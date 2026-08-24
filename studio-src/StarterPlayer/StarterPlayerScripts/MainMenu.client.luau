--!nonstrict
-- MAIN MENU (25.08.2026) -- the title terminal a subject sees before the
-- facility takes them.
--
-- Until now the first screen of the game was the roulette: a black rectangle
-- with green terminal text, no sign of the 3D world at all. This is the front
-- door. It holds until the player chooses ENTER FACILITY.
--
-- COLD ON PURPOSE. The palette here is cyan and white (MenuConfig.Palette),
-- not the phosphor green of the machine screens. Outside the facility is cold;
-- inside it is green. Entering flashes phosphor across the glass for two
-- frames -- that flash IS the handoff, and it is a GUI wash rather than a
-- Lighting tween because Lighting has exactly one owner (SimulationGrade) and
-- a second writer is how you get a stuck grade.
--
-- PERFORMANCE, the three rules this file lives by:
--   1. Its OWN ScreenGui. Roblox drops a Gui's render cache when ANY
--      descendant changes; KenopsiaMachine has 521 of them, so a streak
--      sliding around in there would re-rasterise all 521 every step. This
--      tree is ~130 instances and nothing here ever writes into the machine's.
--   2. NO RenderStepped. Every moving thing -- the streak, the parallax, the
--      camera dolly, the clock -- rides ONE stepped loop at Feel.Step.Fps, and
--      each writer compares before it writes. Idle cost is ~12 wakeups/s doing
--      almost nothing.
--   3. Closed means closed. gui.Enabled = false, the loop's gate goes false,
--      the diorama is destroyed. A match pays nothing for this file.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config")
local Menu = require(Config:WaitForChild("MenuConfig"))
local Feel = require(Config:WaitForChild("FeelConfig"))

-- Optional: the glyph module gives the hint bar this device's own key names
-- and button images. A place without it keeps the authored desktop text.
local Glyphs = (function()
	local m = script.Parent:FindFirstChild("Glyphs")
	return m and require(m) or nil
end)()

local P = {}
for k, v in Menu.Palette do P[k] = Color3.fromHex(v) end

local STEP = Feel.stepSeconds()
local FONT = Enum.Font.Code

-- STATE ----------------------------------------------------------------------
local gui, root, rowsFrame, streak, titleImg, titleGlowA, titleGlowB, subLabel
local detailCard, detailHead, detailLines, hintLabel, cellFrames, ditherCard
local personnelPanel, personnelRows
local shardsImg
local rowButtons = {}
local selected = 1
local isOpen = false
local bootToken = 0
local subPanel = nil        -- "briefing" | "settings" | "personnel" | nil
local releaseHold = nil     -- undo for the briefing visibility watchdog
local diorama, dioLamp, dioLampLight, dioCamBase
local openedAt = 0
local lampDropUntil = 0
local machine = nil

local function machineGui()
	if machine and machine.Parent then return machine end
	machine = playerGui:FindFirstChild("KenopsiaMachine")
	return machine
end

local function platform()
	local m = machineGui()
	return (m and m:GetAttribute("Platform")) or "Desktop"
end

local function isMobile()
	local p = platform()
	return p == "Mobile" or p == "Tablet"
end

local function motionOk()
	return not GuiService.ReducedMotionEnabled and player:GetAttribute("KenopsiaReduceFlicker") ~= true
end

-- Same bus and same gate as the machine's own cues (KenopsiaClient.sfx).
local function sfx(name)
	if player:GetAttribute("KenopsiaUiSound") == false then return end
	local audio = SoundService:FindFirstChild("KenopsiaAudio")
	local folder = audio and audio:FindFirstChild("SFX")
	local s = folder and folder:FindFirstChild(name)
	if s and s.SoundId ~= "" then
		if s.SoundGroup == nil then s.SoundGroup = SoundService:FindFirstChild("KenopsiaUI") end
		SoundService:PlayLocalSound(s)
	end
end

local function img(name)
	local spec = Menu.Images[name]
	if not spec or spec.id == "" then return "" end
	return "rbxassetid://" .. spec.id
end

local function aspect(name)
	local spec = Menu.Images[name]
	if not spec or spec.h == 0 then return 1 end
	return spec.w / spec.h
end

-- Time-based typewriter, the same rule the machine screens use (Feel.visibleAt
-- against elapsed time, NOT one grapheme per frame): 30 fps and 60 fps finish
-- the same line at the same instant.
local function typewrite(label, text, cps, token)
	label.Text = text
	local total = utf8.len(text) or #text
	label.MaxVisibleGraphemes = 0
	local t0 = os.clock()
	while true do
		if token ~= bootToken then return end
		local n = Feel.visibleAt(os.clock() - t0, cps, total)
		if label.MaxVisibleGraphemes ~= n then label.MaxVisibleGraphemes = n end
		if n >= total then break end
		task.wait()
	end
	label.MaxVisibleGraphemes = -1
end

-- BUILD ----------------------------------------------------------------------

local function newLabel(parent, name, size, colour, textSize, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Size = size
	l.Font = FONT
	l.TextSize = textSize
	l.TextColor3 = colour
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = ""
	l.Parent = parent
	return l
end

local function newImage(parent, name, image, z)
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.BorderSizePixel = 0
	i.Image = image
	i.ResampleMode = Enum.ResamplerMode.Pixelated
	i.ZIndex = z or 1
	i.Parent = parent
	return i
end

local function buildBackground()
	-- Three static plates. Two are tiled at their authored size (crisp), one is
	-- a single magnified sheet. None of them ever changes except the shard
	-- sheet's position, which the idle loop nudges a few pixels.
	local plate = newImage(root, "Plate", img("Rain"), 1)
	plate.Size = UDim2.fromScale(1, 1)
	plate.ScaleType = Enum.ScaleType.Tile
	plate.TileSize = UDim2.fromOffset(Menu.Images.Rain.w, Menu.Images.Rain.h)
	plate.ImageColor3 = P.ACCENT
	plate.ImageTransparency = 0.88

	local dots = newImage(root, "Dots", img("Dots"), 2)
	dots.Size = UDim2.fromScale(1, 1)
	dots.ScaleType = Enum.ScaleType.Tile
	dots.TileSize = UDim2.fromOffset(Menu.Images.Dots.w, Menu.Images.Dots.h)
	dots.ImageColor3 = P.ACCENT
	dots.ImageTransparency = 0.82

	shardsImg = newImage(root, "Shards", img("Shards"), 3)
	shardsImg.Size = UDim2.fromScale(0.68, 0.95)
	shardsImg.Position = UDim2.fromScale(0.36, 0.05)
	shardsImg.ImageColor3 = P.CYAN_HI
	shardsImg.ImageTransparency = 0.78

	-- vignette: four static edge gradients, exactly the UiFx recipe
	for _, spec in ipairs({
		{ "VignetteTop", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.16), 90 },
		{ "VignetteBottom", UDim2.fromScale(0, 0.84), UDim2.fromScale(1, 0.16), -90 },
		{ "VignetteLeft", UDim2.fromScale(0, 0), UDim2.fromScale(0.10, 1), 0 },
		{ "VignetteRight", UDim2.fromScale(0.90, 0), UDim2.fromScale(0.10, 1), 180 },
	}) do
		local f = Instance.new("Frame")
		f.Name = spec[1]
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Position = spec[2]
		f.Size = spec[3]
		f.ZIndex = 4
		local g = Instance.new("UIGradient")
		g.Rotation = spec[4]
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		f.Parent = root
	end
