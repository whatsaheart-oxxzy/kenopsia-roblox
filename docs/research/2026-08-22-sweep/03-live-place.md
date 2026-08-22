# Live Roblox Studio state (Edit datamodel) of Kenopsia_MainGame, placeId 110672791536316, studio_id c39e925b-2e9e-4d46-a465-65c4b6a8ec59

> Read-only research lens, measured 2026-08-22 (workflow wf_a13d7aec-54c). Facts cite their source; treat plan documents as claims, measurements as truth.

## Summary

Studio is in Edit mode only (get_studio_state: "Current Studio Mode: Edit", "Available DataModels: Edit"). No Play was entered; every read below is a pure execute_luau/inspect read.

CODE PARITY IS PERFECT. 62 LuaSourceContainers live under ServerScriptService/ReplicatedStorage/StarterPlayer/StarterGui/ReplicatedFirst; 62 files in studio-src. Every one matches on both #Source and the h=(h*31+byte)%2^31 checksum computed live in Luau and again in Python over the mirror bytes. 0 DIFFERENT, 0 MIRROR-ONLY, 0 LIVE-ONLY. StarterGui contains zero scripts (all UI is built imperatively by KenopsiaClient). Note KenopsiaClient.client.luau is the only file whose bytes contain CRLF (85124 raw vs 82711 LF-normalized) — and Studio's live Source has the identical CRLF bytes, so it is byte-identical, not a line-ending drift.

The real gaps are content, not code. AnimationIds has 4 placeholder zeros left: Player.Eat, Boss.Death, Textures.PlayerBlink/Happy/Hurt, Textures.BossAngry. Worse, the Studio fallback for Eat is also dead: StudioSequences.Player.Eat expects a holder named "Anim_Eat" in ServerStorage.RBX_ANIMSAVES and no such holder exists (13 holders present, none named Anim_Eat). So the diner's bite has no clip on any path.

UI: StarterGui.KenopsiaMachine is a single ScreenGui, 520 descendants, 15 direct children (Status, Score, Selection, Info, RoundCard, Briefing, JoinCover, CountText, Announce, Fader, Scope, HipCross, SettingsPanel, HitMark, TouchControls). There is no frame named HUD, Ready or Final — Ready is a button inside Info, and the end-of-round screen is Score. Only Selection is Visible=true at rest. The whole UI is fixed-pixel: exactly 1 UIScale and 1 UIAspectRatioConstraint in 520 descendants, and zero UIListLayout/UIGridLayout/UIPadding anywhere.

Scene: 3 arenas in Workspace (CanteenProtocol 306 parts, "Dead Zone" 400, "Bird Hunting" 261), 4 loose props at top level, Baseplate still present. Canteen rig markers are complete and symmetric (Seats/PlateAnchors/ForkAnchors/MouthTargets/PlayerCameras/ExecutionMuzzles, 4 each with SeatIndex attributes) — but there is no Fork or Beans_Fork part anywhere in the game; ForkAnchors is the only "fork" name that exists. Lighting has a Sky and nothing else: no ColorCorrection, Bloom, Blur, Atmosphere or DepthOfField, despite fog being tuned (60→480, near-black red). Zero RemoteEvents in ReplicatedStorage at edit time.

## Facts

- Studio state: Current Studio Mode = Edit; Available DataModels = Edit; Focused DataModel in viewport = Edit. No Play session.
  - *Source:* MCP call mcp__Roblox_Studio__get_studio_state(studio_id=c39e925b-2e9e-4d46-a465-65c4b6a8ec59)
- 62 LuaSourceContainers exist live under ServerScriptService, ReplicatedStorage, StarterPlayer, StarterGui, ReplicatedFirst. StarterGui contributes 0 of them.
  - *Source:* execute_luau (Edit) walking the 5 service roots, emitting GetFullName|ClassName|#Source|h
- studio-src contains exactly 62 files (find . -type f | wc -l = 62).
  - *Source:* C:\Users\Asus\Claude\Kenopsia_Roblox Project\studio-src (bash find/wc)
- ALL 62 scripts are IDENTICAL live vs mirror on both byte length and the h=(h*31+b)%2147483648 checksum. DIFFERENT = 0, MIRROR-ONLY = 0, LIVE-ONLY = 0.
  - *Source:* Luau checksum pass vs python -c checksum pass over C:\Users\Asus\Claude\Kenopsia_Roblox Project\studio-src
- Largest live scripts: StarterPlayer.StarterPlayerScripts.KenopsiaClient (LocalScript, 85124 B, h=1340381855); ServerScriptService.KenopsiaServer.Services.Minefield (36455 B, h=1768027261); Services.BirdHunting (34419 B, h=1212089549); Services.CanteenProtocol (32701 B, h=886525972); Services.TrialKit (30825 B, h=2136941216); Services.MachineFlow (27222 B, h=696594332); StarterPlayerScripts.TrialClientKit (24781 B, h=1417056466); Services.CanteenProps (22691 B, h=458735814); Services.RoomService (19829 B, h=1586950905).
  - *Source:* execute_luau checksum table (Edit)
- KenopsiaClient.client.luau is the only mirror file containing CRLF: raw 85124 B / h=1340381855, LF-normalized 82711 B / h=1423187590. The LIVE Source is 85124 B with the same h=1340381855, i.e. Studio's Source itself holds CRLF — the pair is byte-identical.
  - *Source:* python checksum row 'StarterPlayer/StarterPlayerScripts/KenopsiaClient.client.luau|85124|1340381855|82711|1423187590' vs live row
