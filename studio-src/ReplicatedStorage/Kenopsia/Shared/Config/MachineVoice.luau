--!nonstrict
-- MACHINE VOICE (P1.4) -- the comment pool and the role card.
--
-- The Machine never speaks. It prints. Every line here follows MASTERPLAN
-- section 2: uppercase, industrial, no jokes, no exclamation marks, at most
-- 48 characters so it fits one CRT row at 13 px under the standings and at
-- 16 px under the score rows. Lines are ORIGINAL to Kenopsia; tests/rules.lua
-- greps this file for the reference game's copy strings like any other
-- shipped file, and tests/voice.lua proves the rules above for every line.
--
-- PURE and portable to Lua 5.1 (see the header of Rules/Pacing.luau for the
-- rule): no Roblox globals at module level, no compound assignment, no
-- generalized iteration. MachineFlow hands in a Random; the tests hand in a
-- function. Both are accepted by pick().
--
-- Placeholders: `<NAME>` is replaced from ctx.name (uppercased, cut to 14
-- characters like the standings rows), `<DIR>` from ctx.dir ("UP" / "DOWN").
-- A line whose placeholder has no value in ctx is simply not a candidate, so a
-- packet with no name never prints "<NAME>" and a swing line never guesses a
-- direction.

local MachineVoice = {}

MachineVoice.MaxLength = 48
MachineVoice.NameLength = 14

MachineVoice.Categories = { "outcome", "swing", "streak", "firstdeath", "sweep", "idle" }

MachineVoice.Lines = {
	-- A trial has been won and lost. Spoken with the score board.
	outcome = {
		"RESULT LOGGED. THE FLOOR DOES NOT CARE.",
		"ONE SUBJECT MET SPEC. THE REST DID NOT.",
		"<NAME> CLEARED THE TRIAL. NOTED.",
		"THE MACHINE RECORDS. IT DOES NOT PRAISE.",
		"OUTPUT WITHIN TOLERANCE. PROCEED.",
		"OUTPUT BELOW TOLERANCE. PROCEED ANYWAY.",
		"FIGURES FILED. NOBODY IS EXCUSED.",
		"<NAME> HOLDS THE TOP FIGURE.",
		"THE TRIAL IS CLOSED. THE LEDGER IS NOT.",
		"NUMBERS ARE IN. THE NUMBERS ARE FINAL.",
		"PERFORMANCE NOTED. NOTHING IS OWED.",
		"<NAME> IS AHEAD. AHEAD IS NOT SAFE.",
	},
	-- A rank changed hands between two rounds.
	swing = {
		"<NAME> MOVED <DIR>. THE LEDGER NOTES IT.",
		"<NAME> GOES <DIR>. THE FLOOR SHIFTS.",
		"POSITIONS REASSIGNED. ADJUST.",
		"A RANK CHANGED HANDS. NOBODY APPLAUDED.",
		"THE ORDER HAS BEEN REVISED.",
		"UPWARD MOTION DETECTED. IT WILL NOT LAST.",
		"DOWNWARD MOTION DETECTED. AS EXPECTED.",
		"RANKS REORDERED. THE LEDGER IS CORRECTED.",
		"<NAME> GAINS GROUND. GROUND IS ON LOAN.",
		"<NAME> LOSES GROUND. IT IS NOT RETURNED.",
	},
	-- The same subject on top twice or more in a row.
	streak = {
		"<NAME> AGAIN. THE PATTERN IS NOTED.",
		"<NAME> REMAINS ON TOP. PATTERN LOGGED.",
		"THE SAME SUBJECT LEADS. THE REST FOLLOW.",
		"TOP POSITION UNCHANGED. THE REST ARE SLOW.",
		"<NAME> HOLDS. THE OTHERS DRIFT.",
		"ONE SUBJECT KEEPS WINNING. RECALIBRATE.",
		"A STREAK IS A PATTERN. PATTERNS END.",
		"<NAME> IS STILL FIRST. TOLERATED.",
		"DOMINANCE RECORDED. NOT REWARDED.",
	},
	-- The first body of the session.
	firstdeath = {
		"FIRST LOSS OF THE SHIFT. THE REST CONTINUE.",
		"ONE SUBJECT PROCESSED. THE LINE MOVES ON.",
		"<NAME> IS THE FIRST TO GO. NOTED.",
		"THE FIRST BODY IS LOGGED. MORE WILL FOLLOW.",
		"ONE LESS SUBJECT. OUTPUT UNAFFECTED.",
		"INITIAL CASUALTY RECORDED. PROCEED.",
		"<NAME> HAS BEEN PROCESSED. CONTINUE.",
		"THE FLOOR HAS TAKEN ITS FIRST. IT WANTS MORE.",
	},
	-- Everyone but one went down, or one subject never failed a round.
	sweep = {
		"<NAME> IS THE ONLY ONE LEFT STANDING.",
		"ONE SUBJECT REMAINS. THE REST ARE FILED.",
		"<NAME> FINISHED EVERY ROUND. ANOMALY.",
		"A CLEAN RUN. THE MACHINE IS NOT IMPRESSED.",
		"TOTAL CLEARANCE. RECORD IT AND MOVE ON.",
		"ALL OTHERS PROCESSED. ONE UNIT INTACT.",
		"<NAME> DID NOT FAIL ONCE. UNDER REVIEW.",
		"THE FLOOR IS EMPTY BUT FOR ONE.",
		"FULL SWEEP. THE SURVIVOR IS UNDER WATCH.",
	},
	-- Lobby filler while the Machine waits for a full shift.
	idle = {
		"THE MACHINE IS WAITING. IT IS PATIENT.",
		"SUBJECTS PENDING. CYCLE NOT YET STARTED.",
		"UPTIME CONTINUES. NOTHING ELSE DOES.",
		"THE FLOOR IS CLEAN. IT WILL NOT STAY CLEAN.",
		"STANDBY. THE SHIFT HAS NOT BEGUN.",
		"SEATS AVAILABLE. VOLUNTEERS ARE NOT.",
		"THE LINE IS IDLE. THE LINE REMEMBERS.",
		"NO INPUT. THE MACHINE NOTES THIS TOO.",
		"WAITING FOR A FULL SHIFT.",
		"CALIBRATION COMPLETE. SUBJECTS ARE NOT.",
	},
}

