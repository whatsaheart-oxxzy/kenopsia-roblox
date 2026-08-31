-- OPTIONAL. Insert verbatim into tests/feel.lua AFTER line 401 (the blank line
-- that follows the "shift report hold in (0, 6] s" check) and BEFORE line 402,
-- print("No duplicated Pacing.Timing values").
--
-- Requires studio-src/ReplicatedStorage/Kenopsia/Shared/Config/FeelConfig.luau
-- to carry the Feel.FieldPush block first (mirror step M1 of APPLY-headbutt.md).
-- Without the mirror step this hunk fails at "Feel.FieldPush exists"; with the
-- mirror step and without this hunk, feel.lua stays at 190 checks / 0 failures.
--
-- Effect on the offline battery: feel 190 -> 198 checks, 0 failures.
-- Every other suite is untouched (13 suites, counts unchanged).

-- FIELD HEADBUTT (31.08.2026, user): any direction, the victim falls along
-- their own heading, and the fall lasts exactly one second. FieldPush.luau is
-- server-only and has no offline twin, so these pin the three numbers that
-- carry the behaviour. NOTE: AttackSeconds / FallSeconds / HeadbuttDuration /
-- FallFlatDuration are ANIMATION lengths, not Machine motion. They are
-- deliberately absent from the nonFade list above and must stay absent -- all
-- four are longer than Feel.MaxMotion on purpose.
print("Field headbutt (31.08.2026)")
local FP = Feel.FieldPush
check(type(FP) == "table", "Feel.FieldPush exists")
check(FP.HalfAngleDegrees >= 180,
	"any direction: the reach cone is switched off (>= 180)", tostring(FP.HalfAngleDegrees))
check(FP.FallSeconds == 1.0,
	"the fall lasts exactly 1.0 s", tostring(FP.FallSeconds))
check(FP.FallHeadingSpeed > 0 and FP.FallHeadingSpeed < Feel.Birdhunt.InjuredSpeed,
	"the fall-heading threshold sits under the slowest deliberate gait",
	tostring(FP.FallHeadingSpeed) .. " < " .. tostring(Feel.Birdhunt.InjuredSpeed))
check(FP.FallFlatDuration > 0 and FP.FallSeconds > 0,
	"the FallFlat clip is rescaled onto FallSeconds, never timed on its own",
	tostring(FP.FallFlatDuration / FP.FallSeconds) .. "x")
check(FP.RecoveryImmunity > 0 and FP.RecoveryImmunity + FP.FallSeconds > FP.Cooldown,
	"a victim cannot be re-hit before the attacker's own cooldown is up",
	tostring(FP.FallSeconds + FP.RecoveryImmunity) .. " vs " .. tostring(FP.Cooldown))
check(FP.Windup > 0 and FP.Windup < FP.AttackSeconds,
	"the hit lands inside the attacker's own action window", tostring(FP.Windup))
check(FP.Range > 0 and FP.MaxHeightDifference > 0,
	"range and height gates survive the cone removal",
	tostring(FP.Range) .. " studs, " .. tostring(FP.MaxHeightDifference) .. " up")
