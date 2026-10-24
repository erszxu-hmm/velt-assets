--[[
    Velt UI Library
    Tema: tenang, elegan, bersih
    Palet diambil dari logo: slate gelap + hijau sage pucat

    Elemen: Window, Tab, Section, Label, Button, Toggle, Slider, Dropdown, Notify
    Tombol buka/tutup default: RightShift
]]

local Velt = {}
Velt.__index = Velt

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- Tema
local Theme = {
    Background = Color3.fromRGB(15, 22, 24),
    Sidebar    = Color3.fromRGB(19, 28, 31),
    Element    = Color3.fromRGB(25, 36, 40),
    ElementHi  = Color3.fromRGB(32, 46, 51),
    Stroke     = Color3.fromRGB(44, 62, 66),
    Accent     = Color3.fromRGB(183, 211, 192),
    AccentDim  = Color3.fromRGB(96, 124, 108),
    Text       = Color3.fromRGB(230, 238, 234),
    Muted      = Color3.fromRGB(127, 149, 144),
    Font       = Enum.Font.Gotham,
    FontMedium = Enum.Font.GothamMedium,
    FontBold   = Enum.Font.GothamBold,
}

local EASE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_SLOW = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Helper
local function Create(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = obj
    end
    return obj
end

local function Tween(obj, props, info)
    local t = TweenService:Create(obj, info or EASE, props)
    t:Play()
    return t
end

local function Corner(radius)
    return Create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function Stroke(color, thickness, transparency)
    return Create("UIStroke", {
        Color = color or Theme.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function Padding(l, t, r, b)
    return Create("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
    })
end

local function GetGuiParent()
    if gethui then
        local ok, ui = pcall(gethui)
        if ok and ui then return ui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function ResolveImage(source)
    if not source or source == "" then return nil end
    if type(source) == "number" then return "rbxassetid://" .. source end
    if source:find("rbxassetid://") or source:find("rbxthumb://") then return source end
    -- file lokal di folder workspace executor
    if isfile and getcustomasset and isfile(source) then
        local ok, asset = pcall(getcustomasset, source)
        if ok then return asset end
    end
    return nil
end

-- Window
function Velt:CreateWindow(config)
    config = config or {}
    local name = config.Name or "Velt"
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift
    local size = config.Size or UDim2.fromOffset(580, 380)

    -- bersihkan instance lama
    local parent = GetGuiParent()
    local old = parent:FindFirstChild("VeltUI")
    if old then old:Destroy() end

    local Window = { Tabs = {}, ActiveTab = nil, Connections = {} }

    local gui = Create("ScreenGui", {
        Name = "VeltUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    })
    gui.Parent = parent
    Window.Gui = gui

    local main = Create("Frame", {
        Name = "Main",
        Size = size,
        Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    }, { Corner(14), Stroke(Theme.Stroke, 1) })
    Window.Main = main

    -- Sidebar
    local sidebar = Create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 156, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        Parent = main,
    })
    Create("Frame", { -- garis pemisah
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.Stroke,
        BorderSizePixel = 0,
        Parent = sidebar,
    })

    -- Brand (logo + nama)
    local brand = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundTransparency = 1,
        Parent = sidebar,
    })

    local logoBox = Create("Frame", {
        Size = UDim2.fromOffset(36, 36),
        Position = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = brand,
    }, { Corner(10), Stroke(Theme.AccentDim, 1) })

    local logoImage = ResolveImage(config.Logo)
    if logoImage then
        Create("ImageLabel", {
            Size = UDim2.new(1, -8, 1, -8),
            Position = UDim2.fromOffset(4, 4),
            BackgroundTransparency = 1,
            Image = logoImage,
            ImageColor3 = Theme.Accent,
            ScaleType = Enum.ScaleType.Fit,
            Parent = logoBox,
        })
    else
        Create("TextLabel", { -- fallback jika logo belum di-set
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "V",
            Font = Theme.FontBold,
            TextSize = 20,
            TextColor3 = Theme.Accent,
            Parent = logoBox,
        })
    end

    Create("TextLabel", {
        Size = UDim2.new(1, -64, 0, 36),
        Position = UDim2.fromOffset(60, 16),
        BackgroundTransparency = 1,
        Text = name,
        Font = Theme.FontBold,
        TextSize = 17,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = brand,
    })

    local tabList = Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -76),
        Position = UDim2.fromOffset(0, 68),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = sidebar,
    }, {
        Padding(10, 0, 10, 0),
        Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
    })

    -- Area konten
    local content = Create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -156, 1, 0),
        Position = UDim2.fromOffset(156, 0),
        BackgroundTransparency = 1,
        Parent = main,
    })

    local header = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        Parent = content,
    })
    local pageTitle = Create("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.fromOffset(22, 0),
        BackgroundTransparency = 1,
        Text = "",
        Font = Theme.FontMedium,
        TextSize = 16,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    local closeBtn = Create("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -40, 0, 14),
        BackgroundColor3 = Theme.Element,
        BackgroundTransparency = 1,
        Text = "×",
        Font = Theme.FontMedium,
        TextSize = 20,
        TextColor3 = Theme.Muted,
        AutoButtonColor = false,
        Parent = header,
    }, { Corner(8) })
    closeBtn.MouseEnter:Connect(function()
        Tween(closeBtn, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
    end)
    closeBtn.MouseLeave:Connect(function()
        Tween(closeBtn, { BackgroundTransparency = 1, TextColor3 = Theme.Muted })
    end)

    local pages = Create("Frame", {
        Size = UDim2.new(1, 0, 1, -56),
        Position = UDim2.fromOffset(0, 56),
        BackgroundTransparency = 1,
        Parent = content,
    })

    -- Drag
    do
        local dragging, dragStart, startPos
        local function begin(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end
        brand.InputBegan:Connect(begin)
        header.InputBegan:Connect(begin)
        table.insert(Window.Connections, UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            end
        end))
    end

    -- Buka / tutup
    local visible = true
    local function setVisible(state)
        visible = state
        main.Visible = true
        if state then
            Tween(main, { Size = size }, EASE_SLOW)
        else
            Tween(main, { Size = UDim2.fromOffset(size.X.Offset, 0) }, EASE_SLOW)
            task.delay(0.3, function()
                if not visible then main.Visible = false end
            end)
        end
    end
    function Window:Toggle() setVisible(not visible) end
    closeBtn.MouseButton1Click:Connect(function() setVisible(false) end)
    table.insert(Window.Connections, UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == toggleKey then setVisible(not visible) end
    end))

    -- Notifikasi
    local notifHolder = Create("Frame", {
        Size = UDim2.new(0, 280, 1, -24),
        Position = UDim2.new(1, -296, 0, 12),
        BackgroundTransparency = 1,
        Parent = gui,
    }, {
        Create("UIListLayout", {
            Padding = UDim.new(0, 8),
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    function Window:Notify(opts)
        opts = opts or {}
        local duration = opts.Duration or 4
        local card = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Sidebar,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = notifHolder,
        }, {
            Corner(10), Stroke(Theme.Stroke, 1), Padding(14, 11, 14, 12),
            Create("UIListLayout", { Padding = UDim.new(0, 3) }),
        })
        local title = Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = opts.Title or name,
            Font = Theme.FontMedium,
            TextSize = 13,
            TextColor3 = Theme.Accent,
            TextTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })
        local body = Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = opts.Content or "",
            Font = Theme.Font,
            TextSize = 12,
            TextWrapped = true,
            TextColor3 = Theme.Text,
            TextTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })
        Tween(card, { BackgroundTransparency = 0 })
        Tween(title, { TextTransparency = 0 })
        Tween(body, { TextTransparency = 0.15 })
        task.delay(duration, function()
            if not card.Parent then return end
            Tween(card, { BackgroundTransparency = 1 })
            Tween(title, { TextTransparency = 1 })
            Tween(body, { TextTransparency = 1 })
            task.wait(0.25)
            card:Destroy()
        end)
    end

    function Window:Destroy()
        for _, c in ipairs(Window.Connections) do c:Disconnect() end
        gui:Destroy()
    end

    -- Tab
    function Window:AddTab(tabName)
        local Tab = {}

        local button = Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = Theme.Element,
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = #Window.Tabs + 1,
            Parent = tabList,
        }, { Corner(8) })

        local indicator = Create("Frame", {
            Size = UDim2.fromOffset(3, 0),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Parent = button,
        }, { Corner(2) })

        local label = Create("TextLabel", {
            Size = UDim2.new(1, -24, 1, 0),
            Position = UDim2.fromOffset(14, 0),
            BackgroundTransparency = 1,
            Text = tabName,
            Font = Theme.FontMedium,
            TextSize = 13,
            TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = button,
        })

        local page = Create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.AccentDim,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = pages,
        }, {
            Padding(20, 2, 20, 16),
            Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
        })

        local order = 0
        local function nextOrder() order += 1 return order end

        local function setActive(active)
            Tween(button, { BackgroundTransparency = active and 0 or 1 })
            Tween(label, { TextColor3 = active and Theme.Text or Theme.Muted })
            Tween(indicator, { Size = UDim2.fromOffset(3, active and 16 or 0) })
        end

        function Tab:Select()
            for _, t in ipairs(Window.Tabs) do
                t.Page.Visible = false
                t.SetActive(false)
            end
            page.Visible = true
            setActive(true)
            pageTitle.Text = tabName
            Window.ActiveTab = Tab
        end

        button.MouseButton1Click:Connect(function() Tab:Select() end)
        button.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(label, { TextColor3 = Theme.Text }) end
        end)
        button.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(label, { TextColor3 = Theme.Muted }) end
        end)

        Tab.Page = page
        Tab.SetActive = setActive
        table.insert(Window.Tabs, Tab)
        if #Window.Tabs == 1 then Tab:Select() end

        -- Basis elemen
        local function BaseElement(height)
            return Create("Frame", {
                Size = UDim2.new(1, 0, 0, height or 40),
                BackgroundColor3 = Theme.Element,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(),
                Parent = page,
            }, { Corner(10), Stroke(Theme.Stroke, 1, 0.4) })
        end

        local function ElementLabel(parentFrame, text)
            return Create("TextLabel", {
                Size = UDim2.new(1, -90, 0, 40),
                Position = UDim2.fromOffset(14, 0),
                BackgroundTransparency = 1,
                Text = text,
                Font = Theme.FontMedium,
                TextSize = 13,
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = parentFrame,
            })
        end

        function Tab:AddSection(text)
            Create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundTransparency = 1,
                Text = text,
                Font = Theme.FontMedium,
                TextSize = 12,
                TextColor3 = Theme.AccentDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = nextOrder(),
                Parent = page,
            }, { Padding(2, 8, 0, 0) })
        end

        function Tab:AddLabel(text)
            local lbl = Create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text = text,
                Font = Theme.Font,
                TextSize = 12,
                TextWrapped = true,
                TextColor3 = Theme.Muted,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = nextOrder(),
                Parent = page,
            }, { Padding(2, 2, 2, 2) })
            return { Set = function(_, t) lbl.Text = t end }
        end

        function Tab:AddButton(opts)
            local frame = BaseElement(40)
            ElementLabel(frame, opts.Name or "Button")
            local hit = Create("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                Parent = frame,
            })
            Create("TextLabel", {
                Size = UDim2.fromOffset(30, 40),
                Position = UDim2.new(1, -34, 0, 0),
                BackgroundTransparency = 1,
                Text = "›",
                Font = Theme.FontMedium,
                TextSize = 20,
                TextColor3 = Theme.AccentDim,
                Parent = frame,
            })
            hit.MouseEnter:Connect(function() Tween(frame, { BackgroundColor3 = Theme.ElementHi }) end)
            hit.MouseLeave:Connect(function() Tween(frame, { BackgroundColor3 = Theme.Element }) end)
            hit.MouseButton1Click:Connect(function()
                Tween(frame, { BackgroundColor3 = Theme.Stroke }, TweenInfo.new(0.08))
                task.delay(0.08, function() Tween(frame, { BackgroundColor3 = Theme.ElementHi }) end)
                if opts.Callback then task.spawn(opts.Callback) end
            end)
        end

        function Tab:AddToggle(opts)
            local state = opts.Default or false
            local frame = BaseElement(40)
            ElementLabel(frame, opts.Name or "Toggle")

            local track = Create("Frame", {
                Size = UDim2.fromOffset(36, 20),
                Position = UDim2.new(1, -50, 0.5, -10),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            }, { Corner(10), Stroke(Theme.Stroke, 1) })
            local knob = Create("Frame", {
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.fromOffset(3, 3),
                BackgroundColor3 = Theme.Muted,
                BorderSizePixel = 0,
                Parent = track,
            }, { Corner(7) })

            local function render(animate)
                local info = animate and EASE or TweenInfo.new(0)
                Tween(knob, {
                    Position = UDim2.fromOffset(state and 19 or 3, 3),
                    BackgroundColor3 = state and Theme.Accent or Theme.Muted,
                }, info)
                Tween(track, { BackgroundColor3 = state and Theme.AccentDim or Theme.Background }, info)
            end
            render(false)

            local function set(v, silent)
                state = v
                render(true)
                if not silent and opts.Callback then task.spawn(opts.Callback, state) end
            end

            Create("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                Parent = frame,
            }).MouseButton1Click:Connect(function() set(not state) end)

            if state and opts.Callback then task.spawn(opts.Callback, state) end
            return { Set = function(_, v) set(v) end, Get = function() return state end }
        end

        function Tab:AddSlider(opts)
            local min, max = opts.Min or 0, opts.Max or 100
            local step = opts.Step or 1
            local value = math.clamp(opts.Default or min, min, max)

            local frame = BaseElement(54)
            Create("TextLabel", {
                Size = UDim2.new(1, -90, 0, 30),
                Position = UDim2.fromOffset(14, 2),
                BackgroundTransparency = 1,
                Text = opts.Name or "Slider",
                Font = Theme.FontMedium,
                TextSize = 13,
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
            })
            local valueLabel = Create("TextLabel", {
                Size = UDim2.fromOffset(70, 30),
                Position = UDim2.new(1, -84, 0, 2),
                BackgroundTransparency = 1,
                Text = tostring(value),
                Font = Theme.FontMedium,
                TextSize = 13,
                TextColor3 = Theme.Accent,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = frame,
            })
            local track = Create("Frame", {
                Size = UDim2.new(1, -28, 0, 4),
                Position = UDim2.fromOffset(14, 38),
                BackgroundColor3 = Theme.Background,
                BorderSizePixel = 0,
                Parent = frame,
            }, { Corner(2) })
            local fill = Create("Frame", {
                Size = UDim2.fromScale((value - min) / (max - min), 1),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = track,
            }, { Corner(2) })
            local thumb = Create("Frame", {
                Size = UDim2.fromOffset(12, 12),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                BackgroundColor3 = Theme.Text,
                BorderSizePixel = 0,
                Parent = fill,
            }, { Corner(6) })

            local function setValue(v, silent)
                v = math.clamp(math.round(v / step) * step, min, max)
                value = v
                valueLabel.Text = tostring(v)
                Tween(fill, { Size = UDim2.fromScale((v - min) / (max - min), 1) }, TweenInfo.new(0.06))
                if not silent and opts.Callback then task.spawn(opts.Callback, v) end
            end

            local dragging = false
            local function fromInput(input)
                local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                setValue(min + (max - min) * rel)
            end
            local hit = Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                Position = UDim2.fromOffset(0, 28),
                BackgroundTransparency = 1,
                Text = "",
                Parent = frame,
            })
            hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    Tween(thumb, { Size = UDim2.fromOffset(15, 15) })
                    fromInput(input)
                end
            end)
            table.insert(Window.Connections, UserInputService.InputEnded:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    dragging = false
                    Tween(thumb, { Size = UDim2.fromOffset(12, 12) })
                end
            end))
            table.insert(Window.Connections, UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    fromInput(input)
                end
            end))

            return { Set = function(_, v) setValue(v) end, Get = function() return value end }
        end

        function Tab:AddDropdown(opts)
            local items = opts.Options or {}
            local selected = opts.Default or items[1]
            local open = false

            local frame = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Element,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                LayoutOrder = nextOrder(),
                Parent = page,
            }, {
                Corner(10), Stroke(Theme.Stroke, 1, 0.4),
                Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
            })

            local head = Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundTransparency = 1,
                Text = "",
                LayoutOrder = 1,
                Parent = frame,
            })
            Create("TextLabel", {
                Size = UDim2.new(0.5, 0, 1, 0),
                Position = UDim2.fromOffset(14, 0),
                BackgroundTransparency = 1,
                Text = opts.Name or "Dropdown",
                Font = Theme.FontMedium,
                TextSize = 13,
                TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = head,
            })
            local current = Create("TextLabel", {
                Size = UDim2.new(0.5, -36, 1, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(selected or "-"),
                Font = Theme.Font,
                TextSize = 12,
                TextColor3 = Theme.Accent,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = head,
            })
            local arrow = Create("TextLabel", {
                Size = UDim2.fromOffset(24, 40),
                Position = UDim2.new(1, -30, 0, 0),
                BackgroundTransparency = 1,
                Text = "⌄",
                Font = Theme.FontMedium,
                TextSize = 16,
                TextColor3 = Theme.AccentDim,
                Parent = head,
            })

            local list = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Visible = false,
                LayoutOrder = 2,
                Parent = frame,
            }, {
                Padding(8, 0, 8, 8),
                Create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
            })

            local optionButtons = {}
            local function refresh()
                for value, b in pairs(optionButtons) do
                    local on = value == selected
                    Tween(b, {
                        BackgroundTransparency = on and 0 or 1,
                        TextColor3 = on and Theme.Accent or Theme.Muted,
                    })
                end
                current.Text = tostring(selected or "-")
            end

            local function choose(v, silent)
                selected = v
                refresh()
                if not silent and opts.Callback then task.spawn(opts.Callback, v) end
            end

            for i, item in ipairs(items) do
                local b = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundColor3 = Theme.ElementHi,
                    BackgroundTransparency = 1,
                    Text = tostring(item),
                    Font = Theme.Font,
                    TextSize = 12,
                    TextColor3 = Theme.Muted,
                    AutoButtonColor = false,
                    LayoutOrder = i,
                    Parent = list,
                }, { Corner(7) })
                optionButtons[item] = b
                b.MouseButton1Click:Connect(function() choose(item) end)
            end
            refresh()

            head.MouseButton1Click:Connect(function()
                open = not open
                list.Visible = open
                Tween(arrow, { Rotation = open and 180 or 0 })
            end)

            return { Set = function(_, v) choose(v) end, Get = function() return selected end }
        end

        return Tab
    end

    return Window
end

return Velt
