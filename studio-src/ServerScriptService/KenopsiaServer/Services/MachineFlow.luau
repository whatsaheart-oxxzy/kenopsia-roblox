--!nonstrict
-- MATCH FLOW (Phase 1).
--
-- Owns everything inside RoomService's Playing phase:
--   Selecting -> Briefing -> Trial -> Score -> Final Score
-- and unwinds through a finally-style cleanup on either a clean finish or an
-- abort.
--
-- Gate 1 turns the single roulette-picked trial into a SESSION: every enabled
-- trial is played once, in a seed-shuffled order, with no return to the lobby
-- between them. The loop iterates #order rather than a hardcoded three, so it
-- runs two trials today and three the moment Canteen flips to ready = true at
-- Gate 4 -- with no change to this file.
--
-- The trial modules are still invoked with their EXISTING signatures. Threading
-- RoundContext into them belongs to Gates 2/3/4; here Contexts supplies the
-- tokens and the cleanup scopes, and a thin adapter feeds the old calls.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local BirdHunting = require(script.Parent.BirdHunting)
local Minefield = require(script.Parent.Minefield)
local CanteenProtocol = require(script.Parent.CanteenProtocol)
local Contexts = require(script.Parent.Contexts)

local Shared = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Pacing = require(Rules:WaitForChild("Pacing"))
local Playlist = require(Rules:WaitForChild("Playlist"))
local Scoring = require(Rules:WaitForChild("Scoring"))

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
		module = Minefield,
	},
	{
		-- REQ-CP-01/02 done: the arena markers exist under
		-- Workspace.CanteenProtocol.Rig (built by tools/build-canteen-arena.luau)
		-- and CanteenProtocol.validateArena() gates them. REQ-CP-03 (client HUD
		-- and input) and REQ-CP-04 (original audio and models) are outstanding,
		-- so ready STAYS false: the server mechanic below cannot be played
		-- without a client that can send `plate` and `mouth`.
		--
		-- The id is "canteen", NOT "tablemanners". "Table Manners" is the name
		-- the reference game uses for this minigame, and carrying it in the
		-- shipped source is the copyright exposure REQ-IP-01 exists to remove.
		-- Playlist.Ids agrees, and tests/rules.lua asserts that the old spelling
		-- is rejected so it cannot quietly come back.
		--
		-- TableManners.luau still exists on disk but is no longer required by
		-- anything, so its init() never runs, its beat handler never connects
		-- and the old rhythm mechanic is already unreachable at runtime. The
		-- file is deleted once this gate passes, per the plan.
		id = "canteen",
		displayName = "CANTEEN PROTOCOL",
		icon = "Saw",
		subtitle = "RATION ISSUED. EAT ONLY WHEN UNOBSERVED._",
		tagline = "FREEZE WHEN THE INSPECTOR LOOKS.",
		ready = false,
		showInterRoundScore = false,
		module = CanteenProtocol,
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

-- Session-level. effectScope is rewritten per trial by the loop, because FX
-- must be cleared per trial scope and never globally (REQ-DZ-03).
local function buildContext(room)
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
		effectScope = sessionId,
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

-- The trials this session will play, in seed-shuffled order.
--
-- Playlist.order permutes ALL THREE ids; the filter drops whatever is not
-- schedulable while preserving the shuffled relative order of the rest. That is
-- why the loop below needs no knowledge of how many trials exist: two survive
-- the filter today, three the moment Canteen passes Gate 4.
local function playableOrder(seed)
	local enabled = {}
	for _, t in enabledTrials() do
		enabled[t.id] = t
	end
	local out = {}
	for _, id in Playlist.order(seed) do
		local t = enabled[id]
		if t then table.insert(out, t) end
	end
	return out
end

local function runMatch(room)
	-- C2: every route - setup, no-trial, cancellation, completion and trial
	-- error - leaves through the single finalizer below. `outcome` is the one
	-- source of truth, so an aborted session is never logged as completed.
	local outcome = "completed" -- completed | cancelled | no-trial | error
	local ctx, session = nil, nil
	local activeTrial = nil
	local cleaned = false
	-- Latches once the SESSION has finished and its final board is out. It is
	-- deliberately NOT set per trial: a player leaving during trial 2 must still
	-- cancel the match, and only the final board makes the result immutable.
	local scoresCommitted = false

	-- Must be safe before ctx exists: the no-trial route reaches it too.
	local function cleanup()
		if cleaned then return end
		cleaned = true
		if ctx then
			setActiveTrial(ctx, "")
			if activeTrial and activeTrial.module.cleanup then
				pcall(activeTrial.module.cleanup, ctx)
			end
			for _, uid in ctx.participantUserIds do
				if activeByUser[uid] == ctx then activeByUser[uid] = nil end
			end
			if sessionsByRoomId[room.id] == ctx then
				sessionsByRoomId[room.id] = nil
			end
		end
		-- Cancelling the session runs every scope still open beneath it, so a
		-- round that was mid-flight when the match died cannot leave a delayed
		-- callback behind still holding a live context.
		if session then session:cancel() end
		room.preSent = nil
		tellRoom(room, { kind = "hide" })
	end

	local ok, err = xpcall(function()
		-- The server mints the seed. It is never taken from a client.
		local seed = math.random(1, 2147483647)
		local order = playableOrder(seed)
		if #order == 0 then
			warn("[MachineFlow] no ready trial at match start")
			outcome = "no-trial"
			return
		end

		ctx = buildContext(room)
		sessionsByRoomId[room.id] = ctx
		for _, uid in ctx.participantUserIds do
			activeByUser[uid] = ctx
		end
		session = Contexts.newSession(room.id, ctx.participantUserIds, seed)

		local playerCount = #ctx.participantUserIds
		print(("[MachineFlow] session %s seed=%d trials=%d players=%d")
			:format(tostring(ctx.sessionId), seed, #order, playerCount))

		-- C6: KenopsiaSessionScore/Wins are MATCH-scoped, not server-scoped.
		-- Zero them once here, for this match's participant snapshot.
		--
		-- THIS MUST STAY HERE, BEFORE THE TRIAL LOOP. The counters have to carry
		-- ACROSS the trials of one session -- that is what makes it a session
		-- score at all -- so moving this inside the loop would wipe trial 1's
		-- result the moment trial 2 begins. The Phase 1 comment flagged this as
		-- the thing to get right when the playlist arrived. This is that moment.
		for _, uid in ctx.participantUserIds do
			local plr = Players:GetPlayerByUserId(uid)
			if plr then
				plr:SetAttribute("KenopsiaSessionScore", 0)
				plr:SetAttribute("KenopsiaSessionWins", 0)
			end
		end

		local sessionTotals = {}
		for _, uid in ctx.participantUserIds do
			sessionTotals[uid] = 0
		end

		for trialIndex, trial in ipairs(order) do
			if ctx.cancelled() then return end

			local trialCtx = session:newTrial(trial.id, trialIndex, #order)
			activeTrial = trial
			ctx.effectScope = ("%s:%s"):format(ctx.sessionId, trial.id)

			-- SELECTING. Reveals which game is next. There is NO return to the
			-- lobby between trials: the room stays in Playing and only the stage
			-- moves, which is what makes the games read as one session.
			RoomServiceRef.setStage(ctx.sessionId, "Selecting")
			RoomServiceRef.setProgress(ctx.sessionId, {
				activeTrialId = trial.id,
				trialIndex = trialIndex,
				trialCount = #order,
				-- Cleared explicitly. A leg counter left over from Bird Hunting
				-- would otherwise be drawn over the next trial's HUD.
				roundIndex = RoomServiceRef.CLEAR,
				legIndex = RoomServiceRef.CLEAR,
				legCount = RoomServiceRef.CLEAR,
			})
			-- "info", NOT a new kind. The client dispatches on a fixed set --
			-- selection / info / status / round / score / announce / hide -- and
			-- an unknown kind renders NOTHING. The first cut of this loop sent
			-- "select" and the reveal was simply blank.
			--
			-- showInfo types the name out at ~26 chars/s, so the hold has to
			-- outlast the typewriter or the card disappears mid-word.
			tell(ctx, { kind = "info", id = trial.id, name = trial.displayName,
				icon = trial.icon, index = trialIndex, total = #order })
			if not hold(ctx, Pacing.Timing.Reveal) then return end

			-- BRIEFING
			RoomServiceRef.setStage(ctx.sessionId, "Briefing")
			tell(ctx, { kind = "status", lines = {
				trial.displayName,
				trial.tagline,
				" ",
				("Minigame %d of %d."):format(trialIndex, #order),
				"Bootstrapping simulation ...",
			} })
			if not hold(ctx, Pacing.Timing.ControlCard) then return end

			-- TRIAL
			RoomServiceRef.setStage(ctx.sessionId, "Trial")
			local isBird = trial.id == "birdhunt"
			-- Pacing owns this now. The registry used to hardcode 10 rounds for
			-- Dead Zone and 5 for Bird; both are named in the plan as errors not
			-- to repeat, and for Bird the number is LEGS, not rounds.
			local rounds = Pacing.roundsFor(trial.id, playerCount) or 1
			local trialTotals = {}

			for roundIndex = 1, rounds do
				if ctx.cancelled() then return end

				local roundCtx = trialCtx:newRound(roundIndex, rounds)
				RoomServiceRef.setProgress(ctx.sessionId, {
					roundIndex = roundIndex,
					roundCount = rounds,
				})

				tell(ctx, { kind = "round", n = roundIndex, total = rounds,
					verbs = trial.tagline })
				if not hold(ctx, Pacing.Timing.RoundCard) then return end
				tell(ctx, { kind = "hide" })
				setActiveTrial(ctx, trial.id)

				local scores
				if isBird and #room.members >= 2 then
					-- One LEG per iteration: each iteration is a full
					-- hunter-versus-runners exchange and the hunter seat
					-- advances. Pacing already sized `rounds` as the leg count
					-- (2p 4 / 3p 3 / 4p 4), so this is no longer 5 x playerCount.
					roundCtx:newLeg(roundIndex)
					RoomServiceRef.setProgress(ctx.sessionId, {
						legIndex = roundIndex, legCount = rounds,
					})
					local hunter = room.members[(roundIndex - 1) % #room.members + 1]
					local legOk, legScores = pcall(trial.module.runRound,
						room, roundIndex, hunter.userId, roundIndex, rounds)
					if not legOk then error(legScores, 0) end
					scores = type(legScores) == "table" and legScores or {}
				else
					local rOk, rScores = pcall(trial.module.runRound, room, roundIndex)
					if not rOk then error(rScores, 0) end
					scores = type(rScores) == "table" and rScores or {}
				end

				setActiveTrial(ctx, "")
				roundCtx.cleanup:run()
				for uid, value in scores do
					trialTotals[uid] = (trialTotals[uid] or 0) + value
				end
				if not hold(ctx, Pacing.Timing.RoundSettle) then return end
			end

			-- SCORE. A COMPLETED trial distributes exactly 1700, whatever the raw
			-- in-trial numbers happened to be. That is what makes the games
			-- comparable: a trial that awards large raw scores cannot outweigh
			-- the other two just by using bigger numbers.
			local entries = {}
			for _, uid in ctx.participantUserIds do
				table.insert(entries, { userId = uid, raw = trialTotals[uid] or 0 })
			end
			local ranking = Scoring.rankRound(entries, function(a, b)
				return a.raw > b.raw
			end)
			Scoring.distribute(ranking)

			local board = {}
			for _, r in ipairs(ranking) do
				local uid = r.entry.userId
				sessionTotals[uid] = (sessionTotals[uid] or 0) + r.points
				local plr = Players:GetPlayerByUserId(uid)
				if plr then
					plr:SetAttribute("KenopsiaSessionScore", sessionTotals[uid])
				end
				table.insert(board, {
					userId = uid,
					displayName = plr and plr.DisplayName or tostring(uid),
					place = r.place,
					points = r.points,
					score = sessionTotals[uid],
				})
			end

			RoomServiceRef.setStage(ctx.sessionId, "Score")
			tell(ctx, { kind = "score", board = board, trialId = trial.id,
				index = trialIndex, total = #order, final = false })
			if not hold(ctx, Pacing.Timing.InterimScore) then return end

			-- NO hide() here. Every show* on the client begins with hideAll(),
			-- so the next minigame's reveal replaces this board by itself. Hiding
			-- first only opened a gap in which the player stood in the empty
			-- world waiting -- which is precisely what the live run showed.

			-- Between trials, not only after the last one: whatever this trial
			-- parked in the world has to go before the next one builds in the
			-- same space.
			if trial.module.cleanup then pcall(trial.module.cleanup, ctx) end
			trialCtx:cancel()
			activeTrial = nil
		end

		-- FINAL SCORE. Highest cumulative total is VIABLE, everyone else
		-- REJECTED. Ties at the top are ALL viable: Scoring already shares tied
		-- places, and inventing a single winner here would contradict the board
		-- the players just watched.
		RoomServiceRef.setStage(ctx.sessionId, "FinalScore")
		local final = {}
		local best = -1
		for _, uid in ctx.participantUserIds do
			local total = sessionTotals[uid] or 0
			if total > best then best = total end
		end
		for _, uid in ctx.participantUserIds do
			local plr = Players:GetPlayerByUserId(uid)
			local total = sessionTotals[uid] or 0
			local viable = total == best
			if viable and plr then
				plr:SetAttribute("KenopsiaSessionWins",
					(plr:GetAttribute("KenopsiaSessionWins") or 0) + 1)
			end
			table.insert(final, {
				userId = uid,
				displayName = plr and plr.DisplayName or tostring(uid),
				score = total,
				verdict = viable and "VIABLE" or "REJECTED",
			})
		end
		table.sort(final, function(a, b) return a.score > b.score end)
		tell(ctx, { kind = "score", board = final, final = true })

		-- The board is out and the attributes are written. Nothing after this
		-- point may downgrade the result: the hold below is presentation only.
		scoresCommitted = true
		hold(ctx, Pacing.Timing.FinalScore)
	end, debug.traceback)

	-- FINALIZER. Exactly one route out, for every outcome.
	cleanup()
	if not ok then
		outcome = "error"
	elseif outcome == "completed" and not scoresCommitted and ctx and ctx.cancelled() then
		-- hold() returns false on cancellation and the body returns cleanly, so
		-- `ok` is true for an aborted session. Detect it explicitly rather than
		-- mislabelling it "match complete". Gated on scoresCommitted so that
		-- someone quitting during the final presentation hold cannot turn a
		-- played-out session into "cancelled".
		outcome = "cancelled"
	end

	if outcome == "error" then
		warn(("[MachineFlow] session %s failed: %s")
			:format(ctx and tostring(ctx.sessionId) or "<no-session>", tostring(err)))
		RoomServiceRef.abort(room, "MINIGAME ERROR")
	elseif outcome == "no-trial" then
		RoomServiceRef.abort(room, "NO READY MINIGAME")
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
