--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PHOSPHOR = Color3.fromHex("78FFAA")
local IDLE = Color3.fromHex("8CE8AE")
local DIM = Color3.fromHex("2E6B4A")
local AMBER = Color3.fromHex("FFBA3C")
-- 23.08.2026: one-shot constants live in one table -- Luau allows 200 live
-- locals per function and the main chunk went over it after the P1 merge.
local K = {
	SNIPER_BASE_FOV = 70,
	ZOOMS = { { fov = 35, label = "x2" }, { fov = 18, label = "x4" } },
	FIRE_COOLDOWN = 2.2,
	MARK_LIFETIME = 1.0,
	MARK_POOL_MAX = 64,
	CP_PLATE_COOLDOWN = 0.16,
	CP_MOUTH_COOLDOWN = 0.35,
	CP_FORK_CAPACITY = 4,
	CP_IDLE = Color3.fromRGB(150, 158, 152),
	CP_WARN = Color3.fromRGB(255, 176, 40),
	CP_DANGER = Color3.fromRGB(255, 58, 44),
	CP_SAFE = Color3.fromRGB(120, 208, 128),
	CP_PIP_EMPTY = Color3.fromRGB(40, 46, 40),
	PODIUM_ORDINAL = { "1ST", "2ND", "3RD" },
	SETTING_ATTR = { Crt = "KenopsiaCRT" },
	SFX_POOLS = { Click = "Clicks", Submit = "Submits" },
	FORWARD_BIND = "KenopsiaForwardOnly",
	KNOWN_KINDS = { selection = true, info = true, status = true, round = true, score = true, announce = true, hide = true, rolecard = true },
}

local remotes = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
local RoomState = remotes:WaitForChild("RoomState")
local MachineState = remotes:WaitForChild("MachineState")
local ReadyReq = remotes:WaitForChild("RoomReadyRequest")
local SniperFire = remotes:FindFirstChild("SniperFire")
local SniperAim = remotes:FindFirstChild("SniperAim")
task.spawn(function()
	SniperFire = SniperFire or remotes:WaitForChild("SniperFire")
	SniperAim = SniperAim or remotes:WaitForChild("SniperAim")
end)
-- Left over from the removed XBot rig: no server code creates either remote any
-- more, so both WaitForChild calls always ran to their full timeout and cost
-- EVERY client 30 seconds of dead boot before the rest of this script executed
-- (measured: "[Kenopsia] client online" landed ~34 s after join, and the
-- crosshair, HUD and input bindings below with it). Resolve them the way
-- SniperFire/SniperAim are resolved above -- optional, off the critical path,
-- and still adopted if they ever come back. Both uses are already nil-guarded.
local XBotPush = remotes:FindFirstChild("XBotPush")
local XBotCrouch = remotes:FindFirstChild("XBotCrouch")
task.spawn(function()
	XBotPush = XBotPush or remotes:WaitForChild("XBotPush", 15)
	XBotCrouch = XBotCrouch or remotes:WaitForChild("XBotCrouch", 15)
end)

local machine = playerGui:WaitForChild("KenopsiaMachine")
-- P1.5: every cps, tween duration, easing, shake and flicker number the
-- screens use comes from Shared/Config/FeelConfig (the timing bible). ONE
-- local on purpose -- this chunk sits near Luau's 200-local ceiling.
local Feel = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("FeelConfig"))

-- MachineLayout stamps the detected platform on the gui; touch buttons show
-- on mobile always, on desktop only when a touchscreen exists, never on console
local function touchAllowed()
	local p = machine:GetAttribute("Platform")
	if p == "Console" then return false end
	if p == "Mobile" then return true end
	return UserInputService.TouchEnabled
end
local selection = machine:WaitForChild("Selection")
local info = machine:WaitForChild("Info")
local statusScreen = machine:WaitForChild("Status")
local roundCard = machine:WaitForChild("RoundCard")
local briefing = machine:WaitForChild("Briefing")
local scoreScreen = machine:WaitForChild("Score")
local announceScreen = machine:WaitForChild("Announce")
local faderFrame = machine:WaitForChild("Fader")
local scopeGui = machine:WaitForChild("Scope")
local hipCross = machine:WaitForChild("HipCross")
local touchControls = machine:WaitForChild("TouchControls")

-- Hunter pre-leg look-speed setup, matching the reference control step while
-- keeping the visual language original to Kenopsia.
local lookSpeedLevel = 5
local lookSensitivity = 0.005
local hunterSetupActive = false
local lookPanel = Instance.new("Frame")
lookPanel.Name = "HunterLookSetup"
lookPanel.Size = UDim2.fromScale(1, 1)
lookPanel.BackgroundColor3 = Color3.fromRGB(2, 6, 4)
lookPanel.BackgroundTransparency = 1
lookPanel.BorderSizePixel = 0
lookPanel.ZIndex = 80
lookPanel.Visible = false
lookPanel.Parent = machine

local function addSizeLimits(gui, minSize, maxSize)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = minSize
	constraint.MaxSize = maxSize
	constraint.Parent = gui
end
do
	local lookTitle = Instance.new("TextLabel")
	lookTitle.Name = "Title"
	lookTitle.AnchorPoint = Vector2.new(0.5, 0.5)
	lookTitle.Position = UDim2.fromScale(0.5, 0.77)
	lookTitle.Size = UDim2.new(0.88, 0, 0, 42)
	lookTitle.BackgroundTransparency = 1
	lookTitle.Font = Enum.Font.Code
	lookTitle.Text = "ADJUST LOOK SPEED"
	lookTitle.TextColor3 = PHOSPHOR
	lookTitle.TextSize = 24
	lookTitle.ZIndex = 81
	lookTitle.Parent = lookPanel
	addSizeLimits(lookTitle, Vector2.new(260, 42), Vector2.new(520, 42))

	local lookHint = Instance.new("TextLabel")
	lookHint.AnchorPoint = Vector2.new(0.5, 0.5)
	lookHint.Position = UDim2.fromScale(0.5, 0.91)
	lookHint.Size = UDim2.new(0.9, 0, 0, 28)
	lookHint.BackgroundTransparency = 1
	lookHint.Font = Enum.Font.Code
	lookHint.Text = "CLICK / TAP BAR     LEFT / RIGHT"
	lookHint.TextColor3 = DIM
	lookHint.TextSize = 16
	lookHint.ZIndex = 81
	lookHint.Parent = lookPanel
	addSizeLimits(lookHint, Vector2.new(280, 28), Vector2.new(540, 28))
end

local lookTrack = Instance.new("TextButton")
lookTrack.Name = "Track"
lookTrack.AnchorPoint = Vector2.new(0.5, 0.5)
lookTrack.Position = UDim2.fromScale(0.5, 0.84)
lookTrack.Size = UDim2.new(0.76, 0, 0, 50)
lookTrack.BackgroundColor3 = Color3.fromRGB(8, 18, 13)
lookTrack.BorderColor3 = DIM
lookTrack.BorderSizePixel = 2
lookTrack.AutoButtonColor = false
lookTrack.Font = Enum.Font.Code
lookTrack.TextColor3 = IDLE
lookTrack.TextSize = 24
lookTrack.ZIndex = 81
lookTrack.Parent = lookPanel

addSizeLimits(lookTrack, Vector2.new(250, 50), Vector2.new(440, 50))

local scopeLook = Instance.new("TextLabel")
scopeLook.Name = "ScopeLookSpeed"
scopeLook.AnchorPoint = Vector2.new(0.5, 1)
scopeLook.Position = UDim2.new(0.5, 0, 1, -24)
scopeLook.Size = UDim2.new(0.72, 0, 0, 32)
scopeLook.BackgroundColor3 = Color3.fromRGB(5, 12, 8)
scopeLook.BackgroundTransparency = 0.18
scopeLook.BorderColor3 = DIM
scopeLook.BorderSizePixel = 1
scopeLook.Font = Enum.Font.Code
scopeLook.TextColor3 = IDLE
scopeLook.TextSize = 16
scopeLook.ZIndex = 82
scopeLook.Visible = false
scopeLook.Parent = machine
addSizeLimits(scopeLook, Vector2.new(220, 32), Vector2.new(360, 32))

local youLabel = Instance.new("TextLabel")
youLabel.Name = "RunnerYou"
youLabel.AnchorPoint = Vector2.new(0.5, 0.5)
youLabel.Position = UDim2.fromScale(0.5, 0.72)
youLabel.Size = UDim2.fromOffset(180, 42)
youLabel.BackgroundTransparency = 1
youLabel.Font = Enum.Font.Code
youLabel.Text = "[  YOU  ]"
youLabel.TextColor3 = PHOSPHOR
youLabel.TextSize = 26
youLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
youLabel.TextStrokeTransparency = 0.25
youLabel.ZIndex = 70
youLabel.Visible = false
youLabel.Parent = machine

local function setLookSpeed(level)
	lookSpeedLevel = math.clamp(math.floor(level + 0.5), 1, 10)
	lookSensitivity = 0.0025 + lookSpeedLevel * 0.0005
	local cells = string.rep("■", lookSpeedLevel) .. string.rep("□", 10 - lookSpeedLevel)
	lookTrack.Text = cells
	scopeLook.Text = "LOOK SPEED  " .. cells
end
local function setHunterSetup(on)
	hunterSetupActive = on
	lookPanel.Visible = on
	if on then
		setLookSpeed(lookSpeedLevel)
		if machine:GetAttribute("Platform") == "Console" then
			pcall(function() GuiService.SelectedObject = lookTrack end)
		end
	elseif GuiService.SelectedObject == lookTrack then
		GuiService.SelectedObject = nil
	end
end
lookTrack.InputBegan:Connect(function(input)
	if not hunterSetupActive then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		local alpha = math.clamp((input.Position.X - lookTrack.AbsolutePosition.X) / math.max(1, lookTrack.AbsoluteSize.X), 0, 1)
		setLookSpeed(math.ceil(alpha * 10))
	end
end)
UserInputService.InputBegan:Connect(function(input)
	if not hunterSetupActive then return end
	if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then
		setLookSpeed(lookSpeedLevel - 1)
	elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then
		setLookSpeed(lookSpeedLevel + 1)
	end
end)
setLookSpeed(lookSpeedLevel)

local session = 0
-- P1.6: kinds the funnel renders. Anything else is logged once and IGNORED,
-- because bumping `session` for an unknown kind cancels every typewriter and
-- odometer mid-word (this happened once with kind = "select").
local unknownKinds = {}
local myReady = false
local maxPlayers = 4
-- C3: true while this client is on the bench (present in RoomState.spectators,
-- absent from members). Module scope because updateReadyVisual() is also called
-- from showInfo(), which never sees a RoomState payload.
local amSpectator = false
-- Captured on first use so the spectator notice can be undone without assuming
-- what the GUI ships in TopTicker.Text.
local tickerDefaultText = nil
-- C1.a: this round's server-issued token. Arrives on the role payload and must
-- be echoed on every TrialInput packet; the server rejects anything that does
-- not match. Cleared on role="none" so a stale token can never be replayed.
local trialRoundToken = nil
local pendingRunner = false
-- MP-05 ROUTER. Packets with kind="trial" are dispatched to
-- StarterPlayerScripts.TrialClients.<id> through TrialClientKit; this file only
-- lends closures over its own locals (built after the helpers exist, right
-- before the funnel). The WaitForChild is bounded so a place where the kit has
-- not been pushed yet still boots -- router disabled, one warn.
local trialKitModule = script.Parent:FindFirstChild("TrialClientKit")
	or script.Parent:WaitForChild("TrialClientKit", 10)
local TrialClientKit = trialKitModule and require(trialKitModule) or nil
if not TrialClientKit then
	warn("[KenopsiaClient] TrialClientKit missing - MP-05 trials disabled")
end
local trialClientsFolder = script.Parent:FindFirstChild("TrialClients")
local trialRouter = nil
local trialCam = nil        -- { mode = "top"|"fixed"|"follow", ... } owned by the router
local trialWalkSpeed = 0    -- WalkSpeed while moveState == "trial"

-- SESSION SETTINGS + UI AUDIO -----------------------------------------------

-- P2.3: Reduce Motion in the OS pre-selects REDUCE FLICKER and REDUCE SHAKE;
-- every setting is mirrored onto the local Player as an attribute
-- (KenopsiaUiSound, ..., KenopsiaSimFilter, KenopsiaCRT, KenopsiaReduceShake)
-- so UiFx / SimulationGrade can read it.
local uiSettings = { UiSound = true, Music = true, ReduceFlicker = GuiService.ReducedMotionEnabled == true,
	SimFilter = true, Crt = true, ReduceShake = GuiService.ReducedMotionEnabled == true }
local function publishSetting(key)
	player:SetAttribute(K.SETTING_ATTR[key] or ("Kenopsia" .. key), uiSettings[key])
end
for key in uiSettings do publishSetting(key) end

