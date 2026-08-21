--!nonstrict
-- CutToSpecRules -- FRAMEWORK STUB (MP-05 D13). The implementer overwrites this
-- file with the trial's PURE logic (grids, sequences, schedules, sort rules,
-- ranking keys); tests/carve.lua loads it through the tests/rules.lua shim.
--
-- PURE, and portable to Lua 5.1: see the header of Pacing.luau for the rule and
-- why it exists. No `game`, no services, no instances, no os/clock access, no
-- math.random (randomness arrives as an injected nextInt).
--
-- REQ-IP-01: original id "carve"; no reference-game name in this file.
local CutToSpecRules = {}

CutToSpecRules.TRIAL_ID = "carve"

return CutToSpecRules
