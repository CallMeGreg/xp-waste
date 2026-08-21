import SwiftUI

/// A just-completed reward, surfaced by the UI as a celebratory toast. Either a single Task, a
/// batch of Tasks completed together, or a Diary-tier completion — carrying the Tokens awarded and,
/// for a tier clear, the XP **lamp** granted.
struct TaskEvent: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let tokens: Int
    /// SF Symbol for the toast glyph.
    let icon: String
    let tint: Color
    /// When a Diary tier was just cleared, the lamp tier (0…5, Bronze→Rune) awarded — drives a lamp
    /// badge on the toast. `nil` for plain Task completions (which pay only Tokens).
    var lampTier: Int? = nil
}

/// Difficulty tier of a Task within its Diary. Higher tiers pay out more Reward Tokens per Task, and
/// completing an entire tier grants a matching XP **lamp** (see `lampTier`: Easy→Bronze … Grandmaster
/// →Rune). The Token values are centralized in `Balance.Rewards` so re-balancing never touches this
/// file. `grandmaster` is the end-game capstone tier — its Tasks demand 200M-XP-class feats.
enum TaskTier: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard, elite, master, grandmaster

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy:        return "Easy"
        case .medium:      return "Medium"
        case .hard:        return "Hard"
        case .elite:       return "Elite"
        case .master:      return "Master"
        case .grandmaster: return "Grandmaster"
        }
    }

    /// Reward Tokens granted for completing a single Task of this tier.
    var tokenReward: Int {
        switch self {
        case .easy:        return Balance.Rewards.tokensEasy
        case .medium:      return Balance.Rewards.tokensMedium
        case .hard:        return Balance.Rewards.tokensHard
        case .elite:       return Balance.Rewards.tokensElite
        case .master:      return Balance.Rewards.tokensMaster
        case .grandmaster: return Balance.Rewards.tokensGrandmaster
        }
    }

    /// Sort order low → high difficulty.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The XP-lamp tier (0…5, Bronze→Rune) awarded for clearing every Task in this tier of a Diary.
    /// Equals the tier's difficulty order, so an Easy clear grants a Bronze lamp and a Grandmaster
    /// clear a Rune lamp — the top of the lamp ladder (`Balance.lampTierCoefficients`).
    var lampTier: Int { order }

    /// Tier tint used for badges and progress accents.
    var tint: Color {
        switch self {
        case .easy:        return Color(red: 0.45, green: 0.70, blue: 0.42) // green
        case .medium:      return Color(red: 0.36, green: 0.60, blue: 0.86) // blue
        case .hard:        return Color(red: 0.78, green: 0.55, blue: 0.28) // bronze/orange
        case .elite:       return Color(red: 0.62, green: 0.42, blue: 0.86) // violet
        case .master:      return Color(red: 0.85, green: 0.32, blue: 0.36) // red
        case .grandmaster: return Color(red: 0.95, green: 0.77, blue: 0.30) // gold (capstone)
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
        case .idler:         return "Idle taps & offline gains"
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
    case tap            // a deliberate training tap resolved
    case idleTap        // an automatic/idle tap resolved (e.g. the Runecraft idle perk)
    case crit           // a tap landed a critical
    case cache          // a tap yielded a bonus cache
    case energyProc     // a tap banked Supercharge Energy
    case energyFull     // a skill's Energy meter reached its cap
    case supercharge    // a Supercharge burst was triggered
    case boost          // an XP Boost was activated
    case energyCell     // an Energy Cell was consumed
    case slot           // an AFK slot assignment changed
    case offlineReturn  // returned from an offline session with credited XP
    case refund         // Thieving refunded a coupon or Energy Cell
    case combo          // the Agility combo multiplier advanced
    case currency       // a consumable balance (coupons) changed
}

/// Stable string keys for the lifetime tallies the reward engine keeps. Kept as raw strings so
/// they persist compactly in `taskCounters` and can't drift from the Task catalog.
enum TaskCounter {
    static let taps = "taps"
    static let idleTaps = "idleTaps"               // automatic/idle taps (kept out of "tap" Tasks)
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
    static let boostTaps = "boostTaps"             // taps landed while an XP Boost was live
    static let superchargeTaps = "superchargeTaps" // taps landed while that skill was Supercharged

    /// Per-skill lifetime tap tally. Namespaced so each skill keeps its own key and the group
    /// Tasks can sum across a category's skills.
    static func skillTaps(_ skill: SkillID) -> String { "taps." + skill.rawValue }
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

    /// How many skills in a category have reached at least `level` — for "all skills to N" sweeps.
    @MainActor
    private static func count(atLeast level: Int, in category: SkillCategory, _ game: GameState) -> Int {
        SkillID.skills(in: category).filter { game.level(for: $0) >= level }.count
    }

    /// How many skills (across all 23) have reached at least `level`.
    @MainActor
    private static func count(atLeast level: Int, _ game: GameState) -> Int {
        SkillID.allCases.filter { game.level(for: $0) >= level }.count
    }

    /// Total taps a player has logged across every skill in a category — the basis for the
    /// Grandmaster "endless grind" tap Tasks.
    @MainActor
    private static func groupTaps(in category: SkillCategory, _ game: GameState) -> Int {
        SkillID.skills(in: category).reduce(0) { $0 + game.taskCounter(TaskCounter.skillTaps($1)) }
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
        Task(id: "combat.level80", diary: .combat, tier: .hard,
             title: "Warlord", detail: "Reach level 80 in any combat skill.",
             goal: 80, triggers: [.levelUp]) { maxLevel(in: .combat, $0) },
        Task(id: "combat.tier6", diary: .combat, tier: .elite,
             title: "Weaponmaster", detail: "Unlock a tier-6 method on any combat skill.",
             goal: 1, triggers: [.levelUp]) { hasTier6(in: .combat, $0) },
        Task(id: "combat.all70", diary: .combat, tier: .elite,
             title: "Elite Battalion", detail: "Reach level 70 in all six combat skills.",
             goal: 6, triggers: [.levelUp]) { count(atLeast: 70, in: .combat, $0) },
        Task(id: "combat.all99", diary: .combat, tier: .master,
             title: "Combat Legend", detail: "Reach level 99 in all six combat skills.",
             goal: 6, triggers: [.levelUp]) { maxedCount(in: .combat, $0) },
        Task(id: "combat.supercharge25", diary: .combat, tier: .master,
             title: "Warmonger", detail: "Trigger 25 Supercharges on combat skills.",
             goal: 25, triggers: [.supercharge]) { $0.taskCounter(TaskCounter.combatSupercharges) },
        Task(id: "combat.taps10k", diary: .combat, tier: .grandmaster,
             title: "Endless Onslaught", detail: "Land 10,000 taps across combat skills.",
             goal: 10_000, triggers: [.tap]) { groupTaps(in: .combat, $0) }
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
        Task(id: "prod.tier3", diary: .production, tier: .medium,
             title: "Second Upgrade", detail: "Unlock a tier-3 method on any production skill.",
             goal: 30, triggers: [.levelUp]) { maxLevel(in: .production, $0) },
        Task(id: "prod.level70", diary: .production, tier: .hard,
             title: "Master Artisan", detail: "Reach level 70 in any production skill.",
             goal: 70, triggers: [.levelUp]) { maxLevel(in: .production, $0) },
        Task(id: "prod.all50", diary: .production, tier: .hard,
             title: "Assembly Line", detail: "Reach level 50 in all seven production skills.",
             goal: 7, triggers: [.levelUp]) { count(atLeast: 50, in: .production, $0) },
        Task(id: "prod.tier6", diary: .production, tier: .elite,
             title: "Grandmaster Smith", detail: "Unlock a tier-6 method on any production skill.",
             goal: 1, triggers: [.levelUp]) { hasTier6(in: .production, $0) },
        Task(id: "prod.all70", diary: .production, tier: .elite,
             title: "Grand Workshop", detail: "Reach level 70 in all seven production skills.",
             goal: 7, triggers: [.levelUp]) { count(atLeast: 70, in: .production, $0) },
        Task(id: "prod.all90", diary: .production, tier: .master,
             title: "Legendary Artisan", detail: "Reach level 90 in all seven production skills.",
             goal: 7, triggers: [.levelUp]) { count(atLeast: 90, in: .production, $0) },
        Task(id: "prod.all99", diary: .production, tier: .master,
             title: "Production Legend", detail: "Reach level 99 in all seven production skills.",
             goal: 7, triggers: [.levelUp]) { maxedCount(in: .production, $0) },
        Task(id: "prod.taps10k", diary: .production, tier: .grandmaster,
             title: "Endless Production", detail: "Land 10,000 taps across production skills.",
             goal: 10_000, triggers: [.tap]) { groupTaps(in: .production, $0) }
    ]

    static let utility: [Task] = [
        Task(id: "util.combo120", diary: .utility, tier: .easy,
             title: "Nimble", detail: "Build a ×1.2 tap combo.",
             goal: 120, triggers: [.combo]) { $0.taskCounter(TaskCounter.bestComboBips) },
        Task(id: "util.level20", diary: .utility, tier: .easy,
             title: "Fleet Footed", detail: "Reach level 20 in any utility skill.",
             goal: 20, triggers: [.levelUp]) { maxLevel(in: .utility, $0) },
        Task(id: "util.combo140", diary: .utility, tier: .medium,
             title: "In the Zone", detail: "Build a ×1.4 tap combo.",
             goal: 140, triggers: [.combo]) { $0.taskCounter(TaskCounter.bestComboBips) },
        Task(id: "util.refund", diary: .utility, tier: .medium,
             title: "Light Fingers", detail: "Pickpocket back a coupon or Energy Cell.",
             goal: 1, triggers: [.refund]) { $0.taskCounter(TaskCounter.refunds) },
        Task(id: "util.level60", diary: .utility, tier: .hard,
             title: "Untouchable", detail: "Reach level 60 in any utility skill.",
             goal: 60, triggers: [.levelUp]) { maxLevel(in: .utility, $0) },
        Task(id: "util.combo150", diary: .utility, tier: .hard,
             title: "Flow State", detail: "Build a ×1.5 tap combo.",
             goal: 150, triggers: [.combo]) { $0.taskCounter(TaskCounter.bestComboBips) },
        Task(id: "util.tier6", diary: .utility, tier: .elite,
             title: "Shadow", detail: "Unlock a tier-6 method on any utility skill.",
             goal: 1, triggers: [.levelUp]) { hasTier6(in: .utility, $0) },
        Task(id: "util.refund25", diary: .utility, tier: .elite,
             title: "Master Thief", detail: "Pickpocket back 25 coupons or Energy Cells.",
             goal: 25, triggers: [.refund]) { $0.taskCounter(TaskCounter.refunds) },
        Task(id: "util.all90", diary: .utility, tier: .master,
             title: "Utility Grandmaster", detail: "Reach level 90 in all five utility skills.",
             goal: 5, triggers: [.levelUp]) { count(atLeast: 90, in: .utility, $0) },
        Task(id: "util.all99", diary: .utility, tier: .master,
             title: "Utility Legend", detail: "Reach level 99 in all five utility skills.",
             goal: 5, triggers: [.levelUp]) { maxedCount(in: .utility, $0) },
        Task(id: "util.taps10k", diary: .utility, tier: .grandmaster,
             title: "Endless Hustle", detail: "Land 10,000 taps across utility skills.",
             goal: 10_000, triggers: [.tap]) { groupTaps(in: .utility, $0) }
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
        Task(id: "gather.energyProcs50", diary: .gathering, tier: .hard,
             title: "Live Wire", detail: "Bank Supercharge Energy 50 times.",
             goal: 50, triggers: [.energyProc]) { $0.taskCounter(TaskCounter.energyProcs) },
        Task(id: "gather.caches100", diary: .gathering, tier: .elite,
             title: "Bounty Hunter", detail: "Collect 100 bonus caches.",
             goal: 100, triggers: [.cache]) { $0.taskCounter(TaskCounter.caches) },
        Task(id: "gather.energyCap60", diary: .gathering, tier: .elite,
             title: "Bottomless", detail: "Raise your Energy cap to 60 seconds.",
             goal: 60, triggers: [.levelUp]) { Int($0.energyCapSeconds) },
        Task(id: "gather.all90", diary: .gathering, tier: .master,
             title: "Harvest Lord", detail: "Reach level 90 in all five gathering skills.",
             goal: 5, triggers: [.levelUp]) { count(atLeast: 90, in: .gathering, $0) },
        Task(id: "gather.all99", diary: .gathering, tier: .master,
             title: "Gathering Legend", detail: "Reach level 99 in all five gathering skills.",
             goal: 5, triggers: [.levelUp]) { maxedCount(in: .gathering, $0) },
        Task(id: "gather.taps10k", diary: .gathering, tier: .grandmaster,
             title: "Endless Harvest", detail: "Land 10,000 taps across gathering skills.",
             goal: 10_000, triggers: [.tap]) { groupTaps(in: .gathering, $0) }
    ]

    static let idler: [Task] = [
        // Easy
        Task(id: "idle.return1", diary: .idler, tier: .easy,
             title: "Well Rested", detail: "Return from an offline session.",
             goal: 1, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.offlineReturns) },
        Task(id: "idle.idletaps100", diary: .idler, tier: .easy,
             title: "Autopilot", detail: "Reach 100 idle taps.",
             goal: 100, triggers: [.idleTap]) { $0.taskCounter(TaskCounter.idleTaps) },
        // Medium
        Task(id: "idle.offline100k", diary: .idler, tier: .medium,
             title: "Overnight", detail: "Earn 100k XP in a single offline return.",
             goal: 100_000, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.bestOfflineXP) },
        Task(id: "idle.idletaps1000", diary: .idler, tier: .medium,
             title: "Set and Forget", detail: "Reach 1,000 idle taps.",
             goal: 1_000, triggers: [.idleTap]) { $0.taskCounter(TaskCounter.idleTaps) },
        // Hard
        Task(id: "idle.idletaps5000", diary: .idler, tier: .hard,
             title: "Hands Off", detail: "Reach 5,000 idle taps.",
             goal: 5_000, triggers: [.idleTap]) { $0.taskCounter(TaskCounter.idleTaps) },
        Task(id: "idle.idletaps10000", diary: .idler, tier: .hard,
             title: "Idle Hands", detail: "Reach 10,000 idle taps.",
             goal: 10_000, triggers: [.idleTap]) { $0.taskCounter(TaskCounter.idleTaps) },
        // Elite
        Task(id: "idle.offline500k", diary: .idler, tier: .elite,
             title: "Big Sleeper", detail: "Earn 500k XP in a single offline return.",
             goal: 500_000, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.bestOfflineXP) },
        Task(id: "idle.offline1m", diary: .idler, tier: .elite,
             title: "Hibernation", detail: "Earn 1,000,000 XP in a single offline return.",
             goal: 1_000_000, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.bestOfflineXP) },
        Task(id: "idle.idletaps25000", diary: .idler, tier: .elite,
             title: "Ghost in the Machine", detail: "Reach 25,000 idle taps.",
             goal: 25_000, triggers: [.idleTap]) { $0.taskCounter(TaskCounter.idleTaps) },
        // Master
        Task(id: "idle.returns50", diary: .idler, tier: .master,
             title: "Creature of Habit", detail: "Return from 50 offline sessions.",
             goal: 50, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.offlineReturns) },
        Task(id: "idle.idletaps50000", diary: .idler, tier: .master,
             title: "Automation Station", detail: "Reach 50,000 idle taps.",
             goal: 50_000, triggers: [.idleTap]) { $0.taskCounter(TaskCounter.idleTaps) },
        // Grandmaster
        Task(id: "idle.offline10m", diary: .idler, tier: .grandmaster,
             title: "Eternal Slumber",
             detail: "Bank 10,000,000 XP in one offline return, summed across every skill training.",
             goal: 10_000_000, triggers: [.offlineReturn]) { $0.taskCounter(TaskCounter.bestOfflineXP) },
        Task(id: "idle.idletaps100000", diary: .idler, tier: .grandmaster,
             title: "Perpetual Motion", detail: "Reach 100,000 idle taps.",
             goal: 100_000, triggers: [.idleTap]) { $0.taskCounter(TaskCounter.idleTaps) }
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
        Task(id: "tycoon.boosttaps500", diary: .tycoon, tier: .hard,
             title: "Boost Rider", detail: "Land 1,000 taps while an XP Boost is active.",
             goal: 1_000, triggers: [.tap]) { $0.taskCounter(TaskCounter.boostTaps) },
        Task(id: "tycoon.cells10", diary: .tycoon, tier: .hard,
             title: "Cell Stockpile", detail: "Use 10 Energy Cells.",
             goal: 10, triggers: [.energyCell]) { $0.taskCounter(TaskCounter.energyCells) },
        Task(id: "tycoon.cells25", diary: .tycoon, tier: .elite,
             title: "Energy Baron", detail: "Use 25 Energy Cells.",
             goal: 25, triggers: [.energyCell]) { $0.taskCounter(TaskCounter.energyCells) },
        Task(id: "tycoon.stack25", diary: .tycoon, tier: .elite,
             title: "Perfect Storm", detail: "Tap 25 times with a Boost and Supercharge both active.",
             goal: 25, triggers: [.tap]) { $0.taskCounter(TaskCounter.stackedBursts) },
        Task(id: "tycoon.boosttaps2500", diary: .tycoon, tier: .master,
             title: "Boost Tycoon", detail: "Land 4,000 taps while an XP Boost is active.",
             goal: 4_000, triggers: [.tap]) { $0.taskCounter(TaskCounter.boostTaps) },
        Task(id: "tycoon.supertaps1500", diary: .tycoon, tier: .master,
             title: "Overcharged", detail: "Land 1,500 taps on a Supercharged skill.",
             goal: 1_500, triggers: [.tap]) { $0.taskCounter(TaskCounter.superchargeTaps) },
        Task(id: "tycoon.boosttaps6000", diary: .tycoon, tier: .grandmaster,
             title: "Empire", detail: "Land 10,000 taps while an XP Boost is active.",
             goal: 10_000, triggers: [.tap]) { $0.taskCounter(TaskCounter.boostTaps) }
    ]

    static let completionist: [Task] = [
        Task(id: "comp.breadth20", diary: .completionist, tier: .easy,
             title: "Well Rounded", detail: "Train every skill to level 20.",
             goal: SkillID.allCases.count, triggers: [.levelUp]) { count(atLeast: 20, $0) },
        Task(id: "comp.total250", diary: .completionist, tier: .medium,
             title: "Journeyman", detail: "Reach total level 250.",
             goal: 250, triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "comp.total500", diary: .completionist, tier: .medium,
             title: "Wayfarer", detail: "Reach total level 500.",
             goal: 500, triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "comp.first99", diary: .completionist, tier: .hard,
             title: "First 99", detail: "Reach level 99 in any skill.",
             goal: 1, triggers: [.levelUp]) { $0.maxedSkillCount },
        Task(id: "comp.total750", diary: .completionist, tier: .hard,
             title: "Veteran", detail: "Reach total level 750.",
             goal: 750, triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "comp.breadth50", diary: .completionist, tier: .elite,
             title: "Jack of All Trades", detail: "Train every skill to level 50.",
             goal: SkillID.allCases.count, triggers: [.levelUp]) { count(atLeast: 50, $0) },
        Task(id: "comp.breadth70", diary: .completionist, tier: .elite,
             title: "Renaissance", detail: "Train every skill to level 70.",
             goal: SkillID.allCases.count, triggers: [.levelUp]) { count(atLeast: 70, $0) },
        Task(id: "comp.total1500", diary: .completionist, tier: .elite,
             title: "Trailblazer", detail: "Reach total level 1500.",
             goal: 1500, triggers: [.levelUp]) { $0.totalLevel },
        Task(id: "comp.maxcape", diary: .completionist, tier: .master,
             title: "Max Cape", detail: "Reach level 99 in all 23 skills.",
             goal: SkillID.allCases.count, triggers: [.levelUp]) { $0.maxedSkillCount },
        Task(id: "comp.eternal", diary: .completionist, tier: .master,
             title: "Eternal", detail: "Reach the 200M XP ceiling in any skill.",
             goal: 1, triggers: [.levelUp]) { $0.maxXPSkillCount },
        Task(id: "comp.truecomp", diary: .completionist, tier: .grandmaster,
             title: "True Completionist", detail: "Reach 200M XP in every skill.",
             goal: SkillID.allCases.count, triggers: [.levelUp]) { $0.maxXPSkillCount }
    ]
}
