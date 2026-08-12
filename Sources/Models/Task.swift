import SwiftUI

/// A just-completed reward, surfaced by the UI as a celebratory toast. Either a single Task, a
/// batch of Tasks completed together, or a Diary-tier completion — carrying the Tokens awarded.
struct TaskEvent: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let tokens: Int
    /// SF Symbol for the toast glyph.
    let icon: String
    let tint: Color
}

/// Difficulty tier of a Task within its Diary. Higher tiers pay out more Reward Tokens.
/// The Token values themselves are centralized in `Balance.Rewards` so re-balancing never
/// touches this file.
enum TaskTier: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard, elite, master

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        case .elite:  return "Elite"
        case .master: return "Master"
        }
    }

    /// Reward Tokens granted for completing a single Task of this tier.
    var tokenReward: Int {
        switch self {
        case .easy:   return Balance.Rewards.tokensEasy
        case .medium: return Balance.Rewards.tokensMedium
        case .hard:   return Balance.Rewards.tokensHard
        case .elite:  return Balance.Rewards.tokensElite
        case .master: return Balance.Rewards.tokensMaster
        }
    }

    /// Sort order low → high difficulty.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// Tier tint used for badges and progress accents.
    var tint: Color {
        switch self {
        case .easy:   return Color(red: 0.45, green: 0.70, blue: 0.42) // green
        case .medium: return Color(red: 0.36, green: 0.60, blue: 0.86) // blue
        case .hard:   return Color(red: 0.78, green: 0.55, blue: 0.28) // bronze/orange
        case .elite:  return Color(red: 0.62, green: 0.42, blue: 0.86) // violet
        case .master: return Color(red: 0.85, green: 0.32, blue: 0.36) // red
        }
    }
}

/// A themed set of Tasks. Mirrors OSRS Achievement Diaries, re-themed around the account's
/// actual activities (there are no regions in XP Waste).
enum TaskDiary: String, Codable, CaseIterable, Identifiable {
    case combat, production, utility, gathering, idler, tycoon, completionist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .combat:        return "Combat Diary"
        case .production:     return "Production Diary"
        case .utility:        return "Utility Diary"
        case .gathering:      return "Gathering Diary"
        case .idler:          return "Idler's Diary"
        case .tycoon:         return "Tycoon's Diary"
        case .completionist:  return "Completionist's Diary"
        }
    }

    var subtitle: String {
        switch self {
        case .combat:        return "Master the six combat skills"
        case .production:    return "Forge, craft, and build"
        case .utility:       return "Speed, stealth, and cunning"
        case .gathering:     return "Harvest the world"
        case .idler:         return "AFK slots & offline gains"
        case .tycoon:        return "Boosts, cells, and multipliers"
        case .completionist: return "The long road to a maxed account"
        }
    }

    /// SF Symbol shown on the Diary card.
    var icon: String {
        switch self {
        case .combat:        return "shield.lefthalf.filled"
        case .production:    return "hammer.fill"
        case .utility:       return "figure.run"
        case .gathering:     return "leaf.fill"
        case .idler:         return "moon.zzz.fill"
        case .tycoon:        return "sparkles"
        case .completionist: return "seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .combat:        return Color(red: 0.72, green: 0.20, blue: 0.18)
        case .production:    return Color(red: 0.42, green: 0.44, blue: 0.48)
        case .utility:       return Color(red: 0.62, green: 0.49, blue: 0.28)
        case .gathering:     return Color(red: 0.40, green: 0.62, blue: 0.30)
        case .idler:         return Color(red: 0.33, green: 0.47, blue: 0.82)
        case .tycoon:        return Color.doubleXP
        case .completionist: return Color(red: 0.87, green: 0.76, blue: 0.36)
        }
    }
}

/// The kind of event that can advance a Task's progress. Tasks are indexed by trigger so a hook
/// only re-checks the handful of Tasks that could actually have changed — no per-frame scans.
enum TaskTrigger: Hashable {
    case levelUp        // any skill gained a level (also fires on offline level-ups)
    case tap            // a training tap resolved
    case crit           // a tap landed a critical
    case cache          // a tap yielded a bonus cache
    case energyProc     // a tap banked Supercharge Energy
    case energyFull     // a skill's Energy meter reached its cap
    case supercharge    // a Supercharge burst was triggered
    case boost          // an XP Boost was activated
    case energyCell     // an Energy Cell was consumed
    case slot           // an AFK slot assignment changed
    case offlineReturn  // returned from an offline session with credited XP
    case refund         // Thieving refunded a coupon or Supercharge
    case combo          // the Agility combo multiplier advanced
    case currency       // a consumable balance (coupons) changed
}

