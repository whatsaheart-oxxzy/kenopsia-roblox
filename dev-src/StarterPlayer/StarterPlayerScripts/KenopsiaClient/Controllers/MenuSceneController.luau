--!nonstrict
-- MENU SCENE (Gate M1 §2 D/E/F).
--
-- Owns the 3D half of the main menu on this client: the camera, the local-only
-- hiding of other players, and the menu-only colour grade. It owns nothing in
-- the 2D UI -- that is MenuOverlayController's and SessionWallController's job.
--
-- Activation is NOT a client decision. The server attribute
-- `KenopsiaMenuActive`, written only by MenuPresenceService, is the single
-- source of truth. This module observes it and never sets it.
--
-- Everything it touches is restored on release: CameraType, CameraSubject,
-- FieldOfView, other players' transparency, the colour grade and the fade
-- layer. A player teleporting into a trial must not inherit a scripted camera.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local MenuSceneController = {}

local ACTIVE_ATTR = "KenopsiaMenuActive"

-- Camera poses. FOV values are part of the pose, not decoration: the tween
-- moves CFrame and FieldOfView together so the framing never lags the move.
local LANDING_FOV = 48
local SESSION_FOV = 38
local MOVE_TIME = 0.85
local MOVE_STYLE = Enum.EasingStyle.Cubic
local MOVE_DIRECTION = Enum.EasingDirection.InOut
-- Reduced-motion path: a short fade and a hard cut, never a shortened tween.
local CUT_FADE = 0.15

local GRADE_NAME = "KenopsiaMenuGrade"
local FADE_NAME = "KenopsiaMenuFade"

local state = {
	active = false,
	pose = "Landing",
	settings = nil,
	camera = nil,
	saved = nil,
	tween = nil,
	grade = nil,
	fade = nil,
	conns = {},
	charConns = {},
	warned = {},
}

local function warnOnce(key, message)
	if state.warned[key] then return end
	state.warned[key] = true
	warn("[MenuScene] " .. message)
end

local function stage()
	return workspace:FindFirstChild("MenuStage")
end

local function marker(name)
	local s = stage()
	local m = s and s:FindFirstChild(name)
	if not m then
		warnOnce(name, "MenuStage." .. name .. " missing - camera move skipped")
	end
	return m
end

-- Animations off OR Reduce Effects on both mean "do not animate". The settings
-- table is read live rather than cached, so toggling mid-session takes effect
-- immediately. Both the current key (`ReduceFlicker`) and the name the UI pass
-- renames it to (`ReduceEffects`) are accepted, so this keeps working across
-- that rename instead of silently reverting to animated.
local function reducedMotion()
	local s = state.settings
	if not s then return false end
	if s.Animations == false then return true end
	if s.ReduceEffects == true then return true end
	if s.ReduceFlicker == true then return true end
	return false
end

-- FADE ----------------------------------------------------------------------

local function ensureFade()
	if state.fade and state.fade.Parent then return state.fade end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end
	local gui = pg:FindFirstChild(FADE_NAME)
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = FADE_NAME
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 10000
		gui.Enabled = true
		local frame = Instance.new("Frame")
		frame.Name = "Cover"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = gui
		gui.Parent = pg
	end
	state.fade = gui
	return gui
end

-- Fades to black, runs `apply` while covered, then fades back. Returns only
-- after the cut so callers cannot race the pose change.
local function hardCut(apply)
	local gui = ensureFade()
	local cover = gui and gui:FindFirstChild("Cover")
	if not cover then
		apply()
		return
	end
	cover.BackgroundTransparency = 1
	cover.Visible = true
	local inTween = TweenService:Create(cover, TweenInfo.new(CUT_FADE), { BackgroundTransparency = 0 })
	inTween:Play()
	inTween.Completed:Wait()
	apply()
	local outTween = TweenService:Create(cover, TweenInfo.new(CUT_FADE), { BackgroundTransparency = 1 })
	outTween:Play()
	outTween.Completed:Once(function()
		cover.Visible = false
	end)
