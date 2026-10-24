-- LumenVelt: Lumen UI exposed through the Velt API (single file: Lumen bundle + adapter)
local Lumen = (function()
-- Lumen UI 1.0.0 (single-file bundle). Usage: local Lumen = loadstring(readfile("Lumen.bundle.lua"))()
local __methods = {}
function __methods.WaitForChild(self, name)
	local c = rawget(self, "_kids")[name]
	if not c then error("Lumen bundle: missing module '" .. tostring(name) .. "'", 2) end
	return c
end
function __methods.FindFirstChild(self, name) return rawget(self, "_kids")[name] end
local __NodeMT = {}
__NodeMT.__index = function(self, k)
	local m = __methods[k]
	if m then return m end
	return rawget(self, "_kids")[k]
end
local function __node(name, parent)
	local n = setmetatable({ Name = name, Parent = parent, _kids = {} }, __NodeMT)
	if parent then rawget(parent, "_kids")[name] = n end
	return n
end
local __realRequire = require
local function __require(n)
	if type(n) ~= "table" or not rawget(n, "_kids") then return __realRequire(n) end
	if not rawget(n, "_loaded") then
		n._loaded = true
		n._value = n._fn(n, __require)
	end
	return n._value
end
local __root = __node("Lumen")
local __core = __node("Core", __root)
local __comp = __node("Components", __root)

__node("Animation", __core)
__node("Config", __core)
__node("Container", __core)
__node("Drag", __core)
__node("Focus", __core)
__node("Maid", __core)
__node("Notifications", __core)
__node("Pool", __core)
__node("Signal", __core)
__node("Theme", __core)
__node("Tooltip", __core)
__node("Util", __core)
__node("Window", __core)
__node("Basic", __comp)
__node("Button", __comp)
__node("Checkbox", __comp)
__node("ColorPicker", __comp)
__node("Dropdown", __comp)
__node("Element", __comp)
__node("ProgressBar", __comp)
__node("RadioGroup", __comp)
__node("Slider", __comp)
__node("TabGroup", __comp)
__node("Textbox", __comp)
__node("Toggle", __comp)
__node("Widgets", __comp)

-- ===== Core/Animation =====
rawget(__core, "_kids")["Animation"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Animation
	- Animation.Tween: TweenService wrapper (cached TweenInfo, per-property cancel, reduced-motion aware)
	- Animation.Number: custom numeric animation on ONE shared Heartbeat connection
	- Animation.Easing: pure easing functions (t in 0..1)
]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Animation = {}
Animation.Enabled = true
Animation.DefaultStyle = Enum.EasingStyle.Quint
Animation.DefaultDirection = Enum.EasingDirection.Out

local E = {}
E.Linear = function(t) return t end
E.QuadIn = function(t) return t * t end
E.QuadOut = function(t) return 1 - (1 - t) * (1 - t) end
E.QuadInOut = function(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end
E.CubicIn = function(t) return t * t * t end
E.CubicOut = function(t) return 1 - (1 - t) ^ 3 end
E.CubicInOut = function(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end
E.QuartOut = function(t) return 1 - (1 - t) ^ 4 end
E.ExpoOut = function(t) return t >= 1 and 1 or 1 - 2 ^ (-10 * t) end
E.SineInOut = function(t) return -(math.cos(math.pi * t) - 1) / 2 end
E.BackOut = function(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
E.ElasticOut = function(t)
	if t <= 0 then return 0 end
	if t >= 1 then return 1 end
	return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
end
Animation.Easing = E

local infoCache = {}
local running = setmetatable({}, { __mode = "k" }) -- inst -> { prop -> record }

--- Tweens properties of an Instance. Snaps instantly when duration <= 0 or animations are disabled.
-- @param inst Instance
-- @param goal table property -> value
-- @param duration number|nil seconds (default 0.2)
-- @param style Enum.EasingStyle|nil
-- @param direction Enum.EasingDirection|nil
-- @return Tween|nil
function Animation.Tween(inst, goal, duration, style, direction)
	duration = duration or 0.2
	if not Animation.Enabled or duration <= 0 then
		for prop, value in pairs(goal) do
			inst[prop] = value
		end
		return nil
	end
	style = style or Animation.DefaultStyle
	direction = direction or Animation.DefaultDirection
	local key = duration .. "|" .. tostring(style) .. "|" .. tostring(direction)
	local info = infoCache[key]
	if not info then
		info = TweenInfo.new(duration, style, direction)
		infoCache[key] = info
	end

	local active = running[inst]
	if not active then
		active = {}
		running[inst] = active
	end
	-- cancel overlapping tweens; snap their non-overlapping props to the end value so nothing freezes mid-way
	for prop in pairs(goal) do
		local rec = active[prop]
		if rec then
			rec.tween:Cancel()
			for p, v in pairs(rec.goal) do
				if active[p] == rec then
					active[p] = nil
				end
				if goal[p] == nil then
					inst[p] = v
				end
			end
		end
	end

	local tween = TweenService:Create(inst, info, goal)
	local rec = { tween = tween, goal = goal }
	for prop in pairs(goal) do
		active[prop] = rec
	end
	tween.Completed:Once(function()
		for prop in pairs(goal) do
			if active[prop] == rec then
				active[prop] = nil
			end
		end
	end)
	tween:Play()
	return tween
end

--- Cancels running tweens of an instance (leaves values where they are).
function Animation.Stop(inst)
	local active = running[inst]
	if active then
		for _, rec in pairs(active) do
			rec.tween:Cancel()
		end
		running[inst] = nil
	end
end

-- shared Heartbeat loop ------------------------------------------------------
local active = {}
local conn

local function step(dt)
	for i = #active, 1, -1 do
		local a = active[i]
		if a.cancelled then
			table.remove(active, i)
		else
			a.t = a.t + dt
			local alpha = math.min(a.t / a.duration, 1)
			a.update(a.from + (a.to - a.from) * a.easing(alpha))
			if alpha >= 1 then
				a.cancelled = true
				table.remove(active, i)
				if a.onDone then
					a.onDone()
				end
			end
		end
	end
	if #active == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end

--- Animates a number with a custom easing; all running animations share one Heartbeat connection.
-- @param from number
-- @param to number
-- @param duration number seconds
-- @param easing string|function name in Animation.Easing or function(t)
-- @param update function(value)
-- @param onDone function|nil
-- @return table handle with :Cancel()
function Animation.Number(from, to, duration, easing, update, onDone)
	if type(easing) == "string" then
		easing = E[easing] or E.CubicOut
	end
	if not Animation.Enabled or duration <= 0 then
		update(to)
		if onDone then onDone() end
		return { Cancel = function() end }
	end
	local a = { from = from, to = to, duration = duration, easing = easing or E.CubicOut, update = update, onDone = onDone, t = 0 }
	table.insert(active, a)
	if not conn then
		conn = RunService.Heartbeat:Connect(step)
	end
	return {
		Cancel = function()
			a.cancelled = true
		end,
	}
end

return Animation

end


-- ===== Core/Config =====
rawget(__core, "_kids")["Config"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Config
	Default configuration. Override at runtime with Lumen:Configure({ ... }) (deep-merged).
]]
return {
	Theme = "Dark",
	DisplayOrder = 100,

	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	FontMono = Enum.Font.RobotoMono,
	TextSize = 14,
	TextSizeSmall = 12,
	TextSizeTitle = 16,

	Radius = 8,
	RadiusSmall = 6,
	Padding = 12,
	ElementHeight = 36,
	TouchExtraHeight = 6, -- added to ElementHeight on touch-only devices
	ElementGap = 6,

	Animation = {
		Enabled = true, -- false = reduced motion (everything snaps)
		Fast = 0.12,
		Normal = 0.22,
		Slow = 0.35,
		Style = Enum.EasingStyle.Quint,
		Direction = Enum.EasingDirection.Out,
	},

	Window = {
		Size = UDim2.fromOffset(580, 400),
		MinSize = Vector2.new(380, 260),
		MaxSize = Vector2.new(1200, 900),
		TitleBarHeight = 42,
		SidebarWidth = 150,
		CompactSidebarWidth = 56,
		CompactBelow = 470, -- window width under which the sidebar collapses to icons
		Blur = true,
		BlurSize = 12,
		Shadow = true,
		ToggleKey = Enum.KeyCode.RightShift,
	},

	-- 9-slice drop shadow. Swap the asset id if you prefer another one.
	Shadow = {
		Image = "rbxassetid://6014261993",
		Slice = Rect.new(49, 49, 450, 450),
		Transparency = 0.55,
		Spread = 26,
	},

	Notification = {
		Position = "BottomRight", -- TopLeft | TopRight | TopCenter | BottomLeft | BottomRight | BottomCenter
		Width = 300,
		Duration = 4,
		Max = 5,
		PoolSize = 8,
	},

	Tooltip = { Delay = 0.35, MaxWidth = 240 },

	Keyboard = { Enabled = true, EngageKey = Enum.KeyCode.Tab },

	Icons = {}, -- name -> "rbxassetid://..."; Lumen:RegisterIcons() fills this
}

end


-- ===== Core/Container =====
rawget(__core, "_kids")["Container"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Container
	Base class for anything that hosts elements (Tab, TabGroup page).
	Every Add* method is protected: a bad prop table logs a clear warning and returns an inert
	null-object instead of crashing the calling script.
]]
local Container = {}
Container.__index = Container

-- inert object: any chain of indexing/calling returns itself
local Null
Null = setmetatable({}, {
	__index = function() return Null end,
	__call = function() return Null end,
})
Container.Null = Null

--- Creates a subclass that inherits all Add* methods. @return table class
function Container.extend()
	local class = {}
	class.__index = class
	setmetatable(class, { __index = Container })
	return class
end

--- @param ctx table @param window table @param frame GuiObject element parent
-- @param scope any keyboard-focus scope key
-- @return Container
function Container.new(ctx, window, frame, scope)
	return setmetatable({ Ctx = ctx, Window = window, Frame = frame, Scope = scope, _order = 0 }, Container)
end

function Container:_nextOrder()
	self._order = self._order + 1
	return self._order
end

function Container:_add(name, props)
	local comp = self.Ctx.Components[name]
	local ok, result = xpcall(comp.new, function(e)
		return debug.traceback(tostring(e), 2)
	end, self, props)
	if not ok then
		warn(string.format("[Lumen] could not create %s: %s", name, tostring(result)))
		return Null
	end
	if self.Window and self.Window.Elements then
		self.Window.Elements[result] = true
	end
	return result
end

local function asProps(v, key)
	if type(v) == "table" then return v end
	return { [key] = v }
end

--- Adds a Button. @param props table { Text, Style="Solid"|"Outline"|"Gradient"|"Ghost", Callback, Color, Tooltip } @return Button
function Container:AddButton(props) return self:_add("Button", asProps(props, "Text")) end
--- Adds a Toggle switch. @param props table { Text, Default, Callback, Tooltip } @return Toggle
function Container:AddToggle(props) return self:_add("Toggle", asProps(props, "Text")) end
--- Adds a Checkbox. @param props table { Text, Default, Color, Callback } @return Checkbox
function Container:AddCheckbox(props) return self:_add("Checkbox", asProps(props, "Text")) end
--- Adds a Radio group. @param props table { Text, Options, Default, Callback } @return RadioGroup
function Container:AddRadioGroup(props) return self:_add("RadioGroup", asProps(props, "Text")) end
--- Adds a Slider. @param props table { Text, Min, Max, Default, Step, Suffix, Orientation, Height, Callback } @return Slider
function Container:AddSlider(props) return self:_add("Slider", asProps(props, "Text")) end
--- Adds a Textbox. @param props table { Text, Placeholder, Default, Password, Validate, Pattern, Numeric, Callback } @return Textbox
function Container:AddTextbox(props) return self:_add("Textbox", asProps(props, "Text")) end
--- Adds a Dropdown. @param props table { Text, Options, Default, Multi, Searchable, Callback } @return Dropdown
function Container:AddDropdown(props) return self:_add("Dropdown", asProps(props, "Text")) end
--- Adds a ColorPicker. @param props table { Text, Default, Gradient, Callback } @return ColorPicker
function Container:AddColorPicker(props) return self:_add("ColorPicker", asProps(props, "Text")) end
--- Adds a ProgressBar. @param props table { Text, Value, Min, Max, Style="Linear"|"Circular", Animated } @return ProgressBar
function Container:AddProgressBar(props) return self:_add("ProgressBar", asProps(props, "Text")) end
--- Adds a text label. @param props string|table { Text, Muted } @return Label
function Container:AddLabel(props) return self:_add("Label", asProps(props, "Text")) end
--- Adds a section header. @param props string|table { Text } @return Section
function Container:AddSection(props) return self:_add("Section", asProps(props, "Text")) end
--- Adds a thin divider line. @return Divider
function Container:AddDivider() return self:_add("Divider", {}) end
--- Adds a nested tab group. @param props table { Tabs = {"A","B"}, Default = 1 } @return TabGroup (.Tabs[name|index] are containers)
function Container:AddTabGroup(props) return self:_add("TabGroup", props) end

return Container

end


-- ===== Core/Drag =====
rawget(__core, "_kids")["Drag"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Drag
	Press-and-drag helper. The InputChanged/InputEnded connections exist ONLY while a drag is active.
]]
local UserInputService = game:GetService("UserInputService")

local Drag = {}
Drag.__index = Drag

--- Attaches drag behavior to a GuiObject.
-- @param gui GuiObject
-- @param handlers table { Began=fn(input), Changed=fn(input), Ended=fn(input), CanBegin=fn()->boolean }
-- @return Drag object with :Destroy()
function Drag.Attach(gui, handlers)
	local self = setmetatable({ Active = false }, Drag)

	local function stop(input)
		if not self.Active then
			return
		end
		self.Active = false
		if self._move then self._move:Disconnect() self._move = nil end
		if self._end then self._end:Disconnect() self._end = nil end
		if handlers.Ended then handlers.Ended(input) end
	end

	self._began = gui.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if self.Active then
			return
		end
		if handlers.CanBegin and not handlers.CanBegin() then
			return
		end
		self.Active = true
		if handlers.Began then handlers.Began(input) end
		self._move = UserInputService.InputChanged:Connect(function(i)
			if (kind == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseMovement)
				or (kind == Enum.UserInputType.Touch and i == input) then
				if handlers.Changed then handlers.Changed(i) end
			end
		end)
		self._end = UserInputService.InputEnded:Connect(function(i)
			if i == input or (kind == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseButton1) then
				stop(i)
			end
		end)
	end)
	return self
end

--- Disconnects everything.
function Drag:Destroy()
	self.Active = false
	if self._began then self._began:Disconnect() self._began = nil end
	if self._move then self._move:Disconnect() self._move = nil end
	if self._end then self._end:Disconnect() self._end = nil end
end

return Drag

end


-- ===== Core/Focus =====
rawget(__core, "_kids")["Focus"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Focus
	Keyboard navigation per window.
	Press the engage key (default Tab) while the window is visible:
	  Up/Down or Tab/Shift+Tab = move, Left/Right = adjust, Enter/Space = activate, Esc = leave.
	While engaged, navigation keys are sunk (ContextActionService) so the game does not also react.
]]
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Util = require(script.Parent.Util)

local Focus = {}
Focus.__index = Focus

local ACTION = "LumenNavigate"

--- @param ctx table library context
-- @param window table owning window (needs .Visible)
-- @return Focus
function Focus.new(ctx, window)
	local self = setmetatable({}, Focus)
	self.Ctx = ctx
	self.Window = window
	self.Engaged = false
	self._scopes = {}
	self._scope = nil
	self._current = nil
	self._conn = UserInputService.InputBegan:Connect(function(input)
		local kb = ctx.Config.Keyboard
		if not kb.Enabled or self.Engaged or not window.Visible or window.Minimized then
			return
		end
		if input.KeyCode == kb.EngageKey and UserInputService:GetFocusedTextBox() == nil then
			self:Engage()
		end
	end)
	return self
end

--- Registers a focusable item in a scope (usually a tab).
-- @param scope any scope key
-- @param item table { Root, Label, Activate, Adjust, SetFocused(bool), IsEnabled() }
function Focus:Register(scope, item)
	local list = self._scopes[scope]
	if not list then
		list = {}
		self._scopes[scope] = list
	end
	table.insert(list, item)
end

--- Removes an item.
function Focus:Unregister(scope, item)
	local list = self._scopes[scope]
	if list then
		local idx = table.find(list, item)
		if idx then
			table.remove(list, idx)
		end
	end
	if self._current == item then
		self._current = nil
	end
end

--- Changes the active scope (called when a tab is selected).
function Focus:SetScope(scope)
	self:_clear()
	self._scope = scope
	if self.Engaged then
		self:Move(1)
	end
end

function Focus:_clear()
	if self._current then
		self._current.SetFocused(false)
		self._current = nil
	end
end

function Focus:_scrollTo(root)
	local sf = root.Parent
	while sf and not sf:IsA("ScrollingFrame") do
		sf = sf.Parent
	end
	if not sf then
		return
	end
	local rel = root.AbsolutePosition.Y - sf.AbsolutePosition.Y
	local h = root.AbsoluteSize.Y
	local view = sf.AbsoluteSize.Y
	local pos = sf.CanvasPosition
	if rel < 8 then
		sf.CanvasPosition = Vector2.new(pos.X, math.max(0, pos.Y + rel - 8))
	elseif rel + h > view - 8 then
		sf.CanvasPosition = Vector2.new(pos.X, pos.Y + (rel + h - view) + 8)
	end
end

function Focus:_focus(item)
	if self._current and self._current ~= item then
		self._current.SetFocused(false)
	end
	self._current = item
	item.SetFocused(true)
	self:_scrollTo(item.Root)
	self.Ctx:Announce(item.Label)
end

--- Moves focus to the next/previous visible, enabled item (wraps around).
-- @param dir number 1 or -1
function Focus:Move(dir)
	local list = self._scopes[self._scope]
	if not list or #list == 0 then
		return
	end
	local idx = table.find(list, self._current) or (dir > 0 and 0 or #list + 1)
	for _ = 1, #list do
		idx = idx + dir
		if idx > #list then idx = 1 elseif idx < 1 then idx = #list end
		local it = list[idx]
		if it.IsEnabled() and Util.IsShown(it.Root) then
			self:_focus(it)
			return
		end
	end
end

--- Enters keyboard-navigation mode.
function Focus:Engage()
	if self.Engaged then
		return
	end
	self.Engaged = true
	local K = Enum.KeyCode
	ContextActionService:BindActionAtPriority(ACTION, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		local k = input.KeyCode
		local shift = UserInputService:IsKeyDown(K.LeftShift) or UserInputService:IsKeyDown(K.RightShift)
		if k == K.Up or (k == K.Tab and shift) then
			self:Move(-1)
		elseif k == K.Down or k == K.Tab then
			self:Move(1)
		elseif k == K.Left or k == K.Right then
			local it = self._current
			if it and it.Adjust then Util.Call(it.Adjust, k == K.Right and 1 or -1) end
		elseif k == K.Return or k == K.Space then
			local it = self._current
			if it and it.Activate then Util.Call(it.Activate) end
		elseif k == K.Escape then
			self:Disengage()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, K.Up, K.Down, K.Left, K.Right, K.Return, K.Space, K.Escape, K.Tab)
	if not self._current then
		self:Move(1)
	end
end

--- Leaves keyboard-navigation mode.
function Focus:Disengage()
	if not self.Engaged then
		return
	end
	self.Engaged = false
	ContextActionService:UnbindAction(ACTION)
	self:_clear()
end

--- Releases connections and bindings.
function Focus:Destroy()
	self:Disengage()
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
end

return Focus

end


-- ===== Core/Maid =====
rawget(__core, "_kids")["Maid"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Maid
	Collects connections / instances / functions / destroyables and cleans them together.
]]
local Maid = {}
Maid.__index = Maid

--- @return Maid
function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

--- Registers a task. @param task RBXScriptConnection|Instance|function|table(Destroy/Disconnect) @return task
function Maid:Give(task)
	table.insert(self._tasks, task)
	return task
end

--- Cleans and forgets all tasks. Safe to call multiple times.
function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for _, t in ipairs(tasks) do
		local kind = typeof(t)
		if kind == "RBXScriptConnection" then
			t:Disconnect()
		elseif kind == "Instance" then
			t:Destroy()
		elseif kind == "function" then
			t()
		elseif kind == "table" then
			if t.Disconnect then
				t:Disconnect()
			elseif t.Destroy then
				t:Destroy()
			end
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid

end


-- ===== Core/Notifications =====
rawget(__core, "_kids")["Notifications"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Notifications
	Toasts (Info/Success/Warning/Error, auto-dismiss, click to dismiss) and modal Alerts.
	Toast cards are pooled: repeated notifications never allocate new Instances after warm-up.
]]
local Util = require(script.Parent.Util)

local Notifications = {}
Notifications.__index = Notifications

