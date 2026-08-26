# MP-08 — Todesanzeige, Zuschauermodus, Crawl, Selection-Panel

**Ziel:** `docs/MP-08-DEATH-AND-SPECTATE.md` im Repo
`C:\Users\Asus\Claude\Kenopsia_Roblox Project`.
Liegt vorerst hier, weil in dieser Session kein Schreibzugriff aufs Repo
besteht (siehe Abschnitt 4).

Aufgabe (User, 26.08.2026):

1. Canteen Protocol: bei einem Tod bekommen **alle** die Todesanzeige und sehen
   dadurch nicht mehr, ob der Boss sie anschaut. Nur der Gestorbene soll sie
   bekommen.
2. Dead Zone: beim Krabbeln steht eine **eingefrorene UI** im Weg, man sieht
   nichts mehr. Und: Crawl-Geschwindigkeit soll der Lauf-Geschwindigkeit
   entsprechen.
3. Alle drei Minigames: wer stirbt, ist bis zur **neuen Runde** im
   Zuschauermodus. Kreativ gestalten.
4. Wenn ein Minigame endet und das nächste startet, soll das **Selection-Panel**
   das gewählte Minigame zeigen.

---

## 0. Befund — eine Ursache hinter (1) und (2)

Die drei Live-Trials sind `birdhunt` (BIRD HUNTING), `minefield` (DEAD ZONE)
und `canteen` (CANTEEN PROTOCOL) — `MachineFlow.luau:65–119`, alle drei
`ready = true`.

### B-01 — `role="spectate"` ruft kein `hideAll()` (KRITISCH)

`KenopsiaClient.client.luau:2551`, im Dispatch unter `p.kind == "role"`:

```lua
if p.role == "spectate" then
    faderFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    faderFrame.BackgroundTransparency = 0
    faderFrame.Visible = true
    task.delay(0.6, function() faderFrame.Visible = false end)
    local pos  = Vector3.new(p.pos[1],  p.pos[2],  p.pos[3])
    local look = Vector3.new(p.look[1], p.look[2], p.look[3])
    spectateCF    = CFrame.lookAt(pos, look)
    spectateWatch = p.watch
    ...
    return            -- <== kein hideAll()
end
```

Der Zweig kehrt zurück, **bevor** die Bildschirm-Weiche am Ende des Dispatch
(`session += 1` … `hideAll()`, Zeile 2789–2818) erreicht wird. Die Vollbild-
karte, die den Tod angekündigt hat, bleibt also stehen.

Dazu kommt: `showAnnounce` (Zeile 2341) blendet sich **nie selbst aus**.

```lua
local function showAnnounce(p, token)
    hideAll()
    if p.style == "death" then
        announceScreen.BackgroundTransparency = 0.4          -- Welt bleibt sichtbar
        announceScreen.Line.TextColor3 = Color3.fromRGB(255, 48, 32)
        task.delay(Feel.Death.Hold, function()               -- 2.5 s
            ... TweenService:Create(..., { BackgroundTransparency = 0 }) -- volles Schwarz
        end)
    else
        announceScreen.BackgroundTransparency = 0            -- SOFORT undurchsichtig
        announceScreen.Line.TextColor3 = PHOSPHOR
    end
    announceScreen.Visible = true
    ...
end
```

`showRoleCard` hat `task.delay(p.seconds, hideAll)`, `showPodium` hat eine
Deadline — `showAnnounce` ist die einzige Screen-Funktion ohne Selbstabbau.

**Zeitachse Dead Zone, zweite Mine** (`Minefield.luau:523`):

| t     | Ereignis                                                        |
|-------|-----------------------------------------------------------------|
| 0.0 s | `announce style="death"` → Karte, Welt zu 60 % sichtbar          |
| 2.5 s | `Feel.Death.Hold` → Tween auf `BackgroundTransparency = 0`       |
| 3.0 s | Bild vollständig schwarz                                        |
| 3.2 s | `role="spectate"` → Kamera wechselt, **Karte bleibt oben**       |
| ∞     | Schwarz mit rotem Text, bis ein anderes Screen-Paket kommt       |

Das ist „man kann nichts weiter sehen“. Der Zuschauermodus läuft die ganze
Zeit korrekt — nur sieht ihn niemand.

