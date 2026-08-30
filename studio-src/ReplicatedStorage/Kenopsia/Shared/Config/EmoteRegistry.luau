--!nonstrict
-- EMOTE REGISTRY (Phase 5) -- the emote CATALOG as a socket. SHIPS DORMANT.
--
-- One row per emote. `animKey` is a KEY of AnimationIds.Player, NEVER an asset
-- id: AnimationIds is the only file in the codebase that may contain a raw
-- content-URI literal for an animation (its own header states that rule), and
-- its resolve() returns nil for a clip that is not published yet. So a row
-- whose clip is still 0 costs nothing, plays nothing, warns nothing and never
-- throws -- the CRT-hum placeholder pattern Badges.luau established, applied to
-- clips instead of badge ids.
--
-- ADDING AN EMOTE IS ONE ROW HERE PLUS ONE PUBLISHED CLIP IN AnimationIds.
-- No service change, no client change, no remote change. The commented example
-- rows below are the whole retrofit, written out.
--
-- PURE CONFIG: no game:GetService, no Instance, no require, no yields --
-- tests/emotes.lua loads this file in plain desktop Lua 5.1 and proves every
-- rule below offline (the MenuConfig / ProgressionRules discipline).
--
-- ZERO PAY-FOR-POWER (the recorded rule, MASTERPLAN P5.4 "cosmetic only"): an
-- emote is a cosmetic clip and nothing else. No row may carry speed, damage,
-- score, points, health, reach or any other gameplay quantity -- the allowed
-- field set below is closed and tests/emotes.lua enforces it, exactly as it
-- enforces the same deny-list over MonetizationConfig's grants.
--
-- CRATE KEYS ARE EARNED, NEVER SOLD. Keys come from WORK ORDERS (Phase 4c:
-- ProgressionRules.FRAGMENTS_PER_KEY rolls quest fragments into keys at the
-- verdict). MainGame sells no key, no fragment and no crate -- see
-- MonetizationConfig's grant deny-list.
--
-- SOURCES -- who may play a row:
--   "default"    owned by everyone, forever. Never checked against a profile;
--                revoking a row instantly stops it playing, no migration.
--   "crate"      EARNED: a crate key opens it (keys are quest income, above).
--   "robux"      a gamepass grant -- the id must appear in some
--                MonetizationConfig.PASSES[*].grants.emotes list.
--   "clearance"  reaching a clearance band unlocks it; `clearance` is that band
--                (ProgressionRules.clearanceFor).
-- Everything except "default" REQUIRES OWNERSHIP -- see requiresOwnership.
local EmoteRegistry = {}

-- The closed set. A row's `source` must be one of these; the server decides
-- ownership from it and nothing else.
EmoteRegistry.SOURCES = {
	default = true,
	crate = true,
	robux = true,
	clearance = true,
}

-- The closed field set. Any other key on a row is a bug -- see ZERO
-- PAY-FOR-POWER above; tests/emotes.lua rejects a row that grows one.
EmoteRegistry.FIELDS = {
	id = true,        -- string, must equal the table key (the id travels alone in packets)
	name = true,      -- string, the CRT label; SHOUTED, like every Machine string
	animKey = true,   -- string, a key of AnimationIds.Player
	source = true,    -- string, a key of SOURCES
	rarity = true,    -- string, cosmetic tier label only
	clearance = true, -- number, source == "clearance" only
}

