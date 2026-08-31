--!nonstrict
-- Shared, round-scoped Headbutt authority for Bird Hunting and Dead Zone.
-- Clients send intent only. This controller never accepts a client target,
-- position, impulse, animation id or cooldown.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config")
local AnimationIds = require(Config:WaitForChild("AnimationIds"))
local Tune = require(Config:WaitForChild("FeelConfig")).FieldPush

local FieldPush = {}
FieldPush.__index = FieldPush

local function clock()
	return workspace:GetServerTimeNow()
end

local function stop(track)
	if track then track:Stop(0.08) end
end

local function finiteVector(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < math.huge and math.abs(v.Y) < math.huge and math.abs(v.Z) < math.huge
end

-- The horizontal part of a vector, or nil when it is not finite or has no
-- direction left once Y is dropped. The fall heading is picked from two of
-- these, so a degenerate one has to be distinguishable from a real one.
local function flatOf(v)
	if not v or not finiteVector(v) then return nil end
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 0.01 then return nil end
	return flat
end

function FieldPush.new(options)
	local self = setmetatable({ options = options, entries = {}, enabled = false, destroyed = false }, FieldPush)
	-- Main requires the trial modules before RoomService.start creates remotes.
	-- Resolve the receipt channel only once an actual round is being prepared.
	local remotes = ReplicatedStorage.Kenopsia:FindFirstChild("Remotes")
	self.machineState = remotes and remotes:FindFirstChild("MachineState")
	for uid, subject in options.subjects do
		local st = options.state[uid]
		if st and not st.sniper then
			local animator = subject.hum:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = subject.hum
			end
			local entry = { subject = subject, readyAt = 0, serial = 0, immuneUntil = 0 }
			self.entries[uid] = entry
			-- Load once, during preparation. All later request handlers are non-yielding.
			entry.attack = AnimationIds.load(animator, "Player", "Push")
			entry.fall = AnimationIds.load(animator, "Player", "FallFlat")
			if entry.attack then
				entry.attack.Priority = Enum.AnimationPriority.Action2
				entry.attack.Looped = false
			end
			if entry.fall then
				entry.fall.Priority = Enum.AnimationPriority.Action3
				entry.fall.Looped = false
			end
			subject.char:SetAttribute("FieldPushTrial", options.trialId)
			subject.char:SetAttribute("FieldPushRoundToken", options.roundToken)
			subject.char:SetAttribute("FieldPushReadyAt", 0)
			subject.char:SetAttribute("FieldPushStunnedUntil", 0)
			subject.char:SetAttribute("FieldPushActionUntil", 0)
			subject.char:SetAttribute("FieldPushFallen", false)
			subject.char:SetAttribute("FieldPushEnabled", false)
			entry.died = subject.hum.Died:Connect(function() self:Remove(uid) end)
		end
	end
	local elapsed = 0
	self.heartbeat = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.05 then return end
		elapsed = 0
		self:_step()
	end)
	return self
end

function FieldPush:_owns(entry)
	return entry.subject.char:GetAttribute("FieldPushRoundToken") == self.options.roundToken
end

function FieldPush:_subject(uid)
	if self.destroyed or not self.enabled or not self.options.isActive() then return nil end
	local o = self.options
	if o.room.sessionId ~= o.sessionId then return nil end
	local member = false
	for _, m in o.room.members do
		if m.userId == uid then member = true break end
	end
	if not member then return nil end
	local st, entry = o.state[uid], self.entries[uid]
	if not st or st.done or st.sniper or not entry then return nil end
	local s = entry.subject
	local player = Players:GetPlayerByUserId(uid)
	if not player or player.Character ~= s.char or not s.char.Parent then return nil end
	if not s.hum.Parent or s.hum.Health <= 0 or not s.root.Parent or s.root.Anchored then return nil end
	if s.hum.Sit or s.hum.PlatformStand or s.char:GetAttribute("XBotCrawl") == true then return nil end
	if not self:_owns(entry) then return nil end
	return s, entry
end

