--!nonstrict
-- SESSION WALL COORDINATOR.
--
-- Owns the SurfaceGui, page/network routing and no party authority. PartyWallView
-- renders the terminal; RoomService validates and performs every state change.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyWallView = require(script.Parent.PartyWallView)

local player = Players.LocalPlayer

local SessionWallController = {}
SessionWallController.__index = SessionWallController

local GUI_NAME = "KenopsiaSessionWall"
local BACK_ACTION = "KenopsiaPartyWallBack"
local BACK_PRIORITY = 3000
local CODE_LENGTH = 6

function SessionWallController.new(deps)
	local self = setmetatable({}, SessionWallController)
	self.scene = deps and deps.scene
	self.onBack = deps and deps.onBack
	self.conns = {}
	self.room = nil
	self.pendingState = nil
	self.revealed = false
	self.joinOrigin = "code"
	self.createPending = false

	local pg = player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(GUI_NAME)
	if old then
		old:Destroy()
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.AlwaysOnTop = false
	gui.Active = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.Face = Enum.NormalId.Front
	gui.Enabled = false
	gui.Parent = pg
	self.gui = gui

	self:bindAdornee()
	self.remotes = self:resolveRemotes()

	local config = ReplicatedStorage:WaitForChild("Kenopsia")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("GameConfig")
	local gameConfig = require(config)
	self.view = PartyWallView.new(gui, {
		backToLanding = function()
			self:returnToLanding()
		end,
		create = function(isPublic, joinPolicy)
			self:create(isPublic, joinPolicy)
		end,
		joinCode = function(code)
			self:joinCode(code)
		end,
		browse = function()
			self:browse()
		end,
		joinPublic = function(roomId)
			self:joinPublic(roomId)
		end,
		cancelJoin = function()
			self:cancelJoin()
		end,
		toggleReady = function()
			self:toggleReady()
		end,
		leave = function()
			self:leave()
		end,
		decide = function(userId, accept)
			self:decide(userId, accept)
		end,
	}, {
		localUserId = player.UserId,
		codeAlphabet = gameConfig.Room.CodeAlphabet,
	})
	self.view:go("Select")
	self.view:setInteractive(false)

	self:bindServer()
	self:bindBack()
	return self
end

function SessionWallController:bindAdornee()
	local function resolve()
		local stage = workspace:FindFirstChild("MenuStage")
		local display = stage and stage:FindFirstChild("SessionDisplay")
		if not display then
			return false
		end
		self.gui.Adornee = display
		display.CanQuery = true
		return true
	end
	if resolve() then
		return
	end
	task.spawn(function()
		for _ = 1, 40 do
			task.wait(0.25)
			if resolve() then
				return
			end
		end
		warn("[SessionWall] MenuStage.SessionDisplay never appeared - wall will not render")
	end)
end

function SessionWallController:resolveRemotes()
	local kenopsia = ReplicatedStorage:WaitForChild("Kenopsia", 10)
	return kenopsia and kenopsia:WaitForChild("Remotes", 10) or nil
end

function SessionWallController:remote(name)
	return self.remotes and self.remotes:FindFirstChild(name) or nil
end

function SessionWallController:fire(name, ...)
	local remote = self:remote(name)
	if not remote then
		self.view:setNotice("LOBBY SERVICE OFFLINE", true)
		return false
	end
	remote:FireServer(...)
	return true
end

function SessionWallController:me()
	local members = self.room and self.room.members or {}
	for _, member in members do
		if member.userId == player.UserId then
			return member
		end
	end
	return nil
end

function SessionWallController:create(isPublic, joinPolicy)
	if self.createPending then
		return
	end
	if type(isPublic) ~= "boolean" then
		return
	end
	if joinPolicy ~= "Open" and joinPolicy ~= "Approval" then
		return
	end
	self.createPending = true
	self.view:setCreateLocked(true)
	if not self:fire("RoomCreateRequest", { public = isPublic, joinPolicy = joinPolicy }) then
		self.createPending = false
		self.view:setCreateLocked(false)
		return
	end
	-- A rate-limited or dropped request has no server reply. Do not strand the
	-- create form in a permanent locked state.
	task.delay(3, function()
		if not self.createPending or self.room then
			return
		end
		self.createPending = false
		self.view:setCreateLocked(false)
		if self.view:page() == "Create" then
			self.view:setNotice("TRY AGAIN", true)
		end
	end)
end

function SessionWallController:joinCode(code)
	if type(code) ~= "string" or #code ~= CODE_LENGTH then
		self.view:setNotice("CODE MUST BE 6 CHARACTERS", true, "Join")
		return
	end
	self.joinOrigin = "code"
	self.view:setNotice("CONNECTING...", false, "Join")
	self:fire("RoomJoinRequest", code)
end

function SessionWallController:browse()
	self.view:setNotice("REFRESHING...", false, "Browse")
	self:fire("RoomBrowseRequest")
end

function SessionWallController:joinPublic(roomId)
	if type(roomId) ~= "number" then
		return
	end
	self.joinOrigin = "public"
	self.view:setNotice("JOINING...", false, "Browse")
	self:fire("RoomPublicJoinRequest", roomId)
