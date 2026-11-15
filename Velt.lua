--[[
    ██╗   ██╗███████╗██╗  ████████╗
    ██║   ██║██╔════╝██║  ╚══██╔══╝
    ██║   ██║█████╗  ██║     ██║
    ╚██╗ ██╔╝██╔══╝  ██║     ██║
     ╚████╔╝ ███████╗███████╗██║
      ╚═══╝  ╚══════╝╚══════╝╚═╝

    Velt UI Library v2.0.0

    Usage:
        local Velt = loadstring(game:HttpGet("url"))()
        local Window = Velt:CreateWindow({
            Title = "My Script",
            Theme = "Obsidian",
            MinimizeKey = Enum.KeyCode.RightShift,
            SaveConfig = true,
            ConfigFolder = "VeltConfig"
        })
        local Tab = Window:AddTab({ Title = "Main" })
        local Section = Tab:AddSection({ Title = "Combat" })
        Section:AddToggle({ Title = "Enabled", Default = false, Flag = "AimbotOn", Callback = function(v) end })

    v2.0  new look: icon rail sidebar (labels on wide windows), page header with search, collapsible
          section cards, two columns on wide windows, tab groups, stat tiles, new themes.
          Icons come from velt_icons.png in the Velt asset repo (letter badges if it can't be downloaded).
    v1.1 additions
        - Sage theme (default), floating logo button (tap = open/close, drag = move), close hides
        - Window fits the phone screen, resize grip, Window:SetSize / :Toggle / .Gui / .OnVisibility
        - Logo: nil = default Velt logo (downloaded once), false = none, or a file / URL / asset id
        - Profile card (Roblox headshot) -> Config tab with named presets (SaveConfig = true)
        - Flat v0 API still works: Window:AddTab("Name"); tab:AddToggle{Name=..}; tab:AddSection("Title")
]]

--[[
	VELT // OS  —  UI Library + Admin Hub
	Style   : Obsidian-glass, warm-gold accent, spring-physics animations
	Merged  : standard skeleton + full interactive-FX version (Aether OS v2.4 reference)
	Rename  : AetherAdminOS  →  VeltOS   |   AETHER // OS  →  VELT // OS
	Platform: Roblox executor (LocalScript)

	Controls
	  RightShift   — toggle panel open/close
	  /            — focus live search bar
	  Esc (search) — clear & dismiss search
]]



-- ============================================================
-- SERVICES
-- ============================================================
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService     = game:GetService("RunService")
local Lighting       = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera
local mouse     = player:GetMouse()

-- ── Admin guard (edit ADMIN_IDS to match your UserId) ──
local ADMIN_IDS = { [12345678] = true }
if not (RunService:IsStudio() or ADMIN_IDS[player.UserId]) then return end

-- ── Optional server remote ──
local adminRemote = ReplicatedStorage:FindFirstChild("AdminActionRemote")
local function fireServer(action, target, value)
	if adminRemote then adminRemote:FireServer(action, target, value) end
end

-- ============================================================
-- DESIGN TOKENS
-- ============================================================
local Accents = {
	{ Name = "Champagne", Color = Color3.fromRGB(232, 184, 102) },
	{ Name = "Cyan",      Color = Color3.fromRGB(56,  189, 248) },
	{ Name = "Emerald",   Color = Color3.fromRGB(52,  211, 153) },
	{ Name = "Crimson",   Color = Color3.fromRGB(244, 63,  94)  },
	{ Name = "Platinum",  Color = Color3.fromRGB(226, 232, 240) },
}

local Theme = {
	Bg          = Color3.fromRGB(13,  15,  20),
	Sidebar     = Color3.fromRGB(18,  20,  27),
	Card        = Color3.fromRGB(24,  27,  36),
	CardHover   = Color3.fromRGB(31,  35,  47),
	Stroke      = Color3.fromRGB(48,  54,  70),
	StrokeHover = Color3.fromRGB(82,  92,  118),
	Text        = Color3.fromRGB(244, 246, 250),
	SubText     = Color3.fromRGB(145, 153, 172),
	ToggleOff   = Color3.fromRGB(45,  50,  65),
	Accent      = Accents[1].Color,
}

-- ── Reactive accent system ──
local accentListeners = {}
local function onAccentChange(fn)
	table.insert(accentListeners, fn)
	fn(Theme.Accent)
end
local function setAccent(color)
	Theme.Accent = color
	mainStroke.Color = color
	for _, fn in ipairs(accentListeners) do fn(color) end
end

-- ── TweenInfo presets ──
local TI = {
	fast   = TweenInfo.new(0.18, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	hover  = TweenInfo.new(0.18, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	bounce = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	spring = TweenInfo.new(0.32, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	quint  = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	linear = function(t) return TweenInfo.new(t, Enum.EasingStyle.Linear) end,
	sine   = TweenInfo.new(1,    Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut),
}

local function tween(obj, info, props)
	TweenService:Create(obj, info, props):Play()
end

-- ============================================================
-- INTERACTIVE FX  (hover scale + stroke glow + click bounce)
-- ============================================================
local function attachFX(guiObj, opts)
	opts = opts or {}
	local hs      = opts.hoverScale  or 1.04
	local cs      = opts.clickScale  or 0.94
	local strokeObj = opts.stroke
	local glowOnHover = opts.glowOnHover

	local uiScale = guiObj:FindFirstChildOfClass("UIScale")
		or Instance.new("UIScale", guiObj)
	uiScale.Scale = 1

	local hovered = false

	guiObj.MouseEnter:Connect(function()
		hovered = true
		tween(uiScale, TI.hover, { Scale = hs })
		if strokeObj then
			tween(strokeObj, TI.hover, { Color = glowOnHover and Theme.Accent or Theme.StrokeHover })
		end
	end)
	guiObj.MouseLeave:Connect(function()
		hovered = false
		tween(uiScale, TI.hover, { Scale = 1 })
		if strokeObj then
			tween(strokeObj, TI.hover, { Color = Theme.Stroke })
		end
	end)
	if guiObj:IsA("GuiButton") then
		guiObj.MouseButton1Down:Connect(function()
			tween(uiScale, TI.fast, { Scale = cs })
		end)
		guiObj.MouseButton1Up:Connect(function()
			tween(uiScale, TI.bounce, { Scale = hovered and hs or 1 })
		end)
	end
end

-- ============================================================
-- ScreenGui
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name              = "VeltOS"
screenGui.ResetOnSpawn      = false
screenGui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset    = true
screenGui.Parent            = playerGui

-- ============================================================
-- TOAST NOTIFICATION  (slide-in from right, fade-out)
-- ============================================================
local toastHolder = Instance.new("Frame", screenGui)
toastHolder.Size                = UDim2.new(0, 270, 0, 240)
toastHolder.Position            = UDim2.new(1, -286, 1, -256)
toastHolder.BackgroundTransparency = 1
toastHolder.ZIndex              = 100
local toastLayout = Instance.new("UIListLayout", toastHolder)
toastLayout.VerticalAlignment   = Enum.VerticalAlignment.Bottom
toastLayout.Padding             = UDim.new(0, 6)

local function notify(msg, duration)
	duration = duration or 2.6
	local wrapper = Instance.new("Frame", toastHolder)
	wrapper.Size               = UDim2.new(1, 0, 0, 36)
	wrapper.BackgroundTransparency = 1

	local toast = Instance.new("Frame", wrapper)
	toast.Size            = UDim2.new(1, 0, 1, 0)
	toast.Position        = UDim2.new(0.4, 0, 0, 0)
	toast.BackgroundColor3 = Theme.Sidebar
	toast.BackgroundTransparency = 1
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

	local st = Instance.new("UIStroke", toast)
	st.Transparency = 1
	onAccentChange(function(c) st.Color = c end)

	local bar = Instance.new("Frame", toast)
	bar.Size              = UDim2.new(0, 3, 0, 18)
	bar.Position          = UDim2.new(0, 7, 0.5, -9)
	bar.BackgroundTransparency = 1
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	onAccentChange(function(c) bar.BackgroundColor3 = c end)

	local icon = Instance.new("TextLabel", toast)
	icon.Size = UDim2.new(0, 20, 1, 0)
	icon.Position = UDim2.new(0, 14, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "◈"
	icon.TextTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 13
	onAccentChange(function(c) icon.TextColor3 = c end)

	local lbl = Instance.new("TextLabel", toast)
	lbl.Size              = UDim2.new(1, -42, 1, 0)
	lbl.Position          = UDim2.new(0, 38, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text              = msg
	lbl.TextColor3        = Theme.Text
	lbl.TextTransparency  = 1
	lbl.Font              = Enum.Font.GothamMedium
	lbl.TextSize          = 11
	lbl.TextXAlignment    = Enum.TextXAlignment.Left

	-- slide in
	tween(toast, TI.quint, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.1 })
	tween(st,   TI.quint, { Transparency = 0.15 })
	tween(bar,  TI.quint, { BackgroundTransparency = 0 })
	tween(icon, TI.quint, { TextTransparency = 0 })
	tween(lbl,  TI.quint, { TextTransparency = 0 })

	task.delay(duration, function()
		if not wrapper or not wrapper.Parent then return end
		local out = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(toast, out, { Position = UDim2.new(0.35, 0, 0, 0), BackgroundTransparency = 1 })
		tween(st,   out, { Transparency = 1 })
		tween(bar,  out, { BackgroundTransparency = 1 })
		tween(icon, out, { TextTransparency = 1 })
		tween(lbl,  out, { TextTransparency = 1 })
		task.wait(0.28)
		if wrapper then wrapper:Destroy() end
	end)
end

-- ============================================================
-- DYNAMIC ISLAND PILL  (minimize mode)
-- ============================================================
local island = Instance.new("TextButton", screenGui)
island.Name                   = "VeltIsland"
island.Size                   = UDim2.new(0, 210, 0, 36)
island.Position               = UDim2.new(0.5, -105, 0, 14)
island.BackgroundColor3       = Color3.fromRGB(13, 15, 22)
island.BackgroundTransparency = 0.1
island.Text                   = ""
island.AutoButtonColor        = false
island.Visible                = false
island.ZIndex                 = 60
Instance.new("UICorner", island).CornerRadius = UDim.new(1, 0)

local islandStroke = Instance.new("UIStroke", island)
islandStroke.Thickness = 1.2
onAccentChange(function(c) islandStroke.Color = c end)

local islandScale = Instance.new("UIScale", island)
islandScale.Scale = 0.85
attachFX(island, { hoverScale = 1.05, clickScale = 0.95, stroke = islandStroke, glowOnHover = true })

-- pulsing status dot
local islandDot = Instance.new("Frame", island)
islandDot.Size     = UDim2.new(0, 8, 0, 8)
islandDot.Position = UDim2.new(0, 14, 0.5, -4)
Instance.new("UICorner", islandDot).CornerRadius = UDim.new(1, 0)
onAccentChange(function(c) islandDot.BackgroundColor3 = c end)

task.spawn(function()
	while islandDot and islandDot.Parent do
		tween(islandDot, TI.sine, { BackgroundTransparency = 0.65 })
		task.wait(1)
		tween(islandDot, TI.sine, { BackgroundTransparency = 0 })
		task.wait(1)
	end
end)

local islandLbl = Instance.new("TextLabel", island)
islandLbl.Size                = UDim2.new(1, -34, 1, 0)
islandLbl.Position            = UDim2.new(0, 30, 0, 0)
islandLbl.BackgroundTransparency = 1
islandLbl.Text                = "VELT // OS   •   Klik buka"
islandLbl.TextColor3          = Theme.Text
islandLbl.Font                = Enum.Font.GothamBold
islandLbl.TextSize            = 11
islandLbl.TextXAlignment      = Enum.TextXAlignment.Left

-- ============================================================
-- MAIN GLASS CHASSIS  (CanvasGroup for zoom-fade transition)
-- ============================================================
local mainFrame = Instance.new("CanvasGroup", screenGui)
mainFrame.Name              = "VeltMain"
mainFrame.Size              = UDim2.new(0, 680, 0, 460)
mainFrame.Position          = UDim2.new(0.5, -340, 0.5, -230)
mainFrame.BackgroundTransparency = 1
mainFrame.GroupTransparency = 1
mainFrame.Visible           = true
mainFrame.ZIndex            = 30
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)

local mainScale = Instance.new("UIScale", mainFrame)
mainScale.Scale = 0.90

-- glass background layer (opacity slider won't fight GroupTransparency)
local glassBg = Instance.new("Frame", mainFrame)
glassBg.Size                = UDim2.new(1, 0, 1, 0)
glassBg.BackgroundColor3    = Theme.Bg
glassBg.BackgroundTransparency = 0.12
glassBg.BorderSizePixel     = 0
glassBg.ZIndex              = 0
Instance.new("UICorner", glassBg).CornerRadius = UDim.new(0, 16)

-- subtle gradient wash
local mainGrad = Instance.new("UIGradient", glassBg)
mainGrad.Rotation = 135
mainGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 0.08),
})

-- chassis border
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color     = Theme.Stroke
mainStroke.Thickness = 1.2

-- cursor-driven spotlight (radial glow follows mouse inside chassis)
local spotlight = Instance.new("Frame", mainFrame)
spotlight.Name              = "Spotlight"
spotlight.Size              = UDim2.new(1, 0, 1, 0)
spotlight.BackgroundTransparency = 1
spotlight.ZIndex            = 1
spotlight.BorderSizePixel   = 0
-- We draw the spotlight via a UIGradient that we reposition each frame
local spotGrad = Instance.new("UIGradient", spotlight)
spotGrad.Rotation = 0
onAccentChange(function(c)
	spotGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
	})
end)
spotGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.88),
	NumberSequenceKeypoint.new(0.45, 0.97),
	NumberSequenceKeypoint.new(1, 1),
})

