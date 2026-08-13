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
local XBotPush = remotes:WaitForChild("XBotPush", 15)
local XBotCrouch = remotes:WaitForChild("XBotCrouch", 15)

local machine = playerGui:WaitForChild("KenopsiaMachine")

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

local function addSizeLimits(gui, minSize, maxSize)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = minSize
	constraint.MaxSize = maxSize
	constraint.Parent = gui
end
addSizeLimits(lookTitle, Vector2.new(260, 42), Vector2.new(520, 42))
addSizeLimits(lookTrack, Vector2.new(250, 50), Vector2.new(440, 50))
addSizeLimits(lookHint, Vector2.new(280, 28), Vector2.new(540, 28))

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

-- SESSION SETTINGS + UI AUDIO -----------------------------------------------

local uiSettings = { UiSound = true, Music = true, ReduceFlicker = false }

-- Click/Submit draw a random variant from their pool so repeated presses
-- don't sound like a sample loop
local SFX_POOLS = { Click = "Clicks", Submit = "Submits" }
local function sfx(name)
	if not uiSettings.UiSound then return end
	local root = SoundService:FindFirstChild("KenopsiaAudio")
	local folder = root and root:FindFirstChild("SFX")
	if not folder then return end
	local s
	local poolName = SFX_POOLS[name]
	local pool = poolName and folder:FindFirstChild(poolName)
	if pool then
		local variants = pool:GetChildren()
		if #variants > 0 then s = variants[math.random(#variants)] end
	end
	s = s or folder:FindFirstChild(name)
	if s and s.SoundId ~= "" then
		SoundService:PlayLocalSound(s)
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

-- DEAD-ZONE-LICHT: schwarzes Void + kaltes blaues Flutlicht, nur waehrend der
-- Runde und nur auf diesem Client; danach wird alles exakt zurueckgestellt
local LightingSvc = game:GetService("Lighting")
local savedLight = nil
local dzColor = nil
local dzLampFolder = nil

local function enterDZLight()
	if savedLight then return end
	savedLight = {
		Ambient = LightingSvc.Ambient,
		OutdoorAmbient = LightingSvc.OutdoorAmbient,
		FogColor = LightingSvc.FogColor,
		FogStart = LightingSvc.FogStart,
		FogEnd = LightingSvc.FogEnd,
		Brightness = LightingSvc.Brightness,
		ClockTime = LightingSvc.ClockTime,
	}
	LightingSvc.Ambient = Color3.fromRGB(10, 12, 18)
	LightingSvc.OutdoorAmbient = Color3.fromRGB(2, 3, 6)
	LightingSvc.FogColor = Color3.fromRGB(0, 0, 0)
	LightingSvc.FogStart = 45
	LightingSvc.FogEnd = 150
	LightingSvc.Brightness = 1
	LightingSvc.ClockTime = 0
	dzColor = Instance.new("ColorCorrectionEffect")
	dzColor.Saturation = -0.35
	dzColor.Contrast = 0.08
	dzColor.TintColor = Color3.fromRGB(205, 218, 255)
	dzColor.Parent = LightingSvc
	-- Flutlicht-Raster ueber dem Feld (nur lokal, kostet den Server nichts)
	dzLampFolder = Instance.new("Folder")
	dzLampFolder.Name = "DZ_Lights_Local"
	dzLampFolder.Parent = workspace
	local dz = workspace:FindFirstChild("Dead Zone")
	local ground = dz and dz:FindFirstChild("Minefield Ground")
	if ground then
		local size = ground.Size
		local cf = ground.CFrame
		local nx = math.clamp(math.floor(size.X / 16), 2, 5)
		local nz = math.clamp(math.floor(size.Z / 16), 2, 7)
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
				local spot = Instance.new("SpotLight")
				spot.Face = Enum.NormalId.Bottom
				spot.Angle = 80
				spot.Range = 26
				spot.Brightness = 2.4
				spot.Color = Color3.fromRGB(170, 205, 255)
				spot.Shadows = false
				spot.Parent = holder
				holder.Parent = dzLampFolder
			end
		end
	end
end

