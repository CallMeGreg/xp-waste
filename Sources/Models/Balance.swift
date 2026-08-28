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
    static let offlineXPMultiplier: Double = 0.2

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

    /// One-time starter grants for a brand-new game, handed out when onboarding completes so a
    /// fresh player has something to spend on their first session.
    static let starterCoupons: Int = 3
    static let starterEnergyCells: Int = 3

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
        .attack:       BuffScaling(at1: 0.0,   at99: 6.0, curve: .easeIn),  // accuracy: roll-bias exponent (uniform → near-max), back-loaded so the avg-XP% climbs gradually instead of spiking early

        .strength:     BuffScaling(at1: 1.0,   at99: 2.0),    // power: max-hit ceiling (× base method XP)
        .defence:      BuffScaling(at1: 1.0,   at99: 1.75),   // guard: min-hit floor (× base, clamped ≤ max)
        .hitpoints:    BuffScaling(at1: 1.0,   at99: 2.0),    // vitality: charge banked per tap-proc ×
        .ranged:       BuffScaling(at1: 0.0,   at99: 0.60),   // rapid fire: chance for an extra hit
        .prayer:       BuffScaling(at1: 0.0,   at99: 3.0),    // blessing: +bonus added to the Supercharge multiplier (×2 base → ×5)
        .magic:        BuffScaling(at1: doubleXPMultiplier, at99: 3.0),    // enchantment: Daily Boost multiplier value
        // Gathering — feeds the idle engine
        .woodcutting:  BuffScaling(at1: 0.0,   at99: 0.12),   // bird's nests: bonus-XP cache chance
        .fishing:      BuffScaling(at1: 1.0,   at99: 10.0),   // big catch: ×base Supercharge charge chance (1×→10×)
        .mining:       BuffScaling(at1: maxEnergySeconds, at99: 60.0), // deep reserves: Energy cap (seconds)
        .farming:      BuffScaling(at1: 1.0,   at99: 2.0),    // patient growth: offline XP efficiency ×
        .hunter:       BuffScaling(at1: 1.0,   at99: 3.0),    // trapper: OFFLINE passive XP rate × (app closed)
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
    /// rate that Fishing's "Big Catch" perk multiplies (1× at Lv 1 → 10× at Lv 99), so the effective
    /// per-tap charge chance runs 0.1% at Fishing level 1 up to 1% at Fishing 99.
    static let baseEnergyTapChance: Double = 0.001

    /// Seconds of Energy granted when a tap's charge proc lands (scaled by Hitpoints "Vitality").
    static let energyTapProcSeconds: Double = 1.0

    /// Max seconds between taps to keep an Agility combo chaining, and taps needed to reach the ceiling.
    static let agilityComboWindow: TimeInterval = 1.2
    static let agilityComboTapsToMax: Int = 20

    // MARK: Raids

    /// A raid is a short **expedition through three rooms** — a warm-up skill room, a mini-boss, then
    /// a tougher final boss — every room a *different* game loop. The whole run shares one countdown;
    /// clear every room before it expires to win.
    static let raidBaseSeconds: Double = 40
    static let raidSecondsPerRoom: Double = 46

    /// Total clock for a raid at `tier`, scaled by its room count.
    static func raidDuration(forTier tier: Int) -> Double {
        raidBaseSeconds + raidSecondsPerRoom * Double(raidRoomCount(forTier: tier))
    }

    /// How many raids each skill group can be attempted per calendar day. One shot: a completed
    /// attempt (win *or* loss) spends the day for that group.
    static let raidsPerGroupPerDay: Int = 1

    /// A **flawless** clear (finished without losing a single raid-HP heart) banks this many *extra*
    /// lamps on top of the guaranteed one — the reason to sweat every dodge on a daily run.
    static let raidFlawlessBonusLamps: Int = 1

    /// Per-raid-tier lamp value coefficient (index = raid tier 0…5, Bronze → Rune). A lamp applied
    /// to a skill grants `skillLevel × coefficient` XP, so a lamp's worth scales with the skill's
    /// exact level and grows exponentially across tiers (Bronze→Iron is a small step; Adamant→Rune
    /// a large one). Re-balancing lamps is a one-line change here — no gameplay or view code.
    /// Doubled now that a raid is a multi-room expedition, so each daily clear is worth the effort.
    static let lampTierCoefficients: [Int] = [1000, 1800, 3300, 6000, 11000, 20000]

    /// Rooms per raid by tier (0…5). Every raid runs three rooms — a warm-up, a mini-boss and a
    /// final boss — at all tiers; higher tiers grow harder through the multi-axis `RaidTierParams`
    /// ramp (fewer hearts, tighter windows, more boss phases, bigger goals), never by adding filler.
    static let raidRoomCounts: [Int] = [3, 3, 3, 3, 3, 3]
    static func raidRoomCount(forTier tier: Int) -> Int {
        raidRoomCounts[min(max(tier, 0), raidRoomCounts.count - 1)]
    }

    /// Per-tier difficulty knobs every room mechanic reads, selected by a group's raid tier (0…5).
    /// Ascending difficulty: raid HP shrinks, windows tighten, decoys & memory-length grow, and the
    /// final boss gains phases — a multi-axis ramp, not just "fewer mistakes allowed".
    struct RaidTierParams {
        /// Shared "raid HP" hearts for the whole run — a missed dodge / trap / catch / alarm costs
        /// one; at zero the raid ends immediately. Fewer at higher tiers.
        let playerHP: Int
        /// Extra phases the final boss fights through (1 = single phase; up to 3 = an enrage ladder,
        /// each phase tightening its slam cadence).
        let bossPhases: Int
        /// Seconds a tap-target / dodge telegraph stays actionable before it lapses (tightens).
        let targetLifetime: Double
        /// Base cadence (seconds) between spawns / hazards / beam sweeps (shrinks with tier).
        let spawnInterval: Double
        /// Half-width of the rhythm "perfect" sweet-spot as a fraction of the bar (narrows).
        let sweetHalfWidth: Double
        /// Glyphs to repeat per round in a memory (sequence) room (grows with tier).
        let sequenceLength: Int
        /// Distinct decoy resource types on a recognition board (grows with tier).
        let decoyCount: Int
        /// Multiplier applied to every room's base objective size, so runs lengthen with tier.
        let goalScale: Double
    }

    /// Six ascending-difficulty tiers, aligned to the training-method ladder (avg level 1/15/30/50/70/90).
    static let raidTierParams: [RaidTierParams] = [
        RaidTierParams(playerHP: 6, bossPhases: 1, targetLifetime: 1.70, spawnInterval: 1.30, sweetHalfWidth: 0.15, sequenceLength: 3, decoyCount: 2, goalScale: 1.00),
        RaidTierParams(playerHP: 6, bossPhases: 1, targetLifetime: 1.55, spawnInterval: 1.16, sweetHalfWidth: 0.13, sequenceLength: 3, decoyCount: 3, goalScale: 1.10),
        RaidTierParams(playerHP: 5, bossPhases: 2, targetLifetime: 1.40, spawnInterval: 1.04, sweetHalfWidth: 0.11, sequenceLength: 4, decoyCount: 4, goalScale: 1.20),
        RaidTierParams(playerHP: 5, bossPhases: 2, targetLifetime: 1.25, spawnInterval: 0.94, sweetHalfWidth: 0.095, sequenceLength: 4, decoyCount: 5, goalScale: 1.35),
        RaidTierParams(playerHP: 4, bossPhases: 3, targetLifetime: 1.12, spawnInterval: 0.86, sweetHalfWidth: 0.08, sequenceLength: 5, decoyCount: 6, goalScale: 1.50),
        RaidTierParams(playerHP: 4, bossPhases: 3, targetLifetime: 1.00, spawnInterval: 0.78, sweetHalfWidth: 0.07, sequenceLength: 5, decoyCount: 7, goalScale: 1.70)
    ]

    /// Difficulty parameters for a given raid tier (clamped to the table).
    static func raidParams(forTier tier: Int) -> RaidTierParams {
        raidTierParams[min(max(tier, 0), raidTierParams.count - 1)]
    }

    /// Base objective size for a room mechanic at tier 0 (successful actions to clear). Boss rooms
    /// scale this up (see `raidRoomGoal`). All room "sizes" live here so re-tuning never touches the
    /// room content in `RaidPlan` or any view.
    static func raidRoomBaseGoal(_ kind: RaidRoomKind) -> Int {
        switch kind {
        case .laneDodge:   return 8
        case .swipeDodge:  return 8    // boss (×mult): dodge-and-counter openings
        case .duel:        return 10   // boss (×mult): red-circle strikes on the Champion
        case .rhythm:      return 10
        case .charge:      return 7    // boss (×mult): each stoke-and-release is a slow, big blow
        case .vents:       return 8    // boss (×mult): each clean bleed in the green band
        case .stealth:     return 12
        case .pathTrace:   return 6    // boss (×mult): waypoints traced to the exit
        case .memory:      return 3    // boss (×mult): rounds (each round is `sequenceLength` runes)
        case .recognition: return 14
        case .mash:        return 8    // boss (×mult): haul bars filled
        case .sort:        return 12   // boss (×mult): hauls sorted into the right bin
        }
    }

    /// Boss rooms are longer fights: their base objective is multiplied by this and grows with each
    /// extra phase, so the finale always outlasts the warm-up rooms.
    static let raidBossGoalMultiplier: Double = 1.7
    static let raidBossPhaseGoalBonus: Double = 0.5

    /// The concrete objective size (boss HP / quota) for one room at a tier.
    static func raidRoomGoal(kind: RaidRoomKind, isBoss: Bool, tier: Int) -> Int {
        let p = raidParams(forTier: tier)
        var base = Double(raidRoomBaseGoal(kind))
        if isBoss {
            base *= raidBossGoalMultiplier + raidBossPhaseGoalBonus * Double(p.bossPhases - 1)
        }
        return max(1, Int((base * p.goalScale).rounded()))
    }

    /// Damage a single well-earned beat deals in specific boss rooms. Most successes are worth one
    /// boss-HP; a few land a heavier blow so the fight rewards skill instead of dragging on.
    static let raidMashHaulDamageRange: ClosedRange<Int> = 8...12  // River Serpent: a full haul bar is one big, variable heave.
    static let raidChargePerfectDamage: Int = 3   // Forge golem: a dead-centre release lands extra.
    /// A charge released within this fraction of the band's half-width counts as a *perfect* strike.
    static let raidChargePerfectFraction: Double = 0.4
    /// Sand Beast: the base counter (swiping clear of a lunge) lands 1, but immediately sliding *back*
    /// the opposite way inside the follow-up window lands this bonus on top — so a crisp two-beat
    /// exchange hits hard and the room doesn't drag.
    static let raidSwipeSlideBackDamage: Int = 2
    /// Vault Warden: keying the memorised code back correctly lands a variable blow (a longer/cleaner
    /// recall hits harder) instead of a flat 1.
    static let raidMemoryCodeDamageRange: ClosedRange<Int> = 1...3

    /// The Smeltery's rhythm combo pays off precision: once the streak runs *hot* a perfect strike
    /// pours extra bars, so a maintained combo clears the room faster. Below the threshold — and on
    /// an outer "good" hit — each success still pours the base 1. The threshold matches the on-screen
    /// flame that lights at the same combo, so "flame on" reads as "bonus active".
    static let raidRhythmComboThreshold: Int = 3
    static func raidRhythmPerfectBars(combo: Int) -> Int {
        guard combo >= raidRhythmComboThreshold else { return 1 }
        return min(3, 1 + combo / raidRhythmComboThreshold)   // ×3–5 → 2 bars, ×6+ → 3 bars (capped)
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
        /// Tokens to instantly refresh **every** raid's daily attempt so they can all be run again
        /// today — a premium convenience, priced above a single Boost Coupon.
        static let refreshRaidsCost = 250

        // MARK: IAP — Tokens granted per real-money pack

        /// Tokens granted by the small / medium / large Token packs. Each dwarfs a single Task so
        /// buying is a big jump, and the large pack alone exceeds a full achievement clear.
        static let iapTokensSmall = 500
        static let iapTokensMedium = 3_000
        static let iapTokensLarge = 7_500
    }
}
