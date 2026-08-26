-- Gate 1 offline proof. Run from the repo root:
--
--     lua tests/rules.lua
--
-- This loads the SHIPPED module files from studio-src -- not copies -- so what
-- passes here is what runs in the place. The only thing the harness supplies is
-- a stand-in for Roblox's `script` / `require`, because those are the one part
-- of a "pure" module that still cannot exist outside the engine.
--
-- Exit code is 0 only if every check passes, so this is usable as a gate.

local ROOT = "studio-src/ReplicatedStorage/Kenopsia/Shared/Rules/"

-- `require(script.Parent.X)` is given a TABLE by Roblox, not a string. The shim
-- therefore makes script.Parent.X be the already-loaded module and require the
-- identity function -- no rewriting of the module source, no second copy to
-- drift out of step.
local function loadModule(file, parent)
	local chunk = assert(loadfile(ROOT .. file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = parent or {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local Pacing = loadModule("Pacing.luau")
local Playlist = loadModule("Playlist.luau")
local Scoring = loadModule("Scoring.luau", { Pacing = Pacing })

local failures = 0
local checks = 0

local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
	end
end

-- 1. PACING ------------------------------------------------------------------

print("\nPACING -- rounds and legs per player count")

local expected = {
	{ "minefield", 2, 4 }, { "minefield", 3, 3 }, { "minefield", 4, 3 },
	{ "birdhunt", 2, 3 },  { "birdhunt", 3, 3 },  { "birdhunt", 4, 3 },  -- 22.08.2026: 3 legs x 60 s (MASTERPLAN P0.3)
	{ "canteen", 2, 3 },   { "canteen", 3, 2 },   { "canteen", 4, 2 },
	-- MP-05 section A rows, one per new trial.
	{ "carve", 2, 3 },      { "carve", 3, 3 },      { "carve", 4, 2 },
	{ "armory", 2, 3 },     { "armory", 3, 2 },     { "armory", 4, 2 },
	{ "upstream", 2, 3 },   { "upstream", 3, 3 },   { "upstream", 4, 2 },
	{ "floorcheck", 2, 3 }, { "floorcheck", 3, 3 }, { "floorcheck", 4, 2 },
	{ "clearance", 2, 2 },  { "clearance", 3, 2 },  { "clearance", 4, 2 },
	{ "carrier", 2, 2 },    { "carrier", 3, 3 },    { "carrier", 4, 2 },
	{ "breather", 2, 3 },   { "breather", 3, 3 },   { "breather", 4, 3 },
	{ "sweep", 2, 3 },      { "sweep", 3, 2 },      { "sweep", 4, 2 },
	{ "crawler", 2, 3 },    { "crawler", 3, 2 },    { "crawler", 4, 2 },
	{ "ricochet", 2, 3 },   { "ricochet", 3, 3 },   { "ricochet", 4, 2 },
	{ "stacker", 2, 3 },    { "stacker", 3, 3 },    { "stacker", 4, 3 },
	{ "sorting", 2, 3 },    { "sorting", 3, 2 },    { "sorting", 4, 2 },
}
for _, row in ipairs(expected) do
	local got = Pacing.roundsFor(row[1], row[2])
	check(got == row[3],
		string.format("%-10s %dp -> %d", row[1], row[2], row[3]),
		string.format("got %s", tostring(got)))
end

-- Solo maps onto the 2-player row rather than having one of its own.
check(Pacing.roundsFor("minefield", 1) == Pacing.roundsFor("minefield", 2),
	"solo uses the 2-player row")

-- 23.08.2026: canteen 45 -> 60 (tension ramp; see Pacing.RoundSeconds).
-- 23.08.2026: minefield 55 -> 62 (slower compactor; its speed derives from this).
check(Pacing.RoundSeconds.minefield == 62 and Pacing.RoundSeconds.birdhunt == 60
	and Pacing.RoundSeconds.canteen == 60, "round limits 62 / 60 / 60 s")
check(Pacing.TrialPointPool == 1700, "point pool is 1700")
-- 23.08.2026 (P0.3): the lobby roulette hold moved out of MachineFlow's literal.
check(type(Pacing.Timing) == "table" and Pacing.Timing.LobbyReveal == 6.4,
	"Pacing.Timing.LobbyReveal is 6.4 s (the lobby roulette hold)")
-- P1.3 (23.08.2026), MASTERPLAN section 2/3: verdict stamp 6 s + podium 8 s.
check(Pacing.Timing.FinalScore == 6 and Pacing.Timing.Podium == 8, "verdict beat is 6 s stamp + 8 s podium",
	tostring(Pacing.Timing.FinalScore) .. " + " .. tostring(Pacing.Timing.Podium))
-- P1.4: the role card beat ("<NAME> IS THE HUNTER.") is 1.6 s, MASTERPLAN section 2.
check(Pacing.Timing.RoleCard == 1.6, "role card beat is 1.6 s", tostring(Pacing.Timing.RoleCard))
-- MP-08 S10/S11 (26.08.2026): the roulette between two trials. Its own row, so
-- the price of that beat (6.4 s per switch, +12.8 s in a three-trial session)
-- can be tuned without moving the lobby's.
--
-- The real floor is the client's roulette animation, not this value -- that
-- bound is asserted in tests/feel.lua, which is the file that can see Feel.
-- Here we only pin the shipped number, the way LobbyReveal is pinned.
check(Pacing.Timing.TrialReveal == 6.4, "Pacing.Timing.TrialReveal is 6.4 s (the between-trials roulette hold)",
	tostring(Pacing.Timing.TrialReveal))

-- MP-05 D8: one RoundSeconds number per new trial, section A values.
local expectedSeconds = {
	carve = 45, armory = 50, upstream = 40, floorcheck = 35, clearance = 50, carrier = 45,
	breather = 30, sweep = 45, crawler = 40, ricochet = 45, stacker = 20, sorting = 40,
}
local secondsOk, secondsBad = true, {}
for id, secs in pairs(expectedSeconds) do
	if Pacing.RoundSeconds[id] ~= secs then
		secondsOk = false
		secondsBad[#secondsBad + 1] = id .. "=" .. tostring(Pacing.RoundSeconds[id])
	end
end
check(secondsOk, "MP-05 RoundSeconds match section A", table.concat(secondsBad, ","))

-- Every id in Playlist.Ids has BOTH a rounds row and a RoundSeconds value.
local rowsOk, rowsBad = true, {}
for _, id in ipairs(Playlist.Ids) do
	local r2, r3, r4 = Pacing.roundsFor(id, 2), Pacing.roundsFor(id, 3), Pacing.roundsFor(id, 4)
	if not (r2 and r3 and r4 and Pacing.RoundSeconds[id]) then
		rowsOk = false
		rowsBad[#rowsBad + 1] = id
	end
end
check(rowsOk, "every playlist id has a rounds row and a round limit", table.concat(rowsBad, ","))

-- 2. PLAYLIST ----------------------------------------------------------------

print("\nPLAYLIST -- deterministic shuffle over every id")

local function key(order) return table.concat(order, ",") end

check(#Playlist.Ids == 15, "playlist knows 15 ids", string.format("got %d", #Playlist.Ids))

-- Every id exactly once, never a repeat, for a wide sweep of seeds.
local malformed = 0
for seed = 1, 2000 do
	local order = Playlist.order(seed)
	local seen = {}
	if #order ~= #Playlist.Ids then malformed = malformed + 1 end
	for _, id in ipairs(order) do
		if seen[id] then malformed = malformed + 1 end
		seen[id] = true
	end
	for _, id in ipairs(Playlist.Ids) do
		if not seen[id] then malformed = malformed + 1 end
	end
end
check(malformed == 0, "2000 seeds: every order is a permutation, no repeats",
	string.format("%d malformed", malformed))

-- Distinct orders are reachable. With fifteen ids the permutation space is far
-- larger than 2000 seeds can cover, so the property is "at least six distinct
-- orders within 2000 seeds" (the original three-id proof asked for all six);
-- searching for them proves the shuffle actually varies with the seed rather
-- than asserting a hand-picked list that could pass on a broken shuffle.
local found, distinct = {}, 0
local witness = {}
for seed = 1, 2000 do
	local k = key(Playlist.order(seed))
	if not found[k] then
		found[k] = seed
		distinct = distinct + 1
		if #witness < 6 then witness[#witness + 1] = string.format("seed %d -> %s", seed, k) end
	end
end
check(distinct >= 6, "at least 6 distinct orders within 2000 seeds", string.format("got %d", distinct))
for _, w in ipairs(witness) do print("          " .. w) end

-- The three shipped ids still reach every relative order among themselves.
local rel, relCount = {}, 0
for seed = 1, 2000 do
	local sub = {}
	for _, id in ipairs(Playlist.order(seed)) do
		if id == "minefield" or id == "birdhunt" or id == "canteen" then sub[#sub + 1] = id end
	end
	local k = key(sub)
	if not rel[k] then
		rel[k] = true
		relCount = relCount + 1
	end
end
check(relCount == 6, "the shipped three reach all 6 relative orders", string.format("got %d", relCount))

-- Determinism: the same seed must give the same order every time.
local stable = true
for seed = 1, 50 do
	if key(Playlist.order(seed)) ~= key(Playlist.order(seed)) then stable = false end
end
check(stable, "same seed always yields the same order")

check(Playlist.isKnown("canteen") and not Playlist.isKnown("tablemanners"),
	"isKnown accepts canteen and rejects the old id")
check(Playlist.isKnown("carve") and Playlist.isKnown("sorting") and not Playlist.isKnown("chisel"),
	"isKnown accepts the new ids and rejects an unlisted one")

-- MP-05 D7: the session slice. Playlist.session keeps the first N ENABLED ids
-- of an order, in order; N = 0/nil keeps all of them.
do
	local order = Playlist.order(77)
	local enabled = {}
	for _, id in ipairs(Playlist.Ids) do enabled[id] = true end
	local all = Playlist.session(order, enabled, 0)
	check(#all == #order and key(all) == key(order), "session(0) keeps the whole order")
	check(#Playlist.session(order, enabled, nil) == #order, "session(nil) keeps the whole order")
	local five = Playlist.session(order, enabled, 5)
	local prefixOk = #five == 5
	for i = 1, 5 do
		if five[i] ~= order[i] then prefixOk = false end
	end
	check(prefixOk, "session(5) is the first five of the order")
	-- Only the enabled ids count towards N and disabled ones never appear.
	local three = { minefield = true, birdhunt = true, canteen = true }
	local sess = Playlist.session(order, three, 5)
	local onlyEnabled = #sess == 3
	for _, id in ipairs(sess) do
		if not three[id] then onlyEnabled = false end
	end
	check(onlyEnabled, "session drops disabled ids and stops at what is enabled")
	local relOrder = {}
	for _, id in ipairs(order) do
		if three[id] then relOrder[#relOrder + 1] = id end
	end
	check(key(sess) == key(relOrder), "session preserves the shuffled relative order")
	local two = Playlist.session(order, three, 2)
	check(#two == 2 and two[1] == relOrder[1] and two[2] == relOrder[2],
		"session(2) over three enabled ids is their first two")
end

-- REQ-IP-01: the reference game's minigame names must not appear in shipped
-- source. The forbidden list is stored REVERSED here so this test file itself
-- does not contain the names. Each phrase is checked in every spelling a
-- shipped id, display name, comment or UI string could carry: Title Case,
-- UPPER CASE, CamelCase, lowercase-joined, snake_case, UPPER_SNAKE and the
-- plain lowercase words -- except that the plain lowercase form is skipped for
-- a phrase beginning with "the ", which is ordinary English prose. Checked
-- against Playlist.Ids and against every file default.project.json maps.
--
-- P1.4 (23.08.2026): the second block is the reference's CRT COPY -- its round
-- card taglines, its objective monolith, and the sentences on its briefing and
-- intermission score cards (docs/research/2026-08-22-sweep/04-reference-game.md,
-- "MACHINE VERDICT/ORDER LINES" and "INTERMISSION SCORE CARD"). Two of the
-- taglines had been shipped verbatim as Kenopsia taglines until this test
-- caught them; MachineVoice.luau is a mapped file, so the comment pool is
-- grepped by the same loop.
do
	local reversed = {
		"teltnuag lesihc", "yrotcaf mraerif", "yaw gnorw", "gnitoof elbats",
		"drazah lennut", "boj edisni", "kaerb ekoms", "smroftalp sirbed",
		"rekaerb enips", "dnuober lahtel", "deifitrec tfilkrof", "retlif eht",
		"ytrap enihcam",
		-- CRT copy (P1.4)
		"pets ruoy hctaw .daeha nacs", "ti no eman ruoy htiw tellub a",
		"timbus .evrac .eziromem", "edih .tnuh .hcraes", "devres si rennid",
		"gnimoc era sniart eht", "ylekilnu si lavivrus",
		"llik ot toohs .epicer eht wollof", "egnirys eht dnif",
		"erocs noitatum eneg laitnetop", "stniop atad rotinom krowten laruen",
		"stnapicitrap tinu tset neewteb gnidivid", "ssecorp kcolb metsys noissimretni",
		"detelpmoc reppartstoob noitalumis", "stcejbus rof gnitiaw", "ylno esu lanretni",
	}
	local forbidden = {}
	local function titleCase(phrase)
		return (string.gsub(phrase, "(%a)([%w]*)", function(a, b) return string.upper(a) .. b end))
	end
	for _, r in ipairs(reversed) do
		local phrase = string.reverse(r)
		local title = titleCase(phrase)
		forbidden[#forbidden + 1] = title
		forbidden[#forbidden + 1] = string.upper(phrase)
		forbidden[#forbidden + 1] = (string.gsub(title, " ", ""))
		forbidden[#forbidden + 1] = (string.gsub(phrase, " ", ""))
		forbidden[#forbidden + 1] = (string.gsub(phrase, " ", "_"))
		forbidden[#forbidden + 1] = string.upper((string.gsub(phrase, " ", "_")))
		if string.sub(phrase, 1, 4) ~= "the " then
			forbidden[#forbidden + 1] = phrase
		end
	end
	local function offending(text)
		for _, f in ipairs(forbidden) do
			if string.find(text, f, 1, true) then return f end
		end
		return nil
	end
	local idsClean = true
	for _, id in ipairs(Playlist.Ids) do
		if offending(id) then idsClean = false end
	end
	check(idsClean, "REQ-IP-01: no forbidden token in Playlist.Ids")
	-- Self-check: the two taglines that were shipped verbatim until P1.4 must
	-- be caught in the exact form a round card would carry them.
	local caught = 0
	for _, r in ipairs({ "pets ruoy hctaw .daeha nacs", "ti no eman ruoy htiw tellub a" }) do
		if offending(string.upper(string.reverse(r)) .. ".") then caught = caught + 1 end
	end
	check(caught == 2, "REQ-IP-01: the reference's round card copy is rejected in UPPER CASE")

	local project = io.open("default.project.json", "r")
	local mapped, dirty, unreadable = 0, {}, {}
	if project then
		local json = project:read("*a")
		project:close()
		for path in string.gmatch(json, '"%$path"%s*:%s*"([^"]+)"') do
			mapped = mapped + 1
			local fh = io.open(path, "r")
			if fh then
				local body = fh:read("*a")
				fh:close()
				local hit = offending(body)
				if hit then dirty[#dirty + 1] = path .. " (" .. hit .. ")" end
			else
				unreadable[#unreadable + 1] = path
			end
		end
	end
	check(project ~= nil and mapped >= 40, "default.project.json maps every shipped file",
		string.format("mapped %d", mapped))
	check(#unreadable == 0, "every mapped path exists", table.concat(unreadable, ", "))
	check(#dirty == 0, "REQ-IP-01: no forbidden token in any shipped file", table.concat(dirty, ", "))
end

-- 2b. MP-08 FEED CONTRACT ------------------------------------------------------
--
-- 26.08.2026 (user, MP-08 S11). Nothing here can be proved by loading a pure
-- module: the promise lives in the wiring between a server that SENDS
-- kind="feed" and a client that HANDLES it. So this reads the shipped source
-- the same way the REQ-IP-01 block above does.
--
-- The promise being kept: a death belongs to the person who died. The full
-- screen card goes to them alone (tellOne), everyone else gets a feed line that
-- takes nothing away from the picture. Before MP-08, CanteenProtocol broadcast
-- that card to the whole room -- and since showAnnounce("death") pulls to solid
-- black after 2.5 s, every survivor lost sight of the observer they had to
-- watch, mid-round.

print("\nMP-08 -- the feed contract between server and client")

do
	local function read(path)
		local fh = io.open(path, "r")
		if not fh then return nil end
		local body = fh:read("*a")
		fh:close()
		return body
	end
	local SERVER = "studio-src/ServerScriptService/KenopsiaServer/Services/"
	local client = read("studio-src/StarterPlayer/StarterPlayerScripts/KenopsiaClient.client.luau")
	local canteen = read(SERVER .. "CanteenProtocol.luau")
	local minefield = read(SERVER .. "Minefield.luau")
	local machineFlow = read(SERVER .. "MachineFlow.luau")

	check(client ~= nil and canteen ~= nil and minefield ~= nil and machineFlow ~= nil,
		"MP-08: all four touched files are readable")

	if client and canteen and minefield and machineFlow then
		-- The client handles it, and does so BEFORE the screen funnel. A feed
		-- line is an overlay, not a screen: routing it through the funnel would
		-- bump `session` and cancel whatever typewriter is running under it.
		local feedAt = string.find(client, 'p.kind == "feed"', 1, true)
		local funnelAt = string.find(client, "if not K.KNOWN_KINDS[p.kind] then", 1, true)
		check(feedAt ~= nil, 'client dispatches kind="feed"')
		check(feedAt ~= nil and funnelAt ~= nil and feedAt < funnelAt,
			'the feed branch is caught BEFORE the screen funnel (no session bump)')
		check(not string.find(client, "KNOWN_KINDS = {[^}]*feed"),
			"feed stays OUT of K.KNOWN_KINDS -- it is not a screen")

		-- B-02: the death card is no longer broadcast to the whole canteen.
		check(not string.find(canteen, 'announce%(st%.room, { kind = "announce", style = "death"'),
			"CanteenProtocol no longer broadcasts the death card to the room")
		check(string.find(canteen, 'tellOne%(userId, { kind = "announce", style = "death"') ~= nil,
			"CanteenProtocol sends the death card to the dead subject alone")
		check(string.find(canteen, 'kind = "feed"', 1, true) ~= nil,
			"CanteenProtocol tells the rest of the room by feed line")

		-- B-01 / B-06: nobody starts crawling without being told, and being told
		-- costs them no picture. The two rings were separate branches running
		-- identical statements; MP-08 merged them, so the invariant is stated as
		-- "every latch of ps.crawling is paired with a crawl feed line" rather
		-- than as a branch count -- that survives the next restructure.
		local latches, crawlLines = 0, 0
		for _ in string.gmatch(minefield, "ps%.crawling = true") do latches = latches + 1 end
		for _ in string.gmatch(minefield, 'kind = "feed", style = "warn", text = "LEGS GONE') do
			crawlLines = crawlLines + 1
		end
		check(latches >= 1 and crawlLines == latches,
			"every crawl latch in Minefield is announced by a feed line",
			string.format("%d latches, %d feed lines", latches, crawlLines))
		check(not string.find(minefield, 'kind = "announce", style = "warn"'),
			"the crawl hint is no longer a full-screen card")
		-- B-03 companion: BirdHunting called tellOne() without ever defining it,
		-- so the spectate packet for a killed runner died as an undefined global
		-- and viewer mode there never ran at all.
		check(string.find(minefield, "local function tellOne", 1, true) ~= nil,
			"Minefield defines tellOne")

		-- B-08: showAnnounce was the only screen function that never took itself
		-- down. Every STYLED card -- death, win, warn -- now says how long it
		-- stands, because those are the ones that interrupt a running round and
		-- have nothing following them to clear the glass.
		--
		-- Deliberately not every card: the plain ones ("MARK THE GROUND...",
		-- "EAT EVERYTHING...") open a round and are cleared by the 3-2-1 that
		-- follows them, which calls hideAll() on n == 3. A seconds field there
		-- would only be a second, competing timer.
		local styled, timed, untimed = 0, 0, {}
		for _, body in ipairs({ canteen, minefield }) do
			for call in string.gmatch(body, 'kind = "announce", style = [^}]*') do
				styled = styled + 1
				if string.find(call, "seconds =", 1, true) then
					timed = timed + 1
				else
					untimed[#untimed + 1] = string.sub(call, 1, 46)
				end
			end
		end
		check(styled > 0 and styled == timed,
			"every styled announce card in Canteen/Minefield carries seconds (self-teardown)",
			string.format("%d of %d timed: %s", timed, styled, table.concat(untimed, " | ")))
		check(string.find(client, "local secs = tonumber(p.seconds)", 1, true) ~= nil,
			"showAnnounce honours p.seconds")

		-- B-01: the spectate branch clears the glass before taking the camera.
		local specAt = string.find(client, 'if p.role == "spectate" then', 1, true)
		local hideAt = specAt and string.find(client, "hideAll()", specAt, true)
		local faderAt = specAt and string.find(client, "faderFrame.BackgroundColor3", specAt, true)
		check(specAt ~= nil and hideAt ~= nil and faderAt ~= nil and hideAt < faderAt,
			"the spectate branch calls hideAll() before it sets the camera")

		-- B-03: a dead runner keeps the spectate camera until the leg ends --
		-- and, first of all, actually receives it.
		local bird = read(SERVER .. "BirdHunting.luau")
		check(bird ~= nil and string.find(bird, "clearParticipant(plr.UserId, s, true)", 1, true) ~= nil,
			"BirdHunting drops a killed runner without ending their viewer mode")
		check(bird ~= nil and string.find(bird, "local function tellOne", 1, true) ~= nil,
			"BirdHunting defines the tellOne its spectate packet calls")

		-- S9: the roulette runs between trials, on the shared icon builder.
		check(string.find(machineFlow, "local function iconsFor(trial)", 1, true) ~= nil,
			"MachineFlow exposes iconsFor(trial)")
		check(string.find(machineFlow, "Pacing.Timing.TrialReveal", 1, true) ~= nil,
			"the trial loop holds on Pacing.Timing.TrialReveal")

		-- S8 (26.08.2026, user decision): the crawl speed must stay INSIDE the
		-- compactor's own speed band. The machine is clamped to
		-- [MIN_SHRED_SPEED, MAX_SHRED_SPEED]; a crawler above the upper clamp can
		-- never be caught, whatever the number looks like, and the maiming stops
		-- costing time. This is the whole reason 6.0 was chosen over 10, and it
		-- is a single edit away from being undone silently.
		local minShred = tonumber(string.match(minefield, "local MIN_SHRED_SPEED = ([%d%.]+)"))
		local maxShred = tonumber(string.match(minefield, "local MAX_SHRED_SPEED = ([%d%.]+)"))
		local crawl = tonumber(string.match(minefield, "local CRAWL_SPEED = ([%d%.]+)"))
		check(minShred ~= nil and maxShred ~= nil and crawl ~= nil,
			"Minefield states MIN_SHRED_SPEED, MAX_SHRED_SPEED and CRAWL_SPEED")
		if minShred and maxShred and crawl then
			check(crawl == 6.0, "CRAWL_SPEED is 6.0", tostring(crawl))
			check(crawl <= maxShred,
				"a crawler stays catchable: CRAWL_SPEED <= MAX_SHRED_SPEED",
				string.format("crawl %s vs machine cap %s", tostring(crawl), tostring(maxShred)))
			check(crawl > minShred,
				"but the crawl still beats the machine's floor, so it is not a death sentence",
				string.format("crawl %s vs machine floor %s", tostring(crawl), tostring(minShred)))
		end
		-- The client half of the same decision: the 7 -> 10 runner ramp must keep
		-- its crawl exception, or it would lift a 6.0 crawler straight past the
		-- compactor's cap on the first frame they move.
		check(string.find(client, 'if char:GetAttribute("XBotCrawl") == true then runT = 0 return end', 1, true) ~= nil,
			"the runner ramp still exempts a crawler")
		check(string.find(client, 'if char:GetAttribute("XBotCrawl") ~= true then', 1, true) ~= nil,
			"applyMovement still leaves a crawler's WalkSpeed to the server")

		-- 26.08.2026 (user): the Canteen corpse stays parked at the table until
		-- the round is cleaned up. Killing the Humanoid handed the body to
		-- Roblox's auto-respawn, which destroyed it five seconds later.
		-- Line-anchored on purpose: the comment that replaced this line QUOTES it,
		-- so a plain substring search would match the explanation and never fail.
		check(not string.find(canteen, "\n[ \t]*subject%.hum%.Health = 0"),
			"CanteenProtocol no longer kills the Humanoid on elimination")
		check(string.find(canteen, 'SetAttribute("KenopsiaProcessed"', 1, true) ~= nil,
			"CanteenProtocol reports the death through KenopsiaProcessed instead")
		check(string.find(canteen, "subject.root.Anchored = true", 1, true) ~= nil,
			"the eliminated subject is frozen in place")

		-- 26.08.2026 (user): der Raum erzaehlt, nicht das HUD. Die beiden
		-- Observer-Untertitel sind raus -- der Observer senkt sich sichtbar,
		-- sein Gesicht springt auf Angry und er schwenkt gestuft; ein Text
		-- darueber sagt dem Spieler, er solle aufs HUD schauen statt an den Tisch.
		-- Auf die ZUWEISUNG geprueft, nicht auf den Text: der Kommentar, der die
		-- Entfernung begruendet, zitiert beide Zeilen -- eine reine Textsuche
		-- wuerde also die Erklaerung finden und nie fehlschlagen.
		check(not string.find(client, '%.Text = "OBSERVER DESCENDING"'),
			"the OBSERVER DESCENDING subtitle is no longer written to a label")
		check(not string.find(client, '%.Text = "OBSERVED'),
			"the OBSERVED - DO NOT SWALLOW subtitle is no longer written to a label")
		-- Die Urteile bleiben: das sind Ergebnisse, keine Erzaehlung.
		check(string.find(client, "PROTOCOL VIOLATION", 1, true) ~= nil
			and string.find(client, "RATION COMPLETE", 1, true) ~= nil,
			"the outcome lines (violation / ration complete) are kept")

		-- Der Prompt darf nicht ins Messer schicken: unter Beobachtung ist
		-- Schlucken die eine toedliche Handlung, und das HUD forderte sie an.
		check(string.find(client, "cpApplyPrompt", 1, true) ~= nil,
			"the eat prompt is decided in one place (cpApplyPrompt)")
		check(string.find(client, 'watched and "HOLD" or "EAT"', 1, true) ~= nil,
			"a watched player is told to HOLD, never to EAT")
		local promptCalls = 0
		for _ in string.gmatch(client, "cpApplyPrompt%(%)") do promptCalls = promptCalls + 1 end
		check(promptCalls >= 2, "both the fork and the observer refresh the prompt",
			tostring(promptCalls) .. " call sites")

		-- Der Tisch haelt die Luft an, solange der Observer oben ist.
		local diner = read(SERVER .. "CanteenDiner.luau")
		local props = read(SERVER .. "CanteenProps.luau")
		check(diner ~= nil and string.find(diner, "function CanteenDiner.hold", 1, true) ~= nil,
			"CanteenDiner can hold its breath")
		check(diner ~= nil and string.find(diner, "if not self.held then", 1, true) ~= nil,
			"the blink loop skips instead of terminating, so no second thread is spawned")
		check(props ~= nil and string.find(props, "pcall(diner.hold, diner, up)", 1, true) ~= nil,
			"observerTo puts the whole table on hold")
		-- Und der Tod ist wieder der AUTORISIERTE Clip, keine gerechnete Pose.
		check(diner ~= nil and string.find(diner, 'AnimationIds.load(animator, "Player", "Death")', 1, true) ~= nil,
			"the diner plays the authored Death clip again")
		check(diner ~= nil and not string.find(diner, "local function slump", 1, true),
			"no custom slump pose left")

		-- 26.08.2026 (user): no dance in CANTEEN PROTOCOL, on any platform. The
		-- trial-scoped attribute is what makes that hold BETWEEN a trial's rounds.
		local ps1 = read("studio-src/StarterPlayer/StarterCharacterScripts/PS1Animate.client.luau")
		check(machineFlow ~= nil and string.find(machineFlow, "local function setTrialId(ctx, trialId)", 1, true) ~= nil,
			"MachineFlow publishes a trial-scoped KenopsiaTrialId")
		check(ps1 ~= nil and string.find(ps1, "local function danceBlocked()", 1, true) ~= nil,
			"PS1Animate routes every dance path through one danceBlocked()")
		if ps1 then
			local guards = 0
			for _ in string.gmatch(ps1, "danceBlocked%(%)") do guards = guards + 1 end
			-- definition + animation + key/gamepad + touch button + stop-on-enter
			check(guards >= 5, "danceBlocked guards the key, the button and the clip",
				tostring(guards) .. " uses")
		end
	end
end

-- 3. SCORING -----------------------------------------------------------------

print("\nSCORING -- every tie shape sums to exactly 1700")

-- Tie shapes are the compositions of n: (3) is all-tied, (1,2) is one clear
-- winner then two tied, and so on. 2^(n-1) shapes per player count, 14 in all.
local function compositions(n)
	local out = {}
	local function walk(remaining, acc)
		if remaining == 0 then
			local copy = {}
			for i, v in ipairs(acc) do copy[i] = v end
			out[#out + 1] = copy
			return
		end
		for size = 1, remaining do
			acc[#acc + 1] = size
			walk(remaining - size, acc)
			acc[#acc] = nil
		end
	end
	walk(n, {})
	return out
end

local shapeCount = 0
for n = 2, 4 do
	for _, shape in ipairs(compositions(n)) do
		-- Build scores that produce exactly this tie shape.
		local entries, score = {}, 100
		for _, groupSize in ipairs(shape) do
			for _ = 1, groupSize do
				entries[#entries + 1] = { score = score }
			end
			score = score - 10
		end

		local ranking = Scoring.rankRound(entries, function(a, b) return a.score > b.score end)
		Scoring.distribute(ranking)

		local sum = 0
		for _, r in ipairs(ranking) do sum = sum + r.points end

		-- Tied players must not drift apart by more than the single point the
		-- exact-total rule forces. Zero would be ideal and is impossible for
		-- some shapes -- three players all tied cannot split 1700 evenly.
		local worstSpread = 0
		local i = 1
		while i <= #ranking do
			local j = i
			local lo, hi = ranking[i].points, ranking[i].points
			while j < #ranking and ranking[j + 1].from == ranking[i].from do
				j = j + 1
				if ranking[j].points < lo then lo = ranking[j].points end
				if ranking[j].points > hi then hi = ranking[j].points end
			end
			if hi - lo > worstSpread then worstSpread = hi - lo end
			i = j + 1
		end

		shapeCount = shapeCount + 1
		check(sum == Scoring.Pool and worstSpread <= 1,
			string.format("%dp shape (%s) -> sum %d, tie spread %d",
				n, table.concat(shape, "+"), sum, worstSpread),
			string.format("expected sum %d and spread <= 1", Scoring.Pool))
	end
end
check(shapeCount == 14, "all 14 tie shapes covered", string.format("got %d", shapeCount))

-- Ordering sanity: a clear winner must never score below a clear loser.
local ranking = Scoring.distribute(Scoring.rankRound(
	{ { score = 1 }, { score = 9 }, { score = 5 }, { score = 3 } },
	function(a, b) return a.score > b.score end))
local monotone = true
for i = 2, #ranking do
	if ranking[i].points > ranking[i - 1].points then monotone = false end
end
check(monotone, "points never increase down the ranking")
check(ranking[1].entry.score == 9, "the highest scorer ranks first")

-- SUMMARY --------------------------------------------------------------------

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("GATE 1 RULES PROOF: FAIL")
	os.exit(1)
end
print("GATE 1 RULES PROOF: PASS")
os.exit(0)
