import SwiftUI

/// Raid theming, layered onto the existing `SkillCategory` grouping. There is exactly one raid per
/// category; its difficulty and reward tier track that group's combined skill level (see
/// `GameState.raidTier`). All raid *numbers* live in `Balance.swift`; this file is pure identity.
extension SkillCategory {

    /// The raid's proper name, thematically tied to how the group's skills are trained in OSRS.
    var raidName: String {
        switch self {
        case .combat:     return "The Colosseum"
        case .production: return "The Grand Forge"
        case .utility:    return "The Heist"
        case .gathering:  return "The Expedition"
        }
    }

    /// A one-line pitch for the raid card.
    var raidTagline: String {
        switch self {
        case .combat:     return "Strike the boss's weakpoints — and dodge its slams."
        case .production: return "Time each strike on the forge line to fill the order."
        case .utility:    return "Slip past the guard and loot every room unseen."
        case .gathering:  return "Harvest the called resource — ignore the decoys."
        }
    }

    /// The core verb, shown as a compact hint on the card.
    var raidVerb: String {
        switch self {
        case .combat:     return "Precision & reflex"
        case .production: return "Rhythm & timing"
        case .utility:    return "Stealth & restraint"
        case .gathering:  return "Recognition & speed"
        }
    }

    /// SF Symbol used for the raid's banner / lamp glyph.
    var raidSymbol: String {
        switch self {
        case .combat:     return "shield.lefthalf.filled"
        case .production: return "hammer.fill"
        case .utility:    return "eye.slash.fill"
        case .gathering:  return "leaf.fill"
        }
    }

    /// Signature accent for the raid UI (distinct per group, cohesive with its skills).
    var raidTint: Color {
        switch self {
        case .combat:     return Color(red: 0.80, green: 0.28, blue: 0.26)
        case .production: return Color(red: 0.86, green: 0.52, blue: 0.24)
        case .utility:    return Color(red: 0.52, green: 0.40, blue: 0.80)
        case .gathering:  return Color(red: 0.34, green: 0.64, blue: 0.36)
        }
    }

    /// OSRS-metal flavor name for a raid tier (0…5), mirroring the training-method material ladder.
    static func raidTierName(_ tier: Int) -> String {
        let names = ["Bronze", "Iron", "Steel", "Mithril", "Adamant", "Rune"]
        return names[min(max(tier, 0), names.count - 1)]
    }

    /// Tint for a raid tier, matching the named material (Bronze → bronze, Rune → runite) via the
    /// shared metal ladder — so the tier badge reads as its metal, not the raid's group theme.
    static func raidTierColor(_ tier: Int) -> Color {
        Palette.metal[min(max(tier, 0), Palette.metal.count - 1)]
    }
}

/// A banked, unspent XP lamp. Earned either by clearing a raid (bound to that skill `group`, spent
/// on one of its skills) or by clearing a Diary tier (`group == nil` — a *universal* lamp spendable
/// on **any** skill). The final XP is computed *at application time* from the target skill's current
/// method tier (see `GameState.projectedLampXP`), so a lamp banked early and spent on a high-level
/// skill is worth more — OSRS-faithful.
struct RaidLampRecord: Codable, Identifiable, Equatable {
    let id: UUID
    /// The skill group this lamp is bound to, or `nil` for a universal (Diary-tier) lamp usable on
    /// any skill.
    let group: SkillCategory?
    /// The reward tier it was earned at (0…5, Bronze→Rune; drives `Balance.lampTierCoefficients`).
    let tier: Int
    /// When it was earned (newest-first ordering in the inventory).
    let earned: Date

    init(id: UUID = UUID(), group: SkillCategory?, tier: Int, earned: Date = Date()) {
        self.id = id
        self.group = group
        self.tier = tier
        self.earned = earned
    }

    /// True for a Diary-tier lamp that can be poured into any skill (no group binding).
    var isUniversal: Bool { group == nil }
}
