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
            GameState+Rewards.swift     # Diary reward engine: Task evaluation, Token payouts, queries
            SkillBuff.swift             # per-skill unique account-wide perks (BuffKind + theming)
            Task.swift                  # Diary rewards: Task/Diary/Tier model + full Task catalog
            Store.swift                 # StoreKit 2 in-app purchases (Token packs; tokens buy consumables)
            SoundManager.swift          # SFX engine: pooled AVAudioPlayers, one cue per game moment
  Views/    RootView / Onboarding / Home / SkillTile
            SkillTrainingView / SettingsView / Components
            BoostsView                  # the Shop tab: spend Tokens on Coupons/Cells, buy Token packs
            DiaryView                   # the Diary tab: Overview + All Tasks (themed Diaries, tiers, Reward Tokens)
  Resources/Sounds/                     # bundled OSRS-inspired SFX (sfx_*.wav) — see SOUND_DESIGN.md
  Assets.xcassets                       # app icon + accent color
Config/     Products.storekit           # local StoreKit config for testing IAP (Token packs)
Tools/      sound_synth.py              # deterministic generator for the SFX (regenerate/re-pick)
project.yml                             # XcodeGen project definition (universal: iPhone + iPad)
docs/       GAME_DESIGN.md, DEVELOPMENT.md, SKILL_BUFFS.md, SOUND_DESIGN.md, ACHIEVEMENTS.md
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
- **`Task.swift`** + **`GameState+Rewards.swift`** implement the **Diary** reward system: a catalog of
  Tasks grouped into themed Diaries and difficulty tiers, evaluated live from gameplay counters,
  paying out **Tokens**. Tokens are the game's single currency — earned from Tasks, bought via IAP,
  and **spent in the Shop** (`BoostsView`) on Boost Coupons and Energy Cells. Clearing a whole Diary
  tier instead banks a tier-matched **any-skill XP Lamp** (Bronze→Rune) in `DiaryView`. All economy
  numbers (Task grants, tier-clear lamp coefficients, Shop prices, IAP grants) live in `Balance.Rewards`
  / `Balance.lampTierCoefficients`; the earning UI
  is `DiaryView` (see [ACHIEVEMENTS.md](ACHIEVEMENTS.md)).
- **Navigation** — `RootView` shows `OnboardingView` until `hasSeenOnboarding`, then a **custom
  bottom tab bar** (`AppTabBar`) with five tabs: **Skills** (`HomeView`) · **Raids** (`RaidsView`)
  · **Shop** (`BoostsView`) · **Diary** (`DiaryView`) · **Settings** (`SettingsView`). The
  native `TabView` bar floats at the top on iPadOS, so the app uses a hand-rolled bar pinned via
  `.safeAreaInset(edge: .bottom)` — identical placement on iPhone and iPad. Each tab keeps its own
  `NavigationStack`; the level-up / notice / Task toasts and the offline-progress sheet live at the
  root `ZStack` so they overlay every tab. There is **no standalone Stats screen** — its content is
  split across tabs: overview stats → **Settings**, the achievements checklist folded into **Tasks**
  in the **Diary** tab, per-skill buff descriptors → **Skills**. The Skills tab **pins** the
  Total-Level header (and, when active, an **XP Boost** banner) above its scroll view so both stay
  visible while scrolling.

## Tuning

All balance lives in `Sources/Models/Balance.swift` — training-method tiers, passive rate,
offline XP rate/cap, Energy cap, slot thresholds, Supercharge multipliers, Daily Boost timing, and
the **per-skill perk scaling** (`buffScaling` — every perk's neutral level-1 and fully-trained
level-99 value). Re-balancing the game is a one-file change.

## Testing in-app purchases

The economy is built on a **single currency, Tokens**. IAP sells only **Token packs**; Tokens are
then spent in the Shop (`BoostsView`) on Boost Coupons and Energy Cells. `Config/Products.storekit`
defines the three consumable Token packs (`com.callmegreg.xpwaste.tokens.small/medium/large` →
500 / 3,000 / 7,500 Tokens) and is wired into the `XPWaste` scheme's Run action, so purchases work
locally in the simulator when you run from **Xcode** (no App Store Connect needed). In production
these map to the same real App Store Connect product IDs. `Store.grants` maps each product ID to its
Token amount — keep it in sync with `Products.storekit`, and route grants in `XPWasteApp` (`onGrant`)
to `creditPurchasedTokens`. Spending is handled entirely in-game by `GameState.buyBoostCoupon` /
`buyEnergyCell` (priced from `Balance.Rewards`), which debit Tokens and top up the existing
`doubleXPCoupons` / `energyCells` inventory.

