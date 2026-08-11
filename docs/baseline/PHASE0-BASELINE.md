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

### Verification level achieved

Line-count parity against Studio's reported `lineCount`: **19/19 pass**.

This is *not* the full byte-level zero-diff the plan's Phase 0 step 7 requires. At Basic
tier there is no hashing primitive in Studio (`execute_luau` is PRO), so a true zero-diff
requires re-reading all 6,263 lines and comparing. That pass has **not** been run and is
the first outstanding Phase 0 item.

## Instance manifest (partial)

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

### Not yet enumerated

`ReplicatedStorage.Kenopsia.Remotes`, `SoundService.KenopsiaAudio`, `StarterGui`,
`Lighting`, `ServerStorage.KenopsiaAssets`, and player settings. These remain outstanding
Phase 0 work.

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
`ReplicatedStorage.XBotAnimations` via `SequencePlayer`, not by asset ID.
