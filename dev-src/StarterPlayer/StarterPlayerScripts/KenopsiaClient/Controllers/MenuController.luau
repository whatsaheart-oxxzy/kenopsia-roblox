--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local SoundBank = require(UI.SoundBank)

local player = Players.LocalPlayer

local MenuController = {}
MenuController.__index = MenuController

local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local PHOSPHOR = Color3.fromHex("78FFAA")
local IDLE = Color3.fromHex("8CE8AE")
local DIM = Color3.fromHex("2E6B4A")
local BLOOD = Color3.fromHex("A81E14")
local BLOOD_BRIGHT = Color3.fromHex("E0342A")
local AMBER = Color3.fromHex("FFBA3C")

local thumbCache = {}

function MenuController.new(gui)
	local self = setmetatable({}, MenuController)
	self.gui = gui
	self.area = gui.Monitor.ScreenArea
	self.content = self.area.Content
	self.screens = self.content.Screens
	self.overlay = self.area.Overlay
	self.banner = self.content:FindFirstChild("Banner")
	self.conns = {}
	self.current = nil
	self._transition = 0
	self._lastShow = 0

	self.settings = {
		CrtIntensity = 1.0, TextScale = 1.0,
		Scanlines = true, ScreenStatic = true, ReduceFlicker = false,
		Animations = true, CustomCursor = true, UiSound = true, Music = true,
	}
	self.room = { hostUserId = 0, members = {} }
	self.shake = { magnitude = 0, decay = 0 }

	SoundBank.init()
	SoundBank.setSfxEnabled(self.settings.UiSound)
	SoundBank.setMusicEnabled(self.settings.Music)

	self:wireResolution()
	self:wireButtons()
	self:wireNavigation()
	self:wireSettings()
	self:wireRoom()
	self:bindServer()
	self:applyCursor()
	self:startAmbient()

	self:show("Boot", true)
	self:playPowerOn()
	self:playBoot()
	return self
end

function MenuController:remote(name)
	local k = ReplicatedStorage:FindFirstChild("Kenopsia")
	local remotes = k and k:FindFirstChild("Remotes")
	local r = remotes and remotes:FindFirstChild(name)
	return (r and r:IsA("RemoteEvent")) and r or nil
end

function MenuController:wireResolution()
	local scale = self.content:FindFirstChildOfClass("UIScale")
	if not scale then return end
	local designW = self.content:GetAttribute("DesignWidth") or 700
	local designH = self.content:GetAttribute("DesignHeight") or 372

	local function apply()
		local size = self.area.AbsoluteSize
		if size.X > 1 and size.Y > 1 then
			scale.Scale = math.clamp(math.min(size.X / designW, size.Y / designH), 0.2, 4)
		end
	end
	table.insert(self.conns, self.area:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply))
	apply()
end

function MenuController:wireButtons()
	local comps = self.gui:FindFirstChild("Components")
	local highlight = comps and comps:FindFirstChild("SelectionHighlight")
	for _, b in self.content:GetDescendants() do
		if b:IsA("TextButton") then
			if highlight then b.SelectionImageObject = highlight end
			if b:FindFirstChild("Accent") then self:animateButton(b) end
		end
	end
end

function MenuController:animateButton(b)
	local stroke = b:FindFirstChildOfClass("UIStroke")
	local accent = b:FindFirstChild("Accent")
	local caret = b:FindFirstChild("Caret")

	local restFill = b.BackgroundTransparency
	local restStroke = stroke and stroke.Transparency or 0.35
	local restAccent = accent and accent.Size or UDim2.new(0, 4, 0.55, 0)
	local restAccentPos = accent and accent.Position or UDim2.new(0, -18, 0.225, 0)
	local restCaret = caret and caret.TextTransparency or 0.35

	local function focus(on)
		Motion.hover(b, {
			BackgroundTransparency = on and math.max(0, restFill - 0.24) or restFill,
			TextColor3 = on and PHOSPHOR or IDLE,
		})
		if stroke then
			Motion.hover(stroke, { Transparency = on and 0 or restStroke, Color = on and BLOOD_BRIGHT or BLOOD })
		end
		if accent then
			Motion.hover(accent, {
				Size = on and UDim2.new(0, 8, 0.82, 0) or restAccent,
				Position = on and UDim2.new(0, -18, 0.09, 0) or restAccentPos,
			})
		end
		if caret then
			Motion.hover(caret, { TextTransparency = on and 0 or restCaret })
		end
	end

	local function hoverSound()
		if b:GetAttribute("HoverSound") == "Confirm" then
			SoundBank.confirm()
		else
			SoundBank.hover()
		end
	end

	table.insert(self.conns, b.MouseEnter:Connect(function() focus(true) hoverSound() end))
	table.insert(self.conns, b.MouseLeave:Connect(function() focus(false) end))
	table.insert(self.conns, b.SelectionGained:Connect(function() focus(true) hoverSound() end))
	table.insert(self.conns, b.SelectionLost:Connect(function() focus(false) end))
	table.insert(self.conns, b.Activated:Connect(function() SoundBank.click() end))
	table.insert(self.conns, b.MouseButton1Down:Connect(function()
		Motion.press(b, { BackgroundTransparency = 0 })
	end))
	table.insert(self.conns, b.MouseButton1Up:Connect(function()
		Motion.press(b, { BackgroundTransparency = math.max(0, restFill - 0.24) })
	end))
