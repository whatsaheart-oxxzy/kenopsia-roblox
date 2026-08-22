# Retro/PS1/CRT UI feel: what Roblox can technically do, what it cannot, and how to make the interface feel alive without burning low-end phones or triggering photosensitivity.

> Read-only research lens, measured 2026-08-22 (workflow wf_a13d7aec-54c). Facts cite their source; treat plan documents as claims, measurements as truth.

## Summary

Roblox has no custom shaders, so a "PS1 look" is never a post-process. It must be built from four separate layers with very different cost profiles.

Layer 1 (UI): ImageLabel/ImageButton.ResampleMode = Pixelated is the ONLY nearest-neighbour path in the engine. 3D Textures/Decals/SurfaceAppearance/MaterialVariant/ViewportFrame stay bilinear (feature request open since May 2022, no staff reply). Chunky pixels are reachable on flat surfaces via SurfaceGui + ImageLabel, and nowhere else.

Layer 2 (3D): true PS1 vertex snapping/affine warp is only reachable via EditableMesh, whose SetPosition() moves one vertex per call and forces a full GPU re-upload each frame. Cap 60 000 verts/mesh plus a memory budget that already errors in the wild. Highest perf risk in this lens for phones.

Layer 3 (lighting): free wins exist. ColorGradingEffect.TonemapperPreset = Retro reproduces pre-2019 Roblox lighting. Lighting fog + Atmosphere give the PS1 draw-distance cutoff at ~zero cost. Lighting.Technology is being sunset toward LightingStyle (Soft/Realistic); quality level 3 and below falls back to voxel anyway.

Layer 4 (aliveness): scanlines, flicker, typewriter, boot ledgers, relay clicks. Each is cheap alone and expensive together for one reason: Roblox caches a ScreenGui's whole render geometry and invalidates the ENTIRE cache when any descendant property changes. One 1px scanline animating inside KenopsiaMachine re-rasterises all 521 descendants every frame.

The project already commits to the aesthetic (single Enum.Font.Code, five phosphor colours, tiled grunge overlay, flicker roulette, ReduceFlicker setting, noise-based shake). Three concrete defects found: the flicker roulette runs ~7 flashes/s for 1.6 s (WCAG limit is 3/s) and is opt-out not opt-in; the typewriter uses byte-wise string.sub instead of MaxVisibleGraphemes (breaks RichText and non-ASCII, busts the render cache); and typewriter speed is frame-quantised by task.wait so text types ~40 % slower on a 30 fps phone while Pacing.Timing holds stay fixed in seconds.

Deliverable below: ~25 techniques, each with API, cost, risk and source.

## Facts

- ResampleMode (Default = bilinear, Pixelated = nearest neighbour) exists ONLY on ImageLabel, ImageButton and VideoDisplay. Roblox staff warn: nearest neighbour causes aliasing/shimmering on size reduction, so only use it for magnification.
  - *Source:* https://devforum.roblox.com/t/resamplemode-new-property-for-image-gui-objects/1418681
- Nearest-neighbour filtering for 3D Texture/Decal/SurfaceAppearance/MaterialVariant has NOT shipped. Request open since May 2022, no staff reply through Sept 2024. Community workaround: SurfaceGui + ImageLabel with ResampleMode Pixelated (does not wrap curved geometry).
  - *Source:* https://devforum.roblox.com/t/resamplemode-for-materials-and-textures/1783233
- ViewportFrame has no ResampleMode and a 1024-px-per-axis render limit; it renders at its own on-screen size, so a small ViewportFrame scaled up gives a BLURRY (bilinear) image, not chunky pixels. Open request to add ResampleMode to ViewportFrame.
  - *Source:* https://devforum.roblox.com/t/add-resamplemode-to-viewportframe/3030577 and https://devforum.roblox.com/t/viewportframe-rendering-shouldnt-have-a-resolution-limit-should-not-have-a-white-outline/305898
- Roblox caches a Gui's full render geometry (array of rects + colours + textures) and clears that cache when a descendant is added/removed OR any property of any descendant changes. Official advice: split mostly-static and mostly-dynamic UI into SEPARATE ScreenGuis so dynamic UI does not invalidate the static cache.
  - *Source:* https://devforum.roblox.com/t/static-ui-performance-improvements/222557
- CanvasGroup rasterises its subtree to an off-screen texture; every change inside forces a full re-render of that texture. On client graphics level 3- (studio 6-) CanvasGroup output is downscaled and animations are throttled.
  - *Source:* https://create.roblox.com/docs/reference/engine/classes/CanvasGroup and https://devforum.roblox.com/t/canvasgroup-performance-concerns/3556937
- EditableMesh:SetPosition() moves one vertex per call and requires a full mesh re-upload to GPU each frame; there is no bulk vertex API. Max 60 000 vertices per EditableMesh (runtime error above). Memory budget errors ('Editable mesh memory budget reached') occur in production; FixedSize clones via CreateEditableMeshAsync reduce the budget charge.
  - *Source:* https://devforum.roblox.com/t/ps1-style-vertex-warping-shader-module-using-editablemeshes/3572022 and https://devforum.roblox.com/t/editable-mesh-memory-budget-reached/3469104
- EditableImage Read/WritePixelsBuffer is capped at 1024x1024 even in plugin context; devs report frame drops writing canvases as small as 112x63 px at fixed draw rates.
  - *Source:* https://devforum.roblox.com/t/editableimage-higher-resolution-and-memory-limit/4389575 and https://devforum.roblox.com/t/allow-editableimagewritepixelsbuffer-to-go-up-to-2048x2048-for-plugins/4568767
- Custom pixel shaders / post-process shaders are impossible in Roblox; only the fixed set ColorCorrectionEffect, BlurEffect, BloomEffect, SunRaysEffect, DepthOfFieldEffect, ColorGradingEffect exists. 'Penumbra' Luau graphics library renders shaders on the CPU (no GPU access) and publishes no perf numbers.
  - *Source:* https://create.roblox.com/docs/environment/post-processing-effects and https://devforum.roblox.com/t/shaders-in-roblox-have-arrived-penumbra-luau-graphics/4128887
- ColorGradingEffect.TonemapperPreset has exactly two values: Default (0) and Retro (1). Retro imitates the pre-2019 Roblox lighting look; it replaced Compatibility lighting during the Aug-Oct 2024 sunset.
  - *Source:* https://create.roblox.com/docs/reference/engine/enums/TonemapperPreset and https://devforum.roblox.com/t/compatibility-lighting-becomes-retro-tone-mapping-sunset-migration/3128560