end

local function buildTitle()
	local L = Menu.Layout
	local h = L.TitleW / aspect("Wordmark")
	-- The two offset copies are the chromatic split. They live UNDER the mark
	-- and collapse onto it during the boot punch; after that they sit at zero
	-- offset and cost nothing.
	titleGlowA = newImage(root, "TitleChromaA", img("Wordmark"), 5)
	titleGlowA.ImageColor3 = Color3.fromRGB(255, 60, 60)
	titleGlowA.ImageTransparency = 0.65
	titleGlowB = newImage(root, "TitleChromaB", img("Wordmark"), 5)
	titleGlowB.ImageColor3 = P.ACCENT
	titleGlowB.ImageTransparency = 0.65
	titleImg = newImage(root, "Title", img("Wordmark"), 6)
	titleImg.ImageColor3 = P.CYAN_HI
	for _, i in ipairs({ titleGlowA, titleGlowB, titleImg }) do
		i.Size = UDim2.fromOffset(L.TitleW, h)
		i.Position = UDim2.fromOffset(L.TitleX, L.TitleY)
		i.Visible = false
	end
	subLabel = newLabel(root, "Sub", UDim2.new(0, 520, 0, 16), P.CYAN_DIM, 13)
	subLabel.Position = UDim2.fromOffset(L.TitleX + 4, L.TitleY + h + L.SubGap)
	subLabel.ZIndex = 6
	subLabel.Visible = false
end

local function buildRows()
	local L = Menu.Layout
	rowsFrame = Instance.new("Frame")
	rowsFrame.Name = "Rows"
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.BorderSizePixel = 0
	rowsFrame.Position = UDim2.fromOffset(L.RowsX, L.RowsY)
	rowsFrame.Size = UDim2.fromOffset(L.RowW, #Menu.Entries * (L.RowH + L.RowGap))
	rowsFrame.ZIndex = 7
	rowsFrame.Parent = root

	-- Console: MachineLayout parks a phosphor-green focus ring on every
	-- selectable object through PlayerGui.SelectionImageObject. On a menu row
	-- that would sit on top of the streak and fight it for the same job, so
	-- each row carries its own empty override instead.
	local blankFocus = Instance.new("Frame")
	blankFocus.Name = "NoFocusRing"
	blankFocus.BackgroundTransparency = 1
	blankFocus.BorderSizePixel = 0
	blankFocus.Size = UDim2.fromScale(1, 1)
	blankFocus.Parent = rowsFrame

	streak = newImage(rowsFrame, "Streak", img("Streak"), 7)
	streak.Size = UDim2.fromOffset(L.StreakW, Menu.streakH(false))
	streak.Position = UDim2.fromOffset(L.StreakX, Menu.streakY(1, false))
	streak.ImageColor3 = P.WHITE
	streak.Visible = false

	for i, entry in ipairs(Menu.Entries) do
		local b = Instance.new("TextButton")
		b.Name = "Row" .. i
		b.BackgroundTransparency = 1
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Position = UDim2.fromOffset(0, Menu.rowY(i, false))
		b.Size = UDim2.fromOffset(L.RowW, L.RowH)
		b.Font = FONT
		b.TextSize = L.RowTextSize
		b.TextColor3 = P.CYAN
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Text = ""
		b.ZIndex = 8
		b.Selectable = true
		b.SelectionImageObject = blankFocus
		b.Visible = false
		b:SetAttribute("EntryId", entry.id)
		b:SetAttribute("EntryIndex", i)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, L.RowTextX)
		pad.Parent = b
		local bullet = Instance.new("Frame")
		bullet.Name = "Bullet"
		bullet.AnchorPoint = Vector2.new(0, 0.5)
		bullet.Position = UDim2.new(0, L.BulletX - L.RowTextX, 0.5, 0)
		bullet.Size = UDim2.fromOffset(8, 8)
		bullet.BackgroundColor3 = P.INK
		bullet.BorderSizePixel = 0
		bullet.ZIndex = 9
		bullet.Visible = false
		bullet.Parent = b
		b.Parent = rowsFrame
		rowButtons[i] = b
	end
end

local function buildDetail()
	local L = Menu.Layout
	detailCard = Instance.new("Frame")
	detailCard.Name = "Detail"
	detailCard.BackgroundColor3 = P.PLATE
	detailCard.BackgroundTransparency = 0.18
	detailCard.BorderSizePixel = 0
	detailCard.Position = UDim2.new(L.DetailX, 0, 0, L.DetailY)
	detailCard.Size = UDim2.new(L.DetailW, 0, 0, L.DetailH)
	detailCard.ZIndex = 7
	detailCard.Visible = false
	local st = Instance.new("UIStroke")
	st.Color = P.CYAN_DIM
	st.Thickness = 1
	st.Parent = detailCard
	-- serration along the top edge, the machine's own chrome vocabulary
	local ser = Instance.new("Frame")
	ser.Name = "Serration"
	ser.BackgroundTransparency = 1
	ser.Position = UDim2.new(0, 0, 0, -6)
	ser.Size = UDim2.new(1, 0, 0, 5)
	ser.ZIndex = 8
	ser.Parent = detailCard
	for i = 0, 40 do
		local t = Instance.new("Frame")
		t.BackgroundColor3 = P.ACCENT
		t.BorderSizePixel = 0
		t.Position = UDim2.new(i / 41, 0, 0, 0)
		t.Size = UDim2.fromOffset(4, 5)
		t.ZIndex = 8
		t.Parent = ser
	end
	detailHead = newLabel(detailCard, "Head", UDim2.new(1, -28, 0, 18), P.CYAN_HI, 15)
	detailHead.Position = UDim2.fromOffset(14, 14)
	detailHead.ZIndex = 8
	detailLines = {}
	for i = 1, 4 do
		local l = newLabel(detailCard, "Line" .. i, UDim2.new(1, -28, 0, 18), P.CYAN, 13)
		l.Position = UDim2.fromOffset(14, 48 + (i - 1) * 22)
		l.ZIndex = 8
		detailLines[i] = l
	end
	detailCard.Parent = root
end

