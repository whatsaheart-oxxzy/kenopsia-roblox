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
