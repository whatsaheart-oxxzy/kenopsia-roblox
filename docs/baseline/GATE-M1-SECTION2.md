# Gate M1 §2 — scene, character and camera

Target: `Kenopsia_DEV` `129909297895850`, universe `10640788131`.
`KenopsiaMainGame` untouched throughout.

Baseline (the "before" state) is `GATE-M1-BASELINE.md` and
`dev-instance-tree.csv`. This file is the change log.

Preflight passed at `2d4752a` before the first mutation: correct place, correct
universe, Edit mode, one plugin client, one MCP instance, clean tree.

---

## Part A — scene scaffolding (COMPLETE)

**Every change in Part A is additive or a property edit. Nothing was deleted.**
All six placeholder Parts are still present, per the replace-before-delete rule.

### A1. `MainMenuWAll` — four identical `Wall` Parts uniquely renamed

Baseline problem: four sibling Parts all named `Wall`. A path read resolves the
first, so the other three could not be read or written at all.

`mutate_instances_rename` accepts a `siblingIndex`, so renaming `siblingIndex 1`
four times in succession names each remaining part in original sibling order —
no destructive workaround needed.

| New name | Position | Size |
|---|---|---|
| `Wall_01` | `(143.30, 14.00, 26.90)` | `113 × 1 × 10` |
| `Wall_02` | `(143.30, 21.00, 27.90)` | `113 × 1 × 10` |
| `Wall_03` | `(145.30, 6.00, 25.90)` | `113 × 1 × 10` |
| `Wall_04` | `(143.30, 29.00, 28.90)` | `113 × 1 × 10` |

Four stacked horizontal slabs. **`Wall_03` is the session wall** — the one behind
the `Host/Join/Public Session` Parts at `Z = 25.15`.

### A2. `Workspace.MenuStage` created

New `Folder` holding the five markers the spec requires. Marker convention:
`Anchored = true`, `Transparency = 1`, `CanCollide/CanTouch = false`,
`CastShadow = false`, `Locked = true`.

| Instance | Class | Position | Size | `CanQuery` |
|---|---|---|---|---|
| `LandingCamera` | Part | `(135.2, 8.0, 2.4)` | `1×1×1` | false |
| `SessionCamera` | Part | `(138.9, 6.2, 16.5)` | `1×1×1` | false |
| `CharacterAnchor` | Part | `(129.6, 4.0, 15.1)` | `2×1×2` | false |
| `SessionDisplay` | Part | `(138.9, 5.5, 25.15)` | `8×7×0.2` | **true** |
| `MenuLights` | Folder | — | — | — |

Placement rationale, all derived from measured geometry rather than invented:

- `LandingCamera` / `SessionCamera` reproduce the spec's camera positions exactly.
- `CharacterAnchor` is the rig's **existing** `HumanoidRootPart` position, so the
  established composition is preserved rather than re-authored. Floor top is
  `Y = 1.0`; `Y = 4.0` is the correct R6 root height.
- `SessionDisplay` sits at `(138.9, 5.5, 25.15)` — **exactly the spec's
  `SessionCamera` look-target**, which is also `Join Session`'s position, the
  middle of the wall trio. Sized `8 × 7` to frame all three buttons
  (they span `X 136.4–141.4`, `Y 3.0–8.0`) with margin. `CanQuery = true` as the
  spec requires for SurfaceGui interaction.
- Default `SurfaceGui` `Face = Front` is the `-Z` face, which points back toward
  `SessionCamera` at `Z = 16.5`. No rotation needed.

### A3. `CameraPart` converted to an invisible marker

| Property | Before | After |
|---|---|---|
| `Transparency` | 0 | **1** |
| `CanCollide` | true | **false** |
| `CanTouch` | true | **false** |
| `CanQuery` | true | **false** |
| `CastShadow` | true | **false** |
| `Locked` | — | **true** |

It was a solid, visible, shadow-casting block at head height that a player could
walk into.

### A4. Rig defect fixed — `Torso.Anchored`

