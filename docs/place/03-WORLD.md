# 03 — Die Welt (Workspace)

1 793 Instanzen, Tiefe 6, 10 direkte Kinder.
Alle Positionen in Studs, Format `X,Y,Z`.

## Übersicht der zehn Workspace-Kinder

| Name | Klasse | Nachkommen | Zweck |
|---|---|---:|---|
| `CanteenProtocol` | `Folder` | 472 | Arena Trial 3 |
| `Dead Zone` | `Folder` | 711 | Arena Trial 2 |
| `Bird Hunting` | `Folder` | 593 | Arena Trial 1 |
| `Baseplate` | `Part` | 1 | 2048×16×2048 bei `0,-8,0` |
| `Terrain` | `Terrain` | 0 | Region 2044³, ungenutzt |
| `Camera` | `Camera` | 0 | Editor-Kamera |
| `SniperRifle_PSX` | `Model` | 1 | **loses Prop** bei `-284.6,9.0,-589.6` |
| `bench` | `Model` | 0 | **loses, leeres Modell** |
| `saw_blade` | `Model` | 2 | **loses Prop** bei `16.0,-55.2,-114.4` (unter der Baseplate) |
| `gear_mx_1` | `Model` | 1 | **loses Prop** bei `16.0,-55.1,-114.4` (unter der Baseplate) |

Es gibt **keinen** Ordner `KenopsiaArenas` — den legt erst `TrialKit` an, das im
Place nicht existiert.

### Räumliche Aufteilung

| Arena | Zentrum ca. | Grundfläche |
|---|---|---|
| `Bird Hunting` | `5, 1, 580` | 330 × 360 (Wände), Spielfeld ~80 × 317 |
| `CanteenProtocol` | `-97, 16, -7` | 88 × 81, geschlossener Raum mit Decke |
| `Dead Zone` | `-165, 1, -1720` | 45 × 375 Korridor, Umgebung ~330 × 380 |

Die drei liegen weit auseinander — der Abstand `Bird Hunting` ↔ `Dead Zone` beträgt
über 2 300 Studs auf Z. Bei `FogEnd = 480` sieht man von keiner Arena in eine andere.
Die geplanten zwölf neuen Arenen (`MP-05 §A`) liegen bei `X = 1400…2400`,
`Z = -900…900` — also **außerhalb** der Baseplate, deren Rand bei ±1024 liegt.

---

## 1. `CanteenProtocol` — 472 Nachkommen

### 1.1 `Rig` — die Marker (34 Nachkommen)

Alles Würfel von 0,6 Studs, `Anchored`, `CanCollide = false`, unsichtbar im Spiel.
Diese Marker sind der **Vertrag** zwischen dem von Hand gebauten Raum und
`CanteenProtocol.validateArena()`. Gebaut von `tools/build-canteen-arena.luau`.

#### `Seats` — Sitzplätze

| Marker | Position | Attribute |
|---|---|---|
| `P1` | `-98.3, 12.3, -21.3` | `SeatIndex=1` `DinerLift=0` `DinerScale=1` `DinerSeated=true` |
| `P2` | `-82.3, 12.3, -21.3` | `SeatIndex=2` `DinerLift=0` `DinerScale=1` `DinerSeated=true` |
| `P3` | `-98.3, 12.3, 9.7` | `SeatIndex=3` `DinerLift=0` `DinerScale=1` `DinerSeated=true` |
| `P4` | `-82.3, 12.3, 9.7` | `SeatIndex=4` `DinerLift=0` `DinerScale=1` `DinerSeated=true` |

> `DinerScale`, `DinerLift` und `DinerSeated` sind **live justierbare Attribute** —
> `CanteenDiner` liest sie beim Spawn. Man kann die Figuren im Studio verschieben und
> skalieren, ohne Code anzufassen.

#### `PlateAnchors` — Teller

| Marker | Position | Attribut |
|---|---|---|
| `P1` | `-98.6, 13.6, -11.4` | `SeatIndex=1` |
| `P2` | `-82.8, 13.6, -11.4` | `SeatIndex=2` |
| `P3` | `-98.6, 13.6, 0.4` | `SeatIndex=3` |
| `P4` | `-82.8, 13.6, -0.0` | `SeatIndex=4` |

#### `ForkAnchors` — Gabeln

| Marker | Position | Attribut |
|---|---|---|
| `P1` | `-98.6, 15.2, -13.2` | `SeatIndex=1` |
| `P2` | `-82.7, 15.2, -13.2` | `SeatIndex=2` |
| `P3` | `-98.6, 15.2, 2.1` | `SeatIndex=3` |
| `P4` | `-82.7, 15.2, 1.7` | `SeatIndex=4` |

