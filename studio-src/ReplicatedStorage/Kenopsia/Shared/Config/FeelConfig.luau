--!nonstrict
-- FEEL CONFIG (P1.5) -- how the Machine MOVES: every typewriter rate, tween
-- duration, easing, shake constant, flicker rule, step rate and the 3-2-1
-- numbers, in one file. docs/MASTERPLAN.md section 3 is the bible this file
-- transcribes; tests/feel.lua proves the two agree.
--
-- Pacing (Shared/Rules/Pacing.luau) owns how long a BEAT lasts (Reveal 3.5,
-- RoundCard 3.0, CountdownFrom 3, ...). This file owns how the beat FEELS
-- while it lasts. Nothing in Pacing.Timing is repeated here; where a feel
-- number depends on a beat (e.g. the count has CountdownFrom steps, each
-- Countdown.StepSeconds long) the comment names the Pacing key.
--
-- PURE and portable to Lua 5.1 (see the header of Rules/Pacing.luau for the
-- rule): no Roblox globals at module level, no type annotations, no compound
-- assignment, no generalized iteration. Easings are NAMES ("Quart", "Out");
-- the client resolves them to Enum.EasingStyle / Enum.EasingDirection with
-- Feel.easing(). Colours are hex strings; the client wraps Color3.fromHex.

local Feel = {}

-- Device classes are MachineLayout's Platform attribute values. Every
-- per-device table below has exactly these keys; Feel.forDevice() falls back
-- to Desktop for anything else (nil before MachineLayout has stamped it).
Feel.Devices = { "Mobile", "Tablet", "Desktop", "Console" }

-- Typewriter: time-based MaxVisibleGraphemes. Elapsed * cps graphemes are
-- visible, whatever the frame rate; 30 fps and 60 fps finish the same line at
-- the same instant. Every N graphemes a blip plays with a PlaybackSpeed drawn
-- from the band, so a long line never sounds like a sample loop.
Feel.Typewriter = {
	BodyCps = 24,        -- round card verbs, announce lines, NEXT SIMULATION, boot text
	StatusCps = 30,      -- Status screen rows, the voice line under the score rows
	LineGap = 0.25,      -- seconds between consecutive Status rows
	LeadIn = 0.4,        -- seconds before the announce line starts typing
	ScoreLeadIn = 0.3,   -- seconds before the score voice line starts typing
	BlipEvery = 3,       -- graphemes per blip
	BlipSfx = "Hover",   -- SoundService.KenopsiaAudio.SFX.<name>, cloned per blip
	BlipSpeedMin = 0.94, -- PlaybackSpeed band
	BlipSpeedMax = 1.06,
}

-- Easing names. Machine elements move Linear (or stepped); Quart/Out is
-- reserved for the crosshair snap and the 3-2-1 punch (a snap, not a slide).
-- Fades use Quad so the tail is soft.
Feel.Easing = {
	Machine = "Linear",
	Snap = "Quart",
	SnapDir = "Out",
	Fade = "Quad",
	FadeInDir = "In",
	FadeOutDir = "Out",
}

-- Panel transitions, seconds, per device class (section 3: mobile 200-300,
-- desktop 150-200, tablet ~400). Band is what tests/feel.lua checks the value
-- against; Value is what ships.
Feel.Panel = {
	Mobile  = { Value = 0.25,  Band = { 0.20, 0.30 } },
	Tablet  = { Value = 0.40,  Band = { 0.35, 0.45 } },
	Desktop = { Value = 0.175, Band = { 0.15, 0.20 } },
	Console = { Value = 0.175, Band = { 0.15, 0.20 } }, -- ten-foot UI reads like a desktop
}

-- Hit / confirm / reject feedback: 80-120 ms chroma jolt or hit-stop.
Feel.Feedback = { Min = 0.08, Max = 0.12, Jolt = 0.12 }

-- Nothing except a fade may take longer than this. Every non-fade duration in
-- this file is asserted against it by tests/feel.lua.
Feel.MaxMotion = 0.6

