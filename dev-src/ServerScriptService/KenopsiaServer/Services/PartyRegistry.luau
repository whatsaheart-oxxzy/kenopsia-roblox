--!nonstrict

local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Kenopsia.Shared.Config.GameConfig)

local PartyRegistry = {}

local IS_STUDIO = RunService:IsStudio()

local localStore: { [string]: any } = {}

local map
if not IS_STUDIO then
	local ok, result = pcall(function()
		return MemoryStoreService:GetHashMap(Config.MemoryStore.RoomMapName)
	end)
	if ok then map = result else warn("[PartyRegistry] MemoryStore unavailable: " .. tostring(result)) end
end

function PartyRegistry.isStudioFallback(): boolean
	return map == nil
end

local function randomCode(): string
	local alphabet = Config.Room.CodeAlphabet
	local out = table.create(Config.Room.CodeLength)
	for i = 1, Config.Room.CodeLength do
		local n = math.random(1, #alphabet)
		out[i] = string.sub(alphabet, n, n)
	end
	return table.concat(out)
end

-- Claim a free code for a reservation. Returns code, or nil plus a reason.
function PartyRegistry.claim(accessCode: string, privateServerId: string): (string?, string?)
	local entry = {
		accessCode = accessCode,
		privateServerId = privateServerId,
		placeId = game.PlaceId,
		createdAt = os.time(),
	}

	for _ = 1, Config.Room.ClaimAttempts do
		local code = randomCode()

		if map == nil then
			if localStore[code] == nil then
				localStore[code] = entry
				return code, nil
			end
		else
			local ok, won = pcall(function()
				local claimed = false
				map:UpdateAsync(code, function(existing)
					if existing ~= nil then
						return nil -- taken; abort without overwriting
					end
					claimed = true
					return entry
				end, Config.Room.RoomTtlSeconds)
				return claimed
			end)

			if not ok then
				return nil, "MEMORYSTORE UNAVAILABLE"
			elseif won then
				return code, nil
			end
			-- Lost the race on this code; loop and try another.
		end
	end

	return nil, "COULD NOT ALLOCATE A CODE"
end

-- Server-side only. The returned table contains the access code.
function PartyRegistry.lookup(code: string): (any?, string?)
	if type(code) ~= "string" or #code ~= Config.Room.CodeLength then
		return nil, "INVALID CODE"
	end
	code = string.upper(code)

	if map == nil then
		local entry = localStore[code]
		return entry, entry and nil or "NO SUCH SESSION"
	end

	local ok, entry = pcall(function() return map:GetAsync(code) end)
	if not ok then
		return nil, "MEMORYSTORE UNAVAILABLE"
	end
	if entry == nil then
		return nil, "NO SUCH SESSION"
	end
	return entry, nil
end

-- Free a code the moment its room empties, so short codes stay scarce-free.
function PartyRegistry.release(code: string)
	if type(code) ~= "string" then return end
	code = string.upper(code)
	if map == nil then
		localStore[code] = nil
		return
	end
	pcall(function() map:RemoveAsync(code) end)
end

function PartyRegistry.touch(code: string)
	if map == nil or type(code) ~= "string" then return end
	pcall(function()
		map:UpdateAsync(string.upper(code), function(existing)
			return existing -- rewrite unchanged, purely to reset the TTL
		end, Config.Room.RoomTtlSeconds)
	end)
end

return PartyRegistry