#### `MouthTargets` — Mundpositionen

| Marker | Position | Attribut |
|---|---|---|
| `P1` | `-98.4, 14.3, -20.7` | `SeatIndex=1` |
| `P2` | `-82.4, 14.3, -20.7` | `SeatIndex=2` |
| `P3` | `-98.4, 14.3, 9.1` | `SeatIndex=3` |
| `P4` | `-82.4, 14.3, 9.1` | `SeatIndex=4` |

#### `PlayerCameras` — Kamera pro Sitzplatz

| Marker | Position | Attribut |
|---|---|---|
| `P1` | `-98.1, 18.8, -28.7` | `SeatIndex=1` |
| `P2` | `-82.0, 18.8, -28.7` | `SeatIndex=2` |
| `P3` | `-98.1, 18.8, 17.1` | `SeatIndex=3` |
| `P4` | `-82.0, 18.8, 17.1` | `SeatIndex=4` |

#### `ExecutionMuzzles` — Mündungen für die Hinrichtung

| Marker | Position | Attribut |
|---|---|---|
| `P1` | `-98.3, 30.0, -21.3` | `SeatIndex=1` |
| `P2` | `-82.3, 30.0, -21.3` | `SeatIndex=2` |
| `P3` | `-98.3, 30.0, 9.7` | `SeatIndex=3` |
| `P4` | `-82.3, 30.0, 9.7` | `SeatIndex=4` |

Alle vier sitzen exakt 17,7 Studs **über** dem jeweiligen Sitzplatz.

#### Einzelmarker

| Marker | Position | Attribut | Rolle |
|---|---|---|---|
| `ObserverCamera` | `-63.0, 26.0, -5.4` | — | die **eine feste Tischkamera**, blickt in `-X` den Tisch entlang |
| `SpectatorCamera` | `-93.0, 25.3, 20.3` | — | Zuschauerposition |
| `Observer` | `-93.0, 20.3, -5.7` | — | Ruheposition des Observers über dem Tisch |
| `BossSeat` | `-115.8, 12.3, -5.7` | `BossScale=1` | Sitzplatz des Bosses am Kopfende |

### 1.2 Raumhülle

| Part | Position | Größe | Material |
|---|---|---|---|
| `Floor Canteen Protocol` | `-97.2, 0.5, -6.9` | `88 × 1 × 81` | `Concrete` |
| `Ceiling` | `-97.8, 32.7, -6.9` | `90 × 1 × 81` | `Concrete` |
| `Wall` | `-144.4, 16.1, 0.5` | `5.5 × 32.3 × 66.2` | `Concrete` |
| `Wall` | `-98.1, 16.1, -49.9` | `98 × 32.3 × 5` | `Concrete` |
| `Wall` | `-50.2, 16.1, -6.7` | `5.5 × 32.3 × 80.6` | `Concrete` |
| `Wall` | `-97.3, 16.1, 37.3` | `99.7 × 32.3 × 7.4` | `Concrete` |
| `Door Ceilin` | `-144.4, 16.3, -40.0` | `5.5 × 32 × 14.9` | `Concrete` |
| `Camera for Canteen` | `-63.0, 26.0, -5.4` | `1.1 × 1 × 2` | sichtbares Kameragehäuse an der `ObserverCamera` |

### 1.3 Teller-Parts

Acht `Plate`-Parts (`0.2 × 6.1 × 6.1`) an nur **vier** Positionen — jede doppelt:

| Position | Anzahl | Material |
|---|---:|---|
| `-98.6, 13.5, -11.4` | 2 | `Plastic` |
| `-82.8, 13.5, -11.4` | 2 | `Metal` / `Plastic` |
| `-98.6, 13.5, 0.4` | 2 | `Plastic` |
| `-82.8, 13.5, -0.0` | 2 | `Plastic` |

Siehe [`07-FINDINGS.md`](07-FINDINGS.md) F-17.

### 1.4 `FloorLamp_01` … `FloorLamp_08`

Acht identische Lampenmodelle, je 38 Nachkommen:
`Model:6, Part:12, PointLight:3, SurfaceLight:3, UnionOperation:14`
(Unterteile: `Neons` mit `LightUnit_01..03`, `Power plate`, `Frame screw`,
`Neon frame`, `Union`).

Sie stehen an nur **vier** Positionen, jeweils doppelt:

| Position | Lampen |
|---|---|
| `-96.5, 32.6, 22.6` | `FloorLamp_01` + `FloorLamp_02` |
| `-96.5, 32.6, -6.2` | `FloorLamp_04` + `FloorLamp_07` |
| `-96.5, 32.6, -29.8` | `FloorLamp_05` + `FloorLamp_08` |
| `-131.9, 32.6, -6.2` | `FloorLamp_03` + `FloorLamp_06` |

Das sind **24 PointLights und 24 SurfaceLights**, wo 12 und 12 gemeint waren.
Siehe [`07-FINDINGS.md`](07-FINDINGS.md) F-16.

### 1.5 Möbel und Requisiten (Mesh-Props)

| Prop | Anzahl | Positionen |
|---|---:|---|
| `Canteen_table_large_3` | 1 | `-97.0, 0.0, -0.2` |
| `Canteen_Mesh_Table_Rectangle_01` | 1 | `-119.8, 14.0, 6.6` |
| `Canteen_chair_wooden_1` | 6 | 4 an den Sitzplätzen + `-120.6,16.0,-22.4`, `-116.4,1.0,-5.3` |
| `Canteen_canned_food_4` | 12 | verteilt |
| `Canteen_canned_food_3` | 1 | **`0.0, 2.1, 1.0`** — steht am Weltursprung, nicht in der Kantine |
| `Canteen_mre_1` | 8 | u.a. **zweimal** auf `-134.8, 2.0, -38.2` |
| `Canteen_trash_1` | 5 | u.a. **zweimal** auf `-89.1, 1.8, 20.5` |
| `Canteen_Mesh_Drinks_01` | 6 | drei davon bei `Y ≈ -3.8`, also **unter dem Boden** |
| `Canteen_Mesh_Packaging_01` | 7 | alle bei `Y = -0.3`, **unter dem Boden** |
| `Canteen_Mesh_Cups_01` | 4 | auf dem Tisch |
| `Canteen_Mesh_Trolley_01` | 1 | `-136.8, -0.0, -14.2` |
| `Canteen_Mesh_Trolley_04` | 1 | `-111.2, 1.4, -36.8` |
| `Canteen_metal_shelf_1` | 1 | `-135.6, 1.0, 11.8` |

---

## 2. `Dead Zone` — 711 Nachkommen

Ein langer Korridor auf `Z ≈ -1540 … -1925`, Laufrichtung `-Z`.

### 2.1 Spielrelevante Marker und Flächen

| Part | Position | Größe | Rolle |
|---|---|---|---|
| `ShredderSpawnpoint` | `-164.9, 1.9, -1539.0` | `41 × 1 × 2` | Startlinie des Compactors |
| `Cameraplacement` | `-164.9, 16.7, -1637.4` | `41 × 1 × 2` | Kameraposition |
| `Spawnpoint DeadZone` | `-164.9, 1.9, -1637.4` | `41 × 1 × 2` | Spielerstart |
| `MineStartpoint` | `-164.9, 1.9, -1660.8` | `41 × 1 × 2` | Beginn des verminten Bereichs |
| `Exit` | `-164.9, 1.9, -1919.4` | `41 × 1 × 2` | Ziel |
| `Minefield Ground` | `-165.3, 0.9, -1722.9` | `45 × 1 × 375` | das Minenfeld, Material `Ground` |
| `GreenArea` | `-60.8, 1.9, -1722.4` | `164 × 3 × 376` | Randfläche Ost, `Grass` |
| `GreenArea` | `-247.8, 0.9, -1723.4` | `120 × 1 × 374` | Randfläche West, `Grass` |
| `VanWay` | `-168.8, 0.9, -1925.0` | `214 × 1 × 30` | Zufahrt hinter dem Ziel |

Laufstrecke `MineStartpoint → Exit`: **258,6 Studs**.
Compactor-Anlauf `ShredderSpawnpoint → MineStartpoint`: **121,8 Studs**.

Zur Laufzeit legt `Minefield` den Ordner `DZ_Runtime` mit `Compactor` /
`Housing` / `WarnStrip` / `Roller` / `Tooth` an.

### 2.2 Kulisse

| Modell | Anzahl | Bemerkung |
|---|---:|---|
| `fence_e_2_Node` | 61 | Zaunsegmente |
| `fence_e_pillar_1_Node` | 32 | Zaunpfosten |
| `fence_e_pillar_1_corner_Node` | 4 | Ecken bei `Z = -1630.4` |
| `tree_stump_1` | 8 | |
| `Scene` (3 Varianten) | 2 + 2 + 4 | Lagerhallen, Schuppen, Garagentore |
| `water_tower_hm_1_Node` | 2 | |
| `Van` | 1 | `-165.0, 1.2, -1925.0`, am Ziel |
| `jerrycan_mx_1_Node` | 3 | |
| `debris_bricks_mx_1_Node` | 2 | |
| `scanner_1_Node` | 1 | `-213.3, 7.3, -1803.6` |
| `Scanner for Scanning Mines` | 1 | `-78.2, 8.4, -1795.5` |
| `military_radio_1_Node` | 1 | `-190.2, 1.4, -1694.4` |
| `generator_1_Node` | 1 | `-189.0, 8.7, -1844.3` |
| `cement_bags_mp_1_pallet_1_Node` | 1 | |
| `scrap_metal_mx_1_Node`, `sign_1_Node`, `stone_1`, `barricade_a_2_` | 1 / 1 / 1 / 12 | |

