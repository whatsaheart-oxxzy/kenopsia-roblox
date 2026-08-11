--!nonstrict
-- Platform-aware layout for the KenopsiaMachine GUI.
-- The machine screens were authored against a ~710px-tall window with pixel
-- offsets; this rescales each screen's coordinate system per platform so the
-- design keeps its proportions on phones, desktops and consoles.
--   Mobile  : content scaled down to fit small viewports, touch controls on
--   Desktop : near-authored scale, touch controls follow touch availability
--   Console : 10-foot scale-up, gamepad focus driven, touch controls off
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local machine = playerGui:WaitForChild("KenopsiaMachine")

local REF_HEIGHT = 710 -- the window height the screens were authored against

-- fullscreen screens: size-compensated so scale-relative children keep their
-- share of the screen while pixel offsets shrink with the platform scale
local FULLSCREEN = { "Selection", "Info", "Status", "RoundCard", "Briefing", "Score", "Announce", "Warning" }
-- centered pixel-sized elements: plain scale, anchor keeps them centered
local CENTERED = { "SettingsPanel", "CountText", "HipCross", "HitMark" }
-- untouched: Fader, Scope, JoinCover (must cover the whole screen),
-- TouchControls (finger-sized by design)

local function detectPlatform()
	local forced = machine:GetAttribute("ForcePlatform")
	if forced == "Mobile" or forced == "Console" or forced == "Desktop" then
		return forced
	end
	if GuiService:IsTenFootInterface() then return "Console" end
	local touch = UserInputService.TouchEnabled
	local pointer = UserInputService.MouseEnabled or UserInputService.KeyboardEnabled
	if touch and not pointer then return "Mobile" end
	-- Studio device emulation keeps the mouse alive; a small touch viewport
	-- is a phone regardless
	if touch then
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		if math.min(vp.X, vp.Y) < 500 then return "Mobile" end
	end
	return "Desktop"
end

local function platformScale(platform)
	local cam = workspace.CurrentCamera
	local vh = (cam and cam.ViewportSize.Y or REF_HEIGHT)
	local s = vh / REF_HEIGHT
	if platform == "Mobile" then
		return math.clamp(s, 0.42, 0.85)
	elseif platform == "Console" then
		return math.clamp(s * 1.1, 1, 1.4)
	end
	return math.clamp(s, 0.8, 1.3)
end

local function scaleObject(obj, s, fullscreen)
	local ui = obj:FindFirstChild("KenopsiaScale")
	if not ui then
		ui = Instance.new("UIScale")
		ui.Name = "KenopsiaScale"
		ui.Parent = obj
	end
	ui.Scale = s
	if fullscreen then
		-- inverse-sized frame + UIScale nets a fullscreen render in which
		-- scale-relative children are untouched and pixel offsets shrink
		obj.AnchorPoint = Vector2.new(0, 0)
		obj.Position = UDim2.new(0, 0, 0, 0)
		obj.Size = UDim2.fromScale(1 / s, 1 / s)
	end
end

local currentPlatform = detectPlatform()

