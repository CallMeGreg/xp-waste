# XP Waste — Skill Perks

Every one of the 23 skills grants a **unique, account-wide passive perk**. No two perks pull the
same mechanical lever, so leveling *any* skill makes the whole account measurably stronger in a
different way. A perk's magnitude scales with that skill's level — neutral at level 1, fully
realized at level 99 — so training is always paying into a permanent buff on top of raw XP.

- **Data & theming:** `Sources/Models/SkillBuff.swift` (`BuffKind`, per-skill `SkillID.buff`
  name/icon/blurb).
- **All tunable numbers:** `Sources/Models/Balance.swift` (`buffScaling` + secondary constants).
- **Application:** `Sources/Models/GameState.swift` (aggregate getters + the tap pipeline).
- **Surfacing:** the training screen's **perk banner**, tap-outcome pops (crit / extra hit /
  cache), and the Skills hub's per-skill perk descriptors.

## Non-regression guarantee

Every perk's **level-1 value is neutral** — `0`, `×1`, or the exact prior constant (e.g. Magic's
Daily Boost starts at `1.5×`, Mining's Energy cap starts at `maxEnergySeconds`). On a brand-new
account (level 1 in everything) the tap range collapses to a single value and no procs can fire,
so the game plays **identically to before the perk system existed**. Perks are strictly additive
as you level.

## Scaling model

Each perk has a `BuffScaling { at1, at99, curve }` envelope in `Balance.buffScaling`. The value at
a given level is:

```
buffValue(level) = at1 + (at99 − at1) × buffProgress(level, curve)
```

`buffProgress` returns `0` at level 1 and `1` at level 99. Curves: `linear` (steady), `easeIn`
(back-loaded, most payoff at high levels), `easeOut` (front-loaded). All v1 perks use `linear`.
**Re-balancing any perk is a one-line change to its `at1`/`at99`/`curve`** — gameplay and view
code never change.

## The 23 perks

Values below are **level 1 → level 99** (the full envelope). "Kind" is the `BuffKind` case.

### Combat — shape the active tap "hit"

| Skill | Perk | Kind | Lever (1 → 99) | Effect |
|-------|------|------|-----------------|--------|
| Attack ⚔️ | Accuracy | `accuracy` | bias `0 → 6` | Skews each tap's XP roll toward its **max hit** (fewer low rolls). |
| Strength 💪 | Power | `maxHit` | `×1.0 → ×2.0` | Raises the **ceiling** of the tap XP range (chance for bigger clicks). |
| Defence 🛡️ | Guard | `minHit` | `×1.0 → ×1.75` | Raises the guaranteed **floor** of the tap XP range (clamped ≤ ceiling). |
| Hitpoints ❤️ | Vitality | `energyRate` | `×1.0 → ×2.0` | Banks **more Supercharge Energy** each time a tap sparks a charge. |
| Ranged 🏹 | Rapid Fire | `extraHit` | `0 → 60%` | Chance for a tap to land an **extra hit** (100%+ guarantees one and rolls again). |
| Magic 🔮 | Enchantment | `doubleXPPotency` | `1.5 → 3.0×` | Empowers **the Daily Boost beyond 1.5×**. |

### Production — taps, idle & the boost economy

| Skill | Perk | Kind | Lever (1 → 99) | Effect |
|-------|------|------|-----------------|--------|
| Smithing 🔨 | Foundry | `foregroundRate` | `×1.0 → ×5.0` | Multiplies **foreground idle** XP (app *open*). |
| Crafting 🧵 | Masterwork | `critMagnitude` | `×2.0 → ×4.0` | **Critical taps hit harder** (crit chance comes from Slayer). |
| Fletching 🎯 | Extra Ammo | `flatTap` | `+0 → +8` | Adds **flat bonus XP** to every tap. |
| Runecraft 🌀 | Runic Automaton | `autoTap` | `0 → 3 / s` | **Auto-taps** the skill you're currently training. |
| Cooking 🍳 | Well Fed | `tapPercent` | `+0% → +50%` | **+% XP on every tap**, on every skill. |
| Construction 🏠 | Workshop | `offlineCap` | `10h → 48h` | Raises the **offline accrual cap** — bank more hours of away-time XP. |
| Firemaking 🔥 | Slow Burn | `superchargeDuration` | `×1.0 → ×2.0` | **Supercharge bursts last longer.** |

### Utility — tempo, offline & meta

