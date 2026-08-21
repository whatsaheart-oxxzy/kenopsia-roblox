# 02 — Alle Skripte

21 Skripte, **386 043 Bytes** Quelltext. Keines ist `Disabled`.
Zeilennummern beziehen sich auf den **Live-Stand vom 21.08.2026**.

## Inventar

| Pfad | Klasse | Bytes | Repo-Abgleich |
|---|---|---:|---|
| `ServerScriptService.KenopsiaServer.Main` | `Script` | 340 | — |
| `…Services.RoomService` | `ModuleScript` | 19 829 | identisch |
| `…Services.MachineFlow` | `ModuleScript` | 22 840 | **abweichend** (Repo: 27 222) |
| `…Services.BirdHunting` | `ModuleScript` | 34 419 | identisch |
| `…Services.Minefield` | `ModuleScript` | 36 455 | identisch |
| `…Services.CanteenProtocol` | `ModuleScript` | 32 701 | identisch |
| `…Services.CanteenProps` | `ModuleScript` | 22 691 | identisch |
| `…Services.CanteenDiner` | `ModuleScript` | 13 430 | identisch |
| `…Services.CanteenBoss` | `ModuleScript` | 10 816 | identisch |
| `…Services.Contexts` | `ModuleScript` | 8 406 | identisch |
| `…Services.BloodFX` | `ModuleScript` | 7 019 | identisch |
| `ReplicatedStorage.Kenopsia.Shared.Config.GameConfig` | `ModuleScript` | 1 756 | **abweichend** |
| `…Shared.Config.AnimationIds` | `ModuleScript` | 7 523 | — |
| `…Shared.Rules.Pacing` | `ModuleScript` | 4 057 | **abweichend** |
| `…Shared.Rules.Playlist` | `ModuleScript` | 2 691 | **abweichend** |
| `…Shared.Rules.Scoring` | `ModuleScript` | 4 630 | identisch |
| `…Shared.Net.Envelope` | `ModuleScript` | 6 512 | identisch |
| `ReplicatedStorage.KenopsiaAssets.Effects.Blood.BloodEffect` | `ModuleScript` | 6 802 | — |
| `StarterPlayer.StarterPlayerScripts.KenopsiaClient` | `LocalScript` | 79 433 | **abweichend** |
| `…StarterPlayerScripts.MachineLayout` | `LocalScript` | 10 922 | **abweichend** |
| `…StarterPlayerScripts.GoreClient` | `LocalScript` | 14 221 | — |
| `StarterPlayer.StarterCharacterScripts.Health` | `Script` | 134 | — |
| `ReplicatedFirst.KenopsiaLoading` | `LocalScript` | 3 840 | — |

**Im Repo, aber NICHT im Place:** `TrialKit.luau` (29 774 B), `TrialClientKit`,
`TrialRules`, 12 Trial-Module, 12 `*Rules`, 12 `TrialClients/*`.
Siehe [`07-FINDINGS.md`](07-FINDINGS.md) F-04.

---

## `Main` (Script, 340 B) — vollständig

```lua
--!nonstrict
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.KenopsiaServer.Services
local RoomService = require(Services.RoomService)
local MachineFlow = require(Services.MachineFlow)

RoomService.start()
MachineFlow.start(RoomService)

print("[Kenopsia] server ready (main game)")
```

## `Health` (Script, 134 B) — vollständig

```lua
-- absichtlich leer: ersetzt Roblox' Standard-Regeneration.
-- Verletzungen (Body-Shots) bleiben bis zum Health-Reset am Rundenstart.
```

---

## `RoomService` (19 829 B)

> **CANONICAL ROOM (Phase 1).** Ein Server hostet genau *einen* Raum für 2–4 Spieler.
> Die alte Mehrraum-Lobby ist ausgebaut; die `create`/`join`/`quick`-Remotes überleben
> nur als Shims, die jeden Aufrufer auf diesen einen Raum auflösen, damit bestehende
> Clients weiterlaufen.
>
> Lebenszyklus: `Waiting → Starting → Playing → Waiting`, bei fatalem Fehler
> `Playing → Aborting → Cleanup → Waiting`. `MachineFlow` besitzt, was *innerhalb*
> von `Playing` passiert, und beobachtet Abbrüche über `room.phase` und `room.sessionId`.
>
> Bewusst konserviert: `room.members` behält die Form `{userId, displayName, ready}`
> und `room.phase == "Playing"` behält seine Bedeutung, weil `BirdHunting` und
> `Minefield` beides lesen. Nachzügler landen deshalb in `spectators` und werden
> **nie** mitten im Match an `members` angehängt.

