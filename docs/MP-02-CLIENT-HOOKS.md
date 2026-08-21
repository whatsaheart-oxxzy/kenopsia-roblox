# MP-02 - Client hooks for the 12-trial port

Analyst report (Agent 1b). Source of truth: `studio-src\StarterPlayer\StarterPlayerScripts\KenopsiaClient.client.luau`
(2289 lines, verified diff-clean against the live place today), `MachineLayout.client.luau` (341),
`GoreClient.client.luau` (430), `ReplicatedFirst\KenopsiaLoading.client.luau` (121). GUI facts come from the
weppy mirror `weppy-project-sync\place_110672791536316_Kenopsia_MainGame\explorer\StarterGui\KenopsiaMachine`
(full sync 2026-08-14). Line numbers refer to the files as they stand today - re-grep before editing.

Verdict up front: the monolith already has a single packet funnel (`MachineState.OnClientEvent`, line 1865) and
a single camera writer (`RunService.RenderStepped`, line 471). Everything per-trial is either a local flag
(`sniperActive`, `canteenActive`), a substring test on the character attribute `XBotMoves`, or a hard-coded
`p.kind` branch. A generic dispatcher fits in with three insertions and one new `moveState`/camera mode - no
legacy branch needs to move.

---

## 1. How MachineState packets are received

| Line | What |
|---|---|
| 19-20 | `remotes = ReplicatedStorage.Kenopsia.Remotes`, `MachineState = remotes.MachineState` (RemoteEvent, server -> client only). |
| 819 | `TrialInput = remotes:WaitForChild("TrialInput", 20)` - the ONE client -> server trial remote (see §3). |
| 1865 | `MachineState.OnClientEvent:Connect(function(p)` - the funnel. Everything below is `if p.kind == ... then ... return end` in this order: |

Order of the branches inside the funnel (each ends with `return`):

| Line | kind | Handler / effect |
|---|---|---|
| 1867 | `huntersetup` | `setHunterSetup(sniperActive)` (Bird look-speed panel). |
| 1871 | `mines` | `showMines(p.list)` - Dead Zone reveal marks. NOTE: no `trialId` field on this packet. |
| 1875 | `role` | see §2.4 - the shared role/camera/movement handler. `p.role == "spectate"` returns at 1876-1887 BEFORE the token line. |
| 1933 | `gorefx` | `applyGoreFx(pos, power, force)` - shake + screen blood (generic, any trial may send it). |
| 1941-1983 | `cpstate cpobs cpmiss cpdone cpout cpend` | Canteen HUD readouts (§2.3). None carries `trialId`. |
| 1985 | `count` | `sfx("Count"..n)`, on n==3 `hideAll()` + Fader fade-in, CountText "3/2/1". Generic - every trial uses it. |
| 2010 | `hitmark` | dead (nothing sends it). |
| 2034 | `go` | sniper gates, `sfx("AccessGranted")` (asset missing -> silent), CountText "GO!", Fader off, `pendingRunner` -> `moveState="runner"` + `applyMovement()`, RunnerYou label. Generic. |
| **2072** | **fallthrough** | `session += 1` (cancels every running typewriter/roll animation), hides `JoinCover`, `setLobbyMusic(kind in {selection,info,score})`, then `selection / info / status / round / score / announce / hide` (2080-2094). `info` also does `machine:SetAttribute("TrialId", p.id)` (2083). **Any unknown kind lands here and bumps `session`** - so a new per-trial packet that is not intercepted before line 2072 silently kills a typewriter mid-word and stops the lobby music toggle from being correct. |

Payload shapes actually sent by the server today (MachineFlow.luau unless stated):

- `selection {icons={3 names}, chosen=1..3}` (preFlow, lobby only) - `info {name, icon, id [,index,total]}` - `status {lines={...}}` -
  `round {n, total, verbs=tagline}` - `score {board={ {userId,displayName,place,points,score} }, trialId, index, total, final}` -
  `announce {text [,style="death"]}` - `hide {}`.
