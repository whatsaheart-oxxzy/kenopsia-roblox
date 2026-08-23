# QA — three-trial polish after the user's 2-player test (23.08.2026)

User feedback → change → live check. Built by three parallel agents (Minefield / character clips +
Bird Hunting / Canteen) plus a gate reviewer; place-side markers and the final pushes by hand.

| Feedback | Change | Live check |
|---|---|---|
| Canteen camera too far and too low | `Rig.ObserverCamera` (+ `Camera for Canteen`) moved from 14 studs off the table at 12.75 to 13 studs at 15.0 (under the 15.66 ceiling), pitch 22° onto the table centre. The per-seat `PlayerCameras` were also re-aimed (over the right shoulder, 9.8 up) but the diners' view is the table camera. | capture: table fills the frame, boss at the head, 20 peas per plate |
| Peas sit too high | `PlateAnchors` −0.2 studs | pea centres 8.92 vs plate top 8.86 — on the plate |
| Canteen too fast, no tension, boss predictable | `Pacing.RoundSeconds.canteen` 45 → 60; `PEAS_TOTAL` 16 → 20 (`PEA_STEP` 50 → 40 to keep the band maths); boss hidden 2.5–9.0 s (was 2–4) from the seeded rng, **fake-outs** (p 0.3, 1.0–1.8 s, never twice in a row), watch window ramps 0.9–1.8 → 1.4–2.6 s over the round; lowering telegraph untouched | `[CP] go … peas=20`, `round over, elapsed=60.1` |
| **Bug found on the way:** from round 2 on the canteen was silently skipped ("arena invalid: P1 camera cannot see its plate - blocked by Head/Torso") | `validateArena` rays now ignore player characters and `CP_Props` — the parked, invisible avatars carry hit boxes since P3.3 | rounds 2+ run |
| Dead Zone players and mines too small | `GameConfig.Character.Scale` 0.69 → 0.9 (7.8 studs); sonar mine marks 1.6 → 2.56 studs (client `acquireMark`) | spawn scale 0.90 |
| Shredder must not detonate mines (blood on every screen) | mines the compactor front passes are CRUSHED: `live=false`, no explode/gore/sound/crater; armed (runner-triggered) mines still detonate and chain; round-over line prints `crushed=n` | `crushed=0` solo (runner died first) — code path reviewed |
| Shredder a bit slower | `Pacing.RoundSeconds.minefield` 55 → 62 → sweep 6.50 → 5.72 studs/s | `[DZ] … sweep 300 @ 5.72/s -> 62.0 s round; runner margin +20.1 s` |
| New clips: field death, crawl, injured walk | `AnimationIds.Player.DeathField/Crawl/InjuredWalk = 0` + `StudioSequences` ("Sweep Fall" / "Zombie Crawl" / "Injured Walking", sequence "mixamo.com"); **Studio bridge**: the server registers the saved sequences at warmup and publishes `StudioAnim_Player_<Name>` attributes on `ReplicatedStorage.Kenopsia`, the client's `AnimationIds.load` reads them when the published id is 0 | client loads Crawl 3.77 s, InjuredWalk 1.73 s, DeathField 1.73 s in Studio |
| Crawl after a mine knock | `Minefield`: `CRAWL_SPEED = 4.2` applied when `XBotCrawl` latches, restored at cleanup; `PS1Animate` plays Crawl while `XBotCrawl` | not reachable solo (direct step = kill); attribute path reviewed |
| Injured walking after a body shot | `BirdHunting`: `INJURED_SPEED = 7`, `Injured` attribute set on a non-lethal body shot, cleared at placement/teardown, never restored to 14 mid-leg; `PS1Animate` plays InjuredWalk while `Injured` and moving | needs a hunter + runner (2 players) |
| Field death clip | `PS1Animate` Died → `DeathField` (fallback `Death`) | runner killed by a mine: `Player/DeathField` playing |
| 4th minigame not wanted before release | `MachineFlow.TRIALS.sorting.ready = false` (code stays) | `1/15 … 3/15 trials ready` |

Offline gates: rules 84, trialrules 37, animationids 35, contexts 21, envelope 27, sorting 34 — all green; selene clean on every changed file (pre-existing warnings only). Parity verified for all 9 pushed scripts.

## Needs the user

* Publish the three clips under the group (like the others) and paste the ids → `AnimationIds.Player.DeathField / Crawl / InjuredWalk`. Until then they play in Studio only.
* 2-player: Bird Hunting injured walk + speed 7, Dead Zone crawl + crush (`crushed=n` in the log), canteen fake-outs in play.
