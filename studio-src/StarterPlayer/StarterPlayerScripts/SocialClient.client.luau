--!nonstrict
-- SOCIAL CLIENT (Phase 4d) -- the invite lever. INNER-GAME-PLAN section 6.
--
-- 2-4 players is the whole game, so an empty seat is the single biggest reason
-- a session ends early. This script asks for exactly one thing at exactly one
-- moment: when the SHIFT REPORT lands with a seat open, it opens Roblox's own
-- invite sheet.
--
-- WHY THE SHIFT REPORT AND NOTHING ELSE. The plan also lists a lobby prompt.
-- An unsolicited popup on join is the wrong shape -- it lands before anybody
-- has a reason to invite, it is the prompt players learn to dismiss, and
-- Roblox rate-limits the API anyway. The SHIFT REPORT is the honest moment:
-- the round just ended, the numbers are on screen, everyone is still here.
-- A LOBBY INVITE BUTTON is the right second surface and it belongs to the UI
-- (Codex): SocialService:PromptGameInvite is a plain client call, so a button
-- calls it directly -- it does not need this script and must not be bolted on
-- here as another popup.
--
-- NO GUI. This is the whole feature: Roblox draws the invite sheet.
--
-- DISCIPLINE (LightGuard / Telemetry): every external call pcall-wrapped, one
-- warn per reason, no loops, no RenderStepped, and a total no-op when the
-- remote never appears (a published place running an older server) or when
-- SocialService is unavailable (Studio, or a policy that forbids invites).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer

local CONFIG = {
	RemoteTimeout = 20,
	-- Per SESSION (this client's lifetime), not per round. Two is the point at
	-- which a prompt stops being a suggestion and starts being nagging; the
	-- gap keeps a 3-trial rematch chain from prompting on every verdict.
	MaxPrompts = 2,
	MinGapSeconds = 240,
}

local prompts = 0
local lastAt = -math.huge
local warned = {}

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[SocialClient] " .. msg)
end

-- CanSendGameInviteAsync YIELDS and throws on a client that may not invite, so
-- it never runs inline -- the caller is a remote handler and must not block the
-- packet dispatch for every other listener.
local function promptInvite()
	task.spawn(function()
		local ok, allowed = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if not ok then
			warnOnce("can", "CanSendGameInviteAsync failed (expected in Studio): " .. tostring(allowed))
			return
		end
		if allowed ~= true then return end -- policy says no: silent, never a warn
		-- Commit the budget only once the sheet is actually asked for, so a
		-- policy refusal above does not spend a prompt the player never saw.
		prompts += 1
		lastAt = os.clock()
		local sent, err = pcall(SocialService.PromptGameInvite, SocialService, player)
		if not sent then
			warnOnce("prompt", "PromptGameInvite failed: " .. tostring(err))
		end
	end)
end

task.spawn(function()
	local kenopsia = ReplicatedStorage:WaitForChild("Kenopsia", CONFIG.RemoteTimeout)
	local remotes = kenopsia and kenopsia:WaitForChild("Remotes", CONFIG.RemoteTimeout)
	local remote = remotes and remotes:WaitForChild("MachineState", CONFIG.RemoteTimeout)
	if not (remote and remote:IsA("RemoteEvent")) then return end -- older server: no-op
	remote.OnClientEvent:Connect(function(packet)
		if type(packet) ~= "table" or packet.kind ~= "shiftreport" then return end
		-- openSeats is 4 - #room.members at the verdict (MachineFlow). No seat
		-- open means a full roster: there is nothing to invite anybody to.
		if (tonumber(packet.openSeats) or 0) <= 0 then return end
		if prompts >= CONFIG.MaxPrompts then return end
		if os.clock() - lastAt < CONFIG.MinGapSeconds then return end
		promptInvite()
	end)
end)
