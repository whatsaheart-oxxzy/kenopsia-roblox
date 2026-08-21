# MP-04 — Trial design cards for the twelve unbuilt minigames

Status: DESIGN (Agent 1d, 2026-08-17). Input for the Framework / Trial-build / Integrate stages of the MP plan.
Scope: the twelve minigames of the reference roster that are not yet in `MachineFlow.TRIALS`
(`birdhunt`, `minefield`, `canteen` are shipped and untouched by this document).

> IP NOTE (REQ-IP-01). This file is the ONLY place where the reference game's minigame names appear,
> and it lives under `docs/`, never in `studio-src/`, `tests/`, `default.project.json` or any comment.
> Every id, display name, subtitle, tagline, HUD string and packet `kind` below is original.
> `tests/rules.lua` already rejects the three old spellings; the Framework agent extends that assertion
> with the twelve reference names in the mapping table (§0.1) so a rename can never quietly regress.

---

## 0. Shared decisions (apply to every card)

### 0.1 Reference -> shipped mapping (docs only)

| # | Reference name (docs only) | id | Display name | Icon (Selection.IconPool) |
|---|---|---|---|---|
| 1 | Chisel Gauntlet | `carve` | CUT TO SPEC | Cube |
| 2 | Firearm Factory | `armory` | ARMS ISSUE | Crosshair |
| 3 | Wrong Way | `upstream` | UPSTREAM | Factory |
| 4 | Stable Footing | `floorcheck` | FLOOR CHECK | Cube |
| 5 | Tunnel Hazard | `clearance` | CLEARANCE | Train |
| 6 | Inside Job | `carrier` | CARRIER | Bug |
| 7 | Smoke Break | `breather` | BREATHER | Factory |
| 8 | Debris Platforms | `sweep` | CLEAR THE DECK | Saw |
| 9 | Spine Breaker | `crawler` | CRAWLER | Bug |
| 10 | Lethal Rebound | `ricochet` | RICOCHET | Saw |
| 11 | Forklift Certified | `stacker` | PALLET DUTY | Factory |
| 12 | The Filter | `sorting` | SORTING FLOOR | Magnifier |

Icons: the live `StarterGui.KenopsiaMachine.Selection.IconPool` holds exactly eight ImageLabels —
`Bug, Crosshair, Cube, Factory, Magnifier, Saw, Train, Utensil` (`Utensil` is unused today; `Saw` is
Canteen's). Fifteen trials over eight glyphs means repeats; the roulette hides ~45 % of tiles at random
and shows the winner's icon large, so repeats are cosmetic. `MachineFlow.DECOY_ICONS` should shrink to
whatever is still unused after integration (only `Utensil`) or be dropped — a decoy that equals a real
trial's icon is harmless but pointless. New original glyphs (chisel, arrow, syringe, cigarette, blade,
pallet, funnel) are an ASSET-LEDGER follow-up, not a blocker.

### 0.2 House voice for the copy
Subtitle: an order in the Machine's voice, ends with `_` (CRT cursor). Tagline: the four-to-six word
verb line shown on the RoundCard. Uppercase, industrial, no jokes, no exclamation marks. Death lines are
two or three words in the past tense (`PROCESSED.`, `YOU STEPPED WRONG.`).

### 0.3 Framework contract every card assumes (from the code, not from the plan)
- `MachineFlow` sums `runRound` return values across the trial's rounds and ranks by `raw` desc, then
  `Scoring.distribute` pays exactly 1700. So each card's "ranking metric" is an ORDERING KEY in bands
  (Minefield/Canteen idiom): `FINISHED 2000+ > ALIVE 1000+ > ELIMINATED 0+`, with per-band detail that
  can never cross into the band above. Cards state their bands explicitly.
- `Pacing.ROUNDS[id] = {[2]=,[3]=,[4]=}` and `Pacing.RoundSeconds[id]` rows are given per card.
- Death = `announce {kind="gorefx", pos, power}` + `tellOne {kind="announce", style="death", text=...}` +
  `tellOne {kind="role", role="spectate", ...}` — exactly Minefield's sequence. Every kill is
  telegraphed >= 0.7 s before it lands (light/sound/motion), never instant on a hidden timer.
- Server samples `HumanoidRootPart.Position` on a fixed tick for all positional judgments (Minefield
  idiom, never `.Touched`), converts to grid cells arithmetically, and rejects teleports (>
  `walkSpeed * dt * 1.5` per tick => snap back + strike). Client only ever sends INTENT packets through
  `TrialInput` (`{trialId, action, roundToken, ...}`); server validates trialId/action/roundToken/
  sessionId/phase/membership/rate (>= 12 packets/s per player => drop + warn).
- Client module `TrialClients/<id>.luau` gets `{kind="role", role=..., camStyle=..., roundToken=...}` and
  trial-specific `{kind=...}` packets routed by the generic dispatcher; `camStyle` is `"top"` (Minefield
  style) unless the card says otherwise. Every card lists its packet kinds so the dispatcher agent can
  budget the vocabulary.
- Arena: `Workspace.KenopsiaArenas.<id>` built by an idempotent `ensureArena()` from anchored
  SmoothPlastic Parts, `CastShadow=false`, < 300 parts. Per-round dynamic props go into a per-round
  Folder that `guard.cleanup` destroys. Players are teleported in via the same `PivotTo` pattern
  Minefield uses at its `Spawnpoint` and are handed back to MachineFlow at return.

### 0.4 Arena offset table (proposal — the Framework agent verifies against the live Dead Zone /
Bird Hunting / CanteenProtocol bounds before committing)
All new arenas sit on the plane `Y = 400` (above the fog ceiling of the hub) in a row along +X, 600 studs
apart so no arena's audio, camera or debris can be seen from a neighbour:

| id | origin (X, Y, Z) | footprint |
|---|---|---|
| carve | (2000, 400, -3000) | 60 x 60 |
| armory | (2600, 400, -3000) | 90 x 90 |
| upstream | (3200, 400, -3000) | 40 x 140 |
| floorcheck | (3800, 400, -3000) | 60 x 80 |
| clearance | (4400, 400, -3000) | 30 x 160 |
| carrier | (5000, 400, -3000) | 100 x 100 |
| breather | (5600, 400, -3000) | 40 x 40 |
| sweep | (6200, 400, -3000) | 70 x 70 |
| crawler | (6800, 400, -3000) | 70 x 70 |
| ricochet | (7400, 400, -3000) | 60 x 60 |
| stacker | (8000, 400, -3000) | 90 x 90 |
| sorting | (8600, 400, -3000) | 60 x 60 |

### 0.5 Shared PS1 palette (one table in the kit + one in a server `ArenaPalette` module)
`Void (12,12,14)`, `Concrete (96,96,92)`, `Wet Concrete (68,70,66)`, `Steel (140,146,150)`,
`Rust (122,58,34)`, `Hazard (196,160,32)`, `Signal (200,32,32)`, `Blood (120,16,16)`,
`Grime (58,72,52)`, `Bone (204,196,176)`, `Sodium (232,176,88)` (lamp glow neon parts, no lights).
Every arena uses <= 5 of these. Neon is used only for "the telegraph" (the thing that is about to
kill you) so danger has one consistent colour language: `Signal` neon = lethal now, `Hazard` neon =
lethal soon.

### 0.6 SFX available today (`SoundService.KenopsiaAudio`, see docs/assets/audio-inventory.csv)
`SFX.Click/ClickAlt/Hover`, `SFX.Clicks.Click1-5`, `SFX.Submit/SubmitAlt`, `SFX.Submits.Submit1-3`,
`SFX.Reject/AccessDenied`, `SFX.AccessGranted`, `SFX.StandClear`, `SFX.Warning`, `SFX.Confirm`,
`SFX.Count5..1`, `SFX.ImpactBody`, `SFX.MineExplosions.Explode1-4`, `SFX.Blood.Blood1-2`,
`SFX.SniperFire/SniperReload/BulletRicochet.Primary`, `Music.Trials.birdhunt/minefield`.
Cards name gaps (train horn, cough, saw whine, forklift beep, gunshot for a handgun) with the fallback
that ships until an original asset is added to the ledger. No trial may DEPEND on a missing sound.

