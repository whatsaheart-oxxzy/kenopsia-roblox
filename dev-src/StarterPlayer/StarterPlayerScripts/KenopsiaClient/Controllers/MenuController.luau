--!nonstrict
-- MENU COORDINATOR (Gate M1 §3C).
--
-- What remains of the old 1,087-line controller after the split. It now owns
-- exactly two things:
--
--   1. The CRT monitor surface that the TRIAL screens live on, and the show()
--      contract TrialController calls.
--   2. The settings appliers the overlay delegates to.
--
-- It no longer owns the menu. The landing screen is MenuOverlayController's,
-- the session flow is SessionWallController's, and the camera and character are
-- MenuSceneController's.
--
-- REMOVED HERE (plan §4). All of this is gone from the source, not merely
-- unreachable: the horror boot and "5 OF 4 FOUND", the forced six-second
-- content warning, RedWash / BloodDrips / BleedTop / BleedBottom, the VHS
-- chrome (REC, SP, tracking, corrupted dates), the RGB title ghosts, the tape
-- dropouts, the random camera kicks and the shake they drove, the 12 Hz static
-- swapping, and the permanent RenderStepped loop that ran all of it every frame
-- whether or not anything was visible.
--
-- The shake is gone rather than kept: it was applied only inside that loop, and
-- every consumer it modulated is itself on the removal list. Its one legitimate
-- use -- feedback on a rejected action -- is served by the overlay's and the
-- wall's own error states.
--
-- The monitor is DISABLED until a trial screen asks for it, so the landing view
-- is the 3D street and nothing else. That is what removes the CRT frame from
-- the menu without deleting the surface the trials still need.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local UI = script.Parent.Parent.UI
local Motion = require(UI.Motion)
local SoundBank = require(UI.SoundBank)

local player = Players.LocalPlayer

local MenuController = {}
MenuController.__index = MenuController

-- Screens that belong to the trial path. Everything else the old menu used
-- (Boot, MainMenu, Settings, Credits, Create, Join, ContentWarning) is dead and
-- is never shown again from here.
local TRIAL_SCREENS = {
	Countdown = true, TrialIntro = true, Trial = true,
	TrialResult = true, FinalResult = true,
}

function MenuController.new(gui)
	local self = setmetatable({}, MenuController)
	self.gui = gui
	self.area = gui.Monitor.ScreenArea
	self.content = self.area.Content
	self.screens = self.content.Screens
	self.overlay = self.area.Overlay
	self.conns = {}
	self.current = nil
	self._transition = 0

	-- Shared with MenuOverlayController, which owns the settings UI. One table,
	-- so the panel and the appliers can never disagree.
	self.settings = {
		TextScale = 1.0,
		RetroFilter = 0.25,
		Scanlines = true,
		ReduceEffects = false,
		ReduceFlicker = false,
		Animations = true,
		CustomCursor = true,
		UiSound = true,
		Music = true,
	}

	SoundBank.init()
	SoundBank.setSfxEnabled(self.settings.UiSound)
	SoundBank.setMusicEnabled(self.settings.Music)

	self:applyTextScale(self.settings.TextScale)
	self:applyIntensity(self.settings.RetroFilter)
	self:applyCursor()

	-- The monitor starts dark. No boot sequence, no content-warning gate, no
	-- power-on animation: the player is in the street menu immediately.
	self:hideMonitor()
	self:bindServer()

	return self
end

function MenuController:remote(name)
	local k = ReplicatedStorage:FindFirstChild("Kenopsia")
	local remotes = k and k:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild(name) or nil
end

-- MONITOR --------------------------------------------------------------------

function MenuController:hideMonitor()
	self.current = nil
	for _, s in self.screens:GetChildren() do
		if s:IsA("GuiObject") then s.Visible = false end
	end
	local monitor = self.gui:FindFirstChild("Monitor")
	if monitor then monitor.Visible = false end
end

