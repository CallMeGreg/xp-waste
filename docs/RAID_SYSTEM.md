# XP Waste — Raid System (design)

A new **Raids** feature: one thematic raid per skill **category**, gated to **once per group per
day**, whose **difficulty and reward tier scale with that group's combined skill level**. A raid
grants **no XP while you play** — clearing it awards a **Skill Lamp** bound to that group, worth
about **1.5× the XP you'd have earned tapping that skill for the raid's duration**.

> **Status:** design only. Nothing here is implemented yet. This document is the spec; the
> implementation PR that follows must obey the repo's universal-app and screenshot rules
> (both iPhone **and** iPad captures of every new screen) and keep every tunable number in
> `Balance.swift`.

---

## 1. Goals & pillars

- **A daily, high-stakes, active challenge** that complements — never replaces — the tap/idle
  loop. One shot per group per day; clear it or come back tomorrow.
- **Four distinct, skill-faithful gameplay loops**, one per category, each expressing how that
  group of skills is trained in OSRS.
- **Rewards that scale with mastery.** Difficulty tracks the group's combined level; the payoff
  (an XP lamp) scales with the skill you spend it on, so it stays relevant from level 1 to 99.
- **Zero magic numbers in gameplay/view code.** Every raid constant — duration, difficulty ramp,
  pass thresholds, reward multiplier — lives in `Balance.swift`, matching the existing pattern.

### Confirmed design decisions

| Question | Decision |
|----------|----------|
| Deliverable | **This document only** (design). Implementation is a follow-up. |
| Structure | **One raid per `SkillCategory`** (Combat, Production, Utility, Gathering). |
| Difficulty & reward scaling | **Auto-scales with the group's combined level** (no manual tier picking). |
| Placement | **New "Raids" tab** in a root `TabView` (Skills \| Raids). |
| XP during play | **None.** The raid is a minigame; the reward is the lamp. |
| Frequency | **1 raid per group per day** (up to 4/day across the four groups). |
| Reward variance | **Pass/fail.** Clear the success threshold → full lamp; fall short → nothing. |
| Failure cost | **One shot** — a failed attempt consumes that group's daily raid. |
| Lamp value basis | **Benchmarked against tapping the specific skill the lamp is applied to**, at that skill's current method tier (bigger lamp on a higher-level skill). |

---

## 2. Where it lives (navigation)

Today `RootView` shows `OnboardingView` until `hasSeenOnboarding`, then `HomeView` inside a
`NavigationStack`, with global level-up / notice toasts and the offline-progress sheet layered on
top.

**Change:** once onboarding is complete, wrap the game in a **`TabView`** with two tabs:

| Tab | View | Icon (SF Symbol) |
|-----|------|------------------|
| **Skills** | today's `HomeView` (unchanged hub) | `square.grid.2x2.fill` |
| **Raids** | new `RaidsView` | `flag.checkered` / `shield.lefthalf.filled` |

The level-up toast, notice toast, and `offlineProgress` sheet stay at the **root ZStack** so they
overlay both tabs. Onboarding optionally gains a 5th card introducing raids (kept short — see the
onboarding-overload note in the game design doc).

> Universal-app rules still apply everywhere: no hard-coded sizes, width-capped & centered content
> (`.frame(maxWidth: …)`), adaptive layouts via `horizontalSizeClass`, iPad in all orientations.

---

## 3. Raid groups & tiers

There is exactly one raid per category, themed to its skills:

| Group (`SkillCategory`) | Raid | Skills | Combined-level max |
|-------------------------|------|--------|--------------------|
| **Combat** | **The Colosseum** | Attack, Strength, Defence, Hitpoints, Ranged, Magic | 6 × 99 = **594** |
| **Production** | **The Grand Forge** | Smithing, Crafting, Fletching, Runecraft, Cooking, Construction, Firemaking | 7 × 99 = **693** |
| **Utility** | **The Heist** | Agility, Hunter, Slayer, Thieving, Prayer | 5 × 99 = **495** |
| **Gathering** | **The Expedition** | Woodcutting, Farming, Fishing, Mining, Herblore | 5 × 99 = **495** |

### 3.1 Tier = the group's *average* method tier

Groups have different skill counts (5, 6, 7), so raw combined level isn't comparable across them.
We normalize by **average level** and reuse the **existing** method-tier ladder:

