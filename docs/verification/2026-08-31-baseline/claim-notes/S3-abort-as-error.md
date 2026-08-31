# S3-abort-as-error -- VERDICT: REFUTED

## Half 1: "cancellation reported to players as MINIGAME ERROR" -- FALSE
- Only 2 abort() call sites in the whole server: MachineFlow:1398 ("MINIGAME ERROR", outcome=="error")
  and :1400 ("NO READY MINIGAME", outcome=="no-trial"). Cancellation has its own reason string.
- Player-left -> RoomService:340 abortMatch("PLAYER LEFT - CANNOT CONTINUE WITH A SINGLE PLAYER")
  -> :248 fail(plr, "RUN ABORTED - "..upper(reason)) -> LobbyError -> AbortScreen:93 black card.
- The abort-during-round route DOES set outcome="error" (round returns "aborted", loop error()s it at
  MachineFlow:1111/1118), so MachineFlow:1398 calls abort(room,"MINIGAME ERROR") a second time -- but
  abortMatch is doubly guarded (RoomService:240 phase must be Playing/Starting; it is "Aborting", and
  :241 room.aborting is already true) so it returns false and fires NO second LobbyError.
  Net: log-level mislabel only ("[MachineFlow] session X failed: aborted", "[RoomService] cleanup (error)").
  `outcome` has no other consumer (grep: only :1395/:1399/:1405).

## Half 2: "cleanup is not idempotent" -- FALSE at every layer
- MachineFlow:802-803  `if cleaned then return end; cleaned = true`
- RoomService:226-229  documented idempotent; `if room.phase == "Waiting" then return end`
- RoomService:240-241  abortMatch phase + room.aborting re-entry guards
- TrialKit:807-809     `Round:cleanup()` -> `if self.cleaned then return end`
- CanteenProtocol:936-937 `if not st or st.cleaned then return end`
- BirdHunting:1559-60 / Minefield:1573-74 / CanteenProtocol:1361-62 all nil the _guard BEFORE pcall(g.cleanup)

## Live parity (weppy, placeId 110672791536316, clientId ad22f53b, alias studio-2)
Every quoted region above read live and byte-identical to studio-src:
MachineFlow 766-784, 800-812, 1107-1121, 1382-1406; RoomService 226-252, 319-346; AbortScreen 86-97 (97 lines).
So this finding does NOT depend on the drifted client mirror. AbortScreen exists live and is NOT the
drifted KenopsiaClient.

## Not verified
No play test. RoomService.finishRun (:548) is dead code (0 callers).
BirdHunting.abort():1562 releases arenaBusy with no owner check (Canteen:1364 does check) -- separate concern.