local function buildChrome()
	local L = Menu.Layout
	-- corner ticks
	for _, c in ipairs({ { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } }) do
		for _, seg in ipairs({ { L.TickLen, 2 }, { 2, L.TickLen } }) do
			local f = Instance.new("Frame")
			f.Name = "Tick"
			f.AnchorPoint = Vector2.new(c[1], c[2])
			f.Position = UDim2.new(c[1], c[3] * L.TickInset, c[2], c[4] * L.TickInset)
			f.Size = UDim2.fromOffset(seg[1], seg[2])
			f.BackgroundColor3 = P.CYAN_DIM
			f.BorderSizePixel = 0
			f.ZIndex = 6
			f.Visible = false
			f.Parent = root
		end
	end
	local build = newLabel(root, "BuildTag", UDim2.new(0, 260, 0, 14), P.CYAN_DIM, 11,
		Enum.TextXAlignment.Right)
	build.AnchorPoint = Vector2.new(1, 0)
	build.Position = UDim2.new(1, -L.TickInset - 8, 0, L.TickInset - 4)
	build.ZIndex = 6
	build.Visible = false

	-- status cells, bottom left, in the boxed style the machine chrome uses
	cellFrames = {}
	for i = 1, 3 do
		local b = Instance.new("Frame")
		b.Name = "Cell" .. i
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(0, L.CellsX + (i - 1) * (L.CellW + L.CellGap), 1, -L.CellsFromBottom)
		b.Size = UDim2.fromOffset(L.CellW, L.CellH)
		b.BackgroundColor3 = P.PLATE
		b.BackgroundTransparency = 0.2
		b.BorderSizePixel = 0
		b.ZIndex = 6
		b.Visible = false
		local st = Instance.new("UIStroke")
		st.Color = P.CYAN_DIM
		st.Thickness = 1
		st.Parent = b
		local head = newLabel(b, "Head", UDim2.new(1, -12, 0, 12), P.ACCENT, 11)
		head.Position = UDim2.fromOffset(6, 4)
		head.ZIndex = 7
		local val = newLabel(b, "Value", UDim2.new(1, -12, 0, 12), P.CYAN_DIM, 11)
		val.Position = UDim2.fromOffset(6, 19)
		val.ZIndex = 7
		b.Parent = root
		cellFrames[i] = b
	end

	hintLabel = newLabel(root, "Hint", UDim2.new(0.8, 0, 0, 16), P.CYAN_DIM, 13,
		Enum.TextXAlignment.Center)
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -18)
	hintLabel.ZIndex = 6
	hintLabel.Visible = false

	-- the menu's OWN dither card: the machine has one on the overlay gui, and
	-- bumping that one from here would dirty the machine's tree for no reason.
	ditherCard = newImage(root, "Dither", "", 40)
	ditherCard.Size = UDim2.fromScale(1, 1)
	ditherCard.ScaleType = Enum.ScaleType.Tile
	ditherCard.TileSize = UDim2.fromOffset(Feel.Dither.TilePx, Feel.Dither.TilePx)
	ditherCard.ImageColor3 = Color3.new(0, 0, 0)
	ditherCard.BackgroundColor3 = Color3.new(0, 0, 0)
	ditherCard.BackgroundTransparency = 1
	ditherCard.Visible = false

	-- the phosphor wash that hands the player over to the machine
	local wash = Instance.new("Frame")
	wash.Name = "Handoff"
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundColor3 = Color3.fromHex("78FFAA")
	wash.BackgroundTransparency = 1
	wash.BorderSizePixel = 0
	wash.ZIndex = 41
	wash.Visible = false
	wash.Parent = root
end

-- The subject's own face on the file. NEVER a baked-in image: the id comes
-- from the player reading the screen, so every client sees themselves and a
-- published build cannot ship the developer's avatar by accident. rbxthumb
-- resolves locally -- no HTTP, no yield, no thumbnail API call.
local function buildMugshot(parent)
	local holder = Instance.new("Frame")
	holder.Name = "Mugshot"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -18, 0, 56)
	holder.Size = UDim2.fromOffset(104, 104)
	holder.BackgroundColor3 = P.BG
	holder.BackgroundTransparency = 0.1
	holder.BorderSizePixel = 0
	holder.ZIndex = 21
	local st = Instance.new("UIStroke")
	st.Color = P.CYAN_DIM
	st.Thickness = 1
	st.Parent = holder

	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	face.BorderSizePixel = 0
	face.Position = UDim2.fromOffset(4, 4)
	face.Size = UDim2.fromOffset(96, 96)
	face.Image = ("rbxthumb://type=AvatarBust&id=%d&w=150&h=150"):format(player.UserId)
	face.ResampleMode = Enum.ResamplerMode.Pixelated
	face.ZIndex = 21
	face.Parent = holder

	-- the same glass the rest of the game reads through, so the portrait looks
	-- captured by the facility rather than pasted in from the avatar shop
	local lines = Instance.new("ImageLabel")
	lines.Name = "Lines"
	lines.BackgroundTransparency = 1
	lines.BorderSizePixel = 0
	lines.Position = UDim2.fromOffset(4, 4)
	lines.Size = UDim2.fromOffset(96, 96)
	lines.Image = "rbxassetid://75481537065425" -- the shared 64 px scanline tile
	lines.ImageTransparency = 0.55
	lines.ScaleType = Enum.ScaleType.Tile
	lines.TileSize = UDim2.fromOffset(64, 64)
	lines.ResampleMode = Enum.ResamplerMode.Pixelated
	lines.ZIndex = 22
	lines.Parent = holder

	-- four corner brackets, the machine's own way of framing a reading
	for _, c in ipairs({ { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } }) do
		for _, seg in ipairs({ { 12, 2 }, { 2, 12 } }) do
			local t = Instance.new("Frame")
			t.AnchorPoint = Vector2.new(c[1], c[2])
			t.Position = UDim2.new(c[1], c[3] * 2, c[2], c[4] * 2)
			t.Size = UDim2.fromOffset(seg[1], seg[2])
			t.BackgroundColor3 = P.ACCENT
			t.BorderSizePixel = 0
			t.ZIndex = 23
			t.Parent = holder
		end
	end
	holder.Parent = parent
end