- Trials: `role {role="runner"|"sniper"|"none"|"spectate", frozen, camDir, camStyle="top"|nil, roundToken, pos={x,y,z}, look={x,y,z}, watch={userIds}}`
  (Minefield 409/487/547/805, BirdHunting 405/455/718, CanteenProtocol 557/650), `count {n}`, `go {}`, `mines {list}`,
  `huntersetup {}`, `gorefx {pos,power,force}`, `cp* {...}`.
- Note `score` DOES carry `trialId` - a dispatcher must not route on "has trialId" alone.

## 2. Where the per-trial code lives

### 2.1 minefield ("DEAD ZONE")
- HUD/props: none in the GUI - reveal marks are pooled world Parts: `acquireMark/releaseMark/showMines` 918-970; sonar ring `spawnWave` 826-847 (clones `ReplicatedStorage.KenopsiaAssets.MF_SonarRing`); touch button `TouchControls.Btn_SCAN` (visibility in `setRunnerTouch` 782-801, keyed on `XBotMoves` containing "scan").
- Input: `firePulse` 849-878 sends `TrialInput:FireServer{trialId="minefield", action="pulse", roundToken=trialRoundToken}` + `sfx("Click")`; hold logic `setScanHeld` 880-897; bindings F / ButtonY / Btn_SCAN at 985-1013 (`InputBegan/InputEnded`), guarded only by `charScanAllowed()` (= `XBotMoves` contains "scan", plain-text `string.find` WITHOUT the plain flag).
- Camera: role packet carries `camStyle="top"` -> `runnerCamStyle` (1915) -> RenderStepped 495-499: eye = root + (0, 24, -9*camDir), look straight down-forward, lerp 6/s. Runner cam ALSO forces `Humanoid.AutoRotate=false` and rewrites `root.CFrame` yaw every frame (503-506) and `bindForwardOnly()` (361-375) drops backward input. Lighting: `enterDZLight/exitDZLight` 276-341 keyed on `player:GetAttribute("KenopsiaActiveTrial") == "minefield"` (344-349).
- Movement: `applyMovement` 400-414: WalkSpeed 7 if `XBotMoves` contains "scan" else 14 while `moveState=="runner"`, else 0; JumpPower always 0.
- Cleanup: server sends `role none` (Minefield 339) -> 1891 `trialRoundToken=nil`, 1892-1900 hides CountText, `runnerCam=false`, `unbindForwardOnly`, `restoreCamera()` (1929). Marks expire on their own timer (975-984). Music/light follow the attribute going "".

### 2.2 birdhunt ("BIRD HUNTING")
- HUD: `Scope`, `HipCross`, `TouchControls.Btn_FIRE/SCOPE/ZOOM` (GUI-authored), `HunterLookSetup` panel built 58-149, `ScopeLookSpeed` 121-137. Viewmodel `buildViewmodel` 561-599 (clones `KenopsiaAssets.SniperRifle`), `setSniperRig` 626-664, `setSniperLight` 1298-1335.
- Input: `fireShot` 676-697 uses its OWN remotes `SniperFire`/`SniperAim` (22-27), not TrialInput; bindings 699-720 (LMB/RMB/R2/L2/Y), touch/gamepad aim 723-745, wheel zoom 1284-1293; all guarded by `sniperActive`/`sniperCanFire`. Runner touch punch/crouch use `XBotPush`/`XBotCrouch` remotes (28-29, 802-816).
- Camera: RenderStepped 1337-1432 (turret cam, `sniperBase` from `Workspace["Bird Hunting"].SniperPost/Start`); runners use the chase branch 500-503 (`camStyle` nil -> "chase").
- Cleanup: `role none` -> `setSniperRig(false)` (destroys viewmodel, MouseBehavior default), `setSniperLight(false)`, `setHunterSetup(false)`.