local TOKEN = { Info = "Accent", Success = "Success", Warning = "Warning", Error = "Danger" }

--- @param ctx table @param gui ScreenGui
-- @return Notifications
function Notifications.new(ctx, gui)
	local cfg = ctx.Config.Notification
	local self = setmetatable({ Ctx = ctx, Gui = gui, Active = {}, _n = 0 }, Notifications)

	local pos = cfg.Position
	local right, left = pos:find("Right") ~= nil, pos:find("Left") ~= nil
	local bottom = pos:find("Bottom") ~= nil
	local ax = right and 1 or (left and 0 or 0.5)
	self.SlideDir = right and 1 or (left and -1 or 0)
	self.Top = not bottom

	local list = Util.List(8)
	list.VerticalAlignment = bottom and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
	list.HorizontalAlignment = right and Enum.HorizontalAlignment.Right
		or (left and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center)

	self.Holder = Util.Create("Frame", {
		Name = "Notifications", BackgroundTransparency = 1, ZIndex = 100,
		AnchorPoint = Vector2.new(ax, bottom and 1 or 0),
		Position = UDim2.new(ax, right and -16 or (left and 16 or 0), bottom and 1 or 0, bottom and -16 or 16),
		Size = UDim2.new(0, cfg.Width, 1, -32), Parent = gui,
	}, { list })

	self.Pool = ctx.Pool.new(function() return self:_build() end, function(e) self:_reset(e) end, cfg.PoolSize, function(e)
		e.Wrapper:Destroy()
	end)
	return self
end

function Notifications:_build()
	local cfg = self.Ctx.Config
	local wrapper = Util.Create("Frame", {
		Name = "Toast", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	local card = Util.Create("TextButton", {
		Name = "Card", Text = "", AutoButtonColor = false, BorderSizePixel = 0, ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = wrapper,
	}, { Util.Corner(cfg.Radius) })
	local stroke = Util.Stroke(1)
	stroke.Parent = card
	local content = Util.Create("Frame", {
		Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card,
	}, { Util.List(2), Util.Padding(16, 11, 12, 14) })
	local title = Util.Label({ Name = "Title", Font = cfg.FontBold, TextWrapped = true, LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	local body = Util.Label({ Name = "Body", TextSize = cfg.TextSizeSmall + 1, TextWrapped = true, LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
	local bar = Util.Create("Frame", { Name = "Accent", BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Parent = card })
	local progress = Util.Create("Frame", { Name = "Progress", BorderSizePixel = 0, BackgroundTransparency = 0.5,
		Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3), Parent = card })
	local entry = { Wrapper = wrapper, Card = card, Stroke = stroke, Title = title, Body = body, Bar = bar, Progress = progress }
	card.Activated:Connect(function()
		if entry.Dismiss then entry.Dismiss() end
	end)
	return entry
end

function Notifications:_reset(e)
	e.Dismiss = nil
	e.Wrapper.Parent = nil
	e.Wrapper.AutomaticSize = Enum.AutomaticSize.Y
	e.Wrapper.Size = UDim2.new(1, 0, 0, 0)
	e.Card.Position = UDim2.new()
end

--- Shows a toast.
-- @param props table { Title=string, Content=string, Type="Info"|"Success"|"Warning"|"Error", Duration=number (0 = sticky) }
-- @return table handle { Dismiss = function }
function Notifications:Notify(props)
	props = props or {}
	local ctx = self.Ctx
	local cfg = ctx.Config.Notification
	local T, Anim = ctx.Theme, ctx.Anim
	local kind = TOKEN[props.Type] and props.Type or "Info"
	local duration = tonumber(props.Duration) or cfg.Duration

	while #self.Active >= cfg.Max do
		self.Active[1].Dismiss()
	end

	local e = self.Pool:Acquire()
	e.Title.Text = tostring(props.Title or kind)
	e.Title.Visible = true
	e.Body.Text = tostring(props.Content or "")
	e.Body.Visible = e.Body.Text ~= ""
	e.Card.BackgroundColor3 = T:Get("Surface")
	e.Stroke.Color = T:Get("Stroke")
	e.Title.TextColor3 = T:Get("Text")
	e.Body.TextColor3 = T:Get("TextMuted")
	e.Bar.BackgroundColor3 = T:Get(TOKEN[kind])
	e.Progress.BackgroundColor3 = T:Get(TOKEN[kind])
	e.Progress.Visible = duration > 0
	e.Progress.Size = UDim2.new(1, 0, 0, 3)

	self._n = self._n + 1
	e.Wrapper.LayoutOrder = self.Top and -self._n or self._n
	e.Card.Position = UDim2.fromOffset(self.SlideDir * (cfg.Width + 24), self.SlideDir == 0 and -30 or 0)
	e.Wrapper.Parent = self.Holder
	table.insert(self.Active, e)
	Anim.Tween(e.Card, { Position = UDim2.new() }, ctx.Config.Animation.Slow)
	if duration > 0 then
		Anim.Tween(e.Progress, { Size = UDim2.new(0, 0, 0, 3) }, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
	end

	local dead = false
	local function dismiss()
		if dead then return end
		dead = true
		local idx = table.find(self.Active, e)
		if idx then table.remove(self.Active, idx) end
		Anim.Tween(e.Card, { Position = UDim2.fromOffset(self.SlideDir * (cfg.Width + 24), self.SlideDir == 0 and -30 or 0) }, ctx.Config.Animation.Normal)
		task.delay(ctx.Config.Animation.Normal, function()
			e.Wrapper.AutomaticSize = Enum.AutomaticSize.None
			e.Wrapper.Size = UDim2.new(1, 0, 0, e.Wrapper.AbsoluteSize.Y)
			Anim.Tween(e.Wrapper, { Size = UDim2.new(1, 0, 0, 0) }, 0.18)
			task.delay(0.2, function()
				self.Pool:Release(e)
			end)
		end)
	end
	e.Dismiss = dismiss
	if duration > 0 then
		task.delay(duration, dismiss)
	end
	return { Dismiss = dismiss }
end

--- Shows a modal alert with buttons.
-- @param props table { Title, Content, Type, Buttons = { {Text=string, Callback=function, Style="Solid"|"Outline"} } }
-- @return table handle { Close = function }
function Notifications:Alert(props)
	props = props or {}
	local ctx = self.Ctx
	local cfg, T, Anim = ctx.Config, ctx.Theme, ctx.Anim
	if self._alert then
		self._alert.Close()
	end
	local kind = TOKEN[props.Type] and props.Type or "Info"

	local dim = Util.Create("TextButton", {
		Name = "LumenAlert", Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 300,
		BackgroundColor3 = Color3.new(), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = self.Gui,
	})
	local card = Util.Create("Frame", {
		Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 14),
		Size = UDim2.fromOffset(340, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
		BackgroundColor3 = T:Get("Surface"), Parent = dim,
	}, { Util.Corner(cfg.Radius + 2), Util.List(8), Util.Padding(18) })
	local stroke = Util.Stroke(1, T:Get(TOKEN[kind]))
	stroke.Parent = card
	Util.Label({ Name = "Title", Text = tostring(props.Title or "Notice"), Font = cfg.FontBold, TextSize = cfg.TextSizeTitle,
		TextColor3 = T:Get("Text"), TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Parent = card })
	Util.Label({ Name = "Body", Text = tostring(props.Content or ""), TextColor3 = T:Get("TextMuted"), TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card })
	local row = Util.Create("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 3, Parent = card }, { Util.List(8, Enum.FillDirection.Horizontal) })
	row:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Right

	local closed = false
	local function close()
		if closed then return end
		closed = true
		self._alert = nil
		Anim.Tween(dim, { BackgroundTransparency = 1 }, 0.15)
		Anim.Tween(card, { Position = UDim2.new(0.5, 0, 0.5, 14) }, 0.15)
		task.delay(0.16, function() dim:Destroy() end)
	end

	local buttons = props.Buttons
	if type(buttons) ~= "table" or #buttons == 0 then
		buttons = { { Text = "OK" } }
	end
	for i, b in ipairs(buttons) do
		local solid = (b.Style or (i == #buttons and "Solid" or "Outline")) == "Solid"
		local btn = Util.Create("TextButton", {
			Text = tostring(b.Text or "OK"), Font = cfg.FontBold, TextSize = cfg.TextSize, AutoButtonColor = false,
			BorderSizePixel = 0, Size = UDim2.new(0, 96, 1, 0), LayoutOrder = i, Parent = row,
			BackgroundColor3 = T:Get("Accent"), BackgroundTransparency = solid and 0 or 1,
			TextColor3 = solid and T:Get("AccentText") or T:Get("Text"),
		}, { Util.Corner(cfg.RadiusSmall) })
		if not solid then
			Util.Stroke(1, T:Get("Stroke")).Parent = btn
		end
		btn.Activated:Connect(function()
			close()
			Util.Call(b.Callback)
		end)
	end
	Anim.Tween(dim, { BackgroundTransparency = 0.5 }, 0.15)
	Anim.Tween(card, { Position = UDim2.fromScale(0.5, 0.5) }, 0.25)
	self._alert = { Close = close }
	return self._alert
end

--- Destroys UI and pooled objects.
function Notifications:Destroy()
	self.Pool:Destroy()
	self.Holder:Destroy()
	if self._alert then self._alert.Close() end
end

return Notifications

end


-- ===== Core/Pool =====
rawget(__core, "_kids")["Pool"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Pool
	Generic object pool. Used for notification cards and dropdown rows so repeated
	open/close never allocates new Instances.
]]
local Pool = {}
Pool.__index = Pool

--- @param factory function () -> object
-- @param reset function|nil (object) -> () called when released
-- @param max number|nil max idle objects kept (default 16)
-- @param destroyer function|nil (object) -> () default: object:Destroy()
-- @return Pool
function Pool.new(factory, reset, max, destroyer)
	return setmetatable({
		_factory = factory,
		_reset = reset,
		_max = max or 16,
		_destroy = destroyer or function(o)
			o:Destroy()
		end,
		_free = {},
	}, Pool)
end

--- @return object a recycled or new object
function Pool:Acquire()
	local n = #self._free
	if n > 0 then
		local obj = self._free[n]
		self._free[n] = nil
		return obj
	end
	return self._factory()
end

--- Returns an object to the pool (destroyed if the pool is full).
function Pool:Release(obj)
	if self._reset then
		self._reset(obj)
	end
	if #self._free < self._max then
		table.insert(self._free, obj)
	else
		self._destroy(obj)
	end
end

--- Destroys all idle objects.
function Pool:Destroy()
	for _, obj in ipairs(self._free) do
		self._destroy(obj)
	end
	table.clear(self._free)
end

return Pool

end


-- ===== Core/Signal =====
rawget(__core, "_kids")["Signal"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Signal
	Minimal pure-Lua signal (no BindableEvent instances -> cheaper, no instance leaks).
]]
local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

--- Disconnects this connection.
function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._handlers
	for i = 1, #list do
		if list[i] == self then
			table.remove(list, i)
			break
		end
	end
end

--- @return Signal
function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

--- @param fn function @return table connection (has :Disconnect())
function Signal:Connect(fn)
	local conn = setmetatable({ Connected = true, _fn = fn, _signal = self }, Connection)
	table.insert(self._handlers, conn)
	return conn
end

--- Connects a handler that disconnects itself after the first fire.
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

--- Fires every handler in its own thread (an erroring handler never blocks the rest).
function Signal:Fire(...)
	local n = #self._handlers
	if n == 0 then
		return
	end
	local snapshot = table.clone(self._handlers)
	for _, conn in ipairs(snapshot) do
		if conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
end

--- Disconnects everything.
function Signal:Destroy()
	for _, conn in ipairs(self._handlers) do
		conn.Connected = false
	end
	table.clear(self._handlers)
end

return Signal

end


-- ===== Core/Theme =====
rawget(__core, "_kids")["Theme"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Theme
	Token-based theming. Static colors are registered with Bind(); state-dependent
	colors are recomputed by components through Track() (ONE loop, no per-element connections).
]]
local Animation = require(script.Parent.Animation)
local Signal = require(script.Parent.Signal)

local Theme = {}
Theme.__index = Theme

local function extend(base, over)
	local t = table.clone(base)
	for k, v in pairs(over) do
		t[k] = v
	end
	return t
end

local Dark = {
	Background = Color3.fromRGB(14, 15, 20),
	Surface = Color3.fromRGB(21, 23, 31),
	SurfaceAlt = Color3.fromRGB(29, 32, 43),
	Hover = Color3.fromRGB(38, 42, 56),
	Track = Color3.fromRGB(12, 13, 18),
	Stroke = Color3.fromRGB(46, 50, 66),
	Text = Color3.fromRGB(236, 238, 246),
	TextMuted = Color3.fromRGB(139, 146, 166),
	Accent = Color3.fromRGB(110, 99, 255),
	AccentAlt = Color3.fromRGB(56, 189, 248),
	AccentText = Color3.fromRGB(255, 255, 255),
	Success = Color3.fromRGB(52, 211, 153),
	Warning = Color3.fromRGB(251, 191, 36),
	Danger = Color3.fromRGB(248, 113, 113),
	Shadow = Color3.fromRGB(0, 0, 0),
	TooltipBackground = Color3.fromRGB(44, 48, 64),
	TooltipText = Color3.fromRGB(236, 238, 246),
}

Theme.Palettes = {
	Dark = Dark,
	Light = extend(Dark, {
		Background = Color3.fromRGB(243, 245, 250),
		Surface = Color3.fromRGB(255, 255, 255),
		SurfaceAlt = Color3.fromRGB(236, 239, 246),
		Hover = Color3.fromRGB(224, 228, 239),
		Track = Color3.fromRGB(214, 219, 232),
		Stroke = Color3.fromRGB(211, 216, 230),
		Text = Color3.fromRGB(24, 26, 36),
		TextMuted = Color3.fromRGB(98, 105, 124),
		Accent = Color3.fromRGB(88, 76, 240),
		AccentAlt = Color3.fromRGB(14, 148, 220),
		Success = Color3.fromRGB(16, 160, 110),
		Warning = Color3.fromRGB(217, 140, 0),
		Danger = Color3.fromRGB(220, 60, 60),
		Shadow = Color3.fromRGB(40, 50, 80),
		TooltipBackground = Color3.fromRGB(30, 32, 44),
		TooltipText = Color3.fromRGB(245, 246, 250),
	}),
	HighContrast = extend(Dark, {
		Background = Color3.fromRGB(0, 0, 0),
		Surface = Color3.fromRGB(0, 0, 0),
		SurfaceAlt = Color3.fromRGB(18, 18, 18),
		Hover = Color3.fromRGB(55, 55, 55),
		Track = Color3.fromRGB(40, 40, 40),
		Stroke = Color3.fromRGB(255, 255, 255),
		Text = Color3.fromRGB(255, 255, 255),
		TextMuted = Color3.fromRGB(225, 225, 225),
		Accent = Color3.fromRGB(255, 235, 0),
		AccentAlt = Color3.fromRGB(0, 255, 255),
		AccentText = Color3.fromRGB(0, 0, 0),
		Success = Color3.fromRGB(0, 255, 110),
		Warning = Color3.fromRGB(255, 170, 0),
		Danger = Color3.fromRGB(255, 80, 80),
		TooltipBackground = Color3.fromRGB(0, 0, 0),
		TooltipText = Color3.fromRGB(255, 255, 255),
	}),
}

--- @param name string initial palette name (falls back to "Dark")
-- @return Theme
function Theme.new(name)
	local self = setmetatable({}, Theme)
	self.Palettes = table.clone(Theme.Palettes)
	self.Name = self.Palettes[name] and name or "Dark"
	self.Palette = self.Palettes[self.Name]
	self.Changed = Signal.new()
	self._bindings = setmetatable({}, { __mode = "k" })
	self._trackers = {}
	return self
end

--- @param token string palette key @return Color3
function Theme:Get(token)
	return self.Palette[token]
end

--- Registers (or overrides) a palette. Missing tokens fall back to Dark.
-- @param name string
-- @param palette table token -> Color3
function Theme:Register(name, palette)
	self.Palettes[name] = extend(self.Palettes.Dark, palette)
end

--- @return table sorted array of palette names
function Theme:List()
	local names = {}
	for n in pairs(self.Palettes) do
		table.insert(names, n)
	end
	table.sort(names)
	return names
end

function Theme:_resolve(token)
	if type(token) == "function" then
		return token(self.Palette)
	end
	return self.Palette[token]
end

--- Binds instance properties to palette tokens and applies them now.
-- @param inst Instance
-- @param map table property -> token | function(palette)->value
-- @return Instance inst
function Theme:Bind(inst, map)
	local existing = self._bindings[inst]
	if not existing then
		existing = {}
		self._bindings[inst] = existing
	end
	for prop, token in pairs(map) do
		existing[prop] = token
		inst[prop] = self:_resolve(token)
	end
	return inst
end

--- Registers a re-render callback invoked on every theme change. @param key any unique key @param fn function(animated)
function Theme:Track(key, fn)
	self._trackers[key] = fn
end

--- @param key any key passed to Track
function Theme:Untrack(key)
	self._trackers[key] = nil
end

--- Switches palette (real-time).
-- @param name string
-- @param animated boolean|nil tween colors
-- @return boolean success
function Theme:Set(name, animated)
	local palette = self.Palettes[name]
	if not palette then
		warn("[Lumen] unknown theme '" .. tostring(name) .. "'")
		return false
	end
	self.Name = name
	self.Palette = palette
	for inst, map in pairs(self._bindings) do
		if inst.Parent then
			local goal = {}
			for prop, token in pairs(map) do
				goal[prop] = self:_resolve(token)
			end
			Animation.Tween(inst, goal, animated and 0.25 or 0)
		end
	end
	for _, fn in pairs(self._trackers) do
		local ok, err = pcall(fn, animated)
		if not ok then
			warn("[Lumen] theme tracker error: " .. tostring(err))
		end
	end
	self.Changed:Fire(name)
	return true
end

return Theme

end


-- ===== Core/Tooltip =====
rawget(__core, "_kids")["Tooltip"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Tooltip
	One shared tooltip frame. Smart positioning (flips at screen edges), themed (dark/light),
	disabled automatically on touch-only devices.
]]
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Util = require(script.Parent.Util)

local Tooltip = {}
Tooltip.__index = Tooltip

--- @param ctx table library context @param gui ScreenGui parent
-- @return Tooltip
function Tooltip.new(ctx, gui)
	local self = setmetatable({}, Tooltip)
	self.Ctx = ctx
	self.Enabled = not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
	self._token = 0
	local cfg = ctx.Config

	local frame = Util.Create("Frame", {
		Name = "Tooltip", Visible = false, ZIndex = 1000, BorderSizePixel = 0,
		Size = UDim2.fromOffset(10, 10), Active = false, Parent = gui,
	}, { Util.Corner(cfg.RadiusSmall) })
	local stroke = Util.Stroke(1)
	stroke.Parent = frame
	local label = Util.Label({
		Name = "Text", Size = UDim2.fromScale(1, 1), TextWrapped = true, TextSize = cfg.TextSizeSmall + 1,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = frame,
	})
	Util.Padding(8, 6).Parent = frame
	ctx.Theme:Bind(frame, { BackgroundColor3 = "TooltipBackground" })
	ctx.Theme:Bind(stroke, { Color = "Stroke" })
	ctx.Theme:Bind(label, { TextColor3 = "TooltipText" })
	self.Frame, self.Label = frame, label
	self._size = Vector2.new(10, 10)
	return self
end

function Tooltip:_place()
	local m = UserInputService:GetMouseLocation()
	local vp = Util.Viewport()
	local w, h = self._size.X, self._size.Y
	local x, y = m.X + 14, m.Y + 18
	if x + w > vp.X - 6 then x = m.X - w - 10 end
	if y + h > vp.Y - 6 then y = m.Y - h - 14 end
	self.Frame.Position = UDim2.fromOffset(math.max(6, x), math.max(6, y))
end

function Tooltip:_show(text)
	if not text or text == "" then
		return
	end
	local cfg = self.Ctx.Config
	local size = TextService:GetTextSize(text, cfg.TextSizeSmall + 1, cfg.Font, Vector2.new(cfg.Tooltip.MaxWidth, 10000))
	self._size = Vector2.new(size.X + 18, size.Y + 14)
	self.Label.Text = text
	self.Frame.Size = UDim2.fromOffset(self._size.X, self._size.Y)
	self:_place()
	self.Frame.Visible = true
end

--- Attaches a tooltip to a GuiObject.
-- @param gui GuiObject
-- @param text string|function text or function returning text (evaluated on hover)
-- @return function detach
function Tooltip:Attach(gui, text)
	if not self.Enabled then
		return function() end
	end
	local delay = self.Ctx.Config.Tooltip.Delay
	local enter = gui.MouseEnter:Connect(function()
		self._token = self._token + 1
		local token = self._token
		task.delay(delay, function()
			if self._token == token and gui.Parent then
				self:_show(type(text) == "function" and text() or text)
			end
		end)
	end)
	local leave = gui.MouseLeave:Connect(function()
		self._token = self._token + 1
		self.Frame.Visible = false
	end)
	local move = gui.MouseMoved:Connect(function()
		if self.Frame.Visible then
			self:_place()
		end
	end)
	return function()
		enter:Disconnect()
		leave:Disconnect()
		move:Disconnect()
		self.Frame.Visible = false
	end
end

--- Destroys the tooltip frame.
function Tooltip:Destroy()
	self.Frame:Destroy()
end

return Tooltip

end


-- ===== Core/Util =====
rawget(__core, "_kids")["Util"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Util
	Shared helpers: instance builders, math, colors, safe calls, pointer math.
]]
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Util = {}
Util.Config = nil -- injected by init.lua

--- Creates an Instance, assigns props (Parent last, for performance) and parents children.
-- @param className string
-- @param props table|nil
-- @param children table|nil array of Instances
-- @return Instance
function Util.Create(className, props, children)
	local inst = Instance.new(className)
	local parent
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				inst[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

--- UICorner. @param radius number|"full" @return UICorner
function Util.Corner(radius)
	return Util.Create("UICorner", {
		CornerRadius = radius == "full" and UDim.new(1, 0) or UDim.new(0, radius or 8),
	})
end

--- Border-mode UIStroke. @param thickness number|nil @param color Color3|nil @return UIStroke
function Util.Stroke(thickness, color)
	return Util.Create("UIStroke", {
		Thickness = thickness or 1,
		Color = color or Color3.new(),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

--- UIPadding. Padding(all) | Padding(horizontal, vertical) | Padding(l, t, r, b).
-- @return UIPadding
function Util.Padding(l, t, r, b)
	t = t or l
	r = r or l
	b = b or t
	return Util.Create("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
	})
end

--- UIListLayout. @param padding number @param direction Enum.FillDirection|nil @return UIListLayout
function Util.List(padding, direction)
	return Util.Create("UIListLayout", {
		Padding = UDim.new(0, padding or 0),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

--- TextLabel with library defaults. @param props table @return TextLabel
function Util.Label(props)
	local cfg = Util.Config
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = cfg.Font,
		TextSize = cfg.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return Util.Create("TextLabel", p)
end

--- @return number clamped value
function Util.Clamp(n, lo, hi)
	return math.max(lo, math.min(hi, n))
end

--- Rounds n to the nearest multiple of step. @return number
function Util.Round(n, step)
	step = step or 1
	return math.floor(n / step + 0.5) * step
end

--- Number of decimals needed to display multiples of step. @return number
function Util.Decimals(step)
	local s = string.format("%.6f", step)
	s = s:gsub("0+$", "")
	local dot = s:find(".", 1, true)
	if not dot then
		return 0
	end
	return #s - dot
end

--- @return string number formatted with fixed decimals
function Util.FormatNumber(v, decimals)
	return string.format("%." .. (decimals or 0) .. "f", v)
end

--- Parses "#RGB", "#RRGGBB" (with or without #). @return Color3|nil
function Util.HexToColor3(hex)
	if type(hex) ~= "string" then
		return nil
	end
	hex = hex:gsub("^#", "")
	if #hex == 3 then
		hex = hex:gsub(".", "%0%0")
	end
	if #hex ~= 6 or hex:find("%X") then
		return nil
	end
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end

--- @return string "#RRGGBB"
function Util.Color3ToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

--- Runs a user callback in protected mode; errors become readable warnings.
-- @param fn function|nil
function Util.Call(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = xpcall(fn, function(e)
		return debug.traceback(tostring(e), 2)
	end, ...)
	if not ok then
		warn("[Lumen] callback error: " .. tostring(err))
	end
end

--- Reads props[key] checking its type; warns and returns default when wrong.
-- @return any
function Util.Expect(props, key, expected, default)
	local v = props[key]
	if v == nil then
		return default
	end
	if typeof(v) ~= expected then
		warn(string.format("[Lumen] '%s' expected %s, got %s (using default)", key, expected, typeof(v)))
		return default
	end
	return v
end

--- Pointer position in AbsolutePosition space (screen px incl. GUI inset).
-- @param input InputObject
-- @param is3D boolean|nil true when inside Surface/BillboardGui (uses input.Position as-is)
-- @return Vector2
function Util.PointerPos(input, is3D)
	if is3D then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		local inset = GuiService:GetGuiInset()
		return Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
	end
	return UserInputService:GetMouseLocation()
end

--- True if the gui and all its GuiObject ancestors are Visible and it is parented under a LayerCollector.
function Util.IsShown(gui)
	local cur = gui
	while cur and not cur:IsA("LayerCollector") do
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return cur ~= nil
end

--- Recursive merge of `over` into `base` (mutates base). @return table base
function Util.DeepMerge(base, over)
	for k, v in pairs(over) do
		if type(v) == "table" and type(base[k]) == "table" then
			Util.DeepMerge(base[k], v)
		else
			base[k] = v
		end
	end
	return base
end

--- Current camera viewport (fallback 1280x720). @return Vector2
function Util.Viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

return Util

end


-- ===== Core/Window =====
rawget(__core, "_kids")["Window"]._fn = function(script, require)
--[[
	Lumen UI :: Core/Window
	Draggable / resizable / minimizable window with sidebar tabs, blur + shadow,
	popup layer (dropdowns, color picker), responsive layout and keyboard navigation.
	Mounts: "Screen" (default), "Surface" (SurfaceGui) or "Billboard" (BillboardGui).
	3D mounts are display-oriented: no drag/resize/blur, and pointer-position controls
	(slider, color picker) are best-effort there.
]]
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Util = require(script.Parent.Util)
local Drag = require(script.Parent.Drag)
local Focus = require(script.Parent.Focus)
local Container = require(script.Parent.Container)

local Window = {}
Window.__index = Window

local Tab = Container.extend()

local function createMount(ctx, props)
	assert(typeof(props.Adornee) == "Instance", "Mount '" .. tostring(props.Mount) .. "' needs props.Adornee (a BasePart)")
	local playerGui = ctx.GuiParent or Players.LocalPlayer:WaitForChild("PlayerGui")
	if props.Mount == "Surface" then
		return Util.Create("SurfaceGui", {
			Name = "LumenSurface", Adornee = props.Adornee, Face = props.Face or Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = props.CanvasSize or Vector2.new(900, 600),
			AlwaysOnTop = props.AlwaysOnTop == true, ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
		})
	end
	return Util.Create("BillboardGui", {
		Name = "LumenBillboard", Adornee = props.Adornee, Size = props.BillboardSize or UDim2.fromOffset(560, 380),
		StudsOffset = props.StudsOffset or Vector3.new(0, 3, 0), AlwaysOnTop = props.AlwaysOnTop == true,
		MaxDistance = props.MaxDistance or 100, Active = true, ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
	})
end

--- Creates a window. Prefer Lumen:CreateWindow().
-- @param ctx table library context
-- @param props table { Title, Subtitle, Icon, Size=UDim2|Vector2, Theme, ToggleKey=KeyCode|false, Resizable, Blur, Shadow,
--   Mount="Screen"|"Surface"|"Billboard", Adornee, Face, CanvasSize, OnClose=function, CloseDestroys=boolean }
-- @return Window
function Window.new(ctx, props)
	props = props or {}
	local Config, T, Anim = ctx.Config, ctx.Theme, ctx.Anim
	local cfg = Config.Window
	local self = setmetatable({}, Window)
	self.Ctx, self.Props = ctx, props
	self.Maid = ctx.Maid.new()
	self.Tabs, self.Elements = {}, {}
	self.Opened, self.Closed, self.TabChanged = ctx.Signal.new(), ctx.Signal.new(), ctx.Signal.new()
	self.Visible, self.Minimized = true, false
	self.Is3D = props.Mount == "Surface" or props.Mount == "Billboard"
	self.Resizable = props.Resizable ~= false and not self.Is3D
	self._vtoken = 0

	if props.Theme then
		T:Set(props.Theme)
	end

	local base = props.Size or cfg.Size
	if typeof(base) == "Vector2" then
		base = UDim2.fromOffset(base.X, base.Y)
	end
	self.Size = Vector2.new(base.X.Offset, base.Y.Offset)
	local parentGui
	if self.Is3D then
		parentGui = self.Maid:Give(createMount(ctx, props))
	else
		parentGui = ctx:GetScreenGui()
		self.Size = self:_fitSize(self.Size)
	end

	-- holder (moves / resizes) -------------------------------------------------
	local vp = Util.Viewport()
	local holder = Util.Create("Frame", {
		Name = "Lumen_" .. tostring(props.Title or "Window"), BackgroundTransparency = 1,
		Size = self.Is3D and UDim2.fromScale(1, 1) or UDim2.fromOffset(self.Size.X, self.Size.Y),
		Position = self.Is3D and UDim2.new() or UDim2.fromOffset(math.floor((vp.X - self.Size.X) / 2), math.floor((vp.Y - self.Size.Y) / 2)),
		Parent = parentGui,
	})
	self.Holder = holder
	self.Maid:Give(holder)

	if cfg.Shadow and props.Shadow ~= false and not self.Is3D then
		local sh = Config.Shadow
		local s = sh.Spread
		local shadow = Util.Create("ImageLabel", {
			Name = "Shadow", BackgroundTransparency = 1, ZIndex = 0, Image = sh.Image, ScaleType = Enum.ScaleType.Slice,
			SliceCenter = sh.Slice, ImageTransparency = sh.Transparency,
			Position = UDim2.fromOffset(-s, -s + 6), Size = UDim2.new(1, s * 2, 1, s * 2), Parent = holder,
		})
		T:Bind(shadow, { ImageColor3 = "Shadow" })
		self.Shadow = shadow
	end

	local main = Util.Create("Frame", {
		Name = "Main", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1, Parent = holder,
	}, { Util.Corner(Config.Radius + 2) })
	local mainStroke = Util.Stroke(1)
	mainStroke.Parent = main
	T:Bind(main, { BackgroundColor3 = "Background" })
	T:Bind(mainStroke, { Color = "Stroke" })
	self.Main = main

	-- title bar ----------------------------------------------------------------
	local tbH = cfg.TitleBarHeight
	local titleBar = Util.Create("Frame", { Name = "TitleBar", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, tbH), Parent = main })
	T:Bind(titleBar, { BackgroundColor3 = "Surface" })
	local tbLine = Util.Create("Frame", { Name = "Line", BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Parent = titleBar })
	T:Bind(tbLine, { BackgroundColor3 = "Stroke" })
	self.TitleBar = titleBar

	local titleBox = Util.Create("Frame", {
		Name = "Titles", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 1, 0), Parent = titleBar,
	}, { Util.List(8, Enum.FillDirection.Horizontal) })
	local tl = titleBox:FindFirstChildOfClass("UIListLayout")
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	if props.Icon then
		local icon = Util.Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20),
			Image = ctx:ResolveIcon(props.Icon), LayoutOrder = 1, Parent = titleBox })
		T:Bind(icon, { ImageColor3 = "Accent" })
	end
	self.TitleLabel = Util.Label({ Name = "Title", Text = tostring(props.Title or "Lumen"), Font = Config.FontBold,
		TextSize = Config.TextSizeTitle, AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, Parent = titleBox })
	T:Bind(self.TitleLabel, { TextColor3 = "Text" })
	if props.Subtitle then
		local sub = Util.Label({ Name = "Subtitle", Text = tostring(props.Subtitle), TextSize = Config.TextSizeSmall,
			AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3, Parent = titleBox })
		T:Bind(sub, { TextColor3 = "TextMuted" })
	end

	local ctrl = Util.Create("Frame", {
		Name = "Controls", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(72, tbH), Parent = titleBar,
	}, { Util.List(4, Enum.FillDirection.Horizontal) })
	local cl = ctrl:FindFirstChildOfClass("UIListLayout")
	cl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	cl.VerticalAlignment = Enum.VerticalAlignment.Center

	local function ctrlButton(name, order, danger)
		local b = Util.Create("TextButton", {
			Name = name, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(30, 30), LayoutOrder = order, Parent = ctrl,
		}, { Util.Corner(Config.RadiusSmall) })
		local function paint(hover)
			Anim.Tween(b, { BackgroundTransparency = hover and 0 or 1, BackgroundColor3 = T:Get(danger and "Danger" or "Hover") }, Config.Animation.Fast)
		end
		self.Maid:Give(b.MouseEnter:Connect(function() paint(true) end))
		self.Maid:Give(b.MouseLeave:Connect(function() paint(false) end))
		return b
	end
	local minBtn = ctrlButton("Minimize", 1, false)
	local minGlyph = Util.Create("Frame", { Name = "Glyph", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(11, 2), Parent = minBtn })
	T:Bind(minGlyph, { BackgroundColor3 = "TextMuted" })
	local closeBtn = ctrlButton("Close", 2, true)
	local closeGlyph = Util.Label({ Name = "Glyph", Text = "\195\151", Font = Config.FontBold, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = closeBtn })
	T:Bind(closeGlyph, { TextColor3 = "TextMuted" })
	minBtn:SetAttribute("A11yLabel", "Minimize window")
	closeBtn:SetAttribute("A11yLabel", "Close window")
	if self.Is3D then
		ctrl.Visible = false
	end
	self.Maid:Give(minBtn.Activated:Connect(function() self:ToggleMinimize() end))
	self.Maid:Give(closeBtn.Activated:Connect(function()
		Util.Call(props.OnClose)
		if props.CloseDestroys then self:Destroy() else self:Hide() end
	end))

	-- body ---------------------------------------------------------------------
	local body = Util.Create("Frame", {
		Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, tbH), Size = UDim2.new(1, 0, 1, -tbH), Parent = main,
	})
	self.Body = body
	local sidebar = Util.Create("Frame", { Name = "Sidebar", BorderSizePixel = 0, Size = UDim2.new(0, cfg.SidebarWidth, 1, 0), Parent = body })
	T:Bind(sidebar, { BackgroundColor3 = "Surface" })
	local sbLine = Util.Create("Frame", { Name = "Line", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0), Parent = sidebar })
	T:Bind(sbLine, { BackgroundColor3 = "Stroke" })
	self.Sidebar = sidebar
	self.TabList = Util.Create("ScrollingFrame", {
		Name = "Tabs", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = sidebar,
	}, { Util.List(4), Util.Padding(8, 10) })

	local content = Util.Create("Frame", {
		Name = "Content", BackgroundTransparency = 1, ClipsDescendants = true,
		Position = UDim2.fromOffset(cfg.SidebarWidth, 0), Size = UDim2.new(1, -cfg.SidebarWidth, 1, 0), Parent = body,
	})
	self.Content = content
	self.Cover = Util.Create("Frame", { Name = "Cover", BorderSizePixel = 0, Visible = false, ZIndex = 30, Size = UDim2.fromScale(1, 1), Parent = content })
	T:Bind(self.Cover, { BackgroundColor3 = "Background" })

	-- popup layer ----------------------------------------------------------------
	self.Overlay = Util.Create("Frame", { Name = "Overlay", BackgroundTransparency = 1, Visible = false, ZIndex = 40, Size = UDim2.fromScale(1, 1), Parent = main })
	local blocker = Util.Create("TextButton", { Name = "Blocker", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ZIndex = 1, Size = UDim2.fromScale(1, 1), Parent = self.Overlay })
	self.Maid:Give(blocker.Activated:Connect(function() self:HidePopup() end))

	-- resize grip ------------------------------------------------------------------
	local grip = Util.Create("TextButton", {
		Name = "ResizeGrip", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ZIndex = 20,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(20, 20), Visible = self.Resizable, Parent = main,
	})
	for _, p in ipairs({ { 12, 12 }, { 7, 12 }, { 12, 7 } }) do
		local dot = Util.Create("Frame", { BorderSizePixel = 0, Position = UDim2.fromOffset(p[1], p[2]), Size = UDim2.fromOffset(3, 3), Parent = grip }, { Util.Corner("full") })
		T:Bind(dot, { BackgroundColor3 = "TextMuted" })
	end
	self.Grip = grip

	-- drag & resize ------------------------------------------------------------------
	if not self.Is3D and props.Draggable ~= false then
		local startPtr, startPos
		self.Maid:Give(Drag.Attach(titleBar, {
			Began = function(input)
				startPtr = Util.PointerPos(input)
				startPos = Vector2.new(holder.Position.X.Offset, holder.Position.Y.Offset)
				ctx._z = ((ctx._z or 1) % 90) + 1
				holder.ZIndex = ctx._z
			end,
			Changed = function(input)
				local d = Util.PointerPos(input) - startPtr
				holder.Position = UDim2.fromOffset(startPos.X + d.X, startPos.Y + d.Y)
			end,
			Ended = function() self:_clampToScreen() end,
		}))
	end
	if self.Resizable then
		local startPtr, startSize
		self.Maid:Give(Drag.Attach(grip, {
			CanBegin = function() return not self.Minimized end,
			Began = function(input) startPtr = Util.PointerPos(input); startSize = self.Size end,
			Changed = function(input) self:SetSize(startSize + (Util.PointerPos(input) - startPtr)) end,
		}))
	end

	-- toggle key / viewport ------------------------------------------------------------
	local toggleKey = props.ToggleKey
	if toggleKey == nil then toggleKey = cfg.ToggleKey end
	self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and self._popup then
			self:HidePopup()
		end
		if processed or self.Is3D or toggleKey == false then return end
		if input.KeyCode == toggleKey then self:Toggle() end
	end))
	local cam = workspace.CurrentCamera
	if cam and not self.Is3D then
		self.Maid:Give(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:SetSize(self.Size)
			self:_clampToScreen()
		end))
	end

	self.Focus = Focus.new(ctx, self)
	self.Maid:Give(self.Focus)
	self.Maid:Give(function()
		if self.Blur then self.Blur:Destroy() self.Blur = nil end
	end)

	self:_layout()
	self:_blur(true)
	return self
