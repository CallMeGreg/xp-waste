# XP Waste — Raid System (design)

One thematic **raid per skill category**, gated to **once per group per day**, whose **difficulty,
room count, and reward tier scale with that group's average skill level**. A raid grants **no XP
while you play** — clearing every room banks a **Skill Lamp** bound to that group, spendable on any
one of its skills.

Unlike a single minigame, **a raid is a multi-room expedition**: a **warm-up skill room**, a
**mini-boss**, then a **final boss** that is tougher than everything before it. Every room runs a
*different* mechanic — **twelve rooms across the game, twelve distinct loops, none ever reused** —
and the whole run shares **one countdown** and **one pool of raid HP**, so it reads like a real
adventure rather than a repeated tap-test.

> **Status:** implemented. This document tracks the shipped design. All tunable numbers live in
> `Balance.swift`; room/boss identities in `RaidPlan.swift`. Any change here must obey the repo's
> universal-app and screenshot rules (both iPhone **and** iPad captures of every new screen).

---

## 1. Goals & pillars

- **A daily, high-stakes, active challenge** that complements — never replaces — the tap/idle loop.
  One shot per group per day; clear it or come back tomorrow.
- **Every raid is an expedition, not a single loop.** Three rooms with different goals — a warm-up
  skill room, a mini-boss and a tougher final boss. Difficulty evolves **structurally** — more boss
  phases, faster/enraged attacks, larger objectives, tighter windows, longer memory sequences and
  more decoys, fewer hearts — not merely "fewer mistakes allowed".
- **Twelve distinct, skill-faithful room mechanics — one per room, none ever repeated** across the
  four raids, so every room in the game is its own game loop and each expedition feels different
  from the last.
- **Bosses that fight back — natively, inside the mechanic.** There is **no full-screen dodge
  overlay**. A reaction boss punishes a missed defence with a heart from within its own room (the
  combat finale trades blows through **red "strike"** and **green "parry"** circles); a *skilling*
  boss instead trips a visible **two-strike alarm** before it takes a heart. A boss room is a real
  fight whether or not you're swinging a sword.
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
| 4 | Adamant | 3 | 4 | 3 | ↓ | 5 | 6 | 1.50 |
| 5 | Rune    | 3 | 4 | **3** | tightest | 5 | 7 | 1.70 |

So a Rune raid isn't just "the Bronze raid with less slack" — the same three rooms bite far harder:
a **3-phase final boss**, fewer hearts, tighter reaction windows, longer memory sequences, more
decoys, and larger objectives (`goalScale`).

The **timer** is budgeted per room: `raidDuration = raidBaseSeconds + raidSecondsPerRoom × rooms`
(`Balance.raidDuration(forTier:)` — currently `40 + 46 × 3`), so every raid feels fair.

---

## 4. Room mechanics — twelve distinct loops

Each room runs one of **twelve** `RaidRoomKind`s (`RaidRooms.swift`), each a wholly *distinct*
interface with its own objective — **no loop is ever reused**, within a raid or across the four
raids. A room clears when its objective count reaches `Balance.raidRoomGoal(kind:isBoss:tier:)`.
The twelve are three-per-raid, deliberately pairing a reaction verb, a timing/skilling verb and a
memory/precision verb so each expedition has its own rhythm:

| Raid | Kind | Verb | What you do | Role |
|------|------|------|-------------|------|
| **Colosseum** | `laneDodge` | Dodge & strike | Slide your ward to the one safe lane of a three-lane volley, then strike in the gap. | warm-up |
| **Colosseum** | `swipeDodge` | Read & sidestep | Read the Sand Beast's telegraphed lunge, swipe the opposite way, land the counter. | mini-boss |
| **Colosseum** | `duel` | Trade blows | Tap **red** openings to strike the Champion; tap **green** incoming blows to parry before their ring closes. | **final** |
| **Grand Forge** | `rhythm` | Time the strikes | Strike the sweeping meter's moving sweet-spot; build a heat combo. | warm-up |
| **Grand Forge** | `charge` | Stoke & release | Hold to drive the heat gauge up, release inside the target band — overheat and the Slag Golem splashes you. | mini-boss |
| **Grand Forge** | `dial` | Align the press | Rotate the key notch to the top and lock before the Forge Master's press-timer fires. | **final** |
| **Vault Heist** | `stealth` | Loot unseen | Grab loot only while the sweeping searchlight is turned away. | warm-up |
| **Vault Heist** | `pathTrace` | Trace the route | Drag the loot along the safe corridor past the Warhound, hitting each waypoint without straying. | mini-boss |
| **Vault Heist** | `memory` | Repeat the pattern | Watch, then repeat each lit lock-rune in order; two wrong rounds trip the Warden's alarm. | **final** |
| **Expedition** | `recognition` | Gather the called | Tap the *called* resource among tier-scaled decoys. | warm-up |
| **Expedition** | `mash` | Haul it in | Rapid-tap to haul the net — but freeze the instant the River Serpent thrashes. | mini-boss |
| **Expedition** | `sort` | Sort the offerings | Route each streaming offering to its side (ripe → altar / rotten → pit); two mis-sends trip the Colossus's alarm. | **final** |

