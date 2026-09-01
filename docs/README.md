# XP Waste — documentation

Project documentation lives here. The [root `README.md`](../README.md) is reserved for
**players** (what the game is and how to play). Everything about design, engineering, setup, and
app logistics lives in this folder.

| Doc | What it covers |
|-----|----------------|
| [GAME_DESIGN.md](GAME_DESIGN.md) | Full game design document — vision, skills, mechanics, progression, balance tables, and the indie-dev critique. |
| [RAID_SYSTEM.md](RAID_SYSTEM.md) | Raid system design — each raid a three-room boss expedition (warm-up → mini-boss → tougher final boss), shared timer + raid HP, **twelve distinct room mechanics (none reused)**, native in-mechanic boss threats incl. the red/green combat duel, boss phases/enrage, tier scaling, the flawless Token bonus, and the XP-lamp reward. |
| [SKILL_BUFFS.md](SKILL_BUFFS.md) | The 23 unique account-wide skill perks — per-skill lever table, designed synergies, scaling model, and the tap "hit" pipeline. |
| [ACHIEVEMENTS.md](ACHIEVEMENTS.md) | Design proposal for the **Diary** — Tasks, Reward Tokens, the Reward Vault (XP Lamps + capes), the Collection Log, and how IAP expedites/unlocks it. |
| [SOUND_DESIGN.md](SOUND_DESIGN.md) | The OSRS-inspired sound palette — event → cue mapping, the audio engine (`SoundManager`), the generator (`Tools/sound_synth.py`), and how to regenerate or re-pick cues. |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Engineering setup: requirements, build & run, project layout, architecture, tuning, StoreKit/IAP testing, and debug hooks. |
| [../.github/copilot-instructions.md](../.github/copilot-instructions.md) | Guidance for AI coding agents working in this repo (conventions, universal-app rules, doc layout). |

## Documentation convention

- **`README.md` (root) is strictly player-facing.** Keep it to how the game works and how to
  play — no build steps, architecture, setup, or design internals.
- **All other docs live under `docs/`** (or their own folders), each in its own file. When you
  add design, development, setup, or logistics documentation, put it here and link it from this
  index — do not grow the root README.