function FieldPush:_receipt(uid, phase, entry, targetUserId)
	local player = Players:GetPlayerByUserId(uid)
	if self.machineState and player then
		self.machineState:FireClient(player, {
			kind = "fieldPush", phase = phase, trialId = self.options.trialId,
			roundToken = self.options.roundToken, cooldownEndsAt = entry.readyAt,
			targetUserId = targetUserId,
		})
	end
end

-- The same range, height and solid-world LOS check is used for runners and
-- Bird Hunting's existing loose-cover fallback. 31.08.2026 (user): it is no
-- longer front-facing -- see the cone note below.
function FieldPush:InReach(subject, position, target)
	if not finiteVector(position) or not finiteVector(subject.root.Position) then return false end
	local delta = position - subject.root.Position
	if math.abs(delta.Y) > Tune.MaxHeightDifference then return false end
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude > Tune.Range then return false end
	-- ANY DIRECTION (31.08.2026, user): "The player can headbutt another player
	-- IN ANY direction". The cone is not deleted, it is switched off by its own
	-- number: Tune.HalfAngleDegrees >= 180 means "no cone" and is tested as
	-- such rather than left to cos(rad(180)) == -1, because the dot product of
	-- two unit vectors can land a hair under -1 in floating point and would
	-- then reject the one target standing exactly behind you. Range, height and
	-- the solid-world LOS ray are direction-agnostic and still apply, so the
	-- reach becomes a Tune.Range disc instead of a 130 degree wedge.
	if Tune.HalfAngleDegrees < 180 then
		local look = subject.root.CFrame.LookVector
		if not finiteVector(look) then return false end
		local forward = Vector3.new(look.X, 0, look.Z)
		if forward.Magnitude < 0.01 then return false end
		if flat.Magnitude > 0.05 and forward.Unit:Dot(flat.Unit) < math.cos(math.rad(Tune.HalfAngleDegrees)) then
			return false
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { subject.char }
	params.RespectCanCollide = true
	local origin = subject.root.Position + Vector3.new(0, 0.6, 0)
	local hit = workspace:Raycast(origin, position + Vector3.new(0, 0.6, 0) - origin, params)
	return hit == nil or hit.Instance == target or (target and hit.Instance:IsDescendantOf(target))
end

function FieldPush:_restore(entry, restoreMovement)
	local s = entry.subject
	local owns = self:_owns(entry)
	stop(entry.fall)
	if owns and entry.autoRotate ~= nil and s.hum.Parent then
		if s.hum.AutoRotate == false then s.hum.AutoRotate = entry.autoRotate end
		entry.autoRotate = nil
	end
	if owns and entry.serverOwned and s.root.Parent and not s.root.Anchored then
		pcall(function()
			if s.root:GetNetworkOwner() == nil then
				if entry.ownershipAuto then
					s.root:SetNetworkOwnershipAuto()
				else
					s.root:SetNetworkOwner(entry.networkOwner)
				end
			end
		end)
	end
	entry.serverOwned = nil
	if owns then
		s.char:SetAttribute("FieldPushStunnedUntil", 0)
		s.char:SetAttribute("FieldPushFallen", false)
	end
	if owns and restoreMovement and s.hum.Parent and s.hum.Health > 0 and s.hum.WalkSpeed == 0 then
		local speed = self.options.recoverSpeed(s, entry.walkBefore)
		if type(speed) == "number" then s.hum.WalkSpeed = speed end
	end
	entry.stunUntil = nil
	entry.walkBefore = nil
	entry.autoRotate = nil
	entry.networkOwner = nil
	entry.ownershipAuto = nil
end

-- Used before a trial takes ownership of death, escape or mine-maiming.
-- Its caller decides whether the current movement should be restored first.
function FieldPush:Interrupt(uid, restoreMovement)
	local entry = self.entries[uid]
	if not entry then return end
	entry.serial += 1
	entry.actionUntil = nil
	stop(entry.attack)
	if self:_owns(entry) then entry.subject.char:SetAttribute("FieldPushActionUntil", 0) end
	if entry.stunUntil then self:_restore(entry, restoreMovement == true) end
end

