--!nonstrict
-- CANTEEN PROTOCOL (Gate 4) -- eat everything on your plate without being seen.
--
-- This REPLACES the TableManners rhythm prototype; it does not repair it. The
-- old mechanic was "press on the beat". This one is a hiding game: the food is
-- free, the swallowing is what kills you.
--
-- MECHANIC
--   All players eat at the same time, each at their own plate. 20 peas. The
--   fork carries at most 4. Two actions:
--     PLATE  plate -> fork, loads up to the remaining capacity. ALWAYS SAFE.
--     MOUTH  fork -> mouth, consumes the WHOLE load. Detectable.
--   An empty fork to the mouth is a harmless miss -- it costs the cooldown and
--   nothing else, so mashing MOUTH is self-punishing rather than forbidden.
--
-- THE OBSERVER IS ENTIRELY SERVER-SIDE.
--   hidden 2.5-9.0s -> lowering 0.35s -> watching 0.9-1.8s -> raising 0.30s
--   23.08.2026: the 2-player test called him predictable ("looks up after a
--   fixed time") and the round short. Three changes, all in runObserver:
--     * the hidden read is 2.5-9.0 s instead of 2.0-4.0 s, so the rhythm
--       cannot be counted;
--     * FAKE-OUT: after raising, 30% of the time the next read is 1.0-1.8 s
--       and he looks straight up again. Never twice in a row, so two
--       fake-outs cannot pin a player at the plate for half the round;
--     * the watch grows across the round, 0.9-1.8 s at GO to 1.4-2.6 s at
--       the deadline, so the last peas cost more than the first.
--   The client is TOLD the phase so it can draw a warning; it never decides
--   whether anyone was seen. A client that lies about the phase changes what
--   its player sees on screen and nothing else.
--
-- WHY `lowering` EXISTS: it is the tell. Without a visible wind-up the observer
-- is a coin flip and the player has no decision to make. 0.35 s is enough to
-- abort a swallow you have not started and not enough to save one you have.
--
-- Arena markers come from `Workspace.CanteenProtocol.Rig`, built by
-- `tools/build-canteen-arena.luau`. Nothing here reads the room's dressing --
-- in particular not the eight `Plate` cylinders, whose child order is not a
-- contract. `validateArena()` gates the whole trial.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodFX = require(script.Parent.BloodFX)
local CanteenProps = require(script.Parent.CanteenProps)
local Pacing = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("Pacing"))
local AnimationIds = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("AnimationIds"))
-- P1.5: the 3-2-1 step length is the SAME number the kit and the client use.
local Feel = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("FeelConfig"))

local CanteenProtocol = {}
-- #50 watchdog hook state (see CanteenProtocol.abort below).
CanteenProtocol._guard = nil :: { cleanup: (() -> ())? }?
CanteenProtocol._guardOwner = nil :: string?

local ROUND_TIME = Pacing.RoundSeconds.canteen or 60

-- 23.08.2026: 16 -> 20 peas (five full forks instead of four). CanteenProps
-- builds the plate from this number through `opts.peas`; nothing else counts.
local PEAS_TOTAL = 20
local FORK_CAPACITY = 4

-- Server-side minimum intervals. These are the rate limit, not a rhythm: they
-- exist so a macro cannot empty a plate in one frame, and they are checked on
-- the SERVER clock so a client cannot argue about them.
local MIN_PLATE_INTERVAL = 1.0 -- 24.08.2026 (user): one pea per second, the stab reads
local MIN_MOUTH_INTERVAL = 0.50

-- How long a swallow stays detectable. An eating window that overlaps the
-- watching phase AT ANY POINT is caught, so committing to a mouthful just
-- before the observer drops is fatal -- which is the decision the game is made
-- of.
local EAT_WINDOW = 0.45

-- 23.08.2026: 2.0-4.0 -> 2.5-9.0. A 2-second spread is a rhythm; a 6.5-second
-- spread is a wait you cannot count out. HIDDEN_MIN is also the cosmetic `dur`
-- announced for the hidden phase -- the real read time is never sent (see
-- runObserver), or the packet would be the tell.
local HIDDEN_MIN, HIDDEN_MAX = 2.5, 9.0
-- FAKE-OUT (23.08.2026): after a raising phase, with this probability the next
-- read is FAKEOUT_MIN-FAKEOUT_MAX s and the eyes come straight back up. The
-- player who shovels the moment the paper rises is the player this catches.
-- Never two in a row: the second one would be a rhythm again, and a pair of
-- 1-second reads gives nobody a window to eat in.
local FAKEOUT_CHANCE = 0.3
local FAKEOUT_MIN, FAKEOUT_MAX = 1.0, 1.8
local LOWERING_TIME = 0.35
-- 23.08.2026: the watch ramps. WATCH_MIN/MAX hold at GO; by the deadline the
-- range is WATCH_END_MIN/MAX, linear in elapsed/ROUND_TIME (watchRange below).
-- A longer stare late in the round means a swallow started on the tell is
-- still caught more often, which is where the last peas get their price.
local WATCH_MIN, WATCH_MAX = 0.9, 1.8
local WATCH_END_MIN, WATCH_END_MAX = 1.4, 2.6
local RAISING_TIME = 0.30
-- Four simultaneous catches are executed serially. The watchdog is a ceiling,
-- not a mandatory hold: the loop exits as soon as every visible shot finishes.
local EXECUTION_GRACE = 8.0

-- 26.08.2026 (user, Schritt 3): der Schlag zwischen Treffer und Zerlegen.
--
-- Ohne ihn passiert alles im selben Frame: Einschlag, Koerper weg, Brockenregen,
-- Schirm-Blut. Das liest sich als ein einziger roter Schmierer, in dem keine
-- Ursache mehr zu erkennen ist. Mit dem Schlag sieht man erst den TREFFER am
-- Kopf und dann, dass ihn das zerlegt -- zwei Ereignisse, in dieser Reihenfolge.
--
-- Kurz genug, dass es ein Einschlag bleibt und kein Zoegern wird. Der Boss
-- feuert onFire am Muendungsblitz ab, das hier haengt also am Blitz und nicht an
-- der Rundenuhr -- und es haelt die Runde auch nicht auf: finish() laeuft
-- unabhaengig weiter, pendingExecutions wartet nicht auf diesen Timer.
local SHATTER_BEAT = 0.15

