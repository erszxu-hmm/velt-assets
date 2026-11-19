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
	VELT UI LIBRARY  v3.0  
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	Usage:
	  local Velt = loadstring(game:HttpGet(RAW_URL))()
	  local win  = Velt:CreateWindow({
	      Title      = "Velt",
	      Subtitle   = "My Game",   -- changes per script
	      LogoId     = "12345678",  -- rbxassetid number, or ""
	      ToggleKey  = Enum.KeyCode.RightShift,
	      SaveConfig = true,
	      ConfigFolder = "VeltCfg",
	  })
	  local tab = win:AddTab({ Title = "Main", Group = "FEATURES" })
	  tab:AddSection("Combat")
	  tab:AddToggle({ Name="God Mode", Default=false, Flag="gm",
	      Callback=function(v) end })
	  tab:AddSlider({ Name="Speed", Min=16, Max=120, Step=2,
	      Default=16, Callback=function(v) end })
	  tab:AddButton({ Name="Teleport", Callback=function() end })
	  tab:AddDropdown({ Name="Mode", Options={"A","B"}, Default="A",
	      Callback=function(v) end })
	  tab:AddLabel("some text")  -- returns obj with :Set(text)
	  tab:AddStats({ Columns=3, Items={{Id="k",Value="0",Label="kills"}} })
	  tab:Clear()
	  win:Notify({ Title="Hello", Content="world", Duration=3 })
	  win:SetSize(w, h)
	━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]]

-- ════════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════════
local Players  = game:GetService("Players")
local Tween    = game:GetService("TweenService")
local UIS      = game:GetService("UserInputService")
local Run      = game:GetService("RunService")
local LP       = Players.LocalPlayer
local PGui     = LP:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════
--  AUTO-DETECT  game name + script name
-- ════════════════════════════════════════════
local function detectGameName()
	-- 1) game.Name (set by developer in Studio)
	local n = tostring(game.Name or "")
	if n ~= "" and n ~= "Game" and n ~= "Baseplate" and n ~= "game" then
		return n
	end
	-- 2) MarketplaceService PlaceName (works in live game)
	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
	end)
	if ok and info and type(info.Name) == "string" and info.Name ~= "" then
		return info.Name
	end
	-- 3) fallback: PlaceId
	return "Place " .. tostring(game.PlaceId)
end

-- Script name: detected from the calling script's Name at load time.
-- Since this library is loaded with loadstring, we try to find the
-- LocalScript that called us by walking the script chain.
local function detectScriptName()
	-- getscriptname is an executor function (Synapse, Fluxus, etc.)
	if getscriptname then
		local ok, n = pcall(getscriptname)
		if ok and type(n) == "string" and n ~= "" then
			-- strip path separators, keep just the filename
			return (n:match("[^\/]+$") or n):gsub("%.lua$", "")
		end
	end
	-- fallback: try script chain
	local s = script
	if s and s.Name and s.Name ~= "" and s.Name ~= "Script" then
		return s.Name
	end
	return nil  -- caller did not name their script; use game name only
end

local _autoGameName   = detectGameName()
local _autoScriptName = detectScriptName()
-- Combined subtitle: "ScriptName • GameName"  or just "GameName"
local function autoSubtitle()
	if _autoScriptName then
		return _autoScriptName .. "  •  " .. _autoGameName
	end
	return _autoGameName
end

-- ════════════════════════════════════════════
--  DESIGN TOKENS  (OLED dark + gold accent)
-- ════════════════════════════════════════════
local D = {
	Bg        = Color3.fromRGB( 10,  10,  15),
	Sidebar   = Color3.fromRGB( 14,  14,  22),
	Card      = Color3.fromRGB( 20,  20,  30),
	CardHov   = Color3.fromRGB( 28,  28,  42),
	Surface   = Color3.fromRGB( 17,  17,  27),
	Stroke    = Color3.fromRGB( 40,  40,  60),
	StrokeH   = Color3.fromRGB( 72,  72, 105),
	Text      = Color3.fromRGB(240, 240, 248),
	Sub       = Color3.fromRGB(118, 118, 148),
	Muted     = Color3.fromRGB( 65,  65,  85),
	Accent    = Color3.fromRGB(232, 184, 102),
	TogOff    = Color3.fromRGB( 36,  36,  52),
	Danger    = Color3.fromRGB(220,  60,  60),
}

-- reactive accent
local _accentFns = {}
local function onAccent(fn) table.insert(_accentFns, fn); fn(D.Accent) end
local function setAccent(c)
	D.Accent = c
	for _, f in ipairs(_accentFns) do pcall(f, c) end
end

