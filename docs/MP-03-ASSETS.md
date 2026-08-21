# MP-03 — Asset inventory and integration plan (Agent 1c, 2026-08-17)

Read-only survey of the live place `Kenopsia_MainGame` (110672791536316, Edit
datamodel) plus the two Blender export folders and `docs/assets/ASSET-LEDGER.md`.
Nothing was modified. Numbers are studs, positions are world-space centres.

Companion docs: `ASSET-LEDGER.md` (licences — still authoritative for every
BLOCK/INF row), `C:\Users\Asus\Documents\Retro\PS1Player\ROBLOX_IMPORT_GUIDE.md`,
`C:\Users\Asus\Documents\Retro\TableManners\ROBLOX_IMPORT_GUIDE.md`.

---

## 1. Inventory

### 1.1 Rigs and animation source models (all loose in `Workspace`)

| Instance | Class | Contents | Position (centre) | Extents |
|---|---|---|---|---|
| `Player_Rig_scaleUnits` | Model (PrimaryPart `RootPart`) | `RootPart` Part 2x2x1 (feet, Y=53.3) holding 20 Bones `Root > LowerTorso > {UpperTorso > {Neck > Head > Ponytail1 > Ponytail2, LeftUpperArm > LeftLowerArm > LeftHand, RightUpperArm > RightLowerArm > RightHand, Prop_Bag}, LeftUpperLeg > LeftLowerLeg > LeftFoot, RightUpperLeg > RightLowerLeg > RightFoot}`; skinned MeshParts `Player_Body` (7.67x6.75x1.71, mesh 121596309152455), `Player_Head` (1.16x1.53x1.67, mesh 89019499333728), `Player_Bag` (0.37x0.66x0.72, mesh 90439124030871), all TextureID **136734973177857** (neutral atlas); 3 Motor6D `RootPart -> Player_*` (C0 body +3.375 Y, head +6.955 Y, bag (1.015, 4.6, 0.47)); `AnimationController` (no Animator child); `InitialPoses` folder (72 CFrameValues `*_Initial/_Original/_Composited`) | (-46.7, 56.7, 122.6) | 7.7 x 8.7 x 1.9 — **A-pose, 7.7 studs tall, feet at RootPart centre** |
| `Anim_Idle` / `Anim_Walk` / `Anim_Run` / `Anim_Crouch` / `Anim_Push` | Model | Identical copies of the rig (RBX_ReimportId differs) + `AnimSaves` ObjectValue -> `ServerStorage.RBX_ANIMSAVES.Anim_*` | stacked at (-46.7, 13.1 .. 48.0, 122.6) | same |
| `PS1Player_AllAnims` | Model | Same rig, `AnimSaves` -> `RBX_ANIMSAVES.PS1Player_AllAnims` (holds all 5 clips) | (-46.7, 4.4, 123.1) | same |
| `Boss_Rig_scaleUnits` | Model (PrimaryPart `RootPart`) | `RootPart` 2x2x1 with 19 Bones `Root > LowerTorso > {LeftUpperLeg.., RightUpperLeg.., UpperTorso > {LeftUpperArm > LeftLowerArm > LeftHand > Prop_Newspaper, RightUpperArm > RightLowerArm > RightHand > Prop_Pistol, Neck > Head}}`; skinned MeshParts `Boss_Body` 9.52x7.40x2.40 (mesh 120564744640037), `Boss_Head` 1.34^3 (140393163764203), `Boss_Newspaper` 2.64x1.70x0.49 (103717996765526), `Boss_Pistol` 0.22x0.88x1.13 (130680735362056), all TextureID **130641113899237** (neutral atlas); 4 Motor6D; `AnimationController`; `InitialPoses` | (-50.6, 4.8, 77.8) — 37 studs from the CanteenProtocol folder edge | 10.4 x 9.7 x 2.4 — standing A-pose, ~8.6 tall |
| `Sneak Walk`, `Injured Walking`, `Zombie Crawl` | Model | **No geometry** (0 BaseParts): 195 CFrameValues in `InitialPoses` + `AnimationController` + `AnimSaves` (Value = nil). Mixamo residue, unusable as-is; ledger says remove before release. | (0,0,0) | 0 |
| `SniperRifle_PSX` | Model (no PrimaryPart) | 1 MeshPart 16.8 x 3.11 x 1.51, mesh 95513591480496, TextureID 102060729071869, Anchored=false. **Long axis is +X**, not -Z. | (-285.3, 9.3, -589.8) | — |
| `bench`, `gear_mx_1`, `saw_blade` | Model | single MeshParts (PSX-pack props); `gear_mx_1`/`saw_blade` sit at (16, -55, -114) below the baseplate | — | tiny |