---

## 3. `Bird Hunting` — 593 Nachkommen

Ein Laufkorridor von `Z ≈ 429` (Start) bis `Z ≈ 745` (Ziel), Laufrichtung `+Z`,
mit einem Scharfschützen auf einem Turm am Ende.

### 3.1 Spielrelevante Marker

| Part | Position | Größe | Rolle |
|---|---|---|---|
| `Start` | `5.2, 1.5, 429.0` | `42 × 1 × 2` | Startlinie der Runner |
| `Exit` | `5.1, 1.1, 744.6` | `17 × 1 × 4` | Ziel |
| `SniperPost` | `3.4, 41.6, 757.3` | `1 × 1 × 1` | Position des Hunters, 40 Studs hoch |

Laufstrecke `Start → Exit`: **315,6 Studs**. Der Sniper steht 12,7 Studs hinter dem
Ziel und 40 Studs darüber — er sieht die gesamte Bahn.

Zur Laufzeit baut `BirdHunting` den `SniperTurret` mit `Mount` und `Barrel`,
plus gepoolte `SniperBeam`- und `Sparks`-Instanzen.

### 3.2 Umgrenzung

| Part | Position | Größe |
|---|---|---|
| `Wall` | `13.0, 21.0, 374.9` | `330 × 42 × 55` (hinter dem Start) |
| `Wall` | `-87.5, 16.0, 582.9` | `131 × 32 × 359` (West) |
| `Wall` | `105.5, 16.0, 583.4` | `145 × 32 × 360` (Ost) |
| `Wall` | `5.0, 17.0, 757.4` | `78 × 34 × 10` (hinter dem Ziel, trägt den Sniper) |
| `Grass` | `5.8, 0.5, 562.7` | `80 × 1 × 317` (Laufbahn) |
| `Grass` | `-21.2, 0.5, 734.2` / `31.8, 0.5, 734.2` | je `28 × 1 × 26` |

### 3.3 Deckung — was die Runner schützt

| Modell | Anzahl |
|---|---:|
| `Stone 1` | 43 |
| `fence_e_2` | 24 + 1 |
| `Metal_crate` | 16 |
| `Wooden_pallet` | 12 |
| `Tree 1` | 11 |
| `Wall with Stacheln` | 9 |
| `Wall block` | 9 |
| `metal_shelf` | 9 |
| `Wall 1` | 6 |
| `Wall with metal` | 4 |
| `Tree 3` | 4 |
| `Gravel`, `Tree LOg`, `Tower`, `door hr` | je 3 |
| `Pillar`, `Tree Stump`, `bench`, `brick max`, `wires` | je 2 |
| `Water Tower`, `Storage Tank`, `pipe`, `Tree 2`, `concrete block hiding`, `concrete block hidin`, `floor_ceiling_hr_2_hole` | je 1 |

`Tower` ×3 steht bei `Z = 751`, direkt am Ziel: `-20.6`, `5.4`, `31.4` auf X.

> Die Deckung ist vom Nutzer von Hand gebaut — das ist laut Entwurf so gewollt
> ("der Nutzer baut extra Wanddeckung selbst"). Zwei Modelle heißen fast gleich
> (`concrete block hiding` / `concrete block hidin`) und teilen dieselbe
> `RBX_ReimportId` — es ist derselbe Import, zweimal unterschiedlich benannt.

---

## Erhebungsmethode

Rekursiver Lauf über `workspace:GetChildren()`. `Folder` und `BasePart` wurden
vollständig ausgegeben (mit Position, Größe, Material, Farbe, `Anchored`,
`CanCollide` und allen Attributen). `Model`-Instanzen wurden per **Signatur**
zusammengefasst — die sortierte Klassenhistogramm ihrer Nachkommen — sodass jedes
Template genau einmal mit allen Mesh- und Textur-IDs erscheint und die übrigen
Vorkommen nur als Positionsliste. Ohne diese Verdichtung war die Ausgabe 100 KB
reine Schraubengeometrie.
