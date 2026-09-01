--!nonstrict
-- CRATE RULES (01.09.2026) -- the crate roll as pure, provable arithmetic.
--
-- The server (Services/CrateService) is the ONLY roller; the client calls
-- pool() and odds() to render the MANIFEST modal and reel() is built server
-- side so the animation can only ever land on the server's result -- the
-- spec's "Server bestimmt Ergebnis, Client animiert nur zum vorbestimmten
-- Item" rule, expressed as code shape instead of discipline.
--
-- PURE (the ProgressionRules discipline): no Roblox globals, no requires, no
-- clock, no math.random -- every random number comes IN as an argument, so
-- tests/supply.lua replays exact draws in desktop Lua 5.1. Lua 5.1 subset
-- only: no compound assignment, no generalized iteration.
--
-- SEMANTICS, fixed here so server and tests can never drift:
--   * the pool is every catalog row with source == "crate" whose id is not in
--     the owned set, SORTED -- a roll among unowned rows only means a
--     duplicate is impossible and "all owned" is a visible COLLECTION
--     COMPLETE state, never a wasted key;
--   * a roll picks a RARITY BAND first (relative WEIGHTS over the rarities
--     present in the pool, walked in sorted rarity order), then uniformly one
--     id inside that band (sorted) -- so adding a rare tier later changes
--     odds, not code;
--   * odds() is the same walk expressed as percentages with one decimal, the
--     last band absorbing the rounding remainder so the MANIFEST always sums
--     to exactly 100.

local CrateRules = {}

-- Every unowned crate row, sorted. `emotes` is EmoteRegistry.Emotes (or any
-- table of rows shaped like it); `owned` is a set { [id] = true }.
function CrateRules.pool(emotes, owned)
	local out = {}
	if type(emotes) ~= "table" then
		return out
	end
	for id, row in pairs(emotes) do
		if
			type(id) == "string"
			and type(row) == "table"
			and row.source == "crate"
			and not (type(owned) == "table" and owned[id] == true)
		then
			out[#out + 1] = id
		end
	end
	table.sort(out)
	return out
end

-- The shared walk: rarities present in the pool (sorted) and the sorted ids
-- per band. Local on purpose -- callers see bands only through odds()/roll().
local function bands(poolIds, emotes)
	local byRarity = {}
	local rarities = {}
	for i = 1, #poolIds do
		local id = poolIds[i]
		local row = type(emotes) == "table" and emotes[id] or nil
		local rarity = (type(row) == "table" and type(row.rarity) == "string") and row.rarity or "standard"
		local list = byRarity[rarity]
		if list == nil then
			list = {}
			byRarity[rarity] = list
			rarities[#rarities + 1] = rarity
		end
		list[#list + 1] = id
	end
	table.sort(rarities)
	for i = 1, #rarities do
		table.sort(byRarity[rarities[i]])
	end
	return rarities, byRarity
end

local function weightOf(weights, rarity)
	local w = type(weights) == "table" and tonumber(weights[rarity]) or nil
	if w == nil or w < 0 then
		return 0
	end
	return w
end

-- { { rarity = "issue", percent = 100 }, ... } over the PRESENT bands, one
-- decimal, summing to exactly 100 (last band takes the remainder). An empty
-- pool has no odds rows -- the UI shows COLLECTION COMPLETE instead.
function CrateRules.odds(poolIds, emotes, weights)
	local out = {}
	local rarities, _ = bands(poolIds, emotes)
	if #rarities == 0 then
		return out
	end
	local total = 0
	for i = 1, #rarities do
		total = total + weightOf(weights, rarities[i])
	end
	local spent = 0
	for i = 1, #rarities do
		local percent
		if i == #rarities then
			percent = math.floor((100 - spent) * 10 + 0.5) / 10
		elseif total > 0 then
			percent = math.floor(weightOf(weights, rarities[i]) / total * 1000 + 0.5) / 10
		else
			percent = math.floor(1000 / #rarities + 0.5) / 10
		end
		spent = spent + percent
		out[#out + 1] = { rarity = rarities[i], percent = percent }
	end
	return out
end

-- One roll. r1 picks the rarity band, r2 the id inside it; both in [0, 1).
-- nil for an empty pool. Zero total weight degrades to uniform bands, so a
-- misconfigured WEIGHTS table can never make a paid-for... an EARNED-for key
-- vanish into a roll that cannot land.
function CrateRules.roll(poolIds, emotes, weights, r1, r2)
	local rarities, byRarity = bands(poolIds, emotes)
	if #rarities == 0 then
		return nil
	end
	r1 = tonumber(r1) or 0
	r2 = tonumber(r2) or 0
	local total = 0
	for i = 1, #rarities do
		total = total + weightOf(weights, rarities[i])
	end
	local band = rarities[#rarities]
	if total > 0 then
		local pick = r1 * total
		local cursor = 0
		for i = 1, #rarities do
			cursor = cursor + weightOf(weights, rarities[i])
			if pick < cursor then
				band = rarities[i]
				break
			end
		end
	else
		local idx = math.floor(r1 * #rarities) + 1
		if idx > #rarities then
			idx = #rarities
		end
		band = rarities[idx]
	end
	local ids = byRarity[band]
	local idx = math.floor(r2 * #ids) + 1
	if idx > #ids then
		idx = #ids
	end
	return ids[idx]
end

-- The strip the client scrolls past the ticker. `resultId` is pinned at
-- `resultIndex`; every other tile is drawn from the pool via the caller's
-- randInt(n) -> 1..n, so the server owns even the filler randomness and a
-- replayed packet renders identically.
function CrateRules.reel(poolIds, resultId, length, resultIndex, randInt)
	local out = {}
	length = tonumber(length) or 0
	for i = 1, length do
		if i == resultIndex then
			out[i] = resultId
		else
			out[i] = poolIds[randInt(#poolIds)]
		end
	end
	return out
end

return CrateRules