### 4.1 Raid HP vs. tempo

**Raid HP** (hearts, `RaidTierParams.playerHP`) is the *combat* resource for the whole run. Only a
**failed defence** (`onMistake`) costs a heart: a lapsed parry or dodge, an overheat, a missed
press, straying off the trace path, or a boss **alarm** filling. At zero hearts the raid ends
immediately. Pure-skilling slips in a non-boss room (a mistimed forge strike, a wrong recognition
pick) cost only **tempo/combo**, never HP — which is what makes a **flawless** run (no hearts lost)
a meaningful, rewardable feat.

---

## 5. Room sequences (per raid)

Built by `SkillCategory.raidRooms(tier:)`. Every raid is exactly three rooms — a **warm-up skill
room → a mini-boss → a tougher final boss** — and **no mechanic is reused** in any of the twelve
slots. The mix is deliberately different per raid so no two expeditions feel alike.

| Raid | Room 1 (warm-up) | Room 2 (mini-boss) | Room 3 (final boss) |
|------|------------------|--------------------|---------------------|
| **The Colosseum** | The Volley Pit — `laneDodge` | **The Sand Beast** — `swipeDodge` | **The Champion** — `duel` |
| **The Grand Forge** | The Smeltery — `rhythm` | **The Slag Golem** — `charge` | **The Forge Master** — `dial` |
| **The Vault Heist** | The Long Corridor — `stealth` | **The Warhound** — `pathTrace` | **The Vault Warden** — `memory` |
| **The Expedition** | The Grove — `recognition` | **The River Serpent** — `mash` | **The Grove Colossus** — `sort` |

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
  the boss is **enraged** in its last third, which speeds up its own attacks (faster strike/parry
  spawns, shorter press and reaction windows) and reddens the room.
- **Boss goals are longer.** `raidRoomGoal` multiplies a boss room's base objective by
  `raidBossGoalMultiplier + raidBossPhaseGoalBonus × (phases − 1)`, so the finale always outlasts
  the warm-up rooms.
- **Who draws the boss.** The two combat bosses — `swipeDodge` (Sand Beast) and `duel` (Champion) —
  **self-draw** their creature *inside* the mechanic (`RaidRoomKind.selfDrawsBoss`), because the
  boss art *is* the fight. Every other boss room renders the creature in the **engine's boss banner**
  above the stage while you work the mechanic below.
- **How bosses threaten — no full-screen overlay.** There is no shared slam / DODGE overlay any
  more. Each boss punishes you from inside its own room: **reaction bosses** cost a **heart** the
  instant a defence lapses (`duel` green-blow expiry, `swipeDodge` timeout, `charge` overheat,
  `dial` press-timeout, `pathTrace` stray); **skilling bosses** (`memory`, `sort`) fill a visible
  **two-strike alarm** and only then take a heart.

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
- `raidRoomCounts`, `raidRoomCount(forTier:)` — rooms per tier (currently **3 at every tier**).
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
| `Sources/Views/RaidSessionView.swift` | The multi-room engine, HUD, intro cards, native boss threats, result. |
| `Sources/Views/RaidRooms.swift` | The twelve room mechanics + `RaidRoomContext`. |
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

- Even more per-boss attack variety (e.g. multi-lane duel volleys, drifting `dial` notches).
- Room modifiers / mutators for replayability within a day's tier.
- A cosmetic "raid log" of best clears and flawless streaks.