end

-- sizing -----------------------------------------------------------------------------
function Window:_fitSize(v)
	local cfg = self.Ctx.Config.Window
	local vp = Util.Viewport()
	local maxX = math.min(cfg.MaxSize.X, vp.X - 16)
	local maxY = math.min(cfg.MaxSize.Y, vp.Y - 16)
	return Vector2.new(Util.Clamp(v.X, math.min(cfg.MinSize.X, maxX), maxX), Util.Clamp(v.Y, math.min(cfg.MinSize.Y, maxY), maxY))
end

--- Sets the window size (clamped to min/max and the viewport). @param v Vector2
function Window:SetSize(v)
	if self.Is3D then return end
	self.Size = self:_fitSize(v)
	if not self.Minimized then
		self.Holder.Size = UDim2.fromOffset(self.Size.X, self.Size.Y)
	else
		self.Holder.Size = UDim2.fromOffset(self.Size.X, self.Ctx.Config.Window.TitleBarHeight)
	end
	self:_layout()
end

function Window:_clampToScreen()
	if self.Is3D then return end
	local vp = Util.Viewport()
	local p = self.Holder.Position
	local x = Util.Clamp(p.X.Offset, -self.Size.X + 90, vp.X - 90)
	local y = Util.Clamp(p.Y.Offset, 0, vp.Y - 44)
	self.Holder.Position = UDim2.fromOffset(x, y)
end

-- responsive: sidebar collapses to icons on narrow windows
function Window:_layout()
	local cfg = self.Ctx.Config.Window
	local w = self.Size.X
	self.Compact = w < cfg.CompactBelow
	local sw = self.Compact and cfg.CompactSidebarWidth or cfg.SidebarWidth
	self.Sidebar.Size = UDim2.new(0, sw, 1, 0)
	self.Content.Position = UDim2.fromOffset(sw, 0)
	self.Content.Size = UDim2.new(1, -sw, 1, 0)
	for _, tab in ipairs(self.Tabs) do
		tab._applyCompact(self.Compact)
	end
end

-- blur / visibility --------------------------------------------------------------------
function Window:_blur(on)
	if self.Is3D or self.Props.Blur == false or not self.Ctx.Config.Window.Blur then return end
	if on then
		if not self.Blur then
			self.Blur = Util.Create("BlurEffect", { Name = "LumenBlur", Size = 0, Parent = Lighting })
		end
		self.Blur.Enabled = true
		self.Ctx.Anim.Tween(self.Blur, { Size = self.Ctx.Config.Window.BlurSize }, 0.3)
	elseif self.Blur then
		local blur = self.Blur
		self.Ctx.Anim.Tween(blur, { Size = 0 }, 0.2)
		task.delay(0.22, function()
			if blur.Parent and not self.Visible then blur.Enabled = false end
		end)
	end
end

--- Shows the window (slide-in).
function Window:Show()
	if self.Visible then return end
	self.Visible = true
	self._vtoken = self._vtoken + 1
	local pos = self.Holder.Position
	self.Holder.Position = pos + UDim2.fromOffset(0, 14)
	self.Holder.Visible = true
	self.Ctx.Anim.Tween(self.Holder, { Position = pos }, self.Ctx.Config.Animation.Normal)
	self:_blur(true)
	self.Opened:Fire()
