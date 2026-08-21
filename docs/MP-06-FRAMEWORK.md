# MP-06 — FRAMEWORK (what the Framework stage built, and the exact APIs the 12 implementers write against)

Status: BUILT 2026-08-17 (Framework stage of docs/MP-05-BUILD-PLAN.md §D.1). This file is the
implementer's contract AND the Framework report. Where it differs from MP-05 the difference is
listed in §7 with the reason; everywhere else MP-05 §A/§B/§C/§E stand unchanged.

> IP NOTE (REQ-IP-01). No reference-game minigame name appears in `studio-src/`, `tests/` or
> `default.project.json`. `tests/rules.lua` now greps every file `default.project.json` maps
> for the forbidden token list (Title Case, UPPER, CamelCase, joined, snake_case, plain) and
> fails the gate on a hit. Keep it that way in comments too.

---

## 0. Ownership rules (D13 — read before touching anything)

You are ONE of twelve parallel implementers. You may create/overwrite ONLY these four files:

1. `studio-src/ServerScriptService/KenopsiaServer/Services/<Name>.luau` (server, on TrialKit)
2. `studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/<Name>Rules.luau` (pure, Lua 5.1-portable)
3. `studio-src/StarterPlayer/StarterPlayerScripts/TrialClients/<id>.luau` (client, on TrialClientKit)
4. `tests/<id>.lua` (offline proof, ≥ 15 checks, `os.exit(failures > 0 and 1 or 0)`)

plus optionally `docs/trials/<id>.md`. All four already exist as compliant stubs; overwrite them.

NEVER edit: `MachineFlow.luau`, `TrialKit.luau`, `TrialClientKit.luau`, `TrialRules.luau`,
`Pacing.luau`, `Playlist.luau`, `GameConfig.luau`, `AnimationIds.luau`, `KenopsiaClient.client.luau`,
`MachineLayout.client.luau`, `default.project.json`, `tests/rules.lua`, `tests/trialrules.lua`,
`tests/animationids.lua`, or another trial's four files. If a kit function is missing, write a
`local` helper inside your own module and leave a one-line note in `docs/trials/<id>.md`.

Your row (id / Name / display / icon / subtitle / tagline / rounds / RoundSeconds / origin) is
MP-05 §A. `MachineFlow.TRIALS`, `Pacing.ROUNDS`, `Pacing.RoundSeconds`, `Playlist.Ids`,
`GameConfig.Playlist.TrialIds` and `GameConfig.Arenas.Origins` already carry it. `ready` stays
`false` in the registry — the Integrate stage flips it.

| id | Name (server module) | Rules module | client module | test |
|---|---|---|---|---|
| carve | CutToSpec | CutToSpecRules | TrialClients/carve.luau | tests/carve.lua |
| armory | ArmsIssue | ArmsIssueRules | TrialClients/armory.luau | tests/armory.lua |
| upstream | Upstream | UpstreamRules | TrialClients/upstream.luau | tests/upstream.lua |
| floorcheck | FloorCheck | FloorCheckRules | TrialClients/floorcheck.luau | tests/floorcheck.lua |
| clearance | Clearance | ClearanceRules | TrialClients/clearance.luau | tests/clearance.lua |
| carrier | Carrier | CarrierRules | TrialClients/carrier.luau | tests/carrier.lua |
| breather | Breather | BreatherRules | TrialClients/breather.luau | tests/breather.lua |
| sweep | ClearTheDeck | ClearTheDeckRules | TrialClients/sweep.luau | tests/sweep.lua |
| crawler | Crawler | CrawlerRules | TrialClients/crawler.luau | tests/crawler.lua |
| ricochet | Ricochet | RicochetRules | TrialClients/ricochet.luau | tests/ricochet.lua |
| stacker | PalletDuty | PalletDutyRules | TrialClients/stacker.luau | tests/stacker.lua |
| sorting | SortingFloor | SortingFloorRules | TrialClients/sorting.luau | tests/sorting.lua |

Gate for your trial (the critic runs these, in this order): IP grep → `git diff --stat` shows only
your four files → `lua tests/<id>.lua` green → `luau-lsp analyze --definitions=globalTypes.d.luau
--base-luaurc=.luaurc --sourcemap=sourcemap.json <your files>` and `selene <your files>` clean → the
MP-05 §E bullets.

