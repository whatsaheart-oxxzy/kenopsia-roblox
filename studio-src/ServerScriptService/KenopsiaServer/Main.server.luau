--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.KenopsiaServer.Services
local RoomService = require(Services.RoomService)
local MachineFlow = require(Services.MachineFlow)

RoomService.start()
MachineFlow.start(RoomService)

print("[Kenopsia] server ready (main game)")
