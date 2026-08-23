--!nonstrict
-- MATCH FLOW (Phase 1).
--
-- Owns everything inside RoomService's Playing phase:
--   Selecting -> Briefing -> Trial -> Score -> Final Score
-- and unwinds through a finally-style cleanup on either a clean finish or an
-- abort.
--
-- Gate 1 turns the single roulette-picked trial into a SESSION: enabled trials
-- are played once each, in a seed-shuffled order, with no return to the lobby
-- between them. The loop iterates #order rather than a hardcoded count, so it
-- runs however many ids survive the two gates -- and, since MP-05, at most
-- GameConfig.Playlist.PerSession of them (D7) -- with no change to this file.
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
-- MP-05: the twelve new trials (Framework-stage stubs until each implementer
-- fills its module in). Every one is required at boot so a missing file fails
-- loudly here, not mid-session.
local CutToSpec = require(script.Parent.CutToSpec)
local ArmsIssue = require(script.Parent.ArmsIssue)
local Upstream = require(script.Parent.Upstream)
local FloorCheck = require(script.Parent.FloorCheck)
local Clearance = require(script.Parent.Clearance)
local Carrier = require(script.Parent.Carrier)
local Breather = require(script.Parent.Breather)
local ClearTheDeck = require(script.Parent.ClearTheDeck)
local Crawler = require(script.Parent.Crawler)
local Ricochet = require(script.Parent.Ricochet)
local PalletDuty = require(script.Parent.PalletDuty)
local SortingFloor = require(script.Parent.SortingFloor)
-- P1.3 podium beat / P1.7 bench camera (23.08.2026). Both are presentation:
-- every call below is pcall-wrapped so a missing arena or rig can never turn a
-- played-out session into "MINIGAME ERROR".
local Podium = require(script.Parent.Podium)
local AudienceCam = require(script.Parent.AudienceCam)

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
		-- The id is "canteen". The reference game's name for this minigame is
		-- the copyright exposure REQ-IP-01 exists to remove, so it appears
		-- nowhere in shipped source -- not in ids, not in UI text, and not in
		-- comments like this one. Playlist.Ids agrees, and tests/rules.lua
		-- asserts the old spelling is rejected so it cannot quietly come back.
		id = "canteen",
		displayName = "CANTEEN PROTOCOL",
		icon = "Saw",
		subtitle = "RATION ISSUED. EAT ONLY WHEN UNOBSERVED._",
		tagline = "FREEZE WHEN THE INSPECTOR LOOKS.",
		-- The session becomes THREE minigames here. Both gates flip together:
		-- this flag and the "canteen" entry in Config.Playlist.TrialIds. The
		-- loop itself is unchanged -- it has iterated #order since Gate 1 and
		-- simply now receives three.
		--
		-- validateArena() still gates every round independently: a broken or
		-- missing rig makes runRound warn and return zeros rather than drop a
		-- player into an arena that is not there.
		ready = true,
		showInterRoundScore = false,
		module = CanteenProtocol,
	},
	-- MP-05 -- the twelve new trials (docs/MP-05-BUILD-PLAN.md section A).
	-- ready = false for every one until its Integrate/QA pass flips it, one
	-- trial at a time. Ids and display names are original (REQ-IP-01); the
	-- reference names live in docs/ only. Text is the plan's, verbatim.
	{
		id = "carve",
		displayName = "CUT TO SPEC",
		icon = "Cube",
		subtitle = "MATCH THE TEMPLATE. THE BLOCK IS NOT FORGIVING._",
		tagline = "CUT ONLY WHAT IS SHOWN.",
		ready = false,
		showInterRoundScore = false,
		module = CutToSpec,
	},
	{
		id = "armory",
		displayName = "ARMS ISSUE",
		icon = "Crosshair",
		subtitle = "PARTS ARE ON THE FLOOR. THE ISSUE IS NOT._",
		tagline = "COLLECT. ASSEMBLE. DISCHARGE.",
		ready = false,
		showInterRoundScore = false,
		module = ArmsIssue,
	},
	{
		id = "upstream",
		displayName = "UPSTREAM",
		icon = "Factory",
		subtitle = "THE STAIRS RUN DOWN. YOU RUN UP._",
		tagline = "READ THE ARROWS. CLIMB.",
		ready = false,
		showInterRoundScore = false,
		module = Upstream,
	},
	{
		id = "floorcheck",
		displayName = "FLOOR CHECK",
		icon = "Cube",
		subtitle = "ONE PLATE HOLDS. THE REST GIVE WAY._",
		tagline = "STAND WHERE YOU ARE TOLD.",
		ready = false,
		showInterRoundScore = false,
		module = FloorCheck,
	},
	{
		id = "clearance",
		displayName = "CLEARANCE",
		icon = "Train",
		subtitle = "THE LINE IS LIVE. FIND YOUR RECESS._",
		tagline = "OFF THE TRACK BEFORE THE HORN.",
		ready = false,
		showInterRoundScore = false,
		module = Clearance,
	},
	{
		id = "carrier",
		displayName = "CARRIER",
		icon = "Bug",
		subtitle = "ONE OF YOU IS ALREADY SICK._",
		tagline = "FIND THE NEEDLE. OR AVOID IT.",
		ready = false,
		showInterRoundScore = false,
		module = Carrier,
	},
	{
		id = "breather",
		displayName = "BREATHER",
		icon = "Factory",
		subtitle = "ONE CIGARETTE. THIRTY SECONDS. NOTHING ELSE._",
		tagline = "INHALE. NOT TOO DEEP.",
		ready = false,
		showInterRoundScore = false,
		module = Breather,
	},
	{
		id = "sweep",
		displayName = "CLEAR THE DECK",
		icon = "Saw",
		subtitle = "THE PRESS ONLY WAITS FOR WEIGHT._",
		tagline = "KEEP YOUR PLATE CLEAN.",
		ready = false,
		showInterRoundScore = false,
		module = ClearTheDeck,
	},
	{
		id = "crawler",
		displayName = "CRAWLER",
		icon = "Bug",
		subtitle = "IT WANTS A BACK TO BREAK._",
		tagline = "DODGE IT. OR PASS IT ON.",
		ready = false,
		showInterRoundScore = false,
		module = Crawler,
	},
	{
		id = "ricochet",
		displayName = "RICOCHET",
		icon = "Saw",
		subtitle = "THE BLADES DO NOT STOP AT WALLS._",
		tagline = "WATCH THE ANGLES.",
		ready = false,
		showInterRoundScore = false,
		module = Ricochet,
	},
	{
		id = "stacker",
		displayName = "PALLET DUTY",
		icon = "Factory",
		subtitle = "TWENTY SECONDS. STACK HIGH. DO NOT DROP._",
		tagline = "HIGHEST STACK KEEPS THE JOB.",
		ready = false,
		showInterRoundScore = false,
		module = PalletDuty,
	},
	{
		id = "sorting",
		displayName = "SORTING FLOOR",
		icon = "Magnifier",
		subtitle = "GOOD LEFT. BAD RIGHT. NO EXCEPTIONS._",
		tagline = "MISFILE AND YOU FOLLOW IT.",
		ready = false, -- built and verified 23.08.2026; held back until after release (user call: three trials first)
		showInterRoundScore = false,
		module = SortingFloor,
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

-- P1.7: the bench (room.spectators, late joiners held out of the match). The
-- ONLY packets that go here are the Machine's own cameras - the audience view
-- of a running trial and the podium - never trial traffic (MP-01 section 7.3).
local function tellBench(room, payload)
	if not Remote then return end
	for userId in pairs(room.spectators or {}) do
		local plr = Players:GetPlayerByUserId(userId)
		if plr then Remote:FireClient(plr, payload) end
	end
end

-- Trial begin / end hooks for the bench camera. nil trialId = clear.
local function benchCamera(room, trialId)
	local ok, packet = pcall(function()
		return trialId and AudienceCam.packetFor(trialId) or AudienceCam.clearPacket()
	end)
	if ok and packet then tellBench(room, packet) end
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
	-- 22.08.2026 (P1.1): the lobby reveal IS the first trial of the session it
	-- precedes. The seed is minted here and runMatch consumes it, so the
	-- roulette can no longer contradict what starts ten seconds later.
	local seed = math.random(1, 2147483647)
	room.pendingSeed = seed
	local enabledById = {}
	for _, t in pool do enabledById[t.id] = t end
	local firstId = Playlist.arrange(Playlist.session(Playlist.order(seed), enabledById, Config.Playlist.PerSession))[1]
	local trial = enabledById[firstId] or pool[math.random(#pool)]
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
	-- P0.3: the roulette hold lives in Pacing.Timing.LobbyReveal (6.4 s), not here.
	task.wait(Pacing.Timing.LobbyReveal or 6.4)
	if room.phase ~= "Waiting" or #room.members == 0 then return end
	tellRoom(room, {
		kind = "info",
		name = trial.displayName,
		icon = trial.icon,
		id = trial.id,
	})
	room.preSent = room.preSent or {}
	for _, m in room.members do room.preSent[m.userId] = true end

	-- P1.7 rematch: carry the last verdict's readiness forward, after a grace
	-- in which anyone can walk away (or un-ready once the flag is on).
	local rematch = room.rematch
	room.rematch = nil
	if rematch and os.clock() < rematch.until_ then
		task.wait(Config.Match.RematchGrace or 6)
		if room.phase ~= "Waiting" or room.token ~= waitingToken then return end
		RoomServiceRef.carryReady(rematch.userIds)
	end
end

-- MATCH ----------------------------------------------------------------------

-- The trials this session will play, in seed-shuffled order.
--
-- Playlist.order permutes ALL ids in Playlist.Ids; Playlist.session drops
-- whatever is not schedulable while preserving the shuffled relative order of
-- the rest, and (D7) keeps only the first GameConfig.Playlist.PerSession of the
-- survivors. That is why the loop below needs no knowledge of how many trials
-- exist: three survive both gates today, up to PerSession once the MP-05
-- trials flip ready.
-- P1.2 standings card: rank by this trial's running raw key, with a rise/fall
-- mark against the previous round. Rendered by the client's Status screen, so
-- no new packet kind is needed. Machine voice: uppercase, no punctuation games.
local function standingsLines(ctx, totals, roundIndex, rounds, prevRank)
	local entries = {}
	for _, uid in ctx.participantUserIds do
		table.insert(entries, { userId = uid, raw = totals[uid] or 0 })
	end
	local ranking = Scoring.rankRound(entries, function(a, b) return a.raw > b.raw end)
	local lines = { ("STANDINGS - ROUND %d/%d"):format(roundIndex, rounds) }
	for _, r in ipairs(ranking) do
		local uid = r.entry.userId
		local plr = Players:GetPlayerByUserId(uid)
		local name = string.upper(plr and plr.DisplayName or tostring(uid)):sub(1, 14)
		local was = prevRank[uid]
		local mark = (was == nil or was == r.place) and "" or (r.place < was and "  UP" or "  DOWN")
		prevRank[uid] = r.place
		table.insert(lines, ("%d. %s%s"):format(r.place, name, mark))
	end
	return lines
end

local function playableOrder(seed)
	local enabled = {}
	for _, t in enabledTrials() do
		enabled[t.id] = t
	end
	local out = {}
	for _, id in Playlist.arrange(Playlist.session(Playlist.order(seed), enabled, Config.Playlist.PerSession)) do
		table.insert(out, enabled[id])
	end
	return out
end

-- P1.6 round watchdog. MachineFlow never bounded a round; a trial that hung
-- hung the whole match. The round runs on its own thread and is cancelled at
-- RoundSeconds + overhead + grace; the trial then ends early with the totals
-- it has and the session goes on.
local ROUND_OVERHEAD = 15
local ROUND_GRACE = 20
local function runRoundGuarded(trial, ...)
	local args = table.pack(...)
	local budget = (Pacing.RoundSeconds[trial.id] or 90) + ROUND_OVERHEAD + ROUND_GRACE
	local done, ok, result = false, true, nil
	local thread = task.spawn(function()
		ok, result = pcall(trial.module.runRound, table.unpack(args, 1, args.n))
		done = true
	end)
	local deadline = os.clock() + budget
	while not done and os.clock() < deadline do task.wait(0.1) end
	if not done then
		pcall(task.cancel, thread)
		warn(("[MachineFlow] %s round exceeded %.0f s - cut by the watchdog"):format(trial.id, budget))
		return false, "timeout"
	end
	return ok, result
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
		room.waitTold = nil
		tellRoom(room, { kind = "hide" })
		-- P1.7: whatever route brought us here, the bench gets its camera back.
		benchCamera(room, nil)
	end

	local ok, err = xpcall(function()
		-- The server mints the seed. It is never taken from a client.
		local seed = room.pendingSeed or math.random(1, 2147483647)
		room.pendingSeed = nil
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
			-- P1.3: the last trial of a multi-trial session is the FINAL AUDIT and
			-- pays double, so the session is open until its last minute.
			local isFinal = trialIndex == #order and #order > 1

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
				isFinal and "FINAL AUDIT. DOUBLE WEIGHT." or ("Minigame %d of %d."):format(trialIndex, #order),
				"Bootstrapping simulation ...",
			} })
			if not hold(ctx, Pacing.Timing.ControlCard) then return end

			-- TRIAL
			RoomServiceRef.setStage(ctx.sessionId, "Trial")
			-- P1.7: the bench watches this arena from its fixed audience camera
			-- for the whole trial (late joiners seated mid-trial get it from
			-- the boot watchdog below, keyed on the same stage).
			benchCamera(room, trial.id)
			local isBird = trial.id == "birdhunt"
			-- Pacing owns this now. The registry used to hardcode 10 rounds for
			-- Dead Zone and 5 for Bird; both are named in the plan as errors not
			-- to repeat, and for Bird the number is LEGS, not rounds.
			local rounds = Pacing.roundsFor(trial.id, playerCount)
			if not rounds then
				-- MP-01 section 9.2: a missing Pacing row used to become 1 round
				-- silently. It is still 1 round, but never silently.
				warn(("[MachineFlow] no Pacing.ROUNDS row for '%s' - playing 1 round"):format(trial.id))
				rounds = 1
			end
			local trialTotals = {}
			local prevRank = {}
			local timedOut = false

			for roundIndex = 1, rounds do
				if ctx.cancelled() then return end

				local roundCtx = trialCtx:newRound(roundIndex, rounds)
				RoomServiceRef.setProgress(ctx.sessionId, {
					roundIndex = roundIndex,
					roundCount = rounds,
				})

				tell(ctx, { kind = "round", n = roundIndex, total = rounds,
					verbs = isFinal and ("FINAL AUDIT. " .. trial.tagline) or trial.tagline })
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
					local legOk, legScores = runRoundGuarded(trial,
						room, roundIndex, hunter.userId, roundIndex, rounds)
					if not legOk then
						if legScores == "timeout" then timedOut = true else error(legScores, 0) end
					end
					scores = type(legScores) == "table" and legScores or {}
				else
					local rOk, rScores = runRoundGuarded(trial, room, roundIndex)
					if not rOk then
						if rScores == "timeout" then timedOut = true else error(rScores, 0) end
					end
					scores = type(rScores) == "table" and rScores or {}
				end

				setActiveTrial(ctx, "")
				roundCtx.cleanup:run()
				for uid, value in scores do
					trialTotals[uid] = (trialTotals[uid] or 0) + value
				end
				if timedOut then break end
				if roundIndex < rounds then
					-- P1.2: who is winning, after every round - not once per trial.
					tell(ctx, { kind = "status", lines = standingsLines(ctx, trialTotals, roundIndex, rounds, prevRank) })
					if not hold(ctx, Pacing.Timing.Standings or 2.5) then return end
				end
				if not hold(ctx, Pacing.Timing.RoundSettle) then return end
			end
			-- P1.7: the trial is over for the bench too.
			benchCamera(room, nil)

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
			Scoring.distribute(ranking, isFinal and 2 or 1)

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

		-- P1.7 rematch: the verdict's subjects come back pre-readied (preFlow
		-- applies it after the next lobby reveal, with a grace to walk away).
		local rematchIds = {}
		for _, uid in ctx.participantUserIds do rematchIds[uid] = true end
		room.rematch = { userIds = rematchIds, until_ = os.clock() + 60 }

		-- The board is out and the attributes are written. Nothing after this
		-- point may downgrade the result: the holds below are presentation only.
		scoresCommitted = true
		if not hold(ctx, Pacing.Timing.FinalScore) then return end

		-- P1.3 PODIUM (MASTERPLAN section 2: stamp 6 s + podium 8 s). The top
		-- three stand on the blocks; the room AND the bench get the fixed
		-- camera. pcall-wrapped: a failed stage is a skipped beat, never an
		-- aborted session. strike() runs on every route out of the hold.
		local okRaise, stage = pcall(Podium.raise, final, Pacing.Timing.Podium)
		if okRaise and stage then
			tellRoom(room, stage.packet)
			tellBench(room, stage.packet)
			hold(ctx, Pacing.Timing.Podium or 8)
			pcall(Podium.strike, stage)
			local clear = { kind = "podium" }
			tellRoom(room, clear)
			tellBench(room, clear)
		elseif not okRaise then
			warn(("[MachineFlow] podium skipped: %s"):format(tostring(stage)))
		end
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
					-- perf (22.08.2026): seat() broadcasts the whole RoomState; members are
					-- left alone, only the unseated and the bench (promotion) go through it.
					if os.clock() - plr:GetAttribute("KenopsiaJoinedAt") > 7 and not RoomServiceRef.isMember(plr) then
						RoomServiceRef.autoSeat(plr)
					end
					local room = RoomServiceRef.roomOf(plr)
					-- P1.7: a bench seat is not a blank world. Tell the late joiner
					-- what is running and that the next cycle takes them (F-09).
					if room and room.phase == "Playing" and room.spectators[plr.UserId] then
						local stamp = tostring(room.activeTrialId) .. ":" .. tostring(room.trialIndex)
						room.waitTold = room.waitTold or {}
						if room.waitTold[plr.UserId] ~= stamp then
							room.waitTold[plr.UserId] = stamp
							local t = trialById(room.activeTrialId)
							Remote:FireClient(plr, { kind = "status", lines = {
								"A CYCLE IS IN PROGRESS.",
								t and ("TRIAL %d OF %d: %s"):format(room.trialIndex or 0, room.trialCount or 0, t.displayName)
									or "SUBJECTS UNDER TEST.",
								" ",
								"YOU ARE ON THE BENCH.",
								"THE NEXT CYCLE TAKES YOU.",
							} })
							-- P1.7: seated mid-trial, so the begin hook already
							-- fired without them - hand them the camera now.
							if room.stage == "Trial" then
								local ok, packet = pcall(AudienceCam.packetFor, room.activeTrialId)
								if ok and packet then Remote:FireClient(plr, packet) end
							end
						end
					end
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
