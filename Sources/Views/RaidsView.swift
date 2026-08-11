import SwiftUI

/// The Raids tab: one raid per skill group, whose tier scales with the group's combined level.
/// Clear a raid (once per group per day) to bank an XP **lamp** for that group, spendable on any one
/// of its skills. Universal & responsive: width-capped and centered, adaptive to iPhone / iPad.
struct RaidsView: View {
    @EnvironmentObject private var game: GameState
    @Binding var tab: AppTab
    @State private var raidingGroup: SkillCategory?
    @State private var applyGroup: SkillCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    RaidsHeader(lampCount: game.raidLamps.count)
                    ForEach(SkillCategory.allCases) { group in
                        RaidCard(
                            group: group,
                            onRaid: { raidingGroup = group },
                            onApply: { applyGroup = group }
                        )
                    }
                }
                .padding(14)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TabSwitcher(selection: $tab)
                }
            }
            .fullScreenCover(item: $raidingGroup) { group in
                RaidSessionView(group: group)
            }
            .sheet(item: $applyGroup) { group in
                LampApplySheet(group: group)
            }
            .onAppear {
                #if DEBUG
                let env = ProcessInfo.processInfo.environment
                if raidingGroup == nil,
                   let raw = env["OPEN_RAID"],
                   let group = SkillCategory.allCases.first(where: { $0.rawValue.lowercased() == raw.lowercased() }) {
                    raidingGroup = group
                }
                if applyGroup == nil,
                   let raw = env["OPEN_APPLY"],
                   let group = SkillCategory.allCases.first(where: { $0.rawValue.lowercased() == raw.lowercased() }) {
                    applyGroup = group
                }
                #endif
            }
        }
    }
}

/// Compact hub header explaining the loop and showing banked-lamp count.
private struct RaidsHeader: View {
    let lampCount: Int
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RAIDS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text("Clear a raid for an XP lamp")
                    .font(.subheadline.weight(.semibold))
                Text("One attempt per group each day")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                ArtworkView(art: .vector(.genieLamp), size: 18, color: .yellow)
                Text("\(lampCount)").font(.headline.weight(.bold)).monospacedDigit()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.yellow.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.4)))
            .accessibilityLabel("\(lampCount) lamps")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08)))
    }
}

/// One raid's card: identity, tier + combined-level progress, availability CTA, and lamp inventory.
private struct RaidCard: View {
    @EnvironmentObject private var game: GameState
    let group: SkillCategory
    var onRaid: () -> Void
    var onApply: () -> Void

    var body: some View {
        let tier = game.raidTier(group)
        let combined = game.raidCombinedLevel(group)
        let maxCombined = game.raidMaxCombinedLevel(group)
        let available = game.isRaidAvailableToday(group)
        let lampCount = game.lamps(for: group).count

        return VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(group.raidTint.opacity(0.22)).frame(width: 44, height: 44)
                    Image(systemName: group.raidSymbol)
                        .font(.title3.weight(.bold)).foregroundStyle(group.raidTint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.raidName).font(.headline.weight(.bold))
                    Text("\(group.rawValue) · \(group.raidVerb)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                tierBadge(tier)
            }

            Text(group.raidTagline)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Combined-level → next tier progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Combined level \(combined)")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if let next = game.raidNextTierLevel(group) {
                        Text("Next tier at avg lv \(next)")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Max tier").font(.caption2.weight(.semibold)).foregroundStyle(group.raidTint)
                    }
                }
                XPProgressBar(progress: game.raidTierProgress(group), tint: group.raidTint, height: 6)
                Text("Difficulty & lamp reward scale with this group's level")
                    .font(.caption2).foregroundStyle(.secondary.opacity(0.8))
            }

            // Actions
            HStack(spacing: 10) {
                Button(action: onRaid) {
                    Label(available ? "Raid" : "Raided today", systemImage: available ? "play.fill" : "checkmark")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(available ? group.raidTint : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(available ? .white : .secondary)
                }
                .buttonStyle(PressableStyle(scale: 0.97))
                .disabled(!available)

                if lampCount > 0 {
                    Button(action: onApply) {
                        HStack(spacing: 6) {
                            ArtworkView(art: .vector(.genieLamp), size: 17, color: .yellow)
                            Text("\(lampCount)").monospacedDigit()
                        }
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(Color.yellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.4)))
                        .foregroundStyle(.yellow)
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                    .accessibilityLabel("Apply \(lampCount) \(group.rawValue) lamps")
                }
            }

            if !available {
                Text("Come back tomorrow for another attempt.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(group.raidTint.opacity(0.25)))
    }

    private func tierBadge(_ tier: Int) -> some View {
        VStack(spacing: 1) {
            Text(SkillCategory.raidTierName(tier).uppercased())
                .font(.caption2.weight(.heavy))
            Text("TIER \(tier + 1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(group.raidTint.opacity(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(group.raidTint.opacity(0.5)))
        .foregroundStyle(group.raidTint)
    }
}

/// Sheet to spend a group's lamps: pick which skill to pour the XP into. Shows the projected XP and
/// resulting level for each skill before you commit, then applies one lamp per tap.
private struct LampApplySheet: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    let group: SkillCategory

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    let lamps = game.lamps(for: group)
                    header(remaining: lamps.count)
                    if let lamp = lamps.first {
                        ForEach(SkillID.skills(in: group)) { skill in
                            skillRow(skill: skill, lamp: lamp)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle("Apply \(group.rawValue) Lamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func header(remaining: Int) -> some View {
        HStack(spacing: 10) {
            ArtworkView(art: .vector(.genieLamp), size: 24, color: .yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(remaining) lamp\(remaining == 1 ? "" : "s") to spend")
                    .font(.subheadline.weight(.bold))
                Text("Pick a \(group.rawValue.lowercased()) skill. XP scales with the skill's tier.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.yellow.opacity(0.3)))
    }

    private func skillRow(skill: SkillID, lamp: RaidLampRecord) -> some View {
        let level = game.level(for: skill)
        let currentXP = game.xp(for: skill)
        let gain = game.projectedLampXP(lamp, on: skill)
        let newLevel = XPTable.level(forXP: min(currentXP + gain, XPTable.xpCap))
        let method = game.currentMethod(for: skill)
        return Button {
            _ = game.applyLamp(lamp, to: skill)
            SoundManager.shared.play(.levelUp, enabled: game.soundEnabled)
            if game.lamps(for: group).isEmpty { dismiss() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(skill.tint.opacity(0.22)).frame(width: 36, height: 36)
                    ArtworkView(art: method.art, size: 19 * method.scale, color: method.tint ?? skill.tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.displayName).font(.subheadline.weight(.semibold))
                    Text("lv. \(level)\(newLevel > level ? " → \(newLevel)" : "")")
                        .font(.caption).monospacedDigit()
                        .foregroundStyle(newLevel > level ? skill.tint : .secondary)
                }
                Spacer()
                Text("+\(Format.abbrev(gain)) XP")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.yellow)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}
