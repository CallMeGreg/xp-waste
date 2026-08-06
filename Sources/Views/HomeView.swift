import SwiftUI

/// The main hub: total-level header + a grid of skill tiles grouped by category.
struct HomeView: View {
    @EnvironmentObject private var game: GameState
    @State private var showStats = false
    @State private var showSettings = false
    @State private var path: [SkillID] = []

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    HeaderCard()
                    ForEach(SkillCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.rawValue.uppercased())
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
            .onAppear {
                #if DEBUG
                if path.isEmpty,
                   let raw = ProcessInfo.processInfo.environment["OPEN_SKILL"],
                   let skill = SkillID(rawValue: raw) {
                    path = [skill]
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
                    Label("×\(game.superchargeXPPerTap) supercharge", systemImage: "flame.fill")
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
