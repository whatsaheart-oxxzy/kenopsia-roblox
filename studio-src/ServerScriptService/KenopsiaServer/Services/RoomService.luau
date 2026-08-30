--!nonstrict
-- CANONICAL ROOM (Phase 1).
--
-- One server hosts exactly one room for 2-4 players. The old multi-room
-- lobby is retired; the create/join/quick remotes survive only as shims that
-- resolve every caller to this room, so existing clients keep working.
--
-- Lifecycle owned here:
--   Waiting -> Starting -> Playing -> Waiting
--   Playing -> Aborting -> Cleanup -> Waiting        (fatal membership/trial)
--
-- MachineFlow owns what happens *inside* Playing (Selecting/Briefing/Trial/
-- Score). It observes cancellation through room.phase and room.sessionId.
--
-- Deliberately preserved for Phase 1: `room.members` keeps its
-- { userId, displayName, ready } shape and `room.phase == "Playing"` keeps its
-- meaning, because BirdHunting and Minefield read both and must not change
-- behaviour during this architecture phase. Late joiners are therefore held in
-- `spectators`, never appended to `members` mid-match.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local RoomService = {}

local runRequested = Instance.new("BindableEvent")
RoomService.RunRequested = runRequested.Event

local ROOM_ID = 1

-- The one room. Never destroyed; it is reset back to Waiting instead.
local room = {
	id = ROOM_ID,
	phase = "Waiting",
	countdown = nil,
	token = 0,
	sessionId = nil,
	-- C4: observable sub-phase. nil whenever the room is idle; "Selecting" is
	-- written by the lobby pre-flow while Waiting, the rest by MachineFlow while
	-- Playing. Never assigned directly outside the two setters below.
	stage = nil,         -- nil | "Selecting" | "Briefing" | "Trial" | "Score" | "FinalScore"
	members = {},        -- ordered: { userId, displayName, ready }
	spectators = {},     -- [userId] = true; joined during a match
	participants = nil,  -- snapshot: { [userId] = true } taken at match start
	requiredMinimum = nil,
	aborting = false,

	-- Gate 1: observable session progress. All nil while idle, all written ONLY
	-- through setProgress, and all cleared by toWaiting -- otherwise the lobby
	-- would keep rendering the progress of a match that has already ended.
	--
	-- legIndex/legCount stay nil for trials that have no legs. Bird Hunting is
	-- the only one that does, and a stale leg number left over from it is exactly
	-- the kind of residue that makes the next trial's HUD lie.
	activeTrialId = nil,
	trialIndex = nil,
	trialCount = nil,
	roundIndex = nil,
	roundCount = nil,
	legIndex = nil,
	legCount = nil,
	-- Server clock instant at which the current stage ends, so a client can draw
	-- its own countdown without the server ticking one down over the wire.
	stageEndsAt = nil,
}

local Remotes
local nextSession = 0

-- rate limiting -------------------------------------------------------------
local buckets = {}
local function allow(player, key, perSecond)
	local now = os.clock()
	local id = player.UserId .. ":" .. key
	local b = buckets[id]
	if not b or now - b.stamp >= 1 then
		buckets[id] = { stamp = now, count = 1 }
		return true
	end
	if b.count >= perSecond then return false end
	b.count += 1
	return true
end

local function fail(player, message)
	if Remotes and Remotes.LobbyError then
		Remotes.LobbyError:FireClient(player, message)
	end
end

local function minPlayers()
	if RunService:IsStudio() then
		return Config.Players.StudioTestMinimum
	end
	return Config.Room.MinPlayers
end

-- state broadcast -----------------------------------------------------------
local function publicState()
	local members = {}
	for _, m in room.members do
		table.insert(members, { userId = m.userId, displayName = m.displayName, ready = m.ready })
	end
	local spectators = {}
	for userId in pairs(room.spectators) do
		table.insert(spectators, userId)
	end
	return {
		-- No code is issued in the canonical model; kept for client compat.
		code = "",
		isPublic = true,
		hostUserId = room.members[1] and room.members[1].userId or nil,
		phase = room.phase,
		stage = room.stage,
		countdown = room.countdown,
		maxPlayers = Config.Room.MaxPlayers,
		members = members,
		spectators = spectators,

		-- Gate 1 session progress. Sent on every broadcast so a late joiner and a
		-- reconnecting client both land on the correct screen without asking.
		activeTrialId = room.activeTrialId,
		trialIndex = room.trialIndex,
		trialCount = room.trialCount,
		roundIndex = room.roundIndex,
		roundCount = room.roundCount,
		legIndex = room.legIndex,
		legCount = room.legCount,
		stageEndsAt = room.stageEndsAt,
	}
