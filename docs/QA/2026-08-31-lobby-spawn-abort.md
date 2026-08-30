# QA - Lobby spawn + abort system (31.08.2026)

User report: "no spawnpoint and it ends up in air" in every trial; the abort
"only says a text, and the game continues".

## Root cause (measured in Play)

The place had NO SpawnLocation. Four services (TrialKit 846, Podium 151,
Minefield 613, BirdHunting 433) have always looked up
`workspace:FindFirstChild("SpawnLocation")` and fell back to (0,5,0) - open
void. A joining character spawned at the engine default (0,103,0), fell,
was destroyed at FallenPartsDestroyHeight -500 and the respawn never took:
the whole session ran with `player.Character == nil` - trials cycled empty
rounds while the client floated in fog. Removing the podium had also removed
the only return-home teleport (Podium.strike).

## What shipped

1. **`Workspace.KenopsiaLobby`** (place geometry, NOT in the repo - it lives
   in the .rbxl): a sealed 44x44 holding cell at the origin (slate blues,
   one neon ceiling lamp + PointLight, everything anchored, CastShadow off)
   with **`Workspace.SpawnLocation`** (direct child, Neutral, Duration 0) at
   (0,0.5,0) - exactly where all four services have always pointed.
2. **MachineFlow.cleanup(): everyone goes home on every route** (verdict,
   abort, error) - each member's root unanchored, velocity zeroed, teleported
   to the spawn +-6 studs.
3. **MachineFlow.runRoundGuarded: the watchdog poll also watches
   `room.aborting`** and cuts a running round within 0.1 s of an abort, then
   runs the same teardown hooks as the timeout route. Before this, an abort
   only bumped the token and the round played its full 62 s ("the game
   continues").
4. **NEW `StarterPlayerScripts/AbortScreen.client.luau`**: on any LobbyError
   beginning "RUN ABORTED" (only abortMatch sends that prefix), full black
   screen + the reason in red mono, PlayerModule controls disabled AND chat
   input bar off (no moving, no typing), 5 s, then released - the lobby is
   already cleaned up and re-homed underneath. Lobby-side refusals keep
   their old feed-line behaviour.

## Verified IN PLAY (solo, StudioTestMinimum=1)

- Spawn: character at (0,4.8,0), velocity 0, stable for 8 s. No death loop.
- Trial teleports all work now: birdhunt corridor (-11,6,429) with the world
  RENDERING and the HUD live (LEG 1/3, timer, HEADBUTT prompt - screenshot),
  canteen seat (-98,7,-13), minefield corridor (-165,5,-1637).
- Abort card: fired the exact server message at the client - full black +
  "RUN ABORTED - PLAYER LEFT - CANNOT CONTINUE WITH A SINGLE PLAYER"
  (screenshot), card gone and controls restored after 5 s.
- Session end: character back on the lobby platform at (3,5,-2).

## Still needs 2 players (test debt)

The real abort chain end-to-end (player disconnects -> removeMember ->
abortMatch -> round cut -> black card on the SURVIVOR -> lobby): every link
is individually verified, but the full chain needs a second live player.

## IMPORTANT - place data

The lobby is GEOMETRY in the open place. It exists only in Studio memory
until the user saves. **Save & Publish is required** for any of this session
(and the whole inner-game build) to reach production.
