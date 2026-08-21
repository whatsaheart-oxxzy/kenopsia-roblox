# MP-07 — Review vor dem Push (F-04)

Prüfung von `TrialKit.luau` gegen die Verträge in `MP-06`, durchgeführt 21.08.2026,
**bevor** das Framework in Place `110672791536316` geht. Rein lesend.

Geprüft: `ensureArena`, `Round:cleanup`, `TrialKit.runRound`, `TrialKit.wireInput`.
Nicht geprüft: `Round:place/sample/tick/kill/out/scores`, `TrialClientKit`, die
Client-Router-Änderungen in `KenopsiaClient`.

**Gesamturteil: tragfähig.** Die Zusagen aus `MP-06` halten dem Lesen stand — der
Abbau ist idempotent und LIFO, `runRound` räumt auf jedem Ausgang genau einmal auf
und wirft den Originaltraceback weiter, die zwölfstufige Eingabekette ist
vollständig implementiert. Drei Punkte gehören trotzdem entschieden, bevor zwölf
Implementierer das Muster kopieren.

---

## R-01 · Arenen werden beim Boot gebaut, nicht beim ersten Spielen

**Beleg.** Jeder Stub ruft in `Trial.init()` auf:

```lua
function Trial.init()
    pcall(TrialKit.ensureArena, TRIAL_ID, buildArena)
end
```

`MachineFlow.start` ruft `init()` auf **jedem** registrierten Modul, auch auf
nicht-fertigen — das ist ausdrücklich so gewollt, damit Remotes beim Boot existieren.
Folge: alle zwölf Arenen entstehen beim Serverstart.

**Wirkung.** Mit den Stubs harmlos: eine Slab, vier Marker, eine Kamera, rund sechs
Teile pro Arena, zusammen ~72. Mit ausgebauten Trials sind es laut Akzeptanzkriterium
bis zu 300 Teile pro Arena — **bis zu 3 600 Teile, die bei jedem Serverstart entstehen
und bei `StreamingEnabled = false` dauerhaft geladen bleiben**, auch wenn eine Session
nur fünf der fünfzehn Trials spielt. Das ist Befund F-22 aus `docs/place/07-FINDINGS.md`,
hier konkret verortet.

**Der Aufruf in `init()` ist reines Vorwärmen.** `runRoundInner` ruft `ensureArena`
ohnehin selbst auf, bevor es platziert. Entfernt man ihn aus `init()`, ändert sich am
Verhalten nichts außer dem Zeitpunkt.

**Warum er trotzdem dasteht:** `buildFn` darf nicht yielden, läuft also synchron. Eine
300-Teile-Arena beim ersten Spielen zu bauen ist ein einmaliger Ruckler pro Arena und
Server.

**Empfehlung.** Aus `init()` streichen und stattdessen die **eingeplanten** Trials beim
Matchstart vorwärmen — `MachineFlow` kennt `order`, bevor das erste Trial läuft. Damit
entstehen pro Server nur die fünf tatsächlich gespielten Arenen, ohne Ruckler. Die
Entscheidung gehört vor den Push, weil das Stub-Muster sonst zwölfmal kopiert wird.

---

## R-02 · `seq` ist beratend, nicht erzwungen

**Beleg.** Stufe 10 der Kette:

```lua
if type(payload.seq) == "number" then
    if payload.seq <= (ps.lastSeq or 0) then return end
    ps.lastSeq = payload.seq
end
```

**Zwei Lücken.**

1. **Weglassen genügt.** Ein Client, der `seq` gar nicht sendet, überspringt die
   Prüfung vollständig. Das ist laut `MP-05` D3 so entworfen, hat aber eine Folge, die
   nirgends steht: der Schutz gegen Wiederholung *innerhalb* einer Runde ist damit
   allein das Ratenlimit aus Stufe 11, nicht die Sequenznummer.
