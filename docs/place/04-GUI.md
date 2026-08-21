# 04 — Die Oberfläche (`KenopsiaMachine`)

Ein einziges `ScreenGui` in `StarterGui`, 521 Nachkommen.

```
ResetOnSpawn    = false
IgnoreGuiInset  = true
DisplayOrder    = 50
Enabled         = true
ZIndexBehavior  = Sibling
```

Der Ladebildschirm liegt darüber (`KenopsiaLoadingGui`, `DisplayOrder = 100`,
gebaut von `ReplicatedFirst.KenopsiaLoading`).

## Farbpalette

Jede Farbe der Oberfläche stammt aus fünf Werten:

| Rolle | Hex | Verwendung |
|---|---|---|
| Phosphor hell | `#78FFAA` | Überschriften, Ziffern, aktive Elemente, Icons, Rahmen |
| Phosphor gedämpft | `#8CE8AE` | Fließtext, Statuszeilen, Namen, Nebenrang |
| Phosphor dunkel | `#2E6B4A` | Grunge-Tint, Rahmen zweiter Ordnung, ausgegraute Zeilen |
| Grund fast schwarz | `#020402` / `#020602` | Screen-Hintergründe |
| Grund tief | `#041005` | Ziffernkacheln, Icon-Aussparungen |
| Gefahrenrot | `#FF1818` | nur `Btn_FIRE` und `Btn_PUNCH` |
| Knochenweiß | `#EBF5EE` | nur das Hüft-Fadenkreuz |

**Schrift: durchgehend `Enum.Font.Code`** — es gibt keine zweite Schriftart im
gesamten GUI.

Das Grunge-Overlay ist immer dasselbe Bild: `rbxassetid://89538183732053`,
gekachelt (`ScaleType = Tile`), Transparenz `0.55`, eingefärbt auf `#2E6B4A`,
als vier Streifen (oben/unten 70 px, links/rechts 90 px) mit je einem `UIGradient`.

## Z-Ordnung

| Z | Element |
|---:|---|
| 1 | `Status`, `Score`, `Selection`, `Info`, `RoundCard`, `Briefing` (die Screens) |
| 55 | `Info.Btn_SETTINGS` |
| 60 / 61 | `Announce` / `Announce.Line` |
| 65 | `Scope` und `Scope.Mask` samt Blenden |
| 66 | `Scope.ZoomLabel`, `HipCross` |
| 67 | `HitMark` |
| 68 | `TouchControls` |
| 70 | `Fader` |
| 80 | `CountText` |
| 82 / 83 | `SettingsPanel` / dessen `Hit`-Buttons |
| 90 | `JoinCover` |

---

## Die sechs Screens

Alle sechs sind vollflächig (`1,0 / 1,0`). Beim Start ist nur `Selection` sichtbar.

### `Selection` — das Roulette *(einziger sichtbarer Screen im Ruhezustand)*

Hintergrund `#020602`, darüber `GrungeWash` (dasselbe Grunge-Bild, Transparenz
`0.25`, Tint `#1E5C38`) und `CenterDark` (`#010301`, Transparenz `0.35`, mit
`UIGradient`).

**`Tiles`** — drei Kacheln bei `x = 0.30 / 0.50 / 0.70`, je 128×128, zentriert.
Jede Kachel hat acht Eckwinkel aus `#78FFAA`-Frames (26×6 und 6×26) und einen
`Icon`-Halter von 78×78 in der Mitte.

**`CrossH` / `CrossV`** — Fadenkreuzlinien über die volle Breite/Höhe, 4 px,
`#78FFAA`, versteckt bis zur Auswahl.

**`BootText`** — `"Simulation bootst:"`, 14 px, rechts bei `x = 0.78`.

**`IconPool`** — acht versteckte Vorlagen à 78×78, alle aus reinen Frames gebaut
(kein einziges Bild):

