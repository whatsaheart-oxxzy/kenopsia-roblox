--!nonstrict
-- Animates every X Bot rig this client can see (player characters and NPC
-- bots). No Animator, no asset ids: SequencePlayer writes bone transforms
-- straight from the KeyframeSequences in ReplicatedStorage, which works in
-- live servers where locally registered hash ids do not. States arrive as
-- replicated attributes set by the server (XBotState / XBotAction).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("XBotAnimations", 20)
if not folder then return end
local SequencePlayer = require(folder:WaitForChild("SequencePlayer"))

-- locomotion clips run slower than raw Mixamo timing: the legs then match
-- the distance actually travelled instead of scrabbling
local LOCO_SPEED = { Walk = 0.62, Run = 0.7, Jump = 1, Idle = 1, SneakWalk = 1, InjuredWalk = 0.9, ZombieCrawl = 1, Sit = 1 }

local hooked = {}

local function hookRig(char)
	if hooked[char] then return end
	if not char:GetAttribute("XBotRig") then return end
	hooked[char] = true
	local mesh = char:WaitForChild("Beta_Joints", 10)
	if not mesh then return end
	-- player characters carry a Humanoid; NPC bots do not
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum and Players:GetPlayerFromCharacter(char) then
		hum = char:WaitForChild("Humanoid", 10)
	end
	local rig = SequencePlayer.attach(char, folder)
	if not rig then return end

	-- an idle Animator zeroes Bone.Transform every frame, erasing the sequence
	-- player's writes; make sure none survives on this client
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Animator") then d:Destroy() end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("Animator") then d:Destroy() end
	end)

	local sniperHeld = false

	local function setLoco(state)
		if sniperHeld then return end
		if state == "Crouch" then
			rig:setLoco("SneakWalk", LOCO_SPEED.SneakWalk, 0.2)
		elseif state == "CrouchIdle" then
			-- sneaking but standing still: freeze on the clip's first frame
			rig:setLoco("SneakWalk", 0, 0.25, true)
		elseif state == "Injured" then
			rig:setLoco("InjuredWalk", LOCO_SPEED.InjuredWalk, 0.25)
		elseif state == "Crawl" then
			rig:setLoco("ZombieCrawl", LOCO_SPEED.ZombieCrawl, 0.25)
		elseif state == "CrawlIdle" then
			rig:setLoco("ZombieCrawl", 0, 0.25, true)
		else
			rig:setLoco(state, LOCO_SPEED[state] or 1, 0.2)
		end
	end

	-- third-person rifle: every client renders one on any aiming sniper,
	-- planted at the animated right hand, oriented with the body
	local handRifle, rifleConn
	local function dropRifle()
		if rifleConn then rifleConn:Disconnect() rifleConn = nil end
		if handRifle then handRifle:Destroy() handRifle = nil end
		-- Defensive sweep: role changes must never leave an untracked rifle clone.
		for _, child in char:GetChildren() do
			if child:IsA("Model") and child.Name == "HandRifle" then child:Destroy() end
		end
	end
	local function attachRifle()
		dropRifle()
		-- The local Hunter already gets the first-person SniperViewmodel.
		-- Creating a hidden third-person clone caused the duplicate rifle/sniper.
		if player.Character == char then return end
		local template = ReplicatedStorage:FindFirstChild("KenopsiaAssets")
		template = template and template:FindFirstChild("SniperRifle")
		local rootP = char:FindFirstChild("HumanoidRootPart") or mesh
		if not template then return end
		local hand
		for _, d in ipairs(mesh:GetDescendants()) do
			if d:IsA("Bone") and d.Name == "mixamorig:RightHand" then hand = d break end
		end
		if not hand then return end
		handRifle = template:Clone()
		handRifle.Name = "HandRifle"
		handRifle.Parent = char
		rifleConn = RunService.RenderStepped:Connect(function()
			if not (handRifle and hand.Parent and rootP.Parent) then return end
			local rot = rootP.CFrame - rootP.CFrame.Position
			handRifle:PivotTo(CFrame.new(hand.TransformedWorldCFrame.Position)
				* rot * CFrame.Angles(math.rad(-4), 0, 0))
		end)
	end
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			dropRifle()
			rig:destroy()
			hooked[char] = nil
		end
	end)

	setLoco(char:GetAttribute("XBotState") or "Idle")
	char:GetAttributeChangedSignal("XBotState"):Connect(function()
		setLoco(char:GetAttribute("XBotState") or "Idle")
	end)

	char:GetAttributeChangedSignal("XBotAction"):Connect(function()
		local v = char:GetAttribute("XBotAction") or ""
		local action = string.match(v, "^(%a+)")
		if action == "SniperAim" then
			-- kneel down and hold the aim for the whole round
			sniperHeld = true
			attachRifle()
			rig:playAction("SniperAim", { fade = 0.25, hold = true })
		elseif action == "SniperEnd" then
			sniperHeld = false
			dropRifle()
			rig:releaseAction(0.3)
			setLoco(char:GetAttribute("XBotState") or "Idle")
		elseif action == "Punch" then
			rig:playAction("Punch", { fade = 0.08 })
		elseif action == "Pushed" then
			task.spawn(function()
				local len = rig:playAction("SweepFall", { fade = 0.08, hold = true })
				if len <= 0 then return end
				-- own character: no running while on the floor
				local isMine = player.Character == char
				local prevSpeed
				if isMine and hum then
					prevSpeed = hum.WalkSpeed
					hum.WalkSpeed = 0
				end
				task.wait(len + 1.0)
				rig:playAction("StandUp", { fade = 0.25 })
				local up = rig.clips.StandUp
				task.wait(up and up.duration or 0)
				if isMine and hum and prevSpeed and prevSpeed > 0 then
					hum.WalkSpeed = prevSpeed
				end
			end)
		end
	end)
