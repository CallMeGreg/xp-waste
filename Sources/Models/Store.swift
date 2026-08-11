import Foundation
import StoreKit

/// A purchasable pack of **universal Tokens**, presented in the Shop.
///
/// This is a lightweight view-model over a StoreKit `Product`, so the UI can render
/// (and be previewed/tested) without depending on live App Store connectivity. Tokens are the
/// single spendable currency: bought here, earned from Feats, and spent on Boost Coupons and
/// Energy Cells (see `docs/ACHIEVEMENTS.md`).
struct TokenPack: Identifiable, Equatable {
    let id: String
    let title: String
    /// Number of Tokens granted by this pack.
    let tokens: Int
    let priceText: String
    var bestValue: Bool = false
}

/// Wraps StoreKit 2 to sell **Token packs** — the one IAP family. Consumables no longer sell
/// coupons or Energy Cells directly; players buy Tokens and spend them in the Shop instead.
///
/// Products are defined in `Config/Products.storekit` for local testing (wired into the
/// scheme) and would map to App Store Connect products in production. Successful, verified
/// purchases call `onGrant` with the number of Tokens to credit.
@MainActor
final class Store: ObservableObject {

    // Universal Token packs.
    static let tokenSmallID = "com.callmegreg.xpwaste.tokens.small"
    static let tokenMediumID = "com.callmegreg.xpwaste.tokens.medium"
    static let tokenLargeID = "com.callmegreg.xpwaste.tokens.large"

    static let productIDs = [tokenSmallID, tokenMediumID, tokenLargeID]

    /// How many Tokens each product grants. Keep in sync with `Config/Products.storekit`.
    /// Amounts live in `Balance.Rewards` so re-balancing the economy stays a one-file change.
    static let grants: [String: Int] = [
        tokenSmallID:  Balance.Rewards.iapTokensSmall,
        tokenMediumID: Balance.Rewards.iapTokensMedium,
        tokenLargeID:  Balance.Rewards.iapTokensLarge
    ]

    @Published private(set) var packs: [TokenPack] = []
    @Published private(set) var storeAvailable = false
    @Published private(set) var isLoading = false
    @Published var purchasingID: String?
    @Published var statusMessage: String?

    /// Invoked with the number of Tokens to credit after a verified purchase.
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

            let built: [TokenPack] = Self.productIDs.compactMap { id in
                guard let product = products[id], let tokens = Self.grants[id] else { return nil }
                return TokenPack(id: id,
                                 title: product.displayName,
                                 tokens: tokens,
                                 priceText: product.displayPrice,
                                 bestValue: id == Self.tokenLargeID)
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

    /// Purchase a pack. On success, the Tokens are credited via `onGrant`.
    func purchase(_ pack: TokenPack) async {
        statusMessage = nil
        purchasingID = pack.id
        defer { purchasingID = nil }

        guard storeAvailable, let product = products[pack.id] else {
            #if DEBUG
            onGrant?(pack.tokens)
            statusMessage = "Test purchase — added \(pack.tokens) Tokens."
            #else
            statusMessage = "The Shop is unavailable right now. Please try again later."
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

    /// Credits the Tokens for a verified product id (falling back to the tapped pack if unknown).
    private func grant(for productID: String, fallback: TokenPack?) {
        if let tokens = Self.grants[productID] {
            onGrant?(tokens)
        } else if let fallback {
            onGrant?(fallback.tokens)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreError.failedVerification
        }
    }

    #if DEBUG
    /// Placeholder catalog so the Shop renders when no live products are available
    /// (e.g. running from the command line without the scheme's StoreKit configuration).
    static let mockPacks: [TokenPack] = [
        TokenPack(id: tokenSmallID, title: "Pouch of Tokens", tokens: Balance.Rewards.iapTokensSmall, priceText: "$1.99"),
        TokenPack(id: tokenMediumID, title: "Sack of Tokens", tokens: Balance.Rewards.iapTokensMedium, priceText: "$4.99"),
        TokenPack(id: tokenLargeID, title: "Chest of Tokens", tokens: Balance.Rewards.iapTokensLarge, priceText: "$9.99", bestValue: true)
    ]
    #endif
}