local function exitDZLight()
	if not savedLight then return end
	for k, val in pairs(savedLight) do LightingSvc[k] = val end
	savedLight = nil
	if dzColor then dzColor:Destroy() dzColor = nil end
	if dzLampFolder then dzLampFolder:Destroy() dzLampFolder = nil end
end

local function updateDZLight()
	local active = player:GetAttribute("KenopsiaActiveTrial") or ""
	if active == "minefield" then enterDZLight() else exitDZLight() end
end
player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(updateDZLight)
task.defer(updateDZLight)

local controlsModule
task.spawn(function()
	pcall(function()
		local ps = player:WaitForChild("PlayerScripts", 10)
		local pm = ps and ps:WaitForChild("PlayerModule", 10)
		if pm then controlsModule = require(pm):GetControls() end
	end)
end)

local FORWARD_BIND = "KenopsiaForwardOnly"
local function bindForwardOnly()
	RunService:BindToRenderStep(FORWARD_BIND, Enum.RenderPriority.Input.Value + 1, function()
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
		RunService:UnbindFromRenderStep(FORWARD_BIND)
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
end

local function typewrite(label, text, cps, token)
	label.Visible = true
	label.Text = ""
	for i = 1, #text do
		if session ~= token then return end
		label.Text = string.sub(text, 1, i)
		task.wait(1 / cps)
	end
end

-- MOVEMENT: frozen everywhere except as a runner in a live round ------------

local moveState = "frozen"
local function applyMovement()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if moveState == "runner" then
		-- Dead Zone (Move-Set "scan"): NUR Gehen - der Kastrierer ist knapp langsamer.
		-- Ueberall sonst wird sofort gerannt (kein Anlauf mehr).
		local moves = char:GetAttribute("XBotMoves") or ""
		hum.WalkSpeed = string.find(moves, "scan") and 7 or 14
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
local runnerCamStyle = "chase" -- "top" = fast 2D-Draufsicht (Dead Zone, Machine-Party-Look)
local smoothCamPos = nil
local spectateCF = nil

local function restoreCamera()
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
end

RunService.RenderStepped:Connect(function(dt)
	if spectateCF then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = spectateCF
	elseif runnerCam then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			camera.CameraType = Enum.CameraType.Scriptable
			if runnerCamStyle == "top" then
				-- fast senkrechte, weich nachziehende Draufsicht wie im Original
				local eye = root.Position + Vector3.new(0, 24, -9 * runnerCamDir)
				smoothCamPos = smoothCamPos and smoothCamPos:Lerp(eye, math.min(dt * 6, 1)) or eye
				camera.CFrame = CFrame.lookAt(smoothCamPos, smoothCamPos + Vector3.new(0, -24, 15 * runnerCamDir))
			else
				camera.CFrame = CFrame.lookAt(
					root.Position + Vector3.new(0, 20, -17 * runnerCamDir),
					root.Position + Vector3.new(0, 3, 30 * runnerCamDir))
			end
			-- Shiftlock only: der Charakter blickt immer in Bahnrichtung
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum.AutoRotate = false end
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, runnerCamDir == 1 and math.pi or 0, 0)
		end
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
local SNIPER_BASE_FOV = 70
local ZOOMS = { { fov = 35, label = "x2" }, { fov = 18, label = "x4" } }
local zoomIdx = 1

-- Roblox recreates CurrentCamera after death/respawn; never trust the old one
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCam = workspace.CurrentCamera
	if newCam then
		camera = newCam
		if viewmodel then viewmodel.Parent = camera end
	end
end)

local function applyScope()
	local targetFov = scoped and ZOOMS[zoomIdx].fov or (sniperActive and SNIPER_BASE_FOV or 70)
	TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = targetFov }):Play()
	scopeGui.Visible = scoped
	local zl = scopeGui:FindFirstChild("ZoomLabel")
	if zl then zl.Text = ZOOMS[zoomIdx].label end
	local zb = touchControls:FindFirstChild("Btn_ZOOM")
	if zb then
		zb.Visible = scoped
		zb.Text = ZOOMS[zoomIdx].label
	end
	hipCross.Visible = sniperActive and not scoped
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

