--!nonstrict
-- CANTEEN DINER -- the visible PS1 body at each occupied seat.
--
-- Mirror of CanteenBoss for the eaters. The real Roblox character stays the
-- gameplay subject (Humanoid, Health, BloodFX targets) and is merely made
-- invisible by CanteenProtocol; this actor is the thing the table camera
-- sees.
--
-- THE DINER IS STILL. No idle loop, no breathing, no fidget: a table of
-- motionless figures is the reference game's whole atmosphere, and it is also
-- what makes the Observer's movement the only thing on screen that moves. The
-- seated pose is a BIND-POSE offset (see `sit`), not a clip, so the rig holds
-- it forever at zero cost. Only two moments animate:
--   Eat   for one eat window          -> eat(duration)   (only with a real id)
--   Death once, held on its last frame -> die()
-- Every play is generation-guarded, so a track that outlives its window can
-- never fire on the next round's diner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AnimationIds = require(ReplicatedStorage:WaitForChild("Kenopsia")
	:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AnimationIds"))

local CanteenDiner = {}

-- Seat marker attributes (all optional, tuned in Studio). They MULTIPLY the
-- scale the arena implies rather than replacing it, so a 1.0 means "whatever
-- this table asks for" and not "import scale".
--   DinerScale  1.0   multiplier on the arena-derived scale
--   DinerLift   0.0   extra studs added to the resolved root height
--   DinerSeated true  fold the legs 90 degrees at hip and knee
local SCALE_LIMITS = { min = 0.4, max = 3.0 }

-- 26.08.2026 (user): DIE DINER SIND GROESSER ALS DIE ARENA VERLANGT.
--
-- Der Death-Clip ist in Ordnung und bleibt -- der Koerper soll aber auf dem
-- Tisch landen und nicht darunter, und der Weg dahin ist eine groessere Figur.
--
-- NUR DIE DINER. Der Boss bekommt seine Skalierung direkt als `worldScale` von
-- CanteenProps (CanteenBoss.spawn) und kennt diesen Faktor nicht -- er bleibt
-- also exakt so gross wie bisher. Genau deshalb steht der Faktor hier und nicht
-- in CanteenProps: dort waere er derselbe Wert fuer beide Rigs.
--
-- PREIS, bewusst: CanteenDiner.scaleFor loest die Skalierung so auf, dass das
-- Becken auf der Sitzflaeche UND der Mund am MouthTarget landet -- zwei Anker,
-- eine Unbekannte. Dieser Faktor bricht den zweiten: das Becken bleibt auf dem
-- Stuhl (PivotTo rechnet mit pelvisHeight * scale), der Mund steigt aber ueber
-- den MouthTarget. Die Gabel ist an die Hand geskinnt und faehrt mit der Figur
-- mit, der Versatz ist also kosmetisch und keine Regelaenderung -- aber er ist
-- da, und bei zu grossen Werten sieht man ihn.
--
-- Pro Sitz weiter feinjustierbar ueber das Marker-Attribut DinerScale, das auf
-- diesen Faktor NOCH multipliziert. Ein Sitz, der zu gross geraet, wird also in
-- Studio zurueckgedreht, ohne dass der Code angefasst werden muss.
local DINER_SCALE_BOOST = 1.25

local function findTemplate()
	local assets = ServerStorage:FindFirstChild("KenopsiaAssets")
	local rigs = assets and assets:FindFirstChild("Rigs")
	-- 22.08.2026: PS1Player_Fork carries the fork and its beans skinned to the
	-- right hand, so the cutlery follows every clip for free; the bare rig is
	-- the fallback for places that have not imported it.
	return rigs and (rigs:FindFirstChild("PS1Player_Fork") or rigs:FindFirstChild("PS1Player"))
end

