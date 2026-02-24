# EcrinVeil

### Important: This UI is right now bugged. Please do not use it.

**iOS 17 Dark Mode inspired UI library for Roblox exploits.**  
Clean, animated, multi-language, theme-aware. No external dependencies.

# Note: Check the example script!
---

### Features

- **5 built-in themes** — Dark, Midnight, Slate, Ocean, Ember. Switch at runtime, all elements repaint instantly.
- **Custom cursor** — 5 shapes (heart, dot, ring, cross, square). Hotspot-corrected so the click point aligns with the visual.
- **Multi-language system** — Pass `{en="...", tr="..."}` tables anywhere a label accepts a string. Call `SetLanguage("tr")` and every label updates live. Incomplete languages are flagged in the dropdown.
- **SaveManager** — JSON-based config save/load. KeyCode values round-trip correctly. Ignored keys supported.
- **12 element types** — Paragraph, Separator, StatusRow, Button, Toggle, Slider, Input, Dropdown (single + multi), Keybind (toggle + hold), ProgressBar, ColorPicker (RGB + hex + presets), PlayerTable, Table, Accordion, ThemePicker, LanguageDropdown.
- **Accordion** — Collapsible sections that accept any element type inside them via the same Add* API.
- **Notify + Dialog** — Toast notifications (up to 5 simultaneous slots) with 4 severity kinds. iOS-style alert dialogs with custom button layouts.
- **Tab badges + enable/disable** — Numeric badges on sidebar tabs. Lock tabs programmatically.

---

### Installation

Paste into your script:

```lua
local EcrinVeil = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ecrinveil/EcrinVeil/refs/heads/main/Ecrinveil.luau"
))()
```

---

### Quick Start

```lua
local EcrinVeil = loadstring(game:HttpGet("https://raw.githubusercontent.com/ecrinveil/EcrinVeil/refs/heads/main/Ecrinveil.luau"))()

local Window = EcrinVeil:CreateWindow({
    Title    = "My Script",
    Subtitle = "v1.0",
})

local tab = Window:AddTab({ Title = "Main", Icon = "home" })

tab:AddToggle("GodMode", {
    Title    = "God Mode",
    Default  = false,
    Callback = function(val)
        print("God Mode:", val)
    end,
})
```

---

### API Reference

#### EcrinVeil (global)

| Method | Description |
|--------|-------------|
| `EcrinVeil:CreateWindow(opts)` | Creates and returns a Window. |
| `EcrinVeil:Notify(opts)` | Shows a toast notification. Returns `{Dismiss}`. |
| `EcrinVeil:Dialog(opts)` | Shows a modal dialog. Returns `{Close}`. |
| `EcrinVeil:SetTheme(name)` | Applies a theme globally. Names: `"dark"` `"midnight"` `"slate"` `"ocean"` `"ember"`. |
| `EcrinVeil:GetThemes()` | Returns a sorted list of theme name strings. |
| `EcrinVeil:SetLanguage(code)` | Updates all tracked labels to the given language code. |
| `EcrinVeil:SetCursor(shape)` | Changes the custom cursor shape. Shapes: `"heart"` `"dot"` `"ring"` `"cross"` `"square"`. |
| `EcrinVeil:GetCursorShapes()` | Returns a sorted list of cursor shape strings. |
| `EcrinVeil.Options` | Table of all elements created with an id. Use for SaveManager. |
| `EcrinVeil.Colors` | Live color table (C). Reflects the active theme. |

