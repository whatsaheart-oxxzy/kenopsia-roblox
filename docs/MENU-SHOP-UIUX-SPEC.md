# Kenopsia — UI/UX-Design-Spezifikation für Main Menu & Shop (Roblox, PS1-Horror)

> **Provenance:** User-supplied research spec, filed 2026-09-01 by the "ui/ux menu
> specification" session. This is the DESIGN-LANGUAGE document; it was written
> against generic Roblox patterns, **not** against this repo. Before implementing
> anything from it, read `docs/MENU-SHOP-UIUX-INTEGRATION.md`, which maps every
> section onto the code that actually exists (and flags where this spec
> contradicts decisions the user has already locked).

**TL;DR**
- Baue das gesamte Menü als diegetisches "Kalt-CRT-Terminal": eine linke, ein-/ausklappbare Sidebar-Rail (~240px expanded / ~64px collapsed am Desktop, Bottom-Tab-Bar am Mobile), fünf Destinationen (PLAY, SHOP, INVENTORY, sekundär: SETTINGS/SOCIAL), persistente Currency-Pills oben rechts (Credits + Robux), und ein Promo-Code-Widget oben rechts im Shop.
- Die Rarity-Sprache RARE=blau `#4A90E2`, EPIC=lila `#B026FF`, LEGENDARY=gold `#FFD700`, UNIQUE=animierter Regenbogen/Holo-Rahmen entspricht der Muskelgedächtnis-Erwartung der Spieler; Crates nutzen einen CS:GO-artigen horizontalen Spin-Reveal mit farbcodiertem Glow — und MÜSSEN vor dem Kauf eine Odds-Tabelle zeigen (Roblox-Policy).
- Jede Spezifikation ist auf konkrete Roblox-Objekte gemappt (ScreenGui, Frame, UIListLayout, UIGridLayout, ViewportFrame, UIStroke, UICorner, UIScale, TextLabel mit Pixelated-Resampling), sodass Codex/Claude Code sie direkt implementieren können.

---

## Key Findings

1. **Sidebar > Top-Tabs für Shop/Menü-Systeme mit vielen Destinationen.** Eine vertikale Nav-Rail skaliert besser auf viele Sektionen und liest sich am Desktop wie ein Terminal-Menü. Am Mobile ist eine Bottom-Tab-Bar (3–5 primäre Ziele) das reichweitenstärkste Muster; Hamburger nur für Overflow.
2. **Die Rarity-Farbkonvention ist branchenweit erlernt** (blau=Rare, lila=Epic, gold/orange=Legendary). Abweichungen (Destiny 2: lila=Legendary, gold=Exotic) existieren, aber die Fortnite/WoW-Konvention ist der sicherste Default. Der Top-Tier "UNIQUE" muss über Farbe hinaus differenziert werden: animierter Rahmen, Holo-Shift, Glow, Partikel, eigener Sound.
3. **Odds-Disclosure ist bei Robux-Crates Pflicht, nicht optional.** Roblox verlangt klare, zugängliche Wahrscheinlichkeitsangaben vor dem Kauf randomisierter Items. Ethisch sauber: earned-currency-Crates deutlich von Robux-Käufen trennen und Gambling-Framing vermeiden.
4. **Diegetische Terminal-UIs (Signalis, Lethal Company, Buckshot Roulette) sind der stärkste Referenzrahmen** für Kenopsia — kein schwebendes Game-Menü, sondern eine bediente Maschine. In Roblox billig über eine getilte, halbtransparente Scanline-ImageLabel-Overlay + TweenService-Flicker + Pixel-Monospace-Font umsetzbar.
5. **Currency-Pills + animierter Count-up ("Juice") sind Standard** (Clash Royale, Brawl Stars, Fortnite): `[icon][count][+]`, TweenService-Zählanimation und Scale-Punch bei Änderung.

---

## Details

