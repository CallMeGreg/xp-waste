import SwiftUI

/// Sheet where the player activates a Double XP boost, uses/stocks Energy Cells, and buys
/// more of either via in-app purchase. Both consumables remain purchasable so players can
/// always buy an XP multiplier *or* Energy; skill perks make each one stronger over time.
struct BoostsView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var activateHaptic = 0
    @State private var energyHaptic = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    doubleXPStatus
                    couponBalance
                    storeSection(title: "GET MORE COUPONS", packs: store.couponPacks, tint: .doubleXP)

                    energyCard
                    storeSection(title: "GET ENERGY CELLS", packs: store.energyPacks, tint: .orange)

                    legalFootnote
                }
                .padding(16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Boosts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: activateHaptic)
            .sensoryFeedback(.impact, trigger: energyHaptic)
        }
    }

    // MARK: Double XP status / activation

    private func multText(_ v: Double) -> String {
        v == v.rounded() ? String(format: "×%.0f", v) : String(format: "×%.1f", v)
    }

    private var boostMinutes: Int {
        Int(((Balance.doubleXPDurationSeconds + game.doubleXPBonusDuration) / 60).rounded())
    }

    @ViewBuilder
    private var doubleXPStatus: some View {
        if game.isDoubleXPActive {
            TimelineView(.periodic(from: .now, by: 1)) { _ in activeCard }
        } else {
            idleCard
        }
    }

    private var activeCard: some View {
        VStack(spacing: 12) {
            Label("\(multText(game.xpMultiplier)) XP ACTIVE", systemImage: "sparkles")
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
            Text("✨").font(.system(size: 54))
            Text("Double XP")
                .font(.title2.bold())
            Text("Activate a coupon for **\(boostMinutes) minutes** of \(multText(game.doubleXPPotency)) XP on every skill — taps and passive training alike. It even stacks with Supercharge.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button(action: activate) {
                Text(game.doubleXPCoupons > 0 ? "Activate Double XP" : "Out of coupons")
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

    private var couponBalance: some View {
        HStack(spacing: 12) {
            Text("🎟️").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Coupons")
                    .font(.subheadline.weight(.semibold))
                Text(game.dailyCoupons == 1 ? "1 free every day" : "\(game.dailyCoupons) free every day")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(game.doubleXPCoupons)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.doubleXP)
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08)))
    }

    // MARK: Energy Cells

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("🔋").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Energy Cells")
                        .font(.subheadline.weight(.semibold))
                    Text("Instantly recharge every slotted skill to full")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(game.energyCells)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }

            Button(action: useEnergyCell) {
                Text(game.energyCells > 0 ? "Use Energy Cell" : "Out of Energy Cells")
                    .font(.headline)
                    .foregroundStyle(game.canUseEnergyCell ? .black : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(game.canUseEnergyCell ? Color.orange : Color.white.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(PressableStyle())
            .disabled(!game.canUseEnergyCell)

            Text(energyHint)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.08)))
    }

    private var energyHint: String {
        if game.slots.isEmpty {
            return "Slot a skill first — a cell recharges all your slotted skills at once."
        }
        return "Each cell fills all \(game.slots.count) slotted skill\(game.slots.count == 1 ? "" : "s") to full Energy, ready to Supercharge. Mining, Firemaking and Prayer make every charge stronger."
    }

    // MARK: Store

    @ViewBuilder
    private func storeSection(title: String, packs: [StorePack], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            if packs.isEmpty {
                HStack {
                    if store.isLoading { ProgressView() }
                    Text(store.isLoading ? "Loading store…" : "Store unavailable right now.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                ForEach(packs) { pack in
                    packRow(pack, tint: tint)
                }
            }

            if let message = store.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08)))
    }

    private func packRow(_ pack: StorePack, tint: Color) -> some View {
        HStack(spacing: 12) {
            Text(pack.kind == .coupons ? "🎟️" : "🔋").font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pack.title).font(.subheadline.weight(.semibold))
                    if pack.bestValue {
                        Text("BEST VALUE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(tint, in: Capsule())
                    }
                }
                Text("\(pack.amount) \(pack.kind == .coupons ? "coupons" : "Energy Cells")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
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
        .padding(.vertical, 6)
    }

    private var legalFootnote: some View {
        Text("Coupons and Energy Cells are consumable in-app purchases. Prices are shown by the App Store and may vary by region.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    private func activate() {
        if game.activateDoubleXP(), game.hapticsEnabled {
            activateHaptic += 1
        }
    }

    private func useEnergyCell() {
        if game.useEnergyCell(), game.hapticsEnabled {
            energyHaptic += 1
        }
    }
}