- Lighting.Technology (Voxel/ShadowMap/Future) was announced deprecated 21 Jan 2025, replaced by LightingStyle where Voxel is removed and ShadowMap/Future become Soft/Realistic. Regardless of setting, the engine falls back to voxel lighting at quality level 3 and below for performance.
  - *Source:* https://roblox.fandom.com/wiki/Future_Is_Bright and https://roblox.github.io/future-is-bright/compare.html
- ScreenGui.ScreenInsets enum: CoreUISafeInsets (default, clears topbar), DeviceSafeInsets (notch/cutout only, ignores Roblox core UI), TopbarSafeInsets (dynamic, limited to topbar area), plus None. ScreenGui.ClipToDeviceSafeArea clips descendants to the device safe area. SafeAreaCompatibility has two values: None (0) and FullscreenExtension (1). GuiService:GetInsetArea(screenInsets) returns a Rect; GuiService:GetGuiInset() returns a tuple.
  - *Source:* https://create.roblox.com/docs/reference/engine/classes/ScreenGui , https://create.roblox.com/docs/reference/engine/enums/SafeAreaCompatibility , https://create.roblox.com/docs/reference/engine/classes/GuiService
- GuiService:IsTenFootInterface() is marked DEPRECATED in the API reference.
  - *Source:* https://create.roblox.com/docs/reference/engine/classes/GuiService
- Gamepad focus APIs: GuiService:Select(instance) enters selection at the lowest SelectionOrder (ties broken topmost-then-leftmost); GuiBase2d.SelectionGroup (bool) + SelectionBehaviorUp/Down/Left/Right with Enum.SelectionBehavior.Escape (default) or Stop traps focus in a panel; GuiObject.SelectionOrder (int, default 0) affects entry order only, not directional movement; GuiBase2d.SelectionChanged(amISelected, previous, new) bubbles up the tree. PlayerGui.SelectionImageObject sets the focus ring for ALL elements; GuiObject.SelectionImageObject only for that one element.
  - *Source:* https://devforum.roblox.com/t/new-gamepad-ui-selection-apis/1791278
- Accessibility APIs: GuiService.ReducedMotionEnabled (bool; docs advise setting TweenInfo.Time to 0 or swapping movement for a fade), GuiService.PreferredTransparency (number; 1 = default, 0 = fully opaque; multiply BackgroundTransparency by it), GuiService.PreferredTextSize (Medium/Large/Larger/Largest). TextService:GetTextSize / GetTextBoundsAsync honour PreferredTextSize. React to changes via GuiService:GetPropertyChangedSignal.
  - *Source:* https://create.roblox.com/docs/production/publishing/accessibility and https://devforum.roblox.com/t/introducing-accessibility-settings/2723187
- WCAG 2.3.1 (Level A): nothing may flash more than THREE times in any one-second period unless below the general/red flash thresholds. A general flash = a pair of opposing relative-luminance changes of >=10 % of max where the darker state is below 0.80 relative luminance. Saturated red flashes are judged more strictly.
  - *Source:* https://www.w3.org/WAI/WCAG22/Understanding/three-flashes.html
- TextLabel.MaxVisibleGraphemes is the engine's purpose-built typewriter property (set to -1 for all). It exists precisely because the old string.sub-per-character approach 'can cause some issues'. Known caveat: it counts graphemes of the rendered text, so RichText markup needs care.
  - *Source:* https://devforum.roblox.com/t/typewriter-effect-new-property-maxvisiblegraphemes-live/1092043
- Roblox console guidance: players sit 8-10 feet from the screen; four directions + select + back must reach every UI element; navigation is strictly sequential so minimise moves; use InputActionLabel or UserInputService:GetStringForKeyCode()/GetImageForKeyCode() for platform-correct button glyphs; disable the chat window on console; add audio feedback for UI navigation and haptics for dramatic events.
  - *Source:* https://create.roblox.com/docs/production/publishing/console-guidelines
- The Roblox top bar is documented by staff as 36 offset px tall in the UI best-practices post, with a community correction that it is now 58 px. Modern iPhone is 19.5:9, iPad is 4:3; corner-pinned UI needs ~5-8 % extra inset for notch, home indicator and rounded corners.
  - *Source:* https://devforum.roblox.com/t/designing-ui-tips-and-best-practices/3074034
- Mobile touch target floor commonly cited for Roblox: 44x44 points (Apple HIG) / 48 dp (Android), roughly UDim2.fromScale(0.12, 0.07) on a phone; spacing between targets matters as much as size. Default Roblox touch controls occupy the bottom-left and bottom-right corners.
  - *Source:* https://simplified.media/guides/roblox-ui-systems and https://create.roblox.com/docs/production/game-design/ui-ux-design
- UI motion timing consensus: <100 ms reads as instantaneous, >1 s reads as sluggish; mobile 200-300 ms, tablet +30 % (400-450 ms), desktop 150-200 ms; asymmetric easing (fast accelerate, slow decelerate) reads as natural; shorter durations for exits and short travel.
  - *Source:* https://m1.material.io/motion/duration-easing.html and https://www.nngroup.com/articles/animation-duration/
- Concrete CSS-CRT numbers worth porting: scanlines as an 8 px-period gradient (4 px transparent / 4 px rgba(0,0,0,0.25)); a single 100 px-tall bright band that is off-screen for 80 % of a 10 s cycle then sweeps top-to-bottom in the last 20 %; per-channel text offsets of <1 px in blue (rgba(0,30,255,0.5)) and red (rgba(255,0,80,0.3)) for chromatic aberration; caret blink at 1 s with step-end timing (hard on/off, never a fade).
  - *Source:* https://dev.to/ekeijl/retro-crt-terminal-screen-in-css-js-4afh
- Signalis ships the CRT effect and film grain as TOGGLES in video settings; the aesthetic is 'cassette futurism' and even non-diegetic screens are justified as the android protagonist's own HUD.
  - *Source:* https://steventus.substack.com/p/glancing-signalis-part-1-immersion and https://steamcommunity.com/app/1262350/discussions/
