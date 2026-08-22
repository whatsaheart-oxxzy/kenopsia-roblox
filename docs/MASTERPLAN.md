# KENOPSIA — Master Plan (measured 2026-08-22)

> The one plan. Written for execution by Claude Fable 5 in ultracode mode with parallel worker agents, supervised by the user (Tamem). Evidence: `docs/research/2026-08-22-sweep/` (seven read-only lenses, every claim sourced). Supersedes the ordering in `PLAN.md` §3 where the two differ; `PLAN.md` keeps the decisions (E1 2–4 players fixed, E2 build all twelve) and the per-trial protocol (§5).
>
> **Kurzfassung (DE):** Das Spiel ist technisch weiter als die Doku sagt (Framework liegt im Place, 62/62 Skripte identisch), aber es fühlt sich noch nicht wie ein Party-Spiel an: kein Zwischenstand, kein Urteils-Moment, kein Grund wiederzukommen, UI als Pixel-Festlayout auf einem Handy-dominierten Markt, ein Drittel der Session stumm, Animationen ohne Freigabe. Dieser Plan ordnet die Arbeit in sieben Phasen — Wahrheit & Quick-Wins → Session-Rückgrat & Feel → lebendige Retro-UI auf allen Geräten → PS1-Look nur in den Minispielen → Trials → Bindung & Wachstum → Audio — plus Modi für spätere Updates. Jede Phase hat Agenten, Dateien, Tore und eine Live-Prüfung.

---

## 0. Ground truth (measured, not assumed)

| Fact | Measured value | Source |
|---|---|---|
| Place ↔ repo parity | **62/62 scripts byte-identical** (checksum `(h*31+b) % 2^31`, Luau vs Python). TrialKit 30 825 B, TrialClientKit 24 781 B, 12 server stubs, 12 client stubs and the MP-era `MachineFlow`/`KenopsiaClient` **are in the place**. `docs/place/` (21.08.) is stale on this point. | research 03 |
| Framework smoke test | **never run** — no commit, no QA doc says a stub round was played | git log, docs |
| Trials ready | 3 (`birdhunt`, `minefield`, `canteen`); 12 registered with `ready=false`, ~2.9 KB stubs | MachineFlow registry |
| Session length | 4 p: ~771 s (12.8 min); 2 p: ~893 s. BIRD HUNTING = 422 s of it (4 legs × 90 s) | research 01 |
| Machine loop | Selecting 3.5 → Briefing 8.0 → [RoundCard 3.0 → round → Settle 1.5]×n → Score 4.5 → … → Final 8.0; lobby roulette hard-coded 6.4 s | Pacing.luau, MachineFlow |
| Roulette honesty | `preFlow` picks `math.random`, `runMatch` mints its own seed → the lobby reveal can contradict the first trial | MachineFlow 334 vs 460 |
| Verdict | server computes VIABLE/REJECTED, **client never renders it**; final board looks like the interim board | MachineFlow 664–674, KenopsiaClient 1766–1834 |
| Per-round standings | none (`showInterRoundScore` dead) | MP-01 124–131 |
| GUI | 1 ScreenGui, 520 descendants, **fixed pixels** (1 UIScale, 1 UIAspectRatioConstraint, 0 layouts); roulette flicker ≈7 flashes/s (WCAG limit 3); typewriter `string.sub` per char; `Briefing` screen dead; 7 hard-wired touch buttons on 2 anchors; 8 icons for 15 trials, unknown icon → Crosshair silently | research 03, 06 |
| StarterPlayer | `CharacterUseJumpPower=true`, `JumpPower=0`, `AutoJumpEnabled=false` → **F-03 already fixed** | research 03 |
| Lighting | Sky only. No ColorCorrection/Bloom/Atmosphere. Fog 60→480, EnvironmentDiffuse/Specular 0 | research 03 |
| Streaming | `StreamingEnabled=false`, 967 arena parts, arenas ~2 300 studs apart in Z | research 03 |
| Chat | Roblox default chat fully on | research 03 |
| Animations | 11 ids published by user 4840146924, place owned by group 832614570 → Length 0 until access is shared; `warmup()` falls back to `RBX_ANIMSAVES` in Studio only. `Player.Eat=0`, `Boss.Death=0`, 4 face textures 0. **Anim_Eat.fbx + Anim_Stab.fbx exported 22.08. 14:44, not imported; no `Anim_Eat` holder; no `Stab` key; no Fork part anywhere in the place.** All RBX_ANIMSAVES sequences are Priority=Action, Loop=true | research 03, 07 |
| Audio | 34 Sounds. Music: `birdhunt` (0.24), `minefield` (0.45) only. `Ambience` empty. `Music.Loop` gone → lobby music dead code. `sfx("AccessGranted")` silent no-op. 942 local source files; licence PDFs only for PSX Tech, ROT, Rust & Blood | research 07 |
| Persistence / social | 0 DataStore, Badge, GamePass, leaderstats, invites, private servers, captures, notifications | research 02, 05 |
| Props | `ServerStorage.KenopsiaAssets.Props` = Minefield only; `CP_Observer.fbx` (repo) never imported; 16 canteen FBX meshes in `Retro\Kenopsia_Canteen_Import` never imported | research 07 |
| Dead geometry | Baseplate, `gear_mx_1`/`saw_blade` 55 studs under it, `SniperRifle_PSX`, empty `bench`; duplicate lamps/plates (F-16/17/18) | research 03 |
| Tooling | Studio MCP registered and connected (`Kenopsia_MainGame`); weppy sync lock held by DEV place 129909297895850; aftman toolchain + Lua 5.1 present; Blender 4.2/5.2 with blender-mcp, currently not running | research 07 |

