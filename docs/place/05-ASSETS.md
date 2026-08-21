# 05 — Alle Assets

Jede Asset-ID, die im Place referenziert wird: Meshes, Texturen, Sounds,
Animationen, Rigs.

---

## 1. Audio — `SoundService.KenopsiaAudio`

### 1.1 Musik (`Music.Trials`)

| Name | Asset-ID | Lautstärke | Loop |
|---|---|---:|---|
| `birdhunt` | `rbxassetid://71143122243344` | 0.24 | ja |
| `minefield` | `rbxassetid://132499516846518` | 0.45 | ja |

**`canteen` fehlt** — das Minispiel läuft ohne Musik.
Der Ordner `Ambience` existiert und ist **leer**.

### 1.2 Effekte (`SFX`) — Einzelklänge

| Name | Asset-ID | Lautstärke |
|---|---|---:|
| `Click` | `rbxassetid://71275573444924` | 0.45 |
| `Hover` | `rbxassetid://71275573444924` | 0.16 |
| `ClickAlt` | `rbxassetid://132164304600477` | 0.45 |
| `Confirm` | `rbxassetid://130292722664147` | 0.60 |
| `Reject` | `rbxassetid://114448879961050` | 0.70 |
| `Warning` | `rbxassetid://93861370808858` | 0.65 |
| `ImpactBody` | `rbxassetid://83335185987012` | 0.90 |
| `Count5` | `rbxassetid://117149096126658` | 0.75 |
| `Count4` | `rbxassetid://88984010858075` | 0.75 |
| `Count3` | `rbxassetid://125929365204512` | 0.75 |
| `Count2` | `rbxassetid://90490572986710` | 0.75 |
| `Count1` | `rbxassetid://132909621965246` | 0.75 |

`Click` und `Hover` teilen dieselbe ID und unterscheiden sich nur in der Lautstärke.

### 1.3 Effekte — Gruppen (Zufallsauswahl)

| Gruppe | Kinder | Asset-IDs | Lautstärke |
|---|---|---|---:|
| `SniperFire` | `Primary` | `118803023612410` | 1.45 |
| `BulletRicochet` | `Primary` | `83668417079973` | 1.10 |
| `SniperReload` | `Primary` | `83110281478101` | 1.70 |
| `Clicks` | `Click1…5` | `136898832673181`, `136745293101522`, `115728252091834`, `111557351602976`, `132683279963887` | 0.60 |
| `Submits` | `Submit1…3` | `79171960825561`, `111991322032307`, `109725832591895` | 0.60 |
| `MineExplosions` | `Explode1…4` | `86475991650982`, `76737678985387`, `71471343684752`, `75789945781051` | 0.90 |
| `Blood` | `Blood1…2` | `127560368697616`, `86853838840785` | 0.85 |

**Gesamt: 2 Musiktitel, 31 Sound-Instanzen.**
`kit.sfx(name)` ist bei einem unbekannten Namen stumm und wirft nie.

---

## 2. Animationen

### 2.1 Publizierte IDs (`Shared.Config.AnimationIds`)

> Das ist der **einzige** Ort im Projekt, an dem eine Animations-Asset-ID steht.
> `0` bedeutet "noch nicht publiziert": `resolve()` gibt `nil` zurück und jeder
> Aufrufer überspringt den Clip. Keine Animation ist nie ein Fehler und nie ein Yield.

#### `AnimationIds.Player` — Rig `PS1Player` (20 Bones, 30 fps, Loops am Ort)

| Clip | ID | Länge | Priorität | Bemerkung |
|---|---|---|---|---|
| `Idle` | `125600962447767` | 2.00 s | Idle | |
| `Walk` | `123033497454830` | 1.00 s | Movement | natürlich 4,5 Studs/s bei Skalierung 1 |
| `Run` | `95031726336950` | 0.67 s | Movement | natürlich 10,95 Studs/s |
| `Crouch` | `125766316179596` | 2.00 s | Movement | wird als "sneak" benutzt |
| `Push` | `70937503697406` | 1.33 s | Action | natürlich 3,15 Studs/s |
| `Death` | `114200780379540` | — | Action | die Table-Manners-Hinrichtung |
| `Eat` | **`0`** | — | — | **kein authored Ess-Clip** — `CanteenDiner` fällt auf `Push` zurück, zeitskaliert auf das Essfenster |