end

--- Hides the window (slide-out).
function Window:Hide()
	if not self.Visible then return end
	self.Visible = false
	self._vtoken = self._vtoken + 1
	local token = self._vtoken
	self:HidePopup()
	self.Focus:Disengage()
	local pos = self.Holder.Position
	self.Ctx.Anim.Tween(self.Holder, { Position = pos + UDim2.fromOffset(0, 14) }, 0.15)
	self:_blur(false)
	task.delay(0.16, function()
		if token == self._vtoken then
			self.Holder.Visible = false
			self.Holder.Position = pos
		end
	end)
	self.Closed:Fire()
end

--- Toggles visibility.
function Window:Toggle()
	if self.Visible then self:Hide() else self:Show() end
end

--- Minimizes to the title bar / restores.
function Window:ToggleMinimize()
	if self.Is3D then return end
	local Anim, Config = self.Ctx.Anim, self.Ctx.Config
	self.Minimized = not self.Minimized
	self:HidePopup()
	if self.Minimized then
		self.Grip.Visible = false
		Anim.Tween(self.Holder, { Size = UDim2.fromOffset(self.Size.X, Config.Window.TitleBarHeight) }, Config.Animation.Normal)
		task.delay(Config.Animation.Normal, function()
			if self.Minimized then self.Body.Visible = false end
		end)
	else
		self.Body.Visible = true
		self.Grip.Visible = self.Resizable
		Anim.Tween(self.Holder, { Size = UDim2.fromOffset(self.Size.X, self.Size.Y) }, Config.Animation.Normal)
	end
end

--- Changes the window title. @param text string
function Window:SetTitle(text)
	self.TitleLabel.Text = tostring(text)
end

--- Switches theme in real time. @param name string "Dark" | "Light" | "HighContrast" | custom
function Window:SetTheme(name)
	return self.Ctx.Theme:Set(name, true)
end

--- Shows a toast. @param props table see Notifications:Notify
function Window:Notify(props)
	self.Ctx:GetScreenGui()
	return self.Ctx.Notifications:Notify(props)
end

-- popups -------------------------------------------------------------------------------------
--- Displays a frame in the popup layer (one at a time). A click outside closes it.
-- @param frame GuiObject @param onClose function|nil
function Window:ShowPopup(frame, onClose)
	self:HidePopup()
	frame.ZIndex = 2
	frame.Active = true
	frame.Parent = self.Overlay
	self.Overlay.Visible = true
	self._popup = { Frame = frame, OnClose = onClose }
end

--- Closes the current popup, if any.
function Window:HidePopup()
	local p = self._popup
	if not p then return end
	self._popup = nil
	p.Frame.Parent = nil
	self.Overlay.Visible = false
	if p.OnClose then Util.Call(p.OnClose) end
end

-- tabs ---------------------------------------------------------------------------------------------
--- Adds a sidebar tab.
-- @param props string|table { Name, Icon, Build = function(tab) } (Build runs lazily on first open)
-- @return Tab container (has all Add* methods)
function Window:AddTab(props)
	props = type(props) == "string" and { Name = props } or (props or {})
	local ctx = self.Ctx
	local Config, T, Anim = ctx.Config, ctx.Theme, ctx.Anim
	local name = tostring(props.Name or ("Tab " .. (#self.Tabs + 1)))
	local tab = setmetatable({ Ctx = ctx, Window = self, Name = name, _order = 0, _build = props.Build, Built = props.Build == nil }, Tab)
	tab.Scope = tab

	local page = Util.Create("ScrollingFrame", {
		Name = "Page_" .. name, Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1), Parent = self.Content,
	}, { Util.List(Config.ElementGap), Util.Padding(Config.Padding) })
	T:Bind(page, { ScrollBarImageColor3 = "Stroke" })
	tab.Page, tab.Frame = page, page

	local btn = Util.Create("TextButton", {
		Name = "Tab_" .. name, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36), LayoutOrder = #self.Tabs + 1, Parent = self.TabList,
	}, { Util.Corner(Config.RadiusSmall) })
	local bar = Util.Create("Frame", { Name = "Indicator", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(3, 0), Parent = btn }, { Util.Corner("full") })
	T:Bind(bar, { BackgroundColor3 = "Accent" })

	local icon
	if props.Icon then
		icon = Util.Create("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(18, 18),
			Image = ctx:ResolveIcon(props.Icon), Parent = btn })
	else
		icon = Util.Label({ Name = "Monogram", Text = name:sub(1, 1):upper(), Font = Config.FontBold, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(18, 18), Parent = btn })
	end
	local label = Util.Label({ Name = "Label", Text = name, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -44, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
	btn:SetAttribute("A11yRole", "tab")
	btn:SetAttribute("A11yLabel", name)

	local hover = false
	local isImage = icon:IsA("ImageLabel")
	local function render(animate)
		local active = self.Current == tab
		local dur = animate and Config.Animation.Fast or 0
		local col = T:Get(active and "Text" or "TextMuted")
		Anim.Tween(btn, { BackgroundTransparency = active and 0 or (hover and 0.5 or 1), BackgroundColor3 = T:Get(active and "SurfaceAlt" or "Hover") }, dur)
		Anim.Tween(label, { TextColor3 = col }, dur)
		Anim.Tween(icon, isImage and { ImageColor3 = active and T:Get("Accent") or col } or { TextColor3 = active and T:Get("Accent") or col }, dur)
		Anim.Tween(bar, { BackgroundTransparency = active and 0 or 1, Size = UDim2.fromOffset(3, active and 18 or 0) }, dur)
	end
	tab.Render = render
	tab._applyCompact = function(compact)
		label.Visible = not compact
		icon.Position = compact and UDim2.new(0.5, -9, 0.5, 0) or UDim2.new(0, 14, 0.5, 0)
	end
	tab._applyCompact(self.Compact)
	self.Maid:Give(btn.MouseEnter:Connect(function() hover = true; render(true) end))
	self.Maid:Give(btn.MouseLeave:Connect(function() hover = false; render(true) end))
	self.Maid:Give(btn.Activated:Connect(function() self:SelectTab(tab) end))
	ctx.Theme:Track(tab, function() render(true) end)
	self.Maid:Give(function() ctx.Theme:Untrack(tab) end)

	table.insert(self.Tabs, tab)
	render(false)
	if not self.Current then
		self:SelectTab(tab)
	end
	return tab
end

--- Selects a tab with a fade/slide transition (builds it first if lazy).
-- @param tab table|string|number Tab object, name or index
function Window:SelectTab(tab)
	if type(tab) == "number" then
		tab = self.Tabs[tab]
	elseif type(tab) == "string" then
		for _, t in ipairs(self.Tabs) do
			if t.Name == tab then tab = t break end
		end
	end
	if type(tab) ~= "table" or self.Current == tab then return end
	local Anim, Config = self.Ctx.Anim, self.Ctx.Config
	local prev = self.Current
	self.Current = tab
	self:HidePopup()
	if prev then
		prev.Page.Visible = false
		prev.Render(true)
	end
	if not tab.Built then
		tab.Built = true
		Util.Call(tab._build, tab)
	end
	tab.Page.Position = UDim2.fromOffset(0, 10)
	tab.Page.Visible = true
	tab.Render(true)
	Anim.Tween(tab.Page, { Position = UDim2.new() }, Config.Animation.Normal)
	self.Cover.BackgroundTransparency = 0
	self.Cover.Visible = true
	local t = Anim.Tween(self.Cover, { BackgroundTransparency = 1 }, Config.Animation.Normal)
	if t then
		t.Completed:Once(function()
			if self.Current == tab then self.Cover.Visible = false end
		end)
	else
		self.Cover.Visible = false
	end
	self.Focus:SetScope(tab)
	self.TabChanged:Fire(tab)
end

--- Destroys the window and everything in it.
function Window:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	self.Visible = false
	for el in pairs(self.Elements) do
		if el.Destroy then el:Destroy() end
	end
	table.clear(self.Elements)
	self.Opened:Destroy()
	self.Closed:Destroy()
	self.TabChanged:Destroy()
	self.Maid:Clean()
end

return Window

end


-- ===== Components/Basic =====
rawget(__comp, "_kids")["Basic"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Basic
	Label, Section, Divider — static, theme-bound elements.
]]
local Element = require(script.Parent.Element)

local Basic = {}

-- Label --------------------------------------------------------------------------
local Label = Element.extend()
Label.__index = Label

--- @param container table @param props table { Text=string, Muted=boolean, Wrap=boolean(default true) }
function Label.new(container, props)
	local ctx = container.Ctx
	local Util = ctx.Util
	local self = setmetatable({}, Label)
	local lbl = Util.Label({
		Name = "Label", Text = tostring(props.Text or ""), TextWrapped = props.Wrap ~= false,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = container:_nextOrder(),
		TextSize = props.Muted and ctx.Config.TextSizeSmall or ctx.Config.TextSize, Parent = container.Frame,
	}, nil)
	Util.Padding(2, 4).Parent = lbl
	ctx.Theme:Bind(lbl, { TextColor3 = props.Muted and "TextMuted" or "Text" })
	self.Label = lbl
	self:_init(container, lbl, props, "label")
	return self
end

--- Changes the text. @param text string
function Label:SetText(text)
	self.Label.Text = tostring(text)
end
Basic.Label = Label

-- Section ------------------------------------------------------------------------
local Section = Element.extend()
Section.__index = Section

--- @param container table @param props table { Text=string }
function Section.new(container, props)
	local ctx = container.Ctx
	local Util = ctx.Util
	local self = setmetatable({}, Section)
	local frame = Util.Create("Frame", {
		Name = "Section", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = container:_nextOrder(), Parent = container.Frame,
	})
	local lbl = Util.Label({
		Name = "Label", Text = string.upper(tostring(props.Text or "")), Font = ctx.Config.FontBold, TextSize = ctx.Config.TextSizeSmall,
		Position = UDim2.fromOffset(2, 4), Size = UDim2.new(1, -2, 1, -4), TextYAlignment = Enum.TextYAlignment.Bottom, Parent = frame,
	})
	ctx.Theme:Bind(lbl, { TextColor3 = "TextMuted" })
	self.Label = lbl
	self:_init(container, frame, props, "heading")
	return self
end

--- Changes the title. @param text string
function Section:SetText(text)
	self.Label.Text = string.upper(tostring(text))
end
Basic.Section = Section

-- Divider ------------------------------------------------------------------------
local Divider = Element.extend()
Divider.__index = Divider

--- @param container table @param props table (unused)
function Divider.new(container, props)
	local ctx = container.Ctx
	local self = setmetatable({}, Divider)
	local line = ctx.Util.Create("Frame", {
		Name = "Divider", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = container:_nextOrder(), Parent = container.Frame,
	})
	ctx.Theme:Bind(line, { BackgroundColor3 = "Stroke" })
	self:_init(container, line, props or {}, "separator")
	return self
end
Basic.Divider = Divider

return Basic

end


-- ===== Components/Button =====
rawget(__comp, "_kids")["Button"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Button
	Styles: Solid | Outline | Gradient | Ghost. Hover / press / focus states and a click ripple.
	Usage: tab:AddButton({ Text = "Save", Style = "Gradient", Callback = function() end })
]]
local Element = require(script.Parent.Element)

local Button = Element.extend()

--- @param container table
-- @param props table { Text, Style, Callback, Color=Color3, Icon, Tooltip, Enabled }
-- @return Button
function Button.new(container, props)
	local ctx = container.Ctx
	local Util, Config, T = ctx.Util, ctx.Config, ctx.Theme
	local self = setmetatable({}, Button)
	self.Style = ({ Solid = "Solid", Outline = "Outline", Gradient = "Gradient", Ghost = "Ghost" })[props.Style or "Solid"] or "Solid"

	local row, stroke = Element.CreateRow(container, props, nil, "TextButton")
	row.ClipsDescendants = true
	self.Row, self.Stroke = row, stroke

	self.Gradient = Util.Create("UIGradient", { Rotation = 20, Enabled = self.Style == "Gradient", Parent = row })
	self.Ripple = Util.Create("Frame", {
		Name = "Ripple", Visible = false, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75,
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(0, 0), ZIndex = 1, Parent = row,
	}, { Util.Corner("full") })

	local hasIcon = props.Icon ~= nil
	if hasIcon then
		self.Icon = Util.Create("ImageLabel", {
			Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(16, 16), Image = ctx:ResolveIcon(props.Icon), ZIndex = 2, Parent = row,
		})
	end
	self.Label = Util.Label({
		Name = "Label", Text = tostring(props.Text or "Button"), Font = Config.FontBold, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(hasIcon and 30 or 8, 0), Size = UDim2.new(1, hasIcon and -38 or -16, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, Parent = row,
	})

	self:_init(container, row, props, "button")
	self:_interact(row)

	self.Maid:Give(row.Activated:Connect(function()
		if self.Enabled then
			self:_fire(true, tostring(props.Text or "Button") .. " activated")
		end
	end))
	self.Maid:Give(row.InputBegan:Connect(function(i)
		if self.Enabled and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			self:_ripple(i)
		end
	end))
	self:Focusable({ Activate = function() self:Click() end })
	self:_render(false)
	return self
end

function Button:_ripple(input)
	local Util, Anim = self.Ctx.Util, self.Ctx.Anim
	local row, rip = self.Row, self.Ripple
	local p = Util.PointerPos(input, self.Container.Window.Is3D) - row.AbsolutePosition
	local w, h = row.AbsoluteSize.X, row.AbsoluteSize.Y
	local far = math.sqrt(math.max(p.X, w - p.X) ^ 2 + math.max(p.Y, h - p.Y) ^ 2) * 2
	if self._rip then self._rip:Cancel() end
	rip.Position = UDim2.fromOffset(p.X, p.Y)
	rip.Size = UDim2.fromOffset(0, 0)
	rip.BackgroundTransparency = 0.7
	rip.Visible = true
	Anim.Tween(rip, { BackgroundTransparency = 1 }, 0.5, Enum.EasingStyle.Quad)
	self._rip = Anim.Number(0, far, 0.5, "CubicOut", function(v)
		rip.Size = UDim2.fromOffset(v, v)
	end, function()
		rip.Visible = false
	end)
end

function Button:_render(animate)
	local T, Anim, S = self.Ctx.Theme, self.Ctx.Anim, self.State
	local dur = animate and self.Ctx.Config.Animation.Fast or 0
	local accent = self.Props.Color or T:Get("Accent")
	local dim = self.Enabled and 0 or 0.55
	local bg, bgT, textColor = nil, 0, T:Get("AccentText")
	local strokeColor, strokeT = T:Get("Text"), 1

	if self.Style == "Solid" then
		bg = accent
		if S.press then bg = accent:Lerp(Color3.new(0, 0, 0), 0.2)
		elseif S.hover or S.focus then bg = accent:Lerp(Color3.new(1, 1, 1), 0.12) end
		bgT = dim
	elseif self.Style == "Gradient" then
		self.Gradient.Color = ColorSequence.new(accent, T:Get("AccentAlt"))
		local v = S.press and 0.78 or ((S.hover or S.focus) and 1 or 0.92)
		bg, bgT = Color3.new(v, v, v), dim
	elseif self.Style == "Outline" then
		bg = accent
		bgT = S.press and 0.75 or (S.hover and 0.88 or 1)
		textColor, strokeColor, strokeT = accent, accent, 0
	else -- Ghost
		bg = T:Get("Hover")
		bgT = S.press and 0.2 or (S.hover and 0.5 or 1)
		textColor = T:Get("Text")
	end
	if S.focus then
		strokeColor, strokeT = T:Get("Text"), 0
	end
	if not self.Enabled and (self.Style == "Outline" or self.Style == "Ghost") then
		textColor = T:Get("TextMuted")
	end
	Anim.Tween(self.Row, { BackgroundColor3 = bg, BackgroundTransparency = bgT }, dur)
	Anim.Tween(self.Stroke, { Color = strokeColor, Transparency = strokeT, Thickness = S.focus and 2 or 1.5 }, dur)
	Anim.Tween(self.Label, { TextColor3 = textColor }, dur)
	if self.Icon then
		Anim.Tween(self.Icon, { ImageColor3 = textColor }, dur)
	end
end

--- Programmatically clicks the button.
function Button:Click()
	if self.Enabled then
		self:_fire(true)
	end
end

--- Changes the caption. @param text string
function Button:SetText(text)
	self.Label.Text = tostring(text)
end

--- Changes the style. @param style string "Solid"|"Outline"|"Gradient"|"Ghost"
function Button:SetStyle(style)
	self.Style = ({ Solid = "Solid", Outline = "Outline", Gradient = "Gradient", Ghost = "Ghost" })[style] or self.Style
	self.Gradient.Enabled = self.Style == "Gradient"
	self:_render(true)
end

return Button

end


-- ===== Components/Checkbox =====
rawget(__comp, "_kids")["Checkbox"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Checkbox
	Usage: local c = tab:AddCheckbox({ Text = "Remember me", Default = true, Color = Color3.fromRGB(52,211,153) })
]]
local Element = require(script.Parent.Element)
local Widgets = require(script.Parent.Widgets)

local Checkbox = Element.extend()

