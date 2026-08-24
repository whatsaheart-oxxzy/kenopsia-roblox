--!nonstrict
-- MENU OVERLAY (Gate M1 §3).
--
-- The flat 2D layer that sits over the 3D street scene: the landing screen,
-- Settings, Credits, and the navigation stack that connects them. It owns no
-- camera, no character and no session logic -- START only asks
-- MenuSceneController to move, and the session wall is SessionWallController's.
--
-- Built entirely in code rather than authored in StarterGui, so the whole
-- surface is source-controlled and diffable. Nothing here reads or writes the
-- old CRT `Monitor` tree.
--
-- Navigation is an explicit stack. BACK, Escape and gamepad B always return to
-- the state actually pushed before this one, never to a hardcoded "Landing" --
-- that is the specific bug the stack exists to prevent.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local SoundBank = require(UI.SoundBank)
local GlitchTitle = require(UI.GlitchTitle)

local player = Players.LocalPlayer

local MenuOverlayController = {}
MenuOverlayController.__index = MenuOverlayController

local GUI_NAME = "KenopsiaLanding"
local BACK_ACTION = "KenopsiaMenuBack"

local CONTENT_NOTICE = "STYLIZED VIOLENCE · FLASHING IMAGES"

-- BUILDERS -------------------------------------------------------------------

local function flatPanel(parent, name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Theme.Street.Asphalt
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.StreetRadius.Soft)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = Theme.Street.Sage
	s.Thickness = Theme.StreetStroke.Hairline
	s.Transparency = 0.45
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	return f
end

-- Offset drop shadow as a solid frame behind the target. No blur, no gradient:
-- the style is hard-edged, and a real shadow object would cost a second render
-- pass for no visual gain at this scale.
local function dropShadow(target, offset)
	local sh = Instance.new("Frame")
	sh.Name = "Shadow"
	sh.BackgroundColor3 = Theme.Street.Ink
	sh.BackgroundTransparency = 0.35
	sh.BorderSizePixel = 0
	sh.ZIndex = target.ZIndex - 1
	sh.Size = target.Size
	sh.Position = UDim2.new(
		target.Position.X.Scale, target.Position.X.Offset + offset,
		target.Position.Y.Scale, target.Position.Y.Offset + offset)
	sh.AnchorPoint = target.AnchorPoint
	sh.Parent = target.Parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.StreetRadius.Soft)
	c.Parent = sh
	return sh
end

local function actionButton(parent, name, text, order)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BackgroundColor3 = Theme.Street.Asphalt
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, Theme.Touch.Action)
	b.LayoutOrder = order
	b.Font = Theme.TitleFont
	b.Text = text
	b.TextSize = 30
	b.TextColor3 = Theme.Street.OffWhite
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Parent = parent

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = b

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.StreetRadius.Soft)
	c.Parent = b

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Street.Sage
	stroke.Thickness = Theme.StreetStroke.Normal
	stroke.Transparency = 0.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b

	-- Focus and hover share one visual language so gamepad users get exactly the
	-- affordance mouse users get.
	local function setActive(on)
		Motion.hover(b, { BackgroundColor3 = on and Theme.Street.Ink or Theme.Street.Asphalt })
		Motion.hover(stroke, { Color = on and Theme.Street.Amber or Theme.Street.Sage,
			Transparency = on and 0 or 0.5 })
		b.TextColor3 = on and Theme.Street.Amber or Theme.Street.OffWhite
	end
	b.MouseEnter:Connect(function() setActive(true) SoundBank.hover() end)
	b.MouseLeave:Connect(function() setActive(false) end)
	b.SelectionGained:Connect(function() setActive(true) SoundBank.hover() end)
	b.SelectionLost:Connect(function() setActive(false) end)
	return b
end

-- CONSTRUCTION ---------------------------------------------------------------

