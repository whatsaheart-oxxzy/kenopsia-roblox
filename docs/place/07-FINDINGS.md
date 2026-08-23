# 07 — Befunde

Was bei der Aufnahme am 21.08.2026 auffiel. Jeder Befund nennt den **Beleg** (die
gemessene Stelle) und eine **Behebung**. Nichts davon wurde geändert — die Aufnahme
war rein lesend.

Einstufung: **A** = blockiert die Veröffentlichung · **B** = wichtig, nicht dringend ·
**C** = Aufräumarbeit.

> **Korrektur 21.08.2026:** F-02 ist zurückgezogen. Es war ein Messfehler meinerseits,
> kein Konfigurationsfehler im Place. Die Begründung steht unten bei F-02 und ist dort
> bewusst stehen geblieben, statt gelöscht zu werden.

---

## Status 23.08.2026 (P0.5 Docs-Truth-Pass)

Die Befundtexte unten sind der **Stand vom 21.08.2026** und bleiben als Beleg stehen.
Was seither gemessen wurde, steht hier — je Befund mit der QA-Notiz, die es belegt.
"Lead" = Aufräumen im Studio durch den Lead (MASTERPLAN P0.4), vom Repo aus nicht prüfbar.

| Befund | Status | Beleg (measured on) |
|---|---|---|
| F-01 Sicherung | **erledigt** 21.08. | Commits `bc1160b`, `081a8b8`; Remote vorhanden |
| F-02 Serverkapazität | zurückgezogen 21.08. | Messartefakt, s.u. |
| F-03 Springen | **erledigt** — `CharacterUseJumpPower=true`, `JumpPower=0`, `AutoJumpEnabled=false` (2026-08-22); seit P3.3 verbietet `CharacterService` den Sprung auf jedem Charakter (2026-08-22) | `docs/research/2026-08-22-sweep/03-live-place.md`; `docs/QA/2026-08-22-p3-ps1-character.md` |
| F-04 Framework nicht im Place | **erledigt** — 62/62 Skripte byte-identisch (2026-08-22), Smoke-Test P0.1 gespielt (2026-08-22). Von den zwölf Trials ist `sorting` gebaut (P4.1, 2026-08-23, `ready=false` bis Release); elf sind weiterhin Stubs | `docs/MASTERPLAN.md` §0; `docs/QA/2026-08-22-framework-smoke.md`; `docs/QA/2026-08-23-p4-sorting.md` |
| F-04 Nebenbefund `tests/<id>.lua` | weiterhin **neue Arbeit** pro Trial; als erstes existiert `tests/sorting.lua` (34 Checks, 2026-08-23) | `docs/MP-06-FRAMEWORK.md` §0 (Hinweis 23.08.) |
| F-05 Animations-Freigabe | **erledigt** — Clips unter der Gruppe neu publiziert, jede ID `Length > 0` (2026-08-22). Offen: die drei Feld-Clips `DeathField`/`Crawl`/`InjuredWalk` (retargetet 23.08.) warten auf die Publikation durch den Lead, bis dahin nur im Studio | `docs/QA/2026-08-22-canteen-stab-eat.md`; `docs/QA/2026-08-23-three-trials-polish.md` |
| F-06 Rundentimeout | **erledigt** — `MachineFlow.runRoundGuarded`, Budget `RoundSeconds + 15 + 20` (2026-08-22; nur Unit-Logik, kein hängendes Trial zum Testen) | `docs/QA/2026-08-22-p1-robustness-rematch.md` |
| F-07 Envelope | **strukturell erledigt** für neue Trials (`TrialKit.wireInput`, geprüft mit `sorting` über Remote + echtem Token, 2026-08-23); die drei Alt-Trials bleiben beim nackten Paket (MP-05 D3, gewollt) | `docs/QA/2026-08-23-p4-sorting.md` |
| F-08 Token-Kanal | **strukturell erledigt** — `ev="begin"` trägt das Token (Smoke 2026-08-22) | `docs/QA/2026-08-22-framework-smoke.md` |
| F-09 Zuschauer | **halb** — Nachzügler bekommen die Bank-Karte (2026-08-22); die Zuschauer-Kamera auf die laufende Arena fehlt | `docs/QA/2026-08-22-p1-robustness-rematch.md` |
| F-10 Kantinen-Musik | **erledigt** — `Music.Trials.canteen` (Klon von `minefield`), `Music.Loop` zurück, `birdhunt` 0.24 → 0.40 (2026-08-22). `Ambience` weiterhin leer (P6) | `docs/QA/2026-08-22-framework-smoke.md` (Side findings) |
| F-11 Sechs IDs auf 0 | **erledigt** — `Player.Eat` publiziert (0.40 s), `Boss.Death` gestrichen (der Boss stirbt nie), vier Gesichtstexturen hochgeladen (2026-08-22). Neu auf 0 seit 23.08.: die drei Feld-Clips, s. F-05 | `docs/QA/2026-08-22-canteen-stab-eat.md` (Addendum 2) |
| F-12 Touch-Buttons | **strukturell erledigt** für neue Trials — `kit.pad()` baut zur Laufzeit in die eigene `KenopsiaTrialHud`-ScreenGui (2026-08-22); die sieben festen Buttons der Alt-Trials bleiben | `docs/QA/2026-08-22-perf-pass-1.md`; `docs/QA/2026-08-23-p4-sorting.md` |
| F-13 Doppeltes `TrialInput` | **strukturell erledigt** — `TrialKit` ein `TrialInput` mit `trialId` (im Place seit 22.08.); Perf-Triage: noch ein `OnServerEvent` pro Trial | `docs/QA/2026-08-22-perf-pass-1.md` (Triage) |
| F-14 `roundsFor` stumm | **erledigt** — `MachineFlow` warnt bei fehlender Zeile; `Pacing.ROUNDS` hat alle 15 Zeilen (im Place seit der 62/62-Parität, 2026-08-22) | `docs/MASTERPLAN.md` §0 |
| F-15 Live/Repo-Drift | **erledigt** — 62/62 byte-identisch (2026-08-22); jede QA-Notiz seither prüft die Parität der gepushten Dateien | `docs/research/2026-08-22-sweep/03-live-place.md` |
| F-16 Doppel-Lampen | **offen — Lead** (P0.4) | — |
| F-17 Doppel-Teller | **erledigt** — vier Duplikate gelöscht (2026-08-22) | `docs/QA/2026-08-22-canteen-stab-eat.md` (Addendum) |
| F-18 Versunkene Props | **offen — Lead** (P0.4) für Baseplate, `gear_mx_1`, `saw_blade`, `bench`, Duplikate; `SniperRifle_PSX` ist seit 22.08. das Viewmodel (`ReplicatedStorage.KenopsiaAssets.SniperRifle`, Authoring-Mesh archiviert). Die Kantinen-Positionen in der Tabelle sind durch die 0.47-Skalierung (2026-08-22) ohnehin überholt | `docs/QA/2026-08-22-p3-simulation-grade.md` |
| F-19 Mixamo-Archive | **offen — Lead** (P0.4). `RBX_ANIMSAVES` bleibt: die drei Feld-Clips laufen bis zur Publikation aus `Anim_FieldClips` (2026-08-23) | `docs/QA/2026-08-23-three-trials-polish.md` (Addendum) |
| F-20 Tote Kommentare | **offen, C** — `showInterRoundScore = false` steht noch in jeder Registry-Zeile (die Zwischenstände kommen seit P1.2 aus `standingsLines()`), `Pacing.Timing.Title` unverändert; Rest nicht nachgemessen | `studio-src` (2026-08-23) |
| F-21 Standard-Chat | **entschieden** (Lead, 22.08.): Chat **an** in Lobby/Maschinen-Screens, **aus** während eines Trials. Code: `UiFx.client.luau` schaltet `ChatWindowConfiguration`/`ChatInputBarConfiguration.Enabled` an `KenopsiaActiveTrial` (Commit dieser Notiz, 2026-08-23; Live-Check offen) | `docs/MASTERPLAN.md` §8; `docs/QA/2026-08-23-p0-leftovers.md` |
| F-22 Alles geladen | **entschieden** — `StreamingEnabled` bleibt `false` (Runner-Kameras); `TrialKit` baut Arenen erst beim ersten Spielen (`Slab, Spawn1-4, Cam` = 6 Nachkommen nach der Session, 2026-08-22) | `docs/MASTERPLAN.md` P0.4; `docs/QA/2026-08-22-framework-smoke.md` |

