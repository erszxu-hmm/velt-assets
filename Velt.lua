--[[
    ██╗   ██╗███████╗██╗  ████████╗
    ██║   ██║██╔════╝██║  ╚══██╔══╝
    ██║   ██║█████╗  ██║     ██║
    ╚██╗ ██╔╝██╔══╝  ██║     ██║
     ╚████╔╝ ███████╗███████╗██║
      ╚═══╝  ╚══════╝╚══════╝╚═╝

    Velt UI Library v2.0.0
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
Env.listFiles   = (typeof(listfiles) == "function" and listfiles) or function() return {} end
Env.getAsset    = (typeof(getcustomasset) == "function" and getcustomasset) or (typeof(getsynasset) == "function" and getsynasset) or nil
Env.canFS       = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
                  and typeof(isfolder) == "function" and typeof(makefolder) == "function" and typeof(listfiles) == "function"

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
local function mkTheme(t)
    local function mix(a, b, k) return a:Lerp(b, k) end
    t.AccentGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0, t.Accent),
        ColorSequenceKeypoint.new(1, mix(t.Accent, t.AccentDark, 0.45)),
    })
    t.TitleBar     = t.TitleBar or t.Sidebar
    t.Success      = t.Success or Color3.fromRGB(74, 210, 140)
    t.Warning      = t.Warning or Color3.fromRGB(240, 190, 80)
    t.Error        = t.Error or Color3.fromRGB(240, 96, 108)
    t.Info         = t.Info or Color3.fromRGB(110, 160, 245)
    t.Shadow       = t.Shadow or Color3.fromRGB(0, 0, 0)
    t.CornerRadius = UDim.new(0, 10)
    t.CornerSmall  = UDim.new(0, 8)
    t.Font         = Enum.Font.GothamMedium
    t.FontBold     = Enum.Font.GothamBold
    t.FontLight    = Enum.Font.Gotham
    return t
end

local function C(r, g, b) return Color3.fromRGB(r, g, b) end

