import Foundation

/// Central home for every tunable game-balance constant.
///
/// Re-balancing the game should never require touching gameplay code — change the numbers
/// here and the rest of the game follows.
enum Balance {

    // MARK: Passive training (foreground only)

    /// "Actions" auto-performed per second by each slotted skill. Passive XP equals this times
    /// that skill's *current method* XP-per-action, so passive scales as training methods improve.
    static let passiveActionsPerSecond: Double = 1.0

    // MARK: Offline training (app closed)

    /// Fraction of the foreground passive rate that *slotted* skills keep earning while the app
    /// is closed. Mirrors the offline-Energy efficiency pattern: idle progress is real but
    /// reduced so active play (taps + Supercharge) stays worthwhile.
    static let offlineXPMultiplier: Double = 0.4

    /// Maximum stretch of offline time (hours) that accrues XP. Time away beyond this is ignored,
    /// so the game can't be finished by leaving it closed for days. The window resets every time
    /// the player returns.
    static let maxOfflineHours: Double = 10.0

    /// Minimum time away (seconds) before the "welcome back" summary is presented, so brief app
    /// switches don't pop a sheet. XP is still credited for shorter gaps.
    static let minOfflineSecondsForSummary: TimeInterval = 60

    // MARK: Training method tiers

    /// A tier in a skill's training progression: unlocks at `unlockLevel` and grants
    /// `xpPerAction` XP per tap. Each skill supplies thematic flavor (name + artwork) per tier
    /// in `SkillID.trainingMethods`.
    struct TrainingTier {
        let unlockLevel: Int
        let xpPerAction: Int
    }

    /// Shared tier ladder. As a skill levels up it unlocks higher tiers that grant more XP per
    /// tap, so the on-screen training method visibly evolves (normal tree → oak → willow → …).
    static let trainingTiers: [TrainingTier] = [
        TrainingTier(unlockLevel: 1,  xpPerAction: 1),
        TrainingTier(unlockLevel: 15, xpPerAction: 3),
        TrainingTier(unlockLevel: 30, xpPerAction: 6),
        TrainingTier(unlockLevel: 50, xpPerAction: 12),
        TrainingTier(unlockLevel: 70, xpPerAction: 25),
        TrainingTier(unlockLevel: 90, xpPerAction: 50)
    ]

    /// Index into `trainingTiers` of the highest tier unlocked at `level`.
    static func trainingTierIndex(forSkillLevel level: Int) -> Int {
        var index = 0
        for (i, tier) in trainingTiers.enumerated() where level >= tier.unlockLevel { index = i }
        return index
    }

    // MARK: Energy & Supercharge

    /// Maximum bankable Supercharge time, in seconds. Mining's "Deep Reserves" perk raises it.
    static let maxEnergySeconds: Double = 30.0

    /// Minimum banked Energy (seconds) required to trigger a Supercharge.
    static let minEnergyToSupercharge: Double = 1.0

    /// Base Supercharge multiplier: while supercharged, taps earn `method XP × multiplier`.
    /// This no longer ramps with total level — per-tap payout already scales as a skill's
    /// training method upgrades with level, so the burst stays a constant multiplier on top of
    /// that. Prayer's perk adds to this base (see `superchargePrayerBonus`), scaling the
    /// effective Supercharge from ×2 up to ×5 at Prayer 99.
    static let superchargeMultiplier: Int = 2

    // MARK: Daily Boost (formerly "Double XP")

    /// Base multiplier applied to *all* XP (taps + passive) while a Daily Boost is active.
    /// Magic's perk raises it further; it stacks multiplicatively with Supercharge.
    static let doubleXPMultiplier: Double = 1.5

    /// How long a single Daily Boost coupon lasts once activated, in seconds (5 minutes).
    static let doubleXPDurationSeconds: TimeInterval = 300

    /// Free Daily Boost coupons granted the first time the app is opened on a new calendar day.
    static let dailyFreeCoupons: Int = 1

    // MARK: Training slots

    /// A skill must reach this level before it can be assigned to a training slot.
    static let slotEligibilityLevel: Int = 10

