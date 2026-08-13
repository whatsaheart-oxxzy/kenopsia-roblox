--!nonstrict
-- PACING (Gate 1) -- rounds, legs and every timing constant in one place.
--
-- PURE. No `game`, no services, no instances, no os/clock access. That is not
-- stylistic: it is what lets Gate 1 be PROVED by `tests/rules.lua` from the
-- command line instead of demonstrated by playing the game.
--
-- PORTABILITY RULE for this file and its siblings under Rules/ and Net/:
-- they must parse and run under BOTH Luau and plain Lua 5.1, because the offline
-- proof runs on the Lua 5.1 interpreter on this machine. That means:
--
--   * no type annotations       (`x: number` is a syntax error in 5.1)
--   * no generalized iteration  (`for k, v in t` -- use pairs/ipairs)
--   * no table.create / table.clear / table.freeze / continue
--
-- `--!nonstrict` is only a comment to 5.1, so it is safe to keep.
--
-- The point is that the offline proof runs THE SAME SOURCE the game runs. A test
-- against a rewritten copy would prove nothing about what ships.

local Pacing = {}

-- Player-count rows. Solo is deliberately mapped onto the 2-player row rather
-- than given one of its own: Studio debug is the only way to reach it, and a
-- separate row would be pacing that no live session can ever produce.
local function row(counts, playerCount)
	local n = playerCount or 0
	if n <= 2 then return counts[2] end
	if n >= 4 then return counts[4] end
	return counts[n]
end

-- Rounds per trial, by player count. From plan §2.
local ROUNDS = {
	minefield = { [2] = 4, [3] = 3, [4] = 3 },
	canteen   = { [2] = 3, [3] = 2, [4] = 2 },
}

-- Bird Hunting counts LEGS, not rounds: one leg per scheduled Hunter. 3-player
-- sessions run 3 and 4-player sessions run 4, so this is NOT `playerCount` and
-- NOT `5 * playerCount` -- both of those were shipped before and are named in
-- the plan as errors not to repeat.
local LEGS = { [2] = 4, [3] = 3, [4] = 4 }

function Pacing.roundsFor(trialId, playerCount)
	if trialId == "birdhunt" then
		return row(LEGS, playerCount)
	end
	local counts = ROUNDS[trialId]
	if not counts then return nil end
	return row(counts, playerCount)
end

function Pacing.legsFor(playerCount)
	return row(LEGS, playerCount)
end

-- Per-trial time limits, seconds. The Dead Zone value replaces the old
-- FAILSAFE_TIME of 150 and is what the crusher traversal must be tuned against;
-- the Bird value replaces ROUND_TIME 150.
Pacing.RoundSeconds = {
	minefield = 55,
	birdhunt  = 90,
	canteen   = 45,
}

-- Session and presentation timing, seconds. Every delay in the session loop
-- comes from here so that no controller invents its own.
--
-- THESE ARE TUNED TO THE CLIENT'S ANIMATIONS, not just to the plan's numbers.
-- The screens type their text out (showInfo at ~26 chars/s, showStatus one line
-- per 0.25 s), so a hold shorter than the typewriter makes the card vanish
-- before it has finished writing itself. That is exactly what the first live run
-- of the session loop showed.
--
-- Deviation recorded: the plan gives 3 s interim and 6 s final. Both are raised
-- below. Those numbers were written against a design where the CRT counts down
-- while totals climb; against the typewriter the reviewer observed them as too
-- short to read. The plan's values are kept in this comment so the deviation is
-- visible rather than lost.
Pacing.Timing = {
	Reveal       = 3.5,  -- "NEXT SIMULATION: <name>", typed out
	Title        = 1.2,  -- in-trial title card (plan value, no typewriter)
	RoundCard    = 3.0,  -- "Round n/m" plus its verb line
	RoundSettle  = 1.5,  -- beat after a round ends, before the next card
	CountdownFrom = 3,   -- 3-2-1, one per second
	FadeMax      = 0.6,  -- upper bound on any transition fade
	InterimScore = 4.5,  -- score card after each completed minigame (plan: 3.0)
	FinalScore   = 8.0,  -- final cumulative board (plan: 6.0)
	ControlCard  = 8.0,  -- briefing; early confirm is allowed
}

-- The scoring pool a completed trial distributes. Kept here rather than in
-- Scoring so the pool and the pacing that produces it are read from one file.
Pacing.TrialPointPool = 1700

return Pacing
