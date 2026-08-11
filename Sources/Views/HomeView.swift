import SwiftUI

/// The main hub: a compact total-level header, top-bar boost icons, and a grouped
/// "stat list" of every skill (emblem, name, inline XP bar, level, supercharge-ready flag).
struct HomeView: View {
    @EnvironmentObject private var game: GameState
    @Binding var tab: AppTab
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showBoosts = false
    @State private var showLog = false
    @State private var path: [SkillID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 14) {
                    TotalLevelHeader()
                    ForEach(SkillCategory.allCases) { category in
                        SkillStatGroup(category: category)
                    }
                }
                .padding(14)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SkillID.self) { skill in
                SkillTrainingView(skill: skill)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Button {
                            SoundManager.shared.play(.ui, enabled: game.soundEnabled)
                            showStats = true
                        } label: {
                            Image(systemName: "chart.bar.fill").circleToolbarButton()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stats")
                        Button {
                            SoundManager.shared.play(.ui, enabled: game.soundEnabled)
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill").circleToolbarButton()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                }
                ToolbarItem(placement: .principal) {
                    TabSwitcher(selection: $tab)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        LogChip {
                            SoundManager.shared.play(.ui, enabled: game.soundEnabled)
                            showLog = true
                        }
                        BoostsIcons {
                            SoundManager.shared.play(.ui, enabled: game.soundEnabled)
                            showBoosts = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showBoosts) { BoostsView() }
            .sheet(isPresented: $showLog) { AdventurersLogView() }
            .onAppear {
                #if DEBUG
                if path.isEmpty,
                   let raw = ProcessInfo.processInfo.environment["OPEN_SKILL"],
                   let skill = SkillID(rawValue: raw) {
                    path = [skill]
                }
                switch ProcessInfo.processInfo.environment["OPEN_SHEET"] {
                case "doublexp": showBoosts = true
                case "log":      showLog = true
                default:         break
                }
                if ProcessInfo.processInfo.environment["OPEN_DIARY"] != nil { showLog = true }
                #endif
            }
        }
    }
}

/// Compact hub header: total level, max-cape progress, and a one-line slots/supercharge summary.
private struct TotalLevelHeader: View {
    @EnvironmentObject private var game: GameState
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("TOTAL LEVEL").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text("\(game.totalLevel)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 4) {
                XPProgressBar(progress: Double(game.totalLevel) / Double(game.maxTotalLevel),
                              tint: .accentColor, height: 7)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08)))
    }

    private var subtitle: String {
        if game.isFullyMaxed { return "Maxed — level 99 in every skill" }
        return "\(game.slots.count)/\(game.maxSlots) AFK slots · ×\(game.effectiveSuperchargeMultiplier) supercharge"
    }
}

/// A category card: a header label plus a divider-separated list of skill "stat" rows.
private struct SkillStatGroup: View {
    let category: SkillCategory
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(category.rawValue.uppercased(), systemImage: category.symbol)
                    .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            ForEach(Array(SkillID.skills(in: category).enumerated()), id: \.element) { idx, skill in
                if idx > 0 {
                    Divider().overlay(Color.white.opacity(0.06)).padding(.leading, 52)
                }
                NavigationLink(value: skill) {
                    SkillStatRow(skill: skill)
                }
                .buttonStyle(PressableStyle(scale: 0.98))
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
    }
}

/// A single skill row: emblem, name, inline XP bar, level, and AFK-slot / meter-full status flags.
private struct SkillStatRow: View {
    @EnvironmentObject private var game: GameState
    let skill: SkillID
    var body: some View {
        let level = game.level(for: skill)
        let method = game.currentMethod(for: skill)
        let slotted = game.isSlotted(skill)
        let energyFull = game.isEnergyFull(skill)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(skill.tint.opacity(0.22)).frame(width: 34, height: 34)
                ArtworkView(art: method.art, size: 18 * method.scale, color: method.tint ?? skill.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(skill.displayName)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Spacer()
                    if slotted {
                        Label("AFK", systemImage: "bolt.fill")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.yellow)
                    }
                    if energyFull {
                        Label("Full", systemImage: "flame.fill")
                            .font(.caption2.weight(.bold)).foregroundStyle(.orange)
                    }
                    Text("lv. \(level)")
                        .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(.primary)
                }
                XPProgressBar(progress: XPTable.progressToNextLevel(forXP: game.xp(for: skill)),
                              tint: skill.tint, height: 5)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

/// A gold toolbar chip showing the Reward Token balance; opens the Adventurer's Log.
private struct LogChip: View {
    @EnvironmentObject private var game: GameState
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.footnote.weight(.bold)).foregroundStyle(Color.rewardToken)
                Text("\(game.tokens)")
                    .font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(.primary)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color.rewardToken.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.rewardToken.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adventurer's Log, \(game.tokens) Reward Tokens")
    }
}

/// Two compact top-bar chips — Daily Boost (coupon count, or a live countdown while active) and
/// Energy Cells — that open the Boosts sheet. Split for at-a-glance status.
private struct BoostsIcons: View {
    @EnvironmentObject private var game: GameState
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTap) {
                if game.isDoubleXPActive {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        chip(system: "sparkles", tint: .doubleXP,
                             text: Format.clock(game.doubleXPRemaining), wide: true)
                    }
                } else {
                    chip(system: "sparkles", tint: .doubleXP,
                         text: "\(game.doubleXPCoupons)", wide: false)
                }
            }
            .buttonStyle(.plain)
            Button(action: onTap) {
                chip(system: "bolt.fill", tint: .orange, text: "\(game.energyCells)", wide: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func chip(system: String, tint: Color, text: String, wide: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system).font(.footnote.weight(.bold)).foregroundStyle(tint)
            Text(text).font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(.primary)
        }
        .padding(.horizontal, wide ? 10 : 8).padding(.vertical, 6)
        .background(tint.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.45)))
    }
}

/// Wraps a top-bar glyph in its own circular chip so each control reads as a
/// distinct, separate button (matches the app's translucent-card styling).
private struct CircleToolbarButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.footnote.weight(.bold))
            .foregroundStyle(.primary)
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.10), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.22)))
    }
}

private extension View {
    func circleToolbarButton() -> some View { modifier(CircleToolbarButton()) }
}
