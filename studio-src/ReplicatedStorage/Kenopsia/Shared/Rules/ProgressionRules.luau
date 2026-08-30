--!nonstrict
-- PROGRESSION RULES (Phase 4a) -- the retention foundation's one pure file.
--
-- PURE, the Pacing discipline in full: no game, no services, no instances,
-- no os/time -- every number that depends on "now" is passed IN (tickStreak
-- takes a dayStamp, rollQuests takes the day). The file must parse under
-- BOTH Luau and Lua 5.1, because tests/progression.lua proves it with a
-- desktop interpreter: no type annotations, no generalized iteration
-- (pairs/ipairs only), no table.create/clear/freeze, no `continue`, no
-- `+=`, no `//`.
--
-- This is the ONE place the profile shape lives. Services/Profiles owns the
-- DataStore traffic and the timing; every rule it applies -- defaults, XP,
-- clearance bands, the streak shield, the quest pool -- is defined and
-- provable here.

local ProgressionRules = {}

-- XP --------------------------------------------------------------------------
-- Per-verdict grants. `viable` deliberately beats `rejected`: a loss still
-- pays (the session was worked), but never as much as the verdict itself.
ProgressionRules.XP = {
	roundSurvived = 25,
	roundWon = 40,
	trialWon = 60,
	viable = 150,
	rejected = 50,
	dailyFirst = 200,
}

-- summary = { viable, roundsPlayed, roundsWon, trialsWon, dailyFirst }.
-- Missing fields count as zero/false; exactly one of viable/rejected pays.
function ProgressionRules.sessionXp(summary)
	if type(summary) ~= "table" then summary = {} end
	local XP = ProgressionRules.XP
	local total = 0
	total = total + (tonumber(summary.roundsPlayed) or 0) * XP.roundSurvived
	total = total + (tonumber(summary.roundsWon) or 0) * XP.roundWon
	total = total + (tonumber(summary.trialsWon) or 0) * XP.trialWon
	if summary.viable then
		total = total + XP.viable
	else
		total = total + XP.rejected
	end
	if summary.dailyFirst then
		total = total + XP.dailyFirst
	end
	return total
end

-- CLEARANCE -------------------------------------------------------------------
-- Bands in ascending xp order; the first threshold MUST be 0 so every xp maps
-- somewhere. clearanceFor returns the HIGHEST band whose threshold is met.
ProgressionRules.CLEARANCE = {
	{ name = "PROBATIONARY", xp = 0 },
	{ name = "GRADE_D", xp = 500 },
	{ name = "GRADE_C", xp = 1500 },
	{ name = "GRADE_B", xp = 3500 },
	{ name = "GRADE_A", xp = 7000 },
	{ name = "OVERSEER_CANDIDATE", xp = 14000 },
}

function ProgressionRules.clearanceFor(xp)
	xp = tonumber(xp) or 0
	local index = 1
	for i, band in ipairs(ProgressionRules.CLEARANCE) do
		if xp >= band.xp then index = i end
	end
	return index, ProgressionRules.CLEARANCE[index].name
end

-- PROFILE SHAPE (schema v1) ---------------------------------------------------
-- The three shipped trials. trialStats rows for OTHER ids may still appear at
-- runtime (Profiles.recordTrial creates one for any id it is handed), which is
-- exactly the forward-compat behaviour a growing playlist needs.
ProgressionRules.TRIAL_IDS = { "birdhunt", "minefield", "canteen" }

local function freshTrialStats()
	local out = {}
	for _, id in ipairs(ProgressionRules.TRIAL_IDS) do
		out[id] = { plays = 0, wins = 0, best = 0 }
	end
	return out
end

-- Every call returns INDEPENDENT tables -- nothing here may be shared, or two
-- players' volatile profiles would write through each other.
function ProgressionRules.defaultProfile()
	return {
		schemaVersion = 1,
		firstSeen = 0,
		lastSeen = 0,
		sessions = 0,
		roundsPlayed = 0,
		viableCount = 0,
		rejectedCount = 0,
		-- best (lowest) shared final-board place ever taken; 0 = no verdict yet
		bestBand = 0,
		trialStats = freshTrialStats(),
		streak = { current = 0, best = 0, lastDayStamp = 0, shield = 0 },
		xp = 0,
		clearance = 1,
		quests = { day = 0, slots = {}, progress = {}, claimed = {} },
		emotes = { owned = {}, equipped = "", wheel = {} },
		crates = { keys = 0, fragments = 0 },
		settings = {},
		analytics = { d1Stamp = 0 },
	}
end

