# Astryn HUB — v1.2.0

An original, modular Roblox Luau UI framework with an astral visual identity.
Single file, no dependencies, works as a `ModuleScript` or through `loadstring`.

---

## 1. Initialising

```lua
-- ModuleScript
local Astryn = require(path.to.Astryn)

-- Remote
local Astryn = loadstring(game:HttpGet("https://example.com/Astryn.lua"))()
```

The module returns a single table. Requiring it twice returns the same table,
and `Astryn:CreateWindow` destroys any previous Astryn window and purges stray
`ScreenGui`s, so re-running a script never stacks duplicate interfaces. Pass
`Singleton = false` to opt out.

---

## 2. Creating a window

```lua
local Window = Astryn:CreateWindow({
    Name        = "Astryn HUB",
    Subtitle    = "Astral Interface",
    Size        = UDim2.fromOffset(680, 470),
    Theme       = "Astral",
    ToggleKey   = Enum.KeyCode.RightControl,
    Transparency = 0.06,
    LoadingScreen = 1.6,      -- seconds, or omit for no loader
    ConfirmClose  = true,     -- ask before unloading
    OnClose       = function() end,
})
```

| Method | Purpose |
|---|---|
| `Window:CreateTab(config)` | Adds a tab |
| `Window:SelectTab(tabOrName)` | Switches tab |
| `Window:GetTab(name)` | Lookup by name |
| `Window:Toggle(state?)` | Show/hide |
| `Window:ToggleMinimize()` | Collapse to header |
| `Window:SetScale(n)` | 1.0 = 100% |
| `Window:SetTransparency(n)` | 0–1 |
| `Window:SetToggleKey(keyCode)` | Rebinds the hotkey |
| `Window:SetCompact(bool)` | Icon-only sidebar (automatic under 560px) |
| `Window:SetPerformanceMode(bool)` | Disables the star field |
| `Window:CreateSettingsTab()` | Built-in settings — call last |
| `Window:Close()` / `Window:Destroy()` | Teardown |

---

## 3. Tabs

```lua
local Tab = Window:CreateTab({ Name = "Main", Icon = "home" })

Tab:SetBadge(3)    -- notification badge, cleared when the tab is opened
Tab:ClearBadge()
Tab:Destroy()
```

`Icon` accepts a built-in glyph name (`home`, `user`, `eye`, `teleport`,
`settings`, `misc`, `star`, `shield`, `code`, `bolt`, `bell`, `grid`, `key`,
`palette`, `world`, …) or an asset string such as `"rbxassetid://123456"`.

---

## 4. Elements

Every element shares the same object shape:

```lua
element:Get()                  -- current value (nil for display-only elements)
element:Set(value, silent?)    -- silent = true skips the callback
element:SetName(text)
element:SetDescription(text)
element:SetEnabled(bool)       -- dims and stops responding
element:SetVisible(bool)
element:Destroy()
element.Instance               -- the root GuiObject
element.Type, element.Flag, element.Enabled
```

Any element given a `Flag` is registered with the configuration system.
Without one, its `Name` is used.

```lua
Tab:CreateSection("Player Settings")
Tab:CreateDivider()
Tab:CreateLabel({ Name = "Text", Accent = true })
Tab:CreateParagraph({ Title = "Information", Content = "Body text." })

Tab:CreateButton({
    Name = "Test Button",
    Description = "Optional",
    Icon = "bolt",
    Callback = function() end,
})

Tab:CreateToggle({
    Name = "Test Toggle",
    CurrentValue = false,
    Flag = "MyToggle",
    Callback = function(value) end,
})

Tab:CreateSlider({
    Name = "Walk Speed",
    Range = { 0, 100 },      -- reversed or invalid ranges are repaired
    Increment = 1,
    CurrentValue = 16,
    Suffix = "",
    Callback = function(value) end,
})                            -- extra: slider:SetRange(min, max)

Tab:CreateDropdown({
    Name = "Select Option",
    Options = { "One", "Two", "Three" },
    CurrentOption = "One",    -- values not in Options are rejected
    Callback = function(value) end,
})                            -- extra: dropdown:Refresh(options, keepSelection)
                              --        dropdown:GetOptions()

Tab:CreateMultiDropdown({
    Name = "Select Several",
    Options = { "A", "B", "C" },
    CurrentOption = { "A" },
    Callback = function(values) end,   -- receives an array
})

Tab:CreateInput({
    Name = "Username",
    PlaceholderText = "Enter username...",
    Numeric = false,
    ClearOnSubmit = false,
    Callback = function(text, enterPressed) end,
})

Tab:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = Enum.KeyCode.RightControl,
    Callback = function(key) end,    -- fired when the binding changes
    OnPress  = function(key) end,    -- fired when the bound key is pressed
})

Tab:CreateColorPicker({
    Name = "Accent Color",
    Color = Color3.fromRGB(140, 100, 255),
    Callback = function(color) end,
})
```

A callback that throws is caught, warned and contained — it never breaks the UI.

