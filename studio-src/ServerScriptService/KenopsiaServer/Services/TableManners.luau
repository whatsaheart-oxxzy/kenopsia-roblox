--!nonstrict
-- CANTEEN PROTOCOL: Rhythmus-Essen, Machine-Party-Remake.
-- Der Server wuerfelt pro Runde EINEN Beatplan (16 Bissen, 4 Abschnitte) und
-- verteilt ihn an alle; gegessen wird auf den Beat (E / A-Taste / EAT-Button).
-- Perfect +-70ms, Good +-150ms, daneben = Miss. Drei schnelle Fehler fuellen
-- den Stressmesser: 1,2s Husten, Eingaben gesperrt. Wer alle 16 Portionen
-- schafft, kassiert den Abschlussbonus. Arena-Marker (optional, vom Hand-Bau):
-- workspace["Canteen"] mit "Seat1".."Seat4" und "Cameraplacement".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableManners = {}

local PERFECT = 0.07
local GOOD = 0.15
local SPAM_LOCK = 0.40
local COUGH_TIME = 1.2
local STRESS_WINDOW = 4.0   -- drei Misses innerhalb dieses Fensters = voller Messer
local BITES = 16
local LEAD_IN = 3.0         -- Sekunden zwischen Beatplan-Versand und erstem Beat
local COMPLETE_BONUS = 25

local current = nil
local TrialInput

local function refs()
	local cp = workspace:FindFirstChild("Canteen")
		or workspace:FindFirstChild("Canteen Protocol")
		or workspace:FindFirstChild("TableManners")
	if not cp then return nil end
	local seats = {}
	for i = 1, 4 do
		local s = cp:FindFirstChild("Seat" .. i) or cp:FindFirstChild("Seat0" .. i)
		if s then table.insert(seats, s) end
	end
	return { cp = cp, seats = seats, cam = cp:FindFirstChild("Cameraplacement") }
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

-- 16 Bissen in 4 Abschnitten: gleichmaessig / kurz-lang / falsche Pause / Finale.
-- Relativzeiten ab Beat 1; alle Spieler bekommen denselben Plan.
local function buildBeats()
	local beats = {}
	local t = 0
	local function push(gap)
		t += gap + (math.random(-4, 4) / 100)
		table.insert(beats, math.floor(t * 1000) / 1000)
	end
	table.insert(beats, 0)
	for _ = 1, 3 do push(1.6) end                 -- Abschnitt 1: gleichmaessig
	t += 0.6
	for _ = 1, 2 do push(0.8) push(2.0) end        -- Abschnitt 2: kurz / lang
	t += 0.6
	push(1.0) push(1.0) push(3.2) push(1.0)        -- Abschnitt 3: falsche Pause
	t += 0.4
	push(1.1) push(1.0) push(0.9) push(0.85)       -- Abschnitt 4: Finale zieht an
	return beats
end

function TableManners.init()
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
		if payload.trialId ~= "tablemanners" or payload.action ~= "bite" then return end
		local ps = st.state[player.UserId]
		if not ps or ps.done then return end
		local now = workspace:GetServerTimeNow()
		if now < st.planStart - 0.5 then return end
		if now < (ps.lockUntil or 0) then return end
		if now < (ps.lastPress or 0) + SPAM_LOCK then return end
		ps.lastPress = now
		-- naechster unkonsumierter Beat im Fenster?
		local bestIdx, bestDev
		for i, bt in st.beats do
			if not ps.consumed[i] then
				local dev = now - (st.planStart + bt)
				if math.abs(dev) <= GOOD and (not bestDev or math.abs(dev) < math.abs(bestDev)) then
					bestIdx, bestDev = i, dev
				end
			end
		end
		if bestIdx then
			ps.consumed[bestIdx] = true
			ps.hits += 1
			ps.devSum += math.abs(bestDev)
			local grade = math.abs(bestDev) <= PERFECT and "perfect" or "good"
			if grade == "perfect" then ps.perfects += 1 end
			if ps.hits >= BITES then
				ps.done = true
				ps.finishRel = now - st.planStart
				tellOne(player.UserId, { kind = "announce", text = "RATION CONSUMED. STAND BY." })
			end
			tellOne(player.UserId, { kind = "bite", grade = grade, idx = bestIdx, hits = ps.hits, stress = ps.stress })
		else
			-- daneben: Stress steigt, drei schnelle Fehler = Husten
			table.insert(ps.missTimes, now)
			local recent = 0
			for _, mt in ps.missTimes do
				if now - mt <= STRESS_WINDOW then recent += 1 end
			end
			ps.misses += 1
			ps.stress = math.min(recent / 3, 1)
			if ps.stress >= 1 then
				ps.lockUntil = now + COUGH_TIME
				ps.stress = 0
				ps.missTimes = {}
				tellOne(player.UserId, { kind = "cough", until_ = COUGH_TIME })
			else
				tellOne(player.UserId, { kind = "bite", grade = "miss", hits = ps.hits, stress = ps.stress })
			end
		end
	end)
