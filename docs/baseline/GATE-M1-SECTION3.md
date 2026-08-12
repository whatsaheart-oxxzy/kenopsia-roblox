# Gate M1 §3 — UI structure and street-retro design

Target: `Kenopsia_DEV` `129909297895850`. `KenopsiaMainGame` untouched.

Controller split from the spec, and where each part stands:

| Controller | Responsibility | State |
|---|---|---|
| `MenuSceneController` | character, camera, local lighting, handover | **done (§2 D/E/F)** |
| `MenuOverlayController` | landing, Settings, Credits, navigation stack | **done (§3A)** |
| `SessionWallController` | wall pages, room remotes, roster, errors | §3B |
| `MenuController` | thin coordinator + `show()` adapter for `TrialController` | §3C |

---

## §3A — street palette and the landing layer (COMPLETE, transferred)

### Theme

A `Street` palette was added **alongside** the existing phosphor one, not over
it. The old CRT screens still render until §3C, and overwriting `Theme.Color`
in place would restyle them mid-flight.

| Token | Value | Use |
|---|---|---|
| `Ink` | `#171A18` | deepest ground |
| `Asphalt` | `#292C2A` | raised surface |
| `OffWhite` | `#D8D0BE` | primary text |
| `Sage` | `#6F8870` | secondary text, rules |
| `Amber` | `#D2A94A` | focus / active |
| `Denim` | `#60727A` | cool accent, disabled |
| `Error` | `#B56A45` | burnt orange — **never red** |

Rounding 0–2 px, strokes 1–2 px, offset shadows 3–4 px, no glass or blur, no
neon. Touch floor 48 px, primary actions 56–64 px. `DenkOne` for display type
(verified present in `globalTypes.d.luau`), `Code` for status lines and room
codes.

### `MenuOverlayController`

Built **entirely in code** rather than authored in StarterGui, so the whole
surface is source-controlled and diffable.

Landing shows only: `KENOPSIA`, `START`, `SETTINGS`, `CREDITS`, and
`STYLIZED VIOLENCE · FLASHING IMAGES`. No CRT monitor frame, no session buttons,
no reference to the source game.

**Navigation is an explicit stack.** BACK, Escape and gamepad B return to the
state actually pushed before this one, never to a hardcoded `Landing`. Hiding a
panel also clears `Selectable`, `Active` and `Interactable` on its buttons —
an invisible-but-selectable button still takes gamepad focus, which is precisely
how a hidden screen stays reachable for controller users.

**Settings reuses existing behaviour** rather than reimplementing it: appliers
delegate to `menu:applyTextScale`, `menu:applyIntensity` and `menu:applyCursor`,
and the panel shares the **same settings table** as `MenuController`, so the new
panel and the legacy CRT screen cannot disagree while both exist.

Rows: Text Size 80–130 %, Retro Filter 0–100 % (default 25 %), Subtle Scanlines,
Reduce Effects, Animations, Retro Cursor, UI Sound, Music. Session-scoped, no
DataStore. `Screen Static` and `CRT Intensity` in their horror form are not
carried over.

**Credits** keeps the group, developer and roles, and deliberately **omits**
*"Environment materials: CC0 retro texture packs."* That claim was false — the
CC0 notice only ever covered `LowPolyAssetPack_Free.zip`, never the packs this
game ships. Asset credits return only from the confirmed ledger.

### Three defects caught before transfer, not after

1. **`GuiService.SafeZoneOffsets` does not exist.** The safe-area listener would
   have thrown at runtime. It now keys off `Camera.ViewportSize`, which is what
   actually moves `GetGuiInset()`.
2. **The legacy settings table has no `RetroFilter` or `ReduceEffects` key.** The
   sliders would have formatted `nil` and the toggles would have read OFF
   regardless of real state. Both are seeded, `ReduceEffects` from the existing
   `ReduceFlicker` value.
3. **Retro Filter is stored 0–1 but specified as a percentage.** Display scaling
   is now explicit rather than printing "0%" for `0.25`.

A fourth was caught by the count, not by inspection: selene went 46 → 47 while a
filename filter claimed no new findings. **The filter was wrong, not the count** —
`Main.client` captured an overlay handle it never used. Removed; back to 46.

### Verification

| Check | Result |
|---|---|
| Source parity | **18/18 MATCH** |
| Luau validation | **18/18 valid**, 0 diagnostics |
| Selene | 0 errors, **46 warnings** — baseline |
| Registration | 18/18 both directions, 0 missing on disk |
| Placeholder Parts | **6 present, untouched** |

### Deliberate temporary state

