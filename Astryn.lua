--[[
	█████╗ ███████╗████████╗██████╗ ██╗   ██╗███╗   ██╗
	██╔══██╗██╔════╝╚══██╔══╝██╔══██╗╚██╗ ██╔╝████╗  ██║
	███████║███████╗   ██║   ██████╔╝ ╚████╔╝ ██╔██╗ ██║
	██╔══██║╚════██║   ██║   ██╔══██╗  ╚██╔╝  ██║╚██╗██║
	██║  ██║███████║   ██║   ██║  ██║   ██║   ██║ ╚████║
	╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝

	ASTRYN HUB — Astral Interface Framework
	Version 1.0.0

	A modular, original Roblox UI library with a cosmic visual identity.

	QUICK START
	-----------
	  local Astryn = loadstring(game:HttpGet("<url>/Astryn.lua"))()
	  -- or, as a ModuleScript: local Astryn = require(path.to.Astryn)

	  Astryn:SetKeySystem({ Enabled = false })            -- keyless
	  local Window = Astryn:CreateWindow({ Name = "Astryn HUB" })
	  local Tab    = Window:CreateTab({ Name = "Main", Icon = "home" })
	  Tab:CreateSection("Example")
	  Tab:CreateButton({ Name = "Test", Callback = function() end })
	  Window:CreateSettingsTab()                          -- always last
	  Astryn:Destroy()                                    -- full teardown

	See README.md for the complete API reference.

	Architecture
	------------
	Astryn
	  ├── Core      : Maid, Util, Theme, Animation, Config
	  ├── Systems   : Background, Notification, Dialog, Loading, KeySystem
	  ├── Elements  : Button, Toggle, Slider, Dropdown, MultiDropdown, Label,
	  │               Paragraph, Section, Divider, Input, Keybind, ColorPicker
	  └── Window    : header / sidebar / tabs / content / settings

	Everything is namespaced inside this single module so it can be delivered
	through loadstring() or required as a ModuleScript. Each sub-system is an
	isolated table — adding a new element is a single function in `Elements`.
--]]

local Astryn = {}
Astryn.__index = Astryn
Astryn.Version = "1.2.0"
Astryn.Name = "Astryn HUB"

--==================================================================
-- SERVICES
--==================================================================

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local GuiService       = game:GetService("GuiService")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- Forward declaration: Theme:Repaint tweens colours, but Theme is defined
-- before Animation. Declaring it here keeps the reference an upvalue.
local Animation

--==================================================================
-- ENVIRONMENT DETECTION
--==================================================================

local Env = {}
Env.IsMobile      = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
Env.IsTablet      = false -- resolved on first window creation from viewport size
Env.HasFileSystem = (typeof(writefile) == "function" and typeof(readfile) == "function")
Env.GetHui        = (typeof(gethui) == "function") and gethui or nil
Env.Protect       = (typeof(syn) == "table" and syn.protect_gui) or nil

Astryn.Env = Env

--==================================================================
-- CORE / MAID  (connection + instance lifetime manager)
--==================================================================

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

-- Accepts RBXScriptConnection, Instance, function or table with :Destroy()
function Maid:Give(item)
	table.insert(self._tasks, item)
	return item
end

function Maid:Clean()
	for i = #self._tasks, 1, -1 do
		local item = self._tasks[i]
		self._tasks[i] = nil
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			pcall(function() item:Destroy() end)
		elseif kind == "function" then
			pcall(item)
		elseif kind == "table" and item.Destroy then
			pcall(function() item:Destroy() end)
		end
	end
end

Maid.Destroy = Maid.Clean
Astryn.Maid = Maid

--==================================================================
-- CORE / UTILITY
--==================================================================

local Util = {}

