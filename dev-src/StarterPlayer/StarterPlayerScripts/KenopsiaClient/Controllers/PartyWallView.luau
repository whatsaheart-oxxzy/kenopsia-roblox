--!nonstrict
-- PARTY WALL VIEW.
--
-- Builds the diegetic SessionDisplay interface and nothing else. The view owns
-- layout, focus and page rendering; SessionWallController owns network state,
-- and RoomService remains the only authority allowed to change a party.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local SoundBank = require(UI.SoundBank)

local PartyWallView = {}
PartyWallView.__index = PartyWallView

local ROW_HEIGHT = Theme.Party.RowHeight
local ROW_GAP = Theme.Party.RowGap

local function connect(self, signal, handler, bucket)
	local conn = signal:Connect(handler)
	table.insert(bucket or self.connections, conn)
	return conn
end

local function label(parent, name, text, font, size, color)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Font = font
	item.Text = text
	item.TextSize = size
	item.TextColor3 = color
	item.TextWrapped = false
	item.Parent = parent
	return item
end

local function isRendered(object, page)
	local node = object
	while node and node ~= page.Parent do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

local function pageFrame(self, name, title)
	local page = Instance.new("Frame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.fromScale(1, 1)
	page.Visible = false
	page:SetAttribute("PartyPage", name)
	page.Parent = self.root
	self.pages[name] = page

	local heading = label(page, "Heading", title, Theme.TitleFont, 42, Theme.Cold.Bright)
	heading.Position = UDim2.fromOffset(70, 22)
	heading.Size = UDim2.new(1, -140, 0, 54)
	heading.TextXAlignment = Enum.TextXAlignment.Center
	heading.TextYAlignment = Enum.TextYAlignment.Center

	local rule = Instance.new("Frame")
	rule.Name = "TitleRule"
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0, 82)
	rule.Size = UDim2.new(0.76, 0, 0, 1)
	rule.BackgroundColor3 = Theme.Cold.Dim
	rule.BackgroundTransparency = Theme.Party.RuleTransparency
	rule.BorderSizePixel = 0
	rule.Parent = page

	local description = label(page, "Description", "", Theme.MonoFont, 19, Theme.Cold.Dim)
	description.AnchorPoint = Vector2.new(0.5, 0)
	description.Position = UDim2.new(0.5, 0, 0, 506)
	description.Size = UDim2.new(0.84, 0, 0, 48)
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Center
	description.TextYAlignment = Enum.TextYAlignment.Center
	self.descriptions[name] = description

	local notice = label(page, "Notice", "", Theme.MonoFont, 18, Theme.Cold.Dim)
	notice.AnchorPoint = Vector2.new(0.5, 0)
	notice.Position = UDim2.new(0.5, 0, 0, 564)
	notice.Size = UDim2.new(0.86, 0, 0, 26)
	notice.TextXAlignment = Enum.TextXAlignment.Center
	notice.TextYAlignment = Enum.TextYAlignment.Center
	self.notices[name] = notice

	return page
end

local function menuList(parent, y, height, widthScale)
	local list = Instance.new("Frame")
	list.Name = "MenuList"
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0, y)
	list.Size = UDim2.new(widthScale or 0.82, 0, 0, height)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

local function paintRow(self, row)
	local focused = row.enabled and (row.hovered or row.selected)
	row.bar.Visible = focused
	row.marker.Visible = focused
	row.button.TextColor3 = if focused then Theme.Cold.OnStreak else Theme.Cold.Text
	row.button.TextTransparency = if row.enabled then (focused and 0 or Theme.Party.InactiveTransparency) else 0.62
	if focused and row.description then
		local target = self.descriptions[row.pageName]
		if target then
			target.Text = row.description
		end
	end
end

