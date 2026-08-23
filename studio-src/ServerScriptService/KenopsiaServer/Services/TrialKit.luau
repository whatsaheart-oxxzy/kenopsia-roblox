--!nonstrict
-- TRIAL KIT (MP-05 Framework, plan section B) -- the one server library the twelve new
-- trials are written against.
--
-- It is a library of helpers plus a ROUND OBJECT. The behaviour is Minefield's
-- (livingOf / roomActive / announce / tellOne / the C1.a input chain / the C1.e
-- cleanup / the D12 death sequence), lifted once so twelve modules do not each
-- carry their own copy that can drift.
--
-- NO per-room mutable "current" (MP-01 section 7.5). All round state hangs off the
-- round object; the only module tables are the two round registries (by
-- trialId:roomId and by trialId:userId), both cleared by R:cleanup(), plus the
-- per-trial arena refs cache and the per-trial input connection (both
-- idempotent init products, never round state).
--
-- REQ-IP-01: this file names no reference-game minigame anywhere.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodFX = require(script.Parent.BloodFX)

local Shared = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
-- P1.5: the death timeline and the 3-2-1 step come from the feel bible.
local Feel = require(Shared:WaitForChild("Config"):WaitForChild("FeelConfig"))
local Rules = Shared:WaitForChild("Rules")
local Pacing = require(Rules:WaitForChild("Pacing"))
local TrialRules = require(Rules:WaitForChild("TrialRules"))

local TrialKit = {}

-- B.1 CONSTANTS AND PALETTE ---------------------------------------------------
-- World PS1 palette (MP-04 section 0.5). The client kit mirrors it byte-for-byte; a
-- change here is a change there.
TrialKit.PALETTE = {
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
}
TrialKit.BAND = TrialRules.BAND
TrialKit.key = TrialRules.key
TrialKit.HOME_FALLBACK = Vector3.new(0, 5, 0)
TrialKit.Rules = TrialRules