-- top specular line
local specular = Instance.new("Frame", mainFrame)
specular.Name                = "Specular"
specular.Size                = UDim2.new(0.76, 0, 0, 1)
specular.Position            = UDim2.new(0.12, 0, 0, 0)
specular.BackgroundTransparency = 0
specular.BorderSizePixel     = 0
specular.ZIndex              = 5
local specGrad = Instance.new("UIGradient", specular)
specGrad.Rotation = 0
onAccentChange(function(c)
	specGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 0, 0)),
		ColorSequenceKeypoint.new(0.5, c),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 0, 0)),
	})
	specGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1,   1),
	})
end)

-- accent border pulse on window enter/leave
mainFrame.MouseEnter:Connect(function()
	tween(mainStroke, TI.fast, { Color = Theme.Accent, Thickness = 1.5 })
	tween(specular,   TI.fast, { BackgroundTransparency = 0 })
end)
mainFrame.MouseLeave:Connect(function()
	tween(mainStroke, TI.fast, { Color = Theme.Stroke, Thickness = 1.2 })
	tween(specular,   TI.fast, { BackgroundTransparency = 0.3 })
end)

-- ── RenderStepped: cursor spotlight + mouse-parallax tilt ──
RunService.RenderStepped:Connect(function()
	if not mainFrame.Visible or mainFrame.GroupTransparency > 0.9 then return end
	local abs = mainFrame.AbsolutePosition
	local sz  = mainFrame.AbsoluteSize
	if sz.X < 1 or sz.Y < 1 then return end
	local mx, my = mouse.X - abs.X, mouse.Y - abs.Y
	local nx = math.clamp(mx / sz.X, 0, 1)   -- 0..1 relative
	local ny = math.clamp(my / sz.Y, 0, 1)

	-- reposition gradient origin so it appears to follow the cursor
	spotGrad.Offset = Vector2.new(nx - 0.5, ny - 0.5)

	-- subtle parallax: glass bg drifts opposite to cursor (visionOS feel)
	local px = (nx - 0.5) * -6
	local py = (ny - 0.5) * -4
	glassBg.Position = UDim2.fromOffset(px, py)
end)

