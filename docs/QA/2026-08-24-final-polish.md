# QA — 24.08. final polish (user test feedback round 2)

1. **"Not smooth / glitch in minigames"** — root cause: the 30 Hz camera hold from PS1 pass 2 read
   as stutter, not retro. REMOVED same day (SimulationGrade publishes 0; client hold code deleted).
   The 6 px position quantisation stays (it was in the build the user previously approved).
2. **"T cross for a moment when I load in / press W"** — the gait clips were fetched lazily: the
   first Walk of a life pulled the asset from the CDN while the rig stood in bind pose. PS1Animate
   now warms every clip on spawn and puts Idle on with Play(0); live: Idle is playing the moment the
   lobby shows.
3. **DZ camera further out** — eye 15 up / 18 behind, same 35°.
4. **Terminal UI (Idea.jpg)** — the user's two grid backgrounds rebuilt as 256 px tiles (uploaded:
   soft 80856993711380, black 139301976639622) and layered under Info/Selection/Status/Score/
   Briefing; every screen gets terminal chrome: USER line + index box, corner ticks, a function-key
   strip, and (Info) a row of boxed SYS status cells. All static instances, ZIndex under the content,
   built once at boot. Capture: the Info screen reads like the reference.

Parity: PS1Animate 11129/1638933967, SimulationGrade 10523/1025850537, UiFx 29033/1512549261,
KenopsiaClient 111186/2117896176 (178 locals). Suites green.