`Workspace.Rig.Torso` was `Anchored = true`. Now `false`. **All seven R6 parts
are unanchored**, verified individually.

This was the real blocker on promoting the rig: an anchored Torso on a
`StarterCharacter` freezes the character's physics outright.

### A5. Materials — the "Real" variants are out of use

`Wall Real` / `Floor Real` are `MaterialVariant`s, so disabling them means
reassigning the parts that reference them, not editing the variants.
`Material` must be set **before** `MaterialVariant` — a variant only binds when
its `BaseMaterial` matches the part's `Material`.

| Part | Before | After |
|---|---|---|
| `Workspace.Wall` | `Brick` / `Wall Real` | `Concrete` / `RETRO_Concrete_WallA` |
| `Workspace.Floor` | `Ground` / `Floor Real` | `Asphalt` / `RETRO_Asphalt_Old` |
| `MainMenuWAll.Wall_01..04` | `Brick` / `Wall Real` | `Concrete` / `RETRO_Concrete_WallA` |

Verified: **no surveyed part references `Wall Real`, `Floor Real` or
`Ceiling Real` any more.** The variants themselves are left in place, unused —
deleting them is not required to disable them and would be harder to reverse.

### A6. Post-change capture

`docs/baseline/dev-instance-tree-after-s2a.csv` — 1,024 instances.
`Workspace` now has 18 direct children (17 + `MenuStage`).

---

## Tooling limit found — instance-typed properties cannot be set

`manage_properties_set` accepts primitives, `Vector3 {x,y,z}`,
`Color3 {r,g,b}`, `CFrame` (12-number array), `UDim2` and Enum strings.
**It has no Instance type**, and `manage_properties_set_calculated` is PRO-gated
(and is for arithmetic anyway).

Five encodings were tried against `Workspace.Rig.PrimaryPart` — bare path,
`game.`-prefixed path, relative name, `{path}`, `{instancePath}`, `{__type}` —
all rejected with *"BasePart expected, got string"*. The rejection comes from the
Studio plugin, not the node server.

Consequence for the two instance-typed properties M1 needs:

| Property | Resolution |
|---|---|
| `SurfaceGui.Adornee` | **Not affected.** The spec already requires the SurfaceGui to be built into `PlayerGui` at runtime, so `Adornee = MenuStage.SessionDisplay` is set in Luau. |
| `Model.PrimaryPart` | Set in `MenuPresenceService` on `CharacterAdded`, not on the saved template. More robust: it survives respawns and does not depend on the template being right. |

Neither needs a manual Studio step. **Reading** `CFrame` also has a trap: it
returns a 12-element array, and reading it as a `Vector3` yields **silent zeros**
rather than an error.

---

## Rig readiness for `StarterCharacter` — verified, not yet promoted

| Check | Result |
|---|---|
| R6 parts | all 7 present |
| `Motor6D` joints | **6/6** — `Neck`, `Left/Right Shoulder`, `Left/Right Hip`, `RootJoint` |
| Anchored parts | **none** |
| `Humanoid.RigType` | `R6` |
| `StarterPlayer.StarterCharacter` | does not exist yet |

The rig is structurally valid to promote.

---

## Part B — rig promoted to `StarterCharacter` (COMPLETE)

`Workspace.Rig` → `StarterPlayer` → renamed `StarterCharacter`.

| Check | Result |
|---|---|
| Parts | 13 (7 R6 + 6 accessory handles) |
| `Motor6D` | 6 |
| `Humanoid` / `Animate` | 1 / 1 |
| `Accessory` | 6 |
| `HumanoidRootPart.Anchored` | false |
| Left behind in `Workspace` | **nothing** |

This removes the second dummy from the scene, as the spec requires.

Source realigned with `git mv` to
`dev-src/StarterPlayer/StarterCharacter/Animate.client.luau`;
`kenopsia-dev.project.json` updated. Parity re-verified **15/15**, and
`Animate`'s hash is unchanged at `F388A285E9660C66` — the move preserved content
byte-for-byte.

