--!nonstrict
-- SIMULATION GRADE -- the PS1 look, and ONLY while a trial runs (P3.1, 22.08.2026).
--
-- The Machine screens are clean phosphor; the 3D layer is ungraded in the
-- lobby. The moment KenopsiaActiveTrial becomes non-empty this script takes a
-- snapshot of every Lighting property it is about to touch, applies the
-- arena's preset (tonemapper, grade, fog or atmosphere, lamps) and quantises
-- the camera POSITION to 1/8 stud -- never the rotation, never in a scope, and
-- never under Reduce Motion. When the attribute clears, or the player turns
-- SIMULATION FILTER off in Settings, the snapshot is written back property
-- for property and every created instance is destroyed: byte-for-byte.
--
-- Presets: PRESETS[trialId] here for the legacy trials; a TrialClients/<id>
-- module may export `presentation = { grade = {...} }` instead, which wins.
-- Cost: three post-effects, one CFrame write per frame. Nothing per player.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local trialClientsFolder = script.Parent:FindFirstChild("TrialClients")

local QUANT = 6 -- 24.08.2026: was 8; harder position steps read more PS1 -- steps per stud
local BIND = "KenopsiaSimulationGrade"

-- Every preset may set any of these Lighting fields; unset ones keep the
-- lobby value. `fog` = {start, end, Color3}; `atmosphere` replaces fog
-- outdoors (Roblox ignores Lighting.Fog* while an Atmosphere exists).
local BASE = {
	saturation = -0.35,
	contrast = 0.08,
	tint = Color3.fromRGB(235, 232, 225),
	tonemapper = Enum.TonemapperPreset.Retro,
	quantise = true,
}

