--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.KenopsiaServer.Services
local RoomService = require(Services.RoomService)
local PlaylistService = require(Services.PlaylistService)

RoomService.start()
PlaylistService.start(RoomService)

print("[Kenopsia] server ready")
