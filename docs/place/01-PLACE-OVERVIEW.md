# 01 — Place-Übersicht

Place `110672791536316` · "Kenopsia_MainGame" · Gruppe `832614570` · aufgenommen 21.08.2026

---

## 1. Service-Zensus

Nachkommen pro Service, ohne Studios eigene Plugin-Instanzen:

| Service | Nachkommen | Tiefe | Direkte Kinder | Bemerkung |
|---:|---:|---:|---:|---|
| `ServerStorage` | 31 954 | 12 | 3 | 29 785 davon sind `RBX_ANIMSAVES` (Keyframe-Rohdaten) |
| `Workspace` | 1 793 | 6 | 10 | drei Arenen + lose Props |
| `StarterGui` | 521 | 6 | 1 | ein einziges `ScreenGui`: `KenopsiaMachine` |
| `ReplicatedStorage` | 62 | 4 | 2 | `KenopsiaAssets` + `Kenopsia` |
| `SoundService` | 43 | 4 | 1 | `KenopsiaAudio` |
| `MaterialService` | 15 | 1 | 15 | 15 `MaterialVariant` |
| `ServerScriptService` | 13 | 3 | 1 | `KenopsiaServer` |
| `TextChatService` | 8 | 2 | 4 | Standard-Chat aktiv |
| `StarterPlayer` | 6 | 2 | 2 | 3 LocalScripts + 1 Script |
| `Players` | 3 | 2 | 1 | |
| `Lighting` | 1 | 1 | 1 | `KenopsiaSky` |
| `ReplicatedFirst` | 1 | 1 | 1 | `KenopsiaLoading` |
| `StarterPack` | 0 | — | 0 | leer |
| `Teams` | 0 | — | 0 | leer |
| **Datamodel gesamt** | **40 144** | | | |

---

## 2. Service-Einstellungen

### Workspace

| Eigenschaft | Wert |
|---|---|
| `StreamingEnabled` | **`false`** |
| `Gravity` | `196.2` (Standard) |
| `FallenPartsDestroyHeight` | `-500` |
| `FilteringEnabled` | `true` |
| `AllowThirdPartySales` | `false` |
| `InterpolationThrottling` | `Default` |
| `CurrentCamera` | `Camera` |

> `StreamingEnabled = false` ist eine bewusste Entscheidung: Streaming hat in Runde 2–3
> die Runner-Kameras auf echten Netzwerk-Clients zerstört (funktionierte in Play Solo,
> versagte im Team Test). Konsequenz: **alles ist immer geladen.**

### Lighting

| Eigenschaft | Wert |
|---|---|
| `Ambient` | `0.298, 0.259, 0.259` (warmes Grau-Rot) |
| `OutdoorAmbient` | `0.416, 0.369, 0.369` |
| `Brightness` | `1.2` |
| `EnvironmentDiffuseScale` | **`0`** |
| `EnvironmentSpecularScale` | **`0`** |
| `GlobalShadows` | `true` |
| `ShadowSoftness` | `0.2` |
| `ClockTime` / `TimeOfDay` | `9.4` / `09:24:00` |
| `FogColor` | `0.173, 0.086, 0.078` (dunkles Rotbraun) |
| `FogStart` / `FogEnd` | `60` / `480` |
| `ExposureCompensation` | `0` |
| `Technology` | *nicht lesbar über MCP* |
| Kind | `KenopsiaSky <Sky>` |

> Die beiden `Environment*Scale = 0` sind der Kern des PS1-Looks: keine
> bildbasierte Beleuchtung, flache Flächen. `FogEnd = 480` ist außerdem der
> Grund, warum die geplanten Arena-Origins in `MP-05 §A` mindestens 480 Studs
> auseinanderliegen müssen — sonst sieht man von einer Arena in die nächste.

### Players

| Eigenschaft | Wert |
|---|---|
| `MaxPlayers` | **`60`** ← widerspricht `GameConfig` (siehe [F-02](07-FINDINGS.md)) |
| `PreferredPlayers` | `60` |
| `RespawnTime` | `3` |
| `CharacterAutoLoads` | `true` |

### StarterPlayer