local function selectionRow(self, parent, pageName, name, text, description, order, callback, bucket)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	button.LayoutOrder = order
	button.Font = Theme.TitleFont
	button.Text = text
	button.TextSize = 29
	button.TextColor3 = Theme.Cold.Text
	button.TextTransparency = Theme.Party.InactiveTransparency
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.ZIndex = 3
	button.Parent = parent

	local bar = Instance.new("Frame")
	bar.Name = "SelectionBar"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Size = UDim2.new(1, -8, 1, -4)
	bar.BackgroundColor3 = Theme.Cold.Streak
	bar.BackgroundTransparency = 0.06
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.ZIndex = 1
	bar.Parent = button

	local marker = Instance.new("Frame")
	marker.Name = "CopperMarker"
	marker.AnchorPoint = Vector2.new(0, 0.5)
	marker.Position = UDim2.new(0, 14, 0.5, 0)
	marker.Size = UDim2.fromOffset(7, 30)
	marker.BackgroundColor3 = Theme.Party.Marker
	marker.BorderSizePixel = 0
	marker.Visible = false
	marker.ZIndex = 4
	marker.Parent = button

	local row = {
		button = button,
		bar = bar,
		marker = marker,
		pageName = pageName,
		description = description,
		enabled = true,
		hovered = false,
		selected = false,
	}
	self.rows[button] = row

	connect(self, button.MouseEnter, function()
		if not row.enabled then
			return
		end
		row.hovered = true
		paintRow(self, row)
		SoundBank.hover()
	end, bucket)
	connect(self, button.MouseLeave, function()
		row.hovered = false
		paintRow(self, row)
	end, bucket)
	connect(self, button.SelectionGained, function()
		if not row.enabled then
			return
		end
		row.selected = true
		paintRow(self, row)
		SoundBank.hover()
	end, bucket)
	connect(self, button.SelectionLost, function()
		row.selected = false
		paintRow(self, row)
	end, bucket)
	connect(self, button.Activated, function()
		if not row.enabled then
			return
		end
		if description and self.descriptions[pageName] then
			self.descriptions[pageName].Text = description
		end
		SoundBank.click()
		if callback then
			callback()
		end
	end, bucket)

	return row
end

local function setRowEnabled(self, row, enabled)
	if not row then
		return
	end
	row.enabled = enabled == true
	row.button:SetAttribute("Disabled", not row.enabled)
	row.button.Active = self.interactive and row.enabled
	row.button.Interactable = self.interactive and row.enabled
	row.button.Selectable = self.interactive and row.enabled
	if not row.enabled then
		row.hovered = false
		row.selected = false
	end
	paintRow(self, row)
end

local function setRowText(row, text)
	if row then
		row.button.Text = text
	end
end

local function invoke(self, name, ...)
	local callback = self.callbacks[name]
	if callback then
		callback(...)
	end
end

function PartyWallView.new(gui, callbacks, options)
	local self = setmetatable({}, PartyWallView)
	self.gui = gui
	self.callbacks = callbacks or {}
	self.options = options or {}
	self.connections = {}
	self.browseConnections = {}
	self.pages = {}
	self.descriptions = {}
	self.notices = {}
	self.rows = {}
	self.interactive = false
	self.currentPage = nil
	self.createPublic = true
	self.createJoinPolicy = "Open"
	self.room = nil
	self.currentRequestUserId = nil
	gui.CanvasSize = Theme.Party.Canvas

	local root = Instance.new("Frame")
	root.Name = "PartyWall"
	root.BackgroundColor3 = Theme.Cold.Ground
	root.BackgroundTransparency = Theme.Party.PanelTransparency
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.Parent = gui
	self.root = root

	local outline = Instance.new("UIStroke")
	outline.Color = Theme.Cold.Dim
	outline.Thickness = 1
	outline.Transparency = 0.35
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Parent = root

	local scanlines = Instance.new("ImageLabel")
	scanlines.Name = "Scanlines"
	scanlines.BackgroundTransparency = 1
	scanlines.BorderSizePixel = 0
	scanlines.Image = Theme.Asset.Scanlines
	scanlines.ImageColor3 = Theme.Cold.Text
	scanlines.ImageTransparency = 0.91
	scanlines.ScaleType = Enum.ScaleType.Tile
	scanlines.TileSize = UDim2.fromOffset(128, 128)
	scanlines.Size = UDim2.fromScale(1, 1)
	scanlines.ZIndex = 0
	scanlines.Parent = root

	local footer = Instance.new("Frame")
	footer.Name = "InputHints"
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -10)
	footer.Size = UDim2.new(0.84, 0, 0, 30)
	footer.BackgroundTransparency = 1
	footer.BorderSizePixel = 0
	footer.ZIndex = 5
	footer.Parent = root
	local backHint = label(footer, "Back", "ESC / B  BACK", Theme.MonoFont, 17, Theme.Cold.Dim)
	backHint.Size = UDim2.new(0.5, 0, 1, 0)
	backHint.TextXAlignment = Enum.TextXAlignment.Left
	local selectHint = label(footer, "Select", "ENTER / A  SELECT", Theme.MonoFont, 17, Theme.Cold.Dim)
	selectHint.Position = UDim2.fromScale(0.5, 0)
	selectHint.Size = UDim2.new(0.5, 0, 1, 0)
	selectHint.TextXAlignment = Enum.TextXAlignment.Right

	self:buildSelect()
	self:buildCreate()
	self:buildJoin()
	self:buildWaiting()
	self:buildBrowse()
	self:buildRoom()
	return self
