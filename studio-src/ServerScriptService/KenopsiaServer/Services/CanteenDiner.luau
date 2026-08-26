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

-- 26.08.2026 (user): DER KOERPER FAELLT AUF DEN TISCH, NICHT DARUNTER.
--
-- Bis hierher lief zum Sterben der Death-Clip (AnimationIds Player/Death),
-- einmal, geparkt auf dem letzten Frame. Das Parken funktionierte -- die POSE
-- war das Problem: der Clip ist ein STEHENDER Tod und legt die Figur auf Hoehe
-- des RIG-ROOTS ab. Der Root eines Diners sitzt aber `pelvisHeight` UNTER der
-- Sitzflaeche (siehe PivotTo in spawn), also ungefaehr auf Bodenhoehe. Die
-- Leiche landete damit flach auf dem Boden UNTER dem Tisch, wo die feste
-- Tischkamera sie gar nicht sieht -- genau der gemeldete Fehler.
--
-- Der Sitz ist in dieser Datei schon lange keine Animation, sondern ein
-- Bind-Pose-Offset (`sit` oben). Der Zusammenbruch ist jetzt dasselbe: der
-- Oberkoerper klappt um die Huefte nach vorn, bis Brust und Kopf auf der
-- Tischplatte liegen; die Beine bleiben gefaltet auf dem Stuhl, die Arme
-- fallen aus ihrer Pose. Das kann NICHT danebenlanden, weil nichts
-- translatiert wird -- es wird ausschliesslich rotiert, also bleibt der
-- Koerper da, wo er sitzt, und kippt nur nach vorn.
--
-- Der Winkel ist an der Geometrie belegt, nicht geraten: die Schultern liegen
-- bei dieser Arena-Skalierung auf Hoehe der Tischplatte (siehe den Kommentar
-- ueber HOVER). Klappt der Oberkoerper um ~90 Grad nach vorn, kommt der Kopf
-- auf Plattenhoehe und um Hals- plus Kopflaenge nach vorn zu liegen -- auf dem
-- Tisch. Etwas unter 90 Grad, damit die Brust aufliegt statt durchzurutschen.
--
-- Pro Sitzmarker feinjustierbar, wie DinerScale / DinerLift / DinerSeated:
--   DinerSlump  82   Grad, um die der Oberkoerper nach vorn faellt
local SLUMP_FOLD = 82            -- Grad, Voreinstellung
local SLUMP_HEAD = math.rad(18)  -- Kopf kippt zur Seite, statt gerade aufzuschlagen
local SLUMP_ARM = math.rad(45)   -- Arme rutschen aus ihrer Pose auf die Platte

-- Aufgeteilt auf Becken und Brustbein: eine einzige Achse waere ein Scharnier
-- und liesse den Ruecken kerzengerade. Die Summe ist der bestellte Winkel.
local function slump(model, root, foldDegrees)
	local fold = math.rad(math.clamp(tonumber(foldDegrees) or SLUMP_FOLD, 0, 100))
	local right = root.CFrame.RightVector
	local forward = root.CFrame.LookVector
	-- Gleiche Achse und gleiches Vorzeichen wie HIP_FOLD in `sit`: positiv um
	-- die Rechts-Achse ist "nach vorn/unten".
	for _, op in { { "LowerTorso", fold * 0.45 }, { "UpperTorso", fold * 0.55 } } do
		local bone = model:FindFirstChild(op[1], true)
		if bone and bone:IsA("Bone") then rotateBoneWorld(bone, right, op[2]) end
	end
	local head = model:FindFirstChild("Head", true)
	if head and head:IsA("Bone") then rotateBoneWorld(head, forward, SLUMP_HEAD) end
	-- Beide Arme geben nach. Der rechte verlaesst damit die Hover-Pose, in der
	-- er die Gabel ueber dem Teller gehalten hat.
	for _, side in { "Left", "Right" } do
		local upperArm = model:FindFirstChild(side .. "UpperArm", true)
		if upperArm and upperArm:IsA("Bone") then
			rotateBoneWorld(upperArm, forward, side == "Left" and -SLUMP_ARM or SLUMP_ARM)
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
		(tonumber(opts.scale) or 1) * (tonumber(marker:GetAttribute("DinerScale")) or 1),
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
			-- 26.08.2026 (user): KEIN Death-Clip mehr. Er ist ein stehender Tod
			-- und legte die Leiche auf Root-Hoehe ab, also unter den Tisch --
			-- siehe die lange Begruendung ueber `slump`. Der Zusammenbruch ist
			-- jetzt eine Bind-Pose wie der Sitz selbst. AnimationIds.Player.Death
			-- bleibt deklariert: wer den Clip zurueckholen will, laedt ihn hier
			-- wieder und ruft ihn in die() auf.
		},
		scale = scale,
		-- Grad, um die der Oberkoerper beim Tod nach vorn faellt. Am Sitzmarker
		-- feinjustierbar (DinerSlump), wie DinerScale und DinerLift.
		slumpFold = tonumber(marker:GetAttribute("DinerSlump")) or SLUMP_FOLD,
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
function CanteenDiner.startBlinking(self)
	if not AnimationIds.texture("PlayerBlink") then return end
	task.spawn(function()
		while self.alive and not self.dead and not self.expression do
			task.wait(3 + math.random() * 2)
			if not (self.alive and not self.dead and not self.expression) then break end
			self:face("Blink")
			task.wait(0.1)
			if self.alive and not self.dead and not self.expression then self:face(nil) end
		end
	end)
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

function CanteenDiner.die(self)
	if not self.alive or self.dead then return end
	self.dead = true
	self.generation += 1
	self:express("Hurt")
	-- Alles anhalten, auch einen Bissen in der Luft: die Transforms der Clips
	-- stapeln sich sonst auf die Bind-Pose, die gleich umgeklappt wird, und der
	-- Tote wuerde weiteressen. Ohne Ausblendzeit -- ein Schuss ist ein Schnitt,
	-- und eine auslaufende Blende wuerde gegen die neue Bind-Pose arbeiten.
	stopAll(self, nil, 0)
	slump(self.model, self.root, self.slumpFold)
end

function CanteenDiner.destroy(self)
	if not self.alive then return end
	self.alive = false
	self.generation += 1
	-- Hier stand das Aufraeumen der Death-Stopped-Verbindung. Die gibt es nicht
	-- mehr: der Tod ist kein Clip mehr, der auslaufen und zurueckfedern koennte,
	-- sondern eine Bind-Pose (siehe `slump`). Damit faellt auch die ganze
	-- Halte-Mechanik weg, die den letzten Frame gegen langsame Frames sichern
	-- musste -- eine Bind-Pose haelt von selbst.
	for _, track in self.tracks do pcall(track.Stop, track, 0) end
	if self.model.Parent then self.model:Destroy() end
end

return CanteenDiner