-- the CONTROLS window speaks each platform's input language AND the language
-- of the trial the roulette picked (New Minigame, New Moves)
local TRIAL_TEXT = {
	birdhunt = {
		sec1 = "RUNNERS:", sec2 = "HUNTER:",
		Desktop = {
			Row1 = "Move",
			Row1b = "Crouch [Ctrl]",
			Row2 = "Aim + Shoot",
			Row3 = "Scope [x2]",
			icons = true,
		},
		Mobile = {
			Row1 = "Stick  Move",
			Row1b = "CROUCH button",
			Row2 = "Drag  Aim  +  FIRE button",
			Row3 = "SCOPE button [x2]",
			icons = false,
		},
		Console = {
			Row1 = "LS  Move",
			Row1b = "B  Crouch",
			Row2 = "RS  Aim  +  RT  Shoot",
			Row3 = "LT  Scope [x2]    Y  Zoom",
			icons = false,
		},
		scoring = {
			"Headshot     instant  +100",
			"Body shot    2 to drop",
			"Winged       +15 / kill +60",
			"Escape       +100 & time",
			"Timeout      distance only",
		},
	},
	minefield = {
		sec1 = "RUNNERS:", sec2 = "SONAR:",
		Desktop = {
			Row1 = "Move",
			Row1b = "Use sonar [HOLD]",
			Row2 = "",
			Row3 = "",
			icons = true, noteRows = { Row2 = true, Row3 = true },
		},
		Mobile = {
			Row1 = "Move",
			Row1b = "Use sonar [HOLD]",
			Row2 = "",
			Row3 = "",
			icons = false,
		},
		Console = {
			Row1 = "Move",
			Row1b = "Use sonar [HOLD Y]",
			Row2 = "",
			Row3 = "",
			icons = false,
		},
		scoring = {},
	},
	tablemanners = {
		sec1 = "DINERS:", sec2 = "TIMING:",
		Desktop = {
			Row1 = "Seated - no moving",
			Row1b = "Eat [E] on the beat",
			Row2 = "Perfect  within 70 ms",
			Row3 = "Good  within 150 ms",
			icons = true, noteRows = { Row1 = true, Row2 = true, Row3 = true },
		},
		Mobile = {
			Row1 = "Seated - no moving",
			Row1b = "EAT button on the beat",
			Row2 = "Perfect  within 70 ms",
			Row3 = "Good  within 150 ms",
			icons = false,
		},
		Console = {
			Row1 = "Seated - no moving",
			Row1b = "A  Eat on the beat",
			Row2 = "Perfect  within 70 ms",
			Row3 = "Good  within 150 ms",
			icons = false,
		},
		scoring = {
			"Bite          +8",
			"Perfect       +4 bonus",
			"Miss          -2 / 3 = choke",
			"All 16        +25 & tempo",
			"Last place    disposal",
		},
	},
}

local function applyControlsText()
	local info = machine:FindFirstChild("Info")
	local cw = info and info:FindFirstChild("ControlsWindow")
	if not cw then return end
	local trial = TRIAL_TEXT[machine:GetAttribute("TrialId")] or TRIAL_TEXT.birdhunt
	local t = trial[currentPlatform] or trial.Desktop
	for _, rowName in ipairs({ "Row1", "Row1b", "Row2", "Row3" }) do
		local row = cw:FindFirstChild(rowName)
		local label = row and row:FindFirstChild("Text")
		local showIcon = t.icons and not (t.noteRows and t.noteRows[rowName])
		if label then
			label.Text = t[rowName] or label.Text
			label.Position = showIcon and UDim2.new(0, 28, 0, 0) or UDim2.new(0, 0, 0, 0)
			label.Size = showIcon and UDim2.new(1, -28, 1, 0) or UDim2.new(1, 0, 1, 0)
		end
		local icon = row and row:FindFirstChild("MouseIcon")
		if icon then icon.Visible = showIcon end
	end
	local sec1 = cw:FindFirstChild("SecRunners")
	if sec1 then sec1.Text = trial.sec1 end
	local sec2 = cw:FindFirstChild("SecSniper")
	if sec2 then sec2.Text = trial.sec2 end
	local p2 = cw:FindFirstChild("Page2")
	if p2 then
		for i = 1, 5 do
			local r = p2:FindFirstChild("R" .. i)
			if r then r.Text = trial.scoring[i] or "" end
		end
	end
end
machine:GetAttributeChangedSignal("TrialId"):Connect(applyControlsText)

local focusScreen -- defined below; apply() retries focus through it