The landing layer is live **on top of** the old CRT menu, which still renders.
That is intentional: §3C removes the horror boot, the monitor frame and the
permanent `RenderStepped` loop only once §3B's session wall has taken over the
room flow. Removing them first would leave the menu with no route into a room.

---

## §3B — session wall (COMPLETE, transferred)

`SessionWallController` is a `SurfaceGui` in `PlayerGui` adorned to
`MenuStage.SessionDisplay`. A `SurfaceGui` parented to the part itself cannot
receive input reliably, which is why the container lives in `PlayerGui` and only
the `Adornee` points at the world. 72 `PixelsPerStud`, `AlwaysOnTop = false`,
`Active = true`, relative Scale layouts throughout.

Baseline defects this closes: `TerminalScreen` sat in `StarterGui` with an
**empty `Adornee`** at `PixelsPerStud 256`, so it rendered nowhere.

**Create, Join and Room are pages of the same terminal**, not separate screens.
`LEAVE` returns to session select; only the separate `BACK` on Select pulls the
camera home and hides the wall.

**No new remote, no server contract change.** `RoomCreateRequest({public})`,
`RoomJoinRequest(code)`, `RoomQuickJoinRequest()`, `RoomLeaveRequest`,
`RoomReadyRequest`, `RoomStartRequest`, `RoomState` and `LobbyError` are used
exactly as they already exist.

### Gating

Before `START` the whole layer is `Enabled`/`Visible` false **and** `Active`,
`Selectable`, `Interactable` false. Invisibility alone is insufficient — an
invisible-but-selectable button still takes gamepad focus.

### Reveal timing

`MenuSceneController.goTo` now accepts `opts.onArrive` and fires it when the
camera has **actually** finished, on every path. Callers must not guess the
duration with their own `task.delay`: the reduced-motion route takes
`2 × CUT_FADE` (0.30 s), not `MOVE_TIME` (0.85 s), so a guessed delay would
reveal the wall mid-move for precisely the users who asked for less motion. A
**cancelled** tween deliberately does not fire `onArrive` — a superseding move
means we never arrived.

### Join code

Normalised as the player types: upper-cased, non-alphanumerics stripped, clamped
to 6. The server upper-cases anyway; showing the corrected value avoids a code
that looks wrong but is accepted.

### Open conflict — `PUBLIC SESSION` empty state

The spec requires that no match shows `NO OPEN ROOM IN THIS SERVER`. But
`RoomService.quickJoin` **creates** a public room when it finds none
(`RoomService.luau`, `quickJoin` → `createRoom(player, true)`), so a genuine miss
can never reach the client.

The message and a timeout fallback are wired, but the honest position is that it
**cannot fire until the server changes**. Not resolved unilaterally: the spec
also says to keep `RoomService`'s existing authority, and changing quick-join
semantics is a server behaviour change that belongs to the reviewer.

Options, for the record: (a) `quickJoin` stops auto-creating and the client shows
the empty state; (b) auto-create stays and the helper line is reworded to
describe what actually happens; (c) leave as-is and accept the message is dead
code until cross-server matchmaking lands.

### Verification

| Check | Result |
|---|---|
| Source parity | **19/19 MATCH** |
| Luau validation | **19/19 valid**, 0 diagnostics |
| Selene | 0 errors, 46 warnings — baseline |
| Registration | 19/19 both directions |
| Placeholder Parts | **6 present, untouched** |

### Placeholder deletion — unblocked but deliberately held

The reviewer's condition ("delete only once the landing and session
replacements are fully present") is now met on paper: both exist, both are
byte-exact in Studio, both are Luau-valid.

**Held anyway, pending one Play test.** Nothing has been seen to render yet. If
the wall fails to draw — a wrong `Adornee`, a face pointing away, a scale
mistake — the placeholders are the only remaining visual reference for where
those six controls belong. The composition reference in
`dev-menu-button-cframes.csv` makes deletion recoverable, but not free.

Recommended order: Play → confirm landing draws, START moves the camera, the
three session actions appear on the wall → then delete.

---

## §3B corrections after the live test (COMPLETE)

Reviewer HOLD after Play. Landing, rig, camera move and the `PlayerGui`
SurfaceGui all confirmed working; no runtime errors. Five items raised, all
closed.

### 1. Six placeholder Parts deleted

They rendered **in front of** the new menu and physically blocked the click on
`HOST SESSION`. Deletion approved once the replacements were proven to render.

`Workspace` went 17 → 11 direct children. Diffed against
`dev-instance-tree-after-s2f.csv`: **exactly the six removed, nothing added,
nothing else lost.** `MenuStage` (11 descendants) and `MainMenuWAll`
(`Wall_01..04`) both intact.

