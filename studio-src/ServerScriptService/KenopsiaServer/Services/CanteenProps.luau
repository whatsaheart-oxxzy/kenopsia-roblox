--!nonstrict
-- CANTEEN PROTOCOL -- the physical props: peas, forks and the Observer.
--
-- WHY THESE ARE SERVER INSTANCES AND NOT A CLIENT HUD.
-- The three things a player must read to play this minigame are: how much food
-- is left, how loaded the fork is, and whether the Observer is looking. All
-- three are server state. Building them as real parts means the server's number
-- IS the picture -- there is no second copy of the truth on the client to drift
-- out of sync, and no payload that silently renders nothing because the client
-- does not know that `kind`. That failure has already happened once in this
-- project (`kind = "select"` drew nothing), so it is worth avoiding by design
-- rather than by care.
--
-- SWAPPABLE, exactly like MF_Compactor and BH_Turret. Drop a model into
-- ServerStorage.KenopsiaAssets.Props.CanteenProtocol named CP_Observer, CP_Fork
-- or CP_Pea and it replaces the procedural build with no code change.
--   CP_Observer wants its PrimaryPart at the lens, looking down -Z.
--   CP_Fork     wants its PrimaryPart at the grip, tines toward +Z.
--   CP_Pea      is a single small part or model; it is cloned 16 times a plate.
--
-- NO CONSTANTS ARE DUPLICATED FROM CanteenProtocol. Pea count, fork capacity
-- and the eat window arrive through `opts`, because two copies of a rule drift
-- apart and the drift is invisible until a player is scored on the wrong one.

local ServerStorage = game:GetService("ServerStorage")

local CanteenProps = {}

local PEA_SIZE = 0.34
-- Peas sit inside this radius on the plate. The plate cylinder is 6.1 across,
-- so 2.1 leaves a visible rim rather than food spilling over the edge.
local PLATE_SPREAD = 2.1
-- Sunflower spacing. Successive peas land 137.5 degrees apart, which fills a
-- disc evenly without the rings and spokes a naive polar grid produces.
local GOLDEN_ANGLE = 2.399963229728653

local FORK_TINE_COUNT = 3
-- How far above its rest pose the Observer waits while hidden. Ceiling is at
-- ~32.6 and the Observer marker sits at ~19.3, so 9 studs keeps it clear of the
-- table and still under the ceiling.
local OBSERVER_HIDE_RISE = 9.0

local function templates()
	local props = ServerStorage:FindFirstChild("KenopsiaAssets")
	props = props and props:FindFirstChild("Props")
	return props and props:FindFirstChild("CanteenProtocol")
end

local function decorate(part)
	part.Anchored = true
	part.CanCollide = false
	-- Props must not answer raycasts. The Observer's line of sight to each
	-- MouthTarget is a real query in this arena, and a pea that blocks it would
	-- make the minigame quietly unlosable.
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function pivotOf(inst)
	return inst:IsA("BasePart") and inst.CFrame or inst:GetPivot()
end

local function setPivot(inst, cf)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
	else
		inst:PivotTo(cf)
	end
end

local function setVisible(inst, visible)
	local t = visible and 0 or 1
	if inst:IsA("BasePart") then
		inst.Transparency = t
		return
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = t
		end
	end
end

-- BUILDERS ------------------------------------------------------------------

local function makePea(tpl)
	local custom = tpl and tpl:FindFirstChild("CP_Pea")
	if custom then
		local c = custom:Clone()
		for _, d in ipairs(c:IsA("BasePart") and { c } or c:GetDescendants()) do
			if d:IsA("BasePart") then decorate(d) end
		end
		return c
	end
	local p = Instance.new("Part")
	p.Name = "Pea"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(PEA_SIZE, PEA_SIZE, PEA_SIZE)
	p.Material = Enum.Material.Glass
	p.Color = Color3.fromRGB(96, 118, 58)
	return decorate(p)
end

local function makeFork(tpl)
	local custom = tpl and tpl:FindFirstChild("CP_Fork")
	if custom then
		local c = custom:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then decorate(d) end
		end
		return c
	end
	local model = Instance.new("Model")
	model.Name = "Fork"
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.16, 0.16, 2.2)
	grip.Material = Enum.Material.Metal
	grip.Color = Color3.fromRGB(150, 152, 155)
	decorate(grip)
	grip.Parent = model
	model.PrimaryPart = grip
	for i = 1, FORK_TINE_COUNT do
		local tine = Instance.new("Part")
		tine.Name = "Tine" .. i
		tine.Size = Vector3.new(0.07, 0.07, 0.75)
		tine.Material = Enum.Material.Metal
		tine.Color = Color3.fromRGB(168, 170, 172)
		decorate(tine)
		tine.Parent = model
	end
	return model
