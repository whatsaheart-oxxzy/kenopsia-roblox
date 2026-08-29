# Texture census (Task G2) — 29.08.2026

Read-only Studio census (studio 527862b7, Edit datamodel) of every texture asset
reference in the scanned containers. Reference kinds collected:
`MeshPart.TextureID`, `SurfaceAppearance` (ColorMap / MetalnessMap / NormalMap /
RoughnessMap), `Decal.Texture` / `Texture.Texture`, and `Sky` faces.
Deduplicated by numeric asset id.

## Totals

- **Unique asset ids: 115**
- **Total references: 913**
- No Decal/Texture instances reference assets in any scanned container (all
  texture refs are MeshPart.TextureID, SurfaceAppearance maps, or Sky faces).
- No MetalnessMap or RoughnessMap references exist anywhere — SurfaceAppearance
  usage is ColorMap (workspace MF_Shredder + metal_shelf/scanner) and NormalMap
  (ServerStorage MF_Compactor) only.

## Per-container counts

| Container | Refs | Unique ids | Note |
|---|---:|---:|---|
| workspace["Dead Zone"] | 556 | 54 | largest arena; fence/warehouse/shed kit |
| workspace["Bird Hunting"] | 239 | 34 | fence/stone/tree/wall kit |
| workspace.CanteenProtocol | 50 | 6 | Canteen_* prop meshes |
| workspace.MF_Shredder | 16 | 6 | all SurfaceAppearance.ColorMap |
| ServerStorage.KenopsiaAssets.Props | 32 | 12 | MF_Compactor: ColorMaps (shared with MF_Shredder) + 6 NormalMap ids |
| ServerStorage.KenopsiaAssets.Rigs | 10 | 2 | PS1Player + CanteenBoss body atlases |
| ReplicatedStorage.KenopsiaAssets | 1 | 1 | SniperRifle.Receiver (102060729071869) |
| StarterPlayer.StarterCharacter | 3 | 1 | PlayerNeutral atlas 136734973177857 on the 3 body MeshParts |
| Lighting (Sky only, outside task list but where Sky lives) | 6 | 6 | KenopsiaSky_PS1: one id per face Bk/Dn/Ft/Lf/Rt/Up |

ServerStorage.KenopsiaAssets has no children besides Props and Rigs.
Unique counts per container sum to >115 because ids are shared across
containers (e.g. MF_Shredder ColorMaps also appear in Props.Minefield.MF_Compactor;
the PlayerNeutral atlas appears in Rigs and StarterCharacter).

## Top 40 ids by usage