-- Click/Submit draw a random variant from their pool so repeated presses
-- don't sound like a sample loop
-- P0.3: a name with no Sound under SoundService.KenopsiaAudio.SFX used to be a
-- silent no-op; now it warns ONCE per name so a typo or a missing asset shows
-- up in the console instead of as a quiet cue.
local sfxWarned = {}
local function sfx(name)
	if not uiSettings.UiSound then return end
	local root = SoundService:FindFirstChild("KenopsiaAudio")
	local folder = root and root:FindFirstChild("SFX")
	if not folder then return end
	local s
	local poolName = K.SFX_POOLS[name]
	local pool = poolName and folder:FindFirstChild(poolName)
	if pool then
		local variants = pool:GetChildren()
		if #variants > 0 then s = variants[math.random(#variants)] end
	end
	s = s or folder:FindFirstChild(name)
	if s and s.SoundId ~= "" then
		-- P2.2: every UI cue rides the KenopsiaUI SoundGroup (built by UiFx at
		-- boot; looked up here so the order the two scripts start in is moot).
		if s.SoundGroup == nil then s.SoundGroup = SoundService:FindFirstChild("KenopsiaUI") end
		SoundService:PlayLocalSound(s)
	elseif not sfxWarned[name] then
		sfxWarned[name] = true
		warn((s and "[sfx] empty SoundId: " or "[sfx] unknown name: ") .. tostring(name))
	end
end

local lobbyMusicOn = false
local function setLobbyMusic(on)
	lobbyMusicOn = on
	local root = SoundService:FindFirstChild("KenopsiaAudio")
	local loop = root and root:FindFirstChild("Music")
	loop = loop and loop:FindFirstChild("Loop")
	if not loop then return end
	if on and uiSettings.Music then
		if not loop.IsPlaying then loop:Play() end
	else
		loop:Stop()
	end
end

-- Per-trial presentation is stamped on the local Player so concurrent rooms
-- can run different trials without clobbering one global music/light state.
local function updateTrialMusic()
	local root = SoundService:FindFirstChild("KenopsiaAudio")
	local trialsF = root and root:FindFirstChild("Music")
	trialsF = trialsF and trialsF:FindFirstChild("Trials")
	if not trialsF then return end
	local active = player:GetAttribute("KenopsiaActiveTrial") or ""
	for _, s in ipairs(trialsF:GetChildren()) do
		if s:IsA("Sound") then
			if s.Name == active and uiSettings.Music then
				if not s.IsPlaying then s:Play() end
			else
				s:Stop()
			end
		end
	end
	if active ~= "" then
		setLobbyMusic(false)
	elseif not lobbyMusicOn then
		setLobbyMusic(true)
	end
end
player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(updateTrialMusic)
task.defer(updateTrialMusic)

-- DEAD-ZONE-LICHT (Lighting + lamp raster) moved to SimulationGrade.client.luau
-- on 22.08.2026 (P3.1): every trial's look, snapshot and restore, lives there.

local controlsModule
task.spawn(function()
	pcall(function()
		local ps = player:WaitForChild("PlayerScripts", 10)
		local pm = ps and ps:WaitForChild("PlayerModule", 10)
		if pm then controlsModule = require(pm):GetControls() end
	end)
end)

local function bindForwardOnly()
	RunService:BindToRenderStep(K.FORWARD_BIND, Enum.RenderPriority.Input.Value + 1, function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or not controlsModule then return end
		local mv = controlsModule:GetMoveVector()
		-- forward and strafes only; backward input is discarded
		hum:Move(Vector3.new(mv.X, 0, math.min(mv.Z, 0)), true)
	end)
end
local function unbindForwardOnly()
	pcall(function()
		RunService:UnbindFromRenderStep(K.FORWARD_BIND)
	end)
end

local function hideAll()
	selection.Visible = false
	info.Visible = false
	statusScreen.Visible = false
	roundCard.Visible = false
	briefing.Visible = false
	scoreScreen.Visible = false
	announceScreen.Visible = false
	-- P2.2: every screen swap starts here, and the swap itself stays a hard
	-- cut. UiFx watches this counter and re-paints whatever is on screen next
	-- through the Bayer dither steps (Feel.Dither) on the overlay layer.
	machine:SetAttribute("DitherSeq", (machine:GetAttribute("DitherSeq") or 0) + 1)
end

-- P1.5 TYPEWRITER: time-based MaxVisibleGraphemes. The whole text is set once
-- and the label reveals floor(elapsed * cps) graphemes per frame, so a line is
-- the same length at the same instant at 30 and 60 fps (the old string.sub +
-- task.wait(1/cps) loop drifted by one frame per character). utf8.len counts
-- graphemes for the cap (nil on malformed UTF-8 -> byte length). Blocking,
-- like before: callers sequence lines with it. `token` keeps the cancel
-- semantics (a newer screen bumps `session`, the older typewriter stops).
-- Scoped in a do-block so the blip helper is not another top-level local.
local typewrite
do
	local function blip()
		if not uiSettings.UiSound then return end
		local root = SoundService:FindFirstChild("KenopsiaAudio")
		local folder = root and root:FindFirstChild("SFX")
		local src = folder and folder:FindFirstChild(Feel.Typewriter.BlipSfx)
		if not src or src.SoundId == "" then return end
		local s = src:Clone()
		s.PlaybackSpeed = Feel.blipSpeed(math.random())
		s.SoundGroup = SoundService:FindFirstChild("KenopsiaUI")
		s.Parent = SoundService
		s.Ended:Once(function() s:Destroy() end)
		s:Play()
	end
	typewrite = function(label, text, cps, token)
		local total = utf8.len(text) or #text
		label.MaxVisibleGraphemes = 0
		label.Text = text
		label.Visible = true
		local t0 = os.clock()
		local shown = 0
		local nextBlip = Feel.Typewriter.BlipEvery
		while shown < total do
			RunService.RenderStepped:Wait()
			if session ~= token then return end
			local n = Feel.visibleAt(os.clock() - t0, cps, total)
			if n ~= shown then
				shown = n
				label.MaxVisibleGraphemes = n
				if n >= nextBlip then
					nextBlip = n + Feel.Typewriter.BlipEvery
					blip()
				end
			end
		end
		label.MaxVisibleGraphemes = -1
	end
end

-- MOVEMENT: frozen everywhere except as a runner in a live round ------------

local moveState = "frozen"
local function applyMovement()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if moveState == "runner" then
		-- Dead Zone (Move-Set "scan"): NUR Gehen - der Compactor ist knapp langsamer.
		-- Ueberall sonst wird sofort gerannt (kein Anlauf mehr).
		local moves = char:GetAttribute("XBotMoves") or ""
		hum.WalkSpeed = string.find(moves, "scan") and 7 or 14
	elseif moveState == "trial" then
		-- MP-05: a TrialClients module set this through kit.movement.set.
		hum.WalkSpeed = trialWalkSpeed
	else
		hum.WalkSpeed = 0
	end
	-- no jumping anywhere in this game
	hum.UseJumpPower = true
	hum.JumpPower = 0
end
player.CharacterAdded:Connect(function()
	task.wait(0.3)
	applyMovement()
end)
task.defer(applyMovement)

-- CAMERAS -------------------------------------------------------------------

local camera = workspace.CurrentCamera
local runnerCam = false
local runnerCamDir = 1 -- +1: Bahn laeuft Richtung +Z (Bird Hunting), -1: Richtung -Z (Dead Zone)
local runnerCamStyle = "chase" -- "top" = fast 2D-Draufsicht (Dead Zone)
local smoothCamPos = nil
local spectateCF = nil
-- Who a finished player is watching. The SERVER decides who is watchable and
-- sends the list; the client only picks one from it, because from here a
-- living runner and someone standing at spawn look identical.
local spectateWatch = nil   -- array of userIds, or nil for the fixed camera
local spectateIndex = 1
local spectateEye = nil

-- Returns the root of the currently watched player, skipping anyone who has
-- left or has not respawned yet. The list is never mutated -- it belongs to
-- the server, and a player who is briefly characterless must not be dropped
-- from it permanently.
local function spectateRoot()
	if not spectateWatch or #spectateWatch == 0 then return nil end
	for offset = 0, #spectateWatch - 1 do
		local idx = ((spectateIndex - 1 + offset) % #spectateWatch) + 1
		local target = Players:GetPlayerByUserId(spectateWatch[idx])
		local char = target and target.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		-- Ignore anyone who has left the arena. spectateCF is the arena's own
		-- vantage point, so a target hundreds of studs from it is not in the
		-- round any more -- typically already teleported out during teardown.
		-- Following them there is how the baseplate ends up on screen.
		if root and spectateCF
			and (root.Position - spectateCF.Position).Magnitude > 600 then
			root = nil
		end
		if root then
			spectateIndex = idx
			return root
		end
	end
	return nil
end

local function restoreCamera()
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
end

-- P1.3 podium / P1.7 audience camera (23.08.2026): the Machine's own fixed
-- camera. Set from the `podium` and `audiencecam` packets, released by their
-- clears. It is written in the RenderStepped writer below like every other
-- camera here (a BindToRenderStep binding can never override that writer -
-- docs/QA/2026-08-22-p3-simulation-grade.md), and it outranks the trial cams:
-- when the Machine shows the podium nothing else may own the view.
local machineCam = nil        -- CFrame, or nil
local machineCamKind = nil    -- "podium" | "audiencecam"
-- Resolved on first use, never awaited at boot: a place without the module
-- pushed yet boots exactly as before and only these two kinds go dark.
local MachineCamRules = nil
local function machineCamRules()
	if MachineCamRules == nil then
		local rules = ReplicatedStorage:FindFirstChild("Kenopsia")
		rules = rules and rules:FindFirstChild("Shared")
		rules = rules and rules:FindFirstChild("Rules")
		local m = rules and rules:FindFirstChild("MachineCam")
		MachineCamRules = m and require(m) or false
		if not MachineCamRules then warn("[Kenopsia] Shared.Rules.MachineCam missing - podium/audience camera off") end
	end
	return MachineCamRules or nil
end
-- The bench card (Status screen) stays up while the audience camera runs, so
-- its opaque ground is thinned to let the arena through and put back after.
local statusGroundDefault = nil
local function setMachineCam(kind, p)
	local rules = machineCamRules()
	local pos, look = nil, nil
	if rules then pos, look = rules.read(p) end
	if pos and look then
		machineCam = CFrame.lookAt(Vector3.new(pos[1], pos[2], pos[3]), Vector3.new(look[1], look[2], look[3]))
		machineCamKind = kind
		if kind == "audiencecam" then
			if statusGroundDefault == nil then statusGroundDefault = statusScreen.BackgroundTransparency end
			statusScreen.BackgroundTransparency = 0.55
		end
		return true
	end
	-- A clear for the kind we hold (a stale clear for another kind is ignored).
	if machineCamKind == kind then
		machineCam = nil
		machineCamKind = nil
		restoreCamera()
	end
	if kind == "audiencecam" and statusGroundDefault ~= nil then
		statusScreen.BackgroundTransparency = statusGroundDefault
	end
	return false
end

-- P3.1: SimulationGrade publishes the PS1 position step (steps per stud, 0 =
-- off) as KenopsiaCamQuant. RenderStepped runs AFTER every BindToRenderStep
-- priority, so the grade's own binding cannot reach a camera this writer sets;
-- the snap has to happen here, after the branches. Position only, never rotation.
local camQuant = tonumber(player:GetAttribute("KenopsiaCamQuant")) or 0
player:GetAttributeChangedSignal("KenopsiaCamQuant"):Connect(function()
	camQuant = tonumber(player:GetAttribute("KenopsiaCamQuant")) or 0
end)

RunService.RenderStepped:Connect(function(dt)
	if machineCam then
		-- P1.3/P1.7: the Machine's fixed camera (podium, bench audience view).
		-- First, because it exists only while no trial may own the view.
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = machineCam
	elseif spectateCF then
		camera.CameraType = Enum.CameraType.Scriptable
		-- Follow whoever is still running. spectateCF is the fallback for the
		-- moment nobody is watchable -- last runner down, or everyone mid
		-- respawn -- so the camera never freezes on a dead body.
		local root = spectateRoot()
		if root then
			local eye = root.Position + Vector3.new(0, 16, -16)
			spectateEye = spectateEye and spectateEye:Lerp(eye, math.min(dt * 4, 1)) or eye
			camera.CFrame = CFrame.lookAt(spectateEye, root.Position)
		else
			camera.CFrame = spectateCF
		end
	elseif trialCam then
		-- MP-05: kit.camera.* modes. Spectate (above) wins over the trial cam,
		-- so the death cam keeps working for new trials; the runner cam
		-- below is never set by them.
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = TrialClientKit.computeCamera(trialCam, player.Character, camera, dt)
	elseif runnerCam then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			camera.CameraType = Enum.CameraType.Scriptable
			if runnerCamStyle == "top" then
				-- 23.08.2026 (user call): closer and leaning back -- 16 up, 14 behind,
				-- looking 45 degrees down at a point two studs ahead of the runner.
				local eye = root.Position + Vector3.new(0, 16, -14 * runnerCamDir)
				smoothCamPos = smoothCamPos and smoothCamPos:Lerp(eye, math.min(dt * 6, 1)) or eye
				camera.CFrame = CFrame.lookAt(smoothCamPos, smoothCamPos + Vector3.new(0, -16, 16 * runnerCamDir))
			else
				camera.CFrame = CFrame.lookAt(
					root.Position + Vector3.new(0, 20, -17 * runnerCamDir),
					root.Position + Vector3.new(0, 3, 30 * runnerCamDir))
			end
			-- Shiftlock only: der Charakter blickt immer in Bahnrichtung. perf
			-- (22.08.2026): the yaw is rewritten only when physics actually turned
			-- the root, and AutoRotate only when it came back on -- no property
			-- write per frame in the steady state.
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.AutoRotate then hum.AutoRotate = false end
			local look = root.CFrame.LookVector
			local wantZ = runnerCamDir == 1 and 1 or -1
			if math.abs(look.Z - wantZ) > 0.02 or math.abs(look.X) > 0.02 then
				root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, runnerCamDir == 1 and math.pi or 0, 0)
			end
		end
	end
	if camQuant > 0 and camera.CameraType == Enum.CameraType.Scriptable then
		local cf = camera.CFrame
		local pos = cf.Position
		local q = Vector3.new(
			math.floor(pos.X * camQuant + 0.5) / camQuant,
			math.floor(pos.Y * camQuant + 0.5) / camQuant,
			math.floor(pos.Z * camQuant + 0.5) / camQuant)
		if q ~= pos then camera.CFrame = cf.Rotation + q end
	end
end)

