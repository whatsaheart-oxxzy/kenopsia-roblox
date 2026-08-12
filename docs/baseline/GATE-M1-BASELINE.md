# Gate M1 §1 — Kenopsia_DEV source and safety gate

Read-only capture. **Nothing in `Kenopsia_DEV` was created, modified or
destroyed.** No script was written; every call was a read.

Scope: `Kenopsia_DEV` only. `KenopsiaMainGame` was not touched and its
`default.project.json` is unchanged, per Gate M1 §1.1.

---

## 1. Preflight — PASS

| Check | Result |
|---|---|
| PlaceId | `129909297895850` ✅ |
| Universe / GameId | `10640788131` ✅ — read from `game.GameId`, matches MainGame's universe |
| Studio mode | **edit** ✅ |
| Studio version | `0.734.0.7340915` |
| Plugin clients | **1** ✅ (`studio-2`) — MainGame window closed, so routing is unambiguous |
| MCP instances | **1** ✅ |
| Git tree | clean ✅ |

Automated by `tools/weppy.ps1`:

```powershell
. .\tools\weppy.ps1
Test-KenopsiaPreflight -PlaceId 129909297895850 -ExpectedGameId 10640788131 -RepoRoot .
```

**Run this before every DEV transfer.** It fails closed — a dirty tree, a second
Studio window, Play mode, or the wrong universe all abort it.

---

## 2. Source mirror — 15/15 parity

Every script in the place was mirrored into `dev-src/` and then **re-fetched**
from Studio and compared, so the check verifies the round trip rather than
trusting the write.

| File | Lines | SHA-256 (first 16) |
|---|---:|---|
| `ReplicatedStorage/Kenopsia/Shared/Config/GameConfig.luau` | 33 | `05B9A976909E7444` |
| `ServerScriptService/KenopsiaServer/Main.server.luau` | 12 | `D447B84002E5D6F6` |
| `.../Services/PartyRegistry.luau` | 121 | `541AEDC7A7529766` |
| `.../Services/PlaylistService.luau` | 237 | `8FCF10E2548D69BE` |
| `.../Services/RoomService.luau` | 361 | `7EBBA9C73F655E84` |
| `.../Services/TrialCanteen.luau` | 110 | `CDBA1333463A39C8` |
| `.../Services/TrialQuality.luau` | 96 | `4F353D26E17E1972` |
| `.../Services/TrialTarget.luau` | 70 | `FBAA57DC538B60BF` |
| `StarterPlayer/.../KenopsiaClient/Controllers/MenuController.luau` | **1087** | `AD69706F6B3AD933` |
| `StarterPlayer/.../KenopsiaClient/Controllers/TrialController.luau` | 308 | `E99954185B3FE307` |
| `StarterPlayer/.../KenopsiaClient/Main.client.luau` | 43 | `928C80D9487E66D0` |
| `StarterPlayer/.../KenopsiaClient/UI/Motion.luau` | 62 | `7FC5F2B4F646EA25` |
| `StarterPlayer/.../KenopsiaClient/UI/SoundBank.luau` | 101 | `03B6E5F8ADB0962C` |
| `StarterPlayer/.../KenopsiaClient/UI/Theme.luau` | 111 | `70B0FF453DACB3D8` |
| `Workspace/Rig/Animate.client.luau` | 586 | `F388A285E9660C66` |

**PARITY: 15/15 MATCH.** All files LF-only; **no CR byte anywhere**, so no
BOM/CRLF normalisation was needed or applied.

`MenuController` at 1,087 lines confirms the spec's split target
(`MenuController` / `MenuSceneController` / `MenuOverlayController` /
`SessionWallController`).

Path map: `docs/baseline/dev-script-map.json`.
Rojo project: `kenopsia-dev.project.json` — leaf-only, `servePlaceIds`
restricted to `129909297895850`. Every container is `$className` with **no
`$path`**, so Rojo can never own a content folder and delete its children.
Rojo remains disconnected; transfers go through the controlled direct path.

---

## 3. Instance baseline

Full tree (998 instances): `docs/baseline/dev-instance-tree.csv`.

