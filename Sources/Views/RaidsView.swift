import SwiftUI

/// The Raids tab: one raid per skill group, whose tier scales with the group's average level.
/// Clear a raid (once per group per day) to bank an XP **lamp** for that group, spendable on any one
/// of its skills. Universal & responsive: width-capped and centered, adaptive to iPhone / iPad.
struct RaidsView: View {
    @EnvironmentObject private var game: GameState
    @State private var raidingGroup: SkillCategory?
    @State private var applyGroup: SkillCategory?
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    RaidsOverviewCard()
                    LazyVGrid(columns: Layout.columns(hSize, count: 2, spacing: 14), spacing: 14) {
                        ForEach(SkillCategory.allCases) { group in
                            RaidCard(
                                group: group,
                                onRaid: { raidingGroup = group },
                                onApply: { applyGroup = group },
                                fillHeight: Layout.isWide(hSize)
                            )
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: Layout.maxWidth(hSize, compact: 760, regular: 1180))
                .frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle("Raids")
            .navigationBarTitleDisplayMode(.inline)
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

/// A single explainer at the top of the Raids tab so each card doesn't have to repeat the rules.
private struct RaidsOverviewCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08)).frame(width: 40, height: 40)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.headline.weight(.bold)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Raids").font(.subheadline.weight(.bold))
                Text("Each raid is a multi-room expedition — warm-up rooms, a mini-boss, then a tougher final boss — sharing one timer and one pool of raid HP. Clear every room to bank an XP lamp; finish flawlessly (no hearts lost) for a bonus lamp. Difficulty, rooms & rewards scale with a group's level.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.10)))
    }
}

/// One raid's card: identity, tier + average-level progress, availability CTA, and lamp inventory.
private struct RaidCard: View {
    @EnvironmentObject private var game: GameState
    let group: SkillCategory
    var onRaid: () -> Void
    var onApply: () -> Void
    var fillHeight: Bool = false

    var body: some View {
        let tier = game.raidTier(group)
        let average = game.raidAverageLevel(group)
        let available = game.isRaidAvailableToday(group)
        let lamps = game.lamps(for: group)
        let rooms = group.raidRooms(tier: tier)
        // Distinct tiers present, best first, so mixed-tier inventories read clearly.
        let lampsByTier = Dictionary(grouping: lamps, by: { $0.tier })
            .map { (tier: $0.key, count: $0.value.count) }
            .sorted { $0.tier > $1.tier }

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
                    Text("\(group.rawValue) · \(rooms.count) rooms · \(rooms.filter { $0.isBoss }.count) bosses")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                tierBadge(tier)
            }

            Text(group.raidTagline)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            roomLineup(rooms)

