# Gate 1 — contexts and the three-minigame session

Target: `KenopsiaMainGame` `110672791536316`, per the Gate 0 §2 ruling.

---

## What Gate 1 delivers

| Piece | File | Proof |
|---|---|---|
| Rounds, legs, every timing constant | `Shared/Rules/Pacing.luau` | `tests/rules.lua` |
| Seed-shuffled order over the three ids | `Shared/Rules/Playlist.luau` | `tests/rules.lua` |
| Exactly 1700 points per completed minigame | `Shared/Rules/Scoring.luau` | `tests/rules.lua` |
| Packet envelope and its validator | `Shared/Net/Envelope.luau` | `tests/envelope.lua` |
| Session / trial / round scopes, CleanupScope | `Services/Contexts.luau` | `tests/contexts.lua` |
| Session progress on the room | `Services/RoomService.luau` | runtime |
| The session loop | `Services/MachineFlow.luau` | runtime |
| Server rejections made visible | `KenopsiaClient.client.luau` | runtime |

**81 offline checks, 0 failures**, run from the command line against the shipped
module files — not copies.

---

## The offline proof is real, and here is why it is trustworthy

`tests/*.lua` load the **actual** files from `studio-src` through `loadfile`. The
only thing the harness supplies is a stand-in for `script` / `require`, and for
`Contexts` a one-call `HttpService` stub. A test against a rewritten copy would
prove nothing about what ships.

That is what forces the portability rule in `Rules/` and `Net/`: no type
annotations, no generalized iteration, no `table.create` / `clone` / `freeze`.
The interpreter available here is **Lua 5.1.5**, and `aftman` cannot install a
real `luau` binary without an interactive trust prompt. Where selene wants
`table.clone`, the line carries an explicit `allow` with the reason, so it does
not get "simplified" into breaking the proof.

### Playlist does not use `math.random`

Luau and Lua 5.1 ship **different generators**. A shuffle built on `math.random`
would be reproducible in both and still produce different orders from the same
seed — the offline proof would then be proving something the game never does,
which is worse than having no proof. The generator is a stated 32-bit LCG,
drawn from the **high** bits because an LCG's low bits have short periods and
would visibly bias a three-element shuffle.

All six permutations are reachable, and the test **searches** for them rather
than asserting a hand-picked list that could pass on a broken shuffle.

### Scoring — a conflict in the spec, resolved

Two rules are required at once: the distribution sums to exactly 1700, and tied
players share the average of the places they occupy. For some shapes both cannot
hold in whole points — three players all tied is the clearest case, since
1700/3 is not an integer.

**The total wins.** A session that silently awards 1699 makes every cumulative
board wrong and compounds over three minigames. Tied players may differ by at
most one point, allocated to the earlier rank.

Measured across **all 14 tie shapes**: every one sums to exactly 1700, and the
spread is **0 everywhere except 3p (2+1) and 3p (3)** — precisely the two cases
the arithmetic makes impossible.

---

## The session loop

```
READY -> snapshot participants, mint sessionId + server seed
      -> Playlist.order(seed), filtered to schedulable minigames
      -> for i = 1..#order:
            Selecting   reveal the next minigame, NO lobby return
            Briefing    control card
            Trial       rounds/legs from Pacing
            Score       Scoring.distribute -> exactly 1700
      -> FinalScore     VIABLE / REJECTED, ties all viable
      -> return to lobby
```

The loop iterates `#order`, never a hardcoded three. Two minigames run today and
three the moment Canteen flips `ready` at Gate 4, **with no change to
MachineFlow**.

### Preserved deliberately

The single-exit finalizer and its `outcome`, the cancellation-aware `hold()`, the
captured `audience`, and the **match-scoped score reset**. That reset stays
before the loop and must never move into it: the counters carry across the
minigames of one session, so resetting per minigame would wipe minigame 1 the
moment minigame 2 began. The Phase 1 comment flagged this as the thing to get
right when the playlist arrived.

`scoresCommitted` now latches only after the **final** board, not per minigame. A
player leaving during minigame 2 must still cancel the match.

### Two errors from the plan's forbidden list, removed

The registry hardcoded **10 rounds for Dead Zone** and **5 for Bird Hunting**.
Both are named in the plan as errors not to repeat. `Pacing` owns the counts now,
and for Bird each iteration is one **leg** with the hunter seat advancing — no
longer `5 × playerCount`.

---

## Defects found and fixed during Gate 1

| Defect | Found by |
|---|---|
| `(value == CLEAR) and nil or value` always fell through to `or value`, so `CLEAR` would have been **written into** the field and broadcast as userdata | luau-lsp, not a test |
| The session loop sent `kind = "select"`; the client dispatches on a fixed set and an unknown kind renders **nothing** | live run |
| Card holds taken from the plan were shorter than the client's typewriter, so cards vanished mid-word | live run |
| A `hide` between minigames left the player standing in an empty world; every `show*` already calls `hideAll()` | live run |
| The look block was written **below** the function that calls it — Lua locals must exist first | selene, before transfer |
| A dead `typeof` fallback in `Envelope` | selene + luau-lsp |
| `table.insert(conns, …)` in the client, where `conns` does not exist — it would have thrown on the **first** rejection, the exact case the notice reports | grep, before transfer |