local PRESETS = {
	-- the Dead Zone: black void, cold floodlight raster (moved here from the
	-- monolith's DZ-light block). The strip must read as a floor even where
	-- local lights are not rendered at all (low quality level / weak phones),
	-- so the ambient carries the floor and the raster only adds the pools.
	minefield = {
		Ambient = Color3.fromRGB(24, 28, 40), -- 23.08.2026: user call, darker
		OutdoorAmbient = Color3.fromRGB(10, 13, 20),
		Brightness = 1,
		ClockTime = 0,
		fog = { 40, 130, Color3.fromRGB(0, 0, 0) },
		tint = Color3.fromRGB(205, 218, 255),
		saturation = -0.3,
		contrast = 0.15,
		lamps = "minefield",
	},
	-- the canteen: sodium tubes, grease in the air, nothing beyond the walls
	canteen = {
		Ambient = Color3.fromRGB(62, 54, 46),
		OutdoorAmbient = Color3.fromRGB(34, 30, 28),
		Brightness = 1.35,
		fog = { 38, 140, Color3.fromRGB(18, 13, 10) },
		tint = Color3.fromRGB(255, 228, 192),
		saturation = -0.45,
		contrast = 0.18,
	},
	-- the range: overcast dusk, thick ground haze; the scope must stay honest,
	-- so no position quantisation here
	birdhunt = {
		Brightness = 1.1,
		-- 24.08.2026 (user): a light-blue PS1 sky -- the authored skybox is
		-- pulled while the trial runs (skyless) and the atmosphere paints a
		-- flat pale blue; the world grain overlay keeps it pixelated.
		atmosphere = { Density = 0.35, Offset = 0.22, Haze = 1.6, Glare = 0,
			Color = Color3.fromRGB(152, 186, 214), Decay = Color3.fromRGB(118, 138, 158) },
		tint = Color3.fromRGB(206, 214, 226),
		saturation = -0.35,
		contrast = 0.1,
		quantise = false,
		skyless = true,
	},
}

local LIGHT_FIELDS = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "ExposureCompensation",
	"FogStart", "FogEnd", "FogColor",
	-- 24.08.2026 (PS1 pass 2): no soft shadows, no PBR ambience in a trial.
	"GlobalShadows", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local disabledFx = {}
local savedSky = nil

local snapshot = nil
local created = {}
local activeId = ""

local function filterOn()
	return player:GetAttribute("KenopsiaSimFilter") ~= false
end

local function motionOk()
	return not GuiService.ReducedMotionEnabled and player:GetAttribute("KenopsiaReduceFlicker") ~= true
end

-- The monolith's RenderStepped camera writer runs AFTER every BindToRenderStep
-- priority (measured 22.08.2026: Last, then RenderStepped), so scriptable
-- cameras are snapped there; it reads the step from this attribute. The
-- binding below only handles the default (Custom) camera.
local quantWanted = false
local function publishQuant()
	local on = quantWanted and motionOk()
	player:SetAttribute("KenopsiaCamQuant", on and QUANT or 0)
	-- 24.08.2026: the camera also HOLDS its frame at a retro cadence while the
	-- filter runs -- the world renders at full rate, the view steps at 30 Hz.
	player:SetAttribute("KenopsiaCamStep", on and 30 or 0)
end

local function presetFor(id)
	local mod = trialClientsFolder and trialClientsFolder:FindFirstChild(id)
	if mod and mod:IsA("ModuleScript") then
		local ok, m = pcall(require, mod)
		if ok and type(m) == "table" and type(m.presentation) == "table" and type(m.presentation.grade) == "table" then
			return m.presentation.grade
		end
	end
	return PRESETS[id] or {}
end

local function get(preset, key)
	local v = preset[key]
	if v == nil then v = BASE[key] end
	return v
end

local function make(className, name, props)
	local inst = Instance.new(className)
	inst.Name = name
	for k, v in props do inst[k] = v end
	inst.Parent = Lighting
	table.insert(created, inst)
	return inst
end

-- the Dead Zone floodlight raster: local only, costs the server nothing
local function buildLamps(kind)
	if kind ~= "minefield" then return end
	local dz = workspace:FindFirstChild("Dead Zone")
	local ground = dz and dz:FindFirstChild("Minefield Ground")
	if not ground then return end
	local folder = Instance.new("Folder")
	folder.Name = "DZ_Lights_Local"
	-- one cold pool every 40 studs (PointLight: a 130-degree SpotLight barely
	-- reaches the floor); phones get a single centre row, half the lights.
	local size, cf = ground.Size, ground.CFrame
	local machine = player.PlayerGui:FindFirstChild("KenopsiaMachine")
	local mobile = machine ~= nil and machine:GetAttribute("Platform") == "Mobile"
	local nx = mobile and 1 or math.clamp(math.floor(size.X / 24), 1, 4)
	local nz = math.clamp(math.floor(size.Z / 40), 2, 10)
	for ix = 1, nx do
		for iz = 1, nz do
			local ox = -size.X / 2 + size.X * ((ix - 0.5) / nx)
			local oz = -size.Z / 2 + size.Z * ((iz - 0.5) / nz)
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Transparency = 1
			holder.Size = Vector3.new(0.2, 0.2, 0.2)
			holder.CFrame = cf * CFrame.new(ox, 14, oz)
			local spot = Instance.new("PointLight")
			spot.Range = 40
			spot.Brightness = 1.6 -- 23.08.2026: user call, darker pools
			spot.Color = Color3.fromRGB(170, 205, 255)
			spot.Shadows = false
			spot.Parent = holder
			holder.Parent = folder
		end
	end
	folder.Parent = workspace
	table.insert(created, folder)
end

local function apply(id)
	if snapshot then return end
	local preset = presetFor(id)
	snapshot = {}
	for _, f in LIGHT_FIELDS do snapshot[f] = Lighting[f] end
	for _, f in { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "ExposureCompensation" } do
		if preset[f] ~= nil then Lighting[f] = preset[f] end
	end
	if preset.fog then
		Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor = preset.fog[1], preset.fog[2], preset.fog[3]
	end
	-- PS1 rules: hard light only. Smooth shadow maps, PBR environment light
	-- and any modern post effect (bloom, DoF, sun rays) go dark for the trial.
	Lighting.GlobalShadows = false
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	for _, e in Lighting:GetChildren() do
		if (e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("SunRaysEffect")) and e.Enabled then
			disabledFx[e] = true
			e.Enabled = false
		end
	end
	if get(preset, "skyless") == true then
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			savedSky = sky
			sky.Parent = nil
		end
		-- 24.08.2026 (user): the trial sky is a 128 px Bayer-dithered light
		-- blue (uploaded asset), flat on all six faces -- a PS1 backdrop, not
		-- a photograph. Swapped in per trial, restored with the snapshot.
		local ps1 = Instance.new("Sky")
		ps1.Name = "SimGrade_PS1Sky"
		local face = "rbxassetid://131765931649272"
		ps1.SkyboxBk, ps1.SkyboxFt, ps1.SkyboxLf, ps1.SkyboxRt, ps1.SkyboxUp, ps1.SkyboxDn =
			face, face, face, face, face, face
		ps1.CelestialBodiesShown = false
		ps1.StarCount = 0
		ps1.SunAngularSize = 0
		ps1.MoonAngularSize = 0
		ps1.Parent = Lighting
		table.insert(created, ps1)
	end
	if preset.atmosphere then
		make("Atmosphere", "SimGrade_Atmosphere", preset.atmosphere)
	end
	make("ColorGradingEffect", "SimGrade_Tonemap", { TonemapperPreset = get(preset, "tonemapper") })
	make("ColorCorrectionEffect", "SimGrade_Grade", {
		Saturation = get(preset, "saturation"),
		Contrast = get(preset, "contrast"),
		TintColor = get(preset, "tint"),
	})
	buildLamps(preset.lamps)
	activeId = id
	quantWanted = get(preset, "quantise") == true
	publishQuant()
	if quantWanted then
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value, function()
			if not motionOk() then return end
			local cam = workspace.CurrentCamera
			if not cam or cam.CameraType ~= Enum.CameraType.Custom then return end
			local cf = cam.CFrame
			local p = cf.Position
			local q = Vector3.new(
				math.floor(p.X * QUANT + 0.5) / QUANT,
				math.floor(p.Y * QUANT + 0.5) / QUANT,
				math.floor(p.Z * QUANT + 0.5) / QUANT)
			if q ~= p then cam.CFrame = cf.Rotation + q end
		end)
	end
end

local function restore()
	if not snapshot then return end
	RunService:UnbindFromRenderStep(BIND)
	quantWanted = false
	publishQuant()
	for _, inst in created do inst:Destroy() end
	table.clear(created)
	for e in disabledFx do
		if e.Parent then e.Enabled = true end
	end
	table.clear(disabledFx)
	if savedSky then
		savedSky.Parent = Lighting
		savedSky = nil
	end
	for k, v in snapshot do Lighting[k] = v end
	snapshot = nil
	activeId = ""
end

local function update()
	local id = player:GetAttribute("KenopsiaActiveTrial") or ""
	local want = id ~= "" and filterOn()
	if snapshot and (not want or id ~= activeId) then restore() end
	if want and not snapshot then apply(id) end
end

player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(update)
player:GetAttributeChangedSignal("KenopsiaSimFilter"):Connect(update)
player:GetAttributeChangedSignal("KenopsiaReduceFlicker"):Connect(publishQuant)
task.defer(update)
