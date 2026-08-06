import SwiftUI

/// Sheet where the player activates a Double XP boost, sees their coupon balance,
/// and buys more coupons via in-app purchase.
struct DoubleXPView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var activateHaptic = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    statusCard
                    couponBalance
                    storeSection
                    legalFootnote
                }
                .padding(16)
            }
            .background(GameBackground())
            .navigationTitle("Double XP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: activateHaptic)
        }
    }

    // MARK: Status / activation

    @ViewBuilder
    private var statusCard: some View {
        if game.isDoubleXPActive {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                activeCard
            }
        } else {
            idleCard
        }
    }

    private var activeCard: some View {
        let remaining = game.doubleXPRemaining
        let fraction = remaining / Balance.doubleXPDurationSeconds
        return VStack(spacing: 12) {
            Label("2× XP ACTIVE", systemImage: "sparkles")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.doubleXP)
            Text(Format.clock(remaining))
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            XPProgressBar(progress: fraction, tint: .doubleXP, height: 8)
            Text("Every skill is earning double XP — tap away!")
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
            Text("Activate a coupon for **10 minutes** of 2× XP on every skill — taps and passive training alike. It even stacks with Supercharge.")
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

    // MARK: Coupon balance

    private var couponBalance: some View {
        HStack(spacing: 12) {
            Text("🎟️").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Coupons")
                    .font(.subheadline.weight(.semibold))
                Text("1 free every day")
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

    // MARK: Store

    private var storeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GET MORE COUPONS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            if store.packs.isEmpty {
                HStack {
                    if store.isLoading { ProgressView() }
                    Text(store.isLoading ? "Loading store…" : "Store unavailable right now.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                ForEach(store.packs) { pack in
                    packRow(pack)
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

    private func packRow(_ pack: CouponPack) -> some View {
        HStack(spacing: 12) {
            Text("🎟️").font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pack.title).font(.subheadline.weight(.semibold))
                    if pack.bestValue {
                        Text("BEST VALUE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.doubleXP, in: Capsule())
                    }
                }
                Text("\(pack.coupons) coupons")
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
                .background(Color.doubleXP, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(store.purchasingID != nil)
        }
        .padding(.vertical, 6)
    }

    private var legalFootnote: some View {
        Text("Coupons are consumable in-app purchases. Prices are shown by the App Store and may vary by region.")
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
}