| Zeile | Definition |
|---:|---|
| 34 | `local room = {` |
| 74 | `allow(player, key, perSecond)` — Ratenbegrenzung |
| 87 | `fail(player, message)` |
| 93 | `minPlayers()` |
| 101 | `publicState()` |
| 137 | `broadcast()` |
| 146 | `memberIndex(userId)` |
| 153 | **`RoomService.isParticipant(_room, userId)`** |
| 160 | **`RoomService.audience(_room)`** |
| 169 | `addMember(player)` |
| 180 | `addSpectator(player)` |
| 186 | `promoteSpectators()` |
| 196 | `clearReady()` |
| 201 | `toWaiting()` |
| 228 | `cleanupToWaiting(reason)` |
| 239 | `abortMatch(reason)` |
| 252 | **`RoomService.abort(_room, reason)`** |
| 254 | `allReady()` |
| 262 | `abortCountdown(reason)` |
| 276 | `beginCountdown()` — mint `sessionId = "S<n>-<ms>"`, Snapshot `participants` |
| 311 | `maybeAutoStart()` |
| 320 | `removeMember(userId)` |
| 344 | `setReady(player, ready)` |
| 367 | `seat(player)` |
| 380 | **`RoomService.autoSeat(player)`** |
| 384 | **`RoomService.roomOf(player)`** |
| 390 | **`RoomService.getRoom(id)`** |
| 395 | **`RoomService.canonical()`** |
| 399 | **`RoomService.waitingRooms()`** |
| 405 | **`RoomService.cancelled(sessionId)`** — `phase ~= "Playing" or sessionId ~= …` |
| 427 | **`RoomService.setStage(sessionId, stage)`** |
| 443 | **`RoomService.setWaitingStage(token, stage)`** |
| 467 | `local PROGRESS_FIELDS = {` |
| 478 | **`RoomService.setProgress(sessionId, patch)`** |
| 513 | **`RoomService.finishRun(_room)`** |
| 518 | `ensureRemotes()` |
| 547 | **`RoomService.start()`** |

Remotes: `LobbyError`, `RoomState`, `RoomCreateRequest`, `RoomJoinRequest`,
`RoomQuickJoinRequest`, `RoomLeaveRequest`, `RoomReadyRequest`, `RoomStartRequest`.

---

## `MachineFlow` (22 840 B)

> **MATCH FLOW (Phase 1).** Besitzt alles innerhalb von `RoomService`s `Playing`-Phase:
> `Selecting → Briefing → Trial → Score → Final Score`, und wickelt über ein
> finally-artiges Cleanup ab — bei sauberem Ende wie bei Abbruch.
>
> Gate 1 machte aus dem einen Roulette-Treffer eine SESSION: jedes aktivierte Trial
> wird einmal gespielt, in seed-gemischter Reihenfolge, ohne Rückkehr in die Lobby
> dazwischen. Die Schleife iteriert `#order` statt einer fest verdrahteten Drei.
>
> Die Trial-Module werden noch mit ihren BESTEHENDEN Signaturen aufgerufen.
> `RoundContext` in sie hineinzureichen gehört zu Gates 2/3/4.

| Zeile | Definition |
|---:|---|
| 42 | `local TRIALS = {` — die Registry, siehe unten |
| 96 | `trialById(id)` |
| 104 | `enabledTrials()` |
| 124 | `newRoundToken(sessionId)` |
| 131 | `buildContext(room)` |
| 155 | `tell(ctx, payload)` |
| 162 | `tellRoom(room, payload)` |
| 171 | `hold(ctx, seconds)` |
| 180 | `setActiveTrial(ctx, trialId)` — setzt Attribut `KenopsiaActiveTrial` |
| 189 | `runSelection(room)` — das Roulette |
| 227 | `preFlow(room)` |
| 268 | `playableOrder(seed)` |
| 281 | `runMatch(room)` — der Hauptloop |
| 574 | **`MachineFlow.start(RoomService)`** |

