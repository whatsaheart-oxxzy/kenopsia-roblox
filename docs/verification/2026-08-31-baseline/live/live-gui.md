# verify1 — LIVE GUI tree inventory (read-only)

Place: MainGame, placeId **110672791536316** ("Place1"), studioState `edit`.
Date of capture: 2026-08-31.

## 0. METHOD / TOOLING CAVEAT — read this first

The `studio_id` supplied in the task (`946e0bcf-b69e-46f2-877b-e803310070ac`) is **dead**.

- [RUNTIME] `mcp__Roblox_Studio__search_game_tree` → `"No Roblox Studio instances are connected."`
- [RUNTIME] `mcp__Roblox_Studio__list_roblox_studios` → `{"studios":[]}`

So the `Roblox_Studio` proxy bound to no Studio at all. This matches the known
`StudioMCP.exe` re-bind hazard (proxy must be killed after a Studio restart; the
studio_id changes).

I fell back to the **weppy** MCP, which *is* live-attached to the correct place:

- [RUNTIME] `weppy system_info(connection)` → one plugin client
  `clientId ad22f53b-ce31-4d0d-855b-8a82dc878baa`, `targetAlias studio-2`,
  `placeId 110672791536316`, `connectionState "connected"`, `studioState "edit"`,
  `pluginVersion 2.16.2`, `studioVersion 0.736.0.7361346`.

Every `[RUNTIME]` fact below was read through that client with **read-only**
`query_instances` actions (`get` / `children` / `find_child` / `search_name` /
`search_class`). No mutate, no execute_luau, no play test. Nothing was modified.

**Scope limit on the word RUNTIME here:** these are reads of the *edit-mode
DataModel* (StarterGui as authored), not of a running client's PlayerGui. Frames
that a LocalScript builds at runtime would not appear. Where that distinction
changes a conclusion I say so explicitly.

Tier limit: weppy is in **Basic** mode. `search_property` is blocked
([RUNTIME] `"Pro action 'query_instances_search_property' is blocked in Basic mode"`),
so `Visible` was read one instance at a time via `get`.

---

## 1. StarterGui — every ScreenGui and its DisplayOrder

[RUNTIME] `query_instances children game.StarterGui` → `childCount: 3`.
DisplayOrder read per-instance with `get`.

| ScreenGui | ClassName | DisplayOrder | Enabled | IgnoreGuiInset | ResetOnSpawn |
|---|---|---|---|---|---|
| `KenopsiaMachine` | ScreenGui | **50** | false | true | false |
| `FieldPushGui` | ScreenGui | **18** | false | false | false |
| `KenopsiaEmote` | ScreenGui | **18** | false | false | true |

Exactly three. No others.

Two notes worth flagging:

- All three ship **`Enabled = false`**. `KenopsiaMachine` is switched on by
  [SOURCE] `studio-src/ReplicatedFirst/KenopsiaLoading.client.luau:120-121`:
  `local machineGui = playerGui:WaitForChild("KenopsiaMachine", 20)` / `machineGui.Enabled = true`.
- `FieldPushGui` and `KenopsiaEmote` **collide on DisplayOrder 18**. Their relative
  Z order is therefore undefined-by-DisplayOrder and falls back to sibling order.
  Both are single-button docks so it likely does not bite, but it is unintentional-looking.

---

## 2. KenopsiaMachine — ALL direct children

[RUNTIME] `query_instances children game.StarterGui.KenopsiaMachine` → `childCount: 15`.
`Visible` read individually via `get` (15 calls).

| # | Name | ClassName | Visible | ZIndex |
|---|---|---|---|---|
| 1 | `Status` | Frame | false | 1 |
| 2 | `Score` | Frame | false | 1 |
| 3 | `Selection` | Frame | **true** | 1 |
| 4 | `Info` | Frame | false | 1 |
| 5 | `RoundCard` | Frame | false | 1 |
| 6 | `Briefing` | Frame | false | 1 |
| 7 | `JoinCover` | Frame | false | 90 |
| 8 | `CountText` | TextLabel | false | 80 |
| 9 | `Announce` | Frame | false | 60 |
| 10 | `Fader` | Frame | false | 70 |
| 11 | `Scope` | Frame | false | 65 |
| 12 | `HipCross` | Frame | false | 66 |
| 13 | `SettingsPanel` | Frame | false | 82 |
| 14 | `HitMark` | TextLabel | false | 67 |
| 15 | `TouchControls` | Frame | false | 68 |

`Selection` is the only child authored visible — consistent with it being the
first screen shown once the ScreenGui is enabled.

[RUNTIME] `search_class LuaSourceContainer root=game.StarterGui` → **`count: 0`**.
There is **no Script, LocalScript or ModuleScript anywhere under StarterGui**.
All GUI behaviour is driven externally from StarterPlayerScripts.

