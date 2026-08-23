-- P2.4 Glyphs offline proof. Run from the repo root:
--
--     lua tests/glyphs.lua
--
-- Loads the SHIPPED StarterPlayerScripts/Glyphs.luau (no copy) in plain Lua
-- 5.1 with a fake resolver in place of UserInputService and proves: the
-- action map covers Desktop / Console / Touch, keyboard keys come from the
-- (layout-aware) string resolver, gamepad keys from the image resolver with
-- a text fallback, touch shows the pad label, every visible text follows the
-- Machine voice, the input-mode hysteresis (gamepad after the hold, click at
-- once, mouse move never), the composed console signal, and that the live
-- layout script no longer leans on IsTenFootInterface alone.
--
-- Exit code is 0 only if every check passes, so this is usable as a gate.

local FILE = "studio-src/StarterPlayer/StarterPlayerScripts/Glyphs.luau"
local FEEL = "studio-src/ReplicatedStorage/Kenopsia/Shared/Config/FeelConfig.luau"
local LAYOUT = "studio-src/StarterPlayer/StarterPlayerScripts/MachineLayout.client.luau"
local CLIENT = "studio-src/StarterPlayer/StarterPlayerScripts/KenopsiaClient.client.luau"

local function loadModule(file)
	local chunk = assert(loadfile(file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local Glyphs = loadModule(FILE)
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

local function readFile(path)
	local fh = io.open(path, "r")
	if not fh then return nil end
	local body = fh:read("*a")
	fh:close()
	return body
end

-- A fake UserInputService: an AZERTY keyboard (W -> Z, A -> Q) and one image
-- per gamepad button; nothing for the d-pad so the text fallback is exercised.
local AZERTY = { W = "z", A = "q", S = "s", D = "d", F = "f" }
local calls = { image = {}, string = {} }
local resolver = {
	image = function(key)
		calls.image[#calls.image + 1] = key
		if string.sub(key, 1, 4) == "DPad" then return "" end
		return "rbxasset://textures/ui/Controls/" .. key .. ".png"
	end,
	string = function(key)
		calls.string[#calls.string + 1] = key
		return AZERTY[key] or ""
	end,
}

-- 1. LOAD --------------------------------------------------------------------

print("\nGLYPHS -- module")
check(type(Glyphs) == "table" and type(Glyphs.Actions) == "table", "module returns a table with Actions")
check(rawget(_G, "Enum") == nil, "no Roblox global leaked at load (Enum untouched)")
check(Glyphs.platformFor("Console") == "Console" and Glyphs.platformFor("Mobile") == "Touch"
	and Glyphs.platformFor("Tablet") == "Touch" and Glyphs.platformFor("Desktop") == "Desktop"
	and Glyphs.platformFor(nil) == "Desktop", "platformFor maps MachineLayout's Platform attribute")

-- 2. ACTION MAP --------------------------------------------------------------

print("\nGLYPHS -- action map")
local required = { "Confirm", "Back", "Move", "Crouch", "Aim", "Fire", "Scope", "Zoom", "Scan", "Load", "Swallow",
	"LookLeft", "LookRight" }
local missing = {}
for _, a in ipairs(required) do
	if not Glyphs.Actions[a] then missing[#missing + 1] = a end
end
check(#missing == 0, "every client action has a row", table.concat(missing, ","))

local shapeBad, touchBad, consoleBad = {}, {}, {}
for name, row in pairs(Glyphs.Actions) do
	for _, p in ipairs(Glyphs.Platforms) do
		local b = row[p]
		if type(b) ~= "table" or not (b.key or b.keys or b.text) then shapeBad[#shapeBad + 1] = name .. "." .. p end
	end
	local t = row.Touch
	if not (t and type(t.text) == "string" and t.text == string.upper(t.text) and not string.find(t.text, "!", 1, true)) then
		touchBad[#touchBad + 1] = name
	end
	local c = row.Console
	local keys = c and (c.keys or { c.key }) or {}
	for _, k in ipairs(keys) do
		if not (string.sub(k, 1, 6) == "Button" or string.sub(k, 1, 10) == "Thumbstick" or string.sub(k, 1, 4) == "DPad") then
			consoleBad[#consoleBad + 1] = name .. ":" .. tostring(k)
		end
	end
end
check(#shapeBad == 0, "every action has Desktop / Console / Touch (key | keys | text)", table.concat(shapeBad, ","))
check(#touchBad == 0, "touch shows an uppercase pad label, no exclamation mark", table.concat(touchBad, ","))
check(#consoleBad == 0, "console rows are gamepad KeyCodes only", table.concat(consoleBad, ","))

-- the bindings KenopsiaClient listens to
check(Glyphs.Actions.Crouch.Desktop.key == "LeftControl" and Glyphs.Actions.Crouch.Console.key == "ButtonB",
	"crouch: LeftControl / ButtonB")
check(Glyphs.Actions.Scan.Desktop.key == "F" and Glyphs.Actions.Scan.Console.key == "ButtonY", "sonar: F / ButtonY")
check(Glyphs.Actions.Fire.Console.key == "ButtonR2" and Glyphs.Actions.Scope.Console.key == "ButtonL2",
	"fire / scope: RT / LT")
check(Glyphs.Actions.Load.Console.key == "ButtonL2" and Glyphs.Actions.Swallow.Console.key == "ButtonR2",
	"canteen load / swallow: LT / RT")
check(Glyphs.Actions.Confirm.Console.key == "ButtonA", "confirm is the A button")
check(Glyphs.Actions.Fire.Touch.text == "FIRE" and Glyphs.Actions.Scope.Touch.text == "SCOPE"
	and Glyphs.Actions.Crouch.Touch.text == "CROUCH" and Glyphs.Actions.Scan.Touch.text == "SCAN"
	and Glyphs.Actions.Load.Touch.text == "PLATE" and Glyphs.Actions.Swallow.Touch.text == "MOUTH",
	"touch labels are the TouchControls button names (FIRE SCOPE CROUCH SCAN PLATE MOUTH)")

-- 3. RENDERING ---------------------------------------------------------------

print("\nGLYPHS -- rendering")
check(Glyphs.text("Move  [{Move}]", "Desktop", resolver) == "Move  [Z Q S D]",
	"desktop keys come from the string resolver (AZERTY shows Z Q S D)",
	Glyphs.text("Move  [{Move}]", "Desktop", resolver))
check(Glyphs.text("Crouch [{Crouch}]", "Desktop", resolver) == "Crouch [CTRL]",
	"non-printable keys use the KeyText table (CTRL)")
check(Glyphs.text("{Fire} / {Zoom}", "Desktop", resolver) == "LMB / WHEEL", "mouse buttons and the wheel are fixed text")
check(Glyphs.text("{Scan}", "Desktop", resolver) == "F", "a printable key is uppercased")
check(Glyphs.text("{Crouch} button", "Touch", resolver) == "CROUCH button", "touch shows the pad label")
check(Glyphs.text("{LookLeft}", "Touch", resolver) == "TAP BAR", "touch look hint is TAP BAR")

local segs = Glyphs.segments("{Crouch}  Crouch", "Console", resolver)
check(#segs == 2 and segs[1].image == "rbxasset://textures/ui/Controls/ButtonB.png" and segs[1].text == "B"
	and segs[2].text == "  Crouch", "console: an image segment with its alt text, then the text")
check(Glyphs.hasImage(segs) and not Glyphs.hasImage(Glyphs.segments("{Crouch}", "Desktop", resolver)),
	"hasImage is true only for console image rows")
check(Glyphs.join(segs) == "B  Crouch", "join falls back to the alt text")
local dpad = Glyphs.segments("{LookLeft} / {LookRight}", "Console", resolver)
check(#dpad == 3 and dpad[1].image == nil and dpad[1].text == "DPAD LEFT" and dpad[3].text == "DPAD RIGHT",
	"console: an empty image falls back to the ButtonText table")
local two = Glyphs.segments("{Aim}  Aim  +  {Fire}  Shoot", "Console", resolver)
local images = 0
for _, s in ipairs(two) do if s.image then images = images + 1 end end
check(images == 2, "two tokens in one line give two images")
check(Glyphs.text("{Nope} x", "Desktop", resolver) == "NOPE x", "an unknown action prints its name in capitals")
check(Glyphs.text("plain", "Console", resolver) == "plain" and Glyphs.text("", "Console", resolver) == "",
	"lines without tokens pass through")
check(Glyphs.text("{Move}", "Console", {}) == "LS" and Glyphs.text("{Move}", "Desktop", {}) == "W A S D",
	"no resolver: ButtonText / KeyCode names")
check(#calls.image > 0 and #calls.string > 0, "both resolver calls were exercised")

print("\nGLYPHS -- look hint and Machine voice")
for _, p in ipairs(Glyphs.Platforms) do
	local line = Glyphs.text(Glyphs.LookHint[p], p, resolver)
	check(type(line) == "string" and #line > 0 and line == string.upper(line) and not string.find(line, "!", 1, true),
		"LookHint." .. p .. " is uppercase with no exclamation mark", line)
end
check(Glyphs.text(Glyphs.LookHint.Desktop, "Desktop", resolver) == "CLICK BAR     LEFT / RIGHT",
	"desktop look hint names the arrow keys")
local voiceBad = {}
for _, tbl in ipairs({ Glyphs.KeyText, Glyphs.ButtonText }) do
	for k, v in pairs(tbl) do
		if v ~= string.upper(v) or string.find(v, "!", 1, true) then voiceBad[#voiceBad + 1] = k end
	end
end
check(#voiceBad == 0, "KeyText / ButtonText are uppercase, no exclamation marks", table.concat(voiceBad, ","))

-- 4. HYSTERESIS --------------------------------------------------------------

print("\nGLYPHS -- input-mode hysteresis")
check(type(Feel.Input) == "table" and Feel.Input.GamepadHoldSeconds == 2, "Feel.Input.GamepadHoldSeconds is 2 s",
	tostring(Feel.Input and Feel.Input.GamepadHoldSeconds))
check(Glyphs.classify("Gamepad1") == "Gamepad" and Glyphs.classify("Gamepad4") == "Gamepad"
	and Glyphs.classify("MouseMovement") == "Move" and Glyphs.classify("MouseButton1") == "Pointer"
	and Glyphs.classify("MouseWheel") == "Pointer" and Glyphs.classify("Keyboard") == "Pointer"
	and Glyphs.classify("Touch") == "Touch" and Glyphs.classify("Focus") == nil and Glyphs.classify(nil) == nil,
	"classify: gamepads, mouse move, pointer, touch, ignored")

local HOLD = Feel.Input.GamepadHoldSeconds
local t = Glyphs.newInputTracker(HOLD)
check(t.mode == nil, "fresh tracker is undecided")
check(t.feed("Gamepad1", 0) ~= "Gamepad", "a gamepad press does not flip at once")
check(t.evaluate(HOLD - 0.1) ~= "Gamepad", "still not at hold - 0.1 s")
check(t.pending(HOLD - 0.5) and math.abs(t.pending(HOLD - 0.5) - 0.5) < 1e-9, "pending reports the time left on the hold")
check(t.evaluate(HOLD + 0.1) == "Gamepad", "gamepad after > hold seconds as the last input type")
check(t.pending(HOLD + 0.2) == nil, "no timer once the gamepad is the mode")
check(t.feed("MouseMovement", HOLD + 1) == "Gamepad", "a stray mouse move does not end gamepad mode")
check(t.feed("MouseButton1", HOLD + 2) == "Pointer", "a click ends it at once")
check(t.pending(HOLD + 2) == nil, "the click cleared the gamepad clock")

t = Glyphs.newInputTracker(HOLD)
t.feed("Gamepad1", 10)
t.feed("Keyboard", 11)
check(t.evaluate(10 + HOLD + 1) == "Pointer", "a key inside the hold resets the gamepad clock")
t.feed("Gamepad1", 20)
t.feed("MouseMovement", 21)
check(t.evaluate(20 + HOLD + 0.5) == "Gamepad", "a mouse move inside the hold does not reset it")
t.feed("Touch", 30)
check(t.mode == "Touch", "a touch takes the mode at once")
t.feed("Focus", 31)
check(t.mode == "Touch", "an ignored type changes nothing")
check(Glyphs.newInputTracker(nil).hold == 2, "default hold is 2 s when none is given")

print("\nGLYPHS -- composed console signal")
check(Glyphs.isConsole({ tenFoot = true }) == true, "ten-foot interface -> console")
check(Glyphs.isConsole({ gamepad = true }) == true, "gamepad with no keyboard / mouse / touch -> console")
check(Glyphs.isConsole({ gamepad = true, keyboard = true, mouse = true, mode = "Pointer" }) == false,
	"gamepad + keyboard + mouse on the pointer -> not console")
check(Glyphs.isConsole({ gamepad = true, keyboard = true, mouse = true, mode = "Gamepad" }) == true,
	"gamepad + keyboard + mouse, gamepad settled as the mode -> console")
check(Glyphs.isConsole({ gamepad = true, touch = true }) == false, "gamepad + touch (a phone with a pad) -> not console")
check(Glyphs.isConsole({}) == false, "nothing -> not console")

-- 5. THE LIVE SCRIPTS --------------------------------------------------------

print("\nGLYPHS -- shipped scripts")
local layout = readFile(LAYOUT)
check(layout ~= nil, "MachineLayout.client.luau readable")
if layout then
	local alone = {}
	for line in string.gmatch(layout, "[^\n]+") do
		if string.find(line, "IsTenFootInterface", 1, true) and not string.find(line, "tenFoot =", 1, true) then
			alone[#alone + 1] = line
		end
	end
	check(#alone == 0, "IsTenFootInterface appears only inside the composed Glyphs.isConsole call",
		table.concat(alone, " | "))
	check(string.find(layout, "Glyphs.isConsole", 1, true) ~= nil, "MachineLayout uses Glyphs.isConsole")
	check(string.find(layout, "Feel.Input.GamepadHoldSeconds", 1, true) ~= nil, "the hold is read from FeelConfig")
	check(string.find(layout, "SelectionGroup = true", 1, true) ~= nil
		and string.find(layout, "SelectionBehaviorLeft = Enum.SelectionBehavior.Stop", 1, true) ~= nil,
		"panels are SelectionGroups with Stop edges")
	check(string.find(layout, "GuiService:Select(", 1, true) ~= nil, "focus falls back to GuiService:Select(panel)")
	check(string.find(layout, "GetImageForKeyCode(Enum.KeyCode.ButtonA)", 1, true) == nil,
		"no hard-wired A-button image left in MachineLayout")
	-- every {Token} inside a string literal (the controls rows) is a known action
	local unknown, tokens = {}, 0
	for lit in string.gmatch(layout, '"([^"\n]*)"') do
		for name in string.gmatch(lit, "{(%w+)}") do
			tokens = tokens + 1
			if not Glyphs.Actions[name] then unknown[#unknown + 1] = name end
		end
	end
	check(tokens >= 20 and #unknown == 0, "every {Action} token in the MachineLayout rows is in Glyphs.Actions",
		string.format("%d tokens, unknown: %s", tokens, table.concat(unknown, ",")))
end
local client = readFile(CLIENT)
check(client ~= nil, "KenopsiaClient.client.luau readable")
if client then
	local n = 0
	for _ in string.gmatch(client, "\nlocal ") do n = n + 1 end
	if string.sub(client, 1, 6) == "local " then n = n + 1 end
	check(n <= 180, "KenopsiaClient top-level locals <= 180", tostring(n))
	check(string.find(client, "lookPanel.SelectionGroup = true", 1, true) ~= nil, "the hunter look panel is a SelectionGroup")
	check(string.find(client, "K.Glyphs.LookHint", 1, true) ~= nil, "the look hint is rendered through Glyphs")
end
local project = readFile("default.project.json")
check(project and string.find(project, "StarterPlayerScripts/Glyphs.luau", 1, true) ~= nil,
	"default.project.json maps Glyphs.luau")

print(string.format("\n%d checks, %d failures", checks, failures))
if failures > 0 then
	print("GLYPHS PROOF: FAIL")
	os.exit(1)
end
print("GLYPHS PROOF: PASS")