/// Stable string keys for the lifetime tallies the reward engine keeps. Kept as raw strings so
/// they persist compactly in `taskCounters` and can't drift from the Task catalog.
enum TaskCounter {
    static let taps = "taps"
    static let crits = "crits"
    static let caches = "caches"
    static let energyProcs = "energyProcs"
    static let supercharges = "supercharges"
    static let combatSupercharges = "combatSupercharges"
    static let boosts = "boosts"
    static let energyCells = "energyCells"
    static let offlineReturns = "offlineReturns"
    static let refunds = "refunds"
    static let levelUps = "levelUps"
    static let stackedBursts = "stackedBursts"
    static let bestComboBips = "bestComboBips"     // max comboMultiplier ×100 ever reached
    static let bestOfflineXP = "bestOfflineXP"     // largest single offline-return XP
}

/// A single, checkable achievement. `progress(game)` returns the current value toward `goal`
/// (a one-shot Task uses `goal == 1`); the Task is complete once progress reaches the goal.
///
/// The closure is `@MainActor` because it reads `GameState` (which is main-actor isolated); it's
/// only ever evaluated from the main actor (the reward engine and SwiftUI views).
struct Task: Identifiable {
    typealias Progress = @MainActor (GameState) -> Int

    let id: String
    let diary: TaskDiary
    let tier: TaskTier
    let title: String
    let detail: String
    let goal: Int
    /// Events that can change this Task's progress.
    let triggers: Set<TaskTrigger>
    /// Current progress toward `goal` (unclamped; the engine/UI clamp for display).
    let progress: Progress

    /// True when this Task tracks a running count worth showing as "n / goal" (goal > 1).
    var isCounter: Bool { goal > 1 }

    var tokenReward: Int { tier.tokenReward }
}

/// The static Task catalog and lookup indexes. Pure data — like `TrainingMethod` flavor, it holds
/// no state. Progress is computed live from `GameState`.
enum TaskCatalog {

    /// Every Task in the game, grouped by Diary in declaration order.
    static let all: [Task] = combat + production + utility + gathering + idler + tycoon + completionist

    /// Tasks for one Diary, in tier order.
    static func tasks(in diary: TaskDiary) -> [Task] {
        all.filter { $0.diary == diary }.sorted { $0.tier.order < $1.tier.order }
    }

    /// Tasks registered for a given trigger (for cheap, targeted evaluation).
    static let byTrigger: [TaskTrigger: [Task]] = {
        var map: [TaskTrigger: [Task]] = [:]
        for task in all {
            for trigger in task.triggers { map[trigger, default: []].append(task) }
        }
        return map
    }()

    /// Tasks sharing a (diary, tier) group — used to award the diary-tier completion bonus.
    static func group(_ diary: TaskDiary, _ tier: TaskTier) -> [Task] {
        all.filter { $0.diary == diary && $0.tier == tier }
    }

    // MARK: Progress helpers

    @MainActor
    private static func maxLevel(in category: SkillCategory, _ game: GameState) -> Int {
        SkillID.skills(in: category).map { game.level(for: $0) }.max() ?? 1
    }

    @MainActor
    private static func maxedCount(in category: SkillCategory, _ game: GameState) -> Int {
        SkillID.skills(in: category).filter { game.isMaxed($0) }.count
    }

    @MainActor
    private static func hasTier6(in category: SkillCategory, _ game: GameState) -> Int {
        SkillID.skills(in: category).contains { game.level(for: $0) >= Balance.trainingTiers.last!.unlockLevel } ? 1 : 0
    }

    // MARK: - Diaries