local FIRE_COOLDOWN = 2.2 -- mirror of the server gate, for HUD feedback only
local lastFireAt = -10
local function fireShot()
	if not sniperActive or not sniperCanFire or not SniperFire then return end
	if os.clock() - lastFireAt < FIRE_COOLDOWN then return end
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
		zoomIdx = zoomIdx % #ZOOMS + 1
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
	zoomIdx = zoomIdx % #ZOOMS + 1
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
touchControls.Btn_CROUCH.Activated:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and hum) then return end
	if not crouchToggled and not charSneakAllowed() then return end
	if not crouchToggled and hum.WalkSpeed <= 0 then return end
	setCrouchTouch(not crouchToggled)
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
local function showMines(list)
	for _, e in list do
		local key = math.floor(e[1]) .. ":" .. math.floor(e[3])
		local mark = revealMarks[key]
		if not mark then
			mark = Instance.new("Part")
			mark.Shape = Enum.PartType.Cylinder
			mark.Size = Vector3.new(0.12, 1.6, 1.6)
			mark.CFrame = CFrame.new(e[1], e[2] + 0.12, e[3]) * CFrame.Angles(0, 0, math.rad(90))
			mark.Material = Enum.Material.Neon
			mark.Color = Color3.fromRGB(255, 60, 50)
			mark.Anchored = true
			mark.CanCollide = false
			mark.CanQuery = false
			mark.CanTouch = false
			mark.Parent = workspace
			revealMarks[key] = mark
		end
		mark.Transparency = e[4] and 0.1 or 0.55
		mark:SetAttribute("DieAt", os.clock() + 1.6)
	end
end
task.spawn(function()
	while true do
		task.wait(0.4)
		for key, mark in pairs(revealMarks) do
			if (mark:GetAttribute("DieAt") or 0) < os.clock() then
				mark:Destroy()
				revealMarks[key] = nil
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

-- CANTEEN PROTOCOL: Beat-Track-HUD + Ess-Eingabe (E / ButtonA / EAT-Button) --
local canteenActive = false
local canteenHud = nil
local canteenTicks = {}
local canteenPlan = nil
local canteenLoop = nil
local biteReadyAt = 0
local biteLockUntil = 0
local CP_PXPS = 140

local function charEatAllowed()
	local char = player.Character
	return char ~= nil and string.find(char:GetAttribute("XBotMoves") or "", "eat") ~= nil
end

local function buildCanteenHud()
	if canteenHud then return canteenHud end
	local f = Instance.new("Frame")
	f.Name = "CanteenHud"
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Position = UDim2.new(0.5, 0, 1, -18)
	f.Size = UDim2.new(0, 560, 0, 116)
	f.BackgroundColor3 = Color3.fromRGB(6, 12, 9)
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Visible = false
	local st = Instance.new("UIStroke")
	st.Color = PHOSPHOR
	st.Thickness = 1
	st.Parent = f
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 10, 0, 6)
	title.Size = UDim2.new(1, -90, 0, 16)
	title.Font = Enum.Font.Code
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = PHOSPHOR
	title.Text = "CANTEEN PROTOCOL \u{2014} EAT [E]"
	title.Parent = f
	local counter = Instance.new("TextLabel")
	counter.Name = "Counter"
	counter.BackgroundTransparency = 1
	counter.Position = UDim2.new(1, -70, 0, 6)
	counter.Size = UDim2.new(0, 60, 0, 16)
	counter.Font = Enum.Font.Code
	counter.TextSize = 14
	counter.TextXAlignment = Enum.TextXAlignment.Right
	counter.TextColor3 = PHOSPHOR
	counter.Text = "00/16"
	counter.Parent = f
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 10, 0, 30)
	track.Size = UDim2.new(1, -20, 0, 46)
	track.BackgroundColor3 = Color3.fromRGB(10, 18, 13)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = f
	local zg = Instance.new("Frame")
	zg.Name = "ZoneGood"
	zg.AnchorPoint = Vector2.new(0.5, 0.5)
	zg.Position = UDim2.new(0.5, 0, 0.5, 0)
	zg.Size = UDim2.new(0, math.floor(2 * 0.15 * CP_PXPS), 1, -8)
	zg.BackgroundColor3 = Color3.fromRGB(38, 66, 46)
	zg.BackgroundTransparency = 0.35
	zg.BorderSizePixel = 0
	zg.Parent = track
	local zp = Instance.new("Frame")
	zp.Name = "ZonePerfect"
	zp.AnchorPoint = Vector2.new(0.5, 0.5)
	zp.Position = UDim2.new(0.5, 0, 0.5, 0)
	zp.Size = UDim2.new(0, math.floor(2 * 0.07 * CP_PXPS), 1, -8)
	zp.BackgroundColor3 = Color3.fromRGB(52, 120, 66)
	zp.BackgroundTransparency = 0.45
	zp.BorderSizePixel = 0
	zp.ZIndex = 2
	zp.Parent = track
	local grade = Instance.new("TextLabel")
	grade.Name = "Grade"
	grade.BackgroundTransparency = 1
	grade.AnchorPoint = Vector2.new(0.5, 0)
	grade.Position = UDim2.new(0.5, 0, 0, 78)
	grade.Size = UDim2.new(0, 200, 0, 18)
	grade.Font = Enum.Font.Code
	grade.TextSize = 16
	grade.TextColor3 = PHOSPHOR
	grade.TextTransparency = 1
	grade.Text = ""
	grade.Parent = f
	local stress = Instance.new("Frame")
	stress.Name = "Stress"
	stress.Position = UDim2.new(0, 10, 1, -14)
	stress.Size = UDim2.new(1, -20, 0, 8)
	stress.BackgroundColor3 = DIM
	stress.BorderSizePixel = 0
	stress.Parent = f
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 70, 60)
	fill.BorderSizePixel = 0
	fill.Parent = stress
	f.Parent = machine
	canteenHud = f
	return f
