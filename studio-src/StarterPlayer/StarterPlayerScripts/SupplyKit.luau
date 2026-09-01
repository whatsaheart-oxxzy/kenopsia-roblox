--!nonstrict
-- SUPPLY KIT (01.09.2026) -- the wardrobe + requisition screens as a module.
--
-- The TrialClientKit pattern: everything visual lives here, mountable by a
-- thin host (SupplyClient in this place; the Kenopsia_DEV menu redesign can
-- mount the same file with its own host + palette when the ceremony moves to
-- the menu place, which is where EmoteRegistry says crates belong long-term).
-- The kit never touches a remote or a service directly -- every send goes
-- through deps.send and every fact arrives through onPacket, so the host owns
-- the wire and the kit stays portable and testable.
--
-- WHAT IT RENDERS (docs/MENU-SHOP-UIUX-SPEC.md, reworked to the machine):
--   * a left tab rail (the spec's sidebar, sized to the two destinations that
--     exist) with the white selection streak -- WHITE nowhere else;
--   * wallet pills (earned keys + fragment progress -- there is no "credits"
--     currency and no Robux balance to sum);
--   * WARDROBE: the 8-slot wheel strip, the catalog grid with the rarity
--     frame ladder, and a detail panel whose PLAY goes through the real
--     server gate (no viewport mannequin -- the lobby character is the
--     preview, and it exercises the true wire);
--   * REQUISITION: the crate panel with DECRYPT + the MANIFEST odds modal
--     (odds computed from the live pool via CrateRules -- they can never
--     drift from the server, which rolls with the same module), the reveal
--     ceremony (shake -> reel -> flash -> typewriter), and the gamepass
--     tiles (unarmed passes read OFFLINE and never prompt).
--
-- MainMenu's three performance rules apply: own ScreenGui, NO RenderStepped
-- (one stepped loop at deps.stepSeconds, every writer compares before it
-- writes), and closed means closed -- gui disabled, loop gated, the reveal
-- strip destroyed after every ceremony.
local TweenService = game:GetService("TweenService")

local SupplyKit = {}
SupplyKit.__index = SupplyKit

local FONT = Enum.Font.Code

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

-- CREATE ----------------------------------------------------------------------
function SupplyKit.create(deps)
	local self = setmetatable({}, SupplyKit)
	self.deps = deps
	self.P = deps.palette
	self.L = deps.layout
	self.S = deps.strings

	-- Replicated facts, all defaulted so the screens render before the first
	-- packet (the volatile-first discipline, client edition).
	self.owned = {}
	self.equipped = ""
	self.wheel = {}
	self.keys = 0
	self.fragments = 0
	self.shownKeys = 0
	self.shownFragments = 0
	self.selectedId = nil
	self.tab = 1
	self.revealBusy = false
	self.revealWait = 0
	self.pulsePhase = 0
	self.loopOn = false
	self.cards = {}
	self.slotButtons = {}
	self.wheelButtons = {}

	self:_build()
	return self
end