-- RANKING BANDS. runRound returns one ordering key per player and MachineFlow
-- sums those across rounds, then ranks and distributes exactly 1700. The bands
-- encode the plan's order: finished > alive-unfinished > eliminated.
--
-- The separation is arithmetic, not hope (23.08.2026: re-fitted for 20 peas
-- and a 60-s round; PEA_STEP 50 -> 40, the bands themselves stay the shared
-- TrialRules.BAND values):
--   eliminated  0    + eaten*40 (max 19 -> 760) + survived*2 (max 60 -> 120) = 880
--   alive       1000 + eaten*40 (max 19 -> 760)                              = 1760
--   finished    2000 + spare*10 (max 60 -> 600)                              = 2600
-- 19 is the ceiling for both lower bands because eating the 20th pea IS
-- finishing. 880 < 1000 and 1760 < 2000, so no band can ever reach into the one
-- above it. (At PEA_STEP 50 the eliminated band would have reached 1070.)
local ELIMINATED_BAND = 0
local ALIVE_BAND = 1000
local FINISHED_BAND = 2000
local PEA_STEP = 40
local FINISH_SPEED_STEP = 10
local SURVIVAL_STEP = 2

-- cos(40 degrees). Roblox's default FOV is 70, so the half-angle is 35 vertical
-- and wider horizontally; 40 keeps the Observer on screen from any seat without
-- demanding it sit dead centre.
local MIN_OBSERVER_COSINE = 0.766

local SEAT_IDS = { "P1", "P2", "P3", "P4" }
local MARKER_GROUPS = {
	{ folder = "Seats", key = "seats" },
	{ folder = "PlateAnchors", key = "plates" },
	{ folder = "ForkAnchors", key = "forks" },
	{ folder = "MouthTargets", key = "mouths" },
	{ folder = "PlayerCameras", key = "cams" },
	{ folder = "ExecutionMuzzles", key = "muzzles" },
}
local SOLO_MARKERS = { "Observer", "BossSeat", "ObserverCamera", "SpectatorCamera" }

local current = nil
local TrialInput
local arenaBusy = false
local arenaOwnerSessionId = nil

-- ARENA --------------------------------------------------------------------

local cachedArena = nil

local function arena()
	-- IsDescendantOf(workspace), not `rig.Parent`. A rig detached from the
	-- world still has a parent chain for a while, and rebuilding it destroys
	-- these instances -- a destroyed part errors on every property read rather
	-- than returning nil. This is the stricter of the two tests.
	if cachedArena and cachedArena.rig:IsDescendantOf(workspace) then
		return cachedArena
	end
	cachedArena = nil

	local root = workspace:FindFirstChild("CanteenProtocol")
	local rig = root and root:FindFirstChild("Rig")
	if not rig then return nil end

	local a = { root = root, rig = rig }
	for _, group in ipairs(MARKER_GROUPS) do
		local folder = rig:FindFirstChild(group.folder)
		if not folder then return nil end
		local list = {}
		for i, id in ipairs(SEAT_IDS) do
			local m = folder:FindFirstChild(id)
			if not (m and m:IsA("BasePart")) then return nil end
			list[i] = m
		end
		a[group.key] = list
	end
	for _, name in ipairs(SOLO_MARKERS) do
		local m = rig:FindFirstChild(name)
		if not (m and m:IsA("BasePart")) then return nil end
		a[name] = m
	end

	cachedArena = a
	return a
end

