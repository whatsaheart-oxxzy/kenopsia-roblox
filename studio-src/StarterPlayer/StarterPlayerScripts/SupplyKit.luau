--!nonstrict
-- SUPPLY KIT v2 (01.09.2026, evening) -- sidebar + minimal panels.
--
-- The user's ruling replaced v1's centered surface: "Ich will nur ein smooth
-- Sidebar haben und wenn man draufdrückt, ist es nicht in Vollbildschirm
-- sondern minimal." So: a slim RAIL slides in from the left edge (one tween,
-- Supply.Motion.SLIDE); pressing an entry opens a MINIMAL panel anchored
-- beside the rail; pressing it again closes it. Nothing here ever goes
-- fullscreen -- the fullscreen lobby/party wall belongs to the menu-place
-- redesign, not this file. Reference language (user-pointed: Cyberpunk 2077
-- via gameuidatabase id=439): compact anchored panels, a thin rule under the
-- header, a colour notch per row, eyebrow/value label hierarchy, hard edges.
--
-- Three destinations: WARDROBE (wheel + catalog + detail), REQUISITION
-- (crate ceremony + gamepass tiles), ACCESS CODES (decision D-C -- the
-- widget ships now, the server's code table fills later).
--
-- Rarity is the user's decided COMMON/RARE/VEX set (SupplyConfig.Rarity):
-- those hues appear on rarity strokes and tier tags only; all chrome stays
-- machine phosphor, WHITE stays reserved for the active-row streak.
--
-- The TrialClientKit portability contract is unchanged: no remotes, no
-- services -- deps.send out, onPacket in, one step(now) from the host's loop.
-- MainMenu's perf rules hold: own ScreenGui, no RenderStepped, closed means
-- the reveal strip is destroyed and every tween is short and one-shot.
local TweenService = game:GetService("TweenService")

local SupplyKit = {}
SupplyKit.__index = SupplyKit

local FONT = Enum.Font.Code
local CODE_TIMEOUT = 8 -- seconds before a silent redeem un-sticks the widget
local OPEN_TIMEOUT = 8 -- seconds before a silent crate open un-sticks DECRYPT

local function hex(h)
	return Color3.fromHex(h)
end

-- BUILDERS --------------------------------------------------------------------
local function frame(parent, name, colorHex)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	if colorHex then
		f.BackgroundColor3 = hex(colorHex)
	else
		f.BackgroundTransparency = 1
	end
	f.Parent = parent
	return f
end

local function label(parent, name, text, size, colorHex)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.Text = text
	l.TextSize = size
	l.TextColor3 = hex(colorHex)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function button(parent, name, text, size, colorHex, plateHex)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Font = FONT
	b.Text = text
	b.TextSize = size
	b.TextColor3 = hex(colorHex)
	if plateHex then
		b.BackgroundColor3 = hex(plateHex)
	else
		b.BackgroundTransparency = 1
	end
	b.Parent = parent
	return b
end

local function stroke(target, colorHex, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = hex(colorHex)
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = target
	return s
end

-- The reference's corner chrome: four small L-ticks instead of a rounded box.
local function cornerTicks(parent, colorHex)
	for i = 1, 4 do
		local h = frame(parent, "TickH" .. i, colorHex)
		h.Size = UDim2.fromOffset(12, 1)
		local v = frame(parent, "TickV" .. i, colorHex)
		v.Size = UDim2.fromOffset(1, 12)
		local right = i == 2 or i == 4
		local bottom = i >= 3
		h.AnchorPoint = Vector2.new(right and 1 or 0, bottom and 1 or 0)
		v.AnchorPoint = h.AnchorPoint
		h.Position = UDim2.new(right and 1 or 0, right and -2 or 2, bottom and 1 or 0, bottom and -2 or 2)
		v.Position = h.Position
		h.BackgroundTransparency = 0.2
		v.BackgroundTransparency = 0.2
	end
end

-- One panel skeleton: plate, hairline, ticks, header with the thin rule.
local function panelShell(self, parent, name, w, h, titleText)
	local p = frame(parent, name, self.P.BG)
	p.AnchorPoint = Vector2.new(0, 0.5)
	p.Size = UDim2.fromOffset(w, h)
	p.Visible = false
	stroke(p, self.P.GREEN_DIM, 1, 0.35)
	cornerTicks(p, self.P.GREEN)
	local title = label(p, "Title", titleText, 17, self.P.GREEN)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -28, 0, 22)
	local rule = frame(p, "Rule", self.P.GREEN_DIM)
	rule.Position = UDim2.fromOffset(14, 34)
	rule.Size = UDim2.new(1, -28, 0, 1)
	rule.BackgroundTransparency = 0.4
	local scale = Instance.new("UIScale")
	scale.Parent = p
	return p, scale
end

-- CREATE ----------------------------------------------------------------------
function SupplyKit.create(deps)
	local self = setmetatable({}, SupplyKit)
	self.deps = deps
	self.P = deps.palette
	self.L = deps.layout
	self.S = deps.strings

	self.owned = {}
	self.equipped = ""
	self.wheel = {}
	self.keys = 0
	self.fragments = 0
	self.shownKeys = 0
	self.shownFragments = 0
	self.selectedId = nil
	self.panelName = nil -- "wardrobe" | "supply" | "codes" | nil
	self.railOpen = false
	self.revealBusy = false
	self.revealWait = 0
	self.codeBusy = false
	self.codeWait = 0
	self.pulsePhase = 0
	self.cards = {}
	self.slotButtons = {}
	self.wheelButtons = {}
	self.railRows = {}
	self.panels = {}
	self.panelScales = {}

	self:_build()
	return self
end

function SupplyKit:_build()
	local P, L, S = self.P, self.L, self.S

	local gui = Instance.new("ScreenGui")
	gui.Name = "KenopsiaSupply"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- Between the machine (50) and the CRT glass (60), under the title menu
	-- (55): everything here reads through the same tube.
	gui.DisplayOrder = 54
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui = gui

	-- THE COLLAPSED TAB: the only thing on screen while the rail sleeps.
	local tab = button(gui, "RailTab", "S\nU\nP\nP\nL\nY", 12, P.GREEN_SOFT, P.PLATE)
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Position = UDim2.new(0, 0, 0.5, 0)
	tab.Size = UDim2.fromOffset(L.RailTabW, L.RailTabH)
	tab.TextXAlignment = Enum.TextXAlignment.Center
	stroke(tab, P.GREEN_DIM, 1, 0.4)
	tab.MouseEnter:Connect(function()
		tab.TextColor3 = hex(P.GREEN)
		self.deps.sfx("Hover")
	end)
	tab.MouseLeave:Connect(function()
		tab.TextColor3 = hex(P.GREEN_SOFT)
	end)
	tab.Activated:Connect(function()
		self.deps.sfx("Click")
		self:setRail(not self.railOpen)
	end)
	self.railTab = tab

	-- THE RAIL: a floating block, not a full-height column -- minimal.
	local rail = frame(gui, "Rail", P.BG)
	rail.AnchorPoint = Vector2.new(0, 0.5)
	rail.Position = UDim2.new(0, -L.RailW - 4, 0.5, 0) -- parked off-screen
	rail.Size = UDim2.fromOffset(L.RailW, 34 + 3 * (L.RailRowH + 6) + 40)
	stroke(rail, P.GREEN_DIM, 1, 0.35)
	cornerTicks(rail, P.GREEN)
	self.rail = rail

	local railHead = label(rail, "Head", "SUPPLY//SYS", 12, P.GREEN_DIM)
	railHead.Position = UDim2.fromOffset(12, 8)
	railHead.Size = UDim2.new(1, -24, 0, 14)

	local streak = frame(rail, "Streak", "FFFFFF") -- THE one white surface
	streak.Size = UDim2.fromOffset(3, L.RailRowH)
	streak.Visible = false
	self.streak = streak

	local rows = {
		{ key = "wardrobe", text = S.TAB_WARDROBE },
		{ key = "supply", text = S.TAB_SUPPLY },
		{ key = "codes", text = S.TAB_CODES },
	}
	for i, row in ipairs(rows) do
		local b = button(rail, "Row_" .. row.key, "> " .. row.text, 15, P.GREEN_DIM)
		b.Position = UDim2.fromOffset(L.RailPad, 30 + (i - 1) * (L.RailRowH + 6))
		b.Size = UDim2.new(1, -L.RailPad * 2, 0, L.RailRowH)
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Activated:Connect(function()
			self.deps.sfx("Click")
			self:setPanel(self.panelName == row.key and nil or row.key)
		end)
		b.MouseEnter:Connect(function()
			if self.panelName ~= row.key then
				b.TextColor3 = hex(P.GREEN_SOFT)
				self.deps.sfx("Hover")
			end
		end)
		b.MouseLeave:Connect(function()
			if self.panelName ~= row.key then b.TextColor3 = hex(P.GREEN_DIM) end
		end)
		self.railRows[row.key] = b
	end

	-- The glanceable wallet line at the rail's foot.
	self.railWallet = label(rail, "Wallet", "", 12, P.GREEN_SOFT)
	self.railWallet.AnchorPoint = Vector2.new(0, 1)
	self.railWallet.Position = UDim2.new(0, 12, 1, -8)
	self.railWallet.Size = UDim2.new(1, -24, 0, 16)

	self:_buildWardrobe(gui)
	self:_buildSupply(gui)
	self:_buildCodes(gui)
	self:_refreshPills(true)

	self.gui.Parent = self.deps.playerGui
end

-- RAIL / PANEL MOTION -----------------------------------------------------------
local function slideInfo(self)
	return TweenInfo.new(self.deps.motion.SLIDE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

function SupplyKit:setRail(open)
	if self.railOpen == open then return end
	self.railOpen = open
	local L = self.L
	if open then
		self.deps.send.sync()
		self:_rescale()
	else
		self:setPanel(nil)
	end
	TweenService:Create(self.rail, slideInfo(self), {
		Position = open and UDim2.new(0, 6, 0.5, 0) or UDim2.new(0, -L.RailW - 4, 0.5, 0),
	}):Play()
	TweenService:Create(self.railTab, slideInfo(self), {
		Position = open and UDim2.new(0, -L.RailTabW - 2, 0.5, 0) or UDim2.new(0, 0, 0.5, 0),
	}):Play()
end

-- One panel at a time; opening slides it out of the rail's edge, closing is
-- immediate (the rail itself carries the exit motion when it sleeps).
function SupplyKit:setPanel(name)
	local L = self.L
	local old = self.panelName
	self.panelName = name
	for key, b in pairs(self.railRows) do
		b.TextColor3 = hex(key == name and self.P.GREEN or self.P.GREEN_DIM)
	end
	if old and self.panels[old] then
		self.panels[old].Visible = false
		if old == "supply" then self:_endReveal() end
		if self.oddsModal then self.oddsModal.Visible = false end
	end
	local streakTarget = name and self.railRows[name] or nil
	self.streak.Visible = streakTarget ~= nil
	if streakTarget then
		self.streak.Position = UDim2.fromOffset(0, streakTarget.Position.Y.Offset)
	end
	if not name then return end
	local panel = self.panels[name]
	panel.Visible = true
	local x = L.RailW + L.PanelGap + 6
	panel.Position = UDim2.new(0, x - 14, 0.5, 0)
	TweenService:Create(panel, slideInfo(self), { Position = UDim2.new(0, x, 0.5, 0) }):Play()
	if name == "codes" then self:_setCodeStatus("idle") end
end

function SupplyKit:_rescale()
	local cam = workspace.CurrentCamera
	local view = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local L = self.L
	local widest = L.PanelWardrobeW + L.RailW + L.PanelGap + 20
	local s = math.clamp(math.min(view.Y / 710, view.X / widest), 0.55, 1.15)
	for _, scale in pairs(self.panelScales) do
		if scale.Scale ~= s then scale.Scale = s end
	end
end

-- WARDROBE ----------------------------------------------------------------------
function SupplyKit:_buildWardrobe(gui)
	local P, L, S = self.P, self.L, self.S
	local page, scale = panelShell(self, gui, "Wardrobe", L.PanelWardrobeW, L.PanelWardrobeH, S.TAB_WARDROBE)
	self.panels.wardrobe = page
	self.panelScales.wardrobe = scale

	local top = 42
	for i = 1, 8 do
		local b = button(page, "Slot" .. i, "--", 11, P.GREEN_DIM, P.PLATE)
		b.Position = UDim2.fromOffset(14 + (i - 1) * (L.WheelSlot + L.WheelGap), top)
		b.Size = UDim2.fromOffset(L.WheelSlot, L.WheelSlot)
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.TextWrapped = true
		stroke(b, P.GREEN_DIM, 1, 0.45)
		local num = label(b, "Num", tostring(i), 10, P.GREEN_DIM)
		num.Position = UDim2.fromOffset(3, 1)
		num.Size = UDim2.fromOffset(14, 11)
		b.Activated:Connect(function()
			self:_slotPressed(i)
		end)
		self.wheelButtons[i] = b
	end

	local gridTop = top + L.WheelSlot + 12
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(14, gridTop)
	grid.Size = UDim2.new(0, L.CardW * 2 + L.CardGap + 8, 1, -gridTop - 12)
	grid.ScrollBarThickness = 4
	grid.ScrollBarImageColor3 = hex(P.GREEN_DIM)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = page
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(L.CardW, L.CardH)
	layout.CellPadding = UDim2.fromOffset(L.CardGap, L.CardGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local sourceLine = {
		default = S.SOURCE_DEFAULT,
		crate = S.SOURCE_CRATE,
		robux = S.SOURCE_ROBUX,
		clearance = S.SOURCE_CLEARANCE,
	}
	for order, id in ipairs(self.deps.registry.list()) do
		local row = self.deps.registry.get(id)
		local ladder = self.deps.rarity[row.rarity] or self.deps.rarity.standard
		local card = button(grid, "Card_" .. id, "", 14, P.GREEN_SOFT, P.PLATE)
		card.LayoutOrder = order
		local cardStroke = stroke(card, ladder.stroke, ladder.double and 2 or 1, 0.25)
		-- The reference's colour notch: rarity as a left tick, not a wash.
		local notch = frame(card, "Notch", ladder.stroke)
		notch.Position = UDim2.fromOffset(0, 6)
		notch.Size = UDim2.fromOffset(3, L.CardH - 12)
		local name = label(card, "Name", row.name, 14, P.GREEN_SOFT)
		name.Position = UDim2.fromOffset(12, 8)
		name.Size = UDim2.new(1, -22, 0, 32)
		name.TextWrapped = true
		name.TextYAlignment = Enum.TextYAlignment.Top
		local tier = label(card, "Tier", ladder.label, 10, ladder.stroke)
		tier.AnchorPoint = Vector2.new(0, 1)
		tier.Position = UDim2.new(0, 12, 1, -22)
		tier.Size = UDim2.new(1, -22, 0, 12)
		local state = label(card, "State", S.SEALED, 11, P.GREEN_DIM)
		state.AnchorPoint = Vector2.new(0, 1)
		state.Position = UDim2.new(0, 12, 1, -6)
		state.Size = UDim2.new(1, -22, 0, 13)
		card.Activated:Connect(function()
			self.deps.sfx("Click")
			self:_select(id)
		end)
		self.cards[id] = { root = card, stroke = cardStroke, state = state, pulse = ladder.pulse, row = row, source = sourceLine[row.source] or "" }
	end

	local detail = frame(page, "Detail", P.PLATE)
	detail.AnchorPoint = Vector2.new(1, 0)
	detail.Position = UDim2.new(1, -14, 0, gridTop)
	detail.Size = UDim2.new(0, L.DetailW, 1, -gridTop - 12)
	stroke(detail, P.GREEN_DIM, 1, 0.4)
	self.detailName = label(detail, "Name", "--", 17, P.GREEN)
	self.detailName.Position = UDim2.fromOffset(12, 10)
	self.detailName.Size = UDim2.new(1, -24, 0, 40)
	self.detailName.TextWrapped = true
	self.detailInfo = label(detail, "Info", "", 12, P.GREEN_SOFT)
	self.detailInfo.Position = UDim2.fromOffset(12, 54)
	self.detailInfo.Size = UDim2.new(1, -24, 0, 38)
	self.detailInfo.TextWrapped = true

	self.playBtn = button(detail, "Btn_PLAY", S.PLAY, 15, P.GREEN, P.BG)
	self.playBtn.Position = UDim2.fromOffset(12, 98)
	self.playBtn.Size = UDim2.new(1, -24, 0, 32)
	stroke(self.playBtn, P.GREEN_DIM, 1, 0.35)
	self.playBtn.Activated:Connect(function()
		if self:_usable(self.selectedId) then
			self.deps.sfx("Confirm")
			self.deps.send.play(self.selectedId)
		else
			self.deps.sfx("Reject")
		end
	end)

	local assignHead = label(detail, "AssignHead", S.ASSIGN, 11, P.GREEN_DIM)
	assignHead.Position = UDim2.fromOffset(12, 140)
	assignHead.Size = UDim2.new(1, -24, 0, 13)
	for i = 1, 8 do
		local b = button(detail, "Assign" .. i, tostring(i), 13, P.GREEN_SOFT, P.BG)
		b.Position = UDim2.fromOffset(12 + (i - 1) * 28, 157)
		b.Size = UDim2.fromOffset(24, 24)
		b.TextXAlignment = Enum.TextXAlignment.Center
		stroke(b, P.GREEN_DIM, 1, 0.5)
		b.Activated:Connect(function()
			if self:_usable(self.selectedId) then
				self.deps.sfx("Confirm")
				self.deps.send.equip(i, self.selectedId)
			else
				self.deps.sfx("Reject")
			end
		end)
		self.slotButtons[i] = b
	end

	self.clearBtn = button(detail, "Btn_CLEAR", S.CLEAR, 12, P.GREEN_DIM, P.BG)
	self.clearBtn.Position = UDim2.fromOffset(12, 189)
	self.clearBtn.Size = UDim2.new(1, -24, 0, 24)
	stroke(self.clearBtn, P.GREEN_DIM, 1, 0.5)
	self.clearBtn.Activated:Connect(function()
		if not self.selectedId then return end
		for i = 1, 8 do
			if self.wheel[i] == self.selectedId then
				self.deps.sfx("Click")
				self.deps.send.equip(i, "")
				return
			end
		end
		self.deps.sfx("Reject")
	end)
end

-- REQUISITION -------------------------------------------------------------------
function SupplyKit:_buildSupply(gui)
	local P, L, S = self.P, self.L, self.S
	local page, scale = panelShell(self, gui, "Supply", L.PanelSupplyW, L.PanelSupplyH, S.TAB_SUPPLY)
	self.panels.supply = page
	self.panelScales.supply = scale

	local cratePanel = frame(page, "Crate", P.PLATE)
	cratePanel.Position = UDim2.fromOffset(14, 44)
	cratePanel.Size = UDim2.new(1, -28, 0, 200)
	stroke(cratePanel, P.GREEN_DIM, 1, 0.35)

	local glyph = label(cratePanel, "Glyph", "[ ▚▚▚ ]", 28, P.GREEN)
	glyph.AnchorPoint = Vector2.new(0.5, 0)
	glyph.Position = UDim2.new(0.5, 0, 0, 16)
	glyph.Size = UDim2.fromOffset(200, 34)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	self.crateGlyph = glyph

	self.crateStatus = label(cratePanel, "Status", S.KEYS_FROM, 12, P.GREEN_DIM)
	self.crateStatus.AnchorPoint = Vector2.new(0.5, 0)
	self.crateStatus.Position = UDim2.new(0.5, 0, 0, 58)
	self.crateStatus.Size = UDim2.new(1, -32, 0, 28)
	self.crateStatus.TextXAlignment = Enum.TextXAlignment.Center
	self.crateStatus.TextWrapped = true

	self.decryptBtn = button(cratePanel, "Btn_DECRYPT", S.DECRYPT, 19, P.GREEN, P.BG)
	self.decryptBtn.AnchorPoint = Vector2.new(0.5, 0)
	self.decryptBtn.Position = UDim2.new(0.5, 0, 0, 96)
	self.decryptBtn.Size = UDim2.fromOffset(200, 42)
	self.decryptBtn.TextXAlignment = Enum.TextXAlignment.Center
	stroke(self.decryptBtn, P.GREEN, 1, 0.3)
	self.decryptBtn.Activated:Connect(function()
		self:_decryptPressed()
	end)

	local oddsBtn = button(cratePanel, "Btn_ODDS", "( i ) " .. S.ODDS, 13, P.GREEN_SOFT, P.BG)
	oddsBtn.AnchorPoint = Vector2.new(0.5, 0)
	oddsBtn.Position = UDim2.new(0.5, 0, 0, 148)
	oddsBtn.Size = UDim2.fromOffset(200, 28)
	oddsBtn.TextXAlignment = Enum.TextXAlignment.Center
	stroke(oddsBtn, P.GREEN_DIM, 1, 0.5)
	oddsBtn.Activated:Connect(function()
		self.deps.sfx("Click")
		self:_showOdds()
	end)

	local passes = frame(page, "Passes", nil)
	passes.Position = UDim2.fromOffset(14, 254)
	passes.Size = UDim2.new(1, -28, 1, -266)
	local passList = Instance.new("UIListLayout")
	passList.Padding = UDim.new(0, 8)
	passList.SortOrder = Enum.SortOrder.LayoutOrder
	passList.Parent = passes

	for order, key in ipairs(self.deps.money.list()) do
		local pass = self.deps.money.PASSES[key]
		local armed = self.deps.money.armed(key)
		local tile = frame(passes, "Pass_" .. key, P.PLATE)
		tile.LayoutOrder = order
		tile.Size = UDim2.new(1, 0, 0, 58)
		stroke(tile, P.GREEN_DIM, 1, armed and 0.35 or 0.6)
		local name = label(tile, "Name", pass.name, 14, armed and P.GREEN or P.GREEN_DIM)
		name.Position = UDim2.fromOffset(12, 7)
		name.Size = UDim2.new(1, -140, 0, 18)
		local grants = #self.deps.money.grantedEmotes(key)
		local line = label(
			tile,
			"Grants",
			grants > 0 and string.format("GRANTS %d EMOTE(S)", grants) or "SUPPORTER STANDING",
			11,
			P.GREEN_DIM
		)
		line.Position = UDim2.fromOffset(12, 28)
		line.Size = UDim2.new(1, -140, 0, 13)
		local action = button(tile, "Btn_BUY", armed and S.ACQUIRE or S.OFFLINE, 12, armed and P.GREEN_SOFT or P.GREEN_DIM, P.BG)
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -10, 0.5, 0)
		action.Size = UDim2.fromOffset(104, 24)
		action.TextXAlignment = Enum.TextXAlignment.Center
		stroke(action, P.GREEN_DIM, 1, armed and 0.4 or 0.65)
		if armed then
			action.Activated:Connect(function()
				self.deps.sfx("Click")
				self.deps.send.shop(pass.sku)
			end)
		end
	end

	local price = tonumber(self.deps.money.PrivateServerPrice) or 0
	if price > 0 then
		local tile = frame(passes, "Pass_PRIVATE", P.PLATE)
		tile.LayoutOrder = 99
		tile.Size = UDim2.new(1, 0, 0, 40)
		stroke(tile, P.GREEN_DIM, 1, 0.45)
		local name = label(tile, "Name", S.PRIVATE, 13, P.GREEN_SOFT)
		name.Position = UDim2.fromOffset(12, 4)
		name.Size = UDim2.new(1, -24, 0, 17)
		local line = label(tile, "Price", string.format("R$ %d - VIA SERVER MENU", price), 11, P.GREEN_DIM)
		line.Position = UDim2.fromOffset(12, 22)
		line.Size = UDim2.new(1, -24, 0, 13)
	end

	self:_buildOdds(page)
end

-- ODDS MODAL (inside the requisition panel -- still minimal) --------------------
function SupplyKit:_buildOdds(page)
	local P, S = self.P, self.S
	local modal = frame(page, "Odds", P.BG)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.new(1, -40, 1, -60)
	modal.Visible = false
	modal.ZIndex = 30
	modal.Active = true
	stroke(modal, P.GREEN, 1, 0.3)
	cornerTicks(modal, P.GREEN)
	self.oddsModal = modal

	local title = label(modal, "Title", S.ODDS_TITLE, 16, P.GREEN)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 20)
	title.ZIndex = 31
	self.oddsRows = label(modal, "Rows", "", 14, P.GREEN_SOFT)
	self.oddsRows.Position = UDim2.fromOffset(16, 40)
	self.oddsRows.Size = UDim2.new(1, -32, 1, -116)
	self.oddsRows.TextYAlignment = Enum.TextYAlignment.Top
	self.oddsRows.ZIndex = 31
	local note = label(modal, "Note", S.ODDS_NOTE, 10, P.GREEN_DIM)
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 16, 1, -42)
	note.Size = UDim2.new(1, -32, 0, 26)
	note.TextWrapped = true
	note.ZIndex = 31
	local closeBtn = button(modal, "Btn_CLOSE", S.CLOSE, 13, P.GREEN_SOFT, P.PLATE)
	closeBtn.AnchorPoint = Vector2.new(0.5, 1)
	closeBtn.Position = UDim2.new(0.5, 0, 1, -8)
	closeBtn.Size = UDim2.fromOffset(110, 26)
	closeBtn.TextXAlignment = Enum.TextXAlignment.Center
	closeBtn.ZIndex = 31
	stroke(closeBtn, P.GREEN_DIM, 1, 0.4)
	closeBtn.Activated:Connect(function()
		self.deps.sfx("Click")
		modal.Visible = false
	end)
