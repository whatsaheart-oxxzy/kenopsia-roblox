# X1-four-player-cap -- PARTIAL

UPPER BOUND (room) holds. LOWER BOUND (2) holds only on live servers.
- studio-src RoomService:93-98 minPlayers() -> StudioTestMinimum=1 in Studio. LIVE-confirmed via weppy get_source.
- dev-src RoomService.forceStart:316-318 -> beginCountdown:270 has NO min check.
  Caller: PlaylistService:209-220 remote "TrialPracticeRequest". No repo client fires it.
- Server capacity (Players.MaxPlayers) is a Dashboard setting, unreadable. Docs attest 4 (MainGame) / 28 (DEV).
- GameConfig.Players.MaximumPerServer / MinimumForMatch are read by NO code in either tree.
- MachineFlow:1366 hardcodes `4 - #room.members`.
