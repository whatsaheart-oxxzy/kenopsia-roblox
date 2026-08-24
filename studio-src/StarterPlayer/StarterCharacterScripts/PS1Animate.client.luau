--!nonstrict
-- PS1 ANIMATE -- the player character's clips (P3.3, 22.08.2026).
--
-- Runs in every character and does nothing unless the character is the PS1
-- rig (attribute KenopsiaPS1 on the StarterCharacter model). Idle / Walk / Run
-- are chosen by the measured speed, so a trial that lowers WalkSpeed (the
-- injured runner in the range) drops into the walk by itself; Crouch plays
-- while the character's `Crouching` attribute is true (CharacterService sets
-- it from the crouch remote); Death plays once on Died. There is no jump clip
-- because there is no jumping in this game -- the state is disabled here too.
--
-- 23.08.2026, three more gaits from the trials' attributes (all server-set):
--   XBotCrawl  true -> Crawl, looped, paced by the speed, held at 0 when still
--                     (the maimed body in the Dead Zone); beats everything
--   Injured    true -> InjuredWalk while moving, instead of Walk / Run (a
--                     winged runner in Bird Hunting); Idle / Crouch unchanged
--   Died            -> DeathField (the field death) when it loads, else Death
-- A clip that does not load (unpublished outside Studio) degrades to the
-- plain Idle / Walk / Run choice -- never to a frozen or wrong-speed body.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local char = script.Parent
-- the attribute can arrive a beat after the script starts: wait for it, then decide
local t0 = os.clock()
while char and char:GetAttribute("KenopsiaPS1") == nil and os.clock() - t0 < 5 do task.wait(0.1) end
if not (char and char:GetAttribute("KenopsiaPS1") == true) then
	print("[PS1Animate] not a PS1 rig - idle")
	return
end
print("[PS1Animate] up")

local hum = char:WaitForChild("Humanoid")
local animator = hum:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Parent = hum
end
local AnimationIds = require(ReplicatedStorage:WaitForChild("Kenopsia")
	:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AnimationIds"))

hum.UseJumpPower = true
hum.JumpPower = 0
pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)

-- clip speeds at scale 1 (AnimationIds), so AdjustSpeed keeps the feet planted
local NATURAL = AnimationIds.PlayerSpeeds or { Walk = 4.5, Run = 10.95, Crawl = 2.26, InjuredWalk = 3.49 }
local RUN_AT = 7.5 -- studs/s: below this the walk carries the legs

local tracks = {}
local function track(name)
	if tracks[name] == nil then
		tracks[name] = AnimationIds.load(animator, "Player", name) or false
	end
	return tracks[name] or nil
end

local current = nil
local currentName = nil
local function play(name, speed)
	local t = track(name)
	if not t then return end
	if current ~= t then
		local prev, prevName = current, currentName
		if current then current:Stop(0.15) end
		t.Looped = name ~= "Death" and name ~= "DeathField" -- 23.08.2026: both deaths one-shot
		t:Play(0.15)
		-- 24.08.2026: gait blends land on the SAME FOOT. Walk and Run are both
		-- authored left-contact-first loops, so carrying the normalised cycle
		-- phase across the crossfade keeps the feet frame-matched instead of
		-- restarting the stride mid-step.
		if prev and prev.Length > 0 and t.Length > 0
			and ((prevName == "Walk" and name == "Run") or (prevName == "Run" and name == "Walk")) then
			t.TimePosition = (prev.TimePosition / prev.Length) % 1 * t.Length
		end
		current = t
		currentName = name
	end
	if speed then t:AdjustSpeed(speed) end
end

local dead = false
local speedNow = 0
local function update()
	if dead then return end
	local scale = char:GetScale()
	local moving = speedNow > 0.5
	-- 23.08.2026: the trial attributes pick the gait first; each falls through
	-- to the plain choice when its clip is not available (track() -> nil).
	if char:GetAttribute("XBotCrawl") == true and track("Crawl") then
		play("Crawl", moving and speedNow / ((NATURAL.Crawl or 2.0) * scale) or 0)
	elseif char:GetAttribute("Crouching") == true then
		play("Crouch", moving and 1 or 0)
	elseif not moving then
		play("Idle", 1)
	elseif char:GetAttribute("Injured") == true and track("InjuredWalk") then
		play("InjuredWalk", speedNow / ((NATURAL.InjuredWalk or 2.6) * scale))
	elseif speedNow < RUN_AT then
		play("Walk", speedNow / (NATURAL.Walk * scale))
	else
		play("Run", speedNow / (NATURAL.Run * scale))
	end
end

