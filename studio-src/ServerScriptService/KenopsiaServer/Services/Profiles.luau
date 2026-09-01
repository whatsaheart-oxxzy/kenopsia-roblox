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
--
-- Phase 5: the EMOTES block near the bottom stops being a one-function socket.
-- grantEmote keeps its signature and gains the corruption guard the crates
-- wallet already has; the wheel gets its writers (setEquipped / setEmoteSlot /
-- setWheel) and a reader. All memory-only, all on the same three flush moments.
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
local live = {} -- [userId] = { userId, data, volatile, dirty, joinedClock, pendingTrialWins? }
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
	local crates = type(data.crates) == "table" and data.crates or nil
	pcall(remote.FireClient, remote, plr, {
		kind = "profilestate",
		xp = data.xp,
		clearance = data.clearance,
		streak = data.streak.current,
		sessions = data.sessions,
		viable = data.viableCount,
		volatile = entry.volatile,
		-- Supply screens (01.09.2026): the crate wallet rides the same packet.
		-- Additive fields only -- a client from before them ignores unknown keys.
		keys = crates and tonumber(crates.keys) or 0,
		fragments = crates and tonumber(crates.fragments) or 0,
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
--
-- Phase 4b: returns the RECEIPT -- everything the SHIFT REPORT beat and the
-- badge rules need, computed from what this function already did. Returning a
-- value to callers that used to ignore one is backward-safe; a missing
-- profile returns nil, exactly where it used to return nothing.
--
-- Phase 4c: the WORK ORDER tick rides the same call. Quests re-roll/advance
-- via ProgressionRules.applyQuests on the SAME `day` the streak tick used;
-- completions AUTO-CLAIM (the recorded decision in applyQuests' header: while
-- the UI is dark, completion IS the claim) and pay QuestXp each plus one
-- crate-key fragment, fragments rolling into keys at FRAGMENTS_PER_KEY.
-- Quest XP is folded into xpDelta BEFORE the clearance recompute, so the
-- receipt's clearance includes it and xpTotal - xpDelta stays the
-- pre-verdict total. The receipt grows quests / questsCompleted / fragments /
-- keys.
function Profiles.recordSession(userId, summary)
	local entry = live[userId]
	if not entry then return nil end
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

	local xpDelta = ProgressionRules.sessionXp({
		viable = summary.viable and true or false,
		roundsPlayed = summary.roundsPlayed,
		roundsWon = summary.roundsWon,
		trialsWon = summary.trialsWon,
		dailyFirst = dailyFirst,
	})

	-- Phase 4c WORK ORDERS: the quest tick rides the verdict. `wins` is the
	-- session-scoped stash recordTrial filled (see its header) -- consumed
	-- HERE and cleared, so the next session starts empty. applyQuests
	-- re-rolls on a day change and auto-claims completions; the fragments
	-- roll into keys here because the crates wallet is profile state, not
	-- quest state.
	local wins = entry.pendingTrialWins or {}
	entry.pendingTrialWins = nil
	local quests, questResult = ProgressionRules.applyQuests(data.quests, day,
		ProgressionRules.sessionMetrics({
			viable = summary.viable and true or false,
			roundsPlayed = summary.roundsPlayed,
			trialsWon = summary.trialsWon,
		}, wins))
	data.quests = quests
	-- Wallet corruption discipline (the tickStreak / applyQuests pattern):
	-- migrate() only fills MISSING keys, so an externally corrupted non-table
	-- crates -- or a non-numeric counter -- would otherwise throw here on
	-- every verdict, and recordSession promises it never throws.
	--
	-- The same admission forces the roll-up to be ONE DIVISION, never a
	-- `while fragments >= perKey` loop: this function never yields, so a
	-- corrupted counter of 1e9 would not throw, it would SPIN -- freezing the
	-- verdict thread for the whole room, strictly worse than the throw the
	-- guards above prevent (and a bad perKey < 1 would never terminate at
	-- all). Division is O(1) and identical to the loop for every real value.
	-- The finite guards reject NaN/inf/negative for the same reason: they
	-- cannot round-trip a DataStore, so a poisoned counter would silently
	-- kill every future write for that player.
	if type(data.crates) ~= "table" then data.crates = { keys = 0, fragments = 0 } end
	local perKey = tonumber(ProgressionRules.FRAGMENTS_PER_KEY) or 0
	local fragments = (tonumber(data.crates.fragments) or 0) + questResult.fragments
	local keys = tonumber(data.crates.keys) or 0
	if not (fragments >= 0 and fragments < math.huge) then fragments = 0 end
	if not (keys >= 0 and keys < math.huge) then keys = 0 end
	if perKey >= 1 and fragments >= perKey then
		local earned = math.floor(fragments / perKey)
		fragments = fragments - earned * perKey
		keys = keys + earned
	end
	data.crates.fragments = fragments
	data.crates.keys = keys
	-- Quest XP joins the SAME clearance recompute below -- added to xpDelta
	-- BEFORE data.xp moves, so the receipt's clearance (and clearanceUp)
	-- already includes it, and xpTotal - xpDelta stays the pre-verdict total.
	xpDelta = xpDelta + questResult.xp

	local prevClearance = tonumber(data.clearance) or 1
	data.xp = (data.xp or 0) + xpDelta
	local clearance, clearanceName = ProgressionRules.clearanceFor(data.xp)
	data.clearance = clearance
	data.lastSeen = now
	entry.dirty = true

	local plr = Players:GetPlayerByUserId(userId)
	if plr then setAttributes(plr, entry) end

	return {
		xpDelta = xpDelta,
		xpTotal = data.xp,
		clearance = clearance,
		clearanceName = clearanceName, -- clearanceFor's second return
		clearanceUp = clearance > prevClearance, -- the band index rose THIS session
		streak = data.streak.current,
		sessions = data.sessions,
		viable = summary.viable and true or false,
		viableCount = data.viableCount, -- FIRST_VIABLE reads "== 1"
		bestBand = data.bestBand,
		dailyFirst = dailyFirst,
		-- Phase 4c: the post-apply quest state and the crate wallet. `quests`
		-- is a REFERENCE to the live profile table (read it before this
		-- player's next recordSession); questsCompleted is this verdict's own
		-- fresh list.
		quests = data.quests, -- { day, slots, progress, claimed }
		questsCompleted = questResult.completed,
		fragments = data.crates.fragments,
		keys = data.crates.keys,
		volatile = entry.volatile and true or false,
	}
end

-- Per-trial lifetime stats. `won` should come from the trial board's
-- tie-aware place (place == 1), not from the voice's sole-top counter.
--
-- Phase 4c COUPLING: a win is also stashed in entry.pendingTrialWins, the
-- session-scoped set the NEXT recordSession consumes AND clears for the WORK
-- ORDER trialwin_* metrics. MachineFlow's flow guarantees the order -- every
-- recordTrial of a session runs at its trial's board, before the verdict's
-- recordSession. A session that dies before its verdict leaves the stash for
-- this player's next verdict on this server; accepted (the wins were real),
-- and leaving drops it with the whole live entry.
function Profiles.recordTrial(userId, trialId, won, rawBest)
	local entry = live[userId]
	if not entry or type(trialId) ~= "string" then return end
	local stats = entry.data.trialStats[trialId]
	if not stats then
		stats = { plays = 0, wins = 0, best = 0 }
		entry.data.trialStats[trialId] = stats -- a new trial id records itself
	end
	stats.plays = (stats.plays or 0) + 1
	if won then
		stats.wins = (stats.wins or 0) + 1
		local pending = entry.pendingTrialWins
		if not pending then
			pending = {}
			entry.pendingTrialWins = pending
		end
		pending[trialId] = true
	end
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

-- EMOTES (Phase 5) --------------------------------------------------------------
-- Memory-only, like everything else in this file: each writer marks the entry
-- dirty and the same three flush moments (verdict / PlayerRemoving /
-- BindToClose) carry it to the store. `emotes` is already in OWNED_FIELDS, so
-- nothing about the merge changes.
--
-- The CATALOG is NOT here. Shared/Config/EmoteRegistry owns it and
-- Services/EmoteService checks a row against it before calling any of these --
-- a Shared/Config require from this module would buy nothing and add a boot
-- cycle for a rule the caller already enforces. Profiles enforces exactly ONE
-- rule, and it is the one that keeps a wheel honest:
--
--     YOU CANNOT EQUIP WHAT YOU DO NOT OWN.
--
-- (A "default" emote -- free for everyone -- is materialised into `owned` by
-- EmoteService the first time it is put on a wheel, so that rule stays absolute
-- without a second code path here. It is not an ownership shortcut: the PLAY
-- path asks the registry, never `owned`, for a default row.)
--
-- Corruption discipline, the crates pattern from recordSession: migrate() only
-- fills MISSING keys, so an externally corrupted non-table `emotes` -- or a
-- non-table owned/wheel, or a non-string equipped -- would throw on the first
-- grant of the session. Normalise ONCE, here, and every writer below is total.
local function emoteState(entry)
	local data = entry.data
	if type(data.emotes) ~= "table" then
		data.emotes = { owned = {}, equipped = "", wheel = {} }
	end
	local emotes = data.emotes
	if type(emotes.owned) ~= "table" then emotes.owned = {} end
	if type(emotes.wheel) ~= "table" then emotes.wheel = {} end
	if type(emotes.equipped) ~= "string" then emotes.equipped = "" end
	return emotes
end

-- The wheel is a DENSE 1..WHEEL_SLOTS array of strings ("" = empty slot). Dense
-- for the applyQuests reason: a sparse Lua array JSON-encodes as an OBJECT and
-- comes back from the DataStore with string keys, at which point ipairs sees
-- nothing and the wheel silently empties itself.
Profiles.WHEEL_SLOTS = 8

local function normaliseWheel(emotes)
	local wheel = emotes.wheel
	for i = 1, Profiles.WHEEL_SLOTS do
		if type(wheel[i]) ~= "string" then wheel[i] = "" end
	end
	-- Drop anything past the wheel: a shrunk WHEEL_SLOTS, or a value written by
	-- a future server with a wider wheel, must not travel back to the store.
	for i = #wheel, Profiles.WHEEL_SLOTS + 1, -1 do
		wheel[i] = nil
	end
	return wheel
end

-- Ownership. Phase 5 callers: EmoteService.grant (a gamepass purchase, a crate
-- open, a cross-place MessagingService nudge). HARD CONSTRAINT, unchanged since
-- the socket was written: this NO-OPS for a userId that is not on this server.
-- A grant for an offline player is LOST -- the durable write is the caller's
-- job, and KenopsiaProfile_v1 is the source of truth.
-- Returns TRUE only when this call actually added something. Additive: nothing
-- read the old nil return, and an idempotent answer is what lets the caller
-- skip a DataStore write for a grant that changes nothing (a repeated
-- cross-place nudge, a gamepass re-confirmed every OWNERSHIP_TTL).
function Profiles.grantEmote(userId, emoteId)
	local entry = live[userId]
	if not entry or type(emoteId) ~= "string" or emoteId == "" then return false end
	local owned = emoteState(entry).owned
	if owned[emoteId] == true then return false end
	owned[emoteId] = true
	entry.dirty = true
	return true
end

-- Read accessor. Returns the live sub-table BY REFERENCE (the Profiles.get
-- discipline) or nil for a player this server has not seen; callers READ it,
-- the writers here are the only ones that mutate it.
function Profiles.emotes(userId)
	local entry = live[userId]
	if not entry then return nil end
	return emoteState(entry)
end

-- The one-button emote. "" clears it. Returns false for an id that is not
-- owned, so a caller can tell a rejection from a no-op.
function Profiles.setEquipped(userId, emoteId)
	local entry = live[userId]
	if not entry or type(emoteId) ~= "string" then return false end
	local emotes = emoteState(entry)
	if emoteId ~= "" and emotes.owned[emoteId] ~= true then return false end
	if emotes.equipped == emoteId then return true end
	emotes.equipped = emoteId
	entry.dirty = true
	return true
end

-- One wheel slot. slot is 1..WHEEL_SLOTS; emoteId is an owned id, or "" / nil
-- to clear the slot.
function Profiles.setEmoteSlot(userId, slot, emoteId)
	local entry = live[userId]
	if not entry then return false end
	slot = tonumber(slot)
	if not slot or slot ~= math.floor(slot) or slot < 1 or slot > Profiles.WHEEL_SLOTS then return false end
	if emoteId == nil then emoteId = "" end
	if type(emoteId) ~= "string" then return false end
	local emotes = emoteState(entry)
	if emoteId ~= "" and emotes.owned[emoteId] ~= true then return false end
	local wheel = normaliseWheel(emotes)
	if wheel[slot] == emoteId then return true end
	wheel[slot] = emoteId
	entry.dirty = true
	return true
end

-- The whole wheel at once (a later UI's "save layout"). `list` is an array of
-- ids; anything missing, unowned or not a string becomes an empty slot rather
-- than a rejection -- a layout that names one emote the player has since lost
-- must still save the other seven.
function Profiles.setWheel(userId, list)
	local entry = live[userId]
	if not entry or type(list) ~= "table" then return false end
	local emotes = emoteState(entry)
	local wheel = {}
	for i = 1, Profiles.WHEEL_SLOTS do
		local id = list[i]
		if type(id) == "string" and id ~= "" and emotes.owned[id] == true then
			wheel[i] = id
		else
			wheel[i] = ""
		end
	end
	emotes.wheel = wheel
	entry.dirty = true
	return true
end

-- CRATES (supply screens, 01.09.2026) ------------------------------------------
-- The wallet's ONLY spender. Earning stays where it always was (recordSession's
-- fragment roll-up); this section adds the read and the decrement the crate
-- ceremony needs, with the same normalise-once discipline as emoteState above --
-- an externally corrupted crates table repairs itself on first touch instead of
-- throwing inside a remote handler.
local function crateWallet(entry)
	local data = entry.data
	if type(data.crates) ~= "table" then
		data.crates = { keys = 0, fragments = 0 }
	end
	local crates = data.crates
	local keys = tonumber(crates.keys) or 0
	if not (keys >= 0 and keys < math.huge) then keys = 0 end
	local fragments = tonumber(crates.fragments) or 0
	if not (fragments >= 0 and fragments < math.huge) then fragments = 0 end
	crates.keys = keys
	crates.fragments = fragments
	return crates
end

-- Plain numbers by value, or nil for a player this server has not seen -- the
-- caller renders these, it never writes them back.
function Profiles.wallet(userId)
	local entry = live[userId]
	if not entry then return nil end
	local crates = crateWallet(entry)
	return { keys = crates.keys, fragments = crates.fragments }
end

-- One key, or a clean false. Synchronous and yield-free by construction, so a
-- caller can check-then-spend in one event handler with no interleaving window.
-- The flush is the CALLER's job (CrateService pairs it with the grant so both
-- land in one UpdateAsync), the dirty mark is not.
function Profiles.spendCrateKey(userId)
	local entry = live[userId]
	if not entry then return false end
	local crates = crateWallet(entry)
	if crates.keys < 1 then return false end
	crates.keys = crates.keys - 1
	entry.dirty = true
	return true
end

-- The wallet's grant side (access codes, admin gifts). Whole non-negative
-- amounts only; fragments granted here roll into keys at the next verdict,
-- exactly like quest fragments do -- recordSession owns the roll-up.
function Profiles.grantCrate(userId, keys, fragments)
	local entry = live[userId]
	if not entry then return false end
	local crates = crateWallet(entry)
	crates.keys = crates.keys + math.max(0, math.floor(tonumber(keys) or 0))
	crates.fragments = crates.fragments + math.max(0, math.floor(tonumber(fragments) or 0))
	entry.dirty = true
	return true
end

-- Public re-send of profilestate, for a service that just changed what the
-- packet carries (a spent key, a fresh grant). No-op for a player who left.
function Profiles.pushState(userId)
	local entry = live[userId]
	if not entry then return end
	local plr = Players:GetPlayerByUserId(userId)
	if plr then sendState(plr, entry) end
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