| # | Asset id | Usages | Example path | Kind |
|---:|---|---:|---|---|
| 1 | 130508216971392 | 73 | Workspace.Dead Zone.Model.fence_e_2_Node.fence_e_2_Node.fence_e_2 | MeshPart.TextureID |
| 2 | 133183271346242 | 73 | Workspace.Dead Zone.Model.fence_e_2_Node.fence_e_2_Node.fence_e_22 | MeshPart.TextureID |
| 3 | 138877202114055 | 73 | Workspace.Dead Zone.Model.fence_e_2_Node.fence_e_2_Node.fence_e_23 | MeshPart.TextureID |
| 4 | 137205326240424 | 55 | Workspace.Bird Hunting.fence_e_2.default | MeshPart.TextureID |
| 5 | 79669173388948 | 53 | Workspace.Dead Zone.fence_e_pillar_1_Node...fence_e_pillar_1 | MeshPart.TextureID |
| 6 | 103285742087007 | 53 | Workspace.Dead Zone.fence_e_pillar_1_Node...fence_e_pillar_12 | MeshPart.TextureID |
| 7 | 115786459061333 | 43 | Workspace.Bird Hunting.Stone 1.stone_3.stone_3_mesh | MeshPart.TextureID |
| 8 | 106313060356155 | 19 | Workspace.CanteenProtocol.Canteen_Mesh_Packaging_01... | MeshPart.TextureID |
| 9 | 122145178277948 | 16 | Workspace.Bird Hunting.Metal_crate.metal_crate_3_Node.metal_crate_3 | MeshPart.TextureID |
| 10 | 73206043398448 | 13 | Workspace.Dead Zone.Model.tree_stump_1...tree_stump_12 | MeshPart.TextureID |
| 11 | 87331348296243 | 13 | Workspace.Dead Zone.Model.tree_stump_1...tree_stump_1 | MeshPart.TextureID |
| 12 | 74133227102947 | 12 | Workspace.Bird Hunting.Tree 1.tree_9_Node.tree_9 | MeshPart.TextureID |
| 13 | 82114296687896 | 12 | Workspace.CanteenProtocol.Canteen_canned_food_4... | MeshPart.TextureID |
| 14 | 122729198033905 | 12 | Workspace.Bird Hunting.Wooden_pallet.wood_pallet_2_Node.wood_pallet_2 | MeshPart.TextureID |
| 15 | 128383841950004 | 12 | Workspace.Dead Zone.barricade_a_2_.barricade_a_2_Node.barricade_a_2 | MeshPart.TextureID |
| 16 | 70418612159947 | 11 | Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.warehouse_mx_27 | MeshPart.TextureID |
| 17 | 86116868270796 | 11 | Workspace.Bird Hunting.Wall with Stacheln...concrete_fence_hr_2 | MeshPart.TextureID |
| 18 | 120172127107072 | 11 | Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.warehouse_mx_25 | MeshPart.TextureID |
| 19 | 120715147610918 | 9 | Workspace.Bird Hunting.Wall with Stacheln...concrete_fence_hr_22 | MeshPart.TextureID |
| 20 | 125366711647259 | 9 | Workspace.Bird Hunting.Wall block.barricade_a_1_Node.barricade_a_1 | MeshPart.TextureID |
| 21 | 136734973177857 | 9 | ServerStorage.KenopsiaAssets.Rigs.PS1Player.Player_Body | MeshPart.TextureID (RIG ATLAS) |
| 22 | 79809317290433 | 8 | Workspace.Dead Zone...garage_door_hr_4_piece_2 | MeshPart.TextureID |
| 23 | 95461307433280 | 8 | Workspace.Dead Zone...garage_door_hr_3_piece_2 | MeshPart.TextureID |
| 24 | 98644177134566 | 8 | Workspace.Dead Zone.Model.Scene.warehouse_mx_1_Node.warehouse_mx_13 | MeshPart.TextureID |
| 25 | 113744907884599 | 8 | Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.warehouse_mx_26 | MeshPart.TextureID |
| 26 | 118399576525123 | 8 | Workspace.MF_Shredder.Intake_Funnel_Left.001.SurfaceAppearance | SA.ColorMap |
| 27 | 123700107354504 | 8 | Workspace.MF_Shredder.Shredder_Drum_Right.001.SurfaceAppearance | SA.ColorMap |
| 28 | 123818397411330 | 8 | Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.warehouse_mx_23 | MeshPart.TextureID |
| 29 | 98099973274478 | 7 | Workspace.Bird Hunting.metal_shelf.metal_shelf_2_Node.metal_shelf_22 | MeshPart.TextureID |
| 30 | 102434050747418 | 7 | Workspace.CanteenProtocol.Canteen_chair_wooden_1... | MeshPart.TextureID |
| 31 | 113762393139469 | 7 | Workspace.CanteenProtocol.Canteen_mre_1.Canteen_mre_1 | MeshPart.TextureID |
| 32 | 121035210748431 | 7 | Workspace.Bird Hunting.metal_shelf...metal_shelf_2.SurfaceAppearance | SA.ColorMap |
| 33 | 71357010760083 | 5 | Workspace.Dead Zone.fence_e_pillar_1_corner_Node...corner | MeshPart.TextureID |
| 34 | 96637947485228 | 5 | Workspace.Dead Zone.Van.van_3_Node.van_3 | MeshPart.TextureID |
| 35 | 106603599155918 | 5 | Workspace.Dead Zone.cement_bags_mp_1_pallet_1_Node...pallet_12 | MeshPart.TextureID |
| 36 | 106701748291066 | 5 | Workspace.Bird Hunting.Wall 1.wall_rg_1_Node.wall_rg_12 | MeshPart.TextureID |
| 37 | 116790276902060 | 5 | Workspace.Bird Hunting.Wall 1.wall_rg_1_Node.wall_rg_1 | MeshPart.TextureID |
| 38 | 130494134275606 | 5 | Workspace.Dead Zone.fence_e_pillar_1_corner_Node...corner2 | MeshPart.TextureID |
| 39 | 76241712040018 | 4 | Workspace.Dead Zone...door_hr_9_Node.door_hr_9 | MeshPart.TextureID |
| 40 | 77945868765427 | 4 | Workspace.MF_Shredder.Roadwheels_Left.001.SurfaceAppearance | SA.ColorMap |

