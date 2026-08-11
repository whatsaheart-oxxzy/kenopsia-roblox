--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local BirdHunting = require(script.Parent.BirdHunting)
local Minefield = require(script.Parent.Minefield)

local MachineFlow = {}

local Remote
local RoomServiceRef

-- TRIAL REGISTRY: add a module + an entry here and the machine will seat it.
-- module contract: runRound(room, roundIndex) -> { [userId] = score },
-- optional init() at boot and park() while an opaque card covers everyone.
local TRIALS = {
	{
		id = "birdhunt",
		name = "BIRD HUNTING",
		icon = "Crosshair",
		motto = "RUN. HIDE. SURVIVE.",
		tagline = "A BULLET WITH YOUR NAME ON IT.",
		rounds = 5,
		module = BirdHunting,
	},
	{
		id = "minefield",
		name = "DEAD ZONE",
		icon = "Cube",
		motto = "SCAN AHEAD.",
		tagline = "SCAN AHEAD. WATCH YOUR STEP.",
		rounds = 10,
		module = Minefield,
	},
}
local DECOY_ICONS = { "Magnifier", "Saw", "Factory", "Train", "Bug" }
-- jede Session spielt EIN Minigame; die Roulette wuerfelt es aus

local function trialById(id)
	for _, t in TRIALS do
		if t.id == id then return t end
	end
	return TRIALS[1]
end

local function send(room, payload)
	for _, m in room.members do
		local plr = Players:GetPlayerByUserId(m.userId)
		if plr then Remote:FireClient(plr, payload) end
	end
end

local function alive(room)
	return #room.members > 0 and room.phase == "Playing"
end

local function setActiveTrial(room, trialId)
	for _, member in room.members do
		local plr = Players:GetPlayerByUserId(member.userId)
		if plr then plr:SetAttribute("KenopsiaActiveTrial", trialId or "") end
	end
end

