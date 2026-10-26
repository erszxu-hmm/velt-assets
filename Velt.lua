--[[
    ██╗   ██╗███████╗██╗  ████████╗
    ██║   ██║██╔════╝██║  ╚══██╔══╝
    ██║   ██║█████╗  ██║     ██║
    ╚██╗ ██╔╝██╔══╝  ██║     ██║
     ╚████╔╝ ███████╗███████╗██║
      ╚═══╝  ╚══════╝╚══════╝╚═╝

    Velt UI Library v1.0.0
    Modern · Minimal · Warm

    Usage:
        local Velt = loadstring(game:HttpGet("url"))()
        local Window = Velt:CreateWindow({
            Title = "My Script",
            Theme = "Obsidian",
            MinimizeKey = Enum.KeyCode.RightShift,
            SaveConfig = true,
            ConfigFolder = "VeltConfig"
        })
        local Tab = Window:AddTab({ Title = "Main", Icon = "home" })
        local Section = Tab:AddSection({ Title = "Combat" })
        Section:AddToggle({ Title = "Enabled", Default = false, Flag = "AimbotOn", Callback = function(v) end })
]]

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UserInput      = game:GetService("UserInputService")
local RunService     = game:GetService("RunService")
local HttpService    = game:GetService("HttpService")
local CoreGui        = game:GetService("CoreGui")
local TextService    = game:GetService("TextService")

local LocalPlayer    = Players.LocalPlayer
local Mouse          = LocalPlayer and LocalPlayer:GetMouse()
local Camera         = workspace.CurrentCamera

----------------------------------------------------------------
-- Environment / Exploit Compatibility
----------------------------------------------------------------
local Env = {}
Env.isExploit   = pcall(function() return getgenv end) and getgenv ~= nil
Env.getHui      = (typeof(gethui) == "function" and gethui) or function() return CoreGui end
Env.cloneRef    = (typeof(cloneref) == "function" and cloneref) or function(o) return o end
Env.isFile      = (typeof(isfile) == "function" and isfile) or function() return false end
Env.readFile    = (typeof(readfile) == "function" and readfile) or function() return "" end
Env.writeFile   = (typeof(writefile) == "function" and writefile) or function() end
Env.makeFolder  = (typeof(makefolder) == "function" and makefolder) or function() end
Env.isFolder    = (typeof(isfolder) == "function" and isfolder) or function() return false end
Env.delFile     = (typeof(delfile) == "function" and delfile) or function() end

local function protectGui(gui)
    if typeof(syn) == "table" and syn.protect_gui then
        syn.protect_gui(gui)
        gui.Parent = CoreGui
    elseif Env.isExploit then
        gui.Parent = Env.getHui()
    else
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

----------------------------------------------------------------
-- Signal
----------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ _cbs = {}, _once = {} }, Signal)
end

function Signal:Connect(fn)
    local id = tostring({}) -- unique key
    self._cbs[id] = fn
    return {
        Disconnect = function()
            self._cbs[id] = nil
        end
    }
end

function Signal:Once(fn)
    local id = tostring({})
    self._once[id] = fn
end

function Signal:Fire(...)
    for _, fn in pairs(self._cbs) do
        task.spawn(fn, ...)
    end
    for id, fn in pairs(self._once) do
        task.spawn(fn, ...)
        self._once[id] = nil
    end
end

function Signal:Destroy()
    table.clear(self._cbs)
    table.clear(self._once)
end

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------
local Util = {}

function Util.create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

function Util.tween(inst, props, duration, style, dir)
    local info = TweenInfo.new(
        duration or 0.25,
        style or Enum.EasingStyle.Quart,
        dir or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(inst, info, props)
    tw:Play()
    return tw
end

function Util.tweenSequence(inst, propName, seq, duration)
    -- For color sequences on UIGradient, we tween the offset instead
    if typeof(seq) == "ColorSequence" then
        inst[propName] = seq
    end
end

function Util.lerp(a, b, t)
    return a + (b - a) * t
end

function Util.deepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = type(v) == "table" and Util.deepCopy(v) or v
    end
    return copy
end

function Util.round(n, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(n * mult + 0.5) / mult
end

function Util.clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

function Util.uuid()
    local t = "xxxxxxxx"
    return t:gsub("x", function()
        return string.format("%x", math.random(0, 15))
    end)
end

function Util.colorToHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255),
        math.floor(c.G * 255),
        math.floor(c.B * 255))
end

function Util.hexToColor(hex)
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return Color3.fromRGB(255, 255, 255) end
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return Color3.fromRGB(r, g, b)
end

function Util.hsvToRgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    else r, g, b = v, p, q end
    return Color3.new(r, g, b)
end

function Util.rgbToHsv(c)
    local r, g, b = c.R, c.G, c.B
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local h, s, v = 0, 0, mx
    local d = mx - mn
    s = mx == 0 and 0 or d / mx
    if mx ~= mn then
        if mx == r then h = (g - b) / d + (g < b and 6 or 0)
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, s, v
end

