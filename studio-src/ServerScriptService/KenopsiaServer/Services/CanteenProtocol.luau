--!nonstrict
-- CANTEEN PROTOCOL (Gate 4) -- eat everything on your plate without being seen.
--
-- This REPLACES the TableManners rhythm prototype; it does not repair it. The
-- old mechanic was "press on the beat". This one is a hiding game: the food is
-- free, the swallowing is what kills you.
--
-- MECHANIC
--   All players eat at the same time, each at their own plate. 16 peas. The
--   fork carries at most 4. Two actions:
--     PLATE  plate -> fork, loads up to the remaining capacity. ALWAYS SAFE.
--     MOUTH  fork -> mouth, consumes the WHOLE load. Detectable.
--   An empty fork to the mouth is a harmless miss -- it costs the cooldown and
--   nothing else, so mashing MOUTH is self-punishing rather than forbidden.
--
-- THE OBSERVER IS ENTIRELY SERVER-SIDE.
--   hidden 2.0-4.0s -> lowering 0.35s -> watching 0.9-1.8s -> raising 0.30s
--   The client is TOLD the phase so it can draw a warning; it never decides
--   whether anyone was seen. A client that lies about the phase changes what
--   its player sees on screen and nothing else.
--
-- WHY `lowering` EXISTS: it is the tell. Without a visible wind-up the observer
-- is a coin flip and the player has no decision to make. 0.35 s is enough to
-- abort a swallow you have not started and not enough to save one you have.
--
-- Arena markers come from `Workspace.CanteenProtocol.Rig`, built by
-- `tools/build-canteen-arena.luau`. Nothing here reads the room's dressing --
-- in particular not the eight `Plate` cylinders, whose child order is not a
-- contract. `validateArena()` gates the whole trial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodFX = require(script.Parent.BloodFX)
local CanteenProps = require(script.Parent.CanteenProps)
local Pacing = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("Pacing"))

local CanteenProtocol = {}

local ROUND_TIME = Pacing.RoundSeconds.canteen or 45

local PEAS_TOTAL = 16
local FORK_CAPACITY = 4

-- Server-side minimum intervals. These are the rate limit, not a rhythm: they
-- exist so a macro cannot empty a plate in one frame, and they are checked on
-- the SERVER clock so a client cannot argue about them.
local MIN_PLATE_INTERVAL = 0.16
local MIN_MOUTH_INTERVAL = 0.35

-- How long a swallow stays detectable. An eating window that overlaps the
-- watching phase AT ANY POINT is caught, so committing to a mouthful just
-- before the observer drops is fatal -- which is the decision the game is made
-- of.
local EAT_WINDOW = 0.45

local HIDDEN_MIN, HIDDEN_MAX = 2.0, 4.0
local LOWERING_TIME = 0.35
local WATCH_MIN, WATCH_MAX = 0.9, 1.8
local RAISING_TIME = 0.30

-- RANKING BANDS. runRound returns one ordering key per player and MachineFlow
-- sums those across rounds, then ranks and distributes exactly 1700. The bands
-- encode the plan's order: finished > alive-unfinished > eliminated.
--
-- The separation is arithmetic, not hope:
--   eliminated  0    + eaten*50 (max 15 -> 750) + survived*2 (max 45 -> 90) = 840
--   alive       1000 + eaten*50 (max 15 -> 750)                             = 1750
--   finished    2000 + spare*10 (max 45 -> 450)                             = 2450
-- 15 is the ceiling for both lower bands because eating the 16th pea IS
-- finishing. 840 < 1000 and 1750 < 2000, so no band can ever reach into the one
-- above it.
local ELIMINATED_BAND = 0
local ALIVE_BAND = 1000
local FINISHED_BAND = 2000
local PEA_STEP = 50
local FINISH_SPEED_STEP = 10
local SURVIVAL_STEP = 2

-- cos(40 degrees). Roblox's default FOV is 70, so the half-angle is 35 vertical
-- and wider horizontally; 40 keeps the Observer on screen from any seat without
-- demanding it sit dead centre.
local MIN_OBSERVER_COSINE = 0.766

