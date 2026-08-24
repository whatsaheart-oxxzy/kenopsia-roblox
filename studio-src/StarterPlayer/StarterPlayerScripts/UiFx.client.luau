--!nonstrict
-- UI FX -- the CRT glass over the Machine (P2.2, 22.08.2026).
--
-- Lives in its OWN ScreenGui. Roblox caches a Gui's render geometry and drops
-- the whole cache when ANY descendant changes; KenopsiaMachine has 520
-- descendants, so every animated pixel in there re-rasterises all of them.
-- Everything that moves on the glass -- the refresh band, the interference
-- blip -- lives here instead, and nothing here ever touches the Machine's tree.
--
-- Honours GuiService.ReducedMotionEnabled (no band, no blip) and the player
-- attribute KenopsiaCRT (false = glass off; the settings panel sets it).
--
-- P2.2 (23.08.2026): plus the UI sound bus + CRT hum (6), the Bayer dither
-- screen transition (7), the phosphor glow (8) and the Selection idle
-- oscillators (9). The ONE exception to "never touch the Machine's tree" is
-- the glow: a UIStroke and an echo label per headline, built once at boot;
-- the echo only changes when its label does, which re-rasterises anyway.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- P2.2 (23.08.2026) UI SOUND BUS: one SoundGroup for every UI cue -- the
-- click / submit pools and typewriter blips (KenopsiaClient looks it up by
-- name at call time) and the CRT hum below -- so the whole bus has one fader.
-- Built first so it exists before the client's first sfx().
local uiGroup = SoundService:FindFirstChild("KenopsiaUI")
if not uiGroup then
	uiGroup = Instance.new("SoundGroup")
	uiGroup.Name = "KenopsiaUI"
	uiGroup.Volume = 1
	uiGroup.Parent = SoundService
end

-- 64x64 tile with the same 8-px period (4 clear rows, 4 rows black at 30 %):
-- Roblox draws ScaleType.Tile as one quad per tile, so the 8-px tile was
-- ~40k quads on a phone screen; this one is 64x fewer (perf, 22.08.2026).
local SCANLINE = "rbxassetid://75481537065425"
-- P1.5: band / blip cadence from the feel bible.
local Feel = require(game:GetService("ReplicatedStorage"):WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Config"):WaitForChild("FeelConfig"))
local PHOSPHOR = Color3.fromHex("78FFAA")

local gui = Instance.new("ScreenGui")
gui.Name = "KenopsiaMachine_Overlay"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 60 -- above KenopsiaMachine (50), below the loading bridge (100)
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- 1) scanlines: one tiled, nearest-neighbour image. Static: zero per-frame cost.
local scan = Instance.new("ImageLabel")
scan.Name = "Scanlines"
scan.BackgroundTransparency = 1
scan.Image = SCANLINE
scan.ImageTransparency = 0.55 -- 23.08.2026: user call, lighter lines
scan.ScaleType = Enum.ScaleType.Tile
scan.TileSize = UDim2.fromOffset(64, 64)
scan.ResampleMode = Enum.ResamplerMode.Pixelated
scan.Size = UDim2.fromScale(1, 1)
scan.ZIndex = 2
scan.Parent = gui

-- 2) vignette: four edge gradients, static.
local function edge(name, pos, size, rotation)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.Position = pos
	f.Size = size
	f.ZIndex = 1
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	f.Parent = gui
end
edge("VignetteTop", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.14), 90)
edge("VignetteBottom", UDim2.fromScale(0, 0.86), UDim2.fromScale(1, 0.14), -90)
edge("VignetteLeft", UDim2.fromScale(0, 0), UDim2.fromScale(0.08, 1), 0)
edge("VignetteRight", UDim2.fromScale(0.92, 0), UDim2.fromScale(0.08, 1), 180)

-- 3) refresh band: a faint bright band sweeps top-to-bottom for 2 s, then the
--    glass is still for 8 s (the CSS-CRT timing: the silence is what sells it).
local band = Instance.new("Frame")
band.Name = "RefreshBand"
band.BackgroundColor3 = PHOSPHOR
band.BackgroundTransparency = 0.8
band.BorderSizePixel = 0
band.Size = UDim2.new(1, 0, 0, 110)
band.Position = UDim2.new(0, 0, 0, -120)
band.ZIndex = 3
local bandGradient = Instance.new("UIGradient")
bandGradient.Rotation = 90
bandGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 1),
})
bandGradient.Parent = band
band.Parent = gui

