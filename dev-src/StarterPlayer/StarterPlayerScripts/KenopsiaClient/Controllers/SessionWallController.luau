--!nonstrict
-- SESSION WALL (Gate M1 §3B).
--
-- The wall terminal the camera pushes into after START. It is a SurfaceGui in
-- PlayerGui adorned to MenuStage.SessionDisplay -- a SurfaceGui parented to the
-- part itself cannot receive input reliably, which is why the container lives
-- in PlayerGui and only the Adornee points at the world.
--
-- Create, Join and Room are PAGES OF THIS SAME TERMINAL, not separate screens.
-- LEAVE returns to session select; only the separate BACK pulls the camera home
-- and hides the wall.
--
-- Room remotes and payloads are used exactly as they already exist. This
-- controller adds no new remote and changes no server contract.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local SoundBank = require(UI.SoundBank)

local player = Players.LocalPlayer

local SessionWallController = {}
SessionWallController.__index = SessionWallController

local GUI_NAME = "KenopsiaSessionWall"
local PIXELS_PER_STUD = 72
local CODE_LENGTH = 6
local REVEAL_STAGGER = 0.08

-- The helper line states the scope honestly for this gate: quick join searches
-- the CURRENT SERVER only. Cross-server matchmaking is its own gate.
local PUBLIC_HELP = "OPEN ROOMS IN THIS SERVER"
local PUBLIC_EMPTY = "NO OPEN ROOM IN THIS SERVER"

-- BUILD HELPERS --------------------------------------------------------------

local function panel(parent, name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Theme.Street.Asphalt
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.Visible = false
	f.Parent = parent
	return f
end

local function heading(parent, text)
	local l = Instance.new("TextLabel")
	l.Name = "Heading"
	l.BackgroundTransparency = 1
	l.Font = Theme.TitleFont
	l.Text = text
	l.TextScaled = false
	l.TextSize = 34
	l.TextColor3 = Theme.Street.OffWhite
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Position = UDim2.fromScale(0.06, 0.05)
	l.Size = UDim2.fromScale(0.88, 0.1)
	l.Parent = parent
	return l
end

local function note(parent, text, yScale)
	local l = Instance.new("TextLabel")
	l.Name = "Note"
	l.BackgroundTransparency = 1
	l.Font = Theme.MonoFont
	l.Text = text
	l.TextSize = 16
	l.TextColor3 = Theme.Street.Sage
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Position = UDim2.fromScale(0.06, yScale)
	l.Size = UDim2.fromScale(0.88, 0.06)
	l.Parent = parent
	return l
end

local function wallButton(parent, name, text, yScale, hScale)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BackgroundColor3 = Theme.Street.Ink
	b.BorderSizePixel = 0
	b.Position = UDim2.fromScale(0.06, yScale)
	b.Size = UDim2.fromScale(0.88, hScale or 0.13)
	b.Font = Theme.TitleFont
	b.Text = text
	b.TextSize = 26
	b.TextColor3 = Theme.Street.OffWhite
	b.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.StreetRadius.Soft)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = Theme.Street.Sage
	s.Thickness = Theme.StreetStroke.Normal
	s.Transparency = 0.45
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b

	local function setActive(on)
		Motion.hover(s, { Color = on and Theme.Street.Amber or Theme.Street.Sage,
			Transparency = on and 0 or 0.45 })
		b.TextColor3 = on and Theme.Street.Amber or Theme.Street.OffWhite
	end
	b.MouseEnter:Connect(function() setActive(true) SoundBank.hover() end)
	b.MouseLeave:Connect(function() setActive(false) end)
	b.SelectionGained:Connect(function() setActive(true) SoundBank.hover() end)
	b.SelectionLost:Connect(function() setActive(false) end)
	return b
end

-- CONSTRUCTION ---------------------------------------------------------------

