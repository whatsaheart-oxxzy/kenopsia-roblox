--!nonstrict
-- ANIMATION IDS -- the ONLY place a hand-published animation/texture id lives.
--
-- 0 means "not published yet": resolve() returns nil and every caller skips the
-- clip. Publishing happens in Studio's Animation Editor (a manual step, see
-- docs/MP-03-ASSETS.md M1/M2 and docs/MP-05-BUILD-PLAN.md section G) -- it cannot be
-- automated, so this table ships with placeholders and the game degrades to
-- "no animation" until the user pastes the ids in. No animation is never an
-- error and never a yield.
--
-- Rules: no other module contains `rbxassetid://` for an animation; `resolve`
-- is pure so `tests/animationids.lua` can prove the placeholder behaviour.
local RunService = game:GetService("RunService")

local AnimationIds = {}

AnimationIds.Player = {          -- rig: PS1Player (20 bones), loops in place, 30 fps
	-- 22.08.2026: every clip re-published under the GROUP (see OWNERSHIP below).
	Idle   = 136021051849380, -- 2.00 s, priority Idle
	Walk   = 139242749568316, -- 1.00 s, Movement, natural 4.5 st/s at scale 1
	Run    = 122100342132694, -- 0.67 s, Movement, natural 10.95 st/s
	Crouch = 124433445029981, -- 2.00 s, Movement (used for "sneak")
	Push   = 83985770937060, -- 1.33 s, Action, natural 3.15 st/s
	Death  = 120865302102282, -- Table Manners execution, Action
	-- 0.20 s, Action, repeatable: the fork punches down into the plate and
	-- lifts with beans on the tines (Documents\Retro\PS1Player, 42_anim_table.py).
	Stab   = 124637290464825,
	-- 0.40 s, Action, one-shot: fork to mouth and back; the beans vanish at the
	-- bite. Authored as Anim_Eat.fbx (same pipeline). It keys six bones -- right arm chain plus a 3/4/5-degree torso, neck and
	-- head dip -- and holds every other bone, the legs above all, at exactly
	-- its rest value, so the seated pose CanteenDiner.sit() writes into
	-- Bone.CFrame survives the bite. That is the whole reason a bespoke clip
	-- was needed instead of the obvious stand-in: Push moves the legs.
	Eat    = 132791710012729,
	-- 23.08.2026: three Mixamo clips (Sweep Fall / Zombie Crawl / Injured
	-- Walking) RETARGETED onto the PS1 rig -- the raw imports carry 52
	-- mixamorig:* bones the 20-bone rig does not have, which is why the
	-- Animation Editor reported "no root". The retargeted sequences live on
	-- Workspace.Anim_FieldClips (save holder of the same name); publish from
	-- that rig under the group. 0 until then; Studio plays the saved sequence
	-- (see StudioSequences + the warmup bridge).
	-- DeathField is the death of the FIELD trials (Dead Zone, Bird Hunting);
	-- the canteen keeps its execution Death above.
	-- Published under the group 23.08.2026 (evening) from Anim_FieldClips.
	DeathField  = 137420901214756,
	Crawl       = 102977383488004,
	InjuredWalk = 109198821545630,
}
-- Clip start offsets in seconds: the Sweep Fall source opens with ~0.6 s of
-- "hands to the head" before the body goes — the field death skips it.
AnimationIds.PlayerStart = { DeathField = 0.6 }
-- for AdjustSpeed. Crawl / InjuredWalk (23.08.2026) are MEASURED from the
-- Mixamo hips trend the retarget removed (8.50 studs / 3.77 s, 6.05 / 1.73 s
-- at scale 1) -- the clips play in place, these are their natural speeds.
AnimationIds.PlayerSpeeds = { Walk = 4.5, Run = 10.95, Push = 3.15, Crawl = 2.26, InjuredWalk = 3.49 }
AnimationIds.Boss = {            -- rig: CanteenBoss (19 bones)
	-- 22.08.2026: re-published under the group; Reading is its own looping clip
	-- (LookDown lands on the paper, CanteenBoss hands over to Reading from there).
	-- The boss never dies: the execution clip is the PLAYER's Death above.
	Reading = 93007201218927, Idle = 130938007759833, LookUp = 94677474801733,
	LookDown = 119985932443999, Shoot = 86667177937697,
}
AnimationIds.Textures = {
	-- 22.08.2026: the four expression atlases uploaded (1024, nearest-upscaled).
	PlayerNeutral = 136734973177857, PlayerBlink = 134298997425493,
	PlayerHappy = 71841991124832, PlayerHurt = 100549970137009,
	BossNeutral   = 130641113899237, BossAngry = 88815675234840,
}