**Dasselbe beim Krabbeln, ganz ohne Tod** (`Minefield.luau:514`):

```lua
tellOne(uid, { kind = "announce", style = "warn", text = "LEGS GONE. CRAWL." })
```

`style ~= "death"` ⇒ `BackgroundTransparency = 0` **sofort**, kein Timer, und
der Server schickt danach kein `hide`. Der Krabbler ist ab diesem Moment blind
bis zum Rundenende. Das ist die „eingefrorene UI“.

### B-02 — Canteen sendet die Todeskarte an den ganzen Raum (KRITISCH)

`CanteenProtocol.luau:388`:

```lua
tellOne(userId, { kind = "cpout", reason = reason })          -- richtig: nur er
announce(st.room, { kind = "announce", style = "death",       -- falsch: alle
    text = ("PROTOCOL VIOLATION - %s"):format(...) })
```

`announce()` (Zeile 335) iteriert `room.members` und feuert an jeden. Jeder
Überlebende bekommt damit `hideAll()` — also auch das Canteen-HUD weg — plus
die Karte, die nach 2.5 s auf volles Schwarz zieht. Mitten in einer Runde, in
der man den Observer sehen **muss**.

Verschärfend: in Canteen sitzt jeder von Anfang an in `role="spectate"` auf der
festen Tischkamera (`CanteenProtocol.luau:845`). Die Karte deckt also exakt das
Bild zu, auf das es ankommt.

### B-03 — Bird Hunting beendet den Zuschauermodus zu früh (HOCH)

`BirdHunting.luau:722` schickt 2.0 s nach dem Tod `role="spectate"`.
`BirdHunting.luau:736` ruft nach `KILL_VIEW_TIME` `clearParticipant(...)`, und
das feuert `role="none"` (Zeile 417). Der Client verlässt damit den
Spectate-Zweig (`spectateCF = nil`, Zeile 2569) und die Kamera springt zurück
auf den eigenen Körper am Spawn. Der Tote sieht den Rest des Legs sich selbst
zu — statt „bis die neue Runde startet“.

### B-04 — Crawl 4.2 gegen Lauf 7…10 (vom User beauftragt)

`Minefield.luau:48` `CRAWL_SPEED = 4.2`. Der Läufer rampt im Client von 7 auf
10 (`KenopsiaClient.client.luau:471` plus Ramp 497–517).

**Ausdrücklich festgehalten:** `MIN_SHRED_SPEED = 4.6` ist die
Compactor-Geschwindigkeit. Mit Crawl = Lauf holt der Compactor einen Krabbler
**nie mehr** ein — die Beinamputation kostet dann nur noch Optik, keine Zeit.
Das ist die beauftragte Wirkung; hier notiert, damit sie nicht später als Bug
zurückkommt.

### B-05 — kein Selection-Panel zwischen den Trials (vom User beauftragt)

`MachineFlow.luau:841` schickt in der Trial-Schleife nur
`{ kind = "info", id, name, icon, index, total }`. Das Roulette
(`kind = "selection"`) läuft ausschließlich einmal in `preFlow` vor dem Match
(`MachineFlow.luau:425`). Der Client kann es längst (`showSelection`,
Zeile 1998) und braucht nur `icons` (3 Namen) und `chosen` (1–3).

### Weitere Funde aus demselben Durchgang

* **B-06 (MITTEL)** — `Minefield.luau:535`, äußerer Ring (`KNOCK_RADIUS`),
  setzt das Krabbeln, sendet aber **keine** Nachricht. Der Spieler krabbelt
  ohne Erklärung. Der innere Ring (Zeile 514) sendet eine. Inkonsistent.
* **B-07 (MITTEL)** — `Minefield.luau:585` `style="win"` („SECTOR CLEARED.“)
  ist ebenfalls eine sofort deckende Vollbildkarte; 1.2 s später kommt
  `spectate`. Der Sieger sieht denselben schwarzen Schirm wie der Tote.
  Gleiche Ursache wie B-01.
* **B-08 (NIEDRIG)** — `showAnnounce` braucht ein `seconds`-Feld mit
  Selbstabbau, damit diese Klasse Fehler generisch zu ist.