    static let combat: [Task] = [
        Task(id: "combat.first_crit", diary: .combat, tier: .easy,
             title: "First Blood", detail: "Land your first critical tap.",
             goal: 1, triggers: [.crit]) { $0.taskCounter(TaskCounter.crits) },
        Task(id: "combat.level10", diary: .combat, tier: .easy,
             title: "Warmed Up", detail: "Reach level 10 in any combat skill.",
             goal: 10, triggers: [.levelUp]) { maxLevel(in: .combat, $0) },
        Task(id: "combat.supercharge3", diary: .combat, tier: .medium,
             title: "Berserker", detail: "Trigger 3 Supercharges on combat skills.",
             goal: 3, triggers: [.supercharge]) { $0.taskCounter(TaskCounter.combatSupercharges) },
        Task(id: "combat.level40", diary: .combat, tier: .medium,
             title: "Seasoned Fighter", detail: "Reach level 40 in any combat skill.",
             goal: 40, triggers: [.levelUp]) { maxLevel(in: .combat, $0) },
        Task(id: "combat.level60", diary: .combat, tier: .hard,
             title: "Battle-Hardened", detail: "Reach level 60 in any combat skill.",
             goal: 60, triggers: [.levelUp]) { maxLevel(in: .combat, $0) },
        Task(id: "combat.tier6", diary: .combat, tier: .elite,
             title: "Weaponmaster", detail: "Unlock a tier-6 method on any combat skill.",
             goal: 1, triggers: [.levelUp]) { hasTier6(in: .combat, $0) },
        Task(id: "combat.all99", diary: .combat, tier: .master,
             title: "Combat Legend", detail: "Reach level 99 in all six combat skills.",
             goal: 6, triggers: [.levelUp]) { maxedCount(in: .combat, $0) }
    ]

    static let production: [Task] = [
        Task(id: "prod.level10", diary: .production, tier: .easy,
             title: "Apprentice", detail: "Reach level 10 in any production skill.",
             goal: 10, triggers: [.levelUp]) { maxLevel(in: .production, $0) },
        Task(id: "prod.tier2", diary: .production, tier: .easy,
             title: "First Upgrade", detail: "Unlock a tier-2 method on any production skill.",
             goal: 15, triggers: [.levelUp]) { maxLevel(in: .production, $0) },
        Task(id: "prod.level40", diary: .production, tier: .medium,
             title: "Craftsman", detail: "Reach level 40 in any production skill.",
             goal: 40, triggers: [.levelUp]) { maxLevel(in: .production, $0) },
        Task(id: "prod.level70", diary: .production, tier: .hard,
             title: "Master Artisan", detail: "Reach level 70 in any production skill.",
             goal: 70, triggers: [.levelUp]) { maxLevel(in: .production, $0) },
        Task(id: "prod.tier6", diary: .production, tier: .elite,
             title: "Grandmaster Smith", detail: "Unlock a tier-6 method on any production skill.",
             goal: 1, triggers: [.levelUp]) { hasTier6(in: .production, $0) },
        Task(id: "prod.all99", diary: .production, tier: .master,
             title: "Production Legend", detail: "Reach level 99 in all seven production skills.",
             goal: 7, triggers: [.levelUp]) { maxedCount(in: .production, $0) }
    ]

    static let utility: [Task] = [
        Task(id: "util.combo120", diary: .utility, tier: .easy,
             title: "Nimble", detail: "Build a ×1.2 tap combo.",
             goal: 120, triggers: [.combo]) { $0.taskCounter(TaskCounter.bestComboBips) },
        Task(id: "util.combo140", diary: .utility, tier: .medium,
             title: "In the Zone", detail: "Build a ×1.4 tap combo.",
             goal: 140, triggers: [.combo]) { $0.taskCounter(TaskCounter.bestComboBips) },
        Task(id: "util.refund", diary: .utility, tier: .medium,
             title: "Light Fingers", detail: "Pickpocket back a coupon or Supercharge.",
             goal: 1, triggers: [.refund]) { $0.taskCounter(TaskCounter.refunds) },
        Task(id: "util.level60", diary: .utility, tier: .hard,
             title: "Untouchable", detail: "Reach level 60 in any utility skill.",
             goal: 60, triggers: [.levelUp]) { maxLevel(in: .utility, $0) },
        Task(id: "util.tier6", diary: .utility, tier: .elite,
             title: "Shadow", detail: "Unlock a tier-6 method on any utility skill.",
             goal: 1, triggers: [.levelUp]) { hasTier6(in: .utility, $0) },
        Task(id: "util.all99", diary: .utility, tier: .master,
             title: "Utility Legend", detail: "Reach level 99 in all five utility skills.",
             goal: 5, triggers: [.levelUp]) { maxedCount(in: .utility, $0) }
    ]

