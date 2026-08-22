# PLAN — Kenopsia auf Party-Spiel-Niveau

> Zielort: `C:\Users\Asus\Claude\Kenopsia_Roblox Project\PLAN.md`
>
> **22.08.2026:** Die Reihenfolge der Arbeit steht jetzt in [`docs/MASTERPLAN.md`](docs/MASTERPLAN.md) (Belege: `docs/research/2026-08-22-sweep/`). Dieses Dokument bleibt das Entscheidungs-Log (E1, E2, §5-Protokoll). Gemessen am 22.08.: Framework, Stubs und die MP-Fassungen von `MachineFlow`/`KenopsiaClient` liegen **im Place** (62/62 Skripte byte-identisch) — P0-A ist damit gepusht, aber nie rauchgetestet (MASTERPLAN P0.1).

Arbeitsdokument. Stand **21.08.2026**, erstellt aus einer Live-Auslesung des Places
`110672791536316` (Roblox-Studio-MCP) gegen dieses Repo. Kein Plandokument wurde als
Wahrheit übernommen — jede Zahl unten ist gemessen.

Ziel: aus dem laufenden 3-Minigame-Prototyp ein Party-Spiel machen, das die Struktur
des Referenzspiels erreicht (viele kurze, unterschiedliche Prüfungen unter einer
urteilenden Maschine). Grafik/Texturen sind **nicht** Teil dieses Plans — die macht
der Nutzer über die UI.

Verwandte Dokumente: **`docs/place/`** (die gemessene Aufnahme des Live-Place —
Ist-Stand und 22 Befunde), `docs/MP-01-SERVER-CONTRACT.md` (Server-Vertrag),
`docs/MP-02-CLIENT-HOOKS.md`, `docs/MP-03-ASSETS.md`, `docs/MP-04-TRIAL-DESIGNS.md`
(die zwölf Design-Cards), `docs/MP-05-BUILD-PLAN.md` (Bauplan), `docs/MP-06-FRAMEWORK.md`
(API-Vertrag für Implementierer). Dieses Dokument ersetzt sie nicht — es ordnet sie
und korrigiert sie dort, wo die Messung etwas anderes sagt.

---

## 0. Erledigt am 21.08.2026: die Arbeit ist gesichert

Bis zu diesem Tag war der letzte Commit des Repos vom **14.08.2026** (`d5b4486`),
und das Repo hatte **kein Remote** — fünf Tage Arbeit existierten nur auf einer
Festplatte. Behoben in zwei getrennten Commits:

| Commit | Inhalt |
|---|---|
| `bc1160b` | `docs/place/` — vollständige Aufnahme des Live-Place, 8 Dateien, 2 529 Zeilen |
| `081a8b8` | MP-Framework, `TrialKit`/`TrialClientKit`/`TrialRules`, 36 Trial-Stubs, Canteen-Finale, `docs/MP-01…06` — 64 Dateien, 8 586 Zeilen |

Remote: **`https://github.com/whatsaheart-oxxzy/kenopsia-roblox`** (privat, Branch
`master`). Nicht verwechseln mit `kenopsia-bots` — das sind die Discord-Bots.

`.gitignore` schließt bereits `globalTypes.d.luau` und `roblox.yml` aus; neu
hinzugekommen ist `*.blend1` (Blenders Auto-Backup). `CP_Observer.blend` bleibt
bewusst versioniert.

**Neu als Nachschlagewerk:** `docs/place/` beantwortet ab jetzt die Frage „was läuft
live?" — Service-Einstellungen, alle 21 Skripte mit API, die drei Arenen mit jedem
Marker, das ganze GUI, jede Asset-ID, alle Remotes und Pakete, plus 22 Befunde mit
Beleg und Behebung. **Nicht** `studio-src/` dafür lesen: das ist dem Place voraus.

---

## 1. Gemessener Ist-Stand

### Live im Place `110672791536316`

