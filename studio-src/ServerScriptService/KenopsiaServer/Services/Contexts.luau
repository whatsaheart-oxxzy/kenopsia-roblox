--!nonstrict
-- CONTEXTS (Gate 1) -- who is playing, which trial, which round, and how any of
-- it is torn down.
--
-- Three nested scopes, each owning exactly one lifetime:
--
--   SessionContext  one match: the participants, the seed, the trial order
--   TrialContext    one RUN of one trial inside that match
--   RoundContext    one round -- and for Bird Hunting, one LEG
--
-- WHY TOKENS, AND WHY PER LEG -------------------------------------------------
--
-- Every context carries a token that appears in the packet envelope. A packet is
-- only acted on when its token is the CURRENT one, which is what makes a
-- captured packet worthless the moment its round ends.
--
-- Bird Hunting is why `newLeg` exists. A leg is a full hunter-versus-runners
-- exchange and behaves like a round, but several legs share one round index. If
-- the token only changed per round, a shot captured in leg 1 would still
-- validate in leg 3.
--
-- WHY isActive() IS CHECKED BY EVERY DELAYED CALLBACK -------------------------
--
-- Almost every bug this file exists to prevent has the same shape: something was
-- scheduled with task.delay or task.spawn, the round ended, and the callback ran
-- anyway -- moving a camera that belongs to the next trial, awarding a point in a
-- round that is over, or clearing effects for a player who is now elsewhere.
--
-- isActive() walks the whole chain, so a round is inactive the instant its
-- trial or its session is cancelled. Checking only the round would miss a
-- match-level abort.
--
-- NO MODULE-GLOBAL `current` --------------------------------------------------
--
-- State hangs off the context, and contexts are handed to the code that needs
-- them. A module-level `current` is shared mutable state between rooms: with two
-- rooms running, the second overwrites the first and the first's cleanup then
-- tears down the wrong round.

local HttpService = game:GetService("HttpService")

local Contexts = {}

-- CLEANUP SCOPE ---------------------------------------------------------------
-- Generalises the `guard.cleanup` pattern already used by Minefield.runRound and
-- BirdHunting.runRound: one guard table, one teardown, run whatever happened.
-- What it adds is MANY teardowns instead of one, and an idempotent run().

local CleanupScope = {}
CleanupScope.__index = CleanupScope

function Contexts.newCleanupScope()
	return setmetatable({ _fns = {}, _done = false }, CleanupScope)
end

-- Registering after the scope has already run means the caller raced teardown.
-- The function is run IMMEDIATELY rather than stored, because storing it would
-- leak whatever it was meant to release -- run() is never coming again.
function CleanupScope:add(fn)
	if type(fn) ~= "function" then return end
	if self._done then
		pcall(fn)
		return
	end
	table.insert(self._fns, fn)
end

-- Idempotent by design. "Double cleanup" is on the plan's list of errors not to
-- repeat: a round that ends normally AND then errors would otherwise tear the
-- same state down twice, and the second pass typically operates on instances the
-- first one destroyed.
--
-- LIFO, because teardown must unwind in the reverse of construction -- the thing
-- registered last is the thing that depends on everything before it.
--
-- Each entry is pcall'd on its own so one failing teardown cannot strand the
-- rest. Failures are warned, never swallowed silently.
function CleanupScope:run()
	if self._done then return end
	self._done = true
	for i = #self._fns, 1, -1 do
		local ok, err = pcall(self._fns[i])
		if not ok then
			warn("[Contexts] cleanup step failed: " .. tostring(err))
		end
	end
	self._fns = {}
end

function CleanupScope:isDone()
	return self._done
end

-- ROUND -----------------------------------------------------------------------

local RoundContext = {}
RoundContext.__index = RoundContext

function RoundContext:isActive()
	return not self.cancelled and self.trial:isActive()
end

-- Starts a new leg inside the same round: fresh token, fresh cleanup scope.
-- The previous leg's scope is run first, so leaving a leg can never leak into
-- the next one.
function RoundContext:newLeg(legIndex)
	self.cleanup:run()
	self.legIndex = legIndex
	self.roundToken = self.trial.session:_nextToken("leg")
	self.cleanup = Contexts.newCleanupScope()
	return self