function MenuOverlayController.new(deps)
	local self = setmetatable({}, MenuOverlayController)
	self.scene = deps and deps.scene
	self.settings = (deps and deps.settings) or {}
	self.appliers = (deps and deps.appliers) or {}

	-- Seed the keys this panel owns but the legacy settings table predates.
	-- Without this the sliders format a nil and the toggles read as OFF
	-- regardless of the real state.
	if self.settings.RetroFilter == nil then self.settings.RetroFilter = 0.25 end
	if self.settings.ReduceEffects == nil then
		self.settings.ReduceEffects = self.settings.ReduceFlicker == true
	end
	if self.settings.TextScale == nil then self.settings.TextScale = 1.0 end
	self.conns = {}
	self.stack = {}
	self.state = nil
	self.panels = {}

	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild(GUI_NAME)
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false          -- respect the top bar
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 50
	gui.Parent = pg
	self.gui = gui

	-- Safe-area inset. GuiService reports the notch/rounded-corner region on
	-- mobile; without this the title and the content notice can sit under it.
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	self.root = root
	self:applySafeArea()
	-- Re-apply on viewport change. GuiService has no "safe area changed" signal,
	-- and GetGuiInset() only shifts when the viewport does (rotation, window
	-- resize, top-bar state), so ViewportSize is the correct trigger.
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(self.conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:applySafeArea()
		end))
	end

	self:buildLanding()
	self:buildCredits()
	self:buildSettings()
	self:bindBack()

	self:go("Landing", { replace = true })
	return self
end

function MenuOverlayController:applySafeArea()
	local inset = GuiService:GetGuiInset()
	local pad = self.root:FindFirstChildOfClass("UIPadding")
	if not pad then
		pad = Instance.new("UIPadding")
		pad.Parent = self.root
	end
	pad.PaddingTop = UDim.new(0, math.max(24, inset.Y))
	pad.PaddingBottom = UDim.new(0, 24)
	pad.PaddingLeft = UDim.new(0, math.max(28, inset.X))
	pad.PaddingRight = UDim.new(0, 28)
end

function MenuOverlayController:buildLanding()
	local panel = Instance.new("Frame")
	panel.Name = "Landing"
	panel.BackgroundTransparency = 1
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = self.root
	self.panels.Landing = panel

	-- The wordmark, not a TextLabel: an authored mark that tears every few
	-- seconds (UI/GlitchTitle). Its height follows the image's aspect, so the
	-- 520 here is the only number that decides how big the title reads.
	self.title = GlitchTitle.build(panel, {
		name = "Title",
		width = 520,
		position = UDim2.fromScale(0, 0),
	})

	local menu = Instance.new("Frame")
	menu.Name = "Actions"
	menu.BackgroundTransparency = 1
	menu.AnchorPoint = Vector2.new(0, 1)
	menu.Position = UDim2.new(0, 0, 1, -46)
	menu.Size = UDim2.new(0, 340, 0, Theme.Touch.Action * 3 + 24)
	menu.Parent = panel

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = menu

	self.btnStart = actionButton(menu, "Btn_START", "START", 1)
	self.btnSettings = actionButton(menu, "Btn_SETTINGS", "SETTINGS", 2)
	self.btnCredits = actionButton(menu, "Btn_CREDITS", "CREDITS", 3)

	local notice = Instance.new("TextLabel")
	notice.Name = "ContentNotice"
	notice.BackgroundTransparency = 1
	notice.Font = Theme.MonoFont
	notice.Text = CONTENT_NOTICE
	notice.TextSize = 16
	notice.TextColor3 = Theme.Street.Sage
	notice.TextXAlignment = Enum.TextXAlignment.Left
	notice.AnchorPoint = Vector2.new(0, 1)
	notice.Position = UDim2.new(0, 0, 1, -8)
	notice.Size = UDim2.new(0, 520, 0, 22)
	notice.Parent = panel

	self.btnStart.Activated:Connect(function()
		SoundBank.click()
		self:startSession()
	end)
	self.btnSettings.Activated:Connect(function()
		SoundBank.click()
		self:go("Settings")
	end)
	self.btnCredits.Activated:Connect(function()
		SoundBank.click()
		self:go("Credits")
	end)
end

