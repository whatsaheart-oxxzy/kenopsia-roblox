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

-- CANTEEN POLISH (Phase 3a, 29.08.2026) -- the observer's escalation ladder,
-- suspicion, fake-lowers, hot peas and the rustle tell. Consumed by
-- CanteenProtocol / CanteenProps / CanteenBoss on the server; nothing here
-- reaches the client (the plate and the boss ARE the readout, per the
-- CanteenProps header). The round length itself stays
-- Pacing.RoundSeconds.canteen; the settlement window stays
-- Pacing.Timing.CanteenSettlement -- this block only owns how the screw turns.
--   HiddenShrink     multiplies BOTH hidden bounds by (1 - this) per round past
--                    the first: round 2 reads 2.13-7.65 s, round 3 1.81-6.50 s.
--   HiddenFloor      no hidden read is ever shorter than this. 1.2 s stays
--                    above Feel.Death.TelegraphMin (0.7): the 0.35 s lowering
--                    tell plus a human reaction always fits.
--   SuspicionStep    seconds off the NEXT full read per near-catch this round
--                    (a swallow whose window died during `lowering` -- risky
--                    but unpunished); applied after the shrink, still floored.
--   SuspicionAngryAt at this many near-catches the boss keeps the angry atlas
--                    up until the round ends (CanteenBoss.setSuspicious).
--   FakeLowerFrom /  from this round on, a hidden read may carry ONE
--   FakeLowerChance  theatrical glance (LookDown with no phase behind it),
--                    never two reads in a row. Pure theater: detection is off.
--   HotPeasFrom /    from this round on, HotPeaCount peas per plate are HOT
--   HotPeaCount /    (tinted hazard-amber on the plate): once forked they must
--   HotPeaSeconds    reach a mouth within HotPeaSeconds or they are VOIDED --
--                    off the fork, no score, cpmiss nudge.
--   HotPeaHex        fallback tint when TrialKit.PALETTE.Hazard is absent.
--   PeaScore         raw-key detail per eaten pea (CanteenProtocol PEA_STEP).
--                    The protocol clamps every band's detail under 1000, so
--                    the Borda bands can never overlap.
--   RustleLead       seconds the paper rustle precedes every lowering onset --
--                    and every fake glance, so the sound never disambiguates.
--   RustleSound /    the SFX slot (SoundService.KenopsiaAudio.SFX.Canteen.
--   RustlePlaceholderId / RustleVolume  <RustleSound>), CRT-hum pattern: named
--                    asset first, then the placeholder id, 0 = silent with one
--                    warn until the asset lands (MASTERPLAN P6).
Feel.Canteen = {
	HiddenShrink = 0.15,
	HiddenFloor = 1.2,
	SuspicionStep = 0.3,
	SuspicionAngryAt = 2,
	FakeLowerFrom = 2,
	FakeLowerChance = 0.25,
	HotPeasFrom = 2,
	HotPeaCount = 4,
	HotPeaSeconds = 8,
	HotPeaHex = "D9A036",
	PeaScore = 60,
	RustleLead = 0.35,
	RustleSound = "Rustle",
	RustlePlaceholderId = 0,
	RustleVolume = 0.5,
}

