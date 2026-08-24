# QA — 24.08. mobile pass (aim assist, layout fixes, touch polish)

1. **Mobile aim assist (medium)** — touch snipers get a magnet: inside a small cone (8° hip,
   5° scoped) the aim angles ease toward the nearest LIVING player head every frame (framerate-safe
   exponential, scoped 7/s, hip 4.5/s) — a pull, never a snap. Gated on `touchAllowed()` (Platform
   Mobile/Tablet or a real touch device; Console and PC never). Found on the way: the first gate
   referenced the FUNCTION instead of calling it — the assist would have run on PC. Fixed before
   push.
2. **Layout fix (measured with ForcePlatform=Mobile, scale 0.62)** — the terminal SYS status cells
   collided with the roster/progress cluster bottom-right; the row is bottom-LEFT now on every
   platform.
3. **Touch polish** — the DANCE emote button 56 → 64 px (44 pt floor with margin) + machine-style
   UIStroke; controls text correctly switches to touch wording ("PLATE button loads") — verified in
   the capture.
4. Existing touch surfaces re-audited: trial buttons ≥ 64 px, spectate cycling on touch = tap
   left/right half, EndCard buttons scale-relative.

Parity: KenopsiaClient 115093/1879147719, PS1Animate 11753/1323822254, UiFx 29148/146182049.
ForcePlatform cleared after the test. All 10 suites green.

Open (needs the user's phone): aim assist feel (strength tuning lives in the two per-second numbers),
MicroProfiler, real touch drag vs. the assist.

## Round 2 (user's iPhone-14 emulator screenshot)

- Canteen PLATE/MOUTH: 110 px mid-screen slabs → 84 px pinned into the bottom CORNERS (left thumb
  PLATE, right thumb MOUTH).
- All trial touch buttons smaller and SPREAD (place instances): FIRE/PUNCH 88 px bottom-right,
  SCOPE/CROUCH/SCAN/EAT 68 px moved LEFT of the primary instead of stacked, ZOOM 60 px above.
- DANCE button is LOBBY-ONLY now (hides the moment a trial starts).
- Fork: one stab per second (server MIN_PLATE_INTERVAL 0.16 → 1.0, client cooldown matched) — the
  stab clip gets room to read.
- Aim assist "bisschen staerker": ease 7/4.5 → 9.5/6.5 per second, scoped cone 5° → 6°.

Next up per the user: console pass, then iPad.

## Round 3 — console + tablet look (ForcePlatform, live)

- **Console focus bug fixed**: at join READY is briefly `Selectable=false` (no roster yet), so the
  first `focusScreen` fell through to the engine pick (SETTINGS / the pager arrow) and stayed there.
  MachineLayout now reclaims the focus onto READY when it becomes selectable AND 0.3 s after the Info
  screen shows (losing the race to focusScreen on purpose). Live: selection lands on Btn_READY,
  phosphor ring + Ⓐ glyph (capture).
- Console capture otherwise clean: gamepad glyphs in the controls (stick icon, HOLD Ⓨ), 22 px text
  floor, SYS cells bottom-left without collisions.
- Tablet capture clean at scale 1; "STICK Move / HOLD SCAN" is the correct Touch wording (on-screen
  joystick), not a glyph bug.
- ForcePlatform cleared after the tests.

Still needs a real gamepad (user): d-pad walk Info → Settings → Briefing without leaving a panel.

## Round 4 — the win that never fired, camera, stick, fork catch

- **DZ exit fixed**: reaching the gate did NOTHING — the win hung on `Exit.Touched`, and standing in
  the gate left the runner ~0.5 studs before the part's plane. The escape is now a LINE CHECK in the
  20 Hz loop with 1.5 studs of grace (standing in the gate wins), plus the "SECTOR CLEARED." card,
  1.2 s later the black-beat spectate, and the round-end blackout. Verified live: teleport across the
  line → SECTOR CLEARED at 6.9 s → spectate at 8.1 s → round over (and the crush counter finally
  showed live numbers: crushed=49).
- **Bird Hunting camera** a touch further down (look target Y 3 → −1).
- **Default touch joystick** only where movement IS the game: `GuiService.TouchControlsEnabled`
  follows `moveState == "runner"` (DZ + BH runners); lobby, canteen seats and the sniper post drop it.
- **Canteen**: the observer now catches the FORK too — any plate action during `watching` is
  `eliminate(..., "seen")`, not just the swallow.
