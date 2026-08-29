--!nonstrict
-- DEAD ZONE SONAR SENDER (Phase 3b, 30.08.2026) -- ein eigener LocalScript,
-- MIT ABSICHT nicht im KenopsiaClient: dessen Haupt-Chunk steht bei ~185/200
-- Luau-Locals, und jede neue Bindung dort riskiert, dass das ganze Script
-- nicht mehr kompiliert. Dieses Script teilt sich mit ihm NICHTS ausser den
-- Remotes.
--
-- Es SENDET nur. Der Server besitzt die Oekonomie (Feel.Minefield.SonarPulses),
-- den Cooldown (0.8 s), das Stillstand-Tor der letzten Runde und jedes
-- Aufdeck-Teil; die Antwort braucht hier keinen Handler, weil die Aufdeckung
-- seit Phase 3b aus SERVER-Teilen besteht, die jeder sieht. Ein doppelter oder
-- verfruehter Druck wird serverseitig still verworfen -- ein naiver Sender ist
-- sicher (Recon-Verdikt 29.08.).
--
-- Eingaben: E (Tastatur), ButtonX (Gamepad -- KenopsiaClient haelt Y, beide
-- koexistieren), und ein eigener >= 64 px Touch-Button in einem EIGENEN
-- ScreenGui (nie im TouchControls-Frame der Machine herumschrauben).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
local TrialInput = remotes:WaitForChild("TrialInput", 20)
local MachineState = remotes:WaitForChild("MachineState", 20)

-- Token-Cache: das DZ-Rollenpaket ({kind="role", role="runner", roundToken=..})
-- traegt den Rundentoken; role="none"/"spectate" laesst ihn fallen. Faengt
-- diese Verbindung den Token eines ANDEREN Trials (der MP-05-Router verteilt
-- dieselbe Paketform), ist das egal: der Server prueft trialId UND Token, ein
-- fremder Puls faellt durch. Mehrere OnClientEvent-Verbindungen neben dem
-- Dispatcher des KenopsiaClient sind ausdruecklich in Ordnung (Recon-Verdikt).
local roundToken = nil
local pulseReadyAt = 0

-- Das Tor des KenopsiaClient selbst (charScanAllowed): der DZ-Server stempelt
-- XBotMoves="scan" auf jeden Laeufer. Das Design nennt zusaetzlich ein
-- Spieler-Attribut KenopsiaActiveTrial=="minefield" -- das stempelt im Live-
-- Place heute NIEMAND (Recon 29.08.), deshalb zaehlt es hier nur, WENN es
-- existiert, und XBotMoves bleibt das eigentliche Tor.
local function scanAllowed()
	local trial = player:GetAttribute("KenopsiaActiveTrial")
	if trial ~= nil and trial ~= "minefield" then return false end
	local char = player.Character
	if not char then return false end
	local moves = char:GetAttribute("XBotMoves")
	return type(moves) == "string" and string.find(moves, "scan", 1, true) ~= nil
end

local function firePulse()
	if not TrialInput then return end
	if not roundToken then return end
	if not scanAllowed() then return end
	local now = os.clock()
	if now < pulseReadyAt then return end
	-- 0.9 spiegelt den 0.8-s-Boden des Servers, wie der KenopsiaClient-Pfad.
	pulseReadyAt = now + 0.9
	TrialInput:FireServer({
		trialId = "minefield",
		action = "pulse",
		roundToken = roundToken,
	})
	-- Nur der Klick als lokale Quittung; Ring und Glow kommen als Server-
	-- Teile fuer alle zurueck (PlayOnRemove-Muster: parenten, zerstoeren,
	-- der Klang spielt).
	local ka = SoundService:FindFirstChild("KenopsiaAudio")
	local click = ka and ka:FindFirstChild("SFX") and ka.SFX:FindFirstChild("Click")
	if click then
		local s = click:Clone()
		s.Parent = SoundService
		s.PlayOnRemove = true
		s:Destroy()
	end
end

if MachineState then
	MachineState.OnClientEvent:Connect(function(p)
		if type(p) ~= "table" then return end
		if p.kind ~= "role" then return end
		if p.role == "runner" and p.roundToken ~= nil then
			roundToken = p.roundToken
		elseif p.role == "none" or p.role == "spectate" then
			roundToken = nil
		end
	end)
end

-- Tastatur / Gamepad: EIN Druck = EIN Puls, nie auto-repeat -- die Oekonomie
-- (drei Pulse) verlangt bewusstes Ausgeben. gameProcessed schluckt Chat/UI.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		firePulse()
	end
end)

-- Touch: eigener ScreenGui, ein 72x72-px-Button (>= 64 px Mindestziel),
-- rechts ueber der TouchControls-Zeile der Machine. Sichtbar nur auf Touch-
-- Geraeten, waehrend ein DZ-Lauf den Scan erlaubt.
local gui = Instance.new("ScreenGui")
gui.Name = "DZSonarGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Name = "Btn_PULSE"
btn.Size = UDim2.fromOffset(72, 72)
btn.AnchorPoint = Vector2.new(1, 1)
btn.Position = UDim2.new(1, -18, 1, -170)
btn.BackgroundColor3 = Color3.fromRGB(16, 22, 19)
btn.BackgroundTransparency = 0.25
btn.BorderSizePixel = 0
btn.Font = Enum.Font.Code
btn.TextSize = 16
btn.TextColor3 = Color3.fromRGB(140, 232, 174)
btn.Text = "PULSE"
btn.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = btn

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(46, 107, 74)
stroke.Thickness = 1
stroke.Parent = btn

btn.Activated:Connect(firePulse)

-- Sichtbarkeits-Poll statt Attribut-Signalen: der Charakter wird pro Runde
-- neu bestempelt und kann respawnen; ein 0.5-s-Poll ist billiger als das
-- Verbindungs-Geflecht, das beides sauber abdeckte.
task.spawn(function()
	while true do
		gui.Enabled = UserInputService.TouchEnabled
			and roundToken ~= nil
			and scanAllowed()
		task.wait(0.5)
	end
end)