| | |
|---|---|
| Trials `ready = true` | **3** — `birdhunt`, `minefield`, `canteen` |
| Spieler | **4** pro Server, **ein** Raum pro Server (Mehrraum-Modell ausgebaut) |
| Session | ~13 min; davon BIRD HUNTING allein ~6 min (4 Legs × 90 s) |
| Loop | Roulette → Info/Briefing → Trial (n Runden) → Punktetafel → … → `VIABLE`/`REJECTED` |
| Scoring | Borda, exakt 1700 Punkte pro Trial, Gleichstände geteilt |
| Framework | **nicht vorhanden** — kein `TrialKit`, kein `TrialClientKit`, kein `TrialClients` |
| Persistenz | **keine** — 0 Treffer für `DataStore`, `Badge`, `GamePass`, `leaderstats` |
| Audio | 2 Musiktitel (`birdhunt`, `minefield`); `canteen` ohne, `Ambience` leer; 19 SFX-Gruppen |
| Animationen | publiziert und aktiv (Idle/Walk/Run/Crouch/Push/Death + Boss); 6 IDs noch `0` |
| Streaming | `StreamingEnabled = false` |

### Im Repo, nicht im Place

| Baustein | Größe | Zustand |
|---|---|---|
| `TrialKit.luau` | 29 774 B | fertig, offline getestet, **nie gepusht** |
| `TrialClientKit` + Router | vorhanden | dito |
| 12 Server-Trials | je ~2 830 B | **Stubs**, unverändert seit 17.08. 16:58 |
| 12 Client-Trials | je ~1 185 B | **Stubs** |
| 12 `*Rules`-Module | vorhanden | **Stubs** |
| 12 `tests/<id>.lua` | — | **existieren nicht** (MP-06 §0 behauptet das Gegenteil) |
| `docs/MP-04` Design-Cards | 58 673 B | vollständig, bis zur Punkteformel |

Die Stubs sind gut gebaut: sie legen eine Arena an, platzieren Spieler, zählen herunter
und geben Nullpunkte zurück. Ein `ready = true` liefert also bereits eine
vertragskonforme Leerrunde — das Framework lässt sich unabhängig von den Trials
integrieren und rauchtesten.

> **Kernbefund.** Der teure Teil ist bezahlt: Framework, Wire-Protokoll,
> Validierungskette, zwölf durchdesignte Minigames. Was fehlt, ist Ausführung —
> und eine Entscheidung über die Spielerzahl, die mit jedem gebauten Trial teurer wird.

---

## 2. Entscheidungen vor dem Bauen

### E1 — Spielerzahl · ENTSCHIEDEN 21.08.2026: **2–4, fest**

