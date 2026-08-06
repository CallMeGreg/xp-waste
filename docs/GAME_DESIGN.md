# Idle Skiller — Game Design Document

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
| Combat (7)    | Attack ⚔️, Strength 💪, Defence 🛡️, Hitpoints ❤️, Ranged 🏹, Prayer 🙏, Magic 🔮 |
| Gathering (5) | Woodcutting 🪓, Fishing 🎣, Mining ⛏️, Farming 🌱, Hunter 🪤 |
| Artisan (8)   | Cooking 🍳, Firemaking 🔥, Crafting 🧵, Smithing 🔨, Fletching 🎯, Herblore 🧪, Runecraft 🌀, Construction 🏠 |
| Support (3)   | Agility 🏃, Thieving 🥷, Slayer 💀 |

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

### 3.3 Passive — "Training Slots" (idle, app open)
Assign a skill to a **training slot** to earn passive XP while the app is in the foreground.

- A skill must reach **level 10** before it can be slotted (gives early tapping a purpose).
- Passive rate: **~1 action / second** per slotted skill, valued at that skill's *current method*
  XP — so passive scales as methods improve, but stays a light trickle versus fast manual tapping.
- **Slots unlock with total level:** 1 slot at the start → **2nd slot at total 100** →
  **3rd slot at total 300** (tuned for the 23-skill roster).

### 3.4 Energy & Supercharge (idle, app open *and* closed)
Each slotted skill accumulates **Energy** in real time — whether the app is open or closed.

- Conversion: **1 minute of elapsed time = 1 second of Supercharge**, capped at **30
  seconds** (so 30 minutes fully charges a skill).
- Tap **Supercharge** to spend all banked Energy. For that many seconds, taps on that skill are
  **multiplied**:

  | Supercharge tier | Multiplier | Unlocks at total level |
  |------------------|------------|------------------------|
  | I   | **×2**  | 0 (start) |
  | II  | **×5**  | 100 |
  | III | **×10** | 300 |
  | IV  | **×20** | 500 |

The multiplier applies to the **current method's** XP-per-tap (e.g. a tier-4 method at +12/tap,
supercharged ×10, under 2× Double XP = 240 XP per tap). This creates the signature
**return-and-burst loop**: idle to bank Energy, come back, and tap furiously during the
Supercharge window. Passive XP keeps trickling during a Supercharge; only *taps* get the multiplier.

## 4. Progression arc (1 → maxed)

- **Early (total 23–100):** Tap skills to level 10 to unlock slotting. Start the first passive
  slot. Learn Supercharge on the first return. Hit the first method upgrades (level 15/30).
- **Mid (total 100–300):** Unlock slot 2 (100) and slot 3 (300). Reach Supercharge tier II
  (100). Juggle three passive skills + active tapping + Supercharge bursts, and push skills into
  their tier-4 methods (level 50, +12/tap).
- **Late (total 300–2277):** Supercharge tiers III (300) and IV (500); tier-5/6 methods (level
  70/90) accelerate the brutal OSRS tail. Milestones: first 99 → all combat 99 → all gathering
  99 → all artisan 99 → all support 99 → **max cape (2277)**.

## 5. Screens & UX

1. **Splash** — brief branded loader.
2. **Onboarding** (first launch, 4 short cards) — goal, tap-to-train, slots+Energy,
   Supercharge. Energy/Supercharge detail is reinforced contextually on the first slot.
3. **Home / Skills grid (hub)** — top bar with total level, max-cape progress, and slots
   used; an **adaptive** grid of skill tiles (2 columns on iPhone, more on iPad), grouped into
   the four category sections. Each tile shows the skill's *current method* glyph, level, XP bar,
   slot badge, Energy ring, and a "Supercharge ready" glow. Toolbar → Stats and Settings.
4. **Skill Training (full screen, responsive)** — the big tappable object (which upgrades with
   your method tier); a header with level + XP-to-next bar; a **method banner** showing the
   current method, its +X/tap, and the next unlock; a slot toggle (enabled at level 10); and an
   Energy meter + **Supercharge** button with live countdown and active multiplier. On iPad /
   regular width this becomes a **two-pane** layout (object left, method + controls right); on
   iPhone it's a single vertical column.
5. **Stats / Milestones** — total level, per-skill levels, unlock thresholds, and a milestone
   checklist.
6. **Settings** — haptics/sound toggles, reset progress, about + OSRS-inspired disclaimer.

## 6. Visual & audio direction

Dark, cozy "parchment + rune" palette. Each skill has a signature tint and an emoji glyph as
its v1 trainable object (designed to be swapped for custom art later). Feedback is juicy:
floating XP numbers, object bounce, level-up flash, and haptics. Audio hooks are stubbed for
v1 _(future: tap/level/supercharge SFX)_.

## 7. Technical architecture

- **SwiftUI**, iOS 17+, **universal (iPhone + iPad)**, MVVM. Responsive layouts via adaptive
  grids and `horizontalSizeClass` (two-pane training on regular width); content is width-capped
  and centered so it reads well on large iPad canvases. iPhone is portrait; iPad supports all
  orientations.
- Single source of truth: `GameState` (`ObservableObject`) holds XP, slots, Energy, and
  Supercharge timers; exposes derived values (level, total level, max slots, current method/tier,
  supercharge multiplier).
- **Ticking:** a 1 Hz foreground timer applies passive XP + Energy and counts down active
  Supercharges using real elapsed `dt` (rate-correct regardless of tick jitter).
- **Scene phase:** on background, persist state + timestamp; on foreground, credit **offline
  Energy** for slotted skills (capped) — offline grants Energy only, never passive XP, per
  the design.
