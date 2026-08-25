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

-- House style: machine labels are letter-spaced. A run of spaces stays a run,
-- so "PRIVATE ROOM" keeps its word break instead of closing up.
local function spaced(s)
	local out = {}
	for i = 1, #s do out[#out + 1] = string.sub(s, i, i) end
	return table.concat(out, " ")
end

-- The landing's entries have no boxes any more: the selected one is lit by a
-- torn white bar that travels between them (see buildStreak). A button is
-- therefore just a label plus a hit area, and `onActive` tells the owner which
-- row the bar belongs on.
local function actionButton(parent, name, text, order, onActive)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.Size = UDim2.new(1, 0, 0, Theme.Touch.Action)
	b.LayoutOrder = order
	-- above the selection bar (ZIndex 1) -- with Sibling z-behaviour a tie
	-- would let the bar paint over its own label
	b.ZIndex = 3
	b.Font = Theme.TitleFont
	b.Text = spaced(text)
	b.TextSize = 26
	b.TextColor3 = Theme.Cold.Text
	b.TextTransparency = 0.15
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Parent = parent

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 34)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = b

	-- the small mark that sits inside the bar, left of the label
	local bullet = Instance.new("Frame")
	bullet.Name = "Bullet"
	bullet.AnchorPoint = Vector2.new(0, 0.5)
	bullet.Position = UDim2.new(0, -22, 0.5, 0)
	bullet.Size = UDim2.fromOffset(8, 8)
	bullet.BackgroundColor3 = Theme.Cold.OnStreak
	bullet.BorderSizePixel = 0
	bullet.ZIndex = 4
	bullet.Visible = false
	bullet.Parent = b

	-- Focus and hover share one visual language so gamepad users get exactly the
	-- affordance mouse users get.
	local function setActive(on)
		b.TextColor3 = on and Theme.Cold.OnStreak or Theme.Cold.Text
		b.TextTransparency = on and 0 or 0.15
		bullet.Visible = on
		if on and onActive then onActive(b) end
	end
	b.MouseEnter:Connect(function() setActive(true) SoundBank.hover() end)
	b.MouseLeave:Connect(function() setActive(false) end)
	b.SelectionGained:Connect(function() setActive(true) SoundBank.hover() end)
	b.SelectionLost:Connect(function() setActive(false) end)
	return b
end

-- The uploaded plates (tools/menu-assets.py, 25.08.2026). All white on
-- transparent so they can be tinted, all authored small so they magnify with
-- hard pixel edges instead of going soft.
local PLATE = {
	Streak = "rbxassetid://134334042347021",
	Shards = "rbxassetid://120005853529594",
	Rain = "rbxassetid://105106540934647",
	Dots = "rbxassetid://85128683768553",
}

