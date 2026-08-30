--!nonstrict
-- BLUT-FX (Server): schlanke Event-Zentrale. Sichtbares Blut rendert jeder
-- Client selbst (GoreClient) - null Server-Physik, minimale Replikation.
-- Server-seitig bleiben nur: Leichen (alle sehen dieselbe) und Blutquellen
-- an kriechenden Chars (ein Emitter-Part, repliziert automatisch).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BloodFX = {}

local DARK = Color3.fromRGB(50, 4, 4)
local BRIGHT = Color3.fromRGB(80, 0, 0)
local bleeding = {}   -- [char] = { alive, recipients } fuer raumbezogene Blutspuren

-- GORE-BUDGET (30.08.2026, user: "weniger Blut") -- Server-Satellit des
-- GORE-Blocks in StarterPlayerScripts.GoreClient, dieselbe E6-Entscheidung
-- (mild, ~14+), keine Perf-Massnahme. Alles SICHTBARE am Blut wird drueben
-- gestellt; hier steht nur der Takt, weil diese Schleife auf dem Server laeuft.
-- Die Spur bleibt -- sie tropft seltener: ~2.0 s statt ~1.3 s.
local BLEED_MIN = 1.6   -- war 1.0
local BLEED_VAR = 0.8   -- war 0.6

local goreEvent
local function ev(payload, recipients)
	if not goreEvent then
		local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
		goreEvent = folder:FindFirstChild("GoreEvent")
		if not goreEvent then
			goreEvent = Instance.new("RemoteEvent")
			goreEvent.Name = "GoreEvent"
			goreEvent.Parent = folder
		end
	end
	if recipients then
		for _, player in ipairs(recipients) do
			if player and player.Parent == Players then goreEvent:FireClient(player, payload) end
		end
	else
		goreEvent:FireAllClients(payload)
	end
end

-- Remote sofort beim Boot anlegen, damit GoreClient nicht ins Leere wartet
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	if not folder:FindFirstChild("GoreEvent") then
		local e = Instance.new("RemoteEvent")
		e.Name = "GoreEvent"
		e.Parent = folder
	end
end)