### 0.7 Common exploit guards (each card adds only its specifics)
1. Position: server-sampled, speed-clamped, arena-bounds-clamped; a player outside the arena AABB is
   snapped to spawn (never killed for it — network hiccups happen).
2. Inputs: only the actions listed in the card, only in the phases listed, roundToken must match the
   live round, rate-limited, membership-checked (audience packets are dropped silently).
3. Hidden state (safe tile, template, infected player, correct alcove) is never sent to clients before
   the moment the design says it is revealed; when it is revealed it is revealed to everyone equally.
4. Timers are server-owned; the client receives an absolute `endsAt` (server clock) once and counts
   down locally.

---

## 1. `carve` — CUT TO SPEC

**Subtitle** `MATCH THE TEMPLATE. THE BLOCK IS NOT FORGIVING._`  **Tagline** `CUT ONLY WHAT IS SHOWN.`
**Icon** Cube. **Reference (docs only):** Chisel Gauntlet.

**Core loop.** Each player stands at a workbench holding a 3x3x3 block of 27 unit cubes. A template
(a subset of the 27 cubes that must REMAIN) is shown on the wall for 5 s, then hidden. Players carve by
clicking a cube to remove it; each cube removed that the template says should stay is a WRONG CUT. The
first wrong cut turns the bench lamp `Hazard` and sounds `Warning` (telegraph); the second wrong cut
drops the guillotine hood over the bench and kills the player. Finishing means every cube not in the
template has been removed and none of the template has been touched. Later rounds show the template
shorter, use templates with fewer remaining cubes (more cuts, more chances to err) and, in round 3+,
show only two of the three orthographic views (front + top) so the player must infer the third.
Everyone works in parallel; the round ends when all are finished/dead or the clock runs out.

**Roles.** All players are Carvers. Dead players spectate the fastest live bench.

**Inputs.** Mouse move = highlight cube under cursor (client raycast against that player's own block
parts, which are client-visible), LMB = `cut {x,y,z}`, `R` = rotate view 90 deg (client only),
`Tab` = peek: shows the template again for 0.75 s but costs a fixed 3 s time penalty (server-owned,
`peek` action, max 2 per round). Camera `camStyle="bench"`: fixed 3/4 view over the player's own bench
(kit helper: `camera.fixed(cframe)`), NOT top-down — the block needs three visible faces.

**Server / client split.** Server owns the template (seeded RNG per round from
`Random.new(hash(sessionId, roundIndex))`), the per-player 27-bit block state, strike count, peek count,
timers, ranking. It sends `{kind="carve_template", cells=[...27 bools], showFor}` (all players get the
same template — fairness and spectator legibility), `{kind="carve_state", userId, removed=[indices]}`
after each accepted cut (to all, so spectators/others see progress), `{kind="carve_strike", userId, n}`.
Client renders the block from the state packet (27 unit Parts per bench, one bench per participant,
<= 4 * 27 + 4 * 6 bench parts), the template preview as a mini block on the wall, the hood.

**Win / loss / death.** Finished = block equals template. Death = second wrong cut (hood drops:
0.8 s `Hazard` -> `Signal` lamp, `StandClear` sound, then hood + `gorefx power 1.2` + `Blood`), death
text `OFF SPEC.` Time-out = alive-unfinished.

**Ranking metric (ordering key).** `FINISHED 2000 + spareSeconds*10` > `ALIVE 1000 + correctCuts*20`
(max 26 cuts = 520 < 1000) > `ELIMINATED 0 + correctCuts*20 - strikes*10`. Ties (same finish second)
share.

**Pacing.** `ROUNDS.carve = {[2]=3,[3]=3,[4]=2}`, `RoundSeconds.carve = 45` (5 s template + 40 s carve).

**Arena.** 60x60 slab `Concrete`; four benches (`Steel` top, `Rust` legs) in a row facing a `Wet
Concrete` wall carrying four `Bone` template boards; one guillotine hood per bench (`Steel`, hinged via
CFrame tween on the server, cosmetic on the client). Sodium neon strip lamps above each bench that go
`Hazard` on strike 1. ~ 60 static parts + 108 block cubes.

**Dynamic props (per round).** Block cubes (rebuilt each round), template mini-blocks, hood state.

**SFX.** Cut = `Clicks.Click1-5` random; wrong cut = `Reject`; strike 1 = `Warning`; hood telegraph =
`StandClear`; kill = `ImpactBody` + `Blood.Blood1`; finish = `AccessGranted`. Gap: no chisel/saw
sound — `Clicks` ships as the placeholder.

**Difficulty knobs.** template show time (5 -> 3 s), template density (16..20 of 27 remain early,
9..12 late), views shown (3 -> 2), peek cost, strikes allowed (2 fixed — do not make it 1, that is
unfair with mouse raycasts).

**Exploits to guard.** Cut coordinates validated (0..2 each, cube still present, cube visible from an
outer face — no cutting an interior cube before its neighbours); template never sent after showFor
except via paid `peek`; rate limit 6 cuts/s; a `cut` for a bench that is not the sender's is dropped.

**Pure-logic units (tests/carve.lua).** `Templates.generate(rng, density) -> 27 bools` (connected,
front-face-visible); `Block.canCut(state, idx)` (exposure rule); `Block.isFinished(state, template)`;
`Rank.key(record)` band monotonicity; orthographic view projection `Views.project(template, axis)`.

---

## 2. `armory` — ARMS ISSUE

**Subtitle** `PARTS ARE ON THE FLOOR. THE ISSUE IS NOT._`  **Tagline** `COLLECT. ASSEMBLE. DISCHARGE.`
**Icon** Crosshair. **Reference (docs only):** Firearm Factory.

**Core loop.** A workshop floor is littered with pistol parts of four kinds (frame, slide, barrel,
magazine) plus decoy parts (springs, pins) — one full set per player exists, no more. Players sprint the
floor collecting parts (walk over + `E`); a HUD silhouette fills in. With all four collected they run
to any Assembly Press (two on the floor) and hold `E` for a 2 s assembly, then must fire the assembled
weapon by aiming at the ceiling target and clicking. First shot ends the round for the shooter as
FINISHED; the rest keep going until the clock. Scarcity is the game: parts can be STOLEN from a
player's hands by walking into them while they carry an incomplete set (`Sneak Walk` pack makes a
carrier walk slower per part carried, 16 -> 10 studs/s at 4 parts), which is what makes it a brawl
rather than a scavenger hunt. Round 2+ shuffles part spawn positions and adds a conveyor belt that
carries parts across the floor (Minefield-style CFrame tick, no physics).

**Roles.** All players are Assemblers.

**Inputs.** WASD move, `E` pick up / hold to assemble, LMB fire (only when armed), mouse aims the
crosshair in the top-down view. `camStyle="top"`.