`AnimationIds.PlayerSpeeds = { Walk = 4.5, Run = 10.95, Push = 3.15 }` — für `AdjustSpeed`.

#### `AnimationIds.Boss` — Rig `CanteenBoss` (19 Bones)

| Clip | ID | Bemerkung |
|---|---|---|
| `Reading` | `78730370216852` | identisch mit `LookUp` — der Boss hält seine erste Lesepose bei Geschwindigkeit 0 |
| `Idle` | `95540888860028` | |
| `LookUp` | `78730370216852` | |
| `LookDown` | `76111131902834` | |
| `Shoot` | `87302586462797` | |
| `Death` | **`0`** | nicht publiziert |

#### `AnimationIds.Textures`

| Name | ID |
|---|---|
| `PlayerNeutral` | `136734973177857` |
| `BossNeutral` | `130641113899237` |
| `PlayerBlink` | **`0`** |
| `PlayerHappy` | **`0`** |
| `PlayerHurt` | **`0`** |
| `BossAngry` | **`0`** |

**Sechs IDs stehen noch auf `0`:** `Player.Eat`, `Boss.Death`, `PlayerBlink`,
`PlayerHappy`, `PlayerHurt`, `BossAngry`.

### 2.2 Das Berechtigungsproblem — wörtlich aus dem Modul

> **OWNERSHIP.** Jede ID oben wurde von Nutzer `4840146924` (iLoveKilIs) publiziert,
> aber Place `110672791536316` gehört **Gruppe `832614570`**. Roblox weigert sich,
> eine Animation abzuspielen, für die die Experience keine Berechtigung hat —
> `LoadAnimation` gelingt, die Spur spielt, `Length` bleibt `0` und der Rig bewegt
> sich nie; die Ausgabe zeigt *"The experience doesn't have access permission to use
> asset id N. Click to share access"*. Behebung: diesen Link einmal pro ID anklicken
> (oder Creator Hub → Development Items → Animations → Permissions → diese Experience
> hinzufügen). **Nichts im Code kann das gewähren.**

**Der Studio-Notbehelf:** `AnimationIds.warmup()` prüft auf einem Server einmal beim
Boot eine einzige publizierte ID an einem nackten `Animator`. Löst sie sich innerhalb
von 3 s nicht auf, setzt es `publishedPlayable = false`, und jedes spätere `load()`
registriert stattdessen die authored `KeyframeSequence`s aus
`ServerStorage.RBX_ANIMSAVES` über `KeyframeSequenceProvider:RegisterKeyframeSequence`
— **das funktioniert nur im Studio**. Auf einem Live-Server bleiben die Rigs
bewegungslos, bis die Freigabe erteilt ist.

### 2.3 `AnimationIds.StudioSequences` — die Fallback-Zuordnung

| Gruppe | Clip | Halter in `RBX_ANIMSAVES` | Sequenzname | min. Keyframes |
|---|---|---|---|---:|
| Player | `Idle` | `PS1Player_AllAnims` | `Idle` | — |
| Player | `Walk` | `PS1Player_AllAnims` | `Walk` | — |
| Player | `Run` | `PS1Player_AllAnims` | `Run` | — |
| Player | `Crouch` | `PS1Player_AllAnims` | `Crouch` | — |
| Player | `Push` | `PS1Player_AllAnims` | `Push` | — |
| Player | `Death` | `Anim_Death` | `Death of Player` | — |
| Boss | `Idle` | `Anim_Idle` | `Idle` | **100** |
| Boss | `LookUp` | `Anim_LookUp` | `LookingUp` | — |
| Boss | `Reading` | `Anim_LookUp` | `LookingUp` | — |
| Boss | `LookDown` | `Anim_LookDown` | `LookDown` | — |
| Boss | `Shoot` | `Anim_Shoot` | `Shoot` | — |
| Boss | `Death` | `Anim_Death` | `Death of Player` | — |