end

function PartyWallView:buildSelect()
	local page = pageFrame(self, "Select", "PARTY")
	local list = menuList(page, 116, 260, 0.82)
	selectionRow(
		self,
		list,
		"Select",
		"Btn_CREATE",
		"CREATE PARTY",
		"CREATE A PUBLIC OR PRIVATE PARTY IN THIS SERVER",
		1,
		function()
			self:go("Create")
		end
	)
	selectionRow(
		self,
		list,
		"Select",
		"Btn_JOIN",
		"JOIN PARTY",
		"ENTER A SIX CHARACTER PRIVATE PARTY CODE",
		2,
		function()
			self:go("Join")
		end
	)
	selectionRow(
		self,
		list,
		"Select",
		"Btn_PUBLIC",
		"PUBLIC PARTY",
		"BROWSE OPEN PUBLIC PARTIES IN THIS SERVER",
		3,
		function()
			self:go("Browse")
			invoke(self, "browse")
		end
	)
	selectionRow(self, list, "Select", "Btn_BACK", "BACK", "RETURN TO THE STREET", 4, function()
		invoke(self, "backToLanding")
	end)
	self.descriptions.Select.Text = "CREATE OR JOIN A PARTY IN THIS SERVER"
end

function PartyWallView:buildCreate()
	local page = pageFrame(self, "Create", "CREATE PARTY")
	local list = menuList(page, 116, 260, 0.82)
	self.visibilityRow = selectionRow(
		self,
		list,
		"Create",
		"Btn_VISIBILITY",
		"VISIBILITY       PUBLIC",
		"PUBLIC PARTIES APPEAR IN THIS SERVER'S PARTY LIST",
		1,
		function()
			self.createPublic = not self.createPublic
			setRowText(self.visibilityRow, "VISIBILITY       " .. (self.createPublic and "PUBLIC" or "PRIVATE"))
			self.visibilityRow.description = self.createPublic and "PUBLIC PARTIES APPEAR IN THIS SERVER'S PARTY LIST"
				or "PRIVATE PARTIES ARE HIDDEN AND USE A SIX CHARACTER CODE"
			self.descriptions.Create.Text = self.visibilityRow.description
		end
	)
	self.joinRuleRow = selectionRow(
		self,
		list,
		"Create",
		"Btn_JOIN_RULE",
		"JOIN RULE        OPEN",
		"OPEN JOIN SEATS VALID PLAYERS IMMEDIATELY",
		2,
		function()
			self.createJoinPolicy = if self.createJoinPolicy == "Open" then "Approval" else "Open"
			setRowText(
				self.joinRuleRow,
				"JOIN RULE        " .. (self.createJoinPolicy == "Open" and "OPEN" or "HOST APPROVAL")
			)
			self.joinRuleRow.description = self.createJoinPolicy == "Open"
					and "OPEN JOIN SEATS VALID PLAYERS IMMEDIATELY"
				or "THE HOST MUST ACCEPT EACH JOIN REQUEST"
			self.descriptions.Create.Text = self.joinRuleRow.description
		end
	)
	self.createRow = selectionRow(
		self,
		list,
		"Create",
		"Btn_CREATE",
		"CREATE",
		"LOCK THESE SETTINGS AND CREATE THE PARTY",
		3,
		function()
			invoke(self, "create", self.createPublic, self.createJoinPolicy)
		end
	)
	selectionRow(self, list, "Create", "Btn_BACK", "BACK", "RETURN TO PARTY SELECTION", 4, function()
		self:go("Select")
	end)
	self.descriptions.Create.Text = "CHOOSE VISIBILITY AND HOW PLAYERS MAY JOIN"