end

function SupplyKit:_showOdds()
	local pool = self.deps.rules.pool(self.deps.registry.Emotes, self.owned)
	local odds = self.deps.rules.odds(pool, self.deps.registry.Emotes, self.deps.crate.WEIGHTS)
	if #odds == 0 then
		self.oddsRows.Text = self.S.EMPTY
	else
		local lines = {}
		for _, band in ipairs(odds) do
			local ladder = self.deps.rarity[band.rarity] or self.deps.rarity.standard
			lines[#lines + 1] = string.format("%-10s %5.1f%%", ladder.label, band.percent)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = string.format("%d ITEM(S) IN STOCK", #pool)
		self.oddsRows.Text = table.concat(lines, "\n")
	end
	self.oddsModal.Visible = true
end

-- ACCESS CODES -------------------------------------------------------------------
function SupplyKit:_buildCodes(gui)
	local P, L, S = self.P, self.L, self.S
	local page, scale = panelShell(self, gui, "Codes", L.PanelCodesW, L.PanelCodesH, S.TAB_CODES)
	self.panels.codes = page
	self.panelScales.codes = scale

	local box = Instance.new("TextBox")
	box.Name = "CodeInput"
	box.BackgroundColor3 = hex(P.PLATE)
	box.BorderSizePixel = 0
	box.Font = FONT
	box.PlaceholderText = S.CODE_PLACEHOLDER
	box.PlaceholderColor3 = hex(P.GREEN_DIM)
	box.Text = ""
	box.TextSize = 16
	box.TextColor3 = hex(P.GREEN)
	box.ClearTextOnFocus = false
	box.Position = UDim2.fromOffset(14, 50)
	box.Size = UDim2.new(1, -28, 0, 36)
	box.Parent = page
	stroke(box, P.GREEN_DIM, 1, 0.4)
	self.codeBox = box

	self.redeemBtn = button(page, "Btn_REDEEM", S.REDEEM, 15, P.GREEN, P.PLATE)
	self.redeemBtn.Position = UDim2.fromOffset(14, 96)
	self.redeemBtn.Size = UDim2.new(1, -28, 0, 34)
	self.redeemBtn.TextXAlignment = Enum.TextXAlignment.Center
	stroke(self.redeemBtn, P.GREEN_DIM, 1, 0.35)
	self.redeemBtn.Activated:Connect(function()
		self:_redeemPressed()
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then self:_redeemPressed() end
	end)

	self.codeStatus = label(page, "Status", "", 12, P.GREEN_SOFT)
	self.codeStatus.Position = UDim2.fromOffset(14, 140)
	self.codeStatus.Size = UDim2.new(1, -28, 0, 30)
	self.codeStatus.TextWrapped = true

	local hint = label(page, "Hint", S.CODE_HINT, 10, P.GREEN_DIM)
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 14, 1, -10)
	hint.Size = UDim2.new(1, -28, 0, 14)
	hint.TextWrapped = true
