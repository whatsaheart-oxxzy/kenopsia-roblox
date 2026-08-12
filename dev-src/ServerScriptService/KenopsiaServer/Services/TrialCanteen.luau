--!nonstrict
local Trial = {}
Trial.Id = "canteen_protocol"
Trial.DisplayName = "CANTEEN PROTOCOL"
Trial.Verb = "MEMORIZE"
Trial.Caption = "COMMIT THE TABLE TO MEMORY. RESTORE WHAT THE MACHINE REMOVES."
Trial.Duration = 24

local GLYPHS = { "#", "%", "&", "@", "+", "=", "\u{00A7}", "\u{00D8}", "\u{0394}", "\u{03A6}", "\u{03A8}", "\u{03A9}", "\u{00B6}", "\u{00A4}" }
local CELLS = 12
local BLANKS = 4
local MEMORIZE = 6

function Trial.Setup(ctx)
	local rng = Random.new(ctx.seed)
	local pool = table.clone(GLYPHS)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local board = {}
	for i = 1, CELLS do board[i] = pool[i] end

	local idx = {}
	for i = 1, CELLS do idx[i] = i end
	for i = CELLS, 2, -1 do
		local j = rng:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	local blanks = {}
	local answer = {}
	for i = 1, BLANKS do
		blanks[i] = idx[i]
		answer[idx[i]] = board[idx[i]]
	end

	local tray = {}
	for i = 1, BLANKS do table.insert(tray, board[blanks[i]]) end
	table.insert(tray, pool[CELLS + 1])
	table.insert(tray, pool[CELLS + 2])
	for i = #tray, 2, -1 do
		local j = rng:NextInteger(1, i)
		tray[i], tray[j] = tray[j], tray[i]
	end

	local state = {
		ctx = ctx,
		board = board,
		blanks = blanks,
		answer = answer,
		tray = tray,
		masked = false,
		assigned = {},
	}
	ctx.send({ kind = "canteen_board", board = board, memorize = MEMORIZE })
	return state
end

function Trial.Start(state)
	task.delay(MEMORIZE, function()
		if state.done then return end
		state.masked = true
		state.ctx.send({ kind = "canteen_mask", blanks = state.blanks, tray = state.tray })
	end)
end

local function isBlank(state, cell)
	for _, b in state.blanks do
		if b == cell then return true end
	end
	return false
end

local function inTray(state, glyph)
	for _, g in state.tray do
		if g == glyph then return true end
	end
	return false
end

function Trial.HandleInput(state, userId, payload)
	if payload.kind ~= "assign" or not state.masked or state.done then return end
	local cell = tonumber(payload.cell)
	local glyph = payload.glyph
	if not cell or type(glyph) ~= "string" then return end
	if not isBlank(state, cell) or not inTray(state, glyph) then return end
	state.assigned[userId] = state.assigned[userId] or {}
	state.assigned[userId][cell] = glyph
end

function Trial.Stop(state)
	state.done = true
	local scores = {}
	for _, m in state.ctx.room.members do
		local a = state.assigned[m.userId] or {}
		local s = 0
		for cell, glyph in a do
			if state.answer[cell] == glyph then s += 100 end
		end
		scores[m.userId] = s
	end
	return scores
end

function Trial.Cleanup(state)
	state.done = true
end

return Trial