-- Declarative instance builder: Util.New("Frame", {props}, {children})
function Util.New(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
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
	if parent then inst.Parent = parent end
	return inst
end

function Util.Corner(radius, parent)
	return Util.New("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

function Util.Stroke(color, thickness, transparency, parent)
	return Util.New("UIStroke", {
		Color = color or Color3.fromRGB(60, 60, 90),
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Util.Padding(parent, top, bottom, left, right)
	return Util.New("UIPadding", {
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or top or 0),
		PaddingLeft = UDim.new(0, left or top or 0),
		PaddingRight = UDim.new(0, right or left or top or 0),
		Parent = parent,
	})
end

function Util.List(parent, padding, direction, alignment)
	return Util.New("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = direction or Enum.FillDirection.Vertical,
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Util.Gradient(colors, rotation, transparency, parent)
	return Util.New("UIGradient", {
		Color = colors,
		Rotation = rotation or 0,
		Transparency = transparency or NumberSequence.new(0),
		Parent = parent,
	})
end

function Util.Round(value, increment)
	if not increment or increment <= 0 then return value end
	return math.floor((value / increment) + 0.5) * increment
end

function Util.Clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

function Util.Lerp(a, b, t)
	return a + (b - a) * t
end

-- Deep copy used by the theme system so user tables are never mutated
function Util.Copy(tbl)
	local out = {}
	for k, v in pairs(tbl) do
		out[k] = (type(v) == "table") and Util.Copy(v) or v
	end
	return out
end

function Util.Shift(color, amount)
	local h, s, v = Color3.toHSV(color)
	return Color3.fromHSV(h, s, Util.Clamp(v + amount, 0, 1))
end

-- Safe unique id for flags that the user did not name
local _idCounter = 0
function Util.NextId(prefix)
	_idCounter += 1
	return (prefix or "Astryn") .. "_" .. tostring(_idCounter)
end

-- Resolves the safest available ScreenGui parent for the current executor
function Util.GuiParent()
	if Env.GetHui then
		local ok, hui = pcall(Env.GetHui)
		if ok and hui then return hui end
	end
	local ok = pcall(function() return CoreGui.Name end)
	if ok then
		return CoreGui
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

function Util.Viewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end


-- Guarded call used by every user-supplied callback in the library.
-- A thrown callback never breaks the UI; it warns and returns false.
function Util.SafeCall(fn, ...)
	if type(fn) ~= "function" then return false end
	local results = table.pack(pcall(fn, ...))
	if not results[1] then
		warn("[Astryn] callback error: " .. tostring(results[2]))
		return false
	end
	return true, table.unpack(results, 2, results.n)
end

-- True when an instance still exists in the DataModel hierarchy.
function Util.IsAlive(instance)
	return typeof(instance) == "Instance" and instance.Parent ~= nil
end

Astryn.Util = Util

--==================================================================
-- CORE / DESIGN TOKENS
-- Single source of truth for spacing, radii and type scale. Elements
-- read from here instead of hardcoding numbers, so the whole library
-- can be re-proportioned from one table.
--==================================================================

local Tokens = {
	Radius = {
		Window  = 16,
		Panel   = 14,   -- dialogs, key card, notifications
		Card    = 11,   -- element rows
		Control = 8,    -- buttons, fields, dropdown displays
		Pill    = 999,
	},
	Spacing = {
		Gutter    = 14,   -- horizontal inset inside a card
		Stack     = 8,    -- vertical gap between cards
		PageInset = 12,
	},
	Height = {
		Header   = 54,
		Row      = 42,
		RowDesc  = 56,
		Control  = 26,
		Tab      = 36,
		TabTouch = 42,
	},
	Text = {
		Title    = 15,
		Row      = 13.5,
		Body     = 12.5,
		Caption  = 11.5,
		Micro    = 11,
	},
	Font = {
		Bold    = Enum.Font.GothamBold,
		Medium  = Enum.Font.GothamMedium,
		Regular = Enum.Font.Gotham,
		Mono    = Enum.Font.Code,
	},
}

Astryn.Tokens = Tokens

--==================================================================
-- CORE / SCHEDULER
-- One RunService.Heartbeat connection for the entire library. Every
-- animated system (star field, spinners) registers a named job here
-- instead of opening its own loop, and the connection closes itself
-- when the last job is removed.
--==================================================================

local Scheduler = { Jobs = {}, Count = 0, Connection = nil }

function Scheduler:Add(key, fn)
	if self.Jobs[key] == nil then self.Count += 1 end
	self.Jobs[key] = fn
	if not self.Connection then
		self.Connection = RunService.Heartbeat:Connect(function(dt)
			dt = math.min(dt, 1 / 20) -- clamp after lag spikes
			for jobKey, job in pairs(self.Jobs) do
				local ok, err = pcall(job, dt)
				if not ok then
					warn("[Astryn] scheduler job '" .. tostring(jobKey) .. "' failed: " .. tostring(err))
					self:Remove(jobKey)
				end
			end
		end)
	end
end

function Scheduler:Remove(key)
	if self.Jobs[key] ~= nil then
		self.Jobs[key] = nil
		self.Count -= 1
	end
	if self.Count <= 0 and self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
		self.Count = 0
	end
end

function Scheduler:Clear()
	table.clear(self.Jobs)
	self.Count = 0
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

Astryn.Scheduler = Scheduler

--==================================================================
-- CORE / DRAG MANAGER
-- Sliders, colour pickers, the window itself and the mobile launcher
-- all need pointer tracking. Previously each one opened its own
-- InputChanged/InputEnded pair, which scaled linearly with the number
-- of controls. They now share exactly two connections.
--==================================================================

local DragManager = { Active = nil }

DragManager.Connections = {
	UserInputService.InputChanged:Connect(function(input)
		local session = DragManager.Active
		if not session then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			if not Util.IsAlive(session.Object) then
				DragManager.Active = nil
				return
			end
			Util.SafeCall(session.OnMove, input)
		end
	end),
	UserInputService.InputEnded:Connect(function(input)
		local session = DragManager.Active
		if not session then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			DragManager.Active = nil
			if session.OnEnd then Util.SafeCall(session.OnEnd, input) end
		end
	end),
}

-- Binds `object` so that pressing it starts a drag session.
--   onMove(input)  called on every pointer move while held
--   onEnd(input)   optional, called once on release
-- Returns the InputBegan connection so callers can hand it to a Maid.
function DragManager:Bind(object, onMove, onEnd, onBegin)
	return object.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		DragManager.Active = { Object = object, OnMove = onMove, OnEnd = onEnd }
		if onBegin then Util.SafeCall(onBegin, input) end
		Util.SafeCall(onMove, input)
	end)
end

function DragManager:Destroy()
	self.Active = nil
	for _, connection in ipairs(self.Connections) do connection:Disconnect() end
	table.clear(self.Connections)
end

Astryn.DragManager = DragManager

--==================================================================
-- CORE / ICON SET
-- Lightweight glyph icons (no external assets). Passing a string that
-- begins with "rbxassetid://" switches the slot to an ImageLabel instead.
--==================================================================

local Icons = {
	home      = "⌂",
	user      = "◉",
	eye       = "◈",
	visual    = "◈",
	teleport  = "✦",
	settings  = "⚙",
	gear      = "⚙",
	misc      = "✧",
	star      = "★",
	sparkle   = "✦",
	shield    = "⛨",
	code      = "⌘",
	bolt      = "⚡",
	info      = "ⓘ",
	check     = "✓",
	cross     = "✕",
	search    = "⌕",
	palette   = "◐",
	grid      = "⊞",
	play      = "▶",
	bell      = "✧",
	folder    = "▤",
	key       = "⚷",
	arrow     = "›",
	chevron   = "⌄",
	minus     = "–",
	plus      = "+",
	world     = "◍",
}

function Icons.Resolve(name)
	if type(name) ~= "string" then return nil end
	if name:match("^rbxassetid://") or name:match("^%d+$") then
		return (name:match("^%d+$") and ("rbxassetid://" .. name) or name), true
	end
	return Icons[name:lower()] or name, false
end

Astryn.Icons = Icons

--==================================================================
-- CORE / THEME
-- Every themed property is registered so SetTheme() repaints live.
--==================================================================

local Theme = {}
Theme.Registry = {}   -- [Instance] = { [property] = { Key, Modifier } }
Theme.Current = "Astral"

Theme.Presets = {
	Astral = {
		Background     = Color3.fromRGB(11, 11, 20),
		Secondary      = Color3.fromRGB(17, 17, 30),
		Tertiary       = Color3.fromRGB(24, 24, 42),
		Elevated       = Color3.fromRGB(31, 31, 54),
		Accent         = Color3.fromRGB(140, 100, 255),
		AccentAlt      = Color3.fromRGB(96, 178, 255),
		Text           = Color3.fromRGB(236, 236, 248),
		SubText        = Color3.fromRGB(148, 148, 176),
		Border         = Color3.fromRGB(46, 46, 74),
		Success        = Color3.fromRGB(96, 224, 160),
		Warning        = Color3.fromRGB(255, 196, 96),
		Error          = Color3.fromRGB(255, 104, 128),
		Nebula         = Color3.fromRGB(78, 46, 150),
		Star           = Color3.fromRGB(226, 226, 255),
	},
	Nebula = {
		Background     = Color3.fromRGB(16, 10, 24),
		Secondary      = Color3.fromRGB(24, 15, 36),
		Tertiary       = Color3.fromRGB(34, 21, 50),
		Elevated       = Color3.fromRGB(44, 27, 64),
		Accent         = Color3.fromRGB(236, 112, 200),
		AccentAlt      = Color3.fromRGB(150, 110, 255),
		Text           = Color3.fromRGB(245, 235, 250),
		SubText        = Color3.fromRGB(176, 152, 190),
		Border         = Color3.fromRGB(64, 40, 88),
		Success        = Color3.fromRGB(120, 230, 180),
		Warning        = Color3.fromRGB(255, 200, 120),
		Error          = Color3.fromRGB(255, 110, 130),
		Nebula         = Color3.fromRGB(128, 40, 130),
		Star           = Color3.fromRGB(255, 232, 250),
	},
	Void = {
		Background     = Color3.fromRGB(8, 8, 10),
		Secondary      = Color3.fromRGB(14, 14, 17),
		Tertiary       = Color3.fromRGB(20, 20, 24),
		Elevated       = Color3.fromRGB(28, 28, 33),
		Accent         = Color3.fromRGB(190, 190, 205),
		AccentAlt      = Color3.fromRGB(120, 120, 140),
		Text           = Color3.fromRGB(240, 240, 245),
		SubText        = Color3.fromRGB(135, 135, 148),
		Border         = Color3.fromRGB(40, 40, 46),
		Success        = Color3.fromRGB(150, 220, 170),
		Warning        = Color3.fromRGB(230, 200, 140),
		Error          = Color3.fromRGB(230, 120, 130),
		Nebula         = Color3.fromRGB(38, 38, 48),
		Star           = Color3.fromRGB(255, 255, 255),
	},
	Aurora = {
		Background     = Color3.fromRGB(8, 18, 22),
		Secondary      = Color3.fromRGB(12, 26, 32),
		Tertiary       = Color3.fromRGB(17, 36, 44),
		Elevated       = Color3.fromRGB(23, 48, 58),
		Accent         = Color3.fromRGB(88, 232, 196),
		AccentAlt      = Color3.fromRGB(96, 180, 255),
		Text           = Color3.fromRGB(230, 248, 246),
		SubText        = Color3.fromRGB(138, 176, 180),
		Border         = Color3.fromRGB(34, 68, 80),
		Success        = Color3.fromRGB(110, 240, 180),
		Warning        = Color3.fromRGB(255, 208, 120),
		Error          = Color3.fromRGB(255, 120, 132),
		Nebula         = Color3.fromRGB(24, 92, 96),
		Star           = Color3.fromRGB(226, 255, 250),
	},
	Solstice = {
		Background     = Color3.fromRGB(20, 14, 12),
		Secondary      = Color3.fromRGB(30, 21, 17),
		Tertiary       = Color3.fromRGB(42, 29, 23),
		Elevated       = Color3.fromRGB(54, 38, 30),
		Accent         = Color3.fromRGB(255, 160, 84),
		AccentAlt      = Color3.fromRGB(255, 108, 108),
		Text           = Color3.fromRGB(252, 240, 232),
		SubText        = Color3.fromRGB(186, 158, 142),
		Border         = Color3.fromRGB(78, 54, 42),
		Success        = Color3.fromRGB(150, 220, 140),
		Warning        = Color3.fromRGB(255, 205, 110),
		Error          = Color3.fromRGB(255, 108, 108),
		Nebula         = Color3.fromRGB(120, 60, 30),
		Star           = Color3.fromRGB(255, 244, 226),
	},
}

Theme.Colors = Util.Copy(Theme.Presets.Astral)

-- Registers an instance property against a theme key.
-- modifier(colorFromTheme) -> finalValue, allows tints/shades per element.
function Theme:Apply(instance, property, key, modifier)
	if typeof(instance) ~= "Instance" then return instance end
	local resolved = self:Resolve(key)
	if not resolved then
		warn("[Astryn] unknown theme key '" .. tostring(key) .. "', falling back to Text")
		resolved = "Text"
	end
	key = resolved

	local entries = self.Registry[instance]
	if not entries then
		entries = {}
		self.Registry[instance] = entries
		-- self-prune: the entry disappears with the instance
		instance.Destroying:Once(function()
			self.Registry[instance] = nil
		end)
	end
	entries[property] = { Key = key, Modifier = modifier }

	local value = self.Colors[key]
	instance[property] = modifier and modifier(value) or value
	return instance
end

function Theme:Unregister(instance)
	self.Registry[instance] = nil
end

function Theme:Get(key)
	return self.Colors[key] or self.Colors.Text
end

-- Repaints are coalesced: many rapid Set calls (dragging the accent
-- picker, for instance) collapse into one pass on the next frame.
function Theme:Repaint(animated)
	if self._queued then
		self._animateQueued = self._animateQueued and animated
		return
	end
	self._queued = true
	self._animateQueued = animated

	task.defer(function()
		self._queued = false
		local useTween = self._animateQueued
		for instance, entries in pairs(self.Registry) do
			if typeof(instance) ~= "Instance" or instance.Parent == nil then
				if typeof(instance) ~= "Instance" or not instance:IsDescendantOf(game) then
					self.Registry[instance] = nil
					continue
				end
			end
			for property, entry in pairs(entries) do
				local color = self.Colors[entry.Key]
				if color then
					local value = entry.Modifier and entry.Modifier(color) or color
					if useTween then
						Animation.Tween(instance, { [property] = value }, "Normal")
					else
						pcall(function() instance[property] = value end)
					end
				end
			end
		end
	end)
end

-- Friendly aliases: callers writing MutedText, Primary or Foreground get
-- mapped onto the canonical palette keys instead of a warning.
Theme.Aliases = {
	MutedText      = "SubText",
	TextSecondary  = "SubText",
	SubtleText     = "SubText",
	Primary        = "Accent",
	Highlight      = "Accent",
	Foreground     = "Text",
	Stroke         = "Border",
	Outline        = "Border",
	Surface        = "Secondary",
	SurfaceAlt     = "Tertiary",
}

function Theme:Resolve(key)
	if self.Colors[key] ~= nil then return key end
	return self.Aliases[key]
end

function Theme:Set(theme, animated)
	if type(theme) == "string" then
		local preset = self.Presets[theme]
		if not preset then return false end
		self.Current = theme
		self.Colors = Util.Copy(preset)
	elseif type(theme) == "table" then
		self.Current = theme.Name or "Custom"
		for key, value in pairs(theme) do
			if typeof(value) == "Color3" then
				local resolved = self:Resolve(key) or key
				self.Colors[resolved] = value
			end
		end
	else
		return false
	end
	self:Repaint(animated ~= false)
	return true
end

Astryn.Theme = Theme

--==================================================================
-- CORE / ANIMATION
--==================================================================

Animation = {}
Animation.Enabled = true
Animation.Speed = 1

Animation.Preset = {
	Fast    = TweenInfo.new(0.14, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	Normal  = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Slow    = TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Spring  = TweenInfo.new(0.46, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	Smooth  = TweenInfo.new(0.32, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
}

-- Tracks the tween currently driving each property so a new tween on
-- the same property cancels the old one instead of fighting it (the
-- cause of the jittery hover/resize behaviour in v1.0).
local ActiveTweens = setmetatable({}, { __mode = "k" })

local function cancelConflicts(instance, properties)
	local record = ActiveTweens[instance]
	if not record then return end
	for property in pairs(properties) do
		local tween = record[property]
		if tween then
			if tween.PlaybackState == Enum.PlaybackState.Playing then
				tween:Cancel()
			end
			record[property] = nil
		end
	end
end

local function trackTween(instance, properties, tween)
	local record = ActiveTweens[instance]
	if not record then
		record = {}
		ActiveTweens[instance] = record
	end
	for property in pairs(properties) do
		record[property] = tween
	end
	tween.Completed:Once(function()
		for property in pairs(properties) do
			if record[property] == tween then record[property] = nil end
		end
	end)
end

-- Animation.Tween(instance, properties, infoOrPresetName)
-- Safe against destroyed instances and invalid property names.
function Animation.Tween(instance, properties, info)
	if not Util.IsAlive(instance) then return nil end
	if type(info) == "string" then info = Animation.Preset[info] or Animation.Preset.Normal end
	info = info or Animation.Preset.Normal

	cancelConflicts(instance, properties)

	if not Animation.Enabled then
		for property, value in pairs(properties) do
			pcall(function() instance[property] = value end)
		end
		return nil
	end

	if Animation.Speed ~= 1 then
		info = TweenInfo.new(
			info.Time / Animation.Speed,
			info.EasingStyle, info.EasingDirection,
			info.RepeatCount, info.Reverses, info.DelayTime
		)
	end

	local ok, tween = pcall(TweenService.Create, TweenService, instance, info, properties)
	if not ok then
		-- invalid property for this class: fall back to a direct write
		for property, value in pairs(properties) do
			pcall(function() instance[property] = value end)
		end
		return nil
	end

	trackTween(instance, properties, tween)
	tween:Play()
	return tween
end

-- Instantly settles an instance, used during teardown.
function Animation.Stop(instance)
	local record = ActiveTweens[instance]
	if not record then return end
	for property, tween in pairs(record) do
		pcall(function() tween:Cancel() end)
		record[property] = nil
	end
	ActiveTweens[instance] = nil
end

-- Staggered fade-in used when a tab's content is shown.
-- Only transparency is animated: positions are owned by UIListLayout,
-- so writing to them here would be overwritten every frame.
-- REVEAL_LIMIT caps the stagger: only the first screenful of elements is
-- animated. Beyond that the user cannot see the reveal anyway, and a
-- 100-element tab would otherwise queue 100 delayed tweens per switch.
local REVEAL_LIMIT = 14

function Animation.Reveal(children)
	if not Animation.Enabled then return end
	local index = 0
	for _, child in ipairs(children) do
		if index >= REVEAL_LIMIT then break end
		if child:IsA("GuiObject") and child.Visible then
			index += 1
			local targets = {}
			if child.BackgroundTransparency < 1 then
				targets.Background = child.BackgroundTransparency
				child.BackgroundTransparency = 1
			end
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				targets.Text = child.TextTransparency
				child.TextTransparency = 1
			end
			task.delay(index * 0.02, function()
				if not child.Parent then return end
				if targets.Background then
					Animation.Tween(child, { BackgroundTransparency = targets.Background }, "Smooth")
				end
				if targets.Text then
					Animation.Tween(child, { TextTransparency = targets.Text }, "Smooth")
				end
			end)
		end
	end
end

Astryn.Animation = Animation

--==================================================================
-- CORE / CONFIG STORE
-- JSON-backed on executors that expose a filesystem, in-memory otherwise.
--==================================================================

local Config = {}
Config.Folder = "AstrynHub"
Config.Memory = {}
Config.Registry = {}   -- flag -> { Get, Set }
Config.Defaults = {}   -- flag -> value captured at registration
Config.AutoLoad = nil

function Config:_Path(name)
	return self.Folder .. "/configs/" .. name .. ".json"
end

function Config:_EnsureFolders()
	if not Env.HasFileSystem then return end
	pcall(function()
		if not isfolder(self.Folder) then makefolder(self.Folder) end
		if not isfolder(self.Folder .. "/configs") then makefolder(self.Folder .. "/configs") end
	end)
end

function Config:Write(path, contents)
	if Env.HasFileSystem then
		self:_EnsureFolders()
		local ok = pcall(writefile, path, contents)
		if ok then return true end
	end
	self.Memory[path] = contents
	return true
end

function Config:Read(path)
	if Env.HasFileSystem then
		local ok, data = pcall(function()
			if isfile(path) then return readfile(path) end
			return nil
		end)
		if ok and data then return data end
	end
	return self.Memory[path]
end

function Config:Erase(path)
	if Env.HasFileSystem then
		pcall(function()
			if isfile(path) then delfile(path) end
		end)
	end
	self.Memory[path] = nil
end

function Config:List()
	local names = {}
	if Env.HasFileSystem then
		local ok, files = pcall(listfiles, self.Folder .. "/configs")
		if ok and files then
			for _, file in ipairs(files) do
				local name = tostring(file):match("([^/\\]+)%.json$")
				if name then table.insert(names, name) end
			end
		end
	end
	for path in pairs(self.Memory) do
		local name = path:match("([^/\\]+)%.json$")
		if name and not table.find(names, name) then table.insert(names, name) end
	end
	table.sort(names)
	return names
end

-- Registers a configurable element. `handle` must expose Get() and Set(value).
-- The value present at registration is remembered as that flag's default so
-- Config:Reset() can restore it later.
function Config:Register(flag, handle)
	if not flag then return end
	self.Registry[flag] = handle
	local ok, value = pcall(handle.Get)
	if ok then self.Defaults[flag] = value end
end

function Config:Unregister(flag)
	if flag then
		self.Registry[flag] = nil
		self.Defaults[flag] = nil
	end
end

-- Serialisation: Color3 and EnumItem are stored as descriptive tables
local function Encode(value)
	local t = typeof(value)
	if t == "Color3" then
		return { __type = "Color3", R = value.R, G = value.G, B = value.B }
	elseif t == "EnumItem" then
		return { __type = "EnumItem", Enum = tostring(value.EnumType), Name = value.Name }
	elseif t == "table" then
		local out = {}
		for k, v in pairs(value) do out[tostring(k)] = Encode(v) end
		return { __type = "table", Data = out }
	end
	return value
end

local function Decode(value)
	if type(value) == "table" then
		if value.__type == "Color3" then
			return Color3.new(value.R, value.G, value.B)
		elseif value.__type == "EnumItem" then
			local enumName = value.Enum:gsub("^Enum%.", "")
			local ok, item = pcall(function() return Enum[enumName][value.Name] end)
			return ok and item or nil
		elseif value.__type == "table" then
			local out = {}
			for k, v in pairs(value.Data) do out[k] = Decode(v) end
			return out
		end
	end
	return value
end

function Config:Snapshot()
	local data = { __astryn = Astryn.Version, values = {} }
	for flag, handle in pairs(self.Registry) do
		local ok, value = pcall(handle.Get)
		if ok and value ~= nil then
			data.values[flag] = Encode(value)
		end
	end
	return data
end

function Config:Save(name)
	name = tostring(name or "default")
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self:Snapshot())
	if not ok then return false, "Failed to encode configuration" end
	self:Write(self:_Path(name), encoded)
	return true
end

function Config:Load(name)
	name = tostring(name or "default")
	local raw = self:Read(self:_Path(name))
	if not raw then return false, "Configuration not found" end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(data) ~= "table" or type(data.values) ~= "table" then
		return false, "Configuration is corrupted"
	end
	-- Unknown flags are skipped, and one bad value cannot abort the load.
	local applied, skipped = 0, 0
	for flag, encoded in pairs(data.values) do
		local handle = self.Registry[flag]
		if handle then
			local decoded, value = pcall(Decode, encoded)
			if decoded and value ~= nil and pcall(handle.Set, value, true) then
				applied += 1
			else
				skipped += 1
				warn("[Astryn] could not restore flag '" .. tostring(flag) .. "'")
			end
		else
			skipped += 1
		end
	end
	return true, applied, skipped
end

-- Restores every registered element to the value it had when it was created.
function Config:Reset()
	local restored = 0
	for flag, handle in pairs(self.Registry) do
		local default = self.Defaults[flag]
		if default ~= nil and pcall(handle.Set, default, true) then
			restored += 1
		end
	end
	return true, restored
end

function Config:Delete(name)
	name = tostring(name or "default")
	if not self:Read(self:_Path(name)) then return false, "Configuration not found" end
	self:Erase(self:_Path(name))
	return true
end

Astryn.Config = Config

--==================================================================
-- SYSTEMS / ASTRAL BACKGROUND
-- A lightweight star field: N small frames drifting upward with a
-- gentle twinkle, plus two soft nebula blobs behind them. One
-- Heartbeat connection per window, paused whenever the window hides.
--==================================================================

local Background = {}
Background.__index = Background

local STAR_BUDGET = { High = 34, Balanced = 20, Performance = 0 }

function Background.new(parent, mode)
	local self = setmetatable({}, Background)
	self.Maid = Maid.new()
	self.Stars = {}
	self.Running = false
	self.Mode = mode or "High"

	self.Canvas = Util.New("Frame", {
		Name = "AstralCanvas",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 0,
		Parent = parent,
	})
	self.Maid:Give(self.Canvas)

	-- base cosmic gradient
	local base = Util.New("Frame", {
		Name = "Gradient",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = self.Canvas,
	})
	Theme:Apply(base, "BackgroundColor3", "Background")
	Util.New("UIGradient", {
		Rotation = 115,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(190, 190, 210)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 255, 255)),
		}),
		Parent = base,
	})

	-- nebula blobs (soft radial glows)
	self.Nebulas = {}
	for index, spec in ipairs({
		{ pos = UDim2.fromScale(0.18, 0.12), size = UDim2.fromScale(0.75, 0.9), key = "Nebula",   trans = 0.78 },
		{ pos = UDim2.fromScale(0.82, 0.86), size = UDim2.fromScale(0.85, 1.0), key = "AccentAlt", trans = 0.90 },
	}) do
		local blob = Util.New("ImageLabel", {
			Name = "Nebula" .. index,
			BackgroundTransparency = 1,
			Image = "rbxassetid://8992230677", -- soft radial falloff
			ImageTransparency = spec.trans,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = spec.pos,
			Size = spec.size,
			ZIndex = 0,
			Parent = self.Canvas,
		})
		Theme:Apply(blob, "ImageColor3", spec.key)
		blob:SetAttribute("BasePosX", spec.pos.X.Scale)
		blob:SetAttribute("BasePosY", spec.pos.Y.Scale)
		table.insert(self.Nebulas, blob)
	end

	self:Rebuild()
	return self
end

function Background:Rebuild()
	for _, star in ipairs(self.Stars) do
		if star.Frame then star.Frame:Destroy() end
	end
	table.clear(self.Stars)

	local count = STAR_BUDGET[self.Mode] or STAR_BUDGET.High
	for _ = 1, count do
		local size = math.random(10, 26) / 10
		local frame = Util.New("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = math.random(35, 80) / 100,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromScale(math.random(), math.random()),
			ZIndex = 0,
			Parent = self.Canvas,
		})
		Util.Corner(4, frame)
		Theme:Apply(frame, "BackgroundColor3", "Star")
		table.insert(self.Stars, {
			Frame = frame,
			Speed = math.random(8, 26) / 1000,   -- scale units per second
			Phase = math.random() * math.pi * 2,
			Twinkle = math.random(6, 16) / 10,
			BaseTransparency = frame.BackgroundTransparency,
		})
	end
end

function Background:SetMode(mode)
	self.Mode = mode
	self:Rebuild()
	if mode == "Performance" then
		self:Stop()
		for _, blob in ipairs(self.Nebulas) do blob.Visible = false end
	else
		for _, blob in ipairs(self.Nebulas) do blob.Visible = true end
		self:Start()
	end
end

function Background:Start()
	if self.Running or self.Mode == "Performance" then return end
	self.Running = true
	self.Clock = self.Clock or 0
	self.JobKey = self.JobKey or ("AstralBackground_" .. Util.NextId("BG"))

	Scheduler:Add(self.JobKey, function(dt)
		if not Animation.Enabled then return end
		if not Util.IsAlive(self.Canvas) then
			self:Stop()
			return
		end
		self.Clock += dt
		for _, star in ipairs(self.Stars) do
			local frame = star.Frame
			local y = frame.Position.Y.Scale - star.Speed * dt
			if y < -0.05 then
				frame.Position = UDim2.fromScale(math.random(), 1.05)
			else
				frame.Position = UDim2.new(frame.Position.X.Scale, 0, y, 0)
			end
			frame.BackgroundTransparency = Util.Clamp(
				star.BaseTransparency + math.sin(self.Clock * star.Twinkle + star.Phase) * 0.22, 0, 1)
		end
		-- nebula parallax runs at a third of the star rate; it is a slow
		-- gradient drift, so recomputing it every frame is wasted work
		self.NebulaTick = (self.NebulaTick or 0) + dt
		if self.NebulaTick >= 1 / 20 then
			self.NebulaTick = 0
			for index, blob in ipairs(self.Nebulas) do
				local drift = math.sin(self.Clock * 0.07 + index) * 0.018
				blob.Position = UDim2.fromScale(
					blob:GetAttribute("BasePosX") + drift,
					blob:GetAttribute("BasePosY") + drift * 0.5
				)
			end
		end
	end)
end

function Background:Stop()
	self.Running = false
	if self.JobKey then Scheduler:Remove(self.JobKey) end
end

function Background:Destroy()
	self:Stop()
	self.Maid:Clean()
end

Astryn.Background = Background

--==================================================================
-- SYSTEMS / OVERLAY GUI
-- A single top-level ScreenGui shared by notifications, the key
-- screen, loading screens and dialogs. Created lazily.
--==================================================================

local Overlay = {}
Overlay.Gui = nil
Overlay.Maid = Maid.new()

