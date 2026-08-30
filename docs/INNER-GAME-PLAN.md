# INNER-GAME-PLAN — Kenopsia_MainGame release design (approved 29.08.2026)

Plan of record for the **inner game** of Kenopsia_MainGame (place `110672791536316`, group
`832614570`): lighting, gameplay, systems, smoothness, and the player-return loop for the
2–4 player release with the three shipped trials. Approved by the user on 29.08.2026.
Ordering authority remains `MASTERPLAN.md`; decisions live in `PLAN.md` (this plan adds
E4–E6). GUI/UI is out of scope (Codex builds screens; this doc defines only the data
contracts the UI consumes). Gamepasses, dance emotes, crates (Kenopsia_DEV) and the emote
wheel come later — this plan ships dormant sockets so the retrofit is a table entry.

Provenance: produced by a 7-agent workflow — 3 research agents (MASTERPLAN + docs digest;
live Studio inspection 29.08; code/animation inventory incl. `docs/place/`), 3 independent
design drafts (mechanics / atmosphere+perf / retention lenses), and a judge that scored the
drafts and ruled on every conflict. Everything below is grounded in the measured live place.

**Non-negotiables this plan honors** (MASTERPLAN/PLAN.md, verified live): 2–4 players
forever (E1); Borda scoring, exactly 1700 pts/trial, FINAL AUDIT ×2; telegraph ≥0.7s before
every kill; server-authoritative kills; all timings in `FeelConfig`/`Pacing.Timing`, never
literals; Machine voice text-only uppercase ending `_`; PS1 grade trial-scoped only,
byte-exact Lighting snapshot/restore; camera quantisation position-only; chat ON in lobby /
OFF in trials; `StreamingEnabled=false`; 4-file trial pattern, one owner per shared file;
REQ-IP-01; KenopsiaClient sits at ~185/200 Luau registers — **every new client feature is
its own LocalScript/module**, never new locals in the monolith.

---

## 1. Design stance — one verb per trial

Each trial owns exactly one verb the others don't; escalation mutates the read, never adds
verbs:

- **DEAD ZONE** = *read the ground*
- **BIRD HUNTING** = *read the other player*
- **CANTEEN PROTOCOL** = *read the boss*

At 2–4 players, chaos can't come from crowd density — it comes from **shared-fate
mechanics** (one player's action changes another's read) and structural comeback pressure
(FINAL AUDIT ×2 plus per-trial "greed lines": risky detail-point options trailing players
are incentivized to take). Raw score keys keep the bands FINISHED 2000+ / ALIVE 1000+ /
OUT 0+ with **detail always <1000** (per-kill/per-pickup detail is capped `min(999, …)`).

## 2. The three trials

### 2.1 DEAD ZONE (minefield, 62s rounds, 4/3/3 by player count)

Keep: 258.6-stud mined corridor, client-integrated compactor (server publishes
`MF_Z0/T0/Speed` only), `DeathField` death clip (0.6s offset).

- **Sonar economy (new baseline):** each player gets **3 sonar pulses per round**
  (`MF_SonarRing`, cyan Signal ring); a pulse reveals mines within 12 studs for 2.5s **to
  everyone**. Cooperative information, competitive positioning — the front-runner becomes a
  public service without any coop mechanic.
- **Crater persistence across rounds:** detonated mines leave `MF_Crater` instances that
  **persist across rounds within the trial** (runtime folder in the TrialContext, cleared in
  `cleanup(ctx)`). Craters are proven-safe ground: the field becomes a map the group
  co-authored; your death is everyone else's information. Machine line:
  `THE FALLEN MARK THE PATH_`.
- **Mid-round pressure step:** one compactor speed step at `t = RoundSeconds × 0.55`,
  telegraphed ≥0.7s by a **lane-light cascade + horn** — never a light alone (low quality
  drops local lights; the horn + emissive-neon cascade is the canonical telegraph).
- **Final-round mutator (single axis):** `BLACKOUT SWEEP` — sonar pulses fire only while
  standing still ≥0.5s (`Feel.Minefield.SonarStillTime=0.5`), compactor 1.15×.
