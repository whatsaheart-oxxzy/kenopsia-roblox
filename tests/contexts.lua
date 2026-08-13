-- Gate 1 offline proof, part 3: cleanup scopes and the context chain.
--
--     lua tests/contexts.lua
--
-- Contexts.luau is a SERVER module and touches one Roblox API -- HttpService,
-- for the session id. That single call is stubbed here. Everything actually
-- under test (cleanup ordering, idempotency, the isActive chain, token
-- freshness) is plain logic and runs unmodified.
--
-- Stubbing one service is worth it: "a delayed callback ran after its round
-- ended" and "cleanup ran twice" are the two failure shapes this module exists
-- to prevent, and neither is observable from a playtest until it corrupts a
-- score.

local function loadModule(path)
	local chunk = assert(loadfile(path))
	local env = setmetatable({}, { __index = _G })
	local guidCounter = 0
	env.game = {
		GetService = function(_, name)
			assert(name == "HttpService", "unexpected service: " .. tostring(name))
			return {
				GenerateGUID = function()
					guidCounter = guidCounter + 1
					return string.format("GUID%03d", guidCounter)
				end,
			}
		end,
	}
	env.warn = function() end -- cleanup failures warn by design; keep output clean
	setfenv(chunk, env)
	return chunk()
end

local Contexts = loadModule("studio-src/ServerScriptService/KenopsiaServer/Services/Contexts.luau")

local failures, checks = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
	end
end

-- CLEANUP SCOPE ---------------------------------------------------------------

print("\nCLEANUP SCOPE")

local order = {}
local scope = Contexts.newCleanupScope()
scope:add(function() table.insert(order, "first") end)
scope:add(function() table.insert(order, "second") end)
scope:add(function() table.insert(order, "third") end)
scope:run()
check(table.concat(order, ",") == "third,second,first",
	"teardown runs LIFO", table.concat(order, ","))

local runs = 0
local idem = Contexts.newCleanupScope()
idem:add(function() runs = runs + 1 end)
idem:run()
idem:run()
idem:run()
check(runs == 1, "run() is idempotent -- double cleanup cannot happen", "ran " .. runs)
check(idem:isDone(), "isDone reports true after run")

-- A failing step must not strand the ones after it.
local reached = {}
local failing = Contexts.newCleanupScope()
failing:add(function() table.insert(reached, "bottom") end)
failing:add(function() error("boom") end)
failing:add(function() table.insert(reached, "top") end)
local okRun = pcall(function() failing:run() end)
check(okRun, "a failing teardown step does not propagate out of run()")
check(table.concat(reached, ",") == "top,bottom",
	"a failing step does not strand the others", table.concat(reached, ","))

-- Registering after teardown would otherwise leak whatever it holds.
local lateRan = false
local late = Contexts.newCleanupScope()
late:run()
late:add(function() lateRan = true end)
check(lateRan, "add() after run() executes immediately instead of leaking")

-- CONTEXT CHAIN ---------------------------------------------------------------

print("\nCONTEXT CHAIN")

local session = Contexts.newSession("room1", { "alice", "bob" }, 4242)
check(session:isActive(), "a new session is active")
check(session.playerCount == 2 and session.seed == 4242, "session carries player count and seed")

local trial = session:newTrial("minefield", 1, 3)
local round = trial:newRound(1, 4)
check(trial:isActive() and round:isActive(), "trial and round start active")

-- The whole point: cancelling an OUTER scope must deactivate the inner ones,
-- because a delayed callback only ever holds the round.
session.cancelled = true
check(not round:isActive(), "cancelling the session deactivates the round")
check(not trial:isActive(), "cancelling the session deactivates the trial")
session.cancelled = false

trial.cancelled = true
check(not round:isActive(), "cancelling the trial deactivates the round")
trial.cancelled = false
check(round:isActive(), "the round is active again once nothing above it is cancelled")

-- TOKENS ----------------------------------------------------------------------

print("\nTOKENS")

local seen = {}
local dupes = 0
local s2 = Contexts.newSession("room2", { "a", "b", "c" }, 1)
for i = 1, 5 do
	local t = s2:newTrial("birdhunt", i, 3)
	if seen[t.trialToken] then dupes = dupes + 1 end
	seen[t.trialToken] = true
	for r = 1, 4 do
		local rd = t:newRound(r, 4)
		if seen[rd.roundToken] then dupes = dupes + 1 end
		seen[rd.roundToken] = true
	end
end
check(dupes == 0, "no token is ever reused within a session", dupes .. " duplicates")

-- Bird Hunting: several legs share one round index, so the token must change per
-- LEG or a shot captured in leg 1 still validates in leg 3.
local t3 = s2:newTrial("birdhunt", 1, 3)
local r3 = t3:newRound(1, 4)
local leg1 = r3.roundToken
r3:newLeg(1)
local leg2 = r3.roundToken
r3:newLeg(2)
local leg3 = r3.roundToken
check(leg1 ~= leg2 and leg2 ~= leg3 and leg1 ~= leg3,
	"roundToken is regenerated for every leg")

-- Leaving a leg must not leak into the next one.
local legTornDown = false
local r4 = t3:newRound(2, 4)
r4:newLeg(1)
r4.cleanup:add(function() legTornDown = true end)
r4:newLeg(2)
check(legTornDown, "the previous leg's cleanup runs when the next leg starts")

-- ENVELOPE EXPECTATION --------------------------------------------------------

print("\nENVELOPE EXPECTATION")

local exp = r4:envelopeExpectation(7)
check(exp.sessionId == s2.sessionId and exp.trialId == "birdhunt"
	and exp.trialToken == t3.trialToken and exp.roundToken == r4.roundToken
	and exp.lastSeq == 7, "expectation carries the full identity chain")

-- GUARDED RUN -----------------------------------------------------------------

print("\nGUARDED RUN")

local torn = false
local g1 = Contexts.newCleanupScope()
g1:add(function() torn = true end)
local value = Contexts.guardedRun(g1, function() return "done" end)
check(value == "done" and torn, "success path returns the value and tears down")

torn = false
local g2 = Contexts.newCleanupScope()
g2:add(function() torn = true end)
local ok, err = pcall(function()
	Contexts.guardedRun(g2, function() error("trial exploded") end)
end)
check(not ok, "failure path re-raises instead of swallowing")
check(torn, "teardown ran even though the body failed")
check(tostring(err):find("trial exploded") ~= nil,
	"the original error survives to the caller", tostring(err))

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("GATE 1 CONTEXTS PROOF: FAIL")
	os.exit(1)
end
print("GATE 1 CONTEXTS PROOF: PASS")
os.exit(0)
