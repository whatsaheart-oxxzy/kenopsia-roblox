-- RECALL client UI.
--
-- Presentation only. This module knows nothing about which answers are correct,
-- because the server never tells it - during the recall phase it receives the
-- masked grid and a shuffled candidate tray, and that is genuinely all the
-- information that exists on this machine.
--
-- Interaction: tap a blank cell to select it, then tap a symbol in the tray to
-- place it. Tapping a filled-in blank clears it. You can keep changing your mind
-- until the phase ends; only the final state is scored.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local IconPool = require(Shared.IconPool)
local Net = require(Shared.Net)

local player = Players.LocalPlayer
local RecallGrid = Net.get("RecallGrid")
local RecallSubmit = Net.get("RecallSubmit")

local RecallUI = {}

local CELL = 96
local PAD = 8

local gui: ScreenGui
local board: Frame
local tray: Frame
local prompt: TextLabel

local cellButtons: { [number]: TextButton } = {}
local selectedCell: number? = nil
local placed: { [number]: string } = {}
local blankCells: { [number]: boolean } = {}

local function iconImage(id: string): string
	local icon = IconPool.byId(id)
	return if icon then icon.image else ""
end

local function iconLabel(id: string): string
	local icon = IconPool.byId(id)
	return if icon then icon.label else id
end

-- Draw a symbol into a button. Falls back to the text label when the icon has
-- not been uploaded yet, so the minigame is playable with zero art.
local function paint(button: TextButton, id: string?)
	local image = button:FindFirstChild("Icon") :: ImageLabel?
	if not image then
		return
	end
	if id and id ~= "" then
		image.Image = iconImage(id)
		image.Visible = true
		button.Text = if iconImage(id) == "" then iconLabel(id) else ""
	else
		image.Image = ""
		image.Visible = false
		button.Text = ""
	end
end

local function makeButton(parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(CELL, CELL)
	button.BackgroundColor3 = Color3.fromRGB(22, 26, 20)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.Code
	button.TextScaled = true
	button.TextColor3 = Config.Colors.Accent
	button.Text = ""
	button.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.Colors.Accent
	stroke.Transparency = 0.5
	stroke.Thickness = 1
	stroke.Parent = button

	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.Size = UDim2.fromScale(0.8, 0.8)
	image.Position = UDim2.fromScale(0.1, 0.1)
	image.BackgroundTransparency = 1
	-- The one place Roblox lets you turn off bilinear filtering. A 64px PSX icon
	-- scaled up smooth looks like a mistake; scaled up hard it looks deliberate.
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.Parent = button

	return button
end

local function setSelected(cell: number?)
	selectedCell = cell
	for index, button in cellButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			local isSelected = index == cell
			stroke.Transparency = if isSelected then 0 else 0.5
			stroke.Thickness = if isSelected then 3 else 1
		end
	end
	prompt.Text = if cell then "CHOOSE A SYMBOL" else "SELECT A MISSING CELL"
end

local function clearBoard()
	for _, child in board:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for _, child in tray:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	cellButtons = {}
	placed = {}
	blankCells = {}
	selectedCell = nil
end

local function buildBoard(payload)
	clearBoard()

	local width = payload.width
	local height = payload.height
	board.Size = UDim2.fromOffset(width * (CELL + PAD) - PAD, height * (CELL + PAD) - PAD)

	local interactive = payload.phase == "recall"

	for cell = 1, width * height do
		local id = payload.grid[cell]
		local button = makeButton(board)
		button.LayoutOrder = cell
		cellButtons[cell] = button

		local isBlank = interactive and (id == nil or id == "")
		blankCells[cell] = isBlank

		if isBlank then
			button.BackgroundColor3 = Color3.fromRGB(12, 14, 11)
			button.Activated:Connect(function()
				if placed[cell] then
					-- Tapping a filled blank clears it.
					placed[cell] = nil
					paint(button, nil)
					RecallSubmit:FireServer(cell, "")
					setSelected(cell)
				else
					setSelected(if selectedCell == cell then nil else cell)
				end
			end)
		else
			paint(button, id)
		end
	end
end

local function buildTray(candidates: { string })
	for _, id in candidates do
		local button = makeButton(tray)
		paint(button, id)
		button.Activated:Connect(function()
			local cell = selectedCell
			if not cell or not blankCells[cell] then
				return
			end
			placed[cell] = id
			local target = cellButtons[cell]
			if target then
				paint(target, id)
			end
			RecallSubmit:FireServer(cell, id)
			setSelected(nil)
		end)
	end
end

function RecallUI.mount()
	gui = Instance.new("ScreenGui")
	gui.Name = "KenopsiaRecall"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(6, 8, 6)
	backdrop.BackgroundTransparency = 0.25
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	board = Instance.new("Frame")
	board.AnchorPoint = Vector2.new(0.5, 0.5)
	board.Position = UDim2.fromScale(0.5, 0.42)
	board.BackgroundTransparency = 1
	board.Parent = gui

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CELL, CELL)
	grid.CellPadding = UDim2.fromOffset(PAD, PAD)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = board

	prompt = Instance.new("TextLabel")
	prompt.Size = UDim2.new(1, 0, 0, 24)
	prompt.Position = UDim2.fromScale(0, 0.68)
	prompt.BackgroundTransparency = 1
	prompt.Font = Enum.Font.Code
	prompt.TextSize = 18
	prompt.TextColor3 = Config.Colors.Accent
	prompt.Text = ""
	prompt.Parent = gui

	tray = Instance.new("Frame")
	tray.AnchorPoint = Vector2.new(0.5, 0)
	tray.Position = UDim2.fromScale(0.5, 0.74)
	tray.Size = UDim2.new(0.9, 0, 0, CELL)
	tray.BackgroundTransparency = 1
	tray.Parent = gui

	local trayLayout = Instance.new("UIListLayout")
	trayLayout.FillDirection = Enum.FillDirection.Horizontal
	trayLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	trayLayout.Padding = UDim.new(0, PAD)
	trayLayout.Parent = tray

	RecallGrid.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end

		if payload.phase == "hide" then
			gui.Enabled = false
			clearBoard()
			return
		end

		gui.Enabled = true
		buildBoard(payload)

		if payload.phase == "memorize" then
			prompt.Text = "MEMORIZE"
			tray.Visible = false
		elseif payload.phase == "recall" then
			tray.Visible = true
			buildTray(payload.candidates or {})
			setSelected(nil)
		elseif payload.phase == "reveal" then
			prompt.Text = "SOLUTION"
			tray.Visible = false
		end
	end)

	return gui
end

return RecallUI