---

## 3. Does `Warning` exist in KenopsiaMachine? — **NO. CONFIRMED ABSENT.**

This is the headline finding and it is solid.

**Negative evidence, three independent reads:**

1. [RUNTIME] `children game.StarterGui.KenopsiaMachine` → 15 children, listed
   above, **none named `Warning`**.
2. [RUNTIME] `find_child(path=game.StarterGui.KenopsiaMachine, childName="Warning")`
   → `{"found": false, "searchedName": "Warning"}`.
3. [RUNTIME] `search_name(query="Warning", root=game, maxResults=50)` → `count: 1`,
   and the single hit is **not a GUI object**:
   `game.SoundService.KenopsiaAudio.SFX.Warning`, `className: "Sound"`.

So in the entire edit-time DataModel the only `Warning` is a Sound.

**Consumers that will therefore block.** Both cited lines verified verbatim:

- [SOURCE] `studio-src/ReplicatedFirst/KenopsiaLoading.client.luau:122`:
  `		local warning = machineGui:WaitForChild("Warning", 10)`
  Guarded by `if warning then warning.Visible = true end` on line 123, so it
  degrades rather than errors — but it costs a **full 10 s** first, and it sits
  *before* the `preloadAsync` critical-asset block that follows (line 126 onward,
  `local criticalAssets = {}`). The loading screen therefore holds ~10 s longer
  than intended before it even begins preloading.

- [SOURCE] `studio-src/StarterPlayer/StarterPlayerScripts/KenopsiaClient.client.luau:2959`:
  `local warningFrame = machine:WaitForChild("Warning", 10)`
  This one is worse. It is a **top-level statement** in the LocalScript's main
  chunk (column 0, under the banner `-- CONTENT WARNING + SETTINGS ---`), and the
  file is **3306 lines** long. Every statement after 2959 — including the settings
  panel wiring on 2960+ — is therefore deferred by the full 10 s timeout.
  The very next line, `local settingsPanel = machine:WaitForChild("SettingsPanel", 10)`,
  resolves instantly (SettingsPanel exists, table §2 row 13), so the 10 s is
  attributable to `Warning` alone.

Net: **two separate 10 s stalls**, one in ReplicatedFirst and one in
StarterPlayerScripts. They are on different scripts so they overlap in wall-clock
rather than summing to 20 s, but both fire on every join.

**Children of `Warning` / `Btn_CONTINUE`:** not applicable — the parent does not
exist, so it has no children.

[RUNTIME] `search_name(query="Btn_*", root=game.StarterGui)` → 10 hits
(`Btn_READY`, `Btn_SETTINGS`, `Btn_CLOSE`, `Btn_FIRE`, `Btn_SCOPE`, `Btn_ZOOM`,
`Btn_PUNCH`, `Btn_CROUCH`, `Btn_SCAN`, `Btn_EAT`). **`Btn_CONTINUE` is not among
them and does not exist anywhere in StarterGui.**

**Nothing in the repo creates `Warning`.** Exhaustive ripgrep of `"Warning"` over
`studio-src/` returns 10 hits and *every GUI-frame one is a read*:

- [SOURCE] `MachineLayout.client.luau:32`:
  `local FULLSCREEN = { "Selection", "Info", "Status", "RoundCard", "Briefing", "Score", "Announce", "Warning" }`
- [SOURCE] `MachineLayout.client.luau:371`:
  `local GROUPS = { "Warning", "SettingsPanel", "HunterLookSetup", "Briefing", "Info" }`
- [SOURCE] `MachineLayout.client.luau:453`:
  `		machine:FindFirstChild("Warning") and machine.Warning:FindFirstChild("Btn_CONTINUE", true),`
- [SOURCE] `MachineLayout.client.luau:619`: `	Warning = "Btn_CONTINUE",` (in `local PRIMARY`, gamepad focus targets)
- [SOURCE] `MainMenu.client.luau:1529`: `	local warning = m:FindFirstChild("Warning")`
- [SOURCE] `KenopsiaClient.client.luau:2977`: `	local btn = warningFrame:FindFirstChild("Btn_CONTINUE")`

No `Instance.new` and no clone ever produces a `Warning` frame. Line 32 is the
telling one: `FULLSCREEN` names **8** frames, and **7 of the 8 exist live**
(`Selection`, `Info`, `Status`, `RoundCard`, `Briefing`, `Score`, `Announce`).
`Warning` is the **only** member of that list with no live counterpart. That is
the signature of an asset that was deleted from the place, not of one that was
never authored.

