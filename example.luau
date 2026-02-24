-- EcrinVeil v2.5 — Full Example Script
-- This file touches every element type, every callback pattern, SaveManager,
-- the language system, theme picker, accordion, and the notify/dialog API.
-- It is intentionally verbose so it doubles as living documentation.

local EcrinVeil = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ecrinveil/EcrinVeil/refs/heads/main/Ecrinveil.luau"
))()

-- SaveManager needs a reference to the library so it knows which Options to
-- read/write. Set this before building any tabs that call BuildConfigSection.
EcrinVeil.SaveManager:SetLibrary(EcrinVeil)
EcrinVeil.SaveManager:SetFolder("MyGame_EcrinVeil")

-- Keys listed here will be skipped during save/load.
-- "_cfgName" is the config name input itself — we never want to overwrite it.
EcrinVeil.SaveManager:SetIgnoreIndexes({ _cfgName = true })

-- Cursor shape can be set before CreateWindow.
-- Options: "heart" | "dot" | "ring" | "cross" | "square"
EcrinVeil:SetCursor("dot")

-- Window
local Window = EcrinVeil:CreateWindow({
    Title    = { en = "MyGame Hub", tr = "MyGame Merkezi" },
    Subtitle = { en = "v1.0.0  •  EcrinVeil 2.5", tr = "v1.0.0  •  EcrinVeil 2.5" },
    Width    = 600,
    Height   = 480,
    -- MinimizeKey defaults to RightShift; override if needed.
    MinimizeKey = Enum.KeyCode.RightShift,
})


-- TABS
-- Each tab gets an Icon key (text stand-in) and a translatable Title.

local tabMain     = Window:AddTab({ Title = { en = "Main",     tr = "Ana Sayfa" },  Icon = "home"     })
local tabCombat   = Window:AddTab({ Title = { en = "Combat",   tr = "Savaş"     },  Icon = "zap"      })
local tabVisuals  = Window:AddTab({ Title = { en = "Visuals",  tr = "Görsel"    },  Icon = "eye"      })
local tabPlayers  = Window:AddTab({ Title = { en = "Players",  tr = "Oyuncular" },  Icon = "user"     })
local tabSettings = Window:AddTab({ Title = { en = "Settings", tr = "Ayarlar"   },  Icon = "settings" })

-- Demonstrate badge on a tab (e.g. unread notifications count)
tabMain:SetBadge(3)


-- MAIN TAB
-- Shows: Paragraph, Separator, StatusRow, Button (normal + colored), Notify, Dialog

tabMain:AddParagraph({
    Title   = { en = "Welcome", tr = "Hoşgeldin" },
    Content = {
        en = "This panel gives you a quick overview of your current session stats and quick-action buttons.",
        tr = "Bu panel mevcut oturum istatistiklerini ve hızlı aksiyon butonlarını gösterir.",
    },
})

tabMain:AddSeparator({ Title = { en = "Session Info", tr = "Oturum Bilgisi" } })

-- StatusRow: update the value at runtime with elem:SetValue()
local statusPing = tabMain:AddStatusRow({
    Label = { en = "Ping", tr = "Ping" },
    Value = "—",
    Color = EcrinVeil.Colors.green,
})

local statusFPS = tabMain:AddStatusRow({
    Label = { en = "FPS", tr = "FPS" },
    Value = "—",
})

-- Update ping and FPS every second using a simple heartbeat loop.
-- We use a counter instead of connecting directly to Heartbeat to keep
-- the update rate predictable regardless of frame rate.
local _ticker = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
    _ticker = _ticker + dt
    if _ticker < 1 then return end
    _ticker = 0

    local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    local fps  = math.floor(1 / dt)

    statusPing:SetValue(math.floor(ping) .. " ms",
        ping < 80 and EcrinVeil.Colors.green
        or ping < 150 and EcrinVeil.Colors.orange
        or EcrinVeil.Colors.red)

    statusFPS:SetValue(fps,
        fps >= 55 and EcrinVeil.Colors.green
        or fps >= 30 and EcrinVeil.Colors.orange
        or EcrinVeil.Colors.red)
end)

tabMain:AddSeparator({ Title = { en = "Actions", tr = "Aksiyonlar" } })

-- Normal button
tabMain:AddButton({
    Title       = { en = "Send Info Notification", tr = "Bilgi Bildirimi Gönder" },
    Description = { en = "Fires a toast with kind=info", tr = "info türünde bildirim gösterir" },
    Icon        = "bell",
    Callback    = function()
        EcrinVeil:Notify({
            Title   = "Hello!",
            Content = "This is an info notification.",
            Kind    = "info",   -- "info" | "success" | "warn" | "error"
            Duration = 4,
        })
    end,
})