- ServerScriptService.KenopsiaServer.Main is only 340 B (h=1326411704) — a thin bootstrap; all server logic lives in the 23 ModuleScripts under KenopsiaServer.Services.
  - *Source:* execute_luau checksum table; ServerScriptService children = KenopsiaServer [Folder] kids=2
- Live AnimationIds non-zero ids — Player: Idle=125600962447767, Walk=123033497454830, Run=95031726336950, Crouch=125766316179596, Push=70937503697406, Death=114200780379540. Player.Eat = 0.
  - *Source:* script_read game.ReplicatedStorage.Kenopsia.Shared.Config.AnimationIds lines 17-33
- AnimationIds.Boss: Reading=78730370216852, Idle=95540888860028, LookUp=78730370216852 (same asset as Reading), LookDown=76111131902834, Shoot=87302586462797, Death=0.
  - *Source:* script_read AnimationIds lines 35-39
- AnimationIds.Textures: PlayerNeutral=136734973177857, BossNeutral=130641113899237 are live; PlayerBlink=0, PlayerHappy=0, PlayerHurt=0, BossAngry=0.
  - *Source:* script_read AnimationIds lines 40-43
- AnimationIds.PlayerSpeeds = { Walk = 4.5, Run = 10.95, Push = 3.15 }, used with AdjustSpeed.
  - *Source:* script_read AnimationIds line 34
- StudioSequences.Player = Idle/Walk/Run/Crouch/Push -> {"PS1Player_AllAnims", <name>}, Death -> {"Anim_Death","Death of Player"}, Eat -> {"Anim_Eat","Eat"}. StudioSequences.Boss = Idle -> {"Anim_Idle","Idle",100} (min 100 keyframes to disambiguate the two Anim_Idle holders), LookUp/Reading -> {"Anim_LookUp","LookingUp"}, LookDown -> {"Anim_LookDown","LookDown"}, Shoot -> {"Anim_Shoot","Shoot"}, Death -> {"Anim_Death","Death of Player"}.
  - *Source:* script_read AnimationIds lines 62-77
- warmup(): server-only, runs once, task.spawn'd. Resolves Boss/Idle; if nil -> publishedPlayable=false. Otherwise builds a throwaway Model+AnimationController+Animator in workspace, LoadAnimation, Play, polls track.Length>0 for up to 3 s (os.clock deadline, task.wait(0.1)), Stop(0), Destroy, sets publishedPlayable. On failure it warns; in Studio it falls back to RBX_ANIMSAVES sequences via KeyframeSequenceProvider:RegisterKeyframeSequence.
  - *Source:* script_read AnimationIds lines 107-150
- load() prefers the Studio-registered sequence whenever publishedPlayable==false OR the published id is 0/nil: `if AnimationIds.publishedPlayable == false or uri == nil then uri = studioUri(group,name) or uri end`. Animation instances are cached per group/name/uri; every failure path returns nil, never throws.
  - *Source:* script_read AnimationIds lines 166-183
- ServerStorage.RBX_ANIMSAVES has 13 holders: PS1Player_AllAnims (Idle 61kf, Walk 31, Run 21, Push 41, Crouch 61), Anim_Push, Anim_Crouch, Anim_Run, Anim_Walk, Anim_Idle (Scene 61 / Idle 61), Player_Rig_scaleUnits (empty), Anim_LookUp (LookingUp 45kf), Anim_Shoot (Shoot 50kf), Anim_Reading (Scene 121kf only), Anim_LookDown (LookDown 20kf), Anim_Idle (Scene 121 / Idle 121 — the boss one), Anim_Death (Death of Player 60kf). Total 29785 descendants.
  - *Source:* execute_luau enumerating ServerStorage.RBX_ANIMSAVES children + GetKeyframes()
- StarterPlayer live: CharacterUseJumpPower=true, CharacterJumpHeight=7.1999998, CharacterJumpPower=0, AutoJumpEnabled=false, CharacterWalkSpeed=12, CameraMode=Enum.CameraMode.Classic, DevTouchMovementMode=UserChoice, DevComputerMovementMode=UserChoice, EnableMouseLockOption=true, CharacterMaxSlopeAngle=89, LoadCharacterAppearance=true, Health/NameDisplayDistance=100.
  - *Source:* execute_luau property probe on game:GetService("StarterPlayer")
- Players: CharacterAutoLoads=true, RespawnTime=3, MaxPlayers=60. Workspace: StreamingEnabled=FALSE, Gravity=196.2, FallenPartsDestroyHeight=-500. TextChatService: CreateDefaultTextChannels=TRUE, CreateDefaultCommands=true, ChatVersion=TextChatService. StarterGui: ScreenOrientation=Sensor, ShowDevelopmentGui=true.
  - *Source:* execute_luau service property probe
- StarterGui.KenopsiaMachine [ScreenGui]: IgnoreGuiInset=true, ResetOnSpawn=false, DisplayOrder=50, Enabled=true, ZIndexBehavior=Sibling, ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets, SafeAreaCompatibility=FullscreenExtension, ClipToDeviceSafeArea=true, 520 descendants. It is StarterGui's only child.
  - *Source:* execute_luau inspect of StarterGui.KenopsiaMachine
- KenopsiaMachine's 15 direct children with ZIndex/Visible: Status(Z1,false), Score(Z1,false), Selection(Z1,TRUE), Info(Z1,false), RoundCard(Z1,false), Briefing(Z1,false), JoinCover(Z90,false), CountText TextLabel(Z80,false), Announce(Z60,false), Fader(Z70,false), Scope(Z65,false), HipCross(Z66,false), SettingsPanel(Z82,false,430x330 px centered), HitMark TextLabel(Z67,false), TouchControls(Z68,false). Frames named HUD, Ready and Final do NOT exist.
  - *Source:* execute_luau child enumeration of StarterGui.KenopsiaMachine
