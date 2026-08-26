--!nonstrict
-- DEAD ZONE: gemeinsames Minenfeld.
-- Minen sind unsichtbare Zellen unter dem Boden; ein Scanner-Puls (Taste F/Y)
-- pulst eine Welle und deckt Minen im Nahbereich persoenlich auf. Explosionen
-- toeten im Kernradius, werfen Ueberlebende in den Zombie-Crawl und lassen
-- Krater zurueck. Marker stammen aus dem von Hand gebauten workspace["Dead Zone"].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")

local BloodFX = require(script.Parent.BloodFX)
local Pacing = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("Pacing"))
-- P1.5: the 3-2-1 step length is the SAME number the kit and the client use.
local Feel = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("FeelConfig"))

local Minefield = {}
-- #50 watchdog hook state (see Minefield.abort below).
Minefield._guard = nil :: { cleanup: (() -> ())? }?

-- THE COMPACTOR IS THE ROUND TIMER, so its speed is DERIVED from the distance
-- it has to cover and the round length Pacing asks for -- never fixed. A fixed
-- speed silently changes the round length every time the arena or the
-- ShredderSpawnpoint marker moves, and that is exactly what had happened.
--
-- Measured in the live arena before this change: the marker sits 122 studs
-- BEHIND the minefield, so at the old fixed 4.5 studs/s the machine spent its
-- first 22 seconds merely reaching the players' starting line and needed 88 s
-- to finish -- against a planned round of 55. Worse, a CRAWLING player needs
-- 67 s to cross and escaped with 20 s to spare, which left being maimed with
-- no consequence at all. The machine threatened nobody.
--
-- The clamps below ARE the design, not safety rails:
--   under the runner's walk speed (7)  -> escaping on foot stays possible
--   over the crawl speed (4.2)         -> being maimed still costs the round
local MAX_SHRED_SPEED = 6.5   -- runner walks at 7
local MIN_SHRED_SPEED = 4.6   -- was: "runner crawls at 4.2" -- see CRAWL_SPEED
-- 23.08.2026: the crawl speed was only ever a number in the comment above.
-- The client owns WalkSpeed (KenopsiaClient applyMovement: 7 in "scan") and
-- nothing told it a runner had been maimed, so the attribute played the
-- crawl clip over a runner still walking at 7. The server now writes this
-- onto the humanoid the moment XBotCrawl latches; it replicates down.
--
-- 26.08.2026 (user, MP-08 S8): das Krabbeln war 4.2 und damit deutlich langsamer
-- als der Lauf; der Plan verlangte Lauftempo (10). Auf 10 waere der Compactor
-- aber wirkungslos geworden -- er ist auf MAX_SHRED_SPEED = 6.5 gedeckelt und
-- holt oberhalb davon NIEMANDEN mehr ein. Die Sache ist bei 6.5 binaer: jeder
-- Wert darueber ist derselbe Zustand ("entkommt immer"), nur anders lackiert.
--
-- 26.08.2026 (user, Entscheidung): 6.0 -- der einzige echte Mittelweg. Deutlich
-- fluessiger als die alten 4.2, aber INNERHALB des Compactor-Bandes
-- (MIN_SHRED_SPEED 4.6 .. MAX_SHRED_SPEED 6.5). Der Compactor faehrt
-- sweepDistance / sweepBudget, auf dieses Band geklemmt: in Runden, in denen
-- er nahe am oberen Klemmwert liegt, holt er einen Krabbler ein, darunter nicht.
-- Die Beinamputation kostet damit wieder Zeit, statt nur Optik zu sein -- aber
-- sie ist kein sicheres Todesurteil mehr.
--
-- Der Client rampt einen Laeufer von 7 auf 10 (applyMovement + Ramp-Schleife).
-- Ein Krabbler faehrt die Rampe NICHT: applyMovement laesst WalkSpeed in Ruhe,
-- solange XBotCrawl gesetzt ist, und die Ramp-Schleife nimmt ihn wieder aus.
-- Dieser Wert hier ist also der Endwert, nicht der Rampenfuss.
local CRAWL_SPEED = 6.0
-- Seconds allowed for the APPROACH -- the stretch from the marker to the
-- players' line, where the machine is behind everyone and threatens nobody.
-- Spending gameplay seconds there is what made the round 88 s. Lower this to
-- give the sweep more time (easier), raise it to give the sweep less (harder).
local APPROACH_SECONDS = 8
local SHRED_GRACE = 1.5
-- MOTION VALIDATION -- PARKED UNTIL GATE 6, NOT DEAD CODE.
--
-- selene reports all five as unused, and they are: they were copied across
-- from BirdHunting and never wired to anything. Dead Zone therefore performs
-- NO exit validation today -- reaching the exit counts however it happened.
--
-- That is a known, accepted gap. Anti-cheat is deliberately sequenced last,
-- which is also where the plan puts it: Gate 6, 'Security, performance,
-- adversarial review'. The shared validator (Services/MotionCheck, lifted
-- from BirdHunting's runnerPositionValid / runnerGrounded /
-- rememberRunnerPosition / rollbackRunner) belongs to that gate.
--
-- They are kept HERE rather than deleted so the tuning is not lost and so
-- the gap stays visible in the file it applies to. Do not delete them as
-- dead code.
--
-- The selene unused_variable warnings on all five are deliberately NOT
-- suppressed. They are true, and leaving them visible keeps the missing
-- validation on the radar; an allow() would hide exactly the signal this
-- comment exists to preserve.
-- 24.08.2026: runners SPRINT after 1 s of continuous movement (7 -> 10, the
-- client ramp in KenopsiaClient); the validator allows the ramped top speed.
local MAX_RUNNER_SPEED = 10
local POSITION_SPEED_FACTOR = 2
local POSITION_TOLERANCE = 5
local PATH_SPEED_FACTOR = 1.5
local PATH_TOLERANCE = 12
local CELL = 4
local MINE_DENSITY = 0.14
local SAFE_OVERLAP = 0.35
local FUSE = 0.12
local CHAIN_FUSE = 0.30
local CHAIN_RADIUS = 6
local KILL_RADIUS = 4
local KNOCK_RADIUS = 8
local SCAN_RADIUS = 8      -- Scanner-Puls zeigt Minen innerhalb 8 Studs
-- Replaced by the banded ordering key at the end of the round. Kept out of
-- the scoring entirely: CLEANRUN_BONUS as POINTS was what let a later
-- escapee outrank an earlier one, which the plan lists as an error not to
-- repeat. It survives as a +1 tiebreaker only.