end

function RoundContext:cancel()
	self.cancelled = true
	self.cleanup:run()
end

-- The envelope fields a packet must carry to be accepted in this round.
function RoundContext:envelopeExpectation(lastSeq)
	return {
		sessionId = self.trial.session.sessionId,
		trialId = self.trial.trialId,
		trialToken = self.trial.trialToken,
		roundToken = self.roundToken,
		lastSeq = lastSeq,
	}
end

-- TRIAL -----------------------------------------------------------------------

local TrialContext = {}
TrialContext.__index = TrialContext

function TrialContext:isActive()
	return not self.cancelled and self.session:isActive()
end

function TrialContext:newRound(roundIndex, roundCount)
	local round = setmetatable({
		trial = self,
		index = roundIndex,
		count = roundCount,
		legIndex = nil,
		legCount = nil,
		roundToken = self.session:_nextToken("round"),
		cancelled = false,
		cleanup = Contexts.newCleanupScope(),
	}, RoundContext)
	self.round = round
	return round
end

function TrialContext:cancel()
	self.cancelled = true
	if self.round then self.round:cancel() end
	self.cleanup:run()
end

-- SESSION ---------------------------------------------------------------------

local SessionContext = {}
SessionContext.__index = SessionContext

function SessionContext:isActive()
	return not self.cancelled
end

-- Tokens are unique within the session and never reused. The counter is enough:
-- a client cannot profit from predicting a future token, because the server only
-- ever compares against the CURRENT one, and a packet carrying a future token
-- arrives before that round exists and is rejected for exactly that reason.
function SessionContext:_nextToken(kind)
	self._tokenSeq = self._tokenSeq + 1
	return string.format("%s:%s:%d", self.sessionId, kind, self._tokenSeq)
end

function SessionContext:newTrial(trialId, index, count)
	local trial = setmetatable({
		session = self,
		trialId = trialId,
		index = index,
		count = count,
		trialToken = self:_nextToken("trial"),
		cancelled = false,
		round = nil,
		cleanup = Contexts.newCleanupScope(),
	}, TrialContext)
	self.trial = trial
	return trial
end

function SessionContext:cancel()
	self.cancelled = true
	if self.trial then self.trial:cancel() end
	self.cleanup:run()
end

-- `participants` is SNAPSHOTTED here, not read live from the room. The order of
-- play, the number of rounds and the scoring pool are all derived from it, and a
-- player leaving mid-session must not silently change the pacing of a trial that
-- is already running.
function Contexts.newSession(roomId, participants, seed)
	-- selene: allow(manual_table_clone)
	-- NOT table.clone. Everything above this line -- CleanupScope, the isActive
	-- chain, the token sequence -- is exercised by tests/contexts.lua under Lua
	-- 5.1, which has no table.clone. Those are the safety properties most worth
	-- proving, so the loop stays.
	local snapshot = {}
	for i, p in ipairs(participants or {}) do
		snapshot[i] = p
	end
	return setmetatable({
		sessionId = HttpService:GenerateGUID(false),
		roomId = roomId,
		participants = snapshot,
		playerCount = #snapshot,
		seed = seed,
		cancelled = false,
		trial = nil,
		cleanup = Contexts.newCleanupScope(),
		_tokenSeq = 0,
	}, SessionContext)
end

-- GUARDED RUN -----------------------------------------------------------------
-- The exact contract Minefield.runRound and BirdHunting.runRound already
-- implement by hand, in one place so all three trials cannot drift apart.
--
-- Teardown ALWAYS runs. On failure the ORIGINAL traceback is re-raised after
-- teardown, never swallowed: MachineFlow's finalizer depends on seeing the error
-- to set outcome = "error" and abort the match. An early version of the Dead Zone
-- swallowed round errors and returned zeroed scores, so a broken trial repeated
-- the same throw for every round and then reported a final board of zeros with
-- nothing on screen to say anything had gone wrong.
function Contexts.guardedRun(scope, fn)
	local ok, result = xpcall(fn, debug.traceback)
	scope:run()
	if not ok then
		error(result, 0)
	end
	return result
end

return Contexts
