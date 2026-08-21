import SwiftUI

/// The Shop, unified around a single currency — **Tokens**. See your Token balance, **spend Tokens**
/// to stock up on Boost Coupons and Energy Cells, and **buy Tokens** with real money. Tokens are also
/// earned by completing Tasks in the Diary, so the whole economy is one pouch of coins. XP Boosts are
/// activated from the Skills tab, not here. See `docs/ACHIEVEMENTS.md`.
struct BoostsView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var store: Store
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pinned Token balance — stays in view while the rest of the shop scrolls.
                TokenWalletCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .frame(maxWidth: Layout.maxWidth(hSize, compact: 640, regular: 1040))
                    .frame(maxWidth: .infinity)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if Layout.isWide(hSize) {
                                HStack(alignment: .top, spacing: 16) {
                                    VStack(spacing: 16) {
                                        sectionHeader("Spend Tokens")
                                        SpendFamilyCard(spendable: .coupon)
                                        SpendFamilyCard(spendable: .cell)
                                        RefreshRaidsCard()
                                    }
                                    VStack(spacing: 16) {
                                        sectionHeader("Buy more Tokens")
                                        GetTokensCard()
                                    }
                                }
                            } else {
                                sectionHeader("Spend Tokens")
                                SpendFamilyCard(spendable: .coupon)
                                SpendFamilyCard(spendable: .cell)
                                RefreshRaidsCard()
                                sectionHeader("Buy more Tokens")
                                GetTokensCard()
                            }

                            legalFootnote.id("shopBottom")
                        }
                        .padding(16)
                        .frame(maxWidth: Layout.maxWidth(hSize, compact: 640, regular: 1040))
                        .frame(maxWidth: .infinity)
                    }
                    #if DEBUG
                    .onAppear {
                        // Deterministic screenshots of the lower "Token Packs" (IAP) section.
                        guard ProcessInfo.processInfo.environment["SHOP_SCROLL"] == "tokens" else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation { proxy.scrollTo("shopBottom", anchor: .bottom) }
                        }
                    }
                    #endif
                }
            }
            .background(GameBackground())
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private var legalFootnote: some View {
        Text("Tokens are a consumable in-app purchase, and are also earned in-game. They have no monetary value and can't be exchanged for cash. Prices are set by the App Store and may vary by region.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

// MARK: - Token wallet hero

/// Your live Token balance, styled to match the Diary's gold Token treatment.
private struct TokenWalletCard: View {
    @EnvironmentObject private var game: GameState
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.rewardToken.opacity(0.22)).frame(width: 52, height: 52)
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.rewardToken)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("TOKENS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text("\(game.tokens)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
                Text("Earn from Diary Tasks · spend below").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.rewardToken.opacity(0.30)))
    }
}

// MARK: - Spend Tokens on a consumable family

/// The two Token-spendable consumables. Keeps the spend UI DRY and routes to the matching
/// `GameState` action; all prices come from `Balance.Rewards`.
private enum Spendable {
    case coupon, cell

    var title: String { self == .coupon ? "Boost Coupons" : "Energy Cells" }
    var icon: String { self == .coupon ? "ticket.fill" : "bolt.fill" }
    var tint: Color { self == .coupon ? .doubleXP : .orange }
    var unitCost: Int { self == .coupon ? Balance.Rewards.boostCouponCost : Balance.Rewards.energyCellCost }
    /// Only single-unit Token purchases are offered (bundles were removed to keep the shop simple).
    var quantities: [Int] { [1] }

    var blurb: String {
        switch self {
        case .coupon: return "Spend one to start a timed XP boost on every skill."
        case .cell:   return "Instantly fills the skill you're training to full Supercharge."
        }
    }

    @MainActor
    func balance(_ g: GameState) -> Int { self == .coupon ? g.doubleXPCoupons : g.energyCells }

    func itemName(_ count: Int) -> String {
        switch self {
        case .coupon: return count == 1 ? "Boost Coupon" : "Boost Coupons"
        case .cell:   return count == 1 ? "Energy Cell" : "Energy Cells"
        }
    }

    @MainActor
    @discardableResult
    func buy(_ g: GameState, _ qty: Int) -> Bool { self == .coupon ? g.buyBoostCoupon(qty) : g.buyEnergyCell(qty) }
}

/// A family card that shows the owned balance and offers Token-priced purchases.
private struct SpendFamilyCard: View {
    @EnvironmentObject private var game: GameState
    let spendable: Spendable
    @State private var buyHaptic = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: spendable.icon).font(.title3).foregroundStyle(spendable.tint)
                Text(spendable.title).font(.headline)
                Spacer()
                BalancePill(icon: spendable.icon, tint: spendable.tint, value: spendable.balance(game))
            }
            Text(spendable.blurb).font(.footnote).foregroundStyle(.secondary)

            Divider().overlay(Color.white.opacity(0.08))

            ForEach(spendable.quantities, id: \.self) { qty in
                spendRow(qty)
                if qty != spendable.quantities.last {
                    Divider().overlay(Color.white.opacity(0.05))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(spendable.tint.opacity(0.18)))
        .sensoryFeedback(.success, trigger: buyHaptic)
    }

    private func spendRow(_ qty: Int) -> some View {
        let cost = spendable.unitCost * qty
        let afford = game.tokens >= cost
        return HStack(spacing: 12) {
            Text("\(qty)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(spendable.tint)
                .frame(minWidth: 34, alignment: .leading)
            Text(spendable.itemName(qty)).font(.subheadline.weight(.semibold))
            Spacer()
            Button { buy(qty) } label: { tokenPrice(cost, enabled: afford) }
                .buttonStyle(PressableStyle())
                .disabled(!afford)
        }
        .padding(.vertical, 4)
    }

    private func tokenPrice(_ cost: Int, enabled: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "star.circle.fill").font(.caption.weight(.bold))
            Text(cost.formatted()).font(.subheadline.weight(.bold)).monospacedDigit()
        }
        .foregroundStyle(enabled ? .black : Color.secondary)
        .frame(minWidth: 64)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(enabled ? Color.rewardToken : Color.white.opacity(0.10), in: Capsule())
    }

    private func buy(_ qty: Int) {
        if spendable.buy(game, qty) {
            if game.hapticsEnabled { buyHaptic += 1 }
            SoundManager.shared.play(.purchase, enabled: game.soundEnabled)
        }
    }
}

