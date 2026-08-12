# Asset and licence ledger

Authoritative for all licensing questions. **Supersedes `docs/legacy/ASSETS.md`**,
whose CC0 claim is void — see `docs/baseline/GATE0-BASELINE.md` §4.

Seeded at Gate 0. Must be **fully green before Gate 7 release**.

Columns are the eight required by plan §4:
asset id · source file · author/shop · licence proof · permitted edit ·
permitted game use · universe permission · load status.

Status legend: **OK** proven · **INF** inferred, needs a dated store record ·
**BLOCK** release blocker · **N/A** not applicable.

---

## 1. Licence instruments on file

| Instrument | Location | Covers | Terms |
|---|---|---|---|
| Pizza Doggy's Game Assets — License Agreement (PDF) | `Retro\` (root), `Retro\PSX Tech\`, `Retro\ROT - Horror Audio Bundle\`, `Retro\Rust & Blood - SFX Library\` | those three packs, explicitly | game use ✅ (commercial ok) · modification ✅ · standalone redistribution ❌ · inclusion in asset packs/bundles ❌ · attribution optional · other digital media = ask |
| ~~`Retro\NOTES.txt` (CC0 1.0)~~ | — | — | **DOES NOT EXIST.** Claim void. Never cite it. |

**Coverage gap:** roughly 30 further pack folders under `Retro\` carry no licence
file. They are plausibly Pizza Doggy purchases — the folder
`Pizza Doggy's Item Icons Making Setup` and
`Item Icons - PSX Mega Pack, PSX Bunkers` tie that vendor to the PSX Mega Pack
and PSX Bunkers lines — but **inference is not proof**. Each needs a dated copy
of its store terms archived before Gate 7.

**Standing constraint that follows from these terms:** Kenopsia may ship these
assets inside the game. It may **not** publish them as a Roblox model, a toolbox
asset, an open-sourced place file, or any other form where the asset travels on
its own. This applies even to modified versions.

---

## 2. Audio — 39 Sounds, all populated

Machine-generated from the live place. Full table:
`docs/assets/audio-inventory.csv`. 39 instances, 37 distinct asset ids
(`Click`/`Hover` share one; `Reject`/`AccessDenied` share one).

Every row below: **author/shop** = presumed Pizza Doggy audio packs
(`ROT - Horror Audio Bundle`, `Rust & Blood - SFX Library`,
`Echoes - Audio Super Kit`, `System Status Alerts & Misc`,
`Super Retro Game OST`, `Special Ambiences`) — **INF** until each upload is
traced back to its source file. **Permitted edit** ✅ and **permitted game use**
✅ under the Pizza Doggy terms for the three proven packs.
**Universe permission** must be confirmed per id (uploaded audio defaults to
private and plays silently with no error if the experience lacks permission) —
**untested, Gate 7**.

### Music

| Path | Asset id | Volume | Licence | Notes |
|---|---|---:|---|---|
| `Music.Intro` | `117311429031651` | 0.35 | INF | |
| `Music.Loop` | `136345765095808` | 0.35 | INF | |
| `Music.Outro` | `77820284893951` | 0.35 | INF | |
| `Music.Trials.birdhunt` | `71143122243344` | 0.24 | **BLOCK** | `REQ-IP-02` names Bird music as unresolved. Prove or replace. |
| `Music.Trials.minefield` | `132499516846518` | 0.45 | INF | |
| `Music.Trials.canteen` | — | — | **BLOCK** | Does not exist. `REQ-CP-04`. |

`Ambience` folder exists and is **empty**.

### Weapon audio — ids pinned by plan §3

| Path | Asset id | Plan volume | **Live volume** | Licence |
|---|---|---:|---:|---|
| `SFX.SniperFire.Primary` | `118803023612410` | 0.95 | **1.45** | INF |
| `SFX.SniperReload.Primary` | `83110281478101` | 0.75 | **1.70** | INF |
| `SFX.BulletRicochet.Primary` | `83668417079973` | 0.80 | **1.10** | INF |

Ids match the plan exactly; **volumes do not**. Unresolved conflict between the
Phase 1 preserve-volumes constraint and plan §3 — see
`GATE0-BASELINE.md` §5. Decide before Gate 3.

### UI and impact SFX

| Path | Asset id | Vol | Path | Asset id | Vol |
|---|---|---:|---|---|---:|
| `SFX.Click` | `71275573444924` | 0.45 | `SFX.Count5` | `117149096126658` | 0.75 |
| `SFX.ClickAlt` | `132164304600477` | 0.45 | `SFX.Count4` | `88984010858075` | 0.75 |
| `SFX.Submit` | `78750521109999` | 0.55 | `SFX.Count3` | `125929365204512` | 0.75 |
| `SFX.SubmitAlt` | `105043211211780` | 0.55 | `SFX.Count2` | `90490572986710` | 0.75 |
| `SFX.Reject` | `114448879961050` | 0.70 | `SFX.Count1` | `132909621965246` | 0.75 |
| `SFX.Hover` | `71275573444924` | 0.16 | `SFX.ImpactBody` | `83335185987012` | 0.90 |
| `SFX.AccessDenied` | `114448879961050` | 0.70 | `SFX.Warning` | `93861370808858` | 0.65 |
| `SFX.AccessGranted` | `81955326079132` | 0.70 | `SFX.Confirm` | `130292722664147` | 0.60 |
| `SFX.StandClear` | `127661892376075` | 0.70 | | | |

