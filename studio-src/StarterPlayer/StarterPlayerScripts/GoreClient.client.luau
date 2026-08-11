--!nonstrict
-- GORE-CLIENT: rendert saemtliches Blut lokal (null Server-Last, null Lag).
-- Troepfchen = simulierte Punkte: Heartbeat-Schleife mit Gravitation, pro
-- Frame ein kurzer Raycast in Flugrichtung; beim Einschlag entsteht ein
-- flacher Splat EXAKT auf der Flaechennormale (RaycastResult.Normal).
-- Farben: tiefes Burgund (50,4,4 / 80,0,0), Material Glass mit leichter
-- Reflectance fuer den nassen Look. Alles gedeckelt + selbstaufraeumend.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local DEEP = Color3.fromRGB(50, 4, 4)
local DARK = Color3.fromRGB(80, 0, 0)
local DRIED = Color3.fromRGB(36, 3, 3)
local GRAVITY = Vector3.new(0, -75, 0)
local MAX_DROPLETS = 140
local MAX_SPLATS = 90
local MAX_POOLS = 30
local POOL_LIFE = 18

local droplets = {}
local splats = {}
local pools = {}

local fx
local function fxFolder()
	if fx and fx.Parent then return fx end
	fx = Instance.new("Folder")
	fx.Name = "GoreFX_Local"
	fx.Parent = workspace
	return fx
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function refreshRayFilter()
	local ex = { fxFolder() }
	for _, plr in Players:GetPlayers() do
		if plr.Character then table.insert(ex, plr.Character) end
	end
	local serverFx = workspace:FindFirstChild("KenopsiaFX")
	if serverFx then table.insert(ex, serverFx) end
	rayParams.FilterDescendantsInstances = ex
end

local function evict(list, max)
	while #list > max do
		local old = table.remove(list, 1)
		if old and old.Parent then
			TweenService:Create(old, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			Debris:AddItem(old, 0.7)
		end
	end
end

-- flaches Plaettchen exakt auf der Flaeche - nie ein Zylinder
local function splatAt(pos, normal, big)
	local p = Instance.new("Part")
	p.Name = "Splat"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Glass
	p.Reflectance = 0.15
	p.Color = math.random() < 0.6 and DEEP or DARK
	local w = (big and 1.0 or 0.4) + math.random() * (big and 1.4 or 0.7)
	p.Size = Vector3.new(w, w * (0.55 + math.random() * 0.9), 0.04)
	p.CFrame = CFrame.lookAt(pos + normal * 0.02, pos + normal) * CFrame.Angles(0, 0, math.random() * math.pi * 2)
	p.Transparency = 0.08
	p.Parent = fxFolder()
	table.insert(splats, p)
	evict(splats, MAX_SPLATS)
	task.delay(4, function()
		if p.Parent then TweenService:Create(p, TweenInfo.new(3), { Color = DRIED }):Play() end
	end)
	task.delay(9, function()
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(2), { Transparency = 1 }):Play()
			Debris:AddItem(p, 2.1)
		end
	end)
end

local function groundSplat(pos, big)
	refreshRayFilter()
	local hit = workspace:Raycast(pos + Vector3.new(0, 2.5, 0), Vector3.new(0, -12, 0), rayParams)
	if hit then splatAt(hit.Position, hit.Normal, big) end
end

-- Blutlache: zwei leicht verdrehte nasse Platten; waechst, trocknet, verblasst
local function pool(pos, size)
	refreshRayFilter()
	local hit = workspace:Raycast(pos + Vector3.new(0, 2.5, 0), Vector3.new(0, -12, 0), rayParams)
	if not hit then return end
	size = size or (1.6 + math.random() * 1.6)
	for layer = 1, 2 do
		local p = Instance.new("Part")
		p.Name = "Pool"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Glass
		p.Reflectance = 0.2
		p.Color = layer == 1 and DARK or DEEP
		p.Size = Vector3.new(0.3, 0.3, 0.05)
		p.CFrame = CFrame.lookAt(hit.Position + hit.Normal * (0.015 * layer), hit.Position + hit.Normal * 2)
			* CFrame.Angles(0, 0, math.random() * math.pi * 2)
		p.Transparency = 0.05
		p.Parent = fxFolder()
		local s = size * (layer == 1 and 1 or 0.65)
		TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(s, s * (0.7 + math.random() * 0.5), 0.05) }):Play()
		table.insert(pools, p)
		task.delay(POOL_LIFE * 0.4, function()
			if p.Parent then TweenService:Create(p, TweenInfo.new(4), { Color = DRIED }):Play() end
		end)
		task.delay(POOL_LIFE, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(3), { Transparency = 1 }):Play()
				Debris:AddItem(p, 3.1)
			end
		end)
	end
	evict(pools, MAX_POOLS)
end

-- Troepfchen-Simulation ------------------------------------------------------
local dropletTpl = Instance.new("Part")
dropletTpl.Name = "Droplet"
dropletTpl.Size = Vector3.new(0.14, 0.14, 0.14)
dropletTpl.Material = Enum.Material.Glass
dropletTpl.Reflectance = 0.1
dropletTpl.Color = DARK
dropletTpl.Anchored = true
dropletTpl.CanCollide = false
dropletTpl.CanQuery = false
dropletTpl.CanTouch = false
dropletTpl.CastShadow = false

