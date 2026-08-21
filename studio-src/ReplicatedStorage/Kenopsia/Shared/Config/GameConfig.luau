--!strict
-- Phase 1: one canonical room per server, 2-4 players.
-- The multi-room lobby model is retired; RoomService keeps compatibility
-- shims for the old create/join/quick remotes so existing clients still
-- resolve to the single canonical room instead of erroring.
return {
	ProjectName = "Kenopsia",
	Version = "0.3.0",

	Players = {
		-- Published capacity must match this. Players.MaxPlayers is read-only
		-- to scripts and plugins; it is set in Studio via
		-- File > Game Settings > Places > Server Size. See PHASE1 report.
		MaximumPerServer = 4,
		MinimumForMatch = 2,
		-- Studio solo/debug path only; never used on a live server.
		StudioTestMinimum = 1,
	},

	Room = {
		MaxPlayers = 4,
		MinPlayers = 2,
		RequireAllReady = true,
		-- Retained only so the legacy join-by-code shim can validate a payload
		-- shape without erroring. No codes are issued in the canonical model.
		CodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",
		CodeLength = 6,
	},

	Playlist = {
		-- Candidate trials. A trial is scheduled only if it appears here AND
		-- its registry entry in MachineFlow declares ready = true. Both gates
		-- must pass, so an unfinished trial cannot reach the roulette.
		-- "canteen" joins this list when REQ-CP-01..04 are complete. It is NOT
		-- spelled with the reference game's name for that minigame; that name
		-- is the copyright exposure REQ-IP-01 exists to remove, and it appears
		-- nowhere in shipped source, comments included.
		--
		-- MP-05: the twelve new ids are listed from the Framework stage on. Each
		-- stays unschedulable until its registry entry flips ready = true in the
		-- Integrate stage (the second gate), so listing them here leaks nothing.
		TrialIds = {
			"birdhunt", "minefield", "canteen",
			"carve", "armory", "upstream", "floorcheck", "clearance", "carrier",
			"breather", "sweep", "crawler", "ricochet", "stacker", "sorting",
		},
		PlacementPoints = { 3, 2, 1, 0 },
		-- D7: how many trials one session plays. playableOrder(seed) takes the
		-- first PerSession ENABLED ids of Playlist.order(seed); 0 or nil = all.
		-- Fifteen trials at ~2 min each is not a party game.
		PerSession = 5,
	},

	-- D4: where the twelve procedural arenas stand. Floor level is Y = 0 (each
	-- arena builds its own 1-stud slab whose top is the origin's Y). Off the
	-- 2048 baseplate, > 1200 studs from existing content, > 480 (FogEnd) apart.
	-- TrialKit.ensureArena reads Origins[trialId]; a missing id is a warn + nil.
	Arenas = {
		Origins = {
			carve = Vector3.new(1400, 0, -900), armory = Vector3.new(1400, 0, -300),
			upstream = Vector3.new(1400, 0, 300), floorcheck = Vector3.new(1400, 0, 900),
			clearance = Vector3.new(1900, 0, -900), carrier = Vector3.new(1900, 0, -300),
			breather = Vector3.new(1900, 0, 300), sweep = Vector3.new(1900, 0, 900),
			crawler = Vector3.new(2400, 0, -900), ricochet = Vector3.new(2400, 0, -300),
			stacker = Vector3.new(2400, 0, 300), sorting = Vector3.new(2400, 0, 900),
		},
		MaxFootprint = 200, MaxHeight = 120,
	},

	Match = {
		-- Hold the final cumulative board before returning to Waiting.
		FinalBoardHold = 12,
		-- Countdown from Waiting -> Playing once everyone is ready.
		StartCountdown = 3,
	},
}
