--!nonstrict
-- PLAYLIST (Gate 1) -- the order the trials are played in.
--
-- PURE, and portable to Lua 5.1: see the header of Pacing.luau for the rule and
-- why it exists.
--
-- WHY THIS DOES NOT USE math.random ------------------------------------------
--
-- Luau and Lua 5.1 ship DIFFERENT generators. A shuffle built on math.random
-- would be reproducible offline and reproducible in Studio -- and produce two
-- different orders from the same seed. The offline proof would then be proving
-- something the game never does, which is worse than having no proof at all.
--
-- It also would not survive `math.randomseed` being called anywhere else in the
-- session: a global generator is shared state, and the playlist must depend on
-- nothing but its seed.
--
-- So the generator lives here, is fully specified, and is identical everywhere.

local Playlist = {}

-- The order ids are drawn from. This is the ONLY place the set is written down.
-- `canteen` is listed because the ORDER is defined over all ids from Gate 1;
-- whether a trial is actually schedulable is a separate gate
-- (GameConfig.Playlist.TrialIds plus `ready` in the MachineFlow registry), which
-- is why listing it here cannot leak an unfinished trial into a session.
--
-- MP-05: the twelve new ids follow the shipped three. Same rule: the ORDER is
-- defined over the whole set; schedulability is the two gates above.
Playlist.Ids = {
	"minefield", "birdhunt", "canteen",
	"carve", "armory", "upstream", "floorcheck", "clearance", "carrier",
	"breather", "sweep", "crawler", "ricochet", "stacker", "sorting",
}

-- A 32-bit linear congruential generator -- Numerical Recipes constants.
-- Chosen for being small enough to state in full and identical under both
-- runtimes; it is not, and does not need to be, cryptographic.
--
-- 2^32 arithmetic stays exact in doubles: 1664525 * (2^32 - 1) is about 2^52.6,
-- under the 2^53 integer limit, so no precision is lost on either runtime.
local function lcg(seed)
	local state = math.floor(seed) % 4294967296
	if state < 0 then state = state + 4294967296 end
	return function(n)
		state = (1664525 * state + 1013904223) % 4294967296
		-- Take from the HIGH bits: the low bits of an LCG have short periods, so
		-- `state % n` would visibly bias a 3-element shuffle.
		return (math.floor(state / 65536) % n) + 1
	end
end

-- Fisher-Yates. Every id exactly once, no repeats, order determined solely by
-- the seed.
function Playlist.order(seed)
	local out = {}
	for i = 1, #Playlist.Ids do
		out[i] = Playlist.Ids[i]
	end
	local nextInt = lcg(seed or 0)
	for i = #out, 2, -1 do
		local j = nextInt(i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- D7: the slice one session actually plays. Walks `order` and keeps the first
-- `perSession` ids for which enabled[id] is truthy; perSession nil or 0 keeps
-- them all. Pure, so tests/rules.lua can prove the slice property; MachineFlow's
-- playableOrder maps the ids back to registry entries.
function Playlist.session(order, enabled, perSession)
	local out = {}
	local limit = tonumber(perSession) or 0
	for _, id in ipairs(order) do
		if enabled[id] then
			out[#out + 1] = id
			if limit > 0 and #out >= limit then break end
		end
	end
	return out
end

-- True when `id` names a trial the playlist knows about. Used to reject a
-- trialId arriving from a client before it is looked up anywhere.
function Playlist.isKnown(id)
	for _, known in ipairs(Playlist.Ids) do
		if known == id then return true end
	end
	return false
end

return Playlist