-- A titled overlay card shared by Settings and Credits.
function MenuOverlayController:buildCard(name, heading)
	-- No scrim. This frame is a positioning container only.
	--
	-- It used to carry Ink at 0.15 transparency -- an 85%-opaque full-screen
	-- wash that greyed the 3D street out behind the card. The card itself is
	-- fully opaque (flatPanel leaves BackgroundTransparency at 0), so the wash
	-- bought no readability; it only replaced the menu's own backdrop with a
	-- flat grey rectangle.
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromScale(1, 1)
	panel.Visible = false
	panel.Parent = self.root
	self.panels[name] = panel

	local card = flatPanel(panel, "Card")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0, 560, 0, 460)
	dropShadow(card, Theme.StreetShadow.OffsetLarge)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 24)
	pad.PaddingBottom = UDim.new(0, 20)
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Heading"
	title.BackgroundTransparency = 1
	title.Font = Theme.TitleFont
	title.Text = heading
	title.TextSize = 32
	title.TextColor3 = Theme.Street.OffWhite
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Parent = card

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.new(0, 0, 0, 52)
	body.Size = UDim2.new(1, 0, 1, -52 - Theme.Touch.Action - 12)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = Theme.Street.Sage
	body.Parent = card

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	local back = actionButton(card, "Btn_BACK", "BACK", 99)
	back.AnchorPoint = Vector2.new(0, 1)
	back.Position = UDim2.new(0, 0, 1, 0)
	back.Size = UDim2.new(1, 0, 0, Theme.Touch.Action)
	back.Activated:Connect(function()
		SoundBank.click()
		self:back()
	end)

	return panel, body, back
end

function MenuOverlayController:buildCredits()
	local _, body = self:buildCard("Credits", "CREDITS")
	local function line(text, size, color, order)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = size >= 24 and Theme.TitleFont or Theme.MonoFont
		l.Text = text
		l.TextSize = size
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Size = UDim2.new(1, 0, 0, size + 8)
		l.LayoutOrder = order
		l.Parent = body
		return l
	end
	line("GROUP", 18, Theme.Street.Sage, 1)
	line(Theme.Credits.Group, 26, Theme.Street.OffWhite, 2)
	line("", 10, Theme.Street.Sage, 3)
	line("DEVELOPER", 18, Theme.Street.Sage, 4)
	line(Theme.Credits.Developer, 26, Theme.Street.OffWhite, 5)
	line(table.concat(Theme.Credits.DeveloperRoles, " · "), 18, Theme.Street.Denim, 6)
	-- The former "Environment materials: CC0 retro texture packs." line is
	-- deliberately absent. It was false: that CC0 notice only ever covered a
	-- free sample pack, never the packs this game ships. Asset credits are
	-- added back only from the confirmed ledger.
end

