# QA — P2.4 console focus + device glyphs (23.08.2026)

GitHub issue #18, package B (console + glyph part; the per-trial touch buttons were NOT touched).
Built OFFLINE on master; nothing was pushed to the place. The lead pushes `Glyphs` (new ModuleScript
under StarterPlayerScripts) FIRST, then MachineLayout, KenopsiaClient, FeelConfig, and runs the live
checks below. Without the module MachineLayout stops with
`[MachineLayout] Glyphs module missing (push StarterPlayerScripts/Glyphs first)` after 10 s and
KenopsiaClient warns once and keeps the authored hint text.

## What was built

| Piece | File | What changed |
|---|---|---|
| Glyphs | `studio-src/StarterPlayer/StarterPlayerScripts/Glyphs.luau` (new, mapped in `default.project.json`) | Pure Lua 5.1 module. `Actions` = action -> `{ Desktop, Console, Touch }` binding (`key` / `keys` KeyCode names, or fixed `text`); `segments(line, platform, resolver)` expands `{Action}` tokens in a controls line into text / image segments; `text()` / `join()` flatten to a string; `KeyText` (CTRL, ENTER, LEFT ...) for keys `GetStringForKeyCode` does not print as one character, `ButtonText` (A, B, LT, RT, LS, RS, DPAD LEFT ...) as image fallback / alt text; `LookHint` per platform; `robloxResolver(UserInputService)` builds the live resolver (`GetImageForKeyCode` / `GetStringForKeyCode`, `Enum` touched at call time only); `classify(inputTypeName)`, `newInputTracker(holdSeconds)` (the hysteresis), `isConsole(signals)` (the composed console signal). |
| FeelConfig | `Shared/Config/FeelConfig.luau` | `Feel.Input = { GamepadHoldSeconds = 2 }` (not a motion; outside MaxMotion). |
| Platform detection | `MachineLayout.client.luau` `detectPlatform` | Console = `Glyphs.isConsole{ tenFoot = GuiService:IsTenFootInterface(), gamepad, keyboard, mouse, touch, mode = tracker.mode }`: ten-foot OR gamepad without keyboard / mouse / touch OR the tracker has settled on the gamepad. `IsTenFootInterface` appears in exactly one line, inside that call (tests/glyphs.lua greps it). |
| Live input mode | `MachineLayout.client.luau` `LastInputTypeChanged` | Feeds the tracker with `inputType.Name`. A click / key / touch switches the mode at once; a gamepad only once it has been the last input type for > 2 s (a `task.delay` re-evaluates when the hold can have elapsed); `MouseMovement` is ignored in both directions. `refreshPlatform()` is the single re-detect path (also used by `ForcePlatform`); leaving Console clears `GuiService.SelectedObject`, entering it re-focuses through `apply()` -> `focusAny()`. The `Platform` attribute updates live. |
| Selection groups | `MachineLayout.client.luau` `wireGroup` (+ `lookPanel` in KenopsiaClient) | `GROUPS = { Warning, SettingsPanel, HunterLookSetup, Briefing, Info }` (focus priority). Each gets `SelectionGroup = true` and `SelectionBehaviorUp/Down/Left/Right = Enum.SelectionBehavior.Stop` — the **GuiBase2d property pattern**, which is the current API (`GuiService:AddSelectionParent` / `RemoveSelectionGroup` are marked deprecated in favour of it in `globalTypes.d.luau`; there is no `SelectionGroup` Instance class). `HunterLookSetup` is created by KenopsiaClient at boot: it sets the same five properties itself and MachineLayout adopts it through `machine.ChildAdded`. Shown -> `focusScreen`; hidden -> selection inside it dropped, then `focusAny()` (closing Settings lands back on Info's READY). |
| Focus | `MachineLayout.client.luau` `focusScreen` | 1) named primary via a dotted path (`Info = Btn_READY`, `Warning = Btn_CONTINUE`, `SettingsPanel = Row_UISOUND.Hit`, `HunterLookSetup = Track`, `Briefing = NavBar.ArrowR.Hit`); 2) `GuiService:Select(panel)` (engine pick inside the group); 3) the largest visible button. Phosphor ring (`PlayerGui.SelectionImageObject`) untouched. |
| Glyphs in the controls rows | `MachineLayout.client.luau` `TRIAL_TEXT` + `renderGlyphRow` | Rows carry `{Move} {Crouch} {Aim} {Fire} {Scope} {Zoom} {Scan} {Load} {Swallow}` tokens (31 tokens over 9 actions, every one in `Glyphs.Actions`). Desktop -> key strings from `GetStringForKeyCode` (AZERTY shows `Z Q S D`), `CTRL`, `LMB` / `RMB` / `WHEEL`; Touch -> the pad labels (`STICK`, `CROUCH`, `FIRE`, `SCOPE`, `SCAN`, `PLATE`, `MOUTH`); Console -> a `GlyphRow` child of the row label: horizontal `UIListLayout` of `TextLabel` segments and `ImageLabel` button images (`GetImageForKeyCode`, `TextSize + 6` px square, padding 4), the plain label blanked while it shows. Trial modules' `controlsText` lines may use the same tokens (none does yet). |
| Pad hints | `MachineLayout.client.luau` `applyButtonHints` | `PadHint` on `Info.Btn_READY`, `Warning.Btn_CONTINUE` and now `SettingsPanel.Btn_CLOSE`, image = `Glyphs.glyph("Confirm", "Console")` (A); hidden off-console or when the image is empty. The hard-wired `GetImageForKeyCode(Enum.KeyCode.ButtonA)` is gone. |
| Look-speed panel | `KenopsiaClient.client.luau` | `lookPanel` is a SelectionGroup (Stop x4); hint label named `Hint`, text per platform from `Glyphs.LookHint`: Desktop `CLICK BAR     LEFT / RIGHT`, Console `DPAD LEFT / DPAD RIGHT` (text, see open points), Touch `TAP BAR`. Helper rides `K.Glyphs` / `K.GlyphResolver` — **no new top-level local** (178 before, 178 after). |
| Settings back-out | `KenopsiaClient.client.luau` settings block | Gamepad **B** closes the SettingsPanel (focus is trapped inside its group; CLOSE is the other way out). |
| Test | `tests/glyphs.lua` (new) | 68 checks: action map for Desktop / Console / Touch, resolver use (AZERTY, image + alt, empty image -> ButtonText), Machine voice on every visible text, the hysteresis as pure logic, `isConsole`, and greps on the shipped scripts (ten-foot only inside the composed call, Stop edges, `GuiService:Select`, tokens known, client locals <= 180, project mapping). |

