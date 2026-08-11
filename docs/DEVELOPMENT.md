# Development

Engineering setup, build, and project logistics for **XP Waste**. Player-facing docs live
in the [root README](../README.md); the full design write-up is in
[GAME_DESIGN.md](GAME_DESIGN.md); agent guidance is in
[`.github/copilot-instructions.md`](../.github/copilot-instructions.md).

## Requirements

- Xcode 16+ (developed with Xcode 26.6 / iOS 26.5 SDK)
- iOS 17.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to (re)generate the project:
  `brew install xcodegen`

## Build & run

The Xcode project is **generated** from `project.yml` by XcodeGen — edit `project.yml`, not the
`.xcodeproj`. `build/` is git-ignored.

```bash
# 1. Generate the Xcode project (re-run after editing project.yml)
export PATH="/opt/homebrew/bin:$PATH"
xcodegen generate

# 2a. Open in Xcode and run on a simulator or device
open XPWaste.xcodeproj

# 2b. …or build from the command line
xcodebuild -project XPWaste.xcodeproj -scheme XPWaste \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

XP Waste is a **universal app** (`TARGETED_DEVICE_FAMILY = "1,2"`). iPhone runs portrait;
iPad supports all four orientations and multitasking. Layouts are responsive (adaptive grids,
size-class-aware panes, width-capped/centered content), so **verify UI changes on both an
iPhone and an iPad simulator** (e.g. build/run against an iPad Pro destination too).

## Project layout

```
Sources/
  App/      XPWasteApp.swift        # @main, scene-phase persistence
  Models/   SkillID.swift               # the 23 skills, 4 categories + theming
            TrainingMethod.swift        # per-skill 6-tier thematic training methods
            XPTable.swift               # OSRS XP curve
            Balance.swift               # ALL tunable constants (tiers, slots, supercharge, perks…)
            GameState.swift             # source of truth: XP, slots, energy, supercharge, coupons, energy cells
            SkillBuff.swift             # per-skill unique account-wide perks (BuffKind + theming)
            Store.swift                 # StoreKit 2 in-app purchases (coupon + Energy Cell packs)
            SoundManager.swift          # SFX engine: pooled AVAudioPlayers, one cue per game moment
  Views/    RootView / Onboarding / Home / SkillTile
            SkillTrainingView / StatsView / SettingsView / Components
            BoostsView                  # activate Daily Boost, use/buy Energy Cells, both stores
  Resources/Sounds/                     # bundled OSRS-inspired SFX (sfx_*.wav) — see SOUND_DESIGN.md
  Assets.xcassets                       # app icon + accent color
Config/     Products.storekit           # local StoreKit config for testing IAP (2 families)
Tools/      sound_synth.py              # deterministic generator for the SFX (regenerate/re-pick)
project.yml                             # XcodeGen project definition (universal: iPhone + iPad)
docs/       GAME_DESIGN.md, DEVELOPMENT.md, SKILL_BUFFS.md, SOUND_DESIGN.md
```

## Architecture at a glance

- **`GameState`** (`@MainActor`, `ObservableObject`) is the single source of truth for XP,
  slots, Energy, Supercharge timers, coupons, and Energy Cells; views read derived values via
  `.environmentObject`.
- **`Balance.swift`** centralizes *every* tunable number — re-balancing never requires touching
  gameplay or view code.
- **`XPTable.swift`** encodes the exact OSRS XP curve (L1 = 0 XP, L99 = 13,034,431).
- **`SkillID.swift`** + **`TrainingMethod.swift`** define the 23 skills, their four categories,
  and each skill's six thematic training-method tiers.
- **`SkillBuff.swift`** maps each of the 23 skills to a **unique account-wide perk**; the scaling
  envelopes live in `Balance.buffScaling` and the effects are applied in `GameState` (see
  [SKILL_BUFFS.md](SKILL_BUFFS.md)).

## Tuning

All balance lives in `Sources/Models/Balance.swift` — training-method tiers, passive rate,
offline XP rate/cap, Energy cap, slot thresholds, Supercharge multipliers, Daily Boost timing, and
the **per-skill perk scaling** (`buffScaling` — every perk's neutral level-1 and fully-trained
level-99 value). Re-balancing the game is a one-file change.

## Testing in-app purchases

`Config/Products.storekit` defines two families of consumables — **Daily Boost coupon** packs
(`…coupons.small/medium/large`) and **Energy Cell** packs (`…energy.small/medium/large`) — and is
wired into the `XPWaste` scheme's Run action, so purchases work locally in the simulator when you
run from **Xcode** (no App Store Connect needed). In production these map to real App Store Connect
product IDs (`com.callmegreg.xpwaste.coupons.*` and `com.callmegreg.xpwaste.energy.*`). The
`Store.grants` table maps each product ID to its family (`ProductKind`) and amount — keep it in
sync with `Products.storekit`, and route grants in `XPWasteApp` (`onGrant`) to `addCoupons` /
`addEnergyCells`.

> `simctl launch` from the CLI does **not** apply the scheme's StoreKit config, so
> `Product.products` is empty there. `Store.swift` has a `#if DEBUG` mock catalog fallback (both
> families) so the store still renders for screenshots / UI verification.

## Debug hooks (guarded by `#if DEBUG`, never in release)

Used for deterministic screenshots / UI checks:

- `SEED_DEMO=ready|super` — seeds representative levels, slots, energy, coupons, and Energy Cells
  (and, for `super`, an active Supercharge + Daily Boost).
- `OPEN_SKILL=<rawValue>` — deep-links Home straight into a skill's training screen.
- `OPEN_SHEET=doublexp` — auto-presents the Boosts sheet (Daily Boost + Energy Cells).
- `OPEN_SHEET=stats` — auto-presents the Stats sheet (per-skill levels and emblems).
- `OFFLINE_DEMO=1` — seeds a representative **"welcome back"** offline-earnings summary (per-skill
  XP + level-ups) so the sheet can be screenshotted deterministically.

Pass them to the simulator via the `SIMCTL_CHILD_` prefix, e.g.
`SIMCTL_CHILD_SEED_DEMO=super SIMCTL_CHILD_OPEN_SKILL=attack xcrun simctl launch ...`.

## Notes

- Skill and training-method art is drawn by `Artwork.swift` (`ArtworkView` renders a `SkillArt`
  that is either an SF Symbol or a hand-authored `VectorIcon` path). Each skill uses one motif
  across its six tiers, progressing by tint + a per-tier size ramp. No emoji art.
- The save schema (`SaveData` in `GameState`) uses optional fields for additive changes so older
  saves keep decoding — preserve backward compatibility when adding persisted state.
- Commit messages include:
  `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`.