-- The gate. `ready` stays false until this passes, so a half-built arena can
-- never reach a player: it returns the FIRST reason it fails rather than a
-- bare false, because "arena invalid" in a log tells nobody which marker to go
-- and place.
function CanteenProtocol.validateArena()
	local root = workspace:FindFirstChild("CanteenProtocol")
	if not root then return false, "Workspace.CanteenProtocol is missing" end
	if not root:FindFirstChild("Rig") then
		return false, "Rig folder missing - run tools/build-canteen-arena.luau"
	end

	-- Drop the cache before validating. The gate must never pass on a snapshot:
	-- caught by a negative test, removing a seat marker left the cached entry
	-- pointing at a still-valid but UNPARENTED part, and validateArena happily
	-- returned true for an arena that no longer had that seat in it. A gate that
	-- only ever confirms what it already believes is not a gate.
	cachedArena = nil
	local a = arena()
	if not a then
		return false, "Rig is incomplete - re-run tools/build-canteen-arena.luau"
	end

	-- Every marker must still hang in the rig. Resolving them is not enough:
	-- FindFirstChild returns the live child, but a marker reparented elsewhere
	-- in the world would resolve for some other lookup and place a player
	-- somewhere nobody built.
	for _, group in ipairs(MARKER_GROUPS) do
		for i, id in ipairs(SEAT_IDS) do
			if not a[group.key][i]:IsDescendantOf(a.rig) then
				return false, ("%s.%s is detached from the Rig"):format(group.folder, id)
			end
		end
	end
	for _, name in ipairs(SOLO_MARKERS) do
		if not a[name]:IsDescendantOf(a.rig) then
			return false, ("%s is detached from the Rig"):format(name)
		end
	end

	-- A marker that answers raycasts would silently break the observer's line
	-- of sight and every future hit test in this arena.
	for _, d in ipairs(a.rig:GetDescendants()) do
		if d:IsA("BasePart") and (d.CanQuery or d.CanCollide) then
			return false, ("marker %s is raycast/collision visible"):format(d.Name)
		end
	end

	for i, id in ipairs(SEAT_IDS) do
		local seat, plate, mouth = a.seats[i], a.plates[i], a.mouths[i]

		-- NaN never equals itself. A degenerate CFrame.lookAt produces exactly
		-- this and every downstream position becomes garbage, so it is checked
		-- here rather than discovered as a player teleporting to nowhere.
		if seat.Position.X ~= seat.Position.X then
			return false, ("seat %s has a non-finite CFrame"):format(id)
		end

		if mouth.Position.Y <= plate.Position.Y then
			return false, ("%s mouth (%.2f) is not above its plate (%.2f)")
				:format(id, mouth.Position.Y, plate.Position.Y)
		end

		local flat = Vector3.new(1, 0, 1)
		local reach = ((seat.Position - plate.Position) * flat).Magnitude
		if reach < 2 or reach > 24 then
			return false, ("%s is %.1f studs from its plate - not a seat at this table"):format(id, reach)
		end

		local toPlate = ((plate.Position - seat.Position) * flat).Unit
		if seat.CFrame.LookVector:Dot(toPlate) < 0.9 then
			return false, ("%s does not face its own plate"):format(id)
		end

		for j = i + 1, #SEAT_IDS do
			if (a.seats[j].Position - seat.Position).Magnitude < 4 then
				return false, ("seats %s and %s occupy the same place"):format(id, SEAT_IDS[j])
			end
		end
	end

	-- The observer must actually SEE the eaters. A marker aimed into a wall
	-- passes every name-and-count check and makes the whole minigame unlosable.
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	-- 23.08.2026: player characters are parked at the seats (invisible, with
	-- hit boxes) from round 2 on; they are not geometry and must not fail the
	-- camera->plate ray, which the over-the-shoulder camera crosses.
	local ignore = { a.rig }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(ignore, plr.Character) end
	end
	local props = workspace:FindFirstChild("CP_Props")
	if props then table.insert(ignore, props) end
	rp.FilterDescendantsInstances = ignore
	for i, id in ipairs(SEAT_IDS) do
		local target = a.mouths[i].Position
		local hit = workspace:Raycast(a.Observer.Position, target - a.Observer.Position, rp)
		if hit and (target - hit.Position).Magnitude > 3.5 then
			return false, ("Observer cannot see %s - blocked by %s"):format(id, hit.Instance.Name)
		end
	end

	-- And the PLAYER must be able to see their own plate. This check was
	-- missing, and the first screenshot from a player camera came back as a
	-- brown blur: the cameras were placed by fixed offsets from the seat and
	-- ended up INSIDE the chair backrests, which are 16 studs tall. A camera
	-- that renders the inside of a chair passes every name, count and distance
	-- check ever written.
	for i, id in ipairs(SEAT_IDS) do
		local eye = a.cams[i].Position
		local target = a.plates[i].Position
		local hit = workspace:Raycast(eye, target - eye, rp)
		if hit and (target - hit.Position).Magnitude > 3.5 then
			return false, ("%s camera cannot see its plate - blocked by %s"):format(id, hit.Instance.Name)
		end

		-- And the Observer must be ON SCREEN from that camera. This is the
		-- check that the first player-view screenshot forced: with the Observer
		-- parked past the head of the table the angle was ~57 degrees, outside
		-- a 70-degree FOV. Every other check passed and the tell was invisible.
		-- MAX_OBSERVER_ANGLE is deliberately tighter than the half-FOV so the
		-- warning is comfortably in view rather than clipping the edge.
		local toObserver = (a.Observer.Position - eye).Unit
		local cosAngle = a.cams[i].CFrame.LookVector:Dot(toObserver)
		if cosAngle < MIN_OBSERVER_COSINE then
			return false, ("%s cannot see the Observer - %.0f degrees off screen"):format(
				id, math.deg(math.acos(math.clamp(cosAngle, -1, 1))))
		end
	end

	return true
end

-- HELPERS ------------------------------------------------------------------

local function livingOf(room)
	local out = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		local char = plr and plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if plr and char and hum and rootPart and hum.Health > 0 then
			out[mm.userId] = { player = plr, char = char, hum = hum, root = rootPart }
		end
	end
	return out
end

local function remotes()
	return ReplicatedStorage.Kenopsia:FindFirstChild("Remotes")
end

local function announce(room, payload)
	local folder = remotes()
	local MachineState = folder and folder:FindFirstChild("MachineState")
	if not MachineState then return end
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then MachineState:FireClient(plr, payload) end
	end
end

local function tellOne(userId, payload)
	local folder = remotes()
	local MachineState = folder and folder:FindFirstChild("MachineState")
	local plr = Players:GetPlayerByUserId(userId)
	if MachineState and plr then MachineState:FireClient(plr, payload) end
end

local function pushState(st, userId)
	local ps = st.state[userId]
	if not ps then return end
	-- The props ARE the readout. The payload below is the future client HUD's
	-- copy; if it never arrives, the plate and the fork still show the truth.
	if st.props and ps.seat then
		st.props.setPeas(ps.seat, ps.remaining)
		st.props.setFork(ps.seat, ps.fork)
	end
	tellOne(userId, {
		kind = "cpstate",
		peas = ps.remaining,
		fork = ps.fork,
		capacity = FORK_CAPACITY,
		total = PEAS_TOTAL,
		eaten = ps.eaten,
	})
end

-- ELIMINATION ---------------------------------------------------------------

local function roundActive(st)
	return current == st
		and st.active
		and st.room ~= nil
		and st.room.phase == "Playing"
		and st.room.sessionId == st.sessionId
end