-- Fades, seconds. Exempt from MaxMotion by the bible. ArenaIn is the black
-- card thinning under the first count so the arena is fully visible before
-- "2"; it runs UNDER the count and adds no time to the beat.
Feel.Fade = {
	ScreenBlood = 0.55, -- full-screen blood veil
	HitMark = 0.9,      -- IMPACT / TERMINATED text
	YouLabel = 0.45,    -- "YOU" marker over the runner after GO
	Notice = 0.4,       -- lobby rejection notice
	Ration = 0.4,       -- Canteen HUD ration colour settle
	ArenaIn = 1.4,
}

-- Camera shake: trauma model. Events add to trauma (0..1); strength is
-- trauma squared; trauma drains at Decay per second (a full load ~3 s).
-- 26.08.2026 (user): HEFTIGER, NACH UNTEN, ROT.
--
-- Die Amplituden sind angehoben (Translate 1.15 -> 1.8, Tilt 0.2 -> 0.3,
-- Roll 0.26 -> 0.38). Ueber `power` allein war das nicht zu holen: applyGoreFx
-- rechnet trauma = min(1, trauma + power * near), der Wert ist also bei 1
-- gedeckelt und mag = trauma^2 damit ebenfalls. Wer mehr Wucht will, muss an
-- die Amplituden -- `power` entscheidet nur, wie schnell man den Deckel
-- erreicht.
--
-- GILT FUER JEDEN gorefx, also auch fuer Minen und Compactor in der Dead Zone.
-- Das ist Absicht: ein Spiel sollte EINE Sprache fuer Einschlaege sprechen, und
-- zwei verschieden harte Schuettler waeren nicht Abstimmung, sondern Zufall.
Feel.Shake = {
	Decay = 0.33,      -- trauma per second
	NoiseHz = 30,      -- math.noise sample rate
	Translate = 1.8,   -- studs at full trauma
	Tilt = 0.3,        -- radians (pitch / yaw) at full trauma
	Roll = 0.38,       -- radians at full trauma
	-- DER ABWAERTS-SCHLAG. Das Rauschen oben ist symmetrisch -- es rumpelt in
	-- alle Richtungen gleich und hat deshalb keine RICHTUNG. Diese beiden geben
	-- ihm eine: die Kamera faellt nach unten und kippt den Blick mit, als saecke
	-- einem der Kopf weg. Getrennt vom Rauschen, weil ein Schlag kein Rumpeln
	-- ist -- er faellt steiler ab (trauma^3 statt ^2, siehe den Writer im
	-- Client), sitzt also im ersten Moment und ist weg, waehrend das Rumpeln
	-- noch ausklingt.
	Down = 2.2,        -- studs nach unten at full trauma
	DownPitch = 0.16,  -- radians, der Blick kippt mit nach unten
	-- P2.3: the SHAKE settings row (ReduceShake, seeded from
	-- GuiService.ReducedMotionEnabled) multiplies every amplitude by this.
	-- Never zero: a hit must still read as a hit.
	ReduceFactor = 0.35,
}

-- Flicker: at most MaxPerSecond state changes per second, on the DIM channel
-- only (Dim <-> Bright, never to black, never to full phosphor). Hold is the
-- minimum time a state is held (1 / MaxPerSecond, rounded up a hair so the
-- roulette loop never lands under it). Seeded from
-- GuiService.ReducedMotionEnabled: the client's ReduceFlicker setting drops
-- the chaos phase entirely and cuts lock blinks to one.
Feel.Flicker = {
	MaxPerSecond = 3,
	Hold = 0.34,
	Dim = "2E6B4A",
	Bright = "8CE8AE",
}

-- Stepped UI motion (house style): a 12-15 fps grid via a dt accumulator.
-- Never for fades, never for drag cursors. Odometer digits roll on this grid.
Feel.Step = { Fps = 12, FpsMin = 12, FpsMax = 15 }

