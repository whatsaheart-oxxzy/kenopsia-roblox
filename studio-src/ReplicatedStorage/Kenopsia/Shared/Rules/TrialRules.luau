--!nonstrict
-- TRIAL RULES (MP-05 Framework) -- the PURE half of the server TrialKit.
--
-- PURE, and portable to Lua 5.1: see the header of Pacing.luau for the rule and
-- why it exists. TrialKit (a server module, needs `game`) requires this file and
-- wraps its numbers in Vector3/CFrame; `tests/trialrules.lua` proves the numbers
-- from the command line. Nothing here may touch `game`, services, instances,
-- `os.clock` or `math.random`.
--
-- What lives here and why:
--   * banded ordering keys  -- every new trial ranks players with the same three
--                              bands (FINISHED > ALIVE > OUT); the clamp that keeps
--                              per-band detail below the next band is the whole
--                              point, so it is proved once instead of twelve times.
--   * grid arithmetic       -- floor plates are found by ARITHMETIC on a position,
--                              never by Touched (REQ-DZ-02 style: the server decides
--                              which cell you are on from your root position).
--   * seeded randomness     -- the Playlist LCG, re-seeded per (session, round) so
--                              Studio and the offline proof draw the same layout.
--   * the round-token format -- one mint for twelve trials (MP-01 section 3, D11).

local TrialRules = {}

-- 1. ORDERING KEY BANDS -------------------------------------------------------
-- MachineFlow ranks the raw numbers a trial returns; only the ORDER matters.
-- A player who FINISHED always outranks one merely ALIVE at the deadline, who
-- always outranks one who is OUT. Detail inside a band is clamped to 0..999 so
-- no amount of in-band merit can cross into the band above.
TrialRules.BAND = { FINISHED = 2000, ALIVE = 1000, OUT = 0 }
TrialRules.BAND_WIDTH = 1000

function TrialRules.key(band, detail)
	local d = math.floor(tonumber(detail) or 0)
	if d < 0 then d = 0 end
	if d > TrialRules.BAND_WIDTH - 1 then d = TrialRules.BAND_WIDTH - 1 end
	return (tonumber(band) or 0) + d
end

-- 2. GRID ARITHMETIC ----------------------------------------------------------
-- A grid descriptor is plain numbers so it can be built and tested without
-- Vector3: { cols, rows, cell, gap, x0, z0 } where (x0, z0) is the CENTRE of the
-- grid on the XZ plane. Plates are `cell` wide with `gap` between them; a
-- position inside a gap belongs to no cell (returns nil), which is what makes
-- "you were between plates when it dropped" a legitimate death.
function TrialRules.newGrid(cols, rows, cell, gap, x0, z0)
	return {
		cols = cols, rows = rows, cell = cell, gap = gap or 0,
		x0 = x0 or 0, z0 = z0 or 0,
	}
end

-- Total span of the grid along one axis (n plates and n-1 gaps).
function TrialRules.gridSpan(n, cell, gap)
	return n * cell + (n - 1) * (gap or 0)
end

-- Centre of plate (c, r), 1-based; c runs along +X, r along +Z.
function TrialRules.cellCenter(g, c, r)
	local pitch = g.cell + g.gap
	local spanX = TrialRules.gridSpan(g.cols, g.cell, g.gap)
	local spanZ = TrialRules.gridSpan(g.rows, g.cell, g.gap)
	local x = g.x0 - spanX / 2 + (c - 1) * pitch + g.cell / 2
	local z = g.z0 - spanZ / 2 + (r - 1) * pitch + g.cell / 2
	return x, z
end

-- Which plate a world (x, z) is over: c, r  -- or nil when outside the grid or
-- inside a gap. Pure arithmetic, no Touched, no raycast.
function TrialRules.cellOf(g, x, z)
	local pitch = g.cell + g.gap
	local spanX = TrialRules.gridSpan(g.cols, g.cell, g.gap)
	local spanZ = TrialRules.gridSpan(g.rows, g.cell, g.gap)
	local lx = x - (g.x0 - spanX / 2)
	local lz = z - (g.z0 - spanZ / 2)
	if lx < 0 or lz < 0 or lx >= spanX or lz >= spanZ then return nil end
	local c = math.floor(lx / pitch) + 1
	local r = math.floor(lz / pitch) + 1
	-- Inside the gap after plate c / r?
	if lx - (c - 1) * pitch >= g.cell then return nil end
	if lz - (r - 1) * pitch >= g.cell then return nil end
	if c < 1 or c > g.cols or r < 1 or r > g.rows then return nil end
	return c, r
end

-- 3. SEEDED RANDOMNESS --------------------------------------------------------
-- The Playlist LCG (Numerical Recipes constants), restated here so a rules
-- module needs only TrialRules. Same generator, same high-bit draw, so a layout
-- generated in Studio and in `lua tests/<id>.lua` from one seed is identical.
function TrialRules.lcg(seed)
	local state = math.floor(tonumber(seed) or 0) % 4294967296
	if state < 0 then state = state + 4294967296 end
	return function(n)
		state = (1664525 * state + 1013904223) % 4294967296
		return (math.floor(state / 65536) % n) + 1
	end
end

-- djb2 over the bytes of a string, folded to 32 bits. Deterministic across
-- runtimes; used to turn "<sessionId>:<roundIndex>" into an LCG seed.
function TrialRules.hash(str)
	local h = 5381
	for i = 1, #str do
		h = (h * 33 + string.byte(str, i)) % 4294967296
	end
	return h
end

-- nextInt(n) -> 1..n, seeded from the session id and the round index, so two
-- rounds of one session never share a layout and a replayed session id does.
function TrialRules.rng(sessionId, roundIndex)
	return TrialRules.lcg(TrialRules.hash(tostring(sessionId) .. ":" .. tostring(roundIndex or 1)))
end

-- Fisher-Yates in place with an injected generator. Returns the same table.
function TrialRules.shuffle(list, nextInt)
	for i = #list, 2, -1 do
		local j = nextInt(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- 4. ROUND TOKEN --------------------------------------------------------------
-- D11: "<ID>-<sessionId>-R<roundIndex>-<ms % 100000>", the Minefield/Canteen
-- mint with the id in caps. `ms` is injected so this stays clock-free.
function TrialRules.token(trialId, sessionId, roundIndex, ms)
	return string.format("%s-%s-R%s-%d",
		string.upper(tostring(trialId)), tostring(sessionId), tostring(roundIndex or 1),
		math.floor(tonumber(ms) or 0) % 100000)
end

-- True when `token` has the shape token() produces for `trialId`.
function TrialRules.tokenMatches(token, trialId)
	if type(token) ~= "string" then return false end
	local prefix = string.upper(tostring(trialId)) .. "-"
	return string.sub(token, 1, #prefix) == prefix
		and string.find(token, "%-R%d+%-%d+$") ~= nil
end

-- 5. GEOMETRY HELPERS ---------------------------------------------------------
-- Axis-aligned bounds test on plain numbers; TrialKit's R:sample uses it for
-- the arena AABB clamp. `box` = { minX, maxX, minY, maxY, minZ, maxZ }.
function TrialRules.inBox(box, x, y, z)
	return x >= box[1] and x <= box[2]
		and y >= box[3] and y <= box[4]
		and z >= box[5] and z <= box[6]
end

-- Horizontal (XZ) distance -- the number every "within reach" check uses.
function TrialRules.flatDistance(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

return TrialRules
