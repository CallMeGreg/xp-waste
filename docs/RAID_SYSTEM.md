# XP Waste — Raid System (design)

One thematic **raid per skill category**, gated to **once per group per day**, whose **difficulty,
room count, and reward tier scale with that group's average skill level**. A raid grants **no XP
while you play** — clearing every room banks a **Skill Lamp** bound to that group, spendable on any
one of its skills.

Unlike a single minigame, **a raid is a multi-room expedition**: a couple of warm-up rooms, a
**mini-boss**, sometimes an **elite** room at the top tiers, then a **final boss** that is tougher
than everything before it. Every room runs a *different* mechanic, and the whole run shares **one
countdown** and **one pool of raid HP**, so it reads like a real adventure rather than a repeated
tap-test.

> **Status:** implemented. This document tracks the shipped design. All tunable numbers live in
> `Balance.swift`; room/boss identities in `RaidPlan.swift`. Any change here must obey the repo's
> universal-app and screenshot rules (both iPhone **and** iPad captures of every new screen).

---

## 1. Goals & pillars

- **A daily, high-stakes, active challenge** that complements — never replaces — the tap/idle loop.
  One shot per group per day; clear it or come back tomorrow.
- **Every raid is an expedition, not a single loop.** Multiple rooms with different goals, a
  mini-boss and a tougher final boss, and (at high tiers) an extra elite room. Difficulty evolves
  **structurally** — more rooms, more boss phases, faster/enraged attacks — not merely "fewer
  mistakes allowed".
- **Six distinct, skill-faithful room mechanics** mixed across the four raids so each group's
  expedition feels different from the next.
- **Bosses that fight back.** Even a *skilling* finale (forge, gathering) layers a telegraphed
  **dodge** on top of the skilling verb, so a boss room is a real fight whether or not you're
  swinging a sword.
- **Rewards that scale with mastery.** Difficulty tracks the group's average level; the payoff (an
  XP lamp) scales with the skill you spend it on, so it stays relevant from level 1 to 99. A
  **flawless** clear (no raid HP lost) banks a bonus lamp.
- **Zero magic numbers in gameplay/view code.** Every raid constant lives in `Balance.swift`.

---

## 2. Where it lives (navigation)

Raids is one tab of the app's **custom bottom tab bar** (`AppTabBar`): **Skills · Raids · Shop ·
Diary · Settings**. `RaidsView` hosts a width-capped, centered 2-column grid of the four raid
cards; tapping **Raid** presents `RaidSessionView` as a `fullScreenCover`. Global toasts and the
offline sheet stay at the root so they overlay every tab.

Universal-app rules apply throughout: no hard-coded sizes, width-capped & centered content, adaptive
layouts via `horizontalSizeClass`, iPad in all orientations.

---

## 3. Raids, tiers & room counts

One raid per category, themed to its skills:

| Group (`SkillCategory`) | Raid | Tagline |
|-------------------------|------|---------|
| **Combat** | **The Colosseum** | Three bouts against the arena's champions. |
| **Production** | **The Grand Forge** | Fill the war-order before the Forge Master. |
| **Utility** | **The Vault Heist** | Three wards stand between you and the vault. |
| **Gathering** | **The Expedition** | Harvest three biomes ahead of the storm. |

### 3.1 Tier = the group's average method tier

A raid's **tier (0…5, Bronze → Rune)** is `Balance.trainingTierIndex` of the group's **average
level** (`GameState.raidTier`). The tier drives everything difficulty-related through
`Balance.raidTierParams[tier]` (`RaidTierParams`) and `Balance.raidRoomCounts[tier]`.

| Tier | Name | Rooms | Raid HP | Final-boss phases | Windows / cadence | Memory len | Decoys | Goal ×|
|-----:|------|:----:|:------:|:-----------------:|:-----------------:|:----------:|:------:|:-----:|
| 0 | Bronze  | 3 | 6 | 1 | widest | 3 | 2 | 1.00 |
| 1 | Iron    | 3 | 6 | 1 | ↓ | 3 | 3 | 1.10 |
| 2 | Steel   | 3 | 5 | 2 | ↓ | 4 | 4 | 1.20 |
| 3 | Mithril | 3 | 5 | 2 | ↓ | 4 | 5 | 1.35 |
| 4 | Adamant | **4** | 4 | 3 | ↓ | 5 | 6 | 1.50 |
| 5 | Rune    | **4** | 4 | **3** | tightest | 5 | 7 | 1.70 |

