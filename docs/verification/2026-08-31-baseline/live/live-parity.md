# LIVE-vs-MIRROR parity — MainGame placeId 110672791536316

Read-only pass. Live datamodel reached via the **weppy** bridge (clientId ad22f53b…, targetAlias
studio-2, placeId 110672791536316, studioState "edit"). The `Roblox_Studio` MCP proxy named in the task
(studio_id 946e0bcf-…) returned `{"studios":[]}` — NOT USABLE this session; see Caveats.

## Counting convention

weppy `lineCount` counts the empty line after a final newline. Verified per file by reading the tail:
e.g. Contexts live 243-246 = `"end\n\nreturn Contexts\n"` (line 246 empty) → 245 real lines.
"live real" below is the artifact-corrected count and is what the delta uses.

## Parity table

| script | live raw | live real | mirror | delta | verdict |
|---|---|---|---|---|---|
| StarterPlayerScripts.KenopsiaClient | 4125 | **4124** | 3306 | **+818** | **DRIFT — live far ahead** |
| StarterPlayerScripts.SocialClient | 86 | 86 | 86 | 0 | line-count match |
| StarterPlayerScripts.LightGuard | 71 | 70 | 70 | 0 | line-count match |
| StarterPlayerScripts.MachineLayout | 729 | **728** | 695 | **+33** | **DRIFT — live ahead** |
| ReplicatedFirst.KenopsiaLoading | 286 | **285** | 163 | **+122** | **DRIFT — live ahead** |
| Services.Profiles | 663 | 663 | 663 | 0 | line-count match |
| Services.MachineFlow | 1515 | 1514 | 1514 | 0 | line-count match |
| Services.Telemetry | 152 | 151 | 151 | 0 | line-count match |
| Services.RoomService | 646 | 645 | 645 | 0 | line-count match |
| Services.Contexts | 246 | 245 | 245 | 0 | line-count match |

All 10 mirror files exist and end with a trailing newline (`awk END{print NR}` equals `wc -l`).

**Equal line count is NOT proof of equal content** — only counts were compared. NEEDS_RUNTIME for
byte-equality: a full `get_source` plus diff per file.

Corroborating drift signal: live KenopsiaClient uses **CRLF** (`"end\r\n\r\n"` at lines 4123-4125) while
the Rojo-synced modules (Contexts, MachineFlow, RoomService) are **LF**. Consistent with KenopsiaClient
having been hand-edited inside Studio rather than pushed from the repo.

## Existence diffs (live vs mirror)

LIVE-ONLY (exist in the place, no mirror file):

- `game.StarterPlayer.StarterPlayerScripts.MobileProbe` (LocalScript)
- `game.StarterPlayer.StarterPlayerScripts.IceTheme` (ModuleScript)
- `game.ServerScriptService.KenopsiaServer.Services.FieldPush` (ModuleScript) — live Services = 33, mirror = 32

MIRROR-ONLY (file on disk, absent from the live place):

- `studio-src/StarterPlayer/StarterPlayerScripts/MainMenu.client.luau`
- `studio-src/StarterPlayer/StarterPlayerScripts/SimulationGrade.client.luau`

Both ARE mapped in default.project.json, so a Rojo sync would create them in MainGame.

Live StarterPlayerScripts = 15 children; ReplicatedFirst = 1 child (KenopsiaLoading only).

## FINDING: the Rojo project does not cover the mirror

`default.project.json` (servePlaceIds [110672791536316]) maps only a subset of the files on disk.

StarterPlayerScripts — file exists but **NOT MAPPED** (Rojo would never push or pull them):
`SocialClient`, `LightGuard`, `AbortScreen`, `GradeDirector`, `SonarClient`, `RunnerClient`

Services — file exists but **NOT MAPPED** (26 of 32 mapped):
`Badges`, `EmoteService`, `Lobby`, `Profiles`, `SoloExit`, `Telemetry`

Consequence: for **Profiles, Telemetry, SocialClient and LightGuard** — four of the ten scripts under
verification — the mirror file is not a sync artifact at all. Their line counts match live today by
coincidence or manual copying, not because any tool keeps them in step. Nothing would detect them drifting.

## Symbol table — LIVE datamodel, 115 scripts searched, case-insensitive

