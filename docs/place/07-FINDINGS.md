# 07 — Befunde

Was bei der Aufnahme am 21.08.2026 auffiel. Jeder Befund nennt den **Beleg** (die
gemessene Stelle) und eine **Behebung**. Nichts davon wurde geändert — die Aufnahme
war rein lesend.

Einstufung: **A** = blockiert die Veröffentlichung · **B** = wichtig, nicht dringend ·
**C** = Aufräumarbeit.

---

## A — Blockierend

### F-01 · Die Arbeit existiert nur einmal

**Beleg:** `.git/logs/HEAD` endet am 14.08.2026 mit `d5b4486`. Die Dateien
`docs/MP-01…06` (17.08.), `studio-src/.../TrialKit.luau` (17.08.), 36 Stub-Dateien
(17.08.) und `Canteen{Boss,Diner,Props,Protocol}.luau` (19.08.) sind in keinem
Commit. `.git/config` enthält **keinen** `[remote]`-Block.

**Wirkung:** ~227 KB Design- und Vertragsarbeit plus das komplette Framework
existieren nur auf einer Festplatte, ohne Versionierung und ohne Kopie.

**Behebung:**
```
git add -A
git commit -m "MP framework, 12 trial stubs, canteen finale"
gh repo create kenopsia-roblox --private --source=. --remote=origin --push
```
Vorher `.gitignore` prüfen: `globalTypes.d.luau` (818 KB, regenerierbar) und
`roblox.yml` (740 KB) raus, `.blend`-Dateien rein.

---

### F-02 · Die publizierte Serverkapazität ist 60, das Spiel erwartet 4

**Beleg:** `Players.MaxPlayers = 60`, `PreferredPlayers = 60`.
`GameConfig.Players.MaximumPerServer = 4`, `Room.MaxPlayers = 4`.
Der Kommentar in `GameConfig` sagt selbst: *"Published capacity must match this."*

**Wirkung:** Auf einem Live-Server können 60 Spieler beitreten. Der kanonische Raum
nimmt vier davon auf; die übrigen 56 landen als `spectators` und bekommen von den
Trials **gar nichts** (siehe F-16). Das ist kein theoretischer Fall — es ist der
Normalfall, sobald das Spiel öffentlich ist.

**Behebung:** In Studio unter *File → Game Settings → Places → Server Size* auf den
Wert setzen, der auch in `GameConfig` steht. `Players.MaxPlayers` ist für Skripte
schreibgeschützt.

---

### F-03 · Springen ist aktiv, obwohl es aus sein soll

**Beleg:** `StarterPlayer.CharacterJumpPower = 0`, aber
`CharacterUseJumpPower = false` und `CharacterJumpHeight = 7.2`.
Steht `UseJumpPower` auf `false`, gilt `JumpHeight` — die `0` bei `JumpPower` hat
keine Wirkung. Zusätzlich `AutoJumpEnabled = true`.

**Wirkung:** Spieler können in allen drei Trials springen. Der Entwurf sagt
ausdrücklich *"Jump is always 0"* (`MP-05` D10). Im Minenfeld lassen sich damit
Zellen überspringen, in Bird Hunting die Deckungslogik umgehen.

**Behebung:** entweder `CharacterUseJumpPower = true` (dann greift `JumpPower = 0`)
oder `CharacterJumpHeight = 0`. Zusätzlich `AutoJumpEnabled = false`.

---

### F-04 · Das Framework ist geschrieben, aber nicht im Place — und die zwölf Trials sind leer

**Beleg:** Der Place enthält unter `Services` genau zehn Module. `TrialKit`,
`TrialClientKit`, `TrialRules` und der Ordner `TrialClients` fehlen vollständig.
Im Repo liegt `TrialKit.luau` mit 29 774 B, während alle zwölf Server-Trials
byte-nah identische ~2 830-B-Stubs sind und alle zwölf Client-Trials ~1 185 B —
sämtlich zuletzt geschrieben am **17.08.2026 16:58**.

**Wirkung:** Das Spiel hat drei Minispiele, obwohl fünfzehn geplant und zwölf
entworfen sind. Der teure Teil (Framework, Wire-Protokoll, Validierungskette,
zwölf Design-Cards) ist fertig; nur die Ausführung fehlt.