| Icon | Aufbau |
|---|---|
| `Cube` | 3×3 Raster aus neun 19×19-Blöcken |
| `Magnifier` | Ring (44×44, Stroke 6, runde Ecke) + 30×8-Griff, 45° gedreht |
| `Crosshair` | Ring 48×48 + zwei Balken 72×7 und 7×72 |
| `Saw` | Ring 42×42 (Stroke 7) + Nabe 12×12 + neun Zähne 10×10 in 45°-Schritten |
| `Factory` | Halle 62×26 + zwei Schlote (10×30, 10×22) + zwei Rauchpunkte 8×8 |
| `Utensil` | drei Gabelzinken 4×22 + Stiel 6×26 + Löffelschale 16×22 (rund) + Stiel 6×24 |
| `Train` | Kessel 48×38 (Ecke 8) + zwei Fenster 13×12 in `#041005` + zwei Räder 12×12 |
| `Bug` | Leib 26×34 (rund) + Kopf 16×14 + sechs Beine 18×5 in ±30° |

Verwendet werden davon: `Crosshair` (birdhunt), `Cube` (minefield), `Saw` (canteen).
Decoys: `Magnifier`, `Saw`, `Factory`, `Train`, `Bug`.
**Ein unbekannter Icon-Name rendert stumm `Crosshair`.**

### `Info` — Briefing mit Steuerung, Roster und READY

| Element | Position | Inhalt |
|---|---|---|
| `TopTicker` | `0.13 / 26 px` | `"Simulation bootstrapper completed. Waiting for…"`, 13 px, `#8CE8AE` |
| `NextLabel` | `0.13 / 46 px` | `"NEXT SIMULATION: ------"`, **30 px**, `#78FFAA` |
| `SelIcon` | `15 / 30 px` | 147×141 Rahmen mit acht Eckwinkeln, `Holder` 78×78 mit `UIScale` |
| `ControlsWindow` | `0.13 / 116 px` | 45,5 % × 55,1 %, Stroke 2.4 `#78FFAA` |
| `Roster` | `0.605 / 110 px` | 39 % breit, vier Zeilen |
| `Btn_READY` | `0.61 / 0.117+330` | 38 % × 80 px, Text `"R E A D Y"`, **34 px** |
| `NavCluster` | `0.604 / 0.121+428` | `Marker ▼` + `Track` + `Gauge` (150×22) |
| `Btn_SETTINGS` | rechts oben | 150×36, Z 55, `#8CE8AE` auf Schwarz |

**`ControlsWindow`** enthält:
- `Serration` — 32 Zacken à 5×14 px, `#78FFAA` (der gezackte Rand oben)
- `Title` `"CONTROLS"`, 30 px
- `SecRunners` `"RUNNERS:"` / `SecSniper` `"SNIPER:"` — die zwei Abschnittsköpfe
- `Row1` / `Row1b` / `Row2` / `Row3` — je ein `MouseIcon` (16×22 gerundeter Rahmen
  mit 2×7-Rad) plus Textzeile, 17 px
- `PageLabel` `"Page 1/2"`, `ArrowL ◀` / `ArrowR ▶` (38×26, `#78FFAA`, dunkler Glyph,
  darüber ein unsichtbarer `Hit`-TextButton mit 10 px Rand nach außen)
- `Page2` — die Scoring-Tabelle, versteckt: `H1 "SCORING:"` plus `R1…R5`, 19 px

Der Inhalt von Row1–Row3 wird von `MachineLayout.applyControlsText()` pro Trial und
Plattform überschrieben — die im Place gespeicherten Texte sind der
`birdhunt`-Desktop-Stand.

**`Roster`** — vier Zeilen à 32 px, alle versteckt bis Spieler da sind. Pro Zeile:
`Check` (20×20 Rahmen mit `Fill`), `RankLabel` (`"1."`…`"4."`), `ScoreLabel`
(`"0000"`), `NameLabel`. Alles 20 px.

### `Score` — die Punktetafel