end

-- Everyone on the server sees room state, including spectators, so a late
-- joiner's UI can show "next match" rather than an empty lobby.
local function broadcast()
	if not (Remotes and Remotes.RoomState) then return end
	local state = publicState()
	for _, plr in Players:GetPlayers() do
		Remotes.RoomState:FireClient(plr, state)
	end
end

-- membership ----------------------------------------------------------------
local function memberIndex(userId)
	for i, m in room.members do
		if m.userId == userId then return i end
	end
	return nil
end

function RoomService.isParticipant(_room, userId)
	if not room.participants then return memberIndex(userId) ~= nil end
	return room.participants[userId] == true
end

-- The captured audience for a match: participants who are still connected.
-- Spectators are deliberately excluded so trial effects stay scoped.
function RoomService.audience(_room)
	local out = {}
	for _, m in room.members do
		local plr = Players:GetPlayerByUserId(m.userId)
		if plr then table.insert(out, plr) end
	end
	return out
end

local function addMember(player)
	if memberIndex(player.UserId) then return end
	if #room.members >= Config.Room.MaxPlayers then return end
	table.insert(room.members, {
		userId = player.UserId,
		displayName = player.DisplayName,
		ready = false,
	})
	room.spectators[player.UserId] = nil
end

local function addSpectator(player)
	room.spectators[player.UserId] = true
end

-- Promote everyone waiting on the bench. Called only on the way back into
-- Waiting, so a late joiner can never enter a match already in progress.
local function promoteSpectators()
	for userId in pairs(room.spectators) do
		local plr = Players:GetPlayerByUserId(userId)
		if plr and #room.members < Config.Room.MaxPlayers then
			addMember(plr)
		end
	end
	room.spectators = {}
end

local function clearReady()
	for _, m in room.members do m.ready = false end
end

-- lifecycle -----------------------------------------------------------------
local function toWaiting()
	room.phase = "Waiting"
	room.countdown = nil
	room.stage = nil
	room.sessionId = nil
	room.participants = nil
	room.requiredMinimum = nil
	room.aborting = false
	-- Progress belongs to the match that just ended. Leaving any of it set makes
	-- the lobby show a trial index or a round counter for a session that no
	-- longer exists.
	room.activeTrialId = nil
	room.trialIndex = nil
	room.trialCount = nil
	room.roundIndex = nil
	room.roundCount = nil
	room.legIndex = nil
	room.legCount = nil
	room.stageEndsAt = nil
	room.token += 1
	promoteSpectators()
	clearReady()
	broadcast()
end

-- Idempotent: safe to call from a finally-style path and again from the
-- watchdog. Only the first call does work.
local function cleanupToWaiting(reason)
	if room.phase == "Waiting" then return end
	room.phase = "Cleanup"
	broadcast()
	if reason then
		print(("[RoomService] cleanup (%s)"):format(reason))
	end
	toWaiting()
end
RoomService.cleanupToWaiting = cleanupToWaiting

local function abortMatch(reason)
	if room.phase ~= "Playing" and room.phase ~= "Starting" then return false end
	if room.aborting then return false end
	room.aborting = true
	room.phase = "Aborting"
	room.token += 1
	broadcast()
	warn(("[RoomService] aborting match: %s"):format(tostring(reason)))
	for _, plr in Players:GetPlayers() do
		fail(plr, "RUN ABORTED - " .. string.upper(tostring(reason)))
	end
	return true
end
RoomService.abort = function(_room, reason) return abortMatch(reason) end

local function allReady()
	if #room.members == 0 then return false end
	for _, m in room.members do
		if not m.ready then return false end
	end
	return true
end

local function abortCountdown(reason)
	if room.phase ~= "Starting" then return end
	room.token += 1
	room.phase = "Waiting"
	room.countdown = nil
	if reason then
		for _, m in room.members do
			local plr = Players:GetPlayerByUserId(m.userId)
			if plr then fail(plr, reason) end
		end
	end
	broadcast()
