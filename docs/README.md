# Idle Skiller — documentation

Project documentation lives here. The [root `README.md`](../README.md) is reserved for
**players** (what the game is and how to play). Everything about design, engineering, setup, and
app logistics lives in this folder.

| Doc | What it covers |
|-----|----------------|
| [GAME_DESIGN.md](GAME_DESIGN.md) | Full game design document — vision, skills, mechanics, progression, balance tables, and the indie-dev critique. |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Engineering setup: requirements, build & run, project layout, architecture, tuning, StoreKit/IAP testing, and debug hooks. |
| [../.github/copilot-instructions.md](../.github/copilot-instructions.md) | Guidance for AI coding agents working in this repo (conventions, universal-app rules, doc layout). |

## Documentation convention

- **`README.md` (root) is strictly player-facing.** Keep it to how the game works and how to
  play — no build steps, architecture, setup, or design internals.
- **All other docs live under `docs/`** (or their own folders), each in its own file. When you
  add design, development, setup, or logistics documentation, put it here and link it from this
  index — do not grow the root README.
