--!nonstrict
-- PODIUM (P1.3, 23.08.2026) -- the verdict's last beat: three anchored blocks,
-- the top three subjects standing on them, the winner lit, the losers' slots
-- dark, one fixed camera. Parts only, no art.
--
-- MachineFlow drives it: after the 6 s VIABLE/REJECTED stamp it calls raise()
-- with the final board, sends stage.packet to the room AND the bench, holds
-- Pacing.Timing.Podium, then strike() puts everything back -- characters
-- un-anchored and home at SpawnLocation (where TrialKit's own cleanup leaves
-- them, so the lobby that follows finds nothing different), the model gone.
--
-- Numbers (block offsets, heights, camera) live in Shared/Rules/MachineCam so
-- the offline proof sees the same layout this file builds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrialKit = require(script.Parent.TrialKit)

local Shared = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local AnimationIds = require(Shared:WaitForChild("Config"):WaitForChild("AnimationIds"))
local MachineCam = require(Shared:WaitForChild("Rules"):WaitForChild("MachineCam"))

local Podium = {}

local MODEL_NAME = "PodiumStage"
-- Clear of everything: existing content is X in [-290, 200] / Z in [-1950, 800],
-- the twelve procedural arenas X 1400..2400 / Z -900..900 (GameConfig.Arenas).
local DEFAULT_ORIGIN = Vector3.new(900, 0, 1500)

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

function Podium.origin()
	local origins = Config.Arenas and Config.Arenas.Origins
	local o = origins and origins.podium
	return typeof(o) == "Vector3" and o or DEFAULT_ORIGIN
end

-- STAGE -----------------------------------------------------------------------

local function rankStrip(block, place, lit, parent)
	-- A thin band across the front face of the block: neon on the winner's,
	-- dark on the others. The face toward the camera is +Z.
	local size = block.Size
	return TrialKit.part({
		name = "Rank" .. place,
		size = Vector3.new(size.X - 1, 0.6, 0.2),
		cf = block.CFrame * CFrame.new(0, size.Y / 2 - 0.8, size.Z / 2 + 0.1),
		color = lit and TrialKit.PALETTE.Sodium or TrialKit.PALETTE.Grime,
		neon = lit,
		canCollide = false, canQuery = false, canTouch = false,
		parent = parent,
	})
end

local function buildStage(origin)
	local L = MachineCam.PODIUM
	local model = Instance.new("Model")
	model.Name = MODEL_NAME

	TrialKit.part({
		name = "Slab", size = Vector3.new(L.slab.sizeX, 1, L.slab.sizeZ),
		pos = origin + Vector3.new(0, -0.5, 0), color = TrialKit.PALETTE.WetConcrete,
		parent = model,
	})
	TrialKit.part({
		name = "BackWall", size = Vector3.new(L.slab.sizeX, L.wall.height, L.wall.depth),
		pos = origin + Vector3.new(0, L.wall.height / 2, L.wall.z), color = TrialKit.PALETTE.Void,
		parent = model,
	})

	local blocks = {}
	for place = 1, 3 do
		local s = L.slots[place]
		local lit = place == 1
		local block = TrialKit.part({
			name = "Block" .. place,
			size = Vector3.new(s.size, s.height, s.size),
			pos = origin + Vector3.new(s.dx, s.height / 2, 0),
			color = lit and TrialKit.PALETTE.Steel or TrialKit.PALETTE.Void,
			parent = model,
		})
		rankStrip(block, place, lit, model)
		blocks[place] = block
	end

	-- One lamp over the winner; the other two slots get nothing, on purpose.
	local lampPost = TrialKit.marker("Lamp", CFrame.new(origin + Vector3.new(0, L.slots[1].height + 14, 4)), model)
	local lamp = Instance.new("PointLight")
	lamp.Brightness = 2.5
	lamp.Range = 30
	lamp.Color = TrialKit.PALETTE.Sodium
	lamp.Shadows = false
	lamp.Parent = lampPost

	local cam = MachineCam.podiumCamera(origin)
	TrialKit.marker("PodiumCamera", CFrame.lookAt(v3(cam.pos), v3(cam.look)), model)

	model.Parent = workspace
	return model, blocks