Remote: `MachineState`. Decoy-Icons: `Magnifier, Saw, Factory, Train, Bug`.

### Die Trial-Registry (`local TRIALS`)

| Feld | `birdhunt` | `minefield` | `canteen` |
|---|---|---|---|
| `displayName` | `BIRD HUNTING` | `DEAD ZONE` | `CANTEEN PROTOCOL` |
| `icon` | `Crosshair` | `Cube` | `Saw` |
| `subtitle` | `THE SIGHTLINE NEVER BLINKS._` | `READ THE FLOOR. KEEP MOVING._` | `RATION ISSUED. EAT ONLY WHEN UNOBSERVED._` |
| `tagline` | `A BULLET WITH YOUR NAME ON IT.` | `SCAN AHEAD. WATCH YOUR STEP.` | `FREEZE WHEN THE INSPECTOR LOOKS.` |
| `ready` | `true` | `true` | `true` |
| `showInterRoundScore` | `false` | `false` | `false` |
| `module` | `BirdHunting` | `Minefield` | `CanteenProtocol` |

> Der Kommentar über dem `canteen`-Eintrag ist veraltet: er behauptet
> `ready STAYS false`, das Feld darunter steht auf `true`. Siehe
> [`07-FINDINGS.md`](07-FINDINGS.md) F-20.

Ein Trial wird nur eingeplant, wenn **beide** Tore offen sind: Eintrag in
`GameConfig.Playlist.TrialIds` **und** `ready = true` hier.
`showInterRoundScore` ist tot — es gibt keine Rundenkarte mit Punkten.

---

## `BirdHunting` (34 419 B) — "BIRD HUNTING"

Kein Header-Kommentar. Zählt **Legs**, nicht Runden: ein Leg pro geplantem Hunter.

| Zeile | Definition |
|---:|---|
| 56 | `finiteComponent(component)` |
| 63 | `cleanDirection(value)` |
| 73 | `aimWithinBounds(dir, baseAim)` |
| 83 | `ensureRemote()` |
| 127 | `refs()` — löst die Marker aus `workspace["Bird Hunting"]` auf |
| 150 | `buildTurret(parent)` — baut `SniperTurret`/`Mount`/`Barrel` |
| 208 / 222 | `acquireTracer()` / `releaseTracer(part)` — Pooling |
| 232 / 257 | `acquireSpark()` / `releaseSpark(holder)` — Pooling |
| 271 | `aimTurret(model, eye, dir)` |
| 279 | `livingOf(room)` |
| 297 | `roomActive(room)` |
| 302 | **`BirdHunting.init()`** |
| 306 | `runLeg(room, roundIndex, forcedHunterUserId, legIndex, legTotal, guard)` |
| 637 | `roundState.shoot = function(dir)` |
| 899 | `waitForArena(room)` |
| 923 | **`BirdHunting.runRound(room, roundIndex, forcedHunterUserId, legIndex, legTotal)`** — 5 Argumente, als einziges Trial |

Remotes: `SniperFire`, `SniperAim`. Nutzt `Remotes:FindFirstChild("MachineState")`.

Punktetafel (aus `MachineLayout.TRIAL_TEXT.birdhunt.scoring`):

```
Headshot     instant  +100
Body shot    2 to drop
Winged       +15 / kill +60
Escape       +100 & time
Timeout      distance only
```

---

## `Minefield` (36 455 B) — "DEAD ZONE"

> **DEAD ZONE: gemeinsames Minenfeld.** Minen sind unsichtbare Zellen unter dem Boden;
> ein Scanner-Puls (Taste F/Y) pulst eine Welle und deckt Minen im Nahbereich
> persönlich auf. Explosionen töten im Kernradius, werfen Überlebende in den
> Zombie-Crawl und lassen Krater zurück. Marker stammen aus dem von Hand gebauten
> `workspace["Dead Zone"]`.