Vorbemerkung zur Roblox-Umsetzung, die für ALLE fünf Bereiche gilt:
- **Root:** ein `ScreenGui` (`IgnoreGuiInset = true`, `ResetOnSpawn = false`), darin ein Vollbild-`Frame` `Root` (`BackgroundColor3 = Color3.fromHex("#020609")`).
- **CRT-Layer (global):** ein `ImageLabel` `ScanlineOverlay` über allem (`ZIndex` hoch, `Active=false`, `ResampleMode = Enum.ResamplerMode.Pixelated`), getiltes Scanline-Bild, `ImageTransparency ~0.85`, per `TweenService` leicht in Transparency oszillierend für Flicker. Optional zweite `ImageLabel`-Ebene mit leichtem RGB-Offset (Chromatic Aberration): drei versetzte, additiv gefärbte Kopien oder ein vorgerendertes Aberrations-Overlay.
- **Typografie:** eine Monospace/Pixel-Schrift (z.B. `Code` oder eine importierte Bitmap-Font via ImageLabel-Glyphen); Standardfarbe Body `#BFE9F5`, Headings `#E8FBFF`, inert/disabled `#4E7C8A`. WHITE `#FFFFFF` ausschließlich für den Selection-Highlight/Streak. `#FF1818` niemals im Menü verwenden (reserviert für Trials).
- **Skalierung:** `UIScale` an einem Menü-Container, per Script auf Basis von `Camera.ViewportSize` gesetzt (kleiner am Phone). Alle Touch-Targets ≥ 44pt.
- **Panel-Optik:** `Frame` mit `UICorner` (klein, ~4px; PS1 ist eher hart/eckig — evtl. gar kein Corner-Radius für harten Terminal-Look), `UIStroke` (1px, Farbe `#4E7C8A`, Transparency ~0.4) und Corner-Bracket-Ecken (`⌐ ¬ ⌐ ¬`) als vier kleine ImageLabels/TextLabels im Signalis-Stil.

### 1. SIDEBAR (Vertikale Nav-Rail)

**Layout & Proportionen.** Desktop expanded ~240px Breite; collapsed Rail ~64px (nur Icons). Jede Nav-Zeile: 56px Höhe, Icon links (~28px), Label rechts. Vertikale Struktur von oben nach unten: Logo/Machine-Sigil (oben, ~96px Höhe), primäre Destinationen (PLAY, SHOP, INVENTORY), Spacer/Flex, sekundäre Ziele unten (SETTINGS, SOCIAL/Codes, Quit).

**Component-Struktur (Roblox).**
- `Frame` `Sidebar` mit `UIListLayout` (`FillDirection = Vertical`, `Padding = 4px`).
- Jede Zeile ein `TextButton` `NavItem` mit Kind-`ImageLabel` (Icon, Pixelated) + Kind-`TextLabel` (Label). `UIPadding` links ~12px.
- Aktiv-Indikator: ein 3px `Frame` `ActiveBar` am linken Rand ODER eine volle Row-Highlight-Fläche.

**States.**
- **Default:** Icon+Label in `#4E7C8A` (inert-cyan), Panel-BG `#06121A`.
- **Hover:** BG-Tint auf `#0A1A24`, Icon/Label auf `#BFE9F5`, optional 1px `UIStroke` cyan; leichtes Scan-/Flicker-Ping.
- **Selected/Active:** WHITE-Selection-Streak — ein weißer 3px `ActiveBar` links + Label auf `#E8FBFF`; ein kurzer horizontaler weißer "Streak"-Sweep (per TweenService X-Position) beim Wechsel. Weiß ist hier bewusst der einzige Ort mit reinem `#FFFFFF`.
- **Disabled/Locked:** Icon+Label `#4E7C8A` @ 50% + Lock-Glyph.

**Interaktion/Animation.** Collapse/Expand über Chevron/Hamburger oben: TweenService auf `Sidebar.Size.X` (240↔64), Labels faden via `TextTransparency`. Im collapsed State Tooltips (kleines Frame) beim Hover mit Label-Text. Tab-Wechsel: alter Content faded/glitcht raus (kurzer Scanline-Roll), neuer faded rein — typewriter-Reveal für Heading.

**Mobile-Adaption.** Bottom-Tab-Bar mit den 3 primären Zielen (PLAY, SHOP, INVENTORY) + optional Overflow-Icon für SETTINGS/SOCIAL. Icons ~28px, Mini-Label darunter, Tab-Höhe ≥ 56px (Touch ≥44pt). Aktiver Tab: weißer Top-Streak + helles Icon. Auf sehr kleinen Screens sekundäre Panels droppen. Rail (icon-only, rechte Kante) als Alternative im Landscape.