-- DEAD ZONE POLISH (Phase 3b, 30.08.2026) -- the sonar economy, the trial-long
-- craters, the mid-round speed step, the BLACKOUT SWEEP mutator and the scrap
-- tags. Consumed by Services/Minefield on the server; the standalone
-- SonarClient sender reads nothing here (it only sends -- the server spends).
-- Like the Canteen block, nothing here reaches KenopsiaClient. Round
-- length stays Pacing.RoundSeconds.minefield and rounds per trial stay
-- Pacing.ROUNDS -- this block only owns how the field behaves.
--   SonarPulses      pulses per runner per round. Spent SERVER-side; the old
--                    held-to-repeat trigger in KenopsiaClient simply drains
--                    the same budget faster -- holding F is a choice, not an
--                    exploit.
--   SonarRadius      studs a pulse reveals around the pulser. Replaces the
--                    module-local SCAN_RADIUS 8 (+ CELL fringe): one number,
--                    one file.
--   SonarReveal      seconds the server-part glow stands on a revealed mine.
--                    The reveal is EVERYONE'S: ring and glows are server
--                    parts in DZ_Runtime, the server's picture like the
--                    canteen plate.
--   SonarStillTime   BLACKOUT SWEEP only: a pulse fires only after this many
--                    seconds of stillness, measured from the server's OWN
--                    20 Hz position samples -- never from client claims.
--   CraterClearRadius studs around a previous-round crater in which no new
--                    mine is seeded. A crater is proven-safe ground; reading
--                    the scars is reading the path.
--   SpeedStepAt      fraction of RoundSeconds.minefield at which the ONE
--                    mid-round compactor speed step lands.
--   SpeedStepFactor  that step's multiplier on the current phase speed,
--                    published through the same MF_Z0/T0/Speed anchor the
--                    clients already integrate.
--   SweepFactor      BLACKOUT SWEEP: multiplier on the compactor's clamped
--                    base speed, final round only. Worst stack 6.5 * 1.15 *
--                    1.12 = 8.37 stays under the ramped sprint (10) -- escape
--                    on foot survives the mutator; walking (7) does not.
--   ScrapTags /      tags per round in the most-mined third of the corridor,
--   ScrapDetail      and the raw ordering-key detail each pays on pickup.
--                    Minefield clamps progress + scrap under its DETAIL_CAP
--                    (999) so no eliminated key can reach the escape band;
--                    tests/feel.lua re-proves min(1000 + Tags*Detail, 999)+1
--                    < 2000.
--   ScrapHex         fallback tint when TrialKit.PALETTE.Signal is absent
--                    (the HotPeaHex pattern, one shelf up).
--   HornSound /      the speed-step horn slot (SoundService.KenopsiaAudio.
--   HornPlaceholderId / SFX.Minefield.<HornSound>), CRT-hum pattern: named
--   HornVolume       asset first, then the placeholder id, 0 = silent with
--                    one warn until the asset lands (MASTERPLAN P6).
--   CascadeSeconds   length of the lane-light cascade telegraphing the step
--                    (the 11 LaneLight parts, flashed emissive in sequence,
--                    server-side -- never Light objects, low quality drops
--                    those). Held >= Feel.Death.TelegraphMin by
--                    tests/feel.lua: the step is a lethal-adjacent event and
--                    gets the lethal minimum warning.
Feel.Minefield = {
	SonarPulses = 3,
	SonarRadius = 12,
	SonarReveal = 2.5,
	SonarStillTime = 0.5,
	CraterClearRadius = 6,
	SpeedStepAt = 0.55,
	SpeedStepFactor = 1.12,
	SweepFactor = 1.15,
	ScrapTags = 3,
	ScrapDetail = 150,
	ScrapHex = "46E8E0",
	HornSound = "Horn",
	HornPlaceholderId = 0,
	HornVolume = 0.6,
	CascadeSeconds = 0.7,
}