**Behebung:** Push-Prozedur in `docs/MP-05-BUILD-PLAN.md §F`. Wichtig: die zwölf
Stubs müssen **gleichzeitig** mit dem Framework hinein, weil `MachineFlow.start`
jedes registrierte Modul `require`t und `init()`t — auch die nicht-fertigen.

**Nebenbefund:** `docs/MP-06-FRAMEWORK.md §0` behauptet, alle vier Dateien pro Trial
existierten als Stubs. Die `tests/<id>.lua` existieren **nicht** — `tests/` enthält
nur `rules`, `envelope`, `contexts`, `trialrules`, `animationids`.

---

### F-05 · Die publizierten Animationen spielen auf einem Live-Server nicht

**Beleg:** Dokumentiert im Kopf von `AnimationIds.luau`: Die IDs wurden von Nutzer
`4840146924` publiziert, der Place gehört Gruppe `832614570`. Roblox spielt eine
Animation ohne Freigabe nicht ab — `LoadAnimation` gelingt, `Length` bleibt `0`, der
Rig bewegt sich nie.

**Wirkung:** `AnimationIds.warmup()` erkennt das und fällt auf die
`KeyframeSequence`s aus `ServerStorage.RBX_ANIMSAVES` zurück — **das funktioniert
nur im Studio** (`RegisterKeyframeSequence` ist Studio-only). Auf einem
veröffentlichten Server stehen alle Rigs still: der Boss liest nicht, senkt die
Zeitung nicht, schießt nicht; die Diner essen nicht.

**Behebung:** Pro Animations-ID einmal die Freigabe erteilen — im Output den Link
*"Click to share access"* anklicken, oder Creator Hub → Development Items →
Animations → Permissions → diese Experience hinzufügen. Betrifft mindestens
11 IDs. Nichts im Code kann das ersetzen.

---

## B — Wichtig

### F-06 · `MachineFlow` begrenzt keine Rundenlaufzeit

**Beleg:** `runMatch` (Zeile 281 ff.) ruft `trial.module.runRound` auf und wartet;
es gibt keinen Timeout. Jedes Trial muss seine Deadline aus `Pacing.RoundSeconds[id]`
selbst durchsetzen.

**Wirkung:** Ein Trial, das nie zurückkehrt, hängt den ganzen Match. Bei drei
sorgfältig geprüften Trials überschaubar — bei fünfzehn nicht.

**Behebung:** `TrialKit`s `R:tick` mit Failsafe (`deadline + 20 s`) schließt das
strukturell. Ein weiterer Grund, das Framework zuerst zu shippen.

---

### F-07 · `Envelope` ist spezifiziert, aber nicht verdrahtet

**Beleg:** `Envelope.validate` existiert (Zeile 128) und wird von **keinem** Trial
aufgerufen. Die drei Live-Trials akzeptieren das nackte Paket und prüfen von Hand.
`sessionId` erreicht den Client gar nicht und kann daher auch nicht zurückgespiegelt
werden.

**Wirkung:** Der dokumentierte Schutz gegen Replay über Rundengrenzen hinweg existiert
als Modul, nicht als Wirkung. Die Trials haben eigene, unterschiedlich strenge
Prüfungen.

**Behebung:** `TrialKit.wireInput` implementiert die vollständige Kette (12 Stufen)
einmal für alle Trials. Für die drei Alt-Trials bleibt es beim nackten Paket —
bewusst, laut `MP-05` D3.

---

### F-08 · Das `role`-Paket ist der einzige Weg, wie ein `roundToken` zum Client kommt

**Beleg:** `KenopsiaClient` übernimmt `trialRoundToken` nur aus dem `role`-Handler;
`role = "none"` löscht ihn wieder.

**Wirkung:** Ein Trial, das nie ein Rollenpaket sendet, hat keine funktionierende
Eingabe. Genau daran ist Canteen einmal gescheitert (Bug F-1 im Projektlog: der
`spectate`-Zweig kehrte zurück, **bevor** das Token übernommen wurde — das Minispiel
sah perfekt aus und war unspielbar).

**Behebung:** `TrialKit` liefert das Token über `ev="begin"`. Bis dahin: jedes neue
Trial muss ein Rollenpaket senden.