So a Rune raid isn't just "the Bronze raid with less slack" — it has **an extra room**, a **3-phase
final boss**, fewer hearts, tighter dodge windows, longer memory sequences, and more decoys.

The **timer** is budgeted per room: `raidDuration = raidBaseSeconds + raidSecondsPerRoom × rooms`
(`Balance.raidDuration(forTier:)`), so 3- and 4-room raids both feel fair.

---

## 4. Room mechanics

Each room is one of six `RaidRoomKind`s (`RaidRooms.swift`), each a *distinct* interface with its
own objective. A room clears when its objective count reaches
`Balance.raidRoomGoal(kind:isBoss:tier:)`.

| Kind | Verb | What you do | Boss overlay |
|------|------|-------------|:------------:|
| **barrage** | Dodge & strike | Slide your ward into the one safe lane of a three-lane volley; surviving a wave lands a counter-strike. Pure dodge-and-punish. | owns its dodge |
| **assault** | Break the weakpoints | Tap glowing weakpoints on a looming foe while it telegraphs and **slams**; a missed slam costs a heart. | owns its dodge |
| **forge** | Time the strikes | Rhythm: strike the sweeping meter's moving **sweet-spot**, build a combo. | engine slam |
| **recognition** | Gather the called | Tap the **called** resource among tier-scaled **decoys** (recognition + speed). | engine slam |
| **stealth** | Loot unseen | Grab loot only while the sweeping **searchlight** is turned away; grabbing while watched costs a heart. | self-draws boss |
| **sequence** | Repeat the pattern | Memorise then repeat a lit **glyph sequence** of length `sequenceLength`. | engine slam |

### 4.1 Raid HP vs. tempo

**Raid HP** (hearts, `RaidTierParams.playerHP`) is the *combat* resource for the whole run. Only a
**failed dodge / slam / alarm** (`onMistake`) costs a heart; at zero the raid ends immediately.
Skilling slips (a mistimed forge strike, a wrong recognition pick) cost only **tempo/combo**, never
HP. That's what makes a **flawless** run (no hearts lost) a meaningful, rewardable feat.

---

## 5. Room sequences (per raid)

Built by `SkillCategory.raidRooms(tier:)`. Every raid has a **mini-boss** midway and a **final
boss** last; the extra room at tiers 4–5 (`fourRooms`) splices an **elite** room in before the
finale. Mechanic mixes are deliberately varied per raid.

| Raid | Room 1 | Room 2 (mini-boss) | Elite (tier ≥ 4) | Final boss |
|------|--------|--------------------|------------------|------------|
| **The Colosseum** | Volley Pit (barrage) | **The Sand Beast** (assault) | The Gauntlet (barrage) | **The Champion** (assault) |
| **The Grand Forge** | The Smeltery (forge) | **The Slag Golem** (assault) | The Assembly (sequence) | **The Forge Master** (forge) |
| **The Vault Heist** | Long Corridor (stealth) | **The Warhound** (barrage) | The Tumblers (sequence) | **The Vault Warden** (stealth) |
| **The Expedition** | The Grove (recognition) | **The River Serpent** (barrage) | Drying Racks (forge) | **The Grove Colossus** (recognition) |

---

## 6. Bosses

`RaidBoss` (`RaidPlan.swift`) enumerates eight creatures, each with a proper **name** and a
one-line **threat** flavor. They're drawn by `RaidBossView` (`RaidBossArt.swift`): a **parametrised
vector silhouette on a `Canvas`** — one archetype per boss (brute / construct / hound / warden /
serpent) sharing chrome, so the roster looks varied without a bespoke asset each. The boss
**breathes** (idle bob), its **eyes pulse**, it **flinches + flashes white** when struck
(`hitToken`), darkens as it's wounded (`hpFraction`), and gains an **angry rim + faster pulse** when
**enraged**.

