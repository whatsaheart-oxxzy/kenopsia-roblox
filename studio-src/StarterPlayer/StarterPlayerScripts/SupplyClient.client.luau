--!nonstrict
-- SUPPLY CLIENT (01.09.2026, v2) -- the thin host under SupplyKit.
--
-- Owns everything the kit deliberately does not: the remotes, the
-- MachineState subscription, the platform / sound / motion answers, and the
-- ONE stepped loop (Feel.Step.Fps, the MainMenu rule -- no RenderStepped
-- anywhere in this file or the kit). v2: the kit brings its own edge tab +
-- sliding rail, so this host no longer builds a button -- it only decides
-- WHEN the whole surface exists on screen.
--
-- Visibility contract: lobby only. The surface hides and every panel closes
-- the moment the player's KenopsiaTrialId attribute is set (MachineFlow
-- stamps it per trial), and it stays hidden while the title terminal
-- (KenopsiaMenu) is open. The gap between two trials can flash the tab for a
-- beat -- accepted; the SERVER gates every action for a session participant.
--
-- Zero KenopsiaClient edits, zero input binds: the standalone-LocalScript
-- pattern of SocialClient / GradeDirector, applied to the supply surface.
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
local PromoRules = require(Rules:WaitForChild("PromoRules"))
local ProgressionRules = require(Rules:WaitForChild("ProgressionRules"))
local SupplyKit = require(script.Parent:WaitForChild("SupplyKit"))

local STEP = Feel.stepSeconds()

-- REMOTES ----------------------------------------------------------------------
-- MachineState exists from MachineFlow.start; CrateOpen/SupplySync come from
-- CrateService.start, PromoRedeem from PromoService.start. All waited with a
-- timeout so a place that boots without a service leaves a quiet, dead
-- surface instead of a hang.
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
local promoRedeem = remote("PromoRedeem")

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
	motion = SupplyConfig.Motion,
	registry = EmoteRegistry,
	money = MonetizationConfig,
	rules = CrateRules,
	promo = PromoRules,
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
		redeem = function(code)
			fire(promoRedeem, { code = code })
		end,
	},
})
kit:setVisible(false) -- the loop below decides when the surface exists

if machineState then
	machineState.OnClientEvent:Connect(function(packet)
		pcall(function()
			kit:onPacket(packet)
		end)
	end)
end

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
	if inTrial() then kit:setVisible(false) end
end)

-- ONE LOOP ------------------------------------------------------------------------
-- Kit animation only while the surface is on screen; the visibility check
-- rides the same loop at a slower cadence (every ~0.25 s), compare-before-write.
task.spawn(function()
	local sinceVis = 0
	while true do
		task.wait(STEP)
		local now = os.clock()
		if kit.gui and kit.gui.Enabled then kit:step(now) end
		sinceVis = sinceVis + STEP
		if sinceVis >= 0.25 then
			sinceVis = 0
			local want = not inTrial() and not menuOpen()
			kit:setVisible(want)
		end
	end
end)

-- Warm the state once the server is fully up: the join-time emotestate can
-- predate this script's MachineState connection.
task.delay(5, function()
	fire(supplySync, {})
end)