-- ============================================================
-- OPEN / MINIMIZE TRANSITION  (zoom-fade + spring scale)
-- ============================================================
local isPanelOpen      = true
local isAnimatingPanel = false

local function playOpenAnim()
	mainFrame.Visible          = true
	mainFrame.GroupTransparency = 1
	mainScale.Scale             = 0.90
	tween(mainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { GroupTransparency = 0 })
	tween(mainScale, TI.spring, { Scale = 1 })
end

local function setMinimized(minimized)
	if isAnimatingPanel or isPanelOpen == (not minimized) then return end
	isAnimatingPanel = true
	isPanelOpen      = not minimized

	if minimized then
		local closeInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(mainFrame, closeInfo, { GroupTransparency = 1 })
		local t = TweenService:Create(mainScale, closeInfo, { Scale = 0.90 })
		t:Play()
		t.Completed:Wait()
		mainFrame.Visible = false

		island.Visible  = true
		islandScale.Scale = 0.80
		tween(islandScale, TI.spring, { Scale = 1 })
	else
		local t2 = TweenService:Create(islandScale,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.80 })
		t2:Play(); t2.Completed:Wait()
		island.Visible = false
		playOpenAnim()
		task.wait(0.30)
	end
	isAnimatingPanel = false
end

island.MouseButton1Click:Connect(function() setMinimized(false) end)
task.defer(playOpenAnim)

-- ============================================================
-- TOPBAR
-- ============================================================
local topbar = Instance.new("Frame", mainFrame)
topbar.Size                 = UDim2.new(1, 0, 0, 48)
topbar.BackgroundColor3     = Theme.Sidebar
topbar.BackgroundTransparency = 0.22
topbar.BorderSizePixel      = 0
topbar.ZIndex               = 4

Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 16)
-- bottom-clip the rounded corners
local topClip = Instance.new("Frame", topbar)
topClip.Size                = UDim2.new(1, 0, 0.5, 0)
topClip.Position            = UDim2.new(0, 0, 0.5, 0)
topClip.BackgroundColor3    = Theme.Sidebar
topClip.BackgroundTransparency = 0.22
topClip.BorderSizePixel     = 0
topClip.ZIndex              = 3

local topLine = Instance.new("Frame", topbar)
topLine.Size               = UDim2.new(1, 0, 0, 1)
topLine.Position           = UDim2.new(0, 0, 1, -1)
topLine.BackgroundColor3   = Theme.Stroke
topLine.BorderSizePixel    = 0

-- brand wordmark
local brand = Instance.new("TextLabel", topbar)
brand.Size                 = UDim2.new(0, 160, 1, 0)
brand.Position             = UDim2.new(0, 18, 0, 0)
brand.BackgroundTransparency = 1
brand.Text                 = "VELT // OS"
brand.Font                 = Enum.Font.GothamBold
brand.TextSize             = 13
brand.TextXAlignment       = Enum.TextXAlignment.Left
brand.ZIndex               = 5
onAccentChange(function(c) brand.TextColor3 = c end)

-- ── Live search bar ──
local searchBox = Instance.new("TextBox", topbar)
searchBox.Size              = UDim2.new(0, 220, 0, 28)
searchBox.Position          = UDim2.new(0, 170, 0.5, -14)
searchBox.BackgroundColor3  = Theme.Card
searchBox.BackgroundTransparency = 0.15
searchBox.PlaceholderText   = "Cari fitur…  (tekan /)"
searchBox.PlaceholderColor3 = Theme.SubText
searchBox.Text              = ""
searchBox.TextColor3        = Theme.Text
searchBox.Font              = Enum.Font.Gotham
searchBox.TextSize          = 11
searchBox.ClearTextOnFocus  = false
searchBox.ZIndex            = 5
Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 8)
local sbPad = Instance.new("UIPadding", searchBox)
sbPad.PaddingLeft = UDim.new(0, 10)
local sbStroke = Instance.new("UIStroke", searchBox)
sbStroke.Color = Theme.Stroke; sbStroke.Thickness = 1
searchBox.Focused:Connect(function()
	tween(sbStroke, TI.fast, { Color = Theme.Accent })
end)
searchBox.FocusLost:Connect(function()
	tween(sbStroke, TI.fast, { Color = Theme.Stroke })
end)