- All full-screen frames use AnchorPoint (0,0), Position {0,0},{0,0}, Size {1,0},{1,0}: Status, Score, Selection, Info, RoundCard, Briefing, JoinCover, Announce, Fader, Scope, TouchControls.
  - *Source:* execute_luau child enumeration
- Selection (the roulette) children: GrungeWash [ImageLabel], CenterDark [Frame+UIGradient], Tiles [Frame] holding Tile1/Tile2/Tile3 (each 128x128 px, AnchorPoint 0.5,0.5, at X=0.30 / 0.50 / 0.70, Y=0.5), CrossH, CrossV, BootText ("Simulation bootst:", TextSize 14, Visible=false), IconPool [Frame, 0x0, Visible=false] with 8 icons: Cube, Magnifier, Crosshair, Saw, Factory, Utensil, Train, Bug (each 78x78). 106 descendants.
  - *Source:* execute_luau depth-2 walk of StarterGui.KenopsiaMachine.Selection
- Info frame (144 descendants) children: Grunge (Top/Bottom 70px bars, Left/Right 90px bars — note Right is at Position X scale 1.00272846, a ~0.27% overhang), TopTicker, NextLabel ("NEXT SIMULATION: ------"), SelIcon (147x141 at {0,15},{0,30}) with 8 corner Frames all literally named "Frame" plus Holder(78x78, the only UIScale in the GUI), ControlsWindow (0.4554x0.5509 scale, 2 pages, PageLabel "Page 1/2"), Roster (4 rows, all Visible=false), Btn_READY TextButton ("R E A D Y", 0.38 wide x 80px, at Y {0.1166,330}), NavCluster (Marker/Track/Gauge), Btn_SETTINGS TextButton (150x36, Z=55, AnchorPoint 1,0, Position {0.99013555,0},{-0.00592053961,56} — a NEGATIVE Y scale).
  - *Source:* execute_luau depth-2 walk of StarterGui.KenopsiaMachine.Info
- RoundCard has only 2 descendants: Title TextLabel ("Round 1/3", TextSize 58, Y=0.38) and Verbs TextLabel ("MEMORIZE. INSPECT. ALIGN._", TextSize 20, Y={0.38,66}). No background, no UIScale.
  - *Source:* execute_luau depth-2 walk of StarterGui.KenopsiaMachine.RoundCard
- Score frame (87 descendants): Grunge bars, Ticker (Text width 2.0 scale for marquee), ConclusionLabel, ScoreName, Odometer (Digit1-4 at 86x118 px, 96 px pitch, plus Pedestal), RankList (Row1-4, all Visible=false), BinaryBlocks (Header + 18 hard-coded 8-bit TextLabels Bin1_1..Bin3_6).
  - *Source:* execute_luau depth-2 walk of StarterGui.KenopsiaMachine.Score
- Status frame (16 descendants): Grunge bars + TypeLine1..TypeLine7, all Text="" and Visible=false, 18 px pitch starting at Y=30, X offset 46.
  - *Source:* execute_luau depth-2 walk of StarterGui.KenopsiaMachine.Status
- TouchControls (37 descendants) holds 7 TextButtons, all pixel-anchored bottom-right: Btn_FIRE (104x104 at 1,-24/1,-24, Visible=true), Btn_SCOPE (76x76 at 1,-38/1,-148, Visible=true), Btn_ZOOM (64x64, false), Btn_PUNCH (104x104, false), Btn_CROUCH (76x76, false), Btn_SCAN (76x76, false), Btn_EAT (76x76, false). Btn_SCOPE, Btn_CROUCH, Btn_SCAN and Btn_EAT all occupy the identical rect {1,-38},{1,-148} 76x76 — they are mutually exclusive slots. Parent TouchControls is Visible=false.
  - *Source:* execute_luau depth-2 walk of StarterGui.KenopsiaMachine.TouchControls
- SettingsPanel (63 descendants): 430x330 centered, UIStroke, Serration strip built from 40 identical 5px Frames all named "Frame", Title, three toggle rows Row_UISOUND / Row_MUSIC / Row_REDUCEFLICKER (each Text + Check 30x30 + full-size Hit TextButton at Z=83), Btn_CLOSE 150x42 bottom-centered.
  - *Source:* execute_luau depth-2 walk of StarterGui.KenopsiaMachine.SettingsPanel
- UI modifier census across all 520 KenopsiaMachine descendants: UIStroke=53, UICorner=29, UIGradient=17, UIScale=1, UIAspectRatioConstraint=1, UIListLayout=0, UIGridLayout=0, UIPadding=0, UISizeConstraint=0, UITextSizeConstraint=0. The only two are StarterGui.KenopsiaMachine.Info.SelIcon.Holder.UIScale and StarterGui.KenopsiaMachine.Scope.Mask.UIAspectRatioConstraint.
  - *Source:* execute_luau ClassName census over StarterGui.KenopsiaMachine:GetDescendants()
- SoundService has exactly one child: KenopsiaAudio [Folder], 42 descendants. Subfolders Music/Trials, Ambience (EMPTY), SFX.
  - *Source:* execute_luau recursive walk of SoundService
