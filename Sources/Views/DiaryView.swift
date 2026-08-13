import SwiftUI

/// The Diary — the player-facing home of the achievement/reward system. Two tabs:
/// an **Overview** (Reward Token balance, overall completion, and the Tasks you're closest to
/// finishing) and **All Tasks** (drill into a themed Diary to see every Task and its live progress).
///
/// Styled to match the app's dark translucent-card aesthetic and width-capped/centered so it
/// reads well on iPad as well as iPhone.
struct DiaryView: View {
    @EnvironmentObject private var game: GameState
    @State private var tab: Tab = .overview
    @State private var path: [TaskDiary] = []
    @Environment(\.horizontalSizeClass) private var hSize

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case tasks = "All Tasks"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                GameBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        if Layout.isWide(hSize) {
                            viewPicker.frame(maxWidth: 420)
                            TokenBalanceCard()
                        } else {
                            TokenBalanceCard()
                            viewPicker
                        }

                        switch tab {
                        case .overview: DiaryOverview()
                        case .tasks:    DiaryTaskList()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: Layout.maxWidth(hSize, compact: 720, regular: 1180))
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Diary")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: TaskDiary.self) { diary in
                TaskDiaryDetailView(diary: diary)
            }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.environment["DIARY_TAB"] == "tasks" { tab = .tasks }
                if let raw = ProcessInfo.processInfo.environment["OPEN_DIARY"],
                   let diary = TaskDiary(rawValue: raw) {
                    tab = .tasks
                    path = [diary]
                }
                #endif
            }
        }
    }

    private var viewPicker: some View {
        Picker("View", selection: $tab) {
            ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Token balance hero

private struct TokenBalanceCard: View {
    @EnvironmentObject private var game: GameState
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.rewardToken.opacity(0.22)).frame(width: 52, height: 52)
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.rewardToken)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("TOKENS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text("\(game.tokens)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
                Text("Earned by completing Tasks").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .diaryCard()
    }
}

// MARK: - Diary XP lamp inventory

/// Unified inventory of any-skill XP lamps earned by clearing Diary tiers.
private struct DiaryLampInventoryCard: View {
    @EnvironmentObject private var game: GameState
    @State private var showApply = false

    var body: some View {
        let byTier = Dictionary(grouping: game.diaryLamps, by: { $0.tier })
            .map { (tier: $0.key, count: $0.value.count) }
            .sorted { $0.tier > $1.tier }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("XP LAMPS", systemImage: "sparkles")
                    .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(game.diaryLamps.count)")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
            }
            Text("Earned by clearing Diary tiers. Spend one on any skill — its XP scales with that skill's level.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(byTier, id: \.tier) { entry in
                        let c = SkillCategory.raidTierColor(entry.tier)
                        HStack(spacing: 5) {
                            ArtworkView(art: .vector(.genieLamp), size: 15, color: c)
                            Text("\(SkillCategory.raidTierName(entry.tier)) ×\(entry.count)")
                                .font(.caption.weight(.bold)).foregroundStyle(c)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(c.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(c.opacity(0.35)))
                    }
                }
                .padding(.vertical, 1)
            }
            Button { showApply = true } label: {
                Text("Use Lamps")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.rewardToken, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.rewardTokenText)
            }
            .buttonStyle(PressableStyle(scale: 0.98))
        }
        .padding(16)
        .diaryCard()
        .sheet(isPresented: $showApply) { DiaryLampApplySheet() }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["OPEN_DIARY_LAMPS"] != nil { showApply = true }
            #endif
        }
    }
}

