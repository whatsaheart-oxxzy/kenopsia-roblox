--!nonstrict
-- UI FX -- the CRT glass over the Machine (P2.2, 22.08.2026).
--
-- Lives in its OWN ScreenGui. Roblox caches a Gui's render geometry and drops
-- the whole cache when ANY descendant changes; KenopsiaMachine has 520
-- descendants, so every animated pixel in there re-rasterises all of them.
-- Everything that moves on the glass -- the refresh band, the interference
-- blip -- lives here instead, and nothing here ever touches the Machine's tree.
--
-- Honours GuiService.ReducedMotionEnabled (no band, no blip) and the player
-- attribute KenopsiaCRT (false = glass off; the settings panel sets it).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SCANLINE = "rbxassetid://73471354146575" -- 8x8 tile: 4 clear rows, 4 rows black at 30 %
local PHOSPHOR = Color3.fromHex("78FFAA")

local gui = Instance.new("ScreenGui")
gui.Name = "KenopsiaMachine_Overlay"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 60 -- above KenopsiaMachine (50), below the loading bridge (100)
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- 1) scanlines: one tiled, nearest-neighbour image. Static: zero per-frame cost.
local scan = Instance.new("ImageLabel")
scan.Name = "Scanlines"
scan.BackgroundTransparency = 1
scan.Image = SCANLINE
scan.ImageTransparency = 0.35
scan.ScaleType = Enum.ScaleType.Tile
scan.TileSize = UDim2.fromOffset(8, 8)
scan.ResampleMode = Enum.ResamplerMode.Pixelated
scan.Size = UDim2.fromScale(1, 1)
scan.ZIndex = 2
scan.Parent = gui

-- 2) vignette: four edge gradients, static.
local function edge(name, pos, size, rotation)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Position = pos
	f.Size = size
	f.ZIndex = 1
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	f.Parent = gui
end
edge("VignetteTop", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.14), 90)
edge("VignetteBottom", UDim2.fromScale(0, 0.86), UDim2.fromScale(1, 0.14), -90)
edge("VignetteLeft", UDim2.fromScale(0, 0), UDim2.fromScale(0.08, 1), 0)
edge("VignetteRight", UDim2.fromScale(0.92, 0), UDim2.fromScale(0.08, 1), 180)

-- 3) refresh band: a faint bright band sweeps top-to-bottom for 2 s, then the
--    glass is still for 8 s (the CSS-CRT timing: the silence is what sells it).
local band = Instance.new("Frame")
band.Name = "RefreshBand"
band.BackgroundColor3 = PHOSPHOR
band.BackgroundTransparency = 0.8
band.BorderSizePixel = 0
band.Size = UDim2.new(1, 0, 0, 110)
band.Position = UDim2.new(0, 0, 0, -120)
band.ZIndex = 3
local bandGradient = Instance.new("UIGradient")
bandGradient.Rotation = 90
bandGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 1),
})
bandGradient.Parent = band
band.Parent = gui

-- 4) interference blip: a 2-px bright line at a random height for 80 ms,
--    every 8-20 s. Decorrelated from the band so the two never fall in step.
local blip = Instance.new("Frame")
blip.Name = "Blip"
blip.BackgroundColor3 = PHOSPHOR
blip.BackgroundTransparency = 0.45
blip.BorderSizePixel = 0
blip.Size = UDim2.new(1, 0, 0, 2)
blip.Visible = false
blip.ZIndex = 3
blip.Parent = gui

gui.Parent = playerGui

local function crtOn()
	return player:GetAttribute("KenopsiaCRT") ~= false
end

local function motionOk()
	return crtOn() and not GuiService.ReducedMotionEnabled
		and player:GetAttribute("KenopsiaReduceFlicker") ~= true
end

local function applyToggle()
	local on = crtOn()
	scan.Visible = on
	for _, n in ipairs({ "VignetteTop", "VignetteBottom", "VignetteLeft", "VignetteRight" }) do
		local f = gui:FindFirstChild(n)
		if f then f.Visible = on end
	end
	-- phones read through a lighter glass: the lines must not eat the 10-px text
	local machine = playerGui:FindFirstChild("KenopsiaMachine")
	local platform = machine and machine:GetAttribute("Platform")
	scan.ImageTransparency = (platform == "Mobile") and 0.55 or 0.35
end
applyToggle()
player:GetAttributeChangedSignal("KenopsiaCRT"):Connect(applyToggle)
task.defer(function()
	local machine = playerGui:WaitForChild("KenopsiaMachine", 30)
	if machine then
		applyToggle()
		machine:GetAttributeChangedSignal("Platform"):Connect(applyToggle)
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(8)
		if motionOk() then
			local cam = workspace.CurrentCamera
			local vh = cam and cam.ViewportSize.Y or 720
			band.Position = UDim2.new(0, 0, 0, -120)
			local tw = TweenService:Create(band, TweenInfo.new(2, Enum.EasingStyle.Linear), {
				Position = UDim2.new(0, 0, 0, vh + 10),
			})
			tw:Play()
			tw.Completed:Wait()
		end
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(8 + math.random() * 12)
		if motionOk() then
			blip.Position = UDim2.new(0, 0, math.random(), 0)
			blip.Visible = true
			task.wait(0.08)
			blip.Visible = false
		end
	end
end)
