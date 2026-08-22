# QA — P1.6 robustness + P1.7 rematch / late joiners (2026-08-22)

**Place:** Kenopsia_MainGame, Studio Play Solo, temporary `TrialIds = { "breather" }` + stub `ready=true` (reverted). Real client; READY via `user_mouse_input`.

## Observed (server log)

```
[Kenopsia] unhandled MachineState kind: bogus        <- 2 bogus packets fired from the server, ONE warning, typewriters untouched
[MachineFlow] session S1-61890 seed=1829693381 trials=1 players=1
[RoomService] cleanup (completed)
[RoomService] rematch: 1 subject(s) re-armed         <- after the post-verdict lobby reveal + 6 s grace
[MachineFlow] session S2-43370 seed=199213246 trials=1 players=1   <- next session started by itself
```

## Changes

- **Round watchdog** (`MachineFlow.runRoundGuarded`): each round runs on its own thread; budget = `Pacing.RoundSeconds[id] + 15 + 20`. On expiry the thread is cancelled, a warning is logged, the trial ends early with the totals it has and the session continues (F-06 closed).
- **Unknown packet kinds** (client funnel): kinds outside `selection/info/status/round/score/announce/hide` are logged once and ignored instead of bumping `session` (which cancelled every typewriter/odometer mid-word).
- **Anti-monotony** (`Playlist.Form`, `Playlist.Breaks`, `Playlist.arrange`): never three survival-form trials in a row, never `breather`/`stacker` first or last. Exhaustive for slices ≤ 7 (minimal displacement from the seed order, deterministic); 1000-seed probe: 0 violations except the 4 slices that are five survival ids (unarrangeable). Applied in both `runSelection` (reveal) and `playableOrder`, so the reveal stays honest.
- **Rematch**: the verdict's participants are stored on the room (`room.rematch`, 60 s validity); after the next lobby reveal `preFlow` waits `GameConfig.Match.RematchGrace = 6` s and `RoomService.carryReady()` re-arms them → countdown → next session. Un-ready still works during the grace/countdown.
- **Late joiners** (F-09, first half): a player on the bench during Playing gets a Status card (`A CYCLE IS IN PROGRESS. / TRIAL i OF n: NAME / YOU ARE ON THE BENCH. / THE NEXT CYCLE TAKES YOU.`), refreshed per trial via the 2 s watchdog. Not done: the audience camera onto the running arena.

## Gate

- [x] offline: `tests/rules.lua` PASS, `tests/trialrules.lua` PASS, selene 0/0, Playlist stays Lua-5.1 portable
- [x] unknown kind: warned once, session unaffected
- [x] rematch: re-armed and restarted without a click
- [x] parity place ↔ studio-src: MachineFlow, RoomService, Playlist, GameConfig, KenopsiaClient
- [ ] not verified live: the watchdog cutting a hung round (no hanging trial to test with; unit-level logic only), the bench card (needs a second player — Team Test)