function Util.getTextBounds(text, font, size)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, size, font, Vector2.new(9999, 9999))
    end)
    return ok and bounds or Vector2.new(#text * size * 0.5, size)
end

----------------------------------------------------------------
-- Connection Tracker
----------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Add(task)
    self._tasks[#self._tasks + 1] = task
    return task
end

function Maid:Cleanup()
    for _, t in ipairs(self._tasks) do
        if typeof(t) == "RBXScriptConnection" then
            t:Disconnect()
        elseif typeof(t) == "Instance" then
            t:Destroy()
        elseif type(t) == "function" then
            t()
        elseif type(t) == "table" and t.Disconnect then
            t:Disconnect()
        elseif type(t) == "table" and t.Destroy then
            t:Destroy()
        end
    end
    table.clear(self._tasks)
end

----------------------------------------------------------------
-- Theme Engine
----------------------------------------------------------------
local Themes = {
    Obsidian = {
        Background      = Color3.fromRGB(10, 10, 14),
        Sidebar         = Color3.fromRGB(14, 14, 18),
        TitleBar        = Color3.fromRGB(14, 14, 18),
        Card            = Color3.fromRGB(20, 20, 26),
        CardBorder      = Color3.fromRGB(38, 38, 46),
        Surface         = Color3.fromRGB(26, 26, 32),
        SurfaceHover    = Color3.fromRGB(34, 34, 42),
        Text            = Color3.fromRGB(235, 230, 222),
        TextDim         = Color3.fromRGB(130, 126, 118),
        TextDark        = Color3.fromRGB(80, 78, 72),
        Accent          = Color3.fromRGB(210, 130, 80),
        AccentHover     = Color3.fromRGB(230, 150, 100),
        AccentDark      = Color3.fromRGB(170, 100, 60),
        ToggleOff       = Color3.fromRGB(44, 44, 52),
        SliderTrack     = Color3.fromRGB(36, 36, 44),
        Success         = Color3.fromRGB(80, 200, 120),
        Warning         = Color3.fromRGB(240, 180, 60),
        Error           = Color3.fromRGB(230, 80, 80),
        Info            = Color3.fromRGB(80, 160, 240),
        Shadow          = Color3.fromRGB(0, 0, 0),
        AccentGradient  = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 110, 60)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 130))
        }),
        CornerRadius    = UDim.new(0, 8),
        CornerSmall     = UDim.new(0, 6),
        Font            = Enum.Font.GothamMedium,
        FontBold        = Enum.Font.GothamBold,
        FontLight        = Enum.Font.Gotham,
    },

    Midnight = {
        Background      = Color3.fromRGB(8, 10, 18),
        Sidebar         = Color3.fromRGB(12, 14, 24),
        TitleBar        = Color3.fromRGB(12, 14, 24),
        Card            = Color3.fromRGB(18, 20, 32),
        CardBorder      = Color3.fromRGB(32, 36, 52),
        Surface         = Color3.fromRGB(22, 24, 36),
        SurfaceHover    = Color3.fromRGB(30, 32, 46),
        Text            = Color3.fromRGB(225, 228, 240),
        TextDim         = Color3.fromRGB(120, 124, 140),
        TextDark        = Color3.fromRGB(70, 74, 88),
        Accent          = Color3.fromRGB(100, 130, 240),
        AccentHover     = Color3.fromRGB(120, 150, 255),
        AccentDark      = Color3.fromRGB(80, 110, 200),
        ToggleOff       = Color3.fromRGB(36, 38, 50),
        SliderTrack     = Color3.fromRGB(30, 32, 44),
        Success         = Color3.fromRGB(80, 200, 140),
        Warning         = Color3.fromRGB(240, 190, 70),
        Error           = Color3.fromRGB(230, 80, 90),
        Info            = Color3.fromRGB(100, 170, 240),
        Shadow          = Color3.fromRGB(0, 0, 4),
        AccentGradient  = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 110, 240)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 80, 220))
        }),
        CornerRadius    = UDim.new(0, 8),
        CornerSmall     = UDim.new(0, 6),
        Font            = Enum.Font.GothamMedium,
        FontBold        = Enum.Font.GothamBold,
        FontLight        = Enum.Font.Gotham,
    },

    Ember = {
        Background      = Color3.fromRGB(14, 8, 8),
        Sidebar         = Color3.fromRGB(18, 12, 12),
        TitleBar        = Color3.fromRGB(18, 12, 12),
        Card            = Color3.fromRGB(26, 18, 18),
        CardBorder      = Color3.fromRGB(48, 34, 34),
        Surface         = Color3.fromRGB(30, 22, 22),
        SurfaceHover    = Color3.fromRGB(40, 30, 30),
        Text            = Color3.fromRGB(240, 228, 222),
        TextDim         = Color3.fromRGB(140, 120, 112),
        TextDark        = Color3.fromRGB(88, 70, 65),
        Accent          = Color3.fromRGB(230, 90, 60),
        AccentHover     = Color3.fromRGB(250, 110, 80),
        AccentDark      = Color3.fromRGB(190, 70, 45),
        ToggleOff       = Color3.fromRGB(48, 36, 36),
        SliderTrack     = Color3.fromRGB(40, 30, 30),
        Success         = Color3.fromRGB(100, 200, 100),
        Warning         = Color3.fromRGB(240, 180, 60),
        Error           = Color3.fromRGB(240, 70, 70),
        Info            = Color3.fromRGB(100, 160, 220),
        Shadow          = Color3.fromRGB(4, 0, 0),
        AccentGradient  = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 80, 40)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 50, 80))
        }),
        CornerRadius    = UDim.new(0, 8),
        CornerSmall     = UDim.new(0, 6),
        Font            = Enum.Font.GothamMedium,
        FontBold        = Enum.Font.GothamBold,
        FontLight        = Enum.Font.Gotham,
    },

    Frost = {
        Background      = Color3.fromRGB(240, 242, 248),
        Sidebar         = Color3.fromRGB(230, 232, 240),
        TitleBar        = Color3.fromRGB(234, 236, 244),
        Card            = Color3.fromRGB(250, 252, 255),
        CardBorder      = Color3.fromRGB(210, 214, 226),
        Surface         = Color3.fromRGB(234, 236, 244),
        SurfaceHover    = Color3.fromRGB(224, 226, 236),
        Text            = Color3.fromRGB(24, 26, 34),
        TextDim         = Color3.fromRGB(100, 104, 118),
        TextDark        = Color3.fromRGB(160, 164, 176),
        Accent          = Color3.fromRGB(80, 120, 210),
        AccentHover     = Color3.fromRGB(60, 100, 190),
        AccentDark      = Color3.fromRGB(100, 140, 230),
        ToggleOff       = Color3.fromRGB(200, 204, 216),
        SliderTrack     = Color3.fromRGB(210, 214, 226),
        Success         = Color3.fromRGB(40, 160, 80),
        Warning         = Color3.fromRGB(210, 150, 30),
        Error           = Color3.fromRGB(210, 60, 60),
        Info            = Color3.fromRGB(50, 130, 210),
        Shadow          = Color3.fromRGB(180, 184, 196),
        AccentGradient  = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 100, 210)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 80, 200))
        }),
        CornerRadius    = UDim.new(0, 8),
        CornerSmall     = UDim.new(0, 6),
        Font            = Enum.Font.GothamMedium,
        FontBold        = Enum.Font.GothamBold,
        FontLight        = Enum.Font.Gotham,
    },
}

-- Theme binding system
local ThemeEngine = {}
ThemeEngine._bindings   = {}
ThemeEngine._current    = nil
ThemeEngine._nextId     = 0
ThemeEngine.Changed     = Signal.new()

function ThemeEngine:Get(key)
    return self._current and self._current[key]
end

function ThemeEngine:Bind(instance, property, themeKey, transform)
    self._nextId = self._nextId + 1
    local id = self._nextId
    self._bindings[id] = {
        inst = instance,
        prop = property,
        key  = themeKey,
        fn   = transform,
    }
    -- apply now
    if self._current then
        local val = self._current[themeKey]
        if transform then val = transform(val) end
        if val ~= nil then instance[property] = val end
    end
    return function() self._bindings[id] = nil end
end

function ThemeEngine:Apply(themeName, animate)
    local theme = type(themeName) == "string" and Themes[themeName] or themeName
    if not theme then return end
    self._current = theme
    local dur = animate and 0.3 or 0
    local stale = {}
    for id, b in pairs(self._bindings) do
        if not b.inst or not b.inst.Parent then
            stale[#stale + 1] = id
            continue
        end
        local val = theme[b.key]
        if b.fn then val = b.fn(val) end
        if val == nil then continue end
        if dur > 0 and (typeof(val) == "Color3" or typeof(val) == "number") then
            Util.tween(b.inst, { [b.prop] = val }, dur)
        else
            b.inst[b.prop] = val
        end
    end
    for _, id in ipairs(stale) do self._bindings[id] = nil end
    self.Changed:Fire(theme)
end

function ThemeEngine:Register(name, themeTable)
    Themes[name] = themeTable
end

----------------------------------------------------------------
-- Dragging
----------------------------------------------------------------
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging = false
    local dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInput.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            Util.tween(frame, { Position = newPos }, 0.06, Enum.EasingStyle.Sine)
        end
    end)
end

----------------------------------------------------------------
-- Ripple Effect
----------------------------------------------------------------
local function createRipple(parent, inputPos)
    local absPos = parent.AbsolutePosition
    local absSize = parent.AbsoluteSize
    local relX = inputPos and (inputPos.X - absPos.X) or (absSize.X / 2)
    local relY = inputPos and (inputPos.Y - absPos.Y) or (absSize.Y / 2)
    local maxDist = math.max(
        math.sqrt(relX^2 + relY^2),
        math.sqrt((absSize.X - relX)^2 + relY^2),
        math.sqrt(relX^2 + (absSize.Y - relY)^2),
        math.sqrt((absSize.X - relX)^2 + (absSize.Y - relY)^2)
    ) * 2

    local ripple = Util.create("Frame", {
        Name = "_Ripple",
        Parent = parent,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.82,
        Position = UDim2.new(0, relX, 0, relY),
        Size = UDim2.new(0, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = parent.ZIndex + 5,
        ClipsDescendants = false,
    })
    Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ripple })

    local tw = Util.tween(ripple, {
        Size = UDim2.new(0, maxDist, 0, maxDist),
        BackgroundTransparency = 1
    }, 0.45, Enum.EasingStyle.Quart)
    tw.Completed:Connect(function() ripple:Destroy() end)
end

----------------------------------------------------------------
-- Icons (built-in simple text icons)
----------------------------------------------------------------
local Icons = {
    home     = "⌂", combat  = "⚔", player  = "☻", misc  = "✦",
    visual   = "◉", world   = "⊕", config  = "⚙", info  = "ℹ",
    close    = "✕", minimize = "—", maximize = "□",
    check    = "✓", arrow   = "›", search  = "⌕", star  = "★",
    heart    = "♥", shield  = "⛨", bolt    = "⚡", gear  = "⚙",
    eye      = "◉", lock    = "⊘", key     = "⚷", flag  = "⚑",
    swords   = "⚔", target  = "◎", speed   = "»", moon  = "☾",
    sun      = "☼", code    = "<>", folder  = "📁", file  = "📄",
}

