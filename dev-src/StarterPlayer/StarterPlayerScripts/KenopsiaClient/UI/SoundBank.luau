--!nonstrict

local SoundService = game:GetService("SoundService")

local SoundBank = {}

local sfxEnabled = true
local musicEnabled = true
local musicWanted = false
local sfx, music = nil, nil
local cursor: { [string]: number } = {}

function SoundBank.init()
	local root = SoundService:FindFirstChild("KenopsiaAudio")
	sfx = root and root:FindFirstChild("SFX")
	music = root and root:FindFirstChild("Music")
	if not sfx then
		warn("[SoundBank] SoundService.KenopsiaAudio.SFX missing - UI will be silent")
	end
end

function SoundBank.setSfxEnabled(on: boolean)
	sfxEnabled = on
end

-- Back-compat alias: "UI sound" toggle only gates one-shots now.
SoundBank.setEnabled = SoundBank.setSfxEnabled

local function haltMusic()
	if not music then return end
	for _, name in { "Intro", "Loop", "Outro" } do
		local s = music:FindFirstChild(name)
		if s and s.IsPlaying then s:Stop() end
	end
end

function SoundBank.setMusicEnabled(on: boolean)
	musicEnabled = on
	if on then
		if musicWanted then SoundBank.startMusic() end
	else
		haltMusic()
	end
end

local function pick(names: { string }): Sound?
	if not sfx then return nil end
	local key = names[1]
	local n = (cursor[key] or 0) % #names + 1
	cursor[key] = n
	local s = sfx:FindFirstChild(names[n])
	return (s and s:IsA("Sound")) and s or nil
end

local function play(names: { string })
	if not sfxEnabled then return end
	local s = pick(names)
	if s and s.SoundId ~= "" then
		SoundService:PlayLocalSound(s)
	end
end

-- Interface one-shots ------------------------------------------------------
function SoundBank.hover()  play({ "Hover" }) end
function SoundBank.click()  play({ "Click", "ClickAlt" }) end
function SoundBank.submit() play({ "Submit", "SubmitAlt" }) end

-- The Machine's voice ------------------------------------------------------
function SoundBank.denied()  play({ "AccessDenied" }) end
function SoundBank.granted() play({ "AccessGranted" }) end
function SoundBank.confirm() play({ "Confirm" }) end
function SoundBank.warning() play({ "Warning" }) end
function SoundBank.standClear() play({ "StandClear" }) end

function SoundBank.count(n: number)
	if n >= 1 and n <= 5 then
		play({ "Count" .. n })
	end
end

function SoundBank.startMusic()
	musicWanted = true
	if not musicEnabled or not music then return end
	local loop = music:FindFirstChild("Loop")
	if loop and not loop.IsPlaying then loop:Play() end
end

function SoundBank.stopMusic()
	musicWanted = false
	haltMusic()
end

function SoundBank.playOutro()
	if not musicEnabled or not music then return end
	SoundBank.stopMusic()
	local outro = music:FindFirstChild("Outro")
	if outro then outro:Play() end
end

return SoundBank