`AnimSaves` (`ObjectValue` → `ServerStorage.RBX_ANIMSAVES.Rig`) was **left in
place**. It is animation-editor residue and harmless; removing it is a deletion
and deletions are reviewer-gated in this gate.

---

## Part C — `MenuPresenceService` (COMPLETE, transferred)

New `ModuleScript` at
`ServerScriptService.KenopsiaServer.Services.MenuPresenceService`, started from
`Main` after `RoomService` (so `roomOf()` is live before the first character
binds) and after `PlaylistService` (so a run already in flight is not mistaken
for a menu state).

Decisions worth keeping:

- **`KenopsiaMenuActive` is written only here.** Clients read it; they never
  decide it.
- **Original `Humanoid` values are captured at engage time, not hardcoded.**
  Changing the rig's `WalkSpeed` or `JumpPower` in Studio therefore cannot
  silently break `release()`.
- **Re-engaging the same character is an explicit no-op.** Without that guard the
  reconciliation loop would overwrite the saved values with the already-frozen
  ones, and `release()` would restore `WalkSpeed = 0` as though it were original.
- **`PrimaryPart` is set on every `CharacterAdded`**, not on the template, since
  the MCP property layer has no Instance type. Strictly more robust: it survives
  respawns and does not depend on the template being authored correctly.
- **The root is anchored at runtime only** and always unanchored by `release()`.
  It is the only reliable way to stop drift and shoving when up to four
  characters share one collision-free anchor. The rig template stays unanchored,
  which is what the gate requires.
- **A 1 s reconciliation loop re-derives presence.** `RoomService.finishRun()`
  returns a room to `Waiting` without firing an event, and adding a signal to
  `RoomService` is outside this gate's scope. The loop also heals anything the
  event path misses. Safe because engage and release are both idempotent.
- **A room in `Starting` still shows the menu**; the countdown plays over it.
  Only `Playing` releases.

---

## Transfer defect found and fixed — non-ASCII corruption

The first transfer of `MenuPresenceService` **failed parity**, and the failure
mode is worth recording because it is close to invisible:

- identical character count (7,808), identical line count (225);
- the only difference was at index 39, where the source's `§` arrived as `�`.

Cause: PowerShell 5.1's `Invoke-RestMethod` encodes a **string** body as
ISO-8859-1 unless a charset is declared. Every non-ASCII character in every
transfer would have been silently mangled — and because length and line count
survive, nothing but a byte-exact hash would have caught it.

Fix in `tools/weppy.ps1`: the request body is now converted with
`[System.Text.Encoding]::UTF8.GetBytes()` and sent as bytes with
`application/json; charset=utf-8`. **Do not revert this to a string body.**

Re-transferred: **2/2 MATCH**.

A second, smaller wrapper defect surfaced alongside it: `Invoke-Weppy` asserted
`routing.actualPlaceId` unconditionally, but `manage_scripts_validate` returns no
routing block, so every valid result was reported as a routing failure. The
assertion now runs only when a routing block is present.

**Luau validation: 16/16 `valid`, 0 diagnostics.**
**Selene: 0 errors, 46 warnings — unchanged from the §1 baseline.**

---

## Reviewer HOLD/FAIL on §2 A–C — corrections applied

Six findings. Five closed, one requires a manual Studio action.

### 1. Five anchored accessory handles — FIXED

`whitehairaccessory`, `Accessory (Meshes/PENDIENTESMIASMA)`,
`Accessory (Cabello NOVA)`, `Accessory (CAT in head)` and `Accessory (NERD)`
all had `Anchored = true` on their `Handle`. Each is welded to the rig by an
`AccessoryWeld`, so **a single anchored handle anchors the entire character
assembly** — every player would have spawned frozen.

**This was a verification failure, not just a data defect.** Part B checked the
seven R6 parts, found them unanchored, and reported the rig "ready". The six
accessory handles were never examined, yet the conclusion was written as though
the character had been checked. Scope of evidence must match scope of claim.