### 1.2 Animation saves — `ServerStorage.RBX_ANIMSAVES` (Model, 6 children)

| ObjectValue (Value) | KeyframeSequences inside | Length / frames | Loop | Priority | Poses |
|---|---|---|---|---|---|
| `PS1Player_AllAnims` -> `Workspace.PS1Player_AllAnims` | `Idle`, `Walk`, `Run`, `Crouch`, `Push` | 2.00 s/61, 1.00 s/31, 0.67 s/21, 2.00 s/61, 1.33 s/41 | all true | **Action** (guide wants Idle/Movement/Action) | 21 each (`PlayerRig` + 20 bones) |
| `Anim_Idle` .. `Anim_Push` -> `Workspace.Anim_*` | one KFS each, always named **`Scene`** | as above | true | Action | 21 |

**No published animation asset ids exist anywhere in the place** (no `Animation`
instances, no id attributes). The saves are editor drafts only. Nothing for the
Boss (Reading/Idle/LookUp/LookDown/Shoot/Death) has been imported yet.

### 1.3 Storage folders

| Path | Contents |
|---|---|
| `ServerStorage.KenopsiaAssets.Props.Minefield` | `MF_Mine`, `MF_Crater`, `MF_SonarRing`, `MF_Hunter_Shredder` (10 MeshParts + SurfaceAppearance) — the swap-in slot pattern used by Minefield |
| `ServerStorage.KenopsiaAssets.Props.BirdHunting` / `.CanteenProtocol` | **do not exist** — `BirdHunting.buildTurret` looks for `BH_Turret`, `CanteenProps.makeObserver` looks for `CP_Observer`; both fall back to procedural parts today |
| `ReplicatedStorage.KenopsiaAssets` | `Effects.Blood.BloodEffect` (+ config Values), `SniperRifle` (21-part procedural viewmodel, pivot at grip, barrel -Z), `MF_SonarRing` |
| `ReplicatedStorage.Kenopsia.Shared` | `Config.GameConfig`, `Rules.{Pacing,Playlist,Scoring}`, `Net.Envelope`. `Kenopsia.Remotes` is created at runtime by Main (absent at edit time). |
| `StarterPlayer` | `CharacterUseJumpPower=false`, `CharacterWalkSpeed=12`, `LoadCharacterAppearance=true`, CameraMode Classic, zoom 0.5..128. **No `StarterCharacter`** (default R15 avatars). `StarterPlayerScripts`: `KenopsiaClient`, `MachineLayout`, `GoreClient`. `StarterCharacterScripts`: `Health` (134 chars). |
| `StarterGui.KenopsiaMachine` | ScreenGui with Status/Score/Selection/Info/RoundCard/Briefing/JoinCover/CountText/Announce/Fader/Scope/HipCross/Warning/SettingsPanel/HitMark/TouchControls (Btn_FIRE/SCOPE/ZOOM/PUNCH/CROUCH/SCAN/EAT). Selection.IconPool already has icons `Cube, Magnifier, Crosshair, Saw, Factory, Utensil, Train, Bug` — reusable for new trial tiles. |
| `Workspace` misc | `Baseplate` 2048x16x2048 at (0,-8,0); `Terrain` (extents ~2044 around origin); Gravity 196.2; StreamingEnabled false; FallenPartsDestroyHeight -500; **no SpawnLocation** |

### 1.4 Audio — `SoundService.KenopsiaAudio` (live values, all present)