**Lehre fürs Testen:** Ein synthetischer Testclient, der das Token direkt aus dem
Paket liest, verdeckt diese ganze Fehlerklasse. Client-Tore immer über den echten
Eingabepfad prüfen.

---

### F-09 · Zuschauer bekommen von Trials nichts

**Beleg:** Jeder Sender iteriert `room.members`; `room.spectators` wird nie
berücksichtigt. `RoomService` hält Nachzügler bewusst in `spectators`, damit
`BirdHunting` und `Minefield` ihre Annahme über `members` behalten.

**Wirkung:** Wer während eines Matches beitritt, sieht bis zur nächsten Session eine
leere Welt. In Kombination mit F-02 (60 Slots, 4 Plätze) betrifft das im Normalfall
die Mehrheit der Spieler.

**Behebung:** Zusammen mit der Serverkapazität entscheiden. Entweder Kapazität auf
die Raumgröße senken, oder Zuschauern einen echten Zuschauermodus geben.

---

### F-10 · `canteen` hat keine Musik, `Ambience` ist leer

**Beleg:** `SoundService.KenopsiaAudio.Music.Trials` enthält genau zwei Sounds:
`birdhunt` und `minefield`. Der Ordner `Ambience` hat null Kinder.

**Wirkung:** Ein Drittel der Session läuft ohne Musik. Atmosphäre ist bei diesem
Spiel das Verkaufsargument.

**Behebung:** Kurzfristig einen der beiden vorhandenen Titel für `canteen`
wiederverwenden (so sieht es `MP-05` D6 ohnehin vor). Mittelfristig: bei fünfzehn
Trials entweder fünfzehn Titel oder ein Basis-Loop mit Intensitäts-Layer.

---

### F-11 · Sechs Animations-IDs stehen auf `0`

**Beleg:** `Player.Eat`, `Boss.Death`, `Textures.PlayerBlink`, `PlayerHappy`,
`PlayerHurt`, `BossAngry`.

**Wirkung:** `CanteenDiner` fällt beim Essen auf `Push` zurück — die einzige
Aktion mit Armen nach vorn — zeitskaliert auf das Essfenster. Das ist als
Übergangslösung so gebaut und dokumentiert, sieht aber nicht wie Essen aus.
Die Gesichtstexturen fehlen ganz.

**Behebung:** Clips im Animation Editor publizieren, IDs in `AnimationIds` einsetzen.
Es ist der einzige Ort im Projekt, an dem eine Animations-ID steht.

---

### F-12 · Die Touch-Buttons sind fest pro Alt-Trial verdrahtet

**Beleg:** `KenopsiaMachine.TouchControls` enthält sieben feste Buttons:
`Btn_FIRE`, `Btn_SCOPE`, `Btn_ZOOM`, `Btn_PUNCH`, `Btn_CROUCH`, `Btn_SCAN`,
`Btn_EAT`. `FIRE`/`PUNCH` liegen exakt übereinander, ebenso
`SCOPE`/`CROUCH`/`SCAN`/`EAT`.

**Wirkung:** Jedes neue Trial bräuchte hier einen weiteren Button und eine weitere
Sichtbarkeitsregel. Bei zwölf zusätzlichen Trials wird das unhaltbar.

**Behebung:** `TrialClientKit.kit.pad()` baut die Buttons zur Laufzeit. Wichtig für
alles Neue: Roblox ist mehrheitlich mobil — die Steuerung jedes Trials muss von
Anfang an für Daumen entworfen werden, nicht für Tastatur mit Touch-Nachtrag.

---

### F-13 · Zwei Trials legen ein Remote gleichen Namens an

**Beleg:** `Minefield` und `CanteenProtocol` erzeugen beide ein `RemoteEvent` namens
`TrialInput`. `BirdHunting` benutzt stattdessen `SniperFire` und `SniperAim`.

**Wirkung:** Wer beim Boot zuerst läuft, legt es an; der zweite findet es per
`FindFirstChild`. Funktioniert, ist aber Zufall statt Vertrag, und die
Aktionsnamensräume der beiden Trials teilen sich einen Kanal.

**Behebung:** `TrialKit` vereinheitlicht auf ein `TrialInput` mit `trialId` im Paket.

---

### F-14 · `Pacing.roundsFor` gibt bei fehlender Zeile stillschweigend `nil` zurück