-- STREAK ----------------------------------------------------------------------
-- dayStamp = floor(epochSeconds / 86400), computed by the CALLER -- this file
-- never reads a clock. One tick per verdict, mutating and returning `streak`:
--   dayStamp < last  -> ignored (a stale tick never rewinds the record);
--   same day         -> nothing moves (idempotent);
--   day + 1          -> the streak continues;
--   day + 2 + shield -> exactly one missed day, silently covered; the shield
--                       is consumed and cannot fire again until the streak
--                       climbs to its next multiple of 7;
--   anything else    -> reset to 1.
-- The shield is earned at every multiple of 7 consecutive days, capped at 1
-- banked. An earned shield survives a full reset (it was paid for); the cap
-- still makes "at most one covered miss per 7 earned days" provable --
-- tests/progression.lua walks the exact sequence.
function ProgressionRules.tickStreak(streak, dayStamp)
	if type(streak) ~= "table" then
		streak = { current = 0, best = 0, lastDayStamp = 0, shield = 0 }
	end
	dayStamp = tonumber(dayStamp) or 0
	local last = tonumber(streak.lastDayStamp) or 0
	if last ~= 0 and dayStamp <= last then
		return streak
	end
	-- selene: allow(if_same_then_else) -- first-ever tick and a broken run both
	-- land on 1; the duplicate blocks keep the four cases readable as cases.
	if last == 0 then
		streak.current = 1
	elseif dayStamp == last + 1 then
		streak.current = (tonumber(streak.current) or 0) + 1
	elseif dayStamp == last + 2 and (tonumber(streak.shield) or 0) > 0 then
		streak.shield = (tonumber(streak.shield) or 0) - 1
		streak.current = (tonumber(streak.current) or 0) + 1
	else
		streak.current = 1
	end
	streak.lastDayStamp = dayStamp
	if streak.current > (tonumber(streak.best) or 0) then
		streak.best = streak.current
	end
	if streak.current % 7 == 0 and (tonumber(streak.shield) or 0) < 1 then
		streak.shield = 1
	end
	return streak
end

-- QUESTS ----------------------------------------------------------------------
-- Sized for the three shipped trials only: every metric below is countable
-- from birdhunt / minefield / canteen play alone, so no quest can demand a
-- trial that is not in the playlist. LIVE since Phase 4c: applyQuests below
-- ticks progress at every verdict and auto-claims completions (its header
-- documents the decision); the pool and the roll are provable since 4a.
-- Machine voice: uppercase, trailing underscore, no punctuation games.
ProgressionRules.QuestPool = {
	{ id = "q_rounds6", text = "COMPLETE 6 ROUNDS_", goal = 6, metric = "roundsPlayed" },
	{ id = "q_rounds12", text = "COMPLETE 12 ROUNDS_", goal = 12, metric = "roundsPlayed" },
	{ id = "q_sessions2", text = "SEE 2 VERDICTS THROUGH_", goal = 2, metric = "sessions" },
	{ id = "q_viable1", text = "BE FOUND VIABLE_", goal = 1, metric = "viable" },
	{ id = "q_trialwins3", text = "TOP ANY BOARD 3 TIMES_", goal = 3, metric = "trialWins" },
	{ id = "q_bird1", text = "TOP THE BOARD IN BIRD HUNTING_", goal = 1, metric = "trialwin_birdhunt" },
	{ id = "q_mine1", text = "TOP THE BOARD IN DEAD ZONE_", goal = 1, metric = "trialwin_minefield" },
	{ id = "q_canteen1", text = "TOP THE BOARD IN CANTEEN PROTOCOL_", goal = 1, metric = "trialwin_canteen" },
}

