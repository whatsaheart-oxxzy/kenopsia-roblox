-- The list of minigames, and the only file you touch when adding one.
--
-- To add minigame #4: write the module under minigames/, implement the four
-- methods in Types.Minigame, and add one require here. Nothing in RoundService,
-- ArenaService, ScoreService or the client needs to know it exists.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared").Config)

local Registry = {}

local ALL = {
	require(script.Parent.minigames.Recall),
	require(script.Parent.minigames.Grate),
	require(script.Parent.minigames.Line),
}

local byId = {}
for _, minigame in ALL do
	assert(not byId[minigame.Id], `duplicate minigame id "{minigame.Id}"`)
	byId[minigame.Id] = minigame
end

Registry.all = ALL

function Registry.get(id: string)
	return byId[id]
end

-- Pick a minigame that suits the current player count, avoiding an immediate
-- repeat. Falls back to allowing a repeat rather than returning nil, because a
-- round that cannot start is a far worse failure than the same game twice.
function Registry.pick(rng: Random, playerCount: number, lastId: string?)
	local eligible = {}
	for _, minigame in ALL do
		if playerCount >= minigame.MinPlayers and minigame.Id ~= lastId then
			table.insert(eligible, minigame)
		end
	end

	if #eligible == 0 then
		for _, minigame in ALL do
			if playerCount >= minigame.MinPlayers then
				table.insert(eligible, minigame)
			end
		end
	end

	if #eligible == 0 then
		if Config.Verbose then
			warn(`[Registry] no minigame supports {playerCount} players`)
		end
		return nil
	end

	return eligible[rng:NextInteger(1, #eligible)]
end

return Registry