* **B-09 (NIEDRIG)** — `applyMovement` (Zeile 463–487) kennt das Krabbeln
  nicht: bei `moveState == "runner"` schreibt es hart `7` bzw. `14`. Jedes
  `role`-Paket während des Krabbelns überschreibt damit `CRAWL_SPEED`. Fällt
  heute nicht auf, weil während einer Dead-Zone-Runde kein weiteres
  `role`-Paket kommt — nach S8 ist es ohnehin derselbe Wert.

---

## 1. Entwurf des Zuschauermodus

Vorhanden: freie Kamera auf ein Ziel, Q/E-Wechsel (Gamepad LB/RB, Touch links/
rechts), `SpectateCaption` unten mittig — `KenopsiaClient.client.luau:566–619`.
Der Server liefert bereits die `watch`-Liste der noch Lebenden.

Ausbau, im Register der Maschine (klinisch, phosphorgrün, keine
Sportübertragung):

```
 ┌ OBSERVATION DECK ─────────────────────────────┐
 │  SUBJECT 03 // TAMEM           [Q] ◀   ▶ [E]  │
 │  STATUS     ALIVE                             │
 │  REMAINING  2 OF 4                            │
 └───────────────────────────────────────────────┘
```

* **Kill-Feed statt Vollbildkarte.** Jede Eliminierung im Raum wird eine Zeile
  rechts oben, 4 s Standzeit, dann Ausblenden. Rot für den Tod, phosphorgrün
  für „RATION COMPLETE“ / „SECTOR CLEARED“. Neues Paket
  `{ kind = "feed", text = ..., style = ... }`. Es ersetzt genau das
  Broadcast-`announce`, das heute alle blendet.
* **Vollbildkarte nur für den Betroffenen**, Look unverändert, aber mit
  `seconds` und Selbstabbau (B-08) — sie gibt den Zuschauermodus frei, statt
  ihn zuzudecken.
* **Zähler `REMAINING n OF m`** aus der `watch`-Liste, die der Server schon
  schickt. Macht sichtbar, warum die Runde noch läuft.
* **Scanlinien-Rahmen** ums Bild, damit der Zuschauermodus auf einen Blick vom
  Spielbild unterscheidbar ist — dieselbe Sprache wie die CRT-Overlays.
* **Dauer:** bis `role="none"` oder ein Lobby-Screen kommt, also bis zur
  nächsten Runde. Kein Timer, der den Modus vorher beendet (B-03).

---

## 2. Schritte

| #   | Datei | Änderung | Behebt |
|-----|-------|----------|--------|
| S1  | `KenopsiaClient.client.luau` | `spectate`-Zweig ruft `hideAll()`, bevor er die Kamera setzt | B-01, B-07 |
| S2  | `KenopsiaClient.client.luau` | `showAnnounce` nimmt `p.seconds` und baut sich selbst ab | B-08 |
| S3  | `KenopsiaClient.client.luau` | neues `kind="feed"` + Kill-Feed-Widget, `K.KNOWN_KINDS` ergänzen | B-02, B-06 |
| S4  | `CanteenProtocol.luau` | Todeskarte per `tellOne`; der Raum bekommt eine `feed`-Zeile | B-02 |
| S5  | `Minefield.luau` | Krabbel-Hinweis wird `feed`; äußerer Ring bekommt dieselbe Zeile | B-01, B-06 |
| S6  | `KenopsiaClient.client.luau` | Observation Deck: Rahmen, Statusblock, `REMAINING n OF m` | (3) |
| S7  | `BirdHunting.luau` | `clearParticipant` schickt für Tote kein `role="none"` mehr | B-03 |
| S8  | `Minefield.luau` + Client | `CRAWL_SPEED` = Laufgeschwindigkeit; Ramp auch beim Krabbeln; `applyMovement` respektiert `XBotCrawl` | B-04, B-09 |
| S9  | `MachineFlow.luau` | `runSelection` in `iconsFor(trial)` zerlegen; in der Trial-Schleife `kind="selection"` vor `kind="info"` | B-05 |
| S10 | `Pacing.luau` | `Timing.TrialReveal` für den Roulette-Halt zwischen den Trials | B-05 |
| S11 | `tests/rules.lua` | neue Pacing-Zeile und die `feed`-Zusage absichern | — |