-- Rig proportions in ITS OWN units, measured off the template rather than
-- written down: a re-export at another size then re-scales itself instead of
-- silently sinking into the floor.
--   pelvis = LowerTorso, the bone that rests on a chair
--   mouth  = the Head BONE, which sits in the lower third of the skull mesh --
--            jaw height, which is where a fork is supposed to arrive
function CanteenDiner.metrics()
	local template = findTemplate()
	local root = template and template:FindFirstChild("RootPart")
	if not (root and root:IsA("BasePart")) then return nil end
	local function offset(boneName)
		local b = template:FindFirstChild(boneName, true)
		return b and b:IsA("Bone") and (b.WorldCFrame.Position.Y - root.Position.Y) or nil
	end
	local pelvis, mouth = offset("LowerTorso"), offset("Head")
	if not (pelvis and mouth and mouth > pelvis) then return nil end
	return { pelvis = pelvis, mouth = mouth }
end

-- The scale at which a diner's pelvis reaches `seatY` AND its mouth reaches
-- `mouthY` at the same time. Two anchors, one unknown -- so the figure is never
-- guessed at: it is whatever this arena's chair and MouthTarget imply. Returns
-- nil when the rig or the anchors are unusable, and the caller keeps scale 1.
function CanteenDiner.scaleFor(seatY, mouthY)
	local m = CanteenDiner.metrics()
	if not m then return nil end
	local reach = mouthY - seatY
	if reach <= 0 then return nil end
	local scale = reach / (m.mouth - m.pelvis)
	return math.clamp(scale, SCALE_LIMITS.min, SCALE_LIMITS.max)
end

local function stopAll(self, except, fade)
	for _, track in self.tracks do
		if track ~= except and track.IsPlaying then track:Stop(fade or 0.1) end
	end
end

-- Rotate a bone about a WORLD axis while keeping its position. Bone.CFrame is
-- the replicated bind offset; animation Transforms stack on top of it, which
-- is exactly what a seated base pose wants.
local function rotateBoneWorld(bone, axis, angle)
	local w = bone.WorldCFrame
	local newW = CFrame.new(w.Position) * CFrame.fromAxisAngle(axis, angle) * (w - w.Position)
	local parent = bone.Parent
	local parentW = parent:IsA("Bone") and parent.WorldCFrame or parent.CFrame
	bone.CFrame = parentW:ToObjectSpace(newW)
end

-- The seated pose, built entirely out of bind-pose offsets so it costs nothing
-- to hold and never drifts. Without it the rig keeps its A-pose: legs straight
-- down through the chair and arms held out sideways, which at a dinner table
-- reads as a mannequin rather than a diner.
-- Angles measured on the rig itself, not guessed: at ARM_DROP the hand ends up
-- 2.58 units below the shoulder and 0.01 OUTWARD of it -- arms hanging straight
-- against the ribs -- with ELBOW_BEND carrying the forearm 0.55 forward. Note
-- the diner cannot reach the table and is not meant to: at this arena's scale
-- her shoulders sit level with the tabletop and her arm spans 4.2 studs against
-- a 6.3-stud gap, so a "hands on the table" pose would float them in mid-air.
local HIP_FOLD = math.pi / 2 -- thighs forward, horizontal
local KNEE_FOLD = -math.pi / 2 -- shins back down, vertical
local ARM_DROP = math.rad(60) -- A-pose arms in against the ribs
local ELBOW_BEND = math.rad(25) -- forearms slightly forward

-- 22.08.2026: the RIGHT arm rests in the fork HOVER pose instead -- fist above
-- the plate, tines down (Documents\Retro\PS1Player\scripts\hover_bind.json).
-- Stab and Eat are exported as DELTAS against exactly this pose, so any other
-- rest pose would punch the fork from somewhere else. Axes are in the rig
-- root's space, applied in order after the legs.
local HOVER = {
	{ "RightUpperArm", Vector3.new(0.54693, 0.54207, 0.63798), 110.48 },
	{ "RightLowerArm", Vector3.new(-0.14428, 0.5395, 0.82954), 47.102 },
	{ "RightHand", Vector3.new(-0.01165, 0.07766, 0.99691), 135.547 },
}

