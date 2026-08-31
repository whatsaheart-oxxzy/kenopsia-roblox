# Baseline verification — 31.08.2026

Output of a **read-only** verification pass over Kenopsia, run to answer step 1 of the
owner's handoff: *establish the current baseline and ownership boundaries before
implementing anything.* **Nothing here was applied to the game.**

## Read this before trusting anything below

The run was executed by a 47-agent workflow (`wf_eabd60f0-e49`). **36 agents finished; the
host process died twice and took the rest with it.** Concretely:

| phase | state |
|---|---|
| Live-place parity (2 agents) | complete |
| Area maps (8 agents) | complete — 451 edges |
| Claim verdicts (23 agents) | complete — **first pass only** |
| Adversarial review (42 planned) | **3 ran** |
| Final synthesis | **never ran** |

So: every verdict in `CLAIMS.md` is **PROVISIONAL**. The design of the run was that each
claim be attacked by two independent reviewers whose job was to *refute* it, and that
almost never happened. Treat a CONFIRMED verdict as "one agent found evidence", not as
"established". `ADVERSARIAL-REVIEWS.md` records the three that did run.

## Contents

| file | what it is |
|---|---|
| `CLAIMS.md` | 23 handoff assertions checked against current source — verdict, evidence with file:line, player impact, and an unimplemented fix sketch each |
| `DEPENDENCY-MAP.md` | 8 area maps: menu -> admission -> lobby -> trials -> results -> rematch. 451 evidenced edges, plus each area's unfinished register, risks and uncertainties |
| `ADVERSARIAL-REVIEWS.md` | the 3 refutation passes that completed |
| `agent-results.json` | raw structured output of all 36 agents, for re-synthesis without re-running them |
| `live/live-gui.md` | inventory of the LIVE StarterGui tree — the `Warning` frame finding |
| `live/live-parity.md` | live-vs-mirror line parity + symbol table across 10 scripts |
| `live/live-KenopsiaClient-1-3760.luau` | dump of live `KenopsiaClient` lines 1-3760 (the mirror is 818 lines behind) |
| `claim-notes/` | working notes individual agents left behind |
| `staged-headbutt-audio/` | **UNAPPLIED** work from a separate run: a 386-line `FieldPush` rewrite, a FeelConfig block and a test hunk. Never reviewed, never applied |

## Findings that are settled by runtime evidence, not inference

These came from reading the live DataModel, not from source assertions:

1. **`KenopsiaMachine.Warning` does not exist.** Confirmed three ways (child listing,
   `find_child`, whole-tree name search — the only `Warning` in the place is a Sound).
   Two scripts block on it for a full 10 s on every join, one of them at top-level scope
   in `KenopsiaClient`, deferring everything after it. Nothing anywhere creates the frame,
   and there are **zero scripts under StarterGui**. `Btn_CONTINUE` and `HunterLookSetup`
   are missing the same way.
2. **No end-of-round presentation GUI exists** — `Report`, `ShiftReport`, `Podium`,
   `Winner` are all absent. A server-side `Podium` module has nothing to draw into, and
   the ~5 s shift-report hold is a blank screen (the server's own comment at
   `MachineFlow:1336` says it ships dark).
3. **No return-to-menu affordance** anywhere in the place's 19 buttons; the string
   `BackToMenu` does not exist in MainGame, `studio-src/` or `dev-src/`.
4. **The Rojo project does not cover the mirror.** 12 files on disk are unmapped by
   `default.project.json` — including `Profiles`, `Telemetry`, `SoloExit`, `Lobby`,
   `SocialClient`, `LightGuard`. For those, mirror and live have *no sync relationship at
   all*; nothing would detect them drifting. Conversely `SimulationGrade` is mapped and
   would be **recreated** in MainGame by a Rojo push, though it was deliberately deleted
   from the place on 27.08.
5. **11 authoring rigs still ship in Workspace** against only 3 trial folders, and two
   stale full copies of `KenopsiaClient` sit in `ServerStorage` backup folders.

## Two handoff claims came back REFUTED

Recorded so nobody "fixes" a non-problem:

- **S3** — "a cancelled match is reported as MINIGAME ERROR". `MachineFlow` already
  separates a `cancelled` outcome from `error`.
- **P4** — "the main-menu place writes the same profile as MainGame".

## Not a bug, though an agent flagged it

`Workspace` has no `SpawnLocation` at edit time. That is **correct and deliberate** —
`Services/Lobby.luau` builds the holding cell and the spawn at server boot, which is
exactly what stopped it being unversioned place geometry. Do not re-add one to the place.
