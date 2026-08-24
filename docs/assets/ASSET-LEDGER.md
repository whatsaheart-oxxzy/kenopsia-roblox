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

### Pizza Doggy's Game Assets — License Agreement (PDF) — covers **four** packs

Terms: game use ✅ (commercial ok) · modification ✅ · standalone redistribution
❌ · inclusion in asset packs, templates or bundles ❌ · attribution optional ·
other digital media = ask first.

| PDF copy | Pack licensed | Provenance |
|---|---|---|
| `Retro\Game Asset License Agreement.pdf` (root) | **PSX Textures II** | `Downloads\PSX Textures II v1.6.zip` — 327.8 MB, 2026-08-06, present on disk |
| `Retro\PSX Tech\...` | PSX Tech | in-folder |
| `Retro\ROT - Horror Audio Bundle\...` | ROT — Horror Audio Bundle | in-folder |
| `Retro\Rust & Blood - SFX Library\...` | Rust & Blood — SFX Library | in-folder |

The root copy is **not orphaned** — it belongs to PSX Textures II. An earlier
revision of this ledger described the coverage as "three packs" by treating the
root copy as unattributed. Corrected.

### The CC0 notice — what it actually covered

| Instrument | Status |
|---|---|
| `Retro\NOTES.txt` (CC0 1.0 Universal) | **Not currently present**, and it never covered the packs in use |

Two distinct facts, both required for the record:

1. `NOTES.txt` is absent — not at the Retro root, not within four levels below
   it, and no `.txt` exists at the Retro root at all.
2. Earlier investigation associated that CC0 notice **only with
   `LowPolyAssetPack_Free.zip`** — a free sample pack — and **never with the
   arena packs this game ships**. Corroborated: `Downloads\LowPolyAssetPack_Free.zip`
   (34.8 MB, 2026-08-06) is present, with `Retro\Example Scenes\LowPoly_Scenes_Free.blend`
   as its unpacked remnant.

The defect in `docs/legacy/ASSETS.md` was therefore **generalising a free sample
pack's licence across a commercial library** — not a bare falsehood. That
generalisation is void: CC0 permits redistribution, Pizza Doggy forbids it, so
applying CC0 library-wide would licence-launder packs that explicitly forbid it.

