--!strict
-- Every tunable in the game lives here. Gameplay iteration should never mean
-- editing a service, so if you find yourself hardcoding a number in RoundService
-- or a minigame, it belongs in this file instead.

local Config = {}

-- Match shape ---------------------------------------------------------------

Config.MaxPlayers = 8
Config.MinPlayers = 2
Config.RoundsPerMatch = 5

-- Phase durations in seconds. These drive the round state machine directly.
Config.Phase = {
	Intermission = 12,
	Announce = 4,
	Load = 1.5,
	Countdown = 3,
	Score = 6,
	Results = 15,
}

-- Scoring -------------------------------------------------------------------
-- Kept deliberately coarse. Round-to-round swings should feel large enough that
-- a bad round hurts, but never so large that round 5 is the only one that counts.

Config.Score = {
	RecallPerCorrect = 100,
	GratePerRow = 25,
	GrateFinishBonus = 200,
	LinePerPedestal = 150,
	LineFirstBonus = 100,
}

-- RECALL --------------------------------------------------------------------

Config.Recall = {
	GridWidth = 5,
	GridHeight = 3,
	MemorizeTime = 7,
	RecallTime = 25,

	-- How many cells get blanked, indexed by round number. Clamps to the last
	-- entry, so round 9 uses the same difficulty as round 5.
	BlanksByRound = { 3, 4, 5, 6, 7 },

	-- Wrong-answer icons mixed into the candidate tray alongside the correct
	-- ones. Higher = harder, but past ~6 the tray stops being readable.
	DecoyCount = 4,

	-- Anti-spam. A legitimate player cannot tap faster than this.
	SubmitsPerSecond = 8,
}

-- THE GRATE -----------------------------------------------------------------

Config.Grate = {
	Width = 6,
	Length = 24,
	PadSize = Vector3.new(8, 1, 8),
	PadGap = 0.4,

	-- Safe pads per row. One of them always continues the true path; the rest
	-- are dead ends, which is where the tension comes from.
	SafePerRow = 2,

	-- Seconds the full safe path is revealed before the round starts.
	-- Set to 0 to make it pure trial-and-error instead of a memory test.
	FlashTime = 2.0,

	PlayTime = 60,
	PollRate = 15, -- Hz, server-side occupancy sampling
}

-- THE LINE ------------------------------------------------------------------

Config.Line = {
	PedestalCount = 5,
	DecoyItems = 6,
	PlayTime = 75,

	-- Seconds a player is locked out after submitting the wrong item.
	WrongPenalty = 2.0,

	-- Studs. Must match the ProximityPrompt MaxActivationDistance.
	InteractRange = 10,
}

-- Presentation --------------------------------------------------------------

Config.Colors = {
	PadNeutral = Color3.fromRGB(58, 58, 54),
	PadSafe = Color3.fromRGB(96, 168, 88),
	PadUnsafe = Color3.fromRGB(150, 46, 40),
	PadFlash = Color3.fromRGB(178, 196, 150),
	Accent = Color3.fromRGB(120, 200, 110),
	Warn = Color3.fromRGB(190, 70, 55),
}

-- Set true to log every phase transition and minigame result to the output
-- window. Leave on until the loop has survived a long unattended soak test.
Config.Verbose = true

return table.freeze(Config)