---

## 1. Wire protocol (D1/D2/D3, unchanged)

Server → client (`ReplicatedStorage.Kenopsia.Remotes.MachineState`), everything a new trial sends:

| packet | who sends it | when |
|---|---|---|
| `{kind="trial", trialId, ev="begin", roundToken, roundIndex, roundCount, roundSeconds, ...}` | `R:begin(fields)` | first packet of the round, after `R:place`, before the countdown |
| `{kind="trial", trialId, ev="deadline", roundToken, endsAt=<server time>, seconds}` | `R:setDeadline()` (auto at GO if you never call it) | once; the client kit stores `endsAt` for `kit.timer()` |
| `{kind="trial", trialId, ev="out", roundToken, text}` | `R:out(uid, text)` | non-lethal elimination, to that player only |
| `{kind="trial", trialId, ev="end", roundToken}` | `R:cleanup()` | last packet, EVERY exit path |
| `{kind="trial", trialId, ev="<yours>", ...}` | `TrialKit.send / sendOne` | anything else (`template`, `call`, `state`, ...) |
| `{kind="announce", text}` / `{kind="announce", style="death", text}` | `R:cover`, `R:kill` | opaque cover / death card |
| `{kind="count", n}` `{kind="go"}` `{kind="gorefx", pos, power}` | `R:countdown`, `R:kill` | generic, unchanged |
| `{kind="role", role="spectate", watch, pos, look, roundToken}` | `R:kill` (3.2 s later), `R:out` | the legacy death cam, unchanged |

Never send `role="runner"/"sniper"/"none"`, never `FireAllClients`, never set `XBotMoves` to
anything containing `scan/eat/sneak/push`.

Client → server (`ReplicatedStorage.Kenopsia.Remotes.TrialInput`), what `kit.send` produces:
`{ trialId, action, roundToken, seq=<monotonic per client>, v=1, data=<table|nil> }`.
The server kit validates the whole chain (§2.5) before your handler sees it; only `payload.data`
is yours and you must range-check every field of it.

---

## 2. Server: `TrialKit` (`Services/TrialKit.luau`)

`local TrialKit = require(script.Parent.TrialKit)`. Everything below is real, lint-clean and
used by the twelve stubs. Nothing module-global mutates per room; the only module tables are
the round registries (cleared by `R:cleanup()`), the arena refs cache and the input connections.

### 2.1 Constants
```lua
TrialKit.PALETTE   -- Void Concrete WetConcrete Steel Rust Hazard Signal Blood Grime Bone Sodium (Color3)
TrialKit.BAND      -- { FINISHED = 2000, ALIVE = 1000, OUT = 0 }
TrialKit.key(band, detail)   -- band + clamp(floor(detail), 0, 999)   (== TrialRules.key)
TrialKit.HOME_FALLBACK       -- Vector3.new(0, 5, 0)
TrialKit.Rules               -- the TrialRules module (grid arithmetic, rng, token, inBox, flatDistance)
```

