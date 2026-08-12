# Gate 0 — baseline and protection

Execution contract: `C:\Users\Asus\Documents\Retro\Kenopsia Plan.md`
(the three-minigame release plan). This supersedes the earlier
`Step by Step Plan.md`, which remains on disk as history.

Read-only gate. No instance and no script in the place was created, modified or
destroyed while producing this record.

---

## 1. Provenance

| Item | Value |
|---|---|
| HEAD **at Gate 0 start** | `9637fcc5c1f0e98af49c05ad38936a2bae4678c0` — *"Record transfer 2: C1-fix + C3-C6 live, 5/5 SHA parity green"* |
| HEAD **after Gate 0** | `65b8bc2` — *"Gate 0: baseline, asset ledger, REQ re-map onto the new plan"* |
| **Gate 1 precheck baseline** | **`65b8bc2`** — use this, not `9637fcc` |
| Working tree | **clean** (`git status --porcelain` empty) |

`9637fcc` → `65b8bc2` adds documentation only. **No file under `studio-src`
changed between them**, so the 19/19 parity recorded in §3 remains valid at
`65b8bc2` without re-running it.

| Place id | `110672791536316` |
| Universe role | **KenopsiaMainGame** (the shipping place) |
| Studio version | `0.734.0.7340915` |
| Studio state | **edit** (`studioStateSource: runService`) |
| WEPPY plugin | `2.12.3`, clientId `80aa43c2-eb9e-4b46-bdcf-3bf1accb5804`, alias `studio-1` |
| WEPPY server | `2.12.3`, pid `16004`, `127.0.0.1:3002` |
| Connected plugin clients | **1** |
| Connected MCP instances | **1** (`Claude Code`) — no competing writer |
| Licence tier | Basic (`execute_luau`, `workspace_state`, `manage_sync`, `place_info`, all `manage_studio` play actions and `*_mass_*` remain PRO-gated) |

`placeName` is reported as `Place2`. It has previously reported `Place1`. The
place **name** is not a reliable identifier here; `placeId` is, and every call in
this gate was pinned to it and verified against `routing.actualPlaceId`.

---

## 2. Target place — `Kenopsia_DEV` required (corrected)

Plan §5 rules 7–8 require gate work in a `Kenopsia_DEV` place limited to the same
universe, with the verified commit promoted to `KenopsiaMainGame` only after all
gates pass.

### Correction of record

An earlier revision of this document stated that working directly in
KenopsiaMainGame was *"Authorised by the reviewer."* **That claim was wrong and
is withdrawn.** No such authorisation was given. It was inferred from a planning
answer and should never have been written as an authorisation — an inference is
not a grant, and recording it as one put a false permission into the project's
own audit trail. The reviewer has since stated the requirement explicitly:

> Die angebliche Freigabe, direkt in KenopsiaMainGame zu arbeiten, wurde von mir
> nicht erteilt. Unser Plan verlangt Kenopsia_DEV.

### Standing rule

**All gate work from Gate 1 onward happens in `Kenopsia_DEV`.**
`KenopsiaMainGame` (`110672791536316`) stays untouched until release. It is not
written to, and it is not published, until the verified commit is promoted at
Gate 7.

Gate 0 itself was executed against `110672791536316`. That is acceptable *only*
because Gate 0 was **strictly read-only** — the parity check, property reads and
manifest queries created, modified and destroyed nothing. No mutation of
MainGame has occurred at any point under the new plan.

### Blocking precondition for Gate 1

Gate 1 cannot start until all four are true:

1. The `Kenopsia_DEV` placeId is known and confirmed.
2. It is open in Studio in Edit mode and visible as a plugin client.
3. Its permission is **"Limited to same Universe."**
4. Its content is verified against the MainGame manifest — the trial arenas
   (`Dead Zone` 150 children, `Bird Hunting` 234, `CanteenProtocol` 78), the
   `KenopsiaMachine` ScreenGui, `SoundService.KenopsiaAudio` (39 Sounds), the
   XBot rig and `ReplicatedStorage.KenopsiaAssets`. A DEV place missing the
   arenas cannot host a meaningful Gate 1, and `Minefield.refs()` /
   `BirdHunting.refs()` would return `nil` and skip every round.

