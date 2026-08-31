# QA — Full-screen blackout + the second cover (31.08.2026)

User: *"still no full blackscreen. A bit before Victory/Round Ending there will
be a black screen, going away when Round UI shows, then reappear again till the
countdown with 3,2,1."*

Two separate defects behind one sentence.

## 1. The blackout was never full-screen

`Fader` is a Frame **inside** `KenopsiaMachine`, and that ScreenGui sits at
`DisplayOrder = 50`. Anything in a higher-order ScreenGui drew straight over
the "black" screen — measured live in a running trial:

| ScreenGui | DisplayOrder | Above the Fader? |
|---|---|---|
| `KenopsiaTrialHud` (TrialClientKit) | machine + 1 = **51** | yes — clock, LEG counter, touch pads, ability panel |
| `KenopsiaMachine_Overlay` | **60** | yes |
| `KenopsiaNotice` | **900** | yes |
| Roblox topbar | above every ScreenGui | yes — only `SetCore("TopbarEnabled")` hides it |

The client's own HUD (`Overlay.showHud`) was fine — it is a sibling under
`machine` at ZIndex 5, under the Fader at 70. The trial HUD is a *different*
surface and had never been accounted for.

**Fix — a mirror, not a refactor.** A new `KenopsiaCover` ScreenGui
(`DisplayOrder 950`, `IgnoreGuiInset`, `ScreenInsets.None`) holds one black
frame that **follows the Fader's `Visible` and `BackgroundTransparency`** via
property-changed signals, and toggles the topbar with it. Every existing caller
— `Overlay.show/black/clear/liftAfter/release`, the 3-2-1 arena fade, the
spectate cut, GO — keeps working untouched, and tweens are mirrored frame by
frame, so the fade-in still fades. 950 is deliberately **below** `AbortScreen`
(1000): the abort card must stay the topmost surface.

`SetCore` is called only on an actual state change, never per tween frame.

## 2. Nothing covered the teleport

Per round the server ran: round card → (role card) → `hide` → **runRound**
(`Round:place` teleports everyone and the arena is built) → countdown 3-2-1.

`hide` is a known kind, and *every* known kind clears the held blackout — so
the screen was **open** for exactly the window in which players are teleported
and the arena is assembled. That is the "reappear again till the countdown"
the user is asking for.

**Fix:** one `{kind="cover", hold=true}` immediately after the `hide`. It is
lifted by nothing on a timer — the countdown itself takes it down: at `n == 3`
the client already runs `hideAll()` + `Overlay.black()` and tweens the arena in
under the numbers (`Feel.Fade.ArenaIn`). So the screen is black from the last
card until 3-2-1, and the reveal belongs to the countdown rather than to the
teleport.

Resulting beat, which is the user's sentence exactly:
`round ends → BLACK → standings / round card → BLACK → 3-2-1 (arena fades in) → GO`

## Verified in Play

- `KenopsiaCover` present at DisplayOrder 950; full ScreenGui census taken live.
- Instrumented a real round: cover ON at 13.6 s, OFF at 15.1 s — **1.5 s of
  black across the teleport**, lifted by the countdown, not by a timer.
- Forced the blackout up mid-leg and captured: **every pixel black**, including
  the topbar strip and the LEG/clock/ability HUD.
- Released after the hold: HUD and world back (LEG 2/3, 0:50), no stuck black,
  topbar restored.
- selene over both files: **3 errors / 1 warning — byte-identical to the same
  run on the pre-change tree** (all pre-existing). Offline battery 14/14 green.

## Notes

- The 25 s `BACKSTOP` in `Overlay` still applies: if a countdown never arrives
  the blackout clears itself, which now also restores the topbar.
- Not changed: the round-end cover already fired before the results card, so
  "a bit before Victory/Round Ending" needed no server change — it simply was
  not *full*, which is defect 1.