- **Boss HP bar.** In a boss room the objective bar is styled as **boss HP** (`1 − progress/goal`),
  labelled with the boss name and, for a multi-phase final boss, a row of **phase pips**.
- **Phases & enrage.** The final room fights through `RaidTierParams.bossPhases` phases (up to 3);
  the boss is **enraged** in its last third, which tightens the engine slam cadence.
- **Boss goals are longer.** `raidRoomGoal` multiplies a boss room's base objective by
  `raidBossGoalMultiplier + raidBossPhaseGoalBonus × (phases − 1)`, so the finale always outlasts
  the warm-up rooms.
- **Who draws the boss.** `assault` and `stealth` self-draw their boss inside the mechanic; for
  `barrage / forge / recognition / sequence` boss rooms the **engine** renders a boss banner above
  the mechanic. `RaidRoomKind.usesEngineHazards(isBoss:)` marks the *skilling* boss kinds (forge /
  recognition / stealth / sequence) that also receive the shared telegraphed **DODGE!** overlay.

---

## 7. The engine (`RaidSessionView`)

Owns the whole run: it walks `group.raidRooms(tier:)`, runs the shared **countdown**, tracks
**objective progress** per room and global **raid HP**, computes **boss HP / phase / enrage** from
progress, and renders:

- a **HUD** — close, raid name + tier, timer + countdown bar, an **expedition room map** (one node
  per room; bosses flagged, final boss crowned), the objective/boss-HP bar, and **heart** pips;
- an animated `RaidRoomBackdrop` (themed gradient + drifting motes + vignette, reddening on enrage);
- **room-intro cards** (room *x* of *N*, boss art or mechanic glyph, threat, objective, mechanic +
  mini-boss/final-boss chips, and an **Enter / Advance / Face the Boss** button — the timer is
  paused while reading);
- the **shared slam overlay** for `usesEngineHazards` boss rooms (tap to dodge; a lapse costs a
  heart);
- a **result overlay** — win/fail, flawless callout, and the earned **lamp(s)** with the flawless
  bonus.

