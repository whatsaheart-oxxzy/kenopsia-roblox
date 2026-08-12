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