local SEAT_IDS = { "P1", "P2", "P3", "P4" }
local MARKER_GROUPS = {
	{ folder = "Seats", key = "seats" },
	{ folder = "PlateAnchors", key = "plates" },
	{ folder = "ForkAnchors", key = "forks" },
	{ folder = "MouthTargets", key = "mouths" },
	{ folder = "PlayerCameras", key = "cams" },
	{ folder = "ExecutionMuzzles", key = "muzzles" },
}
local SOLO_MARKERS = { "Observer", "ObserverCamera", "SpectatorCamera" }

local current = nil
local TrialInput

-- ARENA --------------------------------------------------------------------

local cachedArena = nil

local function arena()
	-- IsDescendantOf(workspace), not `rig.Parent`. A rig detached from the
	-- world still has a parent chain for a while, and rebuilding it destroys
	-- these instances -- a destroyed part errors on every property read rather
	-- than returning nil. This is the stricter of the two tests.
	if cachedArena and cachedArena.rig:IsDescendantOf(workspace) then
		return cachedArena
	end
	cachedArena = nil

	local root = workspace:FindFirstChild("CanteenProtocol")
	local rig = root and root:FindFirstChild("Rig")
	if not rig then return nil end

	local a = { root = root, rig = rig }
	for _, group in ipairs(MARKER_GROUPS) do
		local folder = rig:FindFirstChild(group.folder)
		if not folder then return nil end
		local list = {}
		for i, id in ipairs(SEAT_IDS) do
			local m = folder:FindFirstChild(id)
			if not (m and m:IsA("BasePart")) then return nil end
			list[i] = m
		end
		a[group.key] = list
	end
	for _, name in ipairs(SOLO_MARKERS) do
		local m = rig:FindFirstChild(name)
		if not (m and m:IsA("BasePart")) then return nil end
		a[name] = m
	end

	cachedArena = a
	return a
end

