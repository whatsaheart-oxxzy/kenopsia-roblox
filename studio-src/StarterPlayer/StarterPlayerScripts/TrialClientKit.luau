--!nonstrict
-- TRIAL CLIENT KIT (MP-05 Framework, plan section C) -- the router that dispatches
-- {kind="trial"} packets to StarterPlayerScripts/TrialClients/<id>.luau modules,
-- and the per-trial `kit` object those modules receive in init(kit).
--
-- The monolith (KenopsiaClient) keeps owning movement, cameras, the death cam
-- and every legacy screen. It hands this module a set of CLOSURES (deps) and one
-- line in its packet funnel: `if trialRouter.handle(p) then return end`. Nothing
-- reusable lives in the monolith; nothing that touches monolith locals lives
-- here except through those closures.
--
-- Client module contract (see docs/MP-06-FRAMEWORK.md):
--   return { init(kit), onPacket(p), onEnd(), controlsText = {...} }
-- init runs once per client lifetime (memoised); onPacket receives every packet
-- of this trial (begin included) plus observed generic kinds; onEnd clears
-- module tables -- the router tears down HUD, pad, keys, connections, tweens,
-- camera, movement, mouse icon, CountText and the token by itself.
--
-- REQ-IP-01: no reference-game name appears in this file.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TrialClientKit = {}