| Zeile | Definition |
|---:|---|
| 89 | `refs()` |
| 105 | `livingOf(room)` |
| 119 | `roomActive(room)` |
| 126 | `stillRunning(state, exceptUserId)` |
| 134 | `audienceOf(room)` |
| 144 | `buildGrid(R)` |
| 159 | `cellCenter(g, col, row)` |
| 166 | `cellOf(g, pos)` |
| 173 | `carvePaths(g)` — garantiert lösbare Pfade |
| 203 | `announce(room, payload)` |
| 212 | `tellOne(userId, payload)` |
| 218 | **`Minefield.init()`** |
| 272 | `runRoundInner(room, roundIndex, guard)` |
| 907 | **`Minefield.runRound(room, roundIndex)`** |

Remote: `TrialInput`. Baut zur Laufzeit `DZ_Runtime` mit `Compactor` /
`Housing` / `WarnStrip` / `Roller` / `Tooth`.

Steuerung: `Move` + `Use sonar [HOLD]` (Konsole: `HOLD Y`).

---

## `CanteenProtocol` (32 701 B) — "CANTEEN PROTOCOL"

> **Iss alles vom Teller, ohne gesehen zu werden.** Das ersetzt den
> TableManners-Rhythmus-Prototypen, es repariert ihn nicht. Die alte Mechanik war
> "drück im Takt". Diese ist ein Versteckspiel: das Essen ist gratis, das Schlucken
> bringt dich um.
>
> **MECHANIK.** Alle essen gleichzeitig, jeder am eigenen Teller. 16 Erbsen. Die
> Gabel trägt höchstens 4. Zwei Aktionen:
> `PLATE` Teller → Gabel, lädt bis zur Restkapazität — **immer sicher**.
> `MOUTH` Gabel → Mund, verbraucht die GANZE Ladung — detektierbar.
> Eine leere Gabel zum Mund ist ein harmloser Fehlschlag: kostet die Abklingzeit und
> sonst nichts, damit Dauerdrücken sich selbst bestraft statt verboten zu sein.
>
> **DER OBSERVER IST VOLLSTÄNDIG SERVERSEITIG.**
> `hidden 2.0–4.0 s → lowering 0.35 s → watching 0.9–1.8 s → raising 0.30 s`
> Der Client wird über die Phase informiert, damit er eine Warnung zeichnen kann; er
> entscheidet nie, ob jemand gesehen wurde. Ein Client, der über die Phase lügt,
> ändert nur, was sein eigener Spieler auf dem Bildschirm sieht.
>
> **WARUM `lowering` EXISTIERT:** es ist der Tell. Ohne sichtbaren Anlauf ist der
> Observer ein Münzwurf und der Spieler hat keine Entscheidung. 0,35 s reichen, um
> ein noch nicht begonnenes Schlucken abzubrechen, und reichen nicht, um ein
> begonnenes zu retten.

| Zeile | Definition |
|---:|---|
| 92 | `local MARKER_GROUPS = {` |
| 111 | `arena()` |
| 151 | **`CanteenProtocol.validateArena()`** — Tor vor jeder Runde |
| 273 | `livingOf(room)` |
| 287 | `remotes()` |
| 291 / 301 | `announce(room, payload)` / `tellOne(userId, payload)` |
| 308 | `pushState(st, userId)` |
| 329 | `roundActive(st)` |
| 337 | `eliminate(st, userId, reason)` |
| 401 | `setPhase(st, phase, duration)` |
| 413 | `sweep(st)` |
| 422 | `sleepWhileActive(st, duration)` |
| 431 | `runObserver(st)` |
| 462 | `handleAction(player, action)` |
| 551 | **`CanteenProtocol.init()`** |
| 574 | `cleanupRound(st)` |
| 626 | **`CanteenProtocol.cleanup(ctx)`** |
| 636 | `waitForArena(room)` |
| 651 | `runRoundInner(room, roundIndex, guard)` |
| 891 | **`CanteenProtocol.runRound(room, roundIndex)`** |

Remote: `TrialInput`. Aktionen: `plate`, `mouth`.

---

## `CanteenProps` (22 691 B)

