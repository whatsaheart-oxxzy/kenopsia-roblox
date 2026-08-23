--!nonstrict
-- MACHINE CAMERAS (P1.3 podium + P1.7 audience camera, 23.08.2026) -- the two
-- fixed cameras the Machine itself owns, and the wire shape of their packets.
--
-- PURE and Lua-5.1 portable (see the header of Rules/Pacing.luau for the rule):
-- no Vector3, no CFrame, no services. Positions travel as {x, y, z} arrays, the
-- same shape the legacy `role spectate` packet uses (pos/look), so the client
-- builds one CFrame.lookAt from either. tests/machinecam.lua proves the shapes
-- here; tests/envelope.lua proves they fit the Envelope limits.
--
-- Packets (server -> client over MachineState, never FireAllClients):
--   { kind="podium", cam={pos={x,y,z}, look={x,y,z}}, rows={{place, userId,
--     displayName, score}...}, seconds=8 }      -- the stage is up
--   { kind="podium" }                            -- the stage is struck
--   { kind="audiencecam", cf={pos={x,y,z}, look={x,y,z}}, trialId }
--                                                -- a trial runs; bench watches
--   { kind="audiencecam" }                       -- the trial ended
-- A packet WITHOUT its camera field is the clear. The client treats both kinds
-- as "the Machine owns the camera" and releases it on the clear.

local MachineCam = {}

-- PODIUM LAYOUT (studs, relative to the stage origin; floor top = origin.y).
-- Three blocks on one slab, winner in the middle and highest; the camera sits
-- in front (+Z) and slightly above, looking at the winner's chest height.
-- Podium.luau turns these numbers into parts; the client never needs them.
MachineCam.PODIUM = {
	slab = { sizeX = 40, sizeZ = 24 },
	wall = { height = 14, depth = 1, z = -9 },
	slots = {
		[1] = { dx = 0, height = 6, size = 6 },
		[2] = { dx = -8, height = 4, size = 6 },
		[3] = { dx = 8, height = 2.5, size = 6 },
	},
	-- 22 studs out, 8 up, aimed at the winner's waist: a 7.8-stud rig on the
	-- 6-stud block tops out at ~14, inside the 70-degree vertical field (+-15).
	cam = { dx = 0, dy = 8, dz = 22, lx = 0, ly = 5, lz = 0 },
	seconds = 8,
}

MachineCam.MAX_ROWS = 3
MachineCam.NAME_LENGTH = 20

local function point(x, y, z)
	return { x, y, z }
end

-- {x,y,z} from anything vector-shaped (Vector3, {X=,Y=,Z=}) or an array.
function MachineCam.xyz(v)
	if type(v) == "table" and v[1] ~= nil then
		return point(v[1], v[2], v[3])
	end
	return point(v.X, v.Y, v.Z)
end

-- Camera eye and look target for a stage at `origin` ({x,y,z} or vector-shaped).
function MachineCam.podiumCamera(origin)
	local o = MachineCam.xyz(origin)
	local c = MachineCam.PODIUM.cam
	return {
		pos = point(o[1] + c.dx, o[2] + c.dy, o[3] + c.dz),
		look = point(o[1] + c.lx, o[2] + c.ly, o[3] + c.lz),
	}
end

-- Where slot `place` (1..3) stands: the top centre of its block, {x,y,z}.
function MachineCam.podiumSlotTop(origin, place)
	local o = MachineCam.xyz(origin)
	local s = MachineCam.PODIUM.slots[place]
	if not s then return nil end
	return point(o[1] + s.dx, o[2] + s.height, o[3])
end

-- The rows that stand on the blocks: the final board's first three entries in
-- board order (the board is already sorted best first). `slot` is the block
-- (1..3, one body per block); `place` is the rank for the caption and, like
-- the verdict, SHARES a tied score (two subjects on 3400 are both 1ST -- the
-- final board just called them both VIABLE, the podium must not contradict
-- it). An explicit e.place from Scoring wins. Names are clipped to NAME_LENGTH
-- so the packet stays under the Envelope string cap.
function MachineCam.podiumRows(board)
	local rows = {}
	local prevScore, prevPlace = nil, nil
	for i, e in ipairs(board or {}) do
		if #rows >= MachineCam.MAX_ROWS then break end
		local name = tostring(e.displayName or e.userId or "?")
		local score = e.score or 0
		local place = e.place
		if place == nil then
			place = (prevScore ~= nil and score == prevScore) and prevPlace or i
		end
		prevScore, prevPlace = score, place
		rows[#rows + 1] = {
			slot = i,
			place = place,
			userId = e.userId,
			displayName = string.sub(name, 1, MachineCam.NAME_LENGTH),
			score = score,
		}
	end
	return rows
end

function MachineCam.podiumPacket(origin, board, seconds)
	return {
		kind = "podium",
		cam = MachineCam.podiumCamera(origin),
		rows = MachineCam.podiumRows(board),
		seconds = seconds or MachineCam.PODIUM.seconds,
	}
end

-- The bench's view of a running trial. eye/look are vector-shaped or arrays.
function MachineCam.audiencePacket(trialId, eye, look)
	return {
		kind = "audiencecam",
		trialId = trialId,
		cf = { pos = MachineCam.xyz(eye), look = MachineCam.xyz(look) },
	}
end

-- The clear for either kind: the same kind, no camera field.
function MachineCam.clearPacket(kind)
	return { kind = kind }
end

-- Client-side decode: the {pos, look} pair of a packet, or nil when the packet
-- is a clear or malformed (every component must be a finite number).
local function finite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function triple(t)
	if type(t) ~= "table" then return nil end
	if not (finite(t[1]) and finite(t[2]) and finite(t[3])) then return nil end
	return point(t[1], t[2], t[3])
end

function MachineCam.read(p)
	if type(p) ~= "table" then return nil end
	local cam = p.cam or p.cf
	if type(cam) ~= "table" then return nil end
	local pos, look = triple(cam.pos), triple(cam.look)
	if not (pos and look) then return nil end
	-- A zero-length look axis would make CFrame.lookAt NaN out.
	if pos[1] == look[1] and pos[2] == look[2] and pos[3] == look[3] then return nil end
	return pos, look
end

return MachineCam