function SessionWallController.new(deps)
	local self = setmetatable({}, SessionWallController)
	self.scene = deps and deps.scene
	self.onBack = deps and deps.onBack
	self.conns = {}
	self.pages = {}
	self.page = nil
	self.room = { hostUserId = 0, members = {} }
	self.revealed = false

	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(GUI_NAME)
	if old then old:Destroy() end

	local gui = Instance.new("SurfaceGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.AlwaysOnTop = false
	gui.Active = true
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Face = Enum.NormalId.Front
	gui.Enabled = false
	gui.Parent = pg
	self.gui = gui

	self:bindAdornee()
	self:buildSelect()
	self:buildHost()
	self:buildJoin()
	self:buildRoom()
	self:bindServer()

	self:setLayerInteractive(false)
	return self
end

-- The Adornee is resolved at runtime rather than saved on the instance: the
-- MCP property layer cannot write Instance-typed properties, and doing it here
-- also survives the part being rebuilt.
function SessionWallController:bindAdornee()
	local function resolve()
		local stage = workspace:FindFirstChild("MenuStage")
		local display = stage and stage:FindFirstChild("SessionDisplay")
		if display then
			self.gui.Adornee = display
			display.CanQuery = true
			return true
		end
		return false
	end
	if resolve() then return end
	task.spawn(function()
		for _ = 1, 40 do
			task.wait(0.25)
			if resolve() then return end
		end
		warn("[SessionWall] MenuStage.SessionDisplay never appeared - wall will not render")
	end)
end

-- Before START the whole layer must be inert: not merely invisible, but
-- non-focusable. An invisible-but-selectable button still takes gamepad focus.
function SessionWallController:setLayerInteractive(on)
	self.gui.Enabled = on
	self.gui.Active = on
	for _, d in self.gui:GetDescendants() do
		if d:IsA("GuiButton") or d:IsA("TextBox") then
			d.Selectable = on
			d.Active = on
			d.Interactable = on
		end
	end
end

function SessionWallController:buildSelect()
	local p = panel(self.gui, "Select")
	self.pages.Select = p
	heading(p, "SESSION")
	self.btnHost = wallButton(p, "Btn_HOST", "HOST SESSION", 0.22)
	self.btnJoin = wallButton(p, "Btn_JOIN", "JOIN SESSION", 0.38)
	self.btnPublic = wallButton(p, "Btn_PUBLIC", "PUBLIC SESSION", 0.54)
	self.publicNote = note(p, PUBLIC_HELP, 0.68)
	local back = wallButton(p, "Btn_BACK", "BACK", 0.82, 0.11)

	self.btnHost.Activated:Connect(function() SoundBank.click() self:go("Host") end)
	self.btnJoin.Activated:Connect(function() SoundBank.click() self:go("Join") end)
	self.btnPublic.Activated:Connect(function()
		SoundBank.click()
		self:quickJoin()
	end)
	back.Activated:Connect(function()
		SoundBank.click()
		self:hide()
		if self.onBack then self.onBack() end
	end)
end

function SessionWallController:buildHost()
	local p = panel(self.gui, "Host")
	self.pages.Host = p
	heading(p, "HOST")
	local pub = wallButton(p, "Btn_PUBLIC_ROOM", "PUBLIC ROOM", 0.24)
	note(p, "ANYONE ON THIS SERVER MAY BE SEATED", 0.38)
	local priv = wallButton(p, "Btn_PRIVATE_ROOM", "PRIVATE ROOM", 0.48)
	note(p, "CODE REQUIRED", 0.62)
	local back = wallButton(p, "Btn_BACK", "BACK", 0.8, 0.11)

	pub.Activated:Connect(function() SoundBank.click() self:hostSession(true) end)
	priv.Activated:Connect(function() SoundBank.click() self:hostSession(false) end)
	back.Activated:Connect(function() SoundBank.click() self:go("Select") end)
end

function SessionWallController:buildJoin()
	local p = panel(self.gui, "Join")
	self.pages.Join = p
	heading(p, "JOIN")

	local box = Instance.new("TextBox")
	box.Name = "CodeEntry"
	box.BackgroundColor3 = Theme.Street.Ink
	box.BorderSizePixel = 0
	box.Position = UDim2.fromScale(0.06, 0.26)
	box.Size = UDim2.fromScale(0.88, 0.15)
	box.Font = Theme.MonoFont
	box.Text = ""
	box.PlaceholderText = "------"
	box.PlaceholderColor3 = Theme.Street.Denim
	box.TextSize = 40
	box.TextColor3 = Theme.Street.OffWhite
	box.ClearTextOnFocus = false
	box.Parent = p
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, Theme.StreetRadius.Soft) c.Parent = box
	local s = Instance.new("UIStroke") s.Color = Theme.Street.Sage s.Thickness = Theme.StreetStroke.Normal
	s.Transparency = 0.45 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = box
	self.codeEntry = box

	-- Normalise as the player types: the server upper-cases anyway, and showing
	-- the corrected value avoids a code that looks wrong but is accepted.
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local clean = string.upper(box.Text):gsub("[^A-Z0-9]", "")
		if #clean > CODE_LENGTH then clean = string.sub(clean, 1, CODE_LENGTH) end
		if clean ~= box.Text then box.Text = clean end
	end)

	self.joinNote = note(p, "ENTER THE 6 CHARACTER CODE", 0.44)
	local connect = wallButton(p, "Btn_CONNECT", "CONNECT", 0.56)
	local back = wallButton(p, "Btn_BACK", "BACK", 0.8, 0.11)

	connect.Activated:Connect(function() SoundBank.click() self:connect() end)
	back.Activated:Connect(function() SoundBank.click() self:go("Select") end)