-- The gate. `ready` stays false until this passes, so a half-built arena can
-- never reach a player: it returns the FIRST reason it fails rather than a
-- bare false, because "arena invalid" in a log tells nobody which marker to go
-- and place.
function CanteenProtocol.validateArena()
	local root = workspace:FindFirstChild("CanteenProtocol")
	if not root then return false, "Workspace.CanteenProtocol is missing" end
	if not root:FindFirstChild("Rig") then
		return false, "Rig folder missing - run tools/build-canteen-arena.luau"
	end

	-- Drop the cache before validating. The gate must never pass on a snapshot:
	-- caught by a negative test, removing a seat marker left the cached entry
	-- pointing at a still-valid but UNPARENTED part, and validateArena happily
	-- returned true for an arena that no longer had that seat in it. A gate that
	-- only ever confirms what it already believes is not a gate.
	cachedArena = nil
	local a = arena()
	if not a then
		return false, "Rig is incomplete - re-run tools/build-canteen-arena.luau"
	end

	-- Every marker must still hang in the rig. Resolving them is not enough:
	-- FindFirstChild returns the live child, but a marker reparented elsewhere
	-- in the world would resolve for some other lookup and place a player
	-- somewhere nobody built.
	for _, group in ipairs(MARKER_GROUPS) do
		for i, id in ipairs(SEAT_IDS) do
			if not a[group.key][i]:IsDescendantOf(a.rig) then
				return false, ("%s.%s is detached from the Rig"):format(group.folder, id)
			end
		end
	end
	for _, name in ipairs(SOLO_MARKERS) do
		if not a[name]:IsDescendantOf(a.rig) then
			return false, ("%s is detached from the Rig"):format(name)
		end
	end

	-- A marker that answers raycasts would silently break the observer's line
	-- of sight and every future hit test in this arena.
	for _, d in ipairs(a.rig:GetDescendants()) do
		if d:IsA("BasePart") and (d.CanQuery or d.CanCollide) then
			return false, ("marker %s is raycast/collision visible"):format(d.Name)
		end
	end

	for i, id in ipairs(SEAT_IDS) do
		local seat, plate, mouth = a.seats[i], a.plates[i], a.mouths[i]

		-- NaN never equals itself. A degenerate CFrame.lookAt produces exactly
		-- this and every downstream position becomes garbage, so it is checked
		-- here rather than discovered as a player teleporting to nowhere.
		if seat.Position.X ~= seat.Position.X then
			return false, ("seat %s has a non-finite CFrame"):format(id)
		end

		if mouth.Position.Y <= plate.Position.Y then
			return false, ("%s mouth (%.2f) is not above its plate (%.2f)")
				:format(id, mouth.Position.Y, plate.Position.Y)
		end

		local flat = Vector3.new(1, 0, 1)
		local reach = ((seat.Position - plate.Position) * flat).Magnitude
		if reach < 2 or reach > 24 then
			return false, ("%s is %.1f studs from its plate - not a seat at this table"):format(id, reach)
		end

		local toPlate = ((plate.Position - seat.Position) * flat).Unit
		if seat.CFrame.LookVector:Dot(toPlate) < 0.9 then
			return false, ("%s does not face its own plate"):format(id)
		end

		for j = i + 1, #SEAT_IDS do
			if (a.seats[j].Position - seat.Position).Magnitude < 4 then
				return false, ("seats %s and %s occupy the same place"):format(id, SEAT_IDS[j])
			end
		end
	end

	-- The observer must actually SEE the eaters. A marker aimed into a wall
	-- passes every name-and-count check and makes the whole minigame unlosable.
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { a.rig }
	for i, id in ipairs(SEAT_IDS) do
		local target = a.mouths[i].Position
		local hit = workspace:Raycast(a.Observer.Position, target - a.Observer.Position, rp)
		if hit and (target - hit.Position).Magnitude > 3.5 then
			return false, ("Observer cannot see %s - blocked by %s"):format(id, hit.Instance.Name)
		end
	end

	-- And the PLAYER must be able to see their own plate. This check was
	-- missing, and the first screenshot from a player camera came back as a
	-- brown blur: the cameras were placed by fixed offsets from the seat and
	-- ended up INSIDE the chair backrests, which are 16 studs tall. A camera
	-- that renders the inside of a chair passes every name, count and distance
	-- check ever written.
	for i, id in ipairs(SEAT_IDS) do
		local eye = a.cams[i].Position
		local target = a.plates[i].Position
		local hit = workspace:Raycast(eye, target - eye, rp)
		if hit and (target - hit.Position).Magnitude > 3.5 then
			return false, ("%s camera cannot see its plate - blocked by %s"):format(id, hit.Instance.Name)
		end

		-- And the Observer must be ON SCREEN from that camera. This is the
		-- check that the first player-view screenshot forced: with the Observer
		-- parked past the head of the table the angle was ~57 degrees, outside
		-- a 70-degree FOV. Every other check passed and the tell was invisible.
		-- MAX_OBSERVER_ANGLE is deliberately tighter than the half-FOV so the
		-- warning is comfortably in view rather than clipping the edge.
		local toObserver = (a.Observer.Position - eye).Unit
		local cosAngle = a.cams[i].CFrame.LookVector:Dot(toObserver)
		if cosAngle < MIN_OBSERVER_COSINE then
			return false, ("%s cannot see the Observer - %.0f degrees off screen"):format(
				id, math.deg(math.acos(math.clamp(cosAngle, -1, 1))))
		end
	end

	return true
end

-- HELPERS ------------------------------------------------------------------

local function livingOf(room)
	local out = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		local char = plr and plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if plr and char and hum and rootPart and hum.Health > 0 then
			out[mm.userId] = { player = plr, char = char, hum = hum, root = rootPart }
		end
	end
	return out
end

local function remotes()
	return ReplicatedStorage.Kenopsia:FindFirstChild("Remotes")
end

local function announce(room, payload)
	local folder = remotes()
	local MachineState = folder and folder:FindFirstChild("MachineState")
	if not MachineState then return end
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then MachineState:FireClient(plr, payload) end
	end
end

local function tellOne(userId, payload)
	local folder = remotes()
	local MachineState = folder and folder:FindFirstChild("MachineState")
	local plr = Players:GetPlayerByUserId(userId)
	if MachineState and plr then MachineState:FireClient(plr, payload) end
end

