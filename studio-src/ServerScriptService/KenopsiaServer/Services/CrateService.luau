--!nonstrict
-- CRATE SERVICE (01.09.2026) -- the DECRYPT ceremony's server half.
--
-- The missing piece between the earned wallet (Profiles.crates, filled by WORK
-- ORDER fragments at the verdict) and the six crate dances that ship dormant in
-- EmoteRegistry: nothing consumed a key until this file. The arithmetic lives
-- in Shared/Rules/CrateRules (pure, proven by tests/supply.lua); this file is
-- only the gates, the spend and the packets -- the EmoteService discipline,
-- applied to one more remote pair.
--
-- SERVER DECIDES, CLIENT ANIMATES. One CrateOpen press does everything here,
-- synchronously: roll the result, spend the key, write the grant, build the
-- reel. The client receives a `crateresult` packet whose reel already CONTAINS
-- the result at SupplyConfig.Crate.RESULT_INDEX and can only animate toward
-- it -- there is no second request the animation could race, and a replayed
-- packet renders the same ceremony.
--
-- NOTHING IS SOLD HERE. Keys are earned (EmoteRegistry's own header: "CRATE
-- KEYS ARE EARNED, NEVER SOLD"), the pool is unowned crate rows only, so a
-- duplicate is impossible and a spent key always yields a new emote; when the
-- collection is complete the client shows COLLECTION COMPLETE and the server
-- refuses before touching the wallet.
--
-- SPEND-THEN-GRANT is safe because nothing between the two yields: Luau runs
-- an event handler to its first yield atomically, so check -> spend -> grant
-- cannot interleave with a second press or a PlayerRemoving. EmoteService.grant
-- carries the flush, which lands the spend and the grant in ONE UpdateAsync.
--
-- LOBBY ONLY, same predicate as EmoteService (RoomService.canonical +
-- isParticipant -- never the trial attributes, which blank between rounds).
-- FAILS CLOSED on every reference that was not handed to start().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kenopsia = ReplicatedStorage:WaitForChild("Kenopsia")
local Config = Kenopsia:WaitForChild("Shared"):WaitForChild("Config")
local Rules = Kenopsia:WaitForChild("Shared"):WaitForChild("Rules")
local EmoteRegistry = require(Config:WaitForChild("EmoteRegistry"))
local SupplyConfig = require(Config:WaitForChild("SupplyConfig"))
local CrateRules = require(Rules:WaitForChild("CrateRules"))
local Profiles = require(script.Parent.Profiles)

-- Longer than the client's own reveal lockout would need, shorter than
-- impatience: one ceremony at a time per player, committed on entry (the
-- EmoteService rateGate rule -- a rejected press costs the same as an
-- accepted one, so rejection never becomes the cheap spam path).
local OPEN_COOLDOWN = 3
local SYNC_COOLDOWN = 2

local CrateService = {}

local started = false
local warned = {}
local RoomServiceRef = nil
local EmoteServiceRef = nil
local machineState = nil
local remotes = {}
local lastAt = {} -- [userId] = { [channel] = os.clock() of the last request }

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[CrateService] " .. msg)
end

-- THE LOBBY PREDICATE (EmoteService.inLobby, unchanged semantics) --------------
local function inLobby(player)
	if RoomServiceRef == nil then
		warnOnce("room", "no RoomService reference - every open denied (start was not called right)")
		return false
	end
	local ok, result = pcall(function()
		local room = RoomServiceRef.canonical()
		if type(room) ~= "table" then return false end
		if room.phase ~= "Playing" then return true end
		return RoomServiceRef.isParticipant(room, player.UserId) ~= true
	end)
	if not ok then
		warnOnce("lobby", "RoomService lookup failed - opens denied: " .. tostring(result))
		return false
	end
	return result == true
end

local function rateGate(userId, channel, cooldown)
	local now = os.clock()
	local per = lastAt[userId]
	if not per then
		per = {}
		lastAt[userId] = per
	end
	local last = per[channel]
	if last ~= nil and now - last < cooldown then return false end
	per[channel] = now
	return true
end

-- PACKETS ----------------------------------------------------------------------
-- Same wire as every other per-player fact: MachineState, dispatched by kind,
-- unknown kinds render nothing on a client from before this file.
local function sendResult(player, payload)
	if not machineState or player.Parent ~= Players then return end
	payload.kind = "crateresult"
	pcall(machineState.FireClient, machineState, player, payload)
end

local function walletOf(userId)
	local wallet = Profiles.wallet(userId)
	if type(wallet) ~= "table" then return nil end
	return wallet
end

-- THE CEREMONY -------------------------------------------------------------------
local function onOpen(player)
	if not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	if not rateGate(player.UserId, "open", OPEN_COOLDOWN) then return end
	if not inLobby(player) then return end
	local userId = player.UserId
	local wallet = walletOf(userId)
	if not wallet then return end

	local emotes = Profiles.emotes(userId)
	local owned = type(emotes) == "table" and emotes.owned or {}
	local poolIds = CrateRules.pool(EmoteRegistry.Emotes, owned)
	if #poolIds == 0 then
		sendResult(player, { ok = false, reason = "EMPTY", keys = wallet.keys, fragments = wallet.fragments })
		return
	end

	local cost = SupplyConfig.Crate.COST_KEYS
	if wallet.keys < cost then
		sendResult(player, { ok = false, reason = "NO_KEYS", keys = wallet.keys, fragments = wallet.fragments })
		return
	end

	local resultId = CrateRules.roll(
		poolIds,
		EmoteRegistry.Emotes,
		SupplyConfig.Crate.WEIGHTS,
		math.random(),
		math.random()
	)
	local row = EmoteRegistry.get(resultId)
	if row == nil then
		-- Cannot happen while roll() only returns pool members; fail closed
		-- without touching the wallet rather than trust it anyway.
		warnOnce("roll", "roll returned an id the catalog does not know: " .. tostring(resultId))
		return
	end

	for _ = 1, cost do
		if not Profiles.spendCrateKey(userId) then
			-- Also unreachable after the balance check (nothing yielded), kept
			-- as a closed gate so a future refactor that adds a yield above
			-- fails safe instead of granting for free.
			warnOnce("spend", "wallet went short between check and spend")
			return
		end
	end

	-- grant() validates against the catalog, flushes (one UpdateAsync carries
	-- the spend AND the grant) and sends the fresh emotestate packet.
	if EmoteServiceRef and not EmoteServiceRef.grant(userId, resultId) then
		warnOnce("grant", "grant refused after a paid roll for " .. tostring(resultId))
	end

	local reel = CrateRules.reel(
		poolIds,
		resultId,
		SupplyConfig.Crate.REEL_LENGTH,
		SupplyConfig.Crate.RESULT_INDEX,
		function(n)
			return math.random(n)
		end
	)
	local after = walletOf(userId) or { keys = 0, fragments = 0 }
	sendResult(player, {
		ok = true,
		emoteId = resultId,
		name = row.name,
		rarity = row.rarity,
		keys = after.keys,
		fragments = after.fragments,
		reel = reel,
	})
	Profiles.pushState(userId)
end

-- The supply screens' opening handshake: emotestate + profilestate on demand,
-- so a client that boots after the join-time sends still gets both.
local function onSync(player)
	if not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	if not rateGate(player.UserId, "sync", SYNC_COOLDOWN) then return end
	if EmoteServiceRef then
		pcall(EmoteServiceRef.sendState, player)
	end
	Profiles.pushState(player.UserId)
end

-- BOOT ------------------------------------------------------------------------
-- Main runs this AFTER EmoteService.start (whose grant path this reuses) and
-- therefore after RoomService (Remotes folder) and Profiles (wallet tables).
function CrateService.start(RoomService, EmoteService)
	if started then return end
	started = true
	RoomServiceRef = RoomService
	EmoteServiceRef = EmoteService
	if RoomServiceRef == nil then
		warnOnce("room", "started without a RoomService reference - every open will be denied")
	end
	if EmoteServiceRef == nil then
		warnOnce("emote", "started without an EmoteService reference - opens cannot grant")
	end

	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	for _, name in ipairs({ "CrateOpen", "SupplySync" }) do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		remotes[name] = remote
	end
	remotes.CrateOpen.OnServerEvent:Connect(function(player)
		pcall(onOpen, player)
	end)
	remotes.SupplySync.OnServerEvent:Connect(function(player)
		pcall(onSync, player)
	end)

	task.spawn(function()
		local ok, remote = pcall(function()
			return folder:WaitForChild("MachineState", 30)
		end)
		if ok and remote then machineState = remote end
	end)

	Players.PlayerRemoving:Connect(function(plr)
		lastAt[plr.UserId] = nil
	end)

	local pool = CrateRules.pool(EmoteRegistry.Emotes, {})
	print(("[CrateService] online - %d crate emote(s) in stock, cost %d key(s)")
		:format(#pool, SupplyConfig.Crate.COST_KEYS))
end

return CrateService
