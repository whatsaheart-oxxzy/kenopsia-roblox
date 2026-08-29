--!nonstrict
-- GRADE DIRECTOR -- the per-trial blue grade (INNER-GAME-PLAN section 4 step
-- 2). Successor to SimulationGrade (removed from the place 27.08.2026,
-- archived in ServerStorage.KenopsiaAuthoring.Archive): same proven
-- snapshot/apply/restore mechanics, but the presets live in
-- Shared/Config/GradePresets (pure data, proved offline by tests/grade.lua)
-- and the restore now PROVES itself byte-for-byte.
--
-- SCOPE OF A GRADE: KenopsiaTrialId (MachineFlow.setTrialId), set once per
-- trial and cleared once at its end -- NOT KenopsiaActiveTrial, which is a
-- ROUND flag that reads "" during the standings card and the 3-2-1 between
-- rounds (26.08.2026 ruling). Keying the grade on the trial id keeps the look
-- steady across those gaps (the old module restored+reapplied on every
-- standings card: a visible lighting pop) and keeps it up through a death and
-- respawn mid-trial. Quantisation follows the ROUND flag: the camera steps
-- only while a round actually runs. A trial switch with no lobby gap is one
-- attribute change: update() restores the old grade and applies the new one
-- in the same pass.
--
-- APPLY: snapshot the five Lighting scalars this script writes (Ambient,
-- OutdoorAmbient, FogStart, FogEnd, FogColor -- raw property values), write
-- the preset, parent ONE ColorCorrectionEffect "KenopsiaGrade" to Lighting.
-- GlobalShadows / EnvironmentDiffuseScale / EnvironmentSpecularScale are NOT
-- touched -- the P2 step-1 baseline owns them permanently -- and no sky swap,
-- no Atmosphere, no lamp rasters in Phase 2 (arenas are lit as authored).
--
-- RESTORE, proved in two halves (comparing only values READ BACK from the
-- properties, never recomputed Color3s -- so every compare is float-exact by
-- construction):
--   1. BEFORE writing anything, compare Lighting against the read-back taken
--      right after apply() wrote the preset. A difference here means a third
--      party wrote Lighting while the grade held. (Comparing only AFTER the
--      restore write would prove nothing about this -- the write itself
--      erases the evidence.)
--   2. Destroy the effect, write every snapshotted value back, read each
--      property again and compare == against the snapshot. A difference here
--      means the write itself failed or was clamped by the engine.
-- Either failure sets Lighting attribute GradeRestoreMismatch = trialId for
-- the QA pass and fires one warn per session per cause.
--
-- CAMERA QUANTISATION (1/8 stud from the preset, position only, NEVER
-- rotation): published as KenopsiaCamQuant (steps per stud) on the
-- LocalPlayer. The monolith's RenderStepped camera writer still reads that
-- attribute -- the hook was deliberately kept on 27.08.2026 as the re-arm
-- point -- and snaps every Scriptable camera (machineCam / spectate /
-- trialCam / runnerCam), so that half costs this script nothing and NO new
-- per-frame loop is added for it. The default (Custom) camera was always the
-- grade script's own half: the BindToRenderStep below reproduces the
-- archive's binding (priority Last, Custom cameras only). The two can never
-- fight over one camera -- the monolith writer guards on Scriptable, this
-- binding on Custom -- and KenopsiaClient itself is not touched.
--
-- OFF-SWITCHES: SIMULATION FILTER (KenopsiaSimFilter ~= false, published by
-- the monolith at boot) gates the whole grade. Reduce Motion (OS
-- ReducedMotionEnabled OR KenopsiaReduceFlicker -- the UiFx convention) and
-- the sniper scope (PlayerGui.KenopsiaMachine.Scope.Visible, the one clean
-- external scope signal) gate QUANTISATION only: suspending the colour grade
-- mid-round would pop the fog on every zoom.
--
-- Cost: one post-effect, one attribute write per state change, one CFrame
-- compare per frame while quantising. Every external touch is pcall-wrapped;
-- this script must never error.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local okPresets, GradePresets = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
		:WaitForChild("Config"):WaitForChild("GradePresets"))
end)
if not okPresets or type(GradePresets) ~= "table" or type(GradePresets.Presets) ~= "table" then
	warn("[GradeDirector] GradePresets missing or malformed -- grade disabled")
	return
