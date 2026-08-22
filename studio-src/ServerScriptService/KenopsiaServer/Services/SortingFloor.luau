--!nonstrict
-- SORTING FLOOR (P4.1, 23.08.2026). A belt, a rule board that changes without
-- warning, two chutes per station. Sort right = point. Sort wrong = strike,
-- three strikes = the station floor opens. All players are sorters, anchored.
--
-- Server owns: the seeded item stream (sent once at GO, attrs are what you
-- sort by), the rule schedule (telegraph 0.5 s before every change, never
-- earlier), per-station windows on the server clock, strikes, the drop.
-- Client renders: belt items, board, lamps, HUD (TrialClients/sorting.luau).
--
-- Contract: docs/MP-06-FRAMEWORK.md. REQ-IP-01: original id "sorting" /
-- display "SORTING FLOOR"; the reference name appears nowhere in source.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrialKit = require(script.Parent.TrialKit)
local Rules = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("SortingFloorRules"))
local Pacing = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("Pacing"))

local Trial = {}
local TRIAL_ID = "sorting"
local TAGLINE = "MISFILE AND YOU FOLLOW IT."
local P = TrialKit.PALETTE

local STATIONS = 4
local STATION_X = { -15, -5, 5, 15 } -- along the belt (origin-relative)
local STATION_Z = -4                 -- the sorters' side of the belt
local BELT_TOP = 3
local BELT_START, BELT_END = -28, 28 -- items travel +X; the maw is at BELT_END

-- ARENA ------------------------------------------------------------------------
-- ~60 static parts: floor, belt + frame, four stations (pad = trapdoor, pit
-- below, two chutes, lamp head), rule board + frame, incinerator maw.
local function buildArena(folder, origin)
	TrialKit.slab(folder, origin, 60, 60, P.WetConcrete)
	TrialKit.box("Belt", Vector3.new(BELT_END - BELT_START, 1, 4),
		CFrame.new(origin + Vector3.new((BELT_START + BELT_END) / 2, BELT_TOP - 0.5, 0)), P.Steel, folder)
	for _, dz in { -2.3, 2.3 } do
		TrialKit.box("BeltFrame", Vector3.new(BELT_END - BELT_START + 2, 1.4, 0.6),
			CFrame.new(origin + Vector3.new((BELT_START + BELT_END) / 2, BELT_TOP - 0.3, dz)), P.Rust, folder)
	end
	-- legs under the belt
	for x = BELT_START + 4, BELT_END - 4, 8 do
		TrialKit.box("BeltLeg", Vector3.new(0.6, BELT_TOP - 1, 0.6), CFrame.new(origin + Vector3.new(x, (BELT_TOP - 1) / 2, 0)), P.Rust, folder)
	end
	local spawns, traps, lamps = {}, {}, {}
	for i = 1, STATIONS do
		local x = STATION_X[i]
		-- the pad IS the trapdoor; the pit yawns below it
		traps[i] = TrialKit.box("Trap" .. i, Vector3.new(5, 1, 5), CFrame.new(origin + Vector3.new(x, 0.55, STATION_Z)), P.Concrete, folder)
		TrialKit.part({ name = "Pit" .. i, size = Vector3.new(5.6, 10, 5.6), cf = CFrame.new(origin + Vector3.new(x, -5.5, STATION_Z)),
			color = P.Void, parent = folder, canCollide = false })
		TrialKit.part({ name = "PitRim" .. i, size = Vector3.new(6.2, 0.4, 6.2), cf = CFrame.new(origin + Vector3.new(x, 0.2, STATION_Z)),
			color = P.Signal, parent = folder, neon = true })
		-- chutes: A on the sorter's LEFT (they face +Z, so left is +X), B on the right
		TrialKit.box("ChuteA" .. i, Vector3.new(1.6, 1.2, 1.6), CFrame.new(origin + Vector3.new(x + 2.6, BELT_TOP + 0.1, -1.0)), P.Steel, folder)
		TrialKit.box("ChuteB" .. i, Vector3.new(1.6, 1.2, 1.6), CFrame.new(origin + Vector3.new(x - 2.6, BELT_TOP + 0.1, -1.0)), P.Steel, folder)
		TrialKit.part({ name = "LetterA" .. i, size = Vector3.new(0.6, 0.6, 0.2), cf = CFrame.new(origin + Vector3.new(x + 2.6, BELT_TOP + 0.9, -1.85)), color = P.Bone, parent = folder, canCollide = false })
		TrialKit.part({ name = "LetterB" .. i, size = Vector3.new(0.6, 0.6, 0.2), cf = CFrame.new(origin + Vector3.new(x - 2.6, BELT_TOP + 0.9, -1.85)), color = P.Bone, parent = folder, canCollide = false })
		-- lamp head over the station
		TrialKit.box("LampPost" .. i, Vector3.new(0.4, 7, 0.4), CFrame.new(origin + Vector3.new(x - 3.2, 3.5, STATION_Z - 3)), P.Rust, folder)
		lamps[i] = TrialKit.part({ name = "Lamp" .. i, size = Vector3.new(1.2, 1.2, 1.2), cf = CFrame.new(origin + Vector3.new(x - 3.2, 7.3, STATION_Z - 3)),
			color = P.Sodium, parent = folder, neon = true, canCollide = false })
		-- sorter stands on the pad, facing the belt (+Z)
		spawns[i] = CFrame.new(origin + Vector3.new(x, 4.1, STATION_Z)) * CFrame.Angles(0, math.pi, 0)
	end
	-- rule board on the far side of the belt, readable from the stations
	TrialKit.box("BoardFrame", Vector3.new(26, 5, 0.4), CFrame.new(origin + Vector3.new(0, 8.5, 6.2)), P.Rust, folder)
	TrialKit.part({ name = "BoardGlow", size = Vector3.new(26.6, 5.6, 0.2), cf = CFrame.new(origin + Vector3.new(0, 8.5, 6.5)),
		color = P.Hazard, parent = folder, neon = true, canCollide = false, transparency = 0.6 })
	TrialKit.box("Board", Vector3.new(24.8, 3.8, 0.3), CFrame.new(origin + Vector3.new(0, 8.5, 5.95)), P.Bone, folder)
	for _, dx in { -12.5, 12.5 } do
		TrialKit.box("BoardPost", Vector3.new(0.5, 10, 0.5), CFrame.new(origin + Vector3.new(dx, 5, 6.3)), P.Rust, folder)
	end
	-- the incinerator maw at the belt end
	TrialKit.box("Maw", Vector3.new(6, 7, 7), CFrame.new(origin + Vector3.new(BELT_END + 3, 3.5, 0)), P.Void, folder)
	TrialKit.part({ name = "MawGlow", size = Vector3.new(0.3, 5, 5), cf = CFrame.new(origin + Vector3.new(BELT_END - 0.1, BELT_TOP + 2.5, 0)),
		color = P.Signal, parent = folder, neon = true, canCollide = false, transparency = 0.3 })
	-- back wall and side walls, low: the hall
	TrialKit.wallBox(folder, origin, 60, 60, 10, 1, P.Concrete)
	local cam = TrialKit.marker("Cam", CFrame.lookAt(origin + Vector3.new(0, 19, -25), origin + Vector3.new(0, 4, 0)), folder)
	return { spawn = spawns, cam = cam, traps = traps, lamps = lamps }