end

local function canteenStep()
	if not canteenPlan or not canteenHud then return end
	local track = canteenHud:FindFirstChild("Track")
	if not track then return end
	local now = workspace:GetServerTimeNow()
	local half = track.AbsoluteSize.X / 2
	for i, tk in canteenTicks do
		if tk.frame.Visible then
			local dt = (canteenPlan.startAt + canteenPlan.beats[i]) - now
			tk.frame.Position = UDim2.new(0, half + dt * CP_PXPS, 0.5, 0)
			if not tk.eaten and not tk.dead and dt < -0.16 then
				tk.dead = true
				tk.frame.BackgroundColor3 = Color3.fromRGB(140, 34, 26)
				TweenService:Create(tk.frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
				task.delay(0.45, function() tk.frame.Visible = false end)
			end
		end
	end
end

local function sendBite()
	if not canteenActive or not charEatAllowed() then return end
	local now = os.clock()
	if now < biteReadyAt or now < biteLockUntil then return end
	biteReadyAt = now + 0.35
	if TrialInput then
		TrialInput:FireServer({ trialId = "tablemanners", action = "bite" })
	end
	local track = canteenHud and canteenHud:FindFirstChild("Track")
	local zp = track and track:FindFirstChild("ZonePerfect")
	if zp then
		zp.BackgroundTransparency = 0.05
		TweenService:Create(zp, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E or (input.KeyCode == Enum.KeyCode.ButtonA and canteenActive) then
		sendBite()
	end
end)
local eatBtn = touchControls:FindFirstChild("Btn_EAT")
if eatBtn then
	eatBtn.Activated:Connect(sendBite)
end

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed or not sniperActive or not scoped then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local newIdx = math.clamp(zoomIdx + (input.Position.Z > 0 and 1 or -1), 1, #ZOOMS)
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
					local bt = (os.clock() - boltCycleStart) / FIRE_COOLDOWN
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
		task.wait(0.4)
		for _, t in tiles do
			if session ~= token then return end
			t.Visible = true
			task.wait(0.25)
		end
		task.wait(0.3)
		if session ~= token then return end

		-- symbols flicker chaotically, then the machine locks its choice
		if uiSettings.ReduceFlicker then
			task.wait(0.6)
			if session ~= token then return end
		else
			local deadline = os.clock() + 1.6
			while os.clock() < deadline do
				if session ~= token then return end
				for i = 1, 3 do
					tiles[i].Icon.Visible = math.random() < 0.55
					setTileLit(tiles[i], math.random() < 0.4)
				end
				task.wait(0.07)
			end
		end
		for i = 1, 3 do
			tiles[i].Icon.Visible = true
			setTileLit(tiles[i], i == (p.chosen or 1))
		end

		-- lock-in flash: longer, heavier blinks
		local chosenTile = tiles[p.chosen or 1]
		for _ = 1, (uiSettings.ReduceFlicker and 1 or 4) do
			if session ~= token then return end
			chosenTile.Visible = false
			task.wait(0.14)
			chosenTile.Visible = true
			task.wait(0.2)
		end

		-- crosshair snaps straight to the mark
		local center = chosenTile.AbsolutePosition + chosenTile.AbsoluteSize / 2
		selection.CrossH.Position = UDim2.new(0, 0, 0, -6)
		selection.CrossV.Position = UDim2.new(0, -6, 0, 0)
		selection.CrossH.Visible = true
		selection.CrossV.Visible = true
		TweenService:Create(selection.CrossH, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, center.Y + 16),
		}):Play()
		TweenService:Create(selection.CrossV, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, center.X, 0, 0),
		}):Play()
		task.wait(0.45)
		if session ~= token then return end
		selection.BootText.Position = UDim2.new(0, center.X + 90, 0, center.Y)
		typewrite(selection.BootText, "Simulation bootst:", 22, token)
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
		typewrite(info.NextLabel, "NEXT SIMULATION: " .. (p.name or "?"), 26, token)
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
			if l then typewrite(l, text, 30, token) end
			task.wait(0.25)
		end
	end)