> Zwei `ObjectValue` heißen `Anim_Idle`. Die Mindest-Keyframezahl `100` unterscheidet
> sie: der Boss-Idle hat 121 Keyframes, der Spieler-Idle 61.

### 2.4 `ServerStorage.RBX_ANIMSAVES` — 29 785 Instanzen

| Halter | Sequenz | Keyframes | Loop | Priorität |
|---|---|---:|---|---|
| `PS1Player_AllAnims` | `Idle` | 61 | ja | Action |
| | `Walk` | 31 | ja | Action |
| | `Run` | 21 | ja | Action |
| | `Push` | 41 | ja | Action |
| | `Crouch` | 61 | ja | Action |
| `Anim_Idle` (Spieler) | `Scene`, `Idle` | 61 | ja | Action |
| `Anim_Walk` | `Scene`, `Walk` | 31 | ja | Action |
| `Anim_Run` | `Scene`, `Run` | 21 | ja | Action |
| `Anim_Push` | `Scene`, `Push` | 41 | ja | Action |
| `Anim_Crouch` | `Scene`, `Crouch` | 61 | ja | Action |
| `Anim_Idle` (Boss) | `Scene`, `Idle` | 121 | ja | Action |
| `Anim_LookUp` | `Scene`, `LookingUp` | 45 | ja | Action |
| `Anim_LookDown` | `Scene`, `LookDown` | 20 | ja | Action |
| `Anim_Shoot` | `Scene`, `Shoot` | 50 | ja | Action |
| `Anim_Reading` | `Scene` | 121 | ja | Action |
| `Anim_Death` | `Scene`, `Death of Player` | 60 | ja | Action |
| `Player_Rig_scaleUnits` | *(leer)* | — | — | — |

`Anim_Reading` hat **keine** benannte zweite Sequenz — nur `Scene`. Deshalb bildet
`StudioSequences.Boss.Reading` auf `Anim_LookUp` / `LookingUp` ab.

Zusammensetzung der 29 785 Instanzen: 28 377 `Pose`, 1 358 `Keyframe`,
26 `KeyframeSequence`, Rest `ObjectValue`/Ordner.

---

## 3. Rigs

### 3.1 `ServerStorage.KenopsiaAssets.Rigs` — die Spiel-Rigs

Beide `RenderFidelity = Precise`.

#### `CanteenBoss` (30 Nachkommen)

| Teil | Mesh-ID | Größe |
|---|---|---|
| `Boss_Body` | `120564744640037` | 9.5 × 7.4 × 2.4 |
| `Boss_Head` | `140393163764203` | 1.3 × 1.3 × 1.3 |
| `Boss_Newspaper` | `103717996765526` | 2.6 × 1.7 × 0.5 |
| `Boss_Pistol` | `130680735362056` | 0.2 × 0.9 × 1.1 |
| `RootPart` | *(Part)* | 2 × 2 × 1, **Anchored** |

Plus `AnimationController` und 19 Bones.

#### `PS1Player` (103 Nachkommen)

| Teil | Mesh-ID | Größe |
|---|---|---|
| `Player_Body` | `121596309152455` | 7.7 × 6.8 × 1.7 |
| `Player_Bag` | `90439124030871` | 0.4 × 0.7 × 0.7 |
| `Player_Head` | `89019499333728` | 1.2 × 1.5 × 1.7 |
| `RootPart` | *(Part)* | 2 × 2 × 1 |

Plus `AnimationController`, `InitialPoses` (72 Nachkommen — die Bind-Pose, aus der
`CanteenDiner.sit()` die Sitzhaltung als Offset berechnet) und
`AnimSaves → ServerStorage.RBX_ANIMSAVES.Player_Rig_scaleUnits`.

### 3.2 `ServerStorage.KenopsiaAuthoring.MasterRigs`

`Boss_Master` (102 Nachkommen) und `Player_Master` (103) — identische Mesh-IDs wie
oben, `RenderFidelity = Precise`. Die Referenzkopien.