| Element | Position | Inhalt |
|---|---|---|
| `Ticker` | oben, 22 px hoch, `clip` | Lauftext, doppelt so breit wie der Screen: `"SIMULATION CONCLUDED. DISTRIBUTE OPERATOR PERF…"` |
| `ConclusionLabel` | `0.06 / 0.16` | `"SIMULATION CONCLUSION"`, 20 px |
| `ScoreName` | `0.06 / 0.21` | `"OPERATOR\nPERFORMANCE SCORE"`, 22 px |
| `Odometer` | `0.05 / 0.36` | 374×130 |
| `RankList` | `0.55 / 0.12` | 40 % × 136 px |
| `BinaryBlocks` | `0.52 / 0.50` | 44 % × 42 % |

**`Odometer`** — vier Ziffernkacheln `Digit1…4`, je 86×118, Abstand 96 px,
Hintergrund `#041005` bei Transparenz `0.10`, Stroke 2.2 `#2E6B4A`, Ecke 12 px,
darin ein `Value`-Label mit **84 px** Schriftgröße in `#78FFAA`.
Darunter `Pedestal`, 36 px breiter als der Block, Transparenz `0.35`, Ecke 13 px.
Animiert von `KenopsiaClient.rollDigit()`.

**`RankList`** — vier Zeilen à 28 px. Pro Zeile: **zwei** Häkchen (`Check1`,
`Check2`, je 16×16 mit Stroke 1.6 `#8CE8AE`), `RankLabel`, `ScoreLabel` (`"0000"`),
`NameLabel`. Alles 20 px.

**`BinaryBlocks`** — Header `"INTERACTIVE BLOCK PROCESS FW"` (13 px) plus
18 Labels `Bin1_1…Bin3_6`, drei Spalten à sechs Zeilen. Reine Deko: laufende
Binärkolonnen.

### `Status` — die Terminalzeilen

Sieben Zeilen `TypeLine1…7`, 13 px, `#8CE8AE`, linksbündig ab `x = 46 px`, im
Abstand von 18 px, alle leer und versteckt. `KenopsiaClient.showStatus()` tippt sie
zeilenweise (eine Zeile pro 0,25 s).

### `Briefing`

`Title "BRIEFING"` (46 px, `x = 0.16 / y = 0.22`), `BriefList` mit fünf Zeilen à
24 px im Abstand 28 px (20 px Schrift, alle leer und versteckt),
`PageLabel "Page 1/2"`, `NavBar` mit `ArrowL ◀`, `ArrowR ▶`, `Marker ▼`, `Track` und
`Gauge` mit fünf Segmenten (`Seg1…3` sichtbar, `Seg4`/`Seg5` versteckt).

### `RoundCard`

Schwarz, nur zwei Zeilen bei `y = 0.38`:
`Title "Round 1/3"` in **58 px** und `Verbs "MEMORIZE. INSPECT. ALIGN._"` in 20 px.

> Der gespeicherte Verbs-Text ist ein Relikt aus dem alten RECALL-Entwurf; zur
> Laufzeit setzt `MachineFlow` die Tagline des laufenden Trials.

---

## Overlays

| Element | Z | Beschreibung |
|---|---:|---|
| `JoinCover` | 90 | Vollflächig `#020402`, Zeile `"connecting subjects ..."` (18 px). Deckt den Beitritt ab. |
| `CountText` | 80 | Ein Label, 300×160, **100 px** Schrift, `#78FFAA` — die 3‑2‑1‑Zählung |
| `Fader` | 70 | Vollflächig schwarz, nur zum Überblenden |
| `Announce` | 60 | Vollflächig schwarz + `Line` (34 px, `#78FFAA`, 90 % breit). Ein **leerer** Announce-Text rendert vollflächig schwarz — so decken Trials Teleports ab. |
| `HitMark` | 67 | `"HIT"`, 30 px, mit schwarzem Stroke — der Trefferindikator des Snipers |

### `Scope` — das Zielfernrohr (Z 65)

