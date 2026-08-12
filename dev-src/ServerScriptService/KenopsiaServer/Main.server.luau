--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.KenopsiaServer.Services
local RoomService = require(Services.RoomService)
local PlaylistService = require(Services.PlaylistService)
local MenuPresenceService = require(Services.MenuPresenceService)

RoomService.start()
PlaylistService.start(RoomService)
-- Started after RoomService so roomOf() is live before the first character
-- binds, and after PlaylistService so a run already in flight is not treated
-- as a menu state.
MenuPresenceService.start(RoomService)

print("[Kenopsia] server ready")
