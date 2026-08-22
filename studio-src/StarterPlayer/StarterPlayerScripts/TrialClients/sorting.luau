--!nonstrict
-- SORTING FLOOR client (P4.1, 23.08.2026). Renders what the server decided:
-- the item stream on the belt (pooled Parts moved on server time), the rule
-- board with its 0.5 s Hazard telegraph, station lamps, the HUD (rule, your
-- current item in words, window bar, strikes, count, timer) and the inputs:
-- Q = chute A (left), E = chute B (right), Space = pass; gamepad X / B / Y;
-- three touch buttons. The camera is the arena's fixed station view.
--
-- Contract: docs/MP-06-FRAMEWORK.md. REQ-IP-01: original id "sorting".
local M = {}

local kit = nil
local hud = nil
local ruleLabel, itemLabel, countLabel, windowMeter = nil, nil, nil, nil
local strikeDots = {}
local boardPart, boardGlow = nil, nil
local myStation = nil
local stream = {}        -- [station] = { items } (server times)
local live = {}          -- [itemId] = { part, band, item }
local decided = {}       -- [itemId] = true (sent, whatever the verdict)
local currentId = nil
local strikes, correct = 0, 0
local warnUntil = 0
local runtimeFolder = nil
-- arena frame, read off the floor slab at begin
local originX, originZ, beltTopY = 0, 0, 3
local startXW, mawXW = -28, 28

M.controlsText = {
	title = "SORTING FLOOR",
	sec1 = "RULE:", sec2 = "STRIKES:",
	lines = { "SORT A [Q]  /  B [E]", "PASS [Space]", "THE RULE CHANGES", "3 MISFILES = DROP" },
	Mobile = { "SORT A  /  B buttons", "PASS button", "THE RULE CHANGES", "3 MISFILES = DROP" },
	Console = { "SORT A [X]  /  B [B]", "PASS [Y]", "THE RULE CHANGES", "3 MISFILES = DROP" },
}

-- the grade while this trial runs (SimulationGrade reads it)
M.presentation = {
	grade = {
		Ambient = Color3.fromRGB(48, 46, 44),
		OutdoorAmbient = Color3.fromRGB(28, 26, 24),
		fog = { 40, 150, Color3.fromRGB(14, 12, 10) },
		tint = Color3.fromRGB(232, 226, 210),
		saturation = -0.4,
		quantise = false,
	},
}

local COLOURS = {
	red = Color3.fromRGB(200, 32, 32), green = Color3.fromRGB(58, 118, 52),
	blue = Color3.fromRGB(56, 84, 170), grey = Color3.fromRGB(140, 146, 150),
}
-- sizes read from the fixed camera 25 studs back: chunky on purpose
local SHAPES = {
	parcel = { "box", Vector3.new(2.2, 1.7, 2.2) }, can = { "cyl", Vector3.new(1.7, 2.0, 1.7) },
	bone = { "rod", Vector3.new(0.7, 0.7, 3.0) }, bottle = { "cyl", Vector3.new(1.3, 2.6, 1.3) },
	syringe = { "rod", Vector3.new(0.5, 0.5, 2.5) }, battery = { "box", Vector3.new(1.2, 2.0, 1.2) },
	jar = { "box", Vector3.new(1.7, 1.9, 1.7) }, fruit = { "ball", Vector3.new(1.9, 1.9, 1.9) },
}
local APPROACH = 3.0 -- seconds an item is on the belt before it reaches the station
local EXIT = 2.0     -- seconds from the station to the maw

function M.init(k)
	kit = k
end

local function arenaPart(name)
	local a = kit.arena()
	return a and a:FindFirstChild(name, true) or nil
end

local stationXCache = {}
local function stationX(s)
	if stationXCache[s] then return stationXCache[s] end
	local trap = arenaPart("Trap" .. tostring(s))
	if trap then stationXCache[s] = trap.Position.X end
	return stationXCache[s]
end