---

## 5. Themes

```lua
Astryn:SetTheme("Astral")        -- Astral, Nebula, Void, Aurora, Solstice
Astryn:SetTheme({ Accent = Color3.fromRGB(0, 200, 255) })   -- partial override
Astryn:RegisterTheme("MyTheme", { Background = ..., Accent = ... })
local name, palette = Astryn:GetTheme()
```

Keys: `Background`, `Secondary`, `Tertiary`, `Elevated`, `Accent`, `AccentAlt`,
`Text`, `SubText`, `Border`, `Success`, `Warning`, `Error`, `Nebula`, `Star`.

Aliases are accepted and mapped automatically: `MutedText`/`TextSecondary` →
`SubText`, `Primary`/`Highlight` → `Accent`, `Foreground` → `Text`,
`Stroke`/`Outline` → `Border`, `Surface` → `Secondary`.

Theme changes repaint existing widgets live. Repaints are coalesced into one
pass per frame, so dragging the accent picker stays smooth.

---

## 6. Notifications, dialogs, loading

```lua
Astryn:Notify({
    Title = "Astryn HUB",
    Content = "Feature enabled.",
    Duration = 4,              -- clamped to 1–30
    Variant = "Success",       -- Default | Success | Warning | Error
    Icon = "sparkle",
})
Astryn:ClearNotifications()

Astryn:Dialog({
    Title = "Confirm",
    Content = "Are you sure?",
    Buttons = {
        { Name = "Yes", Primary = true, Callback = function() end },
        { Name = "No" },
    },
})

local loader = Astryn:ShowLoading({ Title = "ASTRYN HUB", Subtitle = "Loading..." })
loader:SetProgress(0.5, "Half way")
loader:Close()
```

---

## 7. Key system

Enabled and keyless modes are the same call. Keyless skips the key screen
entirely — no verification UI is ever constructed. By default, Astryn HUB's
KeySystem talks to the real Astryn HUB backend over HTTP — it never creates
a key, never trusts a local clock for expiry, and never stores a provider
secret, API token, or signing secret.

```lua
-- Keyless
Astryn:SetKeySystem({ Enabled = false })

-- Gated, using the built-in backend (this is also the default config —
-- shown explicitly here so it's obvious where to point a different
-- deployment)
Astryn:SetKeySystem({
    Enabled = true,
    Title = "Astryn HUB",
    Subtitle = "Enter your key to continue",
    Placeholder = "Astryn Key",
    SaveKey = true,

    ApiBaseUrl = "https://astryn-hub.vercel.app/api",
    ValidateEndpoint = "/key/validate",     -- POST {key} -> validation result
    GetKeyUrl = "https://astryn-hub.vercel.app/get-key",
    PremiumUrl = "https://astryn-hub.vercel.app/premium",
})
```

The validate endpoint's request/response contract:

```
POST {ApiBaseUrl}{ValidateEndpoint}
Body: { "key": "ASTRYN-XXXX-XXXX" }

200 OK (free, active):
{ "valid": true, "type": "FREE", "premium": false, "lifetime": false,
  "key": "ASTRYN-XXXX-XXXX", "expiresAt": "2026-09-14T12:00:00Z" }

200 OK (premium):
{ "valid": true, "type": "PREMIUM", "premium": true, "lifetime": true,
  "key": "ASTRYN-PREMIUM-XXXX", "expiresAt": null }

200 OK (expired / invalid):
{ "valid": false, "reason": "expired" }
{ "valid": false, "reason": "invalid_key" }
```

Every field is type-checked before use; a malformed response is treated as
`"Response API tidak valid."`, never as an implicit valid key.

### Backward compatibility: custom validators still work

Supplying `Validate` (or its alias `Verify`) as a function fully overrides
the built-in backend call, exactly like earlier Astryn HUB versions:

```lua
Astryn:SetKeySystem({
    Enabled = true,
    Validate = function(key)
        local ok, body = pcall(game.HttpGet, game, API .. "/verify?key=" .. key)
        return ok and body == "valid", ok and "Welcome back." or "Gateway unreachable."
    end,
})
```

With neither `Validate` nor `Verify` supplied, the default HTTP client is
used. With no backend reachable and no custom validator, the gate fails
closed — no key is ever accepted by falling through to a default "true".

### Public API

```lua
Astryn.KeySystem:SetKey(key, { Validate = true })  -- saves + validates
Astryn.KeySystem:GetKey()                          -- locally saved key, or nil
Astryn.KeySystem:ClearKey()                        -- erases saved key + cached result
Astryn.KeySystem:Validate(key)                     -- (ok, info, message) — talks to the backend
Astryn.KeySystem:IsValid()                         -- from the LAST server response only
Astryn.KeySystem:IsPremium()                       -- from the LAST server response only
Astryn.KeySystem:GetKeyInfo()                      -- copy of the last server response, or nil
Astryn.KeySystem:OpenGetKey()                      -- opens/copies the Get Free Key URL
Astryn.KeySystem:OpenPremium()                     -- opens/copies the Get Premium URL
Astryn.KeySystem:FormatExpiry(info)                -- display only: "Expires in 23h 58m" / "Lifetime"
```

