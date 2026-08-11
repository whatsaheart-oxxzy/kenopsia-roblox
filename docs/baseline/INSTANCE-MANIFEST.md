# Phase 0 instance manifest — place `110672791536316`

Read-only capture. No instance was created, modified, or destroyed.
Every query was pinned with `placeId: 110672791536316`; all responses echoed
`requestedPlaceId == actualPlaceId == 110672791536316`.

Depth limits are stated per section. Where a section is depth-limited, that is
noted explicitly rather than implied.

---

## Workspace — 13 children

| Name | Class | Role |
|---|---|---|
| `Bird Hunting` | Folder | trial arena (234 children) |
| `Dead Zone` | Folder | trial arena (150 children) |
| `CanteenProtocol` | Folder | trial arena (78 children) — **set dressing only** |
| `Terrain` | Terrain | |
| `Camera` | Camera | |
| `Baseplate` | Part | |
| `Scene` | Model | |
| `tape_worm` | Decal | |
| `gear_mx_1`, `saw_blade` | Model | props |
| `Sneak Walk`, `Injured Walking`, `Zombie Crawl` | Model | **animation-source rigs left in the live Workspace** |

### `Workspace["Bird Hunting"]` — 234 direct children

All three code-referenced markers present:

| Marker | Class | Referenced by |
|---|---|---|
| `Start` | Part | `BirdHunting.refs()` |
| `Exit` | Part | `BirdHunting.refs()` |
| `SniperPost` | Part | `BirdHunting.refs()` |

Cover/geometry by count: `Stone 1` ×66, `fence_e_2` ×25, `Metal_crate` ×23,
`Wall block` ×18, `metal_shelf` ×12, `Wooden_pallet` ×12, `Tree 1` ×12,
`Wall 1` ×10, `Wall with Stacheln` ×10, `Wall with metal` ×7, `Tree LOg` ×6,
`Pillar` ×5, `Tree 3` ×4, `Wall` ×4 (Part), `Gravel` ×4, `Grass` ×3 (Part),
`Tower` ×3, `Tree Stump` ×3, `Tree 2` ×2, `floor_ceiling_hr_2_hole` ×1,
`Water Tower` ×1.

### `Workspace["Dead Zone"]` — 150 direct children

All six code-referenced markers present:

| Marker | Class | Referenced by |
|---|---|---|
| `Minefield Ground` | Part | `Minefield.refs()` / `buildGrid` |
| `Spawnpoint DeadZone` | Part | `Minefield.refs()` |
| `MineStartpoint` | Part | `Minefield.refs()` / grid origin |
| `Exit` | Part | `Minefield.refs()` / `Touched` |
| `Cameraplacement` | Part | `Minefield.refs()` / spectator cam |
| `ShredderSpawnpoint` | Part | `Minefield.refs()` / crusher origin |

Also present but **not referenced by any shipping script**: `GreenArea` ×2 (Part),
`VanWay` (Part), `Van` (Model), `Scanner for Scanning Mines` (Model),
`scanner_1_Node`, `sign_1_Node`, `military_radio_1_Node`, `generator_1_Node`.
Dressing by count: `fence_e_2_Node` ×61, `fence_e_pillar_1_Node` ×32,
`barricade_a_2_` ×12, `Scene` ×8, `tree_stump_1` ×8,
`fence_e_pillar_1_corner_Node` ×4, `jerrycan_mx_1_Node` ×3,
`debris_bricks_mx_1_Node` ×2, `water_tower_hm_1_Node` ×2,
`cement_bags_mp_1_pallet_1_Node`, `scrap_metal_mx_1_Node`, `stone_1`.

### `Workspace.CanteenProtocol` — 78 direct children

**No gameplay markers exist.** Required by the plan and absent: `Seat01..Seat04`,
`Plate01..Plate04`, `PeaAnchor01..PeaAnchor04`, `Camera02`, `Camera03`, `Camera04`,
`TableFocus`, `Inspector` (+ `Clipboard`, `BoltTool`, `Muzzle`).

Present instead: 8 × `Plate` (all identically named, so unaddressable by index),
1 × `Camera for Canteen`, `Canteen_table_large_3`, `Canteen_Mesh_Table_Rectangle_01`,
6 × `Canteen_chair_wooden_1`, 8 × `Floor lamp`, 12 × `Canteen_canned_food_4`,
`Canteen_canned_food_3`, 8 × `Canteen_mre_1`, 7 × `Canteen_Mesh_Packaging_01`,
6 × `Canteen_Mesh_Drinks_01`, 5 × `Canteen_trash_1`, 4 × `Canteen_Mesh_Cups_01`,
`Canteen_Mesh_Trolley_01`, `Canteen_Mesh_Trolley_04`, `Canteen_metal_shelf_1`,
4 × `Wall`, `Ceiling`, `Door Ceilin`, `Floor Canteen Protocol`.

---

## ReplicatedStorage — depth 4, fully enumerated