**Beleg:** `ROUNDS` enthält nur `minefield` und `canteen`; `birdhunt` läuft über
`LEGS`. Fehlt eine Zeile, ist der Rückgabewert `nil`, und `MachineFlow` spielt
`rounds = … or 1` — eine einzige Runde, ohne Warnung.

**Wirkung:** Ein neues Trial ohne Pacing-Zeile läuft eine Runde statt drei, und
niemand merkt es.

**Behebung:** Im Repo-Stand von `MachineFlow` warnt eine fehlende Zeile bereits —
das ist eine der Abweichungen zwischen Live und Mirror.

---

### F-15 · Live-Skripte weichen vom Repo ab

**Beleg:** Bytegenaue Gegenüberstellung:

| Skript | Live | Repo | |
|---|---:|---:|---|
| `MachineFlow` | 22 840 | 27 222 | **Repo ist voraus** |
| `GameConfig`, `Pacing`, `Playlist`, `KenopsiaClient`, `MachineLayout` | | | **Repo ist voraus** |
| `RoomService`, `BirdHunting`, `Minefield`, `BloodFX`, `Contexts`, `CanteenProtocol`, `CanteenProps`, `CanteenBoss`, `CanteenDiner`, `Scoring`, `Envelope` | | | identisch |

**Wirkung:** `studio-src/` ist **kein** Spiegel des Places mehr. Die Frage "was läuft
live?" darf niemals durch Lesen von `studio-src/` beantwortet werden.

**Behebung:** Der Unterschied ist gewollt — die sechs abweichenden Dateien tragen die
Framework-Änderungen, die noch nicht gepusht sind. Beim Push von F-04 gleichen sie
sich an. Bis dahin: im Repo-README festhalten, welche Dateien voraus sind.

---

## C — Aufräumarbeit

### F-16 · Acht Lampen an vier Positionen

**Beleg:** `FloorLamp_01`+`_02` bei `-96.5, 32.6, 22.6`;
`_04`+`_07` bei `-96.5, 32.6, -6.2`; `_05`+`_08` bei `-96.5, 32.6, -29.8`;
`_03`+`_06` bei `-131.9, 32.6, -6.2`. Jede Lampe hat 3 `PointLight` und
3 `SurfaceLight`.

**Wirkung:** 24 PointLights und 24 SurfaceLights, wo je 12 gemeint waren. Roblox
begrenzt die Zahl gleichzeitig sichtbarer Lichter — überzählige werden verworfen, und
welche das sind, ist nicht deterministisch. Dazu Z-Fighting auf den Deckungsflächen.

**Behebung:** Je eine der beiden Lampen pro Position löschen. Spart 152 Instanzen und
24 Lichter.

---

### F-17 · Acht Teller an vier Plätzen

**Beleg:** Acht `Plate`-Parts (`0.2 × 6.1 × 6.1`) an genau vier Positionen, jede
doppelt. Eines der Duplikate hat abweichendes Material (`Metal` statt `Plastic`).

**Behebung:** Vier davon löschen. Die `PlateAnchors`-Marker sind die Wahrheit, nicht
die sichtbaren Teller.

---

### F-18 · Requisiten unter dem Boden und am Weltursprung

**Beleg:**

| Objekt | Position | Problem |
|---|---|---|
| `Canteen_Mesh_Packaging_01` ×7 | alle bei `Y = -0.3` | unter dem Kantinenboden (`Y = 1.0`) |
| `Canteen_Mesh_Drinks_01` ×3 | `Y ≈ -3.8` | unter dem Boden |
| `Canteen_canned_food_3` | `0.0, 2.1, 1.0` | am **Weltursprung**, nicht in der Kantine |
| `gear_mx_1` | `16.0, -55.1, -114.4` | unter der Baseplate (`Y = -8`) |
| `saw_blade` | `16.0, -55.2, -114.4` | unter der Baseplate |
| `SniperRifle_PSX` | `-284.6, 9.0, -589.6` | loses Modell zwischen den Arenen |
| `bench` | — | **leeres** Modell ohne Kinder |
| `Canteen_mre_1` | `-134.8, 2.0, -38.2` ×2 | Duplikat |
| `Canteen_trash_1` | `-89.1, 1.8, 20.5` ×2 | Duplikat |
| `metal_shelf` | `-14.0, 13.3, 515.8` ×2 | Duplikat |

