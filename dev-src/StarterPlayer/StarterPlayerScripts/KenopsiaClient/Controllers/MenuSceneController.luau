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
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
	-- Original Enabled state per PostEffect, so "stop reducing" restores what was
	-- authored instead of switching everything on.
	effectsSaved = {},
	-- The Lighting fields the menu overwrites, captured on the way in. nil means
	-- "not applied"; see applyMenuLighting for why it is snapshotted only once.
	lightSaved = nil,
	-- Authored Neck.C0, captured once so the head can always be put back.
	neckBase = nil,
	lookConn = nil,
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

-- MOTION is ANIMATIONS, and nothing else.
--
-- This used to return true for ReduceEffects and ReduceFlicker as well, which
-- made REDUCE EFFECTS a second, mislabelled animation switch: turning it on
-- stopped the camera move and changed no effect whatsoever, because the toggle
-- had no applier at all. Effects are now their own concern -- see applyEffects
-- below -- and this reads exactly the one setting whose name it carries.
--
-- The settings table is read live rather than cached, so a mid-session toggle
-- takes effect immediately.
local function reducedMotion()
	local s = state.settings
	if not s then return false end
	return s.Animations == false
end

-- EFFECTS ---------------------------------------------------------------------
-- What REDUCE EFFECTS actually turns off: the post-processing in Lighting.
--
-- Selected by CLASS, not by a name list, so an effect added later is covered
-- without editing this file. The menu's own colour grade is deliberately
-- excluded: it is the art direction rather than an effect the player is asking
-- to be spared, and it costs practically nothing.

local function postEffects()
	local out = {}
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") and c.Name ~= GRADE_NAME then
			table.insert(out, c)
		end
	end
	return out
end

local function applyEffects()
	local reduce = state.settings and state.settings.ReduceEffects == true
	for _, e in postEffects() do
		if state.effectsSaved[e] == nil then
			state.effectsSaved[e] = e.Enabled
		end
		-- Never switch ON something that was authored OFF. DepthOfField ships
		-- disabled in this place, so a blanket `not reduce` would introduce an
		-- effect the moment the player turned the setting off.
		e.Enabled = (not reduce) and state.effectsSaved[e]
	end
end

local function restoreEffects()
	for e, original in state.effectsSaved do
		if e.Parent then e.Enabled = original end
	end
	table.clear(state.effectsSaved)
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

-- CHARACTER LOOK -------------------------------------------------------------
-- The menu character watches the CURSOR: wherever the mouse goes, the head
-- turns to follow, and a cursor resting on the character means it is looking
-- straight at the viewer.
--
-- HEAD ONLY, through the R6 Neck Motor6D. MenuPresenceService anchors the
-- character at CharacterAnchor and freezes its rotation, so turning the body
-- would be the client fighting the server for a part the server owns. The neck
-- is not read by anything else and is restored on release.
--
-- NOT a permanent RenderStepped. There are exactly three things that can change
-- where the head should point, and each drives it directly:
--
--   * the cursor moves   -> UserInputService.InputChanged, MouseMovement only
--   * the camera moves   -> per frame, but ONLY for the length of that move
--   * the character loads-> settleLook's three bounded re-reads
--
-- A still mouse in front of a still camera therefore costs nothing at all, which
-- is what the section 4 rule is actually asking for.
--
-- LANDING ONLY. Measured against the real markers, tracking SessionCamera needs
-- about 98 degrees of yaw -- the clamp holds at 55 and the head then points 43
-- degrees away from the camera, which reads as broken rather than as a stare.
-- At the wall the character is not the subject anyway, so the head returns to
-- rest as soon as the camera leaves the landing pose.
--
-- Defined ABOVE the camera section because goTo drives it; a Lua local must
-- exist before the code that references it.

local NECK_MAX_YAW = math.rad(55)
local NECK_MAX_PITCH = math.rad(28)
-- R6 head centre relative to torso centre.
local HEAD_OFFSET = CFrame.new(0, 1.5, 0)
-- How far the gaze slides from the lens as the cursor travels to the edge of the
-- screen, in studs. Measured at 6: the head then sweeps about -43 to +2 degrees
-- of yaw, and only the very top of the screen reaches the pitch clamp. Larger
-- values start clamping at the left and right edges too.
local CURSOR_GAZE_SPREAD = 6

