# Idle Skiller ⚔️🌳⛏️

An **OSRS-inspired idle / clicker skilling game** for iOS, built in SwiftUI. Train all **23
Old School RuneScape skills** from level 1 to 99 using the exact OSRS experience curve — by
tapping, setting up passive training, and banking **Energy** while you're away for bonus-XP
**Supercharge** bursts. Universal: designed for **both iPhone and iPad**.

See **[GAME_DESIGN.md](GAME_DESIGN.md)** for the full design, balance table, and critique.

## Features

- **All 23 skills** across four categories — **Combat** (Attack, Strength, Defence, Hitpoints,
  Ranged, Prayer, Magic), **Gathering** (Woodcutting, Fishing, Mining, Farming, Hunter),
  **Artisan** (Cooking, Firemaking, Crafting, Smithing, Fletching, Herblore, Runecraft,
  Construction) and **Support** (Agility, Thieving, Slayer) — each on the real OSRS XP curve
  (L99 = 13,034,431 XP).
- **Thematic, tiered training methods** — every skill has **6 methods** that evolve with your
  level (e.g. Woodcutting: normal → oak → willow → maple → yew → magic tree). Higher tiers award
  more XP per tap (1 / 3 / 6 / 12 / 25 / 50) and visibly upgrade the tappable object.
- **Tap to train** a full-screen thematic object with floating feedback and haptics.
- **Training slots** for passive XP (1 → 2 → 3 slots as your total level grows).
- **Energy & Supercharge** — bank up to 30s of Supercharge while the app is open *or closed*,
  then spend it for a **×2 / ×5 / ×10 / ×20** XP-per-tap burst (multiplier scales with total level).
- **Double XP coupons** — activate a coupon for **10 minutes of 2× XP on every skill** (stacks
  with Supercharge). One **free coupon daily**, plus **in-app purchase** packs (StoreKit 2).
- **Universal, responsive UI** — adaptive skill grid and a size-class-aware training screen
  (two-pane on iPad / regular width, single column on iPhone). Looks great in portrait and, on
  iPad, in every orientation.
- **Home hub, Stats/Milestones, Settings**, and first-launch onboarding.
- Full **offline-Energy** crediting and `UserDefaults` persistence.

## Requirements

- Xcode 16+ (developed with Xcode 26.6 / iOS 26.5 SDK)
- iOS 17.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to (re)generate the project:
  `brew install xcodegen`

## Build & run

The Xcode project is generated from `project.yml` by XcodeGen.

```bash
# 1. Generate the Xcode project
xcodegen generate

# 2a. Open in Xcode and run on a simulator or device
open IdleSkiller.xcodeproj

# 2b. …or build & launch from the command line
xcodebuild -project IdleSkiller.xcodeproj -scheme IdleSkiller \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Project layout

```
Sources/
  App/      IdleSkillerApp.swift        # @main, scene-phase persistence
  Models/   SkillID.swift               # the 23 skills, 4 categories + theming
            TrainingMethod.swift        # per-skill 6-tier thematic training methods
            XPTable.swift               # OSRS XP curve
            Balance.swift               # ALL tunable constants (tiers, slots, supercharge…)
            GameState.swift             # source of truth: XP, slots, energy, supercharge, coupons
            Store.swift                 # StoreKit 2 in-app purchases (coupon packs)
  Views/    RootView / Onboarding / Home / SkillTile
            SkillTrainingView / StatsView / SettingsView / Components
            DoubleXPView                # activate boost + coupon store
  Assets.xcassets                       # app icon + accent color
Config/     Products.storekit           # local StoreKit config for testing IAP
project.yml                             # XcodeGen project definition (universal: iPhone + iPad)
```

## Universal (iPhone + iPad)

Idle Skiller is a universal app (`TARGETED_DEVICE_FAMILY = "1,2"`). iPhone runs portrait; iPad
supports all four orientations and multitasking. Layouts are responsive (adaptive grids,
size-class-aware panes, width-capped/centered content), so verify UI changes on **both** an
iPhone and an iPad simulator. See `.github/copilot-instructions.md` for the full guidance.

## Testing in-app purchases

`Config/Products.storekit` defines the consumable coupon packs and is wired into the
`IdleSkiller` scheme's Run action, so purchases work locally in the simulator when you
run from **Xcode** (no App Store Connect needed). In production these map to real
App Store Connect product IDs (`com.callmegreg.idleskiller.coupons.*`).

## Tuning

All balance lives in `Sources/Models/Balance.swift` — passive rate, Energy cap, slot
thresholds, and Supercharge tiers. Re-balancing the game is a one-file change.

---

*Inspired by Old School RuneScape. Not affiliated with or endorsed by Jagex. Emoji glyphs are
placeholder art for v1.*
