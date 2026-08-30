--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BloodFX = require(script.Parent.BloodFX)
local Pacing = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("Pacing"))
-- P1.5: the 3-2-1 step length is the SAME number the kit and the client use.
local Feel = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("FeelConfig"))

local BirdHunting = {}
-- #50 watchdog hook state (see BirdHunting.abort below).
BirdHunting._guard = nil :: { cleanup: (() -> ())? }?

-- Upper bound only: a leg ends when every runner is out.
-- REQ-BH-01: the leg cap comes from Pacing. (Phase 3c: the old "the plan sets
-- at 90 s" note here was stale -- live is 3 legs x 60 s since 22.08., P0.3.)
--
-- It was 150. Measured in a live solo session, four legs at that cap is ten
-- minutes of a single minigame -- against a target of 10-15 minutes for the
-- WHOLE three-minigame session. A leg that runs to the cap is one where the
-- runners are hiding rather than running, and 60 s is already long for that.
--
-- Read from Pacing rather than copied, so the leg cap and the round counts
-- that produce it cannot drift apart.
local ROUND_TIME = Pacing.RoundSeconds.birdhunt or 90
-- PHASE 3c (30.08.2026) -- BIRD HUNTING polish. Every tuned number lives in
-- Feel.Birdhunt (FeelConfig, the block after Feel.Minefield); resolved once
-- here so a missing block degrades to the shipped values instead of erroring
-- the whole trial.
local BH_FEEL = Feel.Birdhunt or {}
-- Phase 3c: the reload lockout IS the fire cooldown -- one number, one gate.
-- KenopsiaClient mirrors it as K.FIRE_COOLDOWN = 2.2 (bolt-cycle, recoil and
-- its own local gate); tests/feel.lua pins Feel.Birdhunt.ReloadSeconds == 2.2
-- until the client reads Feel, so the HUD's rifle can never lie about the
-- server's gate.
local FIRE_COOLDOWN = BH_FEEL.ReloadSeconds or 2.2
local AIM_INTERVAL = 1 / 25
local MAX_AIM_YAW = 0.72
local MIN_AIM_PITCH = -0.62
local MAX_AIM_PITCH = 0.27
local MAX_DIRECTION_COMPONENT = 10000
local MAX_RUNNER_SPEED = 14
-- 23.08.2026: a body shot that does not drop the runner wings them -- the
-- character gets the `Injured` attribute (PS1Animate plays InjuredWalk) and
-- limps at this WalkSpeed for the REST OF THE LEG. Slower than
-- MAX_RUNNER_SPEED, so every speed check above still accepts them; restored
-- only at the next leg's placement, never mid-leg.
-- Phase 3c: 7 -> Feel.Birdhunt.InjuredSpeed (3.5). At 7 a winged runner still
-- outran the bolt cycle to the exit; at 3.5 the limp is a real decision for
-- the hunter -- finish the wounded or switch targets. PS1Animate's
-- InjuredWalk (natural 3.49 st/s) plays at ~1x, so the gait finally matches
-- the speed it was authored for.
local INJURED_SPEED = BH_FEEL.InjuredSpeed or 3.5
local POSITION_SPEED_FACTOR = 2
local POSITION_TOLERANCE = 5
local PATH_SPEED_FACTOR = 1.15
local PATH_TOLERANCE = 12
local GROUND_CHECK_DISTANCE = 5.25
local MAX_AIRBORNE_TIME = 0.8
local MAX_UPWARD_SPEED = 12
local VERTICAL_TOLERANCE = 1.5
local BODY_DAMAGE = 55      -- two body shots drop a runner
local HIT_POINTS = 15       -- winging a runner
local KILL_POINTS = 60      -- body-shot finish
local HEADSHOT_POINTS = 100 -- one clean headshot: instant
-- How long a downed runner stays where they fell before the HUD resets and
-- they are moved out. Previously this was zero: the shot landed and the
-- teleport ran in the SAME frame, so a player never saw their own death --
-- one blood puff and they were already somewhere else.
local KILL_VIEW_TIME = 3.5
-- Phase 3c constants, all Feel.Birdhunt (see the block's doc comment there).
local PUSHES_PER_LEG = BH_FEEL.PushesPerLeg or 1
local PUSH_RANGE = BH_FEEL.PushRange or 6
local TOPPLE_SECONDS = BH_FEEL.ToppleSeconds or 0.5
local EXPOSE_AFTER = BH_FEEL.ExposeAfter or 2.5
local EXPOSE_SECONDS = BH_FEEL.ExposeSeconds or 0.4
local EXPOSE_EVERY = BH_FEEL.ExposeEvery or 1.5
local COVER_RADIUS = BH_FEEL.CoverRadius or 5
local BIRD_COUNT = BH_FEEL.Birds or 2
local BIRD_DETAIL = BH_FEEL.BirdDetail or 200
local BIRD_SPEED = BH_FEEL.BirdSpeed or 14
-- Minefield's DETAIL_CAP, same number on purpose: the hunter's one raw-key
-- accumulator (tags + decoys) is clamped under 1000 at scoring so no added
-- detail can ever run a raw key away from the pack. Max legit per runner is
-- wing (15) THEN headshot (100) = 115 -- a second body shot always kills at
-- 45 HP <= BODY_DAMAGE, so two wings on one runner are impossible -- giving
-- 3 x 115 (345) + Birds x BirdDetail (400) = 745; tests/feel.lua re-proves it.
local DETAIL_CAP = 999
-- The lamp's two states and the exposure ping tint (hex strings in Feel, the
-- house colour convention -- here the SERVER paints them onto neon parts).
local LAMP_RELOAD_COLOR = Color3.fromHex(BH_FEEL.LampReloadHex or "D9A036")
local LAMP_READY_COLOR = Color3.fromHex(BH_FEEL.LampReadyHex or "46E8E0")
local EXPOSE_COLOR = Color3.fromHex(BH_FEEL.ExposeHex or "FF1818")
-- Which folder children a runner may topple: the LOOSE cover only. Stones,
-- walls, trees and towers never move -- a pushed wall would re-shape the
-- anti-teleport lane the validators above assume.
local PUSHABLE_NAMES = { ["Metal_crate"] = true, ["Wooden_pallet"] = true }
-- Stillness epsilon per main-loop sample. Minefield's STILL_EPSILON is 0.15
-- studs per 20 Hz tick (3 st/s of drift tolerance); this loop samples at
-- 0.2 s, so 0.5 studs keeps roughly the same tolerance. Server's OWN samples,
-- never client claims.
local EXPOSE_STILL_EPSILON = 0.5

-- Remote state is keyed by the active hunter. The arena itself is serialized
-- below because every room currently shares the same physical map.
local activeByHunter = {}
-- Phase 3c: the one live leg (arenaBusy serializes them), so the TrialInput
-- push handler can resolve it. Set beside activeByHunter, cleared by stopRound.
local currentLeg = nil
local arenaBusy = false
local fireRemote
local aimRemote
local pushInput

local function finiteComponent(component)
	return component == component
		and component > -math.huge
		and component < math.huge
		and math.abs(component) <= MAX_DIRECTION_COMPONENT
end

local function cleanDirection(value)
	if typeof(value) ~= "Vector3" then return nil end
	if not (finiteComponent(value.X) and finiteComponent(value.Y) and finiteComponent(value.Z)) then
		return nil
	end
	local magnitude = value.Magnitude
	if magnitude ~= magnitude or magnitude < 0.1 or magnitude >= math.huge then return nil end
	return value / magnitude
end

local function aimWithinBounds(dir, baseAim)
	local basis = CFrame.lookAt(Vector3.zero, baseAim)
	local relative = basis:VectorToObjectSpace(dir)
	local yaw = math.atan2(-relative.X, -relative.Z)
	local pitch = math.asin(math.clamp(relative.Y, -1, 1))
	return math.abs(yaw) <= MAX_AIM_YAW
		and pitch >= MIN_AIM_PITCH
		and pitch <= MAX_AIM_PITCH
end

local function ensureRemote()
	if fireRemote then return end
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	fireRemote = folder:FindFirstChild("SniperFire")
	if not fireRemote then
		fireRemote = Instance.new("RemoteEvent")
		fireRemote.Name = "SniperFire"
		fireRemote.Parent = folder
	end
	fireRemote.OnServerEvent:Connect(function(player)
		local c = activeByHunter[player.UserId]
		if not (c and c.active and c.sniperUserId == player.UserId) then return end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.Health > 0) then return end
		local now = os.clock()
		if now - c.lastShot < FIRE_COOLDOWN then return end
		c.lastShot = now
		-- The latest validated server aim is authoritative; a fire payload cannot
		-- redirect the ray independently.
		c.shoot(c.aimDir)
	end)
	aimRemote = folder:FindFirstChild("SniperAim")
	if not aimRemote then
		aimRemote = Instance.new("UnreliableRemoteEvent")
		aimRemote.Name = "SniperAim"
		aimRemote.Parent = folder
	end
	aimRemote.OnServerEvent:Connect(function(player, value)
		local c = activeByHunter[player.UserId]
		if not (c and c.acceptAim and c.sniperUserId == player.UserId) then return end
		-- Consume the rate-limit window before parsing attacker-controlled payloads.
		local now = os.clock()
		if now - c.lastAimAt < AIM_INTERVAL then return end
		c.lastAimAt = now
		local dir = cleanDirection(value)
		if not dir or not aimWithinBounds(dir, c.baseAim) then return end
		c.aimDir = dir
	end)
	-- Phase 3c: PUSH rides the SAME TrialInput remote Minefield owns a handler
	-- on. Multiple OnServerEvent connections on one RemoteEvent are fine; each
	-- handler drops foreign trialIds (Minefield's does exactly that with
	-- "minefield"). Find-or-create mirrors Minefield.init, so boot order
	-- between the two services does not matter.
	pushInput = folder:FindFirstChild("TrialInput")
	if not pushInput then
		pushInput = Instance.new("RemoteEvent")
		pushInput.Name = "TrialInput"
		pushInput.Parent = folder
	end
	pushInput.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then return end
		if payload.trialId ~= "birdhunt" or payload.action ~= "push" then return end
		local c = currentLeg
		if not c then return end
		-- Minefield's C1.a ladder, Bird-shaped. Bird's legacy remotes validate
		-- via activeByHunter identity; a runner input has no such key, so the
		-- leg token stands in:
		--   active      - open only between GO and leg end.
		--   phase       - kills packets belonging to an aborted match.
		--   roundToken  - MANDATORY. Handed to runners in this leg's role
		--                 packet and refused unless echoed exactly, so a push
		--                 replayed from an earlier leg dies here even while a
		--                 later leg is live and accepting input. Freshness,
		--                 not authorisation: membership, role, liveness and
		--                 rate are proven inside c.push on the leg's own
		--                 tables.
		if not c.active then return end
		if c.room and c.room.phase ~= nil and c.room.phase ~= "Playing" then return end
		if payload.roundToken ~= c.roundToken then return end
		if c.push then c.push(player) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		activeByHunter[player.UserId] = nil
	end)
