--!nonstrict
-- X Bot playable characters: locomotion state machine + push combat.
-- States replicate to every client via the XBotState/XBotAction attributes;
-- XBotAnimSync (client) turns them into animation playback.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
local push = remotes:FindFirstChild("XBotPush")
if not push then
	push = Instance.new("RemoteEvent")
	push.Name = "XBotPush"
	push.Parent = remotes
end
local crouchRemote = remotes:FindFirstChild("XBotCrouch")
if not crouchRemote then
	crouchRemote = Instance.new("RemoteEvent")
	crouchRemote.Name = "XBotCrouch"
	crouchRemote.Parent = remotes
end

-- Crouch is client-requested and server-owned. The imported SneakWalk pose
-- folds the rig low and forward, so both query hitboxes must follow the visible
-- body. HumanoidRootPart remains collidable while BodyBox becomes query-only.
local CROUCH_SPEED = 6
local CROUCH_REQUEST_INTERVAL = 0.1
local WALK_SPEED = 7
local RUN_SPEED = 14
local RUN_AFTER = 1.0 -- seconds of continuous movement before breaking into a run
local crouching = {}
local lastCrouchRequest = {}
local moveStart = {}

-- Absolute root-space centers measured from the authored SneakWalk pose.
local CROUCH_HEAD_C0 = CFrame.new(-1.66, -0.53, -2.10)
local CROUCH_BODY_C0 = CFrame.new(-0.75, -2.40, -1.00)
local CROUCH_BODY_SIZE = Vector3.new(2.50, 3.80, 2.50)
local baseHeadC0 = {}
local baseBodyC0 = {}
local baseBodySize = {}
local baseBodyCollide = {}

local function setCrouchHitboxes(player, char, on)
	local uid = player.UserId
	local head = char:FindFirstChild("Head")
	local headWeld = head and head:FindFirstChild("HitWeld")
	local body = char:FindFirstChild("BodyBox")
	local bodyWeld = body and body:FindFirstChild("HitWeld")
	if headWeld then
		if not baseHeadC0[uid] then baseHeadC0[uid] = headWeld.C0 end
		headWeld.C0 = on and CROUCH_HEAD_C0 or baseHeadC0[uid]
	end
	if body and bodyWeld then
		if not baseBodyC0[uid] then
			baseBodyC0[uid] = bodyWeld.C0
			baseBodySize[uid] = body.Size
			baseBodyCollide[uid] = body.CanCollide
		end
		bodyWeld.C0 = on and CROUCH_BODY_C0 or baseBodyC0[uid]
		body.Size = on and CROUCH_BODY_SIZE or baseBodySize[uid]
		if on then
			body.CanCollide = false
		else
			body.CanCollide = baseBodyCollide[uid]
		end
	end
end

crouchRemote.OnServerEvent:Connect(function(player, wants)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and char:GetAttribute("XBotRig") and hum and hum.Health > 0) then return end
	wants = wants == true
	if crouching[player.UserId] == wants then return end
	-- new minigame, new moves: sneaking only where the trial allows it
	local moves = char:GetAttribute("XBotMoves") or ""
	if wants and not string.find(moves, "sneak") then return end
	-- only meaningful while the character is free to move (in a round)
	if wants and hum.WalkSpeed <= 0 then return end
	local now = os.clock()
	if wants and now - (lastCrouchRequest[player.UserId] or 0) < CROUCH_REQUEST_INTERVAL then return end
	lastCrouchRequest[player.UserId] = now
	crouching[player.UserId] = wants
	setCrouchHitboxes(player, char, wants)
end)

-- locomotion states ---------------------------------------------------------
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end
	acc = 0
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char and char:GetAttribute("XBotRig") then
			local root = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local v = root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				local moves = char:GetAttribute("XBotMoves") or ""
				-- Trial changes are server-owned. Removing the sneak move must also
				-- clear a held/toggled crouch and restore the head hitbox.
				if crouching[plr.UserId] and not string.find(moves, "sneak", 1, true) then
					crouching[plr.UserId] = nil
					setCrouchHitboxes(plr, char, false)
				end
				-- speed ramp: the first second of movement walks, then breaks
				-- into a run; the heartbeat owns WalkSpeed while it is unlocked
				if hum.WalkSpeed > 0 then
					-- kein Anlauf mehr: es wird sofort gerannt. Ausnahme Dead Zone
					-- (Move-Set "scan"): dort ist NUR Gehen erlaubt - der Kastrierer
					-- kommt mit 0.75x Gehtempo hinterher
					local desired
					if crouching[plr.UserId] then
						desired = CROUCH_SPEED
					elseif string.find(moves, "scan") then
						desired = WALK_SPEED
					else
						desired = RUN_SPEED
					end
					-- a winged runner limps: one surviving body shot caps the pace
					if hum.Health < 60 then
						desired = math.min(desired, 9.5)
					end
					-- ein Minen-Knockback zwingt in den Zombie-Crawl: knapp unter
					-- Kastrierer-Tempo (4.5) - vorwaerts kriechen lohnt sich noch
					if char:GetAttribute("XBotCrawl") then
						desired = math.min(desired, 4.2)
					end
					if hum.WalkSpeed ~= desired then hum.WalkSpeed = desired end
				end
				local state
				if hum.FloorMaterial == Enum.Material.Air then
					state = "Jump"
				else
					if char:GetAttribute("XBotCrawl") then
						state = speed < 0.5 and "CrawlIdle" or "Crawl"
					elseif crouching[plr.UserId] and hum.WalkSpeed > 0 then
						state = speed < 1 and "CrouchIdle" or "Crouch"
					elseif speed < 1 then
						state = "Idle"
					elseif hum.Health < 60 then
						-- body-shot survivor: injured limp instead of walk/run
						state = "Injured"
					elseif speed < 9 then
						-- walk phase runs at 7; velocity overshoot must not read as Run
						state = "Walk"
					else
						state = "Run"
					end
				end
				if char:GetAttribute("XBotState") ~= state then
					char:SetAttribute("XBotState", state)
				end
			end
		end
	end
