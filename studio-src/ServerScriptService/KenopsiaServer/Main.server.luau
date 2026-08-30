--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.KenopsiaServer.Services
local RoomService = require(Services.RoomService)
local MachineFlow = require(Services.MachineFlow)
local CharacterService = require(Services.CharacterService)
local Telemetry = require(Services.Telemetry)
local Profiles = require(Services.Profiles)

RoomService.start() -- creates ReplicatedStorage.Kenopsia.Remotes; everything below waits on it
Telemetry.start()
Profiles.start() -- Phase 4a: volatile-first profiles; loaded before MachineFlow can reach a verdict
CharacterService.start()
MachineFlow.start(RoomService)

print("[Kenopsia] server ready (main game)")