-- Deterministic three-slot deal. `rngInts` is an OPTIONAL injected integer
-- draw -- rngInts(n) -> 1..n -- so a caller with a seeded Random can drive it;
-- without one the deal derives from `day` alone through a small LCG, so the
-- same day deals the same three quests on every server. Slots are quest ids,
-- always distinct (each pick is removed from the working pool).
function ProgressionRules.rollQuests(day, rngInts)
	day = tonumber(day) or 0
	local draw = rngInts
	if type(draw) ~= "function" then
		local state = (day * 2654435761 + 1013904223) % 2147483647
		draw = function(n)
			state = (state * 16807) % 2147483647
			return (state % n) + 1
		end
	end
	-- selene: allow(manual_table_clone) -- table.clone is Luau-only; this file
	-- must load under plain Lua 5.1 for tests/progression.lua.
	local pool = {}
	for i, quest in ipairs(ProgressionRules.QuestPool) do
		pool[i] = quest
	end
	local slots = {}
	for i = 1, 3 do
		if #pool == 0 then break end
		local pick = draw(#pool)
		if type(pick) ~= "number" or pick < 1 or pick > #pool then pick = 1 end
		pick = math.floor(pick)
		slots[i] = pool[pick].id
		table.remove(pool, pick)
	end
	return slots
end

-- WORK ORDERS (Phase 4c) -- the daily quests go LIVE at the verdict.
--
-- Economy: one completed quest pays QuestXp XP and ONE crate-key fragment;
-- FRAGMENTS_PER_KEY fragments roll into a key. The roll-up loop lives in the
-- CALLER (Profiles.recordSession), because the crates wallet is profile
-- state, not quest state -- this file only prices the quest itself.
ProgressionRules.QuestXp = 100
ProgressionRules.FRAGMENTS_PER_KEY = 5

function ProgressionRules.questById(id)
	for _, quest in ipairs(ProgressionRules.QuestPool) do
		if quest.id == id then return quest end
	end
	return nil
end

-- The metric snapshot ONE verdict contributes -- the bridge from a
-- recordSession summary to the QuestPool metrics. `summary` is the same
-- receipt-shaped table sessionXp reads ({ viable, roundsPlayed, trialsWon });
-- `trialWinsById` is the session's per-trial win set ({ [trialId] = true },
-- stashed by Profiles.recordTrial). Every metric the pool can name is present
-- -- the trialwin_* keys default to 0 -- so applyQuests never reads a hole
-- for a shipped quest.
function ProgressionRules.sessionMetrics(summary, trialWinsById)
	if type(summary) ~= "table" then summary = {} end
	local metrics = {
		roundsPlayed = tonumber(summary.roundsPlayed) or 0,
		sessions = 1,
		viable = summary.viable and 1 or 0,
		trialWins = tonumber(summary.trialsWon) or 0,
	}
	for _, id in ipairs(ProgressionRules.TRIAL_IDS) do
		metrics["trialwin_" .. id] = 0
	end
	if type(trialWinsById) == "table" then
		for id, won in pairs(trialWinsById) do
			if won and type(id) == "string" then
				metrics["trialwin_" .. id] = 1
			end
		end
	end
	return metrics
end

-- The quest state machine, one call per verdict. Mutates and returns the
-- profile's quests table ({ day, slots, progress, claimed }) plus the receipt
-- part { completed = {ids}, fragments, xp }. NO clock reads -- `day` is the
-- caller's dayStamp, the same one its streak tick consumed.
--
--   * quests.day ~= day -> re-roll (rollQuests(day)), progress zeroed,
--     claimed cleared. Unclaimed completed quests from yesterday are LOST --
--     daily discipline; the pool is sized so a session completes ~1 of 3.
--   * per slot: progress[i] moves by metrics[metric] (a missing metric adds
--     0), clamped at goal; reaching goal while not yet claimed[i] marks the
--     slot claimed and appends its id to `completed`. Claiming on the SAME
--     apply that reached the goal is what makes the payout idempotent: a
--     second apply the same day adds into the clamp and completes nothing.
--
-- AUTO-CLAIM (recorded decision): while the UI is dark there is no claim
-- flow, so completion IS the claim -- the caller pays XP and fragments
-- immediately and claimed[i] records "paid". A later UI claim flow replaces
-- this by leaving a completed slot unclaimed (progress at goal, claimed
-- false) and paying on the player's claim remote instead; the state shape
-- already carries both facts, so that change stays inside this function and
-- its caller.
--
-- progress[] and claimed[] are kept DENSE (real 0/false entries, never nil
-- holes): a sparse Lua array JSON-encodes as an object and comes back from
-- the DataStore with string keys. A slot whose id has left the pool is
-- skipped untouched (forward compat with a shrunk pool).
function ProgressionRules.applyQuests(quests, day, metrics)
	if type(quests) ~= "table" then
		quests = { day = 0, slots = {}, progress = {}, claimed = {} }
	end
	day = tonumber(day) or 0
	if type(metrics) ~= "table" then metrics = {} end
	if (tonumber(quests.day) or 0) ~= day then
		quests.day = day
		quests.slots = ProgressionRules.rollQuests(day)
		quests.progress = {}
		quests.claimed = {}
		for i = 1, #quests.slots do
			quests.progress[i] = 0
			quests.claimed[i] = false
		end
	end
	if type(quests.slots) ~= "table" then quests.slots = {} end
	if type(quests.progress) ~= "table" then quests.progress = {} end
	if type(quests.claimed) ~= "table" then quests.claimed = {} end
	local completed = {}
	for i, id in ipairs(quests.slots) do
		local quest = ProgressionRules.questById(id)
		if quest then
			local total = (tonumber(quests.progress[i]) or 0) + (tonumber(metrics[quest.metric]) or 0)
			if total > quest.goal then total = quest.goal end
			quests.progress[i] = total
			if total >= quest.goal and quests.claimed[i] ~= true then
				quests.claimed[i] = true
				table.insert(completed, id)
			else
				quests.claimed[i] = quests.claimed[i] == true
			end
		end
	end
	return quests, {
		completed = completed,
		fragments = #completed * 1, -- one fragment per completed quest
		xp = #completed * ProgressionRules.QuestXp,
	}
end

return ProgressionRules