-- Lobby roulette (showSelection). Tiles appear TileGap apart after Lead; the
-- chaos phase lasts Chaos on the flicker rule; LockBlinks blinks of the chosen
-- tile, each state held Flicker.Hold; the crosshair snaps in CrosshairSnap
-- (the one Quart/Out); the boot text starts BootDelay later. The whole thing
-- must fit under Pacing.Timing.LobbyReveal.
Feel.Roulette = {
	Lead = 0.4,
	TileGap = 0.25,
	Pause = 0.3,
	Chaos = 1.6,
	ReducedChaos = 0.6, -- plain hold in place of the chaos phase under ReduceFlicker
	LockBlinks = 3,
	CrosshairSnap = 0.32,
	BootDelay = 0.45,
}

-- 3-2-1 / GO. One implementation (the CountText handler in KenopsiaClient;
-- TrialKit Round:countdown and the three legacy services send the same
-- {kind="count"|"go"} packets). Pacing.Timing.CountdownFrom steps of
-- StepSeconds each. Punch: TextSize PunchFrom -> PunchTo in PunchSeconds,
-- Quart/Out; GO: GoFrom -> GoTo in GoSeconds, held GoHold then hidden.
Feel.Countdown = {
	StepSeconds = 1.0,
	PunchFrom = 160,
	PunchTo = 120,
	PunchSeconds = 0.3,
	GoFrom = 150,
	GoTo = 118,
	GoSeconds = 0.35,
	GoHold = 0.7,
	GoTransparency = 0.08,
}

-- Death timeline, seconds from the kill. Telegraph is the MINIMUM warning a
-- trial must give before a lethal event; Hold is the camera on the body with
-- the death card; Fade the black-out; Spectate when the spectate packet lands
-- (TrialKit DEATH_CAM_DELAY).
Feel.Death = {
	TelegraphMin = 0.7,
	Hold = 2.5,
	Fade = 0.5,
	Spectate = 3.2,
}

-- Weapon / scope feel (not a Machine element: Quad is allowed here).
Feel.Scope = { ZoomSeconds = 0.18 }

-- CRT overlay life (UiFx): the refresh band sweeps the glass BandSweep s
-- (Linear) every BandIdle s; an interference blip holds BlipHold s every
-- BlipMin..BlipMax s. Both are ambient, ReduceFlicker / ReducedMotion stop
-- them. The sweep is exempt from MaxMotion like a fade: it is a continuous
-- scroll across the whole glass, not a state change the player waits for.
Feel.Overlay = {
	BandIdle = 8,
	BandSweep = 2,
	BlipMin = 8,
	BlipMax = 20,
	BlipHold = 0.08,
}

-- P2.2 (23.08.2026) Bayer dither between Machine screens (UiFx). The swap
-- itself stays a hard cut (section 3); the glass then re-paints the new screen
-- through Steps ordered-dither tiles, one per frame of the Step.Fps grid
-- (Steps / Fps = the whole transition). NEVER a smooth alpha tween. Under
-- ReduceFlicker / ReducedMotion the tiles are replaced by a plain black card
-- held ReducedSteps frames (a 2-step cut). Tiles[i] is the 4x4 Bayer level i
-- (1 = sparsest, Steps = densest); TilePx is the on-screen tile size
-- (8 = each pattern pixel is 2 px; 4 = native).
Feel.Dither = {
	Steps = 4,
	ReducedSteps = 2,
	TilePx = 8,
	Tiles = {
		"rbxassetid://128764657994112",
		"rbxassetid://121598984043867",
		"rbxassetid://93726535183476",
		"rbxassetid://72454964162888",
	},
}

-- Phosphor glow on headline labels (UiFx builds it once from a name list):
-- a 1-px UIStroke plus a 1-px offset echo label with lower alpha. Both
-- transparencies are MULTIPLIED by GuiService.PreferredTransparency at
-- apply time (Roblox's accessibility contract: 1 = default, lower = the
-- player wants less see-through). No per-frame work: the echo mirrors the
-- label through property-changed signals only.
Feel.Glow = {
	StrokeTransparency = 0.6,
	StrokeThickness = 1,
	EchoTransparency = 0.75,
	EchoOffsetPx = 1,
}