> **Tooling note.** All six delete calls returned `Instance not found`, yet the
> instances were gone and the child count dropped by exactly six. The return
> value and the effect disagreed. The outcome was confirmed by diffing the
> manifest rather than by trusting the response — worth remembering, because a
> delete that reports failure while succeeding would otherwise invite a retry
> that destroys something else.

### 2. `SessionDisplay` resized to fit the frame

`8 × 7 × 0.2` → **`8 × 5.4 × 0.2`**. At FOV 38 and 8.65 studs the old height
overflowed the view, clipping the `SESSION` heading and the `BACK` button.
Centre unchanged at `(138.9, 5.5, 25.15)`; **camera and FOV untouched**, as
directed.

The wall's layout is entirely `Scale`-based, so it reflowed to the new aspect
with no code change — which is exactly why relative layouts were specified.

### 3. `PUBLIC SESSION` — option (a), server changed

`RoomService.quickJoin` no longer creates a room on a miss. The `else` branch
now sends `fail(player, "NO OPEN ROOM IN THIS SERVER")`.

Creating a room on a miss made *"join something that exists"* and *"create
something new"* the same action, which is why the client could never report an
empty result honestly. `HOST SESSION → PUBLIC ROOM` is now the only create path,
and the two actions have genuinely distinct jobs. The client message stops being
dead code.

### 4. Camera failure fallback

`goTo` now returns whether the move actually **started**, and also fails when the
marker is missing — not only when the camera is. `goToSession` / `goToLanding`
forward that result, and `startSession` branches on it.

Landing is hidden before the move begins and `onArrive` would never fire on a
failure, so without this the player was left on a bare street with no menu and
no way back. On failure the landing panel is restored and a neutral message is
shown — internal-fault wording, not blame.

### 5. Reduced motion — comment corrected, behaviour kept

The reviewer is right on both counts: the behaviour is correct and the comment
was wrong. `hardCut` awaits the fade-**in**, applies the pose, then starts the
fade-out **without** awaiting it — so `onArrive` lands at ~`CUT_FADE`, not
`2 × CUT_FADE`. That ordering is better than the one the comment described: the
wall appears behind black and is already in place as the cover clears, instead
of popping in afterwards. Only the description changed.

### Verification

| Check | Result |
|---|---|
| Source parity | **19/19 MATCH** |
| Luau validation | **19/19 valid**, 0 diagnostics |
| Selene | 0 errors, 46 warnings — baseline |
| Placeholder Parts | **0 remaining** |
| Workspace diff | exactly 6 removed, 0 added |
| `MenuStage` / `MainMenuWAll` | intact |
| `SessionDisplay` | `8 × 5.4 × 0.2`, centre unchanged |

Manifest: `docs/baseline/dev-instance-tree-after-s3b.csv`.

---

## §3C — coordinator and removals (next)

The shake question, answered from the code: **it does not survive.** `self.shake`
is applied in exactly one place — `MenuController.luau:935-937`, inside
`startAmbient`'s permanent `RenderStepped` loop, which §4 deletes. Every consumer
is itself on the §4 removal list: `RedWash` (:995), the RGB title ghosts (:1014),
the tape dropouts (:1032). It has no independent existence.

The one call worth rescuing is `kick(1)` at `:707` inside `reject()` — that is
**error feedback**, not horror dressing. `SessionWallController:setNote(…, isError)`
plus `SoundBank.denied()` and `MenuOverlayController:setNotice(…, isError)`
already replace it, so nothing is silently lost. The other two calls
(`playPowerOn`, `playBoot`) are the horror boot itself.

§3C also removes the duplicate `RoomState` / `LobbyError` listeners: both
`MenuController` and `SessionWallController` currently subscribe, which is
harmless while the old CRT screens still exist but must not survive the split.

`TerminalScreen` becomes its own `SurfaceGui` under `PlayerGui` with
`Adornee = MenuStage.SessionDisplay`, `AlwaysOnTop = false`, `Active = true`,
~72 `PixelsPerStud`. Baseline state to fix: it currently sits in `StarterGui`
with an **empty `Adornee`** and `PixelsPerStud 256`, so it renders nowhere.

Before `START` the whole session layer is `Enabled`/`Visible` false, `Active`
false, `Selectable` false, `Interactable` false. Only after the camera move do
`HOST SESSION`, `JOIN SESSION`, `PUBLIC SESSION` appear.

Room remotes are unchanged. `PUBLIC SESSION` is same-server quick join for this
gate, with the helper line `OPEN ROOMS IN THIS SERVER` and the neutral empty
state `NO OPEN ROOM IN THIS SERVER`. `LEAVE` returns to session select, not to
landing; a separate `BACK` returns the camera to landing and hides the wall.

Only after the wall exists may the six placeholder Parts be removed.
