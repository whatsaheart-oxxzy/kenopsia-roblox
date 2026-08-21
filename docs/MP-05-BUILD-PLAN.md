# MP-05 — BUILD PLAN (single source of truth for the 12-trial port)

Status: PLAN, synthesised 2026-08-17 from MP-01 (server contract), MP-02 (client hooks),
MP-03 (assets), MP-04 (trial designs). Where the four disagreed this file decides; the
decisions and their reasons are in §0. Anything not covered here: MP-01 wins for server
behaviour, MP-02 for the client, MP-03 for assets, MP-04 for game feel.

> IP NOTE (REQ-IP-01). The reference game's minigame names appear ONLY in `docs/` (this file,
> MP-04). They must not appear in `studio-src/`, `tests/`, `default.project.json`, Studio
> instance names or any comment — not the full names and not the distinctive tokens
> (`Chisel Gauntlet, Firearm Factory, Wrong Way, Stable Footing, Tunnel Hazard, Inside Job,
> Smoke Break, Debris Platforms, Spine Breaker, Lethal Rebound, Forklift Certified, The
> Filter, Machine Party` and their camel/snake spellings). `tests/rules.lua` gets an
> assertion that greps `Playlist.Ids` and the registry copy for these (Framework stage).

Reading order for an implementer: §0 decisions → §A your row → §B server kit → §C client kit
→ §D your files → §E acceptance → MP-04 card for your trial (game feel only; where MP-04
contradicts §A/§B/§C, this file wins).

---

## 0. Decisions that resolve the MP-01..04 conflicts

