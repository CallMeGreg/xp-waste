# Idle Skiller ⚔️🌳⛏️

An **OSRS-inspired idle / clicker skilling game** for iOS, built in SwiftUI. Train ten skills
from level 1 to 99 using the exact Old School RuneScape experience curve — by tapping,
setting up passive training, and banking **Energy** while you're away for bonus-XP
**Supercharge** bursts.

See **[GAME_DESIGN.md](GAME_DESIGN.md)** for the full design, balance table, and critique.

## Features (v1)

- **10 skills** — Attack, Strength, Defence, Ranged, Magic, Hitpoints, Prayer, Woodcutting,
  Fishing, Mining — each on the real OSRS XP curve (L99 = 13,034,431 XP).
- **Tap to train** a full-screen thematic object (+1 XP) with floating feedback and haptics.
- **Training slots** for passive XP (1 → 2 → 3 slots as your total level grows).
- **Energy & Supercharge** — bank up to 30s of Supercharge while the app is open *or closed*,
  then spend it for **2 / 5 / 10 / 20 XP-per-tap** bursts (tier scales with total level).
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
  Models/   SkillID.swift               # the 10 skills + theming
            XPTable.swift               # OSRS XP curve
            Balance.swift               # ALL tunable constants
            GameState.swift             # source of truth: XP, slots, energy, supercharge
  Views/    RootView / Onboarding / Home / SkillTile
            SkillTrainingView / StatsView / SettingsView / Components
  Assets.xcassets                       # app icon + accent color
project.yml                             # XcodeGen project definition
```

## Tuning

All balance lives in `Sources/Models/Balance.swift` — passive rate, Energy cap, slot
thresholds, and Supercharge tiers. Re-balancing the game is a one-file change.

---

*Inspired by Old School RuneScape. Not affiliated with or endorsed by Jagex. Emoji glyphs are
placeholder art for v1.*
