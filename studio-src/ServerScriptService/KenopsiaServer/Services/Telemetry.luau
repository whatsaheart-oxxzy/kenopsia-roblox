--!nonstrict
-- TELEMETRY -- analytics skeleton (G1).
--
-- Server wrapper around AnalyticsService plus one client-report remote:
--   * Telemetry.event(name, player?, data?) -> LogCustomEvent (needs a Player;
--     without one the call is skipped -- Roblox custom events are per-player);
--   * Telemetry.funnel(player, funnelName, step, stepName) -> LogFunnelStepEvent
--     (funnelSessionId nil: documented-optional, fine for one-time funnels);
--   * RemoteEvent "TelemetryEvent": clients may report whitelisted events only
--     ("MobileBlackScreen"), rate-limited 1 per name per player per 60s;
--     payload must be a small flat table of numbers/strings (+booleans for
--     flags like `touch`); the sanitized payload is folded into
--     CustomField01..03 as "key=value" strings (the only keys LogCustomEvent
--     accepts -- see Enum.AnalyticsCustomFieldKeys), first 3 keys by sort order.
-- Every external call is pcall-wrapped; Analytics failures (expected in
-- Studio) warn once per reason, never spam, never throw. No per-frame work.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	RateLimitSeconds = 60,
	MaxPayloadKeys = 8,
	MaxStringLength = 64,
}

local CLIENT_EVENT_WHITELIST = {
	MobileBlackScreen = true,
}

local Telemetry = {}

local started = false
local warned = {}
local lastFired = {} -- [player] = { [eventName] = os.clock() }

local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[Telemetry] " .. msg)
end

-- LogCustomEvent only accepts customFields keyed by Enum.AnalyticsCustomFieldKeys
-- (CustomField01..03) -- arbitrary keys are rejected by the engine. Fold the
-- sanitized payload into "key=value" category strings on those keys (sorted for
-- deterministic assignment; overflow beyond 3 fields is dropped).
local CUSTOM_FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local function toCustomFields(data)
	if type(data) ~= "table" then return nil end
	local entries = {}
	for k, v in pairs(data) do
		table.insert(entries, { s = tostring(k), v = v })
	end
	table.sort(entries, function(a, b) return a.s < b.s end) -- string sort: never throws on mixed keys
	local fields = nil
	for i = 1, math.min(#entries, #CUSTOM_FIELD_KEYS) do
		fields = fields or {}
		fields[CUSTOM_FIELD_KEYS[i]] = entries[i].s .. "=" .. tostring(entries[i].v)
	end
	return fields
end

local function sanitizePayload(payload)
	if type(payload) ~= "table" then return nil end
	local out, count = {}, 0
	for k, v in payload do
		if type(k) ~= "string" or #k > CONFIG.MaxStringLength then return nil end
		local t = type(v)
		if t == "string" then
			if #v > CONFIG.MaxStringLength then return nil end
		elseif t ~= "number" and t ~= "boolean" then
			return nil
		end
		count += 1
		if count > CONFIG.MaxPayloadKeys then return nil end
		out[k] = v
	end
	return out
end

function Telemetry.event(name, player, data)
	if type(name) ~= "string" then return end
	if not (typeof(player) == "Instance" and player:IsA("Player")) then
		return -- LogCustomEvent is per-player; nothing to log without one
	end
	local fields = toCustomFields(data)
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, 1, fields)
	end)
	if not ok then
		warnOnce("event", "LogCustomEvent failed (expected in Studio): " .. tostring(err))
	end
end

function Telemetry.funnel(player, funnelName, step, stepName)
	if not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	if type(funnelName) ~= "string" or type(step) ~= "number" or type(stepName) ~= "string" then return end
	local ok, err = pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnelName, nil, step, stepName)
	end)
	if not ok then
		warnOnce("funnel", "LogFunnelStepEvent failed (expected in Studio): " .. tostring(err))
	end
end

local function onClientReport(player, payload)
	if type(payload) ~= "table" then return end
	local name = payload.event
	if type(name) ~= "string" or not CLIENT_EVENT_WHITELIST[name] then return end

	local now = os.clock()
	local perPlayer = lastFired[player]
	if not perPlayer then
		perPlayer = {}
		lastFired[player] = perPlayer
	end
	if perPlayer[name] and now - perPlayer[name] < CONFIG.RateLimitSeconds then return end

	local data = sanitizePayload(payload)
	if not data then return end
	data.event = nil -- name travels separately
	perPlayer[name] = now
	Telemetry.event(name, player, data)
end

function Telemetry.start()
	if started then return end
	started = true

	local remotes = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	local remote = remotes:FindFirstChild("TelemetryEvent")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "TelemetryEvent"
		remote.Parent = remotes
	end
	remote.OnServerEvent:Connect(function(player, payload)
		pcall(onClientReport, player, payload)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastFired[player] = nil
	end)
end

return Telemetry
