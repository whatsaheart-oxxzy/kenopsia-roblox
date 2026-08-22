# Game design as documented — Kenopsia_Roblox Project (PLAN.md, docs/MP-01…07, docs/place/, docs/legacy/, docs/baseline/)

> Read-only research lens, measured 2026-08-22 (workflow wf_a13d7aec-54c). Facts cite their source; treat plan documents as claims, measurements as truth.

## Summary

The design corpus is unusually strong on paper and unusually thin on the things that make a Roblox party game retain: 12 fully specced trial design cards (MP-04, 909 lines) sit on top of 3 shipped trials, with one framework (TrialKit, 30.1 KB) written, reviewed (MP-07) and never pushed to the live place.
Measured session today: 3 trials, ALL played every session, ≈704 s ≈ 11:45 min at 4 players, of which BIRD HUNTING alone is 394 s = 56 % (docs/place/01:215-222). PLAN.md §1 says "~13 min" — the only number in PLAN that the place doc contradicts.
Form analysis is the sharpest design insight in the repo: 8 of 12 designed trials have death, and 5 (floorcheck, clearance, ricochet, sweep, crawler) share one FORM — no FINISH state, ALIVE band, top-down camera, round ends at ≤1 survivor — which is exactly DEAD ZONE's form. PLAN §2 E2 names the real risk as session monotony, not catalogue redundancy, and proposes a Playlist rule against >2 consecutive survival trials; that rule is still an open question (PLAN §6.2).
Only 4 of 15 trials bring a genuinely new verb (sorting=judge, upstream=rhythm/typing, stacker=vehicle physics, carrier=social deduction). carrier is the only social-deduction game in the whole roster and the only one that makes the game social at all.
Scoring is a single global system: raw ordering key per round → summed across rounds → Borda → exactly 1700 points per trial. No per-round score card exists (`showInterRoundScore` is dead, MP-01:124-131), so "who is winning right now" is invisible for up to 6 minutes.
Persona is fully specified and consistent: uppercase, industrial, no jokes, no exclamation marks; subtitles end with `_`; death lines 2–3 words past tense; a five-value phosphor palette (#78FFAA/#8CE8AE/#2E6B4A) with Enum.Font.Code as the only font in 521 GUI descendants. Meanwhile Roblox's default chat runs next to it (F-21).
Persistence, badges, modes, private servers, friends, rematch, streaks, emotes, onboarding and spectating are either absent (0 code hits) or explicitly deferred to milestone M6. Nothing in any doc covers a rematch loop, a tutorial/first-session, or a party/friend flow — the room code fields exist in GameConfig but no codes are ever issued.
At least eight direct doc-vs-doc contradictions exist, most resolved-by-fiat in MP-05 §0 but not corrected at the source (MP-04 still ships Y=400 arenas, per-trial packet kinds, and non-existent SFX names).

## Facts

- TRIAL 1/15 (LIVE) birdhunt "BIRD HUNTING" — verb: hunt/escape (one sniper per leg vs runners). Form: survival + FINISHED-escape band. Legs 4/3/4 (2p/3p/4p) × 90 s. Controls: desktop Move + Crouch [Ctrl]; Hunter Aim+Shoot, Scope [x2]; mobile CROUCH button, drag-aim + FIRE button; console RS aim + RT shoot, LT scope, Y zoom. Monotony risk: NONE for form (only ranged trial) but it is 394 s = 56 % of the session at 4 players.
  - *Source:* studio-src/.../MachineFlow.luau:58-67; docs/place/02-SCRIPTS.md:508-530; docs/place/01-PLACE-OVERVIEW.md:217-222
- TRIAL 2/15 (LIVE) minefield "DEAD ZONE" — verb: cross a hidden minefield, buy knowledge with a sonar pulse. Form: survival. ROUNDS 4/3/3, 55 s. Controls: Move + Use sonar [HOLD] (F / gamepad Y / mobile SCAN button); camStyle "top", forward-only movement, WalkSpeed 7 while scanning else 14, JumpPower 0. Monotony risk: this IS the form 5 designed trials duplicate.
  - *Source:* docs/place/02-SCRIPTS.md:217-247; docs/MP-02-CLIENT-HOOKS.md:52-56; docs/place/06-CONTRACTS.md:177-186
- TRIAL 3/15 (LIVE) canteen "CANTEEN PROTOCOL" — verb: eat 16 rations unseen; fork holds 4; PLATE always safe, MOUTH detectable; server-side Observer cycle hidden 2.0–4.0 s → lowering 0.35 s → watching 0.9–1.8 s → raising 0.30 s. Form: finish (empty plate) + elimination. ROUNDS 3/2/2, 45 s. Controls: seated, no movement; LMB plate / RMB mouth; mobile PLATE/MOUTH buttons; console RT swallow. Monotony risk: low (only stillness game); caps at exactly 4 seats.
  - *Source:* docs/place/02-SCRIPTS.md:249-300; PLAN.md:100-102; docs/place/02-SCRIPTS.md:508-534
- TRIAL 4/15 (DESIGNED) carve "CUT TO SPEC" — verb: carve a 3×3×3 block to a memorised template. Form: finish (race) with death on 2nd wrong cut. ROUNDS 3/3/2, 45 s (5 s template + 40 s carve). Controls: mouse highlight + LMB cut, R rotate view, Tab peek (3 s penalty, max 2); camera fixed 3/4 over own bench. Fun: memory + commitment under a guillotine. Risk: mouse-raycast precision on touch is unaddressed beyond "one pad button per action".
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:118-181; docs/MP-05-BUILD-PLAN.md:68
- TRIAL 5/15 (DESIGNED) armory "ARMS ISSUE" — verb: scavenge 4 pistol parts, assemble, fire. Form: pure race, NO death ("the roster's one pure race; the Machine's cruelty here is theft"). ROUNDS 3/2/2, 50 s. Controls: WASD, E pick/assemble, LMB fire, mouse aim, camStyle top. Fun: theft-by-body-contact turns a scavenger hunt into a brawl (carry slowdown 16→10 studs/s at 4 parts). Risk: low monotony, high implementation surface (theft, conveyor, immunity).
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:184-243
- TRIAL 6/15 (DESIGNED) upstream "UPSTREAM" — verb: type arrow sequences to climb a down-escalator. Form: finish (top landing) + death at the shredder. ROUNDS 3/3/2, 40 s. Controls: arrow keys / WASD only, no mouse; camStyle side, all four lanes visible. Fun: the roster's only rhythm/typing game, spectator-legible. Risk: keyboard-only verb on a majority-mobile platform (F-12).
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:246-298; docs/place/07-FINDINGS.md:213-228
- TRIAL 7/15 (DESIGNED) floorcheck "FLOOR CHECK" — verb: stand on the announced plate before the drop. Form: survival, NO finish state. ROUNDS 3/3/2, 35 s. Controls: WASD only, camStyle top; no input packets at all (skips wireInput entirely). Fun: public information + bluff (one fake call per round, flipped 0.6 s later). Risk: HIGHEST monotony — same ALIVE-band/top-down/last-man-standing shape as DEAD ZONE.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:301-353; docs/MP-05-BUILD-PLAN.md:171-172; PLAN.md:133-137
- TRIAL 8/15 (DESIGNED) clearance "CLEARANCE" — verb: read a private number, find the matching alcove, dodge the train. Form: survival, no finish. ROUNDS 2/2/2, 50 s. Controls: WASD + E open shutter (≤4 studs), camStyle top radius 26. Fun: private-information routing under a 3.5 s telegraph; the alcove you used never repeats. Risk: same survival form; long-narrow arena (30×160) fights a top-down camera — MP-04 itself files this as a kit note.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:356-414; docs/MP-05-BUILD-PLAN.md:72
- TRIAL 9/15 (DESIGNED) carrier "CARRIER" — verb: infect / deduce. Form: no death, no finish for most; Clean-survivor band 2000. ROUNDS 2/3/2, 45 s. Controls: WASD, E search (hold 0.8 s), LMB stab (Carrier), Q check (Clean, 8 s cooldown), Shift crouch; camStyle top radius 22. Fun: the ONLY social-deduction game in 15 trials; PLAN calls it the thing that "makes the game social". Risk: designed for 2–4 players where "everyone is always in view"; MP-04 admits it would be better with more players.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:418-481; PLAN.md:187, PLAN.md:110-112
- TRIAL 10/15 (DESIGNED) breather "BREATHER" — verb: smoke a cigarette without coughing or being caught. Form: finish (burn 100 %), non-lethal elimination (CONFISCATED.). ROUNDS 3/3/3, 30 s — the roster's only trial with 3 rounds at every player count. Controls: LMB hold = inhale edge packets, Space = cosmetic ash tap; characters anchored, no movement; camera fixed frontal rail. Fun: deliberately the calm round — "the roulette should feel uneven, like the reference". Risk: near-zero verb depth; one input.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:486-538; docs/MP-05-BUILD-PLAN.md:74
- TRIAL 11/15 (DESIGNED) sweep "CLEAR THE DECK" — verb: kick debris off your platform before the press arms. Form: survival, no finish. ROUNDS 3/2/2, 45 s. Controls: WASD + E kick (≤3 studs), camStyle top. Fun: griefing — kicking toward a shared edge passes the debris to a neighbour, which "makes 2-player rounds a duel". Risk: survival form again; player is AABB-clamped to their own 12×12 platform, so movement is nearly meaningless.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:542-595
- TRIAL 12/15 (DESIGNED) crawler "CRAWLER" — verb: dodge a leaping machine, or fling it at a rival. Form: survival, no finish. ROUNDS 3/2/2, 40 s. Controls: WASD, Space mash = struggle (8 edges in 2 s), E throwoff, mouse+LMB fling; camStyle top. Fun: hot-potato — you can save a rival to aim the crawler at someone else. Risk: survival form; the most complex server AI in the roster (leap arc, pin, retarget, second crawler in round 3).
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:599-652
- TRIAL 13/15 (DESIGNED) ricochet "RICOCHET" — verb: read blade angles and dash. Form: survival, no finish, ends early at ≤1 alive. ROUNDS 3/3/2, 45 s. Controls: WASD + Shift dash (0.35 s, 3 s cooldown, 14-stud server impulse — "the ONE movement modifier the server grants"); camStyle top, fixed whole-arena. Fun: bullet-hell, fully deterministic so it is fair at any ping. Risk: survival form; least new information per round of the five.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:656-710
- TRIAL 14/15 (DESIGNED) stacker "PALLET DUTY" — verb: drive a forklift and stack crates. Form: single band, no death, no elimination (`1000 + stackHeight*100 …`, a 0-stack still scores 1000). ROUNDS 3/3/3, 20 s — the shortest round in the game. Controls: WASD drive at 10 Hz, E forks, Q mast level; camera top following the rig Part, character parented into the seat. Fun: physics-flavoured slapstick + 12 crates shared by 4 players = contention. Risk: the only trial where losing costs nothing (everyone lands in one band).
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:714-768; docs/MP-05-BUILD-PLAN.md:78
- TRIAL 15/15 (DESIGNED) sorting "SORTING FLOOR" — verb: judge items against a rule that rotates every 8–12 s without warning. Form: survival (3 strikes = trapdoor death), no finish. ROUNDS 3/2/2, 40 s. Controls: Q chute A, E chute B, Space explicit pass; no movement; camera fixed over the four stations. Fun: judgement under time pressure, item window 1.6 s → 1.0 s by round 3. Risk: static station game; PLAN ranks it #1 to build for exactly this new verb.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:772-831; PLAN.md:184
- SESSION STRUCTURE (measured, live place 110672791536316): Roulette/Selecting 3.5 s → Briefing/ControlCard 8.0 s → Trial (n rounds: RoundCard 3.0 s → runRound → RoundSettle 1.5 s) → Score board 4.5 s, repeated per trial, then FinalScore 8.0 s with verdict VIABLE/REJECTED.
  - *Source:* docs/place/01-PLACE-OVERVIEW.md:178-203; docs/MP-01-SERVER-CONTRACT.md:62-107
- SESSION PACING (measured): fixed overhead 3.5+8.0+4.5 = 16.0 s per trial, plus 3.0+1.5 = 4.5 s per round. At 4 players: birdhunt 394 s, minefield 195 s, canteen 115 s → total ≈704 s ≈ 11:45 min; birdhunt = 56 % of the session.
  - *Source:* docs/place/01-PLACE-OVERVIEW.md:210-222
- PLAN.md §1 states the session is "~13 min" with birdhunt "~6 min"; the place measurement says 11:45 min and 394 s (6:34). The 13-min figure is the only PLAN number the measured doc does not support.
  - *Source:* PLAN.md:56 vs docs/place/01-PLACE-OVERVIEW.md:220
- SESSION PACING (designed): PerSession = 5 (D7). Computing the documented rows at 4 players (16 + rounds×(RoundSeconds+4.5)) gives per-trial durations of 89.5 s (stacker) to 125 s (armory, clearance) → a 5-trial session of 448–597 s ≈ 7.5–10 min, unless birdhunt (394 s) is drawn, which alone pushes a 5-trial session toward 15 min.
  - *Source:* derived from docs/MP-05-BUILD-PLAN.md:68-79 + docs/place/01-PLACE-OVERVIEW.md:212-219
- Variety math: 15 trials at 5 per session = 3 003 combinations vs today's 6 orderings of 3 trials — "gleicher Loop, gleiche UI, anderes Spiel".
  - *Source:* PLAN.md:233-235
- Scoring: runRound returns a raw ORDERING KEY per participant; keys are summed across a trial's rounds, ranked descending, then Scoring.distribute pays exactly Pacing.TrialPointPool = 1700 per trial by Borda with tie-averaging. Magnitude is irrelevant. Bands: FINISHED 2000+ > ALIVE 1000+ > OUT 0+, per-band detail clamped < 1000.
  - *Source:* docs/MP-01-SERVER-CONTRACT.md:109-123; docs/MP-05-BUILD-PLAN.md:117-118
- There is NO per-round score card. Rounds are separated only by RoundSettle 1.5 s; the board appears once per TRIAL and once at the end. `showInterRoundScore` is dead code.
  - *Source:* docs/MP-01-SERVER-CONTRACT.md:124-131
- Every trial is worth the same 1700 points today; PLAN P1 proposes a doubled final trial announced as FINAL AUDIT because "wer nach Trial 2 führt, gewinnt meist".
  - *Source:* PLAN.md:216-219
- MACHINE VOICE: uppercase, industrial, no jokes, no exclamation marks. Subtitle = an order ending in `_` (CRT cursor). Tagline = a four-to-six word verb line. Death lines are two or three words in the past tense (PROCESSED., OFF SPEC., WRONG PLATE., STRUCK., PRESSED., SPINE FAILED., SPLIT., MISFILED., FED TO THE BELT.); non-lethal outs are CONFISCATED.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:42-45; docs/MP-05-BUILD-PLAN.md:96-98
- MACHINE COLOURS (measured from the live GUI, 521 descendants): Phosphor bright #78FFAA (headings, digits, active elements, icons, frames), Phosphor muted #8CE8AE (body text, status lines, names), Phosphor dark #2E6B4A (grunge tint, second-order frames, greyed rows), base near-black #020402/#020602, deep base #041005, danger red #FF1818 (only Btn_FIRE and Btn_PUNCH), bone white #EBF5EE (only the hip crosshair).
  - *Source:* docs/place/04-GUI.md:16-31
- MACHINE TYPOGRAPHY: `Enum.Font.Code` throughout — "es gibt keine zweite Schriftart im gesamten GUI" (Inconsolata; MP-02 says keep it). Grunge overlay is always rbxassetid://89538183732053, ScaleType Tile, Transparency 0.55, tinted #2E6B4A, as four strips (70 px top/bottom, 90 px left/right).
  - *Source:* docs/place/04-GUI.md:30-35; docs/MP-02-CLIENT-HOOKS.md:221
- Kit UI palette (client): PHOSPHOR 78FFAA, IDLE 8CE8AE, DIM 2E6B4A, AMBER FFBA3C, DANGER (255,58,44), WARN (255,176,40), SAFE (120,208,128), PANEL (9,12,10), INK (2,6,4), BLOOD (120,8,6).
  - *Source:* docs/MP-02-CLIENT-HOOKS.md:201; docs/MP-05-BUILD-PLAN.md:260
- World PS1 palette (11 colours, ≤5 per arena): Void(12,12,14), Concrete(96,96,92), WetConcrete(68,70,66), Steel(140,146,150), Rust(122,58,34), Hazard(196,160,32), Signal(200,32,32), Blood(120,16,16), Grime(58,72,52), Bone(204,196,176), Sodium(232,176,88). Neon is reserved for telegraphs: Signal = lethal now, Hazard = lethal soon.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:90-96; docs/MP-05-BUILD-PLAN.md:112-116
- REQ-IP-01: the reference game's minigame names may appear ONLY in docs/ — never in studio-src/, tests/, default.project.json, Studio instance names or any comment. Banned tokens: Chisel Gauntlet, Firearm Factory, Wrong Way, Stable Footing, Tunnel Hazard, Inside Job, Smoke Break, Debris Platforms, Spine Breaker, Lethal Rebound, Forklift Certified, The Filter, Machine Party (and camel/snake spellings). tests/rules.lua greps Playlist.Ids and the registry for them; the IP grep is the FIRST gate of the critic checklist.
  - *Source:* docs/MP-05-BUILD-PLAN.md:8-14; docs/MP-04-TRIAL-DESIGNS.md:6-11; PLAN.md:283-289
- Death sequence is fixed (D12): BloodFX.kill(pos); hum.Health = 0; announce {kind="gorefx", pos, power}; tellOne {kind="announce", style="death", text}; after 3.2 s a spectate role packet. Every kill telegraphed ≥ 0.7 s in advance (light/sound/motion), never instant on a hidden timer.
  - *Source:* docs/MP-05-BUILD-PLAN.md:37; docs/MP-04-TRIAL-DESIGNS.md:54-57
- Packet kinds handled today: selection, info, status, round, score, hide (MachineFlow); announce, count, go, role, gorefx (trials); plus legacy per-trial kinds mines, huntersetup, hitmark, cpstate/cpobs/cpmiss/cpout/cpdone/cpend. Unknown kinds render NOTHING. New trials use one envelope: {kind="trial", trialId, ev=…} with reserved ev="begin"/"end".
  - *Source:* docs/MP-01-SERVER-CONTRACT.md:212-219; docs/place/06-CONTRACTS.md:71-78; docs/MP-05-BUILD-PLAN.md:26
- Roles: role="runner"|"sniper"|"spectate"|"none". Any role value a new trial invents is treated as frozen + camera restored, and "runner" drags in forced yaw + forward-only movement, so new trials must NOT send role for their own participants; they may reuse role="spectate" for the dead.
  - *Source:* docs/MP-02-CLIENT-HOOKS.md:72-83; docs/MP-05-BUILD-PLAN.md:26
- Player count is FIXED at 2–4 (decided 21.08.2026): GameConfig.Players.MaximumPerServer = 4, MinimumForMatch = 2, StudioTestMinimum = 1, Room.MaxPlayers = 4, MinPlayers = 2, RequireAllReady = true; one room per server. Kenopsia_DEV is separately at 28.
  - *Source:* PLAN.md:90-95; docs/place/06-CONTRACTS.md:143-156
- PERSISTENCE: none. A marker scan over every LuaSourceContainer in the datamodel returned 0 hits for DataStore, MarketplaceService, GamePass, Badge, ProfileStore, Leaderstats. Session score/wins live only in the player attributes KenopsiaSessionScore / KenopsiaSessionWins, which MachineFlow zeroes once per match.
  - *Source:* PLAN.md:60, PLAN.md:325-327; docs/MP-01-SERVER-CONTRACT.md:68
- BADGES: mentioned exactly once, as milestone M6 work after persistence — "gespielte Sessions, Siege, bestes Ergebnis pro Trial → Profilfeld in der Lobby. Danach Badges (erste Session, zehnter Sieg, alle Trials gespielt). Erst danach Kosmetik und Monetarisierung". No badge ids, no design, no doc.
  - *Source:* PLAN.md:239-241, PLAN.md:264
- MODES: there is exactly one mode. Playlist.order(seed) shuffles all enabled ids; playableOrder keeps the first PerSession of them. No ranked/casual/custom/solo variant appears anywhere in the docs. GameConfig.Playlist.PlacementPoints = {3,2,1,0} exists but is explicitly NOT used.
  - *Source:* docs/place/06-CONTRACTS.md:158-161, 221-238; docs/MP-01-SERVER-CONTRACT.md:121-122
- SPECTATORS: two different things are called spectating. (a) In-trial spectate = a role packet for dead participants with a fixed camera and a `watch` list to cycle. (b) Late joiners land in room.spectators and receive NOTHING — every sender iterates room.members — so a player who joins mid-match "sieht bis zur nächsten Session eine leere Welt". The documented fix is a real spectator mode OR blocking mid-match joins.
  - *Source:* docs/MP-01-SERVER-CONTRACT.md:189-203; docs/place/07-FINDINGS.md:170-181 (F-09); PLAN.md:245-247
- SOCIAL: the only social system designed anywhere is the carrier trial's hidden-role mechanic. No friend list, no party, no invite, no cross-session identity. GameConfig.Room carries CodeAlphabet ("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") and CodeLength = 6, annotated "nur für den Join-Shim … es werden keine Codes ausgegeben" — a half-built private-room hook that issues no codes.
  - *Source:* docs/place/06-CONTRACTS.md:147-156; docs/MP-04-TRIAL-DESIGNS.md:418-481
- Roblox's default chat is fully on next to the Machine persona: TextChatService.CreateDefaultCommands = true, CreateDefaultTextChannels = true, all four config objects unchanged — "eine Designentscheidung, die noch niemand getroffen hat".
  - *Source:* docs/place/07-FINDINGS.md:356-365 (F-21)
- Touch controls are hard-wired per legacy trial: KenopsiaMachine.TouchControls has seven fixed buttons (Btn_FIRE, SCOPE, ZOOM, PUNCH, CROUCH, SCAN, EAT) with FIRE/PUNCH stacked. The doc's own note: "Roblox ist mehrheitlich mobil — die Steuerung jedes Trials muss von Anfang an für Daumen entworfen werden". The kit's answer is kit.pad() building buttons at runtime, plus an acceptance rule of ≥1 pad button per action and a gamepad alias per key.
  - *Source:* docs/place/07-FINDINGS.md:213-227 (F-12); docs/MP-05-BUILD-PLAN.md:379
- Audio: SoundService.KenopsiaAudio.Music.Trials contains exactly two Sounds (birdhunt, minefield); canteen has none and the Ambience folder has zero children, so a third of today's session plays silent. updateTrialMusic() has NO fallback — a trial without a Sound of its name plays silence.
  - *Source:* docs/place/07-FINDINGS.md:184-196 (F-10); docs/MP-04-TRIAL-DESIGNS.md:899-903
- Named audio gaps with shipping fallbacks: train horn (clearance), cough (breather), saw whine (ricochet), servo skitter (crawler), forklift reverse beep (stacker), handgun report (armory), chisel tap (carve). Rule: "No trial may DEPEND on a missing sound."
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:896-898, :103-104
- Icons: the live Selection.IconPool holds exactly eight pixel-block Frames (Bug, Crosshair, Cube, Factory, Magnifier, Saw, Train, Utensil). Fifteen trials over eight glyphs means repeats; an unknown icon name silently renders Crosshair. Seven new glyphs (chisel, arrow, syringe, cigarette, blade, pallet, funnel) are an optional user commission, not a blocker.
  - *Source:* docs/MP-04-TRIAL-DESIGNS.md:34-40; docs/MP-05-BUILD-PLAN.md:30, :422
- Arena load: StreamingEnabled = false (deliberate — streaming broke the runner cameras). 1 793 Workspace instances for three arenas today; fifteen arenas at up to 300 static parts each adds up to 4 500 permanently loaded parts. MP-07 R-01 decided arenas build lazily on first play, not at boot; the repo stubs already carry the R-01 comment and build only inside runRoundInner.
  - *Source:* docs/place/07-FINDINGS.md:367-381 (F-22); docs/MP-07-PREPUSH-REVIEW.md:131-160; studio-src/.../Services/FloorCheck.luau:41-48
- Build state (measured on disk): 12 server stubs at ~2.9 KB each, 12 client stubs at ~1.2 KB each, TrialKit.luau 30.1 KB, GameConfig already carries PerSession = 5; MachineFlow has ready = true for exactly 3 entries and ready = false for the 12 new ones. tests/ contains only animationids, contexts, envelope, rules, trialrules — NO tests/<id>.lua exists.
  - *Source:* ls studio-src/ServerScriptService/KenopsiaServer/Services/, ls tests/, studio-src/.../MachineFlow.luau:64,74,104,118-228, studio-src/.../GameConfig.luau:51
- Legacy docs/legacy/ contents (superseded prototype, one line each): DESIGN.md — the original 2–8 player, 5-programs-per-cycle design with three minigames RECALL/THE GRATE/THE LINE and a shared IconPool "vocabulary"; ASSETS.md — the PSX asset import list, its blanket CC0 claim explicitly voided at the top; default.project.json.legacy — the old Rojo map; src/ — the dead prototype (RoundService, ArenaService, ScoreService, MinigameRegistry, minigames/Recall|Grate|Line, shared Config/Types/Net/State/IconPool, client init/HUD/RecallUI).
  - *Source:* docs/legacy/DESIGN.md:1-178; docs/legacy/ASSETS.md:1-9; ls docs/legacy/src/
- docs/baseline/ contents (one line each): GATE0-BASELINE.md — baseline + protection audit incl. the licence correction; GATE1-REPORT.md — contexts and the three-minigame session; GATE-M1-BASELINE.md — Kenopsia_DEV source/safety round-trip gate; GATE-M1-SECTION2.md — scene, character and camera; GATE-M1-SECTION3.md — UI structure and the "street-retro" palette added alongside the phosphor one; INSTANCE-MANIFEST.md + PHASE0-BASELINE.md — phase-0 instance inventory of place 110672791536316; PHASE1-REPORT.md / PHASE1-CORRECTIONS.md — the canonical server/session architecture and its corrections; five dev-instance-tree*.csv snapshots (151–166 KB each), dev-menu-button-cframes.csv, dev-script-map.json / maingame-script-map.json, selene-report.txt + selene-dev-baseline.txt (lint baselines).
  - *Source:* ls docs/baseline/; head of each file
- There is no DESIGN.md or ASSETS.md anywhere outside docs/legacy/ — a repo-wide glob for {DESIGN,ASSETS}.md returns only docs/legacy/DESIGN.md and docs/legacy/ASSETS.md. Licensing authority moved to docs/assets/ASSET-LEDGER.md, which must be "fully green before Gate 7 release".
  - *Source:* Glob **/{DESIGN,ASSETS}.md; docs/assets/ASSET-LEDGER.md:1-11
- MP-07 (pre-push review of TrialKit, read-only, 21.08.2026) found three issues, all decided before push: R-01 arenas were being built at boot in every stub → delete the ensureArena call from init(); R-02 the seq check is bypassable by omitting seq and permanently defeatable with NaN → add `if payload.seq ~= payload.seq then return end`, rate limit remains the real barrier; R-03 `actions` given as an array silently drops EVERY input packet → normalise and warn.
  - *Source:* docs/MP-07-PREPUSH-REVIEW.md:18-199
- The F-1 class of bug is the documented worst case and has happened once: CanteenProtocol sent roundToken inside a role="spectate" packet, the client returned before adopting it, so every plate/mouth packet was dropped — "das Minigame sah perfekt aus und war unspielbar". PLAN §5 makes "test client gates through the real input path" a standing rule.
  - *Source:* docs/MP-02-CLIENT-HOOKS.md:70; PLAN.md:297-301; docs/MP-05-BUILD-PLAN.md:39

## Problems

### Five of the twelve designed trials are the same game in a different costume

- **Evidence:** PLAN.md:133-137: floorcheck, clearance, ricochet, sweep, crawler share one FORM — "kein FINISH-Zustand, ALIVE-Band, Top-Down-Kamera, Runde endet bei ≤ 1 Überlebendem" — which DEAD ZONE already ships. MP-05 §A confirms it numerically: all five have no FINISHED band, camera.top, and the ALIVE 1000+ / OUT 0+ pair (docs/MP-05-BUILD-PLAN.md:71,72,75,76,77). 8 of 12 designs have death (docs/MP-04-TRIAL-DESIGNS.md:839-852).
- **Impact:** With PerSession = 5 drawn from 15, a run of three top-down survival rounds is likely and will read as one long minigame; the session's variety promise (3 003 combinations) is nominal, not felt.
- **Fix idea:** Implement the rule PLAN already proposes but leaves open (PLAN.md:139-142, :312-313): Playlist.order gets a constraint that no more than two survival-form trials are adjacent. Tag each registry entry with `form = "survival"|"finish"|"score"` (the data already exists in MP-05 §A's Death?/band columns) and reject orderings that violate it — a few lines in Playlist, cheaper than cutting content.

### BIRD HUNTING eats 56 % of the session and its length is untouched

- **Evidence:** docs/place/01-PLACE-OVERVIEW.md:217-222 — birdhunt 4 legs × 90 s = 394 s of a 704 s session; minefield 195 s; canteen 115 s. PLAN.md:213-215 proposes 60 s × 3 legs but this is P1 work, not scheduled before M4.
- **Impact:** One trial dominates every session today, and once PerSession = 5 is active a session that happens to draw birdhunt is ~40 % longer than one that does not (my computation from MP-05 §A: 89.5–125 s per new trial vs 394 s) — pacing becomes a coin flip.
- **Fix idea:** Do the two-line Pacing change (RoundSeconds.birdhunt 90→60, LEGS 4/3/4→3) before, not after, the framework push; it is the single largest pacing win in the repo and touches one shared file that the Framework stage owns anyway.

### No per-round scoreboard: 'who is winning' is invisible for up to six minutes

- **Evidence:** docs/MP-01-SERVER-CONTRACT.md:124-131 — "There is NO per-round score card. Rounds are separated only by RoundSettle (1.5 s)… `showInterRoundScore` is dead." MP-04 §13.2 nonetheless prints `showInterRoundScore=false` for all twelve new entries (docs/MP-04-TRIAL-DESIGNS.md:875-876). PLAN.md:220-221: "Der 'wer führt gerade'-Moment fehlt."
- **Impact:** The core competitive tension of a party game — the standings swinging — is only surfaced once per trial. In a 4-leg birdhunt that is 6.5 minutes of play with no feedback on position.
- **Fix idea:** Send a lightweight standings card in the 1.5 s RoundSettle window from the place where the trial board is already assembled; no new remote, no new UI screen (the Score screen already exists).

### Every trial is worth the same 1700 points, so the ending is decided early

- **Evidence:** docs/MP-01-SERVER-CONTRACT.md:113-118 and docs/place/01-PLACE-OVERVIEW.md:232 — Scoring.distribute pays exactly Pacing.TrialPointPool = 1700 per trial regardless of position in the session. PLAN.md:216-219: "wer nach Trial 2 führt, gewinnt meist, und die letzten Minuten sind entschieden, bevor sie gespielt werden."
- **Impact:** The last third of the session has no stakes for anyone but the leader — the exact opposite of what a party game needs at the moment players decide whether to stay for another round.
- **Fix idea:** PLAN's own fix: a weight factor in Scoring.distribute for the final trial, announced as FINAL AUDIT. One number, one card, large tension gain.

### Late joiners get a blank world; there is no spectator mode

- **Evidence:** docs/place/07-FINDINGS.md:170-181 (F-09) — every sender iterates room.members, room.spectators is never considered, so "wer während eines Matches beitritt, sieht bis zur nächsten Session eine leere Welt". Confirmed in the contract: docs/MP-01-SERVER-CONTRACT.md:194-198.
- **Impact:** On Roblox the join is the funnel. A player who clicks in mid-session sees nothing for up to 11 minutes and leaves; the game loses precisely the traffic it worked to earn.
- **Fix idea:** Either promote spectators to a real audience (send them the same trial packets in a camera-only role — TrialKit.audienceOf is already the seam) or gate joins during Playing with a visible 'NEXT CYCLE IN mm:ss' lobby screen so the wait is legible instead of empty.

### Nothing persists: no reason to come back, and no evidence you were ever there

- **Evidence:** PLAN.md:60 and :325-327 — a marker scan across every script found 0 hits for DataStore, Badge, GamePass, ProfileStore, leaderstats. Session score and wins are player attributes that MachineFlow zeroes at the start of every match (docs/MP-01-SERVER-CONTRACT.md:68).
- **Impact:** Win a session, leave, and the game has no memory of it. No progression, no badges, no personal bests per trial, and therefore nothing that would justify cosmetics or monetisation later (PLAN itself: "vorher gibt es nichts, das sich zu besitzen lohnt").
- **Fix idea:** The smallest useful slice is one DataStore profile: sessions played, wins, best band per trial id — the trial id list already exists in GameConfig.Playlist.TrialIds and the band keys are already normalised.

### No rematch loop is designed anywhere — the session just ends

- **Evidence:** The documented tail is: FinalScore hold 8.0 s (Pacing.Timing), Match.FinalBoardHold = 12 s, then RoomService.cleanupToWaiting → phase Waiting, sessionId nil, participants nil, spectators promoted (docs/MP-01-SERVER-CONTRACT.md:99-107; docs/place/06-CONTRACTS.md:163-166). No 'play again', no vote, no keep-the-party-together step appears in PLAN, MP-01, MP-04 or MP-05.
- **Impact:** The highest-intent moment in the whole loop (the second the verdict lands) is spent dumping everyone back into an unready waiting room where RequireAllReady = true means one person walking away blocks the restart.
- **Fix idea:** Carry readiness forward: after the final board, put the same four players into a pre-readied room with a countdown they can opt out of, rather than clearing readiness. It is a RoomService state change, not new UI.

### The Machine persona is undermined by Roblox's default chat and by silence

- **Evidence:** docs/place/07-FINDINGS.md:356-365 (F-21): TextChatService.CreateDefaultCommands = true, CreateDefaultTextChannels = true, unchanged — "bei einem Spiel, dessen ganze Identität eine Maschine mit strenger Stimme ist, läuft daneben Robloxs Standard-Chatfenster". F-10 (:184-196): canteen has no music and Ambience is empty. PLAN.md:222-226: the Machine never comments on outcomes.
- **Impact:** The single strongest asset — a consistent, unfriendly institutional voice — is diluted by an off-brand UI and by a third of the session running silent. Persona is also the cheapest differentiator against every other Roblox party game.
- **Fix idea:** Three cheap moves in one pass: restyle or replace the default chat window, reuse an existing music id for canteen (already sanctioned by MP-05 D6), and add the outcome comment pool PLAN P1 describes at the point where the score board is already sent.

### MP-04 as written would produce broken trials if followed literally

- **Evidence:** MP-04 specifies arenas at Y = 400 in a row 600 studs apart (docs/MP-04-TRIAL-DESIGNS.md:70-88), per-trial packet kinds like `carve_template`/`fc_call` (:891-894), SFX names AccessGranted/AccessDenied/StandClear/Submit (:99-104), and carrier RoundSeconds "45 (2p: 30)" (:846). MP-05 overrides all four: Y = 0 grid at X {1400,1900,2400} (D4), one `kind="trial"` envelope with `ev` (D1), substitute SFX names (D6), and a single RoundSeconds number (D8).
- **Impact:** MP-04 is the document PLAN §5 tells an implementer to read FIRST for game feel. Four of its shared decisions are silently wrong, and the corrections live in a second document 900 lines away. The class of bug this produces is the F-1 class: a trial that looks perfect and is unplayable.
- **Fix idea:** Add a five-line SUPERSEDED banner at the top of MP-04 §0 listing D1/D4/D6/D8, the same way docs/legacy/ASSETS.md already carries its voided-licence banner.

### PLAN.md contradicts its own decision E2 twenty lines later

- **Evidence:** PLAN.md:114 decides "E2 — Bauen wir alle zwölf? Ja (korrigiert 21.08.2026)" and PLAN.md:310-313 records the question as closed. But PLAN.md:231 (work package P2) still reads: "`floorcheck`, `clearance`, `ricochet` nach E2 ans Ende oder streichen."
- **Impact:** The one document that is supposed to arbitrate between the MP docs contains an unresolved instruction to possibly cut three finished designs. A future session reading only §3 will act on the retracted recommendation.
- **Fix idea:** Delete the trailing clause in P2 and replace it with the survival-adjacency rule that E2 actually concluded with.

### MP-06 §0 tells twelve implementers that files exist which do not

- **Evidence:** docs/MP-06-FRAMEWORK.md:24 — "All four already exist as compliant stubs; overwrite them." Measured: tests/ contains only animationids.lua, contexts.lua, envelope.lua, rules.lua, trialrules.lua — none of the twelve tests/<id>.lua exist. PLAN.md:74 flags exactly this ("MP-06 §0 behauptet das Gegenteil").
- **Impact:** The per-trial gate ("lua tests/<id>.lua green, ≥15 checks") is the first hard quality bar in the workflow, and the doc implies a starting point that isn't there — an implementer who trusts it discovers the gap at gate time.
- **Fix idea:** Correct the sentence to name tests/<id>.lua as new work, and copy tests/trialrules.lua's harness header into MP-06 §3 as the template.

### Keyboard-shaped verbs on a majority-mobile platform

- **Evidence:** upstream is explicitly "pure keyboard" (arrow keys, no mouse — docs/MP-04-TRIAL-DESIGNS.md:258-262); carve needs mouse raycast highlighting plus R and Tab (:135-139); crawler needs Space mashing plus mouse-aimed fling (:616-618); sorting uses Q/E/Space (:790-792). The only mobile provision is the acceptance line "at least one kit.pad() button per action" (docs/MP-05-BUILD-PLAN.md:379) and F-12's warning that touch must be designed "für Daumen … nicht für Tastatur mit Touch-Nachtrag".
- **Impact:** Four designs will need touch schemes invented during implementation, by twelve independent agents, with no shared pattern — the likeliest place for the roster to fragment in feel and fairness.
- **Fix idea:** Specify two or three canonical pad layouts in TrialClientKit (single action, dual action, four-direction) and require every card to name which one it uses, instead of leaving each implementer to build a pad.

## Opportunities

### Ship the anti-monotony playlist rule as a data field, not a judgement call: add `form = "survival" | "finish" | "score"` to each MachineFlow.TRIALS entry and have Playlist.order reject orderings with three adjacent survival trials

- **Why:** Turns the 3 003 possible line-ups from a number into a felt variety guarantee, and makes the five same-form trials a strength (they can never cluster) instead of the risk PLAN identifies
- **Cost:** Small — one field per registry entry plus a re-roll loop in Playlist.order; tests/rules.lua already does permutation searching
- **Source:** PLAN.md:139-142, :312-313; docs/MP-05-BUILD-PLAN.md:66-79

### Turn the room-code fields that already exist into a real private/party flow

- **Why:** GameConfig.Room already carries CodeAlphabet and CodeLength with the note 'es werden keine Codes ausgegeben'. A 4-player game with hidden roles (carrier) lives or dies on playing with people you know; a code is the shortest path from 'I saw a clip' to 'get in here'
- **Cost:** Medium — needs a lobby entry point and reserved-server or room-matching logic; the config surface is already sketched
- **Source:** docs/place/06-CONTRACTS.md:147-156; docs/MP-04-TRIAL-DESIGNS.md:418-481

### Make the ending shareable: podium instead of a text list, plus the Machine's verdict line

- **Why:** PLAN says it plainly — 'auf Roblox ist der Siegermoment das, was aufgenommen und geteilt wird — das ist Reichweite, die gerade liegen bleibt'. The verdict VIABLE/REJECTED is already computed and held for 8 s
- **Cost:** Medium — a new final screen against an existing packet; no server logic change
- **Source:** PLAN.md:222-223; docs/MP-01-SERVER-CONTRACT.md:99-101

### Give the Machine reactions: a comment pool per outcome, fired where the score board is already sent

- **Why:** PLAN calls this the 'größter Identitätsgewinn pro Aufwand' — pure text against a system that already exists, and the voice rules (uppercase, industrial, no jokes, no exclamation marks, 2–3 word past-tense death lines) are already written down
- **Cost:** Small — a data table plus one call site
- **Source:** PLAN.md:224-226; docs/MP-05-BUILD-PLAN.md:96-98

### Keep the party together after the verdict: carry readiness into the next session instead of clearing it

- **Why:** The rematch is the cheapest retention mechanic in party games, and today the loop actively dissolves the group (cleanupToWaiting clears participants and readiness while RequireAllReady = true)
- **Cost:** Small–medium — a RoomService state change plus an opt-out countdown
- **Source:** docs/MP-01-SERVER-CONTRACT.md:106; docs/place/06-CONTRACTS.md:149-152

### Use the Briefing card (8.0 s, already the longest single hold in the loop) as onboarding

- **Why:** Every trial already ships controlsText per device (D15) and a four-to-six word tagline; a first-time player currently gets the same 8 s card as a veteran. Highlighting the one new verb on a player's first encounter with each trial is free tutorial
- **Cost:** Small — one flag per trial id in a persisted profile, or session-local at first
- **Source:** docs/MP-05-BUILD-PLAN.md:40; docs/place/01-PLACE-OVERVIEW.md:190

### Personal bests per trial as the first persistence slice, before badges or cosmetics

- **Why:** The band scheme already produces a comparable number per trial (FINISHED 2000+ / ALIVE 1000+ / OUT 0+ with per-band detail), so 'your best on SORTING FLOOR' is one DataStore write away and gives a solo-ish goal in a game that otherwise scores you only against whoever happens to be in the server
- **Cost:** Medium — one profile store, plus the lobby profile field PLAN already scoped for M6
- **Source:** PLAN.md:239-241; docs/MP-01-SERVER-CONTRACT.md:113-118

### Exploit the roster's deliberate unevenness: schedule BREATHER and PALLET DUTY as tempo breaks

- **Why:** MP-04 designed breather as the one calm round ('die roulette should feel uneven, like the reference') and stacker as a 20 s scramble. Placing them by design rather than by shuffle gives the session a shape — tension, break, tension, FINAL AUDIT
- **Cost:** Small — a slot rule in the same place as the survival-adjacency rule
- **Source:** docs/MP-04-TRIAL-DESIGNS.md:513-516, :748

### Fix the silent third of the session immediately by reusing existing music ids

- **Why:** canteen has no track and Ambience is empty; MP-05 D6 already sanctions reusing the minefield id for arena trials and the birdhunt id for the calm ones (breather, carrier, stacker), with no client change needed
- **Cost:** Tiny — add Sound instances named Music.Trials.<id>
- **Source:** docs/place/07-FINDINGS.md:184-196; docs/MP-05-BUILD-PLAN.md:31; docs/MP-04-TRIAL-DESIGNS.md:899-903

### Design the touch pad once, centrally, as two or three canonical layouts in TrialClientKit

- **Why:** Twelve implementers inventing twelve pads is how a roster stops feeling like one game; a shared layout language also makes every new trial instantly familiar on mobile, which is where most of the audience is
- **Cost:** Medium — kit work up front, saves work twelve times over
- **Source:** docs/place/07-FINDINGS.md:213-227; docs/MP-05-BUILD-PLAN.md:379

### Decide the chat question deliberately — style it as Machine terminal output or turn the default off

- **Why:** F-21 records this as a design decision nobody has made. Either answer strengthens the persona; leaving Roblox's default window floating over a phosphor CRT weakens it for free
- **Cost:** Small
- **Source:** docs/place/07-FINDINGS.md:356-365

## Open questions

- Does Playlist.order get a rule preventing more than two consecutive survival-form trials? PLAN.md:312-313 explicitly leaves this as the only part of E2 still open.
- Is Kenopsia_DEV continued as the test place, or is testing moved into a copy of MainGame? (PLAN.md:314-315)
- Music: procure fifteen tracks, or build one base loop with per-trial intensity layers? (PLAN.md:316; docs/place/07-FINDINGS.md:194-196)
- Are the five offline test suites (rules, envelope, contexts, trialrules, animationids) currently green? PLAN.md:337-339 records this as unverified, and they are the first gate of the MP-05 §F push procedure.
- When is PerSession = 5 activated? PLAN.md §E3 says 'once more than five trials are finished'; GameConfig in the repo already has PerSession = 5; MP-05 §G item 6 asks the user to confirm 5 or name another number.
- Should mid-match joiners get a real spectator mode, or should joins during Playing be blocked outright? (docs/place/07-FINDINGS.md:179-181, F-09)
- Is Roblox's default chat kept, restyled, or disabled? Recorded as a decision nobody has made (docs/place/07-FINDINGS.md:363-365, F-21).
- Do the seven new pixel-block icons (chisel, arrow, syringe, cigarette, blade, pallet, funnel) get commissioned, or does the roulette accept icon repeats across fifteen trials? (docs/MP-05-BUILD-PLAN.md:422; docs/MP-04-TRIAL-DESIGNS.md:34-40)
- Does MachineFlow.DECOY_ICONS shrink to the one still-unused glyph (Utensil) or get dropped entirely once fifteen trials are registered? (docs/MP-04-TRIAL-DESIGNS.md:37-39; docs/MP-02-CLIENT-HOOKS.md:106)
- StarterCharacter: after the five player clips are published, is the PS1 rig enabled behind GameConfig.Character.UsePS1Rig, or does the game stay on default R15? (docs/MP-05-BUILD-PLAN.md:419, D9)
- Are the six animation ids still at 0 (Player.Eat, Boss.Death, PlayerBlink, PlayerHappy, …) going to be published, and are the existing published clips actually permitted for the universe? F-05 is still listed as blocking. (docs/place/07-FINDINGS.md:98-117, :198-212)
- Should the Contexts round token be threaded into runRound so one token format can be validated centrally, or does every trial keep minting its own? (docs/MP-01-SERVER-CONTRACT.md:742-745)
- Is Envelope ever wired, or does it stay dead code alongside the flat packet? (docs/MP-01-SERVER-CONTRACT.md:746-748; docs/place/07-FINDINGS.md:134-150, F-07)
- Which build order wins: PLAN §3 P0-B by play value (sorting → upstream → stacker → carrier) or MP-05 §F by integration risk (floorcheck → breather → sorting → … → carrier)? PLAN says the swap is deliberate but MP-05 is nominally the single source of truth. (PLAN.md:180-195 vs docs/MP-05-BUILD-PLAN.md:398)
- Nowhere covered at all, and needed by a party game: onboarding / first-session tutorial, an explicit rematch or 'play again' step, win streaks or daily goals, emotes or any expressive input outside the trials, private servers, and any friend/party/invite flow. No document in the repo mentions any of these.