```
avgLevel(group)  = combinedLevel(group) / skillCount(group)          // 1…99
raidTier(group)  = Balance.trainingTierIndex(forSkillLevel: avgLevel) // 0…5
```

So a raid is **Rune tier** exactly when the group's skills *average* level 90+, the same ladder
(`1 / 15 / 30 / 50 / 70 / 90`) that governs training methods. No new threshold table needed — the
raid tier reads as "your Combat skills average a Mithril-tier fighter."

| Raid tier | Reuses method unlock level | Theme name (flavor) |
|-----------|----------------------------|---------------------|
| 0 | avg ≥ 1  | Bronze |
| 1 | avg ≥ 15 | Iron |
| 2 | avg ≥ 30 | Steel |
| 3 | avg ≥ 50 | Mithril |
| 4 | avg ≥ 70 | Adamant |
| 5 | avg ≥ 90 | Rune |

Higher tiers make the raid **harder** (§4) and — because you'll spend the lamp on higher-level
skills — **more rewarding** (§6).

---

## 4. The four gameplay loops

Every loop shares a frame: a **countdown** (`Balance.raidDurationSeconds`, a few minutes), an
on-screen **progress/score** read-out, and a **pass threshold** you must reach before time runs
out. **No XP is granted during play.** Each loop is a different verb; difficulty parameters are
selected by `raidTier(group)` from a centralized per-tier table (§7). All are fully responsive
(single column on compact width; roomier framing on iPad/regular width).

### 4.1 Combat — **The Colosseum** (precision boss fight)
*Attack · Strength · Defence · Hitpoints · Ranged · Magic*

- A **boss with a health bar**. Glowing **weakpoints** flash on/around it; **tap them quickly and
  accurately** before they fade to deal damage (the "precise, quick clicks" loop).
- The boss periodically **telegraphs an attack** (wind-up indicator); tap the **Block/Dodge**
  prompt inside a short window or take damage to your **raid HP**.
- **Pass:** deplete the boss's HP before the timer **and** survive (raid HP > 0).
- **Tier ramp:** boss HP ↑, weakpoint visible-time ↓, attack cadence ↑, dodge window ↓.

### 4.2 Production — **The Grand Forge** (assembly rhythm)
*Smithing · Crafting · Fletching · Runecraft · Cooking · Construction · Firemaking*

- An assembly line. Each **product** is a short **recipe** of station steps (e.g. Smelt → Hammer →
  Quench). A sweeping **"strike" meter** passes over a highlighted **sweet-spot**; tap in the
  sweet-spot to complete each step and finish the product.
- **Pass:** complete a **quota** of products before the timer. Mis-timed strikes waste time.
- **Tier ramp:** quota ↑, sweet-spot width ↓, meter speed ↑, longer recipes (more steps).

### 4.3 Utility — **The Heist** (stealth-agility gauntlet)
*Agility · Hunter · Slayer · Thieving · Prayer*

- Sneak through a series of **rooms** with mixed, timed prompts: **vault** obstacles exactly on
  cue (Agility), **pickpocket / loot** only while the guard is turned away (Thieving — tapping while
  watched = caught), **spring a trap** at the right moment (Hunter), **hold steady** to avoid
  detection (Prayer). A **restraint** element: do **not** tap decoys/traps.
- **Pass:** reach the vault (clear all rooms) before the timer with **fewer than N** times caught.
- **Tier ramp:** more rooms, shorter safe windows, faster guard cycles, more decoys, fewer allowed
  slip-ups.

### 4.4 Gathering — **The Expedition** (correct-resource collection)
*Woodcutting · Farming · Fishing · Mining · Herblore*