local function buildPersonnel()
	personnelPanel = Instance.new("Frame")
	personnelPanel.Name = "Personnel"
	personnelPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	personnelPanel.Position = UDim2.fromScale(0.5, 0.5)
	personnelPanel.Size = UDim2.fromOffset(470, 60 + #Menu.Personnel * 34 + 60)
	personnelPanel.BackgroundColor3 = P.PLATE
	personnelPanel.BackgroundTransparency = 0.05
	personnelPanel.BorderSizePixel = 0
	personnelPanel.ZIndex = 20
	personnelPanel.Visible = false
	local st = Instance.new("UIStroke")
	st.Color = P.ACCENT
	st.Thickness = 2
	st.Parent = personnelPanel
	local title = newLabel(personnelPanel, "Title", UDim2.new(1, -32, 0, 26), P.CYAN_HI, 22)
	title.Position = UDim2.fromOffset(18, 18)
	title.ZIndex = 21
	title.Text = Menu.spaced("PERSONNEL FILE")
	buildMugshot(personnelPanel)
	personnelRows = {}
	for i, row in ipairs(Menu.Personnel) do
		local y = 60 + (i - 1) * 34
		local k = newLabel(personnelPanel, "Key" .. i, UDim2.new(0, 160, 0, 20), P.CYAN_DIM, 14)
		k.Position = UDim2.fromOffset(18, y)
		k.ZIndex = 21
		k.Text = row.label
		-- The rows stop short of the portrait: the first three sit beside it,
		-- so their values are clipped to the free column rather than running
		-- under the frame.
		local beside = y < 56 + 104
		local v = newLabel(personnelPanel, "Val" .. i, UDim2.new(0, beside and 140 or 260, 0, 20),
			P.CYAN_HI, 14)
		v.Position = UDim2.fromOffset(182, y)
		v.ZIndex = 21
		v.TextTruncate = Enum.TextTruncate.AtEnd
		personnelRows[i] = v
	end
	local close = Instance.new("TextButton")
	close.Name = "Btn_CLOSE"
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -18)
	close.Size = UDim2.fromOffset(160, 40)
	close.BackgroundColor3 = P.BG
	close.BackgroundTransparency = 0.15
	close.BorderSizePixel = 0
	close.Font = FONT
	close.TextSize = 18
	close.TextColor3 = P.CYAN
	close.Text = Menu.spaced("BACK")
	close.AutoButtonColor = false
	close.ZIndex = 21
	close.Selectable = true
	local cs = Instance.new("UIStroke")
	cs.Color = P.CYAN_DIM
	cs.Thickness = 1
	cs.Parent = close
	close.Parent = personnelPanel
	personnelPanel.Parent = root
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "KenopsiaMenu"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- BETWEEN the machine (50) and the CRT glass (60), not above both: the
	-- scanlines, vignette, refresh band and blip live on the overlay gui, so a
	-- menu ordered above it would be the one surface in the game with no glass
	-- on it. 55 covers the machine and still reads through the same tube.
	gui.DisplayOrder = 55
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = P.BG
	root.BorderSizePixel = 0
	root.Parent = gui

	buildBackground()
	buildTitle()
	buildRows()
	buildDetail()
	buildChrome()
	buildPersonnel()
	gui.Parent = playerGui
end

-- DIORAMA --------------------------------------------------------------------
-- Client-side, 3000 studs up, wrapped in its own shell so no sky can show
-- through. 19 parts, 2 lights, everything anchored and non-colliding.

