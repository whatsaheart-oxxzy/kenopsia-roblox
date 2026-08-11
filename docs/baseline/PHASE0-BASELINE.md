# Phase 0 baseline — Kenopsia release candidate

Captured from the live Studio place, read-only. No Studio mutation was performed.

## Provenance

| Field | Value |
|---|---|
| Place ID | `110672791536316` |
| Place name reported by plugin | `Place1` (does **not** match the plan's `iLoveKilIs's Place: 08062026_3`; identity confirmed by the user and corroborated structurally) |
| Studio version | `0.733.0.7330989` |
| Studio state | `edit` (source: `runService`) |
| Bridge | `weppy-roblox-mcp` 2.12.2, target `studio-1`, client `1ce95788-8fcf-4029-aa7d-bf6000749ac2` |
| Licence tier | `basic` / unlicensed — `execute_luau`, `workspace_state`, `manage_sync`, `place_info` are PRO-gated and unavailable |
| Backup | `C:\Users\Asus\Documents\Retro\Kenopsia_Backup (Main MiniGame).rbxl`, 2,903,038 bytes, 2026-08-11 20:40:44 |

Every MCP call was pinned with `placeId: 110672791536316`, which hard-fails rather than
falling back to another place. All 30+ responses echoed
`requestedPlaceId == actualPlaceId`.

## Script mirror

19 of 19 `LuaSourceContainer` instances exported to `studio-src/`, path-faithful to the
place hierarchy, Rojo suffix convention (`.server.luau` / `.client.luau` / `.luau`).

| Studio path | Class | Lines |
|---|---|---|
| `ReplicatedFirst.KenopsiaLoading` | LocalScript | 122 |
| `StarterPlayer.StarterPlayerScripts.KenopsiaClient` | LocalScript | 1954 |
| `StarterPlayer.StarterPlayerScripts.XBotAnimSync` | LocalScript | 233 |
| `StarterPlayer.StarterPlayerScripts.MachineLayout` | LocalScript | 336 |
| `StarterPlayer.StarterPlayerScripts.GoreClient` | LocalScript | 431 |
| `StarterPlayer.StarterCharacterScripts.Health` | Script | 3 |
| `StarterPlayer.StarterCharacter.Animate` | LocalScript | 1 |
| `ReplicatedStorage.KenopsiaAssets.Effects.Blood.BloodEffect` | ModuleScript | 221 |
| `ReplicatedStorage.Kenopsia.Shared.Config.GameConfig` | ModuleScript | 25 |
| `ReplicatedStorage.XBotAnimations.PublishedIds` | ModuleScript | 14 |
| `ReplicatedStorage.XBotAnimations.SequencePlayer` | ModuleScript | 238 |
| `ServerScriptService.KenopsiaServer.Main` | Script | 12 |
| `ServerScriptService.KenopsiaServer.XBotCharacters` | Script | 275 |
| `ServerScriptService.KenopsiaServer.Services.RoomService` | ModuleScript | 393 |
| `ServerScriptService.KenopsiaServer.Services.MachineFlow` | ModuleScript | 300 |
| `ServerScriptService.KenopsiaServer.Services.BirdHunting` | ModuleScript | 703 |
| `ServerScriptService.KenopsiaServer.Services.Minefield` | ModuleScript | 574 |
| `ServerScriptService.KenopsiaServer.Services.TableManners` | ModuleScript | 259 |
| `ServerScriptService.KenopsiaServer.Services.BloodFX` | ModuleScript | 169 |

Totals: **6,263 lines, 201,273 bytes**, all LF, zero CR bytes.

### Verification level achieved — ZERO-DIFF CONFIRMED

| Check | Result |
|---|---|
| Line-count parity vs Studio `lineCount` | **19/19 pass** |
| CR bytes present | **0** (pure LF, matching Studio) |
| **SHA-256, Studio source vs local file** | **19/19 identical — 0 differences** |
| WEPPY Luau validation (`manage_scripts validate`) | **19/19 `status = valid`**, Roblox parser 0.730, **0 diagnostics** |

The byte-level zero-diff gate of plan Phase 0 step 7 is **satisfied**. The mirror is
authoritative and may back a Rojo mapping.

The Luau validation proves **syntax validity only**. Semantic/static analysis is a
separate gate — see "Static analysis" below.

## Instance manifest — COMPLETE

Full hierarchy with depth limits stated per section:
[`INSTANCE-MANIFEST.md`](INSTANCE-MANIFEST.md). Highlights below.

### `Workspace` — 13 children

`CanteenProtocol` (Folder), `Dead Zone` (Folder), `Bird Hunting` (Folder), `Terrain`,
`Camera`, `Baseplate` (Part), `Scene` (Model), `tape_worm` (Decal), `gear_mx_1` (Model),
`saw_blade` (Model), `Sneak Walk` (Model), `Injured Walking` (Model), `Zombie Crawl` (Model).

The last three are animation-source rigs sitting in the live Workspace.

### `Workspace.CanteenProtocol` — 78 children

Set dressing only: `Canteen_table_large_3`, `Canteen_Mesh_Table_Rectangle_01`,
6 × `Canteen_chair_wooden_1`, 8 × `Floor lamp`, 4 × `Canteen_Mesh_Cups_01`,
6 × `Canteen_Mesh_Drinks_01`, 12 × `Canteen_canned_food_4`, `Canteen_canned_food_3`,
8 × `Canteen_mre_1`, 7 × `Canteen_Mesh_Packaging_01`, 5 × `Canteen_trash_1`,
`Canteen_Mesh_Trolley_01`, `Canteen_Mesh_Trolley_04`, `Canteen_metal_shelf_1`,
4 × `Wall`, `Ceiling`, `Door Ceilin`, `Floor Canteen Protocol`,
8 × `Plate` (all identically named), `Camera for Canteen`.

**None** of the hierarchy the plan requires exists: no `Seat01..04`, no `Plate01..04`,
no `PeaAnchor01..04`, no `Camera02/03/04`, no `TableFocus`, no `Inspector`.

### Runtime-created remotes — absent in Edit

`ReplicatedStorage.Kenopsia` has exactly one child at rest: `Shared`. There is **no
`Remotes` folder in the saved place**. All 15 remotes are created at runtime by
`RoomService.ensureRemotes()` (8), `MachineFlow.start()` (`MachineState`),
`BirdHunting.ensureRemote()` (`SniperFire`, and `SniperAim` as an
**UnreliableRemoteEvent**), `Minefield.init()` / `TableManners.init()` (`TrialInput`,
whichever runs first), `BloodFX` boot (`GoreEvent`), and `XBotCharacters`
(`XBotPush`, `XBotCrouch`). Any later manifest diff must expect them to appear only
after a server boot.

### Other observed counts

`SoundService.KenopsiaAudio` 50 descendants, `StarterGui` 529, `ServerStorage.KenopsiaAssets`
40, `Lighting` 1 (`KenopsiaSky`). `Players.MaxPlayers = 60`.

## Runtime asset IDs found in source (asset-ledger seed)

Animations (`ReplicatedStorage.XBotAnimations.PublishedIds`) — provenance unverified:

`Idle 85677606246468`, `Walk 120444870216482`, `Run 122795638856363`,
`CrouchWalk 113663200701243`, `Jump 72948522195534`, `Punch 113738141694741`,
`SweepFall 124407808671429`, `StandUp 75643901941236`, `Sit 131818913727408`,
`SniperAim 77238131923469`.

Bird audio is referenced by name (`SniperFire`, `SniperReload`, `BulletRicochet`,
`ImpactBody`, `Blood`) through `SoundService.KenopsiaAudio.SFX`, not by literal ID in
source; the three `.ogg` masters live in `release/bird-hunting-audio/`.

`PublishedIds` contains no clip for the `Injured`, `Crawl`/`CrawlIdle`, or `SneakWalk`
states that `XBotCharacters` emits — those are driven by `KeyframeSequence` children of
`ReplicatedStorage.XBotAnimations` via `SequencePlayer`, not by asset ID. In fact
`SequencePlayer` resolves every clip by KeyframeSequence *name*, so `PublishedIds` is
not on the runtime path at all.

---

## Static analysis

Tool: **selene 0.31.0**, pinned in `aftman.toml`. Config: `selene.toml`, `std = "roblox"`
(generated via `selene generate-roblox-std`). Scope: **`studio-src` only** — the legacy
prototype under `docs/legacy/src` is not shipping code and is not analysed.

Full output: [`selene-report.txt`](selene-report.txt).

```
0 parse errors
5 errors
22 warnings
```

Adjudication of the 5 errors — **none is a genuine new defect**:

| Finding | Location | Verdict |
|---|---|---|
| `incorrect_standard_library_use`: `CFrame.identity` has no field `Lerp` | `SequencePlayer.luau:165` | **False positive.** selene's Roblox std models `CFrame.identity` as a namespace field rather than a CFrame value. `CFrame.identity:Lerp(pose, w)` is valid at runtime. |
| `if_same_then_else` ×4 | `XBotAnimSync:209`, `KenopsiaClient:652`, `:655`, `:892` | **Benign by design.** Each is a deliberate multi-input branch (mouse *or* gamepad button producing the same action). |

Substantive warnings:

- **`unscoped_variables`: `current` is not declared locally** — `Minefield.luau:273`.
  Independent confirmation of the implicit-global defect. Deferred to its
  implementation phase (see register below).
- `unused_variable` ×21, incl. `activeByUser` (declared, never used in `Minefield`),
  `RunService` in `MachineFlow`, `ReplicatedStorage` in `KenopsiaLoading`.

Style lints (`multiple_statements`, `roblox_manual_fromscale_or_fromoffset`,
`mixed_table`) are disabled: `studio-src` is a byte-exact export, so those would only
flag the original author's house style, and "fixing" them would break the zero-diff.

---

## Rojo / legacy-source defusal

**Archived recoverably** to `docs/legacy/` (moved, not deleted; all committed to git):

| Was | Now |
|---|---|
| `src/` (old prototype: `src/shared`, `src/server`, `src/client`) | `docs/legacy/src/` |
| `DESIGN.md` | `docs/legacy/DESIGN.md` |
| `ASSETS.md` | `docs/legacy/ASSETS.md` |
| `default.project.json` (old mapping) | `docs/legacy/default.project.json.legacy` |

The archived mapping pointed `ReplicatedStorage.KenopsiaShared → src/shared`,
`ServerScriptService.Kenopsia → src/server`, and
`StarterPlayer.StarterPlayerScripts.KenopsiaClient → src/client`. That last node is the
concrete hazard: the live place has a **LocalScript** named `KenopsiaClient` at exactly
that path, so a sync would have replaced the real 1,954-line client with a folder built
from the dead prototype.

**New mapping** (`default.project.json`) is path-faithful to `studio-src` and binds
**leaves only**. Every container (`Kenopsia`, `Shared`, `Config`, `KenopsiaAssets`,
`Effects`, `Blood`, `XBotAnimations`, `KenopsiaServer`, `Services`,
`StarterPlayerScripts`, `StarterCharacterScripts`, `StarterCharacter`) is declared with
`$className` and **no `$path`**, so Rojo owns exactly the 19 script instances and never a
content folder. Container class names were each verified against the live place before
being written — `StarterCharacter` is a `Model` (holds the XBot rig) and `Blood` is a
`Folder` holding six `ValueBase` config objects that `BloodEffect` reads via
`script.Parent`; a folder-level `$path` on either would have destroyed live content.

Offline validation (does not touch Studio):

```
rojo build default.project.json -o <temp>.rbxlx
→ exit 0, 207,904 bytes
→ 3 Script + 6 LocalScript + 10 ModuleScript = 19   (exact class-by-class match)
```

**Rojo has not been connected to Studio and must not be until a human reviews this
mapping.** `rojo build` proves the project is well-formed and every path resolves; it
does not prove reconciliation behaviour against the live tree.

### Separate `cafe-chaos` project — do not cross the streams

`C:\Users\Asus\Roblox Project` is an **unrelated game** (`"name": "cafe-chaos"`) whose
`default.project.json` maps its own `src/` onto `ServerScriptService`,
`ReplicatedStorage` and `StarterPlayer`. It has been left untouched.

> **Never launch `rojo serve` from `C:\Users\Asus\Roblox Project` while the Kenopsia
> place is open in Studio.** The Rojo Studio plugin connects to whatever server is on
> the port; a cafe-chaos server would overwrite Kenopsia's server, shared and client
> trees with a different game.

---

## Rollback procedure (approved fallback — no WEPPY Pro required)

ChangeHistoryService waypoints need `execute_luau`, which is PRO-gated. The approved
substitute, to be followed for every phase that touches Studio:

1. **Keep the verified baseline `.rbxl`.**
   `C:\Users\Asus\Documents\Retro\Kenopsia_Backup (Main MiniGame).rbxl` — 2,903,038 bytes,
   2026-08-11 20:40:44. Do not overwrite it; new backups get new dated filenames.
2. **Clean git commit before every phase.** `git status` must be clean (or show only
   intended, reviewed changes) before the first mutation of a phase.
3. **Dated manual backup before any phase that changes Studio instances.**
   File → Save to File As → `Kenopsia_<phase>_<YYYY-MM-DD>.rbxlx`. This is a human step;
   no MCP equivalent exists. The phase does not start until the file is verified on disk.
4. **Re-read every modified script in full after writing it.** After any
   `manage_scripts set_source` / `edit_replace`, re-fetch the whole script with
   `get_source` and compare against intent — never trust the write's return value alone.
5. **Re-verify SHA-256 parity** between `studio-src` and Studio at the end of each phase,
   so the mirror never silently drifts from the live place.
6. **Pin every MCP call to `placeId: 110672791536316`.** It hard-fails rather than
   falling back to another Studio instance.

---

## Deferred requirements register

Recorded here, **not repaired during Phase 0**. Each carries into its implementation
phase and that phase's acceptance gate.

| ID | Requirement | Evidence |
|---|---|---|
| `REQ-DZ-01` | `current` must become per-round scoped state; remove the implicit global | `Minefield.luau:273`; selene `unscoped_variables` |
| `REQ-DZ-02` | Replace replicated mine `Part`s with pure server records | `Minefield.runRound` creates `Part` per mine |
| `REQ-DZ-03` | Trial cleanup must not call global `BloodFX.clear()` | `Minefield.luau` cleanup |
| `REQ-DZ-04` | Collapse `kill` + `shatter` double invocation into one bounded effect | `Minefield.explode` |
| `REQ-DZ-05` | Crusher 42.0 s traversal / 0.5 s grace; derive direction from markers | current `SHRED_SPEED 4.5`, `SHRED_GRACE 1.5` |
| `REQ-DZ-06` | Sonar radius 9; remove the sonar-free `CLEANRUN_BONUS` | current `SCAN_RADIUS 8`, `CLEANRUN_BONUS 20` |
| `REQ-BH-01` | Hidden leg cap 40 s | current `ROUND_TIME = 150` |
| `REQ-CP-01` | Canteen arena hierarchy (`Seat01..04`, `Plate01..04`, `PeaAnchor01..04`, `Camera02..04`, `TableFocus`, `Inspector`) | none exist |
| `REQ-CP-02` | `refs()` must resolve `Workspace.CanteenProtocol` (current lookup names never match) | `TableManners.refs()` |
| `REQ-CP-03` | Replace beat/Perfect/Good/stress mechanic with plate→mouth + observer | `TableManners`, `KenopsiaClient` HUD, `MachineLayout` Page2 |
| `REQ-CP-04` | Original Canteen audio must exist and load before `ready = true` | no `tablemanners` music, no Canteen SFX |
| `REQ-REG-01` | Declarative trial registry with a real `ready` flag; all three trials registered | `MachineFlow.TRIALS` has 2 entries, no `ready` field |
| `REQ-REG-02` | **Canteen stays out of the roulette until fully implemented and explicitly marked ready** | currently excluded — preserve this |
| `REQ-CAP-01` | Reconcile server capacity to 4 | plan 4 / `GameConfig` 28 / live `Players.MaxPlayers` **60** |
| `REQ-FX-01` | Gore budget 48 desktop / 24 mobile at 30 Hz, distance-culled, cached raycast exclusions | `MAX_DROPLETS 140`, Heartbeat-rate, `refreshRayFilter()` per frame |
| `REQ-FX-02` | Remove global screen blood and the fountain in `shatter` | `GoreClient.screenBlood`, `fountain` |
| `REQ-IP-01` | Remove source-referencing comments and UI strings | `Machine-Party-Remake` ×2, `Machine-Party-Look`, `Kastrierer` ×5 **plus a live instance named `Kastrierer`**, `BOOM HEADSHOT` comment + UI string, `HIT` UI string |
| `REQ-IP-02` | Resolve provenance for the sniper rifle model, Bird music, and the 12 XBot KeyframeSequences | asset ledger seeded, unverified |

Note: `release/bird-hunting-audio/*.ogg` is gitignored, so the licensed audio masters
are **not** in version control. They exist only on disk and inside the `.rbxl` backup.

---

## Corrected Gate 1 — Phase 0 blockers only

| # | Phase-0 blocker | Result |
|---|---|---|
| 1 | Authoritative mirror verified | **PASS** — 19/19 SHA-256 identical, 0 differences |
| 2 | Legacy source cannot overwrite Studio | **PASS** — legacy archived to `docs/legacy`, new leaf-only mapping, Rojo not connected, cafe-chaos hazard documented |
| 3 | Syntax and static analysis pass | **PASS** — 0 parse errors; 19/19 WEPPY `valid`; selene's 5 errors adjudicated as 1 std false positive + 4 intentional branches |
| 4 | Complete manifest exists | **PASS** — `INSTANCE-MANIFEST.md`, depth limits stated |
| 5 | Rollback procedure exists | **PASS** — recorded above, no Pro licence required |
| 6 | Phase-0 artifacts committed | **PASS** |

**GATE 1: PASS.** Gameplay defects are recorded in the register above and are explicitly
out of scope for Phase 0.