-- show() is the contract TrialController depends on. Its signature is
-- unchanged. It now also raises the monitor, so callers do not need to know the
-- surface was hidden.
function MenuController:show(name, instant, dir)
	local target = self.screens:FindFirstChild(name)
	if not target then return end

	local monitor = self.gui:FindFirstChild("Monitor")
	if monitor then monitor.Visible = true end

	if self.current == name then
		target.Visible = true
		return
	end

	local previous = self.current and self.screens:FindFirstChild(self.current)
	self.current = name
	self._transition += 1
	local token = self._transition

	for _, s in self.screens:GetChildren() do
		if s ~= target and s ~= previous then s.Visible = false end
	end

	local animate = not instant and self.settings.Animations
	dir = dir or 1

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
	else
		target.Position = UDim2.fromScale(0, 0)
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

-- SERVER ---------------------------------------------------------------------
-- Trial path only. The roster, room code, visibility, ready state and
-- LobbyError all belong to SessionWallController now -- this controller
-- deliberately does NOT subscribe to them, so there is exactly one listener per
-- concern rather than two racing to render the same payload.

function MenuController:bindServer()
	local state = self:remote("RoomState")
	if not state then return end
	table.insert(self.conns, state.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then return end

		if payload.phase == "Starting" and payload.countdown then
			self:onCountdown(payload.countdown)
		elseif payload.phase == "Playing" then
			SoundBank.granted()
			local trial = self.screens:FindFirstChild("Trial")
			local title = trial and trial:FindFirstChild("Title")
			if title then title.Text = "AWAITING PROGRAM..." end
			if trial then self:show("Trial") end
		elseif payload.phase == "Waiting" then
			self._lastCount = nil
			-- Back to the lobby: drop the monitor entirely and let the 3D menu
			-- be the whole view again. Previously this fell through to a Room
			-- screen, which is now the wall's page.
			if self.current and TRIAL_SCREENS[self.current] then
				self:hideMonitor()
			end
		end
	end))
end

function MenuController:onCountdown(n)
	if self.current ~= "Countdown" then
		self:show("Countdown")
		SoundBank.standClear()
	end
	if self._lastCount == n then return end
	self._lastCount = n

	local countdown = self.screens:FindFirstChild("Countdown")
	local title = countdown and countdown:FindFirstChild("Title")
	if title then
		title.Text = tostring(n)
		title.TextTransparency = 0.5
		Motion.press(title, { TextTransparency = 0 })
	end
	SoundBank.count(n)
end

-- SETTINGS APPLIERS ----------------------------------------------------------
-- Called by MenuOverlayController, which owns the settings UI.

function MenuController:applyIntensity(v)
	self.settings.RetroFilter = v
	-- Scales the surviving CRT framing on the trial monitor only. The horror
	-- layers this used to drive no longer exist.
	local vig = self.overlay and self.overlay:FindFirstChild("PhosphorWash")
	if vig then vig.BackgroundTransparency = 1 - math.clamp(v, 0, 1) * 0.12 end
	for _, name in { "VigTop", "VigBottom", "VigLeft", "VigRight" } do
		local f = self.overlay and self.overlay:FindFirstChild(name)
		if f then f.BackgroundTransparency = 1 - math.clamp(v, 0, 1) * 0.55 end
	end
end

function MenuController:applyTextScale(scale)
	self.settings.TextScale = scale
	local s = self.content:FindFirstChild("ResolutionScale")
	if s and s:IsA("UIScale") then s.Scale = scale end
end

function MenuController:applyCursor()
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local cg = pg and pg:FindFirstChild("KenopsiaCursor")
	self.cursor = cg and cg:FindFirstChild("Cursor")
	local on = self.settings.CustomCursor
	pcall(function() UserInputService.MouseIconEnabled = not on end)
	if self.cursor then self.cursor.Visible = on end
end

function MenuController:destroy()
	for _, conn in self.conns do
		if conn.Connected then conn:Disconnect() end
	end
	table.clear(self.conns)
end

return MenuController
