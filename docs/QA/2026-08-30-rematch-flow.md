# QA - Post-verdict flow rework + touch half-autoaim (30.08.2026, evening)

User directives: remove the WINNER/2nd-place podium; after the final board go
directly to the play-again choice; BOTH players must agree to a rematch; a
player leaving mid-match shows a clear "cannot continue with a single player"
error; halve the mobile/iPad autoaim in Bird Hunting.

## What shipped

1. **Podium stage removed** (MachineFlow). Flow is now: final board
   (FinalScore hold) -> SHIFT REPORT (5 s) -> lobby. The Podium module and its
   require stay (revert = restore one block); selene's one new warning
   (unused `Podium`) is that tombstone.
2. **Unanimous rematch** (MachineFlow). The P1.7 carried-readiness is gone:
   `carryReady` + the 6 s grace no longer pre-ready the verdict's subjects.
   Everyone returns to the lobby UNREADY; the countdown only starts when ALL
   seated members press READY themselves (RoomService.maybeAutoStart:
   allReady + minPlayers, unchanged). The KenopsiaRetention step-5 funnel
   still fires for verdict participants still seated at the next preFlow.
3. **Clear solo-abort error** (RoomService). The mid-match below-minimum abort
   existed; only its reason string changed:
   "MEMBERSHIP BELOW MINIMUM" -> "PLAYER LEFT - CANNOT CONTINUE WITH A
   SINGLE PLAYER" (client shows "RUN ABORTED - <reason>" via LobbyError).
   Fires exactly when one participant remains (requiredMinimum 2 in
   production; StudioTestMinimum stays 1 so solo Studio tests still run).
4. **Touch half-autoaim** (KenopsiaClient, birdhunt sniper). Magnet pull
   halved: 9.5/6.5 -> 4.75/3.25 (scoped/unscoped ease rates). The search cone
   (6/8 deg) is unchanged - the magnet assists, it no longer aims.

## Verified IN PLAY (official Studio MCP reconnected this session)

First full in-Play session since the inner-game build started. Solo Studio
run (StudioTestMinimum=1): boot clean (all services online, EmoteService
"7 emote(s), 0/2 gamepass(es) armed"), READY -> TRANSMISSION roulette ->
birdhunt -> ... -> canteen -> FINAL AUDIT -> verdict board ("SUBJECT STATUS
VIABLE", 6800) -> **no podium** -> lobby with the roster showing the score
and the player **unreadied** ("Waiting for subjects ..."). Screenshots taken
at every stage. All 3 edited scripts weppy-validate clean; offline suites
green (feel 190, rules PASS, progression 247, emotes PASS).

## Production finding (the user's blue-screen report)

The published place shows only blue fog + "[ YOU ]" (the round-start runner
marker) - it is running OLD code. The current Studio place boots clean and
renders the full lobby menu. **Fix = Save & Publish the current place.**
Solo joiners in production correctly see the waiting menu (2 players
required); Studio allows 1 for testing.