-- UI palette (the monolith's constants) + the world PS1 palette, a byte-for-byte
-- mirror of the server TrialKit.PALETTE.
TrialClientKit.PALETTE = {
	PHOSPHOR = Color3.fromHex("78FFAA"),
	IDLE = Color3.fromHex("8CE8AE"),
	DIM = Color3.fromHex("2E6B4A"),
	AMBER = Color3.fromHex("FFBA3C"),
	DANGER = Color3.fromRGB(255, 58, 44),
	WARN = Color3.fromRGB(255, 176, 40),
	SAFE = Color3.fromRGB(120, 208, 128),
	PANEL = Color3.fromRGB(9, 12, 10),
	INK = Color3.fromRGB(2, 6, 4),
	BLOOD = Color3.fromRGB(120, 8, 6),
	world = {
		Void = Color3.fromRGB(12, 12, 14),
		Concrete = Color3.fromRGB(96, 96, 92),
		WetConcrete = Color3.fromRGB(68, 70, 66),
		Steel = Color3.fromRGB(140, 146, 150),
		Rust = Color3.fromRGB(122, 58, 34),
		Hazard = Color3.fromRGB(196, 160, 32),
		Signal = Color3.fromRGB(200, 32, 32),
		Blood = Color3.fromRGB(120, 16, 16),
		Grime = Color3.fromRGB(58, 72, 52),
		Bone = Color3.fromRGB(204, 196, 176),
		Sodium = Color3.fromRGB(232, 176, 88),
	},
}

local HUD_ZINDEX = 58     -- below Announce 60 / Fader 70: death cards and fades cover it
local PAD_ZINDEX = 68     -- same as TouchControls, above Scope.Mask 65
local DEFAULT_SEND_COOLDOWN = 0.1

-- The kinds the router lets a module OBSERVE while the legacy handler still runs.
local OBSERVED = { count = true, go = true, announce = true, hide = true, gorefx = true, role = true }

-- CAMERA ----------------------------------------------------------------------
-- Called from the monolith's RenderStepped writer while `trialCam` is set.
-- cam = { mode = "top"|"fixed"|"follow", ... } owned by the router.
--   top:    eye = subject + (0, height, -back), lerped, looking at the subject.
--           Reproduces the legacy top-down runner cam WITHOUT the yaw lock and
--           without forward-only movement. fixed=true freezes the first frame's
--           eye (arena-wide shot); radius shrinks height/back proportionally.
--   follow: eye = subject + offset, look = subject + look.
--   fixed:  a constant CFrame.
function TrialClientKit.computeCamera(cam, char, camera, dt)
	if cam.mode == "fixed" then
		return cam.cframe or camera.CFrame
	end
	local subject = cam.subject
	if typeof(subject) ~= "Instance" or not subject.Parent then
		subject = char and char:FindFirstChild("HumanoidRootPart") or nil
	end
	local target = subject and subject.Position or (cam.lastTarget or camera.CFrame.Position)
	cam.lastTarget = target
	if cam.mode == "follow" then
		local eye = target + (cam.offset or Vector3.new(0, 20, -17))
		local look = target + (cam.look or Vector3.new(0, 3, 0))
		local lerp = cam.lerp or 6
		cam.eye = cam.eye and cam.eye:Lerp(eye, math.min((dt or 0.016) * lerp, 1)) or eye
		return CFrame.lookAt(cam.eye, look)
	end
	-- "top"
	local height = cam.height or 24
	local back = cam.back or 9
	if cam.radius then
		local scale = math.max(cam.radius / 24, 0.35)
		height = height * scale
		back = back * scale
	end
	if cam.fixed and cam.frozenEye then
		return CFrame.lookAt(cam.frozenEye, cam.frozenLook)
	end
	local eye = target + Vector3.new(0, height, -back)
	local lerp = cam.lerp or 6
	cam.eye = cam.eye and cam.eye:Lerp(eye, math.min((dt or 0.016) * lerp, 1)) or eye
	if cam.fixed then
		cam.frozenEye = eye
		cam.frozenLook = target
		return CFrame.lookAt(eye, target)
	end
	return CFrame.lookAt(cam.eye, cam.eye + Vector3.new(0, -height, back * 1.6))
end

-- KIT -------------------------------------------------------------------------
-- One kit per trial id, created lazily by the router and handed to init(kit)
-- exactly once. Everything it allocates for a round is tracked and released by
-- kit._teardown() (router-only), so a module's onEnd rarely needs more than
-- clearing its own tables.
local function newKit(trialId, deps, router)
	local kit = {}
	kit.trialId = trialId
	kit.player = deps.player
	kit.machine = deps.machine
	kit.palette = TrialClientKit.PALETTE

	local hud, pad, edge = nil, nil, nil
	local conns = {}          -- tracked RBXScriptConnections
	local tweens = {}         -- tracked Tween objects
	local binds = {}          -- [name] = { conns = {...} }
	local lastSent = {}       -- [action] = os.clock()
	local seq = 0
	local lastTapPos = nil    -- last touch tap, for mouseRay on touch devices
	kit._deadlineAt = nil     -- server time from ev="deadline"

	-- Lives as long as the kit (not torn down per round): remembers where the
	-- last touch landed so mouseRay can pick under a finger.
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTapPos = input.Position
		end
	end)

	function kit.isActive()
		return router.activeId == trialId
	end

	function kit.roundToken()
		return deps.getToken()
	end

	function kit.deadline()
		return kit._deadlineAt
	end

	function kit.serverNow()
		return workspace:GetServerTimeNow()
	end

	function kit.touchAllowed()
		return deps.touchAllowed()
	end

	function kit.character()
		return deps.player.Character
	end

	function kit.root()
		local char = deps.player.Character
		return char and char:FindFirstChild("HumanoidRootPart") or nil
	end

	-- D3 packet: flat legacy fields + seq/v/data. Dropped when the trial is
	-- not active or no token has arrived; per-action client cooldown mirrors
	-- the server gate so a spammed key does not fill the remote.
	function kit.send(action, data, cooldown)
		if not kit.isActive() then return false end
		local token = deps.getToken()
		if not token or not deps.TrialInput then return false end
		local now = os.clock()
		if now < (lastSent[action] or 0) + (cooldown or DEFAULT_SEND_COOLDOWN) then return false end
		lastSent[action] = now
		seq += 1
		deps.TrialInput:FireServer({
			trialId = trialId,
			action = action,
			roundToken = token,
			seq = seq,
			v = 1,
			data = data,
		})
		return true
	end

	-- UI ----------------------------------------------------------------------
	function kit.hud()
		if hud and hud.Parent then return hud end
		hud = Instance.new("Frame")
		hud.Name = "TrialHud_" .. trialId
		hud.BackgroundTransparency = 1
		hud.Size = UDim2.new(1, 0, 1, 0)
		hud.ZIndex = HUD_ZINDEX
		hud.Parent = deps.machine
		return hud
	end

	function kit.pad()
		if pad and pad.Parent then return pad end
		pad = Instance.new("Frame")
		pad.Name = "TrialTouch_" .. trialId
		pad.BackgroundTransparency = 1
		pad.Size = UDim2.new(1, 0, 1, 0)
		pad.ZIndex = PAD_ZINDEX
		pad.Visible = deps.touchAllowed()
		pad.Parent = deps.machine
		return pad
	end

	local function toAlign(a)
		if typeof(a) == "EnumItem" then return a end
		if a == "Left" then return Enum.TextXAlignment.Left end
		if a == "Right" then return Enum.TextXAlignment.Right end
		return Enum.TextXAlignment.Center
	end

	function kit.label(parent, o)
		o = o or {}
		local l = Instance.new("TextLabel")
		l.Name = o.name or "Label"
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.TextSize = o.textSize or 20
		l.TextColor3 = o.color or TrialClientKit.PALETTE.IDLE
		l.Text = o.text or ""
		l.TextXAlignment = toAlign(o.align)
		l.Size = o.size or UDim2.new(0, 400, 0, 28)
		l.Position = o.pos or UDim2.new(0.5, 0, 0, 24)
		l.AnchorPoint = o.anchor or Vector2.new(0.5, 0)
		l.ZIndex = (parent and parent.ZIndex or 1) + 1
		l.Parent = parent
		return l
	end

	function kit.panel(parent, size, pos)
		local f = Instance.new("Frame")
		f.Name = "Panel"
		f.AnchorPoint = Vector2.new(0.5, 1)
		f.Position = pos or UDim2.new(0.5, 0, 1, -28)
		f.Size = size or UDim2.new(0, 300, 0, 74)
		f.BackgroundColor3 = TrialClientKit.PALETTE.PANEL
		f.BackgroundTransparency = 0.25
		f.BorderSizePixel = 0
		f.ZIndex = (parent and parent.ZIndex or 1) + 1
		f.Parent = parent
		return f
	end

	-- 110x110 touch button in the shipped style. pos = UDim2 (AnchorPoint .5/1).
	function kit.button(parent, name, text, pos, color, onActivated)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = pos or UDim2.new(0.5, 0, 1, -120)
		b.Size = UDim2.new(0, 110, 0, 110)
		b.BackgroundColor3 = Color3.fromRGB(12, 16, 13)
		b.BackgroundTransparency = 0.2
		b.BorderSizePixel = 0
		b.Font = Enum.Font.Code
		b.TextSize = 18
		b.TextColor3 = color or TrialClientKit.PALETTE.IDLE
		b.Text = text
		b.ZIndex = (parent and parent.ZIndex or 1) + 1
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 12)
		round.Parent = b
		b.Parent = parent
		if onActivated then
			table.insert(conns, b.Activated:Connect(function()
				if not kit.isActive() then return end
				onActivated()
			end))
		end
		return b
	end

	-- Fill bar. Returns { frame, fill, set(fraction) }.
	function kit.meter(parent, o)
		o = o or {}
		local frame = Instance.new("Frame")
		frame.Name = o.name or "Meter"
		frame.AnchorPoint = o.anchor or Vector2.new(0.5, 0)
		frame.Position = o.pos or UDim2.new(0.5, 0, 0, 64)
		frame.Size = o.size or UDim2.new(0, 240, 0, 14)
		frame.BackgroundColor3 = Color3.fromRGB(40, 46, 40)
		frame.BorderSizePixel = 0
		frame.ZIndex = (parent and parent.ZIndex or 1) + 1
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = o.color or TrialClientKit.PALETTE.SAFE
		fill.BorderSizePixel = 0
		fill.ZIndex = frame.ZIndex + 1
		fill.Parent = frame
		frame.Parent = parent
		local m = { frame = frame, fill = fill }
		function m.set(fraction)
			fill.Size = UDim2.new(math.clamp(tonumber(fraction) or 0, 0, 1), 0, 1, 0)
		end
		return m
	end

	-- Countdown label from a server-time deadline (workspace:GetServerTimeNow()
	-- based -- the kit converts nothing per second, no packets). endsAt defaults
	-- to the deadline the server sent with ev="deadline".
	function kit.timer(endsAt, parent, o)
		o = o or {}
		local label = kit.label(parent or kit.hud(), {
			name = "Timer", text = "", textSize = o.textSize or 26,
			color = o.color or TrialClientKit.PALETTE.IDLE,
			size = o.size or UDim2.new(0, 160, 0, 32),
			pos = o.pos or UDim2.new(1, -24, 0, 18), anchor = o.anchor or Vector2.new(1, 0),
			align = o.align or "Right",
		})
		local t = { label = label, running = true }
		local function update()
			local at = endsAt or kit._deadlineAt
			if not at then
				label.Text = ""
				return
			end
			local left = math.max(0, at - workspace:GetServerTimeNow())
			label.Text = string.format("%02d.%d", math.floor(left), math.floor((left % 1) * 10))
			if left <= 5 then label.TextColor3 = TrialClientKit.PALETTE.DANGER end
		end
		update()
		local conn = RunService.RenderStepped:Connect(function()
			if not t.running or not kit.isActive() then return end
			update()
		end)
		table.insert(conns, conn)
		function t.stop()
			t.running = false
		end
		return t
	end

	-- The client's showAnnounce; style "death" is the death card.
	function kit.card(text, style)
		deps.showCard(text or "", style)
	end

	-- Peripheral warning: a UIStroke around the whole screen (Canteen's edge glow).
	function kit.edgeGlow(color, transparency, tweenSecs)
		local h = kit.hud()
		if not edge or not edge.Parent then
			local holder = Instance.new("Frame")
			holder.Name = "Edge"
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, 0, 1, 0)
			holder.ZIndex = h.ZIndex
			edge = Instance.new("UIStroke")
			edge.Name = "Glow"
			edge.Thickness = 12
			edge.Transparency = 1
			edge.Parent = holder
			holder.Parent = h
		end
		if color then edge.Color = color end
		local target = transparency == nil and 0 or transparency
		if tweenSecs and tweenSecs > 0 then
			kit.tween(edge, { Transparency = target }, tweenSecs)
		else
			edge.Transparency = target
		end
		return edge
	end

	-- Types text into a label; stops when the trial ends.
	function kit.typewrite(label, text, cps)
		local gen = router.generation
		task.spawn(function()
			label.Text = ""
			for i = 1, #text do
				if not kit.isActive() or router.generation ~= gen or not label.Parent then return end
				label.Text = string.sub(text, 1, i)
				task.wait(1 / (cps or 24))
			end
		end)
	end

	function kit.sfx(name)
		deps.sfx(name)
	end

	-- CAMERA / MOVEMENT (owned by the monolith; the kit only sets its modes) --
	kit.camera = {}
	-- Bounds of the static arena (runtime folder excluded): centre, size.
	local function arenaBounds()
		local a = kit.arena()
		if not a then return nil end
		local runtime = a:FindFirstChild(string.upper(trialId) .. "_Runtime")
		local minV, maxV = nil, nil
		for _, d in a:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 and not (runtime and d:IsDescendantOf(runtime)) then
				local half = d.Size / 2
				local lo, hi = d.Position - half, d.Position + half
				minV = minV and Vector3.new(math.min(minV.X, lo.X), math.min(minV.Y, lo.Y), math.min(minV.Z, lo.Z)) or lo
				maxV = maxV and Vector3.new(math.max(maxV.X, hi.X), math.max(maxV.Y, hi.Y), math.max(maxV.Z, hi.Z)) or hi
			end
		end
		if not minV then return nil end
		return (minV + maxV) / 2, maxV - minV
	end
	function kit.camera.top(o)
		o = o or {}
		if o.fixed then
			-- One arena-wide shot from the replicated bounds; falls back to a
			-- freeze of the first follow frame while the arena is not yet here.
			local center, size = arenaBounds()
			if center then
				local extent = math.max(size.X, size.Z, 20)
				local height = o.height or (extent * 0.8 + 6)
				local back = o.back or (extent * 0.2)
				local eye = Vector3.new(center.X, center.Y + height, center.Z - back)
				deps.setCam({ mode = "fixed", cframe = CFrame.lookAt(eye, Vector3.new(center.X, center.Y, center.Z)) })
				return
			end
		end
		deps.setCam({
			mode = "top", height = o.height or 24, back = o.back or 9, lerp = o.lerp or 6,
			radius = o.radius, fixed = o.fixed == true, subject = o.subject,
		})
	end
	function kit.camera.fixed(cframe)
		deps.setCam({ mode = "fixed", cframe = cframe })
	end
	function kit.camera.follow(o)
		o = o or {}
		deps.setCam({ mode = "follow", offset = o.offset, look = o.look, lerp = o.lerp, subject = o.subject })
	end
	function kit.camera.restore()
		deps.setCam(nil)
		deps.restoreCamera()
	end

	kit.movement = {}
	function kit.movement.set(walkSpeed)
		deps.setMove("trial", tonumber(walkSpeed) or 0)
	end
	function kit.movement.freeze()
		deps.setMove("frozen", 0)
	end

	-- INPUT -------------------------------------------------------------------
	local function matches(input, list)
		for _, want in ipairs(list) do
			if typeof(want) == "EnumItem" then
				if want.EnumType == Enum.KeyCode and input.KeyCode == want then return true end
				if want.EnumType == Enum.UserInputType and input.UserInputType == want then return true end
			end
		end
		return false
	end

	-- name: unbind handle. inputs: KeyCodes and/or UserInputTypes. Edge semantics
	-- (began once per press, ended once per release), gameProcessed guard.
	function kit.bindKey(name, inputs, onBegan, onEnded)
		kit.unbind(name)
		local held = false
		local b = { conns = {} }
		table.insert(b.conns, UserInputService.InputBegan:Connect(function(input, gp)
			if gp or not kit.isActive() then return end
			if not matches(input, inputs) then return end
			if held then return end
			held = true
			if onBegan then onBegan(input) end
		end))
		table.insert(b.conns, UserInputService.InputEnded:Connect(function(input)
			if not matches(input, inputs) then return end
			if not held then return end
			held = false
			if onEnded and kit.isActive() then onEnded(input) end
		end))
		binds[name] = b
	end

	-- Up/Down/Left/Right + WASD + DPad, fn("Up"|"Down"|"Left"|"Right") on press.
	function kit.bindArrows(fn)
		local map = {
			[Enum.KeyCode.Up] = "Up", [Enum.KeyCode.W] = "Up", [Enum.KeyCode.DPadUp] = "Up",
			[Enum.KeyCode.Down] = "Down", [Enum.KeyCode.S] = "Down", [Enum.KeyCode.DPadDown] = "Down",
			[Enum.KeyCode.Left] = "Left", [Enum.KeyCode.A] = "Left", [Enum.KeyCode.DPadLeft] = "Left",
			[Enum.KeyCode.Right] = "Right", [Enum.KeyCode.D] = "Right", [Enum.KeyCode.DPadRight] = "Right",
		}
		kit.unbind("__arrows")
		local b = { conns = {} }
		table.insert(b.conns, UserInputService.InputBegan:Connect(function(input, gp)
			if gp or not kit.isActive() then return end
			local dir = map[input.KeyCode]
			if dir then fn(dir) end
		end))
		binds["__arrows"] = b
	end

	function kit.unbind(name)
		local b = binds[name]
		if not b then return end
		for _, c in ipairs(b.conns) do c:Disconnect() end
		binds[name] = nil
	end

	function kit.onRender(fn)
		local c = RunService.RenderStepped:Connect(function(dt)
			if not kit.isActive() then return end
			fn(dt)
		end)
		table.insert(conns, c)
		return c
	end

	function kit.onHeartbeat(fn)
		local c = RunService.Heartbeat:Connect(function(dt)
			if not kit.isActive() then return end
			fn(dt)
		end)
		table.insert(conns, c)
		return c
	end

	-- Ray from the mouse (or the last touch tap) into the world.
	function kit.mouseRay(maxDist, filterInstances)
		local camera = deps.camera or workspace.CurrentCamera
		local pos
		if lastTapPos and UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			pos = lastTapPos
		else
			pos = UserInputService:GetMouseLocation()
		end
		local ray = camera:ViewportPointToRay(pos.X, pos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local exclude = {}
		if deps.player.Character then table.insert(exclude, deps.player.Character) end
		if filterInstances then
			for _, inst in ipairs(filterInstances) do table.insert(exclude, inst) end
		end
		params.FilterDescendantsInstances = exclude
		return workspace:Raycast(ray.Origin, ray.Direction * (maxDist or 200), params)
	end

	-- WORLD -------------------------------------------------------------------
	function kit.gore(pos, power)
		deps.applyGoreFx(pos, power or 1, false)
	end

	function kit.arena()
		local root = workspace:FindFirstChild("KenopsiaArenas")
		return root and root:FindFirstChild(trialId) or nil
	end

	function kit.arenaRuntime()
		local a = kit.arena()
		return a and a:FindFirstChild(string.upper(trialId) .. "_Runtime") or nil
	end

	-- Telegraph helper: recolour (and neon) a part for `seconds`, then restore.
	-- The restore always runs, active or not, so no arena part is left lit.
	function kit.flash(part, color, seconds)
		if not part or not part:IsA("BasePart") then return end
		if part:GetAttribute("KitFlashing") then return end
		local c0, m0 = part.Color, part.Material
		part:SetAttribute("KitFlashing", true)
		part.Color = color or TrialClientKit.PALETTE.world.Hazard
		part.Material = Enum.Material.Neon
		task.delay(seconds or 0.3, function()
			if part.Parent then
				part.Color = c0
				part.Material = m0
			end
			part:SetAttribute("KitFlashing", nil)
		end)
	end

	function kit.tween(instance, props, seconds, style)
		local info = TweenInfo.new(seconds or 0.3, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tw = TweenService:Create(instance, info, props)
		table.insert(tweens, tw)
		tw:Play()
		return tw
	end

	-- ROUTER-ONLY: release everything the round allocated. Idempotent.
	function kit._teardown()
		for name in binds do kit.unbind(name) end
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		conns = {}
		for _, tw in ipairs(tweens) do pcall(function() tw:Cancel() end) end
		tweens = {}
		if hud then hud:Destroy() end
		hud = nil
		edge = nil
		if pad then pad:Destroy() end
		pad = nil
		lastSent = {}
		kit._deadlineAt = nil
	end

	return kit
end

-- ROUTER ----------------------------------------------------------------------
-- deps (all closures over the monolith's locals):
--   player, machine, camera, TrialInput, sfx(name), touchAllowed(),
--   showCard(text, style), applyGoreFx(pos, power, force),
--   getToken() / setToken(tok), setMove(state, speed), setCam(tbl|nil),
--   clearSpectate(), restoreCamera(), hideCountText(), trialClientsFolder
function TrialClientKit.newRouter(deps)
	local router = {}
	router.activeId = nil
	router.generation = 0
	local modules = {}     -- [trialId] = { mod = table, kit = kit, inited = bool }
	local activeEntry = nil

	local function loadModule(trialId)
		local entry = modules[trialId]
		if entry then return entry end
		local folder = deps.trialClientsFolder
		local ms = folder and folder:FindFirstChild(trialId)
		if not ms then
			warn(("[TrialRouter] no client module for trial '%s'"):format(tostring(trialId)))
			return nil
		end
		local ok, mod = pcall(require, ms)
		if not ok or type(mod) ~= "table" then
			warn(("[TrialRouter] client module '%s' failed to load: %s"):format(tostring(trialId), tostring(mod)))
			return nil
		end
		entry = { mod = mod, kit = newKit(trialId, deps, router), inited = false }
		modules[trialId] = entry
		return entry
	end

	local function callSafe(entry, fname, ...)
		local fn = entry and entry.mod[fname]
		if type(fn) ~= "function" then return end
		local ok, err = pcall(fn, ...)
		if not ok then
			warn(("[TrialRouter:%s] %s error: %s"):format(tostring(router.activeId), fname, tostring(err)))
		end
	end

	-- Idempotent. Ends the active module and returns the monolith to idle:
	-- no trial cam, no spectate cam, frozen movement, mouse visible, no token.
	function router.endActive()
		local entry = activeEntry
		if not entry then return end
		callSafe(entry, "onEnd")
		router.generation += 1
		activeEntry = nil
		router.activeId = nil
		pcall(entry.kit._teardown)
		deps.setCam(nil)
		-- New trials never send `role none`, which is what clears these today.
		deps.clearSpectate()
		deps.restoreCamera()
		deps.setMove("frozen", 0)
		deps.hideCountText()
		pcall(function() UserInputService.MouseIconEnabled = true end)
		deps.setToken(nil)
	end

	local function shallowCopy(p)
		return table.clone(p)
	end

	-- Returns true when the packet was consumed (nothing else may handle it).
	function router.handle(p)
		if p.kind == "trial" and type(p.trialId) == "string" then
			local ev = p.ev
			if ev == "begin" then
				if activeEntry and router.activeId ~= p.trialId then router.endActive() end
				if activeEntry and router.activeId == p.trialId then
					-- A second begin for the same trial (next round): fresh HUD.
					router.endActive()
				end
				local entry = loadModule(p.trialId)
				if not entry then return true end
				router.generation += 1
				activeEntry = entry
				router.activeId = p.trialId
				if type(p.roundToken) == "string" then deps.setToken(p.roundToken) end
				-- Movement starts frozen every round; the module lifts it on GO.
				deps.setMove("frozen", 0)
				if not entry.inited then
					entry.inited = true
					callSafe(entry, "init", entry.kit)
				end
				callSafe(entry, "onPacket", p)
				return true
			end
			if ev == "end" then
				if activeEntry and router.activeId == p.trialId then router.endActive() end
				return true
			end
			if activeEntry and router.activeId == p.trialId then
				if type(p.roundToken) == "string" then deps.setToken(p.roundToken) end
				if ev == "deadline" and type(p.endsAt) == "number" then
					activeEntry.kit._deadlineAt = p.endsAt
				end
				callSafe(activeEntry, "onPacket", p)
			end
			return true
		end
		if activeEntry and OBSERVED[p.kind] then
			-- F-1 companion: a spectate role packet may carry the token too.
			if type(p.roundToken) == "string" then deps.setToken(p.roundToken) end
			callSafe(activeEntry, "onPacket", shallowCopy(p))
			return false
		end
		return false
	end

	-- For MachineLayout / diagnostics: the loaded module table for an id.
	function router.moduleOf(trialId)
		local entry = loadModule(trialId)
		return entry and entry.mod or nil
	end

	return router
end

return TrialClientKit
