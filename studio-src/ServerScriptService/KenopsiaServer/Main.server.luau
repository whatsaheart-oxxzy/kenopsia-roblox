--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.KenopsiaServer.Services
local RoomService = require(Services.RoomService)
local MachineFlow = require(Services.MachineFlow)
local CharacterService = require(Services.CharacterService)
local Telemetry = require(Services.Telemetry)

RoomService.start() -- creates ReplicatedStorage.Kenopsia.Remotes; everything below waits on it
Telemetry.start()
CharacterService.start()
MachineFlow.start(RoomService)

print("[Kenopsia] server ready (main game)")