function SupplyKit:_build()
	local P, L, S = self.P, self.L, self.S

	local gui = Instance.new("ScreenGui")
	gui.Name = "KenopsiaSupply"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	-- BETWEEN the machine (50) and the CRT glass (60), under the main menu
	-- (55): the supply terminal reads through the same tube as everything
	-- else, and the title terminal covers it if both are ever open.
	gui.DisplayOrder = 54
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	self.gui = gui

	local dim = frame(gui, "Dim", P.BG)
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundTransparency = 0.35
	dim.Active = true

	local panel = frame(gui, "Panel", P.BG)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(L.PanelW, L.PanelH)
	stroke(panel, P.GREEN_DIM, 1, 0.35)
	self.panel = panel

	-- One UIScale of our own: this gui does not share the machine's, and the
	-- panel is authored against the same ~710 px reference height.
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	self.scale = scale

	-- HEADER ------------------------------------------------------------------
	local header = frame(panel, "Header", nil)
	header.Size = UDim2.new(1, 0, 0, L.HeaderH)
	local title = label(header, "Title", S.TITLE, 24, P.GREEN)
	title.Position = UDim2.fromOffset(18, 0)
	title.Size = UDim2.new(0, 320, 1, 0)

	local closeBtn = button(header, "Btn_CLOSE", S.CLOSE, 16, P.GREEN_SOFT, P.PLATE)
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -14, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(84, 30)
	stroke(closeBtn, P.GREEN_DIM, 1, 0.4)
	closeBtn.Activated:Connect(function()
		self.deps.sfx("Click")
		self:close()
	end)

	local pills = frame(header, "Pills", nil)
	pills.AnchorPoint = Vector2.new(1, 0.5)
	pills.Position = UDim2.new(1, -112, 0.5, 0)
	pills.Size = UDim2.fromOffset(360, L.PillH)
	local pillList = Instance.new("UIListLayout")
	pillList.FillDirection = Enum.FillDirection.Horizontal
	pillList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	pillList.VerticalAlignment = Enum.VerticalAlignment.Center
	pillList.Padding = UDim.new(0, L.PillGap)
	pillList.Parent = pills

	local function pill(name)
		local p = frame(pills, name, self.P.PLATE)
		p.Size = UDim2.fromOffset(150, L.PillH)
		stroke(p, self.P.GREEN_DIM, 1, 0.45)
		local t = label(p, "Value", "", 15, self.P.GREEN_SOFT)
		t.Position = UDim2.fromOffset(10, 0)
		t.Size = UDim2.new(1, -20, 1, 0)
		return t
	end
	self.keysLabel = pill("PillKeys")
	self.fragmentsLabel = pill("PillFragments")

	-- RAIL --------------------------------------------------------------------
	local rail = frame(panel, "Rail", nil)
	rail.Position = UDim2.fromOffset(0, L.HeaderH)
	rail.Size = UDim2.new(0, L.RailW, 1, -L.HeaderH)

	local streak = frame(rail, "Streak", "FFFFFF") -- THE one white surface
	streak.Size = UDim2.fromOffset(3, L.RailRowH)
	self.streak = streak

	self.tabButtons = {}
	local tabs = { S.TAB_WARDROBE, S.TAB_SUPPLY }
	for i, name in ipairs(tabs) do
		local b = button(rail, "Tab" .. i, "> " .. name, 18, P.GREEN_DIM)
		b.Position = UDim2.fromOffset(L.RailPad, (i - 1) * (L.RailRowH + 6) + 8)
		b.Size = UDim2.new(1, -L.RailPad * 2, 0, L.RailRowH)
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Activated:Connect(function()
			self.deps.sfx("Click")
			self:setTab(i)
		end)
		b.MouseEnter:Connect(function()
			if self.tab ~= i then
				b.TextColor3 = hex(P.GREEN_SOFT)
				self.deps.sfx("Hover")
			end
		end)
		b.MouseLeave:Connect(function()
			if self.tab ~= i then b.TextColor3 = hex(P.GREEN_DIM) end
		end)
		self.tabButtons[i] = b
	end

	local railLine = frame(rail, "Line", P.GREEN_DIM)
	railLine.Position = UDim2.new(1, -1, 0, 0)
	railLine.Size = UDim2.new(0, 1, 1, 0)
	railLine.BackgroundTransparency = 0.55

	-- CONTENT -----------------------------------------------------------------
	local content = frame(panel, "Content", nil)
	content.Position = UDim2.fromOffset(L.RailW, L.HeaderH)
	content.Size = UDim2.new(1, -L.RailW, 1, -L.HeaderH)
	self.content = content

	self:_buildWardrobe(content)
	self:_buildSupply(content)
	self:_buildOdds(content)
	self:setTab(1)
	self:_refreshPills(true)

	self.gui.Parent = self.deps.playerGui
end