--- @param container table @param props table { Text, Default=boolean, Color=Color3, Callback, Tooltip }
-- @return Checkbox
function Checkbox.new(container, props)
	local ctx = container.Ctx
	local self = setmetatable({}, Checkbox)
	local row, stroke = Element.CreateRow(container, props, nil, "TextButton")
	self.Row, self.Stroke = row, stroke
	self.Box = Widgets.CheckBox(ctx, row, 18)
	self.Box.Frame.AnchorPoint = Vector2.new(0, 0.5)
	self.Box.Frame.Position = UDim2.new(0, 12, 0.5, 0)
	self.Box.SetColor(props.Color)
	self.Label = ctx.Util.Label({
		Name = "Label", Text = tostring(props.Text or "Checkbox"), Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -52, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	self.Value = props.Default == true
	self:_init(container, row, props, "checkbox")
	self:_interact(row)
	self.Maid:Give(row.Activated:Connect(function()
		if self.Enabled then self:Set(not self.Value) end
	end))
	self:Focusable({
		Activate = function() if self.Enabled then self:Set(not self.Value) end end,
		Adjust = function(dir) if self.Enabled then self:Set(dir > 0) end end,
	})
	self:_render(false)
	return self
end

--- @param value boolean @param silent boolean|nil
function Checkbox:Set(value, silent)
	value = value and true or false
	if value == self.Value then return end
	self.Value = value
	self:_render(true)
	if not silent then
		self:_fire(value, tostring(self.Props.Text or "Checkbox") .. (value and " checked" or " unchecked"))
	end
end

--- @return boolean
function Checkbox:Get()
	return self.Value
end

function Checkbox:_render(animate)
	self:_renderRow(self.Row, self.Stroke, animate)
	self.Box.Set(self.Value, animate)
end

return Checkbox

end


-- ===== Components/ColorPicker =====
rawget(__comp, "_kids")["ColorPicker"]._fn = function(script, require)
--[[
	Lumen UI :: Components/ColorPicker
	Saturation/value square, hue bar, hex + RGB inputs, optional 2-stop gradient mode.
	Usage: local c = tab:AddColorPicker({ Text = "Accent", Default = Color3.fromRGB(110,99,255), Callback = function(color) end })
	       tab:AddColorPicker({ Text = "Fade", Gradient = true, Default = {Color3.new(1,0,0), Color3.new(0,0,1)},
	           Callback = function(colorSequence) end })
	On 3D mounts (Surface/Billboard) pointer picking is best-effort; use the hex/RGB boxes there.
]]
local Element = require(script.Parent.Element)

local ColorPicker = Element.extend()
local W = 224

--- @param container table
-- @param props table { Text, Default=Color3 | {Color3,Color3} | ColorSequence, Gradient=boolean, Callback }
-- @return ColorPicker
function ColorPicker.new(container, props)
	local ctx = container.Ctx
	local Util, Config = ctx.Util, ctx.Config
	local self = setmetatable({}, ColorPicker)
	self.Gradient = props.Gradient == true
	self.Active = 1
	local base = Color3.fromRGB(110, 99, 255)
	local d = props.Default
	if self.Gradient then
		local a, b = base, Color3.fromRGB(56, 189, 248)
		if typeof(d) == "ColorSequence" then
			a, b = d.Keypoints[1].Value, d.Keypoints[#d.Keypoints].Value
		elseif type(d) == "table" then
			a = typeof(d[1]) == "Color3" and d[1] or a
			b = typeof(d[2]) == "Color3" and d[2] or b
		end
		self.Colors = { a, b }
	else
		self.Colors = { typeof(d) == "Color3" and d or base }
	end
	self.H, self.S, self.V = self.Colors[1]:ToHSV()

	local row, stroke = Element.CreateRow(container, props, nil, "TextButton")
	self.Row, self.Stroke = row, stroke
	self.Label = Util.Label({ Name = "Label", Text = tostring(props.Text or "Color"), Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -80, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	self.Swatch = Util.Create("Frame", { Name = "Swatch", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(46, 20), Parent = row }, { Util.Corner(5) })
	self.SwatchStroke = Util.Stroke(1)
	self.SwatchStroke.Parent = self.Swatch
	self.SwatchGradient = Util.Create("UIGradient", { Enabled = self.Gradient, Parent = self.Swatch })

	self:_init(container, row, props, "colorpicker")
	self:_interact(row)
	self.Maid:Give(row.Activated:Connect(function() if self.Enabled then self:_open() end end))
	self.Maid:Give(function()
		local win = self.Container.Window
		if self.Popup then
			if self.IsOpen and win._popup and win._popup.Frame == self.Popup then win:HidePopup() end
			self.Popup:Destroy()
		end
	end)
	self:Focusable({ Activate = function() if self.Enabled then self:_open() end end })
	self:_swatch()
	self:_render(false)
	return self
end

function ColorPicker:_swatch()
	if self.Gradient then
		self.Swatch.BackgroundColor3 = Color3.new(1, 1, 1)
		self.SwatchGradient.Color = ColorSequence.new(self.Colors[1], self.Colors[2])
	else
		self.Swatch.BackgroundColor3 = self.Colors[1]
	end
end

function ColorPicker:_buildPopup()
	local ctx = self.Ctx
	local Util, Config, T = ctx.Util, ctx.Config, ctx.Theme
	local popup = Util.Create("Frame", { Name = "ColorPopup", BorderSizePixel = 0 }, { Util.Corner(Config.RadiusSmall) })
	self.PopupStroke = Util.Stroke(1)
	self.PopupStroke.Parent = popup
	local y = 12
	self.Inputs = {}

	if self.Gradient then
		self.StopButtons = {}
		for i, name in ipairs({ "Start", "End" }) do
			local b = Util.Create("TextButton", { Name = name, Text = name, Font = Config.FontBold, TextSize = Config.TextSizeSmall + 1,
				AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(12 + (i - 1) * 104, y),
				Size = UDim2.fromOffset(96, 24), Parent = popup }, { Util.Corner(5) })
			self.StopButtons[i] = b
			self.Maid:Give(b.Activated:Connect(function()
				self.Active = i
				self.H, self.S, self.V = self.Colors[i]:ToHSV()
				self:_refreshUI()
			end))
		end
		y = y + 34
	end

	local sv = Util.Create("Frame", { Name = "SV", BorderSizePixel = 0, ClipsDescendants = true, Position = UDim2.fromOffset(12, y),
		Size = UDim2.fromOffset(200, 120), Parent = popup }, { Util.Corner(6) })
	local white = Util.Create("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = sv },
		{ Util.Create("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	local black = Util.Create("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = sv },
		{ Util.Create("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90 }) })
	local svMarker = Util.Create("Frame", { Name = "Marker", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12), ZIndex = 4, Parent = sv }, { Util.Corner("full"), Util.Stroke(2, Color3.new(1, 1, 1)) })
	local svHit = Util.Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ZIndex = 5,
		Size = UDim2.fromScale(1, 1), Parent = sv })
	y = y + 130

	local hue = Util.Create("Frame", { Name = "Hue", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(200, 14), Parent = popup }, { Util.Corner("full") })
	local keys = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 == 1 and 0 or i / 6, 1, 1)))
	end
	Util.Create("UIGradient", { Color = ColorSequence.new(keys), Parent = hue })
	local hueMarker = Util.Create("Frame", { Name = "Marker", BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 20), ZIndex = 4, Parent = hue },
		{ Util.Corner(3), Util.Stroke(1.5, Color3.new(0.1, 0.1, 0.1)) })
	local hueHit = Util.Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ZIndex = 5,
		Position = UDim2.fromOffset(-4, -4), Size = UDim2.new(1, 8, 1, 8), Parent = hue })
	y = y + 26

	local function input(name, x, w)
		local tb = Util.Create("TextBox", { Name = name, BorderSizePixel = 0, ClearTextOnFocus = false, Font = Config.Font,
			TextSize = Config.TextSizeSmall + 1, Text = "", PlaceholderText = name, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 26), Parent = popup }, { Util.Corner(5) })
		local st = Util.Stroke(1)
		st.Parent = tb
		self.Inputs[name] = { Box = tb, Stroke = st }
		return tb
	end
	local hex = input("HEX", 12, 84)
	local r, g, b = input("R", 102, 34), input("G", 140, 34), input("B", 178, 34)
	y = y + 38

	self.Maid:Give(hex.FocusLost:Connect(function()
		local c = Util.HexToColor3(hex.Text)
		if c then self:_setFromColor(c) else self:_refreshUI() end
	end))
	local function rgbCommit()
		local nr, ng, nb = tonumber(r.Text), tonumber(g.Text), tonumber(b.Text)
		if nr and ng and nb then
			self:_setFromColor(Color3.fromRGB(Util.Clamp(nr, 0, 255), Util.Clamp(ng, 0, 255), Util.Clamp(nb, 0, 255)))
		else
			self:_refreshUI()
		end
	end
	for _, tb in ipairs({ r, g, b }) do
		self.Maid:Give(tb.FocusLost:Connect(rgbCommit))
	end

	local is3D = self.Container.Window.Is3D
	self.Maid:Give(ctx.Drag.Attach(svHit, {
		Began = function(i) self:_pickSV(i, sv, is3D) end,
		Changed = function(i) self:_pickSV(i, sv, is3D) end,
	}))
	self.Maid:Give(ctx.Drag.Attach(hueHit, {
		Began = function(i) self:_pickHue(i, hue, is3D) end,
		Changed = function(i) self:_pickHue(i, hue, is3D) end,
	}))
	popup.Size = UDim2.fromOffset(W, y)
	self.PopupH = y
	self.Popup, self.SV, self.SVMarker, self.HueMarker = popup, sv, svMarker, hueMarker
	self.HexBox, self.RBox, self.GBox, self.BBox = hex, r, g, b
end