-- ── 5-dot accent switcher ──
local dotHolder = Instance.new("Frame", topbar)
dotHolder.Size              = UDim2.new(0, 118, 0, 26)
dotHolder.Position          = UDim2.new(1, -172, 0.5, -13)
dotHolder.BackgroundTransparency = 1
dotHolder.ZIndex            = 5
local dotList = Instance.new("UIListLayout", dotHolder)
dotList.FillDirection        = Enum.FillDirection.Horizontal
dotList.VerticalAlignment    = Enum.VerticalAlignment.Center
dotList.HorizontalAlignment  = Enum.HorizontalAlignment.Center
dotList.Padding              = UDim.new(0, 8)

for _, acc in ipairs(Accents) do
	local dot = Instance.new("TextButton", dotHolder)
	dot.Size              = UDim2.new(0, 14, 0, 14)
	dot.BackgroundColor3  = acc.Color
	dot.Text              = ""
	dot.AutoButtonColor   = false
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	attachFX(dot, { hoverScale = 1.32, clickScale = 0.80 })
	dot.MouseButton1Click:Connect(function()
		setAccent(acc.Color)
		notify("Aksen: " .. acc.Name)
	end)
end

-- ── Minimize button ──
local minBtn = Instance.new("TextButton", topbar)
minBtn.Size              = UDim2.new(0, 28, 0, 28)
minBtn.Position          = UDim2.new(1, -44, 0.5, -14)
minBtn.BackgroundColor3  = Theme.Card
minBtn.Text              = "—"
minBtn.TextColor3        = Theme.SubText
minBtn.Font              = Enum.Font.GothamBold
minBtn.TextSize          = 12
minBtn.AutoButtonColor   = false
minBtn.ZIndex            = 5
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)
local minStroke = Instance.new("UIStroke", minBtn)
minStroke.Color = Theme.Stroke; minStroke.Thickness = 1
attachFX(minBtn, { hoverScale = 1.1, clickScale = 0.88, stroke = minStroke, glowOnHover = true })
minBtn.MouseButton1Click:Connect(function() setMinimized(true) end)

-- ── Smooth drag (topbar) ──
local dragging, dragStart, dragStartPos
topbar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging      = true
		dragStart     = input.Position
		dragStartPos  = mainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
local dragInput
topbar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local d = input.Position - dragStart
		mainFrame.Position = UDim2.new(
			dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
			dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y)
	end
end)

-- ============================================================
-- SIDEBAR
-- ============================================================
local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size                = UDim2.new(0, 152, 1, -48)
sidebar.Position            = UDim2.new(0, 0, 0, 48)
sidebar.BackgroundColor3    = Theme.Sidebar
sidebar.BackgroundTransparency = 0.30
sidebar.BorderSizePixel     = 0
sidebar.ZIndex              = 3

local sideLine = Instance.new("Frame", sidebar)
sideLine.Size               = UDim2.new(0, 1, 1, 0)
sideLine.Position           = UDim2.new(1, -1, 0, 0)
sideLine.BackgroundColor3   = Theme.Stroke
sideLine.BorderSizePixel    = 0

-- spring indicator pill (slides to active tab)
local sideIndicator = Instance.new("Frame", sidebar)
sideIndicator.Size          = UDim2.new(0, 3, 0, 20)
sideIndicator.Position      = UDim2.new(0, 8, 0, 20)
sideIndicator.BorderSizePixel = 0
sideIndicator.ZIndex        = 4
Instance.new("UICorner", sideIndicator).CornerRadius = UDim.new(1, 0)
onAccentChange(function(c) sideIndicator.BackgroundColor3 = c end)

local sideHolder = Instance.new("Frame", sidebar)
sideHolder.Size             = UDim2.new(1, 0, 1, 0)
sideHolder.BackgroundTransparency = 1
local sideList = Instance.new("UIListLayout", sideHolder)
sideList.Padding            = UDim.new(0, 4)
sideList.SortOrder          = Enum.SortOrder.LayoutOrder
local sidePad = Instance.new("UIPadding", sideHolder)
sidePad.PaddingTop   = UDim.new(0, 14)
sidePad.PaddingLeft  = UDim.new(0, 10)
sidePad.PaddingRight = UDim.new(0, 10)

-- ============================================================
-- CONTENT AREA
-- ============================================================
local contentArea = Instance.new("Frame", mainFrame)
contentArea.Size            = UDim2.new(1, -152, 1, -48)
contentArea.Position        = UDim2.new(0, 152, 0, 48)
contentArea.BackgroundTransparency = 1
contentArea.ZIndex          = 2

-- ============================================================
-- TAB SYSTEM
-- ============================================================
local activeTab      = nil
local allCards       = {}
local cardOrder      = 0

local function makeScrollPage(name)
	local page = Instance.new("ScrollingFrame", contentArea)
	page.Name                  = name
	page.Size                  = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel       = 0
	page.ScrollBarThickness    = 3
	page.ScrollBarImageColor3  = Theme.Stroke
	page.AutomaticCanvasSize   = Enum.AutomaticSize.Y
	page.CanvasSize            = UDim2.new()
	page.Visible               = false

	local list = Instance.new("UIListLayout", page)
	list.Padding        = UDim.new(0, 8)
	list.SortOrder      = Enum.SortOrder.LayoutOrder

	local pad = Instance.new("UIPadding", page)
	pad.PaddingTop    = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft   = UDim.new(0, 14)
	pad.PaddingRight  = UDim.new(0, 14)
	return page
end

local searchPage = makeScrollPage("SearchPage")

