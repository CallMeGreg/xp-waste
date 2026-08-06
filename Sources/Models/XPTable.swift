import Foundation

/// The Old School RuneScape experience curve.
///
/// `xpForLevel[n]` is the cumulative XP required to *reach* level `n`
/// (level 1 == 0 XP, level 99 == 13,034,431 XP).
enum XPTable {

    static let maxLevel = 99

    /// Cumulative XP required to reach each level. Index == level (1...99); index 0 is unused.
    static let xpForLevel: [Int] = {
        var result = [Int](repeating: 0, count: maxLevel + 1)
        var points = 0.0
        var cumulative = 0.0
        for level in 1...maxLevel {
            result[level] = Int((cumulative / 4.0).rounded(.down))
            points += (Double(level) + 300.0 * pow(2.0, Double(level) / 7.0)).rounded(.down)
            cumulative = points
        }
        return result
    }()

    /// Total XP required to fully max the skill (reach level 99).
    static let maxXP = xpForLevel[maxLevel]

    /// Cumulative XP required to reach a given level (clamped to 1...99).
    static func xp(toReach level: Int) -> Int {
        xpForLevel[min(max(level, 1), maxLevel)]
    }

    /// The level attained for a given cumulative XP total.
    static func level(forXP xp: Int) -> Int {
        var level = 1
        for candidate in 1...maxLevel where xp >= xpForLevel[candidate] {
            level = candidate
        }
        return level
    }

    /// Progress (0...1) from the current level toward the next level for a given XP total.
    /// Returns 1.0 at level 99.
    static func progressToNextLevel(forXP xp: Int) -> Double {
        let level = level(forXP: xp)
        guard level < maxLevel else { return 1.0 }
        let base = xpForLevel[level]
        let next = xpForLevel[level + 1]
        guard next > base else { return 1.0 }
        return min(max(Double(xp - base) / Double(next - base), 0.0), 1.0)
    }

    /// XP remaining until the next level, or 0 at level 99.
    static func xpToNextLevel(forXP xp: Int) -> Int {
        let level = level(forXP: xp)
        guard level < maxLevel else { return 0 }
        return max(xpForLevel[level + 1] - xp, 0)
    }
}