end

function TableManners.runRound(room, roundIndex)
	local scores = {}
	for _, mm in room.members do scores[mm.userId] = 0 end
	local R = refs()

	announce(room, { kind = "announce", text = "EAT ON THE BEAT. DO NOT CHOKE." })
	task.wait(2.8)

	-- Sitzplaetze (falls Arena steht): Spieler einfrieren und platzieren
	local subjects = livingOf(room)
	local state = {}
	local n = 0
	for _, mm in room.members do
		local s = subjects[mm.userId]
		state[mm.userId] = {
			done = s == nil, hits = 0, perfects = 0, misses = 0,
			devSum = 0, stress = 0, consumed = {}, missTimes = {},
		}
		if s then
			s.hum.Health = s.hum.MaxHealth
			s.hum.WalkSpeed = 0
			s.char:SetAttribute("XBotMoves", "eat")
			s.char:SetAttribute("XBotCrawl", false)
			n += 1
			if R and R.seats[n] then
				local seat = R.seats[n]
				local anchor = seat:FindFirstChild("PlayerAnchor", true) or seat
				local pivot = anchor:IsA("BasePart") and anchor.CFrame or anchor:GetPivot()
				s.root.CFrame = pivot + Vector3.new(0, 3.2, 0)
			end
		end
	end

	-- feste Kamera auf den Tisch, solange die Arena steht
	if R and R.cam then
		local look = (#R.seats > 0 and R.seats[1]:IsA("BasePart")) and R.seats[1].Position
			or (R.cam.CFrame * CFrame.new(0, -2, -12)).Position
		for _, mm in room.members do
			tellOne(mm.userId, { kind = "role", role = "spectate",
				pos = { R.cam.Position.X, R.cam.Position.Y, R.cam.Position.Z },
				look = { look.X, look.Y, look.Z } })
		end
	end

	for c = 3, 1, -1 do
		announce(room, { kind = "count", n = c })
		task.wait(1)
	end
	announce(room, { kind = "go" })

	local beats = buildBeats()
	local planStart = workspace:GetServerTimeNow() + LEAD_IN
	current = { state = state, beats = beats, planStart = planStart }
	announce(room, { kind = "beatplan", startAt = planStart, beats = beats, total = BITES })
	print("[CP] go; members=" .. #room.members .. " beats=" .. #beats)

	-- Runde laeuft bis letzter Beat + Good-Fenster + Auslauf
	local roundEnd = planStart + beats[#beats] + GOOD + 1.2
	while workspace:GetServerTimeNow() < roundEnd do
		task.wait(0.1)
		local allDone = true
		for _, ps in state do
			if not ps.done then allDone = false break end
		end
		if allDone then break end
		if #room.members == 0 then break end
	end
	current = nil
	announce(room, { kind = "cpend" })

	-- Wertung: Portionen > Perfects > Tempo; Abschlussbonus fuer volle 16
	for uid, ps in state do
		local sc = ps.hits * 8 + ps.perfects * 4 - ps.misses * 2
		if ps.hits >= BITES and ps.finishRel then
			sc += COMPLETE_BONUS + math.max(0, math.floor(30 - ps.finishRel))
		end
		scores[uid] = math.max(0, sc)
	end

	-- letzter Platz bekommt die Entsorgungsansage (Shredder-Sequenz folgt mit Arena)
	local worstUid, worstScore
	local count = 0
	for uid, sc in scores do
		count += 1
		if not worstScore or sc < worstScore then worstUid, worstScore = uid, sc end
	end
	if count >= 2 and worstUid then
		tellOne(worstUid, { kind = "announce", style = "death", text = "WASTE DETECTED. DISPOSAL SCHEDULED." })
	end
	task.wait(2.2)

	-- Aufraeumen: Attribute zuruecksetzen; WalkSpeed regelt der Client via Rollen-Payload
	for _, s in livingOf(room) do
		s.char:SetAttribute("XBotMoves", "")
	end
	local MachineState = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")
	if MachineState then
		for _, mm in room.members do
			local plr = Players:GetPlayerByUserId(mm.userId)
			if plr then
				MachineState:FireClient(plr, { kind = "role", role = "none" })
			end
		end
	end
	return scores
end

return TableManners