```
Workspace          KenopsiaRuntime{ActiveMap, ActiveEffects, Debug}, Audios,
                   Terrain, CameraPart, SpawnLocation, Baseplate, Camera,
                   Floor, Wall, Rig, MainMenuWAll, Start, Settings, Credits
StarterGui         KenopsiaGui{Components, Templates, TerminalScreen,
                   Backdrop, Monitor}, KenopsiaCursor{Cursor}
Lighting           Sky, SunRays, Atmosphere, Bloom, DepthOfField
MaterialService    18 x RETRO_*, plus "Wall Real", "Floor Real", "Ceiling Real"
ServerStorage      RBX_ANIMSAVES{Rig}
```

### 3.1 `Workspace.CameraPart` — currently a solid visible box

| Property | Current | Spec §2 target |
|---|---|---|
| `Transparency` | **0** | 1 |
| `Anchored` | true | true ✅ |
| `CanCollide` | **true** | false |
| `CanTouch` | **true** | false |
| `CanQuery` | **true** | false |
| `CastShadow` | **true** | no visible shadow |
| `Position` | `(135.2, 8, 2.4)` | — matches the spec's `LandingCamera` position exactly |
| `Size` | `(4, 1, 2)` | — |

It is a visible, colliding, shadow-casting block sitting in the scene at head
height. A player can walk into it today.

### 3.2 `Workspace.Rig` — R6, three defects against the spec

Children: `Head`, `Torso`, `Left Arm`, `Right Arm`, `Left Leg`, `Right Leg`,
`Humanoid`, `HumanoidRootPart`, `Animate` (LocalScript), `Shirt`, `Pants`,
`Body Colors`, `AnimSaves` (ObjectValue), **6 Accessories**.

`Humanoid.RigType = R6`, `WalkSpeed 16`, `JumpPower 50`, `DisplayName` empty.

| Defect | Current | Spec §2 requirement |
|---|---|---|
| **PrimaryPart** | `Head` | **`HumanoidRootPart`** |
| **Anchoring** | `Torso.Anchored = **true**` (Head and HumanoidRootPart false) | *"kein Körperteil dauerhaft verankert"* |
| **AnimSaves** | `ObjectValue` → `ServerStorage.RBX_ANIMSAVES.Rig` | animation-editor residue, not shippable |

An anchored `Torso` on a `StarterCharacter` would freeze the character's physics
outright. Both must be corrected before the rig is promoted.

### 3.3 Menu button parts — **three found, spec says six**

| Part | Anchored | Transparency | Color | Size |
|---|---|---:|---|---|
| `Workspace.Start` | **false** | 0 | `(163,162,165)` | `(5, 1, 0.5)` |
| `Workspace.Settings` | **false** | 0 | `(163,162,165)` | `(5, 1, 0.5)` |
| `Workspace.Credits` | **false** | 0 | `(163,162,165)` | `(5, 1, 0.5)` |