end

-- CAMERA ---------------------------------------------------------------------

local function takeCamera()
	local camera = workspace.CurrentCamera
	if not camera then return false end
	state.camera = camera
	if not state.saved then
		-- Captured once per activation. Re-capturing after we have already gone
		-- Scriptable would save OUR state as the original and make release a
		-- no-op that strands the player on a scripted camera.
		state.saved = {
			cameraType = camera.CameraType,
			cameraSubject = camera.CameraSubject,
			fieldOfView = camera.FieldOfView,
		}
	end
	camera.CameraType = Enum.CameraType.Scriptable
	return true
end

local function cancelTween()
	if state.tween then
		state.tween:Cancel()
		state.tween = nil
	end
end

local function applyPose(markerName, fov, animate)
	local m = marker(markerName)
	local camera = state.camera or workspace.CurrentCamera
	if not (m and camera) then return end
	cancelTween()

	if not animate then
		camera.CFrame = m.CFrame
		camera.FieldOfView = fov
		return
	end

	-- One tween drives CFrame and FieldOfView together, which is what keeps the
	-- move reading as a single camera push rather than a pan with a separate
	-- zoom riding on top of it.
	state.tween = TweenService:Create(
		camera,
		TweenInfo.new(MOVE_TIME, MOVE_STYLE, MOVE_DIRECTION),
		{ CFrame = m.CFrame, FieldOfView = fov }
	)
	state.tween:Play()
end

-- Returns true only if the move actually started. Callers hide UI on the way
-- into a move, so a silent false here would leave the player on a bare scene
-- with no menu and no way back. They must branch on the result.
local function goTo(pose, opts)
	opts = opts or {}
	if not state.active then return false end
	if not takeCamera() then return false end
	if not marker(pose == "Session" and "SessionCamera" or "LandingCamera") then
		return false
	end
	state.pose = pose
	local markerName = pose == "Session" and "SessionCamera" or "LandingCamera"
	local fov = pose == "Session" and SESSION_FOV or LANDING_FOV

	-- onArrive fires when the camera has reached its destination, on every path.
	-- Callers must not guess the duration with their own task.delay: the three
	-- routes settle at wildly different times (instant, ~CUT_FADE, MOVE_TIME),
	-- and a guessed delay would reveal the wall mid-move.
	local arrive = opts.onArrive
	local function fire()
		if arrive then task.spawn(arrive) end
	end

	if opts.instant then
		applyPose(markerName, fov, false)
		fire()
	elseif reducedMotion() then
		-- Reduced motion: fade to black over CUT_FADE, move the camera while
		-- covered, then fade back. onArrive fires as soon as the camera has
		-- MOVED -- i.e. after the fade-in and the cut, not after the fade-out.
		-- That is deliberate: the wall then appears behind black and is already
		-- there as the cover clears, instead of popping in afterwards. So the
		-- arrival latency here is ~CUT_FADE, not 2 x CUT_FADE.
		task.spawn(function()
			hardCut(function() applyPose(markerName, fov, false) end)
			fire()
		end)
	else
		applyPose(markerName, fov, true)
		local tween = state.tween
		if tween then
			tween.Completed:Once(function(playbackState)
				-- A cancelled tween means another move superseded this one, so
				-- the caller must not be told it arrived here.
				if playbackState == Enum.PlaybackState.Completed then fire() end
			end)
		else
			fire()
		end
	end
	return true
end

function MenuSceneController.goToSession(opts) return goTo("Session", opts) end
function MenuSceneController.goToLanding(opts) return goTo("Landing", opts) end
function MenuSceneController.currentPose() return state.pose end

-- OTHER PLAYERS --------------------------------------------------------------
-- Each client sees only its own character in the menu, even with up to four
-- standing on the same collision-free anchor. Local-only: LocalTransparencyModifier
-- is a client-side render property and changes nothing on the server.

