--!nonstrict
-- MENU CONFIG (25.08.2026) -- what the MAIN MENU says and where its parts sit.
--
-- The menu is the first thing a subject sees: a cold terminal outside the
-- facility, deliberately NOT the phosphor green of the machine screens inside
-- it. Entering warms the palette over (see MainMenu.enter) -- that colour break
-- is the point, so every cold value lives here and nowhere else.
--
-- PURE and portable to Lua 5.1 (same rule as Rules/Pacing.luau and
-- Config/FeelConfig.luau): no Roblox globals at module level, no type
-- annotations, no compound assignment, no generalized iteration. Colours are
-- hex strings; the client wraps Color3.fromHex. tests/menu.lua proves the
-- numbers here.
--
-- HOW the menu moves is NOT here -- that is FeelConfig (step grid, flicker
-- rule, typewriter rate, dither steps). This file only says WHAT and WHERE.

local Menu = {}

-- PALETTE -------------------------------------------------------------------
-- Cold cyan/white. WHITE is reserved for the selection streak alone, exactly
-- the way #FF1818 is reserved for FIRE/PUNCH in the machine palette.
Menu.Palette = {
	BG = "020609",      -- ground
	PLATE = "06121A",   -- boxed cells, the detail card
	CYAN = "BFE9F5",    -- body text, unselected entries
	CYAN_HI = "E8FBFF", -- the wordmark, headings, values
	CYAN_DIM = "4E7C8A", -- inert text, build tag, corner ticks
	WHITE = "FFFFFF",   -- THE STREAK ONLY
	INK = "04121A",     -- text sitting ON the streak
	ACCENT = "6FD8F0",  -- serration, brackets, cell headers
}

-- IMAGES --------------------------------------------------------------------
-- All five are white-on-transparent and authored SMALL: with
-- ResamplerMode.Pixelated a magnified source gives hard pixel edges, a
-- minified one just aliases. Sources: tools/menu-assets.py (original work).
-- Ids are filled in on upload; an empty id renders as nothing, never as an
-- error, so the menu still boots on a place that has not got them yet.
-- Uploaded 25.08.2026 from tools/menu-assets.py output.
Menu.Images = {
	Wordmark = { id = "88647754582283", w = 512, h = 97 },
	Streak = { id = "134334042347021", w = 256, h = 32 },
	Shards = { id = "120005853529594", w = 512, h = 384 },
	Rain = { id = "105106540934647", w = 256, h = 256 },
	Dots = { id = "85128683768553", w = 128, h = 128 },
}

-- LAYOUT --------------------------------------------------------------------
-- Authored against the same ~710 px reference height as every machine screen,
-- so MachineLayout's UIScale carries the menu with no second scaling rule.
Menu.Layout = {
	TitleX = 64,
	TitleY = 96,
	TitleW = 560,     -- height follows the image aspect; never distort the mark
	SubGap = 14,      -- from the bottom of the mark to the subtitle
	RowsX = 72,
	RowsY = 300,
	RowW = 420,
	RowH = 40,
	RowGap = 10,
	RowTextX = 34,    -- label inset inside the row
	RowTextSize = 26,
	StreakW = 470,    -- wider than the row: the torn ends must show
	StreakOverhang = 1.15, -- of RowH, centred -- the bar breaks the row's line
	StreakX = -22,    -- relative to RowsX
	BulletX = 12,
	DetailX = 0.60,   -- scale
	DetailY = 300,
	DetailW = 0.30,   -- scale
	DetailH = 190,
	CellW = 112,
	CellH = 38,
	CellGap = 10,
	CellsX = 64,
	CellsFromBottom = 78,
	TickInset = 28,
	TickLen = 14,
}

-- Mobile trims. The user reported the phone UI reading too large (24.08.), so
-- the menu starts smaller there rather than being scaled down after the fact.
Menu.Mobile = {
	TitleW = 400,
	RowH = 46,        -- >= 44 pt touch floor
	RowTextSize = 20,
	RowW = 330,
	StreakW = 372,
	Cells = 2,        -- drop the third status cell
	DetailHidden = true, -- no room for the detail card next to the rows
}

-- ENTRIES -------------------------------------------------------------------
-- `id` is what MainMenu switches on. `detail` fills the right-hand card, in the
-- machine's voice: flat, imperative, no punctuation games.
Menu.Entries = {
	{
		id = "enter",
		label = "ENTER FACILITY",
		detail = {
			"JOIN THE ACTIVE CYCLE.",
			"THE MACHINE PICKS THE",
			"SIMULATION. NOT YOU.",
		},
	},
	{
		id = "briefing",
		label = "BRIEFING",
		detail = {
			"WHAT THE THREE",
			"SIMULATIONS WANT, AND",
			"WHAT THEY PAY.",
		},
	},
	{
		id = "settings",
		label = "SETTINGS",
		detail = {
			"SOUND, MUSIC, FLICKER,",
			"FILTER, GLASS, SHAKE.",
			"ALL OF IT OPTIONAL.",
		},
	},
	{
		id = "personnel",
		label = "PERSONNEL FILE",
		detail = {
			"YOUR RECORD FOR THIS",
			"SESSION. THE MACHINE",
			"KEEPS NOTHING LONGER.",
		},
	},
}