-- Role cards: one sentence, full screen, 1.6 s (Pacing.Timing.RoleCard). Keyed
-- by trial id then role; `default` is the fallback for any trial that names a
-- role without its own phrasing.
MachineVoice.RoleCards = {
	default = "<NAME> IS THE <ROLE>.",
	birdhunt = {
		hunter = "<NAME> IS THE HUNTER.",
		runner = "<NAME> RUNS THE FIELD.",
	},
}

-- Uppercase, trimmed, cut to `limit` characters. Never nil.
local function formatName(name, limit)
	local s = string.upper(tostring(name or "?"))
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if s == "" then s = "?" end
	s = string.sub(s, 1, limit or MachineVoice.NameLength)
	-- The result is a gsub replacement string, so a literal % must be doubled.
	return (string.gsub(s, "%%", "%%%%"))
end

-- One integer in 1..n from whatever generator the caller has. A function is
-- called as rng(n) (tests, Playlist-style LCGs); a Roblox Random through its
-- NextInteger method; anything else falls back to math.random, which is the
-- only non-deterministic path and is never taken by MachineFlow.
local function draw(rng, n)
	if n <= 1 then return 1 end
	local t = type(rng)
	if t == "function" then
		local v = tonumber(rng(n)) or 1
		return ((math.floor(v) - 1) % n) + 1
	end
	if (t == "table" or t == "userdata") and rng.NextInteger then
		local ok, v = pcall(function() return rng:NextInteger(1, n) end)
		if ok and type(v) == "number" then return v end
	end
	return math.random(n)
end

local function substitute(line, ctx)
	local out = line
	if string.find(out, "<NAME>", 1, true) then
		out = string.gsub(out, "<NAME>", formatName(ctx.name))
	end
	if string.find(out, "<DIR>", 1, true) then
		out = string.gsub(out, "<DIR>", string.upper(tostring(ctx.dir)))
	end
	return out
end

-- The candidates of a category for this ctx: every line whose placeholders
-- can all be filled. Order is the pool's order, so the draw is reproducible.
local function candidates(category, ctx)
	local pool = MachineVoice.Lines[category]
	if not pool then return {} end
	local out = {}
	for i = 1, #pool do
		local line = pool[i]
		local needsName = string.find(line, "<NAME>", 1, true) ~= nil
		local needsDir = string.find(line, "<DIR>", 1, true) ~= nil
		if (not needsName or ctx.name ~= nil) and (not needsDir or (ctx.dir == "up" or ctx.dir == "down")) then
			out[#out + 1] = line
		end
	end
	return out
end

-- pick(category, rng, ctx) -> line or nil.
-- Deterministic for a deterministic rng. ctx = { name = ?, dir = "up"|"down" }
-- or nil. Unknown category -> nil, so a packet simply carries no line.
function MachineVoice.pick(category, rng, ctx)
	ctx = ctx or {}
	local pool = candidates(category, ctx)
	if #pool == 0 then return nil end
	local line = pool[draw(rng, #pool)]
	return substitute(line, ctx)
end

-- roleCard(trialId, roleName, playerName) -> "<NAME> IS THE HUNTER."
-- The name is cut at 20 (a display name's maximum), so the sentence stays
-- inside MaxLength for every role phrase above.
function MachineVoice.roleCard(trialId, roleName, playerName)
	local role = string.lower(tostring(roleName or ""))
	local perTrial = MachineVoice.RoleCards[trialId]
	local template = (type(perTrial) == "table" and perTrial[role]) or MachineVoice.RoleCards.default
	local out = string.gsub(template, "<NAME>", formatName(playerName, 20))
	out = string.gsub(out, "<ROLE>", string.upper(role))
	return out
end

-- Every line of every category, for the tests and for anyone who wants to
-- count them. Fresh array each call; the pool itself is never handed out.
function MachineVoice.all()
	local out = {}
	for _, category in ipairs(MachineVoice.Categories) do
		local pool = MachineVoice.Lines[category] or {}
		for i = 1, #pool do
			out[#out + 1] = { category = category, text = pool[i] }
		end
	end
	return out
end

return MachineVoice