#### CreateWindow — opts

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Title` | string or table | `"EcrinVeil"` | Window title. Accepts `{en="...", tr="..."}`. |
| `Subtitle` | string or table | — | Smaller text under the title. |
| `Width` | number | `580` | Window width in pixels. |
| `Height` | number | `460` | Window height in pixels. |
| `MinimizeKey` | KeyCode | `RightShift` | Key to toggle window visibility. |

#### Window

| Method | Description |
|--------|-------------|
| `Window:AddTab(opts)` | Creates and returns a Tab. `opts.Title`, `opts.Icon` (icon key string). |
| `Window:SelectTab(index)` | Programmatically selects a tab by 1-based index. |
| `Window:SetTitle(str)` | Updates the window title at runtime. |
| `Window:Show()` / `Window:Hide()` | Show or hide the window with animation. |
| `Window:Toggle()` | Toggles visibility. |
| `Window:Destroy()` | Removes the window and cleans up. |

#### Tab

| Method | Description |
|--------|-------------|
| `Tab:SetBadge(n)` | Shows a numeric badge on the tab. `0` clears it. |
| `Tab:SetEnabled(bool)` | Dims and locks/unlocks the tab. |
| `Tab:AddParagraph(opts)` | Static text block. `opts.Title`, `opts.Content`. |
| `Tab:AddSeparator(opts)` | Thin divider. Optional `opts.Title` label. |
| `Tab:AddStatusRow(opts)` | Label + right-aligned value. `elem:SetValue(v, color?)`. |
| `Tab:AddButton(opts)` | Tappable row. `opts.Callback`. Optional `opts.Color` for solid-fill style. |
| `Tab:AddToggle(id, opts)` | iOS-style switch. `elem:SetValue(bool)`, `elem:OnChanged(fn)`. |
| `Tab:AddSlider(id, opts)` | Draggable slider. `opts.Min/Max/Default/Rounding`. `elem:SetValue(n)`. |
| `Tab:AddInput(id, opts)` | Text input. `opts.Numeric`, `opts.Finished`, `opts.Placeholder`. |
| `Tab:AddDropdown(id, opts)` | Single or multi-select list with search. `opts.Multi`, `opts.Values`. |
| `Tab:AddKeybind(id, opts)` | Key listener. `opts.Mode = "Toggle"\|"Hold"`. `elem:GetState()`. |
| `Tab:AddProgressBar(opts)` | 0–1 range bar. `elem:SetValue(n)`, `elem:SetColor(c)`. |
| `Tab:AddColorpicker(id, opts)` | RGB sliders + hex input + preset swatches. `elem:SetValue(Color3)`. |
| `Tab:AddPlayerTable(opts)` | Searchable player list with avatars. `elem:GetSelected()`. |
| `Tab:AddTable(opts)` | Generic searchable + optionally multi-select list. `elem:SetItems(t)`. |
| `Tab:AddAccordion(opts)` | Collapsible section. `acc:Add(fn)` — fn receives an inner Tab-like object. |
| `Tab:AddThemePicker()` | Built-in theme selector UI. |
| `Tab:AddLanguageDropdown()` | Language selector. Auto-populated from registered label languages. |

#### Notify — opts

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `Title` | string | — | Bold header text. |
| `Content` | string | `""` | Body text. |
| `SubContent` | string | — | Small secondary line. |
| `Kind` | string | `"info"` | `"info"` `"success"` `"warn"` `"error"` — sets accent color. |
| `Duration` | number | `4` | Seconds before auto-dismiss. `nil` = persistent. |

#### Dialog — opts

| Key | Type | Description |
|-----|------|-------------|
| `Title` | string or table | Dialog heading. |
| `Content` | string or table | Body text. |
| `Buttons` | array | Each entry: `{Title, Style?, Callback?}`. Style: `"destructive"` or `"cancel"`. |

#### SaveManager

```lua
EcrinVeil.SaveManager:SetLibrary(EcrinVeil)
EcrinVeil.SaveManager:SetFolder("MyGame")
EcrinVeil.SaveManager:SetIgnoreIndexes({ _cfgName = true })

EcrinVeil.SaveManager:Save("profile1")   -- returns bool
EcrinVeil.SaveManager:Load("profile1")   -- returns bool

-- Adds a config name input + Save/Load buttons to a tab
EcrinVeil.SaveManager:BuildConfigSection(tab)
```

#### Language system

Any label value can be a plain string or a language table:

```lua
tab:AddToggle("id", {
    Title = { en = "God Mode", tr = "Tanrı Modu", de = "Gottmodus" },
})
```

Switch at runtime:

```lua
EcrinVeil:SetLanguage("tr")
```

Languages with missing keys are shown as `(incomplete)` and are non-selectable in the dropdown.

---

### Themes

| Name | Character |
|------|-----------|
| `dark` | Pure black, iOS system colors |
| `midnight` | Black background with deep blue accents |
| `slate` | Dark grey, neutral and professional |
| `ocean` | Deep navy with cyan/teal tones |
| `ember` | Dark red/orange, warm feel |

```lua
EcrinVeil:SetTheme("ocean")
```

---

### Accordion

```lua
local acc = tab:AddAccordion({
    Title       = "Advanced Options",
    DefaultOpen = false,
})

acc:Add(function(t)
    t:AddToggle("SomeToggle", { Title = "Enable X", Default = false })
    t:AddSlider("SomeSlider", { Title = "Intensity", Min = 0, Max = 100, Default = 50 })
end)

-- Programmatic control
acc:Open()
acc:Close()
acc:Toggle()
```

---

### Common Patterns

**Read any option value anywhere:**
```lua
local val = EcrinVeil.Options["Aimbot"].Value
```

**Update an element from outside its callback:**
```lua
local toggle = tab:AddToggle("AutoFarm", { Default = false })
-- somewhere else:
toggle:SetValue(true)
```

**Hide/show an element:**
```lua
local slider = tab:AddSlider("Speed", { Default = 16 })
slider:SetVisible(false)
```

**Destroy an element:**
```lua
slider:Destroy()
```