> `RenderFidelity` ist zur Laufzeit **nicht schreibbar**. Die Rigs müssen deshalb
> schon in der Vorlage auf `Precise` stehen.

### 3.3 `ServerStorage.KenopsiaAuthoring.AnimationSources` — 1 746 Nachkommen

Ein Modell pro Clip, jeweils mit eigener `InitialPoses`-Kopie und einem
`AnimSaves`-Verweis. **Jede Quelle hat eigene Mesh-IDs** —
`RenderFidelity = Automatic`:

| Quelle | `AnimSaves` → | Body-Mesh |
|---|---|---|
| `Boss_Idle_Source` | `Anim_Idle` | `83965485556491` |
| `Boss_LookUp_Source` | `Anim_LookUp` | `92977338608463` |
| `Boss_LookDown_Source` | `Anim_LookDown` | `74956189104339` |
| `Boss_Shoot_Source` | `Anim_Shoot` | `88279510377810` |
| `Boss_Reading_Source` | `Anim_Reading` | `107464707084144` |
| `Boss_Death_Source` | `Anim_Death` | `104919265054364` |
| `Player_Idle_Source` | `Anim_Idle` | `121596309152455` |
| `Player_Walk_Source` | `Anim_Walk` | `121596309152455` |
| `Player_Run_Source` | `Anim_Run` | `121596309152455` |
| `Player_Crouch_Source` | `Anim_Crouch` | `121596309152455` |
| `Player_Push_Source` | `Anim_Push` | `121596309152455` |

Die Boss-Quellen tragen je eigene Kopf-, Zeitungs- und Pistolen-Meshes; die
Player-Quellen teilen alle dieselben drei Meshes wie das Master-Rig.

**Mixamo-Archive** (je 198 Nachkommen, 195 `InitialPoses`, `AnimSaves → nil`):
`Mixamo_SneakWalk_Archive`, `Mixamo_InjuredWalk_Archive`, `Mixamo_ZombieCrawl_Archive`.
Tote Altlasten aus der abgeschafften Mixamo-Animationsschicht.

---

## 4. Prozedurale Requisiten

### `ServerStorage.KenopsiaAssets.Props.Minefield`

| Modell | Nachkommen | Rolle |
|---|---:|---|
| `MF_Mine` | 8 | die Mine |
| `MF_Crater` | 9 | der Krater nach der Explosion |
| `MF_SonarRing` | 18 | der Sonarring |
| `MF_Hunter_Shredder` | 34 | der Compactor |

Der Ordner `Props.CanteenProtocol` existiert **nicht** — deshalb baut `CanteenProps`
Erbsen, Gabeln und Observer prozedural. Ein Modell namens `CP_Observer`, `CP_Fork`
oder `CP_Pea` dort abzulegen ersetzt den Bau ohne Codeänderung.

### `ReplicatedStorage.KenopsiaAssets`

| Objekt | Nachkommen | Rolle |
|---|---:|---|
| `SniperRifle` | 21 | Viewmodel des Snipers, komplett aus Parts: `Grip`, `Stock`, `ButtPlate`, `CheekRest`, `Receiver`, `Forestock`, `Barrel`, `Muzzle`, `MountF/R`, `ScopeTube`, `ScopeBellF/R`, `LensF/R`, `BoltStub`, `BoltKnob`, `Magazine`, `Trigger`, `TriggerGuard`, `PhosphorDot` |
| `MF_SonarRing` | 18 | Client-Kopie: `Center`, `Seg0…15`, `PivotRoot` |
| `Effects.Blood.BloodEffect` | — | siehe [`06-CONTRACTS.md`](06-CONTRACTS.md) |

---

## 5. Textur- und Mesh-IDs der Welt

### 5.1 Oberfläche

| Verwendung | Asset-ID |
|---|---|
| Grunge-Overlay (alle Screens) | `rbxassetid://89538183732053` |
| Zielfernrohr-Maske | `rbxassetid://84803293920133` |

### 5.2 `CanteenProtocol`

