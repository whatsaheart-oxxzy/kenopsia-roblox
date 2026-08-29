--!nonstrict
-- ATLAS TIERS -- texture quality tiers for the master texture atlases.
--
-- CONTRACT. Every entry is keyed by the MASTER asset id (the 1024px texture
-- the place references today) and carries:
--     low   = number?  -- asset id of the 512px nearest-upscaled twin of the
--                      -- master, published separately. nil = no tier exists
--                      -- yet; the consumer MUST keep the master id then.
--     usage = number   -- static reference count from the 29.08.2026 census
--                      -- (MeshPart.TextureID / SurfaceAppearance maps /
--                      -- Decal.Texture / Sky faces across the three arenas,
--                      -- MF_Shredder, KenopsiaAssets and StarterCharacter).
--     note  = string   -- one example instance path using the id, plus the
--                      -- reference kind; "KEEP 1024" marks ids that must
--                      -- never be tiered (rig expression atlases -- the
--                      -- faces need the resolution, and AnimationIds.Textures
--                      -- swaps them at runtime by exact id).
--
-- CONSUMER. Ships in Phase 2 (GradeDirector): when the client decides the
-- session runs at low quality (mobile, or SavedQualityLevel low), it walks the
-- relevant textures and swaps master id -> lowFor(master id) wherever a low
-- twin exists. Until the twins are published every `low` stays nil and the
-- swap is a no-op -- missing tiers are never an error.
--
-- Pure data + one pure helper; Lua 5.1 portable so the offline proof can
-- require it (ids are < 2^53, exact as doubles). No other module hard-codes
-- a low-tier texture id.
--
-- Consumers iterating the table must skip non-number keys (lowFor).
local AtlasTiers = {}