function Overlay:Get()
	if self.Gui and self.Gui.Parent then return self.Gui end
	local gui = Util.New("ScreenGui", {
		Name = "Astryn_" .. Util.NextId("Overlay"),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 9999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	if Env.Protect then pcall(Env.Protect, gui) end
	gui.Parent = Util.GuiParent()
	self.Gui = gui
	self.Maid:Give(gui)
	return gui
end

function Overlay:Destroy()
	self.Maid:Clean()
	self.Gui = nil
end

--==================================================================
-- SYSTEMS / NOTIFICATIONS
-- Right-aligned stack, newest on top, slide + fade, timer bar.
--==================================================================

local Notification = {}
Notification.Active = {}
Notification.Holder = nil
Notification._Order = 0

-- newest notification sits on top of the stack
function Notification:_NextOrder()
	self._Order -= 1
	return self._Order
end

function Notification:_Holder()
	if self.Holder and self.Holder.Parent then return self.Holder end
	local gui = Overlay:Get()
	local holder = Util.New("Frame", {
		Name = "NotificationHolder",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 500,
		Parent = gui,
	})
	Util.New("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = holder,
	})
	-- keep the stack clear of the mobile top bar / notches
	local inset = GuiService:GetGuiInset()
	holder.Position = UDim2.new(1, -18, 0, 18 + inset.Y)
	self.Holder = holder
	return holder
end

function Notification:Notify(config)
	config = config or {}
	local title    = tostring(config.Title or Astryn.Name)
	local content  = tostring(config.Content or config.Text or "")
	local duration = Util.Clamp(tonumber(config.Duration) or 4, 1, 30)
	local variant  = config.Variant or config.Type or "Default"   -- Default/Success/Warning/Error
	local icon     = config.Icon

	local accentKey = ({ Success = "Success", Warning = "Warning", Error = "Error" })[variant] or "Accent"

	local holder = self:_Holder()
	local maid = Maid.new()

	local card = Util.New("Frame", {
		Name = "Notification",
		BackgroundColor3 = Color3.fromRGB(20, 20, 34),
		BackgroundTransparency = 0.04,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(340, 0),
		ZIndex = 501,
		LayoutOrder = Notification:_NextOrder(),
		Parent = holder,
	})
	maid:Give(card)
	Theme:Apply(card, "BackgroundColor3", "Secondary")
	Util.Corner(Tokens.Radius.Panel, card)
	local stroke = Util.Stroke(nil, 1, 0.35, card)
	Theme:Apply(stroke, "Color", "Border")
	Util.Padding(card, 12, 14, 14, 14)

	-- accent rail
	local rail = Util.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-14, 0),
		Size = UDim2.new(0, 3, 1, 0),
		ZIndex = 502,
		Parent = card,
	})
	Util.Corner(3, rail)
	Theme:Apply(rail, "BackgroundColor3", accentKey)

	local hasIcon = icon ~= nil
	local textOffset = hasIcon and 30 or 0

	if hasIcon then
		local glyph, isImage = Icons.Resolve(icon)
		if isImage then
			local image = Util.New("ImageLabel", {
				BackgroundTransparency = 1,
				Image = glyph,
				Size = UDim2.fromOffset(20, 20),
				Position = UDim2.fromOffset(0, 1),
				ZIndex = 502,
				Parent = card,
			})
			Theme:Apply(image, "ImageColor3", accentKey)
		else
			local label = Util.New("TextLabel", {
				BackgroundTransparency = 1,
				Text = glyph,
				Font = Enum.Font.GothamBold,
				TextSize = 17,
				Size = UDim2.fromOffset(22, 20),
				Position = UDim2.fromOffset(0, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 502,
				Parent = card,
			})
			Theme:Apply(label, "TextColor3", accentKey)
		end
	end

	local titleLabel = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(textOffset, 0),
		Size = UDim2.new(1, -textOffset, 0, 18),
		ZIndex = 502,
		Parent = card,
	})
	Theme:Apply(titleLabel, "TextColor3", "Text")

	local bodyLabel = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = content,
		Font = Enum.Font.Gotham,
		TextSize = 12.5,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(textOffset, 20),
		Size = UDim2.new(1, -textOffset, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 502,
		Parent = card,
	})
	Theme:Apply(bodyLabel, "TextColor3", "SubText")

	local track = Util.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 64),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 10),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 502,
		Parent = card,
	})
	Util.Corner(2, track)
	Theme:Apply(track, "BackgroundColor3", "Tertiary")

	local fill = Util.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 503,
		Parent = track,
	})
	Util.Corner(2, fill)
	Theme:Apply(fill, "BackgroundColor3", accentKey)

	-- entrance
	card.Position = UDim2.fromOffset(340, 0)
	Animation.Tween(card, { Position = UDim2.fromOffset(0, 0) }, "Smooth")
	Animation.Tween(fill, { Size = UDim2.fromScale(0, 1) },
		TweenInfo.new(duration, Enum.EasingStyle.Linear))

	local dismissed = false
	local function dismiss()
		if dismissed then return end
		dismissed = true
		local tween = Animation.Tween(card, {
			Position = UDim2.fromOffset(340, 0),
			BackgroundTransparency = 1,
		}, "Smooth")
		for _, descendant in ipairs(card:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				Animation.Tween(descendant, { TextTransparency = 1 }, "Smooth")
			elseif descendant:IsA("ImageLabel") then
				Animation.Tween(descendant, { ImageTransparency = 1 }, "Smooth")
			elseif descendant:IsA("Frame") then
				Animation.Tween(descendant, { BackgroundTransparency = 1 }, "Smooth")
			elseif descendant:IsA("UIStroke") then
				Animation.Tween(descendant, { Transparency = 1 }, "Smooth")
			end
		end
		if tween then tween.Completed:Wait() else task.wait(0.1) end
		maid:Clean()
		local index = table.find(Notification.Active, maid)
		if index then table.remove(Notification.Active, index) end
	end

	-- click to dismiss early
	local button = Util.New("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 504,
		Parent = card,
	})
	maid:Give(button.MouseButton1Click:Connect(function()
		task.spawn(dismiss)
	end))

	table.insert(Notification.Active, maid)
	task.delay(duration, function() task.spawn(dismiss) end)

	return { Dismiss = function() task.spawn(dismiss) end }
end

function Notification:ClearAll()
	for index = #self.Active, 1, -1 do
		self.Active[index]:Clean()
		table.remove(self.Active, index)
	end
end

Astryn.Notification = Notification

--==================================================================
-- SYSTEMS / DIALOG (modal confirm boxes)
--==================================================================

local Dialog = {}

function Dialog:Show(config)
	config = config or {}
	local gui = Overlay:Get()
	local maid = Maid.new()

	local blocker = Util.New("TextButton", {
		Name = "DialogBlocker",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		AutoButtonColor = false,
		ZIndex = 800,
		Parent = gui,
	})
	maid:Give(blocker)
	Animation.Tween(blocker, { BackgroundTransparency = 0.45 }, "Smooth")

	local card = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(17, 17, 30),
		ZIndex = 801,
		Parent = blocker,
	})
	Theme:Apply(card, "BackgroundColor3", "Secondary")
	Util.Corner(Tokens.Radius.Panel, card)
	local stroke = Util.Stroke(nil, 1, 0.3, card)
	Theme:Apply(stroke, "Color", "Border")
	Util.Padding(card, 18, 16, 18, 18)
	Util.New("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = card,
	})

	local title = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(config.Title or "Astryn HUB"),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		ZIndex = 802,
		Parent = card,
	})
	Theme:Apply(title, "TextColor3", "Text")

	local body = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(config.Content or ""),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		ZIndex = 802,
		Parent = card,
	})
	Theme:Apply(body, "TextColor3", "SubText")

	local row = Util.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 3,
		ZIndex = 802,
		Parent = card,
	})
	Util.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})

	local function close()
		Animation.Tween(blocker, { BackgroundTransparency = 1 }, "Fast")
		local tween = Animation.Tween(card, { Size = UDim2.fromOffset(340, card.AbsoluteSize.Y * 0.9) }, "Fast")
		task.delay(0.18, function() maid:Clean() end)
		if tween then end
	end

	local buttons = config.Buttons or { { Name = "OK" } }
	for index, spec in ipairs(buttons) do
		local isPrimary = spec.Primary or index == 1
		local button = Util.New("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(31, 31, 54),
			Text = tostring(spec.Name or "OK"),
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			Size = UDim2.fromOffset(100, 34),
			LayoutOrder = index,
			ZIndex = 803,
			Parent = row,
		})
		Util.Corner(9, button)
		Theme:Apply(button, "BackgroundColor3", isPrimary and "Accent" or "Elevated")
		Theme:Apply(button, "TextColor3", isPrimary and "Background" or "Text",
			isPrimary and function(c) return Color3.fromRGB(14, 14, 22) end or nil)

		button.MouseEnter:Connect(function()
			Animation.Tween(button, { BackgroundColor3 = Util.Shift(button.BackgroundColor3, 0.06) }, "Fast")
		end)
		local restColor = isPrimary and Theme:Get("Accent") or Theme:Get("Elevated")
		button.MouseLeave:Connect(function()
			Animation.Tween(button, { BackgroundColor3 = restColor }, "Fast")
		end)
		maid:Give(button.MouseButton1Click:Connect(function()
			close()
			if spec.Callback then task.spawn(spec.Callback) end
		end))
	end

	-- entrance pop
	card.Size = UDim2.fromOffset(310, 0)
	Animation.Tween(card, { Size = UDim2.fromOffset(340, 0) }, "Spring")

	return { Close = close }
end

Astryn.Dialog = Dialog

--==================================================================
-- SYSTEMS / LOADING SCREEN
-- Orbiting astral spinner with brand lockup and progress line.
--==================================================================

local Loading = {}

function Loading:Show(config)
	config = config or {}
	local gui = Overlay:Get()
	local maid = Maid.new()

	local root = Util.New("Frame", {
		Name = "AstrynLoading",
		BackgroundColor3 = Color3.fromRGB(11, 11, 20),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 700,
		Parent = gui,
	})
	maid:Give(root)
	Theme:Apply(root, "BackgroundColor3", "Background")
	Animation.Tween(root, { BackgroundTransparency = 0.12 }, "Smooth")

	local background = Background.new(root, Animation.Enabled and "Balanced" or "Performance")
	background.Canvas.BackgroundTransparency = 1
	background:Start()
	maid:Give(background)

	local center = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(260, 150),
		BackgroundTransparency = 1,
		ZIndex = 702,
		Parent = root,
	})

	-- rotating orbit ring
	local ring = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(52, 52),
		BackgroundTransparency = 1,
		ZIndex = 702,
		Parent = center,
	})
	local orbit = Util.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 702,
		Parent = ring,
	})
	local ringStroke = Util.New("UIStroke", {
		Thickness = 2,
		Transparency = 0.82,
		Parent = orbit,
	})
	Theme:Apply(ringStroke, "Color", "Accent")
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = orbit })

	local satellite = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BorderSizePixel = 0,
		ZIndex = 703,
		Parent = orbit,
	})
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = satellite })
	Theme:Apply(satellite, "BackgroundColor3", "Accent")

	local spin = 0
	local spinnerKey = Util.NextId("LoadingSpinner")
	Scheduler:Add(spinnerKey, function(dt)
		if not Util.IsAlive(orbit) then
			Scheduler:Remove(spinnerKey)
			return
		end
		if not Animation.Enabled then return end
		spin += dt * 2.4
		orbit.Rotation = math.deg(spin) % 360
		satellite.BackgroundTransparency = 0.1 + math.abs(math.sin(spin)) * 0.25
	end)
	maid:Give(function() Scheduler:Remove(spinnerKey) end)

	local title = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(config.Title or "ASTRYN HUB"),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 702,
		Parent = center,
	})
	Theme:Apply(title, "TextColor3", "Text")

	local subtitle = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(config.Subtitle or "Aligning the constellations..."),
		Font = Enum.Font.Gotham,
		TextSize = 12.5,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 702,
		Parent = center,
	})
	Theme:Apply(subtitle, "TextColor3", "SubText")

	local track = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124),
		Size = UDim2.fromOffset(180, 3),
		BackgroundColor3 = Color3.fromRGB(31, 31, 54),
		BorderSizePixel = 0,
		ZIndex = 702,
		Parent = center,
	})
	Util.Corner(3, track)
	Theme:Apply(track, "BackgroundColor3", "Elevated")

	local fill = Util.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BorderSizePixel = 0,
		ZIndex = 703,
		Parent = track,
	})
	Util.Corner(3, fill)
	Theme:Apply(fill, "BackgroundColor3", "Accent")

	local handle = {}

	function handle:SetProgress(alpha, text)
		Animation.Tween(fill, { Size = UDim2.fromScale(Util.Clamp(alpha, 0, 1), 1) }, "Smooth")
		if text then subtitle.Text = tostring(text) end
	end

	function handle:SetStatus(text)
		subtitle.Text = tostring(text)
	end

	function handle:Close()
		Animation.Tween(root, { BackgroundTransparency = 1 }, "Smooth")
		Animation.Tween(center, { Position = UDim2.fromScale(0.5, 0.46) }, "Smooth")
		for _, descendant in ipairs(center:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				Animation.Tween(descendant, { TextTransparency = 1 }, "Smooth")
			elseif descendant:IsA("Frame") then
				Animation.Tween(descendant, { BackgroundTransparency = 1 }, "Smooth")
			elseif descendant:IsA("UIStroke") then
				Animation.Tween(descendant, { Transparency = 1 }, "Smooth")
			end
		end
		task.delay(0.35, function() maid:Clean() end)
	end

	-- auto-advance when a Duration is provided
	if config.Duration then
		task.spawn(function()
			local steps = 24
			for step = 1, steps do
				handle:SetProgress(step / steps)
				task.wait(config.Duration / steps)
			end
			if config.AutoClose ~= false then handle:Close() end
		end)
	end

	return handle
end

Astryn.Loading = Loading

--==================================================================
-- SYSTEMS / KEY SYSTEM
--
-- Fully modular: the framework NEVER decides whether a key is valid.
-- Supply a Validate function returning (ok:boolean, message:string?).
-- It may yield (HTTP request, remote check, etc.) — it runs inside a
-- coroutine while the UI shows a verifying state.
--
--   Astryn:SetKeySystem({
--       Enabled = true,
--       Title = "Astryn HUB",
--       Subtitle = "Enter your key to continue",
--       Placeholder = "Astryn Key",
--       SaveKey = true,
--       GetKeyLink = "https://example.com/key",
--       Validate = function(key) ... return true end,
--   })
--==================================================================

local KeySystem = {}
KeySystem.Config = {
	Enabled = false,
	Title = "Astryn HUB",
	Subtitle = "Enter your key to continue",
	Placeholder = "Astryn Key",
	Note = "Your key unlocks the astral interface.",
	SaveKey = true,
	GetKeyLink = nil,
	Validate = nil,
}

-- Accepts either Validate or Verify as the provider function name, so
-- both documented spellings work.
function KeySystem:Configure(config)
	if type(config) ~= "table" then
		warn("[Astryn] SetKeySystem expects a table")
		return
	end
	for key, value in pairs(config) do
		self.Config[key] = value
	end
	if type(config.Verify) == "function" and type(config.Validate) ~= "function" then
		self.Config.Validate = config.Verify
	end
	self.Config.Enabled = self.Config.Enabled == true
end

function KeySystem:_SavedPath()
	return Config.Folder .. "/key.txt"
end

function KeySystem:GetSavedKey()
	if not self.Config.SaveKey then return nil end
	local saved = Config:Read(self:_SavedPath())
	return (saved and #saved > 0) and saved or nil
end

function KeySystem:SaveKey(key)
	if self.Config.SaveKey then Config:Write(self:_SavedPath(), key) end
end

function KeySystem:ClearKey()
	Config:Erase(self:_SavedPath())
end

-- Runs the user-supplied validator safely. With no validator the gate
-- fails closed — deliberately, so no placeholder key ever ships.
function KeySystem:Validate(key)
	local validator = self.Config.Validate
	if type(validator) ~= "function" then
		return false, "No key validator configured"
	end
	local ok, result, message = pcall(validator, key)
	if not ok then
		return false, "Validator error: " .. tostring(result)
	end
	if type(result) == "table" then
		return result.Success == true, result.Message
	end
	return result == true, message
end

-- Prompt returns true/false through the supplied `onResult` callback.
function KeySystem:Prompt(onResult)
	local cfg = self.Config
	local gui = Overlay:Get()
	local maid = Maid.new()
	local finished = false

	local function finish(success)
		if finished then return end
		finished = true
		task.delay(0.36, function() maid:Clean() end)
		task.spawn(onResult, success)
	end

	local blocker = Util.New("Frame", {
		Name = "AstrynKeyScreen",
		BackgroundColor3 = Color3.fromRGB(5, 5, 10),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 600,
		Parent = gui,
	})
	maid:Give(blocker)
	Animation.Tween(blocker, { BackgroundTransparency = 0.25 }, "Smooth")

	local scale = Util.New("UIScale", { Scale = 1, Parent = blocker })
	local viewport = Util.Viewport()
	scale.Scale = Util.Clamp(math.min(viewport.X / 700, viewport.Y / 560), 0.62, 1.1)

	local card = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(380, 330),
		BackgroundColor3 = Color3.fromRGB(11, 11, 20),
		BackgroundTransparency = 0.04,
		ClipsDescendants = true,
		ZIndex = 601,
		Parent = blocker,
	})
	Theme:Apply(card, "BackgroundColor3", "Background")
	Util.Corner(Tokens.Radius.Window, card)
	local cardStroke = Util.Stroke(nil, 1, 0.3, card)
	Theme:Apply(cardStroke, "Color", "Border")

	local background = Background.new(card, Animation.Enabled and "Balanced" or "Performance")
	background:Start()
	maid:Give(background)

	local content = Util.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 604,
		Parent = card,
	})
	Util.Padding(content, 26, 22, 26, 26)

	local emblem = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = "✦",
		Font = Enum.Font.GothamBold,
		TextSize = 30,
		Size = UDim2.new(1, 0, 0, 34),
		ZIndex = 605,
		Parent = content,
	})
	Theme:Apply(emblem, "TextColor3", "Accent")

	local title = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = string.upper(tostring(cfg.Title or "ASTRYN HUB")),
		Font = Enum.Font.GothamBold,
		TextSize = 21,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 605,
		Parent = content,
	})
	Theme:Apply(title, "TextColor3", "Text")

	local subtitle = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(cfg.Subtitle or "Enter your key to continue"),
		Font = Enum.Font.Gotham,
		TextSize = 12.5,
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 605,
		Parent = content,
	})
	Theme:Apply(subtitle, "TextColor3", "SubText")

	local field = Util.New("Frame", {
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(24, 24, 42),
		ZIndex = 605,
		Parent = content,
	})
	Theme:Apply(field, "BackgroundColor3", "Tertiary")
	Util.Corner(10, field)
	local fieldStroke = Util.Stroke(nil, 1, 0.4, field)
	Theme:Apply(fieldStroke, "Color", "Border")

	local input = Util.New("TextBox", {
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = tostring(cfg.Placeholder or "Astryn Key"),
		Font = Enum.Font.GothamMedium,
		TextSize = 13.5,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 606,
		Parent = field,
	})
	Theme:Apply(input, "TextColor3", "Text")
	Theme:Apply(input, "PlaceholderColor3", "SubText")

	maid:Give(input.Focused:Connect(function()
		Animation.Tween(fieldStroke, { Transparency = 0 }, "Fast")
		fieldStroke.Color = Theme:Get("Accent")
	end))
	maid:Give(input.FocusLost:Connect(function()
		Animation.Tween(fieldStroke, { Transparency = 0.4 }, "Fast")
		fieldStroke.Color = Theme:Get("Border")
	end))

	local status = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(cfg.Note or ""),
		Font = Enum.Font.Gotham,
		TextSize = 11.5,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 605,
		Parent = content,
	})
	Theme:Apply(status, "TextColor3", "SubText")

	local function makeButton(text, y, primary, height)
		local button = Util.New("TextButton", {
			AutoButtonColor = false,
			Text = text,
			Font = Enum.Font.GothamBold,
			TextSize = 13.5,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height or 38),
			BackgroundColor3 = Color3.fromRGB(31, 31, 54),
			ZIndex = 605,
			Parent = content,
		})
		Util.Corner(10, button)
		Theme:Apply(button, "BackgroundColor3", primary and "Accent" or "Elevated")
		if primary then
			button.TextColor3 = Color3.fromRGB(16, 12, 30)
		else
			Theme:Apply(button, "TextColor3", "Text")
		end
		button.MouseEnter:Connect(function()
			Animation.Tween(button, { BackgroundColor3 = Util.Shift(button.BackgroundColor3, 0.07) }, "Fast")
		end)
		button.MouseLeave:Connect(function()
			Animation.Tween(button, {
				BackgroundColor3 = primary and Theme:Get("Accent") or Theme:Get("Elevated"),
			}, "Fast")
		end)
		return button
	end

	local verify = makeButton("VERIFY KEY", 184, true)
	local getKey = makeButton("Get Key", 230, false, 34)
	local cancel = makeButton("Cancel", 270, false, 30)
	cancel.Font = Enum.Font.Gotham
	cancel.TextSize = 12
	cancel.BackgroundTransparency = 1
	Theme:Apply(cancel, "TextColor3", "SubText")

	local busy = false
	local function setStatus(text, key)
		status.Text = text
		status.TextColor3 = Theme:Get(key or "SubText")
	end

	local function shake()
		if not Animation.Enabled then return end
		local base = card.Position
		for index = 1, 3 do
			task.delay(index * 0.05, function()
				if card.Parent then
					card.Position = base + UDim2.fromOffset((index % 2 == 0) and -7 or 7, 0)
				end
			end)
		end
		task.delay(0.2, function() if card.Parent then card.Position = base end end)
	end

	local function attempt(key, silent)
		if busy or finished then return end
		key = tostring(key or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if #key == 0 then
			setStatus("Please enter a key.", "Warning")
			shake()
			return
		end
		busy = true
		verify.Text = "VERIFYING..."
		setStatus("Contacting the astral gateway...", "SubText")

		task.spawn(function()
			local ok, message = KeySystem:Validate(key)
			busy = false
			if finished then return end
			if ok then
				verify.Text = "ACCESS GRANTED"
				verify.BackgroundColor3 = Theme:Get("Success")
				setStatus(message or "Key accepted. Opening Astryn HUB...", "Success")
				KeySystem:SaveKey(key)
				Animation.Tween(card, { Size = UDim2.fromOffset(380, 330), BackgroundTransparency = 1 }, "Smooth")
				Animation.Tween(blocker, { BackgroundTransparency = 1 }, "Smooth")
				finish(true)
			else
				verify.Text = "VERIFY KEY"
				setStatus(message or "Invalid key. Please try again.", "Error")
				if not silent then shake() end
				if silent then KeySystem:ClearKey() end
			end
		end)
	end

	maid:Give(verify.MouseButton1Click:Connect(function() attempt(input.Text) end))
	maid:Give(input.FocusLost:Connect(function(enter)
		if enter then attempt(input.Text) end
	end))

	maid:Give(getKey.MouseButton1Click:Connect(function()
		local link = cfg.GetKeyLink
		if cfg.OnGetKey then
			task.spawn(cfg.OnGetKey)
		end
		if link then
			if setclipboard then
				pcall(setclipboard, link)
				setStatus("Key link copied to clipboard.", "Success")
			else
				setStatus(link, "SubText")
			end
		else
			setStatus("No key link configured.", "Warning")
		end
	end))

	maid:Give(cancel.MouseButton1Click:Connect(function()
		Animation.Tween(blocker, { BackgroundTransparency = 1 }, "Smooth")
		Animation.Tween(card, { Position = UDim2.fromScale(0.5, 0.6), BackgroundTransparency = 1 }, "Smooth")
		finish(false)
	end))

	-- entrance animation
	card.Size = UDim2.fromOffset(340, 300)
	card.BackgroundTransparency = 1
	Animation.Tween(card, { Size = UDim2.fromOffset(380, 330), BackgroundTransparency = 0.04 }, "Spring")

	-- try a saved key silently
	local saved = self:GetSavedKey()
	if saved then
		input.Text = saved
		task.delay(0.4, function() attempt(saved, true) end)
	end
end

Astryn.KeySystem = KeySystem

--==================================================================
-- ELEMENTS
--
-- Every element factory has the signature:
--     Elements.Name(tab, config) -> elementObject
-- where `tab` exposes { Container = ScrollingFrame, Window = Window }.
--
-- To add a new element type later: write one factory here and add a
-- matching `Tab:CreateX` alias in the Tab constructor. Nothing else
-- in the core needs to change.
--==================================================================

local Elements = {}

local ROW_HEIGHT       = Tokens.Height.Row
local ROW_HEIGHT_DESC  = Tokens.Height.RowDesc

-- Shared card shell: background, hover glow, title, optional description
local function BuildRow(tab, config, height)
	assert(type(tab) == "table" and tab.Container,
		"[Astryn] element created without a valid tab")
	local hasDescription = config.Description ~= nil and config.Description ~= ""
	height = height or (hasDescription and ROW_HEIGHT_DESC or ROW_HEIGHT)

	local row = Util.New("Frame", {
		Name = tostring(config.Name or "Element"),
		BackgroundColor3 = Color3.fromRGB(17, 17, 30),
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, 0, 0, height),
		ClipsDescendants = true,
		Parent = tab.Container,
	})
	Theme:Apply(row, "BackgroundColor3", "Secondary")
	Util.Corner(Tokens.Radius.Card, row)
	local stroke = Util.Stroke(nil, 1, 0.55, row)
	Theme:Apply(stroke, "Color", "Border")

	local title = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(config.Name or ""),
		Font = Tokens.Font.Medium,
		TextSize = Tokens.Text.Row,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(Tokens.Spacing.Gutter, hasDescription and 10 or 0),
		Size = UDim2.new(1, -130, 0, hasDescription and 17 or height),
		Parent = row,
	})
	Theme:Apply(title, "TextColor3", "Text")

	local description
	if hasDescription then
		description = Util.New("TextLabel", {
			BackgroundTransparency = 1,
			Text = tostring(config.Description),
			Font = Tokens.Font.Regular,
			TextSize = Tokens.Text.Caption,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(Tokens.Spacing.Gutter, 28),
			Size = UDim2.new(1, -130, 0, 15),
			Parent = row,
		})
		Theme:Apply(description, "TextColor3", "SubText")
	end

	return row, title, description, stroke, height