Corroborating: [SOURCE] `KenopsiaClient.client.luau:2975-2976` carries a comment
describing exactly the failure being defended against —
`-- screen with a CONTINUE that did nothing. Clicks in that window landed` /
`-- on a handler that did not exist yet, which reads as a frozen button.`
Someone previously debugged this screen; the frame has since gone missing.

**BONUS FINDING — a second expected frame is also gone.**
[RUNTIME] `search_name(query="HunterLookSetup", root=game)` → `count: 0`.
`HunterLookSetup` is referenced by [SOURCE] `MachineLayout.client.luau:371`
(`GROUPS`) and `:617` (`HunterLookSetup = "Track"` in `PRIMARY`) but exists
nowhere in the DataModel.

**NEEDS_RUNTIME.** One residual uncertainty, stated honestly: the known hazard is
that `studio-src/` is behind the live place for `KenopsiaClient` specifically. I
read the *repo* copies of KenopsiaClient / MachineLayout, so the live client code
could differ from the quotes above. What that cannot change is the `[RUNTIME]`
half: `Warning` is absent from the live edit-time StarterGui, and there is no
script under StarterGui to build it. The observation that would fully settle it:
**start a play test and inspect `Players.<name>.PlayerGui.KenopsiaMachine` for a
`Warning` child, and read the live source of `KenopsiaClient` around line 2959.**
If a runtime-built `Warning` appeared in PlayerGui, the stall would be a race
rather than a guaranteed timeout. I could not check this without violating the
read-only constraint (play test + execute_luau are forbidden here).

---

## 4. Results / podium presentation frames

Checked against the requested name list. `search_name(root=game)` used for the
names absent from the direct-child listing.

| Requested name | Exists? | Evidence |
|---|---|---|
| `Score` | **YES** — Frame, Visible false | [RUNTIME] direct child of KenopsiaMachine |
| `Announce` | **YES** — Frame, Visible false, ZIndex 60 | [RUNTIME] direct child |
| `Status` | **YES** — Frame, Visible false | [RUNTIME] direct child |
| `RoundCard` | **YES** — Frame, Visible false | [RUNTIME] direct child |
| `Briefing` | **YES** — Frame, Visible false | [RUNTIME] direct child |
| `Selection` | **YES** — Frame, Visible **true** | [RUNTIME] direct child |
| `Report` | **NO** | [RUNTIME] `search_name("*Report*", root=game)` → `count: 0` |
| `ShiftReport` | **NO** | same search — zero `*Report*` matches anywhere |
| `Podium` | **NO GUI** | [RUNTIME] `search_name("*Podium*", root=game)` → `count: 1`, and it is `game.ServerScriptService.KenopsiaServer.Services.Podium`, `className: "ModuleScript"` — server logic, not a frame |
| `Winner` | **NO** | [RUNTIME] `search_name("*Winner*", root=game)` → `count: 0` |

Reading: the **6 in-round / pre-round** frames all exist. The **4 end-of-round
presentation** names (Report, ShiftReport, Podium-as-GUI, Winner) **all do not**.
There is a server-side `Podium` service with no client frame to render into.
Whether `Score` + `Announce` are meant to carry the results presentation on their
own is a design question I cannot answer from the tree alone — but if a dedicated
podium/shift-report screen was ever planned, **no GUI for it exists in this place**.

---

## 5. Any "return to menu" button? — **NONE.**

[RUNTIME] `search_class(className="GuiButton", root=game.StarterGui, includeSubclasses=true)`
→ `count: 19`. That is the complete button inventory of the place:

```
KenopsiaMachine.Info.ControlsWindow.ArrowL.Hit          TextButton
KenopsiaMachine.Info.ControlsWindow.ArrowR.Hit          TextButton
KenopsiaMachine.Info.Btn_READY                          TextButton
KenopsiaMachine.Info.Btn_SETTINGS                       TextButton
KenopsiaMachine.SettingsPanel.Row_UISOUND.Hit           TextButton
KenopsiaMachine.SettingsPanel.Row_MUSIC.Hit             TextButton
KenopsiaMachine.SettingsPanel.Row_REDUCEFLICKER.Hit     TextButton
KenopsiaMachine.SettingsPanel.Row_CRT.Hit               TextButton
KenopsiaMachine.SettingsPanel.Row_SHAKE.Hit             TextButton
KenopsiaMachine.SettingsPanel.Btn_CLOSE                 TextButton
KenopsiaMachine.TouchControls.Btn_FIRE                  TextButton
KenopsiaMachine.TouchControls.Btn_SCOPE                 TextButton
KenopsiaMachine.TouchControls.Btn_ZOOM                  TextButton
KenopsiaMachine.TouchControls.Btn_PUNCH                 TextButton
KenopsiaMachine.TouchControls.Btn_CROUCH                TextButton
KenopsiaMachine.TouchControls.Btn_SCAN                  TextButton
KenopsiaMachine.TouchControls.Btn_EAT                   TextButton
FieldPushGui.Dock.HeadbuttButton                        TextButton
KenopsiaEmote.DanceButton                               TextButton
```