    static let gathering: [Task] = [
        Task(id: "gather.energyFull", diary: .gathering, tier: .easy,
             title: "Full Charge", detail: "Fill a skill's Energy meter to the cap.",
             goal: 1, triggers: [.energyFull]) { game in
                SkillID.allCases.contains { game.isEnergyFull($0) } ? 1 : 0
             },
        Task(id: "gather.level10", diary: .gathering, tier: .easy,
             title: "Forager", detail: "Reach level 10 in any gathering skill.",
             goal: 10, triggers: [.levelUp]) { maxLevel(in: .gathering, $0) },
        Task(id: "gather.caches10", diary: .gathering, tier: .medium,
             title: "Nest Collector", detail: "Collect 10 bonus caches.",
             goal: 10, triggers: [.cache]) { $0.taskCounter(TaskCounter.caches) },
        Task(id: "gather.energyCap40", diary: .gathering, tier: .medium,
             title: "Deep Diver", detail: "Raise your Energy cap to 40 seconds.",
             goal: 40, triggers: [.levelUp]) { Int($0.energyCapSeconds) },
        Task(id: "gather.level60", diary: .gathering, tier: .hard,
             title: "Naturalist", detail: "Reach level 60 in any gathering skill.",
             goal: 60, triggers: [.levelUp]) { maxLevel(in: .gathering, $0) },
        Task(id: "gather.caches100", diary: .gathering, tier: .elite,
             title: "Bounty Hunter", detail: "Collect 100 bonus caches.",
             goal: 100, triggers: [.cache]) { $0.taskCounter(TaskCounter.caches) },
        Task(id: "gather.all99", diary: .gathering, tier: .master,
             title: "Gathering Legend", detail: "Reach level 99 in all five gathering skills.",
             goal: 5, triggers: [.levelUp]) { maxedCount(in: .gathering, $0) }
    ]

