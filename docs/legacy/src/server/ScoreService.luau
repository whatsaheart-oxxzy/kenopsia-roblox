-- Match scoring. Deliberately has no DataStore in it yet.
--
-- Persistence is Phase 5 work and adding it early is how party games end up
-- with duplicated currency and rollback bugs. Get the loop fun first, then
-- decide what is even worth saving.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local ScoreService = {}

local Scoreboard = Net.get("Scoreboard")

local totals: { [Player]: number } = {}

local function log(...)
	if Config.Verbose then
		print("[Score]", ...)
	end
end

function ScoreService.reset()
	totals = {}
	ScoreService.publish()
end

function ScoreService.add(player: Player, amount: number)
	if amount == 0 then
		return
	end
	totals[player] = (totals[player] or 0) + amount
end

function ScoreService.applyResult(result: { [Player]: number })
	for player, amount in result do
		ScoreService.add(player, amount)
		log(`{player.Name} +{amount}`)
	end
	ScoreService.publish()
end

function ScoreService.get(player: Player): number
	return totals[player] or 0
end

-- Sorted standings, highest first. Built fresh each call - the player count is
-- capped at 8 so this is never worth caching.
function ScoreService.standings(): { { name: string, userId: number, score: number } }
	local rows = {}
	for _, player in Players:GetPlayers() do
		table.insert(rows, {
			name = player.DisplayName,
			userId = player.UserId,
			score = totals[player] or 0,
		})
	end
	table.sort(rows, function(a, b)
		if a.score == b.score then
			return a.name < b.name
		end
		return a.score > b.score
	end)
	return rows
end

function ScoreService.publish()
	Scoreboard:FireAllClients(ScoreService.standings())
end

function ScoreService.winner(): string?
	local rows = ScoreService.standings()
	if #rows == 0 then
		return nil
	end
	-- A tie at the top is a genuine draw; say so rather than picking by name.
	if #rows > 1 and rows[1].score == rows[2].score then
		return nil
	end
	return rows[1].name
end

Players.PlayerRemoving:Connect(function(player)
	totals[player] = nil
end)

return ScoreService