-- 4) interference blip: a 2-px bright line at a random height for 80 ms,
--    every 8-20 s. Decorrelated from the band so the two never fall in step.
local blip = Instance.new("Frame")
blip.Name = "Blip"
blip.BackgroundColor3 = PHOSPHOR
blip.BackgroundTransparency = 0.45
blip.BorderSizePixel = 0
blip.Size = UDim2.new(1, 0, 0, 2)
blip.Visible = false
blip.ZIndex = 3
blip.Parent = gui

-- 4b) dither card (P2.2): the tiled Bayer ImageLabel the screen transition
--    steps through (section 7 below). Over everything else on the glass.
local dither = Instance.new("ImageLabel")
dither.Name = "Dither"
dither.BackgroundColor3 = Color3.new(0, 0, 0)
dither.BackgroundTransparency = 1
dither.BorderSizePixel = 0
dither.ImageColor3 = Color3.new(0, 0, 0)
dither.ScaleType = Enum.ScaleType.Tile
dither.TileSize = UDim2.fromOffset(Feel.Dither.TilePx, Feel.Dither.TilePx)
dither.ResampleMode = Enum.ResamplerMode.Pixelated
dither.Size = UDim2.fromScale(1, 1)
dither.Visible = false
dither.ZIndex = 5
dither.Parent = gui
-- the four tiles are fetched now, not on the first swap (a 4-frame
-- transition cannot wait for an asset)
task.spawn(function()
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(Feel.Dither.Tiles)
	end)
end)

gui.Parent = playerGui

local function crtOn()
	return player:GetAttribute("KenopsiaCRT") ~= false
end

local function motionOk()
	return crtOn() and not GuiService.ReducedMotionEnabled
		and player:GetAttribute("KenopsiaReduceFlicker") ~= true
end

-- P2.2: the idle oscillators (band, blip, bracket, uptime) are Selection-screen
-- life. None runs while a trial is active or while no live screen is visible.
-- Lead 23.08.: the band and the blip breathe on every Machine screen in the
-- lobby (players sit on Info/READY the longest); the bracket and the uptime
-- counter belong to the Selection grid only (selectionOk below).
local LIVE_SCREENS = { "Selection", "Info", "Status", "Score" }
local function liveOk()
	if (player:GetAttribute("KenopsiaActiveTrial") or "") ~= "" then return false end
	local machine = playerGui:FindFirstChild("KenopsiaMachine")
	if not machine or not machine.Enabled then return false end
	for _, n in ipairs(LIVE_SCREENS) do
		local s = machine:FindFirstChild(n)
		if s and s.Visible then return true end
	end
	return false
end
local function selectionOk()
	if not liveOk() then return false end
	local machine = playerGui:FindFirstChild("KenopsiaMachine")
	local sel = machine and machine:FindFirstChild("Selection")
	return sel ~= nil and sel.Visible
end

local function applyToggle()
	local on = crtOn()
	scan.Visible = on
	for _, n in ipairs({ "VignetteTop", "VignetteBottom", "VignetteLeft", "VignetteRight" }) do
		local f = gui:FindFirstChild(n)
		if f then f.Visible = on end
	end
	-- phones read through a lighter glass: the lines must not eat the 10-px text
	local machine = playerGui:FindFirstChild("KenopsiaMachine")
	local platform = machine and machine:GetAttribute("Platform")
	scan.ImageTransparency = (platform == "Mobile") and 0.7 or 0.55
end
applyToggle()
player:GetAttributeChangedSignal("KenopsiaCRT"):Connect(applyToggle)
task.defer(function()
	local machine = playerGui:WaitForChild("KenopsiaMachine", 30)
	if machine then
		applyToggle()
		machine:GetAttributeChangedSignal("Platform"):Connect(applyToggle)
	end
end)