### 2.2 Arena builders (all Anchored, SmoothPlastic, CastShadow=false, Smooth surfaces)
```lua
TrialKit.part{ name, size=Vector3, cf=CFrame | pos=Vector3, color, parent,
               transparency?, canCollide? (default true), canQuery?, canTouch?, neon?, shape? } -> Part
TrialKit.box(name, size, cf, color, parent) -> Part
TrialKit.marker(name, cf, parent) -> Part           -- invisible, non-colliding, CanQuery/CanTouch false, 1^3
TrialKit.slab(parent, origin, sizeX, sizeZ, color)  -- floor whose TOP is origin.Y (thickness 1)
TrialKit.wallBox(parent, origin, sizeX, sizeZ, height, thickness, color) -> { n, s, e, w }
TrialKit.floorGrid(parent, origin, cols, rows, cell, gap, color, namePrefix) -> g
   -- g.parts[c][r], g.cols, g.rows, g.cell, g.gap, g.origin,
   -- g.cellCenter(c, r) -> Vector3 (top of plate), g.cellOf(pos) -> c, r | nil (arithmetic, never Touched)
TrialKit.ensureArenaFolder(trialId) -> Folder        -- workspace.KenopsiaArenas.<id>, both levels created
TrialKit.ensureArena(trialId, buildFn) -> refs|nil   -- idempotent (attribute "Built" + refs cache); origin from
   -- GameConfig.Arenas.Origins[trialId] (nil -> warn + nil). buildFn(folder, origin) must NOT yield and returns
   -- refs { spawn = Part|{Part...}|{CFrame...}, cam = Part, ... }; the kit adds refs.folder and refs.origin.
TrialKit.arenaRefs(trialId) -> refs|nil              -- cached refs after ensureArena ran
TrialKit.partCount(folder) -> n                      -- acceptance: < 300 static parts
```
Example:
```lua
local function buildArena(folder, origin)
	TrialKit.slab(folder, origin, 60, 60, P.Concrete)
	TrialKit.wallBox(folder, origin, 60, 60, 8, 1, P.WetConcrete)
	local grid = TrialKit.floorGrid(folder, origin + Vector3.new(0, 0.05, 0), 6, 8, 5, 0.5, P.Steel, "Plate")
	local spawns = {}
	for i = 1, 4 do
		spawns[i] = TrialKit.marker("Spawn" .. i, CFrame.new(origin + Vector3.new(-9 + (i - 1) * 6, 3, 26)), folder)
	end
	local cam = TrialKit.marker("Cam", CFrame.new(origin + Vector3.new(0, 34, 40)), folder)
	return { spawn = spawns, cam = cam, grid = grid }
end
```

### 2.3 Room / audience / messaging (Minefield semantics)
```lua
TrialKit.livingOf(room) -> {[uid] = {player, char, hum, root}}   -- fresh each call, Health > 0 only
TrialKit.audienceOf(room) -> {Player}
TrialKit.roomActive(room) -> bool                                 -- #members > 0 and phase nil|"Playing"
TrialKit.announce(room, payload) / TrialKit.tellOne(userId, payload)
TrialKit.send(room, trialId, ev, fields?) / TrialKit.sendOne(userId, trialId, ev, fields?)
TrialKit.spectatePacket(watchUserIds, camPart, lookPos, roundToken) -> payload
TrialKit.deathCard(userId, text)
TrialKit.mintToken(trialId, sessionId, roundIndex) -> "<ID>-<session>-R<n>-<ms%100000>"
TrialKit.rng(room, roundIndex) -> nextInt(n)                      -- seeded LCG (Studio == tests)
TrialKit.zeroScores(room) -> {[uid] = 0}
```

### 2.4 Round wrapper
```lua
function Trial.runRound(room, roundIndex)
	return TrialKit.runRound(TRIAL_ID, room, roundIndex, runRoundInner)   -- xpcall + guard.cleanup, re-raises after cleanup
end
```

### 2.5 Input wiring — the whole validation chain, once
```lua
TrialKit.wireInput(TRIAL_ID, {
	actions = { cut = true, submit = true },       -- 3: only these
	cooldown = 0.25,                               -- 11: default per-player, per-action seconds
	perAction = { cut = 0.12 },                    -- 11: overrides
	handler = function(player, ps, payload, R)     -- 12: pcall'd; an error drops the packet, never the connection
		local d = payload.data
		if type(d) ~= "table" then return end
		local x = tonumber(d.x); if not x or x < 1 or x > 3 then return end   -- range-check EVERYTHING
		...
	end,
})
```
Chain enforced before `handler`: 1 table → 2 `trialId` → 3 action ∈ actions → 4 a live round owns
this player (registry) → 5 `R.acceptInput` → 6 `room.phase == "Playing"` → 7 `room.sessionId ==
R.sessionId` → 8 `roundToken == R.roundToken` → 9 `ps` exists and not `ps.done` → 10 `seq` strictly
increasing when numeric → 11 rate gate. Positions come from `R:sample`, never from `data`. A trial
with no input (floorcheck) skips `wireInput`.