function MenuOverlayController:buildSettings()
	local _, body = self:buildCard("Settings", "SETTINGS")
	self.settingRows = {}

	-- Rows are named after the setting they carry. Naming them all "Row" makes
	-- them unaddressable by path -- a lookup resolves the first and silently
	-- returns the wrong control, which is the same trap the arena's four
	-- identical "Wall" parts set. Not worth repeating in code we own.
	local function row(order, height, key)
		local r = flatPanel(body, "Row_" .. tostring(key or order))
		r.Size = UDim2.new(1, -4, 0, height or Theme.Touch.Min)
		r.LayoutOrder = order
		r.BackgroundTransparency = 0.4
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = r
		return r
	end
	local function rowLabel(parent, text)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Theme.MonoFont
		l.Text = text
		l.TextSize = 18
		l.TextColor3 = Theme.Street.OffWhite
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Size = UDim2.new(0.55, 0, 1, 0)
		l.Parent = parent
		return l
	end

	local function toggleRow(order, label, key, onChange)
		local r = row(order, nil, key)
		rowLabel(r, label)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, 0, 0.5, 0)
		b.Size = UDim2.new(0, 96, 0, 32)
		b.BackgroundColor3 = Theme.Street.Ink
		b.BorderSizePixel = 0
		b.Font = Theme.MonoFont
		b.TextSize = 16
		b.Parent = r
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, Theme.StreetRadius.Soft) c.Parent = b
		local st = Instance.new("UIStroke") st.Color = Theme.Street.Sage st.Thickness = 1
		st.Transparency = 0.5 st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border st.Parent = b
		local function paint()
			local on = self.settings[key] == true
			b.Text = on and "ON" or "OFF"
			b.TextColor3 = on and Theme.Street.Amber or Theme.Street.Denim
			st.Color = on and Theme.Street.Amber or Theme.Street.Sage
		end
		b.Activated:Connect(function()
			self.settings[key] = not (self.settings[key] == true)
			paint()
			SoundBank.click()
			if onChange then onChange(self.settings[key]) end
		end)
		paint()
		table.insert(self.settingRows, paint)
		return r
	end

	-- `displayScale` separates the stored value from the shown one: Retro Filter
	-- is stored 0..1 because that is what the effect consumes, but the spec
	-- states it as a percentage, so it is shown x100.
	local function sliderRow(order, label, key, min, max, step, fmt, displayScale, onChange)
		local r = row(order, nil, key)
		rowLabel(r, label)
		local minus = Instance.new("TextButton")
		minus.AutoButtonColor = false
		minus.AnchorPoint = Vector2.new(1, 0.5)
		minus.Position = UDim2.new(1, -132, 0.5, 0)
		minus.Size = UDim2.new(0, 34, 0, 32)
		minus.BackgroundColor3 = Theme.Street.Ink
		minus.BorderSizePixel = 0
		minus.Font = Theme.MonoFont
		minus.Text = "-"
		minus.TextSize = 20
		minus.TextColor3 = Theme.Street.OffWhite
		minus.Parent = r
		local value = Instance.new("TextLabel")
		value.BackgroundTransparency = 1
		value.AnchorPoint = Vector2.new(1, 0.5)
		value.Position = UDim2.new(1, -44, 0.5, 0)
		value.Size = UDim2.new(0, 84, 0, 32)
		value.Font = Theme.MonoFont
		value.TextSize = 18
		value.TextColor3 = Theme.Street.Amber
		value.Parent = r
		local plus = minus:Clone()
		plus.Position = UDim2.new(1, 0, 0.5, 0)
		plus.Text = "+"
		plus.Parent = r
		local function paint()
			value.Text = string.format(fmt, (self.settings[key] or min) * (displayScale or 1))
		end
		local function nudge(dir)
			local v = (self.settings[key] or min) + dir * step
			self.settings[key] = math.clamp(math.floor(v * 1000 + 0.5) / 1000, min, max)
			paint()
			SoundBank.click()
			if onChange then onChange(self.settings[key]) end
		end
		minus.Activated:Connect(function() nudge(-1) end)
		plus.Activated:Connect(function() nudge(1) end)
		paint()
		table.insert(self.settingRows, paint)
		return r
	end

	local A = self.appliers
	sliderRow(1, "TEXT SIZE", "TextScale", 0.8, 1.3, 0.05, "%.0f%%", 100, function(v)
		if A.textScale then A.textScale(v) end
	end)
	sliderRow(2, "RETRO FILTER", "RetroFilter", 0, 1, 0.05, "%.0f%%", 100, function(v)
		if A.retroFilter then A.retroFilter(v) end
	end)
	toggleRow(3, "SUBTLE SCANLINES", "Scanlines", function(v)
		if A.scanlines then A.scanlines(v) end
	end)
	toggleRow(4, "REDUCE EFFECTS", "ReduceEffects", function(v)
		-- Keep the legacy key in step so anything still reading ReduceFlicker
		-- sees the same answer until the removal pass retires it.
		self.settings.ReduceFlicker = v
		-- This toggle previously had NO applier: its only observable effect was
		-- that MenuSceneController counted it as "reduced motion", so turning it
		-- on stopped the camera move and changed no effect at all. It now drives
		-- the post-processing, and motion belongs solely to ANIMATIONS below.
		if A.effects then A.effects(v) end
	end)
	toggleRow(5, "ANIMATIONS", "Animations", function(v) Motion.setEnabled(v) end)
	toggleRow(6, "RETRO CURSOR", "CustomCursor", function(v)
		if A.cursor then A.cursor(v) end
	end)
	toggleRow(7, "UI SOUND", "UiSound", function(v) SoundBank.setSfxEnabled(v) end)
	toggleRow(8, "MUSIC", "Music", function(v) SoundBank.setMusicEnabled(v) end)
end

-- NAVIGATION -----------------------------------------------------------------

function MenuOverlayController:setPanelVisible(name, visible)
	local p = self.panels[name]
	if not p then return end
	p.Visible = visible
	-- Selectable is cleared as well as Visible: an invisible-but-selectable
	-- button still takes gamepad focus, which is how a hidden screen ends up
	-- "clickable" for controller users.
	for _, d in p:GetDescendants() do
		if d:IsA("GuiButton") then
			d.Selectable = visible
			d.Active = visible
			d.Interactable = visible
		end
	end
end

