--!strict
return {
	ProjectName = "Kenopsia",
	Version = "0.1.0",

	Players = {
		MinimumForMatch = 2,
		MaximumPerServer = 8,
		StudioTestMinimum = 1,
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
