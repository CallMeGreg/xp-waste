import SwiftUI

/// The interactive verb a single raid room runs. Each kind is a *distinct* on-screen interface with
/// its own goal, so a raid strings several together and reads like an expedition through rooms —
/// not one repeated tap-test. Boss rooms layer a telegraphed dodge on top of the skilling kinds
/// (see `usesEngineHazards`), so even a "skilling" finale is a real fight.
enum RaidRoomKind: String {
    case barrage      // dodge sweeping hazards across three lanes, strike in the gaps
    case assault      // tap glowing weakpoints on a foe while it slams
    case forge        // rhythm: strike the sweeping meter's sweet-spot, build a combo
    case recognition  // tap the *called* resource among decoys (recognition + speed)
    case stealth      // loot while the sweeping searchlight is turned away (restraint)
    case sequence     // memorise then repeat a lit glyph sequence (puzzle)

    /// The core verb shown on room-intro cards and the raid preview.
    var verb: String {
        switch self {
        case .barrage:     return "Dodge & strike"
        case .assault:     return "Break the weakpoints"
        case .forge:       return "Time the strikes"
        case .recognition: return "Gather the called"
        case .stealth:     return "Loot unseen"
        case .sequence:    return "Repeat the pattern"
        }
    }

    /// A boss room of a *skilling* kind (forge/recognition/stealth/sequence) gets the shared
    /// telegraphed-slam overlay so it fights back; `barrage` and `assault` already own their dodge.
    func usesEngineHazards(isBoss: Bool) -> Bool {
        guard isBoss else { return false }
        switch self {
        case .barrage, .assault: return false
        default:                 return true
        }
    }
}

/// A boss silhouette, drawn by the parametrised `RaidBossView`. Each maps to a body archetype +
/// palette so the roster looks varied without a bespoke asset per creature.
enum RaidBoss: String {
    case beast, champion            // Colosseum
    case golem, foreman             // Grand Forge
    case hound, warden              // The Heist
    case serpent, colossus          // The Expedition

    /// Proper name shown in the HUD and intro card.
    var name: String {
        switch self {
        case .beast:    return "The Sand Beast"
        case .champion: return "The Champion"
        case .golem:    return "The Slag Golem"
        case .foreman:  return "The Forge Master"
        case .hound:    return "The Warhound"
        case .warden:   return "The Vault Warden"
        case .serpent:  return "The River Serpent"
        case .colossus: return "The Grove Colossus"
        }
    }

    /// One-line boss "attack" flavor, shown under the name.
    var threat: String {
        switch self {
        case .beast:    return "Sand slams & a raking swipe"
        case .champion: return "Crushing blows — enrages when wounded"
        case .golem:    return "Molten splash on every heat"
        case .foreman:  return "Rejects flawed work — showers sparks"
        case .hound:    return "Lunges from the dark"
        case .warden:   return "A sweeping, all-seeing eye"
        case .serpent:  return "Thrashing tail across the shallows"
        case .colossus: return "Ground-splitting stomps"
        }
    }
}

/// One room in a raid: a mechanic + theming, optionally fronted by a boss. Its concrete difficulty
/// (goal size, windows, phases) is resolved from `Balance` at play time by `RaidSessionView`, so
/// this stays pure identity — no magic numbers.
struct RaidRoom: Identifiable {
    let id: Int
    /// Room title ("The Smeltery", "The Champion").
    let title: String
    /// The mechanic driving the room.
    let kind: RaidRoomKind
    /// Non-nil for a boss room: the progress bar reads as boss HP and (for skilling kinds) the room
    /// gains telegraphed slams. The final room of every raid is a boss and is the toughest.
    let boss: RaidBoss?
    /// What the progress bar counts, for the HUD ("Boss HP", "Bars poured", "Loot", …).
    let objectiveNoun: String
    /// Short imperative shown on the room-intro card.
    let objective: String

    var isBoss: Bool { boss != nil }
}

extension SkillCategory {

    /// The raid's proper name, thematically tied to how the group's skills are trained in OSRS.
    var raidName: String {
        switch self {
        case .combat:     return "The Colosseum"
        case .production: return "The Grand Forge"
        case .utility:    return "The Vault Heist"
        case .gathering:  return "The Expedition"
        }
    }

    /// A one-line pitch for the raid card.
    var raidTagline: String {
        switch self {
        case .combat:     return "Three bouts against the arena's champions."
        case .production: return "Fill the war-order before the Forge Master."
        case .utility:    return "Three wards stand between you and the vault."
        case .gathering:  return "Harvest three biomes ahead of the storm."
        }
    }

