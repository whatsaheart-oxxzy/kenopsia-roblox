# Phase 1 — canonical server/session architecture

Place `110672791536316`, Studio in **Edit** throughout (preflight
`studio.state = edit`, `place_identity` placeId/gameId `10640788131`,
placeVersion 335). Every MCP call pinned to the placeId. Rojo never connected.

Pre-change backup: the verified Phase 0 baseline
`C:\Users\Asus\Documents\Retro\Kenopsia_Backup (Main MiniGame).rbxl`
(2,903,038 bytes, 2026-08-11 20:40:44) — **not overwritten**.

## Changed instances — 3, all edited in place

| Instance | Class | Lines before → after | sessionDebugId |
|---|---|---|---|
| `ReplicatedStorage.Kenopsia.Shared.Config.GameConfig` | ModuleScript | 25 → 46 | `1_16765` (unchanged) |
| `ServerScriptService.KenopsiaServer.Services.RoomService` | ModuleScript | 393 → 461 | `1_16768` (unchanged) |
| `ServerScriptService.KenopsiaServer.Services.MachineFlow` | ModuleScript | 300 → 450 | `1_16769` (unchanged) |

Script total unchanged at **19**. `sessionDebugId` stability proves the
ModuleScripts were edited, not destroyed and recreated. No instance was created
or deleted; no non-script instance was touched.

## Published capacity — manual action required

`Players.MaxPlayers` is **read-only** to scripts and plugins:

```
manage_properties set game.Players MaxPlayers = 4
→ "Unable to assign property MaxPlayers. Property is read only"
```

Live value remains **60**. `GameConfig` now declares 4 on the code side.

> **Required manual action:** in Studio, **File → Game Settings → Places →
> (this place) → Server Size → 4**, then Save. Alternatively set Max Players
> to 4 on the Creator Dashboard for place `110672791536316`
> (experience `10640788131`). Until this is done, code says 4 and the
> published server still accepts 60.

## Architecture delivered

**Canonical room.** One room per server, `ROOM_ID = 1`, never destroyed — it
resets to `Waiting` instead. The multi-room create/join/quick/leave remotes
survive as shims that resolve every caller to this room, so existing clients
keep working without a client change.

**Lifecycle**

```
Waiting -> Starting -> Playing -> Cleanup -> Waiting
                          |
                          +-> Aborting -> Cleanup -> Waiting
```

`RoomService` owns `Waiting/Starting/Aborting/Cleanup` and membership.
`MachineFlow` owns what happens inside `Playing`:
`Selecting -> Briefing -> Trial -> Score -> Final Score`.

**Participant snapshot.** At the moment `Starting` completes, the server stamps
`sessionId`, freezes `participants` as a userId set, and records
`requiredMinimum`. A player who joins during `Playing` is added to
`spectators`, never to `members`, and is promoted only on the way back into
`Waiting`. This is what keeps BirdHunting and Minefield unchanged: both read
`room.members` and would otherwise hand a Hunter leg to a late joiner.

**Abort path.** `removeMember` counts surviving snapshot participants; below
`requiredMinimum` it calls `abortMatch` exactly once (guarded by
`room.aborting`). `abortMatch` sets `phase = "Aborting"` and bumps `token`.
Because BirdHunting breaks on `room.phase ~= "Playing"` and Minefield's
`roomActive` requires `phase == "Playing"`, cancellation propagates into both
trials **without editing either module**.

**Server-authoritative ready/membership.** `setReady` rejects non-members
("SPECTATING - NEXT MATCH") and any phase other than `Waiting`/`Starting`.
Revoking ready during `Starting` aborts the countdown. `RoomStartRequest`
re-checks membership, minimum and all-ready server-side.

**Session infrastructure.** `sessionId` (`S<n>-<ms>`), `roundToken`
(`<sessionId>#R<n>`), `sessionsByRoomId`, `activeByUser`, captured `audience`
(participants only — spectators excluded so trial effects stay scoped),
`effectScope` (`<sessionId>:<trialId>`), and `cancelled()` delegating to
`RoomService.cancelled(sessionId)`. Every wait uses the cancellation-aware
`hold()`, which returns false the moment the session dies.

**Idempotent cleanup.** `MachineFlow.runMatch` wraps the whole body in
`xpcall` and runs `cleanup()` once through a finally-style path on both the
clean and the error route, then calls `RoomService.cleanupToWaiting`, which is
itself a no-op if already `Waiting`.

**Declarative trial registry with two independent gates.** A trial runs only if
it is listed in `GameConfig.Playlist.TrialIds` **and** its registry entry
declares `ready = true`.

| id | displayName | ready | in TrialIds |
|---|---|---|---|
| `birdhunt` | BIRD HUNTING | true | yes |
| `minefield` | DEAD ZONE | true | yes |
| `tablemanners` | CANTEEN PROTOCOL | **false** | **no** |

Canteen is excluded twice over and cannot reach the roulette. Its `init()` still
runs at boot so `TrialInput` exists for clients; `enabledTrials()` filters it
from selection and logs the exclusion.

## Preserved deliberately

Bird and Minefield modules were **not modified**. The Hunter leg rotation is
carried over verbatim. Sniper audio is untouched: `SniperFire 118803023612410`,
`SniperReload 83110281478101`, `BulletRicochet 83668417079973` are referenced by
name through `SoundService.KenopsiaAudio.SFX`, and `GoreClient`'s
`BIRD_MUSIC_DUCK` generation-counter ducking (0.62 / 0.72 / 0.34 hold, floor
0.055) is unchanged — none of those files were edited.

Each match still runs **one** roulette-picked trial. The three-shuffled-trial
playlist is a later phase; the registry and session plumbing to support it now
exist.

## Verification

| Check | Result |
|---|---|
| Studio in Edit, placeId pinned | PASS |
| selene over `studio-src` | **0 parse errors; 0 findings in all three changed files** |
| Luau validation, `sourceOrigin: studio` | `valid` ×3, parser 0.730, 0 diagnostics |
| Line-count parity Studio vs local | 46/461/450 both sides — exact |
| `GameConfig` full readback | byte-identical |
| `RoomService` readback lines 1–120 | identical |
| Instance count before/after | 19 → 19, sessionDebugIds stable |
| Rojo `servePlaceIds` guard | added: `[110672791536316]` |

### Outstanding verification

1. **Full SHA-256 parity for `RoomService` lines 121–461 and all of
   `MachineFlow`.** Line counts match exactly and the read portions are
   identical, but the complete byte comparison has not been run.
2. **All runtime tests.** `manage_studio` play actions (`play_start`,
   `play_stop`, `play_status`, `run_test`) are **PRO-gated** on this unlicensed
   tier, so no playtest can be started from here. Solo lifecycle, two-player
   membership, and abort/cleanup tests are therefore **not executed**, and no
   server/client console output exists to report. `manage_logs` **is** Basic, so
   logs can be captured if a human presses Play.

Until (2) is done this phase has **static verification only**. Do not publish.
