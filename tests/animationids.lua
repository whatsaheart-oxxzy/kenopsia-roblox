-- MP-05 Framework offline proof: the AnimationIds placeholder contract.
--
--     lua tests/animationids.lua
--
-- Loads the SHIPPED Shared/Config/AnimationIds.luau. resolve() must return nil
-- for every placeholder (0) and a "rbxassetid://<id>" string for a positive id;
-- load() must return nil (never throw) when the id is a placeholder or the
-- animator is missing. Instance is only touched inside load() on a resolved
-- id, so a stub Instance proves that path too.

local function loadModule(path)
	local chunk = assert(loadfile(path))
	local env = setmetatable({}, { __index = _G })
	env.script = { Parent = {} }
	env.Instance = {
		new = function(className)
			return { ClassName = className }
		end,
	}
	-- The module reads RunService at load time (the Studio KeyframeSequence
	-- fallback asks IsStudio/IsServer). Offline both are false, which is the
	-- interesting case anyway: it forces resolve() down the PUBLISHED-id path,
	-- so a placeholder has to come back nil rather than as a Studio sequence.
	-- Without this stub the module cannot even be loaded and the whole file
	-- reports as one error instead of as its checks.
	local services = {
		RunService = { IsStudio = function() return false end, IsServer = function() return false end },
		ServerStorage = { FindFirstChild = function() return nil end },
		KeyframeSequenceProvider = { RegisterKeyframeSequence = function() return nil end },
	}
	env.game = {
		GetService = function(_, name)
			return services[name] or {}
		end,
	}
	setfenv(chunk, env)
	return chunk()
end

local A = loadModule("studio-src/ReplicatedStorage/Kenopsia/Shared/Config/AnimationIds.luau")

local failures, checks = 0, 0
local function check(ok, label, detail)
	checks = checks + 1
	if ok then
		print(string.format("  PASS  %s", label))
	else
		failures = failures + 1
		print(string.format("  FAIL  %s%s", label, detail and ("  -- " .. detail) or ""))
	end
end

print("\nANIMATION IDS -- placeholders resolve to nil, never throw")

check(type(A.Player) == "table" and type(A.Boss) == "table" and type(A.Textures) == "table",
	"Player / Boss / Textures groups exist")
for _, name in ipairs({ "Idle", "Walk", "Run", "Crouch", "Push", "Death" }) do
	check(A.Player[name] ~= nil, "Player." .. name .. " is declared")
end
for _, name in ipairs({ "Reading", "Idle", "LookUp", "LookDown", "Shoot" }) do
	check(A.Boss[name] ~= nil, "Boss." .. name .. " is declared")
end
check(A.PlayerSpeeds.Walk == 4.5 and A.PlayerSpeeds.Run == 10.95 and A.PlayerSpeeds.Push == 3.15,
	"PlayerSpeeds match the exported clips")

-- 23.08.2026: the three Mixamo field clips (DeathField / Crawl / InjuredWalk)
-- are EXPLICITLY allowed to ship as placeholders (0) until published under the
-- group. Offline they must be declared, resolve to nil, load to nil without a
-- throw, and carry a Studio sequence + an AdjustSpeed reference so the Studio
-- bridge and PS1Animate have everything they need the day the ids arrive.
local fieldAnimator = { LoadAnimation = function(_, anim) return { Name = "track:" .. anim.Name } end }
for _, name in ipairs({ "DeathField", "Crawl", "InjuredWalk" }) do
	local id = A.Player[name]
	check(type(id) == "number" and id >= 0, "Player." .. name .. " is declared (0 allowed until published)")
	local seq = A.StudioSequences.Player[name]
	-- the raw "mixamo.com" imports carry 52 mixamorig:* bones the 20-bone PS1
	-- rig does not have; only the retargeted save on Anim_FieldClips fits.
	check(type(seq) == "table" and seq[1] == "Anim_FieldClips" and seq[2] == name,
		"StudioSequences.Player." .. name .. " names the retargeted Anim_FieldClips save")
	if id == 0 then
		check(A.resolve("Player", name) == nil, "resolve(Player." .. name .. ") placeholder -> nil")
		local okL, rL = pcall(A.load, fieldAnimator, "Player", name)
		check(okL and rL == nil, "load(Player." .. name .. ") placeholder -> nil offline, no throw")
	end
end
check(A.PlayerSpeeds.Crawl == 2.26 and A.PlayerSpeeds.InjuredWalk == 3.49,
	"PlayerSpeeds carry the measured Crawl / InjuredWalk hips trends")