end

function SessionWallController:buildRoom()
	local p = panel(self.gui, "Room")
	self.pages.Room = p
	heading(p, "ROOM")

	self.roomCode = note(p, "", 0.16)
	self.roomCode.TextColor3 = Theme.Street.Amber
	self.roomCode.Font = Theme.MonoFont
	self.roomCode.TextSize = 22
	self.roomVisibility = note(p, "", 0.22)

	local roster = Instance.new("Frame")
	roster.Name = "Roster"
	roster.BackgroundTransparency = 1
	roster.Position = UDim2.fromScale(0.06, 0.3)
	roster.Size = UDim2.fromScale(0.88, 0.34)
	roster.Parent = p
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = roster
	self.roster = roster

	self.btnReady = wallButton(p, "Btn_READY", "READY", 0.66, 0.12)
	self.btnStart = wallButton(p, "Btn_START_RUN", "START RUN", 0.79, 0.11)
	local leave = wallButton(p, "Btn_LEAVE", "LEAVE", 0.91, 0.08)
	leave.TextSize = 18

	self.btnReady.Activated:Connect(function()
		SoundBank.click()
		local me = self:me()
		local r = self:remote("RoomReadyRequest")
		if r then r:FireServer(not (me and me.ready)) end
	end)
	self.btnStart.Activated:Connect(function()
		SoundBank.click()
		local r = self:remote("RoomStartRequest")
		if r then r:FireServer() end
	end)
	-- LEAVE returns to session select, NOT to landing. Only the separate BACK
	-- on the Select page pulls the camera home.
	leave.Activated:Connect(function()
		SoundBank.click()
		local r = self:remote("RoomLeaveRequest")
		if r then r:FireServer() end
		self.room = { hostUserId = 0, members = {} }
		-- Re-render before leaving the page. Clearing self.room without this
		-- leaves the previous roster drawn on the hidden Room page, so the next
		-- visit flashes the OLD occupants for a frame before the first
		-- RoomState arrives.
		self:renderRoster()
		self:go("Select")
	end)
end

-- SERVER ---------------------------------------------------------------------

function SessionWallController:remote(name)
	local k = ReplicatedStorage:FindFirstChild("Kenopsia")
	local folder = k and k:FindFirstChild("Remotes")
	return folder and folder:FindFirstChild(name) or nil
end

function SessionWallController:me()
	for _, m in self.room.members do
		if m.userId == player.UserId then return m end
	end
	return nil
end

function SessionWallController:hostSession(isPublic)
	local r = self:remote("RoomCreateRequest")
	if not r then self:setNote("LOBBY SERVICE OFFLINE", true) return end
	r:FireServer({ public = isPublic == true })
end

function SessionWallController:quickJoin()
	local r = self:remote("RoomQuickJoinRequest")
	if not r then self:setNote("LOBBY SERVICE OFFLINE", true) return end
	self.publicNote.Text = "SEARCHING..."
	self.publicNote.TextColor3 = Theme.Street.Sage
	r:FireServer()
	-- The server now answers a miss with LobbyError, so this is only a
	-- last-resort unstick: if the request is dropped or rate-limited, nothing
	-- ever replies and "SEARCHING..." would otherwise sit there forever.
	-- Keyed on the Select page still being visible rather than on self.page,
	-- for the same reason setNote is.
	task.delay(2, function()
		local sel = self.pages.Select
		if sel and sel.Visible and #self.room.members == 0
			and self.publicNote.Text == "SEARCHING..." then
			self.publicNote.Text = PUBLIC_EMPTY
			self.publicNote.TextColor3 = Theme.Street.Denim
		end
	end)
end

function SessionWallController:connect()
	local box = self.codeEntry
	if not box or #box.Text ~= CODE_LENGTH then
		self:setNote("CODE MUST BE 6 CHARACTERS", true)
		return
	end
	local r = self:remote("RoomJoinRequest")
	if not r then self:setNote("LOBBY SERVICE OFFLINE", true) return end
	self:setNote("CONNECTING...", false)
	r:FireServer(box.Text)
end