2. **`NaN` hebelt sie dauerhaft aus.** `type(NaN) == "number"` ist wahr, und
   `NaN <= x` ist immer falsch — die Prüfung wird also bestanden und `ps.lastSeq`
   auf `NaN` gesetzt. Wer bei jedem Paket `NaN` sendet, passiert Stufe 10 dauerhaft.
   Auch das bleibt vom Ratenlimit gedeckelt, ist aber ein echter Defekt.

**Empfehlung.** Eine Zeile: `if payload.seq ~= payload.seq then return end` vor dem
Vergleich, oder `seq` verpflichtend machen. Und in `MP-06 §1` klarstellen, dass das
Ratenlimit die eigentliche Schranke ist — damit kein Trial Reihenfolge-Garantien aus
`seq` ableitet, die es nicht gibt.

---

## R-03 · `actions` muss eine Map sein, ein Array schluckt jede Eingabe

**Beleg.** Stufe 3 prüft `not actions[action]`. Der Vertrag in `MP-06 §2.5` zeigt die
Map-Form:

```lua
actions = { cut = true, submit = true }
```

Schreibt ein Implementierer versehentlich `actions = { "cut", "submit" }`, ist
`actions["cut"]` gleich `nil` — **jedes** Eingabepaket wird stumm verworfen. Kein
Fehler, keine Warnung, kein Log: das Minispiel rendert einwandfrei und reagiert auf
nichts.

Das ist exakt die Fehlerklasse, die dieses Projekt schon einmal getroffen hat (der
Canteen-Token-Bug F-1: perfekt aussehendes, unspielbares Minispiel).

**Empfehlung.** Drei Zeilen in `wireInput`: bei `actions[1] ~= nil` einmal warnen und
die Array-Form in eine Map umschreiben, statt sie stillschweigend zu ignorieren.

---

## Was beim Lesen ausdrücklich in Ordnung war

- **`ensureArena` ist ehrlich idempotent.** Das Attribut `Built` überlebt ein
  Speichern des Place, der Refs-Cache nicht — ein Ordner, der `Built` ist, aber keinen
  Cache hat (Server aus gespeichertem Place gestartet), wird geleert und neu gebaut.
  Die Refs beschreiben also immer, was wirklich dasteht.
- **`Round:cleanup` hebt die Registrierung ZUERST auf**, danach erst den Rest. Jeder
  verzögerte Callback, der `R:active()` prüft, scheitert ab diesem Moment — genau die
  Reihenfolge, die `Contexts` in seinem Kopf als Fehlerquelle beschreibt.
- **Abbau ist LIFO und einzeln `pcall`t**, ein fehlerhafter Teardown reißt die
  übrigen nicht mit.
- **`runRound` räumt auf jedem Ausgang genau einmal auf** und wirft danach den
  ursprünglichen Traceback weiter, statt eine kaputte Runde mit Nullpunkten zu
  wiederholen.
- **Humanoide werden vollständig zurückgesetzt** — `WalkSpeed`, `JumpPower`,
  `Anchored` und alle drei `XBot*`-Attribute.
- **`wireInput` ist wiederholbar**: ein zweiter Aufruf trennt die vorherige
  Verbindung, `init()` bleibt also idempotent.

---

## Entscheidungen (21.08.2026)

Alle drei werden **vor** dem Push umgesetzt, solange noch kein Trial gegen das
Framework geschrieben wurde.

### R-01 → Arenen werden lazy gebaut

`pcall(TrialKit.ensureArena, TRIAL_ID, buildArena)` wird aus `Trial.init()` in allen
zwölf Stubs **gelöscht**. `runRoundInner` ruft `ensureArena` ohnehin selbst auf.

Begründung, warum nicht beim Boot: das Vorwärmen sollte Fehler früh und laut zeigen,
statt sie mitten in einer Runde als Match-Abbruch hochkommen zu lassen. Dieses
Argument trägt nicht — `MP-05 §F` Schritt 5 verlangt **pro Trial eine gespielte Runde,
bevor `ready = true` gesetzt wird**. Die Arena ist bewiesen, bevor ein Spieler sie
sieht. Außerdem: ein fehlendes Origin liefert `nil` und wird in `runRoundInner` sauber
zu Nullpunkten; nur ein *werfendes* `buildFn` bricht den Match ab, und das ist ein
Codefehler, den genau dieses Tor fängt.