local function eliminate(st, userId, reason)
	local ps = st.state[userId]
	if not ps or ps.finished or ps.eliminated then return end
	ps.eliminated = true
	ps.eliminatedAt = os.clock() - st.startedAt
	ps.fork = 0

	-- MP-08 B-02 (26.08.2026, user): die Vollbildkarte gehoert dem Gestorbenen.
	-- announce() feuerte sie an JEDEN im Raum, und showAnnounce("death") zieht
	-- nach Feel.Death.Hold auf volles Schwarz -- mitten in einer Runde, in der
	-- man den Observer sehen MUSS, und in der ohnehin jeder auf der festen
	-- Tischkamera sitzt. Der Raum bekommt jetzt eine Feed-Zeile, die nichts
	-- zudeckt; die Karte geht nur noch an den, um den es geht.
	--
	-- seconds = 3.0: 2.5 s Stand (Feel.Death.Hold) + 0.5 s Zug auf Schwarz,
	-- dann raeumt sie sich selbst ab (S2) und gibt das Bild wieder frei.
	local who = Players:GetPlayerByUserId(userId)
	local name = (who and who.DisplayName) or "SUBJECT"
	tellOne(userId, { kind = "cpout", reason = reason })
	tellOne(userId, { kind = "announce", style = "death", seconds = 3.0,
		text = ("PROTOCOL VIOLATION - %s"):format(name) })
	for _, mm in st.room.members do
		if mm.userId ~= userId then
			tellOne(mm.userId, { kind = "feed", style = "death",
				text = ("%s - PROTOCOL VIOLATION"):format(string.upper(name)) })
		end
	end

	-- Logical elimination happens immediately, but the body and blood wait for
	-- the boss's first visible muzzle event. Simultaneous catches are queued by
	-- the prop controller so the Shoot track is never restarted mid-execution.
	local subject = st.subjects[userId]
	if not (subject and subject.char and subject.hum and subject.hum.Health > 0) then
		-- No live subject to shoot (left, reset, respawned). There is still a
		-- PS1 body sitting at that plate, and leaving it breathing through an
		-- elimination reads as a bug at the table. Drop it without a muzzle.
		if st.props and st.props.dinerDie and ps.seat then
			pcall(st.props.dinerDie, ps.seat)
		end
		return
	end
	st.pendingExecutions = (st.pendingExecutions or 0) + 1
	local completed = false
	local function finish()
		if completed then return end
		completed = true
		st.pendingExecutions = math.max(0, (st.pendingExecutions or 1) - 1)
	end
	local function fire()
		if not roundActive(st) then return end
		local live = st.subjects[userId]
		local plr = Players:GetPlayerByUserId(userId)
		if live ~= subject or not plr or plr.Character ~= subject.char then return end
		if not subject.char.Parent or not subject.hum.Parent or subject.hum.Health <= 0 then return end

		-- Keep the R15 body intact instead of exploding into Roblox body parts.
		-- The avatar is invisible at the table; the PS1 diner is what is hit.
		subject.hum.BreakJointsOnDeath = false
		local diner = st.props and st.props.diner and ps.seat and st.props.diner(ps.seat)
		local hitPart = subject.char:FindFirstChild("Head") or subject.root
		local at = diner and diner:headPosition() or (hitPart and hitPart:IsA("BasePart") and hitPart.Position)

		-- 26.08.2026 (user): KEINE LEICHE MEHR. DER KOERPER GEHT GANZ.
		--
		-- Drei Anlaeufe hat die Leiche gekostet -- Clip laeuft aus und der Koerper
		-- verschwindet per Respawn, Clip legt ihn unter den Tisch, gerechnete Pose
		-- verknotet das Rig. Alle drei scheiterten am selben Punkt: eine sitzende
		-- Leiche an einem Tisch ist eine Pose, und die gehoert in ein
		-- Animationsprogramm, nicht in Laufzeitcode.
		--
		-- Also gibt es sie nicht mehr. Der Schuss ZERLEGT den Diner, genau wie die
		-- zweite Mine in der DEAD ZONE (Minefield: "The body goes entirely --
		-- shatter destroys it -- no death clip, no corpse"). Damit faellt das ganze
		-- Problem weg statt geloest zu werden: kein Endframe, der halten muss, kein
		-- Koerper, der irgendwo landen kann, keine Pose, die stimmen muss.
		--
		-- Die Reihenfolge ist die Choreografie:
		--   1. Treffer am Kopf -- der rote Punkt, der Koerper sitzt noch
		--   2. SHATTER_BEAT spaeter: der Diner verschwindet, der Brockenregen
		--      kommt, und der ganze Raum kriegt Schirm-Blut und Shake
		-- Der Teller mit den restlichen Erbsen bleibt stehen. Das ist der Punkt:
		-- gedeckt fuer jemanden, der nicht mehr da ist.
		--
		-- NUR shatter, sonst NICHTS. Der Client baut daraus bereits das volle
		-- Paket (GoreClient.shatter): zwei Sounds, burst 2.2, 14 Brocken,
		-- Fontaene, vier Lachen und Tropfen. Hier standen zusaetzlich noch ein
		-- fountain, ein pool und ein ImpactBody -- also eine zweite Fontaene, eine
		-- sechste Lache und derselbe Sound ein zweites Mal an derselben Stelle.
		-- Zwei identische Sounds am selben Punkt werden nicht lauter, sondern
		-- matschig, und sechs Lachen uebereinander sind ein Fleck, kein Blut.
		-- Die Lachen liegen uebrigens richtig: pool() raycastet nach unten und
		-- legt sich auf die TISCHPLATTE, nicht auf den Boden darunter.
		if at then BloodFX.hit(at, st.audience) end
		task.delay(SHATTER_BEAT, function()
			-- Der Timer ueberlebt die Runde nicht: nach dem Abraeumen ist st.props
			-- nil und der Diner zerstoert. Beides hier geprueft, statt sich darauf
			-- zu verlassen, dass 0.15 s immer reichen.
			if not roundActive(st) or not st.props then return end
			if diner then st.props.dinerDie(ps.seat) end
			if not at then return end
			BloodFX.shatter(diner and diner.model or nil, at, st.audience)
			-- 26.08.2026 (user): 0.9 -> 1.5. Der Wert war als "kleiner als eine
			-- Mine" gedacht, aber das ist der falsche Vergleich: eine Mine geht
			-- IRGENDWO im Feld hoch, die Hinrichtung passiert am selben Tisch, an
			-- dem man sitzt. Ueber 1 zu gehen hat dabei einen konkreten Zweck --
			-- applyGoreFx deckelt trauma bei 1, ein Wert darueber stellt also
			-- sicher, dass der Schlag IMMER voll ankommt, auch wenn kurz zuvor
			-- schon geschuettelt wurde.
			announce(st.room, { kind = "gorefx", pos = { at.X, at.Y, at.Z }, power = 1.5 })
		end)

		-- DER SPIELER SELBST STIRBT TROTZDEM NICHT.
		--
		-- Hier stand `subject.hum.Health = 0`. Der Humanoid-Tod loeste Roblox'
		-- eigenen Respawn aus (Players.CharacterAutoLoads ist an, RespawnTime 5 s):
		-- fuenf Sekunden spaeter stand der Spieler wieder am SpawnLocation und
		-- konnte mitten in der laufenden Runde herumlaufen. Der Diner ist zerlegt,
		-- der Avatar bleibt einfach verankert, unsichtbar und auf WalkSpeed 0 an
		-- seinem Platz sitzen, bis cleanupRound ihn freigibt.
		--
		-- Der Ausweg ist NICHT, den Respawn global abzuschalten (CharacterAutoLoads
		-- ist eine Players-Eigenschaft, die das ganze Spiel betrifft). Der
		-- Humanoid stirbt hier einfach nicht mehr: eliminiert ist eine
		-- Zustandssache (ps.eliminated), und jede Eingabe- und Schleifenpruefung
		-- oben laeuft ueber ps.eliminated, nicht ueber Health.
		--
		-- Damit MachineFlow den Tod trotzdem zaehlt: watchDeaths hoert auf
		-- Humanoid.Died ODER auf das Attribut KenopsiaProcessed. Genau fuer diesen
		-- Fall ist der zweite Pfad da. Hochzaehlen statt setzen, damit auch eine
		-- zweite Elimination in einer spaeteren Runde ein Change-Signal ausloest.
		local plrOut = Players:GetPlayerByUserId(userId)
		if plrOut then
			plrOut:SetAttribute("KenopsiaProcessed",
				(plrOut:GetAttribute("KenopsiaProcessed") or 0) + 1)
		end
		subject.hum.WalkSpeed = 0
		subject.hum.AutoRotate = false
		subject.root.Anchored = true
	end

	if st.props and st.props.execute then
		local ok = pcall(st.props.execute, fire, finish)
		if not ok then
			fire()
			finish()
		end
	else
		fire()
		finish()
	end
end

-- OBSERVER ------------------------------------------------------------------

local function setPhase(st, phase, duration)
	st.phase = phase
	st.phaseEndsAt = os.clock() + duration
	-- The Observer physically descends. That is the tell -- readable with the
	-- eyes, needing no client code and impossible for a client to hide from
	-- itself.
	if st.props then st.props.observerTo(phase, duration) end
	announce(st.room, { kind = "cpobs", phase = phase, dur = duration })
end

-- Anyone still mid-swallow when the eyes open is caught. This is the half of
-- the rule the input handler cannot see: the action already happened.
local function sweep(st)
	local now = os.clock()
	for userId, ps in st.state do
		if not (ps.finished or ps.eliminated) and now < (ps.eatUntil or 0) then
			eliminate(st, userId, "seen")
		end
	end
end

local function sleepWhileActive(st, duration)
	local deadline = os.clock() + duration
	while os.clock() < deadline do
		if not roundActive(st) then return false end
		task.wait(0.05)
	end
	return roundActive(st)
end

-- 23.08.2026: the watch range at THIS moment of the round. Linear from
-- (WATCH_MIN, WATCH_MAX) at GO to (WATCH_END_MIN, WATCH_END_MAX) at the
-- deadline; clamped so the execution grace after the deadline does not keep
-- growing it.
local function watchRange(st)
	local elapsed = os.clock() - st.startedAt
	local t = math.clamp(elapsed / ROUND_TIME, 0, 1)
	return WATCH_MIN + (WATCH_END_MIN - WATCH_MIN) * t,
		WATCH_MAX + (WATCH_END_MAX - WATCH_MAX) * t
end

local function runObserver(st)
	local rng = Random.new()
	-- 23.08.2026: the read length is decided when the paper goes up, not when
	-- it comes down, so the fake-out decision and the announce happen together.
	-- The first read is always a full one: nobody has had a chance to eat yet.
	local hiddenTime = rng:NextNumber(HIDDEN_MIN, HIDDEN_MAX)
	local lastWasFakeout = false
	while roundActive(st) do
		if not sleepWhileActive(st, hiddenTime) then break end
		-- Never open the eyes while an execution is still being played. The boss
		-- is a serial actor: he cannot lower the paper and shoot at the same
		-- time, so a sweep launched during a queue of shots would arrive with NO
		-- visible wind-up and the survivors would be caught on a tell that was
		-- never shown. Three simultaneous catches take ~4.9 s, which is longer
		-- than the shortest hidden+watch cycle, so this is reachable in a
		-- four-player room rather than theoretical. The rule waits for the
		-- picture; the picture is never faked to keep up with the rule.
		while (st.pendingExecutions or 0) > 0 do
			if not sleepWhileActive(st, 0.1) then return end
		end
		setPhase(st, "lowering", LOWERING_TIME)
		if not sleepWhileActive(st, LOWERING_TIME) then break end

		local watchMin, watchMax = watchRange(st)
		local watchTime = rng:NextNumber(watchMin, watchMax)
		setPhase(st, "watching", watchTime)
		sweep(st)
		if not sleepWhileActive(st, watchTime) then break end

		setPhase(st, "raising", RAISING_TIME)
		if not sleepWhileActive(st, RAISING_TIME) then break end
		-- 23.08.2026: roll the next read. A fake-out is short and never follows
		-- another fake-out. The announced `dur` stays the constant HIDDEN_MIN on
		-- purpose: the boss rig and the client ignore it for this phase, but the
		-- procedural fallback tweens its rise with it, and a faster rise would be
		-- a tell the mechanic is built to not have.
		local fakeout = (not lastWasFakeout) and rng:NextNumber() < FAKEOUT_CHANCE
		lastWasFakeout = fakeout
		if fakeout then
			hiddenTime = rng:NextNumber(FAKEOUT_MIN, FAKEOUT_MAX)
		else
			hiddenTime = rng:NextNumber(HIDDEN_MIN, HIDDEN_MAX)
		end
		setPhase(st, "hidden", HIDDEN_MIN)
	end
end

-- INPUT ---------------------------------------------------------------------

local function handleAction(player, action)
	local st = current
	if not st then return end
	if not st.acceptInput then return end
	-- The same freshness chain Dead Zone uses: phase, session snapshot and the
	-- round token together mean a packet from an earlier round cannot land in
	-- a later one.
	if not st.room or st.room.phase ~= "Playing" then return end
	if st.room.sessionId ~= st.sessionId then return end

	local ps = st.state[player.UserId]
	-- A finished player is SAFE and silent: no further input can un-finish them
	-- or get them caught after the fact.
	if not ps or ps.finished or ps.finishing or ps.eliminated then return end
	local subject = st.subjects[player.UserId]
	if not subject
		or player.Character ~= subject.char
		or not subject.char.Parent
		or not subject.hum.Parent
		or subject.hum.Health <= 0
	then
		eliminate(st, player.UserId, "subject lost")
		return
	end

	local now = os.clock()
	if st.deadline and now >= st.deadline then
		st.acceptInput = false
		return
	end

	if action == "plate" then
		if now < (ps.nextPlateAt or 0) then return end
		ps.nextPlateAt = now + MIN_PLATE_INTERVAL
		-- 24.08.2026 (user): the observer catches the FORK too -- any table
		-- movement under open eyes is a violation, not just the swallow.
		if st.phase == "watching" then
			eliminate(st, player.UserId, "seen")
			return
		end
		-- Loading is ALWAYS safe -- the observer only ever catches a swallow.
		-- 24.08.2026 (user): ONE pea per stab. Filling the fork is four clicks
		-- of theatre (the stab clip plays on every one), not one.
		local space = FORK_CAPACITY - ps.fork
		if space <= 0 or ps.remaining <= 0 then return end
		local take = math.min(1, space, ps.remaining)
		ps.fork = ps.fork + take
		ps.remaining = ps.remaining - take
		pushState(st, player.UserId)
		return
	end

	if action ~= "mouth" then return end
	if now < (ps.nextMouthAt or 0) then return end
	ps.nextMouthAt = now + MIN_MOUTH_INTERVAL

	-- An empty fork to the mouth is a harmless miss: it burns the cooldown and
	-- nothing else. It deliberately does NOT open an eating window, so it
	-- cannot get you killed -- mashing is wasteful, not fatal.
	if ps.fork <= 0 then
		tellOne(player.UserId, { kind = "cpmiss" })
		return
	end

	local load = ps.fork
	ps.fork = 0
	ps.eaten = ps.eaten + load
	ps.eatUntil = now + EAT_WINDOW
	if st.props and ps.seat then st.props.eat(ps.seat, load) end
	pushState(st, player.UserId)

	-- Caught the moment it happens, if the eyes are already open. The other
	-- half -- a window that runs INTO the watching phase -- is sweep()'s job.
	if st.phase == "watching" then
		eliminate(st, player.UserId, "seen")
		return
	end

	if ps.eaten >= PEAS_TOTAL then
		-- The last mouthful is not safe until its complete visible/detectable
		-- window closes. A watcher who opens during that interval still catches
		-- the player; only then does the run become finished and immune.
		ps.finishing = true
		local finishAt = ps.eatUntil
		task.delay(math.max(0, finishAt - os.clock()), function()
			local remaining = finishAt - os.clock()
			if remaining > 0 then task.wait(remaining) end
			if not roundActive(st) then return end
			if st.state[player.UserId] ~= ps or ps.eliminated or ps.finished then return end
			ps.finishing = false
			ps.finished = true
			ps.finishedAt = os.clock() - st.startedAt
			if st.props and st.props.dinerHappy and ps.seat then pcall(st.props.dinerHappy, ps.seat) end
			tellOne(player.UserId, { kind = "cpdone", at = ps.finishedAt })
		end)
	end
end

function CanteenProtocol.init()
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	TrialInput = folder:FindFirstChild("TrialInput")
	if not TrialInput then
		TrialInput = Instance.new("RemoteEvent")
		TrialInput.Name = "TrialInput"
		TrialInput.Parent = folder
	end
	-- Decides once whether the published clips play in this place; the boss
	-- and diners load their tracks through the same module.
	AnimationIds.warmup()
	TrialInput.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then return end
		if payload.trialId ~= "canteen" then return end
		local st = current
		if not st then return end
		if payload.roundToken ~= st.roundToken then return end
		handleAction(player, payload.action)
	end)