local activeByUser = {}
local arenaBusy = false
local TrialInput

-- C1.a: this was an implicit global. It is now a module local, and the round
-- state it points at carries its owning room/session so a stale or foreign
-- packet cannot be serviced.
local current = nil

local function refs()
	local dz = workspace:FindFirstChild("Dead Zone")
	if not dz then return nil end
	local r = {
		dz = dz,
		ground = dz:FindFirstChild("Minefield Ground"),
		spawn = dz:FindFirstChild("Spawnpoint DeadZone"),
		mineStart = dz:FindFirstChild("MineStartpoint"),
		exit = dz:FindFirstChild("Exit"),
		cam = dz:FindFirstChild("Cameraplacement"),
		shredSpawn = dz:FindFirstChild("ShredderSpawnpoint"),
	}
	if not (r.ground and r.spawn and r.mineStart and r.exit and r.shredSpawn) then return nil end
	return r
end

local function livingOf(room)
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

local function roomActive(room)
	return #room.members > 0 and (room.phase == nil or room.phase == "Playing")
end

-- Who a finished player can watch: everyone still running. Sent WITH the
-- spectate role, because the client cannot tell a living runner from someone
-- standing at spawn -- only the server knows who is still in play.
local function stillRunning(state, exceptUserId)
	local out = {}
	for uid, ps in state do
		if uid ~= exceptUserId and not ps.done then table.insert(out, uid) end
	end
	return out
end

local function audienceOf(room)
	local audience = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then table.insert(audience, plr) end
	end
	return audience
end

-- Feldraster aus den Markern: Spalten quer (X), Reihen von MineStartpoint bis Exit
local function buildGrid(R)
	local gTop = R.ground.Position.Y + R.ground.Size.Y / 2
	local cx = R.ground.Position.X
	local halfW = R.ground.Size.X / 2 - 2.5
	local cols = math.max(4, math.floor((halfW * 2) / CELL))
	local z0 = R.mineStart.Position.Z
	local z1 = R.exit.Position.Z
	local dir = z1 > z0 and 1 or -1
	local rows = math.max(8, math.floor(math.abs(z1 - z0) / CELL))
	return {
		gTop = gTop, cols = cols, rows = rows, dir = dir,
		x0 = cx - halfW, z0 = z0,
	}
end

local function cellCenter(g, col, row)
	return Vector3.new(
		g.x0 + (col - 0.5) * CELL,
		g.gTop,
		g.z0 + g.dir * (row - 0.5) * CELL)
end

local function cellOf(g, pos)
	local col = math.floor((pos.X - g.x0) / CELL) + 1
	local row = math.floor((pos.Z - g.z0) * g.dir / CELL) + 1
	return col, row
end

-- zwei garantiert sichere Pfade (Random Walk), max. 35% gemeinsame Zellen
local function carvePaths(g)
	local function walk()
		local cells = {}
		local col = math.random(1, g.cols)
		for row = 1, g.rows do
			cells[row .. ":" .. col] = true
			-- etwas Breite: die Nachbarzelle ist mit-sicher
			local col2 = math.clamp(col + (math.random(2) == 1 and 1 or -1), 1, g.cols)
			cells[row .. ":" .. col2] = true
			col = math.clamp(col + math.random(-1, 1), 1, g.cols)
		end
		return cells
	end
	local a = walk()
	local b
	for _ = 1, 24 do
		b = walk()
		local shared, total = 0, 0
		for k in b do
			total += 1
			if a[k] then shared += 1 end
		end
		if total > 0 and shared / total <= SAFE_OVERLAP then break end
	end
	local safe = {}
	for k in a do safe[k] = true end
	for k in b do safe[k] = true end
	return safe
end

local function announce(room, payload)
	local MachineState = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")
	if not MachineState then return end
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then MachineState:FireClient(plr, payload) end
	end
end

local function tellOne(userId, payload)
	local MachineState = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")
	local plr = Players:GetPlayerByUserId(userId)
	if MachineState and plr then MachineState:FireClient(plr, payload) end
end

function Minefield.init()
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	TrialInput = folder:FindFirstChild("TrialInput")
	if not TrialInput then
		TrialInput = Instance.new("RemoteEvent")
		TrialInput.Name = "TrialInput"
		TrialInput.Parent = folder
	end
	TrialInput.OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then return end
		local st = current
		if not st then return end
		if payload.trialId ~= "minefield" or payload.action ~= "pulse" then return end
		-- C1.a: the round must still own this input.
		--   acceptInput  - open only between GO and round end.
		--   phase        - kills packets belonging to an aborted match.
		--   sessionId    - the round's snapshot must still match the room's.
		--   roundToken   - MANDATORY. The server hands this token to clients in
		--                  the round's role payload and refuses any pulse that
		--                  does not echo it exactly, so a packet replayed from
		--                  an earlier round is rejected even if it arrives while
		--                  a later round is live and accepting input.
		-- The token is a freshness check, not an authorisation check: it does
		-- not replace the role, membership, phase and rate checks around it.
		if not st.acceptInput then return end
		if not st.room or st.room.phase ~= "Playing" then return end
		if st.room.sessionId ~= st.sessionId then return end
		if payload.roundToken ~= st.roundToken then return end
		local ps = st.state[player.UserId]
		if not ps or ps.done then return end
		-- ein Druck = ein Puls; Server-Cooldown gegen Spam
		local now = os.clock()
		if (ps.lastPulse or 0) + 0.8 > now then return end
		ps.lastPulse = now
		ps.usedScanner = true
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local pos = root.Position
		local found = {}
		for _, mn in st.mines do
			if mn.live then
				local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(mn.pos.X, 0, mn.pos.Z)).Magnitude
				if d <= SCAN_RADIUS + CELL then
					table.insert(found, { mn.pos.X, mn.pos.Y, mn.pos.Z, d <= SCAN_RADIUS })
				end
			end
		end
		if #found > 0 then
			tellOne(player.UserId, { kind = "mines", list = found })
		end
	end)