Now: **0 of 13 BaseParts anchored**, verified by enumerating every `BasePart`
descendant rather than a hardcoded list of the seven.

### 2. `MenuPresenceService` missing from both source-of-truth files — FIXED

It was absent from `kenopsia-dev.project.json` and from
`docs/baseline/dev-script-map.json`. Consequences, exactly as the reviewer
stated: a DEV Rojo build would have produced a `Main` requiring a module Rojo
never creates, and the "full" parity run covered only the original 15 entries —
so **the newest and least-proven file was the one nothing verified**.

The map is now **generated from the `dev-src` tree** instead of hand-maintained,
so it cannot drift from the file set again, and a check that every
project.json `$path` target exists on disk now runs alongside it.

Parity is now **16/16**.

### 3. Both camera markers faced backwards — FIXED

Created with identity rotation, whose `LookVector` is `-Z`, while both targets
lie in `+Z`. Both are now aimed with a `lookAt` basis computed from live
positions:

| Marker | Target | LookVector |
|---|---|---|
| `LandingCamera` | `(134.250, 4.750, 15.125)` | `(-0.072, -0.247, 0.966)` |
| `SessionCamera` | `SessionDisplay (138.9, 5.5, 25.15)` | `(0.000, -0.081, 0.997)` |

The landing target is the measured midpoint between `CharacterAnchor` and the
centroid of `Start`/`Settings`/`Credits`. It lands within **0.05 studs** of the
spec's stated `(134.3, 4.8, 15.1)`, which independently confirms the derivation.

### 4. Jumping state not restored exactly — FIXED

`engage()` now captures
`humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)` with the other
originals, and `release()` restores that captured value. Restoring a hardcoded
`true` is a state *change* disguised as a restore.

### 5. `AnimSaves` — DELETED (reviewer-approved)

`StarterCharacter.AnimSaves` removed. `ServerStorage.RBX_ANIMSAVES` deliberately
retained for later animation work, as directed.

### 6. Template `PrimaryPart` — BLOCKED, needs one manual action

Still `Head`. The runtime correction in `MenuPresenceService` is retained, but
the reviewer also wants the saved template fixed, and **that cannot be done
through MCP at any tier**:

- `manage_properties_set` supports primitives, `Vector3`, `Color3`, `CFrame`,
  `UDim2` and Enum strings — **there is no Instance type**.
- `manage_properties_set_calculated` is PRO-gated and is for arithmetic.
- The string `PrimaryPart` does not occur anywhere in the WEPPY server bundle,
  so no command implements it.
- Six value encodings were attempted; all rejected by the plugin with
  *"BasePart expected, got string"*.

**Manual step required:** in Studio, select `StarterPlayer.StarterCharacter`,
and in Properties set `PrimaryPart` to its `HumanoidRootPart`.

### Verification after corrections

| Check | Result |
|---|---|
| Source parity | **16/16 MATCH** |
| Anchored character parts | **0 of 13** |
| `StarterCharacter.AnimSaves` | removed |
| `LandingCamera` / `SessionCamera` LookVector `+Z` | **both true** |
| Luau validation | **16/16 valid**, 0 diagnostics |
| Selene | 0 errors, 46 warnings — unchanged from baseline |
| Template `PrimaryPart` | **still `Head`** — manual action outstanding |

The six placeholder Parts remain untouched.

---

## Parts D / E / F — `MenuSceneController` (COMPLETE, transferred)

One new client module owns the 3D half of the menu, matching the split the spec
defines: camera, local player hiding, menu lighting. It owns nothing in the 2D
UI. Activation is observed from `KenopsiaMenuActive` and never set by the client.

### D — camera flow

- `Scriptable` takeover; `CameraType`, `CameraSubject` and `FieldOfView` saved
  **once per activation**. Re-capturing after going Scriptable would save our own
  state as the original and make release a no-op that strands the player on a
  scripted camera.
