--!nonstrict

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Motion = {}

-- instance -> currently running tween, so we can cancel before replacing.
local active: { [Instance]: Tween } = setmetatable({}, { __mode = "k" })

local animationsEnabled = true

function Motion.setEnabled(on: boolean)
	animationsEnabled = on
end

function Motion.isEnabled(): boolean
	return animationsEnabled
end

function Motion.to(inst: Instance, info: TweenInfo, props: { [string]: any }): Tween?
	if not inst or not inst.Parent then return nil end

	-- Accessibility / performance escape hatch: apply instantly.
	if not animationsEnabled then
		for k, v in props do
			(inst :: any)[k] = v
		end
		return nil
	end

	local prev = active[inst]
	if prev then
		prev:Cancel()
	end

	local tween = TweenService:Create(inst, info, props)
	active[inst] = tween
	tween.Completed:Once(function()
		if active[inst] == tween then active[inst] = nil end
	end)
	tween:Play()
	return tween
end

function Motion.hover(inst, props) return Motion.to(inst, Theme.Motion.Hover, props) end
function Motion.press(inst, props) return Motion.to(inst, Theme.Motion.Press, props) end
function Motion.fade(inst, props)  return Motion.to(inst, Theme.Motion.Fade, props) end
function Motion.screen(inst, props) return Motion.to(inst, Theme.Motion.Screen, props) end
function Motion.slide(inst, props) return Motion.to(inst, Theme.Motion.Slide, props) end

function Motion.cancel(root: Instance)
	local t = active[root]
	if t then t:Cancel() active[root] = nil end
	for _, d in root:GetDescendants() do
		local dt = active[d]
		if dt then dt:Cancel() active[d] = nil end
	end
end

return Motion