end

-- Full-width swipe between screens; dir -1 slides back the other way.
function MenuController:show(name, instant, dir)
	local target = self.screens:FindFirstChild(name)
	if not target then return end
	if self.current == name then
		target.Visible = true
		return
	end

	local previous = self.current and self.screens:FindFirstChild(self.current)
	self.current = name
	self._transition += 1
	self._lastShow = os.clock()
	local token = self._transition

	for _, s in self.screens:GetChildren() do
		if s ~= target and s ~= previous then s.Visible = false end
	end

	local animate = not instant and self.settings.Animations
	dir = dir or ((name == "MainMenu") and -1 or 1)

	if previous and previous ~= target then
		Motion.cancel(previous)
		if animate then
			Motion.screen(previous, { Position = UDim2.fromScale(-dir, 0) })
			task.delay(0.3, function()
				if self._transition == token and previous.Parent then
					previous.Visible = false
					previous.Position = UDim2.fromScale(0, 0)
				end
			end)
		else
			previous.Visible = false
			previous.Position = UDim2.fromScale(0, 0)
		end
	end

	target.Visible = true
	if animate then
		target.Position = UDim2.fromScale(dir, 0)
		Motion.slide(target, { Position = UDim2.fromScale(0, 0) })
		self.shake.magnitude = math.max(self.shake.magnitude, 2.4)
		self.shake.decay = math.max(self.shake.decay, 34)
	else
		target.Position = UDim2.fromScale(0, 0)
	end

	local chrome = self.content:FindFirstChild("VhsChrome")
	local mode = chrome and chrome:FindFirstChild("Mode")
	if mode then
		mode.Text = (name == "Boot" or name == "ContentWarning") and "STBY" or "PLAY \u{25B6}"
	end

	self:focusFirst(target)
end

local function isRendered(obj, stopAt)
	local node = obj
	while node and node ~= stopAt.Parent do
		if node:IsA("GuiObject") and not node.Visible then return false end
		node = node.Parent
	end
	return true
end

function MenuController:focusFirst(target)
	if not UserInputService.GamepadEnabled then return end
	task.defer(function()
		if not target.Parent or not target.Visible then return end
		for _, d in target:GetDescendants() do
			if d:IsA("GuiButton") and d.Selectable and isRendered(d, target) then
				pcall(function() GuiService.SelectedObject = d end)
				return
			end
		end
		pcall(function() GuiService.SelectedObject = nil end)
	end)
end

