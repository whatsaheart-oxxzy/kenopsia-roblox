-- P1.3 / P1.7 offline proof: the Machine's fixed cameras (podium + audience).
--
--     lua tests/machinecam.lua
--
-- Loads the SHIPPED Shared/Rules/MachineCam.luau (Lua-5.1 portable, see the
-- header of Rules/Pacing.luau). What is proved here: the podium packet carries
-- exactly the top three of a final board with their places, the camera and
-- slot maths follow the layout table, the audience packet has the shape the
-- client reads, and the client-side decoder rejects clears and bad numbers.

local ROOT = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"

local function loadModule(file, parent)
	local chunk = assert(loadfile(ROOT .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local MachineCam = loadModule("MachineCam.luau")

local failures, checks = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
	end
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- LAYOUT ----------------------------------------------------------------------

print("\nMACHINECAM -- podium layout")

local L = MachineCam.PODIUM
check(L.slots[1] and L.slots[2] and L.slots[3] and L.slots[4] == nil, "exactly three slots")
check(L.slots[1].height > L.slots[2].height and L.slots[2].height > L.slots[3].height,
	"1st block is the highest, 3rd the lowest")
check(L.slots[1].dx == 0 and L.slots[2].dx < 0 and L.slots[3].dx > 0, "winner in the middle, 2nd left, 3rd right")
check(L.cam.dz > 0 and L.cam.dy > 0, "camera sits in front (+Z) and above the stage")
check(L.seconds == 8, "podium beat is 8 s (MASTERPLAN section 2)")

local ORIGIN = { X = 900, Y = 0, Z = 1500 } -- vector-shaped, like GameConfig's Vector3
local cam = MachineCam.podiumCamera(ORIGIN)
check(near(cam.pos[1], 900 + L.cam.dx) and near(cam.pos[2], L.cam.dy) and near(cam.pos[3], 1500 + L.cam.dz),
	"camera eye = origin + cam offset")
check(near(cam.look[1], 900 + L.cam.lx) and near(cam.look[2], L.cam.ly) and near(cam.look[3], 1500 + L.cam.lz),
	"camera look = origin + look offset")
local camArr = MachineCam.podiumCamera({ 900, 0, 1500 })
check(near(camArr.pos[3], cam.pos[3]) and near(camArr.look[2], cam.look[2]), "array origin gives the same camera")

local top1 = MachineCam.podiumSlotTop(ORIGIN, 1)
local top3 = MachineCam.podiumSlotTop(ORIGIN, 3)
check(near(top1[1], 900) and near(top1[2], L.slots[1].height) and near(top1[3], 1500), "slot 1 top is on the block")
check(near(top3[1], 900 + L.slots[3].dx) and near(top3[2], L.slots[3].height), "slot 3 top follows its offset")
check(MachineCam.podiumSlotTop(ORIGIN, 4) == nil, "no 4th slot")

-- ROWS ------------------------------------------------------------------------

print("\nMACHINECAM -- podium rows from the final board")

local board = {
	{ userId = 11, displayName = "ALICE", score = 3400, verdict = "VIABLE" },
	{ userId = 22, displayName = "BOB", score = 2100, verdict = "REJECTED" },
	{ userId = 33, displayName = "A_VERY_LONG_DISPLAY_NAME_INDEED", score = 900, verdict = "REJECTED" },
	{ userId = 44, displayName = "DAVE", score = 100, verdict = "REJECTED" },
}
local rows = MachineCam.podiumRows(board)
check(#rows == 3, "four subjects -> three rows", tostring(#rows))
check(rows[1].userId == 11 and rows[2].userId == 22 and rows[3].userId == 33, "rows are the board's first three")
check(rows[1].place == 1 and rows[2].place == 2 and rows[3].place == 3, "place falls back to board position")
check(rows[1].slot == 1 and rows[2].slot == 2 and rows[3].slot == 3, "slot is the block: one body per block")
check(#rows[3].displayName <= MachineCam.NAME_LENGTH, "long names are clipped", rows[3].displayName)
check(rows[1].score == 3400 and rows[1].displayName == "ALICE", "row keeps name and score")

local placed = MachineCam.podiumRows({
	{ userId = 1, displayName = "X", place = 1, score = 5 },
	{ userId = 2, displayName = "Y", place = 1, score = 5 },
})
check(#placed == 2 and placed[2].place == 1 and placed[2].slot == 2, "an explicit place (shared 1st) is kept, slots still distinct")
local tied = MachineCam.podiumRows({
	{ userId = 1, displayName = "X", score = 3400 },
	{ userId = 2, displayName = "Y", score = 3400 },
	{ userId = 3, displayName = "Z", score = 900 },
})
check(tied[1].place == 1 and tied[2].place == 1 and tied[3].place == 3,
	"a tied top score shares 1ST like the verdict (1, 1, 3)")
check(tied[1].slot == 1 and tied[2].slot == 2 and tied[3].slot == 3, "tied subjects still get their own blocks")
check(#MachineCam.podiumRows({}) == 0 and #MachineCam.podiumRows(nil) == 0, "empty / nil board -> no rows")
local noName = MachineCam.podiumRows({ { userId = 7, score = 1 } })
check(noName[1].displayName == "7", "missing displayName falls back to the userId")

-- PACKETS ---------------------------------------------------------------------

print("\nMACHINECAM -- packets")

local pk = MachineCam.podiumPacket(ORIGIN, board)
check(pk.kind == "podium" and pk.seconds == 8, "podium packet kind + default seconds")
check(pk.cam and pk.cam.pos and pk.cam.look and #pk.rows == 3, "podium packet carries cam and rows")
check(MachineCam.podiumPacket(ORIGIN, board, 5).seconds == 5, "seconds override")

local ap = MachineCam.audiencePacket("canteen", { X = -63, Y = 26, Z = -5.4 }, { X = -73, Y = 26, Z = -5.4 })
check(ap.kind == "audiencecam" and ap.trialId == "canteen", "audience packet kind + trialId")
check(ap.cf and near(ap.cf.pos[1], -63) and near(ap.cf.look[1], -73), "audience packet cf = {pos, look}")

local clr = MachineCam.clearPacket("audiencecam")
check(clr.kind == "audiencecam" and clr.cf == nil and clr.cam == nil, "clear packet has no camera field")

-- DECODE (client side) --------------------------------------------------------

print("\nMACHINECAM -- read")

local pos, look = MachineCam.read(pk)
check(pos and look and near(pos[3], 1500 + L.cam.dz) and near(look[2], L.cam.ly), "read decodes a podium packet (cam)")
pos, look = MachineCam.read(ap)
check(pos and look and near(pos[1], -63) and near(look[1], -73), "read decodes an audience packet (cf)")
check(MachineCam.read(clr) == nil, "read returns nil for a clear")
check(MachineCam.read(MachineCam.clearPacket("podium")) == nil, "read returns nil for a podium clear")
check(MachineCam.read("nope") == nil and MachineCam.read(nil) == nil, "read survives non-tables")
check(MachineCam.read({ kind = "podium", cam = { pos = { 1, 0 / 0, 3 }, look = { 0, 0, 0 } } }) == nil,
	"NaN component rejected")
check(MachineCam.read({ kind = "podium", cam = { pos = { 1, math.huge, 3 }, look = { 0, 0, 0 } } }) == nil,
	"infinite component rejected")
check(MachineCam.read({ kind = "podium", cam = { pos = { 1, 2, 3 }, look = { 1, 2, 3 } } }) == nil,
	"eye == look rejected (lookAt would be degenerate)")
check(MachineCam.read({ kind = "podium", cam = { pos = { 1, 2 }, look = { 0, 0, 0 } } }) == nil,
	"short triple rejected")

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("MACHINECAM PROOF: FAIL")
	os.exit(1)
end
print("MACHINECAM PROOF: PASS")
os.exit(0)
