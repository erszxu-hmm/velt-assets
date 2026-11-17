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
	VELT UI LIBRARY  v1.0
	Roblox executor library — returns a Velt object.
	API:
	  local Velt = loadstring(game:HttpGet(URL))()
	  local Window = Velt:CreateWindow({ Title, Subtitle, Size, SaveConfig, ConfigFolder, MinSize })
	  local tab    = Window:AddTab({ Title, Group })
	  tab:AddSection(name)
	  tab:AddToggle({ Name, Default, Flag, Callback })   -> toggle obj  :Get() :Set(v)
	  tab:AddSlider({ Name, Min, Max, Step, Default, Callback })
	  tab:AddButton({ Name, Style, Callback })
	  tab:AddLabel(text)  -> label obj  :Set(text)
	  tab:AddDropdown({ Name, Options, Default, Callback })
	  tab:AddStats({ Columns, Items=[{Id,Value,Label}] }) -> stats obj :Set(id, val)
	  tab:Clear()
	  Window:Notify({ Title, Content, Duration })
	  Window:SetSize(w, h)
	  Velt:Splash({ Subtitle }) -> splash  :Preload() :Progress(p, text) :Finish()
	  Velt:CreateWindow(...)   (alias)
]]

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UserInput      = game:GetService("UserInputService")
local RunService     = game:GetService("RunService")
local LP             = Players.LocalPlayer
local PlayerGui      = LP:WaitForChild("PlayerGui")