end

-- INPUT ------------------------------------------------------------------------
-- `sort {itemId, chute}` / `pass {itemId}`: accepted only for an undecided item
-- of the sender's own station inside its window on the SERVER clock. The rule
-- in force is whatever the schedule says at that instant.
local function decide(player, ps, payload, R, action)
	local d = payload.data
	if type(d) ~= "table" then return end
	local itemId = d.itemId
	if type(itemId) ~= "string" or #itemId > 8 then return end
	local st = R.sorting
	if not (st and R.t0) then return end
	local s, n = string.match(itemId, "^(%d+)%-(%d+)$")
	s, n = tonumber(s), tonumber(n)
	if not (s and n) or s ~= ps.station then return end
	local item = st.stream[s] and st.stream[s][n]
	if not item then return end
	if ps.decided[itemId] then return end
	local t = os.clock() - R.t0
	if not Rules.contains(item, t) then return end
	ps.decided[itemId] = true
	local uid = player.UserId
	if action == "pass" then
		TrialKit.sendOne(uid, TRIAL_ID, "so_result", { itemId = itemId, pass = true })
		TrialKit.send(R.room, TRIAL_ID, "so_lamp", { station = s, state = "pass" })
		return
	end
	local chute = d.chute
	if chute ~= "A" and chute ~= "B" then return end
	local want = Rules.apply(Rules.ruleAt(st.schedule, t), item)
	local ok = chute == want
	if ok then
		ps.correct += 1
	else
		ps.strikes = Rules.strike(ps.strikes, false)
	end
	TrialKit.sendOne(uid, TRIAL_ID, "so_result", { itemId = itemId, ok = ok, want = want, correct = ps.correct, strikes = ps.strikes })
	TrialKit.send(R.room, TRIAL_ID, "so_lamp", { station = s, state = ok and "ok" or "bad", strikes = ps.strikes })
	if not ok and Rules.dropped(ps.strikes) and not ps.dropAt then
		-- the telegraph: lamp goes Signal, the floor opens DROP_TELEGRAPH later
		ps.dropAt = os.clock() + Rules.DROP_TELEGRAPH
		TrialKit.send(R.room, TRIAL_ID, "so_strike", { station = s, userId = uid, n = ps.strikes, drop = true })
	end
end

