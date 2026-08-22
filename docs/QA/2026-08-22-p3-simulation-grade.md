# QA — P3.1 SimulationGrade + P2.3 settings rows + FBX assets (22.08.2026)

Place 110672791536316, Studio live checks through the real input path (READY via
`user_mouse_input`, one player, `TrialIds` temporarily narrowed, restored afterwards).

## What changed

| Area | Change | Live check |
|---|---|---|
| `StarterPlayerScripts/SimulationGrade.client.luau` (new) | PS1 grade only while `KenopsiaActiveTrial ~= ""`: snapshot of 8 Lighting fields, `ColorGradingEffect` Retro, `ColorCorrectionEffect` (per-arena saturation/contrast/tint), fog or `Atmosphere`, minefield lamp raster; camera **position** quantisation 1/8 stud; `KenopsiaSimFilter` player attribute = off switch; `TrialClients/<id>.presentation.grade` wins over the built-in preset | minefield: `SimGrade_Tonemap`, `SimGrade_Grade`, fog 45/150, ambient preset, 9 lamps present while active; canteen: fog 38/140, sat −0.40, tint (255,228,192) — capture shows the warm greasy room |
| Camera quantisation | `KenopsiaCamQuant` attribute; the monolith's RenderStepped writer snaps scriptable cameras, the grade's own `Last` binding snaps the Custom camera | **60/60 frames on the 1/8 grid** with the scriptable runner cam; 31/31 with the Custom camera; attribute 8 while active, 0 after |
| `KenopsiaClient` | DZ-light block (80 lines) removed, folded into the grade; settings `SimFilter` + `Crt` rows; every setting published as `Kenopsia<Key>` attribute; `ReduceFlicker` pre-selected from `GuiService.ReducedMotionEnabled` | attributes `KenopsiaSimFilter/CRT/ReduceFlicker/UiSound/Music` present on the client at boot |
| `SettingsPanel` (place) | rows `Row_SIMFILTER` "SIMULATION FILTER", `Row_CRT` "CRT GLASS" (clones of `Row_REDUCEFLICKER`), panel 330 → 438 px | rows present in StarterGui |
| Restore gate | toggling the filter off mid-trial restores the snapshot, destroys every created instance, clears the attribute | verified: filter off → Lighting children = `KenopsiaSky` only, fog 60/480, ambient lobby values, no `DZ_Lights_Local` |
| `ServerStorage.KenopsiaAssets.Props.Minefield.MF_Compactor` (place) | the FBX `MF_Hunter_Shredder` renamed to the name `Minefield.luau` already looks for; `WorldPivot` = leading face of the maw (z of `Maw_Lip` front), 3.2 studs above the tracks (matches `placeShred`'s `gTop + 3.2`); all parts anchored / non-colliding | placed at the ShredderSpawnpoint in Edit mode with `placeShred`'s formula: fills the 45-stud corridor, maw + teeth face the runners' spawn, tracks on the ground, scanner eyes on top. The user's own copy `Workspace.MF_Shredder` was left untouched (delete it when done looking). |
| `ReplicatedStorage.KenopsiaAssets.SniperRifle` (place) | the Blender `SniperRifle_PSX` mesh as the viewmodel: mesh = `Receiver` (lamp host), scaled to the procedural rifle's 4.32-stud length, rotated so the barrel is −Z; invisible `Grip` (PrimaryPart, pivot at (0,−0.18,0.52)) and `Muzzle` (barrel tip) markers. The procedural rifle is archived as `ServerStorage.KenopsiaAuthoring.Archive.SniperRifle_Procedural`, the authoring mesh as `SniperRifle_PSX_Authoring` | preview capture: muzzle marker at the barrel tip, grip marker at the trigger group |

## Engine fact measured today

`RunService.RenderStepped` fires **after** every `BindToRenderStep` priority, `Last` included
(probe: order `LAST, RS`). A binding can therefore never override a camera that a
RenderStepped handler writes — that is why the snap lives in the monolith's writer.

## Minefield lighting — what was learned

* The first live captures showed a lit runner on black nothing. Isolation (night only,
  no grade, an 8-brightness PointLight 11 studs above the runner) showed **no local
  light at all** in this Studio session (quality Automatic) — the raster cannot be
  judged here, and it will be equally absent on weak phones at low quality.
* Consequence: the preset now carries the floor with ambient (34,40,56) /
  outdoor (14,18,28); the lamp raster (PointLight 2.6 / 40, one per 40 studs, one
  centre row on phones) only adds pools where lights render.
* **Open — user check:** play the minefield on the PC with quality ≥ 8 and say whether
  the pools are visible / too bright.

## Open

* Prop animation stepping (12–15 Hz) for kit-driven props — not done (P3.1 row, low value until P4 trials exist).
* Birdhunt preset (Atmosphere) not live-checked — no hunter session in a solo run.
* `MF_Compactor` is 44 × 37 × 75 studs; the runner cam eye sits 24 studs up and 9 behind the runner, so the cowl/mast may brush the camera in the last second before a kill. Judge in a 2-player run.
* Sniper viewmodel: bolt animation parts (`BoltKnob`, `BoltStub`) do not exist on the mesh — the bolt cycle is silently skipped; add two marker parts if the cycle should return.
* `if_same_then_else` selene errors in KenopsiaClient are pre-existing (lines ~705/708/981).