-- ════════════════════════════════════════════
--  TWEEN HELPERS
-- ════════════════════════════════════════════
local TI = {
	fast   = TweenInfo.new(0.14, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	hover  = TweenInfo.new(0.16, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	bounce = TweenInfo.new(0.26, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	spring = TweenInfo.new(0.30, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	quint  = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	sine   = TweenInfo.new(1.00, Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut),
}
local function tw(o, info, props)
	if o and o.Parent then Tween:Create(o, info, props):Play() end
end

-- ════════════════════════════════════════════
--  INSTANCE HELPERS
-- ════════════════════════════════════════════
local function corner(p, r)
	local c = Instance.new("UICorner", p)
	c.CornerRadius = UDim.new(0, r or 8)
	return c
end
local function stroke(p, col, thick)
	local s = Instance.new("UIStroke", p)
	s.Color, s.Thickness = col or D.Stroke, thick or 1
	return s
end
local function padding(p, l, r, t, b)
	local u = Instance.new("UIPadding", p)
	u.PaddingLeft   = UDim.new(0, l or 8)
	u.PaddingRight  = UDim.new(0, r or 8)
	u.PaddingTop    = UDim.new(0, t or 4)
	u.PaddingBottom = UDim.new(0, b or 4)
end
local function listLayout(p, gap, dir)
	local l = Instance.new("UIListLayout", p)
	l.Padding       = UDim.new(0, gap or 4)
	l.SortOrder     = Enum.SortOrder.LayoutOrder
	l.FillDirection = dir or Enum.FillDirection.Vertical
	return l
end
local function newLabel(p, txt, sz, col, xa, bold)
	local l = Instance.new("TextLabel", p)
	l.Text, l.TextSize        = tostring(txt), sz or 11
	l.TextColor3              = col or D.Text
	l.Font                    = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	l.BackgroundTransparency  = 1
	l.TextXAlignment          = xa or Enum.TextXAlignment.Left
	l.TextWrapped             = true
	l.AutomaticSize           = Enum.AutomaticSize.Y
	l.Size                    = UDim2.new(1, 0, 0, 0)
	return l
end

-- hover glow on card
local function cardHoverFX(frame, st)
	frame.MouseEnter:Connect(function()
		tw(frame, TI.hover, { BackgroundColor3 = D.CardHov, BackgroundTransparency = 0.10 })
		if st then tw(st, TI.hover, { Color = D.StrokeH }) end
	end)
	frame.MouseLeave:Connect(function()
		tw(frame, TI.hover, { BackgroundColor3 = D.Card, BackgroundTransparency = 0.18 })
		if st then tw(st, TI.hover, { Color = D.Stroke }) end
	end)
end

-- spring scale
local function springScale(btn, hs, cs)
	hs, cs = hs or 1.05, cs or 0.93
	local us = Instance.new("UIScale", btn); us.Scale = 1
	btn.MouseEnter:Connect(function()    tw(us, TI.hover,  { Scale = hs }) end)
	btn.MouseLeave:Connect(function()    tw(us, TI.hover,  { Scale = 1  }) end)
	if btn:IsA("GuiButton") then
		btn.MouseButton1Down:Connect(function() tw(us, TI.fast,   { Scale = cs }) end)
		btn.MouseButton1Up:Connect(function()   tw(us, TI.bounce, { Scale = 1  }) end)
	end
	return us
end

-- ════════════════════════════════════════════
--  CONFIG  (file-based, all pcall-guarded)
-- ════════════════════════════════════════════
local function mkConfig(folder)
	local c = { folder = folder or "VeltUI" }
	local function fp(k) return c.folder .. "/" .. k .. ".cfg" end
	local function ensDir()
		if isfolder and not isfolder(c.folder) then
			pcall(makefolder, c.folder)
		end
	end
	function c:save(k, v)
		ensDir()
		if writefile then pcall(writefile, fp(k), tostring(v)) end
	end
	function c:load(k, d)
		if readfile and isfile then
			local ok, v = pcall(function()
				if isfile(fp(k)) then return readfile(fp(k)) end
			end)
			if ok and v ~= nil then return v end
		end
		return d
	end
	function c:bool(k, d)
		local v = self:load(k)
		if v == nil then return d end
		return v == "true"
	end
	function c:num(k, d)
		return tonumber(self:load(k)) or d
	end
	return c
end

-- ════════════════════════════════════════════
--  TOAST
-- ════════════════════════════════════════════
local _toastLayer
local function ensureToastLayer(gui)
	if _toastLayer and _toastLayer.Parent then return _toastLayer end
	_toastLayer = Instance.new("Frame", gui)
	_toastLayer.Name = "VeltToasts"
	_toastLayer.Size = UDim2.fromOffset(290, 340)
	_toastLayer.AnchorPoint = Vector2.new(1, 1)
	_toastLayer.Position = UDim2.new(1, -14, 1, -14)
	_toastLayer.BackgroundTransparency = 1
	_toastLayer.ZIndex = 300
	local ll = listLayout(_toastLayer, 6)
	ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
	return _toastLayer
end

local function pushToast(gui, opts)
	local layer = ensureToastLayer(gui)
	local dur   = opts.Duration or 3
	local acol  = D.Accent
	if opts.Title and opts.Title:lower():find("error") then acol = D.Danger end

	local wrap = Instance.new("Frame", layer)
	wrap.Size = UDim2.new(1, 0, 0, 0)
	wrap.AutomaticSize = Enum.AutomaticSize.Y
	wrap.BackgroundTransparency = 1

	local card = Instance.new("Frame", wrap)
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = D.Surface
	card.BackgroundTransparency = 1          -- starts invisible
	card.Position = UDim2.fromOffset(28, 0)  -- starts offset right
	corner(card, 10)
	local cst = stroke(card, acol, 1)
	cst.Transparency = 1
	padding(card, 14, 12, 8, 8)

	local bar = Instance.new("Frame", card)
	bar.Size = UDim2.fromOffset(3, 16)
	bar.Position = UDim2.fromOffset(-10, 4)
	bar.BackgroundColor3 = acol
	bar.BorderSizePixel = 0
	corner(bar, 2)

	local inner = Instance.new("Frame", card)
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	listLayout(inner, 2)

	if opts.Title and opts.Title ~= "" then
		local t = newLabel(inner, opts.Title, 12, D.Text, nil, true)
		t.LayoutOrder = 1
	end
	if opts.Content and opts.Content ~= "" then
		local s = newLabel(inner, opts.Content, 10, D.Sub)
		s.LayoutOrder = 2
	end
	inner.Parent = card

	-- slide in from right
	tw(card, TI.quint, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0.05 })
	tw(cst,  TI.quint, { Transparency = 0 })

	task.delay(dur, function()
		if not wrap or not wrap.Parent then return end
		local out = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw(card, out, { Position = UDim2.fromOffset(28, 0), BackgroundTransparency = 1 })
		tw(cst,  out, { Transparency = 1 })
		task.wait(0.22)
		if wrap and wrap.Parent then wrap:Destroy() end
	end)
end

-- ════════════════════════════════════════════
--  CREATE WINDOW
-- ════════════════════════════════════════════
local function createWindow(_, opts)
	opts = opts or {}
	local cfg     = mkConfig(opts.ConfigFolder or "VeltUI")
	local saveOn  = opts.SaveConfig == true
	local togKey  = opts.ToggleKey or Enum.KeyCode.RightShift
	local minW    = (opts.MinSize and opts.MinSize.X) or 340
	local minH    = (opts.MinSize and opts.MinSize.Y) or 260

	-- destroy any existing window from this library
	for _, root in ipairs({ PGui, game:GetService("CoreGui") }) do
		local old = root:FindFirstChild("VeltLib3_GUI")
		if old then old:Destroy() end
	end

	-- screen gui
	local GUI = Instance.new("ScreenGui")
	GUI.Name             = "VeltLib3_GUI"
	GUI.ResetOnSpawn     = false
	GUI.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
	GUI.IgnoreGuiInset   = true
	-- ── built-in asset URLs (logo + icons from your GitHub) ──
	-- These are fetched and inserted into Roblox via Image property (Content URL).
	-- Roblox accepts raw GitHub PNG URLs directly in ImageLabel.Image.
	local VELT_LOGO_URL  = "https://raw.githubusercontent.com/erszxu-hmm/velt-assets/main/velt_logo.png"
	local VELT_ICONS_URL = "https://raw.githubusercontent.com/erszxu-hmm/velt-assets/main/velt_icons.png"
	-- If the caller passed a LogoId number, that overrides the built-in logo.
	local _logoContent = (opts.LogoId and opts.LogoId ~= "")
		and ("rbxassetid://" .. tostring(opts.LogoId):gsub("rbxassetid://",""))
		or VELT_LOGO_URL

	-- ── safe parent resolution: gethui > CoreGui > PlayerGui
	do
		local function tryParent(target)
			local ok = pcall(function()
				local probe = Instance.new("ScreenGui")
				probe.Parent = target
				probe:Destroy()
			end)
			return ok
		end
		local parent = PGui
		if type(gethui) == "function" then
			local ok, h = pcall(gethui)
			if ok and h then parent = h end
		elseif tryParent(game:GetService("CoreGui")) then
			parent = game:GetService("CoreGui")
		end
		GUI.Parent = parent
	end

	local vp = workspace.CurrentCamera.ViewportSize
	local W  = (opts.Size and opts.Size.X.Offset) or 640
	local H  = (opts.Size and opts.Size.Y.Offset) or 420

	-- ── SHADOW (behind everything) ──────────────────
	local shadow = Instance.new("ImageLabel", GUI)
	shadow.Name                = "Shadow"
	shadow.Image               = "rbxassetid://6014261993"
	shadow.ImageColor3         = Color3.new(0, 0, 0)
	shadow.ImageTransparency   = 0.52
	shadow.ScaleType           = Enum.ScaleType.Slice
	shadow.SliceCenter         = Rect.new(49, 49, 450, 450)
	shadow.BackgroundTransparency = 1
	shadow.ZIndex              = 0

	-- ── MAIN FRAME (opaque, no CanvasGroup) ─────────
	local main = Instance.new("Frame", GUI)
	main.Name                 = "Main"
	main.Size                 = UDim2.fromOffset(W, H)
	main.Position             = UDim2.fromOffset(
		math.floor((vp.X - W) / 2),
		math.floor((vp.Y - H) / 2))
	main.BackgroundColor3     = D.Bg
	main.BackgroundTransparency = 0
	main.ClipsDescendants     = true
	corner(main, 14)
	local mainSt = stroke(main, D.Stroke, 1.2)
	onAccent(function(c)
		local mx = 0.55
		mainSt.Color = Color3.new(
			c.R * mx + D.Stroke.R * (1 - mx),
			c.G * mx + D.Stroke.G * (1 - mx),
			c.B * mx + D.Stroke.B * (1 - mx))
	end)

	-- sync shadow
	local function syncShadow()
		shadow.Position = main.Position - UDim2.fromOffset(28, 18)
		shadow.Size     = main.Size + UDim2.fromOffset(56, 36)
	end
	syncShadow()
	main:GetPropertyChangedSignal("Position"):Connect(syncShadow)
	main:GetPropertyChangedSignal("Size"):Connect(syncShadow)

	-- specular top line
	local spec = Instance.new("Frame", main)
	spec.Size            = UDim2.new(0.65, 0, 0, 1)
	spec.Position        = UDim2.new(0.175, 0, 0, 0)
	spec.BorderSizePixel = 0
	spec.ZIndex          = 10
	do
		local sg = Instance.new("UIGradient", spec)
		sg.Rotation = 0
		onAccent(function(c)
			sg.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,   Color3.new(0, 0, 0)),
				ColorSequenceKeypoint.new(0.5, c),
				ColorSequenceKeypoint.new(1,   Color3.new(0, 0, 0)),
			})
			sg.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0,   1),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(1,   1),
			})
		end)
	end

	-- cursor spotlight (radial on opaque surface)
	local spotFrame = Instance.new("Frame", main)
	spotFrame.Size                = UDim2.fromScale(1, 1)
	spotFrame.BackgroundTransparency = 1
	spotFrame.ZIndex              = 1
	local spotG = Instance.new("UIGradient", spotFrame)
	spotG.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.88),
		NumberSequenceKeypoint.new(0.4, 0.96),
		NumberSequenceKeypoint.new(1,   1),
	})
	onAccent(function(c)
		spotG.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c),
			ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
		})
	end)
	local _mouse = LP:GetMouse()
	Run.RenderStepped:Connect(function()
		if not main.Visible then return end
		local abs, sz = main.AbsolutePosition, main.AbsoluteSize
		if sz.X < 1 then return end
		spotG.Offset = Vector2.new(
			math.clamp((_mouse.X - abs.X) / sz.X, 0, 1) - 0.5,
			math.clamp((_mouse.Y - abs.Y) / sz.Y, 0, 1) - 0.5)
	end)

	-- ── OPEN / CLOSE (fader overlay — no CanvasGroup, no blur residue) ──
	local _open      = true
	local _animating = false

	local function openPanel()
		if _animating or _open then return end
		_animating = true
		main.Visible = true
		local fader = Instance.new("Frame", main)
		fader.Size                = UDim2.fromScale(1, 1)
		fader.BackgroundColor3    = D.Bg
		fader.BackgroundTransparency = 0
		fader.ZIndex              = 100
		fader.BorderSizePixel     = 0
		tw(fader, TI.quint, { BackgroundTransparency = 1 })
		task.delay(0.28, function()
			if fader and fader.Parent then fader:Destroy() end
			_animating = false
		end)
		_open = true
	end

	local function closePanel()
		if _animating or not _open then return end
		_animating = true
		local fader = Instance.new("Frame", main)
		fader.Size                = UDim2.fromScale(1, 1)
		fader.BackgroundColor3    = D.Bg
		fader.BackgroundTransparency = 1
		fader.ZIndex              = 100
		fader.BorderSizePixel     = 0
		tw(fader, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 0 })
		task.delay(0.20, function()
			main.Visible = false
			if fader and fader.Parent then fader:Destroy() end
			_animating = false
		end)
		_open = false
	end

	-- entrance animation
	do
		local fader = Instance.new("Frame", main)
		fader.Size                = UDim2.fromScale(1, 1)
		fader.BackgroundColor3    = D.Bg
		fader.BackgroundTransparency = 0
		fader.ZIndex              = 100
		fader.BorderSizePixel     = 0
		local ms = Instance.new("UIScale", main); ms.Scale = 0.90
		tw(fader, TI.quint, { BackgroundTransparency = 1 })
		tw(ms, TI.spring, { Scale = 1 })
		task.delay(0.32, function()
			if fader and fader.Parent then fader:Destroy() end
			if ms and ms.Parent then ms:Destroy() end
		end)
	end

	-- ── ISLAND PILL ─────────────────────────────────
	local island = Instance.new("TextButton", GUI)
	island.Name                   = "VeltIsland"
	island.Size                   = UDim2.fromOffset(200, 36)
	island.AnchorPoint            = Vector2.new(0.5, 0)
	island.Position               = UDim2.new(0.5, 0, 0, 14)
	island.BackgroundColor3       = D.Sidebar
	island.BackgroundTransparency = 0
	island.Text                   = ""
	island.AutoButtonColor        = false
	island.Visible                = false
	island.ZIndex                 = 60
	corner(island, 40)
	local islandSt = stroke(island, D.Accent, 1.3)
	onAccent(function(c) islandSt.Color = c end)

	local iDot = Instance.new("Frame", island)
	iDot.Size            = UDim2.fromOffset(8, 8)
	iDot.Position        = UDim2.fromOffset(14, 14)
	iDot.BorderSizePixel = 0
	corner(iDot)
	onAccent(function(c) iDot.BackgroundColor3 = c end)
	task.spawn(function()
		while iDot and iDot.Parent do
			tw(iDot, TI.sine, { BackgroundTransparency = 0.7 })
			task.wait(1)
			tw(iDot, TI.sine, { BackgroundTransparency = 0 })
			task.wait(1)
		end
	end)

	-- auto-fill Subtitle from game/script detection if caller did not set it
	if not opts.Subtitle or opts.Subtitle == "" then
		opts.Subtitle = autoSubtitle()
		opts._customSubtitle = false
	else
		opts._customSubtitle = true
	end
	local iTitle = tostring(opts.Title or "Velt")
	local iLbl = Instance.new("TextLabel", island)
	iLbl.Text                = iTitle .. "   •   tap to open"
	iLbl.Font                = Enum.Font.GothamBold
	iLbl.TextSize            = 11
	iLbl.TextColor3          = D.Text
	iLbl.BackgroundTransparency = 1
	iLbl.Position            = UDim2.fromOffset(28, 0)
	iLbl.Size                = UDim2.new(1, -32, 1, 0)
	iLbl.TextXAlignment      = Enum.TextXAlignment.Left
	springScale(island, 1.05, 0.95)

	island.MouseButton1Click:Connect(function()
		island.Visible = false
		openPanel()
	end)

	UIS.InputBegan:Connect(function(inp, gp)
		if gp then return end
		if inp.KeyCode == togKey then
			if _open then
				closePanel()
				task.delay(0.22, function() island.Visible = true end)
			else
				island.Visible = false
				openPanel()
			end
		end
	end)

	-- ── TOPBAR ──────────────────────────────────────
	local TOPBAR_H = 52
	local topbar = Instance.new("Frame", main)
	topbar.Name                   = "Topbar"
	topbar.Size                   = UDim2.new(1, 0, 0, TOPBAR_H)
	topbar.BackgroundColor3       = D.Sidebar
	topbar.BackgroundTransparency = 0
	topbar.BorderSizePixel        = 0
	topbar.ZIndex                 = 4

	-- separator line
	local tbLine = Instance.new("Frame", topbar)
	tbLine.Size            = UDim2.new(1, 0, 0, 1)
	tbLine.Position        = UDim2.new(0, 0, 1, -1)
	tbLine.BackgroundColor3 = D.Stroke
	tbLine.BorderSizePixel = 0

	-- logo image (always shown — built-in URL or caller override)
	local logoW = 36
	do
		local li = Instance.new("ImageLabel", topbar)
		li.Name                   = "Logo"
		li.Size                   = UDim2.fromOffset(28, 28)
		li.Position               = UDim2.new(0, 16, 0.5, -14)
		li.BackgroundTransparency = 1
		li.ScaleType              = Enum.ScaleType.Fit
		li.ZIndex                 = 5
		li.Image                  = _logoContent
	end

	local brandX = 16 + logoW
	local brandLbl = Instance.new("TextLabel", topbar)
	brandLbl.Text              = tostring(opts.Title or "Velt")
	brandLbl.Font              = Enum.Font.GothamBold
	brandLbl.TextSize          = 14
	brandLbl.BackgroundTransparency = 1
	brandLbl.Position          = UDim2.fromOffset(brandX, 10)
	brandLbl.Size              = UDim2.fromOffset(200, 18)
	brandLbl.TextXAlignment    = Enum.TextXAlignment.Left
	brandLbl.ZIndex            = 5
	onAccent(function(c) brandLbl.TextColor3 = c end)

	-- subtitle (game/script name — changes per window)
	local subLbl = Instance.new("TextLabel", topbar)
	subLbl.Text              = tostring(opts.Subtitle or autoSubtitle())
	subLbl.Font              = Enum.Font.Gotham
	subLbl.TextSize          = 10
	subLbl.TextColor3        = D.Sub
	subLbl.BackgroundTransparency = 1
	subLbl.Position          = UDim2.fromOffset(brandX, 30)
	subLbl.Size              = UDim2.fromOffset(220, 14)
	subLbl.TextXAlignment    = Enum.TextXAlignment.Left
	subLbl.ZIndex            = 5

	-- async update subtitle once MarketplaceService resolves (if it was slow)
	task.spawn(function()
		local ok, info = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)
		if ok and info and type(info.Name) == "string" and info.Name ~= "" then
			_autoGameName = info.Name
			-- only overwrite if the user did not pass a custom Subtitle
			if not opts._customSubtitle then
				local newSub = _autoScriptName and (_autoScriptName .. "  •  " .. info.Name) or info.Name
				if subLbl and subLbl.Parent then subLbl.Text = newSub end
				if iLbl and iLbl.Parent then iLbl.Text = iTitle .. "   •   tap to open" end
			end
		end
	end)

	-- minimize btn
	local minBtn = Instance.new("TextButton", topbar)
	minBtn.Size              = UDim2.fromOffset(28, 28)
	minBtn.AnchorPoint       = Vector2.new(1, 0.5)
	minBtn.Position          = UDim2.new(1, -12, 0.5, 0)
	minBtn.BackgroundColor3  = D.Card
	minBtn.Text              = "—"
	minBtn.TextColor3        = D.Sub
	minBtn.Font              = Enum.Font.GothamBold
	minBtn.TextSize          = 13
	minBtn.AutoButtonColor   = false
	minBtn.ZIndex            = 5
	corner(minBtn, 8)
	local minSt = stroke(minBtn, D.Stroke, 1)
	minBtn.MouseEnter:Connect(function()
		tw(minBtn, TI.hover, { BackgroundColor3 = D.CardHov })
		tw(minSt,  TI.hover, { Color = D.Accent })
	end)
	minBtn.MouseLeave:Connect(function()
		tw(minBtn, TI.hover, { BackgroundColor3 = D.Card })
		tw(minSt,  TI.hover, { Color = D.Stroke })
	end)
	minBtn.MouseButton1Click:Connect(function()
		closePanel()
		task.delay(0.22, function() island.Visible = true end)
	end)

	-- drag
	local dragging, dragStart, dragBase
	topbar.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			dragStart = inp.Position
			dragBase  = main.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	local dragInp
	topbar.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement then dragInp = inp end
	end)
	UIS.InputChanged:Connect(function(inp)
		if inp == dragInp and dragging then
			local d = inp.Position - dragStart
			main.Position = UDim2.new(
				dragBase.X.Scale, dragBase.X.Offset + d.X,
				dragBase.Y.Scale, dragBase.Y.Offset + d.Y)
		end
	end)

	-- resize grip
	local grip = Instance.new("TextButton", main)
	grip.Size               = UDim2.fromOffset(18, 18)
	grip.AnchorPoint        = Vector2.new(1, 1)
	grip.Position           = UDim2.fromScale(1, 1)
	grip.BackgroundTransparency = 1
	grip.Text               = ""
	grip.ZIndex             = 20
	for _, pt in ipairs({ {11,11},{6,11},{11,6} }) do
		local d = Instance.new("Frame", grip)
		d.Size            = UDim2.fromOffset(3, 3)
		d.Position        = UDim2.fromOffset(pt[1], pt[2])
		d.BackgroundColor3 = D.Muted
		d.BorderSizePixel = 0
		corner(d)
	end
	do
		local rD, rS, rSz
		grip.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				rD, rS, rSz = true, inp.Position, main.AbsoluteSize
				inp.Changed:Connect(function()
					if inp.UserInputState == Enum.UserInputState.End then rD = false end
				end)
			end
		end)
		UIS.InputChanged:Connect(function(inp)
			if rD and inp.UserInputType == Enum.UserInputType.MouseMovement then
				local d = inp.Position - rS
				main.Size = UDim2.fromOffset(
					math.max(minW, rSz.X + d.X),
					math.max(minH, rSz.Y + d.Y))
			end
		end)
	end

	-- ── SIDEBAR ─────────────────────────────────────
	local SIDEBAR_W = 150
	local sidebar = Instance.new("Frame", main)
	sidebar.Name                  = "Sidebar"
	sidebar.Size                  = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H)
	sidebar.Position              = UDim2.fromOffset(0, TOPBAR_H)
	sidebar.BackgroundColor3      = D.Sidebar
	sidebar.BackgroundTransparency = 0
	sidebar.BorderSizePixel       = 0
	sidebar.ZIndex                = 3

	local sbLine = Instance.new("Frame", sidebar)
	sbLine.Size            = UDim2.new(0, 1, 1, 0)
	sbLine.Position        = UDim2.new(1, -1, 0, 0)
	sbLine.BackgroundColor3 = D.Stroke
	sbLine.BorderSizePixel = 0

	-- spring indicator
	local indicator = Instance.new("Frame", sidebar)
	indicator.Size            = UDim2.fromOffset(3, 20)
	indicator.Position        = UDim2.fromOffset(6, 18)
	indicator.BorderSizePixel = 0
	corner(indicator, 2)
	onAccent(function(c) indicator.BackgroundColor3 = c end)

	local navHolder = Instance.new("Frame", sidebar)
	navHolder.BackgroundTransparency = 1
	navHolder.Size                   = UDim2.fromScale(1, 1)
	navHolder.ClipsDescendants       = true
	listLayout(navHolder, 2)
	padding(navHolder, 8, 8, 12, 12)

	-- ── CONTENT ─────────────────────────────────────
	local contentArea = Instance.new("Frame", main)
	contentArea.Name                  = "Content"
	contentArea.BackgroundTransparency = 1
	contentArea.Size                  = UDim2.new(1, -SIDEBAR_W, 1, -TOPBAR_H)
	contentArea.Position              = UDim2.fromOffset(SIDEBAR_W, TOPBAR_H)
	contentArea.ClipsDescendants      = true
	contentArea.ZIndex                = 2

	-- ── WINDOW OBJECT ───────────────────────────────
	local WIN = {
		Gui = GUI, Main = main,
		tabs = {}, activeTab = nil,
		cfg = cfg,
	}

	local TAB_H = 34
	local function tabY(order) return 12 + order * (TAB_H + 3) + 7 end

	local function selectTab(tab)
		if WIN.activeTab == tab then return end
		if WIN.activeTab then
			local p = WIN.activeTab
			tw(p.btn, TI.fast, { BackgroundTransparency = 1, TextColor3 = D.Sub })
			p.page.Visible = false
		end
		WIN.activeTab = tab
		tw(tab.btn, TI.fast, { BackgroundTransparency = 0.14, TextColor3 = D.Text })
		tab.page.Position = UDim2.fromOffset(0, 10)
		tab.page.Visible  = true
		tw(tab.page, TI.quint, { Position = UDim2.fromOffset(0, 0) })
		-- spring-slide indicator
		tw(indicator,
			TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(6, tabY(tab.order)) })
		indicator.Size = UDim2.fromOffset(4, 24)
		task.delay(0.08, function()
			tw(indicator, TI.spring, { Size = UDim2.fromOffset(3, 20) })
		end)
	end

	-- ── AddTab ──────────────────────────────────────
	function WIN:AddTab(topts)
		topts = topts or {}
		local order = #self.tabs

		-- group separator
		if topts.Group and topts.Group ~= "" then
			local seen = false
			for _, c in ipairs(navHolder:GetChildren()) do
				if c:IsA("TextLabel") and c.Text == topts.Group:upper() then seen = true; break end
			end
			if not seen then
				local gl = Instance.new("TextLabel", navHolder)
				gl.Text              = topts.Group:upper()
				gl.Font              = Enum.Font.GothamBold
				gl.TextSize          = 8
				gl.TextColor3        = D.Muted
				gl.BackgroundTransparency = 1
				gl.Size              = UDim2.new(1, 0, 0, 16)
				gl.TextXAlignment    = Enum.TextXAlignment.Left
				gl.LayoutOrder       = order * 10
				padding(gl, 4, 0, 2, 0)
			end
		end

		-- tab button
		local btn = Instance.new("TextButton", navHolder)
		btn.Size                = UDim2.new(1, 0, 0, TAB_H)
		btn.BackgroundColor3    = D.CardHov
		btn.BackgroundTransparency = 1
		btn.Text                = "  " .. tostring(topts.Title or "Tab")
		btn.TextColor3          = D.Sub
		btn.Font                = Enum.Font.GothamMedium
		btn.TextSize            = 11
		btn.TextXAlignment      = Enum.TextXAlignment.Left
		btn.AutoButtonColor     = false
		btn.LayoutOrder         = order * 10 + 1
		corner(btn, 8)

		btn.MouseEnter:Connect(function()
			if WIN.activeTab and WIN.activeTab.btn == btn then return end
			tw(btn, TI.hover, { BackgroundTransparency = 0.65, TextColor3 = D.Text })
		end)
		btn.MouseLeave:Connect(function()
			if WIN.activeTab and WIN.activeTab.btn == btn then return end
			tw(btn, TI.hover, { BackgroundTransparency = 1, TextColor3 = D.Sub })
		end)

		-- scrollable page
		local page = Instance.new("ScrollingFrame", contentArea)
		page.Name                   = "Page_" .. tostring(topts.Title or order)
		page.Size                   = UDim2.fromScale(1, 1)
		page.BackgroundTransparency = 1
		page.BorderSizePixel        = 0
		page.ScrollBarThickness     = 2
		page.ScrollBarImageColor3   = D.StrokeH
		page.ScrollBarImageTransparency = 0.3
		page.TopImage    = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		page.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		page.MidImage    = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.CanvasSize          = UDim2.new()
		page.Visible             = false
		listLayout(page, 6)
		padding(page, 14, 14, 12, 14)

		local tabObj = {
			btn = btn, page = page, order = order,
			elements = {}, _order = 0,
		}

		btn.MouseButton1Click:Connect(function() selectTab(tabObj) end)
		table.insert(self.tabs, tabObj)
		if not WIN.activeTab then selectTab(tabObj) end

		local function nxt()
			tabObj._order = tabObj._order + 1
			return tabObj._order
		end

		-- ── AddSection ────────────────────────────
		function tabObj:AddSection(name)
			local f = Instance.new("Frame", page)
			f.Size = UDim2.new(1, 0, 0, 24)
			f.BackgroundTransparency = 1
			f.LayoutOrder = nxt()
			local lbl = newLabel(f, name:upper(), 9, D.Accent, nil, true)
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.AutomaticSize = Enum.AutomaticSize.None
			lbl.TextYAlignment = Enum.TextYAlignment.Bottom
			local lp = Instance.new("UIPadding", lbl)
			lp.PaddingLeft   = UDim.new(0, 2)
			lp.PaddingBottom = UDim.new(0, 2)
			onAccent(function(c) lbl.TextColor3 = c end)
		end

		-- ── AddLabel ──────────────────────────────
		function tabObj:AddLabel(text)
			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.BackgroundColor3 = D.Card
			card.BackgroundTransparency = 0.18
			card.LayoutOrder = nxt()
			corner(card, 10)
			local cst = stroke(card, D.Stroke, 1)
			padding(card, 12, 12, 8, 8)
			cardHoverFX(card, cst)
			local lbl = newLabel(card, tostring(text), 10, D.Sub)
			lbl.TextWrapped = true
			local obj = {}
			function obj:Set(t) lbl.Text = tostring(t) end
			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── AddToggle ─────────────────────────────
		function tabObj:AddToggle(topts2)
			topts2 = topts2 or {}
			local flagKey = topts2.Flag and ("tgl_" .. tostring(topts2.Flag))
			local def = topts2.Default
			if saveOn and flagKey then def = cfg:bool(flagKey, def) end
			local value = def == true

			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 44)
			card.BackgroundColor3 = D.Card
			card.BackgroundTransparency = 0.18
			card.LayoutOrder = nxt()
			corner(card, 10)
			local cst = stroke(card, D.Stroke, 1)
			padding(card, 12, 12, 0, 0)
			cardHoverFX(card, cst)

			local nameLbl = newLabel(card, tostring(topts2.Name or "Toggle"), 11, D.Text)
			nameLbl.Size = UDim2.new(1, -66, 1, 0)
			nameLbl.AutomaticSize = Enum.AutomaticSize.None
			nameLbl.TextYAlignment = Enum.TextYAlignment.Center

			-- track
			local track = Instance.new("Frame", card)
			track.Size            = UDim2.fromOffset(44, 22)
			track.AnchorPoint     = Vector2.new(1, 0.5)
			track.Position        = UDim2.new(1, -8, 0.5, 0)
			track.BackgroundColor3 = value and D.Accent or D.TogOff
			corner(track, 11)
			local trackUs = Instance.new("UIScale", track); trackUs.Scale = 1
			onAccent(function(c) if value then track.BackgroundColor3 = c end end)

			-- knob
			local knob = Instance.new("Frame", track)
			knob.Size            = UDim2.fromOffset(16, 16)
			knob.Position        = value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
			knob.BackgroundColor3 = Color3.new(1, 1, 1)
			knob.BorderSizePixel = 0
			corner(knob, 10)
			local knobUs = Instance.new("UIScale", knob); knobUs.Scale = 1

			local obj = {}
			function obj:Set(v, silent)
				value = v == true
				tw(track,  TI.fast,   { BackgroundColor3 = value and D.Accent or D.TogOff })
				tw(knob,   TI.bounce, { Position = value and UDim2.fromOffset(25,3) or UDim2.fromOffset(3,3) })
				tw(knobUs, TI.bounce, { Scale = value and 1.14 or 1 })
				task.delay(0.18, function() tw(knobUs, TI.fast, { Scale = 1 }) end)
				if not silent and topts2.Callback then pcall(topts2.Callback, value) end
				if saveOn and flagKey then cfg:save(flagKey, tostring(value)) end
			end
			function obj:Get() return value end

			track.MouseEnter:Connect(function() tw(trackUs, TI.hover, { Scale = 1.08 }) end)
			track.MouseLeave:Connect(function() tw(trackUs, TI.hover, { Scale = 1 }) end)

			local hit = Instance.new("TextButton", card)
			hit.Size = UDim2.fromScale(1, 1)
			hit.BackgroundTransparency = 1
			hit.Text = ""; hit.ZIndex = 2
			hit.MouseButton1Click:Connect(function() obj:Set(not value) end)

			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── AddSlider ─────────────────────────────
		function tabObj:AddSlider(sopts)
			sopts = sopts or {}
			local flagKey = sopts.Flag and ("sld_" .. tostring(sopts.Flag))
			local minV, maxV = sopts.Min or 0, sopts.Max or 100
			local step = sopts.Step or 1
			local def  = sopts.Default or minV
			if saveOn and flagKey then def = cfg:num(flagKey, def) end
			local value = math.clamp(def, minV, maxV)

			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 56)
			card.BackgroundColor3 = D.Card
			card.BackgroundTransparency = 0.18
			card.LayoutOrder = nxt()
			corner(card, 10)
			local cst = stroke(card, D.Stroke, 1)
			padding(card, 12, 12, 0, 0)
			cardHoverFX(card, cst)

			local nameLbl = newLabel(card, tostring(sopts.Name or "Slider"), 11, D.Text)
			nameLbl.Size = UDim2.new(1, -68, 0, 20)
			nameLbl.AutomaticSize = Enum.AutomaticSize.None
			nameLbl.Position = UDim2.fromOffset(0, 10)
			nameLbl.TextYAlignment = Enum.TextYAlignment.Center

			local valLbl = Instance.new("TextLabel", card)
			valLbl.Size            = UDim2.fromOffset(62, 20)
			valLbl.AnchorPoint     = Vector2.new(1, 0)
			valLbl.Position        = UDim2.new(1, 0, 0, 10)
			valLbl.BackgroundTransparency = 1
			valLbl.Font            = Enum.Font.GothamBold
			valLbl.TextSize        = 11
			valLbl.TextXAlignment  = Enum.TextXAlignment.Right
			onAccent(function(c) valLbl.TextColor3 = c end)

			local trackBg = Instance.new("Frame", card)
			trackBg.Size           = UDim2.new(1, -6, 0, 4)
			trackBg.Position       = UDim2.fromOffset(0, 42)
			trackBg.BackgroundColor3 = D.TogOff
			corner(trackBg, 2)

			local fill = Instance.new("Frame", trackBg)
			fill.Size = UDim2.fromScale(0, 1)
			fill.BorderSizePixel = 0
			corner(fill, 2)
			onAccent(function(c) fill.BackgroundColor3 = c end)

			local sknob = Instance.new("Frame", trackBg)
			sknob.Size           = UDim2.fromOffset(12, 12)
			sknob.AnchorPoint    = Vector2.new(0.5, 0.5)
			sknob.Position       = UDim2.fromScale(0, 0.5)
			sknob.BackgroundColor3 = Color3.new(1, 1, 1)
			sknob.BorderSizePixel = 0
			corner(sknob, 7)
			local sks = Instance.new("UIScale", sknob); sks.Scale = 1

			local draggingSlider = false
			local function updateVis(v, anim)
				local pct  = (v - minV) / math.max(maxV - minV, 1)
				local info = anim and TI.fast or TweenInfo.new(0)
				tw(fill,  info, { Size = UDim2.fromScale(pct, 1) })
				tw(sknob, info, { Position = UDim2.fromScale(pct, 0.5) })
				valLbl.Text = tostring(v)
			end
			local function setVal(v)
				value = math.clamp(math.round(v / step) * step, minV, maxV)
				updateVis(value, true)
				if sopts.Callback then pcall(sopts.Callback, value) end
				if saveOn and flagKey then cfg:save(flagKey, tostring(value)) end
			end
			local function fromMouse()
				local abs = trackBg.AbsolutePosition
				local sz  = trackBg.AbsoluteSize
				setVal(minV + (maxV - minV) * math.clamp((_mouse.X - abs.X) / math.max(sz.X, 1), 0, 1))
			end

			trackBg.MouseEnter:Connect(function() tw(sks, TI.hover, { Scale = 1.3 }) end)
			trackBg.MouseLeave:Connect(function()
				if not draggingSlider then tw(sks, TI.hover, { Scale = 1 }) end
			end)

			local sHit = Instance.new("TextButton", card)
			sHit.Size     = UDim2.new(1, -6, 0, 22)
			sHit.Position = UDim2.fromOffset(0, 34)
			sHit.BackgroundTransparency = 1
			sHit.Text = ""
			sHit.MouseButton1Down:Connect(function()
				draggingSlider = true
				tw(sks, TI.fast, { Scale = 1.5 })
				fromMouse()
			end)
			UIS.InputEnded:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 and draggingSlider then
					draggingSlider = false
					tw(sks, TI.bounce, { Scale = 1 })
				end
			end)
			UIS.InputChanged:Connect(function(inp)
				if draggingSlider and inp.UserInputType == Enum.UserInputType.MouseMovement then
					fromMouse()
				end
			end)
			updateVis(value, false)

			local obj = {}
			function obj:Set(v) setVal(v or def) end
			function obj:Get() return value end
			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── AddButton ─────────────────────────────
		function tabObj:AddButton(bopts)
			bopts = bopts or {}
			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 44)
			card.BackgroundColor3 = D.Card
			card.BackgroundTransparency = 0.18
			card.LayoutOrder = nxt()
			corner(card, 10)
			local cst = stroke(card, D.Stroke, 1)
			padding(card, 12, 12, 0, 0)
			cardHoverFX(card, cst)

			local nameLbl = newLabel(card, tostring(bopts.Name or "Button"), 11, D.Text)
			nameLbl.Size = UDim2.new(1, -112, 1, 0)
			nameLbl.AutomaticSize = Enum.AutomaticSize.None
			nameLbl.TextYAlignment = Enum.TextYAlignment.Center

			local isDanger  = bopts.Style == "Danger"
			local isPrimary = bopts.Style == "Primary"

			local btn = Instance.new("TextButton", card)
			btn.Size            = UDim2.fromOffset(94, 28)
			btn.AnchorPoint     = Vector2.new(1, 0.5)
			btn.Position        = UDim2.new(1, -6, 0.5, 0)
			btn.BackgroundColor3 = isDanger and D.Danger or D.Surface
			btn.BackgroundTransparency = isPrimary and 0 or 0.1
			btn.Text            = "Run"
			btn.Font            = Enum.Font.GothamBold
			btn.TextSize        = 11
			btn.AutoButtonColor = false
			btn.ClipsDescendants = true
			corner(btn, 8)
			local bst = stroke(btn, isDanger and D.Danger or D.Accent, 1)
			onAccent(function(c) if not isDanger then bst.Color = c end end)
			if isPrimary then
				btn.TextColor3 = D.Bg
				btn.BackgroundColor3 = D.Accent
				onAccent(function(c) btn.BackgroundColor3 = c end)
			else
				btn.TextColor3 = D.Text
			end
			springScale(btn, 1.07, 0.92)

			-- ripple
			btn.MouseButton1Click:Connect(function()
				local r = Instance.new("Frame", btn)
				r.Size = UDim2.fromOffset(60, 60)
				r.Position = UDim2.fromOffset(
					btn.AbsoluteSize.X/2 - 30, btn.AbsoluteSize.Y/2 - 30)
				r.BackgroundColor3 = Color3.new(1, 1, 1)
				r.BackgroundTransparency = 0.7
				r.ZIndex = 10
				r.BorderSizePixel = 0
				corner(r, 30)
				tw(r, TweenInfo.new(0.38), {
					Size = UDim2.fromOffset(200, 200),
					Position = UDim2.fromOffset(-70, -70),
					BackgroundTransparency = 1,
				})
				task.delay(0.40, function() if r and r.Parent then r:Destroy() end end)
				if bopts.Callback then pcall(bopts.Callback) end
			end)
		end

		-- ── AddDropdown ───────────────────────────
		function tabObj:AddDropdown(dopts)
			dopts = dopts or {}
			local flagKey = dopts.Flag and ("dd_" .. tostring(dopts.Flag))
			local options = type(dopts.Options) == "table" and dopts.Options or {}
			local def     = dopts.Default or (options[1] and tostring(options[1]))
			if saveOn and flagKey then def = cfg:load(flagKey, def) end
			local selected = def

			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 44)
			card.BackgroundColor3 = D.Card
			card.BackgroundTransparency = 0.18
			card.LayoutOrder = nxt()
			corner(card, 10)
			local cst = stroke(card, D.Stroke, 1)
			padding(card, 12, 12, 0, 0)
			cardHoverFX(card, cst)

			local nameLbl = newLabel(card, tostring(dopts.Name or "Dropdown"), 11, D.Text)
			nameLbl.Size = UDim2.new(1, -122, 1, 0)
			nameLbl.AutomaticSize = Enum.AutomaticSize.None
			nameLbl.TextYAlignment = Enum.TextYAlignment.Center

			local selBtn = Instance.new("TextButton", card)
			selBtn.Size            = UDim2.fromOffset(108, 28)
			selBtn.AnchorPoint     = Vector2.new(1, 0.5)
			selBtn.Position        = UDim2.new(1, -6, 0.5, 0)
			selBtn.BackgroundColor3 = D.Surface
			selBtn.Text            = tostring(selected or "Select…")
			selBtn.Font            = Enum.Font.GothamBold
			selBtn.TextSize        = 10
			selBtn.AutoButtonColor = false
			corner(selBtn, 8)
			local sbst = stroke(selBtn, D.Accent, 1)
			onAccent(function(c) sbst.Color = c; selBtn.TextColor3 = c end)
			selBtn.TextColor3 = D.Accent
			springScale(selBtn, 1.05, 0.93)

			local popup, popOpen = nil, false
			selBtn.MouseButton1Click:Connect(function()
				if popOpen and popup then popup:Destroy(); popup, popOpen = nil, false; return end
				popOpen = true
				popup = Instance.new("Frame", GUI)
				popup.BackgroundColor3 = D.Sidebar
				popup.BackgroundTransparency = 0
				popup.Size = UDim2.fromOffset(148, math.min(#options, 8) * 28 + 10)
				popup.ZIndex = 200
				corner(popup, 10)
				stroke(popup, D.StrokeH, 1)
				local abs = selBtn.AbsolutePosition
				popup.Position = UDim2.fromOffset(abs.X, abs.Y + selBtn.AbsoluteSize.Y + 4)
				listLayout(popup, 2)
				padding(popup, 6, 6, 4, 4)

				for _, opt in ipairs(options) do
					local ob = Instance.new("TextButton", popup)
					ob.Size = UDim2.new(1, 0, 0, 26)
					ob.BackgroundTransparency = 1
					ob.Text = tostring(opt)
					ob.Font = Enum.Font.GothamMedium
					ob.TextSize = 11
					ob.AutoButtonColor = false
					ob.TextXAlignment = Enum.TextXAlignment.Left
					ob.TextColor3 = tostring(opt) == tostring(selected) and D.Accent or D.Text
					local op2 = Instance.new("UIPadding", ob)
					op2.PaddingLeft = UDim.new(0, 8)
					ob.MouseEnter:Connect(function()
						tw(ob, TI.hover, { BackgroundTransparency = 0.60, BackgroundColor3 = D.CardHov })
					end)
					ob.MouseLeave:Connect(function()
						tw(ob, TI.hover, { BackgroundTransparency = 1 })
					end)
					ob.MouseButton1Click:Connect(function()
						selected = tostring(opt)
						selBtn.Text = selected
						popup:Destroy(); popup, popOpen = nil, false
						if saveOn and flagKey then cfg:save(flagKey, selected) end
						if dopts.Callback then pcall(dopts.Callback, selected) end
					end)
				end
				-- close on outside click
				task.spawn(function()
					task.wait(0.05)
					local conn
					conn = UIS.InputBegan:Connect(function(inp)
						if inp.UserInputType == Enum.UserInputType.MouseButton1 then
							task.defer(function()
								if popup and popup.Parent then popup:Destroy() end
								popup, popOpen = nil, false
								pcall(function() conn:Disconnect() end)
							end)
						end
					end)
				end)
			end)

			local obj = {}
			function obj:Set(v, silent)
				selected = tostring(v); selBtn.Text = selected
				if not silent and dopts.Callback then pcall(dopts.Callback, selected) end
			end
			function obj:Get() return selected end
			function obj:SetOptions(newOpts)
				options = type(newOpts) == "table" and newOpts or {}
			end
			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── AddStats ──────────────────────────────
		function tabObj:AddStats(sopts2)
			sopts2 = sopts2 or {}
			local cols  = sopts2.Columns or 3
			local items = sopts2.Items or {}

			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 56)
			card.BackgroundColor3 = D.Card
			card.BackgroundTransparency = 0.18
			card.LayoutOrder = nxt()
			corner(card, 10)
			stroke(card, D.Stroke, 1)
			local grid = Instance.new("UIGridLayout", card)
			grid.CellSize    = UDim2.new(1/cols, -6, 1, -6)
			grid.CellPadding = UDim2.fromOffset(4, 4)
			padding(card, 8, 8, 6, 6)

			local cellMap = {}
			for _, item in ipairs(items) do
				local cell = Instance.new("Frame", card)
				cell.BackgroundTransparency = 1
				local vl = newLabel(cell, tostring(item.Value or "0"), 15, D.Accent,
					Enum.TextXAlignment.Center, true)
				vl.Size = UDim2.new(1, 0, 0, 22)
				vl.AutomaticSize = Enum.AutomaticSize.None
				vl.TextYAlignment = Enum.TextYAlignment.Center
				onAccent(function(c) vl.TextColor3 = c end)
				local ll2 = newLabel(cell, tostring(item.Label or ""), 9, D.Sub,
					Enum.TextXAlignment.Center)
				ll2.Position = UDim2.fromOffset(0, 22)
				ll2.Size     = UDim2.new(1, 0, 0, 14)
				ll2.AutomaticSize = Enum.AutomaticSize.None
				cellMap[item.Id] = vl
			end

			local obj = {}
			function obj:Set(id, val)
				if cellMap[id] then cellMap[id].Text = tostring(val) end
			end
			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── Clear ─────────────────────────────────
		function tabObj:Clear()
			for _, c in ipairs(page:GetChildren()) do
				if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
					c:Destroy()
				end
			end
			tabObj._order    = 0
			tabObj.elements  = {}
		end

		return tabObj
	end

	function WIN:Notify(opts2) pushToast(GUI, opts2 or {}) end

	function WIN:SetSize(w, h)
		main.Size = UDim2.fromOffset(math.max(minW, w), math.max(minH, h))
	end

	WIN.SetAccent = setAccent

	return WIN
end

-- ════════════════════════════════════════════
--  SPLASH
-- ════════════════════════════════════════════
local function createSplash(_, opts)
	opts = opts or {}
	local sg = Instance.new("ScreenGui")
	sg.Name = "VeltLib3_Splash"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	do
		local parent2 = PGui
		if type(gethui) == "function" then
			local ok2, h2 = pcall(gethui)
			if ok2 and h2 then parent2 = h2 end
		elseif pcall(function()
				local p = Instance.new("ScreenGui")
				p.Parent = game:GetService("CoreGui")
				p:Destroy()
			end) then
			parent2 = game:GetService("CoreGui")
		end
		sg.Parent = parent2
	end

	local bg = Instance.new("Frame", sg)
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = D.Bg
	bg.BorderSizePixel  = 0

	-- logo ring
	local ring = Instance.new("Frame", bg)
	ring.Size         = UDim2.fromOffset(80, 80)
	ring.AnchorPoint  = Vector2.new(0.5, 0.5)
	ring.Position     = UDim2.new(0.5, 0, 0.5, -66)
	ring.BackgroundColor3 = D.Surface
	ring.BorderSizePixel  = 0
	corner(ring, 24)
	local rst = stroke(ring, D.Accent, 2)
	onAccent(function(c) rst.Color = c end)

	-- splash logo — always use built-in logo URL (or caller override)
	local _splashLogo = (opts.LogoId and opts.LogoId ~= "")
		and ("rbxassetid://" .. tostring(opts.LogoId):gsub("rbxassetid://",""))
		or "https://raw.githubusercontent.com/erszxu-hmm/velt-assets/main/velt_logo.png"
	do
		local li = Instance.new("ImageLabel", ring)
		li.Size = UDim2.fromScale(0.72, 0.72)
		li.AnchorPoint = Vector2.new(0.5, 0.5)
		li.Position = UDim2.fromScale(0.5, 0.5)
		li.BackgroundTransparency = 1
		li.ScaleType = Enum.ScaleType.Fit
		li.Image = _splashLogo
	end

	local titleL = newLabel(bg, "VELT", 22, D.Accent, Enum.TextXAlignment.Center, true)
	titleL.Position = UDim2.new(0, 0, 0.5, 2)
	titleL.Size = UDim2.new(1, 0, 0, 28)
	titleL.AutomaticSize = Enum.AutomaticSize.None
	titleL.TextYAlignment = Enum.TextYAlignment.Center
	onAccent(function(c) titleL.TextColor3 = c end)

	local subL = newLabel(bg, tostring(opts.Subtitle ~= "" and opts.Subtitle or autoSubtitle()), 11, D.Sub, Enum.TextXAlignment.Center)
	subL.Position = UDim2.new(0, 0, 0.5, 34)
	subL.Size = UDim2.new(1, 0, 0, 16)
	subL.AutomaticSize = Enum.AutomaticSize.None

	local statL = newLabel(bg, "Initializing…", 10, D.Muted, Enum.TextXAlignment.Center)
	statL.Position = UDim2.new(0, 0, 0.5, 90)
	statL.Size = UDim2.new(1, 0, 0, 14)
	statL.AutomaticSize = Enum.AutomaticSize.None

	local trackBg = Instance.new("Frame", bg)
	trackBg.Size = UDim2.fromOffset(220, 3)
	trackBg.AnchorPoint = Vector2.new(0.5, 0.5)
	trackBg.Position = UDim2.new(0.5, 0, 0.5, 72)
	trackBg.BackgroundColor3 = D.TogOff
	trackBg.BorderSizePixel  = 0
	corner(trackBg, 2)
	local pf = Instance.new("Frame", trackBg)
	pf.Size = UDim2.fromScale(0, 1)
	pf.BorderSizePixel = 0
	corner(pf, 2)
	onAccent(function(c) pf.BackgroundColor3 = c end)

	local obj = {}
	function obj:Preload() end
	function obj:Progress(p, text)
		tw(pf, TI.fast, { Size = UDim2.fromScale(math.clamp(p, 0, 1), 1) })
		if text then statL.Text = tostring(text) end
	end
	function obj:Finish()
		tw(bg, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 })
		task.delay(0.42, function() sg:Destroy() end)
	end
	return obj
end

-- ════════════════════════════════════════════
--  EXPORT
-- ════════════════════════════════════════════
local Velt = {}
Velt.__index = Velt
Velt.CreateWindow = createWindow
Velt.Splash       = createSplash
Velt.SetAccent    = setAccent
return setmetatable({}, Velt)
Velt.Splash       = newSplash
Velt.SetAccent    = setAccent
return setmetatable({}, Velt)
