import SwiftUI

/// A single thematic training method shown on the training screen for one tier of a skill.
/// `art` is the big tappable object; `name` is the call-to-action / banner label; `tint` is the
/// per-tier material/element colour and `scale` a gentle size ramp — together they make the
/// object read as visibly upgrading (bigger + more advanced) as you level.
struct TrainingMethod {
    let name: String
    let art: SkillArt
    var tint: Color? = nil
    var scale: CGFloat = 1
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
                TrainingMethod(name: "Jab with a bronze sword", art: .vector(.sword), tint: Palette.metal[0]),
                TrainingMethod(name: "Drill with an iron sword", art: .vector(.sword), tint: Palette.metal[1]),
                TrainingMethod(name: "Spar with a steel sword", art: .vector(.sword), tint: Palette.metal[2]),
                TrainingMethod(name: "Duel with a mithril blade", art: .vector(.sword), tint: Palette.metal[3]),
                TrainingMethod(name: "Onslaught with adamant", art: .vector(.sword), tint: Palette.metal[4]),
                TrainingMethod(name: "Master the rune scimitar", art: .vector(.sword), tint: Palette.metal[5])
            ])
        case .strength:
            // One dumbbell, growing heavier bronze → rune.
            return tiered([
                TrainingMethod(name: "Lift bronze weights", art: .symbol("dumbbell.fill"), tint: Palette.metal[0]),
                TrainingMethod(name: "Press iron dumbbells", art: .symbol("dumbbell.fill"), tint: Palette.metal[1]),
                TrainingMethod(name: "Hoist steel dumbbells", art: .symbol("dumbbell.fill"), tint: Palette.metal[2]),
                TrainingMethod(name: "Heave mithril weights", art: .symbol("dumbbell.fill"), tint: Palette.metal[3]),
                TrainingMethod(name: "Haul adamant weights", art: .symbol("dumbbell.fill"), tint: Palette.metal[4]),
                TrainingMethod(name: "Deadlift rune weights", art: .symbol("dumbbell.fill"), tint: Palette.metal[5])
            ])
        case .defence:
            // One shield, bronze → rune.
            return tiered([
                TrainingMethod(name: "Block in bronze armour", art: .symbol("shield.fill"), tint: Palette.metal[0]),
                TrainingMethod(name: "Guard in iron armour", art: .symbol("shield.fill"), tint: Palette.metal[1]),
                TrainingMethod(name: "Brace in steel plate", art: .symbol("shield.fill"), tint: Palette.metal[2]),
                TrainingMethod(name: "Hold the mithril line", art: .symbol("shield.fill"), tint: Palette.metal[3]),
                TrainingMethod(name: "Stand firm in adamant", art: .symbol("shield.fill"), tint: Palette.metal[4]),
                TrainingMethod(name: "Tank in rune armour", art: .symbol("shield.fill"), tint: Palette.metal[5])
            ])
        case .hitpoints:
            // One heart, growing more vital.
            return tiered([
                TrainingMethod(name: "Trade blows with rats", art: .symbol("heart.fill"), tint: Palette.vitality[0]),
                TrainingMethod(name: "Endure goblin fights", art: .symbol("heart.fill"), tint: Palette.vitality[1]),
                TrainingMethod(name: "Soak up spider bites", art: .symbol("heart.fill"), tint: Palette.vitality[2]),
                TrainingMethod(name: "Weather ogre clubs", art: .symbol("heart.fill"), tint: Palette.vitality[3]),
                TrainingMethod(name: "Brave demon strikes", art: .symbol("heart.fill"), tint: Palette.vitality[4]),
                TrainingMethod(name: "Outlast dragonfire", art: .symbol("heart.fill"), tint: Palette.vitality[5])
            ])
        case .ranged:
            // One bow, normal wood → magic.
            return tiered([
                TrainingMethod(name: "Fire a shortbow", art: .vector(.bow), tint: Palette.wood[0]),
                TrainingMethod(name: "Loose oak bow shots", art: .vector(.bow), tint: Palette.wood[1]),
                TrainingMethod(name: "Volley a willow bow", art: .vector(.bow), tint: Palette.wood[2]),
                TrainingMethod(name: "Snipe with a maple bow", art: .vector(.bow), tint: Palette.wood[3]),
                TrainingMethod(name: "Barrage with a yew bow", art: .vector(.bow), tint: Palette.wood[4]),
                TrainingMethod(name: "Rain magic bow arrows", art: .vector(.bow), tint: Palette.wood[5])
            ])
        case .prayer:
            // One bone, small → dagannoth.
            return tiered([
                TrainingMethod(name: "Bury bones", art: .vector(.bone), tint: Palette.rgb(0.90, 0.88, 0.82)),
                TrainingMethod(name: "Bury big bones", art: .vector(.bone), tint: Palette.rgb(0.96, 0.94, 0.86)),
                TrainingMethod(name: "Offer wyrm bones", art: .vector(.bone), tint: Palette.rgb(0.72, 0.82, 0.60)),
                TrainingMethod(name: "Offer dragon bones", art: .vector(.bone), tint: Palette.rgb(0.70, 0.82, 0.94)),
                TrainingMethod(name: "Offer hydra bones", art: .vector(.bone), tint: Palette.rgb(0.36, 0.74, 0.66)),
                TrainingMethod(name: "Offer dagannoth bones", art: .vector(.bone), tint: Palette.rgb(0.95, 0.86, 0.55))
            ])
        case .magic:
            // One spell-cast, cool air → white-hot surge.
            return tiered([
                TrainingMethod(name: "Cast Wind Strike", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.75, 0.88, 0.95)),
                TrainingMethod(name: "Cast Fire Strike", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.96, 0.60, 0.26)),
                TrainingMethod(name: "Cast Fire Bolt", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.96, 0.50, 0.22)),
                TrainingMethod(name: "Cast Fire Blast", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.94, 0.38, 0.22)),
                TrainingMethod(name: "Cast Fire Wave", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.98, 0.66, 0.28)),
                TrainingMethod(name: "Cast Fire Surge", art: .symbol("wand.and.stars"), tint: Palette.rgb(0.74, 0.86, 1.00))
            ])

        // MARK: Gathering
        case .woodcutting:
            // One tree, normal → magic.
            return tiered([
                TrainingMethod(name: "Chop a normal tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.42, 0.62, 0.34)),
                TrainingMethod(name: "Chop an oak tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.36, 0.56, 0.30)),
                TrainingMethod(name: "Chop a willow tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.55, 0.66, 0.34)),
                TrainingMethod(name: "Chop a maple tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.82, 0.46, 0.26)),
                TrainingMethod(name: "Chop a yew tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.28, 0.48, 0.32)),
                TrainingMethod(name: "Chop a magic tree", art: .symbol("tree.fill"), tint: Palette.rgb(0.52, 0.74, 0.95))
            ])
        case .fishing:
            // One fish, shrimp → anglerfish (growing bigger).
            return tiered([
                TrainingMethod(name: "Net shrimp", art: .symbol("fish.fill"), tint: Palette.rgb(0.93, 0.58, 0.53)),
                TrainingMethod(name: "Fly-fish for trout", art: .symbol("fish.fill"), tint: Palette.rgb(0.58, 0.68, 0.82)),
                TrainingMethod(name: "Cage lobsters", art: .symbol("fish.fill"), tint: Palette.rgb(0.86, 0.42, 0.30)),
                TrainingMethod(name: "Harpoon swordfish", art: .symbol("fish.fill"), tint: Palette.rgb(0.46, 0.56, 0.66)),
                TrainingMethod(name: "Harpoon sharks", art: .symbol("fish.fill"), tint: Palette.rgb(0.52, 0.56, 0.62)),
                TrainingMethod(name: "Catch anglerfish", art: .symbol("fish.fill"), tint: Palette.rgb(0.38, 0.44, 0.50))
            ])
        case .mining:
            // One ore chunk, copper → runite.
            return tiered([
                TrainingMethod(name: "Mine copper ore", art: .vector(.ore), tint: Palette.rgb(0.80, 0.50, 0.30)),
                TrainingMethod(name: "Mine iron ore", art: .vector(.ore), tint: Palette.rgb(0.64, 0.56, 0.50)),
                TrainingMethod(name: "Mine coal", art: .vector(.ore), tint: Palette.rgb(0.34, 0.34, 0.38)),
                TrainingMethod(name: "Mine mithril ore", art: .vector(.ore), tint: Palette.rgb(0.42, 0.55, 0.92)),
                TrainingMethod(name: "Mine adamantite ore", art: .vector(.ore), tint: Palette.rgb(0.26, 0.70, 0.50)),
                TrainingMethod(name: "Mine runite ore", art: .vector(.ore), tint: Palette.rgb(0.28, 0.74, 0.80))
            ])
        case .farming:
            // One leaf, humble crop → magic sapling.
            return tiered([
                TrainingMethod(name: "Plant potatoes", art: .symbol("leaf.fill"), tint: Palette.rgb(0.66, 0.56, 0.34)),
                TrainingMethod(name: "Grow onions", art: .symbol("leaf.fill"), tint: Palette.rgb(0.82, 0.74, 0.46)),
                TrainingMethod(name: "Tend tomatoes", art: .symbol("leaf.fill"), tint: Palette.rgb(0.86, 0.35, 0.30)),
                TrainingMethod(name: "Raise apple trees", art: .symbol("leaf.fill"), tint: Palette.rgb(0.50, 0.66, 0.36)),
                TrainingMethod(name: "Cultivate herbs", art: .symbol("leaf.fill"), tint: Palette.rgb(0.38, 0.64, 0.34)),
                TrainingMethod(name: "Grow magic saplings", art: .symbol("leaf.fill"), tint: Palette.rgb(0.52, 0.74, 0.95))
            ])
        case .hunter:
            // One track, common quarry → herbiboar.
            return tiered([
                TrainingMethod(name: "Snare crimson swifts", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.80, 0.35, 0.32)),
                TrainingMethod(name: "Net butterflies", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.90, 0.65, 0.30)),
                TrainingMethod(name: "Trap tropical wagtails", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.55, 0.72, 0.85)),
                TrainingMethod(name: "Box chinchompas", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.70, 0.45, 0.30)),
                TrainingMethod(name: "Catch red salamanders", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.82, 0.38, 0.26)),
                TrainingMethod(name: "Track herbiboars", art: .symbol("pawprint.fill"), tint: Palette.rgb(0.58, 0.52, 0.42))
            ])

        // MARK: Artisan
        case .cooking:
            // One meal, bread → summer pie.
            return tiered([
                TrainingMethod(name: "Bake bread", art: .symbol("fork.knife"), tint: Palette.rgb(0.82, 0.64, 0.40)),
                TrainingMethod(name: "Brew wine", art: .symbol("fork.knife"), tint: Palette.rgb(0.66, 0.24, 0.44)),
                TrainingMethod(name: "Bake pizza", art: .symbol("fork.knife"), tint: Palette.rgb(0.86, 0.40, 0.28)),
                TrainingMethod(name: "Bake cake", art: .symbol("fork.knife"), tint: Palette.rgb(0.93, 0.66, 0.74)),
                TrainingMethod(name: "Cook tuna potato", art: .symbol("fork.knife"), tint: Palette.rgb(0.90, 0.78, 0.46)),
                TrainingMethod(name: "Bake summer pie", art: .symbol("fork.knife"), tint: Palette.rgb(0.95, 0.70, 0.30))
            ])
        case .firemaking:
            // One fire, dull embers → magic flame.
            return tiered([
                TrainingMethod(name: "Burn normal logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.85, 0.42, 0.18)),
                TrainingMethod(name: "Burn oak logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.90, 0.46, 0.16)),
                TrainingMethod(name: "Burn willow logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.94, 0.52, 0.18)),
                TrainingMethod(name: "Burn maple logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.96, 0.58, 0.20)),
                TrainingMethod(name: "Burn yew logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.98, 0.66, 0.24)),
                TrainingMethod(name: "Burn magic logs", art: .symbol("flame.fill"), tint: Palette.rgb(0.55, 0.72, 0.95))
            ])
        case .crafting:
            // One cut gem, sapphire → onyx.
            return tiered([
                TrainingMethod(name: "Cut sapphires", art: .symbol("diamond.fill"), tint: Palette.sapphire),
                TrainingMethod(name: "Cut emeralds", art: .symbol("diamond.fill"), tint: Palette.emerald),
                TrainingMethod(name: "Cut rubies", art: .symbol("diamond.fill"), tint: Palette.rgb(0.85, 0.22, 0.30)),
                TrainingMethod(name: "Cut diamonds", art: .symbol("diamond.fill"), tint: Palette.diamond),
                TrainingMethod(name: "Cut dragonstones", art: .symbol("diamond.fill"), tint: Palette.rgb(0.72, 0.32, 0.66)),
                TrainingMethod(name: "Cut onyx", art: .symbol("diamond.fill"), tint: Palette.rgb(0.34, 0.32, 0.42))
            ])
        case .smithing:
            // One ingot, bronze → rune.
            return tiered([
                TrainingMethod(name: "Smith bronze bars", art: .vector(.ingot), tint: Palette.metal[0]),
                TrainingMethod(name: "Smith iron bars", art: .vector(.ingot), tint: Palette.metal[1]),
                TrainingMethod(name: "Smith steel bars", art: .vector(.ingot), tint: Palette.metal[2]),
                TrainingMethod(name: "Smith mithril bars", art: .vector(.ingot), tint: Palette.metal[3]),
                TrainingMethod(name: "Smith adamant bars", art: .vector(.ingot), tint: Palette.metal[4]),
                TrainingMethod(name: "Smith rune bars", art: .vector(.ingot), tint: Palette.metal[5])
            ])
        case .fletching:
            // One bow, shortbow → magic.
            return tiered([
                TrainingMethod(name: "Fletch shortbows", art: .vector(.bow), tint: Palette.wood[0]),
                TrainingMethod(name: "Fletch oak bows", art: .vector(.bow), tint: Palette.wood[1]),
                TrainingMethod(name: "Fletch willow bows", art: .vector(.bow), tint: Palette.wood[2]),
                TrainingMethod(name: "Fletch maple bows", art: .vector(.bow), tint: Palette.wood[3]),
                TrainingMethod(name: "Fletch yew bows", art: .vector(.bow), tint: Palette.wood[4]),
                TrainingMethod(name: "Fletch magic bows", art: .vector(.bow), tint: Palette.wood[5])
            ])
        case .herblore:
            // One potion, attack → super combat.
            return tiered([
                TrainingMethod(name: "Mix Attack potions", art: .symbol("flask.fill"), tint: Palette.potion[0]),
                TrainingMethod(name: "Brew Strength potions", art: .symbol("flask.fill"), tint: Palette.potion[1]),
                TrainingMethod(name: "Make Prayer potions", art: .symbol("flask.fill"), tint: Palette.potion[2]),
                TrainingMethod(name: "Mix Super energy potions", art: .symbol("flask.fill"), tint: Palette.potion[3]),
                TrainingMethod(name: "Brew Ranging potions", art: .symbol("flask.fill"), tint: Palette.potion[4]),
                TrainingMethod(name: "Decant Super Combat", art: .symbol("flask.fill"), tint: Palette.potion[5])
            ])
        case .runecraft:
            // One rune seal, air → blood.
            return tiered([
                TrainingMethod(name: "Craft air runes", art: .symbol("seal.fill"), tint: Palette.rune[0]),
                TrainingMethod(name: "Craft earth runes", art: .symbol("seal.fill"), tint: Palette.rune[1]),
                TrainingMethod(name: "Craft fire runes", art: .symbol("seal.fill"), tint: Palette.rune[2]),
                TrainingMethod(name: "Craft nature runes", art: .symbol("seal.fill"), tint: Palette.rune[3]),
                TrainingMethod(name: "Craft law runes", art: .symbol("seal.fill"), tint: Palette.rune[4]),
                TrainingMethod(name: "Craft blood runes", art: .symbol("seal.fill"), tint: Palette.rune[5])
            ])
        case .construction:
            // One build, plain wood → ornate.
            return tiered([
                TrainingMethod(name: "Build wooden chairs", art: .symbol("house.fill"), tint: Palette.rgb(0.62, 0.45, 0.28)),
                TrainingMethod(name: "Build oak tables", art: .symbol("house.fill"), tint: Palette.rgb(0.66, 0.48, 0.30)),
                TrainingMethod(name: "Build teak bookcases", art: .symbol("house.fill"), tint: Palette.rgb(0.58, 0.42, 0.30)),
                TrainingMethod(name: "Build mahogany beds", art: .symbol("house.fill"), tint: Palette.rgb(0.70, 0.40, 0.34)),
                TrainingMethod(name: "Build gilded altars", art: .symbol("house.fill"), tint: Palette.rgb(0.95, 0.80, 0.40)),
                TrainingMethod(name: "Build ornate pools", art: .symbol("house.fill"), tint: Palette.rgb(0.40, 0.68, 0.90))
            ])

        // MARK: Support
        case .agility:
            // One runner, Gnome course → Ardougne rooftops.
            return tiered([
                TrainingMethod(name: "Run the Gnome course", art: .symbol("figure.run"), tint: Palette.rgb(0.45, 0.66, 0.42)),
                TrainingMethod(name: "Draynor rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.52, 0.60, 0.70)),
                TrainingMethod(name: "Varrock rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.58, 0.58, 0.64)),
                TrainingMethod(name: "Canifis rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.42, 0.44, 0.62)),
                TrainingMethod(name: "Seers' Village rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.58, 0.66, 0.76)),
                TrainingMethod(name: "Ardougne rooftops", art: .symbol("figure.run"), tint: Palette.rgb(0.42, 0.60, 0.82))
            ])
        case .thieving:
            // One loot bag, townsfolk → vyre chests.
            return tiered([
                TrainingMethod(name: "Pickpocket townsfolk", art: .symbol("bag.fill"), tint: Palette.rgb(0.72, 0.62, 0.52)),
                TrainingMethod(name: "Raid market stalls", art: .symbol("bag.fill"), tint: Palette.rgb(0.80, 0.58, 0.34)),
                TrainingMethod(name: "Pickpocket guards", art: .symbol("bag.fill"), tint: Palette.rgb(0.55, 0.58, 0.66)),
                TrainingMethod(name: "Rob Ardougne knights", art: .symbol("bag.fill"), tint: Palette.rgb(0.74, 0.74, 0.80)),
                TrainingMethod(name: "Pickpocket elves", art: .symbol("bag.fill"), tint: Palette.rgb(0.52, 0.72, 0.54)),
                TrainingMethod(name: "Loot vyre chests", art: .symbol("bag.fill"), tint: Palette.rgb(0.92, 0.78, 0.38))
            ])
        case .slayer:
            // One skull, crawling hands → alchemical hydra.
            return tiered([
                TrainingMethod(name: "Slay crawling hands", art: .vector(.skull), tint: Palette.rgb(0.74, 0.70, 0.64)),
                TrainingMethod(name: "Slay cave crawlers", art: .vector(.skull), tint: Palette.rgb(0.56, 0.70, 0.46)),
                TrainingMethod(name: "Slay bloodvelds", art: .vector(.skull), tint: Palette.rgb(0.80, 0.30, 0.32)),
                TrainingMethod(name: "Slay gargoyles", art: .vector(.skull), tint: Palette.rgb(0.55, 0.56, 0.62)),
                TrainingMethod(name: "Slay abyssal demons", art: .vector(.skull), tint: Palette.rgb(0.56, 0.40, 0.74)),
                TrainingMethod(name: "Slay alchemical hydra", art: .vector(.skull), tint: Palette.rgb(0.92, 0.62, 0.28))
            ])
        }
    }
}