end

function PartyWallView:buildJoin()
	local page = pageFrame(self, "Join", "JOIN PARTY")
	local codeLabel = label(page, "CodeLabel", "PARTY CODE", Theme.MonoFont, 18, Theme.Cold.Dim)
	codeLabel.AnchorPoint = Vector2.new(0.5, 0)
	codeLabel.Position = UDim2.new(0.5, 0, 0, 118)
	codeLabel.Size = UDim2.new(0.7, 0, 0, 26)
	codeLabel.TextXAlignment = Enum.TextXAlignment.Center

	local box = Instance.new("TextBox")
	box.Name = "CodeEntry"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 150)
	box.Size = UDim2.new(0, 430, 0, 72)
	box.BackgroundColor3 = Theme.Cold.Panel
	box.BackgroundTransparency = 0.08
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Theme.MonoFont
	box.PlaceholderText = "------"
	box.PlaceholderColor3 = Theme.Cold.Dim
	box.Text = ""
	box.TextColor3 = Theme.Cold.Bright
	box.TextSize = 42
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.Parent = page
	self.codeEntry = box
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Cold.Dim
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = box

	local allowed = self.options.codeAlphabet or "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	connect(self, box:GetPropertyChangedSignal("Text"), function()
		local out = {}
		for i = 1, #string.upper(box.Text) do
			local char = string.sub(string.upper(box.Text), i, i)
			if string.find(allowed, char, 1, true) then
				table.insert(out, char)
			end
			if #out >= 6 then
				break
			end
		end
		local clean = table.concat(out)
		if clean ~= box.Text then
			box.Text = clean
		end
	end)

	local list = menuList(page, 258, 124, 0.82)
	self.connectRow = selectionRow(
		self,
		list,
		"Join",
		"Btn_CONNECT",
		"CONNECT",
		"JOIN DIRECTLY OR SEND A REQUEST TO THE HOST",
		1,
		function()
			invoke(self, "joinCode", box.Text)
		end
	)
	selectionRow(self, list, "Join", "Btn_BACK", "BACK", "RETURN TO PARTY SELECTION", 2, function()
		self:go("Select")
	end)
	self.descriptions.Join.Text = "ENTER THE SIX CHARACTER PARTY CODE"
end

function PartyWallView:buildWaiting()
	local page = pageFrame(self, "Waiting", "WAITING FOR HOST APPROVAL")
	local status = label(page, "WaitingStatus", "REQUEST SENT", Theme.MonoFont, 23, Theme.Cold.Text)
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.fromScale(0.5, 0.36)
	status.Size = UDim2.new(0.8, 0, 0, 70)
	status.TextXAlignment = Enum.TextXAlignment.Center
	self.waitingStatus = status
	local list = menuList(page, 340, 124, 0.82)
	selectionRow(self, list, "Waiting", "Btn_CANCEL", "CANCEL REQUEST", "WITHDRAW THIS JOIN REQUEST", 1, function()
		invoke(self, "cancelJoin")
	end)
	selectionRow(self, list, "Waiting", "Btn_BACK", "BACK", "CANCEL THE REQUEST AND RETURN", 2, function()
		invoke(self, "cancelJoin")
	end)
	self.descriptions.Waiting.Text = "THE HOST HAS 45 SECONDS TO ANSWER"
