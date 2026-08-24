-- MAIN MENU offline proof. Run from the repo root:
--
--     lua tests/menu.lua
--
-- Loads the SHIPPED Shared/Config/MenuConfig.luau (no copy) in plain Lua 5.1
-- and proves what the menu says and where its parts sit: the palette is
-- complete and WHITE stays reserved for the streak, the four entries are the
-- ones the design settled on and each carries a detail card, the row/streak
-- geometry never overlaps, the boot sequence fits its budget and lands on
-- FeelConfig's step grid, the briefing pages fill BriefList exactly, every
-- personnel row that claims an attribute names one the server actually sets,
-- and the helpers (spacing, wrapping, designation, clock) behave.
--
-- Exit code is 0 only if every check passes, so this is usable as a gate.

local FILE = "studio-src/ReplicatedStorage/Kenopsia/Shared/Config/MenuConfig.luau"
local FEEL = "studio-src/ReplicatedStorage/Kenopsia/Shared/Config/FeelConfig.luau"

local function loadModule(file)
	local chunk = assert(loadfile(file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local Menu = loadModule(FILE)
local Feel = loadModule(FEEL)

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

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

print("MenuConfig loads in plain Lua")
check(type(Menu) == "table", "module returns a table")
check(rawget(_G, "Enum") == nil, "no Roblox global leaked at load (Enum untouched)")
check(type(Menu.Palette) == "table" and type(Menu.Entries) == "table" and type(Menu.Layout) == "table",
	"Palette / Entries / Layout sections present")

print("Palette")
local NEEDED = { "BG", "PLATE", "CYAN", "CYAN_HI", "CYAN_DIM", "WHITE", "INK", "ACCENT" }
for _, key in ipairs(NEEDED) do
	local v = Menu.Palette[key]
	check(type(v) == "string" and #v == 6 and string.match(v, "^%x%x%x%x%x%x$") ~= nil,
		"palette." .. key .. " is a 6-digit hex", tostring(v))
end
-- WHITE is the streak's alone, the way #FF1818 is FIRE/PUNCH's alone in the
-- machine palette: nothing else may be pure white or the bar stops reading.
local whites = 0
for _, key in ipairs(NEEDED) do
	if string.upper(Menu.Palette[key]) == "FFFFFF" then whites = whites + 1 end
end
check(whites == 1 and string.upper(Menu.Palette.WHITE) == "FFFFFF", "pure white is reserved for the streak")
-- The menu must not be the phosphor green of the machine screens: that colour
-- break is the whole point of the cold palette.
local GREENS = { ["78FFAA"] = true, ["8CE8AE"] = true, ["2E6B4A"] = true }
local greenHits = 0
for _, key in ipairs(NEEDED) do
	if GREENS[string.upper(Menu.Palette[key])] then greenHits = greenHits + 1 end
end
check(greenHits == 0, "no machine phosphor leaked into the cold palette")

print("Entries")
check(#Menu.Entries == 4, "four entries", tostring(#Menu.Entries))
local EXPECT = { "enter", "briefing", "settings", "personnel" }
for i, id in ipairs(EXPECT) do
	local e = Menu.Entries[i]
	check(e ~= nil and e.id == id, "entry " .. i .. " is " .. id, e and tostring(e.id) or "nil")
end
for _, e in ipairs(Menu.Entries) do
	check(type(e.label) == "string" and #e.label > 0, "entry " .. e.id .. " has a label")
	check(string.upper(e.label) == e.label, "entry " .. e.id .. " label is uppercase (machine voice)", e.label)
	check(type(e.detail) == "table" and #e.detail >= 2 and #e.detail <= 4,
		"entry " .. e.id .. " detail card has 2-4 lines", e.detail and tostring(#e.detail) or "nil")
	for _, line in ipairs(e.detail) do
		check(#line <= 30, "entry " .. e.id .. " detail line fits the card (<= 30)", line)
	end
end
check(Menu.indexOf("settings") == 3, "indexOf finds an entry")
check(Menu.indexOf("nope") == nil, "indexOf returns nil for an unknown id")

print("Selection wrapping")
check(Menu.step(1, -1) == 4, "up from the first entry wraps to the last")
check(Menu.step(4, 1) == 1, "down from the last entry wraps to the first")
check(Menu.step(2, 1) == 3 and Menu.step(3, -1) == 2, "plain moves")
check(Menu.step(1, -9) >= 1 and Menu.step(1, -9) <= 4, "a large negative delta stays in range")
check(Menu.step(4, 9) >= 1 and Menu.step(4, 9) <= 4, "a large positive delta stays in range")

print("Row and streak geometry")
for _, mobile in ipairs({ false, true }) do
	local tag = mobile and " (mobile)" or ""
	local h = mobile and Menu.Mobile.RowH or Menu.Layout.RowH
	check(near(Menu.rowY(1, mobile), 0), "row 1 sits at the top of the frame" .. tag)
	local gap = Menu.rowY(2, mobile) - Menu.rowY(1, mobile) - h
	check(near(gap, Menu.Layout.RowGap), "rows are RowGap apart" .. tag, tostring(gap))
	-- the streak overhangs its row, centred, and must not reach the neighbours
	local sh = Menu.streakH(mobile)
	check(sh > h, "streak is taller than its row" .. tag)
	check(near(Menu.streakY(1, mobile) + sh / 2, Menu.rowY(1, mobile) + h / 2),
		"streak is centred on its row" .. tag)
	local overhang = (sh - h) / 2
	check(overhang < Menu.Layout.RowGap, "streak overhang stays inside the row gap" .. tag,
		string.format("%.2f vs %d", overhang, Menu.Layout.RowGap))
	check(Menu.streakY(2, mobile) > Menu.rowY(1, mobile) + h, "streak on row 2 clears row 1" .. tag)
end
check(Menu.Layout.StreakW > Menu.Layout.RowW, "streak is wider than the row (torn ends show)")
check(Menu.Mobile.StreakW > Menu.Mobile.RowW, "mobile streak is wider than the mobile row")
check(Menu.Layout.StreakX < 0, "streak starts left of the row")
check(Menu.Layout.RowTextX > Menu.Layout.BulletX, "the label clears the bullet marker")

print("Touch floor")
-- The user called the mobile UI too large once and unreachable buttons twice:
-- 44 pt is Roblox's own floor and the rows must clear it before scaling.
check(Menu.Mobile.RowH >= 44, "mobile rows are at least 44 pt", tostring(Menu.Mobile.RowH))
check(Menu.Mobile.RowTextSize >= 18, "mobile label stays legible", tostring(Menu.Mobile.RowTextSize))
check(Menu.Mobile.TitleW < Menu.Layout.TitleW, "the wordmark is trimmed on a phone")
check(Menu.Mobile.Cells < 3, "a phone shows fewer status cells")

print("Boot sequence")
local B = Menu.Boot
local step = Feel.stepSeconds()
check(B.Dither < B.Chrome and B.Chrome < B.Title and B.Title < B.Rows and B.Rows < B.Streak
	and B.Streak < B.Hint, "beats are strictly ordered")
-- Beats are counted in STEPS, so landing on the grid is structural: the only
-- thing to prove is that they really are whole steps.
for _, key in ipairs({ "Dither", "Chrome", "Title", "Rows", "Streak", "Hint", "RowStagger" }) do
	local v = B[key]
	check(type(v) == "number" and v >= 0 and v == math.floor(v), "Boot." .. key .. " is a whole step count",
		tostring(v))
end
check(B.RowStagger >= 1, "the row stagger is at least one step (a 0 would fire them all together)")
check(Menu.bootSeconds(step) <= B.Budget, "the whole assembly fits the budget",
	string.format("%.2f s vs %.2f s", Menu.bootSeconds(step), B.Budget))
-- The rows must finish typing before the streak lands on the first one.
local rowsDone = B.Rows + (#Menu.Entries - 1) * B.RowStagger
check(rowsDone <= B.Streak, "every row is up before the streak arrives",
	string.format("%d vs %d steps", rowsDone, B.Streak))

print("Motion constants")
check(Menu.Streak.Steps >= 1 and Menu.Streak.Steps <= 3, "streak travel is 1-3 steps",
	tostring(Menu.Streak.Steps))
check(Menu.Streak.Steps * step <= Feel.MaxMotion, "streak travel respects MaxMotion",
	string.format("%.3f s", Menu.Streak.Steps * step))
check(Menu.Streak.OvershootPx > 0, "the streak overshoots before it settles")
check(Menu.Title.ChromaSteps * step <= Feel.MaxMotion, "title chroma split respects MaxMotion")
check(Menu.Title.PunchScale > 1 and Menu.Title.PunchScale <= 1.15, "title punch is a nudge, not a zoom",
	tostring(Menu.Title.PunchScale))
check(Menu.Idle.ParallaxPeriod >= 4 and Menu.Idle.DollyPeriod >= 10,
	"idle oscillators are slow enough to read as ambient")
-- Decorrelated: two idle periods that divide each other would visibly beat.
check(Menu.Idle.DollyPeriod % Menu.Idle.ParallaxPeriod ~= 0,
	"parallax and dolly periods do not fall in step",
	string.format("%s / %s", tostring(Menu.Idle.DollyPeriod), tostring(Menu.Idle.ParallaxPeriod)))

print("Diorama")
local D = Menu.Diorama
check(#D.Origin == 3 and D.Origin[2] > 1000, "the set sits far above the arenas",
	table.concat({ tostring(D.Origin[1]), tostring(D.Origin[2]), tostring(D.Origin[3]) }, ","))
check(D.Cam.dz > 0 and D.Cam.dy > 0, "the camera stands in front of and above the set")
check(D.Shell.d > D.Cam.dz and D.Shell.w > D.Ground.w,
	"the shell encloses the camera and the ground (no default sky can show)")
check(D.Fov >= 40 and D.Fov <= 70, "field of view is sane", tostring(D.Fov))
check(D.FenceCount + D.CrateCount + 8 <= 20, "the set stays inside its 20-part budget")

print("Briefing")
check(#Menu.Briefing == 2, "two pages", tostring(#Menu.Briefing))
for i, page in ipairs(Menu.Briefing) do
	check(type(page.title) == "string" and #page.title > 0, "page " .. i .. " has a title")
	-- BriefList in the place holds exactly five rows; a sixth would be dropped
	-- silently and a fourth would leave a hole.
	check(#page.lines == 5, "page " .. i .. " fills BriefList exactly (5 rows)", tostring(#page.lines))
	for _, line in ipairs(page.lines) do
		check(#line <= 48, "briefing line fits the row (<= 48)", line)
		check(string.upper(line) == line, "briefing line is uppercase (machine voice)", line)
	end
end
-- REQ-IP-01: no reference-game vocabulary in shipped copy.
local BANNED = { "machine party", "hopeless", "bombs", "checkerboard" }
for _, page in ipairs(Menu.Briefing) do
	for _, line in ipairs(page.lines) do
		for _, word in ipairs(BANNED) do
			check(string.find(string.lower(line), word, 1, true) == nil,
				"briefing avoids reference copy: " .. word, line)
		end
	end
end

print("Personnel file")
check(#Menu.Personnel >= 5, "the file has enough rows to look like a record")
-- Every attribute named here has to be one the server actually writes, or the
-- row renders blank forever. These four are set in MachineFlow.
local SERVER_ATTRS = {
	KenopsiaSessionScore = true,
	KenopsiaSessionWins = true,
	KenopsiaProcessed = true,
	KenopsiaJoinedAt = true,
}
for _, row in ipairs(Menu.Personnel) do
	check(type(row.label) == "string" and #row.label > 0, "personnel row has a label")
	if row.attr ~= nil then
		check(SERVER_ATTRS[row.attr] == true, "personnel row reads a server-set attribute", tostring(row.attr))
		check(type(row.format) == "string", "an attribute row carries a format", tostring(row.label))
	end
end

print("Helpers")
check(Menu.spaced("READY") == "R E A D Y", "spaced() letter-spaces like Btn_READY", Menu.spaced("READY"))
check(Menu.spaced("A B") == "A   B", "spaced() keeps the word break", "[" .. Menu.spaced("A B") .. "]")
check(Menu.spaced("") == "", "spaced() survives an empty string")
check(Menu.designation(0) == "S-0000", "designation of 0", Menu.designation(0))
check(Menu.designation(11273446244) == "S-6244", "designation takes the last four digits",
	Menu.designation(11273446244))
check(Menu.designation(-7) == "S-0007", "designation ignores the sign", Menu.designation(-7))
check(Menu.designation(nil) == "S-0000", "designation survives a nil id", Menu.designation(nil))
check(Menu.clock(0) == "00:00:00", "clock zero", Menu.clock(0))
check(Menu.clock(3661) == "01:01:01", "clock hours/minutes/seconds", Menu.clock(3661))
check(Menu.clock(-5) == "00:00:00", "clock never goes negative", Menu.clock(-5))
check(Menu.clock(59.9) == "00:00:59", "clock floors", Menu.clock(59.9))

print("Images")
for name, img in pairs(Menu.Images) do
	check(type(img.w) == "number" and type(img.h) == "number" and img.w > 0 and img.h > 0,
		"image " .. name .. " declares its authored size")
	-- Authored small on purpose: a magnified Pixelated source is crisp, a
	-- minified one aliases. Nothing here may be bigger than what it draws.
	check(img.w <= 512 and img.h <= 512, "image " .. name .. " is authored small",
		string.format("%dx%d", img.w, img.h))
	check(type(img.id) == "string", "image " .. name .. " has an id field (may be empty pre-upload)")
end

print("")
print(string.format("%d checks, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
os.exit(0)