-- 5) the Roblox chat window (P0.4, decided 22.08.2026): the default chat
--    stays ON in the lobby / Machine screens and is hidden while a trial
--    runs. Observed here rather than in SimulationGrade because that script's
--    apply/restore is gated by the SIM FILTER setting and the chat must not
--    follow a look toggle. pcall-guarded: a place without the TextChatService
--    configuration objects (legacy chat) simply keeps its chat.
local TextChatService = game:GetService("TextChatService")
local chatHidden = false
local function setChatEnabled(on)
	pcall(function()
		local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
		if window then window.Enabled = on end
		local input = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		if input then input.Enabled = on end
	end)
end
local function applyChat()
	local inTrial = (player:GetAttribute("KenopsiaActiveTrial") or "") ~= ""
	if inTrial == chatHidden then return end
	chatHidden = inTrial
	setChatEnabled(not inTrial)
end
player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(applyChat)
task.defer(applyChat)

-- 24.08.2026 (user: "real PS1 graphics"): while a trial runs, a full-screen
-- ordered-dither GRAIN sits over the world -- the same Bayer family the
-- screen swaps use, tiled at 8 px, barely-there alpha. Off with the CRT
-- toggle and under Reduced Motion it stays static (it never animates anyway).
do
	local grain = Instance.new("ImageLabel")
	grain.Name = "TrialGrain"
	grain.Size = UDim2.fromScale(1, 1)
	grain.BackgroundTransparency = 1
	grain.Image = "rbxassetid://121598984043867"
	grain.ImageTransparency = 0.93
	grain.ScaleType = Enum.ScaleType.Tile
	grain.TileSize = UDim2.fromOffset(8, 8)
	grain.ResampleMode = Enum.ResamplerMode.Pixelated
	grain.ZIndex = 3
	grain.Visible = false
	grain.Parent = gui
	local function applyGrain()
		grain.Visible = crtOn() and (player:GetAttribute("KenopsiaActiveTrial") or "") ~= ""
	end
	player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(applyGrain)
	player:GetAttributeChangedSignal("KenopsiaCRT"):Connect(applyGrain)
	task.defer(applyGrain)
end

task.spawn(function()
	while gui.Parent do
		task.wait(Feel.Overlay.BandIdle)
		if motionOk() and liveOk() then
			local cam = workspace.CurrentCamera
			local vh = cam and cam.ViewportSize.Y or 720
			band.Position = UDim2.new(0, 0, 0, -120)
			local tw = TweenService:Create(band, TweenInfo.new(Feel.Overlay.BandSweep, Feel.easing(Feel.Easing.Machine, "Out")), {
				Position = UDim2.new(0, 0, 0, vh + 10),
			})
			tw:Play()
			tw.Completed:Wait()
		end
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(Feel.Overlay.BlipMin + math.random() * (Feel.Overlay.BlipMax - Feel.Overlay.BlipMin))
		if motionOk() and liveOk() then
			blip.Position = UDim2.new(0, 0, math.random(), 0)
			blip.Visible = true
			task.wait(Feel.Overlay.BlipHold)
			blip.Visible = false
		end
	end
end)

-- 6) CRT HUM (P2.2): a low loop on the UI bus. Source: a Sound named
--    Feel.Hum.SoundName under SoundService.KenopsiaAudio (Ambience first, then
--    anywhere below); with none in the place the placeholder id is used and
--    one warn says so. Ducked by DuckDb over DuckSeconds while an announce
--    line or a round card is up (observed through their Visible flags -- the
--    Machine tree is only READ here), released the same way. Off while a
--    trial runs and while UI SOUND is off.
local hum = nil
local humDucked = false
local function humSource()
	local root = SoundService:FindFirstChild("KenopsiaAudio")
	if not root then return nil end
	local amb = root:FindFirstChild("Ambience")
	local s = amb and amb:FindFirstChild(Feel.Hum.SoundName)
	if not s then s = root:FindFirstChild(Feel.Hum.SoundName, true) end
	if s and s:IsA("Sound") and s.SoundId ~= "" then return s end
	return nil
end
local function ensureHum()
	if hum then return hum end
	local s = Instance.new("Sound")
	s.Name = "CrtHum"
	local src = humSource()
	if src then
		s.SoundId = src.SoundId
	else
		s.SoundId = Feel.Hum.PlaceholderId > 0 and ("rbxassetid://" .. tostring(Feel.Hum.PlaceholderId)) or ""
		warn(("[UiFx] no CRT hum asset (SoundService.KenopsiaAudio.Ambience.%s) - placeholder id %d, hum silent")
			:format(Feel.Hum.SoundName, Feel.Hum.PlaceholderId))
	end
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = uiGroup
	s.Parent = SoundService
	hum = s
	return s