- Music/Trials: birdhunt rbxassetid://71143122243344 vol 0.24 Looped=true; minefield rbxassetid://132499516846518 vol 0.45 Looped=true. Those are the only two music tracks and the only two Looped sounds in the whole tree.
  - *Source:* execute_luau SoundService walk
- SFX flat sounds: Click 71275573444924 v0.45, ClickAlt 132164304600477 v0.45, ImpactBody 83335185987012 v0.90 (roll 8/120), Reject 114448879961050 v0.70, Hover 71275573444924 v0.16 (same asset as Click), Warning 93861370808858 v0.65, Confirm 130292722664147 v0.60, Count5 117149096126658, Count4 88984010858075, Count3 125929365204512, Count2 90490572986710, Count1 132909621965246 (all v0.75).
  - *Source:* execute_luau SoundService walk
- SFX sub-folders: SniperFire/Primary 118803023612410 v1.45 (roll 15/420); BulletRicochet/Primary 83668417079973 v1.10 (6/140); SniperReload/Primary 83110281478101 v1.70 (8/150); Clicks/Click1-5 (136898832673181, 136745293101522, 115728252091834, 111557351602976, 132683279963887) v0.60; Submits/Submit1-3 (79171960825561, 111991322032307, 109725832591895) v0.60; MineExplosions/Explode1-4 (86475991650982, 76737678985387, 71471343684752, 75789945781051) v0.90 (12/220); Blood/Blood1-2 (127560368697616, 86853838840785) v0.85 (8/120). Every non-positional sound keeps the default RollOffMaxDistance 10000.
  - *Source:* execute_luau SoundService walk
- Workspace top-level children (10): CanteenProtocol [Folder, 79 kids, 472 desc, 306 BaseParts], "Dead Zone" [Folder, 150 kids, 711 desc, 400 parts], "Bird Hunting" [Folder, 186 kids, 593 desc, 261 parts], Terrain, Baseplate [Part @ (0,-8,0)], gear_mx_1 [Model], saw_blade [Model], SniperRifle_PSX [Model], bench [Model], Camera.
  - *Source:* execute_luau Workspace:GetChildren() with per-subtree BasePart counts
- Arena extents (BasePart position bounding boxes): CanteenProtocol 306 parts, min (-144.4,0.5,-49.9) max (0.0,32.8,37.3), center (-72.2,16.7,-6.3). "Dead Zone" 400 parts, min (-268.9,0.4,-1940.9) max (-60.8,43.4,-1536.1), center (-164.8,21.9,-1738.5). "Bird Hunting" 261 parts, min (-169.7,-0.8,374.9) max (178.4,81.3,767.0), center (4.3,40.3,570.9). Total 967 arena parts.
  - *Source:* execute_luau bbox pass over the three arena folders
- Loose top-level props not in any arena and not Terrain/Camera/Baseplate: exactly 4 — gear_mx_1 (pivot 15.97,-55.13,-114.38), saw_blade (15.97,-55.19,-114.38), SniperRifle_PSX (-284.62,9,-589.58), bench (-11.07,2.62,583.50). gear_mx_1 and saw_blade sit ~55 studs BELOW the baseplate, far from every arena.
  - *Source:* execute_luau Workspace child enumeration + GetPivot()
- Workspace.CanteenProtocol.Rig [Folder] has 10 children / 34 descendants: Seats, PlateAnchors, ForkAnchors, MouthTargets, PlayerCameras, ExecutionMuzzles (4 parts each, SeatIndex 1-4), plus BossSeat, SpectatorCamera, ObserverCamera, Observer. Every marker is a 0.6^3 Part, Anchored=true, Transparency=1, CanCollide=false.
  - *Source:* execute_luau recursive walk of Workspace.CanteenProtocol.Rig with GetAttributes()
- Seat markers Y=12.31: P1 (-98.34,12.31,-21.28), P2 (-82.34,12.31,-21.28), P3 (-98.34,12.31,9.72), P4 (-82.34,12.31,9.72). Each carries attributes DinerLift=0, DinerScale=1, DinerSeated=true, SeatIndex=n. BossSeat (-115.75,12.31,-5.70) attribute BossScale=1.
  - *Source:* execute_luau Rig walk
- PlateAnchors Y=13.60: P1 (-98.60,13.60,-11.45), P2 (-82.80,13.60,-11.45), P3 (-98.60,13.60,0.35), P4 (-82.80,13.60,-0.05). Note P3/P4 Z differ by 0.40 while P1/P2 share Z exactly.
  - *Source:* execute_luau Rig walk
- MouthTargets Y=14.31: P1 (-98.36,14.31,-20.68), P2 (-82.37,14.31,-20.68), P3 (-98.36,14.31,9.12), P4 (-82.37,14.31,9.12). ForkAnchors Y=15.20: P1 (-98.55,15.20,-13.25), P2 (-82.72,15.20,-13.25), P3 (-98.55,15.20,2.15), P4 (-82.72,15.20,1.75).
  - *Source:* execute_luau Rig walk
- Cameras: ObserverCamera at (-63.04,26.00,-5.40); SpectatorCamera at (-93.00,25.27,20.30); Observer at (-93.00,20.27,-5.70); PlayerCameras P1 (-98.15,18.81,-28.70), P2 (-82.00,18.81,-28.70), P3 (-98.14,18.81,17.14), P4 (-81.99,18.81,17.14). ExecutionMuzzles all at Y=30.00 directly above each seat's XZ.
  - *Source:* execute_luau Rig walk