| Eigenschaft | Wert |
|---|---|
| `CharacterWalkSpeed` | `12` |
| `CharacterJumpPower` | `0` |
| `CharacterUseJumpPower` | **`false`** ← daher gilt `JumpHeight`, nicht `JumpPower` |
| `CharacterJumpHeight` | **`7.2`** ← **Springen ist aktiv** (siehe [F-03](07-FINDINGS.md)) |
| `CharacterMaxSlopeAngle` | `89` |
| `CameraMode` | `Classic` |
| `CameraMinZoomDistance` / `Max` | `0.5` / `128` |
| `DevComputerMovementMode` | `UserChoice` |
| `DevTouchMovementMode` | `UserChoice` |
| `DevCameraOcclusionMode` | `Zoom` |
| `EnableMouseLockOption` | `true` |
| `LoadCharacterAppearance` | `true` |
| `AutoJumpEnabled` | `true` |
| `HealthDisplayDistance` / `NameDisplayDistance` | `100` / `100` |

### SoundService

| Eigenschaft | Wert |
|---|---|
| `AmbientReverb` | `NoReverb` |
| `DistanceFactor` | `3.33` |
| `DopplerScale` / `RolloffScale` | `1` / `1` |
| `RespectFilteringEnabled` | `true` |

### TextChatService

`ChatVersion = TextChatService`, `CreateDefaultCommands = true`,
`CreateDefaultTextChannels = true`.
Kinder: `ChatWindowConfiguration`, `ChatInputBarConfiguration`,
`BubbleChatConfiguration`, `ChannelTabsConfiguration` — alle unverändert.

### MaterialService — 15 Varianten

| Name | Basismaterial |
|---|---|
| `CANTEEN_Wood_Dark` | `WoodPlanks` |
| `CANTEEN_LowPoly_Palette` | `Plastic` |
| `CANTEEN_CannedFood_Label` | `Metal` |
| `CANTEEN_MRE_Pouch` | `Fabric` |
| `CANTEEN_Metal_Rough` | `CorrodedMetal` |
| `CANTEEN_Trash_Debris` | `Concrete` |
| `BLOOD_PSX_Stained_Surface` | `Concrete` |
| `RETRO_ConcreteWall` | `Concrete` |
| `RETRO_OldConcrete` | `Concrete` |
| `RETRO_ConcreteFloor` | `Concrete` |
| `RETRO_MetalPanels` | `Metal` |
| `RETRO_RustyMetal` | `CorrodedMetal` |
| `RETRO_MetalFloor` | `DiamondPlate` |
| `RETRO_Grass` | `Grass` |
| `MinefieldGround` | `Ground` |

`BLOOD_PSX_Stained_Surface` wird zur Laufzeit über den `StringValue`
`ReplicatedStorage.KenopsiaAssets.Effects.Blood.StainedMaterialVariant` referenziert.

---

## 3. Boot-Reihenfolge

```
ReplicatedFirst.KenopsiaLoading  (LocalScript, 3 840 B)
    baut "KenopsiaLoadingGui", DisplayOrder 100
    zeigt "KENOPSIA" + "connecting subjects" + Spielerzahl
    weicht, sobald das erste Lobby-Paket ankommt

ServerScriptService.KenopsiaServer.Main  (Script, 340 B)
    require(Services.RoomService)
    require(Services.MachineFlow)
    RoomService.start()          -> legt Remotes an, setzt Raum auf Waiting
    MachineFlow.start(RoomService)-> legt MachineState an, init()t ALLE Trials
    print("[Kenopsia] server ready (main game)")

StarterPlayer.StarterPlayerScripts   (pro Client)
    KenopsiaClient   79 433 B   der Monolith: Lobby, alle drei Trials, Kamera, Input
    MachineLayout    10 922 B   plattformabhängige Skalierung + Steuerungstexte
    GoreClient       14 221 B   rendert alles Blut lokal

StarterPlayer.StarterCharacterScripts
    Health  (Script, 134 B)  absichtlich LEER — ersetzt Roblox' Regeneration.
                             Verletzungen bleiben bis zum Health-Reset am Rundenstart.
```

> `MachineFlow.start` ruft `init()` auf **jedem** registrierten Trial auf, auch auf
> nicht-fertigen. Trials legen dort ihre Remotes an, damit Clients sie per
> `WaitForChild` finden. Deshalb müssen beim Einbau des `TrialKit`-Frameworks alle
> zwölf Stubs gleichzeitig mit hinein — sonst schlägt jeder `require` beim Boot fehl.

---

## 4. Der Session-Loop

