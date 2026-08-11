import SwiftUI

/// High-level grouping used on the Home hub and Stats screen.
enum SkillCategory: String, Codable, CaseIterable, Identifiable {
    case combat = "Combat"
    case production = "Production"
    case utility = "Utility"
    case gathering = "Gathering"

    var id: String { rawValue }

    /// SF Symbol shown on the category section header.
    var symbol: String {
        switch self {
        case .combat: return "shield.lefthalf.filled"
        case .production: return "hammer.fill"
        case .utility: return "figure.run"
        case .gathering: return "leaf.fill"
        }
    }
}

/// Every trainable Old School RuneScape skill, plus its theming (vector emblem, tint).
/// Declaration order is grouped by category so `skills(in:)` reads top-to-bottom per section.
enum SkillID: String, Codable, CaseIterable, Identifiable {
    // Combat
    case attack, strength, defence, hitpoints, ranged, magic
    // Production
    case smithing, crafting, fletching, runecraft, cooking, construction, firemaking
    // Utility
    case agility, hunter, slayer, thieving, prayer
    // Gathering
    case woodcutting, farming, fishing, mining, herblore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .attack: return "Attack"
        case .strength: return "Strength"
        case .defence: return "Defence"
        case .hitpoints: return "Hitpoints"
        case .ranged: return "Ranged"
        case .prayer: return "Prayer"
        case .magic: return "Magic"
        case .woodcutting: return "Woodcutting"
        case .fishing: return "Fishing"
        case .mining: return "Mining"
        case .farming: return "Farming"
        case .hunter: return "Hunter"
        case .cooking: return "Cooking"
        case .firemaking: return "Firemaking"
        case .crafting: return "Crafting"
        case .smithing: return "Smithing"
        case .fletching: return "Fletching"
        case .herblore: return "Herblore"
        case .runecraft: return "Runecraft"
        case .construction: return "Construction"
        case .agility: return "Agility"
        case .thieving: return "Thieving"
        case .slayer: return "Slayer"
        }
    }

    var category: SkillCategory {
        switch self {
        case .attack, .strength, .defence, .hitpoints, .ranged, .magic:
            return .combat
        case .smithing, .crafting, .fletching, .runecraft, .cooking, .construction, .firemaking:
            return .production
        case .agility, .hunter, .slayer, .thieving, .prayer:
            return .utility
        case .woodcutting, .farming, .fishing, .mining, .herblore:
            return .gathering
        }
    }

    /// Vector emblem representing the skill's identity (used on stats rows & level-up toasts).
    /// The big trainable object and Home tile instead show the *current method* artwork so the
    /// object visibly upgrades as you level. Each emblem is intuitively tied to the skill.
    var art: SkillArt {
        switch self {
        case .attack: return .vector(.sword)
        case .strength: return .vector(.flexArm)
        case .defence: return .symbol("shield.lefthalf.filled")
        case .hitpoints: return .symbol("heart.fill")
        case .ranged: return .vector(.bow)
        case .prayer: return .symbol("hands.and.sparkles.fill")
        case .magic: return .symbol("wand.and.stars")
        case .woodcutting: return .vector(.axe)
        case .fishing: return .symbol("fish.fill")
        case .mining: return .vector(.pickaxe)
        case .farming: return .symbol("carrot.fill")
        case .hunter: return .symbol("pawprint.fill")
        case .cooking: return .symbol("fork.knife")
        case .firemaking: return .symbol("flame.fill")
        case .crafting: return .symbol("scissors")
        case .smithing: return .symbol("hammer.fill")
        case .fletching: return .vector(.arrow)
        case .herblore: return .symbol("flask.fill")
        case .runecraft: return .symbol("seal.fill")
        case .construction: return .symbol("house.fill")
        case .agility: return .symbol("figure.run")
        case .thieving: return .symbol("bag.fill")
        case .slayer: return .vector(.skull)
        }
    }

    /// Signature tint for the skill.
    var tint: Color {
        switch self {
        case .attack: return Color(red: 0.72, green: 0.20, blue: 0.18)
        case .strength: return Color(red: 0.24, green: 0.47, blue: 0.55)
        case .defence: return Color(red: 0.33, green: 0.47, blue: 0.82)
        case .hitpoints: return Color(red: 0.83, green: 0.28, blue: 0.33)
        case .ranged: return Color(red: 0.33, green: 0.58, blue: 0.28)
        case .prayer: return Color(red: 0.87, green: 0.76, blue: 0.36)
        case .magic: return Color(red: 0.49, green: 0.37, blue: 0.80)
        case .woodcutting: return Color(red: 0.45, green: 0.33, blue: 0.18)
        case .fishing: return Color(red: 0.22, green: 0.57, blue: 0.68)
        case .mining: return Color(red: 0.50, green: 0.44, blue: 0.38)
        case .farming: return Color(red: 0.40, green: 0.62, blue: 0.30)
        case .hunter: return Color(red: 0.62, green: 0.49, blue: 0.28)
        case .cooking: return Color(red: 0.82, green: 0.45, blue: 0.28)
        case .firemaking: return Color(red: 0.86, green: 0.42, blue: 0.20)
        case .crafting: return Color(red: 0.63, green: 0.45, blue: 0.34)
        case .smithing: return Color(red: 0.42, green: 0.44, blue: 0.48)
        case .fletching: return Color(red: 0.36, green: 0.55, blue: 0.40)
        case .herblore: return Color(red: 0.30, green: 0.60, blue: 0.42)
        case .runecraft: return Color(red: 0.28, green: 0.62, blue: 0.64)
        case .construction: return Color(red: 0.55, green: 0.40, blue: 0.28)
        case .agility: return Color(red: 0.30, green: 0.52, blue: 0.74)
        case .thieving: return Color(red: 0.55, green: 0.35, blue: 0.66)
        case .slayer: return Color(red: 0.40, green: 0.24, blue: 0.30)
        }
    }

    /// Skills grouped by category, preserving declaration order — used by grid/stat sections.
    static func skills(in category: SkillCategory) -> [SkillID] {
        allCases.filter { $0.category == category }
    }
}