**Theming Kenopsia.** Die Sidebar als "Boot-Menü" eines Terminals gestalten: oben ein blinkender Cursor + Typewriter-"KENOPSIA OS v1.__"; Nav-Labels in Caps-Monospace (`> PLAY`, `> SHOP`). Auf Selection erscheint ein `>`-Prompt-Zeichen vor dem Label.

**Named References.** Signalis (Corner-Bracket-Panels, Monochrom-Phasen), Lethal Company (diegetisches Terminal-Listenmenü, Green-Phosphor), Destiny 2 / Warframe (linke bzw. radiale Nav mit Icon+Label und Active-Highlight), Fortnite Locker (Top-Tabs-Alternative). Für Mobile-Bottom-Bar: Brawl Stars / Clash Royale.

### 2. SHOP + PROMO CODES

**Layout & Struktur.** Header-Zeile oben: links Shop-Heading + Reset-Countdown ("FEATURED ROTATES IN HH:MM:SS"), rechts oben die Currency-Pills UND das Promo-Code-Widget (top-right, wie gefordert). Darunter Content: **Featured**-Hero-Reihe (1–2 große Tiles), dann **Rotating/Daily**-Grid, dann **Crates**-Sektion, dann **Direct-Buy (Robux-Specials)**-Sektion. Interne Sektions-Tabs oder Scroll-Anker.

**Item-Card-Grid (Roblox).**
- `ScrollingFrame` `ShopGrid` mit `UIGridLayout` (`CellSize` z.B. 180×220px, `CellPadding` 12px). Am Mobile 2 Spalten, Desktop 4–5.
- Card = `Frame` mit: oben `ViewportFrame` (3D-Item-Render, WorldModel + Camera + rotierendes Model via RunService), Rarity-Farbe als `UIStroke`-Rahmen + radialer BG-Gradient (`UIGradient`), darunter `TextLabel` Name, Preis-Zeile (`ImageLabel` Currency-Icon + `TextLabel` Betrag), unten `TextButton` Buy.
- Sektions-Header: `TextLabel` (Heading `#E8FBFF`) + optional Countdown-`TextLabel`.

**Buy-Button-States.** Default/affordable (`#06121A` BG, cyan Text, cyan Stroke) → Hover (Stroke hell + Glow) → Purchasing (Spinner/"...VERIFYING") → Owned ("OWNED", disabled, `#4E7C8A`) → Can't-afford (Preis in dim, "+"-Prompt zum Currency-Kauf; NICHT rot, da rot reserviert) → Equipped (falls wearable, siehe Inventory) → Sold-out/Expired ("EXPIRED", disabled).

**Purchase-Confirmation-Flow.** Für Robux-Käufe: Roblox `MarketplaceService:PromptProductPurchase`/`PromptPurchase` triggert das native Roblox-Overlay — kein eigenes Confirm nötig, aber ein eigener Vor-Bestätigungs-Dialog ("PROCESS SUBJECT? [CONFIRM]/[CANCEL]" im Terminal-Stil) erhöht Klarheit. Für Credits-Käufe: eigener Modal-Confirm mit Preis, Restbalance-Vorschau und [CONFIRM]/[CANCEL]. Nach Erfolg: Balance-Count-down-Animation + Toast "ACQUIRED: <item>".

**Featured/Rotating/Limited.** Featured-Tiles größer (2×-Cell), mit "FEATURED"-Ribbon; Rotating mit Reset-Countdown; Limited mit Ablauf-Countdown + Stock-Anzeige ("3 REMAINING"). Urgency ohne Rot lösen: pulsierender cyan/weißer Rahmen.

**PROMO-CODE-Widget (top-right des Shop).**
- `Frame` `PromoWidget` oben rechts (unter/neben Currency-Pills): `TextBox` `CodeInput` (Placeholder "ENTER ACCESS CODE...") + `TextButton` `RedeemBtn` ("REDEEM"). Im Terminal-Look: `> _`-Prompt, blinkender Cursor.
- **States:** Success (im Kalt-CRT bleibt es cyan/weiß statt grün: heller `#E8FBFF`-Flash + Checkmark + Toast "CODE ACCEPTED: +<reward>", Feld leert sich); Invalid ("SIGNAL CORRUPTED / INVALID CODE", Feld-Shake via TweenService X-Wackeln, Text in dim-cyan — Rot vermeiden, stattdessen Glitch-Distortion als Fehlersignal); Already-redeemed ("CODE ALREADY PROCESSED"); Expired ("SIGNAL EXPIRED"); Redeeming ("VERIFYING..." Button disabled + Spinner, verhindert Doppel-Submit).
- **Server-Autorität:** Redeem-Logik in einem `RemoteFunction` serverseitig validieren (Codes nie im Client speichern), pro Spieler in `DataStore` als redeemed markieren.