function Trial.init()
	TrialKit.wireInput(TRIAL_ID, {
		actions = { sort = true, pass = true },
		cooldown = 0.15,
		handler = function(player, ps, payload, R)
			decide(player, ps, payload, R, payload.action)
		end,
	})
end

-- ROUND ------------------------------------------------------------------------
local function runRoundInner(room, roundIndex, guard)
	local scores = TrialKit.zeroScores(room)
	local refs = TrialKit.ensureArena(TRIAL_ID, buildArena)
	if not refs then
		warn("[SORTING] arena unavailable")
		return scores
	end
	local R = TrialKit.newRound(TRIAL_ID, room, roundIndex, guard)
	local nextInt = TrialKit.rng(room, roundIndex)
	local roundsTotal = Pacing.roundsFor(TRIAL_ID, #room.members) or 3
	local seconds = Pacing.RoundSeconds[TRIAL_ID] or 40
	local schedule = Rules.schedule(nextInt, roundIndex, roundsTotal, seconds)
	local stream = Rules.generate(nextInt, seconds, roundIndex, STATIONS)
	R.sorting = { schedule = schedule, stream = stream }

	-- seats: station i for the i-th member, anchored, no movement at all
	local byStation = {}
	local spots = { anchored = true, walkSpeed = 0 }
	for i = 1, STATIONS do spots[i] = refs.spawn[i] end
	R:place(spots)
	local i = 0
	for _, mm in room.members do
		local ps = R.state[mm.userId]
		i += 1
		ps.station = math.min(i, STATIONS)
		ps.correct, ps.strikes, ps.decided = 0, 0, {}
		byStation[ps.station] = mm.userId
	end
	-- restore trapdoors whatever happens
	R:onCleanup(function()
		for _, trap in refs.traps do
			if trap and trap.Parent then
				trap.Transparency = 0
				trap.CanCollide = true
			end
		end
	end)

	local firstRule = Rules.rule(schedule[1].ruleId)
	R:begin({
		ruleId = firstRule.id, rule = firstRule.text,
		window = Rules.window(roundIndex), stations = STATIONS, seconds = seconds,
	})
	for _, mm in room.members do
		local ps = R.state[mm.userId]
		if ps and ps.station then
			TrialKit.sendOne(mm.userId, TRIAL_ID, "station", { station = ps.station })
		end
	end
	R:cover(TAGLINE)
	if not R:wait(2.8) then return scores end
	if not R:countdown() then return scores end

	-- GO: the whole stream at once, server-timed (attrs are visible on purpose)
	local goServer = workspace:GetServerTimeNow()
	local wire = {}
	for s = 1, STATIONS do
		local list = {}
		for n, it in ipairs(stream[s]) do
			list[n] = { id = it.id, kind = it.kind, colour = it.colour, sealed = it.sealed,
				arriveAt = goServer + it.arriveAt, leaveAt = goServer + it.leaveAt }
		end
		wire[s] = list
	end
	TrialKit.send(room, TRIAL_ID, "so_stream", { goAt = goServer, stations = wire, mawAt = BELT_END, startAt = BELT_START })
	R:setDeadline(seconds)

	local nextChange = 2          -- schedule[1] is on the board already
	local warned = false
	R:tick(function()
		local t = os.clock() - R.t0
		-- rule changes, telegraphed exactly TELEGRAPH before
		local e = schedule[nextChange]
		if e then
			if not warned and t >= e.at - Rules.TELEGRAPH then
				warned = true
				TrialKit.send(room, TRIAL_ID, "so_warn", { at = goServer + e.at })
			end
			if t >= e.at then
				local r = Rules.rule(e.ruleId)
				TrialKit.send(room, TRIAL_ID, "so_rule", { ruleId = r.id, rule = r.text, at = goServer + e.at })
				nextChange += 1
				warned = false
			end
		end
		-- drops
		local running = 0
		for uid, ps in R.state do
			if not ps.done then
				running += 1
				if ps.dropAt and os.clock() >= ps.dropAt then
					local trap = refs.traps[ps.station]
					if trap then
						trap.Transparency = 0.7
						trap.CanCollide = false
					end
					R:setMovement(uid, nil, false) -- unanchor: the sorter follows the item down
					R:kill(uid, { text = "MISFILED.", power = 1.3 })
				end
			end
		end
		if running == 0 then return "stop" end
	end)
	if not R:active() then return scores end

	scores = R:scores(function(_, ps)
		if not ps.done then
			return TrialKit.key(TrialKit.BAND.ALIVE, Rules.detail(true, ps.correct, ps.strikes))
		end
		return TrialKit.key(TrialKit.BAND.OUT, Rules.detail(false, ps.correct, ps.strikes))
	end)
	R:endRound()
	return scores
end

function Trial.runRound(room, roundIndex)
	return TrialKit.runRound(TRIAL_ID, room, roundIndex, runRoundInner)
end

Trial.Rules = Rules

return Trial
