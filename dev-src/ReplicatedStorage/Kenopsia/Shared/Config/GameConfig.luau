--!strict
return {
	ProjectName = "Kenopsia",
	Version = "0.1.0",

	-- StudioTestMinimum was removed. It let Studio start a room with one player
	-- while production required two, so the environment used for testing was the
	-- one environment where the READY rule did not apply. Room.MinPlayers below
	-- is now the single source of truth, in Studio and in production alike.
	Players = {
		MinimumForMatch = 2,
		MaximumPerServer = 8,
	},

	LaunchTrialCount = 3,

	Room = {
		MaxPlayers = 4,
		MinPlayers = 2,
		CodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",
		CodeLength = 6,
		RoomTtlSeconds = 3600,
		ClaimAttempts = 6,
		RequireAllReady = true,
	},

	Playlist = {
		TrialIds = { "canteen_protocol", "quality_control", "target_calibration" },
		PlacementPoints = { 3, 2, 1, 0 },
	},

	MemoryStore = {
		RoomMapName = "KenopsiaRooms_v1",
	},
}