local function hideCharacter(character)
	if not character then return end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		end
	end
end

local function showCharacter(character)
	if not character then return end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 0
		end
	end
end

local function trackOther(other)
	if other == player then return end
	local function bind(character)
		if not state.active then return end
		hideCharacter(character)
		-- Accessories and limbs stream in after CharacterAdded. Binding to
		-- DescendantAdded keeps late arrivals hidden without a per-frame sweep,
		-- which the performance rules rule out.
		local conn = character.DescendantAdded:Connect(function(d)
			if not state.active then return end
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
			end
		end)
		table.insert(state.charConns, conn)
	end
	if other.Character then bind(other.Character) end
	table.insert(state.charConns, other.CharacterAdded:Connect(bind))
end

local function hideOthers()
	for _, other in Players:GetPlayers() do
		trackOther(other)
	end
	table.insert(state.conns, Players.PlayerAdded:Connect(trackOther))
end

local function showOthers()
	for _, conn in state.charConns do
		if conn.Connected then conn:Disconnect() end
	end
	table.clear(state.charConns)
	for _, other in Players:GetPlayers() do
		if other ~= player then showCharacter(other.Character) end
	end
end

-- LIGHTING -------------------------------------------------------------------
-- Menu-only and client-side. No global time-of-day change: ClockTime, the Sky
-- and the existing post-effects are left exactly as authored, so nothing here
-- leaks into a trial.

local function addGrade()
	if state.grade and state.grade.Parent then return end
	local existing = Lighting:FindFirstChild(GRADE_NAME)
	if existing then existing:Destroy() end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = GRADE_NAME
	grade.Saturation = -0.28
	grade.Contrast = 0.08
	grade.Brightness = -0.02
	grade.TintColor = Color3.fromRGB(238, 242, 245)
	grade.Parent = Lighting
	state.grade = grade
end

local function removeGrade()
	if state.grade then
		state.grade:Destroy()
		state.grade = nil
	end
	local stray = Lighting:FindFirstChild(GRADE_NAME)
	if stray then stray:Destroy() end
end

-- LIFECYCLE ------------------------------------------------------------------

local function engage()
	if state.active then return end
	state.active = true
	takeCamera()
	addGrade()
	hideOthers()
	goTo("Landing", { instant = true })
end

local function release()
	if not state.active then
		removeGrade()
		return
	end
	state.active = false
	cancelTween()
	showOthers()
	removeGrade()

	for _, conn in state.conns do
		if conn.Connected then conn:Disconnect() end
	end
	table.clear(state.conns)

	local camera = state.camera or workspace.CurrentCamera
	if camera and state.saved then
		camera.CameraType = state.saved.cameraType
		camera.CameraSubject = state.saved.cameraSubject
		camera.FieldOfView = state.saved.fieldOfView
		-- If the character exists, point the restored camera back at it rather
		-- than trusting a subject captured before the character spawned.
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
			camera.CameraType = Enum.CameraType.Custom
		end
	end
	state.saved = nil
	state.pose = "Landing"

	local gui = state.fade
	local cover = gui and gui:FindFirstChild("Cover")
	if cover then
		cover.Visible = false
		cover.BackgroundTransparency = 1
	end
end

MenuSceneController.release = release

function MenuSceneController.bindSettings(settings)
	state.settings = settings
end

function MenuSceneController.start(settings)
	if settings then state.settings = settings end

	local function sync()
		if player:GetAttribute(ACTIVE_ATTR) == true then
			engage()
		else
			release()
		end
	end

	player:GetAttributeChangedSignal(ACTIVE_ATTR):Connect(sync)
	-- The camera is recreated on respawn, so the pose has to be re-applied
	-- against the new one rather than assuming the old camera survived.
	player.CharacterAdded:Connect(function()
		if not state.active then return end
		state.camera = nil
		state.saved = nil
		takeCamera()
		goTo(state.pose, { instant = true })
	end)
	sync()

	return MenuSceneController
end

return MenuSceneController
