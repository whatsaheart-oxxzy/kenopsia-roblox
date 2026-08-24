--!nonstrict
-- GLITCH TITLE (25.08.2026) -- the KENOPSIA wordmark on the landing screen.
--
-- The landing used a plain TextLabel at 72 px. This replaces it with an
-- authored wordmark that TEARS: the mark is cut into horizontal bands, and
-- every few seconds a burst shoves some of them sideways while two colour
-- copies split apart underneath. Between bursts it is perfectly still -- the
-- stillness is what makes the tear read as a fault rather than as decoration.
--
-- HOW THE TEAR IS DONE. Each band is a ClipsDescendants frame holding a
-- FULL-SIZE copy of the image, pushed up by that band's own offset, so the
-- bands together render one continuous mark with invisible seams. Shifting a
-- band's X is then a real slice of the letterforms -- not a second copy drawn
-- on top, which only ever looks like a shadow.
--
-- Cost: ~13 instances, and one thread that sleeps for seconds at a time. A
-- burst writes a handful of Positions across 2-4 frames of the 12 fps grid and
-- then goes quiet. Honours Motion.isEnabled() and ReducedMotionEnabled: with
-- either off the mark is simply a still image.
local GuiService = game:GetService("GuiService")

local Motion = require(script.Parent.Motion)
local Theme = require(script.Parent.Theme)

local GlitchTitle = {}

-- The wordmark: drawn from geometry in tools/menu-assets.py (no font file is
-- read, embedded or shipped) and uploaded 25.08.2026. 512 x 97.
GlitchTitle.Image = "rbxassetid://88647754582283"
GlitchTitle.Aspect = 512 / 97

local BANDS = 5
local STEP = 1 / 12          -- the house stepped-motion grid
local QUIET_MIN, QUIET_MAX = 3.0, 7.0
-- Measured on the live landing 25.08.2026: at 5 px / 11 px the tear was there
-- but read as a rendering artefact rather than as a fault. Against a 520 px
-- mark the displacement has to be a few percent of the width before the eye
-- calls it a glitch, and the colour split has to actually separate.
local CHROMA_PX = 9
local CHROMA_ALPHA = 0.45
local SLICE_PX = 22
local DROPOUT_CHANCE = 0.35   -- of bursts that also lose a band for one frame

local function newImage(parent, name, colour, alpha, z)
	local i = Instance.new("ImageLabel")
	i.Name = name
	i.BackgroundTransparency = 1
	i.BorderSizePixel = 0
	i.Image = GlitchTitle.Image
	i.ImageColor3 = colour
	i.ImageTransparency = alpha
	-- Pixelated: the mark is authored small on purpose, so it magnifies with
	-- hard edges instead of going soft.
	i.ResampleMode = Enum.ResamplerMode.Pixelated
	i.ZIndex = z
	i.Parent = parent
	return i
end

