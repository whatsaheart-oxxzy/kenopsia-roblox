# R2-empty-hold — PARTIAL

TRUE: 5s hold real + compulsory; shiftreport renders no Kenopsia UI (not in KNOWN_KINDS).
FALSE: "shows nothing / empty screen". Unknown-kind branch returns BEFORE session+=1,
Overlay.clear() and any hideAll() -> the FINAL VERDICT BOARD from the previous
kind="score" beat stays on screen. showScore never self-hides; the Ticker keeps
tweening. Board is cleared only by kind="hide" from cleanup() (MachineFlow:825),
which runs AFTER the hold. Net: verdict board visible 6.0 + 5.0 = ~11 s.
Also: SocialClient:78-84 uses the shiftreport packet to open Roblox's invite sheet.
