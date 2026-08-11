import SwiftUI

/// The Shop, unified around a single currency — **Tokens**. You activate an XP **Boost**, see your
/// Token balance, **spend Tokens** to stock up on Boost Coupons and Energy Cells, and **buy Tokens**
/// with real money. Tokens are also earned by completing Feats in the Adventurer's Log, so the whole
/// economy is one pouch of coins. See `docs/ACHIEVEMENTS.md`.
struct BoostsView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        BoostStatusCard()
                        TokenWalletCard()

                        sectionHeader("Spend Tokens")
                        SpendFamilyCard(spendable: .coupon)
                        SpendFamilyCard(spendable: .cell)

                        sectionHeader("Get more Tokens")
                        GetTokensCard()

                        legalFootnote.id("shopBottom")
                    }
                    .padding(16)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .navigationTitle("Shop")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
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

/// Your live Token balance, styled to match the Adventurer's Log's gold Token treatment.
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
                Text("Earn from Feats · spend below").font(.caption2).foregroundStyle(.secondary)
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
    /// Purchase quantities offered (buy one, or a discount-free convenience bundle).
    var quantities: [Int] { [1, 5] }

    var blurb: String {
        switch self {
        case .coupon: return "A timed XP boost for every skill — taps and AFK alike. You still get 1 free each day; stock up with Tokens."
        case .cell:   return "Instantly fills the skill you're training to full Supercharge. Stock up with Tokens."
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
            Text("Top up your pouch to spend on Boosts and Energy Cells. A big shortcut — one pack is worth many Feats' worth of Tokens.")
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
            Task { await store.purchase(pack) }
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

// MARK: - Boost status / activation

/// The hero at the top of the Shop: a live countdown while a Boost is running, or an
/// "Activate Boost" call-to-action (with the effect explained) when idle.
private struct BoostStatusCard: View {
    @EnvironmentObject private var game: GameState
    @State private var activateHaptic = 0

    var body: some View {
        Group {
            if game.isDoubleXPActive {
                TimelineView(.periodic(from: .now, by: 1)) { _ in activeCard }
            } else {
                idleCard
            }
        }
        .sensoryFeedback(.success, trigger: activateHaptic)
    }

    private var boostMinutes: Int {
        Int(((Balance.doubleXPDurationSeconds + game.doubleXPBonusDuration) / 60).rounded())
    }

    private func multText(_ v: Double) -> String {
        v == v.rounded() ? String(format: "×%.0f", v) : String(format: "×%.1f", v)
    }

    private var activeCard: some View {
        VStack(spacing: 12) {
            Label("Boost active", systemImage: "sparkles")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.doubleXP)
            Text(Format.clock(game.doubleXPRemaining))
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            XPProgressBar(progress: game.doubleXPFraction, tint: .doubleXP, height: 8)
            Text("Every skill is earning \(multText(game.xpMultiplier)) XP — tap away!")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.doubleXP.opacity(0.14), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.doubleXP.opacity(0.6), lineWidth: 1.5))
    }

    private var idleCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.doubleXP)
            Text("XP Boost").font(.title2.bold())
            Text("Spend a Boost Coupon for **\(boostMinutes) minutes** of \(multText(game.doubleXPPotency)) XP on every skill — taps and AFK training alike. Stacks with Supercharge.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button(action: activate) {
                Text(game.doubleXPCoupons > 0 ? "Activate Boost" : "Out of coupons")
                    .font(.headline)
                    .foregroundStyle(game.canActivateDoubleXP ? .black : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(game.canActivateDoubleXP ? Color.doubleXP : Color.white.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(PressableStyle())
            .disabled(!game.canActivateDoubleXP)

            if game.doubleXPCoupons == 0 {
                Text("Come back tomorrow for a free coupon, or buy more with Tokens below.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.08)))
    }

    private func activate() {
        if game.activateDoubleXP() {
            if game.hapticsEnabled { activateHaptic += 1 }
            SoundManager.shared.play(.doubleXP, enabled: game.soundEnabled)
        }
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