-- parent: where the title goes. opts.width sets the size; the height always
-- follows the image's own aspect so the mark is never stretched.
function GlitchTitle.build(parent, opts)
	opts = opts or {}
	local width = opts.width or 520
	local height = math.floor(width / GlitchTitle.Aspect + 0.5)
	local colour = opts.color or Theme.Cold.Bright
	-- The split needs two DIFFERENT hues or it reads as a blur rather than as a
	-- signal fault. In the cold set that is the focus cyan against the one warm
	-- value in the whole menu, the burnt orange -- which is a real complementary
	-- split without being the red/cyan cliche.
	local chromaA = opts.chromaA or Theme.Cold.Focus
	local chromaB = opts.chromaB or Theme.Cold.Error

	local frame = Instance.new("Frame")
	frame.Name = opts.name or "Title"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(width, height)
	frame.Position = opts.position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = opts.anchorPoint or Vector2.new(0, 0)
	frame.ZIndex = opts.zIndex or 2
	frame.Parent = parent

	local z = frame.ZIndex
	local ca = newImage(frame, "ChromaA", chromaA, 0.72, z)
	ca.Size = UDim2.fromOffset(width, height)
	local cb = newImage(frame, "ChromaB", chromaB, 0.72, z)
	cb.Size = UDim2.fromOffset(width, height)

	local bandHolder = Instance.new("Frame")
	bandHolder.Name = "Bands"
	bandHolder.BackgroundTransparency = 1
	bandHolder.BorderSizePixel = 0
	bandHolder.Size = UDim2.fromScale(1, 1)
	bandHolder.ZIndex = z + 1
	bandHolder.Parent = frame

	local bands = {}
	for i = 1, BANDS do
		-- The last band takes the rounding remainder, so the bands always add
		-- up to exactly the mark's height and no seam line can appear.
		local top = math.floor((i - 1) * height / BANDS + 0.5)
		local bottom = (i == BANDS) and height or math.floor(i * height / BANDS + 0.5)
		local band = Instance.new("Frame")
		band.Name = "Band" .. i
		band.BackgroundTransparency = 1
		band.BorderSizePixel = 0
		band.ClipsDescendants = true
		band.Position = UDim2.fromOffset(0, top)
		band.Size = UDim2.fromOffset(width, bottom - top)
		band.ZIndex = z + 1
		band.Parent = bandHolder
		local img = newImage(band, "Img", colour, 0, z + 1)
		img.Size = UDim2.fromOffset(width, height)
		img.Position = UDim2.fromOffset(0, -top)
		bands[i] = band
	end

	local handle = {
		frame = frame,
		bands = bands,
		chromaA = ca,
		chromaB = cb,
		alive = true,
	}

	local function rest()
		ca.Position = UDim2.fromOffset(0, 0)
		cb.Position = UDim2.fromOffset(0, 0)
		ca.ImageTransparency = 1
		cb.ImageTransparency = 1
		for _, b in ipairs(bands) do
			b.Position = UDim2.fromOffset(0, b.Position.Y.Offset)
			local img = b:FindFirstChild("Img")
			if img then img.ImageTransparency = 0 end
		end
	end
	rest()

	local function motionOk()
		if not handle.alive then return false end
		local ok, reduced = pcall(function() return GuiService.ReducedMotionEnabled end)
		if ok and reduced then return false end
		return Motion.isEnabled()
	end

	-- One burst: 2-4 frames of tear, then everything snaps back to rest.
	-- Every frame re-rolls, so a burst never repeats the same shape twice.
	function handle.burst()
		if not motionOk() then return end
		local frames = math.random(2, 4)
		local dropout = math.random() < DROPOUT_CHANCE
		for f = 1, frames do
			if not handle.alive then return end
			if f == frames then
				rest()
			else
				local dx = math.random(4, CHROMA_PX)
				ca.Position = UDim2.fromOffset(dx, 0)
				cb.Position = UDim2.fromOffset(-dx, 0)
				ca.ImageTransparency = CHROMA_ALPHA
				cb.ImageTransparency = CHROMA_ALPHA
				-- one to three bands move; the rest hold, so the mark SHEARS
				-- rather than sliding as a whole
				for _, b in ipairs(bands) do
					b.Position = UDim2.fromOffset(0, b.Position.Y.Offset)
					local img = b:FindFirstChild("Img")
					if img then img.ImageTransparency = 0 end
				end
				for _ = 1, math.random(1, 3) do
					local b = bands[math.random(#bands)]
					-- never a nudge: a shift under a third of the range reads
					-- as a wobble, and a wobble looks like a bug in the layout
					local shift = math.random(SLICE_PX // 3, SLICE_PX)
					if math.random() < 0.5 then shift = -shift end
					b.Position = UDim2.fromOffset(shift, b.Position.Y.Offset)
				end
				-- signal dropout: one band loses its picture for a single frame
				if dropout and f == 1 then
					local b = bands[math.random(#bands)]
					local img = b:FindFirstChild("Img")
					if img then img.ImageTransparency = 0.85 end
				end
			end
			task.wait(STEP)
		end
		rest()
	end

	task.spawn(function()
		while handle.alive do
			task.wait(QUIET_MIN + math.random() * (QUIET_MAX - QUIET_MIN))
			if handle.alive and frame.Parent and frame.Visible then
				handle.burst()
			end
		end
	end)

	function handle.destroy()
		handle.alive = false
		if frame.Parent then frame:Destroy() end
	end

	return handle
end

return GlitchTitle