function ColorPicker:_pickSV(input, sv, is3D)
	local Util = self.Ctx.Util
	local p = Util.PointerPos(input, is3D)
	self.S = Util.Clamp((p.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
	self.V = 1 - Util.Clamp((p.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
	self:_commit()
end

function ColorPicker:_pickHue(input, hue, is3D)
	local Util = self.Ctx.Util
	local p = Util.PointerPos(input, is3D)
	self.H = Util.Clamp((p.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 0.9999)
	self:_commit()
end

function ColorPicker:_setFromColor(c)
	self.H, self.S, self.V = c:ToHSV()
	self:_commit()
end

function ColorPicker:_commit()
	self.Colors[self.Active] = Color3.fromHSV(self.H, self.S, self.V)
	self:_swatch()
	self:_refreshUI()
	self:_fire(self:Get())
end

function ColorPicker:_refreshUI()
	if not self.Popup then return end
	local T, Util = self.Ctx.Theme, self.Ctx.Util
	local c = self.Colors[self.Active]
	self.SV.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
	self.SVMarker.Position = UDim2.fromScale(self.S, 1 - self.V)
	self.HueMarker.Position = UDim2.fromScale(self.H, 0.5)
	if not self.HexBox:IsFocused() then self.HexBox.Text = Util.Color3ToHex(c) end
	local function set(box, v) if not box:IsFocused() then box.Text = tostring(math.floor(v * 255 + 0.5)) end end
	set(self.RBox, c.R) set(self.GBox, c.G) set(self.BBox, c.B)
	if self.StopButtons then
		for i, b in ipairs(self.StopButtons) do
			local on = i == self.Active
			b.BackgroundColor3 = T:Get(on and "Accent" or "SurfaceAlt")
			b.TextColor3 = T:Get(on and "AccentText" or "Text")
		end
	end
end

function ColorPicker:_skinPopup()
	local T = self.Ctx.Theme
	self.Popup.BackgroundColor3 = T:Get("Surface")
	self.PopupStroke.Color = T:Get("Stroke")
	for _, inp in pairs(self.Inputs) do
		inp.Box.BackgroundColor3 = T:Get("SurfaceAlt")
		inp.Box.TextColor3 = T:Get("Text")
		inp.Box.PlaceholderColor3 = T:Get("TextMuted")
		inp.Stroke.Color = T:Get("Stroke")
	end
end

function ColorPicker:_open()
	if self.IsOpen then return end
	if not self.Popup then self:_buildPopup() end
	local win = self.Container.Window
	self:_skinPopup()
	self:_refreshUI()
	self.IsOpen = true
	win:ShowPopup(self.Popup, function() self.IsOpen = false end)
	local overlay = win.Overlay
	local ap = self.Row.AbsolutePosition - overlay.AbsolutePosition
	local x = math.max(6, ap.X + self.Row.AbsoluteSize.X - W)
	local y = ap.Y + self.Row.AbsoluteSize.Y + 4
	if y + self.PopupH > overlay.AbsoluteSize.Y - 6 then
		y = math.max(6, ap.Y - self.PopupH - 4)
	end
	self.Popup.Position = UDim2.fromOffset(x, y)
end

--- Sets the color(s). @param value Color3|table|ColorSequence @param silent boolean|nil
function ColorPicker:Set(value, silent)
	if self.Gradient then
		local a, b
		if typeof(value) == "ColorSequence" then
			a, b = value.Keypoints[1].Value, value.Keypoints[#value.Keypoints].Value
		elseif type(value) == "table" then
			a, b = value[1], value[2]
		end
		if typeof(a) == "Color3" then self.Colors[1] = a end
		if typeof(b) == "Color3" then self.Colors[2] = b end
	elseif typeof(value) == "Color3" then
		self.Colors[1] = value
	else
		return
	end
	self.H, self.S, self.V = self.Colors[self.Active]:ToHSV()
	self:_swatch()
	self:_refreshUI()
	if not silent then self:_fire(self:Get()) end
end

--- @return Color3|ColorSequence Color3 in solid mode, ColorSequence in gradient mode
function ColorPicker:Get()
	if self.Gradient then
		return ColorSequence.new(self.Colors[1], self.Colors[2])
	end
	return self.Colors[1]
end

--- @return table array of the Color3 stops
function ColorPicker:GetColors()
	return table.clone(self.Colors)
end

function ColorPicker:_render(animate)
	self:_renderRow(self.Row, self.Stroke, animate)
	self.SwatchStroke.Color = self.Ctx.Theme:Get("Stroke")
	if self.Popup then
		self:_skinPopup()
		self:_refreshUI()
	end
end

return ColorPicker

end


-- ===== Components/Dropdown =====
rawget(__comp, "_kids")["Dropdown"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Dropdown
	Searchable, multi-select option, pooled option rows, flips upward when there is no room below.
	Usage: local d = tab:AddDropdown({ Text = "Map", Options = {"Forest","Desert","Snow"}, Default = "Forest",
	           Searchable = true, Callback = function(value) end })
	       tab:AddDropdown({ Text = "Tags", Options = {...}, Multi = true, Callback = function(list) end })
	Options may be strings or { Text = "Shown", Value = anything }.
]]
local Element = require(script.Parent.Element)
local Widgets = require(script.Parent.Widgets)

local Dropdown = Element.extend()
local ROW_H = 30

local function normalize(options)
	local list = {}
	for _, o in ipairs(options or {}) do
		if type(o) == "table" then
			table.insert(list, { Text = tostring(o.Text or o.Value), Value = o.Value ~= nil and o.Value or o.Text })
		else
			table.insert(list, { Text = tostring(o), Value = o })
		end
	end
	return list
end

--- @param container table
-- @param props table { Text, Options, Default (value | array when Multi), Multi, Searchable, MaxVisible=6, Placeholder, Callback }
-- @return Dropdown
function Dropdown.new(container, props)
	local ctx = container.Ctx
	local Util, Config = ctx.Util, ctx.Config
	local self = setmetatable({}, Dropdown)
	self.Multi = props.Multi == true
	self.Searchable = props.Searchable == true
	self.MaxVisible = math.max(1, tonumber(props.MaxVisible) or 6)
	self.Placeholder = tostring(props.Placeholder or "Select...")
	self.Options = normalize(props.Options)
	self.Selected = {}
	self.Open = false
	self.Active = {}

	local row, stroke = Element.CreateRow(container, props, nil, "TextButton")
	self.Row, self.Stroke = row, stroke
	local hasLabel = props.Text ~= nil and props.Text ~= ""
	if hasLabel then
		self.Label = Util.Label({ Name = "Label", Text = tostring(props.Text), Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.42, -12, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	end
	self.ValueLabel = Util.Label({
		Name = "Value", TextXAlignment = hasLabel and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -36, 0.5, 0),
		Size = hasLabel and UDim2.new(0.58, -44, 1, 0) or UDim2.new(1, -52, 1, 0), Parent = row,
	})
	if not hasLabel then self.ValueLabel.Position = UDim2.new(1, -36, 0.5, 0) end
	self.Chevron = Widgets.Chevron(ctx, row)
	self.Chevron.Frame.Position = UDim2.new(1, -20, 0.5, 0)

	self:_init(container, row, props, "combobox")
	self:_interact(row)
	self.RowPool = ctx.Pool.new(function() return self:_buildRow() end, function(r)
		r.Opt, r.Hover = nil, false
		r.Button.Parent = nil
	end, 24, function(r) r.Button:Destroy() end)
	self.Maid:Give(self.RowPool)
	self.Maid:Give(function()
		local win = self.Container.Window
		if self.Open and win and win._popup and win._popup.Frame == self.Popup then win:HidePopup() end
		if self.Popup then self.Popup:Destroy() end
	end)

	self.Maid:Give(row.Activated:Connect(function()
		if self.Open then self.Container.Window:HidePopup() else self:_open() end
	end))
	self:Focusable({
		Activate = function() if self.Open then self.Container.Window:HidePopup() else self:_open() end end,
		Adjust = function(dir) self:_cycle(dir) end,
	})

	if props.Default ~= nil then self:Set(props.Default, true) end
	self:_updateDisplay()
	self:_render(false)
	return self
end

function Dropdown:_buildRow()
	local ctx = self.Ctx
	local Util = ctx.Util
	local r = {}
	local btn = Util.Create("TextButton", {
		Name = "Option", Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ROW_H),
	}, { Util.Corner(5) })
	local x = 10
	if self.Multi then
		r.Check = Widgets.CheckBox(ctx, btn, 16)
		r.Check.Frame.AnchorPoint = Vector2.new(0, 0.5)
		r.Check.Frame.Position = UDim2.new(0, 8, 0.5, 0)
		x = 32
	end
	r.Label = Util.Label({ Name = "Label", Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - 8, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
	r.Button = btn
	btn.MouseEnter:Connect(function() r.Hover = true; self:_skinRow(r, true) end)
	btn.MouseLeave:Connect(function() r.Hover = false; self:_skinRow(r, true) end)
	btn.Activated:Connect(function()
		if r.Opt then self:_choose(r.Opt) end
	end)
	return r
end

function Dropdown:_skinRow(r, animate)
	local T, Anim = self.Ctx.Theme, self.Ctx.Anim
	local dur = animate and self.Ctx.Config.Animation.Fast or 0
	local sel = r.Opt ~= nil and self.Selected[r.Opt.Value] == true
	local hi = sel and not self.Multi
	Anim.Tween(r.Button, { BackgroundTransparency = r.Hover and 0 or (hi and 0.45 or 1), BackgroundColor3 = T:Get(r.Hover and "Hover" or "SurfaceAlt") }, dur)
	Anim.Tween(r.Label, { TextColor3 = hi and T:Get("Accent") or T:Get("Text") }, dur)
	if r.Check then r.Check.Set(sel, animate) end
end

function Dropdown:_buildPopup()
	local ctx = self.Ctx
	local Util, Config = ctx.Util, ctx.Config
	local popup = Util.Create("Frame", { Name = "DropdownPopup", BorderSizePixel = 0, ClipsDescendants = true }, { Util.Corner(Config.RadiusSmall) })
	self.PopupStroke = Util.Stroke(1)
	self.PopupStroke.Parent = popup
	local top = 4
	if self.Searchable then
		self.Search = Util.Create("TextBox", {
			Name = "Search", BorderSizePixel = 0, ClearTextOnFocus = false, Font = Config.Font, TextSize = Config.TextSize,
			TextXAlignment = Enum.TextXAlignment.Left, Text = "", PlaceholderText = "Search...",
			Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 26), Parent = popup,
		}, { Util.Corner(5), Util.Padding(8, 0) })
		self.Maid:Give(self.Search:GetPropertyChangedSignal("Text"):Connect(function()
			self:_populate(self.Search.Text)
		end))
		top = 38
	end
	self.ListTop = top
	self.List = Util.Create("ScrollingFrame", {
		Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -(top + 4)), Parent = popup,
	}, { Util.List(2), Util.Padding(4, 0) })
	self.NoResults = Util.Label({
		Name = "Empty", Text = "No results", TextXAlignment = Enum.TextXAlignment.Center, Visible = false,
		Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 0, ROW_H), Parent = popup,
	})
	self.Popup = popup
end

function Dropdown:_skinPopup()
	local T = self.Ctx.Theme
	self.Popup.BackgroundColor3 = T:Get("Surface")
	self.PopupStroke.Color = T:Get("Stroke")
	self.List.ScrollBarImageColor3 = T:Get("Stroke")
	self.NoResults.TextColor3 = T:Get("TextMuted")
	if self.Search then
		self.Search.BackgroundColor3 = T:Get("SurfaceAlt")
		self.Search.TextColor3 = T:Get("Text")
		self.Search.PlaceholderColor3 = T:Get("TextMuted")
	end
end

function Dropdown:_releaseRows()
	for _, r in ipairs(self.Active) do self.RowPool:Release(r) end
	table.clear(self.Active)
end

function Dropdown:_populate(query)
	self:_releaseRows()
	local q = string.lower(query or "")
	local count = 0
	for _, opt in ipairs(self.Options) do
		if q == "" or string.find(string.lower(opt.Text), q, 1, true) then
			count = count + 1
			local r = self.RowPool:Acquire()
			r.Opt = opt
			r.Label.Text = opt.Text
			r.Button.LayoutOrder = count
			r.Button.Parent = self.List
			self:_skinRow(r, false)
			table.insert(self.Active, r)
		end
	end
	self.NoResults.Visible = count == 0
	self._height = self.ListTop + math.min(math.max(count, 1), self.MaxVisible) * (ROW_H + 2) + 8
	if self.Open then self:_place(false) end
end

function Dropdown:_place(animate)
	local win = self.Container.Window
	local overlay = win.Overlay
	local ap = self.Row.AbsolutePosition - overlay.AbsolutePosition
	local w, h = self.Row.AbsoluteSize.X, self._height
	local y = ap.Y + self.Row.AbsoluteSize.Y + 4
	if y + h > overlay.AbsoluteSize.Y - 6 then
		y = math.max(6, ap.Y - h - 4)
	end
	self.Popup.Position = UDim2.fromOffset(ap.X, y)
	if animate then
		self.Popup.Size = UDim2.fromOffset(w, 0)
		self.Ctx.Anim.Tween(self.Popup, { Size = UDim2.fromOffset(w, h) }, self.Ctx.Config.Animation.Normal)
	else
		self.Popup.Size = UDim2.fromOffset(w, h)
	end
end

function Dropdown:_open()
	if not self.Enabled or self.Open then return end
	if not self.Popup then self:_buildPopup() end
	self:_skinPopup()
	if self.Search then self.Search.Text = "" end
	self.Open = true
	self:_populate("")
	self.Container.Window:ShowPopup(self.Popup, function() self:_onClosed() end)
	self:_place(true)
	self.Chevron.SetOpen(true, true)
	if self.Search then
		task.defer(function()
			if self.Open and self.Search.Parent then self.Search:CaptureFocus() end
		end)
	end
end

function Dropdown:_onClosed()
	self.Open = false
	self:_releaseRows()
	self.Chevron.SetOpen(false, true)
end

function Dropdown:_choose(opt)
	if self.Multi then
		self.Selected[opt.Value] = not self.Selected[opt.Value] or nil
		for _, r in ipairs(self.Active) do self:_skinRow(r, true) end
		self:_updateDisplay()
		self:_fire(self:Get(), tostring(opt.Text))
	else
		local changed = not self.Selected[opt.Value]
		self.Selected = { [opt.Value] = true }
		self:_updateDisplay()
		self.Container.Window:HidePopup()
		if changed then self:_fire(opt.Value, tostring(opt.Text)) end
	end
end

function Dropdown:_cycle(dir)
	if self.Multi or #self.Options == 0 then return end
	local idx = 0
	for i, o in ipairs(self.Options) do
		if self.Selected[o.Value] then idx = i end
	end
	idx = ((idx - 1 + dir) % #self.Options) + 1
	self:_choose(self.Options[idx])
end

function Dropdown:_updateDisplay()
	local T = self.Ctx.Theme
	local names = {}
	for _, o in ipairs(self.Options) do
		if self.Selected[o.Value] then table.insert(names, o.Text) end
	end
	if #names == 0 then
		self.ValueLabel.Text = self.Placeholder
		self.ValueLabel.TextColor3 = T:Get("TextMuted")
	else
		self.ValueLabel.Text = table.concat(names, ", ")
		self.ValueLabel.TextColor3 = T:Get("Accent")
	end
end

--- Sets the selection. @param value any|table single value, or array of values when Multi @param silent boolean|nil
function Dropdown:Set(value, silent)
	local set = {}
	local known = {}
	for _, o in ipairs(self.Options) do known[o.Value] = true end
	if self.Multi then
		for _, v in ipairs(type(value) == "table" and value or { value }) do
			if known[v] then set[v] = true end
		end
	elseif known[value] then
		set[value] = true
	end
	self.Selected = set
	self:_updateDisplay()
	for _, r in ipairs(self.Active) do self:_skinRow(r, true) end
	if not silent then self:_fire(self:Get()) end
end

--- @return any|table selected value (nil when empty), or an array in option order when Multi
function Dropdown:Get()
	if self.Multi then
		local out = {}
		for _, o in ipairs(self.Options) do
			if self.Selected[o.Value] then table.insert(out, o.Value) end
		end
		return out
	end
	for _, o in ipairs(self.Options) do
		if self.Selected[o.Value] then return o.Value end
	end
	return nil
end

--- Replaces the options (selection of values that no longer exist is dropped).
-- @param options table array of strings or {Text, Value}
function Dropdown:SetOptions(options)
	self.Options = normalize(options)
	local keep = self:Get()
	self:Set(keep, true)
	if self.Open then self:_populate(self.Search and self.Search.Text or "") end
end

function Dropdown:_render(animate)
	self:_renderRow(self.Row, self.Stroke, animate)
	local T = self.Ctx.Theme
	self.Chevron.SetColor(T:Get("TextMuted"))
	self:_updateDisplay()
	if self.Popup then
		self:_skinPopup()
		for _, r in ipairs(self.Active) do self:_skinRow(r, animate) end
	end
end

return Dropdown

end


-- ===== Components/Element =====
rawget(__comp, "_kids")["Element"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Element
	Base class for all components: lifecycle (Maid), hover/press/focus state, tooltip,
	keyboard-focus registration, themed row rendering.
]]
local Element = {}
Element.__index = Element

--- Creates a subclass. @return table
function Element.extend()
	local class = {}
	class.__index = class
	setmetatable(class, { __index = Element })
	return class
end

--- Builds the standard element row (rounded, stroked). @return Instance row, UIStroke stroke
-- @param container table @param props table @param height number|nil @param className string|nil "Frame"|"TextButton"
function Element.CreateRow(container, props, height, className)
	local ctx = container.Ctx
	local Util = ctx.Util
	className = className or "Frame"
	local row = Util.Create(className, {
		Name = tostring(props.Name or props.Text or "Element"),
		Size = UDim2.new(1, 0, 0, height or ctx:ElementHeight()),
		BackgroundColor3 = ctx.Theme:Get("SurfaceAlt"),
		BorderSizePixel = 0,
		LayoutOrder = container:_nextOrder(),
		Parent = container.Frame,
	}, { Util.Corner(ctx.Config.RadiusSmall) })
	if className == "TextButton" then
		row.AutoButtonColor = false
		row.Text = ""
	end
	local stroke = Util.Stroke(1, ctx.Theme:Get("Stroke"))
	stroke.Parent = row
	return row, stroke
end

--- Shared initialisation. Call first in every constructor: self:_init(container, root, props, role)
-- @param container table @param root Instance @param props table @param role string accessibility role
function Element:_init(container, root, props, role)
	local ctx = container.Ctx
	self.Ctx, self.Container, self.Root, self.Props = ctx, container, root, props
	self.Maid = ctx.Maid.new()
	self.Changed = ctx.Signal.new()
	self.Enabled = props.Enabled ~= false
	self.State = { hover = false, press = false, focus = false }
	self.Maid:Give(self.Changed)
	self.Maid:Give(root)
	root:SetAttribute("A11yRole", role or "element")
	root:SetAttribute("A11yLabel", tostring(props.Text or props.Name or ""))
	ctx.Theme:Track(self, function(animated)
		if self._render and not self._destroyed then
			self:_render(animated)
		end
	end)
	self.Maid:Give(function()
		self._destroyed = true
		ctx.Theme:Untrack(self)
		if self._detachTooltip then self._detachTooltip() end
	end)
	if props.Tooltip then
		self:SetTooltip(props.Tooltip)
	end
end

--- Sets the hover tooltip. @param text string|function|nil
function Element:SetTooltip(text)
	if self._detachTooltip then
		self._detachTooltip()
		self._detachTooltip = nil
	end
	local tip = self.Ctx.Tooltip
	if text and tip and not self.Container.Window.Is3D then
		self._detachTooltip = tip:Attach(self.Root, text)
	end
end

--- Enables / disables interaction. @param on boolean
function Element:SetEnabled(on)
	self.Enabled = on and true or false
	self.Root:SetAttribute("A11yDisabled", not self.Enabled)
	if self._render then self:_render(true) end
end

--- Shows / hides the element. @param on boolean
function Element:SetVisible(on)
	self.Root.Visible = on and true or false
end

--- Destroys the element and releases all connections.
function Element:Destroy()
	if self._destroyed then return end
	self.Maid:Clean()
end

--- Hover / press tracking for a GuiObject; re-renders on change.
function Element:_interact(gui)
	local S = self.State
	self.Maid:Give(gui.MouseEnter:Connect(function() S.hover = true; self:_render(true) end))
	self.Maid:Give(gui.MouseLeave:Connect(function() S.hover = false; S.press = false; self:_render(true) end))
	self.Maid:Give(gui.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			S.press = true
			self:_render(true)
		end
	end))
	self.Maid:Give(gui.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			S.press = false
			self:_render(true)
		end
	end))
end

--- Registers this element for keyboard navigation.
-- @param spec table { Root, Label, Activate=fn, Adjust=fn(dir), SetFocused=fn(bool) }
function Element:Focusable(spec)
	local window = self.Container.Window
	if not window or not window.Focus then return end
	local item = {
		Root = spec.Root or self.Root,
		Label = spec.Label or tostring(self.Props.Text or ""),
		Activate = spec.Activate,
		Adjust = spec.Adjust,
		SetFocused = spec.SetFocused or function(on)
			self.State.focus = on
			self:_render(true)
		end,
		IsEnabled = function() return self.Enabled end,
	}
	local scope = self.Container.Scope
	window.Focus:Register(scope, item)
	self.Maid:Give(function() window.Focus:Unregister(scope, item) end)
	return item
end

--- Fires Changed + user callback (+ accessibility announcement).
function Element:_fire(value, announce)
	self.Changed:Fire(value)
	self.Ctx.Util.Call(self.Props.Callback, value)
	if announce then
		self.Ctx:Announce(announce)
	end
end

--- Tweens row background / stroke / label for hover + focus + disabled.
-- @param row Instance @param stroke UIStroke @param animate boolean @param state table|nil defaults to self.State
function Element:_renderRow(row, stroke, animate, state)
	local T, Anim = self.Ctx.Theme, self.Ctx.Anim
	local s = state or self.State
	local dur = animate and self.Ctx.Config.Animation.Fast or 0
	Anim.Tween(row, { BackgroundColor3 = T:Get((s.hover and self.Enabled) and "Hover" or "SurfaceAlt") }, dur)
	local color, thick = T:Get("Stroke"), 1
	if s.focus then
		color, thick = T:Get("Accent"), 2
	end
	Anim.Tween(stroke, { Color = color, Thickness = thick }, dur)
	if self.Label then
		Anim.Tween(self.Label, { TextColor3 = T:Get("Text"), TextTransparency = self.Enabled and 0 or 0.55 }, dur)
	end
end

function Element:_render() end

return Element

end


-- ===== Components/ProgressBar =====
rawget(__comp, "_kids")["ProgressBar"]._fn = function(script, require)
--[[
	Lumen UI :: Components/ProgressBar
	Linear or circular, percentage display, animated fill.
	Usage: local p = tab:AddProgressBar({ Text = "Download", Value = 0, Style = "Circular" })
	       p:SetValue(65)
	The ring is drawn from 72 tiny segments (no image assets) and only touched segments are repainted.
]]
local Element = require(script.Parent.Element)

local ProgressBar = Element.extend()
local SEGMENTS = 72

--- @param container table
-- @param props table { Text, Value=0, Min=0, Max=100, Style="Linear"|"Circular", ShowPercent=true, Animated=true, Color=Color3 }
-- @return ProgressBar
function ProgressBar.new(container, props)
	local ctx = container.Ctx
	local Util, Config = ctx.Util, ctx.Config
	local self = setmetatable({}, ProgressBar)
	self.Min, self.Max = tonumber(props.Min) or 0, tonumber(props.Max) or 100
	if self.Max <= self.Min then self.Max = self.Min + 1 end
	self.Circular = props.Style == "Circular"
	self.ShowPercent = props.ShowPercent ~= false
	self.Animated = props.Animated ~= false
	self.Value = self.Min
	self._shown = 0 -- displayed alpha 0..1

	local row, stroke = Element.CreateRow(container, props, self.Circular and 88 or 52, "Frame")
	self.Row, self.Stroke = row, stroke
	self.Label = Util.Label({
		Name = "Label", Text = tostring(props.Text or "Progress"), TextTruncate = Enum.TextTruncate.AtEnd,
		Position = self.Circular and UDim2.fromOffset(92, 0) or UDim2.fromOffset(12, 7),
		Size = self.Circular and UDim2.new(1, -104, 1, 0) or UDim2.new(1, -80, 0, 18), Parent = row,
	})
	self.Percent = Util.Label({
		Name = "Percent", Font = Config.FontBold, TextSize = self.Circular and Config.TextSizeSmall + 1 or Config.TextSize,
		TextXAlignment = self.Circular and Enum.TextXAlignment.Center or Enum.TextXAlignment.Right, Visible = self.ShowPercent,
		AnchorPoint = self.Circular and Vector2.new(0.5, 0.5) or Vector2.new(1, 0),
		Position = self.Circular and UDim2.fromOffset(46, 44) or UDim2.new(1, -12, 0, 7),
		Size = self.Circular and UDim2.fromOffset(48, 20) or UDim2.fromOffset(64, 18), Parent = row,
	})

	if self.Circular then
		local size, thick = 64, 6
		local ring = Util.Create("Frame", { Name = "Ring", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 12),
			Size = UDim2.fromOffset(size, size), Parent = row })
		local R = size / 2 - thick / 2
		local arc = 2 * math.pi * R / SEGMENTS + 1.6
		self.Segs = table.create(SEGMENTS)
		for i = 1, SEGMENTS do
			local th = (i - 0.5) / SEGMENTS * 2 * math.pi
			self.Segs[i] = Util.Create("Frame", {
				Name = "S" .. i, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(th),
				Position = UDim2.fromOffset(size / 2 + R * math.sin(th), size / 2 - R * math.cos(th)),
				Size = UDim2.fromOffset(arc, thick), Parent = ring,
			})
		end
		self._filled = 0
	else
		self.Track = Util.Create("Frame", { Name = "Track", BorderSizePixel = 0, Position = UDim2.new(0, 12, 1, -18),
			Size = UDim2.new(1, -24, 0, 8), Parent = row }, { Util.Corner("full") })
		self.Fill = Util.Create("Frame", { Name = "Fill", BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = self.Track },
			{ Util.Corner("full") })
	end

	self:_init(container, row, props, "progressbar")
	self.Color = props.Color
	self:_render(false)
	self:SetValue(tonumber(props.Value) or self.Min, true)
	return self
end

function ProgressBar:_paintRing(force)
	local T = self.Ctx.Theme
	local accent, track = self.Color or T:Get("Accent"), T:Get("Track")
	local n = math.floor(self._shown * SEGMENTS + 0.5)
	if force then
		for i = 1, SEGMENTS do self.Segs[i].BackgroundColor3 = i <= n and accent or track end
	elseif n > self._filled then
		for i = self._filled + 1, n do self.Segs[i].BackgroundColor3 = accent end
	elseif n < self._filled then
		for i = n + 1, self._filled do self.Segs[i].BackgroundColor3 = track end
	end
	self._filled = n
end

function ProgressBar:_display(alpha)
	self._shown = alpha
	self.Percent.Text = string.format("%d%%", math.floor(alpha * 100 + 0.5))
	if self.Circular then
		self:_paintRing(false)
	else
		self.Fill.Size = UDim2.fromScale(alpha, 1)
	end
end

--- Sets the value (clamped to Min..Max) with an animated fill.
-- @param value number @param instant boolean|nil skip animation
function ProgressBar:SetValue(value, instant)
	value = tonumber(value)
	if not value then return end
	self.Value = self.Ctx.Util.Clamp(value, self.Min, self.Max)
	local target = (self.Value - self.Min) / (self.Max - self.Min)
	if self._anim then self._anim:Cancel() end
	if instant or not self.Animated then
		self:_display(target)
	else
		self._anim = self.Ctx.Anim.Number(self._shown, target, 0.4, "CubicOut", function(a) self:_display(a) end)
	end
	self.Changed:Fire(self.Value)
end

--- @return number
function ProgressBar:GetValue()
	return self.Value
end

function ProgressBar:_render(animate)
	self:_renderRow(self.Row, self.Stroke, animate)
	local T = self.Ctx.Theme
	self.Percent.TextColor3 = T:Get("Text")
	if self.Circular then
		if self._filled then self:_paintRing(true) end
	else
		self.Track.BackgroundColor3 = T:Get("Track")
		self.Fill.BackgroundColor3 = self.Color or T:Get("Accent")
	end
end

return ProgressBar

end


-- ===== Components/RadioGroup =====
rawget(__comp, "_kids")["RadioGroup"]._fn = function(script, require)
--[[
	Lumen UI :: Components/RadioGroup
	Group management: exactly one option selected at a time.
	Usage: local r = tab:AddRadioGroup({ Text = "Quality", Options = {"Low","Medium","High"}, Default = "Medium",
	           Callback = function(value) end })
	Options may be strings or { Text = "Shown", Value = anything }.
]]
local Element = require(script.Parent.Element)
local Widgets = require(script.Parent.Widgets)

local RadioGroup = Element.extend()

local function normalize(options)
	local list = {}
	for _, o in ipairs(options or {}) do
		if type(o) == "table" then
			table.insert(list, { Text = tostring(o.Text or o.Value), Value = o.Value ~= nil and o.Value or o.Text })
		else
			table.insert(list, { Text = tostring(o), Value = o })
		end
	end
	return list
end

--- @param container table @param props table { Text, Options, Default, Color=Color3, Callback }
-- @return RadioGroup
function RadioGroup.new(container, props)
	local ctx = container.Ctx
	local Util, Config = ctx.Util, ctx.Config
	local self = setmetatable({}, RadioGroup)
	local root = Util.Create("Frame", {
		Name = tostring(props.Text or "RadioGroup"), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = container:_nextOrder(), Parent = container.Frame,
	}, { Util.List(4) })
	self.Frame = root
	if props.Text and props.Text ~= "" then
		local title = Util.Label({
			Name = "Title", Text = tostring(props.Text), Font = Config.FontBold, TextSize = Config.TextSizeSmall, LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 20), Parent = root,
		})
		ctx.Theme:Bind(title, { TextColor3 = "TextMuted" })
	end
	self.Options = {}
	self.Value = nil
	self:_init(container, root, props, "radiogroup")
	self.Color = props.Color

	local list = normalize(props.Options)
	for i, opt in ipairs(list) do
		local row, stroke = Element.CreateRow(container, { Name = opt.Text }, 32, "TextButton")
		row.LayoutOrder = i
		row.Parent = root
		local dot = Widgets.RadioDot(ctx, row, 18)
		dot.Frame.AnchorPoint = Vector2.new(0, 0.5)
		dot.Frame.Position = UDim2.new(0, 12, 0.5, 0)
		dot.SetColor(self.Color)
		local label = Util.Label({ Name = "Label", Text = opt.Text, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -52, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
		opt.Row, opt.Stroke, opt.Dot, opt.LabelObj = row, stroke, dot, label
		opt.State = { hover = false, press = false, focus = false }
		table.insert(self.Options, opt)

		self.Maid:Give(row.MouseEnter:Connect(function() opt.State.hover = true; self:_renderOption(opt, true) end))
		self.Maid:Give(row.MouseLeave:Connect(function() opt.State.hover = false; self:_renderOption(opt, true) end))
		self.Maid:Give(row.Activated:Connect(function()
			if self.Enabled then self:Set(opt.Value) end
		end))
		self:Focusable({
			Root = row, Label = (props.Text and (props.Text .. ": ") or "") .. opt.Text,
			Activate = function() self:Set(opt.Value) end,
			Adjust = function(dir) self:_step(dir) end,
			SetFocused = function(on) opt.State.focus = on; self:_renderOption(opt, true) end,
		})
	end
	if props.Default ~= nil then
		self:Set(props.Default, true)
	end
	self:_render(false)
	return self
end

function RadioGroup:_renderOption(opt, animate)
	local fake = { Label = opt.LabelObj, Enabled = self.Enabled }
	Element._renderRow(setmetatable(fake, { __index = self }), opt.Row, opt.Stroke, animate, opt.State)
	opt.Dot.Set(self.Value ~= nil and opt.Value == self.Value, animate)
end

function RadioGroup:_render(animate)
	for _, opt in ipairs(self.Options) do
		self:_renderOption(opt, animate)
	end
end

function RadioGroup:_step(dir)
	local idx = 0
	for i, opt in ipairs(self.Options) do
		if opt.Value == self.Value then idx = i end
	end
	local n = #self.Options
	if n == 0 then return end
	idx = ((idx - 1 + dir) % n) + 1
	self:Set(self.Options[idx].Value)
end

--- Selects the option with the given value. @param value any @param silent boolean|nil
function RadioGroup:Set(value, silent)
	local found
	for _, opt in ipairs(self.Options) do
		if opt.Value == value then found = opt end
	end
	if not found or found.Value == self.Value then return end
	self.Value = found.Value
	self:_render(true)
	if not silent then
		self:_fire(self.Value, tostring(self.Props.Text or "Option") .. " " .. found.Text)
	end
end

--- @return any current value (nil when nothing selected)
function RadioGroup:Get()
	return self.Value
end

return RadioGroup

end


-- ===== Components/Slider =====
rawget(__comp, "_kids")["Slider"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Slider
	Horizontal or vertical, custom range / step, editable value box, smooth animation,
	keyboard adjust (Left/Right, hold Shift for x10).
	Usage: local s = tab:AddSlider({ Text = "Speed", Min = 0, Max = 100, Default = 40, Step = 1, Suffix = "%",
	           Callback = function(v) end })
	       tab:AddSlider({ Text = "Volume", Orientation = "Vertical", Height = 160 })
]]
local UserInputService = game:GetService("UserInputService")
local Element = require(script.Parent.Element)

local Slider = Element.extend()

--- @param container table
-- @param props table { Text, Min=0, Max=100, Default, Step=1, Suffix="", Orientation="Horizontal"|"Vertical", Height, Callback }
-- @return Slider
function Slider.new(container, props)
	local ctx = container.Ctx
	local Util, Config = ctx.Util, ctx.Config
	local self = setmetatable({}, Slider)

	local min, max = tonumber(props.Min) or 0, tonumber(props.Max) or 100
	if max < min then min, max = max, min end
	local step = tonumber(props.Step) or 1
	if step <= 0 then step = 1 end
	self.Min, self.Max, self.Step = min, max, step
	self.Decimals = Util.Decimals(step)
	self.Suffix = tostring(props.Suffix or "")
	self.Vertical = props.Orientation == "Vertical"
	local v = self.Vertical

	local row, stroke = Element.CreateRow(container, props, v and (tonumber(props.Height) or 150) or 56, "Frame")
	self.Row, self.Stroke = row, stroke
	self.Label = Util.Label({
		Name = "Label", Text = tostring(props.Text or "Slider"), Position = UDim2.fromOffset(12, 7),
		Size = UDim2.new(1, v and -64 or -96, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	self.ValueBox = Util.Create("TextBox", {
		Name = "Value", BackgroundTransparency = 1, ClearTextOnFocus = false, Font = Config.FontBold, TextSize = Config.TextSizeSmall + 1,
		Text = "", TextXAlignment = v and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
		AnchorPoint = v and Vector2.new(0, 0) or Vector2.new(1, 0),
		Position = v and UDim2.fromOffset(12, 28) or UDim2.new(1, -12, 0, 7), Size = UDim2.fromOffset(v and 60 or 84, 18), Parent = row,
	})
	local track = Util.Create("Frame", {
		Name = "Track", BorderSizePixel = 0,
		AnchorPoint = v and Vector2.new(0.5, 0) or Vector2.new(0, 0),
		Position = v and UDim2.new(1, -30, 0, 14) or UDim2.fromOffset(12, 40),
		Size = v and UDim2.new(0, 6, 1, -28) or UDim2.new(1, -24, 0, 6), Parent = row,
	}, { Util.Corner("full") })
	local fill = Util.Create("Frame", {
		Name = "Fill", BorderSizePixel = 0, ClipsDescendants = false,
		AnchorPoint = v and Vector2.new(0, 1) or Vector2.new(0, 0), Position = v and UDim2.fromScale(0, 1) or UDim2.new(),
		Size = v and UDim2.fromScale(1, 0) or UDim2.fromScale(0, 1), Parent = track,
	}, { Util.Corner("full") })
	local knob = Util.Create("Frame", {
		Name = "Knob", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
		Position = v and UDim2.fromScale(0.5, 1) or UDim2.fromScale(0, 0.5), Parent = track,
	}, { Util.Corner("full") })
	local knobStroke = Util.Stroke(2)
	knobStroke.Parent = knob
	local hit = Util.Create("TextButton", {
		Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ZIndex = 3,
		Position = v and UDim2.new(1, -52, 0, 6) or UDim2.fromOffset(6, 28),
		Size = v and UDim2.new(0, 44, 1, -12) or UDim2.new(1, -12, 0, 26), Parent = row,
	})
	self.TrackObj, self.Fill, self.Knob, self.KnobStroke, self.Hit = track, fill, knob, knobStroke, hit

	self:_init(container, row, props, "slider")
	self:_interact(row)
	self.Drag = ctx.Drag.Attach(hit, {
		CanBegin = function() return self.Enabled end,
		Began = function(input) self._dragging = true; self:_fromPointer(input); self:_render(true) end,
		Changed = function(input) self:_fromPointer(input) end,
		Ended = function() self._dragging = false; self:_render(true) end,
	})
	self.Maid:Give(self.Drag)
	self.Maid:Give(self.ValueBox.FocusLost:Connect(function()
		local n = tonumber((self.ValueBox.Text:gsub(self.Suffix:gsub("%p", "%%%0"), "")))
		if n then self:Set(n) end
		self:_visual(false)
	end))
	self:Focusable({
		Activate = function() self.ValueBox:CaptureFocus() end,
		Adjust = function(dir)
			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			self:Set(self.Value + dir * self.Step * (shift and 10 or 1))
		end,
	})

	self:Set(tonumber(props.Default) or min, true)
	self:_render(false)
	return self
end

function Slider:_fromPointer(input)
	local pos = self.Ctx.Util.PointerPos(input, self.Container.Window.Is3D)
	local t = self.TrackObj
	local alpha
	if self.Vertical then
		alpha = 1 - (pos.Y - t.AbsolutePosition.Y) / math.max(t.AbsoluteSize.Y, 1)
	else
		alpha = (pos.X - t.AbsolutePosition.X) / math.max(t.AbsoluteSize.X, 1)
	end
	alpha = self.Ctx.Util.Clamp(alpha, 0, 1)
	self:Set(self.Min + (self.Max - self.Min) * alpha)
end

function Slider:_visual(animate)
	local Anim = self.Ctx.Anim
	local range = self.Max - self.Min
	local alpha = range > 0 and (self.Value - self.Min) / range or 0
	if not self.ValueBox:IsFocused() then
		self.ValueBox.Text = self.Ctx.Util.FormatNumber(self.Value, self.Decimals) .. self.Suffix
	end
	local dur = animate and (self._dragging and 0.06 or self.Ctx.Config.Animation.Fast) or 0
	if self.Vertical then
		Anim.Tween(self.Fill, { Size = UDim2.fromScale(1, alpha) }, dur)
		Anim.Tween(self.Knob, { Position = UDim2.fromScale(0.5, 1 - alpha) }, dur)
	else
		Anim.Tween(self.Fill, { Size = UDim2.fromScale(alpha, 1) }, dur)
		Anim.Tween(self.Knob, { Position = UDim2.fromScale(alpha, 0.5) }, dur)
	end
end

--- Sets the value (clamped + snapped to Step). @param value number @param silent boolean|nil
function Slider:Set(value, silent)
	value = tonumber(value)
	if not value then return end
	local Util = self.Ctx.Util
	local v = Util.Clamp(Util.Round(value - self.Min, self.Step) + self.Min, self.Min, self.Max)
	v = tonumber(string.format("%." .. self.Decimals .. "f", v)) or v
	local changed = v ~= self.Value
	self.Value = v
	self:_visual(true)
	if changed and not silent then
		self:_fire(v, tostring(self.Props.Text or "Slider") .. " " .. Util.FormatNumber(v, self.Decimals))
	end
end

--- @return number
function Slider:Get()
	return self.Value
end

--- Changes range at runtime. @param min number @param max number
function Slider:SetRange(min, max)
	min, max = tonumber(min), tonumber(max)
	if not min or not max then return end
	if max < min then min, max = max, min end
	self.Min, self.Max = min, max
	self:Set(self.Value or min, true)
end

function Slider:_render(animate)
	self:_renderRow(self.Row, self.Stroke, animate)
	local T, Anim = self.Ctx.Theme, self.Ctx.Anim
	local dur = animate and self.Ctx.Config.Animation.Fast or 0
	local grown = self._dragging or self.State.hover
	Anim.Tween(self.TrackObj, { BackgroundColor3 = T:Get("Track") }, dur)
	Anim.Tween(self.Fill, { BackgroundColor3 = T:Get("Accent"), BackgroundTransparency = self.Enabled and 0 or 0.5 }, dur)
	Anim.Tween(self.Knob, { BackgroundColor3 = T:Get("AccentText"), Size = UDim2.fromOffset(grown and 18 or 14, grown and 18 or 14) }, dur)
	Anim.Tween(self.KnobStroke, { Color = T:Get("Accent") }, dur)
	Anim.Tween(self.ValueBox, { TextColor3 = T:Get("Accent") }, dur)
end

return Slider

end


-- ===== Components/TabGroup =====
rawget(__comp, "_kids")["TabGroup"]._fn = function(script, require)
--[[
	Lumen UI :: Components/TabGroup
	Nested tabs inside a tab page: segmented strip with a sliding indicator.
	Usage: local g = tab:AddTabGroup({ Tabs = {"General", "Advanced"}, Default = 1 })
	       g.Tabs.General:AddToggle({ ... })     -- also g.Tabs[1]
	       g:Select("Advanced")
]]
local Element = require(script.Parent.Element)
local Container = require(script.Parent.Parent.Core.Container)

local TabGroup = Element.extend()

--- @param container table @param props table { Tabs = {"A","B"}, Default = 1 }
-- @return TabGroup
function TabGroup.new(container, props)
	local ctx = container.Ctx
	local Util, Config = ctx.Util, ctx.Config
	local names = props.Tabs
	assert(type(names) == "table" and #names > 0, "TabGroup needs props.Tabs = {\"A\", \"B\"}")
	local self = setmetatable({}, TabGroup)
	local n = #names

	local root = Util.Create("Frame", { Name = "TabGroup", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = container:_nextOrder(), Parent = container.Frame }, { Util.List(8) })
	local strip = Util.Create("Frame", { Name = "Strip", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = root },
		{ Util.Corner(Config.RadiusSmall) })
	self.StripStroke = Util.Stroke(1)
	self.StripStroke.Parent = strip
	self.Strip = strip
	self.Indicator = Util.Create("Frame", { Name = "Indicator", BorderSizePixel = 0, Position = UDim2.new(0, 3, 0, 3),
		Size = UDim2.new(1 / n, -6, 1, -6), Parent = strip }, { Util.Corner(5) })
	local holder = Util.Create("Frame", { Name = "Pages", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = root }, { Util.List(0) })

	self.Tabs, self.Buttons, self.Pages, self.Names = {}, {}, {}, {}
	self.Current = 0
	self:_init(container, root, { Name = "TabGroup", Text = "TabGroup" }, "tablist")

	for i, name in ipairs(names) do
		name = tostring(name)
		self.Names[i] = name
		local btn = Util.Create("TextButton", { Name = name, Text = name, Font = Config.FontBold, TextSize = Config.TextSizeSmall + 1,
			AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.new((i - 1) / n, 0, 0, 0), Size = UDim2.new(1 / n, 0, 1, 0),
			ZIndex = 2, Parent = strip })
		self.Buttons[i] = btn
		local page = Util.Create("Frame", { Name = "Page_" .. name, BackgroundTransparency = 1, Visible = false, Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, Parent = holder }, { Util.List(Config.ElementGap) })
		self.Pages[i] = page
		local sub = Container.new(ctx, container.Window, page, container.Scope)
		self.Tabs[i] = sub
		self.Tabs[name] = sub
		self.Maid:Give(btn.Activated:Connect(function() self:Select(i) end))
	end
	self:Select(tonumber(props.Default) or 1, true)
	return self
end

--- Selects a nested tab. @param which number|string index or name @param instant boolean|nil
function TabGroup:Select(which, instant)
	local idx = which
	if type(which) == "string" then
		idx = table.find(self.Names, which)
	end
	if not idx or idx < 1 or idx > #self.Pages or idx == self.Current then return end
	local n = #self.Pages
	if self.Current > 0 then self.Pages[self.Current].Visible = false end
	self.Current = idx
	self.Pages[idx].Visible = true
	self.Ctx.Anim.Tween(self.Indicator, { Position = UDim2.new((idx - 1) / n, 3, 0, 3) }, instant and 0 or self.Ctx.Config.Animation.Normal)
	self:_render(not instant)
end

function TabGroup:_render(animate)
	local T, Anim = self.Ctx.Theme, self.Ctx.Anim
	local dur = animate and self.Ctx.Config.Animation.Fast or 0
	Anim.Tween(self.Strip, { BackgroundColor3 = T:Get("SurfaceAlt") }, dur)
	Anim.Tween(self.StripStroke, { Color = T:Get("Stroke") }, dur)
	Anim.Tween(self.Indicator, { BackgroundColor3 = T:Get("Accent") }, dur)
	for i, b in ipairs(self.Buttons) do
		Anim.Tween(b, { TextColor3 = T:Get(i == self.Current and "AccentText" or "TextMuted") }, dur)
	end
end

return TabGroup

end


-- ===== Components/Textbox =====
rawget(__comp, "_kids")["Textbox"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Textbox
	Placeholder, validation (Validate fn / Pattern / Numeric / Required), password mode, clear button.
	Usage: tab:AddTextbox({ Text = "Email", Placeholder = "you@mail.com", Pattern = "^[%w%.%-_]+@[%w%.%-]+%.%a+$",
	           Callback = function(text) end })
	       tab:AddTextbox({ Text = "Password", Password = true })
	Password mode: Roblox has no native password field, so the control masks with "*" and keeps the real
	value internally (Get()). Masking reconstructs edits from the cursor position; a SHOW/HIDE toggle is provided.
]]
local Element = require(script.Parent.Element)

local Textbox = Element.extend()
local MASK = "*"

--- @param container table
-- @param props table { Text, Placeholder, Default, Password, Validate=function(text)->false[,msg] to reject, Pattern, Numeric, Required,
--   MaxLength, ClearButton=true, LiveUpdate=false, ErrorText, Callback }
-- @return Textbox
function Textbox.new(container, props)
	local ctx = container.Ctx
	local Util, Config, T = ctx.Util, ctx.Config, ctx.Theme
	local self = setmetatable({}, Textbox)
	self.Password = props.Password == true
	self.Revealed = false
	self.Value = ""
	self.Valid = true
	self.ClearEnabled = props.ClearButton ~= false

	local root = Util.Create("Frame", {
		Name = tostring(props.Text or "Textbox"), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = container:_nextOrder(), Parent = container.Frame,
	}, { Util.List(2) })
	local rowH = ctx:ElementHeight()
	local row = Util.Create("Frame", { Name = "Row", BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, rowH), LayoutOrder = 1, Parent = root },
		{ Util.Corner(Config.RadiusSmall) })
	local stroke = Util.Stroke(1)
	stroke.Parent = row
	self.Row, self.Stroke = row, stroke

	local hasLabel = props.Text ~= nil and props.Text ~= ""
	if hasLabel then
		self.Label = Util.Label({ Name = "Label", Text = tostring(props.Text), Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.38, -12, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	end
	local field = Util.Create("Frame", {
		Name = "Field", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
		Size = hasLabel and UDim2.new(0.62, -6, 1, -12) or UDim2.new(1, -12, 1, -12), Parent = row,
	}, { Util.Corner(5) })
	local fieldStroke = Util.Stroke(1)
	fieldStroke.Parent = field
	self.Field, self.FieldStroke = field, fieldStroke

	local rightW = (self.ClearEnabled and 22 or 0) + (self.Password and 44 or 0)
	local box = Util.Create("TextBox", {
		Name = "Input", BackgroundTransparency = 1, ClearTextOnFocus = false, Font = Config.Font, TextSize = Config.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "", PlaceholderText = tostring(props.Placeholder or ""),
		Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -(8 + rightW + 4), 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
		MaxVisibleGraphemes = -1, Parent = field,
	})
	self.Box = box

	local function smallButton(name, text, width, xFromRight)
		return Util.Create("TextButton", {
			Name = name, Text = text, Font = Config.FontBold, TextSize = name == "Clear" and 18 or 10, AutoButtonColor = false,
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -xFromRight, 0.5, 0),
			Size = UDim2.fromOffset(width, 20), Visible = false, Parent = field,
		})
	end
	self.ClearBtn = self.ClearEnabled and smallButton("Clear", "\195\151", 20, 4) or nil
	self.EyeBtn = self.Password and smallButton("Reveal", "SHOW", 42, (self.ClearEnabled and 26 or 4)) or nil
	if self.EyeBtn then self.EyeBtn.Visible = true end

	-- error label
	self.ErrorLabel = Util.Label({
		Name = "Error", Visible = false, TextSize = Config.TextSizeSmall, TextWrapped = true, LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root,
	})
	Util.Padding(4, 0).Parent = self.ErrorLabel

	self:_init(container, root, props, "textbox")
	self.Root = root
	self.FocusRoot = row

	-- text changes
	self.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
		if self._setting then return end
		local txt = box.Text
		if props.MaxLength and #txt > props.MaxLength then
			txt = txt:sub(1, props.MaxLength)
			self:_setText(txt)
		end
		if self.Password and not self.Revealed then
			self:_maskedEdit(txt)
		else
			self.Value = txt
		end
		self:_validate()
		self:_updateButtons()
		if props.LiveUpdate and self.Valid then self:_fire(self.Value) end
	end))
	self.Maid:Give(box.Focused:Connect(function() self.State.focus = true; self:_render(true) end))
	self.Maid:Give(box.FocusLost:Connect(function()
		self.State.focus = false
		self:_validate(true)
		self:_render(true)
		if self.Valid and not props.LiveUpdate then self:_fire(self.Value, tostring(props.Text or "Text") .. " set") end
	end))
	if self.ClearBtn then
		self.Maid:Give(self.ClearBtn.Activated:Connect(function()
			self:Set("", true)
			box:CaptureFocus()
			if props.LiveUpdate then self:_fire("") end
		end))
	end
	if self.EyeBtn then
		self.Maid:Give(self.EyeBtn.Activated:Connect(function()
			self.Revealed = not self.Revealed
			self.EyeBtn.Text = self.Revealed and "HIDE" or "SHOW"
			self:_refreshDisplay()
		end))
	end
	self:_interact(row)
	self:Focusable({ Root = row, Activate = function() box:CaptureFocus() end })

	if props.Default then self:Set(tostring(props.Default), true) end
	self:_render(false)
	return self
end

function Textbox:_setText(text)
	self._setting = true
	self.Box.Text = text
	self._setting = false
end

function Textbox:_refreshDisplay()
	local text = (self.Password and not self.Revealed) and string.rep(MASK, #self.Value) or self.Value
	self:_setText(text)
	self:_updateButtons()
end

-- rebuilds the real value from an edit made on the masked text (uses cursor position)
function Textbox:_maskedEdit(newText)
	local old = self.Value
	local oldLen, newLen = #old, #newText
	local m = 0
	for i = 1, newLen do
		if newText:sub(i, i) ~= MASK then m = m + 1 end
	end
	local c = self.Box.CursorPosition
	local q, r = c - 1 - m, oldLen + m - newLen
	if c < 1 or q < 0 or r < 0 or q + r > oldLen then
		self.Value = newText:gsub("%" .. MASK, "") -- cannot reconcile: keep only typed characters
	else
		self.Value = old:sub(1, q) .. newText:sub(q + 1, q + m) .. old:sub(q + r + 1)
	end
	local cursor = math.max(1, q + m + 1)
	self:_refreshDisplay()
	if self.Box:IsFocused() then self.Box.CursorPosition = cursor end
end

function Textbox:_updateButtons()
	if self.ClearBtn then self.ClearBtn.Visible = self.Value ~= "" and self.Enabled end
end

function Textbox:_validate(commit)
	local p, v = self.Props, self.Value
	local ok, msg = true, nil
	if v == "" then
		if p.Required and commit then ok, msg = false, p.ErrorText or "This field is required" end
	else
		if p.Numeric and not tonumber(v) then ok, msg = false, p.ErrorText or "Enter a number" end
		if ok and p.Pattern and not v:find(p.Pattern) then ok, msg = false, p.ErrorText or "Invalid format" end
		if ok and type(p.Validate) == "function" then
			local ran, res, why = pcall(p.Validate, v)
			if not ran then
				warn("[Lumen] Validate error: " .. tostring(res))
			elseif res == false then
				ok, msg = false, (type(why) == "string" and why) or p.ErrorText or "Invalid value"
			end
		end
	end
	self.Valid = ok
	self.ErrorMessage = msg
	self.ErrorLabel.Visible = not ok and msg ~= nil
	self.ErrorLabel.Text = msg or ""
	self:_render(true)
end

--- Sets the text. @param text string @param silent boolean|nil (no callback; callback only fires on commit anyway)
function Textbox:Set(text, silent)
	self.Value = tostring(text or "")
	self:_refreshDisplay()
	self:_validate()
	if not silent and self.Valid then self:_fire(self.Value) end
end

--- @return string current (unmasked) value
function Textbox:Get()
	return self.Value
end

--- @return boolean whether the current value passes validation
function Textbox:IsValid()
	return self.Valid
end

function Textbox:_render(animate)
	local T, Anim = self.Ctx.Theme, self.Ctx.Anim
	local dur = animate and self.Ctx.Config.Animation.Fast or 0
	local s = self.State
	Anim.Tween(self.Row, { BackgroundColor3 = T:Get((s.hover and self.Enabled) and "Hover" or "SurfaceAlt") }, dur)
	Anim.Tween(self.Stroke, { Color = T:Get("Stroke"), Thickness = 1 }, dur)
	local fc = not self.Valid and T:Get("Danger") or (s.focus and T:Get("Accent") or T:Get("Stroke"))
	Anim.Tween(self.FieldStroke, { Color = fc, Thickness = (s.focus or not self.Valid) and 1.5 or 1 }, dur)
	Anim.Tween(self.Field, { BackgroundColor3 = T:Get("Surface") }, dur)
	if self.Label then
		Anim.Tween(self.Label, { TextColor3 = T:Get("Text"), TextTransparency = self.Enabled and 0 or 0.55 }, dur)
	end
	self.Box.TextColor3 = T:Get("Text")
	self.Box.PlaceholderColor3 = T:Get("TextMuted")
	self.Box.TextEditable = self.Enabled
	self.ErrorLabel.TextColor3 = T:Get("Danger")
	if self.ClearBtn then self.ClearBtn.TextColor3 = T:Get("TextMuted") end
	if self.EyeBtn then self.EyeBtn.TextColor3 = T:Get("Accent") end
end

return Textbox

end


-- ===== Components/Toggle =====
rawget(__comp, "_kids")["Toggle"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Toggle
	Usage: local t = tab:AddToggle({ Text = "God mode", Default = false, Callback = function(on) end })
	       t:Set(true) ; t:Get()
]]
local Element = require(script.Parent.Element)

local Toggle = Element.extend()

--- @param container table @param props table { Text, Default=boolean, Callback, Tooltip, Enabled }
-- @return Toggle
function Toggle.new(container, props)
	local ctx = container.Ctx
	local Util = ctx.Util
	local self = setmetatable({}, Toggle)
	local row, stroke = Element.CreateRow(container, props, nil, "TextButton")
	self.Row, self.Stroke = row, stroke
	self.Label = Util.Label({
		Name = "Label", Text = tostring(props.Text or "Toggle"), Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -68, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
	})
	self.Track = Util.Create("Frame", {
		Name = "Track", BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 20), Parent = row,
	}, { Util.Corner("full") })
	self.Knob = Util.Create("Frame", {
		Name = "Knob", BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14), Parent = self.Track,
	}, { Util.Corner("full") })
	self.Value = props.Default == true

	self:_init(container, row, props, "switch")
	self:_interact(row)
	self.Maid:Give(row.Activated:Connect(function()
		if self.Enabled then self:Set(not self.Value) end
	end))
	self:Focusable({
		Activate = function() if self.Enabled then self:Set(not self.Value) end end,
		Adjust = function(dir) if self.Enabled then self:Set(dir > 0) end end,
	})
	self:_render(false)
	return self