| Path | SoundId | Vol | Loop |
|---|---|---|---|
| `Music.Trials.birdhunt` | 71143122243344 | 0.24 | yes |
| `Music.Trials.minefield` | 132499516846518 | 0.45 | yes |
| `Music.Trials.canteen` | **missing** (ledger REQ-CP-04) | | |
| `Ambience` | empty folder | | |
| `SFX.Click` / `SFX.Hover` | 71275573444924 | 0.45 / 0.16 | |
| `SFX.ClickAlt` | 132164304600477 | 0.45 | |
| `SFX.ImpactBody` | 83335185987012 | 0.90 | |
| `SFX.Reject` | 114448879961050 | 0.70 | |
| `SFX.Warning` | 93861370808858 | 0.65 | |
| `SFX.Confirm` | 130292722664147 | 0.60 | |
| `SFX.Count5..1` | 117149096126658, 88984010858075, 125929365204512, 90490572986710, 132909621965246 | 0.75 | |
| `SFX.SniperFire.Primary` | 118803023612410 | 1.45 | |
| `SFX.BulletRicochet.Primary` | 83668417079973 | 1.10 | |
| `SFX.SniperReload.Primary` | 83110281478101 | 1.70 | |
| `SFX.Clicks.Click1..5` | 136898832673181, 136745293101522, 115728252091834, 111557351602976, 132683279963887 | 0.60 | |
| `SFX.Submits.Submit1..3` | 79171960825561, 111991322032307, 109725832591895 | 0.60 | |
| `SFX.MineExplosions.Explode1..4` | 86475991650982, 76737678985387, 71471343684752, 75789945781051 | 0.90 | |
| `SFX.Blood.Blood1..2` | 127560368697616, 86853838840785 | 0.85 | |

Note: the ledger lists `Music.Intro/Loop/Outro`, `SFX.Submit/SubmitAlt/AccessDenied/AccessGranted/StandClear` — those are **not** in this place any more (39 -> 34 Sounds). New trials should reuse pools (`Clicks`, `Submits`, `Warning`, `Confirm`, `Reject`, `ImpactBody`, `Count*`) and add per-trial folders `SFX.<Id>` only when unavoidable; every new upload is a ledger row.

### 1.5 Existing arena footprints (world AABB of all BaseParts)

| Folder | Min | Max | Parts | Key markers |
|---|---|---|---|---|
| `CanteenProtocol` | (-151, 0, -52) | (0, 34, 41) | 305 | `Rig` markers: `Seats.P1..4` (Y 12.3), `Observer` (-93, 20.3, -5.7) look +X, `ObserverCamera` (-63, 26, -5.4), `SpectatorCamera` (-93, 25.3, 20.3); Floor 88x1x81 at Y 0.5, Ceiling at Y 33.1; `Camera for Canteen` at (-63,26,-5.4) |
| `Dead Zone` | (-283, 0, -1942) | (-61, 51, -1535) | 400 | `Spawnpoint DeadZone` (-164.9, 1.9, -1637.4), `MineStartpoint` z -1660.8, `Exit` z -1919.4, `ShredderSpawnpoint` z -1539, `Cameraplacement` Y 16.7, `Minefield Ground` 45x1x375 |
| `Bird Hunting` | (-185, -6, 347) | (192, 97, 780) | 245 | `Start` (5.2, 1.5, 429) 42 wide, `Exit` (5.1, 1.1, 744.6), `SniperPost` (3.4, 41.6, 757.3) |
| Loose dev models | Boss rig (-50.6, 4.8, 77.8); player rigs (-46.7, 4..57, 122.6); rifle (-285, 9, -590) | | | |

Existing content therefore occupies roughly **X in [-290, 200], Z in [-1950, 800]**. Players with no SpawnLocation spawn near the origin, inside/next to the canteen box.

### 1.6 Lighting (the PS1 look)

`Ambient` (76,66,66) · `OutdoorAmbient` (106,94,94) · `Brightness` 1.2 · `ClockTime` 9.4 · `GlobalShadows` true · `ShadowSoftness` 0.2 · `FogColor` (44,22,20) · **`FogStart` 60 / `FogEnd` 480** · `EnvironmentDiffuseScale` 0 · `EnvironmentSpecularScale` 0 · `ExposureCompensation` 0 · no post-effects (no ColorCorrection/Bloom/Atmosphere) · `Sky KenopsiaSky` (6 face ids, `CelestialBodiesShown` false, SunAngularSize 0, StarCount 0). `Technology` is not readable from a plugin thread — check the Explorer manually; expect Compatibility/Voxel for the flat look.

