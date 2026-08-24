# QA — 24.08. death & spectate rework (user test feedback round 3)

1. **"Animation comes back alive after death"** — a finished one-shot track releases the rig back to
   its bind pose. PS1Animate now freezes the death clip a breath before its final keyframe
   (`AdjustSpeed(0)`), so the body STAYS down; the canteen execution picks the TABLE death (Blender
   `Death` clip) and every field trial the Mixamo `DeathField` — chosen by `KenopsiaActiveTrial`.
2. **DZ two-stage mines** — the FIRST mine (direct step included, armed or not) takes the lower half:
   crawl + maim + "LEGS GONE. CRAWL." The SECOND mine kills and the body is GONE — `BloodFX.shatter`
   now hides every MeshPart of the PS1 rig (it only knew the X-Bot-era `Beta_Joints`). Live solo:
   first hit at 12 s → crawl=true legless=true alive; second hit → dead.
3. **Bird Hunting death** — no more corpse fling: the runner's own Humanoid dies where they stand,
   DeathField plays and freezes. A spectate packet follows 2 s later whose watch list contains the
   LIVING RUNNERS ONLY — the sniper is never watchable (user rule).
4. **Viewer mode** — death → 0.6 s BLACK BEAT (the camera switches under it) → follow-cam on the
   watched survivor; with 2+ survivors Q / E (gamepad LB/RB, touch: left/right half) cycles, and a
   phosphor caption names the watched subject ("VIEWER MODE - NAME  [Q/E]"). Caption self-hides with
   the mode. Solo the watch list is empty by design — 2-player check pending.
5. **Rifle light** — the viewmodel lamp went 0.85/9 cool → 2.2/11 warm (255,234,196), shadows off.

Parity: Minefield 42021/533725034, BirdHunting 38065/1277805426, PS1Animate 11606/1479660664,
KenopsiaClient 113667/1040742815 (178 locals), BloodFX 7228/604345882. TrialIds restored; all 10
suites green.

2-player checklist: viewer cycling + caption, BH spectate excludes the sniper, death freeze seen from
the second screen, table death in the canteen.