| Prop | Mesh | Textur |
|---|---|---|
| `Canteen_table_large_3` | `128871075250000` | `102434050747418` |
| `Canteen_chair_wooden_1` | `138424378326139` | `102434050747418` |
| `Canteen_Mesh_Table_Rectangle_01` | `73149669863645` | `106313060356155` |
| `Canteen_Mesh_Drinks_01` | `82361056423934` | `106313060356155` |
| `Canteen_Mesh_Packaging_01` | `73409356894969` | `106313060356155` |
| `Canteen_Mesh_Cups_01` | `126617201819602` | `106313060356155` |
| `Canteen_Mesh_Trolley_01` | `104137092438114` | `106313060356155` |
| `Canteen_Mesh_Trolley_04` | `96185090622105` | `106313060356155` |
| `Canteen_canned_food_4` | `99873556374348` | `82114296687896` |
| `Canteen_canned_food_3` | `118555128679631` | `82114296687896` + `SurfaceAppearance` `110840132829419` |
| `Canteen_mre_1` | `98945829097238` | `113762393139469` |
| `Canteen_trash_1` | `129988180708024` | `119271055491932` |
| `Canteen_metal_shelf_1` | `112467140028409` | `116616006221068` |

### 5.3 `Bird Hunting`

| Prop | Mesh | Textur |
|---|---|---|
| `Stone 1` (`stone_3_mesh`) | `89253069969423` | `115786459061333` |
| `Tree 1` (`tree_9`) | `136079292281033` | `74133227102947` |
| `Tree 2` (`tree_8`) | `84841862240408` | `74133227102947` |
| `Tree 3` (`tree_9`) | `124050815121405` | `109803514628108` |
| `Tree Stump` | `96601260656244` / `132965697253949` | `90388194954702` / `126652979588293` |
| `Tree LOg` | `121486821117962` / `124076633606005` | `89462528308995` / `118251789271638` |
| `Wall block` (`barricade_a_1`) | `134699673737845` | `125366711647259` |
| `fence_e_2` (`default`) | `138390177442749` | `137205326240424` |
| `metal_shelf` | `126979733278569` / `79451772242193` | `98099973274478` / `SurfaceAppearance` `121035210748431` |
| `Metal_crate` (`metal_crate_3`) | `99373570295815` | `122145178277948` |
| `Wooden_pallet` (`wood_pallet_2`) | `96775065983464` | `122729198033905` |
| `Wall with metal` (`barricade_b_4/42/43`) | `93869023300514`, `84185801445861`, `96285473732569` | `83918350839892`, `102929672789691`, `99835410367999` |
| `concrete block hiding` | `71136061855563` / `86887309734225` | `135161890568938` / `93045031305581` |
| `Pillar` | `102225771718619` | `86116868270796` |
| `Wall 1` (`wall_rg_1/12`) | `75701965096638` / `133518834774190` | `116790276902060` / `106701748291066` |
| `Wall with Stacheln` | `134302493486275`, `129500562564041`, `101107823957214` | `86116868270796`, `120715147610918`, `137205326240424` |
| `bench` (`bench_mx_1_1`) | `122600063835932` | `136560808287626` |
| `Tower` (`concrete_block_mx_1`) | `75863220505814` | *(keine)* |
| `pipe` (`pipe_mx_2/22`) | `112426509642721` / `123402206624277` | `86873234426604` |
| `Gravel` (`gravel_pile_hr_1`) | `71505386977845` | `84631410071178` |
| `brick max` (`brick_mx_2_0`) | `75276752702034` | `109182664261705` |
| `door hr` (`door_hr_13`) | `108384451890886` | `89563709584654` |
| `Water Tower` | `124091450224093`, `125245332606013`, `77500671902287`, `134571240138369`, `94813448003190` | `121161080530172`, `86756434629700`, `100724322440427`, `105701950772221`, `127612751828132` |
| `Storage Tank` | `122064858375626` / `132196070181082` | `94559329929220` / `96802598335253` |
| `wires` (`wires_holder_hr_large_1`) | `93970849640160` | `131184601353717` |
| `floor_ceiling_hr_2_hole` | `111872078560228` | *(keine)* |