-- SNIPER INPUT --------------------------------------------------------------

local sniperActive = false
local sniperCanAim = false
local sniperCanFire = false
local scoped = false
local viewmodel = nil
local vmParts = {}
local boltParts = {}
local boltCycleStart = nil
local vmAlign = CFrame.identity
local sniperBase = nil
local sniperYaw, sniperPitch, recoil = 0, 0, 0
-- Unscoped view is natural FOV; the two scope levels are x2 and x4.
local zoomIdx = 1

-- Roblox recreates CurrentCamera after death/respawn; never trust the old one
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCam = workspace.CurrentCamera
	if newCam then
		camera = newCam
		if viewmodel then viewmodel.Parent = camera end
	end
end)

-- THE CROSSHAIR MUST SIT WHERE THE BULLET GOES, and the bullet goes along
-- `camera.CFrame.LookVector` (see the SniperAim fire below) -- dead centre of
-- the viewport. An authored scale position cannot promise that: it is measured
-- in the ScreenGui's own space, which is displaced by the GUI inset and
-- DeviceSafeInsets, and then shrunk again by MachineLayout's UIScale. Measured
-- on a 932x576 viewport the authored {0.524, 0.498} landed 22 px right and
-- 59 px ABOVE the aim point -- the player was aiming by a crosshair that lied.
--
-- So do not compute where it should go; measure where it IS and cancel the
-- error. AbsolutePosition already carries every inset and scale in the chain,
-- so one corrective offset lands it exactly, whatever the platform did.
local function alignHipCross()
	if not hipCross.Visible then return end
	local centre = hipCross.AbsolutePosition + hipCross.AbsoluteSize / 2
	local target = camera.ViewportSize / 2
	local dx, dy = target.X - centre.X, target.Y - centre.Y
	-- Sub-pixel residue is not worth a property write every frame.
	if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end
	hipCross.Position = hipCross.Position + UDim2.fromOffset(dx, dy)
end

-- Checked every frame rather than wired to one event: a resize, a platform
-- change (MachineLayout re-applies its UIScale asynchronously) and a fresh
-- camera after respawn all move the target, and the function above costs two
-- vector reads and returns immediately while the crosshair is hidden or already
-- within half a pixel.
RunService.RenderStepped:Connect(alignHipCross)

local function applyScope()
	local targetFov = scoped and K.ZOOMS[zoomIdx].fov or (sniperActive and K.SNIPER_BASE_FOV or 70)
	TweenService:Create(camera, TweenInfo.new(Feel.Scope.ZoomSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = targetFov }):Play()
	scopeGui.Visible = scoped
	local zl = scopeGui:FindFirstChild("ZoomLabel")
	if zl then zl.Text = K.ZOOMS[zoomIdx].label end
	local zb = touchControls:FindFirstChild("Btn_ZOOM")
	if zb then
		zb.Visible = scoped
		zb.Text = K.ZOOMS[zoomIdx].label
	end
	hipCross.Visible = sniperActive and not scoped
	alignHipCross()
	scopeLook.Visible = sniperActive and scoped
	for part, tr in vmParts do
		part.Transparency = scoped and 1 or tr
	end
end

local function destroyViewmodel()
	if viewmodel then viewmodel:Destroy() end
	viewmodel = nil
	vmParts = {}
	boltParts = {}
	boltCycleStart = nil
end

local function buildViewmodel()
	destroyViewmodel()
	-- custom procedural rifle, authored along -Z with the pivot at the grip
	local src = ReplicatedStorage:FindFirstChild("KenopsiaAssets")
	src = src and src:FindFirstChild("SniperRifle")
	if not src then return end
	local vm = src:Clone()
	vm.Name = "SniperViewmodel"
	for _, d in vm:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			vmParts[d] = d.Transparency
		end
	end
	local lampHost = vm:FindFirstChild("Receiver") or vm:FindFirstChildWhichIsA("BasePart", true)
	if lampHost then
		local lamp = Instance.new("PointLight")
		lamp.Brightness = 0.85
		lamp.Range = 9
		lamp.Color = Color3.fromRGB(220, 225, 235)
		lamp.Shadows = false
		lamp.Parent = lampHost
	end
	pcall(function() vm:ScaleTo(0.62) end)
	vmAlign = CFrame.identity
	local pivot = vm:GetPivot()
	for _, name in { "BoltKnob", "BoltStub" } do
		local part = vm:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			boltParts[part] = pivot:ToObjectSpace(part.CFrame)
		end
	end
	vm.Parent = workspace
	viewmodel = vm
end

local function muzzleFlash(atCF)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 214, 120)
	p.Size = Vector3.new(0.55, 0.55, 1.1)
	p.CFrame = atCF
	p.Parent = workspace
	task.delay(0.06, function() p:Destroy() end)
end

local function setOwnBodyHidden(hidden)
	local char = player.Character
	if not char then return end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function setSniperRig(on)
	-- Roles arrive before the setup card/countdown. Local weapon input only
	-- becomes live on the server's GO event.
	sniperCanAim = false
	sniperCanFire = false
	if on then
		buildViewmodel()
		setOwnBodyHidden(true)
		-- clamped turret view: fixed at the post, facing down the lane;
		-- retry briefly in case the arena has not replicated yet
		sniperBase = nil
		task.spawn(function()
			for _ = 1, 30 do
				if not sniperActive then return end
				local arena = workspace:FindFirstChild("Bird Hunting")
				local post = arena and arena:FindFirstChild("SniperPost")
				local start = arena and arena:FindFirstChild("Start")
				if post and start then
					sniperBase = CFrame.lookAt(post.Position, Vector3.new(start.Position.X, start.Position.Y + 4, start.Position.Z))
					if not viewmodel then buildViewmodel() end
					return
				end
				task.wait(0.2)
			end
		end)
		sniperYaw, sniperPitch, recoil = 0, 0, 0
		zoomIdx = 1
		touchControls.Btn_FIRE.Visible = true
		touchControls.Btn_SCOPE.Visible = true
		local pb = touchControls:FindFirstChild("Btn_PUNCH")
		local cb = touchControls:FindFirstChild("Btn_CROUCH")
		if pb then pb.Visible = false end
		if cb then cb.Visible = false end
		touchControls.Visible = touchAllowed()
	else
		setOwnBodyHidden(false)
		destroyViewmodel()
		sniperBase = nil
		touchControls.Visible = false
		pcall(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseDeltaSensitivity = 1
		end)
	end
	scoped = false
	applyScope()
end

local lastFireAt = -10
local function fireShot()
	if not sniperActive or not sniperCanFire or not SniperFire then return end
	if os.clock() - lastFireAt < K.FIRE_COOLDOWN then return end
	lastFireAt = os.clock()
	SniperFire:FireServer()
	if scoped then
		scoped = false
		applyScope()
	end
	boltCycleStart = os.clock()
	recoil = 1
	if viewmodel then
		local mz = viewmodel:FindFirstChild("Muzzle")
		if mz then
			muzzleFlash(CFrame.new(mz.Position) * (camera.CFrame - camera.CFrame.Position) * CFrame.new(0, 0, -0.35))
		else
			muzzleFlash(viewmodel:GetPivot() * CFrame.new(0, 0, -3.2))
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not sniperActive or not sniperCanFire then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		fireShot()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		scoped = not scoped
		applyScope()
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		-- gamepad: right trigger fires
		fireShot()
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		-- gamepad: left trigger toggles the scope
		scoped = not scoped
		applyScope()
	elseif input.KeyCode == Enum.KeyCode.ButtonY and scoped then
		-- gamepad: Y cycles zoom while scoped
		zoomIdx = zoomIdx % #K.ZOOMS + 1
		applyScope()
	end
end)

-- touch: drag anywhere to aim; on-screen buttons fire, scope and zoom
local touchAim = Vector2.zero
UserInputService.TouchMoved:Connect(function(input, gameProcessed)
	if gameProcessed or not sniperActive then return end
	touchAim += Vector2.new(input.Delta.X, input.Delta.Y)
end)

-- gamepad: right stick deflection aims at a steady angular rate
local gamepadAim = Vector2.zero
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		local v = Vector2.new(input.Position.X, input.Position.Y)
		gamepadAim = v.Magnitude > 0.15 and v or Vector2.zero
	end
end)
touchControls.Btn_FIRE.Activated:Connect(fireShot)
touchControls.Btn_SCOPE.Activated:Connect(function()
	if not sniperActive or not sniperCanFire then return end
	scoped = not scoped
	applyScope()
end)
touchControls.Btn_ZOOM.Activated:Connect(function()
	if not sniperActive or not sniperCanFire or not scoped then return end
	zoomIdx = zoomIdx % #K.ZOOMS + 1
	applyScope()
end)

-- runner touch buttons: punch, and crouch as a toggle (holding a button while
-- steering the thumbstick is not workable on touch)
local crouchToggled = false
local function setCrouchTouch(on)
	crouchToggled = on
	if XBotCrouch then XBotCrouch:FireServer(on) end
	local b = touchControls:FindFirstChild("Btn_CROUCH")
	if b then
		b.BackgroundColor3 = on and Color3.fromRGB(32, 78, 52) or Color3.fromRGB(10, 14, 12)
		b.TextColor3 = on and PHOSPHOR or IDLE
	end
end
-- sneaking is a per-trial move; the button only shows where it works
local runnerTouchOn = false
local function charSneakAllowed()
	local char = player.Character
	return char ~= nil and string.find(char:GetAttribute("XBotMoves") or "", "sneak", 1, true) ~= nil
end
local function charPushAllowed()
	local char = player.Character
	return char ~= nil and string.find(char:GetAttribute("XBotMoves") or "", "push", 1, true) ~= nil
end
local function refreshCrouchBtn()
	local cr = touchControls:FindFirstChild("Btn_CROUCH")
	if cr then cr.Visible = runnerTouchOn and charSneakAllowed() end
	local punch = touchControls:FindFirstChild("Btn_PUNCH")
	if punch then punch.Visible = runnerTouchOn and charPushAllowed() end
end
local function watchMoves(char)
	char:GetAttributeChangedSignal("XBotMoves"):Connect(function()
		refreshCrouchBtn()
		applyMovement()
	end)
end
player.CharacterAdded:Connect(watchMoves)
if player.Character then watchMoves(player.Character) end

local function setRunnerTouch(on)
	runnerTouchOn = on
	local punch = touchControls:FindFirstChild("Btn_PUNCH")
	if punch then punch.Visible = on and charPushAllowed() end
	refreshCrouchBtn()
	local sb = touchControls:FindFirstChild("Btn_SCAN")
	if sb then
		local char = player.Character
		sb.Visible = on and char ~= nil and string.find(char:GetAttribute("XBotMoves") or "", "scan") ~= nil
	end
	if on then
		touchControls.Btn_FIRE.Visible = false
		touchControls.Btn_SCOPE.Visible = false
		touchControls.Btn_ZOOM.Visible = false
		touchControls.Visible = touchAllowed()
	elseif not sniperActive then
		touchControls.Visible = false
	end
	if not on and crouchToggled then setCrouchTouch(false) end
end
touchControls.Btn_PUNCH.Activated:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if XBotPush and char and char:GetAttribute("XBotRig") and hum and hum.WalkSpeed > 0 and charPushAllowed() then
		XBotPush:FireServer()
	end
end)
local function toggleCrouch()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and hum) then return end
	if not crouchToggled and not charSneakAllowed() then return end
	if not crouchToggled and hum.WalkSpeed <= 0 then return end
	setCrouchTouch(not crouchToggled)
end
touchControls.Btn_CROUCH.Activated:Connect(toggleCrouch)
-- P3.3: the same toggle on keyboard (C / Left Ctrl) and gamepad (B); the server
-- gates it on the trial's sneak permission, the rig plays the Crouch clip.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.ButtonB then
		toggleCrouch()
	end
end)