end

function SessionWallController:cancelJoin()
	self.view:setWaitingStatus("CANCELLING REQUEST...")
	self:fire("RoomJoinCancelRequest")
end

function SessionWallController:toggleReady()
	local me = self:me()
	if not me then
		return
	end
	self:fire("RoomReadyRequest", not (me.ready == true))
end

function SessionWallController:leave()
	self:fire("RoomLeaveRequest")
	self.room = nil
	self.pendingState = nil
	self.view:setPendingRequests({})
	self.view:go("Select")
end

function SessionWallController:decide(userId, accept)
	if type(userId) ~= "number" or type(accept) ~= "boolean" then
		return
	end
	self:fire("RoomJoinDecisionRequest", { requestUserId = userId, accept = accept })
end

function SessionWallController:bindServer()
	local state = self:remote("RoomState")
	if state then
		table.insert(
			self.conns,
			state.OnClientEvent:Connect(function(payload)
				if type(payload) ~= "table" or type(payload.members) ~= "table" then
					return
				end
				self.room = payload
				self.createPending = false
				self.view:setCreateLocked(false)
				self.view:setRoom(payload)
				local pending = self.pendingState
				if pending and pending.roomId == payload.roomId and payload.hostUserId == player.UserId then
					self.view:setPendingRequests(pending.requests)
				elseif payload.hostUserId ~= player.UserId then
					self.pendingState = nil
					self.view:setPendingRequests({})
				end
				if self:me() and self.revealed then
					self.view:go("Room")
					self.view:setNotice("", false, "Room")
				end
			end)
		)
	end

	local browseState = self:remote("RoomBrowseState")
	if browseState then
		table.insert(
			self.conns,
			browseState.OnClientEvent:Connect(function(payload)
				if type(payload) ~= "table" or type(payload.rooms) ~= "table" then
					return
				end
				self.view:setBrowseRooms(payload.rooms)
				self.view:setNotice("", false, "Browse")
			end)
		)
	end

	local joinStatus = self:remote("RoomJoinStatus")
	if joinStatus then
		table.insert(
			self.conns,
			joinStatus.OnClientEvent:Connect(function(payload)
				if type(payload) ~= "table" or type(payload.status) ~= "string" then
					return
				end
				local status = payload.status
				if status == "Pending" then
					self.view:setWaitingStatus("REQUEST SENT")
					self.view:go("Waiting")
				elseif status == "Accepted" then
					self.view:setWaitingStatus("APPROVED - JOINING PARTY")
				elseif status == "Declined" or status == "Expired" or status == "Cancelled" then
					local target = self.joinOrigin == "public" and "Browse" or "Join"
					self.view:go(target)
					self.view:setNotice(payload.message or status, status ~= "Cancelled", target)
				end
			end)
		)
	end

	local pendingState = self:remote("RoomPendingState")
	if pendingState then
		table.insert(
			self.conns,
			pendingState.OnClientEvent:Connect(function(payload)
				if type(payload) ~= "table" or type(payload.requests) ~= "table" then
					return
				end
				-- RoomState and RoomPendingState are distinct reliable streams. Cache
				-- the host-only payload so a host migration cannot lose its prompt if
				-- these two deliveries are observed in the opposite order.
				self.pendingState = payload
				if self.room and payload.roomId == self.room.roomId then
					self.view:setPendingRequests(payload.requests)
				end
			end)
		)
	end

	local lobbyError = self:remote("LobbyError")
	if lobbyError then
		table.insert(
			self.conns,
			lobbyError.OnClientEvent:Connect(function(message)
				self.createPending = false
				self.view:setCreateLocked(false)
				self.view:setNotice(tostring(message), true)
			end)
		)
	end
end

function SessionWallController:bindBack()
	ContextActionService:BindActionAtPriority(BACK_ACTION, function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or not self.revealed then
			return Enum.ContextActionResult.Pass
		end
		local page = self.view:page()
		if page == "Select" then
			self:returnToLanding()
		elseif page == "Waiting" then
			self:cancelJoin()
		elseif page == "Room" then
			self:leave()
		else
			self.view:go("Select")
		end
		return Enum.ContextActionResult.Sink
	end, false, BACK_PRIORITY, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
end

function SessionWallController:setLayerInteractive(on)
	self.gui.Enabled = on
	self.gui.Active = on
	self.view:setInteractive(on)
end

function SessionWallController:reveal()
	self.revealed = true
	self.view:go("Select")
	self:setLayerInteractive(true)
end

function SessionWallController:hide()
	self.revealed = false
	self:setLayerInteractive(false)
	pcall(function()
		GuiService.SelectedObject = nil
	end)
end

function SessionWallController:returnToLanding()
	self:hide()
	if self.onBack then
		self.onBack()
	end
end

function SessionWallController:destroy()
	ContextActionService:UnbindAction(BACK_ACTION)
	for _, conn in self.conns do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(self.conns)
	if self.view then
		self.view:destroy()
	end
	if self.gui then
		self.gui:Destroy()
	end
end

return SessionWallController
