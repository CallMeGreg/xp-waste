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
  cache), and the Stats screen's per-skill perk rows.

## Non-regression guarantee

Every perk's **level-1 value is neutral** — `0`, `×1`, or the exact prior constant (e.g. Magic's
Double XP starts at `2.0×`, Mining's Energy cap starts at `maxEnergySeconds`). On a brand-new
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
| Hitpoints ❤️ | Vitality | `energyRate` | `×1.0 → ×2.0` | Banks **Supercharge Energy faster** on every slot. |
| Ranged 🏹 | Rapid Fire | `extraHit` | `0 → 60%` | Chance for a tap to land an **extra hit** (100%+ guarantees one and rolls again). |
| Prayer 🙏 | Blessing | `superchargeBonus` | `+0 → +5` | **Adds flat** to the active Supercharge multiplier. |
| Magic 🔮 | Enchantment | `doubleXPPotency` | `2.0 → 3.0×` | Empowers **Double XP beyond 2×**. |

### Gathering — feed the idle engine

| Skill | Perk | Kind | Lever (1 → 99) | Effect |
|-------|------|------|-----------------|--------|
| Woodcutting 🪓 | Bird's Nests | `cache` | `0 → 12%` | Chance per tap for a **bonus-XP windfall** (`15×` base method XP). |
| Fishing 🎣 | Big Catch | `energyProc` | `0 → 15%` | Chance per tap to bank **bonus Energy** (`+1s` per proc). |
| Mining ⛏️ | Deep Reserves | `energyCap` | `30s → 60s` | Raises the **maximum bankable Energy** for longer Supercharges. |
| Farming 🌱 | Patient Growth | `offline` | `×1.0 → ×2.0` | Better **offline Energy** efficiency while the app is closed. |
| Hunter 🪤 | Trapper | `passiveRate` | `×1.0 → ×2.5` | Slotted skills train **passively faster**. |

### Artisan — production & the boost economy

| Skill | Perk | Kind | Lever (1 → 99) | Effect |
|-------|------|------|-----------------|--------|
| Cooking 🍳 | Well Fed | `tapPercent` | `+0% → +50%` | **+% XP on every tap**, on every skill. |
| Firemaking 🔥 | Slow Burn | `superchargeDuration` | `×1.0 → ×2.0` | **Supercharge bursts last longer.** |
| Crafting 🧵 | Masterwork | `critMagnitude` | `×2.0 → ×4.0` | **Critical taps hit harder** (crit chance comes from Slayer). |
| Smithing 🔨 | Foundry | `passivePercent` | `+0% → +100%` | **+% passive (slot) XP.** |
| Fletching 🎯 | Extra Ammo | `flatTap` | `+0 → +8` | Adds **flat bonus XP** to every tap. |
| Herblore 🧪 | Alchemist | `doubleXPDuration` | `+0 → +300s` | **Double XP boosts last longer.** |
| Runecraft 🌀 | Runic Automaton | `autoTap` | `0 → 3 / s` | **Auto-taps** the skill you're currently training. |
| Construction 🏠 | Workshop | `passiveMultiplier` | `×1.0 → ×2.0` | **Multiplies idle (slot) XP** — every level raises passive output. |

### Support — tempo & meta

| Skill | Perk | Kind | Lever (1 → 99) | Effect |
|-------|------|------|-----------------|--------|
| Agility 🏃 | Momentum | `combo` | `×1.0 → ×1.6` | Fast tapping builds a **combo multiplier** (ramps over ~20 taps within a 1.2s window). |
| Thieving 🥷 | Pickpocket | `refund` | `0% → 50%` | Chance to **refund a spent coupon or Supercharge** ("nick it back"). |
| Slayer 💀 | Assassinate | `critChance` | `0 → 15%` | Chance for a **critical tap** (magnitude comes from Crafting). |

## Designed synergies

Some perks intentionally pair across skills so leveling two things compounds:

- **Crits = Slayer × Crafting.** Slayer sets the *chance*, Crafting sets the *magnitude*. Slayer
  starts at `0%`, so no tap crits until you train it (preserving non-regression); Crafting starts
  at `×2`, so your first crit is already meaty.
- **Supercharge power = Prayer, duration = Firemaking, cap = Mining, rate = Hitpoints, refund =
  Thieving.** The whole Energy/Supercharge loop is levered by five different skills.
- **Double XP = Magic (potency) × Herblore (duration) × Thieving (refund).** The boost economy is
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
6. If Double XP is active, `× Magic` Double XP potency.
7. Side-effect: on a **Fishing** proc, bank bonus Energy to the tapped skill.

`GameState.expectedTapGain(for:)` computes the deterministic *average* of this pipeline for
display (the method banner's "+X / tap"), while `rollTap` is the live, rolled result that drives
the tap pops.

## Secondary constants

Beyond the `buffScaling` envelope, a few perks reference fixed constants in `Balance.swift`:

| Constant | Value | Used by |
|----------|-------|---------|
| `woodcuttingCacheMultiple` | `15×` base | Woodcutting cache windfall size |
| `fishingProcEnergySeconds` | `1s` | Fishing Big Catch Energy per proc |
| `agilityComboWindow` | `1.2s` | Max gap between taps to keep a combo chaining |
| `agilityComboTapsToMax` | `20` | Taps to ramp a combo to its ceiling |