-- BOOT ----------------------------------------------------------------------
-- Beats counted in STEPS of FeelConfig's 12 fps grid, not in seconds: written
-- as decimals they drifted off the grid (0.15 s is 1.8 steps) and the assembly
-- stuttered against every other stepped writer. Steps make the grid structural
-- instead of something to check afterwards -- the client multiplies by
-- Feel.stepSeconds(). Budget stays in seconds: it is a feel limit, not a beat.
Menu.Boot = {
	Dither = 0,
	Chrome = 2,
	Title = 3,
	Rows = 6,
	RowStagger = 1,
	Streak = 13,
	Hint = 16,
	Budget = 1.80,
}

-- Title punch: one step at PunchScale, then 1.0, with a chromatic split that
-- collapses over ChromaSteps steps of the grid.
Menu.Title = { PunchScale = 1.06, ChromaPx = 3, ChromaSteps = 3 }

-- Streak travel: STEPS of the grid, with one step of overshoot past the target
-- before it settles. Under ReducedMotion the client jumps straight there.
Menu.Streak = { Steps = 2, OvershootPx = 6 }

-- Idle life. None of it is per-frame: every writer below runs on the step grid
-- and writes only when its value actually changed.
Menu.Idle = {
	ParallaxPx = 3,      -- shards drift this far on X
	ParallaxPyY = 2,     -- ... and this far on Y
	ParallaxPeriod = 8,  -- seconds for one there-and-back
	DollyStuds = 2,      -- camera travel on X across the stage
	DollyPeriod = 20,
	ClockHz = 1,
}

-- World position of a stage point ({x,y,z} local) with the Origin applied.
-- Returns three numbers so the client can build a Vector3 without this module
-- ever touching a Roblox type (it has to load under plain Lua for the tests).
function Menu.stagePoint(p)
	local o = Menu.Stage.Origin
	return p[1] + o[1], p[2] + o[2], p[3] + o[3]
end

