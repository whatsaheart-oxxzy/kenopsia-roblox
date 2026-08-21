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

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local CanteenBoss = require(script.Parent.CanteenBoss)
local CanteenDiner = require(script.Parent.CanteenDiner)

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

-- How far the newspaper tips forward when the Observer looks up from it.
-- 74 degrees was measured in Blender as the swing that clears the lens (paper
-- top drops from z 2.68 to 0.06, lens sits at 2.06) without the paper passing
-- through the table.
local PAPER_DOWN_RADIANS = math.rad(74)

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
	part.CastShadow = false
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
	p.Material = Enum.Material.SmoothPlastic
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
	grip.Material = Enum.Material.SmoothPlastic
	grip.Color = Color3.fromRGB(150, 152, 155)
	decorate(grip)
	grip.Parent = model
	model.PrimaryPart = grip
	for i = 1, FORK_TINE_COUNT do
		local tine = Instance.new("Part")
		tine.Name = "Tine" .. i
		tine.Size = Vector3.new(0.07, 0.07, 0.75)
		tine.Material = Enum.Material.SmoothPlastic
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
		-- Second return: authored. See poseObserver for why this matters.
		return c, true
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

-- `authored` is not cosmetic: an authored CP_Observer is a rigid model whose
-- parts are already placed relative to each other, and moving it means moving
-- the PIVOT and nothing else. The per-part placement below exists only because
-- the procedural build is a loose bag of parts.
--
-- Without this flag the lookups by name are a trap for the very models this
-- slot exists to accept: any authored model that happens to name a part "Eye"
-- or "Stalk" -- which a lens and a ceiling mount plainly would -- gets those
-- parts yanked onto procedural offsets and tears itself apart on frame one.
local function poseObserver(model, cf, authored)
	setPivot(model, cf)
	if authored then return end

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

-- WHERE IS THE CHAIR? Not where the marker is. `Seats.P1..4` and `BossSeat`
-- stand at the default R15 avatar's hip height, which in the shipped canteen is
-- 2.6 studs above the actual seat pad -- the furniture is oversized and the
-- markers were never re-authored for it. So ask the world instead of the marker:
-- drop a ray and take whatever solid is under the seat. Falls back to the
-- marker's own height, which is exactly the old (hovering) behaviour, so an
-- arena with no chair under a marker still runs.
local function seatSurfaceY(marker, ignore, ceilingY)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(marker.Position + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), rp)
	if not hit then return nil end
	-- A surface at or above the mouth is not a chair -- it is something standing
	-- on the chair. Refusing it keeps a stray prop from launching the diner.
	if ceilingY and hit.Position.Y >= ceilingY then return nil end
	return hit.Position.Y