end
local function humTarget()
	if player:GetAttribute("KenopsiaUiSound") == false then return 0 end
	if (player:GetAttribute("KenopsiaActiveTrial") or "") ~= "" then return 0 end
	return Feel.Hum.Volume * (humDucked and Feel.dbGain(Feel.Hum.DuckDb) or 1)
end
local function applyHum()
	local s = ensureHum()
	local target = humTarget()
	if target > 0 and s.SoundId ~= "" and not s.IsPlaying then s:Play() end
	TweenService:Create(s, TweenInfo.new(Feel.Hum.DuckSeconds, Feel.easing(Feel.Easing.Machine, "Out")), { Volume = target }):Play()
	if target == 0 then
		task.delay(Feel.Hum.DuckSeconds + 0.05, function()
			if humTarget() == 0 and s.IsPlaying then s:Stop() end
		end)
	end
end
player:GetAttributeChangedSignal("KenopsiaUiSound"):Connect(applyHum)
player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(applyHum)
task.defer(applyHum)

-- 7) DITHER TRANSITION (P2.2): KenopsiaClient.hideAll() bumps the attribute
--    DitherSeq on the KenopsiaMachine gui at every screen swap. The swap is a
--    hard cut (timing bible); this re-paints the new screen through the four
--    Bayer tiles, densest first, one per frame of the Step.Fps grid -- never
--    a smooth alpha tween. ReduceFlicker / ReducedMotion: a plain black card
--    held ReducedSteps frames instead (the 2-step cut). A swap landing
--    mid-sequence restarts it (generation counter).
local ditherGen = 0
local function ditherReduced()
	return GuiService.ReducedMotionEnabled or player:GetAttribute("KenopsiaReduceFlicker") == true
end
local function runDither()
	ditherGen += 1
	local gen = ditherGen
	local D = Feel.Dither
	local hold = Feel.stepSeconds()
	-- Review 23.08.: CRT off means clean glass -- no dither card at all.
	if not crtOn() then
		dither.Visible = false
		return
	end
	if ditherReduced() then
		dither.Image = ""
		dither.BackgroundTransparency = 0
		dither.Visible = true
		for _ = 1, D.ReducedSteps do
			task.wait(hold)
			if gen ~= ditherGen then return end
		end
	else
		dither.BackgroundTransparency = 1
		dither.Visible = true
		for i = D.Steps, 1, -1 do
			dither.Image = D.Tiles[i] or D.Tiles[#D.Tiles]
			task.wait(hold)
			if gen ~= ditherGen then return end
		end
	end
	dither.Visible = false
end

-- 8) PHOSPHOR GLOW (P2.2): built ONCE per headline label from the name list:
--    a 1-px phosphor UIStroke on the glyphs plus an echo TextLabel one pixel
--    down-right at lower alpha. The echo is a CHILD of its label (full size,
--    offset EchoOffsetPx): it inherits Visible, Position, Size and the
--    UIScale MachineLayout parents into CountText / HitMark, and since it is
--    the text's own colour the overlap composites to nothing -- only the
--    1-px rim shows. It mirrors the label through property-changed signals
--    (Text, MaxVisibleGraphemes for the typewriter, TextSize for the 3-2-1
--    punch, TextTransparency for the fades, ...) -- no per-frame work. Both
--    transparencies are multiplied by GuiService.PreferredTransparency; the
--    CRT toggle switches the glow off.
local GLOW_LABELS = { "Info.NextLabel", "RoundCard.Title", "Announce.Line", "CountText", "HitMark", "Score.ScoreName", "Briefing.Title" }
local MIRRORED = { "Text", "TextColor3", "TextSize", "TextTransparency", "MaxVisibleGraphemes",
	"TextXAlignment", "TextYAlignment", "TextWrapped", "TextScaled", "FontFace", "RichText", "LineHeight" }