> `simctl launch` from the CLI does **not** apply the scheme's StoreKit config, so
> `Product.products` is empty there. `Store.swift` has a `#if DEBUG` mock catalog fallback (the three
> Token packs) so the Shop still renders for screenshots / UI verification.

## Debug hooks (guarded by `#if DEBUG`, never in release)

Used for deterministic screenshots / UI checks:

- `SEED_DEMO=ready|super` — seeds representative levels, slots, energy, coupons, and Energy Cells
  (and, for `super`, an active Supercharge + Daily Boost). Also seeds a modest Diary
  (counters + Reward Tokens) so the Diary isn't empty in demo screenshots.
- `SEED_CELLS=<n>` — overrides the owned Energy-Cell count of the `SEED_DEMO` seed (e.g. `SEED_CELLS=0`
  surfaces the training screen's out-of-cells **Buy** action, which routes to the Shop).
- `SEED_RAIDED=1` — marks every group's daily raid as already attempted today (and tops up Tokens), so
  the Raids tab shows the **"Raided today — buy a refresh"** affordance and the Shop's **Raid Refresh**
  reads as enabled.
- `SEED_REWARDS=1` — seeds a **rich Diary**: enough levels to unlock all 5 AFK slots,
  representative lifetime counters, every currently-satisfied Task marked complete, cleared
  Diary tiers, and a healthy Reward Token balance. Ideal for reward-system screenshots.
- `OPEN_TAB=<skills|raids|shop|diary|settings>` — launches directly on that bottom tab.
- `OPEN_SKILL=<rawValue>` — selects the **Skills** tab and deep-links straight into a skill's
  training screen.
- `OPEN_RAID=<combat|production|utility|gathering>` — selects the **Raids** tab and opens that
  group's multi-room raid session.
- `FORCE_RAID_TIER=<0-5>` — overrides the opened raid's tier (Bronze…Rune), so higher-tier
  4-room layouts, tighter windows, and multi-phase final bosses can be screenshotted at any level.
- `RAID_ROOM=<n>` — start the raid session on room *n* (0-based). Shows that room's **intro card**
  (with its boss art / mechanic) by default.
- `RAID_PLAY=1` — with `RAID_ROOM`, skip the intro card and drop straight into the room's live
  mechanic (for capturing a mechanic mid-play).
- `RAID_RESULT=<win|lose>` — show the raid **result overlay** without playing (visual-only; does
  not spend the daily attempt). Pair with `RAID_FLAWLESS=1` to render the flawless-bonus win with
  its lamp **and** tier-scaled Token bonus.
- `OPEN_SHEET=doublexp` — selects the **Shop** tab (Spend Tokens on Coupons/Cells, Token packs).
- `SHOP_SCROLL=tokens` — after landing on the Shop, auto-scrolls to the bottom (Energy Cells + IAP
  **Token Packs**) so the below-the-fold section can be screenshotted from the CLI (which can't
  inject scroll gestures). Pairs with `OPEN_SHEET=doublexp`.
- `OPEN_SHEET=diary` — selects the **Diary** tab (Overview, All Tasks & Reward Tokens).
- `DIARY_TAB=tasks` — opens the Diary on the **All Tasks** tab (themed Diary list) instead of Overview.
- `OPEN_DIARY=<rawValue>` — selects the Diary tab and pushes straight into one Diary's detail
  (e.g. `combat`, `gathering`, `tycoon`, `completionist`). Implies the Diary tab.
- `TASK_TOAST=1` — surfaces a sample Task-completion toast on launch (pairs with `SEED_REWARDS`).
- `OFFLINE_DEMO=1` — seeds a representative **"welcome back"** offline-earnings summary (per-skill
  XP + level-ups) so the sheet can be screenshotted deterministically.

Pass them to the simulator via the `SIMCTL_CHILD_` prefix, e.g.
`SIMCTL_CHILD_SEED_DEMO=super SIMCTL_CHILD_OPEN_SKILL=attack xcrun simctl launch ...` or
`SIMCTL_CHILD_SEED_REWARDS=1 SIMCTL_CHILD_OPEN_DIARY=combat xcrun simctl launch ...`.

## Notes

- Skill and training-method art is drawn by `Artwork.swift` (`ArtworkView` renders a `SkillArt`
  that is either an SF Symbol or a hand-authored `VectorIcon` path). Each skill uses one motif
  across its six tiers, progressing by tint + a per-tier size ramp. No emoji art.
- The save schema (`SaveData` in `GameState`) uses optional fields for additive changes so older
  saves keep decoding — preserve backward compatibility when adding persisted state.
- Commit messages include:
  `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`.