tabMain:AddButton({
    Title    = { en = "Send Success Notification", tr = "Başarı Bildirimi Gönder" },
    Icon     = "check",
    Callback = function()
        EcrinVeil:Notify({
            Title      = "Done",
            Content    = "Operation completed.",
            SubContent = "Check your inventory.",
            Kind       = "success",
            Duration   = 3,
        })
    end,
})

tabMain:AddButton({
    Title    = { en = "Send Warning Notification", tr = "Uyarı Bildirimi Gönder" },
    Icon     = "warning",
    Callback = function()
        EcrinVeil:Notify({ Title = "Warning", Content = "Low ammo!", Kind = "warn", Duration = 4 })
    end,
})

tabMain:AddButton({
    Title    = { en = "Send Error Notification", tr = "Hata Bildirimi Gönder" },
    Icon     = "x",
    Callback = function()
        EcrinVeil:Notify({ Title = "Error", Content = "Connection lost.", Kind = "error", Duration = 5 })
    end,
})

-- Colored button — passes a Color3 directly; the press effect darkens it slightly.
tabMain:AddButton({
    Title    = { en = "Teleport to Spawn", tr = "Başlangıca Işınlan" },
    Color    = Color3.fromRGB(48, 130, 255),
    Callback = function()
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(0, 5, 0)
            EcrinVeil:Notify({ Title = "Teleported", Kind = "success", Duration = 2 })
        end
    end,
})

-- Dialog example — two buttons, one destructive
tabMain:AddButton({
    Title    = { en = "Open Dialog", tr = "Diyalog Aç" },
    Icon     = "info",
    Callback = function()
        EcrinVeil:Dialog({
            Title   = { en = "Are you sure?", tr = "Emin misiniz?" },
            Content = { en = "This action cannot be undone.", tr = "Bu işlem geri alınamaz." },
            Buttons = {
                {
                    Title    = { en = "Confirm", tr = "Onayla" },
                    Style    = "destructive",
                    Callback = function()
                        EcrinVeil:Notify({ Title = "Confirmed", Kind = "success", Duration = 2 })
                    end,
                },
                {
                    Title  = { en = "Cancel", tr = "İptal" },
                    Style  = "cancel",
                },
            },
        })
    end,
})


-- COMBAT TAB
-- Shows: Toggle, Slider, Keybind (Toggle mode), Keybind (Hold mode), Dropdown (single + multi)

tabCombat:AddSeparator({ Title = { en = "Aimbot", tr = "Nişangah" } })

local toggleAimbot = tabCombat:AddToggle("Aimbot", {
    Title       = { en = "Aimbot",        tr = "Nişangah"      },
    Description = { en = "Lock onto nearest target", tr = "En yakın hedefe kilitle" },
    Default     = false,
    Callback    = function(val)
        -- val is the new boolean state
        print("Aimbot:", val)
    end,
})

-- OnChanged is an alternative to Callback for when you wire it up after creation.
toggleAimbot:OnChanged(function(val)
    print("Aimbot changed (OnChanged):", val)
end)

local sliderFOV = tabCombat:AddSlider("AimbotFOV", {
    Title       = { en = "FOV",     tr = "Alan"      },
    Description = { en = "Aimbot field of view radius in studs", tr = "Nişangah görüş alanı (studs)" },
    Min         = 10,
    Max         = 500,
    Default     = 120,
    Rounding    = 0,
    Callback    = function(val) print("FOV:", val) end,
})

local sliderSmoothing = tabCombat:AddSlider("AimbotSmooth", {
    Title    = { en = "Smoothing", tr = "Yumuşatma" },
    Min      = 0,
    Max      = 1,
    Default  = 0.25,
    Rounding = 2,   -- two decimal places
    Callback = function(val) print("Smooth:", val) end,
})

tabCombat:AddSeparator({ Title = { en = "Targeting", tr = "Hedefleme" } })

-- Single-select dropdown
local dropdownPart = tabCombat:AddDropdown("AimbotPart", {
    Title   = { en = "Target Part", tr = "Hedef Uzuv" },
    Values  = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" },
    Default = "Head",
    Callback = function(val) print("Target part:", val) end,
})

