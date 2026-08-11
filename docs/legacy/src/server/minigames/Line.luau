-- THE LINE - the Machine wants five things. There is exactly one of each.
--
-- This is the signature minigame: it is the only one where players directly
-- take something from each other. Scarcity is the entire design. If you ever
-- find yourself "fixing" the frustration of someone grabbing the part you
-- needed, stop - that frustration is the product.
--
-- AUTHORITY MODEL, worth reading before you change anything here:
-- the truth of who is carrying what is the `Carrying` ATTRIBUTE on the Player,
-- set only by this script. The model welded to the character is cosmetic. An
-- exploiter can fling that model anywhere they like and it changes nothing,
-- because pedestal submission is validated against the attribute and never
-- against where a part physically is.
--
-- Interaction is ProximityPrompt rather than a custom RemoteEvent on purpose:
-- prompts fire .Triggered on the SERVER with a built-in distance check, so
-- there is no new remote to rate-limit and no reach-extension to defend against.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local IconPool = require(Shared.IconPool)
local Net = require(Shared.Net)

local ArenaService = require(script.Parent.Parent.ArenaService)

local LineFeedback = Net.get("LineFeedback")

local Line = {}

Line.Id = "line"
Line.DisplayName = "SUPPLY"
Line.Verb = "SUBMIT"
Line.Duration = Config.Line.PlayTime
Line.MinPlayers = 2 -- pointless solo; the contention IS the game

local cfg = Config.Line

-- Round state ---------------------------------------------------------------

local runtime: Folder? = nil
local originCF: CFrame = CFrame.identity
local competitors: { Player } = {}
local pedestals: { { part: BasePart, want: string, filled: boolean } } = {}
local filledCount: { [Player]: number } = {}
local closedBy: Player? = nil
local connections: { RBXScriptConnection } = {}
local remaining = 0

local function log(...)
	if Config.Verbose then
		print("[Line]", ...)
	end
end

local function isLocked(player: Player): boolean
	local until_ = player:GetAttribute("LineLockedUntil")
	return type(until_) == "number" and workspace:GetServerTimeNow() < until_
end

local function lockOut(player: Player, seconds: number)
	player:SetAttribute("LineLockedUntil", workspace:GetServerTimeNow() + seconds)
end

-- Build the visual for an icon. Uses the real PSX model when it has been
-- imported, and a labelled placeholder block when it has not, so the minigame
-- is fully playable before any art exists.
local function buildItemVisual(iconId: string): Model
	local icon = IconPool.byId(iconId)

	local imported: Model? = nil
	if icon and icon.model then
		local items = ReplicatedStorage:FindFirstChild("Items")
		local source = items and items:FindFirstChild(icon.model)
		if source and source:IsA("Model") then
			imported = source:Clone()
		end
	end

	-- Assigned on both branches so `model` is never optional below. Writing this
	-- as `local model: Model? = nil` then filling it in reads fine but leaves
	-- every later access nil-typed, which buries real warnings under fake ones.
	local model: Model
	if imported then
		model = imported
	else
		model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Name = "Placeholder"
		part.Size = Vector3.new(2, 2, 2)
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(120, 116, 104)
		part.Parent = model
		model.PrimaryPart = part
	end

	model.Name = iconId

	-- Floating icon so the object is identifiable across the room. In a game
	-- where everything is a grimy brown box, this label is not optional.
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if primary then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Label"
		billboard.Size = UDim2.fromScale(3, 3)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 60
		billboard.Parent = primary

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = if icon then icon.image else ""
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		image.Parent = billboard

		if not icon or icon.image == "" then
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = if icon then icon.label else iconId
			text.TextScaled = true
			text.TextColor3 = Config.Colors.Accent
			text.Font = Enum.Font.Code
			text.Parent = billboard
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Massless = true
			descendant.Anchored = false
		end
	end

	return model
end

local function dropCarried(player: Player, atCFrame: CFrame?)
	local carrying = player:GetAttribute("Carrying")
	if type(carrying) ~= "string" then
		return
	end
	player:SetAttribute("Carrying", nil)

	local character = player.Character
	local held = character and character:FindFirstChild("HeldItem")
	if held then
		held:Destroy()
	end

	if atCFrame and runtime then
		-- Put it back in the world so nobody can permanently remove an item
		-- from play by disconnecting or dying while holding it.
		Line._spawnItem(carrying, atCFrame)
	end
end

function Line._spawnItem(iconId: string, at: CFrame)
	if not runtime then
		return
	end
	local model = buildItemVisual(iconId)
	model.Parent = runtime
	model:PivotTo(at)

	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not primary then
		return
	end
	primary.Anchored = true
	primary.CanCollide = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "SALVAGE"
	prompt.ActionText = "TAKE"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = cfg.InteractRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = primary

	table.insert(
		connections,
		prompt.Triggered:Connect(function(player)
			if not table.find(competitors, player) or isLocked(player) then
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end

			-- Already holding something? Swap: the old item lands where you stand,
			-- which keeps a player from soft-locking themselves with a wrong pick.
			if player:GetAttribute("Carrying") then
				dropCarried(player, (root :: BasePart).CFrame * CFrame.new(0, -2, -3))
			end

			player:SetAttribute("Carrying", iconId)
			model:Destroy()

			-- Cosmetic held copy, welded to the hand.
			local visual = buildItemVisual(iconId)
			visual.Name = "HeldItem"
			local vPrimary = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart")
			local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
			if vPrimary and hand and hand:IsA("BasePart") then
				visual.Parent = character
				vPrimary.CFrame = hand.CFrame * CFrame.new(0, -1, 0)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = vPrimary
				weld.Part1 = hand
				weld.Parent = vPrimary
			else
				visual:Destroy()
			end

			LineFeedback:FireClient(player, { kind = "pickup", icon = iconId })
		end)
	)