end

local function makeObserver(tpl)
	local custom = tpl and tpl:FindFirstChild("CP_Observer")
	if custom then
		local c = custom:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then decorate(d) end
		end
		return c
	end
	local model = Instance.new("Model")
	model.Name = "Observer"
	local head = Instance.new("Part")
	head.Name = "Lens"
	head.Size = Vector3.new(3.4, 3.4, 1.6)
	head.Material = Enum.Material.DiamondPlate
	head.Color = Color3.fromRGB(30, 29, 28)
	decorate(head)
	head.Parent = model
	model.PrimaryPart = head

	local eye = Instance.new("Part")
	eye.Name = "Eye"
	eye.Shape = Enum.PartType.Ball
	eye.Size = Vector3.new(1.5, 1.5, 1.5)
	eye.Material = Enum.Material.Neon
	eye.Color = Color3.fromRGB(150, 20, 16)
	decorate(eye)
	eye.Parent = model

	local light = Instance.new("SpotLight")
	light.Angle = 70
	light.Brightness = 2.5
	light.Range = 34
	light.Color = Color3.fromRGB(255, 90, 70)
	light.Face = Enum.NormalId.Front
	light.Parent = eye

	local stalk = Instance.new("Part")
	stalk.Name = "Stalk"
	stalk.Size = Vector3.new(0.5, 14, 0.5)
	stalk.Material = Enum.Material.Metal
	stalk.Color = Color3.fromRGB(42, 40, 38)
	decorate(stalk)
	stalk.Parent = model
	return model
end

-- Lays the fork out relative to its grip. Kept as one function so the
-- procedural fork and an authored CP_Fork are positioned by the same code.
local function poseFork(model, cf)
	setPivot(model, cf)
	if not model:IsA("Model") then return end
	local grip = model.PrimaryPart
	if not grip then return end
	for i = 1, FORK_TINE_COUNT do
		local tine = model:FindFirstChild("Tine" .. i)
		if tine then
			local spread = (i - (FORK_TINE_COUNT + 1) / 2) * 0.16
			tine.CFrame = cf * CFrame.new(spread, 0, 1.45)
		end
	end
end

local function poseObserver(model, cf)
	setPivot(model, cf)
	local eye = model:FindFirstChild("Eye")
	if eye then eye.CFrame = cf * CFrame.new(0, 0, -0.7) end
	local stalk = model:FindFirstChild("Stalk")
	if stalk then
		-- WORLD up, not the lens's local up. The Observer looks straight down
		-- at the table, so its local +Y is horizontal -- a locally-offset stalk
		-- would jut out sideways instead of running up to the ceiling.
		stalk.CFrame = CFrame.new(cf.Position + Vector3.new(0, 7.6, 0))
	end
end

-- BUILD ---------------------------------------------------------------------

-- opts: { peas = <count>, forkCapacity = <n>, eatWindow = <seconds> }
local PROPS_FOLDER = "CP_Props"

