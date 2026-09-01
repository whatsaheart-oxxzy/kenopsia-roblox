--!nonstrict
-- SUPPLY CLIENT (01.09.2026) -- the thin host under SupplyKit.
--
-- Owns everything the kit deliberately does not: the ScreenGui with the
-- lobby button, the remotes, the MachineState subscription, the platform /
-- sound / motion answers, and the ONE stepped loop (Feel.Step.Fps, the
-- MainMenu rule -- no RenderStepped anywhere in this file or the kit).
--
-- Visibility contract: the SUPPLY button lives in the lobby only. It hides
-- and the panel closes the moment the player's KenopsiaTrialId attribute is
-- set (MachineFlow stamps it per trial), and it stays out of the way while
-- the title terminal (KenopsiaMenu) is open. The gap between two trials can
-- show the button for a beat -- accepted; the SERVER is the gate that
-- matters and it denies every action for a session participant.
--
-- Zero KenopsiaClient edits, zero input binds: the standalone-LocalScript
-- pattern of SocialClient / GradeDirector, applied to the supply screens.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Kenopsia = ReplicatedStorage:WaitForChild("Kenopsia")
local Config = Kenopsia:WaitForChild("Shared"):WaitForChild("Config")
local Rules = Kenopsia:WaitForChild("Shared"):WaitForChild("Rules")
local SupplyConfig = require(Config:WaitForChild("SupplyConfig"))
local EmoteRegistry = require(Config:WaitForChild("EmoteRegistry"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Feel = require(Config:WaitForChild("FeelConfig"))
local CrateRules = require(Rules:WaitForChild("CrateRules"))
local ProgressionRules = require(Rules:WaitForChild("ProgressionRules"))
local SupplyKit = require(script.Parent:WaitForChild("SupplyKit"))

local STEP = Feel.stepSeconds()

-- REMOTES ----------------------------------------------------------------------
-- MachineState exists from MachineFlow.start; CrateOpen/SupplySync are created
-- by CrateService.start. All waited with a timeout so a place that boots
-- without the service leaves a quiet, dead button instead of a hang.
local remotesFolder = Kenopsia:WaitForChild("Remotes")
local function remote(name)
	local r = remotesFolder:WaitForChild(name, 30)
	if not r then warn("[SupplyClient] remote missing: " .. name) end
	return r
end
local machineState = remote("MachineState")
local emotePlay = remote("EmotePlay")
local emoteEquip = remote("EmoteEquip")
local shopPrompt = remote("ShopPrompt")
local crateOpen = remote("CrateOpen")
local supplySync = remote("SupplySync")

local function fire(r, payload)
	if r then pcall(r.FireServer, r, payload) end
end

-- PLATFORM / SOUND / MOTION (the MainMenu answers, unchanged) -------------------
local machine = nil
local function machineGui()
	if machine and machine.Parent then return machine end
	machine = playerGui:FindFirstChild("KenopsiaMachine")
	return machine
end

local function isMobile()
	local m = machineGui()
	local p = (m and m:GetAttribute("Platform")) or "Desktop"
	return p == "Mobile" or p == "Tablet"
end

local function motionOk()
	return not GuiService.ReducedMotionEnabled and player:GetAttribute("KenopsiaReduceFlicker") ~= true
end

local function sfx(name)
	if player:GetAttribute("KenopsiaUiSound") == false then return end
	local audio = SoundService:FindFirstChild("KenopsiaAudio")
	local folder = audio and audio:FindFirstChild("SFX")
	local s = folder and folder:FindFirstChild(name)
	if s and s.SoundId ~= "" then
		if s.SoundGroup == nil then s.SoundGroup = SoundService:FindFirstChild("KenopsiaUI") end
		SoundService:PlayLocalSound(s)
	end
end

-- THE KIT -----------------------------------------------------------------------
local kit = SupplyKit.create({
	playerGui = playerGui,
	palette = SupplyConfig.Palette,
	rarity = SupplyConfig.Rarity,
	crate = SupplyConfig.Crate,
	reveal = SupplyConfig.Reveal,
	strings = SupplyConfig.Strings,
	layout = SupplyConfig.Layout,
	registry = EmoteRegistry,
	money = MonetizationConfig,
	rules = CrateRules,
	fragmentsPerKey = tonumber(ProgressionRules.FRAGMENTS_PER_KEY) or 3,
	stepSeconds = STEP,
	platform = isMobile,
	sfx = sfx,
	motionOk = motionOk,
	send = {
		play = function(id)
			fire(emotePlay, { emoteId = id })
		end,
		equip = function(slot, id)
			fire(emoteEquip, { slot = slot, emoteId = id })
		end,
		shop = function(sku)
			fire(shopPrompt, { sku = sku })
		end,
		open = function()
			fire(crateOpen, {})
		end,
		sync = function()
			fire(supplySync, {})
		end,
	},
})

if machineState then
	machineState.OnClientEvent:Connect(function(packet)
		pcall(function()
			kit:onPacket(packet)
		end)
	end)
end

-- THE LOBBY BUTTON ---------------------------------------------------------------
local btnGui = Instance.new("ScreenGui")
btnGui.Name = "KenopsiaSupplyButton"
btnGui.IgnoreGuiInset = true
btnGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
btnGui.DisplayOrder = 54
btnGui.ResetOnSpawn = false

local btn = Instance.new("TextButton")
btn.Name = "Btn_SUPPLY"
btn.AutoButtonColor = false
btn.AnchorPoint = Vector2.new(1, 1)
btn.Position = UDim2.new(1, -16, 1, -16)
btn.Size = UDim2.fromOffset(SupplyConfig.Layout.ButtonW, isMobile() and SupplyConfig.Layout.TouchRowH or SupplyConfig.Layout.ButtonH)
btn.BackgroundColor3 = Color3.fromHex(SupplyConfig.Palette.PLATE)
btn.BorderSizePixel = 0
btn.Font = Enum.Font.Code
btn.Text = SupplyConfig.Strings.BUTTON
btn.TextSize = 18
btn.TextColor3 = Color3.fromHex(SupplyConfig.Palette.GREEN_SOFT)
btn.Parent = btnGui
local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromHex(SupplyConfig.Palette.GREEN_DIM)
btnStroke.Transparency = 0.4
btnStroke.Parent = btn

btn.MouseEnter:Connect(function()
	btn.TextColor3 = Color3.fromHex(SupplyConfig.Palette.GREEN)
	sfx("Hover")
end)
btn.MouseLeave:Connect(function()
	btn.TextColor3 = Color3.fromHex(SupplyConfig.Palette.GREEN_SOFT)
end)
btn.Activated:Connect(function()
	sfx("Click")
	if kit:isOpen() then
		kit:close()
	else
		kit:open()
	end
end)
btnGui.Parent = playerGui

-- VISIBILITY ---------------------------------------------------------------------
local function inTrial()
	local id = player:GetAttribute("KenopsiaTrialId")
	return type(id) == "string" and id ~= ""
end

local function menuOpen()
	local menu = playerGui:FindFirstChild("KenopsiaMenu")
	return menu ~= nil and menu.Enabled == true
end

player:GetAttributeChangedSignal("KenopsiaTrialId"):Connect(function()
	if inTrial() then
		kit:close()
		btnGui.Enabled = false
	end
end)

-- ONE LOOP ------------------------------------------------------------------------
-- Kit animation only while the panel is open; the button's visibility check
-- rides the same loop at a slower cadence (every ~0.25 s), compare-before-write.
task.spawn(function()
	local sinceVis = 0
	while true do
		task.wait(STEP)
		local now = os.clock()
		if kit:isOpen() then kit:step(now) end
		sinceVis = sinceVis + STEP
		if sinceVis >= 0.25 then
			sinceVis = 0
			local want = not inTrial() and not menuOpen()
			if btnGui.Enabled ~= want then btnGui.Enabled = want end
			if not want and kit:isOpen() then kit:close() end
		end
	end
end)

-- Warm the state once the server is fully up: the join-time emotestate can
-- predate this script's MachineState connection.
task.delay(5, function()
	fire(supplySync, {})
end)