end

function Line:Setup(ctx)
	local rng = Random.new(ctx.seed)

	competitors = ctx.players
	pedestals = {}
	filledCount = {}
	closedBy = nil
	connections = {}

	originCF = ArenaService.getOrigin(ctx.arena)
	runtime = ArenaService.runtimeFolder(ctx.arena)

	for _, player in competitors do
		player:SetAttribute("Carrying", nil)
		player:SetAttribute("LineLockedUntil", nil)
	end

	local pool = IconPool.carryable()
	if #pool == 0 then
		warn("[Line] no icons uploaded yet - see src/shared/IconPool.luau")
		return
	end

	local wanted = IconPool.sample(rng, cfg.PedestalCount, pool)
	remaining = #wanted

	-- Pedestals in a row facing the players.
	for i, icon in wanted do
		local part = Instance.new("Part")
		part.Name = `Pedestal_{i}`
		part.Size = Vector3.new(5, 4, 5)
		part.Anchored = true
		part.Material = Enum.Material.Concrete
		part.Color = Color3.fromRGB(70, 68, 64)
		part.CFrame = originCF * CFrame.new((i - (#wanted + 1) / 2) * 9, 2, 26)
		part.Parent = runtime

		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Top
		surface.CanvasSize = Vector2.new(256, 256)
		surface.Parent = part

		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = icon.image
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		image.Parent = surface

		if icon.image == "" then
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = icon.label
			text.TextScaled = true
			text.Font = Enum.Font.Code
			text.TextColor3 = Config.Colors.Accent
			text.Parent = surface
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "INTAKE"
		prompt.ActionText = "SUBMIT"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = cfg.InteractRange
		prompt.RequiresLineOfSight = false
		prompt.Parent = part

		local entry = { part = part, want = icon.id, filled = false }
		pedestals[i] = entry

		table.insert(
			connections,
			prompt.Triggered:Connect(function(player)
				if entry.filled or not table.find(competitors, player) or isLocked(player) then
					return
				end

				local carrying = player:GetAttribute("Carrying")
				if type(carrying) ~= "string" then
					LineFeedback:FireClient(player, { kind = "empty" })
					return
				end

				if carrying ~= entry.want then
					lockOut(player, cfg.WrongPenalty)
					LineFeedback:FireClient(player, { kind = "rejected", icon = carrying })
					return
				end

				-- Accepted.
				entry.filled = true
				remaining -= 1
				filledCount[player] = (filledCount[player] or 0) + 1
				if remaining == 0 then
					closedBy = player
				end

				dropCarried(player, nil)
				prompt.Enabled = false
				part.Color = Config.Colors.PadSafe
				part.Material = Enum.Material.Neon

				LineFeedback:FireClient(player, { kind = "accepted", icon = carrying })
				log(`{player.Name} filled pedestal {i} ({carrying}), {remaining} left`)
			end)
		)
	end

	-- Exactly one of each required item exists. This is the scarcity.
	local scatter = {}
	for _, icon in wanted do
		table.insert(scatter, icon.id)
	end
	-- Decoys give the room texture and punish grabbing the first thing you see.
	local decoys = IconPool.sample(rng, cfg.DecoyItems, pool)
	for _, icon in decoys do
		table.insert(scatter, icon.id)
	end

	for i, iconId in scatter do
		-- Deterministic scatter across a wide arc in front of the pedestals.
		local angle = (i / #scatter) * math.pi * 2
		local radius = 14 + rng:NextNumber() * 16
		local at = originCF * CFrame.new(math.cos(angle) * radius, 1.5, -2 + math.sin(angle) * radius * 0.5)
		Line._spawnItem(iconId, at)
	end

	log(`round {ctx.round}: {#wanted} pedestals, {#scatter} items on the floor`)
end

function Line:Start()
	-- Nothing to start: prompts are live from Setup and the round clock is owned
	-- by RoundService. Kept for interface symmetry.
end

function Line:Stop()
	local result: { [Player]: number } = {}
	for _, player in competitors do
		local count = filledCount[player] or 0
		local score = count * Config.Score.LinePerPedestal
		if closedBy == player then
			score += Config.Score.LineFirstBonus
		end
		result[player] = score
	end
	return result
end

function Line:Cleanup()
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}

	for _, player in competitors do
		player:SetAttribute("Carrying", nil)
		player:SetAttribute("LineLockedUntil", nil)
		local character = player.Character
		local held = character and character:FindFirstChild("HeldItem")
		if held then
			held:Destroy()
		end
	end

	pedestals = {}
	filledCount = {}
	competitors = {}
	closedBy = nil
	runtime = nil
	remaining = 0
end

return Line