-- Where the character is looking: the cursor.
--
-- Expressed as THE CAMERA, slid sideways by the cursor's offset from the centre
-- of the screen. That formulation is what makes a centred cursor -- a cursor
-- resting on the character -- come out as looking straight down the lens, which
-- is the whole point of the effect. Verified: centred gives yaw -23.8 / pitch
-- 10.2, the same angles that aim at the camera to 0.00 degrees.
--
-- Two alternatives were measured and rejected. A far point along the cursor ray
-- lands BEHIND the character (the camera looks toward it), so the head span
-- comes out at about 178 degrees and clamps everywhere. A plane at half the head
-- depth behaves, but puts the centred gaze at -39 degrees -- looking past the
-- viewer rather than at them.
local function lookTarget(camera)
	-- Touch and gamepad have no pointer; the head simply looks down the lens.
	if not UserInputService.MouseEnabled then return camera.CFrame.Position end
	local vp = camera.ViewportSize
	if vp.X <= 0 or vp.Y <= 0 then return camera.CFrame.Position end
	-- GetMouseLocation shares its origin with ViewportSize -- the true top-left,
	-- inset not applied. This is the same space question the retro cursor got
	-- wrong once; do not "correct" it with GetGuiInset.
	local m = UserInputService:GetMouseLocation()
	local ndcX = (m.X / vp.X) * 2 - 1
	local ndcY = 1 - (m.Y / vp.Y) * 2
	local cf = camera.CFrame
	return cf.Position
		+ cf.RightVector * (ndcX * CURSOR_GAZE_SPREAD)
		+ cf.UpVector * (ndcY * CURSOR_GAZE_SPREAD)
end

local function neckJoint()
	local character = player.Character
	local torso = character and character:FindFirstChild("Torso")
	local neck = torso and torso:FindFirstChild("Neck")
	if neck and neck:IsA("Motor6D") then return neck, torso end
	return nil, nil
end

local function updateLook(alpha)
	local neck, torso = neckJoint()
	if not neck then return end
	if state.neckBase == nil then state.neckBase = neck.C0 end

	local target = state.neckBase
	local camera = state.camera or workspace.CurrentCamera

	if state.active and state.pose == "Landing" and camera then
		local rest = torso.CFrame * HEAD_OFFSET
		local toCamera = lookTarget(camera) - rest.Position
		if toCamera.Magnitude > 0.05 then
			-- Clamped in TORSO space, so the limits are anatomical rather than
			-- world-aligned and stay correct however the character is turned.
			local d = torso.CFrame:VectorToObjectSpace(toCamera.Unit)
			local yaw = math.clamp(math.atan2(-d.X, -d.Z), -NECK_MAX_YAW, NECK_MAX_YAW)
			local pitch = math.clamp(math.asin(math.clamp(d.Y, -1, 1)), -NECK_MAX_PITCH, NECK_MAX_PITCH)
			local look = torso.CFrame:VectorToWorldSpace(
				(CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)).LookVector)
			local desired = CFrame.lookAt(rest.Position, rest.Position + look)

			-- Head = Torso * C0 * C1^-1, so C0 = Torso^-1 * Head * C1. Solving it
			-- this way avoids hand-deriving Euler axes against the R6 neck basis,
			-- which is where this kind of code usually goes wrong. Verified
			-- numerically: at rest it reproduces the authored C0 to 0.000000, and
			-- against LandingCamera the resulting head LookVector hits the camera
			-- to 0.00 degrees.
			local solved = torso.CFrame:Inverse() * desired * neck.C1
			-- Position pinned to the authored pivot: C1 carries a translation, so
			-- a rotated solve would otherwise slide the head off the neck.
			target = CFrame.new(state.neckBase.Position) * (solved - solved.Position)
		end
	end

	if alpha then
		neck.C0 = neck.C0:Lerp(target, alpha)
	else
		neck.C0 = target
	end
end

local function stopLookDriver()
	if state.lookConn then
		if state.lookConn.Connected then state.lookConn:Disconnect() end
		state.lookConn = nil
	end
end

-- Runs for the length of one camera move and no longer. While the camera is
-- still the head has nothing to follow, so there is nothing to spend a frame on.
local function driveLookDuring(tween)
	stopLookDriver()
	if not tween then
		updateLook()
		return
	end
	state.lookConn = RunService.RenderStepped:Connect(function(dt)
		updateLook(math.min(1, dt * 8))
	end)
	tween.Completed:Once(function()
		stopLookDriver()
		updateLook()
	end)
end

-- MenuPresenceService anchors the character at CharacterAnchor a short moment
-- AFTER it spawns, so a torso read taken the instant CharacterAdded fires can
-- still be at the spawn location. Since nothing drives the head while the camera
-- is still, that first bad read would simply stay on screen. Three bounded
-- re-reads settle it without leaving a permanent loop behind.
local function settleLook()
	for _, delay in { 0.1, 0.35, 0.8 } do
		task.delay(delay, function()
			if state.active then updateLook() end
		end)
	end