hum.Running:Connect(function(speed)
	speedNow = speed
	update()
end)
char:GetAttributeChangedSignal("Crouching"):Connect(update)
char:GetAttributeChangedSignal("XBotCrawl"):Connect(update)
char:GetAttributeChangedSignal("Injured"):Connect(update)
hum.Died:Connect(function()
	dead = true
	if current then current:Stop(0.1) end
	current = nil
	-- 23.08.2026: the field death first; the execution Death stays the fallback
	local d = track("DeathField") or track("Death")
	if d then
		d.Looped = false
		d:Play(0.05)
		-- 23.08.2026: the published Sweep Fall starts with a 0.6 s wind-up.
		local start = AnimationIds.PlayerStart and AnimationIds.PlayerStart[d == track("DeathField") and "DeathField" or "Death"]
		if start and start > 0 then d.TimePosition = start end
	end
end)

-- Roblox drops its own R15 Animate into the character (measured 22.08.2026:
-- 22 StringValue children, a Core-priority idle already running -- and again
-- after a teleport, arriving before its children replicate). It would fight
-- these clips forever, so every Animate script is removed, now and whenever
-- one arrives, and nothing but the rig's own Player/* clips may run.
local function isOurs(t)
	return ((t.Animation and t.Animation.Name or ""):find("^Player/")) ~= nil
end
local function evictDefault(inst)
	if inst:IsA("LocalScript") and inst.Name == "Animate" then
		inst:Destroy()
		for _, t in animator:GetPlayingAnimationTracks() do
			if not isOurs(t) then t:Stop(0) end
		end
		current = nil
		update()
	end
end
for _, c in char:GetChildren() do evictDefault(c) end
char.ChildAdded:Connect(function(inst) task.defer(evictDefault, inst) end)
animator.AnimationPlayed:Connect(function(t)
	if not isOurs(t) then t:Stop(0) end
end)
update()

-- 24.08.2026: ONE MINE takes the lower half. The rig is a single skinned mesh,
-- so the legs cannot be detached -- instead, while `XBotLegless` is set, the
-- whole leg chains are pushed 3.2 studs (x scale) straight down every frame
-- AFTER the Animator has written its transforms (RenderStepped runs after all
-- BindToRenderStep work, see docs/QA 22.08.); the arena floor swallows them
-- and the body visually ends at the hips. A dark clot part with a drip
-- emitter rides the pelvis bone -- each client renders its own.
do
	local RunService = game:GetService("RunService")
	local DROP = 3.2
	local clot = nil
	local function ensureClot()
		if clot and clot.Parent then return clot end
		clot = Instance.new("Part")
		clot.Name = "KenopsiaClot"
		clot.Size = Vector3.new(1.7, 0.9, 1.5)
		clot.Color = Color3.fromRGB(84, 8, 8)
		clot.Material = Enum.Material.Slate
		clot.CanCollide = false
		clot.CanQuery = false
		clot.CanTouch = false
		clot.Anchored = true
		clot.CastShadow = false
		local drip = Instance.new("ParticleEmitter")
		drip.Color = ColorSequence.new(Color3.fromRGB(120, 10, 10))
		drip.Size = NumberSequence.new(0.22)
		drip.Lifetime = NumberRange.new(0.3, 0.6)
		drip.Rate = 14
		drip.Speed = NumberRange.new(1, 2)
		drip.Acceleration = Vector3.new(0, -40, 0)
		drip.EmissionDirection = Enum.NormalId.Bottom
		drip.Parent = clot
		clot.Parent = char
		return clot
	end
	local legBones = nil
	local function legs()
		if legBones then return legBones end
		local root = char:FindFirstChild("HumanoidRootPart")
		local lower = root and root:FindFirstChild("Root", true) and root.Root:FindFirstChild("LowerTorso")
		if not lower then return nil end
		legBones = {
			lower = lower,
			uppers = { lower:FindFirstChild("LeftUpperLeg"), lower:FindFirstChild("RightUpperLeg") },
		}
		return legBones
	end
	RunService.RenderStepped:Connect(function()
		if char:GetAttribute("XBotLegless") ~= true then
			if clot then clot:Destroy() clot = nil end
			return
		end
		local lb = legs()
		if not lb then return end
		local scale = char:GetScale()
		for _, b in ipairs(lb.uppers) do
			if b then
				local base = b.Parent.TransformedWorldCFrame * b.CFrame
				local w = base * b.Transform
				b.Transform = base:Inverse() * (w - Vector3.new(0, DROP * scale, 0))
				for _, c in ipairs(b:GetDescendants()) do
					if c:IsA("Bone") then c.Transform = CFrame.new() end
				end
			end
		end
		local c = ensureClot()
		local hip = lb.lower.TransformedWorldCFrame
		c.CFrame = CFrame.new(hip.Position - Vector3.new(0, 0.5 * scale, 0))
	end)
end