### 2.6 Round object
```lua
local R = TrialKit.newRound(TRIAL_ID, room, roundIndex, guard)   -- REGISTERS + arms guard.cleanup, no yield
-- fields: R.room, R.sessionId, R.roundIndex, R.roundToken, R.state[uid] = {done=false, lastInput={}, lastSeq=0, ...yours},
--         R.acceptInput, R.runtime, R.cleaned, R.t0 (set at GO), R.deadline, R.failsafe, R.subjects, R.refs, R.walkSpeed
R:active() -> bool                 -- still registered AND roomActive; EVERY delayed callback checks this first
R:onCleanup(fn)                    -- LIFO, pcall'd at cleanup: connections, tweens, threads
R:runtimeFolder(arenaFolder?) -> Folder "<ID>_Runtime" under the arena, destroyed by cleanup
R:place(spots)                     -- spots = {CFrame|Vector3,...} or fn(i, mm) -> CFrame; spots.walkSpeed (default 16),
                                   -- spots.anchored (seat). Health=Max, root moved, WalkSpeed 0 / JumpPower 0 until GO,
                                   -- originals recorded; members with no living char -> ps.done = true
R:begin(fields?)                   -- ev="begin" to EVERY member (roundCount/roundSeconds filled from Pacing)
R:cover(text?)                     -- announce; "" = opaque black
R:wait(seconds) -> bool            -- <= 0.1 s slices; false as soon as not active
R:countdown() -> bool              -- 3-2-1-GO; opens input, R.t0, applies spots.walkSpeed server-side, arms the
                                   -- default deadline if none; false if aborted (input stays closed)
R:openInput() / R:closeInput()
R:setMovement(uid, walkSpeed?, anchored?)     -- server-side mid-round change, restored at cleanup
R:sample(uid, dt, maxSpeed, aabb?) -> Vector3|nil   -- anti-teleport clamp: XZ speed > maxSpeed*dt*1.5 or outside
                                   -- aabb {minX,maxX,minY,maxY,minZ,maxZ} -> root snapped back to last good pos, returns it
R:setDeadline(seconds?)            -- default Pacing.RoundSeconds[id]; failsafe = deadline + 20; sends ev="deadline"
R:tick(fn)                         -- while now < deadline and < failsafe: task.wait(0.05); break if not active; fn(dt) == "stop" breaks
R:kill(uid, {text, pos?, power=1.5, camPart?, look?})   -- D12: BloodFX.kill, Health 0, gorefx, death card, spectate after 3.2 s
R:out(uid, text, {camPart?, look?, spectate=false?})     -- non-lethal: ev="out", WalkSpeed 0, spectate packet
R:stillRunning(exceptUid) -> {uid,...}
R:scores(fn) -> {[uid]=n}          -- complete zero-filled over room.members; scores[uid] = fn(uid, ps) or 0 (pcall'd)
R:endRound() -> bool               -- closeInput; if active: cover("") + 0.6 s; returns active()
R:cleanup()                        -- idempotent: unregister, teardown LIFO, restore humanoids, teleport home,
                                   -- destroy runtime, BloodFX.clear(token, audience), ev="end"
```

### 2.7 The module shape (this IS the stub; keep it)
```lua
--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrialKit = require(script.Parent.TrialKit)
local Rules = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("<Name>Rules"))
local Trial = {}
local TRIAL_ID = "<id>"
local P = TrialKit.PALETTE

local function buildArena(folder, origin) ... return { spawn = ..., cam = ... } end

function Trial.init()
	TrialKit.wireInput(TRIAL_ID, { actions = {...}, handler = function(player, ps, payload, R) ... end })
	pcall(TrialKit.ensureArena, TRIAL_ID, buildArena)
end

local function runRoundInner(room, roundIndex, guard)
	local scores = TrialKit.zeroScores(room)
	local refs = TrialKit.ensureArena(TRIAL_ID, buildArena)
	if not refs then warn("[<ID>] arena unavailable") return scores end
	local R = TrialKit.newRound(TRIAL_ID, room, roundIndex, guard)
	local nextInt = TrialKit.rng(room, roundIndex)
	local layout = Rules.generate(nextInt, #room.members)        -- pure, tested offline
	local runtime = R:runtimeFolder(refs.folder)                  -- per-round props go here
	R:place(function(i) return refs.spawn[math.min(i, #refs.spawn)].CFrame end)
	R:begin({ ...public layout fields only... })
	R:cover(TAGLINE)
	if not R:wait(2.8) then return scores end
	if not R:countdown() then return scores end
	R:setDeadline()                                                -- optional (auto at GO)
	R:tick(function(dt)
		for uid, ps in R.state do
			if not ps.done then
				local pos = R:sample(uid, dt, 16, aabb)
				...
			end
		end
	end)
	if not R:active() then return scores end
	scores = R:scores(function(uid, ps)
		if ps.finished then return TrialKit.key(TrialKit.BAND.FINISHED, ps.spare * 10) end
		if not ps.done then return TrialKit.key(TrialKit.BAND.ALIVE, ps.progress) end
		return TrialKit.key(TrialKit.BAND.OUT, ps.progress)
	end)
	R:endRound()
	return scores
end

function Trial.runRound(room, roundIndex)
	return TrialKit.runRound(TRIAL_ID, room, roundIndex, runRoundInner)
end
return Trial
```