function MenuController:playPowerOn()
	local po = self.area:FindFirstChild("PowerOn")
	if not po then return end
	local beam = po:FindFirstChild("Beam")
	if not beam or not self.settings.Animations then
		po.Visible = false
		return
	end
	local flash = po:FindFirstChild("Flash")
	local glow = beam:FindFirstChild("Glow")

	po.BackgroundTransparency = 0
	beam.Size = UDim2.new(0, 6, 0, 2)
	beam.BackgroundTransparency = 1
	if glow then glow.BackgroundTransparency = 1 end
	if flash then flash.BackgroundTransparency = 1 end
	beam.Visible = true
	po.Visible = true

	task.spawn(function()
		task.wait(0.45)
		Motion.to(beam, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0 })
		if glow then
			Motion.to(glow, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.6 })
		end
		task.wait(0.34)
		Motion.to(beam, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 2) })
		task.wait(0.3)
		SoundBank.click()
		if flash then
			flash.BackgroundTransparency = 0.3
			Motion.to(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		end
		Motion.to(beam, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 0.92 })
		if glow then
			Motion.to(glow, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		end
		Motion.to(po, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		self:kick(0.35)
		task.wait(0.4)
		po.Visible = false
		po.BackgroundTransparency = 0
		beam.Visible = false
	end)
end

function MenuController:playBoot()
	local ledger = self.screens.Boot:FindFirstChild("Ledger")
	if not ledger then
		self:showWarning()
		return
	end

	local rows = {}
	for _, r in ledger:GetChildren() do
		if r:IsA("Frame") and r:GetAttribute("Status") then table.insert(rows, r) end
	end
	table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	local corrupt = ledger:FindFirstChild("CorruptLine")
	local ghost = ledger:FindFirstChild("GhostLine")

	for _, r in rows do
		r.Visible = false
		r.StatusLabel.Text = ""
	end
	if corrupt then corrupt.Visible = false end

	task.spawn(function()
		local function alive() return self.current == "Boot" end
		local function burst()
			if self.settings.ReduceFlicker then return end
			local bg = self.area:FindFirstChild("Background")
			if not bg then return end
			local t0 = bg.ImageTransparency
			bg.ImageTransparency = 0
			task.delay(0.07, function() bg.ImageTransparency = t0 end)
		end

		task.wait(0.9)
		for i, r in rows do
			if not alive() then return end
			local status = r.StatusLabel
			local statusBase = status.Position
			local kind = r:GetAttribute("Status")
			r.Visible = true
			task.wait(0.12)
			if not alive() then return end

			if kind == "OVER" then
				status.Text = "104%"
				status.TextColor3 = AMBER
				task.wait(0.55)
				status.Text = "OK"
				status.TextColor3 = PHOSPHOR
			elseif kind == "FAIL" then
				status.Text = "FAIL"
				status.TextColor3 = BLOOD_BRIGHT
				task.wait(0.85)
				if not alive() then return end
				status.Text = "OK"
				status.TextColor3 = PHOSPHOR
				status.Position = statusBase + UDim2.fromOffset(2, -1)
				task.delay(0.05, function() status.Position = statusBase end)
			elseif kind == "WARN" then
				status.Text = "WARN"
				status.TextColor3 = AMBER
				task.wait(0.3)
			elseif kind == "COUNT" then
				for _ = 1, 5 do
					status.Text = "\u{2588}"
					status.TextColor3 = PHOSPHOR
					task.wait(0.16)
					status.Text = ""
					task.wait(0.12)
					if not alive() then return end
				end
				status.Text = "4 OF 4"
				status.TextColor3 = PHOSPHOR
				task.wait(0.5)
				if not alive() then return end
				status.Text = "5 OF 4 FOUND"
				status.TextColor3 = BLOOD_BRIGHT
				if corrupt then corrupt.Visible = true end
				burst()
				self:kick(0.4)
				task.wait(0.7)
			else
				status.Text = "OK"
				status.TextColor3 = PHOSPHOR
				task.wait(0.1)
			end

			if i == 5 and ghost and math.random(8) == 1 then
				ghost.Text = player.DisplayName:upper() .. " IS STILL HERE"
				ghost.Visible = true
				task.wait(0.3)
				ghost.Visible = false
			end
		end
		task.wait(0.4)
		if alive() then self:showWarning() end
	end)
end

function MenuController:showWarning()
	self:show("ContentWarning")
	SoundBank.warning()
	local token = self._transition
	task.delay(6, function()
		if self.current == "ContentWarning" and self._transition == token then
			self:enterMainMenu()
		end
	end)
end

function MenuController:enterMainMenu()
	if not self._musicStarted then
		self._musicStarted = true
		SoundBank.startMusic()
	end
	self:show("MainMenu")
end

function MenuController:wireNavigation()
	local routes = {
		Btn_JOINSESSION = "Join",
		Btn_SETTINGS = "Settings",
		Btn_CREDITS = "Credits",
		Btn_ENTERROOM = "Room",
	}

	for _, b in self.screens:GetDescendants() do
		if b:IsA("TextButton") then
			local name = b.Name
			if name == "Btn_BACK" then
				table.insert(self.conns, b.Activated:Connect(function()
					self:show("MainMenu", false, -1)
				end))
			elseif name == "Btn_CONTINUE" then
				table.insert(self.conns, b.Activated:Connect(function()
					self:enterMainMenu()
				end))
			elseif name == "Btn_HOSTSESSION" then
				table.insert(self.conns, b.Activated:Connect(function()
					self:show("Create")
				end))
			elseif name == "Btn_QUICKJOIN" then
				table.insert(self.conns, b.Activated:Connect(function()
					self:quickJoin()
				end))
			elseif name == "Btn_PUBLIC" then
				table.insert(self.conns, b.Activated:Connect(function()
					self:hostSession(true)
				end))
			elseif name == "Btn_PRIVATE" then
				table.insert(self.conns, b.Activated:Connect(function()
					self:hostSession(false)
				end))
			elseif name == "Btn_CONNECT" then
				table.insert(self.conns, b.Activated:Connect(function()
					self:connectSession()
				end))
			elseif name == "Btn_LEAVE" then
				table.insert(self.conns, b.Activated:Connect(function()
					self:leaveSession()
				end))
			elseif routes[name] then
				local dest = routes[name]
				table.insert(self.conns, b.Activated:Connect(function()
					self:show(dest)
				end))
			end
		end
	end

	local join = self.screens:FindFirstChild("Join")
	local card = join and join:FindFirstChild("EntryCard")
	local box = card and card:FindFirstChild("CodeEntry")
	if box then
		table.insert(self.conns, box:GetPropertyChangedSignal("Text"):Connect(function()
			local cleaned = {}
			for c in string.gmatch(string.upper(box.Text), "%S") do
				if string.find(ALPHABET, c, 1, true) and #cleaned < 6 then
					table.insert(cleaned, c)
				end
			end
			local result = table.concat(cleaned)
			if result ~= box.Text then box.Text = result end
		end))
		self._codeEntry = box
	end
end

function MenuController:hostSession(isPublic)
	local r = self:remote("RoomCreateRequest")
	if not r then
		self:reject("LOBBY SERVICE OFFLINE")
		return
	end
	self:showBanner("OPENING ROOM...", DIM)
	r:FireServer({ public = isPublic == true })
end

function MenuController:quickJoin()
	local r = self:remote("RoomQuickJoinRequest")
	if not r then
		self:reject("LOBBY SERVICE OFFLINE")
		return
	end
	self:showBanner("SEARCHING FOR OPEN ROOM...", DIM)
	r:FireServer()
end

function MenuController:connectSession()
	local box = self._codeEntry
	if not box or #box.Text ~= 6 then
		self:reject("CODE MUST BE 6 CHARACTERS")
		return
	end
	local r = self:remote("RoomJoinRequest")
	if not r then
		self:reject("LOBBY SERVICE OFFLINE")
		return
	end
	self:showBanner("CONNECTING...", DIM)
	r:FireServer(box.Text)
end

function MenuController:leaveSession()
	local r = self:remote("RoomLeaveRequest")
	if r then r:FireServer() end
	self.room = { hostUserId = 0, members = {} }
	self:renderRoom()
	self:show("MainMenu", false, -1)
end

function MenuController:bindServer()
	local state = self:remote("RoomState")
	if state then
		table.insert(self.conns, state.OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then return end
			self.room = {
				hostUserId = payload.hostUserId or 0,
				isPublic = payload.isPublic == true,
				members = payload.members or {},
			}
			self:renderRoom()

			local code = self.screens.Room:FindFirstChild("RoomCode")
			if code then
				code.Text = payload.code and ("CODE  " .. payload.code) or ""
			end
			local vis = self.screens.Room:FindFirstChild("Visibility")
			if vis then
				vis.Text = payload.isPublic and "PUBLIC - STRANGERS MAY BE SEATED" or "PRIVATE - CODE REQUIRED"
				vis.TextColor3 = payload.isPublic and PHOSPHOR or AMBER
			end

			if payload.phase == "Starting" and payload.countdown then
				self:onCountdown(payload.countdown)
			elseif payload.phase == "Waiting" then
				self._lastCount = nil
				if self.current == "MainMenu" or self.current == "Create"
					or self.current == "Join" or self.current == "Countdown"
					or self.current == "TrialIntro" or self.current == "Trial"
					or self.current == "TrialResult" or self.current == "FinalResult" then
					self:show("Room")
				end
			elseif payload.phase == "Playing" then
				SoundBank.granted()
				local trial = self.screens:FindFirstChild("Trial")
				local title = trial and trial:FindFirstChild("Title")
				if title then title.Text = "AWAITING PROGRAM..." end
				if trial then self:show("Trial") end
			end
		end))
	end

	local err = self:remote("LobbyError")
	if err then
		table.insert(self.conns, err.OnClientEvent:Connect(function(message)
			self:reject(tostring(message))
		end))
	end