```
ReplicatedStorage
  Kenopsia                      Folder
    Shared                      Folder
      Config                    Folder
        GameConfig              ModuleScript
    (NO Remotes — see below)
  KenopsiaAssets                Folder
    Effects                     Folder
      Blood                     Folder
        BloodEffect             ModuleScript
        Enabled                 BoolValue
        ReduceGore              BoolValue
        LeaveStains             BoolValue
        Intensity               NumberValue
        MaxActive               IntValue
        StainedMaterialVariant  StringValue
    SniperRifle                 Model
    MF_SonarRing                Model
  XBotAnimations                Folder
    PublishedIds                ModuleScript
    SequencePlayer              ModuleScript
    Idle / Walk / Run / Jump / Punch / SweepFall / StandUp / Sit /
    SniperAim / SneakWalk / InjuredWalk / ZombieCrawl   (12 × KeyframeSequence)
```

The six `ValueBase` objects under `Blood` are read by `BloodEffect` through
`script.Parent`. Any Rojo mapping that puts a `$path` on the `Blood` **folder**
would delete them. The Phase 0 mapping therefore binds leaves only.

`PublishedIds` lists 10 asset IDs but `SequencePlayer` resolves clips by
`KeyframeSequence` **name** from the folder, not by asset ID — so `PublishedIds`
is not on the runtime path. It also has no entry for `InjuredWalk` or
`ZombieCrawl`, while both exist as KeyframeSequences.

### `ReplicatedStorage.Kenopsia.Remotes` — ABSENT in Edit

`Kenopsia` has exactly one child in Edit: `Shared`. There is **no `Remotes`
folder in the saved place**. It is created at runtime:

| Remote | Class | Created by |
|---|---|---|
| `RoomState`, `LobbyError`, `RoomCreateRequest`, `RoomJoinRequest`, `RoomQuickJoinRequest`, `RoomLeaveRequest`, `RoomReadyRequest`, `RoomStartRequest` | RemoteEvent | `RoomService.ensureRemotes()` |
| `MachineState` | RemoteEvent | `MachineFlow.start()` |
| `SniperFire` | RemoteEvent | `BirdHunting.ensureRemote()` |
| `SniperAim` | **UnreliableRemoteEvent** | `BirdHunting.ensureRemote()` |
| `TrialInput` | RemoteEvent | `Minefield.init()` and `TableManners.init()` (whichever runs first) |
| `GoreEvent` | RemoteEvent | `BloodFX` boot `task.spawn` |
| `XBotPush`, `XBotCrouch` | RemoteEvent | `XBotCharacters` (top-level, at require time) |

15 remotes total, none of which exist at rest. Any future static analysis or
manifest diff must expect them to appear only after a server boot.

---

## ServerScriptService — depth 2, fully enumerated

```
ServerScriptService
  KenopsiaServer          Folder
    Main                  Script
    XBotCharacters        Script
    Services              Folder
      RoomService / MachineFlow / BirdHunting /
      Minefield / TableManners / BloodFX      (6 × ModuleScript)
```

## ServerStorage

```
ServerStorage
  KenopsiaAssets          Folder
    Props                 Folder
      Minefield           Folder
        MF_Mine           Model   (unused: Minefield builds mines as invisible Parts inline)
        MF_Crater         Model   (used by Minefield.explode)
        MF_SonarRing      Model   (duplicate of the ReplicatedStorage copy the client clones)
```

40 descendants total; depth shown is 3, remaining depth is mesh/part geometry.

## SoundService.KenopsiaAudio — 50 descendants, depth 2 shown

```
KenopsiaAudio
  Music        Folder
    Intro / Loop / Outro          Sound
    Trials     Folder
      birdhunt                    Sound
      minefield                   Sound
      (NO tablemanners)
  Ambience     Folder
  SFX          Folder
    Click / ClickAlt / Submit / SubmitAlt / Reject / Hover /
    AccessDenied / AccessGranted / StandClear / Warning / Confirm /
    Count5 / Count4 / Count3 / Count2 / Count1 / ImpactBody      Sound
    Clicks / Submits / MineExplosions / Blood /
    SniperFire / SniperReload / BulletRicochet                   Folder (variant pools)
```

Depth-3 contents of the seven variant-pool folders were not enumerated.
**No Canteen audio of any kind exists**, and no sonar-ping SFX exists.

## StarterGui — 529 descendants, depth 2 shown

One ScreenGui, `KenopsiaMachine`, with 16 children — every name that
`KenopsiaClient` performs a `WaitForChild` on is present:

`Status`, `Score`, `Selection`, `Info`, `RoundCard`, `Briefing`, `JoinCover`,
`CountText` (TextLabel), `Announce`, `Fader`, `Scope`, `HipCross`, `Warning`,
`SettingsPanel`, `HitMark` (TextLabel), `TouchControls`.

Depth 3+ (individual buttons, rows, icon pools) not enumerated.

## Lighting — 1 child

`KenopsiaSky` (Sky). No `Atmosphere`, `ColorCorrection`, `Bloom` or other
post-effects at rest — `KenopsiaClient` creates a `ColorCorrectionEffect`
at runtime for Dead Zone and destroys it on exit.

## Players / StarterPlayer

| Property | Value | Note |
|---|---|---|
| `Players.MaxPlayers` | **60** | plan requires 4; `GameConfig.Players.MaximumPerServer` claims 28 — **three-way disagreement** |
| `StarterPlayer.StarterCharacter` | Model, `PrimaryPart = HumanoidRootPart` | custom XBot rig |
| `StarterPlayer.StarterCharacterScripts.Health` | Script | deliberately emptied |

Other `Players`/`StarterPlayer` scalar properties were not read individually;
`query_instances get` returns an empty `properties` array at Basic tier, so each
value costs one `manage_properties get` call.