-- WARDROBE --------------------------------------------------------------------
function SupplyKit:_buildWardrobe(content)
	local P, L, S = self.P, self.L, self.S
	local page = frame(content, "Wardrobe", nil)
	page.Size = UDim2.fromScale(1, 1)
	self.wardrobePage = page

	-- The 8-slot wheel strip.
	local wheelHead = label(page, "WheelHead", S.WHEEL, 14, P.GREEN_DIM)
	wheelHead.Position = UDim2.fromOffset(16, 6)
	wheelHead.Size = UDim2.fromOffset(300, 16)
	for i = 1, 8 do
		local b = button(page, "Slot" .. i, "--", 12, P.GREEN_DIM, P.PLATE)
		b.Position = UDim2.fromOffset(16 + (i - 1) * (L.WheelSlot + L.WheelGap), 26)
		b.Size = UDim2.fromOffset(L.WheelSlot, L.WheelSlot)
		b.TextXAlignment = Enum.TextXAlignment.Center
		b.TextWrapped = true
		stroke(b, P.GREEN_DIM, 1, 0.45)
		local num = label(b, "Num", tostring(i), 11, P.GREEN_DIM)
		num.Position = UDim2.fromOffset(4, 1)
		num.Size = UDim2.fromOffset(16, 12)
		b.Activated:Connect(function()
			self:_slotPressed(i)
		end)
		self.wheelButtons[i] = b
	end

	-- The catalog grid.
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(16, 26 + L.WheelSlot + 16)
	grid.Size = UDim2.new(1, -32 - L.DetailW, 1, -(26 + L.WheelSlot + 28))
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
		local name = label(card, "Name", row.name, 15, P.GREEN_SOFT)
		name.Position = UDim2.fromOffset(10, 8)
		name.Size = UDim2.new(1, -20, 0, 34)
		name.TextWrapped = true
		name.TextYAlignment = Enum.TextYAlignment.Top
		local src = label(card, "Source", sourceLine[row.source] or "", 11, P.GREEN_DIM)
		src.AnchorPoint = Vector2.new(0, 1)
		src.Position = UDim2.new(0, 10, 1, -24)
		src.Size = UDim2.new(1, -20, 0, 14)
		local state = label(card, "State", S.SEALED, 12, P.GREEN_DIM)
		state.AnchorPoint = Vector2.new(0, 1)
		state.Position = UDim2.new(0, 10, 1, -6)
		state.Size = UDim2.new(1, -20, 0, 14)
		card.Activated:Connect(function()
			self.deps.sfx("Click")
			self:_select(id)
		end)
		self.cards[id] = { root = card, stroke = cardStroke, state = state, pulse = ladder.pulse, row = row }
	end

	-- The detail panel.
	local detail = frame(page, "Detail", P.PLATE)
	detail.AnchorPoint = Vector2.new(1, 0)
	detail.Position = UDim2.new(1, -16, 0, 26 + L.WheelSlot + 16)
	detail.Size = UDim2.new(0, L.DetailW, 1, -(26 + L.WheelSlot + 28))
	stroke(detail, P.GREEN_DIM, 1, 0.4)
	self.detailName = label(detail, "Name", "--", 18, P.GREEN)
	self.detailName.Position = UDim2.fromOffset(12, 10)
	self.detailName.Size = UDim2.new(1, -24, 0, 44)
	self.detailName.TextWrapped = true
	self.detailInfo = label(detail, "Info", "", 13, P.GREEN_SOFT)
	self.detailInfo.Position = UDim2.fromOffset(12, 58)
	self.detailInfo.Size = UDim2.new(1, -24, 0, 40)
	self.detailInfo.TextWrapped = true

	self.playBtn = button(detail, "Btn_PLAY", S.PLAY, 16, P.GREEN, P.BG)
	self.playBtn.Position = UDim2.fromOffset(12, 108)
	self.playBtn.Size = UDim2.new(1, -24, 0, 34)
	stroke(self.playBtn, P.GREEN_DIM, 1, 0.35)
	self.playBtn.Activated:Connect(function()
		if self:_usable(self.selectedId) then
			self.deps.sfx("Confirm")
			self.deps.send.play(self.selectedId)
		else
			self.deps.sfx("Reject")
		end
	end)

	local assignHead = label(detail, "AssignHead", S.ASSIGN, 12, P.GREEN_DIM)
	assignHead.Position = UDim2.fromOffset(12, 152)
	assignHead.Size = UDim2.new(1, -24, 0, 14)
	for i = 1, 8 do
		local b = button(detail, "Assign" .. i, tostring(i), 14, P.GREEN_SOFT, P.BG)
		b.Position = UDim2.fromOffset(12 + (i - 1) * 28, 170)
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

	self.clearBtn = button(detail, "Btn_CLEAR", S.CLEAR, 13, P.GREEN_DIM, P.BG)
	self.clearBtn.Position = UDim2.fromOffset(12, 204)
	self.clearBtn.Size = UDim2.new(1, -24, 0, 26)
	stroke(self.clearBtn, P.GREEN_DIM, 1, 0.5)
	self.clearBtn.Activated:Connect(function()
		-- Clears the slot currently holding the selected emote, if any.
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

-- REQUISITION -----------------------------------------------------------------
function SupplyKit:_buildSupply(content)
	local P, L, S = self.P, self.L, self.S
	local page = frame(content, "Supply", nil)
	page.Size = UDim2.fromScale(1, 1)
	page.Visible = false
	self.supplyPage = page

	local cratePanel = frame(page, "Crate", P.PLATE)
	cratePanel.Position = UDim2.fromOffset(16, 16)
	cratePanel.Size = UDim2.new(0.55, -24, 1, -32)
	stroke(cratePanel, P.GREEN_DIM, 1, 0.35)

	local glyph = label(cratePanel, "Glyph", "[ ▚▚▚ ]", 34, P.GREEN)
	glyph.AnchorPoint = Vector2.new(0.5, 0)
	glyph.Position = UDim2.new(0.5, 0, 0, 34)
	glyph.Size = UDim2.fromOffset(220, 44)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	self.crateGlyph = glyph

	self.crateStatus = label(cratePanel, "Status", S.KEYS_FROM, 13, P.GREEN_DIM)
	self.crateStatus.AnchorPoint = Vector2.new(0.5, 0)
	self.crateStatus.Position = UDim2.new(0.5, 0, 0, 96)
	self.crateStatus.Size = UDim2.new(1, -40, 0, 34)
	self.crateStatus.TextXAlignment = Enum.TextXAlignment.Center
	self.crateStatus.TextWrapped = true

	self.decryptBtn = button(cratePanel, "Btn_DECRYPT", S.DECRYPT, 22, P.GREEN, P.BG)
	self.decryptBtn.AnchorPoint = Vector2.new(0.5, 0)
	self.decryptBtn.Position = UDim2.new(0.5, 0, 0, 150)
	self.decryptBtn.Size = UDim2.fromOffset(220, 48)
	self.decryptBtn.TextXAlignment = Enum.TextXAlignment.Center
	stroke(self.decryptBtn, P.GREEN, 1, 0.3)
	self.decryptBtn.Activated:Connect(function()
		self:_decryptPressed()
	end)

	local oddsBtn = button(cratePanel, "Btn_ODDS", "( i ) " .. S.ODDS, 14, P.GREEN_SOFT, P.BG)
	oddsBtn.AnchorPoint = Vector2.new(0.5, 0)
	oddsBtn.Position = UDim2.new(0.5, 0, 0, 210)
	oddsBtn.Size = UDim2.fromOffset(220, 30)
	oddsBtn.TextXAlignment = Enum.TextXAlignment.Center
	stroke(oddsBtn, P.GREEN_DIM, 1, 0.5)
	oddsBtn.Activated:Connect(function()
		self.deps.sfx("Click")
		self:_showOdds()
	end)

	-- Gamepass tiles: rendered from MonetizationConfig, silent while unarmed.
	local passes = frame(page, "Passes", nil)
	passes.AnchorPoint = Vector2.new(1, 0)
	passes.Position = UDim2.new(1, -16, 0, 16)
	passes.Size = UDim2.new(0.45, -16, 1, -32)
	local passList = Instance.new("UIListLayout")
	passList.Padding = UDim.new(0, 10)
	passList.SortOrder = Enum.SortOrder.LayoutOrder
	passList.Parent = passes

	for order, key in ipairs(self.deps.money.list()) do
		local pass = self.deps.money.PASSES[key]
		local armed = self.deps.money.armed(key)
		local tile = frame(passes, "Pass_" .. key, P.PLATE)
		tile.LayoutOrder = order
		tile.Size = UDim2.new(1, 0, 0, 74)
		stroke(tile, P.GREEN_DIM, 1, armed and 0.35 or 0.6)
		local name = label(tile, "Name", pass.name, 16, armed and P.GREEN or P.GREEN_DIM)
		name.Position = UDim2.fromOffset(12, 8)
		name.Size = UDim2.new(1, -24, 0, 20)
		local grants = #self.deps.money.grantedEmotes(key)
		local line = label(
			tile,
			"Grants",
			grants > 0 and string.format("GRANTS %d EMOTE(S)", grants) or "SUPPORTER STANDING",
			12,
			P.GREEN_DIM
		)
		line.Position = UDim2.fromOffset(12, 30)
		line.Size = UDim2.new(1, -24, 0, 14)
		local action = button(tile, "Btn_BUY", armed and S.ACQUIRE or S.OFFLINE, 13, armed and P.GREEN_SOFT or P.GREEN_DIM, P.BG)
		action.AnchorPoint = Vector2.new(1, 1)
		action.Position = UDim2.new(1, -10, 1, -8)
		action.Size = UDim2.fromOffset(110, 24)
		action.TextXAlignment = Enum.TextXAlignment.Center
		stroke(action, P.GREEN_DIM, 1, armed and 0.4 or 0.65)
		if armed then
			action.Activated:Connect(function()
				self.deps.sfx("Click")
				self.deps.send.shop(pass.sku)
			end)
		end
	end

	-- The private cycle tile appears only once its price has been decided --
	-- the constant is 0 until then and a price of 0 must never render.
	local price = tonumber(self.deps.money.PrivateServerPrice) or 0
	if price > 0 then
		local tile = frame(passes, "Pass_PRIVATE", P.PLATE)
		tile.LayoutOrder = 99
		tile.Size = UDim2.new(1, 0, 0, 50)
		stroke(tile, P.GREEN_DIM, 1, 0.45)
		local name = label(tile, "Name", S.PRIVATE, 15, P.GREEN_SOFT)
		name.Position = UDim2.fromOffset(12, 6)
		name.Size = UDim2.new(1, -24, 0, 20)
		local line = label(tile, "Price", string.format("R$ %d - VIA SERVER MENU", price), 12, P.GREEN_DIM)
		line.Position = UDim2.fromOffset(12, 26)
		line.Size = UDim2.new(1, -24, 0, 14)
	end
end

-- ODDS MODAL ------------------------------------------------------------------
function SupplyKit:_buildOdds(content)
	local P, S = self.P, self.S
	local modal = frame(content, "Odds", P.BG)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromOffset(330, 300)
	modal.Visible = false
	modal.ZIndex = 30
	stroke(modal, P.GREEN, 1, 0.3)
	self.oddsModal = modal

	local title = label(modal, "Title", S.ODDS_TITLE, 18, P.GREEN)
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 22)
	self.oddsRows = label(modal, "Rows", "", 15, P.GREEN_SOFT)
	self.oddsRows.Position = UDim2.fromOffset(16, 46)
	self.oddsRows.Size = UDim2.new(1, -32, 1, -120)
	self.oddsRows.TextYAlignment = Enum.TextYAlignment.Top
	local note = label(modal, "Note", S.ODDS_NOTE, 11, P.GREEN_DIM)
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 16, 1, -46)
	note.Size = UDim2.new(1, -32, 0, 30)
	note.TextWrapped = true
	local closeBtn = button(modal, "Btn_CLOSE", S.CLOSE, 14, P.GREEN_SOFT, P.PLATE)
	closeBtn.AnchorPoint = Vector2.new(0.5, 1)
	closeBtn.Position = UDim2.new(0.5, 0, 1, -10)
	closeBtn.Size = UDim2.fromOffset(120, 28)
	closeBtn.TextXAlignment = Enum.TextXAlignment.Center
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
			lines[#lines + 1] = string.format("%-12s %5.1f%%", string.upper(band.rarity), band.percent)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = string.format("%d ITEM(S) IN STOCK", #pool)
		self.oddsRows.Text = table.concat(lines, "\n")
	end
	self.oddsModal.Visible = true
end

-- STATE -----------------------------------------------------------------------
-- Client mirror of the server's ownership decision: a "default" row is free
-- for everyone and never appears in `owned` unless it was once put on the
-- wheel (EmoteService materialises it then) -- so the client gates must ask
-- the source too, or the free dance would read SEALED on a fresh profile.
function SupplyKit:_usable(id)
	if not id then return false end
	if self.owned[id] == true then return true end
	local row = self.deps.registry.get(id)
	return row ~= nil and row.source == "default"
end

function SupplyKit:setTab(i)
	self.tab = i
	self.wardrobePage.Visible = i == 1
	self.supplyPage.Visible = i == 2
	for k, b in ipairs(self.tabButtons) do
		b.TextColor3 = hex(k == i and self.P.GREEN or self.P.GREEN_DIM)
	end
	local target = self.tabButtons[i]
	self.streak.Position = UDim2.fromOffset(0, target.Position.Y.Offset)
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
	self.detailInfo.Text = string.upper(row.rarity or "") .. "\n" .. ownedLine
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
	local keysText = string.format("%s %d", self.S.WALLET_KEYS, math.floor(self.shownKeys + 0.5))
	local fragText = string.format("%s %d/%d", self.S.WALLET_FRAGMENTS, math.floor(self.shownFragments + 0.5), per)
	if self.keysLabel.Text ~= keysText then self.keysLabel.Text = keysText end
	if self.fragmentsLabel.Text ~= fragText then self.fragmentsLabel.Text = fragText end
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

-- PACKETS ---------------------------------------------------------------------
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
	end
end

-- THE CEREMONY (client half) ---------------------------------------------------
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
	if not self.revealBusy then
		-- A result we did not ask for this session (e.g. fired before a
		-- rejoin) still lands as state; skip the ceremony, keep the facts.
		return
	end
	self:_runReveal(packet)
end

function SupplyKit:_runReveal(packet)
	local P, L, S = self.P, self.L, self.S
	local reveal = frame(self.content, "Reveal", P.BG)
	reveal.Size = UDim2.fromScale(1, 1)
	reveal.ZIndex = 40
	reveal.Active = true
	stroke(reveal, P.GREEN_DIM, 1, 0.5)
	self.reveal = reveal

	local ladder = self.deps.rarity[packet.rarity] or self.deps.rarity.standard
	local spin = self.deps.reveal.SPIN + (self.deps.reveal.SPIN_BONUS[packet.rarity] or 0)

	-- The strip: tiles from the server's reel, a clipping window, one ticker.
	local window = frame(reveal, "Window", P.PLATE)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.42)
	window.Size = UDim2.new(1, -60, 0, L.ReelTileH + 24)
	window.ClipsDescendants = true
	stroke(window, P.GREEN_DIM, 1, 0.35)

	local strip = frame(window, "Strip", nil)
	strip.Size = UDim2.fromOffset(#packet.reel * (L.ReelTileW + L.ReelGap), L.ReelTileH)
	strip.Position = UDim2.new(0, 0, 0.5, -L.ReelTileH / 2)
	for i, id in ipairs(packet.reel) do
		local row = self.deps.registry.get(id)
		local tile = frame(strip, "Tile" .. i, P.BG)
		tile.Position = UDim2.fromOffset((i - 1) * (L.ReelTileW + L.ReelGap), 0)
		tile.Size = UDim2.fromOffset(L.ReelTileW, L.ReelTileH)
		local tileLadder = row and self.deps.rarity[row.rarity] or self.deps.rarity.standard
		stroke(tile, tileLadder.stroke, 1, 0.3)
		local name = label(tile, "Name", row and row.name or "?", 14, P.GREEN_SOFT)
		name.Position = UDim2.fromOffset(8, 8)
		name.Size = UDim2.new(1, -16, 1, -16)
		name.TextWrapped = true
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextYAlignment = Enum.TextYAlignment.Center
	end

	local ticker = frame(window, "Ticker", ladder.stroke)
	ticker.AnchorPoint = Vector2.new(0.5, 0)
	ticker.Position = UDim2.fromScale(0.5, 0)
	ticker.Size = UDim2.new(0, 2, 1, 0)
	ticker.ZIndex = 5

	local resultCard = label(reveal, "Result", "", 26, P.GREEN)
	resultCard.AnchorPoint = Vector2.new(0.5, 0)
	resultCard.Position = UDim2.fromScale(0.5, 0.62)
	resultCard.Size = UDim2.new(1, -80, 0, 40)
	resultCard.TextXAlignment = Enum.TextXAlignment.Center
	local rarityLine = label(reveal, "Rarity", "", 15, ladder.stroke)
	rarityLine.AnchorPoint = Vector2.new(0.5, 0)
	rarityLine.Position = UDim2.fromScale(0.5, 0.71)
	rarityLine.Size = UDim2.new(1, -80, 0, 20)
	rarityLine.TextXAlignment = Enum.TextXAlignment.Center

	-- The tween target: result tile centred under the ticker.
	local windowMid = (self.L.PanelW - self.L.RailW - 60) / 2
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
	}

	if not self.deps.motionOk() then
		-- Reduced motion: no shake, no spin -- jump to the result and type.
		strip.Position = UDim2.new(0, targetX, 0.5, -L.ReelTileH / 2)
		self.revealState.phase = "typed"
		self.revealState.t0 = os.clock()
		self.deps.sfx("Confirm")
	end
