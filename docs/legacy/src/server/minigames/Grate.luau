-- THE GRATE - cross the floor. Most of it is not floor.
--
-- The Machine flashes the safe path for a couple of seconds, then goes dark.
-- Step wrong and you are out for the round, and the pad you died on lights up
-- red for everybody. Watching someone else find a bad tile is the best
-- information in the game, which is what makes 8 players funnier than 2.
--
-- WHY NOT .Touched: Touched drops contacts for fast-moving characters and fires
-- from the client's physics simulation, so a player who owns their own character
-- can influence when it fires. We sample authoritative positions on a fixed
-- server tick instead and convert to a grid cell with plain arithmetic - O(1)
-- per player, no spatial query, and nothing the client can lie about beyond
-- their position, which the server already validates elsewhere.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local ArenaService = require(script.Parent.Parent.ArenaService)

local GrateReveal = Net.get("GrateReveal")

local Grate = {}

Grate.Id = "grate"
Grate.DisplayName = "CROSS"
Grate.Verb = "CROSS"
Grate.Duration = Config.Grate.PlayTime
Grate.MinPlayers = 1

-- Round state ---------------------------------------------------------------

local cfg = Config.Grate
local pitch = cfg.PadSize.X + cfg.PadGap

local safe: { [number]: boolean } = {} -- padIndex -> is safe
local pads: { [number]: BasePart } = {}
local revealed: { [number]: boolean } = {}
local truePath: { number } = {} -- row -> column

local originCF: CFrame = CFrame.identity
local runtime: Folder? = nil
local competitors: { Player } = {}
local furthestRow: { [Player]: number } = {}
local eliminated: { [Player]: boolean } = {}
local finished: { [Player]: boolean } = {}

local pollConn: RBXScriptConnection? = nil
local flashThread: thread? = nil
local accumulator = 0
local running = false

local function log(...)
	if Config.Verbose then
		print("[Grate]", ...)
	end
end

local function padIndex(row: number, col: number): number
	return (row - 1) * cfg.Width + col
end

local function padCFrame(row: number, col: number): CFrame
	local x = (col - (cfg.Width + 1) / 2) * pitch
	local z = (row - 0.5) * pitch
	return originCF * CFrame.new(x, 0, z)
end

-- World position -> grid cell. Returns nil when the player is off the grid.
local function cellAt(position: Vector3): (number?, number?)
	local localPos = originCF:PointToObjectSpace(position)

	-- Reject players who are above the grid but not standing on it (mid-jump
	-- from a ledge, or falling past it) so a leap cannot skip a bad pad.
	if localPos.Y < -6 or localPos.Y > 12 then
		return nil, nil
	end

	local col = math.floor(localPos.X / pitch + (cfg.Width + 1) / 2 + 0.5)
	local row = math.floor(localPos.Z / pitch) + 1

	if col < 1 or col > cfg.Width or row < 1 or row > cfg.Length then
		return nil, nil
	end
	return row, col
end

function Grate:Setup(ctx)
	local rng = Random.new(ctx.seed)
	local arena = ctx.arena

	competitors = ctx.players
	furthestRow = {}
	eliminated = {}
	finished = {}
	revealed = {}
	safe = {}
	pads = {}
	truePath = {}
	accumulator = 0
	running = false

	originCF = ArenaService.getOrigin(arena)
	runtime = ArenaService.runtimeFolder(arena)

	-- Generate the true path as a forward random walk. Lateral movement is
	-- clamped to +/-1 per row, which guarantees every row is reachable from the
	-- one before it - the path can never require a diagonal leap.
	local col = rng:NextInteger(1, cfg.Width)
	for row = 1, cfg.Length do
		truePath[row] = col
		safe[padIndex(row, col)] = true
		col = math.clamp(col + rng:NextInteger(-1, 1), 1, cfg.Width)
	end

	-- Extra safe pads per row. These are mercy tiles for players who lost the
	-- path: they might save you, or they might dead-end into a wall of red.
	for row = 1, cfg.Length do
		for _ = 2, cfg.SafePerRow do
			local extra = rng:NextInteger(1, cfg.Width)
			safe[padIndex(row, extra)] = true
		end
	end

	-- Build the pads.
	for row = 1, cfg.Length do
		for c = 1, cfg.Width do
			local pad = Instance.new("Part")
			pad.Name = `Pad_{row}_{c}`
			pad.Size = cfg.PadSize
			pad.Anchored = true
			pad.CanCollide = true
			pad.Material = Enum.Material.DiamondPlate
			pad.Color = Config.Colors.PadNeutral
			pad.TopSurface = Enum.SurfaceType.Smooth
			pad.BottomSurface = Enum.SurfaceType.Smooth
			pad.CFrame = padCFrame(row, c)
			pad.Parent = runtime
			pads[padIndex(row, c)] = pad
		end
	end

	log(`built {cfg.Width}x{cfg.Length} grid, seed {ctx.seed}`)