            // Average-level → next tier progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Average level \(average)")
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
            }

            // Actions
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

            // Lamp inventory — one chip per tier, color-coded so multiple tiers are distinguishable —
            // above a prominent "Use Lamps" button matching the Diary tab's affordance.
            if !lamps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(lampsByTier, id: \.tier) { entry in
                            lampChip(tier: entry.tier, count: entry.count)
                        }
                        Spacer(minLength: 0)
                    }
                    Button(action: onApply) {
                        Text("Use Lamps")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.rewardToken, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.rewardTokenText)
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                    .accessibilityLabel("Use \(lamps.count) \(group.rawValue) lamps")
                }
            }

            if !available {
                Text("Come back tomorrow for another attempt.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .topLeading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(group.raidTint.opacity(0.25)))
    }

    /// A compact preview of the raid's room sequence — one node per room, bosses marked with a flame
    /// and the final boss with a crown — so the multi-room structure is legible before you enter.
    private func roomLineup(_ rooms: [RaidRoom]) -> some View {
        HStack(spacing: 4) {
            ForEach(rooms) { r in
                let isFinal = r.id == rooms.count - 1
                let c = r.isBoss ? (isFinal ? Color.yellow : Color.orange) : group.raidTint
                ZStack {
                    Circle().fill(c.opacity(0.16)).frame(width: 26, height: 26)
                    Circle().strokeBorder(c.opacity(0.5), lineWidth: 1).frame(width: 26, height: 26)
                    Image(systemName: isFinal ? "crown.fill" : (r.isBoss ? "flame.fill" : r.kind.symbol))
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(c)
                }
                if r.id != rooms.count - 1 {
                    Image(systemName: "chevron.compact.right")
                        .font(.caption2.weight(.bold)).foregroundStyle(.secondary.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityLabel("\(rooms.count) rooms ending in a boss")
    }

    /// A tier-colored lamp count chip (e.g. a Rune lamp reads runite-colored, an Iron lamp iron-colored).
    private func lampChip(tier: Int, count: Int) -> some View {
        let c = SkillCategory.raidTierColor(tier)
        return HStack(spacing: 4) {
            ArtworkView(art: .vector(.genieLamp), size: 16, color: c)
            Text("\(count)").font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(c)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(c.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(c.opacity(0.45)))
        .accessibilityLabel("\(count) \(SkillCategory.raidTierName(tier)) lamp\(count == 1 ? "" : "s")")
    }

    private func tierBadge(_ tier: Int) -> some View {
        let tierColor = SkillCategory.raidTierColor(tier)
        return VStack(spacing: 1) {
            Text(SkillCategory.raidTierName(tier).uppercased())
                .font(.caption2.weight(.heavy))
            Text("TIER \(tier + 1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(tierColor.opacity(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(tierColor.opacity(0.5)))
        .foregroundStyle(tierColor)
    }
}

/// Sheet to spend a group's lamps: pick which skill to pour the XP into. Shows the projected XP and
/// resulting level for each skill before you commit, then applies one lamp per tap.
private struct LampApplySheet: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    let group: SkillCategory
    @State private var selectedTier: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    let lamps = game.lamps(for: group)
                    let tiers = distinctTiers(lamps)
                    let activeTier = effectiveTier(tiers)
                    let lamp = lamps.first(where: { $0.tier == activeTier }) ?? lamps.first
                    header(remaining: lamps.count, activeTier: activeTier)
                    if tiers.count > 1 {
                        tierPicker(lamps: lamps, tiers: tiers, activeTier: activeTier)
                    }
                    if let lamp {
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
            .navigationTitle("Use \(group.rawValue) Lamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Tiers present in the inventory, best first.
    private func distinctTiers(_ lamps: [RaidLampRecord]) -> [Int] {
        Array(Set(lamps.map { $0.tier })).sorted(by: >)
    }

    /// The tier currently being spent — the player's pick if still in stock, else the best available.
    private func effectiveTier(_ tiers: [Int]) -> Int {
        if let selectedTier, tiers.contains(selectedTier) { return selectedTier }
        return tiers.first ?? 0
    }

    /// Color-coded tier selector, shown only when the group holds lamps of more than one tier.
    private func tierPicker(lamps: [RaidLampRecord], tiers: [Int], activeTier: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(tiers, id: \.self) { tier in
                let c = SkillCategory.raidTierColor(tier)
                let selected = tier == activeTier
                let count = lamps.filter { $0.tier == tier }.count
                Button { selectedTier = tier } label: {
                    HStack(spacing: 5) {
                        ArtworkView(art: .vector(.genieLamp), size: 15, color: c)
                        Text("\(SkillCategory.raidTierName(tier)) ×\(count)")
                            .font(.caption.weight(.bold)).foregroundStyle(c)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(c.opacity(selected ? 0.24 : 0.10), in: Capsule())
                    .overlay(Capsule().strokeBorder(c.opacity(selected ? 0.85 : 0.3), lineWidth: selected ? 2 : 1))
                }
                .buttonStyle(PressableStyle(scale: 0.96))
            }
            Spacer(minLength: 0)
        }
    }

    private func header(remaining: Int, activeTier: Int) -> some View {
        let c = SkillCategory.raidTierColor(activeTier)
        let tierName = SkillCategory.raidTierName(activeTier)
        let article = ["A", "E", "I", "O", "U"].contains(tierName.prefix(1).uppercased()) ? "an" : "a"
        return HStack(spacing: 10) {
            ArtworkView(art: .vector(.genieLamp), size: 24, color: c)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(remaining) lamp\(remaining == 1 ? "" : "s") to spend")
                    .font(.subheadline.weight(.bold))
                Text("Spending \(article) \(tierName) lamp. Pick a \(group.rawValue.lowercased()) skill — XP scales with the skill's level.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(c.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(c.opacity(0.3)))
    }

    private func skillRow(skill: SkillID, lamp: RaidLampRecord) -> some View {
        let level = game.level(for: skill)
        let currentXP = game.xp(for: skill)
        let gain = game.projectedLampXP(lamp, on: skill)
        let newLevel = XPTable.level(forXP: min(currentXP + gain, XPTable.xpCap))
        let method = game.currentMethod(for: skill)
        let tierColor = SkillCategory.raidTierColor(lamp.tier)
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
                Text("+\(Format.abbrevCompact(gain)) XP")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
                    .foregroundStyle(tierColor)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
}
