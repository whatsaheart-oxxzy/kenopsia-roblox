--!strict

local Theme = {}

Theme.Color = {
	Screen    = Color3.fromHex("030906"), -- deep phosphor black
	Panel     = Color3.fromHex("07140D"), -- raised card
	Phosphor  = Color3.fromHex("78FFAA"), -- primary / active
	Idle      = Color3.fromHex("5CCB8A"), -- readable idle body text
	Dim       = Color3.fromHex("307852"), -- rules, borders, disabled
	Amber     = Color3.fromHex("FFBA3C"), -- warnings
	Red       = Color3.fromHex("FF4A3A"), -- errors
	White      = Color3.fromHex("D8FFE8"),
}

-- COLD TERMINAL (25.08.2026).
-- The main menu's palette. It replaces the warm "street retro" set that stood
-- here before: outside the facility is cold, and the phosphor green of the
-- machine screens is what you get once you are inside it. That break is the
-- point, so the two palettes never share a value.
--
-- White is RESERVED for the selection streak, the way #FF1818 is reserved for
-- FIRE/PUNCH elsewhere: if anything else goes pure white the bar stops reading
-- as the brightest thing on screen. Error stays burnt orange -- the only warm
-- signal in the whole menu, which is exactly why it carries.
Theme.Cold = {
	Ground   = Color3.fromHex("020609"), -- deepest ground
	Panel    = Color3.fromHex("06121A"), -- raised surface, boxed cells
	Text     = Color3.fromHex("BFE9F5"), -- primary text
	Bright   = Color3.fromHex("E8FBFF"), -- headings, values
	Dim      = Color3.fromHex("4E7C8A"), -- secondary text, rules, disabled
	Focus    = Color3.fromHex("6FD8F0"), -- focus / active
	Streak   = Color3.fromHex("FFFFFF"), -- THE SELECTION BAR ONLY
	OnStreak = Color3.fromHex("04121A"), -- text sitting on the bar
	Error    = Color3.fromHex("B56A45"), -- burnt orange, never red
}

-- The role slots the menu modules already reference, re-pointed at the cold
-- set. Kept as an alias rather than renamed at ~90 call sites: the KEYS here
-- are role names now, not colour names, so read `Amber` as "focus" and `Sage`
-- as "dim". New code should use Theme.Cold directly.
Theme.Street = {
	Ink      = Theme.Cold.Ground,
	Asphalt  = Theme.Cold.Panel,
	OffWhite = Theme.Cold.Text,
	Sage     = Theme.Cold.Dim,
	Amber    = Theme.Cold.Focus,
	Denim    = Theme.Cold.Dim,
	Error    = Theme.Cold.Error,
}

-- Hard, flat surfaces: minimal rounding, crisp outlines, offset drop shadows.
-- No glass, no blur, no neon.
Theme.StreetRadius = { None = 0, Soft = 2 }
Theme.StreetStroke = { Hairline = 1, Normal = 2 }
Theme.StreetShadow = { Offset = 3, OffsetLarge = 4 }

-- Interactive sizing. Roblox's own floor is 44px; the menu holds itself to 48,
-- and primary actions to 56-64.
Theme.Touch = { Min = 48, Action = 56, ActionLarge = 64 }

-- Diegetic party wall. The 8 x 5.4 stud display has this exact aspect ratio,
-- so a fixed canvas stays sharp while the physical screen and camera remain
-- untouched. All selectable rows clear the 48 px cross-platform input floor.
Theme.Party = {
	Canvas = Vector2.new(960, 648),
	PanelTransparency = 0.12,
	RowHeight = 56,
	RowGap = 8,
	Marker = Color3.fromHex("B56A45"),
	RuleTransparency = 0.42,
	InactiveTransparency = 0.18,
}

-- Denk One for display type, Code for status lines and room codes.
Theme.TitleFont = Enum.Font.DenkOne
Theme.MonoFont = Enum.Font.Code

Theme.Font = Enum.Font.Code
Theme.Text = { Title = 96, Heading = 58, Body = 38, Small = 28, Tiny = 22 }
Theme.Pad  = { XS = 6, S = 12, M = 20, L = 34, XL = 56 }

-- Corner radii and stroke weights, so every surface agrees.
Theme.Radius = { S = 4, M = 8, L = 14 }
Theme.Stroke = { Hairline = 1, Normal = 2, Bold = 3 }

-- Roblox's own guidance is a 44px minimum touch target.
Theme.MinTouchPx = 44

Theme.Asset = {
	Background = "rbxassetid://95645027254703", -- VHS static plate
	Cursor     = "rbxassetid://135426270156789",
	Scanlines  = "rbxassetid://85404279414801",
	Noise      = "rbxassetid://99955208110383",
	Vignette   = "rbxassetid://122512397007287",
	SelectionStreak = "rbxassetid://134334042347021",
}
-- Back-compat for the CRT module's existing lookups.
Theme.CRT = {
	Scanlines = Theme.Asset.Scanlines,
	Noise = Theme.Asset.Noise,
	Vignette = Theme.Asset.Vignette,
}

Theme.Credits = {
	Group = "Kittypawsssv",
	Developer = "iLoveKilIs",
	DeveloperRoles = { "Developer", "Builder", "Modeller" },
}

Theme.Motion = {
	Hover   = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Press   = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Screen  = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slide   = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Fade    = TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	Snap    = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

-- Session settings. No DataStore in the MVP by design, so these reset on leave.
Theme.Defaults = {
	CrtIntensity  = 1.0,   -- 0 .. 1.5
	ReduceFlicker = false, -- accessibility: stops noise churn and glitches
	Scanlines     = true,
	Background    = true,
	CustomCursor  = true,
	UiSound       = true,
	Animations    = true,  -- off => instant screen swaps, no tweens
	TextScale     = 1.0,   -- 0.8 .. 1.3
}

function Theme.label(parent: Instance, text: string, size: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.Font
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color or Theme.Color.Phosphor
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.RichText = false
	l.Parent = parent
	return l
end

function Theme.corner(parent: Instance, radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Radius.M)
	c.Parent = parent
	return c
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Color.Dim
	s.Thickness = thickness or Theme.Stroke.Normal
	s.Transparency = transparency or 0.4
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Vertical phosphor sheen. Purely decorative, one instance, no runtime cost.
function Theme.sheen(parent: Instance, topT: number?, bottomT: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, topT or 0.85),
		NumberSequenceKeypoint.new(1, bottomT or 1),
	})
	g.Parent = parent
	return g
end

return Theme