/// Spend any-skill diary lamps on any of the 23 skills, grouped by category.
private struct DiaryLampApplySheet: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                let lamps = game.diaryLampsSorted
                let tiers = distinctTiers(lamps)
                let activeTier = effectiveTier(tiers)
                let lamp = lamps.first(where: { $0.tier == activeTier }) ?? lamps.first
                VStack(spacing: 14) {
                    header(remaining: lamps.count, activeTier: activeTier)
                    if tiers.count > 1 {
                        tierPicker(lamps: lamps, tiers: tiers, activeTier: activeTier)
                    }
                    if let lamp {
                        ForEach(SkillCategory.allCases) { category in
                            categorySection(category: category, lamp: lamp)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle("Use XP Lamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func distinctTiers(_ lamps: [RaidLampRecord]) -> [Int] {
        Array(Set(lamps.map(\.tier))).sorted(by: >)
    }

    private func effectiveTier(_ tiers: [Int]) -> Int? {
        if let selectedTier, tiers.contains(selectedTier) { return selectedTier }
        return tiers.first
    }

    private func header(remaining: Int, activeTier: Int?) -> some View {
        let c = activeTier.map { SkillCategory.raidTierColor($0) } ?? .secondary
        return VStack(spacing: 8) {
            ArtworkView(art: .vector(.genieLamp), size: 54, color: c)
            if let activeTier {
                Text("\(SkillCategory.raidTierName(activeTier)) Lamp")
                    .font(.headline).foregroundStyle(c)
            }
            Text("\(remaining) lamp\(remaining == 1 ? "" : "s") remaining. Pick any skill — the XP awarded scales with that skill's level.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .diaryCard()
    }

    private func tierPicker(lamps: [RaidLampRecord], tiers: [Int], activeTier: Int?) -> some View {
        HStack(spacing: 8) {
            ForEach(tiers, id: \.self) { tier in
                let count = lamps.filter { $0.tier == tier }.count
                let c = SkillCategory.raidTierColor(tier)
                let selected = tier == activeTier
                Button { selectedTier = tier } label: {
                    HStack(spacing: 5) {
                        ArtworkView(art: .vector(.genieLamp), size: 13, color: c)
                        Text("\(SkillCategory.raidTierName(tier)) ×\(count)")
                            .font(.caption.weight(.bold)).foregroundStyle(c)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(c.opacity(selected ? 0.24 : 0.10), in: Capsule())
                    .overlay(Capsule().strokeBorder(c.opacity(selected ? 0.85 : 0.3), lineWidth: selected ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func categorySection(category: SkillCategory, lamp: RaidLampRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.rawValue.uppercased())
                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            ForEach(SkillID.skills(in: category)) { skill in
                skillRow(skill: skill, lamp: lamp)
            }
        }
    }

    private func skillRow(skill: SkillID, lamp: RaidLampRecord) -> some View {
        let level = game.level(for: skill)
        let projected = game.projectedLampXP(lamp, on: skill)
        let newXP = game.xp(for: skill) + projected
        let newLevel = XPTable.level(forXP: min(newXP, XPTable.xpCap))
        let method = game.currentMethod(for: skill)
        let maxed = game.isMaxXP(skill)
        return Button {
            _ = game.applyDiaryLamp(lamp, to: skill)
            if game.diaryLamps.isEmpty { dismiss() }
        } label: {
            HStack(spacing: 12) {
                ArtworkView(art: method.art, size: 30, color: skill.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.displayName).font(.subheadline.weight(.semibold))
                    Text("Lv \(level)\(newLevel > level ? " → \(newLevel)" : "")")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if maxed {
                    Text("MAX").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                } else {
                    Text("+\(Format.abbrevCompact(projected)) XP")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(Color.rewardToken)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .diaryCard()
            .opacity(maxed ? 0.55 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(maxed)
    }
}

// MARK: - Overview tab

private struct DiaryOverview: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.horizontalSizeClass) private var hSize

    /// Incomplete Tasks you're closest to finishing — targets to chase. More are shown on wide
    /// screens where a two-column grid has room for them.
    private var closest: [Task] {
        TaskCatalog.all
            .filter { !game.isTaskComplete($0) }
            .sorted { game.taskFraction($0) > game.taskFraction($1) }
            .prefix(Layout.isWide(hSize) ? 6 : 4)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 16) {
            if !game.diaryLamps.isEmpty { DiaryLampInventoryCard() }
            overallCard
            if !closest.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("CLOSEST TASKS", systemImage: "target")
                    LazyVGrid(columns: Layout.columns(hSize, count: 2, spacing: 10), spacing: 10) {
                        ForEach(closest) { TaskRow(task: $0) }
                    }
                }
            }
        }
    }

    private var overallCard: some View {
        let done = game.totalTasksCompleted
        let total = TaskCatalog.all.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("OVERALL", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(done) / \(total)")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
            }
            XPProgressBar(progress: total > 0 ? Double(done) / Double(total) : 0,
                          tint: .rewardToken, height: 8)
            Text(done == total ? "Every Task complete — you legend."
                               : "Complete Tasks to earn Tokens.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .diaryCard()
    }
}

// MARK: - All Tasks tab (Diary list)

private struct DiaryTaskList: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.horizontalSizeClass) private var hSize
    var body: some View {
        LazyVGrid(columns: Layout.columns(hSize, count: 2, spacing: 12), spacing: 12) {
            ForEach(TaskDiary.allCases) { diary in
                NavigationLink(value: diary) {
                    DiaryCard(diary: diary)
                }
                .buttonStyle(PressableStyle(scale: 0.98))
            }
        }
    }
}

private struct DiaryCard: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.horizontalSizeClass) private var hSize
    let diary: TaskDiary

    var body: some View {
        let tasks = TaskCatalog.tasks(in: diary)
        let done = game.completedCount(in: diary)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(diary.tint.opacity(0.24)).frame(width: 44, height: 44)
                Image(systemName: diary.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(diary.tint)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(diary.title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                    Spacer()
                    Text("\(done)/\(tasks.count)")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(done == tasks.count ? .green : .secondary)
                }
                Text(diary.subtitle).font(.caption2).foregroundStyle(.secondary)
                XPProgressBar(progress: tasks.isEmpty ? 0 : Double(done) / Double(tasks.count),
                              tint: diary.tint, height: 5)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(14)
        .contentShape(Rectangle())
        .diaryCard(cornerRadius: 14, fillHeight: Layout.isWide(hSize))
    }
}

// MARK: - Diary detail (all Tasks in one Diary, grouped by tier)

struct TaskDiaryDetailView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.horizontalSizeClass) private var hSize
    let diary: TaskDiary

    private let tiers = TaskTier.allCases.sorted { $0.order < $1.order }

    var body: some View {
        ZStack {
            GameBackground()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        ForEach(tiers) { tier in
                            let tasks = TaskCatalog.group(diary, tier)
                            if !tasks.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    tierHeader(tier, tasks: tasks)
                                    LazyVGrid(columns: Layout.columns(hSize, count: 2, spacing: 10), spacing: 10) {
                                        ForEach(tasks) { TaskRow(task: $0) }
                                    }
                                }
                                .id(tier)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: Layout.maxWidth(hSize, compact: 720, regular: 1180))
                    .frame(maxWidth: .infinity)
                }
                .onAppear {
                    #if DEBUG
                    if let raw = ProcessInfo.processInfo.environment["SCROLL_TIER"],
                       let tier = TaskTier(rawValue: raw) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            withAnimation { proxy.scrollTo(tier, anchor: .top) }
                        }
                    }
                    #endif
                }
            }
        }
        .navigationTitle(diary.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        let tasks = TaskCatalog.tasks(in: diary)
        let done = game.completedCount(in: diary)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(diary.tint.opacity(0.24)).frame(width: 48, height: 48)
                Image(systemName: diary.icon).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(diary.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(diary.subtitle).font(.subheadline.weight(.semibold))
                XPProgressBar(progress: tasks.isEmpty ? 0 : Double(done) / Double(tasks.count),
                              tint: diary.tint, height: 7)
                Text("\(done) / \(tasks.count) Tasks complete")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .diaryCard()
    }

    private func tierHeader(_ tier: TaskTier, tasks: [Task]) -> some View {
        let complete = game.isDiaryTierComplete(diary, tier)
        let lampColor = SkillCategory.raidTierColor(tier.lampTier)
        return HStack(spacing: 8) {
            Text(tier.displayName.uppercased())
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(tier.tint.opacity(0.22), in: Capsule())
                .overlay(Capsule().strokeBorder(tier.tint.opacity(0.5)))
                .foregroundStyle(tier.tint)
            HStack(spacing: 4) {
                ArtworkView(art: .vector(.genieLamp), size: 12, color: lampColor)
                Text("\(SkillCategory.raidTierName(tier.lampTier)) Lamp")
                    .font(.caption2).foregroundStyle(complete ? lampColor : .secondary)
            }
            Spacer()
            if complete {
                Label("Cleared", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Shared Task row

private struct TaskRow: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.horizontalSizeClass) private var hSize
    let task: Task

    var body: some View {
        let done = game.isTaskComplete(task)
        let progress = game.taskProgress(task)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill((done ? Color.green : task.tier.tint).opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: done ? "checkmark" : task.diary.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(done ? .green : task.tier.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(done ? .secondary : .primary)
                    Spacer()
                    TokenTag(amount: task.tokenReward, earned: done)
                }
                Text(task.detail).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if task.isCounter && !done {
                    XPProgressBar(progress: game.taskFraction(task), tint: task.tier.tint, height: 5)
                    Text("\(progress) / \(task.goal)")
                        .font(.caption2.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .diaryCard(cornerRadius: 12, fillHeight: Layout.isWide(hSize))
    }
}

/// Small gold Token amount pill; dims to a check-style once earned.
private struct TokenTag: View {
    let amount: Int
    let earned: Bool
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.circle.fill").font(.caption2)
            Text("\(amount)").font(.caption2.weight(.bold)).monospacedDigit()
        }
        .foregroundStyle(earned ? Color.rewardToken : Color.rewardToken.opacity(0.65))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.rewardToken.opacity(earned ? 0.20 : 0.10), in: Capsule())
    }
}

// MARK: - Small helpers

private func sectionHeader(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
        .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
}

private extension View {
    /// The app's translucent card treatment used throughout the Diary. When `fillHeight` is true the
    /// card stretches to fill its row's height (content stays top-aligned) so side-by-side cards in a
    /// two-column grid match heights on wide screens.
    func diaryCard(cornerRadius: CGFloat = 16, fillHeight: Bool = false) -> some View {
        frame(maxWidth: fillHeight ? .infinity : nil,
              maxHeight: fillHeight ? .infinity : nil,
              alignment: .topLeading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.white.opacity(0.08)))
    }
}