## Gates (verbatim)

```
lua tests/feel.lua          -> 130 checks, 0 failures  (exit 0)
lua tests/rules.lua         -> 88 checks, 0 failed  GATE 1 RULES PROOF: PASS  (exit 0)
lua tests/envelope.lua      -> 33 checks, 0 failed  GATE 1 ENVELOPE PROOF: PASS  (exit 0)
lua tests/contexts.lua      -> 21 checks, 0 failed  GATE 1 CONTEXTS PROOF: PASS  (exit 0)
lua tests/voice.lua         -> 26 checks, 0 failed  MACHINE VOICE PROOF: PASS  (exit 0)
lua tests/machinecam.lua    -> 37 checks, 0 failed  MACHINECAM PROOF: PASS  (exit 0)
lua tests/animationids.lua  -> 29 checks, 0 failed  MP-05 ANIMATIONIDS PROOF: PASS  (exit 0)
lua tests/trialrules.lua    -> 37 checks, 0 failed  MP-05 TRIALRULES PROOF: PASS  (exit 0)
lua tests/sorting.lua       -> 34 checks, 0 failures  (exit 0)
lua tests/glyphs.lua        -> 68 checks, 0 failures  GLYPHS PROOF: PASS  (exit 0)

selene MachineLayout.client.luau KenopsiaClient.client.luau Glyphs.luau FeelConfig.luau
                            -> 3 errors, 0 warnings, 0 parse errors
                               (the 3 pre-existing if_same_then_else in KenopsiaClient 885 / 888 / 1168;
                               identical on the baseline). Glyphs.luau, MachineLayout, FeelConfig: clean.

luau-lsp analyze --definitions=globalTypes.d.luau --base-luaurc=.luaurc --sourcemap=sourcemap.json
  MachineLayout.client.luau KenopsiaClient.client.luau Glyphs.luau FeelConfig.luau
                            -> 0 findings before, 0 findings after (sourcemap.json regenerated with
                               `rojo sourcemap default.project.json -o sourcemap.json`; it is gitignored).

grep -c "^local " KenopsiaClient.client.luau -> 178 (before 178; limit 180)
grep -rn IsTenFootInterface studio-src       -> MachineLayout.client.luau:54 (inside Glyphs.isConsole{ tenFoot = ... })
                                                Glyphs.luau:13 (a comment)
```

## Live-check list for the lead

Push order: `Glyphs` first. Then watch the Output for `[MachineLayout] <Platform>, scale x.xx` and
`[Kenopsia] client online`; no `Glyphs module missing` line.