- **Greed line:** 3 **SCRAP TAGS** per round seeded (`TrialKit.rng`) onto the statistically
  most-mined third; +150 detail each.
- **Deaths (mild maturity, E6):** mine kill = `DeathField` clip + crater, 2.5s hold → fade
  → spectate 3.2s; compactor kill = **instant hard cut** to the arena-wide camera — no
  crush shown; the cut is the violence. GoreClient keeps its shipped touch caps (48/40).

### 2.2 BIRD HUNTING (3 legs × 60s, rotating hunter)

Keep: 315.6-stud run, 5-arg `runRound` leg system, touch aim-assist magnet (9.5°/6.5°, 6°
scoped), no grade while scoped.

- **Reload lockout 2.2s** (`Feel.Birdhunt.ReloadSeconds=2.2`) after every shot, with a
  **visual reload tell readable at 300 studs without audio** (rifle-lower viewmodel + tower
  lamp state — phone speakers are often off). Runners who sprint only in reload windows are
  playing correctly.
- **Runner injury state (zero new assets):** a non-lethal limb hit sets the existing
  `Injured` attribute → `InjuredWalk` clip (3.49 st/s) until leg end. The sniper chooses
  kill-shot risk vs. slow-them-down value.
- **Push-topple decoy:** runners can `Push` (existing clip/bind) one loose cover prop per
  leg — crates topple to create new cover; server-validated via the 20Hz sampler, no
  `.Touched`.
- **Heartbeat exposure (anti-camping):** standing still >2.5s in open ground pings the
  runner's silhouette to the sniper (0.4s edge highlight).
- **Decoy birds:** 2–3 client-animated low-poly birds per leg from a server seed; the
  hunter may shoot one for +200 detail — but it **spends a reload window**. A bluff
  resource, and the trial name finally means something.
- Scoring: runner FINISHED 2000 + time detail / ALIVE 1000 + distance / OUT 0 + distance;
  hunter 2000 base + per-tag/bird detail capped <1000. Rotation guarantees everyone snipes
  once; at 2p legs alternate hunter.
- *Post-release escalation (not launch):* persistent cover damage across legs (server
  `coverState` diffs via `trial` packets) — the most expensive feature; design survives,
  ships later.

### 2.3 CANTEEN PROTOCOL (60s rounds, 3/2/2) — the signature boss trial

Keep: observer FSM (`hidden 2.0–4.0 → lowering 0.35 (tell) → watching 0.9–1.8 → raising
0.30`), 16 peas, fork cap 4, `plate` safe / `mouth` detectable, Stab click-to-stab +
separate Eat, execution = boss `Shoot` + player `Death`, boss never dies. The boss is
anchored and has **no locomotion clip — any patrol/walking escalation is rejected for
launch** (would require new animation assets).

- **Escalation ladder:** each round shortens `hidden` bounds ~15% (floor 1.2s) **plus** a
  server-side **suspicion meter** — each near-catch shortens the boss's next hidden window
  0.3s; `BossAngry` atlas swaps at suspicion ≥2. Round 2+ adds **fake-lowers** (`LookDown`
  without `watching` — existing clip): reading the newspaper angle becomes a learnable
  skill.
- **Hot peas (R2+):** 4 of 16 peas are Hazard-tinted; each must reach a mouth within 8s of
  being forked or is voided — forces mouth attempts under a worse read.
- **Banked peas keep their points (the greed line):** caught = executed, but eaten peas
  score. ALIVE 1000 + 60/pea; OUT 0 + 60/pea; **CLEAN PLATE** (all 16) = FINISHED 2000 +
  time detail — the only route to the top band is to keep eating.
- **Last-diner duel + SETTLEMENT:** when one armed diner remains, MachineVoice narrates
  (`ONE REMAINS_`); when someone cleans their plate, a 5s `SETTLEMENT` window
  (`Pacing.Timing.CanteenSettlement=5.0`) lets others shovel rate-limited.
- **Audio tell:** newspaper **rustle SFX 0.35s before `lowering`** — ears beat eyes; also
  the accessibility path.
- **Spectator reward:** dead players inherit the `ObserverCamera` vantage — they see FSM
  tells the living can't.

