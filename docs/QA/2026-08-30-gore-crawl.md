# QA — Gore reduction + crawl change (30.08.2026)

Scope: the user's directive **"Make less blood and remove the half body
crawling and only normal crawling."** Decision E6 (maturity mild ~14+) already
covered the intent; this pass executes it. 3-agent workflow (recon → build →
adversarial review). Review returned **GO on all files** after fixing 6 defects
found in the build, including one real concurrency bug (see below). Applied
LIVE via weppy MCP against content-verified anchors, bottom-up per file, then
mirrored to `studio-src/`.

## What shipped

**One knob, two satellites.** All *visible* blood is now set by a single
`GORE` table at the top of `GoreClient` (~40 % of the old volume: fewer and
smaller droplets/splats/pools, shorter pool life, weaker mist and fountain).
Two values live elsewhere because they run in other scripts, and both point
back at that block in comments:

| File | Live | What |
|---|---|---|
| `StarterPlayerScripts/GoreClient` | 495 | the `GORE` table + all four effect combos (`kill`/`maim`/`hit`/`shatter`) read from it |
| `Services/BloodFX` | 237 | `BLEED_MIN 1.6` / `BLEED_VAR 0.8` (was 1.0/0.6) — the crawl trail drips every ~2.0 s instead of ~1.3 s |
| `StarterPlayerScripts/KenopsiaClient` | 4034 | screen blood: thinner veil, 3–8 blobs (was 5–14), smaller, `FadeScale 0.65`, and a `G.Gate = 0.28` that stops lens blood past ~31.6 studs |

**No event was removed — only volume and dwell.** Every hit keeps its sound,
mist puff and pool; it is simply smaller.

**The half-body crawl is gone.** `Minefield` no longer sets `XBotLegless`
(the only `true` writer is now a comment; the two `false` clearers stay
deliberately, so a character carried over from an older session still gets the
attribute wiped). A first mine now **wounds**: `XBotCrawl` + `CRAWL_SPEED` on
a whole body, the ordinary crawl clip. `GoreClient.maim` lost its
`gibs(pos, 4, true)` — the four leg-shaped chunks were what actually read as a
severed body. Feed line `"LEGS GONE. CRAWL."` → `"WOUNDED. CRAWL."`.

**Shake `power` rescaled** (power feeds `trauma` only, never blood strength):

| Site | Before | After |
|---|---|---|
| `Minefield` mine | 1.3 | 0.8 |
| `Minefield` compactor | 1.6 | 1.0 |
| `CanteenProtocol` execution | 1.5 | 0.9 |
| `TrialKit:Round:kill` default | 1.5 | 0.9 |
| `SortingFloor` MISFILED | 1.3 | 0.8 |

Ordering preserved and now explicit: **mine 0.8 < canteen execution 0.9 <
compactor 1.0.**

## Verification

- Adversarial review found and fixed **6 defects** before apply. The real one:
  `BloodFX`'s bleed thread called `stopBleed(char)` on wake, clearing whatever
  was in `bleeding[char]` — not its own entry. With the longer interval the
  window widened, so a round-end `clear` followed by an immediate re-bleed
  could have the *old* thread kill the *new* trail. Now
  `if bleeding[char] == entry then …`.
- Live: all 7 scripts weppy-validated **`status: valid`** (parser 0.730).
  Every anchor was read back and content-matched before each edit; the two
  anchors the review flagged as conditional (`KenopsiaClient` 3184–3222 /
  3234) were eyeballed live first and matched verbatim.
- Offline battery from the repo, all 13 suites, identical to the pre-pass
  baseline: feel **190/0**, progression **247/0**, grade **54/0**, menu
  **218/0**, sorting **34/0**, animationids / contexts / envelope / glyphs /
  machinecam / rules / trialrules / voice **PASS**.
- selene over the 7 changed files: **3 errors / 10 warnings / 0 parse errors —
  byte-identical to the same run on the pre-pass tree.** No new lint.

## Accepted risks

1. **The canteen execution loses its trauma-cap guarantee.** `> 1` used to
   force `trauma` to the cap even right after another shake; at 0.9 it
   accumulates instead. Relative ordering still holds — the failure mode is
   only that two events in quick succession feel slightly less absolute.
2. **`MAX_SPLATS` on touch (22) sits just under one shatter's output** (~27–30
   splats), so on a phone the oldest 6–8 of a big kill fade early. Still far
   better than before (old: ~66 splats against a 40 cap). Raise
   `GORE.SplatsT` to 30 if it reads as a bug — it is a frame-time ceiling,
   which is why it was not pre-raised.
3. **`PS1Animate` L375–445 (the leg-fold) is now unreachable** — nothing sets
   `XBotLegless` any more. It still costs one `GetAttribute` per character per
   frame. Left in place because `PS1Animate` is inside the emote-phase scope
   fence; delete it when that lifts.
4. **`Feel.Fade.ScreenBlood` is scaled at the call site.** `FeelConfig:75`
   reads 0.55, practice is 0.36. `FeelConfig` was fenced this pass; fold
   `FadeScale` into it when it opens.

## Found during the pass — repo mirror is BEHIND live

Not caused by this pass, but it surfaced while mirroring and it is a release
hazard (a Rojo connect from `studio-src/` would overwrite live with stale
code):

| File | master mirror was behind live by |
|---|---|
| `KenopsiaClient` | ~750 lines (its `screenBlood` was still the pre-26.08 version) |
| `Minefield` | 22 lines |
| `BloodFX` | 18 lines |
| `GoreClient` | 9 lines |

`BloodFX` and `GoreClient`'s live-only content matches the **unmerged
`worktree-mp-08-death-and-spectate` branch** byte-for-byte, so that is where it
came from. This commit deliberately does **not** absorb that branch: the gore
hunks were applied to master's own content (one `BloodFX` hunk that only edits
a comment absent from master was skipped as a no-op). The `KenopsiaClient`
`screenBlood` block is the one exception — the new block is built on the 26.08
version, so pasting it necessarily brings that function forward.

**Queued for the blockers list: reconcile `studio-src/` against live (and
decide the fate of `worktree-mp-08-death-and-spectate`) before any Rojo sync
or publish.**

## PENDING in-Play (standing debt)

Mine 1 → wounded crawl with a whole body and a normal crawl clip, no thrown
lower half, trail still drips; mine 2 → death; blood visibly lighter on a
phone; no lens blood past ~32 studs; shake still reads hardest on the
compactor.

---

## Addendum (same day): the dead leg-fold is gone

With Phase 5 applied the scope fence on `PS1Animate` lifted, so accepted risk
3 above is closed rather than carried. The 71-line `RenderStepped` block that
pushed both leg chains 3.2 studs (× scale) under the floor while `XBotLegless`
was set — plus its clot part and drip emitter — is **deleted**, replaced by a
tombstone comment. Verified first that nothing anywhere still sets the
attribute true: a place-wide search over 111 scripts returns only the two
deliberate `false` clearers in `Minefield.cleanup()` and comments. `PS1Animate`
508 → 454 lines, validates clean. This also removes one `GetAttribute` per
character per frame.