If DEV content is stale or absent, a content migration is its own step and is
sequenced **before** Gate 1, not inside it.

### Consequence for test scaffolding — unchanged

No test-only trial, stub minigame or dev-harness script is created or committed.
The reviewer's earlier instruction was scoped to MainGame, and a DEV place would
in principle permit a stub — but the Gate 1 design does not need one. The
MachineFlow loop iterates `#order` trials rather than a hardcoded three, so it
runs two ready trials now and three at Gate 4 with no code change, and the
orchestration proof runs offline against the pure rules modules. The no-stub
design therefore stands on its own merits, not on the withdrawn deviation.

---

## 3. Source-of-truth parity — 19/19 green

`studio-src` is the sole source of truth. Every file was read back from the live
place and compared byte-for-byte by SHA-256.

| # | File | SHA-256 (first 16) | Result |
|---:|---|---|---|
| 1 | `ReplicatedFirst/KenopsiaLoading.client.luau` | `0449E5B27F779B4C` | MATCH |
| 2 | `ReplicatedStorage/Kenopsia/Shared/Config/GameConfig.luau` | `CD2F474B01661D98` | MATCH |
| 3 | `ReplicatedStorage/KenopsiaAssets/Effects/Blood/BloodEffect.luau` | `2503B895CB12EB5B` | MATCH |
| 4 | `ReplicatedStorage/XBotAnimations/PublishedIds.luau` | `4AF49F15606570FE` | MATCH |
| 5 | `ReplicatedStorage/XBotAnimations/SequencePlayer.luau` | `4ADFBCFB70BB3F68` | MATCH |
| 6 | `ServerScriptService/KenopsiaServer/Main.server.luau` | `EC2F0F78D002CE5F` | MATCH |
| 7 | `.../Services/BirdHunting.luau` | `4676A31DA9D4AC00` | MATCH |
| 8 | `.../Services/BloodFX.luau` | `ABC8309F4E028F93` | MATCH |
| 9 | `.../Services/MachineFlow.luau` | `9A94A0A79043C3C7` | MATCH |
| 10 | `.../Services/Minefield.luau` | `AE7C1865D2BBCA52` | MATCH |
| 11 | `.../Services/RoomService.luau` | `8D14D4BB2009116B` | MATCH |
| 12 | `.../Services/TableManners.luau` | `F202553F9EB616D6` | MATCH |
| 13 | `ServerScriptService/KenopsiaServer/XBotCharacters.server.luau` | `BA23E6A48ED18931` | MATCH |
| 14 | `StarterPlayer/StarterCharacter/Animate.client.luau` | `1CF831BF6B65D5C4` | MATCH |
| 15 | `StarterPlayer/StarterCharacterScripts/Health.server.luau` | `A2FA2DACEBE757A5` | MATCH |
| 16 | `StarterPlayer/StarterPlayerScripts/GoreClient.client.luau` | `7DB8AA8A03DCB4BB` | MATCH |
| 17 | `StarterPlayer/StarterPlayerScripts/KenopsiaClient.client.luau` | `E4FA32CCD8701809` | MATCH |
| 18 | `StarterPlayer/StarterPlayerScripts/MachineLayout.client.luau` | `21E5959F6916D877` | MATCH |
| 19 | `StarterPlayer/StarterPlayerScripts/XBotAnimSync.client.luau` | `309609CB2BCB5947` | MATCH |

**PARITY: 19 match / 0 fail.**

### Verification method (new, and better)

The WEPPY server exposes a local HTTP endpoint that the MCP tool layer sits on
top of:

```
POST http://127.0.0.1:3002/execute
{ "command": "<tool>_<action>", "params": { ... }, "requestId": "<required>" }
```

`requestId` is **mandatory** — omitting it returns a truncated response with
`success` unset, which is silently indistinguishable from a read failure.

