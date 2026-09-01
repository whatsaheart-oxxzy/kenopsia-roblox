# Supply screens (wardrobe + requisition) — implementation plan

> **For agentic workers:** execute task-by-task, in order; each task ends
> parseable (StyLua), tested where the module is pure, and committed.

**Goal:** Build the missing "emote wheel + shop screens" client surface and the
missing crate-open server path on top of the finished P5 contract — additive
only, zero edits to `KenopsiaClient` / `EmoteService` / `MainMenu`.

**Architecture:** One new pure config (`SupplyConfig`) + one new pure rules
module (`CrateRules`) prove the whole crate economy offline; one new server
service (`CrateService`) owns the roll and the two new remotes; one portable UI
kit (`SupplyKit`, the TrialClientKit pattern) renders both screens and is
mounted by a thin standalone host (`SupplyClient`). Profiles gains three
additive members (wallet read, key spend, state push) and two packet fields.

**Tech stack:** Luau (nonstrict, LF, `Enum.Font.Code`), offline tests in
desktop Lua 5.1 (`C:\Lua\bin\lua.exe`, the tests/emotes.lua sandbox), StyLua
from `~/.aftman/bin` as the parse+format gate.

**Spec:** `docs/MENU-SHOP-UIUX-SPEC.md` reworked per
`docs/MENU-SHOP-UIUX-INTEGRATION.md`. Decisions resolved by code evidence
since the integration doc: **D-A** — the cold-cyan palette IS canon for the
front door (`MenuConfig.Palette`), and in-facility surfaces are machine green
(docs/place/04-GUI.md §palette); these screens are in-facility → green.
**D-E** — the menu place is real (`SoloExit.MENU_PLACE_ID = 129909297895850` =
Kenopsia_DEV) and the crate ceremony is directed there long-term
(EmoteRegistry L89 "get from crates in Kenopsia_DEV", EmoteService.publishGrant);
this build hosts the screens in MainGame's lobby NOW (where the contract
lives), with the kit portable for the DEV mount later.

## Global constraints

- Additive only: no edits to `KenopsiaClient.client.luau` (177/200 locals),
  `EmoteService.luau`, `MainMenu.client.luau`, `MachineFlow.luau`.
  `Profiles.luau` and `Main.server.luau` get strictly additive extensions.
- Colors: machine set only — `78FFAA` / `8CE8AE` / `2E6B4A` / `020602` /
  `041005`; `FFFFFF` for the selection streak alone; `#FF1818` NEVER
  (reserved for Btn_FIRE/Btn_PUNCH), `#EBF5EE` never (crosshair).