-- Multi-select dropdown
local dropdownTeams = tabCombat:AddDropdown("IgnoreTeams", {
    Title   = { en = "Ignore Teams",   tr = "Takımları Yoksay"  },
    Values  = { "Red", "Blue", "Green", "Yellow" },
    Multi   = true,
    Default = { "Green" },    -- table of pre-selected values
    Callback = function(sel)
        -- sel is a {[value]=bool} table in multi mode
        for team, active in pairs(sel) do
            print(team, active)
        end
    end,
})

tabCombat:AddSeparator({ Title = { en = "Keybinds", tr = "Kısayollar" } })

-- Toggle-mode keybind: each press flips state
local keybindAimbot = tabCombat:AddKeybind("AimbotKey", {
    Title    = { en = "Aimbot Toggle Key", tr = "Nişangah Aç/Kapat Tuşu" },
    Default  = "E",
    Mode     = "Toggle",
    Callback = function(state)
        print("Aimbot keybind state:", state)
        toggleAimbot:SetValue(state)
    end,
    ChangedCallback = function(newKey)
        EcrinVeil:Notify({ Title = "Keybind changed", Content = newKey.Name, Kind = "info", Duration = 2 })
    end,
})

-- Hold-mode keybind: active only while key is held
local keybindSprint = tabCombat:AddKeybind("SprintKey", {
    Title   = { en = "Sprint (Hold)", tr = "Koşu (Basılı Tut)" },
    Default = "LeftShift",
    Mode    = "Hold",
    Callback = function(holding)
        local char = game.Players.LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = holding and 28 or 16
        end
    end,
})


-- VISUALS TAB
-- Shows: ColorPicker, ProgressBar, Accordion

tabVisuals:AddSeparator({ Title = { en = "ESP Colors", tr = "ESP Renkleri" } })

local cpESPFriend = tabVisuals:AddColorpicker("ESPFriendColor", {
    Title   = { en = "Friendly ESP",   tr = "Dost ESP Rengi"  },
    Default = Color3.fromRGB(80, 200, 120),
    Callback = function(col) print("Friend color:", col) end,
})

cpESPFriend:OnChanged(function(col)
    -- Update your ESP rendering logic here
    print("Friend ESP color updated:", col)
end)

local cpESPEnemy = tabVisuals:AddColorpicker("ESPEnemyColor", {
    Title       = { en = "Enemy ESP",  tr = "Düşman ESP Rengi" },
    Description = { en = "Color applied to enemy outlines", tr = "Düşman kenar rengine uygulanır" },
    Default     = Color3.fromRGB(255, 70, 70),
    Callback    = function(col) print("Enemy color:", col) end,
})

tabVisuals:AddSeparator({ Title = { en = "Loading / Progress", tr = "Yükleme / İlerleme" } })

-- ProgressBar: call elem:SetValue(0..1) to update at runtime
local progressLoad = tabVisuals:AddProgressBar({
    Title   = { en = "Asset Loading", tr = "Varlık Yükleme" },
    Default = 0,
    Color   = EcrinVeil.Colors.blue,
})

-- Simulate a loading sequence when the button is clicked
tabVisuals:AddButton({
    Title    = { en = "Simulate Load", tr = "Yüklemeyi Simüle Et" },
    Icon     = "refresh",
    Callback = function()
        task.spawn(function()
            for i = 0, 100, 2 do
                progressLoad:SetValue(i / 100)
                task.wait(0.04)
            end
            EcrinVeil:Notify({ Title = "Load complete", Kind = "success", Duration = 2 })
        end)
    end,
})

tabVisuals:AddSeparator({ Title = { en = "Accordion Demo", tr = "Accordion Demo" } })

-- Accordion: a collapsible section that can contain any element type.
-- Elements are added via acc:Add(function(innerTab) ... end).
-- innerTab exposes the same Add* API as a regular Tab.
local accAdvanced = tabVisuals:AddAccordion({
    Title       = { en = "Advanced Visuals", tr = "Gelişmiş Görseller" },
    DefaultOpen = false,
})

accAdvanced:Add(function(t)
    t:AddToggle("ShowSkeleton", {
        Title    = { en = "Skeleton ESP",  tr = "İskelet ESP"  },
        Default  = false,
        Callback = function(v) print("Skeleton:", v) end,
    })

    t:AddToggle("ShowHealthBar", {
        Title    = { en = "Health Bars",  tr = "Sağlık Barları" },
        Default  = true,
        Callback = function(v) print("HealthBars:", v) end,
    })

    t:AddSlider("ESPDistance", {
        Title    = { en = "ESP Max Distance", tr = "Maks ESP Mesafesi" },
        Min      = 50,
        Max      = 2000,
        Default  = 500,
        Rounding = 0,
        Callback = function(v) print("ESP distance:", v) end,
    })

    t:AddColorpicker("SkeletonColor", {
        Title   = { en = "Skeleton Color", tr = "İskelet Rengi" },
        Default = Color3.fromRGB(255, 255, 255),
    })
end)

