-- RECALL - the Machine shows you a grid of symbols, then takes some away.
--
-- SECURITY NOTE, and it is the whole reason this module lives in
-- ServerScriptService rather than ReplicatedStorage: during the recall phase the
-- answer key never leaves the server. Clients receive the MASKED grid plus a
-- shuffled candidate tray containing the correct icons mixed with decoys. An
-- exploiter with full memory access still cannot tell which candidate belongs in
-- which blank, because that mapping only exists here.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local IconPool = require(Shared.IconPool)
local Net = require(Shared.Net)

local RecallGrid = Net.get("RecallGrid")
local RecallSubmit = Net.get("RecallSubmit")

local Recall = {}

Recall.Id = "recall"
Recall.DisplayName = "MEMORIZE"
Recall.Verb = "MEMORIZE"
Recall.Duration = Config.Recall.MemorizeTime + Config.Recall.RecallTime
Recall.MinPlayers = 1

-- Round state ---------------------------------------------------------------

local solution: { string } = {} -- cellIndex -> iconId (the answer key, server only)
local isBlank: { [number]: boolean } = {}
local candidateSet: { [string]: boolean } = {} -- valid icon ids a client may submit
local answers: { [Player]: { [number]: string } } = {}
local competitors: { Player } = {}
local submitConn: RBXScriptConnection? = nil
local phaseThread: thread? = nil
local accepting = false

local function log(...)
	if Config.Verbose then
		print("[Recall]", ...)
	end
end

function Recall:Setup(ctx)
	local rng = Random.new(ctx.seed)
	local cellCount = Config.Recall.GridWidth * Config.Recall.GridHeight

	competitors = ctx.players
	answers = {}
	solution = {}
	isBlank = {}
	candidateSet = {}
	accepting = false

	-- Fill the grid. The playable pool may be smaller than the grid while icons
	-- are still being uploaded, so repeat symbols rather than leaving holes -
	-- a grid with duplicates is still a perfectly good memory test.
	local picks = IconPool.sample(rng, cellCount)
	if #picks == 0 then
		warn("[Recall] no icons uploaded yet - see src/shared/IconPool.luau")
		return
	end
	for cell = 1, cellCount do
		solution[cell] = picks[((cell - 1) % #picks) + 1].id
	end

	-- Choose which cells to blank, ramping with the round number.
	local ramp = Config.Recall.BlanksByRound
	local blankCount = ramp[math.min(ctx.round, #ramp)]
	blankCount = math.min(blankCount, cellCount)

	local order = {}
	for cell = 1, cellCount do
		order[cell] = cell
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for i = 1, blankCount do
		isBlank[order[i]] = true
	end

	log(`round {ctx.round}: {cellCount} cells, {blankCount} blanked`)
end

local function buildCandidates(rng: Random): { string }
	-- Correct answers first, deduplicated: two blanks showing the same symbol
	-- should not leak that fact by appearing twice in the tray.
	local seen: { [string]: boolean } = {}
	local list: { string } = {}

	for cell, blank in isBlank do
		if blank then
			local id = solution[cell]
			if id and not seen[id] then
				seen[id] = true
				table.insert(list, id)
			end
		end
	end

	-- Decoys: icons that are not part of any answer.
	local pool = IconPool.playable()
	local decoys = {}
	for _, icon in pool do
		if not seen[icon.id] then
			table.insert(decoys, icon.id)
		end
	end
	for i = #decoys, 2, -1 do
		local j = rng:NextInteger(1, i)
		decoys[i], decoys[j] = decoys[j], decoys[i]
	end
	for i = 1, math.min(Config.Recall.DecoyCount, #decoys) do
		table.insert(list, decoys[i])
	end

	-- Shuffle so correct answers are not clustered at the front.
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end

	candidateSet = {}
	for _, id in list do
		candidateSet[id] = true
	end
	return list
end

function Recall:Start()
	if #solution == 0 then
		return
	end

	-- MEMORIZE phase: the full grid is meant to be seen, so send it as-is.
	RecallGrid:FireAllClients({
		phase = "memorize",
		width = Config.Recall.GridWidth,
		height = Config.Recall.GridHeight,
		grid = solution,
		endsAt = workspace:GetServerTimeNow() + Config.Recall.MemorizeTime,
	})

	submitConn = RecallSubmit.OnServerEvent:Connect(function(player, cell, iconId)
		if not accepting then
			return
		end
		if not Net.allow(player, "RecallSubmit", Config.Recall.SubmitsPerSecond) then
			return
		end
		-- Validate types before anything else: a remote handler must assume the
		-- client is hostile and is sending whatever it likes.
		if type(cell) ~= "number" or type(iconId) ~= "string" then
			return
		end
		if cell ~= math.floor(cell) or not isBlank[cell] then
			return
		end
		if not candidateSet[iconId] then
			return
		end
		if not table.find(competitors, player) then
			return
		end

		local playerAnswers = answers[player]
		if not playerAnswers then
			playerAnswers = {}
			answers[player] = playerAnswers
		end
		-- Overwriting is allowed until time runs out; changing your mind is
		-- part of the game, not an exploit.
		playerAnswers[cell] = iconId
	end)

	phaseThread = task.delay(Config.Recall.MemorizeTime, function()
		local rng = Random.new(os.clock() * 1000)
		local candidates = buildCandidates(rng)

		-- RECALL phase: masked grid only. Blanked cells go out as "".
		local masked = {}
		for cell = 1, #solution do
			masked[cell] = if isBlank[cell] then "" else solution[cell]
		end

		accepting = true
		RecallGrid:FireAllClients({
			phase = "recall",
			width = Config.Recall.GridWidth,
			height = Config.Recall.GridHeight,
			grid = masked,
			candidates = candidates,
			endsAt = workspace:GetServerTimeNow() + Config.Recall.RecallTime,
		})
	end)
end

function Recall:Stop()
	accepting = false

	local result: { [Player]: number } = {}
	for _, player in competitors do
		local playerAnswers = answers[player]
		local correct = 0
		if playerAnswers then
			for cell, iconId in playerAnswers do
				if solution[cell] == iconId then
					correct += 1
				end
			end
		end
		result[player] = correct * Config.Score.RecallPerCorrect
	end

	-- Reveal the answer key now that scoring is locked in. Showing players what
	-- they missed is most of the replay motivation in a memory game.
	RecallGrid:FireAllClients({
		phase = "reveal",
		width = Config.Recall.GridWidth,
		height = Config.Recall.GridHeight,
		grid = solution,
	})

	return result
end

function Recall:Cleanup()
	accepting = false
	if submitConn then
		submitConn:Disconnect()
		submitConn = nil
	end
	if phaseThread then
		task.cancel(phaseThread)
		phaseThread = nil
	end
	solution = {}
	isBlank = {}
	candidateSet = {}
	answers = {}
	competitors = {}
	RecallGrid:FireAllClients({ phase = "hide" })
end

return Recall