    /// SF Symbol used for the raid's banner glyph.
    var raidSymbol: String {
        switch self {
        case .combat:     return "shield.lefthalf.filled"
        case .production: return "hammer.fill"
        case .utility:    return "key.fill"
        case .gathering:  return "leaf.fill"
        }
    }

    /// Signature accent for the raid UI (distinct per group, cohesive with its skills).
    var raidTint: Color {
        switch self {
        case .combat:     return Color(red: 0.86, green: 0.32, blue: 0.28)
        case .production: return Color(red: 0.92, green: 0.56, blue: 0.24)
        case .utility:    return Color(red: 0.56, green: 0.44, blue: 0.86)
        case .gathering:  return Color(red: 0.36, green: 0.70, blue: 0.40)
        }
    }

    /// A secondary accent used for backdrops / gradients so each raid reads as its own place.
    var raidTintDeep: Color {
        switch self {
        case .combat:     return Color(red: 0.34, green: 0.10, blue: 0.12)
        case .production: return Color(red: 0.30, green: 0.15, blue: 0.06)
        case .utility:    return Color(red: 0.16, green: 0.13, blue: 0.30)
        case .gathering:  return Color(red: 0.10, green: 0.22, blue: 0.14)
        }
    }

    /// OSRS-metal flavor name for a raid tier (0…5), mirroring the training-method material ladder.
    static func raidTierName(_ tier: Int) -> String {
        let names = ["Bronze", "Iron", "Steel", "Mithril", "Adamant", "Rune"]
        return names[min(max(tier, 0), names.count - 1)]
    }

    /// Tint for a raid tier, matching the named material via the shared metal ladder.
    static func raidTierColor(_ tier: Int) -> Color {
        Palette.metal[min(max(tier, 0), Palette.metal.count - 1)]
    }

    /// The ordered rooms for this raid at `tier`. Every raid has a **mini-boss** midway and a
    /// **final boss** that is tougher than the rest; the top tiers (`roomCount == 4`) splice in an
    /// extra "elite" room before the finale, so difficulty grows *structurally*, not just by tighter
    /// windows. The mechanic mix per raid is deliberately varied (dodge / assault / skilling).
    func raidRooms(tier: Int) -> [RaidRoom] {
        let fourRooms = Balance.raidRoomCount(forTier: tier) >= 4
        var specs: [(String, RaidRoomKind, RaidBoss?, String, String)]

        switch self {
        case .combat:
            specs = [
                ("The Volley Pit", .barrage, nil, "Waves cleared", "Slip the volley, strike the archers"),
                ("The Sand Beast", .assault, .beast, "Boss HP", "Batter the beast, dodge its slams"),
            ]
            if fourRooms { specs.append(
                ("The Gauntlet", .barrage, nil, "Waves cleared", "Run the twin volleys")) }
            specs.append(
                ("The Champion", .assault, .champion, "Boss HP", "Fell the Champion through every phase"))

        case .production:
            specs = [
                ("The Smeltery", .forge, nil, "Bars poured", "Strike the sweet-spot, pour the bars"),
                ("The Slag Golem", .assault, .golem, "Boss HP", "Shatter its molten core, dodge the splash"),
            ]
            if fourRooms { specs.append(
                ("The Assembly", .sequence, nil, "Recipes done", "Repeat each recipe in order")) }
            specs.append(
                ("The Forge Master", .forge, .foreman, "Boss HP", "Out-smith the master — mind the sparks"))

        case .utility:
            specs = [
                ("The Long Corridor", .stealth, nil, "Loot grabbed", "Loot only while the light is turned"),
                ("The Warhound", .barrage, .hound, "Boss HP", "Slip the hound's lunges, land your strikes"),
            ]
            if fourRooms { specs.append(
                ("The Tumblers", .sequence, nil, "Locks picked", "Repeat each tumbler pattern")) }
            specs.append(
                ("The Vault Warden", .stealth, .warden, "Boss HP", "Rob the vault under its sweeping eye"))

        case .gathering:
            specs = [
                ("The Grove", .recognition, nil, "Gathered", "Gather the called resource, skip decoys"),
                ("The River Serpent", .barrage, .serpent, "Boss HP", "Catch the drift, dodge its thrashing tail"),
            ]
            if fourRooms { specs.append(
                ("The Drying Racks", .forge, nil, "Racks filled", "Time the racks, cure the catch")) }
            specs.append(
                ("The Grove Colossus", .recognition, .colossus, "Boss HP", "Feed it the right offerings, dodge its stomps"))
        }

        return specs.enumerated().map { index, s in
            RaidRoom(id: index, title: s.0, kind: s.1, boss: s.2, objectiveNoun: s.3, objective: s.4)
        }
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