**Named References.** Fortnite Item Shop (Featured-Hero + Daily-Grid + Reset-Countdown + Rarity-Gradient-Cards), Valorant Store (Featured-Bundle + rotierende Offers + Countdown; bewusst KEINE Loot-Boxes für Skins → Direct-Buy, plus Night Market als randomisierter *Rabatt* mit Card-Flip statt Item-Gamble), Rocket League (Featured+Daily+Credits). Roblox: Twitter/𝕏-Icon-Codes-Konvention, Grid-Cards mit Rarity-Tag + Currency-Icon + Buy.

### 3. CREDITS / CURRENCY-DISPLAY

**Platzierung & Struktur.** Persistente Top-Bar oben rechts, sichtbar über alle Tabs. Zwei Pills nebeneinander:
- **Credits** (soft, earned): `[Credit-Icon][12,450][+]` — "+"-Button öffnet einen Hinweis, wie Credits verdient werden (kein Direktkauf, wenn Credits nur earned sind — ethisch sauber; alternativ optional Robux→Credits, aber das nähert sich Gambling, daher lieber earned-only halten).
- **Robux** (premium): `[R$-Icon][amount][+]` — "+" öffnet Robux-Kaufflow.

**Roblox-Umsetzung.** `Frame` `CurrencyBar` mit `UIListLayout` (horizontal). Jede Pill: `Frame` mit `UICorner`, `ImageLabel` Icon (Pixelated), `TextLabel` Betrag (mit Tausender-Formatierung via string-format), `TextButton` "+". Balance aus einem replizierten Wert (`NumberValue`/Attribute), Client hört auf `.Changed`.

**Animation (Juice).** Bei Earn/Spend: `TextLabel`-Count-up/-down via TweenService (numerischer Tween über ~0.4s, gerundet je Frame), plus Scale-Punch der Pill (`UIScale` 1→1.15→1, Bounce) und ein kurzer Glow (`UIStroke.Transparency` Puls). Optional Partikel-Icons, die beim Earn in die Pill "fliegen" (kleine ImageLabels via Tween). Beim Spend Farbe kurz auf `#E8FBFF`. (Referenz-Muster: Clash Royale / Brawl Stars — "coins fly to wallet".)

**Theming.** Credits-Icon als kalte cyan-weiße Glyphe (z.B. stilisiertes Terminal-"₵" oder Maschinen-Token), Robux nativ. Zahlen in Monospace. Beim Count-up kurzer Scanline-Roll über die Zahl.

**Mobile.** Pills kleiner, "+" bleibt ≥44pt Touch-Target; ggf. Betrag kürzen (12.4k).

**Named References.** Clash Royale (Gold+Gems Pills mit "+"), Brawl Stars (Coins/Gems Top-Bar), Fortnite (V-Bucks + "+"), Roblox (R$-Anzeige). Count-up-Juice: Clash Royale / Brawl Stars.

### 4. INVENTORY / WARDROBE / LOADOUT (inkl. Crate-UI, Rarity)

**Layout.** Zweispaltig: **links** großes `ViewportFrame`-Mannequin (das Subject-Model, live aktualisiert beim Equip, langsam rotierend, optional Emote-Preview); **rechts** oben Slot-Filter-Tabs (Mask, Headgear, Back Item, Face, Body-Tint, Trail, Footstep FX, Nameplate/Title, Podium/Victory, Emote), darunter Rarity-Filter (ALL/RARE/EPIC/LEGENDARY/UNIQUE), darunter das Item-Grid (`ScrollingFrame`+`UIGridLayout`).

