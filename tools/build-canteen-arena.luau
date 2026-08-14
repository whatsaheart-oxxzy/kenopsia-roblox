--!nonstrict
-- CANTEEN PROTOCOL -- arena marker rig builder (Gate 4).
--
-- Run this in the Edit datamodel. It is IDEMPOTENT: it deletes and rebuilds
-- `Workspace.CanteenProtocol.Rig` every time, so re-running after the room is
-- rebuilt or rescaled regenerates correct markers instead of stale ones.
--
-- WHY A SCRIPT AND NOT HAND-PLACED PARTS: every position below is DERIVED from
-- the room geometry Tamem built -- the four chairs, the four plate cylinders,
-- the table bounding box. Hand-placed markers would silently rot the moment a
-- chair moves. This file is the source of truth; the markers are its output.
--
-- It touches NOTHING else in the room except anchoring (see ANCHOR_STRUCTURE),
-- and it wraps the whole build in one undo waypoint.

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local ROOT_NAME = "CanteenProtocol"
local RIG_NAME = "Rig"

-- Offsets, in studs, from a MEASURED surface. These are the only tunable
-- numbers in the file; everything else is geometry. Measured 2026: chair seat
-- surface Y = 9.71, plate surface Y = 13.60, table top ~13.5.
local SEAT_ROOT_ABOVE_SEAT = 2.6   -- HumanoidRootPart centre above the chair seat
local MOUTH_ABOVE_SEAT     = 4.6   -- mouth height above the chair seat
local FORK_ABOVE_PLATE     = 1.6   -- fork rest height above the plate surface
local FORK_TOWARD_SEAT     = 1.8   -- fork sits between plate and eater
-- Player camera clearance, measured from the CHAIR rather than the seat.
-- Fixed offsets from the seat put the camera inside the backrest: these chairs
-- are 16 studs tall and 8.8 deep, so "5 back, 3.2 up" landed the eye 0.6 studs
-- behind the back face and 1.5 studs BELOW the top of it -- looking through
-- solid wood. Deriving from the chair's own bounding box survives Tamem
-- swapping the chair model.
local CAM_ABOVE_CHAIR      = 1.8   -- above the chair's highest point
local CAM_BEHIND_CHAIR     = 3.0   -- clear of its back face
local MUZZLE_Y             = 30.0  -- ceiling-mounted execution muzzle
-- The Observer hangs over the CENTRE of the table, not past its head.
-- Measured: from the head of the table the angle between a seated player's
-- view direction and the Observer is ~57 degrees, which is outside a 70-degree
-- FOV. The Observer is the tell the entire minigame is played on -- a player
-- who cannot see it is guessing. Above the centre the angle drops to ~24.
local OBSERVER_ABOVE_TABLE = 7.0
local SPECTATOR_BACK       = 26.0
local SPECTATOR_UP         = 12.0

-- EVERYTHING in this room is anchored. The first pass anchored only the
-- structure and left 40 dressing parts dynamic in case they were intentional
-- physics props. Measured in a running server, they were not:
--   * Canteen_canned_food_3 sank to Y = 0.05, BELOW the floor top at 1.00
--   * Canteen_Mesh_Trolley_01 was still settling on a table after 4 s
--   * "Camera for Canteen" fell 24.5 studs, from Y = 26 to the floor
--   * 20 more rest on tables and shelves, asleep only until something nudges them
-- Nothing in this minigame touches a can, so dynamics here buy no gameplay and
-- cost a permanent physics simulation. Reversible in one line if Tamem ever
-- wants kickable props.
local ANCHOR_ALL = true

local root = workspace:FindFirstChild(ROOT_NAME)
assert(root, "Workspace." .. ROOT_NAME .. " not found")

local log = {}
local function note(fmt, ...)
	table.insert(log, string.format(fmt, ...))
end

local recording = ChangeHistoryService:TryBeginRecording("Build Canteen arena rig")

---------------------------------------------------------------------------
-- 1. Anchor the structure.
---------------------------------------------------------------------------
local anchored = 0
for _, d in ipairs(root:GetDescendants()) do
	if ANCHOR_ALL and d:IsA("BasePart") and not d.Anchored then
		d.Anchored = true
		anchored = anchored + 1
	end
end
note("anchored %d parts", anchored)

---------------------------------------------------------------------------
-- 2. Collect geometry.
---------------------------------------------------------------------------
local table3 = root:FindFirstChild("Canteen_table_large_3")
assert(table3, "big table 'Canteen_table_large_3' not found")
local tableCF, tableSize = table3:GetBoundingBox()
local tableTopY = tableCF.Position.Y + tableSize.Y / 2