end

function MenuController:onCountdown(n)
	if self.current ~= "Countdown" then
		self:show("Countdown")
		SoundBank.standClear()
	end
	if self._lastCount == n then return end
	self._lastCount = n

	local title = self.screens.Countdown:FindFirstChild("Title")
	if title then
		title.Text = tostring(n)
		title.TextTransparency = 0.5
		Motion.press(title, { TextTransparency = 0 })
	end
	SoundBank.count(n)
end

function MenuController:me()
	for _, m in self.room.members do
		if m.userId == player.UserId then return m end
	end
	return nil
end

function MenuController:wireRoom()
	local room = self.screens.Room

	local ready = room:FindFirstChild("Btn_READY")
	if ready then
		table.insert(self.conns, ready.Activated:Connect(function()
			local me = self:me()
			if not me then return end
			SoundBank.submit()
			local r = self:remote("RoomReadyRequest")
			if r then
				r:FireServer(not me.ready)
			else
				me.ready = not me.ready
				self:renderRoom()
			end
		end))
	end

	local start = room:FindFirstChild("Btn_START")
	if start then
		table.insert(self.conns, start.Activated:Connect(function()
			local r = self:remote("RoomStartRequest")
			if r then
				r:FireServer()
			else
				self:reject("LOBBY SERVICE OFFLINE")
			end
		end))
	end

	-- practice: run the sharpening trials without leaving the lobby place
	local trial = room:FindFirstChild("Btn_TRIAL")
	if trial then
		table.insert(self.conns, trial.Activated:Connect(function()
			local r = self:remote("TrialPracticeRequest")
			if r then
				SoundBank.submit()
				r:FireServer()
			else
				self:reject("TRIAL SERVICE OFFLINE")
			end
		end))
	end

	self:renderRoom()
