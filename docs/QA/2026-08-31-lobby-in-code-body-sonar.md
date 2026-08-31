# QA — Lobby moved into code, missing bodies, duplicate sonar (31.08.2026)

Three items from one message: *"What can I possibly do for the caution?"* ·
*"sometimes the character doesnt show up in Bird Hunting and in Dead Zone"* ·
*"there are 2 Sonar. Remove one."*

---

## 1. The caution is gone — the lobby is code now

Yesterday's holding cell was **place geometry**: it lived in the `.rbxl`, not
in the repo. Not versioned, not reviewable, no Rojo sync would bring it back,
and one unsaved close would have deleted it — taking `SpawnLocation` with it
and returning the game to the void-fall bug.

**New `Services/Lobby.luau`** builds the cell and `workspace.SpawnLocation` at
server boot and is **idempotent** — `ensure()` only creates what is missing, so
it does not matter whether the place was ever saved. Called from `Main` as the
**first** service: `CharacterAutoLoads` spawns the first player immediately, and
without a SpawnLocation that player falls.

The hand-built geometry was then **deleted from the place on purpose**, so the
code path is the one that actually runs and got tested rather than sitting
behind geometry that happened to already be there.

Runtime instances are never written to the place file — that is the point: the
file no longer needs to know about the lobby.

**Verified in Play from an empty Workspace:** console prints
`[Lobby] holding cell ready - spawn at 0, 0.5, 0` as the first line, folder
rebuilt with 7 parts, `SpawnLocation` present, character stable at (0, 4.8, 0)
for 5 s.

> Publishing is still required to ship *code* — that never goes away. What is
> gone is the risk of silently losing the room.

## 2. "Sometimes the character doesn't show up"

Real bug, and the mechanism is exact. `Round:place` takes
`TrialKit.livingOf(room)` and, for any member without a living character, does:

```lua
if not s then
    if ps then ps.done = true end   -- TrialKit:587
end
```

— silently marks them finished. They then sit out the entire round with no
body. **Nothing in the whole server ever called `LoadCharacter`** (grepped: 0
hits across 31 service scripts), so a missing character was never recovered.

The window is real: Roblox respawns on `Players.RespawnTime` (3 s), so anyone
who dies near the end of a round is still respawning when the next round places
its players.

**Fix (MachineFlow, before each round):** request a character for every member
who has none or is dead, then wait — bounded by `RespawnGrace` (5 s default) and
checking `ctx.cancelled()`, so a player who is leaving cannot stall the session.
It sits directly under the new blackout, so the respawn is invisible.

**Verified in Play by reproducing the exact failure:** killed the player
mid-round, then watched the next three round starts — `body=YES` at every one.

## 3. Two sonars

Both were live at once in DEAD ZONE:

| | Legacy (KenopsiaClient) | Phase 3b (`SonarClient`) |
|---|---|---|
| Input | **F**, ButtonY, `Btn_SCAN` | **E**, ButtonX, `Btn_PULSE` |
| Behaviour | hold for repeating pulses + a sweeping radar beam | one pulse per press |
| Budget | unlimited | **3 per round**, server-owned |
| Reveal | `spawnWave` — client-local ring, only the presser sees it | server parts, **everyone** sees them |

Two touch buttons, two rings, and both firing `pulse` on the same remote.

**Removed the legacy one**, keeping the Phase 3b economy that
INNER-GAME-PLAN §2.1 specifies. Neutralised at its three choke points rather
than cut out: `firePulse` and `setScanHeld` take an early `do return end`, and
`setRunnerTouch` now forces `Btn_SCAN` hidden (that line was what put the second
button on screen). ~90 lines are left in place deliberately — this script sits
at ~185/200 Luau locals and excising a block from the middle of the main chunk
is the riskier edit. F / ButtonY still route here and now end harmlessly.

**Verified in Play:** `Btn_SCAN visible=false`, `Btn_PULSE visible=true`,
`ScanBeam=0` in the world.

---

## Verification summary

- All four touched scripts weppy-validate clean (parser 0.730).
- selene over Lobby + Main + MachineFlow + KenopsiaClient: **3 errors /
  1 warning — identical to baseline** (all pre-existing, incl. the deliberate
  unused `Podium`).
- Offline battery **14/14 green**.
- `Pacing.Timing.RespawnGrace` deliberately does **not** exist: it is read as
  `or 5`. Adding a real 5.0 key would collide with `ShiftReport = 5.0` and fail
  `tests/feel.lua`'s no-duplicate-timings guard.
