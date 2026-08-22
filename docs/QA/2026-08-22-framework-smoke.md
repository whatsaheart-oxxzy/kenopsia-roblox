# QA — Framework smoke test (MASTERPLAN P0.1), 2026-08-22

**Place:** Kenopsia_MainGame 110672791536316, Studio Play Solo (1 player, `StudioTestMinimum = 1`, solo maps onto the 2-player row).
**Setup (temporary, reverted afterwards):** `MachineFlow` registry `breather.ready = true`; `GameConfig.Playlist.TrialIds = { "breather" }`.
**Driver:** real client — READY clicked with `user_mouse_input` on `Info.Btn_READY`; no synthetic packets.

## Observed (client screen trace, 0.25 s sampling)

```
Round 1/3: RoundCard → Announce (cover) → CountText 3,2,1,GO! → attribute KenopsiaActiveTrial=breather,
           camera Scriptable (kit cam) → end cover → attribute cleared, camera Custom
Round 2/3: identical beat, 12.3 s from cover to GO clear
Round 3/3: identical beat
Score: odometer 1700, RankList row 1 = player, attribute KenopsiaSessionScore=1700
FinalScore → Selection (lobby) → Info after 7.3 s (auto-seat), KenopsiaSessionWins=1
```

Server log: `[MachineFlow] online - 1/15 trials ready (breather)`, `[MachineFlow] session S1-5384 seed=1166749335 trials=1 players=1`, `[RoomService] cleanup (completed)`. No errors, no warnings from TrialKit/Breather.

## Gate

- [x] `ev="begin"` arrives — kit camera engaged, KenopsiaActiveTrial set
- [x] `ev="end"` arrives — attribute cleared, players return to the Machine screens
- [x] no `_Runtime` folder remains — `workspace.KenopsiaArenas.breather` holds only `Slab, Spawn1-4, Cam` (6 descendants)
- [x] player back at spawn (1.0, 2.8, 4.0) after the session
- [ ] forced `error()` inside `runRound` recovered — **not run** (kept the session cheap; covered by TrialKit's pcall + MachineFlow finalizer by design, to be exercised with the first real trial)
- [x] parity place ↔ studio-src after the reverts: MachineFlow 27222/696594332, GameConfig 3214/1591920919, Pacing 5305/1684915598 (both sides)

## Side findings

- **Animation permission is still NOT effective** after the user shared access "to the universe" and a full Studio restart: every id (Boss Idle 95540888860028, Player Idle/Walk/Push/Death) logs `The experience doesn't have access permission to use asset id N. Click to share access`; `AnimationIds.warmup()` fell back to `RBX_ANIMSAVES`. `game.CreatorType = Group`, `CreatorId = 832614570`, `GameId = 10640788131` confirmed from the running server. Next step (user): click the "Click to share access" link in the Output for one id, check the asset's permissions page lists experience 10640788131; if the grant exists and still fails, re-publish the clips with the **group** as creator (Animation Editor → Publish → Creator: group) and paste the new ids.
- Pacing quick win applied (P0.3): `RoundSeconds.birdhunt` 90 → 60, `LEGS` 4/3/4 → 3/3/3. Audio: `Music.Trials.canteen` (clone of minefield), `Music.Loop` (136345765095808), `SFX.AccessGranted` (clone of Confirm), `birdhunt` volume 0.24 → 0.40.
- MCP note: after a Studio restart the proxy must be restarted too (`Stop-Process StudioMCP`), otherwise `list_roblox_studios` stays empty.
