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

-- P2.4 (23.08.2026): action -> key / button glyphs per device and the
-- input-mode hysteresis live in the pure Glyphs module; the hold comes from
-- the feel bible.
local Glyphs = require(script.Parent:WaitForChild("Glyphs", 10)
	or error("[MachineLayout] Glyphs module missing (push StarterPlayerScripts/Glyphs first)"))
local Feel = require(game:GetService("ReplicatedStorage"):WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("FeelConfig"))
local glyphResolver = Glyphs.robloxResolver(UserInputService)
local inputTracker = Glyphs.newInputTracker(Feel.Input.GamepadHoldSeconds)
inputTracker.feed(UserInputService:GetLastInputType().Name, os.clock())

-- fullscreen screens: size-compensated so scale-relative children keep their
-- share of the screen while pixel offsets shrink with the platform scale
local FULLSCREEN = { "Selection", "Info", "Status", "RoundCard", "Briefing", "Score", "Announce", "Warning" }
-- centered pixel-sized elements: plain scale, anchor keeps them centered
local CENTERED = { "SettingsPanel", "CountText", "HipCross", "HitMark" }
-- untouched: Fader, Scope, JoinCover (must cover the whole screen),
-- TouchControls (finger-sized by design)

local function detectPlatform()
	local forced = machine:GetAttribute("ForcePlatform")
	if forced == "Mobile" or forced == "Tablet" or forced == "Console" or forced == "Desktop" then
		return forced
	end
	-- P2.1 (22.08.2026): compose the signal instead of trusting one API.
	-- Gamepad-only input is a console whatever the viewport; touch without a
	-- pointer is a phone or a tablet, told apart by the short axis and the
	-- aspect (an iPad is 4:3 and ~800 pt tall, a phone is 19.5:9 and < 500).
	-- P2.4: Console is a COMPOSED signal (Glyphs.isConsole): the ten-foot
	-- flag, OR a gamepad with no keyboard / mouse / touch, OR the gamepad has
	-- been the last input type for > Feel.Input.GamepadHoldSeconds.
	local touch = UserInputService.TouchEnabled
	local keyboard, mouse = UserInputService.KeyboardEnabled, UserInputService.MouseEnabled
	local pointer = mouse or keyboard
	local gamepad = UserInputService.GamepadEnabled
	if Glyphs.isConsole({ tenFoot = GuiService:IsTenFootInterface(), gamepad = gamepad,
		keyboard = keyboard, mouse = mouse, touch = touch, mode = inputTracker.mode }) then
		return "Console"
	end
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local short = math.min(vp.X, vp.Y)
	local aspect = math.max(vp.X, vp.Y) / math.max(1, short)
	if touch and (not pointer or short < 900) then
		-- Studio device emulation keeps the mouse alive; the viewport decides.
		if short < 500 then return "Mobile" end
		if aspect < 1.6 then return "Tablet" end
		return short < 700 and "Mobile" or "Tablet"
	end
	return "Desktop"
end

local function platformScale(platform)
	local cam = workspace.CurrentCamera
	local vh = (cam and cam.ViewportSize.Y or REF_HEIGHT)
	local s = vh / REF_HEIGHT
	if platform == "Mobile" then
		-- 0.42 made a 128-px tile 54 px and a 26x6 bracket sub-pixel; 0.55 is
		-- the floor at which the roulette and the READY button stay tappable.
		return math.clamp(s, 0.62, 0.85)
	elseif platform == "Tablet" then
		return math.clamp(s, 0.7, 1.0)
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