end

local function beginCountdown()
	if room.phase ~= "Waiting" then return end
	room.phase = "Starting"
	room.token += 1
	local token = room.token
	broadcast()
	task.spawn(function()
		for n = Config.Match.StartCountdown, 1, -1 do
			if room.token ~= token or room.phase ~= "Starting" then return end
			room.countdown = n
			broadcast()
			task.wait(1)
		end
		if room.token ~= token or room.phase ~= "Starting" then return end
		if #room.members < minPlayers() then
			abortCountdown("NOT ENOUGH PARTICIPANTS")
			return
		end

		-- Snapshot: this membership and this minimum define the match.
		nextSession += 1
		room.sessionId = ("S%d-%d"):format(nextSession, math.floor(os.clock() * 1000) % 100000)
		room.participants = {}
		for _, m in room.members do room.participants[m.userId] = true end
		room.requiredMinimum = math.min(#room.members, minPlayers())

		room.countdown = nil
		room.phase = "Playing"
		broadcast()
		-- Fire the id, not the table: BindableEvents deep-copy table arguments,
		-- and downstream systems must operate on the live room, not a snapshot.
		runRequested:Fire(room.id)
	end)
end

local function maybeAutoStart()
	if not Config.Room.RequireAllReady then return end
	if room.phase ~= "Waiting" then return end
	if #room.members < minPlayers() then return end
	if not allReady() then return end
	beginCountdown()
end

-- A participant left. During a match this may be fatal.
local function removeMember(userId)
	local i = memberIndex(userId)
	if i then table.remove(room.members, i) end
	room.spectators[userId] = nil

	if room.phase == "Starting" then
		abortCountdown("PARTICIPANT LOST - COUNTDOWN ABORTED")
		return
	end

	if room.phase == "Playing" then
		local remaining = 0
		for _, m in room.members do
			if RoomService.isParticipant(room, m.userId) then remaining += 1 end
		end
		if remaining < (room.requiredMinimum or minPlayers()) then
			-- 30.08.2026 (user): Klartext statt "MEMBERSHIP BELOW MINIMUM".
			-- Der Client rendert "RUN ABORTED - <reason>" als LobbyError-
			-- Karte; die Bedingung darueber feuert genau dann, wenn nur noch
			-- EIN Teilnehmer uebrig ist (requiredMinimum ist 2 im Betrieb).
			abortMatch("PLAYER LEFT - CANNOT CONTINUE WITH A SINGLE PLAYER")
			return
		end
	end

	broadcast()
end

local function setReady(player, ready)
	-- Server-authoritative: only a seated participant may hold a ready flag,
	-- and only while the room is actually accepting readiness.
	local i = memberIndex(player.UserId)
	if not i then
		fail(player, "SPECTATING - NEXT MATCH")
		return
	end
	if room.phase ~= "Waiting" and room.phase ~= "Starting" then
		fail(player, "RUN IN PROGRESS")
		return
	end
	room.members[i].ready = (ready == true)
	-- 24.08.2026: BACK TO MENU on the end card un-readies BEFORE the carried
	-- rematch re-arms; drop the player from the pending rematch set so the
	-- re-arm respects the choice.
	local rematch = (room :: any).rematch
	if ready ~= true and rematch and rematch.userIds then
		rematch.userIds[player.UserId] = nil
	end
	if room.phase == "Starting" and ready ~= true then
		abortCountdown("READY REVOKED - COUNTDOWN ABORTED")
		return
	end
	broadcast()
	maybeAutoStart()
end

-- P1.7 rematch (22.08.2026): re-arm readiness for the members named in `userIds`
-- (the last verdict's subjects) once the lobby is showing again. Anyone who
-- left is simply not a member any more; anyone who stays can still un-ready.
function RoomService.carryReady(userIds)
	if room.phase ~= "Waiting" then return end
	local armed = 0
	for _, m in room.members do
		if userIds[m.userId] then
			m.ready = true
			armed += 1
		end
	end
	if armed == 0 then return end
	print(("[RoomService] rematch: %d subject(s) re-armed"):format(armed))
	broadcast()
	maybeAutoStart()
end

-- seating -------------------------------------------------------------------
-- The only way in. During a match you land on the bench.
local function seat(player)
	if memberIndex(player.UserId) then
		broadcast()
		return
	end
	if room.phase == "Waiting" and #room.members < Config.Room.MaxPlayers then
		addMember(player)
	else
		addSpectator(player)
	end
	broadcast()
end

function RoomService.autoSeat(player)
	seat(player)
end

function RoomService.roomOf(player)
	if memberIndex(player.UserId) then return room end
	if room.spectators[player.UserId] then return room end
	return nil
end

-- perf (22.08.2026): lets the boot watchdog skip seat() -- and its full
-- RoomState broadcast -- for everyone who already holds a seat.
function RoomService.isMember(player)
	return memberIndex(player.UserId) ~= nil
end

function RoomService.getRoom(id)
	if id == ROOM_ID then return room end
	return nil
end

function RoomService.canonical()
	return room
end

function RoomService.waitingRooms()
	if room.phase == "Waiting" then return { room } end
	return {}
end

-- Cancellation predicate handed to trials/MachineFlow.
function RoomService.cancelled(sessionId)
	return room.phase ~= "Playing" or room.sessionId ~= sessionId
end

-- C4: stage writes -----------------------------------------------------------
-- Two setters, one per owning phase. They can never both accept a write: each
-- demands a phase the other rejects, and the room has exactly one phase. Inside
-- a setter the guard and the write happen in the same resumption with no yield
-- between them, so a stale caller is REJECTED rather than delayed - there is no
-- window in which its write lands after its guard passed.
-- "Selecting" appears in BOTH tables from Gate 1 on, and the two setters still
-- cannot both accept a write: setStage demands Playing, setWaitingStage demands
-- Waiting, and the room has exactly one phase.
--
-- It is an in-match stage now because the session reveals each of its trials in
-- turn WITHOUT returning to the lobby. The lobby's own pre-flow roulette also
-- calls it "Selecting", which is correct -- it is the same thing shown at a
-- different moment, and the phase is what tells them apart.
local IN_MATCH_STAGES = { Selecting = true, Briefing = true, Trial = true, Score = true, FinalScore = true }

-- Playing-phase stages. The sessionId IS the token: this is the same test
-- cancelled() applies, so a thread left over from a dead session cannot write.
function RoomService.setStage(sessionId, stage)
	if not IN_MATCH_STAGES[stage] then return false end
	if room.phase ~= "Playing" then return false end
	if room.sessionId ~= sessionId then return false end
	if room.stage == stage then return true end
	room.stage = stage
	broadcast()
	return true
end

-- Waiting-phase stage. The lobby pre-flow runs before a session exists, so it
-- has no sessionId to present. room.token is the Waiting-phase epoch: it is
-- bumped by every lifecycle move, including Waiting -> Starting and back again,
-- so a pre-flow that yielded across a countdown fails this test exactly the way
-- a dead session fails setStage. "Selecting" is the only stage reachable here,
-- which keeps an in-match stage from ever being written from the lobby path.
function RoomService.setWaitingStage(token, stage)
	if stage ~= "Selecting" then return false end
	if room.phase ~= "Waiting" then return false end
	if room.token ~= token then return false end
	if room.stage == stage then return true end
	room.stage = stage
	broadcast()
	return true
end

-- Gate 1: session progress writes ---------------------------------------------
-- Same discipline as setStage above: the guard and the write happen in one
-- resumption with no yield between them, so a thread left over from a dead
-- session is REJECTED rather than delayed. The sessionId is the token.
--
-- Patch semantics, because no caller ever knows all eight fields at once -- the
-- trial index is set when a trial starts, the round index once per round, the
-- leg only inside Bird Hunting. A field the patch omits keeps its value.
--
-- Clearing therefore needs to be explicit, which is what CLEAR is for. Without
-- it, `legIndex = nil` in a patch is indistinguishable from "not mentioned", and
-- Bird Hunting's leg counter would survive into the next trial's HUD.
RoomService.CLEAR = newproxy(false)

local PROGRESS_FIELDS = {
	activeTrialId = "string",
	trialIndex = "number",
	trialCount = "number",
	roundIndex = "number",
	roundCount = "number",
	legIndex = "number",
	legCount = "number",
	stageEndsAt = "number",
}

function RoomService.setProgress(sessionId, patch)
	if type(patch) ~= "table" then return false end
	if room.phase ~= "Playing" then return false end
	if room.sessionId ~= sessionId then return false end

	-- Validate the WHOLE patch before writing any of it. A patch that is half
	-- applied and then rejected would leave the room describing a state that
	-- never existed, which is worse than rejecting it outright.
	for key, value in pairs(patch) do
		local expected = PROGRESS_FIELDS[key]
		if not expected then return false end
		if value ~= RoomService.CLEAR and type(value) ~= expected then return false end
	end

	local changed = false
	for key, value in pairs(patch) do
		-- NOT `(value == CLEAR) and nil or value`. That is the classic and/or
		-- trap: `and nil` is falsy, so the expression always falls through to
		-- `or value` and CLEAR would be WRITTEN INTO the field and broadcast to
		-- every client instead of clearing it. Caught by luau-lsp, not by a test.
		local newValue
		if value ~= RoomService.CLEAR then newValue = value end
		if room[key] ~= newValue then
			room[key] = newValue
			changed = true
		end
	end

	-- No broadcast when nothing moved: setProgress is called on every round of
	-- every trial, and re-sending an identical state to every player each time
	-- is pure wire traffic.
	if changed then broadcast() end
	return true
end

function RoomService.finishRun(_room)
	cleanupToWaiting("match complete")
end

-- remotes -------------------------------------------------------------------
local function ensureRemotes()
	local k = ReplicatedStorage:FindFirstChild("Kenopsia")
	if not k then
		k = Instance.new("Folder")
		k.Name = "Kenopsia"
		k.Parent = ReplicatedStorage
	end
	local folder = k:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = k
	end
	local names = {
		"RoomState", "LobbyError", "RoomCreateRequest", "RoomJoinRequest",
		"RoomQuickJoinRequest", "RoomLeaveRequest", "RoomReadyRequest", "RoomStartRequest",
	}
	Remotes = {}
	for _, n in names do
		local r = folder:FindFirstChild(n)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = folder
		end
		Remotes[n] = r
	end
end

function RoomService.start()
	ensureRemotes()

	-- Compatibility shims: every legacy room remote now resolves to the one
	-- canonical room instead of creating or switching rooms.
	local function shim(player)
		if not memberIndex(player.UserId) and not room.spectators[player.UserId] then
			seat(player)
		else
			broadcast()
		end
	end
	Remotes.RoomCreateRequest.OnServerEvent:Connect(function(player)
		if not allow(player, "create", 2) then return end
		shim(player)
	end)
	Remotes.RoomJoinRequest.OnServerEvent:Connect(function(player)
		if not allow(player, "join", 3) then return end
		shim(player)
	end)
	Remotes.RoomQuickJoinRequest.OnServerEvent:Connect(function(player)
		if not allow(player, "quick", 2) then return end
		shim(player)
	end)
	-- Leaving the canonical room is not supported: there is nowhere to go.
	-- The request is acknowledged with a fresh state so the UI stays honest.
	Remotes.RoomLeaveRequest.OnServerEvent:Connect(function(player)
		if not allow(player, "leave", 3) then return end
		broadcast()
	end)
	Remotes.RoomReadyRequest.OnServerEvent:Connect(function(player, ready)
		if not allow(player, "ready", 5) then return end
		setReady(player, ready)
	end)
	Remotes.RoomStartRequest.OnServerEvent:Connect(function(player)
		if not allow(player, "start", 2) then return end
		if not memberIndex(player.UserId) then
			fail(player, "SPECTATING - NEXT MATCH")
			return
		end
		if #room.members < minPlayers() then
			fail(player, "NOT ENOUGH PLAYERS")
			return
		end
		if Config.Room.RequireAllReady and not allReady() then
			fail(player, "ALL PLAYERS MUST BE READY")
			return
		end
		beginCountdown()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeMember(player.UserId)
		for _, key in { "create", "join", "quick", "leave", "ready", "start" } do
			buckets[player.UserId .. ":" .. key] = nil
		end
	end)

	print(("[RoomService] online - canonical room, %d-%d players%s")
		:format(Config.Room.MinPlayers, Config.Room.MaxPlayers,
			RunService:IsStudio() and " (studio)" or ""))
end

return RoomService