-- "rbxassetid://<id>" for a published texture, nil while the slot is 0.
function AnimationIds.texture(name)
	local id = AnimationIds.Textures[name]
	if type(id) ~= "number" or id <= 0 then return nil end
	return "rbxassetid://" .. tostring(id)
end

-- OWNERSHIP. The first batch of ids was published by user 4840146924
-- (iLoveKilIs) while place 110672791536316 belongs to GROUP 832614570, and
-- sharing access never took effect; on 22.08.2026 every clip was re-published
-- so the group place can play it. The rule is still the same: Roblox refuses to
-- play an animation the experience has no permission for -- LoadAnimation
-- succeeds, the track plays, Length stays 0 and the rig never moves; the
-- Output shows "The experience doesn't have access permission to use asset
-- id N. Click to share access". Fix = click that link once per id (or
-- Creator Hub -> Development Items -> Animations -> Permissions -> add this
-- experience). Nothing in code can grant it.
--
-- STUDIO FALLBACK. Until then, tests in Studio would show frozen rigs, so on
-- a Studio SERVER the loader can register the authored KeyframeSequences that
-- still live in ServerStorage.RBX_ANIMSAVES (KeyframeSequenceProvider
-- :RegisterKeyframeSequence, Studio-only by design). `warmup()` probes ONE
-- published id on a bare Animator; if it never resolves, every later load()
-- uses the sequences below instead. Outside Studio nothing changes.
-- { ObjectValue name in RBX_ANIMSAVES, KeyframeSequence name, min keyframes }
-- (two ObjectValues are called Anim_Idle; the boss one has 121 keyframes.)
AnimationIds.StudioSequences = {
	Player = {
		Idle = { "PS1Player_AllAnims", "Idle" }, Walk = { "PS1Player_AllAnims", "Walk" },
		Run = { "PS1Player_AllAnims", "Run" }, Crouch = { "PS1Player_AllAnims", "Crouch" },
		Push = { "PS1Player_AllAnims", "Push" }, Death = { "Anim_Death", "Death of Player" },
		-- Anim_Eat.fbx is imported on its own, so its save is its own holder --
		-- name the Animation Editor save "Anim_Eat" and the sequence inside it
		-- "Eat" and the diner animates in Studio before anything is published.
		Eat = { "Anim_Eat", "eat" }, Stab = { "Anim_Stab", "stab beans" },
		-- 23.08.2026: the retargeted field clips (see Player above); the raw
		-- "mixamo.com" imports under Sweep Fall / Zombie Crawl / Injured
		-- Walking do not fit this skeleton and must not be referenced.
		DeathField = { "Anim_FieldClips", "DeathField" }, Crawl = { "Anim_FieldClips", "Crawl" },
		InjuredWalk = { "Anim_FieldClips", "InjuredWalk" },
	},
	Boss = {
		Idle = { "Anim_Idle", "Idle", 100 }, LookUp = { "Anim_LookUp", "LookingUp" },
		Reading = { "Anim_LookUp", "LookingUp" }, LookDown = { "Anim_LookDown", "LookDown" },
		Shoot = { "Anim_Shoot", "Shoot" },
	},
}

-- nil = not probed yet, true = published ids play here, false = they do not.
AnimationIds.publishedPlayable = nil
local studioIds = {}

local function studioUri(group, name)
	if not (RunService:IsStudio() and RunService:IsServer()) then return nil end
	local spec = AnimationIds.StudioSequences[group] and AnimationIds.StudioSequences[group][name]
	if not spec then return nil end
	local key = group .. "/" .. name
	if studioIds[key] ~= nil then return studioIds[key] or nil end
	local saves = game:GetService("ServerStorage"):FindFirstChild("RBX_ANIMSAVES")
	local found = nil
	for _, holder in ipairs(saves and saves:GetChildren() or {}) do
		if holder.Name == spec[1] then
			local ks = holder:FindFirstChild(spec[2])
			if ks and ks:IsA("KeyframeSequence") and #ks:GetKeyframes() >= (spec[3] or 1) then
				found = ks
				break
			end
		end
	end
	local ok, id = pcall(function()
		return found and game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(found) or nil
	end)
	studioIds[key] = (ok and id) or false
	return studioIds[key] or nil
end