-- FELDSCANNER (Dead Zone): hold to emit repeating sonar pulses.
local TrialInput = remotes:WaitForChild("TrialInput", 20)
local pulseReadyAt = 0

local function charScanAllowed()
	local char = player.Character
	return char ~= nil and string.find(char:GetAttribute("XBotMoves") or "", "scan") ~= nil
end

local function spawnWave(root)
	local tpl = ReplicatedStorage:FindFirstChild("KenopsiaAssets")
	tpl = tpl and tpl:FindFirstChild("MF_SonarRing")
	if not tpl then return end
	local ring = tpl:Clone()
	ring:PivotTo(CFrame.new(root.Position.X, root.Position.Y - 2.4, root.Position.Z))
	ring.Parent = workspace
	task.spawn(function()
		-- Welle deckt jetzt den 8-Studs-Scanradius ab
		for i = 1, 14 do
			ring:ScaleTo(0.5 + i * 0.6)
			for _, seg in ipairs(ring:GetChildren()) do
				if seg:IsA("BasePart") and seg.Name ~= "Center" and seg.Name ~= "PivotRoot" then
					seg.Transparency = 0.25 + (i / 14) * 0.75
				end
			end
			task.wait(0.045)
		end
		ring:Destroy()
	end)
end

local function firePulse()
	if not charScanAllowed() then return end
	local now = os.clock()
	if now < pulseReadyAt then return end
	pulseReadyAt = now + 0.9
	if TrialInput then
		-- C1.a: echo this round's token. Without it the server rejects the pulse.
		TrialInput:FireServer({
			trialId = "minefield",
			action = "pulse",
			roundToken = trialRoundToken,
		})
	end
	sfx("Click")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then spawnWave(root) end
	local sb = touchControls:FindFirstChild("Btn_SCAN")
	if sb then
		sb.BackgroundColor3 = Color3.fromRGB(64, 28, 24)
		sb.TextColor3 = Color3.fromRGB(255, 120, 100)
		task.delay(0.25, function()
			sb.BackgroundColor3 = Color3.fromRGB(10, 14, 12)
			sb.TextColor3 = IDLE
		end)
	end
end

local scanHeld = false
local scanHoldGeneration = 0

local function setScanHeld(on)
	on = on == true
	if on and not charScanAllowed() then return end
	if scanHeld == on then return end
	scanHeld = on
	scanHoldGeneration += 1
	local generation = scanHoldGeneration
	if not on then return end

	task.spawn(function()
		while scanHeld and generation == scanHoldGeneration and charScanAllowed() do
			firePulse()
			task.wait(0.9)
		end
	end)
end

local function refreshScannerHud()
	if not charScanAllowed() then setScanHeld(false) end
end
player.CharacterAdded:Connect(function(char)
	char:GetAttributeChangedSignal("XBotMoves"):Connect(refreshScannerHud)
	task.defer(refreshScannerHud)
end)
if player.Character then
	player.Character:GetAttributeChangedSignal("XBotMoves"):Connect(refreshScannerHud)
	refreshScannerHud()
end

-- aufgedeckte Minen: rote Bodenmarken mit kurzer Lebensdauer
local revealMarks = {}
-- POOLED. Every sonar pulse used to Instance.new a Part per revealed mine and
-- Destroy it a moment later; a held scan over a dense field churns dozens of
-- instances a second for marks that all look identical. They are recycled
-- instead, so a round allocates roughly as many parts as the widest single
-- reveal and none after that.
local markPool = {}
-- Plan: markers clear within a second. Was 1.6, which left the field readable
-- long after the pulse that lit it and made a single scan worth more than the
-- risk of standing still to cast it.
-- Bounded so a pathological round cannot turn the pool into a leak. Past this
-- the surplus is destroyed rather than kept.

local function acquireMark()
	local mark = table.remove(markPool)
	if mark then return mark end
	mark = Instance.new("Part")
	mark.Shape = Enum.PartType.Cylinder
	mark.Size = Vector3.new(0.12, 2.56, 2.56) -- 23.08.2026: x1.6, the marks read too small from the 45-degree cam
	mark.Material = Enum.Material.Neon
	mark.Color = Color3.fromRGB(255, 60, 50)
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	return mark
end

local function releaseMark(mark)
	mark.Parent = nil
	if #markPool < K.MARK_POOL_MAX then
		table.insert(markPool, mark)
	else
		mark:Destroy()
	end
end
local function showMines(list)
	for _, e in list do
		local key = math.floor(e[1]) .. ":" .. math.floor(e[3])
		local mark = revealMarks[key]
		if not mark then
			mark = acquireMark()
			-- Set on every acquire, not only on creation: a recycled part
			-- arrives wherever it was last used.
			mark.CFrame = CFrame.new(e[1], e[2] + 0.12, e[3]) * CFrame.Angles(0, 0, math.rad(90))
			mark.Parent = workspace
			revealMarks[key] = mark
		end
		mark.Transparency = e[4] and 0.1 or 0.55
		mark:SetAttribute("DieAt", os.clock() + K.MARK_LIFETIME)
	end
end
task.spawn(function()
	while true do
		task.wait(0.4)
		for key, mark in pairs(revealMarks) do
			if (mark:GetAttribute("DieAt") or 0) < os.clock() then
				revealMarks[key] = nil
				releaseMark(mark)
			end
		end
	end
end)

-- Hold F (PC), Y (gamepad), or the touch button for repeating sonar.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F then
		setScanHeld(true)
	elseif input.KeyCode == Enum.KeyCode.ButtonY and not sniperActive then
		setScanHeld(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonY then
		setScanHeld(false)
	end
end)
local scanBtn = touchControls:FindFirstChild("Btn_SCAN")
if scanBtn then
	scanBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setScanHeld(true)
		end
	end)
	scanBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setScanHeld(false)
		end
	end)
end

-- CANTEEN PROTOCOL: the eating readout and its input.
--
-- The plate, the peas, the fork and the descending Observer are REAL PARTS,
-- built and driven by the server (Services/CanteenProps). This HUD is a second,
-- deliberately redundant readout -- not the only one. The props can be hidden
-- by a camera angle or another player, and the watching phase has to be
-- readable WITHOUT looking away from your own plate, which is what the screen
-- edge is for.
--
-- Nothing here decides anything. Every number arrives from the server, and the
-- server alone rules on whether a swallow was seen. A client that lies about
-- the phase changes only what its own player sees.
local canteenActive = false
local canteenHud = nil
local cpPlateReadyAt = 0
local cpMouthReadyAt = 0

-- Matched to the server MIN_PLATE_INTERVAL / MIN_MOUTH_INTERVAL. These exist to
-- stop the client spamming a remote it already knows will be refused; they are
-- NOT the rule. The server re-checks both on its own clock, so editing these
-- numbers locally buys nothing.


local function charEatAllowed()
	local char = player.Character
	return char ~= nil and string.find(char:GetAttribute("XBotMoves") or "", "eat") ~= nil
end

local function buildCanteenHud()
	if canteenHud then return canteenHud end

	local f = Instance.new("Frame")
	f.Name = "CanteenHud"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 1, 0)
	f.Visible = false
	-- 66, with HipCross -- NOT a low number. KenopsiaMachine uses
	-- ZIndexBehavior.Sibling, so only the top-level container's ZIndex decides
	-- what draws over what, and Scope.Mask sits at 65 painting opaque letterbox
	-- bars over the left, right and bottom of the screen. At the ZIndex 6 this
	-- started with, the edge glow -- which lives at the very screen edge, under
	-- those bars -- was invisible. The warning the whole minigame is played on
	-- would never have been seen.
	f.ZIndex = 66

	-- Peripheral warning. A screen-edge glow is readable without looking at it,
	-- which is the whole point: your eyes are on the plate, not on a label.
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.new(1, 0, 1, 0)
	edge.ZIndex = 6
	local glow = Instance.new("UIStroke")
	glow.Name = "Glow"
	glow.Thickness = 12
	glow.Color = K.CP_DANGER
	glow.Transparency = 1
	glow.Parent = edge
	edge.Parent = f

	local phase = Instance.new("TextLabel")
	phase.Name = "Phase"
	phase.AnchorPoint = Vector2.new(0.5, 0)
	phase.Position = UDim2.new(0.5, 0, 0, 24)
	phase.Size = UDim2.new(0, 460, 0, 34)
	phase.BackgroundTransparency = 1
	phase.Font = Enum.Font.Code
	phase.TextSize = 26
	phase.TextColor3 = K.CP_IDLE
	phase.Text = ""
	phase.ZIndex = 7
	phase.Parent = f

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -28)
	panel.Size = UDim2.new(0, 300, 0, 74)
	panel.BackgroundColor3 = Color3.fromRGB(9, 12, 10)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.ZIndex = 7
	panel.Parent = f

	local ration = Instance.new("TextLabel")
	ration.Name = "Ration"
	ration.Position = UDim2.new(0, 0, 0, 6)
	ration.Size = UDim2.new(1, 0, 0, 26)
	ration.BackgroundTransparency = 1
	ration.Font = Enum.Font.Code
	ration.TextSize = 20
	ration.TextColor3 = K.CP_IDLE
	ration.Text = "PLATE 20    EATEN 00/20" -- placeholder until the first cpstate; PEAS_TOTAL is 20 since 23.08.2026
	ration.ZIndex = 8
	ration.Parent = panel

	-- Fork capacity as pips: four of them, because the fork holds four. Reading
	-- a number means looking at it; reading four dots does not.
	local fork = Instance.new("Frame")
	fork.Name = "Fork"
	fork.AnchorPoint = Vector2.new(0.5, 0)
	fork.Position = UDim2.new(0.5, 0, 0, 38)
	fork.Size = UDim2.new(0, K.CP_FORK_CAPACITY * 30, 0, 24)
	fork.BackgroundTransparency = 1
	fork.ZIndex = 8
	fork.Parent = panel
	for i = 1, K.CP_FORK_CAPACITY do
		local pip = Instance.new("Frame")
		pip.Name = "Pip" .. i
		pip.AnchorPoint = Vector2.new(0.5, 0.5)
		pip.Position = UDim2.new(0, (i - 0.5) * 30, 0.5, 0)
		pip.Size = UDim2.new(0, 18, 0, 18)
		pip.BackgroundColor3 = K.CP_PIP_EMPTY
		pip.BorderSizePixel = 0
		pip.ZIndex = 8
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = pip
		pip.Parent = fork
	end

	f.Parent = machine
	canteenHud = f
	return f
end

local function cpSetState(peas, forkLoad, eaten, total)
	local hud = buildCanteenHud()
	hud.Panel.Ration.Text = string.format("PLATE %02d    EATEN %02d/%02d", peas, eaten, total)
	for i = 1, K.CP_FORK_CAPACITY do
		local pip = hud.Panel.Fork:FindFirstChild("Pip" .. i)
		if pip then
			pip.BackgroundColor3 = (i <= forkLoad) and K.CP_SAFE or K.CP_PIP_EMPTY
		end
	end
end

local function cpSetPhase(phaseName)
	local hud = buildCanteenHud()
	local label = hud.Phase
	local glow = hud.Edge.Glow
	if phaseName == "lowering" then
		label.Text = "OBSERVER DESCENDING"
		label.TextColor3 = K.CP_WARN
		glow.Color = K.CP_WARN
		TweenService:Create(glow, TweenInfo.new(Feel.panel(machine:GetAttribute("Platform"))), { Transparency = 0.45 }):Play()
	elseif phaseName == "watching" then
		label.Text = "OBSERVED - DO NOT SWALLOW"
		label.TextColor3 = K.CP_DANGER
		glow.Color = K.CP_DANGER
		-- Snappier than the wind-up on purpose: the warning may fade in slowly,
		-- the danger may not.
		TweenService:Create(glow, TweenInfo.new(Feel.Feedback.Jolt), { Transparency = 0 }):Play()
	else
		label.Text = ""
		TweenService:Create(glow, TweenInfo.new(Feel.panel(machine:GetAttribute("Platform"))), { Transparency = 1 }):Play()
	end
end

local function cpSend(action)
	if not canteenActive or not charEatAllowed() then return end
	if not TrialInput then return end
	local now = os.clock()
	if action == "plate" then
		if now < cpPlateReadyAt then return end
		cpPlateReadyAt = now + K.CP_PLATE_COOLDOWN
	else
		if now < cpMouthReadyAt then return end
		cpMouthReadyAt = now + K.CP_MOUTH_COOLDOWN
	end
	-- Echo this round token. Without it the server refuses the action, which is
	-- what stops a packet from an earlier round landing in a later one.
	TrialInput:FireServer({
		trialId = "canteen",
		action = action,
		roundToken = trialRoundToken,
	})
	sfx("Click")
end