Reihenfolge: **S1 → S2 → S3 → S4 → S5 → S6 → S7 → S8 → S9 → S10 → S11.**
S1 allein macht den Zuschauermodus in allen drei Spielen sichtbar; alles
Weitere baut darauf auf.

---

## 3. Die Änderungen im Einzelnen

### S1 — `KenopsiaClient.client.luau`, Zeile 2551

```lua
	if p.role == "spectate" then
		-- 26.08.2026 (user, MP-08 B-01): DIE SCHEIBE ZUERST FREIRAEUMEN. Dieser
		-- Zweig kehrt vor der Screen-Weiche am Ende des Dispatch zurueck, also
		-- ruft fuer ihn nie jemand hideAll() -- und die Karte, die den Tod
		-- angekuendigt hat, steht noch. showAnnounce("death") zieht bei
		-- Feel.Death.Hold (2.5 s) auf BackgroundTransparency 0, das
		-- spectate-Paket kommt bei Feel.Death.Spectate (3.2 s): der
		-- Zuschauermodus lief die ganze Zeit hinter schwarzem Glas. Gilt genauso
		-- fuer die "SECTOR CLEARED."-Karte (B-07) und den Krabbel-Hinweis, der
		-- ueberhaupt keinen Timer hatte.
		hideAll()
		-- 24.08.2026 (user): death -> a black beat -> VIEWER MODE. ...
		faderFrame.BackgroundColor3 = Color3.new(0, 0, 0)
```

### S2 — `showAnnounce`, Zeile 2341

`p.seconds` (optional) hängt einen Selbstabbau an, gegen `token` gesichert:

```lua
	announceScreen.Visible = true
	announceScreen.Line.Text = ""
	local secs = tonumber(p.seconds)
	if secs and secs > 0 then
		-- B-08: showRoleCard und showPodium raeumen sich selbst ab, showAnnounce
		-- war die einzige Ausnahme. Ein Sender, der weiss wie lange die Karte
		-- stehen soll, sagt es jetzt -- statt darauf zu bauen, dass irgendwann
		-- ein anderes Paket hideAll() ausloest.
		task.delay(secs, function()
			if session == token then hideAll() end
		end)
	end
```

### S3 — Kill-Feed, neu im Client

`K.KNOWN_KINDS` bleibt unberührt (der Feed wird **vor** der Weiche abgefangen
und darf `session` nicht hochzählen — sonst bricht er laufende Typewriter ab):

```lua
	if p.kind == "feed" then
		pushFeed(p.text, p.style)
		return
	end
```

`pushFeed` baut lazy einen `Frame` „KillFeed“ oben rechts unter `machine`,
`UIListLayout` von oben nach unten, max. 4 Zeilen, jede 4 s sichtbar, dann
`TextTransparency`-Tween und `Destroy`. Rot = `Color3.fromRGB(255, 48, 32)`,
sonst `PHOSPHOR`. ZIndex 66, wie `SpectateCaption`.

### S4 — `CanteenProtocol.luau`, Zeile 388

```lua
	-- MP-08 B-02: die Vollbildkarte gehoert dem Gestorbenen. announce() feuerte
	-- sie an jeden im Raum, und showAnnounce("death") zieht nach 2.5 s auf
	-- volles Schwarz -- mitten in einer Runde, in der man den Observer sehen
	-- MUSS. Der Raum bekommt jetzt eine Feed-Zeile, die nichts zudeckt.
	local who = Players:GetPlayerByUserId(userId)
	local name = (who and who.DisplayName) or "SUBJECT"
	tellOne(userId, { kind = "cpout", reason = reason })
	tellOne(userId, { kind = "announce", style = "death", seconds = 3.0,
		text = ("PROTOCOL VIOLATION - %s"):format(name) })
	for _, mm in st.room.members do
		if mm.userId ~= userId then
			tellOne(mm.userId, { kind = "feed", style = "death",
				text = ("%s - PROTOCOL VIOLATION"):format(string.upper(name)) })
		end
	end
```

`seconds = 3.0`: die Karte steht 2.5 s (`Feel.Death.Hold`), zieht in 0.5 s auf
Schwarz und geht dann weg — der Gestorbene sitzt in Canteen bereits auf der
festen Tischkamera und ist damit sofort wieder Zuschauer.