    /// Total-level thresholds that unlock the 2nd, 3rd, 4th, and 5th training slots
    /// (element `i` unlocks slot `i + 2`). Ascending. Tuned for the full 23-skill roster
    /// (max total level 2277).
    static let slotUnlockTotalLevels: [Int] = [100, 300, 500, 1000]

    /// Number of training slots unlocked for a given total level (1 base + each threshold met).
    static func maxSlots(forTotalLevel total: Int) -> Int {
        1 + slotUnlockTotalLevels.filter { total >= $0 }.count
    }

    /// The absolute maximum number of training slots — every unlock threshold met.
    static var maxPossibleSlots: Int { 1 + slotUnlockTotalLevels.count }

    // MARK: Skill perks (per-skill account-wide buffs)

    /// How a perk's magnitude interpolates from its level-1 value to its level-99 value.
    /// The buff grows with the skill's level so it becomes more prevalent as you train.
    enum BuffCurve {
        case linear   // steady growth per level
        case easeIn   // back-loaded: most of the payoff arrives at high levels
        case easeOut  // front-loaded: quick early gains, tapering off
    }

    /// The scaling envelope for one skill's perk. `at1` is the value at level 1 (tuned to be
    /// *neutral* so a fresh account behaves exactly as before) and `at99` is the fully-trained
    /// value. Re-balancing a perk is a one-line change here.
    struct BuffScaling {
        let at1: Double
        let at99: Double
        var curve: BuffCurve = .linear
    }

    /// Fraction (0...1) of a perk's growth realized at `level`, per its curve.
    /// 0 at level 1, 1 at level 99.
    static func buffProgress(level: Int, curve: BuffCurve) -> Double {
        let span = Double(XPTable.maxLevel - 1)
        let t = Double(min(max(level, 1), XPTable.maxLevel) - 1) / span
        switch curve {
        case .linear:  return t
        case .easeIn:  return t * t
        case .easeOut: return 1 - (1 - t) * (1 - t)
        }
    }

    /// A perk's interpolated magnitude at `level`.
    static func buffValue(level: Int, scaling: BuffScaling) -> Double {
        scaling.at1 + (scaling.at99 - scaling.at1) * buffProgress(level: level, curve: scaling.curve)
    }

    /// Per-skill perk scaling. Every `at1` is neutral (0, ×1, or the prior constant) so at level 1
    /// in everything the game plays identically to before — perks are strictly additive as you level.
    static let buffScaling: [SkillID: BuffScaling] = [
        // Combat — shapes the active tap "hit"
        .attack:       BuffScaling(at1: 0.0,   at99: 6.0),    // accuracy: roll-bias exponent (uniform → near-max)
        .strength:     BuffScaling(at1: 1.0,   at99: 2.0),    // power: max-hit ceiling (× base method XP)
        .defence:      BuffScaling(at1: 1.0,   at99: 1.75),   // guard: min-hit floor (× base, clamped ≤ max)
        .hitpoints:    BuffScaling(at1: 1.0,   at99: 2.0),    // vitality: charge banked per tap-proc ×
        .ranged:       BuffScaling(at1: 0.0,   at99: 0.60),   // rapid fire: chance for an extra hit
        .prayer:       BuffScaling(at1: 0.0,   at99: 3.0),    // blessing: +bonus added to the Supercharge multiplier (×2 base → ×5)
        .magic:        BuffScaling(at1: doubleXPMultiplier, at99: 3.0),    // enchantment: Daily Boost multiplier value
        // Gathering — feeds the idle engine
        .woodcutting:  BuffScaling(at1: 0.0,   at99: 0.12),   // bird's nests: bonus-XP cache chance
        .fishing:      BuffScaling(at1: 0.0,   at99: 10.0),   // big catch: ×base Supercharge charge chance (0×→10×)
        .mining:       BuffScaling(at1: maxEnergySeconds, at99: 60.0), // deep reserves: Energy cap (seconds)
        .farming:      BuffScaling(at1: 1.0,   at99: 2.0),    // patient growth: offline XP efficiency ×
        .hunter:       BuffScaling(at1: 1.0,   at99: 5.0),    // trapper: OFFLINE passive XP rate × (app closed)
        // Production — crafting output & the boost economy
        .cooking:      BuffScaling(at1: 0.0,   at99: 0.50),   // well fed: +fraction to all tap XP
        .firemaking:   BuffScaling(at1: 1.0,   at99: 2.0),    // slow burn: Supercharge duration ×
        .crafting:     BuffScaling(at1: 2.0,   at99: 4.0),    // masterwork: crit magnitude ×
        .smithing:     BuffScaling(at1: 1.0,   at99: 5.0),    // foundry: FOREGROUND idle XP rate × (app open)
        .fletching:    BuffScaling(at1: 0.0,   at99: 8.0),    // extra ammo: +flat XP per tap
        .herblore:     BuffScaling(at1: 0.0,   at99: 300.0),  // alchemist: +seconds to Daily Boost duration
        .runecraft:    BuffScaling(at1: 0.0,   at99: 3.0),    // runic automaton: auto-taps per second
        .construction: BuffScaling(at1: maxOfflineHours, at99: 48.0), // workshop: OFFLINE accrual cap (hours), neutral at the base cap
        // Utility — tempo & meta
        .agility:      BuffScaling(at1: 1.0,   at99: 1.6),    // momentum: tap-streak combo ceiling ×
        .thieving:     BuffScaling(at1: 0.0,   at99: 0.3),    // pickpocket: chance to refund a spent coupon / Energy Cell
        .slayer:       BuffScaling(at1: 0.0,   at99: 0.15)    // assassinate: crit chance
    ]