**Server / client split.** Server owns part positions, ownership, theft rule (a collision between two
sampled positions < 2.5 studs while one is a carrier => the OTHER takes one random part, 1.5 s
immunity after a theft either way), assembly timers, the fire event, ranking. Sends `{kind="armory_parts",
list=[{id,kind,pos}]}` at start and `{kind="armory_take", partId, byUserId}`, `{kind="armory_inv",
userId, kinds=[...]}` (everyone sees everyone's silhouette so theft targets are legible),
`{kind="armory_fire", userId}`. Client renders parts (one Part + Attachment glow each), the silhouettes,
the assembly bar, muzzle flash (client-side neon flash Part 0.1 s).

**Win / loss / death.** No death in this trial (it is the roster's one pure race; the Machine's cruelty
here is theft). FINISHED = fired. ALIVE = not fired at time-out.

**Ranking metric.** `FINISHED 2000 + (roundSeconds - fireTime)*10` > `ALIVE 1000 + partsHeld*100 +
assembled*300` (max 700 < 1000; assembled but not fired sits above 4 loose parts).

**Pacing.** `ROUNDS.armory = {[2]=3,[3]=2,[4]=2}`, `RoundSeconds.armory = 50`.

**Arena.** 90x90 slab `Wet Concrete`, perimeter wall `Concrete` 8 high, six `Steel` shelving blocks
as line-of-sight breakers, two `Rust` Assembly Presses (2x2x3 with a `Hazard` neon top), one `Bone`
ceiling target ring at Y+30. ~ 40 static parts.

**Dynamic props.** Part pickups (4 kinds x playerCount + 6 decoys, <= 22 Parts), conveyor slats
(round 2+, 12 Parts moved by CFrame tick).

**SFX.** pickup = `Submits.Submit1-3`; theft = `Reject` to the victim, `AccessGranted` to the thief;
assembly complete = `Confirm`; fire = `SniperFire.Primary` at pitch 1.4 (gap: no handgun sound —
pitched sniper ships), `BulletRicochet` on the ceiling target.

**Difficulty knobs.** decoy count, conveyor speed, theft radius, carry slowdown per part, assembly hold
time.

**Exploits to guard.** Pickup validated by server distance (< 4 studs) not by client claim; `fire`
accepted only when server state says assembled; theft computed server-side only; assembly is a
server timer that cancels if the player leaves the press radius; conveyor is CFrame-driven so nothing
depends on client physics.

**Pure-logic units (tests/armory.lua).** `Loot.layout(rng, playerCount, arenaSize)` (one full set per
player, min spacing); `Theft.resolve(a, b, now)` (immunity, which part moves); `Inventory.isComplete`;
`Rank.key` bands.

---

## 3. `upstream` — UPSTREAM

**Subtitle** `THE STAIRS RUN DOWN. YOU RUN UP._`  **Tagline** `READ THE ARROWS. CLIMB.`
**Icon** Factory. **Reference (docs only):** Wrong Way.

**Core loop.** Four parallel escalator lanes carry the players DOWN toward a shredder at the bottom.
The Machine displays an arrow sequence above each lane (same sequence for all lanes per beat, 3 to 6
arrows from `Up/Down/Left/Right`); the player must press the arrows in order. Each correct arrow gives
a burst of climb (one step); each wrong arrow stalls the player for a beat while the belt keeps pulling.
Sequences arrive on a beat every 4 s (round 1) down to 2.5 s (round 3), and belt speed rises 15 % per
round. Reaching the top landing = FINISHED (the player steps off and the lane locks). Sliding into the
shredder = death. Sequences are hidden the moment the beat ends, so late readers lose. This is the
roster's rhythm/typing game and its input is pure keyboard.

**Roles.** All players are Climbers.

**Inputs.** Arrow keys (and WASD as aliases) = `arrow {dir, seq}`. No mouse. `camStyle="side"`:
fixed camera looking at all four lanes from the side (kit `camera.fixed`) so spectators/players see
everyone's position on the stairs at once.

**Server / client split.** Server owns the belt (per-tick `pos -= beltSpeed*dt`), sequences (seeded RNG),
per-player progress and stall timers, and the shredder line. It sends `{kind="up_seq", seq=[...],
beatIndex, showFor}` to all, `{kind="up_pos", positions={[userId]=t}}` at 10 Hz (t in 0..1 along the
stairs), `{kind="up_hit", userId, ok}` for feedback. Client renders the escalator (static stepped
parts + a scrolling `Steel` stripe cosmetic), the arrow HUD, the player pawn positions (server moves the
characters via CFrame — characters are `Anchored` on the belt so client physics cannot help).

**Win / loss / death.** FINISHED at top. Death when `t <= 0`: the last 12 % of the stairs is lit
`Signal` neon and `Warning` loops there (telegraph), then `gorefx power 1.6`, text `FED TO THE BELT.`

**Ranking metric.** `FINISHED 2000 + (roundSeconds - finishTime)*10` > `ALIVE 1000 + t*500` >
`ELIMINATED 0 + correctArrows*5` (cap 900).

**Pacing.** `ROUNDS.upstream = {[2]=3,[3]=3,[4]=2}`, `RoundSeconds.upstream = 40`.

**Arena.** 40x140 pit; four lanes each 24 stair Parts (`Steel` treads, `Rust` risers), landing slab
top (`Concrete`), shredder housing bottom (`Void` box with `Signal` neon teeth strips), lane dividers
`Wet Concrete`, arrow boards above (`Bone`). ~ 130 static parts.

**Dynamic props.** none beyond neon state changes; character CFrames.

**SFX.** correct arrow = `Clicks.Click1-5`; wrong = `Reject`; new sequence = `Click`; danger zone =
`Warning` loop; death = `MineExplosions.Explode1` pitched 0.6 + `Blood.Blood2`; finish = `AccessGranted`.

**Difficulty knobs.** belt speed, beat interval, sequence length, showFor, stall duration.

**Exploits to guard.** Arrow packets carry `seq` (beat index) and are rejected if not the live beat or
if beyond the next expected index; rate limit 10/s; character is anchored and moved by the server, so
position packets/exploits do nothing; sequences sent only per beat.

**Pure-logic units (tests/upstream.lua).** `Seq.generate(rng, len)`; `Climb.step(state, dir)`
(advance/stall/complete); `Belt.tick(pos, speed, dt, stalled)`; ordering-key bands.

---

## 4. `floorcheck` — FLOOR CHECK

**Subtitle** `ONE PLATE HOLDS. THE REST GIVE WAY._`  **Tagline** `STAND WHERE YOU ARE TOLD.`
**Icon** Cube. **Reference (docs only):** Stable Footing.

**Core loop.** A 6x8 grid of `Steel` plates over a drop into a shredder. Every cycle the Machine
announces one safe plate by coordinate (`B-5`) on the wall boards and by lighting the plate's row and
column labels — never the plate itself. Players have the CALL window (2.6 s round 1 -> 1.6 s round 3)
to be standing on the announced plate; at the deadline every other plate tilts and drops for 1.2 s
(telegraph: all plates flash `Hazard` for the last 0.5 s of the call). Anyone not on the safe plate
falls. Plates return, a new coordinate is called. Rounds later shrink the safe plate to a smaller
inset (harder to be "on" it, requires precise positioning) and add ONE fake call per round (announced,
then flipped 0.6 s later with `Reject` — players who commit early die; players who wait to the last
0.6 s live). The plate is small enough that four players can stand on it, so this is a movement game,
not a shoving game; but bodies do collide, so late arrivals may bounce off.

**Roles.** All players are Standers.

**Inputs.** WASD only. `camStyle="top"`.

**Server / client split.** Server owns the schedule (seeded), safe cell, fake calls, plate state, sample
positions -> cell each tick, drop resolution. Sends `{kind="fc_call", cell={c,r}, endsAt, fake=nil}` (fake
flag NEVER included; the correction arrives as a second `fc_call`), `{kind="fc_drop", safe={c,r}}`,
`{kind="fc_reset"}`. Client renders labels, plate tilt/drop tween, coordinate boards.

**Win / loss / death.** No FINISH state — survival to the clock is ALIVE. Death = off the safe plate at
a drop: player falls (server disables collision on their plate cell only, or simply CFrames them down),
`gorefx power 1.4` at the shredder, text `WRONG PLATE.`

**Ranking metric.** `ALIVE 1000 + callsSurvived*10` > `ELIMINATED 0 + callsSurvived*10` (later death
ranks higher; ties share). Round ends early when <= 1 player alive.

**Pacing.** `ROUNDS.floorcheck = {[2]=3,[3]=3,[4]=2}`, `RoundSeconds.floorcheck = 35`.

**Arena.** 60x80: 48 plates 6x6 studs on 1-stud gaps (`Steel`, `Hazard` neon when flashing), walkway
frame `Concrete`, drop shaft `Void` 20 deep with `Signal` teeth strips, two `Bone` coordinate boards,
row/column label Parts (14). ~ 80 static parts.

**Dynamic props.** none (plates are static parts whose CFrame is tweened server-side).

**SFX.** call = `Count3` style tick -> reuse `Clicks.Click3`; last 0.5 s = `Warning`; drop = `StandClear`
+ `MineExplosions.Explode2` pitched 0.5; death = `Blood.Blood1`; fake flip = `Reject`.

**Difficulty knobs.** call window, safe inset radius, fake calls per round, plate drop hold time.

**Exploits to guard.** Standing test uses server-sampled position clamped to plate inset; speed clamp
prevents "teleport at the last frame"; safe cell is sent only at call time (which is by design public);
no input packets exist beyond movement.

**Pure-logic units (tests/floorcheck.lua).** `Schedule.build(rng, roundIndex, seconds)` (no
consecutive repeats, fake placement rules); `Grid.cellOf(x,z)`; `Grid.isOn(pos, cell, inset)`;
`Round.resolveDrop(positions, safe) -> deaths`; bands.

---

## 5. `clearance` — CLEARANCE

**Subtitle** `THE LINE IS LIVE. FIND YOUR RECESS._`  **Tagline** `OFF THE TRACK BEFORE THE HORN.`
**Icon** Train. **Reference (docs only):** Tunnel Hazard.

**Core loop.** A 160-stud service tunnel with a single track. Along both walls are 10 numbered
recesses (alcoves), each with a shutter. At round start every player is issued a CLEARANCE NUMBER on
their HUD (private) — only the recess with that number opens for THEM (`E` at the shutter; the wrong
recess flashes `AccessDenied`). Numbers are painted on the alcoves in a scrambled order (not sequential),
so you must run and read. The train is announced by a horn and a `Signal` neon lamp sweep from the far
end (3.5 s telegraph), then a `Steel` locomotive block traverses the tunnel at 60 studs/s and kills
anyone on the track. Between trains (every 9 s round 1, 6 s round 3), shutters close again and numbers
are RE-ISSUED, so a player must leave the alcove and find the next one; the alcove they are in never
repeats. Being in an alcove when the train passes = survived that pass. Round 3 adds a "wrong-way"
train that comes from the near end without the lamp sweep, horn only.

**Roles.** All players are Walkers.

**Inputs.** WASD, `E` = `open {alcove}` at a shutter within 4 studs. `camStyle="top"` (long narrow
arena — kit camera helper needs a `follow` mode with the arena's long axis; note for the kit).

**Server / client split.** Server owns per-player clearance numbers, alcove numbering scramble (public),
train schedule (seeded), train CFrame tick, kill test (track cell + train interval), shutter states.
Sends `{kind="cl_number", n}` (private, tellOne), `{kind="cl_alcoves", labels=[...]}` (public),
`{kind="cl_horn", fromEnd, arrivesAt}` (public), `{kind="cl_shutter", alcove, open, userId}` (public — a
shutter opening reveals that alcove belongs to that player: legible for spectators, no strategic
value since numbers are per-player). Client renders shutters (tween), the train, the lamp sweep, HUD
number card.

**Win / loss / death.** No FINISH; ALIVE at time-out. Death = on track cell when the train's swept
interval covers your X: `gorefx power 1.8`, `ImpactBody`, text `STRUCK.`

**Ranking metric.** `ALIVE 1000 + passesSurvived*50 + firstOpenBonus` (first player to open on each
pass +5, cap 30) > `ELIMINATED 0 + passesSurvived*50` (cap 750).

**Pacing.** `ROUNDS.clearance = {[2]=2,[3]=2,[4]=2}`, `RoundSeconds.clearance = 50`.

**Arena.** 30x160 tunnel: floor `Wet Concrete`, track = two `Rust` rails + `Steel` sleepers (16
sleepers as long strips, not one per tie), 20 alcoves 5x5x8 recessed into `Concrete` walls, each with a
`Steel` shutter Part and a `Bone` number board, `Sodium` lamp Parts every 20 studs, `Signal` sweep lamps
per section. ~ 140 static parts.

**Dynamic props.** locomotive (1 Part 8x10x16 `Steel` + `Signal` neon lamp), reused between passes.

**SFX.** horn = gap -> `SFX.Warning` pitched 0.5 as placeholder; shutter = `Submit`; wrong shutter =
`AccessDenied`; pass = `MineExplosions.Explode3` pitched 0.4 as rumble; death = `ImpactBody` +
`Blood.Blood2`.

**Difficulty knobs.** train interval, train speed, telegraph length, number of active alcoves (10 -> 8
per side, some sealed), wrong-way trains.

**Exploits to guard.** `open` validated by distance and by the private number server-side; number
never appears in public packets; the train is a server interval sweep so lag cannot "phase" through it
(kill = any sampled position inside the swept X-range during the pass, with a 0.4-stud grace on the
alcove threshold); position bounds clamp to the tunnel.

**Pure-logic units (tests/clearance.lua).** `Alcoves.scramble(rng, n)`; `Issue.next(rng, used,
n) -> number` (never repeats last, unique per player per pass optional); `Train.sweep(x0, x1, t) ->
interval`; `Kill.test(pos, interval, alcoveMask)`; bands.

---

## 6. `carrier` — CARRIER

**Subtitle** `ONE OF YOU IS ALREADY SICK._`  **Tagline** `FIND THE NEEDLE. OR AVOID IT.`
**Icon** Bug. **Reference (docs only):** Inside Job.

**Core loop.** A dim open-plan office (desks, cabinets, partitions). At start one player is secretly
the CARRIER; the others are CLEAN. A syringe is hidden in one of ~14 searchable containers (`E` to
search, 0.8 s hold, container opens for everyone to see). Only the Carrier can pick up the syringe;
Clean players who search the right container merely reveal it (`Warning` sound for all, arrow shown to
Clean players — this is their weapon: knowing where it is, they can guard it or run). Holding the
syringe, the Carrier infects a Clean player by getting within 3 studs and pressing LMB (`stab`); the
victim becomes a Carrier too (they can now infect, no syringe needed, but at 5 studs cooldown 3 s).
Clean players win by staying Clean to the clock; Carriers win by infecting everyone. Clean players get
a "check" ability: `Q` on an adjacent player performs a 1.5 s stare that reveals `SICK`/`CLEAN` for the
checker only, once every 8 s — social deduction fits 2-4 players because everyone is always in view.
There is no death: the horror is quieter here. In 2-player sessions the Clean player has 25 s to hold
out and the arena is smaller (partition subset).

**Roles.** 1 Carrier (round-robin across rounds so every player carries at least once when
rounds >= players), rest Clean. Roles reassign per round; the Carrier seat advances like Bird's hunter.

**Inputs.** WASD, `E` search (hold), LMB `stab` (Carrier only), `Q` `check` (Clean only), `Shift`
crouch (`Crouch` clip; slower, hides you behind desks from the top-down camera's fog cutout — cosmetic
client-side, plus a server-side 20 % shorter stab range against a crouched target). `camStyle="top"`
with a reduced view radius (kit `camera.top({radius=22})`) so partitions matter.

**Server / client split.** Server owns roles, syringe container, infection state, cooldowns, checks.
Sends `{kind="cr_role", role="carrier"|"clean"}` (private), `{kind="cr_search", container, byUserId,
found}` (public), `{kind="cr_syringe", userId}` (public — the pickup is visible; the Carrier's identity
IS revealed by picking it up, which is the reference dynamic: search reveals the sick), `{kind="cr_infect",
victimUserId}` (public), `{kind="cr_check", targetUserId, sick}` (private to checker). Client renders
container open/close, syringe on hand (Prop attach to `RightHand`), stare beam, HUD role card.

**Win / loss / death.** No death. Clean at time-out = FINISHED (for Clean). Carrier score depends on
infections; original Carrier who infects everyone before time = FINISHED for Carrier.

**Ranking metric.** Clean survivors `2000 + secondsClean*1` (they all survive to the same second so
they tie unless one was infected — infected players `1000 + secondsClean*10` cap 600 => 1600 < 2000).
Original Carrier: `2000 + infections*200 - 0` if all infected, else `1000 + infections*200 +
secondsHeld*1` (secondsHeld = seconds holding the syringe, cap 60). Secondary Carriers: their infection
count adds `100` each on top of their infected-key. Full band table lives in the test.

**Pacing.** `ROUNDS.carrier = {[2]=2,[3]=3,[4]=2}`, `RoundSeconds.carrier = 45` (2p: 30).

**Arena.** 100x100 office: `Wet Concrete` floor, 12 desks (`Steel` top + `Rust` block), 10 partitions
(`Grime` 6 high), 14 searchable containers = filing cabinets/lockers/bins (`Steel`/`Bone` 2x2x4 with a
`Sodium` neon indicator that goes `Signal` when opened), corridor lamps. ~ 120 static parts.

**Dynamic props.** syringe (2 Parts), stare beam (client-only), open-state neon.

**SFX.** search = `Clicks.Click2` loop; found = `Warning`; pickup = `AccessGranted` (to Carrier),
`Reject` (to Clean who found it first); infect = `ImpactBody` + `Blood.Blood1` at low volume; check =
`Hover`; end = `Confirm`.

**Difficulty knobs.** container count, search hold, stab range/cooldown, check cooldown, view radius,
round seconds.

**Exploits to guard.** Roles private (tellOne only), syringe container private until searched;
`stab`/`check` distance validated server-side; `search` progress is a server timer cancelled on
movement; the Carrier's role is never inferable from any public packet before pickup.

**Pure-logic units (tests/carrier.lua).** `Roles.assign(rng, members, roundIndex)` (rotation
coverage); `Search.pick(rng, containers)`; `Infect.canStab(a, b, now, state)`; `Score.keys(state)`
band separation (Clean-survivor > infected, full-infection Carrier > partial).

---

## 7. `breather` — BREATHER

**Subtitle** `ONE CIGARETTE. THIRTY SECONDS. NOTHING ELSE._`  **Tagline** `INHALE. NOT TOO DEEP.`
**Icon** Factory. **Reference (docs only):** Smoke Break.

**Core loop.** Four players stand at the loading-dock railing under a `Sodium` lamp. Each holds a
cigarette (`Bone` stub with a `Signal` neon ember). Hold LMB to inhale: the ember brightens and the
cigarette length shrinks along a server-owned burn meter; release to exhale (a client-side puff of
`Bone` particles via 3 tiny Parts). A LUNG meter fills while inhaling and drains while exhaling; if it
tops out, the player COUGHS: 1.5 s stunned, the ember dims, and the burn meter loses 12 %. Finish the
cigarette (burn meter 100 %) before the 30 s clock. The Machine interrupts with a SUPERVISOR CHECK
(round 1: once; round 3: three times) — a `Warning` blip and the dock light going `Hazard` for 0.6 s
after which anyone still inhaling is caught (`Reject`, cigarette confiscated = eliminated for the round,
NOT killed). Round 3 also has "wind": burn rate randomly x0.6/x1.4 in 3 s gusts, shown by lamp flicker,
so the optimal inhale rhythm changes.

**Roles.** All players are Smokers.

**Inputs.** LMB hold = `inhale {on=true|false}` (edge packets, not per-frame). Optional `Space` = tap
ash (cosmetic, client only). No movement (characters anchored at the rail, `Idle` clip; a bespoke
smoke pose is an AnimationIds placeholder). `camStyle="rail"`: fixed frontal medium shot of the four
players (kit `camera.fixed`).

**Server / client split.** Server owns burn, lung, cough, supervisor schedule, wind. Sends
`{kind="br_state", userId, burn, lung, coughing}` at 8 Hz for everyone (small numbers, 4 players),
`{kind="br_check", at}` 0.6 s before the check, `{kind="br_caught", userId}`. Client renders the
ember, puffs, meters, dock lamp state.

**Win / loss / death.** FINISHED = burn 100 %. ELIMINATED = caught by supervisor (no gore; the round
text is `CONFISCATED.`). ALIVE = unfinished at 30 s. No death — deliberately the roster's one calm
round; the roulette should feel uneven, like the reference.

**Ranking metric.** `FINISHED 2000 + spareSeconds*10` > `ALIVE 1000 + burn*5` (cap 1499) >
`ELIMINATED 0 + burn*5` (cap 499).

**Pacing.** `ROUNDS.breather = {[2]=3,[3]=3,[4]=3}`, `RoundSeconds.breather = 30`.

**Arena.** 40x40 dock: `Concrete` slab, `Rust` railing (4 Parts), roll-up door `Steel` behind, one
`Sodium` lamp head Part with a `Hazard`/`Signal` neon state, ashtray drum `Rust`, night backdrop `Void`
wall. ~ 25 static parts.

**Dynamic props.** cigarettes (2 Parts each), puff Parts (client only).

**SFX.** inhale = `Hover` loop at low pitch; exhale = none; cough = gap -> `Reject` pitched 0.7 as
placeholder; check = `Warning`; caught = `AccessDenied`; finish = `Confirm`.

**Difficulty knobs.** lung fill/drain rates, cough penalty, supervisor count, wind, seconds.

**Exploits to guard.** inhale is an edge packet with server-side timing (client cannot claim burn);
rate limit 6 edges/s; a stuck `on` is auto-released after 4 s (lung tops out anyway); supervisor time
never sent before the 0.6 s telegraph.

**Pure-logic units (tests/breather.lua).** `Smoke.tick(state, dt, inhaling, wind)`; cough thresholds;
`Supervisor.schedule(rng, roundIndex, seconds)` (min spacing 5 s, never in the first 4 s); bands.

---

## 8. `sweep` — CLEAR THE DECK

**Subtitle** `THE PRESS ONLY WAITS FOR WEIGHT._`  **Tagline** `KEEP YOUR PLATE CLEAN.`
**Icon** Saw. **Reference (docs only):** Debris Platforms.

**Core loop.** Each player owns a 12x12 platform under a hydraulic press head. Debris (bricks, pipe
stubs, slabs — anchored Parts, no physics) drops from the ceiling onto random cells of every platform;
each piece adds WEIGHT to that platform's load meter. Players sweep debris off by walking into it and
pressing `E` (kick) — the piece slides off the platform edge (server tween) and the load drops. When
a platform's load crosses the threshold, its press arms and the head descends over 1.5 s (`Signal`
neon rim + `StandClear`), crushing that player unless the load is brought back under threshold before
contact (the head retracts). Debris rate rises over the round; heavy pieces (slabs, weight 3) need
two kicks. Round 2+ occasionally drops debris on a NEIGHBOUR's platform when you kick (kick direction
= toward the nearest edge; edges shared with a neighbour pass the piece over — the reference's grief
mechanic, kept because it makes 2-player rounds a duel).