---

## A — Blockierend

### F-01 · Die Arbeit existiert nur einmal

**Beleg:** `.git/logs/HEAD` endete am 14.08.2026 mit `d5b4486`. Die Dateien
`docs/MP-01…06` (17.08.), `studio-src/.../TrialKit.luau` (17.08.), 36 Stub-Dateien
(17.08.) und `Canteen{Boss,Diner,Props,Protocol}.luau` (19.08.) waren in keinem
Commit. `.git/config` enthielt **keinen** `[remote]`-Block.

**Wirkung:** ~227 KB Design- und Vertragsarbeit plus das komplette Framework
existierten nur auf einer Festplatte, ohne Versionierung und ohne Kopie.

**Status: ERLEDIGT am 21.08.2026.** Zwei getrennte Commits — `bc1160b` (diese
Dokumentation) und `081a8b8` (Framework, 36 Stubs, Canteen-Finale, MP-Dokumente) —
und ein privates Remote: `https://github.com/whatsaheart-oxxzy/kenopsia-roblox`,
Branch `master`. `.gitignore` schließt seither zusätzlich `*.blend1` aus;
`CP_Observer.blend` bleibt bewusst versioniert.

---

### F-02 · ZURÜCKGEZOGEN — Messartefakt, die Kapazität stimmt

