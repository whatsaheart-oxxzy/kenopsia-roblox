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
-- ============================= DIE REGEL =============================
--
--     shouldSend(verbleibende, hatteGesellschaft)
--         = hatteGesellschaft und verbleibende == 1
--
-- Es zaehlt die KOPFZAHL, nicht wer gerade gegangen ist. Von vier Spielern
-- duerfen drei gehen, ohne dass irgendwer wegteleportiert wird -- erst wenn
-- EINER uebrig ist, faehrt dieser eine zurueck:
--
--     4 -> 3   bleibt      3 -> 2   bleibt      2 -> 1   ZURUECK
--
-- Zwei Verbleibende koennen weiterspielen, und genau das tun sie auch.
--
-- Die EINZIGE Zusatzbedingung ist `hadCompany`: der Server muss ueberhaupt
-- schon einmal zwei Spieler gesehen haben. Ohne sie waere die Regel nicht
-- erfuellbar, sondern selbstzerstoerend -- ein frischer Server hat IMMER genau
-- einen Spieler, naemlich den ersten, der ankommt. "Kopfzahl == 1" allein
-- schickte also jeden Ankoemmling in derselben Sekunde zurueck, das Menue
-- schickte ihn wieder her, und niemand koennte je auf einen zweiten warten:
-- eine Endlosschleife zwischen zwei Places, in der das Spiel nie startet.
-- `hadCompany` unterscheidet "ich bin allein UEBRIG" von "ich bin allein
-- ANGEKOMMEN". Nur der erste Fall ist ein beendetes Spiel.
--
-- Geprueft wird an ZWEI Stellen, damit kein Weg daran vorbeifuehrt:
--   * bei jedem Abgang -- der Normalfall, sofort;
--   * alle WATCH_SECONDS als Wache -- fuer den Fall, dass ein Teleport
--     scheitert (Netz, Place offline). Ohne sie bliebe der Letzte fuer immer
--     haengen, denn ein zweiter Abgang, der es erneut versuchen koennte, kommt
--     nie: es ist ja niemand mehr da, der gehen koennte.
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

local WATCH_SECONDS = 5 -- Takt der Wache (siehe oben)
local RETRY_SECONDS = 10 -- Mindestabstand zwischen zwei Teleport-Versuchen

local started = false
local closing = false
local hadCompany = false
local lastAttempt = -math.huge

-- DIE ENTSCHEIDUNG, rein und ohne Seiteneffekte -- damit sie nachvollziehbar
-- ist, ohne einen Server mit vier Leuten zu besetzen.
function SoloExit.shouldSend(remainingCount, hadCompanyFlag)
	return hadCompanyFlag == true and remainingCount == 1
end

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
	local now = os.clock()
	if now - lastAttempt < RETRY_SECONDS then return false end
	lastAttempt = now
	if RunService:IsStudio() then
		-- TeleportService ist in Studio nicht verfuegbar; der Aufruf wuerde nur
		-- werfen. Die Entscheidung ist trotzdem sichtbar, damit dieser Pfad
		-- auch im Studio-Test geprueft werden kann.
		print(("[SoloExit] studio: would send %s to place %d (teleports do not run in Studio)")
			:format(plr.Name, SoloExit.MENU_PLACE_ID))
		return false
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(SoloExit.MENU_PLACE_ID, { plr })
	end)
	if not ok then
		warn(("[SoloExit] teleport failed for %s: %s"):format(plr.Name, tostring(err)))
	end
	return ok
end

-- Eine Auswertung der Regel gegen den echten Serverstand.
local function evaluate(leaving)
	if closing then return end
	local remaining = SoloExit.remainingAfter(leaving)
	if #remaining >= 2 then
		hadCompany = true
		return
	end
	if not SoloExit.shouldSend(#remaining, hadCompany) then return end
	SoloExit.sendToMenu(remaining[1])
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

	if #Players:GetPlayers() >= 2 then hadCompany = true end
	Players.PlayerAdded:Connect(function()
		if #Players:GetPlayers() >= 2 then hadCompany = true end
	end)

	Players.PlayerRemoving:Connect(function(leaving)
		local remaining = SoloExit.remainingAfter(leaving)
		if SoloExit.shouldSend(#remaining, hadCompany) then
			print(("[SoloExit] %s left - %s is alone, returning to the main menu")
				:format(leaving.Name, remaining[1].Name))
		end
		evaluate(leaving)
	end)

	-- Die Wache. Billig (eine Kopfzahl alle WATCH_SECONDS) und der einzige
	-- Weg, einen gescheiterten Teleport ueberhaupt noch einmal zu versuchen.
	task.spawn(function()
		while not closing do
			task.wait(WATCH_SECONDS)
			evaluate(nil)
		end
	end)

	TeleportService.TeleportInitFailed:Connect(function(plr, result, message)
		warn(("[SoloExit] teleport init failed for %s: %s (%s) - the watch will retry")
			:format(plr and plr.Name or "?", tostring(message), tostring(result)))
	end)

	print(("[SoloExit] armed - a lone survivor returns to place %d")
		:format(SoloExit.MENU_PLACE_ID))
end

return SoloExit