-- 26.08.2026: der Studio-Fallback des BOSS zeigte auf Namen, die es nicht gibt.
-- Im Place nachgemessen: Anim_Idle traegt "idle", Anim_LookUp "lookup",
-- Anim_LookDown "lookdown", Anim_Shoot "shoot" -- FindFirstChild ist
-- case-sensitiv, also traf keine der fuenf Zeilen, und Reading zeigte sogar auf
-- LookUp. Sobald die veroeffentlichten Ids einmal nicht abspielbar sind, steht
-- der Boss dann ohne Track da: T-Pose. TableMannersBoss_AllAnims traegt alle
-- fuenf exakt richtig benannt, wie PS1Player_AllAnims beim Player.
--
-- Offline pruefbar ist die FORM des Mappings, nicht der Inhalt des Place: jede
-- Boss-Zeile muss auf den All-Anims-Halter zeigen und ihren eigenen Namen
-- tragen. Genau die beiden Fehler von vorher.
for _, name in ipairs({ "Reading", "Idle", "LookUp", "LookDown", "Shoot" }) do
	local seq = A.StudioSequences.Boss[name]
	check(type(seq) == "table" and seq[1] == "TableMannersBoss_AllAnims",
		"StudioSequences.Boss." .. name .. " points at TableMannersBoss_AllAnims",
		type(seq) == "table" and tostring(seq[1]) or "missing")
	check(type(seq) == "table" and seq[2] == name,
		"StudioSequences.Boss." .. name .. " names its OWN clip, not another",
		type(seq) == "table" and tostring(seq[2]) or "missing")
end

-- Every placeholder resolves to nil.
local placeholdersOk = true
for _, group in ipairs({ "Player", "Boss", "Textures" }) do
	for name, id in pairs(A[group]) do
		local r = A.resolve(group, name)
		if id == 0 and r ~= nil then placeholdersOk = false end
		if id > 0 and r ~= string.format("rbxassetid://%.0f", id) then placeholdersOk = false end
	end
end
check(placeholdersOk, "resolve: 0 -> nil, positive -> rbxassetid://<id>")
check(A.resolve("Textures", "PlayerNeutral") == "rbxassetid://136734973177857", "a published texture id resolves")
check(A.resolve("Nope", "Idle") == nil, "unknown group -> nil")
check(A.resolve("Player", "Nope") == nil, "unknown name -> nil")

-- load() never throws. Force one published slot to a placeholder temporarily,
-- so this proof remains valid as real animation ids are filled in.
local originalIdle = A.Player.Idle
A.Player.Idle = 0
local ok1, r1 = pcall(A.load, nil, "Player", "Idle")
check(ok1 and r1 == nil, "load(nil animator, placeholder) -> nil, no throw")
local fakeAnimator = { LoadAnimation = function(_, anim) return { Name = "track:" .. anim.Name } end }
local ok2, r2 = pcall(A.load, fakeAnimator, "Player", "Idle")
check(ok2 and r2 == nil, "load(animator, placeholder) -> nil (id is 0)")
-- Temporarily publish an id to prove the resolved path and the cache.
A.Player.Idle = 123456
local ok3, r3 = pcall(A.load, fakeAnimator, "Player", "Idle")
-- Prefix, not equality: load() names the cached Animation "<group>/<name>@<uri>"
-- so that changing a published id invalidates the cache instead of replaying the
-- old one. What this check is actually for is that the track came back from the
-- animator for THIS clip, which the prefix proves just as well.
check(ok3 and type(r3) == "table" and type(r3.Name) == "string"
	and r3.Name:sub(1, #"track:Player/Idle") == "track:Player/Idle",
	"load(animator, published) -> track", ok3 and type(r3) == "table" and tostring(r3.Name) or nil)
local throwing = { LoadAnimation = function() error("boom") end }
local ok4, r4 = pcall(A.load, throwing, "Player", "Idle")
check(ok4 and r4 == nil, "load swallows a LoadAnimation error -> nil")
A.Player.Idle = originalIdle
local restored = originalIdle > 0 and string.format("rbxassetid://%.0f", originalIdle) or nil
check(A.resolve("Player", "Idle") == restored, "published/placeholder value restores cleanly")

print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then
	print("MP-05 ANIMATIONIDS PROOF: FAIL")
	os.exit(1)
end
print("MP-05 ANIMATIONIDS PROOF: PASS")
os.exit(0)