### 2.3 canteen ("CANTEEN PROTOCOL")
- HUD: `buildCanteenHud` 1042-1150 (Frame `CanteenHud` under `machine`, ZIndex 66, edge UIStroke glow + `Phase` label + bottom `Panel` with `Ration` text and 4 fork pips); `cpSetState` 1152-1161, `cpSetPhase` 1163-1183; touch pad `buildCanteenTouch` 1197-1245 (Frame `CanteenTouch`, ZIndex 68, two 110px TextButtons); `cpShowHud/cpHideHud` 1247-1265.
- Input: `cpSend` 1185-1192 -> `TrialInput:FireServer{trialId="canteen", action="plate"|"mouth", roundToken=trialRoundToken}` + `sfx("Click")`, client cooldowns 0.16/0.35 s (mirrors of server gates); bindings 1270-1281 (LMB/L2 plate, RMB/R2 mouth) guarded by `canteenActive`; touch via the pad.
- Camera: server sends `role spectate` per diner (CanteenProtocol 557) -> fixed `spectateCF` at the seat cam (RenderStepped 473-486).
- Cleanup: `cpend` -> `cpHideHud()`; `role none` at 650.

**F-1 (bug, verify in Framework stage):** CanteenProtocol 557 sends `roundToken` inside a `role="spectate"` packet, but the client returns at 1887 before `trialRoundToken = p.roundToken` (1891). `cpSend` therefore echoes nil and CanteenProtocol 472 (`payload.roundToken ~= st.roundToken`) drops every plate/mouth. Nothing else delivers the token to a diner. The dispatcher's token adoption (§5.1, step A) fixes this as a side effect if placed before the spectate early-return; keep that in mind when deciding whether the fix is in scope.

### 2.4 The shared `role` handler (1875-1931) - what a NEW trial would inherit
```
spectate -> spectateCF/watch set, runnerCam=false, RETURN (token NOT adopted)
else     -> spectate cleared; trialRoundToken = p.roundToken
            role=="none": CountText hidden
            sniperActive = role=="sniper"; setSniperRig/Light; setRunnerTouch(role=="runner")
            role~="runner": RunnerYou hidden, AutoRotate=true
            runnerCam = role=="runner"; camDir/camStyle; pendingRunner
            moveState = (runner and not frozen) and "runner" or "frozen"; applyMovement()   <- WalkSpeed 0 for any other role
            MouseIconEnabled = role~="runner"; bind/unbindForwardOnly; restoreCamera() if not runner/sniper
```
Consequence: any role value a new trial invents ("player", "carver") is treated as `frozen` + camera restored + mouse shown. Runner role brings forced yaw + forward-only + lane camera. Neither is what a free-moving top-down trial wants, so new trials must NOT reuse `kind="role"` for their own participants (they MAY reuse `role="spectate"` for dead players - it is harmless - and `role="none"` is not needed, see §5).

## 3. TrialInput - what the client sends
Flat table, no envelope: `{ trialId = "<id>", action = "<verb>", roundToken = <string from the role packet> }`
(minefield 856-860, canteen 1188-1192). Server side (Minefield 226-247, CanteenProtocol 467-473) checks in this order:
type table -> `trialId` == own id -> action known -> acceptInput window -> `room.phase == "Playing"` ->
`room.sessionId == st.sessionId` -> `payload.roundToken == st.roundToken` -> membership/state -> per-action rate gate.
`Shared/Net/Envelope.luau` (v/sessionId/trialId/trialToken/roundToken/seq/action/data + `Envelope.validate`) exists but is
NOT used by any shipped trial or by the client. Recommendation for the kit: send the flat legacy fields PLUS `v=1`, `seq`
(per-client monotonic) and `data=extra`, so a generic server validator can run `Envelope.validate` with
`expected={trialId, roundToken, lastSeq}` and legacy trials keep working untouched. `sessionId`/`trialToken` are unknown to
the client today (no packet carries them); if the server-side design wants them validated, the trial's `begin` packet (§5.2)
must carry them and the kit echoes whatever it was given.