-- A second accordion to demonstrate multiple on the same tab
local accChams = tabVisuals:AddAccordion({
    Title       = { en = "Chams", tr = "Chams" },
    DefaultOpen = false,
})

accChams:Add(function(t)
    t:AddToggle("ChamsEnabled", {
        Title   = { en = "Enable Chams", tr = "Chams Aktif" },
        Default = false,
        Callback = function(v) print("Chams:", v) end,
    })

    t:AddDropdown("ChamsMaterial", {
        Title   = { en = "Material", tr = "Materyal" },
        Values  = { "Neon", "ForceField", "Glass", "SmoothPlastic" },
        Default = "Neon",
        Callback = function(v) print("Chams material:", v) end,
    })

    t:AddColorpicker("ChamsColor", {
        Title   = { en = "Chams Color", tr = "Chams Rengi" },
        Default = Color3.fromRGB(255, 40, 40),
    })
end)


-- PLAYERS TAB
-- Shows: PlayerTable (with avatar thumbnails + search), Table (searchable + multi-select)

tabPlayers:AddSeparator({ Title = { en = "Online Players", tr = "Çevrimiçi Oyuncular" } })

local playerTable = tabPlayers:AddPlayerTable({
    Title      = { en = "Select Player", tr = "Oyuncu Seç" },
    MaxVisible = 6,
    ShowSelf   = false,   -- hide the local player from the list
    OnSelect   = function(name, isDoubleClick)
        if isDoubleClick then
            EcrinVeil:Notify({
                Title   = "Double-clicked",
                Content = name,
                Kind    = "info",
                Duration = 2,
            })
        else
            print("Selected player:", name)
        end
    end,
})

tabPlayers:AddButton({
    Title    = { en = "Teleport to Selected", tr = "Seçilene Işınlan" },
    Icon     = "target",
    Callback = function()
        local name = playerTable:GetSelected()
        if not name then
            EcrinVeil:Notify({ Title = "No player selected", Kind = "warn", Duration = 2 })
            return
        end
        local target = game.Players:FindFirstChild(name)
        if target and target.Character then
            local char = game.Players.LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                EcrinVeil:Notify({ Title = "Teleported to " .. name, Kind = "success", Duration = 2 })
            end
        end
    end,
})

tabPlayers:AddSeparator({ Title = { en = "Weapon Table (multi-select)", tr = "Silah Tablosu (çoklu seçim)" } })

-- Generic Table with search and multi-select
local weaponTable = tabPlayers:AddTable({
    Title      = { en = "Equipped Weapons", tr = "Donanımlı Silahlar" },
    Searchable = true,
    Multi      = true,
    MaxVisible = 5,
    Items      = { "AK-47", "M4A1", "AWP", "Desert Eagle", "P90", "UMP-45", "MP5", "Shotgun" },
    OnSelect   = function(selected)
        -- selected is {[label]=bool} in multi mode
        local active = {}
        for k, v in pairs(selected) do if v then table.insert(active, k) end end
        print("Weapons selected:", table.concat(active, ", "))
    end,
})

-- Dynamically update the table items (e.g. after loading player inventory)
tabPlayers:AddButton({
    Title    = { en = "Reload Weapon List", tr = "Silah Listesini Yenile" },
    Icon     = "refresh",
    Callback = function()
        weaponTable:SetItems({ "AK-47", "M4A1", "AWP", "Knife", "Grenade" })
        EcrinVeil:Notify({ Title = "Weapon list updated", Kind = "success", Duration = 2 })
    end,
})


-- SETTINGS TAB
-- Shows: Input (plain + numeric), Dropdown for theme, ThemePicker widget,
--        LanguageDropdown, SaveManager config section

tabSettings:AddSeparator({ Title = { en = "General", tr = "Genel" } })

-- Plain text input
local inputUsername = tabSettings:AddInput("Username", {
    Title       = { en = "Display Name",    tr = "Görünen Ad"          },
    Placeholder = { en = "Enter your name", tr = "Adınızı girin"       },
    Default     = "",
    Finished    = true,   -- fires Callback only on Enter, not every keystroke
    Callback    = function(val) print("Name set to:", val) end,
})