end

function MenuController:fetchAvatar(userId, image)
	if userId <= 0 then return end
	local cached = thumbCache[userId]
	if cached then
		image.Image = cached
		return
	end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and url then
			thumbCache[userId] = url
			if image and image.Parent then image.Image = url end
		end
	end)
end

function MenuController:renderRoom()
	local room = self.screens.Room
	local roster = room:FindFirstChild("Roster")
	if not roster then return end

	local slots = {}
	for _, s in roster:GetChildren() do
		if s:IsA("Frame") then table.insert(slots, s) end
	end
	table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)

	for index, slot in slots do
		local m = self.room.members[index]
		local occupied = m ~= nil
		local lit = occupied and m.ready

		slot.Avatar.EmptyMark.Visible = not occupied
		slot.PlayerName.Text = occupied and m.displayName or ""
		slot.HostTag.Text = (occupied and m.userId == self.room.hostUserId) and "HOST" or ""
		slot.StatusTag.Text = occupied and (m.ready and "READY" or "STANDBY") or "OPEN"
		slot.StatusTag.TextColor3 = lit and PHOSPHOR or DIM

		if occupied then
			slot.Avatar.ImageTransparency = 0
			self:fetchAvatar(m.userId, slot.Avatar)
		else
			slot.Avatar.Image = ""
			slot.Avatar.ImageTransparency = 1
		end

		local stroke = slot:FindFirstChildOfClass("UIStroke")
		local avatarStroke = slot.Avatar:FindFirstChildOfClass("UIStroke")
		Motion.hover(slot, { BackgroundTransparency = occupied and 0.2 or 0.55 })
		if stroke then
			Motion.hover(stroke, {
				Color = lit and PHOSPHOR or BLOOD,
				Transparency = occupied and 0.25 or 0.7,
			})
		end
		if avatarStroke then
			Motion.hover(avatarStroke, { Color = lit and PHOSPHOR or BLOOD })
		end
		Motion.hover(slot.ReadyPip, {
			BackgroundColor3 = lit and PHOSPHOR or BLOOD,
			BackgroundTransparency = occupied and 0 or 0.75,
		})
	end

	local me = self:me()
	local btn = room:FindFirstChild("Btn_READY")
	if btn then
		btn.Text = (me and me.ready) and "UNREADY" or "READY"
	end
end

function MenuController:reject(message)
	SoundBank.denied()
	self:showBanner(message)
	self:kick(1)
end

function MenuController:showBanner(message, color)
	local banner = self.banner
	if not banner then return end
	banner.Text = message
	banner.TextColor3 = color or BLOOD_BRIGHT
	banner.TextTransparency = 1
	Motion.fade(banner, { TextTransparency = 0 })
	self._bannerToken = (self._bannerToken or 0) + 1
	local token = self._bannerToken
	task.delay(2.6, function()
		if self._bannerToken == token then
			Motion.fade(banner, { TextTransparency = 1 })
		end
	end)
end

function MenuController:kick(strength)
	self.shake.magnitude = math.min(30, self.shake.magnitude + 19 * strength)
	self.shake.decay = 34
end

