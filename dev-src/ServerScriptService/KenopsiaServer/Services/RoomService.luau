--!nonstrict
-- Current-server party authority for Kenopsia_DEV.
-- PartyRegistry intentionally remains dormant: browsing, codes and approval
-- requests live only for the lifetime of this menu server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(
	ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig")
)

local RoomService = {}

local runRequested = Instance.new("BindableEvent")
RoomService.RunRequested = runRequested.Event

local rooms = {}
local byCode = {}
local byPlayer = {}
local pendingByPlayer = {}
local nextRoomId = 0
local nextRequestToken = 0
local Remotes

-- Per-player buckets disappear on PlayerRemoving; no UserId-keyed residue.
local buckets = {}
local function allow(player, key, perSecond)
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local bucket = playerBuckets[key]
	if not bucket or now - bucket.stamp >= 1 then
		playerBuckets[key] = { stamp = now, count = 1 }
		return true
	end
	if bucket.count >= perSecond then
		return false
	end
	bucket.count += 1
	return true
end

local function fail(player, message)
	if player and player.Parent == Players then
		Remotes.LobbyError:FireClient(player, message)
	end
end

local function exactKeys(payload, allowed)
	if type(payload) ~= "table" then
		return false
	end
	for key in payload do
		if not allowed[key] then
			return false
		end
	end
	return true
end

local function minPlayers()
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
		if not byCode[code] then
			return code
		end
	end
	return nil
end

local function publicState(room)
	local members = {}
	for _, member in room.members do
		table.insert(members, {
			userId = member.userId,
			displayName = member.displayName,
			ready = member.ready,
		})
	end
	return {
		roomId = room.id,
		-- Codes are a private-party join instrument. Members of a public party do
		-- not need one, so it is not replicated there.
		code = room.isPublic and nil or room.code,
		isPublic = room.isPublic,
		joinPolicy = room.joinPolicy,
		hostUserId = room.hostUserId,
		phase = room.phase,
		countdown = room.countdown,
		memberCount = #room.members,
		maxPlayers = Config.Room.MaxPlayers,
		minPlayers = minPlayers(),
		members = members,
	}
end

local function broadcastRoom(room)
	local state = publicState(room)
	for _, member in room.members do
		local target = Players:GetPlayerByUserId(member.userId)
		if target then
			Remotes.RoomState:FireClient(target, state)
		end
	end
end

