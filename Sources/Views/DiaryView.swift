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
                        TokenBalanceCard()
                        Picker("View", selection: $tab) {
                            ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch tab {
                        case .overview: DiaryOverview()
                        case .tasks:    DiaryTaskList()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 720)
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
                Text("REWARD TOKENS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
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

// MARK: - Overview tab

private struct DiaryOverview: View {
    @EnvironmentObject private var game: GameState

    /// Incomplete Tasks you're closest to finishing — targets to chase.
    private var closest: [Task] {
        TaskCatalog.all
            .filter { !game.isTaskComplete($0) }
            .sorted { game.taskFraction($0) > game.taskFraction($1) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 16) {
            overallCard
            if !closest.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("CLOSEST TASKS", systemImage: "target")
                    VStack(spacing: 10) {
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
                               : "Complete Tasks to earn Reward Tokens.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .diaryCard()
    }
}

// MARK: - All Tasks tab (Diary list)

private struct DiaryTaskList: View {
    @EnvironmentObject private var game: GameState
    var body: some View {
        VStack(spacing: 12) {
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
        .diaryCard(cornerRadius: 14)
    }
}

// MARK: - Diary detail (all Tasks in one Diary, grouped by tier)

struct TaskDiaryDetailView: View {
    @EnvironmentObject private var game: GameState
    let diary: TaskDiary

    private let tiers = TaskTier.allCases.sorted { $0.order < $1.order }

    var body: some View {
        ZStack {
            GameBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    ForEach(tiers) { tier in
                        let tasks = TaskCatalog.group(diary, tier)
                        if !tasks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                tierHeader(tier, tasks: tasks)
                                VStack(spacing: 10) {
                                    ForEach(tasks) { TaskRow(task: $0) }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
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
        return HStack(spacing: 8) {
            Text(tier.displayName.uppercased())
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(tier.tint.opacity(0.22), in: Capsule())
                .overlay(Capsule().strokeBorder(tier.tint.opacity(0.5)))
                .foregroundStyle(tier.tint)
            Text("+\(Balance.Rewards.diaryTierBonus) bonus")
                .font(.caption2).foregroundStyle(.secondary)
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
        .diaryCard(cornerRadius: 12)
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
    /// The app's translucent card treatment used throughout the Diary.
    func diaryCard(cornerRadius: CGFloat = 16) -> some View {
        background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.white.opacity(0.08)))
    }
}
