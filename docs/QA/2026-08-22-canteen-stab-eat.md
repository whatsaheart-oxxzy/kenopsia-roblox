# QA — Canteen: re-published clips, fork rig, Stab/Eat (P0.2 + P4.0 part), 2026-08-22

**Place:** Kenopsia_MainGame 110672791536316, Studio Play Solo, temporary `TrialIds = { "canteen" }` (reverted).

## Animation ids (re-published by the user under the group — no permission link needed any more)

Probe on a fresh clone of the rigs, server side, `track.Length` after Play:
`Idle 2.00 s · Stab 0.20 s · Eat 0.40 s · Death 1.97 s · Boss Reading 4.00 s · LookUp 1.47 s · LookDown 0.63 s · Shoot 1.63 s`.
Server log: `[AnimationIds] published animation ids play in this place`, `[CP] rigs: boss=seated (5 tracks) diners=1 scale=1.67 eat=clip published=true`.
Closes the F-05 blocker.

## Fork rig

`Workspace.Player_Rig_Fork` (user import) → `ServerStorage.KenopsiaAssets.Rigs.PS1Player_Fork` (Precise, 1024 atlas on body/head/bag, Fork grey, Beans_Fork green and hidden until a PLATE). The three import models (`Player_Rig_Fork`, `Anim_Stab`, `Anim_Eat`) are parked under `ServerStorage.KenopsiaAuthoring.Imports`. `CanteenDiner.findTemplate()` prefers the fork rig; the prop fork + riders of a seat with a fork-diner are hidden.

## Observed (server track logger on CanteenDiner1, real clicks through `user_mouse_input`)

```
3.95  Stab (…64825) 0.03 → 0.20 s, beans visible from the first frame
5.81  Eat  (…12729) 0.03 → 0.40 s, beans hidden at 0.18–0.21 s (frame 5 of 12)
HUD after two bites: PLATE 08  EATEN 08/16
TrialInput packets: plate, mouth with token CP-S1-44701-R3-…
```

Boss: Reading loop is its own track now; LookDown's `Stopped` hands over to Reading (no snap).

## Gate

- [x] every id resolves with Length > 0 in the place
- [x] Stab on PLATE (once per accepted load, not per state push), Eat on MOUTH, beans on the tines between them
- [x] a fork=0 state push during a bite is parked until the bite lands (`setBeans` / `beansAfter`)
- [x] parity place ↔ studio-src for AnimationIds, CanteenBoss, CanteenDiner, CanteenProps; selene 0/0; `tests/animationids.lua` PASS
- [ ] not yet: plates/mouth targets moved to the clip's authored geometry (the fork still stabs 3.2 rig-units in front of the seat, the plates sit further away); CP_Observer import; face textures; Boss.Death id (still 0)

## Gotcha

Clicks sent before `go` or while the fork is full are dropped by design (client gate / capacity 4) — the first click batch looked like a lost input path and was not.
