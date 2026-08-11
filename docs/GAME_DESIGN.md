# XP Waste — Game Design Document

An OSRS-inspired **idle / clicker skilling game** for iOS. Train all **23 Old School RuneScape
skills** from level 1 to 99 through a blend of active tapping and idle Energy-banking,
faithfully following the OSRS experience curve. Built universal for **iPhone and iPad**.

> **v1 scope** — this document describes the full game vision *and* what actually ships in
> v1. Anything marked _(future)_ is designed-for but not implemented yet.

---

## 1. Vision & core fantasy

Recreate the cozy, satisfying grind of OSRS skilling in a mobile-native idle format. The
player taps a big, thematic object to train a skill, sets up passive training, and banks
**Energy** while away so they can return and unleash a bonus-XP **Supercharge** burst. The
long-term goal is the ultimate flex: **level 99 in every skill (a "max cape", total 2277)**.

## 2. Skills (23)

| Category      | Skills |
|---------------|--------|
| Combat (6)     | Attack ⚔️, Strength 💪, Defence 🛡️, Hitpoints ❤️, Ranged 🏹, Magic 🔮 |
| Production (7) | Smithing 🔨, Crafting 🧵, Fletching 🎯, Runecraft 🌀, Cooking 🍳, Construction 🏠, Firemaking 🔥 |
| Utility (5)    | Agility 🏃, Hunter 🪤, Slayer 💀, Thieving 🥷, Prayer 🙏 |
| Gathering (5)  | Woodcutting 🪓, Farming 🌱, Fishing 🎣, Mining ⛏️, Herblore 🧪 |

Every skill uses the **exact OSRS XP curve** (level 99 = 13,034,431 XP; 92 → 99 is roughly
half of that total). All skills start at level 1, so the starting **total level is 23** and
the max is **2277** (23 × 99).

> _Abstraction note:_ In OSRS, several skills (Hitpoints, Prayer, Slayer…) are trained
> indirectly. Here every skill is a first-class tap skill, which suits a tapper. Flagged as an
> intentional deviation.

## 3. Training methods

### 3.1 Manual — "Tap to Train" (active)
Each skill has a **full-screen thematic object**. Tapping it grants XP (the amount depends on
the current method tier, below) with a floating "+X" number, a small object animation, and
optional haptics. Active tapping is the primary driver of early progress.

### 3.2 Thematic tiered training methods
Every skill has **6 training methods** that evolve as the skill levels up, mirroring how the
skill is actually trained in OSRS. The active method is chosen by level, and the on-screen
object visibly upgrades as you climb tiers (a small, frequent reward).

| Tier | Unlocks at level | XP / tap |
|------|------------------|----------|
| 1 | 1  | **1**  |
| 2 | 15 | **3**  |
| 3 | 30 | **6**  |
| 4 | 50 | **12** |
| 5 | 70 | **25** |
| 6 | 90 | **50** |

Examples (basic → end-game): Woodcutting normal → oak → willow → maple → yew → magic tree;
Fishing shrimp → sardines → trout → tuna → lobster → shark; Attack bronze → iron → steel →
mithril → adamant → rune; Runecraft air → earth → fire → nature → law → blood; Slayer crawling
hands → cave crawlers → bloodvelds → abyssal demons → gargoyles → hydra. Because higher tiers
grant more XP per tap, they also **accelerate the brutal late-game curve** (a deliberate pacing
lever). All tier flavor lives in `TrainingMethod.swift`; the ladder itself is in `Balance.swift`.

### 3.3 Passive — "Training Slots" (idle, app open *and* closed)
Assign a skill to a **training slot** to earn passive XP — both while the app is in the foreground
and, at a reduced rate, while it's closed.

- A skill must reach **level 10** before it can be slotted (gives early tapping a purpose).
- Passive rate: **~1 action / second** per slotted skill, valued at that skill's *current method*
  XP — so passive scales as methods improve, but stays a light trickle versus fast manual tapping.
