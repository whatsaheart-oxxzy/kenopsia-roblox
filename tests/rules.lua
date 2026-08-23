-- Gate 1 offline proof. Run from the repo root:
--
--     lua tests/rules.lua
--
-- This loads the SHIPPED module files from studio-src -- not copies -- so what
-- passes here is what runs in the place. The only thing the harness supplies is
-- a stand-in for Roblox's `script` / `require`, because those are the one part
-- of a "pure" module that still cannot exist outside the engine.
--
-- Exit code is 0 only if every check passes, so this is usable as a gate.

local ROOT = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"

-- `require(script.Parent.X)` is given a TABLE by Roblox, not a string. The shim
-- therefore makes script.Parent.X be the already-loaded module and require the
-- identity function -- no rewriting of the module source, no second copy to
-- drift out of step.
local function loadModule(file, parent)
	local chunk = assert(loadfile(ROOT .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local Pacing = loadModule("Pacing.luau")
local Playlist = loadModule("Playlist.luau")
local Scoring = loadModule("Scoring.luau", { Pacing = Pacing })

local failures = 0
local checks = 0

local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
	end
end

-- 1. PACING ------------------------------------------------------------------

print("\nPACING -- rounds and legs per player count")

local expected = {
	{ "minefield", 2, 4 }, { "minefield", 3, 3 }, { "minefield", 4, 3 },
	{ "birdhunt", 2, 3 },  { "birdhunt", 3, 3 },  { "birdhunt", 4, 3 },  -- 22.08.2026: 3 legs x 60 s (MASTERPLAN P0.3)
	{ "canteen", 2, 3 },   { "canteen", 3, 2 },   { "canteen", 4, 2 },
	-- MP-05 section A rows, one per new trial.
	{ "carve", 2, 3 },      { "carve", 3, 3 },      { "carve", 4, 2 },
	{ "armory", 2, 3 },     { "armory", 3, 2 },     { "armory", 4, 2 },
	{ "upstream", 2, 3 },   { "upstream", 3, 3 },   { "upstream", 4, 2 },
	{ "floorcheck", 2, 3 }, { "floorcheck", 3, 3 }, { "floorcheck", 4, 2 },
	{ "clearance", 2, 2 },  { "clearance", 3, 2 },  { "clearance", 4, 2 },
	{ "carrier", 2, 2 },    { "carrier", 3, 3 },    { "carrier", 4, 2 },
	{ "breather", 2, 3 },   { "breather", 3, 3 },   { "breather", 4, 3 },
	{ "sweep", 2, 3 },      { "sweep", 3, 2 },      { "sweep", 4, 2 },
	{ "crawler", 2, 3 },    { "crawler", 3, 2 },    { "crawler", 4, 2 },
	{ "ricochet", 2, 3 },   { "ricochet", 3, 3 },   { "ricochet", 4, 2 },
	{ "stacker", 2, 3 },    { "stacker", 3, 3 },    { "stacker", 4, 3 },
	{ "sorting", 2, 3 },    { "sorting", 3, 2 },    { "sorting", 4, 2 },
}
for _, row in ipairs(expected) do
	local got = Pacing.roundsFor(row[1], row[2])
	check(got == row[3],
		string.format("%-10s %dp -> %d", row[1], row[2], row[3]),
		string.format("got %s", tostring(got)))
end

-- Solo maps onto the 2-player row rather than having one of its own.
check(Pacing.roundsFor("minefield", 1) == Pacing.roundsFor("minefield", 2),
	"solo uses the 2-player row")

-- 23.08.2026: canteen 45 -> 60 (tension ramp; see Pacing.RoundSeconds).
-- 23.08.2026: minefield 55 -> 62 (slower compactor; its speed derives from this).
check(Pacing.RoundSeconds.minefield == 62 and Pacing.RoundSeconds.birdhunt == 60
	and Pacing.RoundSeconds.canteen == 60, "round limits 62 / 60 / 60 s")
check(Pacing.TrialPointPool == 1700, "point pool is 1700")
-- P1.3 (23.08.2026), MASTERPLAN section 2/3: verdict stamp 6 s + podium 8 s.
check(Pacing.Timing.FinalScore == 6 and Pacing.Timing.Podium == 8, "verdict beat is 6 s stamp + 8 s podium",
	tostring(Pacing.Timing.FinalScore) .. " + " .. tostring(Pacing.Timing.Podium))

-- MP-05 D8: one RoundSeconds number per new trial, section A values.
local expectedSeconds = {
	carve = 45, armory = 50, upstream = 40, floorcheck = 35, clearance = 50, carrier = 45,
	breather = 30, sweep = 45, crawler = 40, ricochet = 45, stacker = 20, sorting = 40,
}
local secondsOk, secondsBad = true, {}
for id, secs in pairs(expectedSeconds) do
	if Pacing.RoundSeconds[id] ~= secs then
		secondsOk = false
		secondsBad[#secondsBad + 1] = id .. "=" .. tostring(Pacing.RoundSeconds[id])
	end
end
check(secondsOk, "MP-05 RoundSeconds match section A", table.concat(secondsBad, ","))

-- Every id in Playlist.Ids has BOTH a rounds row and a RoundSeconds value.
local rowsOk, rowsBad = true, {}
for _, id in ipairs(Playlist.Ids) do
	local r2, r3, r4 = Pacing.roundsFor(id, 2), Pacing.roundsFor(id, 3), Pacing.roundsFor(id, 4)
	if not (r2 and r3 and r4 and Pacing.RoundSeconds[id]) then
		rowsOk = false
		rowsBad[#rowsBad + 1] = id
	end
end
check(rowsOk, "every playlist id has a rounds row and a round limit", table.concat(rowsBad, ","))

-- 2. PLAYLIST ----------------------------------------------------------------

print("\nPLAYLIST -- deterministic shuffle over every id")

local function key(order) return table.concat(order, ",") end

check(#Playlist.Ids == 15, "playlist knows 15 ids", string.format("got %d", #Playlist.Ids))

-- Every id exactly once, never a repeat, for a wide sweep of seeds.
local malformed = 0
for seed = 1, 2000 do
	local order = Playlist.order(seed)
	local seen = {}
	if #order ~= #Playlist.Ids then malformed = malformed + 1 end
	for _, id in ipairs(order) do
		if seen[id] then malformed = malformed + 1 end
		seen[id] = true
	end
	for _, id in ipairs(Playlist.Ids) do
		if not seen[id] then malformed = malformed + 1 end
	end
end
check(malformed == 0, "2000 seeds: every order is a permutation, no repeats",
	string.format("%d malformed", malformed))

-- Distinct orders are reachable. With fifteen ids the permutation space is far
-- larger than 2000 seeds can cover, so the property is "at least six distinct
-- orders within 2000 seeds" (the original three-id proof asked for all six);
-- searching for them proves the shuffle actually varies with the seed rather
-- than asserting a hand-picked list that could pass on a broken shuffle.
local found, distinct = {}, 0
local witness = {}
for seed = 1, 2000 do
	local k = key(Playlist.order(seed))
	if not found[k] then
		found[k] = seed
		distinct = distinct + 1
		if #witness < 6 then witness[#witness + 1] = string.format("seed %d -> %s", seed, k) end
	end
end
check(distinct >= 6, "at least 6 distinct orders within 2000 seeds", string.format("got %d", distinct))
for _, w in ipairs(witness) do print("          " .. w) end

-- The three shipped ids still reach every relative order among themselves.
local rel, relCount = {}, 0
for seed = 1, 2000 do
	local sub = {}
	for _, id in ipairs(Playlist.order(seed)) do
		if id == "minefield" or id == "birdhunt" or id == "canteen" then sub[#sub + 1] = id end
	end
	local k = key(sub)
	if not rel[k] then
		rel[k] = true
		relCount = relCount + 1
	end
end
check(relCount == 6, "the shipped three reach all 6 relative orders", string.format("got %d", relCount))

-- Determinism: the same seed must give the same order every time.
local stable = true
for seed = 1, 50 do
	if key(Playlist.order(seed)) ~= key(Playlist.order(seed)) then stable = false end
end
check(stable, "same seed always yields the same order")

check(Playlist.isKnown("canteen") and not Playlist.isKnown("tablemanners"),
	"isKnown accepts canteen and rejects the old id")
check(Playlist.isKnown("carve") and Playlist.isKnown("sorting") and not Playlist.isKnown("chisel"),
	"isKnown accepts the new ids and rejects an unlisted one")

-- MP-05 D7: the session slice. Playlist.session keeps the first N ENABLED ids
-- of an order, in order; N = 0/nil keeps all of them.
do
	local order = Playlist.order(77)
	local enabled = {}
	for _, id in ipairs(Playlist.Ids) do enabled[id] = true end
	local all = Playlist.session(order, enabled, 0)
	check(#all == #order and key(all) == key(order), "session(0) keeps the whole order")
	check(#Playlist.session(order, enabled, nil) == #order, "session(nil) keeps the whole order")
	local five = Playlist.session(order, enabled, 5)
	local prefixOk = #five == 5
	for i = 1, 5 do
		if five[i] ~= order[i] then prefixOk = false end
	end
	check(prefixOk, "session(5) is the first five of the order")
	-- Only the enabled ids count towards N and disabled ones never appear.
	local three = { minefield = true, birdhunt = true, canteen = true }
	local sess = Playlist.session(order, three, 5)
	local onlyEnabled = #sess == 3
	for _, id in ipairs(sess) do
		if not three[id] then onlyEnabled = false end
	end
	check(onlyEnabled, "session drops disabled ids and stops at what is enabled")
	local relOrder = {}
	for _, id in ipairs(order) do
		if three[id] then relOrder[#relOrder + 1] = id end
	end
	check(key(sess) == key(relOrder), "session preserves the shuffled relative order")
	local two = Playlist.session(order, three, 2)
	check(#two == 2 and two[1] == relOrder[1] and two[2] == relOrder[2],
		"session(2) over three enabled ids is their first two")
end

-- REQ-IP-01: the reference game's minigame names must not appear in shipped
-- source. The forbidden list is stored REVERSED here so this test file itself
-- does not contain the names. Each phrase is checked in every spelling a
-- shipped id, display name, comment or UI string could carry: Title Case,
-- UPPER CASE, CamelCase, lowercase-joined, snake_case, UPPER_SNAKE and the
-- plain lowercase words -- except that the plain lowercase form is skipped for
-- a phrase beginning with "the ", which is ordinary English prose. Checked
-- against Playlist.Ids and against every file default.project.json maps.
do
	local reversed = {
		"teltnuag lesihc", "yrotcaf mraerif", "yaw gnorw", "gnitoof elbats",
		"drazah lennut", "boj edisni", "kaerb ekoms", "smroftalp sirbed",
		"rekaerb enips", "dnuober lahtel", "deifitrec tfilkrof", "retlif eht",
		"ytrap enihcam",
	}
	local forbidden = {}
	local function titleCase(phrase)
		return (string.gsub(phrase, "(%a)([%w]*)", function(a, b) return string.upper(a) .. b end))
	end
	for _, r in ipairs(reversed) do
		local phrase = string.reverse(r)
		local title = titleCase(phrase)
		forbidden[#forbidden + 1] = title
		forbidden[#forbidden + 1] = string.upper(phrase)
		forbidden[#forbidden + 1] = (string.gsub(title, " ", ""))
		forbidden[#forbidden + 1] = (string.gsub(phrase, " ", ""))
		forbidden[#forbidden + 1] = (string.gsub(phrase, " ", "_"))
		forbidden[#forbidden + 1] = string.upper((string.gsub(phrase, " ", "_")))
		if string.sub(phrase, 1, 4) ~= "the " then
			forbidden[#forbidden + 1] = phrase
		end
	end
	local function offending(text)
		for _, f in ipairs(forbidden) do
			if string.find(text, f, 1, true) then return f end
		end
		return nil
	end
	local idsClean = true
	for _, id in ipairs(Playlist.Ids) do
		if offending(id) then idsClean = false end
	end
	check(idsClean, "REQ-IP-01: no forbidden token in Playlist.Ids")

	local project = io.open("default.project.json", "r")
	local mapped, dirty, unreadable = 0, {}, {}
	if project then
		local json = project:read("*a")
		project:close()
		for path in string.gmatch(json, '"%$path"%s*:%s*"([^"]+)"') do
			mapped = mapped + 1
			local fh = io.open(path, "r")
			if fh then
				local body = fh:read("*a")
				fh:close()
				local hit = offending(body)
				if hit then dirty[#dirty + 1] = path .. " (" .. hit .. ")" end
			else
				unreadable[#unreadable + 1] = path
			end
		end
	end
	check(project ~= nil and mapped >= 40, "default.project.json maps every shipped file",
		string.format("mapped %d", mapped))
	check(#unreadable == 0, "every mapped path exists", table.concat(unreadable, ", "))
	check(#dirty == 0, "REQ-IP-01: no forbidden token in any shipped file", table.concat(dirty, ", "))
end

-- 3. SCORING -----------------------------------------------------------------

print("\nSCORING -- every tie shape sums to exactly 1700")

-- Tie shapes are the compositions of n: (3) is all-tied, (1,2) is one clear
-- winner then two tied, and so on. 2^(n-1) shapes per player count, 14 in all.
local function compositions(n)
	local out = {}
	local function walk(remaining, acc)
		if remaining == 0 then
			local copy = {}
			for i, v in ipairs(acc) do copy[i] = v end
			out[#out + 1] = copy
			return
		end
		for size = 1, remaining do
			acc[#acc + 1] = size
			walk(remaining - size, acc)
			acc[#acc] = nil
		end
	end
	walk(n, {})
	return out
end

local shapeCount = 0
for n = 2, 4 do
	for _, shape in ipairs(compositions(n)) do
		-- Build scores that produce exactly this tie shape.
		local entries, score = {}, 100
		for _, groupSize in ipairs(shape) do
			for _ = 1, groupSize do
				entries[#entries + 1] = { score = score }
			end
			score = score - 10
		end

		local ranking = Scoring.rankRound(entries, function(a, b) return a.score > b.score end)
		Scoring.distribute(ranking)

		local sum = 0
		for _, r in ipairs(ranking) do sum = sum + r.points end

		-- Tied players must not drift apart by more than the single point the
		-- exact-total rule forces. Zero would be ideal and is impossible for
		-- some shapes -- three players all tied cannot split 1700 evenly.
		local worstSpread = 0
		local i = 1
		while i <= #ranking do
			local j = i
			local lo, hi = ranking[i].points, ranking[i].points
			while j < #ranking and ranking[j + 1].from == ranking[i].from do
				j = j + 1
				if ranking[j].points < lo then lo = ranking[j].points end
				if ranking[j].points > hi then hi = ranking[j].points end
			end
			if hi - lo > worstSpread then worstSpread = hi - lo end
			i = j + 1
		end

		shapeCount = shapeCount + 1
		check(sum == Scoring.Pool and worstSpread <= 1,
			string.format("%dp shape (%s) -> sum %d, tie spread %d",
				n, table.concat(shape, "+"), sum, worstSpread),
			string.format("expected sum %d and spread <= 1", Scoring.Pool))
	end
end
check(shapeCount == 14, "all 14 tie shapes covered", string.format("got %d", shapeCount))

-- Ordering sanity: a clear winner must never score below a clear loser.
local ranking = Scoring.distribute(Scoring.rankRound(
	{ { score = 1 }, { score = 9 }, { score = 5 }, { score = 3 } },
	function(a, b) return a.score > b.score end))
local monotone = true
for i = 2, #ranking do
	if ranking[i].points > ranking[i - 1].points then monotone = false end
end
check(monotone, "points never increase down the ranking")
check(ranking[1].entry.score == 9, "the highest scorer ranks first")

-- SUMMARY --------------------------------------------------------------------

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("GATE 1 RULES PROOF: FAIL")
	os.exit(1)
end
print("GATE 1 RULES PROOF: PASS")
os.exit(0)
