--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

-- iLoveKilIs's Place (same universe, so reserved servers work)
local MAIN_PLACE_ID = 110672791536316

local Config = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local PlaylistService = {}

local TRIALS = {
	require(script.Parent.TrialCanteen),
	require(script.Parent.TrialQuality),
	require(script.Parent.TrialTarget),
}

local Remotes
local RoomServiceRef
local active = {}

local buckets = {}
local function allow(player, perSecond)
	local now = os.clock()
	local b = buckets[player.UserId]
	if not b or now - b.stamp >= 1 then
		buckets[player.UserId] = { stamp = now, count = 1 }
		return true
	end
	if b.count >= perSecond then return false end
	b.count += 1
	return true
end

local function send(room, payload)
	for _, m in room.members do
		local plr = Players:GetPlayerByUserId(m.userId)
		if plr then Remotes.TrialState:FireClient(plr, payload) end
	end
end

local function alive(room)
	return #room.members > 0 and room.phase == "Playing"
end

local function placements(scores, members)
	local arr = {}
	for _, m in members do
		table.insert(arr, { userId = m.userId, displayName = m.displayName, score = scores[m.userId] or 0 })
	end
	table.sort(arr, function(a, b) return a.score > b.score end)
	local pts = Config.Playlist.PlacementPoints
	local lastScore, lastPoints
	for i, e in arr do
		local p = pts[math.min(i, #pts)] or 0
		if lastScore ~= nil and e.score == lastScore then p = lastPoints end
		e.points = p
		lastScore, lastPoints = e.score, p
	end
	return arr
end

local function runPlaylist(room)
	local run = { room = room, totals = {} }
	active[room.id] = run

	for index, trial in TRIALS do
		if not alive(room) then break end
		run.trial = trial
		run.token = string.format("%d:%d:%d", room.id, index, math.random(1, 1e9))

		send(room, {
			kind = "intro", index = index, total = #TRIALS,
			name = trial.DisplayName, verb = trial.Verb, caption = trial.Caption,
			token = run.token,
		})
		task.wait(3.4)
		if not alive(room) then break end

		local ctx = {
			room = room,
			seed = math.random(1, 2 ^ 30),
			index = index,
			token = run.token,
			send = function(payload)
				payload.token = run.token
				send(room, payload)
			end,
		}

		send(room, { kind = "begin", index = index, duration = trial.Duration, name = trial.DisplayName, token = run.token })

		local ok, state = pcall(trial.Setup, ctx)
		if not ok then
			warn("[Playlist] " .. trial.Id .. " Setup errored: " .. tostring(state))
			state = nil
		end
		run.state = state
		if state then pcall(trial.Start, state) end

		local t0 = os.clock()
		while os.clock() - t0 < trial.Duration do
			task.wait(0.25)
			if not alive(room) then break end
		end

		local scores = {}
		if state then
			local ok2, result = pcall(trial.Stop, state)
			if ok2 and type(result) == "table" then scores = result end
			pcall(trial.Cleanup, state)
		end
		run.state = nil
		run.token = nil

		if not alive(room) then break end

		local board = placements(scores, room.members)
		for _, e in board do
			run.totals[e.userId] = (run.totals[e.userId] or 0) + e.points
		end
		send(room, { kind = "trialResult", index = index, total = #TRIALS, name = trial.DisplayName, board = board })
		task.wait(5)
	end

	if alive(room) then
		local finalBoard = {}
		for _, m in room.members do
			table.insert(finalBoard, { userId = m.userId, displayName = m.displayName, score = run.totals[m.userId] or 0 })
		end
		table.sort(finalBoard, function(a, b) return a.score > b.score end)
		send(room, {
			kind = "finalResult", board = finalBoard,
			winner = finalBoard[1] and finalBoard[1].displayName or "",
		})
		task.wait(8)
	end

	active[room.id] = nil
	RoomServiceRef.finishRun(room)
end

-- the real game: reserve a private server on the main place and move the
-- whole lobby there together
local function teleportRoom(room)
	local players = {}
	for _, m in room.members do
		local plr = Players:GetPlayerByUserId(m.userId)
		if plr then table.insert(players, plr) end
	end
	local errRemote = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("LobbyError")
	if #players == 0 then
		RoomServiceRef.finishRun(room)
		return
	end
	if RunService:IsStudio() then
		for _, plr in players do
			if errRemote then errRemote:FireClient(plr, "TELEPORT UNAVAILABLE IN STUDIO") end
		end
		RoomServiceRef.finishRun(room)
		return
	end
	local ok, err = pcall(function()
		local code = TeleportService:ReserveServer(MAIN_PLACE_ID)
		local opts = Instance.new("TeleportOptions")
		opts.ReservedServerAccessCode = code
		TeleportService:TeleportAsync(MAIN_PLACE_ID, players, opts)
	end)
	if not ok then
		warn("[PlaylistService] teleport failed: " .. tostring(err))
		for _, plr in players do
			if errRemote and plr.Parent then errRemote:FireClient(plr, "TRANSPORT FAILED - TRY AGAIN") end
		end
		RoomServiceRef.finishRun(room)
	end
end

local function onInput(player, payload)
	if type(payload) ~= "table" then return end
	if not allow(player, 25) then return end
	local room = RoomServiceRef.roomOf(player)
	local run = room and active[room.id]
	if not run or not run.state or not run.token then return end
	if payload.token ~= run.token then return end
	pcall(run.trial.HandleInput, run.state, player.UserId, payload)
end

function PlaylistService.start(RoomService)
	RoomServiceRef = RoomService

	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	local function ensure(n)
		local r = folder:FindFirstChild(n)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = folder
		end
		return r
	end
	Remotes = { TrialState = ensure("TrialState"), TrialInput = ensure("TrialInput") }

	Remotes.TrialInput.OnServerEvent:Connect(onInput)

	-- TRIAL: host-only practice run of the three sharpening trials
	local practice = ensure("TrialPracticeRequest")
	practice.OnServerEvent:Connect(function(player)
		if not allow(player, 2) then return end
		local room = RoomServiceRef.roomOf(player)
		if not room or room.phase ~= "Waiting" then return end
		if room.hostUserId ~= player.UserId then
			local errRemote = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("LobbyError")
			if errRemote then errRemote:FireClient(player, "HOST ONLY") end
			return
		end
		room.practiceRun = true
		RoomServiceRef.forceStart(room)
	end)

	RoomService.RunRequested:Connect(function(roomId)
		local room = RoomService.getRoom(roomId)
		if not room then return end
		if room.practiceRun then
			room.practiceRun = nil
			task.spawn(runPlaylist, room)
		else
			task.spawn(teleportRoom, room)
		end
	end)

	print("[PlaylistService] online - " .. #TRIALS .. " trials")
end

return PlaylistService
