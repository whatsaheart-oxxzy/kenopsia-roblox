# Menu & Shop UI/UX spec — integration map (2026-09-01)

Companion to `docs/MENU-SHOP-UIUX-SPEC.md`. That spec is a design-language
document written against *generic* Roblox patterns. This file maps it onto what
actually exists in this project as of 2026-09-01, so whoever implements the
screens (per `docs/RELEASE-CHECKLIST.md` the emote wheel + shop screens are
**Codex's**; the server contract is finished and waiting) does not re-derive
the state of the world — and does not accidentally re-open decisions the user
has already locked.

Everything cited below was read from the repo today; `studio-src/` mirrors the
MAIN place (currently *behind* live in places — see RELEASE-CHECKLIST §7),
`dev-src/` mirrors `Kenopsia_DEV`, where the lobby redesign (Gate M1) is in
flight with uncommitted work from today.

---

## 1. Verdict at a glance

| Spec section | Verdict |
|---|---|
| §1 Sidebar nav-rail | **Adapt.** The DEV menu redesign already has a navigation model: an explicit nav *stack* in `MenuOverlayController` over a walkable 3D "Personnel Intake Bay" — not a 2D terminal with a sidebar. The spec's rail/tab-bar pattern applies only if a screen ever hosts 4+ sibling destinations; today's overlay (Landing / Settings / Credits / Session) does not. |
| §2 Shop + promo codes | **Buildable, partly.** Gamepass direct-buy contract is ready (`ShopPrompt` + SKUs). Featured/rotating/limited sections have **no server backing** and nothing rotates. Promo codes have **no server support at all** — new service required. |
| §3 Currency pills | **Adapt.** There is no "Credits" currency. The earned wallet is **crate-key fragments → keys** (`profile.crates {keys, fragments}`). Pills should show KEYS (+fragment progress), not an invented credit balance. A Robux pill has nothing to sum — the paid surface is two gamepasses, not a wallet. |
| §4 Inventory / wardrobe / crates | **Best fit.** Emote ownership, equip, 8-slot wheel, and state packet all exist and are deliberately dark ("Phase 5 adds ZERO client scripts"). Crate *reveal* choreography is usable as-is, but **no crate-open service exists yet** (nothing consumes a key). Rarity needs vocabulary mapping (§4 below). |
| §5 Play / party lobby | **Conflicts.** HOST/JOIN/PUBLIC via `ReserveServer` + room codes is the **retired** multi-room model. Live reality: one canonical room per 2–4-player server, no join codes, rematch needs unanimous READY. The DEV redesign already has `RoomService`/`PartyRegistry`/`PartyWallView`. Only the spec's *presentation* (tiles, ready states, "SUBJECT INTAKE" theming — already echoed by the Intake Bay) carries over. |

---

## 2. The contract that already exists (verified today)

All in the MAIN place tree (`studio-src/`), shipped live with P5 (commit
`0043747`), client side deliberately unbuilt:

- **Remotes** `EmotePlay`, `EmoteEquip`, `ShopPrompt` — created and gated in
  `Services/EmoteService.luau:431-447`. Every path is rate-limited and
  server-validated; the play path is synchronous (L336+).
- **State packet** `kind = "emotestate"` → `{ owned = sorted ids, equipped,
  wheel[1..WHEEL_SLOTS] }` (`EmoteService.luau:307-331`). The catalog does NOT
  travel — the client `require`s `EmoteRegistry` from ReplicatedStorage.
- **Catalog** `Shared/Config/EmoteRegistry.luau` — six user dances, all
  `source = "crate"` (L87: crate keys are EARNED; nothing is sold until the
  user flips a row). Ids ship sorted for deterministic wheel/shop rendering
  (L210). Rows already carry `rarity` (L58) — see §4.
- **Monetization** `Shared/Config/MonetizationConfig.luau` — `PASSES.OVERSEER`
  / `PASSES.ARCHIVE` with stable `sku`s (`PASS_OVERSEER`, `PASS_ARCHIVE`);
  the client only ever sends a sku (L41-43, `passBySku` L86). Both ids are `0`
  → `armed()` false → the whole paid surface is a silent no-op until the user
  pastes ids (RELEASE-CHECKLIST decision #1). `PrivateServerPrice = 0` (L75),
  set-once rule documented in the file header.
- **Wallet** `profile.crates = { keys, fragments }`
  (`Shared/Rules/ProgressionRules.luau:104-105`); WORK-ORDER quests pay one
  fragment each (L313) and fragments roll into keys at `FRAGMENTS_PER_KEY`
  inside `Services/Profiles.luau:380-391`. Wheel writers live in Profiles
  (`setEquipped` / `setEmoteSlot` / `setWheel`, Profiles.luau:30).
- **Invite** — the lobby invite button is a plain client-side
  `SocialService:PromptGameInvite` call by design (RELEASE-CHECKLIST,
  "deliberately NOT built" list).

**Missing server pieces the spec assumes** (each is new work, none is blocked
on a user decision except where noted):

1. **Crate open** — nothing consumes `crates.keys` or grants a random emote
   (grep for open/decrypt/consumeKey: zero hits). Needs a server roll
   (server picks the result; client reel animates *to* it, exactly as the spec
   says), an odds table constant, and an idempotent grant through Profiles.
2. **Promo codes** — no RemoteFunction, no redeemed-store. Needs a service +
   per-player DataStore mark + rate limit. (Spec's server-authority section is
   correct as written.)
3. **Shop rotation / featured / countdown** — no timed catalog exists; with a
   six-emote catalog and two passes there is nothing to rotate yet. Skip until
   the catalog grows.

---

## 3. Locked decisions the spec must NOT re-open

1. **Single-menu rule** (user, 2026-08-08): the MAIN place has ONE menu — the
   Machine flow. A second CRT main menu was built and removed ("2 Menus is
   weird"). Shop/inventory screens must join an existing surface (the Machine
   GUI in MainGame, or the DEV overlay stack), never stand beside it.
2. **Room model** (measured live 2026-08-21, GameConfig header): one canonical
   room per server, 2–4 players, LOCKED at 2–4 ("egal wie", do not re-open).
   No join codes are issued. The spec's §5 HOST/JOIN/PUBLIC ReserveServer flow
   describes the *retired* model — do not implement it. Private servers exist
   only as Roblox's native paid feature (`PrivateServerPrice`, decision #3).
3. **Nothing is sold until the user decides** (RELEASE-CHECKLIST decisions
   #1/#2): all six dances stay `crate`; flipping one to `robux` is the user's
   two-edit decision (`source` + the pass's `grants.emotes`, enforced by
   `tests/emotes.lua`). The spec's Robux-crate sections are therefore
   **dormant design**, not a build order. Corollary: since crates are
   earned-only today, Roblox's paid-random-item odds rule does not yet bind —
   but ship the odds (ⓘ) modal anyway; the spec's ethics stance matches the
   project's existing one and it future-proofs a later paid crate.
4. **Red is reserved**: menu error/urgency states use glitch + dim tones,
   never `#FF1818` — consistent with E4 (danger flashes live in trial UI).
   The spec already agrees; keep it that way in implementation.

---

## 4. Vocabulary and palette mapping

| Spec says | Kenopsia reality |
|---|---|
| "Credits" (earned currency) | **Fragments → Keys** (`profile.crates`). Pill: key icon + count, with fragment progress toward the next key (e.g. `▰▰▱ 2/3`). No Robux→credits path exists — matches the spec's own "earned-only is cleaner" recommendation. |
| RARE / EPIC / LEGENDARY / UNIQUE | Registry tiers are diegetic: `standard`, `issue` (the six dances), `clearance`, `overseer` (`EmoteRegistry.luau`). Keep the *diegetic names* on labels; borrow the spec's **escalation mechanics** (stroke color → glow → animated holo frame) per tier. A color assignment (e.g. standard=inert, issue=blau, clearance=gold, overseer=lila/pass-tint) is a user/art decision — do not silently import Fortnite hexes. |
| Cold-cyan CRT palette (`#BFE9F5`/`#E8FBFF`/`#4E7C8A`) | The project's `Theme.luau` is **phosphor green** (`Phosphor 78FFAA`, L8) plus the new `Theme.Street` set (L42) the Step-2 overlay actually uses; `Theme.CRT` survives as back-compat (L99). E4 locked Machine green as the diegetic signature. **Decision needed** before any screen is styled: cold-cyan as a new surface identity, or restyle the spec's components into Phosphor/Street. Do not fork a third palette ad hoc. |
| Fullscreen 2D terminal menu | The in-flight redesign is a **walkable 3D Personnel Intake Bay with a code-built overlay stack** (`MenuOverlayController` header; landing keeps the 3D room visible). The spec's CRT-terminal framing applies to *individual screens/panels*, not to the frame story. Its "SUBJECT INTAKE" theming is already the redesign's language. |
| `Theme.lua` with palette + rarity map (Stufe 1.1) | Exists: `KenopsiaClient/UI/Theme.luau` (+ `Motion`, `SoundBank`, `GlitchTitle`, `SignalFX`, `Cursor`). Extend it; do not create a second theme module. |
| Party panel with ready states | Exists in DEV: `PartyWallView.luau` (29 KB) + `SessionWallController` + server `PartyRegistry`/`RoomService`. Reuse. |
| ViewportFrame mannequin | The confirmed presentation rig is `Workspace.Player_Rig` (20 bones, 3 Motor6Ds, AnimationController, no Humanoid — Gate M1 §1 findings). Emote preview = play the clip on this rig, not on a cloned R15. |

---

## 5. What is buildable immediately (no pending decision)

Ordered so each step ships alone; all client-side unless marked:

1. **Wardrobe/emote screen** on the existing overlay stack: grid from
   `EmoteRegistry` (sorted ids), state from `emotestate`, EQUIP/UNEQUIP via
   `EmoteEquip`, wheel slots 1..8, equipped card ribbon + sort-to-front. The
   spec's §4 equip-state table applies verbatim.
2. **Wallet pill** (keys + fragment progress) with the spec's §3 count-up
   juice. Verify which packet carries `crates` to the client before rendering;
   if none does yet, extend Profiles' state send (server, trivial, no
   decision).
3. **Rarity card component** with tier-escalating frame treatment mapped onto
   the four diegetic tiers (colors TBD by user — build it token-driven so the
   assignment is one table edit in Theme).
4. **Shop screen skeleton**: two gamepass tiles rendered from
   `MonetizationConfig.PASSES` (name + grants + `armed()` gating; unarmed =
   "OFFLINE" state, no prompt), private-server tile printing
   `PrivateServerPrice` once set. Purchase via `ShopPrompt` with the sku.
   The spec's buy-button state machine applies; "Can't afford" does not (no
   soft-currency direct buys exist).
5. **Crate-open service + DECRYPT reveal** (server + client): server roll,
   odds constant + (ⓘ) modal, spec §4 reveal choreography with tier-keyed
   timing. Earned keys only — no Robux path.
6. **Promo-code service + widget** (server + client): RemoteFunction,
   DataStore redeemed-mark, the spec's five widget states. Decide rewards
   (fragments? keys? an emote?) with the user before shipping.

Deliberately NOT to build from the spec: §5 ReserveServer party flows (locked
out, §3.2 above), shop rotation/featured/limited (nothing to rotate), Robux
crates and any credits purchase path (decisions #1/#2 pending).

## 6. New decisions for the user (beyond RELEASE-CHECKLIST #1–#6)

- **D-A Palette**: cold-cyan spec identity vs. Phosphor/Street for
  shop/wardrobe screens (see §4 row 3).
- **D-B Rarity colors**: color per diegetic tier; whether a holo "UNIQUE"-like
  top tier should exist at all (nothing in the catalog is above `overseer`).
- **D-C Promo codes**: ship at all? If yes, reward table.
- **D-D Odds visibility**: show the (ⓘ) odds modal for earned crates now
  (recommended) or only if a paid crate ever ships.
- **D-E Which place hosts the shop/wardrobe screens**: the MainGame Machine
  GUI, the DEV overlay stack (transferred later), or both — this decides which
  client tree the screens are written into.