-- The layers that sit between the 3D scene and the menu text. They are held
-- deliberately faint: the scene behind them (the wall, the subject standing on
-- the landing) has to stay legible, so these are a veil, not a background.
local function buildBackdrop(gui)
	local back = Instance.new("Frame")
	back.Name = "Backdrop"
	back.BackgroundTransparency = 1
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 0
	back.Parent = gui

	-- SCRIM. The menu's whole text column lives on the left, and a UI must not
	-- depend on what happens to be behind it -- the scene changes, the subject
	-- moves, a lamp flickers. A dark wedge fading out by mid-screen guarantees
	-- the title, the entries and the content notice always have ground to sit
	-- on, and it doubles as the composition's left weight.
	local scrim = Instance.new("Frame")
	scrim.Name = "Scrim"
	scrim.BackgroundColor3 = Theme.Cold.Ground
	scrim.BorderSizePixel = 0
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.ZIndex = 0
	scrim.Parent = back
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.30, 0.45),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = scrim

	-- ... and a shorter one along the bottom edge, for the notice and the cells.
	local floorScrim = scrim:Clone()
	floorScrim.Name = "FloorScrim"
	local fg = floorScrim:FindFirstChildOfClass("UIGradient")
	fg.Rotation = 90
	fg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.70, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	floorScrim.Parent = back

	local function tile(name, image, px, alpha, colour)
		local i = Instance.new("ImageLabel")
		i.Name = name
		i.BackgroundTransparency = 1
		i.BorderSizePixel = 0
		i.Image = image
		i.ImageColor3 = colour
		i.ImageTransparency = alpha
		i.ScaleType = Enum.ScaleType.Tile
		i.TileSize = UDim2.fromOffset(px, px)
		i.ResampleMode = Enum.ResamplerMode.Pixelated
		i.Size = UDim2.fromScale(1, 1)
		i.ZIndex = 0
		i.Parent = back
		return i
	end
	-- Static, very light texture only. Nothing here covers the street or runs a
	-- per-frame updater; the 3D scene and local character remain the background.
	tile("Scanlines", Theme.Asset.Scanlines, 128, 0.91, Theme.Cold.Text)
	tile("Noise", Theme.Asset.Noise, 256, 0.96, Theme.Cold.Text)
	tile("Rain", PLATE.Rain, 256, 0.94, Theme.Cold.Focus)
	tile("Dots", PLATE.Dots, 128, 0.93, Theme.Cold.Focus)

	local shards = Instance.new("ImageLabel")
	shards.Name = "Shards"
	shards.BackgroundTransparency = 1
	shards.BorderSizePixel = 0
	shards.Image = PLATE.Shards
	shards.ImageColor3 = Theme.Cold.Bright
	shards.ImageTransparency = 0.95
	shards.ResampleMode = Enum.ResamplerMode.Pixelated
	shards.Size = UDim2.fromScale(0.68, 0.95)
	shards.Position = UDim2.fromScale(0.36, 0.05)
	shards.ZIndex = 0
	shards.Parent = back

	local vignette = Instance.new("ImageLabel")
	vignette.Name = "Vignette"
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Image = Theme.Asset.Vignette
	vignette.ImageColor3 = Theme.Cold.Ground
	vignette.ImageTransparency = 0.90
	vignette.ScaleType = Enum.ScaleType.Stretch
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.ZIndex = 0
	vignette.Parent = back
	return back
end