local function getIcon(name)
    return Icons[name] or (type(name) == "string" and #name <= 2 and name) or "•"
end

----------------------------------------------------------------
-- Notification System
----------------------------------------------------------------
local NotificationHolder
local ActiveNotifications = {}

local function ensureNotifHolder(screenGui)
    if NotificationHolder and NotificationHolder.Parent then return end
    NotificationHolder = Util.create("Frame", {
        Name = "VeltNotifications",
        Parent = screenGui,
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.new(0, 300, 1, -40),
        AnchorPoint = Vector2.new(1, 1),
        ZIndex = 100,
        ClipsDescendants = false,
    })
    Util.create("UIListLayout", {
        Parent = NotificationHolder,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 6),
    })
end

local function notify(config)
    if not NotificationHolder then return end
    local theme = ThemeEngine._current or Themes.Obsidian
    local nType = config.Type or "Info"
    local accentColor = theme[nType] or theme.Accent
    local duration = config.Duration or 4

    local card = Util.create("Frame", {
        Name = "Notif",
        Parent = NotificationHolder,
        BackgroundColor3 = theme.Card,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        LayoutOrder = -tick(),
        BackgroundTransparency = 1,
        ZIndex = 101,
    })
    Util.create("UICorner", { CornerRadius = theme.CornerRadius, Parent = card })
    Util.create("UIStroke", { Color = accentColor, Thickness = 1, Transparency = 0.7, Parent = card })
    Util.create("UIPadding", { PaddingTop = UDim.new(0,10), PaddingBottom = UDim.new(0,10), PaddingLeft = UDim.new(0,12), PaddingRight = UDim.new(0,12), Parent = card })

    -- accent bar
    Util.create("Frame", {
        Parent = card,
        BackgroundColor3 = accentColor,
        Size = UDim2.new(0, 3, 1, -20),
        Position = UDim2.new(0, -8, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 102,
    })

    local title = Util.create("TextLabel", {
        Parent = card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 16),
        Font = theme.FontBold,
        TextColor3 = theme.Text,
        TextSize = 13,
        Text = config.Title or nType,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 102,
    })

    if config.Content then
        Util.create("TextLabel", {
            Parent = card,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 20),
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Font = theme.Font,
            TextColor3 = theme.TextDim,
            TextSize = 12,
            Text = config.Content,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 102,
        })
    end

    -- progress bar
    local prog = Util.create("Frame", {
        Parent = card,
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.6,
        Size = UDim2.new(1, 24, 0, 2),
        Position = UDim2.new(0, -12, 1, 8),
        BorderSizePixel = 0,
        ZIndex = 103,
    })

    -- animate in
    Util.tween(card, { BackgroundTransparency = 0.05 }, 0.3)

    -- progress shrink
    Util.tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        Util.tween(card, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) }, 0.3)
        task.delay(0.35, function()
            if card.Parent then card:Destroy() end
        end)
    end)
end

----------------------------------------------------------------
-- Config / Save System
----------------------------------------------------------------
local ConfigSystem = {}

function ConfigSystem.new(folder, name)
    local self = { folder = folder, name = name, flags = {}, data = {} }

    function self:Save()
        if not Env.isExploit then return end
        local path = self.folder .. "/" .. self.name .. ".json"
        if not Env.isFolder(self.folder) then
            Env.makeFolder(self.folder)
        end
        local saveData = {}
        for flag, getFn in pairs(self.flags) do
            local ok, val = pcall(getFn)
            if ok then
                if typeof(val) == "Color3" then
                    saveData[flag] = { _type = "Color3", r = val.R, g = val.G, b = val.B }
                elseif typeof(val) == "EnumItem" then
                    saveData[flag] = { _type = "Enum", val = tostring(val) }
                else
                    saveData[flag] = val
                end
            end
        end
        local ok, json = pcall(HttpService.JSONEncode, HttpService, saveData)
        if ok then
            pcall(Env.writeFile, path, json)
        end
    end

    function self:Load()
        if not Env.isExploit then return {} end
        local path = self.folder .. "/" .. self.name .. ".json"
        if not Env.isFile(path) then return {} end
        local ok, raw = pcall(Env.readFile, path)
        if not ok then return {} end
        local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if not ok2 then return {} end
        -- decode special types
        for k, v in pairs(data) do
            if type(v) == "table" and v._type == "Color3" then
                data[k] = Color3.new(v.r, v.g, v.b)
            end
        end
        self.data = data
        return data
    end

    function self:RegisterFlag(flag, getFn, setFn)
        self.flags[flag] = getFn
        -- apply loaded value
        if self.data[flag] ~= nil then
            pcall(setFn, self.data[flag])
        end
    end

    return self
end

----------------------------------------------------------------
-- VELT LIBRARY
----------------------------------------------------------------
local Velt = {}
Velt.__index = Velt
Velt.Version = "1.0.0"
Velt.Themes = Themes
Velt.ThemeEngine = ThemeEngine

-- destroy existing velt instances
if Env.isExploit then
    local ok, genv = pcall(getgenv)
    if ok and genv and genv._VeltInstance then
        pcall(function() genv._VeltInstance:Destroy() end)
    end
end

