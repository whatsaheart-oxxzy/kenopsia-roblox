# QA — P2.2 leftovers + P2.3 SHAKE row: dither, glow, idle life, UI bus + hum (23.08.2026)

GitHub issues #16 (P2.2 leftovers) and #17 (SHAKE row). Built OFFLINE on `master`; nothing was pushed
to the place. The lead pushes the four files and runs the live checks below.

## What was built

| # | Piece | File | What |
|---|---|---|---|
| 1 | Bayer dither between screens | `UiFx.client.luau` §4b/§7, `KenopsiaClient.hideAll()` | `hideAll()` bumps the attribute `DitherSeq` on the `KenopsiaMachine` gui at every swap (the swap itself stays a hard cut, bible §3). UiFx owns a tiled `ImageLabel` `Dither` on the overlay (ScaleType Tile, TileSize 8 px, ResampleMode Pixelated, ImageColor3 black, ZIndex 5) and steps it through the four Bayer tiles densest → sparsest, one tile per frame of `Feel.Step.Fps` (12 fps → 4 × 83 ms = 0.333 s), then hides it. Never an alpha tween. `ReduceFlicker` / `GuiService.ReducedMotionEnabled`: a plain black card held 2 frames (0.167 s) instead. A swap landing mid-sequence restarts it (generation counter). Tiles are `ContentProvider:PreloadAsync`-ed at boot. The `Fader` frame is untouched: its one job (the 1.4 s arena fade-in under count "3") is a fade and stays a fade. |
| 2 | Phosphor glow | `UiFx.client.luau` §8 | Built once at boot from the name list `Info.NextLabel, RoundCard.Title, Announce.Line, CountText, HitMark, Score.ScoreName, Briefing.Title`: a `UIStroke` `PhosphorStroke` (Contextual, 1 px, transparency 0.6) plus an echo `TextLabel` `Glow` one pixel down-right at transparency 0.75. The echo is a CHILD of its label (full size, offset 1 px) so it inherits Visible / Position / Size and the `KenopsiaScale` UIScale MachineLayout parents into CountText / HitMark; same colour over same colour composites to nothing, only the 1-px rim shows. It mirrors Text, TextColor3, TextSize, TextTransparency, MaxVisibleGraphemes (typewriter), alignment, FontFace, RichText, LineHeight through property-changed signals — no per-frame work. Stroke colour follows TextColor3 (red verdict / death line glow red). Both transparencies are multiplied by `GuiService.PreferredTransparency` (re-applied on change); `KenopsiaCRT=false` switches stroke and echo off. HitMark already carries a UIStroke (its dark outline) and gets the echo only — two strokes on one object are undefined. |
| 3 | Idle oscillators on Selection | `UiFx.client.luau` §9 + band/blip gating | Four decorrelated clocks, all on the overlay, all only while `liveOk()` (= `KenopsiaActiveTrial == ""` AND `KenopsiaMachine.Selection.Visible`): (a) breathing bracket — 8 corner ticks around the union rect of `Selection.Tiles.*`, padding 18 px ± 6 px, `sin` with a fresh 4–6 s period drawn every breath, whole-pixel steps at 12 fps; (b) interference blip 8–20 s (existing, now gated); (c) uptime counter `UPTIME hh:mm:ss` from `workspace.DistributedGameTime`, 1 Hz, bottom-left of Selection (+24, −36); (d) refresh band 8 s idle / 2 s sweep (existing, now gated). ReduceFlicker / ReducedMotion / CRT off: bracket holds at rest size, band and blip stop, uptime keeps ticking (text, not motion). `LIVE_SCREENS = { "Selection" }` is the one list to extend if the lead wants the life on the Info lobby too. |
| 4 | UI sound bus + CRT hum | `UiFx.client.luau` §6, `KenopsiaClient.sfx()` / `blip()` | UiFx creates `SoundService.KenopsiaUI` (SoundGroup) first thing; `sfx()` assigns it to a pool Sound on first use (`if s.SoundGroup == nil`), the typewriter blip clones get it too. Hum: `Sound` `CrtHum` under SoundService on the group, Looped, source = `SoundService.KenopsiaAudio.Ambience.Hum` (then any Sound named `Hum` below KenopsiaAudio); **no such asset exists** (audio-inventory.csv has no loop/ambience row; the `Ambience` folder is empty per ASSET-LEDGER) → placeholder id 0, SoundId "", ONE warn `[UiFx] no CRT hum asset (SoundService.KenopsiaAudio.Ambience.Hum) - placeholder id 0, hum silent`. Volume 0.12; ducks −6 dB (gain 0.501) over 0.2 s Linear while `Announce` or `RoundCard` is visible (observed through their `Visible` signals — the Machine tree is only read), returns over 0.2 s. Off (tween to 0, then Stop) while `KenopsiaActiveTrial ~= ""` and while `KenopsiaUiSound == false`. |
| 5 | SHAKE row | `KenopsiaClient.client.luau` settings + shake, `FeelConfig.Shake.ReduceFactor` | `uiSettings.ReduceShake` seeded from `GuiService.ReducedMotionEnabled` like ReduceFlicker, published as player attribute `KenopsiaReduceShake`; row `Row_SHAKE` added to the rows table (`FindFirstChild`, a missing row is harmless — every loop guards on `r.frame`). The trauma shake multiplies `mag` by `Feel.Shake.ReduceFactor` (0.35) when set — never zero. Bonus from #17: `GuiService.ReducedMotionEnabled` is followed at runtime (turning ON seeds both Reduce* rows and re-renders the panel; OFF never overrides the player). |