**Coverage gap:** roughly 29 further pack folders under `Retro\` carry no licence
file. They are plausibly Pizza Doggy purchases — the folders
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

> **STALE — regeneration pending (P0.5, 2026-08-23).** `audio-inventory.csv` lists 39 Sounds
> (generated 2026-08-21). Measured on 2026-08-22 the place held **34** (`Music.Loop` and
> `SFX.AccessGranted` were gone, among others — `docs/research/2026-08-22-sweep/07`); P0.3 then
> re-created `Music.Loop`, `SFX.AccessGranted` (clone of `Confirm`) and added
> `Music.Trials.canteen` (clone of `minefield`), and raised `birdhunt` 0.24 → 0.40
> (`docs/QA/2026-08-22-framework-smoke.md`). The CSV is regenerated from Studio, not by hand;
> until then treat its rows as the 21.08. snapshot.

Machine-generated from the live place. Full table:
`docs/assets/audio-inventory.csv`. 39 instances, 37 distinct asset ids
(`Click`/`Hover` share one; `Reject`/`AccessDenied` share one).

Every row below: **author/shop** = presumed Pizza Doggy audio packs
(`ROT - Horror Audio Bundle`, `Rust & Blood - SFX Library`,
`Echoes - Audio Super Kit`, `System Status Alerts & Misc`,
`Super Retro Game OST`, `Special Ambiences`) — **INF** until each upload is
traced back to its source file. **Permitted edit** ✅ and **permitted game use**
✅ under the Pizza Doggy terms for the four proven packs.
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

### Weapon audio — ids and volumes both frozen

| Path | Asset id | **Authoritative volume** | Licence |
|---|---|---:|---|
| `SFX.SniperFire.Primary` | `118803023612410` | **1.45** | INF |
| `SFX.SniperReload.Primary` | `83110281478101` | **1.70** | INF |
| `SFX.BulletRicochet.Primary` | `83668417079973` | **1.10** | INF |

Ids match plan §3 exactly. The volumes deliberately **do not** — the reviewer
ruled that the live values stand and the plan's 0.95 / 0.75 / 0.80 are not
applied, because the plan's real test is relative (*"deutlich lauter als Musik"*)
and these already pass it against music at 0.24–0.45. Existing music ducking
unchanged. **Gate 3 may alter these only after a real listening test, and only to
correct audible clipping.** See `GATE0-BASELINE.md` §5.

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

## 3b. `DEV_ONLY` — Kenopsia_DEV rig appearance

Place `129909297895850`. Flagged per Gate M1 §1.5. These are catalog or
user-created appearance assets on `Workspace.Rig` with **no ownership or licence
record in this project**.

| Instance | Class | Status |
|---|---|---|
| `Accessory (NERD)` | Accessory | **DEV_ONLY** |
| `Accessory (CAT in head)` | Accessory | **DEV_ONLY** |
| `Accessory (Soulers Keychain)` | Accessory | **DEV_ONLY** |
| `Accessory (Meshes/PENDIENTESMIASMA)` | Accessory | **DEV_ONLY** |
| `whitehairaccessory` | Accessory | **DEV_ONLY** |
| `Accessory (Cabello NOVA)` | Accessory | **DEV_ONLY** |
| `Shirt` | Shirt | **DEV_ONLY** |
| `Pants` | Pants | **DEV_ONLY** |

**Rule:** acceptable inside `Kenopsia_DEV` while that place is limited to the
same universe. **Before any public release**, ownership must be evidenced or the
parts replaced. `Shirt` and `Pants` are included deliberately — Gate M1 §1.5
named only accessories, but clothing carries identical exposure.

This block is expected to be retired wholesale by the Gate 5 original character,
in the same way the XBot `KeyframeSequence` block is.

---

## 3c. Main-menu images — original work, no blocker

Six PNGs generated by `tools/menu-assets.py` (25.08.2026) and uploaded to the group.
Source files live beside this ledger. **Own work, generated from geometry and noise in that
script**: the KENOPSIA wordmark is drawn from rectangles and offset parallelograms defined in the
file — **no font file is read, embedded or shipped**, so no foundry licence is involved. The two
background plates are rebuilds of the reference images the user supplied, in the game's own cold
palette, not copies of them.

| Asset | Source file | Authored size | Asset id | Status |
|---|---|---|---|---|
| Menu wordmark | `menu_wordmark_512.png` | 512×97 | `88647754582283` | OK — own work |
| Selection streak | `menu_streak_256.png` | 256×32 | `134334042347021` | OK — own work |
| Debris shards | `menu_shards_512.png` | 512×384 | `120005853529594` | OK — own work |
| Rain/static plate | `menu_rain_256.png` | 256×256 | `105106540934647` | OK — own work |
| Dot matrix | `menu_dots_128.png` | 128×128 | `85128683768553` | OK — own work |
| Menu background | `menu_bg_960.png` | 960×540 | `99925228392956` | OK — own work |

Ids uploaded 25.08.2026 and written into `Shared/Config/MenuConfig.luau` (`Menu.Images`).
An empty id would render nothing rather than erroring, so the menu boots either way. Same provenance class as the grid tiles
(`grid_black_256`, `grid_soft_256`), the Bayer dither tiles and `ps1_sky_128`.

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
| 1 | ~29 packs with no archived licence terms | 7 | Archive dated store records, or drop the affected assets |
| 2 | Bird trial music `71143122243344` | 3 / 7 | Prove or replace |
| 3 | Sniper rifle model provenance | 3 / 7 | Prove, or rebuild as an original low-poly primitive weapon |
| 4 | 12 XBot `KeyframeSequence`s | 5 / 7 | Likely dissolved by the original character; otherwise prove |
| 5 | No Canteen audio or models exist | 4 | Create or licence original assets (`REQ-CP-04`) |
| 6 | Universe permission untested for every uploaded id | 7 | Verify in a published DEV session — private audio fails silently |
| ~~7~~ | ~~Sniper volumes conflict~~ | — | **RESOLVED at Gate 0** — live values 1.45 / 1.70 / 1.10 are authoritative; plan §3's lower numbers are not applied |

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