**Roblox-Umsetzung.**
- Mannequin: `ViewportFrame` mit `WorldModel`, geklontes Character-Rig + Accessories, eigene `Camera`, Rotation via `RunService.RenderStepped`. Equip → Accessory im Viewport hinzufügen/entfernen.
- Grid-Card: `ViewportFrame` (3D-Item), Rarity-`UIStroke` + `UIGradient`, Name, State-Button.
- Rarity-Filter/Slot-Tabs: `TextButton`s mit Active-Highlight (weißer Streak).

**Equip vs. Equipped States.**
- Owned, nicht equipped: Card normal, Button "EQUIP".
- **Equipped:** Rarity-Glow-Rahmen verstärkt + "EQUIPPED"-Ribbon/Checkmark, Card ans Grid-Anfang sortiert, Button "UNEQUIP" oder inaktiv mit Check.
- Not owned (falls im Inventory sichtbar als "locked"): ausgegraut + Lock + "GET IN SHOP"-Link.
- Buy (falls Inventory Kauf erlaubt): wie Shop-Buy-States.

**RARITY-System (die erwartete Farbsprache).**
- RARE = blau `#4A90E2`
- EPIC = lila `#B026FF`
- LEGENDARY = gold `#FFD700`
- UNIQUE = animierter Regenbogen/Holo-`UIGradient` (Rotation der Gradient-Offset per Tween) + pulsierender Glow (`UIStroke.Transparency`) + `ParticleEmitter`/getweente Sparkle-ImageLabels + eigener Reveal-Sound.
- Umsetzung: Rarity-Farbe als `UIStroke.Color` + radialer `UIGradient` hinter dem Item. Für UNIQUE ein Script, das den Gradient-Hue kontinuierlich shiftet. Border/Glow-Intensität steigt mit Tier. Optional Scarcity-Text ("1 OF 500 PROCESSED"), um UNIQUE genuine special zu machen.

**CRATE / LOOT-UI.**
- **Odds-Disclosure (Pflicht bei Robux-Crates):** ein (ⓘ)-Button auf jeder Crate öffnet ein Modal mit vollständiger Wahrscheinlichkeits-Tabelle je Tier (z.B. RARE 60% / EPIC 25% / LEGENDARY 12% / UNIQUE 3%), zugänglich VOR dem Kauf. Roblox verlangt klare, akkurate, leicht zugängliche Odds-Angabe für bezahlte randomisierte Items.
- **Ethik / Anti-Gambling-Framing:** Credits-Crates (earned) optisch klar von Robux-Direktkäufen trennen; keine "Buy Credits→Open Crate"-Kette mit Echtgeld; Odds trotzdem anzeigen; keine Near-Miss-Manipulation. Sprache neutral halten ("PROCESS", "DECRYPT"), nicht "jackpot/win".
- **Reveal-Animation (CS:GO-Stil, on-theme).** Sequenz: Crate/Datencontainer im Zentrum → Klick "DECRYPT" → Anticipation-Shake (~0.6s) + aufbauendes Glow, dessen FARBE die Rarity telegrafiert (blau/lila/gold/holo) → horizontaler Spin-Reel von Item-Tiles scrollt am Center-Ticker vorbei, verlangsamt mit "tick-tick"-Sound → landet auf Item → Flash + Rarity-Beam + Partikel → Name/Rarity faden per typewriter ein → Buttons [CLAIM] / [DECRYPT AGAIN]. UNIQUE/LEGENDARY: langsameres Timing, Screen-Flash, Screenshake, eigener Audio-Sting. In Roblox: Reel als `Frame` mit `UIListLayout` horizontal, Position-Tween mit stark ease-out; Server bestimmt Ergebnis (RemoteFunction), Client animiert nur zum vorbestimmten Item.

**Mobile.** Mannequin oben (kleiner), Filter+Grid darunter (vertikales Stapeln); Slot-Tabs als scrollbare horizontale Leiste; 2-Spalten-Grid. Auf sehr kleinen Screens Mannequin-Panel als Toggle.

**Named References.** Fortnite Locker (Slot-Loadout + Live-Mannequin), Warframe Arsenal (rotierendes 3D-Model + Slots), Roblox Avatar Editor (3D-Preview links + filterbares Grid + worn-Highlight), Destiny 2 (Slot-Frames, Rarity-Farben — Achtung: dort lila=Legendary, gold=Exotic). Rarity-Konvention: Fortnite/WoW; CS2 (Gold=Knives/Gloves als "Unique"-Signal). Crate-Spin: CS:GO Case-Opening; Glow-Color-Tell: Hearthstone Pack-Opening. Odds: CS2/Apex ("Pack odds"-Button)/Genshin (Pity-Details).

