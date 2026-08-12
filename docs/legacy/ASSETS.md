> **SUPERSEDED FOR LICENSING — see `docs/assets/ASSET-LEDGER.md`.**
> The CC0 claim in the "Licensing" section below is **void**: the `NOTES.txt` it
> cites does not exist, and the one licence instrument that does exist
> (Pizza Doggy's Game Assets) forbids redistribution, which CC0 permits. Do not
> cite this file for licence questions. Verified at Gate 0, 2026-08-12.

# Asset import list

Everything below already exists in `C:\Users\Asus\Documents\Retro`. Nothing here needs to be modelled from scratch.

Import in tier order. **The game runs right now with zero assets imported** — it generates placeholder blocks and text labels — so nothing is blocked on you. Each tier makes it look more like the real thing.

---

## Tier 1 — Do this first (unblocks both minigames that use symbols)

### 1a. The 40 item icons ← the single highest-value import

```
Documents\Retro\Item Icons - PSX Mega Pack, PSX Bunkers\Icons\*.png
```

This is the game's shared vocabulary. RECALL shows you these symbols; THE LINE makes you carry the objects they stand for. One dictionary, used everywhere.

**How:** Studio → **Asset Manager → Images → Bulk Import** → select all 40 PNGs. Roblox will moderate them (usually minutes).

**Then:** open `src/shared/IconPool.luau` and paste each returned id into the matching `image = ""` field:

```lua
{ id = "canned_food_3", label = "CANNED FOOD", image = "rbxassetid://123456789", model = "canned_food_3", safe = true },
```

Any icon left as `""` is simply skipped by the pool — you can import ten, test, and do the rest later.

**Skip these four.** They're already flagged `safe = false` in the pool and won't appear in game: `shotgun_1`, `shotgun_ammo_1/2`, `hand_saw_1`, `kitchen_knife_1`, `cigs_packet_1`, `pills_bottle_1`, `ammo_box_1`. Weapons and pills buy you nothing here and cost you a cleaner moderation profile.

### 1b. The 11 models that match those icons

```
Documents\Retro\PSX Bunkers\Models\FBX\
```

| File | Pairs with icon |
|---|---|
| `canned_food_3.fbx`, `canned_food_4.fbx`, `canned_food_5.fbx` | canned_food_3/4/5 |
| `floppy_disc_2.fbx`, `floppy_disc_3.fbx`, `floppy_disc_4.fbx` | floppy_disc_2/3/4 |
| `cpu_1.fbx` | cpu_1 |
| `power_supply_1.fbx` | power_supply_1 |
| `mre_1.fbx` | mre_1 |
| `pcb_1.fbx` | pcb_scrap_1 |
| `military_radio_1.fbx` | walkie_talkie_1 |

**Where they go:** `ReplicatedStorage.Items`, each as a **Model** named exactly as in the table's left column (minus `.fbx`). `Line.luau` looks them up by that name and falls back to a placeholder block if one is missing.

> These eleven are enough. THE LINE needs 5 pedestals + decoys, and it can repeat item types.

---

## Tier 2 — The three arenas

Build these as `Workspace.Arenas.<id>` Models, each containing an **anchored, invisible, non-collidable Part named `Origin`**. Origin's CFrame is the arena's local space — minigames build relative to it, so you can move or rotate a whole arena in Studio and no code changes.

Required arena ids: `lobby`, `recall`, `grate`, `line`.

### `grate` — THE GRATE
The pads are **generated in code**, so you only build the shell around them. Leave a clear corridor ~52 studs wide × ~210 studs long forward on **+Z** from Origin.

```
PSX Bunkers\Models\FBX\
  tunnel_straight.fbx            <- repeat down both sides
  tunnel_ancle.fbx
  tunnel_junction_three_way.fbx
  tunnel_junction_four_way.fbx
  pipe_1.fbx / pipe_1_short.fbx / pipe_1_ancle.fbx / pipe_2.fbx
  beam_6.fbx / beam_7.fbx
  pillar_11.fbx
  wall_1_plain.fbx
  vent_4.fbx
  lamp_0.fbx                     <- sparse; darkness is the point
```

### `line` — THE LINE
An open workshop. Pedestals and items spawn in code around Origin; you're dressing the room.

```
PSX Bunkers\Models\FBX\
  wooden_crate_8.fbx / wooden_crate_9.fbx
  wood_pallet_1.fbx / wood_pallet_2.fbx
  metal_crate_3.fbx
  metal_shelf_1.fbx / metal_shelf_2.fbx
  supply_box_1.fbx
  water_barrel_1.fbx
  table_large_3.fbx
  machinery_1.fbx / machinery_2.fbx / machinery_3.fbx
  generator_1.fbx
  trash_1..6.fbx                 <- scatter, cheap visual density
  floor_1.fbx / wall_1_plain.fbx / doorway_2_plain.fbx
```

### `recall` — RECALL
Smallest arena. Players barely move; it's a UI minigame. A cell with one big screen.

```
PSX Bunkers\Models\FBX\
  computer_1.fbx
  scanner_1.fbx
  wall_1_plain.fbx / wall_1_round.fbx
  ceiling_peace_1.fbx
  bars_metal_3.fbx / bars_metal_4.fbx
  sign_1..4.fbx
```

### `lobby` — the Machine hub
Where the CRT announces and the marquee scrolls. This is the room players see most, so it's worth the most dressing.

```
PSX Tech\Models\GLB (recommended)\
  control_panel_etx_1.glb        <- the Machine console
  computer_terminal_etx_1.glb
  screen_etx_1_partial.glb       <- the announce CRT
  screen_etx_1_stand.glb
  button_etx_red_1.glb           <- RESET
  button_etx_green_1.glb         <- SUBMIT
  lever_etx_1..9.glb             <- pick 3-4, vary the silhouette
  gauge_etx_1/2/3.glb
  fuse_box_etx_1.glb
  panel_etx_1/2.glb
  fader_etx_1.glb
  signal_receiver_etx_1/2.glb
  capacitor_etx_1..6.glb
  circuit_board_etx_1.glb
  data_block_etx_1.glb

PSX Bunkers\Models\FBX\
  blast_door_1_frame.fbx
  bunker_entrance_1.fbx
  machinery_1/2/3.fbx
```

> Prefer the **GLB** folder where a pack offers one — Roblox's 3D Importer handles GLB materials more predictably than FBX.

---

## Tier 3 — Audio (this pack is a gift, use it early)

### The Machine's voice ← import this before any other audio

```
Documents\Retro\System Status Alerts & Misc\
```

These give the Machine an actual voice for almost no work:

| File | Use |
|---|---|
| `#_one_smx_1.ogg` … `#_ten_smx_1.ogg`, `#_zero_smx_1.ogg` | Speak the program number during Announce |
| `access_granted_smx_1.ogg` | THE LINE — pedestal accepts |
| `access_denied_smx_1.ogg` | THE LINE — pedestal rejects |
| `confirmation_signal_smx_1/2.ogg` | RECALL — answer placed |
| `warning_signal_smx_1.ogg` | THE GRATE — path flash ending |
| `please_stand_clear_smx_1.ogg` | Countdown phase |
| `entry_sequence_initiated_smx_1.ogg` | Load phase |
| `sealing_chamber_smx_1.ogg` | Round start |
| `target_locked_smx_1.ogg` | THE GRATE — a player finishes |
| `atmospheric_hazard_detected_smx_1.ogg`, `containment_breach_risk_smx_1.ogg` | Ambient dread between rounds |

### Ambience and effects

```
Special Ambiences\pressure_mp_emh_1.wav     <- hub room bed
Special Ambiences\void_mp_emh_1.wav         <- between rounds
Echoes - Audio Super Kit\                    <- general SFX
ROT - Horror Audio Bundle\                   <- stingers
Rust & Blood - SFX Library\                  <- impacts, machinery
Super Retro Game OST\                        <- results screen music
```

> **Audio caveats, in order of how likely they are to bite you:** every upload is moderated and can be rejected; there's a **daily upload cap**; and uploaded audio defaults to private — you must grant your experience permission or it will be silent in-game with no error. Import the ~12 Machine-voice clips first and confirm they play before bulk-uploading a thousand `.ogg` files.

---

## Tier 4 — Surfaces and polish

```
64_textures\ , 128_textures\        <- use these, not 512
Retro FPS Style Textures\
PSX Textures II (Expanded Sample)\
TextureMap\MasterMaterial1px.png    <- the shared atlas most models expect
Brutal Skyboxes\
```

---

## Getting the PS1 look right in Roblox

Three things do most of the work:

1. **Use the small textures.** `64_textures` and `128_textures`, not `512`. The crunch is the aesthetic.
2. **Set `ResamplerMode = Pixelated`** on every `ImageLabel` showing an icon. This is the only place Roblox lets you turn off bilinear filtering, and it's exactly where you want it — the RECALL grid. Already wired up in `RecallUI.luau`.
3. **Lighting → `Technology = Voxel`**, low `Brightness`, heavy `FogEnd` pull-in. Future/ShadowMap lighting fights the look; voxel's chunkiness helps it.

MeshPart textures have no pixelated option — Roblox always filters them. Small source textures are the only lever there.

---

## Licensing

`Documents\Retro\NOTES.txt` declares **CC0 1.0 Universal** — free for commercial use, no attribution required. That's ideal for shipping on Roblox.

Note there are four separate `Game Asset License Agreement.pdf` files across the sub-packs. CC0 is confirmed for the base pack; **check the PDF inside any specific pack before shipping it**, in case one of them ships under different terms. Worth ten minutes now rather than a takedown later.

---

## Import order, condensed

1. 40 icons → paste ids into `IconPool.luau` → **RECALL is fully playable**
2. 11 item models → `ReplicatedStorage.Items` → **THE LINE is fully playable**
3. `Origin` parts in four arena Models → **arenas stop being grey placeholders**
4. ~12 Machine-voice audio clips → **the game gets its personality**
5. Everything else, in whatever order is fun