-- Idle life on the Selection screen (UiFx, Overlay layer): four decorrelated
-- oscillators, all on the Step.Fps grid, none while a trial runs, none while
-- Selection is hidden. The bracket breathes BreathPx around the tile row
-- with a fresh period drawn from BracketPeriodMin..Max every cycle; the
-- uptime counter ticks at UptimeHz; the blip and the band keep Feel.Overlay.
Feel.Idle = {
	BracketPeriodMin = 4,
	BracketPeriodMax = 6,
	BracketBreathPx = 6,
	BracketPadPx = 18,
	UptimeHz = 1,
}

-- CRT hum bed (UiFx): a low loop on the KenopsiaUI SoundGroup at Volume,
-- ducked by DuckDb over DuckSeconds under announcements / round cards and
-- released over the same time. Off while a trial runs and while UiSound is
-- off. SoundName is looked up under SoundService.KenopsiaAudio (Ambience.Hum,
-- then any Sound of that name); with none present the PlaceholderId is used
-- (0 = silent, one warn) until an asset is uploaded (MASTERPLAN P6).
Feel.Hum = {
	SoundName = "Hum",
	PlaceholderId = 0,
	Volume = 0.12,
	DuckDb = -6,
	DuckSeconds = 0.2,
}

-- P2.4 (23.08.2026) input-mode hysteresis (MachineLayout through the Glyphs
-- tracker): a gamepad counts as the console signal once it has been the LAST
-- input type for more than GamepadHoldSeconds with no click / key / touch in
-- between; a mouse move alone never ends console mode. Not a motion, so it is
-- not held to MaxMotion.
Feel.Input = { GamepadHoldSeconds = 2 }

-- Helpers -------------------------------------------------------------------

-- Value of a per-device table for MachineLayout's Platform attribute.
function Feel.forDevice(tbl, platform)
	local row = tbl[platform] or tbl.Desktop
	if type(row) == "table" and row.Value ~= nil then return row.Value end
	return row
end

-- Easing names -> Enums. Roblox only (Enum is resolved at CALL time, so the
-- module still loads under plain Lua 5.1 as long as nothing calls this).
function Feel.easing(styleName, dirName)
	return Enum.EasingStyle[styleName or Feel.Easing.Machine], Enum.EasingDirection[dirName or "Out"]
end

-- Panel transition seconds for a device class.
function Feel.panel(platform)
	return Feel.forDevice(Feel.Panel, platform)
end

-- Graphemes visible after `elapsed` seconds at `cps`, capped to `total`.
-- Pure so tests can prove frame-rate independence.
function Feel.visibleAt(elapsed, cps, total)
	local n = math.floor(elapsed * cps)
	if n < 0 then n = 0 end
	if total ~= nil and n > total then n = total end
	return n
end

-- Seconds a line of `total` graphemes takes at `cps`.
function Feel.typeSeconds(total, cps)
	return total / cps
end

-- Blip PlaybackSpeed for a unit random r in [0, 1).
function Feel.blipSpeed(r)
	local t = Feel.Typewriter
	return t.BlipSpeedMin + (t.BlipSpeedMax - t.BlipSpeedMin) * r
end

-- Seconds one step of the stepped-motion grid is held.
function Feel.stepSeconds()
	return 1 / Feel.Step.Fps
end

-- Seconds a dither transition takes (reduced = the plain 2-step cut).
function Feel.ditherSeconds(reduced)
	local steps = reduced and Feel.Dither.ReducedSteps or Feel.Dither.Steps
	return steps * Feel.stepSeconds()
end

-- Linear gain for a decibel offset (-6 dB -> ~0.5).
function Feel.dbGain(db)
	return 10 ^ (db / 20)
end

-- Seconds the roulette takes end to end (with the full flicker phase).
function Feel.rouletteSeconds(tiles, reduced)
	local r = Feel.Roulette
	local chaos = reduced and r.ReducedChaos or r.Chaos
	local blinks = (reduced and 1 or r.LockBlinks) * Feel.Flicker.Hold * 2
	return r.Lead + tiles * r.TileGap + r.Pause + chaos + blinks + r.BootDelay
end

return Feel