-- THE STAGE ------------------------------------------------------------------
-- The set behind the menu is the user's OWN `workspace.MenuStage` from
-- Kenopsia_DEV, measured out of that place on 25.08.2026 and transcribed here
-- so the main game can rebuild it without the two places having to share a
-- workspace. Coordinates are exactly the DEV ones; Origin is added to each, so
-- the set lands far above the arenas -- no replication (it is built on the
-- client), no collisions, nothing for a runner to find.
--
-- Its own geometry encloses the camera's view: the floor runs to z 25.4 and the
-- four stepped wall slabs stand at z 25.9-28.9 across the full width, so no
-- skybox is ever in frame and the menu needs no shell of its own. That is why
-- the grade preset asks for a blank sky rather than a pretty one.
--
-- Dropped from the DEV set on purpose: `Wall` (behind the camera, never in
-- frame), `SessionDisplay` and `SessionCamera` (markers for that prototype's
-- session board, which this menu does not have).
Menu.Stage = {
	Origin = { 0, 3000, 0 },
	Parts = {
		{ name = "Floor", size = { 109, 1, 33 }, pos = { 143.3, 0.5, 8.9 }, rot = { 0, 0, 0 },
			color = { 237, 234, 234 }, material = "Asphalt" },
		-- four slabs, each stepped one stud further back as it rises
		{ name = "Wall_03", size = { 113, 1, 10 }, pos = { 145.3, 4, 25.9 }, rot = { 90, 0, 0 },
			color = { 237, 234, 234 }, material = "Concrete" },
		{ name = "Wall_01", size = { 113, 1, 10 }, pos = { 143.3, 12, 26.9 }, rot = { 90, 0, 0 },
			color = { 237, 234, 234 }, material = "Concrete" },
		{ name = "Wall_02", size = { 113, 1, 10 }, pos = { 143.3, 19, 27.9 }, rot = { 90, 0, 0 },
			color = { 237, 234, 234 }, material = "Concrete" },
		{ name = "Wall_04", size = { 113, 1, 10 }, pos = { 143.3, 27, 28.9 }, rot = { 90, 0, 0 },
			color = { 237, 234, 234 }, material = "Concrete" },
	},
	-- Three lamps, the DEV values kept: a warm key on the landing, an amber one
	-- on the figure, a cold one washing the back wall. `blink` marks the one
	-- that acknowledges a selection move.
	Lights = {
		{ name = "Lamp_Landing", pos = { 139, 10, 14 }, brightness = 1.2, range = 18,
			color = { 216, 208, 190 } },
		{ name = "Lamp_Character", pos = { 131.5, 9.5, 14 }, brightness = 1.6, range = 24,
			color = { 210, 169, 74 }, blink = true },
		{ name = "Lamp_SessionWall", pos = { 139, 9, 23 }, brightness = 1.4, range = 20,
			color = { 96, 114, 122 } },
	},
	-- LandingCamera: looks along +Z and 14 degrees down. The figure stands at
	-- -X of it, which the camera sees on its RIGHT -- so the subject fills the
	-- right of the screen and the menu column has the left to itself.
	Cam = { pos = { 135.2, 8, 2.4 }, rot = { -14.289, 175.73, 0 } },
	CharacterAnchor = { 129.6, 4, 15.1 },
	-- The figure faces the camera rather than the way the anchor happens to
	-- point (the marker's own rotation is identity).
	CharacterFaceCam = true,
	Fov = 70,
	LampBlink = 0.12, -- seconds the character lamp drops when the selection moves
}

-- BRIEFING ------------------------------------------------------------------
-- Wakes KenopsiaMachine.Briefing, which is fully authored in the place and
-- shown by nothing (found 25.08.2026). Five rows per page, which is exactly
-- what BriefList holds. Original copy -- REQ-IP-01.
Menu.Briefing = {
	{
		title = "BRIEFING",
		lines = {
			"YOU ARE A SUBJECT. THE MACHINE CHOOSES.",
			"THREE SIMULATIONS PER CYCLE. POINTS CARRY.",
			"DEAD ZONE - CROSS THE FIELD. ONE MINE MAIMS.",
			"BIRD HUNTING - ONE HUNTER ABOVE. THE REST RUN.",
			"CANTEEN PROTOCOL - EAT. NEVER WHILE WATCHED.",
		},
	},
	{
		title = "SCORING",
		lines = {
			"SURVIVING PAYS MORE THAN HURRYING.",
			"DISTANCE COUNTS EVEN WHEN YOU DO NOT FINISH.",
			"THE HUNTER IS PAID PER SUBJECT PROCESSED.",
			"THE HIGHEST TOTAL AFTER THREE IS VIABLE.",
			"A TIE IS NOT BROKEN. BOTH ARE VIABLE.",
		},
	},
}

-- PERSONNEL FILE ------------------------------------------------------------
-- Every row is read from an attribute the server already sets (MachineFlow):
-- no new remote, no new server code. `attr = nil` means the client fills it.
Menu.Personnel = {
	{ label = "SUBJECT", attr = nil },
	{ label = "DESIGNATION", attr = nil },
	{ label = "CYCLE SCORE", attr = "KenopsiaSessionScore", format = "%04d" },
	{ label = "VERDICTS", attr = "KenopsiaSessionWins", format = "%d" },
	{ label = "PROCESSED", attr = "KenopsiaProcessed", format = "%d" },
	{ label = "IN FACILITY", attr = nil },
	{ label = "STATUS", attr = nil },
}

-- HELPERS -------------------------------------------------------------------

-- House style: machine labels are letter-spaced ("R E A D Y" on Btn_READY).
-- A run of spaces in the source stays a run: "PERSONNEL FILE" must not close
-- up into one word.
function Menu.spaced(s)
	local out = {}
	for i = 1, #s do
		out[#out + 1] = string.sub(s, i, i)
	end
	return table.concat(out, " ")
end

-- Top of row `i` (1-based) in the rows frame's own coordinates.
function Menu.rowY(i, mobile)
	local h = mobile and Menu.Mobile.RowH or Menu.Layout.RowH
	return (i - 1) * (h + Menu.Layout.RowGap)
end

-- Where the streak sits for row `i`: it overhangs the row, centred.
function Menu.streakY(i, mobile)
	local h = mobile and Menu.Mobile.RowH or Menu.Layout.RowH
	local sh = h * Menu.Layout.StreakOverhang
	return Menu.rowY(i, mobile) - (sh - h) / 2
end

function Menu.streakH(mobile)
	local h = mobile and Menu.Mobile.RowH or Menu.Layout.RowH
	return h * Menu.Layout.StreakOverhang
end

-- Entry index by id, or nil.
function Menu.indexOf(id)
	for i = 1, #Menu.Entries do
		if Menu.Entries[i].id == id then return i end
	end
	return nil
end

-- Wrap a selection move: 1 -> #Entries and back, so a d-pad held down cycles
-- instead of sticking at the ends.
function Menu.step(index, delta)
	local n = #Menu.Entries
	local i = index + delta
	while i < 1 do i = i + n end
	while i > n do i = i - n end
	return i
end

-- The subject's file number: stable for a player, meaningless to anyone else.
function Menu.designation(userId)
	local n = math.floor(math.abs(tonumber(userId) or 0)) % 10000
	return string.format("S-%04d", n)
end

-- hh:mm:ss for the session clock and the personnel file.
function Menu.clock(seconds)
	local s = math.floor(math.max(0, seconds))
	return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

-- The last beat of the boot sequence in STEPS, including the row stagger.
function Menu.bootSteps()
	local rows = Menu.Boot.Rows + (#Menu.Entries - 1) * Menu.Boot.RowStagger
	local last = Menu.Boot.Hint
	if rows > last then last = rows end
	if Menu.Boot.Streak > last then last = Menu.Boot.Streak end
	return last
end

-- ... and in seconds, given the grid's step length (Feel.stepSeconds()).
-- tests/menu.lua asserts this stays under Menu.Boot.Budget.
function Menu.bootSeconds(stepSeconds)
	return Menu.bootSteps() * stepSeconds
end

return Menu
