# Place-Dokumentation — Kenopsia_MainGame

Vollständige Aufnahme des Roblox-Place **`110672791536316`** ("Kenopsia_MainGame"),
gelesen am **21.08.2026** live aus dem geöffneten Roblox Studio über die Studio-MCP.

> Zielort im Repo: `docs/place/`

## Was hier drin steht

| Datei | Inhalt |
|---|---|
| [`01-PLACE-OVERVIEW.md`](01-PLACE-OVERVIEW.md) | Service-Zensus, alle Service-Einstellungen, Boot-Reihenfolge, der Session-Loop |
| [`02-SCRIPTS.md`](02-SCRIPTS.md) | Alle 21 Skripte: Pfad, Größe, Header, jede Top-Level-Funktion mit Zeilennummer |
| [`03-WORLD.md`](03-WORLD.md) | Workspace: die drei Arenen, jeder Marker mit Position und Attributen, jedes Prop-Template |
| [`04-GUI.md`](04-GUI.md) | `KenopsiaMachine` komplett: jeder Frame, jede Farbe, jeder Text, jede Z-Ebene |
| [`05-ASSETS.md`](05-ASSETS.md) | Jede Asset-ID des Places: Meshes, Texturen, Sounds, Animationen, Rigs |
| [`06-CONTRACTS.md`](06-CONTRACTS.md) | RemoteEvents, Paket-Arten, Attribute, Rollen, alle Konfigurationswerte |
| [`07-FINDINGS.md`](07-FINDINGS.md) | 22 Befunde aus der Aufnahme — Widersprüche, Duplikate, offene Risiken |

## Wie diese Aufnahme entstanden ist

Kein Plandokument wurde als Wahrheit übernommen. Jede Zahl stammt aus einer der
folgenden Quellen:

- **Instanzbaum und Eigenschaften**: `execute_luau` gegen den `Edit`-Datamodel des
  laufenden Studio, rekursiv über `GetChildren()` / `GetDescendants()`.
- **Skriptquellen**: `.Source` jedes `LuaSourceContainer`, gemessen in Bytes,
  Header-Kommentar und Top-Level-Definitionen extrahiert.
- **Asset-IDs**: `MeshPart.MeshId`, `.TextureID`, `SurfaceAppearance.ColorMap`,
  `Sound.SoundId`, plus die publizierten Animations-IDs aus `AnimationIds.luau`.
- **Repo-Abgleich**: Dateigrößen und Zeitstempel aus dem Dateisystem,
  Commit-Historie aus `.git/logs/HEAD`.

## Was NICHT erfasst werden konnte

| Was | Warum |
|---|---|
| `Lighting.Technology` | Lesezugriff verweigert (`lacking capability RobloxScript`) — die MCP-Sandbox darf diese Eigenschaft nicht lesen |
| `Workspace.StreamingIntegrityMode`, `StreamingTargetRadius`, `SignalBehavior`, `PhysicsSteppingMethod` u.a. | dito |
| `Players.UseStrafingAnimations` | dito |
| Inhalt von `ServerStorage.RBX_ANIMSAVES` (29 785 Instanzen) | bewusst übersprungen — reine Keyframe-Rohdaten; die Ebene darüber ist in [`05-ASSETS.md`](05-ASSETS.md) vollständig dokumentiert |
| Innengeometrie wiederholter Props (Schrauben in Lampen usw.) | als Template einmal dokumentiert, nicht pro Instanz — siehe [`03-WORLD.md`](03-WORLD.md) |
| Laufzeit-Instanzen (`ReplicatedStorage.Kenopsia.Remotes`, `workspace.KenopsiaArenas`) | existieren im Edit-Modus nicht; aus dem Quelltext rekonstruiert in [`06-CONTRACTS.md`](06-CONTRACTS.md) |

## Aufnahme wiederholen

Die Aufnahme ist reproduzierbar: Studio mit dem Place öffnen, dann pro Abschnitt ein
`execute_luau` gegen `datamodel_type: "Edit"`. Die verwendeten Skripte sind in den
jeweiligen Dateien als "Erhebungsmethode" beschrieben. Wichtig:

- Jede Eigenschaftsabfrage in `pcall` wickeln — mehrere Service-Eigenschaften sind
  für die MCP-Sandbox nicht lesbar und werfen statt `nil` zurückzugeben.
- `game:GetDescendants()` liefert auch Studios eigene Plugin-Instanzen
  (`StatsItem`, `StyleRule`, `MemStorageConnection`, `ImageButton` der Studio-UI)
  und Studio-eigene CollectionService-Tags (`data-testid=…`, `TagEditorTagContainer`).
  Immer service-weise zählen, nie über `game`.
- Ausgaben über ~100 KB schreibt die MCP in eine Datei statt sie zurückzugeben.
  Wiederholte Strukturen vorher zusammenfassen.

## Stand des Places zum Aufnahmezeitpunkt

- **3 Minispiele** live und `ready = true`: `birdhunt`, `minefield`, `canteen`
- **4 Spieler** pro Server, **ein** Raum pro Server
- **21 Skripte**, 386 KB Quelltext
- **40 144** Instanzen im Datamodel, davon 29 785 Animations-Rohdaten
- **0** Persistenz (kein DataStore, kein Badge, kein GamePass, keine leaderstats)
- Letzter Commit des Repos: **14.08.2026** — die Arbeit vom 15.–19.08. ist nicht
  versioniert, und das Repo hat kein Remote. Siehe [`07-FINDINGS.md`](07-FINDINGS.md) F-01.