end

local function HoverGlow(row, stroke, maid)
	maid:Give(row.MouseEnter:Connect(function()
		Animation.Tween(row, { BackgroundTransparency = 0.02 }, "Fast")
		Animation.Tween(stroke, { Transparency = 0.15 }, "Fast")
		stroke.Color = Theme:Get("Accent")
	end))
	maid:Give(row.MouseLeave:Connect(function()
		Animation.Tween(row, { BackgroundTransparency = 0.15 }, "Fast")
		Animation.Tween(stroke, { Transparency = 0.55 }, "Fast")
		stroke.Color = Theme:Get("Border")
	end))
end

-- Every element shares this object shape, so callers can treat any
-- component uniformly: :SetName, :SetDescription, :SetVisible,
-- :SetEnabled, :Get, :Set and :Destroy exist on all of them.
local function MakeObject(tab, config, parts)
	local row, title, description = parts.Row, parts.Title, parts.Description
	local maid = parts.Maid

	local object = {
		Instance = row,
		Type = parts.Type or "Element",
		Name = tostring(config.Name or parts.Type or "Element"),
		Enabled = config.Enabled ~= false,
		Destroyed = false,
	}

	function object:SetName(text)
		self.Name = tostring(text)
		if title then title.Text = self.Name end
	end

	function object:SetDescription(text)
		if description then description.Text = tostring(text or "") end
	end

	function object:SetVisible(state)
		if Util.IsAlive(row) then row.Visible = state ~= false end
	end

	-- Disabled elements dim and stop responding, but keep their value.
	function object:SetEnabled(state)
		self.Enabled = state ~= false
		local fade = self.Enabled and 0 or 0.55
		if title then Animation.Tween(title, { TextTransparency = fade }, "Fast") end
		if description then Animation.Tween(description, { TextTransparency = fade }, "Fast") end
		if parts.OnEnabled then Util.SafeCall(parts.OnEnabled, self.Enabled) end
	end

	-- Idempotent: calling Destroy twice is safe, as is destroying an
	-- element whose parent tab has already been torn down.
	function object:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		if self.Flag then
			Config:Unregister(self.Flag)
			if tab.Window and tab.Window.Flags then tab.Window.Flags[self.Flag] = nil end
		end
		local index = table.find(tab.Elements, self)
		if index then table.remove(tab.Elements, index) end
		if Util.IsAlive(row) then Animation.Stop(row) end
		if maid then maid:Clean() end
	end

	-- default value accessors, overridden by stateful elements
	function object:Get() return nil end
	function object:Set() end

	table.insert(tab.Elements, object)
	if not object.Enabled then object:SetEnabled(false) end
	return object
end

-- Attaches value accessors and wires the element into the config manager.
local function RegisterElement(tab, object, config, getter, setter)
	local flag = config.Flag or config.Name
	object.Flag = flag
	object.Get = function() return getter() end
	object.Set = function(_, value, silent) setter(value, silent) end
	if flag then
		if tab.Window.Flags[flag] then
			warn("[Astryn] duplicate flag '" .. tostring(flag) .. "' — the newer element wins")
		end
		tab.Window.Flags[flag] = object
		Config:Register(flag, { Get = getter, Set = setter })
	end
	return object
end

--------------------------------------------------------------------
-- SECTION
--------------------------------------------------------------------
function Elements.Section(tab, config)
	-- accepts either Tab:CreateSection("Name") or a { Name = ... } table
	config = type(config) == "table" and config or { Name = config }
	local text = config.Name or config.Title or "Section"
	local maid = Maid.new()

	local holder = Util.New("Frame", {
		Name = "Section",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = tab.Container,
	})

	local label = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = string.upper(tostring(text or "Section")),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(4, 10),
		Size = UDim2.new(0, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = holder,
	})
	Theme:Apply(label, "TextColor3", "Accent")

	local line = Util.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(46, 46, 74),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0, 18),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = holder,
	})
	Theme:Apply(line, "BackgroundColor3", "Border")

	-- keep the rule from overlapping the label
	maid:Give(label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		line.Size = UDim2.new(1, -(label.AbsoluteSize.X + 16), 0, 1)
	end))
	task.defer(function()
		if Util.IsAlive(label) then
			line.Size = UDim2.new(1, -(label.AbsoluteSize.X + 16), 0, 1)
		end
	end)

	maid:Give(holder)

	local object = MakeObject(tab, config, { Row = holder, Maid = maid, Type = "Section" })
	function object:SetName(newText)
		self.Name = tostring(newText)
		label.Text = string.upper(self.Name)
	end
	return object
end

--------------------------------------------------------------------
-- DIVIDER
--------------------------------------------------------------------
function Elements.Divider(tab)
	local holder = Util.New("Frame", {
		Name = "Divider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 12),
		Parent = tab.Container,
	})
	local line = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 0, 1),
		BackgroundColor3 = Color3.fromRGB(46, 46, 74),
		BorderSizePixel = 0,
		Parent = holder,
	})
	Theme:Apply(line, "BackgroundColor3", "Border")
	Util.New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = line,
	})

	local maid = Maid.new()
	maid:Give(holder)
	return MakeObject(tab, {}, { Row = holder, Maid = maid, Type = "Divider" })
end

--------------------------------------------------------------------
-- LABEL
--------------------------------------------------------------------
function Elements.Label(tab, config)
	config = type(config) == "table" and config or { Name = config }

	local label = Util.New("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Text = tostring(config.Name or config.Text or ""),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = tab.Container,
	})
	Util.Padding(label, 2, 2, 6, 6)
	Theme:Apply(label, "TextColor3", config.Accent and "Accent" or "Text")

	local maid = Maid.new()
	maid:Give(label)

	local object = MakeObject(tab, config, { Row = label, Title = label, Maid = maid, Type = "Label" })
	function object:SetText(text) label.Text = tostring(text) end
	object.Set = function(self, text) self:SetText(text) end
	return object
end

--------------------------------------------------------------------
-- PARAGRAPH
--------------------------------------------------------------------
function Elements.Paragraph(tab, config)
	config = config or {}
	local row = Util.New("Frame", {
		Name = "Paragraph",
		BackgroundColor3 = Color3.fromRGB(17, 17, 30),
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = tab.Container,
	})
	Theme:Apply(row, "BackgroundColor3", "Secondary")
	Util.Corner(10, row)
	local stroke = Util.Stroke(nil, 1, 0.55, row)
	Theme:Apply(stroke, "Color", "Border")
	Util.Padding(row, 12, 14, 14, 14)

	local title = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(config.Title or config.Name or "Information"),
		Font = Enum.Font.GothamBold,
		TextSize = 13.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = row,
	})
	Theme:Apply(title, "TextColor3", "Text")

	local body = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(config.Content or config.Text or ""),
		Font = Enum.Font.Gotham,
		TextSize = 12.5,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 21),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = row,
	})
	Theme:Apply(body, "TextColor3", "SubText")

	local maid = Maid.new()
	maid:Give(row)

	local object = MakeObject(tab, config, {
		Row = row, Title = title, Description = body, Maid = maid, Type = "Paragraph",
	})
	object.Set = function(self, newTitle, newContent)
		if newTitle then title.Text = tostring(newTitle) end
		if newContent then body.Text = tostring(newContent) end
	end
	object.SetContent = function(self, text) body.Text = tostring(text) end
	return object
end

--------------------------------------------------------------------
-- BUTTON
--------------------------------------------------------------------
function Elements.Button(tab, config)
	config = config or {}
	local maid = Maid.new()
	local row, title, description, stroke = BuildRow(tab, config)
	maid:Give(row)

	local glyph, isImage = Icons.Resolve(config.Icon)
	if glyph then
		local offset = 34
		title.Position = UDim2.fromOffset(offset + 10, title.Position.Y.Offset)
		if description then
			description.Position = UDim2.fromOffset(offset + 10, description.Position.Y.Offset)
		end
		if isImage then
			local image = Util.New("ImageLabel", {
				BackgroundTransparency = 1,
				Image = glyph,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 14, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				Parent = row,
			})
			Theme:Apply(image, "ImageColor3", "Accent")
		else
			local iconLabel = Util.New("TextLabel", {
				BackgroundTransparency = 1,
				Text = glyph,
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 14, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			Theme:Apply(iconLabel, "TextColor3", "Accent")
		end
	end

	local chevron = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = "›",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(12, 20),
		Parent = row,
	})
	Theme:Apply(chevron, "TextColor3", "SubText")

	local button = Util.New("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = row,
	})

	HoverGlow(row, stroke, maid)
	maid:Give(row.MouseEnter:Connect(function()
		Animation.Tween(chevron, { Position = UDim2.new(1, -10, 0.5, 0) }, "Fast")
		chevron.TextColor3 = Theme:Get("Accent")
	end))
	maid:Give(row.MouseLeave:Connect(function()
		Animation.Tween(chevron, { Position = UDim2.new(1, -14, 0.5, 0) }, "Fast")
		chevron.TextColor3 = Theme:Get("SubText")
	end))

	local enabled = config.Enabled ~= false

	-- Ripple originating at the pointer. AbsolutePosition is real screen
	-- pixels while the ripple's offset lives in the window's scaled space,
	-- so the delta is divided by the active UIScale. GetMouseLocation
	-- excludes the topbar inset, which IgnoreGuiInset guis do not.
	local function ripple()
		if not Animation.Enabled then return end
		local scale = (tab.Window and tab.Window.Scale and tab.Window.Scale.Scale) or 1
		local inset = GuiService:GetGuiInset()
		local location = UserInputService:GetMouseLocation()
		local size = row.AbsoluteSize / scale

		-- a touch release can land outside the row; clamp so the ripple
		-- always originates somewhere on the card
		local localX = Util.Clamp((location.X + inset.X - row.AbsolutePosition.X) / scale, 0, size.X)
		local localY = Util.Clamp((location.Y + inset.Y - row.AbsolutePosition.Y) / scale, 0, size.Y)

		local circle = Util.New("Frame", {
			BackgroundColor3 = Theme:Get("Accent"),
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(localX, localY),
			Size = UDim2.fromOffset(0, 0),
			ZIndex = 2,
			Parent = row,
		})
		Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = circle })
		local span = size.X * 2
		Animation.Tween(circle, {
			Size = UDim2.fromOffset(span, span),
			BackgroundTransparency = 1,
		}, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out))
		task.delay(0.5, function() circle:Destroy() end)
	end

	maid:Give(button.MouseButton1Down:Connect(function()
		if not enabled then return end
		Animation.Tween(row, { Size = UDim2.new(1, -6, 0, row.Size.Y.Offset) }, "Fast")
	end))
	maid:Give(button.MouseButton1Up:Connect(function()
		Animation.Tween(row, { Size = UDim2.new(1, 0, 0, row.Size.Y.Offset) }, "Fast")
	end))
	maid:Give(button.MouseLeave:Connect(function()
		Animation.Tween(row, { Size = UDim2.new(1, 0, 0, row.Size.Y.Offset) }, "Fast")
	end))

	maid:Give(button.MouseButton1Click:Connect(function()
		if not enabled then return end
		ripple()
		Util.SafeCall(config.Callback)
	end))

	local object = MakeObject(tab, config, {
		Row = row, Title = title, Description = description, Maid = maid, Type = "Button",
		OnEnabled = function(state)
			enabled = state
			Animation.Tween(chevron, { TextTransparency = state and 0 or 0.7 }, "Fast")
		end,
	})

	function object:Fire()
		if self.Enabled then Util.SafeCall(config.Callback) end
	end

	return object