-- ── tween helpers ──
local TI = {
	fast   = TweenInfo.new(0.16, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	bounce = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	spring = TweenInfo.new(0.32, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	quint  = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}
local function tw(obj, info, props) TweenService:Create(obj, info, props):Play() end

-- ── design tokens ──
local T = {
	Bg        = Color3.fromRGB(13,  15,  20),
	Sidebar   = Color3.fromRGB(18,  20,  27),
	Card      = Color3.fromRGB(24,  27,  36),
	CardHov   = Color3.fromRGB(31,  35,  47),
	Stroke    = Color3.fromRGB(48,  54,  70),
	StrokeH   = Color3.fromRGB(82,  92, 118),
	Text      = Color3.fromRGB(244, 246, 250),
	Sub       = Color3.fromRGB(145, 153, 172),
	TogOff    = Color3.fromRGB(45,  50,  65),
	Accent    = Color3.fromRGB(232, 184, 102),
	Danger    = Color3.fromRGB(220,  60,  60),
	Good      = Color3.fromRGB( 52, 211, 153),
}

-- ── UIStroke helper ──
local function stroke(parent, col, thick)
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness, s.Parent = col or T.Stroke, thick or 1, parent
	return s
end
local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end
local function pad(parent, l, r_, t, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft, p.PaddingRight = UDim.new(0, l or 8), UDim.new(0, r_ or 8)
	p.PaddingTop,  p.PaddingBottom = UDim.new(0, t or 4), UDim.new(0, b or 4)
	p.Parent = parent
end
local function list(parent, gap, dir)
	local l = Instance.new("UIListLayout")
	l.Padding, l.SortOrder = UDim.new(0, gap or 4), Enum.SortOrder.LayoutOrder
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Parent = parent
	return l
end
local function label(parent, txt, size, col, align, bold)
	local l = Instance.new("TextLabel")
	l.Text, l.TextSize = tostring(txt), size or 11
	l.TextColor3 = col or T.Text
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.BackgroundTransparency = 1
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Size = UDim2.new(1, 0, 0, 0)
	l.Parent = parent
	return l
end
local function attachHover(frame, strokeObj)
	frame.MouseEnter:Connect(function()
		tw(frame, TI.fast, { BackgroundColor3 = T.CardHov })
		if strokeObj then tw(strokeObj, TI.fast, { Color = T.StrokeH }) end
	end)
	frame.MouseLeave:Connect(function()
		tw(frame, TI.fast, { BackgroundColor3 = T.Card })
		if strokeObj then tw(strokeObj, TI.fast, { Color = T.Stroke }) end
	end)
end
local function attachScale(btn, hs, cs)
	hs, cs = hs or 1.05, cs or 0.93
	local us = Instance.new("UIScale", btn); us.Scale = 1
	btn.MouseEnter:Connect(function() tw(us, TI.fast, { Scale = hs }) end)
	btn.MouseLeave:Connect(function() tw(us, TI.fast, { Scale = 1 }) end)
	if btn:IsA("GuiButton") then
		btn.MouseButton1Down:Connect(function() tw(us, TI.fast, { Scale = cs }) end)
		btn.MouseButton1Up:Connect(function() tw(us, TI.bounce, { Scale = 1 }) end)
	end
end

-- ============================================================
-- CONFIG  (save/load with pcall around every file op)
-- ============================================================
local function mkConfig(folder)
	local cfg = { folder = folder or "VeltUI", data = {} }
	local function path(key) return cfg.folder .. "/" .. key .. ".txt" end
	local function ensureFolder()
		if isfolder and not isfolder(cfg.folder) then
			if makefolder then pcall(makefolder, cfg.folder) end
		end
	end
	function cfg:save(key, val)
		ensureFolder()
		if writefile then pcall(writefile, path(key), tostring(val)) end
	end
	function cfg:load(key, default)
		if readfile and isfile then
			local ok, v = pcall(function()
				if isfile(path(key)) then return readfile(path(key)) end
			end)
			if ok and v ~= nil then return v end
		end
		return default
	end
	function cfg:loadBool(key, default)
		local v = self:load(key, nil)
		if v == nil then return default end
		return v == "true"
	end
	function cfg:loadNum(key, default)
		local v = self:load(key, nil)
		return tonumber(v) or default
	end
	return cfg
end

-- ============================================================
-- TOAST  (slide in from bottom-right)
-- ============================================================
local toastHolder
local function ensureToastHolder(gui)
	if toastHolder and toastHolder.Parent then return toastHolder end
	toastHolder = Instance.new("Frame")
	toastHolder.Name = "VeltToasts"
	toastHolder.Size = UDim2.new(0, 280, 0, 300)
	toastHolder.Position = UDim2.new(1, -292, 1, -312)
	toastHolder.BackgroundTransparency = 1
	toastHolder.ZIndex = 200
	toastHolder.Parent = gui
	local ll = Instance.new("UIListLayout", toastHolder)
	ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
	ll.Padding = UDim.new(0, 6)
	return toastHolder
end

local function showNotify(gui, opts)
	local holder = ensureToastHolder(gui)
	local dur = opts.Duration or 3
	local col = T.Accent
	if opts.Title and opts.Title:lower():find("error") then col = T.Danger end

	local wrap = Instance.new("Frame", holder)
	wrap.Size = UDim2.new(1, 0, 0, 0)
	wrap.AutomaticSize = Enum.AutomaticSize.Y
	wrap.BackgroundTransparency = 1

	local card = Instance.new("Frame", wrap)
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = T.Sidebar
	card.BackgroundTransparency = 0.1
	card.Position = UDim2.fromOffset(32, 0)
	corner(card, 10)
	stroke(card, col)
	pad(card, 14, 12, 8, 8)

	local bar = Instance.new("Frame", card)
	bar.Size = UDim2.fromOffset(3, 16)
	bar.Position = UDim2.fromOffset(-10, 2)
	bar.BackgroundColor3 = col
	corner(bar, 2)

	local inner = Instance.new("Frame", card)
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	list(inner, 2)

	if opts.Title and opts.Title ~= "" then
		local t = label(inner, opts.Title, 12, T.Text, nil, true)
		t.LayoutOrder = 1
	end
	if opts.Content and opts.Content ~= "" then
		local sub = label(inner, opts.Content, 10, T.Sub)
		sub.LayoutOrder = 2
	end
	inner.Parent = card

	-- animate in
	card.BackgroundTransparency = 1
	tw(card, TI.quint, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0.1 })

	task.delay(dur, function()
		if not wrap or not wrap.Parent then return end
		tw(card, TI.fast, { Position = UDim2.fromOffset(32, 0), BackgroundTransparency = 1 })
		task.wait(0.22)
		if wrap then wrap:Destroy() end
	end)
end

-- ============================================================
-- WINDOW
-- ============================================================
local function createWindow(velt, opts)
	opts = opts or {}
	local cfg = mkConfig(opts.ConfigFolder or "VeltUI")
	local saveEnabled = opts.SaveConfig == true

	-- destroy old UI
	for _, root in ipairs({ PlayerGui, game:GetService("CoreGui") }) do
		local old = root:FindFirstChild("VeltLib_GUI")
		if old then old:Destroy() end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "VeltLib_GUI"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.Parent = (gethui and gethui()) or PlayerGui

	local W, H = 580, 380
	if opts.Size then W, H = opts.Size.X.Offset, opts.Size.Y.Offset end
	local minW = (opts.MinSize and opts.MinSize.X) or 320
	local minH = (opts.MinSize and opts.MinSize.Y) or 240

	-- ── Main frame ──
	local vp = workspace.CurrentCamera.ViewportSize
	local mainF = Instance.new("CanvasGroup", gui)
	mainF.Name = "Main"
	mainF.Size = UDim2.fromOffset(W, H)
	mainF.Position = UDim2.fromOffset(math.floor((vp.X - W)/2), math.floor((vp.Y - H)/2))
	mainF.BackgroundColor3 = T.Bg
	mainF.BackgroundTransparency = 0.1
	mainF.GroupTransparency = 1
	corner(mainF, 14)
	stroke(mainF, T.Stroke, 1.2)

	-- specular line
	local spec = Instance.new("Frame", mainF)
	spec.Size = UDim2.new(0.76, 0, 0, 1)
	spec.Position = UDim2.new(0.12, 0, 0, 0)
	spec.BackgroundColor3 = T.Accent
	spec.BackgroundTransparency = 0.55
	spec.BorderSizePixel = 0

	-- glass gradient
	local gg = Instance.new("UIGradient", mainF)
	gg.Rotation = 135
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,0.08) })

	-- cursor spotlight
	local spot = Instance.new("Frame", mainF)
	spot.Size = UDim2.fromScale(1,1)
	spot.BackgroundTransparency = 1
	spot.ZIndex = 1
	local spotG = Instance.new("UIGradient", spot)
	spotG.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, T.Accent), ColorSequenceKeypoint.new(1, Color3.new(0,0,0)) })
	spotG.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0.9), NumberSequenceKeypoint.new(0.4,0.97), NumberSequenceKeypoint.new(1,1) })

	local mouse = LP:GetMouse()
	RunService.RenderStepped:Connect(function()
		if not mainF.Visible or mainF.GroupTransparency > 0.9 then return end
		local abs, sz = mainF.AbsolutePosition, mainF.AbsoluteSize
		if sz.X < 1 then return end
		local nx = math.clamp((mouse.X - abs.X)/sz.X, 0, 1)
		local ny = math.clamp((mouse.Y - abs.Y)/sz.Y, 0, 1)
		spotG.Offset = Vector2.new(nx - 0.5, ny - 0.5)
	end)

	-- open anim
	local mainScale = Instance.new("UIScale", mainF)
	mainScale.Scale = 0.90
	mainF.Visible = true
	tw(mainF, TI.quint, { GroupTransparency = 0 })
	tw(mainScale, TI.spring, { Scale = 1 })

	-- ── Shadow ──
	local shadow = Instance.new("ImageLabel", gui)
	shadow.Name = "Shadow"
	shadow.Image = "rbxassetid://6014261993"
	shadow.ImageColor3 = Color3.new(0,0,0)
	shadow.ImageTransparency = 0.5
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(49,49,450,450)
	shadow.BackgroundTransparency = 1
	shadow.ZIndex = 0
	shadow.Size = mainF.Size + UDim2.fromOffset(60, 60)
	shadow.Position = mainF.Position - UDim2.fromOffset(30, 22)
	mainF:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = mainF.Position - UDim2.fromOffset(30, 22)
	end)
	mainF:GetPropertyChangedSignal("Size"):Connect(function()
		shadow.Size = mainF.Size + UDim2.fromOffset(60, 60)
	end)

	-- ── Topbar ──
	local topbar = Instance.new("Frame", mainF)
	topbar.Name = "Topbar"
	topbar.Size = UDim2.new(1, 0, 0, 48)
	topbar.BackgroundColor3 = T.Sidebar
	topbar.BackgroundTransparency = 0.22
	topbar.BorderSizePixel = 0
	topbar.ZIndex = 4
	corner(topbar, 14)
	local topClip = Instance.new("Frame", topbar)
	topClip.Size = UDim2.new(1, 0, 0.5, 0)
	topClip.Position = UDim2.new(0, 0, 0.5, 0)
	topClip.BackgroundColor3 = T.Sidebar
	topClip.BackgroundTransparency = 0.22
	topClip.BorderSizePixel = 0
	topClip.ZIndex = 3
	local tbLine = Instance.new("Frame", topbar)
	tbLine.Size = UDim2.new(1, 0, 0, 1)
	tbLine.Position = UDim2.new(0, 0, 1, -1)
	tbLine.BackgroundColor3 = T.Stroke
	tbLine.BorderSizePixel = 0

	-- brand
	local brandLbl = Instance.new("TextLabel", topbar)
	brandLbl.Text = tostring(opts.Title or "Velt")
	brandLbl.Font = Enum.Font.GothamBold
	brandLbl.TextSize = 13
	brandLbl.TextColor3 = T.Accent
	brandLbl.BackgroundTransparency = 1
	brandLbl.Position = UDim2.fromOffset(18, 0)
	brandLbl.Size = UDim2.new(0, 180, 1, 0)
	brandLbl.TextXAlignment = Enum.TextXAlignment.Left
	brandLbl.ZIndex = 5

	local subLbl = Instance.new("TextLabel", topbar)
	subLbl.Text = tostring(opts.Subtitle or "")
	subLbl.Font = Enum.Font.Gotham
	subLbl.TextSize = 10
	subLbl.TextColor3 = T.Sub
	subLbl.BackgroundTransparency = 1
	subLbl.Position = UDim2.new(0, 18, 0.55, 0)
	subLbl.Size = UDim2.new(0, 160, 0, 14)
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.ZIndex = 5

	-- minimize btn
	local minBtn = Instance.new("TextButton", topbar)
	minBtn.Size = UDim2.fromOffset(28, 28)
	minBtn.AnchorPoint = Vector2.new(1, 0.5)
	minBtn.Position = UDim2.new(1, -12, 0.5, 0)
	minBtn.BackgroundColor3 = T.Card
	minBtn.Text = "—"
	minBtn.TextColor3 = T.Sub
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 12
	minBtn.AutoButtonColor = false
	minBtn.ZIndex = 5
	corner(minBtn, 8)
	stroke(minBtn, T.Stroke, 1)
	attachScale(minBtn, 1.1, 0.88)

	-- ── Island pill (minimize mode) ──
	local island = Instance.new("TextButton", gui)
	island.Name = "VeltIsland"
	island.Size = UDim2.fromOffset(190, 34)
	island.AnchorPoint = Vector2.new(0.5, 0)
	island.Position = UDim2.new(0.5, 0, 0, 14)
	island.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
	island.BackgroundTransparency = 0.1
	island.Text = ""
	island.AutoButtonColor = false
	island.Visible = false
	island.ZIndex = 60
	corner(island, 40)
	stroke(island, T.Accent, 1.2)
	local idot = Instance.new("Frame", island)
	idot.Size = UDim2.fromOffset(8,8)
	idot.Position = UDim2.fromOffset(14, 13)
	idot.BackgroundColor3 = T.Accent
	corner(idot)
	local ilbl = Instance.new("TextLabel", island)
	ilbl.Text = tostring(opts.Title or "Velt") .. "   •   tap to open"
	ilbl.Font = Enum.Font.GothamBold
	ilbl.TextSize = 11
	ilbl.TextColor3 = T.Text
	ilbl.BackgroundTransparency = 1
	ilbl.Position = UDim2.fromOffset(28, 0)
	ilbl.Size = UDim2.new(1, -32, 1, 0)
	ilbl.TextXAlignment = Enum.TextXAlignment.Left
	task.spawn(function()
		while idot and idot.Parent do
			tw(idot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0.65 })
			task.wait(1)
			tw(idot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 0 })
			task.wait(1)
		end
	end)
	attachScale(island, 1.05, 0.95)

	local isOpen = true
	local isAnimating = false

	local function openPanel()
		if isAnimating then return end
		isAnimating = true
		island.Visible = false
		mainF.Visible = true
		mainF.GroupTransparency = 1
		mainScale.Scale = 0.90
		tw(mainF, TI.quint, { GroupTransparency = 0 })
		tw(mainScale, TI.spring, { Scale = 1 })
		task.delay(0.32, function() isAnimating = false end)
		isOpen = true
	end

	local function closePanel()
		if isAnimating then return end
		isAnimating = true
		tw(mainF, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
		tw(mainScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.90 })
		task.delay(0.22, function()
			mainF.Visible = false
			island.Visible = true
			local is2 = Instance.new("UIScale", island); is2.Scale = 0.80
			tw(is2, TI.spring, { Scale = 1 })
			isAnimating = false
		end)
		isOpen = false
	end

	minBtn.MouseButton1Click:Connect(closePanel)
	island.MouseButton1Click:Connect(openPanel)
	UserInput.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.RightShift then
			if isOpen then closePanel() else openPanel() end
		end
	end)

	-- drag
	local dragging, dragStart, dragStartPos
	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			dragStartPos = mainF.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	local dragInput
	topbar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
	end)
	UserInput.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local d = input.Position - dragStart
			mainF.Position = UDim2.new(
				dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
				dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y)
		end
	end)

	-- resize grip
	local grip = Instance.new("TextButton", mainF)
	grip.Size = UDim2.fromOffset(18, 18)
	grip.AnchorPoint = Vector2.new(1, 1)
	grip.Position = UDim2.fromScale(1, 1)
	grip.BackgroundTransparency = 1
	grip.Text = ""
	grip.ZIndex = 20
	for _, pt in ipairs({{11,11},{6,11},{11,6}}) do
		local d = Instance.new("Frame", grip)
		d.Size = UDim2.fromOffset(3,3)
		d.Position = UDim2.fromOffset(pt[1], pt[2])
		d.BackgroundColor3 = T.Sub
		d.BackgroundTransparency = 0.5
		d.BorderSizePixel = 0
		corner(d)
	end
	do
		local rDrag, rStart, rSize
		grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				rDrag = true
				rStart = input.Position
				rSize = mainF.AbsoluteSize
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then rDrag = false end
				end)
			end
		end)
		UserInput.InputChanged:Connect(function(input)
			if rDrag and input.UserInputType == Enum.UserInputType.MouseMovement then
				local d = input.Position - rStart
				local nw = math.max(minW, rSize.X + d.X)
				local nh = math.max(minH, rSize.Y + d.Y)
				mainF.Size = UDim2.fromOffset(nw, nh)
			end
		end)
	end

	-- ── Sidebar ──
	local sidebar = Instance.new("Frame", mainF)
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 148, 1, -48)
	sidebar.Position = UDim2.fromOffset(0, 48)
	sidebar.BackgroundColor3 = T.Sidebar
	sidebar.BackgroundTransparency = 0.3
	sidebar.BorderSizePixel = 0
	local sbLine = Instance.new("Frame", sidebar)
	sbLine.Size = UDim2.new(0, 1, 1, 0)
	sbLine.Position = UDim2.new(1, -1, 0, 0)
	sbLine.BackgroundColor3 = T.Stroke
	sbLine.BorderSizePixel = 0

	-- indicator
	local indicator = Instance.new("Frame", sidebar)
	indicator.Size = UDim2.fromOffset(3, 20)
	indicator.Position = UDim2.fromOffset(8, 20)
	indicator.BackgroundColor3 = T.Accent
	indicator.BorderSizePixel = 0
	corner(indicator)

	local navHolder = Instance.new("Frame", sidebar)
	navHolder.BackgroundTransparency = 1
	navHolder.Size = UDim2.fromScale(1, 1)
	local navList = list(navHolder, 4)
	local navPad = Instance.new("UIPadding", navHolder)
	navPad.PaddingTop, navPad.PaddingLeft, navPad.PaddingRight = UDim.new(0,12), UDim.new(0,8), UDim.new(0,8)

	-- group headers in nav
	local groupSeps = {}
	local function ensureGroupHeader(groupName)
		if not groupName or groupName == "" then return end
		if groupSeps[groupName] then return end
		local lbl = Instance.new("TextLabel", navHolder)
		lbl.Text = string.upper(groupName)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 9
		lbl.TextColor3 = T.Sub
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, 18)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.LayoutOrder = (#navHolder:GetChildren()) * 10
		local lp = Instance.new("UIPadding", lbl)
		lp.PaddingLeft = UDim.new(0, 6)
		groupSeps[groupName] = true
	end

	-- ── Content area ──
	local contentArea = Instance.new("Frame", mainF)
	contentArea.Name = "Content"
	contentArea.BackgroundTransparency = 1
	contentArea.Size = UDim2.new(1, -148, 1, -48)
	contentArea.Position = UDim2.fromOffset(148, 48)
	contentArea.ClipsDescendants = true

	-- ── Tab management ──
	local WIN = { Gui = gui, Main = mainF, tabs = {}, activeTab = nil, cfg = cfg }

	local TAB_H = 34
	local function getTabY(order)
		return 12 + order * (TAB_H + 4) + 7
	end

	local function selectTab(tab)
		if WIN.activeTab == tab then return end
		if WIN.activeTab then
			local prev = WIN.activeTab
			tw(prev.btn, TI.fast, { BackgroundTransparency = 1, TextColor3 = T.Sub })
			prev.page.Visible = false
		end
		WIN.activeTab = tab
		tw(tab.btn, TI.fast, { BackgroundTransparency = 0.22, TextColor3 = T.Text })
		tab.page.Position = UDim2.fromOffset(0, 8)
		tab.page.Visible = true
		tw(tab.page, TI.quint, { Position = UDim2.fromOffset(0, 0) })
		local targetY = getTabY(tab.order)
		tw(indicator, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(8, targetY) })
		indicator.Size = UDim2.fromOffset(4, 24)
		task.delay(0.1, function() tw(indicator, TI.spring, { Size = UDim2.fromOffset(3, 20) }) end)
	end

	function WIN:AddTab(tabOpts)
		tabOpts = tabOpts or {}
		local order = #self.tabs
		ensureGroupHeader(tabOpts.Group)

		local btn = Instance.new("TextButton", navHolder)
		btn.Size = UDim2.new(1, 0, 0, TAB_H)
		btn.BackgroundColor3 = T.Card
		btn.BackgroundTransparency = 1
		btn.Text = "  " .. tostring(tabOpts.Title or "Tab")
		btn.TextColor3 = T.Sub
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 11
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = false
		btn.LayoutOrder = order * 10 + 1
		corner(btn, 8)
		attachScale(btn, 1.025, 0.97)

		local page = Instance.new("ScrollingFrame", contentArea)
		page.Name = "Page_" .. tostring(tabOpts.Title or order)
		page.Size = UDim2.fromScale(1, 1)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 3
		page.ScrollBarImageColor3 = T.Stroke
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.CanvasSize = UDim2.new()
		page.Visible = false
		local pageList = list(page, 6)
		local pagePad = Instance.new("UIPadding", page)
		pagePad.PaddingTop, pagePad.PaddingLeft, pagePad.PaddingRight, pagePad.PaddingBottom =
			UDim.new(0,12), UDim.new(0,12), UDim.new(0,12), UDim.new(0,12)

		local tabObj = { btn = btn, page = page, order = order, elements = {}, _order = 0 }

		btn.MouseButton1Click:Connect(function() selectTab(tabObj) end)

		-- hover
		local hovBg = false
		btn.MouseEnter:Connect(function()
			hovBg = true
			if WIN.activeTab ~= tabObj then tw(btn, TI.fast, { BackgroundTransparency = 0.55 }) end
		end)
		btn.MouseLeave:Connect(function()
			hovBg = false
			if WIN.activeTab ~= tabObj then tw(btn, TI.fast, { BackgroundTransparency = 1 }) end
		end)

		table.insert(self.tabs, tabObj)
		if not WIN.activeTab then selectTab(tabObj) end

		local function nextOrder()
			tabObj._order = tabObj._order + 1
			return tabObj._order
		end

		-- ── AddSection ──
		function tabObj:AddSection(name)
			local f = Instance.new("Frame", page)
			f.Size = UDim2.new(1, 0, 0, 0)
			f.AutomaticSize = Enum.AutomaticSize.Y
			f.BackgroundTransparency = 1
			f.LayoutOrder = nextOrder()
			local lbl2 = label(f, string.upper(name), 9, T.Accent, nil, true)
			lbl2.Size = UDim2.new(1, 0, 0, 20)
			lbl2.AutomaticSize = Enum.AutomaticSize.None
			lbl2.TextYAlignment = Enum.TextYAlignment.Bottom
			local pad2 = Instance.new("UIPadding", lbl2)
			pad2.PaddingLeft = UDim.new(0, 2)
		end

		-- ── AddLabel ──
		function tabObj:AddLabel(text)
			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.BackgroundColor3 = T.Card
			card.BackgroundTransparency = 0.3
			card.LayoutOrder = nextOrder()
			corner(card, 8)
			pad(card, 10, 10, 6, 6)
			local lbl3 = label(card, tostring(text), 10, T.Sub)
			lbl3.TextWrapped = true
			local obj = {}
			function obj:Set(t) lbl3.Text = tostring(t) end
			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── AddToggle ──
		function tabObj:AddToggle(topts)
			topts = topts or {}
			local flagKey = topts.Flag and ("toggle_" .. tostring(topts.Flag))
			local defVal = topts.Default
			if saveEnabled and flagKey then
				defVal = cfg:loadBool(flagKey, defVal)
			end
			local value = defVal == true

			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 44)
			card.BackgroundColor3 = T.Card
			card.BackgroundTransparency = 0.22
			card.LayoutOrder = nextOrder()
			corner(card, 10)
			local cst = stroke(card, T.Stroke)
			pad(card, 12, 12, 0, 0)
			attachHover(card, cst)

			local nameLbl = label(card, tostring(topts.Name or "Toggle"), 11, T.Text, nil, false)
			nameLbl.Size = UDim2.new(1, -66, 1, 0)
			nameLbl.AutomaticSize = Enum.AutomaticSize.None
			nameLbl.TextYAlignment = Enum.TextYAlignment.Center

			local track = Instance.new("Frame", card)
			track.Size = UDim2.fromOffset(44, 22)
			track.AnchorPoint = Vector2.new(1, 0.5)
			track.Position = UDim2.new(1, -6, 0.5, 0)
			track.BackgroundColor3 = value and T.Accent or T.TogOff
			corner(track, 11)
			local trackScale = Instance.new("UIScale", track); trackScale.Scale = 1
			local knob = Instance.new("Frame", track)
			knob.Size = UDim2.fromOffset(16, 16)
			knob.Position = value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
			knob.BackgroundColor3 = Color3.new(1,1,1)
			corner(knob, 10)
			local knobScale = Instance.new("UIScale", knob); knobScale.Scale = 1

			local obj = {}
			function obj:Set(v, silent)
				value = v == true
				tw(track, TI.fast, { BackgroundColor3 = value and T.Accent or T.TogOff })
				tw(knob, TI.bounce, { Position = value and UDim2.fromOffset(25,3) or UDim2.fromOffset(3,3) })
				tw(knobScale, TI.bounce, { Scale = value and 1.12 or 1 })
				task.delay(0.18, function() tw(knobScale, TI.fast, { Scale = 1 }) end)
				if not silent and topts.Callback then pcall(topts.Callback, value) end
				if saveEnabled and flagKey then cfg:save(flagKey, tostring(value)) end
			end
			function obj:Get() return value end

			track.MouseEnter:Connect(function() tw(trackScale, TI.fast, { Scale = 1.08 }) end)
			track.MouseLeave:Connect(function() tw(trackScale, TI.fast, { Scale = 1 }) end)

			local hit = Instance.new("TextButton", card)
			hit.Size = UDim2.fromScale(1,1)
			hit.BackgroundTransparency = 1
			hit.Text = ""
			hit.ZIndex = 2
			hit.MouseButton1Click:Connect(function() obj:Set(not value) end)

			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── AddSlider ──
		function tabObj:AddSlider(sopts)
			sopts = sopts or {}
			local flagKey = sopts.Flag and ("slider_" .. tostring(sopts.Flag))
			local defVal = sopts.Default or sopts.Min or 0
			if saveEnabled and flagKey then defVal = cfg:loadNum(flagKey, defVal) end
			local minV, maxV = sopts.Min or 0, sopts.Max or 100
			local step = sopts.Step or 1
			local value = math.clamp(defVal, minV, maxV)

			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 56)
			card.BackgroundColor3 = T.Card
			card.BackgroundTransparency = 0.22
			card.LayoutOrder = nextOrder()
			corner(card, 10)
			local cst = stroke(card, T.Stroke)
			pad(card, 12, 12, 0, 0)
			attachHover(card, cst)

			local nameLbl = label(card, tostring(sopts.Name or "Slider"), 11, T.Text)
			nameLbl.Size = UDim2.new(1, -66, 0, 20)
			nameLbl.AutomaticSize = Enum.AutomaticSize.None
			nameLbl.Position = UDim2.fromOffset(0, 10)

			local valLbl = Instance.new("TextLabel", card)
			valLbl.Size = UDim2.fromOffset(60, 20)
			valLbl.AnchorPoint = Vector2.new(1, 0)
			valLbl.Position = UDim2.new(1, 0, 0, 10)
			valLbl.BackgroundTransparency = 1
			valLbl.TextColor3 = T.Accent
			valLbl.Font = Enum.Font.GothamBold
			valLbl.TextSize = 11
			valLbl.TextXAlignment = Enum.TextXAlignment.Right

			local trackBg = Instance.new("Frame", card)
			trackBg.Size = UDim2.new(1, -6, 0, 5)
			trackBg.Position = UDim2.fromOffset(0, 40)
			trackBg.BackgroundColor3 = T.TogOff
			corner(trackBg, 3)
			local fill = Instance.new("Frame", trackBg)
			fill.BackgroundColor3 = T.Accent
			fill.Size = UDim2.fromScale(0, 1)
			corner(fill, 3)
			local sknob = Instance.new("Frame", trackBg)
			sknob.Size = UDim2.fromOffset(13,13)
			sknob.AnchorPoint = Vector2.new(0.5,0.5)
			sknob.Position = UDim2.fromScale(0, 0.5)
			sknob.BackgroundColor3 = Color3.new(1,1,1)
			corner(sknob, 7)
			local sks = Instance.new("UIScale", sknob); sks.Scale = 1
			local draggingSlider = false

			local function updateVisual(v, animate)
				local pct = (v - minV) / math.max(maxV - minV, 1)
				local info = animate and TI.fast or TweenInfo.new(0)
				tw(fill, info, { Size = UDim2.fromScale(pct, 1) })
				tw(sknob, info, { Position = UDim2.fromScale(pct, 0.5) })
				valLbl.Text = tostring(v)
			end
			local function setValue(v)
				value = math.clamp(math.round(v / step) * step, minV, maxV)
				updateVisual(value, true)
				if sopts.Callback then pcall(sopts.Callback, value) end
				if saveEnabled and flagKey then cfg:save(flagKey, tostring(value)) end
			end
			local function fromMouse()
				local abs, sz = trackBg.AbsolutePosition, trackBg.AbsoluteSize
				local pct = math.clamp((mouse.X - abs.X) / math.max(sz.X,1), 0, 1)
				setValue(minV + (maxV - minV) * pct)
			end

			trackBg.MouseEnter:Connect(function() tw(sks, TI.fast, { Scale = 1.3 }) end)
			trackBg.MouseLeave:Connect(function() if not draggingSlider then tw(sks, TI.fast, { Scale = 1 }) end end)
			local sHit = Instance.new("TextButton", card)
			sHit.Size = UDim2.new(1, -6, 0, 22)
			sHit.Position = UDim2.fromOffset(0, 34)
			sHit.BackgroundTransparency = 1
			sHit.Text = ""
			sHit.MouseButton1Down:Connect(function()
				draggingSlider = true
				tw(sks, TI.fast, { Scale = 1.5 })
				fromMouse()
			end)
			UserInput.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 and draggingSlider then
					draggingSlider = false
					tw(sks, TI.bounce, { Scale = 1 })
				end
			end)
			UserInput.InputChanged:Connect(function(input)
				if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then fromMouse() end
			end)

			updateVisual(value, false)

			local obj = {}
			function obj:Set(v) setValue(v or defVal) end
			function obj:Get() return value end
			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── AddButton ──
		function tabObj:AddButton(bopts)
			bopts = bopts or {}
			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 44)
			card.BackgroundColor3 = T.Card
			card.BackgroundTransparency = 0.22
			card.LayoutOrder = nextOrder()
			corner(card, 10)
			local cst = stroke(card, T.Stroke)
			pad(card, 12, 12, 0, 0)
			attachHover(card, cst)

			local nameLbl = label(card, tostring(bopts.Name or "Button"), 11, T.Text)
			nameLbl.Size = UDim2.new(1, -120, 1, 0)
			nameLbl.AutomaticSize = Enum.AutomaticSize.None
			nameLbl.TextYAlignment = Enum.TextYAlignment.Center

			local isDanger = bopts.Style == "Danger"
			local isPrimary = bopts.Style == "Primary"
			local btnCol = isDanger and T.Danger or (isPrimary and T.Accent or T.Sidebar)
			local txtCol = (isDanger or isPrimary) and Color3.new(0.07,0.07,0.07) or T.Text

			local btn = Instance.new("TextButton", card)
			btn.Size = UDim2.fromOffset(94, 28)
			btn.AnchorPoint = Vector2.new(1, 0.5)
			btn.Position = UDim2.new(1, -6, 0.5, 0)
			btn.BackgroundColor3 = btnCol
			btn.Text = isPrimary and (bopts.Name or "") or "Run"
			btn.TextColor3 = isPrimary and T.Bg or T.Text
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 11
			btn.AutoButtonColor = false
			btn.ClipsDescendants = true
			corner(btn, 8)
			local bst = stroke(btn, isDanger and T.Danger or T.Accent, 1)
			attachScale(btn, 1.07, 0.92)

			-- ripple
			btn.MouseButton1Click:Connect(function(x, y)
				local r = Instance.new("Frame", btn)
				r.Size = UDim2.fromOffset(80,80)
				r.Position = UDim2.fromOffset((btn.AbsoluteSize.X/2)-40, (btn.AbsoluteSize.Y/2)-40)
				r.BackgroundColor3 = Color3.new(1,1,1)
				r.BackgroundTransparency = 0.65
				r.ZIndex = 10
				corner(r, 40)
				tw(r, TweenInfo.new(0.4), { Size = UDim2.fromOffset(200,200), Position = UDim2.fromOffset(-60,-60), BackgroundTransparency = 1 })
				task.delay(0.42, function() if r then r:Destroy() end end)
				if bopts.Callback then pcall(bopts.Callback) end
			end)
		end

		-- ── AddDropdown ──
		function tabObj:AddDropdown(dopts)
			dopts = dopts or {}
			local flagKey = dopts.Flag and ("dd_" .. tostring(dopts.Flag))
			local options = dopts.Options or {}
			local defVal = dopts.Default or (options[1] and tostring(options[1]))
			if saveEnabled and flagKey then defVal = cfg:load(flagKey, defVal) end
			local selected = defVal

			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 44)
			card.BackgroundColor3 = T.Card
			card.BackgroundTransparency = 0.22
			card.LayoutOrder = nextOrder()
			corner(card, 10)
			local cst = stroke(card, T.Stroke)
			attachHover(card, cst)
			pad(card, 12, 12, 0, 0)

			local nameLbl = label(card, tostring(dopts.Name or "Dropdown"), 11, T.Text)
			nameLbl.Size = UDim2.new(1, -120, 1, 0)
			nameLbl.AutomaticSize = Enum.AutomaticSize.None
			nameLbl.TextYAlignment = Enum.TextYAlignment.Center

			local selBtn = Instance.new("TextButton", card)
			selBtn.Size = UDim2.fromOffset(104, 28)
			selBtn.AnchorPoint = Vector2.new(1, 0.5)
			selBtn.Position = UDim2.new(1, -6, 0.5, 0)
			selBtn.BackgroundColor3 = T.Sidebar
			selBtn.Text = tostring(selected or "Select…")
			selBtn.TextColor3 = T.Accent
			selBtn.Font = Enum.Font.GothamBold
			selBtn.TextSize = 10
			selBtn.AutoButtonColor = false
			corner(selBtn, 8)
			stroke(selBtn, T.Accent, 1)
			attachScale(selBtn, 1.05, 0.93)

			-- dropdown popup
			local popup, open = nil, false
			selBtn.MouseButton1Click:Connect(function()
				if open and popup then
					popup:Destroy()
					popup, open = nil, false
					return
				end
				open = true
				popup = Instance.new("Frame", gui)
				popup.BackgroundColor3 = T.Sidebar
				popup.Size = UDim2.fromOffset(140, math.min(#options, 8) * 28 + 8)
				popup.ZIndex = 100
				corner(popup, 10)
				stroke(popup, T.Stroke)
				local abs = selBtn.AbsolutePosition
				popup.Position = UDim2.fromOffset(abs.X, abs.Y + selBtn.AbsoluteSize.Y + 4)
				local plist = list(popup, 2)
				local ppad = Instance.new("UIPadding", popup)
				ppad.PaddingTop, ppad.PaddingBottom = UDim.new(0,4), UDim.new(0,4)
				ppad.PaddingLeft, ppad.PaddingRight = UDim.new(0,6), UDim.new(0,6)
				for _, opt in ipairs(options) do
					local ob = Instance.new("TextButton", popup)
					ob.Size = UDim2.new(1, 0, 0, 26)
					ob.BackgroundTransparency = 1
					ob.Text = tostring(opt)
					ob.TextColor3 = tostring(opt) == tostring(selected) and T.Accent or T.Text
					ob.Font = Enum.Font.GothamMedium
					ob.TextSize = 11
					ob.AutoButtonColor = false
					ob.TextXAlignment = Enum.TextXAlignment.Left
					local op = Instance.new("UIPadding", ob); op.PaddingLeft = UDim.new(0,6)
					ob.MouseEnter:Connect(function() tw(ob, TI.fast, { BackgroundTransparency = 0.65, BackgroundColor3 = T.Card }) end)
					ob.MouseLeave:Connect(function() tw(ob, TI.fast, { BackgroundTransparency = 1 }) end)
					ob.MouseButton1Click:Connect(function()
						selected = tostring(opt)
						selBtn.Text = selected
						popup:Destroy(); popup, open = nil, false
						if saveEnabled and flagKey then cfg:save(flagKey, selected) end
						if dopts.Callback then pcall(dopts.Callback, selected) end
					end)
				end
				-- close on click outside
				task.spawn(function()
					task.wait(0.05)
					local conn
					conn = UserInput.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							if popup and not popup:IsAncestorOf(UserInput:GetFocusedTextBox() or Instance.new("TextBox")) then
								task.defer(function()
									if popup then popup:Destroy() end
									popup, open = nil, false
									conn:Disconnect()
								end)
							end
						end
					end)
				end)
			end)

			local obj = {}
			function obj:Set(v, silent)
				selected = tostring(v)
				selBtn.Text = selected
				if not silent and dopts.Callback then pcall(dopts.Callback, selected) end
			end
			function obj:Get() return selected end
			function obj:SetOptions(newOpts)
				options = newOpts
			end
			table.insert(tabObj.elements, obj)
			return obj
		end

		-- ── AddStats ──
		function tabObj:AddStats(sopts)
			sopts = sopts or {}
			local cols = sopts.Columns or 3
			local items = sopts.Items or {}

			local card = Instance.new("Frame", page)
			card.Size = UDim2.new(1, 0, 0, 56)
			card.BackgroundColor3 = T.Card
			card.BackgroundTransparency = 0.22
			card.LayoutOrder = nextOrder()
			corner(card, 10)
			stroke(card, T.Stroke)
			local grid = Instance.new("UIGridLayout", card)
			grid.CellSize = UDim2.new(1/cols, -6, 1, -6)
			grid.CellPadding = UDim2.fromOffset(4, 4)
			local gpad = Instance.new("UIPadding", card)
			gpad.PaddingLeft, gpad.PaddingRight = UDim.new(0,8), UDim.new(0,8)
			gpad.PaddingTop, gpad.PaddingBottom = UDim.new(0,6), UDim.new(0,6)

			local cellMap = {}
			for _, item in ipairs(items) do
				local cell = Instance.new("Frame", card)
				cell.BackgroundTransparency = 1
				local vl = label(cell, tostring(item.Value or "0"), 16, T.Accent, Enum.TextXAlignment.Center, true)
				vl.Size = UDim2.new(1,0,0,22)
				vl.AutomaticSize = Enum.AutomaticSize.None
				vl.TextYAlignment = Enum.TextYAlignment.Center
				local ll2 = label(cell, tostring(item.Label or ""), 9, T.Sub, Enum.TextXAlignment.Center)
				ll2.Position = UDim2.fromOffset(0,22)
				ll2.Size = UDim2.new(1,0,0,14)
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

		-- ── Clear (rebuild page) ──
		function tabObj:Clear()
			for _, c in ipairs(page:GetChildren()) do
				if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
			end
			tabObj._order = 0
			tabObj.elements = {}
		end

		return tabObj
	end

	function WIN:Notify(opts)
		showNotify(gui, opts or {})
	end

	function WIN:SetSize(w, h)
		mainF.Size = UDim2.fromOffset(math.max(minW, w), math.max(minH, h))
	end

	return WIN
end

-- ============================================================
-- SPLASH
-- ============================================================
local function createSplash(velt, opts)
	opts = opts or {}
	local gui2 = Instance.new("ScreenGui")
	gui2.Name = "VeltSplash"
	gui2.ResetOnSpawn = false
	gui2.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui2.IgnoreGuiInset = true
	gui2.Parent = (gethui and gethui()) or PlayerGui

	local bg = Instance.new("CanvasGroup", gui2)
	bg.Size = UDim2.fromScale(1,1)
	bg.BackgroundColor3 = T.Bg
	bg.GroupTransparency = 0

	local ring = Instance.new("Frame", bg)
	ring.Size = UDim2.fromOffset(80, 80)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0.5, 0, 0.5, -60)
	ring.BackgroundColor3 = T.Sidebar
	corner(ring, 24)
	stroke(ring, T.Accent, 2)

	local titleL = Instance.new("TextLabel", bg)
	titleL.Text = "VELT"
	titleL.Font = Enum.Font.GothamBold
	titleL.TextSize = 24
	titleL.TextColor3 = T.Accent
	titleL.BackgroundTransparency = 1
	titleL.Size = UDim2.new(1, 0, 0, 30)
	titleL.Position = UDim2.new(0, 0, 0.5, 0)
	titleL.TextXAlignment = Enum.TextXAlignment.Center

	local subL = Instance.new("TextLabel", bg)
	subL.Text = tostring(opts.Subtitle or "")
	subL.Font = Enum.Font.Gotham
	subL.TextSize = 12
	subL.TextColor3 = T.Sub
	subL.BackgroundTransparency = 1
	subL.Size = UDim2.new(1, 0, 0, 18)
	subL.Position = UDim2.new(0, 0, 0.5, 32)
	subL.TextXAlignment = Enum.TextXAlignment.Center

	local statL = Instance.new("TextLabel", bg)
	statL.Text = "Initializing"
	statL.Font = Enum.Font.Gotham
	statL.TextSize = 10
	statL.TextColor3 = T.Sub
	statL.BackgroundTransparency = 1
	statL.Size = UDim2.new(1, 0, 0, 14)
	statL.Position = UDim2.new(0, 0, 0.5, 90)
	statL.TextXAlignment = Enum.TextXAlignment.Center

	local trackBg2 = Instance.new("Frame", bg)
	trackBg2.Size = UDim2.fromOffset(220, 4)
	trackBg2.AnchorPoint = Vector2.new(0.5, 0.5)
	trackBg2.Position = UDim2.new(0.5, 0, 0.5, 72)
	trackBg2.BackgroundColor3 = T.TogOff
	corner(trackBg2, 2)
	local progFill = Instance.new("Frame", trackBg2)
	progFill.Size = UDim2.fromScale(0, 1)
	progFill.BackgroundColor3 = T.Accent
	corner(progFill, 2)

	local splash = {}
	function splash:Preload() end
	function splash:Progress(p, text)
		tw(progFill, TI.fast, { Size = UDim2.fromScale(math.clamp(p, 0, 1), 1) })
		if text then statL.Text = tostring(text) end
	end
	function splash:Finish()
		tw(bg, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
		task.delay(0.45, function() gui2:Destroy() end)
	end
	return splash
end

-- ============================================================
-- VELT OBJECT
-- ============================================================
local Velt = {}
Velt.__index = Velt

function Velt:CreateWindow(opts)
	return createWindow(self, opts)
end

function Velt:Splash(opts)
	return createSplash(self, opts)
end

return setmetatable({}, Velt)