end

function PartyWallView:buildBrowse()
	local page = pageFrame(self, "Browse", "PUBLIC PARTY")
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "PartyList"
	scroll.AnchorPoint = Vector2.new(0.5, 0)
	scroll.Position = UDim2.new(0.5, 0, 0, 100)
	scroll.Size = UDim2.new(0.84, 0, 0, 310)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.Cold.Dim
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = page
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	self.browseList = scroll

	local empty = label(
		scroll,
		"Empty",
		"NO PUBLIC PARTIES IN THIS SERVER\nCREATE ONE OR REFRESH",
		Theme.MonoFont,
		22,
		Theme.Cold.Dim
	)
	empty.Size = UDim2.new(1, -20, 0, 116)
	empty.TextWrapped = true
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.TextYAlignment = Enum.TextYAlignment.Center
	empty.LayoutOrder = 1
	self.browseEmpty = empty

	local actions = menuList(page, 424, 120, 0.82)
	self.refreshRow = selectionRow(
		self,
		actions,
		"Browse",
		"Btn_REFRESH",
		"REFRESH",
		"REQUEST THE CURRENT PUBLIC PARTY LIST",
		1,
		function()
			invoke(self, "browse")
		end
	)
	selectionRow(self, actions, "Browse", "Btn_BACK", "BACK", "RETURN TO PARTY SELECTION", 2, function()
		self:go("Select")
	end)
	self.descriptions.Browse.Text = "OPEN PUBLIC PARTIES IN THIS SERVER"
	self.descriptions.Browse.Position = UDim2.new(0.5, 0, 0, 550)
	self.descriptions.Browse.Size = UDim2.new(0.84, 0, 0, 28)
	self.descriptions.Browse.TextSize = 16
	self.notices.Browse.Position = UDim2.new(0.5, 0, 0, 580)
	self.notices.Browse.Size = UDim2.new(0.86, 0, 0, 22)
end

