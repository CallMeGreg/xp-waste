# Copilot instructions — XP Waste

XP Waste is a native **SwiftUI** idle/clicker game for iOS, inspired by the skilling
system of Old School RuneScape (OSRS). The player trains all 23 OSRS skills to level 99 by
tapping thematic training objects, banking Energy for Supercharge bursts, and using Double XP
coupons.

## Documentation layout (strict)

**The root `README.md` is strictly player-facing** — it describes what the game is and how to
play, nothing else. **Never add build, setup, architecture, tooling, or design content to the
root README.**

- All design, development, setup, and app-logistics documentation lives under **`docs/`** (or its
  own dedicated folder), each topic in its own file — never inlined into the root README.
  - `docs/GAME_DESIGN.md` — full game design document.
  - `docs/DEVELOPMENT.md` — engineering setup: requirements, build & run, project layout,
    architecture, tuning, StoreKit/IAP testing, debug hooks.
  - `docs/README.md` — index of the docs folder.
- When you write new design/dev/setup/logistics docs, add a file under `docs/` and link it from
  `docs/README.md`. Do **not** grow the root README.
- This `.github/copilot-instructions.md` file is agent guidance; human-facing engineering docs
  belong in `docs/DEVELOPMENT.md`. Keep the two in sync when workflows change.

## Universal app: iPhone AND iPad are both first-class

**This app must look and work great on both iPhone and iPad. Treat universal support as a hard
requirement, not an afterthought.**

- The target ships as a universal app: `TARGETED_DEVICE_FAMILY = "1,2"` in `project.yml`.
  Never drop iPad (family `2`).
- iPhone runs portrait; iPad supports **all four orientations**. The iPad orientations are set
  via `UISupportedInterfaceOrientations~ipad` in the partial `Config/Info.plist` (merged with the
  generated Info.plist) — Xcode's auto-generation ignores the `~ipad` suffix on
  `INFOPLIST_KEY_*` build settings, so that key must live in a real plist. Layouts must survive
  rotation and iPad multitasking (Split View / Slide Over), i.e. arbitrary widths and heights.
- **Never hard-code screen sizes.** Build responsive layouts with `GridItem(.adaptive(...))`,
  `@Environment(\.horizontalSizeClass)` / `verticalSizeClass`, `GeometryReader` only when
  necessary, `Spacer`, and relative sizing.
- Cap and center wide content so it doesn't stretch edge-to-edge on iPad
  (e.g. `.frame(maxWidth: 820).frame(maxWidth: .infinity)`). Existing screens follow this;
  keep new screens consistent.
- Provide size-class-adaptive layouts where it helps: compact width = single vertical column;
  regular width (iPad / landscape) = multi-pane. `SkillTrainingView` is the reference example
  (two-pane on regular, stacked on compact).
- When you add or change UI, **verify on both an iPhone simulator and an iPad simulator**
  before considering the work done.

## Architecture

- **`GameState`** (`Sources/Models/GameState.swift`) is the single source of truth
  (`@MainActor`, `ObservableObject`), injected via `.environmentObject`. All gameplay mutation
  and persistence lives here. Views are declarative and read derived values.
- **`Balance.swift`** centralizes *every* tunable number (XP tiers, passive rates, Supercharge
  multipliers, slot thresholds, Double XP timing). **Re-balancing must never require touching
  gameplay or view code — change the constants here.**
- **`XPTable.swift`** encodes the exact OSRS XP curve (level 1 = 0 XP, level 99 = 13,034,431).
  Do not alter the formula.
- **`SkillID.swift`** enumerates the 23 skills across 4 categories (Combat, Production, Utility,
  Gathering) with identity theming (vector emblem, tint). **`TrainingMethod.swift`** holds each
  skill's six thematic, tiered training methods (basic → end-game, OSRS-faithful).
- **`Artwork.swift`** is the rendering system for all skill/method art: a `SkillArt` value
  (`.symbol` SF Symbol or `.vector` hand-authored `Path`) drawn by `ArtworkView`. There is **no
  emoji art** — emblems and methods reference SF Symbols or the custom `VectorIcon` set. Add new
  art here, not inline in views.
- **`Store.swift`** wraps StoreKit 2 for consumable Double XP coupon packs.

## Training methods (core theming rule)

Each skill has **6 tiers** sharing the unlock ladder in `Balance.trainingTiers`
(levels 1/15/30/50/70/90 → 1/3/6/12/25/50 XP per tap). The active method is chosen by the
skill's level. As you level, the on-screen object **visibly upgrades** (e.g. Woodcutting:
normal → oak → willow → maple → yew → magic tree). When adding/adjusting methods, keep them
**thematically true to how that skill is trained in OSRS**, ordered basic → advanced. Each skill
keeps **one cohesive motif** across all six tiers (e.g. Strength = dumbbells, Fishing = fish,
Prayer = bones) and shows **clear progression** through the material/species in the method name
plus a per-tier tint and size ramp (`TrainingMethod.tiered` sets `scale`). Assign art via
`SkillArt` (SF Symbol or `VectorIcon`) in `Artwork.swift` — never emoji.

## Build & run

Generate the project after editing `project.yml`, then build for the simulator:

```sh
export PATH="/opt/homebrew/bin:$PATH"
xcodegen generate
xcodebuild -project XPWaste.xcodeproj -scheme XPWaste \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

Also build/verify against an iPad destination (e.g. an iPad Pro simulator) for universal support.

Full human-facing setup lives in [`docs/DEVELOPMENT.md`](../docs/DEVELOPMENT.md).

- The Xcode project is **generated** by XcodeGen from `project.yml` — edit `project.yml`, not the
  `.xcodeproj`. `build/` is git-ignored.
- Requires iOS 17+. Uses `.sensoryFeedback`, `NavigationStack`, StoreKit 2, Observation-friendly
  SwiftUI.

## StoreKit testing

- Coupon products are defined in `Config/Products.storekit`, wired to the scheme's
  `storeKitConfiguration`. Running from Xcode uses this local catalog.
- `simctl launch` from the CLI does **not** apply the scheme's StoreKit config, so
  `Product.products` is empty there. `Store.swift` has a `#if DEBUG` mock catalog fallback so the
  store still renders for screenshots/UI verification. Keep that fallback.

## Debug hooks (guarded by `#if DEBUG`, never in release)

Used for deterministic screenshots / UI checks — preserve them when refactoring:

- `SEED_DEMO=ready|super` — seeds representative levels, slots, energy, coupons (and, for
  `super`, an active Supercharge + Double XP boost).
- `OPEN_SKILL=<rawValue>` — deep-links Home straight into a skill's training screen.
- `OPEN_SHEET=doublexp` — auto-presents the Double XP sheet.
- `OFFLINE_DEMO=1` — seeds a representative "welcome back" offline-earnings summary sheet.

Pass them to the simulator via the `SIMCTL_CHILD_` prefix, e.g.
`SIMCTL_CHILD_SEED_DEMO=super SIMCTL_CHILD_OPEN_SKILL=attack xcrun simctl launch ...`.

## Conventions

- Keep balance/data centralized; avoid magic numbers in views.
- Comment only where intent isn't obvious.
- Save schema (`SaveData` in `GameState`) uses optional fields for additive changes so older
  saves keep decoding — preserve backward compatibility when adding persisted state.
- Commit messages include:
  `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`.
