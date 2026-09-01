--!nonstrict
-- PROMO SERVICE (01.09.2026) -- access codes. SHIPS DORMANT (decision D-C:
-- the surface now, the rows later).
--
-- THE CODE TABLE LIVES HERE AND ONLY HERE. Not in Shared/Config: anything in
-- ReplicatedStorage replicates to every client, and a replicated code list is
-- a redeemed code list. The client can pre-check FORMAT through the pure
-- Shared/Rules/PromoRules (which holds no codes); validity is answered only
-- by this file. While CODES is empty every redeem answers INVALID before any
-- DataStore is touched -- the Badges id-0 dormancy pattern, applied to codes.
--
-- ADDING A CODE IS ONE ROW HERE. Nothing else changes:
--
--     CODES.LAUNCH26 = {
--         reward = { keys = 1 },                   -- and/or fragments = n,
--         -- emotes = { "blow_kiss" },             -- and/or catalog ids
--         expires = os.time({ year = 2026, month = 12, day = 31 }), -- optional
--     },
--
-- DOUBLE-REDEEM DISCIPLINE. The check-and-mark is ONE UpdateAsync on the
-- player's redeemed set (KenopsiaPromo_v1, u_<id>), so two servers cannot
-- both accept the same code for the same player. On a volatile server (no
-- DataStore, Studio without API) the mark is memory-only for the session --
-- same trade Profiles makes. Rewards are granted AFTER the mark succeeds;
-- a crash between mark and grant costs one code, never mints doubles.
--
-- Rate-gated on entry (the EmoteService rule), plus a per-player in-flight
-- latch because this path YIELDS in UpdateAsync -- without the latch a
-- double-press could interleave around the yield.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kenopsia = ReplicatedStorage:WaitForChild("Kenopsia")
local Rules = Kenopsia:WaitForChild("Shared"):WaitForChild("Rules")
local PromoRules = require(Rules:WaitForChild("PromoRules"))
local EmoteRegistry = require(Kenopsia:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("EmoteRegistry"))
local Profiles = require(script.Parent.Profiles)

local STORE_NAME = "KenopsiaPromo_v1"
local KEY_FORMAT = "u_%d"
local REDEEM_COOLDOWN = 3

-- THE CODES. Empty on purpose -- see the header. Keys are the NORMALIZED form
-- (SHOUTED alphanumerics, PromoRules.normalize), values are reward rows.
local CODES = {}

local PromoService = {}

local started = false
local warned = {}
local EmoteServiceRef = nil
local machineState = nil
local redeemRemote = nil
local store = nil -- nil = volatile: session-memory marks only
local lastAt = {} -- [userId] = os.clock() of the last attempt
local inFlight = {} -- [userId] = true while a redeem is inside its yield
local volatileMarks = {} -- [userId] = { [code] = true }, the no-store fallback

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[PromoService] " .. msg)
end

local function sendResult(player, payload)
	if not machineState or player.Parent ~= Players then return end
	payload.kind = "promoresult"
	pcall(machineState.FireClient, machineState, player, payload)
end

-- One atomic check-and-mark. Returns "OK" | "INVALID" | "USED" | "EXPIRED"
-- | "ERROR". Volatile path decides against the in-memory set instead.
local function checkAndMark(userId, code)
	local now = os.time()
	if store == nil then
		local marks = volatileMarks[userId]
		if not marks then
			marks = {}
			volatileMarks[userId] = marks
		end
		local status = PromoRules.status(CODES, marks, code, now)
		if status == "OK" then marks[code] = true end
		return status
	end
	local status = "ERROR"
	local ok, err = pcall(function()
		store:UpdateAsync(KEY_FORMAT:format(userId), function(stored)
			if type(stored) ~= "table" then stored = {} end
			status = PromoRules.status(CODES, stored, code, now)
			if status ~= "OK" then
				return nil -- cancel the write, keep the stored set untouched
			end
			stored[code] = true
			return stored
		end)
	end)
	if not ok then
		warnOnce("store", "UpdateAsync failed (expected in Studio): " .. tostring(err))
		return "ERROR"
	end
	return status