local function pushState(st, userId)
	local ps = st.state[userId]
	if not ps then return end
	-- The props ARE the readout. The payload below is the future client HUD's
	-- copy; if it never arrives, the plate and the fork still show the truth.
	if st.props and ps.seat then
		st.props.setPeas(ps.seat, ps.remaining)
		st.props.setFork(ps.seat, ps.fork)
	end
	tellOne(userId, {
		kind = "cpstate",
		peas = ps.remaining,
		fork = ps.fork,
		capacity = FORK_CAPACITY,
		total = PEAS_TOTAL,
		eaten = ps.eaten,
	})
end

-- ELIMINATION ---------------------------------------------------------------

local function eliminate(st, userId, reason)
	local ps = st.state[userId]
	if not ps or ps.finished or ps.eliminated then return end
	ps.eliminated = true
	ps.eliminatedAt = os.clock() - st.startedAt
	ps.fork = 0

	local subject = st.subjects[userId]
	if subject and subject.char and subject.hum and subject.hum.Health > 0 then
		-- The body STAYS at the table: seeing the empty chairs fill up with the
		-- caught is the pressure the round runs on. It is cleaned up with
		-- everything else when the round ends.
		BloodFX.bleed(subject.char, st.audience, st.roundToken)
		subject.hum.Health = 0
	end

	tellOne(userId, { kind = "cpout", reason = reason })
	announce(st.room, { kind = "announce", style = "death",
		text = ("PROTOCOL VIOLATION - %s"):format(
			(Players:GetPlayerByUserId(userId) and Players:GetPlayerByUserId(userId).DisplayName) or "SUBJECT") })
end

-- OBSERVER ------------------------------------------------------------------

local function setPhase(st, phase, duration)
	st.phase = phase
	st.phaseEndsAt = os.clock() + duration
	-- The Observer physically descends. That is the tell -- readable with the
	-- eyes, needing no client code and impossible for a client to hide from
	-- itself.
	if st.props then st.props.observerTo(phase, duration) end
	announce(st.room, { kind = "cpobs", phase = phase, dur = duration })
end

-- Anyone still mid-swallow when the eyes open is caught. This is the half of
-- the rule the input handler cannot see: the action already happened.
local function sweep(st)
	local now = os.clock()
	for userId, ps in st.state do
		if not (ps.finished or ps.eliminated) and now < (ps.eatUntil or 0) then
			eliminate(st, userId, "seen")
		end
	end
end

local function sleepWhileActive(st, duration)
	local deadline = os.clock() + duration
	while os.clock() < deadline do
		if not st.active then return false end
		task.wait(0.05)
	end
	return st.active
end

local function runObserver(st)
	local rng = Random.new()
	while st.active do
		if not sleepWhileActive(st, rng:NextNumber(HIDDEN_MIN, HIDDEN_MAX)) then break end
		setPhase(st, "lowering", LOWERING_TIME)
		if not sleepWhileActive(st, LOWERING_TIME) then break end

		local watchTime = rng:NextNumber(WATCH_MIN, WATCH_MAX)
		setPhase(st, "watching", watchTime)
		sweep(st)
		if not sleepWhileActive(st, watchTime) then break end

		setPhase(st, "raising", RAISING_TIME)
		if not sleepWhileActive(st, RAISING_TIME) then break end
		setPhase(st, "hidden", HIDDEN_MIN)
	end
end

-- INPUT ---------------------------------------------------------------------