- **Offline progress:** slotted skills keep training while the app is closed at **40%** of the
  base foreground passive rate — scaled by **Hunter** (Trapper, offline XP rate ×) and **Farming**
  (Patient Growth, offline XP retention ×), credited on return, capped by **Construction**
  (Workshop) at **10 h** of away time by default (up to **48 h** at level 99; the window
  **resets each return**, so it can't be banked). A **"welcome back"** summary shows the per-skill
  XP earned and any level-ups. Boosts are consumed in real time, so Supercharge / Daily Boost
  don't apply to offline gains. Only *slotted* skills earn offline.
- **Foreground idle** is a distinct lever: **Smithing** (Foundry) multiplies passive XP while the
  app is *open* (Daily Boost still applies), so the app-open and app-closed rates are tuned
  independently.
- **Slots unlock with total level:** 1 slot at the start → **2nd at total 100** → **3rd at
  total 300** → **4th at total 500** → **5th at total 1000** (tuned for the 23-skill roster).

### 3.4 Energy & Supercharge (charge through active play)
Every skill can bank **Energy** toward a Supercharge, earned through active tapping — not idle time.

- Each tap has a small **base chance** (`Balance.baseEnergyTapChance`, `0.1%`) to bank a burst of
  Energy. **Fishing's *Big Catch* perk multiplies that chance** (×0 untrained → ×10 at Lv 99, so up
  to ~1% per tap) and **Hitpoints' *Vitality* perk raises the amount** banked per proc. Energy is
  capped at **30 seconds** (Mining's *Deep Reserves* raises the cap).
- Tap **Supercharge** to spend all banked Energy. For that many seconds, taps on that skill earn a
  flat **×2** multiplier. (Prayer's *Blessing* perk can add a flat bonus on top — see
  [§4](#4-skill-perks-account-wide-passive-buffs).)

The multiplier applies to the **current method's** XP-per-tap (e.g. a tier-4 method at +12/tap,
supercharged ×2, under 1.5× Daily Boost = 36 XP per tap). This creates the signature
**charge-and-burst loop**: tap to build Energy, then unleash a Supercharge and tap furiously
during the window. Passive slot XP keeps trickling during a Supercharge; only *taps* get the
multiplier. Supercharge is available from level 1 — no slot required.

## 4. Skill perks (account-wide passive buffs)

Leveling a skill grants more than XP and prettier objects: **every skill confers a unique,
account-wide passive perk** that grows stronger as that skill climbs. No two perks pull the same
lever, so training *any* skill benefits the whole account in its own way — Strength widens your
tap's damage ceiling, Attack skews rolls toward that ceiling, Mining deepens your Energy cap,
Runecraft literally auto-taps for you, and so on across all 23.

- **Neutral at level 1.** Each perk's level-1 value is `0`, `×1`, or the exact prior constant, so a
  fresh account plays identically to the pre-perk game. Perks are strictly additive as you level.
- **Scales to 99.** A perk interpolates from its level-1 value to its level-99 value along a curve
  (`linear` in v1), so the buff becomes more prevalent the more you train — a permanent reward that
  layers on top of the tap and idle loops.
- **The active tap is a "hit".** Combat perks reshape each tap into a rolled range: Strength sets
  the ceiling, Defence the floor, Attack biases toward the top, Ranged adds extra hits, and
  Slayer × Crafting land the occasional crit. Non-combat perks feed the idle engine (Energy,
  foreground idle rate, offline rate/cap), the boost economy (Daily Boost potency/duration, Supercharge
  power/duration, coupon/Energy refund), or account tempo (combo, auto-tap).

The full per-skill lever table, designed synergies, and the exact tap pipeline order live in
**[SKILL_BUFFS.md](SKILL_BUFFS.md)**. All perk numbers are centralized in `Balance.buffScaling`, so
re-balancing a perk is a one-line change that never touches gameplay or view code.

## 5. Progression arc (1 → maxed)

- **Early (total 23–100):** Tap skills to level 10 to unlock slotting. Start the first passive
  slot. Learn Supercharge on the first return. Hit the first
  method upgrades (level 15/30).
- **Mid (total 100–300):** Unlock slot 2 (100) and slot 3 (300).
  Juggle three passive skills + active tapping + Supercharge bursts, and push skills
  into their tier-4 methods (level 50, +12/tap).
- **Late (total 300–2277):** Tier-5/6 methods (level 70/90) accelerate the brutal
  OSRS tail. Milestones: first 99 → all combat 99 → all production 99 → all utility 99 → all
  gathering 99 → **max cape (2277)**.

## 6. Screens & UX

1. **Splash** — brief branded loader.
2. **Onboarding** (first launch, 4 short cards) — goal, tap-to-train, slots+Energy,
   Supercharge. Energy/Supercharge detail is reinforced contextually on the first slot.
3. **Home / Skills grid (hub)** — top bar with total level, max-cape progress, and slots
   used; an **adaptive** grid of skill tiles (2 columns on iPhone, more on iPad), grouped into
   the four category sections. Each tile shows the skill's *current method* icon, level, XP bar,
   slot badge, Energy ring, and a "Supercharge ready" glow. Toolbar → Stats and Settings.
4. **Skill Training (full screen, responsive)** — the big tappable object (which upgrades with
   your method tier); a header with level + XP-to-next bar; a **method banner** showing the
   current method, its +X/tap, and the next unlock; a **perk banner** showing this skill's
   account-wide buff, its current magnitude, and the next-level preview; a slot toggle (enabled at
   level 10); and an Energy meter + **Supercharge** button with live countdown and active
   multiplier. Tap "+X" pops highlight **crits, extra hits, and cache windfalls**. On iPad /
   regular width this becomes a **two-pane** layout (object left, method + controls right); on
   iPhone it's a single vertical column.
5. **Stats / Milestones** — total level, per-skill levels, unlock thresholds, a milestone
   checklist, and each skill's **current perk** (icon, name, and live magnitude) so you can see
   exactly what every level is buying you.
6. **Settings** — haptics/sound toggles, reset progress, about + OSRS-inspired disclaimer.

## 7. Visual & audio direction

Dark, cozy "parchment + rune" palette. Each skill has a signature tint and a **vector icon**
(SF Symbol or hand-authored path, via `Artwork.swift`) as its trainable object; the object keeps
one motif per skill and upgrades by tint + size as the method tier advances. Feedback is juicy:
floating XP numbers, object bounce, level-up flash, and haptics. **Sound effects** add an
OSRS-flavoured audio layer — a tap cue on every train, a level-up chime, and cues for Supercharge,
Energy Cells, Daily Boosts, purchases, and interface navigation — all original, OSRS-*inspired*
synth cues (no sampled Jagex audio), gated by the Settings **Sound effects** toggle. See
[SOUND_DESIGN.md](SOUND_DESIGN.md) for the palette, the option-by-option picks, and how to
regenerate or re-pick the cues.

## 8. Technical architecture

- **SwiftUI**, iOS 17+, **universal (iPhone + iPad)**, MVVM. Responsive layouts via adaptive
  grids and `horizontalSizeClass` (two-pane training on regular width); content is width-capped
  and centered so it reads well on large iPad canvases. iPhone is portrait; iPad supports all
  orientations.
- Single source of truth: `GameState` (`ObservableObject`) holds XP, slots, Energy, and
  Supercharge timers; exposes derived values (level, total level, max slots, current method/tier,
  supercharge multiplier).
- **Ticking:** a 1 Hz foreground timer applies passive XP + Energy and counts down active
  Supercharges using real elapsed `dt` (rate-correct regardless of tick jitter).
- **Scene phase:** on background, persist state + timestamp; on foreground, credit **offline XP**
  (40% base rate × Hunter × Farming, capped by Construction at 10–48 h) for slotted skills, then
  reset the offline window. A "welcome back" summary is shown when the player was away long enough.
- **Persistence:** `Codable` snapshot in `UserDefaults`.
- **Tuning:** every balance constant lives in `Balance.swift` so re-balancing is a one-file
  change.

## 9. Balance constants (v1, all tunable in `Balance.swift`)

| Constant | Value |
|----------|-------|
| Training method tiers | +1 / 3 / 6 / 12 / 25 / 50 XP-per-tap, unlocking at level 1 / 15 / 30 / 50 / 70 / 90 |
| Passive rate | ~1 action / sec / slotted skill, valued at the skill's current method XP; **Smithing** multiplies the foreground (app-open) rate up to ×10 |
| Offline passive XP | 40% base rate, scaled by **Hunter** (×1 → ×10) and capped by **Construction** at 10 h → 48 h of away time (window resets on return) |
| Energy charge | ~2% base chance per tap to bank 1 sec (Fishing raises the chance, Hitpoints the amount) |
| Energy cap | 30 sec Supercharge (Mining raises it) |
| Slot eligibility | skill level ≥ 10 |
| Slot 2 / Slot 3 unlock | total level 100 / 300 |
| Supercharge multiplier | flat **×2** tap multiplier (Prayer's *Blessing* perk adds up to +5) |
| Daily Boost | 1.5× all XP for 5 min (base; Magic/Herblore perks scale ×/duration); 1 free coupon/day; IAP packs of 5 / 25 / 100 |
| Energy Cells | Consumable that instantly refills every slotted skill to its Energy cap; IAP packs of 3 / 10 / 30 |
| Skill perks | 23 unique account-wide buffs, each neutral at level 1 and scaling to its level-99 value (`Balance.buffScaling`) — see [SKILL_BUFFS.md](SKILL_BUFFS.md) |

## 10. Professional critique (indie-dev self-review)

**Strengths**
- Clean, legible core loop (tap ↔ idle ↔ Supercharge burst). The Supercharge mechanic is a
  strong retention hook that elegantly bridges active and idle play.
- Proven, satisfying long-tail progression from the real OSRS curve.
- Scope is realistic for a v1.

**Risks & mitigations**
1. **Endgame pacing is still the biggest risk.** The OSRS tail is punishing and a full 23-skill
   max is a very long haul. *Mitigation:* the **tiered training methods** now scale XP-per-tap up
   to 50× (plus Supercharge ×2 and Daily Boost ×1.5) so late-game taps are far more rewarding than
   v1's flat +1; treat further yield-scaling as a balance patch — trivial because all constants
   are centralized. More skills also means more parallel goals and more frequent method-upgrade
   dopamine hits.
2. **Offline pacing balance.** Slotted skills now earn **offline XP** (40% base, scaled by Hunter
   and capped by Construction at 10–48 h), so "idle" pays out directly in addition to
   Energy-banking. *Mitigation:* the reduced base rate and per-skill caps keep active tapping +
   Supercharge bursts primary; all are one-line tunables in `Balance.swift` if returns feel too
   strong or too weak.
3. **Onboarding could overload** with four concepts. *Mitigation:* keep cards short and
   reinforce Energy/Supercharge contextually the first time a skill is slotted.
4. **HP/Prayer abstraction** deviates from OSRS. *Mitigation:* accepted for a tapper; noted.

**Verdict:** the loop is fun and shippable. Ship v1 faithful to the spec with fully tunable
constants; the first post-launch pass is pure balancing.

## 11. Roadmap beyond v1 _(future)_

- Yield-scaling / prestige upgrades (including boosts to the offline XP rate/cap).
- Custom art & animation per skill; SFX and music.
- Achievements, daily goals, and a "max cape" celebration.
- iCloud sync; Game Center leaderboards for total level.
- Skill interactions (e.g., gathering feeds a crafting loop).

## 12. Boosts: Daily Boost, Energy Cells & monetization _(v1.1, energy added v1.2)_

**Concept.** Two consumable "boost" families let players spend for *time and multipliers*, never
for permanent power (permanent power comes from the skill perks in [§4](#4-skill-perks-account-wide-passive-buffs)):

- **Daily Boost coupons** — activate one to earn **1.5× XP on every skill for 5 minutes** (base
  values) — taps, Supercharge taps, and passive slot XP alike. The multiplier stacks
  *multiplicatively* with Supercharge (e.g. ×2 tap → ×3 while boosted).
- **Energy Cells** — spend one to **instantly refill every slotted skill to its Energy cap**, so
  you can Supercharge on demand instead of waiting out the real-time charge.

Skill perks feed both economies rather than competing with them: **Magic** raises the Daily Boost
multiplier above 1.5×, **Herblore** extends the duration past 5 minutes, **Thieving** grants more
free coupons per day, and **Mining / Firemaking / Prayer** make each Energy Cell charge bigger,
longer-lasting, and more powerful. Perks make purchases *stronger*, so IAP and progression
synergize instead of one obsoleting the other.

**Economy.**
- **Free daily coupon(s)** — at least one is granted the first time you open the app each calendar
  day (a classic daily-login hook; missed days don't stack, which rewards returning). The
  **Thieving** perk increases the daily haul as it levels.
- **Coupons are inventory.** You spend one to start a boost, and you can't start a second
  while one is running (prevents accidental waste). Owning more than one just lets you chain
  sessions.
- **Energy Cells are inventory.** Each is a one-tap "skip the wait" — it never raises the cap or
  the multiplier, only fills the meter you already have, so it sells *convenience*, not power.
- **In-app purchases (StoreKit 2, consumables):** two product families —
  coupons as Pouch (5) / Sack (25) / Chest (100) and Energy Cells as Spark (3) / Charged (10) /
  Power Core (30). Real purchase + transaction verification; a local `Config/Products.storekit`
  file drives testing in the simulator, and a DEBUG mock catalog keeps the store UI renderable
  offline. Both families remain purchasable at all times, so a player can always buy an XP
  multiplier *or* Energy.

**UX.**
- A violet **Daily Boost & Energy card** on the Home hub shows either "Tap to activate" (+ coupon
  count) or a live **×N XP ACTIVE · M:SS** countdown (the multiplier reflects the player's live
  Magic-perk value, not a hard-coded 1.5×).
- The training screen shows a live **×N** Daily Boost badge next to the Supercharge badge (which
  itself shows the Prayer-inclusive effective multiplier) so the stacked multiplier is legible,
  and tap "+X" pops reflect the true per-tap amount. When you hold Energy Cells, a **Use Cell**
  quick action appears right in the Energy control to recharge on the spot.
- A dedicated **Boosts sheet** handles Daily Boost activation, coupon balance, Energy Cell use, and
  both storefronts.
- Daily rewards, purchases, and cell use surface a top toast.

**Monetization critique (indie-dev self-review).**
- *Strength:* both boosts are **fun-first and non-coercive** — a free daily coupon means F2P
  players always taste the Daily Boost mechanic, and purchases buy *more of a good time*, not power
  gates. Consumables suit a long grind and stack naturally with the existing Supercharge hook.
- *Agnostic vs. perks (v1.2 rebalance):* the agnostic systems (Energy cap/rate, Supercharge multiplier,
  Daily Boost ×/duration, daily coupons) are deliberately set so their **base value equals each
  related perk at level 1** — at a fresh account the game plays exactly as it did pre-perks, and
  perks only ever add on top. This keeps defaults sensible and stops perks from silently
  redefining the paid systems.
- *Risk — "pay-to-skip" perception.* Because XP is the only resource, buying coupons is
  effectively buying progression. *Mitigation:* keep the boost time-boxed and session-based
  (you must be actively tapping to benefit), so it sells *engagement*, not AFK power. Energy Cells
  are likewise a *skip-the-wait* convenience, capped by your existing Energy cap.
- *Risk — real-time expiry can feel punishing* if the player is interrupted mid-boost.
  *Mitigation (future):* consider pausing the timer on backgrounding, or a "boost only counts
  foreground seconds" model. V1 keeps wall-clock expiry for simplicity and honesty ("5 min").
- *Risk — App Review / ethics:* consumables must be clearly described and restore-exempt;
  the store copy states coupons and Energy Cells are consumable and prices are region-dependent.
  No loot boxes, no randomized rewards. Consumables are **not** wiped by a progress reset (paid
  goods are preserved).
- *Balance lever:* `Balance.doubleXPMultiplier`, `doubleXPDurationSeconds`, `dailyFreeCoupons`,
  and `maxEnergySeconds` are centralized and set the **base** (perk level-1) values; the Magic,
  Herblore, Thieving, and Mining/Firemaking/Prayer perks scale above them via
  `Balance.buffScaling`. Tuning generosity vs. monetization is a one-file change.