1. **Xbox emulation (1918 x 1080), gamepad walk.** Device emulator -> Xbox; `[MachineLayout] Console`. Info screen: READY carries the A glyph and the phosphor ring sits on READY at entry. With a controller (the emulator has no gamepad input; plug one into the PC, or set `ForcePlatform = "Console"` on `KenopsiaMachine` on desktop and use a pad): d-pad / left stick walks READY <-> SETTINGS <-> the CONTROLS pager arrows, and **never leaves Info** (push every direction at every button: the ring must stay on an Info control, never land on the chat, the Roblox top bar or nothing). A -> SETTINGS: ring lands on the UI SOUND row; d-pad down walks the rows to CLOSE; left / right / up at the edges stay in the panel; A on a row toggles it; **B** or A on CLOSE closes the panel and the ring is back on READY. Then a trial that shows the Briefing frame (none does yet, P2.5) — until then confirm `Briefing.SelectionGroup = true` in the Explorer at runtime and that the frame is in the `GROUPS` list.
2. **Hunter look-speed panel (birdhunt, hunter role, console).** The ring sits on the bar (`HunterLookSetup.Track`), d-pad left / right changes the level, the hint reads `DPAD LEFT / DPAD RIGHT`, focus cannot leave the bar; when the panel hides the ring is gone.
3. **Input-mode hysteresis (desktop, real controller plugged in).** Start with the mouse: `[MachineLayout] Desktop`. Press a gamepad button once and wait: after ~2 s the `Platform` attribute on `KenopsiaMachine` flips to `Console` (scale up, A glyph, ring on READY). Move the mouse only: stays `Console`. Click: flips back to `Desktop` at once, ring gone. Press a gamepad button and within 2 s press a key: stays `Desktop`. Press a gamepad button, nudge the mouse inside the 2 s, wait: flips to `Console` (the nudge did not reset the hold).
4. **Glyphs on all three platforms, Info screen CONTROLS window, trial birdhunt / minefield / canteen** (set `TrialId` on `KenopsiaMachine`, or let the roulette pick):
   - Desktop 1080p: `Move  [W A S D]`, `Crouch [CTRL]`, `Aim + Shoot [LMB]`, `Scope [RMB]  x2 / x4 [WHEEL]`; minefield `Use sonar [HOLD F]`; canteen `Load fork [LMB]`, `Swallow [RMB]`. With the OS keyboard layout set to French the first row reads `[Z Q S D]`.
   - iPhone 19.5:9 and iPad 4:3 (Mobile / Tablet): `STICK  Move`, `CROUCH button`, `DRAG  Aim  +  FIRE button`, `SCOPE button [x2]`; minefield `Use sonar [HOLD SCAN]`; canteen `PLATE button loads`, `MOUTH button swallows`. Nothing below 10 px, rows not clipped.
   - Xbox: each row is a `GlyphRow` (Explorer: `ControlsWindow.Row1.Text.GlyphRow.Seg1..n`) with the Xbox button images (left stick, B, right stick, RT, LT, Y) in line with the text, `TextSize + 6` px square, text >= 22 px; minefield `Use sonar [HOLD <Y>]`; canteen `<LT>  Load fork`, `<RT>  Swallow`. Check the images are not stretched (ScaleType Fit) and the row does not overflow the window on the widest line (`<LT>  Scope [x2]    <Y>  Zoom`).
5. **Pad hints.** Xbox: A glyph on READY, on the content warning's CONTINUE and on Settings CLOSE; none on desktop / touch. Spectator (benched) keeps hiding READY's glyph.
6. **Regression.** Desktop and phone: no phosphor ring anywhere, `GuiService.SelectedObject` nil; settings rows toggle by click / tap; the roulette, Info overlap and the 0.81 / 0.62 scale numbers from `2026-08-22-p2-layout-1.md` unchanged.

## Open points

* **Briefing NavBar** is wired (group, primary `NavBar.ArrowR.Hit` with fallbacks) but no client code shows the Briefing frame yet — P2.5 (#19) owns that; the gamepad walk Info -> Settings -> Briefing -> back can only be completed once it is shown.
* **Info.NavCluster** is `Marker + Track + Gauge` (decorative, no buttons) per `docs/place/04-GUI.md`; the Info group still covers it, nothing to focus.
* The look-speed panel's console hint is **text** (`DPAD LEFT / DPAD RIGHT`); the image GlyphRow builder lives in MachineLayout and the panel is KenopsiaClient's. If the lead wants images there, move `renderGlyphRow` into a tiny shared client module (one more require in MachineLayout; KenopsiaClient would reach it through `K`).
* `GlyphRow` ImageLabels use the engine default `ResampleMode` (the P2 gate says Pixelated on every ImageLabel; the Xbox button art is a raster asset drawn smaller than native and Pixelated down-sampling would shimmer). One line in `renderGlyphRow` if the lead prefers the gate literally.
* Trial modules' `controlsText` (`sorting.luau` etc.) still carry literal `[Q]` / `[X]` keys; they accept the `{Action}` tokens now, but new actions (SortA / SortB / Pass) need rows in `Glyphs.Actions` — P4 per-trial work.
* `GetStringForKeyCode` on a console / touch device is never called (those platforms do not take the Desktop branch), so no cost there.
