# A4-session-id  -- VERDICT: PARTIAL (core CONFIRMED, "one-time onboarding" imprecise)

## Facts
[SOURCE] Telemetry.luau:104  LogFunnelStepEvent(player, funnelName, nil, step, stepName)  -- sessionId nil
[RUNTIME] live MainGame 110672791536316 (weppy studio-2) Telemetry line 104 = identical
[SOURCE+RUNTIME] exactly 5 funnel call sites in the WHOLE place, one funnel name "KenopsiaRetention":
  1 Joined          Profiles.luau:261        per player per SERVER JOIN
  2 RouletteSeen    MachineFlow.luau:476     per MATCH (preFlow respawned at MachineFlow:1409-1410)
  3 Round1Done      MachineFlow.luau:1156    per MATCH (trialIndex==1 and roundIndex==1, resets per runMatch)
  4 VerdictSeen     MachineFlow.luau:1327    per MATCH
  5 RematchAccepted MachineFlow.luau:505     per MATCH
[SOURCE] MachineFlow.luau:473-474 "One-time funnel -- Analytics dedupes repeats per player."  <- unverified assumption
[SOURCE] Telemetry.luau:8 "funnelSessionId nil: documented-optional, fine for one-time funnels"
[SOURCE] globalTypes.d.luau:9233 LogOnboardingFunnelStepEvent(self, player, step, stepName?, customFields?)  <- the actual one-time API, never used
[SOURCE] Roblox docs (create.roblox.com/docs/production/analytics/funnel-events): onboarding = once per user = LogOnboardingFunnelStepEvent;
         session = multiple times per user = LogFunnelStepEvent; funnelSessionId "distinguish between different sessions of the same user in a recurring funnel"
[SOURCE] a per-match id ALREADY EXISTS and is unused by telemetry: RoomService.luau:297 room.sessionId = ("S%d-%d"):format(...)
         cleared at RoomService.luau:205 (toWaiting) -> not available at step 2 (MachineFlow.luau:453 "no sessionId yet")
         Contexts.luau:214 sessionId = HttpService:GenerateGUID(false) (per-session context)

## Where the claim is imprecise
No step is "one-time onboarding". Step 1 Joined fires on EVERY server join, not once per lifetime,
and LogOnboardingFunnelStepEvent is never called. The real mixture is per-JOIN (step 1) vs per-MATCH (2-5).

## Absence findings
- FirstInput (docs/INNER-GAME-PLAN.md:245) is not implemented anywhere.
- Planned custom events TrialCompleted/SessionVerdict/QuestClaimed/StreakTick/EmotePlayed: zero call sites.
  Telemetry.event() is only ever reached from the client remote (MobileBlackScreen, LightGuard.client.luau:63).
- room.sessionId is only unique WITHIN one server ("S1-43210") -> not safe as a funnelSessionId across servers.

## NEEDS_RUNTIME
Which engine branch is true. Play two consecutive matches with the same player in the published DEV place,
then read Creator Analytics -> Funnels -> KenopsiaRetention: compare RouletteSeen count to distinct-user
Joined count. <= means the engine dedupes (per-match conversion unmeasurable); > means it double-counts
(step-to-step conversion >100%). Neither equals match count.