### Timing deviation, recorded

The plan gives 3 s interim and 6 s final. Both are raised (4.5 / 8.0) because
those numbers were written for a design where the CRT counts down while totals
climb; against the client's typewriter the reviewer observed them as too short to
read. The plan values are kept in a comment in `Pacing.luau` so the deviation
stays visible.

---

## Naming

`tablemanners` is gone. That is the reference game's name for the minigame and
carrying it in shipped source is the exposure `REQ-IP-01` exists to remove. The
id is **`canteen`**, `Playlist.Ids` agrees, and `tests/rules.lua` asserts the old
spelling is **rejected** so it cannot quietly return. The module file is renamed
at Gate 4, where it is replaced wholesale.

Player-facing text says **MINIGAME**, not "trial" — including both abort reasons,
which reach the player as `RUN ABORTED - …`.

**Internal identifiers are unchanged** (`trialId`, `TrialContext`, stage
`"Trial"`). Renaming those touches the envelope contract, `Contexts`, the tests
and every payload check; it is worth doing deliberately rather than folded into a
bug fix.

---

## Removed in the same gate

The XBot rig and the whole animation layer: five scripts plus
`StarterPlayer.StarterCharacter` and `ServerStorage.RBX_ANIMSAVES`. **Zero
`KeyframeSequence`s remain place-wide.**

**The cost, recorded rather than discovered later:** `BloodFX.corpse` cloned
`Beta_Joints`, which was the XBot mesh. With the rig gone it finds nothing and
returns nil, so Bird Hunting and Dead Zone have **no corpse** until the Blender
character supplies one. The blood hit and impact sound still play. Players spawn
as the default Roblox avatar in the meantime.

**The seam is kept on purpose.** The minigames still write `XBotMoves`,
`XBotCrawl`, `XBotScanning`, `XBotAction`. Those calls are inert now, but they
are the protocol — the minigame says *what* the character is doing and the
animation layer decides how it looks. The Blender animations hook the same
attributes instead of needing new plumbing. `BloodFX` still reads `XBotCrawl` and
`Minefield` still sets it, so crawl behaviour in Dead Zone is unaffected.

---

## Verification

| Check | Result |
|---|---|
| Offline proofs | **81 checks, 0 failures** across `rules`, `envelope`, `contexts` |
| Source parity | **19/19 MATCH** (SHA-256) |
| Registration, both directions | **19/19**, zero unmapped scripts in the place |
| Studio-side Luau validation | `status=valid`, 0 diagnostics, every transferred file |
| Selene | **3 errors / 15 warnings** — new baseline; two of the old five errors left with the deleted XBot files. None in Gate 1 code |
| luau-lsp | `MachineFlow` **0** with the sourcemap; every other changed file identical to its pre-change count |

`sourcemap.json` was regenerated. luau-lsp had been running without it, which
reported every `require(ReplicatedStorage:WaitForChild(...))` as an unknown
require — pure artifact. **Future gates should pass `--sourcemap`.**

---

## Verified in the live Luau runtime

The offline proof runs under **Lua 5.1**. The whole portability rule rests on an
argument -- that the same source behaves identically under Luau -- and an argument
is not a measurement. It has now been measured, in a running server:

| Check | Result |
|---|---|
| `Playlist.order` for the six proof seeds | **6/6 identical** to the Lua 5.1 output |
| `Scoring.distribute`, 12 shapes across 2-4 players | **12/12 summed to exactly 1700** |
| `Pacing.roundsFor` | minefield 2p=4, birdhunt 2p=4, canteen 3p=2 |

Had the generators disagreed, the entire Playlist proof would have been void --
reproducible offline, reproducible in game, and different from each other. They
do not disagree.

**Boot is clean after the XBot removal.** `[RoomService] online`,
`[MachineFlow] online - 2/3 trials ready (birdhunt, minefield)`,
`[Kenopsia] server ready`, `[Kenopsia] client online`, and no error or warning.
`[XBotCharacters]` and `[XBotAnimSync]` are correctly absent. The new requires
(Pacing / Playlist / Scoring / Contexts) all resolve, and the client's new
LobbyError block does not throw.

## Not done, and deliberately so

- **§5 runtime acceptance has not been run.** The session flow needs two clients;
  the loop has been observed once and three defects came out of that run. It has
  not been observed *clean* end to end.
- The trials still take their old `runRound(room, roundIndex, …)` signatures.
  Threading `RoundContext` into them is Gates 2/3/4, as planned.
- `kind = "hitmark"` has a client handler drawing `BOOM HEADSHOT!` for 0.9 s and
  **no server sends it** — the indicator is dead code. Both the wording and the
  missing sender belong to Gate 3 (`REQ-IP-01` lists the `HitMark` strings).