-- Unique plate spots. There are 8 Plate parts on 4 positions (duplicates
-- stacked); dedupe by rounded XZ rather than addressing them by index, because
-- child order is not a contract.
local plateSpots, seenPlate = {}, {}
for _, c in ipairs(root:GetChildren()) do
	if c.Name == "Plate" and c:IsA("BasePart") then
		local key = string.format("%.0f_%.0f", c.Position.X, c.Position.Z)
		if not seenPlate[key] then
			seenPlate[key] = true
			-- Top surface, not centre: the cylinder lies flat (UpVector +X).
			table.insert(plateSpots, Vector3.new(c.Position.X, c.Position.Y + c.Size.X / 2, c.Position.Z))
		end
	end
end
assert(#plateSpots == 4, ("expected 4 unique plate spots, found %d"):format(#plateSpots))

-- The four chairs at the big table. Chairs elsewhere in the room are dressing;
-- select by proximity to the table rather than by a hardcoded X threshold.
local chairs = {}
for _, c in ipairs(root:GetChildren()) do
	if c.Name == "Canteen_chair_wooden_1" then
		local part = c:FindFirstChildWhichIsA("BasePart")
		if part then
			local d = (Vector3.new(part.Position.X, 0, part.Position.Z)
				- Vector3.new(tableCF.Position.X, 0, tableCF.Position.Z)).Magnitude
			table.insert(chairs, { part = part, dist = d })
		end
	end
end
table.sort(chairs, function(a, b) return a.dist < b.dist end)
assert(#chairs >= 4, ("expected at least 4 chairs, found %d"):format(#chairs))
while #chairs > 4 do
	table.remove(chairs)
end

-- Seat surface by raycast: the chair mesh height is not a constant we should
-- assume, and a raycast survives the user swapping the chair model.
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { root }

local seats = {}
for _, entry in ipairs(chairs) do
	local pos = entry.part.Position
	local hit = workspace:Raycast(Vector3.new(pos.X, pos.Y + 12, pos.Z), Vector3.new(0, -24, 0), rp)
	local seatY = hit and hit.Position.Y or (pos.Y + entry.part.Size.Y * 0.28)
	local size = entry.part.Size
	table.insert(seats, {
		x = pos.X, z = pos.Z, seatY = seatY,
		-- The chair's own extents, so the camera can be placed clear of it.
		-- max(X, Z) rather than the axis along `facing`: it is the conservative
		-- one and does not depend on how the chair model happens to be rotated.
		chairTop = pos.Y + size.Y / 2,
		chairHalfDepth = math.max(size.X, size.Z) / 2,
	})
end

-- Deterministic P1..P4: sort by Z then X. Child order in the DataModel is not
-- stable across edits, so seat numbering must come from geometry.
table.sort(seats, function(a, b)
	if math.abs(a.z - b.z) > 0.5 then return a.z < b.z end
	return a.x < b.x
end)

-- Pair each seat with its nearest plate, and prove the pairing is a bijection.
local usedPlate = {}
for i, s in ipairs(seats) do
	local best, bestD
	for pi, p in ipairs(plateSpots) do
		if not usedPlate[pi] then
			local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(s.x, 0, s.z)).Magnitude
			if not bestD or d < bestD then
				best, bestD = pi, d
			end
		end
	end
	assert(best, ("seat P%d found no free plate"):format(i))
	usedPlate[best] = true
	s.plate = plateSpots[best]
	s.plateDist = bestD
end

---------------------------------------------------------------------------
-- 3. Build the rig.
---------------------------------------------------------------------------
local old = root:FindFirstChild(RIG_NAME)
if old then
	old:Destroy()
end

local rig = Instance.new("Folder")
rig.Name = RIG_NAME

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = rig
	return f
end

-- Markers are invisible, collisionless and INVISIBLE TO RAYCASTS. CanQuery
-- matters: a marker that answers a raycast would silently poison the observer's
-- line of sight and every future hit test in this arena.
local function marker(name, cf, parent, seatIndex)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.6, 0.6, 0.6)
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if seatIndex then
		p:SetAttribute("SeatIndex", seatIndex)
	end
	p.Parent = parent
	return p
end

local fSeats = folder("Seats")
local fPlates = folder("PlateAnchors")
local fForks = folder("ForkAnchors")
local fMouths = folder("MouthTargets")
local fCams = folder("PlayerCameras")
local fMuzzles = folder("ExecutionMuzzles")