end

--------------------------------------------------------------------
-- TOGGLE
--------------------------------------------------------------------
function Elements.Toggle(tab, config)
	config = config or {}
	local maid = Maid.new()
	local object -- referenced by the click handler before assignment
	local row, title, description, stroke = BuildRow(tab, config)
	maid:Give(row)

	local value = config.CurrentValue == true or config.Default == true

	local track = Util.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(42, 22),
		BackgroundColor3 = Color3.fromRGB(31, 31, 54),
		Parent = row,
	})
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	Theme:Apply(track, "BackgroundColor3", "Elevated")
	local trackStroke = Util.Stroke(nil, 1, 0.5, track)
	Theme:Apply(trackStroke, "Color", "Border")

	local knob = Util.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(148, 148, 176),
		ZIndex = 2,
		Parent = track,
	})
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local glow = Util.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = track,
	})
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
	Theme:Apply(glow, "BackgroundColor3", "Accent")

	local button = Util.New("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = row,
	})

	HoverGlow(row, stroke, maid)

	local function paint(animated)
		local info = animated == false and "Fast" or "Spring"
		Animation.Tween(knob, {
			Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = value and Color3.fromRGB(255, 255, 255) or Theme:Get("SubText"),
		}, info)
		Animation.Tween(glow, { BackgroundTransparency = value and 0 or 1 }, "Fast")
	end
	paint(false)

	local function set(newValue, silent)
		newValue = newValue and true or false
		if newValue == value and silent then return end
		value = newValue
		paint(true)
		if not silent then Util.SafeCall(config.Callback, value) end
	end

	maid:Give(button.MouseButton1Click:Connect(function()
		if not object or object.Enabled then set(not value) end
	end))

	object = MakeObject(tab, config, {
		Row = row, Title = title, Description = description, Maid = maid, Type = "Toggle",
	})
	object.CurrentValue = value

	RegisterElement(tab, object, config,
		function() return value end,
		function(v, silent)
			set(v, silent)
			object.CurrentValue = value
		end)

	if value and config.FireOnCreate then
		Util.SafeCall(config.Callback, value)
	end
	return object
end

--------------------------------------------------------------------
-- SLIDER
--------------------------------------------------------------------
function Elements.Slider(tab, config)
	config = config or {}
	local maid = Maid.new()
	-- Range sanitising: a reversed, incomplete or non-numeric range is
	-- repaired rather than thrown, so one bad config cannot kill the tab.
	local range = type(config.Range) == "table" and config.Range or { 0, 100 }
	local minValue = tonumber(range[1]) or 0
	local maxValue = tonumber(range[2]) or (minValue + 100)
	if maxValue < minValue then
		warn("[Astryn] slider '" .. tostring(config.Name) .. "' has a reversed range — swapping bounds")
		minValue, maxValue = maxValue, minValue
	end
	if maxValue == minValue then maxValue = minValue + 1 end

	local increment = tonumber(config.Increment) or 1
	if increment <= 0 then increment = 1 end
	if increment > (maxValue - minValue) then increment = maxValue - minValue end

	local suffix = tostring(config.Suffix or "")
	local value = Util.Clamp(tonumber(config.CurrentValue) or tonumber(config.Default) or minValue, minValue, maxValue)

	local hasDescription = config.Description ~= nil
	local height = hasDescription and 66 or 52
	local row, title, description, stroke = BuildRow(tab, config, height)
	maid:Give(row)
	title.Size = UDim2.new(1, -90, 0, 17)
	title.Position = UDim2.fromOffset(14, 8)
	if description then description.Position = UDim2.fromOffset(14, 25) end

	local readout = Util.New("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(31, 31, 54),
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 7),
		Size = UDim2.fromOffset(64, 19),
		Text = tostring(value) .. suffix,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Parent = row,
	})
	Util.Corner(6, readout)
	Theme:Apply(readout, "BackgroundColor3", "Elevated")
	Theme:Apply(readout, "TextColor3", "Accent")

	local barY = hasDescription and 48 or 34
	local bar = Util.New("Frame", {
		Position = UDim2.new(0, 14, 0, barY),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = Color3.fromRGB(31, 31, 54),
		Parent = row,
	})
	Util.Corner(6, bar)
	Theme:Apply(bar, "BackgroundColor3", "Elevated")

	local fill = Util.New("Frame", {
		Size = UDim2.fromScale((value - minValue) / math.max(maxValue - minValue, 1e-6), 1),
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BorderSizePixel = 0,
		Parent = bar,
	})
	Util.Corner(6, fill)
	Theme:Apply(fill, "BackgroundColor3", "Accent")
	Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 190, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		Parent = fill,
	})

	local knob = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 3,
		Parent = bar,
	})
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
	local knobStroke = Util.Stroke(nil, 2, 0, knob)
	Theme:Apply(knobStroke, "Color", "Accent")

	HoverGlow(row, stroke, maid)

	local function apply(newValue, silent, animated)
		newValue = Util.Clamp(Util.Round(newValue, increment), minValue, maxValue)
		-- guard against float dust from rounding
		newValue = tonumber(string.format("%.4f", newValue))
		local changed = newValue ~= value
		value = newValue
		local alpha = (value - minValue) / math.max(maxValue - minValue, 1e-6)
		if animated == false then
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		else
			Animation.Tween(fill, { Size = UDim2.fromScale(alpha, 1) }, "Fast")
			Animation.Tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, "Fast")
		end
		readout.Text = tostring(value) .. suffix
		if changed and not silent then Util.SafeCall(config.Callback, value) end
	end

	-- Pointer handling is delegated to the shared DragManager: the
	-- element itself owns a single InputBegan connection.
	local object
	local hit = Util.New("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.new(0, 0, 0, -12),
		Size = UDim2.new(1, 0, 1, 24), -- generous touch target
		ZIndex = 4,
		Parent = bar,
	})

	local function updateFromInput(input)
		if object and not object.Enabled then return end
		local alpha = Util.Clamp(
			(input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		apply(minValue + (maxValue - minValue) * alpha, false, false)
	end

	maid:Give(DragManager:Bind(hit, updateFromInput,
		function() Animation.Tween(knob, { Size = UDim2.fromOffset(14, 14) }, "Fast") end,
		function() Animation.Tween(knob, { Size = UDim2.fromOffset(18, 18) }, "Fast") end))

	apply(value, true, false)

	object = MakeObject(tab, config, {
		Row = row, Title = title, Description = description, Maid = maid, Type = "Slider",
	})
	object.CurrentValue = value

	-- Runtime range changes keep the current value inside the new bounds.
	function object:SetRange(newMin, newMax)
		newMin, newMax = tonumber(newMin), tonumber(newMax)
		if not newMin or not newMax or newMax <= newMin then
			warn("[Astryn] SetRange ignored: invalid bounds")
			return
		end
		minValue, maxValue = newMin, newMax
		apply(Util.Clamp(value, minValue, maxValue), true)
		self.CurrentValue = value
	end

	RegisterElement(tab, object, config,
		function() return value end,
		function(v, silent)
			apply(tonumber(v) or minValue, silent)
			object.CurrentValue = value
		end)
	return object
end

--------------------------------------------------------------------
-- DROPDOWN  (shared implementation for single + multi select)
--------------------------------------------------------------------
local function BuildDropdown(tab, config, multi)
	config = config or {}
	local maid = Maid.new()
	-- Options are normalised to a clean array of strings. Nil holes,
	-- duplicates and non-array tables are dropped with a warning rather
	-- than producing an unusable control.
	local function sanitise(list)
		local clean, seen = {}, {}
		if type(list) ~= "table" then
			if list ~= nil then warn("[Astryn] dropdown Options must be a table") end
			return clean
		end
		for _, option in ipairs(list) do
			local name = tostring(option)
			if not seen[name] then
				seen[name] = true
				table.insert(clean, name)
			end
		end
		return clean
	end

	local options = sanitise(config.Options)
	local searchable = config.Search
	if searchable == nil then searchable = #options > 8 end

	-- Selections that are not in Options are discarded, so a stale saved
	-- config can never select something that no longer exists.
	local selected = {}
	local function isKnown(name)
		return table.find(options, name) ~= nil
	end

	do
		local initial = config.CurrentOption or config.Default
		if multi then
			if type(initial) == "table" then
				for _, option in ipairs(initial) do
					local name = tostring(option)
					if isKnown(name) then selected[name] = true end
				end
			end
		elseif initial ~= nil then
			local name = tostring(initial)
			if isKnown(name) then
				selected[name] = true
			else
				warn("[Astryn] dropdown '" .. tostring(config.Name)
					.. "' default '" .. name .. "' is not in Options")
			end
		end
	end

	local object -- referenced by handlers created before assignment
	local row, title, description, stroke, baseHeight = BuildRow(tab, config)
	maid:Give(row)
	row.ClipsDescendants = true

	local function selectionText()
		local list = {}
		for _, option in ipairs(options) do
			if selected[tostring(option)] then table.insert(list, tostring(option)) end
		end
		if #list == 0 then return config.EmptyText or "None" end
		if multi and #list > 2 then return ("%d selected"):format(#list) end
		return table.concat(list, ", ")
	end

	local display = Util.New("TextButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, math.floor((baseHeight - 26) / 2)),
		Size = UDim2.fromOffset(150, 26),
		BackgroundColor3 = Color3.fromRGB(31, 31, 54),
		Text = "",
		ZIndex = 3,
		Parent = row,
	})
	Util.Corner(8, display)
	Theme:Apply(display, "BackgroundColor3", "Elevated")

	local displayLabel = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = selectionText(),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -30, 1, 0),
		ZIndex = 4,
		Parent = display,
	})
	Theme:Apply(displayLabel, "TextColor3", "Text")

	local arrow = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = "⌄",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, -2),
		Size = UDim2.fromOffset(14, 14),
		ZIndex = 4,
		Parent = display,
	})
	Theme:Apply(arrow, "TextColor3", "SubText")

	-- expandable panel
	local panel = Util.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, baseHeight),
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Parent = row,
	})

	local searchBox
	local listTop = 4
	if searchable then
		local field = Util.New("Frame", {
			Position = UDim2.fromOffset(14, 2),
			Size = UDim2.new(1, -28, 0, 26),
			BackgroundColor3 = Color3.fromRGB(24, 24, 42),
			Parent = panel,
		})
		Util.Corner(7, field)
		Theme:Apply(field, "BackgroundColor3", "Tertiary")
		searchBox = Util.New("TextBox", {
			BackgroundTransparency = 1,
			PlaceholderText = "Search...",
			Text = "",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -18, 1, 0),
			Parent = field,
		})
		Theme:Apply(searchBox, "TextColor3", "Text")
		Theme:Apply(searchBox, "PlaceholderColor3", "SubText")
		listTop = 32
	end

	local list = Util.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, listTop),
		Size = UDim2.new(1, -28, 1, -(listTop + 8)),
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Parent = panel,
	})
	Theme:Apply(list, "ScrollBarImageColor3", "Accent")
	Util.List(list, 4, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)

	local optionButtons = {}
	local expanded = false
	local ROW_H = 28

	local function panelHeight()
		local visible = 0
		for _, entry in pairs(optionButtons) do
			if entry.Button.Visible then visible += 1 end
		end
		local listHeight = math.min(visible, 5) * (ROW_H + 4)
		return listTop + math.max(listHeight, ROW_H) + 8
	end

	local function resize(animated)
		local target = baseHeight + (expanded and panelHeight() or 0)
		local info = animated == false and "Fast" or "Smooth"
		Animation.Tween(row, { Size = UDim2.new(1, 0, 0, target) }, info)
		Animation.Tween(panel, { Size = UDim2.new(1, 0, 0, expanded and panelHeight() or 0) }, info)
		Animation.Tween(arrow, { Rotation = expanded and 180 or 0 }, "Smooth")
	end

	local function paintOptions()
		for name, entry in pairs(optionButtons) do
			local isSelected = selected[name] == true
			Animation.Tween(entry.Button, {
				BackgroundTransparency = isSelected and 0 or 0.35,
				BackgroundColor3 = isSelected and Theme:Get("Accent") or Theme:Get("Tertiary"),
			}, "Fast")
			entry.Label.TextColor3 = isSelected and Color3.fromRGB(18, 14, 32) or Theme:Get("SubText")
			if entry.Check then
				entry.Check.TextTransparency = isSelected and 0 or 1
			end
		end
		displayLabel.Text = selectionText()
	end

	local function fireCallback()
		local payload
		if multi then
			payload = {}
			for _, option in ipairs(options) do
				if selected[tostring(option)] then table.insert(payload, option) end
			end
		else
			for _, option in ipairs(options) do
				if selected[tostring(option)] then payload = option; break end
			end
		end
		Util.SafeCall(config.Callback, payload)
	end

	local buildOptions

	local function choose(name)
		if multi then
			selected[name] = not selected[name] or nil
		else
			table.clear(selected)
			selected[name] = true
			expanded = false
			resize()
		end
		paintOptions()
		fireCallback()
	end

	buildOptions = function()
		for _, entry in pairs(optionButtons) do entry.Button:Destroy() end
		table.clear(optionButtons)

		for index, option in ipairs(options) do
			local name = tostring(option)
			local button = Util.New("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(24, 24, 42),
				BackgroundTransparency = 0.35,
				Size = UDim2.new(1, 0, 0, ROW_H),
				Text = "",
				LayoutOrder = index,
				Parent = list,
			})
			Util.Corner(7, button)

			local label = Util.New("TextLabel", {
				BackgroundTransparency = 1,
				Text = name,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -34, 1, 0),
				Parent = button,
			})

			local check
			if multi then
				check = Util.New("TextLabel", {
					BackgroundTransparency = 1,
					Text = "✓",
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(14, 14),
					TextColor3 = Color3.fromRGB(18, 14, 32),
					Parent = button,
				})
			end

			button.MouseEnter:Connect(function()
				if not selected[name] then
					Animation.Tween(button, { BackgroundTransparency = 0.05 }, "Fast")
				end
			end)
			button.MouseLeave:Connect(function()
				if not selected[name] then
					Animation.Tween(button, { BackgroundTransparency = 0.35 }, "Fast")
				end
			end)
			button.MouseButton1Click:Connect(function() choose(name) end)

			optionButtons[name] = { Button = button, Label = label, Check = check }
		end
		paintOptions()
	end

	buildOptions()

	if searchBox then
		maid:Give(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			local query = searchBox.Text:lower()
			for name, entry in pairs(optionButtons) do
				entry.Button.Visible = (query == "" or name:lower():find(query, 1, true) ~= nil)
			end
			if expanded then resize() end
		end))
	end

	maid:Give(display.MouseButton1Click:Connect(function()
		if object and not object.Enabled then return end
		expanded = not expanded
		resize()
	end))

	HoverGlow(row, stroke, maid)

	-- collapse when another dropdown in the same tab opens
	maid:Give(tab.Window.Signals.CollapseDropdowns.Event:Connect(function(source)
		if source ~= row and expanded then
			expanded = false
			resize()
		end
	end))
	maid:Give(display.MouseButton1Down:Connect(function()
		tab.Window.Signals.CollapseDropdowns:Fire(row)
	end))

	object = MakeObject(tab, config, {
		Row = row, Title = title, Description = description, Maid = maid,
		Type = multi and "MultiDropdown" or "Dropdown",
	})

	local function currentValue()
		if multi then
			local payload = {}
			for _, option in ipairs(options) do
				if selected[tostring(option)] then table.insert(payload, option) end
			end
			return payload
		end
		for _, option in ipairs(options) do
			if selected[tostring(option)] then return option end
		end
		return nil
	end

	object.CurrentOption = currentValue()

	local function applySelection(value, silent)
		table.clear(selected)
		if multi then
			if type(value) == "table" then
				for _, option in pairs(value) do
					local name = tostring(option)
					if isKnown(name) then selected[name] = true end
				end
			end
		elseif value ~= nil then
			local name = tostring(value)
			if isKnown(name) then selected[name] = true end
		end
		paintOptions()
		object.CurrentOption = currentValue()
		if not silent then fireCallback() end
	end

	-- Replaces the option list at runtime. Selections that survive in the
	-- new list are kept when `keepSelection` is true.
	function object:Refresh(newOptions, keepSelection)
		options = sanitise(newOptions)
		if keepSelection then
			for name in pairs(selected) do
				if not isKnown(name) then selected[name] = nil end
			end
		else
			table.clear(selected)
		end
		buildOptions()
		if expanded then resize() end
		self.CurrentOption = currentValue()
	end

	function object:GetOptions()
		return table.clone(options)
	end

	RegisterElement(tab, object, config,
		function() return currentValue() end,
		function(v, silent) applySelection(v, silent) end)
	return object
