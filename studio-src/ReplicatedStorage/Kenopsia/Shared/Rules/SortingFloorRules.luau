--!nonstrict
-- SORTING FLOOR -- the PURE half (P4.1, 23.08.2026).
--
-- Items on a belt, a RULE board that rotates without warning, two chutes. This
-- module owns everything that can be proven offline (tests/sorting.lua): the
-- item space, the rules and how they sort, the rule schedule, the item stream
-- per station, the timing windows, strikes and the ranking detail. No `game`,
-- no services, no os/clock, no math.random: randomness is an injected nextInt(n)
-- (1..n), time is seconds since GO. Lua 5.1 portable (no `+=`, no `//`).
--
-- REQ-IP-01: original id "sorting"; no reference-game name in this file.
local SortingFloorRules = {}

SortingFloorRules.TRIAL_ID = "sorting"

-- TIMING (seconds since GO) ----------------------------------------------------
SortingFloorRules.LEAD = 2.0          -- first item reaches a station this long after GO
SortingFloorRules.GAP = 1.0           -- belt gap between two items at one station
SortingFloorRules.TELEGRAPH = 0.5     -- board flickers Hazard this long before a new rule
SortingFloorRules.DROP_TELEGRAPH = 0.7 -- lamp Signal + StandClear this long before the trapdoor
SortingFloorRules.MAX_STRIKES = 3
SortingFloorRules.RULE_MIN, SortingFloorRules.RULE_MAX = 8, 12 -- seconds between rule changes

-- How long an item is "at" a station: 1.6 s in round 1 down to 1.0 s.
function SortingFloorRules.window(roundIndex)
	local w = 1.6 - 0.3 * ((roundIndex or 1) - 1)
	if w < 1.0 then w = 1.0 end
	return w
end

-- ITEM SPACE ----------------------------------------------------------------------
SortingFloorRules.KINDS = {
	{ id = "parcel",  name = "PARCEL",  material = "plastic", shape = "box" },
	{ id = "can",     name = "CAN",     material = "metal",   shape = "cyl" },
	{ id = "bone",    name = "BONE",    material = "organic", shape = "rod" },
	{ id = "bottle",  name = "BOTTLE",  material = "glass",   shape = "cyl" },
	{ id = "syringe", name = "SYRINGE", material = "plastic", shape = "rod" },
	{ id = "battery", name = "BATTERY", material = "metal",   shape = "box" },
	{ id = "jar",     name = "JAR",     material = "glass",   shape = "box" },
	{ id = "fruit",   name = "FRUIT",   material = "organic", shape = "ball" },
}
SortingFloorRules.COLOURS = { "red", "green", "blue", "grey" }

local kindById = {}
for _, k in ipairs(SortingFloorRules.KINDS) do kindById[k.id] = k end
function SortingFloorRules.kind(id) return kindById[id] end

