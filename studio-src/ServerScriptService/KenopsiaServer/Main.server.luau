--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.KenopsiaServer.Services
local RoomService = require(Services.RoomService)
local MachineFlow = require(Services.MachineFlow)
local CharacterService = require(Services.CharacterService)
local Telemetry = require(Services.Telemetry)
local Profiles = require(Services.Profiles)
local EmoteService = require(Services.EmoteService)

RoomService.start() -- creates ReplicatedStorage.Kenopsia.Remotes; everything below waits on it
Telemetry.start()
Profiles.start() -- Phase 4a: volatile-first profiles; loaded before MachineFlow can reach a verdict
EmoteService.start(RoomService) -- Phase 5: emote/gamepass socket; needs the Remotes folder, the profiles it reads, and the room it gates on
CharacterService.start()
MachineFlow.start(RoomService)

print("[Kenopsia] server ready (main game)")