local Themes = {
    -- calm slate + pale sage (default)
    Sage = mkTheme({
        Background = C(13, 19, 21), Sidebar = C(16, 24, 26), Card = C(21, 31, 34), CardBorder = C(38, 54, 58),
        Surface = C(29, 42, 46), SurfaceHover = C(37, 52, 57),
        Text = C(232, 239, 235), TextDim = C(142, 163, 157), TextDark = C(86, 106, 102),
        Accent = C(170, 205, 184), AccentHover = C(196, 226, 208), AccentDark = C(88, 120, 102), OnAccent = C(12, 22, 19),
        ToggleOff = C(40, 56, 61), SliderTrack = C(36, 50, 55),
    }),
    -- near-black with warm orange
    Obsidian = mkTheme({
        Background = C(10, 10, 12), Sidebar = C(13, 13, 16), Card = C(19, 19, 23), CardBorder = C(38, 38, 44),
        Surface = C(28, 28, 33), SurfaceHover = C(37, 37, 43),
        Text = C(240, 236, 230), TextDim = C(142, 136, 128), TextDark = C(88, 84, 78),
        Accent = C(255, 128, 48), AccentHover = C(255, 150, 80), AccentDark = C(176, 84, 30), OnAccent = C(22, 10, 4),
        ToggleOff = C(46, 46, 52), SliderTrack = C(40, 40, 46),
    }),
    -- soft pink on aubergine black
    Rose = mkTheme({
        Background = C(14, 10, 13), Sidebar = C(18, 13, 17), Card = C(25, 18, 23), CardBorder = C(50, 36, 45),
        Surface = C(34, 25, 32), SurfaceHover = C(44, 32, 41),
        Text = C(246, 235, 241), TextDim = C(162, 136, 152), TextDark = C(102, 82, 94),
        Accent = C(240, 100, 150), AccentHover = C(250, 126, 172), AccentDark = C(168, 62, 102), OnAccent = C(32, 6, 16),
        ToggleOff = C(54, 40, 50), SliderTrack = C(46, 34, 42),
    }),
    -- deep teal
    Ocean = mkTheme({
        Background = C(8, 22, 28), Sidebar = C(10, 28, 35), Card = C(14, 36, 44), CardBorder = C(28, 68, 78),
        Surface = C(20, 50, 60), SurfaceHover = C(27, 63, 75),
        Text = C(228, 243, 246), TextDim = C(132, 172, 180), TextDark = C(80, 116, 124),
        Accent = C(72, 202, 202), AccentHover = C(102, 224, 224), AccentDark = C(36, 130, 134), OnAccent = C(4, 22, 24),
        ToggleOff = C(30, 64, 74), SliderTrack = C(26, 58, 68),
    }),
    -- indigo night
    Midnight = mkTheme({
        Background = C(10, 12, 22), Sidebar = C(13, 16, 28), Card = C(19, 22, 38), CardBorder = C(36, 42, 68),
        Surface = C(27, 31, 52), SurfaceHover = C(35, 40, 66),
        Text = C(228, 232, 246), TextDim = C(132, 140, 170), TextDark = C(84, 90, 118),
        Accent = C(122, 142, 255), AccentHover = C(148, 166, 255), AccentDark = C(80, 96, 200), OnAccent = C(8, 10, 30),
        ToggleOff = C(40, 45, 70), SliderTrack = C(34, 38, 60),
    }),
    -- greyscale
    Mono = mkTheme({
        Background = C(12, 12, 12), Sidebar = C(16, 16, 16), Card = C(22, 22, 22), CardBorder = C(42, 42, 42),
        Surface = C(31, 31, 31), SurfaceHover = C(40, 40, 40),
        Text = C(238, 238, 238), TextDim = C(142, 142, 142), TextDark = C(88, 88, 88),
        Accent = C(226, 226, 226), AccentHover = C(246, 246, 246), AccentDark = C(140, 140, 140), OnAccent = C(14, 14, 14),
        ToggleOff = C(48, 48, 48), SliderTrack = C(40, 40, 40),
    }),
    -- light
    Frost = mkTheme({
        Background = C(240, 242, 248), Sidebar = C(230, 233, 241), Card = C(250, 251, 255), CardBorder = C(208, 213, 226),
        Surface = C(236, 239, 247), SurfaceHover = C(226, 230, 240),
        Text = C(24, 26, 34), TextDim = C(98, 104, 120), TextDark = C(158, 164, 178),
        Accent = C(70, 110, 215), AccentHover = C(54, 94, 198), AccentDark = C(120, 150, 230), OnAccent = C(255, 255, 255),
        ToggleOff = C(200, 205, 218), SliderTrack = C(210, 215, 228),
        Shadow = C(180, 184, 196),
    }),
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
local function getIcon(name, title)
    if type(name) == "string" and name ~= "" and #name <= 2 then return name end
    local t = tostring(title or "?")
    return t:sub(1, 1):upper()
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

-- Autosave file:  <folder>/<name>.json         (last state, restored on next launch)
-- Named presets:  <folder>/presets/<name>.json (explicit Save / Load / Delete)
-- Toggles are NOT switched back on at launch unless RestoreToggles = true (safer for farm/aim features);
-- loading a preset always applies everything, toggles included.
function ConfigSystem.new(folder, name, opts)
    opts = opts or {}
    local self = {
        folder = folder, name = name, flags = {}, data = {}, restored = {},
        loading = false, restoreToggles = opts.restoreToggles == true, autosave = opts.autosave ~= false,
        memory = {}, _token = 0,
    }
    local canFS = Env.canFS

    local function mainPath() return folder .. "/" .. name .. ".json" end
    local function presetDir() return folder .. "/presets" end
    local function presetPath(n) return presetDir() .. "/" .. n .. ".json" end
    local function clean(n)
        n = tostring(n or ""):gsub("[^%w _%-]", "")
        n = n:gsub("^%s+", ""):gsub("%s+$", "")
        return n
    end
    local function ensure()
        if not Env.isFolder(folder) then pcall(Env.makeFolder, folder) end
        if not Env.isFolder(presetDir()) then pcall(Env.makeFolder, presetDir()) end
    end
    local function writeJson(path, data)
        local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
        if not ok then return false end
        return (pcall(Env.writeFile, path, json))
    end
    local function readJson(path)
        if not Env.isFile(path) then return nil end
        local ok, raw = pcall(Env.readFile, path)
        if not ok or type(raw) ~= "string" or raw == "" then return nil end
        local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok2 and type(data) == "table" then return data end
        return nil
    end

    function self:Collect()
        local out = {}
        for flag, f in pairs(self.flags) do
            local ok, v = pcall(f.get)
            if ok and v ~= nil then out[flag] = v end
        end
        return out
    end

    function self:Save()
        if not canFS or not self.autosave then return false end
        ensure()
        return writeJson(mainPath(), self:Collect())
    end

    function self:Load()
        self.data = (canFS and self.autosave and readJson(mainPath())) or {}
        return self.data
    end

    -- apply a table of flag -> value (callbacks fire so the script's own state follows the UI)
    function self:Apply(data)
        self.loading = true
        for flag, v in pairs(data) do
            local f = self.flags[flag]
            if f then pcall(f.set, v, true) end
        end
        self.loading = false
        self:Dirty()
    end

    function self:RegisterFlag(flag, signal, getFn, setFn, kind)
        self.flags[flag] = { get = getFn, set = setFn, kind = kind }
        if signal then signal:Connect(function() self:Dirty() end) end
        -- restore once per flag (dynamic rebuilds must not re-apply stale data)
        if not self.restored[flag] then
            self.restored[flag] = true
            local v = self.data[flag]
            if v ~= nil and (kind ~= "toggle" or self.restoreToggles) then
                self.loading = true
                pcall(setFn, v, true)
                self.loading = false
            end
        end
    end

    function self:Dirty()
        if self.loading or not canFS or not self.autosave then return end
        self._token = self._token + 1
        local token = self._token
        task.delay(1.2, function()
            if token == self._token then self:Save() end
        end)
    end

    function self:SavePreset(n)
        n = clean(n)
        if n == "" then return false end
        local data = self:Collect()
        if canFS then
            ensure()
            return writeJson(presetPath(n), data)
        end
        self.memory[n] = data
        return true
    end

    function self:LoadPreset(n)
        n = clean(n)
        local data = canFS and readJson(presetPath(n)) or self.memory[n]
        if type(data) ~= "table" then return false end
        self:Apply(data)
        return true
    end

    function self:DeletePreset(n)
        n = clean(n)
        if canFS then pcall(Env.delFile, presetPath(n)) else self.memory[n] = nil end
    end

    function self:ListPresets()
        local names = {}
        if canFS then
            local ok, files = pcall(Env.listFiles, presetDir())
            if ok and type(files) == "table" then
                for _, p in ipairs(files) do
                    local n = tostring(p):match("([^/\\]+)%.json$")
                    if n then names[#names + 1] = n end
                end
            end
        else
            for n in pairs(self.memory) do names[#names + 1] = n end
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        return names
    end

    self.CleanName = clean
    return self
end

----------------------------------------------------------------
-- Image / logo resolution
--   Logo = nil      -> default Velt logo (downloaded once from the Velt asset repo)
--   Logo = false    -> no logo
--   Logo = "file"   -> file in the executor workspace
--   Logo = "https://..." / rbxassetid / number
----------------------------------------------------------------
local DEFAULT_LOGO_URL  = "https://raw.githubusercontent.com/erszxu-hmm/velt-assets/main/velt_logo.png"
local DEFAULT_LOGO_FILE = "velt_logo.png"

local function pngValid(file)
    local ok, data = pcall(Env.readFile, file)
    return ok and type(data) == "string" and data:sub(2, 4) == "PNG"
end

local function resolveImage(src)
    if src == false then return nil end
    if src == nil then src = DEFAULT_LOGO_URL end
    if type(src) == "number" then return "rbxassetid://" .. src end
    if type(src) ~= "string" or src == "" then return nil end
    if src:find("^rbxassetid://") or src:find("^rbxthumb://") or src:find("^rbxasset://") then return src end

    local file = src
    if src:find("^https?://") then
        file = (src == DEFAULT_LOGO_URL) and DEFAULT_LOGO_FILE or ("velt_" .. (src:match("([^/]+)$") or "image.png"))
        if Env.canFS and (not Env.isFile(file) or not pngValid(file)) then
            pcall(function()
                local data = game:HttpGet(src)
                if type(data) == "string" and data:sub(2, 4) == "PNG" then Env.writeFile(file, data) end
            end)
        end
    end
    if Env.isFile(file) and Env.getAsset then
        local ok, asset = pcall(Env.getAsset, file)
        if ok and asset and asset ~= "" then return asset end
    end
    return nil
end

-- chevron drawn from two bars (font independent); rotate the returned frame 180 to flip it
local function drawChevron(parent, cx, cy, colorKey, z)
    local holder = Util.create("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, cx, 0.5, cy),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = z or 22,
    })
    local function bar(x, rot)
        local f = Util.create("Frame", {
            Parent = holder,
            Size = UDim2.fromOffset(9, 2),
            Position = UDim2.fromOffset(x, 8),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Rotation = rot,
            BackgroundColor3 = ThemeEngine._current[colorKey],
            BorderSizePixel = 0,
            ZIndex = z or 22,
        })
        Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
        ThemeEngine:Bind(f, "BackgroundColor3", colorKey)
    end
    bar(5, 45)
    bar(11, -45)
    return holder
end

----------------------------------------------------------------
-- Icon atlas (velt_icons.png: 8 columns x 4 rows, 64px cells, white on transparent)
-- Downloaded once from the Velt asset repo; if it is unavailable a letter badge is used instead.
----------------------------------------------------------------
local ICON_URL  = "https://raw.githubusercontent.com/erszxu-hmm/velt-assets/main/velt_icons.png"
local ICON_FILE = "velt_icons.png"
local ICON_NAMES = {
    "home", "sword", "eye", "user", "box", "filter", "bolt", "gear",
    "save", "target", "crosshair", "leaf", "pointer", "book", "pin", "sparkles",
    "list", "shield", "search", "users", "trend", "grid", "bell", "star",
    "server", "flask", "heart", "wand", "dot", "map", "play", "lock",
}
local ICON_INDEX = {}
for i, n in ipairs(ICON_NAMES) do ICON_INDEX[n] = i - 1 end

local ICON_KEYWORDS = {
    { "spot", "pin" }, { "teleport", "pin" }, { "herb", "leaf" }, { "farm", "leaf" }, { "manual", "pointer" },
    { "quest", "book" }, { "target", "target" }, { "predict", "trend" }, { "aim", "crosshair" },
    { "combat", "sword" }, { "fight", "sword" }, { "visual", "eye" }, { "esp", "eye" }, { "player", "user" },
    { "loot", "box" }, { "shop", "box" }, { "filter", "filter" }, { "movement", "bolt" }, { "move", "bolt" },
    { "speed", "bolt" }, { "setting", "gear" }, { "config", "save" }, { "class", "users" }, { "rule", "list" },
    { "world", "map" }, { "server", "server" }, { "misc", "sparkles" }, { "home", "home" }, { "main", "home" },
    { "info", "star" },
}

local function pickIcon(name, title)
    if type(name) == "string" and ICON_INDEX[name:lower()] then return name:lower() end
    local t = tostring(title or ""):lower()
    for _, kv in ipairs(ICON_KEYWORDS) do
        if t:find(kv[1], 1, true) then return kv[2] end
    end
    return "dot"
end

local iconAtlas -- nil = not tried yet, false = unavailable
local function getAtlas()
    if iconAtlas ~= nil then return iconAtlas end
    iconAtlas = false
    if Env.canFS then
        if not Env.isFile(ICON_FILE) or not pngValid(ICON_FILE) then
            pcall(function()
                local data = game:HttpGet(ICON_URL)
                if type(data) == "string" and data:sub(2, 4) == "PNG" then Env.writeFile(ICON_FILE, data) end
            end)
        end
        if Env.isFile(ICON_FILE) and Env.getAsset then
            local ok, asset = pcall(Env.getAsset, ICON_FILE)
            if ok and asset and asset ~= "" then iconAtlas = asset end
        end
    end
    return iconAtlas
end

-- returns the icon instance and the name of its color property
local function makeIcon(parent, name, size, colorKey, z, bind, fallbackText)
    local th = ThemeEngine._current
    local atlas = getAtlas()
    local idx = ICON_INDEX[name]
    if atlas and idx then
        local img = Util.create("ImageLabel", {
            Parent = parent,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(size, size),
            Image = atlas,
            ImageRectOffset = Vector2.new((idx % 8) * 64, math.floor(idx / 8) * 64),
            ImageRectSize = Vector2.new(64, 64),
            ImageColor3 = th[colorKey],
            ZIndex = z or 8,
        })
        if bind then ThemeEngine:Bind(img, "ImageColor3", colorKey) end
        return img, "ImageColor3"
    end
    local lbl = Util.create("TextLabel", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        Font = Enum.Font.GothamBold,
        TextSize = math.floor(size * 0.8),
        Text = tostring(fallbackText or "?"):sub(1, 1):upper(),
        TextColor3 = th[colorKey],
        ZIndex = z or 8,
    })
    if bind then ThemeEngine:Bind(lbl, "TextColor3", colorKey) end
    return lbl, "TextColor3"
end

----------------------------------------------------------------
-- VELT LIBRARY
----------------------------------------------------------------
local Velt = {}
Velt.__index = Velt
Velt.Version = "2.0.0"
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
    local windowTitle   = tostring(config.Title or config.Name or "Velt")
    local themeName     = config.Theme or "Sage"
    local toggleKey     = config.ToggleKey or config.MinimizeKey or Enum.KeyCode.RightShift
    local saveConfig    = config.SaveConfig or false
    local configFolder  = config.ConfigFolder or "VeltConfig"
    local baseSize      = config.Size or UDim2.new(0, 580, 0, 420)
    local minSize       = config.MinSize or Vector2.new(300, 220)
    local closeDestroys = (config.CloseAction == "Destroy")
    local windowMaid    = Maid.new()

    if type(themeName) == "string" and not Themes[themeName] then themeName = "Sage" end
    ThemeEngine:Apply(themeName, false)
    local theme = ThemeEngine._current
    local function T() return ThemeEngine._current or theme end

    -- config system (autosave + named presets)
    local cfgSys
    if saveConfig then
        cfgSys = ConfigSystem.new(configFolder, (windowTitle:gsub("[^%w]", "_")),
            { restoreToggles = config.RestoreToggles == true, autosave = config.Autosave ~= false })
        cfgSys:Load()
    end

    -- leftovers from the older library
    pcall(function()
        local old = Env.getHui():FindFirstChild("VeltUI")
        if old then old:Destroy() end
    end)

    ----------------------------------------------------------------
    -- Viewport / size helpers (phone friendly)
    ----------------------------------------------------------------
    local function viewport()
        local cam = workspace.CurrentCamera
        local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
        if v.X < 50 or v.Y < 50 then v = Vector2.new(1280, 720) end
        return v
    end

    local function clampSize(w, h)
        local v = viewport()
        local maxW, maxH = math.max(200, v.X - 16), math.max(160, v.Y - 16)
        local minW, minH = math.min(minSize.X, maxW), math.min(minSize.Y, maxH)
        return math.clamp(w, minW, maxW), math.clamp(h, minH, maxH)
    end

    local v0 = viewport()
    local curW, curH = clampSize(
        baseSize.X.Offset + baseSize.X.Scale * v0.X,
        baseSize.Y.Offset + baseSize.Y.Scale * v0.Y)
    local posX = math.floor(v0.X / 2 - curW / 2)
    local posY = math.floor(v0.Y / 2 - curH / 2)

    local function clampPos(x, y)
        local v = viewport()
        return math.clamp(x, -(curW - 90), v.X - 90), math.clamp(y, 0, v.Y - 40)
    end

    -- logo (default comes from the Velt asset repo; false disables it)
    local logoImage = resolveImage(config.Logo)

    ----------------------------------------------------------------
    -- Screen GUI + main frame
    ----------------------------------------------------------------
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

    local mainFrame = Util.create("Frame", {
        Name = "Main",
        Parent = screenGui,
        BackgroundColor3 = theme.Background,
        Size = UDim2.fromOffset(curW, curH),
        Position = UDim2.fromOffset(posX, posY),
        AnchorPoint = Vector2.new(0, 0),
        ClipsDescendants = true,
        Active = true,
    })
    ThemeEngine:Bind(mainFrame, "BackgroundColor3", "Background")
    Util.create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = mainFrame })
    Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Transparency = 0.3, Parent = mainFrame })

    -- Title bar
    local TB = 46
    local titleBar = Util.create("Frame", {
        Name = "TitleBar",
        Parent = mainFrame,
        BackgroundColor3 = theme.TitleBar,
        Size = UDim2.new(1, 0, 0, TB),
        BorderSizePixel = 0,
        ZIndex = 10,
    })
    ThemeEngine:Bind(titleBar, "BackgroundColor3", "TitleBar")
    Util.create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = titleBar })
    local tbFill = Util.create("Frame", {
        Parent = titleBar,
        BackgroundColor3 = theme.TitleBar,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        BorderSizePixel = 0,
        ZIndex = 10,
    })
    ThemeEngine:Bind(tbFill, "BackgroundColor3", "TitleBar")
    local tbLine = Util.create("Frame", {
        Parent = titleBar,
        BackgroundColor3 = theme.CardBorder,
        BackgroundTransparency = 0.35,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BorderSizePixel = 0,
        ZIndex = 11,
    })
    ThemeEngine:Bind(tbLine, "BackgroundColor3", "CardBorder")

    -- logo (image) or accent dot
    if logoImage then
        local img = Util.create("ImageLabel", {
            Parent = titleBar,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 26, 0, 26),
            Position = UDim2.new(0, 14, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Image = logoImage,
            ImageColor3 = theme.Accent,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 11,
        })
        ThemeEngine:Bind(img, "ImageColor3", "Accent")
    else
        local dot = Util.create("Frame", {
            Parent = titleBar,
            BackgroundColor3 = theme.Accent,
            Size = UDim2.new(0, 10, 0, 10),
            Position = UDim2.new(0, 20, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            ZIndex = 11,
        })
        ThemeEngine:Bind(dot, "BackgroundColor3", "Accent")
        Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
    end

    local subtitle = config.Subtitle
    local titleLabel = Util.create("TextLabel", {
        Parent = titleBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 50, 0, subtitle and 7 or 0),
        Size = UDim2.new(1, -(50 + 90), 0, subtitle and 18 or TB),
        Font = theme.FontBold,
        TextColor3 = theme.Text,
        TextSize = 14,
        Text = windowTitle,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 11,
    })
    ThemeEngine:Bind(titleLabel, "TextColor3", "Text")
    if subtitle then
        local sub = Util.create("TextLabel", {
            Parent = titleBar,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 50, 0, 25),
            Size = UDim2.new(1, -(50 + 90), 0, 14),
            Font = theme.FontLight,
            TextColor3 = theme.TextDim,
            TextSize = 10,
            Text = tostring(subtitle),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 11,
        })
        ThemeEngine:Bind(sub, "TextColor3", "TextDim")
    end

    -- window controls (glyphs are drawn from frames: font independent)
    local function makeControlBtn(kind, offsetX, hoverKey)
        local btn = Util.create("TextButton", {
            Parent = titleBar,
            BackgroundColor3 = theme.Surface,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, offsetX, 0.5, 0),
            Size = UDim2.new(0, 32, 0, 30),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 12,
        })
        Util.create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = btn })
        local bars = {}
        local function bar(rot, w)
            local f = Util.create("Frame", {
                Parent = btn,
                Size = UDim2.fromOffset(w, 2),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Rotation = rot,
                BackgroundColor3 = theme.TextDim,
                BorderSizePixel = 0,
                ZIndex = 13,
            })
            Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
            ThemeEngine:Bind(f, "BackgroundColor3", "TextDim")
            bars[#bars + 1] = f
        end
        if kind == "close" then bar(45, 13) bar(-45, 13) else bar(0, 12) end
        btn.MouseEnter:Connect(function()
            Util.tween(btn, { BackgroundTransparency = 0.4 }, 0.15)
            for _, f in ipairs(bars) do Util.tween(f, { BackgroundColor3 = T()[hoverKey] }, 0.15) end
        end)
        btn.MouseLeave:Connect(function()
            Util.tween(btn, { BackgroundTransparency = 1 }, 0.15)
            for _, f in ipairs(bars) do Util.tween(f, { BackgroundColor3 = T().TextDim }, 0.15) end
        end)
        return btn
    end

    local closeBtn = makeControlBtn("close", -22, "Error")
    local minBtn   = makeControlBtn("min", -58, "Text")

    -- drag by title bar (kept on-screen)
    do
        local dragging, dStart, sX, sY = false, nil, 0, 0
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dStart = input.Position
                sX, sY = posX, posY
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        windowMaid:Add(UserInput.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dStart
                posX, posY = clampPos(sX + d.X, sY + d.Y)
                mainFrame.Position = UDim2.fromOffset(posX, posY)
            end
        end))
    end

    ----------------------------------------------------------------
    -- Sidebar (icon rail on narrow windows) + profile card
    ----------------------------------------------------------------
    local tabs = {}
    local activeTab = nil
    local groupHeads = {}
    local isRail, twoCol = false, false

    local sidebar = Util.create("Frame", {
        Name = "Sidebar",
        Parent = mainFrame,
        BackgroundColor3 = theme.Sidebar,
        Size = UDim2.new(0, 160, 1, -TB),
        Position = UDim2.new(0, 0, 0, TB),
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    ThemeEngine:Bind(sidebar, "BackgroundColor3", "Sidebar")
    Util.create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = sidebar })
    local sbFillR = Util.create("Frame", {
        Parent = sidebar, BackgroundColor3 = theme.Sidebar, BorderSizePixel = 0, ZIndex = 5,
        Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0),
    })
    ThemeEngine:Bind(sbFillR, "BackgroundColor3", "Sidebar")
    local sbFillT = Util.create("Frame", {
        Parent = sidebar, BackgroundColor3 = theme.Sidebar, BorderSizePixel = 0, ZIndex = 5,
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 0),
    })
    ThemeEngine:Bind(sbFillT, "BackgroundColor3", "Sidebar")
    local sbLine = Util.create("Frame", {
        Parent = sidebar,
        BackgroundColor3 = theme.CardBorder,
        BackgroundTransparency = 0.45,
        Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BorderSizePixel = 0,
        ZIndex = 6,
    })
    ThemeEngine:Bind(sbLine, "BackgroundColor3", "CardBorder")

    local showCard = config.ProfileCard ~= false
    local tabContainer = Util.create("ScrollingFrame", {
        Name = "TabList",
        Parent = sidebar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 10),
        Size = UDim2.new(1, -16, 1, showCard and -74 or -20),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ZIndex = 6,
        BorderSizePixel = 0,
    })
    Util.create("UIListLayout", {
        Parent = tabContainer,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
    })

    local profileBtn, pName, pSub
    if showCard then
        profileBtn = Util.create("TextButton", {
            Name = "ProfileCard",
            Parent = sidebar,
            BackgroundColor3 = theme.Card,
            Position = UDim2.new(0, 8, 1, -60),
            Size = UDim2.new(1, -16, 0, 50),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 7,
        })
        ThemeEngine:Bind(profileBtn, "BackgroundColor3", "Card")
        Util.create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = profileBtn })
        local pStroke = Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Transparency = 0.45, Parent = profileBtn })
        ThemeEngine:Bind(pStroke, "Color", "CardBorder")

        local av = Util.create("ImageLabel", {
            Name = "Avatar",
            Parent = profileBtn,
            BackgroundColor3 = theme.Surface,
            Position = UDim2.new(0, 8, 0.5, 0),
            Size = UDim2.new(0, 32, 0, 32),
            AnchorPoint = Vector2.new(0, 0.5),
            Image = LocalPlayer and ("rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150") or "",
            ZIndex = 8,
        })
        ThemeEngine:Bind(av, "BackgroundColor3", "Surface")
        Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = av })

        pName = Util.create("TextLabel", {
            Parent = profileBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 48, 0, 9),
            Size = UDim2.new(1, -54, 0, 16),
            Font = theme.FontBold,
            TextColor3 = theme.Text,
            TextSize = 12,
            Text = LocalPlayer and LocalPlayer.DisplayName or "Player",
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 8,
        })
        ThemeEngine:Bind(pName, "TextColor3", "Text")
        pSub = Util.create("TextLabel", {
            Parent = profileBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 48, 0, 26),
            Size = UDim2.new(1, -54, 0, 14),
            Font = Enum.Font.Gotham,
            TextColor3 = theme.TextDim,
            TextSize = 10,
            Text = tostring(config.ProfileSubtitle or (cfgSys and "tap for presets" or ("velt v" .. Velt.Version))),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 8,
        })
        ThemeEngine:Bind(pSub, "TextColor3", "TextDim")
    end

    ----------------------------------------------------------------
    -- Content: page header (title + search) and pages
    ----------------------------------------------------------------
    local contentArea = Util.create("Frame", {
        Name = "Content",
        Parent = mainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 160, 0, TB),
        Size = UDim2.new(1, -160, 1, -TB),
        ClipsDescendants = true,
        ZIndex = 5,
    })

    local pageTitle = Util.create("TextLabel", {
        Name = "PageTitle",
        Parent = contentArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -170, 0, 48),
        Font = theme.FontBold,
        TextColor3 = theme.Text,
        TextSize = 17,
        Text = "",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    })
    ThemeEngine:Bind(pageTitle, "TextColor3", "Text")

    local searchFrame = Util.create("Frame", {
        Name = "Search",
        Parent = contentArea,
        BackgroundColor3 = theme.Surface,
        Position = UDim2.new(1, -12, 0, 8),
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.new(0, 150, 0, 32),
        ZIndex = 6,
    })
    ThemeEngine:Bind(searchFrame, "BackgroundColor3", "Surface")
    Util.create("UICorner", { CornerRadius = UDim.new(0, 9), Parent = searchFrame })
    local sStroke = Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Transparency = 0.5, Parent = searchFrame })
    ThemeEngine:Bind(sStroke, "Color", "CardBorder")
    local sIcon = makeIcon(searchFrame, "search", 15, "TextDim", 7, true, "?")
    sIcon.Position = UDim2.new(0, 10, 0.5, -7)
    local searchBox = Util.create("TextBox", {
        Parent = searchFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 32, 0, 0),
        Size = UDim2.new(1, -38, 1, 0),
        Font = theme.Font,
        TextColor3 = theme.Text,
        PlaceholderColor3 = theme.TextDark,
        PlaceholderText = "Search...",
        Text = "",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 7,
    })
    ThemeEngine:Bind(searchBox, "TextColor3", "Text")

    local pagesArea = Util.create("Frame", {
        Name = "Pages",
        Parent = contentArea,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 48),
        Size = UDim2.new(1, 0, 1, -48),
        ClipsDescendants = true,
        ZIndex = 5,
    })

    ----------------------------------------------------------------
    -- Layout: rail / full sidebar, one / two columns
    ----------------------------------------------------------------
    local function placeSection(tabObj, sec, idx)
        local col = (twoCol and idx % 2 == 0) and tabObj._colR or tabObj._colL
        sec._card.Parent = col
        sec._card.LayoutOrder = idx
    end

    local function layoutTab(tabObj)
        if twoCol then
            tabObj._colL.Size = UDim2.new(0.5, -5, 0, 0)
            tabObj._colR.Size = UDim2.new(0.5, -5, 0, 0)
            tabObj._colR.Position = UDim2.new(0.5, 5, 0, 0)
            tabObj._colR.Visible = true
        else
            tabObj._colL.Size = UDim2.new(1, 0, 0, 0)
            tabObj._colR.Visible = false
        end
        for i, sec in ipairs(tabObj._sections) do placeSection(tabObj, sec, i) end
    end

    local function layoutTabButton(tabObj)
        if isRail then
            tabObj._label.Visible = false
            tabObj._icon.Position = UDim2.new(0.5, -9, 0.5, -9)
        else
            tabObj._label.Visible = true
            tabObj._icon.Position = UDim2.new(0, 14, 0.5, -9)
        end
    end

    local function applyLayout()
        isRail = curW < 480
        local sw = isRail and 58 or 168
        local cw = curW - sw
        twoCol = cw >= 600
        sidebar.Size = UDim2.new(0, sw, 1, -TB)
        contentArea.Position = UDim2.new(0, sw, 0, TB)
        contentArea.Size = UDim2.new(1, -sw, 1, -TB)

        local sWidth = math.clamp(math.floor(cw * 0.38), 110, 200)
        searchFrame.Size = UDim2.new(0, sWidth, 0, 32)
        pageTitle.Size = UDim2.new(1, -(sWidth + 32), 0, 48)

        for _, g in ipairs(groupHeads) do
            g.frame.Size = UDim2.new(1, 0, 0, isRail and 10 or 26)
            g.text.Visible = not isRail
            g.line.Visible = isRail
        end
        for _, tb in ipairs(tabs) do
            layoutTabButton(tb)
            layoutTab(tb)
        end

        if profileBtn then
            local av = profileBtn:FindFirstChild("Avatar")
            if isRail then
                profileBtn.Position = UDim2.new(0, 7, 1, -54)
                profileBtn.Size = UDim2.new(1, -14, 0, 44)
                if av then av.Position = UDim2.new(0.5, -16, 0.5, 0) end
                pName.Visible = false
                pSub.Visible = false
            else
                profileBtn.Position = UDim2.new(0, 8, 1, -60)
                profileBtn.Size = UDim2.new(1, -16, 0, 50)
                if av then av.Position = UDim2.new(0, 8, 0.5, 0) end
                pName.Visible = true
                pSub.Visible = true
            end
        end
    end
    applyLayout()

    -- resize grip (bottom-right)
    local grip = Util.create("Frame", {
        Name = "ResizeGrip",
        Parent = mainFrame,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -28, 1, -28),
        Active = true,
        ZIndex = 60,
    })
    local function gline(len, c)
        local f = Util.create("Frame", {
            Parent = grip,
            Size = UDim2.fromOffset(len, 2),
            Position = UDim2.fromOffset(c, c),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Rotation = -45,
            BackgroundColor3 = theme.TextDark,
            BorderSizePixel = 0,
            ZIndex = 61,
        })
        Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
        ThemeEngine:Bind(f, "BackgroundColor3", "TextDark")
    end
    gline(14, 17)
    gline(7, 22)

    local function applySize(w, h, animate)
        curW, curH = clampSize(w, h)
        if animate then
            Util.tween(mainFrame, { Size = UDim2.fromOffset(curW, curH) }, 0.18)
        else
            mainFrame.Size = UDim2.fromOffset(curW, curH)
        end
        posX, posY = clampPos(posX, posY)
        mainFrame.Position = UDim2.fromOffset(posX, posY)
        applyLayout()
    end

    do
        local resizing, rStart, rW, rH = false, nil, 0, 0
        grip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                rStart = input.Position
                rW, rH = curW, curH
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then resizing = false end
                end)
            end
        end)
        windowMaid:Add(UserInput.InputChanged:Connect(function(input)
            if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - rStart
                applySize(rW + d.X, rH + d.Y, false)
            end
        end))
    end

    ----------------------------------------------------------------
    -- Search + tab selection
    ----------------------------------------------------------------
    local function applySearch(tabObj, q)
        q = tostring(q or ""):lower()
        for _, sec in ipairs(tabObj._sections) do
            local any = false
            local titleHit = (q ~= "") and (sec._title ~= "") and (sec._title:find(q, 1, true) ~= nil)
            for _, it in ipairs(sec._items) do
                local vis = (q == "") or titleHit or (it.text ~= "" and it.text:find(q, 1, true) ~= nil)
                it.inst.Visible = vis
                if vis then any = true end
            end
            sec._card.Visible = (q == "") or any or titleHit
            if sec._body then sec._body.Visible = (q ~= "") or not sec._collapsed end
        end
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        if activeTab then applySearch(activeTab, searchBox.Text) end
    end)

    local function paintTab(tabObj, selected)
        local th = T()
        local iprop = tabObj._iconProp
        if selected then
            Util.tween(tabObj._btn, { BackgroundTransparency = 0.86 }, 0.2)
            Util.tween(tabObj._indicator, { Size = UDim2.new(0, 3, 0, 18), BackgroundTransparency = 0 }, 0.2)
            Util.tween(tabObj._icon, { [iprop] = th.Accent }, 0.15)
            Util.tween(tabObj._label, { TextColor3 = th.Text }, 0.15)
        else
            Util.tween(tabObj._btn, { BackgroundTransparency = 1 }, 0.2)
            Util.tween(tabObj._indicator, { Size = UDim2.new(0, 3, 0, 0), BackgroundTransparency = 1 }, 0.2)
            Util.tween(tabObj._icon, { [iprop] = th.TextDim }, 0.15)
            Util.tween(tabObj._label, { TextColor3 = th.TextDim }, 0.15)
        end
    end

    local function selectTab(tabObj)
        if activeTab == tabObj then return end
        if activeTab then
            paintTab(activeTab, false)
            activeTab._page.Visible = false
        end
        activeTab = tabObj
        paintTab(tabObj, true)
        tabObj._page.Visible = true
        pageTitle.Text = tabObj._title
        if searchBox.Text ~= "" then searchBox.Text = "" else applySearch(tabObj, "") end
    end

    windowMaid:Add(ThemeEngine.Changed:Connect(function()
        for _, tb in ipairs(tabs) do paintTab(tb, tb == activeTab) end
    end))

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- Window object
    ----------------------------------------------------------------
    local window = {}
    window._gui = screenGui
    window.Gui = screenGui
    window.Main = mainFrame
    window._main = mainFrame
    window._visible = true
    window._tabs = tabs
    window.Tabs = tabs
    window.Flags = {}          -- kept for old-API scripts
    window._config = cfgSys
    window._maid = windowMaid

    ----------------------------------------------------------------
    -- Show / hide (close hides, it does not destroy)
    ----------------------------------------------------------------
    local function setVisible(state)
        window._visible = state
        if window.OnVisibility then pcall(window.OnVisibility, state) end
        if state then
            mainFrame.Visible = true
            Util.tween(mainFrame, { Size = UDim2.fromOffset(curW, curH) }, 0.28, Enum.EasingStyle.Quint)
        else
            Util.tween(mainFrame, { Size = UDim2.fromOffset(curW, 0) }, 0.22, Enum.EasingStyle.Quart)
            task.delay(0.24, function()
                if not window._visible then mainFrame.Visible = false end
            end)
        end
    end

    minBtn.MouseButton1Click:Connect(function() setVisible(false) end)
    closeBtn.MouseButton1Click:Connect(function()
        if closeDestroys then window:Destroy() else setVisible(false) end
    end)

    windowMaid:Add(UserInput.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == toggleKey then
            setVisible(not window._visible)
        end
    end))

    ----------------------------------------------------------------
    -- Floating logo button: drag to move, tap to open / close
    ----------------------------------------------------------------
    local floatBtn
    if config.FloatingButton ~= false then
        local fx, fy = 16, math.floor(v0.Y / 2 - 25)
        floatBtn = Util.create("Frame", {
            Name = "FloatingToggle",
            Parent = screenGui,
            Size = UDim2.fromOffset(50, 50),
            Position = UDim2.fromOffset(fx, fy),
            BackgroundColor3 = theme.Card,
            BorderSizePixel = 0,
            Active = true,
            ZIndex = 90,
        })
        ThemeEngine:Bind(floatBtn, "BackgroundColor3", "Card")
        Util.create("UICorner", { CornerRadius = UDim.new(0, 15), Parent = floatBtn })
        local floatStroke = Util.create("UIStroke", {
            Color = theme.Accent, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = floatBtn,
        })

        if logoImage then
            local li = Util.create("ImageLabel", {
                Parent = floatBtn,
                Size = UDim2.new(1, -18, 1, -18),
                Position = UDim2.fromOffset(9, 9),
                BackgroundTransparency = 1,
                Image = logoImage,
                ImageColor3 = theme.Accent,
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 91,
            })
            ThemeEngine:Bind(li, "ImageColor3", "Accent")
        else
            local lt = Util.create("TextLabel", {
                Parent = floatBtn,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "V",
                Font = theme.FontBold,
                TextSize = 22,
                TextColor3 = theme.Accent,
                ZIndex = 91,
            })
            ThemeEngine:Bind(lt, "TextColor3", "Accent")
        end

        window.OnVisibility = function(state)
            local th = T()
            Util.tween(floatStroke, { Color = state and th.Accent or th.AccentDark }, 0.2)
        end

        local pressing, moved, fStart, sx, sy = false, false, nil, 0, 0
        floatBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                pressing, moved = true, false
                fStart = input.Position
                sx, sy = fx, fy
                Util.tween(floatBtn, { BackgroundColor3 = T().Surface }, 0.08)
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End and pressing then
                        pressing = false
                        Util.tween(floatBtn, { BackgroundColor3 = T().Card }, 0.12)
                        if not moved then setVisible(not window._visible) end -- pure tap, not a drag
                    end
                end)
            end
        end)
        windowMaid:Add(UserInput.InputChanged:Connect(function(input)
            if pressing and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - fStart
                if not moved and d.Magnitude > 8 then moved = true end
                if moved then
                    local v = viewport()
                    fx = math.clamp(sx + d.X, 0, v.X - 50)
                    fy = math.clamp(sy + d.Y, 0, v.Y - 50)
                    floatBtn.Position = UDim2.fromOffset(fx, fy)
                end
            end
        end))
        window._floatReclamp = function()
            local v = viewport()
            fx = math.clamp(fx, 0, v.X - 50)
            fy = math.clamp(fy, 0, v.Y - 50)
            floatBtn.Position = UDim2.fromOffset(fx, fy)
        end
    else
        window.OnVisibility = function() end
    end
    window.OnVisibility(true)

    -- keep everything on screen when the viewport changes (rotation, resize)
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            windowMaid:Add(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                applySize(curW, curH, false)
                if window._floatReclamp then window._floatReclamp() end
            end))
        end
    end)

    ----------------------------------------------------------------
    -- AddTab
    ----------------------------------------------------------------
    function window:AddTab(tabConfig)
        if type(tabConfig) == "string" then tabConfig = { Title = tabConfig } end
        tabConfig = tabConfig or {}
        local tabTitle = tostring(tabConfig.Title or tabConfig.Name or "Tab")
        local order    = #tabs + 1
        local group    = tabConfig.Group

        -- optional group heading ("Main", "Other", ...) in the sidebar
        if group and group ~= window._lastGroup then
            window._lastGroup = group
            window._seq = (window._seq or 0) + 1
            local gf = Util.create("Frame", {
                Parent = tabContainer, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 26), LayoutOrder = window._seq, ZIndex = 7,
            })
            local gt = Util.create("TextLabel", {
                Parent = gf, BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -10, 1, -4),
                Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = theme.TextDark,
                Text = string.upper(tostring(group)),
                TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 8,
            })
            ThemeEngine:Bind(gt, "TextColor3", "TextDark")
            local gl = Util.create("Frame", {
                Parent = gf, BackgroundColor3 = theme.CardBorder, BackgroundTransparency = 0.3,
                Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.new(1, -12, 0, 1),
                BorderSizePixel = 0, Visible = false, ZIndex = 8,
            })
            ThemeEngine:Bind(gl, "BackgroundColor3", "CardBorder")
            groupHeads[#groupHeads + 1] = { frame = gf, text = gt, line = gl }
        end
        window._seq = (window._seq or 0) + 1

        -- Tab button
        local tabBtn = Util.create("TextButton", {
            Name = "Tab_" .. tabTitle,
            Parent = tabContainer,
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40),
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = window._seq,
            ZIndex = 7,
        })
        ThemeEngine:Bind(tabBtn, "BackgroundColor3", "Accent")
        Util.create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = tabBtn })

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

        local iconInst, iconProp = makeIcon(tabBtn, pickIcon(tabConfig.Icon, tabTitle), 18, "TextDim", 8, false, tabTitle)
        iconInst.Position = UDim2.new(0, 14, 0.5, -9)

        local tabLabel = Util.create("TextLabel", {
            Parent = tabBtn,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 44, 0, 0),
            Size = UDim2.new(1, -52, 1, 0),
            Font = theme.Font,
            TextColor3 = theme.TextDim,
            TextSize = 13,
            Text = tabTitle,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 8,
        })

        -- Content page: two columns (the right one is only used on wide windows)
        local page = Util.create("ScrollingFrame", {
            Name = "Page_" .. tabTitle,
            Parent = pagesArea,
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
            PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 16),
            PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
            Parent = page,
        })
        local holder = Util.create("Frame", {
            Parent = page, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5,
        })
        local function makeCol()
            local c = Util.create("Frame", {
                Parent = holder, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5,
            })
            Util.create("UIListLayout", { Parent = c, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })
            return c
        end
        local colL, colR = makeCol(), makeCol()
        colR.Visible = false

        local tabObj = {
            _btn = tabBtn,
            _indicator = indicator,
            _icon = iconInst,
            _iconProp = iconProp,
            _label = tabLabel,
            _page = page,
            _colL = colL,
            _colR = colR,
            _title = tabTitle,
            _order = order,
            _sections = {},
        }

        tabBtn.MouseEnter:Connect(function()
            if activeTab ~= tabObj then Util.tween(tabBtn, { BackgroundTransparency = 0.93 }, 0.15) end
        end)
        tabBtn.MouseLeave:Connect(function()
            if activeTab ~= tabObj then Util.tween(tabBtn, { BackgroundTransparency = 1 }, 0.15) end
        end)
        tabBtn.MouseButton1Click:Connect(function() selectTab(tabObj) end)

        ----------------------------------------------------------------
        -- AddSection: collapsible card with an optional header
        ----------------------------------------------------------------
        function tabObj:AddSection(secConfig)
            if type(secConfig) == "string" then secConfig = { Title = secConfig } end
            secConfig = secConfig or {}
            local secTitle = tostring(secConfig.Title or "")
            local secOrder = #self._sections + 1

            local card = Util.create("Frame", {
                Name = "Section_" .. secTitle,
                Parent = self._colL,
                BackgroundColor3 = theme.Card,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = secOrder,
                ZIndex = 6,
            })
            ThemeEngine:Bind(card, "BackgroundColor3", "Card")
            Util.create("UICorner", { CornerRadius = theme.CornerRadius, Parent = card })
            local cStroke = Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Transparency = 0.35, Parent = card })
            ThemeEngine:Bind(cStroke, "Color", "CardBorder")
            Util.create("UIListLayout", { Parent = card, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) })

            local body = Util.create("Frame", {
                Name = "Body",
                Parent = card,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 2,
                ZIndex = 7,
            })
            local bodyPad = Util.create("UIPadding", {
                PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = body,
            })
            Util.create("UIListLayout", { Parent = body, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })

            local section = {}
            local sectionFrame = body
            section._frame = card
            section._card = card
            section._body = body
            section._title = secTitle:lower()
            section._items = {}
            section._collapsed = secConfig.Collapsed == true
            section._elementCount = 0

            if secTitle ~= "" then
                local header = Util.create("TextButton", {
                    Name = "Header",
                    Parent = card,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 40),
                    Text = "",
                    AutoButtonColor = false,
                    LayoutOrder = 1,
                    ZIndex = 8,
                })
                local x0 = 14
                if secConfig.Icon then
                    local ic = makeIcon(header, pickIcon(secConfig.Icon, secTitle), 16, "Accent", 9, true, secTitle)
                    ic.Position = UDim2.new(0, 14, 0.5, -8)
                    x0 = 38
                end
                local ht = Util.create("TextLabel", {
                    Parent = header,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, x0, 0, 0),
                    Size = UDim2.new(1, -(x0 + 40), 1, 0),
                    Font = theme.FontBold,
                    TextColor3 = theme.Text,
                    TextSize = 13,
                    Text = secTitle,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 9,
                })
                ThemeEngine:Bind(ht, "TextColor3", "Text")
                local line = Util.create("Frame", {
                    Parent = header, BackgroundColor3 = theme.CardBorder, BackgroundTransparency = 0.5,
                    Position = UDim2.new(0, 14, 1, -1), Size = UDim2.new(1, -28, 0, 1), BorderSizePixel = 0, ZIndex = 9,
                })
                ThemeEngine:Bind(line, "BackgroundColor3", "CardBorder")
                if secConfig.Collapsible ~= false then
                    local chev = drawChevron(header, -22, 0, "TextDim", 9)
                    chev.Rotation = section._collapsed and -90 or 0
                    header.MouseButton1Click:Connect(function()
                        section._collapsed = not section._collapsed
                        body.Visible = not section._collapsed
                        Util.tween(chev, { Rotation = section._collapsed and -90 or 0 }, 0.18)
                    end)
                end
            else
                bodyPad.PaddingTop = UDim.new(0, 8)
            end
            body.Visible = not section._collapsed

            self._sections[secOrder] = section
            self._cur = section
            placeSection(self, section, secOrder)

            ----------------------------------------------------------------
            -- AddToggle
            ----------------------------------------------------------------
            function section:AddToggle(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local value = cfg.Default or false
                local callback = cfg.Callback or function() end
                local changed = Signal.new()

                -- the whole row is the tap target (phone friendly)
                local row = Util.create("TextButton", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Text = "",
                    AutoButtonColor = false,
                    LayoutOrder = section._elementCount,
                    ZIndex = 8,
                })
                local holder = Util.create("Frame", {
                    Parent = row, BackgroundTransparency = 1,
                    Size = UDim2.new(1, -54, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 8,
                })
                Util.create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = holder })
                Util.create("UIListLayout", { Parent = holder, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
                local tl = Util.create("TextLabel", {
                    Parent = holder, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    Font = theme.Font, TextColor3 = theme.Text, TextSize = 13,
                    Text = cfg.Title or "Toggle", TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 9,
                })
                ThemeEngine:Bind(tl, "TextColor3", "Text")
                if cfg.Description then
                    local dl = Util.create("TextLabel", {
                        Parent = holder, BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                        Font = theme.FontLight, TextColor3 = theme.TextDim, TextSize = 11,
                        Text = cfg.Description, TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 9,
                    })
                    ThemeEngine:Bind(dl, "TextColor3", "TextDim")
                end

                local track = Util.create("Frame", {
                    Parent = row,
                    BackgroundColor3 = value and theme.Accent or theme.ToggleOff,
                    Position = UDim2.new(1, 0, 0.5, 0),
                    Size = UDim2.new(0, 40, 0, 22),
                    AnchorPoint = Vector2.new(1, 0.5),
                    ZIndex = 9,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
                local knob = Util.create("Frame", {
                    Parent = track,
                    BackgroundColor3 = value and (theme.OnAccent or Color3.new(1, 1, 1)) or theme.TextDim,
                    Size = UDim2.new(0, 16, 0, 16),
                    Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    ZIndex = 10,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

                local function paint(animate)
                    local th = T()
                    local d = animate and 0.18 or 0
                    Util.tween(track, { BackgroundColor3 = value and th.Accent or th.ToggleOff }, d)
                    Util.tween(knob, {
                        Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                        BackgroundColor3 = value and (th.OnAccent or Color3.new(1, 1, 1)) or th.TextDim,
                    }, d, Enum.EasingStyle.Quart)
                end

                local function updateToggle(v, skipCb)
                    value = v and true or false
                    paint(true)
                    if not skipCb then
                        pcall(callback, value)
                        changed:Fire(value)
                    end
                end

                row.MouseButton1Click:Connect(function() updateToggle(not value) end)

                local toggle = {}
                function toggle:Set(v) updateToggle(v) end
                function toggle:Get() return value end
                function toggle:SetTitle(t) tl.Text = tostring(t) end
                toggle.OnChanged = changed

                if cfg.Flag and cfgSys then
                    cfgSys:RegisterFlag(cfg.Flag, changed, function() return value end, function(v, fire) updateToggle(v, not fire) end, "toggle")
                end
                windowMaid:Add(ThemeEngine.Changed:Connect(function() paint(true) end))
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
                    Size = UDim2.new(1, 0, 0, 54),
                    LayoutOrder = section._elementCount,
                    ZIndex = 8,
                })
                local tl = Util.create("TextLabel", {
                    Parent = row, BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, 6), Size = UDim2.new(1, -70, 0, 20),
                    Font = theme.Font, TextColor3 = theme.Text, TextSize = 13,
                    Text = cfg.Title or "Slider", TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
                })
                ThemeEngine:Bind(tl, "TextColor3", "Text")

                local valueBox = Util.create("Frame", {
                    Parent = row, BackgroundColor3 = theme.Surface,
                    Position = UDim2.new(1, 0, 0, 5), AnchorPoint = Vector2.new(1, 0),
                    Size = UDim2.new(0, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 9,
                })
                ThemeEngine:Bind(valueBox, "BackgroundColor3", "Surface")
                Util.create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = valueBox })
                local vbs = Util.create("UIStroke", { Color = theme.CardBorder, Thickness = 1, Transparency = 0.5, Parent = valueBox })
                ThemeEngine:Bind(vbs, "Color", "CardBorder")
                Util.create("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = valueBox })
                local valueLabel = Util.create("TextLabel", {
                    Parent = valueBox, BackgroundTransparency = 1,
                    Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
                    Font = theme.FontBold, TextColor3 = theme.Accent, TextSize = 12,
                    Text = tostring(Util.round(value, 2)) .. suffix, ZIndex = 10,
                })
                ThemeEngine:Bind(valueLabel, "TextColor3", "Accent")

                local trackFrame = Util.create("Frame", {
                    Parent = row, BackgroundColor3 = theme.SliderTrack,
                    Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 6), ZIndex = 9,
                })
                ThemeEngine:Bind(trackFrame, "BackgroundColor3", "SliderTrack")
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = trackFrame })
                local p0 = (max > min) and ((value - min) / (max - min)) or 0
                local fillFrame = Util.create("Frame", {
                    Parent = trackFrame, BackgroundColor3 = theme.Accent,
                    Size = UDim2.new(p0, 0, 1, 0), ZIndex = 10,
                })
                ThemeEngine:Bind(fillFrame, "BackgroundColor3", "Accent")
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fillFrame })
                local sliderKnob = Util.create("Frame", {
                    Parent = trackFrame, BackgroundColor3 = Color3.new(1, 1, 1),
                    Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(p0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11,
                })
                Util.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sliderKnob })
                local ks = Util.create("UIStroke", { Color = theme.Accent, Thickness = 2, Transparency = 0.15, Parent = sliderKnob })
                ThemeEngine:Bind(ks, "Color", "Accent")

                -- generous invisible hit area around the thin track
                local hit = Util.create("TextButton", {
                    Parent = row, BackgroundTransparency = 1, Text = "",
                    Position = UDim2.new(0, -6, 0, 28), Size = UDim2.new(1, 12, 0, 26), ZIndex = 12,
                })
                local sliding = false
                local function render()
                    local p = (max > min) and ((value - min) / (max - min)) or 0
                    fillFrame.Size = UDim2.new(p, 0, 1, 0)
                    sliderKnob.Position = UDim2.new(p, 0, 0.5, 0)
                    valueLabel.Text = tostring(Util.round(value, 2)) .. suffix
                end
                local function updateSlider(input)
                    local absPos = trackFrame.AbsolutePosition.X
                    local absSize = math.max(1, trackFrame.AbsoluteSize.X)
                    local relX = Util.clamp((input.Position.X - absPos) / absSize, 0, 1)
                    local raw = min + (max - min) * relX
                    value = Util.clamp(Util.round(raw / increment) * increment, min, max)
                    render()
                    pcall(callback, value)
                    changed:Fire(value)
                end
                hit.InputBegan:Connect(function(input)
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
                    render()
                end
                function slider:Get() return value end
                slider.OnChanged = changed

                if cfg.Flag and cfgSys then
                    cfgSys:RegisterFlag(cfg.Flag, changed, function() return value end, function(v, fire) if type(v) == "number" then slider:Set(v); if fire then pcall(callback, value) end end end)
                end
                return slider
            end

            ----------------------------------------------------------------
            -- AddButton   (Style = "Default" | "Primary" | "Danger")
            ----------------------------------------------------------------
            function section:AddButton(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local callback = cfg.Callback or function() end
                local style = cfg.Style or "Default"
                local bgKey = (style == "Primary") and "Accent" or "Surface"
                local hoverKey = (style == "Primary") and "AccentHover" or "SurfaceHover"
                local txtKey = (style == "Primary") and "OnAccent" or ((style == "Danger") and "Error" or "Text")

                local btn = Util.create("TextButton", {
                    Parent = sectionFrame,
                    BackgroundColor3 = theme[bgKey],
                    Size = UDim2.new(1, 0, 0, 38),
                    Text = "",
                    AutoButtonColor = false,
                    LayoutOrder = section._elementCount,
                    ClipsDescendants = true,
                    ZIndex = 8,
                })
                ThemeEngine:Bind(btn, "BackgroundColor3", bgKey)
                Util.create("UICorner", { CornerRadius = UDim.new(0, 9), Parent = btn })
                local bs = Util.create("UIStroke", {
                    Color = (style == "Danger") and theme.Error or theme.CardBorder,
                    Thickness = 1, Transparency = (style == "Primary") and 1 or 0.45, Parent = btn,
                })
                ThemeEngine:Bind(bs, "Color", (style == "Danger") and "Error" or "CardBorder")

                local lbl = Util.create("TextLabel", {
                    Parent = btn, BackgroundTransparency = 1,
                    Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -44, 1, 0),
                    Font = theme.FontBold, TextSize = 13,
                    TextColor3 = theme[txtKey] or Color3.new(1, 1, 1),
                    Text = cfg.Title or "Button", TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
                })
                ThemeEngine:Bind(lbl, "TextColor3", txtKey, function(v) return v or Color3.new(1, 1, 1) end)
                local chev = drawChevron(btn, -20, 0, (style == "Primary") and "OnAccent" or "TextDim", 9)
                chev.Rotation = -90

                btn.MouseEnter:Connect(function() Util.tween(btn, { BackgroundColor3 = T()[hoverKey] }, 0.15) end)
                btn.MouseLeave:Connect(function() Util.tween(btn, { BackgroundColor3 = T()[bgKey] }, 0.15) end)
                btn.MouseButton1Click:Connect(function()
                    createRipple(btn, nil)
                    pcall(callback)
                end)

                local button = {}
                function button:SetTitle(t) lbl.Text = tostring(t) end
                return button
            end

            ----------------------------------------------------------------
            -- AddStats: grid of value/label tiles   (Items = {{Id=,Value=,Label=}}, Columns = 3)
            ----------------------------------------------------------------
            function section:AddStats(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local items = cfg.Items or {}
                local cols = math.max(1, cfg.Columns or 3)
                local rows = math.max(1, math.ceil(#items / cols))
                local cellH, gap = 52, 8

                local grid = Util.create("Frame", {
                    Parent = sectionFrame, BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, rows * cellH + (rows - 1) * gap + 6),
                    LayoutOrder = section._elementCount, ZIndex = 8,
                })
                Util.create("UIPadding", { PaddingTop = UDim.new(0, 4), Parent = grid })
                Util.create("UIGridLayout", {
                    Parent = grid,
                    CellSize = UDim2.new(1 / cols, -(cols - 1) * gap / cols, 0, cellH),
                    CellPadding = UDim2.fromOffset(gap, gap),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                })
                local refs = {}
                for i, it in ipairs(items) do
                    local tile = Util.create("Frame", {
                        Parent = grid, BackgroundColor3 = theme.Surface, LayoutOrder = i, ZIndex = 9,
                    })
                    ThemeEngine:Bind(tile, "BackgroundColor3", "Surface")
                    Util.create("UICorner", { CornerRadius = UDim.new(0, 9), Parent = tile })
                    local vl = Util.create("TextLabel", {
                        Parent = tile, BackgroundTransparency = 1,
                        Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(1, -20, 0, 20),
                        Font = theme.FontBold, TextSize = 15, TextColor3 = theme.Text,
                        Text = tostring(it.Value or "-"), TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
                    })
                    ThemeEngine:Bind(vl, "TextColor3", "Text")
                    local ll = Util.create("TextLabel", {
                        Parent = tile, BackgroundTransparency = 1,
                        Position = UDim2.new(0, 10, 0, 29), Size = UDim2.new(1, -20, 0, 14),
                        Font = theme.FontLight, TextSize = 10, TextColor3 = theme.TextDim,
                        Text = tostring(it.Label or ""), TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
                    })
                    ThemeEngine:Bind(ll, "TextColor3", "TextDim")
                    refs[it.Id or i] = { value = vl, label = ll }
                end
                local obj = {}
                function obj:Set(id, v) local r = refs[id]; if r then r.value.Text = tostring(v) end end
                function obj:SetLabel(id, t) local r = refs[id]; if r then r.label.Text = tostring(t) end end
                return obj
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
                    cfgSys:RegisterFlag(cfg.Flag, changed, function() return value end, function(v, fire) input:Set(v); if fire then pcall(callback, value) end end)
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
                    Size = UDim2.new(1, 0, 0, 54),
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
                    Size = UDim2.new(1, 0, 0, 32),
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

                local arrowHolder = drawChevron(dropBtn, -10, 0, "TextDim", 22)
                local arrowLabel = {}
                local function setArrow(open, h)
                    Util.tween(arrowHolder, { Rotation = open and 180 or 0 }, 0.18)
                    row.Size = UDim2.new(1, 0, 0, open and (64 + (h or 0)) or 54)
                end

                -- Dropdown list
                local dropList = Util.create("Frame", {
                    Parent = row,
                    BackgroundColor3 = theme.Card,
                    Position = UDim2.new(0, 0, 0, 58),
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
                                setArrow(false)
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
                        setArrow(true, h)
                    else
                        Util.tween(dropList, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                        task.delay(0.15, function() dropList.Visible = false end)
                        setArrow(false)
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
                    cfgSys:RegisterFlag(cfg.Flag, changed, function() return value end, function(v, fire) dropdown:Set(v); if fire then pcall(callback, value) end end)
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
                    cfgSys:RegisterFlag(cfg.Flag, changed,
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
                    cfgSys:RegisterFlag(cfg.Flag, changed,
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
            function section:AddText(cfg)
                cfg = cfg or {}
                section._elementCount = section._elementCount + 1
                local label = Util.create("TextLabel", {
                    Parent = sectionFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Font = theme.FontLight,
                    TextColor3 = theme.TextDim,
                    TextSize = 12,
                    Text = tostring(cfg.Text or cfg.Title or ""),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    LayoutOrder = section._elementCount,
                    ZIndex = 8,
                })
                ThemeEngine:Bind(label, "TextColor3", "TextDim")
                local obj = {}
                function obj:Set(t) label.Text = tostring(t) end
                function obj:SetText(t) label.Text = tostring(t) end
                function obj:Get() return label.Text end
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

            -- register elements for the page search
            for _, m in ipairs({ "AddToggle", "AddSlider", "AddDropdown", "AddButton", "AddInput", "AddKeybind",
                                 "AddColorPicker", "AddLabel", "AddParagraph", "AddText", "AddDivider",
                                 "AddProgressbar", "AddStats" }) do
                local orig = section[m]
                if orig then
                    section[m] = function(self2, cfg2)
                        local el = orig(self2, cfg2)
                        local inst
                        for _, c in ipairs(body:GetChildren()) do
                            if c:IsA("GuiObject") and c.LayoutOrder == section._elementCount then inst = c end
                        end
                        if inst then
                            local c2 = type(cfg2) == "table" and cfg2 or {}
                            local txt = string.lower(tostring(c2.Title or c2.Name or c2.Text or "") .. " " .. tostring(c2.Description or c2.Content or ""))
                            section._items[#section._items + 1] = { inst = inst, text = (m == "AddDivider") and "" or txt }
                        end
                        return el
                    end
                end
            end

            return section
        end

        ----------------------------------------------------------------
        -- Tab helpers + flat (v0 style) API
        --   tab:AddToggle{Name=..}  -> goes into the tab's current section
        ----------------------------------------------------------------
        tabObj.Page = page
        function tabObj:Select() selectTab(tabObj) end

        function tabObj:Clear()
            for _, sec in ipairs(self._sections) do
                if sec._card then sec._card:Destroy() end
            end
            self._sections = {}
            self._cur = nil
            if activeTab == self and searchBox.Text ~= "" then searchBox.Text = "" end
        end

        local function norm(o)
            if type(o) == "string" then o = { Title = o } end
            local n = {}
            for k, v in pairs(o or {}) do n[k] = v end
            if n.Title == nil then n.Title = n.Name end
            if n.Increment == nil then n.Increment = n.Step end
            return n
        end

        local function curSection(self)
            if not self._cur then self:AddSection({ Title = "" }) end
            return self._cur
        end

        local flagged = { AddToggle = true, AddSlider = true, AddDropdown = true,
                          AddInput = true, AddKeybind = true, AddColorPicker = true }
        for _, m in ipairs({ "AddToggle", "AddSlider", "AddDropdown", "AddButton", "AddInput",
                             "AddKeybind", "AddColorPicker", "AddParagraph", "AddProgressbar", "AddText", "AddStats" }) do
            tabObj[m] = function(self, o)
                o = norm(o)
                if flagged[m] and cfgSys and o.Flag == nil and not o.NoSave then
                    o.Flag = tabTitle .. "/" .. tostring(o.Title)
                end
                if o.Flag == false or o.NoSave then o.Flag = nil end
                local sec = curSection(self)
                local el = sec[m](sec, o)
                -- v0 behaviour: a toggle created ON reports it to its callback
                if m == "AddToggle" and o.Default and o.Callback then task.spawn(o.Callback, true) end
                return el
            end
        end

        -- v0 AddLabel(text) was a wrapping text line with :Set(text)
        function tabObj:AddLabel(o)
            if type(o) == "table" then o = o.Title or o.Text or o.Name end
            local sec = curSection(self)
            return sec:AddText({ Text = tostring(o or "") })
        end
        function tabObj:AddDivider()
            local sec = curSection(self)
            return sec:AddDivider()
        end

        tabs[#tabs + 1] = tabObj
        layoutTabButton(tabObj)
        layoutTab(tabObj)

        -- auto-select first tab
        if #tabs == 1 then
            selectTab(tabObj)
        end

        return tabObj
    end

    ----------------------------------------------------------------
    -- Window Methods
    ----------------------------------------------------------------
    window._themeName = themeName
    function window:SetTheme(name)
        if type(name) == "string" and not Themes[name] then return end
        if type(name) == "string" then window._themeName = name end
        ThemeEngine:Apply(name, true)
    end

    function window:Notify(cfg)
        if type(cfg) == "string" then cfg = { Content = cfg } end
        notify(cfg)
    end

    function window:Toggle() setVisible(not window._visible) end
    function window:Show() if not window._visible then setVisible(true) end end
    function window:Hide() if window._visible then setVisible(false) end end
    function window:Minimize() setVisible(not window._visible) end
    function window:IsVisible() return window._visible end

    -- SetSize(w, h) / SetSize(UDim2) / SetSize(Vector2)
    function window:SetSize(w, h)
        if type(w) ~= "number" then
            local ok, a, b = pcall(function()
                local x = w.X
                if type(x) == "number" then return x, w.Y end
                return x.Offset, w.Y.Offset
            end)
            if not ok then return end
            w, h = a, b
        end
        if type(w) ~= "number" or type(h) ~= "number" then return end
        applySize(w, h, window._visible)
    end
    function window:GetSize() return Vector2.new(curW, curH) end

    function window:SetTitle(t)
        windowTitle = tostring(t)
        titleLabel.Text = windowTitle
    end

    -- config: autosave + named presets (needs SaveConfig = true)
    function window:SaveConfig(name)
        if not cfgSys then return false end
        if name then return cfgSys:SavePreset(name) end
        return cfgSys:Save()
    end
    function window:LoadConfig(name)
        if not cfgSys then return false end
        if name then return cfgSys:LoadPreset(name) end
        cfgSys:Load()
        cfgSys:Apply(cfgSys.data)
        return true
    end
    function window:ListConfigs() return cfgSys and cfgSys:ListPresets() or {} end
    function window:DeleteConfig(name) if cfgSys then cfgSys:DeletePreset(name) end end

    local configTab
    function window:AddConfigTab()
        if configTab then selectTab(configTab) return configTab end
        configTab = window:AddTab({ Title = "Config" })
        if not cfgSys then
            local s = configTab:AddSection({ Title = "Config" })
            s:AddText({ Text = "Config saving is off for this script (SaveConfig = false)." })
            return configTab
        end
        do
            local names = Velt:GetThemes()
            table.sort(names)
            local ap = configTab:AddSection({ Title = "Appearance", Icon = "sparkles" })
            ap:AddDropdown({ Title = "Theme", Options = names, Default = window._themeName,
                Callback = function(v) window:SetTheme(v) end })
        end
        local sec = configTab:AddSection({ Title = "Presets", Icon = "save" })
        local typed, picked = "", nil
        local dd
        local function refresh()
            if not dd then return end
            dd:Clear()
            for _, n in ipairs(cfgSys:ListPresets()) do dd:Add(n) end
        end
        sec:AddInput({ Title = "New preset name", Placeholder = "my preset", Callback = function(v) typed = v end })
        sec:AddButton({ Title = "Save as new preset", Callback = function()
            if cfgSys:SavePreset(typed) then
                window:Notify({ Title = "Config", Content = "Saved \"" .. cfgSys.CleanName(typed) .. "\"", Type = "Success" })
                refresh()
            else
                window:Notify({ Title = "Config", Content = "Type a preset name first.", Type = "Warning" })
            end
        end })
        dd = sec:AddDropdown({ Title = "Saved presets", Options = cfgSys:ListPresets(), Searchable = true,
            Callback = function(v) picked = v end })
        sec:AddButton({ Title = "Load selected", Callback = function()
            if picked and cfgSys:LoadPreset(picked) then
                window:Notify({ Title = "Config", Content = "Loaded \"" .. picked .. "\"", Type = "Success" })
            else
                window:Notify({ Title = "Config", Content = "Pick a preset in the list first.", Type = "Warning" })
            end
        end })
        sec:AddButton({ Title = "Overwrite selected", Callback = function()
            if picked and cfgSys:SavePreset(picked) then
                window:Notify({ Title = "Config", Content = "Saved \"" .. picked .. "\"", Type = "Success" })
            else
                window:Notify({ Title = "Config", Content = "Pick a preset in the list first.", Type = "Warning" })
            end
        end })
        sec:AddButton({ Title = "Delete selected", Callback = function()
            if picked then
                cfgSys:DeletePreset(picked)
                window:Notify({ Title = "Config", Content = "Deleted \"" .. picked .. "\"", Type = "Info" })
                picked = nil
                refresh()
            else
                window:Notify({ Title = "Config", Content = "Pick a preset in the list first.", Type = "Warning" })
            end
        end })
        sec:AddButton({ Title = "Refresh list", Callback = refresh })
        return configTab
    end
    function window:OpenConfig()
        local t = window:AddConfigTab()
        selectTab(t)
        window:Show()
    end

    if profileBtn then
        profileBtn.MouseButton1Click:Connect(function() window:OpenConfig() end)
    end

    function window:Destroy()
        if cfgSys then cfgSys:Save() end
        windowMaid:Cleanup()
    end

    function window:AddTheme(name, themeTable)
        ThemeEngine:Register(name, themeTable)
    end

    -- Store reference for cleanup on reload
    if Env.isExploit then
        pcall(function() getgenv()._VeltInstance = window end)
    end

    -- Intro animation
    mainFrame.Size = UDim2.fromOffset(curW, 0)
    task.spawn(function()
        task.wait(0.05)
        Util.tween(mainFrame, { Size = UDim2.fromOffset(curW, curH) }, 0.35, Enum.EasingStyle.Quint)
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
