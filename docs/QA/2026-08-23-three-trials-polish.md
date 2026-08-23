# QA — three-trial polish after the user's 2-player test (23.08.2026)

User feedback → change → live check. Built by three parallel agents (Minefield / character clips +
Bird Hunting / Canteen) plus a gate reviewer; place-side markers and the final pushes by hand.

| Feedback | Change | Live check |
|---|---|---|
| Canteen camera too far and too low | `Rig.ObserverCamera` (+ `Camera for Canteen`) moved from 14 studs off the table at 12.75 to 13 studs at 15.0 (under the 15.66 ceiling), pitch 22° onto the table centre. The per-seat `PlayerCameras` were also re-aimed (over the right shoulder, 9.8 up) but the diners' view is the table camera. | capture: table fills the frame, boss at the head, 20 peas per plate |
| Peas sit too high | `PlateAnchors` −0.2 studs | pea centres 8.92 vs plate top 8.86 — on the plate |
| Canteen too fast, no tension, boss predictable | `Pacing.RoundSeconds.canteen` 45 → 60; `PEAS_TOTAL` 16 → 20 (`PEA_STEP` 50 → 40 to keep the band maths); boss hidden 2.5–9.0 s (was 2–4) from the seeded rng, **fake-outs** (p 0.3, 1.0–1.8 s, never twice in a row), watch window ramps 0.9–1.8 → 1.4–2.6 s over the round; lowering telegraph untouched | `[CP] go … peas=20`, `round over, elapsed=60.1` |
| **Bug found on the way:** from round 2 on the canteen was silently skipped ("arena invalid: P1 camera cannot see its plate - blocked by Head/Torso") | `validateArena` rays now ignore player characters and `CP_Props` — the parked, invisible avatars carry hit boxes since P3.3 | rounds 2+ run |
| Dead Zone players and mines too small | `GameConfig.Character.Scale` 0.69 → 0.9 (7.8 studs); sonar mine marks 1.6 → 2.56 studs (client `acquireMark`) | spawn scale 0.90 |
| Shredder must not detonate mines (blood on every screen) | mines the compactor front passes are CRUSHED: `live=false`, no explode/gore/sound/crater; armed (runner-triggered) mines still detonate and chain; round-over line prints `crushed=n` | `crushed=0` solo (runner died first) — code path reviewed |
| Shredder a bit slower | `Pacing.RoundSeconds.minefield` 55 → 62 → sweep 6.50 → 5.72 studs/s | `[DZ] … sweep 300 @ 5.72/s -> 62.0 s round; runner margin +20.1 s` |
| New clips: field death, crawl, injured walk | `AnimationIds.Player.DeathField/Crawl/InjuredWalk = 0` + `StudioSequences` ("Sweep Fall" / "Zombie Crawl" / "Injured Walking", sequence "mixamo.com"); **Studio bridge**: the server registers the saved sequences at warmup and publishes `StudioAnim_Player_<Name>` attributes on `ReplicatedStorage.Kenopsia`, the client's `AnimationIds.load` reads them when the published id is 0 | client loads Crawl 3.77 s, InjuredWalk 1.73 s, DeathField 1.73 s in Studio |
| Crawl after a mine knock | `Minefield`: `CRAWL_SPEED = 4.2` applied when `XBotCrawl` latches, restored at cleanup; `PS1Animate` plays Crawl while `XBotCrawl` | not reachable solo (direct step = kill); attribute path reviewed |
| Injured walking after a body shot | `BirdHunting`: `INJURED_SPEED = 7`, `Injured` attribute set on a non-lethal body shot, cleared at placement/teardown, never restored to 14 mid-leg; `PS1Animate` plays InjuredWalk while `Injured` and moving | needs a hunter + runner (2 players) |
| Field death clip | `PS1Animate` Died → `DeathField` (fallback `Death`) | runner killed by a mine: `Player/DeathField` playing |
| 4th minigame not wanted before release | `MachineFlow.TRIALS.sorting.ready = false` (code stays) | `1/15 … 3/15 trials ready` |

