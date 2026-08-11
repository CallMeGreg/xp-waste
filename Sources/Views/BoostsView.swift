import SwiftUI

/// The Shop: activate an XP **Boost**, see your consumable balances, and buy more Boost
/// Coupons or Energy Cells. One consistent vocabulary throughout — the violet family is
/// "Boost / Boost Coupons", the orange family is "Energy Cells" — with descriptions that
/// state exactly what each does.
struct BoostsView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BoostStatusCard()

                    familyCard(kind: .coupons, tint: .doubleXP, icon: Self.couponIcon,
                               title: "Boost Coupons", balance: game.doubleXPCoupons,
                               description: couponBlurb, packs: store.couponPacks)

                    familyCard(kind: .energy, tint: .orange, icon: Self.energyIcon,
                               title: "Energy Cells", balance: game.energyCells,
                               description: energyBlurb, packs: store.energyPacks)

                    legalFootnote
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
        }
    }

    static let couponIcon = "ticket.fill"
    static let energyIcon = "bolt.fill"

    private var couponBlurb: String {
        let free = Balance.dailyFreeCoupons == 1
            ? "You get 1 free every day."
            : "You get \(Balance.dailyFreeCoupons) free every day."
        return "\(free) Buy more below."
    }

    private var energyBlurb: String {
        "Instantly fills the skill you're training to full Supercharge."
    }

    // MARK: Family card (balance + purchasable packs)

    @ViewBuilder
    private func familyCard(kind: ProductKind, tint: Color, icon: String, title: String,
                            balance: Int, description: String, packs: [StorePack]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
                Text(title).font(.headline)
                Spacer()
                BalancePill(icon: icon, tint: tint, value: balance)
            }
            Text(description).font(.footnote).foregroundStyle(.secondary)

            Divider().overlay(Color.white.opacity(0.08))

            if packs.isEmpty {
                storeStatus(isEmpty: true)
            } else {
                ForEach(packs) { pack in
                    packRow(pack, kind: kind, tint: tint)
                    if pack.id != packs.last?.id {
                        Divider().overlay(Color.white.opacity(0.05))
                    }
                }
                storeStatus(isEmpty: false)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.18)))
    }

    private func packRow(_ pack: StorePack, kind: ProductKind, tint: Color) -> some View {
        HStack(spacing: 12) {
            Text("\(pack.amount)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .frame(minWidth: 34, alignment: .leading)
            Text(kind.itemName(pack.amount)).font(.subheadline.weight(.semibold))
            Spacer()
            BuyButton(pack: pack, tint: tint)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func storeStatus(isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEmpty {
                HStack(spacing: 8) {
                    if store.isLoading { ProgressView() }
                    Text(store.isLoading ? "Loading store…" : "Store unavailable right now.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let message = store.statusMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legalFootnote: some View {
        Text("Boost Coupons and Energy Cells are consumable in-app purchases. Prices are set by the App Store and may vary by region.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
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
                Text("Come back tomorrow for a free coupon, or grab more below.")
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

/// A price button that runs the purchase and shows a spinner while it's in flight.
private struct BuyButton: View {
    @EnvironmentObject private var store: Store
    let pack: StorePack
    let tint: Color

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
            .background(tint, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(store.purchasingID != nil)
    }
}

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
