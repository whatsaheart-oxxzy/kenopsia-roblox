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
	Idle   = 125600962447767, -- 2.00 s, priority Idle
	Walk   = 123033497454830, -- 1.00 s, Movement, natural 4.5 st/s at scale 1
	Run    = 95031726336950, -- 0.67 s, Movement, natural 10.95 st/s
	Crouch = 125766316179596, -- 2.00 s, Movement (used for "sneak")
	Push   = 70937503697406, -- 1.33 s, Action, natural 3.15 st/s
	Death  = 114200780379540, -- Table Manners execution, Action
	-- 0.47 s, Action. AUTHORED, NOT YET PUBLISHED: the clip exists as
	-- Documents\Retro\PS1Player\export\anim\Anim_Eat.fbx and has to be imported
	-- in the Animation Editor and published by hand like every other id here.
	-- It keys six bones -- right arm chain plus a 3/4/5-degree torso, neck and
	-- head dip -- and holds every other bone, the legs above all, at exactly
	-- its rest value, so the seated pose CanteenDiner.sit() writes into
	-- Bone.CFrame survives the bite. That is the whole reason a bespoke clip
	-- was needed instead of the obvious stand-in: Push moves the legs.
	Eat    = 0,
}
AnimationIds.PlayerSpeeds = { Walk = 4.5, Run = 10.95, Push = 3.15 } -- for AdjustSpeed
AnimationIds.Boss = {            -- rig: CanteenBoss (19 bones)
	-- Reading reuses LookUp: CanteenBoss holds its first reading pose at speed 0.
	Reading = 78730370216852, Idle = 95540888860028, LookUp = 78730370216852,
	LookDown = 76111131902834, Shoot = 87302586462797, Death = 0,
}
AnimationIds.Textures = {
	PlayerNeutral = 136734973177857, PlayerBlink = 0, PlayerHappy = 0, PlayerHurt = 0,
	BossNeutral   = 130641113899237, BossAngry = 0,
}

-- OWNERSHIP. Every id above was published by user 4840146924 (iLoveKilIs),
-- but place 110672791536316 belongs to GROUP 832614570. Roblox refuses to
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
		Eat = { "Anim_Eat", "Eat" },
	},
	Boss = {
		Idle = { "Anim_Idle", "Idle", 100 }, LookUp = { "Anim_LookUp", "LookingUp" },
		Reading = { "Anim_LookUp", "LookingUp" }, LookDown = { "Anim_LookDown", "LookDown" },
		Shoot = { "Anim_Shoot", "Shoot" }, Death = { "Anim_Death", "Death of Player" },
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

-- Server, once at boot (async). Decides publishedPlayable within ~3 s.
function AnimationIds.warmup()
	if not RunService:IsServer() or AnimationIds.publishedPlayable ~= nil then return end
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
