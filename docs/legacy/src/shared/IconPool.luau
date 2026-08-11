-- The game's shared vocabulary.
--
-- This is the single most important design decision in the project: RECALL and
-- THE LINE draw from the SAME icon list. The Machine shows you a symbol, and
-- later you are carrying the physical object that symbol meant. Players build
-- one mental dictionary and use it in every minigame, which is what stops this
-- from feeling like an unrelated pile of modes.
--
-- Source art: Documents\Retro\Item Icons - PSX Mega Pack, PSX Bunkers\Icons
-- Matching 3D models: Documents\Retro\PSX Bunkers\Models\FBX
--
-- HOW TO FILL THIS IN
--   1. Upload each PNG to Roblox (bulk upload works: Create > Development Items
--      > Decals, or drag into Studio's Asset Manager > Images).
--   2. Paste the returned id into `image` as "rbxassetid://123456789".
--   3. Leave `model` alone. It names a child of ReplicatedStorage.Items and the
--      game falls back to a generated placeholder block until that model exists.
--
-- Anything still holding image = "" is skipped by the pool, so the game runs
-- correctly with zero icons uploaded and gets richer as you add them.

local Types = require(script.Parent.Types)

local IconPool = {}

-- safe = false keeps an icon out of the random pool. The weapon icons ship in
-- the pack but a game aimed at a broad Roblox audience does not need them, and
-- keeping the moderation profile clean is worth more than four extra symbols.

local ICONS: { Types.Icon & { safe: boolean } } = {
	{ id = "ammo_box_1", label = "AMMO BOX", image = "", model = nil, safe = false },
	{ id = "battery_2", label = "BATTERY", image = "", model = nil, safe = true },
	{ id = "canned_food_1", label = "CANNED FOOD", image = "", model = nil, safe = true },
	{ id = "canned_food_2", label = "CANNED FOOD", image = "", model = nil, safe = true },
	{ id = "canned_food_3", label = "CANNED FOOD", image = "", model = "canned_food_3", safe = true },
	{ id = "canned_food_4", label = "CANNED FOOD", image = "", model = "canned_food_4", safe = true },
	{ id = "canned_food_5", label = "CANNED FOOD", image = "", model = "canned_food_5", safe = true },
	{ id = "cash_1", label = "CASH", image = "", model = nil, safe = true },
	{ id = "cassette_tape_1", label = "CASSETTE", image = "", model = nil, safe = true },
	{ id = "cassette_tape_2", label = "CASSETTE", image = "", model = nil, safe = true },
	{ id = "cell_phone_1", label = "PHONE", image = "", model = nil, safe = true },
	{ id = "cell_phone_2", label = "PHONE", image = "", model = nil, safe = true },
	{ id = "cigs_packet_1", label = "PACKET", image = "", model = nil, safe = false },
	{ id = "cpu_1", label = "PROCESSOR", image = "", model = "cpu_1", safe = true },
	{ id = "dosimeter_2", label = "DOSIMETER", image = "", model = nil, safe = true },
	{ id = "flashlight_1", label = "FLASHLIGHT", image = "", model = nil, safe = true },
	{ id = "flashlight_2", label = "FLASHLIGHT", image = "", model = nil, safe = true },
	{ id = "flashlight_3", label = "FLASHLIGHT", image = "", model = nil, safe = true },
	{ id = "floppy_disc_1", label = "DISKETTE", image = "", model = nil, safe = true },
	{ id = "floppy_disc_2", label = "DISKETTE", image = "", model = "floppy_disc_2", safe = true },
	{ id = "floppy_disc_3", label = "DISKETTE", image = "", model = "floppy_disc_3", safe = true },
	{ id = "floppy_disc_4", label = "DISKETTE", image = "", model = "floppy_disc_4", safe = true },
	{ id = "glass_bottle_1", label = "BOTTLE", image = "", model = nil, safe = true },
	{ id = "hand_saw_1", label = "SAW", image = "", model = nil, safe = false },
	{ id = "keycard_1", label = "KEYCARD", image = "", model = nil, safe = true },
	{ id = "key_2", label = "KEY", image = "", model = nil, safe = true },
	{ id = "kitchen_knife_1", label = "KNIFE", image = "", model = nil, safe = false },
	{ id = "mask_1", label = "MASK", image = "", model = nil, safe = true },
	{ id = "matchbox_1", label = "MATCHES", image = "", model = nil, safe = true },
	{ id = "meat_1", label = "RATION", image = "", model = nil, safe = true },
	{ id = "mre_1", label = "RATION PACK", image = "", model = "mre_1", safe = true },
	{ id = "nails_1", label = "NAILS", image = "", model = nil, safe = true },
	{ id = "pcb_scrap_1", label = "CIRCUIT SCRAP", image = "", model = "pcb_1", safe = true },
	{ id = "pills_bottle_1", label = "PILLS", image = "", model = nil, safe = false },
	{ id = "power_supply_1", label = "POWER UNIT", image = "", model = "power_supply_1", safe = true },
	{ id = "shotgun_1", label = "SHOTGUN", image = "", model = nil, safe = false },
	{ id = "shotgun_ammo_1", label = "SHELLS", image = "", model = nil, safe = false },
	{ id = "shotgun_ammo_2", label = "SHELLS", image = "", model = nil, safe = false },
	{ id = "vhs_tape_1", label = "VHS TAPE", image = "", model = nil, safe = true },
	{ id = "walkie_talkie_1", label = "RADIO", image = "", model = "military_radio_1", safe = true },
}

local byId: { [string]: Types.Icon } = {}
for _, icon in ICONS do
	byId[icon.id] = icon
end

IconPool.all = ICONS

function IconPool.byId(id: string): Types.Icon?
	return byId[id]
end

-- Icons eligible for the RECALL grid: safe, and actually uploaded.
function IconPool.playable(): { Types.Icon }
	local out = {}
	for _, icon in ICONS do
		if icon.safe and icon.image ~= "" then
			table.insert(out, icon)
		end
	end
	return out
end

-- Icons that can exist as a physical object in THE LINE. Falls back to every
-- playable icon when no models are imported yet, so the minigame is testable
-- before any art lands (it spawns labelled placeholder blocks instead).
function IconPool.carryable(): { Types.Icon }
	local withModels = {}
	for _, icon in ICONS do
		if icon.safe and icon.image ~= "" and icon.model then
			table.insert(withModels, icon)
		end
	end
	if #withModels > 0 then
		return withModels
	end
	return IconPool.playable()
end

-- Pick `count` distinct icons from `source` using a seeded Random so a round is
-- reproducible. Returns fewer than requested if the source is too small, which
-- is the expected state before all icons are uploaded.
function IconPool.sample(rng: Random, count: number, source: { Types.Icon }?): { Types.Icon }
	local pool = table.clone(source or IconPool.playable())

	-- Fisher-Yates, driven by the seeded Random rather than math.random so two
	-- servers with the same seed produce the same grid.
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local out = {}
	for i = 1, math.min(count, #pool) do
		out[i] = pool[i]
	end
	return out
end

return IconPool