    /// Woodcutting cache windfall, expressed as a multiple of the current method's base XP.
    static let woodcuttingCacheMultiple: Double = 15.0

    /// Base chance, per tap on any skill, to bank a burst of Supercharge Energy. This is the *unit*
    /// rate that Fishing's "Big Catch" perk multiplies (0× at Lv 1 → 10× at Lv 99), so the effective
    /// per-tap charge chance runs 0% while Fishing is untrained up to 1% at Fishing 99.
    static let baseEnergyTapChance: Double = 0.001

    /// Seconds of Energy granted when a tap's charge proc lands (scaled by Hitpoints "Vitality").
    static let energyTapProcSeconds: Double = 1.0

    /// Max seconds between taps to keep an Agility combo chaining, and taps needed to reach the ceiling.
    static let agilityComboWindow: TimeInterval = 1.2
    static let agilityComboTapsToMax: Int = 20

    // MARK: Raids

    /// How long a raid runs, in seconds — "a few minutes". A raid ends early on a win (goal met);
    /// otherwise the clock is the fail deadline. Reward scales with this (see `raidRapidTapsPerMinute`).
    static let raidDurationSeconds: Double = 180

    /// How many raids each skill group can be attempted per calendar day. One shot: a completed
    /// attempt (win *or* loss) spends the day for that group.
    static let raidsPerGroupPerDay: Int = 1

    /// Per-raid-tier lamp value coefficient (index = raid tier 0…5, Bronze → Rune). A lamp applied
    /// to a skill grants `skillLevel × coefficient` XP, so a lamp's worth scales with the skill's
    /// exact level and grows exponentially across tiers (Bronze→Iron is a small step; Adamant→Rune
    /// a large one). Re-balancing lamps is a one-line change here — no gameplay or view code.
    static let lampTierCoefficients: [Int] = [500, 900, 1650, 3000, 5500, 10000]

    /// Per-tier difficulty knobs the four raid loops read, selected by a group's raid tier (0…5).
    /// Ascending difficulty: the goal climbs while the windows tighten and decoys multiply.
    struct RaidTierParams {
        /// Successful actions needed to clear (boss damage / products / rooms / resources).
        let goal: Int
        /// Failures tolerated before the raid is lost (missed dodges / mistimes / catches / wrong taps).
        let allowedMistakes: Int
        /// Seconds a target or prompt stays actionable before it lapses (tightens with tier).
        let targetLifetime: Double
        /// Seconds between spawns / prompt cadence (shrinks with tier).
        let spawnInterval: Double
        /// Wrong targets present alongside the right one (recognition pressure).
        let decoyCount: Int
    }