-- P2.1 text floor (22.08.2026). Pixel offsets shrink with the platform scale,
-- so a 13-px label at 0.55 rendered 7 px on a phone (16 labels on the Info
-- screen alone). Every label keeps its authored size (remembered once in an
-- attribute) and is raised so it renders at >= MIN_TEXT_PX; on desktop and
-- console the floor is never reached, so nothing changes there.
local MIN_TEXT_PX = 10
-- Console is read from 8-10 feet: Roblox's console guidelines want body text
-- around 22 px and up, so the floor is higher there.
local MIN_TEXT_PX_CONSOLE = 22
local function applyTextFloor(root, s)
	local minPx = currentPlatform == "Console" and MIN_TEXT_PX_CONSOLE or MIN_TEXT_PX
	local floor = math.ceil(minPx / math.max(s, 0.01))
	for _, d in ipairs(root:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and not d.TextScaled then
			local authored = d:GetAttribute("AuthoredTextSize")
			if not authored then
				authored = d.TextSize
				d:SetAttribute("AuthoredTextSize", authored)
			end
			d.TextSize = math.max(authored, floor)
		end
	end
end

-- the CONTROLS window speaks each platform's input language AND the language
-- of the trial the roulette picked (New Minigame, New Moves)
local TRIAL_TEXT = {
	birdhunt = {
		sec1 = "RUNNERS:", sec2 = "HUNTER:",
		Desktop = {
			Row1 = "Move  [{Move}]",
			Row1b = "Crouch [{Crouch}]",
			Row2 = "Aim + Shoot [{Fire}]",
			Row3 = "Scope [{Scope}]  x2 / x4 [{Zoom}]",
			icons = true,
		},
		Mobile = {
			Row1 = "{Move}  Move",
			Row1b = "{Crouch} button",
			Row2 = "{Aim}  Aim  +  {Fire} button",
			Row3 = "{Scope} button [x2]",
			icons = false,
		},
		Console = {
			Row1 = "{Move}  Move",
			Row1b = "{Crouch}  Crouch",
			Row2 = "{Aim}  Aim  +  {Fire}  Shoot",
			Row3 = "{Scope}  Scope [x2]    {Zoom}  Zoom",
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
			Row1 = "Move  [{Move}]",
			Row1b = "Use sonar [HOLD {Scan}]",
			Row2 = "",
			Row3 = "",
			icons = true, noteRows = { Row2 = true, Row3 = true },
		},
		Mobile = {
			Row1 = "{Move}  Move",
			Row1b = "Use sonar [HOLD {Scan}]",
			Row2 = "",
			Row3 = "",
			icons = false,
		},
		Console = {
			Row1 = "{Move}  Move",
			Row1b = "Use sonar [HOLD {Scan}]",
			Row2 = "",
			Row3 = "",
			icons = false,
		},
		scoring = {},
	},
	-- Keyed "canteen". The key IS the lookup: this table used to be keyed on the
	-- reference game's name for the minigame, which is not what the server sets
	-- TrialId to -- so it matched nothing and fell through to TRIAL_TEXT.birdhunt.
	-- Players would have been shown the SNIPER controls while sitting at the
	-- dinner table. Renaming it also clears the last of that name from shipped
	-- source (REQ-IP-01).
	canteen = {
		sec1 = "DINERS:", sec2 = "OBSERVER:",
		Desktop = {
			Row1 = "Seated - no moving",
			Row1b = "Load fork [{Load}]",
			Row2 = "Swallow [{Swallow}]",
			Row3 = "Never swallow while watched",
			icons = true, noteRows = { Row1 = true, Row3 = true },
		},
		Mobile = {
			Row1 = "Seated - no moving",
			Row1b = "{Load} button loads",
			Row2 = "{Swallow} button swallows",
			Row3 = "Never swallow while watched",
			icons = false,
		},
		Console = {
			Row1 = "Seated - no moving",
			Row1b = "{Load}  Load fork",
			Row2 = "{Swallow}  Swallow",
			Row3 = "Never swallow while watched",
			icons = false,
		},
		scoring = {
			"Plate         16 rations",
			"Fork          holds 4",
			"Loading       always safe",
			"Swallowing    only unobserved",
			"Finish first  ranks highest",
		},
	},
	-- MP-05 D15: the neutral fallback. It used to be `birdhunt`, which showed
	-- the SNIPER controls for any id without a row. New trials never need a row
	-- here: their text ships in TrialClients/<id>.luau as `controlsText`.
	default = {
		sec1 = "PLAYERS:", sec2 = "RULE:",
		Desktop = { Row1 = "Move  [{Move}]", Row1b = "Follow the machine", Row2 = "", Row3 = "", icons = true,
			noteRows = { Row1b = true, Row2 = true, Row3 = true } },
		Mobile = { Row1 = "{Move}  Move", Row1b = "Follow the machine", Row2 = "", Row3 = "", icons = false },
		Console = { Row1 = "{Move}  Move", Row1b = "Follow the machine", Row2 = "", Row3 = "", icons = false },
		scoring = {},
	},
}

-- MP-05 D15: a TrialClients/<id> module may export
--   controlsText = { sec1?, sec2?, lines = {Row1, Row1b, Row2, Row3} | Desktop/Mobile/Console = {...4 lines...}, scoring? }
-- This turns that into the TRIAL_TEXT row shape above. Cached per id; the
-- require is pcall'd so a broken module falls back to TRIAL_TEXT.default.
local trialClientsFolder = script.Parent:FindFirstChild("TrialClients")
local controlsTextCache = {}
local function fromControlsText(ct)
	local function rows(list)
		list = list or ct.lines or {}
		return {
			Row1 = list[1] or "", Row1b = list[2] or "", Row2 = list[3] or "", Row3 = list[4] or "",
			icons = ct.icons == true,
		}
	end
	return {
		sec1 = ct.sec1 or "PLAYERS:", sec2 = ct.sec2 or "RULE:",
		Desktop = rows(ct.Desktop), Mobile = rows(ct.Mobile), Console = rows(ct.Console),
		scoring = ct.scoring or {},
	}
end
local function moduleControlsText(trialId)
	if type(trialId) ~= "string" or trialId == "" then return nil end
	if controlsTextCache[trialId] ~= nil then return controlsTextCache[trialId] or nil end
	local ms = trialClientsFolder and trialClientsFolder:FindFirstChild(trialId)
	local result = false
	if ms then
		local ok, mod = pcall(require, ms)
		if ok and type(mod) == "table" and type(mod.controlsText) == "table" then
			result = fromControlsText(mod.controlsText)
		end
	end
	controlsTextCache[trialId] = result
	return result or nil
end

-- P2.4: a controls line carries {Action} tokens (Glyphs.Actions). Desktop and
-- touch lines stay text (layout-correct key strings / pad labels). On console
-- a line with button images becomes a GlyphRow: a horizontal list of text
-- segments and the platform's own button images (GetImageForKeyCode), sized
-- to the row's (floored) text; the plain label is blanked while it shows.
local function renderGlyphRow(label, line)
	local segs = Glyphs.segments(line, Glyphs.platformFor(currentPlatform), glyphResolver)
	local row = label:FindFirstChild("GlyphRow")
	if not Glyphs.hasImage(segs) then
		if row then row:Destroy() end
		label.Text = Glyphs.join(segs)
		return
	end
	label.Text = ""
	if row then
		row:ClearAllChildren()
	else
		row = Instance.new("Frame")
		row.Name = "GlyphRow"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 1)
		row.ZIndex = label.ZIndex
		row.Parent = label
	end
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = row
	local px = label.TextSize + 6
	for i, s in ipairs(segs) do
		local node
		if s.image then
			node = Instance.new("ImageLabel")
			node.Image = s.image
			node.ScaleType = Enum.ScaleType.Fit
			node.Size = UDim2.fromOffset(px, px)
		else
			node = Instance.new("TextLabel")
			node.Font = label.Font
			node.TextSize = label.TextSize
			node.TextColor3 = label.TextColor3
			node.TextXAlignment = Enum.TextXAlignment.Left
			node.Text = s.text
			node.AutomaticSize = Enum.AutomaticSize.X
			node.Size = UDim2.new(0, 0, 1, 0)
		end
		node.Name = "Seg" .. i
		node.BackgroundTransparency = 1
		node.BorderSizePixel = 0
		node.LayoutOrder = i
		node.ZIndex = label.ZIndex
		node.Parent = row
	end
