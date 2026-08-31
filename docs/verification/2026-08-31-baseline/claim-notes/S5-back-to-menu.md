# S5-back-to-menu — PARTIAL

## What actually exists
A button literally labelled "BACK TO MENU" (Instance name Btn_MENU) IS built by
KenopsiaClient inside the SHIFT COMPLETE end card, and it IS routed through a
validated server route (RoomReadyRequest -> allow() rate limit -> setReady()
authority checks). So the claim's stated mechanism is wrong.

It is nonetheless not a working way back to the menu, for TWO independent reasons:

1. UNREACHABLE. build() (which creates Btn_MENU) is only called by show(), and
   show() is only scheduled from the `p.kind == "podium"` branch of the end-card's
   MachineState listener. The podium beat was deleted on 30.08.2026
   (MachineFlow live 1373-1379). Live search of all 34 ServerScriptService scripts:
   0 occurrences of the literal "podium"; podiumPacket() appears once, inside
   Podium.raise, which nothing calls; Podium is required only at MachineFlow:45
   and never invoked. No podium packet can be sent -> the end card never appears.

2. MISLABELLED. Even if shown, dismiss(false) fires RoomReadyRequest:FireServer(false).
   setReady un-readies the player and drops them from the rematch set. It does not
   teleport. The menu is a different place (129909297895850). Player stays in MainGame.

## RoomLeaveRequest
Exists, is validated (allow(player,"leave",3)), and is a deliberate no-op
(RoomService live 606-611, comment "Leaving the canonical room is not supported").
No client fires it: 0 hits for RoomLeaveRequest across 28 live StarterPlayer scripts.

## Only exit = SoloExit or quitting — TRUE
TeleportService appears in exactly ONE live script: SoloExit (line 104).
Searched live: 34 ServerScriptService + 28 StarterPlayer + 28 ReplicatedStorage +
1 ReplicatedFirst = 91 scripts. StarterPlayer/ReplicatedFirst/ReplicatedStorage: 0 hits.
SoloExit fires only when exactly 1 player remains AND hadCompany
(SoloExit.luau:69-71, 116-121). With 2+ players nobody can leave except by quitting.
SoloExit.sendToMenu no-ops in Studio (SoloExit.luau:95-102) -> not observable in a
Studio playtest, only on a published server.

## Reconciles a gap in live-gui.md
live-gui.md sec.5 said "no return-to-menu button among 19 GuiButtons". That inventory
is edit-time StarterGui only; Btn_MENU is Instance.new'd at runtime under `machine`,
so it would never appear there. The button exists in code — it is just never built.
