import Foundation

/// Central home for every tunable game-balance constant.
///
/// Re-balancing the game should never require touching gameplay code — change the numbers
/// here and the rest of the game follows.
enum Balance {

    // MARK: Passive training (foreground only)

    /// XP granted per second to each slotted skill while the app is in the foreground.
    static let passiveXPPerSecond: Double = 1.0

    // MARK: Energy & Supercharge

    /// Real seconds required to bank one second of Supercharge (60s real = 1s charge).
    static let realSecondsPerEnergySecond: Double = 60.0

    /// Maximum bankable Supercharge time, in seconds (30 min real time → 30s charge).
    static let maxEnergySeconds: Double = 30.0

    /// Minimum banked Energy (seconds) required to trigger a Supercharge.
    static let minEnergyToSupercharge: Double = 1.0

    /// Supercharge XP-per-tap tiers, keyed by the total level required to unlock them.
    /// Must stay sorted ascending by `totalLevel`; the highest unlocked tier applies.
    static let superchargeTiers: [(totalLevel: Int, xpPerTap: Int)] = [
        (0, 2),
        (100, 5),
        (300, 10),
        (500, 20)
    ]

    // MARK: Training slots

    /// A skill must reach this level before it can be assigned to a training slot.
    static let slotEligibilityLevel: Int = 10

    /// Total-level thresholds that unlock the 2nd and 3rd training slots.
    static let slot2TotalLevel: Int = 50
    static let slot3TotalLevel: Int = 150

    /// Number of training slots unlocked for a given total level.
    static func maxSlots(forTotalLevel total: Int) -> Int {
        if total >= slot3TotalLevel { return 3 }
        if total >= slot2TotalLevel { return 2 }
        return 1
    }

    /// The active Supercharge XP-per-tap value for a given total level.
    static func superchargeXPPerTap(forTotalLevel total: Int) -> Int {
        var value = superchargeTiers.first?.xpPerTap ?? 2
        for tier in superchargeTiers where total >= tier.totalLevel {
            value = tier.xpPerTap
        }
        return value
    }

    /// The total level at which the *next* Supercharge tier unlocks, or `nil` if maxed.
    static func nextSuperchargeUnlock(forTotalLevel total: Int) -> (totalLevel: Int, xpPerTap: Int)? {
        superchargeTiers.first { $0.totalLevel > total }
    }
}
