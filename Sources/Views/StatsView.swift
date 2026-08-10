import SwiftUI

/// Progress dashboard: overview, per-skill levels, and a milestone checklist.
struct StatsView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                overviewSection
                ForEach(SkillCategory.allCases) { category in
                    Section(category.rawValue) {
                        ForEach(SkillID.skills(in: category)) { skill in
                            skillRow(skill)
                        }
                    }
                }
                milestonesSection
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var overviewSection: some View {
        Section("Overview") {
            statRow("Total level", "\(game.totalLevel) / \(game.maxTotalLevel)")
            statRow("Total XP", Format.abbrev(game.totalXP))
            statRow("Skills maxed", "\(game.maxedSkillCount) / \(SkillID.allCases.count)")
            statRow("AFK slots", "\(game.slots.count) / \(game.maxSlots)")
            statRow("Supercharge", "×\(game.effectiveSuperchargeMultiplier) tap XP")
            statRow("Daily Boost coupons", "\(game.doubleXPCoupons)")
            statRow("Energy Cells", "\(game.energyCells)")
        }
    }

    private func skillRow(_ skill: SkillID) -> some View {
        let xp = game.xp(for: skill)
        let level = game.level(for: skill)
        let buff = game.buffValues(for: skill)
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                ArtworkView(art: skill.art, size: 22, color: skill.tint)
                Text(skill.displayName).font(.subheadline.weight(.semibold))
                Spacer()
                Text("lv. \(level)").font(.subheadline.weight(.bold)).monospacedDigit()
                if game.isMaxed(skill) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                }
            }
            XPProgressBar(progress: XPTable.progressToNextLevel(forXP: xp), tint: skill.tint, height: 5)
            HStack {
                Text("\(Format.abbrev(xp)) XP").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if level < XPTable.maxLevel {
                    Text("\(Format.abbrev(XPTable.xpToNextLevel(forXP: xp))) to next")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: skill.buff.icon).font(.caption2).foregroundStyle(skill.tint)
                Text("\(skill.buff.name): \(buff.current)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    private var milestonesSection: some View {
        Section("Milestones") {
            milestoneRow("First level 99", done: game.maxedSkillCount >= 1)
            milestoneRow("All combat skills 99",
                         done: SkillID.skills(in: .combat).allSatisfy { game.isMaxed($0) })
            milestoneRow("All gathering skills 99",
                         done: SkillID.skills(in: .gathering).allSatisfy { game.isMaxed($0) })
            milestoneRow("All artisan skills 99",
                         done: SkillID.skills(in: .artisan).allSatisfy { game.isMaxed($0) })
            milestoneRow("All support skills 99",
                         done: SkillID.skills(in: .support).allSatisfy { game.isMaxed($0) })
            ForEach(Array(Balance.slotUnlockTotalLevels.enumerated()), id: \.offset) { i, threshold in
                milestoneRow("Unlock \(slotOrdinal(i + 2)) AFK slot (total \(threshold))",
                             done: game.totalLevel >= threshold)
            }
            milestoneRow("Max cape — every skill 99", done: game.isFullyMaxed)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func milestoneRow(_ text: String, done: Bool) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(text).foregroundStyle(done ? .primary : .secondary)
        }
    }

    private func slotOrdinal(_ n: Int) -> String {
        switch n {
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}