**Ursprüngliche Behauptung:** Die publizierte Serverkapazität sei `60`, während
`GameConfig` vier erwartet, und auf einem öffentlichen Server kämen dadurch 56
Spieler in eine leere Welt.

**Das war falsch.** `Players.MaxPlayers` aus dem Studio-**Edit**-Modus meldet `60` —
den Engine-Standard, nicht den konfigurierten Wert des Place. Maßgeblich ist
*File → Game Settings → Places → Server Size*, und der steht für Kenopsia_MainGame
auf **4**, in Übereinstimmung mit `GameConfig.Players.MaximumPerServer = 4` und
`Room.MaxPlayers = 4`. Kenopsia_DEV steht davon getrennt auf 28.

**Lehre für künftige Aufnahmen:** Die Server-Größe ist über **keine** API und über
keinen MCP-Aufruf lesbar. `Players.MaxPlayers` ist im Edit-Modus dafür wertlos. Wer
sie dokumentieren will, sieht im Dialog nach oder hält fest, dass der Wert nicht
erhoben werden konnte — und zitiert nicht die API.

**Folge für F-09:** Die dortige Wirkung ist kleiner als beschrieben. Bei Kapazität 4
und Raumgröße 4 entstehen Zuschauer nur durch Nachzügler in ein laufendes Match,
nicht serverweit. F-09 bleibt gültig, rutscht aber von „betrifft die Mehrheit der
Spieler" auf „betrifft Nachzügler".

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

### F-04 · (Stand 21.08., historisch) Das Framework war geschrieben, aber nicht im Place — und die zwölf Trials waren leer

> **ERLEDIGT 22.08.2026.** Framework gepusht und 62/62 Skripte byte-identisch gemessen
> (`docs/research/2026-08-22-sweep/03-live-place.md`), Smoke-Test P0.1 gespielt
> (`docs/QA/2026-08-22-framework-smoke.md`). Der Text darunter beschreibt den 21.08.

**Beleg (21.08.):** Der Place enthält unter `Services` genau zehn Module. `TrialKit`,
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
*(23.08.2026: MP-06 §0 trägt jetzt den Hinweis; `tests/sorting.lua` ist die erste.)*

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
leere Welt. Betrifft Nachzügler, nicht den Regelfall — siehe die Korrektur unter F-02.

**Behebung:** Entweder Zuschauern einen echten Zuschauermodus geben, oder Beitritte
während eines laufenden Matches gar nicht erst zulassen.

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