function FieldPush:Remove(uid, restoreMovement)
	local entry = self.entries[uid]
	if not entry then return end
	self:Interrupt(uid, restoreMovement == true)
	if self:_owns(entry) then
		local char = entry.subject.char
		char:SetAttribute("FieldPushEnabled", false)
		char:SetAttribute("FieldPushRoundToken", nil)
		char:SetAttribute("FieldPushTrial", nil)
		char:SetAttribute("FieldPushReadyAt", 0)
	end
	if entry.died then entry.died:Disconnect() end
	if entry.attack then entry.attack:Destroy() end
	if entry.fall then entry.fall:Destroy() end
	self.entries[uid] = nil
end

function FieldPush:SetEnabled(enabled)
	self.enabled = enabled == true
	for uid, entry in self.entries do
		if self:_owns(entry) then
			entry.subject.char:SetAttribute("FieldPushEnabled", self:_subject(uid) ~= nil)
		end
	end
end

function FieldPush:_knockdown(attacker, uid, target, entry, now)
	self:Interrupt(uid, false)
	entry.stunUntil = now + Tune.FallSeconds
	entry.immuneUntil = entry.stunUntil + Tune.RecoveryImmunity
	entry.walkBefore = target.hum.WalkSpeed
	entry.autoRotate = target.hum.AutoRotate
	-- THE VICTIM FALLS THE WAY THEY WERE GOING (31.08.2026, user): "The Player
	-- who got headbutted, falls in the direction where they look/move." Not away
	-- from the attacker and not along the attacker's heading. Movement wins over
	-- facing, because a runner at speed is already committed to it; a runner
	-- standing still has only their facing to commit to. Both are read HERE, on
	-- the server, off the victim's own root and BEFORE WalkSpeed is zeroed, so
	-- the shove keeps the heading the victim had at the instant of impact. No
	-- client supplies, or is asked for, a direction.
	--   1) flat speed >= Tune.FallHeadingSpeed -> trip forward over that momentum
	--   2) else the victim's own flat LookVector -> go down the way they face
	--   3) else away from the attacker: the pre-31.08. rule, kept ONLY as the
	--      last resort for a root that is tumbling or looking straight up
	--   4) if even that is degenerate (the two roots on top of each other) ->
	--      no horizontal shove at all; the knockdown still lands, straight down.
	local direction
	local moving = flatOf(target.root.AssemblyLinearVelocity)
	if moving and moving.Magnitude >= Tune.FallHeadingSpeed then
		direction = moving.Unit
	else
		local facing = flatOf(target.root.CFrame.LookVector)
		if facing then
			direction = facing.Unit
		else
			local away = flatOf(target.root.Position - attacker.root.Position)
			if away then direction = away.Unit end
		end
	end
	-- The rig stays motor-driven: no PlatformStand/ragdoll competes with FallFlat.
	target.hum.AutoRotate = false
	target.hum.WalkSpeed = 0
	target.hum.Jump = false
	target.char:SetAttribute("FieldPushStunnedUntil", entry.stunUntil)
	target.char:SetAttribute("FieldPushFallen", true)
	if entry.fall then
		entry.fall:Play(0.04, 1, Tune.FallFlatDuration / Tune.FallSeconds)
	end
	-- EXACTLY Tune.FallSeconds ON THE GROUND (31.08.2026, user). The 20 Hz _step
	-- poll can only notice the deadline up to 0.05 s late, so the stand-up is
	-- scheduled on the same clock that set the deadline. _step stays the safety
	-- net: this delay deliberately does nothing unless the victim is still a
	-- live, owned subject, and every other exit (death, leaving, a character
	-- swap, Interrupt, Remove, Destroy) already restores through _restore.
	-- stunSerial makes a superseded fall's pending delay a no-op.
	local stunSerial = (entry.stunSerial or 0) + 1
	entry.stunSerial = stunSerial
	task.delay(Tune.FallSeconds, function()
		if self.destroyed or self.entries[uid] ~= entry then return end
		if entry.stunSerial ~= stunSerial or not entry.stunUntil then return end
		if self:_subject(uid) then self:_restore(entry, true) end
	end)
	-- Bound the resulting velocity, not an additive force that stacks on spam.
	-- Ownership returns to automatic on recovery/death/teardown.
	pcall(function()
		entry.ownershipAuto = target.root:GetNetworkOwnershipAuto()
		entry.networkOwner = target.root:GetNetworkOwner()
		target.root:SetNetworkOwner(nil)
		entry.serverOwned = true
		local desired = Vector3.new(0, Tune.FlingUp, 0)
		if direction then desired += direction * Tune.FlingSpeed end
		target.root:ApplyImpulse((desired - target.root.AssemblyLinearVelocity) * target.root.AssemblyMass)
	end)