function MenuController:wireSettings()
	local list = self.screens.Settings:FindFirstChild("List")
	if not list then return end

	local function bindSlider(rowName, key, min, max, step, fmt, apply)
		local row = list:FindFirstChild(rowName)
		if not row then return end
		local value = row:FindFirstChild("Value")
		local fill = row.BarBackground.Fill

		local function render()
			local v = self.settings[key]
			value.Text = fmt(v)
			Motion.hover(fill, { Size = UDim2.fromScale((v - min) / (max - min), 1) })
			apply(v)
		end
		local function stepBy(dirn)
			self.settings[key] = math.clamp(self.settings[key] + dirn * step, min, max)
			SoundBank.click()
			render()
		end
		table.insert(self.conns, row.Decrease.Activated:Connect(function() stepBy(-1) end))
		table.insert(self.conns, row.Increase.Activated:Connect(function() stepBy(1) end))
		render()
	end

	bindSlider("Slider_CRTINTENSITY", "CrtIntensity", 0, 1.5, 0.25,
		function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
		function(v) self:applyIntensity(v) end)

	bindSlider("Slider_TEXTSIZE", "TextScale", 0.8, 1.3, 0.1,
		function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
		function(v) self:applyTextScale(v) end)

	local function bindToggle(rowName, key, apply)
		local row = list:FindFirstChild(rowName)
		if not row then return end
		local track = row.Track
		local knob = track.Knob
		local stroke = track:FindFirstChildOfClass("UIStroke")
		local hit = row:FindFirstChild("Hit")
		if not hit then return end

		local function render()
			local on = self.settings[key]
			Motion.hover(knob, {
				Position = on and UDim2.new(1, -30, 0.5, -13) or UDim2.new(0, 4, 0.5, -13),
				BackgroundColor3 = on and PHOSPHOR or BLOOD,
			})
			if stroke then Motion.hover(stroke, { Color = on and PHOSPHOR or BLOOD }) end
			apply(on)
		end

		table.insert(self.conns, hit.Activated:Connect(function()
			self.settings[key] = not self.settings[key]
			SoundBank.click()
			render()
		end))
		render()
	end

	bindToggle("Toggle_SCANLINES", "Scanlines", function(on)
		local w = self.overlay:FindFirstChild("PhosphorWash")
		if w then w.Visible = on end
	end)
	bindToggle("Toggle_SCREENSTATIC", "ScreenStatic", function(on)
		local bg = self.area:FindFirstChild("Background")
		if bg then Motion.fade(bg, { ImageTransparency = on and (bg:GetAttribute("BaseImageTransparency") or 0.42) or 1 }) end
	end)
	bindToggle("Toggle_REDUCEFLICKER", "ReduceFlicker", function() end)
	bindToggle("Toggle_ANIMATIONS", "Animations", function(on) Motion.setEnabled(on) end)
	bindToggle("Toggle_CUSTOMCURSOR", "CustomCursor", function() self:applyCursor() end)
	bindToggle("Toggle_UISOUND", "UiSound", function(on) SoundBank.setSfxEnabled(on) end)
	bindToggle("Toggle_MUSIC", "Music", function(on) SoundBank.setMusicEnabled(on) end)
end

function MenuController:applyIntensity(v)
	local scale = math.clamp(v, 0, 1.5)
	for _, f in self.overlay:GetChildren() do
		if f:IsA("Frame") then
			local base = f:GetAttribute("BaseTransparency")
			if base == nil then
				base = f.BackgroundTransparency
				f:SetAttribute("BaseTransparency", base)
			end
			f.BackgroundTransparency = math.clamp(1 - (1 - base) * scale, 0, 1)
		end
	end
end

function MenuController:applyTextScale(scale)
	for _, d in self.screens:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			local base = d:GetAttribute("BaseTextSize")
			if not base then
				base = d.TextSize
				d:SetAttribute("BaseTextSize", base)
			end
			d.TextSize = math.max(8, math.floor(base * scale + 0.5))
		end
	end
end

function MenuController:applyCursor()
	local pg = player:FindFirstChild("PlayerGui")
	local cg = pg and pg:FindFirstChild("KenopsiaCursor")
	self.cursor = cg and cg:FindFirstChild("Cursor")

	local on = self.settings.CustomCursor
	pcall(function() UserInputService.MouseIconEnabled = not on end)
	if self.cursor then self.cursor.Visible = on end
end

