import SwiftUI

/// The main hub: total-level header + a grid of skill tiles grouped by category.
struct HomeView: View {
    @EnvironmentObject private var game: GameState
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showDoubleXP = false
    @State private var path: [SkillID] = []

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    HeaderCard()
                    DoubleXPCard(show: $showDoubleXP)
                    ForEach(SkillCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Label(category.rawValue.uppercased(), systemImage: category.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(SkillID.skills(in: category)) { skill in
                                    NavigationLink(value: skill) {
                                        SkillTileView(skill: skill)
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle("Idle Skiller")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SkillID.self) { skill in
                SkillTrainingView(skill: skill)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStats = true } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showDoubleXP) { DoubleXPView() }
            .onAppear {
                #if DEBUG
                if path.isEmpty,
                   let raw = ProcessInfo.processInfo.environment["OPEN_SKILL"],
                   let skill = SkillID(rawValue: raw) {
                    path = [skill]
                }
                if ProcessInfo.processInfo.environment["OPEN_SHEET"] == "doublexp" {
                    showDoubleXP = true
                }
                #endif
            }
        }
    }
}

/// Top-of-hub summary: total level, max-cape progress, slots, and the next unlock hint.
private struct HeaderCard: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Level")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(game.totalLevel)")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Label("\(game.slots.count) / \(game.maxSlots) slots", systemImage: "bolt.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)
                    Label("×\(game.superchargeMultiplier) supercharge", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            VStack(spacing: 5) {
                XPProgressBar(progress: Double(game.totalLevel) / Double(game.maxTotalLevel),
                              tint: .accentColor, height: 10)
                HStack {
                    Text("Max cape progress")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(game.totalLevel) / \(game.maxTotalLevel)")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }

            if game.isFullyMaxed {
                Text("🏆 Maxed! Level 99 in every skill.")
                    .font(.caption.bold()).foregroundStyle(.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let next = game.nextSlotUnlock {
                Text("Reach total level \(next.totalLevel) to unlock training slot \(next.slot).")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08)))
    }
}

/// Home entry point for the Double XP feature: shows a live countdown while a boost
/// is running, otherwise an "Activate" prompt with the player's coupon balance.
private struct DoubleXPCard: View {
    @EnvironmentObject private var game: GameState
    @Binding var show: Bool

    var body: some View {
        Button { show = true } label: {
            Group {
                if game.isDoubleXPActive {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in activeContent }
                } else {
                    idleContent
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.doubleXP.opacity(game.isDoubleXPActive ? 0.16 : 0.10),
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.doubleXP.opacity(game.isDoubleXPActive ? 0.6 : 0.35), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var activeContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.title2).foregroundStyle(Color.doubleXP)
            VStack(alignment: .leading, spacing: 2) {
                Text("2× XP ACTIVE")
                    .font(.subheadline.weight(.heavy)).foregroundStyle(Color.doubleXP)
                Text("Every skill earns double XP")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.clock(game.doubleXPRemaining))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit().contentTransition(.numericText())
        }
    }

    private var idleContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.title2).foregroundStyle(Color.doubleXP)
            VStack(alignment: .leading, spacing: 2) {
                Text("Double XP")
                    .font(.subheadline.weight(.bold))
                Text(game.doubleXPCoupons > 0
                     ? "Tap to activate 10 min of 2× XP"
                     : "Free coupon daily · buy more anytime")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                Text("🎟️")
                Text("\(game.doubleXPCoupons)")
                    .font(.headline.weight(.bold)).monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
        }
    }
}
