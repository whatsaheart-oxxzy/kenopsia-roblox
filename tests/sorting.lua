-- P4.1 SORTING FLOOR offline proof: the PURE half of the trial.
--
--     lua tests/sorting.lua
--
-- Loads Shared/Rules/SortingFloorRules.luau through the same shim as
-- tests/trialrules.lua and proves: every rule sorts every item of the item
-- space to exactly A or B and is not degenerate; rule pools per round; the
-- schedule's spacing, first entry and no-repeat; the stream's per-station
-- counts, windows and cadence; window containment; strikes; ranking detail;
-- determinism. Exit code 0 only if every check passes.

local ROOT = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"

local function loadModule(file, parent)
	local chunk = assert(loadfile(ROOT .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local S = loadModule("SortingFloorRules.luau")

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

-- a small seeded LCG: the server injects TrialKit.rng, the proof injects this
local function lcg(seed)
	local s = seed
	return function(n)
		s = (s * 1103515245 + 12345) % 2147483648
		return (math.floor(s / 65536) % n) + 1
	end
end

-- 1. ITEM SPACE + RULES --------------------------------------------------------
print("\nRULES -- every rule sorts the whole item space, none is degenerate")
local space = S.itemSpace()
check(#S.KINDS == 8 and #S.COLOURS == 4 and #space == 64, "8 kinds x 4 colours x sealed = 64 items", tostring(#space))
check(#S.RULES >= 10, "at least ten rules", tostring(#S.RULES))

local allValid, allBothSides = true, true
for _, r in ipairs(S.RULES) do
	local a, b = 0, 0
	for _, it in ipairs(space) do
		local v = S.apply(r, it)
		if v == "A" then a = a + 1 elseif v == "B" then b = b + 1 else allValid = false end
	end
	if a == 0 or b == 0 then allBothSides = false end
	if type(r.text) ~= "string" or r.text == "" or type(r.id) ~= "string" then allValid = false end
end
check(allValid, "apply() returns only A or B for every rule x item; every rule has id + text")
check(allBothSides, "every rule sends some items to A and some to B")
check(S.apply("red", { kind = "can", colour = "red", sealed = false }) == "A", "a wire item (no material) is completed from its kind")
check(S.apply("metal", { kind = "can", colour = "red" }) == "A" and S.apply("metal", { kind = "bone", colour = "red" }) == "B", "metal rule reads the material off the kind")
check(S.apply("nope", { kind = "can" }) == "B", "unknown rule id sorts to B, never errors")

-- 2. RULE POOLS ---------------------------------------------------------------
print("\nPOOLS -- two-attribute rules only late")
local function hasTwo(list)
	for _, id in ipairs(list) do if S.rule(id).two then return true end end
	return false
end
check(not hasTwo(S.list(1, 3)) and not hasTwo(S.list(2, 3)), "rounds 1-2 of three: single-attribute rules only")
check(hasTwo(S.list(3, 3)), "round 3 of three adds two-attribute rules")
check(hasTwo(S.list(2, 2)) and not hasTwo(S.list(1, 2)), "a two-round session gets them in its last round")

-- 3. SCHEDULE -----------------------------------------------------------------
print("\nSCHEDULE -- first rule at 0, 8-12 s apart, never the same twice in a row")
local okSpacing, okRepeat, okEligible, okFirst, okEnd = true, true, true, true, true
for seed = 1, 40 do
	for round = 1, 3 do
		local sch = S.schedule(lcg(seed), round, 3, 40)
		local pool = {}
		for _, id in ipairs(S.list(round, 3)) do pool[id] = true end
		if not sch[1] or sch[1].at ~= 0 then okFirst = false end
		for i, e in ipairs(sch) do
			if not pool[e.ruleId] then okEligible = false end
			if i > 1 then
				local gap = e.at - sch[i - 1].at
				if gap < S.RULE_MIN or gap > S.RULE_MAX then okSpacing = false end
				if e.ruleId == sch[i - 1].ruleId then okRepeat = false end
			end
			if e.at >= 40 - 4 then okEnd = false end
		end
	end
end
check(okFirst, "first entry at t=0")
check(okSpacing, "consecutive changes 8-12 s apart")
check(okRepeat, "no rule repeats back to back")
check(okEligible, "every scheduled rule is eligible for its round")
check(okEnd, "no change inside the last 4 s")
local sch = S.schedule(lcg(7), 1, 3, 40)
check(S.ruleAt(sch, -1) == sch[1].ruleId and S.ruleAt(sch, sch[#sch].at + 100) == sch[#sch].ruleId, "ruleAt clamps before the first and after the last change")
if #sch >= 2 then
	check(S.ruleAt(sch, sch[2].at - 0.01) == sch[1].ruleId and S.ruleAt(sch, sch[2].at) == sch[2].ruleId, "ruleAt switches exactly at the change time")
end

-- 4. STREAM -------------------------------------------------------------------
print("\nSTREAM -- same count per station, windows in order, cadence window+gap")
local okCount, okOrder, okWindow, okLead, okEnd2, okIds = true, true, true, true, true, true
for seed = 1, 20 do
	for round = 1, 3 do
		local st = S.generate(lcg(seed), 40, round, 4)
		local w = S.window(round)
		local counts = {}
		for s = 1, 4 do
			counts[s] = #st[s]
			local prev = nil
			for n, it in ipairs(st[s]) do
				if it.id ~= tostring(s) .. "-" .. tostring(n) or it.station ~= s then okIds = false end
				if math.abs((it.leaveAt - it.arriveAt) - w) > 1e-9 then okWindow = false end
				if prev and it.arriveAt < prev.leaveAt + S.GAP - 1e-9 then okOrder = false end
				if it.arriveAt < S.LEAD then okLead = false end
				if it.leaveAt > 40 - 0.5 + 1e-9 then okEnd2 = false end
				prev = it
			end
		end
		local lo, hi = math.min(counts[1], counts[2], counts[3], counts[4]), math.max(counts[1], counts[2], counts[3], counts[4])
		if hi - lo > 1 then okCount = false end
	end
end
check(okCount, "every station gets the same item count (+-1)")
check(okOrder, "items at one station never overlap and keep the gap")
check(okWindow, "window length per round: 1.6 / 1.3 / 1.0 s")
check(okLead, "first item arrives after LEAD")
check(okEnd2, "last item leaves before the round ends")
check(okIds, "item ids are <station>-<n>")
check(S.window(1) == 1.6 and S.window(2) == 1.3 and math.abs(S.window(3) - 1.0) < 1e-9 and S.window(9) == 1.0, "window() floors at 1.0 s")
local one = S.generate(lcg(3), 40, 1, 4)[1]
check(#one >= 12 and #one * 10 <= 999, "item budget per station keeps correct*10 under the band width", tostring(#one))

-- 5. WINDOW / STRIKES / DETAIL --------------------------------------------------
print("\nWINDOW + STRIKES + DETAIL")
local it = { arriveAt = 5, leaveAt = 6.6 }
check(S.contains(it, 5) and S.contains(it, 6.6) and not S.contains(it, 4.99) and not S.contains(it, 6.61), "contains() is inclusive at both edges")
check(S.strike(0, true) == 0 and S.strike(0, false) == 1 and S.strike(2, false) == 3, "strike() counts only wrong sorts")
check(not S.dropped(2) and S.dropped(3), "dropped() at MAX_STRIKES = 3")
check(S.detail(true, 10, 0) == 100 and S.detail(true, 10, 2) == 94 and S.detail(true, 0, 3) == 0, "alive detail = correct*10 - strikes*3, floored at 0")
check(S.detail(false, 7, 3) == 70, "out detail ignores strikes")
check(S.detail(true, 200, 0) == 999, "detail capped at 999")

-- 6. DETERMINISM ---------------------------------------------------------------
print("\nDETERMINISM")
local a1 = S.generate(lcg(11), 40, 2, 3)
local a2 = S.generate(lcg(11), 40, 2, 3)
local b1 = S.generate(lcg(12), 40, 2, 3)
local same, differ = true, false
for s = 1, 3 do
	for n, x in ipairs(a1[s]) do
		local y = a2[s][n]
		if not y or x.kind ~= y.kind or x.colour ~= y.colour or x.sealed ~= y.sealed then same = false end
		local z = b1[s][n]
		if z and (x.kind ~= z.kind or x.colour ~= z.colour or x.sealed ~= z.sealed) then differ = true end
	end
end
check(same, "same seed -> identical stream")
check(differ, "different seed -> different stream")
local s1, s2 = S.schedule(lcg(5), 2, 3, 40), S.schedule(lcg(5), 2, 3, 40)
local sameSch = #s1 == #s2
for i, e in ipairs(s1) do if not s2[i] or s2[i].at ~= e.at or s2[i].ruleId ~= e.ruleId then sameSch = false end end
check(sameSch, "same seed -> identical schedule")

print(string.format("\n%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