-- Corner ticks, a build tag and a row of boxed status cells: the furniture that
-- makes the screen read as a terminal rather than as a title card. All static
-- except the cell values, which a 1 Hz loop writes only when they change.
local function buildChrome(panel)
	local chrome = Instance.new("Frame")
	chrome.Name = "Chrome"
	chrome.BackgroundTransparency = 1
	chrome.BorderSizePixel = 0
	chrome.Size = UDim2.fromScale(1, 1)
	chrome.ZIndex = 1
	chrome.Parent = panel

	for _, c in ipairs({ { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } }) do
		for _, seg in ipairs({ { 14, 2 }, { 2, 14 } }) do
			local f = Instance.new("Frame")
			f.Name = "Tick"
			f.AnchorPoint = Vector2.new(c[1], c[2])
			f.Position = UDim2.new(c[1], 0, c[2], 0)
			f.Size = UDim2.fromOffset(seg[1], seg[2])
			f.BackgroundColor3 = Theme.Cold.Dim
			f.BorderSizePixel = 0
			f.ZIndex = 1
			f.Parent = chrome
		end
	end

	local tag = Instance.new("TextLabel")
	tag.Name = "BuildTag"
	tag.BackgroundTransparency = 1
	tag.Font = Theme.MonoFont
	tag.Text = "BUILD 2026.08.25"
	tag.TextSize = 12
	tag.TextColor3 = Theme.Cold.Dim
	tag.TextXAlignment = Enum.TextXAlignment.Right
	tag.AnchorPoint = Vector2.new(1, 0)
	tag.Position = UDim2.new(1, -22, 0, 2)
	tag.Size = UDim2.fromOffset(240, 14)
	tag.ZIndex = 1
	tag.Parent = chrome

	local cells = {}
	local row = Instance.new("Frame")
	row.Name = "Cells"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(1, 1)
	row.Position = UDim2.new(1, -22, 1, -8)
	row.Size = UDim2.fromOffset(3 * 116 - 10, 38)
	row.ZIndex = 1
	row.Parent = chrome
	for i, head in ipairs({ "SUBJECTS", "SESSION", "LINK" }) do
		local box = Instance.new("Frame")
		box.Name = "Cell" .. i
		box.Position = UDim2.fromOffset((i - 1) * 116, 0)
		box.Size = UDim2.fromOffset(106, 38)
		box.BackgroundColor3 = Theme.Cold.Panel
		box.BackgroundTransparency = 0.25
		box.BorderSizePixel = 0
		box.ZIndex = 1
		box.Parent = row
		local st = Instance.new("UIStroke")
		st.Color = Theme.Cold.Dim
		st.Thickness = 1
		st.Parent = box
		local h = Instance.new("TextLabel")
		h.BackgroundTransparency = 1
		h.Font = Theme.MonoFont
		h.Text = head
		h.TextSize = 11
		h.TextColor3 = Theme.Cold.Focus
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Position = UDim2.fromOffset(7, 4)
		h.Size = UDim2.new(1, -14, 0, 12)
		h.ZIndex = 2
		h.Parent = box
		local v = h:Clone()
		v.Name = "Value"
		v.Text = "--"
		v.TextColor3 = Theme.Cold.Dim
		v.Position = UDim2.fromOffset(7, 19)
		v.Parent = box
		cells[i] = v
	end
	return chrome, cells
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

	-- The veil sits UNDER Root (which carries the safe-area padding) so the
	-- plates run edge to edge while the text stays inside the notch.
	self.backdrop = buildBackdrop(gui)
	root.ZIndex = 1
	-- applySafeArea already ran above, before this existed, and it is what sizes
	-- the backdrop past the GUI inset -- so run it once more now that there is
	-- something to size.
	self:applySafeArea()

	self:buildLanding()
	self:buildCredits()
	self:buildSettings()
	self:bindBack()

	-- Status cells: 1 Hz, and every value is compared before it is written, so
	-- a menu nobody touches costs one wake-up a second and no property traffic.
	self.statusAlive = true
	task.spawn(function()
		local last = {}
		local t0 = os.clock()
		while self.statusAlive do
			local values = {
				tostring(#Players:GetPlayers()),
				string.format("%02d:%02d", math.floor((os.clock() - t0) / 60) % 60,
					math.floor(os.clock() - t0) % 60),
				"STABLE",
			}
			for i, v in ipairs(values) do
				local cell = self.cells and self.cells[i]
				if cell and last[i] ~= v then
					last[i] = v
					cell.Text = v
				end
			end
			task.wait(1)
		end
	end)

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

	-- The backdrop must cover the WHOLE viewport, inset included. This
	-- ScreenGui keeps IgnoreGuiInset = false so the content respects the top
	-- bar, which means its 1,1 stops short of the screen edge -- and a strip of
	-- the 3D scene showed above the background plate (measured 25.08.2026).
	-- Pull it out past the inset on every side; overdraw on a background costs
	-- nothing and no arithmetic can leave a seam.
	if self.backdrop then
		self.backdrop.Position = UDim2.fromOffset(-inset.X, -inset.Y)
		self.backdrop.Size = UDim2.new(1, inset.X * 2, 1, inset.Y * 2)
	end
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
	-- Anchored to a PROPORTION of the height, not to the bottom edge. Glued to
	-- the bottom the list drifted further and further from the title as the
	-- window grew, leaving a hole in the middle of the composition (reported on
	-- a tall Studio viewport, 25.08.2026).
	menu.AnchorPoint = Vector2.new(0, 0)
	menu.Position = UDim2.new(0, 0, 0.46, 0)
	menu.Size = UDim2.new(0, 340, 0, Theme.Touch.Action * 3 + 24)
	-- Above StreakLayer (1). Sibling z-behaviour sorts whole SUBTREES by the
	-- sibling's own ZIndex, so leaving both at the default 1 let the bar paint
	-- over the very label it is meant to light up (measured live 25.08.2026).
	menu.ZIndex = 3
	menu.Parent = panel

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = menu

	-- THE SELECTION BAR. One instance for the whole list: it travels to
	-- whichever entry is active instead of every entry carrying its own
	-- highlight. It overhangs the row so its torn ends show past the label.
	-- The bar lives in a SIBLING of the list, not inside it. A UIListLayout lays
	-- out every GuiObject child it has, so a layer parented to `menu` was given
	-- a full-height row of its own and pushed all three entries off the bottom
	-- of the screen (measured live, 25.08.2026). Same geometry as `menu`, so
	-- the two rectangles coincide exactly.
	local streakLayer = Instance.new("Frame")
	streakLayer.Name = "StreakLayer"
	streakLayer.BackgroundTransparency = 1
	streakLayer.BorderSizePixel = 0
	streakLayer.AnchorPoint = menu.AnchorPoint
	streakLayer.Position = menu.Position
	streakLayer.Size = menu.Size
	streakLayer.ZIndex = 1
	streakLayer.Parent = panel

	-- The engine draws a blue selection rectangle on the focused button by
	-- default; on this menu the bar already says which row is live, and the
	-- rectangle lands on top of it.
	local noFocusRing = Instance.new("Frame")
	noFocusRing.Name = "NoFocusRing"
	noFocusRing.BackgroundTransparency = 1
	noFocusRing.BorderSizePixel = 0
	noFocusRing.Size = UDim2.fromScale(1, 1)
	noFocusRing.Parent = streakLayer

	local streak = Instance.new("ImageLabel")
	streak.Name = "Streak"
	streak.BackgroundTransparency = 1
	streak.BorderSizePixel = 0
	streak.Image = PLATE.Streak
	streak.ImageColor3 = Theme.Cold.Streak
	streak.ResampleMode = Enum.ResamplerMode.Pixelated
	streak.Size = UDim2.new(1, 44, 0, math.floor(Theme.Touch.Action * 1.12))
	streak.Position = UDim2.fromOffset(-22, 0)
	streak.ZIndex = 1
	streak.Visible = false
	streak.Parent = streakLayer
	self.streak = streak

	-- Stepped travel on the 12 fps grid with one frame of overshoot, then the
	-- settle: the bar SNAPS between entries, it never slides.
	local moveToken = 0
	local function moveStreak(target)
		moveToken = moveToken + 1
		local token = moveToken
		local toY = target.AbsolutePosition.Y - streakLayer.AbsolutePosition.Y
			- math.floor((streak.AbsoluteSize.Y - target.AbsoluteSize.Y) / 2)
		streak.Visible = true
		if not Motion.isEnabled() then
			streak.Position = UDim2.fromOffset(-22, toY)
			return
		end
		local fromY = streak.Position.Y.Offset
		task.spawn(function()
			local dir = toY >= fromY and 1 or -1
			for s = 1, 2 do
				if token ~= moveToken then return end
				local y = (s == 2) and (toY + dir * 6) or (fromY + (toY - fromY) * 0.5)
				streak.Position = UDim2.fromOffset(-22, math.floor(y + 0.5))
				task.wait(1 / 12)
			end
			if token ~= moveToken then return end
			streak.Position = UDim2.fromOffset(-22, toY)
		end)
	end

	self.btnStart = actionButton(menu, "Btn_START", "START", 1, moveStreak)
	self.btnSettings = actionButton(menu, "Btn_SETTINGS", "SETTINGS", 2, moveStreak)
	self.btnCredits = actionButton(menu, "Btn_CREDITS", "CREDITS", 3, moveStreak)
	for _, b in ipairs({ self.btnStart, self.btnSettings, self.btnCredits }) do
		b.SelectionImageObject = noFocusRing
	end

	local notice = Instance.new("TextLabel")
	notice.Name = "ContentNotice"
	notice.BackgroundTransparency = 1
	notice.Font = Theme.MonoFont
	notice.Text = CONTENT_NOTICE
	notice.TextSize = 16
	notice.TextColor3 = Theme.Cold.Text
	notice.TextTransparency = 0.35
	notice.TextXAlignment = Enum.TextXAlignment.Left
	notice.AnchorPoint = Vector2.new(0, 1)
	notice.Position = UDim2.new(0, 0, 1, -8)
	notice.Size = UDim2.new(0, 520, 0, 22)
	notice.Parent = panel

	-- Terminal furniture. On the landing only: the Settings and Credits cards
	-- would collide with the status row at the bottom right.
	local _, cells = buildChrome(panel)
	self.cells = cells

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
	-- The veil belongs to the landing. It is a full-screen layer, so leaving it
	-- up while the camera is at the session wall darkened the left third of a
	-- screen it was never composed for and dragged the shard sheet across the
	-- wall's own text.
	if name == "Landing" and self.backdrop then
		self.backdrop.Visible = visible
	end
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
	self.statusAlive = false
	-- The wordmark owns a sleeping thread; destroying the gui alone would
	-- leave it waking every few seconds for a frame that no longer exists.
	if self.title then
		self.title.destroy()
		self.title = nil
	end
	if self.gui then self.gui:Destroy() end
end

return MenuOverlayController
