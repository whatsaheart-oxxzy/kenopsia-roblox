# Kenopsia — design document

> *kenopsia (n.) — the eerie atmosphere of a place that is usually busy, now empty.*

A competitive party game for **2–8 players**. A derelict industrial Machine issues orders. You obey, you submit, you are scored. Five programs per cycle, highest total wins.

---

## Provenance

The structure is adapted from a Steam game called **Machine Party**, studied from a 21-minute showcase video. What carries over is the *shape*: a central Machine that barks imperative verbs, themed rooms per task, and a submit-and-be-graded loop.

What deliberately does **not** carry over:

- **The gore.** The source is soaked in blood. Roblox moderates that hard and it caps the audience for no design gain. Violence is reskinned as industrial — oil, steam, grinding machinery, pressure.
- **The art, names, icons, and rooms.** Mechanics aren't protectable; specific expression is. Every asset here comes from CC0 PSX packs already owned (see `ASSETS.md`), and every name is original.

---

## The core loop

```
Lobby ──▶ Intermission ──┬──▶ Announce ──▶ Load ──▶ Countdown ──▶ Play ──▶ Score ──┐
                         │                                                          │
                         └──────────────── × 5 rounds ◀─────────────────────────────┘
                                                    │
                                                    ▼
                                                 Results ──▶ Lobby
```

The **Machine** is the connective tissue. Between rounds a CRT names the next program (`MEMORIZE`, `CROSS`, `SUBMIT`) and a marquee scrolls the verb. Every minigame is framed as an instruction from the same authority, which is what makes three unrelated mechanics read as one game.

### The shared vocabulary — the most important decision in the project

RECALL and THE LINE draw from the **same icon list** (`src/shared/IconPool.luau`). The Machine shows you a symbol; later you are carrying the physical object that symbol meant.

Players build **one mental dictionary** and use it everywhere. This is the difference between a game and a menu of modes. Preserve it when adding minigame #4.

---

## The three launch minigames

Chosen for *engineering risk*, not coolness. Each proves a different capability of the framework.

### 1. RECALL — `MEMORIZE`
A 5×3 grid of industrial symbols. Study it for 7 seconds. The Machine blanks some cells; put the right symbols back.

- **Difficulty ramp:** 3 blanks in round 1 → 7 by round 5.
- **Scoring:** 100 per correct cell.
- **Proves:** the round contract end-to-end with almost nothing that can break. Pure UI, no physics.
- **Security:** the answer key never leaves the server. Clients get the masked grid plus a shuffled candidate tray of correct answers mixed with decoys. Full memory access still can't tell you which is which.

### 2. THE GRATE — `CROSS`
A 6×24 floor of pads. The safe path flashes for 2 seconds, then goes dark. Step wrong and you're out for the round — and the pad you died on lights red **for everyone**.

- **Design:** each row has 2 safe pads. One continues the true path; the other may dead-end. Mercy for players who lost the path, punishment for players who trust it blindly.
- **Scoring:** 25/row reached, +200 for finishing.
- **Proves:** spatial gameplay fits the same contract as a UI game.
- **Why 8 players is funnier than 2:** watching someone else find a bad tile is the best information in the game.

### 3. THE LINE — `SUBMIT`
The Machine wants five things. **There is exactly one of each.** Find it, carry it, submit it before someone takes it from under you.

- **Scoring:** 150/pedestal, +100 for closing out the last one. Wrong submission = 2s lockout.
- **Proves:** item and interaction gameplay fits the contract.
- **Design warning:** scarcity *is* the game. If you're ever tempted to "fix" the frustration of someone grabbing the part you needed — don't. That frustration is the product.

### Deliberately deferred
The scoped spotting range (raycast + fog + a lot of feel-tuning), the dinner table (animation-heavy, and the moderation problem child), the conveyor interior (physics-heavy, low payoff).

---

## Architecture

Every minigame implements one four-method contract (`src/shared/Types.luau`):

```lua
Setup(ctx)   -- build the arena, prepare state, start no timers
Start()      -- begin play; NON-BLOCKING
Stop()       -- end play, return { [Player]: score }
Cleanup()    -- tear down; must be safe to call twice
```

`RoundService` only ever calls those four and never learns what a minigame *is*. **Adding minigame #4 is one new file plus one `require` in `MinigameRegistry.luau`.** Nothing else changes.