function CanteenProps.build(arena, opts)
	-- Idempotent, like the arena builder. MachineFlow runs runRound inside a
	-- pcall, so a round that throws never reaches destroy() and would leave its
	-- props standing in the world forever. Clearing a previous set here means
	-- the leak can survive at most until the next round instead of the session.
	local stale = workspace:FindFirstChild(PROPS_FOLDER)
	if stale then stale:Destroy() end

	local tpl = templates()
	local folder = Instance.new("Folder")
	folder.Name = PROPS_FOLDER

	local self = {
		folder = folder,
		seats = {},
		peaCount = opts.peas,
		forkCapacity = opts.forkCapacity,
		eatWindow = opts.eatWindow,
		alive = true,
	}

	for i = 1, #arena.plates do
		local plateCF = arena.plates[i].CFrame
		local seat = { peas = {}, forkLoad = {}, restCF = arena.forks[i].CFrame,
			mouthCF = arena.mouths[i].CFrame, busy = false }

		for k = 1, self.peaCount do
			local pea = makePea(tpl)
			local t = (k - 0.5) / self.peaCount
			local r = PLATE_SPREAD * math.sqrt(t)
			local ang = k * GOLDEN_ANGLE
			setPivot(pea, plateCF * CFrame.new(math.cos(ang) * r, PEA_SIZE * 0.6, math.sin(ang) * r))
			pea.Parent = folder
			seat.peas[k] = pea
		end

		local fork = makeFork(tpl)
		poseFork(fork, seat.restCF)
		fork.Parent = folder
		seat.fork = fork

		-- Peas riding on the fork. Allocated once at build time rather than
		-- created per mouthful: a round is 45 s of rapid loading and unloading,
		-- and churning instances at that rate replicates far more than toggling
		-- transparency on four parts that already exist.
		for k = 1, self.forkCapacity do
			local rider = makePea(tpl)
			setVisible(rider, false)
			rider.Parent = folder
			seat.forkLoad[k] = rider
		end

		self.seats[i] = seat
	end

	local observer = makeObserver(tpl)
	local restCF = arena.Observer.CFrame
	self.observerRest = restCF
	self.observerHidden = restCF + Vector3.new(0, OBSERVER_HIDE_RISE, 0)
	poseObserver(observer, self.observerHidden)
	observer.Parent = folder
	self.observer = observer

	folder.Parent = workspace

	-- METHODS ---------------------------------------------------------------

	function self.setPeas(seatIndex, remaining)
		local seat = self.seats[seatIndex]
		if not seat then return end
		for k, pea in ipairs(seat.peas) do
			setVisible(pea, k <= remaining)
		end
	end

	function self.setFork(seatIndex, load)
		local seat = self.seats[seatIndex]
		if not seat then return end
		-- While a mouthful is in flight the animation owns the riders. The
		-- server sets ps.fork = 0 the instant MOUTH is accepted, so without
		-- this guard the state push would hide the load before it had left the
		-- plate and the fork would travel to the mouth visibly EMPTY.
		if seat.busy then return end
		for k, rider in ipairs(seat.forkLoad) do
			setVisible(rider, k <= load)
		end
		self.poseLoad(seatIndex, pivotOf(seat.fork))
	end

	function self.poseLoad(seatIndex, forkCF)
		local seat = self.seats[seatIndex]
		if not seat then return end
		for k, rider in ipairs(seat.forkLoad) do
			local spread = (k - (self.forkCapacity + 1) / 2) * 0.3
			setPivot(rider, forkCF * CFrame.new(spread, 0.18, 1.7))
		end
	end

	-- The fork travels to the mouth and back in exactly `eatWindow` seconds --
	-- the same window the server uses to decide whether the Observer saw it.
	-- What the player watches IS what is detectable; the animation is not a
	-- decoration timed independently of the rule.
	function self.eat(seatIndex, load)
		local seat = self.seats[seatIndex]
		if not seat or seat.busy then return end
		seat.busy = true
		-- Show exactly what is being carried. `load` is passed in rather than
		-- read back from the fork, because by the time this runs the server has
		-- already zeroed it.
		for k, rider in ipairs(seat.forkLoad) do
			setVisible(rider, k <= (load or 0))
		end
		task.spawn(function()
			local half = self.eatWindow / 2
			local legs = { { seat.restCF, seat.mouthCF }, { seat.mouthCF, seat.restCF } }
			for legIndex, leg in ipairs(legs) do
				local from, to = leg[1], leg[2]
				local t0 = os.clock()
				while self.alive do
					local a = (os.clock() - t0) / half
					if a >= 1 then break end
					local cf = from:Lerp(to, a)
					poseFork(seat.fork, cf)
					self.poseLoad(seatIndex, cf)
					task.wait()
				end
				if not self.alive then break end
				poseFork(seat.fork, to)
				self.poseLoad(seatIndex, to)
				-- The load is swallowed at the far end of the outbound leg, so
				-- the fork comes back empty.
				if legIndex == 1 then
					for _, rider in ipairs(seat.forkLoad) do
						setVisible(rider, false)
					end
				end
			end
			seat.busy = false
		end)
	end

	function self.observerTo(phase, duration)
		if not self.alive then return end
		local target
		if phase == "lowering" or phase == "watching" then
			target = self.observerRest
		else
			target = self.observerHidden
		end
		local from = pivotOf(self.observer)
		if (from.Position - target.Position).Magnitude < 0.05 then return end
		task.spawn(function()
			local t0 = os.clock()
			while self.alive do
				local a = (os.clock() - t0) / math.max(duration, 0.05)
				if a >= 1 then break end
				poseObserver(self.observer, from:Lerp(target, a))
				task.wait()
			end
			if self.alive then poseObserver(self.observer, target) end
		end)
	end

	function self.destroy()
		self.alive = false
		folder:Destroy()
	end

	return self
end

return CanteenProps