Begründung, warum nicht beim Matchstart: `MachineFlow` kennt die `buildFn` der Module
nicht. Das ginge nur über eine neue Vertragsfläche (`Trial.prewarm()` o. ä.), die
zwölf Implementierer lernen müssten. Eine gelöschte Zeile pro Stub ist billiger als
eine erweiterte API.

Preis: ein einmaliger synchroner Bau von einigen Dutzend Millisekunden beim ersten
Spielen jedes Trials pro Server. Gegenwert: statt bis zu 3 600 dauerhaft geladenen
Teilen existieren nur die tatsächlich gespielten Arenen.

Geprüft: nichts liest die Refs vor der ersten Runde. `kit.arena()` auf der Clientseite
läuft frühestens in `begin`, und `MP-06 §4.1` verbietet ausdrücklich, in `init` etwas
zu bauen.

**Änderung:** in `Services/{CutToSpec, ArmsIssue, Upstream, FloorCheck, Clearance,
Carrier, Breather, ClearTheDeck, Crawler, Ricochet, PalletDuty, SortingFloor}.luau`
die `pcall(TrialKit.ensureArena, …)`-Zeile entfernen; die Vorlage in `MP-06 §2.7`
entsprechend anpassen.

### R-02 → NaN abfangen, `seq` bleibt optional

`seq` verpflichtend zu machen bräche `MP-05 D3` und schüfe einen neuen Fehlermodus,
ohne etwas zu gewinnen: das Ratenlimit aus Stufe 11 deckelt Missbrauch ohnehin. Die
NaN-Lücke ist dagegen ein echter Defekt.

**Änderung** in `TrialKit.wireInput`, Stufe 10:

```lua
if type(payload.seq) == "number" then
    if payload.seq ~= payload.seq then return end        -- NaN: haelt jeden Vergleich aus
    if payload.seq <= (ps.lastSeq or 0) then return end
    ps.lastSeq = payload.seq
end
```

Dazu ein Satz in `MP-06 §1`: **Stufe 11 ist die eigentliche Schranke gegen
Wiederholung innerhalb einer Runde**, nicht `seq`. Kein Trial darf
Reihenfolge-Garantien aus `seq` ableiten.

### R-03 → Array-Form normalisieren *und* warnen

Nur zu warnen lässt das Trial kaputt; wer die Array-Form schreibt, merkt es sonst erst
im Playtest. Also beides — normalisieren, damit es funktioniert, warnen, damit es
auffällt. Die Warnung landet im Output, den das Integrationstor per
`get_console_output` ohnehin prüft.

**Änderung** in `TrialKit.wireInput`, direkt nach `local actions = spec.actions or {}`:

```lua
if actions[1] ~= nil then
    warn(("[TrialKit:%s] actions was given as an array; expected a map like "
        .. "{ cut = true }. Normalising - fix the trial module."):format(trialId))
    local map = {}
    for _, name in ipairs(actions) do map[name] = true end
    actions = map
end
```

---

## Reihenfolge beim Push

1. R-02 und R-03 in `TrialKit.luau` einarbeiten, `tests/trialrules.lua` und
   `tests/rules.lua` erneut laufen lassen (beide berühren `wireInput` nicht, sollten
   also unverändert grün bleiben — falls nicht, ist die Änderung falsch).
2. R-01 in den zwölf Stubs, `MP-06 §2.7` nachziehen.
3. luau-lsp und selene erneut über `studio-src`; erwartete Basislinie: 3 selene-Fehler
   in `KenopsiaClient`, keine Meldung in den neuen Dateien.
4. Erst dann der Transfer nach `MP-05 §F`.