-- Touch controls, built here rather than reusing TouchControls.Btn_EAT: that
-- button belonged to the deleted rhythm mechanic, and PLATE / MOUTH need two
-- targets side by side, big enough to hit under time pressure.
local function buildCanteenTouch()
	local existing = machine:FindFirstChild("CanteenTouch")
	if existing then return existing end

	local pad = Instance.new("Frame")
	pad.Name = "CanteenTouch"
	pad.BackgroundTransparency = 1
	pad.Size = UDim2.new(1, 0, 1, 0)
	pad.Visible = false
	-- 68, exactly matching TouchControls, which this replaces for this minigame.
	-- Every shipped touch button deliberately sits ON the letterbox bars -- that
	-- black margin is thumb space outside the play area. Sitting there only
	-- works above the mask at 65; below it the buttons are painted over and the
	-- player has no controls at all.
	pad.ZIndex = 68

	local function button(name, text, xScale, colour)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(xScale, 0, 1, -120)
		-- 110 px. The plan floor is 64, and these get pressed repeatedly
		-- against a countdown, so they are given room.
		b.Size = UDim2.new(0, 110, 0, 110)
		b.BackgroundColor3 = Color3.fromRGB(12, 16, 13)
		b.BackgroundTransparency = 0.2
		b.BorderSizePixel = 0
		b.Font = Enum.Font.Code
		b.TextSize = 18
		b.TextColor3 = colour
		b.Text = text
		b.ZIndex = 9
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 12)
		round.Parent = b
		b.Parent = pad
		return b
	end

	button("Btn_PLATE", "PLATE", 0.18, K.CP_IDLE).Activated:Connect(function()
		cpSend("plate")
	end)
	button("Btn_MOUTH", "MOUTH", 0.82, K.CP_SAFE).Activated:Connect(function()
		cpSend("mouth")
	end)

	pad.Parent = machine
	return pad
end

local function cpShowHud()
	canteenActive = true
	local hud = buildCanteenHud()
	hud.Visible = true
	local pad = buildCanteenTouch()
	pad.Visible = touchAllowed()
end

local function cpHideHud()
	canteenActive = false
	if canteenHud then
		canteenHud.Edge.Glow.Transparency = 1
		canteenHud.Phase.Text = ""
		canteenHud.Visible = false
	end
	local pad = machine:FindFirstChild("CanteenTouch")
	if pad then pad.Visible = false end
end

-- LMB / left trigger loads the fork; RMB / right trigger eats. The guard on
-- canteenActive is what keeps this from fighting the sniper handler above,
-- which claims the same two buttons behind its own sniperActive guard.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not canteenActive then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.ButtonL2 then
		cpSend("plate")
	elseif input.UserInputType == Enum.UserInputType.MouseButton2
		or input.KeyCode == Enum.KeyCode.ButtonR2 then
		cpSend("mouth")
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed or not sniperActive or not scoped then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local newIdx = math.clamp(zoomIdx + (input.Position.Z > 0 and 1 or -1), 1, #K.ZOOMS)
		if newIdx ~= zoomIdx then
			zoomIdx = newIdx
			applyScope()
		end
	end
end)

-- Sniper-Licht: Suchscheinwerfer an der Kamera + hellere Belichtung, damit
-- der Schuetze das Feld auch bei Dunkelheit lesen kann (nur client-seitig)
local Lighting = game:GetService("Lighting")
local sniperLamp = nil
local savedExposure = nil
local function setSniperLight(on)
	if on then
		if savedExposure == nil then
			savedExposure = Lighting.ExposureCompensation
			Lighting.ExposureCompensation = savedExposure + 0.75
		end
		if not sniperLamp then
			local p = Instance.new("Part")
			p.Name = "SniperLamp"
			p.Size = Vector3.new(0.2, 0.2, 0.2)
			p.Transparency = 1
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			local spot = Instance.new("SpotLight")
			spot.Name = "Beam"
			spot.Angle = 75
			spot.Range = 60
			spot.Brightness = 6
			spot.Color = Color3.fromRGB(255, 236, 200)
			spot.Face = Enum.NormalId.Front
			spot.Shadows = false
			spot.Parent = p
			p.Parent = camera
			sniperLamp = p
		end
	else
		if savedExposure ~= nil then
			Lighting.ExposureCompensation = savedExposure
			savedExposure = nil
		end
		if sniperLamp then
			sniperLamp:Destroy()
			sniperLamp = nil
		end
	end
end

local lastAim = 0
RunService.RenderStepped:Connect(function(dt)
	if not sniperActive then return end
	if hunterSetupActive then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		touchAim = Vector2.zero
		gamepadAim = Vector2.zero
		if sniperBase then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = sniperBase
			if sniperLamp then sniperLamp.CFrame = sniperBase end
			if viewmodel then
				viewmodel:PivotTo(sniperBase * CFrame.new(0.34, -0.42, -1.25) * CFrame.Angles(0, -0.05, 0) * vmAlign)
			end
		end
		return
	end
	if sniperBase then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		local delta = UserInputService:GetMouseDelta()
		local dx = delta.X + touchAim.X + gamepadAim.X * 460 * dt
		local dy = delta.Y + touchAim.Y - gamepadAim.Y * 460 * dt
		touchAim = Vector2.zero
		local sens = lookSensitivity * (camera.FieldOfView / 70)
		sniperYaw = math.clamp(sniperYaw - dx * sens, -0.7, 0.7)
		sniperPitch = math.clamp(sniperPitch - dy * sens, -0.6, 0.25)
		camera.CameraType = Enum.CameraType.Scriptable

		-- Keep the camera origin identical to the authoritative server ray.
		-- This also removes a descendant scan from every render frame.
		local aim = CFrame.new(sniperBase.Position)
			* (sniperBase - sniperBase.Position)
			* CFrame.Angles(0, sniperYaw, 0)
			* CFrame.Angles(sniperPitch - recoil * 0.05, 0, 0)
		if scoped then
			-- gentle breathing drift; keep it calm even at deep zoom
			local t = os.clock()
			local mag = 0.0004 * (70 / camera.FieldOfView)
			aim = aim * CFrame.Angles(math.sin(t * 0.5) * mag, math.sin(t * 0.4) * mag, 0)
		end
		camera.CFrame = aim
		if sniperLamp then sniperLamp.CFrame = camera.CFrame end

		-- shouldered rifle: rides the aim line, kicks on recoil, hidden in scope
		if viewmodel then
			if scoped then
				for part in vmParts do part.LocalTransparencyModifier = 1 end
			else
				for part in vmParts do part.LocalTransparencyModifier = 0 end
				viewmodel:PivotTo(camera.CFrame
					* CFrame.new(0.34, -0.42 + 0.05 * recoil, -1.25 + 0.28 * recoil)
					* CFrame.Angles(0.08 * recoil, -0.05, 0)
					* vmAlign)
				local boltAlpha = 0
				if boltCycleStart then
					local bt = (os.clock() - boltCycleStart) / K.FIRE_COOLDOWN
					if bt >= 1 then
						boltCycleStart = nil
					elseif bt > 0.12 and bt < 0.34 then
						boltAlpha = math.clamp((bt - 0.12) / 0.22, 0, 1)
					elseif bt <= 0.58 and bt >= 0.34 then
						boltAlpha = 1
					elseif bt > 0.58 then
						boltAlpha = 1 - math.clamp((bt - 0.58) / 0.24, 0, 1)
					end
				end
				local pivot = viewmodel:GetPivot()
				for part, base in boltParts do
					if part.Parent then
						part.CFrame = pivot * CFrame.new(0, 0, 0.42 * boltAlpha) * base
					end
				end
			end
		end
	end
	recoil = math.max(0, recoil - dt * 3)
	local now = os.clock()
	if sniperCanAim and SniperAim and now - lastAim > 0.05 then
		lastAim = now
		SniperAim:FireServer(camera.CFrame.LookVector)
	end
end)

-- READY PANEL ---------------------------------------------------------------

local function updateReadyVisual()
	-- C3: three states now - DIM while benched, AMBER when ready, PHOSPHOR when
	-- seated and not ready. DIM is the same inert colour vacant roster rows use.
	local colour = amSpectator and DIM or (myReady and AMBER or PHOSPHOR)
	local stroke = info.Btn_READY:FindFirstChildOfClass("UIStroke")
	info.Btn_READY.TextColor3 = colour
	if stroke then stroke.Color = colour end
	-- FindFirstChildOfClass is not recursive, so the stroke above never reaches
	-- Btn_READY.Inner.UIStroke; paint it too or the dimming reads wrong.
	local inner = info.Btn_READY:FindFirstChild("Inner")
	local innerStroke = inner and inner:FindFirstChildOfClass("UIStroke")
	if innerStroke then innerStroke.Color = colour end
	-- A benched player must not fire ReadyReq, and on console must not hold
	-- gamepad focus either: MachineLayout.focusScreen filters candidates on
	-- .Selectable, NOT .Active, so clearing Active alone would park console
	-- selection on a dead button and re-select it on every Info.Visible change.
	info.Btn_READY.Active = not amSpectator
	info.Btn_READY.Selectable = not amSpectator
	if amSpectator and GuiService.SelectedObject == info.Btn_READY then
		GuiService.SelectedObject = info:FindFirstChild("Btn_SETTINGS")
	end
	-- MachineLayout parents an A-button glyph named PadHint into this button on
	-- console; hide it while the button is dead so it stops advertising a prompt.
	local hint = info.Btn_READY:FindFirstChild("PadHint")
	if hint then
		hint.Visible = (not amSpectator) and machine:GetAttribute("Platform") == "Console"
	end
end

local function updateRoster(members)
	local roster = info:FindFirstChild("Roster")
	if not roster then return end
	-- rank seats by running session score, like the reference roster
	local ranked = {}
	for _, m in members do
		local plr = Players:GetPlayerByUserId(m.userId)
		table.insert(ranked, {
			displayName = m.displayName,
			ready = m.ready,
			userId = m.userId,
			score = (plr and plr:GetAttribute("KenopsiaSessionScore")) or 0,
		})
	end
	table.sort(ranked, function(a, b) return a.score > b.score end)
	for i = 1, 4 do
		local row = roster["Row" .. i]
		local m = ranked[i]
		row.Visible = i <= maxPlayers
		if m then
			row.NameLabel.Text = m.displayName or ""
			row.NameLabel.TextColor3 = IDLE
			row.ScoreLabel.Text = string.format("%04d", math.clamp(m.score, 0, 9999))
			row.ScoreLabel.TextColor3 = PHOSPHOR
			row.RankLabel.TextColor3 = PHOSPHOR
			row.Check.Fill.Visible = m.ready == true
			local cst = row.Check:FindFirstChildOfClass("UIStroke")
			if cst then cst.Color = PHOSPHOR end
		else
			row.NameLabel.Text = "vacant"
			row.NameLabel.TextColor3 = DIM
			row.ScoreLabel.Text = "----"
			row.ScoreLabel.TextColor3 = DIM
			row.RankLabel.TextColor3 = DIM
			row.Check.Fill.Visible = false
			local cst = row.Check:FindFirstChildOfClass("UIStroke")
			if cst then cst.Color = DIM end
		end
	end
end

info.Btn_READY.Activated:Connect(function()
	-- C3: guard BEFORE sfx, so a benched player gets no confirmation sound for
	-- a press that does nothing. The server's own rejection arrives on
	-- LobbyError, which IS connected now -- see the notice line at the end of
	-- this file.
	if amSpectator then return end
	sfx("Submit")
	ReadyReq:FireServer(not myReady)
end)


RoomState.OnClientEvent:Connect(function(p)
	if type(p) ~= "table" then return end
	maxPlayers = p.maxPlayers or 4
	-- C3: seat vs bench is decided from THIS payload only, never from stale
	-- state. p.spectators is an ARRAY OF USERIDS (RoomService.publicState builds
	-- it with table.insert over the spectator set), NOT a map - never index it
	-- by UserId.
	local inMembers = false
	for _, m in p.members or {} do
		if m.userId == player.UserId then
			inMembers = true
			myReady = m.ready == true
		end
	end
	local inSpectators = false
	for _, id in p.spectators or {} do
		if id == player.UserId then inSpectators = true end
	end
	if not inMembers then
		-- The old loop only wrote myReady from inside the members scan, so a
		-- benched player kept whatever value it held when last seated and the
		-- button could stay lit AMBER. A bench player holds no ready flag.
		myReady = false
	end
	amSpectator = inSpectators and not inMembers
	-- TopTicker is a TextLabel under Info that no script writes, so it can carry
	-- the notice with no contention. NextLabel cannot: showInfo() typewrites
	-- into it from a task.spawn and would overwrite this within ~1s.
	local ticker = info:FindFirstChild("TopTicker")
	if ticker then
		if tickerDefaultText == nil then tickerDefaultText = ticker.Text end
		ticker.Text = amSpectator and "SPECTATING // NEXT MATCH" or tickerDefaultText
	end
	updateRoster(p.members or {})
	updateReadyVisual()
end)

-- SELECTION: flicker roulette ----------------------------------------------

local function setTileLit(tile, lit)
	for _, d in tile:GetDescendants() do
		if d:IsA("Frame") and d.BackgroundTransparency < 1 then
			d.BackgroundColor3 = lit and PHOSPHOR or DIM
		elseif d:IsA("UIStroke") then
			d.Color = lit and PHOSPHOR or DIM
		end
	end
end

