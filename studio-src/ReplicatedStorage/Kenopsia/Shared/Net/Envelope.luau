--!nonstrict
-- ENVELOPE (Gate 1) -- the shape every client packet must have, and the gate it
-- must pass before any trial code looks at it.
--
-- PURE, and portable to Lua 5.1: see the header of Rules/Pacing.luau for the
-- rule and why it exists. Nothing here calls `typeof`, which is Roblox-only --
-- vector-shaped values are identified by their components instead, so the same
-- source validates under both runtimes.
--
-- WHY AN ENVELOPE AT ALL ------------------------------------------------------
--
-- The trials previously accepted bare `{trialId, action}` tables. That is enough
-- for an exploit client to replay a shot from a finished round, act during a
-- round it is not in, or feed NaN into a position check -- none of which the
-- receiving code could distinguish from a legitimate packet, because the packet
-- carried nothing that tied it to a moment in time.
--
-- Every field here exists to close one of those:
--
--   v           -- the wire format, so a stale client fails loudly, not subtly
--   sessionId   -- this match, not the previous one
--   trialId     -- this trial, not another one running in the same session
--   trialToken  -- this RUN of that trial
--   roundToken  -- this round, and for Bird Hunting this LEG; regenerated per
--                  round so a replayed packet dies at the round boundary
--   seq         -- strictly increasing per sender, so a captured packet cannot
--                  be replayed inside its own round either
--   action/data -- what the player actually did
--
-- The validator is deliberately TOTAL: it returns a reason for every rejection
-- rather than throwing, because the caller has to be able to rate-limit and log
-- a bad sender without a pcall around every remote handler.

local Envelope = {}

Envelope.VERSION = 1

-- Payload limits. These are deliberately small: no legitimate action in any of
-- the three trials needs more. An oversized packet is either a bug or an attempt
-- to make the server walk a large structure on the remote thread.
Envelope.Limits = {
	MaxDepth = 4,
	MaxNodes = 64,
	MaxStringLength = 64,
	MaxActionLength = 32,
}

local function isFiniteNumber(n)
	if type(n) ~= "number" then return false end
	if n ~= n then return false end                       -- NaN: the only value that fails self-equality
	if n == math.huge or n == -math.huge then return false end
	return true
end

-- Vector3 and friends are userdata under Roblox and plain tables in a test, so
-- the check is on the components rather than on the type name. Anything
-- exposing X/Y/Z must have all three finite.
local function vectorComponentsOk(v)
	local ok, x, y, z = pcall(function() return v.X, v.Y, v.Z end)
	if not ok then return true end -- not a vector-shaped value; nothing to check
	if x == nil and y == nil and z == nil then return true end
	return isFiniteNumber(x) and isFiniteNumber(y) and isFiniteNumber(z)
end

-- Walks `value` and rejects anything the server should not be asked to hold:
-- non-finite numbers, vectors with non-finite components, over-long strings,
-- structures that are too deep or too wide, and functions or threads of any
-- kind. Returns ok, reason.
local function scan(value, depth, budget)
	if depth > Envelope.Limits.MaxDepth then return false, "payload too deep" end

	budget.n = budget.n + 1
	if budget.n > Envelope.Limits.MaxNodes then return false, "payload too large" end

	local t = type(value)
	if t == "number" then
		if not isFiniteNumber(value) then return false, "non-finite number" end
		return true
	elseif t == "string" then
		if #value > Envelope.Limits.MaxStringLength then return false, "string too long" end
		return true
	elseif t == "boolean" or t == "nil" then
		return true
	elseif t == "function" or t == "thread" then
		return false, "unserialisable value"
	elseif t == "userdata" then
		if not vectorComponentsOk(value) then return false, "non-finite vector" end
		return true
	elseif t == "table" then
		if not vectorComponentsOk(value) then return false, "non-finite vector" end
		for k, v in pairs(value) do
			local kt = type(k)
			if kt ~= "string" and kt ~= "number" then return false, "bad key type" end
			if kt == "number" and not isFiniteNumber(k) then return false, "non-finite key" end
			if kt == "string" and #k > Envelope.Limits.MaxStringLength then return false, "key too long" end
			local ok, reason = scan(v, depth + 1, budget)
			if not ok then return false, reason end
		end
		return true
	end
	return false, "unsupported type"
end

-- Builds a packet. `ctx` supplies the identity fields; the caller supplies the
-- sequence number, because the sequence belongs to the SENDER and not to the
-- round -- two clients in the same round have independent counters.
function Envelope.build(ctx, seq, action, data)
	return {
		v = Envelope.VERSION,
		sessionId = ctx.sessionId,
		trialId = ctx.trialId,
		trialToken = ctx.trialToken,
		roundToken = ctx.roundToken,
		seq = seq,
		action = action,
		data = data,
	}
end

-- Validates a packet against what the server currently expects.
--
-- `expected` carries sessionId / trialId / trialToken / roundToken and lastSeq,
-- the highest sequence already accepted from THIS sender. Returns ok, reason.
--
-- Order matters: cheap identity checks come before the payload walk, so a packet
-- aimed at a finished round is rejected without the server ever traversing its
-- contents.
function Envelope.validate(payload, expected)
	if type(payload) ~= "table" then return false, "not a table" end
	if payload.v ~= Envelope.VERSION then return false, "wrong version" end

	if type(payload.action) ~= "string" then return false, "missing action" end
	if #payload.action == 0 or #payload.action > Envelope.Limits.MaxActionLength then
		return false, "bad action"
	end

	for _, field in ipairs({ "sessionId", "trialId", "trialToken", "roundToken" }) do
		local want = expected[field]
		if want ~= nil and payload[field] ~= want then
			return false, "stale " .. field
		end
	end

	local seq = payload.seq
	if not isFiniteNumber(seq) then return false, "bad seq" end
	if math.floor(seq) ~= seq then return false, "fractional seq" end
	-- Strictly increasing. Equal is a replay, lower is a reorder or a replay --
	-- both are rejected, and neither is worth distinguishing to the sender.
	local last = expected.lastSeq
	if last ~= nil and seq <= last then return false, "replayed seq" end

	local ok, reason = scan(payload.data, 1, { n = 0 })
	if not ok then return false, reason end

	return true
end

return Envelope
