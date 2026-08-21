--!nonstrict
-- FLOOR CHECK -- FRAMEWORK STUB (MP-05 D13). The implementer overwrites this
-- whole file; the Framework stage ships it only so MachineFlow's require and
-- every Rojo path resolve at boot and a `ready = true` DEV flip already plays a
-- compliant no-op round.
--
-- Contract satisfied here (docs/MP-06-FRAMEWORK.md):
--   init()                idempotent; arena build in pcall; wires no input
--   runRound(room, i)     via TrialKit.runRound; guard armed before the first
--                         yield; cancellation = normal return; zero scores
--
-- REQ-IP-01: original id "floorcheck" / display "FLOOR CHECK"; the reference name
-- appears nowhere in shipped source, comments included.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrialKit = require(script.Parent.TrialKit)
local Rules = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("FloorCheckRules"))

local Trial = {}
local TRIAL_ID = "floorcheck"
local TAGLINE = "STAND WHERE YOU ARE TOLD."
local P = TrialKit.PALETTE

-- Static arena: one slab, four spawn markers, one camera post. buildFn never
-- yields; refs.spawn and refs.cam are the two fields the kit relies on.
local function buildArena(folder, origin)
	TrialKit.slab(folder, origin, 40, 40, P.Concrete)
	local spawns = {}
	for i = 1, 4 do
		spawns[i] = TrialKit.marker(("Spawn%d"):format(i),
			CFrame.new(origin + Vector3.new(-9 + (i - 1) * 6, 3, 12)) * CFrame.Angles(0, math.pi, 0), folder)
	end
	local cam = TrialKit.marker("Cam", CFrame.new(origin + Vector3.new(0, 28, 26)), folder)
	return { spawn = spawns, cam = cam }
end

function Trial.init()
	-- No input yet: a stub accepts nothing. The implementer adds
	-- TrialKit.wireInput(TRIAL_ID, { actions = ..., handler = ... }) here.
	pcall(TrialKit.ensureArena, TRIAL_ID, buildArena)
end

local function runRoundInner(room, roundIndex, guard)
	local scores = TrialKit.zeroScores(room)
	local refs = TrialKit.ensureArena(TRIAL_ID, buildArena)
	if not refs then
		warn("[" .. string.upper(TRIAL_ID) .. "] arena unavailable")
		return scores
	end
	local R = TrialKit.newRound(TRIAL_ID, room, roundIndex, guard)
	R:place(function(i)
		return refs.spawn[math.min(i, #refs.spawn)].CFrame
	end)
	R:begin()
	R:cover(TAGLINE)
	if not R:wait(2.8) then return scores end
	if not R:countdown() then return scores end
	-- A playable no-op: one short beat, then everyone leaves with zero.
	if not R:wait(1) then return scores end
	scores = R:scores(function() return TrialKit.key(TrialKit.BAND.ALIVE, 0) end)
	R:endRound()
	return scores
end

function Trial.runRound(room, roundIndex)
	return TrialKit.runRound(TRIAL_ID, room, roundIndex, runRoundInner)
end

-- Keeps the rules module referenced so a stubbed require is exercised at boot.
Trial.Rules = Rules

return Trial
