--!nonstrict
-- RETRO CURSOR (Gate M1 -- §3 Stilvorgaben, §4 update rule).
--
-- A 24x24 pixel arrow built from Frames: off-white fill, graphite contour, no
-- image asset, no glow, no red. All four of those are spec requirements, and the
-- ImageLabel this replaces broke three of them.
--
-- WHY THIS MODULE EXISTS ------------------------------------------------------
--
-- The cursor used to be moved by two lines inside MenuController's startAmbient
-- RenderStepped loop. §3C deleted that loop along with the rest of the horror
-- layer -- correctly, it was decoration -- but nothing replaced the two lines
-- that positioned the cursor. What shipped was:
--
--   * applyCursor() set MouseIconEnabled = false, hiding the system pointer;
--   * KenopsiaCursor.Cursor sat at Position (-100, -100) and was never moved;
--   * the KenopsiaCursor ScreenGui was Enabled = false anyway, so even the
--     parked ImageLabel never drew.
--
-- The result was a menu with NO visible pointer at all. Clicks still landed, so
-- an automated pass sees nothing wrong -- which is how it survived the 3B/3C
-- live test.
--
-- WHY MouseMovement AND NOT RenderStepped -------------------------------------
--
-- §4 forbids a permanent RenderStepped loop outright. It is also the better
-- mechanism here: InputChanged fires only when the mouse actually moves, so a
-- still mouse costs nothing, and "only appears under mouse control" falls out of
-- the input type rather than needing a separate check.
--
-- ONE POINTER, ALWAYS ---------------------------------------------------------
--
-- MouseIconEnabled is driven from the same refresh that decides our own
-- visibility, so the two can never disagree. Either the system icon is showing
-- or ours is -- never both, and never neither, which was the shipped bug.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)

local Cursor = {}
Cursor.__index = Cursor

local GUI_NAME = "KenopsiaCursor"

-- One arrow pixel = 2 screen px, so the 12-unit grid renders at exactly 24x24.
local PX = 2
local GRID = 12

-- The arrow as one horizontal run per row, top row first: {startX, width} in
-- grid units. A pointer rather than a crosshair -- this is a menu that is asking
-- to be clicked, and a reticle reads as "aim here", not "click here".
--
--   X            row 1
--   XX
--   XXX
--   XXXX
--   XXXXX
--   XXXXXX
--   XXXXXXX
--   XXXXXXXX
--   XXXXXXXXX    row 9  (widest)
--   XXXXX        row 10 (shoulder)
--      XXX       row 11 (tail)
--       XXX      row 12
local ROWS = {
	{ 0, 1 }, { 0, 2 }, { 0, 3 }, { 0, 4 }, { 0, 5 }, { 0, 6 },
	{ 0, 7 }, { 0, 8 }, { 0, 9 }, { 0, 5 }, { 3, 3 }, { 4, 3 },
}

-- Touch and gamepad keep their own input affordances, per spec. Keyboard does
-- NOT hide the cursor: typing a room code is still mouse-and-keyboard mode, and
-- blinking the pointer out mid-entry would be a bug, not a feature.
local function hidesPointer(inputType)
	if inputType == Enum.UserInputType.Touch then return true end
	-- Gamepad1..Gamepad8 -- matched by prefix so a new pad enum cannot slip past.
	return string.sub(inputType.Name, 1, 7) == "Gamepad"
end

function Cursor.new()
	local self = setmetatable({}, Cursor)
	self.conns = {}
	self.enabled = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Clear any earlier cursor first. StarterGui may still be cloning the old
	-- ImageLabel version in, and two ScreenGuis sharing a name make every
	-- FindFirstChild ambiguous. Order-independent by design: this is correct
	-- whether or not the StarterGui original has been deleted yet.
	local stale = playerGui:FindFirstChild(GUI_NAME)
	while stale do
		stale:Destroy()
		stale = playerGui:FindFirstChild(GUI_NAME)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = playerGui
	self.gui = gui

	-- AnchorPoint stays (0,0): the arrow's hotspot is its tip, which is the
	-- top-left grid cell, so the frame position IS the pointer position.
	local root = Instance.new("Frame")
	root.Name = "Arrow"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(GRID * PX, GRID * PX)
	root.Position = UDim2.fromOffset(-100, -100)
	root.Parent = gui
	self.root = root

	local function run(x, y, w, h, color, z)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.Position = UDim2.fromOffset(x * PX, y * PX)
		f.Size = UDim2.fromOffset(w * PX, h * PX)
		f.ZIndex = z
		f.Parent = root
	end

	-- Contour first: each run grown by one unit in every direction. The rows
	-- overlap, so their union is a solid graphite outline around the whole
	-- shape -- which a UIStroke could not give us, since a stroke follows each
	-- frame's own rectangle rather than the silhouette of its siblings.
	for y, r in ROWS do
		run(r[1] - 1, y - 2, r[2] + 2, 3, Theme.Street.Ink, 1)
	end
	for y, r in ROWS do
		run(r[1], y - 1, r[2], 1, Theme.Street.OffWhite, 2)
	end

	self:_bind()
	self:_refresh()
	return self
end

function Cursor:_move()
	local m = UserInputService:GetMouseLocation()
	-- GetMouseLocation is measured below the top bar; the ScreenGui ignores the
	-- inset, so the inset has to be added back or the arrow floats above the
	-- real pointer by the height of the bar. Read live rather than cached --
	-- the inset changes when CoreGui elements come and go.
	local inset = GuiService:GetGuiInset()
	self.root.Position = UDim2.fromOffset(m.X + inset.X, m.Y + inset.Y)
end

function Cursor:_bind()
	table.insert(self.conns, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_move()
		end
	end))

	-- gameProcessedEvent is deliberately ignored above: the pointer must keep
	-- tracking while the mouse is over a button, which is exactly when the event
	-- comes through as processed.

	table.insert(self.conns, UserInputService.LastInputTypeChanged:Connect(function()
		self:_refresh()
	end))

	self:_move()
end

function Cursor:_refresh()
	local wanted = self.enabled
		and UserInputService.MouseEnabled
		and not hidesPointer(UserInputService:GetLastInputType())

	self.gui.Enabled = wanted
	-- The system icon is the inverse of ours, set from this one place so the two
	-- cannot drift apart.
	pcall(function()
		UserInputService.MouseIconEnabled = not wanted
	end)
	if wanted then self:_move() end
end

function Cursor:setEnabled(on)
	self.enabled = on and true or false
	self:_refresh()
end

-- Restores the system pointer. §2 requires the menu to hand the cursor back
-- untouched when it releases control, so this must run on teardown, not just on
-- the settings toggle.
function Cursor:destroy()
	for _, conn in self.conns do
		if conn.Connected then conn:Disconnect() end
	end
	table.clear(self.conns)
	pcall(function()
		UserInputService.MouseIconEnabled = true
	end)
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return Cursor