local function sit(model, root)
	local right = root.CFrame.RightVector
	local forward = root.CFrame.LookVector
	for _, side in { "Left", "Right" } do
		local upperLeg = model:FindFirstChild(side .. "UpperLeg", true)
		local lowerLeg = model:FindFirstChild(side .. "LowerLeg", true)
		if upperLeg and upperLeg:IsA("Bone") then rotateBoneWorld(upperLeg, right, HIP_FOLD) end
		if lowerLeg and lowerLeg:IsA("Bone") then rotateBoneWorld(lowerLeg, right, KNEE_FOLD) end

		-- Arms swing about the FORWARD axis (mirrored per side) to come down, then
		-- the elbow bends about the same axis the knees use. The Left side takes
		-- the NEGATIVE angle: the mirrored sign lifts the arms above the shoulders
		-- instead, which measured as a scarecrow with both hands 6 studs out.
		if side == "Right" then
			for _, op in HOVER do
				local bone = model:FindFirstChild(op[1], true)
				if bone and bone:IsA("Bone") then
					rotateBoneWorld(bone, root.CFrame:VectorToWorldSpace(op[2]), math.rad(op[3]))
				end
			end
		else
			local drop = -ARM_DROP
			local upperArm = model:FindFirstChild(side .. "UpperArm", true)
			local lowerArm = model:FindFirstChild(side .. "LowerArm", true)
			if upperArm and upperArm:IsA("Bone") then rotateBoneWorld(upperArm, forward, drop) end
			if lowerArm and lowerArm:IsA("Bone") then rotateBoneWorld(lowerArm, right, ELBOW_BEND) end
		end
	end
end

-- opts = { scale = <arena-derived world scale>, seatY = <chair surface Y> }
function CanteenDiner.spawn(marker, parent, seatIndex, opts)
	local template = findTemplate()
	if not (template and marker and parent) then return nil end
	opts = opts or {}

	local model = template:Clone()
	model.Name = "CanteenDiner" .. tostring(seatIndex or "")
	for _, junk in { "InitialPoses", "AnimSaves" } do
		local j = model:FindFirstChild(junk)
		if j then j:Destroy() end
	end
	local root = model:FindFirstChild("RootPart")
	if not (root and root:IsA("BasePart")) then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Massless = true
			if d:IsA("MeshPart") then
				-- White + SmoothPlastic: the atlas is the whole look; any tint or
				-- material response smears the pixels. (RenderFidelity is baked
				-- into the template -- it is not writable at runtime.)
				d.Color = Color3.new(1, 1, 1)
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	root.Transparency = 1

	-- Proportions BEFORE scaling: ScaleTo multiplies bone offsets too, so the
	-- ratio has to be read at 1.
	local metrics = CanteenDiner.metrics()
	local scale = math.clamp(
		(tonumber(opts.scale) or 1)
			* DINER_SCALE_BOOST
			* (tonumber(marker:GetAttribute("DinerScale")) or 1),
		SCALE_LIMITS.min, SCALE_LIMITS.max)
	if math.abs(scale - 1) > 0.001 then model:ScaleTo(scale) end

	-- SIT ON THE CHAIR, not on the marker. The seat markers were placed for the
	-- default R15 avatar and sit at its hip height -- 2.6 studs above the actual
	-- chair pad in the shipped canteen -- so pivoting to the marker left the
	-- diner hovering with nothing under it. The chair surface is passed in by
	-- CanteenProps, which raycast for it; the marker still supplies position and
	-- facing.
	local pelvisHeight = (metrics and metrics.pelvis or 3.95) * scale
	local seatY = tonumber(opts.seatY) or (marker.Position.Y - pelvisHeight)
	local lift = tonumber(marker:GetAttribute("DinerLift")) or 0
	local facing = marker.CFrame - marker.CFrame.Position
	model:PivotTo(CFrame.new(marker.Position.X, seatY - pelvisHeight + lift, marker.Position.Z) * facing)
	if marker:GetAttribute("DinerSeated") ~= false then sit(model, root) end
	model.Parent = parent

	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local self = setmetatable({
		alive = true,
		dead = false,
		model = model,
		root = root,
		seatIndex = seatIndex,
		generation = 0,
		tracks = {
			-- No Idle on purpose (see the header). Eat is loaded ONLY when a real
			-- clip has been published: the obvious stand-in, Push, animates the
			-- legs, which would tear the diner out of the seated pose for the
			-- length of every bite. The fork's own travel already reads as the
			-- bite, so the honest placeholder is no motion at all.
			Eat = AnimationIds.load(animator, "Player", "Eat"),
			Stab = AnimationIds.load(animator, "Player", "Stab"),
			Death = AnimationIds.load(animator, "Player", "Death"),
		},
		scale = scale,
		-- The fork rig's own cutlery (nil on the bare PS1Player template).
		fork = model:FindFirstChild("Fork", true),
		beans = model:FindFirstChild("Beans_Fork", true),
		eating = false,
		beansAfter = nil,
	}, { __index = CanteenDiner })
	self.hasFork = self.fork ~= nil and self.fork:IsA("BasePart")
	if self.beans and self.beans:IsA("BasePart") then self.beans.Transparency = 1 end
	self.head = model:FindFirstChild("Player_Head", true)
	self.neutralFace = (self.head and self.head:IsA("MeshPart")) and self.head.TextureID or nil
	self:startBlinking()
	return self