-- console: an A-button glyph rides the screen's primary control
local function applyButtonHints()
	local show = currentPlatform == "Console"
	local targets = {
		machine:FindFirstChild("Info") and machine.Info:FindFirstChild("Btn_READY"),
		machine:FindFirstChild("Warning") and machine.Warning:FindFirstChild("Btn_CONTINUE", true),
	}
	for _, btn in ipairs(targets) do
		if btn then
			local glyph = btn:FindFirstChild("PadHint")
			if not glyph then
				glyph = Instance.new("ImageLabel")
				glyph.Name = "PadHint"
				glyph.BackgroundTransparency = 1
				glyph.AnchorPoint = Vector2.new(0, 0.5)
				glyph.Position = UDim2.new(0, 12, 0.5, 0)
				glyph.Size = UDim2.new(0, 30, 0, 30)
				glyph.Image = UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonA)
				glyph.Parent = btn
			end
			glyph.Visible = show
		end
	end
end

local function apply()
	local s = platformScale(currentPlatform)
	for _, name in ipairs(FULLSCREEN) do
		local obj = machine:FindFirstChild(name)
		if obj then scaleObject(obj, s, true) end
	end
	for _, name in ipairs(CENTERED) do
		local obj = machine:FindFirstChild(name)
		if obj then scaleObject(obj, s, false) end
	end
	applyControlsText()
	applyButtonHints()
	machine:SetAttribute("Platform", currentPlatform)
	machine:SetAttribute("LayoutScale", s)
	-- the boot viewport can be a placeholder size; once layout settles,
	-- retake gamepad focus if nothing is selected yet
	if currentPlatform == "Console" and not GuiService.SelectedObject then
		task.defer(function()
			for _, name in ipairs({ "Warning", "SettingsPanel", "Info" }) do
				local screen = machine:FindFirstChild(name)
				if screen and screen.Visible and focusScreen then
					focusScreen(screen)
					return
				end
			end
		end)
	end
end

apply()

-- rotation / window changes
local viewportConnection
local function bindCamera(camera)
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
end
bindCamera(workspace.CurrentCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(workspace.CurrentCamera)
	apply()
end)
machine:GetAttributeChangedSignal("ForcePlatform"):Connect(function()
	currentPlatform = detectPlatform()
	apply()
end)

-- input mode can change mid-session (tablet + bluetooth keyboard, etc.)
UserInputService.LastInputTypeChanged:Connect(function()
	local p = detectPlatform()
	if p ~= currentPlatform then
		currentPlatform = p
		apply()
	end
end)

-- CONSOLE: drive gamepad focus onto each screen's primary control ----------
local PRIMARY = {
	Info = "Btn_READY",
	Warning = "Btn_CONTINUE",
}

function focusScreen(screen)
	if currentPlatform ~= "Console" then return end
	local primaryName = PRIMARY[screen.Name]
	local best, bestArea
	for _, d in ipairs(screen:GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and d.Selectable then
			if primaryName and d.Name == primaryName then
				best = d
				break
			end
			-- no named primary hit yet: prefer the largest button on screen
			local a = d.AbsoluteSize.X * d.AbsoluteSize.Y
			if not bestArea or a > bestArea then
				best, bestArea = d, a
			end
		end
	end
	if best then
		-- a forced-console test on a tiny window can leave the target
		-- off-screen, which the engine rejects with a console warning; on a
		-- real console viewport the primary is always on-screen
		GuiService.SelectedObject = best
	end
end

for _, name in ipairs({ "Info", "Warning", "SettingsPanel" }) do
	local screen = machine:FindFirstChild(name)
	if screen then
		screen:GetPropertyChangedSignal("Visible"):Connect(function()
			if screen.Visible then
				task.defer(focusScreen, screen)
			elseif GuiService.SelectedObject
				and GuiService.SelectedObject:IsDescendantOf(screen) then
				GuiService.SelectedObject = nil
			end
		end)
		if screen.Visible then task.defer(focusScreen, screen) end
	end
end

print(("[MachineLayout] %s, scale %.2f"):format(currentPlatform, machine:GetAttribute("LayoutScale")))
