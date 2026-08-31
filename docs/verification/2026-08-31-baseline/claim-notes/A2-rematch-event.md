# A2-rematch-event -- PARTIAL

Half true: RematchAccepted fires on passive presence (stronger than claimed -- there is
no opt-out at all). Half false: it has ZERO gameplay effect, nothing "counts as a replay".

## Arming (no player input)
MF:1279-1281  rematchIds from ctx.participantUserIds; room.rematch = {userIds, until_=os.clock()+60}
MF:296-301    participantUserIds = every room.members entry at match start

## Firing
MF:499-508 in preFlow, ~7s after room returns to Waiting (0.4s + LobbyReveal 6.4s)
MF:505     Telemetry.funnel(plr, "KenopsiaRetention", 5, "RematchAccepted")
Guard: still in room.members AND still in rematch.userIds AND <60s. Always <60s (~18s).

## Opt-out is unreachable
1. setReady(false) clears (RS:365-367) BUT RS:356 gates to Waiting/Starting.
   Results screen is Playing: score final MF:1271 -> hold FinalScore 6.0 -> shiftreport
   -> hold ShiftReport 5.0 -> cleanupToWaiting MF:1405. ~11s of Playing = rejected
   "RUN IN PROGRESS" (RS:357).
2. BACK TO MENU button (KC:3245,3268 -> dismiss(false) -> ReadyRemote:FireServer(false))
   only shown on a podium CLEAR packet (KC:3295-3301). NO SERVER SENDS kind="podium":
   Podium.raise/strike have zero callers in studio-src (only .claude/worktrees/mp-08-...).
   MF:1373 "DER PODIUMS-BEAT IST RAUS".
3. RoomLeaveRequest is a no-op (RS:608-611). removeMember only from PlayerRemoving
   (RS:633-634). Only exit = quit the game within ~18s.

## No gameplay effect
Telemetry.funnel -> only AnalyticsService:LogFunnelStepEvent (TEL:100-109). No dedupe.
RoomService.carryReady (RS:379) is DEAD CODE -- zero callers in studio-src or dev-src.
Auto-rematch removed 30.08.2026 (MF:490-498).

## NEEDS_RUNTIME
- live KenopsiaClient lines 3760-4124 (my dump stops at 3760; live is 4124, +818 vs mirror).
  Does live have an alternate end-card trigger / a second ReadyReq:FireServer(false)?
  Live 1-3760 has exactly ONE fire site: :2535 ReadyReq:FireServer(not myReady).
- play test: confirm no kind="podium" packet after a verdict.
- live-gui.md:218-240 -- 19 GuiButtons in StarterGui, no Btn_AGAIN/Btn_MENU. NOT decisive:
  the end card is Instance.new at runtime (card.Parent = machine), invisible at edit time.
- Server side IS at parity: MachineFlow 1514=1514, RoomService 645=645, live grep found
  RematchAccepted only at MachineFlow:505 (live-parity.md symbol table).