**By name:** no `Back`, no `Menu`, no `Exit`, no `Leave`, no `Quit`, no `Return`.

**By text:** the only plausible candidate is `Btn_CLOSE`, and it is not one.
[RUNTIME] `get game.StarterGui.KenopsiaMachine.SettingsPanel.Btn_CLOSE` →
`"Text": "CLOSE"`, `Visible: true`, `ZIndex: 82`, parented to `SettingsPanel`.
It closes the settings overlay, not the session. Its sibling set is the
`Row_*` settings rows.

**Script/LocalScript siblings:** none, for any button.
[RUNTIME] `search_class LuaSourceContainer root=game.StarterGui` → `count: 0`.
No button anywhere in StarterGui has a Script or LocalScript sibling; every
handler is bound remotely from StarterPlayerScripts.

So: **there is no way, from any authored GUI in this place, for a player to
return to the main menu.** Given the menu is a separate place
(`Kenopsia_DEV`, placeId 129909297895850), returning would require a
`TeleportService` call, and no button exists to trigger one. Whether some
non-GUI path (keybind, chat command, auto-teleport on round end) covers this is
**NEEDS_RUNTIME** — the settling observation is a grep of the live
`KenopsiaClient` / server code for `TeleportService` plus a play test to round
end to see what happens.

---

## 6. Workspace authoring rigs + SpawnLocation

[RUNTIME] `query_instances children game.Workspace` → `childCount: 16`.

**All ten requested rigs are still present.** Every one is a `Model` and a direct
child of Workspace:

| Rig | Present | ClassName |
|---|---|---|
| `Anim_PushFall` | **YES** | Model |
| `Player_Rig` | **YES** | Model |
| `Headbutt` | **YES** | Model |
| `Injured Walking` | **YES** | Model |
| `Death Fall` | **YES** | Model |
| `Dancing` | **YES** | Model |
| `Rifle Aiming Idle` | **YES** | Model |
| `Sneak Walk` | **YES** | Model |
| `Zombie Crawl` | **YES** | Model |
| `Fall Flat` | **YES** | Model |

Plus an **eleventh authoring rig not on the request list**: `MF_Shredder` (Model).

The remaining five Workspace children are the real content:
`CanteenProtocol` (Folder), `Dead Zone` (Folder), `Bird Hunting` (Folder) — the
three enabled trials — plus `Terrain` and `Camera`.

So Workspace is **11 stray authoring rigs vs. 3 trial folders**. These rigs are
Mixamo/animation scratch models left in the shipping place; they replicate to
every client on join.

### SpawnLocation — **DOES NOT EXIST**

- [RUNTIME] not present among the 16 direct children of Workspace (listed above).
- [RUNTIME] `search_class(className="SpawnLocation", root=game.Workspace, includeSubclasses=true)`
  → **`count: 0`**.

There is no SpawnLocation anywhere in Workspace at edit time. Character spawn
must therefore be entirely script-driven (or falling back to Roblox's default
origin-area spawn). Not necessarily a bug for a game that teleports players into
trials, but it is worth knowing that nothing in the place declares a spawn point.

---

## Summary of findings, ranked

1. **`KenopsiaMachine.Warning` does not exist** (triple-confirmed live). Causes a
   10 s `WaitForChild` timeout in `KenopsiaLoading.client.luau:122` *before*
   asset preloading, and a second 10 s timeout at top-level scope in
   `KenopsiaClient.client.luau:2959` that defers the remaining ~350 lines of that
   script. `Btn_CONTINUE` likewise absent. Nothing in the repo creates either.
   It is the only missing member of MachineLayout's 8-name `FULLSCREEN` list.
2. **`HunterLookSetup` also missing** — second frame referenced by MachineLayout
   with no live counterpart.
3. **No end-of-round presentation GUI**: Report / ShiftReport / Podium / Winner
   all absent; a server-side `Podium` ModuleScript exists with nothing to draw into.
4. **No return-to-menu affordance anywhere** in 19 buttons.
5. **11 authoring rigs shipping in Workspace** alongside only 3 trial folders.
6. **No SpawnLocation** in Workspace.
7. **Zero scripts under StarterGui** — all GUI wiring is remote.
8. `FieldPushGui` and `KenopsiaEmote` share `DisplayOrder = 18`.
9. **Tooling:** the `Roblox_Studio` MCP proxy is bound to nothing; supplied
   `studio_id` is stale. Use weppy (`clientId ad22f53b-…`) or restart the proxy.
