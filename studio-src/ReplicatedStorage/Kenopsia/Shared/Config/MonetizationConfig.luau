--!nonstrict
-- MONETIZATION CONFIG (Phase 5) -- the paid surface as a socket. SHIPS DARK.
--
-- The CRT-hum placeholder pattern, verbatim from Badges.luau: every id below is
-- 0 until the user creates the item in Creator Hub and pastes the real id in.
-- An id of 0 is skipped SILENTLY -- never prompted, never warned, never thrown.
-- Until then this whole file is a dormant socket and arming it is a config
-- paste, zero code change and zero test change.
--
-- PURE CONFIG: no game:GetService, no Instance, no require, no yields. Every
-- MarketplaceService call lives in Services/EmoteService, pcall-wrapped.
-- tests/emotes.lua loads this file in plain desktop Lua 5.1.
--
-- ============================ THE THREE RULES ============================
--
-- 1. NO GAMEPLAY ADVANTAGE, EVER. Every grant is cosmetic: an emote clip, a
--    UI tint, a name plate. Nothing a pass gives may change a trial's outcome,
--    a score, a speed, a health pool, a timer or a spawn. The `grants` tables
--    below are checked against a DENY-LIST of keys in tests/emotes.lua
--    (speed / damage / score / points / health / reach / power / boost /
--    multiplier / advantage / xp / keys / fragments / crates), so a grant that
--    tries to buy power fails the offline gate before it can ship.
--
-- 2. CRATE KEYS ARE EARNED, NEVER SOLD IN MAINGAME. Keys come from WORK ORDERS
--    (Phase 4c: one fragment per completed quest, FRAGMENTS_PER_KEY = 5 roll
--    into a key at the verdict). `keys` / `fragments` / `crates` are on the
--    deny-list above precisely so this rule cannot rot by accident.
--
-- 3. THE PRIVATE SERVER PRICE IS SET ONCE AND NEVER CHANGED. Roblox lets a
--    creator raise or lower it, and every change is read by the people who
--    already bought one as a bait-and-switch. MASTERPLAN P5.4 records the
--    decision as "a FIXED price (never change it)"; the plan's recommendation
--    is 99 Robux. 0 below means NOT SET YET -- the number goes into Game
--    Settings, not into code; this constant only records what was chosen so a
--    later shop screen can print it without asking the API.
--
-- =========================================================================
local MonetizationConfig = {}

-- GAMEPASSES. `id` is the Creator Hub gamepass id -- 0 = not created yet.
-- `sku` is the STABLE internal name the client sends on ShopPrompt: ids change
-- when a pass is recreated, skus never do, and a sku carries no number a client
-- could invent. Uppercase-underscore, unique, asserted offline.
-- `grants.emotes` lists EmoteRegistry ids; every one of them must exist in the
-- registry (tests/emotes.lua fails the build otherwise) -- which is why both
-- lists ship EMPTY next to a commented example instead of pointing at a row
-- that is itself still commented out.
MonetizationConfig.PASSES = {
	OVERSEER = {
		id = 0, -- paste the Creator Hub gamepass id here to arm it
		sku = "PASS_OVERSEER",
		name = "OVERSEER CLEARANCE",
		-- Cosmetic only. `tint` is a palette key a later lobby/HUD pass reads;
		-- it changes colour and nothing else.
		grants = {
			emotes = {
				-- "overseer_salute", -- uncomment TOGETHER with its EmoteRegistry row
			},
			tint = "overseer",
		},
	},
	ARCHIVE = {
		id = 0, -- paste the Creator Hub gamepass id here to arm it
		sku = "PASS_ARCHIVE",
		name = "ARCHIVE ACCESS",
		-- Deliberately empty: the archive pass is a supporter badge with no
		-- grant decided yet. An empty grants table is a valid armed pass --
		-- buying it changes nothing but the owner's name plate.
		grants = {},
	},
}

-- Robux. 0 = NOT SET YET. Read rule 3 above before touching this number.
-- Recommended by the plan: 99.
MonetizationConfig.PrivateServerPrice = 0

-- True only for a pass whose id has actually been pasted in. EVERY consumer
-- asks this first; a false answer is a silent no-op, never a warn.
function MonetizationConfig.armed(key)
	local pass = type(key) == "string" and MonetizationConfig.PASSES[key] or nil
	return pass ~= nil and (tonumber(pass.id) or 0) > 0
end

-- key, row for a sku; nil, nil for anything unknown. The client only ever sends
-- a sku, so this is the whole trust boundary on the shop path.
function MonetizationConfig.passBySku(sku)
	if type(sku) ~= "string" then return nil, nil end
	for key, pass in pairs(MonetizationConfig.PASSES) do
		if pass.sku == sku then return key, pass end
	end
	return nil, nil
end

-- key, row for a live gamepass id; nil, nil for 0 and for anything unknown.
-- MarketplaceService hands back an id, never a sku, so the purchase-finished
-- path needs this direction too. An id of 0 must NEVER match a placeholder row.
function MonetizationConfig.passById(id)
	id = tonumber(id)
	if not id or id <= 0 then return nil, nil end
	for key, pass in pairs(MonetizationConfig.PASSES) do
		if (tonumber(pass.id) or 0) == id then return key, pass end
	end
	return nil, nil
end

-- Every pass key, SORTED (the EmoteRegistry.list rule: a dictionary has no
-- order and a shop that renders differently per server is a bug nobody reports).
function MonetizationConfig.list()
	local out = {}
	for key in pairs(MonetizationConfig.PASSES) do
		out[#out + 1] = key
	end
	table.sort(out)
	return out
end

-- The emote ids a pass grants, always an array (never nil), so callers loop
-- without a type check. Unknown key -> empty.
function MonetizationConfig.grantedEmotes(key)
	local pass = type(key) == "string" and MonetizationConfig.PASSES[key] or nil
	local grants = pass and pass.grants or nil
	local list = type(grants) == "table" and grants.emotes or nil
	if type(list) ~= "table" then return {} end
	local out = {}
	for _, id in ipairs(list) do
		if type(id) == "string" and id ~= "" then out[#out + 1] = id end
	end
	return out
end

return MonetizationConfig