---

## 3. Pure rules: `Shared/Rules/<Name>Rules.luau` + `Shared/Rules/TrialRules.luau`

Rules modules are Lua 5.1-portable (Pacing header: no type annotations, no `for k, v in t`
without pairs/ipairs, no `table.create/clear/clone/freeze`, no `continue`, no `//`, no `+=`).
Randomness arrives as `nextInt(n)`; never `math.random`. Your test loads the module through the
`tests/rules.lua` shim:
```lua
local ROOT = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"
local function loadModule(file, parent)
	local chunk = assert(loadfile(ROOT .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end
local TR = loadModule("TrialRules.luau")
local Rules = loadModule("<Name>Rules.luau", { TrialRules = TR })   -- if your rules require(script.Parent.TrialRules)
local nextInt = TR.rng("S1-1", 1)
```
`TrialRules` (proved by `tests/trialrules.lua`, 37 checks):
```lua
TrialRules.BAND, TrialRules.key(band, detail)
TrialRules.newGrid(cols, rows, cell, gap, x0, z0) -> g       -- (x0, z0) is the grid CENTRE
TrialRules.gridSpan(n, cell, gap)
TrialRules.cellCenter(g, c, r) -> x, z
TrialRules.cellOf(g, x, z) -> c, r | nil                     -- nil in gaps and outside
TrialRules.lcg(seed) -> nextInt(n)                           -- the Playlist generator
TrialRules.hash(str) -> uint32                               -- djb2
TrialRules.rng(sessionId, roundIndex) -> nextInt(n)
TrialRules.shuffle(list, nextInt) -> list                    -- Fisher-Yates in place
TrialRules.token(trialId, sessionId, roundIndex, ms) / TrialRules.tokenMatches(token, trialId)
TrialRules.inBox({minX,maxX,minY,maxY,minZ,maxZ}, x, y, z) -> bool
TrialRules.flatDistance(ax, az, bx, bz) -> number
```

`Shared/Config/AnimationIds.luau` (all ids 0 = placeholder; `AnimationIds.resolve(group, name)`
-> `"rbxassetid://<id>"|nil`, `AnimationIds.load(animator, group, name)` -> track|nil, never
throws). No other module contains an animation asset id.

---

## 4. Client: `TrialClientKit` + `TrialClients/<id>.luau`

### 4.1 Module contract
```lua
local M = {}
local kit
M.controlsText = { sec1 = "PLAYERS:", sec2 = "RULE:", lines = { "Move", "Cut [E]", "Submit [Space]", "" } }
function M.init(k) kit = k end                -- once per client lifetime; build NOTHING here
function M.onPacket(p) ... end                -- every {kind="trial", trialId=<id>} incl. begin, plus observed
                                              -- generic kinds count/go/announce/hide/gorefx/role (copies, read-only)
function M.onEnd() ... end                    -- clear your tables; the router tears down HUD/pad/keys/conns/tweens/cam/movement
return M
```
`controlsText` = `{ title?, sec1?, sec2?, lines = {Row1, Row1b, Row2, Row3} | Desktop/Mobile/Console = {4 lines},
icons?, scoring? }` — MachineLayout maps it onto the CONTROLS window (unknown ids fall back to a neutral
row, never to the sniper text). Keep module top level side-effect free: MachineLayout `require`s it for the
text before any round.