- ServerStorage.KenopsiaAssets.Rigs has 2 rigs. CanteenBoss [Model, 6 kids / 30 desc]: AnimationController, Boss_Body (Mesh 120564744640037), Boss_Head (140393163764203), Boss_Newspaper (103717996765526), Boss_Pistol (130680735362056) — all MeshParts, RenderFidelity=Precise, TextureID=rbxassetid://130641113899237 — plus RootPart [Part 2x2x1].
  - *Source:* execute_luau enumeration of ServerStorage.KenopsiaAssets.Rigs
- PS1Player [Model, 7 kids / 103 desc]: AnimationController, AnimSaves [ObjectValue], InitialPoses [Folder, 72 children], Player_Body (Mesh 121596309152455), Player_Bag (90439124030871), Player_Head (89019499333728) — MeshParts, RenderFidelity=Precise, TextureID=rbxassetid://136734973177857 — plus RootPart.
  - *Source:* execute_luau enumeration of ServerStorage.KenopsiaAssets.Rigs
- No Fork or Beans_Fork part exists in either rig, in ServerStorage at all, or anywhere in the DataModel. A case-insensitive name scan of game:GetDescendants() returns exactly ONE hit: Workspace.CanteenProtocol.Rig.ForkAnchors [Folder].
  - *Source:* execute_luau global name scan for 'fork' over game:GetDescendants()
- Lighting: Ambient (0.298,0.259,0.259), OutdoorAmbient (0.416,0.369,0.369), Brightness 1.2, ClockTime 9.4, GlobalShadows=true, ShadowSoftness 0.2, EnvironmentDiffuseScale=0, EnvironmentSpecularScale=0, ExposureCompensation=0, FogColor (0.173,0.086,0.078), FogStart 60, FogEnd 480.
  - *Source:* execute_luau Lighting property probe
- Lighting has exactly ONE child: KenopsiaSky [Sky], SkyboxUp=rbxassetid://125893393204256, SunTextureId=rbxasset://sky/sun.jpg. There is no ColorCorrectionEffect, BloomEffect, BlurEffect, Atmosphere, SunRaysEffect or DepthOfFieldEffect in Lighting.
  - *Source:* execute_luau Lighting:GetChildren() with per-class formatting
- ReplicatedStorage children: KenopsiaAssets [Folder: Effects, SniperRifle (21 kids), MF_SonarRing (18 kids)] and Kenopsia [Folder, 1 kid, 23 desc]. ReplicatedFirst: KenopsiaLoading [LocalScript] only. ServerScriptService: KenopsiaServer [Folder] only.
  - *Source:* execute_luau service child enumeration
- ZERO RemoteEvent / RemoteFunction / UnreliableRemoteEvent instances exist under ReplicatedStorage in the Edit datamodel — the remote surface is created at runtime (Shared.Net.Envelope), so nothing is inspectable statically.
  - *Source:* execute_luau filter over ReplicatedStorage:GetDescendants() for Remote* classes — empty result
- ServerStorage also holds KenopsiaAuthoring [Folder: AnimationSources 14 kids/1746 desc, MasterRigs 2 kids/207 desc] and RBX_ANIMSAVES [Model, 29785 descendants].
  - *Source:* execute_luau ServerStorage:GetChildren()
- ServerStorage.KenopsiaAssets.Props holds only Minefield content: MF_Mine (Body+RevealGlow PointLight, Cap, Bolt0-3, PivotRoot), MF_Crater (Scorch, ScorchInner, Chunk0-5, PivotRoot), MF_SonarRing (Center, Seg0-15, PivotRoot), and MF_Hunter_Shredder (18 MeshParts, all RenderFidelity=Automatic, all TextureID EMPTY, each with a SurfaceAppearance except Scanner_Lens_L/R.001).
  - *Source:* execute_luau recursive walk of ServerStorage.KenopsiaAssets.Props
- screen_capture of the Edit viewport (ScreenCapture_1): a near-black green-tinted scanline/noise field with six green corner brackets forming three empty 128px selection tiles — i.e. StarterGui.KenopsiaMachine.Selection.Tiles rendered over the viewport (StarterGui.ShowDevelopmentGui=true), with no 3D geometry visible behind it.
  - *Source:* MCP call mcp__Roblox_Studio__screen_capture(capture_id=ScreenCapture_1)
- Console output (full buffer, 17 lines — fewer than 60 exist): joined live-editing session; MCP Studio plugin ready; [LogHandlers] Started log capture; [WeppyRobloxMCP] Plugin loaded v2.14.5; [WorkspaceWatcher] Initialized; command channel attempt started; [SelectionMonitor] started; 'Requiring asset 13178582173' from the third-party plugin cloud_10366079803 'Add Easy Textures'; [SyncManager] Error: Failed to send sync start: Place 129909297895850 is currently syncing. Only one place can sync at a time.; [SyncManager] init session cleanup acknowledged {state: idle, placeId 110672791536316}; [SyncWatcher] Stopped; AssistantCommand:25: attempt to call a nil value (this last one is my own malformed execute_luau, not game code).
  - *Source:* MCP call mcp__Roblox_Studio__get_console_output(studio_id=c39e925b-...)
- No game-authored runtime warnings or errors are present in the console buffer — no [AnimationIds] warn, no service boot output at all, consistent with Edit mode never having run the server.
  - *Source:* mcp__Roblox_Studio__get_console_output

## Problems

### The Eat animation is dead on BOTH paths — no published id and no Studio fallback holder