| symbol | in LIVE client code? | live hits (file:line) |
|---|---|---|
| `profilestate` | **NO — server only** | Services.Profiles:178 `kind = "profilestate",` |
| `shiftreport` | YES | **SocialClient:78** `if type(packet) ~= "table" or packet.kind ~= "shiftreport" then return end`; (shared) Rules.Pacing:178; (server) MachineFlow:1336, 1352 |
| `PromptGameInvite` | YES | SocialClient:15, **:65** `local sent, err = pcall(SocialService.PromptGameInvite, SocialService, player)`, :67 |
| `RematchAccepted` | **NO — server only** | MachineFlow:505 `Telemetry.funnel(plr, "KenopsiaRetention", 5, "RematchAccepted")` |
| `MobileBlackScreen` | YES | **LightGuard:63** `event = "MobileBlackScreen",`, LightGuard:7; (server) Telemetry:10, :28 |
| `podium` | YES | KenopsiaClient:1133-1140, 1151, 1200, 3203-3240, **3692** `if p.kind == "podium" then`, 3693, 3993, 4112, 4116 (100-hit cap reached) |
| `Btn_CONTINUE` | YES | KenopsiaClient:**3769** `local btn = warningFrame:FindFirstChild("Btn_CONTINUE")`; MachineLayout:492, 651 |
| `Warning` | YES | KenopsiaClient:**3751** `local warningFrame = machine:WaitForChild("Warning", 10)`, :3781; MachineLayout:34, 410, 492, 651; IceTheme:19; RunnerClient:161; TrialClients.sorting:352, 388 |
| `BackToMenu` | **NO — absent from the ENTIRE place** | 0 matches across all 115 scripts; also 0 in studio-src and dev-src |
| `TeleportAsync` | **NO — server only** | Services.SoloExit:104 `TeleportService:TeleportAsync(SoloExit.MENU_PLACE_ID, { plr })` |

### MISSING from live client code

`profilestate`, `RematchAccepted`, `TeleportAsync` (all three exist server-side only) and
**`BackToMenu`, which does not exist anywhere in MainGame or in either repo dir.**

## FINDING: the shift-report beat ships dark

MachineFlow lines 1336-1339 (live, verbatim):

> `-- FireClient per seat). "shiftreport" is NOT in the client's dispatch`
> `-- yet and an unknown kind renders NOTHING, so this ships dark; the`
> `-- HOLD is real, though: the session grows by Pacing.Timing.ShiftReport`
> `-- (5 s).`

Confirmed against live client code: `shiftreport` does NOT appear in KenopsiaClient at all. The only
client consumer is SocialClient:78, which uses the packet solely as a trigger to prompt a game invite —
it renders no report UI. So the session holds roughly 5 s on a screen showing nothing. The
server-authored comment matches the observed client code.

## FINDING: stale client copies inside ServerStorage

Two full LocalScript copies of the client shipped into ServerStorage:

- `game.ServerStorage.KenopsiaUI_Backup_20260828_191906.StarterPlayerScripts.{KenopsiaClient, MachineLayout}`
- `game.ServerStorage.KenopsiaUI_Adjustment_Backup_20260829_063909.KenopsiaClient`

They pollute every game-wide grep (they carry `podium`, `Btn_CONTINUE` etc. at *different* line numbers)
and are dead weight in the place file. Neither is in the mirror.

## Caveats / NEEDS_RUNTIME

1. The task's `Roblox_Studio` studio_id `946e0bcf-b69e-46f2-877b-e803310070ac` is **dead**:
   `list_roblox_studios` returned `{"studios":[]}`, so `script_grep` / `script_read` /
   `search_game_tree` all failed. RobloxStudioBeta.exe (PID 14776) and StudioMCP.exe (PID 25548) are both
   running, so the proxy has lost its binding — per the project's own note, StudioMCP.exe must be killed
   so it re-binds (the studio_id will change). All live evidence here came from the weppy bridge instead.
   Not fixed — this was a read-only pass.
2. Line-count parity is not content parity. No byte-diff was performed.
3. All findings are Edit-datamodel source reads. Nothing was play-tested; no GUI instance was inspected.
   `Btn_CONTINUE` and `Warning` are resolved by name at runtime
   (`machine:WaitForChild("Warning", 10)`, `FindFirstChild("Btn_CONTINUE", true)`) — whether those GUI
   objects actually exist under the Machine is NEEDS_RUNTIME: inspect the Machine ScreenGui/Frame tree,
   or play-test and watch for the 10 s WaitForChild timeout returning nil.
4. Symbol searches covered MainGame only. Kenopsia_DEV (129909297895850 / dev-src) was not connected;
   `BackToMenu` could exist there, though a disk grep of dev-src found none.
