--!nonstrict

local RunService = game:GetService("RunService")

local SequencePlayer = {}

local parsed = {}
local function parse(ks)
	local clip = parsed[ks]
	if clip then return clip end
	local kfs = ks:GetKeyframes()
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local keys = table.create(#kfs)
	for i, kf in ipairs(kfs) do
		local poses = {}
		for _, p in ipairs(kf:GetDescendants()) do
			if p:IsA("Pose") then poses[p.Name] = p.CFrame end
		end
		keys[i] = { t = kf.Time, poses = poses }
	end
	local dur = 0.001
	if #kfs > 0 then dur = math.max(kfs[#kfs].Time, 0.001) end
	clip = { keys = keys, duration = dur, loop = ks.Loop, name = ks.Name }
	parsed[ks] = clip
	return clip
end

local rigs = {}

local Rig = {}
Rig.__index = Rig

function SequencePlayer.attach(model, clipFolder)
	if rigs[model] then return rigs[model] end
	local mesh = model:FindFirstChild("Beta_Joints")
	if not mesh then return nil end
	local bones = {}
	for _, d in ipairs(mesh:GetDescendants()) do
		if d:IsA("Bone") then bones[d.Name] = d end
	end
	local clips = {}
	for _, ks in ipairs(clipFolder:GetChildren()) do
		if ks:IsA("KeyframeSequence") then clips[ks.Name] = parse(ks) end
	end
	-- Beinknochen fuer den Kastrierer-Kollaps (XBotCrawl = Unterkoerper weg)
	local legBones = {}
	for name, b in pairs(bones) do
		if name:find("Leg") or name:find("Foot") or name:find("Toe") then
			table.insert(legBones, b)
		end
	end
	-- clip translations are authored at the raw import size; an Animator would
	-- scale them by the model's scale factor, so this player must too
	local scale = 1
	pcall(function() scale = model:GetScale() end)
	local rig = setmetatable({
		model = model, bones = bones, clips = clips,
		legBones = legBones,
		scaleAdd = scale - 1,
		layers = {}, locoLayer = nil, actionLayer = nil,
		scratch = {},
	}, Rig)
	rigs[model] = rig
	return rig
end

function Rig:destroy()
	rigs[self.model] = nil
	for _, b in pairs(self.bones) do b.Transform = CFrame.identity end
end

local function newLayer(clip, speed, fadeIn)
	return {
		clip = clip, t = 0, speed = speed or 1,
		weight = 0, target = 1, fade = math.max(fadeIn or 0.2, 0.01),
		loop = clip.loop, once = false, hold = false, fadeOut = 0.25,
		onDone = nil, idx = 1, doneFired = false,
	}
end

-- restart=true forces a fresh layer even for the same clip, crossfading back
-- to its first frame (used to freeze crouch-idle on a stable pose)
function Rig:setLoco(name, speed, fade, restart)
	local clip = name and self.clips[name]
	local cur = self.locoLayer
	if cur and clip and cur.clip == clip and not restart then
		cur.speed = speed or cur.speed
		return
	end
	if cur and clip and cur.clip == clip and restart and cur.t < 0.01 and (cur.speed or 1) < 0.01 then
		return -- already frozen at the start
	end
	if cur then
		cur.target = 0
		cur.fade = math.max(fade or 0.2, 0.01)
	end
	if clip then
		local layer = newLayer(clip, speed, fade)
		self.locoLayer = layer
		table.insert(self.layers, layer)
	else
		self.locoLayer = nil
	end
end

-- one-shot overlay; hold=true freezes on the final pose until releaseAction
function Rig:playAction(name, opts)
	opts = opts or {}
	local clip = self.clips[name]
	if not clip then return 0 end
	local prev = self.actionLayer
	if prev then
		prev.target = 0
		prev.fade = 0.1
	end
	local layer = newLayer(clip, opts.speed, opts.fade or 0.15)
	layer.loop = false
	layer.hold = opts.hold == true
	layer.once = not layer.hold
	layer.fadeOut = opts.fadeOut or 0.25
	layer.onDone = opts.onDone
	self.actionLayer = layer
	table.insert(self.layers, layer)
	return clip.duration
end

function Rig:releaseAction(fade)
	local a = self.actionLayer
	if a then
		a.target = 0
		a.fade = math.max(fade or 0.25, 0.01)
		self.actionLayer = nil
	end
end

local function sample(layer, out, bones, scaleAdd)
	local keys = layer.clip.keys
	local n = #keys
	if n == 0 then return end
	local t = layer.t
	local i = layer.idx
	if i > n then i = n end
	while i > 1 and keys[i].t > t do i -= 1 end
	while i < n and keys[i + 1].t <= t do i += 1 end
	layer.idx = i
	local a = keys[i]
	local b = keys[math.min(i + 1, n)]
	local alpha = 0
	if b.t > a.t then alpha = math.clamp((t - a.t) / (b.t - a.t), 0, 1) end
	local w = layer.weight
	for name, cfA in pairs(a.poses) do
		if bones[name] then
			local cfB = b.poses[name] or cfA
			local pose = if alpha > 0 then cfA:Lerp(cfB, alpha) else cfA
			if scaleAdd ~= 0 then
				-- shift translation to authored-size * model scale
				pose += pose.Position * scaleAdd
			end
			local acc = out[name]
			if acc then
				out[name] = acc:Lerp(pose, w)
			elseif w >= 0.999 then
				out[name] = pose
			else
				out[name] = CFrame.identity:Lerp(pose, w)
			end
		end
	end
end

local IDENTITY = CFrame.identity
local function step(dt)
	for model, rig in pairs(rigs) do
		if not model.Parent then
			rig:destroy()
			continue
		end
		local layers = rig.layers
		if #layers == 0 then continue end
		local out = rig.scratch
		table.clear(out)
		local keep = 1
		for idx = 1, #layers do
			local L = layers[idx]
			local dw = dt / L.fade
			if L.weight < L.target then
				L.weight = math.min(L.weight + dw, L.target)
			elseif L.weight > L.target then
				L.weight = math.max(L.weight - dw, L.target)
			end
			L.t += dt * L.speed
			local d = L.clip.duration
			if L.loop then
				if L.t >= d then
					L.t %= d
					L.idx = 1
				end
			elseif L.t >= d then
				L.t = d
				if L.once and not L.doneFired then
					L.doneFired = true
					L.target = 0
					L.fade = L.fadeOut
					if rig.actionLayer == L then rig.actionLayer = nil end
					if L.onDone then task.spawn(L.onDone) end
				end
			end
			if L.weight > 0.001 or L.target > 0 then
				sample(L, out, rig.bones, rig.scaleAdd)
				layers[keep] = L
				keep += 1
			else
				if rig.locoLayer == L then rig.locoLayer = nil end
				if rig.actionLayer == L then rig.actionLayer = nil end
			end
		end
		for i = #layers, keep, -1 do layers[i] = nil end
		for name, bone in pairs(rig.bones) do
			bone.Transform = out[name] or IDENTITY
		end
		-- KASTRIERER: bei XBotCrawl kollabieren alle Beinknochen in die Huefte -
		-- der Unterkoerper verschwindet im Stumpf, der Rest kriecht auf Armen
		if model:GetAttribute("XBotCrawl") then
			for _, b in ipairs(rig.legBones) do
				b.Transform = b.CFrame:Inverse()
			end
		end
	end
end

if RunService:IsClient() then
	RunService.RenderStepped:Connect(step)
else
	RunService.Heartbeat:Connect(step)
end

return SequencePlayer
