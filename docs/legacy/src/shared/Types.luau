--!strict
-- The contract every minigame implements. RoundService only ever calls these
-- four methods and never learns what a minigame actually is, which is what
-- makes adding minigame #4 a new file rather than a refactor.

export type MinigameResult = { [Player]: number }

export type MinigameContext = {
	-- The arena model this minigame should build itself inside of.
	arena: Model,
	-- Players who are actually competing this round (excludes late joiners).
	players: { Player },
	-- Deterministic seed. Always derive randomness from Random.new(seed) so a
	-- round can be reproduced exactly when you need to chase a bug.
	seed: number,
	-- 1-based round number within the current match; drives difficulty ramps.
	round: number,
}

export type Minigame = {
	Id: string,
	DisplayName: string, -- what the announce CRT shows
	Verb: string, -- what the hub marquee scrolls
	Duration: number, -- seconds of Play phase
	MinPlayers: number,

	-- Build the arena contents and prepare state. Must not start any timers.
	Setup: (self: any, ctx: MinigameContext) -> (),
	-- Begin play. Non-blocking: return immediately and drive internal phases
	-- with task.delay so RoundService stays in control of the clock.
	Start: (self: any) -> (),
	-- Stop play and return this round's scores. Must be safe to call early.
	Stop: (self: any) -> MinigameResult,
	-- Tear down everything Setup created. Must be safe to call twice.
	Cleanup: (self: any) -> (),
}

export type Icon = {
	id: string,
	label: string,
	image: string, -- rbxassetid://... ("" until uploaded)
	model: string?, -- child name in ReplicatedStorage.Items, if one exists
}

return {}
