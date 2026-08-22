# Local art/animation pipeline (Blender → FBX → Roblox) on this PC

> Read-only research lens, measured 2026-08-22 (workflow wf_a13d7aec-54c). Facts cite their source; treat plan documents as claims, measurements as truth.

## Summary

Two complete Blender character pipelines exist on disk and both are further along than the docs claim. PS1Player (63 MB, C:\Users\Asus\Documents\Retro\PS1Player) is a fully scripted, re-runnable build: 34 numbered .py stages, a 60 KB SPEC.md, 114 review renders, a 20-bone rig and 7 exported clips. TableManners (the boss) is a second, older but complete pipeline with 6 clips. Blender itself is installed twice (4.2 and 5.2, both with the blender-mcp addon.py 115.7 KB), but Blender is NOT running right now — get_scene_info returns "Could not connect to Blender", so no .blend is open and bl.py's socket 9876 bridge is down. Roblox Studio IS running with exactly one instance, Kenopsia_MainGame (110672791536316).

Measured in the live place rather than taken from plan docs: SoundService.KenopsiaAudio has 34 Sounds. Music.Trials holds 2 entries (birdhunt, minefield) for a 15-trial playlist; Ambience is an empty Folder; Music.Intro/Loop/Outro and SFX.Submit/SubmitAlt/AccessGranted/AccessDenied/StandClear are gone even though audio-inventory.csv still lists them. Two live consequences: KenopsiaClient's setLobbyMusic can never find Music.Loop (lobby music is dead code) and sfx("AccessGranted") is a silent no-op because only Click and Submit have pool fallbacks.

Animation ids: 11 of 17 slots in AnimationIds.luau carry real ids; 6 are still 0 — Player.Eat, Boss.Death, PlayerBlink, PlayerHappy, PlayerHurt, BossAngry. Boss.Reading is not its own clip, it is aliased to the LookUp id. Two clips exist as FBX but nowhere in Roblox: Anim_Eat.fbx and Anim_Stab.fbx (both exported 2026-08-22 14:44, the newest artefacts in the tree) — and RBX_ANIMSAVES has no Anim_Eat holder either, so the documented Studio fallback cannot fire. Anim_Stab has no AnimationIds entry at all.

The boss rig has been moved: Workspace.Boss_Rig_scaleUnits and Player_Rig_scaleUnits no longer exist; ServerStorage.KenopsiaAssets.Rigs does. Props still holds only Minefield — BirdHunting and CanteenProtocol prop folders are absent, so the built CP_Observer.fbx (47,932 B, tools/blender/build_cp_observer.py 17,563 B) has never been imported.

Local audio raw material is abundant: 942 source files across 6 kits (Echoes 471, Rust & Blood 255, ROT 187, System Status Alerts 25, plus 2+2). Only ROT and Rust & Blood carry an in-folder licence PDF; Echoes, System Status Alerts, Special Ambiences and Super Retro Game OST have none, and no NOTES.txt exists anywhere under Retro. Podium/verdict assets are at zero — "Podium statt Textliste" is a one-line PLAN.md M4 bullet with no model, texture or sound behind it.

## Facts

- Blender is installed twice: C:\Program Files\Blender Foundation\Blender 4.2\blender.exe (79.0 MB) and Blender 5.2\blender.exe (107.7 MB). probe_fbx.py hard-codes the 4.2 path.
  - *Source:* ls C:/Program Files/Blender Foundation/*/ ; C:\Users\Asus\Documents\Retro\PS1Player\scripts\probe_fbx.py line 2
- Blender is NOT running. mcp__blender__get_scene_info returned {"result":"Error getting scene info: Could not connect to Blender. Make sure the Blender addon is running."} — no .blend is open.
  - *Source:* MCP call mcp__blender__get_scene_info
- The blender-mcp addon is installed for both 4.2 and 5.2 as addon.py (115.7 KB each) under C:\Users\Asus\AppData\Roaming\Blender Foundation\Blender\{4.2,5.2}\scripts\addons\. An older V5aBemWL.py (31.1 KB) sits in 2.83 and 4.2.
  - *Source:* ls C:/Users/Asus/AppData/Roaming/Blender Foundation/Blender/*/scripts/addons/
- scripts/bl.py sends python to the running Blender over blender-mcp socket 9876 — the whole PS1Player pipeline is driven through that bridge, which is currently down.
  - *Source:* C:\Users\Asus\Documents\Retro\PS1Player\scripts\bl.py lines 1-3
- Exactly one Roblox Studio instance is connected: id c39e925b-2e9e-4d46-a465-65c4b6a8ec59, name "Kenopsia_MainGame (placeId: 110672791536316)".
  - *Source:* MCP call mcp__Roblox_Studio__list_roblox_studios
