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

## §3B — session wall (next)

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
