import Foundation

/// A single thematic training method shown on the training screen for one tier of a skill.
/// `glyph` is the big tappable object; `name` is the call-to-action / banner label.
struct TrainingMethod {
    let name: String
    let glyph: String
}

extension SkillID {
    /// Six thematic training methods — one per `Balance.trainingTiers` entry — evolving from the
    /// most basic action to end-game content, mirroring how the skill is trained in OSRS.
    /// The active method is chosen by the skill's level (see `GameState.currentMethod`).
    var trainingMethods: [TrainingMethod] {
        switch self {
        // MARK: Combat
        case .attack:
            return [
                TrainingMethod(name: "Jab with a bronze sword", glyph: "🗡️"),
                TrainingMethod(name: "Drill with an iron sword", glyph: "⚔️"),
                TrainingMethod(name: "Spar with a steel sword", glyph: "🗡️"),
                TrainingMethod(name: "Duel with a mithril blade", glyph: "⚔️"),
                TrainingMethod(name: "Onslaught with adamant", glyph: "🗡️"),
                TrainingMethod(name: "Master the rune scimitar", glyph: "⚔️")
            ]
        case .strength:
            return [
                TrainingMethod(name: "Punch a training dummy", glyph: "👊"),
                TrainingMethod(name: "Hoist heavy boulders", glyph: "🪨"),
                TrainingMethod(name: "Smash rock crabs", glyph: "🦀"),
                TrainingMethod(name: "Pummel ogres", glyph: "👹"),
                TrainingMethod(name: "Batter hill giants", glyph: "🗿"),
                TrainingMethod(name: "Crush dragons", glyph: "🐉")
            ]
        case .defence:
            return [
                TrainingMethod(name: "Block in leather armour", glyph: "🟫"),
                TrainingMethod(name: "Guard in iron armour", glyph: "🛡️"),
                TrainingMethod(name: "Brace in steel plate", glyph: "🛡️"),
                TrainingMethod(name: "Hold the mithril line", glyph: "🔵"),
                TrainingMethod(name: "Withstand blows in rune", glyph: "🛡️"),
                TrainingMethod(name: "Tank in dragon armour", glyph: "🐲")
            ]
        case .hitpoints:
            return [
                TrainingMethod(name: "Trade blows with rats", glyph: "🐀"),
                TrainingMethod(name: "Endure goblin fights", glyph: "👺"),
                TrainingMethod(name: "Soak up spider bites", glyph: "🕷️"),
                TrainingMethod(name: "Weather ogre clubs", glyph: "👹"),
                TrainingMethod(name: "Brave demon strikes", glyph: "😈"),
                TrainingMethod(name: "Outlast dragonfire", glyph: "🐉")
            ]
        case .ranged:
            return [
                TrainingMethod(name: "Fire a shortbow", glyph: "🏹"),
                TrainingMethod(name: "Loose oak bow shots", glyph: "🏹"),
                TrainingMethod(name: "Volley a willow bow", glyph: "🎯"),
                TrainingMethod(name: "Snipe with a maple bow", glyph: "🏹"),
                TrainingMethod(name: "Barrage with a yew bow", glyph: "🎯"),
                TrainingMethod(name: "Rain magic shortbow arrows", glyph: "✨")
            ]
        case .prayer:
            return [
                TrainingMethod(name: "Bury bones", glyph: "🦴"),
                TrainingMethod(name: "Bury big bones", glyph: "🦴"),
                TrainingMethod(name: "Offer babydragon bones", glyph: "🐲"),
                TrainingMethod(name: "Offer dragon bones", glyph: "🐉"),
                TrainingMethod(name: "Offer superior bones", glyph: "🦴"),
                TrainingMethod(name: "Consecrate a gilded altar", glyph: "⛪")
            ]
        case .magic:
            return [
                TrainingMethod(name: "Cast Wind Strike", glyph: "💨"),
                TrainingMethod(name: "Cast Fire Strike", glyph: "🔥"),
                TrainingMethod(name: "Cast Fire Bolt", glyph: "🔥"),
                TrainingMethod(name: "Cast Fire Blast", glyph: "💥"),
                TrainingMethod(name: "Cast Fire Wave", glyph: "🌊"),
                TrainingMethod(name: "Cast Fire Surge", glyph: "⚡")
            ]

        // MARK: Gathering
        case .woodcutting:
            return [
                TrainingMethod(name: "Chop a normal tree", glyph: "🌳"),
                TrainingMethod(name: "Chop an oak tree", glyph: "🌳"),
                TrainingMethod(name: "Chop a willow tree", glyph: "🌿"),
                TrainingMethod(name: "Chop a maple tree", glyph: "🍁"),
                TrainingMethod(name: "Chop a yew tree", glyph: "🌲"),
                TrainingMethod(name: "Chop a magic tree", glyph: "✨")
            ]
        case .fishing:
            return [
                TrainingMethod(name: "Net some shrimp", glyph: "🦐"),
                TrainingMethod(name: "Bait sardines", glyph: "🐟"),
                TrainingMethod(name: "Fly-fish for trout", glyph: "🎣"),
                TrainingMethod(name: "Harpoon tuna", glyph: "🐟"),
                TrainingMethod(name: "Cage lobsters", glyph: "🦞"),
                TrainingMethod(name: "Harpoon sharks", glyph: "🦈")
            ]
        case .mining:
            return [
                TrainingMethod(name: "Mine copper ore", glyph: "🟤"),
                TrainingMethod(name: "Mine iron ore", glyph: "⛏️"),
                TrainingMethod(name: "Mine coal", glyph: "⚫"),
                TrainingMethod(name: "Mine mithril ore", glyph: "🔵"),
                TrainingMethod(name: "Mine adamantite ore", glyph: "🟢"),
                TrainingMethod(name: "Mine runite ore", glyph: "🔷")
            ]
        case .farming:
            return [
                TrainingMethod(name: "Plant potatoes", glyph: "🥔"),
                TrainingMethod(name: "Grow onions", glyph: "🧅"),
                TrainingMethod(name: "Tend tomatoes", glyph: "🍅"),
                TrainingMethod(name: "Raise apple trees", glyph: "🍎"),
                TrainingMethod(name: "Cultivate herbs", glyph: "🌿"),
                TrainingMethod(name: "Grow magic saplings", glyph: "✨")
            ]
        case .hunter:
            return [
                TrainingMethod(name: "Snare crimson swifts", glyph: "🐦"),
                TrainingMethod(name: "Net butterflies", glyph: "🦋"),
                TrainingMethod(name: "Trap tropical wagtails", glyph: "🪺"),
                TrainingMethod(name: "Box chinchompas", glyph: "🐿️"),
                TrainingMethod(name: "Catch red salamanders", glyph: "🦎"),
                TrainingMethod(name: "Track herbiboars", glyph: "🐗")
            ]

        // MARK: Artisan
        case .cooking:
            return [
                TrainingMethod(name: "Cook shrimp", glyph: "🍤"),
                TrainingMethod(name: "Cook trout", glyph: "🐟"),
                TrainingMethod(name: "Bake bread", glyph: "🍞"),
                TrainingMethod(name: "Cook lobster", glyph: "🦞"),
                TrainingMethod(name: "Cook shark", glyph: "🦈"),
                TrainingMethod(name: "Brew fine wines", glyph: "🍷")
            ]
        case .firemaking:
            return [
                TrainingMethod(name: "Burn normal logs", glyph: "🪵"),
                TrainingMethod(name: "Burn oak logs", glyph: "🔥"),
                TrainingMethod(name: "Burn willow logs", glyph: "🔥"),
                TrainingMethod(name: "Burn maple logs", glyph: "🔥"),
                TrainingMethod(name: "Burn yew logs", glyph: "🔥"),
                TrainingMethod(name: "Burn magic logs", glyph: "✨")
            ]
        case .crafting:
            return [
                TrainingMethod(name: "Tan leather gloves", glyph: "🧤"),
                TrainingMethod(name: "Spin bowstrings", glyph: "🧵"),
                TrainingMethod(name: "Blow molten glass", glyph: "🫙"),
                TrainingMethod(name: "Cut sapphires", glyph: "💙"),
                TrainingMethod(name: "Cut emeralds", glyph: "💚"),
                TrainingMethod(name: "Cut diamonds", glyph: "💎")
            ]
        case .smithing:
            return [
                TrainingMethod(name: "Smith bronze bars", glyph: "🥉"),
                TrainingMethod(name: "Smith iron bars", glyph: "⚙️"),
                TrainingMethod(name: "Smith steel bars", glyph: "🔩"),
                TrainingMethod(name: "Smith mithril bars", glyph: "🔵"),
                TrainingMethod(name: "Smith adamant bars", glyph: "🟢"),
                TrainingMethod(name: "Smith rune bars", glyph: "🔷")
            ]
        case .fletching:
            return [
                TrainingMethod(name: "Whittle arrow shafts", glyph: "🪵"),
                TrainingMethod(name: "String shortbows", glyph: "🏹"),
                TrainingMethod(name: "Carve oak longbows", glyph: "🏹"),
                TrainingMethod(name: "Fletch willow bows", glyph: "🏹"),
                TrainingMethod(name: "Fletch yew bows", glyph: "🎯"),
                TrainingMethod(name: "Fletch magic bows", glyph: "✨")
            ]
        case .herblore:
            return [
                TrainingMethod(name: "Mix Attack potions", glyph: "🧪"),
                TrainingMethod(name: "Brew Strength potions", glyph: "🧪"),
                TrainingMethod(name: "Make Prayer potions", glyph: "💧"),
                TrainingMethod(name: "Mix Super potions", glyph: "⚗️"),
                TrainingMethod(name: "Brew Ranging potions", glyph: "🧪"),
                TrainingMethod(name: "Decant Super Combat", glyph: "⚗️")
            ]
        case .runecraft:
            return [
                TrainingMethod(name: "Craft air runes", glyph: "💨"),
                TrainingMethod(name: "Craft earth runes", glyph: "🟫"),
                TrainingMethod(name: "Craft fire runes", glyph: "🔥"),
                TrainingMethod(name: "Craft nature runes", glyph: "🍃"),
                TrainingMethod(name: "Craft law runes", glyph: "⚖️"),
                TrainingMethod(name: "Craft blood runes", glyph: "🩸")
            ]
        case .construction:
            return [
                TrainingMethod(name: "Build wooden chairs", glyph: "🪑"),
                TrainingMethod(name: "Build oak tables", glyph: "🪵"),
                TrainingMethod(name: "Build teak bookcases", glyph: "📚"),
                TrainingMethod(name: "Build mahogany beds", glyph: "🛏️"),
                TrainingMethod(name: "Build gilded altars", glyph: "⛪"),
                TrainingMethod(name: "Build ornate pools", glyph: "⛲")
            ]

        // MARK: Support
        case .agility:
            return [
                TrainingMethod(name: "Run the Gnome course", glyph: "🏃"),
                TrainingMethod(name: "Draynor rooftops", glyph: "🏘️"),
                TrainingMethod(name: "Varrock rooftops", glyph: "🏙️"),
                TrainingMethod(name: "Canifis rooftops", glyph: "🌙"),
                TrainingMethod(name: "Seers' Village rooftops", glyph: "🏰"),
                TrainingMethod(name: "Ardougne rooftops", glyph: "🗼")
            ]
        case .thieving:
            return [
                TrainingMethod(name: "Pickpocket townsfolk", glyph: "🧍"),
                TrainingMethod(name: "Raid market stalls", glyph: "🍎"),
                TrainingMethod(name: "Pickpocket guards", glyph: "💂"),
                TrainingMethod(name: "Rob Ardougne knights", glyph: "🤺"),
                TrainingMethod(name: "Pickpocket elves", glyph: "🧝"),
                TrainingMethod(name: "Loot vyre chests", glyph: "🗝️")
            ]
        case .slayer:
            return [
                TrainingMethod(name: "Slay crawling hands", glyph: "✋"),
                TrainingMethod(name: "Slay cave crawlers", glyph: "🐛"),
                TrainingMethod(name: "Slay bloodvelds", glyph: "👹"),
                TrainingMethod(name: "Slay abyssal demons", glyph: "😈"),
                TrainingMethod(name: "Slay gargoyles", glyph: "🗿"),
                TrainingMethod(name: "Slay alchemical hydra", glyph: "🐉")
            ]
        }
    }
}
