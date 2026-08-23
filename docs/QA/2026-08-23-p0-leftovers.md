# QA — P0 leftovers: #5 P0.3, #6 P0.4 (code part), #7 P0.5 (2026-08-23)

Built OFFLINE in a git worktree, no Studio, no place touched. Everything below is repo-side;
the live checks at the end are for the lead after the next push (parity check as usual).

## #5 P0.3 — Pacing + audio quick wins (the open remainder)

| Item | Change | File |
|---|---|---|
| Lobby roulette hold | `Pacing.Timing.LobbyReveal = 6.4` (new row in the existing `Pacing.Timing` table, Lua-5.1 portable, comment names the source); `MachineFlow.preFlow` waits `Pacing.Timing.LobbyReveal or 6.4` instead of the literal `task.wait(6.4)` | `Shared/Rules/Pacing.luau`, `Services/MachineFlow.luau` |
| Unknown `sfx()` names | `KenopsiaClient.sfx(name)`: when neither a pool nor a Sound resolves, or the Sound's `SoundId` is empty, it warns ONCE per name (`sfxWarned` set): `[sfx] unknown name: <name>` / `[sfx] empty SoundId: <name>`. Still silent when `UiSound` is off or the `KenopsiaAudio.SFX` folder is missing (those are not name errors). Hunk is 7 lines; nothing else in the file touched | `StarterPlayerScripts/KenopsiaClient.client.luau` |
| Test | `tests/rules.lua`: `Pacing.Timing.LobbyReveal is 6.4 s (the lobby roulette hold)` | `tests/rules.lua` (85 checks) |

Not a boot-time walk over every literal: the once-per-name warn at call time covers it (the
brief allowed either). `TrialClientKit.kit.sfx` is unchanged (MP-05 D6 says silent on a
missing name — the trial kit has its own contract).

## #6 P0.4 — chat window hidden while a trial runs (code part only)

Decision of record (user, 22.08.2026, `docs/MASTERPLAN.md` §8): default chat ON in the
lobby / Machine screens, OFF while `KenopsiaActiveTrial ~= ""`.

Implemented in **`UiFx.client.luau`** (block "5) the Roblox chat window"), not in
`SimulationGrade.client.luau`: SimulationGrade's `update()` is gated by the SIM FILTER
setting (`KenopsiaSimFilter`) and by its Lighting snapshot, so a chat toggle there would follow
a look setting the player can switch off mid-trial. UiFx is the UI-side script, already has
`player`, and its observer is independent of every setting.

* `player:GetAttributeChangedSignal("KenopsiaActiveTrial")` + `task.defer` at boot.
* Non-empty → `ChatWindowConfiguration.Enabled = false` and `ChatInputBarConfiguration.Enabled = false`; empty → both `true`.
* Edge-triggered (`chatHidden` latch): the boot pass does not write anything while no trial runs, so a place whose chat is configured off stays off in the lobby.
* Whole write in `pcall`; the config objects are looked up with `FindFirstChildOfClass`, so a legacy-chat place without them is a no-op.
* No new script instance — the lead has nothing to create in the place; the deletions of P0.4 (Baseplate, gears, lamps, plates, archives) remain the lead's Studio work.

## #7 P0.5 — docs truth pass

| Doc | Change |
|---|---|
| `docs/place/README.md` | "Stand der Wahrheit 23.08.2026" banner: framework IS live (62/62, measured 2026-08-22), smoke test played, 3/15 ready + `sorting` built with `ready=false`, PS1 character, SimulationGrade, canteen re-layout, animation re-publish + the three pending field clips, perf pass 1, 21 → 62 scripts — each with `measured on` and the QA doc. Snapshot section retitled "(21.08.2026 — historisch)". F-01 closure noted. `audio-inventory.csv` note: 39 rows listed, 34 measured 22.08., +3 re-created in P0.3, regeneration needs Studio |
| `docs/place/07-FINDINGS.md` | "Status 23.08.2026" table for F-01 … F-22 (status, date, QA doc); F-04 and F-15 retitled as historical with ERLEDIGT banners; F-04 side finding gets the MP-06 pointer; F-21 gets the decision + implementation paragraph; summary now has a 21.08. (historic) and a 23.08. block |
| `docs/MP-04-TRIAL-DESIGNS.md` §0 | SUPERSEDED banner listing D1 (envelope `kind="trial"`/`ev`), D4 (arena grid on `Y = 0`), D6 (SFX substitutes; `AccessGranted` resolves again since P0.3), D8 (one `RoundSeconds` number) with what ships and the evidence |
| `docs/MP-06-FRAMEWORK.md` §0 | Correction: `tests/<id>.lua` are NEW work, only `tests/sorting.lua` exists; framework files 1–3 are in the place |
| `docs/assets/ASSET-LEDGER.md` §2 | STALE banner for `audio-inventory.csv` (regeneration pending Studio) — the CSV itself is left untouched so it stays machine-parseable |