local function createTab(name, order, iconText)
	local TAB_H = 36
	local btn = Instance.new("TextButton", sideHolder)
	btn.Size                = UDim2.new(1, 0, 0, TAB_H)
	btn.BackgroundColor3    = Theme.Card
	btn.BackgroundTransparency = 1
	btn.LayoutOrder         = order
	btn.AutoButtonColor     = false
	btn.ZIndex              = 4
	-- icon + label in one go
	btn.Text        = (iconText or "") .. "   " .. name
	btn.TextColor3  = Theme.SubText
	btn.Font        = Enum.Font.GothamMedium
	btn.TextSize    = 12
	btn.TextXAlignment = Enum.TextXAlignment.Left
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)
	local bPad = Instance.new("UIPadding", btn)
	bPad.PaddingLeft = UDim.new(0, 14)
	attachFX(btn, { hoverScale = 1.025, clickScale = 0.97 })

	local page = makeScrollPage(name .. "Page")

	local function selectTab()
		searchBox.Text    = ""
		searchPage.Visible = false
		if activeTab then
			tween(activeTab.btn, TI.fast, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
			activeTab.page.Visible = false
		end
		tween(btn, TI.fast, { BackgroundTransparency = 0.22, TextColor3 = Theme.Text })
		-- spring-slide the indicator to this tab
		local targetY = 14 + (order - 1) * (TAB_H + 4) + 8
		tween(sideIndicator, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, 8, 0, targetY) })
		-- flash glow on indicator
		tween(sideIndicator, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 4, 0, 24) })
		task.delay(0.08, function()
			tween(sideIndicator, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 3, 0, 20) })
		end)

		-- page fade-in
		page.Visible          = true
		page.GroupTransparency = 0
		if page:IsA("CanvasGroup") then
			page.GroupTransparency = 1
			tween(page, TI.quint, { GroupTransparency = 0 })
		end

		activeTab = { btn = btn, page = page }
	end

	btn.MouseButton1Click:Connect(selectTab)
	if not activeTab then selectTab() end
	return page
end

-- ============================================================
-- REGISTRY (preset save/load & keybind)
-- ============================================================
local presetRegistry   = {}
local keybindHandlers  = {}
local listeningBindCb  = nil
local listeningBindBtn = nil

-- ============================================================
-- CARD  (base component with hover border glow + bg lift)
-- ============================================================
local function createBaseCard(page, title, desc, height)
	cardOrder = cardOrder + 1
	local card = Instance.new("Frame", page)
	card.Size                = UDim2.new(1, 0, 0, height or 54)
	card.BackgroundColor3    = Theme.Card
	card.BackgroundTransparency = 0.22
	card.LayoutOrder         = cardOrder
	card.ZIndex              = 2
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local st = Instance.new("UIStroke", card)
	st.Color = Theme.Stroke; st.Thickness = 1

	-- hover glow (card bg + border)
	card.MouseEnter:Connect(function()
		tween(card, TI.hover, { BackgroundColor3 = Theme.CardHover, BackgroundTransparency = 0.14 })
		tween(st,   TI.hover, { Color = Theme.StrokeHover })
	end)
	card.MouseLeave:Connect(function()
		tween(card, TI.hover, { BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.22 })
		tween(st,   TI.hover, { Color = Theme.Stroke })
	end)

	local lbl = Instance.new("TextLabel", card)
	lbl.Size               = UDim2.new(1, -155, 0, 20)
	lbl.Position           = UDim2.new(0, 14, 0, 9)
	lbl.BackgroundTransparency = 1
	lbl.Text               = title
	lbl.TextColor3         = Theme.Text
	lbl.Font               = Enum.Font.GothamMedium
	lbl.TextSize           = 12
	lbl.TextXAlignment     = Enum.TextXAlignment.Left

	local sub = Instance.new("TextLabel", card)
	sub.Size               = UDim2.new(1, -155, 0, 15)
	sub.Position           = UDim2.new(0, 14, 0, 30)
	sub.BackgroundTransparency = 1
	sub.Text               = desc
	sub.TextColor3         = Theme.SubText
	sub.Font               = Enum.Font.Gotham
	sub.TextSize           = 10
	sub.TextXAlignment     = Enum.TextXAlignment.Left

	table.insert(allCards, { card = card, page = page, title = title:lower(), desc = desc:lower() })
	return card, st
end

-- ============================================================
-- COMPONENTS
-- ============================================================

-- ── TOGGLE ──
local function addToggle(page, id, title, desc, default, callback)
	local card = createBaseCard(page, title, desc)

	local track = Instance.new("Frame", card)
	track.Size              = UDim2.new(0, 46, 0, 24)
	track.Position          = UDim2.new(1, -58, 0.5, -12)
	track.BackgroundColor3  = default and Theme.Accent or Theme.ToggleOff
	track.BorderSizePixel   = 0
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
	local trackScale = Instance.new("UIScale", track)
	trackScale.Scale = 1

	local knob = Instance.new("Frame", track)
	knob.Size              = UDim2.new(0, 18, 0, 18)
	knob.Position          = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
	knob.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel   = 0
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	local knobScale = Instance.new("UIScale", knob)
	knobScale.Scale = 1

	local value = default or false
	onAccentChange(function(c) if value then track.BackgroundColor3 = c end end)

	local function set(on, fromCode)
		value = on
		if on then
			tween(track, TI.fast, { BackgroundColor3 = Theme.Accent })
			tween(knob,  TI.bounce, { Position = UDim2.new(1, -21, 0.5, -9) })
			tween(knobScale, TI.bounce, { Scale = 1.15 })
			task.delay(0.18, function() tween(knobScale, TI.fast, { Scale = 1 }) end)
		else
			tween(track, TI.fast, { BackgroundColor3 = Theme.ToggleOff })
			tween(knob,  TI.bounce, { Position = UDim2.new(0, 3, 0.5, -9) })
		end
		if not fromCode then callback(on) end
	end

	-- hover: track scale up
	track.MouseEnter:Connect(function() tween(trackScale, TI.fast, { Scale = 1.08 }) end)
	track.MouseLeave:Connect(function() tween(trackScale, TI.fast, { Scale = 1 }) end)

	local hit = Instance.new("TextButton", card)
	hit.Size                = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Text                = ""
	hit.MouseButton1Click:Connect(function() set(not value) end)

	presetRegistry[id] = {
		get = function() return value and 1 or 0 end,
		set = function(v) set(v == 1, false) end,
	}

	set(default or false, true)
end

