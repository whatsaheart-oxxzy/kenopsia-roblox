--!nonstrict
-- PROFILES (Phase 4a) -- the retention foundation. SHIPS DARK.
--
-- Volatile-first persistence: every player gets an in-memory profile the
-- moment they are seen (ProgressionRules.defaultProfile()), and PLAY only
-- ever touches that table -- synchronously, never yielding, never blocking
-- seat(), the match loop or the verdict. The DataStore is best-effort
-- background traffic behind it:
--   * load on join: UpdateAsync with a {jobId, ts} session lock (a lock
--     older than LOCK_STALE_SECONDS is stealable), LOAD_ATTEMPTS tries with
--     backoff; when every try fails the player simply stays VOLATILE --
--     fully playable, nothing ever written. In Studio without API access
--     this is the expected path (one warn, the Telemetry pattern, then
--     silence).
--   * writes at EXACTLY three moments: the session verdict (MachineFlow
--     calls recordSession + flush after scoresCommitted), PlayerRemoving,
--     and BindToClose -- the codebase's first, added here. UpdateAsync only;
--     merge discipline: write OUR fields (OWNED_FIELDS), preserve anything a
--     future schema added, never Set over the stored value.
--   * schemaVersion = 1 with a migrate-on-load chain: v0/nil fills missing
--     keys from the defaults, key by key, unknown keys pass through.
--
-- Every rule -- defaults, XP, clearance bands, the streak shield, quests --
-- lives in Shared/Rules/ProgressionRules (pure; tests/progression.lua).
-- This file is only the traffic and the timing. Every DataStore call is
-- pcall-wrapped; a dirty profile that never flushes is lost by design.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionRules = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("ProgressionRules"))
local Telemetry = require(script.Parent.Telemetry)

local STORE_NAME = "KenopsiaProfile_v1"
local KEY_FORMAT = "u_%d"
local LOCK_STALE_SECONDS = 180
local LOAD_ATTEMPTS = 3
local LOAD_BACKOFF = { 2, 5 } -- seconds before attempts 2 and 3
local CLOSE_FLUSH_SECONDS = 25 -- BindToClose budget (the engine grants 30)
local FUNNEL = "KenopsiaRetention"
-- The boot watchdog holds joiners out for 7 s while the content warning
-- plays; a greeting fired under it would be spent on a black screen.
local GREETING_DELAY = 8

local Profiles = {}

local started = false
local warned = {}
local store = nil -- nil = no persistence this server, everyone volatile
local live = {} -- [userId] = { userId, data, volatile, dirty, joinedClock }
local machineState = nil

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[Profiles] " .. msg)
end

local function today()
	return math.floor(os.time() / 86400)
end

