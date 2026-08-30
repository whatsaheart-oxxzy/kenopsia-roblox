--!nonstrict
-- ABORT SCREEN (30.08.2026, user) -- when a match dies (a player left, a
-- minigame errored), the survivors used to get one feed line while the world
-- kept simulating around them. Now: the moment the server says RUN ABORTED,
-- the screen goes BLACK with the reason on it, movement and chat input are
-- frozen, and after HOLD_SECONDS the lobby -- already cleaned up and re-homed
-- by the server underneath -- is revealed.
--
-- Own LocalScript, not a KenopsiaClient edit: the monolith sits near Luau's
-- 200-local ceiling (project rule since 23.08.).
--
-- Trigger: LobbyError messages beginning "RUN ABORTED" -- RoomService's
-- abortMatch is the only sender with that prefix, and it fires to EVERY
-- player. Lobby-side refusals (ready errors, countdown aborts) come without
-- the prefix and stay what they were: a feed line, no freeze.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local HOLD_SECONDS = 5

local gen = 0

local function getControls()
	local ok, controls = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	return ok and controls or nil
end

-- Freeze = no moving (PlayerModule controls off: WASD, thumbstick, gamepad)
-- and no typing (chat input bar off). Everything pcall-wrapped: a chat system
-- without ChatInputBarConfiguration must not break the abort card.
local function freeze(on)
	local controls = getControls()
	if controls then
		if on then pcall(controls.Disable, controls) else pcall(controls.Enable, controls) end
	end
	pcall(function()
		TextChatService.ChatInputBarConfiguration.Enabled = not on
	end)
end

local function show(message)
	gen += 1
	local myGen = gen
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end
	local old = gui:FindFirstChild("KenopsiaAbort")
	if old then old:Destroy() end

	local screen = Instance.new("ScreenGui")
	screen.Name = "KenopsiaAbort"
	screen.DisplayOrder = 1000 -- above every machine gui
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.Active = true -- swallow clicks and taps
	black.Parent = screen
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.new(0.9, 0, 0, 80)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 24
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(190, 40, 40)
	label.Text = tostring(message)
	label.Parent = black
	screen.Parent = gui

	freeze(true)
	task.delay(HOLD_SECONDS, function()
		-- A second abort during the hold restarts the clock; only the newest
		-- card may unfreeze.
		if gen ~= myGen then return end
		freeze(false)
		if screen.Parent then screen:Destroy() end
	end)
end

task.spawn(function()
	local kenopsia = ReplicatedStorage:WaitForChild("Kenopsia", 30)
	local remotes = kenopsia and kenopsia:WaitForChild("Remotes", 30)
	local remote = remotes and remotes:WaitForChild("LobbyError", 30)
	if not (remote and remote:IsA("RemoteEvent")) then return end
	remote.OnClientEvent:Connect(function(message)
		if type(message) == "string" and message:sub(1, 11) == "RUN ABORTED" then
			show(message)
		end
	end)
end)