- PS1Player is 63 MB total: export 5.1 MB, review 53 MB (114 files), scripts 499 KB, textures 148 KB, docs_eat 196 KB.
  - *Source:* du -sh C:/Users/Asus/Documents/Retro/PS1Player/*
- PS1Player.blend is 1,246,948 B modified 2026-08-22 15:08 — the most recently touched file in the whole art tree. PS1Player_pre_table.blend (1,155,344 B, 14:31) is the pre-fork snapshot.
  - *Source:* ls -la --time-style=long-iso C:/Users/Asus/Documents/Retro/PS1Player
- scripts/ holds 34 .py stage scripts and 7 .json data files (eat_envelope 20.5K, eat_geom 3.4K, eat_solved 1.9K, hover_bind 1.4K, regions_body 39.7K, regions_player 39.7K, table_solved 12.9K).
  - *Source:* ls -la C:/Users/Asus/Documents/Retro/PS1Player/scripts
- Script roles (from each file's top comment): 10_model_body = torso/arms/legs base mesh; 12_model_head = skull, hair, ponytail, goggles; 14_model_bag = hip shoulder bag; 16_model_detail = clothing detail (shorts, pockets, belt, straps, dog tag, watch); 18_model_review = tri-count verification + review renders; 20_paint_atlas = procedural 256x256 PS1 atlas in numpy + Blink/Happy/Hurt variants; 25_uv_layout = UVs from per-face labels into atlas regions; 28_texture_review / 29_critic_shots = textured review renders; 30_rig = 20-bone PlayerRig + weights; 35_rig_test = scripted test poses; 37_solver_lib = analytic 2-bone IK solvers; 39_poses = pose/keying library; 40_anim_{idle,walk,run,crouch,push} = the five NLA loop clips; 40_anim_eat = 14f arms+head-only bite; 41_eat_preview = renders what Roblox will actually compose; 42_anim_table = Stab (6f, repeatable) + Eat (12f, one-shot) plus the fork; 43_table_review / 45_review_sheets / 46_* = contact sheets and numeric critic checks; 50_export = FBX/PNG/blend export; 52_export_eat = Eat-only export with bake_anim_use_all_bones FALSE; 53_export_table = Stab/Eat as deltas + Player_Rig_Fork.fbx; atlas_spec / model_lib / bl / view / probe_eat / probe_fbx = shared libs and headless verification.
  - *Source:* head -8 of each C:\Users\Asus\Documents\Retro\PS1Player\scripts\*.py
- hover_bind.json (1,4xx B) is the seated fork-hover binding: three ops applied in order after the leg/left-arm seat ops — RightUpperArm axis_roblox_local (0.54693, 0.54207, 0.63798) 110.48 deg; RightLowerArm (-0.14428, 0.5395, 0.82954) 47.102 deg; RightHand (-0.01165, 0.07766, 0.99691) 135.547 deg. Plus wrist_minus_pelvis_roblox (0.3, 4.0641, -1.4117), fork_tip_offset_along_hand 1.17, fork_pitch_deg 22.0, and a live verification formula against RightHand.TransformedWorldCFrame.
  - *Source:* C:\Users\Asus\Documents\Retro\PS1Player\scripts\hover_bind.json (full file)
- table_solved.json (12.9 KB) stores the solved Euler XYZ per bone for the "hover" pose and the per-frame "stab" pose — the right-arm values match hover_bind.json exactly (69.064/56.05/-44.953 etc.), and legs are pinned at UpperLeg 90 / LowerLeg -90 (the seated pose).
  - *Source:* C:\Users\Asus\Documents\Retro\PS1Player\scripts\table_solved.json
- export/ FBX inventory with dates: Player_Rig.fbx 163,148 B; Player_Rig_scaleUnits.fbx 163,196 B; PS1Player_AllAnims.fbx 999,100 B (all 2026-08-16 18:37); Player_Rig_Fork.fbx 210,876 B (2026-08-22 14:44).
  - *Source:* ls -la --time-style=long-iso C:/Users/Asus/Documents/Retro/PS1Player/export
- export/anim/ holds 7 clips: Anim_Crouch 350,972; Anim_Idle 355,148; Anim_Push 329,756; Anim_Run 304,956; Anim_Walk 324,236 (all 2026-08-16 18:37) plus Anim_Eat 340,748 and Anim_Stab 327,132 (both 2026-08-22 14:44).
  - *Source:* ls -la --time-style=long-iso C:/Users/Asus/Documents/Retro/PS1Player/export/anim
- Face textures exist as files in both export/ and textures/: Player_Atlas_1024.png 27,625 B, _Blink_1024 27,589 B, _Happy_1024 27,682 B, _Hurt_1024 27,715 B (plus the four 256x256 masters ~6.1 KB each).
  - *Source:* ls -la C:/Users/Asus/Documents/Retro/PS1Player/export and /textures
- MEASURED animation ids in the shipped module: Player.Idle=125600962447767, Walk=123033497454830, Run=95031726336950, Crouch=125766316179596, Push=70937503697406, Death=114200780379540, Eat=0. Boss.Reading=78730370216852, Idle=95540888860028, LookUp=78730370216852, LookDown=76111131902834, Shoot=87302586462797, Death=0. Textures.PlayerNeutral=136734973177857, PlayerBlink=0, PlayerHappy=0, PlayerHurt=0, BossNeutral=130641113899237, BossAngry=0.
  - *Source:* studio-src/ReplicatedStorage/Kenopsia/Shared/Config/AnimationIds.luau:17-43
- Boss.Reading is NOT a separate published clip — it is the LookUp id 78730370216852 reused, with the comment "Reading reuses LookUp: CanteenBoss holds its first reading pose at speed 0", even though Anim_Reading.fbx (404,972 B) exists on disk.
  - *Source:* AnimationIds.luau:36-37 and ls C:/Users/Asus/Documents/Retro/TableManners/export/anim
- Ownership blocker recorded in code: every published id was published by user 4840146924 (iLoveKilIs) but place 110672791536316 belongs to GROUP 832614570; LoadAnimation succeeds, Length stays 0, the rig never moves until the experience is granted access per id. warmup() probes Boss.Idle for 3 s and falls back to Studio KeyframeSequences.
  - *Source:* AnimationIds.luau:45-59, 108-150
- MEASURED live audio: SoundService.KenopsiaAudio contains 34 Sounds. Music.Trials has exactly 2 entries (birdhunt 71143122243344 vol 0.24 looped, minefield 132499516846518 vol 0.45 looped). Ambience is an empty Folder. There is no Music.Intro, Music.Loop or Music.Outro.
  - *Source:* MCP mcp__Roblox_Studio__execute_luau (Edit datamodel, studio c39e925b) walking SoundService.KenopsiaAudio
- MEASURED live SFX set: Click, ClickAlt, ImpactBody, Reject, Hover, Warning, Confirm, Count1-5, folders SniperFire/BulletRicochet/SniperReload (Primary each), Clicks.Click1-5, Submits.Submit1-3, MineExplosions.Explode1-4, Blood.Blood1-2. SFX.Submit, SubmitAlt, AccessGranted, AccessDenied and StandClear do NOT exist live, although audio-inventory.csv still lists all five.
  - *Source:* same execute_luau read vs docs/assets/audio-inventory.csv
- MEASURED ServerStorage.RBX_ANIMSAVES holds 13 ObjectValues. Player: PS1Player_AllAnims -> Idle 61kf / Walk 31kf / Run 21kf / Push 41kf / Crouch 61kf, plus Anim_Idle/Walk/Run/Push/Crouch each holding Scene + a named copy. Boss: Anim_Idle (Scene+Idle 121kf), Anim_LookUp (LookingUp 45kf), Anim_LookDown (LookDown 20kf), Anim_Shoot (Shoot 50kf), Anim_Death (Death of Player 60kf), Anim_Reading (Scene 121kf only — no "Reading" sequence). EVERY sequence has Priority = Action and Loop = true.
  - *Source:* MCP execute_luau read of ServerStorage.RBX_ANIMSAVES
- MEASURED: Workspace.Player_Rig_scaleUnits and Workspace.Boss_Rig_scaleUnits no longer exist; ServerStorage.KenopsiaAssets.Rigs does exist. The MP-03 M4 housekeeping move has been carried out since that doc was written (2026-08-17).
  - *Source:* MCP execute_luau (FindFirstChild checks on workspace and ServerStorage.KenopsiaAssets.Rigs)
- MEASURED: ServerStorage.KenopsiaAssets.Props contains only Minefield{MF_Mine, MF_Crater, MF_SonarRing, MF_Hunter_Shredder}. The BirdHunting and CanteenProtocol prop folders that BirdHunting.buildTurret and CanteenProps.makeObserver look for still do not exist.
  - *Source:* MCP execute_luau enumeration of ServerStorage.KenopsiaAssets.Props
- MEASURED: StarterPlayer.StarterCharacter does not exist — players still use default R15 avatars, and default.project.json has no StarterCharacter node.
  - *Source:* MCP execute_luau FindFirstChild + default.project.json (StarterPlayer block only has StarterPlayerScripts and StarterCharacterScripts/Health)
- The 15-trial playlist is: minefield, birdhunt, canteen, carve, armory, upstream, floorcheck, clearance, carrier, breather, sweep, crawler, ricochet, stacker, sorting.
  - *Source:* studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/Playlist.luau:31-35
- Boss rig files: TableMannersBoss.blend 1,316,324 B (2026-08-15 16:12); export/Boss_Rig.fbx 168,876 B; Boss_Rig_scaleUnits.fbx 168,924 B; TableMannersBoss_AllAnims.fbx 1,246,684 B; BossAnimator.luau 6,401 B; Boss_Atlas_1024.png 26,858 B and Boss_Atlas_Angry_1024.png 26,842 B; export/anim: Anim_Death 345,132, Anim_Idle 395,500, Anim_LookDown 301,228, Anim_LookUp 324,556, Anim_Reading 404,972, Anim_Shoot 330,988 (all 2026-08-15 15:46).
  - *Source:* ls -laR C:/Users/Asus/Documents/Retro/TableManners
- Local sound-kit inventory (audio files only, counted): Echoes - Audio Super Kit 471 OGG (SFX 331, Bonus 38, GUI 37, Soundtracks 34, Ambiences 31); Rust & Blood - SFX Library 255 (Firearms 99, Player 60, Melee 39, Impact & Break 20, Explosions 19, Misc 17, Bonus/OST 1); ROT - Horror Audio Bundle 187 (Cinematic vol.1 63, OST 30, Ambiences 26, Entities 18, UI 18, Machines 11, Monsters 9, Buttons & Levers 5, Ambient 3, Cursed Music 2, Doors 1, Misc 1); System Status Alerts & Misc 25 OGG voice lines; Special Ambiences 2 WAV (35.2 MB each); Super Retro Game OST 2 OGG. Total 942 files.
  - *Source:* find + wc over C:/Users/Asus/Documents/Retro/<kit>
- Licence proof exists in-folder ONLY for PSX Tech, ROT - Horror Audio Bundle and Rust & Blood - SFX Library (Game Asset License Agreement.pdf, 53.2 KB each) plus the Retro-root copy covering PSX Textures II. Echoes, System Status Alerts & Misc, Special Ambiences and Super Retro Game OST carry no licence file (only thumbnails). No NOTES.txt exists anywhere under Retro.
  - *Source:* find C:/Users/Asus/Documents/Retro -maxdepth 2 -iname NOTES.txt -o -iname '*LICENSE*' ; ls of each kit folder ; docs/assets/ASSET-LEDGER.md section 1
- System Status Alerts & Misc contains exactly the voice lines the removed live Sounds needed: access_denied_smx_1.ogg, access_granted_smx_1.ogg, please_stand_clear_smx_1.ogg, warning_signal_smx_1.ogg, target_locked_smx_1.ogg, confirmation_signal_smx_1/2.ogg plus spoken digits 0-10.
  - *Source:* ls C:/Users/Asus/Documents/Retro/System Status Alerts & Misc/Audio/OGG
- release/ (144 KB, 4 files) is a staging folder for upload: release/bird-hunting-audio/{SniperFire.ogg 47,745 B, BulletRicochet.ogg 46,428 B, SniperReload.ogg 38,924 B, README.md 1,288 B} — the three weapon sounds that are already live as ids 118803023612410 / 83668417079973 / 83110281478101.
  - *Source:* ls -laR 'C:/Users/Asus/Claude/Kenopsia_Roblox Project/release'
- tools/ (60 KB, 4 files): build-canteen-arena.luau 13,548 B (procedural canteen arena builder), start-weppy.ps1 4,562 B and weppy.ps1 9,563 B (weppy MCP launcher/CLI), blender/build_cp_observer.py 17,563 B (builds the Canteen Observer prop).
  - *Source:* ls -laR 'C:/Users/Asus/Claude/Kenopsia_Roblox Project/tools'
- tests/ (52 KB, 5 files) are offline Lua 5.1 proofs run outside Roblox: animationids.lua 5,111 B (proves resolve() returns nil for 0 and a rbxassetid string otherwise, and that load() never throws), rules.lua 14,161 B, trialrules.lua 6,780 B, contexts.lua 6,643 B, envelope.lua 4,446 B.
  - *Source:* ls -la tests/ ; head -60 tests/animationids.lua
- dev-src/ (212 KB, 20 files) is a separate Kenopsia_DEV source tree (MenuController, MenuOverlayController, MenuSceneController, SessionWallController, TrialQuality/TrialTarget/TrialCanteen, UI/SoundBank.luau, StarterPlayer/StarterCharacter/Animate.client.luau). It is NOT referenced by default.project.json, which maps studio-src only.
  - *Source:* find dev-src -type f ; default.project.json (all $path entries are studio-src/*)
- default.project.json (8,222 B) serves placeId 110672791536316 and maps 22 server Services, 16 Rules modules, 12 TrialClients, AnimationIds and GameConfig — all from studio-src.
  - *Source:* C:\Users\Asus\Claude\Kenopsia_Roblox Project\default.project.json
- aftman.toml pins rojo 7.7.0, StyLua 2.5.2, selene 0.31.0, luau-lsp 1.69.0.
  - *Source:* C:\Users\Asus\Claude\Kenopsia_Roblox Project\aftman.toml
- .claude/settings.json does NOT exist. Only .claude/settings.local.json (407 B) is present, allowlisting mcp__Roblox_Studio__{execute_luau, list_roblox_studios, script_read, search_game_tree, inspect_instance, get_console_output, start_stop_play} plus Bash, Write, Edit.
  - *Source:* ls -la 'C:/Users/Asus/Claude/Kenopsia_Roblox Project/.claude' ; cat .claude/settings.local.json
- docs/assets/ (2.3 MB, 6 files): ASSET-LEDGER.md 12,190 B, CP_Observer.blend 1,171,740 B (2026-08-15), CP_Observer.blend1, CP_Observer.fbx 47,932 B, CP_Observer_Diffuse.png 12,254 B, audio-inventory.csv 2,255 B (39 rows).
  - *Source:* ls -la 'C:/Users/Asus/Claude/Kenopsia_Roblox Project/docs/assets'
- Retro top level: 45 asset-pack subfolders, 2.6 GB total. Largest: PSX Mega Pack II 3254 files, PSX Bunkers 583, Echoes - Audio Super Kit 471+, 256/ and 512/ texture sets 466 each, PSX Tech 344, Modular Retro FPS Kit 264, FBX and Blend Files 256, PSX Nature 234 / Nature-branches-separated 235, Retro Tree Pack 132, Crosshairs Pack 100, Models 80, Textures 78, Brutal Skyboxes 49, PSX Paintings 42, Item Icons 40, Kenopsia_Canteen_Import 39 (16 FBX+fbm canteen meshes), PSX Gifts & Misc 33, PSX Textures II sample 30, Experimental Textures sample 23, Retro FPS Style Textures 18, PSX Stinky Thoughts 18, PSX Vintage Projector 17, Female (X Bot) Animation 13 Mixamo FBX, Male (Y Bot) Animation 16, 128_textures 12, 64_textures 10, Rusty Kidnapper's Van 9, The Most Comfortable Chair 9, Pizza Doggy's Item Icons Making Setup 6, Stuff For Debugging 5, Hard Hat 3, Eye Glasses 2, T-Shirt Women simple 2, Misc 2, TextureMap 2, Example Scenes 1 (LowPoly_Scenes_Free.blend), __MACOSX 0.
  - *Source:* ls + find -type f | wc -l over C:/Users/Asus/Documents/Retro/*
- ablaze/, blink/ and blood/ are skybox cubemap sets, not audio: each holds exactly 7 PNGs (back/bottom/cubemap/front/left/right/top) — these are the likely source of Lighting.KenopsiaSky.
  - *Source:* ls C:/Users/Asus/Documents/Retro/{ablaze,blink,blood}
- docs_eat/ (196 KB) is a four-document design record for the Eat clip alone: EAT-SPEC.md 86,797 B, EAT-03-WIRING.md 37,424 B, EAT-02-DESIGN.md 31,218 B, EAT-01-GEOMETRY.md 30,232 B (2026-08-19).
  - *Source:* ls -la C:/Users/Asus/Documents/Retro/PS1Player/docs_eat
- The import guide documents the rig as 20 bones, 1440 tris total (Player_Body 1096, Player_Head 302, Player_Bag 42), 7.7 units tall, facing -Y in Blender = Roblox -Z, and gives natural clip speeds Walk 4.5 studs/s, Run 10.95, Push 3.15 at scale 1.
  - *Source:* C:\Users\Asus\Documents\Retro\PS1Player\ROBLOX_IMPORT_GUIDE.md sections A and C3
- Podium exists only as a single planning bullet: PLAN.md:221 "Podium statt Textliste am Ende" and PLAN.md:262 milestone M4. Verdict is text-only today: MachineFlow.luau:673 sets verdict = viable and "VIABLE" or "REJECTED". No podium model, texture or sound exists anywhere on disk or in the place.
  - *Source:* PLAN.md:221,262 ; studio-src/ServerScriptService/KenopsiaServer/Services/MachineFlow.luau:673 ; grep -i podium over *.md and *.luau

## Problems

### Anim_Eat.fbx is authored, exported and documented — but is reachable by neither the published-id path nor the Studio fallback

- **Evidence:** AnimationIds.Player.Eat = 0 (AnimationIds.luau:32). The documented Studio fallback is AnimationIds.StudioSequences.Player.Eat = {"Anim_Eat", "Eat"} (line 70), but the measured RBX_ANIMSAVES contains 13 ObjectValues and none is named Anim_Eat (MCP execute_luau read). The FBX itself is 340,748 B, exported 2026-08-22 14:44, and has 196 KB of design docs behind it (docs_eat/).
- **Impact:** The single most recently authored piece of animation work in the project is dead weight. CanteenDiner deliberately loads no track when Eat == 0, so the seated diner still sits motionless through the bite — the exact gap ROBLOX_IMPORT_GUIDE.md section D2 says the clip was built to close. Neither the publish route nor the no-publish Studio route works today.
- **Fix idea:** In the Animation Editor, import export/anim/Anim_Eat.fbx onto the rig, name the save exactly Anim_Eat and the sequence inside it exactly Eat (that alone makes it work in Studio via the existing fallback), then Publish and paste the id into AnimationIds.Player.Eat.

### Anim_Stab.fbx has no AnimationIds entry at all — it is not even wired for a future id

- **Evidence:** export/anim/Anim_Stab.fbx is 327,132 B, exported 2026-08-22 14:44 alongside Anim_Eat by scripts/53_export_table.py (which names both as its outputs). AnimationIds.luau contains no Stab key in Player, StudioSequences.Player, or anywhere else; grep for 'Stab' across studio-src returns nothing.
- **Impact:** The fork-stab half of the two-clip table pair (42_anim_table.py authors Stab as the repeatable 6-frame punch-down, Eat as the one-shot bite) can never be played. The canteen eating loop is only ever half-implemented even after Eat is published.
- **Fix idea:** Decide whether Stab is shipping. If yes, add Player.Stab = 0 plus StudioSequences.Player.Stab = {"Anim_Stab", "Stab"} and import/publish it in the same Animation Editor pass as Eat. If no, delete the export so it stops reading as pending work.

### Lobby music is dead code — Music.Loop no longer exists in the place

- **Evidence:** KenopsiaClient.client.luau:256-267 setLobbyMusic does root.Music:FindFirstChild("Loop") and returns silently when nil. The measured KenopsiaAudio tree has a Music folder containing only Trials (birdhunt, minefield) — no Intro, Loop or Outro. audio-inventory.csv still lists all three (117311429031651 / 136345765095808 / 77820284893951).
- **Impact:** Every lobby is silent, and the setting toggle for Music does nothing there. The failure is invisible: no warn, no error, just an early return.
- **Fix idea:** Either re-create Music.Loop (the id is still recorded in audio-inventory.csv) or delete setLobbyMusic and its toggle. Also reconcile audio-inventory.csv, which now describes 39 Sounds where 34 exist.

### sfx("AccessGranted") is a permanent silent no-op

- **Evidence:** KenopsiaClient.client.luau:2153 (sfx(p.head and "AccessGranted" or "Confirm")) and :2162 (sfx("AccessGranted")). SFX_POOLS at line 236 is only { Click = "Clicks", Submit = "Submits" }, so AccessGranted falls through to folder:FindFirstChild("AccessGranted") — which the measured live tree does not contain.
- **Impact:** The round-start / access-granted moment has no sound at all, on the one beat where the UI most wants confirmation feedback. By contrast sfx("Submit") at :1561 survives only because the Submits pool happens to cover it.
- **Fix idea:** Upload access_granted_smx_1.ogg from Retro\System Status Alerts & Misc\Audio\OGG (which also has access_denied and please_stand_clear, the other two removed sounds) and re-create SFX.AccessGranted, or repoint the call at SFX.Confirm which does exist.

### 13 of 15 trials have no music and the Ambience folder is empty

- **Evidence:** Playlist.Ids lists 15 ids (Playlist.luau:31-35). Measured Music.Trials contains 2 Sounds: birdhunt and minefield. Ambience is an empty Folder. PLAN.md P3 records the same gap in German ("canteen hat keine Musik, Ambience ist leer").
- **Impact:** Thirteen trials — including all twelve new ones and canteen, which the ledger flags as blocker 5 / REQ-CP-04 — play in silence. updateTrialMusic matches Sound.Name against the active trial id, so a missing Sound is a silent no-op rather than a fallback to anything.
- **Fix idea:** Two source pools already exist locally: Echoes Soundtracks (34 tracks) and ROT Tracks/OST (30) + Ambient (3) + Cursed Music (2). Either one loop per trial (15 uploads) or the PLAN.md alternative of one base loop plus an intensity layer. Ambience is the cheapest win: 57 ambience files sit unused across Echoes (31) and ROT (26).

### All six face/expression textures are exported but none is uploaded, and no code would use them if they were

- **Evidence:** AnimationIds.Textures has PlayerBlink=0, PlayerHappy=0, PlayerHurt=0, BossAngry=0 (lines 41-42). The four PNGs exist (Player_Atlas_{Blink,Happy,Hurt}_1024.png ~27 KB each; Boss_Atlas_Angry_1024.png 26,842 B). Grepping PlayerBlink|PlayerHappy|PlayerHurt|BossAngry across every .luau in the repo returns only those two definition lines — no reader anywhere.
- **Impact:** Uploading the textures alone would change nothing. The blink/happy/hurt behaviour described in ROBLOX_IMPORT_GUIDE.md section E3 (blink every 3-5 s for 0.1 s, Hurt on hit, Happy on win) and the MP-03 boss EyesUp texture swap are both unimplemented, not merely unpublished.
- **Fix idea:** Bulk-import the four PNGs, paste the ids, then write the one small consumer: a blink timer plus hit/win hooks that set Player_Head.TextureID, and the Boss LookUp/EyesUp swap to BossAngry.

### The Canteen boss cannot be staged: the rig has moved, its prop slot does not exist, and one clip is aliased while another is 0

- **Evidence:** Measured: Workspace.Boss_Rig_scaleUnits is gone and ServerStorage.KenopsiaAssets.Rigs exists (M4 move done), but ServerStorage.KenopsiaAssets.Props holds only Minefield — there is no CanteenProtocol folder, so the CP_Observer / CP_Boss swap slots CanteenProps.makeObserver looks for are absent. AnimationIds.Boss.Reading is the LookUp id (78730370216852) rather than the authored Anim_Reading.fbx (404,972 B), whose save Anim_Reading holds only a 'Scene' sequence and no 'Reading'. Boss.Death = 0 despite Anim_Death.fbx and a valid 'Death of Player' 60kf save existing.
- **Impact:** Four separate things must land before the boss appears in the canteen, and today none of them is blocked by authoring — the art is all done. The Reading alias also means the boss visually re-uses LookUp held at speed 0 instead of the 121-keyframe reading loop that was actually animated.
- **Fix idea:** Create ServerStorage.KenopsiaAssets.Props.CanteenProtocol, drop the rig in as CP_Boss with an Animator, import Anim_Reading.fbx as its own save named Reading, and publish Anim_Death for Boss.Death.

### Every KeyframeSequence in RBX_ANIMSAVES is saved as Priority=Action and Loop=true, including the ones that must not be

- **Evidence:** Measured across all 13 holders: Idle 61kf, Walk 31kf, Run 21kf, Crouch 61kf, Push 41kf, LookingUp 45kf, LookDown 20kf, Shoot 50kf, 'Death of Player' 60kf — all report Enum.AnimationPriority.Action and Loop=true. MP-03 M1 flags the same thing ("all five are currently saved as Action, which would fight each other").
- **Impact:** If the Studio KeyframeSequence fallback is ever the active path — which warmup() makes likely, given the group/user ownership mismatch on the published ids — Idle, Walk, Run and Crouch all blend at the same priority and a looped Death/Shoot never ends. The published ids may or may not carry corrected priorities; the saves definitely do not.
- **Fix idea:** Fix priority and looping per clip in the Animation Editor before re-publishing (Idle=Idle, Walk/Run/Crouch=Movement, Push/Shoot/Death=Action; Loop off for Shoot, Death, LookUp, LookDown, Eat).

### Four of the six local sound kits have no licence instrument, and they are the ones the UI actually needs

- **Evidence:** Only PSX Tech, ROT and Rust & Blood carry an in-folder Game Asset License Agreement.pdf; the Retro-root copy covers PSX Textures II. Echoes - Audio Super Kit (471 files, incl. all 37 GUI sounds and 34 soundtracks), System Status Alerts & Misc (25 voice lines), Special Ambiences (2) and Super Retro Game OST (2) have none. No NOTES.txt exists anywhere under Retro — confirmed by search and corroborated by ASSET-LEDGER.md section 1.
- **Impact:** The two pools that would close the UI-sound and per-trial-music gaps are exactly the unlicensed ones. Every upload from them adds an INF row that becomes a Gate 7 blocker (ledger blocker 1, ~29 packs).
- **Fix idea:** Archive a dated store record for Echoes and System Status Alerts & Misc before uploading anything from them — they are almost certainly the same Pizza Doggy account as the three proven PDFs, so one purchase-history export likely clears both.

### Podium and verdict presentation have zero assets — the milestone is a single sentence

- **Evidence:** grep -i podium across every .md and .luau in the project returns PLAN.md:221 and PLAN.md:262 only. Verdict is a string literal: MachineFlow.luau:673 verdict = viable and "VIABLE" or "REJECTED". No podium mesh, texture, sound or arena marker exists in Retro, docs/assets, release/ or the live place.
- **Impact:** M4 ("Session trägt … Podium") cannot start from existing art. PLAN.md itself argues this is the shareable moment and therefore the reach that is currently being left on the table.
- **Fix idea:** Scope it from parts, not new modelling: three anchored blocks plus the existing per-trial camera pattern, the winner rig posed with the already-published Idle clip, one fanfare from Echoes Soundtracks, and reuse the existing SFX.Confirm/Count stingers. Add a VerdictStamp sound only if the text card stays.

### docs/assets/audio-inventory.csv is stale by 5 Sounds and MP-03 is stale on rig placement

- **Evidence:** The CSV lists 39 rows including Music.Intro/Loop/Outro and SFX.Submit/SubmitAlt/AccessGranted/AccessDenied/StandClear; the measured place has 34 Sounds and none of those five names. MP-03 section 1.1 describes both rigs as loose in Workspace; measured, both are gone from Workspace and ServerStorage.KenopsiaAssets.Rigs exists.
- **Impact:** Two of the three documents an agent would consult for asset state now disagree with the place. The CSV is also the ledger's machine-generated evidence file, so the ledger inherits the drift.
- **Fix idea:** Re-run the generator that produced audio-inventory.csv against the live place, and add a 'measured on' date line to both it and MP-03 section 1.

## Opportunities

### Publish Eat + Stab in one Animation Editor session and finish the canteen eating loop

- **Why:** The canteen trial's central beat — a table of PS1 characters actually eating while an Observer watches for movement — is the most distinctive thing in the game and it currently renders as four motionless seated figures with a flying fork. Both clips are authored, exported, solved against the seated bind pose, and documented across four EAT-*.md files.
- **Cost:** One Studio session, no authoring. Two imports, two priority/loop settings, two publishes, two numbers pasted into AnimationIds.luau.
- **Source:** export/anim/Anim_Eat.fbx + Anim_Stab.fbx (2026-08-22 14:44); AnimationIds.luau:24-32,70; ROBLOX_IMPORT_GUIDE.md section D2

### Fill Ambience from the 57 unused local ambience files before writing any new trial

- **Why:** PLAN.md P3 calls ambience "der billigste Weg zu Atmosphäre und derzeit ungenutzt", and it is right: the folder exists, the code path exists, and 57 files are sitting on disk (Echoes 31, ROT 26) plus two 35 MB long-form beds in Special Ambiences. Atmosphere carries across all 15 trials at once instead of one.
- **Cost:** A handful of uploads. Licence check needed for the Echoes half (ROT is covered by its in-folder PDF, so start there).
- **Source:** Measured empty Ambience folder; find counts over Retro/Echoes - Audio Super Kit/OGG/Ambiences and ROT - Horror Audio Bundle/Ambiences

### Use the 37 Echoes GUI sounds and the 25 System Status voice lines as the UI kit for the 12 new trials

- **Why:** MP-03 recommends new trials reuse pools rather than add per-trial folders, but the pools are thin: Clicks has 5, Submits has 3, and there is no error/success/tick/alarm variety at all. 37 GUI files plus spoken lines like target_locked, containment_breach_risk and atmospheric_hazard_detected are exactly the industrial-machine voice PLAN.md specifies (uppercase, industrial, no jokes).
- **Cost:** Licence evidence for two packs, then a batch upload and a small extension to SFX_POOLS in KenopsiaClient.
- **Source:** ls Retro/Echoes - Audio Super Kit/OGG/GUI (37) and Retro/System Status Alerts & Misc/Audio/OGG (25); KenopsiaClient.client.luau:236

### Resolve the animation ownership mismatch once, and 11 already-published ids start working

- **Why:** Eleven clips are published and paid for in effort, and the code says they may all be silently non-functional because they belong to user 4840146924 while the place belongs to group 832614570. One permissions pass per id turns the whole rig from a frozen A-pose into an animated character — the biggest visible change available for the least new work.
- **Cost:** Clicking 'share access' once per id in Creator Hub. Nothing in code can do it. AnimationIds.warmup() already prints whether it worked.
- **Source:** AnimationIds.luau:45-52, 108-150

### Import CP_Observer, which is already built and sitting in the repo

- **Why:** docs/assets/CP_Observer.fbx (47,932 B) plus its diffuse and a 17.5 KB generator script exist, and CanteenProps.makeObserver already has the swap slot wired — dropping the model into ServerStorage.KenopsiaAssets.Props.CanteenProtocol changes the visuals with zero code, replacing the procedural Lens/Eye/Stalk placeholder.
- **Cost:** One import, one folder creation, one texture upload.
- **Source:** docs/assets/CP_Observer.fbx + CP_Observer_Diffuse.png; tools/blender/build_cp_observer.py; measured Props contains only Minefield

### Treat the PS1Player script pipeline as the template for every future asset

- **Why:** 34 numbered, re-runnable, self-documenting Blender scripts with JSON intermediates, headless FBX probes (probe_fbx.py, probe_eat.py) and 114 review renders is an unusually disciplined setup — the boss rig was built the same way and 40_anim_eat.py explicitly documents why its clip differs. New props (podium, BH_Turret, arena kits) authored the same way stay reproducible instead of becoming one-off .blend files.
- **Cost:** None to adopt; the libraries (model_lib.py 12.7 KB, atlas_spec.py 6.6 KB, 37_solver_lib.py, 45_review_sheets.py) are already generic.
- **Source:** C:\Users\Asus\Documents\Retro\PS1Player\scripts\ (34 .py, 499 KB) and review/ (114 files)

### Build the podium out of the assets that already exist rather than modelling one

- **Why:** PLAN.md M4 wants a shareable winner moment. Everything needed is present: a published Idle clip for the pose, the PSX prop packs for staging, Echoes Soundtracks for a fanfare, and the existing per-trial camera pattern. Nothing here requires opening Blender.
- **Cost:** One arena marker plus a small presentation module; no new art.
- **Source:** PLAN.md:221,262; AnimationIds.Player.Idle=125600962447767; Retro/PSX Mega Pack II (3254 files)

### Point Kenopsia_Canteen_Import at the canteen arena's remaining procedural parts

- **Why:** 16 canteen-specific FBX meshes (checkout till, cups, drinks, and a Blood_Texture_Carrier) are sitting unimported in Retro\Kenopsia_Canteen_Import while CanteenProtocol builds 305 parts procedurally. They were clearly exported for this arena and never landed.
- **Cost:** Bulk import plus swap-slot wiring, same pattern as Props.Minefield.
- **Source:** ls Retro/Kenopsia_Canteen_Import (39 files, 16 FBX+fbm pairs); MP-03 section 1.5 (CanteenProtocol 305 parts)

## Open questions

- Is Anim_Stab.fbx meant to ship? It was exported in the same run as Anim_Eat by 53_export_table.py but has no AnimationIds key, no StudioSequences entry and no code reference — so it is either a forgotten wiring step or an abandoned idea.
- Do the 11 published animation ids actually play in place 110672791536316, or is the user-vs-group ownership mismatch documented at AnimationIds.luau:45-52 currently blocking all of them? warmup() prints the answer at server boot; reading the Studio console output would settle it in one call.
- Was Boss.Reading deliberately aliased to the LookUp id, or is that a placeholder from before Anim_Reading was imported? The save Anim_Reading exists but holds only a 'Scene' sequence with no 'Reading' inside it, which looks like an import that was never renamed.
- Are Echoes - Audio Super Kit, System Status Alerts & Misc, Special Ambiences and Super Retro Game OST Pizza Doggy purchases from the same account as the three packs with in-folder PDFs? If so one purchase-history export covers all four and unblocks the UI/music plan; if not, nothing should be uploaded from them.
- Per-trial music for 13 trials, or PLAN.md's base loop plus intensity layer? The two answers differ by roughly 13 uploads and 13 ledger rows versus about 3, and the choice gates how the audio work is scoped.
- Is Blender 4.2 or 5.2 the pipeline version? probe_fbx.py hard-codes the 4.2 path and both have the blender-mcp addon installed, but nothing records which one PS1Player.blend was last saved from — and it was saved 2026-08-22 15:08, after the session that produced the Eat/Stab exports.
- Is dev-src/ live work or an abandoned branch? It contains a StarterCharacter/Animate.client.luau and a UI/SoundBank.luau that would bear directly on the PS1 rig and the audio gaps, but default.project.json maps studio-src exclusively and dev-src has not been touched since 2026-08-12.
- Should audio-inventory.csv be regenerated against the live place? It is the ledger's evidence file and is now stale by 5 Sounds, which means ledger section 2 documents assets that no longer exist.
- Does the podium need the PS1 rig as StarterCharacter first? StarterPlayer.StarterCharacter does not exist and players are default R15, so a winner podium today would showcase generic Roblox avatars rather than the character 63 MB of pipeline was built for.
