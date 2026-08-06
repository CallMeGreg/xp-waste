import Foundation
import StoreKit

/// A purchasable pack of Double XP coupons, presented in the store UI.
///
/// This is a lightweight view-model over a StoreKit `Product`, so the UI can render
/// (and be previewed/tested) without depending on live App Store connectivity.
struct CouponPack: Identifiable, Equatable {
    let id: String
    let title: String
    let coupons: Int
    let priceText: String
    var bestValue: Bool = false
}

/// Wraps StoreKit 2 to sell consumable Double XP coupon packs.
///
/// Products are defined in `Config/Products.storekit` for local testing (wired into the
/// scheme) and would map to App Store Connect products in production. Successful, verified
/// purchases call `onGrant` with the number of coupons to credit.
@MainActor
final class Store: ObservableObject {

    static let smallID = "com.callmegreg.xpwaste.coupons.small"
    static let mediumID = "com.callmegreg.xpwaste.coupons.medium"
    static let largeID = "com.callmegreg.xpwaste.coupons.large"
    static let productIDs = [smallID, mediumID, largeID]

    /// Coupons granted per product id. Keep in sync with `Config/Products.storekit`.
    static let couponGrants: [String: Int] = [smallID: 5, mediumID: 25, largeID: 100]

    @Published private(set) var packs: [CouponPack] = []
    @Published private(set) var storeAvailable = false
    @Published private(set) var isLoading = false
    @Published var purchasingID: String?
    @Published var statusMessage: String?

    /// Invoked with the number of coupons to credit after a verified purchase.
    var onGrant: ((Int) -> Void)?

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

            let built: [CouponPack] = Self.productIDs.compactMap { id in
                guard let product = products[id] else { return nil }
                return CouponPack(id: id,
                                  title: product.displayName,
                                  coupons: Self.couponGrants[id] ?? 0,
                                  priceText: product.displayPrice,
                                  bestValue: id == Self.largeID)
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

    /// Purchase a pack. On success, coupons are credited via `onGrant`.
    func purchase(_ pack: CouponPack) async {
        statusMessage = nil
        purchasingID = pack.id
        defer { purchasingID = nil }

        guard storeAvailable, let product = products[pack.id] else {
            #if DEBUG
            onGrant?(pack.coupons)
            statusMessage = "Test purchase — added \(pack.coupons) coupons."
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
                onGrant?(Self.couponGrants[transaction.productID] ?? pack.coupons)
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
        onGrant?(Self.couponGrants[transaction.productID] ?? 0)
        await transaction.finish()
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
    static let mockPacks: [CouponPack] = [
        CouponPack(id: smallID, title: "Pouch of Coupons", coupons: 5, priceText: "$0.99"),
        CouponPack(id: mediumID, title: "Sack of Coupons", coupons: 25, priceText: "$3.99"),
        CouponPack(id: largeID, title: "Chest of Coupons", coupons: 100, priceText: "$9.99", bestValue: true)
    ]
    #endif
}