- Every player-facing string SHOUTED, machine voice (flat, imperative).
- Nothing sold: crate cost is EARNED keys; unarmed passes render "OFFLINE"
  with no prompt; no Robux crate path anywhere (RELEASE-CHECKLIST #1/#2).
- Server authoritative: client sends `{}` on CrateOpen, animates only to the
  server's pre-decided result (spec §4 crate rule).
- Perf rules (MainMenu's three): own ScreenGui, no RenderStepped (one stepped
  loop at `Feel.stepSeconds()`, compare-before-write), closed = disabled +
  loop gated + reveal instances destroyed.
- REQ-IP-01: no reference-game names in source.
- New packet kinds ride `MachineState`; unknown kinds render nothing on old
  clients by documented contract, so shipping order is free.

## File map

| File | Role |
|---|---|
| Create `studio-src/ReplicatedStorage/Kenopsia/Shared/Config/SupplyConfig.luau` | pure: palette, rarity frame ladder, crate economy constants, reveal timings, strings, layout numbers |
| Create `studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/CrateRules.luau` | pure: pool / odds / roll / reel, provable offline |
| Create `tests/supply.lua` | offline proof of both files + cross-checks vs EmoteRegistry/ProgressionRules |
| Modify `studio-src/.../Services/Profiles.luau` | add `wallet()`, `spendCrateKey()`, `pushState()`; profilestate gains `keys`,`fragments` |
| Create `studio-src/.../Services/CrateService.luau` | remotes `CrateOpen`+`SupplySync`, the roll, crateresult packet |
| Modify `studio-src/.../Main.server.luau` | require + `CrateService.start(RoomService, EmoteService)` after EmoteService |
| Create `studio-src/StarterPlayer/StarterPlayerScripts/SupplyKit.luau` | portable UI module: both screens, reveal, odds modal |
| Create `studio-src/StarterPlayer/StarterPlayerScripts/SupplyClient.client.luau` | thin host: button, visibility, remote wiring, mounts the kit |
| Modify `docs/RELEASE-CHECKLIST.md`, `docs/MENU-SHOP-UIUX-INTEGRATION.md`, create `docs/QA/2026-09-01-supply-screens.md` | truth docs |

## Interfaces (locked)

```lua
-- SupplyConfig (pure)
SupplyConfig.Palette = { BG="020602", PLATE="041005", GREEN="78FFAA",
  GREEN_SOFT="8CE8AE", GREEN_DIM="2E6B4A", WHITE="FFFFFF" }
SupplyConfig.Rarity  = { -- frame ladder, existing hues only (D-B still open)
  standard  = { stroke="2E6B4A", pulse=false, double=false },
  issue     = { stroke="8CE8AE", pulse=false, double=false },
  clearance = { stroke="78FFAA", pulse=true,  double=false },
  overseer  = { stroke="78FFAA", pulse=true,  double=true  },
}
SupplyConfig.Crate = { COST_KEYS=1, REEL_LENGTH=28, RESULT_INDEX=24,
  WEIGHTS={ standard=50, issue=100, clearance=25, overseer=10 } }
SupplyConfig.Reveal = { SHAKE=0.6, SPIN=4.2, SETTLE=0.5, FLASH=0.25,
  HOLD=0.8, SPIN_BONUS={ clearance=1.2, overseer=2.0 } }
SupplyConfig.Strings = { TITLE="SUPPLY TERMINAL", TAB_WARDROBE="WARDROBE",
  TAB_SUPPLY="REQUISITION", DECRYPT="DECRYPT", ODDS="MANIFEST",
  NO_KEYS="NO CRATE KEYS", EMPTY="COLLECTION COMPLETE", CLAIM="CLAIM",
  AGAIN="DECRYPT AGAIN", SEALED="SEALED", OFFLINE="OFFLINE", ... }

-- CrateRules (pure; emotes = EmoteRegistry.Emotes, owned = set of ids)
CrateRules.pool(emotes, owned) -> sorted {id}         -- source=="crate", not owned
CrateRules.odds(poolIds, emotes, weights) -> { {rarity, percent} } -- sums to 100
CrateRules.roll(poolIds, emotes, weights, r1, r2) -> id | nil     -- r in [0,1)
CrateRules.reel(poolIds, resultId, length, resultIndex, randInt) -> {id}

-- Profiles (additive)
Profiles.wallet(userId) -> { keys=n, fragments=n } | nil
Profiles.spendCrateKey(userId) -> boolean            -- >=1, decrement, dirty
Profiles.pushState(userId)                           -- re-send profilestate
-- profilestate packet: + keys = data.crates.keys, + fragments = data.crates.fragments

-- CrateService
CrateService.start(RoomService, EmoteService)
-- remotes (find-or-create in ReplicatedStorage.Kenopsia.Remotes):
--   CrateOpen  (client fires {})   OPEN_COOLDOWN 3
--   SupplySync (client fires {})   SYNC_COOLDOWN 2
-- MachineState packet out:
--   { kind="crateresult", ok=true, emoteId, rarity, name, keys, fragments, reel={id,...} }
--   { kind="crateresult", ok=false, reason="NO_KEYS"|"EMPTY", keys, fragments }

-- SupplyKit
SupplyKit.create(deps) -> { open(), close(), destroy(), isOpen(),
                            onEmoteState(p), onProfileState(p), onCrateResult(p) }
-- deps = { playerGui, palette, rarity, crate, reveal, strings, registry,
--          money, fragmentsPerKey, stepSeconds, platform(), sfx(name),
--          send = { equip(slot,id), play(id), shop(sku), open(), sync() } }
```

## Tasks

### Task 1 — SupplyConfig + CrateRules, proven offline
- [ ] Write `tests/supply.lua` first (loadPure sandbox from tests/emotes.lua):
  config shape + palette values verbatim + deny `FF1818`/`EBF5EE` in file text
  + strings SHOUTED + timing bounds (total reveal < 15 s incl. worst bonus) +
  `WEIGHTS[r] > 0` for every rarity on a crate row (cross-load EmoteRegistry) +
  `ProgressionRules.FRAGMENTS_PER_KEY >= 1`; CrateRules: pool
  excludes owned/non-crate + sorted; odds sum 100 / empty pool {}; roll nil on
  empty, member of pool over 200 seeded draws, deterministic at fixed r1/r2;
  reel length + fixed result index + members from pool.
- [ ] Run `lua tests/supply.lua` → FAIL (files missing).
- [ ] Implement both modules (pure Lua 5.1 subset: no `+=`, no generalized
  iteration, no type annotations — the MenuConfig rule).
- [ ] `lua tests/supply.lua` → PASS; `StyLua --check` both files. Commit.

### Task 2 — Profiles additive members
- [ ] Add `wallet` / `spendCrateKey` (normalise via the existing
  `data.crates` guard) / `pushState`; add `keys`/`fragments` to sendState.
- [ ] `StyLua --check`; full existing suite battery still green. Commit.

### Task 3 — CrateService + boot wiring
- [ ] Service with EmoteService's gate discipline (rateGate copy, inLobby via
  RoomService, warnOnce, pcall every external). Open flow, synchronous to the
  spend: rate → lobby → wallet → pool → roll (math.random) → spendCrateKey →
  EmoteService.grant (flushes, sends emotestate) → reel → crateresult →
  pushState. Sync flow: sendState + pushState.