### Variant pools

| Pool | Asset ids | Vol |
|---|---|---:|
| `SFX.Clicks.Click1..5` | `136898832673181`, `136745293101522`, `115728252091834`, `111557351602976`, `132683279963887` | 0.60 |
| `SFX.Submits.Submit1..3` | `79171960825561`, `111991322032307`, `109725832591895` | 0.60 |
| `SFX.MineExplosions.Explode1..4` | `86475991650982`, `76737678985387`, `71471343684752`, `75789945781051` | 0.90 |
| `SFX.Blood.Blood1..2` | `127560368697616`, `86853838840785` | 0.85 |

---

## 3. Animation — XBot rig

`ReplicatedStorage.XBotAnimations` holds 12 `KeyframeSequence`s. `SequencePlayer`
resolves them **by name**, not by asset id, so `PublishedIds` is **not on the
runtime path**.

| Name in `PublishedIds` | Asset id | Status |
|---|---|---|
| `Idle` | `85677606246468` | **BLOCK** |
| `Walk` | `120444870216482` | **BLOCK** |
| `Run` | `122795638856363` | **BLOCK** |
| `CrouchWalk` | `113663200701243` | **BLOCK** |
| `Jump` | `72948522195534` | **BLOCK** |
| `Punch` | `113738141694741` | **BLOCK** |
| `SweepFall` | `124407808671429` | **BLOCK** |
| `StandUp` | `75643901941236` | **BLOCK** |
| `Sit` | `131818913727408` | **BLOCK** |
| `SniperAim` | `77238131923469` | **BLOCK** |
| `InjuredWalk` | *(absent from `PublishedIds`)* | **BLOCK** |
| `ZombieCrawl` | *(absent from `PublishedIds`)* | **BLOCK** |

`REQ-IP-02`. Presumed source: `Retro\Female (X Bot) Animation\` and
`Retro\Male (Y Bot) Animation\` — Mixamo-derived. Mixamo's terms permit use in
projects but the provenance chain is undocumented here.

**Gate 5 may retire this entire block.** The plan commits to an original Blender
character with retargeted animations; if the new rig ships with original or
separately-licensed motion, these twelve ids leave the shipping surface and the
blocker dissolves rather than needing to be proven.

Source rigs `Sneak Walk`, `Injured Walking` and `Zombie Crawl` are still sitting
loose in the live `Workspace` — remove before release.

---

## 4. Models, meshes and textures — not yet enumerated

| Asset | Where | Status |
|---|---|---|
| `ReplicatedStorage.KenopsiaAssets.SniperRifle` (Model) | first-person + world weapon | **BLOCK** — `REQ-IP-02` names it unresolved. Plan §4 requires it rebuilt as an original low-poly primitive weapon if provenance fails. |
| `MF_Crater`, `MF_Mine`, `MF_SonarRing` | `ServerStorage.KenopsiaAssets.Props.Minefield`, `ReplicatedStorage.KenopsiaAssets` | INF — `MF_Mine` is unused; `Minefield` builds mines inline. |
| `Workspace["Bird Hunting"]` — 234 children | PSX props: `Stone 1` ×66, `fence_e_2` ×25, `Metal_crate` ×23, walls, trees, towers | INF |
| `Workspace["Dead Zone"]` — 150 children | PSX props: `fence_e_2_Node` ×61, `fence_e_pillar_1_Node` ×32, barricades, tree stumps, water towers | INF |
| `Workspace.CanteenProtocol` — 78 children | canteen furniture, food props, lamps, walls | INF |
| `Lighting.KenopsiaSky` (Sky) | 6 face textures | INF — likely `Brutal Skyboxes` |
| `StarterPlayer.StarterCharacter` | XBot rig, `Beta_Joints` skinned mesh | **BLOCK** — superseded at Gate 5 |

Per-instance `MeshId` / `TextureId` enumeration is a **Gate 7** completeness task,
not a Gate 0 one. The read path is established and cheap:
`POST /execute` with `manage_properties_get`, looped from a script.

---

## 5. Blockers, consolidated

| # | Blocker | Gate | Resolution path |
|---|---|---|---|
| 1 | ~30 packs with no archived licence terms | 7 | Archive dated store records, or drop the affected assets |
| 2 | Bird trial music `71143122243344` | 3 / 7 | Prove or replace |
| 3 | Sniper rifle model provenance | 3 / 7 | Prove, or rebuild as an original low-poly primitive weapon |
| 4 | 12 XBot `KeyframeSequence`s | 5 / 7 | Likely dissolved by the original character; otherwise prove |
| 5 | No Canteen audio or models exist | 4 | Create or licence original assets (`REQ-CP-04`) |
| 6 | Universe permission untested for every uploaded id | 7 | Verify in a published DEV session — private audio fails silently |
| 7 | Sniper volumes: plan says 0.95/0.75/0.80, live is 1.45/1.70/1.10 | 3 | Reviewer decision required |

---

## 6. Hard rules

- No file from Machine Party is extracted, uploaded, or referenced. Only
  observable game rules and pacing were taken; names, lore, characters, UI,
  meshes, textures, sounds and music are original or separately licensed.
- Licensed assets ship **inside the game only** — never redistributed standalone,
  modified or not, and never inside an asset pack, template or bundle.
- Renaming an asset does not change its licence. Plan §5 forbids masking
  copyright risk behind a rename.
- Roblox Terms of Use and moderation rules bind regardless of what a vendor
  licence permits.
