-- Kenopsia - client entry point.
--
-- The client is deliberately thin. It renders state and forwards intent; it
-- decides nothing. If you catch yourself computing a score or validating an
-- answer in this folder, that logic belongs on the server.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local HUD = require(script.HUD)
local RecallUI = require(script.RecallUI)

local player = Players.LocalPlayer
local LineFeedback = Net.get("LineFeedback")
local GrateReveal = Net.get("GrateReveal")

HUD.mount()
RecallUI.mount()

-- Roblox's default backpack and chat clutter a game with this much screen text.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- THE LINE feedback -----------------------------------------------------------
-- Short, loud, and non-blocking. A rejected submission needs to be legible in
-- peripheral vision while the player is already running somewhere else.

local feedback = Instance.new("ScreenGui")
feedback.Name = "KenopsiaFeedback"
feedback.ResetOnSpawn = false
feedback.IgnoreGuiInset = true
feedback.Parent = player:WaitForChild("PlayerGui")

local flash = Instance.new("TextLabel")
flash.Size = UDim2.new(1, 0, 0, 40)
flash.Position = UDim2.fromScale(0, 0.6)
flash.BackgroundTransparency = 1
flash.Font = Enum.Font.Code
flash.TextSize = 28
flash.TextTransparency = 1
flash.Parent = feedback

local flashToken = 0

local function showFlash(text: string, color: Color3)
	flashToken += 1
	local token = flashToken
	flash.Text = text
	flash.TextColor3 = color
	flash.TextTransparency = 0
	task.delay(1.2, function()
		if flashToken == token then
			flash.TextTransparency = 1
		end
	end)
end

LineFeedback.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "accepted" then
		showFlash("ACCEPTED", Config.Colors.Accent)
	elseif payload.kind == "rejected" then
		showFlash("REJECTED", Config.Colors.Warn)
	elseif payload.kind == "empty" then
		showFlash("NOTHING TO SUBMIT", Config.Colors.Warn)
	end
end)

-- THE GRATE feedback ----------------------------------------------------------
-- Pad colours already replicate as part properties, so this hook exists purely
-- for the punch: a camera shake or a stinger when someone finds a bad tile.
-- Left as a no-op rather than a stub that does something wrong.

GrateReveal.OnClientEvent:Connect(function(_index, isSafe)
	if isSafe then
		return
	end
	-- TODO Phase 6: camera shake + Rust & Blood SFX hit here.
end)

print("[Kenopsia] client ready")