Reading through this endpoint from a script means script bodies never pass
through the agent's context, so parity checks are:

- **cheap** — all 19 files in one pass instead of ~300 KB of transcription;
- **typo-proof** — no re-emission step, therefore no transcription-induced false
  mismatch, which was the dominant failure risk in the manual method.

Adopt this for every future gate's post-transfer readback. `routing.actualPlaceId`
must still be asserted `== 110672791536316` on every call.

---

## 4. Licence position

The single licence document in the asset library is
`Documents\Retro\Game Asset License Agreement.pdf` — **Pizza Doggy's Game Assets**:

| Clause | Effect |
|---|---|
| Use in any game, commercial or not | **permitted** |
| Edit or modify however you like | **permitted** |
| Other digital media | ask first |
| Resell / redistribute / share the assets on their own, even edited | **forbidden** |
| Include in asset packs, templates or bundles | **forbidden** |
| Attribution | appreciated, not required |

This matches the plan's requirement exactly: usable in the game, not
redistributable as an asset pack.

**Coverage is partial — four packs, not three** (corrected). The PDF exists in
four locations, and the root copy is not orphaned: its provenance ties it to
`PSX Textures II v1.6.zip`, so it carries that pack too.

| PDF location | Pack it licenses |
|---|---|
| `Retro\Game Asset License Agreement.pdf` (root) | **PSX Textures II** — via `Downloads\PSX Textures II v1.6.zip` |
| `Retro\PSX Tech\...` | PSX Tech |
| `Retro\ROT - Horror Audio Bundle\...` | ROT — Horror Audio Bundle |
| `Retro\Rust & Blood - SFX Library\...` | Rust & Blood — SFX Library |

Corroborated on disk: `Downloads\PSX Textures II v1.6.zip` (327.8 MB, dated
2026-08-06) is present.

The remaining ~29 pack folders carry **no licence file at all**.

### The CC0 claim — precise correction

`docs/legacy/ASSETS.md:202` states:

> `Documents\Retro\NOTES.txt` declares **CC0 1.0 Universal** — free for
> commercial use, no attribution required.

Two separate defects, stated precisely:

1. **`NOTES.txt` is not currently present.** Not at the Retro root, not anywhere
   within four levels below it; no `.txt` file exists at the Retro root at all.
2. **Even when it existed, it did not cover the packs in use.** Earlier
   investigation associated that CC0 notice **only with
   `LowPolyAssetPack_Free.zip`** — never with the arena packs this game actually
   ships. Corroborated on disk: `Downloads\LowPolyAssetPack_Free.zip` (34.8 MB,
   2026-08-06) is present, and `Retro\Example Scenes\LowPoly_Scenes_Free.blend`
   is its unpacked remnant.

So the error was never "CC0 is false" in the abstract — it was **generalising a
free sample pack's licence across an entire commercial library.** CC0 and the
Pizza Doggy terms are directly incompatible (CC0 permits redistribution; Pizza
Doggy forbids it), so that generalisation would have licence-laundered packs that
explicitly forbid exactly that.

**Ruling for this project:** the blanket CC0 claim is void.
`docs/assets/ASSET-LEDGER.md` supersedes `docs/legacy/ASSETS.md` on all licensing
questions. Every pack outside the four above is unproven until its own store
terms are archived with a date.

---

## 5. Audio inventory

`SoundService.KenopsiaAudio` holds **39 `Sound` instances, all 39 with a
populated `SoundId`**. Full table: `docs/assets/audio-inventory.csv`.

```
KenopsiaAudio
  Music/            Intro, Loop, Outro
    Trials/         birdhunt, minefield          (no tablemanners)
  Ambience/         EMPTY - zero children
  SFX/              Click, ClickAlt, Submit, SubmitAlt, Reject, Hover,
                    AccessDenied, AccessGranted, StandClear, Warning, Confirm,
                    Count5..Count1, ImpactBody                        (17)
    Clicks/         Click1..Click5
    Submits/        Submit1..Submit3
    MineExplosions/ Explode1..Explode4
    Blood/          Blood1, Blood2
    SniperFire/     Primary
    SniperReload/   Primary
    BulletRicochet/ Primary
```