## 3. Session loop (spine unchanged — it's QA'd; three additions)

preFlow roulette 6.4s honest reveal (server seed) → per trial: info 3.5 → controls 8.0/5.0
→ per round: RoundCard 3.0 → rolecard 1.6 (birdhunt) → countdown → play → cover 0.7 →
standings 2.5 + MachineVoice → settle 1.5 → interim 4.5 → **FINAL AUDIT ×2** → verdict 6.0
→ Podium 8.0 → rematch (grace 6, carried readiness). Watchdog `RoundSeconds+15+20` aborts
the trial, never the session. Additions:

1. **SHIFT REPORT beat** (`Pacing.Timing.ShiftReport=5.0`, between verdict and podium
   teardown): one `MachineState` packet `kind="shiftreport"` with per-player
   XP/streak/quest/badge deltas + `openSeats` — landing while all 2–4 players are
   co-present, because *seeing your friend's number go up* is the re-queue trigger in tiny
   servers. (Codex renders it.)
2. **Rematch streak:** `room.rematchCount`; at 3 consecutive, a dedicated voice pool
   (`OVERTIME APPROVED_`) and `playableOrder` biases the least-recently-played trial first.
3. With 3 trials, prefer seeds whose FINAL AUDIT lands on canteen or birdhunt
   (high-variance closers) so the ×2 gives trailing players a real swing.

## 4. Lighting — the blue shift (E4; LightingStyle=Soft kept, no Future cost)

**Ruling: the world goes cold PS2 industrial blue; the Machine's phosphor-green CRT stays
green** — green becomes the diegetic signature of the Machine, the only "living" color in a
blue facility. No GUI change needed. World materials avoid the green hue band;
`TrialKit.PALETTE` Signal/Hazard telegraph colors shift to cyan `#41D9FF` / amber `#FFB13B`
(contrast-checked against every blue grade).

**Step 1 — repair the damaged live Lighting** (measured 29.08: `FogStart=823/FogEnd=832`
razor band one edit from a divide-by-zero, `FogColor` HDR-white out of range, warm grey-red
ambient): global baseline `Ambient (38,46,66)`, `OutdoorAmbient (56,68,94)`,
`Brightness 1.0`, `ClockTime 17.6`, `FogColor (16,22,34)` clamped 0–255, **Fog 40/480**
(FogEnd ≤480 preserves the ≥480-stud arena-spacing invisibility rule), keep
`GlobalShadows=false` + `EnvironmentDiffuse/Specular=0` (core of the PS1 flatness).
`KenopsiaSky_PS1` gets a blue-graded twin (`KenopsiaSky_PS1_Blue`, same 15-bit + Bayer
pipeline, StarCount 0). Snapshot this repaired state as the grade-restore truth.

**Step 2 — GradeDirector.** `SimulationGrade.client` was removed from the live place on
27.08 (archived); the mirror still has it — reconcile explicitly, then rebuild as
`GradeDirector.client.luau` (fresh LocalScript, presets in
`Shared/Config/GradePresets.luau`): per-trial data presets `{ambient, outdoorAmbient,
fog*, atmosphereDensity, ccSat, ccContrast, ccTint, camQuant}`; snapshot/restore
byte-compared (mismatch logs a `GradeRestoreMismatch` attribute); quantisation
position-only 1/8 stud in the existing RenderStepped writer; off in sniper scope +
ReducedMotion + `KenopsiaSimFilter`. New `tests/grade.lua` (Lua-5.1 pure) asserts: fog band
width ≥120, all colors 0–255, sat ∈ [−0.5, 0], **per-trial ambient luminance floor** —
permanently killing the degenerate-fog and black-screen classes.

**Per-trial grades:** DEAD ZONE = coldest near-night steel (ambient (34,40,56)/(14,18,28)
— the proven zero-lights-readable floor; fog 30/260; the compactor gets the trial's only 2
amber lights: dread by contrast). BIRD HUNTING = brightest pale-blue overcast (fog 60/420;
the runner must read at 315 studs on a phone). CANTEEN = the one warm room — sodium lamp
pools (255,241,222) against blue fog at the windows; lamp flicker ≤3 transitions/s
dim-channel only. The per-character fill light shifts to (214,228,255) so warm skin atlases
pop like PS2 FMV.

