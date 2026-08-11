-- Round HUD. Built entirely in code so it renders correctly before any art
-- exists, and so there is no StarterGui instance to keep in sync with Rojo.
--
-- The countdown reads State.timeLeft() every frame LOCALLY. The server never
-- sends a ticking number - it published one absolute end time when the phase
-- began. That is the difference between one attribute write per phase and
-- sixty per second per player.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local State = require(Shared.State)

local player = Players.LocalPlayer
local RoundEvent = Net.get("RoundEvent")
local Scoreboard = Net.get("Scoreboard")

local HUD = {}

local MONO = Enum.Font.Code

local function label(parent: Instance, size: UDim2, position: UDim2): TextLabel
	local text = Instance.new("TextLabel")
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.Font = MONO
	text.TextColor3 = Color3.fromRGB(214, 214, 206)
	text.TextStrokeTransparency = 0.6
	text.Parent = parent
	return text
end

function HUD.mount()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KenopsiaHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Top bar: phase, minigame name, timer.
	local phaseText = label(gui, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 12))
	phaseText.TextScaled = false
	phaseText.TextSize = 20
	phaseText.Text = ""

	local timerText = label(gui, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 40))
	timerText.TextSize = 38
	timerText.TextColor3 = Config.Colors.Accent
	timerText.Text = ""

	-- Centre announce card, used for the Announce phase and results.
	local announce = label(gui, UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0.36, 0))
	announce.TextSize = 64
	announce.Text = ""
	announce.TextTransparency = 1

	local announceSub = label(gui, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.36, 84))
	announceSub.TextSize = 20
	announceSub.TextColor3 = Config.Colors.Accent
	announceSub.Text = ""
	announceSub.TextTransparency = 1

	-- Standings, top-right.
	local standings = Instance.new("Frame")
	standings.Size = UDim2.new(0, 220, 0, 200)
	standings.Position = UDim2.new(1, -232, 0, 12)
	standings.BackgroundColor3 = Color3.fromRGB(16, 16, 15)
	standings.BackgroundTransparency = 0.35
	standings.BorderSizePixel = 0
	standings.Parent = gui

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = standings

	-- Carry indicator for THE LINE.
	local carry = label(gui, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, -70))
	carry.TextSize = 20
	carry.Text = ""

	-- Update loop ------------------------------------------------------------

	local function phaseCaption(phase: string): string
		if phase == "Lobby" then
			return "AWAITING OPERATORS"
		elseif phase == "Intermission" then
			return "STAND BY"
		elseif phase == "Announce" then
			return "PROGRAM LOADING"
		elseif phase == "Load" then
			return "TRANSFERRING"
		elseif phase == "Countdown" then
			return "PREPARE"
		elseif phase == "Play" then
			return tostring(State.get("Minigame") or "")
		elseif phase == "Score" then
			return "TALLYING"
		elseif phase == "Results" then
			return "CYCLE COMPLETE"
		end
		return phase
	end

	RunService.RenderStepped:Connect(function()
		local phase = State.getPhase()
		local round = State.get("Round")
		local rounds = State.get("Rounds")

		local caption = phaseCaption(phase)
		if phase == "Play" and round and rounds then
			caption = `{caption}   [{round}/{rounds}]`
		end
		phaseText.Text = caption

		local left = State.timeLeft()
		timerText.Text = if left > 0 then string.format("%d", math.ceil(left)) else ""
		timerText.TextColor3 = if left <= 5 and left > 0 then Config.Colors.Warn else Config.Colors.Accent

		local carrying = player:GetAttribute("Carrying")
		carry.Text = if type(carrying) == "string" then `CARRYING: {string.upper(carrying)}` else ""
	end)

	-- Server events ----------------------------------------------------------

	local function flash(main: string, sub: string, duration: number)
		announce.Text = main
		announceSub.Text = sub
		announce.TextTransparency = 0
		announceSub.TextTransparency = 0
		task.delay(duration, function()
			if announce.Text == main then
				announce.TextTransparency = 1
				announceSub.TextTransparency = 1
			end
		end)
	end

	RoundEvent.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end

		if payload.kind == "announce" then
			flash(
				tostring(payload.name),
				`PROGRAM {string.format("%03d", tonumber(payload.round) or 0)} OF {payload.rounds}`,
				Config.Phase.Announce
			)
		elseif payload.kind == "matchResult" then
			local winner = payload.winner
			flash(
				if winner then string.upper(tostring(winner)) else "NO WINNER",
				if winner then "CYCLE COMPLETE" else "TIED",
				Config.Phase.Results
			)
		end
	end)

	Scoreboard.OnClientEvent:Connect(function(rows)
		if type(rows) ~= "table" then
			return
		end
		for _, child in standings:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for i, row in rows do
			local entry = label(standings, UDim2.new(1, -8, 0, 20), UDim2.fromOffset(4, 0))
			entry.LayoutOrder = i
			entry.TextXAlignment = Enum.TextXAlignment.Left
			entry.TextSize = 16
			entry.Text = `{i}. {row.name}`

			local score = label(entry, UDim2.new(0, 60, 1, 0), UDim2.new(1, -60, 0, 0))
			score.TextXAlignment = Enum.TextXAlignment.Right
			score.TextSize = 16
			score.TextColor3 = Config.Colors.Accent
			score.Text = tostring(row.score)
		end
	end)

	return gui
end

return HUD