`Ambience` being empty and `Music.Trials.tablemanners` being absent both confirm
`REQ-CP-04`: no Canteen audio of any kind exists.

### Sniper volumes — RESOLVED: keep the live values

All three asset ids match plan §3 exactly. The volumes did not, which was a
conflict between two reviewer instructions rather than a defect:

- Phase 1 standing constraint: *"Preserve the existing sniper audio IDs,
  **volumes**, and music ducking."*
- New plan §3: 0.95 / 0.75 / 0.80.

**Reviewer ruling — the live values stand. The plan's lower numbers are not
applied.**

| Sound | Asset id | **Authoritative volume** | Plan §3 (not applied) |
|---|---|---:|---:|
| `SFX.SniperFire.Primary` | `118803023612410` | **1.45** | ~~0.95~~ |
| `SFX.SniperReload.Primary` | `83110281478101` | **1.70** | ~~0.75~~ |
| `SFX.BulletRicochet.Primary` | `83668417079973` | **1.10** | ~~0.80~~ |

Existing music ducking is unchanged.

Rationale: the plan's acceptance test is **relative, not absolute** — *"Schuss,
Reload und Ricochet sind deutlich lauter als Musik"* — and the live values
already satisfy it against music at 0.24–0.45.

**Gate 3 constraint:** these values may be changed only after a real listening
test, and only to correct audible clipping. Not to match the plan's numbers.

Music `Sound.Volume` values are 0.35 (Intro/Loop/Outro), 0.24 (birdhunt) and
0.45 (minefield). The plan's *"Musikgruppe: maximal 0.25"* constrains a
`SoundGroup`, not these per-Sound volumes; no `SoundGroup` was found in the audio
tree. Whether one must be introduced is a Gate 3 question — but it must not be
used as a back door to re-scale the weapon audio ruled on above.

---

## 6. Methodology note — a false finding, caught and corrected

`query_instances_descendants` is PRO-gated. At Basic tier it silently falls back
to `query_instances_children` (reported in `data.proFallback`) but returns a
**flattened subtree**, not direct children.

Reading that flattened list as a child list produced a confident false finding:
that duplicate `birdhunt` / `minefield` `Sound`s existed directly under `Music`
alongside the `Trials` folder, and that 58 of 97 Sounds had no `SoundId`. Both
were artifacts. There are 39 Sounds, all populated, and the Phase 0 manifest's
description of the `Music` tree was correct.

The corrected inventory was rebuilt from 39 explicit leaf paths rather than from
tree traversal. **Do not treat `query_instances_descendants` output as a child
list at Basic tier.**

---

## 7. Deferred requirements — re-mapped onto the new gates

The register in `PHASE0-BASELINE.md` was written against the previous plan.
`PHASE0-BASELINE.md` is left intact as history; this table governs.

