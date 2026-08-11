-- Arena lifecycle: locate the model a minigame plays inside, put players in it,
-- and clean up whatever the minigame built.
--
-- Arenas are PRE-PLACED in Workspace.Arenas, not cloned in at round start.
-- Cloning a large model mid-round is the classic source of a visible hitch on
-- the exact frame players need to be reacting, and it fights StreamingEnabled.
-- Pre-placed arenas cost a little memory and buy a seamless transition.
--
-- ARENA CONVENTION (what to build in Studio)
--   Workspace
--     Arenas
--       lobby      (Model)  - Origin (Part, anchored, transparent)
--       recall     (Model)  - Origin
--       grate      (Model)  - Origin  <- pads are generated forward on +Z
--       line       (Model)  - Origin
--
-- Origin is an anchored, invisible, non-collidable Part. Its CFrame is the
-- arena's local space: minigames build relative to it, so you can move or
-- rotate a whole arena in Studio and nothing in code needs to change.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared").Config)

local ArenaService = {}

local ARENAS_NAME = "Arenas"

local function log(...)
	if Config.Verbose then
		print("[Arena]", ...)
	end
end

local function arenasFolder(): Folder
	local existing = workspace:FindFirstChild(ARENAS_NAME)
	if existing then
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = ARENAS_NAME
	folder.Parent = workspace
	return folder
end

-- Build a bare but *playable* arena when the real one has not been modelled
-- yet. This is deliberate: scripting must never be blocked waiting on art.
local function createPlaceholder(id: string, index: number): Model
	log(`arena "{id}" missing - generating placeholder`)

	local model = Instance.new("Model")
	model.Name = id

	local floor = Instance.new("Part")
	floor.Name = "PlaceholderFloor"
	floor.Size = Vector3.new(300, 4, 400)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(48, 48, 46)
	floor.Material = Enum.Material.Concrete
	floor.TopSurface = Enum.SurfaceType.Smooth
	-- Arenas are spaced far apart on X so their physics and streaming regions
	-- never overlap. 1000 studs is comfortably more than any arena needs.
	floor.CFrame = CFrame.new(index * 1000, 0, 0)
	floor.Parent = model

	local origin = Instance.new("Part")
	origin.Name = "Origin"
	origin.Size = Vector3.new(2, 2, 2)
	origin.Anchored = true
	origin.CanCollide = false
	origin.Transparency = 1
	origin.CFrame = floor.CFrame * CFrame.new(0, 2 + 1, -180)
	origin.Parent = model

	model.PrimaryPart = floor
	model.Parent = arenasFolder()
	return model
end

local placeholderIndex = 0

function ArenaService.getArena(id: string): Model
	local folder = arenasFolder()
	local existing = folder:FindFirstChild(id)
	if existing and existing:IsA("Model") then
		if not existing:FindFirstChild("Origin") then
			warn(`[Arena] "{id}" has no Origin part - minigames will build at the model pivot instead`)
		end
		return existing
	end

	placeholderIndex += 1
	return createPlaceholder(id, placeholderIndex)
end

function ArenaService.getOrigin(arena: Model): CFrame
	local origin = arena:FindFirstChild("Origin")
	if origin and origin:IsA("BasePart") then
		return origin.CFrame
	end
	return arena:GetPivot()
end

-- Everything a minigame creates goes under arena.Runtime, so cleanup is a
-- single Destroy and can never accidentally delete hand-built geometry.
function ArenaService.runtimeFolder(arena: Model): Folder
	local existing = arena:FindFirstChild("Runtime")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Runtime"
	folder.Parent = arena
	return folder
end

function ArenaService.clearRuntime(arena: Model)
	local existing = arena:FindFirstChild("Runtime")
	if existing then
		existing:Destroy()
	end
end

-- Place players in an arena. Spread across a line centred on the origin so 8
-- players never spawn inside one another.
function ArenaService.sendPlayers(players: { Player }, arena: Model, spacing: number?)
	local origin = ArenaService.getOrigin(arena)
	local gap = spacing or 8
	local count = #players

	for i, player in players do
		local character = player.Character
		if not character then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end

		local offset = (i - (count + 1) / 2) * gap
		root.CFrame = origin * CFrame.new(offset, 4, 0)

		-- Kill inherited velocity, otherwise players arrive already sliding.
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

-- Freeze / unfreeze for countdown and score phases. WalkSpeed alone is not
-- enough: a player mid-jump keeps their arc, so we pin JumpPower too.
function ArenaService.setFrozen(players: { Player }, frozen: boolean)
	for _, player in players do
		local character = player.Character
		if not character then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			continue
		end
		humanoid.WalkSpeed = if frozen then 0 else 16
		humanoid.JumpPower = if frozen then 0 else 50
		humanoid.AutoRotate = not frozen
	end
end

function ArenaService.alivePlayers(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			table.insert(out, player)
		end
	end
	return out
end

return ArenaService
