--!nonstrict
-- CHARACTER SERVICE -- the PS1 rig as the player character, everywhere (P3.3, 22.08.2026).
--
-- StarterPlayer.StarterCharacter is the PS1Player rig with a Humanoid (built in
-- Studio, attribute KenopsiaPS1). This service:
--   * honours GameConfig.Character.UsePS1Rig: false removes the StarterCharacter
--     at boot and Roblox avatars load exactly as before;
--   * scales every spawned character to GameConfig.Character.Scale and sets the
--     hip height to match (2.95 rig units from the hip root's bottom to the soles);
--   * forbids jumping on every character, rig or avatar (JumpPower 0, state off);
--   * owns the crouch remote the client already fires (XBotCrouch) and mirrors
--     it onto the character as the `Crouching` attribute -- only while the
--     running trial allows it (XBotMoves contains "sneak"), cleared otherwise.
-- The trials keep owning WalkSpeed; the clip follows the speed, not the other
-- way round (StarterCharacterScripts/PS1Animate).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("GameConfig"))

local HIP_UNITS = 2.95 -- hip root's bottom above the soles on the PS1Player rig, scale 1

local CharacterService = {}

local function characterConfig()
	local c = type(Config.Character) == "table" and Config.Character or {}
	return {
		usePS1 = c.UsePS1Rig ~= false,
		scale = tonumber(c.Scale) or 1,
	}
end

local function sneakAllowed(char)
	return string.find(char:GetAttribute("XBotMoves") or "", "sneak", 1, true) ~= nil
end

local function onCharacter(char)
	local cfg = characterConfig()
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.JumpHeight = 0
	pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
	if char:GetAttribute("KenopsiaPS1") == true then
		if math.abs(cfg.scale - 1) > 0.001 then
			pcall(function() char:ScaleTo(cfg.scale) end)
		end
		hum.HipHeight = HIP_UNITS * cfg.scale
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
	end
	char:SetAttribute("Crouching", false)
	char:GetAttributeChangedSignal("XBotMoves"):Connect(function()
		if not sneakAllowed(char) then char:SetAttribute("Crouching", false) end
	end)
end

function CharacterService.start()
	local cfg = characterConfig()
	local starter = StarterPlayer:FindFirstChild("StarterCharacter")
	if not cfg.usePS1 and starter then
		starter:Destroy()
		print("[CharacterService] PS1 rig off - Roblox avatars load")
	elseif cfg.usePS1 and not starter then
		warn("[CharacterService] GameConfig.Character.UsePS1Rig is on but StarterPlayer.StarterCharacter is missing")
	end

	local remotes = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	local crouch = remotes:FindFirstChild("XBotCrouch")
	if not crouch then
		crouch = Instance.new("RemoteEvent")
		crouch.Name = "XBotCrouch"
		crouch.Parent = remotes
	end
	crouch.OnServerEvent:Connect(function(player, on)
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (hum and hum.Health > 0) then return end
		char:SetAttribute("Crouching", on == true and sneakAllowed(char))
	end)

	local function hook(player)
		if player.Character then task.spawn(onCharacter, player.Character) end
		player.CharacterAdded:Connect(onCharacter)
	end
	for _, p in Players:GetPlayers() do hook(p) end
	Players.PlayerAdded:Connect(hook)
end

return CharacterService