| REQ | Gate | Status / change under the new plan |
|---|---|---|
| `REQ-DZ-01` | — | **Closed** by Phase 1 C1.a: `current` is a module local carrying room + session. Gate 1 generalises it into `RoundContext`. |
| `REQ-DZ-02` | 2 | Unchanged — mines become server records. |
| `REQ-DZ-03` | 2 | Unchanged — `BloodFX.clear(effectScope, audience)`. |
| `REQ-DZ-04` | 2 | Unchanged — collapse `kill` + `shatter`. |
| `REQ-DZ-05` | 2 | **Superseded.** Old: 42.0 s traversal / 0.5 s grace. New plan: 55 s round limit; crusher traversal is tuned to fit it. |
| `REQ-DZ-06` | 2 | **Superseded in part.** Old: sonar radius 9. New plan §3: *"Scanradius bleibt zunächst 8 Studs"* — radius stays **8**. Removing `CLEANRUN_BONUS` as a point bonus still stands; it becomes the last tiebreaker only. |
| `REQ-BH-01` | 3 | **Superseded.** Old: hidden leg cap 40 s. New plan §2: **90 s** per leg. |
| `REQ-CP-01` | 4 | **Renamed.** New arena contract is `Seats/P1..P4`, `PlateAnchors/P1..P4`, `ForkAnchors/P1..P4`, `MouthTargets/P1..P4`, `PlayerCameras/P1..P4`, `Observer`, `ObserverCamera`, `ExecutionMuzzles`, `SpectatorCamera` — not the old `Seat01..04` / `PeaAnchor01..04` naming. |
| `REQ-CP-02` | 4 | Unchanged — `refs()` must resolve `Workspace.CanteenProtocol`. |
| `REQ-CP-03` | 4 | **Widened.** Not a repair: the beat/Perfect/Good/stress mechanic is replaced wholesale by plate→fork→mouth plus the server observer cycle, and the old code must be unreachable at runtime. |
| `REQ-CP-04` | 4 | Unchanged and confirmed — no Canteen audio exists. Release blocker. |
| `REQ-REG-01` | 1 | Largely closed in Phase 1. Gate 1 extends the loop to `#order` trials. |
| `REQ-REG-02` | 4 | **Preserved verbatim.** Canteen stays out of `TrialIds` until it is implemented and explicitly ready. |
| `REQ-CAP-01` | — | **Closed.** Server size set to 4 in the Creator Dashboard. `Players.MaxPlayers` still reads 60 in Studio and is ignored. |
| `REQ-FX-01` | 6 | Aligned — 48 pooled gore particles per client. |
| `REQ-FX-02` | 2 / 5 | Unchanged — remove global screen blood and the `shatter` fountain. |
| `REQ-IP-01` | 2 / 3 / 5 | Unchanged — includes renaming the **live `Kastrierer` Model** in Workspace, not only the source references. |
| `REQ-IP-02` | 0 / 7 | Seeded in the ledger. Partly resolvable at Gate 5: an original character supersedes the XBot rig and its 12 `KeyframeSequence`s. |

---

## Gate 0 verdict

| Criterion | Result |
|---|---|
| Clean working tree | PASS |
| Correct place, Edit mode, pinned on every call | PASS |
| No competing writer | PASS (1 plugin client, 1 MCP instance) |
| 19/19 SHA-256 parity | PASS |
| Asset ledger exists | PASS (`docs/assets/ASSET-LEDGER.md`) |
| Deviation recorded with compensating control | PASS |
| `TableManners` still `ready = false` | PASS |

**Reviewer verdict: Gate 0 — PASS WITH CONDITIONS.**

Conditions raised, and their state after this revision:

| # | Condition | State |
|---|---|---|
| 1 | Gate 1 precheck must baseline on `65b8bc2`, not `9637fcc` | **CLOSED** — §1 records both, names `65b8bc2` as the Gate 1 baseline, and notes `studio-src` is unchanged between them so §3 parity still holds |
| 2 | The MainGame authorisation was never granted; `Kenopsia_DEV` is required | **CLOSED in documentation** — §2 withdraws the false claim and makes DEV the standing rule. **Still open in execution:** the DEV place is not yet identified or verified |
| 3 | Ledger says "three packs"; it is four, via `PSX Textures II v1.6.zip` | **CLOSED** — §4 and the ledger both corrected; archive presence verified on disk |
| 4 | CC0 wording must be precise about `LowPolyAssetPack_Free.zip` | **CLOSED** — §4 now states the notice is absent *and* that it only ever covered the free sample pack, never the arena packs |
| 5 | Sniper volumes: keep live values, music ducking unchanged | **CLOSED** — §5 records 1.45 / 1.70 / 1.10 as authoritative and binds Gate 3 |

**Gate 1 remains on HOLD** pending condition 2's execution half: identify
`Kenopsia_DEV`, confirm it is Edit-mode and "Limited to same Universe", and
verify its content against the MainGame manifest.

Unchanged carry-forward: licence coverage for the ~29 packs with no archived
terms (§4) is a Gate 7 release blocker, not a Gate 1 blocker.
