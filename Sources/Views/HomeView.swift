import SwiftUI

/// The main hub (Skills tab): a **pinned** total-level header — with a live XP-Boost banner while a
/// Boost is running — above a scrolling, grouped "stat list" of every skill. Each row shows the
/// emblem, name, inline XP bar, level, the skill's unique account-wide perk, and AFK-slot /
/// supercharge-ready status. Width-capped and centered so it reads well on iPhone and iPad.
struct HomeView: View {
    @EnvironmentObject private var game: GameState
    @State private var path: [SkillID] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                pinnedHeader
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(SkillCategory.allCases) { category in
                            SkillStatGroup(category: category)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(GameBackground())
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SkillID.self) { skill in
                SkillTrainingView(skill: skill)
            }
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

    /// Stays fixed above the scrolling skill list: total level always in view, plus the active
    /// XP-Boost countdown whenever a Boost is running.
    private var pinnedHeader: some View {
        VStack(spacing: 10) {
            TotalLevelHeader()
            if game.isDoubleXPActive {
                BoostBanner()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
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

/// Live XP-Boost banner shown in the pinned header while a Boost is active: the multiplier every
/// skill is earning, a countdown, and a progress bar of the remaining time.
private struct BoostBanner: View {
    @EnvironmentObject private var game: GameState

    private func multText(_ v: Double) -> String {
        v == v.rounded() ? String(format: "×%.0f", v) : String(format: "×%.1f", v)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: 7) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.bold)).foregroundStyle(Color.doubleXP)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("XP BOOST ACTIVE")
                            .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        Text("\(multText(game.xpMultiplier)) XP on every skill")
                            .font(.caption.weight(.semibold)).foregroundStyle(.primary)
                    }
                    Spacer()
                    Text(Format.clock(game.doubleXPRemaining))
                        .font(.headline.weight(.heavy)).monospacedDigit()
                        .foregroundStyle(Color.doubleXP)
                        .contentTransition(.numericText())
                }
                XPProgressBar(progress: game.doubleXPFraction, tint: .doubleXP, height: 5)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.doubleXP.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.doubleXP.opacity(0.5)))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("XP Boost active, \(Format.clock(game.doubleXPRemaining)) remaining")
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

/// A single skill row: emblem, name, inline XP bar, level, its unique account-wide perk
/// (the "skill descriptor"), and AFK-slot / meter-full status flags.
private struct SkillStatRow: View {
    @EnvironmentObject private var game: GameState
    let skill: SkillID
    var body: some View {
        let level = game.level(for: skill)
        let method = game.currentMethod(for: skill)
        let slotted = game.isSlotted(skill)
        let energyFull = game.isEnergyFull(skill)
        let buff = game.buffValues(for: skill).current
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
                HStack(spacing: 5) {
                    Image(systemName: skill.buff.icon)
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(skill.tint)
                    Text("\(skill.buff.name): \(buff)")
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}