end

-- ROUND ---------------------------------------------------------------------

local function cleanupRound(st)
	if not st or st.cleaned then return end
	st.cleaned = true
	st.active = false
	st.acceptInput = false
	if current == st then current = nil end

	if st.observerThread then
		pcall(task.cancel, st.observerThread)
		st.observerThread = nil
	end
	if not st.endAnnounced and st.room then
		announce(st.room, { kind = "cpend" })
		st.endAnnounced = true
	end

	for _, r in ipairs(st.restore or {}) do
		if r.root and r.root.Parent then r.root.Anchored = r.anchored end
		for inst, transparency in r.visibility or {} do
			if inst.Parent then inst.Transparency = transparency end
		end
		if r.hum and r.hum.Parent then
			r.hum.WalkSpeed = r.walk
			r.hum.AutoRotate = r.autoRotate
			r.hum.BreakJointsOnDeath = r.breakJoints
			if r.useJumpPower then
				r.hum.JumpPower = r.jumpPower
			else
				r.hum.JumpHeight = r.jumpHeight
			end
		end
	end

	for userId, subject in st.subjects or {} do
		if subject.char and subject.char.Parent then
			subject.char:SetAttribute("XBotMoves", "")
		end
		local plr = Players:GetPlayerByUserId(userId)
		local char = plr and plr.Character
		if char and char ~= subject.char then char:SetAttribute("XBotMoves", "") end
	end

	if st.props then
		pcall(st.props.destroy)
		st.props = nil
	end
	pcall(BloodFX.clear, st.roundToken, st.audience)
	for userId in st.state or {} do
		tellOne(userId, { kind = "role", role = "none" })
	end
