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

    // MARK: Training method tiers

    /// A tier in a skill's training progression: unlocks at `unlockLevel` and grants
    /// `xpPerAction` XP per tap. Each skill supplies thematic flavor (name + glyph) per tier
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

    /// Real seconds required to bank one second of Supercharge (60s real = 1s charge).
    static let realSecondsPerEnergySecond: Double = 60.0

    /// Maximum bankable Supercharge time, in seconds (30 min real time → 30s charge).
    static let maxEnergySeconds: Double = 30.0

    /// Minimum banked Energy (seconds) required to trigger a Supercharge.
    static let minEnergyToSupercharge: Double = 1.0

    /// Supercharge multiplier tiers, keyed by the total level required to unlock them.
    /// While supercharged, taps earn `method XP × multiplier`. Sorted ascending; highest applies.
    static let superchargeTiers: [(totalLevel: Int, multiplier: Int)] = [
        (0, 2),
        (100, 5),
        (300, 10),
        (500, 20)
    ]

    // MARK: Double XP boost

    /// Multiplier applied to *all* XP (taps + passive) while a Double XP boost is active.
    /// Stacks multiplicatively with Supercharge.
    static let doubleXPMultiplier: Double = 2.0

    /// How long a single Double XP coupon lasts once activated, in seconds (10 minutes).
    static let doubleXPDurationSeconds: TimeInterval = 600

    /// Free Double XP coupons granted the first time the app is opened on a new calendar day.
    static let dailyFreeCoupons: Int = 1

    // MARK: Training slots

    /// A skill must reach this level before it can be assigned to a training slot.
    static let slotEligibilityLevel: Int = 10

    /// Total-level thresholds that unlock the 2nd and 3rd training slots.
    /// Tuned for the full 23-skill roster (max total level 2277).
    static let slot2TotalLevel: Int = 100
    static let slot3TotalLevel: Int = 300

    /// Number of training slots unlocked for a given total level.
    static func maxSlots(forTotalLevel total: Int) -> Int {
        if total >= slot3TotalLevel { return 3 }
        if total >= slot2TotalLevel { return 2 }
        return 1
    }

    /// The active Supercharge multiplier for a given total level.
    static func superchargeMultiplier(forTotalLevel total: Int) -> Int {
        var value = superchargeTiers.first?.multiplier ?? 2
        for tier in superchargeTiers where total >= tier.totalLevel {
            value = tier.multiplier
        }
        return value
    }

    /// The total level at which the *next* Supercharge tier unlocks, or `nil` if maxed.
    static func nextSuperchargeUnlock(forTotalLevel total: Int) -> (totalLevel: Int, multiplier: Int)? {
        superchargeTiers.first { $0.totalLevel > total }
    }

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
        .hitpoints:    BuffScaling(at1: 1.0,   at99: 2.0),    // vitality: Energy bank-rate multiplier
        .ranged:       BuffScaling(at1: 0.0,   at99: 0.60),   // rapid fire: chance for an extra hit
        .prayer:       BuffScaling(at1: 0.0,   at99: 5.0),    // blessing: +flat to Supercharge multiplier
        .magic:        BuffScaling(at1: doubleXPMultiplier, at99: 3.0),    // enchantment: Double XP multiplier value
        // Gathering — feeds the idle engine
        .woodcutting:  BuffScaling(at1: 0.0,   at99: 0.12),   // bird's nests: bonus-XP cache chance
        .fishing:      BuffScaling(at1: 0.0,   at99: 0.15),   // big catch: bonus-Energy chance
        .mining:       BuffScaling(at1: maxEnergySeconds, at99: 60.0), // deep reserves: Energy cap (seconds)
        .farming:      BuffScaling(at1: 1.0,   at99: 2.0),    // patient growth: offline Energy efficiency ×
        .hunter:       BuffScaling(at1: 1.0,   at99: 2.5),    // trapper: passive actions/sec ×
        // Artisan — production & the boost economy
        .cooking:      BuffScaling(at1: 0.0,   at99: 0.50),   // well fed: +fraction to all tap XP
        .firemaking:   BuffScaling(at1: 1.0,   at99: 2.0),    // slow burn: Supercharge duration ×
        .crafting:     BuffScaling(at1: 2.0,   at99: 4.0),    // masterwork: crit magnitude ×
        .smithing:     BuffScaling(at1: 0.0,   at99: 1.0),    // foundry: +fraction to passive XP
        .fletching:    BuffScaling(at1: 0.0,   at99: 8.0),    // extra ammo: +flat XP per tap
        .herblore:     BuffScaling(at1: 0.0,   at99: 300.0),  // alchemist: +seconds to Double XP duration
        .runecraft:    BuffScaling(at1: 0.0,   at99: 3.0),    // runic automaton: auto-taps per second
        .construction: BuffScaling(at1: 0.0,   at99: 2.0),    // architect: extra slots (see constructionSlotLevels)
        // Support — tempo & meta
        .agility:      BuffScaling(at1: 1.0,   at99: 1.6),    // momentum: tap-streak combo ceiling ×
        .thieving:     BuffScaling(at1: Double(dailyFreeCoupons), at99: 3.0),    // pickpocket: free daily coupons
        .slayer:       BuffScaling(at1: 0.0,   at99: 0.15)    // assassinate: crit chance
    ]

    /// Woodcutting cache windfall, expressed as a multiple of the current method's base XP.
    static let woodcuttingCacheMultiple: Double = 15.0

    /// Seconds of Energy granted by a Fishing "big catch" proc.
    static let fishingProcEnergySeconds: Double = 1.0

    /// Max seconds between taps to keep an Agility combo chaining, and taps needed to reach the ceiling.
    static let agilityComboWindow: TimeInterval = 1.2
    static let agilityComboTapsToMax: Int = 20

    /// Construction levels that each grant one extra training slot (stacks with total-level unlocks).
    static let constructionSlotLevels: [Int] = [40, 80]
}
