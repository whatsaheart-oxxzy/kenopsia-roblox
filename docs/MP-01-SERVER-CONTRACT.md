# MP-01 — Server contract for a new trial

Distilled from the shipped code in `studio-src\` (verified against the live place
on 2026-08-17). Line references are to the files as they stand today; re-check them
after any Framework-stage edit to `MachineFlow.luau`.

Files read in full: `Services\MachineFlow.luau`, `Services\Contexts.luau`,
`Services\RoomService.luau`, `Services\Minefield.luau`, `Shared\Rules\{Pacing,
Playlist,Scoring}.luau`, `Shared\Net\Envelope.luau`, `Shared\Config\GameConfig.luau`,
`tests\{rules,contexts,envelope}.lua`, `docs\legacy\DESIGN.md`,
`docs\baseline\GATE1-REPORT.md`. Skimmed: `BirdHunting.luau`, `CanteenProtocol.luau`,
the packet handler of `KenopsiaClient.client.luau` (lines 1865-2095).

---

## 1. Boot and registration

| Step | Where | What happens |
|---|---|---|
| 1 | `Main.server.luau:5-9` | `require(Services.RoomService)`, `require(Services.MachineFlow)`; `RoomService.start()`; `MachineFlow.start(RoomService)`. |
| 2 | `RoomService.start()` → `ensureRemotes()` `RoomService.luau:518-545` | Creates `ReplicatedStorage.Kenopsia` (Folder) → `Remotes` (Folder) and the lobby RemoteEvents `RoomState, LobbyError, RoomCreateRequest, RoomJoinRequest, RoomQuickJoinRequest, RoomLeaveRequest, RoomReadyRequest, RoomStartRequest`. |
| 3 | `MachineFlow.start()` `MachineFlow.luau:574-582` | Finds-or-creates `ReplicatedStorage.Kenopsia.Remotes.MachineState` (RemoteEvent). This is the ONLY server→client channel for trials. |
| 4 | `MachineFlow.luau:584-594` | `pcall(t.module.init)` for EVERY entry of `TRIALS`, ready or not. Your `init()` therefore runs at boot even while `ready = false`. It must be idempotent and must not yield on anything that can be missing (use `FindFirstChild`, not `WaitForChild`, for optional assets). |
| 5 | `MachineFlow.luau:596-599` | `RoomService.RunRequested:Connect(roomId → task.spawn(runMatch, room))`. |
| 6 | `MachineFlow.luau:601-636` | 2 s watchdog: auto-seats players 7 s after join, spawns the lobby `preFlow` roulette. Not trial-relevant. |

The trial registry is the local table `TRIALS` at `MachineFlow.luau:42-93`. Entry
shape (all fields present on every entry):

```lua
{
	id = "minefield",              -- short lowercase ascii; the wire id (payload.trialId, KenopsiaActiveTrial, Pacing key, Playlist id, GameConfig id)
	displayName = "DEAD ZONE",     -- uppercase house style; shown by "info"/"status" cards
	icon = "Cube",                 -- name of a child of the client's selection.IconPool GUI folder (client :1554, :1639). Unknown name = tile renders empty, no error
	subtitle = "…_",               -- NOT read by MachineFlow or the client today (grep clean) — decorative
	tagline = "SCAN AHEAD. WATCH YOUR STEP.", -- second line of the Briefing "status" card (:395) and `verbs` of the "round" card (:422)
	ready = true,                  -- gate 2 (gate 1 = GameConfig.Playlist.TrialIds)
	showInterRoundScore = false,   -- NOT read anywhere today (grep clean) — reserved
	module = Minefield,            -- required at top of MachineFlow (:22-24)
}
```

Schedulability (`enabledTrials()` `:104-117`, `playableOrder()` `:268-279`): a trial
runs iff **all three** hold — id in `GameConfig.Playlist.TrialIds`, registry
`ready = true`, id in `Playlist.Ids` (because `playableOrder` iterates
`Playlist.order(seed)` and drops ids that are not enabled). Missing from
`Playlist.Ids` = silently never played, with no warning.

Optional module hooks MachineFlow calls if present: `module.init()` (boot),
`module.runRound(room, roundIndex)` (required), `module.cleanup(ctx)`
(`:300-302`, `:499`; pcall'd; **no shipped module defines it today**).

---

## 2. The lifecycle MachineFlow drives (`runMatch`, `MachineFlow.luau:281-571`)

Precondition: `RoomService.beginCountdown` (`RoomService.luau:276-309`) has
snapshotted `room.participants = {[userId]=true}`, minted
`room.sessionId = "S<n>-<ms>"`, set `room.phase = "Playing"` and fired
`RunRequested`.

```
runMatch(room)
  seed = math.random(1, 2^31-1)                          :320   (server-minted, never from a client)
  order = playableOrder(seed)                            :321   ALL enabled trials, seed-shuffled — see §9 caveat
  ctx = buildContext(room)                               :328   {sessionId, roundToken, roomId, room, audience, participantUserIds, effectScope, cancelled()}
  session = Contexts.newSession(room.id, participantUserIds, seed)   :333
  zero KenopsiaSessionScore / KenopsiaSessionWins attributes          :347-353  (once per MATCH, never per trial)
  for trialIndex, trial in ipairs(order):
    trialCtx = session:newTrial(trial.id, trialIndex, #order)          :363
    ctx.effectScope = sessionId .. ":" .. trial.id                     :365
    setStage "Selecting"; setProgress{activeTrialId, trialIndex, trialCount, roundIndex=CLEAR, legIndex=CLEAR, legCount=CLEAR}   :370-380
    tell {kind="info", id, name, icon, index, total}                   :388
    hold Pacing.Timing.Reveal (3.5 s)                                  :390
    setStage "Briefing"; tell {kind="status", lines={displayName, tagline, " ", "Minigame i of n.", "Bootstrapping simulation ..."}}   :393-400
    hold Pacing.Timing.ControlCard (8.0 s)                             :401
    setStage "Trial"                                                   :404
    rounds = Pacing.roundsFor(trial.id, playerCount) or 1              :409   (nil row → 1 round, silently)
    for roundIndex = 1, rounds:
      roundCtx = trialCtx:newRound(roundIndex, rounds)                 :415
      setProgress{roundIndex, roundCount}                              :416
      tell {kind="round", n, total, verbs=tagline}                     :421
      hold Pacing.Timing.RoundCard (3.0 s)                             :423
      tell {kind="hide"}                                               :424
      setActiveTrial(ctx, trial.id)   -- Player attribute "KenopsiaActiveTrial" on every audience member   :425 / :180-186
      scores = pcall(trial.module.runRound, room, roundIndex)          :443   ← YOUR ENTRY POINT (Bird alone gets the 5-arg leg call, :438)
        error → error(rScores, 0) → outcome "error"                    :444
        non-table return → {}                                          :445
      setActiveTrial(ctx, "")                                          :448
      roundCtx.cleanup:run()                                           :449   (nothing is registered on it today — the trial cannot see roundCtx)
      trialTotals[uid] += scores[uid]                                  :450-452
      hold Pacing.Timing.RoundSettle (1.5 s)                           :453
    -- SCORE: raw trialTotals → Scoring.rankRound(desc) → Scoring.distribute (exactly 1700)   :460-467
    board = {{userId, displayName, place, points, score=sessionTotal}}  :469-484 ; KenopsiaSessionScore attribute updated :475
    setStage "Score"; tell {kind="score", board, trialId, index, total, final=false}   :486-488
    hold Pacing.Timing.InterimScore (4.5 s)                            :489
    pcall(trial.module.cleanup, ctx) if defined                        :499
    trialCtx:cancel()                                                  :500
  -- FINAL: setStage "FinalScore"; verdict VIABLE (all tied-best) / REJECTED; KenopsiaSessionWins++   :508-531
  tell {kind="score", board=final, final=true}                         :531
  scoresCommitted = true; hold Pacing.Timing.FinalScore (8.0 s)        :535-536
FINALIZER (every route)                                                :539-570
  cleanup(): setActiveTrial ""; pcall(activeTrial.module.cleanup, ctx); session:cancel(); room.preSent=nil; tellRoom{kind="hide"}   :295-316
  outcome error   → RoomService.abort(room, "MINIGAME ERROR")          :552-555  → LobbyError "RUN ABORTED - MINIGAME ERROR" to everyone
  outcome no-trial→ RoomService.abort(room, "NO READY MINIGAME")       :557
  RoomService.cleanupToWaiting(outcome)                                :562   → toWaiting(): phase Waiting, sessionId nil, participants nil, spectators promoted
```

### What MachineFlow does with your scores
* Your `runRound` return is a **raw ordering key per participant**. Only the ORDER
  matters: `Scoring.rankRound(entries, a.raw > b.raw)` then `Scoring.distribute`
  hands out exactly `Pacing.TrialPointPool = 1700` per completed trial by Borda
  weights with tie-averaging (`Scoring.luau:55-137`). Magnitude is irrelevant, so
  use banded keys the way Minefield (`:854-871`: escaped 2000+, eliminated
  0..1000, +1 tiebreak) and Canteen (`FINISHED_BAND 2000 / ALIVE_BAND 1000 /
  ELIMINATED_BAND 0`) do.
* Raw keys are SUMMED across the trial's rounds (`:450-452`) before ranking, so
  keep bands consistent across rounds of the same trial.
* Missing keys read as 0 (`trialTotals[uid] or 0`, `:462`) — but always return a
  complete table anyway (STYLE rule; every existing module zero-fills first).
* `GameConfig.Playlist.PlacementPoints = {3,2,1,0}` exists but is **not used** by
  MachineFlow today (Scoring uses Borda over `n`); do not read it.

### Inter-round score display
There is NO per-round score card. Rounds are separated only by
`RoundSettle` (1.5 s) and the next `"round"` card. The `"score"` board appears
once per TRIAL (after all rounds) and once as the final board.
`showInterRoundScore` is dead. If a trial wants per-round feedback it must
`announce` its own card inside `runRound` (Minefield deliberately does not:
`:876-879`).

### Timers
* MachineFlow does **not** time your round. `runRound` blocks as long as it
  likes; the only guard is `hold()`-style cancellation checks INSIDE your loop.
  A trial that never returns hangs the match (DESIGN.md's rule "the minigame
  never owns the clock" is not enforced by this framework — you must own a
  deadline yourself).
* Take the round length from `Pacing.RoundSeconds[<id>]` and enforce
  `os.clock() >= deadline` in your main loop, plus a failsafe (Minefield:
  `failsafeTime = shredTraversal + 20`, `:741`, loop `:752`).
* Cards: `Reveal 3.5 / ControlCard 8.0 / RoundCard 3.0 / RoundSettle 1.5 /
  InterimScore 4.5 / FinalScore 8.0` (`Pacing.Timing`, `Pacing.luau:81-91`).
  Session overhead per trial ≈ 11.5 s + 4.5 s per round + 4.5 s score.
* Never replicate a ticking countdown; the client counts down itself. Existing
  trials send `{kind="count", n=3..1}` once per second then `{kind="go"}`
  (client `:1985-2050` plays SFX `Count3/2/1`, `AccessGranted`, fades the black
  card in on `n == 3`).

### Cancellation / abort flow
* Sources: participant leaves below `requiredMinimum` →
  `RoomService.abortMatch` (`RoomService.luau:239-251`, phase → `"Aborting"`,
  `room.token += 1`, LobbyError to all); trial exception → MachineFlow outcome
  `"error"`; no trial → `"no-trial"`.
* Predicate: `RoomService.cancelled(sessionId)` = `room.phase ~= "Playing" or
  room.sessionId ~= sessionId` (`:405-407`). Trials that do not receive ctx use
  the equivalent `room.phase == "Playing"` + captured `sessionId` check
  (Minefield `roomActive` `:119-121` + `active()` `:301-303`).
* Contract on abort: `runRound` must **return normally** (a zero/complete
  scores table) as soon as it notices; it must NOT throw. Only genuine
  exceptions propagate (after cleanup) — Minefield `runRound` `:907-926`.
* Every `task.delay` / `task.spawn` / `Touched` / RemoteEvent callback re-checks
  `active()` first (Minefield `:432`, `:486`, `:524`, `:804`).
* Discard partial scores on abort (`:830-834` returns zeros); MachineFlow will
  not show a board for a cancelled session anyway.

### Teleport / spawn responsibilities — MachineFlow does NONE of it
* The trial teleports participants INTO its arena at round start
  (Minefield `:394-398`: `s.root.CFrame = CFrame.lookAt(...)` on
  `HumanoidRootPart`; Canteen anchors roots on seat markers).
* The trial teleports them BACK in its own `cleanup()` to
  `workspace.SpawnLocation.Position + (rand ±6, 4, rand ±6)`, fallback
  `Vector3.new(0,5,0)` (Minefield `:319-326`, Bird `:333`, `:451`). Copy this
  exactly.
* Cover the round trip with an opaque black card first:
  `announce(room, {kind="announce", text=""})` + `task.wait(0.6)` (`:896-899`) —
  an empty announce is rendered fully black by the client.
* Dead players (`hum.Health = 0`) respawn via Roblox default respawn at the
  place SpawnLocation; the trial marks them `done` and (optionally) sends a
  `spectate` role 3.2 s later (`:483-491`). `livingOf(room)` (`:105-117`) is the
  canonical "who still has a Humanoid with Health > 0" filter; call it fresh
  every tick, never cache the character table across yields.
* Health regeneration is disabled place-wide by the empty
  `StarterCharacterScripts\Health.server.luau`; reset `hum.Health =
  hum.MaxHealth` at round start (`:390`).
* Restore anything you changed on the character (WalkSpeed, JumpPower,
  Anchored, attributes `XBotMoves/XBotCrawl/XBotScanning`) in cleanup — Canteen
  keeps a `restore` list `:534-537, :636-645`.

### Audience / spectators
* `room.members` = ordered `{userId, displayName, ready}` of seated players;
  during a match it equals the participants still connected.
  `room.participants` = snapshot `{[userId]=true}` taken at start
  (`RoomService.luau:298-299`); `RoomService.isParticipant(room, userId)`
  (`:153-156`); `RoomService.audience(room)` (`:160-167`) = Player objects of
  connected members. Late joiners sit in `room.spectators` and receive
  **nothing** from trials — every existing sender iterates `room.members`
  (Minefield `announce` `:203-210`, MachineFlow `tell` `:155-160`). Do not
  `FireAllClients`.
* In-trial "spectate" is a ROLE for a participant who is finished/dead:
  `tellOne(uid, {kind="role", role="spectate", watch={userIds still running},
  pos={x,y,z}, look={x,y,z}})` (`:487-490`, `:547-551`). Client `:1876-1885`
  sets a fixed camera at `pos` looking at `look` and cycles `watch`.

---

## 3. Packets, tokens, remotes, folders — exact names

**Server → client:** `ReplicatedStorage.Kenopsia.Remotes.MachineState`
(RemoteEvent). Payload is one table with `kind`. Kinds handled by the client
today (`KenopsiaClient.client.luau:1865-2095`):

| kind | sender | payload |
|---|---|---|
| `selection`, `info`, `status`, `round`, `score`, `hide` | MachineFlow | see §2. Unknown kinds render NOTHING (Gate 1 defect list). |
| `announce` | trials | `{text, style?}`; `text=""` = opaque black cover; `style="death"` = death card (`:481`) |
| `count` / `go` | trials | `{n}` / `{}` |
| `role` | trials | `{role="runner"|"sniper"|"spectate"|"none", roundToken, frozen?, camDir?, camStyle="top"|"chase", pos?, look?, watch?}`. Client stores `trialRoundToken = p.roundToken` (`:1891`) — the round token reaches the client ONLY through a role packet, so **every participant must receive a role packet carrying `roundToken` before input opens**. `role="none"` = release: clears token, cameras, movement locks, CountText (`:1892-1902`). Send it to every member in cleanup. |
| `gorefx` | trials | `{pos={x,y,z}, power, force?}` |
| `mines`, `huntersetup`, `hitmark`, `cp*` | trial-specific | legacy per-trial branches (the Framework stage replaces this with the `TrialClients\<id>` dispatcher). |

**Client → server:** `ReplicatedStorage.Kenopsia.Remotes.TrialInput`
(RemoteEvent), find-or-created by EVERY trial's `init()` (Minefield `:218-225`,
Canteen `:459-466`, Bird `ensureRemote`). Each trial connects its own
`OnServerEvent` and filters on `payload.trialId == "<id>"` first — one remote,
N listeners. Today's client packet is bare `{trialId, action, roundToken}`
(`:856-860`, `:1186-1190`); `Envelope.luau` (`v, sessionId, trialId,
trialToken, roundToken, seq, action, data`) exists with a validator but **is not
wired into any trial or the client**. `Contexts.RoundContext:envelopeExpectation`
is likewise unused because `runRound` never receives the RoundContext.

**Round token today:** minted by the TRIAL, not by Contexts —
`("DZ-%s-R%s-%d"):format(room.sessionId, roundIndex, ms%100000)` (`:291-293`);
Canteen `"CP-…"`. MachineFlow's `ctx.roundToken` (`:138`) and
`roundCtx.roundToken` are never handed to the module. Use the same
`("<ID>-%s-R%s-%d")` mint (prefix = your id in caps).

**Validation chain every input packet passes (Minefield `:226-269`), in order:**
1. `type(payload) == "table"`
2. round state exists for this room/player (`current`/lookup) — else drop
3. `payload.trialId == "<id>"` and `payload.action` ∈ your allowed set
4. `st.acceptInput` (opens at GO, closes at round end / cleanup)
5. `st.room.phase == "Playing"` (kills packets of an aborted match)
6. `st.room.sessionId == st.sessionId` (round's snapshot still the room's)
7. `payload.roundToken == st.roundToken` (freshness; MANDATORY)
8. `st.state[player.UserId]` exists and not `done` (membership + still playing)
9. per-player rate limit (`ps.lastPulse + 0.8 > now → drop`)
10. only then read the character/act. Never trust client positions; validate
    server-side (character `HumanoidRootPart.Position`).

Cheap identity checks precede anything that walks the payload or touches
instances (Envelope's ordering rule, `Envelope.luau:125-127`).

**Player attributes:** `KenopsiaActiveTrial` (`""` or trial id; set by MachineFlow
around `runRound` only; the client keys music/lighting off it `:250-266`,
`:345-348`), `KenopsiaSessionScore`, `KenopsiaSessionWins`, `KenopsiaJoinedAt`.
Character attributes (protocol seam, inert since the XBot removal — GATE1 §
"Removed"): `XBotMoves`, `XBotCrawl`, `XBotScanning`, `XBotAction`.

**Workspace folders:** existing rigs `workspace["Dead Zone"]`,
`workspace["Bird Hunting"]`, `workspace.CanteenProtocol.Rig`; per-round dynamic
folder `DZ_Runtime` parented under the arena (`:351-354`) and destroyed in
cleanup (`:327-330`). Assets: `ServerStorage.KenopsiaAssets.Props.<Trial>`
(`:426`, `:572`), `SoundService.KenopsiaAudio.SFX.<Pool>` (`:454-455`). New
trials: `workspace.KenopsiaArenas.<id>` (create `KenopsiaArenas` if absent),
per-round `<ID>_Runtime` folder inside it.

**Effects:** `BloodFX.kill(pos)`, `BloodFX.shatter(char)`,
`BloodFX.bleed(char, audience, roundToken)`, `BloodFX.clear(roundToken,
audience)` — always scoped by roundToken + audience (REQ-DZ-03), never global.

---

## 4. Compliant trial module skeleton (copy, rename `<ID>`/`<id>`)

Distilled from `Minefield.luau` (`init` `:218-270`, `runRoundInner` `:272-902`,
`runRound` `:907-926`), with the round state looked up per room instead of a
module-global `current`, and a procedural arena. Everything marked `-- ==` is
the contract; the rest is illustrative.

```lua
--!nonstrict
-- <DISPLAY NAME>: <one-line mechanic>.
-- REQ-IP-01: original id "<id>" / display "<DISPLAY NAME>"; the reference name
-- appears nowhere in shipped source, comments included.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodFX = require(script.Parent.BloodFX)
local Pacing = require(ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Shared")
	:WaitForChild("Rules"):WaitForChild("Pacing"))

local Trial = {}
local TRIAL_ID = "<id>"
local ROUND_TIME = Pacing.RoundSeconds[TRIAL_ID] or 45
local INPUT_COOLDOWN = 0.25          -- per-player server-side rate limit, seconds

-- ARENA -----------------------------------------------------------------------
-- Procedural, anchored, SmoothPlastic, flat palette. Built once (idempotent),
-- lives at its own far-apart offset (see plan offset table); per-round props
-- go into a runtime folder that cleanup() destroys.
local ARENA_ORIGIN = Vector3.new(<x>, <y>, <z>)
local PALETTE = { floor = Color3.fromRGB(58, 56, 52), wall = Color3.fromRGB(46, 42, 40), accent = Color3.fromRGB(140, 16, 12) }
local TrialInput

local function part(name, size, cf, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- == idempotent: returns the same refs table on every call, builds only if absent
local function ensureArena()
	local root = workspace:FindFirstChild("KenopsiaArenas")
	if not root then
		root = Instance.new("Folder"); root.Name = "KenopsiaArenas"; root.Parent = workspace
	end
	local a = root:FindFirstChild(TRIAL_ID)
	if not a then
		a = Instance.new("Folder"); a.Name = TRIAL_ID; a.Parent = root
		part("Floor", Vector3.new(60, 1, 60), CFrame.new(ARENA_ORIGIN), PALETTE.floor, a)
		part("Spawn", Vector3.new(24, 1, 6), CFrame.new(ARENA_ORIGIN + Vector3.new(0, 0.5, 24)), PALETTE.wall, a)
		local cam = Instance.new("Part") -- camera marker: invisible, non-colliding
		cam.Name = "Cam"; cam.Anchored = true; cam.CanCollide = false; cam.CanQuery = false; cam.CanTouch = false
		cam.Transparency = 1; cam.Size = Vector3.new(1, 1, 1)
		cam.CFrame = CFrame.new(ARENA_ORIGIN + Vector3.new(0, 45, 0)); cam.Parent = a
	end
	local r = { folder = a, floor = a:FindFirstChild("Floor"), spawn = a:FindFirstChild("Spawn"), cam = a:FindFirstChild("Cam") }
	if not (r.floor and r.spawn) then return nil end
	return r
end

-- ROOM HELPERS (verbatim from Minefield :105-141, :203-216) ------------------
local function livingOf(room)
	local out = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		local char = plr and plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if plr and char and hum and root and hum.Health > 0 then
			out[mm.userId] = { player = plr, char = char, hum = hum, root = root }
		end
	end
	return out
end

local function roomActive(room)
	return #room.members > 0 and (room.phase == nil or room.phase == "Playing")
end

local function audienceOf(room)
	local audience = {}
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then table.insert(audience, plr) end
	end
	return audience
end

local function announce(room, payload)   -- == members only, never FireAllClients
	local MachineState = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")
	if not MachineState then return end
	for _, mm in room.members do
		local plr = Players:GetPlayerByUserId(mm.userId)
		if plr then MachineState:FireClient(plr, payload) end
	end
end

local function tellOne(userId, payload)
	local MachineState = ReplicatedStorage.Kenopsia.Remotes:FindFirstChild("MachineState")
	local plr = Players:GetPlayerByUserId(userId)
	if MachineState and plr then MachineState:FireClient(plr, payload) end
end

-- ROUND STATE LOOKUP -----------------------------------------------------------
-- No module-global `current` shared across rooms: state hangs off the room id
-- and off the player, and both entries are removed by cleanup().
local roundByRoomId = {}
local roundOfUser = {}

-- INPUT -----------------------------------------------------------------------
local ACTIONS = { act = true }   -- the actions this trial accepts

local function onInput(player, payload)
	if type(payload) ~= "table" then return end                        -- 1
	if payload.trialId ~= TRIAL_ID then return end                     -- 3 (cheap id filter FIRST: TrialInput is shared by every trial)
	if not ACTIONS[payload.action] then return end
	local st = roundOfUser[player.UserId]                              -- 2
	if not st then return end
	if not st.acceptInput then return end                              -- 4
	if not st.room or st.room.phase ~= "Playing" then return end       -- 5
	if st.room.sessionId ~= st.sessionId then return end               -- 6
	if payload.roundToken ~= st.roundToken then return end             -- 7 MANDATORY
	local ps = st.state[player.UserId]
	if not ps or ps.done then return end                               -- 8
	local now = os.clock()
	if (ps.lastInput or 0) + INPUT_COOLDOWN > now then return end      -- 9
	ps.lastInput = now
	-- 10: act. Only server-side truth (character root, st tables); payload.data
	-- is a hint to be range-checked, never a position to be trusted.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	-- ... trial logic ...
end

function Trial.init()   -- == idempotent; called at boot for ready=false too
	local folder = ReplicatedStorage:WaitForChild("Kenopsia"):WaitForChild("Remotes")
	TrialInput = folder:FindFirstChild("TrialInput")
	if not TrialInput then
		TrialInput = Instance.new("RemoteEvent")
		TrialInput.Name = "TrialInput"
		TrialInput.Parent = folder
	end
	if Trial._conn then Trial._conn:Disconnect() end
	Trial._conn = TrialInput.OnServerEvent:Connect(onInput)
	pcall(ensureArena)   -- never let a build error break boot
end

-- ROUND -----------------------------------------------------------------------
local function runRoundInner(room, roundIndex, guard)
	local scores = {}
	for _, mm in room.members do scores[mm.userId] = 0 end             -- == complete table, zero-filled first
	local R = ensureArena()
	if not R then
		warn("[" .. TRIAL_ID .. "] arena missing")
		return scores
	end

	local roundState = {
		room = room,
		sessionId = room.sessionId,
		roundToken = ("<ID>-%s-R%s-%d"):format(tostring(room.sessionId), tostring(roundIndex or 1), math.floor(os.clock() * 1000) % 100000),
		state = {}, runtime = nil, acceptInput = false, cleaned = false,
	}
	roundByRoomId[room.id] = roundState
	for _, mm in room.members do roundOfUser[mm.userId] = roundState end

	-- == every loop, wait and delayed callback tests this
	local function active()
		return roundByRoomId[room.id] == roundState and roomActive(room)
	end

	-- == the one teardown path: idempotent; happy path, abort and xpcall handler all reach it
	local function cleanup()
		if roundState.cleaned then return end
		roundState.cleaned = true
		roundState.acceptInput = false
		if roundByRoomId[room.id] == roundState then roundByRoomId[room.id] = nil end
		for uid, st in pairs(roundOfUser) do if st == roundState then roundOfUser[uid] = nil end end
		-- disconnect any Touched/Heartbeat connections here
		local spawnPos = workspace:FindFirstChild("SpawnLocation")
			and workspace.SpawnLocation.Position or Vector3.new(0, 5, 0)
		for _, s in livingOf(room) do
			s.hum.WalkSpeed = 16; s.hum.JumpPower = 50; s.root.Anchored = false   -- restore what you changed
			s.char:SetAttribute("XBotMoves", "")
			s.root.CFrame = CFrame.new(spawnPos + Vector3.new(math.random(-6, 6), 4, math.random(-6, 6)))
		end
		if roundState.runtime then roundState.runtime:Destroy(); roundState.runtime = nil end
		BloodFX.clear(roundState.roundToken, audienceOf(room))
		for _, mm in room.members do tellOne(mm.userId, { kind = "role", role = "none" }) end
	end
	guard.cleanup = cleanup                                            -- == armed BEFORE the first yield

	announce(room, { kind = "announce", text = "<TAGLINE>." })
	task.wait(2.8)
	if not active() then return scores end                             -- == abort during the card must not start a round

	local runtime = Instance.new("Folder")
	runtime.Name = "<ID>_Runtime"
	runtime.Parent = R.folder
	roundState.runtime = runtime
	-- build per-round props into `runtime` here

	-- place players, hand out the token
	local subjects = livingOf(room)
	local n = 0
	for _, mm in room.members do
		local s = subjects[mm.userId]
		roundState.state[mm.userId] = { done = s == nil, progress = 0 }
		if s then
			s.hum.Health = s.hum.MaxHealth
			local w = math.max(R.spawn.Size.X - 6, 8)
			local x = R.spawn.Position.X - w / 2 + w * ((n + 0.5) / math.max(#room.members, 1))
			n += 1
			s.root.CFrame = CFrame.lookAt(Vector3.new(x, R.spawn.Position.Y + 4, R.spawn.Position.Z), Vector3.new(x, R.spawn.Position.Y + 4, ARENA_ORIGIN.Z))
		end
		-- == role packet carries roundToken and camStyle; the client only learns the token from here
		tellOne(mm.userId, { kind = "role", role = "runner", frozen = true, camDir = -1, camStyle = "top", roundToken = roundState.roundToken })
	end

	for c = 3, 1, -1 do
		if not active() then return scores end
		announce(room, { kind = "count", n = c })
		task.wait(1)
	end
	if not active() then return scores end
	announce(room, { kind = "go" })
	roundState.acceptInput = true                                      -- == input opens at GO only
	print(("[%s] go; members=%d token=%s"):format(TRIAL_ID, #room.members, roundState.roundToken))

	local t0 = os.clock()
	local deadline = t0 + ROUND_TIME
	while os.clock() < deadline do
		task.wait(0.05)
		if not active() then break end                                 -- == abort ends the loop now, not at the failsafe
		local liv = livingOf(room)
		local allDone = true
		for uid, ps in roundState.state do
			if not ps.done then
				local s = liv[uid]
				if not s then ps.done = true else allDone = false
					-- ... per-tick server-authoritative logic on s.root.Position ...
				end
			end
		end
		if allDone then break end
		if #room.members == 0 then break end
	end
	roundState.acceptInput = false
	if not active() then return scores end                             -- == aborted round scores nothing

	-- ORDERING KEYS, banded (finished 2000+, alive 1000+, out 0+). Only order matters.
	for uid, ps in roundState.state do
		scores[uid] = ps.finished and (2000 + (ps.spare or 0)) or math.floor(1000 * math.clamp(ps.progress or 0, 0, 1))
	end

	if active() then                                                   -- black cover before cleanup() teleports everyone home
		announce(room, { kind = "announce", text = "" })
		task.wait(0.6)
	end
	return scores
end

-- == verbatim contract from Minefield.runRound :907-926
function Trial.runRound(room, roundIndex)
	local guard = {}
	local ok, result = xpcall(function()
		return runRoundInner(room, roundIndex, guard)
	end, debug.traceback)
	if guard.cleanup then pcall(guard.cleanup) end
	if not ok then
		warn("[" .. TRIAL_ID .. "] round errored: " .. tostring(result))
		error(result, 0)   -- teardown already ran; MachineFlow sets outcome="error" and aborts
	end
	return result
end

return Trial
```

Notes on the skeleton:
* `Contexts.guardedRun(scope, fn)` (`Contexts.luau:236-243`) is the generalised
  form of the `guard`/xpcall wrapper and `Contexts.newCleanupScope()` the
  generalised `cleanup()`. They are usable inside a module today (`local scope
  = Contexts.newCleanupScope(); scope:add(fn)`; `Contexts.guardedRun(scope,
  ...)`) but MachineFlow still calls the OLD signature `runRound(room,
  roundIndex)`, so the RoundContext/roundToken from Contexts never reaches the
  module. Keep the trial-minted token until the Framework stage threads ctx.
* If the Framework stage adds a shared `TrialBase`/kit for the helper block
  (livingOf/announce/tellOne/arena `part()`), do it once and require it — but
  keep `active()`/`cleanup()` inside `runRoundInner`, they close over round
  state.
* Bird's `arenaBusy` mutex (`BirdHunting.luau:900-921`) is only needed if the
  arena is a single shared rig; per-id procedural arenas do not need it.

---

## 5. Edits a new trial needs outside its module

| File | Edit | Line |
|---|---|---|
| `Services\MachineFlow.luau` | `local <Name> = require(script.Parent.<Name>)` and a `TRIALS` entry (`id, displayName, icon, subtitle, tagline, ready, showInterRoundScore=false, module`). Keep `ready = false` until the client module exists. Add the icon name to the client GUI `selection.IconPool` (or accept a blank tile). | `:22-24`, `:42-93` |
| `Shared\Rules\Pacing.luau` | `ROUNDS.<id> = { [2]=…, [3]=…, [4]=… }` (else `roundsFor` returns nil → MachineFlow plays 1 round). `Pacing.RoundSeconds.<id> = <s>`. Pure/Lua-5.1-portable file: no types, no generalized `for k,v in t`, pairs/ipairs only. | `:34-37`, `:61-65` |
| `Shared\Rules\Playlist.luau` | Append `"<id>"` to `Playlist.Ids` — otherwise never scheduled, silently. | `:27` |
| `Shared\Config\GameConfig.luau` | Append `"<id>"` to `Playlist.TrialIds`. | `:38` |
| `default.project.json` | `"ServerScriptService"."KenopsiaServer"."Services"."<Name>": { "$path": "studio-src/ServerScriptService/KenopsiaServer/Services/<Name>.luau" }` and, for the client module, a new `"TrialClients": { "$className": "Folder", "<id>": { "$path": "studio-src/StarterPlayer/StarterPlayerScripts/TrialClients/<id>.luau" } }` under `StarterPlayerScripts`. Every file is mapped explicitly; no `$path` on a folder. | Services block, StarterPlayerScripts block |
| `tests\rules.lua` | Add `{ "<id>", 2, r2 }, { "<id>", 3, r3 }, { "<id>", 4, r4 }` to `expected` (`:48-52`); extend the `RoundSeconds` check (`:64-65`). **And fix the hard-coded 3:** `:79` `if #order ~= 3` must become `#Playlist.Ids`, and the "all 6 permutations reachable" search (`:91-105`) must be replaced (with N ids there are N! orders — e.g. assert `distinct >= 6` within 2000 seeds and keep the permutation/determinism checks). Do this in the Framework stage, once. | `:48-52`, `:64`, `:79`, `:105` |
| `tests\<id>.lua` | Offline proof of the trial's pure logic (grid/sequence/sorting/timers) — see §6. | new |
| Studio (Integrate stage) | Create the ModuleScript `ServerScriptService.KenopsiaServer.Services.<Name>` and `StarterPlayer.StarterPlayerScripts.TrialClients.<id>`, write `.Source`; edit `MachineFlow`, `Pacing`, `Playlist`, `GameConfig` `.Source` in place. | — |

Also `Pacing.roundsFor` special-cases `"birdhunt"` (`:46-48`); do not add more
special cases there — a trial that counts legs should still be a `ROUNDS` row.

---

## 6. Offline test harness pattern

Interpreter: **`C:\Lua\bin\lua.exe` (Lua 5.1.5, on PATH as `lua`)**. All three
suites pass today (33 / 21 / 27 checks). `luau.exe` in `C:\Users\Asus\Roblox
Project\tools\` does NOT work for these tests — it has no `loadfile`
(`tests/rules.lua:19: attempt to call a nil value`). Run from the repo root:
`lua tests/rules.lua && lua tests/envelope.lua && lua tests/contexts.lua`.

The shim (`tests/rules.lua:18-25`):

```lua
local ROOT = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"
local function loadModule(file, parent)
	local chunk = assert(loadfile(ROOT .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }   -- script.Parent.X = already-loaded module
	env.require = function(m) return m end   -- require is the identity
	setfenv(chunk, env)
	return chunk()
end
local Pacing = loadModule("Pacing.luau")
local Scoring = loadModule("Scoring.luau", { Pacing = Pacing })
```

`tests/contexts.lua:15-30` extends `env` with a `game.GetService("HttpService")`
stub returning `GenerateGUID` and a silent `warn`. `check(ok, label, detail)`
counts failures, prints `PASS`/`FAIL`, and the file ends `os.exit(failures > 0
and 1 or 0)` so it works as a gate.

Consequences for a new trial:
* Put the pure logic (grid generation, sequences, sort rules, tile picking,
  timers) in a **separate pure module** with NO `game`/services/instances/
  `os.clock`, portable to Lua 5.1 (no `:` type annotations, no `for k, v in t`
  without pairs/ipairs, no `table.create/clear/clone/freeze`, no `continue`, no
  `//` or `+=`), e.g. `Shared\Rules\<Id>Rules.luau` (map it in
  `default.project.json` and require it from the server module via
  `ReplicatedStorage.Kenopsia.Shared.Rules.<Id>Rules`). The server module
  itself may use full Luau.
* Inject randomness: pure functions take a `nextInt(n)` or seed and use the
  Playlist LCG style, never `math.random`, so Studio and Lua 5.1 agree
  (`Playlist.luau:7-18`).
* `tests\<id>.lua` loads THAT shipped file via the shim above; never a copy.
* Do NOT change the load-order rule: `Scoring` requires `Pacing` via
  `script.Parent.Pacing`, so pass the parent table explicitly.

---

## 7. Anti-pattern checklist (explicitly forbidden in the repo)

Sourced from comments in the code, GATE1-REPORT "errors from the plan's
forbidden list", PHASE1-CORRECTIONS and the STYLE rules.

1. **Reference-game names anywhere in shipped source** — ids, display names, UI
   text, comments (`MachineFlow.luau:70-75`, `GameConfig.luau:34-37`,
   `tests/rules.lua:115`). Also no borrowed framing words (the "Kastrierer" →
   "Compactor" rename, `Minefield.luau:558-561`).
2. **RemoteFunctions.** RemoteEvents only; server never awaits a client.
3. **`FireAllClients` / broadcasting to spectators from a trial** — iterate
   `room.members` / captured audience (`MachineFlow.luau:154`).
4. **Global effect clears** (`BloodFX.clear()` server-wide) — scope by
   roundToken + audience (REQ-DZ-03, `Minefield.luau:331-335`).
5. **Module-global mutable `current` shared across rooms** (`Contexts.luau:33-38`).
   Minefield/Canteen still carry a module `current` (grandfathered, single
   canonical room); new modules key state by room/player.
6. **Delayed callbacks that do not re-check `active()`** — `task.delay`,
   `task.spawn`, `Touched`, remote handlers (`Contexts.luau:22-31`, Minefield C1.d
   sites).
7. **Swallowing round errors and returning zeros** — cleanup, then `error(result,
   0)` (`Minefield.luau:913-924`, `Contexts.luau:229-235`).
8. **Throwing on cancellation** — cancellation is a normal `return scores`.
9. **Double cleanup / non-idempotent teardown** (`Contexts.luau:68-77`,
   `roundState.cleaned` latch).
10. **Bare returns after `guard.cleanup` is armed that skip teardown** — the
    wrapper handles it, but never `return` from `runRoundInner` before arming
    `guard.cleanup` once anything has been changed in the world.
11. **Accepting input without the full chain** — trialId, action, roundToken,
    sessionId, phase, membership/done, rate limit (`Minefield.luau:231-251`).
    Token is freshness, not authorisation: it does not replace the other checks
    (`:240-241`).
12. **Trusting client positions/hits** — server-side distance/cell checks; mines
    are server records, never Parts a client can enumerate (REQ-DZ-02,
    `:364-373`).
13. **Hard-coded round counts in the registry** (the old 10/5) — `Pacing.ROUNDS`
    only (`MachineFlow.luau:406-408`; `Pacing.luau:39-42`).
14. **Fixed speeds that silently change round length** — derive from
    `Pacing.RoundSeconds` and arena distances (`Minefield.luau:18-40`).
15. **Score bonuses that can cross bands / points as magnitude** — banded
    ordering keys; only ORDER feeds `Scoring` (`Minefield.luau:838-853`).
16. **New `kind`s expecting the client to render them** — an unknown kind renders
    nothing (`MachineFlow.luau:381-384`); with the Framework dispatcher, only
    kinds your `TrialClients\<id>` handles may be trial-specific.
17. **`{kind="hide"}` between the score board and the next reveal** — every
    `show*` calls `hideAll()` (`:491-494`).
18. **Resetting session score attributes per trial** (`:342-346`).
19. **Sending a role packet without `roundToken`**, or opening `acceptInput`
    before GO / leaving it open after the round (`:242`, `:423`, `:828`).
20. **`WaitForChild` on optional assets in `init()`** — `init()` runs at boot for
    every registered module including `ready = false`; a hang there delays the
    boot loop (`MachineFlow.luau:584-594`, pcall'd but sequential).
21. **Lua-5.1-incompatible syntax in `Shared\Rules`/`Net`** (`Pacing.luau:8-19`)
    and `table.clone` there (`Scoring.luau:56-59`).
22. **Reading `room.roundToken`** — it does not exist (`CanteenProtocol.luau:499-503`).
23. **Rojo `$path` on a folder** — every file mapped explicitly
    (`GATE-M1-BASELINE.md:69`).
24. **Saving the place from script, deleting existing instances, changing script
    identity** — Studio edits are `.Source` in place inside
    `ChangeHistoryService:TryBeginRecording/FinishRecording`.
25. **`.Touched` for tile/grid detection on fast movers** (DESIGN.md) — sample
    `HumanoidRootPart.Position` on the server tick and convert to a cell with
    arithmetic (`Minefield.luau:812-819`). `Touched` is acceptable only for a
    static exit volume, guarded by `active()`.

---

## 8. Quick reference — names

| Thing | Exact name |
|---|---|
| Server→client remote | `ReplicatedStorage.Kenopsia.Remotes.MachineState` |
| Client→server remote | `ReplicatedStorage.Kenopsia.Remotes.TrialInput` |
| Lobby remotes | `RoomState, LobbyError, RoomReadyRequest, RoomStartRequest, …` (same folder) |
| Room fields | `room.id (=1), phase, token, sessionId, stage, members[{userId,displayName,ready}], spectators{[uid]=true}, participants{[uid]=true}, requiredMinimum, aborting, activeTrialId, trialIndex, trialCount, roundIndex, roundCount, legIndex, legCount, stageEndsAt, trialId, chosenTile, preShown, preSent` |
| RoomService API | `start, autoSeat, roomOf, getRoom, canonical, waitingRooms, isParticipant(room,uid), audience(room), cancelled(sessionId), abort(room,reason), finishRun, cleanupToWaiting, setStage(sessionId,stage), setWaitingStage(token,stage), setProgress(sessionId,patch), CLEAR, RunRequested` |
| Contexts API | `newCleanupScope():add/run/isDone, newSession(roomId, participants, seed):newTrial(id,i,n):newRound(i,n):newLeg(i)/cancel()/isActive()/envelopeExpectation(lastSeq), guardedRun(scope, fn)` |
| Pacing | `roundsFor(id, n), legsFor(n), RoundSeconds[id], Timing{Reveal,Title,RoundCard,RoundSettle,CountdownFrom,FadeMax,InterimScore,FinalScore,ControlCard}, TrialPointPool=1700` |
| Playlist | `Ids, order(seed), isKnown(id)` |
| Scoring | `Pool, borda(n), rankRound(entries, cmp) → {entry,place,from,to}, distribute(ranking) → .points` |
| Envelope (unused today) | `VERSION=1, Limits, build(ctx, seq, action, data), validate(payload, expected) → ok, reason` |
| Player attrs | `KenopsiaActiveTrial, KenopsiaSessionScore, KenopsiaSessionWins, KenopsiaJoinedAt` |
| Char attrs | `XBotMoves, XBotCrawl, XBotScanning, XBotAction` |
| Workspace | `SpawnLocation` (home), `"Dead Zone"`, `"Bird Hunting"`, `CanteenProtocol.Rig`, new: `KenopsiaArenas.<id>` |
| Storage | `ServerStorage.KenopsiaAssets.Props.<Trial>`, `SoundService.KenopsiaAudio.SFX.<Pool>` / `Music.Trials` |
| Studio attr | `workspace:GetAttribute("KenopsiaNoAuto")` disables the auto-seat/pre-flow watchdog |
| Tooling | `lua tests/*.lua` (Lua 5.1 at `C:\Lua\bin`), `luau-lsp analyze --definitions=globalTypes.d.luau --base-luaurc=.luaurc --sourcemap=sourcemap.json <files>`, `selene <files>` (`selene.toml`: std roblox, style lints off) |

---

## 9. Caveats the plan must decide (found while reading, not fixed here)

1. **Session length.** `playableOrder` plays EVERY enabled trial once per session
   (`MachineFlow.luau:262-279`). With 15 ready trials a session is 15 minigames
   (~15 × (11.5 s + rounds × (RoundSeconds + 4.5 s) + 4.5 s) ≈ 25-30 min). Either
   cap the session (e.g. `GameConfig.Playlist.PerSession = 5`, take the first N
   of `Playlist.order(seed)` that are enabled) or accept it. `tests/rules.lua`
   assumptions (`#order == 3`, six permutations) change either way.
2. **`Pacing.roundsFor` returns nil → 1 round silently** (`:409`). Add the row or
   make the fallback loud.
3. **The Contexts round token is unused by trials** — every trial mints its own.
   Threading `roundCtx` into `runRound` (planned Gates 2/3/4, still open per
   GATE1 "Not done") would let the Framework kit validate one token format;
   until then the format is per-trial and the client just echoes it.
4. **`Envelope` is unwired.** If the Framework kit adopts it, both the kit's send
   and every new server module's validation must move together, and legacy
   trials must keep accepting the bare packet.
5. **The `role` packet is the only channel that delivers `roundToken` to the
   client** (`KenopsiaClient.client.luau:1891`), and `role="none"` clears it. A
   trial that never sends a role packet has no working input.
6. **Icons** must exist under the client GUI `selection.IconPool`; the decoy pool
   `DECOY_ICONS` (`MachineFlow.luau:94`) is `Magnifier, Saw, Factory, Train, Bug`.
