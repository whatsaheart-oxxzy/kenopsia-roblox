# Code architecture of the Kenopsia Roblox party game (repo C:\Users\Asus\Claude\Kenopsia_Roblox Project) — session loop, GUI, camera/input/animation wiring, trial-authoring pattern, scaling to 15 trials, timing constants, packet handling, and every place "feel" is decided.

> Read-only research lens, measured 2026-08-22 (workflow wf_a13d7aec-54c). Facts cite their source; treat plan documents as claims, measurements as truth.

## Summary

Kenopsia is a 2-4 player, one-room-per-server party game with a two-layer architecture: RoomService owns Waiting/Starting/Playing/Aborting, MachineFlow owns everything inside Playing (Selecting -> Briefing -> Trial xN -> Score -> FinalScore). Every session-level delay comes from one pure module, Pacing.Timing; every in-round delay is invented by the individual trial.

Three trials are live (birdhunt, minefield, canteen) and are written as three hand-rolled monoliths, each with its own countdown, its own role/camera packets, and its own client branch inside a 2413-line / 85 KB KenopsiaClient.client.luau. A second, much better architecture already exists in the repo — TrialKit (server round object + 12-step input validation chain) and TrialClientKit (packet router + per-trial `kit` with hud/pad/camera/movement/bindKey) — plus 12 registered but stubbed trials. Per docs/place/07-FINDINGS.md F-04, none of that framework is in the live place, so the shipped game is still the legacy three.

The GUI is one authored ScreenGui (KenopsiaMachine, 521 descendants) with six full-screen screens plus overlays; only five of the six are ever shown — Briefing is dead (client only hides it). The final board's VIABLE/REJECTED verdict the server computes is never rendered. The lobby roulette picks a trial with math.random in preFlow that is unrelated to the seed-shuffled order runMatch actually plays, so the pre-match reveal can lie.

