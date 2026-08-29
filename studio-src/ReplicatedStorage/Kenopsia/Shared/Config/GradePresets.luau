--!nonstrict
-- GRADE PRESETS (P2) -- the per-trial blue grade, as DATA: ambient pair, the
-- classic fog band, one ColorCorrection triple and the camera step, per trial
-- id. docs/INNER-GAME-PLAN.md section 4 is the bible this file transcribes;
-- tests/grade.lua proves the two agree. GradeDirector.client is the only
-- consumer: it converts {r,g,b} to Color3.fromRGB and applies/restores.
--
-- PURE and portable to Lua 5.1 (see the header of Rules/Pacing.luau for the
-- rule): no Roblox globals at module level, no type annotations, no compound
-- assignment, no generalized iteration. Colours are {r,g,b} tables of 0-255
-- INTEGERS (not Color3, not hex -- the offline tests do arithmetic on them);
-- camQuant is the camera position step in STUDS (0.125 = 1/8 stud) or false.
--
-- Two safety rules every preset must obey (Rules below; tests/grade.lua is
-- the gate):
--
--   * LUMINANCE FLOOR -- 0.299*r + 0.587*g + 0.114*b of `ambient` must reach
--     30. Low quality levels drop local lights ENTIRELY (the established
--     mobile black-screen root cause), so every arena must stay playable off
--     ambient alone; lamps are additive pools, never the floor.
--
--   * FOG SANITY -- fogEnd <= 480, because arenas sit >= 480 studs apart and
--     full fog at 480 is what keeps a neighbouring arena invisible with
--     StreamingEnabled off. And fogEnd - fogStart >= 120: the measured live
--     damage of 29.08 (FogStart 823 / FogEnd 832, a 9-stud razor band one
--     edit from a divide-by-zero) is the class this kills permanently.
--
-- `atmosphere` is RESERVED and nil everywhere in Phase 2: classic fog carries
-- the look. When a later phase wants one, the shape is { density, offset,
-- haze, glare, color = {r,g,b}, decay = {r,g,b} } -- and note the engine rule:
-- while an Atmosphere instance exists under Lighting, Roblox IGNORES
-- Lighting.FogStart/FogEnd/FogColor entirely, so a preset carries fog OR an
-- atmosphere, never both.

local GradePresets = {}

-- The rule numbers tests/grade.lua asserts the presets against (declared here
-- beside the data, Band/Value discipline: the test checks these match the
-- bible AND that every preset obeys them).
GradePresets.Rules = {
	AmbientLumaFloor = 30, -- min 0.299r+0.587g+0.114b of every .ambient
	FogBandMin = 120,      -- min fogEnd - fogStart, studs
	FogEndMax = 480,       -- arena-spacing invisibility rule
	CamQuantStep = 0.125,  -- the one legal step: 1/8 stud, position only
}

GradePresets.Presets = {
	-- DEAD ZONE: coldest near-night steel. The proven zero-lights-readable
	-- floor (luma 40.0); the compactor's two amber lamps are the trial's only
	-- warmth -- dread by contrast.
	minefield = {
		ambient = { 34, 40, 56 },
		outdoorAmbient = { 14, 18, 28 },
		fogStart = 30,
		fogEnd = 260,
		fogColor = { 8, 12, 20 },
		ccSat = -0.35,
		ccContrast = 0.08,
		ccTint = { 200, 214, 255 },
		camQuant = 0.125,
		atmosphere = nil,
	},
	-- BIRD HUNTING: brightest pale-blue overcast -- the runner must read at
	-- 315 studs on a phone, so the widest fog band and the highest ambient
	-- (luma 61.5). Quantisation ships 1/8 but GradeDirector suspends it while
	-- the scope GUI is visible: the scope stays honest, never stepped.
	birdhunt = {
		ambient = { 52, 62, 84 },
		outdoorAmbient = { 66, 78, 104 },
		fogStart = 60,
		fogEnd = 420,
		fogColor = { 22, 30, 46 },
		ccSat = -0.35,
		ccContrast = 0.08,
		ccTint = { 200, 210, 235 },
		camQuant = 0.125,
		atmosphere = nil,
	},
	-- CANTEEN: the one warm room -- sodium lamp pools against blue fog at the
	-- windows; the tint leans cyan so the lamps pop warmer by contrast.
	-- fogEnd 145, not the plan draft's 140: 25/140 is a 115-stud band, under
	-- the >= 120 rule above; the wall of fog moves 5 studs, the room reads
	-- the same.
	canteen = {
		ambient = { 44, 52, 64 },
		outdoorAmbient = { 30, 36, 48 },
		fogStart = 25,
		fogEnd = 145,
		fogColor = { 12, 16, 22 },
		ccSat = -0.35,
		ccContrast = 0.08,
		ccTint = { 210, 232, 240 },
		camQuant = 0.125,
		atmosphere = nil,
	},
}

return GradePresets