Consequences for new arenas: anything past ~480 studs is fog-hidden, so far-apart arenas never see each other; SmoothPlastic + flat colours + these ambients already read as PS1; per-arena `PointLight`s are cheap accents, do not touch `Lighting` from trial code.

---

## 2. READY vs MANUAL

### 2.1 Ready to use from code now

- **Player rig geometry** (`Player_Rig_scaleUnits`): 3 skinned MeshParts, bones and texture all resolve; can be cloned into `ServerStorage.KenopsiaAssets.Rigs.PS1Player` and driven by an `Animator` under its `AnimationController` for cutscenes / NPC dummies. Without published ids it only shows the A-pose.
- **Boss rig geometry** (`Boss_Rig_scaleUnits`): same status. Static (unanimated) it is already usable as a visible "warden" prop.
- **`SniperRifle_PSX` mesh**: usable immediately as a world model (see section 4).
- **All 34 Sounds** (ids above) — reference by path via a small `Audio` helper, never by literal id in trial code.
- **`RBX_ANIMSAVES` KeyframeSequences** — readable by the Animation Editor; NOT usable at runtime (`Animator:LoadAnimation` needs a published `rbxassetid`; `KeyframeSequenceProvider:RegisterKeyframeSequence` produces a temporary hash id that only works in the local session/Studio and must not be shipped).
- Swap-in prop slots that already exist in code: `ServerStorage.KenopsiaAssets.Props.BirdHunting.BH_Turret` and `.CanteenProtocol.CP_Observer/CP_Fork` — dropping a Model there changes visuals with zero code.

### 2.2 MANUAL user steps (cannot be automated through MCP)

**M1 — Publish the five player clips (Animation Editor).**
1. In Studio select `Workspace.PS1Player_AllAnims` (it has an `AnimationController`; add an `Animator` child if the editor refuses the rig).
2. Avatar -> Animation Editor. The saves `Idle, Walk, Run, Crouch, Push` appear under Load (they live in `RBX_ANIMSAVES.PS1Player_AllAnims`). For each: check Looping ON, set priority via "..." -> Set Animation Priority: `Idle` = Idle, `Walk/Run/Crouch` = Movement, `Push` = Action (all five are currently saved as *Action*, which would fight each other), optionally add markers `Footstep` (Walk f0/f15, Run f0/f10) and `PushPulse` (Push f5/f25).
3. "..." -> Publish to Roblox -> Create new. Copy the id from the "Animation published" toast or Creator Dashboard -> Development Items -> Animations.
4. Enter ids in `AnimationIds.luau` (section 6). Animations are owned by the publishing account; the experience owner must be the same account or group or they play silently.

**M2 — Import + publish the six boss clips.**
Select `Workspace.Boss_Rig_scaleUnits`, Animation Editor -> "..." -> Import -> From FBX Animation -> `C:\Users\Asus\Documents\Retro\TableManners\export\anim\Anim_Reading.fbx` (then Idle, LookUp, LookDown, Shoot, Death). Looping ON for Reading/Idle only. Priority: Reading/Idle = Idle, LookUp/LookDown = Movement, Shoot/Death = Action. Add events (Show Animation Events): `LookUp` f11 `EyesUp`; `Shoot` f14 `PistolShow`, f28 + f36 `Fire`; `Death` f24 `DropPaper`. Publish each; ids into `AnimationIds.Boss`.

**M3 — Upload textures (Asset Manager -> Bulk Import, image).**
Already live: player neutral atlas 136734973177857, boss neutral atlas 130641113899237. Still to upload if the face-swap features are wanted: `PS1Player\export\Player_Atlas_Blink_1024.png`, `Player_Atlas_Happy_1024.png`, `Player_Atlas_Hurt_1024.png`; `TableManners\export\Boss_Atlas_Angry_1024.png`. Record ids in `AnimationIds.Textures` (same module keeps every hand-entered id in one place). Only `Player_Head.TextureID` / `Boss_Head.TextureID` are swapped at runtime.