end

local function showRound(p, token)
	hideAll()
	roundCard.Visible = true
	roundCard.Title.Text = ("Round %d/%d"):format(p.n or 1, p.total or 3)
	roundCard.Verbs.Text = ""
	task.spawn(function()
		typewrite(roundCard.Verbs, (p.verbs or "") .. "_", 24, token)
	end)
end

local function rollDigit(cell, target, delay, token)
	task.spawn(function()
		task.wait(delay)
		local value = cell.Value
		local spins = 14 + delay * 10
		for s = 1, spins do
			if session ~= token then return end
			value.Text = tostring(math.random(0, 9))
			task.wait(0.05 + (s / spins) * 0.06)
		end
		if session ~= token then return end
		value.Text = target
		value.TextColor3 = PHOSPHOR
	end)
end

local function showScore(p, token)
	hideAll()
	scoreScreen.Visible = true

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

local function showAnnounce(p, token)
	hideAll()
	if p.style == "death" then
		-- GTA-style: the world stays visible behind the card, text in blood red;
		-- then full black before the respawn, so spawn is never seen
		announceScreen.BackgroundTransparency = 0.4
		announceScreen.Line.TextColor3 = Color3.fromRGB(255, 48, 32)
		task.delay(2.5, function()
			if session == token and announceScreen.Visible then
				TweenService:Create(announceScreen, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
			end
		end)
	else
		announceScreen.BackgroundTransparency = 0
		announceScreen.Line.TextColor3 = PHOSPHOR
	end
	announceScreen.Visible = true
	announceScreen.Line.Text = ""
	task.spawn(function()
		task.wait(0.4)
		if session ~= token then return end
		typewrite(announceScreen.Line, p.text or "", 24, token)
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
	trauma = math.max(0, trauma - dt * 0.33) -- volle Ladung schuettelt ~3 Sekunden
	local mag = trauma * trauma
	local t = os.clock() * 30
	local nx = math.noise(shakeSeed, t)
	local ny = math.noise(shakeSeed + 17, t)
	local nz = math.noise(shakeSeed + 43, t)
	camera.CFrame = camera.CFrame
		* CFrame.new(nx * 1.15 * mag, ny * 1.15 * mag, 0)
		* CFrame.Angles(nx * 0.2 * mag, ny * 0.2 * mag, nz * 0.26 * mag)
end)

local function screenBlood(strength)
	local v = Instance.new("Frame")
	v.BackgroundColor3 = Color3.fromRGB(120, 8, 6)
	v.BackgroundTransparency = 0.55
	v.BorderSizePixel = 0
	v.Size = UDim2.fromScale(1, 1)
	v.ZIndex = 60
	v.Parent = machine
	TweenService:Create(v, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
	task.delay(0.6, function() v:Destroy() end)
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

-- DISPATCH ------------------------------------------------------------------

MachineState.OnClientEvent:Connect(function(p)
	if type(p) ~= "table" then return end
	if p.kind == "huntersetup" then
		setHunterSetup(sniperActive)
		return
	end
	if p.kind == "mines" then
		showMines(p.list or {})
		return
	end
	if p.kind == "role" then
		if p.role == "spectate" then
			-- toter Beobachter: feste Kamera ueber dem Feld
			local pos = Vector3.new(p.pos[1], p.pos[2], p.pos[3])
			local look = Vector3.new(p.look[1], p.look[2], p.look[3])
			spectateCF = CFrame.lookAt(pos, look)
			runnerCam = false
			return
		end
		spectateCF = nil
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
	if p.kind == "beatplan" then
		canteenPlan = { startAt = p.startAt, beats = p.beats or {} }
		canteenActive = true
		biteLockUntil = 0
		local hud = buildCanteenHud()
		for _, tk in canteenTicks do tk.frame:Destroy() end
		table.clear(canteenTicks)
		local track = hud:FindFirstChild("Track")
		for i = 1, #canteenPlan.beats do
			local t = Instance.new("Frame")
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Size = UDim2.new(0, 6, 0, 30)
			t.Position = UDim2.new(0, -100, 0.5, 0)
			t.BackgroundColor3 = Color3.fromRGB(235, 245, 238)
			t.BorderSizePixel = 0
			t.ZIndex = 3
			t.Parent = track
			canteenTicks[i] = { frame = t }
		end
		hud.Counter.Text = "00/" .. tostring(p.total or 16)
		hud.Stress.Fill.Size = UDim2.new(0, 0, 1, 0)
		hud.Visible = true
		local eb = touchControls:FindFirstChild("Btn_EAT")
		if eb and touchAllowed() then
			eb.Visible = true
			touchControls.Visible = true
		end
		if canteenLoop then canteenLoop:Disconnect() end
		canteenLoop = RunService.RenderStepped:Connect(canteenStep)
		return
	end
	if p.kind == "bite" then
		local hud = buildCanteenHud()
		if p.idx and canteenTicks[p.idx] then
			local tk = canteenTicks[p.idx]
			tk.eaten = true
			tk.frame.BackgroundColor3 = p.grade == "perfect" and Color3.fromRGB(64, 255, 120) or Color3.fromRGB(255, 196, 32)
			TweenService:Create(tk.frame, TweenInfo.new(0.3), { BackgroundTransparency = 1, Size = UDim2.new(0, 14, 0, 40) }):Play()
			task.delay(0.35, function() tk.frame.Visible = false end)
		end
		local g = hud:FindFirstChild("Grade")
		if g then
			g.Text = p.grade == "perfect" and "PERFECT" or (p.grade == "good" and "GOOD" or "MISS")
			g.TextColor3 = p.grade == "perfect" and Color3.fromRGB(64, 255, 120)
				or (p.grade == "good" and Color3.fromRGB(255, 196, 32) or Color3.fromRGB(255, 70, 60))
			g.TextTransparency = 0
			TweenService:Create(g, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
		if p.hits then hud.Counter.Text = string.format("%02d/16", p.hits) end
		TweenService:Create(hud.Stress.Fill, TweenInfo.new(0.25), { Size = UDim2.new(p.stress or 0, 0, 1, 0) }):Play()
		sfx(p.grade == "miss" and "Click" or "Submit")
		return
	end
	if p.kind == "cough" then
		biteLockUntil = os.clock() + (p.until_ or 1.2)
		local hud = buildCanteenHud()
		local g = hud:FindFirstChild("Grade")
		if g then
			g.Text = "CHOKING"
			g.TextColor3 = Color3.fromRGB(255, 48, 32)
			g.TextTransparency = 0
			TweenService:Create(g, TweenInfo.new(p.until_ or 1.2), { TextTransparency = 1 }):Play()
		end
		TweenService:Create(hud.Stress.Fill, TweenInfo.new(0.2), { Size = UDim2.new(0, 0, 1, 0) }):Play()
		sfx("Click")
		return
	end
	if p.kind == "cpend" then
		canteenActive = false
		canteenPlan = nil
		if canteenLoop then canteenLoop:Disconnect() canteenLoop = nil end
		if canteenHud then canteenHud.Visible = false end
		for _, tk in canteenTicks do tk.frame:Destroy() end
		table.clear(canteenTicks)
		local eb = touchControls:FindFirstChild("Btn_EAT")
		if eb then eb.Visible = false end
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
			TweenService:Create(faderFrame, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
			task.delay(1.45, function()
				faderFrame.Visible = false
				faderFrame.BackgroundTransparency = 0
			end)
		end
		local c = machine:FindFirstChild("CountText")
		if c then
			c.Text = tostring(p.n)
			c.Visible = true
			c.TextSize = 160
			TweenService:Create(c, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { TextSize = 120 }):Play()
		end
		return
	end
	if p.kind == "hitmark" then
		local hm = machine:FindFirstChild("HitMark")
		if hm then
			hm.Text = p.head and "BOOM HEADSHOT!" or "HIT"
			hm.TextColor3 = p.head and Color3.fromRGB(255, 48, 32) or PHOSPHOR
			hm.TextSize = p.head and 46 or 30
			hm.TextTransparency = 0
			hm.Visible = true
			TweenService:Create(hm, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
			task.delay(0.95, function() hm.Visible = false end)
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
			c.TextSize = 150
			c.TextTransparency = 0
			c.Visible = true
			TweenService:Create(c, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				TextSize = 118,
				TextTransparency = 0.08,
			}):Play()
			task.delay(0.7, function()
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
				TweenService:Create(youLabel, TweenInfo.new(0.45), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				task.delay(0.48, function()
					youLabel.Visible = false
					youLabel.TextStrokeTransparency = 0.25
				end)
			end)
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
	if p.kind == "selection" then
		showSelection(p, token)
	elseif p.kind == "info" then
		if p.id then machine:SetAttribute("TrialId", p.id) end
		showInfo(p, token)
	elseif p.kind == "status" then
		showStatus(p, token)
	elseif p.kind == "round" then
		showRound(p, token)
	elseif p.kind == "score" then
		showScore(p, token)
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
	task.spawn(function()
		task.wait(0.4)
		sfx("Warning")
		local dismissed = false
		local function dismiss()
			if dismissed then return end
			dismissed = true
			warningFrame.Visible = false
		end
		local btn = warningFrame:FindFirstChild("Btn_CONTINUE")
		if btn then
			btn.Activated:Connect(function()
				sfx("Click")
				dismiss()
			end)
		end
		task.delay(6.5, dismiss)
	end)
end

if settingsPanel then
	local rows = {
		{ frame = settingsPanel:FindFirstChild("Row_UISOUND"), key = "UiSound" },
		{ frame = settingsPanel:FindFirstChild("Row_MUSIC"), key = "Music" },
		{ frame = settingsPanel:FindFirstChild("Row_REDUCEFLICKER"), key = "ReduceFlicker" },
	}
	local function render()
		for _, r in rows do
			if r.frame then
				r.frame.Check.Fill.Visible = uiSettings[r.key] == true
			end
		end
	end
	render()
	for _, r in rows do
		if r.frame then
			r.frame.Hit.Activated:Connect(function()
				uiSettings[r.key] = not uiSettings[r.key]
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
			-- The two release trials show only their reference-supported controls.
			return machine:GetAttribute("TrialId") == "tablemanners"
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
				TweenService:Create(line, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				task.delay(0.45, function()
					if noticeSeq == mine then gui.Enabled = false end
				end)
			end)
		end)
	else
		warn("[Kenopsia] LobbyError remote missing - server rejections will be silent")
	end
end

print("[Kenopsia] client online")