### S5 — `Minefield.luau`, Zeilen 514 / 535–556

Zeile 514 wird zu einer Feed-Zeile, und der äußere Ring bekommt dieselbe:

```lua
	tellOne(uid, { kind = "feed", style = "warn", text = "LEGS GONE. CRAWL." })
```

Zeile 523 (zweite Mine, Tod) bekommt `seconds = 3.0` wie in S4.
Zeile 585 („SECTOR CLEARED.“) ebenfalls `seconds = 1.2`, passend zum
`spectate`-Paket 1.2 s später.

### S6 — Observation Deck

Erweiterung des bestehenden `do`-Blocks um `SpectateCaption`
(Zeile 566–619). Statt einer Zeile ein `Frame` mit drei `TextLabel`
(`SUBJECT`, `STATUS`, `REMAINING`) plus 1-px-Rahmen; die 0.4-s-Schleife, die
heute schon läuft, schreibt sie. `REMAINING` = Anzahl der Einträge in
`spectateWatch`, die gerade eine lebende Figur haben.

### S7 — `BirdHunting.luau`, Zeile 402/736

`clearParticipant` bekommt ein zweites Argument `keepCamera`:

```lua
	local function clearParticipant(uid, subject, keepCamera)
		...
		if player then
			if not subject or player.Character ~= subject.char then clearCharacter(player.Character) end
			-- MP-08 B-03: role="none" raeumt spectateCF im Client ab. Fuer einen
			-- Toten ist das das Ende des Zuschauermodus mitten im Leg. cleanupRound
			-- schickt es am Rundenende ohnehin an jeden -- das ist die Stelle, an
			-- der es hingehoert.
			if MachineState and not keepCamera then
				MachineState:FireClient(player, { kind = "role", role = "none" })
			end
		end
	end
```

Aufruf in `dropRunner` (Zeile 741): `clearParticipant(plr.UserId, s, true)`.

### S8 — Crawl-Geschwindigkeit

`Minefield.luau:48`:

```lua
-- 26.08.2026 (user): das Krabbeln ist so schnell wie das Rennen. Der Client
-- rampt einen Laeufer von RUN_BASE auf RUN_TOP (KenopsiaClient applyMovement +
-- Ramp); der Krabbler bekommt jetzt denselben Endwert.
-- FOLGE, bewusst: MIN_SHRED_SPEED (4.6) ist die Compactor-Geschwindigkeit. Er
-- holt einen Krabbler damit nie mehr ein -- die Beinamputation kostet Optik,
-- keine Zeit.
local CRAWL_SPEED = 10
```

Client, `applyMovement` (Zeile 467–471) — B-09:

```lua
	if moveState == "runner" then
		local moves = char:GetAttribute("XBotMoves") or ""
		local scan = string.find(moves, "scan") ~= nil
		-- MP-08: ein Krabbler behaelt die Laufgeschwindigkeit. Vorher schrieb
		-- diese Zeile hart 7 zurueck und haette CRAWL_SPEED ueberschrieben.
		hum.WalkSpeed = scan and 7 or 14
	end
```

und in der Ramp-Schleife (Zeile 506) das `return` beim Krabbeln entfernen,
damit der Krabbler dieselbe 7→10-Rampe fährt.

### S9 / S10 — Selection-Panel zwischen den Trials

`MachineFlow.luau`: der Icon-/Köder-Aufbau aus `runSelection`
(Zeile 376–401) wird zu `local function iconsFor(trial)` herausgezogen;
`runSelection` ruft ihn auf. In der Trial-Schleife vor Zeile 841:

```lua
			-- MP-08 (user): das Roulette lief nur einmal vor dem Match. Jeder
			-- Trial-Wechsel bekommt es jetzt auch -- dieselbe Praesentation, mit
			-- der die Lobby die erste Wahl zeigt.
			local icons, chosenIdx = iconsFor(trial)
			tell(ctx, { kind = "selection", icons = icons, chosen = chosenIdx,
				name = trial.displayName })
			if not hold(ctx, Pacing.Timing.TrialReveal) then return end

			tell(ctx, { kind = "info", id = trial.id, name = trial.displayName,
				icon = trial.icon, index = trialIndex, total = #order })
			if not hold(ctx, Pacing.Timing.Reveal) then return end
```