end

--- Sets the state. @param value boolean @param silent boolean|nil skip callback
function Toggle:Set(value, silent)
	value = value and true or false
	if value == self.Value then return end
	self.Value = value
	self:_render(true)
	if not silent then
		self:_fire(value, tostring(self.Props.Text or "Toggle") .. (value and " on" or " off"))
	end
end

--- @return boolean
function Toggle:Get()
	return self.Value
end

function Toggle:_render(animate)
	self:_renderRow(self.Row, self.Stroke, animate)
	local T, Anim = self.Ctx.Theme, self.Ctx.Anim
	local dur = animate and self.Ctx.Config.Animation.Fast or 0
	Anim.Tween(self.Track, { BackgroundColor3 = T:Get(self.Value and "Accent" or "Track"), BackgroundTransparency = self.Enabled and 0 or 0.5 }, dur)
	Anim.Tween(self.Knob, {
		Position = UDim2.new(0, self.Value and 23 or 3, 0.5, 0),
		BackgroundColor3 = self.Value and T:Get("AccentText") or T:Get("TextMuted"),
	}, dur)
end

return Toggle

end


-- ===== Components/Widgets =====
rawget(__comp, "_kids")["Widgets"]._fn = function(script, require)
--[[
	Lumen UI :: Components/Widgets
	Small drawn widgets shared by several components (no image assets / special glyphs needed).
]]
local Widgets = {}

