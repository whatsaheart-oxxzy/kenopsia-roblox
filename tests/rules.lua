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
	{ "birdhunt", 2, 4 },  { "birdhunt", 3, 3 },  { "birdhunt", 4, 4 },
	{ "canteen", 2, 3 },   { "canteen", 3, 2 },   { "canteen", 4, 2 },
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

check(Pacing.RoundSeconds.minefield == 55 and Pacing.RoundSeconds.birdhunt == 90
	and Pacing.RoundSeconds.canteen == 45, "round limits 55 / 90 / 45 s")
check(Pacing.TrialPointPool == 1700, "point pool is 1700")

-- 2. PLAYLIST ----------------------------------------------------------------

print("\nPLAYLIST -- deterministic shuffle over three ids")

local function key(order) return table.concat(order, ",") end

-- Every id exactly once, never a repeat, for a wide sweep of seeds.
local malformed = 0
for seed = 1, 2000 do
	local order = Playlist.order(seed)
	local seen = {}
	if #order ~= 3 then malformed = malformed + 1 end
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

-- All six permutations are reachable. The plan asks for six seeds giving six
-- distinct orders; searching for them proves reachability rather than asserting
-- a hand-picked list that could pass on a broken shuffle.
local found, distinct = {}, 0
local witness = {}
for seed = 1, 2000 do
	local k = key(Playlist.order(seed))
	if not found[k] then
		found[k] = seed
		distinct = distinct + 1
		witness[#witness + 1] = string.format("seed %d -> %s", seed, k)
	end
	if distinct == 6 then break end
end
check(distinct == 6, "all 6 permutations reachable", string.format("got %d", distinct))
for _, w in ipairs(witness) do print("          " .. w) end

-- Determinism: the same seed must give the same order every time.
local stable = true
for seed = 1, 50 do
	if key(Playlist.order(seed)) ~= key(Playlist.order(seed)) then stable = false end
end
check(stable, "same seed always yields the same order")

check(Playlist.isKnown("canteen") and not Playlist.isKnown("tablemanners"),
	"isKnown accepts canteen and rejects the old id")

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