function PartyWallView:buildRoom()
	local page = pageFrame(self, "Room", "PUBLIC PARTY")
	self.roomHeading = page:FindFirstChild("Heading")
	local code = label(page, "PartyCode", "", Theme.MonoFont, 29, Theme.Cold.Focus)
	code.AnchorPoint = Vector2.new(0.5, 0)
	code.Position = UDim2.new(0.5, 0, 0, 82)
	code.Size = UDim2.new(0.8, 0, 0, 42)
	code.TextXAlignment = Enum.TextXAlignment.Center
	self.roomCode = code

	local slots = Instance.new("Frame")
	slots.Name = "Slots"
	slots.AnchorPoint = Vector2.new(0.5, 0)
	slots.Position = UDim2.new(0.5, 0, 0, 126)
	slots.Size = UDim2.new(0.84, 0, 0, 248)
	slots.BackgroundTransparency = 1
	slots.BorderSizePixel = 0
	slots.Parent = page
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.Padding = UDim.new(0, 6)
	slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotLayout.Parent = slots
	self.slotViews = {}
	for i = 1, 4 do
		local slot = Instance.new("Frame")
		slot.Name = "Slot_" .. i
		slot.Size = UDim2.new(1, 0, 0, 56)
		slot.BackgroundColor3 = Theme.Cold.Panel
		slot.BackgroundTransparency = 0.26
		slot.BorderSizePixel = 0
		slot.LayoutOrder = i
		slot.Parent = slots
		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = Theme.Cold.Dim
		slotStroke.Thickness = 1
		slotStroke.Transparency = 0.55
		slotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		slotStroke.Parent = slot
		local hostMark = Instance.new("Frame")
		hostMark.Name = "HostMark"
		hostMark.Position = UDim2.new(0, 10, 0.5, -15)
		hostMark.Size = UDim2.fromOffset(6, 30)
		hostMark.BackgroundColor3 = Theme.Party.Marker
		hostMark.BorderSizePixel = 0
		hostMark.Visible = false
		hostMark.Parent = slot
		local nameLabel = label(slot, "PlayerName", "EMPTY", Theme.MonoFont, 20, Theme.Cold.Dim)
		nameLabel.Position = UDim2.new(0, 30, 0, 0)
		nameLabel.Size = UDim2.new(0.62, -30, 1, 0)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		local stateLabel = label(slot, "ReadyState", "EMPTY", Theme.MonoFont, 18, Theme.Cold.Dim)
		stateLabel.Position = UDim2.fromScale(0.62, 0)
		stateLabel.Size = UDim2.new(0.36, -12, 1, 0)
		stateLabel.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(self.slotViews, { frame = slot, hostMark = hostMark, name = nameLabel, state = stateLabel })
	end

	local status = label(page, "RoomStatus", "MINIMUM 2 PLAYERS", Theme.MonoFont, 20, Theme.Cold.Text)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 386)
	status.Size = UDim2.new(0.84, 0, 0, 46)
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextYAlignment = Enum.TextYAlignment.Center
	self.roomStatus = status

	local actions = menuList(page, 442, 120, 0.82)
	self.readyRow = selectionRow(
		self,
		actions,
		"Room",
		"Btn_READY",
		"MINIMUM 2 PLAYERS",
		"EVERY PARTY MEMBER MUST BE READY",
		1,
		function()
			invoke(self, "toggleReady")
		end
	)
	self.leaveRow = selectionRow(
		self,
		actions,
		"Room",
		"Btn_LEAVE",
		"LEAVE PARTY",
		"LEAVE THIS PARTY AND RETURN TO PARTY SELECTION",
		2,
		function()
			invoke(self, "leave")
		end
	)
	self.descriptions.Room.Text = "FOUR PLAYER PARTY - AUTOMATIC START WHEN ALL ARE READY"
	-- The room already has a dedicated live status block. Hiding the generic
	-- description prevents it from crossing the READY / LEAVE action rows.
	self.descriptions.Room.Visible = false

	local modal = Instance.new("Frame")
	modal.Name = "ApprovalPrompt"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.new(0.82, 0, 0, 300)
	modal.BackgroundColor3 = Theme.Cold.Ground
	modal.BackgroundTransparency = 0.02
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Active = true
	modal.ZIndex = 20
	modal.Parent = page
	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = Theme.Cold.Focus
	modalStroke.Thickness = 1
	modalStroke.Transparency = 0.2
	modalStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	modalStroke.Parent = modal
	local prompt = label(modal, "Prompt", "PLAYER WANTS TO JOIN", Theme.TitleFont, 30, Theme.Cold.Bright)
	prompt.Position = UDim2.fromOffset(24, 24)
	prompt.Size = UDim2.new(1, -48, 0, 70)
	prompt.TextWrapped = true
	prompt.TextXAlignment = Enum.TextXAlignment.Center
	prompt.TextYAlignment = Enum.TextYAlignment.Center
	self.requestPrompt = prompt
	local queue = label(modal, "Queue", "", Theme.MonoFont, 16, Theme.Cold.Dim)
	queue.Position = UDim2.new(0, 24, 0, 96)
	queue.Size = UDim2.new(1, -48, 0, 24)
	queue.TextXAlignment = Enum.TextXAlignment.Center
	self.requestQueue = queue
	local modalActions = menuList(modal, 132, 124, 0.86)
	self.acceptRow = selectionRow(
		self,
		modalActions,
		"Room",
		"Btn_ACCEPT",
		"ACCEPT",
		"SEAT THIS PLAYER IF THE PARTY IS STILL OPEN",
		1,
		function()
			invoke(self, "decide", self.currentRequestUserId, true)
		end
	)
	self.declineRow = selectionRow(
		self,
		modalActions,
		"Room",
		"Btn_DECLINE",
		"DECLINE",
		"DECLINE THIS REQUEST",
		2,
		function()
			invoke(self, "decide", self.currentRequestUserId, false)
		end
	)
	self.approvalModal = modal