--- Animated checkbox with a drawn tick.
-- @param ctx table @param parent Instance @param size number|nil box size (default 18)
-- @return table { Frame, Set(checked, animate), SetColor(color3|nil) }
function Widgets.CheckBox(ctx, parent, size)
	size = size or 18
	local Util, Anim, T = ctx.Util, ctx.Anim, ctx.Theme
	local box = Util.Create("Frame", {
		Name = "Box", Size = UDim2.fromOffset(size, size), BorderSizePixel = 0, BackgroundColor3 = T:Get("Surface"), Parent = parent,
	}, { Util.Corner(5) })
	local stroke = Util.Stroke(1.5, T:Get("Stroke"))
	stroke.Parent = box
	local tick = Util.Create("Frame", {
		Name = "Tick", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18), Parent = box,
	})
	local scale = Util.Create("UIScale", { Scale = 0, Parent = tick })
	local function arm(len, x, y, rot)
		return Util.Create("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(len, 2), Rotation = rot, BackgroundColor3 = T:Get("AccentText"), Parent = tick,
		}, { Util.Corner("full") })
	end
	local a1, a2 = arm(4.6, 6, 11, 45), arm(9.6, 10.5, 9, -49)

	local w = { Frame = box, Checked = false }
	function w.Render(animate)
		local dur = animate and ctx.Config.Animation.Fast or 0
		local fill = w.Color or T:Get("Accent")
		Anim.Tween(box, { BackgroundColor3 = w.Checked and fill or T:Get("Surface") }, dur)
		Anim.Tween(stroke, { Color = w.Checked and fill or T:Get("Stroke") }, dur)
		a1.BackgroundColor3 = T:Get("AccentText")
		a2.BackgroundColor3 = T:Get("AccentText")
		Anim.Tween(scale, { Scale = (w.Checked and 1 or 0) * size / 18 }, dur * 1.5, w.Checked and Enum.EasingStyle.Back or Enum.EasingStyle.Quad)
	end
	--- @param checked boolean @param animate boolean|nil
	function w.Set(checked, animate)
		w.Checked = checked and true or false
		w.Render(animate)
	end
	--- @param color Color3|nil custom fill color
	function w.SetColor(color)
		w.Color = color
		w.Render(false)
	end
	w.Render(false)
	return w
end

--- Radio dot (ring + inner dot).
-- @return table { Frame, Set(checked, animate), SetColor(color3|nil), Render(animate) }
function Widgets.RadioDot(ctx, parent, size)
	size = size or 18
	local Util, Anim, T = ctx.Util, ctx.Anim, ctx.Theme
	local ring = Util.Create("Frame", {
		Name = "Radio", Size = UDim2.fromOffset(size, size), BorderSizePixel = 0, BackgroundColor3 = T:Get("Surface"), Parent = parent,
	}, { Util.Corner("full") })
	local stroke = Util.Stroke(1.5, T:Get("Stroke"))
	stroke.Parent = ring
	local dot = Util.Create("Frame", {
		Name = "Dot", BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0), BackgroundColor3 = T:Get("Accent"), Parent = ring,
	}, { Util.Corner("full") })
	local w = { Frame = ring, Checked = false }
	function w.Render(animate)
		local dur = animate and ctx.Config.Animation.Fast or 0
		local fill = w.Color or T:Get("Accent")
		Anim.Tween(stroke, { Color = w.Checked and fill or T:Get("Stroke") }, dur)
		Anim.Tween(ring, { BackgroundColor3 = T:Get("Surface") }, dur)
		Anim.Tween(dot, { BackgroundColor3 = fill, Size = w.Checked and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0, 0) }, dur * 1.5,
			Enum.EasingStyle.Back)
	end
	function w.Set(checked, animate)
		w.Checked = checked and true or false
		w.Render(animate)
	end
	function w.SetColor(color)
		w.Color = color
		w.Render(false)
	end
	w.Render(false)
	return w
end

--- Chevron (V shape) that can rotate.
-- @return table { Frame, SetOpen(open, animate), SetColor(color3) }
function Widgets.Chevron(ctx, parent)
	local Util, Anim = ctx.Util, ctx.Anim
	local f = Util.Create("Frame", {
		Name = "Chevron", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Parent = parent,
	})
	local function arm(x, rot)
		return Util.Create("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 6),
			Size = UDim2.fromOffset(6.8, 2), Rotation = rot, Parent = f,
		}, { Util.Corner("full") })
	end
	local l, r = arm(3.75, 48), arm(8.25, -48)
	local w = { Frame = f }
	function w.SetOpen(open, animate)
		Anim.Tween(f, { Rotation = open and 180 or 0 }, animate and ctx.Config.Animation.Fast or 0)
	end
	function w.SetColor(c)
		l.BackgroundColor3 = c
		r.BackgroundColor3 = c
	end
	return w
end

return Widgets

end


-- ===== init =====
__root._fn = function(script, require)
--[[
	Lumen UI 1.0.0 — modular Roblox UI library.

	Install: put the `Lumen` folder in ReplicatedStorage (ModuleScript "Lumen" with children Core/ and Components/).
	Use (LocalScript):
		local Lumen = require(game.ReplicatedStorage.Lumen)
		local win = Lumen:CreateWindow({ Title = "Hub", Subtitle = "v1" })
		local tab = win:AddTab({ Name = "Main" })
		tab:AddButton({ Text = "Hello", Callback = function() Lumen:Notify({ Title = "Hi", Type = "Success" }) end })
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Core = script:WaitForChild("Core")
local Components = script:WaitForChild("Components")

local Config = require(Core.Config)
local Util = require(Core.Util)
local Signal = require(Core.Signal)
local Maid = require(Core.Maid)
local Pool = require(Core.Pool)
local Animation = require(Core.Animation)
local Theme = require(Core.Theme)
local Drag = require(Core.Drag)
local Tooltip = require(Core.Tooltip)
local Notifications = require(Core.Notifications)
local Window = require(Core.Window)

Util.Config = Config

local Basic = require(Components.Basic)

local ctx = {
	Config = Config, Util = Util, Signal = Signal, Maid = Maid, Pool = Pool, Anim = Animation, Drag = Drag,
	Theme = Theme.new(Config.Theme),
	Announced = Signal.new(),
	Components = {
		Button = require(Components.Button),
		Toggle = require(Components.Toggle),
		Checkbox = require(Components.Checkbox),
		RadioGroup = require(Components.RadioGroup),
		Slider = require(Components.Slider),
		Textbox = require(Components.Textbox),
		Dropdown = require(Components.Dropdown),
		ColorPicker = require(Components.ColorPicker),
		ProgressBar = require(Components.ProgressBar),
		TabGroup = require(Components.TabGroup),
		Label = Basic.Label,
		Section = Basic.Section,
		Divider = Basic.Divider,
	},
}

local function applyConfig()
	Animation.Enabled = Config.Animation.Enabled
	Animation.DefaultStyle = Config.Animation.Style
	Animation.DefaultDirection = Config.Animation.Direction
end
applyConfig()

--- Element height; slightly taller on touch-only devices. @return number
function ctx:ElementHeight()
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	return Config.ElementHeight + (touchOnly and Config.TouchExtraHeight or 0)
end

--- Resolves an icon name registered with RegisterIcons, or returns the raw asset string. @return string
function ctx:ResolveIcon(icon)
	if type(icon) == "number" then return "rbxassetid://" .. icon end
	return Config.Icons[icon] or icon or ""
end

--- Accessibility announcement: Roblox has no screen-reader API, so this fires Lumen.Announced for your own TTS/UI hook.
function ctx:Announce(text)
	if text and text ~= "" then
		self.Announced:Fire(tostring(text))
	end
end

--- Lazily creates the shared ScreenGui (+ tooltip layer and notification layer). @return ScreenGui
function ctx:GetScreenGui()
	if self._gui and self._gui.Parent then
		return self._gui
	end
	local parent = self.GuiParent or Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Util.Create("ScreenGui", {
		Name = "LumenUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = Config.DisplayOrder,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent,
	})
	self._gui = gui
	if self.Tooltip then self.Tooltip:Destroy() end
	if self.Notifications then self.Notifications:Destroy() end
	self.Tooltip = Tooltip.new(self, gui)
	self.Notifications = Notifications.new(self, gui)
	return gui
end

-- public API -----------------------------------------------------------------------------
local Lumen = {}
Lumen.Version = "1.0.0"
Lumen.Theme = ctx.Theme
Lumen.Anim = Animation
Lumen.Easing = Animation.Easing
Lumen.Announced = ctx.Announced
local windows = {}

--- Deep-merges overrides into the default config (call before creating windows).
-- @param overrides table e.g. { Animation = { Enabled = false }, Notification = { Position = "TopRight" } }
function Lumen:Configure(overrides)
	if type(overrides) ~= "table" then
		warn("[Lumen] Configure expects a table")
		return self
	end
	Util.DeepMerge(Config, overrides)
	applyConfig()
	if overrides.Theme then ctx.Theme:Set(Config.Theme, true) end
	return self
end

--- Creates a window. See Core/Window.lua for all props.
-- @param props table { Title, Subtitle, Icon, Size, Theme, ToggleKey, Resizable, Blur, Shadow, Mount, Adornee, ... }
-- @return Window
function Lumen:CreateWindow(props)
	local ok, win = xpcall(Window.new, function(e) return debug.traceback(tostring(e), 2) end, ctx, props)
	if not ok then
		error("[Lumen] CreateWindow failed: " .. tostring(win), 2)
	end
	table.insert(windows, win)
	return win
end

--- Shows a toast. @param props table { Title, Content, Type="Info"|"Success"|"Warning"|"Error", Duration } @return table { Dismiss }
function Lumen:Notify(props)
	ctx:GetScreenGui()
	return ctx.Notifications:Notify(props)
end

--- Shows a modal alert. @param props table { Title, Content, Type, Buttons = { {Text, Callback, Style} } } @return table { Close }
function Lumen:Alert(props)
	ctx:GetScreenGui()
	return ctx.Notifications:Alert(props)
end

--- Switches theme everywhere in real time. @param name string "Dark" | "Light" | "HighContrast" | custom
function Lumen:SetTheme(name)
	return ctx.Theme:Set(name, true)
end

--- Registers a custom palette (missing tokens fall back to Dark). @param name string @param palette table token -> Color3
function Lumen:RegisterTheme(name, palette)
	ctx.Theme:Register(name, palette)
end

--- @return table sorted theme names
function Lumen:GetThemes()
	return ctx.Theme:List()
end

--- Registers named icons. @param map table name -> "rbxassetid://..."
function Lumen:RegisterIcons(map)
	Util.DeepMerge(Config.Icons, map)
end

--- Reduced motion switch. @param enabled boolean
function Lumen:SetAnimationsEnabled(enabled)
	Config.Animation.Enabled = enabled and true or false
	applyConfig()
end

--- Where windows are parented (default LocalPlayer.PlayerGui). Call before the first window.
function Lumen:SetGuiParent(parent)
	ctx.GuiParent = parent
end

--- Destroys every window and shared UI.
function Lumen:Destroy()
	for _, w in ipairs(windows) do
		w:Destroy()
	end
	table.clear(windows)
	if ctx.Tooltip then ctx.Tooltip:Destroy() ctx.Tooltip = nil end
	if ctx.Notifications then ctx.Notifications:Destroy() ctx.Notifications = nil end
	if ctx._gui then ctx._gui:Destroy() ctx._gui = nil end
end

return Lumen

end


return __require(__root)
end)()

-- ============================================================================================
-- Velt-compatible facade on top of Lumen.
-- Supports exactly the Velt API used by the ENTRENCHED script:
--   Velt:CreateWindow{Name,Logo,ToggleKey,Size,MinSize}
--   Window:AddTab(name) -> Tab:AddSection/AddLabel/AddButton/AddToggle/AddSlider/AddDropdown
--   Window:Notify/SetSize/Toggle/Destroy, Window.Gui, Window.OnVisibility, Window.Flags
-- Not provided: the named-preset panel (profile card). Your script's own Config file still saves all settings.
-- ============================================================================================
local UserInputService = game:GetService("UserInputService")

local function canParent(target)
	local ok, result = pcall(function()
		local g = Instance.new("ScreenGui")
		g.Parent = target
		local good = g.Parent == target
		g:Destroy()
		return good
	end)
	return ok and result
end

local function pickParent()
	local getters = {}
	if gethui then table.insert(getters, function() return gethui() end) end
	table.insert(getters, function() return game:GetService("CoreGui") end)
	table.insert(getters, function() return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end)
	for _, get in ipairs(getters) do
		local ok, target = pcall(get)
		if ok and target and canParent(target) then return target end
	end
	return nil
end

local Velt = {}

function Velt:CreateWindow(config)
	config = config or {}

	local parent = pickParent()
	if parent then
		for _, name in ipairs({ "LumenUI", "VeltUI" }) do
			local old = parent:FindFirstChild(name)
			if old then pcall(function() old:Destroy() end) end
		end
	end
	Lumen:SetGuiParent(parent)

	Lumen:RegisterTheme("Entrenched", {
		Background = Color3.fromRGB(14, 15, 12), Surface = Color3.fromRGB(22, 24, 19),
		SurfaceAlt = Color3.fromRGB(30, 33, 26), Hover = Color3.fromRGB(40, 44, 34),
		Track = Color3.fromRGB(10, 11, 8), Stroke = Color3.fromRGB(42, 46, 37),
		Text = Color3.fromRGB(217, 213, 200), TextMuted = Color3.fromRGB(122, 125, 112),
		Accent = Color3.fromRGB(200, 162, 74), AccentAlt = Color3.fromRGB(224, 186, 94),
		AccentText = Color3.fromRGB(20, 18, 10), Success = Color3.fromRGB(94, 122, 74),
		Warning = Color3.fromRGB(224, 186, 94), Danger = Color3.fromRGB(168, 67, 58),
		TooltipBackground = Color3.fromRGB(40, 44, 34), TooltipText = Color3.fromRGB(217, 213, 200),
	})
	Lumen:Configure({
		Keyboard = { Enabled = false }, -- Tab/arrow navigation would fight with the game's controls
		Window = { MinSize = config.MinSize or Vector2.new(300, 220) },
	})

	local logo
	if config.Logo and isfile and getcustomasset then
		local ok, has = pcall(isfile, config.Logo)
		if ok and has then
			local ok2, asset = pcall(getcustomasset, config.Logo)
			if ok2 then logo = asset end
		end
	end

	local win = Lumen:CreateWindow({
		Title = config.Name or "Velt",
		Icon = logo,
		Size = config.Size,
		Theme = "Entrenched",
		ToggleKey = false, -- the script handles its own (rebindable) menu key
		Blur = false,
	})

	local Window = { Flags = {}, Gui = win.Holder.Parent }

	-- floating, draggable toggle button (tap = open/close) --------------------------------------------
	local T = Lumen.Theme
	local float = Instance.new("TextButton")
	float.Name = "FloatingToggle"
	float.Text = logo and "" or "V"
	float.Font = Enum.Font.GothamBold
	float.TextSize = 22
	float.TextColor3 = T:Get("Accent")
	float.AutoButtonColor = false
	float.BackgroundColor3 = T:Get("Background")
	float.BorderSizePixel = 0
	float.Size = UDim2.fromOffset(50, 50)
	local cam = workspace.CurrentCamera
	float.Position = UDim2.fromOffset(16, math.floor((cam and cam.ViewportSize.Y or 720) / 2 - 25))
	float.ZIndex = 150
	Instance.new("UICorner", float).CornerRadius = UDim.new(0, 15)
	local fstroke = Instance.new("UIStroke", float)
	fstroke.Thickness = 1.5
	fstroke.Color = T:Get("Accent")
	if logo then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.new(1, -18, 1, -18)
		img.Position = UDim2.fromOffset(9, 9)
		img.Image = logo
		img.ImageColor3 = T:Get("Accent")
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 151
		img.Parent = float
	end
	float.Parent = Window.Gui

	local conns = {}
	local pressing, moved, startPtr, startAbs = false, false, nil, nil
	table.insert(conns, float.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressing, moved = true, false
			startPtr = input.Position
			startAbs = float.AbsolutePosition
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End and pressing then
					pressing = false
					if not moved then win:Toggle() end
				end
			end)
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if pressing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startPtr
			if not moved and d.Magnitude > 8 then moved = true end
			if moved then
				local v = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
				float.Position = UDim2.fromOffset(
					math.clamp(startAbs.X + d.X, 0, v.X - 50), math.clamp(startAbs.Y + d.Y, 0, v.Y - 50))
			end
		end
	end))

	local function visibility(state)
		fstroke.Color = state and T:Get("Accent") or T:Get("TextMuted")
		if Window.OnVisibility then pcall(Window.OnVisibility, state) end
	end
	table.insert(conns, win.Opened:Connect(function() visibility(true) end))
	table.insert(conns, win.Closed:Connect(function() visibility(false) end))

	-- Window API ------------------------------------------------------------------------------------
	function Window:Toggle() win:Toggle() end
	function Window:SetSize(w, h) win:SetSize(Vector2.new(w, h)) end
	function Window:Notify(o)
		o = o or {}
		Lumen:Notify({ Title = o.Title or config.Name or "Notice", Content = o.Content or "", Duration = o.Duration or 4, Type = "Info" })
	end
	function Window:Destroy()
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		pcall(function() float:Destroy() end)
		pcall(function() win:Destroy() end)
		pcall(function() Lumen:Destroy() end)
	end

	local function run(fn, ...)
		if fn then task.spawn(fn, ...) end
	end

	function Window:AddTab(tabName)
		local tab = win:AddTab({ Name = tostring(tabName) })
		local Tab = {}

		function Tab:AddSection(text) tab:AddSection(text) end

		function Tab:AddLabel(text)
			local l = tab:AddLabel({ Text = tostring(text), Muted = true })
			return { Set = function(_, t) l:SetText(t) end }
		end

		function Tab:AddButton(o)
			tab:AddButton({ Text = o.Name or "Button", Style = "Ghost", Callback = function() run(o.Callback) end })
		end

		function Tab:AddToggle(o)
			local el = tab:AddToggle({ Text = o.Name or "Toggle", Default = o.Default == true,
				Callback = function(v) run(o.Callback, v) end })
			local api = { Set = function(_, v) el:Set(v == true) end, Get = function() return el:Get() end }
			if o.Flag then Window.Flags[o.Flag] = api end
			return api
		end

		function Tab:AddSlider(o)
			local el = tab:AddSlider({ Text = o.Name or "Slider", Min = o.Min or 0, Max = o.Max or 100,
				Default = o.Default, Step = o.Step or 1, Callback = function(v) run(o.Callback, v) end })
			local api = { Set = function(_, v) if type(v) == "number" then el:Set(v) end end, Get = function() return el:Get() end }
			if o.Flag then Window.Flags[o.Flag] = api end
			return api
		end

		function Tab:AddDropdown(o)
			local el = tab:AddDropdown({ Text = o.Name or "Dropdown", Options = o.Options or {}, Default = o.Default,
				Callback = function(v) run(o.Callback, v) end })
			local api = { Set = function(_, v) el:Set(v) end, Get = function() return el:Get() end }
			if o.Flag then Window.Flags[o.Flag] = api end
			return api
		end

		return Tab
	end

	return Window
end

return Velt