end

local function applyControlsText()
	local info = machine:FindFirstChild("Info")
	local cw = info and info:FindFirstChild("ControlsWindow")
	if not cw then return end
	local trialId = machine:GetAttribute("TrialId")
	local trial = moduleControlsText(trialId) or TRIAL_TEXT[trialId] or TRIAL_TEXT.default
	local t = trial[currentPlatform] or (currentPlatform == "Tablet" and trial.Mobile) or trial.Desktop
	for _, rowName in ipairs({ "Row1", "Row1b", "Row2", "Row3" }) do
		local row = cw:FindFirstChild(rowName)
		local label = row and row:FindFirstChild("Text")
		local showIcon = t.icons and not (t.noteRows and t.noteRows[rowName])
		if label then
			renderGlyphRow(label, t[rowName] or label.Text)
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

-- P2.4: the panels that take input, in focus priority (a modal first). Each
-- is a SelectionGroup with every SelectionBehavior edge = Stop, so the d-pad
-- / stick can never leave the panel it is in; focus moves between panels only
-- through focusScreen. HunterLookSetup is built by KenopsiaClient at boot
-- and adopted when it appears.
local GROUPS = { "Warning", "SettingsPanel", "HunterLookSetup", "Briefing", "Info" }
-- 24.08.2026 (console pass): at join the READY button is briefly
-- Selectable=false (no roster yet), so the first focus lands on SETTINGS and
-- stays there. When READY becomes selectable while Info is up, take the
-- focus back to it.
task.defer(function()
	local info = machine:WaitForChild("Info", 10)
	local ready = info and info:WaitForChild("Btn_READY", 10)
	if not ready then return end
	local function reclaim()
		if currentPlatform ~= "Console" or not ready.Selectable then return end
		if not info.Visible then return end
		local sel = GuiService.SelectedObject
		if sel == nil or (sel ~= ready and sel:IsDescendantOf(info)) then
			GuiService.SelectedObject = ready
		end
	end
	ready:GetPropertyChangedSignal("Selectable"):Connect(reclaim)
	-- the screen usually becomes visible AFTER the selectable flip, so the
	-- show itself re-checks too (short delay: focusScreen runs on the same
	-- signal and must lose this race, not win it).
	info:GetPropertyChangedSignal("Visible"):Connect(function()
		if info.Visible then task.delay(0.3, reclaim) end
	end)
	reclaim()
	task.delay(3, reclaim)
end)