- **Evidence:** AnimationIds.Player.Eat = 0 (script_read AnimationIds line 32) and StudioSequences.Player.Eat = {"Anim_Eat","Eat"} (line 70). ServerStorage.RBX_ANIMSAVES contains 13 holders and NONE is named Anim_Eat (execute_luau enumeration: PS1Player_AllAnims, Anim_Push, Anim_Crouch, Anim_Run, Anim_Walk, Anim_Idle, Player_Rig_scaleUnits, Anim_LookUp, Anim_Shoot, Anim_Reading, Anim_LookDown, Anim_Idle, Anim_Death). studioUri() therefore returns nil and load() returns nil.
- **Impact:** The Canteen diner's bite has no clip in Studio or in production. The comment at AnimationIds lines 24-31 claims this is the one bespoke clip that preserves the seated leg pose, so the eat beat will read as a frozen sitter. This is the single highest-value missing asset.
- **Fix idea:** Import Documents\\Retro\\PS1Player\\export\\anim\\Anim_Eat.fbx in the Animation Editor, save it as a holder literally named "Anim_Eat" with the sequence inside named "Eat" (matching line 70), then publish and paste the id into Player.Eat.

### No Fork / Beans_Fork part exists anywhere, yet ForkAnchors markers are fully authored

- **Evidence:** Workspace.CanteenProtocol.Rig.ForkAnchors has 4 positioned markers at Y=15.20 with SeatIndex 1-4. A case-insensitive 'fork' scan over game:GetDescendants() returns exactly one instance — that folder. ServerStorage.KenopsiaAssets.Rigs (CanteenBoss, PS1Player) and .Props (Minefield only) contain no fork mesh.
- **Impact:** Whatever CanteenDiner/CanteenProps is meant to clone onto the ForkAnchors has no source asset in the place. The fork half of the Table Manners loop cannot render.
- **Fix idea:** Either author/import the fork MeshPart into ServerStorage.KenopsiaAssets.Props (alongside Minefield) or confirm it is generated procedurally by CanteenProps.luau; if procedural, the anchors are fine and this is a non-issue worth documenting.

### Four texture ids and Boss.Death are still 0

- **Evidence:** AnimationIds.Textures: PlayerBlink=0, PlayerHappy=0, PlayerHurt=0, BossAngry=0 (lines 41-42); AnimationIds.Boss.Death=0 (line 38). Only PlayerNeutral=136734973177857 and BossNeutral=130641113899237 exist, and both are the TextureID actually applied to every rig MeshPart.
- **Impact:** Faces never change expression — no blink, no hurt reaction, no boss anger tell. Boss death has no published clip (its Studio fallback Anim_Death does exist, so it works in Studio only).
- **Fix idea:** Publish the four face textures and the boss death clip, or delete the placeholder keys so callers stop probing them.

### Lighting has no post-processing at all despite a heavily art-directed fog/ambient setup

- **Evidence:** Lighting:GetChildren() returns exactly one instance, KenopsiaSky [Sky]. FogColor is (0.173,0.086,0.078) with FogStart 60 / FogEnd 480, Ambient is warm-desaturated, EnvironmentDiffuseScale and EnvironmentSpecularScale are both 0 — but there is no ColorCorrectionEffect, BloomEffect, BlurEffect or Atmosphere.
- **Impact:** The PS1/analogue-horror grade the UI is chasing (grunge washes, scanlines, 53 UIStrokes) stops at the GUI layer; the 3D render is ungraded. Any CRT/desaturation look must currently be faked per-frame in client code or is simply absent.
- **Fix idea:** Add a ColorCorrectionEffect (saturation down, slight warm tint) plus a low-threshold Bloom in Lighting, and gate them behind the existing SettingsPanel Row_REDUCEFLICKER toggle.

### The entire 520-instance GUI is fixed-pixel with no layout or scaling system

- **Evidence:** UI modifier census over StarterGui.KenopsiaMachine:GetDescendants(): UIListLayout=0, UIGridLayout=0, UIPadding=0, UISizeConstraint=0, UITextSizeConstraint=0, UIScale=1 (only Info.SelIcon.Holder), UIAspectRatioConstraint=1 (only Scope.Mask). Concrete pixel values everywhere: SettingsPanel 430x330, Odometer digits 86x118 at 96px pitch, Selection tiles 128x128, TouchControls buttons 104x104/76x76, Status TypeLines at 18px pitch, TextScaled=false with hard TextSize 13-58 on every label.
- **Impact:** Phone and small-window layouts will overflow or shrink to illegibility — 13px TextSize on a 400px-wide phone is unreadable, and the 430px SettingsPanel plus the 320px Info.ControlsWindow Serration will clip. ScreenInsets=DeviceSafeInsets + ClipToDeviceSafeArea=true makes the usable area smaller still.
- **Fix idea:** Add one UIScale on the ScreenGui root driven by viewport height (scale = math.min(1, viewportY/720)) — a single instance fixes every child proportionally without touching the 520-element hand-placed layout.

### Two authoring artefacts sit in the Info/Btn_SETTINGS geometry: an out-of-range scale and a negative Y scale

- **Evidence:** StarterGui.KenopsiaMachine.Info.Grunge.Right Position = {1.00272846,-90},{0,0} (X scale >1). StarterGui.KenopsiaMachine.Info.Btn_SETTINGS Position = {0.99013555,0},{-0.00592053961,56} (negative Y scale).
- **Impact:** Both look like drag-in-Studio residue rather than intent. The Right grunge bar hangs ~0.27% of viewport width off-screen; Btn_SETTINGS's negative Y scale means its vertical position drifts with viewport height instead of staying pinned, so on tall viewports it creeps upward toward/behind the 70px top grunge bar.
- **Fix idea:** Snap Grunge.Right to {1,-90},{0,0} and Btn_SETTINGS to {1,-16},{0,56} with AnchorPoint (1,0).

