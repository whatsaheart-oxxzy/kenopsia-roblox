# P4-cross-place -- VERDICT: REFUTED

Claim: "The main-menu place writes the same profile as MainGame, with no coordination between them."

## Both halves are false.

### Half 1 -- "writes the same profile": the menu place writes NO profile at all.
[SOURCE] repo-wide `grep -rl DataStoreService --include=*.luau` -> exactly two files:
  globalTypes.d.luau (type stub) and studio-src/.../Services/Profiles.luau.
  ZERO hits under dev-src/.
[SOURCE] dev-src's only persistence API is MemoryStoreService, in PartyRegistry.luau:3,17 --
  hashmap "KenopsiaRooms_v1" (GameConfig.luau:35-37). Different service, different namespace.
[SOURCE] and PartyRegistry is DEAD: dev-src/.../Main.server.luau requires RoomService,
  PlaylistService, MenuPresenceService only. dev RoomService.luau:3 -- "PartyRegistry
  intentionally remains dormant".
[SOURCE] dev-src/.../UI/Theme.luau:120 -- "No DataStore in the MVP by design, so these reset on leave."
[RUNTIME] live MainGame (weppy, placeId 110672791536316), 115 scripts: DataStoreService in 1
  script (Profiles:32,621), MemoryStoreService in 0. Mirror matches live for this file.

=> KenopsiaProfile_v1 has exactly ONE writer in the whole repo, in MainGame.

### Half 2 -- "no coordination": three coordination mechanisms exist.
(a) [SOURCE] Profiles.luau:99-124,138-140 -- per-key {jobId, ts} session lock,
    LOCK_STALE_SECONDS=180, "cancel the write, keep the other server's lock". This is exactly
    the guard the claim says is missing; it is key-scoped so it would apply across places too.
(b) [SOURCE] Teleport handoff BOTH directions:
    dev PlaylistService.luau:8,166-169 ReserveServer + TeleportAsync -> 110672791536316
    MainGame SoloExit.luau:57,104 TeleportAsync -> 129909297895850
(c) [SOURCE] MessagingService topic "KenopsiaGrant_v1" -- EmoteService.luau:89,290,479,
    header 470-475 "The CROSS-PLACE path. DEV and MainGame share universe 10640788131 and the
    KenopsiaProfile_v1 DataStore". [RUNTIME] present live at EmoteService:89.

## Real finding (opposite direction): the cross-place path is HALF-BUILT.
EmoteService.luau:283-284 -- "DEV's crate ceremony calls this after it has written the durable
grant". No such caller exists: dev-src has no EmoteService, no MessagingService, no crate
ceremony, no DataStore write. MainGame is both publisher and subscriber of KenopsiaGrant_v1.
[RUNTIME] KenopsiaGrant_v1: 1 hit across 115 live scripts, in MainGame's own EmoteService.

## Grain of truth
The teleport carries NO payload: dev sets only opts.ReservedServerAccessCode, never
SetTeleportData; MainGame has ZERO GetJoinData / ReservedServerAccessCode / SetTeleportData /
ReserveServer hits [SOURCE grep, studio-src]. So no player state travels between the places.
That is "no state handoff", which is NOT the same as "both write the same profile".

## NEEDS_RUNTIME
[RUNTIME] weppy system_info connection: ONE plugin client, placeId 110672791536316. The menu
place 129909297895850 is NOT connected this session. Everything above about the menu place is
SOURCE-only (dev-src mirror). Settling observation: open Kenopsia_DEV in Studio and
`manage_scripts search path=game pattern=DataStoreService` -- 0 matches confirms REFUTED
outright; any match means live DEV drifted ahead of dev-src and the claim needs re-scoring.