-- focus the first visible group panel (console only; nothing if none is up)
local function focusAny()
	if currentPlatform ~= "Console" or not focusScreen then return end
	for _, name in ipairs(GROUPS) do
		local screen = machine:FindFirstChild(name)
		if screen and screen.Visible then
			focusScreen(screen)
			return
		end
	end
end

-- console: the gamepad focus ring is the machine's own phosphor frame, not
-- Roblox's default blue rectangle (P2.1, 22.08.2026). PlayerGui's
-- SelectionImageObject applies to every selectable element.
local function applyFocusRing()
	local ring = playerGui:FindFirstChild("KenopsiaFocusRing")
	if currentPlatform ~= "Console" then
		if playerGui.SelectionImageObject == ring then playerGui.SelectionImageObject = nil end
		return
	end
	if not ring then
		ring = Instance.new("Frame")
		ring.Name = "KenopsiaFocusRing"
		ring.BackgroundTransparency = 1
		ring.BorderSizePixel = 0
		ring.Size = UDim2.new(1, 12, 1, 12)
		ring.Position = UDim2.new(0, -6, 0, -6)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(120, 255, 170)
		stroke.Thickness = 3
		stroke.Parent = ring
		-- the four corner ticks the roulette tiles already use
		for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
			local tick = Instance.new("Frame")
			tick.BackgroundColor3 = Color3.fromRGB(120, 255, 170)
			tick.BorderSizePixel = 0
			tick.AnchorPoint = Vector2.new(c[1], c[2])
			tick.Position = UDim2.new(c[1], 0, c[2], 0)
			tick.Size = UDim2.new(0, 14, 0, 6)
			tick.Parent = ring
		end
		ring.Parent = playerGui
	end
	playerGui.SelectionImageObject = ring