**Roles.** All players are Sweepers.

**Inputs.** WASD, `E` = `kick` (nearest debris within 3 studs). `camStyle="top"`.

**Server / client split.** Server owns debris spawn schedule (seeded), per-piece cell + weight, load,
press state and kill. Sends `{kind="sw_drop", pieces=[{id,plat,cell,kind}]}`, `{kind="sw_kick", id,
dir, toPlat}` , `{kind="sw_load", loads={[userId]=n}}` at 5 Hz, `{kind="sw_press", userId, state}`.
Client renders debris Parts (pooled, <= 40 live), the fall (0.6 s tween from Y+25 with a `Hazard` shadow
disc on the target cell = telegraph so debris cannot land on your head unseen — a piece landing ON a
player just pushes them 2 studs, no damage), the press head tween.

**Win / loss / death.** No FINISH; ALIVE at time-out. Death = press contact: `gorefx power 2.0`,
`ImpactBody`, text `PRESSED.`

**Ranking metric.** `ALIVE 1000 + kicks*3 - peakLoad` (peakLoad <= threshold-1) > `ELIMINATED 0 +
secondsSurvived*10` (cap 600).

**Pacing.** `ROUNDS.sweep = {[2]=3,[3]=2,[4]=2}`, `RoundSeconds.sweep = 45`.

