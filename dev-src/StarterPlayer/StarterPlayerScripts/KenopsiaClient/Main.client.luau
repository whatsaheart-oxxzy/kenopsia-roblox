--!nonstrict
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MenuController = require(script.Parent.Controllers.MenuController)
local MenuSceneController = require(script.Parent.Controllers.MenuSceneController)
local MenuOverlayController = require(script.Parent.Controllers.MenuOverlayController)
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

-- The 3D scene is started after the menu so it can share the live settings
-- table (Animations / Reduce Effects drive the camera's reduced-motion path).
-- It is deliberately non-fatal: a failure here must not take the menu down,
-- because the 2D UI is still fully usable without the camera move.
local sceneOk = xpcall(function()
	return MenuSceneController.start(menu.settings)
end, function(err)
	warn("[Kenopsia] menu scene failed to start:\n" .. debug.traceback(tostring(err), 2))
	return nil
end)
if not sceneOk then warn("[Kenopsia] menu scene disabled this session") end

-- The flat landing layer. It shares the SAME settings table as MenuController,
-- so the new panel and the legacy CRT settings screen cannot disagree while
-- both exist during the §3 transition. Appliers delegate to the methods that
-- already own each effect rather than reimplementing them.
local overlayOk, overlay = xpcall(function()
	return MenuOverlayController.new({
		scene = MenuSceneController,
		settings = menu.settings,
		appliers = {
			textScale = function(v) menu:applyTextScale(v) end,
			retroFilter = function(v) menu:applyIntensity(v) end,
			cursor = function() menu:applyCursor() end,
		},
	})
end, function(err)
	warn("[Kenopsia] landing overlay failed to start:\n" .. debug.traceback(tostring(err), 2))
	return nil
end)
if not overlayOk then warn("[Kenopsia] landing overlay disabled this session") end

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