## FeelConfig keys added (all timings live here, none as literals)

| Key | Value |
|---|---|
| `Dither` | Steps 4, ReducedSteps 2, TilePx 8, Tiles = 128764657994112 / 121598984043867 / 93726535183476 / 72454964162888 |
| `Glow` | StrokeTransparency 0.6, StrokeThickness 1, EchoTransparency 0.75, EchoOffsetPx 1 |
| `Idle` | BracketPeriodMin 4, BracketPeriodMax 6, BracketBreathPx 6, BracketPadPx 18, UptimeHz 1 |
| `Hum` | SoundName "Hum", PlaceholderId 0, Volume 0.12, DuckDb −6, DuckSeconds 0.2 |
| `Shake.ReduceFactor` | 0.35 |
| helpers | `stepSeconds()` (1/12), `ditherSeconds(reduced)` (0.333 / 0.167), `dbGain(db)` |

## Gates (verbatim)

```
lua tests/feel.lua          -> 130 checks, 0 failures            (was 98; +32 on Dither / Glow / Idle / Hum / Shake reduce)
lua tests/rules.lua         -> 88 checks, 0 failed / GATE 1 RULES PROOF: PASS
                               PASS  REQ-IP-01: no forbidden token in any shipped file
lua tests/envelope.lua      -> 33 checks, 0 failed / GATE 1 ENVELOPE PROOF: PASS
lua tests/contexts.lua      -> 21 checks, 0 failed / GATE 1 CONTEXTS PROOF: PASS
lua tests/voice.lua         -> 26 checks, 0 failed / MACHINE VOICE PROOF: PASS
lua tests/machinecam.lua    -> 37 checks, 0 failed / MACHINECAM PROOF: PASS
lua tests/animationids.lua  -> 29 checks, 0 failed / MP-05 ANIMATIONIDS PROOF: PASS
lua tests/trialrules.lua    -> 37 checks, 0 failed / MP-05 TRIALRULES PROOF: PASS
lua tests/sorting.lua       -> 34 checks, 0 failures

selene KenopsiaClient UiFx FeelConfig -> 3 errors, 0 warnings, 0 parse errors
                               (the 3 pre-existing if_same_then_else in KenopsiaClient at 861 / 864 / 1144;
                               UiFx and FeelConfig alone: 0 errors, 0 warnings)
luau-lsp analyze --definitions=globalTypes.d.luau --base-luaurc=.luaurc --sourcemap=sourcemap.json
  KenopsiaClient UiFx FeelConfig -> 0 findings before, 0 findings after (sourcemap.json already lists FeelConfig)
grep -c "^local " KenopsiaClient.client.luau -> 178 before, 178 after (no net new top-level local)
```

## Live-check list for the lead (Studio, real input path)

Push with parity: `FeelConfig`, `UiFx`, `KenopsiaClient`. Then, and only then, clone `Row_CRT` → `Row_SHAKE`
at (18, 356), label text `REDUCE SHAKE` (uppercase, no exclamation mark), panel 438 → 492 px.