end

function SupplyKit:_setCodeStatus(state, extra)
	local S = self.S
	local map = {
		idle = { text = "", color = self.P.GREEN_SOFT },
		verifying = { text = S.VERIFYING, color = self.P.GREEN_DIM },
		ok = { text = S.CODE_OK .. (extra or ""), color = self.P.GREEN },
		INVALID = { text = S.CODE_INVALID, color = self.P.GREEN_DIM },
		USED = { text = S.CODE_USED, color = self.P.GREEN_DIM },
		EXPIRED = { text = S.CODE_EXPIRED, color = self.P.GREEN_DIM },
	}
	local row = map[state] or map.idle
	self.codeStatus.Text = row.text
	self.codeStatus.TextColor3 = hex(row.color)
	self.redeemBtn.Text = state == "verifying" and S.VERIFYING or S.REDEEM
	self.redeemBtn.TextColor3 = hex(state == "verifying" and self.P.GREEN_DIM or self.P.GREEN)
end

-- The error feedback is a glitch shake, never a red -- the spec's own rule.
function SupplyKit:_shakeCodeBox()
	if not self.deps.motionOk() then return end
	local box = self.codeBox
	local base = UDim2.fromOffset(14, 50)
	local t1 = TweenService:Create(box, TweenInfo.new(0.05), { Position = UDim2.fromOffset(20, 50) })
	local t2 = TweenService:Create(box, TweenInfo.new(0.05), { Position = UDim2.fromOffset(8, 50) })
	local t3 = TweenService:Create(box, TweenInfo.new(0.06), { Position = base })
	t1.Completed:Connect(function()
		t2:Play()
	end)
	t2.Completed:Connect(function()
		t3:Play()
	end)
	t1:Play()