local function showSelection(p, token)
	hideAll()
	selection.Visible = true
	local pool = selection:FindFirstChild("IconPool")
	local tiles = {}
	for i = 1, 3 do
		local t = selection.Tiles["Tile" .. i]
		t.Visible = false
		t.Icon:ClearAllChildren()
		local src = pool and pool:FindFirstChild(p.icons and p.icons[i] or "Crosshair")
		if src then
			local ic = src:Clone()
			ic.Visible = true
			ic.Position = UDim2.fromScale(0.5, 0.5)
			ic.Parent = t.Icon
		end
		tiles[i] = t
	end
	selection.CrossH.Visible = false
	selection.CrossV.Visible = false
	selection.BootText.Visible = false

	task.spawn(function()
		local R = Feel.Roulette
		task.wait(R.Lead)
		for _, t in tiles do
			if session ~= token then return end
			t.Visible = true
			task.wait(R.TileGap)
		end
		task.wait(R.Pause)
		if session ~= token then return end

		-- symbols flicker, then the machine locks its choice. P1.5: on the
		-- flicker rule (Feel.Flicker: <= 3 changes/s, dim channel only) -- the
		-- icons stay put, the tile chrome steps between DIM and PHOSPHOR every
		-- Hold seconds instead of strobing visibility at 14 Hz.
		if uiSettings.ReduceFlicker then
			task.wait(R.ReducedChaos)
			if session ~= token then return end
		else
			local deadline = os.clock() + R.Chaos
			while os.clock() < deadline do
				if session ~= token then return end
				for i = 1, 3 do
					setTileLit(tiles[i], math.random() < 0.4)
				end
				task.wait(Feel.Flicker.Hold)
			end
		end
		for i = 1, 3 do
			tiles[i].Icon.Visible = true
			setTileLit(tiles[i], i == (p.chosen or 1))
		end

		-- lock-in blinks, each state held the flicker minimum
		local chosenTile = tiles[p.chosen or 1]
		for _ = 1, (uiSettings.ReduceFlicker and 1 or R.LockBlinks) do
			if session ~= token then return end
			setTileLit(chosenTile, false)
			task.wait(Feel.Flicker.Hold)
			setTileLit(chosenTile, true)
			task.wait(Feel.Flicker.Hold)
		end

		-- crosshair snaps straight to the mark. The tile centre is an ABSOLUTE
		-- screen point, but CrossH/CrossV live inside Selection, which
		-- MachineLayout scales (0.81 on desktop, less on phones): a raw absolute
		-- offset lands scale-times too high and too far left. Convert into the
		-- screen's own pixel space first. (P2.1, 22.08.2026)
		local center = chosenTile.AbsolutePosition + chosenTile.AbsoluteSize / 2
		local layoutScale = selection:FindFirstChild("KenopsiaScale")
		layoutScale = layoutScale and layoutScale.Scale or 1
		local localX = (center.X - selection.AbsolutePosition.X) / layoutScale
		local localY = (center.Y - selection.AbsolutePosition.Y) / layoutScale
		local crossH, crossV = selection.CrossH, selection.CrossV
		local hThick = crossH.AbsoluteSize.Y / layoutScale
		local vThick = crossV.AbsoluteSize.X / layoutScale
		crossH.Position = UDim2.new(0, 0, 0, -hThick)
		crossV.Position = UDim2.new(0, -vThick, 0, 0)
		crossH.Visible = true
		crossV.Visible = true
		TweenService:Create(crossH, TweenInfo.new(R.CrosshairSnap, Feel.easing(Feel.Easing.Snap, Feel.Easing.SnapDir)), {
			Position = UDim2.new(0, 0, 0, localY - hThick / 2),
		}):Play()
		TweenService:Create(crossV, TweenInfo.new(R.CrosshairSnap, Feel.easing(Feel.Easing.Snap, Feel.Easing.SnapDir)), {
			Position = UDim2.new(0, localX - vThick / 2, 0, 0),
		}):Play()
		task.wait(R.BootDelay)
		if session ~= token then return end
		selection.BootText.Position = UDim2.new(0, localX + 90, 0, localY)
		typewrite(selection.BootText, "Simulation bootst:", Feel.Typewriter.BodyCps, token)
	end)
end

local function showInfo(p, token)
	hideAll()
	info.Visible = true
	local holder = info.SelIcon.Holder
	for _, c in holder:GetChildren() do
		if not c:IsA("UIScale") then c:Destroy() end
	end
	local pool = selection:FindFirstChild("IconPool")
	local src = pool and pool:FindFirstChild(p.icon or "Crosshair")
	if src then
		local ic = src:Clone()
		ic.Visible = true
		ic.Position = UDim2.fromScale(0.5, 0.5)
		ic.Parent = holder
	end
	info.NextLabel.Text = "NEXT SIMULATION: "
	task.spawn(function()
		typewrite(info.NextLabel, "NEXT SIMULATION: " .. (p.name or "?"), Feel.Typewriter.BodyCps, token)
	end)
	updateReadyVisual()
end

-- STATUS / ROUND / SCORE ----------------------------------------------------

local function showStatus(p, token)
	hideAll()
	statusScreen.Visible = true
	for i = 1, 7 do
		local l = statusScreen:FindFirstChild("TypeLine" .. i)
		if l then
			l.Visible = false
			l.Text = ""
		end
	end
	task.spawn(function()
		for i, text in p.lines or {} do
			if session ~= token then return end
			local l = statusScreen:FindFirstChild("TypeLine" .. i)
			if l then typewrite(l, text, Feel.Typewriter.StatusCps, token) end
			task.wait(Feel.Typewriter.LineGap)
		end
	end)
end

local function showRound(p, token)
	hideAll()
	roundCard.Visible = true
	roundCard.Title.Text = ("Round %d/%d"):format(p.n or 1, p.total or 3)
	roundCard.Verbs.Text = ""
	task.spawn(function()
		typewrite(roundCard.Verbs, (p.verbs or "") .. "_", Feel.Typewriter.BodyCps, token)
	end)
end

local function rollDigit(cell, target, delay, token)
	task.spawn(function()
		task.wait(delay)
		local value = cell.Value
		-- P1.5: the odometer is stepped UI motion -- one digit per frame of the
		-- Feel.Step grid, not an ad-hoc ramp.
		local spins = 14 + delay * 10
		for _ = 1, spins do
			if session ~= token then return end
			value.Text = tostring(math.random(0, 9))
			task.wait(1 / Feel.Step.Fps)
		end
		if session ~= token then return end
		value.Text = target
		value.TextColor3 = PHOSPHOR
	end)
end

local function showScore(p, token)
	hideAll()
	scoreScreen.Visible = true
	-- P1.3 (22.08.2026): the final board is a VERDICT, not another number.
	local myVerdict = nil
	for _, e in p.board or {} do
		if e.userId == player.UserId then myVerdict = e.verdict end
	end
	local conclusion = scoreScreen:FindFirstChild("ConclusionLabel")
	local scoreName = scoreScreen:FindFirstChild("ScoreName")
	if p.final and myVerdict then
		if conclusion then conclusion.Text = "FINAL AUDIT CONCLUDED" end
		if scoreName then
			scoreName.Text = "SUBJECT STATUS\n" .. myVerdict
			scoreName.TextColor3 = myVerdict == "VIABLE" and PHOSPHOR or Color3.fromRGB(255, 24, 24)
		end
		sfx(myVerdict == "VIABLE" and "Confirm" or "Reject")
	else
		if conclusion then conclusion.Text = "SIMULATION CONCLUSION" end
		if scoreName then
			scoreName.Text = "OPERATOR\nPERFORMANCE SCORE"
			scoreName.TextColor3 = PHOSPHOR
		end
	end

	local ticker = scoreScreen.Ticker.Text
	task.spawn(function()
		while session == token and scoreScreen.Visible do
			ticker.Position = UDim2.new(0, scoreScreen.AbsoluteSize.X, 0, 0)
			local w = ticker.TextBounds.X + scoreScreen.AbsoluteSize.X
			local tw = TweenService:Create(ticker, TweenInfo.new(w / 120, Enum.EasingStyle.Linear), {
				Position = UDim2.new(0, -ticker.TextBounds.X, 0, 0),
			})
			tw:Play()
			tw.Completed:Wait()
		end
	end)

	local myScore = 0
	for _, e in p.board or {} do
		if e.userId == player.UserId then myScore = e.score end
	end
	local digits = string.format("%04d", myScore)
	for i = 1, 4 do
		local cell = scoreScreen.Odometer["Digit" .. i]
		cell.Value.Text = "0"
		cell.Value.TextColor3 = IDLE
		if uiSettings.ReduceFlicker then
			cell.Value.Text = string.sub(digits, i, i)
			cell.Value.TextColor3 = PHOSPHOR
		else
			rollDigit(cell, string.sub(digits, i, i), (i - 1) * 0.45, token)
		end
	end

	for i = 1, 4 do
		scoreScreen.RankList["Row" .. i].Visible = false
	end
	task.spawn(function()
		task.wait(2.4)
		for i = 1, 4 do
			if session ~= token then return end
			local row = scoreScreen.RankList["Row" .. i]
			local e = p.board and p.board[i]
			if e then
				row.ScoreLabel.Text = string.format("%04d", e.score)
				row.NameLabel.Text = e.displayName
				row.Visible = true
				for c = 1, 2 do
					local check = row["Check" .. c]
					local fill = check:FindFirstChild("Fill")
					if not fill then
						fill = Instance.new("Frame")
						fill.Name = "Fill"
						fill.BackgroundColor3 = PHOSPHOR
						fill.BorderSizePixel = 0
						fill.Position = UDim2.fromOffset(3, 3)
						fill.Size = UDim2.new(1, -6, 1, -6)
						fill.Parent = check
					end
					fill.Visible = false
					task.delay(0.25 * c, function()
						if session == token then fill.Visible = true end
					end)
				end
				task.wait(0.5)
			end
		end
	end)
end

-- MACHINE VOICE (P1.4) ------------------------------------------------------
-- One comment line under the rows of the standings card (Status screen) and
-- of the score card, from `p.line`. The label is built once per screen at
-- runtime in the screen's own row style, so the place GUI needs no new
-- instance; the dispatcher calls these right after showStatus / showScore.

local function voiceLabel(screen, template, position, size, textSize)
	local l = screen:FindFirstChild("VoiceLine")
	if l then return l end
	if template then
		l = template:Clone()
	else
		l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	l.Name = "VoiceLine"
	l.Text = ""
	l.TextColor3 = PHOSPHOR
	if position then l.Position = position end
	if size then l.Size = size end
	if textSize then l.TextSize = textSize end
	l.Visible = false
	l.Parent = screen
	return l
end

-- Standings: one blank row under the last TypeLine, plain (the rows above are
-- already typing; two typewriters at once read as noise).
local function showStatusLine(p)
	local last = statusScreen:FindFirstChild("TypeLine7")
	local pos = last and UDim2.new(last.Position.X.Scale, last.Position.X.Offset,
		last.Position.Y.Scale, last.Position.Y.Offset + 36) or UDim2.new(0, 46, 0.62, 0)
	local l = voiceLabel(statusScreen, last, pos, last and last.Size or UDim2.new(1, -92, 0, 18), nil)
	l.Text = p.line or ""
	l.Visible = p.line ~= nil and p.line ~= ""
end

-- Score: under the rank rows, typed at the status rate while the odometer
-- rolls (the rows themselves only appear at 2.4 s).
local function showScoreLine(p, token)
	local rl = scoreScreen:FindFirstChild("RankList")
	local pos = rl and UDim2.new(rl.Position.X.Scale, rl.Position.X.Offset,
		rl.Position.Y.Scale + rl.Size.Y.Scale, rl.Position.Y.Offset + rl.Size.Y.Offset + 14)
		or UDim2.new(0.55, 0, 0.12, 150)
	local size = rl and UDim2.new(rl.Size.X.Scale, rl.Size.X.Offset, 0, 22) or UDim2.new(0.4, 0, 0, 22)
	local l = voiceLabel(scoreScreen, nil, pos, size, 16)
	l.Text = ""
	l.Visible = false
	if not p.line or p.line == "" then return end
	task.spawn(function()
		task.wait(Feel.Typewriter.ScoreLeadIn)
		if session ~= token then return end
		typewrite(l, p.line, Feel.Typewriter.StatusCps, token)
	end)
end

-- ROLE CARD (P1.4): one sentence, full screen, phosphor on black, hard cut in
-- and out, for p.seconds (1.6 s). Reuses the Announce screen so hideAll() and
-- the server's follow-up "hide" both clear it.
local function showRoleCard(p, token)
	hideAll()
	announceScreen.BackgroundTransparency = 0
	announceScreen.Line.TextColor3 = PHOSPHOR
	announceScreen.Line.Text = p.text or ""
	announceScreen.Visible = true
	task.delay(tonumber(p.seconds) or 1.6, function()
		if session == token then hideAll() end
	end)
end