    static let idler: [Task] = [
        Task(id: "idle.slot1", diary: .idler, tier: .easy,
             title: "First Slot", detail: "Assign a skill to an AFK slot.",
             goal: 1, triggers: [.slot]) { $0.slots.count },
        Task(id: "idle.return1", diary: .idler, tier: .easy,
             title: "Well Rested", detail: "Return from an offline session.",
             goal: 1, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.offlineReturns) },
        Task(id: "idle.unlock_slot2", diary: .idler, tier: .easy,
             title: "Second Slot",
             detail: "Reach total level \(Balance.slotUnlockTotalLevels[0]) to unlock your 2nd AFK slot.",
             goal: Balance.slotUnlockTotalLevels[0], triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "idle.slot2", diary: .idler, tier: .medium,
             title: "Double Duty", detail: "Fill two AFK slots at once.",
             goal: 2, triggers: [.slot]) { $0.slots.count },
        Task(id: "idle.offline100k", diary: .idler, tier: .medium,
             title: "Overnight", detail: "Earn 100k XP in a single offline return.",
             goal: 100_000, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.bestOfflineXP) },
        Task(id: "idle.unlock_slot3", diary: .idler, tier: .medium,
             title: "Third Slot",
             detail: "Reach total level \(Balance.slotUnlockTotalLevels[1]) to unlock your 3rd AFK slot.",
             goal: Balance.slotUnlockTotalLevels[1], triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "idle.slot5", diary: .idler, tier: .hard,
             title: "Fully Staffed", detail: "Fill all five AFK slots at once.",
             goal: 5, triggers: [.slot]) { $0.slots.count },
        Task(id: "idle.unlock_slot4", diary: .idler, tier: .hard,
             title: "Fourth Slot",
             detail: "Reach total level \(Balance.slotUnlockTotalLevels[2]) to unlock your 4th AFK slot.",
             goal: Balance.slotUnlockTotalLevels[2], triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "idle.offline500k", diary: .idler, tier: .elite,
             title: "Big Sleeper", detail: "Earn 500k XP in a single offline return.",
             goal: 500_000, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.bestOfflineXP) },
        Task(id: "idle.total1000", diary: .idler, tier: .master,
             title: "Idle Empire",
             detail: "Reach total level \(Balance.slotUnlockTotalLevels[3]) to unlock your 5th AFK slot.",
             goal: Balance.slotUnlockTotalLevels[3], triggers: [.levelUp]) { $0.totalLevel }
    ]

    static let tycoon: [Task] = [
        Task(id: "tycoon.boost1", diary: .tycoon, tier: .easy,
             title: "First Boost", detail: "Activate an XP Boost.",
             goal: 1, triggers: [.boost]) { $0.taskCounter(TaskCounter.boosts) },
        Task(id: "tycoon.cell1", diary: .tycoon, tier: .easy,
             title: "Recharged", detail: "Use an Energy Cell.",
             goal: 1, triggers: [.energyCell]) { $0.taskCounter(TaskCounter.energyCells) },
        Task(id: "tycoon.stack", diary: .tycoon, tier: .medium,
             title: "Double Trouble", detail: "Tap with a Boost and Supercharge both active.",
             goal: 1, triggers: [.tap]) { $0.taskCounter(TaskCounter.stackedBursts) },
        Task(id: "tycoon.coupons5", diary: .tycoon, tier: .medium,
             title: "Coupon Hoarder", detail: "Hold five Boost Coupons at once.",
             goal: 5, triggers: [.currency]) { $0.doubleXPCoupons },
        Task(id: "tycoon.boost10", diary: .tycoon, tier: .hard,
             title: "Power User", detail: "Activate 10 XP Boosts.",
             goal: 10, triggers: [.boost]) { $0.taskCounter(TaskCounter.boosts) },
        Task(id: "tycoon.cells25", diary: .tycoon, tier: .elite,
             title: "Energy Baron", detail: "Use 25 Energy Cells.",
             goal: 25, triggers: [.energyCell]) { $0.taskCounter(TaskCounter.energyCells) },
        Task(id: "tycoon.boost50", diary: .tycoon, tier: .master,
             title: "Tycoon", detail: "Activate 50 XP Boosts.",
             goal: 50, triggers: [.boost]) { $0.taskCounter(TaskCounter.boosts) }
    ]

    static let completionist: [Task] = [
        Task(id: "comp.total250", diary: .completionist, tier: .medium,
             title: "Journeyman", detail: "Reach total level 250.",
             goal: 250, triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "comp.first99", diary: .completionist, tier: .hard,
             title: "First 99", detail: "Reach level 99 in any skill.",
             goal: 1, triggers: [.levelUp]) { $0.maxedSkillCount },
        Task(id: "comp.total750", diary: .completionist, tier: .hard,
             title: "Veteran", detail: "Reach total level 750.",
             goal: 750, triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "comp.combat", diary: .completionist, tier: .elite,
             title: "Combat Cape", detail: "Reach level 99 in every combat skill.",
             goal: 6, triggers: [.levelUp]) { maxedCount(in: .combat, $0) },
        Task(id: "comp.production", diary: .completionist, tier: .elite,
             title: "Production Cape", detail: "Reach level 99 in every production skill.",
             goal: 7, triggers: [.levelUp]) { maxedCount(in: .production, $0) },
        Task(id: "comp.utility", diary: .completionist, tier: .elite,
             title: "Utility Cape", detail: "Reach level 99 in every utility skill.",
             goal: 5, triggers: [.levelUp]) { maxedCount(in: .utility, $0) },
        Task(id: "comp.gathering", diary: .completionist, tier: .elite,
             title: "Gathering Cape", detail: "Reach level 99 in every gathering skill.",
             goal: 5, triggers: [.levelUp]) { maxedCount(in: .gathering, $0) },
        Task(id: "comp.maxcape", diary: .completionist, tier: .master,
             title: "Max Cape", detail: "Reach level 99 in all 23 skills.",
             goal: SkillID.allCases.count, triggers: [.levelUp]) { $0.maxedSkillCount },
        Task(id: "comp.eternal", diary: .completionist, tier: .master,
             title: "Eternal", detail: "Reach the 200M XP ceiling in any skill.",
             goal: 1, triggers: [.levelUp]) { $0.maxXPSkillCount },
        Task(id: "comp.truecomp", diary: .completionist, tier: .master,
             title: "True Completionist", detail: "Reach 200M XP in every skill.",
             goal: SkillID.allCases.count, triggers: [.levelUp]) { $0.maxXPSkillCount }
    ]
}