end

-- One stepped tick for everything that moves; called by the host's loop.
function SupplyKit:step(now)
	-- Wallet count-up juice: chase the real value, write only on change.
	local chase = function(shown, target)
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

	-- Rarity pulse on the few cards that carry one.
	self.pulsePhase = (self.pulsePhase + 0.08) % (math.pi * 2)
	local pulseT = 0.1 + 0.35 * (0.5 + 0.5 * math.sin(self.pulsePhase))
	for _, card in pairs(self.cards) do
		if card.pulse and card.stroke.Transparency < 0.5 then
			card.stroke.Transparency = pulseT
		end
	end

	-- Reveal timeout: a silently denied open (server gate) un-sticks the button.
	if self.revealBusy and not self.revealState and now - self.revealWait > 8 then
		self.revealBusy = false
		self.crateStatus.Text = self.S.KEYS_FROM
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
			local tween = TweenService:Create(
				reveal.strip,
				TweenInfo.new(reveal.spin, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0, reveal.targetX, 0.5, -self.L.ReelTileH / 2) }
			)
			tween:Play()
		end
	elseif reveal.phase == "spin" then
		-- Tick when a new tile crosses the ticker; the tween owns the motion.
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
			reveal.rarityLine.Text = string.upper(reveal.packet.rarity or "")
			self:_buildRevealButtons(reveal)
		end
	end