    /// Six ascending-difficulty tiers, aligned to the training-method ladder (avg level 1/15/30/50/70/90).
    static let raidTierParams: [RaidTierParams] = [
        RaidTierParams(goal: 40, allowedMistakes: 12, targetLifetime: 1.70, spawnInterval: 1.25, decoyCount: 2),
        RaidTierParams(goal: 48, allowedMistakes: 10, targetLifetime: 1.50, spawnInterval: 1.10, decoyCount: 3),
        RaidTierParams(goal: 56, allowedMistakes: 9,  targetLifetime: 1.35, spawnInterval: 1.00, decoyCount: 4),
        RaidTierParams(goal: 64, allowedMistakes: 8,  targetLifetime: 1.20, spawnInterval: 0.90, decoyCount: 5),
        RaidTierParams(goal: 72, allowedMistakes: 7,  targetLifetime: 1.05, spawnInterval: 0.82, decoyCount: 6),
        RaidTierParams(goal: 80, allowedMistakes: 6,  targetLifetime: 0.95, spawnInterval: 0.75, decoyCount: 7)
    ]

    /// Difficulty parameters for a given raid tier (clamped to the table).
    static func raidParams(forTier tier: Int) -> RaidTierParams {
        raidTierParams[min(max(tier, 0), raidTierParams.count - 1)]
    }

    /// Lamp value coefficient for a given raid tier (clamped to the table).
    static func lampCoefficient(forTier tier: Int) -> Int {
        lampTierCoefficients[min(max(tier, 0), lampTierCoefficients.count - 1)]
    }

    // MARK: Rewards (Diary — Tasks & universal Tokens)

    /// Every tunable for the achievement/reward economy. Re-balancing payouts, shop prices, or IAP
    /// grants is a one-line change here and never touches Task definitions, gameplay, or view code.
    /// See docs/ACHIEVEMENTS.md.
    ///
    /// **One currency.** Tokens are the single spendable currency. They are *earned* by completing
    /// Tasks and *bought* via IAP (`iapTokens*`), then *spent* in the Shop on Boost Coupons and
    /// Energy Cells (`*Cost`). The scale is deliberately tiered so that paying yields far more than
    /// grinding achievements: the entire Task catalog (79 Tasks) pays out ≈ 3,560 Tokens, a single
    /// Task pays 3–180, one shop item costs 100–250 (so it takes many Tasks to afford one), and even
    /// the smallest IAP pack (500) dwarfs any single Task and buys several shop items outright.
    ///
    /// **Tier clears grant lamps, not Tokens.** Completing *every* Task in one Diary tier awards a
    /// tier-matched XP **lamp** (Easy→Bronze … Grandmaster→Rune, `TaskTier.lampTier`) into the
    /// unified Diary-lamp inventory — a separate, level-scaling reward from the Token economy. Lamp
    /// worth is `Balance.lampTierCoefficients`; the mapping lives on `TaskTier`, so no constant here.
    enum Rewards {
        /// Tokens granted for completing a single Task, by difficulty tier — higher tiers pay far
        /// more, and `grandmaster` (the end-game capstone) pays the most. Tuned so the full catalog
        /// totals ≈ 3,600 Tokens at 100% completion (see the note above).
        static let tokensEasy = 3
        static let tokensMedium = 8
        static let tokensHard = 18
        static let tokensElite = 42
        static let tokensMaster = 90
        static let tokensGrandmaster = 180

        // MARK: Shop prices — Tokens spent to acquire a consumable

        /// Tokens to buy one **Boost Coupon** (a timed all-skill XP multiplier). Pricier than a Cell
        /// because a Boost affects every skill at once. ≈ one Master Task, or a long run of easy ones.
        static let boostCouponCost = 250
        /// Tokens to buy one **Energy Cell** (an instant single-skill Supercharge fill).
        static let energyCellCost = 100

        // MARK: IAP — Tokens granted per real-money pack

        /// Tokens granted by the small / medium / large Token packs. Each dwarfs a single Task so
        /// buying is a big jump, and the large pack alone exceeds a full achievement clear.
        static let iapTokensSmall = 500
        static let iapTokensMedium = 3_000
        static let iapTokensLarge = 7_500
    }
}
