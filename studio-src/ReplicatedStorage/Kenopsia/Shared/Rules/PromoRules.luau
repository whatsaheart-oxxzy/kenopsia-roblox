--!nonstrict
-- PROMO RULES (01.09.2026) -- access-code arithmetic, pure and provable.
--
-- Decision D-C: the code surface ships NOW, the code rows come later. So the
-- table of live codes does NOT live here -- it lives inside Services/
-- PromoService, server-side only, exactly because "Codes nie im Client
-- speichern" (the spec's own server-authority rule): anything in
-- ReplicatedStorage replicates, and a replicated code list is a redeemed code
-- list. This module holds only the pure decisions, so tests/supply.lua can
-- prove them offline and the client can pre-validate FORMAT (never validity).
--
-- PURE (the CrateRules discipline): no Roblox globals, no requires, no clock
-- reads -- `now` comes in as an argument. Lua 5.1 subset.

local PromoRules = {}

PromoRules.MIN_LENGTH = 3
PromoRules.MAX_LENGTH = 24

-- The canonical form both sides agree on: SHOUTED alphanumerics. Spaces,
-- dashes and underscores are typing noise and are stripped; anything else
-- left over means the input is not a code at all -> nil. A nil answer is the
-- client's cue to shake the field without ever asking the server.
function PromoRules.normalize(text)
	if type(text) ~= "string" then return nil end
	local upper = string.upper(text)
	local stripped = string.gsub(upper, "[%s%-_]", "")
	if string.find(stripped, "[^A-Z0-9]") then return nil end
	if #stripped < PromoRules.MIN_LENGTH or #stripped > PromoRules.MAX_LENGTH then return nil end
	return stripped
end

-- The whole redeem decision, in the order the widget's states expect:
-- INVALID (not a known code) -> USED (this player already burned it) ->
-- EXPIRED (past its window) -> OK. `rows` is the server's code table,
-- `redeemed` the player's redeemed set, `now` os.time at the call site.
function PromoRules.status(rows, redeemed, code, now)
	local row = type(rows) == "table" and type(code) == "string" and rows[code] or nil
	if type(row) ~= "table" then return "INVALID" end
	if type(redeemed) == "table" and redeemed[code] == true then return "USED" end
	local expires = tonumber(row.expires)
	if expires and tonumber(now) and now > expires then return "EXPIRED" end
	return "OK"
end

return PromoRules