Zwei Ebenen: `RoomService` besitzt die Raumphase, `MachineFlow` besitzt alles
innerhalb von `Playing`.

```
RoomService                 Waiting → Starting → Playing → Waiting
                            Playing → Aborting → Cleanup → Waiting   (Abbruch)

MachineFlow (innerhalb Playing)
  seed = math.random(1, 2^31-1)              server-gemünzt, nie vom Client
  order = playableOrder(seed)                alle aktivierten Trials, seed-gemischt
  session = Contexts.newSession(...)
  KenopsiaSessionScore / …Wins auf 0         einmal pro MATCH

  für jedes Trial in order:
    Stage "Selecting"   Roulette mit Decoy-Icons     3.5 s  (Pacing.Timing.Reveal)
    Stage "Briefing"    Titel, Tagline, Steuerung    8.0 s  (ControlCard)
    Stage "Trial"
      für runde = 1..Pacing.roundsFor(id, playerCount):
        Rundenkarte "Round n/m" + Verben             3.0 s  (RoundCard)
        {kind="hide"}, Attribut KenopsiaActiveTrial setzen
        → trial.module.runRound(room, roundIndex)    ← blockiert beliebig lange
        Attribut leeren, Rohpunkte aufaddieren
        Nachlauf                                     1.5 s  (RoundSettle)
    Scoring.rankRound → Scoring.distribute           exakt 1700 Punkte
    Stage "Score"      Punktetafel                   4.5 s  (InterimScore)

  Stage "FinalScore"  Urteil VIABLE / REJECTED       8.0 s  (FinalScore)
                      KenopsiaSessionWins++
```

**Wichtig:** `MachineFlow` begrenzt die Laufzeit einer Runde **nicht**. Ein Trial,
das nie zurückkehrt, hängt den ganzen Match. Jedes Trial muss seine eigene Deadline
aus `Pacing.RoundSeconds[id]` durchsetzen. Bei drei Trials überschaubar — bei fünfzehn
nicht.

### Zeitbudget pro Trial

Fixer Overhead: `3.5 + 8.0 + 4.5 = 16.0 s` pro Trial,
plus `3.0 + 1.5 = 4.5 s` pro Runde, plus die Rundenlänge selbst.

| Trial | Runden (2p/3p/4p) | Sekunden/Runde | Dauer bei 4 Spielern |
|---|---|---:|---:|
| `birdhunt` | 4 / 3 / 4 **Legs** | 90 | 16 + 4×94.5 ≈ **394 s** |
| `minefield` | 4 / 3 / 3 | 55 | 16 + 3×59.5 ≈ **195 s** |
| `canteen` | 3 / 2 / 2 | 45 | 16 + 2×49.5 ≈ **115 s** |
| **Session gesamt** | | | **≈ 704 s ≈ 11:45 min** |

`birdhunt` allein ist damit **56 %** der Session.

---

## 5. Punktevergabe

`Scoring.luau`, rein und Lua-5.1-portabel.

- `Scoring.borda(n)` — Gewichte für *n* Plätze
- `Scoring.rankRound(entries, cmp)` — sortiert nach Rohschlüssel
- `Scoring.distribute(ranking)` — verteilt **exakt** `Pacing.TrialPointPool = 1700`

Regel und Konflikt, wörtlich aus dem Modulkopf: die Summe muss exakt 1700 sein
**und** Gleichplatzierte sollen den Durchschnitt ihrer Plätze teilen. Bei drei
Gleichplatzierten geht das nicht in ganzen Zahlen auf (1700/3 = 566,67). **Die Summe
gewinnt**; Gleichplatzierte bekommen Anteile, die sich um höchstens einen Punkt
unterscheiden, der zuerst platzierte zuerst. Bei allen 2- und 4-Spieler-Formen ist
die Spreizung null.

Der Rückgabewert von `runRound` ist nur ein **Ordnungsschlüssel** — nur die
Reihenfolge zählt, nie der Betrag. Die Bänder der bestehenden Trials:

```
FINISHED  2000+     entkommen / fertig
ALIVE     1000+     am Leben, nicht fertig
OUT          0+     ausgeschieden
```

Rohschlüssel werden über alle Runden eines Trials **summiert**, bevor gerankt wird —
die Bänder müssen also über die Runden eines Trials konsistent bleiben.

`GameConfig.Playlist.PlacementPoints = {3,2,1,0}` existiert, wird aber **nicht
benutzt**.