local function showAnnounce(p, token)
	hideAll()
	if p.style == "death" then
		-- GTA-style: the world stays visible behind the card, text in blood red;
		-- then full black before the respawn, so spawn is never seen
		announceScreen.BackgroundTransparency = 0.4
		announceScreen.Line.TextColor3 = Color3.fromRGB(255, 48, 32)
		task.delay(Feel.Death.Hold, function()
			if session == token and announceScreen.Visible then
				TweenService:Create(announceScreen, TweenInfo.new(Feel.Death.Fade), { BackgroundTransparency = 0 }):Play()
			end
		end)
	else
		announceScreen.BackgroundTransparency = 0
		announceScreen.Line.TextColor3 = PHOSPHOR
	end
	announceScreen.Visible = true
	announceScreen.Line.Text = ""
	task.spawn(function()
		task.wait(Feel.Typewriter.LeadIn)
		if session ~= token then return end
		typewrite(announceScreen.Line, p.text or "", Feel.Typewriter.BodyCps, token)
	end)
end

-- P1.3 PODIUM (23.08.2026): its own beat after the verdict stamp, NOT part of
-- showScore. The screens go away so the world shows the stage through the
-- Machine's fixed camera (set by the funnel before this runs); all that stays
-- on the glass is a phosphor caption, rank + name, bottom centre. Released by
-- the server's clear packet, with a local deadline as the backstop.
local podiumCaption = nil
local function showPodium(p, token)
	hideAll()
	if not podiumCaption then
		podiumCaption = Instance.new("TextLabel")
		podiumCaption.Name = "PodiumCaption"
		podiumCaption.AnchorPoint = Vector2.new(0.5, 1)
		podiumCaption.Position = UDim2.fromScale(0.5, 0.92)
		podiumCaption.Size = UDim2.new(0.8, 0, 0, 96)
		podiumCaption.BackgroundTransparency = 1
		podiumCaption.Font = Enum.Font.Code
		podiumCaption.TextColor3 = PHOSPHOR
		podiumCaption.TextSize = 24
		podiumCaption.TextStrokeColor3 = Color3.new(0, 0, 0)
		podiumCaption.TextStrokeTransparency = 0.25
		podiumCaption.TextXAlignment = Enum.TextXAlignment.Center
		podiumCaption.TextYAlignment = Enum.TextYAlignment.Bottom
		podiumCaption.ZIndex = 70
		podiumCaption.Visible = false
		podiumCaption.Parent = machine
	end
	local lines = {}
	for _, r in ipairs(p.rows or {}) do
		local ord = K.PODIUM_ORDINAL[r.place] or (tostring(r.place) .. "TH")
		lines[#lines + 1] = ("%s  %s"):format(ord, string.upper(tostring(r.displayName or "?")))
	end
	podiumCaption.Text = table.concat(lines, "\n")
	podiumCaption.Visible = #lines > 0
	local deadline = os.clock() + (tonumber(p.seconds) or 8) + 2
	task.spawn(function()
		while session == token and machineCamKind == "podium" and os.clock() < deadline do
			task.wait(0.1)
		end
		podiumCaption.Visible = false
		-- Out of the loop on a new Machine screen or on the deadline with the
		-- camera still ours (the clear never came): release it here, or the
		-- writer would hold the podium view under every screen that follows.
		if machineCamKind == "podium" then setMachineCam("podium", {}) end
	end)
end

-- GORE-FX: sehr aggressiver Kamera-Shake + Blutspritzer auf dem Schirm ------
-- Trauma-Modell: Events laden auf, quadratische Staerke, schneller Abfall.
-- Die Connection steht NACH den Kamera-Writern (Runner/Sniper/Spectate),
-- damit der Shake auf deren CFrame draufmultipliziert wird.
local trauma = 0
local shakeSeed = math.random() * 100
RunService.RenderStepped:Connect(function(dt)
	if trauma <= 0 then return end
	local S = Feel.Shake
	trauma = math.max(0, trauma - dt * S.Decay) -- volle Ladung schuettelt ~3 Sekunden
	-- P2.3: the SHAKE settings row scales the amplitude, never to zero.
	local mag = trauma * trauma * (uiSettings.ReduceShake and S.ReduceFactor or 1)
	local t = os.clock() * S.NoiseHz
	local nx = math.noise(shakeSeed, t)
	local ny = math.noise(shakeSeed + 17, t)
	local nz = math.noise(shakeSeed + 43, t)
	camera.CFrame = camera.CFrame
		* CFrame.new(nx * S.Translate * mag, ny * S.Translate * mag, 0)
		* CFrame.Angles(nx * S.Tilt * mag, ny * S.Tilt * mag, nz * S.Roll * mag)
end)

local function screenBlood(strength)
	local v = Instance.new("Frame")
	v.BackgroundColor3 = Color3.fromRGB(120, 8, 6)
	v.BackgroundTransparency = 0.55
	v.BorderSizePixel = 0
	v.Size = UDim2.fromScale(1, 1)
	v.ZIndex = 60
	v.Parent = machine
	TweenService:Create(v, TweenInfo.new(Feel.Fade.ScreenBlood), { BackgroundTransparency = 1 }):Play()
	task.delay(Feel.Fade.ScreenBlood + 0.05, function() v:Destroy() end)
	local n = math.floor(5 + strength * 9)
	for _ = 1, n do
		local b = Instance.new("Frame")
		local s = 18 + math.random(0, 90) * strength
		b.BackgroundColor3 = (math.random() < 0.5) and Color3.fromRGB(96, 8, 6) or Color3.fromRGB(140, 14, 10)
		b.BorderSizePixel = 0
		b.Size = UDim2.fromOffset(s, s)
		b.Position = UDim2.new(math.random(), 0, math.random() * 0.9 - 0.05, 0)
		b.BackgroundTransparency = 0.08
		b.ZIndex = 61
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = b
		b.Parent = machine
		local life = 1.1 + math.random() * 1.7
		TweenService:Create(b, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = b.Position + UDim2.fromScale(0, 0.25 + math.random() * 0.2),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(math.floor(s * 0.7), math.floor(s * 1.6)),
		}):Play()
		task.delay(life + 0.1, function() b:Destroy() end)
	end
end

local function applyGoreFx(pos, power, force)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local ref = root and root.Position or (camera and camera.CFrame.Position)
	if not ref then return end
	local dist = (ref - pos).Magnitude
	local near = math.clamp(1 - (dist - 10) / 30, 0, 1)
	if force then near = math.max(near, 0.7) end
	if near <= 0.05 then return end
	trauma = math.min(1, trauma + (power or 1) * near)
	if near > 0.2 then screenBlood(near) end
end

-- MP-05 ROUTER BUILD. Every closure below exists by now (sfx, touchAllowed,
-- applyMovement, restoreCamera, TrialInput, applyGoreFx, showAnnounce).
if TrialClientKit then
	trialRouter = TrialClientKit.newRouter({
		player = player,
		machine = machine,
		camera = camera,
		TrialInput = TrialInput,
		trialClientsFolder = trialClientsFolder,
		sfx = sfx,
		touchAllowed = touchAllowed,
		applyGoreFx = applyGoreFx,
		showCard = function(text, style)
			session += 1
			showAnnounce({ text = text, style = style }, session)
		end,
		getToken = function() return trialRoundToken end,
		setToken = function(tok) trialRoundToken = tok end,
		setMove = function(state, speed)
			moveState = state
			trialWalkSpeed = speed or 0
			applyMovement()
		end,
		setCam = function(tbl)
			trialCam = tbl
			smoothCamPos = nil
		end,
		clearSpectate = function()
			spectateCF = nil
			spectateWatch = nil
			spectateEye = nil
		end,
		restoreCamera = restoreCamera,
		hideCountText = function()
			local c = machine:FindFirstChild("CountText")
			if c then c.Visible = false end
		end,
	})
	-- Abort backstop: MachineFlow clears KenopsiaActiveTrial on every exit
	-- path, including the ones where the trial's own `end` packet never went
	-- out. A module still active for a different id than the attribute is
	-- ended here.
	player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(function()
		local id = player:GetAttribute("KenopsiaActiveTrial") or ""
		if trialRouter and trialRouter.activeId and trialRouter.activeId ~= id then
			trialRouter.endActive()
		end
	end)
end

-- DISPATCH ------------------------------------------------------------------

