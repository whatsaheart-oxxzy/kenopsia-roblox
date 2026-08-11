-- Kenopsia - server entry point.
--
-- Boot order matters: Net must construct its remotes before any service tries
-- to Net.get() one, and RoundService must be last because it starts an infinite
-- loop the moment it is called.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local State = require(Shared.State)

local ScoreService = require(script.ScoreService)
local RoundService = require(script.RoundService)

-- Remotes and the replicated state folder exist from this line onward.
Net.get("RoundEvent")
State.setPhase("Lobby")

-- Roblox has no scriptable max-player setting; it lives in Game Settings.
-- This warns loudly if the place is misconfigured, because THE LINE's scarcity
-- tuning assumes a hard ceiling of 8.
if Players.MaxPlayers > Config.MaxPlayers then
	warn(
		`[Kenopsia] Players.MaxPlayers is {Players.MaxPlayers} but the game is tuned for {Config.MaxPlayers}. `
			.. `Set it in Home > Game Settings > Basic Info > Max Players.`
	)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Clear any carry state that survived a respawn mid-round.
		player:SetAttribute("Carrying", nil)
		player:SetAttribute("LineLockedUntil", nil)

		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			-- Freeze late arrivals until the next phase change picks them up,
			-- so nobody spawns running into an arena mid-round.
			local phase = State.getPhase()
			if phase == "Countdown" or phase == "Score" or phase == "Announce" then
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
			end
		end
	end)
	ScoreService.publish()
end)

Players.PlayerRemoving:Connect(function()
	ScoreService.publish()
end)

RoundService.start()

print("[Kenopsia] server ready")