// MARK: - Buy Tokens (IAP)

/// A one-shot Token consumable that re-arms **every** group's daily raid so they can all be run
/// again today. Unlike the coupon/cell families there's no "owned" balance — it acts immediately,
/// so it gets its own card rather than reusing `SpendFamilyCard`.
private struct RefreshRaidsCard: View {
    @EnvironmentObject private var game: GameState
    @State private var buyHaptic = 0

    var body: some View {
        let cost = Balance.Rewards.refreshRaidsCost
        let hasSpent = game.hasRaidedTodayAnyGroup
        let enabled = hasSpent && game.tokens >= cost
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill").font(.title3).foregroundStyle(.teal)
                Text("Raid Refresh").font(.headline)
                Spacer()
            }
            Text(hasSpent
                 ? "Re-arm every group's daily raid so you can run them all again right now."
                 : "All raids are already available — nothing to refresh yet today.")
                .font(.footnote).foregroundStyle(.secondary)

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                Text("Refresh all raids").font(.subheadline.weight(.semibold))
                Spacer()
                Button { refresh() } label: { tokenPrice(cost, enabled: enabled) }
                    .buttonStyle(PressableStyle())
                    .disabled(!enabled)
            }
            .padding(.vertical, 4)
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.teal.opacity(0.18)))
        .sensoryFeedback(.success, trigger: buyHaptic)
    }

    private func tokenPrice(_ cost: Int, enabled: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "star.circle.fill").font(.caption.weight(.bold))
            Text(cost.formatted()).font(.subheadline.weight(.bold)).monospacedDigit()
        }
        .foregroundStyle(enabled ? .black : Color.secondary)
        .frame(minWidth: 64)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(enabled ? Color.rewardToken : Color.white.opacity(0.10), in: Capsule())
    }

    private func refresh() {
        if game.refreshRaids() {
            if game.hapticsEnabled { buyHaptic += 1 }
            SoundManager.shared.play(.purchase, enabled: game.soundEnabled)
        }
    }
}

/// The single IAP family: real-money Token packs. Reads the catalog from `Store` (live or the
/// DEBUG mock), so it renders for screenshots without App Store connectivity.
private struct GetTokensCard: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "star.circle.fill").font(.title3).foregroundStyle(Color.rewardToken)
                Text("Token Packs").font(.headline)
                Spacer()
            }
            Text("Top up your pouch to spend on Boost Coupons and Energy Cells.")
                .font(.footnote).foregroundStyle(.secondary)

            Divider().overlay(Color.white.opacity(0.08))

            if store.packs.isEmpty {
                storeStatus(isEmpty: true)
            } else {
                ForEach(store.packs) { pack in
                    packRow(pack)
                    if pack.id != store.packs.last?.id {
                        Divider().overlay(Color.white.opacity(0.05))
                    }
                }
                storeStatus(isEmpty: false)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.rewardToken.opacity(0.18)))
    }

    private func packRow(_ pack: TokenPack) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.title3).foregroundStyle(Color.rewardToken)
                .frame(minWidth: 34, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pack.tokens.formatted()) Tokens").font(.subheadline.weight(.bold)).monospacedDigit()
                if pack.bestValue {
                    Text("Best value").font(.caption2.weight(.bold)).foregroundStyle(Color.rewardToken)
                }
            }
            Spacer()
            TokenBuyButton(pack: pack)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func storeStatus(isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEmpty {
                HStack(spacing: 8) {
                    if store.isLoading { ProgressView() }
                    Text(store.isLoading ? "Loading Token packs…" : "Token packs unavailable right now.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let message = store.statusMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A real-money price button that runs the Token-pack purchase and shows a spinner while in flight.
private struct TokenBuyButton: View {
    @EnvironmentObject private var store: Store
    let pack: TokenPack

    var body: some View {
        Button {
            _Concurrency.Task { await store.purchase(pack) }
        } label: {
            Group {
                if store.purchasingID == pack.id {
                    ProgressView()
                } else {
                    Text(pack.priceText).font(.subheadline.weight(.bold))
                }
            }
            .foregroundStyle(.black)
            .frame(minWidth: 64)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.rewardToken, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(store.purchasingID != nil)
    }
}

// MARK: - Small shared shop components

/// A compact balance chip: family icon + owned count in the family tint.
private struct BalancePill: View {
    let icon: String
    let tint: Color
    let value: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.footnote.weight(.bold)).foregroundStyle(tint)
            Text("\(value)").font(.subheadline.weight(.heavy)).monospacedDigit().foregroundStyle(.primary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(tint.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.4)))
    }
}