**Arena.** 70x70: four 12x12 `Steel` platforms in a 2x2 with 3-stud gutters (`Void` drop, `Grime`
walls), each with a `Rust` press frame (4 columns + a 12x12x3 `Steel` head with `Signal` neon rim),
ceiling hopper Parts. ~ 60 static parts.

**Dynamic props.** debris pool (40 Parts, three kinds: brick 1x1x2, pipe 1x1x4, slab 3x1x3).

**SFX.** drop = `Clicks.Click4`; kick = `Submits.Submit2`; slab land = `ImpactBody` low volume; press
arm = `StandClear` + `Warning` loop; kill = `MineExplosions.Explode4` pitched 0.5 + `Blood.Blood1`.

**Difficulty knobs.** spawn rate curve, threshold, press descent time, heavy-piece ratio, pass-over
enabled.

**Exploits to guard.** kick validated by distance to the piece's server cell; debris and press are
server tweens; load computed only from server state; player kept inside own platform AABB (clamped —
leaving your platform is impossible by design, so no "hide in the gutter").

**Pure-logic units (tests/sweep.lua).** `Debris.schedule(rng, seconds, players)`; `Load.sum(pieces)`;
`Kick.target(pos, pieces)`; `Kick.exitEdge(cell, platIndex) -> toPlat|nil`; `Press.tick(state, load,
dt)`; bands.

