--!strict
-- Replicated round state, carried on attributes so it syncs for free.
--
-- The one thing worth understanding here: we never replicate a ticking timer.
-- The server publishes an absolute end time on the server clock, and each
-- client counts down locally against workspace:GetServerTimeNow(). That is one
-- attribute write per phase instead of one per frame per player, and the
-- countdown stays smooth regardless of ping.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "KenopsiaState"

export type Phase = "Lobby" | "Intermission" | "Announce" | "Load" | "Countdown" | "Play" | "Score" | "Results"

local State = {}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
end

State.folder = folder

function State.setPhase(phase: Phase, duration: number?)
	folder:SetAttribute("PhaseEndsAt", if duration then workspace:GetServerTimeNow() + duration else nil)
	-- Phase last, so a client listening on Phase always reads a matching end time.
	folder:SetAttribute("Phase", phase)
end

function State.getPhase(): Phase
	return (folder:GetAttribute("Phase") or "Lobby") :: Phase
end

function State.timeLeft(): number
	local endsAt = folder:GetAttribute("PhaseEndsAt")
	if type(endsAt) ~= "number" then
		return 0
	end
	return math.max(0, endsAt - workspace:GetServerTimeNow())
end

function State.set(key: string, value: any)
	folder:SetAttribute(key, value)
end

function State.get(key: string): any
	return folder:GetAttribute(key)
end

return State
