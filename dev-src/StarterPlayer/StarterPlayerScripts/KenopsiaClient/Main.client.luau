--!nonstrict
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MenuController = require(script.Parent.Controllers.MenuController)
local TrialController = require(script.Parent.Controllers.TrialController)

local gui = playerGui:WaitForChild("KenopsiaGui", 20)
if not gui then
	warn("[Kenopsia] KenopsiaGui not found")
	return
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

local ok, menu = xpcall(function()
	return MenuController.new(gui)
end, function(err)
	warn("[Kenopsia] menu failed to start:\n" .. debug.traceback(tostring(err), 2))
	return nil
end)
if not ok or not menu then return end

local trialOk = xpcall(function()
	return TrialController.new(menu)
end, function(err)
	warn("[Kenopsia] trial controller failed to start:\n" .. debug.traceback(tostring(err), 2))
	return nil
end)
if not trialOk then warn("[Kenopsia] trials disabled this session") end

player.CharacterAdded:Connect(function()
	menu:applyCursor()
end)

print("[Kenopsia] terminal online")