for i, s in ipairs(seats) do
	local id = "P" .. i
	local seatXZ = Vector3.new(s.x, 0, s.z)
	local plateXZ = Vector3.new(s.plate.X, 0, s.plate.Z)
	-- Facing is derived, never assumed: the seat looks at its own plate.
	local facing = (plateXZ - seatXZ).Unit

	local seatPos = Vector3.new(s.x, s.seatY + SEAT_ROOT_ABOVE_SEAT, s.z)
	marker(id, CFrame.lookAt(seatPos, seatPos + facing), fSeats, i)

	marker(id, CFrame.lookAt(s.plate, s.plate - facing), fPlates, i)

	local forkPos = s.plate + Vector3.new(0, FORK_ABOVE_PLATE, 0) - facing * FORK_TOWARD_SEAT
	marker(id, CFrame.lookAt(forkPos, forkPos - facing), fForks, i)

	local mouthPos = Vector3.new(s.x, s.seatY + MOUTH_ABOVE_SEAT, s.z) + facing * 0.6
	marker(id, CFrame.lookAt(mouthPos, mouthPos + facing), fMouths, i)

	local camPos = Vector3.new(s.x, s.chairTop + CAM_ABOVE_CHAIR, s.z)
		- facing * (s.chairHalfDepth + CAM_BEHIND_CHAIR)
	marker(id, CFrame.lookAt(camPos, s.plate), fCams, i)

	-- Straight down. The explicit up vector is REQUIRED, not decorative:
	-- CFrame.lookAt defaults up to (0,1,0), and a look direction parallel to up
	-- is degenerate -- it yields a CFrame full of NaN. `facing` is horizontal by
	-- construction, so it is always a valid up reference here.
	local muzzlePos = Vector3.new(s.x, MUZZLE_Y, s.z)
	marker(id, CFrame.lookAt(muzzlePos, muzzlePos - Vector3.new(0, 1, 0), facing), fMuzzles, i)

	note("P%d seat=(%.1f, %.2f, %.1f) plate d=%.1f facing=(%.2f, %.2f)",
		i, s.x, s.seatY, s.z, s.plateDist, facing.X, facing.Z)
end

-- Observer: directly above the centre of the table, looking straight down at
-- it. Equidistant from all four seats and inside every one of their view cones.
local tc = tableCF.Position
local longAxis = (tableSize.X >= tableSize.Z) and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
local obsPos = Vector3.new(tc.X, tableTopY + OBSERVER_ABOVE_TABLE, tc.Z)
local obsLook = Vector3.new(tc.X, tableTopY, tc.Z)

-- HORIZONTAL look, world up. This frame hosts an authored CP_Observer, and an
-- authored Observer is a FIGURE -- something that hangs upright.
--
-- lookAt derives local +Y from the part of `up` perpendicular to the look
-- direction, so a look tilted down by an angle tilts the whole model back by
-- that same angle. The previous straight-down look therefore put local +Y along
-- world +X: a figure modelled upright in Blender would have come out lying on
-- its side. Any head tilt belongs in the model, where an artist can see it, not
-- baked into the marker where it silently rotates everything else too.
--
-- The long axis is horizontal by construction, so this is also free of the
-- degenerate parallel-to-up case that the execution muzzles hit.
marker("Observer", CFrame.lookAt(obsPos, obsPos + longAxis, Vector3.yAxis), rig)

-- ObserverCamera: Tamem placed "Camera for Canteen" by hand -- honour that
-- POSITION, but compute the direction, because the part's stored rotation does
-- not point at the table.
local handCam = root:FindFirstChild("Camera for Canteen")
local obsCamPos = handCam and handCam.Position or (obsPos + Vector3.new(0, 2, 0))
marker("ObserverCamera", CFrame.lookAt(obsCamPos, obsLook), rig)

local specPos = Vector3.new(tc.X, tableTopY + SPECTATOR_UP, tc.Z)
	+ Vector3.new(0, 0, 1) * SPECTATOR_BACK
marker("SpectatorCamera", CFrame.lookAt(specPos, obsLook), rig)

rig.Parent = root

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

note("table top Y=%.2f  bbox=(%.1f, %.1f, %.1f)", tableTopY, tableSize.X, tableSize.Y, tableSize.Z)

-- Count the parts, not "descendants minus children": that arithmetic silently
-- omitted the three standalone markers (Observer / ObserverCamera /
-- SpectatorCamera) and under-reported 27 as 24.
local markerCount = 0
for _, d in ipairs(rig:GetDescendants()) do
	if d:IsA("BasePart") then
		markerCount = markerCount + 1
	end
end
note("rig built: %d markers", markerCount)
return table.concat(log, "\n")