local function handleAction(player, action)
	local st = current
	if not st then return end
	if not st.acceptInput then return end
	-- The same freshness chain Dead Zone uses: phase, session snapshot and the
	-- round token together mean a packet from an earlier round cannot land in
	-- a later one.
	if not st.room or st.room.phase ~= "Playing" then return end
	if st.room.sessionId ~= st.sessionId then return end

	local ps = st.state[player.UserId]
	-- A finished player is SAFE and silent: no further input can un-finish them
	-- or get them caught after the fact.
	if not ps or ps.finished or ps.eliminated then return end

	local now = os.clock()

	if action == "plate" then
		if now < (ps.nextPlateAt or 0) then return end
		ps.nextPlateAt = now + MIN_PLATE_INTERVAL
		-- Loading is ALWAYS safe -- the observer only ever catches a swallow.
		local space = FORK_CAPACITY - ps.fork
		if space <= 0 or ps.remaining <= 0 then return end
		local take = math.min(space, ps.remaining)
		ps.fork = ps.fork + take
		ps.remaining = ps.remaining - take
		pushState(st, player.UserId)
		return
	end

	if action ~= "mouth" then return end
	if now < (ps.nextMouthAt or 0) then return end
	ps.nextMouthAt = now + MIN_MOUTH_INTERVAL

	-- An empty fork to the mouth is a harmless miss: it burns the cooldown and
	-- nothing else. It deliberately does NOT open an eating window, so it
	-- cannot get you killed -- mashing is wasteful, not fatal.
	if ps.fork <= 0 then
		tellOne(player.UserId, { kind = "cpmiss" })
		return
	end

	local load = ps.fork
	ps.fork = 0
	ps.eaten = ps.eaten + load
	ps.eatUntil = now + EAT_WINDOW
	if st.props and ps.seat then st.props.eat(ps.seat, load) end
	pushState(st, player.UserId)

	-- Caught the moment it happens, if the eyes are already open. The other
	-- half -- a window that runs INTO the watching phase -- is sweep()'s job.
	if st.phase == "watching" then
		eliminate(st, player.UserId, "seen")
		return
	end

	if ps.eaten >= PEAS_TOTAL then
		ps.finished = true
		ps.finishedAt = now - st.startedAt
		tellOne(player.UserId, { kind = "cpdone", at = ps.finishedAt })
	end
end

function CanteenProtocol.init()
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	TrialInput = folder:FindFirstChild("TrialInput")
	if not TrialInput then
		TrialInput = Instance.new("RemoteEvent")
		TrialInput.Name = "TrialInput"
		TrialInput.Parent = folder
	end
	TrialInput.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then return end
		if payload.trialId ~= "canteen" then return end
		local st = current
		if not st then return end
		if payload.roundToken ~= st.roundToken then return end
		handleAction(player, payload.action)
	end)
end

-- ROUND ---------------------------------------------------------------------

