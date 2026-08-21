--!nonstrict
-- BreatherRules -- FRAMEWORK STUB (MP-05 D13). The implementer overwrites this
-- file with the trial's PURE logic (grids, sequences, schedules, sort rules,
-- ranking keys); tests/breather.lua loads it through the tests/rules.lua shim.
--
-- PURE, and portable to Lua 5.1: see the header of Pacing.luau for the rule and
-- why it exists. No `game`, no services, no instances, no os/clock access, no
-- math.random (randomness arrives as an injected nextInt).
--
-- REQ-IP-01: original id "breather"; no reference-game name in this file.
local BreatherRules = {}

BreatherRules.TRIAL_ID = "breather"

return BreatherRules