end

local function refs()
	local folder = workspace:FindFirstChild("Bird Hunting")
	if not folder then return nil end
	return {
		folder = folder,
		start = folder:FindFirstChild("Start"),
		exit = folder:FindFirstChild("Exit"),
		post = folder:FindFirstChild("SniperPost"),
	}
end

-- THE TOWER IS A MACHINE, NOT A POSED PLAYER.
--
-- The hunter used to be the player's own character, knelt at the parapet and
-- driven by an aim animation. That tied the role to the rig: every pose needed
-- authoring, and the character had to exist and look right before the minigame
-- could. A mounted gun removes the dependency entirely -- the server already
-- validates an aim direction, so the machine can simply point along it.
--
-- SWAPPABLE, like the Compactor. Drop a model into
-- ServerStorage.KenopsiaAssets.Props.BirdHunting as BH_Turret and it replaces
-- the procedural build with no code change. The pivot is what gets aimed, so an
-- authored model wants its PrimaryPart at the mount with the barrel down -Z.
local function buildTurret(parent)
	local props = ServerStorage:FindFirstChild("KenopsiaAssets")
	props = props and props:FindFirstChild("Props")
	props = props and props:FindFirstChild("BirdHunting")
	local tpl = props and props:FindFirstChild("BH_Turret")
	local model
	if tpl then
		model = tpl:Clone()
	else
		model = Instance.new("Model")
		local mount = Instance.new("Part")
		mount.Name = "Mount"
		mount.Size = Vector3.new(1.6, 1.6, 1.6)
		mount.Material = Enum.Material.DiamondPlate
		mount.Color = Color3.fromRGB(38, 36, 34)
		mount.Parent = model
		local barrel = Instance.new("Part")
		barrel.Name = "Barrel"
		barrel.Size = Vector3.new(0.35, 0.35, 5.2)
		barrel.Material = Enum.Material.Metal
		barrel.Color = Color3.fromRGB(24, 23, 22)
		barrel.Parent = model
		model.PrimaryPart = mount
	end
	model.Name = "SniperTurret"
	-- Never a physics object: the shot is a server raycast, so a collidable or
	-- queryable turret would only block that raycast and shove the hunter.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	end
	model.Parent = parent
	return model
end

-- FX POOLS. Both effects allocated an instance per shot and destroyed it a
-- moment later; the plan sizes them at 16 tracers and 24 impacts.
--
-- Module level, not per round, so a leg starts with whatever the previous one
-- left warm. Parts are reparented on acquire because the arena folder is a
-- per-round reference.
--
-- A DESTROYED part must never re-enter a pool: pooling it would hand out an
-- instance whose every property write throws. Release therefore refuses
-- anything already unparented, which covers both destruction and a double
-- release.
local TRACER_POOL_MAX = 16
local SPARK_POOL_MAX = 24
local tracerPool, sparkPool = {}, {}

local function acquireTracer()
	local part = table.remove(tracerPool)
	if part then return part end
	part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(224, 52, 42)
	return part
end

local function releaseTracer(part)
	if not part.Parent then return end
	part.Parent = nil
	if #tracerPool < TRACER_POOL_MAX then
		table.insert(tracerPool, part)
	else
		part:Destroy()
	end
end

local function acquireSpark()
	local holder = table.remove(sparkPool)
	if holder then return holder end
	holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 196, 72), Color3.fromRGB(255, 76, 28))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.11)
	sparks.Lifetime = NumberRange.new(0.12, 0.28)
	sparks.Speed = NumberRange.new(5, 12)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Rate = 0
	sparks.Parent = holder
	return holder
end

local function releaseSpark(holder)
	if not holder.Parent then return end
	holder.Parent = nil
	if #sparkPool < SPARK_POOL_MAX then
		table.insert(sparkPool, holder)
	else
		holder:Destroy()
	end
end

-- Barrel offset from the mount, applied after the aim rotation so the gun sits
-- forward of its pivot instead of through it.
local TURRET_BARREL_OFFSET = CFrame.new(0, 0, -2.6)

local function aimTurret(model, eye, dir)
	if not (model and model.Parent and model.PrimaryPart) then return end
	local pivot = CFrame.lookAt(eye, eye + dir)
	model:PivotTo(pivot)
	local barrel = model:FindFirstChild("Barrel")
	if barrel then barrel.CFrame = pivot * TURRET_BARREL_OFFSET end
end

local function livingOf(room)
	local out = {}
	for _, m in room.members do
		local plr = Players:GetPlayerByUserId(m.userId)
		local char = plr and plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			out[m.userId] = { player = plr, char = char, root = root, hum = hum }
		end
	end
	return out
end

-- C5: the same liveness test C1 gave Minefield. Bird has no session or
-- round-ownership token, so this is room-based only. A nil phase still counts as
-- active, which keeps the direct/solo test calls working, and it folds in the
-- member-drain check the main loop already does at the bottom.
-- (Phase 3c: the LEG now carries a freshness token for the push input -- see
-- roundState.roundToken -- but room liveness stays this room-based test.)
local function roomActive(room)
	return #room.members > 0 and (room.phase == nil or room.phase == "Playing")
end

-- create SniperFire/SniperAim (and, Phase 3c, the TrialInput push handler) at
-- server boot so clients can WaitForChild them
function BirdHunting.init()
	ensureRemote()
end

