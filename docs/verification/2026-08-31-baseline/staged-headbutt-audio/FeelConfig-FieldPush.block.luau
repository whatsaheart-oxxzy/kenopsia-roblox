-- Player-to-player field headbutt. The server owns eligibility, timing and impact.
-- The source attack hits at about 0.8 s; 2.1/0.9 playback aligns it with Windup.
-- 31.08.2026 (user): "The player can headbutt another player IN ANY direction,
-- The Player who got headbutted, falls in the direction where they look/move.
-- The Fall only lasts 1 seconds and the player stands up right after."
-- Three numbers carry that, and FieldPush.luau hardcodes none of them:
--   HalfAngleDegrees 180 IS the any-direction rule. FieldPush:InReach treats
--     >= 180 as "no cone at all" and tests it as such, because cos(rad(180))
--     is -1 and the dot product of two unit vectors can land a hair under -1
--     in floating point -- which would reject the one target standing exactly
--     behind you. The old 65 (a 130 degree wedge) is one edit away.
--   FallSeconds is the WHOLE downtime and the ONLY number that sets it: the
--     server stun is now + FallSeconds, the stand-up is scheduled on that same
--     clock, and the FallFlat clip is replayed at FallFlatDuration/FallSeconds.
--     Clip and stun therefore cannot drift apart. At 1.0 the 55-frame source
--     runs 1.833x, which is what "stands up right after" sounds like.
--   FallHeadingSpeed is the flat speed at which the victim's own momentum
--     outranks their facing as the fall direction. 1.5 st/s sits under the
--     slowest deliberate gait in the game (Birdhunt.InjuredSpeed 3.5) and over
--     the idle jitter of a character standing on a slope.
-- These four are animation lengths, not Machine motion, and must never be added
-- to the nonFade list in tests/feel.lua: AttackSeconds, FallSeconds,
-- HeadbuttDuration, FallFlatDuration all outlive Feel.MaxMotion by design.
Feel.FieldPush = {
	Cooldown = 1.5,
	Range = 6,
	HalfAngleDegrees = 180,
	MaxHeightDifference = 4,
	Windup = 0.34,
	AttackSeconds = 0.9,
	FallSeconds = 1.0,
	FallHeadingSpeed = 1.5,
	RecoveryImmunity = 0.8,
	FlingSpeed = 12,
	FlingUp = 8,
	HeadbuttDuration = 2.1,
	FallFlatDuration = 55 / 30,
}
