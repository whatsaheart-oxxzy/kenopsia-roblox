-- tests/progression.lua -- Phase 4a: proves Shared/Rules/ProgressionRules
-- outside Roblox. PURE module, so a desktop Lua 5.1 runs it as-is.
-- Run from the repo root: lua tests/progression.lua
-- Exit code 0 only if every check passes (CI-friendly, the rules.lua pattern).

local ROOT = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"
local function loadModule(file, parent)
	local chunk = assert(loadfile(ROOT .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local passed, failed = 0, 0
local function check(ok, label, detail)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL: " .. label .. (detail ~= nil and (" -- " .. tostring(detail)) or ""))
	end
end

local Progression = loadModule("ProgressionRules.luau")

-- defaultProfile: shape completeness -----------------------------------------
local shape = {
	schemaVersion = "number", firstSeen = "number", lastSeen = "number",
	sessions = "number", roundsPlayed = "number", viableCount = "number",
	rejectedCount = "number", bestBand = "number", trialStats = "table",
	streak = "table", xp = "number", clearance = "number", quests = "table",
	emotes = "table", crates = "table", settings = "table", analytics = "table",
}
local p = Progression.defaultProfile()
for key, want in pairs(shape) do
	check(type(p[key]) == want, "defaultProfile has " .. key .. " (" .. want .. ")", type(p[key]))
end
check(p.schemaVersion == 1, "defaultProfile schemaVersion is 1", p.schemaVersion)
for _, id in ipairs({ "birdhunt", "minefield", "canteen" }) do
	local row = p.trialStats[id]
	check(type(row) == "table"
		and type(row.plays) == "number" and type(row.wins) == "number" and type(row.best) == "number",
		"defaultProfile trialStats." .. id .. " has plays/wins/best")
end
check(type(p.streak.current) == "number" and type(p.streak.best) == "number"
	and type(p.streak.lastDayStamp) == "number" and type(p.streak.shield) == "number",
	"defaultProfile streak has current/best/lastDayStamp/shield")
check(type(p.quests.day) == "number" and type(p.quests.slots) == "table"
	and type(p.quests.progress) == "table" and type(p.quests.claimed) == "table",
	"defaultProfile quests has day/slots/progress/claimed")
check(type(p.emotes.owned) == "table" and type(p.emotes.equipped) == "string"
	and type(p.emotes.wheel) == "table", "defaultProfile emotes has owned/equipped/wheel")
check(type(p.crates.keys) == "number" and type(p.crates.fragments) == "number",
	"defaultProfile crates has keys/fragments")
check(type(p.analytics.d1Stamp) == "number", "defaultProfile analytics has d1Stamp")
local pA, pB = Progression.defaultProfile(), Progression.defaultProfile()
pA.trialStats.birdhunt.plays = 99
pA.streak.current = 99
check(pB.trialStats.birdhunt.plays == 0 and pB.streak.current == 0,
	"defaultProfile returns independent tables (no shared references)")

-- XP table --------------------------------------------------------------------
for _, key in ipairs({ "roundSurvived", "roundWon", "trialWon", "viable", "rejected", "dailyFirst" }) do
	check(type(Progression.XP[key]) == "number" and Progression.XP[key] > 0,
		"XP." .. key .. " is a positive number", Progression.XP[key])
end
check(Progression.XP.viable > Progression.XP.rejected, "XP.viable beats XP.rejected")

-- sessionXp -------------------------------------------------------------------
local xpViable = Progression.sessionXp({ viable = true, roundsPlayed = 4, trialsWon = 2 })
check(xpViable == 4 * 25 + 2 * 60 + 150, "sessionXp: viable 4 rounds 2 trial wins", xpViable)
local xpRejected = Progression.sessionXp({ viable = false, roundsPlayed = 4, trialsWon = 2 })
check(xpRejected == 4 * 25 + 2 * 60 + 50, "sessionXp: rejected same session", xpRejected)
check(xpViable > xpRejected, "sessionXp: viable outpays rejected on identical play")
check(Progression.sessionXp({ roundsWon = 3 }) == 3 * 40 + 50, "sessionXp: roundsWon counted")
check(Progression.sessionXp({ dailyFirst = true }) - Progression.sessionXp({}) == Progression.XP.dailyFirst,
	"sessionXp: dailyFirst adds exactly XP.dailyFirst")
check(Progression.sessionXp() == Progression.XP.rejected, "sessionXp: nil summary is a bare rejected verdict")

-- clearance -------------------------------------------------------------------
check(#Progression.CLEARANCE >= 2, "CLEARANCE has bands")
check(Progression.CLEARANCE[1].xp == 0, "CLEARANCE starts at 0")
for i = 2, #Progression.CLEARANCE do
	check(Progression.CLEARANCE[i].xp > Progression.CLEARANCE[i - 1].xp,
		"CLEARANCE thresholds strictly increasing at band " .. i)
end
local function bandAt(xp)
	local index, name = Progression.clearanceFor(xp)
	return index, name
end
local i0, n0 = bandAt(0)
check(i0 == 1 and n0 == "PROBATIONARY", "clearanceFor(0) = PROBATIONARY", n0)
check(bandAt(499) == 1, "clearanceFor(499) still band 1")
check(bandAt(500) == 2, "clearanceFor(500) reaches GRADE_D")
check(bandAt(1499) == 2, "clearanceFor(1499) still band 2")
check(bandAt(1500) == 3, "clearanceFor(1500) reaches GRADE_C")
check(bandAt(3500) == 4, "clearanceFor(3500) reaches GRADE_B")
check(bandAt(7000) == 5, "clearanceFor(7000) reaches GRADE_A")
check(bandAt(13999) == 5, "clearanceFor(13999) still band 5")
local iTop, nTop = bandAt(14000)
check(iTop == 6 and nTop == "OVERSEER_CANDIDATE", "clearanceFor(14000) = OVERSEER_CANDIDATE", nTop)
check(bandAt(10 ^ 9) == 6, "clearanceFor(huge) clamps to the top band")
check(bandAt(-5) == 1, "clearanceFor(negative) clamps to band 1")

-- clearance names (Phase 4b: the SHIFT REPORT prints these verbatim) ----------
-- clearanceFor's SECOND return is the band name; the report renders it raw,
-- so every name must be a display-safe uppercase/underscore string.
for i, band in ipairs(Progression.CLEARANCE) do
	check(type(band.name) == "string" and string.match(band.name, "^[A-Z_]+$") ~= nil,
		"CLEARANCE band " .. i .. " name is uppercase/underscore only", tostring(band.name))
	local index, name = Progression.clearanceFor(band.xp)
	check(index == i and name == band.name,
		"clearanceFor(" .. band.xp .. ") returns the band name as second value", tostring(name))
end

-- streak ----------------------------------------------------------------------
local s = { current = 0, best = 0, lastDayStamp = 0, shield = 0 }
Progression.tickStreak(s, 100)
check(s.current == 1 and s.lastDayStamp == 100 and s.best == 1, "streak: first day = 1")
Progression.tickStreak(s, 101)
check(s.current == 2 and s.best == 2, "streak: consecutive day increments", s.current)
Progression.tickStreak(s, 101)
check(s.current == 2 and s.lastDayStamp == 101, "streak: same-day tick is idempotent")
Progression.tickStreak(s, 99)
check(s.current == 2 and s.lastDayStamp == 101, "streak: a stale (earlier) tick never rewinds")
Progression.tickStreak(s, 104) -- days 102 and 103 missed, no shield
check(s.current == 1, "streak: reset after a 2-day gap", s.current)
check(s.best == 2, "streak: best survives the reset")

local s2 = { current = 0, best = 0, lastDayStamp = 0, shield = 0 }
for day = 200, 206 do Progression.tickStreak(s2, day) end
check(s2.current == 7, "streak: seven consecutive days", s2.current)
check(s2.shield == 1, "streak: shield earned at 7 consecutive days", s2.shield)
Progression.tickStreak(s2, 208) -- day 207 missed, shield covers it
check(s2.current == 8, "streak: shield covers exactly one missed day", s2.current)
check(s2.shield == 0, "streak: shield silently consumed", s2.shield)
Progression.tickStreak(s2, 210) -- day 209 missed, no shield left
check(s2.current == 1, "streak: no second cover inside the same 7 days", s2.current)
for day = 211, 216 do Progression.tickStreak(s2, day) end
check(s2.current == 7 and s2.shield == 1, "streak: shield re-armed at the next multiple of 7")
check(s2.best == 8, "streak: best tracked through the shielded run", s2.best)

-- quests ----------------------------------------------------------------------
-- Every metric must be countable from birdhunt / minefield / canteen play
-- alone -- the three shipped trials.
local allowedMetrics = {
	roundsPlayed = true, sessions = true, viable = true, trialWins = true,
	trialwin_birdhunt = true, trialwin_minefield = true, trialwin_canteen = true,
}
check(#Progression.QuestPool >= 6, "QuestPool has at least 6 quests", #Progression.QuestPool)
local seenIds = {}
for _, quest in ipairs(Progression.QuestPool) do
	local id = tostring(quest.id)
	check(type(quest.id) == "string" and type(quest.text) == "string"
		and type(quest.goal) == "number" and quest.goal >= 1
		and type(quest.metric) == "string", "quest well-formed: " .. id)
	check(allowedMetrics[quest.metric] == true,
		"quest metric countable from the three shipped trials: " .. id, quest.metric)
	check(not seenIds[quest.id], "quest id unique: " .. id)
	seenIds[quest.id] = true
end

-- rollQuests ------------------------------------------------------------------
local byId = {}
for _, quest in ipairs(Progression.QuestPool) do byId[quest.id] = true end
local r1 = Progression.rollQuests(20330)
local r2 = Progression.rollQuests(20330)
check(#r1 == 3, "rollQuests deals 3 slots", #r1)
check(r1[1] == r2[1] and r1[2] == r2[2] and r1[3] == r2[3],
	"rollQuests deterministic for the same day")
check(r1[1] ~= r1[2] and r1[1] ~= r1[3] and r1[2] ~= r1[3], "rollQuests slots distinct")
for i = 1, 3 do
	check(byId[r1[i]] == true, "rollQuests slot " .. i .. " comes from the pool", r1[i])
end
local r3 = Progression.rollQuests(1, function(n) return 1 end)
check(r3[1] == Progression.QuestPool[1].id and r3[2] == Progression.QuestPool[2].id
	and r3[3] == Progression.QuestPool[3].id, "rollQuests honors an injected rng")
local differs = false
for day = 20331, 20360 do
	local r = Progression.rollQuests(day)
	if r[1] ~= r1[1] or r[2] ~= r1[2] or r[3] ~= r1[3] then differs = true end
end
check(differs, "rollQuests varies across days (not a constant deal)")

-- WORK ORDERS (Phase 4c): economy constants, questById, sessionMetrics --------
check(Progression.FRAGMENTS_PER_KEY == 5, "FRAGMENTS_PER_KEY is 5", Progression.FRAGMENTS_PER_KEY)
check(Progression.QuestXp == 100, "QuestXp is 100", Progression.QuestXp)
local q6 = Progression.questById("q_rounds6")
check(type(q6) == "table" and q6.metric == "roundsPlayed" and q6.goal == 6,
	"questById returns the pool entry")
check(q6 == Progression.QuestPool[1], "questById returns the entry itself, not a copy")
check(Progression.questById("q_nope") == nil, "questById nil for an unknown id")

local m = Progression.sessionMetrics({ viable = true, roundsPlayed = 7, trialsWon = 2 },
	{ birdhunt = true, canteen = true })
check(m.roundsPlayed == 7, "sessionMetrics passes roundsPlayed through", m.roundsPlayed)
check(m.sessions == 1, "sessionMetrics: one verdict = sessions 1", m.sessions)
check(m.viable == 1, "sessionMetrics: viable verdict = 1", m.viable)
check(m.trialWins == 2, "sessionMetrics: trialWins from summary.trialsWon", m.trialWins)
check(m.trialwin_birdhunt == 1 and m.trialwin_canteen == 1 and m.trialwin_minefield == 0,
	"sessionMetrics: per-trial wins from the stash, missing trial = 0")
local mEmpty = Progression.sessionMetrics()
check(mEmpty.roundsPlayed == 0 and mEmpty.sessions == 1 and mEmpty.viable == 0
	and mEmpty.trialWins == 0 and mEmpty.trialwin_birdhunt == 0,
	"sessionMetrics: nil summary/stash = zeros (sessions still 1)")
for _, quest in ipairs(Progression.QuestPool) do
	check(mEmpty[quest.metric] ~= nil,
		"sessionMetrics snapshot defines pool metric: " .. tostring(quest.id), quest.metric)
end

-- applyQuests: a day change re-rolls, zeroes progress, loses unclaimed --------
local aq = { day = 5, slots = { "q_rounds6" }, progress = { 5 }, claimed = {} }
local res
aq, res = Progression.applyQuests(aq, 6, {})
check(aq.day == 6, "applyQuests re-rolls on a day change", aq.day)
check(#aq.slots == 3, "applyQuests re-roll deals 3 fresh slots", #aq.slots)
local sameDeal = Progression.rollQuests(6)
check(aq.slots[1] == sameDeal[1] and aq.slots[2] == sameDeal[2] and aq.slots[3] == sameDeal[3],
	"applyQuests re-roll IS rollQuests(day) (same deal on every server)")
check(aq.progress[1] == 0 and aq.progress[2] == 0 and aq.progress[3] == 0,
	"applyQuests re-roll zeroes progress (yesterday's 5 is lost)")
check(aq.claimed[1] == false and aq.claimed[2] == false and aq.claimed[3] == false,
	"applyQuests re-roll clears claimed (dense false, no nil holes)")
check(#res.completed == 0 and res.fragments == 0 and res.xp == 0,
	"applyQuests: empty metrics complete nothing")

-- applyQuests: progress ticks, clamps, pays exactly once ----------------------
local wq = { day = 9, slots = { "q_rounds6", "q_viable1", "q_trialwins3" },
	progress = { 0, 0, 0 }, claimed = { false, false, false } }
wq, res = Progression.applyQuests(wq, 9, { roundsPlayed = 4 })
check(wq.progress[1] == 4 and wq.claimed[1] == false and #res.completed == 0,
	"applyQuests: progress ticks by the metric, short of goal")
wq, res = Progression.applyQuests(wq, 9, { roundsPlayed = 9, viable = 1 })
check(wq.progress[1] == 6, "applyQuests: progress clamps at goal", wq.progress[1])
check(wq.claimed[1] == true and wq.claimed[2] == true,
	"applyQuests: completion marks claimed (auto-claim)")
check(#res.completed == 2 and res.completed[1] == "q_rounds6" and res.completed[2] == "q_viable1",
	"applyQuests: completed ids in slot order", table.concat(res.completed, ","))
check(res.fragments == 2 and res.xp == 2 * Progression.QuestXp,
	"applyQuests pays 1 fragment + QuestXp per completion")
check(wq.progress[3] == 0 and wq.claimed[3] == false,
	"applyQuests: untouched slot stays open (missing metric adds 0)")
wq, res = Progression.applyQuests(wq, 9, { roundsPlayed = 5, viable = 1, trialWins = 1 })
check(wq.progress[1] == 6 and #res.completed == 0 and res.fragments == 0 and res.xp == 0,
	"applyQuests: same-day re-apply pays NOTHING again (idempotent claim)")
check(wq.progress[3] == 1 and wq.claimed[3] == false,
	"applyQuests: the open slot still ticks on the re-apply", wq.progress[3])

-- the stash path end to end: recordTrial's win set -> metrics -> completion ---
local bq = { day = 11, slots = { "q_bird1", "q_trialwins3", "q_sessions2" },
	progress = { 0, 0, 0 }, claimed = { false, false, false } }
local bres
bq, bres = Progression.applyQuests(bq, 11,
	Progression.sessionMetrics({ viable = true, roundsPlayed = 8, trialsWon = 1 }, { birdhunt = true }))
check(#bres.completed == 1 and bres.completed[1] == "q_bird1",
	"stash -> sessionMetrics -> applyQuests completes the per-trial order")
check(bq.progress[2] == 1 and bq.progress[3] == 1,
	"trialWins and sessions tick alongside the completion")

-- fragments -> keys: the CALLER's roll-up, proved at the boundary -------------
-- (Profiles.recordSession runs exactly this arithmetic over crates. It is a
-- DIVISION, not a `while f >= perKey` loop: recordSession never yields, so a
-- corrupted stored counter has to settle in O(1) rather than spin the verdict
-- thread, and NaN/inf/negative have to reset -- none of them round-trips a
-- DataStore, so one would kill every future write for that player.)
local function rollUp(crates, gained)
	local perKey = tonumber(Progression.FRAGMENTS_PER_KEY) or 0
	local fragments = (tonumber(crates.fragments) or 0) + gained
	local keys = tonumber(crates.keys) or 0
	if not (fragments >= 0 and fragments < math.huge) then fragments = 0 end
	if not (keys >= 0 and keys < math.huge) then keys = 0 end
	if perKey >= 1 and fragments >= perKey then
		local earned = math.floor(fragments / perKey)
		fragments = fragments - earned * perKey
		keys = keys + earned
	end
	crates.fragments = fragments
	crates.keys = keys
	return crates
end
local crates = rollUp({ keys = 0, fragments = 4 }, 0)
check(crates.keys == 0 and crates.fragments == 4, "4 fragments stay fragments")
crates = rollUp(crates, 1)
check(crates.keys == 1 and crates.fragments == 0, "the 5th fragment becomes a key (boundary)")
crates = rollUp(crates, 12)
check(crates.keys == 3 and crates.fragments == 2, "a big grant rolls up multiple keys")
-- the division must agree with the while-loop it replaced, value for value
for gained = 0, 20 do
	local loopF, loopK = gained, 0
	while loopF >= Progression.FRAGMENTS_PER_KEY do
		loopF = loopF - Progression.FRAGMENTS_PER_KEY
		loopK = loopK + 1
	end
	local c = rollUp({ keys = 0, fragments = 0 }, gained)
	check(c.fragments == loopF and c.keys == loopK,
		"roll-up == the while-loop it replaced, gained " .. gained, c.fragments .. "/" .. c.keys)
end
-- BOUNDED: a corrupted counter settles in one step instead of spinning
local big = rollUp({ keys = 0, fragments = 1e9 }, 0)
check(big.keys == 200000000 and big.fragments == 0,
	"a corrupted 1e9 counter settles in O(1), no spin", big.keys .. "/" .. big.fragments)
check(rollUp({ keys = 0, fragments = 0 / 0 }, 0).fragments == 0,
	"a NaN counter resets to 0 (NaN cannot round-trip a DataStore)")
check(rollUp({ keys = math.huge, fragments = math.huge }, 0).keys == 0,
	"an infinite counter resets to 0")
check(rollUp({ keys = 0, fragments = -7 }, 0).fragments == 0,
	"a negative counter resets to 0")

-- pool honesty: a session cannot trivially sweep its work orders --------------
-- Every completed verdict guarantees exactly sessions = 1 and roundsPlayed >=
-- 1; no other metric is guaranteed (viable only pays a winner, trialWins and
-- trialwin_* only board tops). A quest is a GIMME if a guaranteed metric
-- meets its goal on any verdict at all -- metric sessions/roundsPlayed with
-- goal <= 1. The deliberate goal-1 orders (q_viable1 / q_bird1 style) ride
-- NON-guaranteed metrics, so the guarantee filter already excuses them.
local guaranteed = { sessions = true, roundsPlayed = true }
for _, quest in ipairs(Progression.QuestPool) do
	check(not (guaranteed[quest.metric] and quest.goal <= 1),
		"no gimme quest (guaranteed metric at goal <= 1): " .. tostring(quest.id))
end
for day = 20330, 20359 do
	local slots = Progression.rollQuests(day)
	local nonTrivial = 0
	for i = 1, #slots do
		local quest = Progression.questById(slots[i])
		if quest and not (guaranteed[quest.metric] and quest.goal <= 1) then
			nonTrivial = nonTrivial + 1
		end
	end
	check(nonTrivial >= 2, "day " .. day .. ": at least 2 of 3 slots demand real play", nonTrivial)
end
-- ... and the median LOSING session (9 rounds, no verdict, no board top)
-- completes at most ONE order of any day's deal: the ~1-of-3 sizing.
local median = Progression.sessionMetrics({ viable = false, roundsPlayed = 9, trialsWon = 0 }, {})
for day = 20330, 20359 do
	local dq, dres = Progression.applyQuests(
		{ day = 0, slots = {}, progress = {}, claimed = {} }, day, median)
	check(#dres.completed <= 1,
		"day " .. day .. ": a median losing session completes at most 1 of " .. #dq.slots,
		table.concat(dres.completed, ","))
end

-- ------------------------------------------------------------------------------
print(("progression: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
