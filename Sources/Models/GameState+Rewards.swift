import Foundation

/// The Adventurer's Log reward engine: lifetime counter bookkeeping, Feat evaluation, Reward Token
/// payouts, and the query helpers the Log UI reads. The *state* (tokens, counters, completed feats)
/// lives on `GameState` so it persists with the save; the *logic* lives here to keep the core
/// `GameState.swift` focused on gameplay. See `docs/ACHIEVEMENTS.md`.
///
/// Everything is `@MainActor` (inherited from `GameState`), so Feat progress closures — which read
/// game state — are always evaluated on the main actor.
extension GameState {

    // MARK: - Counters

    /// Current value of a lifetime tally (0 if never incremented). Read by Feat progress closures.
    func featCounter(_ key: String) -> Int { featCounters[key] ?? 0 }

    /// Increment a lifetime tally by `amount` (default 1). Keys come from `FeatCounter`.
    func bumpCounter(_ key: String, by amount: Int = 1) {
        guard amount != 0 else { return }
        featCounters[key, default: 0] += amount
    }

    /// Raise a high-water-mark tally to `value` (only grows). Used for "best combo", "best offline".
    func raiseCounter(_ key: String, to value: Int) {
        if value > (featCounters[key] ?? 0) { featCounters[key] = value }
    }

    // MARK: - Tokens

    /// Grant Reward Tokens (ignores non-positive amounts).
    func addTokens(_ count: Int) {
        guard count > 0 else { return }
        tokens += count
    }

    // MARK: - Feat evaluation

    /// Convenience for the many single-trigger hooks.
    func evaluateFeats(_ trigger: FeatTrigger) { evaluateFeats([trigger]) }

    /// Re-check every Feat registered for any of `triggers`, complete any whose progress has reached
    /// its goal, pay out Tokens (plus any Diary-tier completion bonus newly earned), and surface a
    /// single celebratory `featEvent` for the batch. Cheap and idempotent — safe to call on every
    /// relevant hook. Persists via `save()` only when something actually changes.
    func evaluateFeats(_ triggers: Set<FeatTrigger>) {
        guard !triggers.isEmpty else { return }

        var considered = Set<String>()
        var newlyCompleted: [Feat] = []
        for trigger in triggers {
            for feat in FeatCatalog.byTrigger[trigger] ?? [] {
                guard !completedFeats.contains(feat.id),
                      considered.insert(feat.id).inserted else { continue }
                if feat.progress(self) >= feat.goal { newlyCompleted.append(feat) }
            }
        }
        guard !newlyCompleted.isEmpty else { return }

        var awarded = 0
        for feat in newlyCompleted {
            completedFeats.insert(feat.id)
            awarded += feat.tokenReward
        }

        // Any (diary, tier) group that just became fully complete pays a landmark bonus once.
        var completedGroups: [(diary: FeatDiary, tier: FeatTier)] = []
        var checkedGroups = Set<String>()
        for feat in newlyCompleted {
            let key = groupKey(feat.diary, feat.tier)
            guard checkedGroups.insert(key).inserted, !claimedDiaryTiers.contains(key) else { continue }
            if FeatCatalog.group(feat.diary, feat.tier).allSatisfy({ completedFeats.contains($0.id) }) {
                claimedDiaryTiers.insert(key)
                awarded += Balance.Rewards.diaryTierBonus
                completedGroups.append((feat.diary, feat.tier))
            }
        }

        addTokens(awarded)
        featEvent = makeFeatEvent(feats: newlyCompleted, groups: completedGroups, tokens: awarded)
        save()
    }

    private func groupKey(_ diary: FeatDiary, _ tier: FeatTier) -> String {
        "\(diary.rawValue).\(tier.rawValue)"
    }

    /// Builds the toast for a batch of completions, leading with the biggest news (a Diary-tier
    /// clear beats a single Feat, which beats a generic multi-Feat batch).
    private func makeFeatEvent(feats: [Feat], groups: [(diary: FeatDiary, tier: FeatTier)],
                               tokens: Int) -> FeatEvent {
        if let group = groups.last {
            return FeatEvent(
                title: "\(group.diary.title) — \(group.tier.displayName) complete!",
                subtitle: feats.count == 1 ? feats[0].title : "\(feats.count) Feats cleared",
                tokens: tokens, icon: "rosette", tint: group.tier.tint)
        }
        if feats.count == 1 {
            let feat = feats[0]
            return FeatEvent(title: feat.title, subtitle: "\(feat.diary.title) • \(feat.tier.displayName) Feat",
                             tokens: tokens, icon: feat.diary.icon, tint: feat.tier.tint)
        }
        return FeatEvent(title: "\(feats.count) Feats complete!", subtitle: "Adventurer's Log",
                         tokens: tokens, icon: "checkmark.seal.fill", tint: FeatTier.elite.tint)
    }

    // MARK: - UI queries

    /// Whether a Feat has been completed.
    func isFeatComplete(_ feat: Feat) -> Bool { completedFeats.contains(feat.id) }

    /// Live progress toward a Feat's goal, clamped to `[0, goal]` for display.
    func featProgress(_ feat: Feat) -> Int { min(max(feat.progress(self), 0), feat.goal) }

    /// Fractional progress `[0, 1]` toward a Feat's goal, for progress bars.
    func featFraction(_ feat: Feat) -> Double {
        guard feat.goal > 0 else { return 0 }
        return Double(featProgress(feat)) / Double(feat.goal)
    }

    /// Completed Feats within one Diary (counts against the live catalog, ignoring any stale IDs).
    func completedCount(in diary: FeatDiary) -> Int {
        FeatCatalog.feats(in: diary).reduce(0) { $0 + (completedFeats.contains($1.id) ? 1 : 0) }
    }

    /// Whether every Feat in a (Diary, tier) group is complete.
    func isDiaryTierComplete(_ diary: FeatDiary, _ tier: FeatTier) -> Bool {
        let group = FeatCatalog.group(diary, tier)
        return !group.isEmpty && group.allSatisfy { completedFeats.contains($0.id) }
    }

    /// Total Feats completed across the whole game (vs. `FeatCatalog.all.count`).
    var totalFeatsCompleted: Int {
        FeatCatalog.all.reduce(0) { $0 + (completedFeats.contains($1.id) ? 1 : 0) }
    }
}