---

## 9. `crawler` — CRAWLER

**Subtitle** `IT WANTS A BACK TO BREAK._`  **Tagline** `DODGE IT. OR PASS IT ON.`
**Icon** Bug. **Reference (docs only):** Spine Breaker.

**Core loop.** A caged pit with a mechanical crawler (a 6-legged `Steel`/`Rust` block rig, ~14 Parts,
walking by CFrame keyframes on the server). It targets the nearest player, charges after a 0.9 s
wind-up (legs lift, `Signal` eyes, `Warning`) and LEAPS; a hit player is pinned. A pinned player mashes
`Space` (server counts edges, 8 needed) within 2 s or has their spine snapped (death). Any OTHER player
who reaches a pinned player and presses `E` throws the crawler off — the thrower gets to fling it
(mouse aim, LMB) at a target of their choice, and the crawler lands stunned 1 s then re-targets that
person first. So the game is a hot potato: save your rival to steer the machine at someone else, or
let them die. Round 3 adds a second, slower crawler. If everyone dies the round ends; alive at the clock
survives.

**Roles.** All players are Prey.

**Inputs.** WASD, `Space` mash = `struggle` (edge packets), `E` = `throwoff` (near pinned player),
mouse aim + LMB = `fling {dir}` (only while holding). `camStyle="top"`.

**Server / client split.** Server owns crawler AI (target, wind-up, leap arc as CFrame tween along a
parabola, pin, struggle count, fling), kills. Sends `{kind="cw_state", crawlers=[{id, pos, yaw, mode,
targetUserId}]}` at 12 Hz, `{kind="cw_pin", userId, need, have}`, `{kind="cw_hold", userId}`,
`{kind="cw_fling", id, from, to}`. Client renders the rig from pos/yaw/mode (leg cycle animation is
purely client-side CFrame wiggle keyed to `mode`), the struggle bar, the fling arc.

**Win / loss / death.** No FINISH; ALIVE at time-out. Death = pin timer expires: `Blood.Blood2` +
`gorefx power 1.5`, text `SPINE FAILED.`

**Ranking metric.** `ALIVE 1000 + saves*100 + escapes*50 + flingsLandedOnOthers*30` (cap 999 in
practice: assert) > `ELIMINATED 0 + secondsSurvived*10 + saves*100` (cap ~ 950 — clamp to 999).

**Pacing.** `ROUNDS.crawler = {[2]=3,[3]=2,[4]=2}`, `RoundSeconds.crawler = 40`.

**Arena.** 70x70 cage: `Wet Concrete` floor, `Rust` bars (12 flat panels, not individual bars),
`Void` beyond, four `Concrete` pillars as cover, `Sodium` lamps. ~ 40 static parts + rig 14 per
crawler.

**Dynamic props.** crawler rig(s), pin FX (client).

**SFX.** wind-up = `Warning`; leap = `Clicks.Click5` pitched 0.5; pin = `ImpactBody`; struggle tick =
`Clicks.Click1`; throwoff = `Submit`; fling land = `MineExplosions.Explode2` pitched 0.7; kill =
`Blood.Blood2` + `ImpactBody`. Gap: no servo/mechanical skitter loop — silent locomotion ships.

**Difficulty knobs.** wind-up, leap speed, struggle count, pin time, retarget delay, crawler count.

**Exploits to guard.** struggle edges rate-limited (max 15/s, count only server-timestamped edges >
40 ms apart); `throwoff` validated by distance to the pinned player; `fling` accepted only from the
holder within 3 s of throwoff, direction normalised server-side, range capped; crawler position is
server-owned.

**Pure-logic units (tests/crawler.lua).** `Ai.pickTarget(state, positions, exclude)`;
`Leap.arc(from, to, t)`; `Struggle.accept(lastEdge, now)`; `Fling.landing(from, dir, range, bounds)`;
bands.

---

## 10. `ricochet` — RICOCHET

**Subtitle** `THE BLADES DO NOT STOP AT WALLS._`  **Tagline** `WATCH THE ANGLES.`
**Icon** Saw. **Reference (docs only):** Lethal Rebound.

**Core loop.** A walled square. Circular saw blades are launched from wall slots (slot lights `Hazard`
for 0.8 s, then fires) and travel in straight lines at constant speed, reflecting off walls (angle in
= angle out) — pure 2D geometry the server steps analytically, no physics. Blades never stop; a new
one launches every 6 s (round 1) down to 3.5 s (round 3), and blade speed rises. Any player within a
blade's radius (2 studs) is bisected. Blades of the same speed never collide (they pass), which keeps
the field predictable — this is the roster's bullet-hell. Round 2 adds one "grinder" blade that
follows the perimeter wall clockwise at floor level, denying the corners. Because everything is
deterministic, the client can render blades from `{origin, dir, speed, launchTime}` alone and stay
in sync at any ping (predictable = fair).

**Roles.** All players are Targets.

**Inputs.** WASD; `Shift` = a 0.35 s dash on a 3 s cooldown (`dash {dir}` packet; server applies a
14-stud impulse to its own sampled position — the ONE movement modifier the server grants; movement
otherwise is standard). `camStyle="top"` full-arena (kit `camera.top({fixed=true})`).

**Server / client split.** Server owns blades (analytic reflect stepping in a 2D box), launches
(seeded), kill test, dash. Sends `{kind="rc_launch", id, origin, dir, speed, at}` once per blade (client
integrates locally), `{kind="rc_grinder", at, speed}` once, `{kind="rc_dash", userId, dir}` for others'
FX. Client renders blades (1 disc Part each + `Signal` neon rim), slot lamps, dash streak.

**Win / loss / death.** No FINISH; ALIVE at time-out. Death = blade contact: `gorefx power 1.7`,
`Blood.Blood1`, text `SPLIT.`

**Ranking metric.** `ALIVE 1000 + closeCalls*5` (blade passed within 4 studs without kill; cap 999) >
`ELIMINATED 0 + secondsSurvived*20` (cap 900). Round ends early when <= 1 alive.

**Pacing.** `ROUNDS.ricochet = {[2]=3,[3]=3,[4]=2}`, `RoundSeconds.ricochet = 45`.

**Arena.** 60x60 box: `Concrete` floor with a `Bone` painted grid (12 thin strips) so blade paths read,
`Steel` walls 6 high, 12 wall slots (`Void` recess + `Hazard` neon lamp), corner `Sodium` lamps.
~ 60 static parts.

**Dynamic props.** blades (<= 12 discs, pooled), grinder (1).

**SFX.** slot arm = `Warning`; launch = `SniperReload.Primary` pitched 1.3 as a mechanical clunk;
wall bounce = `BulletRicochet.Primary` (finally literal); death = `Blood.Blood1` + `ImpactBody`; dash =
`Clicks.Click5`. Gap: no saw whine loop — silent blades ship (the bounce sound carries the rhythm).

**Difficulty knobs.** launch interval, blade speed, blade count cap, grinder speed, dash cooldown.