> **Die physischen Requisiten: Erbsen, Gabeln und der Observer.**
>
> **WARUM DAS SERVER-INSTANZEN SIND UND KEIN CLIENT-HUD.** Die drei Dinge, die ein
> Spieler lesen muss, sind: wie viel Essen übrig ist, wie voll die Gabel ist, und ob
> der Observer schaut. Alle drei sind Serverzustand. Sie als echte Parts zu bauen
> heißt: die Zahl des Servers IST das Bild — es gibt keine zweite Kopie der Wahrheit
> auf dem Client, die auseinanderdriften kann, und kein Payload, das stumm nichts
> rendert, weil der Client dieses `kind` nicht kennt. Dieser Fehler ist in diesem
> Projekt schon einmal passiert (`kind = "select"` zeichnete nichts).
>
> **AUSTAUSCHBAR**, genau wie `MF_Compactor` und `BH_Turret`. Ein Modell namens
> `CP_Observer`, `CP_Fork` oder `CP_Pea` in
> `ServerStorage.KenopsiaAssets.Props.CanteenProtocol` ersetzt den prozeduralen Bau
> ohne Codeänderung.
> `CP_Observer` will seinen PrimaryPart an der Linse, Blick nach `-Z`.
> `CP_Fork` will seinen PrimaryPart am Griff, Zinken nach `+Z`.
> `CP_Pea` ist ein kleiner Part oder ein Modell; wird 16× pro Teller geklont.
>
> **KEINE KONSTANTE IST AUS `CanteenProtocol` DUPLIZIERT.** Erbsenzahl,
> Gabelkapazität und Essfenster kommen über `opts` — zwei Kopien einer Regel driften
> auseinander, und die Drift ist unsichtbar, bis ein Spieler nach der falschen
> bewertet wird.

Funktionen: `templates` (53), `decorate` (59), `pivotOf` (73), `setPivot` (77),
`setVisible` (85), `makePea` (100), `makeFork` (118), `makeObserver` (149),
`poseFork` (199), `poseObserver` (222), `seatSurfaceY` (249),
**`CanteenProps.build(arena, opts)`** (261).

---

## `CanteenBoss` (10 816 B)

> Visueller Darsteller für den Observer-Zustand. Die Spielhoheit bleibt bei
> `CanteenProtocol`. Dieses Modul besitzt nur den Low-Poly-Akteur, seine vier
> publizierten Animationsspuren und die serielle Ausführungs-Warteschlange. Jeder
> Callback ist generationsgeschützt, damit eine abgebrochene Runde keinen späten
> Schuss in die Lobby feuern kann.

Funktionen: `findTemplate` (35), `seatedPelvisOffset` (49), `setPistolVisible` (56),
`stopTracks` (63), `playTrack` (71), `holdReading` (82), `applyPhase` (94),
`waitCurrent` (119), `fireOnce` (128), `finishShot` (135), `pump` (142),
**`CanteenBoss.spawn(marker, parent, opts)`** (173),
**`.setPhase(self, phase, duration)`** (279), **`.execute(self, onFire, onDone)`** (286),
**`.destroy(self)`** (301).

---

## `CanteenDiner` (13 430 B)

> **Der sichtbare PS1-Körper an jedem besetzten Platz.** Spiegel von `CanteenBoss`
> für die Esser. Der echte Roblox-Charakter bleibt das Spielsubjekt (Humanoid,
> Health, BloodFX-Ziele) und wird von `CanteenProtocol` lediglich unsichtbar
> gemacht; dieser Akteur ist das, was die Tischkamera sieht.
>
> **DER DINER IST STILL.** Kein Idle-Loop, kein Atmen, kein Zappeln: ein Tisch
> regloser Figuren ist die ganze Atmosphäre des Referenzspiels, und es macht die
> Bewegung des Observers zum einzigen, was sich auf dem Bildschirm bewegt. Die
> sitzende Pose ist ein BIND-POSE-Offset (siehe `sit`), kein Clip — der Rig hält sie
> ewig zum Nulltarif. Nur zwei Momente animieren:
> `Eat` für ein Essfenster → `eat(duration)` (nur mit echter ID)
> `Death` einmal, auf dem letzten Frame gehalten → `die()`

Funktionen: `findTemplate` (35), **`CanteenDiner.metrics()`** (47),
**`.scaleFor(seatY, mouthY)`** (64), `stopAll` (73), `rotateBoneWorld` (82),
`sit` (105), **`.spawn(marker, parent, seatIndex, opts)`** (127),
**`.headPosition(self)`** (219), **`.eat(self, duration)`** (228),
`parkAtEnd` (259), **`.die(self)`** (268), **`.destroy(self)`** (300).

---

## `Contexts` (8 406 B)