-- STUDIO BRIDGE (23.08.2026). studioUri() only works on the SERVER (the saves
-- live in ServerStorage and RegisterKeyframeSequence is server-side), but the
-- PS1 character clips are played by a LocalScript. So the server registers
-- every unpublished Player sequence once at warmup and hands the returned
-- content id to the client as an attribute on ReplicatedStorage.Kenopsia:
--     StudioAnim_Player_<Name>  (string, Studio only)
-- load() on the client reads it when resolve() is nil. Missing saves are never
-- an error: the attribute is simply absent and the clip is skipped as before.
local STUDIO_ATTR_PREFIX = "StudioAnim_"

local function studioAttrHost()
	return game:GetService("ReplicatedStorage"):FindFirstChild("Kenopsia")
end

local function publishStudioSequences()
	if not (RunService:IsStudio() and RunService:IsServer()) then return end
	pcall(function()
		local host = studioAttrHost()
		if not host then return end
		for name, _ in pairs(AnimationIds.StudioSequences.Player) do
			if AnimationIds.resolve("Player", name) == nil then
				local uri = studioUri("Player", name)
				if uri then host:SetAttribute(STUDIO_ATTR_PREFIX .. "Player_" .. name, uri) end
			end
		end
	end)
end

local function studioAttrUri(group, name)
	if not RunService:IsStudio() or RunService:IsServer() then return nil end
	local ok, uri = pcall(function()
		local host = studioAttrHost()
		return host and host:GetAttribute(STUDIO_ATTR_PREFIX .. group .. "_" .. name) or nil
	end)
	if ok and type(uri) == "string" and uri ~= "" then return uri end
	return nil
end

-- Server, once at boot (async). Decides publishedPlayable within ~3 s.
function AnimationIds.warmup()
	if not RunService:IsServer() or AnimationIds.publishedPlayable ~= nil then return end
	publishStudioSequences()
	task.spawn(function()
		local uri = AnimationIds.resolve("Boss", "Idle")
		if not uri then
			AnimationIds.publishedPlayable = false
			return
		end
		local probe = Instance.new("Model")
		probe.Name = "AnimationIdsProbe"
		local controller = Instance.new("AnimationController")
		controller.Parent = probe
		local animator = Instance.new("Animator")
		animator.Parent = controller
		probe.Parent = workspace
		local anim = Instance.new("Animation")
		anim.AnimationId = uri
		local ok, track = pcall(animator.LoadAnimation, animator, anim)
		local playable = false
		if ok and track then
			track:Play()
			local deadline = os.clock() + 3
			while os.clock() < deadline do
				if track.Length > 0 then
					playable = true
					break
				end
				task.wait(0.1)
			end
			track:Stop(0)
		end
		probe:Destroy()
		AnimationIds.publishedPlayable = playable
		if not playable then
			warn("[AnimationIds] published animation ids do not play in this place "
				.. "(experience lacks permission - see Output 'Click to share access'); "
				.. (RunService:IsStudio() and "using ServerStorage.RBX_ANIMSAVES sequences for this Studio session"
					or "rigs will not animate until access is granted"))
		else
			print("[AnimationIds] published animation ids play in this place")
		end
	end)
end

-- "rbxassetid://<id>" or nil when the id is a placeholder / unknown.
function AnimationIds.resolve(group, name)
	local t = AnimationIds[group]
	local id = type(t) == "table" and t[name] or nil
	if type(id) ~= "number" or id <= 0 then return nil end
	-- %.0f, not `..`: asset ids have 15 digits and plain concatenation prints
	-- them in exponent form on the Lua 5.1 interpreter the offline proof runs on.
	return string.format("rbxassetid://%.0f", id)
end

-- Returns an AnimationTrack or nil. Caches Animation instances per (group,name).
-- Never throws: a missing id, a rig without Animator, or a LoadAnimation error
-- all yield nil.
local cache = {}
function AnimationIds.load(animator, group, name)
	if not animator then return nil end
	local uri = AnimationIds.resolve(group, name)
	if AnimationIds.publishedPlayable == false or uri == nil then
		uri = studioUri(group, name) or uri
	end
	-- 23.08.2026: on a Studio CLIENT the server's bridge attribute stands in
	-- for the unpublished id (see STUDIO BRIDGE). Outside Studio this is nil.
	if uri == nil then
		uri = studioAttrUri(group, name)
	end
	if not uri then return nil end
	local key = group .. "/" .. name .. "@" .. uri
	local anim = cache[key]
	if not anim then
		anim = Instance.new("Animation")
		anim.Name = key
		anim.AnimationId = uri
		cache[key] = anim
	end
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	return ok and track or nil
end

return AnimationIds
