--!nonstrict
-- BIRD HUNTING PUSH SENDER (Phase 3c, 30.08.2026) -- its own LocalScript,
-- DELIBERATELY not in KenopsiaClient: the monolith's main chunk sits at
-- ~185/200 Luau locals (see the SonarClient header, the script this one is
-- modelled on line for line), and one more binding there risks the whole
-- script no longer compiling. This script shares NOTHING with it but the
-- remotes.
--
-- It only SENDS. The server owns the push budget (Feel.Birdhunt.PushesPerLeg),
-- the range check, the prop choice, the topple and the leg-end restore; a
-- duplicate, early, spent or out-of-range press is dropped server-side in
-- silence -- a naive sender is safe (the SonarClient verdict, ported).
--
-- WHY NOT XBotMoves "push" / Btn_PUNCH: KenopsiaClient's charPushAllowed()
-- keys the legacy Btn_PUNCH off "push" in XBotMoves, and that button fires
-- XBotPush -- a remote NO server creates or handles (stranded since Gate 1;
-- its client WaitForChild times out and the press no-ops). Granting "push"
-- would surface that dead button on every touch device next to this one.
-- This sender gates on "sneak" instead -- the move Bird Hunting alone grants
-- (scan = Dead Zone, eat = Canteen), so it can never arm in another trial.
--
-- Inputs: R (keyboard), ButtonB (gamepad -- KenopsiaClient holds Y for the
-- scope, SonarClient holds X), and an own 72 px touch button in an OWN
-- ScreenGui (never inside the Machine's TouchControls frame). The two touch
-- buttons can share a screen slot: the scan gate ("scan") and this gate
-- ("sneak") are disjoint, so they never show together.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
local TrialInput = remotes:WaitForChild("TrialInput", 20)
local MachineState = remotes:WaitForChild("MachineState", 20)

-- Token cache: Bird's runner role packet ({kind="role", role="runner",
-- frozen=true, roundToken=..}) carries the leg token since Phase 3c;
-- role="none"/"spectate" drops it. Catching ANOTHER trial's token (Minefield's
-- runner packet has the same shape) is harmless: the server checks trialId
-- AND token, and the "sneak" gate below keeps this sender quiet outside Bird
-- legs anyway. Multiple OnClientEvent connections beside the KenopsiaClient
-- dispatcher are expressly fine (the SonarClient verdict).
local roundToken = nil
local pushReadyAt = 0

-- The XBotMoves gate, SonarClient's scanAllowed() one trial over. The design
-- attribute KenopsiaActiveTrial is stamped by nobody in the live place
-- (Recon 29.08.), so it only counts IF it exists; XBotMoves is the real gate.
local function pushAllowed()
	local trial = player:GetAttribute("KenopsiaActiveTrial")
	if trial ~= nil and trial ~= "birdhunt" then return false end
	local char = player.Character
	if not char then return false end
	local moves = char:GetAttribute("XBotMoves")
	return type(moves) == "string" and string.find(moves, "sneak", 1, true) ~= nil
end

local function firePush()
	if not TrialInput then return end
	if not roundToken then return end
	if not pushAllowed() then return end
	local now = os.clock()
	if now < pushReadyAt then return end
	-- 0.5 mirrors the server's 0.4 s floor, a hair above it.
	pushReadyAt = now + 0.5
	TrialInput:FireServer({
		trialId = "birdhunt",
		action = "push",
		roundToken = roundToken,
	})
	-- No local receipt ON PURPOSE: the topple is server parts everyone sees,
	-- and PS1Animate has no one-shot action channel to play the Push clip
	-- through (its attribute set is gait-only: Crouching / XBotCrawl /
	-- Injured / XBotRifle). The falling crate IS the feedback; a press with
	-- nothing in range correctly feels like nothing.
end

if MachineState then
	MachineState.OnClientEvent:Connect(function(p)
		if type(p) ~= "table" then return end
		if p.kind ~= "role" then return end
		if p.role == "runner" and p.roundToken ~= nil then
			roundToken = p.roundToken
		elseif p.role == "none" or p.role == "spectate" then
			roundToken = nil
		end
	end)
end

-- Keyboard / gamepad: ONE press = ONE push attempt, never auto-repeat -- the
-- budget (one per leg) demands deliberate spending. gameProcessed swallows
-- chat / UI presses.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonB then
		firePush()
	end
end)

-- Touch: own ScreenGui, one 72x72 px button (>= 64 px minimum target), the
-- same slot SonarClient's PULSE button uses -- the gates are disjoint, so the
-- slot is never contested. Visible only on touch devices while a Bird leg
-- allows the push.
local gui = Instance.new("ScreenGui")
gui.Name = "BHPushGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Name = "Btn_PUSH"
btn.Size = UDim2.fromOffset(72, 72)
btn.AnchorPoint = Vector2.new(1, 1)
btn.Position = UDim2.new(1, -18, 1, -170)
btn.BackgroundColor3 = Color3.fromRGB(16, 22, 19)
btn.BackgroundTransparency = 0.25
btn.BorderSizePixel = 0
btn.Font = Enum.Font.Code
btn.TextSize = 16
btn.TextColor3 = Color3.fromRGB(140, 232, 174)
btn.Text = "PUSH"
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = btn

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(46, 107, 74)
stroke.Thickness = 1
stroke.Parent = btn

btn.Activated:Connect(firePush)

-- Visibility poll instead of attribute signals: the character is re-stamped
-- every leg and can respawn; a 0.5 s poll is cheaper than the web of
-- connections that would cover both (the SonarClient pattern).
task.spawn(function()
	while true do
		gui.Enabled = UserInputService.TouchEnabled
			and roundToken ~= nil
			and pushAllowed()
		task.wait(0.5)
	end
end)
