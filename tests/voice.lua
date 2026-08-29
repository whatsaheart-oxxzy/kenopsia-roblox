-- P1.4 Machine voice offline proof. Run from the repo root:
--
--     lua tests/voice.lua
--
-- Loads the SHIPPED Shared/Config/MachineVoice.luau (no copy) and proves the
-- voice rules of docs/MASTERPLAN.md section 2 for every line in the pool, plus
-- the contract MachineFlow and the client rely on: pick() is deterministic for
-- a deterministic rng, never leaks a placeholder, and roleCard() prints the
-- sentence the role card beat shows.
--
-- Exit code is 0 only if every check passes, so this is usable as a gate.

local FILE = "studio-src/ReplicatedStorage/Kenopsia/Shared/Config/MachineVoice.luau"

local function loadModule(file)
	local chunk = assert(loadfile(file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local Voice = loadModule(FILE)

local failures = 0
local checks = 0

local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
	end
end

-- A small deterministic generator in the Playlist style, so the proof does not
-- depend on Lua 5.1's math.random matching Luau's.
local function lcg(seed)
	local state = seed % 2147483648
	return function(n)
		state = (1103515245 * state + 12345) % 2147483648
		return (math.floor(state / 65536) % n) + 1
	end
end

-- 1. THE POOL ----------------------------------------------------------------

print("\nMACHINE VOICE -- the pool")

local required = { "outcome", "swing", "streak", "firstdeath", "sweep", "idle", "lastdiner" }
local all = Voice.all()
local perCategory = {}
for _, e in ipairs(all) do
	perCategory[e.category] = (perCategory[e.category] or 0) + 1
end

check(#all >= 40, "at least 40 lines in the pool", string.format("got %d", #all))
for _, c in ipairs(required) do
	check((perCategory[c] or 0) > 0, string.format("category %-10s is non-empty (%d)", c, perCategory[c] or 0))
end
check(#Voice.Categories == #required, "exactly the seven categories are declared",
	string.format("got %d", #Voice.Categories))

local tooLong, lowercase, bangs, nameLong, unknownPh, dupes, seen = {}, {}, {}, {}, {}, {}, {}
for _, e in ipairs(all) do
	local t = e.text
	if #t > Voice.MaxLength then tooLong[#tooLong + 1] = t end
	if t ~= string.upper(t) then lowercase[#lowercase + 1] = t end
	if string.find(t, "!", 1, true) then bangs[#bangs + 1] = t end
	-- A <NAME> line grows by up to NameLength - 6 after substitution, so its
	-- template must leave room: 48 - (14 - 6) = 40.
	if string.find(t, "<NAME>", 1, true) and #t > Voice.MaxLength - (Voice.NameLength - 6) then
		nameLong[#nameLong + 1] = t
	end
	local stripped = string.gsub(string.gsub(t, "<NAME>", ""), "<DIR>", "")
	if string.find(stripped, "[<>]") then unknownPh[#unknownPh + 1] = t end
	if seen[t] then dupes[#dupes + 1] = t end
	seen[t] = true
end
check(#tooLong == 0, string.format("every line is at most %d characters", Voice.MaxLength), table.concat(tooLong, " | "))
check(#lowercase == 0, "every line is uppercase", table.concat(lowercase, " | "))
check(#bangs == 0, "no exclamation marks", table.concat(bangs, " | "))
check(#nameLong == 0, "every <NAME> line leaves room for a 14-character name", table.concat(nameLong, " | "))
check(#unknownPh == 0, "only <NAME> and <DIR> placeholders are used", table.concat(unknownPh, " | "))
check(#dupes == 0, "no duplicate lines", table.concat(dupes, " | "))

-- 2. PICK --------------------------------------------------------------------

print("\nMACHINE VOICE -- pick()")

-- Same seed, same sequence, across every category and both ctx shapes.
local function sequence(seed)
	local rng = lcg(seed)
	local out = {}
	for round = 1, 20 do
		for _, c in ipairs(required) do
			out[#out + 1] = Voice.pick(c, rng, { name = "Subject" .. round, dir = (round % 2 == 0) and "up" or "down" }) or "nil"
			out[#out + 1] = Voice.pick(c, rng, nil) or "nil"
		end
	end
	return table.concat(out, "\n")
end
check(sequence(11) == sequence(11), "pick is deterministic for a seeded rng")
local varied = false
for seed = 1, 20 do
	if sequence(seed) ~= sequence(seed + 1) then varied = true end
end
check(varied, "pick varies with the seed")

-- Every pick returns a string from the right category, fully substituted,
-- within the length limit, for 300 draws per category and ctx shape.
local badPick = {}
local function inPool(category, line, ctx)
	for _, raw in ipairs(Voice.Lines[category]) do
		local expect = raw
		if ctx and ctx.name then expect = string.gsub(expect, "<NAME>", string.upper(ctx.name)) end
		if ctx and ctx.dir then expect = string.gsub(expect, "<DIR>", string.upper(ctx.dir)) end
		if expect == line then return true end
	end
	return false
end
for _, c in ipairs(required) do
	local rng = lcg(99)
	for i = 1, 300 do
		local ctx = (i % 3 == 0) and nil or { name = "Valk", dir = (i % 2 == 0) and "up" or "down" }
		local line = Voice.pick(c, rng, ctx)
		if type(line) ~= "string" then
			badPick[#badPick + 1] = c .. ": nil"
		elseif string.find(line, "[<>]") then
			badPick[#badPick + 1] = c .. ": placeholder leaked: " .. line
		elseif #line > Voice.MaxLength then
			badPick[#badPick + 1] = c .. ": too long: " .. line
		elseif not inPool(c, line, ctx) then
			badPick[#badPick + 1] = c .. ": not from its pool: " .. line
		end
	end
end
check(#badPick == 0, "1800 picks: string, no placeholder, in range, from the right pool",
	table.concat(badPick, " | ", 1, math.min(#badPick, 5)))

-- With a name every <NAME> line is reachable; without one none is.
local withName, withoutName = {}, {}
do
	local rng = lcg(5)
	for _ = 1, 400 do
		withName[Voice.pick("streak", rng, { name = "Orla" })] = true
		withoutName[Voice.pick("streak", rng, nil)] = true
	end
end
local reachable, leaked = 0, 0
for _, raw in ipairs(Voice.Lines.streak) do
	if string.find(raw, "<NAME>", 1, true) then
		local filled = string.gsub(raw, "<NAME>", "ORLA")
		if withName[filled] then reachable = reachable + 1 end
		for line in pairs(withoutName) do
			if line == filled then leaked = leaked + 1 end
		end
	end
end
check(reachable > 0 and leaked == 0, "<NAME> lines are drawn with a name and never without one",
	string.format("reachable %d leaked %d", reachable, leaked))

-- Names are uppercased and cut to NameLength; a % in a name is harmless.
local longName = Voice.pick("streak", function() return 1 end, { name = "abcdefghijklmnopqrstuvwxyz" })
check(longName == "ABCDEFGHIJKLMN AGAIN. THE PATTERN IS NOTED.", "name is uppercased and cut to 14", tostring(longName))
local pctName = Voice.pick("streak", function() return 1 end, { name = "50%er" })
check(pctName == "50%ER AGAIN. THE PATTERN IS NOTED.", "a % in a name survives substitution", tostring(pctName))

check(Voice.pick("no-such-category", lcg(1), nil) == nil, "unknown category returns nil")

-- A Roblox-style generator (NextInteger method) is accepted too.
local fakeRandom = { NextInteger = function(_, lo, hi) return hi end }
local viaMethod = Voice.pick("idle", fakeRandom, nil)
check(viaMethod == Voice.Lines.idle[#Voice.Lines.idle], "a NextInteger-style rng is accepted", tostring(viaMethod))

-- 3. ROLE CARD ---------------------------------------------------------------

print("\nMACHINE VOICE -- roleCard()")

check(Voice.roleCard("birdhunt", "hunter", "Tamem") == "TAMEM IS THE HUNTER.",
	"birdhunt hunter -> TAMEM IS THE HUNTER.", Voice.roleCard("birdhunt", "hunter", "Tamem"))
check(Voice.roleCard("unknown", "inspector", "  bob ") == "BOB IS THE INSPECTOR.",
	"unknown trial falls back to <NAME> IS THE <ROLE>.", Voice.roleCard("unknown", "inspector", "  bob "))
local longCard = Voice.roleCard("birdhunt", "hunter", "abcdefghijklmnopqrstuvwxyz")
check(#longCard <= Voice.MaxLength and longCard == string.upper(longCard) and not string.find(longCard, "!", 1, true),
	"role card obeys the voice rules with a 20-character name", longCard)
check(Voice.roleCard("birdhunt", "hunter", nil) == "? IS THE HUNTER.", "a missing name prints ?")

-- SUMMARY --------------------------------------------------------------------

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("MACHINE VOICE PROOF: FAIL")
	os.exit(1)
end
print("MACHINE VOICE PROOF: PASS")
os.exit(0)
