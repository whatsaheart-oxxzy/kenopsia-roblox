# Kenopsia — Release checklist (Stand 30.08.2026)

Scope: THREE trials (BIRD HUNTING, DEAD ZONE, CANTEEN PROTOCOL), 2–4 players, ARCADE session
(roulette → trials → FINAL AUDIT → verdict + SHIFT REPORT + podium → rematch). Sorting stays
`ready=false`.

**This file is the single blockers list.** Everything below is either done, needs the user, or is
deliberately not built. Per-phase evidence lives in `docs/QA/`.

## Done and verified (QA docs under docs/QA/)

### Framework (to 24.08)
- Session spine: honest roulette (6.4 s hold), standings + Machine voice lines, FINAL AUDIT ×2,
  verdict stamp, podium (8 s), rematch with carried readiness, bench card + audience camera packets.
- FeelConfig timing bible: time-based typewriter (24/30 cps), flicker ≤ 3/s, one 3-2-1, dither
  screen swaps, phosphor glow, idle life on the machine screens.
- PS1 pass: per-trial grade + world grain, camera quantisation 6 px, PS1 rig (scale 0.9) with
  published group-owned clips incl. field death (0.6 s offset), crawl, injured walk; phase-matched
  walk↔run with the 1 s DZ sprint ramp.
- Perf: split HUD gui, gore caps, room-scoped gore, ONE input dispatcher, living cache, watchdog
  aborts with cleanup, client-side compactor march, turret/jump/layout/rayfilter write reduction.
- Accessibility: ReducedMotion seeds, SIM FILTER / CRT / FLICKER / SHAKE settings rows, chat hidden
  during trials, console focus traps + device glyphs, touch buttons ≥ 64 px.
- Hygiene: place cleaned (duplicates, archives), REQ-IP-01 grep incl. reference CRT copy, docs truth.

### Inner game (30.08, `docs/INNER-GAME-PLAN.md`)
- **P1** Lighting repaired to the blue baseline (the live fog band was one edit from a
  divide-by-zero); blue sky twin; lamp de-dupe; `RunnerVsCars` parked; `LightGuard` mobile
  black-world sentinel; `Telemetry` (AnalyticsService); `AtlasTiers`.
- **P2** `GradeDirector` + `GradePresets` + `tests/grade.lua`; per-trial blue grades keyed on
  `KenopsiaTrialId`; byte-exact snapshot/restore with a `GradeRestoreMismatch` attribute.
- **P3** Trial polish: canteen suspicion meter / fake-lowers / hot peas / SETTLEMENT; DEAD ZONE
  sonar economy, persistent craters, speed step + lane-light cascade, BLACKOUT SWEEP, scrap tags;
  BIRD HUNTING reload lamp, injury state, push-topple, exposure highlight, decoy birds.
- **P4** Retention: `Profiles` (DataStore `KenopsiaProfile_v1`, volatile-first, UpdateAsync-only),
  `ProgressionRules` (XP/CLEARANCE/streak-with-shield), the SHIFT REPORT beat, the six-badge
  dormant socket, WORK ORDERS + crate-key fragments.
- **P5** Emote + gamepass sockets: `EmoteRegistry`, `MonetizationConfig`, `EmoteService`, the
  `XBotEmote` one-shot channel in PS1Animate, and the six user-supplied dances.
- **P4d** `SocialClient` — the invite sheet on the SHIFT REPORT when a seat is open.
- **E6 maturity** — blood cut to ~40 % of the old volume behind one `GORE` table; the half-body
  crawl is gone (a mine wounds, it does not amputate) and the client leg-fold is deleted.

## BLOCKING — needs the USER before release

### Decisions nobody but you can make
1. **Gamepasses (2).** Create them in Creator Hub, paste the ids into
   `Shared/Config/MonetizationConfig.PASSES`, and decide what each grants. Today `OVERSEER` grants
   an empty emote list + a cosmetic tint and `ARCHIVE` grants nothing. Every id is `0`, which means
   the whole paid surface is silent — no prompt can appear until you paste.
2. **Which of the six dances are Robux vs crate.** All six ship as `crate` (keys are EARNED from
   WORK ORDERS), so nothing is sold yet. Flipping one is two edits — `source = "robux"` on the row
   **and** its id in that pass's `grants.emotes`; `tests/emotes.lua` fails the build if you do only
   one half.
3. **Private-server price — set ONCE** (`MonetizationConfig.PrivateServerPrice`, plan recommends
   99 R$). The number itself goes in Game Settings; the constant only records it. Roblox lets you
   change it later and every change reads as a bait-and-switch to people who already bought one.
4. **Badge ids (6).** Create them and paste into `Services/Badges.luau` → `BADGES`: FIRST_SHIFT,
   FIRST_VIABLE, CLEAN_SWEEP, THREE_NIGHTS, FULL_ROSTER, CO_WORKERS. All `0` = silently skipped.