local function part(parent, name, size, cf, colour, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildDiorama()
	if diorama then return end
	local D = Menu.Diorama
	local o = Vector3.new(D.Origin[1], D.Origin[2], D.Origin[3])
	local m = Instance.new("Model")
	m.Name = "KenopsiaMenuSet"

	local dark = Color3.fromRGB(14, 22, 28)
	local mid = Color3.fromRGB(22, 34, 42)
	local cold = Color3.fromRGB(150, 226, 245)

	part(m, "Ground", Vector3.new(D.Ground.w, 1, D.Ground.d), CFrame.new(o), mid)
	-- shell: back, two sides, ceiling. The camera sits at +Z, so the back wall
	-- is at -Z and the shell is deeper than the camera's own offset.
	local S = D.Shell
	part(m, "ShellBack", Vector3.new(S.w, S.h, 2), CFrame.new(o + Vector3.new(0, S.h / 2, -S.d / 2)), dark,
		Enum.Material.SmoothPlastic)
	part(m, "ShellLeft", Vector3.new(2, S.h, S.d), CFrame.new(o + Vector3.new(-S.w / 2, S.h / 2, 0)), dark,
		Enum.Material.SmoothPlastic)
	part(m, "ShellRight", Vector3.new(2, S.h, S.d), CFrame.new(o + Vector3.new(S.w / 2, S.h / 2, 0)), dark,
		Enum.Material.SmoothPlastic)
	part(m, "ShellTop", Vector3.new(S.w, 2, S.d), CFrame.new(o + Vector3.new(0, S.h, 0)), dark,
		Enum.Material.SmoothPlastic)

	-- the gate the subject is standing in front of
	part(m, "GatePostL", Vector3.new(2, 16, 2), CFrame.new(o + Vector3.new(-7, 8, -14)), mid)
	part(m, "GatePostR", Vector3.new(2, 16, 2), CFrame.new(o + Vector3.new(7, 8, -14)), mid)
	part(m, "GateLintel", Vector3.new(18, 2, 2), CFrame.new(o + Vector3.new(0, 16, -14)), mid)
	part(m, "LampHousing", Vector3.new(3, 1.4, 2), CFrame.new(o + Vector3.new(0, 14.6, -12.6)), dark)
	dioLamp = part(m, "Lamp", Vector3.new(2.2, 0.5, 1.4), CFrame.new(o + Vector3.new(0, 14.1, -12.6)),
		cold, Enum.Material.Neon)
	dioLampLight = Instance.new("PointLight")
	dioLampLight.Brightness = 2.1
	dioLampLight.Range = 34
	dioLampLight.Color = cold
	dioLampLight.Shadows = false
	dioLampLight.Parent = dioLamp

	-- a fence line running off to one side, and a fill light behind it so the
	-- posts read as silhouettes rather than as black sticks
	part(m, "FenceRail", Vector3.new(44, 0.4, 0.4), CFrame.new(o + Vector3.new(20, 6, -10)), mid,
		Enum.Material.Metal)
	local posts = math.max(2, Menu.Diorama.FenceCount)
	for i = 1, posts do
		local x = 20 - 22 + (i - 1) * (44 / (posts - 1))
		part(m, "FencePost" .. i, Vector3.new(0.5, 7, 0.5), CFrame.new(o + Vector3.new(x, 3.5, -10)), mid,
			Enum.Material.Metal)
	end
	local fill = Instance.new("PointLight")
	fill.Brightness = 0.9
	fill.Range = 60
	fill.Color = Color3.fromRGB(90, 150, 190)
	fill.Shadows = false
	fill.Parent = m:FindFirstChild("ShellBack")

	for i = 1, Menu.Diorama.CrateCount do
		local x = -18 + (i - 1) * 5
		local z = -4 - (i % 2) * 3
		part(m, "Crate" .. i, Vector3.new(3.4, 3.4, 3.4),
			CFrame.new(o + Vector3.new(x, 1.7, z)) * CFrame.Angles(0, math.rad(i * 17), 0), mid,
			Enum.Material.WoodPlanks)
	end

	m.Parent = workspace
	diorama = m
	local c = Menu.Diorama.Cam
	dioCamBase = {
		eye = o + Vector3.new(c.dx, c.dy, c.dz),
		look = o + Vector3.new(c.lx, c.ly, c.lz),
	}
end

local function destroyDiorama()
	if diorama then
		diorama:Destroy()
		diorama = nil
	end
	dioLamp, dioLampLight, dioCamBase = nil, nil, nil
end

-- SELECTION ------------------------------------------------------------------

local function applyRowColours()
	for i, b in ipairs(rowButtons) do
		local on = i == selected
		b.TextColor3 = on and P.INK or P.CYAN
		b.TextTransparency = on and 0 or 0.25
		local bullet = b:FindFirstChild("Bullet")
		if bullet then bullet.Visible = on end
	end
end

local function applyDetail()
	local entry = Menu.Entries[selected]
	if not entry then return end
	detailHead.Text = "/ /  " .. entry.label
	for i, l in ipairs(detailLines) do
		local line = entry.detail[i]
		l.Text = line or ""
		l.Visible = line ~= nil
	end
end

-- One frame of scrambled glyphs on the row the streak just landed on. Two
-- writes, and it makes the landing feel like a relay closing.
local SCRAMBLE = "#%&*+=/\\|<>"
local function glitchRow(i)
	if not motionOk() then return end
	local b = rowButtons[i]
	local entry = Menu.Entries[i]
	if not (b and entry) then return end
	local chars = {}
	for c in string.gmatch(entry.label, ".") do chars[#chars + 1] = c end
	for _ = 1, 3 do
		local at = math.random(#chars)
		if chars[at] ~= " " then
			chars[at] = string.sub(SCRAMBLE, math.random(#SCRAMBLE), math.random(#SCRAMBLE))
		end
	end
	b.Text = Menu.spaced(table.concat(chars))
	task.delay(STEP, function()
		if b.Parent then b.Text = Menu.spaced(entry.label) end
	end)
end

local streakToken = 0
local function moveStreak(i, animate)
	streakToken = streakToken + 1
	local token = streakToken
	local mobile = isMobile()
	local target = Menu.streakY(i, mobile)
	streak.Visible = true
	if not animate or not motionOk() then
		streak.Position = UDim2.fromOffset(Menu.Layout.StreakX, target)
		return
	end
	local from = streak.Position.Y.Offset
	local steps = Menu.Streak.Steps
	task.spawn(function()
		-- Stepped, not tweened: the machine moves on its grid. The last step
		-- overshoots and the settle lands it -- that overshoot is the whole
		-- reason the bar reads as snapping rather than sliding.
		local dir = target >= from and 1 or -1
		for s = 1, steps do
			if token ~= streakToken then return end
			local t = s / steps
			local y = from + (target - from) * t
			if s == steps then y = target + dir * Menu.Streak.OvershootPx end
			streak.Position = UDim2.fromOffset(Menu.Layout.StreakX, math.floor(y + 0.5))
			task.wait(STEP)
		end
		if token ~= streakToken then return end
		streak.Position = UDim2.fromOffset(Menu.Layout.StreakX, target)
	end)
end

local function setSelected(i, animate, quiet)
	i = math.clamp(i, 1, #Menu.Entries)
	local changed = i ~= selected
	selected = i
	moveStreak(i, animate and changed)
	applyRowColours()
	applyDetail()
	if changed then
		if not quiet then sfx("Hover") end
		glitchRow(i)
		-- the set acknowledges the move: the gate lamp drops for one beat
		lampDropUntil = os.clock() + Menu.Diorama.LampBlink
	end
	if platform() == "Console" and GuiService.SelectedObject ~= rowButtons[i] then
		GuiService.SelectedObject = rowButtons[i]
	end
end

-- SUB-PANELS -----------------------------------------------------------------

-- The machine screens are driven by KenopsiaClient's packet handler, which
-- calls hideAll() on every lobby packet. While the menu is showing one of them
-- a packet would blank it under the player's hands, so ownership means holding
-- it visible until we let go.
local function holdVisible(frame)
	local conn = frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then frame.Visible = true end
	end)
	return function()
		conn:Disconnect()
		frame.Visible = false
	end
end

-- Phosphor -> cold, remembering the authored colour so the panel goes back
-- exactly as it was when the machine takes it over again.
local COLD_MAP = {
	["78FFAA"] = "CYAN_HI",
	["8CE8AE"] = "CYAN",
	["2E6B4A"] = "CYAN_DIM",
}
local function retint(node, on)
	for _, d in ipairs(node:GetDescendants()) do
		for _, prop in ipairs({ "TextColor3", "BackgroundColor3", "ImageColor3", "Color" }) do
			local ok, value = pcall(function() return d[prop] end)
			if ok and typeof(value) == "Color3" then
				local attr = "Authored_" .. prop
				if on then
					local key = COLD_MAP[string.upper(value:ToHex())]
					if key then
						if d:GetAttribute(attr) == nil then d:SetAttribute(attr, value) end
						pcall(function() d[prop] = P[key] end)
					end
				else
					local saved = d:GetAttribute(attr)
					if saved then
						pcall(function() d[prop] = saved end)
						d:SetAttribute(attr, nil)
					end
				end
			end
		end
	end
end

local briefingPage = 1

local function renderBriefing()
	local m = machineGui()
	local screen = m and m:FindFirstChild("Briefing")
	if not screen then return end
	local page = Menu.Briefing[briefingPage] or Menu.Briefing[1]
	local title = screen:FindFirstChild("Title")
	if title then title.Text = page.title end
	-- Row names are not guaranteed, so take BriefList's labels in layout order.
	local list = screen:FindFirstChild("BriefList")
	if list then
		local labels = {}
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("TextLabel") then labels[#labels + 1] = c end
		end
		table.sort(labels, function(a, b)
			return a.Position.Y.Offset + a.Position.Y.Scale * 1000
				< b.Position.Y.Offset + b.Position.Y.Scale * 1000
		end)
		for i, l in ipairs(labels) do
			l.Text = page.lines[i] or ""
			l.Visible = page.lines[i] ~= nil
		end
	end
	local pageLabel = screen:FindFirstChild("PageLabel")
	if pageLabel then
		pageLabel.Text = ("Page %d/%d"):format(briefingPage, #Menu.Briefing)
	end
	local nav = screen:FindFirstChild("NavBar")
	local gauge = nav and nav:FindFirstChild("Gauge")
	if gauge then
		for i = 1, 5 do
			local seg = gauge:FindFirstChild("Seg" .. i)
			if seg then seg.Visible = i <= math.floor(5 * briefingPage / #Menu.Briefing) end
		end
	end
end

local closeSubPanel -- forward

local function openBriefing()
	local m = machineGui()
	local screen = m and m:FindFirstChild("Briefing")
	if not screen then return end
	subPanel = "briefing"
	briefingPage = 1
	m.Enabled = true
	-- The briefing is shown by NOTHING else in the game (verified 25.08.2026),
	-- so its cold tint can simply stay: there is no machine path to restore for.
	retint(screen, true)
	for _, name in ipairs({ "Selection", "Info", "Status", "RoundCard", "Score", "Announce" }) do
		local s = m:FindFirstChild(name)
		if s then s.Visible = false end
	end
	renderBriefing()
	screen.Visible = true
	releaseHold = holdVisible(screen)

	local nav = screen:FindFirstChild("NavBar")
	if nav and not nav:FindFirstChild("MenuBack") then
		local back = Instance.new("TextButton")
		back.Name = "MenuBack"
		back.AnchorPoint = Vector2.new(0.5, 0)
		back.Position = UDim2.new(0.5, 0, 1, 14)
		back.Size = UDim2.fromOffset(150, 34)
		back.BackgroundColor3 = P.BG
		back.BackgroundTransparency = 0.1
		back.BorderSizePixel = 0
		back.Font = FONT
		back.TextSize = 16
		back.TextColor3 = P.CYAN
		back.Text = Menu.spaced("BACK")
		back.AutoButtonColor = false
		back.ZIndex = 12
		back.Selectable = true
		local st = Instance.new("UIStroke")
		st.Color = P.CYAN_DIM
		st.Parent = back
		back.Parent = nav
		back.Activated:Connect(function()
			sfx("Click")
			closeSubPanel()
		end)
	end
	for _, side in ipairs({ "ArrowL", "ArrowR" }) do
		local arrow = nav and nav:FindFirstChild(side)
		local hit = arrow and arrow:FindFirstChild("Hit")
		if hit and not hit:GetAttribute("MenuWired") then
			hit:SetAttribute("MenuWired", true)
			hit.Activated:Connect(function()
				if subPanel ~= "briefing" then return end
				sfx("Click")
				briefingPage = math.clamp(briefingPage + (side == "ArrowR" and 1 or -1), 1, #Menu.Briefing)
				renderBriefing()
			end)
		end
	end
end

local function openSettings()
	local m = machineGui()
	local panel = m and m:FindFirstChild("SettingsPanel")
	if not panel then return end
	subPanel = "settings"
	m.Enabled = true
	retint(panel, true)
	panel.Visible = true
end

local function openPersonnel()
	subPanel = "personnel"
	local now = os.clock()
	local joined = tonumber(player:GetAttribute("KenopsiaJoinedAt"))
	for i, row in ipairs(Menu.Personnel) do
		local label = personnelRows[i]
		local text
		if row.attr then
			local v = tonumber(player:GetAttribute(row.attr)) or 0
			text = string.format(row.format or "%d", v)
		elseif row.label == "SUBJECT" then
			text = string.upper(player.DisplayName)
		elseif row.label == "DESIGNATION" then
			text = Menu.designation(player.UserId)
		elseif row.label == "IN FACILITY" then
			text = Menu.clock(joined and (now - joined) or (now - openedAt))
		else
			text = "COMPLIANT"
		end
		label.Text = text
	end
	personnelPanel.Visible = true
	if platform() == "Console" then
		GuiService.SelectedObject = personnelPanel:FindFirstChild("Btn_CLOSE")
	end
end

function closeSubPanel()
	local m = machineGui()
	if subPanel == "briefing" then
		if releaseHold then
			releaseHold()
			releaseHold = nil
		end
	elseif subPanel == "settings" then
		local panel = m and m:FindFirstChild("SettingsPanel")
		if panel then
			panel.Visible = false
			retint(panel, false)
		end
	elseif subPanel == "personnel" then
		personnelPanel.Visible = false
	end
	subPanel = nil
	if m then m.Enabled = false end
	if platform() == "Console" then
		GuiService.SelectedObject = rowButtons[selected]
	end
end

-- ENTER ----------------------------------------------------------------------

local function runDither(outward)
	local D = Feel.Dither
	local reduced = not motionOk()
	ditherCard.BackgroundTransparency = 1
	ditherCard.Visible = true
	if reduced then
		ditherCard.Image = ""
		ditherCard.BackgroundTransparency = 0
		task.wait(D.ReducedSteps * STEP)
	else
		for n = 1, D.Steps do
			local i = outward and n or (D.Steps - n + 1)
			ditherCard.Image = D.Tiles[i] or D.Tiles[#D.Tiles]
			task.wait(STEP)
		end
	end
	if not outward then ditherCard.Visible = false end
end

local closeMenu -- forward

local function enterFacility()
	if not isOpen then return end
	sfx("Submit")
	local wash = root:FindFirstChild("Handoff")
	task.spawn(function()
		-- One step of the bar at full burn: it grows past the row and the
		-- label goes white inside it. This is the press's only feedback, so it
		-- has to be visible on a phone at arm's length.
		local row = rowButtons[selected]
		local w = streak.Size.X.Offset
		streak.Size = UDim2.fromOffset(w + 16, streak.Size.Y.Offset)
		streak.Position = streak.Position - UDim2.fromOffset(8, 0)
		if row then row.TextColor3 = P.WHITE end
		task.wait(STEP)
		streak.Size = UDim2.fromOffset(w, streak.Size.Y.Offset)
		streak.Position = streak.Position + UDim2.fromOffset(8, 0)
		if row then row.TextColor3 = P.INK end
		runDither(true)
		-- the phosphor handoff: two frames of green across the cold glass, so
		-- the palette change reads as deliberate rather than as a reskin
		if wash and motionOk() then
			wash.Visible = true
			wash.BackgroundTransparency = 0.35
			task.wait(STEP)
			wash.BackgroundTransparency = 0.7
			task.wait(STEP)
			wash.Visible = false
			wash.BackgroundTransparency = 1
		end
		closeMenu("entered")
	end)
end

local function activate(index)
	local entry = Menu.Entries[index]
	if not entry then return end
	if subPanel then return end
	if entry.id == "enter" then
		enterFacility()
		return
	end
	sfx("Click")
	if entry.id == "briefing" then
		openBriefing()
	elseif entry.id == "settings" then
		openSettings()
	elseif entry.id == "personnel" then
		openPersonnel()
	end
end

-- OPEN / CLOSE ---------------------------------------------------------------

local function applyPlatformSizing()
	if not root then return end
	local mobile = isMobile()
	local L, M = Menu.Layout, Menu.Mobile
	local rowH = mobile and M.RowH or L.RowH
	local rowW = mobile and M.RowW or L.RowW
	local textSize = mobile and M.RowTextSize or L.RowTextSize
	local titleW = mobile and M.TitleW or L.TitleW
	local titleH = titleW / aspect("Wordmark")
	for _, layer in ipairs({ titleGlowA, titleGlowB, titleImg }) do
		layer.Size = UDim2.fromOffset(titleW, titleH)
	end
	subLabel.Position = UDim2.fromOffset(L.TitleX + 4, L.TitleY + titleH + L.SubGap)
	rowsFrame.Size = UDim2.fromOffset(rowW, #Menu.Entries * (rowH + L.RowGap))
	for i, b in ipairs(rowButtons) do
		b.Position = UDim2.fromOffset(0, Menu.rowY(i, mobile))
		b.Size = UDim2.fromOffset(rowW, rowH)
		b.TextSize = textSize
	end
	streak.Size = UDim2.fromOffset(mobile and M.StreakW or L.StreakW, Menu.streakH(mobile))
	streak.Position = UDim2.fromOffset(L.StreakX, Menu.streakY(selected, mobile))
	-- On a phone the rows already reach across the screen; the detail card
	-- would sit on top of them, so it simply does not exist there.
	detailCard.Visible = isOpen and not (mobile and M.DetailHidden)
	local cells = mobile and M.Cells or 3
	for i, c in ipairs(cellFrames) do
		if isOpen then c.Visible = i <= cells end
	end
end

-- The hint bar speaks the device's own language. Every glyph segment carries a
-- text fallback (Glyphs.ButtonText), so joining them gives a readable line on
-- every platform without this file having to render button images.
local function refreshHint()
	local p = platform()
	if p == "Mobile" or p == "Tablet" then
		hintLabel.Text = "TAP AN ENTRY  -  TAP AGAIN TO CONFIRM"
		return
	end
	local line = "[{MenuNav}]  NAVIGATE      [{Confirm}]  SELECT"
	if Glyphs then
		local ok, text = pcall(function()
			local resolver = Glyphs.robloxResolver(UserInputService)
			return Glyphs.join(Glyphs.segments(line, Glyphs.platformFor(p), resolver))
		end)
		if ok and type(text) == "string" and text ~= "" then
			hintLabel.Text = text
			return
		end
	end
	hintLabel.Text = p == "Console" and "[DPAD]  NAVIGATE      [A]  SELECT"
		or "[W/S]  NAVIGATE      [ENTER]  SELECT"
end

local function refreshCells()
	if not cellFrames then return end
	local m = machineGui()
	local specs = {
		{ "SUBJECTS", ("%d / %d"):format(#Players:GetPlayers(),
			(m and m:GetAttribute("MaxPlayers")) or 4) },
		{ "NEXT CYCLE", (player:GetAttribute("KenopsiaActiveTrial") or "") ~= "" and "RUNNING" or "ARMED" },
		-- time in the FACILITY, not time on this screen: reopening the menu
		-- from the Info panel must not restart the clock.
		{ "SESSION", Menu.clock(os.clock() - (tonumber(player:GetAttribute("KenopsiaJoinedAt")) or openedAt)) },
	}
	for i, c in ipairs(cellFrames) do
		local spec = specs[i]
		if spec then
			local head, val = c:FindFirstChild("Head"), c:FindFirstChild("Value")
			if head and head.Text ~= spec[1] then head.Text = spec[1] end
			if val and val.Text ~= spec[2] then val.Text = spec[2] end
		end
	end
end

local function runBoot()
	bootToken = bootToken + 1
	local token = bootToken
	local B = Menu.Boot
	local function at(steps)
		return steps * STEP
	end

	task.spawn(function()
		runDither(false)
	end)

	task.delay(at(B.Chrome), function()
		if token ~= bootToken then return end
		for _, c in ipairs(root:GetChildren()) do
			if c.Name == "Tick" or c.Name == "BuildTag" then c.Visible = true end
		end
		local tag = root:FindFirstChild("BuildTag")
		if tag then tag.Text = "BUILD 2026.08.25" end
	end)

	task.delay(at(B.Title), function()
		if token ~= bootToken then return end
		titleImg.Visible = true
		subLabel.Visible = true
		local T = Menu.Title
		local scale = titleImg:FindFirstChild("Punch")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "Punch"
			scale.Parent = titleImg
		end
		task.spawn(function()
			if motionOk() then
				scale.Scale = T.PunchScale
				task.wait(STEP)
				scale.Scale = 1
				-- chromatic split collapsing onto the mark
				titleGlowA.Visible = true
				titleGlowB.Visible = true
				for s = T.ChromaSteps, 1, -1 do
					if token ~= bootToken then return end
					local dx = math.floor(T.ChromaPx * (s / T.ChromaSteps) + 0.5)
					titleGlowA.Position = titleImg.Position + UDim2.fromOffset(dx, 0)
					titleGlowB.Position = titleImg.Position + UDim2.fromOffset(-dx, 0)
					task.wait(STEP)
				end
			end
			titleGlowA.Visible = false
			titleGlowB.Visible = false
		end)
		task.spawn(function()
			typewrite(subLabel, "SUBJECT ORIENTATION TERMINAL // REV 2.4", Feel.Typewriter.BodyCps, token)
		end)
	end)

	for i, entry in ipairs(Menu.Entries) do
		task.delay(at(B.Rows + (i - 1) * B.RowStagger), function()
			if token ~= bootToken then return end
			local b = rowButtons[i]
			b.Visible = true
			task.spawn(function()
				typewrite(b, Menu.spaced(entry.label), Feel.Typewriter.BodyCps, token)
			end)
		end)
	end

	task.delay(at(B.Streak), function()
		if token ~= bootToken then return end
		setSelected(1, false, true)
		streak.Visible = true
		if not isMobile() then detailCard.Visible = true end
	end)

	task.delay(at(B.Hint), function()
		if token ~= bootToken then return end
		hintLabel.Visible = true
		refreshHint()
		local cells = isMobile() and Menu.Mobile.Cells or 3
		for i, c in ipairs(cellFrames) do c.Visible = i <= cells end
		refreshCells()
	end)
end

local function openMenu()
	if isOpen then return end
	isOpen = true
	openedAt = os.clock()
	local m = machineGui()
	if m then m.Enabled = false end
	player:SetAttribute("KenopsiaMenuOpen", true)
	buildDiorama()
	applyPlatformSizing()
	-- everything the boot sequence is going to bring in starts dark
	for _, b in ipairs(rowButtons) do b.Visible = false end
	streak.Visible = false
	titleImg.Visible = false
	titleGlowA.Visible = false
	titleGlowB.Visible = false
	subLabel.Visible = false
	hintLabel.Visible = false
	detailCard.Visible = false
	for _, c in ipairs(cellFrames) do c.Visible = false end
	gui.Enabled = true
	if platform() == "Console" then
		task.defer(function()
			GuiService.SelectedObject = rowButtons[selected]
		end)
	end
	runBoot()
end

function closeMenu(reason)
	if not isOpen then return end
	isOpen = false
	bootToken = bootToken + 1
	if subPanel then closeSubPanel() end
	gui.Enabled = false
	ditherCard.Visible = false
	player:SetAttribute("KenopsiaMenuOpen", false)
	destroyDiorama()
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType == Enum.CameraType.Scriptable then
		-- Hand the view back. CameraSubject was never touched, so Custom picks
		-- the player's own humanoid straight back up.
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end
	local m = machineGui()
	if m then m.Enabled = true end
	if platform() == "Console" and GuiService.SelectedObject
		and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	print("[MainMenu] closed (" .. tostring(reason) .. ")")
end

-- THE ONE STEPPED LOOP -------------------------------------------------------
-- Parallax, camera dolly, gate lamp and the session clock. Every writer here
-- compares before it writes, so a still menu costs 12 wakeups a second and
-- almost no property traffic.

task.spawn(function()
	local lastClock = -1
	local lastShard = nil
	local lastCam = nil
	local lampOn = true
	while true do
		task.wait(STEP)
		if isOpen then
			local now = os.clock()
			local t = now - openedAt

			if shardsImg and motionOk() then
				local I = Menu.Idle
				local ph = (t % I.ParallaxPeriod) / I.ParallaxPeriod
				local tri = 1 - math.abs(2 * ph - 1) -- 0..1..0
				local dx = math.floor(I.ParallaxPx * tri + 0.5)
				local dy = math.floor(I.ParallaxPyY * tri + 0.5)
				if lastShard == nil or lastShard[1] ~= dx or lastShard[2] ~= dy then
					lastShard = { dx, dy }
					shardsImg.Position = UDim2.new(0.36, dx, 0.05, dy)
				end
			end

			if dioCamBase then
				local cam = workspace.CurrentCamera
				if cam then
					local I = Menu.Idle
					local ph = (t % I.DollyPeriod) / I.DollyPeriod
					local offset = math.sin(ph * 2 * math.pi) * I.DollyStuds
					local eye = dioCamBase.eye + Vector3.new(offset, 0, 0)
					-- Assert ownership every step (read first, write only if it
					-- actually drifted): a respawn recreates the camera and
					-- resets CameraType, and the dolly stalls for several
					-- steps near its turning points, so keying only off the
					-- offset could leave the menu looking at the character.
					if cam.CameraType ~= Enum.CameraType.Scriptable then
						cam.CameraType = Enum.CameraType.Scriptable
						lastCam = nil
					end
					if cam.FieldOfView ~= Menu.Diorama.Fov then
						cam.FieldOfView = Menu.Diorama.Fov
					end
					local key = math.floor(offset * 100)
					if lastCam ~= key then
						lastCam = key
						cam.CFrame = CFrame.lookAt(eye, dioCamBase.look)
					end
				end
			end

			if dioLampLight then
				local want = now >= lampDropUntil
				if want ~= lampOn then
					lampOn = want
					dioLampLight.Brightness = want and 2.1 or 0.4
					if dioLamp then
						dioLamp.Color = want and Color3.fromRGB(150, 226, 245) or Color3.fromRGB(40, 66, 78)
					end
				end
			end

			local sec = math.floor(t)
			if sec ~= lastClock then
				lastClock = sec
				refreshCells()
			end
		end
	end
end)

-- INPUT ----------------------------------------------------------------------

build()

for i, b in ipairs(rowButtons) do
	b.Activated:Connect(function()
		if not isOpen then return end
		if selected ~= i then
			setSelected(i, true)
			if isMobile() then return end -- a phone taps once to select, once to confirm
		end
		activate(i)
	end)
	b.MouseEnter:Connect(function()
		if isOpen and not subPanel and not isMobile() then setSelected(i, true) end
	end)
end

local personnelClose = personnelPanel and personnelPanel:FindFirstChild("Btn_CLOSE")
if personnelClose then
	personnelClose.Activated:Connect(function()
		sfx("Click")
		closeSubPanel()
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not isOpen or processed then return end
	local k = input.KeyCode
	if subPanel then
		if k == Enum.KeyCode.Q or k == Enum.KeyCode.ButtonB then
			sfx("Click")
			closeSubPanel()
		end
		return
	end
	if k == Enum.KeyCode.W or k == Enum.KeyCode.Up or k == Enum.KeyCode.DPadUp then
		setSelected(Menu.step(selected, -1), true)
	elseif k == Enum.KeyCode.S or k == Enum.KeyCode.Down or k == Enum.KeyCode.DPadDown then
		setSelected(Menu.step(selected, 1), true)
	elseif k == Enum.KeyCode.E or k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter
		or k == Enum.KeyCode.ButtonA then
		activate(selected)
	end
end)

-- Console: the streak IS the focus indicator, so follow the engine's selection
-- rather than drawing a second ring on top of it.
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	if not isOpen or subPanel then return end
	local sel = GuiService.SelectedObject
	if not (sel and sel:IsDescendantOf(rowsFrame)) then return end
	local idx = sel:GetAttribute("EntryIndex")
	if idx and idx ~= selected then setSelected(idx, true) end
end)

-- FLOW -----------------------------------------------------------------------

-- A trial running means the player joined mid-cycle (or the room moved on
-- while they read the menu). The menu is not a wall: it gets out of the way
-- and does not come back on its own.
player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(function()
	if isOpen and (player:GetAttribute("KenopsiaActiveTrial") or "") ~= "" then
		closeMenu("trial started")
	end
end)

-- Settings is closed by KenopsiaClient's own Btn_CLOSE; notice and come back.
task.defer(function()
	local m = machineGui() or playerGui:WaitForChild("KenopsiaMachine", 30)
	if not m then return end
	machine = m
	m:GetAttributeChangedSignal("Platform"):Connect(function()
		applyPlatformSizing()
		refreshHint()
	end)
	local panel = m:WaitForChild("SettingsPanel", 10)
	if panel then
		panel:GetPropertyChangedSignal("Visible"):Connect(function()
			if subPanel == "settings" and not panel.Visible then closeSubPanel() end
		end)
	end

	-- The way back in: a MENU button beside SETTINGS on the Info screen, cloned
	-- from it at runtime so the place file needs no new instance.
	local info = m:FindFirstChild("Info")
	local settingsBtn = info and info:FindFirstChild("Btn_SETTINGS")
	if settingsBtn and not info:FindFirstChild("Btn_MENU") then
		local b = settingsBtn:Clone()
		b.Name = "Btn_MENU"
		b.Text = "MENU"
		b.Position = settingsBtn.Position + UDim2.fromOffset(0, 40)
		-- the clone carries SETTINGS' console glyph, which would advertise a
		-- prompt applyButtonHints() never updates for this button
		local stale = b:FindFirstChild("PadHint")
		if stale then stale:Destroy() end
		b.Parent = info
		b.Activated:Connect(function()
			if isOpen then return end
			sfx("Click")
			openMenu()
		end)
	end

	-- OPENING ORDER. Three things want the screen at join, in this order:
	-- the loading bridge (ReplicatedFirst, DisplayOrder 100), the content
	-- warning (which KenopsiaLoading makes visible only once the bridge has the
	-- machine), and then this menu.
	--
	-- Getting this wrong is silent and bad: opening as soon as this script runs
	-- disables the machine gui BEFORE KenopsiaLoading turns the warning on, so
	-- the content warning would never be shown to anybody. So wait for the
	-- bridge to go, then for the warning to have had its turn.
	local deadline = os.clock() + 25
	while playerGui:FindFirstChild("KenopsiaLoadingGui") and os.clock() < deadline do
		task.wait(0.1)
	end
	local warning = m:FindFirstChild("Warning")
	if warning then
		-- It may not be visible YET (the bridge sets it) or may be visible
		-- already; either way the menu opens when it is done. KenopsiaClient
		-- dismisses it after 6.5 s at the latest, so this cannot hang.
		if not warning.Visible then
			local seen = os.clock() + 2
			while not warning.Visible and os.clock() < seen do
				task.wait(0.1)
			end
		end
		if warning.Visible then
			local conn
			conn = warning:GetPropertyChangedSignal("Visible"):Connect(function()
				if warning.Visible then return end
				conn:Disconnect()
				openMenu()
			end)
			return
		end
	end
	openMenu()
end)

-- Preload: a five-image menu that pops in one plate at a time looks broken.
task.spawn(function()
	local list = {}
	for name in Menu.Images do
		local uri = img(name)
		if uri ~= "" then
			local l = Instance.new("ImageLabel")
			l.Image = uri
			list[#list + 1] = l
		end
	end
	if #list > 0 then
		pcall(function() ContentProvider:PreloadAsync(list) end)
	end
	for _, l in ipairs(list) do l:Destroy() end
end)

print("[MainMenu] ready (" .. tostring(#Menu.Entries) .. " entries)")