Kenopsia_MainGame bleibt bei maximal vier Spielern, unabhängig von allem Weiteren
(Nutzerentscheidung, „egal wie"). Kenopsia_DEV steht davon getrennt auf 28.
`GameConfig` (`MaximumPerServer = 4`, `Room.MaxPlayers = 4`) stimmt mit den Game
Settings überein — hier ist nichts nachzuziehen.

Ein Vorschlag, auf 6 zu gehen, wurde geprüft und verworfen. Was dabei herauskam und
hier festgehalten gehört:

- **Canteen ist damit korrekt dimensioniert.** `CanteenProtocol` setzt genau
  `#SEAT_IDS` Spieler und überspringt den Rest; sein Kommentar „the room caps at 4"
  ist zutreffend, nicht veraltet. Die vier Sitzplätze im Rig sind kein Mangel.
- **`Pacing` braucht keine Änderung.** `row()` klemmt `n >= 4` auf die `[4]`-Zeile;
  bei einem Maximum von vier wird die Klemme nie erreicht.
- **`RankList` und `Roster` mit je vier Zeilen sind richtig**, ebenso die
  Client-Schleifen `for i = 1, 4`. (Achtung bei künftigen Änderungen dort: eine
  vierte Schleife derselben Form zählt die vier **Odometer-Ziffern**, nicht Spieler.)

Die Konsequenz für §3: an der ersten Vierergruppe ändert sich nichts. `carrier` ist
ein Ansteckungsspiel mit verstecktem Träger, kein Abstimmungsspiel, und funktioniert
zu viert; `stacker` ebenfalls. Beide wären bei mehr Spielern *besser* gewesen — das
ist kein Grund, sie zu streichen.

### E2 — Bauen wir alle zwölf? · **Ja** (korrigiert 21.08.2026)

Eine frühere Fassung dieses Plans behauptete, `floorcheck`, `clearance` und
`ricochet` duplizierten DEAD ZONE und seien zu streichen. **Das war falsch** und ist
hier zurückgezogen. Die Behauptung stammte aus den Einzeilern in `MP-05 §A`; die
Design-Cards in `MP-04` sagen etwas anderes:

| Trial | Was der Spieler tut | Information |
|---|---|---|
| `minefield` DEAD ZONE | vorwärts laufen, mit dem Scanner Wissen kaufen, Zeitpunkt selbst wählen | versteckt, wird aufgedeckt |
| `floorcheck` | auf ein angesagtes Feld treten, Fake-Ansagen erkennen | öffentlich — Timing und Bluff |
| `clearance` | private Nummer lesen, passende Nische finden, Zug ausweichen | privat pro Spieler — Laufen, Lesen, Zuordnen |
| `ricochet` | sichtbare Klingen dodgen, Dash einteilen | vollständig sichtbar — Reflexe und Winkel |

Das sind vier verschiedene Spiele. `clearance` war am stärksten unterschätzt: die
Nischen sind durcheinander beschriftet, die eigene Nummer wird nach jedem Zug neu
vergeben, und die zuletzt benutzte Nische wiederholt sich nie — ein Routing-Spiel
unter Todesdruck.

**Was stattdessen stimmt, viel enger gefasst:** acht der zwölf Entwürfe haben Tod,
und `floorcheck`, `clearance`, `ricochet`, `sweep`, `crawler` teilen dieselbe FORM —
kein FINISH-Zustand, ALIVE-Band, Top-Down-Kamera, Runde endet bei ≤ 1 Überlebendem.
Genau die Form liefert DEAD ZONE bereits. Das Risiko ist nicht Redundanz im Katalog,
sondern **Monotonie innerhalb einer Session**, wenn drei davon hintereinander kommen.

Konsequenz: alle zwölf werden gebaut. Die Reihenfolge in §3 sortiert nach fremdestem
Verb, nicht nach Todesart. Und `Playlist.order` sollte eine Regel bekommen, die
verhindert, dass mehr als zwei Survival-Trials in einer Session aufeinanderfolgen —
das ist billiger und wirksamer als jedes Streichen.

### E3 — Session-Länge

`GameConfig.Playlist.PerSession = 5` (aus MP-05 D7) aktivieren, sobald mehr als fünf
Trials fertig sind. Bis dahin spielt jede Session alles.

---

## 3. Arbeitspakete

### P0-A — Framework in den Place

Voraussetzung für alles Weitere. Danach kostet ein neues Trial vier Dateien statt eines
36-KB-Monolithen, und `TrialKit`s `R:tick` + Failsafe schließt das Loch, dass
`MachineFlow` Rundenlaufzeiten **nicht** begrenzt (ein hängendes Trial hängt heute den
ganzen Match).

Prozedur steht fertig in `docs/MP-05-BUILD-PLAN.md §F`. Kurzfassung:

1. Ein `ChangeHistoryService:TryBeginRecording` um alles.
2. Geteilte Skripte zuerst, `.Source` **in place** bearbeiten, nie löschen/neu anlegen
   (`sessionDebugId` muss stabil bleiben): `Pacing`, `Playlist`, `GameConfig`,
   `MachineFlow`, `KenopsiaClient`, `MachineLayout`.
3. Neue Module unter den exakten Eltern anlegen: `Services.TrialKit`,
   `Shared.Rules.TrialRules`, `StarterPlayerScripts.TrialClientKit`,
   `StarterPlayerScripts.TrialClients` (Folder).
4. **Ein** Stub in einer DEV-Kopie auf `ready = true` flippen, eine Leerrunde spielen:
   `begin` kommt an, `end` kommt an, Spieler kehren heim, kein `_Runtime`-Ordner bleibt
   unter `workspace.KenopsiaArenas.<id>` zurück.
5. Zurückflippen. Erst dann echte Trials.

**Achtung:** `MachineFlow` `init()`t auch nicht-fertige Module. Die zwölf Stubs müssen
also gleichzeitig mit dem Framework hinein, sonst schlägt jeder `require` beim Boot fehl
(genau dafür sind sie da — MP-05 D13).

### P0-B — Vier Trials mit neuen Verben

Reihenfolge nach Spielwert, nicht nach Integrationsrisiko:

| # | id | Anzeige | Bringt neu |
|---|---|---|---|
| 1 | `sorting` | SORTING FLOOR | Urteilen unter Zeitdruck |
| 2 | `upstream` | UPSTREAM | Rennen gegen die Laufrichtung |
| 3 | `stacker` | PALLET DUTY | Physik, stapeln, sabotieren |
| 4 | `carrier` | CARRIER | **soziale Deduktion** — fehlt dem Spiel komplett |

Danach: sieben Minigames mit sieben verschiedenen Spielgefühlen.

`docs/MP-05 §F` integriert stattdessen `floorcheck → breather → sorting → …` und
`carrier` zuletzt. Diese Reihenfolge ist nach **Integrationsrisiko** sortiert und
liefert zuerst ausgerechnet das Trial, das DEAD ZONE am ähnlichsten ist. Der Tausch ist
bewusst: `carrier` bleibt auch hier das letzte der vier, weil es das riskanteste ist —
aber es wird gebaut, nicht vertagt, weil es das Spiel sozial macht.

Pro Trial zu schreiben (MP-06 §0, Ownership-Regeln beachten):

```
studio-src/ServerScriptService/KenopsiaServer/Services/<Name>.luau
studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/<Name>Rules.luau
studio-src/StarterPlayer/StarterPlayerScripts/TrialClients/<id>.luau
tests/<id>.lua                          ← existiert noch nicht, neu anlegen
```

Nie anfassen: `MachineFlow`, `TrialKit`, `TrialClientKit`, `TrialRules`, `Pacing`,
`Playlist`, `GameConfig`, `AnimationIds`, `KenopsiaClient`, `MachineLayout`,
`default.project.json`, `tests/rules.lua`.

### P1 — Tempo und Spannungsbogen

Kleine Eingriffe in vorhandenen Code, zusammen der spürbarste Sprung:

- **BIRD HUNTING kürzen** auf 60 s × 3 Legs (`Pacing.RoundSeconds.birdhunt`, `LEGS`).
  Sechs Minuten für ein Minigame sind eine halbe Session.
- **Letztes Trial doppelt gewichtet**, als `FINAL AUDIT` angekündigt. Ein Faktor in
  `Scoring.distribute`. Heute ist jedes Trial gleich viel wert — wer nach Trial 2 führt,
  gewinnt meist, und die letzten Minuten sind entschieden, bevor sie gespielt werden.
- **Zwischenstand nach jeder Runde.** Heute trennen Runden nur 1,5 s `RoundSettle`; die
  Punktetafel kommt erst nach dem ganzen Trial. Der "wer führt gerade"-Moment fehlt.
- **Podium statt Textliste** am Ende. Auf Roblox ist der Siegermoment das, was
  aufgenommen und geteilt wird — das ist Reichweite, die gerade liegen bleibt.
- **Die Maschine soll reagieren.** Kommentar-Pool je Ausgang, ausgelöst dort, wo ohnehin
  die Punktetafel gesendet wird. Reiner Text gegen ein bestehendes System, größter
  Identitätsgewinn pro Aufwand. Stimme: Großbuchstaben, industriell, keine Witze, keine
  Ausrufezeichen (`MP-05 §A`).

### P2 — Die restlichen Trials

`armory`, `crawler`, `carve`, `breather`, `sweep` — jetzt Fließbandarbeit gegen einen
bewährten Vertrag. `floorcheck`, `clearance`, `ricochet` werden nach E2 **gebaut** (ans Ende der
Reihe); die Regel gegen aufeinanderfolgende Survival-Trials in `Playlist.order` ersetzt jedes Streichen.

Bei mehr als fünf fertigen Trials: `PerSession = 5` aktivieren. 15 Trials mit 5 pro
Session ergeben **3 003 Zusammenstellungen** statt heute 6 Reihenfolgen — gleicher Loop,
gleiche UI, anderes Spiel.

### P3 — Bindung und Politur

- **Persistenz**: gespielte Sessions, Siege, bestes Ergebnis pro Trial → Profilfeld in
  der Lobby. Danach Badges (erste Session, zehnter Sieg, alle Trials gespielt). Erst
  danach Kosmetik und Monetarisierung — vorher gibt es nichts, das sich zu besitzen lohnt.
- **Audio**: `canteen` hat keine Musik, `Ambience` ist leer. Bei fünfzehn Trials
  entweder fünfzehn Titel oder ein Basis-Loop mit Intensitäts-Layer pro Trial.
  Ambience ist der billigste Weg zu Atmosphäre und derzeit ungenutzt.
- **Zuschauer** bekommen von Trials nichts — jeder Sender iteriert `room.members`.
  Wer dazukommt, sieht bis zur nächsten Session eine leere Welt.
- **Arenen-Last**: fünfzehn Arenen à ≤ 300 Teile bei `StreamingEnabled = false` sind bis
  zu 4 500 dauerhaft geladene Teile. Sicherstellen, dass `ensureArena` wirklich erst beim
  ersten Spielen baut, nicht beim Boot.
- **Restliche Animations-IDs** (6 × `0`) und die offenen Handschritte aus `MP-05 §G`.

---

## 4. Meilensteine

| M | Inhalt | Fertig, wenn |
|---|---|---|
| ~~**M0**~~ | ~~Repo gesichert~~ | **erledigt 21.08.2026** — `bc1160b`, `081a8b8`, Remote privat, Push grün |
| ~~**M1**~~ | ~~Spielerzahl entschieden~~ | **erledigt 21.08.2026** — 2–4 fest, keine Nacharbeit nötig |
| **M2** | Framework live | Leerrunde eines Stubs läuft sauber durch, kein `_Runtime`-Rest |
| **M3** | Sieben Minigames | `sorting`, `upstream`, `stacker`, `carrier` fertig und `ready = true` |
| **M4** | Session trägt | Tempo korrigiert, Finale doppelt, Podium, Maschine kommentiert |
| **M5** | Zehn bis zwölf Minigames | `PerSession = 5` aktiv, volle 4-Spieler-Session getestet |
| **M6** | Wiederkommen | Persistenz, Badges, Audio-Lücken geschlossen |

---

## 5. Arbeitsprotokoll für eine Sitzung

Ein Trial pro Sitzung. **Nicht zwei parallel** — sie teilen sich `MachineFlow`, und das
Framework-Design ist ausdrücklich gegen parallele Änderungen an geteilten Dateien
gebaut (MP-05 D13).

Ablauf:

1. `docs/MP-04` Card des Trials lesen (Spielgefühl), dann `MP-05 §A` Zeile (Zahlen),
   dann `MP-06 §2`/`§4` (API).
2. Die vier Dateien schreiben. Regeln-Modul rein und Lua-5.1-portabel halten
   (keine Typannotationen, kein `continue`, kein `+=`, kein `table.create`) — sonst
   läuft der Offline-Beweis nicht.
3. Gate, in dieser Reihenfolge, beim ersten Fehler anhalten:
   ```
   IP-Grep (Referenznamen dürfen in studio-src/ und tests/ nicht vorkommen)
   git diff --stat  →  nur die vier Dateien
   lua tests/<id>.lua                          ≥ 15 Prüfungen, grün
   luau-lsp analyze --definitions=globalTypes.d.luau \
     --base-luaurc=.luaurc --sourcemap=sourcemap.json <dateien>
   selene <dateien>
   Akzeptanzpunkte aus MP-05 §E
   ```
4. Erst dann in den Place pushen (`MP-05 §F`), `ready = true` flippen, eine echte Runde
   spielen, `docs/MP-05-QA-<id>.md` schreiben.
5. Committen und pushen.

Zwei Fallen, die schon Zeit gekostet haben und in `MP-06`/Memory dokumentiert sind:

- **Client-Gates immer über den echten Eingabepfad testen.** Ein synthetischer
  Testclient, der den Round-Token direkt aus dem Paket liest, verdeckt eine ganze
  Fehlerklasse — genau so blieb der Canteen-Token-Bug (F-1) unentdeckt, obwohl das
  Minigame perfekt aussah und unspielbar war.
- **Ein laufendes Treiber-Skript nie löschen** (`arenaBusy` bleibt `true`) — stattdessen
  Play stoppen.

---

## 6. Offene Fragen

1. ~~**E1 — Spielerzahl.**~~ **Entschieden 21.08.2026: 2–4, fest.** Blockiert nichts
   mehr; es gibt keine Nacharbeit.
2. ~~Werden `floorcheck`, `clearance`, `ricochet` gebaut oder gestrichen?~~
   **Entschieden 21.08.2026: alle zwölf werden gebaut.** Die frühere Streich-Empfehlung
   war ein Lesefehler und ist in E2 zurückgezogen. Offen bleibt nur die kleinere Frage,
   ob `Playlist.order` eine Regel gegen aufeinanderfolgende Survival-Trials bekommt.
3. Soll `Kenopsia_DEV` als Testplace weitergeführt werden, oder wird künftig direkt in
   einer Kopie des MainGame getestet?
4. Musik: fünfzehn Titel beschaffen oder ein Layer-System bauen?

---

## 7. Methodik

Live gelesen am 21.08.2026 über die Roblox-Studio-MCP aus dem geöffneten
`Kenopsia_MainGame`: Instanzbaum von `ServerScriptService`, `ReplicatedStorage`,
`StarterPlayer`, `StarterGui`, `SoundService`, `ServerStorage`, `Workspace`; Quelltexte
von `GameConfig`, `Pacing`, `Playlist`, `Scoring`, `MachineFlow`, `AnimationIds`; ein
Marker-Scan über **alle** `LuaSourceContainer` des Datamodels nach `DataStore`,
`MarketplaceService`, `GamePass`, `Badge`, `ProfileStore`, `Leaderstats`.
Repo-Seite: Dateigrößen und Zeitstempel aus dem Dateisystem, Commit-Historie aus
`.git/logs/HEAD`, Remote-Status aus `.git/config`.

Der GitHub-Benutzer `whatsaheart-oxxzy` stammt aus
`AppData/Roaming/GitHub CLI/hosts.yml`, das Repo `kenopsia-bots` aus
`my-discord-bot/.git/config`. Commits, `.gitignore`-Ergänzung und der Push wurden
nachträglich in derselben Sitzung ausgeführt und verifiziert (`git log`,
`git status` sauber, `origin/master` auf `081a8b8`).

Offen: ob die fünf Offline-Testsuiten (`rules`, `envelope`, `contexts`,
`trialrules`, `animationids`) aktuell grün laufen. Sie sind das erste Tor der
Push-Prozedur aus `MP-05 §F` und sollten vor P0-A einmal durchlaufen.