-- FX are grouped per SCOPE so one trial's teardown cannot wipe another's.
-- Without the subfolder the only available reset was ClearAllChildren on the
-- shared folder, which is why REQ-DZ-03 exists.
local function fxFolder(scope)
	local f = workspace:FindFirstChild("KenopsiaFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "KenopsiaFX"
		f.Parent = workspace
	end
	if not scope then return f end
	local sub = f:FindFirstChild(scope)
	if not sub then
		sub = Instance.new("Folder")
		sub.Name = scope
		sub.Parent = f
	end
	return sub
end

local function v(pos) return { pos.X, pos.Y, pos.Z } end

function BloodFX.sound(pos, name, recipients) ev({ t = "sound", p = v(pos), name = name }, recipients) end
function BloodFX.burst(pos, intensity, recipients) ev({ t = "burst", p = v(pos), k = intensity or 1 }, recipients) end
function BloodFX.pool(pos, size, recipients) ev({ t = "pool", p = v(pos), s = size }, recipients) end
function BloodFX.gibs(pos, count, long, recipients) ev({ t = "gibs", p = v(pos), n = count or 5, long = long == true }, recipients) end
function BloodFX.fountain(pos, recipients) ev({ t = "fountain", p = v(pos) }, recipients) end
function BloodFX.kill(pos, recipients) ev({ t = "kill", p = v(pos) }, recipients) end
function BloodFX.hit(pos, recipients) ev({ t = "hit", p = v(pos) }, recipients) end

-- ZERSTUECKELUNG: Koerper verschwindet sofort, Clients rendern den Brockenregen
function BloodFX.shatter(char, pos, recipients)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local p = pos or (root and root.Position)
	if not p then return end
	-- 24.08.2026: hide EVERY skinned mesh of the body, not the X-Bot-era
	-- "Beta_Joints" -- the PS1 rig carries Player_Body/Head/Bag MeshParts.
	if char then
		for _, d in char:GetDescendants() do
			if d:IsA("MeshPart") or (d:IsA("BasePart") and d.Name == "Beta_Joints") then
				d.Transparency = 1
			end
		end
	end
	ev({ t = "shatter", p = v(p) }, recipients)
end

-- steife PS1-Leiche: geklonter Skin fliegt vom Explosionspunkt weg
function BloodFX.corpse(char, impulse, scope)
	local mesh = char and char:FindFirstChild("Beta_Joints")
	if not (mesh and mesh:IsA("BasePart")) then return end
	local c = mesh:Clone()
	c.Name = "Corpse"
	for _, d in c:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D") then d:Destroy() end
	end
	c.Anchored = false
	c.CanCollide = true
	c.CanQuery = false
	c.CanTouch = false
	c.CastShadow = false
	c.CFrame = mesh.CFrame
	local att = Instance.new("Attachment")
	att.Parent = c
	local drip = Instance.new("ParticleEmitter")
	drip.Color = ColorSequence.new(DARK)
	drip.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.05) })
	drip.Lifetime = NumberRange.new(0.3, 0.8)
	drip.Speed = NumberRange.new(1, 4)
	drip.SpreadAngle = Vector2.new(180, 180)
	drip.Acceleration = Vector3.new(0, -50, 0)
	drip.Rate = 18
	drip.Parent = att
	c.Parent = fxFolder(scope)
	c.AssemblyLinearVelocity = impulse or Vector3.new(0, 24, 0)
	c.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
	mesh.Transparency = 1
	task.delay(6, function()
		if c.Parent then
			drip.Enabled = false
			TweenService:Create(c, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(c, 7.6)
	return c
end

-- WUNDE, KEINE AMPUTATION (30.08.2026, user): die Mine reisst den Laeufer von
-- den Beinen, sie nimmt sie ihm nicht mehr. Die Funktion setzt weiterhin den
-- einen Wundtreffer und startet die Krabbelspur; der geworfene Unterkoerper
-- ist auf der Client-Seite raus (GoreClient.maim). Signatur und Aufrufer
-- (Minefield) bleiben unveraendert. Alle sichtbaren Spuren entstehen nur bei
-- den Empfaengern des aktiven Raums.
function BloodFX.maim(char, recipients, scope)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local hip = root.Position - Vector3.new(0, 1.2, 0)
	ev({ t = "maim", p = v(hip) }, recipients)
	BloodFX.bleed(char, recipients, scope)
end

function BloodFX.bleed(char, recipients, scope)
	if not char or bleeding[char] then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local entry = { alive = true, recipients = recipients, scope = scope }
	bleeding[char] = entry
	task.spawn(function()
		while entry.alive and char.Parent do
			task.wait(BLEED_MIN + math.random() * BLEED_VAR)
			local r = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not (r and hum and hum.Health > 0 and char:GetAttribute("XBotCrawl")) then break end
			ev({ t = "splat", p = v(r.Position) }, entry.recipients)
		end
		-- 30.08.2026 (Review): NUR DEN EIGENEN EINTRAG abraeumen. Dieser Thread
		-- schlaeft jetzt bis zu 2.4 s (vorher 1.6 s) zwischen zwei Tropfen. Wird
		-- er in dieser Zeit von aussen gestoppt (BloodFX.clear beim Rundenende)
		-- und derselbe Char faengt sofort neu an zu bluten, wachte der alte
		-- Thread danach auf und raeumte mit stopBleed(char) den FRISCHEN Eintrag
		-- weg -- die neue Spur waere still gestorben. Das Fenster gab es vorher
		-- schon, der laengere Takt macht es nur groesser.
		if bleeding[char] == entry then BloodFX.stopBleed(char) end
	end)
end

function BloodFX.stopBleed(char)
	local e = bleeding[char]
	if not e then return end
	e.alive = false
	bleeding[char] = nil
end

-- Nur die lokalen Effekte eines Raums loeschen; Server-FX anderer
-- gleichzeitig laufender Trials bleiben unangetastet.
function BloodFX.clearClients(recipients)
	if recipients then ev({ t = "clear" }, recipients) end
end

-- REQ-DZ-03. Scoped by default: clears only this scope's folder, stops only
-- the bleeds started under it, and tells only this round's audience.
--
-- Called with NO scope it still performs the old server-wide reset, which is
-- correct for a genuine shutdown but wrong for a trial ending -- with two
-- rooms running, the global path wiped the other room's effects and sent a
-- clear to players who were mid-round somewhere else.
function BloodFX.clear(scope, recipients)
	for char, entry in pairs(bleeding) do
		if not scope or entry.scope == scope then
			BloodFX.stopBleed(char)
		end
	end
	local f = workspace:FindFirstChild("KenopsiaFX")
	if f then
		local target = scope and f:FindFirstChild(scope) or f
		if target then target:ClearAllChildren() end
		if scope and target then target:Destroy() end
	end
	ev({ t = "clear" }, recipients)
end

return BloodFX
