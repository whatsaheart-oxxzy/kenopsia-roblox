--!nonstrict
-- CANTEEN BOSS -- visual actor for the Canteen Protocol observer state.
--
-- The gameplay authority remains CanteenProtocol. This module owns only the
-- low-poly actor, its four published animation tracks and the serial execution
-- queue. Every callback is generation-guarded so an aborted round cannot fire
-- a late shot into the lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AnimationIds = require(ReplicatedStorage:WaitForChild("Kenopsia")
	:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AnimationIds"))

local CanteenBoss = {}

local FRAME_RATE = 30
local PISTOL_FRAME = 14
local PRIMARY_FIRE_FRAME = 28
local SECOND_FIRE_FRAME = 36
local SHOT_END_FRAME = 49
local LOOK_UP_TELL_FRAME = 11
local LOOK_DOWN_FRAMES = 20
local READING_FRAME_TIME = 0

-- The clips are SEATED: every one of them drops the root by this much against
-- the A-pose the template ships in (authored in Blender as SEAT_DROP; measured
-- live at 0.650 on Idle, LookUp, LookDown and Shoot alike). The figure must
-- therefore be placed by where its pelvis ends up ONCE A CLIP IS PLAYING, not
-- by where the bind pose puts it -- otherwise he hovers half a stud above his
-- chair for the whole round.
local SEAT_DROP = 0.65
local SCALE_LIMITS = { min = 0.4, max = 3.0 }

-- Phase 3a (29.08.2026): the glance (CanteenBoss.glance) runs LookDown at clip
-- rate. Exported so CanteenProtocol can fit a fake-lower inside a hidden read
-- without duplicating the frame numbers here.
CanteenBoss.GlanceSeconds = LOOK_DOWN_FRAMES / FRAME_RATE

local function findTemplate()
	local assets = ServerStorage:FindFirstChild("KenopsiaAssets")
	local rigs = assets and assets:FindFirstChild("Rigs")
	local template = rigs and rigs:FindFirstChild("CanteenBoss")
	if template then return template end

	-- Compatibility with the documented prop slot while older places migrate.
	local props = assets and assets:FindFirstChild("Props")
	local canteen = props and props:FindFirstChild("CanteenProtocol")
	return canteen and canteen:FindFirstChild("CP_Boss")
end

-- Pelvis height above the model's own origin while seated, in rig units.
-- Measured off the template so a re-export re-derives it.
local function seatedPelvisOffset(template)
	local root = template:FindFirstChild("RootPart")
	local pelvis = template:FindFirstChild("LowerTorso", true)
	if not (root and pelvis and pelvis:IsA("Bone")) then return nil end
	return (pelvis.WorldCFrame.Position.Y - root.Position.Y) - SEAT_DROP
end

local function setPistolVisible(self, visible)
	local pistol = self.pistol
	if pistol and pistol.Parent then
		pistol.Transparency = visible and 0 or 1
	end
end

-- The glare: the angry atlas goes on the head while the eyes are up -- or,
-- Phase 3a, for the rest of the round once the table has made him suspicious
-- (setSuspicious below): the paper comes back up, the face does not forgive.
local function setAngry(self, angry)
	local head = self.model and self.model:FindFirstChild("Boss_Head", true)
	if not (head and head:IsA("MeshPart")) then return end
	local uri = (angry or self.suspicious) and AnimationIds.texture("BossAngry") or nil
	head.TextureID = uri or self.neutralFace or head.TextureID
end

local function stopTracks(self, except)
	for _, track in self.tracks do
		if track ~= except and track.IsPlaying then
			track:Stop(0.08)
		end
	end
end

local function playTrack(self, name, looped, priority, speed)
	local track = self.tracks[name]
	if not track then return nil end
	stopTracks(self, track)
	if track.IsPlaying then track:Stop(0.04) end
	track.Looped = looped == true
	track.Priority = priority or Enum.AnimationPriority.Movement
	track:Play(0.08, 1, speed or 1)
	return track
end

local function holdReading(self)
	setPistolVisible(self, false)
	-- 22.08.2026: Reading is its own published loop now. If LookDown is still
	-- finishing (raising ran out a frame before the server said "hidden"), let
	-- it land on the paper first; its Stopped handler (see spawn) hands over to
	-- Reading, so the paper never snaps.
	local lookDown = self.tracks.LookDown
	if lookDown and lookDown.IsPlaying and self.phase == "hidden" then return end
	local track = playTrack(self, "Reading", true, Enum.AnimationPriority.Idle)
	if not track then
		-- No reading clip: frame zero of LookUp is the authored paper pose.
		track = playTrack(self, "LookUp", false, Enum.AnimationPriority.Idle)
		if track then
			track.TimePosition = READING_FRAME_TIME
			track:AdjustSpeed(0)
		end
	end
end

local function applyPhase(self)
	if not self.alive or self.executing then return end
	local phase = self.phase
	-- any phase change puts the scan sweep back to centre
	if self.basePivot and phase ~= "watching" and self.model and self.model.Parent then
		self.model:PivotTo(self.basePivot)
	end
	if phase == "lowering" then
		setPistolVisible(self, false)
		setAngry(self, true)
		-- Frame 11 is the authored EyesUp/decision pose. Only that tell segment
		-- must land at the end of lowering; frames 11-44 are a glare hold that
		-- the watching Idle replaces.
		local duration = math.max(0.05,
			tonumber(self.phaseDuration) or (LOOK_UP_TELL_FRAME / FRAME_RATE))
		playTrack(self, "LookUp", false, Enum.AnimationPriority.Movement,
			(LOOK_UP_TELL_FRAME / FRAME_RATE) / duration)
	elseif phase == "watching" then
		setPistolVisible(self, false)
		setAngry(self, true)
		playTrack(self, "Idle", true, Enum.AnimationPriority.Idle)
		-- 24.08.2026 (user): the boss scans BOTH ways while watching -- a
		-- stepped yaw sweep (right, left, centre), PS1-stepped on purpose.
		-- The pivot is restored the moment the phase moves on.
		if self.model and self.model.Parent then
			local base = self.basePivot or self.model:GetPivot()
			self.basePivot = base
			task.spawn(function()
				for _, yaw in ipairs({ -9, 9, 0 }) do
					for _ = 1, 3 do
						task.wait(0.14)
						if self.phase ~= "watching" or not self.model.Parent then
							self.model:PivotTo(base)
							return
						end
					end
					self.model:PivotTo(base * CFrame.Angles(0, math.rad(yaw), 0))
				end
			end)
		end
	elseif phase == "raising" then
		setPistolVisible(self, false)
		setAngry(self, false)
		local duration = math.max(0.05, tonumber(self.phaseDuration) or (LOOK_DOWN_FRAMES / FRAME_RATE))
		playTrack(self, "LookDown", false, Enum.AnimationPriority.Movement,
			(LOOK_DOWN_FRAMES / FRAME_RATE) / duration)
	else
		setAngry(self, false)
		holdReading(self)
	end
end

local function waitCurrent(self, shot, duration)
	local deadline = os.clock() + duration
	while os.clock() < deadline do
		if not self.alive or self.currentShot ~= shot then return false end
		task.wait(math.min(0.03, deadline - os.clock()))
	end
	return self.alive and self.currentShot == shot
end

local function fireOnce(self, shot)
	if shot.fired or not self.alive or self.currentShot ~= shot then return end
	shot.fired = true
	local ok, err = pcall(shot.onFire)
	if not ok then warn("[CanteenBoss] fire callback failed: " .. tostring(err)) end
end

local function finishShot(shot)
	if shot.finished then return end
	shot.finished = true
	local ok, err = pcall(shot.onDone)
	if not ok then warn("[CanteenBoss] completion callback failed: " .. tostring(err)) end
end

local function pump(self)
	if self.executing or not self.alive then return end
	self.executing = true
	task.spawn(function()
		while self.alive and #self.queue > 0 do
			local shot = table.remove(self.queue, 1)
			self.currentShot = shot
			setPistolVisible(self, false)
			playTrack(self, "Shoot", false, Enum.AnimationPriority.Action)

			if waitCurrent(self, shot, PISTOL_FRAME / FRAME_RATE) then
				setPistolVisible(self, true)
			end
			if waitCurrent(self, shot, (PRIMARY_FIRE_FRAME - PISTOL_FRAME) / FRAME_RATE) then
				fireOnce(self, shot)
			end
			-- The clip has a second muzzle event at frame 36. It remains visual:
			-- gameplay damage and blood are deliberately deduplicated above.
			waitCurrent(self, shot, (SECOND_FIRE_FRAME - PRIMARY_FIRE_FRAME) / FRAME_RATE)
			waitCurrent(self, shot, (SHOT_END_FRAME - SECOND_FIRE_FRAME) / FRAME_RATE)

			if self.currentShot == shot then self.currentShot = nil end
			finishShot(shot)
		end
		self.executing = false
		setPistolVisible(self, false)
		applyPhase(self)
	end)
end

-- opts = { scale = <arena-derived world scale>, seatY = <chair surface Y> }
function CanteenBoss.spawn(marker, parent, opts)
	local template = findTemplate()
	if not (template and marker and parent) then return nil end
	opts = opts or {}
	local pelvisOffset = seatedPelvisOffset(template)

	local model = template:Clone()
	model.Name = "CanteenBoss"
	local initialPoses = model:FindFirstChild("InitialPoses")
	if initialPoses then initialPoses:Destroy() end
	local animSaves = model:FindFirstChild("AnimSaves")
	if animSaves then animSaves:Destroy() end

	local root = model:FindFirstChild("RootPart")
	if not (root and root:IsA("BasePart")) then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	-- Same world scale as the diners: he sits at THEIR table, so a scale of his
	-- own would read as a different room. BossScale multiplies it rather than
	-- replacing it.
	local scale = math.clamp(
		(tonumber(opts.scale) or 1) * (tonumber(marker:GetAttribute("BossScale")) or 1),
		SCALE_LIMITS.min, SCALE_LIMITS.max)
	if math.abs(scale - 1) > 0.001 then model:ScaleTo(scale) end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
			if d:IsA("MeshPart") then
				d.Color = Color3.new(1, 1, 1)
				d.Material = Enum.Material.SmoothPlastic
				-- RenderFidelity is a Plugin-security property at runtime. The
				-- ServerStorage template is configured to Performance in Edit mode,
				-- and Clone preserves it; writing it here aborts the live round.
			end
		end
	end
	root.Transparency = 1

	local newspaper = model:FindFirstChild("Boss_Newspaper", true)
	if newspaper and newspaper:IsA("MeshPart") then newspaper.DoubleSided = true end
	local pistol = model:FindFirstChild("Boss_Pistol", true)
	if pistol and pistol:IsA("BasePart") then pistol.Transparency = 1 end
	local bossHead = model:FindFirstChild("Boss_Head", true)

	-- Seat him on the chair the user actually built. PivotTo(marker.CFrame) put
	-- his FEET on a marker that stands at hip height, which left him standing in
	-- mid-air above the seat; the pelvis is the part that belongs on a chair.
	if pelvisOffset and opts.seatY then
		local facing = marker.CFrame - marker.CFrame.Position
		model:PivotTo(CFrame.new(marker.Position.X, opts.seatY - pelvisOffset * scale, marker.Position.Z) * facing)
	else
		model:PivotTo(marker.CFrame)
	end
	model.Parent = parent

	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local self = setmetatable({
		alive = true,
		model = model,
		pistol = pistol,
		neutralFace = (bossHead and bossHead:IsA("MeshPart")) and bossHead.TextureID or nil,
		-- Phase 3a: room suspicion keeps the angry atlas up (see setAngry).
		suspicious = false,
		phase = "hidden",
		tracks = {
			Reading = AnimationIds.load(animator, "Boss", "Reading"),
			LookUp = AnimationIds.load(animator, "Boss", "LookUp"),
			LookDown = AnimationIds.load(animator, "Boss", "LookDown"),
			Idle = AnimationIds.load(animator, "Boss", "Idle"),
			Shoot = AnimationIds.load(animator, "Boss", "Shoot"),
		},
		queue = {},
		executing = false,
		currentShot = nil,
		connections = {},
	}, { __index = CanteenBoss })

	local shoot = self.tracks.Shoot
	if shoot then
		table.insert(self.connections, shoot:GetMarkerReachedSignal("PistolShow"):Connect(function()
			if self.currentShot then setPistolVisible(self, true) end
		end))
		table.insert(self.connections, shoot:GetMarkerReachedSignal("Fire"):Connect(function()
			local shot = self.currentShot
			if shot then fireOnce(self, shot) end
		end))
	end

	local lookDown = self.tracks.LookDown
	if lookDown then
		-- LookDown ends on the paper; Reading takes over from exactly there.
		table.insert(self.connections, lookDown.Stopped:Connect(function()
			if self.alive and not self.executing and (self.phase == "hidden" or self.phase == "raising") then
				holdReading(self)
			end
		end))
	end

	holdReading(self)
	return self
end

function CanteenBoss.setPhase(self, phase, duration)
	if not self.alive then return end
	self.phase = phase
	self.phaseDuration = duration
	applyPhase(self)
end

-- Phase 3a: the room's suspicion, made face. While set, applyPhase keeps
-- calling setAngry and the OR inside it keeps answering "angry", so the glare
-- survives raising and hidden alike. One-way in practice: CanteenProps
-- rebuilds the actor every round, so a fresh round is a fresh face.
function CanteenBoss.setSuspicious(self, on)
	if not self.alive then return end
	self.suspicious = on and true or false
	setAngry(self, self.phase == "lowering" or self.phase == "watching")
end

-- Phase 3a: FAKE-LOWER -- a theatrical glance with NO phase behind it.
-- LookDown played from the reading pose reads as the head twitching up and
-- settling back onto the paper; the existing Stopped handler (see spawn)
-- hands over to Reading, so the paper never snaps. Deliberately refused
-- outside `hidden` and while a shot is playing: the glance is theater, and
-- theater never outranks the rule's picture (the phases CanteenProtocol
-- announces stay the only truth about detection).
function CanteenBoss.glance(self)
	if not self.alive or self.executing or self.currentShot then return end
	if self.phase ~= "hidden" then return end
	playTrack(self, "LookDown", false, Enum.AnimationPriority.Movement, 1)
end

function CanteenBoss.execute(self, onFire, onDone)
	if not self.alive then
		onFire()
		onDone()
		return
	end
	table.insert(self.queue, {
		onFire = onFire,
		onDone = onDone,
		fired = false,
		finished = false,
	})
	pump(self)
end

function CanteenBoss.destroy(self)
	if not self.alive then return end
	self.alive = false
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for _, shot in self.queue do finishShot(shot) end
	table.clear(self.queue)
	if self.currentShot then finishShot(self.currentShot) end
	self.currentShot = nil
	for _, track in self.tracks do
		pcall(track.Stop, track, 0)
	end
	if self.model.Parent then self.model:Destroy() end
end

return CanteenBoss