inputUsername:OnChanged(function(val)
    -- fires on every keystroke regardless of Finished flag
    print("Name typing:", val)
end)

-- Numeric-only input (strips non-numeric characters automatically)
local inputPort = tabSettings:AddInput("ServerPort", {
    Title       = { en = "Custom Server Port", tr = "Özel Sunucu Portu" },
    Placeholder = "1-65535",
    Default     = "7777",
    Numeric     = true,
    Finished    = true,
    Callback    = function(val) print("Port:", val) end,
})

tabSettings:AddSeparator({ Title = { en = "Appearance", tr = "Görünüm" } })

-- Cursor shape dropdown — wires directly into EcrinVeil:SetCursor()
tabSettings:AddDropdown("CursorShape", {
    Title   = { en = "Cursor Shape", tr = "İmleç Şekli" },
    Values  = EcrinVeil:GetCursorShapes(),
    Default = "dot",
    Callback = function(val)
        EcrinVeil:SetCursor(val)
    end,
})

-- ThemePicker widget — shows all built-in themes with color swatches.
-- Clicking any row immediately applies the theme to all open windows.
tabSettings:AddThemePicker()

tabSettings:AddSeparator({ Title = { en = "Language", tr = "Dil" } })

-- LanguageDropdown auto-populates from labels that were registered via
-- multi-language table syntax (the {en=..., tr=...} pattern used above).
-- Languages with missing translations are shown greyed-out and non-clickable.
tabSettings:AddLanguageDropdown()

tabSettings:AddSeparator({ Title = { en = "Danger Zone", tr = "Tehlike Bölgesi" } })

-- SetEnabled can lock a tab so it's un-clickable and dimmed.
-- Useful for features gated behind a toggle or a remote check.
tabSettings:AddButton({
    Title    = { en = "Disable Combat Tab", tr = "Savaş Sekmesini Devre Dışı Bırak" },
    Icon     = "lock",
    Callback = function()
        tabCombat:SetEnabled(false)
        EcrinVeil:Notify({ Title = "Combat tab disabled", Kind = "warn", Duration = 3 })
    end,
})

tabSettings:AddButton({
    Title    = { en = "Re-enable Combat Tab", tr = "Savaş Sekmesini Yeniden Etkinleştir" },
    Icon     = "check",
    Callback = function()
        tabCombat:SetEnabled(true)
        EcrinVeil:Notify({ Title = "Combat tab enabled", Kind = "success", Duration = 2 })
    end,
})

-- SetBadge(0) clears the badge
tabSettings:AddButton({
    Title    = { en = "Clear Main Tab Badge", tr = "Ana Sekme Rozetini Temizle" },
    Icon     = "x",
    Callback = function() tabMain:SetBadge(0) end,
})

tabSettings:AddButton({
    Title    = { en = "Jump to Visuals Tab", tr = "Görseller Sekmesine Git" },
    Icon     = "eye",
    Callback = function() Window:SelectTab(3) end,  -- 1-based index
})

-- The config section adds a name input + Save/Load buttons.
-- Works automatically with any element registered in EcrinVeil.Options
-- (i.e. elements created with an id as first argument).
EcrinVeil.SaveManager:BuildConfigSection(tabSettings)

-- Manual save/load example (bypasses the UI config section)
tabSettings:AddButton({
    Title    = { en = "Quick Save (slot: autosave)", tr = "Hızlı Kaydet (slot: autosave)" },
    Icon     = "download",
    Callback = function()
        local ok = EcrinVeil.SaveManager:Save("autosave")
        EcrinVeil:Notify({
            Title = ok and "Autosaved" or "Save failed",
            Kind  = ok and "success" or "error",
            Duration = 2,
        })
    end,
})

tabSettings:AddButton({
    Title    = { en = "Quick Load (slot: autosave)", tr = "Hızlı Yükle (slot: autosave)" },
    Icon     = "upload",
    Callback = function()
        local ok = EcrinVeil.SaveManager:Load("autosave")
        EcrinVeil:Notify({
            Title = ok and "Autosave loaded" or "No autosave found",
            Kind  = ok and "success" or "warn",
            Duration = 2,
        })
    end,
})

-- After the UI is fully built, set the initial language.
-- Do this last so all labels are registered before the call.
EcrinVeil:SetLanguage("en")

-- Auto-load the default config on startup so settings persist between sessions.
-- Wrapped in a task.defer so it runs after the first frame (all elements ready).
task.defer(function()
    EcrinVeil.SaveManager:Load("default")
end)
