# Sound design

XP Waste ships a small, cohesive set of **original, OSRS-*inspired*** sound effects. They evoke
the *spirit* of famous Old School RuneScape moments — the level-up jingle, chopping wood, mining
ore, coins, bank chests, prayer chimes — **without sampling or copying any Jagex audio**. Every
clip is synthesized from scratch by [`Tools/sound_synth.py`](../Tools/sound_synth.py), which keeps
us clear of copyright and makes the whole palette reproducible and tweakable.

## Shipped cues (event → sound)

The active picks, loaded by [`SoundManager`](../Sources/Models/SoundManager.swift):

| Game moment | Bundled cue | OSRS inspiration |
|-------------|-------------|------------------|
| Every training tap | `sfx_tap.wav` | Crisp interface **click** — short, non-fatiguing for the core loop |
| Skill **levels up** | `sfx_levelup.wav` | Soft two-note **confirm chime** |
| **Supercharge** burst | `sfx_supercharge.wav` | Rising whoosh into a power chord — **Special Attack** energy |
| **Energy Cell** recharge | `sfx_energycell.wav` | Charged hum + zap — a battery / **charge orb** |
| **Daily Boost** (Double XP) | `sfx_doublexp.wav` | Ascending magical bells — a **teleport / enchant** power-up |
| **Purchase** grant lands | `sfx_purchase.wav` | Register ding + sparkle — **purchase confirmed** |
| Open a panel (Stats/Boosts/Settings) | `sfx_ui.wav` | Soft two-tone **tab blip** |

All cues are 44.1 kHz, 16-bit mono WAV in `Sources/Resources/Sounds/`. XcodeGen bundles everything
under `Sources/`, so the files land in the app bundle root and load by name.

## Audio engine — `SoundManager`

`Sources/Models/SoundManager.swift` is a `@MainActor` singleton (`SoundManager.shared`) that:

- Pre-decodes each cue into a **small pool of `AVAudioPlayer`s** (5 voices for the tap, 2 for the
  rest) so rapid, overlapping triggers — fast tapping, or a level-up firing over taps — layer
  instead of cutting each other off.
- Uses the **`.ambient`** audio-session category with `.mixWithOthers`, so playback respects the
  hardware **mute switch** and mixes politely with the player's own background music.
- Applies a per-cue **volume trim** (`Sound.volume`) so the palette sits at an even perceived
  loudness (bright short cues like tap/ui are pulled down).
- Is warmed up once at launch via `prepare()` (called from `XPWasteApp.task`) to avoid a first-tap
  decode hitch.

Playback is gated on `GameState.soundEnabled`, mirroring how views gate `.sensoryFeedback` on
`hapticsEnabled`. Call sites pass the flag through:

```swift
SoundManager.shared.play(.tap, enabled: game.soundEnabled)
```

Triggers live next to their existing haptics: taps/Supercharge/Energy Cell in `SkillTrainingView`,
Daily Boost/Energy Cell in `BoostsView`, the level-up cue in `RootView` (on `levelUpEvent`), the
purchase cue in the `Store.onGrant` callback (`XPWasteApp`), and the interface cue on the Home
toolbar buttons. The Settings **Sound effects** toggle enables/disables the whole layer and plays a
preview blip when switched on.

> Auto-taps (Runecraft's perk) intentionally stay **silent** — only the player's own taps click.

## Regenerating or re-picking cues

The generator is deterministic (fixed RNG seed), so re-running reproduces byte-identical output.

```sh
# numpy is the only dependency
python3 -m venv .venv && ./.venv/bin/pip install numpy

# 1) Audition set — writes EVERY option (A/B/C/D per event) to ./sounds/
./.venv/bin/python Tools/sound_synth.py

# 2) Install the CHOSEN options into the app bundle (Sources/Resources/Sounds/sfx_*.wav)
./.venv/bin/python Tools/sound_synth.py --install
```

To review options, open the generated `sounds/` folder (or drop an `index.html` audio board in it)
and listen. To **change a pick**, edit the `CHOSEN` map at the top of `Tools/sound_synth.py`
(option name → shipped cue name) and re-run with `--install`. To **design a new cue**, add a
`save('my_option', …)` in `build()` using the synthesis helpers (oscillators, ADSR, filters, bell,
reverb, sparkle), then point a `CHOSEN` entry at it and, if it's a new event, add a `Sound` case in
`SoundManager` plus a `play(...)` call at the trigger site.

The audition output (`Tools/sounds/`) is git-ignored — only `Sources/Resources/Sounds/` ships.