-- ITEMS ON THE BELT ----------------------------------------------------------------
local function itemFolder()
	if runtimeFolder and runtimeFolder.Parent then return runtimeFolder end
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "SortingItems_Local"
	runtimeFolder.Parent = workspace
	return runtimeFolder
end

local function plainPart(name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.Parent = itemFolder()
	return p
end

local function makeItem(item)
	local spec = SHAPES[item.kind] or SHAPES.parcel
	local size = spec[2]
	local p = plainPart("Item_" .. item.id, size, COLOURS[item.colour] or COLOURS.grey)
	if spec[1] == "cyl" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(size.Y, size.X, size.Z) -- cylinder axis is X; stand it up later
	elseif spec[1] == "ball" then
		p.Shape = Enum.PartType.Ball
	end
	local band = nil
	if item.sealed then
		band = plainPart("Seal", Vector3.new(size.X + 0.1, 0.18, size.Z + 0.1), kit.palette.world.Bone, Enum.Material.Neon)
	end
	return { part = p, band = band, item = item, height = size.Y, cyl = spec[1] == "cyl" }
end

-- world X of an item at server time `now`, and whether it is on the belt at all
local function itemX(item, now, sx)
	if now < item.arriveAt then
		local a = 1 - math.clamp((item.arriveAt - now) / APPROACH, 0, 1)
		return startXW + (sx - startXW) * a, a > 0
	elseif now <= item.leaveAt then
		return sx, true
	else
		local a = math.clamp((now - item.leaveAt) / EXIT, 0, 1)
		return sx + (mawXW - sx) * a, a < 1
	end
end

local function stepItems()
	local now = kit.serverNow()
	local mine = nil
	for s, list in pairs(stream) do
		local sx = stationX(s)
		if sx then
			for _, item in ipairs(list) do
				local onBelt = now >= item.arriveAt - APPROACH and now <= item.leaveAt + EXIT
				local rec = live[item.id]
				if onBelt then
					if not rec then
						rec = makeItem(item)
						live[item.id] = rec
					end
					local x, shown = itemX(item, now, sx)
					local y = beltTopY + rec.height / 2 + 0.05
					local cf = CFrame.new(x, y, originZ)
					if rec.cyl then cf = cf * CFrame.Angles(0, 0, math.pi / 2) end
					rec.part.CFrame = cf
					rec.part.Transparency = shown and 0 or 1
					if rec.band then
						rec.band.CFrame = CFrame.new(x, beltTopY + rec.height - 0.04, originZ)
						rec.band.Transparency = shown and 0 or 1
					end
				elseif rec then
					rec.part:Destroy()
					if rec.band then rec.band:Destroy() end
					live[item.id] = nil
				end
				if s == myStation and not decided[item.id] and now >= item.arriveAt and now <= item.leaveAt then
					mine = item
				end
			end
		end
	end
	-- HUD: the item at MY station right now, in words (readable on a phone)
	if mine then
		if currentId ~= mine.id then
			currentId = mine.id
			kit.sfx("Click")
		end
		if itemLabel then
			itemLabel.Text = string.upper(mine.kind) .. "  |  " .. string.upper(mine.colour) .. "  |  " .. (mine.sealed and "SEALED" or "OPEN")
		end
		if windowMeter then
			windowMeter.set((mine.leaveAt - now) / math.max(0.01, mine.leaveAt - mine.arriveAt))
		end
	else
		currentId = nil
		if itemLabel then itemLabel.Text = "--" end
		if windowMeter then windowMeter.set(0) end
	end
	-- board telegraph: Hazard flicker for the 0.5 s before a rule change
	if boardGlow then
		local flicker = now < warnUntil and (math.floor(now * 12) % 2 == 0)
		boardGlow.Transparency = flicker and 0.05 or 0.6
	end
end

-- INPUT --------------------------------------------------------------------------
local function sendSort(chute)
	if not currentId or decided[currentId] then return end
	if kit.send("sort", { itemId = currentId, chute = chute }, 0.1) then
		decided[currentId] = true
	end
end

local function sendPass()
	if not currentId or decided[currentId] then return end
	if kit.send("pass", { itemId = currentId }, 0.1) then
		decided[currentId] = true
	end
end

-- HUD ----------------------------------------------------------------------------
local function renderStrikes()
	for i, dot in ipairs(strikeDots) do
		dot.BackgroundColor3 = i <= strikes and kit.palette.DANGER or kit.palette.DIM
	end
	if countLabel then countLabel.Text = ("SORTED %02d"):format(correct) end
end

local function buildHud()
	hud = kit.hud()
	ruleLabel = kit.label(hud, { name = "Rule", text = "", textSize = 30, color = kit.palette.PHOSPHOR,
		size = UDim2.new(0, 760, 0, 40), pos = UDim2.new(0.5, 0, 0, 22) })
	kit.timer(nil, hud, { pos = UDim2.new(0.5, 0, 0, 66), textSize = 22 })
	local panel = kit.panel(hud, UDim2.new(0, 520, 0, 96), UDim2.new(0.5, 0, 1, -150))
	panel.AnchorPoint = Vector2.new(0.5, 0)
	kit.label(panel, { name = "At", text = "AT YOUR STATION", textSize = 14, color = kit.palette.DIM,
		size = UDim2.new(1, 0, 0, 18), pos = UDim2.new(0.5, 0, 0, 6) })
	itemLabel = kit.label(panel, { name = "Item", text = "--", textSize = 26, color = kit.palette.AMBER,
		size = UDim2.new(1, -20, 0, 32), pos = UDim2.new(0.5, 0, 0, 26) })
	windowMeter = kit.meter(panel, { name = "Window", size = UDim2.new(1, -40, 0, 8), pos = UDim2.new(0.5, 0, 0, 66),
		color = kit.palette.PHOSPHOR, anchor = Vector2.new(0.5, 0) })
	countLabel = kit.label(hud, { name = "Count", text = "SORTED 00", textSize = 20, color = kit.palette.IDLE,
		size = UDim2.new(0, 200, 0, 24), pos = UDim2.new(0, 24, 1, -60), anchor = Vector2.new(0, 0), align = "Left" })
	strikeDots = {}
	for i = 1, 3 do
		local d = Instance.new("Frame")
		d.Name = "Strike" .. i
		d.Size = UDim2.new(0, 18, 0, 18)
		d.Position = UDim2.new(1, -24 - (3 - i) * 26, 1, -60)
		d.AnchorPoint = Vector2.new(1, 0)
		d.BackgroundColor3 = kit.palette.DIM
		d.BorderSizePixel = 0
		d.ZIndex = hud.ZIndex + 1
		d.Parent = hud
		strikeDots[i] = d
	end
	local pad = kit.pad()
	kit.button(pad, "Btn_A", "A", UDim2.new(0.5, -130, 1, -40), kit.palette.SAFE, function() sendSort("A") end)
	kit.button(pad, "Btn_PASS", "PASS", UDim2.new(0.5, 0, 1, -40), kit.palette.IDLE, sendPass)
	kit.button(pad, "Btn_B", "B", UDim2.new(0.5, 130, 1, -40), kit.palette.WARN, function() sendSort("B") end)
	kit.bindKey("sortA", { Enum.KeyCode.Q, Enum.KeyCode.ButtonX }, function() sendSort("A") end)
	kit.bindKey("sortB", { Enum.KeyCode.E, Enum.KeyCode.ButtonB }, function() sendSort("B") end)
	kit.bindKey("pass", { Enum.KeyCode.Space, Enum.KeyCode.ButtonY }, sendPass)
end

local function setRule(text)
	if ruleLabel then ruleLabel.Text = text or "" end
	if not boardPart then boardPart = arenaPart("Board") end
	if boardPart then
		local gui = boardPart:FindFirstChild("RuleGui")
		if not gui then
			gui = Instance.new("SurfaceGui")
			gui.Name = "RuleGui"
			gui.Face = Enum.NormalId.Front -- -Z: the side the sorters look at
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0
			local l = Instance.new("TextLabel")
			l.Name = "Text"
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, 0, 1, 0)
			l.Font = Enum.Font.Code
			l.TextScaled = true
			l.TextColor3 = Color3.fromRGB(24, 20, 16)
			l.Parent = gui
			gui.Parent = boardPart
		end
		gui.Text.Text = text or ""
	end