end

-- The reward, after the mark. Every grant is validated the same way the
-- rest of the codebase validates it: catalog rows through EmoteService.grant
-- (which flushes), wallet through Profiles.grantCrate + one flush.
local function applyReward(userId, row)
	local reward = type(row.reward) == "table" and row.reward or {}
	local keys = math.max(0, math.floor(tonumber(reward.keys) or 0))
	local fragments = math.max(0, math.floor(tonumber(reward.fragments) or 0))
	local emotes = {}
	if type(reward.emotes) == "table" then
		for _, id in ipairs(reward.emotes) do
			if EmoteRegistry.get(id) ~= nil then
				emotes[#emotes + 1] = id
			end
		end
	end
	if keys > 0 or fragments > 0 then
		pcall(Profiles.grantCrate, userId, keys, fragments)
		pcall(Profiles.flush, userId)
	end
	for _, id in ipairs(emotes) do
		if EmoteServiceRef then pcall(EmoteServiceRef.grant, userId, id) end
	end
	return { keys = keys, fragments = fragments, emotes = emotes }
end

local function onRedeem(player, payload)
	if not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	local userId = player.UserId
	local now = os.clock()
	local last = lastAt[userId]
	if last ~= nil and now - last < REDEEM_COOLDOWN then return end
	lastAt[userId] = now
	if inFlight[userId] then return end

	local raw = type(payload) == "table" and payload.code or payload
	local code = PromoRules.normalize(raw)
	if code == nil then
		sendResult(player, { ok = false, reason = "INVALID" })
		return
	end
	-- The dormant fast path: an empty table answers without any store traffic.
	if next(CODES) == nil then
		sendResult(player, { ok = false, reason = "INVALID" })
		return
	end
	if PromoRules.status(CODES, nil, code, os.time()) == "INVALID" then
		sendResult(player, { ok = false, reason = "INVALID" })
		return
	end

	inFlight[userId] = true
	local status = checkAndMark(userId, code)
	inFlight[userId] = nil
	if player.Parent ~= Players then return end

	if status ~= "OK" then
		local reason = (status == "USED" or status == "EXPIRED") and status or "INVALID"
		sendResult(player, { ok = false, reason = reason })
		return
	end
	local granted = applyReward(userId, CODES[code])
	local wallet = Profiles.wallet(userId) or { keys = 0, fragments = 0 }
	sendResult(player, {
		ok = true,
		granted = granted,
		keys = wallet.keys,
		fragments = wallet.fragments,
	})
	Profiles.pushState(userId)
end

-- BOOT ------------------------------------------------------------------------
-- Main runs this after EmoteService (whose grant path rewards reuse).
function PromoService.start(EmoteService)
	if started then return end
	started = true
	EmoteServiceRef = EmoteService

	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warnOnce("volatile", "no DataStore - codes mark in memory only (expected in Studio)")
	end

	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	redeemRemote = folder:FindFirstChild("PromoRedeem")
	if not redeemRemote then
		redeemRemote = Instance.new("RemoteEvent")
		redeemRemote.Name = "PromoRedeem"
		redeemRemote.Parent = folder
	end
	redeemRemote.OnServerEvent:Connect(function(player, payload)
		pcall(onRedeem, player, payload)
	end)

	task.spawn(function()
		local okWait, remote = pcall(function()
			return folder:WaitForChild("MachineState", 30)
		end)
		if okWait and remote then machineState = remote end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		lastAt[plr.UserId] = nil
		inFlight[plr.UserId] = nil
		volatileMarks[plr.UserId] = nil
	end)

	local count = 0
	for _ in pairs(CODES) do
		count = count + 1
	end
	print(("[PromoService] online - %d access code(s) live"):format(count))
end

return PromoService