### 5. PLAY / PARTY-LOBBY

**Layout.** PLAY-Screen mit drei Primäraktionen als große Terminal-Tiles/Buttons: **HOST** (Create Private Room), **JOIN** (by Code/Invite), **PUBLIC LOBBY** (Matchmake). Optional PLAY SOLO. Darunter/daneben ein **Party-Panel** mit Member-Slots.

**Flows.**
- **HOST:** erzeugt via `TeleportService:ReserveServer(placeId)` einen reservierten Server; zeigt einen prominenten **Room-Code** groß an (Monospace) + Copy-to-Clipboard-Button + "INVITE FRIENDS" (Roblox `SocialService:PromptGameInvite`). Host-only-Controls: Difficulty/Trial-Select, Kick, START (enabled ab Min-Playern/alle ready). Teleport aller Party-Member via `TeleportService:TeleportToPrivateServer`.
- **JOIN:** `TextBox` Code-Input ("ENTER ROOM CODE") + "CONNECT"-Button; Server validiert Code→reservierten AccessCode nachschlagen (in MemoryStore/DataStore gemappt)→Teleport. States: Connecting/"ESTABLISHING LINK...", Invalid ("NO SIGNAL / INVALID CODE"), Full ("ROOM AT CAPACITY").
- **PUBLIC LOBBY:** Quick-Play; Matchmaking-Spinner mit "SEARCHING… 3/8 SUBJECTS"; via `TeleportService:TeleportPartyAsync` oder place-teleport in Public-Server; Cancel-Button.

**Party-Panel.** Member-Slots (`Frame` je Slot): Avatar-`ViewportFrame`/Thumbnail, Name, Host-Crown-Icon, Ready-State (✓ / "…"). Buttons: INVITE FRIENDS, LEAVE. Host sieht START (disabled bis Bedingung erfüllt). Ready-Up: `TextButton` toggelt Ready-Attribut, repliziert an alle.

**Roblox-Umsetzung.** `RemoteEvent`s für Ready/Start/Join; `TeleportService` (ReserveServer, TeleportToPrivateServer, TeleportPartyAsync); Code→ReservedServerAccessCode-Mapping in `MemoryStoreService` (kurzlebig) oder `DataStore`. Party-State auf Server autoritativ; Client nur Anzeige.

**States (Buttons).** HOST/JOIN/PUBLIC: Default (cyan Terminal-Tile) → Hover (Glow) → Busy/Connecting (Spinner + disabled) → Error (Glitch-Feedback, dim-cyan Text — kein Rot). START: disabled (`#4E7C8A`) bis Ready-Bedingung, dann heller weißer Streak.

**Mobile.** Drei große gestapelte Tiles (je ≥56px hoch), Party-Panel darunter oder als Toggle-Sheet; Code-Input mit großem Feld; Copy/Invite-Buttons ≥44pt.

**Theming Kenopsia.** PLAY als "SUBJECT INTAKE"-Terminal: HOST = "OPEN PRIVATE CYCLE", JOIN = "LINK TO CYCLE", PUBLIC = "ENTER PROCESSING QUEUE". Room-Code als "SIGNAL ID" im Monospace-Feld mit blinkendem Cursor. Matchmaking-Spinner als rotierendes Maschinen-Sigil + typewriter-Statuszeilen.

**Named References.** Among Us (Room-Code Host/Join, Public "Find Game"), Lethal Company (Host/Join Online + Invite, Ship-Lobby, Host-triggered Start), Phasmophobia (Public/Private/Single, Lobby-Code, Difficulty/Map-Select), Devour (Ready-Up pro Player vor Start), Fortnite (Party-Panel bottom-left mit Ready-Check + Invite), Fall Guys (Squads/Solo + Matchmaking-Spinner). Roblox: Reserved/Private Servers via TeleportService.

---

## Recommendations

