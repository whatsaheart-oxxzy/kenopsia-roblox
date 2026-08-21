# 06 — Verträge: Remotes, Pakete, Attribute, Konfiguration

Alles, was Server und Client zwischen sich vereinbart haben.

---

## 1. RemoteEvents

Alle Remotes werden **zur Laufzeit** unter `ReplicatedStorage.Kenopsia.Remotes`
angelegt — im Edit-Modus existiert der Ordner nicht. Die folgende Liste ist aus den
Quelltexten rekonstruiert.

### Lobby (`RoomService`)

| Remote | Richtung | Zweck |
|---|---|---|
| `RoomState` | S → C | vollständiger öffentlicher Raumzustand |
| `LobbyError` | S → C | Fehlermeldung, z. B. `"RUN ABORTED - MINIGAME ERROR"` |
| `RoomReadyRequest` | C → S | READY umschalten |
| `RoomStartRequest` | C → S | Start anfordern |
| `RoomLeaveRequest` | C → S | Raum verlassen |
| `RoomCreateRequest` | C → S | **Shim** — löst auf den kanonischen Raum auf |
| `RoomJoinRequest` | C → S | **Shim** |
| `RoomQuickJoinRequest` | C → S | **Shim** |

Die drei Shims existieren nur, damit ältere Clients nicht mit einem Fehler
abstürzen; es werden keine Codes mehr ausgegeben.

### Match

| Remote | Erzeuger | Richtung | Zweck |
|---|---|---|---|
| `MachineState` | `MachineFlow` | S → C | **der Hauptkanal** — jedes Screen-Paket |
| `TrialInput` | `Minefield`, `CanteenProtocol` | C → S | Spieleraktionen |
| `SniperFire` | `BirdHunting` | C → S | Schuss |
| `SniperAim` | `BirdHunting` | C → S | Zielrichtung |
| `GoreEvent` | `BloodFX` | S → C | Blut-Ereignisse |

> `Minefield` und `CanteenProtocol` legen **beide** ein Remote namens `TrialInput`
> an — wer zuerst kommt, gewinnt; der zweite findet es per `FindFirstChild`.
> `BirdHunting` benutzt stattdessen zwei eigene Remotes. Das
> `TrialKit`-Framework vereinheitlicht das auf ein einziges `TrialInput`.

---

## 2. Paketvertrag `MachineState` (Server → Client)

`KenopsiaClient` behandelt genau 20 Werte von `p.kind`:

### Lobby und Rahmen

| `kind` | Nutzlast | Wirkung |
|---|---|---|
| `selection` | Trial-Kandidaten, Icons | Roulette-Screen |
| `info` | `id, name, icon, index, total` | Info-Screen, `NEXT SIMULATION: <name>` |
| `status` | `lines = { … }` | Terminalzeilen, zeilenweise getippt (0,25 s/Zeile) |
| `round` | `n, total, verbs` | Rundenkarte |
| `score` | `board, trialId, index, total, final` | Punktetafel mit Odometer |
| `hide` | — | alle Screens ausblenden |
| `announce` | `text`, optional `style="death"` | Vollbildkarte. **Leerer Text = vollflächig schwarz** — so decken Trials Teleports ab |
| `count` | `n = 3…1` | Zähltext + SFX `Count3/2/1` |
| `go` | — | Startsignal, SFX `Confirm` |
| `role` | `role, watch, pos, look, roundToken` | Kamera-/Steuerungsrolle |
| `gorefx` | `pos, power` | lokaler Bluteffekt |
| `hitmark` | — | `"HIT"`-Indikator des Snipers |

### Trial-spezifisch

| `kind` | Trial | Zweck |
|---|---|---|
| `huntersetup` | birdhunt | Sniper-Rig, Viewmodel, Scope aufbauen |
| `mines` | minefield | aufgedeckte Minen an einen Spieler |
| `cpstate` | canteen | Erbsen, Gabelladung, gegessen, gesamt |
| `cpobs` | canteen | Observer-Phase |
| `cpmiss` | canteen | leere Gabel zum Mund |
| `cpout` | canteen | ausgeschieden |
| `cpdone` | canteen | Teller leer |
| `cpend` | canteen | Runde vorbei |