end

function Elements.Dropdown(tab, config)
	return BuildDropdown(tab, config, false)
end

function Elements.MultiDropdown(tab, config)
	return BuildDropdown(tab, config, true)
end

--------------------------------------------------------------------
-- INPUT
--------------------------------------------------------------------
function Elements.Input(tab, config)
	config = config or {}
	local maid = Maid.new()
	local row, title, description, stroke, baseHeight = BuildRow(tab, config)
	maid:Give(row)

	local field = Util.New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, math.floor((baseHeight - 26) / 2)),
		Size = UDim2.fromOffset(150, 26),
		BackgroundColor3 = Color3.fromRGB(31, 31, 54),
		Parent = row,
	})
	Util.Corner(8, field)
	Theme:Apply(field, "BackgroundColor3", "Elevated")
	local fieldStroke = Util.Stroke(nil, 1, 1, field)
	Theme:Apply(fieldStroke, "Color", "Accent")

	local box = Util.New("TextBox", {
		BackgroundTransparency = 1,
		Text = tostring(config.CurrentValue or config.Default or ""),
		PlaceholderText = tostring(config.PlaceholderText or config.Placeholder or "Enter text..."),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		ClearTextOnFocus = config.ClearOnFocus == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -18, 1, 0),
		ZIndex = 3,
		Parent = field,
	})
	Theme:Apply(box, "TextColor3", "Text")
	Theme:Apply(box, "PlaceholderColor3", "SubText")

	HoverGlow(row, stroke, maid)

	maid:Give(box.Focused:Connect(function()
		Animation.Tween(fieldStroke, { Transparency = 0 }, "Fast")
	end))

	maid:Give(box.FocusLost:Connect(function(enter)
		Animation.Tween(fieldStroke, { Transparency = 1 }, "Fast")
		if config.Numeric then
			box.Text = tostring(tonumber(box.Text) or "")
		end
		if enter or config.CallbackOnUnfocus ~= false then
			Util.SafeCall(config.Callback, box.Text, enter)
		end
		if config.ClearOnSubmit and enter then box.Text = "" end
	end))

	local object = MakeObject(tab, config, {
		Row = row, Title = title, Description = description, Maid = maid, Type = "Input",
		OnEnabled = function(state) box.TextEditable = state end,
	})
	object.CurrentValue = box.Text

	local function setText(text, silent)
		box.Text = tostring(text or "")
		object.CurrentValue = box.Text
		if not silent then Util.SafeCall(config.Callback, box.Text, false) end
	end

	RegisterElement(tab, object, config,
		function() return box.Text end,
		setText)
	return object
end

--------------------------------------------------------------------
-- KEYBIND
--------------------------------------------------------------------
function Elements.Keybind(tab, config)
	config = config or {}
	local maid = Maid.new()
	local object -- referenced by handlers created before assignment
	local row, title, description, stroke, baseHeight = BuildRow(tab, config)
	maid:Give(row)

	-- Accepts an EnumItem or a key name string; anything else becomes Unknown.
	local function toKeyCode(input)
		if typeof(input) == "EnumItem" and input.EnumType == Enum.KeyCode then return input end
		if type(input) == "string" then
			local ok, item = pcall(function() return Enum.KeyCode[input] end)
			if ok and item then return item end
			warn("[Astryn] unknown key name '" .. input .. "'")
		end
		return Enum.KeyCode.Unknown
	end

	local current = toKeyCode(config.CurrentKeybind or config.Default)

	local button = Util.New("TextButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, math.floor((baseHeight - 26) / 2)),
		Size = UDim2.fromOffset(110, 26),
		BackgroundColor3 = Color3.fromRGB(31, 31, 54),
		Text = current.Name,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		ZIndex = 3,
		Parent = row,
	})
	Util.Corner(8, button)
	Theme:Apply(button, "BackgroundColor3", "Elevated")
	Theme:Apply(button, "TextColor3", "Text")

	HoverGlow(row, stroke, maid)

	local listening = false
	local function setKey(key, silent)
		current = key
		button.Text = (key == Enum.KeyCode.Unknown) and "None" or key.Name
		if not silent then Util.SafeCall(config.Callback, key) end
	end

	maid:Give(button.MouseButton1Click:Connect(function()
		if listening or (object and not object.Enabled) then return end
		listening = true
		button.Text = "Press a key..."
		button.TextColor3 = Theme:Get("Accent")

		local connection
		connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				connection:Disconnect()
				listening = false
				button.TextColor3 = Theme:Get("Text")
				if input.KeyCode == Enum.KeyCode.Escape then
					button.Text = current.Name
					return
				end
				setKey(input.KeyCode)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				connection:Disconnect()
				listening = false
				button.TextColor3 = Theme:Get("Text")
				setKey(Enum.KeyCode.Unknown)
			end
		end)
		maid:Give(connection)
	end))

	-- fire the hook whenever the bound key is pressed
	if config.OnPress then
		maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
			if processed or listening then return end
			if object and not object.Enabled then return end
			if input.KeyCode == current and current ~= Enum.KeyCode.Unknown then
				Util.SafeCall(config.OnPress, current)
			end
		end))
	end

	object = MakeObject(tab, config, {
		Row = row, Title = title, Description = description, Maid = maid, Type = "Keybind",
	})
	object.CurrentKeybind = current

	local function assign(key, silent)
		setKey(toKeyCode(key), silent)
		object.CurrentKeybind = current
	end

	RegisterElement(tab, object, config,
		function() return current end,
		assign)
	return object
end

--------------------------------------------------------------------
-- COLOR PICKER
--------------------------------------------------------------------
function Elements.ColorPicker(tab, config)
	config = config or {}
	local maid = Maid.new()
	local row, title, description, stroke, baseHeight = BuildRow(tab, config)
	maid:Give(row)
	row.ClipsDescendants = true

	local color = config.Color or config.CurrentColor or Color3.fromRGB(140, 100, 255)
	local hue, saturation, brightness = Color3.toHSV(color)

	local preview = Util.New("TextButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, math.floor((baseHeight - 26) / 2)),
		Size = UDim2.fromOffset(52, 26),
		BackgroundColor3 = color,
		Text = "",
		ZIndex = 3,
		Parent = row,
	})
	Util.Corner(8, preview)
	Util.Stroke(Color3.fromRGB(255, 255, 255), 1, 0.75, preview)

	local PANEL_HEIGHT = 136
	local panel = Util.New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, baseHeight),
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Parent = row,
	})

	-- saturation / brightness square
	local square = Util.New("Frame", {
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -28, 0, 90),
		BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = panel,
	})
	Util.Corner(8, square)

	local whiteLayer = Util.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = square,
	})
	Util.New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = whiteLayer,
	})

	local blackLayer = Util.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = square,
	})
	Util.New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = blackLayer,
	})

	local cursor = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(saturation, 1 - brightness),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = square,
	})
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cursor })
	Util.Stroke(Color3.fromRGB(255, 255, 255), 2, 0, cursor)

	-- hue strip
	local hueBar = Util.New("Frame", {
		Position = UDim2.fromOffset(14, 100),
		Size = UDim2.new(1, -28, 0, 14),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Parent = panel,
	})
	Util.Corner(7, hueBar)
	Util.New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hueBar,
	})

	local hueCursor = Util.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(hue, 0.5),
		Size = UDim2.fromOffset(6, 20),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = hueBar,
	})
	Util.Corner(4, hueCursor)

	local hexLabel = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = "#FFFFFF",
		Font = Enum.Font.Code,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 118),
		Size = UDim2.new(1, -28, 0, 14),
		Parent = panel,
	})
	Theme:Apply(hexLabel, "TextColor3", "SubText")

	local function currentColor()
		return Color3.fromHSV(hue, saturation, brightness)
	end

	local function push(silent)
		local value = currentColor()
		preview.BackgroundColor3 = value
		square.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		hexLabel.Text = string.format("#%02X%02X%02X",
			math.floor(value.R * 255 + 0.5),
			math.floor(value.G * 255 + 0.5),
			math.floor(value.B * 255 + 0.5))
		if not silent then Util.SafeCall(config.Callback, value) end
	end
	push(true)

	local expanded = false
	local function resize()
		local target = baseHeight + (expanded and PANEL_HEIGHT or 0)
		Animation.Tween(row, { Size = UDim2.new(1, 0, 0, target) }, "Smooth")
		Animation.Tween(panel, { Size = UDim2.new(1, 0, 0, expanded and PANEL_HEIGHT or 0) }, "Smooth")
	end

	maid:Give(preview.MouseButton1Click:Connect(function()
		expanded = not expanded
		resize()
	end))

	-- Both drag surfaces run through the shared DragManager, so a picker
	-- costs one connection each instead of three.
	local function bindDrag(frame, handler)
		maid:Give(DragManager:Bind(frame, handler))
	end

	bindDrag(square, function(input)
		local x = Util.Clamp((input.Position.X - square.AbsolutePosition.X) / math.max(square.AbsoluteSize.X, 1), 0, 1)
		local y = Util.Clamp((input.Position.Y - square.AbsolutePosition.Y) / math.max(square.AbsoluteSize.Y, 1), 0, 1)
		saturation, brightness = x, 1 - y
		cursor.Position = UDim2.fromScale(x, y)
		push()
	end)

	bindDrag(hueBar, function(input)
		local x = Util.Clamp((input.Position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
		hue = x
		hueCursor.Position = UDim2.fromScale(x, 0.5)
		push()
	end)

	HoverGlow(row, stroke, maid)

	local object = MakeObject(tab, config, {
		Row = row, Title = title, Description = description, Maid = maid, Type = "ColorPicker",
	})
	object.CurrentColor = currentColor()

	local function assign(value, silent)
		if typeof(value) ~= "Color3" then
			warn("[Astryn] colour picker expects a Color3")
			return
		end
		hue, saturation, brightness = Color3.toHSV(value)
		cursor.Position = UDim2.fromScale(saturation, 1 - brightness)
		hueCursor.Position = UDim2.fromScale(hue, 0.5)
		push(silent)
		object.CurrentColor = currentColor()
	end

	RegisterElement(tab, object, config,
		function() return currentColor() end,
		assign)
	return object
end

-- Building blocks exposed to element authors. A custom component only
-- needs these three: BuildRow for the card shell, MakeObject for the
-- shared element API, RegisterElement to join the config system.
Elements.BuildRow        = BuildRow
Elements.MakeObject      = MakeObject
Elements.RegisterElement = RegisterElement
Elements.HoverGlow       = HoverGlow

Astryn.Elements = Elements

--==================================================================
-- TAB
--==================================================================

local Tab = {}
Tab.__index = Tab

function Tab.new(window, config)
	local self = setmetatable({}, Tab)
	config = config or {}
	self.Window = window
	self.Name = tostring(config.Name or "Tab")
	self.Elements = {}
	self.Maid = Maid.new()

	------------------------------------------------- sidebar button
	local button = Util.New("TextButton", {
		Name = self.Name,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(24, 24, 42),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Env.IsMobile and 40 or 36),
		Text = "",
		LayoutOrder = #window.Tabs + 1,
		Parent = window.TabList,
	})
	Util.Corner(9, button)
	self.Button = button
	self.Maid:Give(button)

	-- active indicator rail
	local rail = Util.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = button,
	})
	Util.Corner(3, rail)
	Theme:Apply(rail, "BackgroundColor3", "Accent")
	self.Rail = rail

	local glyph, isImage = Icons.Resolve(config.Icon or "star")
	local iconSlot
	if isImage then
		iconSlot = Util.New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = glyph,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 3,
			Parent = button,
		})
		Theme:Apply(iconSlot, "ImageColor3", "SubText")
	else
		iconSlot = Util.New("TextLabel", {
			BackgroundTransparency = 1,
			Text = glyph,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 13, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			ZIndex = 3,
			Parent = button,
		})
		Theme:Apply(iconSlot, "TextColor3", "SubText")
	end
	self.Icon = iconSlot

	local label = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = self.Name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -52, 1, 0),
		ZIndex = 3,
		Parent = button,
	})
	Theme:Apply(label, "TextColor3", "SubText")
	self.Label = label

	-- notification badge
	local badge = Util.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(255, 104, 128),
		Visible = false,
		ZIndex = 4,
		Parent = button,
	})
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	Theme:Apply(badge, "BackgroundColor3", "Error")
	local badgeLabel = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = "1",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = badge,
	})
	self.Badge, self.BadgeLabel = badge, badgeLabel

	------------------------------------------------- content page
	local page = Util.New("ScrollingFrame", {
		Name = self.Name .. "_Page",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = Env.IsMobile and 5 or 4,
		ScrollBarImageTransparency = 0.45,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Parent = window.Content,
	})
	Theme:Apply(page, "ScrollBarImageColor3", "Accent")
	Util.Padding(page, 4, 16, 2, 10)
	Util.List(page, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Center)
	self.Container = page
	self.Maid:Give(page)

	------------------------------------------------- interactions
	self.Maid:Give(button.MouseEnter:Connect(function()
		if window.ActiveTab ~= self then
			Animation.Tween(button, { BackgroundTransparency = 0.35 }, "Fast")
			Animation.Tween(label, { TextColor3 = Theme:Get("Text") }, "Fast")
		end
	end))
	self.Maid:Give(button.MouseLeave:Connect(function()
		if window.ActiveTab ~= self then
			Animation.Tween(button, { BackgroundTransparency = 1 }, "Fast")
			Animation.Tween(label, { TextColor3 = Theme:Get("SubText") }, "Fast")
		end
	end))
	self.Maid:Give(button.MouseButton1Click:Connect(function()
		window:SelectTab(self)
	end))

	table.insert(window.Tabs, self)

	-- adopt the sidebar's current layout if it is already collapsed
	if window.Compact then
		label.Visible = false
		iconSlot.Position = UDim2.new(0.5, -9, 0.5, 0)
		badge.Position = UDim2.new(1, -4, 0, 6)
	end

	return self
end

function Tab:SetActive(active)
	local accent = Theme:Get("Accent")
	if active then
		Animation.Tween(self.Button, {
			BackgroundTransparency = 0.1,
			BackgroundColor3 = Theme:Get("Tertiary"),
		}, "Smooth")
		Animation.Tween(self.Rail, { Size = UDim2.new(0, 3, 0, 18) }, "Spring")
		Animation.Tween(self.Label, { TextColor3 = Theme:Get("Text") }, "Fast")
		if self.Icon:IsA("TextLabel") then
			Animation.Tween(self.Icon, { TextColor3 = accent }, "Fast")
		else
			Animation.Tween(self.Icon, { ImageColor3 = accent }, "Fast")
		end
		self:ClearBadge()
	else
		Animation.Tween(self.Button, { BackgroundTransparency = 1 }, "Smooth")
		Animation.Tween(self.Rail, { Size = UDim2.fromOffset(3, 0) }, "Fast")
		Animation.Tween(self.Label, { TextColor3 = Theme:Get("SubText") }, "Fast")
		if self.Icon:IsA("TextLabel") then
			Animation.Tween(self.Icon, { TextColor3 = Theme:Get("SubText") }, "Fast")
		else
			Animation.Tween(self.Icon, { ImageColor3 = Theme:Get("SubText") }, "Fast")
		end
	end
end

function Tab:SetBadge(count)
	if not count or count <= 0 then
		self:ClearBadge()
		return
	end
	self.Badge.Visible = true
	self.BadgeLabel.Text = count > 9 and "9+" or tostring(count)
	self.Badge.Size = UDim2.fromOffset(0, 0)
	Animation.Tween(self.Badge, { Size = UDim2.fromOffset(16, 16) }, "Spring")
end

function Tab:ClearBadge()
	self.Badge.Visible = false
end

function Tab:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true

	local index = table.find(self.Window.Tabs, self)
	if index then table.remove(self.Window.Tabs, index) end

	-- elements remove themselves from self.Elements as they are destroyed,
	-- so iterate over a snapshot rather than the live list
	for _, element in ipairs(table.clone(self.Elements)) do
		if element.Destroy then pcall(function() element:Destroy() end) end
	end
	table.clear(self.Elements)

	if self.Window.ActiveTab == self then
		self.Window.ActiveTab = nil
		local fallback = self.Window.Tabs[1]
		if fallback then self.Window:SelectTab(fallback) end
	end

	self.Maid:Clean()
end