`docs/assets/audio-inventory.csv` was NOT regenerated (needs the place). `PLAN.md` P2 clause:
already done in commit `306b505`, nothing left.

Gate from the issue: `grep -n "nicht im Place" docs/place` → 2 hits, both historical
(`07-FINDINGS.md:27` status row "F-04 Framework nicht im Place | **erledigt**", `:110` heading
"(Stand 21.08., historisch) … war geschrieben, aber nicht im Place"). `NOT in the place` → 0 hits.

## Gates (verbatim)

```
$ lua tests/rules.lua        → 85 checks, 0 failed / GATE 1 RULES PROOF: PASS
                               (  PASS  Pacing.Timing.LobbyReveal is 6.4 s (the lobby roulette hold))
$ lua tests/envelope.lua     → 27 checks, 0 failed / GATE 1 ENVELOPE PROOF: PASS
$ lua tests/contexts.lua     → 21 checks, 0 failed / GATE 1 CONTEXTS PROOF: PASS
$ lua tests/trialrules.lua   → 37 checks, 0 failed / MP-05 TRIALRULES PROOF: PASS
$ lua tests/animationids.lua → 35 checks, 0 failed / MP-05 ANIMATIONIDS PROOF: PASS
$ lua tests/sorting.lua      → 34 checks, 0 failures
```

```
$ selene Pacing.luau MachineFlow.luau KenopsiaClient.client.luau UiFx.client.luau
error[if_same_then_else]  KenopsiaClient.client.luau:738 / :741 / :1023   (3 errors, 0 warnings, 0 parse errors)
```
All three are pre-existing (same blocks at HEAD, lines 731/734/1016 — the sniper fire/scope and
scan-hold input branches; noted as pre-existing in `2026-08-22-p3-simulation-grade.md` too).
Pacing, MachineFlow, UiFx: clean.

```
$ luau-lsp analyze --definitions=<master>/globalTypes.d.luau --base-luaurc=.luaurc --sourcemap=<master>/sourcemap.json <4 files>
Minefield.luau(953,5)/(953,30), BirdHunting.luau(952,5)/(952,30): TypeError: Key 'cleanup' not found in table '{|  |}'
```
luau-lsp is on PATH; `globalTypes.d.luau` / `sourcemap.json` live in the master checkout, not the
worktree, so they were passed by absolute path. The four errors are in files this change does not
touch (pulled in through requires) and are pre-existing; the four changed files report nothing.

REQ-IP-01: `grep -rniE "<13 reference names, space/camel/snake>" studio-src tests default.project.json` → 0 hits.

## Live-check list for the lead (after the push + parity check)

1. **Lobby reveal still 6.4 s**: join, watch the roulette → the `info` card ("NEXT SIMULATION: …")
   must land 6.4 s after the icons start spinning, exactly as before. Server log unchanged.
2. **Chat hidden during a trial**: in the lobby the Roblox chat window + input bar are visible.
   READY → 3-2-1 → as soon as `KenopsiaActiveTrial` is set, both disappear; after `ev="end"`
   (attribute cleared) both come back on the score screen / in the lobby. Toggle SIM FILTER off
   mid-trial: the chat must STAY hidden (it does not follow the look setting). Check
   `TextChatService.ChatWindowConfiguration.Enabled` in the Explorer while playing if in doubt.
3. **Unknown sfx warns once**: deliberate probe — in Edit mode temporarily rename
   `SoundService.KenopsiaAudio.SFX.Warning` → `Warning_x`, Play, trigger the warning card
   several times (the warning button / READY during a countdown) and expect exactly ONE
   `[sfx] unknown name: Warning` line in the Output no matter how often it fires; rename back.
   Any stray name a trial client still uses will now surface the same way during normal play.
4. Parity for the four pushed scripts: `Pacing`, `MachineFlow`, `KenopsiaClient`, `UiFx`.