-- Every item the belt can carry: kind x colour x sealed (64). Used by the
-- exhaustive test and by nothing at runtime.
function SortingFloorRules.itemSpace()
	local out = {}
	for _, k in ipairs(SortingFloorRules.KINDS) do
		for _, c in ipairs(SortingFloorRules.COLOURS) do
			for _, sealed in ipairs({ true, false }) do
				out[#out + 1] = { kind = k.id, colour = c, sealed = sealed, material = k.material }
			end
		end
	end
	return out
end

-- RULES: the predicate sends an item to chute A, everything else goes to B.
-- `two` marks two-attribute rules (round 3, or the last round of a short
-- session). Text is the Machine's voice, shown verbatim on the board.
SortingFloorRules.RULES = {
	{ id = "sealed",  two = false, text = "SEALED -> A. OPEN -> B.",
		test = function(it) return it.sealed == true end },
	{ id = "metal",   two = false, text = "METAL -> A. ALL ELSE -> B.",
		test = function(it) return it.material == "metal" end },
	{ id = "organic", two = false, text = "ORGANIC -> A. ALL ELSE -> B.",
		test = function(it) return it.material == "organic" end },
	{ id = "glass",   two = false, text = "GLASS -> A. ALL ELSE -> B.",
		test = function(it) return it.material == "glass" end },
	{ id = "red",     two = false, text = "RED -> A. ALL ELSE -> B.",
		test = function(it) return it.colour == "red" end },
	{ id = "grey",    two = false, text = "GREY -> A. ALL ELSE -> B.",
		test = function(it) return it.colour == "grey" end },
	{ id = "open",    two = false, text = "OPEN -> A. SEALED -> B.",
		test = function(it) return it.sealed ~= true end },
	{ id = "red_sealed",     two = true, text = "RED AND SEALED -> A. ALL ELSE -> B.",
		test = function(it) return it.colour == "red" and it.sealed == true end },
	{ id = "open_plastic",   two = true, text = "OPEN PLASTIC -> A. ALL ELSE -> B.",
		test = function(it) return it.sealed ~= true and it.material == "plastic" end },
	{ id = "metal_or_glass", two = true, text = "METAL OR GLASS -> A. ALL ELSE -> B.",
		test = function(it) return it.material == "metal" or it.material == "glass" end },
	{ id = "blue_organic",   two = true, text = "BLUE ORGANIC -> A. ALL ELSE -> B.",
		test = function(it) return it.colour == "blue" and it.material == "organic" end },
}

local ruleById = {}
for _, r in ipairs(SortingFloorRules.RULES) do ruleById[r.id] = r end
function SortingFloorRules.rule(id) return ruleById[id] end

-- "A" or "B", never anything else. An item without a material (a bare
-- {kind=...} from the wire) is completed from its kind first.
function SortingFloorRules.apply(rule, item)
	if type(rule) == "string" then rule = ruleById[rule] end
	if not rule then return "B" end
	local it = item
	if it.material == nil and it.kind and kindById[it.kind] then
		it = { kind = it.kind, colour = it.colour, sealed = it.sealed, material = kindById[it.kind].material }
	end
	return rule.test(it) and "A" or "B"
end

-- Rules a round may draw from. Two-attribute rules only in round 3, or in the
-- last round of a session that has fewer than three.
function SortingFloorRules.list(roundIndex, roundsTotal)
	local hard = (roundIndex or 1) >= 3 or ((roundsTotal or 3) < 3 and (roundIndex or 1) >= (roundsTotal or 3))
	local out = {}
	for _, r in ipairs(SortingFloorRules.RULES) do
		if hard or not r.two then out[#out + 1] = r.id end
	end
	return out
end

-- SCHEDULE: { {at=0, ruleId}, {at=t1, ruleId}, ... } with 8-12 s between
-- changes, never the same rule twice in a row, every id eligible for the round.
function SortingFloorRules.schedule(nextInt, roundIndex, roundsTotal, seconds)
	local pool = SortingFloorRules.list(roundIndex, roundsTotal)
	local out = {}
	local t = 0
	local last = nil
	while t < seconds - 4 do
		local id = pool[nextInt(#pool)]
		if id == last and #pool > 1 then
			id = pool[nextInt(#pool)]
			if id == last then
				for _, alt in ipairs(pool) do
					if alt ~= last then id = alt break end
				end
			end
		end
		out[#out + 1] = { at = t, ruleId = id }
		last = id
		t = t + SortingFloorRules.RULE_MIN + (nextInt(SortingFloorRules.RULE_MAX - SortingFloorRules.RULE_MIN + 1) - 1)
	end
	return out
end

-- The rule in force at time t: the last entry whose `at` is not after t.
function SortingFloorRules.ruleAt(schedule, t)
	local cur = schedule[1] and schedule[1].ruleId or nil
	for _, e in ipairs(schedule) do
		if e.at <= t then cur = e.ruleId else break end
	end
	return cur
end

-- STREAM: per station, items at a shared cadence (window + gap) from LEAD until
-- the round ends. Attributes are drawn per item, so stations see different
-- things at the same moment while every station gets the same count.
function SortingFloorRules.generate(nextInt, seconds, roundIndex, stations)
	local w = SortingFloorRules.window(roundIndex)
	local out = {}
	for s = 1, stations do
		local list = {}
		local n = 0
		local t = SortingFloorRules.LEAD
		while t + w <= seconds - 0.5 do
			n = n + 1
			local k = SortingFloorRules.KINDS[nextInt(#SortingFloorRules.KINDS)]
			local c = SortingFloorRules.COLOURS[nextInt(#SortingFloorRules.COLOURS)]
			list[n] = {
				id = tostring(s) .. "-" .. tostring(n),
				station = s,
				kind = k.id,
				material = k.material,
				colour = c,
				sealed = nextInt(2) == 1,
				arriveAt = t,
				leaveAt = t + w,
			}
			t = t + w + SortingFloorRules.GAP
		end
		out[s] = list
	end
	return out
end

-- Is `now` inside the item's window at its station?
function SortingFloorRules.contains(item, now)
	return now >= item.arriveAt and now <= item.leaveAt
end

function SortingFloorRules.strike(strikes, ok)
	return ok and strikes or (strikes + 1)
end

function SortingFloorRules.dropped(strikes)
	return strikes >= SortingFloorRules.MAX_STRIKES
end

-- Ranking detail inside the band (the server wraps it in TrialKit.key):
-- alive: correct*10 - strikes*3 (never below 0); out: correct*10.
function SortingFloorRules.detail(alive, correct, strikes)
	local d
	if alive then
		d = (correct or 0) * 10 - (strikes or 0) * 3
	else
		d = (correct or 0) * 10
	end
	if d < 0 then d = 0 end
	if d > 999 then d = 999 end
	return d
end

return SortingFloorRules