MachineState.OnClientEvent:Connect(function(p)
	if type(p) ~= "table" then return end
	-- MP-05: kind="trial" is consumed by the router; generic kinds are observed
	-- and fall through to the legacy handlers below.
	if trialRouter and trialRouter.handle(p) then return end
	if p.kind == "huntersetup" then
		setHunterSetup(sniperActive)
		return
	end
	if p.kind == "mines" then
		showMines(p.list or {})
		return
	end
	if p.kind == "role" then
		-- F-1 (MP-05 D14): Canteen delivers the round token INSIDE its spectate
		-- role packet, and this handler used to return before adopting it, so
		-- every plate/mouth was sent with a nil token and dropped. Adopt a
		-- token whenever one is present, before the spectate early-return.
		if p.roundToken ~= nil then trialRoundToken = p.roundToken end
		if p.role == "spectate" then
			-- toter Beobachter: feste Kamera ueber dem Feld
			local pos = Vector3.new(p.pos[1], p.pos[2], p.pos[3])
			local look = Vector3.new(p.look[1], p.look[2], p.look[3])
			spectateCF = CFrame.lookAt(pos, look)
			spectateWatch = p.watch
			spectateIndex = 1
			spectateEye = nil
			runnerCam = false
			return
		end
		spectateCF = nil
		spectateWatch = nil
		spectateEye = nil
		-- C1.a: adopt this round's token, or drop it when the round ends.
		trialRoundToken = p.roundToken
		if p.role == "none" then
			-- C5 companion: CountText is written by the "count" handler and
			-- hidden ONLY by the "go" handler. An aborted leg now returns
			-- before GO, so without this the frozen "3"/"2"/"1" stays on screen
			-- indefinitely. hideAll() does not touch CountText - it is a
			-- sibling under `machine`, not under the screens hideAll clears -
			-- so MachineFlow's {kind="hide"} does not clear it either. Both
			-- Bird's C5 bails and Dead Zone's C1 bails end with role="none".
			local c = machine:FindFirstChild("CountText")
			if c then c.Visible = false end
		end
		sniperActive = p.role == "sniper"
		if not sniperActive then setHunterSetup(false) end
		setSniperRig(sniperActive)
		setSniperLight(sniperActive)
		setRunnerTouch(p.role == "runner")
		if p.role ~= "runner" then
			youLabel.Visible = false
			local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if h then h.AutoRotate = true end
		end
		runnerCam = p.role == "runner"
		runnerCamDir = p.camDir or 1
		runnerCamStyle = p.camStyle or "chase"
		smoothCamPos = nil
		pendingRunner = p.role == "runner"
		moveState = (p.role == "runner" and not p.frozen) and "runner" or "frozen"
		applyMovement()
		pcall(function()
			UserInputService.MouseIconEnabled = p.role ~= "runner"
		end)
		if p.role == "runner" then
			bindForwardOnly()
		else
			unbindForwardOnly()
		end
		if not runnerCam and not sniperActive then
			restoreCamera()
		end
		return
	end
	if p.kind == "gorefx" then
		if p.pos then
			applyGoreFx(Vector3.new(p.pos[1], p.pos[2], p.pos[3]), p.power, p.force)
		end
		return
	end
	-- CANTEEN PROTOCOL. Every one of these is a pure readout: the server has
	-- already decided by the time the packet arrives.
	if p.kind == "cpstate" then
		cpShowHud()
		cpSetState(p.peas or 0, p.fork or 0, p.eaten or 0, p.total or 20)
		return
	end
	if p.kind == "cpobs" then
		cpSetPhase(p.phase)
		return
	end
	if p.kind == "cpmiss" then
		-- Empty fork to the mouth. Harmless by design, so this is a nudge and
		-- not a punishment: it says "nothing on the fork", not "you failed".
		local hud = buildCanteenHud()
		hud.Panel.Ration.TextColor3 = K.CP_WARN
		TweenService:Create(hud.Panel.Ration, TweenInfo.new(Feel.Fade.Ration), { TextColor3 = K.CP_IDLE }):Play()
		return
	end
	if p.kind == "cpdone" then
		local hud = buildCanteenHud()
		hud.Phase.Text = "RATION COMPLETE - YOU ARE SAFE"
		hud.Phase.TextColor3 = K.CP_SAFE
		-- Finished players cannot be caught and cannot act. Dropping
		-- canteenActive here stops the client sending input the server would
		-- only throw away.
		canteenActive = false
		local pad = machine:FindFirstChild("CanteenTouch")
		if pad then pad.Visible = false end
		return
	end
	if p.kind == "cpout" then
		local hud = buildCanteenHud()
		hud.Phase.Text = "PROTOCOL VIOLATION"
		hud.Phase.TextColor3 = K.CP_DANGER
		hud.Edge.Glow.Color = K.CP_DANGER
		hud.Edge.Glow.Transparency = 0
		canteenActive = false
		local pad = machine:FindFirstChild("CanteenTouch")
		if pad then pad.Visible = false end
		return
	end
	if p.kind == "cpend" then
		cpHideHud()
		return
	end
	if p.kind == "count" then
		sniperCanAim = sniperActive
		sniperCanFire = false
		setHunterSetup(false)
		sfx("Count" .. tostring(p.n))
		if p.n == 3 then
			-- black card cuts away; the arena fades in under the count
			hideAll()
			faderFrame.BackgroundTransparency = 0
			faderFrame.Visible = true
			TweenService:Create(faderFrame, TweenInfo.new(Feel.Fade.ArenaIn, Feel.easing(Feel.Easing.Fade, Feel.Easing.FadeInDir)), { BackgroundTransparency = 1 }):Play()
			task.delay(Feel.Fade.ArenaIn + 0.05, function()
				faderFrame.Visible = false
				faderFrame.BackgroundTransparency = 0
			end)
		end
		local c = machine:FindFirstChild("CountText")
		if c then
			c.Text = tostring(p.n)
			c.Visible = true
			-- P1.5: ONE 3-2-1. TrialKit Round:countdown and the three legacy
			-- services all send {kind="count"}; the punch numbers live in Feel.
			c.TextSize = Feel.Countdown.PunchFrom
			TweenService:Create(c, TweenInfo.new(Feel.Countdown.PunchSeconds, Feel.easing(Feel.Easing.Snap, Feel.Easing.SnapDir)), { TextSize = Feel.Countdown.PunchTo }):Play()
		end
		return
	end
	if p.kind == "hitmark" then
		local hm = machine:FindFirstChild("HitMark")
		if hm then
			-- REQ-IP-01. The previous headshot string was a borrowed catchphrase
			-- and sat oddly against the clinical register the rest of the game
			-- speaks in -- ACCESS DENIED, STAND CLEAR, VIABLE, REJECTED. It is
			-- deliberately not quoted here: removing a phrase from the UI and
			-- then writing it into a comment leaves it in the shipped source.
			--
			-- NOTE: nothing sends kind = "hitmark" today, so this handler never
			-- runs. Wiring the sniper's hit feedback is its own Gate 3 step; the
			-- string is corrected here so the phrase is not sitting in shipped
			-- source while that waits.
			hm.Text = p.head and "TERMINATED" or "IMPACT"
			hm.TextColor3 = p.head and Color3.fromRGB(255, 48, 32) or PHOSPHOR
			hm.TextSize = p.head and 46 or 30
			hm.TextTransparency = 0
			hm.Visible = true
			TweenService:Create(hm, TweenInfo.new(Feel.Fade.HitMark, Feel.easing(Feel.Easing.Fade, Feel.Easing.FadeInDir)), { TextTransparency = 1 }):Play()
			task.delay(Feel.Fade.HitMark + 0.05, function() hm.Visible = false end)
		end
		sfx(p.head and "AccessGranted" or "Confirm")
		return
	end
	if p.kind == "go" then
		if sniperActive then
			sniperCanAim = true
			sniperCanFire = true
		end
		setHunterSetup(false)
		sfx("AccessGranted")
		local c = machine:FindFirstChild("CountText")
		if c then
			c.Text = "GO!"
			c.TextSize = Feel.Countdown.GoFrom
			c.TextTransparency = 0
			c.Visible = true
			TweenService:Create(c, TweenInfo.new(Feel.Countdown.GoSeconds, Feel.easing(Feel.Easing.Snap, Feel.Easing.SnapDir)), {
				TextSize = Feel.Countdown.GoTo,
				TextTransparency = Feel.Countdown.GoTransparency,
			}):Play()
			task.delay(Feel.Countdown.GoHold, function()
				if c.Text == "GO!" then c.Visible = false end
			end)
		end
		faderFrame.Visible = false
		if pendingRunner then
			moveState = "runner"
			applyMovement()
			youLabel.TextTransparency = 0
			youLabel.Visible = true
			task.delay(0.85, function()
				if not pendingRunner then return end
				TweenService:Create(youLabel, TweenInfo.new(Feel.Fade.YouLabel), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				task.delay(Feel.Fade.YouLabel + 0.03, function()
					youLabel.Visible = false
					youLabel.TextStrokeTransparency = 0.25
				end)
			end)
		end
		return
	end
	-- P1.3 / P1.7: the Machine's fixed cameras. A packet with its camera field
	-- sets it, one without is the clear (Shared/Rules/MachineCam). Neither
	-- reaches the screen funnel below: the audience view must NOT cancel the
	-- bench card it is shown under, and the podium bumps `session` itself.
	if p.kind == "podium" then
		if setMachineCam("podium", p) then
			session += 1
			showPodium(p, session)
		end
		return
	end
	if p.kind == "audiencecam" then
		setMachineCam("audiencecam", p)
		return
	end
	if not K.KNOWN_KINDS[p.kind] then
		if not unknownKinds[p.kind] then
			unknownKinds[p.kind] = true
			warn("[Kenopsia] unhandled MachineState kind: " .. tostring(p.kind))
		end
		return
	end
	session += 1
	local token = session
	local cover = machine:FindFirstChild("JoinCover")
	if cover and cover.Visible and p.kind ~= "hide" then
		cover.Visible = false
	end
	local lobbyKinds = { selection = true, info = true, score = true }
	setLobbyMusic(lobbyKinds[p.kind] == true)
	-- MP-05 belt: a lobby screen means no trial is running.
	if trialRouter and lobbyKinds[p.kind] then trialRouter.endActive() end
	if p.kind == "selection" then
		showSelection(p, token)
	elseif p.kind == "info" then
		if p.id then machine:SetAttribute("TrialId", p.id) end
		showInfo(p, token)
	elseif p.kind == "status" then
		showStatus(p, token)
		showStatusLine(p)
	elseif p.kind == "round" then
		showRound(p, token)
	elseif p.kind == "rolecard" then
		showRoleCard(p, token)
	elseif p.kind == "score" then
		showScore(p, token)
		showScoreLine(p, token)
	elseif p.kind == "announce" then
		showAnnounce(p, token)
	elseif p.kind == "hide" then
		hideAll()
	end
end)

-- CONTENT WARNING + SETTINGS ------------------------------------------------

local warningFrame = machine:WaitForChild("Warning", 10)
local settingsPanel = machine:WaitForChild("SettingsPanel", 10)

if warningFrame then
	local dismissed = false
	local function dismiss()
		if dismissed then return end
		dismissed = true
		warningFrame.Visible = false
	end

	-- CONNECTED FIRST, before anything that yields.
	--
	-- This whole block used to sit inside a task.spawn that began with
	-- task.wait(0.4). The wait was there for the sound, but it also delayed
	-- the button being wired -- so for the first 0.4 s the warning was on
	-- screen with a CONTINUE that did nothing. Clicks in that window landed
	-- on a handler that did not exist yet, which reads as a frozen button.
	local btn = warningFrame:FindFirstChild("Btn_CONTINUE")
	if btn then
		btn.Activated:Connect(function()
			sfx("Click")
			dismiss()
		end)
	end
	task.delay(6.5, dismiss)

	-- The sound keeps its short lead-in; only the wiring moved ahead of it.
	task.spawn(function()
		task.wait(0.4)
		if not dismissed then sfx("Warning") end
	end)
end

if settingsPanel then
	local rows = {
		{ frame = settingsPanel:FindFirstChild("Row_UISOUND"), key = "UiSound" },
		{ frame = settingsPanel:FindFirstChild("Row_MUSIC"), key = "Music" },
		{ frame = settingsPanel:FindFirstChild("Row_REDUCEFLICKER"), key = "ReduceFlicker" },
		{ frame = settingsPanel:FindFirstChild("Row_SIMFILTER"), key = "SimFilter" },
		{ frame = settingsPanel:FindFirstChild("Row_CRT"), key = "Crt" },
		-- P2.3: a clone of Row_CRT at y 356 (panel grown to 492 px); a place
		-- without the row is harmless -- every loop below guards on r.frame.
		{ frame = settingsPanel:FindFirstChild("Row_SHAKE"), key = "ReduceShake" },
	}
	local function render()
		for _, r in rows do
			if r.frame then
				r.frame.Check.Fill.Visible = uiSettings[r.key] == true
			end
		end
	end
	render()
	-- P2.3: follow the OS Reduce Motion switch at runtime. Seeds only when it
	-- turns ON; a player's own OFF choice is never overridden.
	pcall(function()
		GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			if not GuiService.ReducedMotionEnabled then return end
			for _, key in { "ReduceFlicker", "ReduceShake" } do
				uiSettings[key] = true
				publishSetting(key)
			end
			render()
		end)
	end)
	for _, r in rows do
		if r.frame then
			r.frame.Hit.Activated:Connect(function()
				uiSettings[r.key] = not uiSettings[r.key]
				publishSetting(r.key)
				sfx("Click")
				render()
				if r.key == "Music" then setLobbyMusic(lobbyMusicOn) end
			end)
		end
	end
	local closeBtn = settingsPanel:FindFirstChild("Btn_CLOSE")
	if closeBtn then
		closeBtn.Activated:Connect(function()
			sfx("Click")
			settingsPanel.Visible = false
		end)
	end
	local openBtn = info:FindFirstChild("Btn_SETTINGS")
	if openBtn then
		openBtn.Activated:Connect(function()
			sfx("Click")
			settingsPanel.Visible = not settingsPanel.Visible
		end)
	end
end

-- CONTROLS pager -------------------------------------------------------------
do
	local win = info:FindFirstChild("ControlsWindow")
	if win then
		local pageOne = { "SecRunners", "Row1", "Row1b", "SecSniper", "Row2", "Row3" }
		local page2 = win:FindFirstChild("Page2")
		local pageLabel = win:FindFirstChild("PageLabel")
		local arrows = {}
		local page = 1

		local function hasSecondPage()
			-- Only Canteen has a second page: its scoring rules do not fit on
			-- one. This compared against the reference game's name for the
			-- minigame, which the server never sends, so the page was dead.
			return machine:GetAttribute("TrialId") == "canteen"
		end

		local function renderPage()
			local pages = hasSecondPage() and 2 or 1
			if page > pages then page = 1 end
			for _, n in pageOne do
				local f = win:FindFirstChild(n)
				if f then f.Visible = page == 1 end
			end
			if page2 then page2.Visible = pages == 2 and page == 2 end
			if pageLabel then
				pageLabel.Text = "Page " .. page .. "/" .. pages
				pageLabel.Visible = pages > 1
			end
			for _, arrow in arrows do arrow.Visible = pages > 1 end
		end
		local function flip()
			if not hasSecondPage() then return end
			sfx("Click")
			page = page == 1 and 2 or 1
			renderPage()
		end
		for _, n in { "ArrowL", "ArrowR" } do
			local arrow = win:FindFirstChild(n)
			if arrow then
				table.insert(arrows, arrow)
				local hit = arrow:FindFirstChild("Hit")
				if hit then hit.Activated:Connect(flip) end
			end
		end
		machine:GetAttributeChangedSignal("TrialId"):Connect(renderPage)
		renderPage()
	end
end

-- LOBBY ERRORS ---------------------------------------------------------------
-- Every server-side rejection -- not host, too few players, ready refused, run
-- aborted -- is sent on LobbyError. Until now nothing on this client listened,
-- so all of it landed in silence: the player pressed a button, the server said
-- no, and the screen did not change. That is indistinguishable from a bug, and
-- it is why people press the same button again.
--
-- Deliberately its OWN ScreenGui rather than a frame inside the machine layout.
-- The notice has to be visible during a minigame as well as in the lobby, and
-- every show* on the machine begins with hideAll(); a notice living in there
-- would be wiped by the next screen change it was trying to explain.
do
	local lobbyError = remotes:FindFirstChild("LobbyError")
	if lobbyError then
		local gui = Instance.new("ScreenGui")
		gui.Name = "KenopsiaNotice"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 900
		gui.Enabled = false
		gui.Parent = playerGui

		local line = Instance.new("TextLabel")
		line.Name = "Line"
		line.AnchorPoint = Vector2.new(0.5, 1)
		line.Position = UDim2.fromScale(0.5, 0.94)
		line.Size = UDim2.new(0.9, 0, 0, 30)
		line.BackgroundTransparency = 1
		line.Font = Enum.Font.Code
		line.TextSize = 20
		line.TextColor3 = AMBER
		line.TextStrokeTransparency = 0.4
		line.Text = ""
		line.Parent = gui

		local noticeSeq = 0
		-- Connected without storing the handle: this LocalScript has no teardown
		-- path and lives for the whole session. A first draft pushed it into a
		-- `conns` table that does not exist in this file, which would have thrown
		-- on the first rejection -- the exact case the notice exists to report.
		lobbyError.OnClientEvent:Connect(function(message)
			if type(message) ~= "string" or message == "" then return end
			noticeSeq += 1
			local mine = noticeSeq
			line.Text = string.upper(message)
			line.TextTransparency = 0
			gui.Enabled = true
			sfx("Reject")
			-- Held on a sequence number, not a debounce: a second rejection
			-- while the first is still showing must replace it and restart the
			-- clock, never be dropped and never let the older timer hide the
			-- newer message.
			task.delay(3.5, function()
				if noticeSeq ~= mine then return end
				TweenService:Create(line, TweenInfo.new(Feel.Fade.Notice), { TextTransparency = 1 }):Play()
				task.delay(Feel.Fade.Notice + 0.05, function()
					if noticeSeq == mine then gui.Enabled = false end
				end)
			end)
		end)
	else
		warn("[Kenopsia] LobbyError remote missing - server rejections will be silent")
	end
end

print("[Kenopsia] client online")