### Reference and market, in one paragraph each

**Machine Party** (research 04): the persona is *text only* — no voice; the four-beat grammar (depleting roulette → briefing with per-role controls + INVITE slots + READY → round card with a 4–6 word order ending `._` → intermission score card) is structure, not IP. Praise: chaos with friends, brutalist art, *bespoke* deaths per minigame, soundtrack. Complaints: 1 h of content, fixed order, no matchmaking, stun-lock, no practice, no progression, no comeback. It has **zero built-in virality** — clips happened to it. Banned in source: all reference names and the CRT copy ("POTENTIAL GENE MUTATION SCORE", "NEXT SIMULATION:", "SIMULATION CONCLUDED. DISTRIBUTE …", numbered blue jumpsuit) — REQ-IP-01 extends to copy.

**Roblox 2026** (research 05): ranking is retention + co-play, not CCU. Primary signals: play-through rate, **first-play bounce (<60 s)**, **play days per user**, playtime (capped 60 min/day). Secondary: intentional co-play days (joins, invites, private servers), qualified sessions. 4-player servers are *not* a handicap (Grow a Garden runs 4). What kills us: empty-server cold start, >60 s before first input, nothing to come back for. Cheapest levers: DataStore profile + badges, invite prompt with LaunchData, Party API, paid private servers (fixed price, never change it), Captures prompts, Experience Notifications, weekly Events, Standout Games nomination.

---

## 1. Diagnosis — why it is not yet fun or smooth

1. **No spine of tension.** Standings are invisible for up to 6 minutes; every trial is worth the same 1700; the leader after trial 2 usually wins; the session ends on a board that looks like the last board. The verdict exists and is never shown.
2. **The lobby lies and the join is blind.** The roulette reveal is decorative; late joiners see an empty world; readiness is cleared after every session so the group dissolves at the moment of highest intent.
3. **One trial is half the evening.** BIRD HUNTING 422 s of 771.
4. **The machine has one voice and three bodies.** 3-2-1, cover card and end beat are implemented four times (TrialKit, BirdHunting, Minefield, Canteen) with four feels; five typewriter speeds; ~30 ad-hoc tween durations.
5. **Static, fixed-pixel UI on a phone platform.** 13 px text, 430 px panels, mobile scale clamp to 0.42 (128 px tile → 54 px), tablets on the Desktop branch, everything re-rasterised per animated pixel because it is one ScreenGui.
6. **PS1 stops at the GUI.** The 3D layer is ungraded: no tonemapper, no grade, no quantisation, fog tuned but alone.
7. **The bodies don't move.** Permission blocks 11 clips on a live server; Eat/Stab authored but unreachable; faces unimplemented; boss cannot be staged.
8. **A third of the session is silent** and the lobby is silent.
9. **Nothing persists, nothing invites, nothing is clipped.** Zero of the signals Roblox ranks on are fed.
10. **Docs drift** leads agents into the F-1 class of bug (perfect-looking, unplayable): MP-04 §0 superseded items, MP-06 "tests exist", PLAN.md P2 contradicts E2, `docs/place` says framework not live, audio-inventory.csv stale by 5 sounds.

---

## 2. Target experience — the walkthrough we build toward

Times are targets; they become `Pacing.Timing` / `FeelConfig` values in P1.

