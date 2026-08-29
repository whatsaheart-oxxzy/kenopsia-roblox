--!nonstrict
-- LIGHT GUARD -- mobile black-world sentinel (G1).
--
-- Roblox has no pixel readback, so this is an honest heuristic: 3s after
-- join, if the saved render quality is low (Automatic or <= 4) on a touch
-- device, raise the local ambient floor a little (client-side Lighting writes
-- never replicate) and report ONE diagnostic "MobileBlackScreen" telemetry
-- event -- it fires on the heuristic, not on a proven black frame; the name
-- is kept for the analytics counter. Desktop / healthy clients: pure no-op.
-- Safe when the remote never appears (published place without server update)
-- and when UserGameSettings errors. No loops, no RenderStepped.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local CONFIG = {
	DelaySeconds = 3,
	LowQualityMax = 4, -- SavedQualitySetting: Automatic (0) .. QualityLevel4
	AmbientDelta = { R = 14, G = 16, B = 20 }, -- RGB floor added client-side
	RemoteTimeout = 10,
}

local function addClamped(color) -- Color3 has no + operator; add per channel
	return Color3.new(
		math.min(color.R + CONFIG.AmbientDelta.R / 255, 1),
		math.min(color.G + CONFIG.AmbientDelta.G / 255, 1),
		math.min(color.B + CONFIG.AmbientDelta.B / 255, 1)
	)
end

task.delay(CONFIG.DelaySeconds, function()
	if not UserInputService.TouchEnabled then return end -- desktop: no-op

	local quality = nil
	pcall(function()
		quality = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if quality == nil or quality > CONFIG.LowQualityMax then return end
	-- 0 is Automatic, 1..4 the low tiers -- both count as at-risk

	local texMB = -1 -- -1 = unknown (Stats read failed)
	pcall(function()
		-- bucket to 25 MB steps: the server folds this into an analytics
		-- CustomField category string, and raw floats would make every
		-- event a unique breakdown value
		local raw = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture)
		texMB = math.floor(raw / 25 + 0.5) * 25
	end)

	pcall(function()
		Lighting.Ambient = addClamped(Lighting.Ambient)
		Lighting.OutdoorAmbient = addClamped(Lighting.OutdoorAmbient)
		Lighting:SetAttribute("KenopsiaLowLight", true)
	end)

	pcall(function()
		local kenopsia = ReplicatedStorage:WaitForChild("Kenopsia", CONFIG.RemoteTimeout)
		local remotes = kenopsia and kenopsia:WaitForChild("Remotes", CONFIG.RemoteTimeout)
		local remote = remotes and remotes:WaitForChild("TelemetryEvent", CONFIG.RemoteTimeout)
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer({
				event = "MobileBlackScreen",
				quality = quality,
				texMB = texMB,
				touch = UserInputService.TouchEnabled,
			})
		end
	end)
end)