end

function CanteenProtocol.cleanup(ctx)
	local st = current
	if not st then return end
	if ctx and ctx.sessionId ~= nil
		and tostring(ctx.sessionId) ~= tostring(st.sessionId) then
		return
	end
	cleanupRound(st)
end

local function waitForArena(room)
	local announced = false
	while arenaBusy do
		if #room.members == 0 or room.phase ~= "Playing" then return false end
		if not announced then
			announced = true
			announce(room, { kind = "announce", text = "CANTEEN OCCUPIED. STANDBY." })
		end
		task.wait(0.25)
	end
	arenaBusy = true
	arenaOwnerSessionId = room.sessionId
	return true
end

local function runRoundInner(room, roundIndex, guard)
	local scores = {}
	for _, mm in room.members do scores[mm.userId] = 0 end

	local okArena, reason = CanteenProtocol.validateArena()
	if not okArena then
		warn(("[CanteenProtocol] arena invalid: %s"):format(reason))
		return scores
	end
	local a = arena()

	local subjects = livingOf(room)
	local audience = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then table.insert(audience, plr) end
	end

	local st = {
		room = room,
		sessionId = room.sessionId,
		-- Minted here, exactly as Dead Zone mints its own. There is no
		-- `room.roundToken` to read: rooms carry a sessionId, and the per-round
		-- token is the trial's to create. Reading a field that does not exist
		-- would have silently fallen through to a fallback forever.
		roundToken = ("CP-%s-R%s-%d"):format(
			tostring(room.sessionId), tostring(roundIndex or 1),
			math.floor(os.clock() * 1000) % 100000),
		state = {},
		subjects = subjects,
		audience = audience,
		active = true,
		acceptInput = false,
		phase = "hidden",
		startedAt = os.clock(),
		pendingExecutions = 0,
		restore = {},
	}
	current = st
	guard.cleanup = function() cleanupRound(st) end

	-- Built AFTER validateArena, never before: the gate raycasts from the
	-- Observer to every MouthTarget, and props standing on the table during
	-- that check could block the very line of sight it is there to prove.
	-- (They also carry CanQuery = false, so this is belt and braces.)
	st.props = CanteenProps.build(a, {
		peas = PEAS_TOTAL,
		forkCapacity = FORK_CAPACITY,
		eatWindow = EAT_WINDOW,
	})

	-- Seat everyone. More members than seats cannot happen (the room caps at 4)
	-- but the loop is written so a fifth member is skipped rather than
	-- overwriting seat 1 -- silently stacking two players on one chair would be
	-- a far worse failure than one player sitting out.
	local seatIndex = 0
	for _, mm in room.members do
		local s = subjects[mm.userId]
		st.state[mm.userId] = {
			remaining = PEAS_TOTAL, fork = 0, eaten = 0,
			finished = false, finishing = false, eliminated = s == nil,
			eatUntil = 0, nextPlateAt = 0, nextMouthAt = 0,
		}
		if s and seatIndex < #SEAT_IDS then
			seatIndex = seatIndex + 1
			local i = seatIndex
			st.state[mm.userId].seat = i

			table.insert(st.restore, {
				root = s.root,
				hum = s.hum,
				anchored = s.root.Anchored,
				walk = s.hum.WalkSpeed,
				autoRotate = s.hum.AutoRotate,
				breakJoints = s.hum.BreakJointsOnDeath,
				useJumpPower = s.hum.UseJumpPower,
				jumpPower = s.hum.JumpPower,
				jumpHeight = s.hum.JumpHeight,
			})

			s.hum.Health = s.hum.MaxHealth
			s.hum.WalkSpeed = 0
			s.hum.JumpPower = 0
			s.root.CFrame = a.seats[i].CFrame
			-- Anchored, not just WalkSpeed 0: the seat marker floats at chair
			-- height with nothing solid beneath it, so an unanchored character
			-- would simply fall off the chair the moment the round began.
			s.root.Anchored = true
			s.char:SetAttribute("XBotMoves", "eat")

			-- The PS1 diner is the body at the table; the avatar stays the
			-- Humanoid the rules act on and is simply hidden underneath it.
			-- Only when a diner actually spawned -- an empty rig slot must not
			-- leave a player with no body at all.
			local diner = st.props.seatDiner and st.props.seatDiner(i)
			if diner then
				local visibility = {}
				for _, d in s.char:GetDescendants() do
					if (d:IsA("BasePart") or d:IsA("Decal")) and d.Transparency < 1 then
						visibility[d] = d.Transparency
						d.Transparency = 1
					end
				end
				st.restore[#st.restore].visibility = visibility
			end

			-- One fixed table camera for everybody, seat-independent: the
			-- ObserverCamera marker looks down the table at the boss with all
			-- four diners in frame, so you watch your own body eat. It is a
			-- validated SOLO_MARKER, so it exists whenever the round runs.
			local eye = a.ObserverCamera.CFrame
			local aim = eye.Position + eye.LookVector * 10
			tellOne(mm.userId, { kind = "role", role = "spectate",
				pos = { eye.Position.X, eye.Position.Y, eye.Position.Z },
				look = { aim.X, aim.Y, aim.Z },
				roundToken = st.roundToken })
		end
	end

	do
		local boss = st.props.boss
		local bossTracks = 0
		for _ in (boss and boss.tracks or {}) do bossTracks += 1 end
		local diners, scale, eatClip = 0, nil, false
		for _, d in (st.props.diners or {}) do
			diners += 1
			scale = d.scale
			if d.tracks.Eat then eatClip = true end
		end
		-- Diners are deliberately still: no idle track, and no eat clip until one
		-- is published. "eat=none" is the expected reading, not a fault.
		print(("[CP] rigs: boss=%s (%d tracks) diners=%d scale=%.2f eat=%s published=%s")
			:format(boss and "seated" or "MISSING", bossTracks, diners, scale or 0,
				eatClip and "clip" or "none", tostring(AnimationIds.publishedPlayable)))
	end

	announce(room, { kind = "announce", text = "EAT EVERYTHING. DO NOT BE SEEN." })
	if not sleepWhileActive(st, 2.4) then return scores end

	for c = 3, 1, -1 do
		if not roundActive(st) then return scores end
		announce(room, { kind = "count", n = c })
		if not sleepWhileActive(st, Feel.Countdown.StepSeconds) then return scores end
	end
	if not roundActive(st) then return scores end
	announce(room, { kind = "go" })

	st.startedAt = os.clock()
	st.deadline = st.startedAt + ROUND_TIME
	st.acceptInput = true
	for _, mm in room.members do pushState(st, mm.userId) end

	-- Dead Zone and Bird Hunting both log their round start, and those lines
	-- have repeatedly answered in seconds what guessing could not. Seats is the
	-- number that matters: a member who could not be seated plays no part.
	print(("[CP] go; members=%d seated=%d peas=%d token=%s")
		:format(#room.members, seatIndex, PEAS_TOTAL, st.roundToken))

	st.observerThread = task.spawn(runObserver, st)

	local deadline = st.deadline
	local hardDeadline = deadline + EXECUTION_GRACE
	while os.clock() < hardDeadline do
		task.wait(0.1)
		if not roundActive(st) or #room.members == 0 then break end
		-- The grace period is presentation/settlement time only. No new plate or
		-- mouth action is accepted after the authored round deadline.
		if os.clock() >= deadline then st.acceptInput = false end
		-- Reset, respawn and subject loss are terminal. Checking in the server
		-- loop closes the gap even when the player sends no further remote.
		for userId, ps in st.state do
			if not (ps.finished or ps.eliminated) then
				local subject = st.subjects[userId]
				local plr = Players:GetPlayerByUserId(userId)
				if not subject
					or not plr
					or plr.Character ~= subject.char
					or not subject.char.Parent
					or not subject.hum.Parent
					or subject.hum.Health <= 0
				then
					eliminate(st, userId, "subject lost")
				end
			end
		end
		local anyLeft = false
		local anyFinishing = false
		for _, ps in st.state do
			if ps.finishing and not ps.eliminated then anyFinishing = true end
			if not (ps.finished or ps.eliminated) then
				anyLeft = true
			end
		end
		if not anyLeft and (st.pendingExecutions or 0) == 0 then break end
		if os.clock() >= deadline
			and (st.pendingExecutions or 0) == 0
			and not anyFinishing
		then
			break
		end
	end
	st.acceptInput = false
	if st.observerThread then
		pcall(task.cancel, st.observerThread)
		st.observerThread = nil
	end
	announce(room, { kind = "cpend" })
	st.endAnnounced = true

	local finished, eliminated = 0, 0
	for _, ps in st.state do
		if ps.finished then
			finished = finished + 1
		elseif ps.eliminated then
			eliminated = eliminated + 1
		end
	end
	print(("[CP] round over, elapsed=%.1f finished=%d caught=%d")
		:format(os.clock() - st.startedAt, finished, eliminated))

	local elapsed = os.clock() - st.startedAt
	for userId, ps in st.state do
		local key
		if ps.finished then
			local spare = math.max(0, ROUND_TIME - (ps.finishedAt or ROUND_TIME))
			key = FINISHED_BAND + math.floor(spare * FINISH_SPEED_STEP)
		elseif not ps.eliminated then
			key = ALIVE_BAND + ps.eaten * PEA_STEP
		else
			local survived = math.min(ps.eliminatedAt or 0, elapsed)
			key = ELIMINATED_BAND + ps.eaten * PEA_STEP + math.floor(survived * SURVIVAL_STEP)
		end
		scores[userId] = key
	end

	sleepWhileActive(st, 1.6)

	return scores
end

-- #50: watchdog-side cleanup after a task.cancel (see Minefield.abort).
function CanteenProtocol.abort()
	local g = CanteenProtocol._guard
	CanteenProtocol._guard = nil
	if g and g.cleanup then pcall(g.cleanup) end
	if arenaOwnerSessionId ~= nil and arenaOwnerSessionId == CanteenProtocol._guardOwner then
		arenaBusy = false
		arenaOwnerSessionId = nil
	end
end

function CanteenProtocol.runRound(room, roundIndex)
	local emptyScores = {}
	for _, mm in room.members do emptyScores[mm.userId] = 0 end
	if not waitForArena(room) then return emptyScores end

	local owner = room.sessionId
	local guard = { cleanup = function() end }
	CanteenProtocol._guard = guard
	CanteenProtocol._guardOwner = owner
	local ok, result = xpcall(function()
		return runRoundInner(room, roundIndex, guard)
	end, debug.traceback)
	CanteenProtocol._guard = nil
	pcall(guard.cleanup)
	if arenaOwnerSessionId == owner then
		arenaBusy = false
		arenaOwnerSessionId = nil
	end
	if not ok then error(result, 0) end
	return result
end

return CanteenProtocol
