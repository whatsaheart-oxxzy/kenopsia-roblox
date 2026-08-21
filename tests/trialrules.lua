-- MP-05 Framework offline proof: the PURE half of the server TrialKit.
--
--     lua tests/trialrules.lua
--
-- Loads the SHIPPED Shared/Rules/TrialRules.luau through the same shim as
-- tests/rules.lua. Proves the banded ordering key clamp, the grid arithmetic
-- (cellCenter/cellOf are inverses, gaps and outside return nil), the seeded
-- LCG (deterministic per session+round, distinct across rounds) and the token
-- format every new trial mints. Exit code 0 only if every check passes.

local ROOT = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"

local function loadModule(file, parent)
	local chunk = assert(loadfile(ROOT .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local TR = loadModule("TrialRules.luau")
local Playlist = loadModule("Playlist.luau")

local failures, checks = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
	end
end

-- 1. BANDS -------------------------------------------------------------------
print("\nBANDS -- FINISHED > ALIVE > OUT, detail clamped below the next band")

check(TR.BAND.FINISHED == 2000 and TR.BAND.ALIVE == 1000 and TR.BAND.OUT == 0, "band constants 2000/1000/0")
check(TR.key(TR.BAND.ALIVE, 0) == 1000, "key(ALIVE, 0) == 1000")
check(TR.key(TR.BAND.ALIVE, 999) == 1999, "key(ALIVE, 999) == 1999")
check(TR.key(TR.BAND.ALIVE, 1000) == 1999, "key(ALIVE, 1000) clamps to 1999")
check(TR.key(TR.BAND.ALIVE, 5e9) == 1999, "key(ALIVE, huge) clamps to 1999")
check(TR.key(TR.BAND.OUT, -50) == 0, "key(OUT, negative) clamps to 0")
check(TR.key(TR.BAND.FINISHED, 12.9) == 2012, "key floors fractional detail")
check(TR.key(TR.BAND.OUT, 999999) < TR.key(TR.BAND.ALIVE, 0), "max OUT < min ALIVE")
check(TR.key(TR.BAND.ALIVE, 999999) < TR.key(TR.BAND.FINISHED, 0), "max ALIVE < min FINISHED")
check(TR.key(TR.BAND.ALIVE, nil) == 1000, "nil detail is 0")

-- 2. GRID --------------------------------------------------------------------
print("\nGRID -- arithmetic cell lookup, no Touched")

local g = TR.newGrid(6, 8, 4, 0.5, 100, -200)
check(TR.gridSpan(6, 4, 0.5) == 26.5, "span of 6 x 4 with 0.5 gaps is 26.5")

-- Inverse property over every cell.
local inverseOk = true
for c = 1, g.cols do
	for r = 1, g.rows do
		local x, z = TR.cellCenter(g, c, r)
		local cc, rr = TR.cellOf(g, x, z)
		if cc ~= c or rr ~= r then inverseOk = false end
	end
end
check(inverseOk, "cellOf(cellCenter(c, r)) == c, r for all 48 cells")

-- Corners of a plate still resolve to it; the gap does not.
do
	local x, z = TR.cellCenter(g, 3, 5)
	local half = g.cell / 2 - 0.01
	local c1, r1 = TR.cellOf(g, x - half, z - half)
	local c2, r2 = TR.cellOf(g, x + half, z + half)
	check(c1 == 3 and r1 == 5 and c2 == 3 and r2 == 5, "plate corners resolve to the plate")
	local gc = TR.cellOf(g, x + g.cell / 2 + 0.1, z)
	check(gc == nil, "a point in the gap resolves to nil")
end
check(TR.cellOf(g, 100 - 20, -200) == nil, "west of the grid is nil")
check(TR.cellOf(g, 100 + 20, -200) == nil, "east of the grid is nil")
check(TR.cellOf(g, 100, -200 - 20) == nil, "north of the grid is nil")
check(TR.cellOf(g, 100, -200 + 20) == nil, "south of the grid is nil")

-- The grid is centred on (x0, z0).
do
	local x1, z1 = TR.cellCenter(g, 1, 1)
	local x6, z8 = TR.cellCenter(g, 6, 8)
	check(math.abs((x1 + x6) / 2 - 100) < 1e-9 and math.abs((z1 + z8) / 2 + 200) < 1e-9,
		"grid is centred on its origin")
end

-- Zero-gap grid: every point inside resolves to some cell.
do
	local g0 = TR.newGrid(3, 3, 2, 0, 0, 0)
	local allHit = true
	for i = 0, 29 do
		for j = 0, 29 do
			local x = -3 + (i + 0.5) * 0.2
			local z = -3 + (j + 0.5) * 0.2
			if TR.cellOf(g0, x, z) == nil then allHit = false end
		end
	end
	check(allHit, "zero-gap grid has no dead points inside")
end

-- 3. RNG ---------------------------------------------------------------------
print("\nRNG -- seeded per session and round")

do
	local a = TR.rng("S1-123", 1)
	local b = TR.rng("S1-123", 1)
	local same = true
	for _ = 1, 50 do
		if a(100) ~= b(100) then same = false end
	end
	check(same, "same session+round -> same sequence")

	local r1 = TR.rng("S1-123", 1)
	local r2 = TR.rng("S1-123", 2)
	local differ = false
	for _ = 1, 20 do
		if r1(1000) ~= r2(1000) then differ = true end
	end
	check(differ, "round 1 and round 2 differ")

	local inRange = true
	local seen = {}
	local n = TR.rng("S9", 3)
	for _ = 1, 500 do
		local v = n(6)
		if v < 1 or v > 6 or v ~= math.floor(v) then inRange = false end
		seen[v] = true
	end
	local all = true
	for v = 1, 6 do
		if not seen[v] then all = false end
	end
	check(inRange, "nextInt(6) stays in 1..6")
	check(all, "nextInt(6) reaches every value in 500 draws")

	-- The LCG is Playlist's: the same seed shuffles identically.
	local pl = Playlist.order(4242)
	local ids = {}
	for i, id in ipairs(Playlist.Ids) do ids[i] = id end
	local mine = TR.shuffle(ids, TR.lcg(4242))
	check(table.concat(pl, ",") == table.concat(mine, ","), "TrialRules.lcg + shuffle == Playlist.order")

	check(TR.hash("abc") == TR.hash("abc") and TR.hash("abc") ~= TR.hash("abd"), "hash is stable and sensitive")
	check(TR.hash("") == 5381, "hash of empty string is the djb2 seed")
end

-- 4. TOKEN -------------------------------------------------------------------
print("\nTOKEN -- <ID>-<session>-R<n>-<ms % 100000>")

do
	local tok = TR.token("carve", "S1-77", 2, 1234567)
	check(tok == "CARVE-S1-77-R2-34567", "token format", tok)
	check(TR.tokenMatches(tok, "carve"), "tokenMatches accepts its own token")
	check(not TR.tokenMatches(tok, "armory"), "tokenMatches rejects another trial's token")
	check(not TR.tokenMatches(nil, "carve") and not TR.tokenMatches(42, "carve"), "tokenMatches rejects non-strings")
	check(TR.token("x", "s", nil, 0) == "X-s-R1-0", "token defaults roundIndex to 1")
end

-- 5. GEOMETRY ----------------------------------------------------------------
print("\nGEOMETRY -- AABB and flat distance")

do
	local box = { -10, 10, 0, 20, -5, 5 }
	check(TR.inBox(box, 0, 1, 0), "inBox: centre inside")
	check(TR.inBox(box, 10, 20, 5), "inBox: max corner inclusive")
	check(not TR.inBox(box, 10.1, 1, 0), "inBox: just outside X")
	check(not TR.inBox(box, 0, -0.1, 0), "inBox: below Y")
	check(TR.flatDistance(0, 0, 3, 4) == 5, "flatDistance 3-4-5")
end

-- SUMMARY --------------------------------------------------------------------
print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("MP-05 TRIALRULES PROOF: FAIL")
	os.exit(1)
end
print("MP-05 TRIALRULES PROOF: PASS")
os.exit(0)