**Exploits to guard.** Blades and kills computed from server sampled positions with the same analytic
step (client rendering can be wrong but cannot save you); dash is a server impulse with a server
cooldown; blade launches are seeded server-side and sent at launch (knowing them early gives nothing:
they are visible anyway).

**Pure-logic units (tests/ricochet.lua).** `Blade.at(blade, t) -> pos, dir` (reflection in an
axis-aligned box, exact for any t); `Blade.hitsCircle(blade, t0, t1, center, r)` (swept test between
ticks so fast blades cannot tunnel through a player); `Launch.schedule(rng, roundIndex, seconds)`;
`Grinder.at(t)`; bands.

---

## 11. `stacker` — PALLET DUTY

**Subtitle** `TWENTY SECONDS. STACK HIGH. DO NOT DROP._`  **Tagline** `HIGHEST STACK KEEPS THE JOB.`
**Icon** Factory. **Reference (docs only):** Forklift Certified.

**Core loop.** Each player drives a forklift (a 6-Part rig the server moves as a kinematic body: WASD =
throttle/steer with inertia, no Roblox vehicle physics) around a small yard with 12 crates. Drive the
forks under a crate, press `E` to lift (server checks fork alignment: crate within a 3x3 stud fork
zone in front and forks at crate height), drive to your PALLET (a marked 6x6 target), press `E` to
drop; the crate lands on your stack if the forklift is inside the drop zone, otherwise it drops where
it is (and cannot be re-lifted if it fell tilted — server marks it `spoiled`, `Rust` colour). Stacks
are pure integers: no physics; a stack of n crates is n Parts at n heights. Stack collapse rule: a stack
taller than 5 needs a "brace" (a second `E` press while lifted, +0.5 s) or the top crate falls off when
dropped. Crates are shared: 12 for up to 4 players in a 20 s round means fighting over crates. `Q`
raises/lowers the fork height (3 levels) — height must match the crate's level to lift and the stack's
top to drop.

**Roles.** All players are Operators.

**Inputs.** WASD = `drive {throttle, steer}` at 10 Hz (server integrates), `E` = `forks` (lift/drop
context), `Q` = `mast {level}`. `camStyle="top"` following the forklift rig (kit camera follows a
server-owned Model, not the character — note for the kit: `camera.top({subject=<instance>})`).
Characters are seated: parented into the rig's seat Part via `PivotTo` and anchored.

**Server / client split.** Server owns forklift kinematics (pos, yaw, speed), crate states (free/lifted/
stacked/spoiled), stacks, drop validation, brace. Sends `{kind="st_rig", rigs={[userId]={pos,yaw,mast}}}`
at 15 Hz, `{kind="st_crate", id, state, pos, level, ownerUserId}` per change, `{kind="st_stack",
userId, height}`. Client renders the rigs (interpolated), crates, drop-zone rings, mast level HUD.

**Win / loss / death.** No death (the Machine's cruelty here is time). At 20 s: highest stack wins.

**Ranking metric.** `1000 + stackHeight*100 - spoiledByYou*10 + firstToHeightBonus` (first to reach
each height +1, tiebreak only). Everyone is in one band; a 0-stack scores 1000. Ties share.

**Pacing.** `ROUNDS.stacker = {[2]=3,[3]=3,[4]=3}`, `RoundSeconds.stacker = 20`.

**Arena.** 90x90 yard: `Concrete` slab with `Hazard` painted lane strips (thin Parts), 4 pallet zones
(`Bone` 6x6 slabs with a `Sodium` neon post), `Steel` container walls as boundaries, `Rust` loading
gate. ~ 40 static parts.

**Dynamic props.** forklift rigs (6 Parts each: body `Hazard`, mast `Steel`, 2 forks, 2 wheels blocks,
seat), crates (12 x 1 Part `Grime` 3x3x3, `Rust` when spoiled).

**SFX.** lift = `Submit`; drop on stack = `Submits.Submit3`; spoiled drop = `Reject`; collision =
`ImpactBody` low volume; end horn = `Confirm`. Gap: forklift beep loop while reversing — none ships.

**Difficulty knobs.** crate count, brace height, yard size, forklift accel/turn rate, mast switch time.

**Exploits to guard.** Client sends only throttle/steer; server clamps both to [-1,1] and integrates
with fixed accel — no positions from the client; lift/drop validated by server geometry; crate ownership
server-only; two rigs colliding is resolved as elastic pushback in the server integrator (no physics).

**Pure-logic units (tests/stacker.lua).** `Kin.step(state, input, dt)` (bounded speed, yaw rate);
`Forks.canLift(rig, crate)`; `Forks.canDrop(rig, zone, stack)`; `Stack.drop(stack, braced) ->
newHeight, spoiled?`; `Rig.resolveOverlap(a, b)`; bands.

---

## 12. `sorting` — SORTING FLOOR

**Subtitle** `GOOD LEFT. BAD RIGHT. NO EXCEPTIONS._`  **Tagline** `MISFILE AND YOU FOLLOW IT.`
**Icon** Magnifier. **Reference (docs only):** The Filter.

**Core loop.** A conveyor carries items (parcels, cans, bones, bottles, syringes, batteries — 8 kinds
as small flat-colour Parts) past each player's sorting station. Above the floor a RULE board states the
current sort rule in the Machine's terms (`SEALED -> A. OPEN -> B.`, `METAL -> A. ORGANIC -> B.`,
`RED -> A. ALL ELSE -> B.`) and rules ROTATE without warning every 8-12 s (board flickers `Hazard`
for 0.5 s first — the telegraph). Each player has two chutes (A left, B right). Pressing `Q` sends the
item at their station to A, `E` to B; ignoring it lets it pass to the incinerator (a miss). Correct
sort = point; wrong sort = STRIKE, station lamp `Hazard`; three strikes = the station floor opens and
the sorter drops into the incinerator (death, telegraph: lamp goes `Signal` + `StandClear` 0.7 s
before the drop on the third strike). Item speed and rule complexity ramp per round; round 3 adds
two-attribute rules (`RED AND SEALED -> A`).

**Roles.** All players are Sorters.

**Inputs.** `Q` = `sort {itemId, chute="A"}`, `E` = `sort {itemId, chute="B"}`, `Space` = `pass` (explicit
pass gives no point but no strike, and clears the item early: skilled players pass ambiguous items).
No movement (anchored at station). `camStyle="station"`: fixed slight-top view of all four stations in a
row (kit `camera.fixed`).

**Server / client split.** Server owns the item stream (seeded; each item = kind + colour + sealed
flag), rule schedule, per-station current item, strikes, timing window (an item is "at" a station for
1.6 s round 1 -> 1.0 s round 3). Sends `{kind="so_rule", text, ruleId, at}` (public),
`{kind="so_item", id, station, attrs, arriveAt, leaveAt}` (public, ahead of time — the client tweens it
in), `{kind="so_result", userId, itemId, ok}` , `{kind="so_strike", userId, n}`. Client renders the belt
(static Parts + moving items pooled, <= 16 live), rule board, chutes, lamps.

**Win / loss / death.** No FINISH; ALIVE at time-out. Death = third strike (trapdoor: `gorefx power
1.3` at the incinerator, `Blood.Blood2`, text `MISFILED.`).

**Ranking metric.** `ALIVE 1000 + correct*10 - strikes*3` (cap 999: assert with the item budget) >
`ELIMINATED 0 + correct*10` (cap 990).

**Pacing.** `ROUNDS.sorting = {[2]=3,[3]=2,[4]=2}`, `RoundSeconds.sorting = 40`.

**Arena.** 60x60: `Wet Concrete` floor, one 50-stud `Steel` belt with `Rust` frame, four stations (each:
`Concrete` pad, `Steel` A/B chutes with `Bone` letters, `Sodium` lamp head, trapdoor Part), rule board
`Bone` with a `Hazard`/`Signal` neon frame, incinerator maw `Void` + `Signal` neon at the belt end.
~ 70 static parts.

**Dynamic props.** items (pool 16, one Part each in 4 shapes x palette colours), trapdoor state.