| Skill | Perk | Kind | Lever (1 → 99) | Effect |
|-------|------|------|-----------------|--------|
| Agility 🏃 | Momentum | `combo` | `×1.0 → ×1.6` | Fast tapping builds a **combo multiplier** (ramps over ~20 taps within a 1.2s window). |
| Hunter 🪤 | Trapper | `offlineRate` | `×1.0 → ×3.0` | Multiplies **offline** passive XP (app *closed*) — traps keep working while you're away. |
| Slayer 💀 | Assassinate | `critChance` | `0 → 15%` | Chance for a **critical tap** (magnitude comes from Crafting). |
| Thieving 🥷 | Pickpocket | `refund` | `0% → 30%` | Chance to **refund a spent coupon or Energy Cell** ("nick it back"). |
| Prayer 🙏 | Blessing | `superchargePotency` | `+0.00 → +3.00` | **Adds** to the active Supercharge multiplier (base `×2` → up to `×5`). |

### Gathering — feed the idle engine

| Skill | Perk | Kind | Lever (1 → 99) | Effect |
|-------|------|------|-----------------|--------|
| Woodcutting 🪓 | Bird's Nests | `cache` | `0 → 12%` | Chance per tap for a **bonus-XP windfall** (`15×` base method XP). |
| Farming 🌱 | Patient Growth | `offline` | `×1.0 → ×2.0` | Keeps **more offline XP** while the app is closed. |
| Fishing 🎣 | Big Catch | `energyProc` | `×0 → ×10` | **Multiplies** the `0.1%` base per-tap chance to bank Supercharge Energy — `0%` untrained up to `1%` at Lv 99. |
| Mining ⛏️ | Deep Reserves | `energyCap` | `30s → 60s` | Raises the **maximum bankable Energy** for longer Supercharges. |
| Herblore 🧪 | Alchemist | `doubleXPDuration` | `+0 → +300s` | **Daily Boosts last longer.** |

## Designed synergies

Some perks intentionally pair across skills so leveling two things compounds:

- **Crits = Slayer × Crafting.** Slayer sets the *chance*, Crafting sets the *magnitude*. Slayer
  starts at `0%`, so no tap crits until you train it (preserving non-regression); Crafting starts
  at `×2`, so your first crit is already meaty.
- **Supercharge power = Prayer, duration = Firemaking, cap = Mining, charge chance = Fishing,
  charge amount = Hitpoints, Energy-Cell refund = Thieving.** The whole Energy/Supercharge loop is levered by
  several different skills.
- **Daily Boost = Magic (potency) × Herblore (duration) × Thieving (refund).** The boost economy is
  levered by three skills — Thieving can even hand the spent coupon straight back.
- **Idle engine = Hunter (rate) × Smithing (+% XP) × Construction (workshop ×).** Slotted passive
  training is levered by three skills that stack multiplicatively.
- **Tap "hit" range = Strength (ceiling) × Defence (floor) × Attack (bias).** The core click is
  shaped by three combat skills at once.

## Tap pipeline (order of operations)

Resolved in `GameState.rollTap(for:)`. Each tap:

1. `base` = the skill's current **method XP/tap** (from `TrainingMethod` tiers).
2. For each hit — `1 + Ranged` extra hits:
   1. **Roll the hit** uniformly in `[minHit, maxHit]`, where `maxHit = base × Power(Strength)`
      and `minHit = base × Guard(Defence)` (clamped ≤ `maxHit`), then **skew toward max** by
      Attack's `Accuracy` exponent.
   2. `+ Fletching` flat bonus.
   3. `× Cooking` tap-XP multiplier.
   4. `× Agility` combo multiplier.
   5. If **Slayer** crit chance procs, `× Crafting` crit magnitude.
3. Sum the hits.
4. On a **Woodcutting** cache proc, add a `15×` base windfall.
5. If supercharged, `× (Supercharge multiplier + Prayer bonus)`.
6. If Daily Boost is active, `× Magic` Daily Boost potency.
7. Side-effect: each tap has a **base chance** (`baseEnergyTapChance`, *multiplied* by **Fishing**) to
   bank Supercharge Energy to the tapped skill, in an amount scaled by **Hitpoints**.

`GameState.expectedTapGain(for:)` computes the deterministic *average* of this pipeline for
display (the method banner's "+X / tap"), while `rollTap` is the live, rolled result that drives
the tap pops.

## Secondary constants

Beyond the `buffScaling` envelope, a few perks reference fixed constants in `Balance.swift`:

| Constant | Value | Used by |
|----------|-------|---------|
| `woodcuttingCacheMultiple` | `15×` base | Woodcutting cache windfall size |
| `baseEnergyTapChance` | `0.1%` | Unit per-tap chance to bank Supercharge Energy (Fishing multiplies it ×0→×10) |
| `energyTapProcSeconds` | `1s` | Energy banked per tap-proc (scaled by Hitpoints) |
| `agilityComboWindow` | `1.2s` | Max gap between taps to keep a combo chaining |
| `agilityComboTapsToMax` | `20` | Taps to ramp a combo to its ceiling |