-- ── SLIDER ──
local function addSlider(page, id, title, desc, min, max, default, suffix, callback)
	local card = createBaseCard(page, title, desc, 62)

	local valLbl = Instance.new("TextLabel", card)
	valLbl.Size            = UDim2.new(0, 60, 0, 18)
	valLbl.Position        = UDim2.new(1, -66, 0, 8)
	valLbl.BackgroundTransparency = 1
	valLbl.Text            = tostring(default) .. (suffix or "")
	valLbl.Font            = Enum.Font.GothamBold
	valLbl.TextSize        = 11
	valLbl.TextXAlignment  = Enum.TextXAlignment.Right
	onAccentChange(function(c) valLbl.TextColor3 = c end)

	local track = Instance.new("Frame", card)
	track.Size             = UDim2.new(1, -28, 0, 5)
	track.Position         = UDim2.new(0, 14, 0, 46)
	track.BackgroundColor3 = Theme.ToggleOff
	track.BorderSizePixel  = 0
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame", track)
	fill.BackgroundTransparency = 0
	fill.BorderSizePixel        = 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	onAccentChange(function(c) fill.BackgroundColor3 = c end)

	local knob = Instance.new("Frame", track)
	knob.Size              = UDim2.new(0, 13, 0, 13)
	knob.AnchorPoint       = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel   = 0
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	local knobScale = Instance.new("UIScale", knob)
	knobScale.Scale = 1

	local value   = default
	local draggingSlider = false

	local function updateVisual(v, animate)
		local pct = (v - min) / math.max(max - min, 1)
		local info = animate and TI.fast or TweenInfo.new(0)
		tween(fill,  info, { Size = UDim2.new(pct, 0, 1, 0) })
		tween(knob, info, { Position = UDim2.new(pct, 0, 0.5, 0) })
		valLbl.Text = tostring(math.round(v)) .. (suffix or "")
	end

	local function setValue(v)
		value = math.clamp(math.round(v), min, max)
		updateVisual(value, true)
		callback(value)
	end

	local function fromMouse()
		local abs = track.AbsolutePosition
		local sz  = track.AbsoluteSize
		local mx  = mouse.X
		local pct = math.clamp((mx - abs.X) / math.max(sz.X, 1), 0, 1)
		setValue(min + (max - min) * pct)
	end

	-- hover grow
	track.MouseEnter:Connect(function() tween(knobScale, TI.fast, { Scale = 1.3 }) end)
	track.MouseLeave:Connect(function() if not draggingSlider then tween(knobScale, TI.fast, { Scale = 1 }) end end)

	local sliderHit = Instance.new("TextButton", card)
	sliderHit.Size              = UDim2.new(1, -28, 0, 24)
	sliderHit.Position          = UDim2.new(0, 14, 0, 36)
	sliderHit.BackgroundTransparency = 1
	sliderHit.Text              = ""
	sliderHit.MouseButton1Down:Connect(function()
		draggingSlider = true
		tween(knobScale, TI.fast, { Scale = 1.5 })
		fromMouse()
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if draggingSlider then
				draggingSlider = false
				tween(knobScale, TI.bounce, { Scale = 1 })
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
			fromMouse()
		end
	end)

	updateVisual(default, false)

	presetRegistry[id] = {
		get = function() return value end,
		set = function(v) setValue(v or default) end,
	}
end

-- ── BUTTON (plain & hold-to-confirm) ──
local function addButton(page, title, desc, btnText, holdSecs, callback)
	local card = createBaseCard(page, title, desc)

	local btn = Instance.new("TextButton", card)
	btn.Size              = UDim2.new(0, 100, 0, 28)
	btn.Position          = UDim2.new(1, -112, 0.5, -14)
	btn.BackgroundColor3  = Theme.Sidebar
	btn.Text              = btnText
	btn.TextColor3        = Theme.Text
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 11
	btn.AutoButtonColor   = false
	btn.ClipsDescendants  = true
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	local bst = Instance.new("UIStroke", btn)
	bst.Thickness = 1
	onAccentChange(function(c) bst.Color = c end)
	attachFX(btn, { hoverScale = 1.07, clickScale = 0.92, stroke = bst, glowOnHover = true })

	if not holdSecs or holdSecs <= 0 then
		btn.MouseButton1Click:Connect(callback)
	else
		local prog = Instance.new("Frame", btn)
		prog.Size              = UDim2.new(0, 0, 1, 0)
		prog.BackgroundTransparency = 0.60
		prog.BorderSizePixel   = 0
		prog.ZIndex            = 0
		onAccentChange(function(c) prog.BackgroundColor3 = c end)

		local holdTween
		btn.MouseButton1Down:Connect(function()
			btn.Text = "Tahan…"
			holdTween = TweenService:Create(prog, TI.linear(holdSecs), { Size = UDim2.new(1, 0, 1, 0) })
			holdTween.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					prog.Size = UDim2.new(0, 0, 1, 0)
					btn.Text  = btnText
					callback()
				end
			end)
			holdTween:Play()
		end)
		btn.MouseButton1Up:Connect(function()
			if holdTween then holdTween:Cancel() end
			prog.Size = UDim2.new(0, 0, 1, 0)
			btn.Text  = btnText
		end)
	end
end