end

-- console: the confirm-button glyph rides each panel's primary control
-- (P2.4: resolved through Glyphs so the image is the platform's own; the
-- settings CLOSE button carries one too).
local function applyButtonHints()
	local show = currentPlatform == "Console"
	local targets = {
		machine:FindFirstChild("Info") and machine.Info:FindFirstChild("Btn_READY"),
		machine:FindFirstChild("Warning") and machine.Warning:FindFirstChild("Btn_CONTINUE", true),
		machine:FindFirstChild("SettingsPanel") and machine.SettingsPanel:FindFirstChild("Btn_CLOSE"),
	}
	local confirm = Glyphs.glyph("Confirm", "Console", glyphResolver)[1]
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
				glyph.Parent = btn
			end
			glyph.Image = confirm.image or ""
			glyph.Visible = show and confirm.image ~= nil
		end
	end
end

local viewportApplyPending = false
local function apply()
	local s = platformScale(currentPlatform)
	for _, name in ipairs(FULLSCREEN) do
		local obj = machine:FindFirstChild(name)
		if obj then
			scaleObject(obj, s, true)
			applyTextFloor(obj, s)
		end
	end
	for _, name in ipairs(CENTERED) do
		local obj = machine:FindFirstChild(name)
		if obj then
			scaleObject(obj, s, false)
			applyTextFloor(obj, s)
		end
	end
	-- P2.1: the Info text column is authored at x = 0.13 of the screen, which on
	-- a phone lands under the SelIcon brackets (15 + 147 px). Keep the column
	-- at least 12 px right of the icon, in the screen's own (pre-scale) pixels.
	local info = machine:FindFirstChild("Info")
	if info then
		local cam = workspace.CurrentCamera
		local localW = (cam and cam.ViewportSize.X or 1920) / s
		local col = math.max(0.13 * localW, 15 + 147 + 12)
		for _, n in ipairs({ "TopTicker", "NextLabel", "ControlsWindow" }) do
			local c = info:FindFirstChild(n)
			if c then c.Position = UDim2.new(0, col, c.Position.Y.Scale, c.Position.Y.Offset) end
		end
		-- ... and the CONTROLS window must end before the Roster starts (on a 4:3
		-- tablet its authored 45.5 % ran into the roster's checkboxes).
		local cw, roster = info:FindFirstChild("ControlsWindow"), info:FindFirstChild("Roster")
		if cw and roster then
			local authoredW = cw:GetAttribute("AuthoredWidthScale")
			if not authoredW then
				authoredW = cw.Size.X.Scale
				cw:SetAttribute("AuthoredWidthScale", authoredW)
			end
			local rosterX = roster.Position.X.Scale * localW + roster.Position.X.Offset
			local w = math.min(authoredW * localW, rosterX - col - 16)
			cw.Size = UDim2.new(0, math.max(200, w), cw.Size.Y.Scale, cw.Size.Y.Offset)
		end
	end
	applyControlsText()
	applyButtonHints()
	applyFocusRing()
	machine:SetAttribute("Platform", currentPlatform)
	machine:SetAttribute("LayoutScale", s)
	-- the boot viewport can be a placeholder size; once layout settles,
	-- retake gamepad focus if nothing is selected yet (P2.4: also the moment
	-- a gamepad becomes the input mode -- apply() runs on that flip too)
	if currentPlatform == "Console" and not GuiService.SelectedObject then
		task.defer(focusAny)
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
		-- #50: a window drag fires ViewportSize every frame; run the (full
		-- tree walk) apply at most every 0.15 s, once more after it settles.
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if viewportApplyPending then return end
			viewportApplyPending = true
			task.delay(0.15, function()
				viewportApplyPending = false
				apply()
			end)
		end)
	end
end
bindCamera(workspace.CurrentCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(workspace.CurrentCamera)
	apply()
end)
-- P2.4: one re-detect path. Leaving Console drops the gamepad selection so
-- no phosphor ring is left on a mouse-driven screen; entering it re-focuses
-- through apply().
local function refreshPlatform()
	local p = detectPlatform()
	if p == currentPlatform then return end
	local wasConsole = currentPlatform == "Console"
	currentPlatform = p
	apply()
	if wasConsole and p ~= "Console" and GuiService.SelectedObject then
		GuiService.SelectedObject = nil
	end
