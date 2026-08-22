# QA — P3.3 PS1 rig as the player character, everywhere (22.08.2026)

Place 110672791536316. Studio live checks, one player, `TrialIds` narrowed to minefield and
restored afterwards. Commit: see git log ("P3.3").

## What changed

| Piece | Change |
|---|---|
| `StarterPlayer.StarterCharacter` (place) | `PS1Player` rig + Humanoid: `RootPart` → `HumanoidRootPart` lifted to hip level (3.95 rig units), the `Root` bone and the three Motor6Ds re-seated so every bone keeps its world pose; meshes non-colliding / non-queryable; invisible hit boxes `Head` (headshots — BirdHunting tests `hit.Instance.Name == "Head"`), `Torso`, `Legs`; Humanoid R15 type, `HipHeight 2.95` (soles sit at the old root level), `RequiresNeck false`, `BreakJointsOnDeath false`, JumpPower 0, no name/health display; attributes `KenopsiaPS1`, `XBotRig`. `StarterPlayer.LoadCharacterAppearance = false` (uniform silhouette). |
| `GameConfig.Character` | `{ UsePS1Rig = true, Scale = 0.69 }` — 8.72 rig studs × 0.69 = 6.0 studs, R15-sized for the arenas |
| `Services/CharacterService.luau` (new) | flag (removes the StarterCharacter at boot when off), per-spawn `ScaleTo` + hip height, jumping forbidden on every character, `XBotCrouch` remote created and mirrored onto the character as `Crouching` (gated on the trial's `XBotMoves` "sneak", cleared when the permission goes) |
| `StarterCharacterScripts/PS1Animate.client.luau` (new) | Idle / Walk (injured) / Run chosen by measured speed with `AdjustSpeed` against `AnimationIds.PlayerSpeeds` × scale (`RUN_AT` 7.5 st/s), Crouch while `Crouching`, Death once on Died; evicts Roblox's default R15 `Animate` (it is inserted even when the StarterCharacter carries one, and again after a teleport, before its children replicate) and stops any track that is not `Player/*` |
| `KenopsiaClient` | crouch toggle on keyboard C / Left Ctrl and gamepad B (same path as the touch button) |
| `Main.server.luau` | `CharacterService.start()` after `RoomService.start()` (Remotes folder) |

## Live checks

* Spawn: `KenopsiaPS1=true`, scale 0.69, HipHeight 2.04, soles exactly on the ground (body bottom 0.00 / ground 0.00), JumpPower 0, `Player/Idle` the only track, default `Animate` gone, `[PS1Animate] up` in the log.
* Minefield round, runner driven forward: v = 7.0 st/s (trial WalkSpeed 7) → `Player/Walk@2.17` the only track; `LeftUpperArm.Transform` / `LeftUpperLeg.Transform` change frame to frame (arms down from the A-pose, legs swinging) — the skinned mesh deforms under the Humanoid's Animator; top-down capture shows the PS1 figure in the corridor.
* Canteen unaffected: the diners are separate `PS1Player_Fork` clones.

## Lessons

* A StarterCharacter's own `Animate` LocalScript does not stop Roblox from inserting the default one — and the default R15 clips key the same bone names (`LowerTorso`, `LeftUpperArm`, …), so they DO deform this rig. Eviction + `Animator.AnimationPlayed` guard is the only reliable fence.
* `CharacterService` must start after `RoomService` (which creates `ReplicatedStorage.Kenopsia.Remotes`); the other order hung the whole boot on an infinite WaitForChild.
* The character's attributes may not be readable on the first frame of a StarterCharacterScripts LocalScript — wait for them.

## Open

* Crouch speed: the server only publishes `Crouching`; BirdHunting still has to slow a crouching runner (and the Crouch clip is a loop, frozen at frame 0 while standing still) — P4 tuning.
* Push (`XBotPush`) remote still has no server; the Push clip is unused.
* Death: `BloodFX.corpse` expects a `Beta_Joints` part and silently returns on this rig — the runner now plays the Death clip in place instead of a flying corpse. Decide per trial in P4.
* Hit boxes are static boxes around the hip root; a crouching character keeps the standing `Head` box (sniper headshots while sneaking) — move `Head` with the head bone later if it matters.
* 2-player check: other players' PS1 characters animate via replication of the Animator (not verified solo).
