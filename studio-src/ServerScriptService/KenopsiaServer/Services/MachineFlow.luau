--!nonstrict
-- MATCH FLOW (Phase 1).
--
-- Owns everything inside RoomService's Playing phase:
--   Selecting -> Briefing -> Trial -> Score -> Final Score
-- and unwinds through a finally-style cleanup on either a clean finish or an
-- abort.
--
-- Phase 1 introduces the session/token/cancellation infrastructure and the
-- declarative trial registry. It deliberately does NOT change how a trial
-- plays: BirdHunting and Minefield are still invoked with their existing
-- signatures, and each match still runs one roulette-picked trial. Threading
-- RoundContext into the trial modules, and running three shuffled trials per
-- match, belong to their own phases (REQ-REG-01, plan section 2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local BirdHunting = require(script.Parent.BirdHunting)
local Minefield = require(script.Parent.Minefield)
local TableManners = require(script.Parent.TableManners)

local MachineFlow = {}

local Remote
local RoomServiceRef

-- DECLARATIVE TRIAL REGISTRY -------------------------------------------------
-- A trial is schedulable only when it is listed in GameConfig.Playlist.TrialIds
-- AND declares ready = true here. Two independent gates, so an unfinished
-- trial cannot reach the roulette by editing one list.
local TRIALS = {
	{
		id = "birdhunt",
		displayName = "BIRD HUNTING",
		icon = "Crosshair",
		subtitle = "THE SIGHTLINE NEVER BLINKS._",
		tagline = "A BULLET WITH YOUR NAME ON IT.",
		ready = true,
		showInterRoundScore = false,
		roundsForPlayerCount = function(_n) return 5 end,
		module = BirdHunting,
	},
	{
		id = "minefield",
		displayName = "DEAD ZONE",
		icon = "Cube",
		subtitle = "READ THE FLOOR. KEEP MOVING._",
		tagline = "SCAN AHEAD. WATCH YOUR STEP.",
		ready = true,
		showInterRoundScore = false,
		roundsForPlayerCount = function(_n) return 10 end,
		module = Minefield,
	},
	{
		-- REQ-CP-01..04: arena markers, refs() lookup, mechanic and audio are
		-- all outstanding. ready = false keeps it out of the roulette. Do not
		-- flip this until its acceptance gate passes.
		id = "tablemanners",
		displayName = "CANTEEN PROTOCOL",
		icon = "Saw",
		subtitle = "RATION ISSUED. EAT ONLY WHEN UNOBSERVED._",
		tagline = "FREEZE WHEN THE INSPECTOR LOOKS.",
		ready = false,
		showInterRoundScore = false,
		roundsForPlayerCount = function(_n) return 5 end,
		module = TableManners,
	},
}
local DECOY_ICONS = { "Magnifier", "Saw", "Factory", "Train", "Bug" }

local function trialById(id)
	for _, t in TRIALS do
		if t.id == id then return t end
	end
	return nil
end

-- Both gates.
local function enabledTrials()
	local out = {}
	for _, id in Config.Playlist.TrialIds do
		local t = trialById(id)
		if t and t.ready then
			table.insert(out, t)
		elseif t then
			warn(("[MachineFlow] trial '%s' is listed but ready=false - excluded"):format(id))
		else
			warn(("[MachineFlow] trial '%s' is listed but not registered - excluded"):format(id))
		end
	end
	return out
end

-- SESSION / ROUND CONTEXT ----------------------------------------------------
local sessionsByRoomId = {}
local activeByUser = {}
local roundCounter = 0

local function newRoundToken(sessionId)
	roundCounter += 1
	return ("%s#R%d"):format(sessionId, roundCounter)
end

local function buildContext(room, trial)
	local audience = RoomServiceRef.audience(room)
	local participantUserIds = {}
	for _, m in room.members do
		table.insert(participantUserIds, m.userId)
	end
	local sessionId = room.sessionId
	local roundToken = newRoundToken(sessionId)
	return {
		sessionId = sessionId,
		roundToken = roundToken,
		roomId = room.id,
		room = room,
		audience = audience,
		participantUserIds = participantUserIds,
		effectScope = ("%s:%s"):format(sessionId, trial.id),
		cancelled = function()
			return RoomServiceRef.cancelled(sessionId)
		end,
	}
end

-- messaging ------------------------------------------------------------------
-- Sends only to the captured audience, never FireAllClients.
local function tell(ctx, payload)
	if not Remote then return end
	for _, plr in ctx.audience do
		if plr.Parent == Players then Remote:FireClient(plr, payload) end
	end
end

local function tellRoom(room, payload)
	if not Remote then return end
	for _, m in room.members do
		local plr = Players:GetPlayerByUserId(m.userId)
		if plr then Remote:FireClient(plr, payload) end
	end
end

-- Cancellation-aware wait. Returns false the moment the session dies.
local function hold(ctx, seconds)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if ctx.cancelled() then return false end
		task.wait(0.1)
	end
	return not ctx.cancelled()
end

local function setActiveTrial(ctx, trialId)
	for _, plr in ctx.audience do
		if plr.Parent == Players then
			plr:SetAttribute("KenopsiaActiveTrial", trialId or "")
		end
	end
end

-- SELECTING ------------------------------------------------------------------
local function runSelection(room)
	local pool = enabledTrials()
	if #pool == 0 then
		warn("[MachineFlow] no ready trials - cannot select")
		return nil
	end
	local trial = pool[math.random(#pool)]
	room.trialId = trial.id

	local others = {}
	for _, t in pool do
		if t.id ~= trial.id then table.insert(others, t.icon) end
	end
	local decoys = {}
	for _, ic in DECOY_ICONS do
		if ic ~= trial.icon then table.insert(decoys, ic) end
	end
	while #others < 2 and #decoys > 0 do
		table.insert(others, table.remove(decoys, math.random(#decoys)))
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
	return trial, icons, chosenIdx
end

-- Lobby presentation while Waiting: roulette, then the info/ready panel.
local function preFlow(room)
	-- C4: the lobby pre-flow runs while the room is still Waiting, so there is
	-- no sessionId yet and the Playing-gated setter cannot be used. room.token
	-- is the Waiting-phase epoch; capture it before the first yield and let
	-- RoomService reject the write if a countdown - or a whole match - moved the
	-- room on while this thread was parked in the task.wait below.
	local waitingToken = room.token
	local trial, icons, chosenIdx = runSelection(room)
	if not trial then
		-- P3 fix: clear the flag on the way out. The boot watchdog only spawns
		-- preFlow when `not room.preShown`, so leaving it set here would
		-- permanently disable the lobby roulette for the life of the server
		-- once no trial is ready.
		room.preShown = nil
		return
	end

	RoomServiceRef.setWaitingStage(waitingToken, "Selecting")
	room.preSent = room.preSent or {}
	for _, m in room.members do room.preSent[m.userId] = true end
	tellRoom(room, { kind = "selection", icons = icons, chosen = chosenIdx })
	task.wait(6.4)
	if room.phase ~= "Waiting" or #room.members == 0 then return end
	tellRoom(room, {
		kind = "info",
		name = trial.displayName,
		icon = trial.icon,
		id = trial.id,
	})
	room.preSent = room.preSent or {}
	for _, m in room.members do room.preSent[m.userId] = true end
end

-- MATCH ----------------------------------------------------------------------
local function runMatch(room)
	-- C2: every route - setup, no-ready-trial, cancellation, completion and
	-- trial error - leaves through the single finalizer below. `outcome` is
	-- the one source of truth, so an aborted session is never logged as a
	-- completed match.
	local outcome = "completed" -- completed | cancelled | no-trial | error
	local trial, ctx = nil, nil
	local cleaned = false
	-- Latches once the match has genuinely finished and its scores are written.
	-- From that point the result is immutable: a player leaving during the
	-- final-board presentation must not retroactively relabel a completed match
	-- as cancelled.
	local scoresCommitted = false

	-- Must be safe before ctx exists: the no-trial route reaches it too.
	local function cleanup()
		if cleaned then return end
		cleaned = true
		if ctx then
			setActiveTrial(ctx, "")
			if trial and trial.module.cleanup then
				pcall(trial.module.cleanup, ctx)
			end
			for _, uid in ctx.participantUserIds do
				if activeByUser[uid] == ctx then activeByUser[uid] = nil end
			end
			if sessionsByRoomId[room.id] == ctx then
				sessionsByRoomId[room.id] = nil
			end
		end
		room.preSent = nil
		tellRoom(room, { kind = "hide" })
	end

	local ok, err = xpcall(function()
		-- Trial resolution moved inside the protected body. Previously a
		-- missing trial called abort() and returned before cleanup existed,
		-- stranding the room in Aborting with nothing to drive it out.
		trial = trialById(room.trialId)
		if not (trial and trial.ready) then
			local pool = enabledTrials()
			trial = pool[1]
		end
		if not trial then
			warn("[MachineFlow] no ready trial at match start")
			outcome = "no-trial"
			return
		end

		ctx = buildContext(room, trial)
		sessionsByRoomId[room.id] = ctx
		for _, uid in ctx.participantUserIds do
			activeByUser[uid] = ctx
		end

		-- C6: KenopsiaSessionScore/Wins are MATCH-scoped, not server-scoped.
		-- Zero them once here, for this match's participant snapshot. Without
		-- this they accumulate for the lifetime of the server and the lobby
		-- roster reads as a career total instead of this match's result.
		-- REVISIT WITH THE THREE-TRIAL PLAYLIST (REQ-REG-01): once a session
		-- runs three shuffled trials these counters must carry ACROSS the
		-- trials of one session, so the reset has to stay HERE, before the
		-- first trial, and must never move into a per-trial loop.
		for _, uid in ctx.participantUserIds do
			local plr = Players:GetPlayerByUserId(uid)
			if plr then
				plr:SetAttribute("KenopsiaSessionScore", 0)
				plr:SetAttribute("KenopsiaSessionWins", 0)
			end
		end

		-- BRIEFING
		RoomServiceRef.setStage(ctx.sessionId, "Briefing")
		tell(ctx, { kind = "status", lines = {
			"All subjects successfully briefed.",
			"Likelyhood of subjects understanding briefing: 90%",
			"Likelyhood of subject survival: 20%",
			"Favorable gene mutation percentage: 0.5%",
			" ",
			"Bootstrapping next simulation ...",
			"Geometry cache 32/100",
		} })
		if not hold(ctx, 6.5) then return end

		-- TRIAL
		RoomServiceRef.setStage(ctx.sessionId, "Trial")
		local totals = {}
		local rounds = trial.roundsForPlayerCount(#ctx.participantUserIds)
		for roundIndex = 1, rounds do
			if ctx.cancelled() then return end
			tell(ctx, { kind = "round", n = roundIndex, total = rounds, verbs = trial.tagline })
			if not hold(ctx, 3) then return end
			tell(ctx, { kind = "hide" })
			setActiveTrial(ctx, trial.id)

			local scores
			if trial.id == "birdhunt" and #room.members >= 2 then
				-- Preserved verbatim from Phase 0: every participant is Hunter
				-- once per numbered round; the starting seat rotates.
				scores = {}
				local order = table.clone(room.members)
				local offset = (roundIndex - 1) % #order
				for leg = 1, #order do
					if ctx.cancelled() then break end
					local member = order[(offset + leg - 1) % #order + 1]
					local legOk, legScores = pcall(
						trial.module.runRound, room, roundIndex, member.userId, leg, #order)
					if legOk and type(legScores) == "table" then
						for uid, value in legScores do
							scores[uid] = (scores[uid] or 0) + value
						end
					elseif not legOk then
						error(legScores, 0)
					end
				end
			else
				local rOk, rScores = pcall(trial.module.runRound, room, roundIndex)
				if not rOk then error(rScores, 0) end
				scores = type(rScores) == "table" and rScores or {}
			end

			setActiveTrial(ctx, "")
			for uid, s in scores do
				totals[uid] = (totals[uid] or 0) + s
			end
			if not hold(ctx, 1.5) then return end

			if trial.showInterRoundScore and roundIndex < rounds then
				local standings = {}
				for _, m in room.members do
					table.insert(standings, {
						userId = m.userId,
						displayName = m.displayName,
						score = totals[m.userId] or 0,
					})
				end
				table.sort(standings, function(a, b) return a.score > b.score end)
				RoomServiceRef.setStage(ctx.sessionId, "Score")
				tell(ctx, { kind = "score", board = standings })
				if not hold(ctx, 5.5) then return end
				tell(ctx, { kind = "hide" })
				RoomServiceRef.setStage(ctx.sessionId, "Trial")
			end
		end

		if not hold(ctx, 3) then return end

		-- FINAL SCORE: the ranked cumulative board is the result. No separate
		-- winner banner.
		RoomServiceRef.setStage(ctx.sessionId, "FinalScore")
		local board = {}
		for _, m in room.members do
			table.insert(board, {
				userId = m.userId,
				displayName = m.displayName,
				score = totals[m.userId] or 0,
			})
			local plr = Players:GetPlayerByUserId(m.userId)
			if plr then
				plr:SetAttribute("KenopsiaSessionScore",
					(plr:GetAttribute("KenopsiaSessionScore") or 0) + (totals[m.userId] or 0))
			end
		end
		table.sort(board, function(a, b) return a.score > b.score end)
		if #board >= 2 and board[1].score > 0 and board[1].score > board[2].score then
			local winner = Players:GetPlayerByUserId(board[1].userId)
			if winner then
				winner:SetAttribute("KenopsiaSessionWins",
					(winner:GetAttribute("KenopsiaSessionWins") or 0) + 1)
			end
		end
		tell(ctx, { kind = "score", board = board })
		-- Scores are written and the board is out. The match is finished; the
		-- hold below is presentation only, so nothing after this point may
		-- downgrade the result.
		scoresCommitted = true
		if trial.module.park then pcall(trial.module.park) end
		hold(ctx, Config.Match.FinalBoardHold)
	end, debug.traceback)

	-- FINALIZER. Exactly one route out, for every outcome.
	cleanup()
	if not ok then
		outcome = "error"
	elseif outcome == "completed" and not scoresCommitted and ctx and ctx.cancelled() then
		-- hold() returns false on cancellation and the body returns cleanly,
		-- so `ok` is true for an aborted session. Detect it explicitly rather
		-- than mislabelling it "match complete".
		-- Gated on scoresCommitted: once the final board is out the match is
		-- finished, and someone quitting during the 12s presentation hold must
		-- not turn a played-out match into "cancelled".
		outcome = "cancelled"
	end

	if outcome == "error" then
		warn(("[MachineFlow] session %s failed: %s")
			:format(ctx and tostring(ctx.sessionId) or "<no-session>", tostring(err)))
		RoomServiceRef.abort(room, "TRIAL ERROR")
	elseif outcome == "no-trial" then
		RoomServiceRef.abort(room, "NO READY TRIAL")
	end

	-- Reached on every route, including no-trial and error, so the room can
	-- never be stranded in Aborting.
	RoomServiceRef.cleanupToWaiting(outcome)

	task.wait(0.4)
	if room.phase == "Waiting" and #room.members > 0 then
		room.preShown = true
		task.spawn(preFlow, room)
	else
		room.preShown = nil
	end
end

-- BOOT -----------------------------------------------------------------------
function MachineFlow.start(RoomService)
	RoomServiceRef = RoomService
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	Remote = folder:FindFirstChild("MachineState")
	if not Remote then
		Remote = Instance.new("RemoteEvent")
		Remote.Name = "MachineState"
		Remote.Parent = folder
	end

	-- init() every registered module, including not-ready ones: they create
	-- their remotes at boot so clients can WaitForChild them. A not-ready
	-- trial still never runs, because enabledTrials() filters it out.
	for _, t in TRIALS do
		if t.module.init then
			local ok, err = pcall(t.module.init)
			if not ok then
				warn(("[MachineFlow] %s init failed: %s"):format(t.id, tostring(err)))
			end
		end
	end

	RoomService.RunRequested:Connect(function(roomId)
		local room = RoomService.getRoom(roomId)
		if room then task.spawn(runMatch, room) end
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			if not workspace:GetAttribute("KenopsiaNoAuto") then
				for _, plr in Players:GetPlayers() do
					-- Hold new joiners out until the content warning has played.
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
							if t then
								Remote:FireClient(plr, {
									kind = "info", name = t.displayName,
									icon = t.icon, id = t.id,
								})
							end
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
		end
	end)

	local enabled = enabledTrials()
	local names = {}
	for _, t in enabled do table.insert(names, t.id) end
	print(("[MachineFlow] online - %d/%d trials ready (%s)")
		:format(#enabled, #TRIALS, table.concat(names, ", ")))
end

return MachineFlow
