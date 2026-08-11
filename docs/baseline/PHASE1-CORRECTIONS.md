# Phase 1 corrections — specification

Reviewer gate: **PHASE 1 FAIL**. Commit `3a9a1d8` preserved. Source parity for
`GameConfig`, `RoomService`, `MachineFlow` accepted as closed by the reviewer.

Status of this document: **specification only. No Studio mutation has been made
for any item below.** `Players.MaxPlayers` re-checked and still `60`.

Execution order matters: C1 and C2 are correctness/softlock fixes and must land
before C3–C6, which are contract and observability work.

---

## C1 — Dead Zone cancellation (CRITICAL)

`Minefield.luau`. Five distinct defects.

**C1.a — `TrialInput` has no owner.**
`Minefield.init()` does `local st = current`, where `current` is an *implicit
global* (selene `unscoped_variables`, `Minefield.luau:273`). The handler
validates `payload.trialId` and `ps.done` but never checks which room or
session owns the round, nor the room phase.

Fix: the round state must carry `room`, `sessionId` and `roundToken`. Reject
the packet unless all of: state exists, `st.roundToken == payload.roundToken`
(or the server-side active token if the client does not yet send one),
`st.room.phase == "Playing"`, and the firing player is a snapshot participant.
Declare `current` as a module local in the same edit — it must stop being a
global regardless.

**C1.b — no cancellation between the announcement and GO.**
`runRound` does `announce(...)` then `task.wait(2.8)`, then the seating loop,
then `for c = 3,1,-1 do announce(count); task.wait(1) end`, then `announce(go)`.
None of these check the room. An abort during this ~6 s window still starts a
full round.

Fix: check `room.phase ~= "Playing"` after the announcement wait, once per
countdown iteration, and immediately before `announce(go)`. Return through
cleanup (C1.e) on any of them.

**C1.c — the main loop ignores Aborting.**
`while os.clock() - t0 < FAILSAFE_TIME do` breaks only on `allDone`, the
crusher passing `shredEndZ`, or `#room.members == 0`. `roomActive(room)` is
defined in the module but never called. An abort therefore leaves the round
running until the crusher finishes or **150 s** elapses.

Fix: `if not roomActive(room) then break end` as the first statement inside the
loop body.

**C1.d — delayed callbacks are unguarded.**
`task.delay(FUSE, function() explode(mine) end)`,
`task.delay(CHAIN_FUSE, ...)`, `task.delay(math.random() * 0.2, ...)`, and the
`task.delay(3.2, function() tellOne(uid, { kind = "role", role = "spectate" ... }) end)`
camera hand-off all capture no token. The 3.2 s spectate callback is the worst:
after cleanup it can fire at a player already returned to the lobby and strand
their camera on the Dead Zone arena.

Fix: capture `local token = roundState.roundToken` at creation and begin every
delayed body with `if roundState.roundToken ~= token or not roomActive(room) then return end`.
Same guard for the gore/`announce({kind="gorefx"})` emissions.

**C1.e — no single idempotent cleanup path.**
`exitConn:Disconnect()`, `runtime:Destroy()`, `BloodFX.clear()`, the attribute
reset and the spawn restore all sit inline after the loop. If anything above
errors, `exitConn` leaks, the `DZ_Runtime` folder (mines, craters, the
`Kastrierer` model) survives, and `current` stays set — poisoning the next
round.

Fix: wrap the body in `xpcall`, hoist all teardown into one `cleanup()` closure
guarded by a `cleaned` flag, and call it from a finally-style path on both
routes. It must: disconnect `exitConn`, clear the module-local active state,
`runtime:Destroy()`, restore `XBotCrawl`/`XBotScanning`/`XBotMoves` and spawn
position for every living participant, and send `{ kind = "role", role = "none" }`.
Per REQ-DZ-03 it must **not** call global `BloodFX.clear()` — that is a
separate deferred item, so keep the existing call for now but move it inside
the single path.

---

## C2 — MachineFlow no-ready-trial path (SOFTLOCK)

`MachineFlow.runMatch`, as committed in `3a9a1d8`:

```lua
if not trial then
    warn("[MachineFlow] no ready trial at match start - aborting")
    RoomServiceRef.abort(room, "NO READY TRIAL")
    return                       -- <-- BUG
end
```

`abort()` sets `phase = "Aborting"`. The early `return` happens before `ctx`
and `cleanup()` exist, so `RoomService.cleanupToWaiting` is never reached and
the room **stays in Aborting forever**. Nothing else drives it back to Waiting.

Second defect, same function:

```lua
RoomServiceRef.cleanupToWaiting(ok and "match complete" or "trial error")
```

`ok` is true for a *cancelled* session too, because `hold()` returns false and
the body `return`s cleanly. An aborted match is therefore logged as
"match complete".

Fix: restructure so setup, no-trial, cancellation, normal completion and trial
error all pass through one finalizer. Sketch:

```lua
local ctx, cleanup = nil, nil
local outcome = "completed"          -- completed | cancelled | error | no-trial
local ok, err = xpcall(function()
    trial = resolveTrial(room)
    if not trial then outcome = "no-trial" return end
    ctx = buildContext(room, trial)
    cleanup = makeCleanup(ctx, trial, room)
    ... body; set outcome = "cancelled" when ctx.cancelled() ...
end, debug.traceback)
if not ok then outcome = "error" end
if cleanup then cleanup() end                      -- idempotent
if outcome == "error" or outcome == "no-trial" then
    RoomServiceRef.abort(room, outcome == "error" and "TRIAL ERROR" or "NO READY TRIAL")
end
RoomServiceRef.cleanupToWaiting(outcome)           -- honest label
```

