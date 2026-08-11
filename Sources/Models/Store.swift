import Foundation
import StoreKit

/// Which consumable family a store product belongs to.
enum ProductKind: Equatable {
    case coupons   // Boost Coupons (activate for a timed XP multiplier)
    case energy    // Energy Cells (instant Supercharge Energy)

    /// The player-facing item name, correctly pluralized for `count`.
    func itemName(_ count: Int) -> String {
        switch self {
        case .coupons: return count == 1 ? "Boost Coupon" : "Boost Coupons"
        case .energy:  return count == 1 ? "Energy Cell"  : "Energy Cells"
        }
    }
}

/// A purchasable pack of consumables, presented in the store UI.
///
/// This is a lightweight view-model over a StoreKit `Product`, so the UI can render
/// (and be previewed/tested) without depending on live App Store connectivity.
struct StorePack: Identifiable, Equatable {
    let id: String
    let kind: ProductKind
    let title: String
    /// Number of coupons (or Energy Cells) granted by this pack.
    let amount: Int
    let priceText: String
    var bestValue: Bool = false
}

/// Wraps StoreKit 2 to sell two families of consumables: Daily Boost coupons and Energy Cells.
///
/// Products are defined in `Config/Products.storekit` for local testing (wired into the
/// scheme) and would map to App Store Connect products in production. Successful, verified
/// purchases call `onGrant` with the product family and the amount to credit.
@MainActor
final class Store: ObservableObject {

    // Daily Boost coupon packs (an XP multiplier).
    static let couponSmallID = "com.callmegreg.xpwaste.coupons.small"
    static let couponMediumID = "com.callmegreg.xpwaste.coupons.medium"
    static let couponLargeID = "com.callmegreg.xpwaste.coupons.large"

    // Energy Cell packs (instant Supercharge Energy).
    static let energySmallID = "com.callmegreg.xpwaste.energy.small"
    static let energyMediumID = "com.callmegreg.xpwaste.energy.medium"
    static let energyLargeID = "com.callmegreg.xpwaste.energy.large"

    static let productIDs = [couponSmallID, couponMediumID, couponLargeID,
                             energySmallID, energyMediumID, energyLargeID]

    /// What each product grants: its family and amount. Keep in sync with `Config/Products.storekit`.
    static let grants: [String: (kind: ProductKind, amount: Int)] = [
        couponSmallID:  (.coupons, 1),
        couponMediumID: (.coupons, 5),
        couponLargeID:  (.coupons, 20),
        energySmallID:  (.energy, 3),
        energyMediumID: (.energy, 10),
        energyLargeID:  (.energy, 30)
    ]

    @Published private(set) var packs: [StorePack] = []
    @Published private(set) var storeAvailable = false
    @Published private(set) var isLoading = false
    @Published var purchasingID: String?
    @Published var statusMessage: String?

    /// Invoked with the product family and amount to credit after a verified purchase.
    var onGrant: ((ProductKind, Int) -> Void)?

    /// Packs in the Daily Boost coupon family, in catalog order.
    var couponPacks: [StorePack] { packs.filter { $0.kind == .coupons } }
    /// Packs in the Energy Cell family, in catalog order.
    var energyPacks: [StorePack] { packs.filter { $0.kind == .energy } }

    private var products: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    enum StoreError: Error { case failedVerification }

    /// Begin listening for transactions and load the product catalog. Safe to call once.
    func start() {
        if updatesTask == nil { updatesTask = listenForTransactions() }
        Task { await loadProducts() }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })

            let built: [StorePack] = Self.productIDs.compactMap { id in
                guard let product = products[id], let grant = Self.grants[id] else { return nil }
                return StorePack(id: id,
                                 kind: grant.kind,
                                 title: product.displayName,
                                 amount: grant.amount,
                                 priceText: product.displayPrice,
                                 bestValue: id == Self.couponLargeID || id == Self.energyLargeID)
            }

            if !built.isEmpty {
                packs = built
                storeAvailable = true
                return
            }
        } catch {
            // Fall through to the unavailable / mock path below.
        }

        storeAvailable = false
        #if DEBUG
        packs = Self.mockPacks
        #else
        packs = []
        #endif
    }

    /// Purchase a pack. On success, the grant is credited via `onGrant`.
    func purchase(_ pack: StorePack) async {
        statusMessage = nil
        purchasingID = pack.id
        defer { purchasingID = nil }

        guard storeAvailable, let product = products[pack.id] else {
            #if DEBUG
            onGrant?(pack.kind, pack.amount)
            statusMessage = "Test purchase — added \(pack.amount) \(pack.kind.itemName(pack.amount))."
            #else
            statusMessage = "The Store is unavailable right now. Please try again later."
            #endif
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                grant(for: transaction.productID, fallback: pack)
                statusMessage = "Purchase complete."
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                statusMessage = "Purchase pending approval."
            @unknown default:
                break
            }
        } catch {
            statusMessage = "Purchase failed. Please try again."
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        grant(for: transaction.productID, fallback: nil)
        await transaction.finish()
    }

    /// Credits the grant for a verified product id (falling back to the tapped pack if unknown).
    private func grant(for productID: String, fallback: StorePack?) {
        if let grant = Self.grants[productID] {
            onGrant?(grant.kind, grant.amount)
        } else if let fallback {
            onGrant?(fallback.kind, fallback.amount)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreError.failedVerification
        }
    }

    #if DEBUG
    /// Placeholder catalog so the store UI renders when no live products are available
    /// (e.g. running from the command line without the scheme's StoreKit configuration).
    static let mockPacks: [StorePack] = [
        StorePack(id: couponSmallID, kind: .coupons, title: "Pouch of Coupons", amount: 1, priceText: "$0.99"),
        StorePack(id: couponMediumID, kind: .coupons, title: "Sack of Coupons", amount: 5, priceText: "$3.99"),
        StorePack(id: couponLargeID, kind: .coupons, title: "Chest of Coupons", amount: 20, priceText: "$9.99", bestValue: true),
        StorePack(id: energySmallID, kind: .energy, title: "Spark Cells", amount: 3, priceText: "$0.99"),
        StorePack(id: energyMediumID, kind: .energy, title: "Charged Cells", amount: 10, priceText: "$2.99"),
        StorePack(id: energyLargeID, kind: .energy, title: "Power Core", amount: 30, priceText: "$6.99", bestValue: true)
    ]
    #endif
}