- Lethal Company's UI uses 3270font (IBM 3270 terminal), a flat no-gradient palette (red/orange/yellow/green/blue) with red-orange reserved for alerts, simple circles/squares, transparency to read as projected, and context-sensitive prompts that appear only when actionable. Its screen-space pixelation filter is applied to the UI too, which is what makes it look 'rough'.
  - *Source:* https://indieklem.com/11-whats-behind-the-interface-of-lethal-company/ and https://fontsinuse.com/uses/68901/lethal-company-video-game
- PS1-era look, technically: vertex jitter comes from fixed-point vertex positions snapping to integer screen coordinates; affine texture mapping interpolates UVs from screen x/y only, ignoring z (modern equivalent: the 'noperspective' qualifier). Both are reproducible only by moving actual vertices in Roblox.
  - *Source:* https://www.david-colson.com/2021/11/30/ps1-style-renderer.html and https://danielilett.com/2021-11-06-tut5-21-ps1-affine-textures/
- PS1 gameplay generally targeted 30 fps while many titles animated characters at a lower rate; Final Fantasy VII-IX capped battle animation near 15 fps while MENUS ran at 60 fps. Modern demakes reproduce this by playing animators at a reduced rate over 60 fps gameplay.
  - *Source:* https://www.resetera.com/threads/so-why-did-final-fantasy-games-on-the-ps1-cap-at-15fps-for-battles-is-this-a-stylistic-choice-or-ps1-limitations.681631/
- Roblox image uploads were historically hard-capped at 1024x1024 (longest side scaled to 1024, shorter side proportionally); 4096x4096 decal support has since shipped but the upload page still advertises the old 1024 limit.
  - *Source:* https://devforum.roblox.com/t/decal-upload-page-still-mentions-1024x1024-limit-instead-of-4096x4096/4526770
- UIGradient docs advise not exceeding 6 colour stops for performance; ColorSequence.new() with an over-long table errors with 'table is too long'.
  - *Source:* https://create.roblox.com/docs/reference/engine/classes/UIGradient and https://devforum.roblox.com/t/what-is-the-maximum-amount-of-keypoints-in-a-colorsequence/1160624