end

function FieldPush:TryPush(player)
	local uid = player.UserId
	local entry = self.entries[uid]
	local now = clock()
	-- Cheap server floor before any world query. Rejected requests do not
	-- broadcast or extend the window, and holding a key never schedules repeats.
	if not entry or now < entry.readyAt then return false end
	local subject = self:_subject(uid)
	if not subject or (entry.stunUntil and now < entry.stunUntil) then return false end
	entry.readyAt = now + Tune.Cooldown
	entry.serial += 1
	local serial = entry.serial
	entry.actionUntil = now + Tune.AttackSeconds
	subject.char:SetAttribute("FieldPushReadyAt", entry.readyAt)
	subject.char:SetAttribute("FieldPushActionUntil", entry.actionUntil)
	if entry.attack then
		entry.attack:Play(0.04, 1, Tune.HeadbuttDuration / Tune.AttackSeconds)
	end
	self:_receipt(uid, "attack", entry)
	task.delay(Tune.Windup, function()
		if self.destroyed or self.entries[uid] ~= entry or entry.serial ~= serial then return end
		local attacker = self:_subject(uid)
		local hitTime = clock()
		if not attacker or (entry.stunUntil and hitTime < entry.stunUntil) then return end
		local nearest, nearestEntry, nearestId, distance
		for targetId, targetEntry in self.entries do
			if targetId ~= uid and hitTime >= targetEntry.immuneUntil then
				local target = self:_subject(targetId)
				if target and self:InReach(attacker, target.root.Position, target.char) then
					local d = (target.root.Position - attacker.root.Position).Magnitude
					if not distance or d < distance then
						nearest, nearestEntry, nearestId, distance = target, targetEntry, targetId, d
					end
				end
			end
		end
		if nearest then
			self:_knockdown(attacker, nearestId, nearest, nearestEntry, hitTime)
			self:_receipt(uid, "hit", entry, nearestId)
		elseif self.options.pushProp and self.options.pushProp(player, attacker, self) then
			self:_receipt(uid, "hit", entry)
		else
			self:_receipt(uid, "miss", entry)
		end
	end)
	return true
end

function FieldPush:_step()
	if self.destroyed then return end
	local now = clock()
	for uid, entry in self.entries do
		local subject = self:_subject(uid)
		if self.enabled and not subject then
			local s, st = entry.subject, self.options.state[uid]
			local player = Players:GetPlayerByUserId(uid)
			self:Remove(uid, st and not st.done and player and player.Character == s.char
				and s.char:GetAttribute("XBotCrawl") ~= true)
		else
			if entry.actionUntil and now >= entry.actionUntil then
				stop(entry.attack)
				entry.actionUntil = nil
				if self:_owns(entry) then entry.subject.char:SetAttribute("FieldPushActionUntil", 0) end
			end
			if entry.stunUntil then
				if now >= entry.stunUntil then
					self:_restore(entry, subject ~= nil)
				elseif subject then
					subject.hum.WalkSpeed = 0
					subject.hum.Jump = false
				end
			end
		end
	end
end

function FieldPush:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.enabled = false
	if self.heartbeat then self.heartbeat:Disconnect() end
	for uid, entry in self.entries do
		local st = self.options.state[uid]
		local player = Players:GetPlayerByUserId(uid)
		self:Remove(uid, st and not st.done and player and player.Character == entry.subject.char
			and entry.subject.char:GetAttribute("XBotCrawl") ~= true)
	end
end

return FieldPush