-- Element aliases. Adding a new element = one line here.
Tab.CreateSection       = function(self, config) return Elements.Section(self, config) end
Tab.CreateDivider       = function(self, config) return Elements.Divider(self, config) end
Tab.CreateLabel         = function(self, config) return Elements.Label(self, config) end
Tab.CreateParagraph     = function(self, config) return Elements.Paragraph(self, config) end
Tab.CreateButton        = function(self, config) return Elements.Button(self, config) end
Tab.CreateToggle        = function(self, config) return Elements.Toggle(self, config) end
Tab.CreateSlider        = function(self, config) return Elements.Slider(self, config) end
Tab.CreateDropdown      = function(self, config) return Elements.Dropdown(self, config) end
Tab.CreateMultiDropdown = function(self, config) return Elements.MultiDropdown(self, config) end
Tab.CreateInput         = function(self, config) return Elements.Input(self, config) end
Tab.CreateKeybind       = function(self, config) return Elements.Keybind(self, config) end
Tab.CreateColorPicker   = function(self, config) return Elements.ColorPicker(self, config) end

Astryn.Tab = Tab

--==================================================================
-- WINDOW
--==================================================================

local Window = {}
Window.__index = Window

function Window.new(config)
	local self = setmetatable({}, Window)
	config = config or {}
	self.Config = config
	self.Maid = Maid.new()
	self.Tabs = {}
	self.Flags = {}
	self.Minimized = false
	self.Visible = true
	self.Destroyed = false

	self.Signals = {
		CollapseDropdowns = Instance.new("BindableEvent"),
	}
	self.Maid:Give(self.Signals.CollapseDropdowns)

	local viewport = Util.Viewport()
	Env.IsTablet = Env.IsMobile and math.min(viewport.X, viewport.Y) >= 600

	local requested = config.Size or UDim2.fromOffset(650, 450)
	local width  = math.min(requested.X.Offset, viewport.X - 40)
	local height = math.min(requested.Y.Offset, viewport.Y - 60)
	self.BaseSize = UDim2.fromOffset(width, height)

	------------------------------------------------- screen gui
	local gui = Util.New("ScreenGui", {
		Name = "Astryn_" .. Util.NextId("Window"),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	if Env.Protect then pcall(Env.Protect, gui) end
	gui.Parent = Util.GuiParent()
	self.Gui = gui
	self.Maid:Give(gui)

	local scale = Util.New("UIScale", { Scale = 1, Parent = gui })
	self.Scale = scale
	self.UserScale = config.Scale or 1

	------------------------------------------------- root frame
	local root = Util.New("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = config.Position or UDim2.fromScale(0.5, 0.5),
		Size = self.BaseSize,
		BackgroundColor3 = Color3.fromRGB(11, 11, 20),
		BackgroundTransparency = config.Transparency or 0.06,
		ClipsDescendants = true,
		Parent = gui,
	})
	Theme:Apply(root, "BackgroundColor3", "Background")
	Util.Corner(Tokens.Radius.Window, root)
	local rootStroke = Util.Stroke(nil, 1, 0.35, root)
	Theme:Apply(rootStroke, "Color", "Border")
	self.Root, self.RootStroke = root, rootStroke

	-- soft drop shadow
	local shadow = Util.New("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(49, 49, 450, 450),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 60, 1, 60),
		ZIndex = 0,
		Parent = root,
	})
	shadow.Parent = gui
	shadow.Position = root.Position
	shadow.AnchorPoint = root.AnchorPoint
	self.Shadow = shadow
	self.Maid:Give(root:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = root.Position
	end))
	self.Maid:Give(root:GetPropertyChangedSignal("Size"):Connect(function()
		shadow.Size = UDim2.new(0, root.Size.X.Offset + 60, 0, root.Size.Y.Offset + 60)
	end))

	------------------------------------------------- astral background
	self.Background = Background.new(root, config.Performance and "Performance" or "High")
	self.Maid:Give(self.Background)
	self.Background:Start()

	------------------------------------------------- header
	local header = Util.New("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		ZIndex = 5,
		Parent = root,
	})
	self.Header = header

	local headerLine = Util.New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.fromRGB(46, 46, 74),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = header,
	})
	Theme:Apply(headerLine, "BackgroundColor3", "Border")

	-- accent bloom that fades across the header rule, so the divider reads
	-- as part of the astral identity rather than a plain 1px line
	local headerGlow = Util.New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.fromRGB(140, 100, 255),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = header,
	})
	Theme:Apply(headerGlow, "BackgroundColor3", "Accent")
	Util.New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.00, 1),
			NumberSequenceKeypoint.new(0.28, 0.35),
			NumberSequenceKeypoint.new(0.62, 0.6),
			NumberSequenceKeypoint.new(1.00, 1),
		}),
		Parent = headerGlow,
	})

	local emblem = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = "✦",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		ZIndex = 6,
		Parent = header,
	})
	Theme:Apply(emblem, "TextColor3", "Accent")
	self.Emblem = emblem

	local title = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = string.upper(tostring(config.Name or "ASTRYN HUB")),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(46, 11),
		Size = UDim2.new(1, -160, 0, 17),
		ZIndex = 6,
		Parent = header,
	})
	Theme:Apply(title, "TextColor3", "Text")
	self.Title = title

	local subtitle = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = tostring(config.Subtitle or "Astral Interface"),
		Font = Enum.Font.Gotham,
		TextSize = 11.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(46, 28),
		Size = UDim2.new(1, -160, 0, 14),
		ZIndex = 6,
		Parent = header,
	})
	Theme:Apply(subtitle, "TextColor3", "SubText")
	self.Subtitle = subtitle

	-- header control buttons
	local function headerButton(glyph, offset, hoverKey, callback)
		local button = Util.New("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(31, 31, 54),
			BackgroundTransparency = 0.4,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			Text = glyph,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			ZIndex = 7,
			Parent = header,
		})
		Util.Corner(8, button)
		Theme:Apply(button, "BackgroundColor3", "Elevated")
		Theme:Apply(button, "TextColor3", "SubText")
		button.MouseEnter:Connect(function()
			Animation.Tween(button, {
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme:Get(hoverKey),
			}, "Fast")
			Animation.Tween(button, { TextColor3 = Color3.fromRGB(16, 14, 26) }, "Fast")
		end)
		button.MouseLeave:Connect(function()
			Animation.Tween(button, {
				BackgroundTransparency = 0.4,
				BackgroundColor3 = Theme:Get("Elevated"),
				TextColor3 = Theme:Get("SubText"),
			}, "Fast")
		end)
		button.MouseButton1Click:Connect(callback)
		self.Maid:Give(button)
		return button
	end

	self.CloseButton = headerButton("✕", -14, "Error", function() self:Close() end)
	self.MinimizeButton = headerButton("–", -46, "Accent", function() self:ToggleMinimize() end)

	------------------------------------------------- body: sidebar + content
	local body = Util.New("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		ZIndex = 4,
		Parent = root,
	})
	self.Body = body

	local sidebarWidth = Env.IsMobile and (Env.IsTablet and 150 or 128) or 148
	self.SidebarWidth = sidebarWidth
	self.Compact = false
	local sidebar = Util.New("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = Color3.fromRGB(17, 17, 30),
		BackgroundTransparency = 0.35,
		Size = UDim2.new(0, sidebarWidth, 1, 0),
		ZIndex = 4,
		Parent = body,
	})
	Theme:Apply(sidebar, "BackgroundColor3", "Secondary")
	Util.New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 0.45),
		}),
		Parent = sidebar,
	})
	self.Sidebar = sidebar

	local sidebarLine = Util.New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Color3.fromRGB(46, 46, 74),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = sidebar,
	})
	Theme:Apply(sidebarLine, "BackgroundColor3", "Border")

	local tabList = Util.New("ScrollingFrame", {
		Name = "TabList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 1, -42),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.6,
		ZIndex = 5,
		Parent = sidebar,
	})
	Theme:Apply(tabList, "ScrollBarImageColor3", "Accent")
	Util.Padding(tabList, 0, 8, 10, 10)
	Util.List(tabList, 4)
	self.TabList = tabList

	local footer = Util.New("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -10),
		Size = UDim2.new(1, -20, 0, 14),
		Text = "Astryn v" .. Astryn.Version,
		Font = Enum.Font.Gotham,
		TextSize = 10.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = sidebar,
	})
	Theme:Apply(footer, "TextColor3", "SubText")
	self.SidebarFooter = footer

	local content = Util.New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(sidebarWidth + 10, 0),
		Size = UDim2.new(1, -(sidebarWidth + 22), 1, 0),
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = body,
	})
	self.Content = content

	------------------------------------------------- dragging
	self:_BindDragging()
	self:_BindToggleKey(config.ToggleKey or Enum.KeyCode.RightControl)
	self:_BindScaling()

	if Env.IsMobile then self:_CreateMobileToggle() end

	------------------------------------------------- open animation
	root.Size = UDim2.fromOffset(self.BaseSize.X.Offset * 0.85, self.BaseSize.Y.Offset * 0.85)
	root.BackgroundTransparency = 1
	shadow.ImageTransparency = 1
	Animation.Tween(root, {
		Size = self.BaseSize,
		BackgroundTransparency = config.Transparency or 0.06,
	}, "Spring")
	Animation.Tween(shadow, { ImageTransparency = 0.45 }, "Smooth")

	return self
end

--------------------------------------------------- dragging (mouse + touch)
function Window:_BindDragging()
	local root = self.Root
	local dragStart, startPosition

	self.Maid:Give(DragManager:Bind(self.Header,
		function(input)
			if not dragStart then return end
			-- UIScale divides the offsets, so the delta must be scaled to
			-- keep the window locked to the pointer at any UI scale
			local scale = self.Scale.Scale
			local delta = (input.Position - dragStart) / scale
			root.Position = UDim2.new(
				startPosition.X.Scale, startPosition.X.Offset + delta.X,
				startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end,
		function()
			dragStart = nil
			if self.RefreshScale then self.RefreshScale() end -- snap back on-screen
		end,
		function(input)
			dragStart = input.Position
			startPosition = root.Position
		end))
end

--------------------------------------------------- keyboard toggle
function Window:_BindToggleKey(key)
	self.ToggleKey = key
	self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or self.Destroyed then return end
		if input.KeyCode == self.ToggleKey and self.ToggleKey ~= Enum.KeyCode.Unknown then
			self:Toggle()
		end
	end))
end

function Window:SetToggleKey(key)
	if typeof(key) == "EnumItem" then self.ToggleKey = key end
end

--------------------------------------------------- responsive scaling
function Window:_BindScaling()
	local function refresh()
		local viewport = Util.Viewport()
		local auto = Util.Clamp(math.min(viewport.X / 960, viewport.Y / 680), 0.62, 1.15)
		if Env.IsMobile and not Env.IsTablet then
			auto = Util.Clamp(auto * 1.12, 0.72, 1.2) -- keep touch targets usable
		end
		self.Scale.Scale = auto * (self.UserScale or 1)

		-- effective width in scaled units decides the sidebar layout
		local effective = viewport.X / math.max(self.Scale.Scale, 0.01)
		self:SetCompact(effective < 560)

		-- keep the window inside the safe area
		local inset = GuiService:GetGuiInset()
		local root = self.Root
		if root.AbsoluteSize.X < 1 then return end -- not measured yet
		local halfWidth = (root.AbsoluteSize.X / 2)
		local halfHeight = (root.AbsoluteSize.Y / 2)
		local x = Util.Clamp(root.AbsolutePosition.X + halfWidth, halfWidth, math.max(viewport.X - halfWidth, halfWidth))
		local y = Util.Clamp(root.AbsolutePosition.Y + halfHeight, halfHeight + inset.Y, math.max(viewport.Y - halfHeight, halfHeight))
		if math.abs(x - (root.AbsolutePosition.X + halfWidth)) > 1
			or math.abs(y - (root.AbsolutePosition.Y + halfHeight)) > 1 then
			root.Position = UDim2.fromOffset(x / self.Scale.Scale, y / self.Scale.Scale)
		end
	end

	refresh()
	local camera = workspace.CurrentCamera
	if camera then
		self.Maid:Give(camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh))
	end
	self.RefreshScale = refresh
end

-- Below a narrow breakpoint the sidebar collapses to icons only so the
-- content column never becomes unusably thin on phones.
function Window:SetCompact(state)
	state = state and true or false
	if self.Compact == state then return end
	self.Compact = state

	local full = self.SidebarWidth
	local width = state and 52 or full
	Animation.Tween(self.Sidebar, { Size = UDim2.new(0, width, 1, 0) }, "Smooth")
	Animation.Tween(self.Content, {
		Position = UDim2.fromOffset(width + 10, 0),
		Size = UDim2.new(1, -(width + 22), 1, 0),
	}, "Smooth")

	if self.SidebarFooter then self.SidebarFooter.Visible = not state end

	for _, tab in ipairs(self.Tabs) do
		tab.Label.Visible = not state
		tab.Icon.Position = state and UDim2.new(0.5, -9, 0.5, 0) or UDim2.new(0, 13, 0.5, 0)
		tab.Icon.AnchorPoint = Vector2.new(0, 0.5)
		tab.Badge.Position = state and UDim2.new(1, -4, 0, 6) or UDim2.new(1, -10, 0.5, 0)
	end
end

function Window:SetScale(value)
	self.UserScale = Util.Clamp(value, 0.5, 2)
	if self.RefreshScale then self.RefreshScale() end
end

--------------------------------------------------- floating mobile toggle
function Window:_CreateMobileToggle()
	local button = Util.New("TextButton", {
		Name = "AstrynMobileToggle",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 14, 0, 70),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.fromRGB(17, 17, 30),
		BackgroundTransparency = 0.1,
		Text = "✦",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		ZIndex = 50,
		Parent = self.Gui,
	})
	Util.New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = button })
	Theme:Apply(button, "BackgroundColor3", "Secondary")
	Theme:Apply(button, "TextColor3", "Accent")
	Util.Stroke(Theme:Get("Accent"), 1, 0.5, button)
	self.Maid:Give(button)

	-- draggable so it never blocks gameplay controls
	local dragStart, startPosition, moved

	self.Maid:Give(DragManager:Bind(button,
		function(input)
			if not dragStart then return end
			local delta = (input.Position - dragStart) / self.Scale.Scale
			if delta.Magnitude > 6 then moved = true end
			button.Position = UDim2.new(0,
				startPosition.X.Offset + delta.X, 0,
				startPosition.Y.Offset + delta.Y)
		end,
		function()
			-- a press that never moved is a tap, not a drag
			if not moved then self:Toggle() end
			dragStart = nil
		end,
		function(input)
			dragStart, startPosition, moved = input.Position, button.Position, false
		end))

	self.MobileToggle = button
end

--------------------------------------------------- tabs
function Window:CreateTab(config)
	if self.Destroyed then
		warn("[Astryn] CreateTab called on a destroyed window")
		return nil
	end
	local tab = Tab.new(self, config)
	if not self.ActiveTab then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if type(tab) == "string" then
		for _, candidate in ipairs(self.Tabs) do
			if candidate.Name == tab then tab = candidate; break end
		end
	end
	if type(tab) ~= "table" or tab.Destroyed or self.ActiveTab == tab then return end
	if not Util.IsAlive(tab.Container) then return end

	self.Signals.CollapseDropdowns:Fire(nil)

	local previous = self.ActiveTab
	self.ActiveTab = tab

	for _, candidate in ipairs(self.Tabs) do
		candidate:SetActive(candidate == tab)
	end

	if previous then
		local page = previous.Container
		Animation.Tween(page, { Position = UDim2.fromOffset(-14, 0) }, "Fast")
		task.delay(Animation.Enabled and 0.12 or 0, function()
			if previous.Container then
				previous.Container.Visible = false
				previous.Container.Position = UDim2.fromOffset(0, 0)
			end
		end)
	end

	tab.Container.Visible = true
	tab.Container.Position = UDim2.fromOffset(16, 0)
	Animation.Tween(tab.Container, { Position = UDim2.fromOffset(0, 0) }, "Smooth")
	Animation.Reveal(tab.Container:GetChildren())
end

function Window:GetTab(name)
	for _, tab in ipairs(self.Tabs) do
		if tab.Name == name then return tab end
	end
	return nil
end

--------------------------------------------------- visibility
function Window:Toggle(state)
	if self.Destroyed then return end
	if state == nil then state = not self.Visible end
	self.Visible = state

	if state then
		self.Root.Visible = true
		self.Shadow.Visible = true
		self.Background:Start()
		self.Root.Size = UDim2.fromOffset(self.BaseSize.X.Offset * 0.9, self.Root.Size.Y.Offset * 0.9)
		Animation.Tween(self.Root, {
			Size = self.Minimized and UDim2.fromOffset(self.BaseSize.X.Offset, 52) or self.BaseSize,
			BackgroundTransparency = self.Config.Transparency or 0.06,
		}, "Spring")
		Animation.Tween(self.Shadow, { ImageTransparency = 0.45 }, "Smooth")
	else
		self.Background:Stop()
		Animation.Tween(self.Root, { BackgroundTransparency = 1 }, "Fast")
		Animation.Tween(self.Shadow, { ImageTransparency = 1 }, "Fast")
		local tween = Animation.Tween(self.Root, {
			Size = UDim2.fromOffset(self.BaseSize.X.Offset * 0.9, self.Root.Size.Y.Offset * 0.9),
		}, "Fast")
		task.delay(Animation.Enabled and 0.2 or 0, function()
			if self.Root and not self.Visible then
				self.Root.Visible = false
				self.Shadow.Visible = false
			end
		end)
		if tween then end
	end
end

