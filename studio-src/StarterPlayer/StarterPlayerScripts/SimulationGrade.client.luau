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

local QUANT = 8 -- steps per stud
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
		Ambient = Color3.fromRGB(34, 40, 56),
		OutdoorAmbient = Color3.fromRGB(14, 18, 28),
		Brightness = 1,
		ClockTime = 0,
		fog = { 45, 150, Color3.fromRGB(0, 0, 0) },
		tint = Color3.fromRGB(205, 218, 255),
		lamps = "minefield",
	},
	-- the canteen: sodium tubes, grease in the air, nothing beyond the walls
	canteen = {
		Ambient = Color3.fromRGB(62, 54, 46),
		OutdoorAmbient = Color3.fromRGB(34, 30, 28),
		Brightness = 1.35,
		fog = { 38, 140, Color3.fromRGB(18, 13, 10) },
		tint = Color3.fromRGB(255, 228, 192),
		saturation = -0.4,
		contrast = 0.12,
	},
	-- the range: overcast dusk, thick ground haze; the scope must stay honest,
	-- so no position quantisation here
	birdhunt = {
		Brightness = 1.1,
		atmosphere = { Density = 0.4, Offset = 0.22, Haze = 2.2, Glare = 0,
			Color = Color3.fromRGB(118, 112, 104), Decay = Color3.fromRGB(64, 58, 56) },
		tint = Color3.fromRGB(206, 214, 226),
		saturation = -0.3,
		quantise = false,
	},
}

local LIGHT_FIELDS = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "ExposureCompensation",
	"FogStart", "FogEnd", "FogColor" }

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
	player:SetAttribute("KenopsiaCamQuant", (quantWanted and motionOk()) and QUANT or 0)
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
			spot.Brightness = 2.6
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
