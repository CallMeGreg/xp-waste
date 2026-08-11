import Foundation

/// The distinct mechanical lever a skill's perk pulls. Every skill maps to a *different* kind,
/// so no two perks do the same thing — leveling any skill benefits the whole account uniquely.
enum BuffKind {
    // Combat — shapes the active tap "hit"
    case accuracy            // Attack: skews each tap's XP roll toward its max hit
    case maxHit              // Strength: raises the ceiling of the tap XP range
    case minHit              // Defence: raises the guaranteed floor of the tap XP range
    case energyRate          // Hitpoints: banks more Supercharge Energy per tap-proc
    case extraHit            // Ranged: chance for a tap to land an extra hit
    case superchargeBonus    // Prayer: +flat to the active Supercharge multiplier
    case doubleXPPotency     // Magic: raises the Daily Boost multiplier above 1.5×
    // Gathering — feeds the idle engine
    case cache               // Woodcutting: chance per tap for a bonus-XP windfall
    case energyProc          // Fishing: multiplies the base per-tap chance to bank Supercharge Energy
    case energyCap           // Mining: raises the maximum bankable Energy
    case offline             // Farming: keeps more idle XP while the app is closed
    case offlineRate         // Hunter: multiplies OFFLINE passive XP (app closed)
    // Artisan — production & the boost economy
    case tapPercent          // Cooking: +% XP on every tap
    case superchargeDuration // Firemaking: Supercharge bursts last longer
    case critMagnitude       // Crafting: critical taps hit harder
    case foregroundRate      // Smithing: multiplies FOREGROUND idle XP (app open)
    case flatTap             // Fletching: +flat XP added to every tap
    case doubleXPDuration    // Herblore: Daily Boosts last longer
    case autoTap             // Runecraft: auto-taps the open skill
    case offlineCap          // Construction: raises the OFFLINE accrual cap (hours)
    // Support — tempo & meta
    case combo               // Agility: tap-streak combo multiplier
    case refund              // Thieving: chance to refund a spent coupon or Supercharge
    case critChance          // Slayer: chance for a critical tap
}

/// Thematic presentation for a skill's perk (name, icon, one-line blurb).
struct SkillBuffInfo {
    let kind: BuffKind
    let name: String
    let icon: String
    let blurb: String
}

extension SkillID {
    /// The unique, account-wide perk this skill confers. Its magnitude scales with the skill's
    /// level (envelope in `Balance.buffScaling`); the effect is applied in `GameState`.
    var buff: SkillBuffInfo {
        switch self {
        // MARK: Combat
        case .attack:
            return SkillBuffInfo(kind: .accuracy, name: "Accuracy", icon: "scope",
                                 blurb: "Skews every tap toward its max hit — fewer low rolls.")
        case .strength:
            return SkillBuffInfo(kind: .maxHit, name: "Power", icon: "bolt.fill",
                                 blurb: "Raises the ceiling of every tap — a chance for bigger clicks.")
        case .defence:
            return SkillBuffInfo(kind: .minHit, name: "Guard", icon: "shield.lefthalf.filled",
                                 blurb: "Raises the guaranteed floor of every tap.")
        case .hitpoints:
            return SkillBuffInfo(kind: .energyRate, name: "Vitality", icon: "heart.fill",
                                 blurb: "Banks more Supercharge Energy each time a tap sparks a charge.")
        case .ranged:
            return SkillBuffInfo(kind: .extraHit, name: "Rapid Fire", icon: "arrow.up.forward.app.fill",
                                 blurb: "Chance for a tap to land an extra hit.")
        case .prayer:
            return SkillBuffInfo(kind: .superchargeBonus, name: "Blessing", icon: "sparkle",
                                 blurb: "Adds to your active Supercharge multiplier.")
        case .magic:
            return SkillBuffInfo(kind: .doubleXPPotency, name: "Enchantment", icon: "wand.and.stars",
                                 blurb: "Empowers the Daily Boost beyond 1.5×.")

        // MARK: Gathering
        case .woodcutting:
            return SkillBuffInfo(kind: .cache, name: "Bird's Nests", icon: "gift.fill",
                                 blurb: "Chance per tap for a bonus-XP windfall.")
        case .fishing:
            return SkillBuffInfo(kind: .energyProc, name: "Big Catch", icon: "drop.fill",
                                 blurb: "Multiplies your chance to bank Supercharge Energy on every tap.")
        case .mining:
            return SkillBuffInfo(kind: .energyCap, name: "Deep Reserves", icon: "battery.100.bolt",
                                 blurb: "Raises your Energy cap for longer Supercharges.")
        case .farming:
            return SkillBuffInfo(kind: .offline, name: "Patient Growth", icon: "moon.zzz.fill",
                                 blurb: "Keeps more idle XP while the app is closed.")
        case .hunter:
            return SkillBuffInfo(kind: .offlineRate, name: "Trapper", icon: "timer",
                                 blurb: "Traps keep working while you're away — faster offline XP.")

        // MARK: Artisan
        case .cooking:
            return SkillBuffInfo(kind: .tapPercent, name: "Well Fed", icon: "fork.knife",
                                 blurb: "+% XP on every tap, on every skill.")
        case .firemaking:
            return SkillBuffInfo(kind: .superchargeDuration, name: "Slow Burn", icon: "flame.fill",
                                 blurb: "Supercharge bursts last longer.")
        case .crafting:
            return SkillBuffInfo(kind: .critMagnitude, name: "Masterwork", icon: "hammer.fill",
                                 blurb: "Critical taps hit even harder.")
        case .smithing:
            return SkillBuffInfo(kind: .foregroundRate, name: "Foundry", icon: "gearshape.2.fill",
                                 blurb: "The forge roars while the app's open — faster idle XP.")
        case .fletching:
            return SkillBuffInfo(kind: .flatTap, name: "Extra Ammo", icon: "plus.circle.fill",
                                 blurb: "Adds flat bonus XP to every tap.")
        case .herblore:
            return SkillBuffInfo(kind: .doubleXPDuration, name: "Alchemist", icon: "hourglass",
                                 blurb: "Daily Boosts last longer.")
        case .runecraft:
            return SkillBuffInfo(kind: .autoTap, name: "Runic Automaton", icon: "cpu.fill",
                                 blurb: "Auto-taps the skill you're training.")
        case .construction:
            return SkillBuffInfo(kind: .offlineCap, name: "Workshop", icon: "wrench.and.screwdriver.fill",
                                 blurb: "Your workshop banks more hours of offline progress.")

        // MARK: Support
        case .agility:
            return SkillBuffInfo(kind: .combo, name: "Momentum", icon: "figure.run",
                                 blurb: "Fast tapping builds a combo multiplier.")
        case .thieving:
            return SkillBuffInfo(kind: .refund, name: "Pickpocket", icon: "ticket.fill",
                                 blurb: "Chance to nick back a spent coupon or Supercharge.")
        case .slayer:
            return SkillBuffInfo(kind: .critChance, name: "Assassinate", icon: "burst.fill",
                                 blurb: "Chance for a critical tap.")
        }
    }
}