Just below the cut (usage 4): BossNeutral atlas 130641113899237
(ServerStorage.KenopsiaAssets.Rigs.CanteenBoss.Boss_Body — RIG ATLAS, included
in AtlasTiers.luau as a 41st entry so the KEEP-1024 rule is data), plus ~30
more usage-4 warehouse/shed/door kit ids and the 6 MF_Compactor NormalMaps.

## Rig expression atlases (AnimationIds.Textures)

Source: `ReplicatedStorage.Kenopsia.Shared.Config.AnimationIds` lines 71-76 —
"the four expression atlases uploaded (1024, nearest-upscaled)" plus two boss
atlases. Swapped onto the body MeshParts at runtime by exact id:

| Name | Asset id | Static refs in census |
|---|---|---:|
| PlayerNeutral | 136734973177857 | 9 (Rigs.PS1Player ×6, StarterCharacter ×3) |
| PlayerBlink | 134298997425493 | 0 (runtime swap only) |
| PlayerHappy | 71841991124832 | 0 (runtime swap only) |
| PlayerHurt | 100549970137009 | 0 (runtime swap only) |
| BossNeutral | 130641113899237 | 4 (Rigs.CanteenBoss) |
| BossAngry | 88815675234840 | 0 (runtime swap only) |

## 512-twin candidates vs must-stay-1024

**Must stay 1024 (never tier):** the 6 expression atlas ids above. The faces
live on these sheets and need the resolution; additionally the runtime
expression swap in AnimationIds/consumers matches by exact master id, so a
tier swap would break blink/hurt/angry swaps.

**Prime 512-twin candidates (arena/prop textures — all other top-40 ids):**

- Fence kit (usages 53-73 each): 130508216971392, 133183271346242,
  138877202114055, 137205326240424, 79669173388948, 103285742087007 —
  ~380 refs combined; the single biggest win.
- Rocks/trees/crates/pallets: 115786459061333, 73206043398448, 87331348296243,
  74133227102947, 122729198033905, 122145178277948.
- Warehouse/shed/door kit (Dead Zone Scene): warehouse_mx_*, shed_ax_*,
  door/garage_door ids (usages 4-11 each, many ids — batch them).
- Canteen props: 106313060356155, 82114296687896, 102434050747418,
  113762393139469 (+ trash/mre/shelf usage<4 ids).
- MF_Shredder/MF_Compactor SurfaceAppearance ColorMaps: 118399576525123,
  123700107354504, 77945868765427, 87725144878576, 108233566552274,
  126730748699203. NormalMaps (72986386229200 etc.) are lower value — normal
  data survives downscale poorly; tier last, if at all.
- Sky faces (KenopsiaSky_PS1, 6 ids ×1): already PS1-styled; low priority,
  but safe to tier since sky detail is deliberately soft.
- SniperRifle Receiver 102060729071869: single ref, but it is the hunter's
  viewmodel seen up close — keep 1024 until a 512 twin is verified on-screen.

Tier data lives in `AtlasTiers.luau` (staged alongside this file, destination
`ReplicatedStorage.Kenopsia.Shared.Config.AtlasTiers`); every `low` is nil
until the 512 nearest-upscaled twins are published. Consumer ships in Phase 2
GradeDirector.
