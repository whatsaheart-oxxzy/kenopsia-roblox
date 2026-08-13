--!nonstrict
-- SCORING (Gate 1) -- turning a finished trial into points.
--
-- PURE, and portable to Lua 5.1: see the header of Pacing.luau.
--
-- A completed trial always distributes EXACTLY 1700 points, whatever the player
-- count and whatever ties occurred. That total is the contract; everything below
-- exists to hold it.
--
-- THE ONE PLACE THE SPEC CANNOT BE SATISFIED TWICE ----------------------------
--
-- Two rules are required at once:
--
--   (a) the distribution sums to exactly 1700, and
--   (b) tied players share the average of the places they occupy.
--
-- For some shapes these cannot both hold in whole points. Three players all tied
-- is the clearest case: 1700 / 3 = 566.67, so no set of three equal integers
-- sums to 1700. Something has to give.
--
-- RULING: (a) wins. The total is the contract -- a session that silently awards
-- 1699 or 1701 makes every cumulative board wrong, and the error compounds over
-- three trials. Tied players therefore receive shares that may differ by at most
-- ONE point, allocated to the earlier-ranked player first.
--
-- The spread is bounded and asserted by tests/rules.lua, so it can never quietly
-- grow. Where the arithmetic is clean -- which is every 2-player and 4-player
-- shape -- tied players receive exactly equal points and the spread is zero.

local Pacing = require(script.Parent.Pacing)

local Scoring = {}

Scoring.Pool = Pacing.TrialPointPool

-- Borda weights: best place scores n, worst scores 1.
function Scoring.borda(n)
	local w = {}
	for i = 1, n do
		w[i] = n - i + 1
	end
	return w
end

-- Ranks `entries` with `cmp`, where cmp(a, b) is true when a places strictly
-- ahead of b. Entries that separate under neither direction are tied.
--
-- Returns an array sorted best-first, each element:
--   { entry = <original>, place = <competition rank>, from = <i>, to = <j> }
--
-- `from`/`to` are the 1-based place SLOTS the tie group occupies, which is what
-- "the average of the places they occupy" needs -- two players tied for first
-- occupy slots 1 and 2, and share the average of those two weights, not twice
-- the weight of first place.
function Scoring.rankRound(entries, cmp)
	-- selene: allow(manual_table_clone)
	-- NOT table.clone: that is Luau-only, and this file has to parse and run
	-- under Lua 5.1 as well, which is what lets tests/rules.lua prove the shipped
	-- source instead of a copy. Do not "simplify" this loop.
	local sorted = {}
	for i, e in ipairs(entries) do
		sorted[i] = e
	end

	-- A stable sort is not guaranteed by table.sort in either runtime, so the
	-- comparator must be a strict weak ordering and ties must be resolved by the
	-- grouping pass below rather than by sort order.
	table.sort(sorted, function(a, b)
		return cmp(a, b)
	end)

	local out = {}
	local i = 1
	while i <= #sorted do
		local j = i
		while j < #sorted and not cmp(sorted[j], sorted[j + 1]) and not cmp(sorted[j + 1], sorted[j]) do
			j = j + 1
		end
		for k = i, j do
			out[k] = { entry = sorted[k], place = i, from = i, to = j }
		end
		i = j + 1
	end
	return out
end

-- Fills `.points` on a ranking so the column sums to exactly Scoring.Pool.
--
-- Largest-remainder (Hamilton): floor every exact share, then hand the leftover
-- whole points to the largest fractional remainders. Remainder ties break by
-- rank, so the allocation is fully determined by the ranking and never by table
-- order or by chance.
function Scoring.distribute(ranking)
	local n = #ranking
	if n == 0 then return ranking end

	local weights = Scoring.borda(n)

	-- Tie groups take the mean of the weights of the slots they occupy. Summing
	-- means over a partition preserves the total, so `total` is always the same
	-- n(n+1)/2 regardless of how the ties fall.
	local share = {}
	local total = 0
	for i = 1, n do
		local r = ranking[i]
		local sum = 0
		for slot = r.from, r.to do
			sum = sum + weights[slot]
		end
		share[i] = sum / (r.to - r.from + 1)
		total = total + share[i]
	end

	local assigned = 0
	local remainder = {}
	for i = 1, n do
		local exact = Scoring.Pool * share[i] / total
		local whole = math.floor(exact)
		ranking[i].points = whole
		assigned = assigned + whole
		remainder[i] = { index = i, frac = exact - whole }
	end

	table.sort(remainder, function(a, b)
		if a.frac ~= b.frac then return a.frac > b.frac end
		return a.index < b.index -- earlier rank wins the spare point
	end)

	local leftover = Scoring.Pool - assigned
	for k = 1, leftover do
		local target = remainder[k]
		if not target then break end
		ranking[target.index].points = ranking[target.index].points + 1
	end

	return ranking
end

return Scoring
