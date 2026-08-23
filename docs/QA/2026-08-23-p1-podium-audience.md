# QA — P1.3 podium stage + P1.7 audience camera (2026-08-23)

**Scope:** the OPEN remainders of issues #10 (podium beat after the verdict stamp) and #14
(bench / late joiners watch the running arena). Built OFFLINE on a worktree branch; nothing
pushed into the place yet — the live checks at the bottom are for the lead.

The double pool (`Scoring.distribute(ranking, 2)`), the `FINAL AUDIT` cards and the
VIABLE/REJECTED stamp in `showScore` were already live and are untouched.

## What was built

| File | Change |
|---|---|
| `Shared/Rules/MachineCam.luau` (new, pure, Lua-5.1 portable) | the podium layout table, `podiumRows(board)` (top three, `slot` = block, `place` shares a tied score like the verdict), `podiumPacket`, `audiencePacket`, `clearPacket`, and the client-side decoder `read(p)` (finite components, eye ≠ look) |
| `Services/Podium.luau` (new) | `raise(board, seconds)`: destroys a leftover `workspace.PodiumStage`, builds the model from `TrialKit.part` (slab 40×1×24, back wall 40×14×1 at z −9, three blocks 6×h×6, rank strips, one PointLight over 1st, `PodiumCamera` marker), stands the top three on the blocks (`root.CFrame` = block top + HipHeight + root/2, facing +Z toward the camera, `Anchored = true`, WalkSpeed 0, Idle clip via `AnimationIds.load(animator, "Player", "Idle")` on PS1 rigs), returns the stage with `packet`. `strike(stage)`: stops the clip, restores `Anchored`/WalkSpeed, teleports each subject to `SpawnLocation + (±6, 4, ±6)` (the same home `TrialKit.Round:cleanup` uses, so `cleanupToWaiting` → lobby finds nothing different), destroys the model. Idempotent, every per-character op in pcall. |
| `Services/AudienceCam.luau` (new) | `packetFor(trialId)` resolves the bench eye LIVE from the arena: canteen `Rig.ObserverCamera` (eye + LookVector·10, the diners' own death-cam eye); minefield `Cameraplacement + (0, 28, 30)` looking at the midpoint of `MineStartpoint`/`Exit` at ground + 2; birdhunt `Start + (0, 60, −20)` (above the 42-stud wall behind the start) looking at the lane midpoint; TrialKit arenas `origin + (0, 90, 120)` looking at `origin + (0, 4, 0)`. Missing arena → nil → no packet. |
| `GameConfig.Arenas.Origins.podium` | `Vector3.new(900, 0, 1500)` — off the legacy content (X ≤ 200, Z ≤ 800), ~780 studs from the nearest procedural arena (floorcheck 1400/900), past FogEnd 480 |
| `Pacing.Timing` | `FinalScore 8.0 → 6.0` (the verdict stamp), new `Podium = 8.0` (MASTERPLAN §2/§3: 6 + 8) |
| `MachineFlow.luau` (5 small hunks) | requires; `tellBench(room, payload)` (room.spectators) + `benchCamera(room, trialId)`; Trial-stage begin hook sends the audience cam to the bench, end-of-rounds hook clears it, `cleanup()` clears it on every exit route; after `hold(FinalScore)` → `pcall(Podium.raise)` → packet to members AND bench → `hold(Podium)` → `pcall(Podium.strike)` → `{kind="podium"}` clear to both; the bench watchdog hands a late joiner the audience cam when it seats them while `room.stage == "Trial"` |
| `KenopsiaClient.client.luau` (4 hunks, nothing in `showScore`/standings/`sfx`) | `machineCam` state + `setMachineCam(kind, p)` next to `restoreCamera`; a FIRST branch in the RenderStepped camera writer (`if machineCam then … elseif spectateCF …`) — the snap/quantisation tail is unchanged; `showPodium(p, token)` after `showAnnounce`: `hideAll()`, phosphor caption `1ST  NAME / 2ND  NAME / 3RD  NAME` bottom-centre (Code 24 px, ZIndex 70), released on the clear packet or a deadline of `seconds + 2`; funnel handlers for `podium` (bumps `session`) and `audiencecam` (does NOT touch `session`, so the bench card keeps typing) before the unknown-kind guard. While the audience cam is held the Status screen's `BackgroundTransparency` is set to 0.55 so the arena shows under the bench card; restored on the clear. |
| `default.project.json` | maps the three new modules |
| `docs/MP-01-SERVER-CONTRACT.md` | two rows in the §3 kinds table |
| tests | new `tests/machinecam.lua` (37 checks); `tests/envelope.lua` +6 (both packets and both clears walk through `Envelope.validate` as `data` under the depth/node/string limits, NaN eye rejected); `tests/rules.lua` +1 (6 s + 8 s) |

### Numbers

* Podium origin `(900, 0, 1500)`; blocks at x = 0 (1st, h 6, Steel, Sodium neon strip, lamp), −8 (2nd, h 4, Void, Grime strip), +8 (3rd, h 2.5, Void, Grime strip); slab top = y 0.
* `PodiumCamera`: eye `(900, 8, 1522)` → look `(900, 5, 1500)`. A 0.9-scale PS1 rig on the 6-stud block tops out at ~14 studs — inside the 70° vertical field (±15.4 at 22 studs).
* Packet sizes: podium = 1 + 6 + 3×5 + 1 values, depth 3 under `data`; both well under `Envelope.Limits` (64 nodes / depth 4 / 64-char strings, names clipped to 20).

## Gate output (verbatim)

```
$ lua tests/contexts.lua | tail -2
21 checks, 0 failed
GATE 1 CONTEXTS PROOF: PASS
$ lua tests/envelope.lua | tail -2
33 checks, 0 failed
GATE 1 ENVELOPE PROOF: PASS
$ lua tests/rules.lua | grep -E "FAIL|REQ-IP|mapped|checks|PROOF|verdict beat"
  PASS  verdict beat is 6 s stamp + 8 s podium
  PASS  REQ-IP-01: no forbidden token in Playlist.Ids
  PASS  every mapped path exists
  PASS  REQ-IP-01: no forbidden token in any shipped file
85 checks, 0 failed
GATE 1 RULES PROOF: PASS
$ lua tests/machinecam.lua | tail -2
37 checks, 0 failed
MACHINECAM PROOF: PASS
$ lua tests/trialrules.lua | tail -1 ; lua tests/animationids.lua | tail -1 ; lua tests/sorting.lua | tail -1
MP-05 TRIALRULES PROOF: PASS
MP-05 ANIMATIONIDS PROOF: PASS
34 checks, 0 failures

$ selene Podium.luau AudienceCam.luau MachineFlow.luau MachineCam.luau Pacing.luau GameConfig.luau KenopsiaClient.client.luau
error[if_same_then_else]: KenopsiaClient.client.luau:786:3     <- pre-existing (was ~705)
error[if_same_then_else]: KenopsiaClient.client.luau:789:3     <- pre-existing (was ~708)
error[if_same_then_else]: KenopsiaClient.client.luau:1071:3    <- pre-existing (was ~981)
Results: 3 errors, 0 warnings, 0 parse errors   (0 findings in any hunk of this change)

$ luau-lsp analyze --definitions=globalTypes.d.luau --base-luaurc=.luaurc --sourcemap=sourcemap.json <the seven files>
Minefield.luau(953,5/30): TypeError: Key 'cleanup' not found in table '{|  |}'      <- pre-existing, file untouched
BirdHunting.luau(952,5/30): TypeError: Key 'cleanup' not found in table '{|  |}'    <- pre-existing, file untouched
(nothing reported for Podium / AudienceCam / MachineFlow / MachineCam / Pacing / GameConfig / KenopsiaClient)
```

`globalTypes.d.luau` was copied from the master checkout and `sourcemap.json` regenerated with
`rojo sourcemap default.project.json` inside the worktree (both gitignored).

## Live checks for the lead (push order: MachineCam → Podium, AudienceCam → MachineFlow, Pacing, GameConfig → KenopsiaClient)

Needs **2 players** for the podium (the third block stays empty, that is expected) and a
**third client joining mid-trial** for the bench camera (Team Test, or a second Studio
instance). A 2-player run with a narrowed `TrialIds` (e.g. `{ "minefield", "canteen" }`) is enough
for everything below; restore the list afterwards.

**Podium (issue #10)**

1. Server log after the last trial: `[Podium] up at (900, 0, 1500): 2 block(s) occupied` exactly
   once per session, ~6 s after the verdict board appeared (not before: the stamp must be
   readable first).
2. Both clients: at that moment the verdict screen disappears and the 3D view cuts to the stage
   — three blocks on a slab, dark wall behind, the winner on the high middle block with the
   neon strip and the sodium pool of light, the loser on the left (2nd) block, the right block
   empty and dark. Both rigs face the camera and breathe in Idle (no walk/run, no A-pose).
   Caption bottom-centre: `1ST  <NAME>` / `2ND  <NAME>` in phosphor.
3. The camera does NOT shake, quantise or drift for the 8 s; no player can walk off the block
   (anchored).
4. After ~8 s: caption gone, both characters back at `SpawnLocation` (not on the blocks, not
   anchored — try walking once the next round starts), `workspace.PodiumStage` absent
   (Explorer), the lobby roulette plays as before, rematch re-arm still fires.
5. Tie check (optional): two players with the same final total → both captions say `1ST`,
   still two different blocks.
6. Abort check: one player leaves DURING the podium → the other is teleported home, the stage is
   destroyed, no `MINIGAME ERROR`, room returns to Waiting.
7. Quality note: Studio's Automatic quality may render no local lights (memory note, P3.1
   captures). If the winner's block is not lit, judge the lamp on the PC at quality ≥ 8 before
   calling it a bug; the neon strip shows regardless.

**Audience camera (issue #14)**

1. Start a 2-player session; when the Trial stage begins, join with the third client. Within
   ~2 s of seating (`7 s` join hold-out + watchdog) the bench card types
   `A CYCLE IS IN PROGRESS. / TRIAL i OF n: NAME / … / YOU ARE ON THE BENCH.` AND the world
   behind it is the running arena from a fixed high view (the card's black ground is thinned
   to 55 %, lines still readable):
   * canteen: the table seen from `Rig.ObserverCamera` (same eye as the diners' death cam);
   * minefield: above/behind the death cam, down the corridor toward the Exit — the compactor
     and the runners must be in frame;
   * birdhunt: above the wall behind the start line, down the lane.
2. The bench client's own character is NOT moved; its movement stays frozen; the camera does
   not follow anyone. No `role`, `count`, `go`, `gorefx` packet reaches the bench client
   (Output stays free of trial HUD on that client).
3. Between rounds nothing changes on the bench (the cam is per TRIAL, not per round); at the
   trial's end (score card for the players) the bench camera releases — the bench client sees
   its own character at spawn again and the bench card ground is opaque again.
4. A third client that was ALREADY on the bench before a trial begins gets the camera at the
   begin hook (no re-join needed): check with one who joined during the Score stage.
5. Session abort (a player leaves mid-trial): the bench camera clears via `cleanup()`; after
   `toWaiting` the bench client is promoted and gets the roulette like everyone else.
6. The bench ALSO sees the podium (packet goes to `room.spectators`), then the lobby.
7. Output hygiene: no `[Kenopsia] unhandled MachineState kind: podium/audiencecam` on any client
   (that line means KenopsiaClient was not pushed); no `[AudienceCam]` warn (means an arena
   marker is missing); `[Kenopsia] Shared.Rules.MachineCam missing` means the module was not
   pushed.

## Not done / open

* The bench watches the arena WITHOUT the simulation grade (`KenopsiaActiveTrial` is only set on
  participants), i.e. clean lobby lighting and fog 60/480. Deliberate for now; if the lead
  wants the grade on the bench too, SimulationGrade would need to read the audience state.
* Dead-at-verdict subjects: a subject whose character is mid-respawn when the podium rises gets
  no body on its block (the caption still names them). `raise()` never yields by design.
* The bench card still shows the audience view only for the three legacy trials plus kit
  arenas via their origin; a kit trial can override nothing yet (no `refs.audienceCam` hook).
* P1.7's other half (`lobbywait` with `nextCycleAt`, and forwarding the trial's own audience
  packets to the bench) is unchanged — the bench gets the Machine's camera, never trial traffic.