end

local function runRoundInner(room, roundIndex, guard)
	local scores = {}
	for _, mm in room.members do scores[mm.userId] = 0 end
	local R = refs()
	if not R then
		warn("[DZ] Dead Zone Marker fehlen")
		return scores
	end
	local g = buildGrid(R)

	-- C1.a/C1.d: one state object per round. It owns its room and session, and
	-- carries the token every delayed callback is guarded against.
	local roundState = {
		state = {},
		mines = {},
		grid = g,
		runtime = nil,
		room = room,
		sessionId = room.sessionId,
		roundToken = ("DZ-%s-R%s-%d"):format(
			tostring(room.sessionId), tostring(roundIndex or 1),
			math.floor(os.clock() * 1000) % 100000),
		acceptInput = false,
		cleaned = false,
	}
	current = roundState

	-- True only while this exact round still owns the arena and the match is
	-- still Playing. Every loop, wait and delayed callback tests this.
	local function active()
		return current == roundState and roomActive(room)
	end

	local exitConn = nil
	local MachineState = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")

	-- C1.e: the one teardown path. Idempotent; reached from the happy path,
	-- from an abort, and from the xpcall handler in Minefield.runRound.
	local function cleanup()
		if roundState.cleaned then return end
		roundState.cleaned = true
		roundState.acceptInput = false
		if exitConn then
			exitConn:Disconnect()
			exitConn = nil
		end
		if current == roundState then current = nil end
		local spawnPos = workspace:FindFirstChild("SpawnLocation")
			and workspace.SpawnLocation.Position or Vector3.new(0, 5, 0)
		for uid, s in livingOf(room) do
			-- 23.08.2026: undo the server-side CRAWL_SPEED write before the
			-- role="none" packet below. That packet is what restores WalkSpeed
			-- today (the client's applyMovement has the final word, exactly as
			-- TrialKit's D10 restore); this only makes sure a crawler does not
			-- keep 4.2 if the packet never lands. Restored to what the server
			-- saw before the crawl, the same snapshot TrialKit keeps.
			local ps = roundState.state[uid]
			if ps and ps.crawling and ps.walkBefore then
				s.hum.WalkSpeed = ps.walkBefore
			end
			s.char:SetAttribute("XBotCrawl", false)
			s.char:SetAttribute("XBotLegless", false)
			s.char:SetAttribute("XBotScanning", false)
			s.char:SetAttribute("XBotMoves", "")
			s.root.CFrame = CFrame.new(spawnPos + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
		end
		if roundState.runtime then
			roundState.runtime:Destroy()
			roundState.runtime = nil
		end
		-- REQ-DZ-03, closed. This used to be the server-wide BloodFX.clear():
		-- it stopped EVERY bleed, wiped the shared FX folder, and broadcast a
		-- clear to every player on the server -- including anyone mid-round in
		-- another room. Now scoped to this round's own folder and audience.
		BloodFX.clear(roundState.roundToken, audienceOf(room))
		if MachineState then
			for _, mm in room.members do
				local plr = Players:GetPlayerByUserId(mm.userId)
				if plr then MachineState:FireClient(plr, { kind = "role", role = "none" }) end
			end
		end
	end
	guard.cleanup = cleanup

	-- 23.08.2026 (P1.4, REQ-IP-01): the old sentence was the reference game's
	-- round card verbatim; this is the DEAD ZONE tagline from MachineFlow.
	announce(room, { kind = "announce", text = "MARK THE GROUND. OUTRUN THE PRESS." })
	task.wait(2.8)
	-- C1.b: an abort during the announcement must not start a round.
	if not active() then return scores end

	-- Laufzeitordner: Minen, Krater, Effekte
	local runtime = Instance.new("Folder")
	runtime.Name = "DZ_Runtime"
	runtime.Parent = R.dz
	roundState.runtime = runtime

	-- Layout: sichere Pfade frei, Rest zufaellig vermint (unsichtbar, unterirdisch)
	local safe = carvePaths(g)
	local mines = {}
	roundState.mines = mines
	for row = 3, g.rows - 1 do
		for col = 1, g.cols do
			if not safe[row .. ":" .. col] and math.random() < MINE_DENSITY then
				local c = cellCenter(g, col, row)
				-- REQ-DZ-02: a mine is a SERVER RECORD, not an instance.
				--
				-- Every mine used to be an invisible Part parented into the
				-- runtime folder in Workspace, so an exploit client could
				-- enumerate that folder and read the ENTIRE minefield -- the
				-- one thing this minigame is built on not knowing.
				--
				-- The Part was never read: explode() works from pos and live,
				-- and the sonar answers out of this table. It was pure
				-- exposure for no behaviour at all.
				mines[row .. ":" .. col] = {
					pos = Vector3.new(c.X, g.gTop, c.Z),
					live = true,
				}
			end
		end
	end

	local state = {}
	roundState.state = state
	local subjects = livingOf(room)
	local n = 0
	for _, mm in room.members do
		local s = subjects[mm.userId]
		state[mm.userId] = { done = s == nil, escaped = false, progress = 0, usedScanner = false }
		if s then
			s.hum.Health = s.hum.MaxHealth
			s.char:SetAttribute("XBotMoves", "scan")
			s.char:SetAttribute("XBotCrawl", false)
			s.char:SetAttribute("XBotLegless", false)
			s.char:SetAttribute("XBotScanning", false)
			local w = math.max(R.spawn.Size.X - 6, 8)
			local x = R.spawn.Position.X - w / 2 + w * ((n + 0.5) / math.max(#room.members, 1))
			n += 1
			local look = Vector3.new(x, R.spawn.Position.Y + 4, R.exit.Position.Z)
			s.root.CFrame = CFrame.lookAt(Vector3.new(x, R.spawn.Position.Y + 4, R.spawn.Position.Z), look)
		end
	end

	if MachineState then
		for _, mm in room.members do
			local plr = Players:GetPlayerByUserId(mm.userId)
			if plr then
				-- C1.a: hand this round's token to the client. KenopsiaClient
				-- stores it and echoes it on every pulse; the TrialInput guard
				-- rejects anything that does not match.
				MachineState:FireClient(plr, { kind = "role", role = "runner", frozen = true, camDir = g.dir, camStyle = "top", roundToken = roundState.roundToken })
			end
		end
	end
	for c = 3, 1, -1 do
		-- C1.b: an abort during the countdown ends the round here.
		if not active() then return scores end
		announce(room, { kind = "count", n = c })
		task.wait(Feel.Countdown.StepSeconds)
	end
	if not active() then return scores end
	announce(room, { kind = "go" })

	-- C1.a: sonar input opens only now, and only for this round.
	roundState.acceptInput = true
	print("[DZ] go; members=" .. #room.members .. " token=" .. roundState.roundToken)

	local craterTpl = ServerStorage.KenopsiaAssets.Props.Minefield:FindFirstChild("MF_Crater")

	local explode
	explode = function(mine)
		-- C1.d: a fuse or chain scheduled before an abort must not detonate
		-- into a torn-down round.
		if not active() then return end
		if not mine.live then return end
		mine.live = false
		local pos = mine.pos
		-- Blitz + Krater
		local flash = Instance.new("Part")
		flash.Shape = Enum.PartType.Ball
		flash.Material = Enum.Material.Neon
		flash.Color = Color3.fromRGB(255, 120, 60)
		flash.Size = Vector3.new(6, 6, 6)
		flash.CFrame = CFrame.new(pos)
		flash.Anchored = true
		flash.CanCollide = false
		flash.CanQuery = false
		flash.Parent = runtime
		task.delay(0.16, function() flash:Destroy() end)
		if craterTpl then
			local cr = craterTpl:Clone()
			cr:PivotTo(CFrame.new(pos.X, g.gTop + 0.06, pos.Z) * CFrame.Angles(0, math.rad(math.random(360)), 0))
			cr.Parent = runtime
		end
		-- 3D-Explosion: zufaellige Variante am Krater; RollOff macht nah/fern
		local ka = game.SoundService:FindFirstChild("KenopsiaAudio")
		local pool = ka and ka.SFX:FindFirstChild("MineExplosions")
		if pool then
			local variants = pool:GetChildren()
			if #variants > 0 then
				local s2 = variants[math.random(#variants)]:Clone()
				s2.Parent = flash
				s2.PlayOnRemove = true
				task.delay(0.15, function() s2:Destroy() end)
			end
		end
		-- Schirm-Gore + aggressiver Shake fuer alle in der Naehe der Explosion
		announce(room, { kind = "gorefx", pos = { pos.X, pos.Y, pos.Z }, power = 1.3 })
		-- Treffer
		for uid, ps in state do
			if not ps.done then
				local s = livingOf(room)[uid]
				if s then
					local d = (Vector3.new(s.root.Position.X, 0, s.root.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
					if d <= KILL_RADIUS and ps.crawling then
						ps.done = true
						ps.cardAt = os.clock()
						-- The second mine: nothing is left to crawl with. The
						-- body goes entirely (shatter destroys it) -- no death
						-- clip, no corpse.
						BloodFX.shatter(s.char, nil, audienceOf(room))
						s.hum.Health = 0
						-- MP-08 S5: seconds = 3.0 -- 2.5 s Stand (Feel.Death.Hold),
						-- 0.5 s Zug auf Schwarz, dann raeumt die Karte sich selbst
						-- ab (S2). Das spectate-Paket kommt 3.2 s spaeter und
						-- findet die Scheibe frei vor.
						tellOne(uid, { kind = "announce", style = "death", seconds = 3.0,
							text = "YOU STEPPED WRONG. TWICE." })
						if R.cam then
							task.delay(3.2, function()
								-- C1.d: never strand a lobby player's camera on
								-- the arena after the round was torn down.
								if not active() then return end
								tellOne(uid, { kind = "role", role = "spectate",
									watch = stillRunning(state, uid),
									pos = { R.cam.Position.X, R.cam.Position.Y, R.cam.Position.Z },
									look = { R.exit.Position.X, g.gTop, R.exit.Position.Z } })
							end)
						end
					elseif d <= KNOCK_RADIUS and not ps.crawling then
						-- BEIDE RINGE, EINE VERZWEIGUNG.
						--
						-- Das waren bis MP-08 zwei Zweige: der innere (KILL_RADIUS,
						-- noch nicht krabbelnd) und der aeussere (KNOCK_RADIUS). Sie
						-- fuehrten schon vorher dieselben sechs Anweisungen aus, und
						-- mit der Feed-Zeile aus B-06 -- der aeussere Ring setzte das
						-- Krabbeln, sagte es aber nie -- waren sie Zeichen fuer
						-- Zeichen gleich. Zusammengelegt, statt die Zeile zweimal zu
						-- pflegen: die Reihenfolge bleibt erhalten, weil der Todesfall
						-- oben jetzt auf `ps.crawling` prueft und dieser Zweig auf
						-- `not ps.crawling` -- die vier Faelle (innen/aussen x
						-- krabbelnd/nicht) treffen damit exakt wie vorher.
						--
						-- 24.08.2026 (evening, user): JEDE erste Mine -- direkter
						-- Tritt eingeschlossen, scharf oder nicht -- ist die zweite
						-- Chance: die untere Haelfte geht, der Laeufer krabbelt
						-- weiter. Erst die ZWEITE Mine toetet (Zweig oben).
						--
						-- LATCHED. Ohne ps.crawling legte eine zweite Explosion den
						-- ganzen Effekt erneut auf jemanden, der schon krabbelt --
						-- noch ein Bleed auf dem ersten, und das Attribut unter eine
						-- bereits laufende Animation geschrieben.
						ps.crawling = true
						s.char:SetAttribute("XBotCrawl", true)
						-- 24.08.2026 (user): one mine takes the LOWER HALF. The
						-- client folds the leg chains under the floor while
						-- XBotLegless is set (PS1Animate) and maim() throws the
						-- hip gibs; bleed (inside maim) keeps the crawl trail.
						s.char:SetAttribute("XBotLegless", true)
						-- 23.08.2026: the crawl is now a SPEED, not only a clip. See
						-- CRAWL_SPEED. Snapshot first so cleanup() can put it back.
						ps.walkBefore = s.hum.WalkSpeed
						s.hum.WalkSpeed = CRAWL_SPEED
						BloodFX.maim(s.char, audienceOf(room), roundState.roundToken)
						-- MP-08 B-01/B-06: war fuer den inneren Ring eine Vollbild-
						-- karte OHNE Timer (style ~= "death" heisst sofort deckendes
						-- Schwarz, und danach schickte niemand ein `hide` -- der
						-- Krabbler war ab hier blind bis zum Rundenende, ganz ohne
						-- gestorben zu sein: die "eingefrorene UI"), und fuer den
						-- aeusseren gar nichts. Als Feed-Zeile sagt sie beiden
						-- dasselbe, ohne das Bild zu nehmen.
						tellOne(uid, { kind = "feed", style = "warn", text = "LEGS GONE. CRAWL." })
					end
				end
			end
		end
		-- Kettenreaktion
		for _, other in mines do
			if other.live then
				local d = (other.pos - pos).Magnitude
				if d <= CHAIN_RADIUS then
					task.delay(CHAIN_FUSE, function() explode(other) end)
				end
			end
		end
	end

	-- Exit. 24.08.2026 (user: standing IN the gate won nothing): the Touched
	-- event needed a physical overlap the gate geometry did not always give.
	-- The escape is now a LINE CHECK in the 20 Hz loop (crossing the exit's z
	-- wins, however you got there); Touched stays as a secondary trigger.
	local function escapeRunner(plr, ps)
		if not active() or not ps or ps.done then return end
		ps.done = true
		ps.escaped = true
		roundState.escapeCount = (roundState.escapeCount or 0) + 1
		ps.escapeOrder = roundState.escapeCount
		ps.cardAt = os.clock()
		local s = livingOf(room)[plr.UserId]
		if s then s.hum.WalkSpeed = 0 end
		-- MP-08 B-07: auch die Siegkarte deckte sofort zu und hatte keinen Timer.
		-- 1.2 s, passend zum spectate-Paket unten -- der Sieger sah bis dahin
		-- denselben schwarzen Schirm wie der Tote.
		tellOne(plr.UserId, { kind = "announce", style = "win", seconds = 1.2, text = "SECTOR CLEARED." })
		if R.cam then
			task.delay(1.2, function()
				if not active() then return end
				tellOne(plr.UserId, { kind = "role", role = "spectate",
					watch = stillRunning(state, plr.UserId),
					pos = { R.cam.Position.X, R.cam.Position.Y, R.cam.Position.Z },
					look = { R.exit.Position.X, g.gTop, R.exit.Position.Z } })
			end)
		end
	end
	exitConn = R.exit.Touched:Connect(function(hit)
		-- C1.d: Touched can fire during teardown; an abort must not award an escape.
		if not active() then return end
		local char = hit and hit.Parent
		local plr = char and Players:GetPlayerFromCharacter(char)
		if not plr then
			char = char and char.Parent
			plr = char and Players:GetPlayerFromCharacter(char)
		end
		escapeRunner(plr, plr and state[plr.UserId])
	end)

	-- DER COMPACTOR: eine Shredderwand, die von hinten durchs Feld marschiert.
	-- Er ersetzt den Rundentimer - wer troedelt, wird eingeholt und zerlegt.
	--
	-- REQ-IP-01: renamed from "Kastrierer". That word is German for
	-- "castrator" -- borrowed framing, and a direct conflict with the Mild
	-- maturity rating this project targets. "Compactor" describes what the
	-- machine does, in the same clinical register as the rest of the game.
	--
	-- SWAPPABLE VISUAL. Drop an authored model into
	-- ServerStorage.KenopsiaAssets.Props.Minefield as MF_Compactor and it is
	-- used instead of the procedural build below -- no code change.
	--
	-- This works because the machine is not a physics object. It kills by a
	-- SERVER-SIDE Z COMPARISON against its leading edge, never by Touched, so
	-- the parts are purely something to look at. A custom model brings its own
	-- animation; the server only decides WHERE the thing is.
	local shredWidth = g.cols * CELL + 8
	local customTpl = ServerStorage.KenopsiaAssets.Props.Minefield
		:FindFirstChild("MF_Compactor")
	local shred, custom
	if customTpl then
		shred = customTpl:Clone()
		shred.Name = "Compactor"
		custom = true
		-- An imported model arrives with collidable, queryable parts by
		-- default. Left alone it would physically shove runners around and
		-- block raycasts, replacing a clean distance rule with a bulldozer.
		for _, d in shred:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
	else
		shred = Instance.new("Model")
		shred.Name = "Compactor"
	end
	-- #50: the authored model (18 MeshParts) is animated CLIENT-SIDE. The
	-- server only publishes a motion state (Z0/T0/speed, below) plus the
	-- statics here; every client integrates z itself at render rate, so the
	-- march replicates a handful of attribute writes instead of 18 CFrames
	-- at 20 Hz. The procedural fallback keeps the old server-side path.
	if custom then
		shred:SetAttribute("MF_X", g.x0 + g.cols * CELL / 2)
		shred:SetAttribute("MF_Y", g.gTop + 3.2)
		shred:SetAttribute("MF_Yaw", g.dir > 0 and 180 or 0)
		game:GetService("CollectionService"):AddTag(shred, "MF_Compactor")
	end
	-- Procedural fallback, used only when no MF_Compactor model is supplied.
	-- housing / warnStrip / rollers stay declared in both paths because
	-- placeShred reads them; with a custom model they simply stay nil and
	-- placeShred takes its own branch.
	local housing, warnStrip
	local rollers = {}
	if not custom then
		housing = Instance.new("Part")
		housing.Name = "Housing"
		housing.Anchored = true
		housing.CanCollide = false
		housing.CanQuery = false
		housing.CanTouch = false
		housing.Material = Enum.Material.DiamondPlate
		housing.Color = Color3.fromRGB(58, 56, 52)
		housing.Size = Vector3.new(shredWidth, 7, 3)
		housing.Parent = shred
		warnStrip = Instance.new("Part")
		warnStrip.Name = "WarnStrip"
		warnStrip.Anchored = true
		warnStrip.CanCollide = false
		warnStrip.CanQuery = false
		warnStrip.CanTouch = false
		warnStrip.Material = Enum.Material.Neon
		warnStrip.Color = Color3.fromRGB(140, 16, 12)
		warnStrip.Size = Vector3.new(shredWidth, 0.5, 0.2)
		warnStrip.Parent = shred
		local wl = Instance.new("PointLight")
		wl.Color = Color3.fromRGB(255, 40, 30)
		wl.Range = 18
		wl.Brightness = 2
		wl.Parent = warnStrip
		-- rollers declared above
		for r = 1, 2 do
			local roller = Instance.new("Part")
			roller.Name = "Roller" .. r
			roller.Shape = Enum.PartType.Cylinder
			roller.Anchored = true
			roller.CanCollide = false
			roller.CanQuery = false
			roller.CanTouch = false
			roller.Material = Enum.Material.Metal
			roller.Color = Color3.fromRGB(72, 66, 60)
			roller.Size = Vector3.new(shredWidth - 2, 2.2, 2.2)
			roller.Parent = shred
			table.insert(rollers, roller)
			for tooth = 1, 6 do
				local tp = Instance.new("Part")
				tp.Name = "Tooth"
				tp.Anchored = true
				tp.CanCollide = false
				tp.CanQuery = false
				tp.CanTouch = false
				tp.Material = Enum.Material.Metal
				tp.Color = Color3.fromRGB(46, 42, 40)
				tp.Size = Vector3.new(shredWidth - 2.4, 0.5, 0.9)
				tp.Parent = roller
			end
		end
	end

	local lastPubSpeed = nil
	local function publishShred(zPos, signedSpeed)
		if lastPubSpeed == signedSpeed then return end
		lastPubSpeed = signedSpeed
		shred:SetAttribute("MF_Z0", zPos)
		shred:SetAttribute("MF_T0", workspace:GetServerTimeNow())
		shred:SetAttribute("MF_Speed", signedSpeed)
	end

	local function placeShred(zPos, spin)
		local baseCF = CFrame.new(g.x0 + g.cols * CELL / 2, g.gTop + 3.2, zPos)
		if custom then
			-- One PivotTo moves whatever the model contains, so an authored
			-- machine needs no knowledge here. Yawed to face down the corridor:
			-- the model is authored facing -Z, and g.dir tells us which way this
			-- arena actually runs.
			shred:PivotTo(baseCF * CFrame.Angles(0, g.dir > 0 and math.pi or 0, 0))
			return
		end
		housing.CFrame = baseCF * CFrame.new(0, 0.6, -g.dir * 1.2)
		warnStrip.CFrame = baseCF * CFrame.new(0, 3.6, g.dir * 0.4)
		for r, roller in rollers do
			-- Zylinderachse liegt von Haus aus auf X (Feldbreite); spin dreht um X
			local rc = baseCF * CFrame.new(0, -1.6 + (r - 1) * 2.2, g.dir * 1.4) * CFrame.Angles(spin + r * 1.57, 0, 0)
			roller.CFrame = rc
			local ti = 0
			for _, tp in roller:GetChildren() do
				if tp.Name == "Tooth" then
					ti += 1
					tp.CFrame = rc * CFrame.Angles(ti * (math.pi / 3), 0, 0) * CFrame.new(0, 1.35, 0)
				end
			end
		end
	end
	-- Start am ShredderSpawnpoint-Marker (verschieben = Startabstand tunen),
	-- aber nie vor der Sicherheitslinie hinter Spawnplatte/Feld
	local behindField = g.z0 - g.dir * 12
	local behindSpawn = R.spawn.Position.Z - g.dir * (R.spawn.Size.Z / 2 + 8)
	local shredZ = (behindSpawn - behindField) * g.dir < 0 and behindSpawn or behindField
	if R.shredSpawn then
		local markerZ = R.shredSpawn.Position.Z
		if (markerZ - shredZ) * g.dir < 0 then shredZ = markerZ end
	end
	local shredEndZ = g.z0 + g.dir * (g.rows * CELL + 12)
	
	-- TWO PHASES, and only the second one is gameplay.
	--
	-- APPROACH: marker -> the players' line. The machine is behind everyone
	-- here and can only catch someone who walks backwards into it, so its
	-- speed has no effect on fairness. It gets a fixed short budget.
	--
	-- SWEEP: the players' line -> past the exit. This is the part that decides
	-- the round, so it keeps the cap that makes escaping on foot possible and
	-- crawling fatal.
	--
	-- Splitting them is what lets the round hit its planned length WITHOUT
	-- moving ShredderSpawnpoint: the 98 dead studs behind the field no longer
	-- cost gameplay seconds. One speed for the whole run could not do both.
	local sweepStartZ = behindSpawn
	local approachDistance = math.abs(sweepStartZ - shredZ)
	local sweepDistance = math.abs(shredEndZ - sweepStartZ)
	-- 23.08.2026: 55 -> 62 (Pacing). The 2-player test wanted the machine a
	-- bit slower; since its speed is DERIVED from this number, the round
	-- length is the dial. The fallback only mirrors Pacing.
	local targetRound = Pacing.RoundSeconds.minefield or 62
	local sweepBudget = math.max(5, targetRound - SHRED_GRACE - APPROACH_SECONDS)
	local sweepSpeed = math.clamp(sweepDistance / sweepBudget,
		MIN_SHRED_SPEED, MAX_SHRED_SPEED)
	-- Never slower than the sweep. APPROACH_SECONDS is a BUDGET, not a
	-- duration: with the marker close to the field the budget would work out
	-- below the sweep speed and the machine would dawdle in, then accelerate
	-- once it mattered -- backwards, and it only appears if the marker moves.
	local approachSpeed = sweepSpeed
	if approachDistance > 0.5 then
		approachSpeed = math.max(sweepSpeed, approachDistance / APPROACH_SECONDS)
	end
	local shredTraversal = approachDistance / approachSpeed
		+ sweepDistance / sweepSpeed + SHRED_GRACE
	-- The runner's margin is the real difficulty dial, so it is measured and
	-- printed rather than felt out one playtest at a time.
	--
	-- Both sides are measured to the SAME event -- the exit -- and from the
	-- same instant, the start of the round. A first version compared the sweep
	-- DURATION against the runner's, which silently dropped the approach: the
	-- machine does not begin sweeping until it has arrived, so the runner has
	-- that time too. It under-reported the slack by the whole approach, and a
	-- difficulty dial that reads low makes you tune the game harder than you
	-- meant to.
	--
	-- Measured to the exit, not to shredEndZ: the machine passes the exit
	-- before it stops, and reaching the exit is what ends a runner's round.
	local approachTime = approachDistance / approachSpeed
	local sweepToExit = math.abs(R.exit.Position.Z - sweepStartZ) / sweepSpeed
	local machineReachesExit = SHRED_GRACE + approachTime + sweepToExit
	local runnerSeconds = math.abs(R.exit.Position.Z - R.spawn.Position.Z) / 7
	local runnerMargin = machineReachesExit - runnerSeconds
	-- A real failsafe now, not a second timer: it only ever fires if the
	-- machine somehow fails to reach the end it is driven towards.
	local failsafeTime = shredTraversal + 20
	print(("[DZ] compactor approach %.0f studs @ %.1f/s, sweep %.0f @ %.2f/s -> %.1f s round (target %.0f); runner margin %+.1f s")
		:format(approachDistance, approachSpeed, sweepDistance, sweepSpeed,
			shredTraversal, targetRound, runnerMargin))
	placeShred(shredZ, 0)
	if custom then publishShred(shredZ, 0) end
	shred.Parent = runtime

	-- Hauptschleife: Zellenerkennung, Fortschritt und der marschierende Compactor
	local t0 = os.clock()
	local lastTick = os.clock()
	local spin = 0
	local crushed = 0 -- 23.08.2026: mines the machine silently removed
	while os.clock() - t0 < failsafeTime do
		task.wait(0.05)
		-- C1.c: break out the moment the match aborts. Previously this loop
		-- only ended on all-done / crusher-past-exit / zero-members, so an
		-- abort ran on until the 150s failsafe.
		if not active() then break end
		local now = os.clock()
		local dt = now - lastTick
		lastTick = now
		-- Compactor bewegen (nach Schonfrist), Walzen drehen
		local speedNow = 0
		if now - t0 > SHRED_GRACE and (shredZ - shredEndZ) * g.dir < 0 then
			-- Approach speed until the machine reaches the players' line, sweep
			-- speed from there on.
			speedNow = ((shredZ - sweepStartZ) * g.dir < 0)
				and approachSpeed or sweepSpeed
			shredZ += g.dir * speedNow * dt
		end
		spin += dt * 6
		if custom then
			publishShred(shredZ, g.dir * speedNow)
		else
			placeShred(shredZ, spin)
		end
		local shredFront = shredZ + g.dir * 2
		-- 23.08.2026: Minen, die die Maschine ueberrollt, werden ZERDRUECKT,
		-- nicht gezuendet. Vorher ging jede ueberrollte Mine von selbst hoch;
		-- im 2-Spieler-Test war das eine Kette von Explosionen hinter den
		-- Laeufern, und weil explode() sein gorefx an den ganzen Raum schickt,
		-- hatte jeder Blut auf dem Schirm, ohne dass irgendwer etwas falsch
		-- gemacht haette. Eine zerdrueckte Mine ist einfach weg: nicht mehr
		-- scharf, kein explode(), kein BloodFX, kein gorefx, kein Klang, und
		-- sie kettet nichts mehr an (explode() prueft other.live). Zu
		-- verstecken gibt es nichts - eine Mine ist ein Server-Eintrag ohne
		-- Instanz (REQ-DZ-02); mit live=false faellt sie auch aus dem Sonar.
		-- Kettenreaktionen bleiben den Minen, die ein LAEUFER ausloest.
		-- 23.08.2026 (Gate): `not mn.armed` bleibt - eine Mine, auf die ein
		-- Laeufer schon getreten ist (Zuender laeuft, FUSE), wird von der
		-- Maschine NICHT entschaerft; sie geht hoch wie versprochen.
		for _, mn in mines do
			if mn.live and not mn.armed and (mn.pos.Z - shredFront) * g.dir < 0 then
				mn.live = false
				crushed += 1
			end
		end
		local liv = livingOf(room)
		local allDone = true
		for uid, ps in state do
			if not ps.done then
				local s = liv[uid]
				if not s then
					ps.done = true
				else
					allDone = false
					local pos = s.root.Position
					-- Fortschritt in Studs Richtung Exit
					local prog = (pos.Z - g.z0) * g.dir
					if prog > ps.progress then ps.progress = prog end
					-- crossing the exit line IS the win (see escapeRunner above);
					-- 1.5 studs of grace so STANDING IN THE GATE already counts
					-- (the user stood exactly on the line and nothing fired).
					if (pos.Z - R.exit.Position.Z) * g.dir >= -1.5 then
						local plr2 = Players:GetPlayerByUserId(uid)
						if plr2 then escapeRunner(plr2, ps) end
					end
					-- vom Compactor eingeholt? Sofort zerlegt. (Nie in der Schonfrist)
					if now - t0 > SHRED_GRACE and (pos.Z - shredFront) * g.dir < 0 then
						ps.done = true
						ps.cardAt = os.clock()
						BloodFX.shatter(s.char, nil, audienceOf(room))
						announce(room, { kind = "gorefx", pos = { pos.X, pos.Y, pos.Z }, power = 1.6 })
						s.hum.Health = 0
						-- MP-08 S5: der Compactor-Tod ist byteweise dieselbe Figur wie
						-- die zweite Mine oben -- Todeskarte, 3.2 s spaeter das
						-- spectate-Paket. Der Plan nennt nur die Minenzeile, aber es
						-- ist derselbe Fehler (B-01/B-08), also derselbe Timer.
						tellOne(uid, { kind = "announce", style = "death", seconds = 3.0,
							text = "PROCESSED." })
						if R.cam then
							task.delay(3.2, function()
								-- C1.d: never strand a lobby player's camera on
								-- the arena after the round was torn down.
								if not active() then return end
								tellOne(uid, { kind = "role", role = "spectate",
									watch = stillRunning(state, uid),
									pos = { R.cam.Position.X, R.cam.Position.Y, R.cam.Position.Z },
									look = { R.exit.Position.X, g.gTop, R.exit.Position.Z } })
							end)
						end
					else
						-- Zelle betreten?
						local col, row = cellOf(g, pos)
						local mine = mines[row .. ":" .. col]
						if mine and mine.live and not mine.armed then
							mine.armed = true
							task.delay(FUSE, function() explode(mine) end)
						end
					end
				end
			end
		end
		if allDone then break end
		if (shredZ - shredEndZ) * g.dir >= 0 then break end
		if #room.members == 0 then break end
	end
	print("[DZ] round over, elapsed=" .. math.floor((os.clock() - t0) * 10) / 10
		.. " crushed=" .. crushed)
	roundState.acceptInput = false

	-- An aborted round scores nothing: the plan discards an incomplete
	-- minigame's partial scores. Teardown is cleanup()'s job either way.
	if not active() then
		return scores
	end

	task.wait(2.4)

	-- WERTUNG. This is an ORDERING KEY, not a point total.
	--
	-- MachineFlow ranks players by this number and Scoring.distribute turns
	-- the ranking into the actual award, which is exactly 1700 across the
	-- minigame. So only the ORDER matters here, never the magnitude.
	--
	-- Banded, because the old formula could invert the order it was meant to
	-- express. A fourth escapee scored ESCAPE_POINTS + 0 while someone who
	-- died near the exit scored up to 40, and CLEANRUN_BONUS was worth 20 --
	-- enough to lift a later escapee above an earlier one. Reaching the exit
	-- first is the whole point of the minigame; it must not be losable to a
	-- bonus.
	--
	--   escaped       2000 + 1000 down to 2000, earlier is STRICTLY higher
	--   eliminated       0 ..  1000, by legitimate forward progress
	--   clean run       +1, a tiebreaker ONLY -- it can never cross a band
	local ESCAPE_BAND = 2000
	local ORDER_STEP = 100
	local fieldLen = g.rows * CELL
	for uid, ps in state do
		local sc
		if ps.escaped then
			-- Whoever reaches the exit sooner ranks above whoever reaches it
			-- later, with no way for the gap to close.
			sc = ESCAPE_BAND
				+ math.max(0, 1000 - ORDER_STEP * ((ps.escapeOrder or 1) - 1))
		else
			sc = math.floor(1000 * math.clamp((ps.progress or 0) / fieldLen, 0, 1))
		end
		-- Never a bonus, only a tiebreaker: it separates two players who are
		-- otherwise exactly level and cannot move anyone past a band.
		if not ps.usedScanner then sc += 1 end
		scores[uid] = sc
	end

	-- Round-complete card only. Player restore, runtime teardown, exit
	-- disconnect and the role reset all belong to cleanup(), which the
	-- wrapper below always runs exactly once.
	-- The "ROUND n COMPLETE." card is gone. The session owns round and
	-- minigame structure now -- RoomService carries roundIndex/roundCount and
	-- MachineFlow draws the Score stage after every minigame -- so a card
	-- announcing the same thing per round only delayed the next one.
	
	-- BLACK OUT BEFORE THE TELEPORT. cleanup() moves every player to the
	-- global SpawnLocation, which sits on the Baseplate far from the arena,
	-- and the next round teleports them back. Uncovered, that round trip is
	-- visible: escaped players are watching the others at that moment and see
	-- them pop onto the Baseplate.
	--
	-- An empty announce is opaque black on the client -- the same cover the
	-- death card already uses so "spawn is never seen". Dead Zone's round
	-- boundary never had one. The next round card replaces it, so nothing
	-- needs to clear it explicitly.
	--
	-- Guarded on the round still being live. An aborted match tears down on
	-- its own path and its players are already on their way back to the
	-- lobby; dropping an opaque cover on them there would blacken a screen
	-- nobody is going to clear, and the 0.6 s would be spent holding it.
	if active() then
		announce(room, { kind = "announce", text = "" })
		task.wait(0.6)
	end
	
	return scores
end

-- C1.e: every exit path - normal, cancelled, or thrown - runs cleanup exactly
-- once before returning. A thrown round yields zeroed scores rather than
-- propagating into MachineFlow's error path with no teardown.
-- #50: the MachineFlow watchdog task.cancel()s a hung round's thread, which
-- skips the guard below. abort() lets the watchdog run the same cleanup from
-- its own thread.
function Minefield.abort()
	local g = Minefield._guard
	Minefield._guard = nil
	if g and g.cleanup then pcall(g.cleanup) end
end

function Minefield.runRound(room, roundIndex)
	local guard = {}
	Minefield._guard = guard
	local ok, result = xpcall(function()
		return runRoundInner(room, roundIndex, guard)
	end, debug.traceback)
	Minefield._guard = nil
	if guard.cleanup then pcall(guard.cleanup) end
	if not ok then
		-- Teardown has already run, so it is safe to re-raise. Propagate the
		-- ORIGINAL traceback: MachineFlow's finalizer then sets outcome="error"
		-- and aborts the match. Cancellation is a normal return path and never
		-- arrives here - only genuine exceptions do.
		-- The first cut swallowed these and returned zeroed scores. That was
		-- wrong: MachineFlow saw a clean round, so a broken Dead Zone repeated
		-- the same throw for all 10 rounds (~45s of black screen) and then
		-- reported a final board of zeros with no player-visible error.
		warn("[DZ] round errored: " .. tostring(result))
		error(result, 0)
	end
	return result
end

return Minefield
