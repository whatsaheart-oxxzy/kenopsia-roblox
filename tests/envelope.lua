-- Gate 1 offline proof, part 2: the packet envelope. Run from the repo root:
--
--     lua tests/envelope.lua
--
-- Loads the shipped module, same as tests/rules.lua. Exit code 0 only if every
-- check passes.

local function loadModule(path, parent)
	local chunk = assert(loadfile(path))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local Envelope = loadModule("studio-src/ReplicatedStorage/Kenopsia/Shared/Net/Envelope.luau")

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

local CTX = {
	sessionId = "S1",
	trialId = "minefield",
	trialToken = "T1",
	roundToken = "R1",
}
local function expect(over)
	local e = { sessionId = "S1", trialId = "minefield", trialToken = "T1", roundToken = "R1", lastSeq = 10 }
	for k, v in pairs(over or {}) do e[k] = v end
	return e
end

-- A packet the server should always accept.
local function good(seq, data)
	return Envelope.build(CTX, seq or 11, "hit", data or { x = 1, y = 2 })
end

print("\nENVELOPE -- accepts a well-formed packet")
local ok, reason = Envelope.validate(good(), expect())
check(ok, "well-formed packet accepted", tostring(reason))

print("\nENVELOPE -- identity")
local function rejects(payload, expectedTable, label)
	local accepted, why = Envelope.validate(payload, expectedTable or expect())
	check(not accepted, label, accepted and "ACCEPTED but should not be" or nil)
	return why
end

rejects("not a table", nil, "non-table rejected")
local p = good(); p.v = 2
rejects(p, nil, "wrong version rejected")
p = good(); p.sessionId = "OTHER"
rejects(p, nil, "stale sessionId rejected")
p = good(); p.trialId = "birdhunt"
rejects(p, nil, "packet aimed at another trial rejected")
p = good(); p.trialToken = "T0"
rejects(p, nil, "stale trialToken rejected")
p = good(); p.roundToken = "R0"
rejects(p, nil, "packet from a finished round rejected")

print("\nENVELOPE -- sequence")
rejects(good(10), nil, "replayed seq (equal to last) rejected")
rejects(good(9), nil, "reordered seq (below last) rejected")
rejects(good(10.5), nil, "fractional seq rejected")
rejects(good(0 / 0), nil, "NaN seq rejected")
check(Envelope.validate(good(11), expect()), "seq exactly one above last accepted")
check(Envelope.validate(good(999), expect()), "a forward jump is accepted (packet loss is not an attack)")

print("\nENVELOPE -- payload values")
rejects(good(11, { v = 0 / 0 }), nil, "NaN in data rejected")
rejects(good(11, { v = math.huge }), nil, "infinity in data rejected")
rejects(good(11, { v = -math.huge }), nil, "negative infinity rejected")
rejects(good(11, { pos = { X = 1, Y = 0 / 0, Z = 3 } }), nil, "vector with NaN component rejected")
check(Envelope.validate(good(11, { pos = { X = 1, Y = 2, Z = 3 } }), expect()),
	"vector with finite components accepted")
rejects(good(11, { f = function() end }), nil, "function in data rejected")
rejects(good(11, { s = string.rep("a", 65) }), nil, "over-long string rejected")

print("\nENVELOPE -- payload size")
local wide = {}
for i = 1, 100 do wide[i] = i end
rejects(good(11, wide), nil, "too many nodes rejected")

local deep = { a = { b = { c = { d = { e = 1 } } } } }
rejects(good(11, deep), nil, "too deep rejected")

print("\nENVELOPE -- action")
p = good(); p.action = nil
rejects(p, nil, "missing action rejected")
p = good(); p.action = ""
rejects(p, nil, "empty action rejected")
p = good(); p.action = string.rep("a", 33)
rejects(p, nil, "over-long action rejected")

print("\nENVELOPE -- build")
local built = Envelope.build(CTX, 7, "fire", { n = 1 })
check(built.v == Envelope.VERSION and built.sessionId == "S1" and built.trialId == "minefield"
	and built.trialToken == "T1" and built.roundToken == "R1" and built.seq == 7
	and built.action == "fire", "build fills every identity field")

-- P1.3 / P1.7 (23.08.2026): the Machine's camera packets (podium, audiencecam)
-- travel server -> client over MachineState, outside the validator's path --
-- but they are built to the SAME limits (depth, node count, string length), so
-- a future client-side scan or a bench-originated echo can never trip on them.
-- Proved by walking each packet as `data` through validate().
print("\nENVELOPE -- machine camera packets fit the limits")
local MachineCam = loadModule("studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/MachineCam.luau")
local fullBoard = {}
for i = 1, 4 do
	fullBoard[i] = { userId = 1000 + i, displayName = string.rep("N", 40) .. i, score = 5000 - i * 700 }
end
local podium = MachineCam.podiumPacket({ X = 900, Y = 0, Z = 1500 }, fullBoard)
local okP, whyP = Envelope.validate(Envelope.build(CTX, 11, "cam", podium), expect())
check(okP, "podium packet (4-player board, long names) passes depth/size/string limits", tostring(whyP))
check(#podium.rows == 3, "podium packet carries at most three rows", tostring(#podium.rows))
local aud = MachineCam.audiencePacket("minefield", { X = -164.9, Y = 44.7, Z = -1607.4 }, { X = -164.9, Y = 3.9, Z = -1790 })
local okA, whyA = Envelope.validate(Envelope.build(CTX, 12, "cam", aud), expect())
check(okA, "audiencecam packet passes the limits", tostring(whyA))
for _, kind in ipairs({ "podium", "audiencecam" }) do
	local okC, whyC = Envelope.validate(Envelope.build(CTX, 13, "cam", MachineCam.clearPacket(kind)), expect())
	check(okC, kind .. " clear packet passes the limits", tostring(whyC))
end
local nanCam = MachineCam.audiencePacket("x", { X = 0 / 0, Y = 0, Z = 0 }, { X = 1, Y = 1, Z = 1 })
rejects(Envelope.build(CTX, 14, "cam", nanCam), nil, "a camera packet with a NaN component is rejected by the scan")

-- A validator that throws instead of returning would force a pcall around every
-- remote handler, so every rejection path above must have returned normally.
check(true, "no rejection path threw")

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("GATE 1 ENVELOPE PROOF: FAIL")
	os.exit(1)
end
print("GATE 1 ENVELOPE PROOF: PASS")
os.exit(0)
