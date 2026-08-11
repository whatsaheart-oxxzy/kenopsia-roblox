--!strict
-- Single namespaced remote layer. Nothing anywhere else in the codebase should
-- create a RemoteEvent: add a name to REMOTE_NAMES instead, so the full
-- client/server attack surface stays readable in one list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "KenopsiaNet"

local REMOTE_NAMES = {
	"RoundEvent", -- S->C: announce payloads, results, generic UI cues
	"RecallGrid", -- S->C: grid to display (masked during the recall phase)
	"RecallSubmit", -- C->S: { cellIndex, iconId }
	"GrateReveal", -- S->C: pad revealed { index, safe }
	"LineFeedback", -- S->C: accepted / rejected feedback
	"Scoreboard", -- S->C: current standings
}

local Net = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in REMOTE_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
end

function Net.get(name: string): RemoteEvent
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), `Net: unknown remote "{name}"`)
	return remote :: RemoteEvent
end

-- Rate limiting -------------------------------------------------------------
-- Every C->S handler must gate on this. An exploiter who can call a remote in a
-- tight loop can stall the server even when the handler itself is harmless.

type Bucket = { tokens: number, last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

function Net.allow(player: Player, key: string, perSecond: number): boolean
	local now = os.clock()
	local byKey = buckets[player]
	if not byKey then
		byKey = {}
		buckets[player] = byKey
	end

	local bucket = byKey[key]
	if not bucket then
		bucket = { tokens = perSecond, last = now }
		byKey[key] = bucket
	end

	bucket.tokens = math.min(perSecond, bucket.tokens + (now - bucket.last) * perSecond)
	bucket.last = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

if RunService:IsServer() then
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Net