### F-15 · (Stand 21.08., historisch) Live-Skripte wichen vom Repo ab

> **ERLEDIGT 22.08.2026:** 62/62 byte-identisch (Checksumme `(h*31+b) % 2^31`, Luau und
> Python), siehe `docs/research/2026-08-22-sweep/03-live-place.md`.

**Beleg (21.08.):** Bytegenaue Gegenüberstellung:

| Skript | Live | Repo | |
|---|---:|---:|---|
| `MachineFlow` | 22 840 | 27 222 | **Repo ist voraus** |
| `GameConfig`, `Pacing`, `Playlist`, `KenopsiaClient`, `MachineLayout` | | | **Repo ist voraus** |
| `RoomService`, `BirdHunting`, `Minefield`, `BloodFX`, `Contexts`, `CanteenProtocol`, `CanteenProps`, `CanteenBoss`, `CanteenDiner`, `Scoring`, `Envelope` | | | identisch |

**Wirkung:** `studio-src/` ist **kein** Spiegel des Places mehr. Die Frage „was läuft
live?" darf niemals durch Lesen von `studio-src/` beantwortet werden — dafür ist
dieses Verzeichnis da.

**Behebung:** Der Unterschied ist gewollt — die sechs abweichenden Dateien tragen die
Framework-Änderungen, die noch nicht gepusht sind. Beim Push von F-04 gleichen sie
sich an.

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

**Entschieden 22.08.2026 (Lead):** Chat bleibt **an** in der Lobby und auf den
Maschinen-Screens und ist **aus**, solange ein Trial läuft. Umgesetzt am 23.08.2026 in
`UiFx.client.luau`: `ChatWindowConfiguration.Enabled` und
`ChatInputBarConfiguration.Enabled` folgen `KenopsiaActiveTrial ~= ""`, pcall-geschützt;
Live-Check steht in `docs/QA/2026-08-23-p0-leftovers.md` aus.

---

### F-22 · Alles ist immer geladen

**Beleg:** `StreamingEnabled = false` (bewusst — Streaming zerstörte die
Runner-Kameras auf echten Netzwerk-Clients). Aktuell 1 793 Workspace-Instanzen für
drei Arenen.

**Wirkung:** Bei fünfzehn Arenen à bis zu 300 statischen Teilen kommen bis zu
4 500 dauerhaft geladene Teile dazu. Bei vier Spielern auf Desktop egal, auf
schwachen Telefonen nicht.

**Behebung:** Sicherstellen, dass `TrialKit.ensureArena` wirklich erst beim ersten
Spielen baut und nicht beim Boot. Das ist im Framework so angelegt — beim Einbau
prüfen.

---

## Zusammenfassung

Stand 21.08.2026 (historisch):

| Einstufung | Anzahl | Betrifft |
|---|---:|---|
| **A** blockierend | 3 offen | Springen (F-03), Framework (F-04), Animations-Freigaben (F-05) |
| **A** erledigt | 1 | Sicherung (F-01) |
| **A** zurückgezogen | 1 | Serverkapazität (F-02) — Messartefakt |
| **B** wichtig | 10 | Rundentimeout, Envelope, Token-Kanal, Zuschauer, Audio, Animations-IDs, Touch, Remotes, Pacing, Live/Repo-Drift |
| **C** Aufräumen | 7 | Lampen, Teller, versunkene Props, Altlasten, tote Konfiguration, Chat, Streaming |

Stand 23.08.2026 (siehe Status-Tabelle oben):

| Einstufung | Stand |
|---|---|
| **A** | alle vier erledigt (F-01, F-03, F-04, F-05), F-02 zurückgezogen; Rest von F-05: drei Feld-Clips publizieren (Lead) |
| **B** | erledigt oder strukturell erledigt: F-06, F-07, F-08, F-10, F-11, F-12, F-13, F-14, F-15; halb: F-09 (Zuschauer-Kamera) |
| **C** | erledigt: F-17; entschieden: F-21 (Code da, Live-Check offen), F-22; offen beim Lead: F-16, F-18, F-19; offen C: F-20 |