end

-- FACES. One 1024 atlas per expression, swapped on the head part only: the
-- body and bag map elsewhere on the same atlas and never change.
function CanteenDiner.face(self, name)
	local head = self.head
	if not (head and head:IsA("MeshPart")) then return end
	local uri = name and AnimationIds.texture("Player" .. name) or nil
	head.TextureID = uri or self.neutralFace or head.TextureID
end

-- A blink every 3-5 s for 0.1 s: the only motion a still diner is allowed.
--
-- 26.08.2026 (user): ...und selbst das hoert auf, solange der Observer oben ist.
-- Der Tisch haelt die Luft an. Es ist die billigste Regung, die es hier gibt --
-- ein Texturwechsel auf dem Kopf -- und trotzdem faellt ihr AUSBLEIBEN auf:
-- vier Figuren, die im selben Moment aufhoeren zu blinzeln und mit offenen
-- Augen dasitzen, bis er sich wieder hinter die Zeitung senkt. Kein Text, kein
-- Ton, keine neue Instanz.
--
-- Bewusst KEIN Abbruch der Schleife: `held` laesst sie weiterlaufen und
-- ueberspringt nur den Blinzler. Ein Beenden und Neustarten haette bei jedem
-- Phasenwechsel einen zweiten Thread auf denselben Diner gelegt.
function CanteenDiner.startBlinking(self)
	if not AnimationIds.texture("PlayerBlink") then return end
	task.spawn(function()
		while self.alive and not self.dead and not self.expression do
			task.wait(3 + math.random() * 2)
			if not (self.alive and not self.dead and not self.expression) then break end
			if not self.held then
				self:face("Blink")
				task.wait(0.1)
				if self.alive and not self.dead and not self.expression then self:face(nil) end
			end
		end
	end)
end

-- Augen auf, solange er zusieht. Gesetzt von CanteenProps.observerTo.
function CanteenDiner.hold(self, on)
	if not self.alive then return end
	self.held = on and true or false
end

-- Hurt / Happy stick and end the blinking.
function CanteenDiner.express(self, name)
	if not self.alive then return end
	self.expression = name
	self:face(name)
end

-- Beans on the tines. While a bite is in flight the clip owns the beans (they
-- vanish at the mouth), so a state push that arrives mid-bite is parked and
-- applied when the bite lands -- otherwise the server zeroing the fork the
-- instant MOUTH is accepted would empty the fork before it reaches the face.
function CanteenDiner.setBeans(self, visible)
	local beans = self.beans
	if not (beans and beans:IsA("BasePart")) then return end
	if self.eating then
		self.beansAfter = visible
		return
	end
	beans.Transparency = visible and 0 or 1
end

-- PLATE: the fork punches into the plate and comes up loaded. Repeatable at
-- the server's MIN_PLATE_INTERVAL; a second stab restarts the clip.
function CanteenDiner.stab(self)
	if not self.alive or self.dead then return end
	local track = self.tracks.Stab
	if not track then return end
	if track.IsPlaying then track:Stop(0) end
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.03, 1, 1)
end

-- Head position for blood; falls back to the root.
function CanteenDiner.headPosition(self)
	local head = self.model:FindFirstChild("Player_Head", true)
	return head and head:IsA("BasePart") and head.Position or self.root.Position