end

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

	-- ONE SCALE FOR THE WHOLE TABLE, derived from the arena rather than typed in.
	-- Seat 1's chair and its MouthTarget are two anchors on the same body: the
	-- pelvis belongs on the pad, the mouth belongs where the fork flies to. That
	-- fixes the figure exactly, and it re-derives itself if the user rebuilds the
	-- room at another size. Everyone at the table -- diners and the Observer --
	-- shares it, because a warden at a different scale reads as a different room.
	--
	-- The ray must ignore every PLAYER BODY as well as the markers and our own
	-- props. CanteenProtocol parks each character on its seat moments after this
	-- runs, and any player already standing there measures as "chair" -- caught
	-- live: seat P1 returned Y 15.68 off the avatar's own head instead of 9.71
	-- off the chair, which would have seated the diner six studs in the air and,
	-- because seat 1 also sets the table's scale, shrunk everyone at it.
	local ignore = { arena.rig, workspace:FindFirstChild(PROPS_FOLDER) }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(ignore, plr.Character) end
	end

	local seatY = {}
	for i = 1, #arena.seats do
		seatY[i] = seatSurfaceY(arena.seats[i], ignore, arena.mouths[i].Position.Y)
	end
	local bossSeatY = seatSurfaceY(arena.BossSeat, ignore, arena.BossSeat.Position.Y + 6)

	-- Scale off the first seat that actually found a chair, not blindly off seat
	-- one: one unmeasurable seat must not resize the whole table.
	local scaleSeat
	for i = 1, #seatY do
		if seatY[i] then
			scaleSeat = i
			break
		end
	end
	local worldScale = (scaleSeat and CanteenDiner.scaleFor(seatY[scaleSeat], arena.mouths[scaleSeat].Position.Y)) or 1
	print(("[CP] table scale %.3f (seat %s: chair %.2f -> mouth %.2f)"):format(
		worldScale, scaleSeat and ("P" .. scaleSeat) or "none",
		scaleSeat and seatY[scaleSeat] or -1,
		scaleSeat and arena.mouths[scaleSeat].Position.Y or -1))

	local self = {
		folder = folder,
		seats = {},
		diners = {},
		peaCount = opts.peas,
		forkCapacity = opts.forkCapacity,
		eatWindow = opts.eatWindow,
		alive = true,
	}

	for i = 1, #arena.plates do
		local plateCF = arena.plates[i].CFrame
		local seat = { peas = {}, forkLoad = {}, restCF = arena.forks[i].CFrame,
			mouthCF = arena.mouths[i].CFrame, busy = false, eatGen = 0 }

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

	local observer, observerAuthored = makeObserver(tpl)
	local restCF = arena.Observer.CFrame
	self.observerRest = restCF
	self.observerHidden = restCF + Vector3.new(0, OBSERVER_HIDE_RISE, 0)
	self.observerAuthored = observerAuthored

	-- A "Newspaper" part is an explicit contract, not a guess at the model's
	-- internals: it opts the model into the hinge behaviour. Anything without
	-- one keeps the whole-model rise and fall, so the procedural placeholder is
	-- unaffected.
	local paper = observer:IsA("Model") and observer:FindFirstChild("Newspaper", true) or nil
	if paper and paper:IsA("BasePart") then
		-- PLACE FIRST, then capture. Reading paper.CFrame before poseObserver
		-- moves the model records the pose it had while still sitting at the
		-- origin, and the paper would then swing about a hinge point it has
		-- never actually occupied.
		--
		-- With a paper the figure never retreats: it hangs at rest for the whole
		-- round and only the paper moves.
		poseObserver(observer, restCF, observerAuthored)
		self.paper = paper
		self.paperRest = paper.CFrame
		-- The hinge is the BOTTOM edge of the panel -- where the folded hands
		-- hold it. Roblox rebuilds a MeshPart's pivot at its bounding-box centre
		-- on import, so the origin authored in Blender does not survive;
		-- deriving the hinge from the part's own size does, and survives a
		-- resize too.
		self.paperHinge = paper.CFrame * CFrame.new(0, -paper.Size.Y / 2, 0)
		self.paperAngle = 0
	else
		poseObserver(observer, self.observerHidden, observerAuthored)
	end

	function self.setPaperAngle(rad)
		if not self.paper or not self.paper.Parent then return end
		local r = CFrame.Angles(-rad, 0, 0)
		-- Rotate the rest pose ABOUT the hinge frame, rather than about the
		-- part's own centre, which would swing the paper through his chest.
		self.paper.CFrame = self.paperHinge * r * self.paperHinge:Inverse() * self.paperRest
	end
	observer.Parent = folder
	self.observer = observer

	folder.Parent = workspace

	-- The mechanical Observer remains the invisible server authority. When an
	-- authored boss template is available, it becomes the readable visual tell
	-- while raycasts and phase timing continue to use the validated marker rig.
	self.boss = CanteenBoss.spawn(arena.BossSeat, folder, { scale = worldScale, seatY = bossSeatY })
	if self.boss then
		setVisible(observer, false)
		for _, d in observer:GetDescendants() do
			if d:IsA("Light") then d.Enabled = false end
		end
	end

	-- METHODS ---------------------------------------------------------------

	-- The visible body at an occupied seat. Called by CanteenProtocol for each
	-- seated member only, so empty chairs stay empty. Returns the actor or nil
	-- (no template = no body; the mechanic does not care).
	function self.seatDiner(seatIndex)
		if not self.alive or self.diners[seatIndex] then return self.diners[seatIndex] end
		local marker = arena.seats[seatIndex]
		local diner = marker and CanteenDiner.spawn(marker, folder, seatIndex, {
			scale = worldScale,
			seatY = seatY[seatIndex],
		}) or nil
		self.diners[seatIndex] = diner
		return diner
	end

	function self.diner(seatIndex)
		return self.diners[seatIndex]
	end

	function self.dinerDie(seatIndex)
		local diner = self.diners[seatIndex]
		if diner then diner:die() end
	end

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
		seat.pendingForkLoad = math.max(0, math.floor(tonumber(load) or 0))
		-- While a mouthful is in flight the animation owns the riders. The
		-- server sets ps.fork = 0 the instant MOUTH is accepted, so without
		-- this guard the state push would hide the load before it had left the
		-- plate and the fork would travel to the mouth visibly EMPTY.
		if seat.busy then return end
		for k, rider in ipairs(seat.forkLoad) do
			setVisible(rider, k <= seat.pendingForkLoad)
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
		if not seat then return end
		-- NEVER drop an accepted bite. The server has already consumed the load
		-- by the time this runs; if the previous fork is still returning (a
		-- scheduler hitch can stretch its 0.45 s past the 0.5 s mouth interval),
		-- the old flight is superseded by generation and this one starts from
		-- wherever the fork is now. An early return here would be exactly the
		-- "invisible mouthful" -- eaten on the server, never seen at the table.
		seat.eatGen += 1
		local gen = seat.eatGen
		seat.busy = true
		local diner = self.diners[seatIndex]
		if diner then diner:eat(self.eatWindow) end
		-- Show exactly what is being carried. `load` is passed in rather than
		-- read back from the fork, because by the time this runs the server has
		-- already zeroed it.
		for k, rider in ipairs(seat.forkLoad) do
			setVisible(rider, k <= (load or 0))
		end
		task.spawn(function()
			local half = self.eatWindow / 2
			local startedAt = os.clock()
			local fromCF = pivotOf(seat.fork)
			local swallowed = false
			-- One absolute timeline prevents a scheduler hitch in the outbound
			-- leg from adding a second full half-window on the return.
			while self.alive and seat.eatGen == gen do
				local elapsed = os.clock() - startedAt
				if elapsed >= self.eatWindow then break end
				local cf
				if elapsed < half then
					cf = fromCF:Lerp(seat.mouthCF, elapsed / half)
				else
					if not swallowed then
						swallowed = true
						for _, rider in ipairs(seat.forkLoad) do setVisible(rider, false) end
					end
					cf = seat.mouthCF:Lerp(seat.restCF, (elapsed - half) / half)
				end
				poseFork(seat.fork, cf)
				self.poseLoad(seatIndex, cf)
				task.wait()
			end
			-- Superseded: the newer flight owns the fork and the busy flag now.
			if seat.eatGen ~= gen then return end
			if self.alive then
				for _, rider in ipairs(seat.forkLoad) do setVisible(rider, false) end
				poseFork(seat.fork, seat.restCF)
				self.poseLoad(seatIndex, seat.restCF)
			end
			seat.busy = false
			-- PLATE remains legal while the previous fork is returning. Reapply
			-- the latest authoritative load now so that accepted food never stays
			-- visually absent after the animation releases its riders.
			if self.alive then self.setFork(seatIndex, seat.pendingForkLoad or 0) end
		end)
	end

	function self.observerTo(phase, duration)
		if not self.alive then return end
		if self.boss then
			self.boss:setPhase(phase, duration)
			return
		end
		local down = (phase == "lowering" or phase == "watching")

		-- NEWSPAPER, if the authored model brought one. The figure then stays
		-- put and only the paper hinges, which is a better tell than a whole
		-- body rising into the ceiling: he never stops looming, and lowering a
		-- paper is a decision a person makes rather than machinery moving.
		--
		-- The swing is driven by the SAME phase and the SAME duration the server
		-- uses to rule on a swallow, for the same reason the fork's travel
		-- equals EAT_WINDOW: what the player watches has to be what is
		-- detectable, not an animation timed separately from the rule.
		if self.paper then
			local target = down and PAPER_DOWN_RADIANS or 0
			local from = self.paperAngle or 0
			if math.abs(target - from) < 0.01 then return end
			self.paperAngle = target
			task.spawn(function()
				local t0 = os.clock()
				while self.alive do
					local a = (os.clock() - t0) / math.max(duration, 0.05)
					if a >= 1 then break end
					self.setPaperAngle(from + (target - from) * a)
					task.wait()
				end
				if self.alive then self.setPaperAngle(target) end
			end)
			return
		end

		local target = down and self.observerRest or self.observerHidden
		local from = pivotOf(self.observer)
		if (from.Position - target.Position).Magnitude < 0.05 then return end
		task.spawn(function()
			local t0 = os.clock()
			while self.alive do
				local a = (os.clock() - t0) / math.max(duration, 0.05)
				if a >= 1 then break end
				poseObserver(self.observer, from:Lerp(target, a), self.observerAuthored)
				task.wait()
			end
			if self.alive then poseObserver(self.observer, target, self.observerAuthored) end
		end)
	end

	-- Serialised by CanteenBoss. The first callback is the authoritative shot;
	-- the completion callback lets CanteenProtocol keep the round alive until
	-- the visible execution has finished. With no authored boss the gameplay
	-- still completes immediately instead of becoming dependent on an asset.
	function self.execute(onFire, onDone)
		if self.boss then
			self.boss:execute(onFire, onDone)
		else
			onFire()
			onDone()
		end
	end

	function self.destroy()
		if not self.alive then return end
		self.alive = false
		if self.boss then self.boss:destroy() end
		for _, diner in self.diners do diner:destroy() end
		table.clear(self.diners)
		folder:Destroy()
	end

	return self
end

return CanteenProps