-- BIRD HUNTING POLISH (Phase 3c, 30.08.2026) -- the reload lamp, the real
-- limp, push-topple cover, heartbeat exposure and the decoy birds. Consumed
-- by Services/BirdHunting on the server; the standalone RunnerClient push
-- sender reads nothing here (it only sends -- the server owns the budget,
-- the range and the topple, the SonarClient contract one trial over). Like
-- the Canteen and Minefield blocks, nothing here reaches KenopsiaClient. Leg
-- length stays Pacing.RoundSeconds.birdhunt and legs per trial stay
-- Pacing.LEGS -- this block only owns how a leg feels.
--   ReloadSeconds    the fire lockout AND the lamp cycle, one number. The
--                    server enforces it in the SniperFire handler (early
--                    shots rejected silently, as before); the lamp over the
--                    post holds the reload colour for exactly this long
--                    after every accepted shot. KenopsiaClient mirrors it as
--                    K.FIRE_COOLDOWN = 2.2 (bolt-cycle, recoil, local gate);
--                    tests/feel.lua PINS this value to 2.2 until the client
--                    reads Feel, so the hunter's rifle can never lie about
--                    the server's gate.
--   LampReloadHex /  the lamp's two states (the hex-string colour
--   LampReadyHex     convention, though here the SERVER paints them onto a
--                    neon part -- readable at 300 studs with sound off, per
--                    the telegraph contract: neon emissive + sound, never
--                    Light-only). Amber = bolt open, sprint now; Signal-cyan
--                    = loaded, be behind something.
--   InjuredSpeed     WalkSpeed of a winged runner for the rest of the leg.
--                    Was the module's own 7 -- faster than PS1Animate's
--                    InjuredWalk was authored for (natural 3.49 st/s); at
--                    3.5 the gait plays ~1x and the limp is a real decision
--                    for the hunter: finish the wounded or switch targets.
--                    Healed at the next leg's placement (the Minefield CRAWL
--                    snapshot + restore contract), never mid-leg.
--   PushesPerLeg /   each runner may topple this many LOOSE cover props per
--   PushRange /      leg (Metal_crate / Wooden_pallet only -- stones, walls,
--   ToppleSeconds    trees never move) within PushRange studs. The fall is a
--                    ToppleSeconds stepped pivot, server-side, one-shot; the
--                    prop stays down as new LOW cover and stands back up
--                    from its snapshot when the leg ends. Under MaxMotion:
--                    the topple is a motion, not a fade.
--   ExposeAfter /    HEARTBEAT EXPOSURE. Standing still ExposeAfter s in
--   ExposeSeconds /  OPEN ground (no cover prop within CoverRadius) pings
--   ExposeEvery /    the runner: a Highlight on the character, ExposeSeconds
--   CoverRadius /    long, repeating every ExposeEvery while still, visible
--   ExposeHex        to EVERYONE -- deliberately including the runner. (The
--                    plan asked for a sniper-only ping; a telegraph given
--                    ABOUT you that you cannot see is not a telegraph, and
--                    self-visibility is what lets a runner correct instead
--                    of just die confused.) Stillness comes from the leg
--                    loop's own 0.2 s samples, the Minefield STILL_EPSILON
--                    precedent -- never client claims.
--   Birds /          decoy birds crossing the lane per leg on server-moved
--   BirdSpeed /      straight paths (10 Hz, one PivotTo per bird per tick),
--   BirdDetail       BirdSpeed st/s -- never faster than a runner (14), so a
--                    lead learned on birds transfers to runners. Shooting
--                    one pays BirdDetail into the hunter's raw key but
--                    consumes the shot AND the reload -- the bluff cost. A
--                    shot bird never respawns, so the hunter's raw stays
--                    provable offline: 3 x (wing 15 + headshot 100) = 345
--                    plus Birds*BirdDetail (400) = 745, clamped under 1000
--                    by the DETAIL_CAP (999) pattern; tests/feel.lua
--                    re-proves the sum.
Feel.Birdhunt = {
	ReloadSeconds = 2.2,
	LampReloadHex = "D9A036",
	LampReadyHex = "46E8E0",
	InjuredSpeed = 3.5,
	PushesPerLeg = 1,
	PushRange = 6,
	ToppleSeconds = 0.5,
	ExposeAfter = 2.5,
	ExposeSeconds = 0.4,
	ExposeEvery = 1.5,
	CoverRadius = 5,
	ExposeHex = "FF1818",
	Birds = 2,
	BirdSpeed = 14,
	BirdDetail = 200,
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