end

local function revealPad(index: number, isSafe: boolean)
	if revealed[index] then
		return
	end
	revealed[index] = true

	local pad = pads[index]
	if pad then
		pad.Color = if isSafe then Config.Colors.PadSafe else Config.Colors.PadUnsafe
		pad.Material = if isSafe then Enum.Material.DiamondPlate else Enum.Material.CrackedLava
		if not isSafe then
			-- Drop the bad pad slightly so the failed route stays readable from
			-- across the arena even after the colour is lost in the fog.
			pad.CFrame = pad.CFrame * CFrame.new(0, -0.4, 0)
		end
	end

	GrateReveal:FireAllClients(index, isSafe)
end

local function eliminate(player: Player)
	if eliminated[player] then
		return
	end
	eliminated[player] = true

	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if root and root:IsA("BasePart") then
		-- Park them beside the grid rather than killing them: respawning mid-round
		-- fights the round state machine and costs a character reload.
		local sideX = (cfg.Width / 2 + 3) * pitch
		root.CFrame = originCF * CFrame.new(sideX, 6, cfg.Length * pitch * 0.5)
		root.AssemblyLinearVelocity = Vector3.zero
	end
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end

	log(`{player.Name} eliminated at row {furthestRow[player] or 0}`)
end

local function tick()
	for _, player in competitors do
		if eliminated[player] or finished[player] then
			continue
		end
		local character = player.Character
		if not character then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end

		local row, col = cellAt(root.Position)
		if not row or not col then
			continue
		end

		local index = padIndex(row, col)
		local isSafe = safe[index] == true

		revealPad(index, isSafe)

		if not isSafe then
			eliminate(player)
			continue
		end

		if row > (furthestRow[player] or 0) then
			furthestRow[player] = row
		end
		if row >= cfg.Length then
			finished[player] = true
			log(`{player.Name} finished`)
		end
	end
end

function Grate:Start()
	running = true

	-- Flash the true path, then go dark. This is the memory test.
	if cfg.FlashTime > 0 then
		for row, col in truePath do
			local pad = pads[padIndex(row, col)]
			if pad then
				pad.Color = Config.Colors.PadFlash
				pad.Material = Enum.Material.Neon
			end
		end
		flashThread = task.delay(cfg.FlashTime, function()
			for row, col in truePath do
				local pad = pads[padIndex(row, col)]
				if pad and not revealed[padIndex(row, col)] then
					pad.Color = Config.Colors.PadNeutral
					pad.Material = Enum.Material.DiamondPlate
				end
			end
		end)
	end

	local step = 1 / cfg.PollRate
	pollConn = RunService.Heartbeat:Connect(function(dt)
		if not running then
			return
		end
		accumulator += dt
		while accumulator >= step do
			accumulator -= step
			tick()
		end
	end)
end

function Grate:Stop()
	running = false

	local result: { [Player]: number } = {}
	for _, player in competitors do
		local rows = furthestRow[player] or 0
		local score = rows * Config.Score.GratePerRow
		if finished[player] then
			score += Config.Score.GrateFinishBonus
		end
		result[player] = score
	end
	return result
end

function Grate:Cleanup()
	running = false
	if pollConn then
		pollConn:Disconnect()
		pollConn = nil
	end
	if flashThread then
		task.cancel(flashThread)
		flashThread = nil
	end

	-- Restore anyone we froze; the round machine unfreezes survivors but not
	-- players we parked, and a permanently frozen player is a match-ruining bug.
	for player in eliminated do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
		end
	end

	pads = {}
	safe = {}
	revealed = {}
	truePath = {}
	competitors = {}
	furthestRow = {}
	eliminated = {}
	finished = {}
	runtime = nil
end

return Grate