-- Routes by what is ACTUALLY VISIBLE, not by the remembered page.
--
-- Routing on self.page looks equivalent and is not: if the recorded page ever
-- disagrees with the visible one -- a desync, or simply an error arriving after
-- the player has navigated away -- the message is written to a hidden label and
-- the player is shown nothing at all while believing the action did nothing.
-- Reading visibility is self-correcting and cannot drift.
function SessionWallController:setNote(text, isError)
	local target
	for name, page in self.pages do
		if page.Visible then
			target = page:FindFirstChild("Note")
			if target then
				self.page = name -- heal the record while we are here
				break
			end
		end
	end
	target = target or self.publicNote
	if not target then return end
	target.Text = text
	target.TextColor3 = isError and Theme.Street.Error or Theme.Street.Sage
end

function SessionWallController:bindServer()
	local state = self:remote("RoomState")
	if state then
		table.insert(self.conns, state.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then return end
			self.room = {
				hostUserId = payload.hostUserId or 0,
				isPublic = payload.isPublic == true,
				members = payload.members or {},
			}
			if self.roomCode then
				self.roomCode.Text = payload.code and ("CODE  " .. payload.code) or ""
			end
			if self.roomVisibility then
				self.roomVisibility.Text = payload.isPublic
					and "PUBLIC - STRANGERS MAY BE SEATED" or "PRIVATE - CODE REQUIRED"
				self.roomVisibility.TextColor3 = payload.isPublic
					and Theme.Street.Sage or Theme.Street.Amber
			end
			self:renderRoster()
			-- Any real membership moves the wall to the Room page, whichever
			-- route produced it: host, code join or quick join.
			if #self.room.members > 0 and self.revealed
				and (self.page == "Select" or self.page == "Host" or self.page == "Join") then
				self:go("Room")
			end
		end))
	end
	local err = self:remote("LobbyError")
	if err then
		table.insert(self.conns, err.OnClientEvent:Connect(function(message)
			self:setNote(string.upper(tostring(message)), true)
			SoundBank.denied()
		end))
	end
end

function SessionWallController:renderRoster()
	if not self.roster then return end
	for _, c in self.roster:GetChildren() do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	for i, m in self.room.members do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Theme.MonoFont
		l.Text = string.format("%d  %s%s%s", i, string.upper(m.displayName or "?"),
			m.userId == self.room.hostUserId and "   [HOST]" or "",
			m.ready and "   READY" or "")
		l.TextSize = 18
		l.TextColor3 = m.ready and Theme.Street.Amber or Theme.Street.OffWhite
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Size = UDim2.new(1, 0, 0, 24)
		l.LayoutOrder = i
		l.Parent = self.roster
	end
	local me = self:me()
	if self.btnReady then
		self.btnReady.Text = (me and me.ready) and "NOT READY" or "READY"
	end
	if self.btnStart then
		local isHost = self.room.hostUserId == player.UserId
		self.btnStart.Visible = isHost
		self.btnStart.Interactable = isHost
		self.btnStart.Selectable = isHost
	end
end

-- PAGES ----------------------------------------------------------------------

function SessionWallController:go(name)
	if not self.pages[name] then return end
	for pageName, p in self.pages do
		p.Visible = (pageName == name)
	end
	self.page = name
	if name == "Select" then
		self.publicNote.Text = PUBLIC_HELP
		self.publicNote.TextColor3 = Theme.Street.Sage
	end
	self:setLayerInteractive(self.revealed)
	if self.revealed and UserInputService.GamepadEnabled then
		local p = self.pages[name]
		for _, d in p:GetDescendants() do
			if d:IsA("GuiButton") and d.Visible and d.Selectable then
				GuiService.SelectedObject = d
				break
			end
		end
	end
end

-- Called by the coordinator once the camera has finished moving. The three
-- session actions appear only here -- never before the move, and never while
-- the landing screen is up.
function SessionWallController:reveal()
	self.revealed = true
	self:go("Select")
	self:setLayerInteractive(true)
	for i, b in { self.btnHost, self.btnJoin, self.btnPublic } do
		b.Visible = false
		task.delay(REVEAL_STAGGER * (i - 1), function()
			if not self.revealed then return end
			b.Visible = true
			b.BackgroundTransparency = 1
			Motion.fade(b, { BackgroundTransparency = 0 })
		end)
	end
end

function SessionWallController:hide()
	self.revealed = false
	self:setLayerInteractive(false)
	for _, p in self.pages do p.Visible = false end
	self.page = nil
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = nil end
end

function SessionWallController:destroy()
	for _, conn in self.conns do
		if conn.Connected then conn:Disconnect() end
	end
	table.clear(self.conns)
	if self.gui then self.gui:Destroy() end
end

return SessionWallController
