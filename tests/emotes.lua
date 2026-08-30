-- tests/emotes.lua -- Phase 5: proves Shared/Config/EmoteRegistry and
-- Shared/Config/MonetizationConfig outside Roblox. Both are PURE config, so a
-- desktop Lua 5.1 runs them as-is (the menu.lua / progression.lua pattern).
-- Run from the repo root: lua tests/emotes.lua
-- Exit code 0 only if every check passes (CI-friendly, the rules.lua pattern).
--
-- What this file is FOR, in one line each:
--   * an emote names its clip by KEY, never by asset id -- so it cross-loads
--     AnimationIds and asserts every animKey is a key of AnimationIds.Player;
--   * a placeholder is the documented dormant state -- a gamepass id of 0 is
--     never armed and can never be prompted, a clip id of 0 resolves to nil;
--   * ZERO PAY-FOR-POWER -- a deny-list over every grant key, so a grant that
--     tries to buy speed/damage/score/keys fails the gate before it ships;
--   * the ownership DECISION is pure and provable: default rows are free,
--     everything else requires ownership, and an unknown id fails CLOSED.

local CONFIG = "studio-src/ReplicatedStorage/Kenopsia/Shared/Config/"

-- Variant A (menu.lua): a pure module, no services, no Instance.
local function loadPure(file)
	local chunk = assert(loadfile(CONFIG .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

-- Variant B (animationids.lua): AnimationIds reads RunService at load time.
-- Offline both IsStudio and IsServer are false, which forces resolve() down the
-- PUBLISHED-id path -- the interesting case for a clip that is still a 0.
local function loadAnimationIds()
	local chunk = assert(loadfile(CONFIG .. "AnimationIds.luau"))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.Instance = {
		new = function(className)
			return { ClassName = className }
		end,
	}
	local services = {
		RunService = { IsStudio = function() return false end, IsServer = function() return false end },
		ServerStorage = { FindFirstChild = function() return nil end },
		KeyframeSequenceProvider = { RegisterKeyframeSequence = function() return nil end },
	}
	env.game = {
		GetService = function(_, name)
			return services[name] or {}
		end,
	}
	setfenv(chunk, env)
	return chunk()
end

local function readFile(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local Registry = loadPure("EmoteRegistry.luau")
local Money = loadPure("MonetizationConfig.luau")
local Anim = loadAnimationIds()

local failures, checks = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. tostring(detail)) or ""))
	end
end

-- EMOTE REGISTRY -- shape ------------------------------------------------------
print("\nEMOTE REGISTRY -- every row is well formed")

check(type(Registry.Emotes) == "table", "Emotes table exists")
check(type(Registry.SOURCES) == "table", "SOURCES set exists")
check(type(Registry.FIELDS) == "table", "FIELDS set exists")
for _, source in ipairs({ "default", "crate", "robux", "clearance" }) do
	check(Registry.SOURCES[source] == true, "SOURCES carries " .. source)
end