-- MIGRATION -------------------------------------------------------------------
-- Fill only what is MISSING: unknown keys (a future schema's fields) pass
-- through untouched, and schemaVersion never moves backwards -- a value a
-- newer server stamped stays stamped.
local function fillMissing(target, defaults)
	for k, v in pairs(defaults) do
		if target[k] == nil then
			target[k] = v
		elseif type(v) == "table" and type(target[k]) == "table" then
			fillMissing(target[k], v)
		end
	end
end

local function migrate(data)
	if type(data) ~= "table" then data = {} end
	-- v0/nil -> v1: the whole chain today. New versions append steps here.
	fillMissing(data, ProgressionRules.defaultProfile())
	data.schemaVersion = math.max(tonumber(data.schemaVersion) or 0, 1)
	return data
end

-- The merge writes exactly these keys from the live copy; everything else in
-- the stored value (including `_lock`, handled separately) is preserved.
local OWNED_FIELDS = {
	"schemaVersion", "firstSeen", "lastSeen", "sessions", "roundsPlayed",
	"viableCount", "rejectedCount", "bestBand", "trialStats", "streak",
	"xp", "clearance", "quests", "emotes", "crates", "settings", "analytics",
}

-- DATASTORE TRAFFIC -----------------------------------------------------------
local function lockHeldByOther(stored, now)
	local lock = type(stored) == "table" and stored._lock or nil
	if type(lock) ~= "table" then return false end
	if lock.jobId == game.JobId then return false end
	return (now - (tonumber(lock.ts) or 0)) <= LOCK_STALE_SECONDS
end

-- One UpdateAsync: read, migrate, take the lock, hand the table out.
local function tryLoad(userId)
	local captured, blocked = nil, false
	local ok, err = pcall(function()
		store:UpdateAsync(KEY_FORMAT:format(userId), function(stored)
			local now = os.time()
			if lockHeldByOther(stored, now) then
				blocked = true
				return nil -- cancel the write, keep the other server's lock
			end
			blocked = false
			local data = migrate(stored)
			data._lock = { jobId = game.JobId, ts = now }
			captured = data
			return data
		end)
	end)
	if not ok then return nil, tostring(err) end
	if blocked then return nil, "locked by another server" end
	return captured, nil
end

-- Merge-write the live copy. release=true also hands the lock back.
local function trySave(entry, release)
	local data = entry.data
	local ok, err = pcall(function()
		store:UpdateAsync(KEY_FORMAT:format(entry.userId), function(stored)
			if type(stored) ~= "table" then stored = {} end
			for _, k in ipairs(OWNED_FIELDS) do
				stored[k] = data[k]
			end
			if release then
				stored._lock = nil
			else
				stored._lock = { jobId = game.JobId, ts = os.time() }
			end
			return stored
		end)
	end)
	if ok then entry.dirty = false end
	return ok, err
end

-- PACKETS / ATTRIBUTES --------------------------------------------------------
-- MachineFlow.start creates MachineState AFTER Profiles.start (Main boot
-- order), so this waits -- only ever called from a spawned loader thread.
local function getRemote()
	if machineState then return machineState end
	local ok, remote = pcall(function()
		local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
		return folder:WaitForChild("MachineState", 30)
	end)
	if ok and remote then machineState = remote end
	return machineState
end

local function setAttributes(plr, entry)
	-- Fresh Kenopsia* names -- the Phase 4a attribute census shows neither in
	-- use anywhere. Podium/lobby dressing reads these in a later phase.
	pcall(function()
		plr:SetAttribute("KenopsiaClearance", entry.data.clearance)
		plr:SetAttribute("KenopsiaStreak", entry.data.streak.current)
	end)
end

-- The UI contract, dark until a later phase renders it: an unknown kind
-- renders NOTHING on the client (MachineFlow's documented dispatch).
local function sendState(plr, entry)
	local remote = getRemote()
	if not remote or plr.Parent ~= Players then return end
	local data = entry.data
	pcall(remote.FireClient, remote, plr, {
		kind = "profilestate",
		xp = data.xp,
		clearance = data.clearance,
		streak = data.streak.current,
		sessions = data.sessions,
		viable = data.viableCount,
		volatile = entry.volatile,
	})
end

-- Phase 4a greeting decision: fixed-format text, sent straight from here on
-- the existing `announce` kind -- NOT a new MachineVoice category.
-- MachineVoice.pick's placeholder contract is {name, dir} at every call site;
-- the greeting needs NUMBERS, and widening the pool contract (plus
-- tests/voice.lua) is not a ships-dark change. `announce` is already used
-- per-player (Minefield, BirdHunting); the one hard rule is NON-EMPTY text --
-- an empty announce is an opaque black cover. Both formats below always
-- carry text. Returning subjects only; a volatile load stays silent.
local function sendGreeting(plr, entry)
	if entry.volatile then return end
	local data = entry.data
	if (data.sessions or 0) < 1 then return end
	local remote = getRemote()
	if not remote or plr.Parent ~= Players then return end
	local text
	local streak = data.streak
	if (streak.current or 0) >= 2 and (today() - (streak.lastDayStamp or 0)) <= 1 then
		text = ("NIGHT %d CONSECUTIVE. NOTED_"):format(streak.current)
	else
		text = ("SHIFT %d. WELCOME BACK_"):format((data.sessions or 0) + 1)
	end
	pcall(remote.FireClient, remote, plr, { kind = "announce", text = text, seconds = 4 })
end

-- JOIN / LEAVE ----------------------------------------------------------------
local function onPlayer(plr)
	local userId = plr.UserId
	if live[userId] then return end
	-- Volatile seed FIRST: play reads this table synchronously from the very
	-- first frame; the DataStore only ever upgrades it in the background.
	local entry = {
		userId = userId,
		data = ProgressionRules.defaultProfile(),
		volatile = true,
		dirty = false,
		joinedClock = os.clock(),
	}
	live[userId] = entry

	task.spawn(function()
		if store then
			for attempt = 1, LOAD_ATTEMPTS do
				local data, err = tryLoad(userId)
				if data then
					if live[userId] ~= entry or plr.Parent ~= Players then
						-- Left while we were loading: hand the lock straight
						-- back (with lastSeen) and forget the entry.
						entry.data = data
						entry.volatile = false
						entry.data.lastSeen = os.time()
						trySave(entry, true)
						return
					end
					local now = os.time()
					if (tonumber(data.firstSeen) or 0) == 0 then data.firstSeen = now end
					data.lastSeen = now
					entry.data = data
					entry.volatile = false
					entry.dirty = true -- firstSeen/lastSeen moved; verdict or leave flushes
					break
				end
				warnOnce("load", "load failed (expected in Studio without API access): " .. tostring(err))
				if attempt < LOAD_ATTEMPTS then
					task.wait(LOAD_BACKOFF[attempt] or 5)
					if live[userId] ~= entry or plr.Parent ~= Players then return end
				end
			end
		else
			warnOnce("store", "no DataStore - all profiles volatile this server")
		end
		if live[userId] ~= entry or plr.Parent ~= Players then return end

		setAttributes(plr, entry)
		Telemetry.funnel(plr, FUNNEL, 1, "Joined")
		sendState(plr, entry)

		local elapsed = os.clock() - entry.joinedClock
		if elapsed < GREETING_DELAY then task.wait(GREETING_DELAY - elapsed) end
		if live[userId] == entry and plr.Parent == Players then
			sendGreeting(plr, entry)
		end
	end)
end

-- NOT RoomService's PlayerRemoving (membership-critical) -- Profiles owns its
-- own connection, the Telemetry pattern.
local function onLeave(plr)
	local entry = live[plr.UserId]
	live[plr.UserId] = nil
	if not entry or entry.volatile or not store then return end
	entry.data.lastSeen = os.time()
	local ok, err = trySave(entry, true) -- write + hand the lock back
	if not ok then
		warnOnce("save", "leave flush failed (expected in Studio): " .. tostring(err))
	end
end

-- API -------------------------------------------------------------------------
function Profiles.get(userId)
	local entry = live[userId]
	return entry and entry.data or nil
end

function Profiles.isVolatile(userId)
	local entry = live[userId]
	if not entry then return true end
	return entry.volatile and true or false
end

-- The verdict record. summary = { viable, band, roundsPlayed, roundsWon?,
-- trialsWon? }; band is the shared final-board place (1 = top, ties share).
-- dailyFirst is computed HERE, off the streak tick: the day moved = the first
-- verdict of that day. Never yields, never throws past its own pcalls.
function Profiles.recordSession(userId, summary)
	local entry = live[userId]
	if not entry then return end
	if type(summary) ~= "table" then summary = {} end
	local data = entry.data
	local now = os.time()

	data.sessions = (data.sessions or 0) + 1
	data.roundsPlayed = (data.roundsPlayed or 0) + (tonumber(summary.roundsPlayed) or 0)
	if summary.viable then
		data.viableCount = (data.viableCount or 0) + 1
	else
		data.rejectedCount = (data.rejectedCount or 0) + 1
	end
	local band = tonumber(summary.band)
	if band and band >= 1 and ((data.bestBand or 0) == 0 or band < data.bestBand) then
		data.bestBand = band
	end

	local day = math.floor(now / 86400)
	local prevDay = type(data.streak) == "table" and data.streak.lastDayStamp or 0
	-- Reassign: tickStreak replaces a corrupted non-table streak with a fresh
	-- one, and that replacement only takes effect if we keep the return.
	data.streak = ProgressionRules.tickStreak(data.streak, day)
	local dailyFirst = data.streak.lastDayStamp ~= prevDay
	if (data.analytics.d1Stamp or 0) == 0 then data.analytics.d1Stamp = day end

	data.xp = (data.xp or 0) + ProgressionRules.sessionXp({
		viable = summary.viable and true or false,
		roundsPlayed = summary.roundsPlayed,
		roundsWon = summary.roundsWon,
		trialsWon = summary.trialsWon,
		dailyFirst = dailyFirst,
	})
	data.clearance = ProgressionRules.clearanceFor(data.xp)
	data.lastSeen = now
	entry.dirty = true

	local plr = Players:GetPlayerByUserId(userId)
	if plr then setAttributes(plr, entry) end
end

-- Per-trial lifetime stats. `won` should come from the trial board's
-- tie-aware place (place == 1), not from the voice's sole-top counter.
function Profiles.recordTrial(userId, trialId, won, rawBest)
	local entry = live[userId]
	if not entry or type(trialId) ~= "string" then return end
	local stats = entry.data.trialStats[trialId]
	if not stats then
		stats = { plays = 0, wins = 0, best = 0 }
		entry.data.trialStats[trialId] = stats -- a new trial id records itself
	end
	stats.plays = (stats.plays or 0) + 1
	if won then stats.wins = (stats.wins or 0) + 1 end
	local raw = tonumber(rawBest)
	if raw and raw > (stats.best or 0) then stats.best = raw end
	entry.dirty = true
end

-- The verdict write. Fire-and-forget: the save runs on its own thread so the
-- FinalScore presentation hold is never gated on DataStore latency. A failed
-- flush stays dirty; PlayerRemoving / BindToClose retry it.
function Profiles.flush(userId)
	local entry = live[userId]
	if not entry or entry.volatile or not entry.dirty or not store then return false end
	task.spawn(function()
		if live[entry.userId] ~= entry then return end -- left meanwhile; onLeave owns the final write
		local ok, err = trySave(entry, false)
		if not ok then
			warnOnce("save", "flush failed (expected in Studio): " .. tostring(err))
		end
	end)
	return true
end

-- Dormant Phase 5 socket: ownership only -- no packet, no UI, no unlock flow.
function Profiles.grantEmote(userId, emoteId)
	local entry = live[userId]
	if not entry or type(emoteId) ~= "string" then return end
	entry.data.emotes.owned[emoteId] = true
	entry.dirty = true
end

-- BOOT ------------------------------------------------------------------------
function Profiles.start()
	if started then return end
	started = true

	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warnOnce("store", "GetDataStore failed - all profiles volatile this server: " .. tostring(result))
	end

	-- The CharacterService hook pattern: players who beat start() to the
	-- server are swept first, then the connection takes over.
	for _, plr in Players:GetPlayers() do
		onPlayer(plr)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(plr)
		pcall(onLeave, plr)
	end)

	-- The codebase's first BindToClose (Phase 4a grep: zero anywhere else).
	-- Flush every loaded profile in parallel with a bounded wait; a volatile
	-- server (Studio without API) passes through instantly.
	game:BindToClose(function()
		if not store then return end
		local waiting = 0
		for _, entry in pairs(live) do
			if not entry.volatile then
				waiting += 1
				task.spawn(function()
					entry.data.lastSeen = os.time()
					pcall(trySave, entry, true)
					waiting -= 1
				end)
			end
		end
		local deadline = os.clock() + CLOSE_FLUSH_SECONDS
		while waiting > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	print("[Profiles] online - " .. (store and "store connected" or "VOLATILE (no DataStore)"))
end

return Profiles
