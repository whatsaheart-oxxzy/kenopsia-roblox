--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = script.Parent.Parent.UI
local Motion = require(UI.Motion)
local SoundBank = require(UI.SoundBank)

local PHOSPHOR = Color3.fromHex("78FFAA")
local IDLE = Color3.fromHex("8CE8AE")
local DIM = Color3.fromHex("2E6B4A")
local BLOOD_BRIGHT = Color3.fromHex("E0342A")
local AMBER = Color3.fromHex("FFBA3C")

local TrialController = {}
TrialController.__index = TrialController

function TrialController.new(menu)
	local self = setmetatable({}, TrialController)
	self.menu = menu
	self.screens = menu.screens
	self.trial = self.screens:FindFirstChild("Trial")
	self.canteen = self.trial and self.trial:FindFirstChild("CanteenBoard")
	self.desk = self.trial and self.trial:FindFirstChild("InspectDesk")
	self.field = self.trial and self.trial:FindFirstChild("CalibrationField")
	self.timerLabel = self.trial and self.trial:FindFirstChild("TimerLabel")
	self.scoreLabel = self.trial and self.trial:FindFirstChild("ScoreLabel")
	self.token = nil

	local k = ReplicatedStorage:WaitForChild("Kenopsia")
	local remotes = k:WaitForChild("Remotes")
	self.stateRemote = remotes:WaitForChild("TrialState", 10)
	self.inputRemote = remotes:WaitForChild("TrialInput", 10)
	if not self.stateRemote or not self.inputRemote then
		warn("[TrialController] trial remotes missing")
		return self
	end

	self.stateRemote.OnClientEvent:Connect(function(p)
		if type(p) == "table" then self:onState(p) end
	end)

	self:wireDesk()
	return self
end

function TrialController:sendInput(payload)
	payload.token = self.token
	self.inputRemote:FireServer(payload)
end

function TrialController:hideBoards()
	if self.canteen then self.canteen.Visible = false end
	if self.desk then self.desk.Visible = false end
	if self.field then self.field.Visible = false end
end

function TrialController:startTimer(duration)
	local token = self.token
	local endAt = os.clock() + duration
	task.spawn(function()
		while self.token == token do
			local left = math.max(0, endAt - os.clock())
			if self.timerLabel then
				self.timerLabel.Text = string.format("0:%02d", math.ceil(left))
				self.timerLabel.TextColor3 = left < 5 and BLOOD_BRIGHT or AMBER
			end
			if left <= 0 then break end
			task.wait(0.2)
		end
	end)
end

function TrialController:onState(p)
	if p.token then self.token = p.token end
	local kind = p.kind

	if kind == "intro" then
		self.currentName = p.name
		local s = self.screens.TrialIntro
		local eyebrow = s:FindFirstChild("Eyebrow")
		local title = s:FindFirstChild("Title")
		local caption = s:FindFirstChild("Caption")
		if eyebrow then eyebrow.Text = string.format("PROGRAM %d OF %d", p.index, p.total) end
		if title then title.Text = p.name or "" end
		if caption then caption.Text = (p.verb and (p.verb .. "  \u{00B7}  ") or "") .. (p.caption or "") end
		self:hideBoards()
		self.menu:show("TrialIntro")
		SoundBank.standClear()
	elseif kind == "begin" then
		local title = self.trial and self.trial:FindFirstChild("Title")
		if title then title.Text = p.name or self.currentName or "" end
		if self.scoreLabel then self.scoreLabel.Text = "" end
		self.menu:show("Trial")
		self:startTimer(p.duration or 0)
	elseif kind == "canteen_board" then
		self:buildCanteen(p.board)
	elseif kind == "canteen_mask" then
		self:maskCanteen(p.blanks, p.tray)
	elseif kind == "qc_unit" then
		self:showUnit(p)
	elseif kind == "target" then
		self:showTarget(p)
	elseif kind == "trialResult" then
		self:showBoard("TrialResult", p.board, false)
	elseif kind == "finalResult" then
		self:showBoard("FinalResult", p.board, true)
		local w = self.screens.FinalResult:FindFirstChild("WinnerLabel")
		if w then w.Text = (p.winner and p.winner ~= "") and ("WINNER  \u{00B7}  " .. p.winner) or "" end
	end
end

-- CANTEEN PROTOCOL --------------------------------------------------------

function TrialController:buildCanteen(board)
	if not self.canteen then return end
	self:hideBoards()
	self.canteen.Visible = true
	local grid = self.canteen.Grid
	local template = self.canteen.GlyphCellTemplate
	for _, c in grid:GetChildren() do
		if c:IsA("TextButton") then c:Destroy() end
	end
	for _, b in self.canteen.Tray:GetChildren() do
		if b:IsA("TextButton") then b:Destroy() end
	end
	self.cells = {}
	self.blankSet = nil
	self.selectedGlyph = nil
	for i, glyph in board do
		local c = template:Clone()
		c.Name = "Cell" .. i
		c.Text = glyph
		c.LayoutOrder = i
		c.Visible = true
		c.Parent = grid
		self.cells[i] = c
		c.Activated:Connect(function()
			self:cellClicked(i)
		end)
	end
	local prompt = self.canteen:FindFirstChild("Prompt")
	if prompt then
		prompt.Text = "COMMIT THE TABLE TO MEMORY"
		prompt.TextColor3 = DIM
	end
end