end

function M.onPacket(p)
	if not kit then return end
	if p.kind == "trial" then
		if p.ev == "begin" then
			stream, live, decided, stationXCache = {}, {}, {}, {}
			strikes, correct, currentId, warnUntil = 0, 0, nil, 0
			local a = kit.arena()
			local floor = a and a:FindFirstChild("Floor", true)
			if floor then
				originX, originZ = floor.Position.X, floor.Position.Z
				beltTopY = floor.Position.Y + floor.Size.Y / 2 + 3
			end
			startXW, mawXW = originX - 28, originX + 28
			local cam = a and a:FindFirstChild("Cam", true)
			if cam then kit.camera.fixed(cam.CFrame) end
			boardPart = arenaPart("Board")
			boardGlow = arenaPart("BoardGlow")
			buildHud()
			renderStrikes()
			setRule(p.rule)
			kit.onHeartbeat(stepItems)
		elseif p.ev == "station" then
			myStation = p.station
		elseif p.ev == "so_stream" then
			stream = {}
			if p.startAt then startXW = originX + p.startAt end
			if p.mawAt then mawXW = originX + p.mawAt end
			for s, list in pairs(p.stations or {}) do
				stream[tonumber(s) or s] = list
			end
		elseif p.ev == "so_warn" then
			warnUntil = kit.serverNow() + 0.5
			kit.sfx("Warning")
		elseif p.ev == "so_rule" then
			warnUntil = 0
			setRule(p.rule)
		elseif p.ev == "so_result" then
			-- a pass clears the item early and counts nothing
			if not p.pass then
				if p.ok then
					correct = p.correct or (correct + 1)
					kit.sfx("Submit")
				else
					strikes = p.strikes or (strikes + 1)
					kit.sfx("Reject")
					kit.edgeGlow(kit.palette.DANGER, 0.35, 0.5)
				end
				renderStrikes()
			end
		elseif p.ev == "so_lamp" then
			local lamp = arenaPart("Lamp" .. tostring(p.station))
			if lamp then
				if p.state == "ok" then
					kit.flash(lamp, kit.palette.world.Sodium, 0.25)
				elseif p.state == "bad" then
					kit.flash(lamp, kit.palette.world.Hazard, 0.6)
				else
					kit.flash(lamp, kit.palette.world.Steel, 0.2)
				end
			end
		elseif p.ev == "so_strike" and p.drop then
			local lamp = arenaPart("Lamp" .. tostring(p.station))
			if lamp then kit.flash(lamp, kit.palette.world.Signal, 0.7) end
			kit.sfx("Warning")
			if p.userId == kit.player.UserId then
				kit.card("STAND CLEAR.", "death")
			end
		elseif p.ev == "out" then
			kit.card(p.text)
		end
	elseif p.kind == "go" then
		kit.movement.freeze()
	end
end

function M.onEnd()
	for _, rec in pairs(live) do
		if rec.part then rec.part:Destroy() end
		if rec.band then rec.band:Destroy() end
	end
	if runtimeFolder then
		runtimeFolder:Destroy()
		runtimeFolder = nil
	end
	live, stream, decided, stationXCache = {}, {}, {}, {}
	hud, ruleLabel, itemLabel, countLabel, windowMeter = nil, nil, nil, nil, nil
	strikeDots = {}
	boardPart, boardGlow, myStation, currentId = nil, nil, nil, nil
end

return M
