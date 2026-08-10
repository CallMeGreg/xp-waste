import SwiftUI

/// A single thematic training method shown on the training screen for one tier of a skill.
/// `art` is the big tappable object; `name` is the full call-to-action / banner label; `tint` is
/// the per-tier material/element colour and `scale` a gentle size ramp — together they make the
/// object read as visibly upgrading (bigger + more advanced) as you level.
struct TrainingMethod {
    let name: String
    let art: SkillArt
    var tint: Color? = nil
    var scale: CGFloat = 1
    /// A concise label (usually just the material/species) for the compact method chip, where the
    /// full `name` would truncate. The details sheet still shows the full `name`. Falls back to
    /// `name` when unset.
    var shortName: String? = nil

    /// The label to show in tight spaces (the training-screen chip).
    var tag: String { shortName ?? name }
}

extension SkillID {
    /// Every skill keeps ONE motif across all six tiers (a sword stays a sword, a bone a bone)
    /// so a progression reads as cohesive; `tiered` then layers a size ramp on top of the
    /// per-tier tint so each successive object is clearly larger / heavier than the last.
    private func tiered(_ methods: [TrainingMethod]) -> [TrainingMethod] {
        methods.enumerated().map { index, method in
            var m = method
            m.scale = 0.84 + CGFloat(index) * 0.058   // ~0.84 → 1.13 across the six tiers
            return m
        }
    }