end

-- SUBJECTS ---------------------------------------------------------------------

local function living(userId)
	local plr = Players:GetPlayerByUserId(userId)
	local char = plr and plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if plr and char and hum and root and hum.Health > 0 then
		return { player = plr, char = char, hum = hum, root = root }
	end
	return nil
end

local function standOn(stage, row)
	local s = living(row.userId)
	if not s then return end
	local top = MachineCam.podiumSlotTop(stage.origin, row.slot or row.place)
	if not top then return end
	local y = top[2] + s.hum.HipHeight + s.root.Size.Y / 2
	local pos = Vector3.new(top[1], y, top[3])
	stage.restore[row.userId] = {
		char = s.char, hum = s.hum, root = s.root,
		anchored = s.root.Anchored, walk = s.hum.WalkSpeed,
	}
	s.hum.WalkSpeed = 0
	s.root.AssemblyLinearVelocity = Vector3.zero
	-- Face the camera (+Z).
	s.root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
	s.root.Anchored = true
	-- The rig stands in Idle. Server-played on the character's own Animator so
	-- every client sees the same clip (AnimationIds names it "Player/...", so
	-- the rig's PS1Animate filter lets it through); no Animator or an
	-- unpublished id degrades to no server clip - the rig's own PS1Animate is
	-- already holding Idle at speed 0, so the pose is the same either way.
	if s.char:GetAttribute("KenopsiaPS1") == true then
		local animator = s.hum:FindFirstChildOfClass("Animator")
		local track = AnimationIds.load(animator, "Player", "Idle")
		if track then
			track.Looped = true
			track:Play(0.1)
			stage.restore[row.userId].track = track
		end
	end
end

local function sendHome(s)
	local spawnPart = workspace:FindFirstChild("SpawnLocation")
	local home = spawnPart and spawnPart.Position or TrialKit.HOME_FALLBACK
	s.root.CFrame = CFrame.new(home + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
end

-- PUBLIC -----------------------------------------------------------------------

-- Builds the stage and stands the board's top three on it. Returns the stage
-- handle (pass it to strike) with `packet` ready to send. Never yields.
function Podium.raise(board, seconds)
	local old = workspace:FindFirstChild(MODEL_NAME)
	if old then old:Destroy() end
	local origin = Podium.origin()
	local model, blocks = buildStage(origin)
	local stage = { origin = origin, model = model, blocks = blocks, restore = {} }
	stage.packet = MachineCam.podiumPacket(origin, board, seconds)
	local occupied = 0
	for _, row in ipairs(stage.packet.rows) do
		local ok, err = pcall(standOn, stage, row)
		if not ok then
			warn(("[Podium] could not place %s: %s"):format(tostring(row.displayName), tostring(err)))
		elseif stage.restore[row.userId] then
			occupied += 1
		end
	end
	print(("[Podium] up at (%d, %d, %d): %d block(s) occupied"):format(origin.X, origin.Y, origin.Z, occupied))
	return stage
end

-- Idempotent teardown: clips stopped, roots un-anchored, subjects home, model gone.
function Podium.strike(stage)
	if not stage or stage.struck then return end
	stage.struck = true
	for _, r in pairs(stage.restore) do
		pcall(function()
			if r.track then r.track:Stop(0.1) end
			if r.root and r.root.Parent then
				r.root.Anchored = r.anchored == true
				sendHome(r)
			end
			if r.hum and r.hum.Parent then
				r.hum.WalkSpeed = r.walk or 0
			end
		end)
	end
	stage.restore = {}
	if stage.model then
		stage.model:Destroy()
		stage.model = nil
	end
end

return Podium
