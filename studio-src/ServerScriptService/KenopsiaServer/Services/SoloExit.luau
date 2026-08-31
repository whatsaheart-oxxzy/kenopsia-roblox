--!nonstrict
-- SOLO EXIT (31.08.2026, user) -- wer allein zurueckbleibt, wird SOFORT ins
-- Hauptmenue geschickt. Keine Warnung, kein Countdown, keine Taste.
--
-- Kenopsia ist ein 2-4-Spieler-Spiel. Ein einzelner Spieler kann nichts mehr
-- starten: der Countdown verlangt MinPlayers, also sass der Letzte bis eben in
-- einer Lobby, die nie wieder losgeht -- ohne Weg zurueck ins Menue, weil es
-- im ganzen Spiel keinen einzigen TeleportService-Aufruf gab.
--
-- DAS ZIEL ist Kenopsia_DEV (das MainMenu-Place). Dieselbe Universe
-- (10640788131) wie MainGame, in docs/baseline und INNER-GAME-PLAN mehrfach
-- belegt. Steht als EINE Konstante hier, damit ein Wechsel eine Zeile ist.
--
-- DER AUSLOESER IST EIN ABGANG, NICHT DIE KOPFZAHL. Das ist der eine Punkt,
-- an dem dieses Modul bewusst enger ist als "sobald nur noch 1 Spieler da
-- ist": ein frischer Server hat IMMER genau einen Spieler -- den ersten, der
-- ankommt. Wuerde allein die Kopfzahl zaehlen, schickte der Server jeden
-- Ankoemmling sofort zurueck, das Menue schickte ihn wieder her, und niemand
-- koennte je auf einen zweiten Spieler warten. Eine Endlosschleife zwischen
-- zwei Places. Deshalb: NUR wenn jemand GEHT und genau einer uebrig bleibt --
-- also exakt der Fall "der 2. Spieler ist raus und er ist allein".
--
-- Laeuft in JEDER Phase, nicht nur im Match: zwei in der Lobby, einer geht --
-- der andere kann genauso wenig spielen und faehrt genauso zurueck.
--
-- Der Abbruch des laufenden Matches bleibt RoomService (abortMatch); dieses
-- Modul kuemmert sich nur um den Rueckweg. Schlaegt der Teleport fehl, bleibt
-- der Spieler hier und faellt auf genau dieses Verhalten von vorher zurueck.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local SoloExit = {}

-- Kenopsia_DEV -- das MainMenu-Place, Universe 10640788131.
SoloExit.MENU_PLACE_ID = 129909297895850

local started = false
local closing = false
local sending = {} -- [userId] = true, damit ein zweiter Anlauf nicht doppelt sendet

-- Wer bleibt uebrig, wenn `leaving` weg ist? PlayerRemoving feuert, WAEHREND
-- der Spieler noch in Players:GetPlayers() steht -- deshalb wird er hier
-- explizit herausgerechnet statt auf ein Timing zu hoffen.
function SoloExit.remainingAfter(leaving)
	local out = {}
	for _, plr in Players:GetPlayers() do
		if plr ~= leaving then
			table.insert(out, plr)
		end
	end
	return out
end

-- Schickt EINEN Spieler ins Menue. Gibt true zurueck, wenn der Teleport
-- angenommen wurde. Wirft nie.
function SoloExit.sendToMenu(plr)
	if not (typeof(plr) == "Instance" and plr:IsA("Player") and plr.Parent == Players) then
		return false
	end
	if sending[plr.UserId] then return false end
	if RunService:IsStudio() then
		-- TeleportService ist in Studio nicht verfuegbar; der Aufruf wuerde nur
		-- werfen. Die Entscheidung ist trotzdem sichtbar, damit dieser Pfad
		-- auch im Studio-Test geprueft werden kann.
		print(("[SoloExit] studio: would send %s to place %d (teleports do not run in Studio)")
			:format(plr.Name, SoloExit.MENU_PLACE_ID))
		return false
	end
	sending[plr.UserId] = true
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(SoloExit.MENU_PLACE_ID, { plr })
	end)
	if not ok then
		sending[plr.UserId] = nil
		warn(("[SoloExit] teleport failed for %s: %s"):format(plr.Name, tostring(err)))
	end
	return ok
end

function SoloExit.start()
	if started then return end
	started = true

	-- Beim Herunterfahren gehen ALLE Spieler -- unterwegs steht die Kopfzahl
	-- zwangslaeufig einmal auf 1. Da ist nichts zu retten, und ein Teleport in
	-- einen schliessenden Server ist nur eine Fehlermeldung.
	game:BindToClose(function()
		closing = true
	end)

	Players.PlayerRemoving:Connect(function(leaving)
		if closing then return end
		local remaining = SoloExit.remainingAfter(leaving)
		if #remaining ~= 1 then return end
		local last = remaining[1]
		print(("[SoloExit] %s left - %s is alone, returning to the main menu")
			:format(leaving.Name, last.Name))
		SoloExit.sendToMenu(last)
	end)

	-- Der Teleport kann nach der Annahme noch scheitern (Netz, Place offline).
	-- Dann bleibt der Spieler hier: Sperre loesen, damit ein spaeterer Abgang
	-- es erneut versuchen darf.
	TeleportService.TeleportInitFailed:Connect(function(plr, result, message)
		if plr then sending[plr.UserId] = nil end
		warn(("[SoloExit] teleport init failed for %s: %s (%s)")
			:format(plr and plr.Name or "?", tostring(message), tostring(result)))
	end)

	print(("[SoloExit] armed - a lone survivor returns to place %d")
		:format(SoloExit.MENU_PLACE_ID))
end

return SoloExit