-- THE CATALOG. Exactly ONE real row ships in Phase 5: the free dance that
-- already exists in the game (AnimationIds.Player.Dance = published 24.08.2026,
-- the retargeted Mixamo "Dancing" on Anim_FieldClips). It is source "default"
-- so it is owned by everyone and the ownership check never touches a profile.
--
-- NOTE the deliberate overlap: PS1Animate ALSO plays Dance as a looping gait
-- off its own danceOn latch (G / DPadLeft / the KenopsiaEmote DanceButton).
-- That path is free, client-local and UNTOUCHED by Phase 5. This row is the
-- same clip reached through the SERVER-authoritative one-shot channel, so the
-- day a paid or earned emote is added it rides a wire that was already proven
-- with a clip everybody owns.
EmoteRegistry.Emotes = {
	dance_default = {
		id = "dance_default",
		name = "DANCE",
		animKey = "Dance",
		source = "default",
		rarity = "standard",
	},

	-- ---------------------------------------------------------------------
	-- THE SIX DANCE EMOTES (30.08.2026, user-supplied clips). Published under
	-- the group 832614570 and already in AnimationIds.Player, so every row
	-- below is LIVE the moment a player owns it -- no placeholder, no 0.
	--
	-- ALL SIX SHIP AS "crate": crate keys are EARNED (WORK ORDER fragments,
	-- Phase 4c), so shipping them this way sells NOTHING and needs no id from
	-- anybody. The user's directive was "buy with robux OR get from crates in
	-- Kenopsia_DEV" -- which of the six become "robux" is a decision, not a
	-- default, and it is on the blockers list. Flipping one is TWO edits:
	-- source = "robux" here, and its id added to the grants.emotes list of a
	-- MonetizationConfig pass. tests/emotes.lua fails the build if a "robux"
	-- row is not reachable from some pass, so the pair cannot be half-done.
	-- ---------------------------------------------------------------------
	blow_kiss = {
		id = "blow_kiss",
		name = "BLOW A KISS",
		animKey = "BlowKiss",
		source = "crate",
		rarity = "issue",
	},
	insult = {
		id = "insult",
		name = "INSULT",
		animKey = "Insult",
		source = "crate",
		rarity = "issue",
	},
	rumba = {
		id = "rumba",
		name = "RUMBA",
		animKey = "Rumba",
		source = "crate",
		rarity = "issue",
	},
	moonwalk = {
		id = "moonwalk",
		name = "MOONWALK",
		animKey = "Moonwalk",
		source = "crate",
		rarity = "issue",
	},
	silly_dance = {
		id = "silly_dance",
		name = "SILLY DANCE",
		animKey = "SillyDance",
		source = "crate",
		rarity = "issue",
	},
	hip_hop = {
		id = "hip_hop",
		name = "HIP HOP",
		animKey = "HipHop",
		source = "crate",
		rarity = "issue",
	},

	-- ---------------------------------------------------------------------
	-- EXAMPLE ROWS -- commented out on purpose. Uncommenting one is HALF the
	-- retrofit; the other half is publishing its clip under the group and
	-- pasting the id into AnimationIds.Player under the SAME key as `animKey`.
	-- Until that id exists, resolve() returns nil, PS1Animate's track() returns
	-- nil and playEmote() simply returns -- no animation, no error, no yield.
	-- (Do not forget the warm list at PS1Animate line 61-62: append the new
	-- animKey there or the first press shows the bind pose for a beat.)
	--
	-- A CRATE emote -- opened with an EARNED key, never bought:
	-- salute_crate = {
	-- 	id = "salute_crate",
	-- 	name = "SALUTE",
	-- 	animKey = "Salute",       -- add AnimationIds.Player.Salute = <published id>
	-- 	source = "crate",
	-- 	rarity = "issue",
	-- },
	--
	-- A ROBUX emote -- granted by a gamepass. Its id MUST be listed in
	-- MonetizationConfig.PASSES.OVERSEER.grants.emotes or nothing can ever own
	-- it; tests/emotes.lua fails the build if that link is missing.
	-- overseer_salute = {
	-- 	id = "overseer_salute",
	-- 	name = "OVERSEER SALUTE",
	-- 	animKey = "OverseerSalute",
	-- 	source = "robux",
	-- 	rarity = "overseer",
	-- },
	--
	-- A CLEARANCE emote -- unlocked by the XP band, costs nothing:
	-- clearance5_nod = {
	-- 	id = "clearance5_nod",
	-- 	name = "ACKNOWLEDGE",
	-- 	animKey = "Nod",
	-- 	source = "clearance",
	-- 	rarity = "clearance",
	-- 	clearance = 5,
	-- },
	-- ---------------------------------------------------------------------
}

-- The row, or nil for anything this catalog does not know. Total: a non-string
-- id, an unknown id and a nil id all come back nil, never an error.
function EmoteRegistry.get(id)
	if type(id) ~= "string" then return nil end
	return EmoteRegistry.Emotes[id]
end

-- True only for a row that everybody owns. An unknown id is NOT default.
function EmoteRegistry.isDefault(id)
	local row = EmoteRegistry.get(id)
	return row ~= nil and row.source == "default"
end

-- The pure ownership DECISION, so the rule is provable offline and the server
-- never re-implements it. FAILS CLOSED: an unknown id requires ownership, so a
-- typo or a row deleted from under a saved wheel can never become free play.
function EmoteRegistry.requiresOwnership(id)
	local row = EmoteRegistry.get(id)
	if row == nil then return true end
	return row.source ~= "default"
end

-- The clip key for an id, or nil. This is what the server writes into the
-- character attribute XBotEmote; PS1Animate feeds it straight to
-- AnimationIds.load(animator, "Player", key).
function EmoteRegistry.animKey(id)
	local row = EmoteRegistry.get(id)
	return row and row.animKey or nil
end

-- Every id, SORTED -- a dictionary has no order and a wheel/shop that renders
-- in a different order on every server is a bug nobody reports.
function EmoteRegistry.list()
	local out = {}
	for id in pairs(EmoteRegistry.Emotes) do
		out[#out + 1] = id
	end
	table.sort(out)
	return out
end

return EmoteRegistry