-- ── SELECTOR (cycle through options) ──
local function addSelector(page, id, title, desc, options, callback)
	local card = createBaseCard(page, title, desc)
	local idx  = 1

	local btn = Instance.new("TextButton", card)
	btn.Size              = UDim2.new(0, 100, 0, 28)
	btn.Position          = UDim2.new(1, -112, 0.5, -14)
	btn.BackgroundColor3  = Theme.Sidebar
	btn.Text              = tostring(options[1])
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 11
	btn.AutoButtonColor   = false
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	local bst = Instance.new("UIStroke", btn)
	bst.Thickness = 1
	onAccentChange(function(c) bst.Color = c; btn.TextColor3 = c end)
	attachFX(btn, { hoverScale = 1.07, clickScale = 0.92, stroke = bst, glowOnHover = true })

	btn.MouseButton1Click:Connect(function()
		idx = (idx % #options) + 1
		btn.Text = tostring(options[idx])
		-- pop animation
		local us = btn:FindFirstChildOfClass("UIScale")
		if us then
			tween(us, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.88 })
			task.delay(0.08, function() tween(us, TI.bounce, { Scale = 1 }) end)
		end
		callback(options[idx])
	end)

	presetRegistry[id] = {
		get = function() return idx end,
		set = function(v)
			idx = math.clamp(v or 1, 1, #options)
			btn.Text = tostring(options[idx])
			callback(options[idx])
		end,
	}
end

-- ── KEYBIND ──
local function addKeybind(page, id, title, desc, default, callback)
	local card, _ = createBaseCard(page, title, desc)
	local boundKey = default

	local btn = Instance.new("TextButton", card)
	btn.Size              = UDim2.new(0, 100, 0, 28)
	btn.Position          = UDim2.new(1, -112, 0.5, -14)
	btn.BackgroundColor3  = Theme.Sidebar
	btn.Text              = boundKey and tostring(boundKey.Name) or "NONE"
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 11
	btn.AutoButtonColor   = false
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	local bst = Instance.new("UIStroke", btn)
	bst.Thickness = 1
	onAccentChange(function(c) bst.Color = c; btn.TextColor3 = c end)
	attachFX(btn, { hoverScale = 1.07, clickScale = 0.92, stroke = bst, glowOnHover = true })

	btn.MouseButton1Click:Connect(function()
		btn.Text = "…"
		listeningBindCb = function(kc)
			boundKey  = kc
			btn.Text  = kc and kc.Name or "NONE"
		end
	end)

	table.insert(keybindHandlers, function(kc)
		if boundKey and kc == boundKey then callback() end
	end)
end

-- ============================================================
-- SECTION HEADER helper
-- ============================================================
local function addSectionLabel(page, text)
	cardOrder = cardOrder + 1
	local lbl = Instance.new("TextLabel", page)
	lbl.Size               = UDim2.new(1, 0, 0, 24)
	lbl.BackgroundTransparency = 1
	lbl.LayoutOrder        = cardOrder
	lbl.Text               = text
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextSize           = 10
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	onAccentChange(function(c) lbl.TextColor3 = c end)
	local pad = Instance.new("UIPadding", lbl)
	pad.PaddingLeft = UDim.new(0, 2)
end

-- ============================================================
-- TAB 1 : COMBAT
-- ============================================================
local combatPage = createTab("Combat", 1, "⚔")

addSectionLabel(combatPage, "COMBAT")
addToggle(combatPage, "godmode", "God Mode", "Kebal penuh terhadap semua damage senjata", false, function(on)
	player:SetAttribute("AdminGodMode", on)
	fireServer("GodMode", player, on)
	notify(on and "God Mode aktif" or "God Mode nonaktif")
end)
addToggle(combatPage, "infammo", "Infinite Ammo", "Peluru tidak pernah habis & tanpa reload", false, function(on)
	player:SetAttribute("AdminInfAmmo", on)
	fireServer("InfAmmo", player, on)
end)
addToggle(combatPage, "norecoil", "No Recoil & Spread", "Akurasi peluru 100% lurus tanpa hentakan", false, function(on)
	player:SetAttribute("AdminNoRecoil", on)
end)
addToggle(combatPage, "rapidfire", "Rapid Fire", "Hapus jeda tembakan antar peluru", false, function(on)
	player:SetAttribute("AdminRapidFire", on)
end)
addSelector(combatPage, "dmgmult", "Damage Multiplier", "Lipat gandakan output damage senjata",
	{"1x", "2x", "5x", "1-Hit"}, function(val)
		player:SetAttribute("AdminDmgMult", val)
		fireServer("DmgMult", player, val)
	end)

-- ============================================================
-- TAB 2 : VISUALS
-- ============================================================
local visualPage = createTab("Visuals", 2, "👁")
local espEnabled = false

local function applyESP(plr, char)
	if not char or plr == player then return end
	local old = char:FindFirstChild("VeltESP")
	if old then old:Destroy() end
	if not espEnabled then return end
	local hl = Instance.new("Highlight", char)
	hl.Name              = "VeltESP"
	hl.FillColor         = Theme.Accent
	hl.OutlineColor      = Color3.new(1, 1, 1)
	hl.FillTransparency  = 0.65
end
local function refreshESP()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then applyESP(p, p.Character) end
	end
end
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function(c) task.wait(0.2); applyESP(p, c) end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= player then
		p.CharacterAdded:Connect(function(c) task.wait(0.2); applyESP(p, c) end)
	end
end
-- update ESP highlight color whenever accent changes
onAccentChange(function(c)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			local hl = p.Character:FindFirstChild("VeltESP")
			if hl then hl.FillColor = c end
		end
	end
end)

addSectionLabel(visualPage, "VISUALS")
addToggle(visualPage, "esp", "Player ESP (Wallhack)", "Tampilkan siluet musuh menembus dinding", false, function(on)
	espEnabled = on; refreshESP()
end)
addToggle(visualPage, "fullbright", "Fullbright", "Terangkan seluruh arena tanpa bayangan", false, function(on)
	Lighting.Brightness    = on and 3   or 1
	Lighting.GlobalShadows = not on
	Lighting.Ambient       = on and Color3.fromRGB(185, 185, 185) or Color3.fromRGB(70, 70, 70)
end)
addSlider(visualPage, "fov", "Field of View", "Perluas sudut pandang kamera FPS", 70, 120, 75, "°", function(val)
	camera.FieldOfView = val
end)
addSlider(visualPage, "camshake", "Camera Shake Scale", "Kurangi efek guncangan senjata", 0, 100, 100, "%", function(val)
	-- wire to your camera shake module if any
	player:SetAttribute("AdminCamShake", val)
end)

-- ============================================================
-- TAB 3 : MOVEMENT
-- ============================================================
local movePage = createTab("Movement", 3, "🚀")
local flying  = false
local flySpd  = 60
local noclip  = false

RunService.Stepped:Connect(function()
	if not noclip or not player.Character then return end
	for _, p in ipairs(player.Character:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end
end)
RunService.RenderStepped:Connect(function(dt)
	if not flying or not player.Character then return end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end
	hum.PlatformStand = true
	local dir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += camera.CFrame.LookVector  end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= camera.CFrame.LookVector  end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir += Vector3.yAxis end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame += (dir.Magnitude > 0 and dir.Unit * flySpd * dt or Vector3.zero)
end)

addSectionLabel(movePage, "MOVEMENT")
addToggle(movePage, "fly", "Free Flight", "Terbang bebas  WASD + Space / Ctrl", false, function(on)
	flying = on
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and not on then hum.PlatformStand = false end
end)
addToggle(movePage, "noclip", "Noclip", "Tembus tembok & objek arena", false, function(on) noclip = on end)
addSlider(movePage, "walkspeed", "Walk Speed", "Kecepatan lari karakter", 16, 120, 16, " st/s", function(val)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = val end
end)
addSlider(movePage, "flyspeed", "Fly Speed", "Kecepatan saat mode Fly aktif", 20, 200, 60, "", function(val)
	flySpd = val
end)
addButton(movePage, "Teleport ke Kursor", "Pindah instan ke titik yang dibidik crosshair", "Teleport", 0, function()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp and mouse.Hit then
		hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
		notify("Teleport berhasil")
	end
end)
addKeybind(movePage, "flybind", "Flight Keybind", "Tombol untuk toggle fly", Enum.KeyCode.X, function()
	flying = not flying
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and not flying then hum.PlatformStand = false end
	notify(flying and "Fly ON" or "Fly OFF")
end)

-- ============================================================
-- TAB 4 : PLAYERS
-- ============================================================
local playersPage = createTab("Players", 4, "👥")

local function rebuildPlayerList()
	for _, c in ipairs(playersPage:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		cardOrder = cardOrder + 1
		local row = Instance.new("Frame", playersPage)
		row.Size               = UDim2.new(1, 0, 0, 50)
		row.BackgroundColor3   = Theme.Card
		row.BackgroundTransparency = 0.22
		row.LayoutOrder        = cardOrder
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
		local rst = Instance.new("UIStroke", row)
		rst.Color = Theme.Stroke; rst.Thickness = 1
		row.MouseEnter:Connect(function()
			tween(row, TI.hover, { BackgroundColor3 = Theme.CardHover, BackgroundTransparency = 0.14 })
			tween(rst, TI.hover, { Color = Theme.StrokeHover })
		end)
		row.MouseLeave:Connect(function()
			tween(row, TI.hover, { BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.22 })
			tween(rst, TI.hover, { Color = Theme.Stroke })
		end)

		local nameLbl = Instance.new("TextLabel", row)
		nameLbl.Size              = UDim2.new(0, 180, 1, 0)
		nameLbl.Position          = UDim2.new(0, 14, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text              = plr.DisplayName .. (plr == player and "  (kamu)" or "")
		nameLbl.TextColor3        = Theme.Text
		nameLbl.Font              = Enum.Font.GothamMedium
		nameLbl.TextSize          = 11
		nameLbl.TextXAlignment    = Enum.TextXAlignment.Left

		local actions = {"Spec", "Bring", "Freeze", "Heal"}
		if plr ~= player then table.insert(actions, "Kick") end

		for i, act in ipairs(actions) do
			local b = Instance.new("TextButton", row)
			b.Size             = UDim2.new(0, 46, 0, 24)
			b.Position         = UDim2.new(1, -((#actions - i + 1) * 52) - 6, 0.5, -12)
			b.BackgroundColor3 = Theme.Sidebar
			b.Text             = act
			b.TextColor3       = act == "Kick" and Color3.fromRGB(244, 63, 94) or Theme.SubText
			b.Font             = Enum.Font.GothamBold
			b.TextSize         = 10
			b.AutoButtonColor  = false
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
			attachFX(b, { hoverScale = 1.1, clickScale = 0.88 })
			b.MouseButton1Click:Connect(function()
				if act == "Spec" then
					local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
					if hum then camera.CameraSubject = hum; notify("Spectating: " .. plr.Name) end
				else
					fireServer("PlayerAction", plr, act)
					notify(act .. " → " .. plr.Name)
				end
			end)
		end
	end
end

Players.PlayerAdded:Connect(rebuildPlayerList)
Players.PlayerRemoving:Connect(rebuildPlayerList)
rebuildPlayerList()

-- ============================================================
-- TAB 5 : SYSTEM
-- ============================================================
local sysPage = createTab("System", 5, "⚙")
local savedPreset = nil

addSectionLabel(sysPage, "INTERFACE")
addSlider(sysPage, "opacity", "Glass Opacity", "Transparansi latar kaca panel", 5, 55, 12, "%", function(val)
	glassBg.BackgroundTransparency = val / 100
end)
addSelector(sysPage, "uiscale", "Panel Size", "Ukuran jendela VELT OS",
	{"Small (560px)", "Normal (680px)", "Large (780px)"}, function(val)
		local w = val:find("560") and 560 or val:find("780") and 780 or 680
		tween(mainFrame, TI.spring, { Size = UDim2.new(0, w, 0, math.floor(w * 0.676)) })
	end)

addSectionLabel(sysPage, "CONFIG PRESET")
addButton(sysPage, "Save Config Preset", "Simpan seluruh pengaturan & keybind aktif", "Save", 0, function()
	savedPreset = {}
	for id, entry in pairs(presetRegistry) do savedPreset[id] = entry.get() end
	notify("Preset disimpan")
end)
addButton(sysPage, "Load Config Preset", "Pulihkan pengaturan yang terakhir disimpan", "Load", 0, function()
	if not savedPreset then return notify("Belum ada preset") end
	for id, val in pairs(savedPreset) do
		if presetRegistry[id] then presetRegistry[id].set(val) end
	end
	notify("Preset dipulihkan")
end)

addSectionLabel(sysPage, "ADMIN ACTIONS")
addButton(sysPage, "Heal All Players", "Pulihkan HP seluruh pemain di arena", "Execute", 0, function()
	fireServer("HealAll")
	notify("Seluruh pemain dipulihkan")
end)
addButton(sysPage, "Reset Round (Hold)", "Tahan 1.2 detik untuk respawn semua", "Hold Reset", 1.2, function()
	fireServer("ResetRound")
	notify("Round di-reset")
end)

-- ============================================================
-- LIVE SEARCH
-- ============================================================
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = string.lower(searchBox.Text)
	if q == "" then
		searchPage.Visible = false
		for _, item in ipairs(allCards) do item.card.Parent = item.page end
		if activeTab then activeTab.page.Visible = true end
	else
		if activeTab then activeTab.page.Visible = false end
		searchPage.Visible = true
		local idx2 = 0
		for _, item in ipairs(allCards) do
			local match = item.title:find(q, 1, true) or item.desc:find(q, 1, true)
			if match then
				idx2 = idx2 + 1
				item.card.Parent = searchPage
				-- staggered slide-in
				item.card.Position = UDim2.new(0, 18, 0, 0)
				item.card.BackgroundTransparency = 1
				local delay = (idx2 - 1) * 0.04
				task.delay(delay, function()
					tween(item.card, TI.quint, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.22 })
				end)
			else
				item.card.Parent = nil
			end
		end
	end
end)

-- ============================================================
-- GLOBAL INPUT
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gpe)
	-- capture keybind rebind
	if listeningBindCb and input.UserInputType == Enum.UserInputType.Keyboard then
		local chosen = input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode or nil
		listeningBindCb(chosen)
		listeningBindCb  = nil
		listeningBindBtn = nil
		return
	end
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		setMinimized(mainFrame.Visible and mainFrame.GroupTransparency < 0.5)
	elseif input.KeyCode == Enum.KeyCode.Slash then
		searchBox:CaptureFocus()
	else
		for _, h in ipairs(keybindHandlers) do h(input.KeyCode) end
	end
end)

-- ============================================================
-- BOOT NOTIFICATION
-- ============================================================
task.delay(0.6, function()
	notify("VELT // OS dimuat  —  RightShift untuk toggle", 3.2)
end)

return Velt
