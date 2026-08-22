--!nonstrict
-- Instant loading screen: covers join, shows who is connected, and yields to
-- the Machine the moment the first lobby screen arrives.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local PHOSPHOR = Color3.fromHex("78FFAA")
local IDLE = Color3.fromHex("8CE8AE")
local DIM = Color3.fromHex("2E6B4A")

local gui = Instance.new("ScreenGui")
gui.Name = "KenopsiaLoadingGui"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromHex("020402")
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Text = "KENOPSIA"
title.Font = Enum.Font.Code
title.TextSize = 34
title.TextColor3 = PHOSPHOR
title.BackgroundTransparency = 1
title.Position = UDim2.new(0.5, -200, 0.42, -40)
title.Size = UDim2.new(0, 400, 0, 40)
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = bg

local line = Instance.new("TextLabel")
line.Name = "StatusLine"
line.Text = "connecting subjects"
line.Font = Enum.Font.Code
line.TextSize = 17
line.TextColor3 = IDLE
line.BackgroundTransparency = 1
line.Position = UDim2.new(0.5, -220, 0.42, 8)
line.Size = UDim2.new(0, 440, 0, 22)
line.TextXAlignment = Enum.TextXAlignment.Center
line.Parent = bg

local count = Instance.new("TextLabel")
count.Name = "CountLine"
count.Text = ""
count.Font = Enum.Font.Code
count.TextSize = 14
count.TextColor3 = DIM
count.BackgroundTransparency = 1
count.Position = UDim2.new(0.5, -220, 0.42, 34)
count.Size = UDim2.new(0, 440, 0, 18)
count.TextXAlignment = Enum.TextXAlignment.Center
count.Parent = bg

gui.Parent = playerGui

local done = false

-- P2.2 boot ledger (22.08.2026): the unavoidable load time as a POST readout
-- in the machine's voice. Lines land every 120-200 ms, one stalls on purpose,
-- and the dots loop takes over while the lobby packet is still in flight. It
-- never outlasts the real load: `done` cuts it the moment the bridge drops.
local LEDGER = { "POST", "PHOSPHOR", "SUBJECT LINK", "PROTOCOL TABLE", "AUDIO BUS", "SIMULATION POOL" }
local ledger = {}
for i in ipairs(LEDGER) do
	local l = Instance.new("TextLabel")
	l.Name = "Ledger" .. i
	l.Text = ""
	l.Font = Enum.Font.Code
	l.TextSize = 14
	l.TextColor3 = DIM
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0.5, -220, 0.42, 58 + i * 18)
	l.Size = UDim2.new(0, 440, 0, 18)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = bg
	ledger[i] = l
end

task.spawn(function()
	for i, name in ipairs(LEDGER) do
		if done then return end
		local l = ledger[i]
		local pad = string.rep(".", math.max(1, 20 - #name))
		l.Text = name .. " " .. pad .. " "
		task.wait(i == 4 and 0.7 or (0.12 + math.random() * 0.08))
		if done then return end
		l.Text = name .. " " .. pad .. " OK"
		l.TextColor3 = IDLE
	end
	local dots = 0
	while not done do
		dots = (dots % 3) + 1
		line.Text = "connecting subjects " .. string.rep(".", dots)
		count.Text = ("subjects in facility: %d"):format(#Players:GetPlayers())
		task.wait(0.45)
	end
end)

task.spawn(function()
	local t0 = os.clock()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	-- Never remove the bridge until its visible successor is ready. These
	-- properties are asserted here so an accidental saved Edit-state toggle
	-- cannot strand a cold client on a blank screen.
	local machineGui = playerGui:WaitForChild("KenopsiaMachine", 20)
	if machineGui then
		machineGui.Enabled = true
		local warning = machineGui:WaitForChild("Warning", 10)
		if warning then warning.Visible = true end

		-- Only preload startup-critical content. Passing the entire place here
		-- would make slow mobile joins substantially worse.
		local criticalAssets = {}
		local function add(asset)
			if asset then criticalAssets[#criticalAssets + 1] = asset end
		end
		local selection = machineGui:FindFirstChild("Selection")
		add(selection and selection:FindFirstChild("GrungeWash"))
		local audio = SoundService:FindFirstChild("KenopsiaAudio")
		local music = audio and audio:FindFirstChild("Music")
		local sfx = audio and audio:FindFirstChild("SFX")
		add(music and music:FindFirstChild("Intro"))
		add(music and music:FindFirstChild("Loop"))
		add(sfx and sfx:FindFirstChild("Warning"))
		add(sfx and sfx:FindFirstChild("Click"))
		if #criticalAssets > 0 then
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync(criticalAssets)
			end)
			if not ok then warn("[KenopsiaLoading] Critical preload failed:", err) end
		end
	end

	local held = os.clock() - t0
	if held < 2 then task.wait(2 - held) end
	done = true
	gui:Destroy()
end)
