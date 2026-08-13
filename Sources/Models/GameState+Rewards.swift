import Foundation

/// The Diary reward engine: lifetime counter bookkeeping, Task evaluation, Reward Token
/// payouts, and the query helpers the Diary UI reads. The *state* (tokens, counters, completed tasks)
/// lives on `GameState` so it persists with the save; the *logic* lives here to keep the core
/// `GameState.swift` focused on gameplay. See `docs/ACHIEVEMENTS.md`.
///
/// Everything is `@MainActor` (inherited from `GameState`), so Task progress closures — which read
/// game state — are always evaluated on the main actor.
extension GameState {

    // MARK: - Counters

    /// Current value of a lifetime tally (0 if never incremented). Read by Task progress closures.
    func taskCounter(_ key: String) -> Int { taskCounters[key] ?? 0 }

    /// Increment a lifetime tally by `amount` (default 1). Keys come from `TaskCounter`.
    func bumpCounter(_ key: String, by amount: Int = 1) {
        guard amount != 0 else { return }
        taskCounters[key, default: 0] += amount
    }

    /// Raise a high-water-mark tally to `value` (only grows). Used for "best combo", "best offline".
    func raiseCounter(_ key: String, to value: Int) {
        if value > (taskCounters[key] ?? 0) { taskCounters[key] = value }
    }

    // MARK: - Tokens

    /// Grant Reward Tokens (ignores non-positive amounts).
    func addTokens(_ count: Int) {
        guard count > 0 else { return }
        tokens += count
    }

    // MARK: - Task evaluation

    /// Convenience for the many single-trigger hooks.
    func evaluateTasks(_ trigger: TaskTrigger) { evaluateTasks([trigger]) }

    /// Re-check every Task registered for any of `triggers`, complete any whose progress has reached
    /// its goal, pay out Tokens (plus any Diary-tier completion bonus newly earned), and surface a
    /// single celebratory `taskEvent` for the batch. Cheap and idempotent — safe to call on every
    /// relevant hook. Persists via `save()` only when something actually changes.
    func evaluateTasks(_ triggers: Set<TaskTrigger>) {
        guard !triggers.isEmpty else { return }

        var considered = Set<String>()
        var newlyCompleted: [Task] = []
        for trigger in triggers {
            for task in TaskCatalog.byTrigger[trigger] ?? [] {
                guard !completedTasks.contains(task.id),
                      considered.insert(task.id).inserted else { continue }
                if task.progress(self) >= task.goal { newlyCompleted.append(task) }
            }
        }
        guard !newlyCompleted.isEmpty else { return }

        var awarded = 0
        for task in newlyCompleted {
            completedTasks.insert(task.id)
            awarded += task.tokenReward
        }

        // Any (diary, tier) group that just became fully complete pays a landmark bonus once.
        var completedGroups: [(diary: TaskDiary, tier: TaskTier)] = []
        var checkedGroups = Set<String>()
        for task in newlyCompleted {
            let key = groupKey(task.diary, task.tier)
            guard checkedGroups.insert(key).inserted, !claimedDiaryTiers.contains(key) else { continue }
            if TaskCatalog.group(task.diary, task.tier).allSatisfy({ completedTasks.contains($0.id) }) {
                claimedDiaryTiers.insert(key)
                awarded += Balance.Rewards.diaryTierBonus(for: task.tier)
                completedGroups.append((task.diary, task.tier))
            }
        }

        addTokens(awarded)
        taskEvent = makeTaskEvent(tasks: newlyCompleted, groups: completedGroups, tokens: awarded)
        save()
    }

    private func groupKey(_ diary: TaskDiary, _ tier: TaskTier) -> String {
        "\(diary.rawValue).\(tier.rawValue)"
    }

    /// Builds the toast for a batch of completions, leading with the biggest news (a Diary-tier
    /// clear beats a single Task, which beats a generic multi-Task batch).
    private func makeTaskEvent(tasks: [Task], groups: [(diary: TaskDiary, tier: TaskTier)],
                               tokens: Int) -> TaskEvent {
        if let group = groups.last {
            return TaskEvent(
                title: "\(group.diary.title) — \(group.tier.displayName) complete!",
                subtitle: tasks.count == 1 ? tasks[0].title : "\(tasks.count) Tasks cleared",
                tokens: tokens, icon: "rosette", tint: group.tier.tint)
        }
        if tasks.count == 1 {
            let task = tasks[0]
            return TaskEvent(title: task.title, subtitle: "\(task.diary.title) • \(task.tier.displayName) Task",
                             tokens: tokens, icon: task.diary.icon, tint: task.tier.tint)
        }
        return TaskEvent(title: "\(tasks.count) Tasks complete!", subtitle: "Diary",
                         tokens: tokens, icon: "checkmark.seal.fill", tint: TaskTier.elite.tint)
    }

    // MARK: - UI queries

    /// Whether a Task has been completed.
    func isTaskComplete(_ task: Task) -> Bool { completedTasks.contains(task.id) }

    /// Live progress toward a Task's goal, clamped to `[0, goal]` for display.
    func taskProgress(_ task: Task) -> Int { min(max(task.progress(self), 0), task.goal) }

    /// Fractional progress `[0, 1]` toward a Task's goal, for progress bars.
    func taskFraction(_ task: Task) -> Double {
        guard task.goal > 0 else { return 0 }
        return Double(taskProgress(task)) / Double(task.goal)
    }

    /// Completed Tasks within one Diary (counts against the live catalog, ignoring any stale IDs).
    func completedCount(in diary: TaskDiary) -> Int {
        TaskCatalog.tasks(in: diary).reduce(0) { $0 + (completedTasks.contains($1.id) ? 1 : 0) }
    }

    /// Whether every Task in a (Diary, tier) group is complete.
    func isDiaryTierComplete(_ diary: TaskDiary, _ tier: TaskTier) -> Bool {
        let group = TaskCatalog.group(diary, tier)
        return !group.isEmpty && group.allSatisfy { completedTasks.contains($0.id) }
    }

    /// Total Tasks completed across the whole game (vs. `TaskCatalog.all.count`).
    var totalTasksCompleted: Int {
        TaskCatalog.all.reduce(0) { $0 + (completedTasks.contains($1.id) ? 1 : 0) }
    }
}