| Beat | What the player sees | Target timing |
|---|---|---|
| **Join** | `KenopsiaLoadingGui` boot ledger: fixed-width POST lines, right-aligned `OK`, one 600–900 ms stall, ends when the first lobby packet lands (never longer than real load) | ≤ 8 s, input possible the instant `Selection` shows |
| **Lobby** | `Selection` alive: 15-tile **depleting grid** (played trials dashed), uptime counter 1 Hz, breathing bracket 4–6 s, interference blip every 8–20 s, refresh band 10 s; standings + **INVITE** slots + READY; "NEXT CYCLE IN mm:ss" for late joiners; CRT hum bed | first input ≤ 20 s after spawn |
| **Ready** | carried readiness from the previous session, opt-out countdown | 3 s |
| **Roulette** | honest reveal of `order[1]`; reticle sweep; flicker ≤ 3/s on the dim channel; lock-in snap Quart/Out 0.32 s | 3.5 s |
| **Briefing** | two-column per-role CONTROLS, device-correct glyphs, **first-encounter highlight** of the one new verb; 8 s on first sight of a trial, 5 s on repeat; controls recallable in-round (hold) | 8 / 5 s |
| **Role card** | `<NAME> IS THE HUNTER.` full screen, one sentence | 1.6 s |
| **Round card** | `Round n/m` + tagline `._`, typed at 24 cps time-based | 2.2 s |
| **Round** | kit timer HUD from `ev="deadline"`; telegraph grammar (Signal neon = lethal now, Hazard = soon, ≥ 0.7 s before every kill); death: camera **holds** on the body 2.5 s, death line (`PROCESSED.`), fade 0.5 s; spectate with a verb | per `Pacing.RoundSeconds` |
| **Settle** | **standings card**: rank deltas only (▲▼), Machine comment line | 2.5 s |
| **Trial score** | odometer roll, rank list, binary blocks | 4.5 s |
| **Final audit** | last trial announced `FINAL AUDIT.`, pool ×2 | — |
| **Verdict** | stamp `VIABLE` / `REJECTED` with a distinct sound, podium (3 blocks, winner rig in Idle, losers' slots dark), capture prompt, invite prompt "CALL A SUBJECT FOR THE NEXT SHIFT" | 6 s stamp + 8 s podium |
| **Rematch** | same four players pre-readied, countdown with opt-out; profile row ticks (sessions, wins, best band) | 10 s |

**Machine voice** stays text-only: uppercase, industrial, no jokes, no exclamation marks; subtitle ends `_`; death lines 2–3 words past tense. A comment pool of ≥ 40 original lines (outcome, rank swing, streak, first death, clean sweep).

**PS1 rule:** the *simulation grade* (tonemapper, grade, fog, quantisation, stepped props) is ON only while `KenopsiaActiveTrial ~= ""`. The Machine screens are clean phosphor CRT. Player toggle `SIMULATION FILTER` in Settings.

---

## 3. Timing bible (the "not too slow, not too fast" table)

| Thing | Rule | Value |
|---|---|---|
| Terminal state change (screen swap, cursor) | hard cut | 0 ms |
| Hit / confirm / reject feedback | chroma jolt or hit-stop | 80–120 ms |
| Panel transition | mobile 200–300, desktop 150–200, tablet ~400 | ms |
| Anything except fades | never > 600 ms | — |
| Easing | Linear or stepped for machine elements; Quart/Out only for the crosshair snap | — |
| Typewriter | time-based `MaxVisibleGraphemes`, 24 cps; status lines 30 cps; per-N-grapheme blip, PlaybackSpeed 0.94–1.06 | — |
| Stepped UI motion (house style) | 12–15 fps grid via dt accumulator; never for fades or drag cursors | — |
| Flicker | ≤ 3 transitions/s, dim channel only (#2E6B4A↔#8CE8AE), seeded from `GuiService.ReducedMotionEnabled` | — |
| 3-2-1 | one implementation (TrialKit `Round:countdown`), count punch 160→120 px 0.3 s Quart/Out, GO 150→118 px 0.35 s | 3 × 1.0 s |
| Death | telegraph ≥ 0.7 s → kill instant → hold 2.5 s → fade 0.5 s → spectate at 3.2 s | — |
| Canteen | Observer hidden 2.0–4.0 → lowering 0.35 → watching 0.9–1.8 → raising 0.30; Stab clip 6 f @ 30 = 0.20 s, spammable at 0.16 s; Eat 12 f = 0.40 s, 0.50 s interval; beans vanish at f 5 (server-confirmed only) | — |
| Player rig clip speeds | Walk 4.5, Run 10.95, Push 3.15 studs/s at scale 1 (`AnimationIds.PlayerSpeeds`) | — |
| Boss | LookUp exactly when `lowering` starts (0.35 s tell); Shoot on `execute`; Death parked on last frame | — |
| Roulette total | 3.5 s (tiles 0.25 s apart after 0.4 s, flicker 1.6 s, 4 lock blinks, crosshair 0.32 s) | — |
| Briefing | 8 s first, 5 s repeat | — |
| Round card | 2.2 s (from 3.0) | — |
| Settle | 2.5 s with standings (from 1.5) | — |
| Interim score | 4.5 s | — |
| Verdict + podium | 6 + 8 s | — |
| Lobby roulette hold | move 6.4 s into `Pacing.Timing.LobbyReveal` | 6.4 s |

---

## 4. Work packages

Each package lists: **Agents** (how Fable 5 splits it; files never shared between parallel agents — MP-05 D13), **Files**, **Gate** (what must be true before `ready`/merge), **Live check** (how it is verified in Studio with the real input path, never a synthetic client — PLAN §5).

Legend — effort S/M/L; ✋ = needs a human click (user).

### P0 — Truth and quick wins (1 session, sequential)

**P0.1 Framework smoke test (S).** Flip `ready=true` on one stub (`breather` is the least arena-dependent) in a **DEV copy** (`Kenopsia_DEV` 129909297895850 or a fresh save-as), play a 2-player round through the real client: `ev="begin"` arrives, kit timer shows, `ev="end"` arrives, players return, no `workspace.KenopsiaArenas.<id>._Runtime` remains, `MachineFlow` recovers from a forced `error()` in `runRound`. Write `docs/QA/2026-xx-framework-smoke.md`. Flip back.
*Gate:* all five checks green. *Why first:* everything in P1/P4 stands on it and nobody has ever run it.

**P0.2 Animations unblocked (S, ✋).** User clicks *share access* for the 11 ids (or re-publishes under the group). Then agent: import `Anim_Eat.fbx`, `Anim_Stab.fbx` (holders named exactly `Anim_Eat`/`Eat`, `Anim_Stab`/`Stab`), `Anim_Reading.fbx` as `Reading`, Boss `Anim_Death`; set Priority/Loop per clip (Idle=Idle; Walk/Run/Crouch=Movement, loop; Push/Shoot/Death/Eat/Stab/LookUp/LookDown=Action, no loop); publish ✋; paste ids; add `Player.Stab` + `StudioSequences.Player.Stab`. Import `Player_Rig_Fork.fbx` as `ServerStorage.KenopsiaAssets.Rigs.PS1Player_Fork` (RenderFidelity Precise, 1024 atlas). Import `CP_Observer.fbx` into `Props.CanteenProtocol.CP_Observer`.
*Gate:* `[CP] rigs: … published=true` in a Play log; `tests/animationids.lua` green. *Live check:* Canteen round, diner visibly stabs/eats with the fork in hand.

**P0.3 Pacing + audio quick wins (S).** `Pacing.RoundSeconds.birdhunt` 90→60, `LEGS` 4/3/4→3/3/3; `Pacing.Timing.LobbyReveal=6.4` replaces the literal; canteen music = reuse `minefield` id as `Music.Trials.canteen`; restore `Music.Loop` (id in `audio-inventory.csv`); re-create `SFX.AccessGranted` (upload `access_granted_smx_1.ogg` ✋ licence) or repoint to `Confirm`; normalise `birdhunt` 0.24→0.40.
*Gate:* session at 4 p ≤ 10 min computed from Pacing; every `sfx()` name resolves (add a boot-time warn for unknown names).

**P0.4 Place hygiene (S).** Delete Baseplate (all arenas have floors), `gear_mx_1`, `saw_blade`, `bench`; move `SniperRifle_PSX` to `ServerStorage.KenopsiaAssets`; delete 4 duplicate lamps (F-16), 4 duplicate plates (F-17), sunken props (F-18), the three Mixamo archives (F-19). Decide chat (recommendation: **disable default channels**, Machine has no chat; keep bubble chat off) — `TextChatService.CreateDefaultTextChannels=false`. `StreamingEnabled`: **keep false for now** (runner cameras broke under streaming, F-22); instead parent inactive arenas out of Workspace at trial switch (P1.6).
*Gate:* Workspace instance count < 1 700; a full session plays.

**P0.5 Docs truth pass (S).** `docs/place/README.md` + `07-FINDINGS.md`: add "2026-08-22: framework IS live, 62/62 parity; F-03 fixed; F-04 pushed, smoke per P0.1". MP-04 §0: SUPERSEDED banner (D1/D4/D6/D8 live in MP-05). MP-06 §0: tests/<id>.lua are *new* work. PLAN.md P2: delete the "oder streichen" clause. Regenerate `audio-inventory.csv` from the place. Add `measured on` lines.
*Gate:* `grep -n "nicht im Place\|NOT in the place" docs/place` returns only historical notes.

### P1 — Session spine and Machine feel (M; 3–4 agents in parallel on disjoint files)

| # | Change | Files (owner) | Notes |
|---|---|---|---|
| 1.1 | **Honest roulette + depleting grid**: mint `seed` in `RoomService.beginCountdown`, `preFlow` reveals `order[1]`; `{kind="selection"}` carries `played[]`; client renders 15 tiles (3×5) with dashed consumed slots | MachineFlow, RoomService, KenopsiaClient `showSelection` (agent A) | `Selection.Tiles` grows from 3 to 15 tiles; icons from IconPool |
| 1.2 | **Standings card in Settle**: after each round send `{kind="standings", rows, deltas}`; client shows rank + ▲▼ only; `RoundSettle` 1.5→2.5 | MachineFlow 594–599, KenopsiaClient (agent A) | reuse `Score` screen chrome, no odometer |
| 1.3 | **FINAL AUDIT ×2 + verdict screen + podium**: `Scoring.distribute(ranking, weight)`; RoundCard for the last trial says `FINAL AUDIT.`; `showScore` branches on `p.final` → stamp VIABLE/REJECTED (phosphor vs danger), sound, then podium (3 anchored blocks in a `PodiumStage` model, winner rig playing Idle, fixed camera) | Scoring, MachineFlow, KenopsiaClient `showScore`, new `Services/Podium.luau` (agent B) | podium from parts, no new art |
| 1.4 | **Machine comment pool**: `Shared/Config/MachineVoice.luau` (≥ 40 lines, categories outcome/swing/streak/first-death/sweep/idle), fired with standings and score packets; role card `{kind="rolecard", text}` 1.6 s beat for asymmetric trials | new module, MachineFlow, KenopsiaClient (agent C) | voice rules §2; IP grep in `tests/rules.lua` extended to the CRT copy strings |
| 1.5 | **FeelConfig**: `Shared/Config/FeelConfig.luau` with every cps, tween duration, easing, shake decay, flicker rate; client reads it; typewriter → time-based `MaxVisibleGraphemes`; unify 3-2-1 on TrialKit for the three legacy trials (or at least same numbers) | KenopsiaClient, TrialClientKit, BirdHunting, Minefield, CanteenProtocol (agent D, sequential after A–C merge) | `tests/feel.lua` asserts the timing bible |
| 1.6 | **Robustness**: `MachineFlow` round deadline = `RoundSeconds[id] + 20 s` → abort trial, not session; unknown packet kind → warn once, no `session += 1`; `Playlist.order` anti-monotony (`form` tag per registry entry: survival/finish/score; ≤ 2 adjacent survival; `breather`/`stacker` never first or last); inactive arena folders parented to `ServerStorage.KenopsiaArenasParked` at trial switch | MachineFlow, Playlist, `tests/rules.lua` (agent E) | rules stay Lua-5.1 portable |
| 1.7 | **Rematch + late joiners**: `cleanupToWaiting` keeps readiness for the last participants with a 10 s opt-out countdown; late joiners get `{kind="lobbywait", nextCycleAt}` and the audience packets of the running trial (`TrialKit.audienceOf`) with a fixed camera | RoomService, MachineFlow, KenopsiaClient lobby (agent F) | F-09 closed |

*Gate:* offline tests green (`rules`, `feel`, `contexts`, `envelope`, `trialrules`, `animationids`), luau-lsp + selene clean, IP grep clean. *Live check:* one full 2-player session via real clicks (`user_mouse_input`): roulette matches first trial, standings card appears after every round, verdict stamp + podium render, rematch countdown fires, joining mid-match shows `NEXT CYCLE IN`.

### P2 — Alive, retro, every device (M–L; agents by layer)

| # | Change | Owner |
|---|---|---|
| 2.1 | **Split the GUI** into `KenopsiaMachine_Static` (grunge, brackets, chrome), `KenopsiaMachine` (live text/counters), `KenopsiaMachine_Overlay` (scanlines, vignette, refresh band, fader; `IgnoreGuiInset=true`, `ScreenInsets=None`); content GUIs `ScreenInsets=DeviceSafeInsets`. Root `UIScale` driven by viewport (`min(1, vpY/720)` then platform clamps), `UIAspectRatioConstraint` on tiles/icon holders/brackets, `UISizeConstraint` on panels. Fix `Info.Grunge.Right` (X scale 1.0027) and `Btn_SETTINGS` (negative Y scale). Re-measure CrossH/CrossV vs `AbsolutePosition`, Info overlap of status line vs `NEXT SIMULATION`, `SelIcon` position (user's 3 screenshots) | agent UI-A (KenopsiaClient screens, MachineLayout) |
| 2.2 | **Overlay & life**: scanline tile (8 px period, `ResampleMode=Pixelated`), refresh band (8 s idle / 2 s sweep), vignette, Bayer dither fades (4 tiles @ 12 fps) between screens, phosphor glow (UIStroke + offset duplicate), step-end cursor, idle oscillators on Selection, chroma jolt on reject/hit, relay-click SFX through a `SoundGroup` + low CRT hum that ducks under announcements, boot ledger in `KenopsiaLoading` | agent UI-B (new `UiFx.luau` client module, KenopsiaLoading) |
| 2.3 | **Accessibility**: seed `ReduceFlicker`/`ReduceShake` from `GuiService.ReducedMotionEnabled`; flicker rule from §3; multiply transparencies by `PreferredTransparency`; derive text sizes from `PreferredTextSize`; Settings rows: `CRT`, `GRAIN`, `FLICKER: ON/REDUCED`, `SIMULATION FILTER`, `SHAKE` | agent UI-B |
| 2.4 | **Platforms**: detection via `UserInputService.{Touch,Keyboard,Mouse,Gamepad}Enabled` + `LastInputTypeChanged`, aspect as a separate axis (`Tablet` branch for 4:3); 44 pt touch floor, bottom 30 % clear of custom UI except pads; `kit.pad()` canonical layouts `single | dual | quad | stick+one`; legacy `TouchControls` folded into one context button per slot; console: `PlayerGui.SelectionImageObject` = phosphor bracket, `SelectionGroup` + `SelectionBehavior.Stop` per panel, `GuiService:Select(panel)`; platform-correct glyphs via `UserInputService:GetStringForKeyCode` / `GetImageForKeyCode` | agent UI-C (MachineLayout, TrialClientKit pad, TouchControls) |
| 2.5 | **Briefing & icons**: two-column per-role controls; INVITE slots (P5 wires them); first-encounter highlight; in-round recall (hold `Tab`/`Back`/long-press); 7 new pixel-block icons (chisel, arrow, syringe, cigarette→"breath", blade, pallet, funnel) in IconPool; warn on unknown icon | agent UI-D (KenopsiaClient `showInfo`, IconPool via Studio edit) |

*Gate:* no `string.sub` typewriter left; flicker ≤ 3/s measured by a test harness; `ResampleMode=Pixelated` on every ImageLabel; luau-lsp clean. *Live check:* Studio device emulation captures (`screen_capture`) for iPhone 19.5:9, iPad 4:3, 1080p desktop, console 1080p at 10-ft scale — every screen, all legible, no overlap, touch pads ≥ 44 pt; MicroProfiler on a real phone ✋ (user) before/after 2.2 — UI render time must not rise above the pre-2.1 baseline.

### P3 — PS1 look, minigames only (M)

| # | Change | Owner |
|---|---|---|
| 3.1 | **SimulationGrade** client module: on `KenopsiaActiveTrial` non-empty apply (and snapshot/restore on empty): `ColorGradingEffect.TonemapperPreset=Retro`, `ColorCorrectionEffect` (Saturation −0.35, Contrast 0.08, tint toward arena palette), per-arena fog + `Atmosphere` preset, camera **position** quantisation 1/8 stud (never rotation; off in birdhunt scope; off under ReducedMotion), prop animation stepping 12–15 Hz for kit-driven props. Each `TrialClients/<id>.luau` exports `presentation = { music=, grade=, fog= }` next to `controlsText` (the D15 precedent) | agent FX-A (new client module, TrialClientKit, KenopsiaClient 295–375 DZ lighting folded in) |
| 3.2 | **Texel rules**: `SurfaceGui` + Pixelated ImageLabel for diegetic monitors/signage/objective monoliths (`{kind="monolith", text}`); 1024 nearest-upscaled atlases remain the 3D rule; flat shading/hard edges in Blender exports; ArenaPalette ≤ 5 colours per arena, Signal/Hazard neon only for telegraphs | agent FX-B (arena kit in TrialKit `ensureArena` helpers, Blender pipeline note) |
| 3.3 | **PS1 rig as StarterCharacter** behind `GameConfig.Character.UsePS1Rig` (after P0.2 proves the clips play live); Animate script from `dev-src/StarterPlayer/StarterCharacter/Animate.client.luau` as the starting point; uniform silhouette + one identity slot (cap colour = subject colour) | agent FX-C (sequential, risky; own QA doc) |

*Gate:* toggling the filter off restores Lighting byte-for-byte (snapshot compare); phone MicroProfiler ✋ frame time within budget with grade on; birdhunt aim unaffected. *Live check:* play canteen + minefield with filter on/off; screenshot pairs into `docs/QA/`.

### P4 — Trials (L; one agent per trial, never two on shared files)

Order by play value (PLAN §3): **canteen completion → sorting → upstream → stacker → carrier → armory → carve → sweep → crawler → clearance → floorcheck → ricochet → breather**.

**4.0 Canteen completion (M):** adopt `hover_bind.json` in `CanteenDiner.sit()` (replaces the two right-arm ops; verify with the recipe in the JSON against `RightHand.TransformedWorldCFrame`); `CanteenDiner:stab()` on `plate` input (Stab clip, 0.16 s min interval), `eat()` on `mouth` (Eat clip; beans on fork = `Beans_Fork` transparency, plate beans = server-confirmed count → never an invisibly consumed bite: the bean leaves the plate only on the server ack, the clip runs on the ack, `eatGen` restart keeps the accepted bite); LookUp fires exactly at `lowering` start; move `PlateAnchors`/`MouthTargets` to the clip's authored geometry (plate 3.2 studs in front of the seat at chin height) or scale the clip; replace CanteenProps' flying fork with the rig's fork; `CP_Observer` + boss clips; face textures consumer (blink 3–5 s/0.1 s, Hurt on hit, Happy on VIABLE, BossAngry on LookUp); import the 16 canteen meshes into Props swap slots. Bespoke death: shot at the table, slump forward face-down (reference grammar), blood on the cloth.

**4.1–4.12 New trials:** per trial the four files (`Services/<Name>.luau`, `Shared/Rules/<Name>Rules.luau`, `TrialClients/<id>.luau`, `tests/<id>.lua` ≥ 15 checks), `controlsText` + `presentation` + `padLayout` exports, one **bespoke death** set-piece via `{kind="gorefx"}` variants, telegraph ≥ 0.7 s, server-authoritative kills, push/stun counterplay (cooldown + recovery frames), per-count tuning rows already in Pacing. Survival-form trials get one **mutator axis** each (seeded layout / escalating tempo / variant rule) so run 12 ≠ run 1.
**Gate per trial (PLAN §5):** IP grep → `git diff --stat` four files only → `lua tests/<id>.lua` green → luau-lsp + selene → MP-05 §E acceptance → DEV play with the real input path → `docs/QA/<id>.md` → commit → `ready=true`.
After > 5 ready: `PerSession=5` active; session ≤ 10 min at 4 p.

### P5 — Retention and growth (M; parallel with P4)

| # | Change | Cost |
|---|---|---|
| 5.1 | `Services/Profile.luau`: DataStore profile with session lock (sessions, VIABLE count, best band per trial, daily streak, first-seen per trial for the briefing highlight); lobby profile row; `tests/profile.lua` on the pure part | M |
| 5.2 | Badges (5 free/day): FIRST SHIFT, FIRST VIABLE, CLEAN SWEEP (a trial with no death), THREE NIGHTS (streak), FULL ROSTER (all trials seen), CO-WORKERS (session with 3+ humans) | S |
| 5.3 | Invite: `SocialService:PromptGameInvite` with `LaunchData` = room/reserved code, surfaced on the INVITE slots and on the verdict screen; Party API: `Player.PartyId` groups party members into one room (test only in a published build ✋) | S–M |
| 5.4 | Private servers at a **fixed** price (never change it) with host toggles: playlist, round length, filter presets — cosmetic only | S ✋ |
| 5.5 | Captures prompts on exactly four beats (elimination, REJECTED, last-second VIABLE, canteen finale), ≤ 3/session | S |
| 5.6 | Experience Notifications opt-in after first VIABLE; weekly `NIGHT SHIFT` Experience Event with a rotating playlist + `OrderedDataStore` weekly boards shown as an etched subject wall in the lobby | M |
| 5.7 | Never wait: solo **PRACTICE SHIFT** (one-button scored run of the next trial against ghosts of recorded runs) while matchmaking resolves; mid-match joiners enter at the next trial | L |
| 5.8 | Icon/thumbnail experiments (Machine + four subjects), Standout Games nomination ✋, Creator Analytics signal check once traffic exists | S |

*Gate:* DataStore calls budgeted (< 1 write per player per round), profile survives server restart, badges award once. *Live check:* two accounts, streak increments across a day boundary (mock clock in tests).

### P6 — Audio (S–M, mostly ✋ uploads)

Licence evidence first (Echoes, System Status Alerts, Special Ambiences, Super Retro Game OST — one purchase-history export ✋). Then: `Ambience` bed per arena family (ROT first, licensed), **one base loop + intensity layer** per trial form instead of 15 tracks (3–4 uploads), UI kit from the 37 Echoes GUI sounds + 25 voice lines (industrial, no jokes) into `SFX_POOLS`, normalise all music to −0.45, verdict stinger, podium fanfare. Regenerate `audio-inventory.csv`; ledger rows green before release.

### P7 — Later updates: fun modes (design now, build after P5)

| Mode | One line | Needs |
|---|---|---|
| **ARCADE** (default) | 5 seeded trials, anti-monotony rule, ≤ 10 min | P1 |
| **FULL SHIFT** | all 15, ceremonial intro/outro, FINAL AUDIT, podium | P4 |
| **CUSTOM SHIFT** | private-server host picks playlist, round length, filter | P5.4 |
| **NIGHT SHIFT** | weekly mutators (no telegraph colour → sound only; double speed; mirrored arenas), weekly board | P5.6 |
| **SABOTEUR** | eliminated players get one sabotage verb per round (trigger a hazard, swap a plate) — turns dead time into play | P1.7 |
| **AUDIT** | 1v1 best-of-5 on finish-form trials | P4 |
| **INCIDENT ARCHIVE** | diegetic replay of the session's best death with a share frame (Captures) — the growth engine the reference lacks | P5.5 |
| **PRACTICE SHIFT** | solo/ghost runs, no score pool | P5.7 |

---

## 5. GitHub as the planning surface

- `docs/MASTERPLAN.md` (this file) — the plan; `docs/research/2026-08-22-sweep/` — the evidence; `docs/QA/` — one file per live check.
- **Milestones** M2–M8 = phases P0–P6 (+ M9 modes). **Issues** one per work package row, with the acceptance checklist from its *Gate* and *Live check*, labels `phase:P#`, `area:{flow,ui,fx,trial,growth,audio,docs}`, `device:{mobile,console,ipad,pc}`, `needs-user` for ✋ items, `blocker`.
- An issue is closed only by a commit that references it **and** a `docs/QA/*.md` live check where the gate says so.
- `PLAN.md` stays as the decision log; this file owns the order.


### Issue map (created 2026-08-22)

Milestones M2–M9 = phases P0–P7 at https://github.com/whatsaheart-oxxzy/kenopsia-roblox/milestones. Labels: `phase:P#`, `area:*`, `device:*`, `needs-user`, `blocker`. No Projects board (token lacks the `project` scope).

| # | Milestone | Issue |
|---:|---|---|
| [#1](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/1) | M2 P0 Truth and quick wins | P0.1 Framework smoke test in a DEV copy (never run so far) |
| [#2](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/2) | M2 P0 Truth and quick wins | P0.2a Share access for the 11 published animation ids (group place) |
| [#3](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/3) | M2 P0 Truth and quick wins | P0.2b Import Eat, Stab, Reading, Boss Death; fix priorities/loops; publish; paste ids |
| [#4](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/4) | M2 P0 Truth and quick wins | P0.2c Import the fork rig and CP_Observer as templates |
| [#5](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/5) | M2 P0 Truth and quick wins | P0.3 Pacing + audio quick wins |
| [#6](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/6) | M2 P0 Truth and quick wins | P0.4 Place hygiene and the chat decision |
| [#7](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/7) | M2 P0 Truth and quick wins | P0.5 Docs truth pass |
| [#8](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/8) | M3 P1 Session spine and Machine feel | P1.1 Honest roulette + depleting 15-tile grid |
| [#9](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/9) | M3 P1 Session spine and Machine feel | P1.2 Standings card after every round |
| [#10](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/10) | M3 P1 Session spine and Machine feel | P1.3 FINAL AUDIT x2, verdict stamp, podium |
| [#11](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/11) | M3 P1 Session spine and Machine feel | P1.4 Machine comment pool + role card beat |
| [#12](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/12) | M3 P1 Session spine and Machine feel | P1.5 FeelConfig + time-based typewriter + one 3-2-1 |
| [#13](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/13) | M3 P1 Session spine and Machine feel | P1.6 Robustness: round timeout, unknown-kind guard, anti-monotony playlist, parked arenas |
| [#14](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/14) | M3 P1 Session spine and Machine feel | P1.7 Rematch with carried readiness + late-joiner wait/audience |
| [#15](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/15) | M4 P2 Alive retro UI, every device | P2.1 Split the GUI, viewport scale, constraints, geometry fixes |
| [#16](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/16) | M4 P2 Alive retro UI, every device | P2.2 Overlay and idle life + boot ledger |
| [#17](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/17) | M4 P2 Alive retro UI, every device | P2.3 Accessibility seeds + settings rows |
| [#18](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/18) | M4 P2 Alive retro UI, every device | P2.4 Platform detection, canonical touch pads, console focus |
| [#19](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/19) | M4 P2 Alive retro UI, every device | P2.5 Briefing per role, in-round recall, INVITE slots, seven icons |
| [#20](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/20) | M4 P2 Alive retro UI, every device | P2.6 Device QA sheet + phone profiling |
| [#21](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/21) | M5 P3 PS1 look in minigames only | P3.1 SimulationGrade: PS1 look only while a trial runs |
| [#22](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/22) | M5 P3 PS1 look in minigames only | P3.2 Texel rules: SurfaceGui monoliths, ArenaPalette |
| [#23](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/23) | M5 P3 PS1 look in minigames only | P3.3 PS1 rig as StarterCharacter behind a flag |
| [#24](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/24) | M6 P4 Trials | P4.0 Canteen completion: fork, stab/eat, plates, observer, faces, bespoke death |
| [#25](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/25) | M6 P4 Trials | P4.1 trial `sorting` - SORTING FLOOR |
| [#26](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/26) | M6 P4 Trials | P4.2 trial `upstream` - UPSTREAM |
| [#27](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/27) | M6 P4 Trials | P4.3 trial `stacker` - PALLET DUTY |
| [#28](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/28) | M6 P4 Trials | P4.4 trial `carrier` - CARRIER |
| [#29](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/29) | M6 P4 Trials | P4.5 trial `armory` - ARMS ISSUE |
| [#30](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/30) | M6 P4 Trials | P4.6 trial `carve` - CUT TO SPEC |
| [#31](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/31) | M6 P4 Trials | P4.7 trial `sweep` - CLEAR THE DECK |
| [#32](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/32) | M6 P4 Trials | P4.8 trial `crawler` - CRAWLER |
| [#33](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/33) | M6 P4 Trials | P4.9 trial `clearance` - CLEARANCE |
| [#34](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/34) | M6 P4 Trials | P4.10 trial `floorcheck` - FLOOR CHECK |
| [#35](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/35) | M6 P4 Trials | P4.11 trial `ricochet` - RICOCHET |
| [#36](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/36) | M6 P4 Trials | P4.12 trial `breather` - BREATHER |
| [#37](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/37) | M6 P4 Trials | P4.13 Activate PerSession=5 and run the full-session QA |
| [#38](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/38) | M7 P5 Retention and growth | P5.1 Profile DataStore (sessions, wins, best band per trial, streak, first-seen) |
| [#39](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/39) | M7 P5 Retention and growth | P5.2 Badges (5 free per day) |
| [#40](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/40) | M7 P5 Retention and growth | P5.3 Invite prompt with LaunchData + Party API grouping |
| [#41](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/41) | M7 P5 Retention and growth | P5.4 Paid private servers at a fixed price + host toggles |
| [#42](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/42) | M7 P5 Retention and growth | P5.5 Captures prompts on four beats |
| [#43](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/43) | M7 P5 Retention and growth | P5.6 Notifications opt-in, weekly NIGHT SHIFT event, weekly subject wall |
| [#44](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/44) | M7 P5 Retention and growth | P5.7 Never wait: PRACTICE SHIFT (ghost runs) + mid-match join at the next trial |
| [#45](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/45) | M7 P5 Retention and growth | P5.8 Icon/thumbnail experiments + Standout Games nomination |
| [#46](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/46) | M8 P6 Audio | P6.1 Licence evidence for Echoes, System Status Alerts, Special Ambiences, Super Retro OST |
| [#47](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/47) | M8 P6 Audio | P6.2 Ambience beds, base loop + intensity layers, UI sound kit, inventory regen |
| [#48](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/48) | M9 P7 Later modes | P7 Modes for later updates: design doc |
| [#49](https://github.com/whatsaheart-oxxzy/kenopsia-roblox/issues/49) | M2 P0 Truth and quick wins | Open decisions (user) - answer before the phase that needs them |

## 6. Execution protocol for Fable 5 (ultracode)

1. One **Workflow per phase**; inside it `pipeline()` per work package: implement → offline gates → adversarial review (refute-first, 2 of 3 must pass) → live check in Studio → QA doc → commit. Agents own disjoint files (MP-05 D13); shared files (`MachineFlow`, `KenopsiaClient`, `Pacing`, `Playlist`, `GameConfig`, `TrialKit`, `TrialClientKit`, `MachineLayout`) are edited by **one** agent per phase, sequentially.
2. Studio MCP is the write path: edit `.Source` in place (stable `sessionDebugId`), `ChangeHistoryService:TryBeginRecording` around batches, never delete/recreate scripts, never destroy a running driver script (stop Play instead). Rojo is never connected; weppy only for read-side parity (`tools/weppy.ps1`), and only after its sync lock on DEV is released.
3. Before every phase: checksum parity place ↔ `studio-src` (the Luau/Python pair in research 03). After every phase: parity again, commit, push.
4. Test the real input path (`user_mouse_input` / `user_keyboard_input` through the real client). A synthetic client that reads tokens from packets is banned (F-1).
5. Never: reference names or CRT copy in `studio-src/`/`tests/`; leg keys in exported clips; bulk-push of anything; raising the player count (E1).
6. ✋ items are batched into one user checklist per phase (permissions, uploads, publishes, phone profiling, Game Settings).
7. Memory/docs: every measured fact that contradicts a doc gets fixed in the doc in the same commit.

## 7. Verification (end-to-end)

- Offline: `StyLua --check`, `rojo build`, `rojo sourcemap` + `luau-lsp analyze`, `selene`, `lua tests/*.lua`, IP grep.
- Studio: Play a full 2-player and 4-player ARCADE session (real input), capture every Machine screen on four device emulations, console focus walk with a gamepad, MicroProfiler on phone ✋.
- Published: a DEV-place publish for Party API / invites / private servers / captures (cannot be tested in Studio) ✋.
- Metrics after launch: Creator Analytics — bounce < 60 s, D1, co-play days; adjust P5 by the signal ranking shown there.

## 8. Open decisions (recommendation in bold; none blocks P0–P2)

1. Default chat: **disable** default channels (Machine has no chat) vs restyle.
2. Music: **base loop + intensity layers** (3–4 uploads) vs 15 tracks.
3. Test place: **Kenopsia_DEV as the always-on test copy** (save-as from MainGame before each phase) vs testing in MainGame.
4. `SIMULATION FILTER` default: **ON**, with the toggle seeded from ReducedMotion.
5. Private-server price: set once, **never change** — pick before P5.4.
6. Ship `Stab` as its own clip: **yes** (click-to-stab, other button to eat, as designed 22.08.).
7. `StreamingEnabled`: keep off, park inactive arenas (P1.6); revisit after P4 with a phone measurement.
8. Docs language going forward: this plan and issues in English (agent-facing), QA docs may be German.
