--!nonstrict
-- BADGES (Phase 4b) -- the six retention badges as a SOCKET. SHIPS DARK.
--
-- The CRT-hum placeholder pattern: every id below is 0 until the user creates
-- the badges in Creator Hub and pastes the real ids into BADGES -- an id of 0
-- is skipped SILENTLY, so until then this whole file is a dormant socket and
-- arming it is a config paste, zero code change.
--
-- MachineFlow calls Badges.checkSession once per participant, right after it
-- captures that player's Profiles.recordSession receipt. The rules run
-- synchronously (no yields, nothing can throw past this file's pcalls), then
-- ONE thread per call is spawned for the yielding work: AwardBadge yields,
-- and CO_WORKERS needs Player:IsFriendsWith (also yields), so both live on
-- the spawned thread and the verdict loop is never blocked. checkSession must
-- never throw into MachineFlow -- and the call site pcalls it anyway, the
-- Profiles discipline.
--
-- CO_WORKERS timing decision: the friend check runs LAZILY inside the spawned
-- award thread, not as an async pre-pass at session start. Chosen because it
-- is the simpler of the two correct options: no session-start bookkeeping, no
-- "is the answer ready by the verdict" race, and the thread it needs already
-- exists for AwardBadge. The check is also GATED on the badge being armed
-- (id ~= 0) and not yet awarded, so the dark socket never spends a friends
-- API round trip. Cost accepted: if the player leaves in the beat between the
-- verdict and the spawned thread running, the check comes back empty and the
-- badge simply waits for the next shared verdict.
--
-- Double-award is harmless -- Roblox no-ops a badge the player owns -- but
-- the per-user set below still guards it, kept for the server's lifetime,
-- which subsumes the per-session guard: a badge is permanent, so never
-- re-calling AwardBadge for the same user+key on this server is strictly
-- cheaper and never wrong. Six booleans per seen userId; nothing to clean up.
--
-- No start(): there is nothing to boot -- no remotes, no connections, no
-- player sweep. MachineFlow's require is the whole wiring.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local Badges = {}

-- THE CONFIG SOCKET. Creator Hub badge ids get pasted here; nothing else in
-- the codebase changes when they do. 0 = not created yet, skip silently.
Badges.BADGES = {
	FIRST_SHIFT  = { id = 0 }, -- first verdict ever (receipt.sessions == 1)
	FIRST_VIABLE = { id = 0 }, -- first VIABLE verdict (receipt.viableCount == 1)
	CLEAN_SWEEP  = { id = 0 }, -- sole-topped every board of a 2+-trial session
	THREE_NIGHTS = { id = 0 }, -- streak of 3+ consecutive days (shield counts)
	FULL_ROSTER  = { id = 0 }, -- verdict in a full 4-subject room
	CO_WORKERS   = { id = 0 }, -- verdict with a Roblox friend seated in the room
}

local awarded = {} -- [userId] = { [badgeKey] = true }; server lifetime, see header

local function alreadyAwarded(userId, key)
	local per = awarded[userId]
	return per ~= nil and per[key] == true
end

-- Runs on the spawned thread only: AwardBadge yields. An id of 0 is the
-- placeholder path and returns without a sound; a failed pcall stays unmarked
-- so a later session may retry.
local function award(userId, key)
	local entry = Badges.BADGES[key]
	local id = entry and tonumber(entry.id) or 0
	if id == 0 then return end -- placeholder: not created yet, skip silently
	if alreadyAwarded(userId, key) then return end
	local ok, err = pcall(BadgeService.AwardBadge, BadgeService, userId, id)
	if ok then
		local per = awarded[userId]
		if not per then
			per = {}
			awarded[userId] = per
		end
		per[key] = true
	else
		warn(("[Badges] AwardBadge %s failed: %s"):format(key, tostring(err)))
	end
end

-- The one entry point. receipt is Profiles.recordSession's return (xpDelta,
-- sessions, viableCount, streak, viable, ...); context is MachineFlow's
-- session view:
--   { members = <judged roster count>, trialsWon, trialsTotal,
--     hasFriendInRoom = bool|nil, otherUserIds = { <the other participants> } }
-- hasFriendInRoom = nil means "unknown -- resolve it from otherUserIds on the
-- spawned thread" (the lazy CO_WORKERS path, see header); an explicit false
-- skips the check entirely. Never yields, never throws.
function Badges.checkSession(userId, receipt, context)
	userId = tonumber(userId)
	if not userId or type(receipt) ~= "table" then return end
	if type(context) ~= "table" then context = {} end

	local due = {}
	if (tonumber(receipt.sessions) or 0) == 1 then
		table.insert(due, "FIRST_SHIFT")
	end
	if receipt.viable and (tonumber(receipt.viableCount) or 0) == 1 then
		table.insert(due, "FIRST_VIABLE")
	end
	-- Session-level, per the ruling on the plan: every trial board of THIS
	-- session sole-topped, and only when the session had 2+ trials -- a
	-- one-trial session has no sweep to speak of.
	local trialsTotal = tonumber(context.trialsTotal) or 0
	if trialsTotal >= 2 and (tonumber(context.trialsWon) or 0) >= trialsTotal then
		table.insert(due, "CLEAN_SWEEP")
	end
	if (tonumber(receipt.streak) or 0) >= 3 then
		table.insert(due, "THREE_NIGHTS")
	end
	if (tonumber(context.members) or 0) == 4 then
		table.insert(due, "FULL_ROSTER")
	end

	local friends = context.hasFriendInRoom -- true / false / nil = resolve below
	local others = type(context.otherUserIds) == "table" and context.otherUserIds or {}

	task.spawn(function()
		for _, key in ipairs(due) do
			award(userId, key)
		end
		-- CO_WORKERS last, and only when it could actually pay: a dark id (0)
		-- or an already-earned badge never buys a friends API round trip.
		local entry = Badges.BADGES.CO_WORKERS
		if (tonumber(entry and entry.id) or 0) == 0 then return end
		if alreadyAwarded(userId, "CO_WORKERS") then return end
		if friends == nil and #others > 0 then
			local plr = Players:GetPlayerByUserId(userId)
			if plr then
				for _, otherId in ipairs(others) do
					local ok, isFriend = pcall(plr.IsFriendsWith, plr, otherId)
					if ok and isFriend == true then
						friends = true
						break
					end
				end
			end
		end
		if friends == true then
			award(userId, "CO_WORKERS")
		end
	end)
end

return Badges