end)

-- push combat ---------------------------------------------------------------
local lastPush = {}
local downedUntil = {}

local function pulse(char, action)
	char:SetAttribute("XBotAction", action .. "#" .. tostring(math.floor(os.clock() * 1000)))
end

push.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastPush[player.UserId] or 0) < 1.2 then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and char:GetAttribute("XBotRig") and root and hum) then return end
	local moves = char:GetAttribute("XBotMoves") or ""
	if not string.find(moves, "push", 1, true) then return end
	if hum.WalkSpeed <= 0 or hum.Health <= 0 then return end
	if (downedUntil[player.UserId] or 0) > now then return end
	lastPush[player.UserId] = now
	pulse(char, "Punch")

	-- the hit lands mid-swing
	task.delay(0.35, function()
		if not root.Parent then return end
		local origin = root.Position
		local look = root.CFrame.LookVector
		-- other players' X Bot characters
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local oc = other.Character
				local oroot = oc and oc:FindFirstChild("HumanoidRootPart")
				local ohum = oc and oc:FindFirstChildOfClass("Humanoid")
				if oc and oc:GetAttribute("XBotRig") and oroot and ohum and ohum.Health > 0 then
					local d = oroot.Position - origin
					if d.Magnitude < 7 and look:Dot(d.Unit) > 0.35
						and (downedUntil[other.UserId] or 0) < os.clock() then
						downedUntil[other.UserId] = os.clock() + 3.6
						pulse(oc, "Pushed")
					end
				end
			end
		end
		-- NPC bots with an Act brain
		for _, m in workspace:GetChildren() do
			if m:IsA("Model") and m ~= char then
				local act = m:FindFirstChild("Act")
				local bmesh = m:FindFirstChild("Beta_Joints")
				if act and act:IsA("BindableEvent") and bmesh then
					local d = bmesh.Position - origin
					if d.Magnitude < 9 and look:Dot(d.Unit) > 0.3 then
						act:Fire("Pushed")
					end
				end
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	lastPush[p.UserId] = nil
	downedUntil[p.UserId] = nil
	crouching[p.UserId] = nil
	lastCrouchRequest[p.UserId] = nil
	moveStart[p.UserId] = nil
	baseHeadC0[p.UserId] = nil
	baseBodyC0[p.UserId] = nil
	baseBodySize[p.UserId] = nil
	baseBodyCollide[p.UserId] = nil
end)

-- fresh characters never spawn crouched
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function()
		crouching[p.UserId] = nil
		lastCrouchRequest[p.UserId] = nil
		moveStart[p.UserId] = nil
		baseHeadC0[p.UserId] = nil
		baseBodyC0[p.UserId] = nil
		baseBodySize[p.UserId] = nil
		baseBodyCollide[p.UserId] = nil
	end)
end)

-- the engine swaps in its default R6 Animate script at spawn; it cannot drive
-- this rig (and spams infinite-yield warnings), so put it down on arrival.
-- Animators must go too: an idle Animator zeroes Bone.Transform every frame,
-- which would erase the client-side sequence player's writes.
local function neuterAnimate(char)
	local function kill(inst)
		if inst.Name == "Animate" and inst:IsA("LocalScript") then
			inst.Disabled = true
		end
		if inst:IsA("Animator") then
			inst:Destroy()
		end
	end
	for _, c in char:GetDescendants() do kill(c) end
	local conn = char.DescendantAdded:Connect(kill)
	task.delay(5, function() conn:Disconnect() end)
end
local function watchPlayer(plr)
	plr.CharacterAdded:Connect(function(char)
		if char:GetAttribute("XBotRig") then neuterAnimate(char) end
	end)
	if plr.Character and plr.Character:GetAttribute("XBotRig") then
		neuterAnimate(plr.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in Players:GetPlayers() do watchPlayer(p) end

print("[XBotCharacters] online")
