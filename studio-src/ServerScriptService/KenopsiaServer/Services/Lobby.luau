--!nonstrict
-- LOBBY / HOLDING CELL (31.08.2026) -- der Warteraum und, wichtiger,
-- workspace.SpawnLocation. BAUT SICH SELBST, weil genau das am 30.08. gefehlt
-- hat und niemand es sehen konnte.
--
-- WAS VORHER PASSIERT IST. Vier Dienste schlagen seit jeher
-- `workspace:FindFirstChild("SpawnLocation")` nach und weichen sonst auf
-- (0,5,0) aus -- TrialKit, Podium, Minefield, BirdHunting. Im Place existierte
-- kein einziger SpawnLocation. Also erschien jeder Charakter auf der
-- Engine-Vorgabe hoch ueber dem Nichts, fiel bis
-- workspace.FallenPartsDestroyHeight (-500) und wurde geloescht; der Respawn
-- landete wieder im selben Loch. Ergebnis: ganze Sessions liefen mit
-- `player.Character == nil` -- die Trials drehten leere Runden, waehrend der
-- Client im blauen Nebel schwebte.
--
-- WARUM DAS HIER CODE IST UND KEINE GEOMETRIE. Am 30.08. wurde der Raum von
-- Hand ins offene Place gebaut. Das funktioniert, hat aber einen Haken, der
-- nichts mit Roblox zu tun hat: Geometrie lebt in der .rbxl, nicht im Repo.
-- Sie ist nicht versioniert, nicht reviewbar, kein Rojo-Sync holt sie zurueck,
-- und ein einziges "nicht speichern" loescht sie. Als Modul ist der Raum
-- dagegen im Repo, im Diff, und baut sich bei JEDEM Serverstart neu.
--
-- IDEMPOTENT. ensure() legt nur an, was fehlt: ist der Raum schon da (von
-- Hand gebaut oder von einem frueheren Start), passiert nichts. Damit ist es
-- egal, ob der Place gespeichert wurde oder nicht.
--
-- Zur Laufzeit erzeugte Instanzen werden NICHT in die Place-Datei geschrieben.
-- Das ist Absicht: die Datei braucht den Raum nicht mehr zu kennen.
local Workspace = game:GetService("Workspace")

local Lobby = {}

local FOLDER = "KenopsiaLobby"
local SPAWN = "SpawnLocation"

-- Der Boden liegt mit der Oberkante auf Y = 0, der SpawnLocation darauf. Alle
-- vier Dienste oben streuen +-6 Studs um diese Position, deshalb ist der Raum
-- mit 44 x 44 bewusst groesser als der Streukreis.
local FLOOR = Vector3.new(44, 2, 44)
local WALL_H = 12
local COL_FLOOR = Color3.fromRGB(34, 40, 56)
local COL_WALL = Color3.fromRGB(44, 52, 72)

local function slab(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = true
	p.CastShadow = false
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Baut den Raum, falls er fehlt, und gibt den SpawnLocation zurueck.
function Lobby.ensure()
	local folder = Workspace:FindFirstChild(FOLDER)
	if not folder or not folder:IsA("Folder") then
		if folder then folder:Destroy() end
		folder = Instance.new("Folder")
		folder.Name = FOLDER
		folder.Parent = Workspace

		slab(folder, "Floor", FLOOR, CFrame.new(0, -1, 0), COL_FLOOR)
		slab(folder, "WallN", Vector3.new(44, WALL_H, 2), CFrame.new(0, WALL_H / 2, -23), COL_WALL)
		slab(folder, "WallS", Vector3.new(44, WALL_H, 2), CFrame.new(0, WALL_H / 2, 23), COL_WALL)
		slab(folder, "WallW", Vector3.new(2, WALL_H, 44), CFrame.new(-23, WALL_H / 2, 0), COL_WALL)
		slab(folder, "WallE", Vector3.new(2, WALL_H, 44), CFrame.new(23, WALL_H / 2, 0), COL_WALL)
		slab(folder, "Ceiling", Vector3.new(48, 2, 48), CFrame.new(0, WALL_H + 1, 0), COL_FLOOR)

		-- EINE kalte Deckenleuchte. Die Ambient-Boden-Regel aus
		-- INNER-GAME-PLAN 5 gilt auch hier: der Raum muss lesbar bleiben, wenn
		-- die Handy-Qualitaetsstufe alle lokalen Lichter wegwirft -- deshalb
		-- ist die Platte selbst Neon und das PointLight nur der Zuschlag.
		local lamp = slab(folder, "LampPanel", Vector3.new(16, 0.4, 16),
			CFrame.new(0, WALL_H - 0.2, 0), Color3.fromRGB(120, 150, 190), Enum.Material.Neon)
		lamp.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(140, 170, 220)
		light.Brightness = 0.8
		light.Range = 26
		light.Parent = lamp
	end

	-- Der SpawnLocation ist der eigentliche Zweck des Moduls und MUSS ein
	-- direktes Kind von Workspace sein: genau so schlagen ihn die vier Dienste
	-- nach (FindFirstChild ohne Rekursion).
	local spawn = Workspace:FindFirstChild(SPAWN)
	if spawn and not spawn:IsA("SpawnLocation") then
		spawn:Destroy()
		spawn = nil
	end
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = SPAWN
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.CFrame = CFrame.new(0, 0.5, 0)
		spawn.Anchored = true
		spawn.CanCollide = true
		spawn.CastShadow = false
		spawn.Color = Color3.fromRGB(40, 48, 66)
		spawn.Material = Enum.Material.Slate
		spawn.Neutral = true
		spawn.Duration = 0 -- kein ForceField beim Erscheinen
		spawn.Parent = Workspace
	end

	return spawn
end

function Lobby.start()
	local spawn = Lobby.ensure()
	print(("[Lobby] holding cell ready - spawn at %s"):format(tostring(spawn and spawn.Position)))
end

return Lobby
