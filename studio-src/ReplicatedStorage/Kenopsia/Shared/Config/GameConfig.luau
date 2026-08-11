--!strict
return {
	ProjectName = "Kenopsia",
	Version = "0.2.0",

	Players = {
		MinimumForMatch = 2,
		MaximumPerServer = 28,
		StudioTestMinimum = 1,
	},

	Room = {
		MaxPlayers = 4,
		MinPlayers = 2,
		CodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",
		CodeLength = 6,
		RequireAllReady = true,
	},

	Playlist = {
		TrialIds = { "birdhunt", "minefield" },
		PlacementPoints = { 3, 2, 1, 0 },
	},
}