`Pacing.Timing.TrialReveal = 6.4` (wie `LobbyReveal`; `Feel.rouletteSeconds(3)`
liegt bei ≈ 5.9 s, der Halt muss darüber liegen).

Das verlängert jeden Trial-Wechsel um 6.4 s. Bei drei Trials sind das
+12.8 s pro Session (der erste Trial hat sein Roulette schon aus `preFlow` —
dort wird es **nicht** doppelt gezeigt, siehe S9-Detail: `trialIndex == 1 and
room.preShown` überspringt es).

---

## 4. Ausgeführt — 26.08.2026

S1–S11 umgesetzt, offline geprüft und per `.Source` ins Place
110672791536316 geschrieben. Der Abschnitt hier hielt vorher fest, dass die
Planungs-Session keinerlei Schreibrecht hatte; das ist erledigt und wird
durch das Ergebnis ersetzt.

**Alle sechs Skripte in place, byte-identisch zu `studio-src/`, `debugId`
unverändert** (vor dem ersten Schreiben abgelesen, danach gegengeprüft):

| Instanz | debugId | Bytes |
|---|---|---|
| `ReplicatedStorage.Kenopsia.Shared.Rules.Pacing` | `1_20730` | 7 113 |
| `…Services.MachineFlow` | `1_20749` | 47 154 |
| `…Services.BirdHunting` | `1_20750` | 39 615 |
| `…Services.Minefield` | `1_20751` | 44 490 |
| `…Services.CanteenProtocol` | `1_20754` | 38 787 |
| `StarterPlayer.StarterPlayerScripts.KenopsiaClient` | `1_18793` | 125 262 |

Geschrieben mit `execute_luau` + exakten Splices unter
`ChangeHistoryService:TryBeginRecording` — nie löschen/neu anlegen. Die
Splice-Funktion bricht ab, wenn ein Anker fehlt **oder zweimal vorkommt**,
also wird nie geraten. Verifiziert über Länge + Rolling-Hash gegen die
lokalen Dateien; `.gitattributes` verlangt Byte-Gleichheit, und genau die
hat den einen Unterschied gefunden, der sonst durchgerutscht wäre (eine
verschluckte Leerzeile vor `local function cycle`).

10/10 Offline-Suites grün. selene: **3 Fehler statt 4** vor der Änderung,
0 parse errors.

### Zwei Funde, die der neue Test in S11 aufgedeckt hat

* **`BirdHunting` rief in `dropRunner` ein `tellOne()`, das dort nie
  definiert war** — ein undefiniertes Global. Das spectate-Paket für einen
  erschossenen Läufer lief also in „attempt to call a nil value" und kam nie
  an: **der Zuschauermodus hat in BIRD HUNTING noch nie funktioniert.**
  Deshalb war B-03 (role="none" beendet ihn zu früh) auch gar nicht
  beobachtbar — es gab nichts zu beenden. Ohne diesen Helfer wäre S7
  wirkungslos geblieben.
* **Der Compactor-Tod („PROCESSED.", `Minefield`)** ist dieselbe Figur wie
  die zweite Mine — Todeskarte, 3.2 s später `spectate`. Der Plan nennt nur
  die Minenzeile; gleicher Fehler (B-01/B-08), also derselbe Timer.

### Abweichung vom Plan

Die beiden Minen-Ringe führten schon vorher dieselben sechs Anweisungen aus
und waren mit der Feed-Zeile aus B-06 Zeichen für Zeichen gleich (selene:
`if_same_then_else`). Zusammengelegt, statt die Zeile zweimal zu pflegen:
der Todeszweig prüft jetzt auf `ps.crawling`, der Maim-Zweig auf
`not ps.crawling`. Die vier Fälle (innen/außen × krabbelnd/nicht) treffen
exakt wie vorher.

S10 hängt an einer eigenen `Pacing.Timing`-Zeile (`TrialReveal`), damit der
Preis des Beats drehbar ist, ohne die Lobby mitzudrehen. Die Untergrenze ist
die Laufzeit des Rads im Client (`Feel.rouletteSeconds(3)` ≈ 5.9 s) — das
sichert `tests/feel.lua` ab, nicht ein Vergleich gegen `LobbyReveal`.