**SFX.** item arrive = `Clicks.Click3`; correct = `Submits.Submit1`; wrong = `Reject`; rule change =
`Warning`; strike 3 telegraph = `StandClear`; death = `MineExplosions.Explode1` pitched 0.5 +
`Blood.Blood2`.

**Difficulty knobs.** window seconds, rule change interval, two-attribute rules, item kinds count,
strike allowance.

**Exploits to guard.** `sort` accepted only for the item currently at the sender's station and inside
its window (server clock); rules never sent before the telegraph; item attrs are visible on purpose
(they are what you sort by), but the RULE is what changes and it is server-timed; rate limit 6/s.

**Pure-logic units (tests/sorting.lua).** `Rules.list` + `Rules.apply(rule, item) -> "A"|"B"`
(exhaustive over the item space); `Stream.generate(rng, seconds, speed, players)` (each station gets
the same count +-1); `Rules.schedule(rng, roundIndex, seconds)`; `Window.contains(item, now)`;
`Strikes.apply`; bands.

---

## 13. Roll-up tables for the Framework agent

### 13.1 Pacing rows (drop-in for `Pacing.ROUNDS` / `Pacing.RoundSeconds`)

| id | [2] | [3] | [4] | RoundSeconds | Death? |
|---|---|---|---|---|---|
| carve | 3 | 3 | 2 | 45 | yes (hood) |
| armory | 3 | 2 | 2 | 50 | no |
| upstream | 3 | 3 | 2 | 40 | yes (belt) |
| floorcheck | 3 | 3 | 2 | 35 | yes (drop) |
| clearance | 2 | 2 | 2 | 50 | yes (train) |
| carrier | 2 | 3 | 2 | 45 (2p: 30) | no |
| breather | 3 | 3 | 3 | 30 | no |
| sweep | 3 | 2 | 2 | 45 | yes (press) |
| crawler | 3 | 2 | 2 | 40 | yes (pin) |
| ricochet | 3 | 3 | 2 | 45 | yes (blade) |
| stacker | 3 | 3 | 3 | 20 | no |
| sorting | 3 | 2 | 2 | 40 | yes (trapdoor) |

Total scheduled play time per trial stays inside the envelope of the shipped three (Dead Zone 4x55 s
at 2p is the ceiling; nothing above exceeds 3x50 s). `carrier` in a 2-player session is a
duel-of-nerves; the alternative of "no Carrier round at 2p" was rejected because Playlist.order()
schedules ALL ids regardless of player count and a trial that self-skips would need a new gate.

### 13.2 `MachineFlow.TRIALS` entries (copy text exactly; `ready=false` until each trial's client ships)

```
{ id="carve",      displayName="CUT TO SPEC",    icon="Cube",      subtitle="MATCH THE TEMPLATE. THE BLOCK IS NOT FORGIVING._", tagline="CUT ONLY WHAT IS SHOWN." }
{ id="armory",     displayName="ARMS ISSUE",     icon="Crosshair", subtitle="PARTS ARE ON THE FLOOR. THE ISSUE IS NOT._",        tagline="COLLECT. ASSEMBLE. DISCHARGE." }
{ id="upstream",   displayName="UPSTREAM",       icon="Factory",   subtitle="THE STAIRS RUN DOWN. YOU RUN UP._",                 tagline="READ THE ARROWS. CLIMB." }
{ id="floorcheck", displayName="FLOOR CHECK",    icon="Cube",      subtitle="ONE PLATE HOLDS. THE REST GIVE WAY._",              tagline="STAND WHERE YOU ARE TOLD." }
{ id="clearance",  displayName="CLEARANCE",      icon="Train",     subtitle="THE LINE IS LIVE. FIND YOUR RECESS._",              tagline="OFF THE TRACK BEFORE THE HORN." }
{ id="carrier",    displayName="CARRIER",        icon="Bug",       subtitle="ONE OF YOU IS ALREADY SICK._",                      tagline="FIND THE NEEDLE. OR AVOID IT." }
{ id="breather",   displayName="BREATHER",       icon="Factory",   subtitle="ONE CIGARETTE. THIRTY SECONDS. NOTHING ELSE._",     tagline="INHALE. NOT TOO DEEP." }
{ id="sweep",      displayName="CLEAR THE DECK", icon="Saw",       subtitle="THE PRESS ONLY WAITS FOR WEIGHT._",                 tagline="KEEP YOUR PLATE CLEAN." }
{ id="crawler",    displayName="CRAWLER",        icon="Bug",       subtitle="IT WANTS A BACK TO BREAK._",                        tagline="DODGE IT. OR PASS IT ON." }
{ id="ricochet",   displayName="RICOCHET",       icon="Saw",       subtitle="THE BLADES DO NOT STOP AT WALLS._",                 tagline="WATCH THE ANGLES." }
{ id="stacker",    displayName="PALLET DUTY",    icon="Factory",   subtitle="TWENTY SECONDS. STACK HIGH. DO NOT DROP._",         tagline="HIGHEST STACK KEEPS THE JOB." }
{ id="sorting",    displayName="SORTING FLOOR",  icon="Magnifier", subtitle="GOOD LEFT. BAD RIGHT. NO EXCEPTIONS._",             tagline="MISFILE AND YOU FOLLOW IT." }
```
`showInterRoundScore=false` for all (matches the shipped three; the interim board after the trial is
enough at 20-50 s rounds).

### 13.3 Kit requirements harvested from the cards (for the TrialClientKit agent)
- `camera.top({radius=?, fixed=?, subject=<Instance>?})` — default follow (`carrier` needs the reduced
  radius, `ricochet` a fixed whole-arena view, `stacker` a non-character subject).
- `camera.fixed(cframe)` — `carve` (bench 3/4), `upstream` (side), `breather` (rail), `sorting`
  (station).
- `input.bindKey(key, onDown, onUp)` with edge semantics (`breather` inhale, `crawler` struggle),
  `input.bindMouse(onDown, onUp, aimProvider)` (`armory`, `crawler`), `input.arrows(cb)` (`upstream`).
- `send(action, data)` stamps `trialId` + `roundToken` and enforces the same per-action rate the
  server enforces so honest clients never trip the limit.
- `hud.meter(name)`, `hud.card(text, style)` (death cards use `style="death"` exactly like today),
  `hud.timer(endsAt)`.
- `palette` = the §0.5 table; `fx.flash(part, colour, seconds)` for telegraphs.

### 13.4 Packet `kind` vocabulary (prefixes so the dispatcher can route by prefix if it wants to)
`carve_*`, `armory_*`, `up_*`, `fc_*`, `cl_*`, `cr_*`, `br_*`, `sw_*`, `cw_*`, `rc_*`, `st_*`, `so_*`,
plus the shared `role`, `announce`, `count`, `go`, `gorefx`. Role packets always carry `roundToken`
and `camStyle`.

### 13.5 Audio gaps to record in docs/assets/ASSET-LEDGER.md (all have a shipping fallback above)
train horn (`clearance`), cough (`breather`), saw whine loop (`ricochet`), servo skitter (`crawler`),
forklift reverse beep (`stacker`), handgun report (`armory`), chisel tap (`carve`).
Music: `KenopsiaClient.updateTrialMusic()` plays `SoundService.KenopsiaAudio.Music.Trials.<activeTrialId>`
and has NO fallback today — a trial without a Sound of its name plays silence (verified in the client
source, lines 245-266). Until twelve original tracks exist, the Integrate agent should add
`Music.Trials.<id>` Sounds that reuse the `minefield` asset id for arena trials and the `birdhunt` asset
id for the calm ones (`breather`, `carrier`, `stacker`); no client change is needed for that.

### 13.6 Animation placeholders (single `AnimationIds` config module, degrade gracefully)
`Idle/Walk/Run/Crouch/Push` (exist as FBX; ids TBD by the user), plus new placeholder keys the cards
would use if published later: `Kick` (sweep), `Smoke` (breather), `Struggle` (crawler), `Stab` (carrier),
`Carve` (carve), `Sit` (stacker). Missing id => no animation, never an error.