local function spawnDroplets(pos, n, speedMin, speedMax, upBias)
	for _ = 1, n do
		if #droplets >= MAX_DROPLETS then break end
		local d = dropletTpl:Clone()
		d.CFrame = CFrame.new(pos)
		d.Parent = fxFolder()
		local ang = math.random() * math.pi * 2
		local pitch = math.min(math.random() * 0.9 + (upBias or 0.1), 1.5)
		local sp = speedMin + math.random() * (speedMax - speedMin)
		local dir = Vector3.new(math.cos(ang) * math.cos(pitch), math.sin(pitch), math.sin(ang) * math.cos(pitch))
		table.insert(droplets, { part = d, pos = pos, vel = dir * sp, life = 0 })
	end
end

RunService.Heartbeat:Connect(function(dt)
	if #droplets == 0 then return end
	refreshRayFilter()
	for i = #droplets, 1, -1 do
		local dr = droplets[i]
		dr.life += dt
		local newVel = dr.vel + GRAVITY * dt
		local delta = newVel * dt
		local hit = workspace:Raycast(dr.pos, delta * 1.15, rayParams)
		if hit then
			splatAt(hit.Position, hit.Normal, false)
			dr.part:Destroy()
			table.remove(droplets, i)
		elseif dr.life > 2.5 then
			dr.part:Destroy()
			table.remove(droplets, i)
		else
			dr.pos += delta
			dr.vel = newVel
			dr.part.CFrame = CFrame.new(dr.pos)
		end
	end
end)

-- Nebel + Brocken-Partikel + Troepfchen
local function burst(pos, k)
	k = k or 1
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(pos)
	local att = Instance.new("Attachment")
	att.Parent = holder
	local mist = Instance.new("ParticleEmitter")
	mist.Color = ColorSequence.new(DARK, DEEP)
	mist.LightEmission = 0.1
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(0.25, 0.9)
	mist.Speed = NumberRange.new(4, 14)
	mist.SpreadAngle = Vector2.new(180, 180)
	mist.Acceleration = Vector3.new(0, -30, 0)
	mist.Rate = 0
	mist.Parent = att
	holder.Parent = fxFolder()
	mist:Emit(math.floor(35 * k))
	Debris:AddItem(holder, 2)
	spawnDroplets(pos, math.floor(8 + 10 * k), 8, 24, 0.15)
end

local function gibs(pos, n, long)
	for _ = 1, n or 5 do
		local p = Instance.new("Part")
		p.Name = "Gib"
		p.Material = Enum.Material.SmoothPlastic
		p.Color = math.random() < 0.3 and DARK or DEEP
		local s = 0.25 + math.random() * 0.4
		if long then
			p.Size = Vector3.new(0.32 + math.random() * 0.1, 1.0 + math.random() * 0.6, 0.32 + math.random() * 0.1)
		else
			p.Size = Vector3.new(s, s * (0.6 + math.random() * 0.8), s)
		end
		p.CFrame = CFrame.new(pos + Vector3.new(math.random(-6, 6) / 10, math.random(0, 8) / 10, math.random(-6, 6) / 10))
			* CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.AssemblyLinearVelocity = Vector3.new(math.random(-18, 18), math.random(14, 30), math.random(-18, 18))
		p.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
		p.Parent = fxFolder()
		task.delay(0.55 + math.random() * 0.4, function()
			if p.Parent then groundSplat(p.Position, false) end
		end)
		Debris:AddItem(p, 3.5 + math.random() * 1.5)
	end
end

local function fountain(pos)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(pos)
	local att = Instance.new("Attachment")
	att.Parent = holder
	local jet = Instance.new("ParticleEmitter")
	jet.Color = ColorSequence.new(DARK, DEEP)
	jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.08) })
	jet.Lifetime = NumberRange.new(0.4, 0.9)
	jet.Speed = NumberRange.new(14, 24)
	jet.SpreadAngle = Vector2.new(14, 14)
	jet.Acceleration = Vector3.new(0, -70, 0)
	jet.Rate = 90
	jet.Parent = att
	holder.Parent = fxFolder()
	task.delay(1.3, function() jet.Enabled = false end)
	Debris:AddItem(holder, 3)
	spawnDroplets(pos, 8, 10, 18, 1.1)
end

local BIRD_MUSIC_DUCK = {
	SniperFire = 0.62,
	SniperReload = 0.72,
	BulletRicochet = 0.34,
}
local birdMusicDuckGeneration = 0
local birdMusicDuckTween
local birdMusicBaseVolume