end

local function hookPlayer(plr)
	plr.CharacterAdded:Connect(hookRig)
	if plr.Character then hookRig(plr.Character) end
end
Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end

-- NPC rigs: any top-level workspace model flagged XBotRig (e.g. new X Bot)
local function watchModel(m)
	if not m:IsA("Model") or Players:GetPlayerFromCharacter(m) then return end
	if m:GetAttribute("XBotRig") then
		task.spawn(hookRig, m)
	else
		local conn
		conn = m:GetAttributeChangedSignal("XBotRig"):Connect(function()
			if m:GetAttribute("XBotRig") then
				conn:Disconnect()
				task.spawn(hookRig, m)
			end
		end)
	end
end
workspace.ChildAdded:Connect(watchModel)
for _, m in ipairs(workspace:GetChildren()) do watchModel(m) end

-- Trial-gated actions: punch only with "push"; crouch only with "sneak".
local remotes = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
local push = remotes:WaitForChild("XBotPush", 15)
local crouch = remotes:WaitForChild("XBotCrouch", 15)

local function isCrouchKey(input)
	return input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C
end

-- gamepad crouch is a toggle: holding B while steering the stick is awkward
local gamepadCrouch = false
local function watchGamepadMoves(char)
	gamepadCrouch = false
	char:GetAttributeChangedSignal("XBotMoves"):Connect(function()
		if not string.find(char:GetAttribute("XBotMoves") or "", "sneak", 1, true) then
			gamepadCrouch = false
		end
	end)
end
player.CharacterAdded:Connect(watchGamepadMoves)
if player.Character then watchGamepadMoves(player.Character) end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local canAct = char and char:GetAttribute("XBotRig") and hum and hum.WalkSpeed > 0
	local moves = char and (char:GetAttribute("XBotMoves") or "") or ""
	local canSneak = canAct and string.find(moves, "sneak", 1, true) ~= nil
	local canPush = canAct and string.find(moves, "push", 1, true) ~= nil
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if not gameProcessed and push and canPush then push:FireServer() end
	elseif input.KeyCode == Enum.KeyCode.ButtonX then
		if not gameProcessed and push and canPush then push:FireServer() end
	elseif input.KeyCode == Enum.KeyCode.ButtonB then
		if not gameProcessed and crouch then
			if gamepadCrouch then
				gamepadCrouch = false
				crouch:FireServer(false)
			elseif canSneak then
				gamepadCrouch = true
				crouch:FireServer(true)
			end
		end
	elseif isCrouchKey(input) then
		-- hold to sneak
		if not gameProcessed and crouch and canSneak then crouch:FireServer(true) end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	-- releases always count, even if the UI swallowed the press
	if isCrouchKey(input) and crouch then
		crouch:FireServer(false)
	end
end)

print("[XBotAnimSync] online (sequence player)")