function CanteenProtocol.runRound(room, roundIndex)
	local scores = {}
	for _, mm in room.members do scores[mm.userId] = 0 end

	local okArena, reason = CanteenProtocol.validateArena()
	if not okArena then
		warn(("[CanteenProtocol] arena invalid: %s"):format(reason))
		return scores
	end
	local a = arena()

	local subjects = livingOf(room)
	local audience = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then table.insert(audience, plr) end
	end

	local st = {
		room = room,
		sessionId = room.sessionId,
		-- Minted here, exactly as Dead Zone mints its own. There is no
		-- `room.roundToken` to read: rooms carry a sessionId, and the per-round
		-- token is the trial's to create. Reading a field that does not exist
		-- would have silently fallen through to a fallback forever.
		roundToken = ("CP-%s-R%s-%d"):format(
			tostring(room.sessionId), tostring(roundIndex or 1),
			math.floor(os.clock() * 1000) % 100000),
		state = {},
		subjects = subjects,
		audience = audience,
		active = true,
		acceptInput = false,
		phase = "hidden",
		startedAt = os.clock(),
	}

	-- Built AFTER validateArena, never before: the gate raycasts from the
	-- Observer to every MouthTarget, and props standing on the table during
	-- that check could block the very line of sight it is there to prove.
	-- (They also carry CanQuery = false, so this is belt and braces.)
	st.props = CanteenProps.build(a, {
		peas = PEAS_TOTAL,
		forkCapacity = FORK_CAPACITY,
		eatWindow = EAT_WINDOW,
	})

	-- Seat everyone. More members than seats cannot happen (the room caps at 4)
	-- but the loop is written so a fifth member is skipped rather than
	-- overwriting seat 1 -- silently stacking two players on one chair would be
	-- a far worse failure than one player sitting out.
	local restore = {}
	local seatIndex = 0
	for _, mm in room.members do
		local s = subjects[mm.userId]
		st.state[mm.userId] = {
			remaining = PEAS_TOTAL, fork = 0, eaten = 0,
			finished = false, eliminated = s == nil,
			eatUntil = 0, nextPlateAt = 0, nextMouthAt = 0,
		}
		if s and seatIndex < #SEAT_IDS then
			seatIndex = seatIndex + 1
			local i = seatIndex
			st.state[mm.userId].seat = i

			table.insert(restore, { root = s.root, hum = s.hum,
				anchored = s.root.Anchored, walk = s.hum.WalkSpeed, jump = s.hum.JumpPower })

			s.hum.Health = s.hum.MaxHealth
			s.hum.WalkSpeed = 0
			s.hum.JumpPower = 0
			s.root.CFrame = a.seats[i].CFrame
			-- Anchored, not just WalkSpeed 0: the seat marker floats at chair
			-- height with nothing solid beneath it, so an unanchored character
			-- would simply fall off the chair the moment the round began.
			s.root.Anchored = true
			s.char:SetAttribute("XBotMoves", "eat")

			tellOne(mm.userId, { kind = "role", role = "spectate",
				pos = { a.cams[i].Position.X, a.cams[i].Position.Y, a.cams[i].Position.Z },
				look = { a.plates[i].Position.X, a.plates[i].Position.Y, a.plates[i].Position.Z },
				roundToken = st.roundToken })
		end
	end

	announce(room, { kind = "announce", text = "EAT EVERYTHING. DO NOT BE SEEN." })
	task.wait(2.4)

	for c = 3, 1, -1 do
		announce(room, { kind = "count", n = c })
		task.wait(1)
	end
	announce(room, { kind = "go" })

	current = st
	st.startedAt = os.clock()
	st.acceptInput = true
	for _, mm in room.members do pushState(st, mm.userId) end

	-- Dead Zone and Bird Hunting both log their round start, and those lines
	-- have repeatedly answered in seconds what guessing could not. Seats is the
	-- number that matters: a member who could not be seated plays no part.
	print(("[CP] go; members=%d seated=%d peas=%d token=%s")
		:format(#room.members, seatIndex, PEAS_TOTAL, st.roundToken))

	local observerThread = task.spawn(runObserver, st)

	local deadline = st.startedAt + ROUND_TIME
	while os.clock() < deadline do
		task.wait(0.1)
		if #room.members == 0 then break end
		if room.phase ~= "Playing" then break end
		local anyLeft = false
		for _, ps in st.state do
			if not (ps.finished or ps.eliminated) then anyLeft = true break end
		end
		if not anyLeft then break end
	end

	local finished, eliminated = 0, 0
	for _, ps in st.state do
		if ps.finished then
			finished = finished + 1
		elseif ps.eliminated then
			eliminated = eliminated + 1
		end
	end
	print(("[CP] round over, elapsed=%.1f finished=%d caught=%d")
		:format(os.clock() - st.startedAt, finished, eliminated))

	st.active = false
	st.acceptInput = false
	current = nil
	-- The observer loop only checks `active` between waits, so it can outlive
	-- this line by up to one 0.05 s tick. Cancelling it outright avoids a stray
	-- phase broadcast landing after the round card is already gone.
	task.cancel(observerThread)
	announce(room, { kind = "cpend" })

	local elapsed = os.clock() - st.startedAt
	for userId, ps in st.state do
		local key
		if ps.finished then
			local spare = math.max(0, ROUND_TIME - (ps.finishedAt or ROUND_TIME))
			key = FINISHED_BAND + math.floor(spare * FINISH_SPEED_STEP)
		elseif not ps.eliminated then
			key = ALIVE_BAND + ps.eaten * PEA_STEP
		else
			local survived = math.min(ps.eliminatedAt or 0, elapsed)
			key = ELIMINATED_BAND + ps.eaten * PEA_STEP + math.floor(survived * SURVIVAL_STEP)
		end
		scores[userId] = key
	end

	task.wait(1.6)

	for _, r in ipairs(restore) do
		if r.root.Parent then
			r.root.Anchored = r.anchored
		end
		if r.hum.Parent then
			r.hum.WalkSpeed = r.walk
			r.hum.JumpPower = r.jump
		end
	end
	st.props.destroy()
	BloodFX.clear(st.roundToken, audience)
	for _, s in livingOf(room) do
		s.char:SetAttribute("XBotMoves", "")
	end
	for _, mm in room.members do
		tellOne(mm.userId, { kind = "role", role = "none" })
	end

	return scores
end

return CanteenProtocol
