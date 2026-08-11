--!nonstrict
-- DEAD ZONE: gemeinsames Minenfeld, Machine-Party-Remake.
-- Minen sind unsichtbare Zellen unter dem Boden; ein Scanner-Puls (Taste F/Y)
-- pulst eine Welle und deckt Minen im Nahbereich persoenlich auf. Explosionen
-- toeten im Kernradius, werfen Ueberlebende in den Zombie-Crawl und lassen
-- Krater zurueck. Marker stammen aus dem von Hand gebauten workspace["Dead Zone"].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")

local BloodFX = require(script.Parent.BloodFX)

local Minefield = {}

local FAILSAFE_TIME = 150
local SHRED_SPEED = 4.5     -- langsamer als Gehen (7), schneller als Crawl (4.2):
                            -- wer laeuft, bleibt vorn; wer kriecht/troedelt, verliert
local SHRED_GRACE = 1.5
local MAX_RUNNER_SPEED = 7
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
local ESCAPE_POINTS = 100
local CLEANRUN_BONUS = 20

local activeByUser = {}
local arenaBusy = false
local TrialInput

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

function Minefield.runRound(room, roundIndex)
	local scores = {}
	for _, mm in room.members do scores[mm.userId] = 0 end
	local R = refs()
	if not R then
		warn("[DZ] Dead Zone Marker fehlen")
		return scores
	end
	local g = buildGrid(R)

	announce(room, { kind = "announce", text = "SCAN AHEAD. WATCH YOUR STEP." })
	task.wait(2.8)

	-- Laufzeitordner: Minen, Krater, Effekte
	local runtime = Instance.new("Folder")
	runtime.Name = "DZ_Runtime"
	runtime.Parent = R.dz

	-- Layout: sichere Pfade frei, Rest zufaellig vermint (unsichtbar, unterirdisch)
	local safe = carvePaths(g)
	local mines = {}
	for row = 3, g.rows - 1 do
		for col = 1, g.cols do
			if not safe[row .. ":" .. col] and math.random() < MINE_DENSITY then
				local c = cellCenter(g, col, row)
				local p = Instance.new("Part")
				p.Name = "Mine"
				p.Size = Vector3.new(1, 1, 1)
				p.CFrame = CFrame.new(c.X, g.gTop - 0.7, c.Z)
				p.Transparency = 1
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Parent = runtime
				mines[row .. ":" .. col] = { part = p, pos = Vector3.new(c.X, g.gTop, c.Z), live = true }
			end
		end
	end

	local state = {}
	local subjects = livingOf(room)
	local n = 0
	for _, mm in room.members do
		local s = subjects[mm.userId]
		state[mm.userId] = { done = s == nil, escaped = false, progress = 0, usedScanner = false }
		if s then
			s.hum.Health = s.hum.MaxHealth
			s.char:SetAttribute("XBotMoves", "scan")
			s.char:SetAttribute("XBotCrawl", false)
			s.char:SetAttribute("XBotScanning", false)
			local w = math.max(R.spawn.Size.X - 6, 8)
			local x = R.spawn.Position.X - w / 2 + w * ((n + 0.5) / math.max(#room.members, 1))
			n += 1
			local look = Vector3.new(x, R.spawn.Position.Y + 4, R.exit.Position.Z)
			s.root.CFrame = CFrame.lookAt(Vector3.new(x, R.spawn.Position.Y + 4, R.spawn.Position.Z), look)
		end
	end

	local MachineState = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")
	if MachineState then
		for _, mm in room.members do
			local plr = Players:GetPlayerByUserId(mm.userId)
			if plr then
				MachineState:FireClient(plr, { kind = "role", role = "runner", frozen = true, camDir = g.dir, camStyle = "top" })
			end
		end
	end
	for c = 3, 1, -1 do
		announce(room, { kind = "count", n = c })
		task.wait(1)
	end
	announce(room, { kind = "go" })

	local roundState = { state = state, mines = mines, grid = g, runtime = runtime }
	current = roundState
	print("[DZ] go; members=" .. #room.members)

	local craterTpl = ServerStorage.KenopsiaAssets.Props.Minefield:FindFirstChild("MF_Crater")

	local explode
	explode = function(mine)
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
					if d <= KILL_RADIUS then
						ps.done = true
						ps.cardAt = os.clock()
						-- sofortige Zerstueckelung: Koerper zerreisst am Ort der Mine
						BloodFX.kill(s.root.Position)
						BloodFX.shatter(s.char)
						s.hum.Health = 0
						tellOne(uid, { kind = "announce", style = "death", text = "YOU STEPPED WRONG." })
						if R.cam then
							task.delay(3.2, function()
								tellOne(uid, { kind = "role", role = "spectate",
									pos = { R.cam.Position.X, R.cam.Position.Y, R.cam.Position.Z },
									look = { R.exit.Position.X, g.gTop, R.exit.Position.Z } })
							end)
						end
					elseif d <= KNOCK_RADIUS then
						-- Ueberlebt, aber der KASTRIERER nimmt die Beine: ab jetzt Zombie-Crawl
						s.char:SetAttribute("XBotCrawl", true)
						BloodFX.maim(s.char)
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

	-- Exit
	local exitConn = R.exit.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		local plr = char and Players:GetPlayerFromCharacter(char)
		if not plr then
			char = char and char.Parent
			plr = char and Players:GetPlayerFromCharacter(char)
		end
		local ps = plr and state[plr.UserId]
		if ps and not ps.done then
			ps.done = true
			ps.escaped = true
			roundState.escapeCount = (roundState.escapeCount or 0) + 1
			ps.escapeOrder = roundState.escapeCount
			ps.cardAt = os.clock()
			tellOne(plr.UserId, { kind = "announce", text = "FIELD CLEARED." })
			local s = livingOf(room)[plr.UserId]
			if s then s.hum.WalkSpeed = 0 end
		end
	end)

	-- DER KASTRIERER: eine Shredderwand, die von hinten durchs Feld marschiert.
	-- Er ersetzt den Rundentimer - wer troedelt, wird eingeholt und zerlegt.
	local shredWidth = g.cols * CELL + 8
	local shred = Instance.new("Model")
	shred.Name = "Kastrierer"
	local housing = Instance.new("Part")
	housing.Name = "Housing"
	housing.Anchored = true
	housing.CanCollide = false
	housing.CanQuery = false
	housing.CanTouch = false
	housing.Material = Enum.Material.DiamondPlate
	housing.Color = Color3.fromRGB(58, 56, 52)
	housing.Size = Vector3.new(shredWidth, 7, 3)
	housing.Parent = shred
	local warnStrip = Instance.new("Part")
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
	local rollers = {}
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
	local function placeShred(zPos, spin)
		local baseCF = CFrame.new(g.x0 + g.cols * CELL / 2, g.gTop + 3.2, zPos)
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
	placeShred(shredZ, 0)
	shred.Parent = runtime

	-- Hauptschleife: Zellenerkennung, Fortschritt und der marschierende Kastrierer
	local t0 = os.clock()
	local lastTick = os.clock()
	local spin = 0
	while os.clock() - t0 < FAILSAFE_TIME do
		task.wait(0.05)
		local now = os.clock()
		local dt = now - lastTick
		lastTick = now
		-- Kastrierer bewegen (nach Schonfrist), Walzen drehen
		if now - t0 > SHRED_GRACE and (shredZ - shredEndZ) * g.dir < 0 then
			shredZ += g.dir * SHRED_SPEED * dt
		end
		spin += dt * 6
		placeShred(shredZ, spin)
		local shredFront = shredZ + g.dir * 2
		-- Minen, die die Maschine ueberrollt, gehen von selbst hoch
		for _, mn in mines do
			if mn.live and not mn.armed and (mn.pos.Z - shredFront) * g.dir < 0 then
				mn.armed = true
				task.delay(math.random() * 0.2, function() explode(mn) end)
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
					-- vom Kastrierer eingeholt? Sofort zerlegt. (Nie in der Schonfrist)
					if now - t0 > SHRED_GRACE and (pos.Z - shredFront) * g.dir < 0 then
						ps.done = true
						ps.cardAt = os.clock()
						BloodFX.shatter(s.char)
						announce(room, { kind = "gorefx", pos = { pos.X, pos.Y, pos.Z }, power = 1.6 })
						s.hum.Health = 0
						tellOne(uid, { kind = "announce", style = "death", text = "PROCESSED." })
						if R.cam then
							task.delay(3.2, function()
								tellOne(uid, { kind = "role", role = "spectate",
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
	print("[DZ] round over, elapsed=" .. math.floor((os.clock() - t0) * 10) / 10)
	current = nil
	exitConn:Disconnect()
	task.wait(2.4)

	-- Wertung: Ziel > Fluchtreihenfolge > Distanz; CleanRun-Bonus ohne Scanner
	local fieldLen = g.rows * CELL
	for uid, ps in state do
		local sc = 0
		if ps.escaped then
			sc = ESCAPE_POINTS + math.max(0, 30 - 10 * ((ps.escapeOrder or 1) - 1))
			if not ps.usedScanner then sc += CLEANRUN_BONUS end
		else
			sc = math.floor(40 * math.clamp((ps.progress or 0) / fieldLen, 0, 1))
		end
		scores[uid] = sc
	end

	-- Aufraeumen: Krater/Minen weg, Attribute zurueck, zurueck zum Spawn
	local spawnPos = workspace:FindFirstChild("SpawnLocation") and workspace.SpawnLocation.Position or Vector3.new(0, 5, 0)
	for uid, s in livingOf(room) do
		s.char:SetAttribute("XBotCrawl", false)
		s.char:SetAttribute("XBotScanning", false)
		s.char:SetAttribute("XBotMoves", "")
		s.root.CFrame = CFrame.new(spawnPos + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
	end
	runtime:Destroy()
	BloodFX.clear()
	if MachineState then
		local now = os.clock()
		for _, mm in room.members do
			local plr = Players:GetPlayerByUserId(mm.userId)
			if plr then
				local st = state[mm.userId]
				if not (st and st.cardAt and now - st.cardAt < 6) then
					MachineState:FireClient(plr, { kind = "announce", text = "ROUND " .. tostring(roundIndex or 1) .. " COMPLETE." })
				end
				MachineState:FireClient(plr, { kind = "role", role = "none" })
			end
		end
	end
	return scores
end

return Minefield
