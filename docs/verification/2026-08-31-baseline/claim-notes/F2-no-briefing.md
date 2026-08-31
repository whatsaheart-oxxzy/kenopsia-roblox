# F2-no-briefing -- PARTIAL (headline REFUTED, three sub-claims stand)

READ-ONLY. Live reads via weppy clientId ad22f53b-... placeId 110672791536316. No play test.

## REFUTED
- CONTROLS window exists live and is authored Visible=true:
  [RUNTIME] game.StarterGui.KenopsiaMachine.Info.ControlsWindow Visible=true, Title.Text="CONTROLS",
  children Row1/Row1b/Row2/Row3/SecRunners/SecSniper/Page2(H1,R1..R5)/PageLabel/ArrowL/ArrowR.
- Per-trial text: LIVE MachineLayout TRIAL_TEXT birdhunt/minefield/canteen + default fallback,
  applyControlsText() bound to machine TrialId attribute (live MachineLayout:401).
- Scanner IS explained live: minefield Row2 "Pulse  [HOLD {Scan}]", Row3 "Shows mines within 8 studs"
  (live MachineLayout:178-179/186/193) + 5-line scoring page (live 203-209).
  The MIRROR studio-src still has the OLD empty version -> the handoff claim is stale-mirror derived.
- Page2 reachability fixed live: pager reads win:GetAttribute("Pages") (live KenopsiaClient:3874),
  MachineLayout publishes it from `filled` (live MachineLayout:399). Mirror still hardcodes canteen.
- Contextual feedback exists: pushFeed kill/告 feed (live KenopsiaClient:1062-1122), Minefield
  "SONAR %d LEFT."/"SONAR SPENT."/"HOLD STILL TO SCAN."/"WOUNDED. CRAWL.", death card
  "YOU STEPPED WRONG. TWICE.", canteen EatPrompt HOLD/EAT + edge glow phases.
- Lobby Info card (preFlow, MachineFlow:482) carries the FIRST trial's controls with no time limit.

## STANDS (true half)
1. cpout carries reason="seen" (CanteenProtocol:465) -- live client has ZERO matches for `p.reason`;
   it prints bare "PROTOCOL VIOLATION" (live KenopsiaClient:3567). Cause never stated.
2. MIS-TEACH: page says "Loading       always safe" (live MachineLayout:243) but server eliminates on
   action=="plate" while phase=="watching" (CanteenProtocol:822-824). EatPrompt "HOLD" only shows at
   full fork (cpApplyPrompt), so loading under open eyes has no warning at all.
3. Bird Hunting tells the RUNNER nothing: 0 hits for style="death" and 0 for kind="feed" in live
   BirdHunting. Hunter gets hitmark TERMINATED/IMPACT; victim gets blood + spectate 2 s later.
4. The authored 2-page BRIEFING (MenuConfig.Menu.Briefing) is dead in MainGame: its only renderer
   MainMenu.client.luau is absent from live StarterPlayerScripts (15 children, no MainMenu).
5. Briefing STAGE (8 s, Pacing.ControlCard) shows only name+tagline+"Minigame N of M."+
   "Bootstrapping simulation ..." (live MachineFlow:969-975). Controls card gets 3.5 s (Reveal).
6. MachineVoice is flavour only -- no rule text; RoleCards only for birdhunt.