Scaling blockers to 15 trials are concrete: 7 hard-wired TouchControls buttons, 8 icons in IconPool with silent fallback to Crosshair, XBotMoves substring gating (scan/eat/sneak/push) that legacy input paths key on, per-trial lighting/music keyed on hardcoded ids, a fixed 1700-point pool that makes a 20 s trial worth the same as a 4x90 s trial, and no round timeout in MachineFlow (only TrialKit's failsafe would fix it).

Measured upper-bound session length today: ~771 s (12.8 min) at 4 players, ~893 s (14.9 min) at 2 players. GameConfig.Playlist.PerSession = 5 keeps that roughly constant once 15 trials exist.

"Feel" is decided in ~30 places, almost all inside KenopsiaClient: tween easings (Quart/Quad/Linear), the typewriter (22-30 cps), the trauma-model screen shake, the odometer digit roll, screen blood, and the 1.4 s fader.

## Facts

- [BOOT] Server entry is 2 lines: RoomService.start() then MachineFlow.start(RoomService). Nothing else boots.
  - *Source:* docs/place/02-SCRIPTS.md:50-51 (full text of ServerScriptService.KenopsiaServer.Main, 340 B)
- [LOOP 0 - JOIN] A 2 s watchdog loop auto-seats any player 7 s after their KenopsiaJoinedAt attribute, and spawns the lobby pre-flow whenever a Waiting room has members and no preShown flag.
  - *Source:* studio-src/ServerScriptService/KenopsiaServer/Services/MachineFlow.luau:747-782 (task.wait(2); line 756 `> 7`; lines 774-779 preFlow spawn)
- [LOOP 1 - LOBBY ROULETTE] preFlow picks a trial with math.random over the enabled pool, sets stage 'Selecting', sends {kind='selection', icons, chosen}, waits a HARD-CODED 6.4 s (not from Pacing), then sends {kind='info'}.
  - *Source:* MachineFlow.luau:366-397 (runSelection at 328-363; task.wait(6.4) at line 387)
- [LOOP 2 - READY] Client READY -> RoomReadyRequest -> setReady -> maybeAutoStart -> beginCountdown: Config.Match.StartCountdown = 3 iterations of task.wait(1), then sessionId is minted as 'S<n>-<ms%100000>' and phase becomes Playing, firing RunRequested.
  - *Source:* RoomService.luau:344-363, 311-317, 276-309 (countdown loop 283-288, sessionId 297, Fire 307); GameConfig.luau:74
- [LOOP 3 - SESSION SETUP] runMatch mints seed = math.random(1, 2147483647) server-side, builds order via Playlist.session(Playlist.order(seed), enabled, PerSession=5), and zeroes KenopsiaSessionScore/Wins ONCE before the trial loop.
  - *Source:* MachineFlow.luau:460, 409-419, 487-493; GameConfig.luau:51
- [LOOP 4 - PER TRIAL] Selecting: setStage + setProgress, {kind='info', id,name,icon,index,total}, hold Pacing.Timing.Reveal = 3.5 s.
  - *Source:* MachineFlow.luau:510-530
- [LOOP 5 - BRIEFING] Briefing: {kind='status', lines={displayName, tagline, ' ', 'Minigame i of n.', 'Bootstrapping simulation ...'}}, hold Pacing.Timing.ControlCard = 8.0 s. NOTE: this drives the Status screen, not the Briefing screen.
  - *Source:* MachineFlow.luau:533-541
- [LOOP 6 - ROUND CARD] Per round: setProgress(roundIndex/roundCount), {kind='round', n, total, verbs=trial.tagline}, hold Pacing.Timing.RoundCard = 3.0 s, then {kind='hide'} and setActiveTrial(trial.id).
  - *Source:* MachineFlow.luau:558-571
- [LOOP 7 - TRIAL CALL] birdhunt with >=2 members is called as runRound(room, roundIndex, hunterUserId, legIndex, legTotal) - 5 args, the only trial with that signature; every other trial is runRound(room, roundIndex). Both are pcall'd and a failure is re-raised as error(msg, 0).
  - *Source:* MachineFlow.luau:574-592
- [LOOP 8 - SETTLE] After each round: setActiveTrial(''), roundCtx.cleanup:run(), score accumulation, hold Pacing.Timing.RoundSettle = 1.5 s.
  - *Source:* MachineFlow.luau:594-599
- [LOOP 9 - INTERIM SCORE] Scoring.rankRound + Scoring.distribute award EXACTLY Pacing.TrialPointPool = 1700 per completed trial regardless of raw in-trial numbers; board is sent as {kind='score', board, trialId, index, total, final=false}, hold Pacing.Timing.InterimScore = 4.5 s. No {kind='hide'} follows, deliberately.
  - *Source:* MachineFlow.luau:606-640; Scoring.luau:93-137; Pacing.luau:125
- [LOOP 10 - FINAL] FinalScore stage: highest cumulative total = 'VIABLE' (ties all viable, KenopsiaSessionWins +1), everyone else 'REJECTED'; sent as {kind='score', board=final, final=true}; hold Pacing.Timing.FinalScore = 8.0 s.
  - *Source:* MachineFlow.luau:654-682
- [LOOP 11 - UNWIND] One finalizer for every outcome (completed|cancelled|no-trial|error): cleanup() clears KenopsiaActiveTrial, calls trial cleanup, cancels the session context, sends {kind='hide'}; then RoomService.cleanupToWaiting, task.wait(0.4), and preFlow restarts.
  - *Source:* MachineFlow.luau:435-456, 686-716
- [LOOP - MEASURED LENGTH] Upper-bound session at 4 players with the 3 ready trials = 770.9 s (12.8 min): birdhunt 4 legs x (4.5 + 4 + 3 + 90) + 16 = 422 s; minefield 3 rounds x (4.5 + 2.8 + 3 + 55) + 16 = 211.9 s; canteen 2 rounds x (4.5 + 2.4 + 3 + 45 + 1.6) + 16 = 129 s; + FinalScore 8 s. At 2 players it is 892.7 s (14.9 min) because minefield runs 4 rounds and canteen 3.
  - *Source:* Computed from Pacing.luau:34-58, 76-95, 111-121 + MachineFlow.luau:530/541/569/599/635/682 + BirdHunting.luau:724,730-736 + Minefield.luau:346,413-418 + CanteenProtocol.luau:788,790-794,886
- [LOOP - COUNTDOWN OWNERSHIP] MachineFlow never sends the 3-2-1. Each trial does its own: TrialKit Round:countdown (3 x 1 s), BirdHunting (4 s hunter-setup hold then 3 x 1 s), Minefield (2.8 s announce then 3 x 1 s), CanteenProtocol (2.4 s cover then 3 x 1 s). Four independent implementations of the same beat.
  - *Source:* TrialKit.luau:518-541; BirdHunting.luau:723-741; Minefield.luau:345-420; CanteenProtocol.luau:787-796
- [GUI] One authored ScreenGui 'KenopsiaMachine' (ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=50, ZIndexBehavior=Sibling, 521 descendants). Font is Enum.Font.Code everywhere; the whole palette is 5 phosphor colours + danger red + bone white.
  - *Source:* docs/place/04-GUI.md:1-35
- [GUI] Screen -> code map: Selection = showSelection (KenopsiaClient.client.luau:1615-1694); Info = showInfo (1696-1716); Status = showStatus (1720-1738); RoundCard = showRound (1740-1748); Score = showScore (1766-1834) with rollDigit (1750-1764); Announce = showAnnounce (1836-1859); hideAll (403-411) blanks all six.
  - *Source:* studio-src/StarterPlayer/StarterPlayerScripts/KenopsiaClient.client.luau (line numbers as listed)
- [GUI] The 'Briefing' screen is DEAD: it is resolved at KenopsiaClient.client.luau:56 and set Visible=false in hideAll at line 408, and nothing anywhere sets it Visible=true. The Briefing stage renders on the Status screen instead.
  - *Source:* KenopsiaClient.client.luau:56, 408 (grep for 'briefing' returns only these two lines)
- [GUI] Overlays and where they are driven: CountText (count/go handlers, 2123-2129 and 2163-2176), Fader (2115-2121), JoinCover (hidden at 2196-2199), HitMark (2132-2155, DEAD - nothing sends kind='hitmark'), Scope/HipCross (applyScope 598-615, alignHipCross 581-589), SettingsPanel (2258-2296), Warning content card (2224-2256), LobbyError notice in its OWN ScreenGui 'KenopsiaNotice' DisplayOrder 900 (2359-2411).
  - *Source:* KenopsiaClient.client.luau (line numbers as listed); comment at 2141 states nothing sends hitmark
- [GUI] Two HUDs are built at runtime, not authored: CanteenHud (buildCanteenHud, ZIndex 66 - deliberately above Scope.Mask at 65) and CanteenTouch pad (buildCanteenTouch, ZIndex 68, two 110x110 buttons at x=0.18 and x=0.82).
  - *Source:* KenopsiaClient.client.luau:1106-1202, 1261-1309
- [GUI] MachineLayout rescales the GUI per platform against a 710 px reference height: Mobile clamp(s,0.42,0.85), Console clamp(s*1.1,1,1.4), Desktop clamp(s,0.8,1.3); it writes the Platform and LayoutScale attributes and drives console gamepad focus (PRIMARY = Info->Btn_READY, Warning->Btn_CONTINUE).
  - *Source:* studio-src/StarterPlayer/StarterPlayerScripts/MachineLayout.client.luau:17, 46-56, 281-308, 343-371
- [GUI] The CONTROLS window text lookup order is: TrialClients/<id>.controlsText (pcall require, cached) -> TRIAL_TEXT[trialId] -> TRIAL_TEXT.default. The old fallback to birdhunt (which showed sniper controls for any unknown id) was replaced by a neutral 'PLAYERS:/RULE:' row.
  - *Source:* MachineLayout.client.luau:186-226 (lookup at 226), TRIAL_TEXT.default at 176-183
- [CAMERA] There is exactly ONE camera writer: a single RenderStepped connection with a 4-way priority chain - spectateCF (death cam) > trialCam (MP-05 kit) > runnerCam ('top' or 'chase') > untouched. A SECOND RenderStepped connection multiplies the shake on top, and its position after the camera writers is load-bearing.
  - *Source:* KenopsiaClient.client.luau:500-541 (chain), 1867-1878 (shake, comment at 1863-1864 explains the ordering requirement)
- [CAMERA] Legacy runner cam 'top' (Dead Zone): eye = root + (0, 24, -9*camDir), lerp min(dt*6,1), look = eye + (0,-24,15*camDir); it also forces Humanoid.AutoRotate=false and rewrites root yaw EVERY FRAME. 'chase' (Bird Hunting): eye = root + (0,20,-17*camDir), look = root + (0,3,30*camDir), no lerp.
  - *Source:* KenopsiaClient.client.luau:520-539
- [CAMERA] Sniper cam is its own RenderStepped block: sniperBase = CFrame.lookAt(SniperPost.Position, Start + (0,4,0)) resolved with a 30 x 0.2 s retry loop; yaw clamped +/-0.7, pitch clamped -0.6..0.25; scoped adds a breathing drift of sin(t*0.5)*0.0004*(70/FOV).
  - *Source:* KenopsiaClient.client.luau:690-714 (base), 1401-1481 (writer; clamps 1424-1425; drift 1434-1439)
- [CAMERA] The kit camera has 3 modes computed in one pure function: 'top' (eye = subject + (0,height,-back), default height 24 / back 9 / lerp 6, optional fixed=true freeze and radius scaling), 'follow' (offset/look/lerp), 'fixed' (constant CFrame). kit.camera.top({fixed=true}) derives an arena-wide shot from the replicated static-part bounds.
  - *Source:* studio-src/StarterPlayer/StarterPlayerScripts/TrialClientKit.luau:70-107 (computeCamera), 391-427 (arenaBounds + kit.camera.top)
- [INPUT - LEGACY] Sniper: LMB fire / RMB scope / R2 fire / L2 scope / Y zoom / MouseWheel zoom, FIRE_COOLDOWN 2.2 s client-side mirror; touch drag aims (TouchMoved), gamepad Thumbstick2 with 0.15 deadzone aims at 460 units/s.
  - *Source:* KenopsiaClient.client.luau:738-807, 784-796, 1344-1353
- [INPUT - LEGACY] Sonar: hold F (PC) / ButtonY (gamepad) / Btn_SCAN (touch); firePulse rate-limits at 0.9 s and the hold loop re-fires every 0.9 s; the packet is a bare {trialId='minefield', action='pulse', roundToken}.
  - *Source:* KenopsiaClient.client.luau:913-939 (0.9 s at 917), 944-959, 1041-1068
- [INPUT - LEGACY] Canteen: LMB/L2 = plate, RMB/R2 = mouth, guarded by canteenActive so it does not fight the sniper handler that claims the same two buttons; client cooldowns 0.16 s / 0.35 s are explicit mirrors of the server's MIN_PLATE_INTERVAL 0.16 / MIN_MOUTH_INTERVAL 0.50.
  - *Source:* KenopsiaClient.client.luau:1091-1092, 1237-1256, 1330-1342; CanteenProtocol.luau:51-52
- [INPUT - LEGACY GATING] Every legacy input path is gated on a SUBSTRING of the character attribute XBotMoves: 'scan' (sonar + WalkSpeed 7), 'eat' (canteen), 'sneak' (crouch button), 'push' (punch button). This is why MP-06 forbids new trials from putting those substrings in XBotMoves.
  - *Source:* KenopsiaClient.client.luau:433-434, 823-830, 886-889, 1101-1104; docs/MP-06-FRAMEWORK.md:73-75
- [INPUT - KIT] kit.bindKey(name, {KeyCodes/UserInputTypes}, onBegan, onEnded) gives edge semantics with a gameProcessed guard and an isActive guard; kit.bindArrows maps Arrows + WASD + DPad to Up/Down/Left/Right; every bind is released by the router's _teardown.
  - *Source:* TrialClientKit.luau:461-504, 587-600
- [TOUCH] The authored TouchControls contains 7 fixed buttons (Btn_FIRE, SCOPE, ZOOM, PUNCH, CROUCH, SCAN, EAT) sharing two anchor positions; visibility is hand-wired per legacy role in setSniperRig and setRunnerTouch. kit.pad() replaces this by building buttons at runtime into a per-trial Frame 'TrialTouch_<id>' at ZIndex 68, Visible = touchAllowed().
  - *Source:* docs/place/04-GUI.md:210-232; KenopsiaClient.client.luau:690-736, 846-865; TrialClientKit.luau:201-211, 253-278
- [ANIMATION] All animation asset ids live in exactly one module. AnimationIds.resolve(group,name) returns nil for id 0 and never throws; AnimationIds.load caches Animation instances and pcalls LoadAnimation. Six ids are still 0: Player.Eat, Boss.Death, and 4 face textures.
  - *Source:* studio-src/ReplicatedStorage/Kenopsia/Shared/Config/AnimationIds.luau:17-43, 152-183; docs/place/07-FINDINGS.md:198-209
- [ANIMATION] warmup() probes ONE published id on a throwaway Animator for up to 3 s; if Length stays 0 it sets publishedPlayable=false and every later load() falls back to KeyframeSequenceProvider:RegisterKeyframeSequence over ServerStorage.RBX_ANIMSAVES - which is Studio-only. On a live server the rigs simply do not move.
  - *Source:* AnimationIds.luau:83-150; docs/place/07-FINDINGS.md:98-114
- [ANIMATION] The seated diner pose is not a clip: it is four bind-pose bone rotations (HIP_FOLD pi/2, KNEE_FOLD -pi/2, ARM_DROP 60deg, ELBOW_BEND 25deg) written into Bone.CFrame, so it holds forever at zero cost and animation Transforms stack on top of it.
  - *Source:* studio-src/ServerScriptService/KenopsiaServer/Services/CanteenDiner.luau:100-124
- [ANIMATION] Diner scale is derived, not authored: CanteenDiner.scaleFor(seatY, mouthY) solves for the scale at which the rig's pelvis reaches the chair AND its Head bone reaches the MouthTarget marker, clamped to 0.4..3.0.
  - *Source:* CanteenDiner.luau:47-71
- [TRIAL PATTERN] A new trial is exactly 4 files, and the implementer may touch NOTHING else: Services/<Name>.luau (server on TrialKit), Shared/Rules/<Name>Rules.luau (pure, Lua 5.1 portable), StarterPlayerScripts/TrialClients/<id>.luau (client on TrialClientKit), tests/<id>.lua (>=15 offline checks).
  - *Source:* docs/MP-06-FRAMEWORK.md:14-29 (ownership rules and the NEVER-edit list)
- [TRIAL PATTERN] Registration is two independent gates: the id must appear in GameConfig.Playlist.TrialIds AND its MachineFlow.TRIALS entry must declare ready = true. All 15 ids are already listed; 12 have ready = false.
  - *Source:* MachineFlow.luau:243-256 (enabledTrials), 57-232 (registry); GameConfig.luau:42-46
- [TRIAL PATTERN] The canonical server body is: zeroScores -> ensureArena(buildFn) -> newRound(guard) -> rng -> Rules.generate(nextInt, #members) -> runtimeFolder -> R:place(spots) -> R:begin(fields) -> R:cover(TAGLINE) -> R:wait(2.8) -> R:countdown() -> R:tick(fn) -> R:scores(fn) -> R:endRound(), wrapped by TrialKit.runRound.
  - *Source:* docs/MP-06-FRAMEWORK.md:204-257; live example studio-src/ServerScriptService/KenopsiaServer/Services/Upstream.luau:46-70
- [TRIAL CAN] R:tick(fn) runs fn(dt) every ~0.05 s while os.clock() < deadline AND < failsafe, breaking immediately if the round is no longer active or fn returns 'stop'. failsafe = deadline + FAILSAFE_EXTRA (20 s) and is honoured even if the trial pushes the deadline out.
  - *Source:* TrialKit.luau:56, 648-673
- [TRIAL CAN] R:place(spots) freezes placement (Health=Max, WalkSpeed 0, JumpPower 0, optional root Anchored) and records originals; R:countdown() lifts the freeze at GO by applying spots.walkSpeed (default 16) server-side. This deviation from MP-05 is deliberate - a server-set 16 at placement would let players walk during the countdown.
  - *Source:* TrialKit.luau:543-590, 518-541; docs/MP-06-FRAMEWORK.md:412
- [TRIAL CAN] R:sample(uid, dt, maxSpeed, aabb) is the anti-teleport clamp: XZ distance > maxSpeed*elapsed*1.5 + 0.05, or outside the AABB, snaps the root back to the last good position and zeroes AssemblyLinearVelocity. Positions come from R:sample, never from packet data.
  - *Source:* TrialKit.luau:609-642; docs/MP-06-FRAMEWORK.md:168-169
- [TRIAL CAN] R:kill(uid, opts) is the fixed D12 death sequence: BloodFX.kill, room-wide {kind='gorefx', power 1.5}, Health 0, personal death card, and after DEATH_CAM_DELAY = 3.2 s (active-checked) a spectate packet watching everyone still running. R:out is the non-lethal twin (ev='out', WalkSpeed 0, optional spectate).
  - *Source:* TrialKit.luau:53, 697-738
- [TRIAL CAN] Tokens: R.roundToken = TrialRules.token(trialId, sessionId, roundIndex, ms) minted in newRound before any yield; the client echoes it on every packet; TrialKit.wireInput rejects a mismatch at step 8. Contexts additionally mints per-LEG tokens because Bird Hunting's legs share one round index.
  - *Source:* TrialKit.luau:422-456, 330-332, 385; docs/place/02-SCRIPTS.md:380-387
- [TRIAL CANNOT] A trial must never send role='runner'/'sniper'/'none', never FireAllClients, and never set XBotMoves to anything containing scan/eat/sneak/push - all three would re-enter legacy monolith paths.
  - *Source:* docs/MP-06-FRAMEWORK.md:73-75
- [TRIAL - INPUT CHAIN] TrialKit.wireInput enforces 12 steps before the trial's handler sees a packet: table -> trialId -> declared action -> a live round owns this player -> R.acceptInput -> room.phase=='Playing' -> room.sessionId==R.sessionId -> roundToken match -> ps exists and not done -> monotonic seq (with an explicit NaN guard) -> per-player per-action rate gate -> pcall'd handler. An array-form `actions` is normalised with a warn because it would otherwise fail silently and totally.
  - *Source:* TrialKit.luau:342-416 (NaN guard at 396, array normalisation at 361-367)
- [CLIENT ROUTER] The router consumes every {kind='trial'} packet and returns true (so it can never reach the fallthrough); 'begin' loads/inits the module and adopts the token, 'end' tears down, 'deadline' stores endsAt. Generic kinds count/go/announce/hide/gorefx/role are OBSERVED (a table.clone copy is forwarded) and return false so the legacy handlers still run.
  - *Source:* TrialClientKit.luau:59 (OBSERVED), 671-715
- [CLIENT ROUTER] The single funnel insertion in the monolith is one line: `if trialRouter and trialRouter.handle(p) then return end`, plus a KenopsiaActiveTrial attribute backstop that ends a module whose id no longer matches the attribute, plus a lobby-kind belt (selection/info/score end the active module).
  - *Source:* KenopsiaClient.client.luau:1983, 1969-1974, 2200-2203
- [PACKETS] The client handles 20 kinds. Order in the funnel: trial (router) -> huntersetup -> mines -> role -> gorefx -> cpstate -> cpobs -> cpmiss -> cpdone -> cpout -> cpend -> count -> hitmark -> go -> then the fallthrough block (session+=1) which handles selection/info/status/round/score/announce/hide.
  - *Source:* KenopsiaClient.client.luau:1979-2220
- [PACKETS] 'count' does four things: gates sniper aim on / fire off, cancels the hunter setup panel, plays sfx('Count'..n), and on n==3 only hides all screens and fades the Fader from opaque over 1.4 s (Quad In) with a 1.45 s cleanup delay; CountText is punched in at TextSize 160 and tweened to 120 over 0.3 s Quart Out.
  - *Source:* KenopsiaClient.client.luau:2107-2131
- [PACKETS] 'go' unlocks sniper fire, plays sfx('AccessGranted'), shows 'GO!' at TextSize 150 tweened to 118 over 0.35 s Quart Out and hides it 0.7 s later, kills the fader, and for a pending runner switches moveState to 'runner' and flashes the [ YOU ] label (visible 0.85 s, fade 0.45 s).
  - *Source:* KenopsiaClient.client.luau:2156-2193
- [PACKETS] 'role' is the only channel that delivers a roundToken to the legacy client, and F-1 was fixed by adopting p.roundToken BEFORE the spectate early-return (line 1997). role='none' additionally hides CountText because hideAll() does not touch it.
  - *Source:* KenopsiaClient.client.luau:1992-2053 (token at 1997, CountText at 2022-2023); docs/place/07-FINDINGS.md:151-166
- [PACKETS] The fallthrough block bumps `session += 1`, which is the generation token every typewriter and odometer roll checks - so ANY unrecognised kind reaching line 2194 silently kills a running typewriter mid-word.
  - *Source:* KenopsiaClient.client.luau:2194-2219, 413-421 (typewrite guard at 417)
- [PACKETS] An empty announce text renders a full-screen black card - that is how trials cover teleports: announce{text=''} + 0.6 s.
  - *Source:* docs/place/06-CONTRACTS.md:60, 340-345; TrialKit.luau:493-495, 762-769 (END_COVER_SECONDS = 0.6 at line 54)
- [TIMING] Pacing.Timing (seconds): Reveal 3.5, Title 1.2, RoundCard 3.0, RoundSettle 1.5, CountdownFrom 3, FadeMax 0.6, InterimScore 4.5, FinalScore 8.0, ControlCard 8.0. TrialPointPool 1700.
  - *Source:* studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/Pacing.luau:111-125
- [TIMING] Only 6 of the 9 Timing fields are ever read (Reveal, ControlCard, RoundCard, RoundSettle, InterimScore, FinalScore). Title, FadeMax and CountdownFrom are read by NO source file.
  - *Source:* grep 'Timing\.' across studio-src: only MachineFlow.luau:530,541,569,599,635,682
- [TIMING] Pacing.RoundSeconds: minefield 55, birdhunt 90, canteen 45, carve 45, armory 50, upstream 40, floorcheck 35, clearance 50, carrier 45, breather 30, sweep 45, crawler 40, ricochet 45, stacker 20, sorting 40.
  - *Source:* Pacing.luau:76-95
- [TIMING] Pacing.ROUNDS by player count [2/3/4]: minefield 4/3/3, canteen 3/2/2, carve 3/3/2, armory 3/2/2, upstream 3/3/2, floorcheck 3/3/2, clearance 2/2/2, carrier 2/3/2, breather 3/3/3, sweep 3/2/2, crawler 3/2/2, ricochet 3/3/2, stacker 3/3/3, sorting 3/2/2. Bird Hunting uses LEGS = 4/3/4. Solo maps onto the 2-player row.
  - *Source:* Pacing.luau:26-58
- [TIMING] Per-trial hard-coded pre-rolls that are NOT in Pacing: BirdHunting hunter-setup task.wait(4); Minefield announce task.wait(2.8); Canteen cover 2.4 s + trailing sleep 1.6 s; TrialKit stubs use R:wait(2.8); MachineFlow lobby roulette task.wait(6.4).
  - *Source:* BirdHunting.luau:724; Minefield.luau:346; CanteenProtocol.luau:788, 886; Upstream.luau:59; MachineFlow.luau:387
- [FEEL - TYPEWRITER] Four different characters-per-second values are hard-coded: Info name 26 cps, Status lines 30 cps (plus a 0.25 s gap per line), RoundCard verbs 24 cps, Announce line 24 cps after a 0.4 s delay, Selection boot text 22 cps. kit.typewrite defaults to 24 cps.
  - *Source:* KenopsiaClient.client.luau:1713, 1734-1735, 1746, 1857, 1692; TrialClientKit.luau:374-383
- [FEEL - SHAKE] Screen shake is a trauma model: trauma decays at 0.33/s (~3 s from full), magnitude is trauma^2, driven by 3 math.noise channels at t = os.clock()*30, applied as translation *1.15 and rotation *0.2/0.2/0.26. applyGoreFx converts distance to 'near' = clamp(1-(dist-10)/30, 0, 1) and only shakes above 0.05.
  - *Source:* KenopsiaClient.client.luau:1865-1878, 1914-1925
- [FEEL - BLOOD] screenBlood spawns a full-screen burgundy wash (transparency 0.55, tween out over 0.55 s, destroyed at 0.6 s) plus floor(5 + strength*9) rounded blobs that fall 0.25-0.45 screen heights over 1.1-2.8 s with Quad In.
  - *Source:* KenopsiaClient.client.luau:1880-1912
- [FEEL - ROULETTE] Tiles appear 0.25 s apart after a 0.4 s beat; symbols flicker chaotically for 1.6 s at 0.07 s per frame (random visibility 0.55 / lit 0.4); 4 lock-in blinks of 0.14 s off / 0.2 s on; crosshair snaps in over 0.32 s Quart Out; boot text types 0.45 s later. uiSettings.ReduceFlicker collapses the flicker to a 0.6 s hold and 1 blink.
  - *Source:* KenopsiaClient.client.luau:1637-1693 (ReduceFlicker branches at 1648, 1669)
- [FEEL - ODOMETER] rollDigit spins each digit 14 + delay*10 times with an accelerating step of 0.05 + (s/spins)*0.06 s, with digit i delayed by (i-1)*0.45 s; the rank list appears 2.4 s later, one row per 0.5 s, each row's two checkmarks filling 0.25 s apart.
  - *Source:* KenopsiaClient.client.luau:1750-1764, 1796, 1803-1833
- [FEEL - SCORE TICKER] The score ticker scrolls at a constant 120 px/s (TweenInfo duration = width/120, EasingStyle.Linear) and re-loops while the screen is visible.
  - *Source:* KenopsiaClient.client.luau:1770-1781
- [FEEL - DEATH CARD] A death announce keeps the world visible at BackgroundTransparency 0.4 with blood-red text, then fades to full black over 0.5 s starting 2.5 s in, so the respawn is never seen.
  - *Source:* KenopsiaClient.client.luau:1836-1851
- [FEEL - CANTEEN WARNING] The edge glow fades IN slowly (0.3 s to transparency 0.45 on 'lowering') and snaps ON fast (0.12 s to 0 on 'watching'), fading out over 0.35 s - the asymmetry is a deliberate design note in the code.
  - *Source:* KenopsiaClient.client.luau:1215-1235 (comment at 1228-1229)
- [FEEL - SCOPE] Field of view tweens over 0.18 s Quad Out; unscoped FOV 70, scope levels x2 = 35 and x4 = 18; the bolt cycle is keyed to FIRE_COOLDOWN 2.2 s with segments at 0.12/0.34/0.58/0.82 of the cycle.
  - *Source:* KenopsiaClient.client.luau:557-559, 598-615, 1453-1471
- [FEEL - SFX] sfx() draws a random variant from a pool for Click (pool 'Clicks') and Submit (pool 'Submits'); named sounds used are Count1/2/3, AccessGranted, Confirm, Click, Submit, Warning, Reject. Per MP-02, AccessGranted is referenced but absent from the SFX folder, so GO is silent.
  - *Source:* KenopsiaClient.client.luau:236-253, 2111, 2153, 2162; docs/MP-02-CLIENT-HOOKS.md:200
- [FEEL - LIGHTING] Dead Zone swaps the whole Lighting state (Ambient, Fog 45/150, Brightness 1, ClockTime 0, ColorCorrection Saturation -0.35 / Contrast 0.08 / cold tint) and builds a local-only 2-5 x 2-7 grid of SpotLights at 26 range / 2.4 brightness, keyed purely on KenopsiaActiveTrial == 'minefield'. Sniper adds +0.75 ExposureCompensation and a 60-range spotlight parented to the camera.
  - *Source:* KenopsiaClient.client.luau:302-373 (id test at 372), 1360-1398
- [SCORING] Raw round keys use three bands with a detail below 1000: FINISHED 2000, ALIVE 1000, OUT 0. Keys are summed across a trial's rounds, then ranked, then Scoring.distribute allocates exactly 1700 via Borda weights + largest-remainder, with ties differing by at most 1 point.
  - *Source:* TrialKit.luau:46-47; Scoring.luau:36-137; CanteenProtocol.luau:68-84 (worked arithmetic)
- [STATE] Room progress is a validated patch API: setProgress validates the WHOLE patch before writing any of it, uses a newproxy CLEAR sentinel for explicit clearing, and skips the broadcast when nothing changed.
  - *Source:* RoomService.luau:465-511
- [REPO vs PLACE] studio-src is NOT a mirror of the live place. Repo KenopsiaClient is 85 124 B / 2413 lines vs 79 433 B live; MachineFlow 27 222 B repo vs 22 840 B live. TrialKit, TrialClientKit, TrialRules, the TrialClients folder, the 12 trial modules and the 12 Rules modules exist ONLY in the repo.
  - *Source:* Measured file sizes (PowerShell Get-ChildItem on studio-src) vs docs/place/02-SCRIPTS.md:10-36 and docs/place/07-FINDINGS.md:76-95, 256-272
- [TESTS] tests/ contains only rules.lua, envelope.lua, contexts.lua, trialrules.lua, animationids.lua. The 12 per-trial tests MP-06 section 0 says exist as stubs do NOT exist.
  - *Source:* ls tests/; docs/MP-06-FRAMEWORK.md:22 vs docs/place/07-FINDINGS.md:92-94

## Problems

### The good architecture is written but not shipped - the game still runs three hand-rolled monoliths

- **Evidence:** TrialKit.luau (30 825 B), TrialClientKit.luau (24 781 B), TrialRules, 12 server stubs and 12 client stubs exist in studio-src and are mapped in default.project.json:80,105-119, but docs/place/02-SCRIPTS.md:34-36 and 07-FINDINGS.md:76-95 record that the live place contains exactly ten Services modules and no TrialClients folder. MachineFlow.luau:29-40 requires all twelve, so they must be pushed together or boot fails.
- **Impact:** Every scaling fix already designed (one TrialInput with a 12-step validation chain, runtime touch pads, per-round failsafe, arena lifecycle) is inert. The shipped game is 3 trials with 3 divergent countdowns, 2 remote namespaces and 1 monolithic client.
- **Fix idea:** Do the MP-05 section F push as one recording: framework + 24 stubs + the 6 drifted shared scripts, flip one ready=true in the DEV place, verify begin/end and no _Runtime leak.

### The lobby roulette reveals a trial that the match may not play first (or at all)

- **Evidence:** preFlow calls runSelection, which does `pool[math.random(#pool)]` and writes room.trialId (MachineFlow.luau:334-335), then shows the icon roulette and the NEXT SIMULATION card. runMatch never reads room.trialId - it mints its own seed at line 460 and builds the order from Playlist.order(seed) at 409-419.
- **Impact:** The single most atmospheric moment in the lobby is decorative and can contradict what actually starts ~10 s later. With 15 trials and PerSession=5 the odds of the reveal matching the first played trial fall to about 1 in 3.
- **Fix idea:** Mint the session seed at ready-complete time, compute the order once, and let preFlow reveal order[1]; or explicitly re-brand the lobby roulette as 'boot sequence' rather than a reveal.

### The server computes VIABLE/REJECTED and the client never renders it

- **Evidence:** MachineFlow.luau:664-674 builds final entries with a `verdict` field; showScore (KenopsiaClient.client.luau:1766-1834) reads only e.score and e.displayName and ignores p.final entirely. A grep for 'verdict' in KenopsiaClient returns nothing.
- **Impact:** The session has no payoff screen. The final board is visually identical to the interim board, so 12 minutes of play end on a number that just got slightly bigger.
- **Fix idea:** Branch showScore on p.final: swap the odometer for a verdict stamp, hold with a distinct sound, and use the already-authored PHOSPHOR/DANGER split.

### MachineFlow imposes no timeout on runRound

- **Evidence:** MachineFlow.luau:584-592 pcalls trial.module.runRound and simply waits. There is no deadline, no watchdog thread and no cancellation of the trial thread; the only protection is each trial policing its own clock (BirdHunting.luau:820, Minefield.luau:707-710, CanteenProtocol.luau:811-851).
- **Impact:** One trial that never returns hangs the entire match for every player, with no abort path. Reviewable for 3 carefully-audited trials; not reviewable for 15 written by 12 parallel implementers.
- **Fix idea:** Wrap the runRound call in a deadline-aware task (Pacing.RoundSeconds[id] + a fixed grace) and abort the session on expiry - the failsafe TrialKit already implements for its own R:tick, lifted one level up.

### Seven touch buttons are hard-wired per legacy trial and share two anchor positions

- **Evidence:** docs/place/04-GUI.md:210-232 lists Btn_FIRE/SCOPE/ZOOM/PUNCH/CROUCH/SCAN/EAT with FIRE overlapping PUNCH and SCOPE/CROUCH/SCAN/EAT all at -38/-148. Visibility is spread across setSniperRig (KenopsiaClient.client.luau:717-722), setRunnerTouch (846-865) and refreshCrouchBtn (831-836), each keyed on an XBotMoves substring.
- **Impact:** Roblox is majority mobile. Every new trial would need another authored button plus another visibility rule in three different functions; at 15 trials the anchor stack is unreadable and unmaintainable.
- **Fix idea:** Make kit.pad() the only touch surface for new trials (it already exists) and freeze TouchControls as legacy-only; longer term, move the three legacy trials onto pad() too.

### Eight icons for fifteen trials, with a silent wrong-icon fallback

- **Evidence:** IconPool contains Bug, Crosshair, Cube, Factory, Magnifier, Saw, Train, Utensil (docs/MP-02-CLIENT-HOOKS.md:108-116). showSelection clones `pool:FindFirstChild(p.icons[i] or 'Crosshair')` (KenopsiaClient.client.luau:1624) - an unknown name renders Crosshair with no warning. The registry already reuses icons: Cube for minefield/carve/floorcheck, Saw for canteen/sweep/ricochet, Factory for upstream/breather/stacker.
- **Impact:** The roulette stops being a reveal when three different games show the same symbol, and a typo in a registry icon name is invisible.
- **Fix idea:** Ship ~7 more pixel-block icons (setTileLit recolours any Frame/UIStroke tree, so no code change is needed) and warn once on an unknown icon name.

### Per-trial presentation is keyed on hard-coded trial ids scattered across the client

- **Evidence:** Dead Zone lighting: `if active == 'minefield'` (KenopsiaClient.client.luau:372). Music: a Sound named exactly the trial id under Music.Trials (271-291), and per 07-FINDINGS.md:184-194 only birdhunt and minefield exist. Controls second page: `machine:GetAttribute('TrialId') == 'canteen'` (2312). Client-side trial cooldown constants CP_PLATE_COOLDOWN/CP_MOUTH_COOLDOWN are duplicated from the server (1091-1092 vs CanteenProtocol.luau:51-52).
- **Impact:** A third of the current session already runs without music. At 15 trials, either 15 tracks and 15 lighting branches are hand-written, or most trials look and sound like nothing.
- **Fix idea:** Give the kit a declarative presentation block (music id, lighting preset, scoring page) that TrialClients/<id>.luau exports the same way it already exports controlsText.

### A completed trial always distributes exactly 1700 points regardless of how long it took

- **Evidence:** Scoring.Pool = Pacing.TrialPointPool = 1700 (Scoring.luau:34, Pacing.luau:125), applied once per trial at MachineFlow.luau:613. Pacing.RoundSeconds ranges from stacker 20 s to birdhunt 90 s x 4 legs.
- **Impact:** A 20-second single-mechanic trial is worth exactly as much as a 6-minute Bird Hunting block. With 5 random trials per session, two players can receive very different total effort for the same maximum score, which reads as unfair rather than as variety.
- **Fix idea:** Either normalise the pool by trial duration/round count, or - better for a party game - keep the flat pool and shorten the long trials so the flatness is honest.

### Dead code and dead configuration are accumulating in the contract surface

- **Evidence:** Never read by any source file: Pacing.Timing.Title / FadeMax / CountdownFrom (grep 'Timing.' hits only 6 fields), GameConfig.Playlist.PlacementPoints, GameConfig.Match.FinalBoardHold, MachineFlow registry fields `subtitle` and `showInterRoundScore` (all 15 entries), Playlist.isKnown, the entire Envelope module (no require anywhere), the hitmark handler (KenopsiaClient.client.luau:2132, comment at 2141 admits it), and the Briefing screen.
- **Impact:** Contract documents describe behaviour that does not exist. The next implementer reads MP-06/06-CONTRACTS, wires against Envelope or sets `subtitle`, and gets nothing - the same failure class as the 'kind=select rendered nothing' and 'TRIAL_TEXT keyed on the wrong name' bugs already recorded in the comments.
- **Fix idea:** Delete or wire each. Envelope in particular is either the input contract (then TrialKit.wireInput should call validate) or it should go.

### MP-06 documents twelve per-trial test files that do not exist

- **Evidence:** docs/MP-06-FRAMEWORK.md:22 states 'All four already exist as compliant stubs; overwrite them'. tests/ contains only rules.lua, envelope.lua, contexts.lua, trialrules.lua, animationids.lua. Confirmed independently at docs/place/07-FINDINGS.md:92-94.
- **Impact:** The gate the critic is supposed to run per trial (`lua tests/<id>.lua` green) has no file to run, so the offline-proof discipline that makes the pure Rules modules valuable silently lapses for all 12 new trials.
- **Fix idea:** Generate the 12 test stubs (they are ~40 lines each around the tests/rules.lua loadModule shim) before any implementer starts.

### Any unrecognised packet kind silently cancels every running screen animation

- **Evidence:** KenopsiaClient.client.luau:2194-2195 does `session += 1` in the fallthrough for any kind that reached it; typewrite (413-421), rollDigit (1750-1764), showSelection (1637-1693) and showScore (1803-1833) all bail the moment session != token.
- **Impact:** Adding a new generic packet kind - a HUD hint, a music cue, a spectator update - without also adding a branch above line 2194 will make cards vanish mid-word. This exact failure already happened once with kind='select'.
- **Fix idea:** Move the session bump inside the six known-kind branches instead of the fallthrough, and warn once on an unhandled kind.

### KenopsiaClient is a 2413-line, 85 KB single file holding all three legacy trials, all cameras, all input and all screens

- **Evidence:** Measured: 85 124 B / 2413 lines. Sections: platform/layout 46-197, audio 230-293, DZ lighting 295-375, movement 386-449, cameras 451-541, sniper 543-807, runner/crouch 809-880, sonar 882-1068, canteen 1070-1353, sniper light/aim 1355-1481, lobby/ready 1483-1601, machine screens 1603-1859, gore 1861-1925, router build 1927-1975, dispatch 1977-2220, warning/settings 2222-2296, controls pager 2298-2346, lobby errors 2348-2411.
- **Impact:** Three separate RenderStepped writers with an order dependency documented only in a comment (1863-1864), three overlapping InputBegan handlers distinguished only by sniperActive/canteenActive/scanHeld flags, and every legacy trial change risking the lobby.
- **Fix idea:** Once the router ships, port the three legacy trials onto TrialClients/<id>.luau one at a time; each port deletes 200-400 lines from the monolith and removes one flag from the input handlers.

## Opportunities

### Ship the framework push (MP-05 section F) as the single next action, then port ONE legacy trial (canteen is the smallest: 1070-1353 in the client) onto TrialClients as the proof.

- **Why:** Unblocks 12 designed trials at once. A party game lives on variety; going from 3 to 8+ trials is the single largest fun multiplier available, and everything needed already exists in the repo.
- **Cost:** One Studio recording session for the push; ~1 day for the canteen port.
- **Source:** docs/MP-05-BUILD-PLAN.md section F referenced at docs/place/07-FINDINGS.md:88-90; TrialClientKit.luau:611-724 (router already handles this)

### Give the final board a real payoff: render the verdict field, hold on a stamp, add a distinct sound, and show the session's best moment per player.

- **Why:** Party games are remembered by their last 10 seconds. Right now the session ends on an identical-looking board with a bigger number, and the server already computes VIABLE/REJECTED.
- **Cost:** ~50 lines in showScore plus one sound.
- **Source:** MachineFlow.luau:669-674 (verdict computed); KenopsiaClient.client.luau:1766-1834 (never read)

### Extract the 'feel' constants (typewriter cps, tween easings/durations, shake decay, blood counts) into one FeelConfig module the way Pacing centralises timings.

- **Why:** There are already five different typewriter speeds and a dozen ad-hoc TweenInfos; one file makes the game's rhythm tunable in a single pass instead of a hunt across 2400 lines, and it is the same discipline that made Pacing provable offline.
- **Cost:** Half a day; mechanical.
- **Source:** KenopsiaClient.client.luau:1692,1713,1734,1746,1857 (cps) and 600,1223,1230,1233,1683,1775,1845,1888,1905,2077,2117,2128,2150,2169,2185,2402 (tweens)

### Make the lobby roulette honest by minting the session seed at countdown start and revealing order[1].

- **Why:** Turns a decorative animation into an actual reveal, which is what the whole 6.4 s roulette is built to feel like.
- **Cost:** ~20 lines across RoomService.beginCountdown and MachineFlow.preFlow/runMatch.
- **Source:** MachineFlow.luau:328-397 vs 458-466

### Add ~7 pixel-block icons to Selection.IconPool and warn on unknown names.

- **Why:** Restores distinct identity per trial in the one moment every player watches, and removes a silent-failure class.
- **Cost:** A Studio edit or a small builder script; setTileLit already handles any Frame/UIStroke tree.
- **Source:** docs/MP-02-CLIENT-HOOKS.md:108-116; KenopsiaClient.client.luau:1605-1613, 1624

### Use the ev='deadline' packet the kit already sends to put a visible countdown on every new trial's HUD via kit.timer().

- **Why:** Time pressure is the cheapest tension available and it is already wired end-to-end (one packet, no per-second traffic); today no legacy trial shows a clock at all.
- **Cost:** One line per trial client module.
- **Source:** TrialKit.luau:648-657; TrialClientKit.luau:309-339

### Declare presentation (music id, lighting preset, controls page) in TrialClients/<id>.luau alongside controlsText, and have the client read it instead of branching on hard-coded ids.

- **Why:** Makes a new trial ship with its own atmosphere for free instead of inheriting silence; the controlsText precedent proves the pattern works (MachineLayout already pcall-requires the module).
- **Cost:** ~80 lines in the client plus a field per trial.
- **Source:** MachineLayout.client.luau:186-226 (existing precedent); KenopsiaClient.client.luau:271-291, 372, 2312 (the hard-coded branches)

### Move the 3-2-1 countdown, the cover card and the end-of-round beat out of the three legacy trials and into one shared implementation (TrialKit already has it as Round:countdown).

- **Why:** Four implementations of the same beat means four different feels for the same moment; one implementation makes 'the machine' read as one voice, which is the game's entire identity.
- **Cost:** Small once the framework is in; the legacy trials just call the kit.
- **Source:** TrialKit.luau:518-541 vs BirdHunting.luau:730-741, Minefield.luau:413-420, CanteenProtocol.luau:790-796

## Open questions

- Is the intended shipping target 15 trials at PerSession=5 (~12 min sessions), or a smaller curated set? The framework, Pacing rows and GameConfig all assume 15, but only 3 are playable and 12 are 75-line stubs with no gameplay design implemented in code.
- Should the three legacy trials be ported onto TrialKit/TrialClientKit, or frozen as legacy forever? MP-06 explicitly keeps them on the bare packet path (D3), but that means the client keeps its three overlapping input handlers and the two remote namespaces (SniperFire/SniperAim vs TrialInput) indefinitely.
- Is Envelope.luau meant to become the real input contract? It is fully specified and documented in 06-CONTRACTS.md section 8 but has zero requires; TrialKit.wireInput reimplements an equivalent chain inline instead of calling Envelope.validate.
- Is the flat 1700-point pool per trial deliberate design (all trials equal) or an artifact? It makes a 20 s stacker round worth as much as four 90 s Bird Hunting legs.
- Who owns the Briefing screen? MachineFlow's Briefing stage renders on the Status screen; the authored Briefing screen (title, 5-line BriefList, pager, 5-segment gauge) has no code path at all.
- What is the plan for spectators? Every trial iterates room.members only, and RoomService deliberately parks late joiners in room.spectators (F-09), so a mid-match joiner sees an empty world for up to 15 minutes.
- Have the animation permissions been granted for the group place? Per AnimationIds.luau:45-59 and F-05, on a published server every rig is frozen and the Studio KeyframeSequence fallback does not apply - no code change can fix it.
- Is the repo/place drift (F-15) expected to persist, or should studio-src become authoritative after the framework push? Right now 'what runs live' cannot be answered by reading studio-src, which affects every measurement in this report that is sourced to repo files.
