--!nonstrict
-- GLYPHS (P2.4, 23.08.2026) -- which key or button an action sits on per
-- device class, and how it is shown: gamepad buttons as the platform's own
-- button images (UserInputService:GetImageForKeyCode), keyboard keys as the
-- layout-correct key string (GetStringForKeyCode: an AZERTY board shows
-- Z Q S D), touch as the label printed on the pad button.
--
-- Also the INPUT-MODE hysteresis MachineLayout runs on LastInputTypeChanged:
-- a gamepad becomes the console signal only once it has been the last input
-- type for longer than the hold; a mouse MOVE alone never ends that (a stray
-- nudge of the mouse must not flip the layout), a click / key / touch does at
-- once. Glyphs.isConsole composes the three console signals so no caller
-- depends on GuiService:IsTenFootInterface alone.
--
-- PURE and portable to Lua 5.1 (tests/glyphs.lua loads it with loadfile; see
-- the header of Shared/Rules/Pacing.luau for the rule): no Roblox global at
-- module level, no type annotations, no compound assignment, no generalized
-- iteration. The two engine calls sit behind an injected resolver;
-- Glyphs.robloxResolver(UserInputService) builds the live one and touches
-- Enum only when called.

local Glyphs = {}

Glyphs.Platforms = { "Desktop", "Console", "Touch" }

-- MachineLayout's Platform attribute -> glyph platform (phones and tablets
-- both read the pad labels).
function Glyphs.platformFor(machinePlatform)
	if machinePlatform == "Console" then return "Console" end
	if machinePlatform == "Mobile" or machinePlatform == "Tablet" then return "Touch" end
	return "Desktop"
end