function Window:ToggleMinimize()
	self.Minimized = not self.Minimized
	self.Body.Visible = not self.Minimized

	if self.Minimized then
		self.Background:Stop()
		Animation.Tween(self.Root, { Size = UDim2.fromOffset(self.BaseSize.X.Offset, 52) }, "Smooth")
		self.MinimizeButton.Text = "+"
	else
		self.Background:Start()
		Animation.Tween(self.Root, { Size = self.BaseSize }, "Smooth")
		self.MinimizeButton.Text = "–"
		task.delay(0.1, function()
			if self.ActiveTab then Animation.Reveal(self.ActiveTab.Container:GetChildren()) end
		end)
	end
end

function Window:Close(skipConfirm)
	if self.Destroyed then return end
	if self.Config.ConfirmClose and not skipConfirm then
		Dialog:Show({
			Title = "Close Astryn HUB",
			Content = "Are you sure you want to unload the interface?",
			Buttons = {
				{ Name = "Close", Primary = true, Callback = function() self:Close(true) end },
				{ Name = "Cancel" },
			},
		})
		return
	end

	self.Destroyed = true
	self.Background:Stop()
	Animation.Tween(self.Root, {
		Size = UDim2.fromOffset(self.BaseSize.X.Offset * 0.88, self.BaseSize.Y.Offset * 0.88),
		BackgroundTransparency = 1,
	}, "Smooth")
	Animation.Tween(self.Shadow, { ImageTransparency = 1 }, "Fast")

	task.delay(Animation.Enabled and 0.3 or 0, function()
		self:Destroy()
	end)

	if self.Config.OnClose then task.spawn(self.Config.OnClose) end
end

-- Idempotent teardown: stops the background job, destroys every tab and
-- element (which unregisters their flags), then clears the ScreenGui.
function Window:Destroy()
	if self._cleaned then return end
	self._cleaned = true
	self.Destroyed = true

	if self.Background then self.Background:Stop() end
	if Util.IsAlive(self.Root) then Animation.Stop(self.Root) end

	for index = #self.Tabs, 1, -1 do
		pcall(function() self.Tabs[index]:Destroy() end)
	end
	table.clear(self.Tabs)
	table.clear(self.Flags)

	self.Maid:Clean()

	local index = table.find(Astryn.Windows, self)
	if index then table.remove(Astryn.Windows, index) end
end

--------------------------------------------------- helpers
function Window:Notify(config) return Notification:Notify(config) end
function Window:Dialog(config) return Dialog:Show(config) end

function Window:SetTransparency(value)
	self.Config.Transparency = value
	self.Root.BackgroundTransparency = value
	self.Sidebar.BackgroundTransparency = Util.Clamp(value + 0.3, 0, 1)
end

function Window:SetPerformanceMode(enabled)
	self.Background:SetMode(enabled and "Performance" or "High")
end

--------------------------------------------------- built-in settings tab
-- Call this LAST so the tab appears at the bottom of the sidebar.
function Window:CreateSettingsTab(config)
	config = config or {}
	local tab = self:CreateTab({ Name = config.Name or "Settings", Icon = config.Icon or "settings" })
	local window = self

	tab:CreateSection("Interface")

	tab:CreateKeybind({
		Name = "UI Toggle Key",
		Description = "Key that shows or hides Astryn HUB",
		Flag = "Astryn::ToggleKey",
		CurrentKeybind = self.ToggleKey,
		Callback = function(key) window:SetToggleKey(key) end,
	})

	tab:CreateSlider({
		Name = "UI Scale",
		Description = "Scales the whole interface",
		Flag = "Astryn::Scale",
		Range = { 60, 140 },
		Increment = 5,
		Suffix = "%",
		CurrentValue = math.floor((self.UserScale or 1) * 100),
		Callback = function(value) window:SetScale(value / 100) end,
	})

	tab:CreateSlider({
		Name = "Window Transparency",
		Description = "Background opacity of the panel",
		Flag = "Astryn::Transparency",
		Range = { 0, 40 },
		Increment = 2,
		Suffix = "%",
		CurrentValue = math.floor((self.Config.Transparency or 0.06) * 100),
		Callback = function(value) window:SetTransparency(value / 100) end,
	})

	local themeNames = {}
	for name in pairs(Theme.Presets) do table.insert(themeNames, name) end
	table.sort(themeNames)

	tab:CreateDropdown({
		Name = "Theme",
		Description = "Astral colour palette",
		Flag = "Astryn::Theme",
		Options = themeNames,
		CurrentOption = Theme.Current,
		Callback = function(value)
			Theme:Set(value, true)
			Notification:Notify({ Title = "Theme", Content = value .. " palette applied.", Duration = 2.5 })
		end,
	})

	tab:CreateColorPicker({
		Name = "Accent Colour",
		Description = "Override the palette accent",
		Flag = "Astryn::Accent",
		Color = Theme:Get("Accent"),
		-- repaint without tweens: this fires continuously while dragging
		Callback = function(value) Theme:Set({ Accent = value }, false) end,
	})

	tab:CreateSection("Performance")

	tab:CreateToggle({
		Name = "Animations",
		Description = "Disable for lower-end devices",
		Flag = "Astryn::Animations",
		CurrentValue = Animation.Enabled,
		Callback = function(value) Animation.Enabled = value end,
	})

	tab:CreateToggle({
		Name = "Performance Mode",
		Description = "Turns off the astral background effects",
		Flag = "Astryn::Performance",
		CurrentValue = false,
		Callback = function(value) window:SetPerformanceMode(value) end,
	})

	tab:CreateSlider({
		Name = "Animation Speed",
		Flag = "Astryn::AnimationSpeed",
		Range = { 50, 200 },
		Increment = 10,
		Suffix = "%",
		CurrentValue = 100,
		Callback = function(value) Animation.Speed = value / 100 end,
	})

	tab:CreateSection("Configuration")

	local nameInput = tab:CreateInput({
		Name = "Config Name",
		PlaceholderText = "default",
		Flag = "Astryn::ConfigName",
		CurrentValue = "default",
	})

	local function configName()
		local text = nameInput:Get()
		return (text and #text > 0) and text or "default"
	end

	tab:CreateButton({
		Name = "Save Configuration",
		Description = "Writes every flagged element to disk",
		Icon = "check",
		Callback = function()
			local ok, err = Config:Save(configName())
			Notification:Notify({
				Title = "Configuration",
				Content = ok and ("Saved as '" .. configName() .. "'.") or ("Save failed: " .. tostring(err)),
				Variant = ok and "Success" or "Error",
			})
		end,
	})

	tab:CreateButton({
		Name = "Load Configuration",
		Description = "Restores a saved configuration",
		Icon = "folder",
		Callback = function()
			local ok, err = Config:Load(configName())
			Notification:Notify({
				Title = "Configuration",
				Content = ok and ("Loaded '" .. configName() .. "'.") or tostring(err),
				Variant = ok and "Success" or "Error",
			})
		end,
	})

	tab:CreateButton({
		Name = "Delete Configuration",
		Description = "Permanently removes the saved file",
		Icon = "cross",
		Callback = function()
			Dialog:Show({
				Title = "Delete configuration",
				Content = "Delete '" .. configName() .. "'? This cannot be undone.",
				Buttons = {
					{ Name = "Delete", Primary = true, Callback = function()
						local ok, err = Config:Delete(configName())
						Notification:Notify({
							Title = "Configuration",
							Content = ok and "Configuration deleted." or tostring(err),
							Variant = ok and "Success" or "Error",
						})
					end },
					{ Name = "Cancel" },
				},
			})
		end,
	})

	tab:CreateButton({
		Name = "Reset All Values",
		Description = "Returns every control to the value it was created with",
		Callback = function()
			Dialog:Show({
				Title = "Reset all values",
				Content = "Every toggle, slider, dropdown and picker returns to its default.",
				Buttons = {
					{ Name = "Reset", Primary = true, Callback = function()
						local _, restored = Config:Reset()
						Notification:Notify({
							Title = "Configuration",
							Content = restored .. " control(s) restored.",
							Variant = "Success",
						})
					end },
					{ Name = "Cancel" },
				},
			})
		end,
	})

	tab:CreateButton({
		Name = "Reset Interface Settings",
		Description = "Restores default theme, scale and animations",
		Callback = function()
			Theme:Set("Astral", true)
			Animation.Enabled = true
			Animation.Speed = 1
			window:SetScale(1)
			window:SetTransparency(0.06)
			window:SetPerformanceMode(false)
			Notification:Notify({ Title = "Astryn HUB", Content = "Interface settings reset.", Variant = "Success" })
		end,
	})

	tab:CreateDivider()
	tab:CreateParagraph({
		Title = "Astryn HUB v" .. Astryn.Version,
		Content = "Astral Interface framework. Configurations are stored under the '"
			.. Config.Folder .. "' folder when a filesystem is available, otherwise in memory for this session.",
	})

	self.SettingsTab = tab
	return tab
end

Astryn.Window = Window

--==================================================================
-- PUBLIC API
--==================================================================

Astryn.Windows = {}

--- Creates (and shows) a window. If the key system is enabled the
--- window stays hidden behind the key screen until verification passes.
--- Removes any Astryn ScreenGui left behind by a previous execution.
--- Without this, re-running the script stacks invisible duplicate UIs.
function Astryn:_PurgeStrayGuis()
	local parent = Util.GuiParent()
	if not parent then return end
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name:match("^Astryn_") then
			pcall(function() child:Destroy() end)
		end
	end
end

function Astryn:CreateWindow(config)
	if config ~= nil and type(config) ~= "table" then
		warn("[Astryn] CreateWindow expects a table — using defaults")
		config = nil
	end
	config = config or {}

	-- Only one Astryn window exists at a time unless explicitly opted out.
	if config.Singleton ~= false then
		for index = #self.Windows, 1, -1 do
			self.Windows[index]:Destroy()
		end
		Notification:ClearAll()
		Notification.Holder = nil
		Overlay:Destroy()
		self:_PurgeStrayGuis()
	end

	if config.Theme then
		Theme:Set(config.Theme, false)
	end
	if config.Animations == false then
		Animation.Enabled = false
	end

	local window = Window.new(config)
	table.insert(self.Windows, window)

	local function reveal()
		if not window.Visible then window:Toggle(true) end
		if config.WelcomeNotification ~= false then
			task.delay(0.35, function()
				Notification:Notify({
					Title = config.Name or "Astryn HUB",
					Content = config.WelcomeMessage or ("Loaded successfully. Press "
						.. (window.ToggleKey and window.ToggleKey.Name or "RightControl") .. " to toggle."),
					Icon = "sparkle",
					Duration = 5,
				})
			end)
		end
	end

	local function gate()
		if KeySystem.Config.Enabled then
			window:Toggle(false)
			KeySystem:Prompt(function(success)
				if success then
					reveal()
					if config.OnVerified then task.spawn(config.OnVerified) end
				else
					window:Destroy()
					if config.OnRejected then task.spawn(config.OnRejected) end
				end
			end)
		else
			reveal()
		end
	end

	if config.LoadingScreen then
		window:Toggle(false)
		local loading = Loading:Show({
			Title = string.upper(tostring(config.Name or "ASTRYN HUB")),
			Subtitle = config.LoadingText or "Aligning the constellations...",
			Duration = type(config.LoadingScreen) == "number" and config.LoadingScreen or 1.6,
			AutoClose = false,
		})
		task.delay(type(config.LoadingScreen) == "number" and config.LoadingScreen or 1.6, function()
			loading:Close()
			task.wait(0.25)
			gate()
		end)
	else
		gate()
	end

	return window
end

--==================================================================
-- EXTENSION API
-- Everything below exists so feature modules and custom components can
-- be written in separate files without editing the core.
--==================================================================

--- Registers a new element type. After this call every tab (existing and
--- future) gains a Create<Name> method.
---
---   Astryn:DefineElement("Stepper", function(tab, config)
---       local row, title, description, stroke = Astryn.Elements.BuildRow(tab, config)
---       -- ... build controls into `row` ...
---       return Astryn.Elements.MakeObject(tab, config, {
---           Row = row, Title = title, Description = description,
---           Maid = maid, Type = "Stepper",
---       })
---   end)
---
---   Tab:CreateStepper({ Name = "Rounds" })
function Astryn:DefineElement(name, factory)
	if type(name) ~= "string" or type(factory) ~= "function" then
		warn("[Astryn] DefineElement expects (name, factory)")
		return false
	end
	if Elements[name] then
		warn("[Astryn] element '" .. name .. "' is being redefined")
	end
	Elements[name] = factory
	Tab["Create" .. name] = function(tab, config)
		return factory(tab, config)
	end
	return true
end

--- Registers a feature module. `builder(window, astryn)` receives the
--- window and builds whatever tabs and controls it needs. Modules are
--- never auto-run; the consumer decides when to mount them.
---
---   Astryn:RegisterModule("PlayerTools", function(window, api)
---       local tab = window:CreateTab({ Name = "Player", Icon = "user" })
---       tab:CreateSection("Movement")
---   end)
---
---   Astryn:LoadModule("PlayerTools", Window)   -- or LoadModules(Window)
Astryn.Modules = {}

function Astryn:RegisterModule(name, builder)
	if type(name) ~= "string" or type(builder) ~= "function" then
		warn("[Astryn] RegisterModule expects (name, builder)")
		return false
	end
	if not self.Modules[name] then
		self._moduleOrder = self._moduleOrder or {}
		table.insert(self._moduleOrder, name)
	end
	self.Modules[name] = { Name = name, Builder = builder, Loaded = false }
	return true
end

function Astryn:LoadModule(name, window, ...)
	local module = self.Modules[name]
	if not module then
		warn("[Astryn] no module registered as '" .. tostring(name) .. "'")
		return false
	end
	if not window or window.Destroyed then
		warn("[Astryn] LoadModule needs a live window")
		return false
	end
	local ok, result = Util.SafeCall(module.Builder, window, self, ...)
	module.Loaded = ok
	module.Instance = result
	return ok, result
end

--- Mounts every registered module, in registration order.
function Astryn:LoadModules(window, ...)
	local loaded = 0
	for _, name in ipairs(self:ListModules()) do
		if self:LoadModule(name, window, ...) then loaded += 1 end
	end
	return loaded
end

--- Returns module names in registration order.
function Astryn:ListModules()
	local names = {}
	for _, name in ipairs(self._moduleOrder or {}) do
		if self.Modules[name] then table.insert(names, name) end
	end
	return names
end

function Astryn:GetModule(name)
	return self.Modules[name]
end

--==================================================================
-- FEEDBACK
--==================================================================

function Astryn:Notify(config) return Notification:Notify(config) end
function Astryn:ClearNotifications() Notification:ClearAll() end
function Astryn:Dialog(config) return Dialog:Show(config) end
function Astryn:ShowLoading(config) return Loading:Show(config) end

function Astryn:SetTheme(theme, animated) return Theme:Set(theme, animated) end
function Astryn:GetTheme() return Theme.Current, Util.Copy(Theme.Colors) end
function Astryn:RegisterTheme(name, palette)
	if type(name) == "string" and type(palette) == "table" then
		Theme.Presets[name] = palette
		return true
	end
	return false
end

function Astryn:SetKeySystem(config) KeySystem:Configure(config) end
function Astryn:ClearSavedKey() KeySystem:ClearKey() end

function Astryn:SaveConfig(name) return Config:Save(name) end
function Astryn:LoadConfig(name) return Config:Load(name) end
function Astryn:DeleteConfig(name) return Config:Delete(name) end
function Astryn:ResetConfig() return Config:Reset() end
function Astryn:ListConfigs() return Config:List() end

--- Runtime diagnostics. Useful for verifying teardown and for stress
--- testing: after Astryn:Destroy() every count should read zero.
---   print(Astryn:GetStats().SchedulerJobs)
function Astryn:GetStats()
	local tabs, elements = 0, 0
	for _, window in ipairs(self.Windows) do
		tabs += #window.Tabs
		for _, tab in ipairs(window.Tabs) do
			elements += #tab.Elements
		end
	end

	local themed = 0
	for _ in pairs(Theme.Registry) do themed += 1 end
	local flags = 0
	for _ in pairs(Config.Registry) do flags += 1 end

	return {
		Windows          = #self.Windows,
		Tabs             = tabs,
		Elements         = elements,
		ThemedInstances  = themed,
		RegisteredFlags  = flags,
		SchedulerJobs    = Scheduler.Count,
		ActiveNotifications = #Notification.Active,
		Modules          = #self:ListModules(),
	}
end

function Astryn:SetAnimationsEnabled(state) Animation.Enabled = state and true or false end
function Astryn:SetAnimationSpeed(multiplier) Animation.Speed = Util.Clamp(multiplier or 1, 0.25, 4) end

--- Reads a live value by flag from any window.
function Astryn:GetFlag(flag)
	for _, window in ipairs(self.Windows) do
		local element = window.Flags[flag]
		if element and element.Get then return element:Get() end
	end
	return nil
end

function Astryn:SetFlag(flag, value, silent)
	for _, window in ipairs(self.Windows) do
		local element = window.Flags[flag]
		if element and element.Set then
			element:Set(value, silent)
			return true
		end
	end
	return false
end

--- Full teardown: destroys every window, notification and overlay.
--- Full teardown: windows, overlays, notifications, scheduler jobs and
--- every registry the library holds. Safe to call more than once.
function Astryn:Destroy()
	for index = #self.Windows, 1, -1 do
		pcall(function() self.Windows[index]:Destroy() end)
	end
	table.clear(self.Windows)

	Notification:ClearAll()
	Notification.Holder = nil
	Overlay:Destroy()
	Scheduler:Clear()

	table.clear(Theme.Registry)
	table.clear(Config.Registry)
	table.clear(Config.Defaults)
	self:_PurgeStrayGuis()
end

Astryn.Unload = Astryn.Destroy

return Astryn