## 4. Roulette / lobby - where registry fields appear
| Registry field | Where shown | Line |
|---|---|---|
| `icon` | `showSelection` 1531-1631: 3 tiles cloned from `Selection.IconPool[name]`, fallback `"Crosshair"` when the name is missing (1539); `showInfo` 1633-1652 clones the same icon into `Info.SelIcon.Holder`. | 1539, 1642 |
| `displayName` | `showInfo`: typewrites `"NEXT SIMULATION: <name>"` into `Info.NextLabel`; `showStatus` line 1 (server puts `displayName` in `lines[1]`, MachineFlow 391). | 1648, 1655 |
| `tagline` | `status` lines[2] (MachineFlow 392) and `round` card `Verbs` (MachineFlow 415 `verbs = trial.tagline`, client 1685). | 1685 |
| `subtitle` | **never sent to the client** - unused today. |
| `id` | `info.id` -> `machine:SetAttribute("TrialId", id)` (2083); MachineLayout `applyControlsText` (line 200) picks `TRIAL_TEXT[TrialId]` **or falls back to `TRIAL_TEXT.birdhunt`** - a new id shows the SNIPER controls text unless MachineLayout gets a row (or a neutral fallback); the CONTROLS pager `hasSecondPage()` (client 2183) is `TrialId == "canteen"`. |

`DECOY_ICONS` (MachineFlow 94) = `{ "Magnifier", "Saw", "Factory", "Train", "Bug" }` - decoys fill the two non-chosen tiles when fewer than 3 trials are enabled; with 15 trials enabled the decoy list is never used (runSelection 198-221 draws the two "others" from real trial icons).

**Icons that exist in `StarterGui.KenopsiaMachine.Selection.IconPool` (mirror of 2026-08-14):**
`Bug, Crosshair, Cube, Factory, Magnifier, Saw, Train, Utensil` - eight names. `Utensil` is unused today (Canteen uses `Saw`).
An icon is a `Frame` (78x78, AnchorPoint .5/.5, BackgroundTransparency 1, Visible false) containing 7-9 solid child `Frame`s
(19x19 pixel blocks, BackgroundColor3 PHOSPHOR 120/255/170, BorderSizePixel 0) - i.e. pixel art made of frames. `setTileLit`
(1521-1529) recolours every opaque Frame/UIStroke under the tile to PHOSPHOR/DIM, so any new icon built the same way (blocks
of Frames, optional UIStroke) lights correctly. Adding an icon = one new Frame under `IconPool` named `<Icon>` with block
children (Integrate-stage Studio edit, or a small builder like `tools/build-canteen-arena.luau`); no client code change.
Plan guidance: with 15 trials, 8 icons is not enough for distinct tiles - either accept reuse (the roulette does not check
uniqueness) or ship ~7 new pixel-block icons in the Integrate stage. Unknown names silently render `Crosshair`.

## 5. How the client knows the active trial
- `player:GetAttribute("KenopsiaActiveTrial")` (server: MachineFlow `setActiveTrial` 181-187, set to `trial.id` right after the round-card `hide` and BEFORE `runRound` (MachineFlow 424), cleared to `""` after every round (438) and in match `cleanup` (293)) - drives trial music (`Music.Trials.<id>` Sound, 245-274) and DZ lighting. This is the abort-safe signal: it is cleared on every exit path.
- `machine:GetAttribute("TrialId")` - client-side, written by the `info` packet (2083); lobby-only, used by MachineLayout controls text and the pager.
- Per-trial packets themselves (`mines`, `cp*`, `role`) carry NO trialId; the legacy code relies on the local flags set by `role`.
- Ordering caveat: attribute replication and RemoteEvent delivery are not guaranteed to arrive in one order, so the dispatcher must route on a `trialId` field inside the packet and only use the attribute as the teardown safety net.

---

## 6. Generic dispatcher - precise design