-- Seconds between a death and the spectate packet (Minefield's 3.2), the cover
-- hold at round end (Minefield's 0.6) and the default input cooldown.
local DEATH_CAM_DELAY = Feel.Death.Spectate
local END_COVER_SECONDS = 0.6
local DEFAULT_COOLDOWN = 0.25
local FAILSAFE_EXTRA = 20
local DEFAULT_WALKSPEED = 16

-- Registries: the ONLY module-level state that refers to a round, and R:cleanup
-- removes every entry it added.
local roundsByRoom = {}   -- [trialId .. ":" .. roomId] = R
local roundsByUser = {}   -- [trialId .. ":" .. userId] = R
local refsByTrial = {}    -- [trialId] = refs table from ensureArena
local inputSpecs = {}     -- [trialId] = normalised spec (idempotent wireInput)
local inputDispatch = nil -- the ONE OnServerEvent connection for TrialInput

local function roomKey(trialId, room)
	return trialId .. ":" .. tostring(room and room.id or "?")
end
local function userKey(trialId, userId)
	return trialId .. ":" .. tostring(userId)
end

local function remotesFolder()
	return ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
end

local function machineState()
	local remotes = ReplicatedStorage:FindFirstChild("Kenopsia")
	remotes = remotes and remotes:FindFirstChild("Remotes")
	return remotes and remotes:FindFirstChild("MachineState") or nil
end

local function v3(pos)
	return { pos.X, pos.Y, pos.Z }
end

-- B.2 ARENA BUILDERS ----------------------------------------------------------
-- All Anchored, SmoothPlastic, CastShadow=false, Smooth surfaces. Flat colours
-- from the palette, no textures: the PS1 look is the lighting's job.
function TrialKit.part(spec)
	local p = Instance.new("Part")
	p.Name = spec.name or "Part"
	if spec.shape then p.Shape = spec.shape end
	p.Anchored = true
	p.CastShadow = false
	p.Material = spec.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Color = spec.color or TrialKit.PALETTE.Concrete
	p.Size = spec.size or Vector3.new(1, 1, 1)
	if spec.cf then
		p.CFrame = spec.cf
	elseif spec.pos then
		p.CFrame = CFrame.new(spec.pos)
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = spec.transparency or 0
	if spec.canCollide == false then p.CanCollide = false end
	if spec.canQuery ~= nil then p.CanQuery = spec.canQuery end
	if spec.canTouch ~= nil then p.CanTouch = spec.canTouch end
	if spec.parent then p.Parent = spec.parent end
	return p
end

function TrialKit.box(name, size, cf, color, parent)
	return TrialKit.part({ name = name, size = size, cf = cf, color = color, parent = parent })
end

-- Invisible, non-colliding, non-queryable 1^3 reference part (spawn spots,
-- camera posts, lookAt targets). Never Touched, never raycast.
function TrialKit.marker(name, cf, parent)
	return TrialKit.part({
		name = name, size = Vector3.new(1, 1, 1), cf = cf, parent = parent,
		transparency = 1, canCollide = false, canQuery = false, canTouch = false,
	})
end

-- Floor whose TOP is at origin.Y (thickness 1).
function TrialKit.slab(parent, origin, sizeX, sizeZ, color)
	return TrialKit.part({
		name = "Slab", size = Vector3.new(sizeX, 1, sizeZ),
		cf = CFrame.new(origin.X, origin.Y - 0.5, origin.Z),
		color = color or TrialKit.PALETTE.Concrete, parent = parent,
	})
end

-- Four walls around a sizeX x sizeZ footprint centred on origin, standing on
-- origin.Y. Returns { n, s, e, w }.
function TrialKit.wallBox(parent, origin, sizeX, sizeZ, height, thickness, color)
	local t = thickness or 1
	local h = height or 8
	local c = color or TrialKit.PALETTE.WetConcrete
	local y = origin.Y + h / 2
	return {
		n = TrialKit.part({ name = "WallN", size = Vector3.new(sizeX + 2 * t, h, t),
			cf = CFrame.new(origin.X, y, origin.Z - sizeZ / 2 - t / 2), color = c, parent = parent }),
		s = TrialKit.part({ name = "WallS", size = Vector3.new(sizeX + 2 * t, h, t),
			cf = CFrame.new(origin.X, y, origin.Z + sizeZ / 2 + t / 2), color = c, parent = parent }),
		e = TrialKit.part({ name = "WallE", size = Vector3.new(t, h, sizeZ),
			cf = CFrame.new(origin.X + sizeX / 2 + t / 2, y, origin.Z), color = c, parent = parent }),
		w = TrialKit.part({ name = "WallW", size = Vector3.new(t, h, sizeZ),
			cf = CFrame.new(origin.X - sizeX / 2 - t / 2, y, origin.Z), color = c, parent = parent }),
	}
end

-- cols x rows plates (cell x 1 x cell, top at origin.Y) centred on origin.
-- Cell lookup is ARITHMETIC (TrialRules), never Touched.
function TrialKit.floorGrid(parent, origin, cols, rows, cell, gap, color, namePrefix)
	local g = TrialRules.newGrid(cols, rows, cell, gap or 0, origin.X, origin.Z)
	g.origin = origin
	g.parts = {}
	local prefix = namePrefix or "Plate"
	for c = 1, cols do
		g.parts[c] = {}
		for r = 1, rows do
			local x, z = TrialRules.cellCenter(g, c, r)
			g.parts[c][r] = TrialKit.part({
				name = ("%s_%d_%d"):format(prefix, c, r),
				size = Vector3.new(cell, 1, cell),
				cf = CFrame.new(x, origin.Y - 0.5, z),
				color = color or TrialKit.PALETTE.Concrete,
				parent = parent,
			})
		end
	end
	function g.cellCenter(c, r)
		local x, z = TrialRules.cellCenter(g, c, r)
		return Vector3.new(x, origin.Y, z)
	end
	function g.cellOf(pos)
		return TrialRules.cellOf(g, pos.X, pos.Z)
	end
	return g
end

-- workspace.KenopsiaArenas.<id>, created if absent (both levels).
function TrialKit.ensureArenaFolder(trialId)
	local root = workspace:FindFirstChild("KenopsiaArenas")
	if not root then
		root = Instance.new("Folder")
		root.Name = "KenopsiaArenas"
		root.Parent = workspace
	end
	local a = root:FindFirstChild(trialId)
	if not a then
		a = Instance.new("Folder")
		a.Name = trialId
		a.Parent = root
	end
	return a
end

-- Idempotent static arena. Called from init() (in pcall) and again at round
-- start (cheap: the cached refs come back). buildFn(folder, origin) must NOT
-- yield and must return a refs table with refs.spawn (Part or {CFrame...}) and
-- refs.cam (Part) for the spectate camera.
--
-- The "Built" attribute survives a place save; the refs cache does not. A folder
-- that is Built but has no cached refs (server started from a saved place) is
-- cleared and rebuilt, so the refs always describe what is actually there.
function TrialKit.ensureArena(trialId, buildFn)
	local origins = Config.Arenas and Config.Arenas.Origins
	local origin = origins and origins[trialId]
	if not origin then
		warn(("[TrialKit] no arena origin for '%s' in GameConfig.Arenas.Origins"):format(tostring(trialId)))
		return nil
	end
	local folder = TrialKit.ensureArenaFolder(trialId)
	local cached = refsByTrial[trialId]
	if folder:GetAttribute("Built") == true and cached then
		return cached
	end
	folder:SetAttribute("Built", false)
	for _, child in folder:GetChildren() do
		child:Destroy()
	end
	local refs = buildFn(folder, origin) or {}
	refs.folder = folder
	refs.origin = origin
	refsByTrial[trialId] = refs
	folder:SetAttribute("Built", true)
	return refs
end

-- Cached refs of an already-built arena (nil until ensureArena ran).
function TrialKit.arenaRefs(trialId)
	return refsByTrial[trialId]
end

-- Acceptance: < 300 static parts per arena.
function TrialKit.partCount(folder)
	local n = 0
	if not folder then return 0 end
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

-- B.3 ROOM / AUDIENCE / MESSAGING (verbatim semantics of Minefield) ----------
function TrialKit.livingOf(room)
	local out = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		local char = plr and plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if plr and char and hum and root and hum.Health > 0 then
			out[mm.userId] = { player = plr, char = char, hum = hum, root = root }
		end
	end
	return out
end

-- P1.6/#50: the MachineFlow watchdog cancels a hung round's thread, which
-- skips every cleanup on that thread. This runs the kit round's cleanup from
-- the outside; legacy trials expose module.abort instead.
function TrialKit.abortRoom(trialId, room)
	local R = roundsByRoom[roomKey(trialId, room)]
	if R then
		pcall(function() R:cleanup() end)
	end
end

function TrialKit.audienceOf(room)
	local audience = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then table.insert(audience, plr) end
	end
	return audience
end

function TrialKit.roomActive(room)
	return room ~= nil and #room.members > 0 and (room.phase == nil or room.phase == "Playing")
end

-- MachineState:FireClient to each member; never FireAllClients (MP-01 section 7.3).
function TrialKit.announce(room, payload)
	local remote = machineState()
	if not remote then return end
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then remote:FireClient(plr, payload) end
	end
end

function TrialKit.tellOne(userId, payload)
	local remote = machineState()
	local plr = Players:GetPlayerByUserId(userId)
	if remote and plr then remote:FireClient(plr, payload) end
end

-- D1 envelope: every packet of a new trial is {kind="trial", trialId, ev, ...}.
local function trialPacket(trialId, ev, fields)
	local p = {}
	if fields then
		for k, val in fields do p[k] = val end
	end
	p.kind = "trial"
	p.trialId = trialId
	p.ev = ev
	return p
end

function TrialKit.send(room, trialId, ev, fields)
	TrialKit.announce(room, trialPacket(trialId, ev, fields))
end

function TrialKit.sendOne(userId, trialId, ev, fields)
	TrialKit.tellOne(userId, trialPacket(trialId, ev, fields))
end

-- The legacy spectate packet, unchanged: the client's death cam is generic.
function TrialKit.spectatePacket(watchUserIds, camPart, lookPos, roundToken)
	local pos = camPart and camPart.Position or TrialKit.HOME_FALLBACK
	local look = lookPos or (camPart and camPart.Position - Vector3.new(0, 1, 0)) or TrialKit.HOME_FALLBACK
	return {
		kind = "role", role = "spectate",
		watch = watchUserIds or {},
		pos = v3(pos), look = v3(look),
		roundToken = roundToken,
	}
end

function TrialKit.deathCard(userId, text)
	TrialKit.tellOne(userId, { kind = "announce", style = "death", text = text })
end

-- D11 token mint.
function TrialKit.mintToken(trialId, sessionId, roundIndex)
	return TrialRules.token(trialId, sessionId, roundIndex, math.floor(os.clock() * 1000))
end

-- B.7 seeded randomness: nextInt(n) closure, identical in Studio and tests.
function TrialKit.rng(room, roundIndex)
	return TrialRules.rng(room and room.sessionId or "?", roundIndex)
end

-- B.4 INPUT WIRING ------------------------------------------------------------
-- The whole MP-01 validation chain, once. spec = { actions = {act=true,...},
-- cooldown = 0.25, perAction = {act = seconds}, handler = fn(player, ps, payload, R) }.
function TrialKit.wireInput(trialId, spec)
	local folder = remotesFolder()
	local remote = folder:FindFirstChild("TrialInput")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "TrialInput"
		remote.Parent = folder
	end
	-- Idempotent init: a second wireInput for the same trial replaces its spec.
	local actions = spec.actions or {}
	-- R-03: the array form is the one mistake here that fails SILENTLY and totally.
	-- `actions["cut"]` is nil for `{ "cut" }`, so step 3 below drops every packet and
	-- the trial renders perfectly while responding to nothing -- the same shape as the
	-- Canteen token bug. Normalise so it works, warn so it gets fixed; the Integrate
	-- stage reads the console anyway.
	if actions[1] ~= nil then
		warn(("[TrialKit:%s] actions was given as an array; expected a map like "
			.. "{ cut = true }. Normalising - fix the trial module."):format(trialId))
		local map = {}
		for _, name in ipairs(actions) do map[name] = true end
		actions = map
	end
	inputSpecs[trialId] = {
		actions = actions,
		cooldown = spec.cooldown or DEFAULT_COOLDOWN,
		perAction = spec.perAction or {},
		handler = spec.handler,
	}
	-- Perf pass 2 (#50): one dispatcher instead of one OnServerEvent connection
	-- per trial -- with 15 trials wired, every input packet used to wake 15
	-- handlers, 14 of which failed the trialId check.
	if inputDispatch then return remote end
	inputDispatch = remote.OnServerEvent:Connect(function(player, payload)
		-- 1-2: cheap identity checks first; the remote is shared by every trial.
		if type(payload) ~= "table" then return end
		local sp = type(payload.trialId) == "string" and inputSpecs[payload.trialId] or nil
		if not sp then return end
		-- 3: only actions this trial declared.
		local action = payload.action
		if type(action) ~= "string" or not sp.actions[action] then return end
		-- 4: a live round must own this player.
		local R = roundsByUser[userKey(payload.trialId, player.UserId)]
		if not R then return end
		-- 5-8: input window, phase, session snapshot, token freshness (C1.a).
		if not R.acceptInput then return end
		if not R.room or R.room.phase ~= "Playing" then return end
		if R.room.sessionId ~= R.sessionId then return end
		if payload.roundToken ~= R.roundToken then return end
		-- 9: membership and still playing.
		local ps = R.state[player.UserId]
		if not ps or ps.done then return end
		-- 10: monotonic seq when the client sends one (D3).
		if type(payload.seq) == "number" then
			-- R-02: NaN survives every comparison (`NaN <= x` is false), so without this
			-- line a client sending seq = NaN on every packet passes step 10 forever.
			-- Step 11 is the real replay bound inside a round; seq is advisory (D3),
			-- because a client that omits it skips this check entirely. No trial may
			-- derive ordering guarantees from seq.
			if payload.seq ~= payload.seq then return end
			if payload.seq <= (ps.lastSeq or 0) then return end
			ps.lastSeq = payload.seq
		end
		-- 11: per-player, per-action rate gate.
		local now = os.clock()
		ps.lastInput = ps.lastInput or {}
		if now < (ps.lastInput[action] or 0) + (sp.perAction[action] or sp.cooldown) then return end
		ps.lastInput[action] = now
		-- 12: the trial's handler, isolated: an error drops the packet, never
		-- the connection. Only payload.data is trial payload and the handler
		-- must range-check every field of it.
		if sp.handler then
			local ok, err = pcall(sp.handler, player, ps, payload, R)
			if not ok then
				warn(("[TrialKit:%s] input handler error: %s"):format(payload.trialId, tostring(err)))
			end
		end
	end)
	return remote
end

-- B.5 ROUND OBJECT ------------------------------------------------------------
local Round = {}
Round.__index = Round

function TrialKit.newRound(trialId, room, roundIndex, guard)
	local R = setmetatable({}, Round)
	R.trialId = trialId
	R.room = room
	R.sessionId = room.sessionId
	R.roundIndex = roundIndex or 1
	R.roundToken = TrialKit.mintToken(trialId, room.sessionId, R.roundIndex)
	R.state = {}
	for _, mm in room.members do
		R.state[mm.userId] = { done = false, lastInput = {}, lastSeq = 0 }
	end
	R.acceptInput = false
	R.runtime = nil
	R.cleaned = false
	R.t0 = nil
	R.deadline = nil
	R.failsafe = nil
	R.subjects = {}
	R.refs = refsByTrial[trialId]
	R.walkSpeed = DEFAULT_WALKSPEED
	R.restore = {}          -- [uid] = { hum, root, walk, jump, anchored }
	R.teardown = {}         -- LIFO fns from R:onCleanup
	R.samples = {}          -- [uid] = { pos, at }
	R.placed = {}           -- [uid] = CFrame from R:place
	-- REGISTER, then arm the guard, before any yield: an abort during the very
	-- first wait must find a cleanup to run.
	roundsByRoom[roomKey(trialId, room)] = R
	for _, mm in room.members do
		roundsByUser[userKey(trialId, mm.userId)] = R
	end
	if guard then
		guard.cleanup = function() R:cleanup() end
	end
	return R
end

-- True only while this exact round still owns its registry slot and the match
-- is still Playing. Every loop, wait and delayed callback tests this.
function Round:active()
	return roundsByRoom[roomKey(self.trialId, self.room)] == self
		and TrialKit.roomActive(self.room)
end

function Round:onCleanup(fn)
	table.insert(self.teardown, fn)
end

-- Perf pass 2 (#50): livingOf builds a fresh table (player/char/hum/root per
-- member) on EVERY call and the Round helpers called it per player per tick.
-- One cached copy with a 0.1 s TTL keeps the semantics (deaths surface within
-- a tick) at a fraction of the allocations.
function Round:living()
	local now = os.clock()
	if not self._living or now - (self._livingAt or 0) > 0.1 then
		self._living = TrialKit.livingOf(self.room)
		self._livingAt = now
	end
	return self._living
end

-- "<ID>_Runtime" under the arena folder; destroyed by cleanup.
function Round:runtimeFolder(arenaFolder)
	if self.runtime and self.runtime.Parent then return self.runtime end
	local f = Instance.new("Folder")
	f.Name = string.upper(self.trialId) .. "_Runtime"
	f.Parent = arenaFolder or (self.refs and self.refs.folder) or TrialKit.ensureArenaFolder(self.trialId)
	self.runtime = f
	return f
end

-- First packet of the round, to EVERY member (spectate-dead too). Carries the
-- token the client echoes on every input; the router adopts it (D2).
function Round:begin(fields)
	local p = {}
	if fields then
		for k, val in fields do p[k] = val end
	end
	p.roundToken = self.roundToken
	p.roundIndex = self.roundIndex
	p.roundCount = p.roundCount or Pacing.roundsFor(self.trialId, #self.room.members) or 1
	p.roundSeconds = p.roundSeconds or Pacing.RoundSeconds[self.trialId]
	TrialKit.send(self.room, self.trialId, "begin", p)
end

function Round:cover(text)
	TrialKit.announce(self.room, { kind = "announce", text = text or "" })
end

-- task.wait in <= 0.1 s slices; false as soon as the round is no longer active.
function Round:wait(seconds)
	local deadline = os.clock() + (seconds or 0)
	while os.clock() < deadline do
		if not self:active() then return false end
		task.wait(math.min(0.1, deadline - os.clock()))
	end
	return self:active()
end

function Round:openInput()
	self.acceptInput = true
end

function Round:closeInput()
	self.acceptInput = false
end

-- 3-2-1 then GO. Opens input, stamps t0 and applies the GO walk speed. False if
-- aborted (input stays closed). Also arms the default deadline (Pacing) when
-- the trial has not chosen one yet, so a trial may skip setDeadline entirely.
function Round:countdown()
	for c = 3, 1, -1 do
		if not self:active() then return false end
		TrialKit.announce(self.room, { kind = "count", n = c })
		if not self:wait(Feel.Countdown.StepSeconds) then return false end
	end
	if not self:active() then return false end
	TrialKit.announce(self.room, { kind = "go" })
	self.acceptInput = true
	self.t0 = os.clock()
	-- Belt and braces (D10): the client owns WalkSpeed, but the server also
	-- lifts the placement freeze at GO so a client module that never calls
	-- kit.movement.set still lets its player move.
	for uid, ps in self.state do
		if not ps.done then
			local s = self:living()[uid]
			if s and not (self.restore[uid] and self.restore[uid].anchoredNow) then
				s.hum.WalkSpeed = self.walkSpeed
			end
		end
	end
	if not self.deadline then self:setDeadline() end
	return true
end

-- spots = {CFrame,...} or fn(i, mm) -> CFrame; spots.walkSpeed (default 16, applied
-- at GO), spots.anchored (bool: seat the player, e.g. bench trials). Members with
-- no living character are marked done. Placement itself FREEZES the humanoid
-- (WalkSpeed 0, JumpPower 0) exactly like the legacy `role frozen=true`, so
-- nobody moves during the countdown; countdown() lifts it.
function Round:place(spots)
	local subjects = TrialKit.livingOf(self.room)
	self._living, self._livingAt = subjects, os.clock()
	self.subjects = subjects
	self.walkSpeed = (type(spots) == "table" and spots.walkSpeed) or DEFAULT_WALKSPEED
	local anchored = type(spots) == "table" and spots.anchored == true
	local i = 0
	for _, mm in self.room.members do
		local ps = self.state[mm.userId]
		local s = subjects[mm.userId]
		if not s then
			if ps then ps.done = true end
		else
			i += 1
			local cf
			if type(spots) == "function" then
				cf = spots(i, mm)
			elseif type(spots) == "table" then
				cf = spots[i] or spots[#spots]
			end
			if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
			if not self.restore[mm.userId] then
				self.restore[mm.userId] = {
					hum = s.hum, root = s.root, char = s.char,
					walk = s.hum.WalkSpeed, jump = s.hum.JumpPower,
					anchored = s.root.Anchored,
				}
			end
			s.hum.Health = s.hum.MaxHealth
			s.hum.WalkSpeed = 0
			s.hum.UseJumpPower = true
			s.hum.JumpPower = 0
			if typeof(cf) == "CFrame" then
				s.root.CFrame = cf
				self.placed[mm.userId] = cf
				self.samples[mm.userId] = { pos = cf.Position, at = os.clock() }
			end
			if anchored then
				s.root.Anchored = true
				self.restore[mm.userId].anchoredNow = true
			end
		end
	end
end

-- Server-side movement change mid-round, recorded for restore.
function Round:setMovement(uid, walkSpeed, anchored)
	local s = self:living()[uid]
	if not s then return end
	if not self.restore[uid] then
		self.restore[uid] = {
			hum = s.hum, root = s.root, char = s.char,
			walk = s.hum.WalkSpeed, jump = s.hum.JumpPower, anchored = s.root.Anchored,
		}
	end
	if walkSpeed ~= nil then s.hum.WalkSpeed = walkSpeed end
	if anchored ~= nil then
		s.root.Anchored = anchored
		self.restore[uid].anchoredNow = anchored
	end
end

-- The anti-teleport clamp every movement trial runs each tick. Reads the root
-- position; if it moved further than maxSpeed * dt * 1.5 (horizontally) since
-- the last good sample, or left the arena AABB, the root is snapped back to the
-- last good position and that position is returned. Never trusts the client.
-- aabb = { minX, maxX, minY, maxY, minZ, maxZ } (TrialRules.inBox shape) or nil.
function Round:sample(uid, dt, maxSpeed, aabb)
	local s = self:living()[uid]
	if not s then return nil end
	local now = os.clock()
	local pos = s.root.Position
	local last = self.samples[uid]
	if not last then
		self.samples[uid] = { pos = pos, at = now }
		return pos
	end
	local elapsed = math.max(dt or 0, now - (last.at or now), 1 / 60)
	local ok = true
	if maxSpeed then
		local d = TrialRules.flatDistance(pos.X, pos.Z, last.pos.X, last.pos.Z)
		if d > maxSpeed * elapsed * 1.5 + 0.05 then ok = false end
	end
	if ok and aabb and not TrialRules.inBox(aabb, pos.X, pos.Y, pos.Z) then
		ok = false
	end
	if not ok then
		s.root.CFrame = CFrame.new(last.pos) * (s.root.CFrame - s.root.CFrame.Position)
		s.root.AssemblyLinearVelocity = Vector3.zero
		last.at = now
		return last.pos
	end
	last.pos = pos
	last.at = now
	return pos
end

-- R.deadline = os.clock() + seconds (default Pacing.RoundSeconds[trialId]);
-- failsafe = deadline + 20, honoured by tick() even if a trial pushes the
-- deadline out. Also tells the clients once (ev="deadline", server time) so a
-- HUD can count down without per-second packets.
function Round:setDeadline(seconds)
	local secs = seconds or Pacing.RoundSeconds[self.trialId] or 45
	self.deadline = os.clock() + secs
	self.failsafe = self.deadline + FAILSAFE_EXTRA
	TrialKit.send(self.room, self.trialId, "deadline", {
		roundToken = self.roundToken,
		endsAt = workspace:GetServerTimeNow() + secs,
		seconds = secs,
	})
end

-- Heartbeat-style loop: fn(dt) each ~0.05 s while the deadline holds and the
-- round is active; fn returning "stop" ends it. Never used for physics; fn does
-- the server-authoritative logic (sampling, distances, kills).
function Round:tick(fn)
	if not self.deadline then self:setDeadline() end
	local last = os.clock()
	while os.clock() < self.deadline and os.clock() < self.failsafe do
		task.wait(0.05)
		if not self:active() then break end
		local now = os.clock()
		local dt = now - last
		last = now
		if fn and fn(dt) == "stop" then break end
	end
end

-- Everyone not yet done, minus exceptUid: the watch list a spectate packet needs.
function Round:stillRunning(exceptUid)
	local out = {}
	for uid, ps in self.state do
		if uid ~= exceptUid and not ps.done then table.insert(out, uid) end
	end
	return out
end

local function camAndLook(self, opts)
	local camPart = opts and opts.camPart or (self.refs and self.refs.cam)
	local look = opts and opts.look
	if not look then
		if self.refs and self.refs.origin then
			look = self.refs.origin
		elseif camPart then
			look = camPart.Position - Vector3.new(0, 1, 0)
		end
	end
	return camPart, look
end

-- D12, exactly Minefield's sequence: gore at the body, Health 0, room-wide
-- gorefx, personal death card, and 3.2 s later (active-checked) the spectate
-- camera. opts = { text, pos?, power=1.5, camPart?, look? }. No-op if done.
function Round:kill(uid, opts)
	local ps = self.state[uid]
	if not ps or ps.done then return end
	opts = opts or {}
	ps.done = true
	ps.dead = true
	ps.diedAt = os.clock()
	local s = self:living()[uid]
	local pos = opts.pos or (s and s.root.Position) or (self.placed[uid] and self.placed[uid].Position)
	if pos then
		-- #50: room-scoped, never FireAllClients on a 28-player server.
		BloodFX.kill(pos, TrialKit.audienceOf(self.room))
		TrialKit.announce(self.room, { kind = "gorefx", pos = v3(pos), power = opts.power or 1.5 })
	end
	if s then s.hum.Health = 0 end
	TrialKit.deathCard(uid, opts.text or "TERMINATED.")
	local camPart, look = camAndLook(self, opts)
	if camPart then
		task.delay(DEATH_CAM_DELAY, function()
			-- Never strand a lobby player's camera on a torn-down arena.
			if not self:active() then return end
			TrialKit.tellOne(uid, TrialKit.spectatePacket(self:stillRunning(uid), camPart, look, self.roundToken))
		end)
	end
end

-- Non-lethal elimination: no gore, ev="out" {text}, optional spectate camera.
function Round:out(uid, text, opts)
	local ps = self.state[uid]
	if not ps or ps.done then return end
	ps.done = true
	ps.outAt = os.clock()
	TrialKit.sendOne(uid, self.trialId, "out", { text = text or "OUT.", roundToken = self.roundToken })
	local s = self:living()[uid]
	if s then s.hum.WalkSpeed = 0 end
	local camPart, look = camAndLook(self, opts)
	if camPart and (opts == nil or opts.spectate ~= false) then
		TrialKit.tellOne(uid, TrialKit.spectatePacket(self:stillRunning(uid), camPart, look, self.roundToken))
	end
end

-- Complete zero-filled table over room.members; scores[uid] = fn(uid, ps) or 0.
function Round:scores(fn)
	local scores = {}
	for _, mm in self.room.members do
		scores[mm.userId] = 0
	end
	if fn then
		for _, mm in self.room.members do
			local ps = self.state[mm.userId] or {}
			local ok, val = pcall(fn, mm.userId, ps)
			if ok and type(val) == "number" then
				scores[mm.userId] = val
			elseif not ok then
				warn(("[TrialKit:%s] score fn error: %s"):format(self.trialId, tostring(val)))
			end
		end
	end
	return scores
end

-- Round-end beat: input closed, opaque cover before the teleport home (the
-- next round card replaces it). Returns active().
function Round:endRound()
	self.acceptInput = false
	if self:active() then
		self:cover("")
		self:wait(END_COVER_SECONDS)
	end
	return self:active()
end

-- C1.e: the one teardown path. Idempotent; reached from the happy path, from an
-- abort and from the xpcall handler in TrialKit.runRound.
function Round:cleanup()
	if self.cleaned then return end
	self.cleaned = true
	self.acceptInput = false
	-- Unregister first, so every delayed callback's active() check fails now.
	if roundsByRoom[roomKey(self.trialId, self.room)] == self then
		roundsByRoom[roomKey(self.trialId, self.room)] = nil
	end
	for _, mm in self.room.members do
		if roundsByUser[userKey(self.trialId, mm.userId)] == self then
			roundsByUser[userKey(self.trialId, mm.userId)] = nil
		end
	end
	for uid, R in roundsByUser do
		if R == self then roundsByUser[uid] = nil end
	end
	-- LIFO teardown of whatever the trial registered (connections, tweens, threads).
	for i = #self.teardown, 1, -1 do
		local fn = self.teardown[i]
		self.teardown[i] = nil
		local ok, err = pcall(fn)
		if not ok then
			warn(("[TrialKit:%s] cleanup fn error: %s"):format(self.trialId, tostring(err)))
		end
	end
	-- Restore every humanoid the round changed.
	for _, r in self.restore do
		if r.root and r.root.Parent then r.root.Anchored = r.anchored == true end
		if r.hum and r.hum.Parent then
			r.hum.WalkSpeed = r.walk or DEFAULT_WALKSPEED
			r.hum.JumpPower = 0
		end
		if r.char and r.char.Parent then
			r.char:SetAttribute("XBotMoves", "")
			r.char:SetAttribute("XBotCrawl", false)
			r.char:SetAttribute("XBotScanning", false)
		end
	end
	-- Everyone still alive goes home. The cover from endRound hides the trip.
	local spawnPart = workspace:FindFirstChild("SpawnLocation")
	local spawnPos = spawnPart and spawnPart.Position or TrialKit.HOME_FALLBACK
	for _, s in TrialKit.livingOf(self.room) do
		s.root.CFrame = CFrame.new(spawnPos + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
	end
	if self.runtime then
		self.runtime:Destroy()
		self.runtime = nil
	end
	-- REQ-DZ-03: scoped to this round's token and audience, never server-wide.
	BloodFX.clear(self.roundToken, TrialKit.audienceOf(self.room))
	TrialKit.send(self.room, self.trialId, "end", { roundToken = self.roundToken })
end

-- B.6 ROUND WRAPPER (verbatim Minefield.runRound) -----------------------------
-- Every exit path - normal, cancelled, or thrown - runs cleanup exactly once
-- before returning. A thrown round propagates its ORIGINAL traceback after
-- teardown, so MachineFlow aborts the match instead of repeating a broken
-- round with zeroed scores.
function TrialKit.runRound(trialId, room, roundIndex, inner)
	local guard: { cleanup: (() -> ())? } = {}
	local ok, result = xpcall(function()
		return inner(room, roundIndex, guard)
	end, debug.traceback)
	if guard.cleanup then pcall(guard.cleanup) end
	if not ok then
		warn(("[%s] round errored: %s"):format(string.upper(trialId), tostring(result)))
		error(result, 0)
	end
	if type(result) ~= "table" then
		result = {}
		for _, mm in room.members do result[mm.userId] = 0 end
	end
	return result
end

-- Zero-filled score table over room.members: the value a round returns when it
-- cannot start (arena missing, aborted before GO).
function TrialKit.zeroScores(room)
	local scores = {}
	for _, mm in room.members do scores[mm.userId] = 0 end
	return scores
end

return TrialKit
