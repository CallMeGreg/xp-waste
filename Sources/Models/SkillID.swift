import SwiftUI

/// High-level grouping used on the Home hub and Stats screen.
enum SkillCategory: String, Codable, CaseIterable, Identifiable {
    case combat = "Combat"
    case gathering = "Gathering"

    var id: String { rawValue }
}

/// The ten trainable skills, plus their v1 theming (glyph, tint, flavor text).
enum SkillID: String, Codable, CaseIterable, Identifiable {
    // Combat
    case attack, strength, defence, ranged, magic, hitpoints, prayer
    // Gathering
    case woodcutting, fishing, mining

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .attack: return "Attack"
        case .strength: return "Strength"
        case .defence: return "Defence"
        case .ranged: return "Ranged"
        case .magic: return "Magic"
        case .hitpoints: return "Hitpoints"
        case .prayer: return "Prayer"
        case .woodcutting: return "Woodcutting"
        case .fishing: return "Fishing"
        case .mining: return "Mining"
        }
    }

    var category: SkillCategory {
        switch self {
        case .woodcutting, .fishing, .mining: return .gathering
        default: return .combat
        }
    }

    /// Emoji glyph used as the trainable object in v1 (swap for custom art later).
    var glyph: String {
        switch self {
        case .attack: return "⚔️"
        case .strength: return "🪨"
        case .defence: return "🛡️"
        case .ranged: return "🏹"
        case .magic: return "🔮"
        case .hitpoints: return "❤️"
        case .prayer: return "🙏"
        case .woodcutting: return "🌳"
        case .fishing: return "🎣"
        case .mining: return "⛏️"
        }
    }

    /// Short call-to-action shown on the training screen.
    var actionVerb: String {
        switch self {
        case .attack: return "Strike the dummy"
        case .strength: return "Heave the boulder"
        case .defence: return "Brace the shield"
        case .ranged: return "Loose an arrow"
        case .magic: return "Channel the rune"
        case .hitpoints: return "Steel your body"
        case .prayer: return "Offer at the altar"
        case .woodcutting: return "Chop the tree"
        case .fishing: return "Cast your line"
        case .mining: return "Swing the pickaxe"
        }
    }

    /// Signature tint for the skill.
    var tint: Color {
        switch self {
        case .attack: return Color(red: 0.72, green: 0.20, blue: 0.18)
        case .strength: return Color(red: 0.24, green: 0.47, blue: 0.55)
        case .defence: return Color(red: 0.33, green: 0.47, blue: 0.82)
        case .ranged: return Color(red: 0.33, green: 0.58, blue: 0.28)
        case .magic: return Color(red: 0.49, green: 0.37, blue: 0.80)
        case .hitpoints: return Color(red: 0.83, green: 0.28, blue: 0.33)
        case .prayer: return Color(red: 0.87, green: 0.76, blue: 0.36)
        case .woodcutting: return Color(red: 0.45, green: 0.33, blue: 0.18)
        case .fishing: return Color(red: 0.22, green: 0.57, blue: 0.68)
        case .mining: return Color(red: 0.50, green: 0.44, blue: 0.38)
        }
    }

    /// Skills grouped by category, preserving declaration order — used by grid/stat sections.
    static func skills(in category: SkillCategory) -> [SkillID] {
        allCases.filter { $0.category == category }
    }
}