## 5. Smoothness / performance / mobile black-screen fix

**Budgets (gates):** mid-range Android 60fps; server Heartbeat <4ms @4p; <300 static parts
per procedural arena; ≤12 live local lights per arena; 0 per-frame writes inside
`KenopsiaMachine` (HUD lives in `KenopsiaTrialHud`); <1 DataStore write/player/round; phone
MicroProfiler gate (#20) on any lighting/overlay change.

**Black-world fix** (established root cause: low quality levels drop local lights entirely
— the P3.1 isolation):

1. **Ambient-floor rule (primary):** every arena must be playable with ALL local lights
   culled; lights are additive pools only. Asserted in `tests/grade.lua`.
2. **Measurement, not anecdotes:** `MobileProbe.client.luau` gains a luminance self-test
   (render a grey calibration part 1s after spawn; if effectively black → the client raises
   its own ambient delta and fires a `MobileBlackScreen {qualityLevel}` telemetry event).
   Texture-memory audit via `Stats` GraphicsTexture on a real phone.
3. **Memory diet:** park `Workspace.RunnerVsCars` (257 parts, 339 models, zero code
   binding) into `ServerStorage.KenopsiaArenasParked`; **512px nearest-upscaled atlas
   twins** for arena textures swapped on low quality/mobile via an `AtlasTiers.luau` table
   (at PS1 texel density, 512 is visually identical on a 6" screen); purge `RBX_ANIMSAVES`
   (29,785 instances = 74% of the datamodel) **from the published place only** after a
   live-server clip verification pass, keeping a Studio authoring save for the fallback
   bridge; F-16 lamp de-dupe (48 doubled lights → 12, also fixes the z-fighting);
   `ContentProvider:PreloadAsync` the active trial's atlas set during blackout covers.

**Feel:** every verb gives client-first feedback within 80–120ms (sonar ring, stab click,
hitmark, push render locally on send; server reconciles); kills stay server-authoritative;
90ms victim hitstop (`Feel.Hitstop=0.09` — pause the Animator, not physics, so it survives
mobile); camera writes only in the single RenderStepped writer; all 14 player clips
prewarmed at spawn (shipped T-pose fix), boss clips prewarmed on arena ensure.
`StreamingEnabled` stays false.

## 6. Retention — the player-return loop

**North star:** join → first input <20s → 3 trials ≈ 9 min → verdict → **SHIFT REPORT** →
rematch, or leave with an unclaimed WORK ORDER pulling you back tomorrow.

- **`Services/Profiles.luau`** (hand-rolled ~150-line module, not the vendored
  ProfileService package): DataStore `KenopsiaProfile_v1`, key `u_<UserId>`, `UpdateAsync`
  session locking (steal >180s; on failure a **volatile session profile** — play is never
  blocked, the report shows `RECORDS OFFLINE_`). Writes at exactly verdict /
  `PlayerRemoving` / `BindToClose`. `schemaVersion` migrate-on-load chain. Schema:
  firstSeen/sessions/viableCount/bestBand; per-trial stats (plays/wins/best +
  tags/cleanPlates); `streak {current, best, lastDayStamp, shield}`; `xp`; `clearance`;
  `quests {day, slots, progress, claimed}`; `emotes {owned, equipped, wheel[8]}`;
  `crates {keys, fragments}`; `settings`. S→C `ProfileState` packet = the UI contract.
- **The Machine remembers you** (cheapest, strongest lever): MachineVoice greeting pool
  keyed off the profile — `SHIFT 14. WELCOME BACK_`, `NIGHT 3 CONSECUTIVE. NOTED_`,
  personal-record lines on beating `trials.<id>.best`. ≥12 new lines, text-only, uppercase.
- **CLEARANCE** (diegetic rank, cosmetic-only — XP never touches gameplay numbers):
  PROBATIONARY → GRADE D/C/B/A → OVERSEER CANDIDATE; unlocks desaturated jumpsuit tints
  (`KenopsiaTint` attribute, applied by `CharacterService`), podium stinger variants,
  emote-wheel slots. XP: round survived 25 / round won 40 / trial won 60 / VIABLE 150 /
  REJECTED 50 / daily first session 200.
- **Daily streak with a shield** (survives one missed day per 7, silently consumed — friend
  groups are appointment-driven; a hard reset punishes the off night). **WORK ORDERS:**
  3 daily quests rolled from `ProgressionRules.QuestPool`, sized so an average session
  completes **1 of 3, never all** (the report always shows the nearest incomplete order);
  rewards XP + crate-key fragments (5 = 1 key). `Shared/Rules/ProgressionRules.luau` pure
  Lua-5.1 + `tests/progression.lua` (streak edge cases; every quest completable with only 3
  trials enabled).
- **Badges (6):** FIRST SHIFT, FIRST VIABLE, CLEAN SWEEP (every round of a *session*),
  THREE NIGHTS, FULL ROSTER, CO-WORKERS.
- **Social:** `SocialService:PromptGameInvite` at lobby + SHIFT REPORT when seats are open;
  Captures prompts on exactly 4 beats ≤3/session (via a tiny `CapturePrompt.client.luau`);
  Experience Notifications opt-in after first VIABLE + weekly NIGHT SHIFT; weekly
  OrderedDataStore subject wall on a lobby CRT SurfaceGui; paid private servers at a
  once-set price (open decision #5 — recommendation: 99 R$). *(Invites/captures/
  notifications are untestable in Studio — verified in the published DEV place.)*
- **`Services/Telemetry.luau`:** AnalyticsService funnel `Joined → FirstInput →
  RouletteSeen → Round1Done → VerdictSeen → RematchAccepted` + custom events
  (TrialCompleted, SessionVerdict, QuestClaimed, StreakTick, EmotePlayed,
  MobileBlackScreen) — the MASTERPLAN metric gates (bounce <60s, D1, co-play days) become
  measurable.

## 7. Cross-device input & audio

**Input:** per-trial `controlsText {Desktop, Mobile, Console}`; touch ≥64px pads via
`kit.pad()` only (finish F-12: replace the 7 hardwired legacy buttons); joystick
runner-roles only; console `GetStringForKeyCode` glyphs + SelectionGroup focus; new
buttons: DZ sonar (pad / `E` / gamepad X), canteen STAB + EAT stay two buttons.

**Audio (all uploads blocked on licence-ledger evidence, #46):** one base loop + one
intensity layer per trial form — DZ layer keyed to compactor proximity, BH to the final
leg, canteen heartbeat to the FSM (the layer doubles as a tell). **Split canteen off
minefield's shared track** (currently the same asset id — the biggest audio identity
leak). Fill the empty `Ambience` folder (one bed per arena family). New SFX slots:
`Canteen.Rustle`, `Minefield.SonarPing`, horn. Music −0.45; verdict stinger; podium
fanfare; SHIFT REPORT dot-matrix print SFX.

## 8. Gamepass / emote / crate hooks (sockets now, store later — E5)

- **Governance:** the 2-gamepass + crate-emote addition is recorded as PLAN.md decision E5
  (the previous "private servers only" stance is superseded). Zero pay-for-power. Crate
  keys are **earned only** (quests/streaks), never sold in MainGame; odds listed in DEV's
  crate ceremony — mild-maturity / no-gambling-optics safe.
- **`Shared/Config/EmoteRegistry.luau`:** `{ [emoteId] = {name, animKey,
  source="crate"|"robux"|"clearance", rarity} }`; `animKey` indexes `AnimationIds.Player`
  (`Dance` 104376411319913 ships as `dance_default`; **a new emote later = one registry row
  + one published clip**).
- **Remotes (created now, dormant):** `EmotePlay {emoteId}` — server validates ownership +
  lobby-only (`KenopsiaActiveTrial==""`) + rate gate, plays via a **dedicated `XBotEmote`
  attribute** (never `XBotMoves` values, which trigger legacy scan/eat/sneak/push client
  paths); `EmoteEquip {slot, emoteId}`; `ShopPrompt {sku}`. The wheel UI is Codex's, driven
  by `profile.emotes.wheel`.
- **Cross-place grants — RESOLVED 30.08.2026:** Kenopsia_DEV (129909297895850) and
  MainGame (110672791536316) **share universe 10640788131** (measured via the public
  `apis.roblox.com/universes/v1/places/<id>/universe` endpoint, both places). So the cheap
  path holds: **one shared DataStore** (`KenopsiaProfile_v1` — already live since P4a) plus
  `MessagingService "KenopsiaGrant"` for same-session sync. No Open Cloud bridge, no second
  schema; DEV's crate ceremony calls `Profiles.grantEmote` against the same key.
- **Gamepasses (2, ids later):** SKU slots in `Shared/Config/MonetizationConfig.luau`
  (e.g. cosmetic bundle + a future-mode pass); ownership live-checked via
  `UserOwnsGamePassAsync` pcall-cached 120s, never persisted as truth.

## 9. Content maturity (E6)

User directive 29.08.2026: **mild, ~14+, playable for everyone** — supersedes the "heavy
fantasy gore" answer recorded in RELEASE-CHECKLIST. Design language: implication over gore
(compactor hard-cut, execution flash + blackout, burgundy PS1 splats within shipped
GoreClient caps, no dismemberment, no horror extremes). Execution step: re-audit the
Creator Hub age questionnaire down to match and update RELEASE-CHECKLIST / #49 in the same
commit.

---

## Implementation phases (each phase = its own workflow, QA doc per MP protocol)

1. **Repair & derisk:** Lighting repair + blue baseline + sky twin; F-16 lamp de-dupe;
   park RunnerVsCars; MobileProbe luminance self-test + Telemetry skeleton; atlas-tier
   table. Gate: phone capture with no black frame.
2. **GradeDirector** + `GradePresets` + `tests/grade.lua`; per-trial blue grades; palette
   shift in `TrialKit.PALETTE`.
3. **Trial polish** (one trial per pass, cheapest risk first): canteen
   (suspicion/fake-lowers/hot peas/settlement/rustle) → DEAD ZONE (sonar economy/craters/
   speed-step/scrap tags) → BIRD HUNTING (reload lock/injury/push-topple/heartbeat/decoy
   birds). New FeelConfig keys asserted in `tests/feel.lua`.
4. **Retention:** `Profiles` + `ProgressionRules` + tests (ship dark) → SHIFT REPORT
   packet + XP/CLEARANCE/badges → streaks + WORK ORDERS + fragments →
   invites/captures/notifications (in the published DEV place).
5. **Sockets:** EmoteRegistry / remotes / MonetizationConfig + universe verification.
6. **Audio** (post-licence-evidence): loops + layers + ambience + new SFX.

**Key files:** `Services/` (MachineFlow, TrialKit, CanteenProtocol/Boss/Diner/Props,
Minefield, BirdHunting, CharacterService + new Profiles/Telemetry/EmoteService),
`Shared/Config/` (GameConfig, FeelConfig, AnimationIds + new GradePresets/EmoteRegistry/
MonetizationConfig/AtlasTiers), `Shared/Rules/` (Pacing, Scoring + new ProgressionRules),
`StarterPlayerScripts/` (new GradeDirector, CapturePrompt; MobileProbe extended;
**KenopsiaClient gains at most one funnel line per feature**), `tests/` (new
feel/grade/progression suites).

## Verification

- Offline: `tests/*.lua` (feel, grade, progression, existing suites) + StyLua/luau-lsp per
  the repo's gates.
- Studio: full 3-trial session in a DEV copy via real input (`user_mouse_input` —
  synthetic clients are banned per F-1); grade snapshot/restore byte-compare on every trial
  exit; standings/report packets observed in the client datamodel.
- Device: phone MicroProfiler capture (#20) of a full session — no black frame, 60fps,
  texture memory logged; console focus pass.
- Live: Telemetry funnel populating in Creator Analytics; DataStore write counts
  ≤1/player/round; badges awarding in the published DEV place.

**Open user decisions (not blockers to start):** private-server price (#5), confirm the
2-gamepass SKU contents, audio licence evidence (#46) before any audio ships.