-- Top ~40 master ids by static usage (census 29.08.2026, 115 unique ids
-- total), plus BossNeutral (rig atlas, listed so the KEEP-1024 rule is data).
AtlasTiers[130508216971392] = { low = nil, usage = 73, note = "Workspace.Dead Zone.Model.fence_e_2_Node.fence_e_2_Node.fence_e_2 (MeshPart.TextureID)" }
AtlasTiers[133183271346242] = { low = nil, usage = 73, note = "Workspace.Dead Zone.Model.fence_e_2_Node.fence_e_2_Node.fence_e_22 (MeshPart.TextureID)" }
AtlasTiers[138877202114055] = { low = nil, usage = 73, note = "Workspace.Dead Zone.Model.fence_e_2_Node.fence_e_2_Node.fence_e_23 (MeshPart.TextureID)" }
AtlasTiers[137205326240424] = { low = nil, usage = 55, note = "Workspace.Bird Hunting.fence_e_2.default (MeshPart.TextureID)" }
AtlasTiers[79669173388948] = { low = nil, usage = 53, note = "Workspace.Dead Zone.fence_e_pillar_1_Node.fence_e_pillar_1_Node.fence_e_pillar_1 (MeshPart.TextureID)" }
AtlasTiers[103285742087007] = { low = nil, usage = 53, note = "Workspace.Dead Zone.fence_e_pillar_1_Node.fence_e_pillar_1_Node.fence_e_pillar_12 (MeshPart.TextureID)" }
AtlasTiers[115786459061333] = { low = nil, usage = 43, note = "Workspace.Bird Hunting.Stone 1.stone_3.stone_3_mesh (MeshPart.TextureID)" }
AtlasTiers[106313060356155] = { low = nil, usage = 19, note = "Workspace.CanteenProtocol.Canteen_Mesh_Packaging_01.Canteen_Mesh_Packaging_01 (MeshPart.TextureID)" }
AtlasTiers[122145178277948] = { low = nil, usage = 16, note = "Workspace.Bird Hunting.Metal_crate.metal_crate_3_Node.metal_crate_3 (MeshPart.TextureID)" }
AtlasTiers[73206043398448] = { low = nil, usage = 13, note = "Workspace.Dead Zone.Model.tree_stump_1.tree_stump_1_Node.tree_stump_12 (MeshPart.TextureID)" }
AtlasTiers[87331348296243] = { low = nil, usage = 13, note = "Workspace.Dead Zone.Model.tree_stump_1.tree_stump_1_Node.tree_stump_1 (MeshPart.TextureID)" }
AtlasTiers[74133227102947] = { low = nil, usage = 12, note = "Workspace.Bird Hunting.Tree 1.tree_9_Node.tree_9 (MeshPart.TextureID)" }
AtlasTiers[82114296687896] = { low = nil, usage = 12, note = "Workspace.CanteenProtocol.Canteen_canned_food_4.Canteen_canned_food_4 (MeshPart.TextureID)" }
AtlasTiers[122729198033905] = { low = nil, usage = 12, note = "Workspace.Bird Hunting.Wooden_pallet.wood_pallet_2_Node.wood_pallet_2 (MeshPart.TextureID)" }
AtlasTiers[128383841950004] = { low = nil, usage = 12, note = "Workspace.Dead Zone.barricade_a_2_.barricade_a_2_Node.barricade_a_2 (MeshPart.TextureID)" }
AtlasTiers[70418612159947] = { low = nil, usage = 11, note = "Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.warehouse_mx_27 (MeshPart.TextureID)" }
AtlasTiers[86116868270796] = { low = nil, usage = 11, note = "Workspace.Bird Hunting.Wall with Stacheln.concrete_fence_hr_2_Node.concrete_fence_hr_2 (MeshPart.TextureID)" }
AtlasTiers[120172127107072] = { low = nil, usage = 11, note = "Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.warehouse_mx_25 (MeshPart.TextureID)" }
AtlasTiers[120715147610918] = { low = nil, usage = 9, note = "Workspace.Bird Hunting.Wall with Stacheln.concrete_fence_hr_2_Node.concrete_fence_hr_22 (MeshPart.TextureID)" }
AtlasTiers[125366711647259] = { low = nil, usage = 9, note = "Workspace.Bird Hunting.Wall block.barricade_a_1_Node.barricade_a_1 (MeshPart.TextureID)" }
AtlasTiers[136734973177857] = { low = nil, usage = 9, note = "ServerStorage.KenopsiaAssets.Rigs.PS1Player.Player_Body (MeshPart.TextureID) -- KEEP 1024: PlayerNeutral expression atlas (AnimationIds.Textures)" }
AtlasTiers[79809317290433] = { low = nil, usage = 8, note = "Workspace.Dead Zone.Model.Scene.warehouse_mx_1_Node.garage_door_hr_4_piece_2_Node.garage_door_hr_4_piece_2 (MeshPart.TextureID)" }
AtlasTiers[95461307433280] = { low = nil, usage = 8, note = "Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.garage_door_hr_3_piece_2_Node.garage_door_hr_3_piece_2 (MeshPart.TextureID)" }
AtlasTiers[98644177134566] = { low = nil, usage = 8, note = "Workspace.Dead Zone.Model.Scene.warehouse_mx_1_Node.warehouse_mx_13 (MeshPart.TextureID)" }
AtlasTiers[113744907884599] = { low = nil, usage = 8, note = "Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.warehouse_mx_26 (MeshPart.TextureID)" }
AtlasTiers[118399576525123] = { low = nil, usage = 8, note = "Workspace.MF_Shredder.Intake_Funnel_Left.001.SurfaceAppearance (SA.ColorMap)" }
AtlasTiers[123700107354504] = { low = nil, usage = 8, note = "Workspace.MF_Shredder.Shredder_Drum_Right.001.SurfaceAppearance (SA.ColorMap)" }
AtlasTiers[123818397411330] = { low = nil, usage = 8, note = "Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.warehouse_mx_23 (MeshPart.TextureID)" }
AtlasTiers[98099973274478] = { low = nil, usage = 7, note = "Workspace.Bird Hunting.metal_shelf.metal_shelf_2_Node.metal_shelf_22 (MeshPart.TextureID)" }
AtlasTiers[102434050747418] = { low = nil, usage = 7, note = "Workspace.CanteenProtocol.Canteen_chair_wooden_1.Canteen_chair_wooden_1 (MeshPart.TextureID)" }
AtlasTiers[113762393139469] = { low = nil, usage = 7, note = "Workspace.CanteenProtocol.Canteen_mre_1.Canteen_mre_1 (MeshPart.TextureID)" }
AtlasTiers[121035210748431] = { low = nil, usage = 7, note = "Workspace.Bird Hunting.metal_shelf.metal_shelf_2_Node.metal_shelf_2.SurfaceAppearance (SA.ColorMap)" }
AtlasTiers[71357010760083] = { low = nil, usage = 5, note = "Workspace.Dead Zone.fence_e_pillar_1_corner_Node.fence_e_pillar_1_corner_Node.fence_e_pillar_1_corner (MeshPart.TextureID)" }
AtlasTiers[96637947485228] = { low = nil, usage = 5, note = "Workspace.Dead Zone.Van.van_3_Node.van_3 (MeshPart.TextureID)" }
AtlasTiers[106603599155918] = { low = nil, usage = 5, note = "Workspace.Dead Zone.cement_bags_mp_1_pallet_1_Node.cement_bags_mp_1_pallet_1_Node.cement_bags_mp_1_pallet_12 (MeshPart.TextureID)" }
AtlasTiers[106701748291066] = { low = nil, usage = 5, note = "Workspace.Bird Hunting.Wall 1.wall_rg_1_Node.wall_rg_12 (MeshPart.TextureID)" }
AtlasTiers[116790276902060] = { low = nil, usage = 5, note = "Workspace.Bird Hunting.Wall 1.wall_rg_1_Node.wall_rg_1 (MeshPart.TextureID)" }
AtlasTiers[130494134275606] = { low = nil, usage = 5, note = "Workspace.Dead Zone.fence_e_pillar_1_corner_Node.fence_e_pillar_1_corner_Node.fence_e_pillar_1_corner2 (MeshPart.TextureID)" }
AtlasTiers[76241712040018] = { low = nil, usage = 4, note = "Workspace.Dead Zone.Model.Scene.warehouse_mx_2_Node.door_hr_9_Node.door_hr_9 (MeshPart.TextureID)" }
AtlasTiers[77945868765427] = { low = nil, usage = 4, note = "Workspace.MF_Shredder.Roadwheels_Left.001.SurfaceAppearance (SA.ColorMap)" }
AtlasTiers[130641113899237] = { low = nil, usage = 4, note = "ServerStorage.KenopsiaAssets.Rigs.CanteenBoss.Boss_Body (MeshPart.TextureID) -- KEEP 1024: BossNeutral expression atlas (AnimationIds.Textures)" }

-- 512px twin for a master id, or nil while none is published (or the id is
-- unknown / deliberately untiered). Pure; never throws.
function AtlasTiers.lowFor(id)
	local entry = AtlasTiers[id]
	if type(entry) ~= "table" then
		return nil
	end
	local low = entry.low
	if type(low) == "number" and low > 0 then
		return low
	end
	return nil
end

return AtlasTiers
