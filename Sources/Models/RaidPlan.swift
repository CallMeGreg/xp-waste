import SwiftUI

/// The interactive verb a single raid room runs. **Every kind is a wholly distinct game loop** — no
/// two rooms in the whole game share one — so a raid reads like an expedition through genuinely
/// different challenges, not one tap-test re-skinned. Twelve kinds fill the twelve rooms (four raids
/// × three rooms). Boss rooms are self-threatening: a reaction boss punishes a missed defence with a
/// heart; a skilling boss trips an alarm. There is **no full-screen dodge** — the combat boss trades
/// blows through red (you strike) and green (incoming) circles instead.
enum RaidRoomKind: String {
    // Combat — The Colosseum
    case laneDodge    // slip the falling volley across three lanes, counter in the gap
    case swipeDodge   // read a beast's telegraphed lunge, swipe away, land the counter
    case duel         // trade blows: tap red openings to strike, tap green blows to parry
    // Production — The Grand Forge
    case rhythm       // strike the sweeping sweet-spot, build a heat combo
    case charge       // hold to stoke heat, release inside the band before it overheats
    case vents        // bleed each over-pressuring tuyère in its green band before one blows out
    // Utility — The Vault Heist
    case stealth      // loot only while the sweeping searchlight is turned away
    case pathTrace    // drag along the safe route past the patrol, hitting each waypoint
    case memory       // memorise then repeat the lit rune sequence
    // Gathering — The Expedition
    case recognition  // tap the *called* resource among decoys
    case mash         // rapid-tap to overpower the haul — but freeze on the thrash
    case sort         // route each streaming haul to its matching bin: fish, logs or ore

    /// The core verb shown on room-intro cards and the raid preview.
    var verb: String {
        switch self {
        case .laneDodge:   return "Dodge & strike"
        case .swipeDodge:  return "Read & sidestep"
        case .duel:        return "Trade blows"
        case .rhythm:      return "Time the strikes"
        case .charge:      return "Stoke & release"
        case .vents:       return "Bleed the vents"
        case .stealth:     return "Loot unseen"
        case .pathTrace:   return "Trace the route"
        case .memory:      return "Repeat the pattern"
        case .recognition: return "Gather the called"
        case .mash:        return "Haul it in"
        case .sort:        return "Sort the haul"
        }
    }

    /// The combat-centric kinds render the boss creature *inside* the mechanic (it is the fight); the
    /// rest are interface-led rooms that show the boss in the engine's banner above the stage.
    var selfDrawsBoss: Bool {
        switch self {
        case .duel, .swipeDodge: return true
        default:                 return false
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
        case .combat:     return "Slip the volley, out-duel two champions of the arena."
        case .production: return "Pour, temper and stamp the war-order under the Forge Master."
        case .utility:    return "Sneak, slip the hound and memorise the vault's every code."
        case .gathering:  return "Read the grove, haul the serpent, feed the Colossus."
        }
    }

    /// SF Symbol used for the raid's banner glyph.
    var raidSymbol: String {
        switch self {
        case .combat:     return "shield.lefthalf.filled"
        case .production: return "hammer.fill"
        case .utility:    return "figure.run"
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

    /// The ordered rooms for this raid. Each raid is a warm-up **skill room → a mini-boss → a tougher
    /// final boss**, and — the core rule — **no mechanic is ever reused**, within a raid or across the
    /// four raids: twelve rooms, twelve distinct game loops. Concrete difficulty (goal size, windows,
    /// boss phases) is resolved from `Balance` at play time, so this stays pure identity.
    func raidRooms(tier: Int) -> [RaidRoom] {
        switch self {
        case .combat:
            return [
                RaidRoom(id: 0, title: "The Volley Pit", kind: .laneDodge, boss: nil,
                         objectiveNoun: "Volleys slipped", objective: "Slide to the safe lane, then strike in the gap"),
                RaidRoom(id: 1, title: "The Sand Beast", kind: .swipeDodge, boss: .beast,
                         objectiveNoun: "Boss HP", objective: "Read the lunge, swipe clear, land the counter"),
                RaidRoom(id: 2, title: "The Champion", kind: .duel, boss: .champion,
                         objectiveNoun: "Boss HP", objective: "Strike the red openings — parry the green blows"),
            ]

        case .production:
            return [
                RaidRoom(id: 0, title: "The Smeltery", kind: .rhythm, boss: nil,
                         objectiveNoun: "Bars poured", objective: "Strike the sweet-spot — a hot combo pours extra bars"),
                RaidRoom(id: 1, title: "The Slag Golem", kind: .charge, boss: .golem,
                         objectiveNoun: "Boss HP", objective: "Stoke the heat, release in the band — don't overheat"),
                RaidRoom(id: 2, title: "The Forge Master", kind: .vents, boss: .foreman,
                         objectiveNoun: "Boss HP", objective: "Bleed each roaring vent in the green — before one blows"),
            ]

        case .utility:
            return [
                RaidRoom(id: 0, title: "The Long Corridor", kind: .stealth, boss: nil,
                         objectiveNoun: "Loot grabbed", objective: "Loot only while the searchlight is turned away"),
                RaidRoom(id: 1, title: "The Warhound", kind: .pathTrace, boss: .hound,
                         objectiveNoun: "Boss HP", objective: "Trace the route past the hound — stay on the path"),
                RaidRoom(id: 2, title: "The Vault Warden", kind: .memory, boss: .warden,
                         objectiveNoun: "Boss HP", objective: "Watch the code light up, then key it back in order"),
            ]

        case .gathering:
            return [
                RaidRoom(id: 0, title: "The Grove", kind: .recognition, boss: nil,
                         objectiveNoun: "Gathered", objective: "Gather only the called resource, skip the decoys"),
                RaidRoom(id: 1, title: "The River Serpent", kind: .mash, boss: .serpent,
                         objectiveNoun: "Boss HP", objective: "Hammer the haul — but freeze the instant it thrashes"),
                RaidRoom(id: 2, title: "The Grove Colossus", kind: .sort, boss: .colossus,
                         objectiveNoun: "Boss HP", objective: "Sort the haul to its bin — fish, logs or ore"),
            ]
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

/// The full payout of a finished raid, returned by `GameState.finishRaid` for the result screen to
/// present. A win always banks exactly one group `lamp`; a **flawless** win (no raid HP lost) adds a
/// tier-scaled **Reward Token** bonus (`flawlessTokens`, 0 otherwise). A loss carries no lamp and no
/// Tokens.
struct RaidReward: Equatable {
    /// The group-bound Skill Lamp banked on a win; `nil` on a loss.
    let lamp: RaidLampRecord?
    /// Reward Tokens granted for a flawless clear (0 for a normal clear or a loss).
    let flawlessTokens: Int

    /// A loss: nothing earned.
    static let none = RaidReward(lamp: nil, flawlessTokens: 0)
}
