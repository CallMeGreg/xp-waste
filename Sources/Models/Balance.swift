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
}