### 5.4 `Dead Zone`

| Prop | Mesh | Textur |
|---|---|---|
| `fence_e_2_Node` | `137793807551318`, `117664552909472`, `117088324723863` | `130508216971392`, `133183271346242`, `138877202114055` |
| `fence_e_pillar_1_Node` | `111431806186508` / `73419712668811` | `79669173388948` / `103285742087007` |
| `fence_e_pillar_1_corner_Node` | `121960282541716` / `94257795300148` | `71357010760083` / `130494134275606` |
| `tree_stump_1` | `81208393790056` / `113088402568817` | `87331348296243` / `73206043398448` |
| `water_tower_hm_1_Node` | `86986331967829`, `87913961864102`, `71350798564696`, `102654561213473`, `122855828036491` | `120172127107072`, `70418612159947`, `75960296378916`, `88209602419504`, `135950912164712` |
| `Van` | `128725286453960`, `115679905711904` + 4 Räder (`112711303492171`, `95787782646584`, `100228666488845`, `71676370704795`) | `96637947485228`, `121957441624930` |
| `scanner_1_Node` / `Scanner for Scanning Mines` | `119561741238857` | `SurfaceAppearance` `116442033008616` |
| `military_radio_1_Node` | `79151817618630` + Knöpfe `111427785770617`, `112889388533138`, `95554791866877`, `119741962761408`, `123306856594815` | `97181037850201`, `115258846959316` |
| `generator_1_Node` | `89210898499864` / `93839031319470` | `75303872161617` / `133296799861646` |
| `barricade_a_2_` | `113063465283329` | `128383841950004` |
| `debris_bricks_mx_1_Node` | `97907394688532` | `92848918019816` |
| `stone_1` (`stone_5_mesh`) | `104802280116239` | `78903440441303` |
| `jerrycan_mx_1_Node` | `93640874391770` | `120986322263103` |
| `sign_1_Node` | `99039260463373` | `112854464098099` |
| `scrap_metal_mx_1_Node` | `136808159167198` | `71025285299964` |
| `cement_bags_mp_1_pallet_1_Node` | `98332890691019` / `88354506684211` ×5 | `87175461577215` / `106603599155918` |
| `Scene` (Lagerhalle A) | `114580062519078`, `82139670691499`, `134410577016015`, `110550252433577`, `115956029423300`, `75189517731500`, `115875304998186` … | `78900791212846`, `118563272190409`, `101293800937710`, `79809317290433`, `131431695095249`, `139033833754305` … |
| `Scene` (Lagerhalle B) | `90826399850982`, `125367131299251`, `98798202826855`, `77193992561767`, `137786349155124`, `135638285059785`, `83995940814978` … | `120172127107072`, `113744907884599`, `111764465664163`, `70418612159947`, `95461307433280`, `76241712040018` … |
| `Scene` (Schuppen) | `97163608585326`, `88907710856476`, `104996049055836`, `72598109886871`, `129840507362905` | `131169701169494`, `134308367834406`, `132723238992180`, `106380326588097`, `103074211383317` |

### 5.5 Lose Objekte

| Objekt | Mesh | Textur |
|---|---|---|
| `SniperRifle_PSX` | `95513591480496` | `102060729071869` |
| `saw_blade` (`saw_blade_1`) | `107263014734099` | `92495691915287` |
| `gear_mx_1` (`default`) | `100526442297699` | `76708485220493` |

---

## 6. Hinweis zum PS1-Look

Roblox hat **keinen Nearest-Neighbour-Filter für 3D-Texturen** — `ResampleMode.Pixelated`
gibt es nur für GUI-Bilder. Der PS1-Look der Meshes beruht deshalb darauf, dass die
Texturatlanten bereits **nearest-hochskaliert auf 1024 px** hochgeladen wurden. Wer
eine Textur neu exportiert, muss diesen Schritt wiederholen, sonst wird sie im Spiel
weichgezeichnet.

Alle Mesh-Props laufen mit `RenderFidelity = Automatic`; nur die Rigs stehen auf
`Precise`.