### Rollen

| Rolle | Bedeutung |
|---|---|
| `runner` | läuft, Vorwärtsbindung aktiv, Kamera folgt |
| `sniper` | Turm, Viewmodel, Scope, Fadenkreuz |
| `spectate` | feste Kamera bei `pos` blickt auf `look`, wechselt durch `watch` |
| `none` | löscht die Rolle **und den `roundToken`** |

> Das `role`-Paket ist der **einzige** Kanal, über den ein `roundToken` heute zum
> Client gelangt. Ein Trial, das nie ein Rollenpaket sendet, hat keine funktionierende
> Eingabe. `TrialKit` ersetzt das durch `ev="begin"`.

---

## 3. Attribute

### Am Spieler (`Player`)

| Attribut | Setzer | Bedeutung |
|---|---|---|
| `KenopsiaActiveTrial` | `MachineFlow.setActiveTrial` | ID des laufenden Trials, `""` zwischen Runden |
| `KenopsiaSessionScore` | `MachineFlow` | kumulierte Punkte dieser Session |
| `KenopsiaSessionWins` | `MachineFlow` | Siege dieser Session — **wird beim Verlassen verworfen** |
| `Platform` | `MachineLayout` | `Mobile` / `Desktop` / `Console` |
| `TrialId` | Client | für den Steuerungstext-Lookup |

### Am Charakter

| Attribut | Bedeutung |
|---|---|
| `XBotMoves` | erlaubte Bewegungen (`scan`, `eat`, `sneak`, `push` …) |
| `XBotRig` | welches Rig aktiv ist |
| `XBotCrawl`, `XBotScanning` | Zustandsflaggen |
| `DieAt` | Zeitstempel für einen geplanten Tod |

> Neue Trials dürfen `XBotMoves` **nicht** auf Werte setzen, die
> `scan`/`eat`/`sneak`/`push` enthalten — das löst die Alt-Trial-Pfade im Client aus.

### An Canteen-Markern (live justierbar)

| Marker | Attribut | Standard |
|---|---|---|
| `Rig.Seats.P1…P4` | `SeatIndex` | 1…4 |
| | `DinerScale` | `1` |
| | `DinerLift` | `0` |
| | `DinerSeated` | `true` |
| `Rig.BossSeat` | `BossScale` | `1` |
| alle übrigen `Rig`-Marker | `SeatIndex` | 1…4 |

### An importierten Modellen

`RBX_ReimportId` — eine GUID, die Roblox beim Mesh-Import setzt. Zwei Modelle mit
derselben GUID stammen aus demselben Import (`concrete block hiding` und
`concrete block hidin` z. B.).

---

## 4. `GameConfig` — vollständig

```lua
ProjectName = "Kenopsia"
Version     = "0.3.0"

Players = {
    MaximumPerServer = 4,     -- muss der publizierten Kapazität entsprechen
    MinimumForMatch  = 2,
    StudioTestMinimum = 1,    -- nur Studio-Solo, nie auf einem Live-Server
}

Room = {
    MaxPlayers      = 4,
    MinPlayers      = 2,
    RequireAllReady = true,
    CodeAlphabet    = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",  -- nur für den Join-Shim
    CodeLength      = 6,                                    -- es werden keine Codes ausgegeben
}

Playlist = {
    TrialIds        = { "birdhunt", "minefield", "canteen" },
    PlacementPoints = { 3, 2, 1, 0 },   -- EXISTIERT, WIRD ABER NICHT BENUTZT
}

Match = {
    FinalBoardHold = 12,   -- Sekunden vor der Rückkehr zu Waiting
    StartCountdown = 3,    -- Waiting -> Playing
}
```

> Die publizierte Kapazität stimmt: Game Settings > Places > Server Size steht auf 4.
> Die Edit-Modus-API meldet irreführend 60 — siehe [`07-FINDINGS.md`](07-FINDINGS.md) F-02.