local function runLeg(room, roundIndex, forcedHunterUserId, legIndex, legTotal, guard)
	ensureRemote()
	local R = refs()
	local scores = {}
	-- C5: zero every participant up front, so any cancellation bail below can
	-- simply `return scores` and hand MachineFlow a complete, zeroed table - the
	-- same shape the arena-incomplete path and BirdHunting.runRound already
	-- produce. The normal scoring loop at the end overwrites every key, so this
	-- cannot mask a real score.
	for _, m in room.members do scores[m.userId] = 0 end
	if not (R and R.start and R.exit and R.post) then
		warn("[BirdHunting] arena incomplete - round skipped")
		return scores
	end

	local startPos = R.start.Position
	local exitZ = R.exit.Position.Z
	local travelDelta = exitZ - startPos.Z
	local runLength = math.abs(travelDelta)
	local travelSign = travelDelta >= 0 and 1 or -1
	local laneHalfWidth = math.max(R.start.Size.X * 0.5 + 12, 30)
	local minEscapeTime = math.max(3, runLength / (MAX_RUNNER_SPEED * PATH_SPEED_FACTOR))
	local function progressAt(z)
		if runLength < 0.001 then return 0 end
		return math.clamp((z - startPos.Z) / travelDelta, 0, 1)
	end
	local eye = R.post.Position
	local spawnPos = workspace:FindFirstChild("SpawnLocation") and workspace.SpawnLocation.Position or Vector3.new(0, 5, 0)

	-- Phase 3c: the folder's own children ARE the cover chart. Snapshotted once
	-- per leg -- the exposure check reads this list, never the live workspace
	-- (a topple moves a crate a couple of studs; it stays cover where it lies).
	-- Everything but the three markers counts: standing against a wall, a tree
	-- or a crate is all "behind something".
	local coverPositions = {}
	local pushables = {}
	for _, child in R.folder:GetChildren() do
		if child ~= R.start and child ~= R.exit and child ~= R.post
			and (child:IsA("BasePart") or child:IsA("Model")) then
			local pos = child:GetPivot().Position
			table.insert(coverPositions, pos)
			if PUSHABLE_NAMES[child.Name] then
				table.insert(pushables, { inst = child, pos = pos, toppled = false })
			end
		end
	end

	-- Every numbered round gives every participant one Hunter leg. The caller
	-- supplies that Hunter; the fallback keeps direct/solo test calls working.
	local sniperUserId = nil
	if #room.members >= 2 then
		for _, member in room.members do
			if member.userId == forcedHunterUserId then
				sniperUserId = forcedHunterUserId
				break
			end
		end
		if not sniperUserId then
			if forcedHunterUserId then
				-- SKIPPED, NEVER SUBSTITUTED.
				--
				-- The session scheduled this leg for a specific player and that
				-- player is no longer in the room. Handing the tower to whoever
				-- happens to sit at the rotation index gives one player two
				-- hunting legs and another none -- and the schedule is the whole
				-- basis on which duel points are comparable.
				--
				-- scores is already zeroed for every participant precisely so a
				-- bail can return it, so a skipped leg costs nobody anything.
				print(("[BH] leg %s skipped: scheduled hunter %d has left")
					:format(tostring(legIndex or roundIndex), forcedHunterUserId))
				return scores
			end
			-- No hunter was supplied at all, which only happens on a direct or
			-- solo test call. The rotation keeps those working.
			local idx = ((roundIndex or 1) - 1) % #room.members + 1
			sniperUserId = room.members[idx].userId
		end
	end

	local MachineState = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")
	local audience = {}
	for _, member in room.members do
		local player = Players:GetPlayerByUserId(member.userId)
		if player then table.insert(audience, player) end
	end
	local function tellAll(payload)
		if not MachineState then return end
		for _, m in room.members do
			local plr = Players:GetPlayerByUserId(m.userId)
			if plr then MachineState:FireClient(plr, payload) end
		end
	end
	-- MP-08 (26.08.2026): this helper did not exist. dropRunner called tellOne()
	-- anyway -- an undefined GLOBAL, so the spectate packet for a killed runner
	-- raised "attempt to call a nil value" inside its task.delay thread and was
	-- never delivered. Viewer mode in Bird Hunting has therefore never once run;
	-- what the dead player saw was their own body at spawn, which is also why
	-- B-03 (role="none" ending the mode too early) could never be observed.
	-- Named and shaped like Minefield's and CanteenProtocol's, so the three
	-- trials send single-player packets the same way.
	local function tellOne(userId, payload)
		if not MachineState then return end
		local plr = Players:GetPlayerByUserId(userId)
		if plr then MachineState:FireClient(plr, payload) end
	end

	local state = {}
	local roundState
	local beam
	local corpses = {}
	-- Phase 3c leg-scoped state, all torn down or restored by stopRound: the
	-- pushed-over cover (snapshot + restore, the Minefield CRAWL contract),
	-- the decoy birds and any exposure Highlight still fading.
	local toppled = {}
	local birds = {}
	local exposeMarks = {}
	local hbConn
	local exitConn
	local stopped = false
	local cleaned = false

	-- keepCamera: leave the client's spectate camera alone. See MP-08 B-03 at
	-- the role packet below.
	local function clearParticipant(uid, subject, keepCamera)
		local function clearCharacter(char)
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 0
				hum.Jump = false
			end
			char:SetAttribute("XBotMoves", "")
			char:SetAttribute("Injured", false) -- 23.08.2026: out of the leg, no limp
		end
		clearCharacter(subject and subject.char)
		local player = Players:GetPlayerByUserId(uid)
		if player then
			if not subject or player.Character ~= subject.char then clearCharacter(player.Character) end
			-- MP-08 B-03 (26.08.2026, user): role="none" raeumt spectateCF im
			-- Client ab -- fuer einen Toten ist das das Ende des Zuschauermodus
			-- mitten im Leg, KILL_VIEW_TIME (3.5 s) nach dem Schuss. Die Kamera
			-- sprang zurueck auf den eigenen Koerper am Spawn, und der Tote sah
			-- den Rest des Legs sich selbst zu. Der Zuschauermodus laeuft jetzt
			-- bis zur neuen Runde: cleanupRound schickt role="none" ohnehin an
			-- jeden im Raum -- das ist die Stelle, an der es hingehoert.
			if MachineState and not keepCamera then
				MachineState:FireClient(player, { kind = "role", role = "none" })
			end
		end
	end

	local function stopRound()
		if stopped then return end
		stopped = true
		if roundState then
			roundState.active = false
			roundState.acceptAim = false
			if sniperUserId and activeByHunter[sniperUserId] == roundState then
				activeByHunter[sniperUserId] = nil
			end
			-- Phase 3c: the push handler must stop resolving this leg.
			if currentLeg == roundState then currentLeg = nil end
		end
		if exitConn then exitConn:Disconnect() exitConn = nil end
		if hbConn then hbConn:Disconnect() hbConn = nil end
		if beam then beam:Destroy() beam = nil end
		if roundState and roundState.turret then
			roundState.turret:Destroy()
			roundState.turret = nil
		end
		-- Phase 3c teardown. The lamp dies with the leg (it lives in R.folder,
		-- not the turret model -- see its build comment).
		if roundState and roundState.lamp then
			roundState.lamp:Destroy()
			roundState.lamp = nil
		end
		for _, b in ipairs(birds) do
			if b.model.Parent then b.model:Destroy() end
		end
		table.clear(birds)
		for _, hl in ipairs(exposeMarks) do
			if hl.Parent then hl:Destroy() end
		end
		table.clear(exposeMarks)
		-- The pushed cover stands back up from its snapshot -- pivot AND the
		-- per-part Anchored flags the topple froze.
		for _, t in ipairs(toppled) do
			if t.inst.Parent then
				t.inst:PivotTo(t.pivot)
				for part, anchored in t.anchored do
					if part.Parent then part.Anchored = anchored end
				end
			end
		end
		table.clear(toppled)
		for _, corpse in ipairs(corpses) do
			if corpse.Parent then corpse:Destroy() end
		end
		table.clear(corpses)
	end

	local function cleanupRound()
		if cleaned then return end
		cleaned = true
		stopRound()
		for _, member in room.members do
			local plr = Players:GetPlayerByUserId(member.userId)
			local char = plr and plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.Health = hum.MaxHealth
				hum.WalkSpeed = 0
			end
			if char then
				char:SetAttribute("XBotMoves", "")
				char:SetAttribute("Injured", false) -- 23.08.2026: the leg is over
				char:SetAttribute("XBotRifle", false)
				local mesh = char:FindFirstChild("Beta_Joints")
				if mesh and mesh:IsA("BasePart") then mesh.Transparency = 0 end
			end
			if root then
				root.CFrame = CFrame.new(spawnPos + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
			end
			if plr then
				pcall(function() plr.CameraMode = Enum.CameraMode.Classic end)
				if MachineState then MachineState:FireClient(plr, { kind = "role", role = "none" }) end
			end
		end
	end
	guard.cleanup = cleanupRound

	-- the machine names its hunter on a black card before anyone moves
	--
	-- P1.4 (23.08.2026): when the session forced the hunter, MachineFlow has
	-- just shown that sentence as the {kind="rolecard"} beat (1.6 s), so the
	-- in-leg card is skipped here rather than printing the name twice in a
	-- row. The direct / solo path (no forced hunter) keeps its own card.
	if not forcedHunterUserId then
		local sniperName = nil
		for _, m in room.members do
			if m.userId == sniperUserId then sniperName = string.upper(m.displayName or "?") end
		end
		tellAll({ kind = "announce", text = sniperName and (sniperName .. " IS THE HUNTER.") or "THE TOWER IS UNMANNED. RUN." })
		task.wait(2.8)
		tellAll({ kind = "hide" })
	end
	-- C5: the room can abort during the 2.8s hunter card. Bail before anyone is
	-- frozen, posed or teleported. guard.cleanup is already armed, so this
	-- return runs cleanupRound through the wrapper - it is not a bare return.
	if not roomActive(room) then return scores end

	local subjects = livingOf(room)
	local lane = 0
	for _, m in room.members do
		local s = subjects[m.userId]
		local isSniper = m.userId == sniperUserId
		state[m.userId] = {
			done = isSniper, escaped = false, progress = 0, sniper = isSniper, points = 0,
			-- Phase 3c: the push budget. Spent SERVER-side in roundState.push.
			pushesLeft = isSniper and 0 or PUSHES_PER_LEG,
		}
		if s then
			s.hum.Health = s.hum.MaxHealth
			s.hum.WalkSpeed = 0
			s.hum.UseJumpPower = true
			s.hum.JumpPower = 0
			s.hum.JumpHeight = 0
			s.hum.Jump = false
			pcall(function() s.hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
			local mesh = s.char:FindFirstChild("Beta_Joints")
			if mesh and mesh:IsA("BasePart") then mesh.Transparency = 0 end
			-- new minigame, new moves: runners may sneak in this trial.
			-- Phase 3c, DELIBERATELY NOT "sneak push": KenopsiaClient's
			-- charPushAllowed() keys the legacy Btn_PUNCH off "push", and that
			-- button fires XBotPush -- a remote NO server creates or handles
			-- (stranded since Gate 1). Granting "push" would surface a dead
			-- button on every touch device. The RunnerClient push sender gates
			-- on "sneak" instead, the move only this trial grants.
			s.char:SetAttribute("XBotMoves", isSniper and "" or "sneak")
			-- 23.08.2026: a new leg heals the limp; the GO below restores the speed
			s.char:SetAttribute("Injured", false)
			if isSniper then
				-- The hunter operates the turret and is not seen doing it. The
				-- character still exists -- the scope camera and the shot filter
				-- both hang off it -- but nobody, including the other players,
				-- sees a body at the parapet. The machine is what stands there.
				for _, d in s.char:GetDescendants() do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.Transparency = 1
					end
				end
				-- Parked at the parapet. The pose no longer matters visually --
				-- every part above was just set invisible and the machine does
				-- the aiming -- but the character must still exist and sit here,
				-- because the scope camera and the shot's raycast filter both
				-- hang off it.
				--
				-- The XBotAction "SniperAim"/"SniperEnd" writes that used to be
				-- here are gone: nothing in the codebase ever read that
				-- attribute, and since the turret hides the hunter they would
				-- drive an animation on an invisible body. Leaving them would
				-- have put a sniper-aim clip on the Blender animation list that
				-- no one will ever see.
				s.root.CFrame = CFrame.lookAt(eye + Vector3.new(0, -3.2, 0), Vector3.new(startPos.X, eye.Y - 3.2, startPos.Z))
			else
				local x = startPos.X - 16 + (lane % 4) * 10
				lane += 1
				s.root.CFrame = CFrame.lookAt(
					Vector3.new(x, startPos.Y + 4, startPos.Z),
					Vector3.new(x, startPos.Y + 4, exitZ))
			end
		end
	end
	-- tracer visual
	local function tracer(fromPos, toPos)
		local dist = (toPos - fromPos).Magnitude
		local part = acquireTracer()
		-- Size and CFrame on every acquire: a recycled tracer carries the
		-- length and angle of the shot before it.
		part.Size = Vector3.new(0.3, 0.3, dist)
		part.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -dist / 2)
		part.Parent = R.folder
		task.delay(0.14, function() releaseTracer(part) end)
	end

	local function coverSpark(pos, normal)
		local holder = acquireSpark()
		holder.CFrame = CFrame.lookAt(pos, pos + normal)
		holder.Parent = R.folder
		local sparks = holder:FindFirstChild("Sparks")
		if sparks then sparks:Emit(9) end
		task.delay(0.4, function() releaseSpark(holder) end)
	end

	-- Phase 3c: PUSH-TOPPLE. One loose prop, once, server-side. The fall is a
	-- short stepped pivot animation (TOPPLE_SECONDS, under Feel.MaxMotion);
	-- the prop stays down as new LOW cover for the rest of the leg and stands
	-- back up in stopRound from the snapshot taken here. Anchoring is frozen
	-- for the fallen phase so an unanchored crate cannot physics-fight the
	-- pivot writes; the original flags restore with the pivot.
	local function toppleProp(entry, fromPos)
		local inst = entry.inst
		local pivot0 = inst:GetPivot()
		local anchored = {}
		if inst:IsA("BasePart") then
			anchored[inst] = inst.Anchored
			inst.Anchored = true
		else
			for _, d in inst:GetDescendants() do
				if d:IsA("BasePart") then
					anchored[d] = d.Anchored
					d.Anchored = true
				end
			end
		end
		table.insert(toppled, { inst = inst, pivot = pivot0, anchored = anchored })
		-- Tip AWAY from the pusher, hinged on the bottom edge of the far side.
		local flat = Vector3.new(entry.pos.X - fromPos.X, 0, entry.pos.Z - fromPos.Z)
		local dir = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, travelSign)
		local ext = inst:IsA("BasePart") and inst.Size or inst:GetExtentsSize()
		local halfAlong = (math.abs(dir.X) * ext.X + math.abs(dir.Z) * ext.Z) * 0.5
		local hinge = entry.pos + dir * halfAlong - Vector3.new(0, ext.Y * 0.5, 0)
		-- Rotating about up x dir tips the top toward dir (right-hand rule).
		-- Vector3.new, not Vector3.yAxis: selene's stdlib does not model the
		-- axis constants as full Vector3s and the repo lint must stay clean.
		local axis = Vector3.new(0, 1, 0):Cross(dir)
		task.spawn(function()
			local steps = math.max(4, math.floor(TOPPLE_SECONDS / 0.05))
			for i = 1, steps do
				if stopped or not inst.Parent then return end
				local a = (i / steps) * math.rad(85)
				local rot = CFrame.fromAxisAngle(axis, a)
				inst:PivotTo(CFrame.new(hinge) * rot * CFrame.new(-hinge) * pivot0)
				task.wait(TOPPLE_SECONDS / steps)
			end
			-- Review fix (30.08.): the fallen prop is cover where it now LIES
			-- as well as where it stood. The hinge displaces the resting pivot
			-- by up to half the prop's extent plus half its height (~4 studs on
			-- a 4-stud crate) -- most of CoverRadius (5) -- so without this a
			-- runner hugging their own toppled crate reads as OPEN ground and
			-- gets pinged. The old entry stays: the footprint still overlaps
			-- it. Leg-scoped, dies with coverPositions at leg end.
			table.insert(coverPositions, inst:GetPivot().Position)
		end)
	end

	-- Phase 3c: DECOY BIRDS. BIRD_COUNT low-poly machine birds cross the lane
	-- on server-computed straight lines, moved by ONE PivotTo per bird per
	-- 0.1 s tick (10 Hz). Server-side ON PURPOSE: the shot raycast must see a
	-- bird where it truly is -- a client-integrated bird (the compactor
	-- attribute pattern) would desync hit detection by exactly the latency the
	-- pattern hides. Two anchored three-part models at 10 Hz are replication
	-- noise, not load. CanQuery stays TRUE on bird parts -- being hittable is
	-- the decoy's whole job (the one deliberate exception to the buildTurret
	-- recipe).
	local birdRng = Random.new()
	local function birdCrossing(b, now)
		local side = laneHalfWidth + 24
		local z = startPos.Z + travelSign * birdRng:NextNumber(0.2, 0.8) * runLength
		local y = startPos.Y + birdRng:NextNumber(8, 13)
		b.leftToRight = not b.leftToRight
		local x0 = startPos.X + (b.leftToRight and -side or side)
		local x1 = startPos.X + (b.leftToRight and side or -side)
		b.from = Vector3.new(x0, y, z)
		b.to = Vector3.new(x1, y, z)
		b.dir = (b.to - b.from).Unit
		b.t0 = now
		b.dur = (b.to - b.from).Magnitude / BIRD_SPEED
	end

	local function buildBird()
		local model = Instance.new("Model")
		model.Name = "BH_DecoyBird"
		model:SetAttribute("BHBird", true)
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(0.5, 0.4, 1.5)
		body.Material = Enum.Material.SmoothPlastic
		body.Color = Color3.fromRGB(46, 42, 40)
		body.CFrame = CFrame.new()
		body.Parent = model
		local wingL = Instance.new("Part")
		wingL.Name = "WingL"
		wingL.Size = Vector3.new(1.7, 0.08, 0.55)
		wingL.Material = Enum.Material.SmoothPlastic
		wingL.Color = Color3.fromRGB(52, 48, 45)
		wingL.CFrame = body.CFrame * CFrame.new(-0.95, 0.12, 0) * CFrame.Angles(0, 0, math.rad(14))
		wingL.Parent = model
		local wingR = Instance.new("Part")
		wingR.Name = "WingR"
		wingR.Size = Vector3.new(1.7, 0.08, 0.55)
		wingR.Material = Enum.Material.SmoothPlastic
		wingR.Color = Color3.fromRGB(52, 48, 45)
		wingR.CFrame = body.CFrame * CFrame.new(0.95, 0.12, 0) * CFrame.Angles(0, 0, math.rad(-14))
		wingR.Parent = model
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				-- CanQuery TRUE: see the block comment above.
				d.CanTouch = false
				d.CastShadow = false
			end
		end
		model.PrimaryPart = body
		model.Parent = R.folder
		return model
	end

	-- A shot decoy tumbles for a beat, then is gone. It never respawns: the
	-- flock is finite (BIRD_COUNT per leg), which is what makes the detail cap
	-- provable offline -- see the scoring clamp at the bottom.
	local function dropBird(model)
		for _, b in ipairs(birds) do
			if b.model == model then b.alive = false end
		end
		task.spawn(function()
			local elapsed = 0
			while elapsed < 0.7 and model.Parent do
				local dt = task.wait(0.05)
				elapsed += dt
				local pivot = model:GetPivot()
				model:PivotTo((pivot + Vector3.new(0, -30 * elapsed * dt, 0))
					* CFrame.Angles(2.4 * dt, 0, 1.4 * dt))
			end
			if model.Parent then model:Destroy() end
		end)
	end

	local function spawnBirds()
		if BIRD_COUNT <= 0 then return end
		local now = os.clock()
		for i = 1, BIRD_COUNT do
			-- dur = 0 keeps the literal's sealed table type honest for
			-- luau-lsp; birdCrossing overwrites it before the read below.
			local b = { model = buildBird(), alive = true, leftToRight = (i % 2 == 0), phase = i * 1.7, dur = 0 }
			birdCrossing(b, now)
			-- staggered starts so two birds never fly formation
			b.t0 = now - birdRng:NextNumber(0, b.dur * 0.7)
			table.insert(birds, b)
		end
		-- The 10 Hz mover. Bounded by `stopped` like the turret tick; a bird
		-- that finishes a crossing simply starts another until the leg ends.
		-- The sine bob rides on the pivot -- no extra per-wing writes.
		task.spawn(function()
			while not stopped do
				local t = os.clock()
				for _, b in ipairs(birds) do
					if b.alive and b.model.Parent then
						local a = (t - b.t0) / b.dur
						if a >= 1 then
							birdCrossing(b, t)
						else
							local pos = b.from:Lerp(b.to, math.clamp(a, 0, 1))
								+ Vector3.new(0, math.sin(t * 2.1 + b.phase) * 0.7, 0)
							b.model:PivotTo(CFrame.lookAt(pos, pos + b.dir))
						end
					end
				end
				task.wait(0.1)
			end
		end)
	end

	local roundStart
	local function runnerGrounded(st, subject)
		if subject.hum.FloorMaterial ~= Enum.Material.Air then return true end
		if not st.groundParams or st.groundCharacter ~= subject.char then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { subject.char }
			st.groundParams = params
			st.groundCharacter = subject.char
		end
		return workspace:Raycast(subject.root.Position, Vector3.new(0, -GROUND_CHECK_DISTANCE, 0), st.groundParams) ~= nil
	end
	local function runnerPositionValid(st, subject, now)
		local pos = subject.root.Position
		if math.abs(pos.X - startPos.X) > laneHalfWidth then return false end
		if pos.Y < startPos.Y - 6 or pos.Y > startPos.Y + 11 then return false end
		local forward = (pos.Z - startPos.Z) * travelSign
		if forward < -10 or forward > runLength + 10 then return false end
		local elapsed = math.max(0, now - (roundStart or now))
		if forward > elapsed * MAX_RUNNER_SPEED * PATH_SPEED_FACTOR + PATH_TOLERANCE then
			return false
		end
		local grounded = runnerGrounded(st, subject)
		st.groundedNow = grounded
		if grounded then
			st.airborneSince = nil
		else
			st.airborneSince = st.airborneSince or now
			if now - st.airborneSince > MAX_AIRBORNE_TIME then return false end
		end
		if st.lastValidPosition then
			local dt = math.clamp(now - (st.lastValidAt or now), 0.05, 0.6)
			local a = Vector3.new(pos.X, 0, pos.Z)
			local b = Vector3.new(st.lastValidPosition.X, 0, st.lastValidPosition.Z)
			if (a - b).Magnitude > MAX_RUNNER_SPEED * dt * POSITION_SPEED_FACTOR + POSITION_TOLERANCE then
				return false
			end
			if pos.Y - st.lastValidPosition.Y > MAX_UPWARD_SPEED * dt + VERTICAL_TOLERANCE then
				return false
			end
		end
		return true
	end
	local function rememberRunnerPosition(st, subject, now)
		st.lastValidPosition = subject.root.Position
		st.lastValidCFrame = subject.root.CFrame
		st.lastValidAt = now
		st.airborneSince = nil
		st.groundedNow = true
	end
	local function rollbackRunner(st, subject, now)
		if st.lastValidCFrame then
			subject.root.CFrame = st.lastValidCFrame
			subject.root.AssemblyLinearVelocity = Vector3.zero
			subject.root.AssemblyAngularVelocity = Vector3.zero
		end
		st.lastValidAt = now
		st.airborneSince = nil
		st.groundedNow = true
	end

	-- Phase 3c: HEARTBEAT EXPOSURE. Stillness is measured from this loop's
	-- OWN 0.2 s samples (the Minefield STILL_EPSILON precedent scaled to this
	-- tick), never from client claims. Standing still past EXPOSE_AFTER in
	-- OPEN ground -- no cover-chart entry within COVER_RADIUS -- pings the
	-- runner: a Highlight EVERYONE sees, the runner included. That is a
	-- deliberate adaptation of the plan's sniper-only ping: a telegraph given
	-- ABOUT you that you cannot see is not a telegraph, and on a muted device
	-- it would be the game's only silent punishment. Highlights have a
	-- 31-instance engine cap; at most one per living runner (<= 3) is alive at
	-- once, each for EXPOSE_SECONDS, so the cap is never approached.
	local function nearCover(pos)
		for _, cp in ipairs(coverPositions) do
			local dx, dz = pos.X - cp.X, pos.Z - cp.Z
			if dx * dx + dz * dz <= COVER_RADIUS * COVER_RADIUS then return true end
		end
		return false
	end
	local function sampleExposure(st, s, now)
		local pos = s.root.Position
		local flat = Vector3.new(pos.X, 0, pos.Z)
		if st.exposeLastPos and (flat - st.exposeLastPos).Magnitude <= EXPOSE_STILL_EPSILON then
			st.exposeStillSince = st.exposeStillSince or now
		else
			st.exposeStillSince = nil
		end
		st.exposeLastPos = flat
		if not st.exposeStillSince then return end
		if now - st.exposeStillSince < EXPOSE_AFTER then return end
		if now - (st.lastExposeAt or 0) < EXPOSE_EVERY then return end
		if nearCover(pos) then return end
		st.lastExposeAt = now
		local hl = Instance.new("Highlight")
		hl.Name = "BH_Expose"
		hl.FillColor = EXPOSE_COLOR
		hl.OutlineColor = EXPOSE_COLOR
		hl.FillTransparency = 0.55
		hl.OutlineTransparency = 0
		-- AlwaysOnTop: exposure must read THROUGH cover at 300 studs -- that
		-- is the whole threat of it.
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = s.char
		table.insert(exposeMarks, hl)
		task.delay(EXPOSE_SECONDS, function()
			if hl.Parent then hl:Destroy() end
		end)
	end

	local baseAim = cleanDirection(Vector3.new(startPos.X, startPos.Y + 4, startPos.Z) - eye)
		or Vector3.new(0, 0, -1)
	local shotParams = RaycastParams.new()
	shotParams.FilterType = Enum.RaycastFilterType.Exclude
	local sniperSubject = sniperUserId and subjects[sniperUserId]
	shotParams.FilterDescendantsInstances = sniperSubject and { sniperSubject.char } or {}
	roundState = {
		sniperUserId = sniperUserId,
		lastShot = 0,
		lastAimAt = 0,
		baseAim = baseAim,
		aimDir = baseAim,
		acceptAim = true,
		active = false,
		-- Phase 3c review fix: reload-lamp generation counter -- see shoot().
		reloadGen = 0,
		-- Phase 3c: the push handler's phase check reads the room off the leg.
		room = room,
		-- Phase 3c: Minefield's freshness token, Bird-shaped (Bird's legacy
		-- remotes key off activeByHunter identity; runner input cannot, so the
		-- token stands in). Handed to runners in the role packet below and
		-- echoed by every push; a push replayed from an earlier leg fails the
		-- echo even while this leg is live. Freshness, not authorisation --
		-- membership, role, liveness and rate checks still run around it.
		roundToken = ("BH-%s-L%s-%d"):format(
			tostring(room.sessionId), tostring(legIndex or roundIndex or 1),
			math.floor(os.clock() * 1000) % 100000),
	}

	-- The machine at the parapet, driven from the SAME validated aimDir the
	-- shot raycast uses. One source for both is what stops the barrel the
	-- runners see from disagreeing with the line the server fires along --
	-- two would drift apart under packet loss and make hits look wrong.
	local turret = buildTurret(R.folder)
	roundState.turret = turret
	-- 24.08.2026 (user): the hunter holds the standing rifle pose while idle
	-- (visible to anyone who can see the post; cleared with the leg).
	if sniperSubject and sniperSubject.char then
		sniperSubject.char:SetAttribute("XBotRifle", true)
	end
	aimTurret(turret, eye, baseAim)
	-- Phase 3c: THE RELOAD LAMP. A neon bar over the post -- the bolt state
	-- readable at 300 studs with the sound OFF (the telegraph contract: neon
	-- emissive plus sound, never Light-only; the existing 0.45 s SniperReload
	-- sound stays its audio half). Amber = bolt open, sprint now; Signal-cyan
	-- = loaded, be behind something. Parented to the arena folder, NOT the
	-- turret model: aimTurret PivotTo's the whole model every 0.06 s and would
	-- swing the lamp with the barrel. CanQuery false keeps it out of the shot
	-- and beam raycasts (the buildTurret rule); stopRound destroys it.
	local lamp = Instance.new("Part")
	lamp.Name = "BH_ReloadLamp"
	lamp.Size = Vector3.new(2.2, 0.6, 0.6)
	lamp.Material = Enum.Material.Neon
	lamp.Color = LAMP_RELOAD_COLOR
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.CanTouch = false
	lamp.CastShadow = false
	lamp.CFrame = CFrame.new(eye + Vector3.new(0, 3.4, 0))
	lamp.Parent = R.folder
	roundState.lamp = lamp
	-- Its own tick: the main loop runs at 0.2 s, and a gun that moves five
	-- times a second reads as broken. Bounded by `stopped`, so it ends with
	-- the leg instead of outliving it.
	task.spawn(function()
		-- #50: PivotTo only when the aim actually changed -- between input
		-- packets the direction is constant and the write would replicate a
		-- whole model of CFrames for nothing.
		local lastDir = nil
		while not stopped and turret.Parent do
			local dir = roundState.aimDir or baseAim
			if dir ~= lastDir then
				lastDir = dir
				aimTurret(turret, eye, dir)
			end
			task.wait(0.06)
		end
	end)
	roundState.shoot = function(dir)
		if not roundState.active then return end
		local origin = eye
		BloodFX.sound(origin, "SniperFire", audience)
		-- Phase 3c: the lamp flips amber the instant a shot is ACCEPTED and
		-- back to ready when the SAME lockout the fire handler enforces has
		-- passed. One number (FIRE_COOLDOWN = Feel.Birdhunt.ReloadSeconds)
		-- feeds both, so the lamp can never lie about the gate.
		-- Review fix (30.08.): generation-guarded. The fire gate opens at
		-- elapsed > FIRE_COOLDOWN while this delay resumes at elapsed >=
		-- FIRE_COOLDOWN -- both can land on the SAME Heartbeat, and if the
		-- next shot's handler runs first, the STALE delay would flip the lamp
		-- ready with a full lockout still running. Only the latest accepted
		-- shot's callback may arm the lamp; superseded ones are inert, so the
		-- lamp is conservative in every interleaving.
		if lamp.Parent then lamp.Color = LAMP_RELOAD_COLOR end
		roundState.reloadGen += 1
		local myReloadGen = roundState.reloadGen
		task.delay(FIRE_COOLDOWN, function()
			if roundState.active and lamp.Parent and roundState.reloadGen == myReloadGen then
				lamp.Color = LAMP_READY_COLOR
			end
		end)
		task.delay(0.45, function()
			if roundState.active then BloodFX.sound(origin, "SniperReload", audience) end
		end)
		local hit = workspace:Raycast(origin, dir * 600, shotParams)
		local endPos = hit and hit.Position or (origin + dir * 600)
		tracer(origin, endPos)
		if not hit then return end
		local char = hit.Instance:FindFirstAncestorOfClass("Model")
		-- Phase 3c: DECOY DOWN. The bird pays BIRD_DETAIL into the hunter's
		-- one accumulator -- and has already consumed the shot and the reload
		-- like any shot (the cooldown was spent in the fire handler before
		-- this ran). That is the bluff's cost. Machine bird, machine feedback:
		-- sparks and ricochet, never blood.
		if char and char:GetAttribute("BHBird") == true then
			local birdSst = sniperUserId and state[sniperUserId]
			if birdSst then birdSst.points += BIRD_DETAIL end
			coverSpark(hit.Position, hit.Normal)
			BloodFX.sound(hit.Position, "BulletRicochet", audience)
			if sniperUserId then tellOne(sniperUserId, { kind = "hitmark", head = false }) end
			dropBird(char)
			return
		end
		local plr = char and Players:GetPlayerFromCharacter(char)
		if not plr or plr.UserId == sniperUserId then
			coverSpark(hit.Position, hit.Normal)
			BloodFX.sound(hit.Position, "BulletRicochet", audience)
			return
		end
		local st = state[plr.UserId]
		local s = subjects[plr.UserId]
		if not (st and not st.done and s and s.hum.Health > 0) then return end
		local sst = state[sniperUserId]
		-- REQ-IP-01: head (or anything riding on it) is an instant kill
		local head = char:FindFirstChild("Head")
		local isHead = hit.Instance.Name == "Head"
			or (head and (hit.Position - head.Position).Magnitude < 1.4)

		local function dropRunner()
			st.progress = math.max(st.progress, progressAt(s.root.Position.Z))
			st.done = true
			-- P1.4: this kill never touches Humanoid.Health (the body is a
			-- corpse clone and the runner is moved out later), so MachineFlow's
			-- death tally cannot see it through Humanoid.Died. The attribute
			-- bump is the one signal it watches instead.
			-- 24.08.2026 (evening, user): the runner FALLS where they stand --
			-- Humanoid.Health = 0 lets PS1Animate play the field death and park
			-- it on the last keyframe; no corpse clone, no fling. One localized
			-- blood hit; the black beat + viewer mode follow from the spectate
			-- packet below.
			BloodFX.hit(hit.Position, audience)
			BloodFX.sound(hit.Position, "ImpactBody", audience)
			local downedHum = char and char:FindFirstChildOfClass("Humanoid")
			if downedHum then
				downedHum.WalkSpeed = 0
				downedHum.Jump = false
				downedHum.Health = 0
			end
			-- viewer mode for the dead: every LIVING RUNNER is watchable; the
			-- sniper is NEVER on the list (user rule).
			task.delay(2.0, function()
				if not roundState.active then return end
				local watch = {}
				for wuid, wst in state do
					if not wst.done and not wst.sniper then table.insert(watch, wuid) end
				end
				local camPos = eye + Vector3.new(0, 14, 0)
				tellOne(plr.UserId, { kind = "role", role = "spectate",
					watch = watch,
					pos = { camPos.X, camPos.Y, camPos.Z },
					look = { spawnPos.X, spawnPos.Y, spawnPos.Z } })
			end)
			local exitCFrame = CFrame.new(spawnPos
				+ Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
			task.delay(KILL_VIEW_TIME, function()
				-- Guarded on the round still running. A leg that ends during the
				-- hold is already torn down by stopRound, and re-freezing someone
				-- who is back in the lobby would strand them at WalkSpeed 0.
				if not roundState.active then return end
				-- keepCamera: the body is parked and frozen, but the view stays
				-- on the living runners until the leg ends (MP-08 B-03).
				clearParticipant(plr.UserId, s, true)
				if s.root and s.root.Parent then s.root.CFrame = exitCFrame end
			end)
		end

		-- Phase 3c: the hitmark handler comes alive. KenopsiaClient has
		-- rendered {kind="hitmark"} since Gate 1 (TERMINATED / IMPACT off
		-- p.head, Feel.Fade.HitMark fade) and nothing ever sent it -- its own
		-- comment says so. head=true is any TERMINAL hit (a body finish is
		-- still a termination on the hunter's glass); head=false is a wing.
		if isHead then
			if sst then sst.points += HEADSHOT_POINTS end
			tellOne(sniperUserId, { kind = "hitmark", head = true })
			dropRunner()
		elseif s.hum.Health <= BODY_DAMAGE then
			if sst then sst.points += KILL_POINTS end
			tellOne(sniperUserId, { kind = "hitmark", head = true })
			dropRunner()
		else
			s.hum.Health -= BODY_DAMAGE
			BloodFX.hit(hit.Position, audience)
			BloodFX.sound(hit.Position, "ImpactBody", audience)
			if sst then sst.points += HIT_POINTS end
			tellOne(sniperUserId, { kind = "hitmark", head = false })
			-- 23.08.2026: winged. The limp lasts the rest of the leg -- placement
			-- of the next leg clears the attribute and restores the speed.
			-- Phase 3c: INJURED_SPEED is now Feel.Birdhunt.InjuredSpeed (3.5).
			s.char:SetAttribute("Injured", true)
			s.hum.WalkSpeed = math.min(s.hum.WalkSpeed, INJURED_SPEED)
		end
	end
	-- Phase 3c: PUSH. Reached only through the TrialInput handler in
	-- ensureRemote, which has already proven leg identity (token), active and
	-- phase. Everything per-player is proven HERE on the leg's own tables --
	-- the activeByHunter style: identity, never client claims. The Push clip
	-- (AnimationIds.Push, preloaded since Gate 1) is deliberately NOT played:
	-- PS1Animate's attribute set is gait-only (Crouching / XBotCrawl /
	-- Injured / XBotRifle -- no one-shot action channel), and granting "push"
	-- in XBotMoves would surface the dead legacy Btn_PUNCH. The falling crate
	-- IS the feedback.
	roundState.push = function(player)
		if not roundState.active then return end
		local st = state[player.UserId]
		local s = subjects[player.UserId]
		if not (st and not st.sniper and not st.done and s and s.hum.Health > 0) then return end
		if player.Character ~= s.char then return end
		local now = os.clock()
		if now - (st.lastPushAt or 0) < 0.4 then return end
		st.lastPushAt = now
		if (st.pushesLeft or 0) <= 0 then return end
		local rootPos = s.root.Position
		local best, bestDist
		for _, entry in ipairs(pushables) do
			if not entry.toppled and entry.inst.Parent then
				local d = (Vector3.new(entry.pos.X, 0, entry.pos.Z)
					- Vector3.new(rootPos.X, 0, rootPos.Z)).Magnitude
				if d <= PUSH_RANGE and (not bestDist or d < bestDist) then
					best, bestDist = entry, d
				end
			end
		end
		if not best then return end
		st.pushesLeft -= 1
		best.toppled = true
		toppleProp(best, rootPos)
	end
	-- Aim is accepted during the countdown so the first shot uses the reticle,
	-- while fire remains blocked until GO.
	if sniperUserId then activeByHunter[sniperUserId] = roundState end
	-- Phase 3c: the push handler resolves the live leg through this. Cleared
	-- by stopRound; pushes stay dead until roundState.active anyway.
	currentLeg = roundState

	-- Roles first (cameras switch, everyone stays frozen), then 3-2-1, then go.
	-- The round state stays inactive through the count, so firing early is impossible.
	if MachineState then
		for _, m in room.members do
			local plr = Players:GetPlayerByUserId(m.userId)
			if plr then
				MachineState:FireClient(plr, {
					kind = "role",
					role = (m.userId == sniperUserId) and "sniper" or "runner",
					frozen = true,
					-- Phase 3c: runners carry the leg token for the push
					-- sender -- RunnerClient caches it exactly the way
					-- SonarClient caches the DZ token (same packet shape as
					-- Minefield's runner role packet). KenopsiaClient ignores
					-- fields it does not read.
					roundToken = (m.userId ~= sniperUserId) and roundState.roundToken or nil,
				})
			end
		end
		local hunter = sniperUserId and Players:GetPlayerByUserId(sniperUserId)
		if hunter then
			MachineState:FireClient(hunter, { kind = "huntersetup" })
			task.wait(4)
			-- C5: 4s is the single longest unguarded window in the leg. Without
			-- this an abort here still reaches the countdown and the GO.
			if not roomActive(room) then return scores end
		end
	end
	for n = 3, 1, -1 do
		-- C5: top of the body, so an abort mid-count never pushes another
		-- number to clients.
		if not roomActive(room) then return scores end
		tellAll({ kind = "count", n = n })
		task.wait(Feel.Countdown.StepSeconds)
	end
	-- C5: point of no return. Past this line the round is committed - runners
	-- are unfrozen to MAX_RUNNER_SPEED, roundState.active goes true (unblocking
	-- SniperFire), and the beam, Heartbeat and exit-Touched connections exist.
	if not roomActive(room) then return scores end
	tellAll({ kind = "go" })
	-- Mirror the client unlock on the server. This keeps authoritative movement,
	-- crouch validation, and anti-teleport state in agreement from the first frame.
	for uid, st in state do
		local subject = subjects[uid]
		if subject and not st.sniper then
			-- 23.08.2026: placement cleared `Injured` for this leg, so this is
			-- the full speed; the guard keeps a limp a limp should that ever
			-- change (an injured runner is never restored to full speed mid-leg).
			subject.hum.WalkSpeed = subject.char:GetAttribute("Injured") == true
				and INJURED_SPEED or MAX_RUNNER_SPEED
		end
	end
	roundState.active = true
	-- Phase 3c: the leg opens with a loaded rifle -- the lamp said amber all
	-- through the count (fire was blocked) and goes ready exactly at GO.
	if lamp.Parent then lamp.Color = LAMP_READY_COLOR end
	spawnBirds()
	print("[BH] go; members=" .. #room.members)

	-- The Hunter's aim is a red line every runner can read. Aim arrives at
	-- 20 Hz, so a cached 20 Hz server ray is enough; no 60 Hz allocations.
	if sniperUserId then
		beam = Instance.new("Part")
		beam.Name = "SniperBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 24, 24)
		beam.Transparency = 0.25
		beam.Size = Vector3.new(0.12, 0.12, 1)
		beam.Parent = R.folder
	end
	local beamParams = RaycastParams.new()
	beamParams.FilterType = Enum.RaycastFilterType.Exclude
	beamParams.FilterDescendantsInstances = sniperSubject and { sniperSubject.char } or {}
	local beamAccum = 0
	hbConn = RunService.Heartbeat:Connect(function(dt)
		if not beam then return end
		beamAccum += dt
		if beamAccum < 0.05 then return end
		beamAccum = 0
		local dir = roundState.aimDir
		local hit = workspace:Raycast(eye, dir * 600, beamParams)
		local endPos = hit and hit.Position or (eye + dir * 600)
		local up = Vector3.new(0, 1, 0)
		local side = dir:Cross(up)
		side = side.Magnitude > 1e-3 and side.Unit or Vector3.new(1, 0, 0)
		local origin = eye + dir * 1.6 + side * 0.5 - up * 0.62
		local dist = (endPos - origin).Magnitude
		beam.Size = Vector3.new(0.12, 0.12, dist)
		beam.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -dist / 2)
	end)

	-- Escape is server-authoritative: touching the trigger only counts after a
	-- plausible, in-bounds run to the far end of the lane.
	exitConn = R.exit.Touched:Connect(function(part)
		local char = part.Parent
		local plr = char and Players:GetPlayerFromCharacter(char)
		if not plr then return end
		local st = state[plr.UserId]
		local subject = subjects[plr.UserId]
		local now = os.clock()
		if not (st and not st.done and not st.sniper and subject and subject.char == char and subject.hum.Health > 0) then return end
		if not runnerPositionValid(st, subject, now)
			or not st.groundedNow
			or progressAt(subject.root.Position.Z) < 0.98
			or now - (roundStart or now) < minEscapeTime then
			rollbackRunner(st, subject, now)
			return
		end
		st.done = true
		st.escaped = true
		st.escapeTimeLeft = math.max(0, ROUND_TIME - (now - (roundStart or now)))
		clearParticipant(plr.UserId, subject)
		subject.root.CFrame = CFrame.new(spawnPos + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
		if MachineState then MachineState:FireClient(plr, { kind = "announce", text = "" }) end
	end)

	local t0 = os.clock()
	roundStart = t0
	for uid, st in state do
		local subject = subjects[uid]
		if subject and not st.sniper then rememberRunnerPosition(st, subject, t0) end
	end
	local finished = false
	while os.clock() - t0 < ROUND_TIME do
		task.wait(0.2)
		if room.phase ~= nil and room.phase ~= "Playing" then break end
		local allDone = true
		local liveSubjects = livingOf(room)
		if sniperUserId and roundState.active then
			local liveHunter = liveSubjects[sniperUserId]
			if not (sniperSubject and liveHunter and liveHunter.char == sniperSubject.char) then
				print("[BH] hunter lost/reset: " .. sniperUserId)
				clearParticipant(sniperUserId, sniperSubject)
				roundState.active = false
				roundState.acceptAim = false
				if activeByHunter[sniperUserId] == roundState then activeByHunter[sniperUserId] = nil end
				if beam then beam:Destroy() beam = nil end
			end
		end
		for uid, st in state do
			if not st.done then
				local s = liveSubjects[uid]
				if s and (not subjects[uid] or s.char ~= subjects[uid].char) then s = nil end
				if s then
					allDone = false
					local now = os.clock()
					-- #50: the jump lock is a one-time write per character --
					-- four Humanoid property writes per runner per 0.2 s were
					-- replication noise. Re-armed when the character changes
					-- (livingOf hands out a fresh table then).
					if not st.sniper and st.jumpLockedChar ~= s.char then
						st.jumpLockedChar = s.char
						s.hum.UseJumpPower = true
						s.hum.JumpPower = 0
						s.hum.JumpHeight = 0
						s.hum.Jump = false
					end
					if st.sniper or runnerPositionValid(st, s, now) then
						if not st.sniper and st.groundedNow then
							rememberRunnerPosition(st, s, now)
							st.progress = math.max(st.progress, progressAt(s.root.Position.Z))
						end
						-- Phase 3c: exposure rides the loop's own samples.
						if not st.sniper then sampleExposure(st, s, now) end
					else
						rollbackRunner(st, s, now)
					end
				elseif not st.sniper then
					print("[BH] subject lost/reset (no original living char): " .. uid)
					st.done = true
					clearParticipant(uid, subjects[uid])
				else
					allDone = false
				end
			end
		end
		-- THE IN-ROUND HUD (27.08.2026, user). A 60 s leg used to run with no
		-- clock, no leg counter and no idea how far the exit was: RoomService has
		-- broadcast legIndex/legCount since Gate 1 and no client has ever read
		-- them, and nothing at all carried the time.
		--
		-- Every number below is ALREADY computed by this loop -- the clock from
		-- t0, the runners left from `state`, each runner's progress from
		-- progressAt via st.progress. This is a readout, never a second source of
		-- truth, so it cannot drift from what the round is actually doing.
		--
		-- Per player rather than tellAll: `progress` and `role` differ per seat.
		-- At the loop's own 5 Hz and 4 players that is 20 packets a second, each
		-- a handful of numbers.
		-- legIndex/legTotal arrive only on the hunter path: MachineFlow passes
		-- them when it forces a seat (isBird and >= 2 members) and calls
		-- runRoundGuarded(trial, room, roundIndex) with neither otherwise -- which
		-- is every solo Studio test, and any leg that runs without a hunter. The
		-- leg number is not actually unknown there: roundIndex IS the leg, and
		-- Pacing sized the count. Fall back rather than let the label blank out.
		local hudLeg = legIndex or roundIndex
		local hudLegs = legTotal or Pacing.legsFor(#room.members) or hudLeg
		local outLeft, outOf = 0, 0
		for _, st in state do
			if not st.sniper then
				outOf += 1
				if not st.done then outLeft += 1 end
			end
		end
		for uid, st in state do
			tellOne(uid, {
				kind = "hud",
				clock = math.max(0, ROUND_TIME - (os.clock() - t0)),
				leg = hudLeg, legs = hudLegs,
				left = outLeft, of = outOf,
				role = st.sniper and "hunter" or (st.done and "out" or "runner"),
				-- The hunter has no lane of their own to be along.
				progress = (not st.sniper) and st.progress or nil,
			})
		end
		if allDone then
			finished = true
			print("[BH] all done at t=" .. math.floor((os.clock() - t0) * 10) / 10)
			break
		end
		if #room.members == 0 then break end
	end
	print("[BH] round over, elapsed=" .. math.floor((os.clock() - t0) * 10) / 10)
	tellAll({ kind = "announce", text = "" })

	stopRound()
	-- grace: the black transition holds while the arena resets
	task.wait(2.6)

	-- Keep earned Hunter/escape points. Only a timed-out runner receives
	-- forward-distance points, clamped to the actual Start -> Exit direction.
	for uid, st in state do
		if st.sniper then
			-- Phase 3c: tags and decoys share the one accumulator; the clamp
			-- is Minefield's DETAIL_CAP pattern, so no hunter raw can run away
			-- from the field. Max legit: 3 x (wing 15 + headshot 100) = 345,
			-- plus BIRD_COUNT x BIRD_DETAIL (400) = 745 -- the clamp is a
			-- fence, not a ceiling anyone reaches in play. tests/feel.lua
			-- re-proves the sum with these exact tag values.
			scores[uid] = math.min(st.points, DETAIL_CAP)
		elseif st.escaped then
			scores[uid] = 100 + math.floor((st.escapeTimeLeft or 0) * 2)
		elseif not finished then
			scores[uid] = math.floor(st.progress * 100)
		else
			scores[uid] = 0
		end
	end
	cleanupRound()
	guard.cleanup = nil

	return scores
end

local function waitForArena(room)
	local announced = false
	while arenaBusy do
		if #room.members == 0 or (room.phase ~= nil and room.phase ~= "Playing") then
			return false
		end
		if not announced then
			announced = true
			local remote = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")
			if remote then
				for _, member in room.members do
					local plr = Players:GetPlayerByUserId(member.userId)
					if plr then
						remote:FireClient(plr, { kind = "announce", text = "HUNTING RANGE BUSY. STANDBY." })
					end
				end
			end
		end
		task.wait(0.25)
	end
	arenaBusy = true
	return true
end

-- #50: watchdog-side cleanup after a task.cancel (see Minefield.abort).
function BirdHunting.abort()
	local g = BirdHunting._guard
	BirdHunting._guard = nil
	if g and g.cleanup then pcall(g.cleanup) end
	arenaBusy = false
end

function BirdHunting.runRound(room, roundIndex, forcedHunterUserId, legIndex, legTotal)
	local emptyScores = {}
	for _, member in room.members do emptyScores[member.userId] = 0 end
	if not waitForArena(room) then return emptyScores end

	local guard = {}
	BirdHunting._guard = guard
	local ok, result = xpcall(function()
		return runLeg(room, roundIndex, forcedHunterUserId, legIndex, legTotal, guard)
	end, debug.traceback)
	BirdHunting._guard = nil
	if guard.cleanup then pcall(guard.cleanup) end
	arenaBusy = false
	if not ok then error(result, 0) end
	return result
end

return BirdHunting