end

local function restoreLook()
	stopLookDriver()
	local neck = neckJoint()
	if neck and state.neckBase then neck.C0 = state.neckBase end
	state.neckBase = nil
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
		updateLook()
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
			updateLook()
			fire()
		end)
	else
		applyPose(markerName, fov, true)
		local tween = state.tween
		-- The head follows the camera for the length of the move and is then let
		-- go; a still camera gives it nothing to follow.
		driveLookDuring(tween)
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
-- Menu-only and client-side. The Sky and the authored post-effects are left
-- alone; everything this DOES touch is snapshotted on the way in and written
-- back on the way out, so nothing leaks into a trial.
--
-- 25.08.2026: it now moves the time of day too. The menu used to run under the
-- place's noon (Brightness 3, ClockTime 14.5, no fog), which flattened three
-- problems into one cause: the stage's own lamps -- a warm key on the landing,
-- an amber one on the subject, a cold one on the session wall -- were invisible
-- against daylight, the cold UI plates could not register over a lit wall, and
-- text at the bottom of the screen sat on bright concrete. Dropping the scene
-- to a cold night hands the lighting back to those three lamps, which is what
-- they were built for, and gives every overlay something dark to sit on.
local MENU_LIGHT = {
	Ambient = Color3.fromRGB(18, 24, 30),
	OutdoorAmbient = Color3.fromRGB(10, 14, 18),
	Brightness = 1,
	ClockTime = 0,
	FogStart = 25,
	FogEnd = 150,
	FogColor = Color3.fromRGB(4, 9, 13),
}
local LIGHT_FIELDS = { "Ambient", "OutdoorAmbient", "Brightness", "ClockTime",
	"FogStart", "FogEnd", "FogColor" }

local function applyMenuLighting()
	-- Snapshot ONCE. Re-entering while already applied would otherwise record
	-- the menu's own values as the originals and restore() would then leave the
	-- place in permanent night.
	if state.lightSaved then return end
	local saved = {}
	for _, f in LIGHT_FIELDS do saved[f] = Lighting[f] end
	state.lightSaved = saved
	for _, f in LIGHT_FIELDS do Lighting[f] = MENU_LIGHT[f] end
end

local function restoreMenuLighting()
	local saved = state.lightSaved
	if not saved then return end
	state.lightSaved = nil
	for _, f in LIGHT_FIELDS do Lighting[f] = saved[f] end
end

local function addGrade()
	applyMenuLighting()
	if state.grade and state.grade.Parent then return end
	local existing = Lighting:FindFirstChild(GRADE_NAME)
	if existing then existing:Destroy() end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = GRADE_NAME
	-- Pushed further than the old values now that it grades a night rather than
	-- a noon, and tinted onto the menu's own cold set.
	grade.Saturation = -0.45
	grade.Contrast = 0.16
	grade.Brightness = -0.03
	grade.TintColor = Color3.fromRGB(196, 224, 240)
	grade.Parent = Lighting
	state.grade = grade
end

local function removeGrade()
	restoreMenuLighting()
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
	applyEffects()
	hideOthers()
	-- The head follows the cursor, driven the same way the retro cursor is:
	-- InputChanged fires only when the mouse actually moves, so a still mouse
	-- costs nothing and the section 4 no-permanent-RenderStepped rule holds.
	-- Registered in state.conns, so release() disconnects it.
	table.insert(state.conns, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		if not state.active or state.pose ~= "Landing" then return end
		updateLook()
	end))
	goTo("Landing", { instant = true })
	settleLook()
end

local function release()
	if not state.active then
		removeGrade()
		restoreEffects()
		return
	end
	state.active = false
	cancelTween()
	-- The head goes back to the authored pose before anything else: a player
	-- teleporting into a trial must not carry a scripted neck with them.
	restoreLook()
	showOthers()
	removeGrade()
	restoreEffects()

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

-- The REDUCE EFFECTS applier. The settings table is shared, so the toggle has
-- already written the value by the time this runs; re-applying is all that is
-- needed and calling it twice is harmless.
function MenuSceneController.setEffectsReduced(reduce)
	if state.settings then state.settings.ReduceEffects = reduce == true end
	applyEffects()
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
		-- The old joint died with the old character, so the captured base pose
		-- belongs to nothing. Clearing it makes the next updateLook re-capture
		-- from the new rig instead of writing a stale CFrame onto it.
		stopLookDriver()
		state.neckBase = nil
		takeCamera()
		goTo(state.pose, { instant = true })
		settleLook()
	end)
	sync()

	return MenuSceneController
end

return MenuSceneController
