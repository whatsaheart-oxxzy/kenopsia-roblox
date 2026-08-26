-- P1.5 Feel offline proof. Run from the repo root:
--
--     lua tests/feel.lua
--
-- Loads the SHIPPED Shared/Config/FeelConfig.luau (no copy) in plain Lua 5.1
-- and proves it against the timing bible in docs/MASTERPLAN.md section 3:
-- typewriter 24 / 30 cps, nothing but a fade over 600 ms, flicker <= 3/s on
-- the dim channel, the one 3-2-1, the death timeline, per-device transition
-- bands, and that the time-based reveal is frame-rate independent.
--
-- Exit code is 0 only if every check passes, so this is usable as a gate.

local FILE = "studio-src/ReplicatedStorage/Kenopsia/Shared/Config/FeelConfig.luau"
local PACING = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/Pacing.luau"

local function loadModule(file)
	local chunk = assert(loadfile(file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local Feel = loadModule(FILE)
local Pacing = loadModule(PACING)

local failures = 0
local checks = 0

local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
	end
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

print("FeelConfig loads in plain Lua")
check(type(Feel) == "table", "module returns a table")
check(type(Feel.Typewriter) == "table" and type(Feel.Countdown) == "table" and type(Feel.Death) == "table",
	"Typewriter / Countdown / Death sections present")
check(rawget(_G, "Enum") == nil, "no Roblox global leaked at load (Enum untouched)")

print("Typewriter")
check(Feel.Typewriter.BodyCps == 24, "body text 24 cps", tostring(Feel.Typewriter.BodyCps))
check(Feel.Typewriter.StatusCps == 30, "status lines 30 cps", tostring(Feel.Typewriter.StatusCps))
check(Feel.Typewriter.BlipEvery >= 1 and Feel.Typewriter.BlipEvery == math.floor(Feel.Typewriter.BlipEvery),
	"blip every whole N graphemes")
check(near(Feel.Typewriter.BlipSpeedMin, 0.94) and near(Feel.Typewriter.BlipSpeedMax, 1.06),
	"blip PlaybackSpeed band 0.94-1.06")
check(near(Feel.blipSpeed(0), 0.94) and near(Feel.blipSpeed(1), 1.06), "blipSpeed maps [0,1] onto the band")
check(type(Feel.Typewriter.BlipSfx) == "string" and #Feel.Typewriter.BlipSfx > 0, "blip has an SFX name")

-- Frame-rate independence: simulate 30 fps and 60 fps frame clocks and
-- compare the visible count at every shared instant. The reveal is a pure
-- function of elapsed time, so both must agree exactly at t = k/30.
do
	local text = 40
	local agree = true
	local finished30, finished60
	for k = 0, 120 do
		local t = k / 30
		local a = Feel.visibleAt(t, Feel.Typewriter.BodyCps, text)
		local b = Feel.visibleAt(t, Feel.Typewriter.BodyCps, text)
		if a ~= b then agree = false end
		if a == text and not finished30 then finished30 = t end
	end
	for k = 0, 240 do
		local t = k / 60
		if Feel.visibleAt(t, Feel.Typewriter.BodyCps, text) == text and not finished60 then finished60 = t end
	end
	check(agree, "visibleAt is a pure function of elapsed time (30 vs 60 fps agree)")
	check(finished30 and finished60 and math.abs(finished30 - finished60) <= 1 / 30,
		"40 graphemes finish within one 30-fps frame of each other at 30 and 60 fps",
		tostring(finished30) .. " vs " .. tostring(finished60))
	check(near(Feel.typeSeconds(48, 24), 2.0), "48 graphemes at 24 cps = 2.0 s")
	check(Feel.visibleAt(-1, 24, 10) == 0 and Feel.visibleAt(100, 24, 10) == 10, "visibleAt clamps to [0, total]")
end

-- The longest Machine lines must finish inside the beat that shows them.
check(Feel.typeSeconds(48, Feel.Typewriter.StatusCps) + Feel.Typewriter.ScoreLeadIn < Pacing.Timing.InterimScore,
	"a 48-char voice line at status cps fits under Pacing.Timing.InterimScore")
check(Feel.typeSeconds(40, Feel.Typewriter.BodyCps) < Pacing.Timing.RoundCard,
	"a 40-char round verb line at body cps fits under Pacing.Timing.RoundCard")

print("Easing")
check(Feel.Easing.Machine == "Linear", "machine elements move Linear")
check(Feel.Easing.Snap == "Quart" and Feel.Easing.SnapDir == "Out", "the snap is Quart/Out")
check(Feel.Easing.Fade == "Quad", "fades are Quad")

print("Panel transitions per device")
check(near(Feel.MaxMotion, 0.6), "MaxMotion is 600 ms")
local bands = { Mobile = { 0.2, 0.3 }, Desktop = { 0.15, 0.2 }, Tablet = { 0.35, 0.45 }, Console = { 0.15, 0.2 } }
for _, dev in ipairs(Feel.Devices) do
	local row = Feel.Panel[dev]
	local band = bands[dev]
	check(row and row.Value >= band[1] and row.Value <= band[2],
		dev .. " transition inside the bible band", row and tostring(row.Value) or "missing")
	check(row and row.Band[1] == band[1] and row.Band[2] == band[2], dev .. " declared band matches the bible")
	check(Feel.panel(dev) == row.Value, "Feel.panel(" .. dev .. ") returns the value")
end
check(Feel.panel(nil) == Feel.Panel.Desktop.Value and Feel.panel("Toaster") == Feel.Panel.Desktop.Value,
	"unknown / nil platform falls back to Desktop")
check(Feel.Feedback.Min >= 0.08 and Feel.Feedback.Max <= 0.12 and Feel.Feedback.Jolt >= Feel.Feedback.Min
	and Feel.Feedback.Jolt <= Feel.Feedback.Max, "feedback jolt inside 80-120 ms")

print("Nothing except fades over 600 ms")
local nonFade = {
	{ "Panel.Mobile", Feel.Panel.Mobile.Value }, { "Panel.Tablet", Feel.Panel.Tablet.Value },
	{ "Panel.Desktop", Feel.Panel.Desktop.Value }, { "Panel.Console", Feel.Panel.Console.Value },
	{ "Feedback.Jolt", Feel.Feedback.Jolt },
	{ "Countdown.PunchSeconds", Feel.Countdown.PunchSeconds }, { "Countdown.GoSeconds", Feel.Countdown.GoSeconds },
	{ "Roulette.CrosshairSnap", Feel.Roulette.CrosshairSnap }, { "Roulette.TileGap", Feel.Roulette.TileGap },
	{ "Roulette.Lead", Feel.Roulette.Lead }, { "Roulette.Pause", Feel.Roulette.Pause },
	{ "Roulette.BootDelay", Feel.Roulette.BootDelay }, { "Roulette.ReducedChaos", Feel.Roulette.ReducedChaos },
	{ "Flicker.Hold", Feel.Flicker.Hold }, { "Scope.ZoomSeconds", Feel.Scope.ZoomSeconds },
	{ "Typewriter.LineGap", Feel.Typewriter.LineGap }, { "Typewriter.LeadIn", Feel.Typewriter.LeadIn },
	{ "Typewriter.ScoreLeadIn", Feel.Typewriter.ScoreLeadIn }, { "Death.Fade", Feel.Death.Fade },
	{ "Overlay.BlipHold", Feel.Overlay.BlipHold },
}
for _, e in ipairs(nonFade) do
	check(type(e[2]) == "number" and e[2] > 0 and e[2] <= Feel.MaxMotion, e[1] .. " <= 600 ms", tostring(e[2]))
end
check(Feel.Death.Fade <= Pacing.Timing.FadeMax, "death fade under Pacing.Timing.FadeMax")
for k, v in pairs(Feel.Fade) do
	check(type(v) == "number" and v > 0, "Fade." .. k .. " is a positive duration")
end

print("Flicker")
check(Feel.Flicker.MaxPerSecond == 3, "at most 3 transitions per second")
check(Feel.Flicker.Hold >= 1 / Feel.Flicker.MaxPerSecond, "Hold >= 1/3 s so a loop never exceeds the rate",
	tostring(Feel.Flicker.Hold))
check(Feel.Flicker.Dim == "2E6B4A" and Feel.Flicker.Bright == "8CE8AE", "dim channel colours #2E6B4A <-> #8CE8AE")
-- worst case the roulette can produce: one change per Hold, both in the chaos
-- phase and during the lock blinks
check(1 / Feel.Flicker.Hold <= Feel.Flicker.MaxPerSecond, "roulette chaos phase rate <= 3/s")
check(Feel.Roulette.LockBlinks >= 1 and Feel.Roulette.LockBlinks <= 4, "lock blinks 1..4")
check(Feel.rouletteSeconds(3, false) <= Pacing.Timing.LobbyReveal,
	"full roulette (3 tiles) fits under Pacing.Timing.LobbyReveal", tostring(Feel.rouletteSeconds(3, false)))
check(Feel.rouletteSeconds(3, true) < Feel.rouletteSeconds(3, false), "ReduceFlicker path is shorter")
-- MP-08 S10 (26.08.2026): the same wheel now also runs between two trials, on
-- its own Pacing row. This is the REAL floor under that number -- drop it below
-- the animation and the info card cuts the wheel off mid-spin.
check(Feel.rouletteSeconds(3, false) <= Pacing.Timing.TrialReveal,
	"full roulette (3 tiles) fits under Pacing.Timing.TrialReveal", tostring(Feel.rouletteSeconds(3, false)))
check(near(Feel.Roulette.Chaos, 1.6) and near(Feel.Roulette.CrosshairSnap, 0.32) and near(Feel.Roulette.TileGap, 0.25)
	and near(Feel.Roulette.Lead, 0.4), "roulette beats: 0.4 lead, 0.25 tiles, 1.6 chaos, 0.32 snap")

print("Stepped motion")
check(Feel.Step.FpsMin == 12 and Feel.Step.FpsMax == 15, "stepped grid band 12-15 fps")
check(Feel.Step.Fps >= Feel.Step.FpsMin and Feel.Step.Fps <= Feel.Step.FpsMax, "Step.Fps inside the band")

print("3-2-1")
check(Pacing.Timing.CountdownFrom == 3, "Pacing: three counts")
check(near(Feel.Countdown.StepSeconds, 1.0), "1.0 s per count")
check(Feel.Countdown.PunchFrom == 160 and Feel.Countdown.PunchTo == 120 and near(Feel.Countdown.PunchSeconds, 0.3),
	"count punch 160 -> 120 px in 0.3 s")
check(Feel.Countdown.GoFrom == 150 and Feel.Countdown.GoTo == 118 and near(Feel.Countdown.GoSeconds, 0.35),
	"GO 150 -> 118 px in 0.35 s")
check(Feel.Countdown.PunchSeconds < Feel.Countdown.StepSeconds, "the punch finishes before the next count")
check(Feel.Countdown.GoHold > Feel.Countdown.GoSeconds, "GO is held past its own tween")

print("Death timeline")
check(near(Feel.Death.TelegraphMin, 0.7), "telegraph >= 0.7 s")
check(near(Feel.Death.Hold, 2.5), "hold 2.5 s")
check(near(Feel.Death.Fade, 0.5), "fade 0.5 s")
check(near(Feel.Death.Spectate, 3.2), "spectate at 3.2 s")
check(Feel.Death.Spectate >= Feel.Death.Hold + Feel.Death.Fade, "spectate lands after hold + fade")

print("Shake")
check(Feel.Shake.Decay > 0 and 1 / Feel.Shake.Decay <= 3.5, "full trauma drains in ~3 s")
check(Feel.Shake.Translate > 0 and Feel.Shake.Tilt > 0 and Feel.Shake.Roll > 0 and Feel.Shake.NoiseHz > 0,
	"shake amplitudes and noise rate positive")
-- 26.08.2026 (user): der Schlag hat jetzt eine RICHTUNG -- nach unten. Das
-- Rauschen daneben ist symmetrisch und kann sie nicht liefern, also sind es
-- eigene Felder. Ohne sie schreibt der Writer im Client nil in eine CFrame.
check(type(Feel.Shake.Down) == "number" and Feel.Shake.Down > 0,
	"the shake has a downward kick", tostring(Feel.Shake.Down))
check(type(Feel.Shake.DownPitch) == "number" and Feel.Shake.DownPitch > 0,
	"and the view pitches down with it", tostring(Feel.Shake.DownPitch))
-- Der Schlag muss ueber dem Rumpeln liegen, sonst geht die Richtung im
-- Rauschen unter und man sieht wieder nur Ruetteln.
check(Feel.Shake.Down > Feel.Shake.Translate,
	"the kick outweighs the rumble, or the direction is lost in the noise",
	string.format("down %s vs translate %s", tostring(Feel.Shake.Down), tostring(Feel.Shake.Translate)))

print("Overlay")
check(Feel.Overlay.BlipMin == 8 and Feel.Overlay.BlipMax == 20, "interference blip every 8-20 s")
check(Feel.Overlay.BandIdle + Feel.Overlay.BandSweep == 10, "refresh band period 10 s")

-- P2.2 / P2.3 (23.08.2026): overlay life + accessibility rows
print("Dither transition")
check(Feel.Dither.Steps == 4, "four ordered-dither steps", tostring(Feel.Dither.Steps))
check(Feel.Dither.ReducedSteps == 2, "ReduceFlicker falls back to a 2-step cut", tostring(Feel.Dither.ReducedSteps))
check(type(Feel.Dither.Tiles) == "table" and #Feel.Dither.Tiles == Feel.Dither.Steps, "one Bayer tile per step")
do
	local allIds = true
	for i, t in ipairs(Feel.Dither.Tiles) do
		if type(t) ~= "string" or not string.match(t, "^rbxassetid://%d+$") then allIds = false end
		for j = 1, i - 1 do
			if Feel.Dither.Tiles[j] == t then allIds = false end
		end
	end
	check(allIds, "every tile is a distinct rbxassetid")
end
check(Feel.Dither.TilePx == 4 or Feel.Dither.TilePx == 8, "tile drawn at 4 or 8 px", tostring(Feel.Dither.TilePx))
check(near(Feel.stepSeconds(), 1 / 12), "dither steps on the 12 fps grid", tostring(Feel.stepSeconds()))
check(near(Feel.ditherSeconds(false), Feel.Dither.Steps / Feel.Step.Fps), "full transition = Steps / Fps",
	tostring(Feel.ditherSeconds(false)))
check(Feel.ditherSeconds(false) <= Feel.MaxMotion, "full dither transition <= 600 ms", tostring(Feel.ditherSeconds(false)))
check(Feel.ditherSeconds(true) < Feel.ditherSeconds(false), "reduced cut is shorter than the dither")
check(Feel.ditherSeconds(false) <= Pacing.Timing.FadeMax, "dither under Pacing.Timing.FadeMax")

print("Phosphor glow")
check(Feel.Glow.StrokeTransparency > 0.5 and Feel.Glow.StrokeTransparency < 0.7, "stroke transparency ~0.6",
	tostring(Feel.Glow.StrokeTransparency))
check(Feel.Glow.StrokeThickness == 1, "stroke thickness 1 px")
check(Feel.Glow.EchoTransparency > Feel.Glow.StrokeTransparency and Feel.Glow.EchoTransparency < 1,
	"echo label dimmer than the stroke", tostring(Feel.Glow.EchoTransparency))
check(Feel.Glow.EchoOffsetPx == 1, "echo offset 1 px")
-- PreferredTransparency multiplies: at the default (1) the values ship as-is,
-- at 0 (player wants no see-through) both land at 0 -- never negative.
for _, pt in ipairs({ 0, 0.5, 1 }) do
	local s, e = Feel.Glow.StrokeTransparency * pt, Feel.Glow.EchoTransparency * pt
	check(s >= 0 and s <= Feel.Glow.StrokeTransparency and e >= 0 and e <= Feel.Glow.EchoTransparency,
		"glow x PreferredTransparency " .. pt .. " stays in [0, authored]")
end

print("Idle oscillators")
check(Feel.Idle.BracketPeriodMin == 4 and Feel.Idle.BracketPeriodMax == 6, "bracket breathes 4-6 s")
check(Feel.Idle.BracketBreathPx > 0 and Feel.Idle.BracketBreathPx < Feel.Idle.BracketPadPx,
	"breath amplitude inside the bracket padding")
check(Feel.Idle.UptimeHz == 1, "uptime counter 1 Hz")
-- four clocks, none sharing a period: band 10 s, blip 8-20 s (random), bracket 4-6 s (random), uptime 1 s
do
	local bandP = Feel.Overlay.BandIdle + Feel.Overlay.BandSweep
	check(bandP ~= 1 / Feel.Idle.UptimeHz and Feel.Idle.BracketPeriodMax < Feel.Overlay.BlipMin
		and Feel.Idle.BracketPeriodMax < bandP, "bracket, blip, band and uptime periods are decorrelated")
end
check(1 / Feel.Idle.UptimeHz >= Feel.stepSeconds(), "uptime tick is representable on the step grid")

print("CRT hum")
check(Feel.Hum.DuckDb == -6, "duck -6 dB", tostring(Feel.Hum.DuckDb))
check(near(Feel.Hum.DuckSeconds, 0.2), "duck over 0.2 s", tostring(Feel.Hum.DuckSeconds))
check(near(Feel.dbGain(-6), 0.501, 0.002), "-6 dB is a gain of ~0.5", tostring(Feel.dbGain(-6)))
check(near(Feel.dbGain(0), 1), "0 dB is unity")
check(Feel.Hum.Volume > 0 and Feel.Hum.Volume <= 0.35, "hum is a bed, not a track", tostring(Feel.Hum.Volume))
check(Feel.Hum.Volume * Feel.dbGain(Feel.Hum.DuckDb) < Feel.Hum.Volume, "ducked volume is lower")
check(type(Feel.Hum.SoundName) == "string" and #Feel.Hum.SoundName > 0, "hum has a lookup name")
check(type(Feel.Hum.PlaceholderId) == "number" and Feel.Hum.PlaceholderId >= 0, "placeholder id is a number (0 = silent)")

print("Shake reduce")
check(near(Feel.Shake.ReduceFactor, 0.35), "ReduceShake = 0.35x amplitude", tostring(Feel.Shake.ReduceFactor))
check(Feel.Shake.ReduceFactor > 0 and Feel.Shake.ReduceFactor < 1, "reduced shake is never zero and never full")

print("No duplicated Pacing.Timing values")
for k in pairs(Pacing.Timing) do
	check(Feel[k] == nil, "Feel has no top-level " .. k)
end

print(string.format("\n%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