end
machine:GetAttributeChangedSignal("ForcePlatform"):Connect(refreshPlatform)

-- input mode can change mid-session (tablet + bluetooth keyboard, a gamepad
-- picked up at a desk, ...). P2.4: the Glyphs tracker carries the hysteresis
-- -- a click / key / touch switches at once, a gamepad only after it has been
-- the last input type for Feel.Input.GamepadHoldSeconds (a timer re-checks
-- once the hold can have elapsed), a mouse move alone changes nothing.
UserInputService.LastInputTypeChanged:Connect(function(inputType)
	local now = os.clock()
	inputTracker.feed(inputType.Name, now)
	local wait = inputTracker.pending(now)
	if wait then
		task.delay(wait + 0.05, function()
			inputTracker.evaluate(os.clock())
			refreshPlatform()
		end)
	end
	refreshPlatform()
end)
do
	local wait = inputTracker.pending(os.clock())
	if wait then
		task.delay(wait + 0.05, function()
			inputTracker.evaluate(os.clock())
			refreshPlatform()
		end)
	end
end

-- CONSOLE: drive gamepad focus onto each screen's primary control ----------
-- P2.4: a path below the panel (dots), walked by findPath.
local PRIMARY = {
	Info = "Btn_READY",
	Warning = "Btn_CONTINUE",
	SettingsPanel = "Row_UISOUND.Hit",
	HunterLookSetup = "Track",
	Briefing = "NavBar.ArrowR.Hit",
}
local function findPath(root, path)
	local obj = root
	for part in string.gmatch(path, "[^%.]+") do
		obj = obj and obj:FindFirstChild(part)
	end
	return obj
end

function focusScreen(screen)
	if currentPlatform ~= "Console" or not screen.Visible then return end
	-- 1) the named primary
	local primary = findPath(screen, PRIMARY[screen.Name] or "")
	if primary and primary:IsA("GuiObject") and primary.Visible and primary.Selectable then
		GuiService.SelectedObject = primary
		return
	end
	-- 2) the engine's pick inside the SelectionGroup (lowest SelectionOrder)
	pcall(function() GuiService:Select(screen) end)
	local sel = GuiService.SelectedObject
	if sel and sel:IsDescendantOf(screen) then return end
	-- 3) the largest visible button on the panel
	local best, bestArea
	for _, d in ipairs(screen:GetDescendants()) do
		if d:IsA("TextButton") and d.Visible and d.Selectable then
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

-- P2.4: SelectionGroup + Stop on all four edges (GuiBase2d.SelectionGroup is
-- the current API; GuiService:AddSelectionParent is deprecated in its favour
-- and the per-object NextSelection* links would need every button wired).
-- Shown -> focus its primary; hidden -> drop the selection and fall back to
-- the next visible panel (closing Settings lands back on Info).
local wired = {}
local function wireGroup(screen)
	if wired[screen] then return end
	wired[screen] = true
	screen.SelectionGroup = true
	screen.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	screen.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	screen.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	screen.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	screen:GetPropertyChangedSignal("Visible"):Connect(function()
		if screen.Visible then
			task.defer(focusScreen, screen)
		else
			local sel = GuiService.SelectedObject
			if sel and sel:IsDescendantOf(screen) then GuiService.SelectedObject = nil end
			task.defer(focusAny)
		end
	end)
	if screen.Visible then task.defer(focusScreen, screen) end
end
for _, name in ipairs(GROUPS) do
	local screen = machine:FindFirstChild(name)
	if screen then wireGroup(screen) end
end
machine.ChildAdded:Connect(function(child)
	if table.find(GROUPS, child.Name) and child:IsA("GuiObject") then wireGroup(child) end
end)

print(("[MachineLayout] %s, scale %.2f"):format(currentPlatform, machine:GetAttribute("LayoutScale")))