1. **Dither (desktop 1080p).** Lobby → roulette → `NEXT SIMULATION` → round card: at every swap the new screen
   paints in through four dither frames (≈ 0.33 s, visibly stepped, coarse 2-px pattern). Screens to watch:
   Selection → Info, Info → Status, Status → RoundCard, RoundCard → (hide) world, Announce death line. Verify
   the densest tile (level 4, id 72454964162888) reads as near-full cover on the first frame; if it is
   ~75 % the order is right but the first frame lets the new screen through — say so and I add a one-frame
   black backing. With `FLICKER: REDUCED` on: a black card for 2 frames, no pattern. Console output must
   not show an asset-load error for the four ids (PreloadAsync at boot).
2. **Dither on a phone emulation (iPhone 19.5:9).** Same swaps; MicroProfiler during a swap: the tiled
   ImageLabel is ~1 quad per 8-px tile for 4 frames (the perf note in UiFx §1 measured 40k quads for the
   old 8-px scanline tile — this one is transient). Report the frame-time spike if any.
3. **Glow (desktop, then phone).** `NEXT SIMULATION: …` types with a 1-px phosphor rim and a 1-px echo
   down-right; `Round n/m` title, the 3-2-1 count (punch 160 → 120 px keeps the echo in step, since the
   echo scales with CountText's UIScale), the death line (red rim), the verdict `SUBJECT STATUS VIABLE /
   REJECTED` (phosphor / red), Briefing title. Settings `CRT` off → no rim, no echo. HitMark: echo only (its
   own dark UIStroke kept). Accessibility: set Roblox "Preferred transparency" (Settings → Accessibility) to
   minimum → rim and echo become opaque (transparency × 0).
4. **Idle life (Selection).** Right after join (Selection visible, no packet yet) and during the 6.4 s
   roulette: corner-tick bracket around the tile row breathing ±6 px with a 4–6 s period, `UPTIME hh:mm:ss`
   bottom-left ticking once per second, blip 8–20 s, band every 10 s. All four vanish the instant Info / any
   other screen shows, and never during a trial (`KenopsiaActiveTrial ~= ""`). With Reduce Motion ON:
   bracket static, no band, no blip, uptime still ticks.
5. **UI bus.** `SoundService.KenopsiaUI` (SoundGroup) exists at boot; after one click `KenopsiaAudio.SFX.
   Clicks.ClickN.SoundGroup == KenopsiaUI`; typewriter blip clones too. Setting `KenopsiaUI.Volume = 0` in
   the explorer mutes every click / blip / hum and nothing else (music untouched).
6. **Hum.** Console shows exactly one `[UiFx] no CRT hum asset … placeholder id 0, hum silent` at boot.
   To hear it: drop any looping Sound named `Hum` into `SoundService.KenopsiaAudio.Ambience` (or anywhere
   under KenopsiaAudio) before Play; then `SoundService.CrtHum` plays at 0.12, drops to ≈ 0.06 within 0.2 s
   when an announce line / round card shows and returns 0.2 s after it hides; stops within 0.25 s of the
   trial attribute going non-empty and when `UI SOUND` is switched off.
7. **SHAKE row (desktop).** Settings panel shows the sixth row; toggling it flips the checkbox, publishes
   `KenopsiaReduceShake` on the LocalPlayer, plays the click. With it on, a gorefx near the player shakes
   at 0.35× (still visible); with Roblox Reduce Motion ON before join, both REDUCE FLICKER and SHAKE rows
   start checked; flipping Reduce Motion ON while playing checks both rows live.
8. **Console emulation (Xbox).** Gamepad focus must not land on the echo labels or the bracket ticks
   (none are Selectable); `Row_SHAKE.Hit` must be reachable with the D-pad like the other five rows.

## Open points

* No hum asset exists in the place or the inventory; the bed is silent until P6 uploads a loop
  (`SoundService.KenopsiaAudio.Ambience.Hum`). The code picks it up on the next boot, no code change.
* The dither level order assumes tile 4 is the densest; unverifiable offline (see live check 1).
* The refresh band and the blip are now gated to the Selection screen (task statement: none of the four
  oscillators while Selection is hidden). Before this they ran over every screen and the world. If the
  lead wants the band back on Info / Status, `LIVE_SCREENS` in UiFx is the one list to extend.
* `GRAIN` (issue #17) is not a row yet: no grain layer exists to switch.
* `PreferredTextSize` (issue #17) is not applied; MachineLayout's text floor is the only text-size rule.
* Phone MicroProfiler before/after (issue #16 live gate) is the user's check; the only new steady-state
  work is the 12 fps bracket/uptime loop while Selection is visible (2 property writes per step) and the
  transient dither quad burst.