Ordering guarantees: `begin` arrives after the round card `hide` and after placement, before `count`;
`count/go` follow within ~3 s; `deadline` arrives at GO (or when the server calls `setDeadline`);
`end` arrives at cleanup on every path; the `KenopsiaActiveTrial` attribute clear ends the module even
if `end` was lost; a lobby packet (`selection/info/score`) also ends it. Movement is FROZEN at `begin`
(the router does that); call `kit.movement.set(speed)` when you observe `p.kind == "go"`.

### 4.2 `kit` API (one kit per trial id, handed to `init`)
```
kit.trialId, kit.player, kit.machine, kit.palette (PHOSPHOR IDLE DIM AMBER DANGER WARN SAFE PANEL INK BLOOD, .world = server PALETTE)
kit.isActive() / kit.roundToken() / kit.deadline() (server time or nil) / kit.serverNow() / kit.touchAllowed()
kit.send(action, data?, cooldown?) -> bool      -- drops when inactive/no token/inside cooldown (default 0.1 s)
kit.hud() -> Frame "TrialHud_<id>" (ZIndex 58)   kit.pad() -> Frame "TrialTouch_<id>" (ZIndex 68, Visible = touchAllowed)
kit.label(parent, {name,text,size,pos,anchor,color,align,textSize}) -> TextLabel (Font Code)
kit.panel(parent, size?, pos?) -> Frame          kit.button(parent, name, text, pos, color, onActivated) -> TextButton 110x110
kit.meter(parent, {name,size,pos,color,anchor}) -> { frame, fill, set(fraction) }
kit.timer(endsAt?, parent?, {pos,size,color,textSize,align}) -> { label, stop() }   -- counts down from server time; endsAt defaults to the deadline packet
kit.card(text, style?)                          -- the client's announce card; style "death" = death card
kit.edgeGlow(color, transparency, tweenSecs) -> UIStroke      kit.typewrite(label, text, cps)      kit.sfx(name)
kit.camera.top({height=24, back=9, lerp=6, radius?, fixed=false, subject?})   -- fixed=true: one arena-wide shot from arena bounds
kit.camera.fixed(cframe) / kit.camera.follow({offset, look, lerp, subject}) / kit.camera.restore()
kit.movement.set(walkSpeed) / kit.movement.freeze()
kit.bindKey(name, {Enum.KeyCode.E, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonA, ...}, onBegan(input), onEnded?(input))
kit.bindArrows(fn(dir))  -- "Up"|"Down"|"Left"|"Right" from arrows + WASD + DPad      kit.unbind(name)
kit.onRender(fn(dt)) / kit.onHeartbeat(fn(dt))  -- isActive-guarded, disconnected on end
kit.mouseRay(maxDist?, filterInstances?) -> RaycastResult|nil   -- mouse or last touch tap; own character excluded
kit.character() / kit.root()      kit.gore(pos, power)      kit.arena() / kit.arenaRuntime()
kit.flash(part, color?, seconds?)  -- telegraph: neon recolour then restore      kit.tween(instance, props, seconds, style?) -> Tween
```
Example (a two-action trial):
```lua
function M.onPacket(p)
	if p.kind == "trial" and p.ev == "begin" then
		local hud = kit.hud()
		status = kit.label(hud, { text = "STAND BY", textSize = 26 })
		kit.timer(nil, hud)
		kit.camera.top({ height = 26, back = 10 })
		kit.bindKey("cut", { Enum.KeyCode.E, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonA }, function()
			local hit = kit.mouseRay(120)
			if hit and hit.Instance:GetAttribute("Cell") then kit.send("cut", { cell = hit.Instance:GetAttribute("Cell") }) end
		end)
		kit.button(kit.pad(), "Btn_CUT", "CUT", UDim2.new(0.82, 0, 1, -120), kit.palette.SAFE, function() kit.send("cut", {}) end)
	elseif p.kind == "go" then
		kit.movement.set(14)
	elseif p.kind == "trial" and p.ev == "template" then
		render(p.cells)                       -- server already decided; this is a readout
	elseif p.kind == "trial" and p.ev == "out" then
		kit.card(p.text)
	end
end
```

---

## 5. What was edited in shared files (line numbers after the edit, 2026-08-17)