end

function SupplyKit:_redeemPressed()
	if self.codeBusy then return end
	-- Format is pre-checked with the SAME pure module the server uses; only
	-- plausibly-shaped codes ever reach the wire. Validity stays server-side.
	local code = self.deps.promo.normalize(self.codeBox.Text)
	if code == nil then
		self.deps.sfx("Reject")
		self:_setCodeStatus("INVALID")
		self:_shakeCodeBox()
		return
	end
	self.codeBusy = true
	self.codeWait = os.clock()
	self:_setCodeStatus("verifying")
	self.deps.sfx("ClickAlt")
	self.deps.send.redeem(code)
end

function SupplyKit:_onPromoResult(packet)
	self.codeBusy = false
	if type(packet.keys) == "number" then self.keys = packet.keys end
	if type(packet.fragments) == "number" then self.fragments = packet.fragments end
	self:_refreshPills(false)
	if packet.ok == true then
		local granted = type(packet.granted) == "table" and packet.granted or {}
		local parts = {}
		local keys = tonumber(granted.keys) or 0
		local fragments = tonumber(granted.fragments) or 0
		if keys > 0 then parts[#parts + 1] = string.format("+%d %s", keys, self.S.WALLET_KEYS) end
		if fragments > 0 then parts[#parts + 1] = string.format("+%d %s", fragments, self.S.WALLET_FRAGMENTS) end
		if type(granted.emotes) == "table" then
			for _, id in ipairs(granted.emotes) do
				local row = self.deps.registry.get(id)
				if row then parts[#parts + 1] = "+" .. row.name end
			end
		end
		local extra = #parts > 0 and (": " .. table.concat(parts, ", ")) or ""
		self.deps.sfx("Confirm")
		self:_setCodeStatus("ok", extra)
		self.codeBox.Text = ""
	else
		self.deps.sfx("Reject")
		self:_setCodeStatus(packet.reason or "INVALID")
		self:_shakeCodeBox()
	end
end

-- STATE ---------------------------------------------------------------------------
function SupplyKit:_usable(id)
	if not id then return false end
	if self.owned[id] == true then return true end
	local row = self.deps.registry.get(id)
	return row ~= nil and row.source == "default"
end

function SupplyKit:_select(id)
	self.selectedId = id
	self:_refreshDetail()
end

local function shortName(row)
	local name = row and row.name or "--"
	if #name > 7 then return string.sub(name, 1, 6) .. "." end
	return name
end

function SupplyKit:_refreshDetail()
	local S = self.S
	local id = self.selectedId
	local row = id and self.deps.registry.get(id) or nil
	if not row then
		self.detailName.Text = "--"
		self.detailInfo.Text = ""
		return
	end
	self.detailName.Text = row.name
	local ownedLine
	if self:_usable(id) then
		ownedLine = S.OWNED
		for i = 1, 8 do
			if self.wheel[i] == id then ownedLine = S.ON_WHEEL .. " [" .. i .. "]" end
		end
	elseif row.source == "crate" then
		ownedLine = S.SEALED .. " - " .. S.SOURCE_CRATE
	elseif row.source == "robux" then
		ownedLine = S.SEALED .. " - " .. S.SOURCE_ROBUX
	elseif row.source == "clearance" then
		ownedLine = S.SEALED .. " - " .. S.SOURCE_CLEARANCE
	else
		ownedLine = S.OWNED
	end
	local ladder = self.deps.rarity[row.rarity] or self.deps.rarity.standard
	self.detailInfo.Text = ladder.label .. "\n" .. ownedLine
	local usable = self:_usable(id)
	self.playBtn.TextColor3 = hex(usable and self.P.GREEN or self.P.GREEN_DIM)
	self.clearBtn.TextColor3 = hex(usable and self.P.GREEN_SOFT or self.P.GREEN_DIM)
end

function SupplyKit:_refreshCards()
	local S = self.S
	for id, card in pairs(self.cards) do
		local isOwned = self.owned[id] == true or card.row.source == "default"
		local onWheel = false
		for i = 1, 8 do
			if self.wheel[i] == id then onWheel = true end
		end
		local text = isOwned and (onWheel and S.ON_WHEEL or S.OWNED) or S.SEALED
		if card.state.Text ~= text then card.state.Text = text end
		local strokeT = isOwned and 0.1 or 0.55
		if card.stroke.Transparency ~= strokeT then card.stroke.Transparency = strokeT end
	end
	for i = 1, 8 do
		local id = self.wheel[i]
		local row = id and id ~= "" and self.deps.registry.get(id) or nil
		local text = row and shortName(row) or "--"
		local b = self.wheelButtons[i]
		if b.Text ~= text then b.Text = text end
		b.TextColor3 = hex(row and self.P.GREEN_SOFT or self.P.GREEN_DIM)
	end
end

function SupplyKit:_refreshPills(instant)
	if instant then
		self.shownKeys = self.keys
		self.shownFragments = self.fragments
	end
	local per = self.deps.fragmentsPerKey
	local text = string.format(
		"%s %d · %s %d/%d",
		self.S.WALLET_KEYS,
		math.floor(self.shownKeys + 0.5),
		self.S.WALLET_FRAGMENTS,
		math.floor(self.shownFragments + 0.5),
		per
	)
	if self.railWallet.Text ~= text then self.railWallet.Text = text end
	local canOpen = self.keys >= self.deps.crate.COST_KEYS
	self.decryptBtn.TextColor3 = hex(canOpen and self.P.GREEN or self.P.GREEN_DIM)
end

function SupplyKit:_slotPressed(i)
	if self:_usable(self.selectedId) then
		self.deps.sfx("Confirm")
		self.deps.send.equip(i, self.selectedId)
		return
	end
	local id = self.wheel[i]
	if id and id ~= "" then
		self.deps.sfx("Click")
		self:_select(id)
	else
		self.deps.sfx("Reject")
	end
end

-- PACKETS -------------------------------------------------------------------------
function SupplyKit:onPacket(packet)
	if type(packet) ~= "table" then return end
	if packet.kind == "emotestate" then
		local owned = {}
		if type(packet.owned) == "table" then
			for _, id in ipairs(packet.owned) do
				owned[id] = true
			end
		end
		self.owned = owned
		self.equipped = type(packet.equipped) == "string" and packet.equipped or ""
		self.wheel = type(packet.wheel) == "table" and packet.wheel or {}
		self:_refreshCards()
		self:_refreshDetail()
	elseif packet.kind == "profilestate" then
		if type(packet.keys) == "number" then self.keys = packet.keys end
		if type(packet.fragments) == "number" then self.fragments = packet.fragments end
		self:_refreshPills(false)
	elseif packet.kind == "crateresult" then
		self:_onCrateResult(packet)
	elseif packet.kind == "promoresult" then
		self:_onPromoResult(packet)
	end
end

-- THE CEREMONY (client half) ------------------------------------------------------
function SupplyKit:_decryptPressed()
	if self.revealBusy then return end
	if self.keys < self.deps.crate.COST_KEYS then
		self.deps.sfx("Reject")
		self.crateStatus.Text = self.S.NO_KEYS
		return
	end
	local pool = self.deps.rules.pool(self.deps.registry.Emotes, self.owned)
	if #pool == 0 then
		self.deps.sfx("Reject")
		self.crateStatus.Text = self.S.EMPTY
		return
	end
	self.revealBusy = true
	self.revealWait = os.clock()
	self.crateStatus.Text = self.S.DECRYPTING
	self.deps.sfx("ClickAlt")
	self.deps.send.open()
end

function SupplyKit:_onCrateResult(packet)
	if type(packet.keys) == "number" then self.keys = packet.keys end
	if type(packet.fragments) == "number" then self.fragments = packet.fragments end
	self:_refreshPills(false)
	if packet.ok ~= true then
		self.revealBusy = false
		self.crateStatus.Text = packet.reason == "EMPTY" and self.S.EMPTY or self.S.NO_KEYS
		self.deps.sfx("Reject")
		return
	end
	if not self.revealBusy then return end
	if self.panelName ~= "supply" then
		-- Panel closed mid-flight: keep the facts, skip the ceremony.
		self.revealBusy = false
		return
	end
	self:_runReveal(packet)
end

-- The reveal covers the REQUISITION PANEL only -- minimal, like everything else.
function SupplyKit:_runReveal(packet)
	local P, L = self.P, self.L
	local host = self.panels.supply
	local reveal = frame(host, "Reveal", P.BG)
	reveal.Size = UDim2.fromScale(1, 1)
	reveal.ZIndex = 40
	reveal.Active = true
	stroke(reveal, P.GREEN_DIM, 1, 0.5)
	self.reveal = reveal

	local ladder = self.deps.rarity[packet.rarity] or self.deps.rarity.standard
	local spin = self.deps.reveal.SPIN + (self.deps.reveal.SPIN_BONUS[packet.rarity] or 0)

	local window = frame(reveal, "Window", P.PLATE)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.38)
	window.Size = UDim2.new(1, -40, 0, L.ReelTileH + 20)
	window.ClipsDescendants = true
	window.ZIndex = 41
	stroke(window, P.GREEN_DIM, 1, 0.35)

	local strip = frame(window, "Strip", nil)
	strip.Size = UDim2.fromOffset(#packet.reel * (L.ReelTileW + L.ReelGap), L.ReelTileH)
	strip.Position = UDim2.new(0, 0, 0.5, -L.ReelTileH / 2)
	strip.ZIndex = 41
	for i, id in ipairs(packet.reel) do
		local row = self.deps.registry.get(id)
		local tile = frame(strip, "Tile" .. i, P.BG)
		tile.Position = UDim2.fromOffset((i - 1) * (L.ReelTileW + L.ReelGap), 0)
		tile.Size = UDim2.fromOffset(L.ReelTileW, L.ReelTileH)
		tile.ZIndex = 41
		local tileLadder = row and self.deps.rarity[row.rarity] or self.deps.rarity.standard
		stroke(tile, tileLadder.stroke, 1, 0.3)
		local name = label(tile, "Name", row and row.name or "?", 13, P.GREEN_SOFT)
		name.Position = UDim2.fromOffset(6, 6)
		name.Size = UDim2.new(1, -12, 1, -12)
		name.TextWrapped = true
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextYAlignment = Enum.TextYAlignment.Center
		name.ZIndex = 42
	end

	local ticker = frame(window, "Ticker", ladder.stroke)
	ticker.AnchorPoint = Vector2.new(0.5, 0)
	ticker.Position = UDim2.fromScale(0.5, 0)
	ticker.Size = UDim2.new(0, 2, 1, 0)
	ticker.ZIndex = 45

	local resultCard = label(reveal, "Result", "", 22, P.GREEN)
	resultCard.AnchorPoint = Vector2.new(0.5, 0)
	resultCard.Position = UDim2.fromScale(0.5, 0.58)
	resultCard.Size = UDim2.new(1, -60, 0, 32)
	resultCard.TextXAlignment = Enum.TextXAlignment.Center
	resultCard.ZIndex = 41
	local rarityLine = label(reveal, "Rarity", "", 14, ladder.stroke)
	rarityLine.AnchorPoint = Vector2.new(0.5, 0)
	rarityLine.Position = UDim2.fromScale(0.5, 0.67)
	rarityLine.Size = UDim2.new(1, -60, 0, 18)
	rarityLine.TextXAlignment = Enum.TextXAlignment.Center
	rarityLine.ZIndex = 41

	local windowW = self.L.PanelSupplyW - 40
	local windowMid = windowW / 2
	local resultX = (self.deps.crate.RESULT_INDEX - 1) * (L.ReelTileW + L.ReelGap) + L.ReelTileW / 2
	local targetX = windowMid - resultX

	self.revealState = {
		frame = reveal,
		strip = strip,
		phase = "shake",
		t0 = os.clock(),
		spin = spin,
		targetX = targetX,
		lastTick = -1,
		packet = packet,
		resultCard = resultCard,
		rarityLine = rarityLine,
		typed = 0,
		windowMid = windowMid,
		ladder = ladder,
	}

	if not self.deps.motionOk() then
		strip.Position = UDim2.new(0, targetX, 0.5, -L.ReelTileH / 2)
		self.revealState.phase = "typed"
		self.revealState.t0 = os.clock()
		self.deps.sfx("Confirm")
	end
end

-- One stepped tick for everything that moves; called by the host's loop.
function SupplyKit:step(now)
	local function chase(shown, target)
		if shown == target then return target end
		local delta = target - shown
		if math.abs(delta) < 0.4 then return target end
		return shown + delta * 0.35
	end
	local beforeK, beforeF = self.shownKeys, self.shownFragments
	self.shownKeys = chase(self.shownKeys, self.keys)
	self.shownFragments = chase(self.shownFragments, self.fragments)
	if self.shownKeys ~= beforeK or self.shownFragments ~= beforeF then
		self:_refreshPills(false)
	end

	self.pulsePhase = (self.pulsePhase + 0.08) % (math.pi * 2)
	local pulseT = 0.1 + 0.35 * (0.5 + 0.5 * math.sin(self.pulsePhase))
	if self.panelName == "wardrobe" then
		for _, card in pairs(self.cards) do
			if card.pulse and card.stroke.Transparency < 0.5 then
				card.stroke.Transparency = pulseT
			end
		end
	end

	if self.revealBusy and not self.revealState and now - self.revealWait > OPEN_TIMEOUT then
		self.revealBusy = false
		self.crateStatus.Text = self.S.KEYS_FROM
	end
	if self.codeBusy and now - self.codeWait > CODE_TIMEOUT then
		self.codeBusy = false
		self:_setCodeStatus("idle")
	end

	local reveal = self.revealState
	if not reveal then return end
	local R = self.deps.reveal
	local elapsed = now - reveal.t0

	if reveal.phase == "shake" then
		if self.deps.motionOk() then
			local mag = 4 * (1 - elapsed / R.SHAKE)
			reveal.strip.Position = UDim2.new(
				0,
				math.floor(math.sin(elapsed * 43) * mag + 0.5),
				0.5,
				-self.L.ReelTileH / 2
			)
		end
		if elapsed >= R.SHAKE then
			reveal.phase = "spin"
			reveal.t0 = now
			TweenService:Create(
				reveal.strip,
				TweenInfo.new(reveal.spin, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0, reveal.targetX, 0.5, -self.L.ReelTileH / 2) }
			):Play()
		end
	elseif reveal.phase == "spin" then
		local x = reveal.strip.Position.X.Offset
		local under = math.floor((reveal.windowMid - x) / (self.L.ReelTileW + self.L.ReelGap))
		if under ~= reveal.lastTick then
			reveal.lastTick = under
			self.deps.sfx("Click")
		end
		if elapsed >= reveal.spin + R.SETTLE then
			reveal.phase = "flash"
			reveal.t0 = now
			self.deps.sfx("Confirm")
			reveal.frame.BackgroundColor3 = hex(self.P.PLATE)
		end
	elseif reveal.phase == "flash" then
		if elapsed >= R.FLASH then
			reveal.frame.BackgroundColor3 = hex(self.P.BG)
			reveal.phase = "typed"
			reveal.t0 = now
		end
	elseif reveal.phase == "typed" then
		local name = reveal.packet.name or "?"
		local want = math.min(#name, math.floor(elapsed * 24))
		if want ~= reveal.typed then
			reveal.typed = want
			reveal.resultCard.Text = string.sub(name, 1, want) .. (want < #name and "_" or "")
		end
		if want >= #name and elapsed >= R.HOLD then
			reveal.phase = "done"
			reveal.rarityLine.Text = reveal.ladder.label
			self:_buildRevealButtons(reveal)
		end
	end
end

function SupplyKit:_buildRevealButtons(reveal)
	local P, S = self.P, self.S
	local claim = button(reveal.frame, "Btn_CLAIM", S.CLAIM, 16, P.GREEN, P.PLATE)
	claim.AnchorPoint = Vector2.new(0.5, 1)
	claim.Position = UDim2.new(0.5, -80, 1, -14)
	claim.Size = UDim2.fromOffset(140, 36)
	claim.TextXAlignment = Enum.TextXAlignment.Center
	claim.ZIndex = 41
	stroke(claim, P.GREEN_DIM, 1, 0.35)
	claim.Activated:Connect(function()
		self.deps.sfx("Click")
		self:_endReveal()
	end)
	local again = button(reveal.frame, "Btn_AGAIN", S.AGAIN, 13, P.GREEN_SOFT, P.PLATE)
	again.AnchorPoint = Vector2.new(0.5, 1)
	again.Position = UDim2.new(0.5, 86, 1, -14)
	again.Size = UDim2.fromOffset(160, 36)
	again.TextXAlignment = Enum.TextXAlignment.Center
	again.ZIndex = 41
	stroke(again, P.GREEN_DIM, 1, 0.5)
	again.Activated:Connect(function()
		self:_endReveal()
		self:_decryptPressed()
	end)
end

function SupplyKit:_endReveal()
	if self.reveal then
		self.reveal:Destroy()
		self.reveal = nil
	end
	self.revealState = nil
	self.revealBusy = false
	self.crateStatus.Text = self.S.KEYS_FROM
end

-- HOST SURFACE --------------------------------------------------------------------
-- The host shows/hides the WHOLE gui (trial, title menu); closing also parks
-- the rail so re-entry always starts from the slim tab.
function SupplyKit:setVisible(on)
	if self.gui.Enabled == on then return end
	if not on then
		self:setPanel(nil)
		self:setRail(false)
		-- Park instantly: a tween on a disabled gui finishes unseen anyway.
		self.rail.Position = UDim2.new(0, -self.L.RailW - 4, 0.5, 0)
		self.railTab.Position = UDim2.new(0, 0, 0.5, 0)
	end
	self.gui.Enabled = on
end

function SupplyKit:isBusy()
	return self.revealBusy or self.codeBusy
end

function SupplyKit:destroy()
	self:_endReveal()
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return SupplyKit