end

local BIND = "KenopsiaGradeDirector"
local EFFECT_NAME = "KenopsiaGrade"

-- Only what apply() writes gets snapshotted; restore is exactly this list.
local LIGHT_FIELDS = { "Ambient", "OutdoorAmbient", "FogStart", "FogEnd", "FogColor" }

local snapshot = nil -- [field] = raw value captured at apply; nil = no grade up
local applied = nil -- [field] = read-back after apply wrote the preset (restore proof half 1)
local effect = nil -- the one ColorCorrectionEffect while a grade holds
local activeId = ""
local bound = false
local quantSteps = 0 -- steps per stud while a round runs and the preset asks, else 0
local scopeVisible = false

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[GradeDirector] " .. msg)
end

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function filterOn()
	return player:GetAttribute("KenopsiaSimFilter") ~= false
end

local function motionOk()
	return not GuiService.ReducedMotionEnabled and player:GetAttribute("KenopsiaReduceFlicker") ~= true
end

-- KenopsiaCamQuant: steps per stud, 0 = off. The monolith's RenderStepped
-- writer consumes it for Scriptable cameras; the binding below consumes it
-- (via quantSteps) for the Custom camera. Suspension (Reduce Motion, scope)
-- publishes 0 so BOTH halves stop together. KenopsiaCamStep (the one-day
-- 30 Hz hold) has no reader left and is not published.
local function publishQuant()
	local on = quantSteps > 0 and motionOk() and not scopeVisible
	player:SetAttribute("KenopsiaCamQuant", on and quantSteps or 0)
end

local function updateQuant()
	local roundId = player:GetAttribute("KenopsiaActiveTrial") or ""
	local preset = snapshot and GradePresets.Presets[activeId] or nil
	local step = preset and preset.camQuant
	if type(step) == "number" and step > 0 and roundId == activeId then
		quantSteps = math.floor(1 / step + 0.5) -- 1/8 stud -> 8 steps per stud
	else
		quantSteps = 0
	end
	publishQuant()
end

local function apply(id)
	if snapshot then return end
	local preset = GradePresets.Presets[id]
	if not preset then return end
	local snap = {}
	for _, f in LIGHT_FIELDS do snap[f] = Lighting[f] end
	snapshot = snap
	activeId = id
	local ok, err = pcall(function()
		if preset.ambient then Lighting.Ambient = rgb(preset.ambient) end
		if preset.outdoorAmbient then Lighting.OutdoorAmbient = rgb(preset.outdoorAmbient) end
		if preset.fogStart then Lighting.FogStart = preset.fogStart end
		if preset.fogEnd then Lighting.FogEnd = preset.fogEnd end
		if preset.fogColor then Lighting.FogColor = rgb(preset.fogColor) end
		-- preset.atmosphere is reserved data, deliberately unread: while an
		-- Atmosphere exists under Lighting the engine ignores Fog* entirely,
		-- which would kill the classic-fog grade above.
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = EFFECT_NAME
		cc.Saturation = preset.ccSat or 0
		cc.Contrast = preset.ccContrast or 0
		cc.TintColor = preset.ccTint and rgb(preset.ccTint) or Color3.new(1, 1, 1)
		cc.Parent = Lighting
		effect = cc
	end)
	if not ok then
		warnOnce("apply", "apply('" .. id .. "') failed: " .. tostring(err))
	end
	-- Read back what the writes actually produced (post-clamp, post-float-
	-- conversion): the expectation restore() checks Lighting against to detect
	-- a third-party write. Captured even after a partial failure -- whatever
	-- state apply left IS the state nothing else may touch.
	local seen = {}
	for _, f in LIGHT_FIELDS do seen[f] = Lighting[f] end
	applied = seen
	if type(preset.camQuant) == "number" and preset.camQuant > 0 and not bound then
		bound = true
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Last.Value, function()
			if quantSteps <= 0 or scopeVisible or not motionOk() then return end
			local cam = workspace.CurrentCamera
			if not cam or cam.CameraType ~= Enum.CameraType.Custom then return end
			local cf = cam.CFrame
			local p = cf.Position
			local q = Vector3.new(
				math.floor(p.X * quantSteps + 0.5) / quantSteps,
				math.floor(p.Y * quantSteps + 0.5) / quantSteps,
				math.floor(p.Z * quantSteps + 0.5) / quantSteps)
			if q ~= p then cam.CFrame = cf.Rotation + q end
		end)
	end
	updateQuant()
