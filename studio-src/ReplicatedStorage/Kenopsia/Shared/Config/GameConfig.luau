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
		TrialIds = { "birdhunt", "minefield", "canteen" },
		PlacementPoints = { 3, 2, 1, 0 },
	},

	Match = {
		-- Hold the final cumulative board before returning to Waiting.
		FinalBoardHold = 12,
		-- Countdown from Waiting -> Playing once everyone is ready.
		StartCountdown = 3,
	},
}
