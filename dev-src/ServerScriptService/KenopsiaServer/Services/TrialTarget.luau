--!nonstrict
local Trial = {}
Trial.Id = "target_calibration"
Trial.DisplayName = "TARGET CALIBRATION"
Trial.Verb = "ALIGN"
Trial.Caption = "NEUTRALIZE EACH CALIBRATION MARK BEFORE IT FADES."
Trial.Duration = 20

local TARGETS = 13
local STEP = 1.4
local WINDOW = 1.2

function Trial.Setup(ctx)
	local rng = Random.new(ctx.seed)
	local targets = {}
	for i = 1, TARGETS do
		targets[i] = {
			x = 0.08 + 0.84 * rng:NextNumber(),
			y = 0.10 + 0.76 * rng:NextNumber(),
		}
	end
	return { ctx = ctx, targets = targets, hits = {}, current = 0, spawnAt = 0 }
end

function Trial.Start(state)
	task.spawn(function()
		task.wait(0.4)
		for i = 1, TARGETS do
			if state.done then return end
			local t = state.targets[i]
			state.current = i
			state.spawnAt = os.clock()
			state.ctx.send({ kind = "target", i = i, total = TARGETS, x = t.x, y = t.y, window = WINDOW })
			task.wait(STEP)
		end
		state.current = 0
	end)
end

function Trial.HandleInput(state, userId, payload)
	if payload.kind ~= "hit" or state.done then return end
	local i = tonumber(payload.i)
	if not i or i ~= state.current then return end
	local dt = os.clock() - state.spawnAt
	if dt > WINDOW + 0.25 then return end
	state.hits[userId] = state.hits[userId] or {}
	if state.hits[userId][i] then return end
	state.hits[userId][i] = math.clamp(dt, 0, WINDOW)
end

function Trial.Stop(state)
	state.done = true
	local scores = {}
	for _, m in state.ctx.room.members do
		local hits = state.hits[m.userId] or {}
		local s = 0
		for _, dt in hits do
			s += 50 + math.floor((1 - dt / WINDOW) * 50)
		end
		scores[m.userId] = s
	end
	return scores
end

function Trial.Cleanup(state)
	state.done = true
end

return Trial
