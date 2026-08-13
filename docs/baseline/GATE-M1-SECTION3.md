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

## §3C — coordinator and removals (COMPLETE, transferred)

`MenuController`: **1,087 → 240 lines**, 847 removed.

It now owns exactly two things: the CRT monitor surface the **trial** screens
live on plus the `show()` contract `TrialController` calls, and the settings
appliers the overlay delegates to. Landing belongs to `MenuOverlayController`,
the session flow to `SessionWallController`, camera and character to
`MenuSceneController`.

### Removed from source, not merely made unreachable

Horror boot and "5 OF 4 FOUND" · the forced six-second content-warning sequence ·
`RedWash` · `BloodDrips` · `BleedTop` / `BleedBottom` · VHS chrome (`REC`, `SP`,
tracking, corrupted dates) · RGB title ghosts · tape dropouts · random camera
kicks and the shake they drove · 12 Hz static swapping · **the permanent
`RenderStepped` loop** that ran all of it every frame whether or not anything was
visible.

Verified absent across the whole client: `shake`, `kick`, `startAmbient`,
`playPowerOn`, `playBoot`, `showWarning`, `RedWash`, `BloodDrips`, `BleedTop`,
`BleedBottom`, `TapeDamage`, `VhsChrome`, `StaticPreload`, `enterMainMenu`.
**No `RenderStepped` connection remains anywhere in the client** — the only
textual hit is the comment recording its removal.

### Instances deleted, each confirmed by re-query

`Overlay.RedWash`, `Overlay.BloodDrips`, `Overlay.BleedTop`,
`Overlay.BleedBottom`, `Overlay.TapeDamage`, `Content.VhsChrome`,
`Screens.Boot`, `Screens.ContentWarning`, and
`Background.StaticPreload` (the 8-image pool the 12 Hz swapper fed from — the
code was gone but the instances remained, caught by a place-wide sweep rather
than assumed).

Kept deliberately: `VigTop/Bottom/Left/Right` and `PhosphorWash`, which are CRT
framing for the trial screens and are still driven by `applyIntensity`.

Place manifest: **998 baseline → 1,028 peak → 931**.

### The shake — answered

Removed, not kept. It was applied in exactly one place, inside the deleted
`RenderStepped` loop, and every consumer it modulated (`RedWash`, RGB ghosts,
tape dropouts) is itself on the removal list. Its one legitimate use — feedback
on a rejected action — is served by `MenuOverlayController:setNotice` and
`SessionWallController:setNote`.

### Duplicate listeners resolved

`MenuController` no longer subscribes to `LobbyError` at all, and its `RoomState`
handler is trial-path only: `Starting` → countdown, `Playing` → trial screen,
`Waiting` → drop the monitor. Roster, room code, visibility and ready state
belong to `SessionWallController`. **One listener per concern** instead of two
racing to render the same payload.

### The CRT frame is gone from the menu without deleting the trial surface

The monitor starts hidden and is raised only by `show()`. The landing view is the
3D street and nothing else, while the trial screens keep the surface they need.
No boot sequence, no content-warning gate, no power-on animation — the player is
in the street menu immediately.

### Verification

| Check | Result |
|---|---|
| Source parity | **19/19 MATCH** |
| Luau validation | **19/19 valid**, 0 diagnostics |
| Selene | 0 errors, **45 warnings** (was 46) |
| Selene in Kenopsia-authored files | **zero** — all 45 are in Roblox's stock `Animate` |
| Horror instances place-wide | **all absent** |
| `TrialController` contract | `show()`, `focusFirst`, `.screens` all present |

### Left in place, proposed not taken

The `MainMenu`, `Settings`, `Credits`, `Create` and `Join` Frames are now dead —
nothing shows them. They are **not** on the §4 removal list, so deleting them is
a separate cleanup for the reviewer to authorise rather than something to take
unilaterally.

---

## §3D — cursor (COMPLETE, transferred)

### The regression this closes

§3C deleted `startAmbient`'s permanent `RenderStepped` loop. That was right — it
was the horror layer. But two lines inside it were **not** horror:

```lua
if self.cursor and self.cursor.Visible then
    local m = UserInputService:GetMouseLocation()
    self.cursor.Position = UDim2.fromOffset(m.X, m.Y)
end
```

Nothing replaced them, so what shipped after §3C was:

| | State before this gate |
|---|---|
| `applyCursor()` | set `MouseIconEnabled = false` — **system pointer off** |
| `KenopsiaCursor.Cursor` | parked at `(-100, -100)`, never moved again |
| `KenopsiaCursor` (ScreenGui) | **`Enabled = false`** — so even the parked label never drew |

**The menu had no visible pointer at all.** Clicks still landed, which is exactly
why the agent-driven 3B/3C live test passed it: a missing cursor is close to
invisible in a screenshot, and every interaction still *works*, just blind.

Two further defects in the same instance: `ImageColor3` was `#E03429` — **red**,
which the §3 palette forbids outright — and the live image id
(`123552452649630`) never matched `Theme.Asset.Cursor` (`135426270156789`).

### What replaces it

`UI/Cursor.luau`, a new module. Spec conformance, point by point:

| Spec requirement | Implementation |
|---|---|
| 24×24 px | 12-unit grid × `PX = 2` |
| built **from Frames** | 24 `Frame`s, one run per arrow row |
| off-white fill, graphite contour | `Street.OffWhite` over `Street.Ink`, contour = each run grown 1 unit and drawn beneath |
| **no image asset** | none — `Theme.Asset.Cursor` is no longer read |
| **no glow** | the `Glow` child is gone with the old instance |
| **no red** | palette tokens only |
| only under mouse control | hidden on `Touch` and `Gamepad*` |
| updated via **`MouseMovement`**, not `RenderStepped` | `InputChanged` filtered to `MouseMovement` |
| cursor restored on menu exit (§2) | `Cursor:destroy()` re-enables `MouseIconEnabled`; called from `MenuController:destroy()` |

Three decisions worth recording:

1. **Keyboard does not hide the cursor.** Only `Touch` and `Gamepad*` do. Typing
   a room code is still mouse-and-keyboard mode, and blinking the pointer out
   mid-entry would be a defect.
2. **`gameProcessedEvent` is ignored** in the move handler. The pointer has to
   keep tracking while it is over a button — which is precisely when the event
   arrives already processed.
3. **`MouseIconEnabled` is written from one place only** (`_refresh`), as the
   inverse of our own visibility. That is what makes "exactly one pointer, never
   two and never none" structural instead of a thing to remember.

The contour is built from grown sibling runs rather than a `UIStroke`, because a
stroke follows each frame's own rectangle, not the silhouette of the group.

Construction is wrapped in `pcall`. On failure `MouseIconEnabled` is never
touched, so the player keeps the **system** pointer — the exact inverse of the
failure being fixed.

`GetMouseLocation()` is measured below the top bar while the ScreenGui sets
`IgnoreGuiInset = true`, so `GuiService:GetGuiInset()` is added back, read live
rather than cached. Note the old code did **not** do this — it would have drawn
the arrow a top-bar's height above the real pointer had it ever run.

### Instances removed

- `StarterGui.KenopsiaCursor` — the replaced ImageLabel cursor. `StarterGui`
  2 → 1 children, verified by re-query.
- Dead screens: `MainMenu` (with its `TitleGhostR`/`TitleGhostB`), `Settings`,
  `Credits`, `Create`, `Join`, `Room`. `Screens` 11 → 5; place descendants
  **6565 → 6150**.

Before deleting, every `MenuController:show()` and `TrialController:showBoard()`
call site was enumerated: the complete set of names ever shown is `Trial`,
`Countdown`, `TrialIntro`, `TrialResult`, `FinalResult`. All five confirmed
present after deletion.

> **Scope note.** These six Frames are **not** on the spec's §4 removal list, and
> §3C deliberately left them for the reviewer. They were removed here on explicit
> user authorisation, recorded as a deliberate addition to §4 rather than as part
> of it.

### Verification

| Check | Result |
|---|---|
| Source parity | **2/2 MATCH** — `len`/`h1`/`h2` identical both sides, `cr=0` |
| Luau analyze (`luau-lsp` 1.69.0) | **0 diagnostics**, exit 0, both files |
| Selene | 0 errors, **45 warnings** — baseline, all in stock `Animate` |
| Selene in Kenopsia-authored files | **zero** |
| Trial screens after deletion | **5/5 present** |
| `StarterGui` children | 2 → 1 (`KenopsiaGui`) |

### Two process defects found, not worked around

1. **The WEPPY preflight could not run.** `Test-KenopsiaPreflight` fails with
   *"WEPPY server not reachable on any candidate port."* The documented gate was
   replaced with an equivalent manual check — `PlaceId 129909297895850`,
   `GameId 10640788131`, Edit mode, exactly one Studio client, clean tree — and
   SHA-256 was replaced with a dual rolling digest plus byte length and a CR
   count, computed on both sides. **The `tools/weppy.ps1` path is stale and
   should either be revived or dropped from the standing rules.**
2. **StyLua has never passed on this repo.** `StyLua --check` reports diffs in
   *every* client file, including ones untouched since earlier gates, and no
   single config key (`collapse_simple_statement`) accounts for it — the codebase
   is written in a compact one-liner style the pinned config does not produce.
   Reformatting would be a large diff unrelated to this gate, so it was not done.
   **The standing rule "selene and StyLua check — clean" is currently false for
   StyLua and should be corrected or enforced deliberately.**

### Still open

- `KenopsiaGui.TerminalScreen` — still in `StarterGui`, still an empty `Adornee`
  at `PixelsPerStud 256`, so it renders nowhere. `SessionWallController` built
  its own `SurfaceGui` under `PlayerGui` in §3B, which makes this instance dead
  rather than pending. **0 code references.** Deletion candidate.
- `ScreenArea.PowerOn`, `Content.Banner`, `Backdrop`, and the six `Templates`
  (`MenuButton`, `Card`, `ToggleRow`, `SliderRow`, `PlayerRow`, `PlayerSlot`)
  plus `Components.SelectionHighlight`: **0 code references** each. Not deleted —
  outside what was authorised.
- §5 acceptance (12 playtests) has not been run. The cursor needs a live check in
  particular: no automated signal distinguishes a correct pointer from a missing
  one, which is the whole reason this regression survived a gate.