---

## 5. `Pacing` — vollständig

```lua
ROUNDS = {
    minefield = { [2] = 4, [3] = 3, [4] = 3 },
    canteen   = { [2] = 3, [3] = 2, [4] = 2 },
}
LEGS = { [2] = 4, [3] = 3, [4] = 4 }      -- nur birdhunt

RoundSeconds = {
    minefield = 55,
    birdhunt  = 90,
    canteen   = 45,
}

Timing = {
    Reveal        = 3.5,   -- "NEXT SIMULATION: <name>", getippt
    Title         = 1.2,   -- In-Trial-Titelkarte (Planwert, kein Typewriter)
    RoundCard     = 3.0,   -- "Round n/m" plus Verbzeile
    RoundSettle   = 1.5,   -- Nachlauf nach einer Runde
    CountdownFrom = 3,     -- 3-2-1, eine pro Sekunde
    FadeMax       = 0.6,   -- Obergrenze für jede Überblendung
    InterimScore  = 4.5,   -- Punktetafel nach jedem Minispiel (Plan: 3.0)
    FinalScore    = 8.0,   -- Endtafel (Plan: 6.0)
    ControlCard   = 8.0,   -- Briefing; frühes Bestätigen erlaubt
}

TrialPointPool = 1700
```

`Pacing.roundsFor(trialId, playerCount)`:
`birdhunt` → `LEGS`-Zeile; sonst `ROUNDS[trialId]`-Zeile; **fehlt die Zeile,
kommt `nil` zurück und `MachineFlow` spielt stillschweigend eine Runde.**

Die Zeilenauswahl `row(counts, n)`: `n ≤ 2` → Zeile `[2]`, `n ≥ 4` → Zeile `[4]`,
sonst `[n]`. Solo wird bewusst auf die 2-Spieler-Zeile abgebildet.

> Die Kommentare erklären, warum `InterimScore` und `FinalScore` über den Planwerten
> liegen: die Screens tippen ihren Text (Info ~26 Zeichen/s, Status eine Zeile pro
> 0,25 s), und ein kürzeres Halten ließe die Karte verschwinden, bevor sie sich fertig
> geschrieben hat. Genau das zeigte der erste Live-Lauf.

---

## 6. `Playlist`

```lua
Playlist.Ids = { "minefield", "birdhunt", "canteen" }

function Playlist.order(seed)
    -- Kopie von Ids, dann Fisher-Yates rückwärts mit einem eigenen LCG
end

function Playlist.isKnown(id)
```

> **Warum kein `math.random`:** Luau und Lua 5.1 liefern *unterschiedliche*
> Generatoren. Ein auf `math.random` gebauter Shuffle wäre offline reproduzierbar und
> im Studio reproduzierbar — und würde aus demselben Seed zwei verschiedene
> Reihenfolgen erzeugen. Der Offline-Beweis würde dann etwas beweisen, das das Spiel
> nie tut. Außerdem überlebte er kein `math.randomseed` an anderer Stelle: ein
> globaler Generator ist geteilter Zustand.

Mit drei IDs gibt es **sechs** mögliche Reihenfolgen, und alle drei werden immer
gespielt. `GameConfig.Playlist.PerSession` existiert im Live-Place **nicht** — das
kommt erst mit dem Framework.

---

## 7. `Scoring`

```lua
Scoring.borda(n)              -- Gewichte für n Plätze
Scoring.rankRound(entries, cmp)
Scoring.distribute(ranking)   -- verteilt exakt Pacing.TrialPointPool = 1700
```

Rohschlüssel der bestehenden Trials, absteigend:

```
FINISHED   2000 + Detail     entkommen / fertig
ALIVE      1000 + Detail     am Leben, nicht fertig
OUT           0 + Detail     ausgeschieden
```

Detail muss unter 1000 bleiben, sonst kippt ein Band ins nächste.
Schlüssel werden über die Runden eines Trials **summiert**, bevor gerankt wird.

---