`Mask` ist ein quadratisches Bild (`rbxassetid://84803293920133`,
`UIAspectRatioConstraint` = 1.000) mit vier schwarzen Blenden `BarL/R/T/B`, die je
4000 px über den Rand hinausragen — dadurch bleibt außerhalb des runden Ausschnitts
alles schwarz, egal welches Seitenverhältnis der Bildschirm hat.
`ZoomLabel` zeigt `"x2"` (24 px) bei `y = 0.87`.

### `HipCross` — Hüftfeuer-Fadenkreuz (Z 66)

45×42, aus fünf Frames in `#EBF5EE`, jeder mit 1 px schwarzem Stroke:
`Dot` 4×4 zentriert, `T`/`B` 2×9 bei ∓14 px, `L`/`R` 9×2 bei ∓14 px.

### `SettingsPanel` (Z 82)

430×330, zentriert, schwarz, Stroke 2 `#78FFAA`.
`Serration` mit 40 Zacken à 5 px. `Title "SETTINGS"` 28 px.
Drei Zeilen à 40 px im Abstand 54 px:

| Zeile | Beschriftung |
|---|---|
| `Row_UISOUND` | `UI SOUND` |
| `Row_MUSIC` | `MUSIC` |
| `Row_REDUCEFLICKER` | `REDUCE FLICKER` |

Jede Zeile: Text links (21 px, `#8CE8AE`), rechts ein `Check` 30×30 (schwarz, Stroke 2,
`Fill` mit 6 px Rand), darüber ein unsichtbarer `Hit`-TextButton über die ganze Zeile.
Unten `Btn_CLOSE` 150×42.

### `TouchControls` (Z 68)

Alle Buttons rechts unten verankert, halbtransparentes Schwarz (`0.35`), rund
(`UICorner` 0.5).

| Button | Größe | Position (Anker unten rechts) | Stroke | sichtbar |
|---|---|---|---|---|
| `Btn_FIRE` | 104×104 | `-24 / -24` | 3 px **`#FF1818`** | ja |
| `Btn_PUNCH` | 104×104 | `-24 / -24` | 3 px **`#FF1818`** | nein |
| `Btn_SCOPE` | 76×76 | `-38 / -148` | 2 px `#78FFAA` | ja |
| `Btn_CROUCH` | 76×76 | `-38 / -148` | 2 px `#78FFAA` | nein |
| `Btn_SCAN` | 76×76 | `-38 / -148` | 2 px `#78FFAA` | nein |
| `Btn_EAT` | 76×76 | `-38 / -148` | 2 px `#78FFAA` | nein |
| `Btn_ZOOM` | 64×64 | `-140 / -136` | 2 px `#78FFAA` | nein |

`Btn_FIRE` und `Btn_PUNCH` haben zusätzlich `InnerRing` (Stroke 1, Transparenz 0.35)
und `Ticks` — vier 2×10-Striche an den vier Himmelsrichtungen.

> Die sechs Buttons `FIRE / SCOPE / ZOOM / PUNCH / CROUCH / SCAN / EAT` sind **fest
> pro Alt-Trial verdrahtet** und teilen sich zwei Ankerpositionen: `FIRE`/`PUNCH`
> liegen exakt übereinander, ebenso `SCOPE`/`CROUCH`/`SCAN`/`EAT`. Jedes neue Trial
> müsste hier einen weiteren Button anlegen — genau das nimmt `TrialClientKit`s
> `kit.pad()` ab, das seine Buttons zur Laufzeit baut.

---

## Layout-Anpassung durch `MachineLayout`

Die Screens wurden gegen ein **~710 px hohes Fenster** mit Pixel-Offsets gezeichnet.
`MachineLayout` skaliert das Koordinatensystem jedes Screens nach Plattform:

| Plattform | Behandlung |
|---|---|
| `Mobile` | Inhalt herunterskaliert, Touch-Controls an |
| `Desktop` | nahe am Originalmaßstab, Touch-Controls folgen der Touch-Verfügbarkeit |
| `Console` | 10-Fuß-Vergrößerung, Gamepad-Fokus, Touch-Controls aus |

Das Attribut `Platform` am Spieler hält das Ergebnis von `detectPlatform()`.
