--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local RoomService = {}

local runRequested = Instance.new("BindableEvent")
RoomService.RunRequested = runRequested.Event

local rooms = {}
local byCode = {}
local byPlayer = {}
local nextRoomId = 0
local Remotes

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
	Remotes.LobbyError:FireClient(player, message)
end

local function minPlayers()
	if RunService:IsStudio() then
		return Config.Players.StudioTestMinimum
	end
	return Config.Room.MinPlayers
end

local function generateCode()
	local alphabet = Config.Room.CodeAlphabet
	for _ = 1, 64 do
		local chars = table.create(Config.Room.CodeLength)
		for i = 1, Config.Room.CodeLength do
			local n = math.random(#alphabet)
			chars[i] = string.sub(alphabet, n, n)
		end
		local code = table.concat(chars)
		if not byCode[code] then return code end
	end
	return nil
end

local function publicState(room)
	local members = {}
	for _, m in room.members do
		table.insert(members, { userId = m.userId, displayName = m.displayName, ready = m.ready })
	end
	return {
		code = room.code,
		isPublic = room.isPublic,
		hostUserId = room.hostUserId,
		phase = room.phase,
		countdown = room.countdown,
		maxPlayers = Config.Room.MaxPlayers,
		members = members,
	}
end

local function broadcast(room)
	local state = publicState(room)
	for _, m in room.members do
		local plr = Players:GetPlayerByUserId(m.userId)
		if plr then
			Remotes.RoomState:FireClient(plr, state)
		end
	end
end

local function destroyRoom(room)
	rooms[room.id] = nil
	byCode[room.code] = nil
end

local function abortCountdown(room, reason)
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
	broadcast(room)
end

local function beginCountdown(room)
	if room.phase ~= "Waiting" then return end
	room.phase = "Starting"
	room.token += 1
	local token = room.token
	task.spawn(function()
		for n = 5, 1, -1 do
			if room.token ~= token or room.phase ~= "Starting" then return end
			room.countdown = n
			broadcast(room)
			task.wait(1)
		end
		if room.token ~= token or room.phase ~= "Starting" then return end
		room.countdown = nil
		room.phase = "Playing"
		broadcast(room)
		-- Fire the id, not the table: BindableEvents deep-copy table arguments,
		-- and the playlist must operate on the live room, not a snapshot.
		runRequested:Fire(room.id)
	end)
end

local function allReady(room)
	for _, m in room.members do
		if not m.ready then return false end
	end
	return true
end

-- internal starters (practice runs) skip the ready gate
function RoomService.forceStart(room)
	beginCountdown(room)
end

local function maybeAutoStart(room)
	if Config.Room.RequireAllReady and room.phase == "Waiting"
		and #room.members >= minPlayers() and allReady(room) then
		beginCountdown(room)
	end
end

local function removeMember(room, userId)
	for i, m in room.members do
		if m.userId == userId then
			table.remove(room.members, i)
			break
		end
	end
	byPlayer[userId] = nil
	if #room.members == 0 then
		destroyRoom(room)
		return
	end
	if room.phase == "Starting" then
		abortCountdown(room, "PARTICIPANT LOST - COUNTDOWN ABORTED")
	end
	if room.hostUserId == userId then
		room.hostUserId = room.members[1].userId
	end
	broadcast(room)
end

local function leave(player)
	local room = byPlayer[player.UserId]
	if room then removeMember(room, player.UserId) end
end

local function addMember(room, player)
	table.insert(room.members, {
		userId = player.UserId,
		displayName = player.DisplayName,
		ready = false,
	})
	byPlayer[player.UserId] = room
	broadcast(room)
end

local function createRoom(player, isPublic)
	leave(player)
	local code = generateCode()
	if not code then
		fail(player, "NO CODES AVAILABLE - TRY AGAIN")
		return
	end
	nextRoomId += 1
	local room = {
		id = nextRoomId,
		code = code,
		isPublic = isPublic == true,
		hostUserId = player.UserId,
		phase = "Waiting",
		countdown = nil,
		members = {},
		token = 0,
	}
	rooms[room.id] = room
	byCode[code] = room
	addMember(room, player)
end

local function joinByCode(player, code)
	if type(code) ~= "string" then return end
	code = string.upper(code)
	local room = byCode[code]
	if not room then
		fail(player, "UNKNOWN CODE")
		return
	end
	if byPlayer[player.UserId] == room then
		broadcast(room)
		return
	end
	if #room.members >= Config.Room.MaxPlayers then
		fail(player, "ROOM FULL")
		return
	end
	if room.phase ~= "Waiting" then
		fail(player, "RUN IN PROGRESS")
		return
	end
	leave(player)
	addMember(room, player)
end

local function quickJoin(player)
	local best
	for _, room in rooms do
		if room.isPublic and room.phase == "Waiting"
			and #room.members < Config.Room.MaxPlayers
			and byPlayer[player.UserId] ~= room then
			if not best or #room.members > #best.members then
				best = room
			end
		end
	end
	if best then
		leave(player)
		addMember(best, player)
	else
		-- Quick join must NOT silently host on a miss. Creating a room here made
		-- "join something that exists" and "create something new" the same
		-- action, so the client could never report an empty result honestly.
		-- HOST SESSION -> PUBLIC ROOM is the explicit create path; this one only
		-- ever joins.
		fail(player, "NO OPEN ROOM IN THIS SERVER")
	end
end

local function setReady(player, ready)
	local room = byPlayer[player.UserId]
	if not room then return end
	for _, m in room.members do
		if m.userId == player.UserId then
			m.ready = ready == true
			break
		end
	end
	if room.phase == "Starting" and ready ~= true then
		abortCountdown(room, "READY REVOKED - COUNTDOWN ABORTED")
		return
	end
	broadcast(room)
	maybeAutoStart(room)
end

local function startRun(player)
	local room = byPlayer[player.UserId]
	if not room then return end
	if room.hostUserId ~= player.UserId then
		fail(player, "HOST ONLY")
		return
	end
	if #room.members < minPlayers() then
		fail(player, "NOT ENOUGH PLAYERS")
		return
	end
	if Config.Room.RequireAllReady and not allReady(room) then
		fail(player, "ALL PLAYERS MUST BE READY")
		return
	end
	beginCountdown(room)
end

function RoomService.roomOf(player)
	return byPlayer[player.UserId]
end

function RoomService.getRoom(id)
	return rooms[id]
end

function RoomService.finishRun(room)
	if rooms[room.id] ~= room then return end
	room.phase = "Waiting"
	room.countdown = nil
	for _, m in room.members do m.ready = false end
	broadcast(room)
end

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

	Remotes.RoomCreateRequest.OnServerEvent:Connect(function(player, payload)
		if not allow(player, "create", 2) then return end
		local isPublic = type(payload) == "table" and payload.public == true
		createRoom(player, isPublic)
	end)
	Remotes.RoomJoinRequest.OnServerEvent:Connect(function(player, code)
		if not allow(player, "join", 3) then return end
		joinByCode(player, code)
	end)
	Remotes.RoomQuickJoinRequest.OnServerEvent:Connect(function(player)
		if not allow(player, "quick", 2) then return end
		quickJoin(player)
	end)
	Remotes.RoomLeaveRequest.OnServerEvent:Connect(function(player)
		if not allow(player, "leave", 3) then return end
		leave(player)
	end)
	Remotes.RoomReadyRequest.OnServerEvent:Connect(function(player, ready)
		if not allow(player, "ready", 5) then return end
		setReady(player, ready)
	end)
	Remotes.RoomStartRequest.OnServerEvent:Connect(function(player)
		if not allow(player, "start", 2) then return end
		startRun(player)
	end)

	Players.PlayerRemoving:Connect(leave)

	print("[RoomService] online - in-place rooms" .. (RunService:IsStudio() and " (studio)" or ""))
end

return RoomService