local function duckBirdMusic(name)
	local hold = BIRD_MUSIC_DUCK[name]
	if not hold then return end
	local ka = SoundService:FindFirstChild("KenopsiaAudio")
	local music = ka and ka:FindFirstChild("Music")
	local trials = music and music:FindFirstChild("Trials")
	local birdMusic = trials and trials:FindFirstChild("birdhunt")
	if not birdMusic or not birdMusic:IsA("Sound") or not birdMusic.IsPlaying then return end

	birdMusicBaseVolume = birdMusicBaseVolume or birdMusic.Volume
	birdMusicDuckGeneration += 1
	local generation = birdMusicDuckGeneration
	if birdMusicDuckTween then birdMusicDuckTween:Cancel() end
	birdMusicDuckTween = TweenService:Create(
		birdMusic,
		TweenInfo.new(0.04, Enum.EasingStyle.Linear),
		{ Volume = math.min(birdMusicBaseVolume, 0.055) }
	)
	birdMusicDuckTween:Play()
	task.delay(hold, function()
		if generation ~= birdMusicDuckGeneration or not birdMusic.Parent then return end
		if birdMusicDuckTween then birdMusicDuckTween:Cancel() end
		birdMusicDuckTween = TweenService:Create(
			birdMusic,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Volume = birdMusicBaseVolume }
		)
		birdMusicDuckTween:Play()
	end)
end

local function playSound(pos, name)
	local ka = SoundService:FindFirstChild("KenopsiaAudio")
	local sfx = ka and ka:FindFirstChild("SFX")
	local src = sfx and sfx:FindFirstChild(name)
	if not src then return end
	local variants = src:IsA("Folder") and src:GetChildren() or { src }
	if #variants == 0 then return end
	duckBirdMusic(name)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(pos)
	local s = variants[math.random(#variants)]:Clone()
	s.Parent = holder
	holder.Parent = fxFolder()
	s:Play()
	Debris:AddItem(holder, 4)
end

local function clearAll()
	for _, dr in droplets do
		if dr.part then dr.part:Destroy() end
	end
	table.clear(droplets)
	table.clear(splats)
	table.clear(pools)
	if fx then fx:ClearAllChildren() end
end

-- Kombos ---------------------------------------------------------------------
local function kill(pos)
	playSound(pos, "Blood")
	playSound(pos, "ImpactBody")
	burst(pos, 1.6)
	gibs(pos, 6, false)
	pool(pos, 2.6 + math.random() * 1.2)
	for _ = 1, 2 do
		local ang = math.random() * math.pi * 2
		local dist = 1.5 + math.random() * 2.5
		pool(pos + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist), 0.8 + math.random())
	end
end

local function maim(pos)
	playSound(pos, "Blood")
	playSound(pos, "ImpactBody")
	burst(pos, 1.3)
	gibs(pos, 4, true)
	pool(pos, 1.6 + math.random())
end

local function hit(pos)
	playSound(pos, "Blood")
	burst(pos, 0.8)
	pool(pos, 1.0 + math.random() * 0.8)
end

-- ZERSTUECKELUNG: der Koerper zerreisst komplett in Brocken (Minen-/Snipertod)
local function shatter(pos)
	playSound(pos, "Blood")
	playSound(pos, "ImpactBody")
	burst(pos, 2.2)
	gibs(pos, 10, false)
	gibs(pos, 4, true)
	fountain(pos)
	pool(pos, 3.0 + math.random() * 1.2)
	for _ = 1, 3 do
		local ang = math.random() * math.pi * 2
		local dist = 1.5 + math.random() * 3
		pool(pos + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist), 0.8 + math.random())
	end
	spawnDroplets(pos, 14, 10, 28, 0.3)
end

-- Dispatch -------------------------------------------------------------------
local remotes = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
local GoreEvent = remotes:WaitForChild("GoreEvent", 30)
if not GoreEvent then return end
GoreEvent.OnClientEvent:Connect(function(p)
	if type(p) ~= "table" or type(p.p) ~= "table" then
		if type(p) == "table" and p.t == "clear" then clearAll() end
		return
	end
	local pos = Vector3.new(p.p[1], p.p[2], p.p[3])
	if p.t == "kill" then kill(pos)
	elseif p.t == "maim" then maim(pos)
	elseif p.t == "hit" then hit(pos)
	elseif p.t == "burst" then burst(pos, p.k)
	elseif p.t == "pool" then pool(pos, p.s)
	elseif p.t == "gibs" then gibs(pos, p.n, p.long)
	elseif p.t == "fountain" then fountain(pos)
	elseif p.t == "splat" then groundSplat(pos, false)
	elseif p.t == "shatter" then shatter(pos)
	elseif p.t == "sound" then playSound(pos, p.name)
	end
end)

-- Standard-Roblox-Todeslaut ("oh") stummschalten - wir haben eigenes Audio
local function muteDeathSound(char)
	task.spawn(function()
		for _ = 1, 40 do
			local root = char:FindFirstChild("HumanoidRootPart")
			local died = root and root:FindFirstChild("Died")
			if died and died:IsA("Sound") then
				died.SoundId = ""
				died.Volume = 0
				return
			end
			task.wait(0.25)
		end
	end)
end
local function hookCharSounds(plr)
	plr.CharacterAdded:Connect(muteDeathSound)
	if plr.Character then muteDeathSound(plr.Character) end
end
Players.PlayerAdded:Connect(hookCharSounds)
for _, plr in Players:GetPlayers() do hookCharSounds(plr) end