5. **Audio licences (#46).** No audio ships without licence evidence in the ledger. **Phase 6 is
   entirely blocked on this** — the canteen still shares minefield's track, which is the biggest
   remaining audio identity leak.
6. **Age questionnaire — RE-AUDIT DOWN.** The 24.08 answer was "heavy fantasy gore". Decision E6
   made the game mild (~14+): implication over gore, no dismemberment, hard-cut deaths, ~40 % blood.
   The questionnaire must be re-answered to match, and #49 updated in the same pass.

### Engineering, before publish
7. **Reconcile `studio-src/` against live — DO THIS BEFORE ANY ROJO CONNECT.** The mirror is behind
   the place: `KenopsiaClient` by ~750 lines, `PS1Animate` 307 vs 454, plus `Minefield`, `BloodFX`,
   `GoreClient` and `AnimationIds`. The live-only `BloodFX`/`GoreClient` content matches the
   **unmerged `worktree-mp-08-death-and-spectate` branch** byte-for-byte, so that branch's fate is
   part of this decision. **A Rojo push from `studio-src/` today would overwrite live work.** This
   wants one deliberate commit off a live dump, not a drive-by.
8. **Remove the authoring rigs from the place**: `Anim_PushFall`, `Player_Rig`, `Headbutt`,
   `Injured Walking`, `Death Fall`, `Dancing`, `Rifle Aiming Idle`, `Sneak Walk`, `Zombie Crawl`,
   `Fall Flat` — ten models used only to author clips. (`Workspace.EmoteRigs`, the six emote preview
   rigs, is already gone from the place.)
9. **Purge `RBX_ANIMSAVES`** (29,785 instances ≈ 74 % of the datamodel) **from the published place
   only**, after a live-server clip verification pass. Keep a Studio authoring save.
10. **Save & Publish** after every session that pushes scripts (parity is verified each time).

### Test debt — needs Play, which I could not drive
The official `Roblox_Studio` MCP has been dead all session (no Play control, no input injection; it
never re-registered across three Studio restarts), so **nothing below has been run in Play**. Every
item was verified statically instead — live parser-clean, offline suites green, anchors read back.

- **P2** grade cycle: each trial's grade applies and restores byte-exact on exit; no
  `GradeRestoreMismatch` attribute appears.
- **P3a/b/c** the per-trial checklists in their QA docs.
- **P4a/b/c** ≤1 DataStore write per player per round; the ~5 s SHIFT REPORT beat is visible as a
  held final board; quitting mid-beat recovers; console silent (no `[Badges]` warns at id 0).
- **Gore/crawl (E6)**: first mine → wounded crawl on a WHOLE body with the normal clip, no thrown
  lower half, trail still dripping; second mine → death; blood visibly lighter on a phone; no lens
  blood past ~32 studs; shake still reads hardest on the compactor.
- **P5**: console prints `[EmoteService] online - 7 emote(s), 0/2 gamepass(es) armed`; an emote
  plays once and the attribute clears; the SAME emote pressed twice plays twice (the pulse); a
  press while moving or inside a trial does nothing; no purchase prompt can appear.
- **P4d**: the invite sheet opens on a SHIFT REPORT with a seat open, at most twice a session.
- **2-player run**: role card names the hunter once per leg; injured walk after a body shot;
  canteen fake-outs; podium with two blocks; audience camera for a bench client.
- **Phone check (#20)**: MicroProfiler once in a trial and once during a screen swap; full session
  with no black frame at 60 fps; texture memory logged.

## Deliberately NOT built (so nobody hunts for it)

From INNER-GAME-PLAN §6, the parts that need a published place or belong to the UI owner:
- **Captures prompts** (`CaptureService`, 4 beats, ≤3/session) — untestable in Studio.
- **Experience-notification opt-in** after first VIABLE + the weekly NIGHT SHIFT push.
- **Weekly OrderedDataStore subject wall** on a lobby CRT — needs a SurfaceGui, so it is Codex's.
- **Lobby invite button** — `SocialService:PromptGameInvite` is a plain client call, so a button
  calls it directly; it deliberately is not a second popup in `SocialClient`.
- **Emote wheel + shop screens** — Codex's. The contract is ready: `profile.emotes.wheel`, the
  `emotestate` packet, and the `EmotePlay` / `EmoteEquip` / `ShopPrompt` remotes.
- **Phase 6 audio** — blocked on #46 above.

## Known non-blockers (tracked)
- CRT hum asset missing (silent until P6 uploads `SoundService.KenopsiaAudio.Ambience.Hum`).
- Sorting Floor built but held back; UPSTREAM and the other 11 trials post-release (P4).
- `Feel.Fade.ScreenBlood` reads 0.55 in FeelConfig but is scaled to 0.36 at the call site — fold
  `FadeScale` in when FeelConfig next opens.
- On touch, `GORE.SplatsT` (22) sits just under one shatter's ~27–30 splats, so the oldest few fade
  early. Still far better than the old 66-vs-40. Raise to 30 if it reads as a bug.
- GRAIN settings row, PreferredTextSize, ScreenGui static/live split, depleting 15-tile grid — P2
  leftovers, none player-blocking with 3 trials.