end

function PartyWallView:setInteractive(on)
	self.interactive = on == true
	for _, page in self.pages do
		for _, descendant in page:GetDescendants() do
			if descendant:IsA("GuiButton") or descendant:IsA("TextBox") then
				local row = self.rows[descendant]
				local allowed = self.interactive and page.Visible and isRendered(descendant, page)
				if row then
					allowed = allowed and row.enabled
				end
				descendant.Active = allowed
				descendant.Interactable = allowed
				descendant.Selectable = allowed
			end
		end
	end
end

function PartyWallView:focusFirst(preferred)
	if not self.interactive then
		return
	end
	local page = self.pages[self.currentPage]
	if not page then
		return
	end
	task.defer(function()
		if not page.Visible then
			return
		end
		if preferred and preferred.Parent and preferred.Selectable and isRendered(preferred, page) then
			GuiService.SelectedObject = preferred
			return
		end
		for _, descendant in page:GetDescendants() do
			if descendant:IsA("GuiButton") and descendant.Selectable and isRendered(descendant, page) then
				GuiService.SelectedObject = descendant
				return
			end
		end
	end)
end

function PartyWallView:go(name)
	if not self.pages[name] then
		return
	end
	for pageName, page in self.pages do
		page.Visible = pageName == name
	end
	self.currentPage = name
	self:setInteractive(self.interactive)
	if UserInputService.GamepadEnabled or UserInputService.KeyboardEnabled then
		self:focusFirst()
	end
end

function PartyWallView:page()
	return self.currentPage
end

function PartyWallView:setNotice(text, isError, pageName)
	local target = self.notices[pageName or self.currentPage]
	if not target then
		return
	end
	target.Text = string.upper(tostring(text or ""))
	target.TextColor3 = isError and Theme.Cold.Error or Theme.Cold.Dim
end

function PartyWallView:setCreateLocked(locked)
	setRowEnabled(self, self.visibilityRow, not locked)
	setRowEnabled(self, self.joinRuleRow, not locked)
	setRowEnabled(self, self.createRow, not locked)
	if locked then
		self:setNotice("CREATING PARTY...", false, "Create")
	end
end

function PartyWallView:clearCode()
	if self.codeEntry then
		self.codeEntry.Text = ""
	end
end

function PartyWallView:setWaitingStatus(text)
	if self.waitingStatus then
		self.waitingStatus.Text = string.upper(tostring(text or "REQUEST SENT"))
	end
end

function PartyWallView:clearBrowseRows()
	for _, conn in self.browseConnections do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(self.browseConnections)
	if not self.browseList then
		return
	end
	for _, child in self.browseList:GetChildren() do
		if child:IsA("TextButton") then
			self.rows[child] = nil
			child:Destroy()
		end
	end
	self.browseFirst = nil
end