**M4 — Housekeeping in the place (Integrate-stage agent may do the moves; deleting is the user's call).**
Move `Player_Rig_scaleUnits` -> `ServerStorage.KenopsiaAssets.Rigs.PS1Player`, `Boss_Rig_scaleUnits` -> `ServerStorage.KenopsiaAssets.Rigs.CanteenBoss`, `SniperRifle_PSX` -> `ReplicatedStorage.KenopsiaAssets.SniperRifle_PSX`. Keep `PS1Player_AllAnims` + `Anim_*` in Workspace **until M1 is published** (the Animation Editor resolves saves through the Workspace model), then delete them together with `Sneak Walk / Injured Walking / Zombie Crawl` (empty Mixamo shells) and the stray `gear_mx_1`, `saw_blade`, `bench`.

**M5 — Universe audio permission check** (ledger blocker 6) — play-test in a published DEV session; private audio fails silently.

---

## 3. StarterCharacter proposal

Facts that decide it: the live code only ever touches `HumanoidRootPart` and `Humanoid` (BloodFX, GoreClient, KenopsiaClient, all trials); the rig has no Humanoid and no `HumanoidRootPart`; the rig is 7.7 studs tall at import scale 1 (R15 default about 5); `StarterPlayer.LoadCharacterAppearance` is true; the five clips are in-place loops tuned for WalkSpeed 11-12 (Walk natural 4.5 st/s, Run 10.95, Push 3.15 at scale 1); the guide's `PS1Animate.luau` is a drop-in `Animate` LocalScript.

| Option | Pros | Cons |
|---|---|---|
| **A. Keep default R15, rig only for cutscenes/NPCs** | Zero risk to the three shipped trials; nothing blocks on M1; avatar loads instantly | Ships the generic Roblox avatar in a PS1 game (visual mismatch); Push/Crouch/Scan attributes (`XBotMoves`, `XBotCrawl`, `XBotRig`) keep driving nothing; each player looks different (silhouettes matter in top-down trials) |
| **B. Female rig as `StarterPlayer.StarterCharacter` (guide C1: Humanoid + invisible `HumanoidRootPart`, `HipHeight` 2.95 at scale 1)** | One uniform PS1 body for everyone; the five clips exist; `PS1Animate.luau` handles Idle/Walk/Run/Crouch/Push by speed; skinned mesh is 1440 tris; `LoadCharacterAppearance` can stay true (custom StarterCharacter ignores the avatar) | Blocks on M1 (until then everyone is a frozen A-pose); 7.7-stud body is 1.5x taller than R15 -> re-check every hard-coded eye/camera height (Minefield spawns at +4 above marker, BirdHunting hides the hunter and parks HRP at `eye - 3.2`, Canteen seats at Y 12.3) or import at 0.714 (~5.5 studs, HipHeight ~2.1) which the guide says requires re-importing the animations against that scale; needs an invisible `Head` part (or `Humanoid.CameraOffset`) for the default camera; GoreClient/BloodFX assume BaseParts on the character (a skinned body has three MeshParts — gore still works but "dismemberment" of R15 limbs will not); death ragdolls need a fallback |
| **C. Hybrid (recommended)** | Ship the 12 new trials against Humanoid+HRP only (no part-name assumptions, no R15-only APIs); keep default R15 in `main` until M1 ids exist; add the StarterCharacter in DEV first behind a `GameConfig.Character.UsePS1Rig` flag; the rig is used TODAY for the Boss/NPC roles and cutscenes | Two code paths for a while; the flag must be honoured by anything that reads part names |

**Recommended path (C):**
1. Now: keep default avatars in `Kenopsia_MainGame`. Every new trial obeys the rule "character == `HumanoidRootPart` + `Humanoid` only; height-dependent numbers come from `Humanoid.HipHeight` + `RootPart.Size.Y/2`, never from constants".
2. After M1: build `StarterCharacter` in `Kenopsia_DEV` exactly per guide C1 at **import scale 0.714** (feet-to-head about 5.5 studs, HRP 2x2x1 at feet+2.82, HipHeight 2.1, WalkSpeed stays 12 -> Run plays at ~1.5x, acceptable; re-import + re-publish the five clips at that scale so nothing else in the place moves). Add: invisible `Head` Part welded to `Player_Body` at feet+5.0 (camera focus), `Animate` LocalScript = `PS1Animate.luau` with `IDS` read from `AnimationIds`, `Massless` MeshParts, `CanCollide false` on meshes.
3. Wire `XBotMoves`-style attributes to the new Animate: `"sneak"` -> Crouch loop, `"push"` -> Push (already what KenopsiaClient/BirdHunting write). Rename these attributes to `KenopsiaMoves`/`KenopsiaRig` in the same pass (REQ-IP hygiene — "XBot" is a Mixamo name).
4. Promote to `main` only after all 15 trials pass QA with the flag on.

---

## 4. Sniper rifle / hunter in Bird Hunting

Current design (BirdHunting.luau "THE TOWER IS A MACHINE, NOT A POSED PLAYER"): the hunter's character is made fully transparent and parked at `SniperPost` (HRP at `eye - 3.2`), and a `SniperTurret` model (swap slot `ServerStorage.KenopsiaAssets.Props.BirdHunting.BH_Turret`, PrimaryPart at the mount, barrel down -Z) is aimed by the server; the client builds a first-person viewmodel from `ReplicatedStorage.KenopsiaAssets.SniperRifle` (scaled 0.62, pivot at grip, along -Z). **There is no aim clip for the female rig and none is planned in the export folder**, so a posed hunter would need new Blender authoring.

Recommendation — keep the turret, use `SniperRifle_PSX` in both slots, no pose work:
1. World: build `Model BH_Turret` = `Part Mount` (PrimaryPart, 1.6^3, invisible or DiamondPlate) + `SniperRifle_PSX` MeshPart. The mesh is authored along **+X** (16.8 long), so weld it with `CFrame.Angles(0, -math.pi/2, 0)` (barrel to -Z) and offset so the grip sits ~1 stud behind the mount and the barrel tip ~13 studs ahead; optionally `ScaleTo(0.75)` (12.6 studs — the tower parapet is 7 wide). All parts Anchored, CanCollide/CanQuery/CanTouch false (BirdHunting enforces this anyway). Put it at `ServerStorage.KenopsiaAssets.Props.BirdHunting.BH_Turret`.
2. Viewmodel: add an optional `ReplicatedStorage.KenopsiaAssets.SniperRifle_PSX` Model (same rotation wrapper, PrimaryPart `Grip` invisible part at the grip, LookVector -Z, and a child part named `Receiver` for the lamp). `buildViewmodel` currently hard-codes `SniperRifle`; extend it to `FindFirstChild("SniperRifle_PSX") or FindFirstChild("SniperRifle")` and skip the bolt-part animation when `BoltKnob/BoltStub` are absent (it already tolerates that). Test scale: the current 21-part rifle uses `ScaleTo(0.62)`; the PSX mesh at 16.8 studs wants ~0.35.
3. If a visible hunter body is ever wanted (Option B/C character): do **not** weld to `RightHand` — the rig has Bones, not limb parts. Use a `RigidConstraint` between an `Attachment` on the rifle grip and the `RightHand` Bone (Bone inherits Attachment, so `RigidConstraint.Attachment0 = Bone` works and follows skinning), and author a `SniperAim` clip in Blender against `PS1Player.blend`. Not needed for the current turret design.
4. Licence: the ledger already carries the sniper model as **BLOCK** (provenance); `SniperRifle_PSX` (mesh 95513591480496 / texture 102060729071869) needs its own row before Gate 7 — it looks like a PSX pack export, not a rebuild.

---

## 5. Boss rig and the Canteen Observer

How the Observer works today (`CanteenProps.luau`, `CanteenProtocol.luau`): the Observer is a server-only, raycasting state machine — `hidden` (raised 9 studs above the `Observer` marker at (-93, 20.3, -5.7)), `lowering` (the visible tell), `watching` (any moving eater in its cone gets executed by `ExecutionMuzzles.P1..4` at Y 30, straight down). Visual = procedural `Lens/Eye/Stalk` or an authored `CP_Observer` from `ServerStorage.KenopsiaAssets.Props.CanteenProtocol` (a `docs/assets/CP_Observer.fbx` + diffuse exists but is not imported). The camera `ObserverCamera` at (-63, 26, -5.4) looks -X across the table.

The Table Manners boss is a different concept (a seated warden with newspaper and pistol; clips Reading -> LookUp -> Shoot -> LookDown). It maps onto the Observer state machine one-to-one, so **augment, do not replace**:

| Observer state | Boss clip | Notes |
|---|---|---|
| hidden / between sweeps | `Reading` (loop) | newspaper up; head texture neutral |
| lowering (tell) | `LookUp` (0.37 s `EyesUp` event) | at `EyesUp` swap `Boss_Head.TextureID` to Angry (M3) |
| watching | `Idle` (loop) | |
| execution fired | `Shoot` (`PistolShow`, 2x `Fire`) | keep the muzzles as the actual damage source; sync `Fire` events with the existing muzzle flash/`SFX` |
| back to sweep | `LookDown` -> `Reading` | |
| trial end (all dead / round over) | optional `Death` (`DropPaper`) as a flourish only |

Implementation sketch: keep the Observer instance as the invisible authority (make its procedural parts `Transparency 1` when a boss is present, or set the `Lens` to the boss's head so raycasts originate from the boss's eyes) and add a `CP_Boss` swap slot in `ServerStorage.KenopsiaAssets.Props.CanteenProtocol` (the moved `Boss_Rig_scaleUnits` with an `Animator` under its `AnimationController`, MeshParts Anchored, `Boss_Newspaper.DoubleSided = true`). Add one marker `BossSeat` to `Workspace.CanteenProtocol.Rig` (extend `tools/build-canteen-arena.luau`, and `SOLO_MARKERS` in CanteenProtocol.luau if it should be validated) at the west head of `Canteen_table_large_3` (table centre (-93, 6.6, -5.7), 38.5 long in X): roughly (-115, floor, -5.7) looking +X toward the eaters and the ObserverCamera. The rig sits inside its animations (root drops ~0.65), so pivot = standing foot origin per guide B6; the canteen furniture is oversized (seat markers at Y 12.3), so expect `Model:ScaleTo(1.4..1.6)` — tune in Studio, then bake the number into the marker's attributes. Runtime uses `BossAnimator.luau` (in the export folder) as the reference; port it as `Services/CanteenBoss.luau` reading ids from `AnimationIds.Boss` — with all ids 0 it must still work: static A-pose, newspaper tip handled by the existing `paper` CFrame code path.

---

## 6. `AnimationIds` config module (design)

Location: `studio-src/ReplicatedStorage/Kenopsia/Shared/Config/AnimationIds.luau` (+ `default.project.json` entry). Shared so both the `Animate` LocalScript and server modules read the same table. Placeholder `0` = not published; the resolver returns `nil` and every caller degrades to "no animation" (never errors, never yields).

```lua
--!nonstrict
-- AnimationIds -- the ONLY place a hand-published animation/texture id lives.
-- 0 means "not published yet": resolve() returns nil and callers skip the clip.
-- (Animation ids come from Studio's Animation Editor > Publish; see docs/MP-03-ASSETS.md M1/M2.)
local AnimationIds = {}

AnimationIds.Player = {          -- rig: PS1Player (20 bones), loops in place, 30 fps
	Idle   = 0, -- 2.00 s, priority Idle
	Walk   = 0, -- 1.00 s, Movement, natural 4.5 st/s at scale 1
	Run    = 0, -- 0.67 s, Movement, natural 10.95 st/s
	Crouch = 0, -- 2.00 s, Movement (used for "sneak")
	Push   = 0, -- 1.33 s, Action, natural 3.15 st/s
}
AnimationIds.PlayerSpeeds = { Walk = 4.5, Run = 10.95, Push = 3.15 } -- for AdjustSpeed
AnimationIds.Boss = {            -- rig: CanteenBoss (19 bones)
	Reading = 0, Idle = 0, LookUp = 0, LookDown = 0, Shoot = 0, Death = 0,
}
AnimationIds.Textures = {
	PlayerNeutral = 136734973177857, PlayerBlink = 0, PlayerHappy = 0, PlayerHurt = 0,
	BossNeutral   = 130641113899237, BossAngry = 0,
}

function AnimationIds.resolve(group, name)
	local t = AnimationIds[group]
	local id = t and t[name]
	if type(id) ~= "number" or id <= 0 then return nil end
	return "rbxassetid://" .. id
end

-- Returns an AnimationTrack or nil. Caches Animation instances per (group,name).
-- Never throws: a missing id, a rig without Animator, or a LoadAnimation error all yield nil.
local cache = {}
function AnimationIds.load(animator, group, name)
	local uri = AnimationIds.resolve(group, name)
	if not (uri and animator) then return nil end
	local key = group .. "/" .. name
	local anim = cache[key]
	if not anim then
		anim = Instance.new("Animation"); anim.Name = key; anim.AnimationId = uri; cache[key] = anim
	end
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	return ok and track or nil
end

return AnimationIds
```

Rules: no other module contains `rbxassetid://` for animations; `tests/` gets a tiny proof that `resolve` returns nil for 0 and a string for a positive id; `selene`/`luau-lsp` clean.

---

## 7. Arena origin grid for the twelve new trials

Constraints: >= 400 studs from every existing footprint (X [-290, 200] x Z [-1950, 800]), >= 400 from each other, off the 2048 baseplate where possible so every arena builds its own floor (avoids seams and the fog-hidden baseplate edge), all far beyond FogEnd 480 from anything else. Grid: X in {1400, 1900, 2400}, Z in {-900, -300, 300, 900}; nearest existing content is >= 1200 studs away, neighbours 500-600 apart. Y = 0 is the arena floor top (each arena builds its own 1-stud slab at Y -0.5). Order = the twelve reference games in the shared-context list; ids are placeholders for the plan's mapping table (docs only).

```lua
-- GameConfig.Arenas.Origins (Vector3, floor level Y=0). Folder Workspace.KenopsiaArenas.<id>
Origins = {
	carve    = Vector3.new(1400, 0, -900), -- Chisel Gauntlet
	assemble = Vector3.new(1400, 0, -300), -- Firearm Factory
	escalate = Vector3.new(1400, 0,  300), -- Wrong Way
	footing  = Vector3.new(1400, 0,  900), -- Stable Footing
	tunnel   = Vector3.new(1900, 0, -900), -- Tunnel Hazard
	office   = Vector3.new(1900, 0, -300), -- Inside Job
	smoke    = Vector3.new(1900, 0,  300), -- Smoke Break
	press    = Vector3.new(1900, 0,  900), -- Debris Platforms
	spider   = Vector3.new(2400, 0, -900), -- Spine Breaker
	rebound  = Vector3.new(2400, 0, -300), -- Lethal Rebound
	forklift = Vector3.new(2400, 0,  300), -- Forklift Certified
	filter   = Vector3.new(2400, 0,  900), -- The Filter
}
```

Each arena must stay inside a 200 x 200 footprint around its origin (keeps a >= 300 gap at 500 spacing) and below Y 120. Nothing here overlaps `Dead Zone`, `Bird Hunting`, `CanteenProtocol` or the dev models. If the plan already fixes ids, keep the coordinates and rename the keys.

---

## 8. Open items for the ledger

- New rows needed: `SniperRifle_PSX` mesh/texture, `Boss_Rig` meshes (4) + atlas, `Player_Rig` meshes (3) + atlas (original Blender work — mark OK with the .blend as proof), `bench`/`gear_mx_1`/`saw_blade` (PSX pack, INF).
- `Music.Trials.canteen` still missing; new trials need either shared music or one loop each (each is an upload + ledger row).
- Ledger section 3 (XBot KeyframeSequences in `ReplicatedStorage.XBotAnimations`) is already stale for this place: that folder does not exist here; the `XBot*` attribute names survive only in code and should be renamed when the PS1 Animate script lands.