-- action -> per-platform binding. key = one KeyCode name; keys = several,
-- shown a space apart; text = fixed text (mouse buttons and the wheel have no
-- KeyCode; touch shows the pad button's label). Desktop keys go through the
-- string resolver, Console keys through the image resolver. The bindings
-- mirror what KenopsiaClient actually listens to (C / LeftControl / B for
-- crouch, F / Y for sonar, LMB / RT to fire, RMB / LT to scope, ...).
Glyphs.Actions = {
	Confirm   = { Desktop = { key = "Return" },                 Console = { key = "ButtonA" },     Touch = { text = "TAP" } },
	Back      = { Desktop = { key = "Escape" },                 Console = { key = "ButtonB" },     Touch = { text = "CLOSE" } },
	Move      = { Desktop = { keys = { "W", "A", "S", "D" } },  Console = { key = "Thumbstick1" }, Touch = { text = "STICK" } },
	Crouch    = { Desktop = { key = "LeftControl" },            Console = { key = "ButtonB" },     Touch = { text = "CROUCH" } },
	Aim       = { Desktop = { text = "MOUSE" },                 Console = { key = "Thumbstick2" }, Touch = { text = "DRAG" } },
	Fire      = { Desktop = { text = "LMB" },                   Console = { key = "ButtonR2" },    Touch = { text = "FIRE" } },
	Scope     = { Desktop = { text = "RMB" },                   Console = { key = "ButtonL2" },    Touch = { text = "SCOPE" } },
	Zoom      = { Desktop = { text = "WHEEL" },                 Console = { key = "ButtonY" },     Touch = { text = "ZOOM" } },
	Scan      = { Desktop = { key = "F" },                      Console = { key = "ButtonY" },     Touch = { text = "SCAN" } },
	Load      = { Desktop = { text = "LMB" },                   Console = { key = "ButtonL2" },    Touch = { text = "PLATE" } },
	Swallow   = { Desktop = { text = "RMB" },                   Console = { key = "ButtonR2" },    Touch = { text = "MOUTH" } },
	Page      = { Desktop = { keys = { "Left", "Right" } },     Console = { keys = { "DPadLeft", "DPadRight" } }, Touch = { text = "ARROWS" } },
	LookLeft  = { Desktop = { key = "Left" },                   Console = { key = "DPadLeft" },    Touch = { text = "TAP BAR" } },
	LookRight = { Desktop = { key = "Right" },                  Console = { key = "DPadRight" },   Touch = { text = "TAP BAR" } },
}

-- Keyboard keys GetStringForKeyCode does not print as one character (it hands
-- back the KeyCode name for those); short enough for a controls row.
Glyphs.KeyText = {
	LeftControl = "CTRL", RightControl = "CTRL", LeftShift = "SHIFT", RightShift = "SHIFT",
	LeftAlt = "ALT", Return = "ENTER", Escape = "ESC", Space = "SPACE", Tab = "TAB",
	Backspace = "BACK", Left = "LEFT", Right = "RIGHT", Up = "UP", Down = "DOWN",
}

-- Gamepad text fallbacks: shown when the image resolver has nothing for a
-- key, and carried next to every image as its alt text.
Glyphs.ButtonText = {
	ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y",
	ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT",
	ButtonL3 = "L3", ButtonR3 = "R3", Thumbstick1 = "LS", Thumbstick2 = "RS",
	DPadLeft = "DPAD LEFT", DPadRight = "DPAD RIGHT", DPadUp = "DPAD UP", DPadDown = "DPAD DOWN",
	ButtonStart = "MENU", ButtonSelect = "VIEW",
}

-- Hunter look-speed panel hint, per platform (KenopsiaClient.setHunterSetup).
-- Machine voice: uppercase, no exclamation marks.
Glyphs.LookHint = {
	Desktop = "CLICK BAR     {LookLeft} / {LookRight}",
	Console = "{LookLeft} / {LookRight}",
	Touch = "TAP BAR",
}

-- One binding -> a list of segments. A segment is { text = "CTRL" } or
-- { image = "rbxasset://...", text = "B" } (text = the alt / fallback).
local function keySegment(keyName, platform, resolver)
	if platform == "Console" then
		local image = resolver and resolver.image and resolver.image(keyName) or ""
		local text = Glyphs.ButtonText[keyName] or string.upper(keyName)
		if type(image) == "string" and image ~= "" then
			return { image = image, text = text }
		end
		return { text = text }
	end
	local fixed = Glyphs.KeyText[keyName]
	if fixed then return { text = fixed } end
	local s = resolver and resolver.string and resolver.string(keyName) or ""
	if type(s) ~= "string" or s == "" then s = keyName end
	return { text = string.upper(s) }
end

function Glyphs.glyph(action, platform, resolver)
	local a = Glyphs.Actions[action]
	if not a then return nil end
	local b = a[platform] or a.Desktop
	if b.text then return { { text = b.text } } end
	if b.key then return { keySegment(b.key, platform, resolver) } end
	local out = {}
	for i = 1, #b.keys do
		if i > 1 then out[#out + 1] = { text = " " } end
		out[#out + 1] = keySegment(b.keys[i], platform, resolver)
	end
	return out
end

-- Expand every {Action} token in a controls line into segments. An unknown
-- action prints its own name in capitals so it is visible on screen.
function Glyphs.segments(text, platform, resolver)
	local out = {}
	local pos = 1
	text = tostring(text or "")
	while true do
		local s, e, name = string.find(text, "{(%w+)}", pos)
		if not s then break end
		if s > pos then out[#out + 1] = { text = string.sub(text, pos, s - 1) } end
		local parts = Glyphs.glyph(name, platform, resolver)
		if parts then
			for i = 1, #parts do out[#out + 1] = parts[i] end
		else
			out[#out + 1] = { text = string.upper(name) }
		end
		pos = e + 1
	end
	if pos <= #text then out[#out + 1] = { text = string.sub(text, pos) } end
	return out
end

-- Segments -> one string (images become their alt text).
function Glyphs.join(segments)
	local parts = {}
	for i = 1, #segments do parts[i] = segments[i].text or "" end
	return table.concat(parts)
end

-- Text-only rendering of a line for a platform.
function Glyphs.text(line, platform, resolver)
	return Glyphs.join(Glyphs.segments(line, platform, resolver))
end

function Glyphs.hasImage(segments)
	for i = 1, #segments do
		if segments[i].image then return true end
	end
	return false
end

-- The live resolver. Enum is read at CALL time only.
function Glyphs.robloxResolver(userInputService)
	local r = {}
	function r.image(keyName)
		local ok, v = pcall(function()
			return userInputService:GetImageForKeyCode(Enum.KeyCode[keyName])
		end)
		return ok and v or ""
	end
	function r.string(keyName)
		local ok, v = pcall(function()
			return userInputService:GetStringForKeyCode(Enum.KeyCode[keyName])
		end)
		return ok and v or ""
	end
	return r
end

-- INPUT MODE ----------------------------------------------------------------

-- UserInputType name -> class. "Move" is mouse movement (the tracker ignores
-- it), nil for types that say nothing about the device (Focus, None, ...).
function Glyphs.classify(inputTypeName)
	if type(inputTypeName) ~= "string" then return nil end
	if string.sub(inputTypeName, 1, 7) == "Gamepad" then return "Gamepad" end
	if inputTypeName == "MouseMovement" then return "Move" end
	if string.sub(inputTypeName, 1, 5) == "Mouse" or inputTypeName == "Keyboard" or inputTypeName == "TextInput" then
		return "Pointer"
	end
	if inputTypeName == "Touch" or inputTypeName == "Accelerometer" or inputTypeName == "Gyro" then
		return "Touch"
	end
	return nil
end

-- The hysteresis. mode is "Gamepad" | "Pointer" | "Touch" | nil (undecided).
--   feed(name, now)  -- a LastInputTypeChanged value (its .Name) at time now
--   evaluate(now)    -- re-check the hold without new input (a timer calls it)
-- Gamepad: remembered from its first event; becomes the mode once more than
-- holdSeconds have passed with no click / key / touch in between. Pointer and
-- Touch take the mode at once and clear the gamepad clock. Move: ignored.
function Glyphs.newInputTracker(holdSeconds)
	local t = { mode = nil, gamepadSince = nil, hold = tonumber(holdSeconds) or 2 }
	function t.evaluate(now)
		if t.gamepadSince and (now - t.gamepadSince) > t.hold then
			t.mode = "Gamepad"
		end
		return t.mode
	end
	function t.feed(inputTypeName, now)
		local class = Glyphs.classify(inputTypeName)
		if class == "Gamepad" then
			if not t.gamepadSince then t.gamepadSince = now end
		elseif class == "Pointer" or class == "Touch" then
			t.gamepadSince = nil
			t.mode = class
		end
		return t.evaluate(now)
	end
	-- seconds until the gamepad hold would elapse (nil when no clock runs)
	function t.pending(now)
		if not t.gamepadSince or t.mode == "Gamepad" then return nil end
		return math.max(0, t.hold - (now - t.gamepadSince))
	end
	return t
end

-- Console = ten-foot interface OR a gamepad with no keyboard / mouse / touch
-- OR the tracker has settled on the gamepad. Never one signal alone.
function Glyphs.isConsole(s)
	if s.tenFoot then return true end
	if s.gamepad and not (s.keyboard or s.mouse or s.touch) then return true end
	return s.mode == "Gamepad"
end

return Glyphs