local glows = {} -- { label = TextLabel, stroke = UIStroke | nil, echo = TextLabel }
local function preferredTransparency()
	local ok, v = pcall(function() return GuiService.PreferredTransparency end)
	return (ok and type(v) == "number") and v or 1
end
local function applyGlow(g)
	local on = crtOn()
	local pt = preferredTransparency()
	local alpha = 1 - g.label.TextTransparency
	if g.stroke then
		g.stroke.Enabled = on
		g.stroke.Transparency = 1 - alpha * (1 - Feel.Glow.StrokeTransparency * pt)
	end
	g.echo.TextTransparency = 1 - alpha * (1 - Feel.Glow.EchoTransparency * pt)
	g.echo.Visible = on
end
local function mirrorGlow(g, prop)
	local label, echo = g.label, g.echo
	if prop == "TextTransparency" then
		applyGlow(g)
	elseif prop == "TextColor3" then
		-- the glow is the text's own light: red verdicts and death lines glow red
		echo.TextColor3 = label.TextColor3
		if g.stroke then g.stroke.Color = label.TextColor3 end
	else
		echo[prop] = label[prop]
	end
end
local function buildGlow(label)
	if label:FindFirstChild("PhosphorStroke") or label:FindFirstChild("Glow") then return end
	-- A label that already carries a UIStroke (HitMark's dark outline) keeps
	-- it: two strokes on one object are undefined, so that one gets the echo only.
	local stroke = nil
	if not label:FindFirstChildOfClass("UIStroke") then
		stroke = Instance.new("UIStroke")
		stroke.Name = "PhosphorStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Color = PHOSPHOR
		stroke.Thickness = Feel.Glow.StrokeThickness
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
		stroke.Parent = label
	end
	local echo = Instance.new("TextLabel")
	echo.Name = "Glow"
	echo.BackgroundTransparency = 1
	echo.BorderSizePixel = 0
	echo.Position = UDim2.fromOffset(Feel.Glow.EchoOffsetPx, Feel.Glow.EchoOffsetPx)
	echo.Size = UDim2.fromScale(1, 1)
	echo.ZIndex = label.ZIndex
	local g = { label = label, stroke = stroke, echo = echo }
	for _, prop in ipairs(MIRRORED) do
		mirrorGlow(g, prop)
		label:GetPropertyChangedSignal(prop):Connect(function() mirrorGlow(g, prop) end)
	end
	echo.Parent = label
	glows[#glows + 1] = g
	applyGlow(g)
end
local function applyGlowAll()
	for _, g in ipairs(glows) do applyGlow(g) end
end
player:GetAttributeChangedSignal("KenopsiaCRT"):Connect(applyGlowAll)
pcall(function()
	GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(applyGlowAll)
end)

-- 9) IDLE OSCILLATORS (P2.2): the breathing bracket around the Selection tile
--    row and the 1 Hz uptime counter, both on the Overlay layer, both on the
--    Step.Fps grid, both only while liveOk(). With the band (10 s) and the
--    blip (8-20 s) that is four decorrelated clocks: the bracket draws a
--    fresh 4-6 s period every breath. Whole-pixel steps, no tween.
local bracket = Instance.new("Frame")
bracket.Name = "IdleBracket"
bracket.BackgroundTransparency = 1
bracket.BorderSizePixel = 0
bracket.Visible = false
bracket.ZIndex = 3
do
	local L = 14
	local function tick(name, ax, ay, w, h)
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundColor3 = PHOSPHOR
		f.BackgroundTransparency = 0.45
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(ax, ay)
		f.Position = UDim2.fromScale(ax, ay)
		f.Size = UDim2.fromOffset(w, h)
		f.ZIndex = 3
		f.Parent = bracket
	end
	tick("TLh", 0, 0, L, 2)
	tick("TLv", 0, 0, 2, L)
	tick("TRh", 1, 0, L, 2)
	tick("TRv", 1, 0, 2, L)
	tick("BLh", 0, 1, L, 2)
	tick("BLv", 0, 1, 2, L)
	tick("BRh", 1, 1, L, 2)
	tick("BRv", 1, 1, 2, L)
end
bracket.Parent = gui

local uptime = Instance.new("TextLabel")
uptime.Name = "Uptime"
uptime.BackgroundTransparency = 1
uptime.Font = Enum.Font.Code
uptime.TextSize = 14
uptime.TextColor3 = PHOSPHOR
uptime.TextTransparency = 0.35
uptime.TextXAlignment = Enum.TextXAlignment.Left
uptime.Size = UDim2.fromOffset(220, 16)
uptime.Text = ""
uptime.Visible = false
uptime.ZIndex = 3
uptime.Parent = gui

local function tileBounds(machine)
	local sel = machine:FindFirstChild("Selection")
	local tiles = sel and sel:FindFirstChild("Tiles")
	local minX, minY, maxX, maxY
	if tiles then
		for _, t in ipairs(tiles:GetChildren()) do
			if t:IsA("GuiObject") then
				local p, s = t.AbsolutePosition, t.AbsoluteSize
				minX = math.min(minX or p.X, p.X)
				minY = math.min(minY or p.Y, p.Y)
				maxX = math.max(maxX or p.X + s.X, p.X + s.X)
				maxY = math.max(maxY or p.Y + s.Y, p.Y + s.Y)
			end
		end
	end
	if not minX then
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		minX, maxX = vp.X * 0.25, vp.X * 0.75
		minY, maxY = vp.Y * 0.38, vp.Y * 0.62
	end
	return minX, minY, maxX, maxY, sel
end

task.spawn(function()
	local I = Feel.Idle
	local period = I.BracketPeriodMin + math.random() * (I.BracketPeriodMax - I.BracketPeriodMin)
	local phase0 = os.clock()
	local lastSec = -1
	local liveNow = false
	while gui.Parent do
		task.wait(Feel.stepSeconds())
		local live = selectionOk()
		if live ~= liveNow then
			liveNow = live
			bracket.Visible = live
			uptime.Visible = live
		end
		local machine = live and playerGui:FindFirstChild("KenopsiaMachine")
		if machine then
			local sec = math.floor(workspace.DistributedGameTime * I.UptimeHz)
			if sec ~= lastSec then
				lastSec = sec
				local s = math.floor(sec / I.UptimeHz)
				uptime.Text = ("UPTIME %02d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
			end
			local breath = 0
			if motionOk() then
				local now = os.clock()
				local ph = (now - phase0) / period
				if ph >= 1 then
					phase0 = now
					period = I.BracketPeriodMin + math.random() * (I.BracketPeriodMax - I.BracketPeriodMin)
					ph = 0
				end
				breath = math.floor(math.sin(ph * 2 * math.pi) * I.BracketBreathPx + 0.5)
			end
			local minX, minY, maxX, maxY, sel = tileBounds(machine)
			local pad = I.BracketPadPx + breath
			-- Review 23.08.: write only on change -- an unchanged UDim2 still
			-- dirties the overlay gui 12x/s (phone cost for nothing).
			local px, py = minX - pad, minY - pad
			local sx, sy = maxX - minX + 2 * pad, maxY - minY + 2 * pad
			if bracket.Position.X.Offset ~= px or bracket.Position.Y.Offset ~= py then
				bracket.Position = UDim2.fromOffset(px, py)
			end
			if bracket.Size.X.Offset ~= sx or bracket.Size.Y.Offset ~= sy then
				bracket.Size = UDim2.fromOffset(sx, sy)
			end
			if sel then
				local ux, uy = sel.AbsolutePosition.X + 24, sel.AbsolutePosition.Y + sel.AbsoluteSize.Y - 36
				if uptime.Position.X.Offset ~= ux or uptime.Position.Y.Offset ~= uy then
					uptime.Position = UDim2.fromOffset(ux, uy)
				end
			end
		end
	end
end)

-- 24.08.2026 (user, Idea.jpg): TERMINAL CHROME. The machine screens sit on a
-- layered grid (the user's two backgrounds, rebuilt as tiles) and carry the
-- terminal furniture of the reference: a USER line with an index box top-left,
-- corner ticks, a function-key strip at the bottom and a row of boxed status
-- cells. Built once at boot into the LIVE gui; everything static, zero
-- per-frame work, hidden with the screen it decorates.
task.defer(function()
	local machine = playerGui:WaitForChild("KenopsiaMachine", 30)
	if not machine then return end
	local PHOSPHOR = Color3.fromRGB(140, 232, 174)
	local DIM = Color3.fromRGB(46, 107, 74)
	local GRID_SOFT = "rbxassetid://80856993711380"
	local GRID_BLACK = "rbxassetid://139301976639622"
	local function gridInto(screen, image, alpha)
		if not screen or screen:FindFirstChild("TermGrid") then return end
		local g = Instance.new("ImageLabel")
		g.Name = "TermGrid"
		g.Size = UDim2.fromScale(1, 1)
		g.BackgroundTransparency = 1
		g.Image = image
		g.ImageTransparency = alpha
		g.ScaleType = Enum.ScaleType.Tile
		g.TileSize = UDim2.fromOffset(256, 256)
		g.ResampleMode = Enum.ResamplerMode.Pixelated
		g.ZIndex = 0
		g.Parent = screen
	end
	-- layered: black fine grid on the lobby screens, soft grid on the boards
	gridInto(machine:FindFirstChild("Info"), GRID_BLACK, 0.55)
	gridInto(machine:FindFirstChild("Selection"), GRID_BLACK, 0.62)
	gridInto(machine:FindFirstChild("Status"), GRID_SOFT, 0.72)
	gridInto(machine:FindFirstChild("Score"), GRID_SOFT, 0.72)
	gridInto(machine:FindFirstChild("Briefing"), GRID_BLACK, 0.62)
	local function chromeInto(screen, opts)
		if not screen or screen:FindFirstChild("TermChrome") then return end
		local c = Instance.new("Frame")
		c.Name = "TermChrome"
		c.Size = UDim2.fromScale(1, 1)
		c.BackgroundTransparency = 1
		c.ZIndex = 2
		c.Parent = screen
		-- USER line + index box, the reference's top-left cluster
		local user = Instance.new("TextLabel")
		user.Name = "UserLine"
		user.Position = UDim2.new(0, 46, 0, 8)
		user.Size = UDim2.new(0, 360, 0, 16)
		user.BackgroundTransparency = 1
		user.Font = Enum.Font.Code
		user.TextSize = 14
		user.TextColor3 = DIM
		user.TextXAlignment = Enum.TextXAlignment.Left
		user.Text = "USER:  " .. string.upper(player.DisplayName)
		user.ZIndex = 3
		user.Parent = c
		local idx = Instance.new("TextLabel")
		idx.Position = UDim2.new(0, 420, 0, 6)
		idx.Size = UDim2.new(0, 34, 0, 20)
		idx.BackgroundColor3 = Color3.fromRGB(6, 14, 10)
		idx.BackgroundTransparency = 0.2
		idx.BorderSizePixel = 0
		idx.Font = Enum.Font.Code
		idx.TextSize = 13
		idx.TextColor3 = PHOSPHOR
		idx.Text = opts.index or "01"
		idx.ZIndex = 3
		idx.Parent = c
		local stroke = Instance.new("UIStroke")
		stroke.Color = DIM
		stroke.Thickness = 1
		stroke.Parent = idx
		-- corner ticks
		for _, spec in ipairs({ { 0, 0, 0, 1 }, { 1, 0, -12, 1 }, { 0, 1, 0, -13 }, { 1, 1, -12, -13 } }) do
			local h = Instance.new("Frame")
			h.Position = UDim2.new(spec[1], spec[3] + (spec[1] == 0 and 28 or -28), spec[2], spec[4] + (spec[2] == 0 and 4 or -4))
			h.Size = UDim2.new(0, 12, 0, 2)
			h.BackgroundColor3 = DIM
			h.BorderSizePixel = 0
			h.ZIndex = 3
			h.Parent = c
			local v = Instance.new("Frame")
			v.Position = UDim2.new(spec[1], (spec[1] == 0 and 28 or -30), spec[2], spec[4] + (spec[2] == 0 and 4 or -14))
			v.Size = UDim2.new(0, 2, 0, 12)
			v.BackgroundColor3 = DIM
			v.BorderSizePixel = 0
			v.ZIndex = 3
			v.Parent = c
		end
		-- bottom function-key strip
		local strip = Instance.new("TextLabel")
		strip.Name = "KeyStrip"
		strip.AnchorPoint = Vector2.new(0.5, 1)
		strip.Position = UDim2.new(0.5, 0, 1, -6)
		strip.Size = UDim2.new(0.7, 0, 0, 14)
		strip.BackgroundTransparency = 1
		strip.Font = Enum.Font.Code
		strip.TextSize = 12
		strip.TextColor3 = DIM
		strip.Text = opts.keys or "F1_READY      F2_SETTINGS      F3_ROSTER"
		strip.ZIndex = 3
		strip.Parent = c
		-- boxed status cells, the reference's CORE row
		if opts.cells then
			local row = Instance.new("Frame")
			row.Name = "Cells"
			row.AnchorPoint = Vector2.new(0.5, 1)
			row.Position = UDim2.new(0.5, 0, 1, -28)
			row.Size = UDim2.new(0, #opts.cells * 96 - 8, 0, 34)
			row.BackgroundTransparency = 1
			row.ZIndex = 3
			row.Parent = c
			for i, cell in ipairs(opts.cells) do
				local b = Instance.new("Frame")
				b.Position = UDim2.new(0, (i - 1) * 96, 0, 0)
				b.Size = UDim2.new(0, 88, 0, 34)
				b.BackgroundColor3 = Color3.fromRGB(5, 12, 8)
				b.BackgroundTransparency = 0.25
				b.BorderSizePixel = 0
				b.ZIndex = 3
				b.Parent = row
				local st = Instance.new("UIStroke")
				st.Color = DIM
				st.Thickness = 1
				st.Parent = b
				local t1 = Instance.new("TextLabel")
				t1.Position = UDim2.new(0, 6, 0, 3)
				t1.Size = UDim2.new(1, -12, 0, 13)
				t1.BackgroundTransparency = 1
				t1.Font = Enum.Font.Code
				t1.TextSize = 11
				t1.TextColor3 = PHOSPHOR
				t1.TextXAlignment = Enum.TextXAlignment.Left
				t1.Text = cell[1]
				t1.ZIndex = 4
				t1.Parent = b
				local t2 = t1:Clone()
				t2.Position = UDim2.new(0, 6, 0, 17)
				t2.TextColor3 = DIM
				t2.Text = cell[2]
				t2.Parent = b
			end
		end
	end
	chromeInto(machine:FindFirstChild("Info"), { index = "01",
		keys = "F1_READY      F2_SETTINGS      F3_ROSTER",
		cells = { { "SYS A-1", "SET" }, { "SYS A-2", "READY" }, { "SYS B-1", "SYNC" }, { "SIM STS", "ONLINE_" } } })
	chromeInto(machine:FindFirstChild("Selection"), { index = "02",
		keys = "SELECTOR ARMED      DO NOT INTERFERE" })
	chromeInto(machine:FindFirstChild("Status"), { index = "03",
		keys = "STANDINGS FEED      LIVE" })
	chromeInto(machine:FindFirstChild("Score"), { index = "04",
		keys = "AUDIT FEED      DO NOT DISPUTE" })
	chromeInto(machine:FindFirstChild("Briefing"), { index = "05",
		keys = "F1_PAGE      F2_BACK" })
end)

-- Wiring that needs the Machine gui: the dither request, the hum duck and
-- the glow labels. Bounded wait; a place without the gui keeps the glass.
task.defer(function()
	local machine = playerGui:WaitForChild("KenopsiaMachine", 30)
	if not machine then return end
	machine:GetAttributeChangedSignal("DitherSeq"):Connect(runDither)
	for _, n in ipairs({ "Announce", "RoundCard" }) do
		local f = machine:FindFirstChild(n)
		if f then
			f:GetPropertyChangedSignal("Visible"):Connect(function()
				local d = false
				for _, m in ipairs({ "Announce", "RoundCard" }) do
					local s = machine:FindFirstChild(m)
					if s and s.Visible then d = true end
				end
				if d ~= humDucked then
					humDucked = d
					applyHum()
				end
			end)
		end
	end
	for _, path in ipairs(GLOW_LABELS) do
		local obj = machine
		for part in string.gmatch(path, "[^%.]+") do
			obj = obj and obj:FindFirstChild(part)
		end
		if obj and obj:IsA("TextLabel") then
			buildGlow(obj)
		else
			warn("[UiFx] glow label missing: " .. path)
		end
	end
end)