`KenopsiaClient.client.luau`: L203-217 router locals + bounded `WaitForChild("TrialClientKit", 10)`;
L424-426 `moveState == "trial"` branch; L503-508 `elseif trialCam` camera branch (spectate wins);
L1887-1935 router build (deps closures) + `KenopsiaActiveTrial` backstop; L1941-1943 funnel line
`if trialRouter and trialRouter.handle(p) then return end`; L1953-1957 F-1 token adoption before the
spectate early-return; L2162-2163 lobby-kind belt. Legacy behaviour is untouched (84 inserted lines,
0 removed).
`MachineLayout.client.luau`: L173-181 `TRIAL_TEXT.default`; L186-222 `moduleControlsText` (pcall
require, cached); L226 lookup order module → TRIAL_TEXT[id] → default.
`MachineFlow.luau`: 12 requires; 12 registry entries `ready=false`; `playableOrder` uses
`Playlist.session(order, enabled, Config.Playlist.PerSession)`; missing Pacing row now warns.
`Playlist.luau`: 15 ids; new pure `Playlist.session(order, enabledSet, perSession)`.
`Pacing.luau`: 12 ROUNDS rows + 12 RoundSeconds. `GameConfig.luau`: 15 TrialIds, `PerSession = 5`,
`Arenas.Origins` (D4 table verbatim). `default.project.json`: every new file mapped explicitly;
`sourcemap.json` regenerated (`rojo sourcemap default.project.json -o sourcemap.json`).

---

## 6. Test / lint results at hand-off

```
lua tests/rules.lua        84 checks, 0 failed   (15 ids, rounds/seconds rows, session slice, REQ-IP-01 file grep)
lua tests/envelope.lua     27 checks, 0 failed
lua tests/contexts.lua     21 checks, 0 failed
lua tests/trialrules.lua   37 checks, 0 failed
lua tests/animationids.lua 22 checks, 0 failed
luau-lsp analyze (--sourcemap=sourcemap.json) on all 35 new/edited files: no new diagnostics
   (baseline only: KenopsiaClient SameLineStatement L355/356; Minefield/BirdHunting guard.cleanup type notes)
selene on the same set: 0 warnings; the 3 pre-existing KenopsiaClient if_same_then_else errors unchanged
```

---

## 7. Deviations from MP-05 (each deliberate)

| MP-05 said | Built | Why |
|---|---|---|
| `R:place` sets `hum.WalkSpeed = spots.walkSpeed or 16` at placement | placement sets 0 (frozen, like legacy `role frozen=true`); `R:countdown()` applies `spots.walkSpeed or 16` at GO | a server-set 16 replicates over the client's frozen 0 and lets players walk during the countdown; the D10 intent (server also sets speed, belt and braces) is kept, at GO |
| `kit.timer(endsAt)` from an `os.clock` deadline | `R:setDeadline` sends ONE `ev="deadline"` packet with `endsAt` in `workspace:GetServerTimeNow()` time; `kit.timer()` reads it | server `os.clock` is not comparable on the client; one packet, no per-second traffic |
| `R:setDeadline` must be called | optional: `R:countdown()` arms the Pacing default when none is set | one less thing to forget; explicit call still overrides |
| kit's pure parts in `Shared/Rules/TrialRules.luau` | done, plus `Playlist.session` (D7 slice) so `tests/rules.lua` can prove the PerSession property without loading MachineFlow | MachineFlow needs `game` |
| `controlsText = { title, lines }` | `{ title?, sec1?, sec2?, lines | Desktop/Mobile/Console, icons?, scoring? }` | the CONTROLS window has four rows and two section headers; `title` is accepted and ignored |
| `AnimationIds.resolve` = `"rbxassetid://" .. id` | `string.format("rbxassetid://%.0f", id)` | 15-digit ids print in exponent form under Lua 5.1 concatenation; identical output in Luau |
| report file `docs/MP-05-FRAMEWORK-REPORT.md` | this file (`docs/MP-06-FRAMEWORK.md`) | task naming |
| Studio smoke run of the stub session | NOT done (Framework agent must not touch Studio) | Integrate stage: push shared scripts + new modules in one recording, flip one `ready=true` in a DEV copy, run one round of a stub, confirm `begin`/`end`, home teleport, no `_Runtime` leak |