> **Wer spielt, welches Trial, welche Runde — und wie das alles abgebaut wird.**
> Drei geschachtelte Scopes, jeder besitzt genau eine Lebensdauer:
> `SessionContext` ein Match · `TrialContext` ein LAUF eines Trials ·
> `RoundContext` eine Runde, und bei Bird Hunting ein LEG.
>
> **WARUM TOKENS, UND WARUM PRO LEG.** Jeder Kontext trägt ein Token, das im
> Paket-Envelope auftaucht. Ein Paket wird nur behandelt, wenn sein Token das
> AKTUELLE ist — das macht ein abgefangenes Paket in dem Moment wertlos, in dem
> seine Runde endet. Bird Hunting ist der Grund für `newLeg`: ein Leg ist ein
> vollständiger Austausch Hunter-gegen-Runner und verhält sich wie eine Runde, aber
> mehrere Legs teilen sich einen Rundenindex. Änderte sich das Token nur pro Runde,
> würde ein in Leg 1 abgefangener Schuss noch in Leg 3 validieren.
>
> **WARUM JEDER VERZÖGERTE CALLBACK `isActive()` PRÜFT.** Fast jeder Bug, dessen
> Verhinderung diese Datei existiert, hat dieselbe Form: etwas wurde mit `task.delay`
> oder `task.spawn` geplant, die Runde endete, und der Callback lief trotzdem — bewegte
> eine Kamera, die zum nächsten Trial gehört, vergab einen Punkt in einer …

API: `Contexts.newCleanupScope()` (52), `CleanupScope:add/run/isDone` (59/78/90),
`RoundContext:isActive/newLeg/cancel/envelopeExpectation` (99/106/114/120),
`TrialContext:isActive/newRound/cancel` (135/139/154),
`SessionContext:isActive/_nextToken/newTrial/cancel` (165/173/178/193),
`Contexts.newSession(roomId, participants, seed)` (203),
`Contexts.guardedRun(scope, fn)` (236).

---

## `BloodFX` (7 019 B, Server)

> **Schlanke Event-Zentrale.** Sichtbares Blut rendert jeder Client selbst
> (`GoreClient`) — null Server-Physik, minimale Replikation. Serverseitig bleiben nur
> Leichen (alle sehen dieselbe) und Blutquellen an kriechenden Chars.

| API | Zeile |
|---|---:|
| `BloodFX.sound(pos, name, recipients)` | 69 |
| `BloodFX.burst(pos, intensity, recipients)` | 70 |
| `BloodFX.pool(pos, size, recipients)` | 71 |
| `BloodFX.gibs(pos, count, long, recipients)` | 72 |
| `BloodFX.fountain(pos, recipients)` | 73 |
| `BloodFX.kill(pos, recipients)` | 74 |
| `BloodFX.hit(pos, recipients)` | 75 |
| `BloodFX.shatter(char, pos, recipients)` | 78 |
| `BloodFX.corpse(char, impulse, scope)` | 88 |
| `BloodFX.maim(char, recipients)` | 129 |
| `BloodFX.bleed(char, recipients, scope)` | 137 |
| `BloodFX.stopBleed(char)` | 155 |
| `BloodFX.clearClients(recipients)` | 164 |
| `BloodFX.clear(scope, recipients)` | 175 |

Remotes: `GoreEvent`. Effektordner: `KenopsiaFX`, Leichen als `Corpse`.

---

## `Envelope` (6 512 B) — **nicht verdrahtet**

> **Die Form, die jedes Client-Paket haben muss, und das Tor, das es passieren muss,
> bevor Trial-Code es ansieht.**
>
> Die Trials akzeptierten früher nackte `{trialId, action}`-Tabellen. Das reicht einem
> Exploit-Client, um einen Schuss aus einer beendeten Runde zu wiederholen, in einer
> Runde zu handeln, in der er nicht ist, oder NaN in eine Positionsprüfung zu füttern —
> und der empfangende Code konnte nichts davon von einem legitimen Paket unterscheiden,
> weil das Paket nichts trug, das es an einen Zeitpunkt band.
>
> | Feld | schließt |
> |---|---|
> | `v` | das Drahtformat — ein veralteter Client scheitert laut, nicht subtil |
> | `sessionId` | dieses Match, nicht das vorige |
> | `trialId` | dieses Trial, nicht ein anderes in derselben Session |
> | `trialToken` | dieser LAUF dieses Trials |
> | `roundToken` | diese Runde, bei Bird Hunting dieses LEG |
> | `seq` | streng steigend pro Sender — ein abgefangenes Paket kann auch innerhalb seiner Runde nicht wiederholt werden |
> | `action`/`data` | was der Spieler tat |