- Project baseline: the entire interface is ONE ScreenGui 'KenopsiaMachine' with 521 descendants, IgnoreGuiInset = true, DisplayOrder 50, ZIndexBehavior Sibling; a single font (Enum.Font.Code); a 5-colour phosphor palette (#78FFAA / #8CE8AE / #2E6B4A / #020402 / #041005) plus #FF1818 danger and #EBF5EE; grunge overlay rbxassetid://89538183732053 tiled at transparency 0.55, tint #2E6B4A, as four edge strips each with a UIGradient.
  - *Source:* C:/Users/Asus/Claude/Kenopsia_Roblox Project/docs/place/04-GUI.md lines 1-60
- Project baseline: no code in studio-src references ResampleMode, CanvasGroup, MaxVisibleGraphemes, Atmosphere or UIAspectRatioConstraint anywhere. UIStroke appears 6 times, UIScale 3 times, GuiService.SelectedObject 8 times, ColorCorrectionEffect once (KenopsiaClient.client.luau:320).
  - *Source:* grep over C:/Users/Asus/Claude/Kenopsia_Roblox Project/studio-src (0 hits for ResampleMode|CanvasGroup|MaxVisibleGraphemes|Atmosphere|UIAspectRatio)
- Project baseline: MachineLayout.client.luau scales the GUI per platform against REF_HEIGHT = 710 px, clamping Mobile to 0.42-0.85, Console to 1.0-1.4 (x1.1), Desktop to 0.8-1.3, and compensates fullscreen frames with Size = UDim2.fromScale(1/s, 1/s) + UIScale. Platform detection uses the deprecated GuiService:IsTenFootInterface() plus a viewport min-axis < 500 heuristic.
  - *Source:* C:/Users/Asus/Claude/Kenopsia_Roblox Project/studio-src/StarterPlayer/StarterPlayerScripts/MachineLayout.client.luau lines 17-56, 32, 41
- Project baseline: typewriter runs at ~26 chars/s for info screens and one status line per 0.25 s; Pacing.Timing holds are Reveal 3.5 s, Title 1.2 s, RoundCard 3.0 s, RoundSettle 1.5 s, FadeMax 0.6 s, InterimScore 4.5 s, FinalScore 8.0 s, ControlCard 8.0 s. The comment records that plan values (3.0 / 6.0) were raised because cards vanished mid-word.
  - *Source:* C:/Users/Asus/Claude/Kenopsia_Roblox Project/studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/Pacing.luau lines 97-121
- Project baseline: a ReduceFlicker user setting already exists (KenopsiaClient.client.luau:232, toggled at :2262) and gates both the roulette flicker (:1648) and one other site (:1792). Camera shake is math.noise-driven with three decorrelated seeds (:1866-1874).
  - *Source:* C:/Users/Asus/Claude/Kenopsia_Roblox Project/studio-src/StarterPlayer/StarterPlayerScripts/KenopsiaClient.client.luau lines 232, 1648, 1792, 1866-1874, 2262

## Problems

### Roulette flicker runs at roughly 7 flashes per second for 1.6 s — over twice the WCAG photosensitivity limit — and the safety setting is opt-out, not opt-in

- **Evidence:** KenopsiaClient.client.luau:1652-1660 loops for 1.6 s doing `tiles[i].Icon.Visible = math.random() < 0.55` and `setTileLit(..., math.random() < 0.4)` every `task.wait(0.07)`. 0.07 s toggling = ~14 state changes/s, i.e. up to ~7 opposing luminance transitions per second, on bright #78FFAA phosphor against a #020602 background (a very large relative-luminance delta, well past the 10 % general-flash threshold). WCAG 2.3.1 caps this at 3 flashes/s. The guard `uiSettings.ReduceFlicker` (line 232) defaults to **false**.
- **Impact:** Photosensitive-seizure risk on the one screen every player sees every round, plus a platform-moderation and store-rating exposure. It is also the screen with the most eyes on it.
- **Fix idea:** Invert the default: derive the initial value from GuiService.ReducedMotionEnabled and default ReduceFlicker to true when that is set; raise the interval from 0.07 to >=0.34 s (under 3 flashes/s) or, better, keep the fast rate but flicker only the *dim* channel (#2E6B4A <-> #78FFAA is a big delta; #2E6B4A <-> #8CE8AE is much smaller) so the luminance swing stays under the general flash threshold. Also cap the burst duration.

### Typewriter uses byte-wise string.sub instead of MaxVisibleGraphemes: breaks on non-ASCII, cannot use RichText, and invalidates the whole 521-descendant UI render cache once per character

- **Evidence:** KenopsiaClient.client.luau:413-421: `for i = 1, #text do label.Text = string.sub(text, 1, i) ... end`. `#text` is byte length and `string.sub` slices bytes, so any UTF-8 character (the codebase is bilingual German/English — 'Naehe', 'Schirm' are ASCII-safe today but 'ä/ö/ü' are two bytes) renders a broken glyph on the intermediate frame. Setting .Text is a property change on a descendant of KenopsiaMachine, which per the Static UI announcement clears that Gui's entire cached appearance array — for all 521 descendants — on every character.
- **Impact:** Latent mojibake the moment anyone types a real umlaut or adds RichText colour to a word; and a per-character full re-rasterisation of the biggest ScreenGui in the game, which is exactly the cost profile that hurts on low-end phones.
- **Fix idea:** Set `label.Text` once and animate `label.MaxVisibleGraphemes` from 0 upward (-1 to reveal all). It is grapheme-correct, RichText-safe, and it is the property Roblox shipped for this exact purpose. Combine with splitting the typing screens into their own ScreenGui (see next finding).

### One ScreenGui holds all 521 descendants, static and animated alike, so every animated pixel re-rasterises the whole interface

- **Evidence:** docs/place/04-GUI.md: 'Ein einziges ScreenGui in StarterGui, 521 Nachkommen', containing both permanently-static art (the four grunge strips with their UIGradients, the eight corner brackets per tile, the icon pool) and everything that animates (typewriter, flicker, crosshair tweens, tickers, fader). Roblox: 'any change in any descendant of a Gui will invalidate the entire Gui's appearance ... consider separating mostly-static and mostly-dynamic UI into separate Guis'.
- **Impact:** Every retro flourish this lens recommends (scanline sweep, flicker, ticking counters, breathing glow) multiplies against 521 descendants instead of against the handful of elements actually changing. This is the single structural blocker to an 'alive' UI on phones.
- **Fix idea:** Split into at least three ScreenGuis at ascending DisplayOrder: KenopsiaMachine_Static (grunge strips, brackets, chrome), KenopsiaMachine_Live (text, counters, flicker targets), KenopsiaMachine_Overlay (scanlines/vignette/fader). Measure before/after in the MicroProfiler on a real phone, not in Studio.

### Typewriter speed is frame-quantised by task.wait, so text types ~40 % slower on a 30 fps phone while the Pacing holds stay fixed in seconds

- **Evidence:** KenopsiaClient.client.luau:419 `task.wait(1 / cps)` with cps = 26 requests 38.5 ms, but task.wait resolves on a frame boundary: at 60 fps it rounds up to 50 ms (3 frames) -> ~20 cps; at 30 fps it rounds to 66.7 ms (2 frames) -> ~15 cps. Pacing.Timing.Reveal is a fixed 3.5 s and the file already records that cards were observed vanishing mid-word (Pacing.luau:100-110).
- **Impact:** The exact bug the Pacing comment describes will reappear on low-end phones, which is where most of the audience is, and it will not reproduce on the developer's desktop.
- **Fix idea:** Drive the reveal from elapsed time rather than per-character sleeps: on RunService.PreRender (or a Heartbeat accumulator) set MaxVisibleGraphemes = math.floor((os.clock() - t0) * cps). Speed then becomes framerate-independent, and it collapses to one property write per frame instead of one per character.

### Platform detection depends on a deprecated API and a magic viewport threshold

- **Evidence:** MachineLayout.client.luau:32 `if GuiService:IsTenFootInterface() then return "Console" end` — the method is marked Deprecated in the API reference — and :41 `if math.min(vp.X, vp.Y) < 500 then return "Mobile" end`. An iPad (4:3, min axis ~768-1024 pt) therefore lands in the Desktop branch and gets Desktop clamps 0.8-1.3 plus Desktop control glyphs.
- **Impact:** Tablets get desktop-sized touch targets and keyboard prompts; any future deprecation removal silently reclassifies every console player as Desktop.
- **Fix idea:** Compose the signal instead: UserInputService.TouchEnabled / KeyboardEnabled / MouseEnabled / GamepadEnabled + UserInputService.LastInputTypeChanged for live switching, and treat aspect ratio (4:3 vs 19.5:9) as a layout axis separate from input class. Keep IsTenFootInterface only as a hint.

### IgnoreGuiInset = true with no ScreenInsets/safe-area handling puts the phosphor chrome under the notch and the Roblox topbar

- **Evidence:** docs/place/04-GUI.md records `IgnoreGuiInset = true` on KenopsiaMachine; grep finds zero references to ScreenInsets, ClipToDeviceSafeArea or SafeAreaCompatibility anywhere in studio-src. The topbar is 36 px (staff) / 58 px (community correction) and corner-pinned UI needs ~5-8 % extra inset for notch + home indicator + rounded corners.
- **Impact:** On notched phones the top-left corner brackets and the TopTicker sit under the cutout; on console, overscan can clip them. A full-bleed CRT overlay actually *wants* IgnoreGuiInset, but the readable chrome does not.
- **Fix idea:** Two-layer approach that also serves the CRT look: the overlay ScreenGui keeps IgnoreGuiInset = true and ScreenInsets = None so scanlines/vignette bleed edge to edge; the content ScreenGui uses ScreenInsets = DeviceSafeInsets (or TopbarSafeInsets) so no glyph is ever occluded. Verify with GuiService:GetInsetArea().

### Accessibility settings the engine already exposes are unread, so the game's own ReduceFlicker toggle is the only escape hatch

- **Evidence:** grep over studio-src: zero hits for ReducedMotionEnabled, PreferredTransparency, PreferredTextSize. The project defines its own `uiSettings = { UiSound, Music, ReduceFlicker }` (KenopsiaClient.client.luau:232) with no bridge to GuiService.
- **Impact:** A player who has already told Roblox 'reduce motion' still gets the full flicker, shake and crosshair whip on first launch, before they find the settings panel.
- **Fix idea:** Seed ReduceFlicker (and a new ReduceShake) from GuiService.ReducedMotionEnabled at startup and follow GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"); multiply every BackgroundTransparency by GuiService.PreferredTransparency so the grunge overlay's 0.55 becomes opaque for players who need contrast.

### Pixel-art fidelity is currently unobtainable because no image path sets ResampleMode

- **Evidence:** The one bitmap in the whole interface is the grunge overlay rbxassetid://89538183732053 tiled with ScaleType = Tile (04-GUI.md), and grep finds no ResampleMode assignment anywhere in studio-src. Every icon is built from plain Frames (IconPool: Cube = 3x3 grid of 19x19 blocks, Magnifier = 44x44 ring + 30x8 handle rotated 45 deg).
- **Impact:** Frame-built icons are crisp but they cost one quad each and cannot carry dithering, 1-bit stipple, or authentic low-res sprite texture. Meanwhile any bitmap added later will be bilinear-smeared by default, which is the single most 'un-retro' artefact possible.
- **Fix idea:** Set ResampleMode = Pixelated as a house rule on every ImageLabel/ImageButton, author source art at true low resolution (e.g. 64x64) and let the engine magnify it. Note the staff warning: never *minify* a Pixelated image, so pair it with UIAspectRatioConstraint so the display size is always an integer multiple of the source.

## Opportunities

### Scanline overlay: one ImageLabel in a dedicated overlay ScreenGui, ScaleType = Tile, TileSize a small even offset (port the CSS 8 px period: 4 px transparent / 4 px black at 25 % alpha), ResampleMode = Pixelated, IgnoreGuiInset = true, ScreenInsets = None so it bleeds edge to edge.

- **Why:** Single cheapest signal that reads instantly as CRT; unifies every screen under one glass surface and hides the fact that icons are flat Frames.
- **Cost:** One GuiObject, static, zero per-frame work. Risk: near zero. Must live in its OWN ScreenGui or it defeats the static-UI cache. Second risk: on a 4:3 iPad vs 19.5:9 phone the tile count differs — use an offset TileSize (device pixels) not scale, so line thickness stays constant.
- **Source:** https://dev.to/ekeijl/retro-crt-terminal-screen-in-css-js-4afh + https://devforum.roblox.com/t/static-ui-performance-improvements/222557

### Rolling refresh band: a single tall ImageLabel or gradient-filled Frame with high transparency that sweeps top-to-bottom. Port the CSS timing exactly — off screen for 80 % of a 10 s cycle, sweep in the last 20 % (i.e. 8 s idle, 2 s sweep).

- **Why:** Idle life with almost no attention cost. The long silence between sweeps is what makes it feel like a real screen rather than a loop.
- **Cost:** One tweened Position per 10 s (or one property write per frame during the 2 s sweep). Risk: low, but it must be in the overlay ScreenGui, and it should be gated by ReducedMotionEnabled.
- **Source:** https://dev.to/ekeijl/retro-crt-terminal-screen-in-css-js-4afh

### Phosphor glow without a shader: UIStroke on text with Color = #78FFAA, high Transparency and a UIGradient child for falloff, plus a low-alpha duplicate TextLabel offset by 1 px. For a soft halo behind a panel use a 9-slice radial ImageLabel rather than a real blur.

- **Why:** Turns flat green text into something that looks emitted rather than printed — the core of the phosphor read. The codebase already builds a UIStroke glow at KenopsiaClient.client.luau:1130, so the pattern exists.
- **Cost:** UIStroke is static geometry once set; cheap. Risk: low. Do NOT animate stroke Thickness every frame on many labels — each write invalidates the parent Gui's cache.
- **Source:** https://create.roblox.com/docs/reference/engine/classes/UIStroke

### Chromatic jolt on impact: on a hit/reject event, clone the key TextLabel twice, tint one #0000FF-ish and one #FF0050-ish at ~0.5/0.3 transparency, offset each by <=1 px in opposite directions for 80-120 ms, then destroy. Port the CSS text-shadow offsets (0.44 px blue, -0.44 px red).

- **Why:** Reads as signal instability and gives hits a physical bite without moving the camera. Pairs with the existing gore shake for a two-tier feedback ladder (small = chroma, large = shake).
- **Cost:** Two temporary GuiObjects for ~100 ms. Risk: low. Keep it under 3 occurrences/second to stay clear of WCAG's flash rule, and skip entirely when ReducedMotionEnabled.
- **Source:** https://dev.to/ekeijl/retro-crt-terminal-screen-in-css-js-4afh + https://www.w3.org/WAI/WCAG22/Understanding/three-flashes.html

### Step-end cursor: a 6x14 Frame after the last typed grapheme, toggled Visible on a 1 s period with a HARD cut (never a tween). Roblox equivalent of CSS `animation-timing-function: step-end`.

- **Why:** One of the strongest 'the machine is waiting for you' cues in the terminal vocabulary, and it costs one boolean per 500 ms.
- **Cost:** One property write per 500 ms. Risk: negligible — 1 flash/s is far under the 3/s threshold. Never fade it; a tweened cursor immediately reads as modern web UI, not as a terminal.
- **Source:** https://dev.to/ekeijl/retro-crt-terminal-screen-in-css-js-4afh

### Replace the per-character typewriter with MaxVisibleGraphemes driven from elapsed time on PreRender, and emit a short blip Sound per N graphemes with PlaybackSpeed randomised in a narrow band (e.g. 0.94-1.06) so the run does not sound like a machine gun.

- **Why:** Fixes correctness (RichText, UTF-8, frame-rate independence) and adds the per-character audio that carries most of the 'alive terminal' feeling. Cheap to A/B.
- **Cost:** One property write per frame while typing (vs one per character today) + sound instances. Risk: low. Cap concurrent UI sounds and route them through a SoundGroup so the existing UiSound toggle controls them; parent to SoundService or the ScreenGui so they are 2D.
- **Source:** https://devforum.roblox.com/t/typewriter-effect-new-property-maxvisiblegraphemes-live/1092043 + https://create.roblox.com/docs/reference/engine/classes/SoundService#PlayLocalSound

### Boot ledger on join: reuse the existing KenopsiaLoadingGui (DisplayOrder 100, built by ReplicatedFirst.KenopsiaLoading) to print a stepped POST sequence — fixed-width lines, right-aligned OK/FAIL, one line per 120-200 ms, with a deliberate 600-900 ms stall on one line before it resolves.

- **Why:** Converts unavoidable load time into worldbuilding and sets the machine's voice before the first trial. Signalis/Iron Lung/Lethal Company all open this way; it is the cheapest identity win available.
- **Cost:** Text writes on an already-separate ScreenGui, so it does not touch the main GUI's cache. Risk: none technically; the risk is pacing — do not exceed the actual load time or players wait on a fake.
- **Source:** https://create.roblox.com/docs/reference/engine/classes/ReplicatedFirst + https://indieklem.com/11-whats-behind-the-interface-of-lethal-company/

### Stepped (held-frame) UI animation as the house style: instead of TweenService, quantise motion to a 12 or 15 fps grid — accumulate dt and only write Position/Size when the accumulator crosses 1/12 s. Reserve smooth tweens for the crosshair snap and fades.

- **Why:** This is the actual PS1 signature people recognise (FF7-9 animated battles near 15 fps while menus ran at 60). It also *reduces* property writes by 4-5x versus a 60 fps tween, so it is faster AND more period-correct.
- **Cost:** Negative cost — fewer writes than a tween. Risk: low; the trap is applying it to fades (banding looks like a bug, not a style) and to input-following elements like a drag cursor, which must stay at full rate.
- **Source:** https://www.resetera.com/threads/so-why-did-final-fantasy-games-on-the-ps1-cap-at-15fps-for-battles-is-this-a-stylistic-choice-or-ps1-limitations.681631/

### Dither/1-bit fades: instead of tweening BackgroundTransparency 0 -> 1, cross-fade through 3-4 tiled Bayer-pattern ImageLabels (ResampleMode = Pixelated, ScaleType = Tile) swapped at 12 fps.

- **Why:** A dithered dissolve is unmistakably period-correct and hides the fact that Roblox's alpha blending is perfectly smooth. Works as the transition between the six machine screens.
- **Cost:** 3-4 small uploaded textures, one Visible swap per step. Risk: low. Author the patterns at 4x4 or 8x8 px and let Pixelated magnify — never minify them (staff warning about shimmering on size reduction).
- **Source:** https://devforum.roblox.com/t/resamplemode-new-property-for-image-gui-objects/1418681

### Idle life budget: give the Selection screen 3-4 independent low-frequency oscillators — a ticking uptime counter (1 Hz), a slow breathing glow on one bracket (UIStroke Transparency, 4-6 s sine), a random interference blip (~1 per 8-20 s, 80 ms), and the 10 s scanline sweep. Decorrelate their periods so they never sync.

- **Why:** 'Alive' is mostly the absence of perfect stillness. Four decorrelated slow signals read as a running machine; one fast signal reads as an animation loop. Cheapest possible retention lever on the screen players idle on between rounds.
- **Cost:** ~4 property writes per second total if each lives in the Live ScreenGui. Risk: low, provided all four are in the dynamic ScreenGui and none of them touch the static chrome.
- **Source:** https://devforum.roblox.com/t/static-ui-performance-improvements/222557

### Relay-click input feedback: every focus move, confirm and reject gets a distinct short sample (relay click / solenoid thunk / buzzer), routed through a SoundGroup, with a constant low CRT hum bed at very low volume that ducks during announcements.

- **Why:** Console guidelines explicitly require audio feedback for UI navigation; more importantly the hum is what makes silence feel like a room rather than a mute. The project already has a UiSound toggle to hang this on.
- **Cost:** One SoundGroup + a handful of short assets; near-zero CPU. Risk: low. Keep UI samples under ~120 ms and randomise PlaybackSpeed slightly to avoid machine-gun repetition on rapid gamepad navigation.
- **Source:** https://create.roblox.com/docs/production/publishing/console-guidelines

### Gamepad focus as a first-class retro element: set PlayerGui.SelectionImageObject to a custom phosphor bracket (four corner Frames matching the existing 26x6 / 6x26 tile brackets) rather than Roblox's default blue ring, and trap focus per-panel with GuiBase2d.SelectionGroup + SelectionBehavior.Stop.

- **Why:** Makes the console/10-foot experience feel authored instead of borrowed, and the bracket vocabulary already exists in the design. Focus trapping removes the 'selection escaped into another screen' class of bug the codebase currently patches by hand (KenopsiaClient.client.luau:1503-1504, MachineLayout.client.luau:369-381).
- **Cost:** One extra GuiObject + a few properties per panel; replaces imperative SelectedObject juggling. Risk: low, and it deletes code. Use GuiService:Select(panel) for entry ordering via SelectionOrder rather than picking a 'best' element manually.
- **Source:** https://devforum.roblox.com/t/new-gamepad-ui-selection-apis/1791278

### Free PS1 grade for the 3D world: ColorGradingEffect with TonemapperPreset = Retro, plus ColorCorrectionEffect (low Saturation, slight green Tint toward #78FFAA, raised Contrast) on the existing effect at KenopsiaClient.client.luau:320.

- **Why:** Retro tonemapping is literally the pre-2019 Roblox renderer, which is the closest thing the engine has to a period look, and it costs one instance. It also ties the 3D arenas to the phosphor UI palette so the whole game reads as one signal.
- **Cost:** Two post-process instances, fixed GPU cost per frame. Risk: low-medium on very low-end phones — post effects have a fixed cost that low-end players 'would appreciate minimized' (zeuxcg). Gate ColorGrading off below a quality threshold.
- **Source:** https://create.roblox.com/docs/reference/engine/enums/TonemapperPreset + https://devforum.roblox.com/t/compatibility-lighting-becomes-retro-tone-mapping-sunset-migration/3128560

### PS1 draw-distance fog as a style AND a perf tool: Lighting.FogStart/FogEnd pulled in tight with FogColor matched to the background, plus an Atmosphere with high Density and low Offset for the haze wall.

- **Why:** Hard fog cutoff is the second-most-recognisable PS1 signature after vertex jitter, it hides pop-in instead of apologising for it, and it lets arenas stay small without feeling small. Costs nothing.
- **Cost:** Zero-to-negative (fog culls distant rendering work). Risk: essentially none. Note Atmosphere and legacy fog interact — tune one or the other, not both blind.
- **Source:** https://create.roblox.com/docs/reference/engine/classes/Atmosphere + https://create.roblox.com/docs/environment/post-processing-effects

### Pixelated textures in 3D via SurfaceGui + ImageLabel (ResampleMode = Pixelated) on flat faces — signage, monitors, floor markings, warning placards — instead of Decal/Texture.

- **Why:** The only way to get genuine nearest-neighbour texels in the 3D world today. Applied to the machine's own screens inside the arena it makes the diegetic monitors match the HUD exactly, which is the Signalis trick (the UI is the android's own display).
- **Cost:** One SurfaceGui + ImageLabel per surface; SurfaceGuis are real UI render work in world space, so cap the count and set MaxDistance/LightInfluence. Risk: medium if scattered widely; low for a handful of hero surfaces. Does not wrap curved geometry.
- **Source:** https://devforum.roblox.com/t/resamplemode-for-materials-and-textures/1783233

### Low-poly + flat shading + fixed camera angles as the cheap 90 % of the PS1 look: author meshes with hard edges (no smoothed normals) in the Blender file already in the repo, keep textures tiny and let them magnify, and use fixed/limited camera posts like RE/Signalis rather than free-look wherever the trial allows.

- **Why:** Delivers most of the perceived PS1 read for zero runtime cost and zero risky API surface, and fixed camera posts are already how the arenas are built ('one slab, four spawn markers, one camera post' in every trial service).
- **Cost:** Art-time only; runtime cost strictly lower than the current smooth-shaded equivalent. Risk: none.
- **Source:** https://www.david-colson.com/2021/11/30/ps1-style-renderer.html + C:/Users/Asus/Claude/Kenopsia_Roblox Project/studio-src/ServerScriptService/KenopsiaServer/Services/TrialKit.luau:202-239

### Camera-CFrame quantisation for a whole-screen PS1 jitter: on RenderStepped, round the camera CFrame's position to a coarse grid (e.g. 1/8 stud) and its look angles to a coarse step. Every vertex in the world then jitters together, for the cost of one CFrame write per frame.

- **Why:** Approximates the PS1's fixed-point vertex snapping globally without touching a single mesh, and it is instantly togglable as an accessibility/perf option. Far cheaper than EditableMesh warping.
- **Cost:** One CFrame assignment per frame. Risk: MEDIUM for motion sickness and for aim precision — it must be off during aimed gameplay (BirdHunting scope) and off under ReducedMotionEnabled. Quantising rotation is much more nauseating than quantising position; start with position only.
- **Source:** https://www.david-colson.com/2021/11/30/ps1-style-renderer.html (fixed-point snapping) + https://danielilett.com/2021-11-06-tut5-21-ps1-affine-textures/

### True per-mesh vertex warping via EditableMesh (the published PS1VertexWarping module) — but only for one or two hero props, at a fixed low update rate, time-sliced across frames.

- **Why:** The only route to the authentic wobble on a specific object (e.g. the machine's own housing, or a single trial prop) rather than the whole camera.
- **Cost:** HIGH. SetPosition() is one vertex per call with a full GPU mesh re-upload each update; 60 000 vertex hard cap; memory budget errors reported in production; 13+/ID-verified creator and owned-mesh permission requirements. Risk: HIGH on low-end phones — this is the item most likely to tank the frame budget. If used at all: FixedSize clones, <500 verts, update at 12-15 Hz not per frame, time-sliced.
- **Source:** https://devforum.roblox.com/t/ps1-style-vertex-warping-shader-module-using-editablemeshes/3572022

### Deliberately DON'T attempt: a low-resolution ViewportFrame render of the 3D scene scaled up for chunky pixels.

- **Why:** Saves the team from a dead end. ViewportFrame has no ResampleMode and is bilinear-upscaled, so a low-res viewport produces a blurry smear, not pixels; it also carries a 1024-px axis cap and is widely reported as a low-end-device performance hazard.
- **Cost:** N/A — the recommendation is to skip it. Achieve the same read with the Pixelated dither/scanline overlays instead.
- **Source:** https://devforum.roblox.com/t/add-resamplemode-to-viewportframe/3030577 + https://devforum.roblox.com/t/viewportframe-performance-issues-for-displaying-items/1798310

### CanvasGroup for whole-screen dissolves only: wrap a screen in a CanvasGroup and animate GroupTransparency once per transition, then reparent or disable it. Do not leave animated content inside a CanvasGroup.

- **Why:** Gives a real cross-fade of an entire composited screen (which stacked per-element transparency cannot do without ugly overlap artefacts), which is what makes screen changes feel like a channel change rather than a layer swap.
- **Cost:** One offscreen render target the size of the group. Risk: MEDIUM on low-end — at graphics level 3 and below CanvasGroup output is downscaled and animations throttled, and any change inside re-renders the whole texture. Use it for the 0.6 s FadeMax transition and nothing else.
- **Source:** https://create.roblox.com/docs/reference/engine/classes/CanvasGroup + https://devforum.roblox.com/t/canvasgroup-performance-concerns/3556937

### Motion timing house rules, written down: hard cuts (0 ms) for terminal state changes; 100-150 ms for hit/confirm feedback; 200-300 ms for panel transitions on mobile, 150-200 ms on desktop, ~400 ms on tablet; nothing over 600 ms except the existing FadeMax. Easing: Linear or step for anything that should read as machine, Quart/Out only for the crosshair snap.

- **Why:** Gives the retro identity a rule rather than a vibe: machines don't ease. Linear/stepped motion for machine elements plus one eased human-feeling element (the crosshair, already Quart/Out at 0.32 s) creates a readable hierarchy.
- **Cost:** Zero — it's a policy, enforced in a Motion constants module next to Pacing.luau. Risk: none.
- **Source:** https://m1.material.io/motion/duration-easing.html + https://www.nngroup.com/articles/animation-duration/

### Two-tier hit feedback ladder with hit-stop: minor events get a 60-100 ms freeze of the affected UI element plus a chroma jolt; major events get the existing math.noise camera shake. Add input buffering on confirm so a press during a transition is not swallowed.

- **Why:** 'Juice It or Lose It' techniques (hit-stop, screen shake, input buffering, easing) are the canonical cheap levers for making the same rules feel better. The shake infrastructure already exists at KenopsiaClient.client.luau:1866-1874; only the small tier is missing.
- **Cost:** Low — a timer and a couple of property writes. Risk: low, but every tier must respect ReducedMotionEnabled and the shake amplitude must be user-scalable.
- **Source:** https://www.gdcvault.com/play/1016487/Juice-It-or-Lose

### Make the CRT layer a player-facing toggle (CRT: ON/OFF, Grain: ON/OFF, Flicker: ON/REDUCED) exactly as Signalis does, seeded from GuiService.ReducedMotionEnabled and surfaced in the existing SettingsPanel next to ReduceFlicker.

- **Why:** Turns an accessibility obligation into an identity beat — the settings panel itself becomes part of the machine's fiction — and lets low-end phones drop the overlay layer entirely for free frames.
- **Cost:** Zero runtime; a few rows in the existing SettingsPanel (rows are already wired at KenopsiaClient.client.luau:2262). Risk: none.
- **Source:** https://steamcommunity.com/app/1262350/discussions/ (Signalis CRT/film-grain toggles) + https://create.roblox.com/docs/production/publishing/accessibility

### Honour GuiService.PreferredTransparency and PreferredTextSize: multiply the grunge overlay's 0.55 and GrungeWash's 0.25 by PreferredTransparency, and derive TextSize from PreferredTextSize (Medium/Large/Larger/Largest) instead of hardcoded 14 px.

- **Why:** The design leans on a low-contrast dark-green-on-near-black palette (#8CE8AE body text on #020602) plus a 0.55-alpha grunge wash — exactly the combination that fails for low-vision players and on a sunlit phone. Respecting the two settings costs almost nothing and widens the audience.
- **Cost:** Two property multiplications at startup + a changed-signal handler. Risk: low; requires the layout to tolerate larger text (test at Largest on a 4:3 iPad, where MachineLayout currently applies Desktop clamps).
- **Source:** https://create.roblox.com/docs/production/publishing/accessibility

### Adopt a real terminal typeface via an uploaded bitmap font atlas rendered as Pixelated ImageLabels for headline/counter text (keeping Enum.Font.Code for body), the way Lethal Company uses 3270font.

- **Why:** Font is the highest-signal, lowest-effort identity lever in a mono-typeface interface; Code is generic, an IBM-3270-style bitmap face is specific. Restricting it to headlines and counters keeps the cost bounded.
- **Cost:** MEDIUM implementation (glyph atlas + a small text-layout routine) and one draw per glyph, so limit to short strings. Risk: medium — do not use it for body copy or localisation; per-glyph ImageLabels multiply descendant count, which is exactly what the render cache punishes.
- **Source:** https://fontsinuse.com/uses/68901/lethal-company-video-game + https://indieklem.com/11-whats-behind-the-interface-of-lethal-company/

### Add UIAspectRatioConstraint to every element whose shape carries meaning (the three 128x128 roulette tiles, the 78x78 icon holders, the 44x44 corner brackets) and UISizeConstraint to clamp panels, instead of relying solely on the global UIScale in MachineLayout.

- **Why:** A scale-sized square is only square on a square screen; the roulette tiles are the visual signature of the game and they currently deform between 19.5:9 and 4:3. It also makes integer-multiple sizing possible, which is a prerequisite for Pixelated art to stay crisp.
- **Cost:** Zero runtime (constraints resolve in layout). Risk: none. grep confirms zero UIAspectRatioConstraint usage today.
- **Source:** https://create.roblox.com/docs/ui/size-modifiers + https://devforum.roblox.com/t/why-should-i-use-uiaspectratioconstraint-over-just-scaling-the-ui/3183426

### Set a touch-target floor of 44x44 pt with real gaps between neighbours, and re-check the mobile scale clamp: MachineLayout clamps Mobile to as low as 0.42, so a 128 px tile becomes ~54 px and a 26x6 bracket becomes ~11x2.5 px.

- **Why:** At 0.42 scale the interface is technically visible but below the tap-accuracy floor, and thin brackets vanish into sub-pixel. Fixing this is a straight conversion win on the platform where most players are.
- **Cost:** Layout work; zero runtime. Risk: low, but it forces a real decision about what gets cut on small screens (progressive disclosure, as the console guidelines recommend).
- **Source:** https://simplified.media/guides/roblox-ui-systems + https://create.roblox.com/docs/production/publishing/console-guidelines + MachineLayout.client.luau:51

### Profile the UI on a real phone with the MicroProfiler (Settings > MicroProfiler On, then browse to the device's IP:port from a dev machine) before and after adding any of the above.

- **Why:** Every technique here is cheap in isolation and the failure mode is cumulative. The mobile client is the correct place to profile because that is where the thermal and bandwidth ceiling actually is; Studio will not reproduce it.
- **Cost:** Time only. Risk: none. This is the gate that decides how many of the 'idle life' oscillators the budget supports.
- **Source:** https://create.roblox.com/docs/performance-optimization/microprofiler

## Open questions

- What is the actual measured frame cost of the current KenopsiaMachine (521 descendants, one ScreenGui) on a low-end Android during the roulette flicker? Nothing in docs/place/ or PLAN.md records a UI render number, so every perf claim in this report about the cache is structural rather than measured. This needs one MicroProfiler capture on a real phone before any overlay layer is added.
- Is ReduceFlicker default-false a deliberate design decision or an oversight? It changes whether the WCAG finding is a bug or a policy question.
- Does the target audience include console at all? MachineLayout has a full Console branch with 10-foot scaling and gamepad text, and KenopsiaClient juggles GuiService.SelectedObject in 8 places, but nothing states console is a shipping platform. The gamepad focus-trap work (SelectionGroup/SelectionBehavior) is only worth doing if it is.
- Is 4:3 (iPad) a supported layout? Current detection sends tablets down the Desktop branch, and the roulette tiles have no aspect constraint, so the answer determines how much layout work the pixel-art rules imply.
- Are EditableMesh/EditableImage even available to this creator account? The PS1 vertex-warping route requires a 13+, ID-verified creator and creator- or group-owned meshes. If that gate is not met, camera-CFrame quantisation is the ONLY jitter route and the whole Layer-2 discussion collapses to art direction.
- Does the project intend to ship any uploaded bitmap art beyond the single grunge texture (rbxassetid://89538183732053)? Every Pixelated/dither/bitmap-font technique here assumes a willingness to author and upload low-resolution source art; the current interface is built almost entirely from Frames.
- What framerate floor is the target? The stepped-animation and camera-quantisation recommendations assume a stable 30 fps baseline; if phones are already dipping below that, the correct move is to cut UI layers, not add them.
- Has Lighting.Technology already been migrated on the live place (110672791536316)? The Technology property is on a deprecation path toward LightingStyle (Soft/Realistic); the ColorGrading Retro recommendation should be validated against whatever the place currently has set, which this read-only pass did not query.