function MenuOverlayController:go(state, opts)
	opts = opts or {}
	if self.state == state then return end
	if self.state and not opts.replace then
		table.insert(self.stack, self.state)
	end
	if self.state then self:setPanelVisible(self.state, false) end
	self.state = state
	self:setPanelVisible(state, true)
	self:focusFirst(state)
end

function MenuOverlayController:back()
	local prev = table.remove(self.stack)
	if not prev then
		-- Nothing pushed: Landing is the floor, not a guess.
		if self.state ~= "Landing" then
			self:setPanelVisible(self.state, false)
			self.state = "Landing"
			self:setPanelVisible("Landing", true)
			self:focusFirst("Landing")
			if self.scene then self.scene.goToLanding() end
		end
		return
	end
	self:setPanelVisible(self.state, false)
	self.state = prev
	self:setPanelVisible(prev, true)
	self:focusFirst(prev)
	if prev == "Landing" and self.scene then self.scene.goToLanding() end
end

function MenuOverlayController:focusFirst(state)
	if not UserInputService.GamepadEnabled then return end
	local p = self.panels[state]
	if not p then return end
	for _, d in p:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible and d.Selectable then
			GuiService.SelectedObject = d
			return
		end
	end
end

function MenuOverlayController:bindBack()
	ContextActionService:BindAction(BACK_ACTION, function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if self.state == "Landing" then return Enum.ContextActionResult.Pass end
		self:back()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	table.insert(self.conns, {
		Connected = true,
		Disconnect = function() ContextActionService:UnbindAction(BACK_ACTION) end,
	})
end

-- SESSION HANDOFF ------------------------------------------------------------

function MenuOverlayController:startSession()
	if self.state ~= "Landing" then return end
	self:go("TransitionToSession")
	-- The landing actions must not remain clickable behind the moving camera.
	self:setPanelVisible("Landing", false)

	if not self.scene then
		self:abortToLanding("SCENE UNAVAILABLE")
		return
	end

	-- goToSession returns false when the scene is inactive or the camera/marker
	-- is missing. Landing is already hidden at this point and onArrive will
	-- never fire, so without this branch the player is left staring at the
	-- street with no menu and no way back. Fail visibly, not silently.
	local started = self.scene.goToSession({ onArrive = function()
		if self.state ~= "TransitionToSession" then return end
		self.state = "SessionSelect"
		if self.onEnterSession then self.onEnterSession() end
	end })

	if not started then
		self:abortToLanding("SESSION VIEW UNAVAILABLE")
	end
end

-- Restore the landing screen after a failed transition and say so plainly.
-- Neutral wording: this is an internal fault, not something the player did.
function MenuOverlayController:abortToLanding(reason)
	self.stack = {}
	self.state = "Landing"
	self:setPanelVisible("Landing", true)
	self:focusFirst("Landing")
	self:setNotice(reason, true)
	SoundBank.denied()
end

function MenuOverlayController:setNotice(text, isError)
	local panel = self.panels.Landing
	local notice = panel and panel:FindFirstChild("ContentNotice")
	if not notice then return end
	if not self._noticeDefault then self._noticeDefault = notice.Text end
	notice.Text = text or self._noticeDefault
	notice.TextColor3 = isError and Theme.Street.Error or Theme.Street.Sage
	if isError then
		task.delay(4, function()
			if notice.Parent then
				notice.Text = self._noticeDefault
				notice.TextColor3 = Theme.Street.Sage
			end
		end)
	end
end

-- The wall's BACK hands control back here: return to the landing camera and
-- restore the landing panel.
function MenuOverlayController:returnToLanding()
	self.stack = {}
	if self.state then self:setPanelVisible(self.state, false) end
	self.state = "Landing"
	self:setPanelVisible("Landing", true)
	self:focusFirst("Landing")
	if self.scene then self.scene.goToLanding() end
end

function MenuOverlayController:destroy()
	for _, conn in self.conns do
		if conn.Disconnect then conn:Disconnect() end
	end
	table.clear(self.conns)
	-- The wordmark owns a sleeping thread; destroying the gui alone would
	-- leave it waking every few seconds for a frame that no longer exists.
	if self.title then
		self.title.destroy()
		self.title = nil
	end
	if self.gui then self.gui:Destroy() end
end

return MenuOverlayController