end

-- Plays the eating gesture for exactly `duration` seconds -- the same number
-- the server uses as the detectable window, so what the table camera shows is
-- what the Observer can catch. A second call inside the window RESTARTS the
-- gesture rather than being swallowed: a bite that was accepted must be seen.
function CanteenDiner.eat(self, duration)
	if not self.alive or self.dead then return end
	local track = self.tracks.Eat
	if not track then return end
	self.generation += 1
	local gen = self.generation
	local window = math.max(0.1, tonumber(duration) or 0.45)
	if track.IsPlaying then track:Stop(0) end
	local stab = self.tracks.Stab
	if stab and stab.IsPlaying then stab:Stop(0.03) end
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action2
	-- Length is 0 until the clip has streamed in; assume the authored 0.40 s
	-- bite in that case so the first one is not played at speed 0.
	local length = track.Length > 0 and track.Length or 0.4
	track:Play(0.05, 1, length / window)
	-- The beans ride to the mouth and vanish at the bite (frame 5 of 12).
	self.eating = true
	self.beansAfter = nil
	task.delay(window * (5 / 12), function()
		if self.generation == gen and self.beans and self.beans:IsA("BasePart") then self.beans.Transparency = 1 end
	end)
	task.delay(window, function()
		if self.generation ~= gen then return end
		if track.IsPlaying then track:Stop(0.1) end
		self.eating = false
		if self.beansAfter ~= nil then
			local after = self.beansAfter
			self.beansAfter = nil
			self:setBeans(after)
		end
	end)
end

-- One-shot, then frozen on the last frame so the body stays down.
--
-- The hold must survive a slow frame. Parking the track with AdjustSpeed(0)
-- shortly before its end only works if the thread wakes while the track is
-- still playing: task.wait resumes on the first Heartbeat past the deadline,
-- and the animator has already stepped that frame -- so on any frame longer
-- than the margin the non-looped track reaches its end, auto-stops, and the
-- body springs back to the seated bind pose and STAYS there (Idle was stopped
-- and `dead` blocks every other play). Hence both belts: a generous margin
-- AND a Stopped handler that re-parks the pose if the track ends anyway.
local DEATH_HOLD_MARGIN = 0.1

local function parkAtEnd(self, death)
	if not (self.alive and self.dead) then return end
	local length = death.Length
	if length <= 0 then return end
	if not death.IsPlaying then death:Play(0, 1, 0) end
	death:AdjustSpeed(0)
	death.TimePosition = math.max(0, length - 0.03)
end

function CanteenDiner.die(self)
	if not self.alive or self.dead then return end
	self.dead = true
	self.generation += 1
	self:express("Hurt")
	local death = self.tracks.Death
	stopAll(self, death, 0.05)
	if not death then return end
	death.Looped = false
	death.Priority = Enum.AnimationPriority.Action4
	-- Fires whether the clip ran out or something stopped it. Either way the
	-- corpse must not stand back up.
	self.deathStopped = death.Stopped:Connect(function()
		task.defer(parkAtEnd, self, death)
	end)
	death:Play(0.05, 1, 1)
	task.spawn(function()
		-- Wait for the length to resolve, then park just before the end. A clip
		-- that resolves later still ends held, because Stopped catches it.
		local deadline = os.clock() + 4
		while self.alive and death.Length <= 0 and os.clock() < deadline do task.wait(0.05) end
		if not self.alive or death.Length <= 0 then return end
		task.wait(math.max(0, death.Length - DEATH_HOLD_MARGIN - death.TimePosition))
		if not (self.alive and self.dead) then return end
		if death.IsPlaying then
			death:AdjustSpeed(0)
			death.TimePosition = math.max(0, death.Length - 0.03)
		else
			parkAtEnd(self, death)
		end
	end)
end

function CanteenDiner.destroy(self)
	if not self.alive then return end
	self.alive = false
	self.generation += 1
	if self.deathStopped then
		self.deathStopped:Disconnect()
		self.deathStopped = nil
	end
	for _, track in self.tracks do pcall(track.Stop, track, 0) end
	if self.model.Parent then self.model:Destroy() end
end

return CanteenDiner
