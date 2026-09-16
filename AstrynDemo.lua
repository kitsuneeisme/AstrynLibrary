--[[
	ASTRYN HUB — Demo / Test Harness
	--------------------------------
	Showcases the framework only. No game logic, no feature code.

	Tabs:
	  Main      buttons, toggles, sections, dividers, notifications
	  Player    sliders, inputs, keybinds  (structure only, no game calls)
	  Visual    dropdowns, multi-dropdowns, colour pickers
	  Misc      dialogs, loading screen, badges, diagnostics
	  Settings  the framework's built-in settings tab

	Loading:
	  ModuleScript : local Astryn = require(script.Parent.Astryn)
	  Remote       : local Astryn = loadstring(game:HttpGet("<url>/Astryn.lua"))()
--]]

local Astryn = require(script.Parent.Astryn)

--==================================================================
-- KEY SYSTEM — keyless. Flip Enabled to gate the interface.
--==================================================================

Astryn:SetKeySystem({
	Enabled = false,
	Title = "Astryn HUB",
	Subtitle = "Enter your key to continue",
	Placeholder = "Astryn Key",
	Note = "Keys are issued per session.",
	SaveKey = true,
	GetKeyLink = "https://example.com/astryn/key",

	-- Replaceable provider. May yield. Returns (ok, message).
	-- With no provider the gate fails closed — nothing is hardcoded.
	Verify = function(key)
		return false, "No key backend connected yet."
	end,
})

--==================================================================
-- WINDOW
--==================================================================

local Window = Astryn:CreateWindow({
	Name = "Astryn HUB",
	Subtitle = "Astral Interface",
	Size = UDim2.fromOffset(680, 470),
	Theme = "Astral",
	ToggleKey = Enum.KeyCode.RightControl,
	LoadingScreen = 1.6,
	ConfirmClose = true,
	OnClose = function()
		print("[Astryn] Interface unloaded.")
	end,
})

--==================================================================
-- MAIN
--==================================================================

local Main = Window:CreateTab({ Name = "Main", Icon = "home" })

Main:CreateSection("Welcome")

Main:CreateParagraph({
	Title = "Astryn HUB",
	Content = "A modular astral interface for Roblox. Every control here is a live "
		.. "framework component — this tab is a test harness, not a feature set.",
})

Main:CreateLabel({ Name = "Framework v" .. Astryn.Version, Accent = true })

Main:CreateDivider()
Main:CreateSection("Actions")

Main:CreateButton({
	Name = "Example Button",
	Description = "Hover, ripple and callback",
	Icon = "bolt",
	Callback = function()
		Astryn:Notify({
			Title = "Astryn HUB",
			Content = "Button clicked!",
			Icon = "check",
			Variant = "Success",
			Duration = 3,
		})
	end,
})

local targetButton = Main:CreateButton({
	Name = "Toggleable Button",
	Description = "Disabled by the switch below",
	Callback = function()
		print("[Demo] Target fired.")
	end,
})

Main:CreateToggle({
	Name = "Example Toggle",
	Description = "Also controls the button above",
	Flag = "Demo::Toggle",
	CurrentValue = true,
	Callback = function(value)
		targetButton:SetEnabled(value)
	end,
})

Main:CreateSection("Notifications")

Main:CreateButton({
	Name = "Show All Variants",
	Description = "Four stacked notifications",
	Icon = "bell",
	Callback = function()
		for index, variant in ipairs({ "Default", "Success", "Warning", "Error" }) do
			task.delay(index * 0.18, function()
				Astryn:Notify({
					Title = variant .. " notification",
					Content = "This is a " .. variant:lower() .. " notification from Astryn HUB.",
					Variant = variant,
					Icon = "sparkle",
					Duration = 4,
				})
			end)
		end
	end,
})

Main:CreateButton({
	Name = "Clear Notifications",
	Callback = function()
		Astryn:ClearNotifications()
	end,
})

--==================================================================
-- PLAYER  (numeric + text input components)
--==================================================================

local Player = Window:CreateTab({ Name = "Player", Icon = "user" })

Player:CreateSection("Sliders")

Player:CreateSlider({
	Name = "Example Slider",
	Description = "Range, increment and suffix",
	Flag = "Demo::Slider",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = 16,
	Callback = function(value)
		print("[Demo] Slider:", value)
	end,
})

Player:CreateSlider({
	Name = "Decimal Slider",
	Flag = "Demo::SliderFine",
	Range = { 0, 5 },
	Increment = 0.25,
	CurrentValue = 1,
	Suffix = "x",
	Callback = function(value)
		print("[Demo] Multiplier:", value)
	end,
})

Player:CreateDivider()
Player:CreateSection("Text & Keys")

Player:CreateInput({
	Name = "Example Input",
	Description = "Commits on Enter or focus loss",
	PlaceholderText = "Type something...",
	Flag = "Demo::Input",
	Callback = function(text, enterPressed)
		print("[Demo] Input:", text, "enter:", enterPressed)
	end,
})

Player:CreateKeybind({
	Name = "Example Keybind",
	Description = "Right-click the field to clear it",
	Flag = "Demo::Keybind",
	CurrentKeybind = Enum.KeyCode.F,
	Callback = function(key)
		print("[Demo] Bound to:", key.Name)
	end,
	OnPress = function()
		Astryn:Notify({ Title = "Keybind", Content = "Bound key pressed.", Duration = 2 })
	end,
})

--==================================================================
-- VISUAL  (selection + colour components)
--==================================================================

local Visual = Window:CreateTab({ Name = "Visual", Icon = "eye" })

Visual:CreateSection("Selection")