Clearing the final room wins; running out of hearts or time loses. Both outcomes spend the daily
attempt (spent up-front in `beginRaid`, so quitting can't farm retries).

---

## 8. Daily limit & one-shot pass/fail

`Balance.raidsPerGroupPerDay = 1`. `GameState.beginRaid(group)` stamps the group's day key the
moment the session opens; `isRaidAvailableToday` gates the card's **Raid** button. A finished
attempt (win *or* loss) has already spent the day.

---

## 9. Reward — Skill Lamps

Clearing a raid banks a **Skill Lamp** bound to the group (`RaidLampRecord`); a **flawless** clear
banks `Balance.raidFlawlessBonusLamps` extra (default **1**). `GameState.finishRaid(_:passed:
flawless:)` returns every lamp earned.

### 9.1 Application rules
- A raid lamp is spent from the **Raids** tab (`LampApplySheet`) on **any one skill in its group**.
- Value is computed **at application time** from the target skill's current level, so a lamp banked
  early and spent on a high-level skill is worth more — OSRS-faithful.

### 9.2 Value formula
```
lampXP(skill, tier) = level(skill) × Balance.lampTierCoefficients[tier]
```
`lampTierCoefficients = [500, 900, 1650, 3000, 5500, 10000]` (Bronze → Rune). The tier's coefficient
grows steeply, and multiplying by the skill's **current level** means no two levels look identical.
`GameState.projectedLampXP` shows the exact number before you commit.

### 9.3 Example payouts

| Target skill level | Bronze (×500) | Steel (×1650) | Rune (×10000) |
|-------------------:|--------------:|--------------:|--------------:|
| 20 | 10,000 | 33,000 | 200,000 |
| 50 | 25,000 | 82,500 | 500,000 |
| 90 | 45,000 | 148,500 | 900,000 |

Re-tuning lamps is a one-line `Balance.swift` edit — never gameplay or view code.

---

## 10. Balance constants (all in `Balance.swift`)

- `raidBaseSeconds`, `raidSecondsPerRoom`, `raidDuration(forTier:)` — the shared clock.
- `raidRoomCounts`, `raidRoomCount(forTier:)` — 3 rooms (tiers 0–3) / 4 rooms (tiers 4–5).
- `RaidTierParams` + `raidTierParams[6]`, `raidParams(forTier:)` — per-tier `playerHP`,
  `bossPhases`, `targetLifetime`, `spawnInterval`, `sweetHalfWidth`, `sequenceLength`, `decoyCount`,
  `goalScale`.
- `raidRoomBaseGoal(_:)`, `raidBossGoalMultiplier`, `raidBossPhaseGoalBonus`,
  `raidRoomGoal(kind:isBoss:tier:)` — objective sizes.
- `raidFlawlessBonusLamps` — bonus lamps for a no-hit clear.
- `raidsPerGroupPerDay` — daily gate.
- `lampTierCoefficients`, `lampCoefficient(forTier:)` — lamp value.

---

## 11. Data model & persistence

- **`RaidPlan.swift`** — `RaidRoomKind`, `RaidBoss`, `RaidRoom`, the `SkillCategory` raid identity
  (`raidName`, `raidTagline`, `raidSymbol`, `raidTint`, `raidTintDeep`, `raidRooms(tier:)`,
  `raidTierName`, `raidTierColor`), and `RaidLampRecord`.
- **`GameState`** — `raidTier`, `raidAverageLevel`, `isRaidAvailableToday`, `raidClears`,
  `lamps(for:)`, `projectedLampXP`, `beginRaid`, `finishRaid(_:passed:flawless:) -> [RaidLampRecord]`,
  `applyLamp`. Persisted `SaveData` fields (`raidDayByGroup`, `raidClearsByGroup`, `raidLamps`) are
  optional for backward-compatible decoding.

---

## 12. Screens & files

| File | Role |
|------|------|
| `Sources/Models/RaidPlan.swift` | Room/boss data model + per-group room sequences. |
| `Sources/Models/Balance.swift` (Raids section) | All raid tuning. |
| `Sources/Views/RaidsView.swift` | Raids tab: cards with room/boss lineup, tier, lamp inventory + `LampApplySheet`. |
| `Sources/Views/RaidSessionView.swift` | The multi-room engine, HUD, intro cards, slam overlay, result. |
| `Sources/Views/RaidRooms.swift` | The six room mechanics + `RaidRoomContext`. |
| `Sources/Views/RaidBossArt.swift` | `RaidBossView` (Canvas boss art) + `RaidRoomBackdrop`. |

---

## 13. Debug hooks (deterministic screenshots)

Guarded by `#if DEBUG`, passed via the `SIMCTL_CHILD_` prefix:

- `OPEN_RAID=<combat|production|utility|gathering>` — open that group's raid session.
- `FORCE_RAID_TIER=<0-5>` — override the raid tier (Bronze…Rune).
- `RAID_ROOM=<n>` — start on room *n* (0-based); shows its **intro card** by default.
- `RAID_PLAY=1` — with `RAID_ROOM`, skip the intro and drop into the live mechanic.
- `RAID_RESULT=<win|lose>` — show the **result overlay** without playing (visual-only, doesn't spend
  the day); pair with `RAID_FLAWLESS=1` for the flawless-bonus win.

Example:
```sh
SIMCTL_CHILD_OPEN_RAID=combat SIMCTL_CHILD_FORCE_RAID_TIER=4 \
SIMCTL_CHILD_RAID_ROOM=1 xcrun simctl launch <device> com.callmegreg.xpwaste
```

---

## 14. Future

- Per-boss bespoke attack patterns (currently a shared telegraphed slam for skilling bosses).
- Room modifiers / mutators for replayability within a day's tier.
- A cosmetic "raid log" of best clears and flawless streaks.
