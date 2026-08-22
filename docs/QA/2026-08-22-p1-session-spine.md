# QA — P1.1 honest roulette, P1.2 standings, P1.3 FINAL AUDIT + verdict (2026-08-22)

**Place:** Kenopsia_MainGame, Studio Play Solo; temporary `TrialIds = { "breather", "stacker" }` with both stubs `ready=true` (all reverted). Real client, READY via `user_mouse_input`, screen trace sampled every 0.5 s.

## Observed

```
  0.0 Info       NEXT SIMULATION: BREATHER            <- lobby reveal
 10.2 RoundCard  Round 1/3 / INHALE. NOT TOO DEEP._   <- first trial IS the reveal
 20.5 Status     STANDINGS - ROUND 1/3 | 1. OXXZY     <- standings after round 1 (2.5 s)
 35.3 Status     STANDINGS - ROUND 2/3 | 1. OXXZY
 51.7 Score      SIMULATION CONCLUSION / OPERATOR PERFORMANCE SCORE / 1700
 59.8 Status     PALLET DUTY | ... | FINAL AUDIT. DOUBLE WEIGHT. | Bootstrapping ...
 67.5 RoundCard  Round 1/3 / FINAL AUDIT. HIGHEST STACK KEEPS THE JOB._
108.8 Score      ... / 5100                           <- 1700 + 2 x 1700
113.4 Score      FINAL AUDIT CONCLUDED / SUBJECT STATUS VIABLE
121.6 Info       NEXT SIMULATION: BREATHER            <- lobby again (new seed)
```
Server: `[MachineFlow] session S1-9533 seed=893700383 trials=2 players=1`, `[RoomService] cleanup (completed)`. No errors.

## Changes

- `MachineFlow.runSelection` mints the session seed (`room.pendingSeed`) and reveals `Playlist.session(...)[1]`; `runMatch` consumes that seed. The lobby reveal can no longer contradict the first trial.
- `standingsLines()` + `{kind="status"}` after every round except the last; `Pacing.Timing.Standings = 2.5`.
- `isFinal` (last trial of a multi-trial session): briefing line `FINAL AUDIT. DOUBLE WEIGHT.`, round-card prefix `FINAL AUDIT.`, `Scoring.distribute(ranking, 2)` (pool × weight, still sums exactly; `tests/rules.lua` green with weight 1).
- Client `showScore`: final board shows `FINAL AUDIT CONCLUDED / SUBJECT STATUS VIABLE|REJECTED` (red for REJECTED) with `Confirm`/`Reject` sfx; non-final boards restore the authored labels.

## Gate

- [x] reveal == first trial (1/1 session; rule is structural now)
- [x] standings card after every non-final round, typed within its 2.5 s
- [x] final trial pays double; final screen shows the verdict
- [x] offline: `tests/rules.lua` PASS, `tests/trialrules.lua` PASS, selene 0/0
- [x] parity place ↔ studio-src for MachineFlow, Scoring, Pacing, GameConfig, KenopsiaClient
- [ ] not done here: depleting 15-tile grid (needs the P2 GUI rebuild), podium (P1.3 second half), Machine comment lines (P1.4)

## Gotcha

`multi_edit` rewrites a CRLF script as LF. `KenopsiaClient` was the only CRLF file; the mirror is LF now too (the place is the truth).
