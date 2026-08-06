# Idle Skiller — Game Design Document

An OSRS-inspired **idle / clicker skilling game** for iOS. Train ten skills from level 1
to 99 through a blend of active tapping and idle Energy-banking, faithfully following the
Old School RuneScape experience curve.

> **v1 scope** — this document describes the full game vision *and* what actually ships in
> v1. Anything marked _(future)_ is designed-for but not implemented yet.

---

## 1. Vision & core fantasy

Recreate the cozy, satisfying grind of OSRS skilling in a mobile-native idle format. The
player taps a big, thematic object to train a skill, sets up passive training, and banks
**Energy** while away so they can return and unleash a bonus-XP **Supercharge** burst. The
long-term goal is the ultimate flex: **level 99 in every skill (a "max cape", total 990)**.

## 2. Skills (10)

| Category   | Skills |
|------------|--------|
| Combat (7) | Attack ⚔️, Strength 🪨, Defence 🛡️, Ranged 🏹, Magic 🔮, Hitpoints ❤️, Prayer 🙏 |
| Gathering (3) | Woodcutting 🌳, Fishing 🎣, Mining ⛏️ |

Every skill uses the **exact OSRS XP curve** (level 99 = 13,034,431 XP; 92 → 99 is roughly
half of that total). All skills start at level 1, so the starting **total level is 10** and
the max is **990**.

> _Abstraction note:_ In OSRS, Hitpoints and Prayer are trained indirectly. Here they are
> first-class tap skills, which suits a tapper. Flagged as an intentional deviation.

## 3. Training methods

### 3.1 Manual — "Tap to Train" (active)
Each skill has a **full-screen thematic object**. Tapping it grants **+1 XP** with floating
"+1" feedback, a small object animation, and optional haptics. Active tapping is the primary
driver of early progress.

### 3.2 Passive — "Training Slots" (idle, app open)
Assign a skill to a **training slot** to earn passive XP while the app is in the foreground.

- A skill must reach **level 10** before it can be slotted (gives early tapping a purpose).
- Passive rate: **1 XP / second** per slotted skill.
- **Slots unlock with total level:** 1 slot at the start → **2nd slot at total 50** →
  **3rd slot at total 150**.

### 3.3 Energy & Supercharge (idle, app open *and* closed)
Each slotted skill accumulates **Energy** in real time — whether the app is open or closed.

- Conversion: **1 minute of elapsed time = 1 second of Supercharge**, capped at **30
  seconds** (so 30 minutes fully charges a skill).
- Tap **Supercharge** to spend all banked Energy. For that many seconds, taps on that skill
  grant **bonus XP per tap**:

  | Supercharge tier | XP / tap | Unlocks at total level |
  |------------------|----------|------------------------|
  | I   | **2**  | 0 (start) |
  | II  | **5**  | 100 |
  | III | **10** | 300 |
  | IV  | **20** | 500 |

This creates the signature **return-and-burst loop**: idle to bank Energy, come back, and
tap furiously during the Supercharge window. Passive XP keeps trickling during a Supercharge;
only *taps* get the multiplier.

## 4. Progression arc (1 → maxed)

- **Early (total 10–50):** Tap skills to level 10 to unlock slotting. Start the first passive
  slot. Learn Supercharge on the first return.
- **Mid (total 50–300):** Unlock slot 2 (50) and slot 3 (150). Reach Supercharge tier II
  (100). Juggle three passive skills + active tapping + Supercharge bursts.
- **Late (total 300–990):** Supercharge tiers III (300) and IV (500). Grind the brutal OSRS
  tail. Milestones: first 99 → all combat 99 → all gathering 99 → **max (990)**.

## 5. Screens & UX

1. **Splash** — brief branded loader.
2. **Onboarding** (first launch, 4 short cards) — goal, tap-to-train, slots+Energy,
   Supercharge. Energy/Supercharge detail is reinforced contextually on the first slot.
3. **Home / Skills grid (hub)** — top bar with total level, max-cape progress, and slots
   used; a 2-column grid of skill tiles (icon, level, XP bar, slot badge, Energy ring,
   "Supercharge ready" glow). Toolbar → Stats and Settings.
4. **Skill Training (full screen)** — the big tappable object; header with level + XP-to-next
   bar; slot toggle (enabled at level 10); Energy meter + **Supercharge** button with live
   countdown and active multiplier.
5. **Stats / Milestones** — total level, per-skill levels, unlock thresholds, and a milestone
   checklist.
6. **Settings** — haptics/sound toggles, reset progress, about + OSRS-inspired disclaimer.

## 6. Visual & audio direction

Dark, cozy "parchment + rune" palette. Each skill has a signature tint and an emoji glyph as
its v1 trainable object (designed to be swapped for custom art later). Feedback is juicy:
floating XP numbers, object bounce, level-up flash, and haptics. Audio hooks are stubbed for
v1 _(future: tap/level/supercharge SFX)_.

## 7. Technical architecture

- **SwiftUI**, iOS 17+, portrait iPhone, MVVM.
- Single source of truth: `GameState` (`ObservableObject`) holds XP, slots, Energy, and
  Supercharge timers; exposes derived values (level, total level, max slots, current tier).
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
| Passive XP rate | 1 XP / sec / slotted skill |
| Energy charge rate | 1 sec Supercharge per 60 sec real time |
| Energy cap | 30 sec Supercharge (30 min real) |
| Slot eligibility | skill level ≥ 10 |
| Slot 2 / Slot 3 unlock | total level 50 / 150 |
| Supercharge tiers | 2 / 5 / 10 / 20 XP-per-tap at total 0 / 100 / 300 / 500 |
| Double XP boost | 2× all XP for 10 min; 1 free coupon/day; IAP packs of 5 / 25 / 100 |

## 9. Professional critique (indie-dev self-review)

**Strengths**
- Clean, legible core loop (tap ↔ idle ↔ Supercharge burst). The Supercharge mechanic is a
  strong retention hook that elegantly bridges active and idle play.
- Proven, satisfying long-tail progression from the real OSRS curve.
- Scope is realistic for a v1.

**Risks & mitigations**
1. **Endgame pacing is the biggest risk.** The OSRS tail is punishing and v1 yields are
   deliberately small, so a full max would take an unrealistic amount of time. *Mitigation:*
   ship the loop intact; treat yield-scaling as the first balance patch — trivial because all
   constants are centralized.
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