```
src/
  server/                     → ServerScriptService.Kenopsia
    init.server.luau            boot order: Net → State → RoundService
    RoundService.luau           the state machine (the spine)
    ArenaService.luau           arena lookup, teleport, freeze, runtime cleanup
    ScoreService.luau           match scoring (no DataStore yet — that's Phase 5)
    MinigameRegistry.luau       the list; the only file you edit to add a game
    minigames/
      Recall.luau  Grate.luau  Line.luau
  shared/                     → ReplicatedStorage.KenopsiaShared
    Config.luau                 every tunable in the game
    Types.luau                  the minigame contract
    Net.luau                    all remotes + rate limiting, in one list
    State.luau                  replicated round state (attributes)
    IconPool.luau               the shared vocabulary ← paste asset ids here
  client/                     → StarterPlayerScripts.KenopsiaClient
    init.client.luau  HUD.luau  RecallUI.luau
```

### Engineering rules held throughout

- **The minigame never owns the clock.** `RoundService` starts it, waits `Duration`, stops it. A minigame that decides when its own round ends can hang the match, and a hung match on a live server needs a shutdown to fix.
- **Every phase is wrapped in `pcall`.** An error in RECALL must not stop the server from ever running GRATE again.
- **No ticking timer is ever replicated.** The server publishes one absolute end time per phase; clients count down locally against `workspace:GetServerTimeNow()`. One attribute write per phase instead of 60/sec/player, and the countdown stays smooth at any ping.
- **`.Touched` is not used for the tile game.** It drops contacts on fast movers and fires from client physics. THE GRATE samples authoritative positions on a fixed 15 Hz server tick and converts to a grid cell with arithmetic — O(1) per player, no spatial query.
- **Authority is an attribute, never a part's position.** In THE LINE, `Player:GetAttribute("Carrying")` is the truth. The model welded to your hand is cosmetic. An exploiter can fling it anywhere; submissions validate against the attribute.
- **`ProximityPrompt` over custom remotes.** Prompts fire `.Triggered` on the server with a built-in distance check — no new remote to rate-limit, no reach extension to defend.
- **Seeded RNG everywhere.** `Random.new(seed)`, seed logged per round. You will want this the first time you have to reproduce a bug.
- **Art never blocks code.** Missing arena → generated placeholder. Missing model → labelled block. Missing icon → text label. The game is fully playable with zero assets imported.

---

## Build phases

| Phase | Scope | Status |
|---|---|---|
| **0** | Foundation: Rojo project, shared layer, round state machine, lobby↔arena flow, HUD | ✅ **done** |
| **1** | The Machine hub: console, marquee, announce CRT, per-arena scriptable camera | ⬜ next |
| **2** | RECALL | ✅ code done — needs icons imported |
| **3** | THE GRATE | ✅ code done — needs arena shell |
| **4** | THE LINE | ✅ code done — needs models + arena shell |
| **5** | DataStore persistence, match history | ⬜ |
| **6** | Audio, post-processing, animation, lighting pass | ⬜ |
| **7** | Playtest, moderation self-audit, publish unlisted → public | ⬜ |

> **Phase 0 exit criteria, and it is worth honouring:** the loop runs 30 minutes unattended, with players joining and leaving mid-round, without desyncing or soft-locking. Every rushed party game dies here.

---

## Getting it running

```bash
cd "C:\Users\Asus\Claude\Kenopsia_Roblox Project"
rojo serve
```

Then in Studio: **Plugins → Rojo → Connect**.

**Studio setup that isn't in code:**
1. **Home → Game Settings → Basic Info → Max Players = 8.** There's no scriptable equivalent; `init.server.luau` warns loudly if it's wrong, because THE LINE's scarcity tuning assumes that ceiling.
2. **Lighting → Technology = Voxel**, low Brightness, tight FogEnd. Future/ShadowMap lighting fights the PSX look.
3. Build `Workspace.Arenas` with Models named `lobby`, `recall`, `grate`, `line`, each containing an anchored invisible Part named `Origin`. Until then, placeholders generate automatically.

Test with 2+ players: **Test → Clients and Servers → 2 players → Start**. The loop won't leave the lobby with fewer than `Config.MinPlayers`.

### Verification gates

All three must pass before any change is considered done:

```bash
aftman install                                    # first time only

StyLua --check src
rojo build --output /tmp/check.rbxl
rojo sourcemap default.project.json --output sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --base-luaurc=.luaurc src
```

`globalTypes.d.luau` is gitignored — on a fresh clone, download it first or analysis produces ~450 lines of fake `Unknown global 'game'` errors:

```bash
curl -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
```

---

## Open questions

- **Round count.** 5 rounds × ~60–90s ≈ 6–8 min/match. Worth playtesting against 3 rounds — Roblox session lengths reward shorter cycles.
- **Elimination vs. scoring in THE GRATE.** Currently you're out for the round but still score for distance. If early deaths feel dead-ended, consider a respawn-at-checkpoint variant.
- **Minigame #4.** The scoped spotting range is the natural next one — it's the only vertical, ranged, non-melee verb in the set.
