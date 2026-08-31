# S1-warning-dep -- CONFIRMED

## Live absence (independently reproduced, not inherited from live-gui.md)
[RUNTIME] weppy clientId ad22f53b-... placeId 110672791536316 studioState edit
- query_instances search_name "Warning" root=game maxResults=50 -> count 1
  = game.SoundService.KenopsiaAudio.SFX.Warning (Sound). No GUI object named Warning anywhere.
- manage_scripts search path=game pattern='Name = "Warning"' -> 0 matches / 115 scripts searched.
- manage_scripts search path=game pattern='"Warning"' -> 21 matches, ALL reads or sfx names.
  No Instance.new/clone constructs a Warning frame.

## Stall A -- loading screen (the claim's core)
LIVE game.ReplicatedFirst.KenopsiaLoading (286 raw / 285 real lines)
  242 task.spawn(function()
  251   local machineGui = playerGui:WaitForChild("KenopsiaMachine", 20)
  252   if machineGui then
  254     local warning = machineGui:WaitForChild("Warning", 10)   <-- 10 s TIMEOUT
  255     if warning then warning.Visible = true end               <-- guarded, no error
  272-277 ContentProvider:PreloadAsync(criticalAssets)             <-- AFTER the stall
  278   end
  280   local held = os.clock() - t0
  281   if held < 2 then task.wait(2 - held) end
  283   gui:Destroy()                                              <-- SAME coroutine
  284 end)
gui = full-screen opaque cover: line 21-32 ScreenGui KenopsiaLoadingGui, DisplayOrder 100,
IgnoreGuiInset true, bg Size UDim2.fromScale(1,1) BackgroundColor3 INK; line 12
ReplicatedFirst:RemoveDefaultLoadingScreen().
=> cover lifetime goes from ~2 s to ~10 s + preload, every join.
MIRROR studio-src/ReplicatedFirst/KenopsiaLoading.client.luau:122 identical statement.
Depth analysis (depth2.py, EOF depth 0 = balanced): line 122 depth 2, line 162 gui:Destroy() depth 1,
both inside the task.spawn opened at line 110.

## Stall B -- client main chunk (a DIFFERENT defect, not a loading stall)
LIVE game.StarterPlayer.StarterPlayerScripts.KenopsiaClient (4125 lines, CRLF)
  68   local machine = playerGui:WaitForChild("KenopsiaMachine")     depth 0
  3751 local warningFrame = machine:WaitForChild("Warning", 10)      depth 0 -> TOP-LEVEL
  3752 local settingsPanel = machine:WaitForChild("SettingsPanel",10) resolves instantly
Depth verified on reassembled live lines 1-3760 (scratchpad live-KenopsiaClient-1-3760.luau).
Defers live lines 3752-4125 (~374 lines) incl.
  3966 lobbyError.OnClientEvent:Connect  (join-rejection notice)
  4108 MS.OnClientEvent:Connect          (final scoreboard / podium clear)
NOT deferred (wired before 3751): 2539 RoomState.OnClientEvent, 3419 MachineState.OnClientEvent.
MIRROR line 2959, verbatim identical, also depth 0.

## Side effect: the content warning ships entirely dark
`if warningFrame then` (live 3754) never runs => no CONTINUE button wiring (3777),
no task.delay(6.5, dismiss) (3784), no sfx("Warning") (3781).
KenopsiaLoading:270 still preloads SFX.Warning for a screen that never shows.

## Residual NEEDS_RUNTIME
Play test and (a) inspect Players.<n>.PlayerGui.KenopsiaMachine for a Warning child,
(b) stopwatch / print os.clock() around KenopsiaLoading gui:Destroy().