- **Persistence:** `Codable` snapshot in `UserDefaults`.
- **Tuning:** every balance constant lives in `Balance.swift` so re-balancing is a one-file
  change.

## 8. Balance constants (v1, all tunable in `Balance.swift`)

| Constant | Value |
|----------|-------|
| Training method tiers | +1 / 3 / 6 / 12 / 25 / 50 XP-per-tap, unlocking at level 1 / 15 / 30 / 50 / 70 / 90 |
| Passive rate | ~1 action / sec / slotted skill, valued at the skill's current method XP |
| Energy charge rate | 1 sec Supercharge per 60 sec real time |
| Energy cap | 30 sec Supercharge (30 min real) |
| Slot eligibility | skill level ≥ 10 |
| Slot 2 / Slot 3 unlock | total level 100 / 300 |
| Supercharge tiers | ×2 / ×5 / ×10 / ×20 tap multiplier at total 0 / 100 / 300 / 500 |
| Double XP boost | 2× all XP for 10 min; 1 free coupon/day; IAP packs of 5 / 25 / 100 |

## 9. Professional critique (indie-dev self-review)

**Strengths**
- Clean, legible core loop (tap ↔ idle ↔ Supercharge burst). The Supercharge mechanic is a
  strong retention hook that elegantly bridges active and idle play.
- Proven, satisfying long-tail progression from the real OSRS curve.
- Scope is realistic for a v1.

**Risks & mitigations**
1. **Endgame pacing is still the biggest risk.** The OSRS tail is punishing and a full 23-skill
   max is a very long haul. *Mitigation:* the **tiered training methods** now scale XP-per-tap up
   to 50× (plus Supercharge ×20 and Double XP ×2) so late-game taps are far more rewarding than
   v1's flat +1; treat further yield-scaling as a balance patch — trivial because all constants
   are centralized. More skills also means more parallel goals and more frequent method-upgrade
   dopamine hits.
2. **"Idle" is really Energy-banking, not offline XP** (per spec). *Mitigation:* lean into the
   return-and-burst payoff and keep passive a light trickle so active tapping stays primary.
   _(future: optional offline passive XP as a prestige upgrade.)_
3. **Onboarding could overload** with four concepts. *Mitigation:* keep cards short and
   reinforce Energy/Supercharge contextually the first time a skill is slotted.
4. **HP/Prayer abstraction** deviates from OSRS. *Mitigation:* accepted for a tapper; noted.

**Verdict:** the loop is fun and shippable. Ship v1 faithful to the spec with fully tunable
constants; the first post-launch pass is pure balancing.

## 10. Roadmap beyond v1 _(future)_

- Yield-scaling / prestige and optional offline passive XP.
- Custom art & animation per skill; SFX and music.
- Achievements, daily goals, and a "max cape" celebration.
- iCloud sync; Game Center leaderboards for total level.
- Skill interactions (e.g., gathering feeds a crafting loop).

## 11. Double XP coupons & monetization _(v1.1)_

**Concept.** A universal **Double XP** boost: activate a coupon to earn **2× XP on every
skill for 10 minutes** — taps, Supercharge taps, and passive slot XP alike. The multiplier
stacks *multiplicatively* with Supercharge (e.g. ×5 tap → ×10 while boosted), creating a
"stack your buffs" power fantasy.

**Economy.**
- **Free daily coupon** — one is granted the first time you open the app each calendar day
  (a classic daily-login hook; missed days don't stack, which rewards returning).
- **Coupons are inventory.** You spend one to start a boost, and you can't start a second
  while one is running (prevents accidental waste). Owning more than one just lets you chain
  sessions.
- **In-app purchases (StoreKit 2, consumables):** Pouch (5), Sack (25), Chest (100). Real
  purchase + transaction verification; a local `Config/Products.storekit` file drives testing
  in the simulator, and a DEBUG mock catalog keeps the store UI renderable offline.

**UX.**
- A violet **Double XP card** on the Home hub shows either "Tap to activate" (+ coupon count)
  or a live **2× XP ACTIVE · M:SS** countdown.
- The training screen shows a **2×** badge next to the Supercharge badge so the stacked
  multiplier is legible, and tap "+X" pops reflect the true per-tap amount.
- A dedicated **Double XP sheet** handles activation, coupon balance, and the store.
- Daily rewards and purchases surface a top toast.

**Monetization critique (indie-dev self-review).**
- *Strength:* the boost is **fun-first and non-coercive** — a free daily coupon means F2P
  players always taste the mechanic, and purchases buy *more of a good time*, not power gates.
  Consumables suit a long grind and stack naturally with the existing Supercharge hook.
- *Risk — "pay-to-skip" perception.* Because XP is the only resource, buying coupons is
  effectively buying progression. *Mitigation:* keep the boost time-boxed and session-based
  (you must be actively tapping to benefit), so it sells *engagement*, not AFK power.
- *Risk — real-time expiry can feel punishing* if the player is interrupted mid-boost.
  *Mitigation (future):* consider pausing the timer on backgrounding, or a "boost only counts
  foreground seconds" model. V1 keeps wall-clock expiry for simplicity and honesty ("10 min").
- *Risk — App Review / ethics:* consumables must be clearly described and restore-exempt;
  the store copy states coupons are consumable and prices are region-dependent. No loot boxes,
  no randomized rewards.
- *Balance lever:* `Balance.doubleXPMultiplier`, `doubleXPDurationSeconds`, and
  `dailyFreeCoupons` are centralized, so tuning generosity vs. monetization is a one-file change.