function Velt:CreateWindow(config)
    config = config or {}
    local windowTitle    = config.Title or "Velt"
    local themeName      = config.Theme or "Obsidian"
    local minimizeKey    = config.MinimizeKey or Enum.KeyCode.RightShift
    local saveConfig     = config.SaveConfig or false
    local configFolder   = config.ConfigFolder or "VeltConfig"
    local windowSize     = config.Size or UDim2.new(0, 580, 0, 420)
    local windowMaid     = Maid.new()

    -- apply theme
    ThemeEngine:Apply(themeName, false)
    local theme = ThemeEngine._current

    -- config system
    local cfgSys
    if saveConfig then
        cfgSys = ConfigSystem.new(configFolder, windowTitle:gsub("[^%w]", "_"))
        cfgSys:Load()
    end

    -- Screen GUI
    local screenGui = Util.create("ScreenGui", {
        Name = "Velt_" .. Util.uuid(),
        DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
    })
    protectGui(screenGui)
    windowMaid:Add(screenGui)
    ensureNotifHolder(screenGui)

    -- Main window frame
    local mainFrame = Util.create("Frame", {
        Name = "Main",
        Parent = screenGui,
        BackgroundColor3 = theme.Background,
        Size = windowSize,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ClipsDescendants = true,
        Active = true,
    })
    ThemeEngine:Bind(mainFrame, "BackgroundColor3", "Background")
    Util.create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = mainFrame })

    -- Shadow
    local shadow = Util.create("ImageLabel", {
        Name = "Shadow",
        Parent = mainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, -15, 0, -15),
        Size = UDim2.new(1, 30, 1, 30),
        ZIndex = -1,
        Image = "rbxassetid://5554236805",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.6,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(23, 23, 277, 277),
    })

    -- Title Bar
    local titleBar = Util.create("Frame", {
        Name = "TitleBar",
        Parent = mainFrame,
        BackgroundColor3 = theme.TitleBar,
        Size = UDim2.new(1, 0, 0, 38),
        BorderSizePixel = 0,
        ZIndex = 10,
    })
    ThemeEngine:Bind(titleBar, "BackgroundColor3", "TitleBar")
    Util.create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = titleBar })
    -- square off bottom corners
    Util.create("Frame", {
        Parent = titleBar,
        BackgroundColor3 = theme.TitleBar,
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.new(0, 0, 1, -12),
        BorderSizePixel = 0,
        ZIndex = 10,
    })

    -- Velt logo dot
    local logoDot = Util.create("Frame", {
        Parent = titleBar,
        BackgroundColor3 = theme.Accent,
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 14, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ZIndex = 11,
    })
    ThemeEngine:Bind(logoDot, "BackgroundColor3", "Accent")
    Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = logoDot })

    -- Brand text
    local brandLabel = Util.create("TextLabel", {
        Parent = titleBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 28, 0, 0),
        Size = UDim2.new(0, 32, 1, 0),
        Font = Enum.Font.GothamBold,
        TextColor3 = theme.Accent,
        TextSize = 12,
        Text = "velt",
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 11,
    })
    ThemeEngine:Bind(brandLabel, "TextColor3", "Accent")

    -- Divider after brand
    Util.create("Frame", {
        Parent = titleBar,
        BackgroundColor3 = theme.CardBorder,
        BackgroundTransparency = 0.5,
        Position = UDim2.new(0, 68, 0.2, 0),
        Size = UDim2.new(0, 1, 0.6, 0),
        BorderSizePixel = 0,
        ZIndex = 11,
    })

    -- Title text
    local titleLabel = Util.create("TextLabel", {
        Parent = titleBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 78, 0, 0),
        Size = UDim2.new(1, -180, 1, 0),
        Font = theme.Font,
        TextColor3 = theme.TextDim,
        TextSize = 13,
        Text = windowTitle,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 11,
    })
    ThemeEngine:Bind(titleLabel, "TextColor3", "TextDim")

    -- Window controls (minimize, close)
    local function makeControlBtn(icon, offsetX, color, hoverColor)
        local btn = Util.create("TextButton", {
            Parent = titleBar,
            BackgroundColor3 = theme.Surface,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, offsetX, 0.5, 0),
            Size = UDim2.new(0, 28, 0, 28),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Font = Enum.Font.GothamBold,
            TextColor3 = color or theme.TextDim,
            TextSize = 14,
            Text = icon,
            AutoButtonColor = false,
            ZIndex = 12,
        })
        Util.create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
        btn.MouseEnter:Connect(function()
            Util.tween(btn, { BackgroundTransparency = 0.5, TextColor3 = hoverColor or theme.Text }, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            Util.tween(btn, { BackgroundTransparency = 1, TextColor3 = color or theme.TextDim }, 0.15)
        end)
        return btn
    end

    local closeBtn = makeControlBtn("✕", -18, theme.TextDim, theme.Error)
    local minBtn   = makeControlBtn("—", -50, theme.TextDim, theme.Text)

    makeDraggable(mainFrame, titleBar)

    -- Sidebar
    local sidebar = Util.create("Frame", {
        Name = "Sidebar",
        Parent = mainFrame,
        BackgroundColor3 = theme.Sidebar,
        Size = UDim2.new(0, 140, 1, -38),
        Position = UDim2.new(0, 0, 0, 38),
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    ThemeEngine:Bind(sidebar, "BackgroundColor3", "Sidebar")

    -- Sidebar border
    Util.create("Frame", {
        Parent = sidebar,
        BackgroundColor3 = theme.CardBorder,
        BackgroundTransparency = 0.6,
        Position = UDim2.new(1, -1, 0, 8),
        Size = UDim2.new(0, 1, 1, -16),
        BorderSizePixel = 0,
        ZIndex = 6,
    })

    -- Tab buttons container
    local tabContainer = Util.create("ScrollingFrame", {
        Name = "TabList",
        Parent = sidebar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 8),
        Size = UDim2.new(1, -16, 1, -40),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Accent,
        ScrollBarImageTransparency = 0.7,
        ZIndex = 6,
        BorderSizePixel = 0,
    })
    Util.create("UIListLayout", {
        Parent = tabContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    -- Footer label
    local footer = Util.create("TextLabel", {
        Parent = sidebar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 1, -28),
        Size = UDim2.new(1, 0, 0, 28),
        Font = Enum.Font.Gotham,
        TextColor3 = theme.TextDark,
        TextSize = 10,
        Text = "velt v" .. Velt.Version,
        ZIndex = 6,
    })
    ThemeEngine:Bind(footer, "TextColor3", "TextDark")

    -- Content area
    local contentArea = Util.create("Frame", {
        Name = "Content",
        Parent = mainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 140, 0, 38),
        Size = UDim2.new(1, -140, 1, -38),
        ClipsDescendants = true,
        ZIndex = 5,
    })

    -- Tab management
    local tabs = {}
    local activeTab = nil

    local function selectTab(tabObj)
        if activeTab == tabObj then return end
        -- deselect old
        if activeTab then
            Util.tween(activeTab._btn, { BackgroundTransparency = 1 }, 0.2)
            Util.tween(activeTab._indicator, { Size = UDim2.new(0, 3, 0, 0), BackgroundTransparency = 1 }, 0.2)
            Util.tween(activeTab._icon, { TextColor3 = theme.TextDim }, 0.15)
            Util.tween(activeTab._label, { TextColor3 = theme.TextDim }, 0.15)
            activeTab._page.Visible = false
        end
        -- select new
        activeTab = tabObj
        Util.tween(tabObj._btn, { BackgroundTransparency = 0.85 }, 0.2)
        Util.tween(tabObj._indicator, { Size = UDim2.new(0, 3, 0, 18), BackgroundTransparency = 0 }, 0.2)
        Util.tween(tabObj._icon, { TextColor3 = theme.Accent }, 0.15)
        Util.tween(tabObj._label, { TextColor3 = theme.Text }, 0.15)
        tabObj._page.Visible = true
    end

    -- Window object
    local window = {}
    window._gui = screenGui
    window._main = mainFrame
    window._visible = true
    window._tabs = tabs
    window._config = cfgSys
    window._maid = windowMaid

    -- Minimize/Close behavior
    local function toggleVisibility()
        window._visible = not window._visible
        if window._visible then
            mainFrame.Visible = true
            Util.tween(mainFrame, { Size = windowSize }, 0.3, Enum.EasingStyle.Back)
            mainFrame.BackgroundTransparency = 0
        else
            Util.tween(mainFrame, { Size = UDim2.new(0, windowSize.X.Offset, 0, 0) }, 0.25, Enum.EasingStyle.Quart)
            task.delay(0.25, function()
                if not window._visible then mainFrame.Visible = false end
            end)
        end
    end

    minBtn.MouseButton1Click:Connect(toggleVisibility)

    closeBtn.MouseButton1Click:Connect(function()
        if cfgSys then cfgSys:Save() end
        Util.tween(mainFrame, {
            Size = UDim2.new(0, windowSize.X.Offset, 0, 0),
            BackgroundTransparency = 1
        }, 0.3, Enum.EasingStyle.Quart)
        task.delay(0.35, function()
            screenGui:Destroy()
        end)
    end)

    windowMaid:Add(UserInput.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == minimizeKey then
            toggleVisibility()
        end
    end))

    ----------------------------------------------------------------
    -- AddTab
    ----------------------------------------------------------------
    function window:AddTab(tabConfig)
        tabConfig = tabConfig or {}
        local tabTitle = tabConfig.Title or "Tab"
        local tabIcon  = tabConfig.Icon or "•"
        local order    = #tabs + 1

        -- Tab button
        local tabBtn = Util.create("TextButton", {
            Name = "Tab_" .. tabTitle,
            Parent = tabContainer,
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 34),
            Font = Enum.Font.SourceSans,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = order,
            ZIndex = 7,
        })
        Util.create("UICorner", { CornerRadius = theme.CornerSmall, Parent = tabBtn })

        -- Active indicator bar
        local indicator = Util.create("Frame", {
            Parent = tabBtn,
            BackgroundColor3 = theme.Accent,
            Size = UDim2.new(0, 3, 0, 0),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 8,
        })
        ThemeEngine:Bind(indicator, "BackgroundColor3", "Accent")
        Util.create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = indicator })

        -- Icon
        local iconLabel = Util.create("TextLabel", {
            Parent = tabBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 0),
            Size = UDim2.new(0, 20, 1, 0),
            Font = Enum.Font.GothamBold,
            TextColor3 = theme.TextDim,
            TextSize = 14,
            Text = getIcon(tabIcon),
            ZIndex = 8,
        })

        -- Label
        local tabLabel = Util.create("TextLabel", {
            Parent = tabBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 38, 0, 0),
            Size = UDim2.new(1, -46, 1, 0),
            Font = theme.Font,
            TextColor3 = theme.TextDim,
            TextSize = 12,
            Text = tabTitle,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 8,
        })

        -- Content page
        local page = Util.create("ScrollingFrame", {
            Name = "Page_" .. tabTitle,
            Parent = contentArea,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.Accent,
            ScrollBarImageTransparency = 0.6,
            Visible = false,
            ZIndex = 5,
            BorderSizePixel = 0,
        })
        Util.create("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            Parent = page,
        })
        Util.create("UIListLayout", {
            Parent = page,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
        })

        local tabObj = {
            _btn = tabBtn,
            _indicator = indicator,
            _icon = iconLabel,
            _label = tabLabel,
            _page = page,
            _order = order,
            _sections = {},
        }

        -- hover effects
        tabBtn.MouseEnter:Connect(function()
            if activeTab ~= tabObj then
                Util.tween(tabBtn, { BackgroundTransparency = 0.9 }, 0.15)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if activeTab ~= tabObj then
                Util.tween(tabBtn, { BackgroundTransparency = 1 }, 0.15)
            end
        end)
        tabBtn.MouseButton1Click:Connect(function()
            selectTab(tabObj)
        end)

        ----------------------------------------------------------------
        -- AddSection
        ----------------------------------------------------------------
        function tabObj:AddSection(secConfig)
            secConfig = secConfig or {}
            local secTitle = secConfig.Title or "Section"
            local secOrder = #self._sections + 1

            local sectionFrame = Util.create("Frame", {
                Name = "Section_" .. secTitle,
                Parent = page,
                BackgroundColor3 = theme.Card,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = secOrder,
                ZIndex = 6,
            })
            ThemeEngine:Bind(sectionFrame, "BackgroundColor3", "Card")
            Util.create("UICorner", { CornerRadius = theme.CornerRadius, Parent = sectionFrame })
            Util.create("UIStroke", {
                Color = theme.CardBorder,
                Thickness = 1,
                Transparency = 0.4,
                Parent = sectionFrame,
            })
            Util.create("UIPadding", {
                PaddingTop = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 12),
                PaddingRight = UDim.new(0, 12),
                Parent = sectionFrame,
            })

            -- Section title
            if secTitle ~= "" then
                Util.create("TextLabel", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Font = theme.FontBold,
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Text = string.upper(secTitle),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 0,
                    ZIndex = 7,
                })
            end

            local elementLayout = Util.create("UIListLayout", {
                Parent = sectionFrame,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
            })

            local section = {}
            section._frame = sectionFrame
            section._elementCount = 0

            self._sections[secOrder] = section

            ----------------------------------------------------------------
            -- AddToggle
            ----------------------------------------------------------------
            function section:AddToggle(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local value = cfg.Default or false
                local callback = cfg.Callback or function() end
                local changed = Signal.new()

                local row = Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 32),
                    LayoutOrder = section._elementCount,
                    ZIndex = 7,
                })

                Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -56, 1, 0),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = cfg.Title or "Toggle",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8,
                })

                if cfg.Description then
                    Util.create("TextLabel", {
                        Parent = row,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, 0, 0, 16),
                        Size = UDim2.new(1, -56, 0, 14),
                        Font = theme.FontLight,
                        TextColor3 = theme.TextDim,
                        TextSize = 10,
                        Text = cfg.Description,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 8,
                    })
                    row.Size = UDim2.new(1, 0, 0, 40)
                end

                -- Toggle switch
                local track = Util.create("TextButton", {
                    Parent = row,
                    BackgroundColor3 = value and theme.Accent or theme.ToggleOff,
                    Position = UDim2.new(1, -44, 0.5, 0),
                    Size = UDim2.new(0, 44, 0, 22),
                    AnchorPoint = Vector2.new(0, 0.5),
                    AutoButtonColor = false,
                    Text = "",
                    ZIndex = 8,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })

                local knob = Util.create("Frame", {
                    Parent = track,
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Size = UDim2.new(0, 16, 0, 16),
                    Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 9,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

                local function updateToggle(v, skipCb)
                    value = v
                    Util.tween(track, { BackgroundColor3 = v and theme.Accent or theme.ToggleOff }, 0.2)
                    Util.tween(knob, { Position = v and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.2, Enum.EasingStyle.Back)
                    if not skipCb then
                        pcall(callback, v)
                        changed:Fire(v)
                    end
                end

                track.MouseButton1Click:Connect(function()
                    updateToggle(not value)
                end)

                local toggle = {}
                function toggle:Set(v) updateToggle(v) end
                function toggle:Get() return value end
                toggle.OnChanged = changed

                -- config flag
                if cfg.Flag and cfgSys then
                    cfgSys:RegisterFlag(cfg.Flag, function() return value end, function(v) updateToggle(v, true) end)
                end

                -- theme update
                ThemeEngine.Changed:Connect(function(t)
                    Util.tween(track, { BackgroundColor3 = value and t.Accent or t.ToggleOff }, 0.3)
                end)

                return toggle
            end

            ----------------------------------------------------------------
            -- AddSlider
            ----------------------------------------------------------------
            function section:AddSlider(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local min = cfg.Min or 0
                local max = cfg.Max or 100
                local increment = cfg.Increment or 1
                local suffix = cfg.Suffix or ""
                local value = Util.clamp(cfg.Default or min, min, max)
                local callback = cfg.Callback or function() end
                local changed = Signal.new()

                local row = Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 46),
                    LayoutOrder = section._elementCount,
                    ZIndex = 7,
                })

                Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.6, 0, 0, 18),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = cfg.Title or "Slider",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8,
                })

                local valueLabel = Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.6, 0, 0, 0),
                    Size = UDim2.new(0.4, 0, 0, 18),
                    Font = theme.Font,
                    TextColor3 = theme.Accent,
                    TextSize = 12,
                    Text = tostring(Util.round(value, 2)) .. suffix,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 8,
                })
                ThemeEngine:Bind(valueLabel, "TextColor3", "Accent")

                -- Track
                local trackFrame = Util.create("Frame", {
                    Parent = row,
                    BackgroundColor3 = theme.SliderTrack,
                    Position = UDim2.new(0, 0, 0, 26),
                    Size = UDim2.new(1, 0, 0, 6),
                    ZIndex = 8,
                })
                ThemeEngine:Bind(trackFrame, "BackgroundColor3", "SliderTrack")
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = trackFrame })

                -- Fill
                local pct = (value - min) / (max - min)
                local fillFrame = Util.create("Frame", {
                    Parent = trackFrame,
                    BackgroundColor3 = theme.Accent,
                    Size = UDim2.new(pct, 0, 1, 0),
                    ZIndex = 9,
                })
                ThemeEngine:Bind(fillFrame, "BackgroundColor3", "Accent")
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fillFrame })

                -- Gradient on fill
                Util.create("UIGradient", {
                    Parent = fillFrame,
                    Color = theme.AccentGradient,
                })

                -- Knob
                local sliderKnob = Util.create("Frame", {
                    Parent = trackFrame,
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(pct, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    ZIndex = 10,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sliderKnob })

                -- Knob glow
                Util.create("UIStroke", {
                    Parent = sliderKnob,
                    Color = theme.Accent,
                    Thickness = 2,
                    Transparency = 0.5,
                })

                local sliding = false

                local function updateSlider(input)
                    local absPos = trackFrame.AbsolutePosition.X
                    local absSize = trackFrame.AbsoluteSize.X
                    local relX = Util.clamp((input.Position.X - absPos) / absSize, 0, 1)
                    local raw = min + (max - min) * relX
                    -- snap to increment
                    value = Util.clamp(Util.round(raw / increment) * increment, min, max)
                    local newPct = (value - min) / (max - min)
                    fillFrame.Size = UDim2.new(newPct, 0, 1, 0)
                    sliderKnob.Position = UDim2.new(newPct, 0, 0.5, 0)
                    valueLabel.Text = tostring(Util.round(value, 2)) .. suffix
                    pcall(callback, value)
                    changed:Fire(value)
                end

                trackFrame.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        updateSlider(input)
                    end
                end)

                windowMaid:Add(UserInput.InputChanged:Connect(function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
                        updateSlider(input)
                    end
                end))

                windowMaid:Add(UserInput.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end))

                local slider = {}
                function slider:Set(v)
                    value = Util.clamp(v, min, max)
                    local p = (value - min) / (max - min)
                    fillFrame.Size = UDim2.new(p, 0, 1, 0)
                    sliderKnob.Position = UDim2.new(p, 0, 0.5, 0)
                    valueLabel.Text = tostring(Util.round(value, 2)) .. suffix
                end
                function slider:Get() return value end
                slider.OnChanged = changed

                if cfg.Flag and cfgSys then
                    cfgSys:RegisterFlag(cfg.Flag, function() return value end, function(v) slider:Set(v) end)
                end

                return slider
            end

            ----------------------------------------------------------------
            -- AddButton
            ----------------------------------------------------------------
            function section:AddButton(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local callback = cfg.Callback or function() end

                local btn = Util.create("TextButton", {
                    Parent = sectionFrame,
                    BackgroundColor3 = theme.Accent,
                    Size = UDim2.new(1, 0, 0, 34),
                    Font = theme.FontBold,
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 13,
                    Text = cfg.Title or "Button",
                    AutoButtonColor = false,
                    LayoutOrder = section._elementCount,
                    ZIndex = 8,
                })
                ThemeEngine:Bind(btn, "BackgroundColor3", "Accent")
                Util.create("UICorner", { CornerRadius = theme.CornerSmall, Parent = btn })

                -- Gradient overlay
                Util.create("UIGradient", {
                    Parent = btn,
                    Color = theme.AccentGradient,
                    Rotation = 90,
                })

                btn.MouseEnter:Connect(function()
                    Util.tween(btn, { BackgroundColor3 = theme.AccentHover }, 0.15)
                end)
                btn.MouseLeave:Connect(function()
                    Util.tween(btn, { BackgroundColor3 = theme.Accent }, 0.15)
                end)
                btn.MouseButton1Click:Connect(function()
                    createRipple(btn, nil)
                    pcall(callback)
                end)

                local button = {}
                function button:SetTitle(t) btn.Text = t end
                return button
            end

            ----------------------------------------------------------------
            -- AddInput
            ----------------------------------------------------------------
            function section:AddInput(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local value = cfg.Default or ""
                local callback = cfg.Callback or function() end
                local changed = Signal.new()

                local row = Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 50),
                    LayoutOrder = section._elementCount,
                    ZIndex = 7,
                })

                Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = cfg.Title or "Input",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8,
                })

                local inputFrame = Util.create("Frame", {
                    Parent = row,
                    BackgroundColor3 = theme.Surface,
                    Position = UDim2.new(0, 0, 0, 22),
                    Size = UDim2.new(1, 0, 0, 28),
                    ZIndex = 8,
                })
                ThemeEngine:Bind(inputFrame, "BackgroundColor3", "Surface")
                Util.create("UICorner", { CornerRadius = theme.CornerSmall, Parent = inputFrame })
                Util.create("UIStroke", {
                    Color = theme.CardBorder,
                    Thickness = 1,
                    Transparency = 0.5,
                    Parent = inputFrame,
                })

                local textbox = Util.create("TextBox", {
                    Parent = inputFrame,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 8, 0, 0),
                    Size = UDim2.new(1, -16, 1, 0),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    PlaceholderColor3 = theme.TextDark,
                    TextSize = 12,
                    Text = value,
                    PlaceholderText = cfg.Placeholder or "Type here...",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = cfg.ClearOnFocus or false,
                    ZIndex = 9,
                })

                textbox.FocusLost:Connect(function(enterPressed)
                    value = textbox.Text
                    pcall(callback, value, enterPressed)
                    changed:Fire(value)
                end)

                local input = {}
                function input:Set(v) textbox.Text = v; value = v end
                function input:Get() return value end
                input.OnChanged = changed

                if cfg.Flag and cfgSys then
                    cfgSys:RegisterFlag(cfg.Flag, function() return value end, function(v) input:Set(v) end)
                end

                return input
            end

            ----------------------------------------------------------------
            -- AddDropdown
            ----------------------------------------------------------------
            function section:AddDropdown(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local options = cfg.Options or {}
                local multi = cfg.Multi or false
                local searchable = cfg.Searchable or false
                local value = multi and (cfg.Default or {}) or (cfg.Default or nil)
                local callback = cfg.Callback or function() end
                local changed = Signal.new()
                local isOpen = false

                local row = Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 50),
                    LayoutOrder = section._elementCount,
                    ClipsDescendants = false,
                    ZIndex = 20 + section._elementCount,
                })

                Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = cfg.Title or "Dropdown",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 21,
                })

                local dropBtn = Util.create("TextButton", {
                    Parent = row,
                    BackgroundColor3 = theme.Surface,
                    Position = UDim2.new(0, 0, 0, 22),
                    Size = UDim2.new(1, 0, 0, 28),
                    Font = theme.Font,
                    TextColor3 = theme.TextDim,
                    TextSize = 12,
                    Text = "",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false,
                    ZIndex = 21,
                })
                ThemeEngine:Bind(dropBtn, "BackgroundColor3", "Surface")
                Util.create("UICorner", { CornerRadius = theme.CornerSmall, Parent = dropBtn })
                Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Transparency = 0.5, Parent = dropBtn })
                Util.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = dropBtn })

                local arrowLabel = Util.create("TextLabel", {
                    Parent = dropBtn,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -4, 0, 0),
                    Size = UDim2.new(0, 16, 1, 0),
                    AnchorPoint = Vector2.new(1, 0),
                    Font = Enum.Font.GothamBold,
                    TextColor3 = theme.TextDim,
                    TextSize = 10,
                    Text = "▼",
                    ZIndex = 22,
                })

                -- Dropdown list
                local dropList = Util.create("Frame", {
                    Parent = row,
                    BackgroundColor3 = theme.Card,
                    Position = UDim2.new(0, 0, 0, 52),
                    Size = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 50,
                })
                Util.create("UICorner", { CornerRadius = theme.CornerSmall, Parent = dropList })
                Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Transparency = 0.3, Parent = dropList })

                local scrollList = Util.create("ScrollingFrame", {
                    Parent = dropList,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = theme.Accent,
                    ZIndex = 51,
                    BorderSizePixel = 0,
                })
                Util.create("UIListLayout", { Parent = scrollList, Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder })
                Util.create("UIPadding", { PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4), PaddingLeft = UDim.new(0,4), PaddingRight = UDim.new(0,4), Parent = scrollList })

                -- Search box
                local searchBox
                if searchable then
                    searchBox = Util.create("TextBox", {
                        Parent = scrollList,
                        BackgroundColor3 = theme.Surface,
                        Size = UDim2.new(1, 0, 0, 26),
                        Font = theme.Font,
                        TextColor3 = theme.Text,
                        PlaceholderColor3 = theme.TextDark,
                        TextSize = 11,
                        Text = "",
                        PlaceholderText = "Search...",
                        TextXAlignment = Enum.TextXAlignment.Left,
                        LayoutOrder = -1,
                        ZIndex = 52,
                    })
                    Util.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = searchBox })
                    Util.create("UIPadding", { PaddingLeft = UDim.new(0, 6), Parent = searchBox })
                end

                local optionButtons = {}

                local function getDisplayText()
                    if multi then
                        if type(value) == "table" and #value > 0 then
                            return table.concat(value, ", ")
                        else
                            return cfg.Placeholder or "Select..."
                        end
                    else
                        return value or cfg.Placeholder or "Select..."
                    end
                end

                local function refreshOptions(filter)
                    for _, ob in ipairs(optionButtons) do
                        if ob.Parent then ob:Destroy() end
                    end
                    table.clear(optionButtons)

                    for i, opt in ipairs(options) do
                        local optStr = tostring(opt)
                        if filter and filter ~= "" and not optStr:lower():find(filter:lower(), 1, true) then
                            continue
                        end

                        local isSelected = false
                        if multi then
                            for _, sv in ipairs(value) do
                                if sv == opt then isSelected = true; break end
                            end
                        else
                            isSelected = (value == opt)
                        end

                        local optBtn = Util.create("TextButton", {
                            Parent = scrollList,
                            BackgroundColor3 = isSelected and theme.Accent or theme.Surface,
                            BackgroundTransparency = isSelected and 0.75 or 1,
                            Size = UDim2.new(1, 0, 0, 26),
                            Font = theme.Font,
                            TextColor3 = isSelected and theme.Accent or theme.Text,
                            TextSize = 12,
                            Text = "  " .. optStr,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            AutoButtonColor = false,
                            LayoutOrder = i,
                            ZIndex = 52,
                        })
                        Util.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = optBtn })

                        optBtn.MouseEnter:Connect(function()
                            if not isSelected then
                                Util.tween(optBtn, { BackgroundTransparency = 0.85 }, 0.1)
                            end
                        end)
                        optBtn.MouseLeave:Connect(function()
                            if not isSelected then
                                Util.tween(optBtn, { BackgroundTransparency = 1 }, 0.1)
                            end
                        end)

                        optBtn.MouseButton1Click:Connect(function()
                            if multi then
                                local found = false
                                for idx, sv in ipairs(value) do
                                    if sv == opt then
                                        table.remove(value, idx)
                                        found = true
                                        break
                                    end
                                end
                                if not found then
                                    table.insert(value, opt)
                                end
                            else
                                value = opt
                                isOpen = false
                                Util.tween(dropList, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
                                task.delay(0.2, function() dropList.Visible = false end)
                                arrowLabel.Text = "▼"
                            end
                            dropBtn.Text = getDisplayText()
                            pcall(callback, value)
                            changed:Fire(value)
                            if multi then refreshOptions(searchBox and searchBox.Text or nil) end
                        end)

                        optionButtons[#optionButtons + 1] = optBtn
                    end
                end

                dropBtn.Text = getDisplayText()
                refreshOptions()

                if searchBox then
                    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                        refreshOptions(searchBox.Text)
                    end)
                end

                dropBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        dropList.Visible = true
                        refreshOptions(searchBox and searchBox.Text or nil)
                        local itemCount = math.min(#options, 6)
                        local h = itemCount * 28 + 8 + (searchable and 30 or 0)
                        Util.tween(dropList, { Size = UDim2.new(1, 0, 0, h) }, 0.2, Enum.EasingStyle.Quart)
                        arrowLabel.Text = "▲"
                    else
                        Util.tween(dropList, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                        task.delay(0.15, function() dropList.Visible = false end)
                        arrowLabel.Text = "▼"
                    end
                end)

                local dropdown = {}
                function dropdown:Set(v)
                    value = v
                    dropBtn.Text = getDisplayText()
                end
                function dropdown:Get() return value end
                function dropdown:Add(opt)
                    table.insert(options, opt)
                    refreshOptions()
                end
                function dropdown:Remove(opt)
                    for i, o in ipairs(options) do
                        if o == opt then table.remove(options, i); break end
                    end
                    refreshOptions()
                end
                function dropdown:Clear()
                    table.clear(options)
                    value = multi and {} or nil
                    dropBtn.Text = getDisplayText()
                    refreshOptions()
                end
                dropdown.OnChanged = changed

                if cfg.Flag and cfgSys then
                    cfgSys:RegisterFlag(cfg.Flag, function() return value end, function(v) dropdown:Set(v) end)
                end

                return dropdown
            end

            ----------------------------------------------------------------
            -- AddKeybind
            ----------------------------------------------------------------
            function section:AddKeybind(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local value = cfg.Default or Enum.KeyCode.Unknown
                local callback = cfg.Callback or function() end
                local changedCb = cfg.ChangedCallback or function() end
                local changed = Signal.new()
                local listening = false

                local row = Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 32),
                    LayoutOrder = section._elementCount,
                    ZIndex = 7,
                })

                Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -80, 1, 0),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = cfg.Title or "Keybind",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8,
                })

                local bindBtn = Util.create("TextButton", {
                    Parent = row,
                    BackgroundColor3 = theme.Surface,
                    Position = UDim2.new(1, -70, 0.5, 0),
                    Size = UDim2.new(0, 70, 0, 24),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Font = theme.Font,
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Text = value.Name or "None",
                    AutoButtonColor = false,
                    ZIndex = 8,
                })
                Util.create("UICorner", { CornerRadius = theme.CornerSmall, Parent = bindBtn })
                Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Transparency = 0.5, Parent = bindBtn })

                bindBtn.MouseButton1Click:Connect(function()
                    listening = true
                    bindBtn.Text = "..."
                    Util.tween(bindBtn, { BackgroundColor3 = theme.Accent }, 0.15)
                end)

                windowMaid:Add(UserInput.InputBegan:Connect(function(input, processed)
                    if listening then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            if input.KeyCode == Enum.KeyCode.Escape then
                                value = Enum.KeyCode.Unknown
                                bindBtn.Text = "None"
                            else
                                value = input.KeyCode
                                bindBtn.Text = value.Name
                            end
                            listening = false
                            Util.tween(bindBtn, { BackgroundColor3 = theme.Surface }, 0.15)
                            pcall(changedCb, value)
                            changed:Fire(value)
                        end
                    elseif not processed and input.KeyCode == value and value ~= Enum.KeyCode.Unknown then
                        pcall(callback)
                    end
                end))

                local keybind = {}
                function keybind:Set(v) value = v; bindBtn.Text = v.Name or "None" end
                function keybind:Get() return value end
                keybind.OnChanged = changed

                if cfg.Flag and cfgSys then
                    cfgSys:RegisterFlag(cfg.Flag,
                        function() return value.Name end,
                        function(v)
                            local ok, kc = pcall(function() return Enum.KeyCode[v] end)
                            if ok and kc then keybind:Set(kc) end
                        end
                    )
                end

                return keybind
            end

            ----------------------------------------------------------------
            -- AddColorPicker
            ----------------------------------------------------------------
            function section:AddColorPicker(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local value = cfg.Default or Color3.fromRGB(210, 130, 80)
                local callback = cfg.Callback or function() end
                local changed = Signal.new()
                local pickerOpen = false

                local row = Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 32),
                    ClipsDescendants = false,
                    LayoutOrder = section._elementCount,
                    ZIndex = 15 + section._elementCount,
                })

                Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -40, 1, 0),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = cfg.Title or "Color",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 16,
                })

                local colorPreview = Util.create("TextButton", {
                    Parent = row,
                    BackgroundColor3 = value,
                    Position = UDim2.new(1, -30, 0.5, 0),
                    Size = UDim2.new(0, 30, 0, 20),
                    AnchorPoint = Vector2.new(0, 0.5),
                    Text = "",
                    AutoButtonColor = false,
                    ZIndex = 16,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = colorPreview })
                Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Parent = colorPreview })

                -- Picker popup
                local pickerFrame = Util.create("Frame", {
                    Parent = row,
                    BackgroundColor3 = theme.Card,
                    Position = UDim2.new(0.3, 0, 0, 36),
                    Size = UDim2.new(0, 220, 0, 0),
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 60,
                })
                ThemeEngine:Bind(pickerFrame, "BackgroundColor3", "Card")
                Util.create("UICorner", { CornerRadius = theme.CornerRadius, Parent = pickerFrame })
                Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Parent = pickerFrame })
                Util.create("UIPadding", { PaddingTop = UDim.new(0,8), PaddingBottom = UDim.new(0,8), PaddingLeft = UDim.new(0,8), PaddingRight = UDim.new(0,8), Parent = pickerFrame })

                -- SV canvas
                local svCanvas = Util.create("ImageLabel", {
                    Parent = pickerFrame,
                    BackgroundColor3 = Color3.new(1, 0, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(1, -24, 0, 130),
                    Image = "rbxassetid://4155801252",
                    ZIndex = 61,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = svCanvas })

                -- SV cursor
                local svCursor = Util.create("Frame", {
                    Parent = svCanvas,
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Size = UDim2.new(0, 12, 0, 12),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    ZIndex = 63,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = svCursor })
                Util.create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.5, Parent = svCursor })

                -- Hue bar
                local hueBar = Util.create("ImageLabel", {
                    Parent = pickerFrame,
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Position = UDim2.new(1, -16, 0, 0),
                    Size = UDim2.new(0, 16, 0, 130),
                    Image = "rbxassetid://4155801252",
                    ZIndex = 61,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = hueBar })

                -- Hue gradient
                Util.create("UIGradient", {
                    Parent = hueBar,
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                    }),
                    Rotation = 90,
                })

                -- Hue cursor
                local hueCursor = Util.create("Frame", {
                    Parent = hueBar,
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    Size = UDim2.new(1, 4, 0, 4),
                    Position = UDim2.new(0, -2, 0, 0),
                    AnchorPoint = Vector2.new(0, 0),
                    ZIndex = 63,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = hueCursor })

                -- Hex input row
                local hexRow = Util.create("Frame", {
                    Parent = pickerFrame,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 138),
                    Size = UDim2.new(1, 0, 0, 26),
                    ZIndex = 61,
                })

                Util.create("TextLabel", {
                    Parent = hexRow,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 30, 1, 0),
                    Font = theme.Font,
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Text = "HEX",
                    ZIndex = 62,
                })

                local hexInput = Util.create("TextBox", {
                    Parent = hexRow,
                    BackgroundColor3 = theme.Surface,
                    Position = UDim2.new(0, 34, 0, 0),
                    Size = UDim2.new(1, -34, 1, 0),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    TextSize = 11,
                    Text = Util.colorToHex(value),
                    ZIndex = 62,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = hexInput })
                Util.create("UIPadding", { PaddingLeft = UDim.new(0, 6), Parent = hexInput })

                -- State
                local h, s, v = Util.rgbToHsv(value)
                local svDragging, hueDragging = false, false

                local function updateFromHSV()
                    value = Util.hsvToRgb(h, s, v)
                    colorPreview.BackgroundColor3 = value
                    hexInput.Text = Util.colorToHex(value)
                    svCanvas.BackgroundColor3 = Util.hsvToRgb(h, 1, 1)
                    svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                    hueCursor.Position = UDim2.new(0, -2, h, 0)
                    pcall(callback, value)
                    changed:Fire(value)
                end

                svCanvas.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then svDragging = true end
                end)
                hueBar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then hueDragging = true end
                end)

                windowMaid:Add(UserInput.InputChanged:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                    if svDragging then
                        local pos = input.Position
                        s = Util.clamp((pos.X - svCanvas.AbsolutePosition.X) / svCanvas.AbsoluteSize.X, 0, 1)
                        v = 1 - Util.clamp((pos.Y - svCanvas.AbsolutePosition.Y) / svCanvas.AbsoluteSize.Y, 0, 1)
                        updateFromHSV()
                    elseif hueDragging then
                        h = Util.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
                        updateFromHSV()
                    end
                end))

                windowMaid:Add(UserInput.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        svDragging = false
                        hueDragging = false
                    end
                end))

                hexInput.FocusLost:Connect(function()
                    local c = Util.hexToColor(hexInput.Text)
                    h, s, v = Util.rgbToHsv(c)
                    updateFromHSV()
                end)

                -- init positions
                updateFromHSV()

                colorPreview.MouseButton1Click:Connect(function()
                    pickerOpen = not pickerOpen
                    if pickerOpen then
                        pickerFrame.Visible = true
                        Util.tween(pickerFrame, { Size = UDim2.new(0, 220, 0, 176) }, 0.2, Enum.EasingStyle.Quart)
                    else
                        Util.tween(pickerFrame, { Size = UDim2.new(0, 220, 0, 0) }, 0.15)
                        task.delay(0.15, function() pickerFrame.Visible = false end)
                    end
                end)

                local colorPicker = {}
                function colorPicker:Set(c)
                    h, s, v = Util.rgbToHsv(c)
                    updateFromHSV()
                end
                function colorPicker:Get() return value end
                colorPicker.OnChanged = changed

                if cfg.Flag and cfgSys then
                    cfgSys:RegisterFlag(cfg.Flag,
                        function() return { value.R, value.G, value.B } end,
                        function(t) if type(t) == "table" then colorPicker:Set(Color3.new(t[1], t[2], t[3])) end end
                    )
                end

                return colorPicker
            end

            ----------------------------------------------------------------
            -- AddLabel
            ----------------------------------------------------------------
            function section:AddLabel(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1

                local label = Util.create("TextLabel", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18),
                    Font = theme.Font,
                    TextColor3 = theme.TextDim,
                    TextSize = 12,
                    Text = cfg.Title or "Label",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = section._elementCount,
                    ZIndex = 8,
                })
                ThemeEngine:Bind(label, "TextColor3", "TextDim")

                local obj = {}
                function obj:SetTitle(t) label.Text = t end
                return obj
            end

            ----------------------------------------------------------------
            -- AddParagraph
            ----------------------------------------------------------------
            function section:AddParagraph(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1

                local container = Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    LayoutOrder = section._elementCount,
                    ZIndex = 7,
                })

                local titleL = Util.create("TextLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 18),
                    Font = theme.FontBold,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = cfg.Title or "",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8,
                })

                local contentL = Util.create("TextLabel", {
                    Parent = container,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 20),
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Font = theme.FontLight,
                    TextColor3 = theme.TextDim,
                    TextSize = 12,
                    Text = cfg.Content or "",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 8,
                })

                local obj = {}
                function obj:SetTitle(t) titleL.Text = t end
                function obj:SetContent(t) contentL.Text = t end
                return obj
            end

            ----------------------------------------------------------------
            -- AddDivider
            ----------------------------------------------------------------
            function section:AddDivider()
                section._elementCount = section._elementCount + 1

                Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundColor3 = theme.CardBorder,
                    BackgroundTransparency = 0.5,
                    Size = UDim2.new(1, 0, 0, 1),
                    LayoutOrder = section._elementCount,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                })
            end

            ----------------------------------------------------------------
            -- AddProgressbar
            ----------------------------------------------------------------
            function section:AddProgressbar(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local value = cfg.Default or 0

                local row = Util.create("Frame", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                    LayoutOrder = section._elementCount,
                    ZIndex = 7,
                })

                local titleL = Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.7, 0, 0, 16),
                    Font = theme.Font,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = cfg.Title or "Progress",
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 8,
                })

                local pctLabel = Util.create("TextLabel", {
                    Parent = row,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0.7, 0, 0, 0),
                    Size = UDim2.new(0.3, 0, 0, 16),
                    Font = theme.Font,
                    TextColor3 = theme.Accent,
                    TextSize = 12,
                    Text = tostring(math.floor(value)) .. "%",
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 8,
                })
                ThemeEngine:Bind(pctLabel, "TextColor3", "Accent")

                local trackBg = Util.create("Frame", {
                    Parent = row,
                    BackgroundColor3 = theme.SliderTrack,
                    Position = UDim2.new(0, 0, 0, 22),
                    Size = UDim2.new(1, 0, 0, 6),
                    ZIndex = 8,
                })
                ThemeEngine:Bind(trackBg, "BackgroundColor3", "SliderTrack")
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = trackBg })

                local fill = Util.create("Frame", {
                    Parent = trackBg,
                    BackgroundColor3 = theme.Accent,
                    Size = UDim2.new(value / 100, 0, 1, 0),
                    ZIndex = 9,
                })
                ThemeEngine:Bind(fill, "BackgroundColor3", "Accent")
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
                Util.create("UIGradient", { Parent = fill, Color = theme.AccentGradient })

                local bar = {}
                function bar:Set(v)
                    value = Util.clamp(v, 0, 100)
                    Util.tween(fill, { Size = UDim2.new(value / 100, 0, 1, 0) }, 0.3)
                    pctLabel.Text = tostring(math.floor(value)) .. "%"
                end
                function bar:Get() return value end
                return bar
            end

            return section
        end

        tabs[#tabs + 1] = tabObj

        -- auto-select first tab
        if #tabs == 1 then
            selectTab(tabObj)
        end

        return tabObj
    end

    ----------------------------------------------------------------
    -- Window Methods
    ----------------------------------------------------------------
    function window:SetTheme(name)
        ThemeEngine:Apply(name, true)
    end

    function window:Notify(cfg)
        notify(cfg)
    end

    function window:SaveConfig()
        if cfgSys then cfgSys:Save() end
    end

    function window:LoadConfig()
        if cfgSys then cfgSys:Load() end
    end

    function window:Destroy()
        if cfgSys then cfgSys:Save() end
        windowMaid:Cleanup()
    end

    function window:Minimize()
        toggleVisibility()
    end

    function window:AddTheme(name, themeTable)
        ThemeEngine:Register(name, themeTable)
    end

    -- Store reference for cleanup on reload
    if Env.isExploit then
        pcall(function() getgenv()._VeltInstance = window end)
    end

    -- Intro animation
    mainFrame.Size = UDim2.new(0, windowSize.X.Offset, 0, 0)
    mainFrame.BackgroundTransparency = 0.5
    task.spawn(function()
        task.wait(0.05)
        Util.tween(mainFrame, {
            Size = windowSize,
            BackgroundTransparency = 0
        }, 0.4, Enum.EasingStyle.Back)
    end)

    return window
end

----------------------------------------------------------------
-- Static Methods
----------------------------------------------------------------
function Velt:GetThemes()
    local list = {}
    for name in pairs(Themes) do
        list[#list + 1] = name
    end
    return list
end

function Velt:RegisterTheme(name, themeTable)
    ThemeEngine:Register(name, themeTable)
end

function Velt:Notify(cfg)
    notify(cfg)
end

return Velt
