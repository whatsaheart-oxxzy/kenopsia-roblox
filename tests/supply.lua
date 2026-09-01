-- tests/supply.lua -- Supply screens: proves Shared/Config/SupplyConfig and
-- Shared/Rules/CrateRules outside Roblox (the tests/emotes.lua sandbox).
-- Run from the repo root: lua tests/supply.lua
-- Exit code 0 only if every check passes.
--
-- What this file is FOR, in one line each:
--   * the palette is the MACHINE set verbatim -- no third palette, no new hue,
--     and the two reserved colours (FIRE red, crosshair bone) never appear;
--   * the crate economy is provable: odds always sum to 100 over the rarities
--     actually present, a roll can only land inside the unowned crate pool,
--     and the reel the client animates carries the server's result at a fixed
--     index -- the spec's "server decides, client animates" rule as asserts;
--   * every player-facing string is SHOUTED, the machine voice rule.

local CONFIG = "studio-src/ReplicatedStorage/Kenopsia/Shared/Config/"
local RULES = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"

-- The menu.lua pattern: a pure module, no services, no Instance.
local function loadPure(path)
	local chunk = assert(loadfile(path))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.require = function(m)
		return m
	end
	setfenv(chunk, env)
	return chunk()
end

local function readFile(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local Supply = loadPure(CONFIG .. "SupplyConfig.luau")
local Crate = loadPure(RULES .. "CrateRules.luau")
local Promo = loadPure(RULES .. "PromoRules.luau")
local Registry = loadPure(CONFIG .. "EmoteRegistry.luau")
local Progression = loadPure(RULES .. "ProgressionRules.luau")

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

-- PALETTE -- the machine set, nothing else -------------------------------------
print("\nSUPPLY CONFIG -- palette is the machine set verbatim")

local P = Supply.Palette
check(type(P) == "table", "Palette exists")
check(P.BG == "020602", "BG is the machine screen ground", P.BG)
check(P.PLATE == "041005", "PLATE is the machine tile ground", P.PLATE)
check(P.GREEN == "78FFAA", "GREEN is bright phosphor", P.GREEN)
check(P.GREEN_SOFT == "8CE8AE", "GREEN_SOFT is body phosphor", P.GREEN_SOFT)
check(P.GREEN_DIM == "2E6B4A", "GREEN_DIM is inert phosphor", P.GREEN_DIM)
check(P.WHITE == "FFFFFF", "WHITE exists (the streak alone)", P.WHITE)
for name, hex in pairs(P) do
	check(
		type(hex) == "string" and hex:match("^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$") ~= nil,
		"palette " .. tostring(name) .. " is 6-digit uppercase hex",
		tostring(hex)
	)
end

for _, file in ipairs({ CONFIG .. "SupplyConfig.luau", RULES .. "CrateRules.luau" }) do
	local text = readFile(file)
	check(text:find("FF1818", 1, true) == nil, file .. " never uses the reserved FIRE red")
	check(text:find("EBF5EE", 1, true) == nil, file .. " never uses the reserved crosshair bone")
end

-- RARITY LADDER -- the user's D-B decision, pinned ----------------------------
-- COMMON grey / RARE blue / VEX yellow (01.09.2026). The registry keys stay
-- diegetic; this asserts the decided mapping so a drive-by "improvement" of a
-- hue or label fails the build instead of shipping.
print("\nSUPPLY CONFIG -- rarity ladder is the decided COMMON/RARE/VEX set")

local rarityInUse = {}
for _, id in ipairs(Registry.list()) do
	local row = Registry.get(id)
	if type(row.rarity) == "string" then
		rarityInUse[row.rarity] = true
	end
end
for rarity in pairs(rarityInUse) do
	local ladder = Supply.Rarity[rarity]
	check(type(ladder) == "table", "Rarity ladder covers " .. rarity)
	if type(ladder) == "table" then
		check(
			type(ladder.stroke) == "string"
				and ladder.stroke:match("^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$") ~= nil,
			rarity .. " stroke is 6-digit uppercase hex",
			tostring(ladder.stroke)
		)
		check(
			type(ladder.label) == "string" and #ladder.label > 0 and ladder.label == string.upper(ladder.label),
			rarity .. " label is SHOUTED",
			tostring(ladder.label)
		)
		check(type(ladder.pulse) == "boolean", rarity .. " pulse is boolean")
		check(type(ladder.double) == "boolean", rarity .. " double is boolean")
	end
end
check(Supply.Rarity.standard.label == "COMMON", "standard reads COMMON", Supply.Rarity.standard.label)
check(Supply.Rarity.issue.label == "RARE", "issue reads RARE", Supply.Rarity.issue.label)
check(Supply.Rarity.clearance.label == "VEX", "clearance reads VEX", Supply.Rarity.clearance.label)
check(Supply.Rarity.overseer.label == "VEX", "overseer reads VEX (same top band)", Supply.Rarity.overseer.label)
check(Supply.Rarity.issue.stroke == "4A90E2", "RARE is the decided blue", Supply.Rarity.issue.stroke)
check(Supply.Rarity.clearance.stroke == "FFD700", "VEX is the decided yellow", Supply.Rarity.clearance.stroke)
check(Supply.Rarity.overseer.stroke == "FFD700", "both VEX doors share the yellow", Supply.Rarity.overseer.stroke)

-- CRATE ECONOMY ---------------------------------------------------------------
print("\nSUPPLY CONFIG -- crate economy constants")

local C = Supply.Crate
check(
	type(C.COST_KEYS) == "number" and C.COST_KEYS >= 1 and C.COST_KEYS == math.floor(C.COST_KEYS),
	"COST_KEYS is a whole key count >= 1",
	C.COST_KEYS
)
check(type(C.REEL_LENGTH) == "number" and C.REEL_LENGTH >= 8, "REEL_LENGTH is a real reel", C.REEL_LENGTH)
check(
	type(C.RESULT_INDEX) == "number" and C.RESULT_INDEX > C.REEL_LENGTH / 2 and C.RESULT_INDEX <= C.REEL_LENGTH - 2,
	"RESULT_INDEX sits late in the reel with tail room",
	C.RESULT_INDEX
)
check(type(C.WEIGHTS) == "table", "WEIGHTS table exists")
for rarity in pairs(rarityInUse) do
	local sourceHasCrate = false
	for _, id in ipairs(Registry.list()) do
		local row = Registry.get(id)
		if row.source == "crate" and row.rarity == rarity then
			sourceHasCrate = true
		end
	end
	if sourceHasCrate then
		check(
			type(C.WEIGHTS[rarity]) == "number" and C.WEIGHTS[rarity] > 0,
			"crate rarity " .. rarity .. " has a positive weight",
			tostring(C.WEIGHTS[rarity])
		)
	end
end

check(
	type(Progression.FRAGMENTS_PER_KEY) == "number" and Progression.FRAGMENTS_PER_KEY >= 1,
	"FRAGMENTS_PER_KEY is readable for the wallet pill",
	tostring(Progression.FRAGMENTS_PER_KEY)
)

-- REVEAL TIMINGS --------------------------------------------------------------
print("\nSUPPLY CONFIG -- reveal timings")

local R = Supply.Reveal
local total = 0
for _, key in ipairs({ "SHAKE", "SPIN", "SETTLE", "FLASH", "HOLD" }) do
	check(type(R[key]) == "number" and R[key] > 0, "Reveal." .. key .. " is positive", tostring(R[key]))
	total = total + (tonumber(R[key]) or 0)
end
local worstBonus = 0
for _, bonus in pairs(R.SPIN_BONUS or {}) do
	if type(bonus) == "number" and bonus > worstBonus then
		worstBonus = bonus
	end
end
check(total + worstBonus < 15, "worst-case reveal stays under 15 s", total + worstBonus)

-- STRINGS -- machine voice ----------------------------------------------------
print("\nSUPPLY CONFIG -- strings are SHOUTED")

local stringCount = 0
for key, value in pairs(Supply.Strings) do
	stringCount = stringCount + 1
	check(
		type(value) == "string" and #value > 0 and value == string.upper(value),
		"Strings." .. tostring(key) .. " is non-empty and SHOUTED",
		tostring(value)
	)
end
check(stringCount >= 10, "the string table is real, not a stub", stringCount)

-- LAYOUT / MOTION ---------------------------------------------------------------
print("\nSUPPLY CONFIG -- layout numbers")
for key, value in pairs(Supply.Layout) do
	check(type(value) == "number" and value > 0, "Layout." .. tostring(key) .. " is positive", tostring(value))
end
check(
	type(Supply.Motion.SLIDE) == "number" and Supply.Motion.SLIDE > 0 and Supply.Motion.SLIDE < 1,
	"Motion.SLIDE is a real slide, under a second",
	tostring(Supply.Motion.SLIDE)
)

-- PROMO RULES -- format and status, pure ----------------------------------------
print("\nPROMO RULES -- normalize")

check(Promo.normalize("kenopsia-2026") == "KENOPSIA2026", "dashes strip, case shouts")
check(Promo.normalize("  ab c_d  ") == "ABCD", "spaces and underscores strip")
check(Promo.normalize("ab") == nil, "too short is nil")
check(Promo.normalize(string.rep("A", 25)) == nil, "too long is nil")
check(Promo.normalize("h!x$") == nil, "non-alphanumerics are nil, not stripped")
check(Promo.normalize(123) == nil, "a non-string is nil")
check(Promo.normalize(string.rep("Z", 24)) == string.rep("Z", 24), "max length passes exactly")

print("\nPROMO RULES -- status")

local rows = {
	GOOD1 = { reward = { keys = 1 } },
	OLD99 = { reward = { keys = 1 }, expires = 1000 },
}
check(Promo.status(rows, {}, "NOPE1", 500) == "INVALID", "unknown code is INVALID")
check(Promo.status(rows, { GOOD1 = true }, "GOOD1", 500) == "USED", "redeemed code is USED")
check(Promo.status(rows, {}, "OLD99", 2000) == "EXPIRED", "past expiry is EXPIRED")
check(Promo.status(rows, {}, "OLD99", 500) == "OK", "before expiry is OK")
check(Promo.status(rows, {}, "GOOD1", 2000) == "OK", "no expiry never expires")
check(Promo.status(nil, {}, "GOOD1", 500) == "INVALID", "no rows table fails closed")

-- CRATE RULES -- pool ---------------------------------------------------------
print("\nCRATE RULES -- pool")

local pool = Crate.pool(Registry.Emotes, {})
check(#pool == 6, "fresh profile: pool is the six crate dances", #pool)
check(pool[1] == "blow_kiss" and pool[#pool] == "silly_dance", "pool is sorted", pool[1] .. ".." .. pool[#pool])
local hasDefault = false
for _, id in ipairs(pool) do
	if id == "dance_default" then
		hasDefault = true
	end
end
check(not hasDefault, "a default row is never in the crate pool")

local poolOwned = Crate.pool(Registry.Emotes, { blow_kiss = true, rumba = true })
check(#poolOwned == 4, "owned rows leave the pool", #poolOwned)
for _, id in ipairs(poolOwned) do
	check(id ~= "blow_kiss" and id ~= "rumba", "owned id " .. id .. " stays excluded")
end

local allOwned = {}
for _, id in ipairs(pool) do
	allOwned[id] = true
end
check(#Crate.pool(Registry.Emotes, allOwned) == 0, "a complete collection empties the pool")

-- CRATE RULES -- odds ---------------------------------------------------------
print("\nCRATE RULES -- odds")

local odds = Crate.odds(pool, Registry.Emotes, C.WEIGHTS)
check(#odds == 1 and odds[1].rarity == "issue", "live catalog: one rarity band", odds[1] and odds[1].rarity)
check(odds[1] and odds[1].percent == 100, "single band reads 100", odds[1] and odds[1].percent)
check(#Crate.odds({}, Registry.Emotes, C.WEIGHTS) == 0, "empty pool has no odds rows")

local synth = {
	a1 = { id = "a1", source = "crate", rarity = "standard" },
	a2 = { id = "a2", source = "crate", rarity = "standard" },
	b1 = { id = "b1", source = "crate", rarity = "issue" },
}
local synthPool = Crate.pool(synth, {})
local synthOdds = Crate.odds(synthPool, synth, { standard = 50, issue = 100 })
local sum = 0
for _, row in ipairs(synthOdds) do
	sum = sum + row.percent
	check(row.percent > 0, "band " .. row.rarity .. " keeps a visible share", row.percent)
end
check(math.abs(sum - 100) < 1e-6, "mixed bands still sum to exactly 100", sum)

-- CRATE RULES -- roll ---------------------------------------------------------
print("\nCRATE RULES -- roll")

check(Crate.roll({}, Registry.Emotes, C.WEIGHTS, 0.5, 0.5) == nil, "empty pool rolls nil")
check(Crate.roll(pool, Registry.Emotes, C.WEIGHTS, 0, 0) == "blow_kiss", "r2=0 lands on the first sorted id")
check(Crate.roll(pool, Registry.Emotes, C.WEIGHTS, 0, 0.999) == "silly_dance", "r2->1 lands on the last sorted id")

local inPool = {}
for _, id in ipairs(pool) do
	inPool[id] = true
end
math.randomseed(7)
local escaped = false
for _ = 1, 200 do
	local id = Crate.roll(pool, Registry.Emotes, C.WEIGHTS, math.random(), math.random())
	if not inPool[id] then
		escaped = true
	end
end
check(not escaped, "200 seeded rolls never leave the pool")

local mixedRolls = { standard = 0, issue = 0 }
math.randomseed(11)
for _ = 1, 400 do
	local id = Crate.roll(synthPool, synth, { standard = 50, issue = 100 }, math.random(), math.random())
	local rarity = synth[id].rarity
	mixedRolls[rarity] = mixedRolls[rarity] + 1
end
check(
	mixedRolls.standard > 0 and mixedRolls.issue > 0,
	"both bands are reachable",
	mixedRolls.standard .. "/" .. mixedRolls.issue
)
check(
	mixedRolls.issue > mixedRolls.standard,
	"the heavier band lands more often",
	mixedRolls.issue .. " vs " .. mixedRolls.standard
)

-- CRATE RULES -- reel ---------------------------------------------------------
print("\nCRATE RULES -- reel")

local cycle = 0
local function fakeRandInt(n)
	cycle = cycle + 1
	return ((cycle - 1) % n) + 1
end
local reel = Crate.reel(pool, "moonwalk", C.REEL_LENGTH, C.RESULT_INDEX, fakeRandInt)
check(#reel == C.REEL_LENGTH, "reel has REEL_LENGTH tiles", #reel)
check(reel[C.RESULT_INDEX] == "moonwalk", "the server's result sits at RESULT_INDEX", reel[C.RESULT_INDEX])
local reelEscaped = false
for _, id in ipairs(reel) do
	if not inPool[id] then
		reelEscaped = true
	end
end
check(not reelEscaped, "every reel tile comes from the pool")

local lone = Crate.reel({ "rumba" }, "rumba", 10, 8, fakeRandInt)
check(#lone == 10 and lone[8] == "rumba" and lone[1] == "rumba", "a one-id pool still fills a reel")

-- VERDICT ----------------------------------------------------------------------
print(string.format("\n%d checks, %d failure(s)", checks, failures))
if failures > 0 then
	os.exit(1)
end
print("ALL GREEN")