Files: `StarterPlayerScripts\TrialClientKit.luau` (ModuleScript, pure helpers), `StarterPlayerScripts\TrialClients\` (Folder) with
`<id>.luau` ModuleScripts returning `{ init(kit), onPacket(payload), onEnd() }`; all added to `default.project.json` under
`StarterPlayerScripts` (`"TrialClientKit": {"$path": ...}`, `"TrialClients": {"$className":"Folder", "<id>": {"$path": ...}}`).

### 6.1 Wire protocol for new trials (server side must follow this)
- Every packet a new trial sends to its clients: `{ kind = "trial", trialId = "<id>", ev = "<event>", ... }`. Reserved events:
  `begin {roundToken, roundIndex, roundCount [,sessionId]}` (first packet of every round, to every audience member),
  `end {}` (last packet, every exit path incl. abort - MachineFlow's attribute clear is the backstop), everything else free
  (`state`, `hit`, `tile`, ...). Payloads that need a fresh token (re-role mid-round) include `roundToken` again.
- Dead-player cameras: legacy `{kind="role", role="spectate", pos, look, watch}` may be reused unchanged (it does not touch
  movement or flags). Countdown/GO/announce/hide/gorefx: reuse the legacy kinds unchanged.
- Never send `role runner/sniper/none` from a new trial. Never set `XBotMoves` to a value containing `scan`, `eat`, `sneak`,
  `push` (substring tests at 400-414, 769-778, 821-825, 1035-1038 would enable legacy input paths). Leave `XBotMoves` empty.

### 6.2 Insertion points in KenopsiaClient.client.luau (three edits + one mode)
**A. Router state + require, after line 201 (`local trialRoundToken = nil`)** - add
```lua
local TrialClientKit = require(script.Parent:WaitForChild("TrialClientKit"))
local trialClientsFolder = script.Parent:FindFirstChild("TrialClients")
local trialRouter = nil -- built after the helpers it closes over exist (see D)
```
**B. Movement mode - `applyMovement` 400-414**: add a third state:
```lua
local trialWalkSpeed = 0
...
if moveState == "runner" then ... 
elseif moveState == "trial" then hum.WalkSpeed = trialWalkSpeed
else hum.WalkSpeed = 0 end
```
(`applyMovement` already re-runs on `CharacterAdded` 416-419, so a respawn keeps the trial speed.)

**C. Camera mode - RenderStepped 471-509**: add ONE branch before `elseif runnerCam`:
```lua
elseif trialCam then          -- table {mode="top"|"fixed"|"follow", ...} owned by the router
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = TrialClientKit.computeCamera(trialCam, player.Character, camera, dt)
```
`spectateCF` stays first (server-driven death cam wins), so `role spectate` keeps working for new trials. `computeCamera` for
`mode="top"` reproduces 495-499 (eye = root + (0, height, -back), lerp 6/s, look at root) WITHOUT the yaw lock 503-506 and
without `bindForwardOnly`. `restoreCamera()` (464-469) is what `onEnd` calls after clearing `trialCam`.

**D. Packet routing - top of the funnel, line 1866 (right after `if type(p) ~= "table" then return end`)**:
```lua
if trialRouter and trialRouter.handle(p) then return end
```
`trialRouter.handle(p)`:
1. If `p.kind == "trial"` and `type(p.trialId)=="string"`: 
   - `ev=="begin"`: if another module is active, end it (idempotent); `require(trialClientsFolder[trialId])` in pcall (missing module -> `warn`, drop, return true); call `init(kit)` once per module (router memoises), mark active, adopt `p.roundToken`, then forward `onPacket(p)`. Return true.
   - `ev=="end"`: `endActive()` (calls `onEnd()` in pcall, then router cleanup: unbind all keys/render callbacks, destroy the trial HUD frame and touch pad, `trialCam=nil` + `restoreCamera()`, `moveState="frozen"` + `applyMovement()`, hide `CountText`, `MouseIconEnabled=true`, `trialRoundToken=nil`). Return true.
   - other `ev`: if the packet's `trialId` == active id, adopt `roundToken` if present, `onPacket(p)` in pcall; else drop (stale). Return true.
   Return true in every `kind=="trial"` case so nothing reaches line 2072.
2. Else if a module is active and `p.kind` is one of `count | go | announce | hide | gorefx | role`: adopt `p.roundToken` if present (this is the F-1 fix when applied to `role spectate`), forward a copy to `onPacket` (observe-only, pcall), **return false** so the legacy handler still runs (countdown card, GO, fader, spectate cam).
3. Else return false.

**E. Teardown safety net - next to line 274/349 (attribute listeners)**:
`player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(function() if trialRouter and trialRouter.activeId ~= (player:GetAttribute("KenopsiaActiveTrial") or "") then trialRouter.endActive() end end)` -
covers abort paths where the server never got to send `end` (MachineFlow cleanup 293 always clears the attribute). Optional belt: also `endActive()` when a lobby kind (`selection|info|score`) reaches line 2078.

The router itself is ~60 lines of the client file (it must close over `machine`, `sfx`, `TrialInput`, `trialRoundToken`, `moveState/applyMovement`, `restoreCamera`, `touchAllowed`, `camera`); everything reusable lives in the kit module.

### 6.3 TrialClientKit API (what `init(kit)` receives)
```
kit.trialId, kit.roundToken (live), kit.player, kit.machine (KenopsiaMachine ScreenGui, read-only), kit.isActive()
kit.send(action, extra?, cooldown?)   -> TrialInput:FireServer{trialId, action, roundToken, seq, v=1, data=extra}; drops when not active/no token; per-action client cooldown (like cpSend 1185)
kit.hud()                             -> lazily created Frame "TrialHud_<id>" under machine: full size, BackgroundTransparency 1, ZIndex 58 (below Announce 60 / Fader 70 so death cards & fades cover it; above lobby screens at 1); destroyed by the router on end
kit.pad()                             -> lazily created Frame "TrialTouch_<id>" ZIndex 68 (same as TouchControls, above Scope.Mask 65), Visible = touchAllowed(); destroyed on end
kit.touchAllowed()                    -> the client's touchAllowed() (35-40)
kit.label(parent, {text,size,pos,anchor,color,align})   -> TextLabel Font=Enum.Font.Code, TextColor3 default IDLE, BackgroundTransparency 1 (Canteen Phase label 1074-1085 is the model)
kit.panel(parent, size, pos)          -> Frame BackgroundColor3 (9,12,10) BackgroundTransparency .25 BorderSizePixel 0 (Canteen Panel 1087-1096)
kit.button(parent, name, text, pos, color, onActivated) -> TextButton 110x110, bg (12,16,13) transp .2, UICorner 12, Font Code 18 (Canteen buttons 1213-1233); returns the button
kit.edgeGlow(color, transparency, tweenSecs)            -> the Canteen UIStroke edge glow (1064-1072/1163-1183)
kit.typewrite(label, text, cps)       -> the client typewrite (387-397) bound to the router's own generation token
kit.sfx(name)                         -> the client sfx() (211-228): SoundService.KenopsiaAudio.SFX; pools Click->Clicks, Submit->Submits; existing names: Click ClickAlt Confirm Count1-5 Hover ImpactBody Reject Warning + pools Blood BulletRicochet MineExplosions SniperFire SniperReload Clicks Submits (AccessGranted is referenced but absent -> silent). New SFX = new Sound under SFX (Integrate stage)
kit.palette                           -> PHOSPHOR 78FFAA, IDLE 8CE8AE, DIM 2E6B4A, AMBER FFBA3C, DANGER (255,58,44), WARN (255,176,40), SAFE (120,208,128), PANEL (9,12,10), INK (2,6,4), BLOOD (120,8,6); plus the world PS1 palette shared with the server arena builder (define once in the kit, mirror in the server palette module)
kit.camera.top({height=24, back=9, lerp=6}) | kit.camera.follow({offset=Vector3, look=Vector3}) | kit.camera.fixed(cf) | kit.camera.restore()   -> sets/clears trialCam (6.2 C)
kit.movement.set(walkSpeed) | kit.movement.freeze()     -> moveState "trial"/"frozen" + applyMovement (6.2 B); JumpPower stays 0
kit.bindKey(name, {Enum.KeyCode.E, Enum.UserInputType.MouseButton1, ...}, onBegan, onEnded?) / kit.unbind(name)   -> UserInputService InputBegan/InputEnded with gameProcessed guard and isActive guard; all removed on end
kit.onRender(fn(dt)) / kit.onHeartbeat(fn(dt))          -> connections tracked and disconnected on end
kit.mouseRay(maxDist, filter?)        -> camera:ViewportPointToRay(mouse) + workspace:Raycast (tile/target picking for Chisel/Stable Footing/Filter-style trials); on touch uses the last tap position
kit.character() / kit.root()          -> current character / HumanoidRootPart or nil
kit.gore(pos, power)                  -> applyGoreFx (1849-1861) for local-only feedback
kit.arena(name?)                      -> workspace.KenopsiaArenas.<id> (WaitForChild-free FindFirstChild; nil until replicated)
```
Contract for modules: `init(kit)` runs once per client lifetime (memoised) - build nothing yet, just capture kit; `onPacket(p)`
receives every `kind="trial"` packet of this trial (including `begin`) plus observed generic kinds; `onEnd()` releases module
state - the router already tears down HUD/pad/keys/render/camera/movement, so a module rarely needs more than clearing tables.
Every callback the module schedules re-checks `kit.isActive()`.

### 6.4 Not interfering with the three legacy branches
- The three legacy trials never send `kind="trial"`, so router step 1 never fires for them; step 2 only observes when a NEW module is active, and `KenopsiaActiveTrial` is a different id then. Legacy flags (`sniperActive`, `canteenActive`, `runnerCam`, `spectateCF`) are untouched.
- The new `moveState="trial"` and `trialCam` are only ever set through the kit; legacy `role` handling still writes `moveState` "runner"/"frozen" and `runnerCam`, and `endActive()` returns both to their idle values, so a legacy trial after a new one starts clean. `endActive()` must run BEFORE the next trial's `role` packet - the `end` packet / attribute clear happen at round end, the next trial's role arrives after Reveal+Briefing holds (>=10 s), so ordering is safe.
- Legacy input handlers stay gated by `XBotMoves` substrings and their flags (§6.1 rule keeps them dead during new trials). The kit's `bindKey` uses its own connections and never touches `TouchControls`.
- Music/lighting attribute listeners (245-274, 344-349) need no change: a `Music.Trials.<id>` Sound is optional; the DZ light is keyed on `"minefield"` only.
- MachineLayout: add a `TRIAL_TEXT` row per new id (or change the fallback at line 200 from `TRIAL_TEXT.birdhunt` to a neutral generic row) and extend `hasSecondPage()` (2183) if a trial needs a scoring page. Recommended: move the per-trial controls text into a data-only ModuleScript `TrialClients\_ControlsText.luau` that MachineLayout requires, so a new trial ships text and client module together. Note the placeholder Font on CountText etc. is Inconsolata via `Enum.Font.Code` - keep it.
- Line 2072 fallthrough: guaranteed unreachable for `kind="trial"` because step 1 always returns true.

### 6.5 Line-anchored edit list (for the Framework agent)
1. L201+ : router locals / kit require (A).
2. L399-414 : `trialWalkSpeed` + `moveState=="trial"` branch (B).
3. L471-509 : `elseif trialCam` branch before `elseif runnerCam` (C).
4. L1866 : `if trialRouter and trialRouter.handle(p) then return end` (D).
5. L1859-1863 (after `applyGoreFx`, before the funnel) : build `trialRouter` here - all closed-over locals exist by then (`sfx` 211, `touchAllowed` 35, `hideAll` 377, `applyMovement` 400, `restoreCamera` 464, `TrialInput` 819, `applyGoreFx` 1849, `typewrite` 387).
6. L274/349 area or after the funnel : `KenopsiaActiveTrial` teardown listener (E).
7. Optional F-1 fix: move `trialRoundToken = p.roundToken` above the `spectate` early-return (1876) or let router step 2 adopt it.
8. MachineLayout L200 fallback + `TRIAL_TEXT` rows; client L2183 pager condition.
9. `default.project.json`: `TrialClientKit`, `TrialClients` folder + one entry per module.