**Behebung:** Unsichtbares löschen, Duplikate löschen, `bench` löschen. Loses in
`ServerStorage.KenopsiaAssets` verschieben oder entfernen.

---

### F-19 · Tote Altlasten in `ServerStorage`

**Beleg:** `KenopsiaAuthoring.AnimationSources` enthält
`Mixamo_SneakWalk_Archive`, `Mixamo_InjuredWalk_Archive`,
`Mixamo_ZombieCrawl_Archive` — je 198 Nachkommen, `AnimSaves → nil`.
Die Mixamo-Animationsschicht wurde am 14.08. entfernt (Commit *"Remove the XBot rig
and the whole animation layer"*).

Dazu: `RBX_ANIMSAVES` ist mit **29 785 Instanzen** allein 74 % des gesamten
Datamodels. Es wird ausschließlich vom Studio-Notbehelf aus F-05 gebraucht.

**Behebung:** Die drei Mixamo-Archive löschen (594 Instanzen). `RBX_ANIMSAVES`
behalten, bis die Animations-Freigaben erteilt sind — danach kann es raus.

---

### F-20 · Veraltete Kommentare und tote Konfiguration

| Stelle | Problem |
|---|---|
| `MachineFlow` `TRIALS`, `canteen`-Eintrag | Der Kommentar sagt *"ready STAYS false"*, das Feld darunter steht auf `true` |
| `GameConfig.Playlist.PlacementPoints` | `{3,2,1,0}` — wird nirgends gelesen, `Scoring` benutzt Borda |
| `GameConfig.Room.CodeAlphabet` / `CodeLength` | nur für den Join-Shim, es werden keine Codes ausgegeben |
| `Pacing.Timing.Title = 1.2` | laut eigenem Kommentar ein Planwert ohne Typewriter |
| `MachineFlow` Registry, `showInterRoundScore` | überall `false`, laut `MP-01` funktionslos |
| `KenopsiaMachine.RoundCard.Verbs` | gespeicherter Text `"MEMORIZE. INSPECT. ALIGN._"` ist ein Relikt des alten RECALL-Entwurfs |
| `Bird Hunting`: `concrete block hiding` / `concrete block hidin` | zwei Namen, dieselbe `RBX_ReimportId` — derselbe Import zweimal benannt |

---

### F-21 · Standard-Chat ist aktiv

**Beleg:** `TextChatService.CreateDefaultCommands = true`,
`CreateDefaultTextChannels = true`, alle vier Konfigurationsobjekte unverändert.

**Wirkung:** Bei einem Spiel, dessen ganze Identität eine Maschine mit strenger Stimme
ist, läuft daneben Robloxs Standard-Chatfenster. Das ist eine Designentscheidung, die
noch niemand getroffen hat.

---

### F-22 · Alles ist immer geladen

**Beleg:** `StreamingEnabled = false` (bewusst — Streaming zerstörte die
Runner-Kameras auf echten Netzwerk-Clients). Aktuell 1 793 Workspace-Instanzen für
drei Arenen.

**Wirkung:** Bei fünfzehn Arenen à bis zu 300 statischen Teilen kommen bis zu
4 500 dauerhaft geladene Teile dazu. Bei vier Spielern auf Desktop egal, bei mehr
Spielern auf schwachen Telefonen nicht.

**Behebung:** Sicherstellen, dass `TrialKit.ensureArena` wirklich erst beim ersten
Spielen baut und nicht beim Boot. Das ist im Framework so angelegt — beim Einbau
prüfen.

---

## Zusammenfassung

| Einstufung | Anzahl | Betrifft |
|---|---:|---|
| **A** blockierend | 5 | Sicherung, Serverkapazität, Springen, Framework, Animations-Freigaben |
| **B** wichtig | 10 | Rundentimeout, Envelope, Token-Kanal, Zuschauer, Audio, Animations-IDs, Touch, Remotes, Pacing, Live/Repo-Drift |
| **C** Aufräumen | 7 | Lampen, Teller, versunkene Props, Altlasten, tote Konfiguration, Chat, Streaming |

Die drei mit dem größten Verhältnis von Wirkung zu Aufwand: **F-01** (Minuten),
**F-02** (eine Einstellung) und **F-03** (eine Eigenschaft).