All three are unanchored and would fall on the first physics step. They match the
spec's description of *"unbefestigte weiße Button-Parts"* — but there are **three
of them, not six**. `Workspace.MainMenuWAll` contains only four Parts, **all
named `Wall`** (identically named, therefore unaddressable by index — the same
trap as MainGame's eight identical `Plate` parts).

**Discrepancy flagged, not assumed away.** Either the count in the spec is
approximate, or three further button parts are expected and absent. Confirm
before removal so nothing is deleted that the spec still wants.

### 3.4 `TerminalScreen` — renders nowhere today

`StarterGui.KenopsiaGui.TerminalScreen` is a `SurfaceGui` with:

| Property | Current | Spec §3 target |
|---|---|---|
| `Adornee` | **empty** | `SessionDisplay` |
| Parent | `StarterGui` | **`PlayerGui`** |
| `PixelsPerStud` | **256** | ~72 |
| `AlwaysOnTop` | false | false ✅ |
| `Active` | true | true ✅ |
| `Enabled` | true | false until after the camera move |

A `SurfaceGui` with no `Adornee` draws nothing, so the wall terminal is currently
invisible regardless of its contents. `SessionDisplay` does not exist yet.

### 3.5 Absent — to be created by M1

`SessionDisplay`, `LandingCamera`, `SessionCamera`, `CharacterAnchor`,
`MenuStage`, `MenuLights`. None exist. `CameraPart` is the only camera marker
present and already sits at the landing position.

### 3.6 Materials — the "Real" variants are live

`Wall Real`, `Floor Real` and `Ceiling Real` are **`MaterialVariant`s in
`MaterialService`**, not Parts — which is why an instance-name search reports
them absent. They are **actively applied**:

- `Workspace.Wall` → `Material = Brick`, `MaterialVariant = "Wall Real"`
- `Workspace.Floor` → `Material = Ground`, `MaterialVariant = "Floor Real"`

Disabling them therefore means **reassigning those parts**, not just editing the
variants. Eighteen `RETRO_*` variants already exist and cover the PSX palette the
spec asks for — e.g. `RETRO_Concrete_WallA` for the wall, `RETRO_Asphalt_Old` for
the floor.

### 3.7 Horror layer — located

All four named removals sit under one parent,
`StarterGui.KenopsiaGui.Monitor.ScreenArea.Overlay`:
`RedWash`, `BloodDrips`, `BleedTop`, `BleedBottom`.

### 3.8 Lighting

`ClockTime 14.5`, `Brightness 3`, `GlobalShadows true`, `FogEnd 100000`,
`Ambient (70,70,70)`, plus `Sky`, `SunRays`, `Atmosphere`, `Bloom`,
`DepthOfField`. The spec forbids a global time-of-day change, so the PSX look
must come from local lamps and a menu-only client-side ColorCorrection.
`Lighting.Technology` was not readable at Basic tier.

---

## 4. `DEV_ONLY` asset flags — Gate M1 §1.5

`Workspace.Rig` wears six Accessories plus a `Shirt` and `Pants`. These are
catalog/user-created appearance assets with **no ownership or licence record in
this project**:

| Instance | Class |
|---|---|
| `Accessory (NERD)` | Accessory |
| `Accessory (CAT in head)` | Accessory |
| `Accessory (Soulers Keychain)` | Accessory |
| `Accessory (Meshes/PENDIENTESMIASMA)` | Accessory |
| `whitehairaccessory` | Accessory |
| `Accessory (Cabello NOVA)` | Accessory |
| `Shirt`, `Pants` | Shirt / Pants |

All eight are marked **`DEV_ONLY`** in `docs/assets/ASSET-LEDGER.md`. They are
acceptable inside `Kenopsia_DEV` while it is universe-limited. Before any public
release, ownership must be evidenced or the parts replaced. `Shirt` and `Pants`
carry the same exposure as the accessories and are included deliberately — the
spec named only accessories, but clothing is the same class of asset.

---

## 5. Verdict

| Gate M1 §1 requirement | State |
|---|---|
| 1.1 Separate DEV source tree, MainGame project untouched | **DONE** — `kenopsia-dev.project.json` + `dev-src/`, `servePlaceIds` restricted to DEV |
| 1.2 All DEV scripts mirrored, SHA-256 compared | **DONE** — 15/15 MATCH |
| 1.3 GUI / camera / rig / scene baseline manifest | **DONE** — §3 above + `dev-instance-tree.csv` |
| 1.4 Repeatable pre-transfer preflight | **DONE** — `tools/weppy.ps1`, fails closed |
| 1.5 Rig accessories marked `DEV_ONLY` | **DONE** — 8 instances, ledger updated |

**Gate M1 §1: PASS. No DEV mutation performed.**

Carried into §2, for reviewer confirmation first:

1. The **three vs six** button-part discrepancy (§3.3).
2. `Workspace.Rig` needs `PrimaryPart` → `HumanoidRootPart` and
   `Torso.Anchored` → false before it can serve as `StarterCharacter` (§3.2).
3. Disabling the "Real" materials requires reassigning `Workspace.Wall` and
   `Workspace.Floor` to `RETRO_*` variants, not only touching the variants (§3.6).
