--!nonstrict
-- UPSTREAM client -- FRAMEWORK STUB (MP-05 D13). The implementer overwrites
-- this whole file. Contract (docs/MP-06-FRAMEWORK.md):
--   init(kit)     once per client lifetime; capture kit, build nothing
--   onPacket(p)   every {kind="trial", trialId="upstream"} packet (begin
--                 included; end is delivered as onEnd) plus observed generic
--                 kinds count/go/announce/hide/gorefx/role (read-only copies)
--   onEnd()       clear module tables; the router tears the rest down
--   controlsText  what the CONTROLS window shows for this trial
--
-- REQ-IP-01: original id "upstream" / display "UPSTREAM"; no reference-game
-- name in this file.
local M = {}

local kit = nil

M.controlsText = {
	title = "UPSTREAM",
	sec1 = "PLAYERS:", sec2 = "RULE:",
	lines = { "Move", "READ THE ARROWS. CLIMB.", "", "" },
}

function M.init(k)
	kit = k
end

function M.onPacket(p)
	if not kit then return end
	if p.kind == "trial" and p.ev == "begin" then
		-- Stub round: top-down follow camera, no HUD, no input.
		kit.camera.top({ height = 24, back = 9 })
	elseif p.kind == "go" then
		kit.movement.set(16)
	end
end

function M.onEnd()
end

return M