`cleanup` must be safe to call when `ctx` was never built.

---

## C3 — Spectator client contract

`KenopsiaClient.client.luau`, `RoomState.OnClientEvent`:

```lua
for _, m in p.members or {} do
    if m.userId == player.UserId then myReady = m.ready == true end
end
```

If the local player is a spectator they are absent from `members`, so the loop
never runs and `myReady` **retains its stale value**. `updateReadyVisual()`
then paints a ready-looking button, and `Btn_READY.Activated` still fires
`ReadyReq`, which the server now rejects with "SPECTATING - NEXT MATCH" — an
error the player never asked for.

Fix, all in the same handler:

1. Read `p.spectators` (added to `publicState` in `3a9a1d8`) and compute
   `local amSpectator = not inMembers and inSpectators`.
2. `if not inMembers then myReady = false end`.
3. `info.Btn_READY.Active = not amSpectator`, `.AutoButtonColor = not amSpectator`,
   and dim `TextColor3` to `DIM` while spectating.
4. Show `SPECTATING // NEXT MATCH` — reuse `info.NextLabel` or add a label
   under the roster; do not add a new full-screen frame.
5. On promotion (`inMembers` becomes true) restore `Active`, colour, and let
   the normal `updateReadyVisual()` path resume.

Guard `Btn_READY.Activated` with `if amSpectator then return end` so a stale
click cannot fire the remote.

---

## C4 — Observable lifecycle stage

Add `stage` to the room: `nil | "Selecting" | "Briefing" | "Trial" | "Score" | "FinalScore"`.

- `RoomService`: add `stage = nil` to the room table; include it in
  `publicState()`; clear it in `toWaiting()`.
- Add `RoomService.setStage(sessionId, stage)` which **verifies the token**:
  `if room.sessionId ~= sessionId or room.phase ~= "Playing" then return false end`.
- `MachineFlow` calls it at each transition and never writes `room.stage`
  directly.
- `preFlow` runs while `Waiting`, so `Selecting` is set through a separate
  waiting-stage setter that checks `phase == "Waiting"` instead.

---

## C5 — Context granularity

Two defects in `buildContext` as committed:

- `roundToken` is generated **once per match**, not per numbered round. Dead
  Zone runs 10 rounds and Bird 5×N legs under a single token, so a guard
  written against it cannot distinguish round 3 from round 7.
- `effectScope` is `"<sessionId>:<trialId>"` — one scope for the whole trial,
  so a scoped clear cannot target a single round.

Fix: move token/scope minting into the per-round loop —
`roundToken = "<sessionId>#R<roundIndex>"`, `effectScope = "<sessionId>:<trialId>:R<roundIndex>"` —
and pass the per-round context to the trial. Keep the match-level `sessionId`
where it is.

Bird cancellation (mechanics unchanged): add
`if room.phase ~= nil and room.phase ~= "Playing" then return scores end`
after the `2.8 s` Hunter-card wait, after the `4 s` `huntersetup` wait, and once
per countdown iteration in `runLeg`. No other Bird edit.

---

## C6 — Match-scoped attribute reset

`KenopsiaSessionScore` and `KenopsiaSessionWins` accumulate across every match
for the lifetime of the server. Until the three-trial playlist exists there is
nothing to carry between minigames, so they must reset per session.

Fix: at the top of `runMatch`, for every snapshot participant, set both
attributes to `0`. Add a comment tying the change to the later playlist phase,
so it is deliberately revisited rather than silently re-broken.

---

## C7 — Manual capacity (BLOCKED ON HUMAN)

`Players.MaxPlayers` is read-only to plugins:
`"Unable to assign property MaxPlayers. Property is read only"`. Re-checked
after the Phase 1 commit: still **60**.

**Studio → File → Game Settings → Places → this place → Server Size → 4 → Save.**
Or set Max Players to 4 on the Creator Dashboard for place `110672791536316`
(experience `10640788131`). Verify with
`manage_properties get game.Players MaxPlayers` → expect `4`.

---

## Retest matrix — every item currently BLOCKED

All `manage_studio` play actions (`play_start`, `play_stop`, `play_status`,
`run_test`) are **PRO-gated** on this unlicensed WEPPY tier. No playtest can be
started from the agent side, so none of the required retests can be executed
here:

| Retest | Status |
|---|---|
| Solo start → complete → Waiting | BLOCKED — needs Play |
| Two-player ready/countdown/start | BLOCKED — needs 2-client Team Test |
| Late join → spectator → promoted | BLOCKED |
| Leave during Bird announcement / setup / active leg | BLOCKED |
| Leave during Dead Zone announcement / countdown / loop | BLOCKED |
| Forced no-ready-trial → Waiting | BLOCKED |
| Forced trial error → Waiting | BLOCKED |
| No stale movement/camera/UI/mine/crusher/rifle/beam/gore/callbacks/attributes | BLOCKED |

`manage_logs` **is** Basic tier (`get`, `errors`, `sinceSeq` cursor). If a human
starts a Play session, server and client console output can be captured and the
matrix completed without a licence purchase.

Static verification (readback, hash parity, Luau validation, Selene, instance
counts) remains fully available and is **not** blocked.
