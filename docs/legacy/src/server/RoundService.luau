-- The round state machine. This is the spine of the game.
--
-- Lobby -> Intermission -> [ Announce -> Load -> Countdown -> Play -> Score ] x N -> Results
--
-- Design rule that matters more than it looks: the minigame NEVER owns the
-- clock. RoundService starts it, waits its Duration, and stops it. A minigame
-- that decides for itself when the round is over is a minigame that can hang the
-- match, and a hung match on a live server is unrecoverable without a shutdown.
--
-- Every phase transition is wrapped so a minigame that throws takes down its own
-- round and nothing else. An error in Recall must not stop the server from ever
-- running Grate again.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("KenopsiaShared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local State = require(Shared.State)

local ArenaService = require(script.Parent.ArenaService)
local ScoreService = require(script.Parent.ScoreService)
local Registry = require(script.Parent.MinigameRegistry)

local RoundEvent = Net.get("RoundEvent")

local RoundService = {}

local started = false
local lastMinigameId: string? = nil

local function log(...)
	if Config.Verbose then
		print("[Round]", ...)
	end
end

-- Run a minigame method, swallowing errors so one bad round cannot kill the
-- loop. Returns nil on failure.
local function protectedCall(minigame, method: string, ...)
	local ok, result = pcall(minigame[method], minigame, ...)
	if not ok then
		warn(`[Round] {minigame.Id}:{method}() errored: {result}`)
		return nil
	end
	return result
end

local function eligiblePlayers(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(out, player)
		end
	end
	return out
end

local function waitPhase(phase: State.Phase, duration: number)
	State.setPhase(phase, duration)
	task.wait(duration)
end

-- One round. Returns false if it could not run at all.
local function runRound(roundNumber: number, rng: Random): boolean
	local players = eligiblePlayers()
	if #players < Config.MinPlayers then
		return false
	end

	local minigame = Registry.pick(rng, #players, lastMinigameId)
	if not minigame then
		return false
	end
	lastMinigameId = minigame.Id

	local arena = ArenaService.getArena(minigame.Id)
	local seed = rng:NextInteger(1, 2 ^ 30)

	State.set("Round", roundNumber)
	State.set("Rounds", Config.RoundsPerMatch)
	State.set("Minigame", minigame.DisplayName)
	State.set("Verb", minigame.Verb)

	-- ANNOUNCE: the CRT names the program before anyone moves.
	RoundEvent:FireAllClients({
		kind = "announce",
		name = minigame.DisplayName,
		verb = minigame.Verb,
		round = roundNumber,
		rounds = Config.RoundsPerMatch,
	})
	waitPhase("Announce", Config.Phase.Announce)

	-- LOAD: build the arena, then move players into it.
	-- Setup's return value is deliberately ignored. If it threw, protectedCall
	-- already warned and the minigame is in a half-built state - we still run the
	-- round (it will simply score everyone zero) and still call Cleanup at the
	-- end, which the contract requires to be safe on a partial Setup. Bailing out
	-- here instead would leave the runtime folder orphaned in the arena.
	protectedCall(minigame, "Setup", {
		arena = arena,
		players = players,
		seed = seed,
		round = roundNumber,
	})

	ArenaService.sendPlayers(players, arena)
	ArenaService.setFrozen(players, true)
	waitPhase("Load", Config.Phase.Load)

	-- COUNTDOWN: players can see the arena but not move yet.
	waitPhase("Countdown", Config.Phase.Countdown)

	-- PLAY.
	ArenaService.setFrozen(players, false)
	protectedCall(minigame, "Start")
	State.setPhase("Play", minigame.Duration)
	task.wait(minigame.Duration)

	-- SCORE.
	local result = protectedCall(minigame, "Stop") or {}
	ArenaService.setFrozen(players, true)
	ScoreService.applyResult(result)

	RoundEvent:FireAllClients({
		kind = "roundResult",
		standings = ScoreService.standings(),
	})
	waitPhase("Score", Config.Phase.Score)

	protectedCall(minigame, "Cleanup")
	ArenaService.clearRuntime(arena)
	ArenaService.setFrozen(players, false)

	return true
end

local function runMatch()
	ScoreService.reset()

	for roundNumber = 1, Config.RoundsPerMatch do
		if #eligiblePlayers() < Config.MinPlayers then
			log("not enough players - abandoning match")
			break
		end
		local ok = runRound(roundNumber, Random.new(os.clock() * 1e6))
		if not ok then
			log(`round {roundNumber} could not start`)
			task.wait(2)
		end
	end

	-- RESULTS.
	local winner = ScoreService.winner()
	State.set("Winner", winner or "")
	RoundEvent:FireAllClients({
		kind = "matchResult",
		winner = winner,
		standings = ScoreService.standings(),
	})
	waitPhase("Results", Config.Phase.Results)

	local lobby = ArenaService.getArena("lobby")
	ArenaService.sendPlayers(eligiblePlayers(), lobby)
end

function RoundService.start()
	assert(not started, "RoundService.start called twice")
	started = true

	task.spawn(function()
		while true do
			-- LOBBY: hold here until enough people are present.
			State.setPhase("Lobby")
			State.set("Minigame", "")
			local lobby = ArenaService.getArena("lobby")
			ArenaService.sendPlayers(eligiblePlayers(), lobby)

			while #eligiblePlayers() < Config.MinPlayers do
				task.wait(1)
			end

			waitPhase("Intermission", Config.Phase.Intermission)

			-- The whole match runs inside a pcall. If anything in here throws,
			-- we log it and fall back to the lobby rather than ending the loop.
			local ok, err = pcall(runMatch)
			if not ok then
				warn(`[Round] match errored: {err}`)
				task.wait(3)
			end
		end
	end)

	log("round loop started")
end

return RoundService