`IsValid()`/`IsPremium()`/`GetKeyInfo()` never consult a local clock or the
saved-key file — they only reflect the most recent real answer from
`Validate()`. A saved key is a convenience for not retyping it; it is always
re-checked against the backend at startup before being trusted, and is only
auto-cleared when the backend gives a definitive negative (not on a network
hiccup, which could just be a temporary outage). `Astryn:ClearSavedKey()`
removes a saved key manually.

---

## 8. Configuration

```lua
Astryn:SaveConfig("default")
Astryn:LoadConfig("default")     -- returns ok, applied, skipped
Astryn:DeleteConfig("default")
Astryn:ResetConfig()             -- restores creation-time defaults
Astryn:ListConfigs()

Astryn:GetFlag("MyToggle")
Astryn:SetFlag("MyToggle", true)
```

Values are stored as JSON under `AstrynHub/configs/`. `Color3` and `EnumItem`
are encoded as tagged tables and decoded back. Unknown flags and undecodable
values are skipped with a warning rather than aborting the load. On executors
without a filesystem, storage falls back to memory for the session.

---

## 9. Teardown

```lua
Window:Destroy()    -- one window
Astryn:Destroy()    -- everything: windows, overlays, scheduler, registries
```

Both are idempotent. Destroying a window destroys its tabs, which destroy their
elements, which unregister their flags and disconnect their connections.

---

## 10. Performance notes

- One `RunService.Heartbeat` connection library-wide (`Scheduler`), released
  automatically when the last job is removed.
- Two `UserInputService` connections library-wide (`DragManager`), shared by
  sliders, colour pickers, the window and the mobile launcher, so cost does not
  grow with the number of controls.
- Tweens are tracked per property and cancel conflicts instead of fighting.
- Star field budget: 34 objects on High, 20 on Balanced, 0 on Performance;
  nebula parallax updates at 20 Hz.
- The background pauses whenever the window is hidden or minimised.

---

## 11. Extending the framework

Astryn separates the **UI framework** from **feature modules**. Feature code
never edits the core — it registers with it.

### Custom elements

```lua
Astryn:DefineElement("Stepper", function(tab, config)
    local maid = Astryn.Maid.new()
    local row, title, description, stroke = Astryn.Elements.BuildRow(tab, config)
    maid:Give(row)

    -- ... build your controls into `row`, using Astryn.Theme:Apply for colours
    -- and Astryn.Tokens for spacing so it matches every other component ...

    local object = Astryn.Elements.MakeObject(tab, config, {
        Row = row, Title = title, Description = description,
        Maid = maid, Type = "Stepper",
    })
    Astryn.Elements.RegisterElement(tab, object, config,
        function() return value end,
        function(v, silent) setValue(v, silent) end)
    return object
end)

Tab:CreateStepper({ Name = "Rounds", Flag = "Rounds" })
```

Every tab — already created or created later — gains the new method, and the
element inherits the shared API, theming, config persistence and cleanup.

### Feature modules

```lua
-- modules/PlayerTools.lua
Astryn:RegisterModule("PlayerTools", function(window, api)
    local tab = window:CreateTab({ Name = "Player", Icon = "user" })
    tab:CreateSection("Movement")
    tab:CreateSlider({ Name = "Speed", Range = { 0, 100 }, Flag = "Speed" })
    return tab
end)

-- main.lua
Astryn:LoadModule("PlayerTools", Window)   -- or Astryn:LoadModules(Window)
Astryn:ListModules()
Astryn:GetModule("PlayerTools")
```

Builders receive `(window, Astryn, ...)`, run through `SafeCall`, and are never
executed automatically — the consumer decides when to mount them.

### Internals available to extensions

| Name | Use |
|---|---|
| `Astryn.Tokens` | spacing, radii, type scale |
| `Astryn.Theme` | `:Apply(instance, property, key)` for live recolouring |
| `Astryn.Animation` | `.Tween`, `.Preset`, `.Reveal`, `.Stop` |
| `Astryn.Maid` | connection/instance lifetime |
| `Astryn.Scheduler` | `:Add(key, fn)` — shares the library's single Heartbeat |
| `Astryn.DragManager` | `:Bind(object, onMove, onEnd, onBegin)` |
| `Astryn.Util` | `New`, `Corner`, `Stroke`, `SafeCall`, `IsAlive`, `Clamp` |
| `Astryn.Elements` | `BuildRow`, `MakeObject`, `RegisterElement`, `HoverGlow` |

---

## 12. Diagnostics

```lua
local stats = Astryn:GetStats()
-- Windows, Tabs, Elements, ThemedInstances, RegisteredFlags,
-- SchedulerJobs, ActiveNotifications, Modules
```

After `Astryn:Destroy()` every count reads zero — the quickest way to verify a
clean teardown during development.