### Baseplate and two orphan props are still in the shipping Workspace

- **Evidence:** Workspace children include Baseplate [Part @ (0,-8,0)], plus gear_mx_1 and saw_blade whose pivots are (15.97,-55.13,-114.38) and (15.97,-55.19,-114.38) — roughly 55 studs below the baseplate and ~1500-2500 studs from every arena centre (arena centres: -72,17,-6 / -165,22,-1739 / 4,40,571).
- **Impact:** Dead geometry that ships to every client, plus a default Baseplate visible under the arenas. saw_blade/gear_mx_1 also read as leftovers from a scrapped Cut-To-Spec trial.
- **Fix idea:** Move gear_mx_1 and saw_blade into ServerStorage.KenopsiaAssets.Props if a trial still needs them, otherwise delete; remove Baseplate once every arena has its own floor (all three do: 'Floor Canteen Protocol', 'Minefield Ground', 'Grass').

### StreamingEnabled is false with 967 arena parts spread over ~2700 studs of Z

- **Evidence:** Workspace.StreamingEnabled=false (execute_luau probe). CanteenProtocol centre Z=-6.3, "Dead Zone" centre Z=-1738.5, "Bird Hunting" centre Z=570.9; total 967 BaseParts across the three arenas (306+400+261) plus 1776 total arena descendants.
- **Impact:** Every client loads all three arenas up front even though the machine runs one trial at a time. On mobile that is the whole map resident in memory for a game that only ever shows one arena.
- **Fix idea:** Either turn on StreamingEnabled (the arenas are already spatially far apart, which is ideal for it) or have RoomService parent the two inactive arena folders out of Workspace.

### Ambience sound folder is empty while both music tracks are trial-specific

- **Evidence:** SoundService.KenopsiaAudio.Ambience [Folder] has zero children. Music/Trials contains only birdhunt (0.24 vol) and minefield (0.45 vol) — nothing for CanteenProtocol or for the Selection/Info lobby.
- **Impact:** The lobby, the roulette and the entire Canteen trial run in silence apart from UI clicks; the two music volumes are also 2x apart from each other, so trial-to-trial loudness will jump.
- **Fix idea:** Add a lobby/ambience bed under Ambience and a canteen track under Music/Trials, and normalise birdhunt up toward minefield's 0.45.

### Weppy sync is blocked by a different place and the watcher has stopped

- **Evidence:** Console: '[SyncManager] Error: Failed to send sync start: Place 129909297895850 is currently syncing. Only one place can sync at a time.' followed by '[SyncWatcher] Stopped'.
- **Impact:** Live file-sync into placeId 110672791536316 is not running right now. It happens to be harmless today because all 62 scripts already checksum-match the mirror, but any edit made on either side from now on will silently diverge.
- **Fix idea:** Release the sync lock held by place 129909297895850 before the next edit session, and re-run the checksum comparison after reconnecting.

### A third-party plugin is fetching assets inside this session

- **Evidence:** Console: 'Requiring asset 13178582173. Callstack: cloud_10366079803.Add Easy Textures.Modules.PluginUpdates line 27/26 - getLatestVersion, cloud_10366079803.Add Easy Textures.Loader line 47'.
- **Impact:** 'Add Easy Textures' is live in the Studio session doing network update checks. Not a game bug, but it is a third party with edit rights over the same DataModel these measurements were taken from — worth knowing when diffing unexplained instance changes.
- **Fix idea:** Disable the plugin during measured/audit sessions so the tree is provably only touched by the project.

## Opportunities

### Ship one UIScale on the KenopsiaMachine ScreenGui root, keyed off viewport height

- **Why:** Mobile is where Roblox growth is, and DevTouchMovementMode=UserChoice plus a fully authored 7-button TouchControls frame proves mobile is an intended platform. Right now every one of the 520 elements is hard pixels (TextSize 13 on Status TypeLines, 430px SettingsPanel), so phones get an unreadable, clipped version of a UI that is otherwise beautiful.
- **Cost:** ~15 lines in KenopsiaClient plus one instance; no layout rework needed
- **Source:** UI modifier census (UIScale=1 of 520 descendants); StarterGui.KenopsiaMachine.TouchControls 7 buttons; StarterPlayer.DevTouchMovementMode=UserChoice

### Add ColorCorrection + Bloom to Lighting and wire them to the existing SettingsPanel.Row_REDUCEFLICKER toggle

- **Why:** The accessibility toggle already exists in the live UI and the fog is already art-directed toward a warm-black analogue look — the 3D layer is the only part of the game not participating in the grade. This is the cheapest possible upgrade to how the game reads in a screenshot or thumbnail, which is what drives clicks.
- **Cost:** 2 instances + ~20 lines
- **Source:** Lighting:GetChildren() = KenopsiaSky only; FogColor (0.173,0.086,0.078); StarterGui.KenopsiaMachine.SettingsPanel.Row_REDUCEFLICKER

### Turn on StreamingEnabled now, before a fourth arena lands

- **Why:** The three arenas are already ~2300 studs apart in Z, which is the textbook layout for streaming. Doing it while there are 967 parts is far cheaper than after the map doubles, and it directly cuts join time — the single biggest funnel drop for a new player.
- **Cost:** One property plus a pass over any code that assumes an instance is present at join
- **Source:** Workspace.StreamingEnabled=false; arena centres Z=-6.3 / -1738.5 / 570.9; 306+400+261 parts

### Publish Anim_Eat and the four face textures together as one asset batch