`Envelope.VERSION = 1` (36), `Envelope.Limits` (41), `isFiniteNumber` (48),
`vectorComponentsOk` (58), `scan` (69), `Envelope.build(ctx, seq, action, data)` (107),
`Envelope.validate(payload, expected)` (128).

**Kein Trial ruft `validate` auf.** Die drei Live-Trials akzeptieren das nackte Paket.
Siehe [`07-FINDINGS.md`](07-FINDINGS.md) F-07.

---

## `KenopsiaClient` (79 433 B, 2 334 Zeilen) — der Monolith

Kein Header außer `--!nonstrict`. Enthält Lobby, alle drei Trials, Kamera, Input,
Musik, Scope, Viewmodel und die Punktetafel-Animation in einer Datei.

**Behandelte Paket-Arten** (`p.kind == …`):
`announce`, `count`, `cpdone`, `cpend`, `cpmiss`, `cpobs`, `cpout`, `cpstate`,
`go`, `gorefx`, `hide`, `hitmark`, `huntersetup`, `info`, `mines`, `role`,
`round`, `score`, `selection`, `status`

**Rollen:** `none`, `runner`, `sniper`, `spectate`
**Gesendete Aktionen:** `pulse` *(die Canteen-Aktionen laufen über `cpSend`)*
**Attribute:** `DieAt`, `KenopsiaActiveTrial`, `KenopsiaSessionScore`, `Platform`,
`TrialId`, `XBotMoves`, `XBotRig`
**GUI-Zweige:** `Announce`, `Briefing`, `Fader`, `HipCross`, `Info`, `RoundCard`,
`Scope`, `Score`, `Selection`, `Status`, `TouchControls`

### Funktionsblöcke

| Bereich | Zeilen | Funktionen |
|---|---|---|
| Plattform / Layout | 46–162 | `touchAllowed`, `addSizeLimits`, `setLookSpeed` |
| Audio | 222–286 | `sfx`, `setLobbyMusic`, `updateTrialMusic` |
| Dead-Zone-Licht | 287–371 | `enterDZLight`, `exitDZLight`, `updateDZLight` |
| Bewegung | 372–451 | `bindForwardOnly`, `unbindForwardOnly`, `applyMovement` |
| Kamera | 452–556 | `spectateRoot`, `restoreCamera` |
| Sniper (birdhunt) | 557–787 | `alignHipCross`, `applyScope`, `destroyViewmodel`, `buildViewmodel`, `muzzleFlash`, `setOwnBodyHidden`, `setSniperRig`, `fireShot` |
| Runner / Crouch | 788–861 | `setCrouchTouch`, `charSneakAllowed`, `charPushAllowed`, `refreshCrouchBtn`, `watchMoves`, `setRunnerTouch` |
| Sonar (minefield) | 862–1076 | `charScanAllowed`, `spawnWave`, `firePulse`, `setScanHeld`, `refreshScannerHud`, `acquireMark`, `releaseMark`, `showMines` |
| Canteen | 1077–1335 | `charEatAllowed`, `buildCanteenHud`, `cpSetState`, `cpSetPhase`, `cpSend`, `buildCanteenTouch`, `cpShowHud`, `cpHideHud` |
| Lobby | 1461–1590 | `setSniperLight`, `updateReadyVisual`, `updateRoster`, `setTileLit` |
| Maschinen-Screens | 1591–1855 | `showSelection`, `showInfo`, `showStatus`, `showRound`, `rollDigit`, `showScore`, `showAnnounce` |
| Gore | 1856–1935 | `screenBlood`, `applyGoreFx` |

---

## `MachineLayout` (10 922 B)

