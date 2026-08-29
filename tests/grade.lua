-- P2 grade offline proof. Run from the repo root:
--
--     lua tests/grade.lua
--
-- Loads the SHIPPED Shared/Config/GradePresets.luau (no copy) in plain Lua
-- 5.1 and proves it against docs/INNER-GAME-PLAN.md section 4: fog band
-- >= 120 studs wide and FogEnd <= 480 (the arena-spacing invisibility rule),
-- every colour component an integer 0-255, saturation in [-0.5, 0], contrast
-- in [0, 0.2], the per-trial ambient luminance floor (playable with ALL
-- local lights culled -- the mobile black-screen killer), camera quantisation
-- 1/8 stud or off, and no unknown trial ids.
--
-- Exit code is 0 only if every check passes, so this is usable as a gate.

local FILE = "studio-src/ReplicatedStorage/Kenopsia/Shared/Config/GradePresets.luau"

local function loadModule(file)
	local chunk = assert(loadfile(file))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.require = function(m) return m end
	setfenv(chunk, env)
	return chunk()
end

local Grade = loadModule(FILE)

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

-- Rec. 601 luma of an {r,g,b} table -- the same formula the plan's
-- "playable with zero lights" floor is written in.
local function luma(c)
	return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
end

local function isColor(c)
	if type(c) ~= "table" then return false end
	for i = 1, 3 do
		local v = c[i]
		if type(v) ~= "number" or v ~= math.floor(v) or v < 0 or v > 255 then return false end
	end
	return true
end

print("GradePresets loads in plain Lua")
check(type(Grade) == "table", "module returns a table")
check(type(Grade.Presets) == "table" and type(Grade.Rules) == "table", "Presets / Rules sections present")
check(rawget(_G, "Color3") == nil and rawget(_G, "Enum") == nil,
	"no Roblox global leaked at load (Color3/Enum untouched)")

print("Declared rules match the plan")
check(Grade.Rules.AmbientLumaFloor == 30, "ambient luminance floor is 30", tostring(Grade.Rules.AmbientLumaFloor))
check(Grade.Rules.FogBandMin == 120, "minimum fog band is 120 studs", tostring(Grade.Rules.FogBandMin))
check(Grade.Rules.FogEndMax == 480, "FogEnd cap is 480 (arena spacing)", tostring(Grade.Rules.FogEndMax))
check(Grade.Rules.CamQuantStep == 1 / 8, "the one legal camera step is 1/8 stud", tostring(Grade.Rules.CamQuantStep))

print("Only known trial ids")
local KNOWN = { minefield = true, birdhunt = true, canteen = true }
do
	local unknown = nil
	local count = 0
	for id in pairs(Grade.Presets) do
		count = count + 1
		if not KNOWN[id] then unknown = tostring(id) end
	end
	check(unknown == nil, "no id outside minefield/birdhunt/canteen", unknown)
	check(count == 3 and Grade.Presets.minefield and Grade.Presets.birdhunt and Grade.Presets.canteen,
		"all three trials have a preset", tostring(count))
end

for _, id in ipairs({ "minefield", "birdhunt", "canteen" }) do
	local p = Grade.Presets[id]
	print(id)
	check(type(p) == "table", id .. " preset is a table")
	check(isColor(p.ambient), "ambient components are integers 0-255")
	check(isColor(p.outdoorAmbient), "outdoorAmbient components are integers 0-255")
	check(isColor(p.fogColor), "fogColor components are integers 0-255")
	check(isColor(p.ccTint), "ccTint components are integers 0-255")
	check(type(p.fogStart) == "number" and type(p.fogEnd) == "number" and p.fogStart >= 0,
		"fog numbers present, FogStart not negative")
	check(p.fogEnd - p.fogStart >= Grade.Rules.FogBandMin, "fog band >= 120 studs (no razor band)",
		tostring(p.fogEnd - p.fogStart))
	check(p.fogEnd <= Grade.Rules.FogEndMax, "FogEnd <= 480 (the next arena stays invisible)", tostring(p.fogEnd))
	check(type(p.ccSat) == "number" and p.ccSat >= -0.5 and p.ccSat <= 0, "saturation in [-0.5, 0]",
		tostring(p.ccSat))
	check(type(p.ccContrast) == "number" and p.ccContrast >= 0 and p.ccContrast <= 0.2, "contrast in [0, 0.2]",
		tostring(p.ccContrast))
	check(luma(p.ambient) >= Grade.Rules.AmbientLumaFloor,
		"ambient luma >= 30 (playable with every local light culled)", string.format("%.1f", luma(p.ambient)))
	check(p.camQuant == false or p.camQuant == Grade.Rules.CamQuantStep, "camQuant is false or 1/8 stud",
		tostring(p.camQuant))
	check(p.atmosphere == nil, "no Atmosphere in Phase 2 (classic fog carries the look)")
end

print("Plan section 4 values transcribed")
local M, B, C = Grade.Presets.minefield, Grade.Presets.birdhunt, Grade.Presets.canteen
check(near(M.ccSat, -0.35) and near(B.ccSat, -0.35) and near(C.ccSat, -0.35), "shared -0.35 saturation")
check(near(M.ccContrast, 0.08) and near(B.ccContrast, 0.08) and near(C.ccContrast, 0.08), "shared 0.08 contrast")
check(M.fogStart == 30 and M.fogEnd == 260, "minefield fog 30/260")
check(B.fogStart == 60 and B.fogEnd == 420, "birdhunt fog 60/420")
-- The plan draft said 25/140; that band is 115 studs, under the >= 120 rule,
-- so the shipped preset lifts FogEnd to 145 (the room reads the same).
check(C.fogStart == 25 and C.fogEnd == 145, "canteen fog 25/145 (draft 140 lifted for the 120 band)")
check(luma(B.ambient) > luma(C.ambient) and luma(C.ambient) > luma(M.ambient),
	"brightness order birdhunt > canteen > minefield (overcast > room > near-night)")

print(string.format("\n%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
