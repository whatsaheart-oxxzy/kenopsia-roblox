# Kenopsia — Release checklist (Stand 24.08.2026)

Scope: THREE trials (BIRD HUNTING, DEAD ZONE, CANTEEN PROTOCOL), 2–4 players, ARCADE session
(roulette → trials → FINAL AUDIT → verdict + podium → rematch). Sorting stays `ready=false`.

## Done and verified (QA docs under docs/QA/)
- Session spine: honest roulette (6.4 s hold), standings + Machine voice lines, FINAL AUDIT ×2,
  verdict stamp, podium (8 s), rematch with carried readiness, bench card + audience camera packets.
- FeelConfig timing bible: time-based typewriter (24/30 cps), flicker ≤ 3/s, one 3-2-1, dither
  screen swaps, phosphor glow, idle life on the machine screens.
- PS1 pass: per-trial grade + world grain, camera quantisation 6 px, PS1 rig (scale 0.9) with
  published group-owned clips incl. field death (0.6 s offset), crawl, injured walk; phase-matched
  walk↔run with the 1 s DZ sprint ramp; mine hits (direct AND knock) take the lower half.
- Perf: split HUD gui, gore caps, room-scoped gore, ONE input dispatcher, living cache, watchdog
  aborts with cleanup, client-side compactor march, turret/jump/layout/rayfilter write reduction.
- Accessibility: ReducedMotion seeds, SIM FILTER / CRT / FLICKER / SHAKE settings rows, chat hidden
  during trials, console focus traps + device glyphs, touch buttons ≥ 64 px.
- Hygiene: place cleaned (duplicates, archives), REQ-IP-01 grep incl. reference CRT copy, docs truth.

## Blocking — needs the USER before release
1. **Save & Publish** the place after every session I push scripts (parity is verified each time).
2. **2-player test** (one run): role card names the hunter once per leg; injured walk after a body
   shot; DZ maim visual from the second screen; canteen fake-outs; podium with two blocks; audience
   camera for a third/bench client. Report anything that feels off.
3. **Phone check** (#20): MicroProfiler once in a trial and once during a screen swap (dither);
   judge grade brightness on real hardware.
4. **Game Settings** (Creator Hub): genre, age guidelines questionnaire (blood/gore settings — the
   game uses heavy fantasy gore), max players 28 (server) is fine, icon + thumbnails.
5. Optional day-1: badges (5 free/day, #39), a DEV place publish for invite/captures work (P5).

## Known non-blockers (tracked)
- CRT hum asset missing (silent until P6 uploads `SoundService.KenopsiaAudio.Ambience.Hum`).
- Sorting Floor built but held back; UPSTREAM and the other 11 trials post-release (P4).
- GRAIN settings row, PreferredTextSize, ScreenGui static/live split, depleting 15-tile grid — P2
  leftovers, none player-blocking with 3 trials.
- Full-session QA log: docs/QA/2026-08-24-full-session.md (this run).
