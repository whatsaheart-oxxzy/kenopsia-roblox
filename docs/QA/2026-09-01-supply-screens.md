# QA — Supply screens (wardrobe + requisition) + crate ceremony

Branch `docs/menu-shop-uiux`, commits `f5e5c1a` → `0c083f8`. Repo-only: **nothing
was pushed to Studio or any live place from this session**, and `studio-src/`
remains exactly as reconcilable against live as before plus these additive
files. Design source: `docs/MENU-SHOP-UIUX-SPEC.md` reworked per
`docs/MENU-SHOP-UIUX-INTEGRATION.md`; build order in
`docs/MENU-SHOP-BUILD-PLAN.md`.

## What shipped

| File | What |
|---|---|
| `Shared/Config/SupplyConfig.luau` | NEW, pure. Machine palette verbatim, rarity frame ladder over the diegetic tiers, crate economy (cost 1 earned key, reel 28/result 24, per-rarity weights), reveal timings, SHOUTED strings, 710px-reference layout numbers. |
| `Shared/Rules/CrateRules.luau` | NEW, pure. pool/odds/roll/reel; rarity-band-then-uniform roll; odds normalised over PRESENT bands, always summing 100; every random number injected (offline-replayable). |
| `Services/Profiles.luau` | ADDITIVE. `wallet()`, `spendCrateKey()` (the wallet's only spender), `pushState()`; `profilestate` packet gains `keys`/`fragments`. House style kept, no reformat. |
| `Services/CrateService.luau` | NEW. Remotes `CrateOpen`/`SupplySync`; EmoteService's gate discipline (rate gates committed on entry, RoomService lobby predicate, warnOnce, pcall-wrapped); synchronous roll→spend→grant (one UpdateAsync via `EmoteService.grant`), `crateresult` packet carrying the reel with the result at RESULT_INDEX. |
| `Main.server.luau` | +2 lines: require + `CrateService.start(RoomService, EmoteService)` after EmoteService. |
| `StarterPlayerScripts/SupplyKit.luau` | NEW module (TrialClientKit pattern). Both screens, wallet pills with count-up, the DECRYPT reveal, the MANIFEST modal (odds computed client-side with the same CrateRules the server rolls with), gamepass tiles (OFFLINE while unarmed, `ShopPrompt` sku when armed), private-cycle tile only at price > 0. WHITE only on the tab streak; DisplayOrder 54 (machine 50 < supply 54 < title menu 55 < CRT glass 60). |
| `StarterPlayerScripts/SupplyClient.client.luau` | NEW host. Lobby SUPPLY_ button (hidden in trials + while `KenopsiaMenu` is open, auto-close on `KenopsiaTrialId`), remote wiring, MachineState dispatch, ONE stepped loop at `Feel.stepSeconds()`. Zero KenopsiaClient edits, zero input binds. |
| `tests/supply.lua` | NEW suite, 114 checks. |

## Offline evidence (all green, this session)

- `lua tests/supply.lua` — **114 checks, 0 failures** (palette verbatim +
  reserved-hex grep-deny, rarity coverage, economy bounds, reveal < 15 s worst
  case, SHOUTED strings, pool/odds/roll/reel semantics incl. 600 seeded rolls
  never leaving the pool and the heavier band landing more often).
- The full battery: all 15 suites of `tests/*.lua` PASS after the Profiles
  edit (supply, emotes, progression, menu, grade, feel, rules, voice, sorting,
  glyphs, contexts, envelope, machinecam, animationids, trialrules).
- StyLua (full-moon Luau parser) parses every touched file: 0 parse errors.
  Existing files were deliberately NOT reformatted — `studio-src` mirrors live
  code and a style pass would poison the parity diff.

## Deliberately as-is

- **Nothing sold**: crate keys stay earned; both passes unarmed (ids 0) render
  OFFLINE and cannot prompt; no Robux crate path exists anywhere.
- **Promo codes not built** — decision D-C (rewards) is the user's; spec
  section stays filed.
- **No radial in-lobby emote wheel HUD, no keybinds** — the input surface
  stays zero until the one-dispatcher question is answered; slots are playable
  and editable from the wardrobe screen.
- **No viewport mannequin** — PLAY previews on the real character through the
  real server gate.
- Rarity COLORS per tier (D-B) still a user decision; the ladder is
  token-driven in SupplyConfig, one table edit when decided.

## NOT verified (the in-Play debt this adds)

Nothing below ran, because nothing was pushed to Studio:

- `[CrateService] online - 6 crate emote(s) in stock, cost 1 key(s)` on boot;
  clean console with no `[CrateService]` warns.
- SUPPLY_ button appears in the lobby, hides in a trial and under the title
  terminal; panel opens, tabs switch, streak moves.
- SupplySync handshake fills owned/wheel/wallet after a fresh join.
- Equip/clear round-trips move the wheel strip; PLAY dances the character in
  the lobby and is denied inside a session.
- A DECRYPT with 0 keys / with keys: NO CRATE KEYS vs full ceremony landing on
  the server's item; wallet pill counts down; emotestate arrives with the new
  emote; COLLECTION COMPLETE after all six.
- Reduced-motion path (no shake/spin), phone layout at the 0.55 scale clamp.

## Bringing it live (deliberate, not drive-by)

Push exactly these seven scripts (six + Main) to the MAIN place via the usual
controlled path (weppy `manage_scripts` with placeId pinned, or the official
proxy), then Save & Publish. `SupplyConfig`/`CrateRules` are new Instances
under `ReplicatedStorage.Kenopsia.Shared.*`; `SupplyKit`/`SupplyClient` new
under `StarterPlayerScripts`. No place geometry, no GUI authoring, no
attribute changes — code only. The DEV mount later: copy `SupplyKit` +
`SupplyConfig` + `CrateRules`, write a DEV host with the cold-cyan palette,
and a DEV-side grant writer that ends in `EmoteService.publishGrant`
(the cross-place path EmoteService already subscribes to).