- A resource field of **nodes**. A **target resource** is indicated ("catch the trout", "mine the
  coal", "chop the willow"); **tap the correct nodes** among decoys. Fish **surface briefly**
  (timing), rocks/trees need a couple taps to **deplete** (rhythm), herbs **wilt** if you're slow;
  wrong species **waste time / cost a strike**.
- **Pass:** gather a **quota** of correct resources before the timer.
- **Tier ramp:** quota ↑, more decoys, faster surfacing/wilting, shorter windows, target switches
  more often.

| Group | Raid | Core verb | Pass condition | Primary fail |
|-------|------|-----------|----------------|--------------|
| Combat | The Colosseum | Precise/fast target taps + dodge | Boss HP → 0 & survive | Timer out / raid HP → 0 |
| Production | The Grand Forge | Rhythm/timing strikes | Product quota met | Quota missed by timer |
| Utility | The Heist | Reaction + restraint | Vault reached, few catches | Caught too often / timer out |
| Gathering | The Expedition | Recognition + speed | Resource quota met | Quota missed by timer |

---

## 5. Daily limit & one-shot pass/fail

- **One raid per group per day.** Availability is tracked per category by calendar day, mirroring
  the existing free-coupon `dayKey()` pattern.
- **Starting a raid consumes that group's daily attempt** — a completed run (pass **or** fail)
  marks the group done for the day. (Guard against mid-raid app kill: mark the attempt spent when
  the raid **begins**, so quitting can't farm retries. See open question Q1.)
- **Pass → full lamp** (§6). **Fail → nothing**; the group shows "Come back tomorrow."
- Difficulty is auto-tuned to the group's tier, so the challenge is always a stretch at your
  current mastery. Pass thresholds (§7) are calibrated so an attentive player *at that combined
  level* can clear it — but with real risk, since a miss costs the day.

---

## 6. Reward — Skill Lamps

Clearing a raid awards **one Skill Lamp bound to that group** (a "Combat Lamp", "Gathering Lamp",
…). Lamps are **stored in an inventory** (persisted) and applied whenever the player chooses.

### 6.1 Application rules
- A lamp can be applied to **exactly one skill within its group** (Combat lamp → any one of Attack/
  Strength/Defence/Hitpoints/Ranged/Magic).
- **One-time use**, then it's consumed. Grants a **flat block of XP** via the existing `addXP`
  pipeline, so it respects the 200M ceiling and fires the normal level-up toast.
- **Not** multiplied by Supercharge or Daily Boost — a lamp is its own reward and stands outside
  the tap-boost economy (prevents runaway stacking).
- Players may **bank** lamps and spend them on whichever group skill they like (typically their
  highest-tier one) — OSRS-authentic, and it's what makes "amount depends on the skill it's used
  on" true.

### 6.2 Value formula
The lamp is worth ~**1.5×** the XP you'd earn **tapping the target skill** for the raid's duration:

```
tapYieldPerMinute(S) = Balance.raidRapidTapsPerMinute × baseXPPerAction(S)   // S at its current tier
lampXP(S, tier)      = round( Balance.raidRewardMultiplier              // 1.5
                              × raidMinutes                             // raidDurationSeconds / 60
                              × tapYieldPerMinute(S)
                              × Balance.raidTierRewardBonus[tier] )     // default 1.0 (neutral)
```

- `baseXPPerAction(S)` already scales with **S's method tier** (`1/3/6/12/25/50`), i.e. with S's
  level — so **"amount depends on the level of the skill it's used on."** ✓
- The **raid tier** matters two ways: (a) you can only earn a higher-tier lamp once the group's
  skills are high enough to spend it on (correlated payoff), and (b) the explicit, **default-neutral**
  `raidTierRewardBonus[tier]` lever lets designers make higher tiers extra-rewarding **without
  touching code.** ✓
- Because the value is computed **at application time** from the target skill's current tier, a
  lamp banked early and spent late is worth more — exactly like an OSRS XP lamp.

### 6.3 Example payouts
With defaults `raidRewardMultiplier = 1.5`, `raidDurationSeconds = 180` (3 min),
`raidRapidTapsPerMinute = 300`, `raidTierRewardBonus = 1.0` → `lampXP = 1350 × baseXPPerAction(S)`:

| Target skill's method tier | XP/tap | Lamp XP | For scale (OSRS curve) |
|----------------------------|--------|---------|------------------------|
| 1 (lv 1–14)  | 1  | **1,350**  | ~level 1 → 11 early on |
| 2 (lv 15–29) | 3  | **4,050**  | a few early levels |
| 3 (lv 30–49) | 6  | **8,100**  | ~a level in the 30s |
| 4 (lv 50–69) | 12 | **16,200** | a chunk of a 50s level |
| 5 (lv 70–89) | 25 | **33,750** | meaningful in the 70s |
| 6 (lv 90–99) | 50 | **67,500** | ~5% of a level near 99 |

All three inputs (`1.5`, the duration, the reference taps/minute) are one-line `Balance.swift`
edits, so re-tuning the 1.5× promise never touches gameplay or view code.

> **Calibration note:** `raidRapidTapsPerMinute` (default 300 ≈ 5 taps/s) anchors "clicking
> rapidly." It's a deliberate reference rate, not a measurement of any given player. Early-game
> lamps are intentionally punchy relative to the tiny early XP curve; late-game they're a steady
> daily nudge. Tune per playtest.

---

## 7. New balance constants (all in `Balance.swift`)

```swift
// MARK: Raids
static let raidDurationSeconds: Double = 180          // ~3 min per raid (a few minutes)
static let raidRapidTapsPerMinute: Double = 300       // reference "rapid tapping" rate for the 1.5× promise
static let raidRewardMultiplier: Double = 1.5         // lamp ≈ 1.5× tapping-for-duration
static let raidsPerGroupPerDay: Int = 1               // one shot per group per day

/// Explicit, default-neutral per-tier reward lever (index = raidTier 0…5).
static let raidTierRewardBonus: [Double] = [1, 1, 1, 1, 1, 1]

/// Per-tier difficulty knobs consumed by the four loops. Index = raidTier 0…5.
struct RaidTierParams {
    let goal: Int              // successful actions to clear (boss damage / products / rooms / resources)
    let allowedMistakes: Int   // failures tolerated before the raid is lost
    let targetLifetime: Double // seconds a target/prompt/safe-window stays actionable (tightens with tier)
    let spawnInterval: Double  // seconds between spawns / prompt cadence (shrinks with tier)
    let decoyCount: Int        // wrong targets / distinct resource types present (recognition pressure)
}
static let raidTierParams: [RaidTierParams] = [ /* 6 entries, ascending difficulty */ ]
static func raidParams(forTier tier: Int) -> RaidTierParams // clamped lookup
static func raidTierBonus(forTier tier: Int) -> Double       // clamped reward lever
```

A single shared `goal` (successes-before-timer) drives every loop, so the win condition and the
HUD are uniform; each loop maps `goal` to its own fantasy (boss weakpoints, forge strikes, looted
rooms, gathered resources). `targetLifetime` doubles as the Forge's timing tolerance and the Heist's
safe-window length. Each loop reads `raidParams(forTier: raidTier(group))`; re-balancing difficulty
is a one-file change.

---

## 8. Data model & persistence

`GameState` remains the single source of truth. Additions follow the **additive, optional-field**
save pattern so older saves keep decoding.

### 8.1 `SaveData` (append optional fields)
```swift
// Added in v1.5 — Raids. Optional for backward-compatible decoding.
var raidLamps: [RaidLampRecord]?         // owned, unspent lamps
var lastRaidDay: [String: String]?       // categoryRawValue → dayKey of last attempt
```

```swift
/// A banked, unspent XP lamp bound to a skill group. `tier` is the raid tier it was earned at
/// (drives `raidTierRewardBonus`); final XP is computed at application from the target skill.
struct RaidLampRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let group: SkillCategory
    let tier: Int
    let earned: Date
}
```

### 8.2 `GameState` API (new)
```swift
// Derived
func raidCombinedLevel(_ group: SkillCategory) -> Int          // Σ level(for:) over the group
func raidTier(_ group: SkillCategory) -> Int                   // via trainingTierIndex(avgLevel)
func raidParams(_ group: SkillCategory) -> Balance.RaidTierParams
func isRaidAvailableToday(_ group: SkillCategory) -> Bool      // dayKey vs lastRaidDay[group]
func lamps(for group: SkillCategory) -> [RaidLampRecord]
func projectedLampXP(_ lamp: RaidLampRecord, on skill: SkillID) -> Int   // §6.2, for UI preview

// Actions
func beginRaid(_ group: SkillCategory)                         // marks the daily attempt spent, save()
func finishRaid(_ group: SkillCategory, passed: Bool)          // passed → append RaidLampRecord; save()
@discardableResult
func applyLamp(_ lamp: RaidLampRecord, to skill: SkillID) -> Bool  // guard skill.category == lamp.group;
                                                                  // addXP(projected…); remove lamp; save()
```

`projectedLampXP` reuses `baseXPPerAction(skill)` and the §6.2 formula. `applyLamp` routes through
the existing `addXP`, so the 200M cap and level-up toast come for free.

---

## 9. Screens & UX

### 9.1 `RaidsView` (the Raids tab hub)
An adaptive list/grid of **four raid cards** (width-capped & centered, like the rest of the app):
- Group name + raid name, category **SF Symbol** and **tint** (from `SkillCategory` / skills).
- **Current tier** badge (Bronze…Rune) + combined level and a progress bar to the next tier.
- **Status:** "Available today" (primary CTA) or "Come back tomorrow" (with a countdown to reset).
- **Lamps owned** for this group, with an **Apply** affordance.

### 9.2 `RaidSessionView` (the minigame)
Full-screen, per-group loop (§4): countdown, live score/progress, pause/quit (quitting still spends
the daily attempt), and a **result screen** (Victory → lamp awarded, with a shine; Defeat → "no
lamp, try again tomorrow"). Responsive: single column on compact width, roomier framing on iPad;
survives rotation and Split View / Slide Over.

### 9.3 Lamp application sheet
From a raid card or the skill screen: pick **which group skill** to spend the lamp on. Show the
**projected XP** and the **resulting level** (via `projectedLampXP`) before confirming, so the
choice is informed. A gentle warning if the target is already at the 200M ceiling.

### 9.4 Art
All raid/loop art goes through **`Artwork.swift`** (`SkillArt` → SF Symbol or hand-authored
`VectorIcon`). **No emoji art** in the app (docs may use emoji for flavor, as here). Reuse each
category's symbol/tint for cohesion; add any new vector emblems (boss, forge, mask, node) to
`Artwork.swift`, not inline in views.

---

## 10. Debug hooks (for deterministic screenshots)

Add, guarded by `#if DEBUG`, consistent with the existing `SEED_DEMO` / `OPEN_SKILL` hooks and
passed via `SIMCTL_CHILD_*`:

- `OPEN_RAID=<combat|production|utility|gathering>` — deep-link straight into a raid session.
- `FORCE_RAID_TIER=<0…5>` — override the auto tier for capturing every difficulty.
- `SEED_LAMPS=<group:count,…>` — seed banked lamps to shoot the inventory/apply UI.
- `RAID_RESULT=<win|lose>` — jump to a result screen for deterministic victory/defeat shots.

The implementation PR must include **iPhone and iPad** captures of `RaidsView`, a session of each of
the four loops, the result screen, and the lamp-apply sheet.

---

## 11. Open questions / future

- **Q1 — Mid-raid quit:** the spec marks the attempt spent at **begin** (can't farm retries). If
  that feels harsh for accidental exits, an alternative is a short "abandon within N seconds =
  no-charge" grace. *Default: spend on begin.*
- **Q2 — Fail consolation:** currently **none** (fail = nothing). A tunable
  `raidConsolationFraction` (default 0) could later grant a fractional lamp on a near-miss without
  code changes.
- **Q3 — Onboarding:** whether to add a 5th onboarding card for raids or teach it contextually the
  first time a raid tier unlocks. *Leaning contextual, to avoid onboarding overload.*
- **Future:** raid-specific cosmetics/titles; a weekly "grandmaster" raid; leaderboards for fastest
  clear; letting Utility's Thieving perk (`refundChance`) occasionally refund a spent lamp.

---

## 12. Implementation checklist (for the follow-up PR)

1. `Balance.swift` — add §7 constants + `RaidTierParams` table (ascending difficulty).
2. New `SkillCategory` raid metadata (raid name, tier theme names) — co-locate with `SkillID.swift`
   or a small `Raid.swift`.
3. `GameState` — §8 `SaveData` optional fields, `RaidLampRecord`, derived getters, and the
   `beginRaid` / `finishRaid` / `applyLamp` actions (route XP through `addXP`).
4. `Artwork.swift` — any new vector emblems (boss, forge, mask, resource node).
5. `RootView` — introduce the two-tab `TabView`; keep toasts + offline sheet at the root.
6. `RaidsView`, `RaidSessionView` (four loops), and the lamp-apply sheet — responsive, width-capped,
   universal.
7. `#if DEBUG` hooks (§10).
8. Build & verify on an **iPhone** *and* an **iPad** simulator; capture screenshots for the PR.
9. Update `docs/GAME_DESIGN.md` (new section) and this file if the design shifts during build.