> **Plattformabhängiges Layout für das `KenopsiaMachine`-GUI.** Die Maschinen-Screens
> wurden gegen ein ~710 px hohes Fenster mit Pixel-Offsets gebaut; das hier skaliert
> das Koordinatensystem jedes Screens pro Plattform, damit das Design seine
> Proportionen auf Telefonen, Desktops und Konsolen behält.
> `Mobile` verkleinert und schaltet Touch-Controls an, `Desktop` bleibt nahe am
> Originalmaßstab, `Console` skaliert für 10-Fuß-Abstand hoch und ist Gamepad-fokussiert.

`detectPlatform` (27), `platformScale` (46), `scaleObject` (58),
`TRIAL_TEXT` (79), `applyControlsText` (175), `applyButtonHints` (210),
`apply` (234), `bindCamera` (267), `PRIMARY` (296), `focusScreen` (301).

### `TRIAL_TEXT` — die Steuerungstexte

| | `birdhunt` | `minefield` | `canteen` |
|---|---|---|---|
| Abschnitt 1 | `RUNNERS:` | `RUNNERS:` | `DINERS:` |
| Abschnitt 2 | `HUNTER:` | `SONAR:` | `OBSERVER:` |
| Desktop 1 | Move | Move | Seated - no moving |
| Desktop 1b | Crouch [Ctrl] | Use sonar [HOLD] | Load fork [LMB] |
| Desktop 2 | Aim + Shoot | — | Swallow [RMB] |
| Desktop 3 | Scope [x2] | — | Never swallow while watched |
| Mobile 1b | CROUCH button | Use sonar [HOLD] | PLATE button loads |
| Mobile 2 | Drag Aim + FIRE button | — | MOUTH button swallows |
| Console 2 | RS Aim + RT Shoot | — | RT Swallow |
| Console 3 | LT Scope [x2], Y Zoom | — | Never swallow while watched |

`canteen`-Scoring-Text:
`Plate 16 rations` · `Fork holds 4` · `Loading always safe` ·
`Swallowing only unobserved` · `Finish first ranks highest`

> Der Kommentar über dem `canteen`-Block dokumentiert einen behobenen Bug: die
> Tabelle war früher auf den Namen des Referenzspiels geschlüsselt, nicht auf das,
> was der Server als `TrialId` setzt — sie traf nichts und fiel auf
> `TRIAL_TEXT.birdhunt` durch. Spielern wären die SNIPER-Controls angezeigt worden,
> während sie am Esstisch saßen.

---

## `GoreClient` (14 221 B)

> Rendert sämtliches Blut lokal (null Serverlast, null Lag). Tröpfchen sind
> simulierte Punkte: Heartbeat-Schleife mit Gravitation, pro Frame ein kurzer
> Raycast in Flugrichtung; beim Einschlag entsteht ein flacher Splat EXAKT auf der
> Flächennormale. Farben: tiefes Burgund (50,4,4 / 80,0,0), mattes SmoothPlastic für
> den flachen PS1-Look. Alles gedeckelt und selbstaufräumend.

`fxFolder` (29), `refreshRayFilter` (39), `evict` (49), `splatAt` (60),
`groundSplat` (89), `pool` (96), `spawnDroplets` (147), `burst` (186),
`gibs` (215), `fountain` (243), `BIRD_MUSIC_DUCK` (269), `duckBirdMusic` (278),
`playSound` (309), `clearAll` (332), `kill` (343), `maim` (356), `hit` (364),
`shatter` (371), `muteDeathSound` (411), `hookCharSounds` (425).

---

## `BloodEffect` (6 802 B, ReplicatedStorage)

Typisiertes Luau-Modul, kein Header. Gesteuert über Value-Objekte daneben
(siehe [`06-CONTRACTS.md`](06-CONTRACTS.md)).

`BloodEffect.Emit(origin, normal?, severity?, parent?) → (boolean, number)` (134),
`.Clear(parent?)` (200), `.SetEnabled(enabled)` (210), `.GetActiveCount()` (217).

---

## `KenopsiaLoading` (3 840 B, ReplicatedFirst)

> Sofort-Ladebildschirm: deckt den Beitritt ab, zeigt, wer verbunden ist, und weicht
> der Maschine in dem Moment, in dem der erste Lobby-Screen ankommt.

Baut `KenopsiaLoadingGui` mit `DisplayOrder = 100`, Titel `KENOPSIA` (34 px),
Statuszeile `connecting subjects` (17 px), Zählzeile (14 px).