function PartyWallView:setBrowseRooms(rooms)
	self:clearBrowseRows()
	rooms = type(rooms) == "table" and rooms or {}
	self.browseEmpty.Visible = #rooms == 0
	for i = 1, math.min(#rooms, 15) do
		local room = rooms[i]
		local host = string.upper(tostring(room.hostDisplayName or "UNKNOWN"))
		if #host > 22 then
			host = string.sub(host, 1, 22)
		end
		local policy = room.joinPolicy == "Approval" and "APPROVAL" or "OPEN"
		local text = string.format("%s     %d/4     %s", host, tonumber(room.memberCount) or 0, policy)
		local row = selectionRow(
			self,
			self.browseList,
			"Browse",
			"Party_" .. tostring(room.roomId),
			text,
			policy == "OPEN" and "JOIN THIS PUBLIC PARTY" or "REQUEST APPROVAL FROM THIS PARTY'S HOST",
			i,
			function()
				invoke(self, "joinPublic", room.roomId)
			end,
			self.browseConnections
		)
		if i == 1 then
			self.browseFirst = row.button
		end
	end
	if self.currentPage == "Browse" then
		self:setInteractive(self.interactive)
		if self.browseFirst then
			self:focusFirst(self.browseFirst)
		end
	end
end

function PartyWallView:setRoom(room)
	if type(room) ~= "table" then
		return
	end
	self.room = room
	local members = type(room.members) == "table" and room.members or {}
	local count = tonumber(room.memberCount) or #members
	local minPlayers = tonumber(room.minPlayers) or 2
	local isPrivate = room.isPublic ~= true
	self.roomHeading.Text = isPrivate and "PRIVATE PARTY" or "PUBLIC PARTY"
	self.roomCode.Text = isPrivate and ("CODE  " .. tostring(room.code or "------")) or ""

	local me
	local everyoneReady = count >= minPlayers
	for i = 1, 4 do
		local slot = self.slotViews[i]
		local member = members[i]
		if member then
			local displayName = string.upper(tostring(member.displayName or "UNKNOWN"))
			slot.hostMark.Visible = member.userId == room.hostUserId
			slot.name.Text = displayName
			slot.name.TextColor3 = Theme.Cold.Text
			slot.state.Text = member.ready and "READY" or "NOT READY"
			slot.state.TextColor3 = member.ready and Theme.Cold.Focus or Theme.Cold.Dim
			if not member.ready then
				everyoneReady = false
			end
			if member.userId == self.options.localUserId then
				me = member
			end
		else
			slot.hostMark.Visible = false
			slot.name.Text = "EMPTY"
			slot.name.TextColor3 = Theme.Cold.Dim
			slot.state.Text = "EMPTY"
			slot.state.TextColor3 = Theme.Cold.Dim
		end
	end

	if room.phase == "Starting" then
		self.roomStatus.Text = if room.countdown
			then "ALL READY — STARTING IN " .. tostring(room.countdown)
			else "ALL READY — STARTING"
	elseif count < minPlayers then
		self.roomStatus.Text = "MINIMUM " .. minPlayers .. " PLAYERS\nWAITING FOR PLAYERS"
	elseif everyoneReady then
		self.roomStatus.Text = "ALL READY — STARTING"
	else
		self.roomStatus.Text = "WAITING FOR READY"
	end

	local canReady = count >= minPlayers and room.phase ~= "Playing"
	setRowEnabled(self, self.readyRow, canReady)
	if count < minPlayers then
		setRowText(self.readyRow, "MINIMUM " .. minPlayers .. " PLAYERS")
	else
		setRowText(self.readyRow, me and me.ready and "NOT READY" or "READY")
	end
	if self.approvalModal.Visible then
		setRowEnabled(self, self.readyRow, false)
		setRowEnabled(self, self.leaveRow, false)
	else
		setRowEnabled(self, self.leaveRow, true)
	end
end

function PartyWallView:setPendingRequests(requests)
	requests = type(requests) == "table" and requests or {}
	local request = requests[1]
	if not request then
		self.currentRequestUserId = nil
		self.approvalModal.Visible = false
		if self.room then
			self:setRoom(self.room)
		end
		self:setInteractive(self.interactive)
		return
	end
	self.currentRequestUserId = request.userId
	self.requestPrompt.Text = string.upper(tostring(request.displayName or "PLAYER")) .. " WANTS TO JOIN"
	self.requestQueue.Text = string.format("REQUEST %d OF %d · EXPIRES AUTOMATICALLY", 1, #requests)
	self.approvalModal.Visible = true
	setRowEnabled(self, self.readyRow, false)
	setRowEnabled(self, self.leaveRow, false)
	setRowEnabled(self, self.acceptRow, true)
	setRowEnabled(self, self.declineRow, true)
	self:setInteractive(self.interactive)
	if self.currentPage == "Room" then
		self:focusFirst(self.acceptRow.button)
	end
end

function PartyWallView:destroy()
	self:clearBrowseRows()
	for _, conn in self.connections do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(self.connections)
	if self.root then
		self.root:Destroy()
	end
end

return PartyWallView