- [ ] Wire into `Main.server.luau` after EmoteService. `StyLua --check`. Commit.

### Task 4 — SupplyKit + SupplyClient
- [ ] Kit: root ScreenGui `KenopsiaSupply`; left tab rail (streak selection,
  white ONLY there); wallet pills top-right with count-up juice; WARDROBE =
  wheel strip (8 slots) + catalog grid (rarity ladder frames, OWNED/SEALED
  states) + detail panel ([PLAY] via EmotePlay, slot assign via EmoteEquip);
  REQUISITION = crate panel (keys, DECRYPT, MANIFEST odds modal computed with
  CrateRules.odds client-side) + reveal overlay (shake → reel tween ease-out →
  land flash → typewriter name → CLAIM/AGAIN) + pass tiles from
  MonetizationConfig (unarmed = OFFLINE, armed = ACQUIRE → ShopPrompt sku) +
  private-server tile only when price > 0. Mobile trims via platform().
  SFX: Click (ticks, throttled), Hover, Confirm (land/equip), Reject (denied).
- [ ] Host: SUPPLY button (bottom-right, ≥44 pt touch), hidden while
  `player:GetAttribute("KenopsiaTrialId") ~= ""` and auto-close on set; wires
  MachineState kinds emotestate/profilestate/crateresult to the kit; fires
  SupplySync on boot + open.
- [ ] `StyLua --check` both. Commit.

### Task 5 — Truth docs + full battery + push
- [ ] `docs/QA/2026-09-01-supply-screens.md`: what shipped, offline evidence,
  the in-Play debt (nothing pushed to Studio from this session), the DEV mount
  path for the redesign.
- [ ] RELEASE-CHECKLIST: rewrite the "Emote wheel + shop screens — Codex's"
  bullet to point at the built surface + remaining debt; integration doc: mark
  D-A/D-E resolved-by-code, build list → built.
- [ ] Run ALL `tests/*.lua`; `StyLua --check` on every touched .luau. Commit,
  push branch `docs/menu-shop-uiux`.

## Explicitly out of scope (and why)
- Promo-code service/widget — D-C (rewards) is the user's call; spec section
  stays filed.
- Radial in-lobby emote wheel HUD & keybinds — input surface stays zero until
  the ONE-dispatcher question is answered; wheel slots are editable and
  playable from the wardrobe screen meanwhile.
- Viewport mannequin — [PLAY] previews on the real character through the real
  server gate instead (cheaper, and it exercises the true wire).
- Shop rotation/featured/countdown, Robux crates, holo tier — nothing to
  rotate, nothing sold, no tier above overseer in the catalog.
- Any Studio/live push — repo-only; the live place gets this via the normal
  deliberate transfer, and `studio-src` is already ahead-of-mirror territory
  per RELEASE-CHECKLIST §7.
