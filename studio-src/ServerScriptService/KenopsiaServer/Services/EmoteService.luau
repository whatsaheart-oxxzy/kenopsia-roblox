--!nonstrict
-- EMOTE SERVICE (Phase 5) -- the emote + gamepass SOCKET. SHIPS DORMANT.
--
-- Three remotes exist and work the day this lands; nothing sends on them yet
-- (no client, no wheel, no shop -- Phase 5 adds ZERO client scripts). One real
-- emote row ships, dance_default, and it is free. Every gamepass id is 0 and an
-- id of 0 is skipped SILENTLY -- the Badges.luau CRT-hum pattern -- so no
-- MarketplaceService prompt can ever appear until the user pastes an id in.
--
-- WHAT THE SERVER OWNS
-- The client NEVER decides ownership. The whole wire is ONE character
-- attribute the server writes after its own checks:
--
--     character:SetAttribute("XBotEmote", <a key of AnimationIds.Player>)
--
-- PS1Animate (StarterCharacterScripts, NOT KenopsiaClient) reads that attribute
-- and plays the clip ONCE at Movement priority through
-- AnimationIds.load(animator, "Player", key). That loader is MANDATORY: it names
-- the Animation "Player/<key>@<uri>", and PS1Animate's animator.AnimationPlayed
-- guard stops any track whose Animation.Name does not start with "Player/" on
-- its first frame. Nothing here builds an Animation instance.
--
-- The attribute is a PULSE, not a state. It is cleared PULSE_SECONDS later,
-- because SetAttribute to the value it already holds does not fire
-- GetAttributeChangedSignal -- so without the clear the SAME emote twice in a
-- row would play once. PS1Animate treats "" as "the pulse was released", never
-- as "stop", so the clear cannot cut a clip that is still running.
--
-- THE FREE DANCE IS UNTOUCHED. PS1Animate's own danceOn latch (G / DPadLeft /
-- the KenopsiaEmote DanceButton) is a looping GAIT and stays exactly as it was:
-- free, client-local, ungated. This service is a second, server-driven,
-- one-shot channel that runs beside it. Zero KenopsiaClient edits.
--
-- LOBBY ONLY, and the predicate is RoomService -- not the trial attributes.
-- KenopsiaActiveTrial is a ROUND flag ("" between the rounds of one trial,
-- MachineFlow's own header documents that exact bug) and KenopsiaTrialId is ""
-- in the gap between two trials of one session. RoomService.canonical() +
-- isParticipant is the only thing true for a WHOLE match and false for a
-- spectator sitting out one.
--
-- DISCIPLINE (Telemetry / Profiles / Badges, unchanged here):
--   * every external call pcall-wrapped, one warn per reason, never a throw;
--   * the PLAY path NEVER yields -- gamepass ownership is answered from a cache
--     that is warmed and refreshed on other threads (see ownsPassCached);
--   * gamepass ownership is NEVER persisted as truth: a refunded pass has to
--     stop granting, so it is re-asked every OWNERSHIP_TTL seconds;
--   * a grant for a player who is not on this server is DROPPED, by design --
--     Profiles.grantEmote no-ops for an offline userId and the DataStore
--     (KenopsiaProfile_v1) is the source of truth, MessagingService is only the
--     live nudge for a player who happens to be here right now.
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared"):WaitForChild("Config")
local EmoteRegistry = require(Config:WaitForChild("EmoteRegistry"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Profiles = require(script.Parent.Profiles)

-- The attribute PS1Animate listens on. Never XBotMoves: values containing
-- scan/eat/sneak/push there drive legacy client paths and this must not touch
-- them. XBotPush is retired (KenopsiaClient says so in its own header) and is
-- not reused either.
local EMOTE_ATTRIBUTE = "XBotEmote"
-- How long the pulse stays on the character before it is released. Must be long
-- enough to replicate (it is ~15 frames) and far shorter than PLAY_COOLDOWN so
-- the next press always sees a cleared attribute.
local PULSE_SECONDS = 0.25
local PLAY_COOLDOWN = 1.5 -- seconds per player, committed on entry (see rateGate)
-- EVERY remote is gated, not just the play path. EmoteEquip answers with a
-- MachineState packet, so one outbound FireClient per inbound event is a
-- bandwidth amplifier on a 28-player server; ShopPrompt, once a pass id is
-- pasted, spawns a MarketplaceService web call per press. A whole-wheel "save
-- layout" is ONE Profiles.setWheel call, never eight EmoteEquips -- do not
-- widen this gate to make a chatty client work.
local EQUIP_COOLDOWN = 0.25
local SHOP_COOLDOWN = 2 -- one purchase dialog at a time
local OWNERSHIP_TTL = 120 -- seconds a cached UserOwnsGamePassAsync answer lives
local REFRESH_COOLDOWN = 10 -- seconds between two background ownership probes
-- DERIVED, never declared twice: Profiles owns the wheel's width because Profiles
-- is what has to keep it dense across a DataStore round trip. Two independent 8s
-- would drift the day one of them moves, and the drift would silently truncate
-- saved wheels.
local WHEEL_SLOTS = tonumber(Profiles.WHEEL_SLOTS) or 8
-- Kenopsia<Purpose>_v<n>, matching Profiles' STORE_NAME = "KenopsiaProfile_v1".
-- MessagingService has no other user anywhere in the codebase; this is the
-- naming convention Phase 5 establishes.
local GRANT_TOPIC = "KenopsiaGrant_v1"
local MAX_ID_LENGTH = 64 -- a client string longer than this is not an id, it is an attack

local EmoteService = {}

local started = false
local warned = {}
local RoomServiceRef = nil
local machineState = nil
local remotes = {}
local lastAt = {} -- [userId] = { [channel] = os.clock() of the last request on that channel }
local passCache = {} -- [userId] = { [passKey] = { owns = bool, at = os.clock(), probing = bool } }

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[EmoteService] " .. msg)
end

-- THE LOBBY PREDICATE ---------------------------------------------------------
-- True for the whole session including the gap between two trials, true for a
-- spectator on a server with a live match, false only while THIS player is a
-- participant of a running match. FAILS CLOSED: no RoomService reference, a
-- malformed room or a throw all read as "not in the lobby", so a boot mistake
-- can never let an emote fire inside a trial.
local function inLobby(player)
	if RoomServiceRef == nil then
		warnOnce("room", "no RoomService reference - every emote denied (start(RoomService) was not called)")
		return false
	end
	local ok, result = pcall(function()
		local room = RoomServiceRef.canonical()
		if type(room) ~= "table" then return false end
		if room.phase ~= "Playing" then return true end
		return RoomServiceRef.isParticipant(room, player.UserId) ~= true
	end)
	if not ok then
		warnOnce("lobby", "RoomService lookup failed - emotes denied: " .. tostring(result))
		return false
	end
	return result == true
end

-- RATE GATE -------------------------------------------------------------------
-- PER PLAYER and PER CHANNEL, never global: one loud client must never be able
-- to spend anybody else's budget, and a play must not be starved by an equip.
-- Committed on ENTRY, not on success: a rejected press has to cost the same as
-- an accepted one, otherwise the rejection path (which can spawn a background
-- ownership probe, a profile write or a web call) becomes the spam surface.
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

-- Forward-declared: probePass (below) materialises a pass grant the first time
-- ownership comes back TRUE, and grantPass lives down in the GRANTS section
-- because that is where the Profiles writes belong. Declaration order only --
-- neither ever calls the other synchronously on the play path.
local grantPass

-- GAMEPASS OWNERSHIP ----------------------------------------------------------
-- UserOwnsGamePassAsync YIELDS and can throw, so it never runs on the play path.
-- The play path reads this cache synchronously; a cold entry answers "no" and
-- schedules the probe, so the next press (PLAY_COOLDOWN later at the earliest)
-- has the real answer. Entries are warmed on join, invalidated on a completed
-- purchase, and expire after OWNERSHIP_TTL -- never persisted, so a refund
-- stops granting within one TTL instead of forever.
--
-- While every pass id is 0 this costs NOTHING: armed() is false and no probe is
-- ever scheduled.
local function cacheFor(userId)
	local per = passCache[userId]
	if not per then
		per = {}
		passCache[userId] = per
	end
	return per
end

local function probePass(userId, passKey)
	local pass = MonetizationConfig.PASSES[passKey]
	local id = pass and tonumber(pass.id) or 0
	if id <= 0 then return end -- placeholder: not created yet, skip silently
	local per = cacheFor(userId)
	local slot = per[passKey]
	local now = os.clock()
	if slot and slot.probing then return end
	if slot and slot.at ~= nil and now - slot.at < REFRESH_COOLDOWN then return end
	slot = slot or {}
	slot.probing = true
	per[passKey] = slot
	task.spawn(function()
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, id)
		if not ok then
			warnOnce("owns", "UserOwnsGamePassAsync failed (expected in Studio): " .. tostring(owns))
		end
		local current = passCache[userId]
		if not current then return end -- left while we were asking
		local fresh = { owns = ok and owns == true, at = os.clock(), probing = false }
		current[passKey] = fresh
		-- A pass bought on the WEBSITE, in DEV, or in a session whose flush
		-- failed never fires PromptGamePassPurchaseFinished on this server, so
		-- the grant has to be materialised the first time ownership is
		-- CONFIRMED. Without this owns() would let the emote PLAY while every
		-- equip is silently rejected -- Profiles' rule is "you cannot equip
		-- what you do not own" and `owned` would never have been written.
		-- Idempotent: a repeat grant changes nothing and costs no store write.
		if fresh.owns then pcall(grantPass, userId, passKey) end
	end)
end

-- Synchronous, never yields, never throws. An unknown answer is "no".
local function ownsPassCached(userId, passKey)
	if not MonetizationConfig.armed(passKey) then return false end
	local per = passCache[userId]
	local slot = per and per[passKey] or nil
	if slot and slot.at ~= nil and os.clock() - slot.at <= OWNERSHIP_TTL then
		return slot.owns == true
	end
	probePass(userId, passKey)
	return false
end

local function warmPasses(userId)
	for _, key in ipairs(MonetizationConfig.list()) do
		if MonetizationConfig.armed(key) then probePass(userId, key) end
	end
end

-- OWNERSHIP DECISION ----------------------------------------------------------
-- Synchronous by construction: the registry decision is pure
-- (EmoteRegistry.requiresOwnership, proven offline), the profile read is an
-- in-memory table (Profiles.get), and the gamepass answer comes from the cache.
local function owns(userId, emoteId)
	if not EmoteRegistry.requiresOwnership(emoteId) then return true end
	local data = Profiles.get(userId)
	local emotes = type(data) == "table" and data.emotes or nil
	local ownedSet = type(emotes) == "table" and emotes.owned or nil
	if type(ownedSet) == "table" and ownedSet[emoteId] == true then return true end
	for _, key in ipairs(MonetizationConfig.list()) do
		if ownsPassCached(userId, key) then
			for _, granted in ipairs(MonetizationConfig.grantedEmotes(key)) do
				if granted == emoteId then return true end
			end
		end
	end
	return false
end

-- GRANTS ----------------------------------------------------------------------
-- The one durable write. Validates against the catalog first -- Profiles takes
-- any string, so the catalog check has to happen HERE or a bad grant would
-- persist forever. flush() is fire-and-forget (its own header); a failed flush
-- stays dirty and PlayerRemoving / BindToClose retry it.
function EmoteService.grant(userId, emoteId)
	userId = tonumber(userId)
	if not userId or EmoteRegistry.get(emoteId) == nil then return false end
	if Profiles.get(userId) == nil then return false end -- not on this server: dropped by design
	local ok, added = pcall(Profiles.grantEmote, userId, emoteId)
	-- Already owned: idempotent success, but NO store write and NO packet. A
	-- repeated MessagingService nudge or a re-confirmed gamepass must not turn
	-- into a DataStore UpdateAsync per message.
	if not (ok and added == true) then return ok end
	pcall(Profiles.flush, userId)
	EmoteService.sendState(Players:GetPlayerByUserId(userId))
	return true
end

-- Every emote a pass grants, then ONE flush. Profiles.flush is an UpdateAsync
-- on one key and same-key writes are throttled, so a per-emote flush would
-- queue N writes for one purchase.
function grantPass(userId, passKey)
	if Profiles.get(userId) == nil then return false end
	local added = false
	for _, emoteId in ipairs(MonetizationConfig.grantedEmotes(passKey)) do
		if EmoteRegistry.get(emoteId) ~= nil then
			local ok, new = pcall(Profiles.grantEmote, userId, emoteId)
			if ok and new == true then added = true end
		end
	end
	if not added then return false end
	pcall(Profiles.flush, userId)
	EmoteService.sendState(Players:GetPlayerByUserId(userId))
	return true
end

-- The publisher half of the cross-place path. DEV's crate ceremony calls this
-- after it has written the durable grant; MainGame's subscriber merges it live
-- if the player happens to be on this server. Fire-and-forget, never a throw --
-- a failed publish costs nothing because the DataStore already holds the truth.
function EmoteService.publishGrant(userId, emoteId)
	userId = tonumber(userId)
	if not userId or type(emoteId) ~= "string" or emoteId == "" then return false end
	local ok, err = pcall(MessagingService.PublishAsync, MessagingService, GRANT_TOPIC, {
		userId = userId,
		kind = "emote",
		id = emoteId,
	})
	if not ok then
		warnOnce("publish", "PublishAsync failed (expected in Studio): " .. tostring(err))
	end
	return ok
end

-- STATE PACKET ----------------------------------------------------------------
-- The UI contract, dark until a later phase renders it: an unknown kind renders
-- NOTHING on the client (MachineFlow's documented dispatch, the same contract
-- Profiles.sendState relies on). So "emotestate" ships with ZERO client edits.
-- The CATALOG is not in the packet -- EmoteRegistry lives in ReplicatedStorage
-- and the client requires it directly; only the per-player facts travel.
function EmoteService.sendState(plr)
	if not (typeof(plr) == "Instance" and plr:IsA("Player")) then return end
	if not machineState or plr.Parent ~= Players then return end
	local data = Profiles.get(plr.UserId)
	local emotes = type(data) == "table" and data.emotes or nil
	if type(emotes) ~= "table" then return end
	local ownedList = {}
	if type(emotes.owned) == "table" then
		for id, held in pairs(emotes.owned) do
			if held == true and type(id) == "string" then ownedList[#ownedList + 1] = id end
		end
		table.sort(ownedList)
	end
	local wheel = {}
	for i = 1, WHEEL_SLOTS do
		local slot = type(emotes.wheel) == "table" and emotes.wheel[i] or nil
		wheel[i] = type(slot) == "string" and slot or ""
	end
	pcall(machineState.FireClient, machineState, plr, {
		kind = "emotestate",
		owned = ownedList,
		equipped = type(emotes.equipped) == "string" and emotes.equipped or "",
		wheel = wheel,
	})
end

-- THE PLAY PATH ---------------------------------------------------------------
-- Every step is synchronous. Order: shape -> catalog -> rate -> body -> lobby
-- -> ownership -> the attribute. Nothing below this comment yields.
local function onPlay(player, payload)
	if not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	local emoteId = type(payload) == "table" and payload.emoteId or payload
	if type(emoteId) ~= "string" or emoteId == "" or #emoteId > MAX_ID_LENGTH then return end
	local row = EmoteRegistry.get(emoteId)
	if row == nil then return end
	if not rateGate(player.UserId, "play", PLAY_COOLDOWN) then return end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and char.Parent and hum and hum.Health > 0) then return end
	if not inLobby(player) then return end
	if not owns(player.UserId, emoteId) then return end

	local key = row.animKey
	if type(key) ~= "string" or key == "" then return end
	-- THE ONLY WIRE. A clip that is not published yet resolves to nil inside
	-- PS1Animate and simply does not play -- no animation is never an error.
	pcall(char.SetAttribute, char, EMOTE_ATTRIBUTE, key)
	-- Release the pulse so the SAME emote can be pressed again (see the header).
	-- Guarded on the value we wrote: a newer emote must never be stomped.
	task.delay(PULSE_SECONDS, function()
		if char.Parent == nil then return end
		if char:GetAttribute(EMOTE_ATTRIBUTE) ~= key then return end
		pcall(char.SetAttribute, char, EMOTE_ATTRIBUTE, "")
	end)
end

-- THE WHEEL -------------------------------------------------------------------
-- slot 1..WHEEL_SLOTS, emoteId a catalog id or "" / nil to clear the slot.
-- A DEFAULT emote is materialised into `owned` on its first equip: Profiles'
-- one rule is "you cannot equip what you do not own", and keeping that rule
-- absolute is worth one redundant boolean. It is NOT an ownership shortcut --
-- the PLAY path asks the registry, never `owned`, for a default row, so
-- deleting a default row stops it playing the same second regardless of what a
-- profile still remembers.
local function onEquip(player, payload)
	if not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	if type(payload) ~= "table" then return end
	if not rateGate(player.UserId, "equip", EQUIP_COOLDOWN) then return end
	local slot = tonumber(payload.slot)
	if not slot or slot ~= math.floor(slot) or slot < 1 or slot > WHEEL_SLOTS then return end
	local emoteId = payload.emoteId
	if emoteId == nil then emoteId = "" end
	if type(emoteId) ~= "string" or #emoteId > MAX_ID_LENGTH then return end
	if emoteId ~= "" then
		if EmoteRegistry.get(emoteId) == nil then return end
		if not owns(player.UserId, emoteId) then return end
		if EmoteRegistry.isDefault(emoteId) then
			pcall(Profiles.grantEmote, player.UserId, emoteId)
		end
	end
	local ok = Profiles.setEmoteSlot(player.UserId, slot, emoteId)
	if not ok then return end
	if emoteId ~= "" then
		-- The last thing put on the wheel is what a one-button client plays.
		Profiles.setEquipped(player.UserId, emoteId)
	end
	EmoteService.sendState(player)
end

-- THE SHOP --------------------------------------------------------------------
-- The client sends a SKU, never an id: ids change when a pass is recreated and
-- a number a client could invent is a number a client could abuse. An unarmed
-- pass (id 0) is a silent no-op -- no prompt, no warn, no throw.
local function onShopPrompt(player, payload)
	if not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	local sku = type(payload) == "table" and payload.sku or payload
	if type(sku) ~= "string" or #sku > MAX_ID_LENGTH then return end
	if not rateGate(player.UserId, "shop", SHOP_COOLDOWN) then return end
	local key, pass = MonetizationConfig.passBySku(sku)
	if not key or not MonetizationConfig.armed(key) then return end
	local id = tonumber(pass.id)
	task.spawn(function()
		local ok, err = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, id)
		if not ok then
			warnOnce("prompt", "PromptGamePassPurchase failed: " .. tostring(err))
		end
	end)
end

-- BOOT ------------------------------------------------------------------------
-- Main runs this AFTER RoomService.start() (which creates the Remotes folder)
-- and AFTER Profiles.start() (which owns the profile tables this reads).
function EmoteService.start(RoomService)
	if started then return end
	started = true
	RoomServiceRef = RoomService
	if RoomServiceRef == nil then
		warnOnce("room", "started without a RoomService reference - every emote will be denied")
	end

	-- Find-or-create, the Minefield / BirdHunting / Telemetry convention: boot
	-- order between services is irrelevant, whoever gets there first creates it.
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	for _, name in ipairs({ "EmotePlay", "EmoteEquip", "ShopPrompt" }) do
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		remotes[name] = remote
	end
	remotes.EmotePlay.OnServerEvent:Connect(function(player, payload)
		pcall(onPlay, player, payload)
	end)
	remotes.EmoteEquip.OnServerEvent:Connect(function(player, payload)
		pcall(onEquip, player, payload)
	end)
	remotes.ShopPrompt.OnServerEvent:Connect(function(player, payload)
		pcall(onShopPrompt, player, payload)
	end)

	-- MachineFlow.start creates MachineState AFTER this (Main boot order), so it
	-- is resolved once on a spawned thread and every later read is a nil check.
	task.spawn(function()
		local ok, remote = pcall(function()
			return folder:WaitForChild("MachineState", 30)
		end)
		if ok and remote then machineState = remote end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then return end
		local key = MonetizationConfig.passById(passId)
		if not key then return end
		-- Invalidate BEFORE granting: the next ownership question must ask the
		-- API again rather than trust the "no" that was cached a moment ago.
		local per = passCache[player.UserId]
		if per then per[key] = nil end
		probePass(player.UserId, key)
		pcall(grantPass, player.UserId, key)
	end)

	-- The CROSS-PLACE path. DEV and MainGame share universe 10640788131 and the
	-- KenopsiaProfile_v1 DataStore, so a crate ceremony in DEV publishes here and
	-- the player sees the emote without a rejoin. The DataStore is still the
	-- source of truth -- this only merges into a LIVE profile, and a payload for
	-- a player who is not on this server is dropped (EmoteService.grant returns
	-- false). A failed subscribe warns once and everything still works on the
	-- player's next load.
	task.spawn(function()
		local ok, err = pcall(MessagingService.SubscribeAsync, MessagingService, GRANT_TOPIC, function(message)
			local body = type(message) == "table" and message.Data or nil
			if type(body) ~= "table" then return end
			if body.kind ~= "emote" then return end
			pcall(EmoteService.grant, body.userId, body.id)
		end)
		if not ok then
			warnOnce("subscribe", "SubscribeAsync failed (expected in Studio without API access): " .. tostring(err))
		end
	end)

	-- The CharacterService / Profiles hook pattern: sweep whoever beat start()
	-- to the server, then let the connection take over.
	local function onPlayer(plr)
		warmPasses(plr.UserId)
	end
	for _, plr in Players:GetPlayers() do
		onPlayer(plr)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(plr)
		lastAt[plr.UserId] = nil
		passCache[plr.UserId] = nil
	end)

	local armed = 0
	for _, key in ipairs(MonetizationConfig.list()) do
		if MonetizationConfig.armed(key) then armed += 1 end
	end
	print(("[EmoteService] online - %d emote(s), %d/%d gamepass(es) armed")
		:format(#EmoteRegistry.list(), armed, #MonetizationConfig.list()))
end

return EmoteService