function MenuController:startAmbient()
	local monitor = self.gui.Monitor
	local camera = workspace.CurrentCamera
	local wash = self.overlay:FindFirstChild("RedWash")
	local bleedTop = self.overlay:FindFirstChild("BleedTop")
	local washBase = wash and wash.BackgroundTransparency or 1
	local bleedBase = bleedTop and bleedTop.BackgroundTransparency or 1
	local t, nextGlitch = 0, 4
	local chrome = self.content:FindFirstChild("VhsChrome")
	local recLabel = chrome and chrome:FindFirstChild("Rec")
	local counterLabel = chrome and chrome:FindFirstChild("Counter")
	local dateLabel = chrome and chrome:FindFirstChild("DateLabel")
	if dateLabel then dateLabel.Text = os.date("%b. %d %Y"):upper() end
	local sessionStart = os.clock()
	local lastSecond = -1
	local bg = self.area:FindFirstChild("Background")
	local staticFrames = {}
	local pre = bg and bg:FindFirstChild("StaticPreload")
	if pre then
		for _, l in pre:GetChildren() do
			if l:IsA("ImageLabel") then table.insert(staticFrames, l) end
		end
		table.sort(staticFrames, function(a, b) return a.Name < b.Name end)
	end
	local staticReady = false
	local staticIdx, nextStaticSwap = 1, 0
	local paraX, paraY = 0, 0
	local contentBase = self.content.Position
	local clockLabel = chrome and chrome:FindFirstChild("Clock")
	local backUntil, backAnchor = 0, 0
	local dateGlitchUntil, dateGlitched = 0, false
	local CORRUPT_DATES = {
		"OCT. 32 1987", "AUG. 00 0000", "??? 07 2026", "AUG. 07 1226", "FEB. 30 1993",
	}
	local damage = self.overlay:FindFirstChild("TapeDamage")
	local headTear = damage and damage:FindFirstChild("HeadTear")
	local trackBand = damage and damage:FindFirstChild("TrackBand")
	local trackLabel = damage and damage:FindFirstChild("TrackLabel")
	local dropPool = {}
	do
		local d = damage and damage:FindFirstChild("Dropouts")
		if d then
			for _, f in d:GetChildren() do
				if f:IsA("Frame") then table.insert(dropPool, f) end
			end
		end
	end
	local dropIdx, tearFrame = 1, 0
	local tearBase = headTear and headTear.Position
	local nextTrack, trackUntil = 18, 0
	local mm = self.screens:FindFirstChild("MainMenu")
	local title = mm and mm:FindFirstChild("Title")
	local ghostR = mm and mm:FindFirstChild("TitleGhostR")
	local ghostB = mm and mm:FindFirstChild("TitleGhostB")
	local titleBase = title and title.Position
	local ghostBurst = 0
	local crawlers = {}
	local dripHost = self.overlay:FindFirstChild("BloodDrips")
	if dripHost then
		for _, d in dripHost:GetChildren() do
			local speed = d:GetAttribute("CrawlSpeed")
			if speed and d:IsA("ImageLabel") then
				table.insert(crawlers, {
					label = d, speed = speed,
					x = d.Position.X.Scale, y = d.Position.Y.Scale,
					baseT = d.ImageTransparency,
				})
			end
		end
	end

	table.insert(self.conns, RunService.RenderStepped:Connect(function(dt)
		if self.cursor and self.cursor.Visible then
			local m = UserInputService:GetMouseLocation()
			self.cursor.Position = UDim2.fromOffset(m.X, m.Y)
		end

		local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local k = math.min(1, dt * 3.5)
		if self.settings.Animations then
			local m = UserInputService:GetMouseLocation()
			local tx = math.clamp((m.X / math.max(1, vp.X)) * 2 - 1, -1, 1)
			local ty = math.clamp((m.Y / math.max(1, vp.Y)) * 2 - 1, -1, 1)
			paraX += (tx - paraX) * k
			paraY += (ty - paraY) * k
		else
			paraX += -paraX * k
			paraY += -paraY * k
		end
		local px, py = paraX * 14, paraY * 9

		if self.shake.magnitude > 0.05 then
			self.shake.magnitude = math.max(0, self.shake.magnitude - self.shake.decay * dt)
			local mag = self.shake.magnitude
			local function j() return (math.random() * 2 - 1) * mag end
			-- Never rotate the monitor: Rotation disables ClipsDescendants for the
			-- whole subtree, letting screen content bleed past the bezel.
			monitor.Position = UDim2.new(0.5, px + j(), 0.5, py + j())
			if camera then
				camera.CFrame = camera.CFrame * CFrame.Angles(
					math.rad(j() * 0.14), math.rad(j() * 0.14), math.rad(j() * 0.1))
			end
		else
			monitor.Position = UDim2.new(0.5, px, 0.5, py)
		end
		local trackJx = (t < trackUntil) and math.random(-5, 5) or 0
		self.content.Position = contentBase + UDim2.fromOffset(paraX * -4 + trackJx, paraY * -3)

		if chrome then
			local elapsed = os.clock() - sessionStart
			local sec = math.floor(elapsed)
			if sec ~= lastSecond and counterLabel then
				lastSecond = sec
				local shown, back = sec, false
				if elapsed < backUntil then
					shown = math.max(0, backAnchor * 2 - sec)
					back = true
				elseif not self.settings.ReduceFlicker and math.random(45) == 1 then
					backUntil = elapsed + 2.5
					backAnchor = sec
				end
				counterLabel.Text = ("SP %d:%02d:%02d"):format(shown // 3600, (shown // 60) % 60, shown % 60)
				counterLabel.TextColor3 = back and BLOOD_BRIGHT or IDLE
			end
			if recLabel then
				recLabel.TextTransparency = (self.settings.ReduceFlicker or elapsed % 1.6 < 0.95) and 0 or 0.7
			end
			if clockLabel then
				clockLabel.TextTransparency = (not self.settings.ReduceFlicker and elapsed % 1.2 < 0.6) and 0.55 or 0.1
			end
			if dateLabel then
				if elapsed < dateGlitchUntil then
					if not dateGlitched then
						dateGlitched = true
						dateLabel.Text = CORRUPT_DATES[math.random(#CORRUPT_DATES)]
						dateLabel.TextColor3 = BLOOD_BRIGHT
					end
				elseif dateGlitched then
					dateGlitched = false
					dateLabel.Text = os.date("%b. %d %Y"):upper()
					dateLabel.TextColor3 = DIM
				elseif not self.settings.ReduceFlicker and math.random(1400) == 1 then
					dateGlitchUntil = elapsed + 0.28
				end
			end
		end

		if self.settings.ReduceFlicker then return end
		t += dt

		local pulse = 0.5 + 0.5 * math.sin(t * 1.1)
		if wash then wash.BackgroundTransparency = washBase - pulse * 0.035 - self.shake.magnitude * 0.014 end
		if bleedTop then bleedTop.BackgroundTransparency = bleedBase - pulse * 0.05 end

		if bg and #staticFrames > 0 and self.settings.ScreenStatic then
			if not staticReady then
				staticReady = true
				for _, l in staticFrames do
					if not l.IsLoaded then staticReady = false break end
				end
			end
			if staticReady and t >= nextStaticSwap then
				nextStaticSwap = t + 0.085
				staticIdx = staticIdx % #staticFrames + 1
				bg.Image = staticFrames[staticIdx].Image
			end
		end

		if ghostR and ghostB and titleBase then
			ghostBurst = math.max(0, ghostBurst - 5 * dt)
			local split = 1.6 + ghostBurst * 8 + math.min(10, self.shake.magnitude * 0.4)
			ghostR.Position = titleBase + UDim2.fromOffset(-split, 0)
			ghostB.Position = titleBase + UDim2.fromOffset(split, 1)
		end

		for _, c in crawlers do
			local cyc = (t * c.speed) % 1
			c.label.Position = UDim2.fromScale(c.x, c.y + cyc * 0.06)
			local fade = cyc > 0.85 and (cyc - 0.85) / 0.15 or 0
			c.label.ImageTransparency = c.baseT + (1 - c.baseT) * fade
		end

		tearFrame += 1
		if headTear and tearFrame % 3 == 0 then
			headTear.ImageRectOffset = Vector2.new(0, math.random(0, 270))
			headTear.Position = tearBase + UDim2.fromOffset(math.random(-4, 4), 0)
		end

		if #dropPool > 0 and math.random() < 0.015 + self.shake.magnitude * 0.012 then
			local drop = dropPool[dropIdx]
			dropIdx = dropIdx % #dropPool + 1
			drop.Position = UDim2.new(math.random() * 0.7, 0, math.random(), 0)
			drop.Size = UDim2.new(0, math.random(40, 220), 0, math.random(1, 2))
			drop.Visible = true
			task.delay(0.05, function()
				if drop.Parent then drop.Visible = false end
			end)
		end

		if trackBand and t >= nextTrack then
			nextTrack = t + 70 + math.random() * 50
			trackUntil = t + 1.6
			trackBand.Position = UDim2.new(0, 0, 1.05, 0)
			trackBand.Visible = true
			if trackLabel then trackLabel.Visible = true end
			Motion.to(trackBand, TweenInfo.new(1.6, Enum.EasingStyle.Linear), { Position = UDim2.new(0, 0, -0.2, 0) })
		end
		if trackBand and trackBand.Visible then
			if t >= trackUntil then
				trackBand.Visible = false
				if trackLabel then trackLabel.Visible = false end
			else
				if staticReady and #staticFrames > 0 then
					trackBand.Image = staticFrames[staticIdx].Image
				end
				if trackLabel then
					trackLabel.TextTransparency = (t % 0.5 < 0.28) and 0.1 or 0.7
				end
			end
		end

		if t >= nextGlitch then
			nextGlitch = t + 5 + math.random() * 8
			ghostBurst = 1
			local screen = self.current and self.screens:FindFirstChild(self.current)
			if screen and self.settings.Animations and (os.clock() - self._lastShow) > 0.6 then
				screen.Position = UDim2.fromOffset(math.random(-7, 7), math.random(-3, 3))
				task.delay(0.05, function()
					if screen.Parent and (os.clock() - self._lastShow) > 0.6 then
						Motion.press(screen, { Position = UDim2.fromScale(0, 0) })
					end
				end)
			end
		end
	end))
end

function MenuController:destroy()
	for _, c in self.conns do c:Disconnect() end
	self.conns = {}
end

return MenuController
