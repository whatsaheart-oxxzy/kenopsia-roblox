--!nonstrict
-- AUDIENCE CAMERA (P1.7, 23.08.2026) -- what the bench watches while a trial
-- runs. One fixed vantage point per trial, resolved from the live arena at the
-- moment it is asked for (the canteen was re-scaled after the place docs were
-- written, so nothing here is a hard-coded world coordinate except the offsets).
--
--   canteen    Rig.ObserverCamera, the same eye every diner's death cam uses
--   minefield  above and behind `Cameraplacement`, down the corridor to `Exit`
--   birdhunt   above the wall behind `Start`, down the lane to `Exit`
--   <kit id>   high, tilted view over the TrialKit arena at its origin
--
-- MachineFlow sends the packet to room.spectators when the Trial stage begins,
-- to a late joiner the moment it seats them on the bench mid-trial, and the
-- clear when the trial ends or the session dies (MachineCam.clearPacket).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrialKit = require(script.Parent.TrialKit)

local Shared = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local MachineCam = require(Shared:WaitForChild("Rules"):WaitForChild("MachineCam"))

local AudienceCam = {}

local function part(folder, name)
	local p = folder and folder:FindFirstChild(name)
	return (p and p:IsA("BasePart")) and p or nil
end

local resolvers = {}

function resolvers.canteen()
	local root = workspace:FindFirstChild("CanteenProtocol")
	local cam = part(root and root:FindFirstChild("Rig"), "ObserverCamera")
	if not cam then return nil end
	local eye = cam.CFrame
	return eye.Position, eye.Position + eye.LookVector * 10
end

function resolvers.minefield()
	local dz = workspace:FindFirstChild("Dead Zone")
	local cam, exit, mines = part(dz, "Cameraplacement"), part(dz, "Exit"), part(dz, "MineStartpoint")
	if not (cam and exit) then return nil end
	-- Up and back from the death cam, looking at the middle of the minefield.
	local eye = cam.Position + Vector3.new(0, 28, 30)
	local mid = mines and (mines.Position + exit.Position) / 2 or exit.Position
	return eye, Vector3.new(mid.X, exit.Position.Y + 2, mid.Z)
end

function resolvers.birdhunt()
	local bh = workspace:FindFirstChild("Bird Hunting")
	local start, exit = part(bh, "Start"), part(bh, "Exit")
	if not (start and exit) then return nil end
	-- Above the 42-stud wall behind the start line, down the lane.
	local eye = start.Position + Vector3.new(0, 60, -20)
	local mid = (start.Position + exit.Position) / 2
	return eye, Vector3.new(mid.X, start.Position.Y + 2, mid.Z)
end

local function kitArena(trialId)
	local refs = TrialKit.arenaRefs(trialId)
	local origins = Config.Arenas and Config.Arenas.Origins
	local origin = (refs and refs.origin) or (origins and origins[trialId])
	if typeof(origin) ~= "Vector3" then return nil end
	local span = (Config.Arenas and Config.Arenas.MaxFootprint) or 200
	return origin + Vector3.new(0, span * 0.45, span * 0.6), origin + Vector3.new(0, 4, 0)
end

-- eye, look (Vector3) for a trial, or nil when its arena is not in the world.
function AudienceCam.resolve(trialId)
	if type(trialId) ~= "string" or trialId == "" then return nil end
	local fn = resolvers[trialId]
	local ok, eye, look
	if fn then
		ok, eye, look = pcall(fn)
	else
		ok, eye, look = pcall(kitArena, trialId)
	end
	if not ok then
		warn(("[AudienceCam] %s: %s"):format(trialId, tostring(eye)))
		return nil
	end
	if not (eye and look) then return nil end
	return eye, look
end

-- The packet for a trial, or nil.
function AudienceCam.packetFor(trialId)
	local eye, look = AudienceCam.resolve(trialId)
	if not eye then return nil end
	return MachineCam.audiencePacket(trialId, eye, look)
end

function AudienceCam.clearPacket()
	return MachineCam.clearPacket("audiencecam")
end

return AudienceCam