Offline gates: rules 84, trialrules 37, animationids 35, contexts 21, envelope 27, sorting 34 — all green; selene clean on every changed file (pre-existing warnings only). Parity verified for all 9 pushed scripts.

## Needs the user

* Publish the three clips under the group (like the others) and paste the ids → `AnimationIds.Player.DeathField / Crawl / InjuredWalk`. Until then they play in Studio only.
* 2-player: Bird Hunting injured walk + speed 7, Dead Zone crawl + crush (`crushed=n` in the log), canteen fake-outs in play.

## Addendum (23.08., later) — "no root": the Mixamo clips had to be retargeted

The user could not publish the three clips: the Animation Editor reported no root. Cause: the
saves under `Sweep Fall` / `Zombie Crawl` / `Injured Walking` are the importer's raw Mixamo
sequences — 52 `mixamorig:*` poses per keyframe — while the PS1 rig has 20 bones with Roblox
names (`Root`, `LowerTorso`, `UpperTorso`, `LeftUpperArm`, …). In Studio they "loaded" (length
> 0) but could never move the rig; the earlier "client loads Crawl 3.77 s" check only read
`track.Length`.

Fix (scratchpad `retarget.lua`, run in the Edit DataModel): world-rotation-delta retarget of
16 mapped bones (Hips→LowerTorso, Spine2→UpperTorso, Neck, Head, Arm/ForeArm/Hand,
UpLeg/Leg/Foot per side) with a per-bone rest alignment (the rig is A-pose, Mixamo T-pose),
a 180° yaw fix (Mixamo faces +Z after import, the rig −Z), hips translation scaled by hip
height (3.95 studs / 99.8 cm = 0.0396) and rebased — linear XZ trend removed for the two loops,
first-frame XZ removed for the death (it keeps its 2.5-stud forward fall). Source rest pose from
the husks' `InitialPoses/*_Initial` (parent-relative binds, cm), target rest from the rig's
`Bone.WorldCFrame`.

Result: `Workspace.Anim_FieldClips` (clone of `Player_Rig`, 20 studs to the left of it) with
the save holder `ServerStorage.RBX_ANIMSAVES.Anim_FieldClips` → `DeathField` (53 kf, 1.73 s,
one-shot, hips end 0.55 above the floor), `Crawl` (114 kf, 3.77 s, loop, hips 0.64 above the
floor), `InjuredWalk` (53 kf, 1.73 s, loop). Pose tree `RootPart → Root → LowerTorso → …`
exactly like the published Blender clips. Captures of the posed rig: death end = lying flat,
crawl = prone with arms forward, injured = hand clutching the side while limping. Play check:
with `XBotCrawl` set the character's `LowerTorso.Transform.Y` reads −2.98 (= −3.31 × scale 0.9)
— the retargeted clip drives the real character.

`AnimationIds`: `StudioSequences` now point at `Anim_FieldClips`; `PlayerSpeeds.Crawl 2.26`,
`InjuredWalk 3.49` measured from the removed hips trends (8.50 studs / 3.77 s, 6.05 / 1.73 s).
`tests/animationids.lua` updated (35 green). Pushed with parity: AnimationIds 12070/2065416073,
PS1Animate 5265/24479636.

**User:** Animation Editor → rig `Anim_FieldClips` → Load `DeathField` / `Crawl` / `InjuredWalk`
→ Publish to Roblox with the group as creator → paste the ids into `AnimationIds.Player`.
The raw `mixamo.com` saves and the three husk models can be deleted afterwards.

**Published 23.08. (evening), group creator:** DeathField 137420901214756, Crawl 102977383488004,
InjuredWalk 109198821545630 → `AnimationIds.Player`; the field death starts at 0.6 s
(`AnimationIds.PlayerStart.DeathField`, applied in PS1Animate after Play). Live: all three load with
their full length on the player's Animator (1.73 / 3.77 / 1.73 s); 0.35 s after `Health = 0` the death
track reads TimePosition 0.95. Parity AnimationIds 12384/620771988, PS1Animate 5517/299047822.