local demoDropdown = Visual:CreateDropdown({
	Name = "Single Select",
	Description = "One option at a time",
	Flag = "Demo::Dropdown",
	Options = { "Option 1", "Option 2", "Option 3", "Option 4" },
	CurrentOption = "Option 1",
	Callback = function(value)
		print("[Demo] Dropdown:", value)
	end,
})

Visual:CreateMultiDropdown({
	Name = "Multi Select",
	Description = "Search appears automatically past eight options",
	Flag = "Demo::MultiDropdown",
	Options = { "Aries", "Lyra", "Orion", "Vega", "Cygnus", "Draco", "Perseus", "Corvus", "Pyxis" },
	CurrentOption = { "Lyra", "Orion" },
	Callback = function(values)
		print("[Demo] Multi:", table.concat(values, ", "))
	end,
})

Visual:CreateButton({
	Name = "Replace Dropdown Options",
	Description = "Demonstrates Refresh() at runtime",
	Callback = function()
		local sets = {
			{ "Option 1", "Option 2", "Option 3", "Option 4" },
			{ "Alpha", "Beta", "Gamma" },
			{ "North", "South", "East", "West" },
		}
		demoDropdown:Refresh(sets[math.random(#sets)])
		Astryn:Notify({ Title = "Dropdown", Content = "Options replaced.", Duration = 2.5 })
	end,
})

Visual:CreateDivider()
Visual:CreateSection("Colour")

Visual:CreateColorPicker({
	Name = "Example Colour Picker",
	Description = "HSV square with a hue strip",
	Flag = "Demo::Color",
	Color = Color3.fromRGB(140, 100, 255),
	Callback = function(color)
		print("[Demo] Colour:", color)
	end,
})

Visual:CreateColorPicker({
	Name = "Live Accent",
	Description = "Repaints the whole interface",
	Color = Color3.fromRGB(140, 100, 255),
	Callback = function(color)
		Astryn:SetTheme({ Accent = color })
	end,
})

--==================================================================
-- MISC  (modals, loaders, diagnostics)
--==================================================================

local Misc = Window:CreateTab({ Name = "Misc", Icon = "misc" })

Misc:CreateSection("Modals")

Misc:CreateButton({
	Name = "Open Dialog",
	Description = "Blocks input until dismissed",
	Callback = function()
		Astryn:Dialog({
			Title = "Confirm action",
			Content = "Dialogs are modal and sit above the window.",
			Buttons = {
				{ Name = "Confirm", Primary = true, Callback = function()
					Astryn:Notify({ Title = "Dialog", Content = "Confirmed.", Variant = "Success" })
				end },
				{ Name = "Cancel" },
			},
		})
	end,
})

Misc:CreateButton({
	Name = "Replay Loading Screen",
	Callback = function()
		Astryn:ShowLoading({ Title = "ASTRYN HUB", Subtitle = "Recalibrating...", Duration = 2 })
	end,
})

Misc:CreateDivider()
Misc:CreateSection("Framework")

Misc:CreateButton({
	Name = "Badge the Player Tab",
	Description = "Cleared when that tab is opened",
	Callback = function()
		Player:SetBadge(3)
	end,
})

Misc:CreateButton({
	Name = "Print Diagnostics",
	Description = "Live object, connection and flag counts",
	Callback = function()
		local stats = Astryn:GetStats()
		for _, key in ipairs({
			"Windows", "Tabs", "Elements", "ThemedInstances",
			"RegisteredFlags", "SchedulerJobs", "ActiveNotifications", "Modules",
		}) do
			print(string.format("[Astryn] %-20s %s", key, tostring(stats[key])))
		end
	end,
})

Misc:CreateButton({
	Name = "Read Flag Values",
	Callback = function()
		for _, flag in ipairs({ "Demo::Toggle", "Demo::Slider", "Demo::Dropdown", "Demo::Input" }) do
			print(string.format("[Demo] %s = %s", flag, tostring(Astryn:GetFlag(flag))))
		end
	end,
})

Misc:CreateDivider()

Misc:CreateParagraph({
	Title = "Adding feature modules",
	Content = "Register a builder with Astryn:RegisterModule(name, fn) and mount it with "
		.. "Astryn:LoadModule(name, Window). Modules build their own tabs using the public "
		.. "API, so the framework never needs to know what they do.",
})

--==================================================================
-- EXAMPLE FEATURE MODULE
-- Shows the separation between framework and features. A real module
-- would live in its own file and be required before mounting.
--==================================================================

Astryn:RegisterModule("ExampleModule", function(window, api)
	local tab = window:CreateTab({ Name = "Module", Icon = "code" })

	tab:CreateSection("Registered module")
	tab:CreateParagraph({
		Title = "ExampleModule",
		Content = "This tab was built by a registered module using only the public API. "
			.. "The core framework was not modified to add it.",
	})
	tab:CreateButton({
		Name = "Module Action",
		Callback = function()
			api:Notify({ Title = "ExampleModule", Content = "Module callback fired.", Duration = 3 })
		end,
	})

	return tab
end)

Astryn:LoadModule("ExampleModule", Window)

--==================================================================
-- SETTINGS — always built last so it sits at the bottom
--==================================================================

Window:CreateSettingsTab()

--==================================================================
-- Optional: restore the last saved configuration
--==================================================================

task.delay(1, function()
	local ok, applied = Astryn:LoadConfig("Default")
	if ok then
		Astryn:Notify({
			Title = "Configuration",
			Content = ("Restored %d value(s)."):format(applied or 0),
			Duration = 3,
		})
	end
end)

return Window