| # | Topic | Decision | Why |
|---|---|---|---|
| D1 | Wire protocol for new trials | MP-02's envelope: every server→client packet of a new trial is `{kind="trial", trialId="<id>", ev="<event>", ...}`; reserved `ev="begin"` (first packet of a round, carries `roundToken, roundIndex, roundCount`) and `ev="end"` (last packet, every exit path). MP-04's per-trial kinds (`carve_template`, `fc_call`, …) become `ev` values (`template`, `call`, …). Generic kinds `announce/count/go/gorefx/hide` and `role="spectate"` are reused unchanged. New trials NEVER send `role="runner"/"sniper"/"none"`. | Unknown kinds fall through to the client's line-2072 fallback and bump `session` (kills typewriters); `kind="trial"` is intercepted before that. Role runner drags in yaw-lock/forward-only movement no top-down trial wants. |
| D2 | How the client learns `roundToken` | From `ev="begin"` (router adopts it into `trialRoundToken`); every later trial packet MAY re-carry it. `role="spectate"` for the dead is allowed and the router also adopts a `roundToken` found on it. | Today only `role` delivers the token (MP-01 §9.5); the router replaces that path for new trials. |
| D3 | Client→server packet | Flat legacy fields plus extras: `{trialId, action, roundToken, seq, v=1, data=<table|nil>}`. Server kit validates the MP-01 chain (type→trialId→action→acceptInput→phase→sessionId→roundToken→membership/done→rate) and additionally drops `seq` ≤ last accepted seq when `seq` is a number. `Envelope.validate` is NOT wired (legacy trials keep the bare packet). | Server contract wins; `sessionId` never reaches the client today so it cannot be echoed. |
| D4 | Arena origins | MP-03's grid on `Y = 0` (verified against the live footprints), NOT MP-04's `Y = 400` row. Stored once in `GameConfig.Arenas.Origins` (Framework stage); modules read `Origins[TRIAL_ID]`. Footprint ≤ 200×200 around the origin, height < 120. Each arena builds its own 1-stud slab whose top is at `Y = 0` (the origin is floor level). | Off the 2048 baseplate (edge at 1024), > 1200 studs from existing content, > 480 (FogEnd) apart. |
| D5 | Icons | Only the eight names that exist in `StarterGui.KenopsiaMachine.Selection.IconPool` (`Bug, Crosshair, Cube, Factory, Magnifier, Saw, Train, Utensil` — pixel-block Frames, verified in the weppy mirror). Assignment in §A; repeats accepted. `DECOY_ICONS` unchanged. New glyphs = ledger follow-up, not a blocker. | Unknown icon name → tile renders `Crosshair` silently. |
| D6 | SFX names | Only names that exist in the live place (MP-03 §1.4). MP-04 cards that name `AccessGranted`, `AccessDenied`, `StandClear`, `Submit`, `SubmitAlt` use these substitutes: `AccessGranted→Confirm`, `AccessDenied→Reject`, `StandClear→Warning`, `Submit→Submits` (pool), `SubmitAlt→ClickAlt`. `kit.sfx(name)` is silent on a missing name, never errors. Music: Integrate adds `Music.Trials.<id>` Sounds reusing the `minefield` id (arena trials) / `birdhunt` id (`breather`, `carrier`, `stacker`). | MP-03 is the live inventory; MP-04 used the stale ledger list. |
| D7 | Session length | `GameConfig.Playlist.PerSession = 5` (Framework stage). `playableOrder(seed)` returns the first `PerSession` enabled ids of `Playlist.order(seed)` (0/nil = all). | 15 trials × ~2 min = 25–30 min sessions is not a party game (MP-01 §9.1). |
| D8 | Round seconds are one number per trial | `Pacing.RoundSeconds[id]` is a single value; MP-04's `carrier` "45 (2p: 30)" becomes 45 for all counts (the 2-player arena subset stays). No trial derives its length from anything else. | Server contract (Pacing row) wins; the tests assert one number. |
| D9 | Character assumptions | Character = `Humanoid` + `HumanoidRootPart` only; height numbers from `Humanoid.HipHeight + RootPart.Size.Y/2`; no R15 part names (MP-04's "attach to RightHand" → attach to `HumanoidRootPart` with an offset, or client-only prop). Default R15 stays until the user finishes MP-03 M1 (StarterCharacter is a later flag, §G). | MP-03 §3 option C. |
| D10 | Movement speed | The client owns `Humanoid.WalkSpeed` (`applyMovement`); a new trial's client module sets it through `kit.movement.set(speed)` on `begin` (default after `begin` is frozen = 0). The server ALSO sets `hum.WalkSpeed` on placement (belt and braces) and enforces a per-tick speed clamp on sampled positions (`R:sample`), which is the real anti-cheat. Jump is always 0. | The legacy `role` packet is the only thing that unfreezes movement today; new trials do not send it. |
| D11 | Trial round token format | Trial-minted, `("<ID>-%s-R%s-%d"):format(sessionId, roundIndex, ms%100000)` via `TrialKit.mintToken` (`<ID>` = id in caps). Contexts' round token stays unused until MachineFlow threads `roundCtx` (out of scope). | MP-01 §9.3. |
| D12 | Death sequence | Exactly Minefield's: `BloodFX.kill(pos)`; `hum.Health = 0`; `announce {kind="gorefx", pos, power}` to the room; `tellOne {kind="announce", style="death", text=<2–3 words past tense>}`; after 3.2 s (active-checked) `tellOne {kind="role", role="spectate", watch, pos, look}`. Non-lethal eliminations (`breather` confiscation, `armory`, `carrier`, `stacker`) send `{kind="trial", ev="out", text=...}` instead and NO gore. Kills are always telegraphed ≥ 0.7 s. | Copy the shipped pattern; the client's death card/gore code is generic. |
| D13 | Shared-file ownership | ONLY the Framework stage edits `MachineFlow, Pacing, Playlist, GameConfig, default.project.json, KenopsiaClient, MachineLayout, tests/rules.lua`. It also creates STUB files for all 36 per-trial modules (server, rules, client) so every `require` and every Rojo path resolves at boot; implementers overwrite only their own four files (§D). | 12 parallel agents cannot share edits to one file; missing `require` targets would break MachineFlow at boot. |
| D14 | Canteen token bug F-1 | Framework fixes it: move `trialRoundToken = p.roundToken` above the `spectate` early-return in the `role` handler (client 1876–1891) — 2 lines, verified by playing Canteen once. | It is a client bug in shipped code and the router touches the same lines. |
| D15 | Controls text | Each `TrialClients/<id>.luau` exports `M.controlsText = { title=..., lines={...} }`; MachineLayout's `applyControlsText` (line ~179) tries `TrialClients[TrialId].controlsText` (pcall require) before `TRIAL_TEXT[...]`, and the fallback becomes a neutral generic row instead of `TRIAL_TEXT.birdhunt`. | Keeps a trial's text with its module; no shared data file 12 agents edit. |
| D16 | Tests interpreter | `C:\Lua\bin\lua.exe` (Lua 5.1, on PATH as `lua`). `luau.exe` in `Roblox Project\tools` has no `loadfile` and does not run these tests. Pure rules modules must be 5.1-portable (Pacing header rules). | MP-01 §6 verified. |

---

## A. Final trial table

Registry text (`MachineFlow.TRIALS`, `showInterRoundScore=false`, `ready=false` until QA):

| # | Reference (docs only) | id | displayName | subtitle | tagline | icon | moduleName (Services/) | rules module (Shared/Rules/) | client module | test |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Chisel Gauntlet | `carve` | CUT TO SPEC | `MATCH THE TEMPLATE. THE BLOCK IS NOT FORGIVING._` | `CUT ONLY WHAT IS SHOWN.` | Cube | `CutToSpec` | `CutToSpecRules` | `TrialClients/carve.luau` | `tests/carve.lua` |
| 2 | Firearm Factory | `armory` | ARMS ISSUE | `PARTS ARE ON THE FLOOR. THE ISSUE IS NOT._` | `COLLECT. ASSEMBLE. DISCHARGE.` | Crosshair | `ArmsIssue` | `ArmsIssueRules` | `TrialClients/armory.luau` | `tests/armory.lua` |
| 3 | Wrong Way | `upstream` | UPSTREAM | `THE STAIRS RUN DOWN. YOU RUN UP._` | `READ THE ARROWS. CLIMB.` | Factory | `Upstream` | `UpstreamRules` | `TrialClients/upstream.luau` | `tests/upstream.lua` |
| 4 | Stable Footing | `floorcheck` | FLOOR CHECK | `ONE PLATE HOLDS. THE REST GIVE WAY._` | `STAND WHERE YOU ARE TOLD.` | Cube | `FloorCheck` | `FloorCheckRules` | `TrialClients/floorcheck.luau` | `tests/floorcheck.lua` |
| 5 | Tunnel Hazard | `clearance` | CLEARANCE | `THE LINE IS LIVE. FIND YOUR RECESS._` | `OFF THE TRACK BEFORE THE HORN.` | Train | `Clearance` | `ClearanceRules` | `TrialClients/clearance.luau` | `tests/clearance.lua` |
| 6 | Inside Job | `carrier` | CARRIER | `ONE OF YOU IS ALREADY SICK._` | `FIND THE NEEDLE. OR AVOID IT.` | Bug | `Carrier` | `CarrierRules` | `TrialClients/carrier.luau` | `tests/carrier.lua` |
| 7 | Smoke Break | `breather` | BREATHER | `ONE CIGARETTE. THIRTY SECONDS. NOTHING ELSE._` | `INHALE. NOT TOO DEEP.` | Factory | `Breather` | `BreatherRules` | `TrialClients/breather.luau` | `tests/breather.lua` |
| 8 | Debris Platforms | `sweep` | CLEAR THE DECK | `THE PRESS ONLY WAITS FOR WEIGHT._` | `KEEP YOUR PLATE CLEAN.` | Saw | `ClearTheDeck` | `ClearTheDeckRules` | `TrialClients/sweep.luau` | `tests/sweep.lua` |
| 9 | Spine Breaker | `crawler` | CRAWLER | `IT WANTS A BACK TO BREAK._` | `DODGE IT. OR PASS IT ON.` | Bug | `Crawler` | `CrawlerRules` | `TrialClients/crawler.luau` | `tests/crawler.lua` |
| 10 | Lethal Rebound | `ricochet` | RICOCHET | `THE BLADES DO NOT STOP AT WALLS._` | `WATCH THE ANGLES.` | Saw | `Ricochet` | `RicochetRules` | `TrialClients/ricochet.luau` | `tests/ricochet.lua` |
| 11 | Forklift Certified | `stacker` | PALLET DUTY | `TWENTY SECONDS. STACK HIGH. DO NOT DROP._` | `HIGHEST STACK KEEPS THE JOB.` | Factory | `PalletDuty` | `PalletDutyRules` | `TrialClients/stacker.luau` | `tests/stacker.lua` |
| 12 | The Filter | `sorting` | SORTING FLOOR | `GOOD LEFT. BAD RIGHT. NO EXCEPTIONS._` | `MISFILE AND YOU FOLLOW IT.` | Magnifier | `SortingFloor` | `SortingFloorRules` | `TrialClients/sorting.luau` | `tests/sorting.lua` |

Numbers (`Pacing.ROUNDS[id] = {[2],[3],[4]}`, `Pacing.RoundSeconds[id]`, `GameConfig.Arenas.Origins[id]`):

| id | 2p | 3p | 4p | RoundSeconds | Origin (X,Y,Z) | Footprint | Camera (client kit) | Death? | Ranking metric (ordering key; bands FINISHED 2000+ > ALIVE 1000+ > OUT 0+; per-band detail must stay < 1000) |
|---|---|---|---|---|---|---|---|---|---|
| carve | 3 | 3 | 2 | 45 | (1400, 0, -900) | 60×60 | `camera.fixed` 3/4 over own bench | yes (hood, 2nd wrong cut) | FIN `2000 + spareSec*10` > ALIVE `1000 + correctCuts*20` > OUT `correctCuts*20 - strikes*10` (≥0) |
| armory | 3 | 2 | 2 | 50 | (1400, 0, -300) | 90×90 | `camera.top` follow | no | FIN `2000 + (50 - fireTime)*10` > ALIVE `1000 + partsHeld*100 + assembled*300` |
| upstream | 3 | 3 | 2 | 40 | (1400, 0, 300) | 40×140 | `camera.fixed` side view of all lanes | yes (belt bottom) | FIN `2000 + (40 - finishTime)*10` > ALIVE `1000 + floor(t*500)` > OUT `min(correctArrows*5, 900)` |
| floorcheck | 3 | 3 | 2 | 35 | (1400, 0, 900) | 60×80 | `camera.top` follow | yes (drop) | ALIVE `1000 + callsSurvived*10` > OUT `callsSurvived*10`; round ends early when ≤ 1 alive |
| clearance | 2 | 2 | 2 | 50 | (1900, 0, -900) | 30×160 (long axis Z) | `camera.top` follow, `radius=26` | yes (train) | ALIVE `1000 + passes*50 + firstOpen*5 (cap 30)` > OUT `min(passes*50, 750)` |
| carrier | 2 | 3 | 2 | 45 | (1900, 0, -300) | 100×100 | `camera.top` follow, `radius=22` | no | Clean-survivor `2000 + secondsClean` ; original Carrier all-infected `2000 + infections*200` ; Carrier partial `1000 + infections*200 + min(secondsHeld,60)` ; infected `min(1000 + secondsClean*10, 1600)` + `100*infectionsAsSecondary` — table asserted in `tests/carrier.lua` (never crosses 2000) |
| breather | 3 | 3 | 3 | 30 | (1900, 0, 300) | 40×40 | `camera.fixed` frontal rail | no (confiscation = out) | FIN `2000 + spareSec*10` > ALIVE `1000 + burn*5 (cap 1499)` > OUT `burn*5 (cap 499)` |
| sweep | 3 | 2 | 2 | 45 | (1900, 0, 900) | 70×70 | `camera.top` follow | yes (press) | ALIVE `1000 + kicks*3 - peakLoad` (clamp 1000..1999) > OUT `min(secondsSurvived*10, 600)` |
| crawler | 3 | 2 | 2 | 40 | (2400, 0, -900) | 70×70 | `camera.top` follow | yes (pin timer) | ALIVE `min(1000 + saves*100 + escapes*50 + flings*30, 1999)` > OUT `min(secondsSurvived*10 + saves*100, 999)` |
| ricochet | 3 | 3 | 2 | 45 | (2400, 0, -300) | 60×60 | `camera.top` `fixed=true` whole arena | yes (blade) | ALIVE `min(1000 + closeCalls*5, 1999)` > OUT `min(secondsSurvived*20, 900)`; ends early when ≤ 1 alive |
| stacker | 3 | 3 | 3 | 20 | (2400, 0, 300) | 90×90 | `camera.top` `subject=<rig Part>` | no | single band `1000 + stackHeight*100 - spoiledByYou*10 + firstToHeight` (≥ 1000, ties share) |
| sorting | 3 | 2 | 2 | 40 | (2400, 0, 900) | 60×60 | `camera.fixed` over the four stations | yes (trapdoor) | ALIVE `1000 + correct*10 - strikes*3` (clamp 1000..1999) > OUT `min(correct*10, 990)` |

`GameConfig.Arenas.Origins` (Framework writes this table verbatim):
```lua
Arenas = {
	Origins = {
		carve = Vector3.new(1400, 0, -900), armory = Vector3.new(1400, 0, -300),
		upstream = Vector3.new(1400, 0, 300), floorcheck = Vector3.new(1400, 0, 900),
		clearance = Vector3.new(1900, 0, -900), carrier = Vector3.new(1900, 0, -300),
		breather = Vector3.new(1900, 0, 300), sweep = Vector3.new(1900, 0, 900),
		crawler = Vector3.new(2400, 0, -900), ricochet = Vector3.new(2400, 0, -300),
		stacker = Vector3.new(2400, 0, 300), sorting = Vector3.new(2400, 0, 900),
	},
	MaxFootprint = 200, MaxHeight = 120,
},
```

Copy voice (all text a trial shows): uppercase, industrial, no jokes, no exclamation marks;
death lines 2–3 words past tense (`OFF SPEC.`, `WRONG PLATE.`, `STRUCK.`, `PRESSED.`,
`SPINE FAILED.`, `SPLIT.`, `MISFILED.`, `FED TO THE BELT.`); non-lethal outs `CONFISCATED.`.

---

## B. Server `TrialKit` (Framework stage builds it; behaviour = what Minefield/Bird/Canteen do)

File: `studio-src\ServerScriptService\KenopsiaServer\Services\TrialKit.luau` (`--!nonstrict`).
It is a library of helpers plus a round object. It holds NO per-room mutable "current": all
state hangs off the round object; the only module tables are the round registries keyed by
`trialId .. ":" .. room.id` and by userId, both cleared by `R:cleanup()`. Every function
below is required behaviour; names are binding so 12 implementers write against one API.

### B.1 Constants and palette
```lua
TrialKit.PALETTE = { -- world PS1 palette (MP-04 §0.5); the client kit mirrors it byte-for-byte
	Void=Color3.fromRGB(12,12,14), Concrete=Color3.fromRGB(96,96,92), WetConcrete=Color3.fromRGB(68,70,66),
	Steel=Color3.fromRGB(140,146,150), Rust=Color3.fromRGB(122,58,34), Hazard=Color3.fromRGB(196,160,32),
	Signal=Color3.fromRGB(200,32,32), Blood=Color3.fromRGB(120,16,16), Grime=Color3.fromRGB(58,72,52),
	Bone=Color3.fromRGB(204,196,176), Sodium=Color3.fromRGB(232,176,88) }
TrialKit.BAND = { FINISHED = 2000, ALIVE = 1000, OUT = 0 }
TrialKit.key(band, detail)          -- returns band + math.clamp(math.floor(detail), 0, 999)
TrialKit.HOME_FALLBACK = Vector3.new(0, 5, 0)
```

### B.2 Arena builders (all return the Instance; all Anchored, SmoothPlastic, CastShadow=false, Smooth surfaces)
```lua
TrialKit.part(spec)   -- spec: {name, size=Vector3, cf=CFrame | pos=Vector3, color=Color3, parent,
                      --        transparency?, canCollide? (default true), canQuery?, canTouch?, neon? (Material Neon),
                      --        shape? Enum.PartType}  → Part
TrialKit.box(name, size, cf, color, parent)         -- shorthand for part{}
TrialKit.marker(name, cf, parent)                    -- invisible, non-colliding, CanQuery/CanTouch false 1^3 part
TrialKit.slab(parent, origin, sizeX, sizeZ, color)   -- floor whose TOP is at origin.Y (thickness 1) → Part
TrialKit.wallBox(parent, origin, sizeX, sizeZ, height, thickness, color) → {n,s,e,w}
TrialKit.floorGrid(parent, origin, cols, rows, cell, gap, color, namePrefix)
   -- builds cols×rows plates (size cell×1×cell, top at origin.Y) centred on origin, returns
   -- g = {parts[c][r], cols, rows, cell, gap, origin, cellCenter(c,r)→Vector3, cellOf(pos)→c,r|nil (arithmetic, never Touched)}
TrialKit.ensureArenaFolder(trialId) → Folder            -- workspace.KenopsiaArenas.<id>, created if absent (both levels)
TrialKit.ensureArena(trialId, buildFn) → refs|nil       -- idempotent: if the folder has an attribute "Built"==true returns
   -- buildFn(folder, origin) result cached on TrialKit; else clears folder, calls buildFn(folder, origin), sets attribute.
   -- origin = GameConfig.Arenas.Origins[trialId] (nil → warn + return nil). buildFn returns a refs table
   -- (must include refs.spawn = Part|{CFrame...} and refs.cam = Part for the spectate camera). Called from init() in pcall and again
   -- at round start (cheap). Never yields.
TrialKit.partCount(folder) → n                          -- acceptance: < 300 static parts
```

### B.3 Room / audience / messaging (verbatim semantics of Minefield :105-216)
```lua
TrialKit.livingOf(room) → {[uid]={player,char,hum,root}}   -- fresh each call; Health>0 only
TrialKit.audienceOf(room) → {Player}                         -- connected room.members
TrialKit.roomActive(room) → bool                            -- #members>0 and phase nil|"Playing"
TrialKit.announce(room, payload)                            -- MachineState:FireClient to each member; never FireAllClients
TrialKit.tellOne(userId, payload)
TrialKit.send(room, trialId, ev, fields?)                   -- announce {kind="trial", trialId=, ev=, ...fields}
TrialKit.sendOne(userId, trialId, ev, fields?)
TrialKit.spectatePacket(watchUserIds, camPart, lookPos) → payload   -- {kind="role", role="spectate", watch, pos={x,y,z}, look={x,y,z}}
TrialKit.deathCard(userId, text)                            -- tellOne {kind="announce", style="death", text=text}
```

### B.4 Input wiring (the whole MP-01 validation chain, once)
```lua
TrialKit.wireInput(trialId, spec)   -- spec = { actions = {act=true,...}, cooldown = 0.25 (default per-player, seconds),
                                    --          perAction = {act = 0.1, ...} (optional overrides),
                                    --          handler = function(player, ps, payload, R) end }
```
Semantics: find-or-create `ReplicatedStorage.Kenopsia.Remotes.TrialInput`; disconnect any earlier
connection for this trialId (idempotent init); on `OnServerEvent(player, payload)`:
1 `type(payload)=="table"`; 2 `payload.trialId == trialId` (FIRST, the remote is shared);
3 `spec.actions[payload.action]`; 4 `R = registry[player.UserId]` for this trialId else drop;
5 `R.acceptInput`; 6 `R.room.phase == "Playing"`; 7 `R.room.sessionId == R.sessionId`;
8 `payload.roundToken == R.roundToken`; 9 `ps = R.state[uid]` exists and not `ps.done`;
10 `if type(payload.seq)=="number" then if payload.seq <= (ps.lastSeq or 0) then drop end; ps.lastSeq = payload.seq end`;
11 rate: `now < (ps.lastInput[action] or 0) + (perAction[action] or cooldown)` → drop; else stamp;
12 `handler(player, ps, payload, R)` in pcall (a handler error warns and drops the packet, never kills the connection).
Only `payload.data` (a table or nil) is trial payload; handlers must range-check every field and never
trust a client position. A trial with no input packets (floorcheck) skips `wireInput` entirely.

### B.5 Round object
```lua
local R = TrialKit.newRound(trialId, room, roundIndex, guard)
```
Creates and REGISTERS the round (`registry[trialId..":"..room.id] = R`, `byUser[uid] = R` for each
member) and arms `guard.cleanup = function() R:cleanup() end` immediately (before any yield). Fields:
`R.room, R.sessionId (snapshot), R.roundIndex, R.roundToken (minted), R.state {[uid]={done=false, lastInput={}, lastSeq=0}}` (one entry per `room.members`), `R.acceptInput=false, R.runtime=nil, R.cleaned=false, R.t0` (set at GO), `R.deadline`, `R.subjects` (last `livingOf` snapshot).
Methods:
```lua
R:active() → bool            -- registry still points at R AND TrialKit.roomActive(room)   (== Minefield active())
R:onCleanup(fn)              -- push a teardown fn (LIFO, pcall'd) e.g. connections, tweens; may be called any time
R:runtimeFolder(arenaFolder) → Folder "<ID>_Runtime" parented to the arena; destroyed by cleanup
R:begin(fields?)             -- sends {kind="trial", ev="begin", trialId, roundToken, roundIndex, roundCount=fields.roundCount, ...} to EVERY member (spectate-dead too). Call once, before countdown, after placement.
R:cover(text?)               -- announce {kind="announce", text=text or ""}  ("" = opaque black)
R:wait(seconds) → bool       -- task.wait in ≤0.1 s slices, returns false as soon as not active()
R:countdown() → bool         -- {kind="count", n=3..1} one per second then {kind="go"}; sets acceptInput=true, R.t0=os.clock(); false if aborted (acceptInput stays false)
R:openInput()/R:closeInput()
R:place(spots)               -- spots = {CFrame,...} or fn(i, mm)→CFrame; for each member with a living char: Health=Max, root.CFrame=spot (+ nothing else); marks members without a char done=true; sets hum.WalkSpeed=spots.walkSpeed or 16, JumpPower 0; records originals for restore.
R:setMovement(uid, walkSpeed, anchored?)   -- server-side, recorded for restore
R:sample(uid, dt, maxSpeed, aabb?) → pos|nil  -- reads root.Position; if it moved > maxSpeed*dt*1.5 since last sample or is outside aabb, snaps the root back to the last good pos and returns that; the anti-teleport clamp every movement trial uses each tick
R:tick(fn)                   -- Heartbeat loop: while os.clock() < R.deadline do dt=task.wait(0.05); if not R:active() then break end; if fn(dt)=="stop" then break end end. Never used for physics; fn does the server-authoritative logic.
R:setDeadline(seconds)       -- R.deadline = os.clock()+seconds (default Pacing.RoundSeconds[trialId]); plus a failsafe = deadline + 20 the tick loop honours
R:kill(uid, opts)            -- opts {text, pos?, power=1.5, camPart?, look?}: D12 sequence, ps.done=true, ps.diedAt=os.clock(); no-op if already done
R:out(uid, text)             -- non-lethal elimination: ps.done=true; sendOne ev="out" {text}; spectate packet if opts.camPart
R:stillRunning(exceptUid) → {uid,...}
R:scores(fn) → table         -- complete zero-filled table over room.members, then scores[uid]=fn(uid, ps) for each; nil → 0
R:endRound() → bool          -- closeInput; if active(): cover("") + wait 0.6; returns active()
R:cleanup()                  -- idempotent (cleaned latch): closeInput; unregister; run onCleanup LIFO; restore every changed humanoid (WalkSpeed 16, JumpPower 0, Anchored false, attributes ""), teleport living members home to workspace.SpawnLocation.Position + (rand±6, 4, rand±6) or HOME_FALLBACK; destroy runtime folder; BloodFX.clear(roundToken, audience); send {kind="trial", ev="end", trialId} to every member.
```
Rate-limit defaults and the `active()` re-check are the round object's job; a trial that
schedules `task.delay/spawn` MUST still write `if not R:active() then return end` first.

### B.6 Round wrapper (verbatim Minefield.runRound)
```lua
TrialKit.runRound(trialId, room, roundIndex, inner)  -- guard={}; ok,res = xpcall(function() return inner(room, roundIndex, guard) end, debug.traceback);
                                                     -- if guard.cleanup then pcall(guard.cleanup) end; if not ok then warn(...); error(res, 0) end; return res
```
A trial module is therefore:
```lua
function Trial.init()  TrialKit.wireInput(TRIAL_ID, {...}); pcall(TrialKit.ensureArena, TRIAL_ID, buildArena) end
function Trial.runRound(room, roundIndex) return TrialKit.runRound(TRIAL_ID, room, roundIndex, runRoundInner) end
```
and `runRoundInner` = `scores zero-fill → refs=ensureArena (nil→warn, return scores) → R=newRound → arena/runtime props → R:place → R:begin → R:cover(tagline) + R:wait(2.8) → R:countdown() (false→return scores) → R:setDeadline → R:tick(...) → if not R:active() return scores → scores = R:scores(keyFn) → R:endRound() → return scores`.

### B.7 Seeded randomness
`TrialKit.rng(room, roundIndex)` → `nextInt(n)` closure built from the Playlist LCG seeded with a
hash of `room.sessionId .. roundIndex` (so Studio and tests agree); pure rules modules take
`nextInt` as a parameter, never `math.random`. Cosmetic jitter may use `math.random`.

### B.8 Framework-stage tests for the kit
`tests/trialkit.lua` cannot load the kit (it needs `game`), so the kit's PURE parts —
`floorGrid` cell arithmetic (`cellCenter/cellOf`), `key()` band clamp, the LCG `rng` and the
token format — live in `Shared/Rules/TrialRules.luau` (5.1-portable) which TrialKit requires;
`tests/trialrules.lua` proves them.

---

## C. Client: `TrialClientKit` + dispatcher (Framework stage)

Files: `studio-src\StarterPlayer\StarterPlayerScripts\TrialClientKit.luau` (ModuleScript),
`studio-src\StarterPlayer\StarterPlayerScripts\TrialClients\<id>.luau` (12 ModuleScripts, stubs
first). Client module contract: `return { init(kit), onPacket(p), onEnd(), controlsText = {title=, lines={}} }`.
`init(kit)` runs once per client lifetime (router memoises) — capture `kit`, build nothing;
`onPacket(p)` receives every `{kind="trial", trialId=<id>}` packet (including `begin`, `end` is
NOT delivered — `onEnd` is) plus observed generic kinds `count/go/announce/hide/gorefx/role`
(read-only copies); `onEnd()` clears module tables — the router already tears down HUD, pad,
keys, render/heartbeat connections, camera, movement, mouse icon, CountText, token. Every
callback a module schedules re-checks `kit.isActive()`.

### C.1 TrialClientKit API (what `init(kit)` receives; the object is per-trial, created by the router)
```
kit.trialId, kit.player, kit.machine (KenopsiaMachine ScreenGui, read-only), kit.roundToken() (live), kit.isActive()
kit.send(action, data?, cooldown?)   -> TrialInput:FireServer{trialId, action, roundToken, seq=<monotonic per client>, v=1, data=data}
                                        drops when not active/no token; per-action client cooldown (default 0.1 s) mirrors the server gate
kit.hud()      -> lazily created Frame "TrialHud_<id>" under machine: full size, BackgroundTransparency 1, ZIndex 58 (below Announce 60 / Fader 70); destroyed on end
kit.pad()      -> lazily created Frame "TrialTouch_<id>", ZIndex 68, Visible = touchAllowed(); destroyed on end
kit.touchAllowed()
kit.label(parent, {text,size,pos,anchor,color,align,textSize}) -> TextLabel Font=Enum.Font.Code, TextColor3 default IDLE, bg transparent
kit.panel(parent, size, pos)             -> Frame BackgroundColor3 (9,12,10) BackgroundTransparency .25 BorderSizePixel 0
kit.button(parent, name, text, pos, color, onActivated) -> TextButton 110x110 (Canteen touch button style)
kit.meter(parent, {name,size,pos,color}) -> {frame, set(fraction)}   (fill bar; breather lung/burn, crawler struggle, armory assembly)
kit.timer(endsAt)                        -> label counting down from a server os.clock deadline sent once (converted via workspace:GetServerTimeNow() delta); no per-second packets
kit.card(text, style?)                   -> the client's showAnnounce (style "death" identical to today's death card)
kit.edgeGlow(color, transparency, tweenSecs)
kit.typewrite(label, text, cps)
kit.sfx(name)                            -> SoundService.KenopsiaAudio.SFX.<name> or pool child; silent on missing name (D6)
kit.palette                              -> UI colours PHOSPHOR/IDLE/DIM/AMBER/DANGER/WARN/SAFE/PANEL/INK/BLOOD + kit.palette.world = TrialKit.PALETTE mirror
kit.camera.top({height=24, back=9, lerp=6, radius=nil, fixed=false, subject=nil})   -- follow (root or subject); radius = FOV/height reduction; fixed = one arena-wide CFrame computed from arena bounds at first call
kit.camera.fixed(cframe) | kit.camera.follow({offset=Vector3, look=Vector3}) | kit.camera.restore()
kit.movement.set(walkSpeed) | kit.movement.freeze()     -- moveState "trial"/"frozen" + applyMovement; JumpPower stays 0
kit.bindKey(name, {Enum.KeyCode.E, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonA, ...}, onBegan, onEnded?)  -- gameProcessed + isActive guards; edge semantics; all removed on end
kit.bindArrows(fn(dir))                  -- Up/Down/Left/Right + WASD + DPad, calls fn("Up"|"Down"|"Left"|"Right") on press
kit.unbind(name)
kit.onRender(fn(dt)) / kit.onHeartbeat(fn(dt))          -- tracked, disconnected on end
kit.mouseRay(maxDist, filterInstances?) -> RaycastResult|nil   -- ViewportPointToRay(mouse or last touch tap) + workspace:Raycast
kit.character() / kit.root()
kit.gore(pos, power)                     -- local-only applyGoreFx
kit.arena()                              -- workspace.KenopsiaArenas.<id> via FindFirstChild (nil until replicated); kit.arenaRuntime() -> the "<ID>_Runtime" folder or nil
kit.flash(part, color, seconds)          -- telegraph helper: temporarily recolours/neons a Part then restores
kit.tween(instance, props, seconds, style?) -- TweenService wrapper tracked and cancelled on end
```

### C.2 Router behaviour (`trialRouter`, ~60 lines inside KenopsiaClient, closes over the monolith's locals)
`trialRouter.handle(p)`:
1. `p.kind == "trial"` and `type(p.trialId)=="string"`:
   - `ev=="begin"`: if another module is active → `endActive()`; `pcall(require, trialClientsFolder[trialId])`
     (missing/broken → `warn`, return true); memoised `init(kit)`; `activeId=trialId`; `trialRoundToken=p.roundToken`;
     `hideAll()` is NOT called (the count handler does it); `onPacket(p)` in pcall. Return true.
   - `ev=="end"`: `endActive()`. Return true.
   - other: if `p.trialId==activeId` → adopt `p.roundToken` if string, `onPacket(p)` in pcall; else drop. Return true.
2. else if a module is active and `p.kind ∈ {count, go, announce, hide, gorefx, role}`: adopt `p.roundToken`
   if present; forward a shallow copy to `onPacket` in pcall; return **false** (legacy handler still runs).
3. else return false.

`endActive()`: `pcall(onEnd)`; unbind all keys/arrows; disconnect render/heartbeat/tweens; destroy
`TrialHud_<id>` and `TrialTouch_<id>`; `trialCam=nil`; **`spectateCF=nil; spectateWatch=nil; spectateEye=nil`**
(new trials never send `role none`, which is what clears these today); `restoreCamera()`;
`moveState="frozen"; applyMovement()`; hide `CountText`; `UserInputService.MouseIconEnabled=true`;
`trialRoundToken=nil`; `activeId=nil`. Idempotent.

### C.3 Exact edit spec for `KenopsiaClient.client.luau` (line numbers as of 2026-08-17; re-grep before editing)
| # | Where | Edit |
|---|---|---|
| 1 | after L201 `local trialRoundToken = nil` | `local TrialClientKit = require(script.Parent:WaitForChild("TrialClientKit"))`, `local trialClientsFolder = script.Parent:FindFirstChild("TrialClients")`, `local trialRouter = nil`, `local trialCam = nil`, `local trialWalkSpeed = 0` |
| 2 | `applyMovement` L400-414 | insert `elseif moveState == "trial" then hum.WalkSpeed = trialWalkSpeed` before the `else hum.WalkSpeed = 0` |
| 3 | RenderStepped L471-509 | insert `elseif trialCam then camera.CameraType = Enum.CameraType.Scriptable; camera.CFrame = TrialClientKit.computeCamera(trialCam, player.Character, camera, dt)` between the `spectateCF` branch and `elseif runnerCam` (spectate wins over trial cam) |
| 4 | L1876-1891 (`role` handler) | F-1: set `trialRoundToken = p.roundToken` when `p.roundToken ~= nil` BEFORE the spectate early-return (keep the later assignment for non-spectate roles) |
| 5 | between `applyGoreFx` (L1849-1861) and the funnel (L1865) | build `trialRouter = TrialClientKit.newRouter({ machine=, sfx=, touchAllowed=, hideAll=, typewrite=, applyGoreFx=, TrialInput=, camera=, player=, getToken=fn, setToken=fn, setMove=fn(state, speed), setCam=fn(tbl), clearSpectate=fn, restoreCamera=, hideCountText=fn })` — the router lives in the kit module, the monolith only passes closures |
| 6 | L1866 (first line inside the funnel, after the type check) | `if trialRouter and trialRouter.handle(p) then return end` |
| 7 | near L345-349 (attribute listeners) | `player:GetAttributeChangedSignal("KenopsiaActiveTrial"):Connect(function() local id = player:GetAttribute("KenopsiaActiveTrial") or ""; if trialRouter and trialRouter.activeId and trialRouter.activeId ~= id then trialRouter.endActive() end end)` — abort backstop |
| 8 | L2072 fallthrough | add `if trialRouter and lobbyKinds[p.kind] then trialRouter.endActive() end` after `lobbyKinds` is defined (belt) |
| 9 | `hasSecondPage()` L~2183 | unchanged (no new trial has a second page) |
MachineLayout `applyControlsText` L179: try `TrialClients[TrialId].controlsText` first (pcall require, cached), then `TRIAL_TEXT[TrialId]`, then a NEW neutral `TRIAL_TEXT.default` — never `birdhunt`.

### C.4 Router ordering guarantees the implementers may rely on
`begin` arrives after the round card `hide` and after placement, before `count`; `count/go`
follow within ~3 s; `end` arrives at cleanup on every path; on abort the attribute clear
(step 7) ends the module even if `end` never arrived; the previous trial's `end` always
precedes the next trial's `begin` (≥ 11.5 s of cards between them).

---

## D. Files and ownership

### D.1 Framework stage (ONE agent, runs first, touches shared files ONLY here)
| File | Edit |
|---|---|
| `Services/TrialKit.luau` (new) | §B |
| `Shared/Rules/TrialRules.luau` (new) + `tests/trialrules.lua` (new) | §B.8 |
| `Shared/Config/AnimationIds.luau` (new) + `tests/animationids.lua` | MP-03 §6 verbatim (`resolve/load`, all ids 0) |
| `Shared/Config/GameConfig.luau` | `Playlist.TrialIds` += the 12 ids; `Playlist.PerSession = 5`; `Arenas = {...}` (§A) |
| `Shared/Rules/Playlist.luau` | `Playlist.Ids` += the 12 ids (Lua 5.1 syntax) |
| `Shared/Rules/Pacing.luau` | 12 `ROUNDS` rows + 12 `RoundSeconds` (§A) |
| `Services/MachineFlow.luau` | 12 `require`s + 12 registry entries (§A text, `ready=false`); `playableOrder` honours `PerSession`; comment updates ("all three" → "all ids") |
| 12 × `Services/<Name>.luau` STUBS | compliant skeleton on TrialKit: `init` wires nothing, `runRound` = newRound → begin → countdown → wait 3 s → scores(0) → endRound (a playable no-op) |
| 12 × `Shared/Rules/<Name>Rules.luau` STUBS | `return {}` with the portability header |
| 12 × `TrialClients/<id>.luau` STUBS | `init/onPacket/onEnd` no-ops + `controlsText` with the tagline |
| `TrialClientKit.luau` (new) | §C.1 + `newRouter` + `computeCamera` |
| `KenopsiaClient.client.luau`, `MachineLayout.client.luau` | §C.3 |
| `default.project.json` | `Services.TrialKit`, 12 `Services.<Name>`, `Rules.TrialRules`, 12 `Rules.<Name>Rules`, `Config.AnimationIds`, `StarterPlayerScripts.TrialClientKit`, `StarterPlayerScripts.TrialClients` (`$className: Folder`) + 12 entries — every file explicit, no `$path` on a folder |
| `tests/rules.lua` | expected rows for 12 ids; RoundSeconds check; `#order == #Playlist.Ids`; permutation search → `distinct >= 6` within 2000 seeds; determinism kept; REQ-IP-01 assertion over `Playlist.Ids` and the id/display strings for the forbidden token list; `PerSession` slice property (first N of order) |
| `docs/MP-05-FRAMEWORK-REPORT.md` | what was built, lint/test output, exact line numbers after the edit |

Gate to release the 12 implementers: `lua tests/rules.lua && lua tests/envelope.lua && lua tests/contexts.lua && lua tests/trialrules.lua` green; luau-lsp + selene clean on every new/edited file; the stub session runs in Studio (12 no-op trials appear in the roulette with `ready=true` flipped temporarily in a DEV copy, then flipped back).

### D.2 Per-trial implementer (12 agents in parallel; each overwrites ONLY these four files)
1. `studio-src/ServerScriptService/KenopsiaServer/Services/<Name>.luau` — full server module on TrialKit.
2. `studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/<Name>Rules.luau` — pure logic (grids, sequences, schedules, sort rules, timers, ranking keys); 5.1-portable; randomness via injected `nextInt`.
3. `studio-src/StarterPlayer/StarterPlayerScripts/TrialClients/<id>.luau` — client module on TrialClientKit; exports `controlsText`.
4. `tests/<id>.lua` — loads the shipped rules module via the `tests/rules.lua` shim; ≥ 15 checks; `os.exit(failures>0 and 1 or 0)`.
Optional: `docs/trials/<id>.md` (design deltas from MP-04, tuning numbers). NOTHING else. If a
kit function is missing, the implementer writes a `local` helper inside their own module and
files a one-line note in their doc for the Framework agent to lift into the kit later.

### D.3 Integrate / QA stage (one agent at a time in Studio)
Flips `ready=true` per trial in `MachineFlow`, adds `Music.Trials.<id>` Sounds, pushes `.Source`,
play-tests (§F), writes `docs/MP-05-QA-<id>.md`.

---

## E. Acceptance criteria (per trial) and the critic checklist

A trial is DONE when all of the following hold. The critic (reviewer agent) ticks each line
against the code, not the description.

**Contract**
- [ ] `init()` idempotent, no `WaitForChild` on optional assets, arena build in `pcall`.
- [ ] `runRound(room, roundIndex)` returns via `TrialKit.runRound`; `guard.cleanup` armed before the first yield; cancellation = normal `return scores`; exceptions propagate after cleanup.
- [ ] Scores: complete table over `room.members`, banded keys per §A, per-band detail clamped < 1000; identical band semantics across rounds.
- [ ] Round length from `Pacing.RoundSeconds[id]` (`R:setDeadline`), failsafe honoured, no per-second countdown packets.
- [ ] Every `task.delay/spawn/Touched/Heartbeat/remote` callback re-checks `R:active()` first.
- [ ] Death per D12; kills telegraphed ≥ 0.7 s; non-lethal outs via `ev="out"`.
- [ ] Packets: only `{kind="trial", trialId, ev, ...}` + generic `announce/count/go/gorefx` + `role spectate`; `begin` before `count`, `end` from cleanup; never `role runner/none`, never `FireAllClients`, never `XBotMoves` values containing `scan/eat/sneak/push`.
- [ ] Hidden state (safe plate, template, carrier, private number, syringe cabinet) never in a public packet before the design's reveal moment.

**Validation**
- [ ] All input via `TrialKit.wireInput` (chain 1–12); handler range-checks every `data` field; positions only from `R:sample`; distances computed server-side; per-action cooldowns match what the client kit sends.
- [ ] Anti-teleport clamp + arena AABB clamp active in the tick.

**Cleanup**
- [ ] Per-round props in `R:runtimeFolder`; static arena idempotent (`ensureArena` twice = same instance count); `R:onCleanup` for every connection/tween; humanoid changes restored; part count of the static arena < 300 (`TrialKit.partCount`).
- [ ] Nothing module-global mutates per room (grep: no `local current`).

**Client**
- [ ] Module has `init/onPacket/onEnd/controlsText`; builds UI only in/after `begin`; uses `kit.send` only; camera via `kit.camera.*`; movement via `kit.movement.*`; every scheduled callback checks `kit.isActive()`; `onEnd` leaves no instances (router destroys HUD/pad, module clears its own world Parts under `kit.arenaRuntime()` only if it created them client-side).
- [ ] Touch: at least one `kit.pad()` button per action; gamepad alias per key.

**Tests / lint / IP**
- [ ] `lua tests/<id>.lua` green (≥ 15 checks: generation determinism for a seed, rule correctness exhaustive where finite, band monotonicity FINISHED > ALIVE > OUT for extreme values, schedule constraints).
- [ ] `luau-lsp analyze --definitions=globalTypes.d.luau --base-luaurc=.luaurc <files>` and `selene <files>`: zero NEW warnings on the four files.
- [ ] Forbidden names/tokens absent (`grep -i` list in the IP note) in the four files, including comments.
- [ ] `--!nonstrict` header, WHY-comments with REQ ids (`REQ-IP-01`, `REQ-<ID>-0n` per trial), no RemoteFunctions.

**Critic checklist (in this order, stop at first failure):** IP grep → shared-file diff is empty (implementer touched only D.2 files) → tests green → lint → contract bullets → validation bullets → cleanup bullets → client bullets → design fidelity vs MP-04 card (roles, inputs, win/loss, telegraphs) → copy voice.

---

## F. Integration order and Studio push procedure

Order:
1. Framework stage (§D.1) → report → gate.
2. 12 implementers in parallel (§D.2); each ends with tests + lint output in its doc.
3. Critic pass per trial (§E); fix loops stay inside the trial's four files.
4. Integrate stage, ONE trial at a time, in this order (simplest first, shared-risk last):
   `floorcheck → breather → sorting → ricochet → sweep → upstream → carve → clearance → crawler → armory → stacker → carrier`.
5. Final QA: a full 4-player DEV session with `PerSession = 15` temporarily, then back to 5.

Studio push procedure (Integrate agent; MCP `execute_luau`; the place is `Kenopsia_MainGame`, studio_id `5b86d54d-8aec-4487-a3be-f9fa661f0a9a`):
1. Preflight in the repo: `git status` clean for the files to push; luau-lsp + selene + `lua tests/*.lua` green.
2. `ChangeHistoryService:TryBeginRecording("MP-05 <what>")` — every write below inside one recording; `FinishRecording` at the end even on error (pcall).
3. Shared scripts FIRST, `.Source` edited in place (never delete/recreate; `sessionDebugId` must stay stable): `Pacing, Playlist, GameConfig, MachineFlow, KenopsiaClient, MachineLayout`; new ModuleScripts created under the exact parents (`ServerScriptService.KenopsiaServer.Services.TrialKit`, `…Services.<Name>`, `ReplicatedStorage.Kenopsia.Shared.Rules.TrialRules/<Name>Rules`, `…Shared.Config.AnimationIds`, `StarterPlayer.StarterPlayerScripts.TrialClientKit`, `…StarterPlayerScripts.TrialClients` Folder + 12 ModuleScripts) — create only if `FindFirstChild` is nil, else edit `.Source`.
4. Per trial: write the four sources; flip `ready=true` for that id in `MachineFlow`; add `SoundService.KenopsiaAudio.Music.Trials.<id>` (Sound, id per D6, Volume like the source, Looped true).
5. Verify: MCP `script_read` of each pushed script hashes equal to the repo file; `get_console_output` clean after `start_stop_play` (Studio play test, 1 player: set `workspace:SetAttribute("KenopsiaNoAuto", true)` only if the auto-seat interferes); confirm the roulette lists the trial, the round runs, `end` arrives, players return home, no leaked instances (`workspace.KenopsiaArenas.<id>` has no `_Runtime` folder after the round).
6. Never save/publish from script; never touch instances other than the scripts above and the new Folder/ModuleScripts/Sounds; the user publishes.
7. Update `docs/MP-05-QA-<id>.md` and the sourcemap if luau-lsp needs it (`rojo sourcemap default.project.json -o sourcemap.json`).

Rollback: `ready=false` for the trial + remove its id from `GameConfig.Playlist.TrialIds` (both gates) — the modules may stay.

---

## G. Manual user steps (cannot be automated)

1. **M1 — Publish the five player clips** (MP-03 §2.2 M1): select `Workspace.PS1Player_AllAnims` → Animation Editor → for `Idle/Walk/Run/Crouch/Push` set Looping ON, priority Idle/Movement/Movement/Movement/Action → Publish → paste ids into `Shared/Config/AnimationIds.luau` (`AnimationIds.Player.*`). Until then everything runs with no animation (by design).
2. **M2 — Import + publish the six boss clips** (`TableManners\export\anim\*.fbx`) → `AnimationIds.Boss.*` (used by the future Canteen boss, not by the 12 trials).
3. **M3 — Optional textures** (blink/happy/hurt atlases) → `AnimationIds.Textures.*`.
4. **StarterCharacter choice** (D9): the 12 trials ship against the default R15 avatar. After M1, decide whether to enable the PS1 rig as `StarterPlayer.StarterCharacter` in DEV behind `GameConfig.Character.UsePS1Rig` (MP-03 §3 option C, import scale 0.714, re-publish clips at that scale). Nothing in the 12 trials depends on the choice.
5. **Audio**: confirm the reused music ids and every SFX are permitted for the universe (play-test a published DEV session; private audio fails silently). Approve any new SFX/music uploads listed in MP-04 §13.5 as ledger rows.
6. **Session length**: confirm `PerSession = 5` (D7) or give another number.
7. **Icons**: optionally commission the seven new pixel-block glyphs (chisel, arrow, syringe, cigarette, blade, pallet, funnel) — until then the tiles repeat existing icons.
8. **Housekeeping** (MP-03 M4): after M1, allow the Integrate agent to move the rigs into `ServerStorage.KenopsiaAssets.Rigs` and delete the Mixamo shells and stray props — deletion is the user's call.