- Landing FOV **48**, session FOV **38**.
- **One tween drives `CFrame` and `FieldOfView` together**, 0.85 s Cubic/InOut.
  That is what keeps it reading as a single camera push rather than a pan with a
  separate zoom riding on top.
- Reduced motion (Animations off **or** Reduce Effects on): 0.15 s fade, hard
  cut — never a shortened tween.
- Full restore on release. If a character exists the camera is handed back to its
  `Humanoid` rather than to a subject captured before the character spawned.
- `reducedMotion()` accepts both `ReduceFlicker` (current key) and
  `ReduceEffects` (the name the §3 UI pass renames it to), so the accessibility
  path survives that rename instead of silently reverting to animated.

### E — other players hidden locally

`LocalTransparencyModifier` on every `BasePart` and `Decal` of every other
player — client-side only, nothing changes on the server. Bound per character
through `DescendantAdded`, so accessories and limbs that stream in after
`CharacterAdded` stay hidden **without a per-frame sweep**, which the performance
rules exclude.

### F — lighting

Client-side `ColorCorrectionEffect` created on engage, destroyed on release
(saturation −0.28, contrast +0.08, brightness −0.02, cool tint).

Three muted practicals under `MenuStage.MenuLights`, palette-aligned, no neon and
no decorative red:

| Lamp | Position | Colour | Brightness / Range |
|---|---|---|---|
| `Lamp_Character` | `(131.5, 9.5, 14.0)` | signal amber `210,169,74` | 1.6 / 24 |
| `Lamp_Landing` | `(139.0, 10.0, 14.0)` | off-white `216,208,190` | 1.2 / 18 |
| `Lamp_SessionWall` | `(139.0, 9.0, 23.0)` | faded denim `96,114,122` | 1.4 / 20 |

**No global time-of-day change.** `Lighting` verified byte-identical to baseline
afterwards: `ClockTime 14.5`, `Brightness 3`, `GlobalShadows true`,
`FogEnd 100000`.

### Tooling hardening

The registration check is now **bidirectional**: every `dev-src` file must appear
in `kenopsia-dev.project.json`, and every project.json `$path` must exist on
disk. That closes the gap class that let `MenuPresenceService` go unregistered —
an unregistered file now fails loudly instead of silently sitting outside the
parity run.

### Verification

| Check | Result |
|---|---|
| Source parity | **17/17 MATCH** |
| Luau validation | **17/17 valid**, 0 diagnostics |
| Selene | 0 errors, 46 warnings — unchanged from baseline |
| Registered files | 17/17, all `$path` targets exist |
| Anchored character parts | **0 of 13** |
| Template `PrimaryPart` | **`HumanoidRootPart`** |
| `Lighting` vs baseline | unchanged |
| Placeholder Parts | **6 present, untouched** |

Manifest: `docs/baseline/dev-instance-tree-after-s2f.csv` (1,028 instances).

---

## Remaining in §2

1. Promote `Workspace.Rig` → `StarterPlayer.StarterCharacter` (move + rename).
   Removes the second dummy from the scene, per spec.
2. `MenuPresenceService` (new server module): park at `CharacterAnchor`, freeze
   movement/jump/rotation, disable collisions, hide nametag, idempotent respawn,
   release on trial/teleport start, `KenopsiaMenuActive` attribute as the
   server-side source of truth, `PrimaryPart` fix on `CharacterAdded`.
3. Local hiding of other players during the personal menu view.
4. Camera flow: `Scriptable`, landing FOV 48 → session FOV 38, 0.85 s
   `Cubic/InOut` tweening CFrame and FOV together; 0.15 s fade + hard cut when
   Animations are off or Reduce Effects is on; full restore on exit.
5. Populate `MenuLights` and apply the menu-only ColorCorrection. No global
   time-of-day change.

Items 2–5 are script work and go into `dev-src/` first, then transfer with
per-file SHA-256 parity. Item 1 is an instance move.

**The six placeholder Parts stay until the landing menu and session wall exist.**
