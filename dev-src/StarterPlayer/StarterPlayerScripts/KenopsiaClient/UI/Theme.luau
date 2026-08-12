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