local function runTrialRound(trial, room, roundIndex)
	if trial.id ~= "birdhunt" or #room.members < 2 then
		return pcall(trial.module.runRound, room, roundIndex)
	end

	-- Duck Hunt fairness: every participant is Hunter once inside each numbered
	-- round. Rotating the starting seat varies the order without changing turns.
	local scores = {}
	local order = table.clone(room.members)
	local offset = ((roundIndex or 1) - 1) % #order
	for leg = 1, #order do
		if not alive(room) then break end
		local member = order[(offset + leg - 1) % #order + 1]
		local ok, legScores = pcall(
			trial.module.runRound,
			room,
			roundIndex,
			member.userId,
			leg,
			#order
		)
		if not ok then return false, legScores end
		if type(legScores) == "table" then
			for uid, value in legScores do
				scores[uid] = (scores[uid] or 0) + value
			end
		end
	end
	return true, scores
end

-- MainGameMenu lobby: flicker-roulette selection, then the info/ready panel.
local function preFlow(room)
	local trial = TRIALS[math.random(#TRIALS)]
	room.trialId = trial.id

	-- decoy tiles: other registered trials first, topped up with flavor icons
	local others = {}
	for _, t in TRIALS do
		if t.id ~= trial.id then table.insert(others, t.icon) end
	end
	local pool = {}
	for _, ic in DECOY_ICONS do
		if ic ~= trial.icon then table.insert(pool, ic) end
	end
	while #others < 2 and #pool > 0 do
		table.insert(others, table.remove(pool, math.random(#pool)))
	end
	while #others > 2 do
		table.remove(others, math.random(#others))
	end

	local chosenIdx = math.random(3)
	local icons = {}
	for i = 1, 3 do
		if i == chosenIdx then
			icons[i] = trial.icon
		else
			icons[i] = table.remove(others, 1)
		end
	end
	room.chosenTile = chosenIdx

	-- mark live members as served NOW, or the catch-up loop fires "info" at
	-- them within 2s and cuts the selection roulette short
	room.preSent = room.preSent or {}
	for _, m in room.members do
		room.preSent[m.userId] = true
	end
	send(room, { kind = "selection", icons = icons, chosen = chosenIdx })
	task.wait(6.4)
	if room.phase ~= "Waiting" or #room.members == 0 then return end
	send(room, { kind = "info", name = trial.name, icon = trial.icon, id = trial.id })
	room.preSent = room.preSent or {}
	for _, m in room.members do
		room.preSent[m.userId] = true
	end
end

local function runFlow(room)
	local trial = trialById(room.trialId)
	send(room, { kind = "status", lines = {
		"All subjects successfully briefed.",
		"Likelyhood of subjects understanding briefing: 90%",
		"Likelyhood of subject survival: 20%",
		"Favorable gene mutation percentage: 0.5%",
		" ",
		"Bootstrapping next simulation ...",
		"Geometry cache 32/100",
	} })
	task.wait(6.5)
	if not alive(room) then return end

	local totals = {}
	local rounds = trial.rounds or 5
	for round = 1, rounds do
		if not alive(room) then return end
		send(room, { kind = "round", n = round, total = rounds, verbs = trial.tagline })
		task.wait(3)
		if not alive(room) then return end
		send(room, { kind = "hide" })
		-- Trial presentation is per player; concurrent rooms must not clobber
		-- each other's music or lighting through one replicated global attribute.
		setActiveTrial(room, trial.id)
		local ok, scores = runTrialRound(trial, room, round)
		setActiveTrial(room, "")
		if ok and type(scores) == "table" then
			for uid, s in scores do
				totals[uid] = (totals[uid] or 0) + s
			end
		else
			warn("[MachineFlow] round errored: " .. tostring(scores))
		end
		task.wait(1.5)
		-- Zwischenstand zwischen den Runden (nicht nach der letzten - da kommt das Finale)
		if round < rounds and alive(room) and trial.id ~= "birdhunt" and trial.id ~= "minefield" then
			local standings = {}
			for _, m in room.members do
				table.insert(standings, {
					userId = m.userId,
					displayName = m.displayName,
					score = totals[m.userId] or 0,
				})
			end
			table.sort(standings, function(a, b) return a.score > b.score end)
			send(room, { kind = "score", board = standings })
			task.wait(5.5)
			if not alive(room) then return end
			send(room, { kind = "hide" })
		end
	end

	task.wait(3)
	if not alive(room) then return end

	local board = {}
	for _, m in room.members do
		table.insert(board, {
			userId = m.userId,
			displayName = m.displayName,
			score = totals[m.userId] or 0,
		})
		-- session running total, surfaced on the ready-panel roster via attribute
		local plr = Players:GetPlayerByUserId(m.userId)
		if plr then
			plr:SetAttribute("KenopsiaSessionScore", (plr:GetAttribute("KenopsiaSessionScore") or 0) + (totals[m.userId] or 0))
		end
	end
	table.sort(board, function(a, b) return a.score > b.score end)

	-- session wins: only meaningful with an opponent and a real score
	if #board >= 2 and board[1].score > 0 and board[1].score > board[2].score then
		local winner = Players:GetPlayerByUserId(board[1].userId)
		if winner then
			winner:SetAttribute("KenopsiaSessionWins", (winner:GetAttribute("KenopsiaSessionWins") or 0) + 1)
		end
	end

	send(room, { kind = "score", board = board })
	pcall(function()
		if trial.module.park then trial.module.park() end
	end)
	task.wait(14)

	send(room, { kind = "hide" })
	room.preSent = nil
	RoomServiceRef.finishRun(room)

	-- straight back into a fresh lobby: no world-gap between cycles
	task.wait(0.4)
	if room.phase == "Waiting" and #room.members > 0 then
		room.preShown = true
		task.spawn(preFlow, room)
	else
		room.preShown = nil
	end
end

function MachineFlow.start(RoomService)
	RoomServiceRef = RoomService
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	Remote = folder:FindFirstChild("MachineState")
	if not Remote then
		Remote = Instance.new("RemoteEvent")
		Remote.Name = "MachineState"
		Remote.Parent = folder
	end
	for _, t in TRIALS do
		if t.module.init then
			local ok, err = pcall(t.module.init)
			if not ok then warn(("[MachineFlow] %s init failed: %s"):format(t.id, tostring(err))) end
		end
	end

	RoomService.RunRequested:Connect(function(roomId)
		local room = RoomService.getRoom(roomId)
		if room then task.spawn(runFlow, room) end
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			if workspace:GetAttribute("KenopsiaNoAuto") then continue end
			for _, plr in Players:GetPlayers() do
				-- hold new joiners out until the content warning has played
				if not plr:GetAttribute("KenopsiaJoinedAt") then
					plr:SetAttribute("KenopsiaJoinedAt", os.clock())
				end
				if os.clock() - plr:GetAttribute("KenopsiaJoinedAt") > 7 then
					RoomServiceRef.autoSeat(plr)
				end
				local room = RoomServiceRef.roomOf(plr)
				if room and room.preShown and room.phase == "Waiting" then
					room.preSent = room.preSent or {}
					if not room.preSent[plr.UserId] then
						room.preSent[plr.UserId] = true
						local t = trialById(room.trialId)
						Remote:FireClient(plr, { kind = "info", name = t.name, icon = t.icon, id = t.id })
					end
				end
			end
			for _, room in RoomServiceRef.waitingRooms() do
				if #room.members > 0 and not room.preShown then
					room.preShown = true
					task.spawn(preFlow, room)
				end
			end
		end
	end)

	print("[MachineFlow] online - trial registry (" .. #TRIALS .. " registered)")
end

return MachineFlow