## 8. `Envelope` — spezifiziert, nicht verdrahtet

```lua
Envelope.VERSION = 1
Envelope.Limits  = { … }
Envelope.build(ctx, seq, action, data)
Envelope.validate(payload, expected)
```

Vorgesehene Paketform Client → Server:

| Feld | Zweck |
|---|---|
| `v` | Drahtformat — ein veralteter Client scheitert laut |
| `sessionId` | dieses Match |
| `trialId` | dieses Trial |
| `trialToken` | dieser Lauf dieses Trials |
| `roundToken` | diese Runde / dieses Leg |
| `seq` | streng steigend pro Sender |
| `action` / `data` | die Aktion |

**Kein Live-Trial ruft `validate` auf.** Die drei Trials akzeptieren das nackte Paket
und prüfen von Hand. `sessionId` erreicht den Client heute gar nicht, kann also auch
nicht zurückgespiegelt werden.

---

## 9. Blut-Konfiguration

`ReplicatedStorage.KenopsiaAssets.Effects.Blood` — Value-Objekte, live veränderbar:

| Objekt | Typ | Wert |
|---|---|---|
| `Enabled` | `BoolValue` | `true` |
| `ReduceGore` | `BoolValue` | `false` |
| `LeaveStains` | `BoolValue` | `true` |
| `Intensity` | `NumberValue` | `1` |
| `MaxActive` | `IntValue` | `48` |
| `StainedMaterialVariant` | `StringValue` | `BLOOD_PSX_Stained_Surface` |

Der Server (`BloodFX`) sendet nur Ereignisse; das Rendern macht `GoreClient` lokal.
`BloodEffect` (ReplicatedStorage) ist die eigentliche Zeichenroutine.

---

## 10. Abbruch und Stornierung

**Prädikat:** `RoomService.cancelled(sessionId)` =
`room.phase ~= "Playing" or room.sessionId ~= sessionId`

Trials ohne Kontext benutzen das Äquivalent: `room.phase == "Playing"` plus die beim
Start festgehaltene `sessionId`.

**Vertrag:** `runRound` muss bei einem Abbruch **normal zurückkehren** — mit einer
vollständigen Nulltabelle — und darf **nicht** werfen. Nur echte Ausnahmen
propagieren, und auch die erst nach dem Cleanup.

**Jeder** `task.delay`, `task.spawn`, `Touched`- oder RemoteEvent-Callback prüft
zuerst `active()`.

Abbruchquellen:
1. Teilnehmerzahl fällt unter das Minimum → `RoomService.abortMatch`,
   Phase `Aborting`, `room.token += 1`, `LobbyError` an alle
2. Ausnahme im Trial → `MachineFlow`-Ausgang `"error"` →
   `RoomService.abort(room, "MINIGAME ERROR")`
3. Kein fertiges Trial → `"no-trial"` → `abort(room, "NO READY MINIGAME")`

---

## 11. Verantwortung für Teleports

`MachineFlow` teleportiert **nichts**. Jedes Trial:

1. bringt die Teilnehmer beim Rundenstart selbst in seine Arena
   (`s.root.CFrame = CFrame.lookAt(…)` am `HumanoidRootPart`)
2. setzt `hum.Health = hum.MaxHealth` (die Regeneration ist place-weit aus)
3. bringt sie im eigenen `cleanup()` zurück nach
   `workspace.SpawnLocation.Position + (rand ±6, 4, rand ±6)`,
   Rückfall `Vector3.new(0, 5, 0)`
4. deckt beide Wege mit einer schwarzen Karte ab:
   `announce {kind="announce", text=""}` plus `task.wait(0.6)`
5. stellt alles wieder her, was es am Charakter verändert hat: `WalkSpeed`,
   `JumpPower`, `Anchored`, alle `XBot*`-Attribute

Tote Spieler (`hum.Health = 0`) respawnen über Roblox' Standard am `SpawnLocation`;
das Trial markiert sie als `done` und sendet 3,2 s später optional ein
`spectate`-Rollenpaket.