local function browseRows()
	local rows = {}
	for _, room in rooms do
		if room.isPublic and room.phase == "Waiting" and #room.members < Config.Room.MaxPlayers then
			local host = Players:GetPlayerByUserId(room.hostUserId)
			local hostName = host and host.DisplayName or room.members[1] and room.members[1].displayName or "UNKNOWN"
			table.insert(rows, {
				roomId = room.id,
				hostDisplayName = string.sub(tostring(hostName), 1, 32),
				memberCount = #room.members,
				maxPlayers = Config.Room.MaxPlayers,
				joinPolicy = room.joinPolicy,
				_createdAt = room.createdAt,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.memberCount ~= b.memberCount then
			return a.memberCount > b.memberCount
		end
		if a._createdAt ~= b._createdAt then
			return a._createdAt < b._createdAt
		end
		return a.roomId < b.roomId
	end)
	local limit = math.min(#rows, Config.Room.BrowseLimit or 15)
	local sanitized = table.create(limit)
	for i = 1, limit do
		local row = rows[i]
		sanitized[i] = {
			roomId = row.roomId,
			hostDisplayName = row.hostDisplayName,
			memberCount = row.memberCount,
			maxPlayers = Config.Room.MaxPlayers,
			joinPolicy = row.joinPolicy,
		}
	end
	return sanitized
end

local function sendBrowse(player)
	if player and player.Parent == Players then
		Remotes.RoomBrowseState:FireClient(player, { rooms = browseRows() })
	end
end

local function broadcastBrowse()
	local payload = { rooms = browseRows() }
	for _, player in Players:GetPlayers() do
		Remotes.RoomBrowseState:FireClient(player, payload)
	end
end

local function pendingCount(room)
	local count = 0
	for _ in room.pending do
		count += 1
	end
	return count
end

local function sendPending(room)
	local host = Players:GetPlayerByUserId(room.hostUserId)
	if not host then
		return
	end
	local requests = {}
	for _, request in room.pending do
		table.insert(requests, {
			userId = request.userId,
			displayName = request.displayName,
			expiresAt = request.expiresAt,
			requestedAt = request.requestedAt,
		})
	end
	table.sort(requests, function(a, b)
		if a.requestedAt ~= b.requestedAt then
			return a.requestedAt < b.requestedAt
		end
		return a.userId < b.userId
	end)
	Remotes.RoomPendingState:FireClient(host, { roomId = room.id, requests = requests })
end

local function joinStatus(player, status, room, message)
	if player and player.Parent == Players then
		Remotes.RoomJoinStatus:FireClient(player, {
			status = status,
			roomId = room and room.id or nil,
			message = message,
		})
	end
end

local function clearPending(request, status, message, suppressHostUpdate)
	if not request then
		return
	end
	local room = request.room
	if room.pending[request.userId] == request then
		room.pending[request.userId] = nil
	end
	if pendingByPlayer[request.userId] == request then
		pendingByPlayer[request.userId] = nil
	end
	if status then
		joinStatus(Players:GetPlayerByUserId(request.userId), status, room, message)
	end
	if not suppressHostUpdate and rooms[room.id] == room then
		sendPending(room)
	end
end

local function cancelAllPending(room, status, message)
	local requests = {}
	for _, request in room.pending do
		table.insert(requests, request)
	end
	for _, request in requests do
		clearPending(request, status, message, true)
	end
	if rooms[room.id] == room then
		sendPending(room)
	end
end

local function destroyRoom(room)
	cancelAllPending(room, "Declined", "PARTY CLOSED")
	rooms[room.id] = nil
	byCode[room.code] = nil
	broadcastBrowse()
end

local function abortCountdown(room, reason)
	if room.phase ~= "Starting" then
		return
	end
	room.token += 1
	room.phase = "Waiting"
	room.countdown = nil
	if reason then
		for _, member in room.members do
			fail(Players:GetPlayerByUserId(member.userId), reason)
		end
	end
	broadcastRoom(room)
	broadcastBrowse()
end

local function beginCountdown(room)
	if room.phase ~= "Waiting" then
		return
	end
	-- Once a party starts, nobody can be approved into a moving target.
	cancelAllPending(room, "Declined", "PARTY STARTED")
	room.phase = "Starting"
	room.token += 1
	local token = room.token
	broadcastBrowse()
	task.spawn(function()
		for number = 5, 1, -1 do
			if room.token ~= token or room.phase ~= "Starting" then
				return
			end
			room.countdown = number
			broadcastRoom(room)
			task.wait(1)
		end
		if room.token ~= token or room.phase ~= "Starting" then
			return
		end
		room.countdown = nil
		room.phase = "Playing"
		broadcastRoom(room)
		broadcastBrowse()
		-- Fire the id, not the table: the playlist must resolve the live room.
		runRequested:Fire(room.id)
	end)
end

local function allReady(room)
	for _, member in room.members do
		if not member.ready then
			return false
		end
	end
	return true
end

local function maybeAutoStart(room)
	if Config.Room.RequireAllReady and room.phase == "Waiting" and #room.members >= minPlayers() and allReady(room) then
		beginCountdown(room)
	end
end

function RoomService.forceStart(room)
	beginCountdown(room)
end

local function removeMember(room, userId)
	for index, member in room.members do
		if member.userId == userId then
			table.remove(room.members, index)
			break
		end
	end
	byPlayer[userId] = nil
	if #room.members == 0 then
		destroyRoom(room)
		return
	end
	local hostChanged = room.hostUserId == userId
	if hostChanged then
		room.hostUserId = room.members[1].userId
	end
	if room.phase == "Starting" then
		abortCountdown(room, "PARTICIPANT LOST - COUNTDOWN ABORTED")
	end
	broadcastRoom(room)
	if hostChanged then
		-- Approval requests survive host migration and are immediately shown to
		-- the successor rather than being owned by the departed client.
		sendPending(room)
	end
	broadcastBrowse()
end

local function leave(player)
	local request = pendingByPlayer[player.UserId]
	if request then
		clearPending(request, "Cancelled", "REQUEST CANCELLED")
	end
	local room = byPlayer[player.UserId]
	if room then
		removeMember(room, player.UserId)
	end
end

local function addMember(room, player)
	local request = pendingByPlayer[player.UserId]
	if request then
		clearPending(request, nil, nil, true)
	end
	table.insert(room.members, {
		userId = player.UserId,
		displayName = string.sub(player.DisplayName, 1, 32),
		ready = false,
	})
	byPlayer[player.UserId] = room
	if #room.members >= Config.Room.MaxPlayers then
		cancelAllPending(room, "Declined", "PARTY FULL")
	else
		sendPending(room)
	end
	broadcastRoom(room)
	broadcastBrowse()
end

local function createRoom(player, isPublic, joinPolicy)
	if byPlayer[player.UserId] then
		fail(player, "LEAVE YOUR CURRENT PARTY FIRST")
		return
	end
	if pendingByPlayer[player.UserId] then
		fail(player, "CANCEL YOUR JOIN REQUEST FIRST")
		return
	end
	local code = generateCode()
	if not code then
		fail(player, "NO CODES AVAILABLE - TRY AGAIN")
		return
	end
	nextRoomId += 1
	local room = {
		id = nextRoomId,
		code = code,
		isPublic = isPublic,
		joinPolicy = joinPolicy,
		hostUserId = player.UserId,
		phase = "Waiting",
		countdown = nil,
		members = {},
		pending = {},
		token = 0,
		createdAt = os.clock(),
	}
	rooms[room.id] = room
	byCode[code] = room
	addMember(room, player)
end

local function roomCanAccept(room)
	return room and rooms[room.id] == room and room.phase == "Waiting" and #room.members < Config.Room.MaxPlayers
end

local function requestJoin(player, room, publicOnly)
	if not room then
		fail(player, publicOnly and "PUBLIC PARTY NOT FOUND" or "UNKNOWN CODE")
		return
	end
	if publicOnly and not room.isPublic then
		fail(player, "PUBLIC PARTY NOT FOUND")
		return
	end
	local current = byPlayer[player.UserId]
	if current then
		if current == room then
			broadcastRoom(room)
			joinStatus(player, "Accepted", room, "ALREADY IN PARTY")
		else
			fail(player, "LEAVE YOUR CURRENT PARTY FIRST")
		end
		return
	end
	local existing = pendingByPlayer[player.UserId]
	if existing then
		if existing.room == room then
			joinStatus(player, "Pending", room, "WAITING FOR HOST APPROVAL")
		else
			fail(player, "CANCEL YOUR JOIN REQUEST FIRST")
		end
		return
	end
	if not roomCanAccept(room) then
		if room.phase ~= "Waiting" then
			fail(player, "PARTY ALREADY STARTED")
		else
			fail(player, "PARTY FULL")
		end
		return
	end

	if room.joinPolicy == "Open" then
		addMember(room, player)
		joinStatus(player, "Accepted", room, "JOINED PARTY")
		return
	end
	if pendingCount(room) >= (Config.Room.MaxPendingJoinRequests or 8) then
		fail(player, "PARTY REQUEST QUEUE FULL")
		return
	end

	nextRequestToken += 1
	local now = os.clock()
	local request = {
		room = room,
		userId = player.UserId,
		displayName = string.sub(player.DisplayName, 1, 32),
		requestedAt = now,
		expiresAt = now + (Config.Room.JoinRequestLifetimeSeconds or 45),
		token = nextRequestToken,
	}
	room.pending[player.UserId] = request
	pendingByPlayer[player.UserId] = request
	joinStatus(player, "Pending", room, "WAITING FOR HOST APPROVAL")
	sendPending(room)

	task.delay(Config.Room.JoinRequestLifetimeSeconds or 45, function()
		local live = pendingByPlayer[request.userId]
		if live ~= request or live.token ~= request.token then
			return
		end
		clearPending(request, "Expired", "REQUEST EXPIRED")
	end)
end

local function validCode(code)
	if type(code) ~= "string" or #code ~= Config.Room.CodeLength then
		return nil
	end
	local upper = string.upper(code)
	for i = 1, #upper do
		if not string.find(Config.Room.CodeAlphabet, string.sub(upper, i, i), 1, true) then
			return nil
		end
	end
	return upper
end

local function joinByCode(player, code)
	local clean = validCode(code)
	if not clean then
		fail(player, "INVALID PARTY CODE")
		return
	end
	requestJoin(player, byCode[clean], false)
end

local function joinPublic(player, roomId)
	if type(roomId) ~= "number" or roomId ~= roomId or roomId % 1 ~= 0 or roomId < 1 then
		return
	end
	requestJoin(player, rooms[roomId], true)
end

-- Backwards-compatible route for any older client still present during a
-- rolling publish. New UI always browses and joins a chosen roomId.
local function quickJoin(player)
	local best
	for _, room in rooms do
		if room.isPublic and roomCanAccept(room) then
			if
				not best
				or #room.members > #best.members
				or (#room.members == #best.members and room.createdAt < best.createdAt)
			then
				best = room
			end
		end
	end
	if best then
		requestJoin(player, best, true)
	else
		fail(player, "NO PUBLIC PARTIES IN THIS SERVER")
	end
end

local function decideJoin(player, payload)
	if not exactKeys(payload, { requestUserId = true, accept = true }) then
		return
	end
	local userId = payload.requestUserId
	local accept = payload.accept
	if type(userId) ~= "number" or userId ~= userId or userId % 1 ~= 0 or userId < 1 then
		return
	end
	if type(accept) ~= "boolean" then
		return
	end
	local room = byPlayer[player.UserId]
	if not room or room.hostUserId ~= player.UserId then
		fail(player, "HOST ONLY")
		return
	end
	local request = room.pending[userId]
	if not request or pendingByPlayer[userId] ~= request then
		return
	end
	if os.clock() >= request.expiresAt then
		clearPending(request, "Expired", "REQUEST EXPIRED")
		return
	end
	if not accept then
		clearPending(request, "Declined", "HOST DECLINED")
		return
	end
	if not roomCanAccept(room) then
		clearPending(request, "Declined", room.phase == "Waiting" and "PARTY FULL" or "PARTY STARTED")
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		clearPending(request, "Cancelled", "PLAYER LEFT")
		return
	end
	clearPending(request, nil, nil, true)
	addMember(room, target)
	joinStatus(target, "Accepted", room, "HOST ACCEPTED")
end

local function cancelJoin(player)
	local request = pendingByPlayer[player.UserId]
	if request then
		clearPending(request, "Cancelled", "REQUEST CANCELLED")
	else
		joinStatus(player, "Cancelled", nil, "NO OPEN REQUEST")
	end
end

local function setReady(player, ready)
	local room = byPlayer[player.UserId]
	if not room then
		return
	end
	if room.phase ~= "Waiting" and room.phase ~= "Starting" then
		return
	end
	if ready and #room.members < minPlayers() then
		fail(player, string.format("MINIMUM %d PLAYERS", minPlayers()))
		return
	end
	for _, member in room.members do
		if member.userId == player.UserId then
			member.ready = ready
			break
		end
	end
	if room.phase == "Starting" and not ready then
		abortCountdown(room, "READY REVOKED - COUNTDOWN ABORTED")
		return
	end
	broadcastRoom(room)
	maybeAutoStart(room)
end

local function startRun(player)
	local room = byPlayer[player.UserId]
	if not room then
		return
	end
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
	if not room or rooms[room.id] ~= room then
		return
	end
	room.phase = "Waiting"
	room.countdown = nil
	for _, member in room.members do
		member.ready = false
	end
	broadcastRoom(room)
	broadcastBrowse()
end

local function ensureRemotes()
	local kenopsia = ReplicatedStorage:FindFirstChild("Kenopsia")
	if not kenopsia then
		kenopsia = Instance.new("Folder")
		kenopsia.Name = "Kenopsia"
		kenopsia.Parent = ReplicatedStorage
	end
	local folder = kenopsia:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = kenopsia
	end
	local names = {
		"RoomState",
		"RoomBrowseState",
		"RoomJoinStatus",
		"RoomPendingState",
		"LobbyError",
		"RoomCreateRequest",
		"RoomJoinRequest",
		"RoomBrowseRequest",
		"RoomPublicJoinRequest",
		"RoomJoinDecisionRequest",
		"RoomJoinCancelRequest",
		"RoomQuickJoinRequest",
		"RoomLeaveRequest",
		"RoomReadyRequest",
		"RoomStartRequest",
	}
	Remotes = {}
	for _, name in names do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		Remotes[name] = remote
	end
end

function RoomService.start()
	ensureRemotes()

	Remotes.RoomCreateRequest.OnServerEvent:Connect(function(player, payload, ...)
		if select("#", ...) > 0 or not allow(player, "create", 2) then
			return
		end
		if
			not exactKeys(payload, { public = true, joinPolicy = true })
			or type(payload.public) ~= "boolean"
			or (payload.joinPolicy ~= "Open" and payload.joinPolicy ~= "Approval")
		then
			fail(player, "INVALID CREATE REQUEST")
			return
		end
		createRoom(player, payload.public, payload.joinPolicy)
	end)
	Remotes.RoomJoinRequest.OnServerEvent:Connect(function(player, code, ...)
		if select("#", ...) > 0 or not allow(player, "join", 2) then
			return
		end
		joinByCode(player, code)
	end)
	Remotes.RoomBrowseRequest.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) > 0 or not allow(player, "browse", 2) then
			return
		end
		sendBrowse(player)
	end)
	Remotes.RoomPublicJoinRequest.OnServerEvent:Connect(function(player, roomId, ...)
		if select("#", ...) > 0 or not allow(player, "join", 2) then
			return
		end
		joinPublic(player, roomId)
	end)
	Remotes.RoomJoinDecisionRequest.OnServerEvent:Connect(function(player, payload, ...)
		if select("#", ...) > 0 or not allow(player, "decision", 5) then
			return
		end
		decideJoin(player, payload)
	end)
	Remotes.RoomJoinCancelRequest.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) > 0 or not allow(player, "cancel", 2) then
			return
		end
		cancelJoin(player)
	end)
	Remotes.RoomQuickJoinRequest.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) > 0 or not allow(player, "join", 2) then
			return
		end
		quickJoin(player)
	end)
	Remotes.RoomLeaveRequest.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) > 0 or not allow(player, "leave", 3) then
			return
		end
		leave(player)
	end)
	Remotes.RoomReadyRequest.OnServerEvent:Connect(function(player, ready, ...)
		if select("#", ...) > 0 or not allow(player, "ready", 5) then
			return
		end
		if type(ready) ~= "boolean" then
			return
		end
		setReady(player, ready)
	end)
	Remotes.RoomStartRequest.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) > 0 or not allow(player, "start", 2) then
			return
		end
		startRun(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			sendBrowse(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		buckets[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.defer(function()
			sendBrowse(player)
		end)
	end

	print("[RoomService] online - current-server parties" .. (RunService:IsStudio() and " (studio)" or ""))
end

return RoomService
