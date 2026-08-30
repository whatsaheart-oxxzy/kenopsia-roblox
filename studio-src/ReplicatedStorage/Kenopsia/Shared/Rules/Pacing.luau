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
	-- MP-05 section A. One row per new trial; a trial with no row is a plan
	-- error, not a default (roundsFor returns nil and MachineFlow falls back
	-- to 1 loudly).
	carve      = { [2] = 3, [3] = 3, [4] = 2 },
	armory     = { [2] = 3, [3] = 2, [4] = 2 },
	upstream   = { [2] = 3, [3] = 3, [4] = 2 },
	floorcheck = { [2] = 3, [3] = 3, [4] = 2 },
	clearance  = { [2] = 2, [3] = 2, [4] = 2 },
	carrier    = { [2] = 2, [3] = 3, [4] = 2 },
	breather   = { [2] = 3, [3] = 3, [4] = 3 },
	sweep      = { [2] = 3, [3] = 2, [4] = 2 },
	crawler    = { [2] = 3, [3] = 2, [4] = 2 },
	ricochet   = { [2] = 3, [3] = 3, [4] = 2 },
	stacker    = { [2] = 3, [3] = 3, [4] = 3 },
	sorting    = { [2] = 3, [3] = 2, [4] = 2 },
}

-- Bird Hunting counts LEGS, not rounds: one leg per scheduled Hunter. 3-player
-- sessions run 3 and 4-player sessions run 4, so this is NOT `playerCount` and
-- NOT `5 * playerCount` -- both of those were shipped before and are named in
-- the plan as errors not to repeat.
-- 22.08.2026 (MASTERPLAN P0.3): 3 legs x 60 s. Four 90-s legs made BIRD HUNTING
-- 422 s of a 771-s session -- more than half the evening for one minigame.
local LEGS = { [2] = 3, [3] = 3, [4] = 3 }

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
	-- 23.08.2026: 55 -> 62. The compactor's sweep speed is DERIVED from this
	-- number (Minefield: sweepDistance / (RoundSeconds - grace - approach)),
	-- so a slightly slower machine, as the 2-player test asked for, is a
	-- slightly longer round and nothing else.
	minefield = 62,
	birdhunt  = 60,
	-- 23.08.2026: 45 -> 60. The 2-player test read the canteen as over before
	-- the tension arrived; CanteenProtocol's observer ramps its watch across
	-- THIS number, so a longer round is a longer screw, not just more peas.
	canteen   = 60,
	-- MP-05 section A / D8: ONE number per trial, whatever the player count.
	-- TrialKit's R:setDeadline reads this; no trial derives its length from
	-- anything else.
	carve      = 45,
	armory     = 50,
	upstream   = 40,
	floorcheck = 35,
	clearance  = 50,
	carrier    = 45,
	breather   = 30,
	sweep      = 45,
	crawler    = 40,
	ricochet   = 45,
	stacker    = 20,
	sorting    = 40,
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
	-- 27.08.2026 (user): the cut to black that closes a round is LONG now. The
	-- 0.7 s beat that shipped on 24.08. was a blink -- long enough to hide the
	-- teardown, too short to read as "your round is over". This is the hold
	-- MachineFlow keeps the screen dark for after death / win / the round
	-- running out, before it fires the standings (or, on a trial's last round,
	-- the score board).
	--
	-- It is a FLOOR, not the length of the blackout: the client holds the black
	-- frame until the next Machine card actually lands, so a slow standings is
	-- more black, never a flash of the torn-down arena. Turn this one number to
	-- make the beat longer or shorter.
	RoundBlackout = 2.5,
	-- Client-side backstop for that held blackout. If the card that should
	-- clear it never arrives (a dropped packet, a stalled round), the fader
	-- lifts on its own after this many seconds rather than leaving somebody in
	-- front of a black screen for the rest of the session. Generous on purpose:
	-- it is a safety net, not a timer anyone should hit in a healthy session.
	BlackoutMax   = 25.0,
	Standings    = 2.5,  -- P1.2: standings card between rounds (typed, 5 lines)
	RoleCard     = 1.6,  -- P1.4: "<NAME> IS THE HUNTER." full screen before an asymmetric leg
	CountdownFrom = 3,   -- 3-2-1, one per second
	FadeMax      = 0.6,  -- upper bound on any transition fade
	InterimScore = 4.5,  -- score card after each completed minigame (plan: 3.0)
	-- P1.3 (23.08.2026, MASTERPLAN section 2 "Verdict"): the final board is the
	-- VIABLE/REJECTED stamp, 6 s, then the podium takes the camera for 8 s.
	FinalScore   = 6.0,  -- verdict stamp (was 8.0 while it was the only beat)
	Podium       = 8.0,  -- three blocks, winner in Idle, fixed camera
	ControlCard  = 8.0,  -- briefing; early confirm is allowed
	-- 23.08.2026 (MASTERPLAN P0.3 / section 3): the lobby roulette hold. The
	-- client spins the icon strip and lands on the chosen trial in this time;
	-- MachineFlow.preFlow used to hard-code `task.wait(6.4)` next to it.
	LobbyReveal  = 6.4,
	-- 26.08.2026 (user, MP-08 S10): derselbe Halt, aber ZWISCHEN den Trials.
	-- MachineFlow schickt bei jedem Trial-Wechsel jetzt auch ein
	-- kind="selection" (S9), und der Client spielt darauf dasselbe Roulette wie
	-- in der Lobby ab. Der Halt muss ueber Feel.rouletteSeconds(3) liegen
	-- (~5.9 s), sonst schneidet die Infokarte das Rad ab -- daher derselbe Wert
	-- wie LobbyReveal und NICHT weniger.
	--
	-- Eigener Eintrag statt LobbyReveal wiederzuverwenden, damit der Preis
	-- dieses Beats (6.4 s pro Wechsel, +12.8 s in einer Session mit drei
	-- Trials) an einer Stelle steht, an der man ihn drehen kann, ohne die
	-- Lobby mitzudrehen.
	TrialReveal  = 6.4,
	-- 29.08.2026 (Phase 3a): the canteen SETTLEMENT window. The FIRST cleaned
	-- plate no longer just waits for the rest -- it starts this many seconds in
	-- which the others may keep eating (the observer keeps running, every rate
	-- gate applies), then the round ends. CanteenProtocol reads it for the
	-- clock AND for the feed line ("SETTLEMENT. 5 SECONDS_"), so turning this
	-- one number turns both. tests/feel.lua holds it in (0, 6].
	CanteenSettlement = 5.0,
	-- 30.08.2026 (Phase 4b): the SHIFT REPORT hold -- the retention beat
	-- between the verdict stamp and the podium. MachineFlow sends every
	-- participant a personal kind="shiftreport" packet (XP delta, clearance,
	-- streak) and keeps the stage for this long. Dark until the client renders
	-- the kind -- an unknown kind renders NOTHING -- but the hold is REAL: the
	-- session grows by this many seconds. tests/feel.lua holds it in (0, 6].
	ShiftReport = 5.0,
}

-- The scoring pool a completed trial distributes. Kept here rather than in
-- Scoring so the pool and the pacing that produces it are read from one file.
Pacing.TrialPointPool = 1700

return Pacing
