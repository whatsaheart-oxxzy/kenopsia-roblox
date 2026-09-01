--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.KenopsiaServer.Services
local RoomService = require(Services.RoomService)
local MachineFlow = require(Services.MachineFlow)
local CharacterService = require(Services.CharacterService)
local Telemetry = require(Services.Telemetry)
local Profiles = require(Services.Profiles)
local EmoteService = require(Services.EmoteService)
local CrateService = require(Services.CrateService)
local PromoService = require(Services.PromoService)
local Lobby = require(Services.Lobby)
local SoloExit = require(Services.SoloExit)

Lobby.start() -- 31.08.2026: baut Warteraum + workspace.SpawnLocation, falls sie fehlen. MUSS zuerst laufen: CharacterAutoLoads spawnt den ersten Spieler sofort, und ohne SpawnLocation faellt er ins Nichts
SoloExit.start() -- 31.08.2026: wer allein zurueckbleibt, faehrt sofort ins MainMenu-Place zurueck
RoomService.start() -- creates ReplicatedStorage.Kenopsia.Remotes; everything below waits on it
Telemetry.start()
Profiles.start() -- Phase 4a: volatile-first profiles; loaded before MachineFlow can reach a verdict
EmoteService.start(RoomService) -- Phase 5: emote/gamepass socket; needs the Remotes folder, the profiles it reads, and the room it gates on
CrateService.start(RoomService, EmoteService) -- Supply screens: the DECRYPT ceremony; reuses EmoteService.grant, so it boots after it
PromoService.start(EmoteService) -- Access codes (D-C): ships with an EMPTY code table; rows are added in PromoService itself
CharacterService.start()
MachineFlow.start(RoomService)

print("[Kenopsia] server ready (main game)")
