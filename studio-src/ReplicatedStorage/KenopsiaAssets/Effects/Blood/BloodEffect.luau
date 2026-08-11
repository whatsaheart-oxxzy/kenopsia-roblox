local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local config = script.Parent
local random = Random.new()

local BloodEffect = {}
local activeDroplets = 0

local COLORS = {
	Color3.fromRGB(78, 0, 4),
	Color3.fromRGB(118, 4, 8),
	Color3.fromRGB(156, 8, 12),
}

local function readValue(name: string, fallback: any): any
	local valueObject = config:FindFirstChild(name)
	if valueObject and valueObject:IsA("ValueBase") then
		return valueObject.Value
	end
	return fallback
end

local function safeNormal(normal: Vector3?): Vector3
	if typeof(normal) == "Vector3" and normal.Magnitude > 0.001 then
		return normal.Unit
	end
	return Vector3.yAxis
end

local function tag(instance: Instance)
	CollectionService:AddTag(instance, "KenopsiaBloodEffect")
	instance:SetAttribute("EffectOnly", true)
end

local function addTrail(part: BasePart, lifetime: number)
	local front = Instance.new("Attachment")
	front.Position = Vector3.new(0, 0, -part.Size.Z * 0.45)
	front.Parent = part

	local back = Instance.new("Attachment")
	back.Position = Vector3.new(0, 0, part.Size.Z * 0.45)
	back.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = front
	trail.Attachment1 = back
	trail.Color = ColorSequence.new(COLORS[2], COLORS[1])
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Lifetime = math.min(0.18, lifetime * 0.2)
	trail.FaceCamera = true
	trail.LightEmission = 0.05
	trail.Parent = part
end

local function emitMist(origin: Vector3, normal: Vector3, intensity: number, parent: Instance)
	local anchor = Instance.new("Part")
	anchor.Name = "BloodMist"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.05
	anchor.CFrame = CFrame.lookAt(origin, origin + normal)
	anchor.Parent = parent
	tag(anchor)

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local mist = Instance.new("ParticleEmitter")
	mist.Name = "CrimsonMist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Rate = 0
	mist.Color = ColorSequence.new(COLORS[3], COLORS[1])
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.35, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	mist.Lifetime = NumberRange.new(0.22, 0.48)
	mist.Speed = NumberRange.new(4, 10)
	mist.Drag = 4
	mist.Acceleration = Vector3.new(0, -9, 0)
	mist.SpreadAngle = Vector2.new(65, 65)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-120, 120)
	mist.LightEmission = 0.05
	mist.LightInfluence = 0.8
	mist.Orientation = Enum.ParticleOrientation.FacingCamera
	mist.Parent = attachment
	mist:Emit(math.clamp(math.floor(5 * intensity + 0.5), 2, 16))

	Debris:AddItem(anchor, 1.25)
end

local function createStain(origin: Vector3, normal: Vector3, intensity: number, parent: Instance)
	if not readValue("LeaveStains", true) or readValue("ReduceGore", false) then
		return
	end

	local width = random:NextNumber(0.55, 1.05) * math.clamp(intensity, 0.5, 2)
	local stain = Instance.new("Part")
	stain.Name = "BloodStain"
	stain.Anchored = true
	stain.CanCollide = false
	stain.CanQuery = false
	stain.CanTouch = false
	stain.CastShadow = false
	stain.Color = COLORS[1]
	stain.Material = Enum.Material.Concrete
	stain.MaterialVariant = readValue("StainedMaterialVariant", "BLOOD_PSX_Stained_Surface")
	stain.Size = Vector3.new(width, 0.018, width * random:NextNumber(0.65, 1))
	stain.CFrame = CFrame.lookAt(origin + normal * 0.015, origin + normal) * CFrame.Angles(math.rad(90), 0, 0)
	stain.Transparency = 0.12
	stain.Parent = parent
	tag(stain)
	Debris:AddItem(stain, 12)
end

function BloodEffect.Emit(origin: Vector3, normal: Vector3?, severity: number?, parent: Instance?): (boolean, number)
	if not readValue("Enabled", true) or typeof(origin) ~= "Vector3" then
		return false, 0
	end

	local effectParent = parent or workspace
	local direction = safeNormal(normal)
	local intensity = math.clamp((severity or 1) * readValue("Intensity", 1), 0.2, 3)
	local reduced = readValue("ReduceGore", false)
	if reduced then
		intensity *= 0.35
	end

	local available = math.max(0, readValue("MaxActive", 48) - activeDroplets)
	local dropletCount = math.min(available, math.clamp(math.floor(13 * intensity + 0.5), 2, 36))
	if dropletCount <= 0 then
		return false, 0
	end

	emitMist(origin, direction, intensity, effectParent)
	createStain(origin, direction, intensity, effectParent)
	activeDroplets += dropletCount

	for index = 1, dropletCount do
		local size = random:NextNumber(0.045, 0.13) * math.clamp(intensity, 0.6, 1.6)
		local droplet = Instance.new("Part")
		droplet.Name = "BloodDroplet"
		droplet.Shape = Enum.PartType.Ball
		droplet.Size = Vector3.one * size
		droplet.Color = COLORS[random:NextInteger(1, #COLORS)]
		droplet.Material = Enum.Material.SmoothPlastic
		droplet.CanCollide = false
		droplet.CanQuery = false
		droplet.CanTouch = false
		droplet.CastShadow = false
		droplet.Massless = true
		droplet.CFrame = CFrame.new(origin + direction * 0.06)
		droplet.Parent = effectParent
		tag(droplet)

		local scatter = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(-0.35, 1),
			random:NextNumber(-1, 1)
		)
		local launch = (direction * random:NextNumber(0.5, 1.2) + scatter * 0.8).Unit
		droplet.AssemblyLinearVelocity = launch * random:NextNumber(12, 25) + Vector3.yAxis * random:NextNumber(2, 7)
		droplet.AssemblyAngularVelocity = Vector3.new(
			random:NextNumber(-16, 16),
			random:NextNumber(-16, 16),
			random:NextNumber(-16, 16)
		)

		local lifetime = random:NextNumber(0.65, 1.35)
		if index <= math.min(6, dropletCount) then
			addTrail(droplet, lifetime)
		end
		Debris:AddItem(droplet, lifetime)
		task.delay(lifetime, function()
			activeDroplets = math.max(0, activeDroplets - 1)
		end)
	end

	return true, dropletCount
end

function BloodEffect.Clear(parent: Instance?)
	local scope = parent or workspace
	for _, instance in CollectionService:GetTagged("KenopsiaBloodEffect") do
		if instance:IsDescendantOf(scope) then
			instance:Destroy()
		end
	end
	activeDroplets = 0
end

function BloodEffect.SetEnabled(enabled: boolean)
	local setting = config:FindFirstChild("Enabled")
	if setting and setting:IsA("BoolValue") then
		setting.Value = enabled
	end
end

function BloodEffect.GetActiveCount(): number
	return activeDroplets
end

return table.freeze(BloodEffect)