    /// Six thematic training methods — one per `Balance.trainingTiers` entry — evolving from the
    /// most basic action to end-game content, mirroring how the skill is trained in OSRS.
    /// The active method is chosen by the skill's level (see `GameState.currentMethod`).
    var trainingMethods: [TrainingMethod] {
        switch self {
        // MARK: Combat
        case .attack:
            // One sword, bronze → rune.
            return tiered([
                TrainingMethod(name: "Jab with a bronze sword", art: .vector(.sword), tint: Palette.metal[0], shortName: "Bronze sword"),
                TrainingMethod(name: "Drill with an iron sword", art: .vector(.sword), tint: Palette.metal[1], shortName: "Iron sword"),
                TrainingMethod(name: "Spar with a steel sword", art: .vector(.sword), tint: Palette.metal[2], shortName: "Steel sword"),
                TrainingMethod(name: "Duel with a mithril blade", art: .vector(.sword), tint: Palette.metal[3], shortName: "Mithril blade"),
                TrainingMethod(name: "Onslaught with adamant", art: .vector(.sword), tint: Palette.metal[4], shortName: "Adamant sword"),
                TrainingMethod(name: "Master the rune scimitar", art: .vector(.sword), tint: Palette.metal[5], shortName: "Rune scimitar")
            ])
        case .strength:
            // One warhammer, bronze → rune. (OSRS trains Strength with aggressive crush weapons —
            // warhammers/mauls — not dumbbells.)
            return tiered([
                TrainingMethod(name: "Smash with a bronze warhammer", art: .vector(.warhammer), tint: Palette.metal[0], shortName: "Bronze warhammer"),
                TrainingMethod(name: "Pound with an iron warhammer", art: .vector(.warhammer), tint: Palette.metal[1], shortName: "Iron warhammer"),
                TrainingMethod(name: "Crush with a steel warhammer", art: .vector(.warhammer), tint: Palette.metal[2], shortName: "Steel warhammer"),
                TrainingMethod(name: "Batter with a mithril warhammer", art: .vector(.warhammer), tint: Palette.metal[3], shortName: "Mithril warhammer"),
                TrainingMethod(name: "Pulverise with an adamant maul", art: .vector(.warhammer), tint: Palette.metal[4], shortName: "Adamant maul"),
                TrainingMethod(name: "Devastate with a rune warhammer", art: .vector(.warhammer), tint: Palette.metal[5], shortName: "Rune warhammer")
            ])
        case .defence:
            // One shield, bronze → rune.
            return tiered([
                TrainingMethod(name: "Block in bronze armour", art: .symbol("shield.fill"), tint: Palette.metal[0], shortName: "Bronze armour"),
                TrainingMethod(name: "Guard in iron armour", art: .symbol("shield.fill"), tint: Palette.metal[1], shortName: "Iron armour"),
                TrainingMethod(name: "Brace in steel plate", art: .symbol("shield.fill"), tint: Palette.metal[2], shortName: "Steel plate"),
                TrainingMethod(name: "Hold the mithril line", art: .symbol("shield.fill"), tint: Palette.metal[3], shortName: "Mithril armour"),
                TrainingMethod(name: "Stand firm in adamant", art: .symbol("shield.fill"), tint: Palette.metal[4], shortName: "Adamant armour"),
                TrainingMethod(name: "Tank in rune armour", art: .symbol("shield.fill"), tint: Palette.metal[5], shortName: "Rune armour")
            ])
        case .hitpoints:
            // One heart, growing more vital.
            return tiered([
                TrainingMethod(name: "Trade blows with rats", art: .symbol("heart.fill"), tint: Palette.vitality[0], shortName: "Rats"),
                TrainingMethod(name: "Endure goblin fights", art: .symbol("heart.fill"), tint: Palette.vitality[1], shortName: "Goblins"),
                TrainingMethod(name: "Soak up spider bites", art: .symbol("heart.fill"), tint: Palette.vitality[2], shortName: "Spiders"),
                TrainingMethod(name: "Weather ogre clubs", art: .symbol("heart.fill"), tint: Palette.vitality[3], shortName: "Ogres"),
                TrainingMethod(name: "Brave demon strikes", art: .symbol("heart.fill"), tint: Palette.vitality[4], shortName: "Demons"),
                TrainingMethod(name: "Outlast dragonfire", art: .symbol("heart.fill"), tint: Palette.vitality[5], shortName: "Dragons")
            ])
        case .ranged:
            // One bow, normal wood → magic.
            return tiered([
                TrainingMethod(name: "Fire a shortbow", art: .vector(.bow), tint: Palette.wood[0], shortName: "Shortbow"),
                TrainingMethod(name: "Loose oak bow shots", art: .vector(.bow), tint: Palette.wood[1], shortName: "Oak bow"),
                TrainingMethod(name: "Volley a willow bow", art: .vector(.bow), tint: Palette.wood[2], shortName: "Willow bow"),
                TrainingMethod(name: "Snipe with a maple bow", art: .vector(.bow), tint: Palette.wood[3], shortName: "Maple bow"),
                TrainingMethod(name: "Barrage with a yew bow", art: .vector(.bow), tint: Palette.wood[4], shortName: "Yew bow"),
                TrainingMethod(name: "Rain magic bow arrows", art: .vector(.bow), tint: Palette.wood[5], shortName: "Magic bow")
            ])
        case .prayer:
            // One bone, small → dagannoth.
            return tiered([
                TrainingMethod(name: "Bury bones", art: .vector(.bone), tint: Palette.rgb(0.90, 0.88, 0.82), shortName: "Bones"),
                TrainingMethod(name: "Bury big bones", art: .vector(.bone), tint: Palette.rgb(0.96, 0.94, 0.86), shortName: "Big bones"),
                TrainingMethod(name: "Offer wyrm bones", art: .vector(.bone), tint: Palette.rgb(0.72, 0.82, 0.60), shortName: "Wyrm bones"),
                TrainingMethod(name: "Offer dragon bones", art: .vector(.bone), tint: Palette.rgb(0.70, 0.82, 0.94), shortName: "Dragon bones"),
                TrainingMethod(name: "Offer hydra bones", art: .vector(.bone), tint: Palette.rgb(0.36, 0.74, 0.66), shortName: "Hydra bones"),
                TrainingMethod(name: "Offer dagannoth bones", art: .vector(.bone), tint: Palette.rgb(0.95, 0.86, 0.55), shortName: "Dagannoth bones")
            ])
        case .magic:
            // One spell-cast, cool air → white-hot surge.
            return tiered([
                TrainingMethod(name: "Cast Wind Strike", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.75, 0.88, 0.95), shortName: "Wind Strike"),
                TrainingMethod(name: "Cast Fire Strike", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.96, 0.60, 0.26), shortName: "Fire Strike"),
                TrainingMethod(name: "Cast Fire Bolt", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.96, 0.50, 0.22), shortName: "Fire Bolt"),
                TrainingMethod(name: "Cast Fire Blast", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.94, 0.38, 0.22), shortName: "Fire Blast"),
                TrainingMethod(name: "Cast Fire Wave", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.98, 0.66, 0.28), shortName: "Fire Wave"),
                TrainingMethod(name: "Cast Fire Surge", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.74, 0.86, 1.00), shortName: "Fire Surge")
            ])

        // MARK: Gathering
        case .woodcutting:
            // One tree, normal → magic.
            return tiered([
                TrainingMethod(name: "Chop a normal tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.42, 0.62, 0.34), shortName: "Normal tree"),
                TrainingMethod(name: "Chop an oak tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.36, 0.56, 0.30), shortName: "Oak tree"),
                TrainingMethod(name: "Chop a willow tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.55, 0.66, 0.34), shortName: "Willow tree"),
                TrainingMethod(name: "Chop a maple tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.82, 0.46, 0.26), shortName: "Maple tree"),
                TrainingMethod(name: "Chop a yew tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.28, 0.48, 0.32), shortName: "Yew tree"),
                TrainingMethod(name: "Chop a magic tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.52, 0.74, 0.95), shortName: "Magic tree")
            ])
        case .fishing:
            // One fish, shrimp → anglerfish (growing bigger).
            return tiered([
                TrainingMethod(name: "Net shrimp", art: .symbol("fish.fill"), tint: Palette.rgb(0.93, 0.58, 0.53), shortName: "Shrimp"),
                TrainingMethod(name: "Fly-fish for trout", art: .symbol("fish.fill"), tint: Palette.rgb(0.58, 0.68, 0.82), shortName: "Trout"),
                TrainingMethod(name: "Cage lobsters", art: .symbol("fish.fill"), tint: Palette.rgb(0.86, 0.42, 0.30), shortName: "Lobsters"),
                TrainingMethod(name: "Harpoon swordfish", art: .symbol("fish.fill"), tint: Palette.rgb(0.46, 0.56, 0.66), shortName: "Swordfish"),
                TrainingMethod(name: "Harpoon sharks", art: .symbol("fish.fill"), tint: Palette.rgb(0.52, 0.56, 0.62), shortName: "Sharks"),
                TrainingMethod(name: "Catch anglerfish", art: .symbol("fish.fill"), tint: Palette.rgb(0.38, 0.44, 0.50), shortName: "Anglerfish")
            ])
        case .mining:
            // One ore chunk, copper → runite.
            return tiered([
                TrainingMethod(name: "Mine copper ore", art: .vector(.ore), tint: Palette.rgb(0.80, 0.50, 0.30), shortName: "Copper ore"),
                TrainingMethod(name: "Mine iron ore", art: .vector(.ore), tint: Palette.rgb(0.64, 0.56, 0.50), shortName: "Iron ore"),
                TrainingMethod(name: "Mine coal", art: .vector(.ore), tint: Palette.rgb(0.34, 0.34, 0.38), shortName: "Coal"),
                TrainingMethod(name: "Mine mithril ore", art: .vector(.ore), tint: Palette.rgb(0.42, 0.55, 0.92), shortName: "Mithril ore"),
                TrainingMethod(name: "Mine adamantite ore", art: .vector(.ore), tint: Palette.rgb(0.26, 0.70, 0.50), shortName: "Adamantite"),
                TrainingMethod(name: "Mine runite ore", art: .vector(.ore), tint: Palette.rgb(0.28, 0.74, 0.80), shortName: "Runite ore")
            ])
        case .farming:
            // One leaf, humble crop → magic sapling.
            return tiered([
                TrainingMethod(name: "Plant potatoes", art: .symbol("leaf.fill"), tint: Palette.rgb(0.66, 0.56, 0.34), shortName: "Potatoes"),
                TrainingMethod(name: "Grow onions", art: .symbol("leaf.fill"), tint: Palette.rgb(0.82, 0.74, 0.46), shortName: "Onions"),
                TrainingMethod(name: "Tend tomatoes", art: .symbol("leaf.fill"), tint: Palette.rgb(0.86, 0.35, 0.30), shortName: "Tomatoes"),
                TrainingMethod(name: "Raise apple trees", art: .symbol("leaf.fill"), tint: Palette.rgb(0.50, 0.66, 0.36), shortName: "Apple trees"),
                TrainingMethod(name: "Cultivate herbs", art: .symbol("leaf.fill"), tint: Palette.rgb(0.38, 0.64, 0.34), shortName: "Herbs"),
                TrainingMethod(name: "Grow magic saplings", art: .symbol("leaf.fill"), tint: Palette.rgb(0.52, 0.74, 0.95), shortName: "Magic saplings")
            ])
        case .hunter:
            // One track, common quarry → herbiboar.
            return tiered([
                TrainingMethod(name: "Snare crimson swifts", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.80, 0.35, 0.32), shortName: "Crimson swifts"),
                TrainingMethod(name: "Net butterflies", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.90, 0.65, 0.30), shortName: "Butterflies"),
                TrainingMethod(name: "Trap tropical wagtails", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.55, 0.72, 0.85), shortName: "Wagtails"),
                TrainingMethod(name: "Box chinchompas", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.70, 0.45, 0.30), shortName: "Chinchompas"),
                TrainingMethod(name: "Catch red salamanders", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.82, 0.38, 0.26), shortName: "Salamanders"),
                TrainingMethod(name: "Track herbiboars", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.58, 0.52, 0.42), shortName: "Herbiboars")
            ])

        // MARK: Artisan
        case .cooking:
            // One meal, bread → summer pie.
            return tiered([
                TrainingMethod(name: "Bake bread", art: .symbol("fork.knife"), tint: Palette.rgb(0.82, 0.64, 0.40), shortName: "Bread"),
                TrainingMethod(name: "Brew wine", art: .symbol("fork.knife"), tint: Palette.rgb(0.66, 0.24, 0.44), shortName: "Wine"),
                TrainingMethod(name: "Bake pizza", art: .symbol("fork.knife"), tint: Palette.rgb(0.86, 0.40, 0.28), shortName: "Pizza"),
                TrainingMethod(name: "Bake cake", art: .symbol("fork.knife"), tint: Palette.rgb(0.93, 0.66, 0.74), shortName: "Cake"),
                TrainingMethod(name: "Cook tuna potato", art: .symbol("fork.knife"), tint: Palette.rgb(0.90, 0.78, 0.46), shortName: "Tuna potato"),
                TrainingMethod(name: "Bake summer pie", art: .symbol("fork.knife"), tint: Palette.rgb(0.95, 0.70, 0.30), shortName: "Summer pie")
            ])
        case .firemaking:
            // One fire, dull embers → magic flame.
            return tiered([
                TrainingMethod(name: "Burn normal logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.85, 0.42, 0.18), shortName: "Normal logs"),
                TrainingMethod(name: "Burn oak logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.90, 0.46, 0.16), shortName: "Oak logs"),
                TrainingMethod(name: "Burn willow logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.94, 0.52, 0.18), shortName: "Willow logs"),
                TrainingMethod(name: "Burn maple logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.96, 0.58, 0.20), shortName: "Maple logs"),
                TrainingMethod(name: "Burn yew logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.98, 0.66, 0.24), shortName: "Yew logs"),
                TrainingMethod(name: "Burn magic logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.55, 0.72, 0.95), shortName: "Magic logs")
            ])
        case .crafting:
            // One cut gem, sapphire → onyx.
            return tiered([
                TrainingMethod(name: "Cut sapphires", art: .symbol("diamond.fill"), tint: Palette.sapphire, shortName: "Sapphires"),
                TrainingMethod(name: "Cut emeralds", art: .symbol("diamond.fill"), tint: Palette.emerald, shortName: "Emeralds"),
                TrainingMethod(name: "Cut rubies", art: .symbol("diamond.fill"), tint: Palette.rgb(0.85, 0.22, 0.30), shortName: "Rubies"),
                TrainingMethod(name: "Cut diamonds", art: .symbol("diamond.fill"), tint: Palette.diamond, shortName: "Diamonds"),
                TrainingMethod(name: "Cut dragonstones", art: .symbol("diamond.fill"), tint: Palette.rgb(0.72, 0.32, 0.66), shortName: "Dragonstones"),
                TrainingMethod(name: "Cut onyx", art: .symbol("diamond.fill"), tint: Palette.rgb(0.34, 0.32, 0.42), shortName: "Onyx")
            ])
        case .smithing:
            // One ingot, bronze → rune.
            return tiered([
                TrainingMethod(name: "Smith bronze bars", art: .vector(.ingot), tint: Palette.metal[0], shortName: "Bronze bars"),
                TrainingMethod(name: "Smith iron bars", art: .vector(.ingot), tint: Palette.metal[1], shortName: "Iron bars"),
                TrainingMethod(name: "Smith steel bars", art: .vector(.ingot), tint: Palette.metal[2], shortName: "Steel bars"),
                TrainingMethod(name: "Smith mithril bars", art: .vector(.ingot), tint: Palette.metal[3], shortName: "Mithril bars"),
                TrainingMethod(name: "Smith adamant bars", art: .vector(.ingot), tint: Palette.metal[4], shortName: "Adamant bars"),
                TrainingMethod(name: "Smith rune bars", art: .vector(.ingot), tint: Palette.metal[5], shortName: "Rune bars")
            ])
        case .fletching:
            // Bow-making ladder (shortbow → magic), but shown as a quiver of arrows so Fletching
            // reads distinctly from Ranged's bow at a glance.
            return tiered([
                TrainingMethod(name: "Fletch shortbows", art: .vector(.quiver), tint: Palette.wood[0], shortName: "Shortbows"),
                TrainingMethod(name: "Fletch oak bows", art: .vector(.quiver), tint: Palette.wood[1], shortName: "Oak bows"),
                TrainingMethod(name: "Fletch willow bows", art: .vector(.quiver), tint: Palette.wood[2], shortName: "Willow bows"),
                TrainingMethod(name: "Fletch maple bows", art: .vector(.quiver), tint: Palette.wood[3], shortName: "Maple bows"),
                TrainingMethod(name: "Fletch yew bows", art: .vector(.quiver), tint: Palette.wood[4], shortName: "Yew bows"),
                TrainingMethod(name: "Fletch magic bows", art: .vector(.quiver), tint: Palette.wood[5], shortName: "Magic bows")
            ])
        case .herblore:
            // One potion, attack → super combat.
            return tiered([
                TrainingMethod(name: "Mix Attack potions", art: .symbol("flask.fill"), tint: Palette.potion[0], shortName: "Attack potions"),
                TrainingMethod(name: "Brew Strength potions", art: .symbol("flask.fill"), tint: Palette.potion[1], shortName: "Strength potions"),
                TrainingMethod(name: "Make Prayer potions", art: .symbol("flask.fill"), tint: Palette.potion[2], shortName: "Prayer potions"),
                TrainingMethod(name: "Mix Super energy potions", art: .symbol("flask.fill"), tint: Palette.potion[3], shortName: "Super energy"),
                TrainingMethod(name: "Brew Ranging potions", art: .symbol("flask.fill"), tint: Palette.potion[4], shortName: "Ranging potions"),
                TrainingMethod(name: "Decant Super Combat", art: .symbol("flask.fill"), tint: Palette.potion[5], shortName: "Super Combat")
            ])
        case .runecraft:
            // One rune seal, air → blood.
            return tiered([
                TrainingMethod(name: "Craft air runes", art: .symbol("seal.fill"), tint: Palette.rune[0], shortName: "Air runes"),
                TrainingMethod(name: "Craft earth runes", art: .symbol("seal.fill"), tint: Palette.rune[1], shortName: "Earth runes"),
                TrainingMethod(name: "Craft fire runes", art: .symbol("seal.fill"), tint: Palette.rune[2], shortName: "Fire runes"),
                TrainingMethod(name: "Craft nature runes", art: .symbol("seal.fill"), tint: Palette.rune[3], shortName: "Nature runes"),
                TrainingMethod(name: "Craft law runes", art: .symbol("seal.fill"), tint: Palette.rune[4], shortName: "Law runes"),
                TrainingMethod(name: "Craft blood runes", art: .symbol("seal.fill"), tint: Palette.rune[5], shortName: "Blood runes")
            ])
        case .construction:
            // One build, plain wood → ornate.
            return tiered([
                TrainingMethod(name: "Build wooden chairs", art: .symbol("house.fill"), tint: Palette.rgb(0.62, 0.45, 0.28), shortName: "Wooden chairs"),
                TrainingMethod(name: "Build oak tables", art: .symbol("house.fill"), tint: Palette.rgb(0.66, 0.48, 0.30), shortName: "Oak tables"),
                TrainingMethod(name: "Build teak bookcases", art: .symbol("house.fill"), tint: Palette.rgb(0.58, 0.42, 0.30), shortName: "Teak bookcases"),
                TrainingMethod(name: "Build mahogany beds", art: .symbol("house.fill"), tint: Palette.rgb(0.70, 0.40, 0.34), shortName: "Mahogany beds"),
                TrainingMethod(name: "Build gilded altars", art: .symbol("house.fill"), tint: Palette.rgb(0.95, 0.80, 0.40), shortName: "Gilded altars"),
                TrainingMethod(name: "Build ornate pools", art: .symbol("house.fill"), tint: Palette.rgb(0.40, 0.68, 0.90), shortName: "Ornate pools")
            ])

        // MARK: Support
        case .agility:
            // One runner, Gnome course → Ardougne rooftops.
            return tiered([
                TrainingMethod(name: "Run the Gnome course", art: .symbol("figure.run"), tint: Palette.rgb(0.45, 0.66, 0.42), shortName: "Gnome course"),
                TrainingMethod(name: "Draynor rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.52, 0.60, 0.70), shortName: "Draynor rooftops"),
                TrainingMethod(name: "Varrock rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.58, 0.58, 0.64), shortName: "Varrock rooftops"),
                TrainingMethod(name: "Canifis rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.42, 0.44, 0.62), shortName: "Canifis rooftops"),
                TrainingMethod(name: "Seers' Village rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.58, 0.66, 0.76), shortName: "Seers' rooftops"),
                TrainingMethod(name: "Ardougne rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.42, 0.60, 0.82), shortName: "Ardougne rooftops")
            ])
        case .thieving:
            // One loot bag, townsfolk → vyre chests.
            return tiered([
                TrainingMethod(name: "Pickpocket townsfolk", art: .symbol("bag.fill"), tint: Palette.rgb(0.72, 0.62, 0.52), shortName: "Townsfolk"),
                TrainingMethod(name: "Raid market stalls", art: .symbol("bag.fill"), tint: Palette.rgb(0.80, 0.58, 0.34), shortName: "Market stalls"),
                TrainingMethod(name: "Pickpocket guards", art: .symbol("bag.fill"), tint: Palette.rgb(0.55, 0.58, 0.66), shortName: "Guards"),
                TrainingMethod(name: "Rob Ardougne knights", art: .symbol("bag.fill"), tint: Palette.rgb(0.74, 0.74, 0.80), shortName: "Knights"),
                TrainingMethod(name: "Pickpocket elves", art: .symbol("bag.fill"), tint: Palette.rgb(0.52, 0.72, 0.54), shortName: "Elves"),
                TrainingMethod(name: "Loot vyre chests", art: .symbol("bag.fill"), tint: Palette.rgb(0.92, 0.78, 0.38), shortName: "Vyre chests")
            ])
        case .slayer:
            // One skull, crawling hands → alchemical hydra.
            return tiered([
                TrainingMethod(name: "Slay crawling hands", art: .vector(.skull), tint: Palette.rgb(0.74, 0.70, 0.64), shortName: "Crawling hands"),
                TrainingMethod(name: "Slay cave crawlers", art: .vector(.skull), tint: Palette.rgb(0.56, 0.70, 0.46), shortName: "Cave crawlers"),
                TrainingMethod(name: "Slay bloodvelds", art: .vector(.skull), tint: Palette.rgb(0.80, 0.30, 0.32), shortName: "Bloodvelds"),
                TrainingMethod(name: "Slay gargoyles", art: .vector(.skull), tint: Palette.rgb(0.55, 0.56, 0.62), shortName: "Gargoyles"),
                TrainingMethod(name: "Slay abyssal demons", art: .vector(.skull), tint: Palette.rgb(0.56, 0.40, 0.74), shortName: "Abyssal demons"),
                TrainingMethod(name: "Slay alchemical hydra", art: .vector(.skull), tint: Palette.rgb(0.92, 0.62, 0.28), shortName: "Alchemical hydra")
            ])
        }
    }
}