local ids = Registry.list()
check(type(ids) == "table" and #ids >= 1, "list() returns a non-empty array", #ids)
local sorted, dupes = true, false
local seen = {}
for i, id in ipairs(ids) do
	if i > 1 and ids[i - 1] > id then sorted = false end
	if seen[id] then dupes = true end
	seen[id] = true
end
check(sorted, "list() is sorted (a wheel renders the same on every server)")
check(not dupes, "list() has no duplicates")
local counted = 0
for _ in pairs(Registry.Emotes) do counted = counted + 1 end
check(counted == #ids, "list() covers every row", counted .. " rows vs " .. #ids .. " ids")

for _, id in ipairs(ids) do
	local row = Registry.Emotes[id]
	check(type(row) == "table", id .. ": row is a table")
	check(row.id == id, id .. ": row.id equals its table key", tostring(row.id))
	check(type(row.name) == "string" and row.name ~= "", id .. ": name is a non-empty string")
	check(type(row.animKey) == "string" and row.animKey ~= "", id .. ": animKey is a non-empty string")
	check(type(row.source) == "string" and Registry.SOURCES[row.source] == true,
		id .. ": source is one of SOURCES", tostring(row.source))
	check(type(row.rarity) == "string" and row.rarity ~= "", id .. ": rarity is a non-empty string")
	-- The closed field set is the ZERO PAY-FOR-POWER guard at the row level: a
	-- row that grows a `speedBonus` fails here, not in play.
	local extra = nil
	for key in pairs(row) do
		if Registry.FIELDS[key] ~= true then extra = key end
	end
	check(extra == nil, id .. ": carries no field outside FIELDS", extra)
	if row.source == "clearance" then
		check(type(row.clearance) == "number" and row.clearance >= 1
			and row.clearance == math.floor(row.clearance),
			id .. ": a clearance row names a positive integer band", tostring(row.clearance))
	else
		check(row.clearance == nil, id .. ": only a clearance row carries `clearance`")
	end
end

-- EMOTE REGISTRY -- the one shipped row ----------------------------------------
print("\nEMOTE REGISTRY -- dance_default is the free row Phase 5 ships")

local dance = Registry.get("dance_default")
check(type(dance) == "table", "dance_default is present")
check(dance ~= nil and dance.source == "default", "dance_default is source `default`",
	dance and dance.source or nil)
check(dance ~= nil and dance.animKey == "Dance", "dance_default plays the Dance clip",
	dance and dance.animKey or nil)
check(Registry.isDefault("dance_default") == true, "isDefault(dance_default) is true")
check(Registry.animKey("dance_default") == "Dance", "animKey(dance_default) is Dance")

-- EMOTE REGISTRY -- the ownership decision -------------------------------------
print("\nEMOTE REGISTRY -- requiresOwnership: default is free, everything else is not")

check(Registry.requiresOwnership("dance_default") == false,
	"a default row does not require ownership")
for _, id in ipairs(ids) do
	local row = Registry.Emotes[id]
	if row.source ~= "default" then
		check(Registry.requiresOwnership(id) == true,
			id .. " (" .. row.source .. ") requires ownership")
		check(Registry.isDefault(id) == false, id .. " is not default")
	end
end
-- FAIL CLOSED: an id nobody knows must never become free play.
check(Registry.requiresOwnership("no_such_emote") == true, "an unknown id requires ownership (fails closed)")
check(Registry.requiresOwnership(nil) == true, "a nil id requires ownership (fails closed)")
check(Registry.requiresOwnership(42) == true, "a non-string id requires ownership (fails closed)")
check(Registry.isDefault("no_such_emote") == false, "an unknown id is not default")
check(Registry.get("no_such_emote") == nil, "get(unknown) is nil")
check(Registry.get(nil) == nil, "get(nil) is nil, never a throw")
check(Registry.get(42) == nil, "get(number) is nil, never a throw")
check(Registry.animKey("no_such_emote") == nil, "animKey(unknown) is nil")

-- THE CLIP CONTRACT ------------------------------------------------------------
print("\nCLIPS -- an emote names a KEY of AnimationIds.Player, never an asset id")

check(type(Anim.Player) == "table", "AnimationIds.Player loaded")
for _, id in ipairs(ids) do
	local key = Registry.Emotes[id].animKey
	check(Anim.Player[key] ~= nil, id .. ": animKey `" .. key .. "` is a key of AnimationIds.Player")
	check(type(Anim.Player[key]) == "number" and Anim.Player[key] >= 0,
		id .. ": AnimationIds.Player." .. key .. " is a number >= 0 (0 = not published yet)")
	-- resolve() is the whole placeholder contract: a published clip is a
	-- "rbxassetid://<id>" string, an unpublished one is nil. NEVER a throw.
	local ok, uri = pcall(Anim.resolve, "Player", key)
	check(ok, id .. ": resolve(Player, " .. key .. ") never throws")
	check(uri == nil or (type(uri) == "string" and uri:sub(1, #"rbxassetid://") == "rbxassetid://"),
		id .. ": resolve is nil or a rbxassetid:// string", tostring(uri))
end
-- The dormant state, proven rather than asserted: force the shipped clip to a
-- placeholder and show that resolve degrades to nil, then restore it.
local realDance = Anim.Player.Dance
Anim.Player.Dance = 0
check(Anim.resolve("Player", "Dance") == nil, "a clip id of 0 resolves to nil (the dormant state)")
Anim.Player.Dance = realDance
check(Anim.resolve("Player", "Dance") == (realDance > 0
	and string.format("rbxassetid://%.0f", realDance) or nil), "the real Dance id restores cleanly")

-- AnimationIds is the ONLY file that may carry a hand-published id.
local registrySource = readFile(CONFIG .. "EmoteRegistry.luau")
local moneySource = readFile(CONFIG .. "MonetizationConfig.luau")
check(registrySource:find("rbxassetid://", 1, true) == nil,
	"EmoteRegistry contains no rbxassetid:// literal")
check(moneySource:find("rbxassetid://", 1, true) == nil,
	"MonetizationConfig contains no rbxassetid:// literal")

-- MONETIZATION -- shape --------------------------------------------------------
print("\nMONETIZATION -- every pass is well formed and every id ships at 0")

check(type(Money.PASSES) == "table", "PASSES table exists")
local passKeys = Money.list()
check(type(passKeys) == "table" and #passKeys >= 1, "list() returns a non-empty array", #passKeys)
local passSorted = true
for i = 2, #passKeys do
	if passKeys[i - 1] > passKeys[i] then passSorted = false end
end
check(passSorted, "PASSES list() is sorted")

local skus = {}
for _, key in ipairs(passKeys) do
	local pass = Money.PASSES[key]
	check(type(pass) == "table", key .. ": row is a table")
	check(type(pass.id) == "number" and pass.id >= 0 and pass.id == math.floor(pass.id),
		key .. ": id is a non-negative integer (0 = not created yet)", tostring(pass.id))
	check(type(pass.sku) == "string" and pass.sku:match("^[A-Z][A-Z0-9_]*$") ~= nil,
		key .. ": sku is UPPERCASE_UNDERSCORE", tostring(pass.sku))
	check(skus[pass.sku] == nil, key .. ": sku " .. tostring(pass.sku) .. " is unique")
	skus[pass.sku] = key
	check(type(pass.name) == "string" and pass.name ~= "", key .. ": name is a non-empty string")
	check(type(pass.grants) == "table", key .. ": grants is a table")
end

check(type(Money.PrivateServerPrice) == "number" and Money.PrivateServerPrice >= 0
	and Money.PrivateServerPrice == math.floor(Money.PrivateServerPrice),
	"PrivateServerPrice is a non-negative integer (0 = not set yet)", tostring(Money.PrivateServerPrice))

-- MONETIZATION -- ZERO PAY-FOR-POWER ------------------------------------------
print("\nMONETIZATION -- no grant may buy gameplay power, and no grant may sell crate keys")

-- Keys are matched as SUBSTRINGS, case-insensitively: `speedBoost`,
-- `scoreMultiplier` and `extraKeys` all have to fail, not just the bare word.
local DENY = {
	"speed", "damage", "score", "points", "health", "reach", "power", "boost",
	"multiplier", "advantage", "xp", "key", "fragment", "crate", "clearance",
}
local function scanGrants(node, path, hits)
	if type(node) ~= "table" then return end
	for k, v in pairs(node) do
		if type(k) == "string" then
			local lower = k:lower()
			for _, bad in ipairs(DENY) do
				if lower:find(bad, 1, true) then
					hits[#hits + 1] = path .. "." .. k .. " (matches '" .. bad .. "')"
				end
			end
			scanGrants(v, path .. "." .. k, hits)
		else
			scanGrants(v, path .. "[" .. tostring(k) .. "]", hits)
		end
	end
end
local hits = {}
for _, key in ipairs(passKeys) do
	scanGrants(Money.PASSES[key].grants, key .. ".grants", hits)
end
check(#hits == 0, "no grant key implies gameplay power or sells crate keys", table.concat(hits, ", "))
-- The deny-list itself has to work, or the check above is theatre. Substring
-- matching means one key can trip several entries (speedBoost hits `speed` AND
-- `boost`), so these assert "caught at all", not a hit count.
local function denyHits(node)
	local found = {}
	scanGrants(node, "proof", found)
	return #found
end
check(denyHits({ speedBoost = 2 }) >= 1, "the deny-list catches a camelCase power key (speedBoost)")
check(denyHits({ nested = { extraKeys = 1 } }) >= 1, "the deny-list recurses into nested grants (extraKeys)")
check(denyHits({ tint = "overseer", emotes = { "x" }, name = "y" }) == 0,
	"the deny-list passes a purely cosmetic grant untouched")

-- Every emote a pass grants must EXIST. Vacuous while both lists are empty;
-- the day a robux row is uncommented, this is what stops a dangling grant.
for _, key in ipairs(passKeys) do
	local granted = Money.grantedEmotes(key)
	check(type(granted) == "table", key .. ": grantedEmotes returns an array")
	for _, emoteId in ipairs(granted) do
		check(Registry.get(emoteId) ~= nil,
			key .. ": granted emote `" .. emoteId .. "` exists in EmoteRegistry")
	end
end
check(#Money.grantedEmotes("NO_SUCH_PASS") == 0, "grantedEmotes(unknown) is an empty array")
check(#Money.grantedEmotes(nil) == 0, "grantedEmotes(nil) is an empty array, never a throw")

-- And the reverse link: a `robux` row nobody sells could never be owned.
for _, id in ipairs(ids) do
	if Registry.Emotes[id].source == "robux" then
		local reachable = false
		for _, key in ipairs(passKeys) do
			for _, granted in ipairs(Money.grantedEmotes(key)) do
				if granted == id then reachable = true end
			end
		end
		check(reachable, id .. " (robux) is granted by some pass")
	end
end

-- MONETIZATION -- the placeholder contract -------------------------------------
print("\nMONETIZATION -- an id of 0 is never armed and can never be prompted")

for _, key in ipairs(passKeys) do
	if Money.PASSES[key].id == 0 then
		check(Money.armed(key) == false, key .. ": id 0 is NOT armed (dormant socket)")
	else
		check(Money.armed(key) == true, key .. ": a pasted id IS armed")
	end
end
check(Money.armed("NO_SUCH_PASS") == false, "armed(unknown) is false")
check(Money.armed(nil) == false, "armed(nil) is false, never a throw")
check(Money.passById(0) == nil, "passById(0) never matches a placeholder row")
check(Money.passById(nil) == nil, "passById(nil) is nil, never a throw")
check(Money.passById(-1) == nil, "passById(negative) is nil")
check(Money.passBySku("NOPE") == nil, "passBySku(unknown) is nil")
check(Money.passBySku(nil) == nil, "passBySku(nil) is nil, never a throw")
local firstKey = passKeys[1]
local firstSku = Money.PASSES[firstKey].sku
local foundKey, foundPass = Money.passBySku(firstSku)
check(foundKey == firstKey and foundPass == Money.PASSES[firstKey],
	"passBySku returns the key and the row itself, not a copy")

-- Arming is a config paste and nothing else: flip one id, prove the whole
-- surface wakes up, put it back.
local restore = Money.PASSES[firstKey].id
Money.PASSES[firstKey].id = 987654321
check(Money.armed(firstKey) == true, "pasting an id arms the pass (zero code change)")
local byId = Money.passById(987654321)
check(byId == firstKey, "passById finds the armed pass", tostring(byId))
Money.PASSES[firstKey].id = restore
check(Money.armed(firstKey) == (restore > 0), "the placeholder restores cleanly")
check(Money.passById(987654321) == nil, "the armed id is gone after the restore")

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("PHASE 5 EMOTES PROOF: FAIL")
	os.exit(1)
end
print("PHASE 5 EMOTES PROOF: PASS")
os.exit(0)