end

local function restore()
	if not snapshot then return end
	if bound then
		bound = false
		pcall(function() RunService:UnbindFromRenderStep(BIND) end)
	end
	quantSteps = 0
	publishQuant()
	if effect then
		pcall(function() effect:Destroy() end)
		effect = nil
	end
	local snap, seen, id = snapshot, applied, activeId
	snapshot, applied, activeId = nil, nil, ""
	-- Proof half 1 -- BEFORE the restore write erases the evidence: Lighting
	-- must still hold exactly what apply() read back after writing the preset.
	-- Exact ==, no epsilon (comparing two read-backs of the same property, so
	-- no recomputed Color3 float trap). A difference = a third party wrote
	-- Lighting while the grade held.
	-- One known legitimate writer: LightGuard's one-shot low-quality ambient
	-- bump (it stamps Lighting attribute KenopsiaLowLight). A late-joining
	-- phone applies the grade first and gets the bump 3s later, mid-grade --
	-- ambient drift with the stamp set is that sentinel, not a bug, and must
	-- not pollute the QA attribute. Fog drift is never legitimate.
	local lowLight = Lighting:GetAttribute("KenopsiaLowLight") == true
	local drift = false
	if seen then
		for _, f in LIGHT_FIELDS do
			if Lighting[f] ~= seen[f]
				and not (lowLight and (f == "Ambient" or f == "OutdoorAmbient")) then
				drift = true
			end
		end
	end
	if drift then
		pcall(function() Lighting:SetAttribute("GradeRestoreMismatch", id) end)
		warnOnce("drift", "third-party Lighting write during trial '" .. id .. "' (GradeRestoreMismatch set)")
	end
	-- Proof half 2: write the snapshot back and verify the write took --
	-- the same raw value written back must read back identical.
	local wrote = pcall(function()
		for _, f in LIGHT_FIELDS do Lighting[f] = snap[f] end
	end)
	local exact = wrote
	if wrote then
		for _, f in LIGHT_FIELDS do
			if Lighting[f] ~= snap[f] then exact = false end
		end
	end
	if not exact then
		pcall(function() Lighting:SetAttribute("GradeRestoreMismatch", id) end)
		warnOnce("restore", "Lighting restore write-back mismatch after trial '" .. id .. "' (GradeRestoreMismatch set)")
	end
end

local function update()
	local id = player:GetAttribute("KenopsiaTrialId") or ""
	if id == "" then
		-- Backstop for any flow that never calls setTrialId: fall back to the
		-- round flag (old SimulationGrade behaviour, pops between rounds).
		id = player:GetAttribute("KenopsiaActiveTrial") or ""
	end
	local want = id ~= "" and filterOn() and GradePresets.Presets[id] ~= nil
	if snapshot and (not want or id ~= activeId) then restore() end
	if want and not snapshot then apply(id) end
	updateQuant()
end

-- The scope GUI is the one clean external "in a scope" signal (Visible is
-- written to exactly the monolith's `scoped` on every toggle). Resolved in
-- the background so a lobby without the frame never blocks or errors.
task.spawn(function()
	local ok, scope = pcall(function()
		local gui = player:WaitForChild("PlayerGui"):WaitForChild("KenopsiaMachine", 60)
		return gui and gui:WaitForChild("Scope", 60) or nil
	end)
	if not ok or not scope then return end
	scopeVisible = scope.Visible == true
	scope:GetPropertyChangedSignal("Visible"):Connect(function()
		scopeVisible = scope.Visible == true
		publishQuant()
	end)
	publishQuant()
end)

player:GetAttributeChangedSignal("KenopsiaTrialId"):Connect(update)
player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(update)
player:GetAttributeChangedSignal("KenopsiaSimFilter"):Connect(update)
player:GetAttributeChangedSignal("KenopsiaReduceFlicker"):Connect(publishQuant)
-- Seeds only the published attribute; a player's own setting rows follow the
-- monolith's ON-only convention and arrive via KenopsiaReduceFlicker above.
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(publishQuant)
task.defer(update)