end

function SupplyKit:_buildRevealButtons(reveal)
	local P, S = self.P, self.S
	local claim = button(reveal.frame, "Btn_CLAIM", S.CLAIM, 18, P.GREEN, P.PLATE)
	claim.AnchorPoint = Vector2.new(0.5, 1)
	claim.Position = UDim2.new(0.5, -90, 1, -18)
	claim.Size = UDim2.fromOffset(160, 40)
	claim.TextXAlignment = Enum.TextXAlignment.Center
	stroke(claim, P.GREEN_DIM, 1, 0.35)
	claim.Activated:Connect(function()
		self.deps.sfx("Click")
		self:_endReveal()
	end)
	local again = button(reveal.frame, "Btn_AGAIN", S.AGAIN, 15, P.GREEN_SOFT, P.PLATE)
	again.AnchorPoint = Vector2.new(0.5, 1)
	again.Position = UDim2.new(0.5, 100, 1, -18)
	again.Size = UDim2.fromOffset(180, 40)
	again.TextXAlignment = Enum.TextXAlignment.Center
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

-- OPEN / CLOSE ----------------------------------------------------------------
function SupplyKit:open()
	if self.gui.Enabled then return end
	self:_rescale()
	self.gui.Enabled = true
	self.deps.send.sync()
	self.deps.sfx("ClickAlt")
end

function SupplyKit:close()
	if not self.gui.Enabled then return end
	self:_endReveal()
	self.oddsModal.Visible = false
	self.gui.Enabled = false
end

function SupplyKit:isOpen()
	return self.gui.Enabled
end

function SupplyKit:_rescale()
	local cam = workspace.CurrentCamera
	local view = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = math.clamp(math.min(view.Y / 710, (view.X - 20) / self.L.PanelW), 0.55, 1.2)
	if self.scale.Scale ~= s then self.scale.Scale = s end
end

function SupplyKit:destroy()
	self:_endReveal()
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return SupplyKit