function TrialController:maskCanteen(blanks, tray)
	if not self.canteen or not self.cells then return end
	self.blankSet = {}
	for _, i in blanks do
		self.blankSet[i] = true
		local c = self.cells[i]
		if c then
			c.Text = "?"
			c.TextColor3 = AMBER
			local st = c:FindFirstChildOfClass("UIStroke")
			if st then st.Color = AMBER end
		end
	end
	local prompt = self.canteen:FindFirstChild("Prompt")
	if prompt then
		prompt.Text = "SELECT A GLYPH, THEN RESTORE ITS CELL"
		prompt.TextColor3 = AMBER
	end
	local template = self.canteen.GlyphCellTemplate
	self.trayButtons = {}
	for j, glyph in tray do
		local b = template:Clone()
		b.Name = "Tray" .. j
		b.Text = glyph
		b.Size = UDim2.fromOffset(50, 50)
		b.LayoutOrder = j
		b.Visible = true
		b.Parent = self.canteen.Tray
		table.insert(self.trayButtons, b)
		b.Activated:Connect(function()
			self.selectedGlyph = glyph
			for _, tb in self.trayButtons do
				local st = tb:FindFirstChildOfClass("UIStroke")
				if st then st.Color = (tb == b) and PHOSPHOR or DIM end
				tb.TextColor3 = (tb == b) and PHOSPHOR or IDLE
			end
			SoundBank.click()
		end)
	end
end

function TrialController:cellClicked(i)
	if not (self.blankSet and self.blankSet[i] and self.selectedGlyph) then return end
	local c = self.cells[i]
	if c then
		c.Text = self.selectedGlyph
		c.TextColor3 = PHOSPHOR
	end
	self:sendInput({ kind = "assign", cell = i, glyph = self.selectedGlyph })
	SoundBank.submit()
end

-- QUALITY CONTROL ---------------------------------------------------------

function TrialController:wireDesk()
	if not self.desk then return end
	local function verdict(approve)
		if not self.currentUnit then return end
		if self.votedUnit == self.currentUnit then return end
		self.votedUnit = self.currentUnit
		self:sendInput({ kind = "verdict", i = self.currentUnit, approve = approve })
		SoundBank.submit()
	end
	local a = self.desk:FindFirstChild("Btn_APPROVE")
	local r = self.desk:FindFirstChild("Btn_REJECT")
	if a then a.Activated:Connect(function() verdict(true) end) end
	if r then r.Activated:Connect(function() verdict(false) end) end
end

function TrialController:showUnit(p)
	if not self.desk then return end
	if not self.desk.Visible then
		self:hideBoards()
		self.desk.Visible = true
	end
	self.currentUnit = p.i
	self.votedUnit = nil
	local feed = self.desk:FindFirstChild("FeedLabel")
	if feed then feed.Text = string.format("UNIT %d / %d", p.i, p.total) end
	local spec = self.desk:FindFirstChild("SpecCard")
	local item = self.desk:FindFirstChild("ItemCard")
	if spec and p.spec then
		spec.GlyphLabel.Text = p.spec.glyph
		spec.CodeLabel.Text = p.spec.code
	end
	if item and p.unit then
		item.GlyphLabel.Text = p.unit.glyph
		item.CodeLabel.Text = p.unit.code
		item.Position = UDim2.new(0.5, 16, 0, 8)
		Motion.press(item, { Position = UDim2.new(0.5, 16, 0, 14) })
	end
end

-- TARGET CALIBRATION ------------------------------------------------------

function TrialController:showTarget(p)
	if not self.field then return end
	if not self.field.Visible then
		self:hideBoards()
		self.field.Visible = true
	end
	if self.activeTarget then
		self.activeTarget:Destroy()
		self.activeTarget = nil
	end
	local t = self.field.TargetTemplate:Clone()
	t.Name = "Target" .. p.i
	t.Position = UDim2.fromScale(p.x, p.y)
	t.Size = UDim2.fromOffset(58, 58)
	t.TextSize = 44
	t.TextColor3 = BLOOD_BRIGHT
	t.Visible = true
	t.Parent = self.field
	self.activeTarget = t
	Motion.to(t, TweenInfo.new(p.window or 1.2, Enum.EasingStyle.Linear), {
		Size = UDim2.fromOffset(26, 26),
		TextSize = 18,
	})
	t.Activated:Connect(function()
		if self.hitTaken == p.i then return end
		self.hitTaken = p.i
		self:sendInput({ kind = "hit", i = p.i, x = p.x, y = p.y })
		t.TextColor3 = PHOSPHOR
		SoundBank.click()
		task.delay(0.12, function()
			if t.Parent then t:Destroy() end
		end)
	end)
end

-- RESULTS ------------------------------------------------------------------

function TrialController:showBoard(screenName, board, final)
	local s = self.screens:FindFirstChild(screenName)
	if not s then return end
	local oldBoard = s:FindFirstChild("Board")
	if oldBoard then oldBoard.Visible = false end
	local oldWinner = s:FindFirstChild("Winner")
	if oldWinner then oldWinner.Visible = false end
	local list = s:FindFirstChild("ResultList")
	if list then
		for i = 1, 4 do
			local row = list:FindFirstChild("Row" .. i)
			if row then
				local e = board and board[i]
				row.Visible = e ~= nil
				if e then
					row.NameLabel.Text = e.displayName or ""
					row.ScoreLabel.Text = final and (tostring(e.score or 0) .. " PTS") or tostring(e.score or 0)
					row.PointsLabel.Text = final and "" or ("+" .. tostring(e.points or 0) .. " PTS")
				end
			end
		end
	end
	self:hideBoards()
	self.menu:show(screenName)
	SoundBank.granted()
end

return TrialController
