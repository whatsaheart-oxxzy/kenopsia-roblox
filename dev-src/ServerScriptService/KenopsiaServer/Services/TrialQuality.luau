--!nonstrict
local Trial = {}
Trial.Id = "quality_control"
Trial.DisplayName = "QUALITY CONTROL"
Trial.Verb = "INSPECT"
Trial.Caption = "COMPARE EACH UNIT AGAINST SPECIFICATION. APPROVE OR REJECT."
Trial.Duration = 20

local GLYPHS = { "#", "%", "&", "@", "+", "=", "\u{00A7}", "\u{00D8}", "\u{0394}", "\u{03A6}", "\u{03A8}", "\u{03A9}" }
local UNITS = 12
local STEP = 1.55

function Trial.Setup(ctx)
	local rng = Random.new(ctx.seed)
	local units = {}
	for i = 1, UNITS do
		local glyph = GLYPHS[rng:NextInteger(1, #GLYPHS)]
		local code = string.format("%03d", rng:NextInteger(0, 999))
		local defect = rng:NextNumber() < 0.45
		local shownGlyph, shownCode = glyph, code
		if defect then
			if rng:NextNumber() < 0.5 then
				local other
				repeat
					other = GLYPHS[rng:NextInteger(1, #GLYPHS)]
				until other ~= glyph
				shownGlyph = other
			else
				local pos = rng:NextInteger(1, 3)
				local old = tonumber(string.sub(code, pos, pos))
				local new
				repeat
					new = rng:NextInteger(0, 9)
				until new ~= old
				shownCode = string.sub(code, 1, pos - 1) .. new .. string.sub(code, pos + 1)
			end
		end
		units[i] = { glyph = glyph, code = code, defect = defect, shownGlyph = shownGlyph, shownCode = shownCode }
	end
	return { ctx = ctx, units = units, verdicts = {}, current = 0 }
end

function Trial.Start(state)
	task.spawn(function()
		task.wait(0.4)
		for i = 1, UNITS do
			if state.done then return end
			local u = state.units[i]
			state.current = i
			state.ctx.send({
				kind = "qc_unit", i = i, total = UNITS,
				spec = { glyph = u.glyph, code = u.code },
				unit = { glyph = u.shownGlyph, code = u.shownCode },
			})
			task.wait(STEP)
		end
		state.current = 0
	end)
end

function Trial.HandleInput(state, userId, payload)
	if payload.kind ~= "verdict" or state.done then return end
	local i = tonumber(payload.i)
	if not i or i ~= state.current then return end
	state.verdicts[userId] = state.verdicts[userId] or {}
	if state.verdicts[userId][i] ~= nil then return end
	state.verdicts[userId][i] = payload.approve == true
end

function Trial.Stop(state)
	state.done = true
	local scores = {}
	for _, m in state.ctx.room.members do
		local v = state.verdicts[m.userId] or {}
		local s = 0
		for i, u in state.units do
			local verdict = v[i]
			if verdict ~= nil then
				if verdict == not u.defect then
					s += 100
				else
					s -= 50
				end
			end
		end
		scores[m.userId] = math.max(0, s)
	end
	return scores
end

function Trial.Cleanup(state)
	state.done = true
end

return Trial
