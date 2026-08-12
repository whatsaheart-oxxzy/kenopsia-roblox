--!nonstrict
-- MENU PRESENCE (Gate M1 §2).
--
-- The DEV main menu is a 3D scene, and the player's own character stands in it.
-- This service owns that character while the menu is up: it parks it on
-- MenuStage.CharacterAnchor, freezes movement, jump and rotation, drops its
-- collisions and hides its nametag, then hands it back untouched the moment a
-- run starts.
--
-- Server-authoritative by design. The player attribute `KenopsiaMenuActive` is
-- the single source of truth for "this player is in the menu", it is written
-- ONLY here, and clients must never set it -- the camera and overlay
-- controllers read it, they do not decide it.
--
-- Every operation is idempotent. Respawns, double CharacterAdded, a release
-- that arrives before an engage, and the reconciliation loop below can all run
-- in any order without corrupting the saved state.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MenuPresenceService = {}

local ATTR = "KenopsiaMenuActive"
local RECONCILE_INTERVAL = 1

local RoomServiceRef
local started = false

-- [userId] = { character, humanoid, saved = {...} }
-- `saved` holds the ORIGINAL values captured at engage time. Nothing is
-- hardcoded: whatever the rig shipped with is what gets restored, so changing
-- the rig's WalkSpeed or JumpPower in Studio does not silently break release().
local held = {}

local function anchorPart()
	local stage = workspace:FindFirstChild("MenuStage")
	return stage and stage:FindFirstChild("CharacterAnchor") or nil
end

local function partsOf(character)
	local out = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then table.insert(out, d) end
	end
	return out
end

-- True while the player should be standing in the menu: not in a room, or in
-- one that has not started running yet. A room in Starting still shows the menu
-- -- the countdown plays over it.
local function shouldBeInMenu(player)
	if not RoomServiceRef then return true end
	local room = RoomServiceRef.roomOf(player)
	if not room then return true end
	return room.phase ~= "Playing"
end

local function engage(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then return end

	-- Re-engaging the same character is a no-op. Without this the reconciliation
	-- loop would overwrite `saved` with the already-frozen values, and release()
	-- would then restore WalkSpeed 0 as if it were the original.
	local entry = held[player.UserId]
	if entry and entry.character == character then
		local anchor = anchorPart()
		if anchor then root.CFrame = anchor.CFrame end
		return
	end

	-- PrimaryPart cannot be set through the MCP property layer (no Instance type),
	-- so it is corrected here instead of on the saved template. Doing it on every
	-- CharacterAdded is strictly more robust: it survives respawns and does not
	-- depend on StarterCharacter being authored correctly.
	character.PrimaryPart = root

	local saved = {
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		useJumpPower = humanoid.UseJumpPower,
		autoRotate = humanoid.AutoRotate,
		displayDistanceType = humanoid.DisplayDistanceType,
		rootAnchored = root.Anchored,
		collide = {},
	}
	for _, part in partsOf(character) do
		saved.collide[part] = part.CanCollide
		part.CanCollide = false
	end

	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.Jump = false
	humanoid.AutoRotate = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)

	local anchor = anchorPart()
	if anchor then
		root.CFrame = anchor.CFrame
		-- Anchoring is the only reliable way to stop drift and shoving while four
		-- characters share one collision-free anchor. This is a RUNTIME anchor and
		-- is always undone by release(); the rig template itself stays unanchored,
		-- which is what the gate requires.
		root.Anchored = true
	end

	held[player.UserId] = { character = character, humanoid = humanoid, saved = saved }
	player:SetAttribute(ATTR, true)
end

local function release(player)
	local entry = held[player.UserId]
	held[player.UserId] = nil
	player:SetAttribute(ATTR, false)
	if not entry then return end

	local character, humanoid, saved = entry.character, entry.humanoid, entry.saved
	if not (character and character.Parent and humanoid and humanoid.Parent) then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = saved.rootAnchored end

	-- Restore only the parts still present. A part destroyed while the menu was
	-- up (accessory swap, respawn race) is simply skipped rather than erroring.
	for part, canCollide in saved.collide do
		if part.Parent then part.CanCollide = canCollide end
	end

	humanoid.WalkSpeed = saved.walkSpeed
	humanoid.UseJumpPower = saved.useJumpPower
	humanoid.JumpPower = saved.jumpPower
	humanoid.JumpHeight = saved.jumpHeight
	humanoid.AutoRotate = saved.autoRotate
	humanoid.DisplayDistanceType = saved.displayDistanceType
	pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
end

-- Public: the trial/teleport path calls this to take the character back.
function MenuPresenceService.releasePlayer(player)
	release(player)
end

function MenuPresenceService.releaseRoom(room)
	if not room then return end
	for _, m in room.members do
		local plr = Players:GetPlayerByUserId(m.userId)
		if plr then release(plr) end
	end
end

function MenuPresenceService.isMenuActive(player)
	return player:GetAttribute(ATTR) == true
end

local function bindCharacter(player, character)
	if shouldBeInMenu(player) then
		engage(player, character)
	else
		player:SetAttribute(ATTR, false)
	end
end

local function bindPlayer(player)
	player:SetAttribute(ATTR, false)
	player.CharacterAdded:Connect(function(character)
		-- CharacterAdded fires before descendants finish replicating; wait for the
		-- root rather than racing it.
		if not character:FindFirstChild("HumanoidRootPart") then
			character:WaitForChild("HumanoidRootPart", 5)
		end
		bindCharacter(player, character)
	end)
	if player.Character then bindCharacter(player, player.Character) end
end

function MenuPresenceService.start(RoomService)
	if started then return end
	started = true
	RoomServiceRef = RoomService

	for _, player in Players:GetPlayers() do bindPlayer(player) end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		held[player.UserId] = nil
	end)

	-- A run starting is the explicit handover point.
	if RoomService and RoomService.RunRequested then
		RoomService.RunRequested:Connect(function(roomId)
			MenuPresenceService.releaseRoom(RoomService.getRoom(roomId))
		end)
	end

	-- Reconciliation backstop. RoomService.finishRun() moves a room back to
	-- Waiting without firing an event, so rather than adding a new signal to a
	-- file this gate is not meant to touch, presence is re-derived here. It is
	-- also what heals any state the event path missed. Cheap at 2-4 players, and
	-- safe because engage() and release() are both idempotent.
	task.spawn(function()
		while true do
			task.wait(RECONCILE_INTERVAL)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local wants = shouldBeInMenu(player)
				local has = held[player.UserId] ~= nil
				if wants and character and not has then
					bindCharacter(player, character)
				elseif not wants and has then
					release(player)
				end
			end
		end
	end)

	print("[MenuPresenceService] online" .. (RunService:IsStudio() and " (studio)" or ""))
end

return MenuPresenceService