**Stufe 1 — Fundament (zuerst bauen).**
1. Root-`ScreenGui` + globaler CRT-Scanline/Flicker-Overlay + Palette-Konstanten (Modul `Theme.lua` mit allen Hex-Werten und Rarity-Map). Pixel-Monospace-Font einbinden, `ResamplerMode.Pixelated` überall auf Icons/Viewports.
2. Sidebar-Rail (Desktop expanded/collapsed) + Bottom-Tab-Bar (Mobile) mit den 3 Primärzielen; Tab-Switching mit Glitch/typewriter-Transition. `UIScale`-Responsiv-Script.
3. Persistente Currency-Bar (Credits + Robux Pills) mit Count-up-Juice.

**Stufe 2 — Kern-Content.**
4. INVENTORY mit ViewportFrame-Mannequin + Slot/Rarity-Filter + Equip/Equipped-States. Rarity-Farbsystem als wiederverwendbare Card-Komponente (RARE/EPIC/LEGENDARY/UNIQUE inkl. animiertem UNIQUE-Rahmen).
5. SHOP mit Featured/Rotating/Crates/Direct-Buy-Sektionen + Buy-Button-States + Promo-Code-Widget (top-right) inkl. aller vier Feedback-States, serverseitig validiert.
6. PLAY mit HOST/JOIN/PUBLIC + Party-Panel + ReserveServer-Flow + Ready-Up.

**Stufe 3 — Monetarisierung & Politur.**
7. Crate-Reveal-Animation (Spin-Reel, farbcodierter Glow, Tier-abhängiges Timing) + verpflichtende Odds-(ⓘ)-Modal VOR Kauf.
8. Robux-Direktkauf via `MarketplaceService` + Terminal-Confirm-Dialog; Credits-Confirm-Modal.

**Benchmarks / was Entscheidungen ändern würde.**
- Wenn Mobile-Anteil > ~60% (bei Roblox typisch): Bottom-Tab-Bar priorisieren, Sidebar am Desktop optional collapsed-default; Crate-Reveal-Timing kürzen (Aufmerksamkeitsspanne, Performance auf Low-End-Phones).
- Wenn ViewportFrame-Performance auf Low-End einbricht: statische vorgerenderte Thumbnails als Fallback (`ImageLabel`) mit ViewportFrame nur im Detail-View.
- Wenn Roblox-Moderation Odds-Compliance prüft: Odds-Modal MUSS vor jedem Robux-Crate-Kauf erreichbar sein — nicht nur in einem Sub-Menü.
- Wenn "UNIQUE" sich nicht besonders genug anfühlt (Playtest-Feedback): Reveal-Full-Screen-Takeover + Ownership-Count ("1 OF 500 PROCESSED") ergänzen.

---

## Caveats

- **Live-Recherche-Tools waren in dieser Umgebung nicht verfügbar** (web_search/web_fetch schlugen fehl; auch der Recherche-Subagent konnte keine Live-Seiten laden). Alle Referenzen stammen aus fundiertem Domänenwissen, nicht aus frisch gezogenen Screenshots von gameuidatabase.com/interfaceingame.com. Vor Final-Implementierung: Layouts gegen aktuelle Screenshots spot-checken (relevante Kategorien dort: Main Menu, Shop/Store, Loot Box/Crate, Inventory/Loadout, Currency/HUD, Lobby/Matchmaking).
- **Roblox-Odds-Disclosure-Wortlaut ist paraphrasiert**, kein Verbatim-Zitat. Die exakte aktuelle Formulierung auf der Roblox-Policy-Seite (create.roblox.com / en.help.roblox.com, "randomized virtual items / paid random items") vor Launch verifizieren — Compliance ist verpflichtend.
- **Rarity-Hex-Werte** (`#4A90E2`, `#B026FF`, `#FFD700`) sind community-übliche/WoW-abgeleitete Konventionswerte; exakte Marken-Hexes einzelner Spiele können abweichen. Destiny 2 nutzt lila=Legendary/gold=Exotic abweichend — bei Kenopsia die Fortnite/WoW-Konvention als Default empfohlen.
- **Valorant** nutzt benannte Editions (Select/Deluxe/Premium/Ultra/Exclusive) statt einer simplen Farbskala — nur als Direct-Buy-Struktur-Referenz zitieren, nicht als Rarity-Farbquelle.
- **TeleportService-Codeflow** (ReserveServer + Code-Mapping) ist ein etabliertes Muster, aber MemoryStore/DataStore-TTL und Rate-Limits müssen bei der Implementierung berücksichtigt werden.