- **Why:** These five zeros are the only things standing between the Canteen trial and its intended performance — the bite plus blink/happy/hurt/angry faces are the whole emotional read of Table Manners. AnimationIds already degrades gracefully, so this is pure upside with zero code risk.
- **Cost:** Manual Animation Editor + texture upload session; no code changes (ids drop into lines 32 and 41-42)
- **Source:** script_read AnimationIds lines 32, 38, 41-42; RBX_ANIMSAVES holder list missing Anim_Eat

### Deduplicate the eight anonymous 'Frame' corner brackets and the 40-Frame Serration strip into a reusable builder

- **Why:** Info.SelIcon has 8 children all named 'Frame' and SettingsPanel.Serration has 40 — the same bracket/serration motif recurs across Selection tiles, SettingsPanel and ControlsWindow. A single helper makes the retro chrome cheap to apply to new screens, which is what lets new trials ship with matching polish instead of plain frames.
- **Cost:** Refactor inside KenopsiaClient (85KB, already the largest file — this shrinks it)
- **Source:** execute_luau walks of Info.SelIcon (8x 'Frame') and SettingsPanel.Serration (40x 'Frame')

### Fill SoundService.KenopsiaAudio.Ambience and add a Canteen music bed

- **Why:** Two of the three trials have music; the Canteen — the one built around tension and stillness — has none, and the lobby/roulette is silent. Ambience is the cheapest tension multiplier in a horror-adjacent game, and the folder is already there waiting.
- **Cost:** 2-3 audio assets, parented into the existing folder structure
- **Source:** SoundService.KenopsiaAudio.Ambience has 0 children; Music/Trials holds only birdhunt and minefield

### Fold the four mutually-exclusive TouchControls slot buttons into one context button

- **Why:** Btn_SCOPE, Btn_CROUCH, Btn_SCAN and Btn_EAT all sit at the identical rect {1,-38},{1,-148} 76x76 — four instances competing for one slot. One button whose label/handler swaps per trial removes a whole class of 'two buttons visible at once' bug and makes adding a fifth trial verb a one-line change.
- **Cost:** Small refactor in the TouchControls setup path
- **Source:** execute_luau walk of StarterGui.KenopsiaMachine.TouchControls — 4 buttons at identical Position/Size

### Keep the Luau-vs-Python checksum sweep as a standing CI/pre-session check

- **Why:** It just proved 62/62 parity in one pass, and it caught the subtle CRLF case (KenopsiaClient 85124 vs 82711 bytes) that a naive text diff would have reported as a false positive. With Weppy sync currently blocked by another place, this is the only thing that would catch silent divergence.
- **Cost:** Already written — the two snippets used in this audit
- **Source:** execute_luau checksum table vs python checksum over studio-src; console '[SyncWatcher] Stopped'

## Open questions

- ForkAnchors exists with 4 positioned markers but no fork asset exists anywhere in the DataModel — is the fork built procedurally at runtime by CanteenProps.luau (22691 B) / CanteenDiner.luau (13430 B), or is it a genuinely missing import? I did not read those two modules.
- Zero RemoteEvents exist under ReplicatedStorage in Edit mode, so the entire client/server contract is invisible statically. Confirming it would need reading Shared/Net/Envelope.luau (6512 B) or a Play session, which was out of scope here.
- AnimationIds.publishedPlayable is nil at edit time and warmup() only runs on a server, so I could NOT measure whether the published ids actually play in this place. The module's own comment (lines 45-52) says place 110672791536316 belongs to GROUP 832614570 while every id was published by user 4840146924 — the permission grant may still be outstanding. Only a Play/live run prints '[AnimationIds] published animation ids play in this place'.
- RBX_ANIMSAVES holds Anim_Reading with a 121-keyframe Scene but no child named 'Reading', while StudioSequences maps Reading -> {'Anim_LookUp','LookingUp'} (45 kf). Is Anim_Reading dead weight (29785 descendants total in RBX_ANIMSAVES) or is the mapping wrong?
- Two holders are both named Anim_Idle (Scene 61/Idle 61 for the player, Scene 121/Idle 121 for the boss). The min-keyframe guard (100) disambiguates the boss, but nothing guards the player path if holder order ever changes — is that intentional fragility?
- gear_mx_1 and saw_blade sit at Y=-55, ~55 studs under the Baseplate. Are these staged for an unbuilt CutToSpec/SortingFloor arena, or abandoned? CutToSpec.luau and SortingFloor.luau are both only ~2970 B — the same stub size as the other 11 unimplemented trial services (Breather, Carrier, Clearance, ClearTheDeck, Crawler, FloorCheck, PalletDuty, Ricochet, Upstream, ArmsIssue), versus 22-36 KB for the three that are real.
- Only 3 of the ~14 trials have a Workspace arena (CanteenProtocol, Dead Zone/Minefield, Bird Hunting) and only 3 server services exceed 10 KB. Is the intended shipping scope 3 trials with 11 stubs, or are the stubs expected to be filled before launch?
- The screen capture shows the Selection UI painted over an otherwise empty dark viewport — I could not tell whether the Edit camera is simply parked away from geometry or whether ShowDevelopmentGui is fully occluding the scene. A camera-positioned capture at an arena centre would settle it but I kept to the single sanity capture requested.
- SoundService itself was not probed for RespectFilteringEnabled / DistanceFactor / AmbientReverb — only its children were walked.
- Lighting.Technology returned ERR (not readable via the property probe in this Studio build), so I cannot report whether the place is on Voxel, ShadowMap or Future — which materially changes how much the missing post-processing would buy.
