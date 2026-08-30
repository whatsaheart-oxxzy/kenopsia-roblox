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

-- ------------------------------------------------------------------------------
print(("progression: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
