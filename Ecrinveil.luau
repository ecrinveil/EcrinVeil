-- EcrinVeil — iOS-Native UI Library v2.5
-- Roblox / iOS 17 Dark Mode / SF Pro-style fonts
--
-- Changelog v2.5:
--   - Cursor hotspot fix: shape offset corrected so the click point
--     matches the visual tip/center of each cursor shape.
--   - press() now accepts Color3 directly, as a C-key string, or as a function.
--     Colored buttons (opts.Color) register a theme callback so they repaint on theme change.
--   - AddTable: isSel closure was stale after rebuild — now re-evaluated per build pass.
--   - AddDropdown: vcSel capture leak fixed, closure rebuilt each buildList call.
--   - SaveManager Load: KeyCode values stored as plain name string, restored correctly.
--   - _themeFrames / _themeCallbacks: dead-ref pruning now runs on every SetTheme
--     call and also on window Destroy, preventing unbounded growth.
--   - ColorPicker preset swatches now pull from C at open-time; added a note about
--     live theme-change while panel is open (known limitation, not worth the complexity).
--   - Dropdown / ColorPicker panel close race condition tightened (flag + nil guard).
--   - Added Tab:AddAccordion() — collapsible section with animated expand/collapse.
--   - resolveText() guards against nil input.

local EcrinVeil   = {}
EcrinVeil.__index = EcrinVeil
EcrinVeil.Version = "2.5.0"
EcrinVeil.Options = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local TS         = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local plr        = Players.LocalPlayer

-- Language system
EcrinVeil._lang            = "en"
EcrinVeil._labelRefs       = {}
EcrinVeil._registeredLangs = {}

local function resolveText(val)
    if val == nil then return "" end
    if type(val) == "string" then return val end
    if type(val) == "table" then
        return val[EcrinVeil._lang] or val["en"] or (next(val) and select(2, next(val))) or ""
    end
    return tostring(val)
end

local function trackLabel(labelInst, originalVal, transformFn)
    if type(originalVal) ~= "table" then return end
    for lang in pairs(originalVal) do
        EcrinVeil._registeredLangs[lang] = true
    end
    table.insert(EcrinVeil._labelRefs, {
        label     = labelInst,
        original  = originalVal,
        transform = transformFn,
    })
end

function EcrinVeil:SetLanguage(lang)
    if type(lang) ~= "string" or lang == "" then
        warn("[EcrinVeil] SetLanguage: invalid code -> " .. tostring(lang))
        return
    end
    self._lang = lang
    local dead = {}
    for i, ref in ipairs(self._labelRefs) do
        local ok, err = pcall(function()
            if ref.label and ref.label.Parent then
                local resolved = resolveText(ref.original)
                ref.label.Text = ref.transform and ref.transform(resolved) or resolved
            else
                table.insert(dead, i)
            end
        end)
        if not ok then
            warn("[EcrinVeil] SetLanguage error: " .. tostring(err))
            table.insert(dead, i)
        end
    end
    for i = #dead, 1, -1 do table.remove(self._labelRefs, dead[i]) end
end

-- Internal UI strings
local INTERNAL = {
    search_placeholder = {
        en="Search...", tr="Ara...", es="Buscar...", fr="Rechercher...",
        de="Suchen...", pt="Buscar...", ru="Поиск...", zh="搜索...", ar="بحث...", ja="検索...",
    },
    select_placeholder = {
        en="Select", tr="Seciniz", es="Seleccionar", fr="Sélectionner",
        de="Auswählen", pt="Selecionar", ru="Выбрать", zh="选择", ar="اختر", ja="選択",
    },
    player_search = {
        en="Search player...", tr="Oyuncu ara...", es="Buscar jugador...",
        fr="Chercher joueur...", de="Spieler suchen...", pt="Buscar jogador...",
        ru="Поиск игрока...", zh="搜索玩家...", ar="البحث عن لاعب...", ja="プレイヤーを検索...",
    },
    saved         = { en="Saved",    tr="Kaydedildi", es="Guardado",   fr="Enregistré",  de="Gespeichert",     pt="Salvo",     ru="Сохранено",  zh="已保存", ar="تم الحفظ",    ja="保存済み" },
    loaded        = { en="Loaded",   tr="Yuklendi",   es="Cargado",    fr="Chargé",       de="Geladen",         pt="Carregado", ru="Загружено",  zh="已加载", ar="تم التحميل",  ja="読み込み済み" },
    error         = { en="Error",    tr="Hata",       es="Error",      fr="Erreur",       de="Fehler",          pt="Erro",      ru="Ошибка",     zh="错误",   ar="خطأ",          ja="エラー" },
    no_writefile  = { en="writefile not supported",   tr="writefile desteklenmiyor",  es="writefile no soportado",
                      fr="writefile non supporté",    de="writefile nicht unterstützt", pt="writefile não suportado",
                      ru="writefile не поддерживается", zh="不支持writefile", ar="writefile غير مدعوم", ja="writefileは非対応" },
    file_not_found= { en="File not found", tr="Dosya bulunamadi", es="Archivo no encontrado", fr="Fichier introuvable",
                      de="Datei nicht gefunden", pt="Archivo não encontrado", ru="Файл не найден",
                      zh="找不到文件", ar="الملف غير موجود", ja="ファイルが見つかりません" },
    config_section= { en="Configuration", tr="Konfigurasyon", es="Configuración", fr="Configuration",
                      de="Konfiguration", pt="Configuração", ru="Конфигурация", zh="配置", ar="الإعدادات", ja="設定" },
    config_name   = { en="Config Name", tr="Config Adi", es="Nombre de config", fr="Nom de config",
                      de="Config-Name", pt="Nome do config", ru="Имя конфига", zh="配置名称", ar="اسم التكوين", ja="設定名" },
    save_btn      = { en="Save",  tr="Kaydet", es="Guardar",  fr="Enregistrer", de="Speichern", pt="Salvar",    ru="Сохранить", zh="保存", ar="حفظ",    ja="保存" },
    load_btn      = { en="Load",  tr="Yukle",  es="Cargar",   fr="Charger",     de="Laden",     pt="Carregar",  ru="Загрузить", zh="加载", ar="تحميل",  ja="読み込む" },
    language_label= { en="Language", tr="Dil", es="Idioma",   fr="Langue",      de="Sprache",   pt="Idioma",    ru="Язык",      zh="语言", ar="اللغة",  ja="言語" },
    ok_btn        = { en="OK",    tr="Tamam",  es="Aceptar",  fr="OK",          de="OK",        pt="OK",        ru="ОК",        zh="确定", ar="موافق",  ja="OK" },
    dialog_title  = { en="Alert", tr="Uyari",  es="Alerta",   fr="Alerte",      de="Hinweis",   pt="Alerta",    ru="Уведомление", zh="提示", ar="تنبيه", ja="アラート" },
    incomplete_lang={ en="(incomplete)", tr="(eksik)", es="(incompleto)", fr="(incomplet)",
                      de="(unvollständig)", pt="(incompleto)", ru="(неполный)", zh="(不完整)", ar="(غير مكتمل)", ja="(不完全)" },
    theme_label   = { en="Theme",  tr="Tema",  es="Tema",     fr="Thème",       de="Thema",     pt="Tema",      ru="Тема",      zh="主题", ar="السمة",  ja="テーマ" },
}

local function T(key)
    local tbl = INTERNAL[key]
    if not tbl then warn("[EcrinVeil] Unknown internal key: " .. tostring(key)); return key end
    return tbl[EcrinVeil._lang] or tbl["en"] or key
end

-- Theme system
local THEMES = {
    dark = {
        bg          = Color3.fromRGB(0,   0,   0  ),
        bgElevated  = Color3.fromRGB(28,  28,  30 ),
        bgSecondary = Color3.fromRGB(18,  18,  20 ),
        bgTertiary  = Color3.fromRGB(10,  10,  12 ),
        fill        = Color3.fromRGB(44,  44,  46 ),
        fillSecond  = Color3.fromRGB(58,  58,  60 ),
        separator   = Color3.fromRGB(56,  56,  58 ),
        blue        = Color3.fromRGB(10,  132, 255),
        green       = Color3.fromRGB(48,  209, 88 ),
        indigo      = Color3.fromRGB(94,  92,  230),
        orange      = Color3.fromRGB(255, 159, 10 ),
        pink        = Color3.fromRGB(255, 55,  95 ),
        purple      = Color3.fromRGB(191, 90,  242),
        red         = Color3.fromRGB(255, 69,  58 ),
        teal        = Color3.fromRGB(100, 210, 255),
        yellow      = Color3.fromRGB(255, 214, 10 ),
        cyan        = Color3.fromRGB(50,  173, 230),
        l1          = Color3.fromRGB(255, 255, 255),
        l2          = Color3.fromRGB(152, 152, 157),
        l3          = Color3.fromRGB(72,  72,  74 ),
        l4          = Color3.fromRGB(44,  44,  46 ),
        overlayAlpha = 0.55,
        winAlpha     = 0,
    },
    midnight = {
        bg          = Color3.fromRGB(0,   0,   0  ),
        bgElevated  = Color3.fromRGB(10,  12,  20 ),
        bgSecondary = Color3.fromRGB(6,   8,   16 ),
        bgTertiary  = Color3.fromRGB(3,   4,   10 ),
        fill        = Color3.fromRGB(18,  22,  38 ),
        fillSecond  = Color3.fromRGB(28,  34,  56 ),
        separator   = Color3.fromRGB(36,  42,  72 ),
        blue        = Color3.fromRGB(60,  160, 255),
        green       = Color3.fromRGB(40,  200, 100),
        indigo      = Color3.fromRGB(100, 100, 240),
        orange      = Color3.fromRGB(255, 170, 40 ),
        pink        = Color3.fromRGB(255, 80,  120),
        purple      = Color3.fromRGB(180, 100, 250),
        red         = Color3.fromRGB(255, 80,  70 ),
        teal        = Color3.fromRGB(80,  210, 240),
        yellow      = Color3.fromRGB(255, 220, 40 ),
        cyan        = Color3.fromRGB(60,  190, 240),
        l1          = Color3.fromRGB(220, 230, 255),
        l2          = Color3.fromRGB(130, 145, 185),
        l3          = Color3.fromRGB(60,  70,  110),
        l4          = Color3.fromRGB(28,  34,  56 ),
        overlayAlpha = 0.65,
        winAlpha     = 0,
    },
    slate = {
        bg          = Color3.fromRGB(15,  15,  18 ),
        bgElevated  = Color3.fromRGB(32,  33,  38 ),
        bgSecondary = Color3.fromRGB(22,  23,  28 ),
        bgTertiary  = Color3.fromRGB(14,  15,  18 ),
        fill        = Color3.fromRGB(48,  50,  58 ),
        fillSecond  = Color3.fromRGB(62,  64,  74 ),
        separator   = Color3.fromRGB(60,  62,  72 ),
        blue        = Color3.fromRGB(90,  180, 255),
        green       = Color3.fromRGB(60,  210, 110),
        indigo      = Color3.fromRGB(120, 110, 240),
        orange      = Color3.fromRGB(255, 170, 60 ),
        pink        = Color3.fromRGB(255, 90,  140),
        purple      = Color3.fromRGB(200, 110, 255),
        red         = Color3.fromRGB(255, 90,  80 ),
        teal        = Color3.fromRGB(80,  215, 245),
        yellow      = Color3.fromRGB(255, 220, 50 ),
        cyan        = Color3.fromRGB(70,  195, 240),
        l1          = Color3.fromRGB(235, 238, 245),
        l2          = Color3.fromRGB(155, 162, 180),
        l3          = Color3.fromRGB(80,  85,  100),
        l4          = Color3.fromRGB(48,  50,  58 ),
        overlayAlpha = 0.60,
        winAlpha     = 0,
    },
    ocean = {
        bg          = Color3.fromRGB(0,   8,   20 ),
        bgElevated  = Color3.fromRGB(8,   22,  45 ),
        bgSecondary = Color3.fromRGB(4,   14,  32 ),
        bgTertiary  = Color3.fromRGB(2,   8,   20 ),
        fill        = Color3.fromRGB(14,  35,  65 ),
        fillSecond  = Color3.fromRGB(22,  50,  88 ),
        separator   = Color3.fromRGB(28,  60,  100),
        blue        = Color3.fromRGB(30,  170, 255),
        green       = Color3.fromRGB(30,  210, 140),
        indigo      = Color3.fromRGB(80,  120, 255),
        orange      = Color3.fromRGB(255, 160, 30 ),
        pink        = Color3.fromRGB(255, 70,  140),
        purple      = Color3.fromRGB(160, 100, 255),
        red         = Color3.fromRGB(255, 80,  80 ),
        teal        = Color3.fromRGB(30,  200, 230),
        yellow      = Color3.fromRGB(255, 215, 20 ),
        cyan        = Color3.fromRGB(20,  210, 255),
        l1          = Color3.fromRGB(210, 235, 255),
        l2          = Color3.fromRGB(120, 165, 210),
        l3          = Color3.fromRGB(50,  90,  140),
        l4          = Color3.fromRGB(14,  35,  65 ),
        overlayAlpha = 0.70,
        winAlpha     = 0,
    },
    ember = {
        bg          = Color3.fromRGB(12,  4,   0  ),
        bgElevated  = Color3.fromRGB(32,  14,  8  ),
        bgSecondary = Color3.fromRGB(20,  8,   4  ),
        bgTertiary  = Color3.fromRGB(10,  4,   2  ),
        fill        = Color3.fromRGB(50,  22,  12 ),
        fillSecond  = Color3.fromRGB(68,  32,  18 ),
        separator   = Color3.fromRGB(80,  38,  20 ),
        blue        = Color3.fromRGB(100, 180, 255),
        green       = Color3.fromRGB(80,  210, 100),
        indigo      = Color3.fromRGB(140, 120, 240),
        orange      = Color3.fromRGB(255, 140, 20 ),
        pink        = Color3.fromRGB(255, 80,  110),
        purple      = Color3.fromRGB(200, 100, 240),
        red         = Color3.fromRGB(255, 90,  50 ),
        teal        = Color3.fromRGB(60,  210, 200),
        yellow      = Color3.fromRGB(255, 210, 30 ),
        cyan        = Color3.fromRGB(60,  190, 230),
        l1          = Color3.fromRGB(255, 235, 220),
        l2          = Color3.fromRGB(185, 145, 125),
        l3          = Color3.fromRGB(100, 65,  45 ),
        l4          = Color3.fromRGB(50,  22,  12 ),
        overlayAlpha = 0.60,
        winAlpha     = 0,
    },
}

local C = {}
EcrinVeil.Colors       = C
EcrinVeil._activeTheme = "dark"
EcrinVeil._windows     = {}

local _themeFrames    = {}
local _themeCallbacks = {}

local function registerThemeFrame(frame, colorKey, propName)
    propName = propName or "BackgroundColor3"
    table.insert(_themeFrames, { frame = frame, colorKey = colorKey, prop = propName })
end

local function registerThemeCallback(fn)
    table.insert(_themeCallbacks, fn)
end

local function pruneThemeRefs()
    -- Runs on every SetTheme and on window Destroy to avoid unbounded growth.
    local dead = {}
    for i, ref in ipairs(_themeFrames) do
        if not (ref.frame and ref.frame.Parent) then
            table.insert(dead, i)
        end
    end
    for i = #dead, 1, -1 do table.remove(_themeFrames, dead[i]) end

    local deadCb = {}
    for i, fn in ipairs(_themeCallbacks) do
        local ok = pcall(fn)
        if not ok then table.insert(deadCb, i) end
    end
    for i = #deadCb, 1, -1 do table.remove(_themeCallbacks, deadCb[i]) end
end

local function applyThemeToC(themeName)
    local t = THEMES[themeName] or THEMES["dark"]
    for k, v in pairs(t) do C[k] = v end
end
applyThemeToC("dark")

function EcrinVeil:SetTheme(themeName)
    themeName = themeName:lower()
    if not THEMES[themeName] then
        warn("[EcrinVeil] Unknown theme: " .. tostring(themeName))
        return
    end
    self._activeTheme = themeName
    applyThemeToC(themeName)

    local dead = {}
    for i, ref in ipairs(_themeFrames) do
        if ref.frame and ref.frame.Parent then
            local col = C[ref.colorKey]
            if col then pcall(function() ref.frame[ref.prop] = col end) end
        else
            table.insert(dead, i)
        end
    end
    for i = #dead, 1, -1 do table.remove(_themeFrames, dead[i]) end

    -- pruneThemeRefs also re-runs all callbacks
    pruneThemeRefs()

    for _, win in ipairs(self._windows) do
        if win and win._gui and win._gui.Parent then
            pcall(function() win:_ApplyTheme() end)
        end
    end
end

function EcrinVeil:GetThemes()
    local names = {}
    for k in pairs(THEMES) do table.insert(names, k) end
    table.sort(names)
    return names
end

-- Typography
local F = {
    regular  = Enum.Font.Gotham,
    medium   = Enum.Font.GothamMedium,
    semibold = Enum.Font.GothamSemibold,
    bold     = Enum.Font.GothamBold,
    heavy    = Enum.Font.GothamBlack,
}
local SZ = {
    largeTitle=34, title1=28, title2=22, title3=20,
    headline=17, body=17, callout=16, subhead=15,
    footnote=13, caption1=12, caption2=11,
}

-- Animation helpers
local function spr(t)  return TweenInfo.new(t or 0.45, Enum.EasingStyle.Back,  Enum.EasingDirection.Out) end
local function eOut(t) return TweenInfo.new(t or 0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out) end
local function eIn(t)  return TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)  end

local function tw(o, i, p) TS:Create(o, i, p):Play() end

-- Widget constructors
local function inst(cls, props, parent)
    local i = Instance.new(cls)
    if i:IsA("GuiObject") then i.BorderSizePixel = 0 end
    for k, v in pairs(props or {}) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function crn(p, r)
    local c = inst("UICorner", { CornerRadius = UDim.new(0, r or 12) })
    c.Parent = p; return c
end
local function strk(p, col, thick, trans)
    local s = inst("UIStroke", { Color = col or C.separator, Thickness = thick or 0.5, Transparency = trans or 0 })
    s.Parent = p; return s
end
local function pad(p, t, r, b, l)
    local u = inst("UIPadding", {
        PaddingTop    = UDim.new(0, t or 0), PaddingRight  = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0), PaddingLeft   = UDim.new(0, l or 0),
    })
    u.Parent = p; return u
end
local function ll(p, dir, gap, ha, va)
    local l = inst("UIListLayout", {
        FillDirection       = dir or Enum.FillDirection.Vertical,
        SortOrder           = Enum.SortOrder.LayoutOrder,
        Padding             = UDim.new(0, gap or 0),
        HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
        VerticalAlignment   = va or Enum.VerticalAlignment.Top,
    })
    l.Parent = p; return l
end
local function frm(props, parent)
    local f = inst("Frame", props, parent)
    if not props.BackgroundTransparency then f.BackgroundTransparency = 1 end
    return f
end
local function lbl(props, parent)
    local l = inst("TextLabel", props, parent)
    l.BackgroundTransparency = 1; l.TextWrapped = true; return l
end
local function btn(props, parent)
    local b = inst("TextButton", props, parent); b.AutoButtonColor = false; return b
end

-- press() accepts:
--   string  -> key into C table, re-evaluated each time (theme-safe)
--   Color3  -> used directly
--   function -> called each time
local function press(obj, normKey, pressedKey, cb)
    local function rc(k)
        if type(k) == "function" then return k()
        elseif type(k) == "string" then return C[k]
        else return k end
    end
    local pressing = false
    obj.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            pressing = true
            tw(obj, eOut(0.07), { BackgroundColor3 = rc(pressedKey) })
        end
    end)
    local function restore()
        if not pressing then return end
        pressing = false
        tw(obj, eOut(0.15), { BackgroundColor3 = rc(normKey) })
    end
    obj.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then restore() end
    end)
    obj.MouseLeave:Connect(function()
        pressing = false
        tw(obj, eOut(0.15), { BackgroundColor3 = rc(normKey) })
    end)
    if cb then obj.MouseButton1Click:Connect(cb) end
end

-- Icons (text stand-ins, replace with ImageLabels if you have asset IDs)
local ICONS = {
    zap="!", settings="*", target="o", user="@", check="v", x="x",
    plus="+", minus="-", search="?", chevronDown="v", chevronRight=">",
    chevronUp="^", info="i", warning="!", home="H", star="*", heart="+",
    lock="#", refresh="~", trash="x", edit="/", download="d", upload="u",
    menu="=", eye="o", copy="c", link="o", bolt="!", shield="s", clock="t",
    bell="b", flag="f", tag="g", key="k", globe="O",
}
local function ic(name) return ICONS[name] or "." end

-- Custom cursor system
-- Shapes: "heart" | "dot" | "ring" | "cross" | "square"
-- Each builder returns a root frame parented to the cursor ScreenGui.
-- The hotspot offset tells press() where the actual click point is relative
-- to the frame's top-left corner, so we can subtract it from mouse position.
local _cursorGui    = nil
local _cursorFrame  = nil
local _cursorConn   = nil
local _cursorRef    = 0
local _cursorShape  = "heart"

-- Hotspot offsets per shape: {x, y} in pixels from frame top-left.
-- This is what gets subtracted so the visual tip lines up with the real click.
local CURSOR_HOTSPOT = {
    heart  = { x = 9,  y = 9  }, -- center of the heart
    dot    = { x = 7,  y = 7  }, -- center of the circle
    ring   = { x = 8,  y = 8  }, -- center of the ring
    cross  = { x = 8,  y = 8  }, -- intersection
    square = { x = 7,  y = 7  }, -- center of the square
}

local CURSOR_SHAPES = {
    heart = function(parent)
        local SIZE = 18
        local root = frm({ Size = UDim2.new(0, SIZE, 0, SIZE), BackgroundTransparency = 1, ZIndex = 9999 }, parent)
        local l = frm({ Size = UDim2.new(0,12,0,12), Position = UDim2.new(0,0,0,0),
            BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0, ZIndex = 9999 }, root)
        crn(l, 6); strk(l, Color3.new(0,0,0), 1, 0)
        local r = frm({ Size = UDim2.new(0,12,0,12), Position = UDim2.new(0,6,0,0),
            BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0, ZIndex = 9999 }, root)
        crn(r, 6); strk(r, Color3.new(0,0,0), 1, 0)
        local b = frm({ Size = UDim2.new(0,13,0,13), Position = UDim2.new(0,2.5,0,6),
            BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0, Rotation = 45, ZIndex = 9998 }, root)
        strk(b, Color3.new(0,0,0), 1, 0)
        return root
    end,
    dot = function(parent)
        local S = 14
        local root = frm({ Size = UDim2.new(0,S,0,S),
            BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0, ZIndex = 9999 }, parent)
        crn(root, S / 2); strk(root, Color3.new(0,0,0), 1.5, 0)
        return root
    end,
    ring = function(parent)
        local S = 16
        local root = frm({ Size = UDim2.new(0,S,0,S), BackgroundTransparency = 1, ZIndex = 9999 }, parent)
        strk(root, Color3.new(1,1,1), 2, 0); crn(root, S / 2)
        local d = frm({ Size = UDim2.new(0,4,0,4), Position = UDim2.new(0.5,-2,0.5,-2),
            BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0, ZIndex = 10000 }, root)
        crn(d, 2)
        return root
    end,
    cross = function(parent)
        local root = frm({ Size = UDim2.new(0,16,0,16), BackgroundTransparency = 1, ZIndex = 9999 }, parent)
        local h = frm({ Size = UDim2.new(1,0,0,3), Position = UDim2.new(0,0,0.5,-1.5),
            BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0, ZIndex = 9999 }, root)
        crn(h, 1); strk(h, Color3.new(0,0,0), 0.5, 0)
        local v = frm({ Size = UDim2.new(0,3,1,0), Position = UDim2.new(0.5,-1.5,0,0),
            BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0, ZIndex = 9999 }, root)
        crn(v, 1); strk(v, Color3.new(0,0,0), 0.5, 0)
        return root
    end,
    square = function(parent)
        local S = 14
        local root = frm({ Size = UDim2.new(0,S,0,S),
            BackgroundColor3 = Color3.new(1,1,1), BackgroundTransparency = 0, ZIndex = 9999 }, parent)
        crn(root, 3); strk(root, Color3.new(0,0,0), 1.5, 0)
        return root
    end,
}

local function _placeCursor(x, y)
    if not _cursorFrame or not _cursorFrame.Parent then return end
    local hs = CURSOR_HOTSPOT[_cursorShape] or { x = 0, y = 0 }
    _cursorFrame.Position = UDim2.new(0, x - hs.x, 0, y - hs.y)
end

local function _buildCursorShape()
    if not _cursorGui then return end
    if _cursorFrame then _cursorFrame:Destroy(); _cursorFrame = nil end
    local builder = CURSOR_SHAPES[_cursorShape] or CURSOR_SHAPES.heart
    _cursorFrame = builder(_cursorGui)
    -- IgnoreGuiInset=false means the gui already lives in inset-adjusted space,
    -- so GetMouseLocation (which returns raw screen coords) needs the inset
    -- subtracted once here for the initial placement.
    local mp = UIS:GetMouseLocation()
    local insetY = GuiService:GetGuiInset().Y
    _placeCursor(mp.X, mp.Y - insetY)
end

local function _buildCursorGui()
    if _cursorGui and _cursorGui.Parent then return end

    -- IgnoreGuiInset=false: Roblox shifts the gui down by the top-bar height
    -- automatically, so inp.Position from InputChanged is already in the same
    -- coordinate space as the gui — no manual subtraction needed there.
    _cursorGui = inst("ScreenGui", {
        Name           = "EV_Cursor",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = false,
        DisplayOrder   = 9999,
    }, plr.PlayerGui)

    _buildCursorShape()

    _cursorConn = UIS.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement then
            _placeCursor(inp.Position.X, inp.Position.Y)
        end
    end)
end

function EcrinVeil:SetCursor(shape)
    shape = tostring(shape):lower()
    if not CURSOR_SHAPES[shape] then
        warn("[EcrinVeil] Unknown cursor shape: " .. shape)
        return
    end
    _cursorShape = shape
    if _cursorGui and _cursorGui.Parent then _buildCursorShape() end
end

function EcrinVeil:GetCursorShapes()
    local s = {}
    for k in pairs(CURSOR_SHAPES) do table.insert(s, k) end
    table.sort(s); return s
end

local function _showCustomCursor()
    _cursorRef = _cursorRef + 1
    _buildCursorGui()
    if _cursorFrame then _cursorFrame.Visible = true end
    pcall(function() UIS.MouseIconEnabled = false end)
    pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
end

local function _hideCustomCursor()
    _cursorRef = math.max(0, _cursorRef - 1)
    if _cursorRef > 0 then return end
    if _cursorFrame then _cursorFrame.Visible = false end
    pcall(function() UIS.MouseIconEnabled = true end)
    if _cursorConn then _cursorConn:Disconnect(); _cursorConn = nil end
    if _cursorGui then _cursorGui:Destroy(); _cursorGui = nil end
    _cursorFrame = nil
end

-- Notify
local _toastSlots = {}
local MAX_TOASTS  = 5
local TOAST_H     = 44
local TOAST_GAP   = 6

local function getNotifyGui()
    local e = plr.PlayerGui:FindFirstChild("EV_Notify")
    if e then return e end
    return inst("ScreenGui", {
        Name = "EV_Notify", ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true, DisplayOrder = 999,
    }, plr.PlayerGui)
end

function EcrinVeil:Notify(opts)
    opts = opts or {}
    local title   = opts.Title
    local content = opts.Content or ""
    local sub     = opts.SubContent
    local dur     = opts.Duration or 4
    local kind    = opts.Kind or "info"
    local accent  = ({ info = C.blue, success = C.green, warn = C.orange, error = C.red })[kind] or C.blue

    local slot = nil
    for i = 1, MAX_TOASTS do
        if not _toastSlots[i] then slot = i; break end
    end
    if not slot then slot = MAX_TOASTS end
    _toastSlots[slot] = true

    local hasTitle   = title and title ~= ""
    local hasContent = content ~= "" and content ~= title
    local hasSub     = sub and sub ~= ""
    local h          = (hasTitle and (hasContent or hasSub)) and 60 or TOAST_H
    local yT         = 14 + (slot - 1) * (h + TOAST_GAP)

    local longest = title or content or ""
    if hasContent and #content > #longest then longest = content end
    local W = math.max(160, math.min(320, #longest * 6.4 + 56))

    local gui  = getNotifyGui()
    local pill = frm({
        Size = UDim2.new(0, W, 0, h),
        Position = UDim2.new(0.5, -W / 2, 0, -h - 10),
        BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0, ZIndex = 100,
    }, gui)
    crn(pill, h / 2); strk(pill, C.separator, 0.5, 0.4)

    local DOT_S = 8
    local accentBar = frm({
        Size = UDim2.new(0, DOT_S, 0, DOT_S),
        Position = UDim2.new(0, 10, 0.5, -DOT_S / 2),
        BackgroundColor3 = accent, BackgroundTransparency = 0, ZIndex = 101,
    }, pill)
    crn(accentBar, DOT_S / 2)

    local tx = 24
    if hasTitle then
        lbl({ Size = UDim2.new(1, -tx-8, 0, 18), Position = UDim2.new(0, tx, 0, 8),
            Text = title, TextColor3 = C.l1, TextSize = SZ.footnote, Font = F.semibold,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101 }, pill)
        if hasContent then
            lbl({ Size = UDim2.new(1, -tx-8, 0, 14), Position = UDim2.new(0, tx, 0, 28),
                Text = content, TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101 }, pill)
        end
        if hasSub then
            lbl({ Size = UDim2.new(1, -tx-8, 0, 12),
                Position = UDim2.new(0, tx, 0, hasContent and 44 or 28),
                Text = sub, TextColor3 = C.l3, TextSize = SZ.caption2, Font = F.regular,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101 }, pill)
        end
    else
        lbl({ Size = UDim2.new(1, -tx-8, 1, 0), Position = UDim2.new(0, tx, 0, 0),
            Text = content, TextColor3 = C.l1, TextSize = SZ.footnote, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101 }, pill)
    end

    tw(pill, spr(0.46), { Position = UDim2.new(0.5, -W / 2, 0, yT) })

    local dismissed = false
    local function dismiss()
        if dismissed then return end; dismissed = true
        _toastSlots[slot] = false
        tw(pill, eIn(0.20), { Position = UDim2.new(0.5, -W / 2, 0, -h - 10) })
        task.delay(0.22, function() if pill and pill.Parent then pill:Destroy() end end)
    end
    if dur then task.delay(dur, function() dismiss() end) end
    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 102 }, pill).MouseButton1Click:Connect(dismiss)
    return { Dismiss = dismiss }
end

-- Dialog
function EcrinVeil:Dialog(opts)
    opts = opts or {}
    local title      = opts.Title or T("dialog_title")
    local content    = opts.Content or ""
    local contentStr = resolveText(content)
    local buttons    = opts.Buttons or { { Title = T("ok_btn") } }

    local gui = inst("ScreenGui", {
        Name = "EV_Dlg_" .. tick(), ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true, DisplayOrder = 998,
    }, plr.PlayerGui)

    local overlay = frm({ Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 1, ZIndex = 90 }, gui)
    tw(overlay, eOut(0.20), { BackgroundTransparency = 0.55 })

    local DW = 270; local BTN_H = 46
    local HDR_H = contentStr ~= "" and 96 or 68
    local dlgH  = HDR_H + BTN_H * #buttons

    local box = frm({
        Size = UDim2.new(0, DW * 0.85, 0, dlgH * 0.85),
        Position = UDim2.new(0.5, -DW * 0.425, 0.5, -dlgH * 0.425),
        BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0, ZIndex = 91,
    }, gui)
    crn(box, 14)
    tw(box, spr(0.32), { Size = UDim2.new(0, DW, 0, dlgH), Position = UDim2.new(0.5, -DW/2, 0.5, -dlgH/2) })

    lbl({ Size = UDim2.new(1,-32,0,22), Position = UDim2.new(0,16,0,18),
        Text = resolveText(title), TextColor3 = C.l1, TextSize = SZ.headline, Font = F.semibold,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 92 }, box)

    if contentStr ~= "" then
        lbl({ Size = UDim2.new(1,-32,0,40), Position = UDim2.new(0,16,0,44),
            Text = contentStr, TextColor3 = C.l2, TextSize = SZ.footnote, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 92 }, box)
    end

    frm({ Size = UDim2.new(1,0,0,0.5), Position = UDim2.new(0,0,0,HDR_H),
        BackgroundColor3 = C.separator, BackgroundTransparency = 0, ZIndex = 92 }, box)

    local function closeDialog()
        tw(overlay, eIn(0.18), { BackgroundTransparency = 1 })
        tw(box, eIn(0.18), {
            Size = UDim2.new(0, DW*0.85, 0, dlgH*0.85),
            Position = UDim2.new(0.5, -DW*0.425, 0.5, -dlgH*0.425),
        })
        task.delay(0.2, function() if gui and gui.Parent then gui:Destroy() end end)
    end

    for i, bDef in ipairs(buttons) do
        local yOff = HDR_H + BTN_H * (i - 1)
        local isD  = bDef.Style == "destructive"
        local isC  = bDef.Style == "cancel"
        local tc   = isD and C.red or isC and C.l2 or C.blue
        if i > 1 then
            frm({ Size = UDim2.new(1,0,0,0.5), Position = UDim2.new(0,0,0,yOff),
                BackgroundColor3 = C.separator, BackgroundTransparency = 0, ZIndex = 92 }, box)
        end
        local b = btn({
            Size = UDim2.new(1, 0, 0, BTN_H), Position = UDim2.new(0, 0, 0, yOff),
            BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0,
            Text = resolveText(bDef.Title or T("ok_btn")), TextColor3 = tc,
            TextSize = SZ.callout, Font = isC and F.regular or F.semibold, ZIndex = 92,
        }, box)
        local isFirst = i == 1
        local isLast  = i == #buttons
        if isFirst or isLast then
            crn(b, 14)
            if isFirst and not isLast then
                frm({ Size = UDim2.new(1,0,0,14), Position = UDim2.new(0,0,1,-14),
                    BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0, ZIndex = 93 }, b)
            elseif isLast and not isFirst then
                frm({ Size = UDim2.new(1,0,0,14), Position = UDim2.new(0,0,0,0),
                    BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0, ZIndex = 93 }, b)
            end
        end
        press(b, "bgElevated", "fillSecond", function()
            closeDialog(); if bDef.Callback then bDef.Callback() end
        end)
    end
    return { Close = closeDialog }
end

-- Forward declarations
local Tab    = {}; Tab.__index    = Tab
local Window = {}; Window.__index = Window

local SIDEBAR_W  = 160
local HDR_H_DEF  = 48
local TAB_ITEM_H = 40

-- Window
function EcrinVeil:CreateWindow(opts)
    opts = opts or {}
    local self        = setmetatable({}, Window)
    self._opts        = opts
    self._tabs        = {}
    self._activeTab   = nil
    self._visible     = true
    self._minimizeKey = opts.MinimizeKey or Enum.KeyCode.RightShift

    self._gui = inst("ScreenGui", {
        Name           = "EcrinVeil_" .. (type(opts.Title) == "string" and opts.Title or "Win"),
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
        DisplayOrder   = 100,
    }, plr.PlayerGui)

    self:_Build()
    self:_SetupInput()
    _showCustomCursor()
    table.insert(EcrinVeil._windows, self)
    return self
end

function Window:_Build()
    local opts = self._opts
    local W = opts.Width  or 580
    local H = opts.Height or 460

    self._overlay = frm({
        Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 1, ZIndex = 10,
    }, self._gui)
    tw(self._overlay, eOut(0.22), { BackgroundTransparency = C.overlayAlpha or 0.55 })

    local startPos  = UDim2.new(0.5, -W/2, 1, 20)
    local endPos    = UDim2.new(0.5, -W/2, 0.5, -H/2)
    self._winEndPos = endPos
    self._winW = W; self._winH = H

    self._win = frm({
        Name = "Window", Size = UDim2.new(0, W, 0, H), Position = startPos,
        BackgroundColor3 = C.bgSecondary, BackgroundTransparency = 0,
        ZIndex = 11, ClipsDescendants = true,
    }, self._gui)
    crn(self._win, 16)
    tw(self._win, spr(0.48), { Position = endPos })

    local HDR_H = HDR_H_DEF
    self._header = frm({
        Size = UDim2.new(1, 0, 0, HDR_H), BackgroundColor3 = C.bgElevated,
        BackgroundTransparency = 0, ZIndex = 12,
    }, self._win)
    -- Square off the bottom corners of the header so it tiles flush with the body.
    frm({
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16),
        BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0, ZIndex = 12,
    }, self._header)
    crn(self._header, 16)

    self._titleLbl = inst("TextLabel", {
        Size = UDim2.new(1, -150, 0, 20),
        Position = UDim2.new(0, 16, 0, opts.Subtitle and 8 or 14),
        Text = resolveText(opts.Title or "EcrinVeil"),
        TextColor3 = C.l1, TextSize = SZ.subhead, Font = F.semibold,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13,
        BackgroundTransparency = 1, TextWrapped = true,
    }, self._header)
    trackLabel(self._titleLbl, opts.Title)

    if opts.Subtitle then
        self._subLbl = inst("TextLabel", {
            Size = UDim2.new(1, -150, 0, 14), Position = UDim2.new(0, 16, 0, 28),
            Text = resolveText(opts.Subtitle),
            TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13,
            BackgroundTransparency = 1, TextWrapped = true,
        }, self._header)
        trackLabel(self._subLbl, opts.Subtitle)
    end

    local btnArea = frm({
        Size = UDim2.new(0, 130, 0, HDR_H), Position = UDim2.new(1, -134, 0, 0),
        BackgroundTransparency = 1, ZIndex = 13,
    }, self._header)
    ll(btnArea, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    pad(btnArea, 0, 10, 0, 0)

    local closeBtn = btn({
        Size = UDim2.new(0, 28, 0, 28), BackgroundColor3 = C.fill, BackgroundTransparency = 0,
        Text = "x", TextColor3 = C.l2, TextSize = 13, Font = F.bold, ZIndex = 14, LayoutOrder = 2,
    }, btnArea)
    crn(closeBtn, 14)
    press(closeBtn, "fill", "fillSecond", function() self:Destroy() end)

    local minBtn = btn({
        Size = UDim2.new(0, 60, 0, 28), BackgroundColor3 = C.fill, BackgroundTransparency = 0,
        Text = "- RShift", TextColor3 = C.l3, TextSize = 10, Font = F.medium, ZIndex = 14, LayoutOrder = 1,
    }, btnArea)
    crn(minBtn, 14)
    press(minBtn, "fill", "fillSecond", function() self:Hide() end)

    frm({
        Size = UDim2.new(1, 0, 0, 0.5), Position = UDim2.new(0, 0, 1, -0.5),
        BackgroundColor3 = C.separator, BackgroundTransparency = 0, ZIndex = 13,
    }, self._header)

    local bodyY = HDR_H
    local bodyH = H - bodyY

    self._sidebar = frm({
        Size = UDim2.new(0, SIDEBAR_W, 0, bodyH), Position = UDim2.new(0, 0, 0, bodyY),
        BackgroundColor3 = C.bgTertiary, BackgroundTransparency = 0, ZIndex = 12,
    }, self._win)
    frm({
        Size = UDim2.new(0, 0.5, 1, 0), Position = UDim2.new(1, -0.5, 0, 0),
        BackgroundColor3 = C.separator, BackgroundTransparency = 0, ZIndex = 13,
    }, self._sidebar)

    self._tabList = inst("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.separator,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 13,
    }, self._sidebar)
    pad(self._tabList, 8, 6, 8, 6)
    self._tabListLayout = ll(self._tabList, Enum.FillDirection.Vertical, 3)
    self._tabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self._tabList.CanvasSize = UDim2.new(0, 0, 0, self._tabListLayout.AbsoluteContentSize.Y + 16)
    end)

    self._contentArea = inst("ScrollingFrame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -SIDEBAR_W, 0, bodyH), Position = UDim2.new(0, SIDEBAR_W, 0, bodyY),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.separator,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 12, ClipsDescendants = true,
    }, self._win)
    pad(self._contentArea, 14, 16, 20, 16)
    self._contentLayout = ll(self._contentArea, Enum.FillDirection.Vertical, 8)
    self._contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        self._contentArea.CanvasSize = UDim2.new(0, 0, 0, self._contentLayout.AbsoluteContentSize.Y + 32)
    end)

    self:_SetupDrag()
end

function Window:_ApplyTheme()
    if not self._win or not self._win.Parent then return end
    local t = THEMES[EcrinVeil._activeTheme] or THEMES["dark"]
    if self._overlay then
        self._overlay.BackgroundTransparency = self._visible and (t.overlayAlpha or 0.55) or 1
    end
    if self._win     then self._win.BackgroundColor3  = t.bgSecondary end
    if self._header  then
        self._header.BackgroundColor3 = t.bgElevated
        for _, ch in ipairs(self._header:GetChildren()) do
            if ch:IsA("Frame") and ch.Size.Y.Offset > 1 then
                ch.BackgroundColor3 = t.bgElevated
            end
        end
    end
    if self._titleLbl then self._titleLbl.TextColor3 = t.l1 end
    if self._subLbl   then self._subLbl.TextColor3   = t.l2 end
    if self._sidebar  then self._sidebar.BackgroundColor3 = t.bgTertiary end
    for _, tab in ipairs(self._tabs) do
        pcall(function() tab:_RefreshTheme() end)
    end
end

function Window:_SetupDrag()
    local drag, ds, sp = false, nil, nil
    self._header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = i.Position; sp = self._win.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d  = i.Position - ds
            self._win.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
            self._winEndPos    = self._win.Position
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)
end

EcrinVeil._listeningKeybind = 0

function Window:_SetupInput()
    UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if EcrinVeil._listeningKeybind > 0 then return end
        if i.KeyCode == self._minimizeKey then self:Toggle() end
    end)
end

function Window:Toggle() if self._visible then self:Hide() else self:Show() end end

function Window:Hide()
    if not self._visible then return end; self._visible = false
    local W = self._win.AbsoluteSize.X
    tw(self._overlay, eIn(0.20), { BackgroundTransparency = 1 })
    tw(self._win, eIn(0.24), { Position = UDim2.new(0.5, -W/2, 1, 20) })
    task.delay(0.26, function()
        if self._win     then self._win.Visible     = false end
        if self._overlay then self._overlay.Visible = false end
    end)
    _hideCustomCursor()
end

function Window:Show()
    if self._visible then return end; self._visible = true
    if self._win     then self._win.Visible     = true end
    if self._overlay then self._overlay.Visible = true end
    tw(self._overlay, eOut(0.22), { BackgroundTransparency = C.overlayAlpha or 0.55 })
    tw(self._win, spr(0.45), { Position = self._winEndPos })
    _showCustomCursor()
end

function Window:SetTitle(str)
    if self._titleLbl then
        self._titleLbl.Text = resolveText(str)
        for i = #EcrinVeil._labelRefs, 1, -1 do
            if EcrinVeil._labelRefs[i].label == self._titleLbl then
                table.remove(EcrinVeil._labelRefs, i)
            end
        end
        trackLabel(self._titleLbl, str)
    end
end

function Window:SelectTab(i)
    local t = self._tabs[i]; if t then t:_Select() end
end

function Window:AddTab(opts)
    opts = opts or {}
    local tab = setmetatable({
        _win      = self,
        _opts     = opts,
        _elements = {},
        _order    = #self._tabs + 1,
        _selected = false,
        _enabled  = true,
        _panels   = {},
    }, Tab)
    table.insert(self._tabs, tab)
    tab:_BuildBtn()
    if #self._tabs == 1 then tab:_Select() end
    return tab
end

function Window:Destroy()
    for i, w in ipairs(EcrinVeil._windows) do
        if w == self then table.remove(EcrinVeil._windows, i); break end
    end
    pruneThemeRefs()
    _hideCustomCursor()
    if self._gui then self._gui:Destroy() end
end

-- Tab
function Tab:_BuildBtn()
    local list = self._win._tabList
    local ttl  = resolveText(self._opts.Title or "Tab")
    local icn  = self._opts.Icon

    self._btn = btn({
        Size = UDim2.new(1, 0, 0, TAB_ITEM_H), BackgroundColor3 = C.fill,
        BackgroundTransparency = 1, Text = "", ZIndex = 14, LayoutOrder = self._order,
    }, list)
    crn(self._btn, 8)

    local inner = frm({
        Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1, ZIndex = 15,
    }, self._btn)
    ll(inner, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    if icn and icn ~= "" then
        self._iconLbl = lbl({
            Size = UDim2.new(0, 16, 0, 16), Text = ic(icn), TextColor3 = C.l3,
            TextSize = 13, Font = F.bold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 15,
        }, inner)
    end

    self._txtLbl = lbl({
        Size = UDim2.new(1, -(icn and 22 or 0), 1, 0), Text = ttl, TextColor3 = C.l2,
        TextSize = SZ.caption1, Font = F.medium,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 15,
    }, inner)

    if type(self._opts.Title) == "table" then trackLabel(self._txtLbl, self._opts.Title) end

    self._selBar = frm({
        Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, 0, 0.2, 0),
        BackgroundColor3 = C.blue, BackgroundTransparency = 1, ZIndex = 15,
    }, self._btn)
    crn(self._selBar, 2)

    self._btn.MouseButton1Click:Connect(function()
        if not self._enabled then return end
        self:_Select()
    end)
end

function Tab:_RefreshTheme()
    if self._selected then
        if self._btn     then self._btn.BackgroundColor3  = C.fill  end
        if self._txtLbl  then self._txtLbl.TextColor3     = C.l1    end
        if self._iconLbl then self._iconLbl.TextColor3    = C.blue  end
        if self._selBar  then self._selBar.BackgroundColor3 = C.blue end
    else
        if self._txtLbl  then self._txtLbl.TextColor3  = C.l2 end
        if self._iconLbl then self._iconLbl.TextColor3 = C.l3 end
    end
end

function Tab:_Select()
    if not self._enabled then return end
    local w = self._win
    for _, t in ipairs(w._tabs) do if t ~= self then t:_Deselect() end end
    w._activeTab = self; self._selected = true

    tw(self._btn,    eOut(0.15), { BackgroundTransparency = 0 })
    self._txtLbl.Font = F.semibold
    tw(self._txtLbl, eOut(0.15), { TextColor3 = C.l1 })
    if self._iconLbl then tw(self._iconLbl, eOut(0.15), { TextColor3 = C.blue }) end
    tw(self._selBar, eOut(0.18), { BackgroundTransparency = 0 })
    self:_ShowContent()
end

function Tab:_Deselect()
    self._selected = false
    tw(self._btn,    eOut(0.15), { BackgroundTransparency = 1 })
    self._txtLbl.Font = F.medium
    tw(self._txtLbl, eOut(0.15), { TextColor3 = C.l2 })
    if self._iconLbl then tw(self._iconLbl, eOut(0.15), { TextColor3 = C.l3 }) end
    tw(self._selBar, eOut(0.15), { BackgroundTransparency = 1 })
    if self._container then self._container.Visible = false end
    if self._panels then
        for _, fn in ipairs(self._panels) do pcall(fn) end
        self._panels = {}
    end
end

function Tab:_ShowContent()
    if not self._container then
        self._container = frm({
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, ZIndex = 12, LayoutOrder = self._order,
        }, self._win._contentArea)
        ll(self._container, Enum.FillDirection.Vertical, 8)
    end
    for _, ch in ipairs(self._win._contentArea:GetChildren()) do
        if ch:IsA("Frame") then ch.Visible = (ch == self._container) end
    end
    self._container.Visible = true
end

function Tab:SetBadge(n)
    if n and n > 0 then
        if not self._badge then
            self._badge = frm({
                Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(1, -4, 0, 4),
                BackgroundColor3 = C.red, BackgroundTransparency = 0, ZIndex = 16,
            }, self._btn)
            crn(self._badge, 9)
            self._badgeLbl = lbl({
                Size = UDim2.new(1, 0, 1, 0), TextColor3 = C.l1,
                TextSize = SZ.caption2, Font = F.bold,
                TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 17,
            }, self._badge)
        end
        self._badge.Visible = true; self._badgeLbl.Text = tostring(n)
    elseif self._badge then
        self._badge.Visible = false
    end
end

function Tab:SetEnabled(enabled)
    self._enabled = enabled
    local alpha = enabled and 1 or 0.35
    tw(self._txtLbl,  eOut(0.18), { TextTransparency = 1 - alpha })
    if self._iconLbl then tw(self._iconLbl, eOut(0.18), { TextTransparency = 1 - alpha }) end
    if not enabled and self._selected then
        for _, t in ipairs(self._win._tabs) do
            if t ~= self and t._enabled then t:_Select(); break end
        end
    end
end

-- Element helpers
local ROW_H = 48

local function getContainer(tab)
    if not tab._container then tab:_ShowContent() end
    return tab._container
end

local function secFrame(parent, order)
    local f = frm({
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.fill, BackgroundTransparency = 0,
        ZIndex = 13, LayoutOrder = order,
    }, parent)
    crn(f, 10)
    registerThemeFrame(f, "fill")
    return f
end

local function rowFrame(parent, order, hasDesc)
    local h = hasDesc and 62 or ROW_H
    local f = frm({
        Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.fill,
        BackgroundTransparency = 0, ZIndex = 14, LayoutOrder = order,
    }, parent)
    registerThemeFrame(f, "fill")
    return f, h
end

local function rowLabels(parent, title, desc, xOff)
    xOff = xOff or 14
    if desc then
        local tL = lbl({
            Size = UDim2.new(0.65, -(xOff + 4), 0, 20), Position = UDim2.new(0, xOff, 0, 10),
            Text = resolveText(title), TextColor3 = C.l1, TextSize = SZ.subhead, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
        }, parent)
        trackLabel(tL, title)
        local dL = lbl({
            Size = UDim2.new(1, -(xOff + 4), 0, 28), Position = UDim2.new(0, xOff, 0, 32),
            Text = resolveText(desc), TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
        }, parent)
        trackLabel(dL, desc)
    else
        local tL = lbl({
            Size = UDim2.new(0.6, -xOff, 1, 0), Position = UDim2.new(0, xOff, 0, 0),
            Text = resolveText(title), TextColor3 = C.l1, TextSize = SZ.subhead, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
        }, parent)
        trackLabel(tL, title)
    end
end

local function applyCommonMethods(elem)
    function elem:SetVisible(v)
        if self.frame then self.frame.Visible = v end
    end
    function elem:Destroy()
        if self.frame then self.frame:Destroy(); self.frame = nil end
    end
    return elem
end

-- Paragraph
function Tab:AddParagraph(opts)
    opts = opts or {}
    local cont  = getContainer(self); local order = #self._elements + 1
    local wrap  = frm({
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, ZIndex = 13, LayoutOrder = order,
    }, cont)
    if opts.Title then
        local tL = lbl({
            Size = UDim2.new(1, 0, 0, 18),
            Text = string.upper(resolveText(opts.Title)),
            TextColor3 = C.l2, TextSize = SZ.caption2, Font = F.medium,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14,
        }, wrap)
        trackLabel(tL, opts.Title, function(s) return string.upper(s) end)
    end
    if opts.Content then
        local cL = lbl({
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            Position = opts.Title and UDim2.new(0, 0, 0, 20) or UDim2.new(0, 0, 0, 0),
            Text = resolveText(opts.Content), TextColor3 = C.l2,
            TextSize = SZ.footnote, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14,
        }, wrap)
        trackLabel(cL, opts.Content)
    end
    local elem = { type = "paragraph", frame = wrap }
    applyCommonMethods(elem)
    table.insert(self._elements, elem); return elem
end

-- Separator
function Tab:AddSeparator(opts)
    opts = opts or {}
    local cont  = getContainer(self); local order = #self._elements + 1
    local wrap  = frm({
        Size = UDim2.new(1, 0, 0, opts.Title and 24 or 8),
        BackgroundTransparency = 1, ZIndex = 13, LayoutOrder = order,
    }, cont)
    if opts.Title then
        local sL = lbl({
            Size = UDim2.new(1, 0, 1, 0),
            Text = string.upper(resolveText(opts.Title)),
            TextColor3 = C.l2, TextSize = SZ.caption2, Font = F.medium,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14,
        }, wrap)
        trackLabel(sL, opts.Title, function(s) return string.upper(s) end)
    end
    local elem = { type = "sep", frame = wrap }
    applyCommonMethods(elem)
    table.insert(self._elements, elem); return elem
end

-- StatusRow
function Tab:AddStatusRow(opts)
    opts = opts or {}
    local cont  = getContainer(self); local order = #self._elements + 1
    local sec   = secFrame(cont, order)
    local row   = rowFrame(sec, 1); pad(row, 0, 14, 0, 14)
    rowLabels(row, opts.Label or "—", nil, 0)
    local initVal = type(opts.Value) == "table" and resolveText(opts.Value) or tostring(opts.Value or "—")
    local vl = lbl({
        Size = UDim2.new(0.45, -4, 1, 0), Position = UDim2.new(0.55, 0, 0, 0),
        Text = initVal, TextColor3 = opts.Color or C.l2,
        TextSize = SZ.subhead, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 15,
    }, row)
    local elem = { type = "status", frame = sec, _lbl = vl }
    function elem:SetValue(v, col) vl.Text = tostring(v); if col then vl.TextColor3 = col end end
    applyCommonMethods(elem)
    table.insert(self._elements, elem); return elem
end

-- Button
function Tab:AddButton(opts)
    opts = opts or {}
    local cont    = getContainer(self); local order = #self._elements + 1
    local cb      = opts.Callback or function() end
    local hasDesc = opts.Description and opts.Description ~= ""
    local sec     = secFrame(cont, order)
    local row     = rowFrame(sec, 1, hasDesc); crn(row, 10)
    pad(row, 0, 14, 0, 14)

    local xOff = 0
    if opts.Icon then
        xOff = 26
        lbl({
            Size = UDim2.new(0, 20, 1, 0), Text = ic(opts.Icon),
            TextColor3 = opts.IconColor or C.blue, TextSize = 16, Font = F.bold, ZIndex = 15,
        }, row)
    end

    if opts.Color then
        tw(row, eOut(0.01), { BackgroundColor3 = opts.Color })
        local cL = lbl({
            Size = UDim2.new(1, -28, 1, 0), Position = UDim2.new(0, 14, 0, 0),
            Text = resolveText(opts.Title or "Button"), TextColor3 = C.l1,
            TextSize = SZ.subhead, Font = F.semibold,
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 15,
        }, row)
        trackLabel(cL, opts.Title)
        -- opts.Color is a raw Color3 so we lerp directly; register callback for theme repaints.
        local pressedCol = opts.Color:Lerp(Color3.new(0, 0, 0), 0.16)
        press(row, opts.Color, pressedCol, nil)
        registerThemeCallback(function()
            if row and row.Parent then row.BackgroundColor3 = opts.Color end
        end)
    else
        rowLabels(row, opts.Title or "Button", opts.Description, xOff)
        lbl({
            Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -18, 0, 0),
            Text = ">", TextColor3 = C.l3, TextSize = 14, Font = F.bold, ZIndex = 15,
        }, row)
        press(row, "fill", "fillSecond", nil)
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 16 }, row).MouseButton1Click:Connect(cb)
    local elem = { type = "button", frame = sec }
    applyCommonMethods(elem)
    table.insert(self._elements, elem); return elem
end

-- Toggle
function Tab:AddToggle(id, opts)
    opts = opts or {}
    local cont     = getContainer(self); local order = #self._elements + 1
    local val      = opts.Default == true
    local cb       = opts.Callback or function() end
    local onChange = nil
    local sec      = secFrame(cont, order)
    local row      = rowFrame(sec, 1, opts.Description ~= nil)
    crn(row, 10); pad(row, 0, 14, 0, 14)
    rowLabels(row, opts.Title or "Toggle", opts.Description)

    local SW, SH = 44, 26
    local sbg = frm({
        Size = UDim2.new(0, SW, 0, SH), Position = UDim2.new(1, -(SW + 14), 0.5, -SH / 2),
        BackgroundColor3 = val and C.green or C.l4, BackgroundTransparency = 0, ZIndex = 15,
    }, row)
    crn(sbg, SH / 2)
    registerThemeCallback(function()
        if sbg and sbg.Parent then sbg.BackgroundColor3 = val and C.green or C.l4 end
    end)

    local ks = SH - 4
    local knob = frm({
        Size = UDim2.new(0, ks, 0, ks), Position = UDim2.new(0, val and SW - ks - 2 or 2, 0.5, -ks / 2),
        BackgroundColor3 = C.l1, BackgroundTransparency = 0, ZIndex = 16,
    }, sbg)
    crn(knob, ks / 2); strk(knob, Color3.new(0,0,0), 0.5, 0.7)
    registerThemeFrame(knob, "l1")

    local elem
    local function update(v, anim)
        val = v
        local kx = v and SW - ks - 2 or 2
        if anim then
            tw(knob, spr(0.3),  { Position = UDim2.new(0, kx, 0.5, -ks / 2) })
            tw(sbg,  eOut(0.2), { BackgroundColor3 = v and C.green or C.l4 })
        else
            knob.Position = UDim2.new(0, kx, 0.5, -ks / 2)
            sbg.BackgroundColor3 = v and C.green or C.l4
        end
        if elem then elem.Value = val end
        cb(v); if onChange then onChange(v) end
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 17 }, row).MouseButton1Click:Connect(function()
        update(not val, true)
    end)

    elem = { type = "toggle", frame = sec, Value = val }
    function elem:SetValue(v) update(v, true) end
    function elem:OnChanged(fn) onChange = fn end
    applyCommonMethods(elem)
    table.insert(self._elements, elem)
    if id then EcrinVeil.Options[id] = elem end
    return elem
end

-- Slider
function Tab:AddSlider(id, opts)
    opts = opts or {}
    local cont     = getContainer(self); local order = #self._elements + 1
    local minV     = opts.Min or 0; local maxV = opts.Max or 100
    local rnd      = opts.Rounding or 0
    local val      = opts.Default or minV
    local cb       = opts.Callback or function() end
    local onChange = nil

    local sec = secFrame(cont, order)
    local row = frm({
        Size = UDim2.new(1, 0, 0, opts.Description and 78 or 68),
        BackgroundColor3 = C.fill, BackgroundTransparency = 0, ZIndex = 14, LayoutOrder = 1,
    }, sec)
    crn(row, 10); pad(row, 10, 14, 10, 14)
    registerThemeFrame(row, "fill")

    local tL = lbl({
        Size = UDim2.new(0.7, -4, 0, 20), Position = UDim2.new(0, 0, 0, 0),
        Text = resolveText(opts.Title or "Slider"), TextColor3 = C.l1,
        TextSize = SZ.subhead, Font = F.regular, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
    }, row)
    trackLabel(tL, opts.Title)
    registerThemeFrame(tL, "l1")

    local vLbl = lbl({
        Size = UDim2.new(0.3, -4, 0, 20), Position = UDim2.new(0.7, 4, 0, 0),
        TextColor3 = C.blue, TextSize = SZ.subhead, Font = F.medium,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 15,
    }, row)

    if opts.Description then
        local dL = lbl({
            Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 22),
            Text = resolveText(opts.Description), TextColor3 = C.l2,
            TextSize = SZ.caption1, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
        }, row)
        trackLabel(dL, opts.Description)
    end

    local trkY = opts.Description and 46 or 34
    local trk  = frm({
        Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0, trkY),
        BackgroundColor3 = C.fillSecond, BackgroundTransparency = 0, ZIndex = 15,
    }, row); crn(trk, 2)
    registerThemeFrame(trk, "fillSecond")
    local fillBar = frm({ Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.blue,
        BackgroundTransparency = 0, ZIndex = 16 }, trk); crn(fillBar, 2)
    registerThemeFrame(fillBar, "blue")

    local TH = 18
    local thumb = frm({
        Size = UDim2.new(0, TH, 0, TH), Position = UDim2.new(0, -TH / 2, 0.5, -TH / 2),
        BackgroundColor3 = C.l1, BackgroundTransparency = 0, ZIndex = 17,
    }, trk)
    registerThemeFrame(thumb, "l1")
    crn(thumb, TH / 2); strk(thumb, Color3.new(0,0,0), 0.5, 0.7)

    local function rnd2(v, d) local m = 10^d; return math.floor(v * m + 0.5) / m end
    local function setVal(v, animated)
        v = math.clamp(v, minV, maxV); v = rnd2(v, rnd); val = v
        local pct = (v - minV) / (maxV - minV)
        vLbl.Text = rnd > 0 and string.format("%." .. rnd .. "f", v) or tostring(v)
        if animated then
            TS:Create(fillBar, eOut(0.12), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
            TS:Create(thumb,   eOut(0.12), { Position = UDim2.new(pct, -TH / 2, 0.5, -TH / 2) }):Play()
        else
            fillBar.Size = UDim2.new(pct, 0, 1, 0)
            thumb.Position = UDim2.new(pct, -TH / 2, 0.5, -TH / 2)
        end
        cb(v); if onChange then onChange(v) end
    end
    setVal(val, false)

    local drag = false
    local conns = {}
    table.insert(conns, thumb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end
    end))
    table.insert(conns, UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement then
            local ta   = trk.AbsolutePosition; local trkW = trk.AbsoluteSize.X
            local pct  = math.clamp((i.Position.X - ta.X) / trkW, 0, 1)
            setVal(minV + (maxV - minV) * pct, false)
        end
    end))
    table.insert(conns, UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end))
    table.insert(conns, trk.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local ta   = trk.AbsolutePosition; local trkW = trk.AbsoluteSize.X
            local pct  = math.clamp((i.Position.X - ta.X) / trkW, 0, 1)
            setVal(minV + (maxV - minV) * pct, true)
        end
    end))

    local elem = { type = "slider", frame = sec, Value = val }
    function elem:SetValue(v) setVal(v, true); self.Value = v end
    function elem:OnChanged(fn) onChange = fn end
    function elem:SetVisible(v2) if sec then sec.Visible = v2 end end
    function elem:Destroy()
        for _, c in ipairs(conns) do c:Disconnect() end
        if sec then sec:Destroy(); sec = nil end
    end
    table.insert(self._elements, elem)
    if id then EcrinVeil.Options[id] = elem end
    return elem
end

-- Input
function Tab:AddInput(id, opts)
    opts = opts or {}
    local cont     = getContainer(self); local order = #self._elements + 1
    local cb       = opts.Callback or function() end
    local onChange = nil
    local val      = opts.Default or ""

    local sec = secFrame(cont, order)
    local row = frm({
        Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.fill,
        BackgroundTransparency = 0, ZIndex = 14, LayoutOrder = 1,
    }, sec)
    crn(row, 10); pad(row, 8, 14, 8, 14)
    registerThemeFrame(row, "fill")

    local tL = lbl({
        Size = UDim2.new(1, 0, 0, 15), Text = resolveText(opts.Title or "Input"),
        TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
    }, row)
    trackLabel(tL, opts.Title)
    registerThemeFrame(tL, "l2")

    local box = inst("TextBox", {
        Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 20),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = val, PlaceholderText = resolveText(opts.Placeholder or ""),
        TextColor3 = C.l1, PlaceholderColor3 = C.l3,
        TextSize = SZ.subhead, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 15, ClearTextOnFocus = false, ClipsDescendants = false,
    }, row)
    registerThemeCallback(function() box.TextColor3 = C.l1 end)

    if opts.Numeric then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            local cl = box.Text:gsub("[^%d%.%-]", "")
            if cl ~= box.Text then box.Text = cl end
        end)
    end

    local border = frm({
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 43),
        BackgroundColor3 = C.separator, BackgroundTransparency = 0, ZIndex = 14,
    }, row)

    box.Focused:Connect(function() tw(border, eOut(0.18), { BackgroundColor3 = C.blue }) end)
    box.FocusLost:Connect(function(enter)
        tw(border, eOut(0.18), { BackgroundColor3 = C.separator }); val = box.Text
        if opts.Finished then if enter then cb(val) end else cb(val) end
        if onChange then onChange(val) end
    end)
    if not opts.Finished then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            val = box.Text; cb(val); if onChange then onChange(val) end
        end)
    end

    local elem = { type = "input", frame = sec, Value = val, _box = box }
    function elem:SetValue(v) box.Text = v; val = v end
    function elem:OnChanged(fn) onChange = fn end
    applyCommonMethods(elem)
    table.insert(self._elements, elem)
    if id then EcrinVeil.Options[id] = elem end
    return elem
end

-- Dropdown
function Tab:AddDropdown(id, opts)
    opts = opts or {}
    local cont     = getContainer(self); local order = #self._elements + 1
    local values   = opts.Values or {}
    local multi    = opts.Multi == true
    local cb       = opts.Callback or function() end
    local onChange = nil
    local sel      = {}; local isOpen = false; local panel = nil; local closing = false

    if multi then
        if type(opts.Default) == "table" then
            for _, v in ipairs(opts.Default) do sel[v] = true end
        end
    else
        sel = opts.Default or values[1]
    end

    local sec = secFrame(cont, order)
    local row = rowFrame(sec, 1, opts.Description ~= nil); crn(row, 10)
    pad(row, 0, 14, 0, 14)
    rowLabels(row, opts.Title or "Dropdown", opts.Description)

    local function dispText()
        if multi then
            local arr = {}
            for v, s in pairs(sel) do if s then table.insert(arr, v) end end
            return #arr == 0 and T("select_placeholder") or table.concat(arr, ", ")
        else
            return tostring(sel or T("select_placeholder"))
        end
    end

    local vLbl = lbl({
        Size = UDim2.new(0.42, -24, 1, 0), Position = UDim2.new(0.58, 0, 0, 0),
        Text = dispText(), TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Right, ClipsDescendants = true, ZIndex = 15,
    }, row)

    local arrow = lbl({
        Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0),
        Text = "v", TextColor3 = C.l3, TextSize = 12, Font = F.bold, ZIndex = 15,
    }, row)

    local function closePanel()
        if not panel or closing then return end
        closing = true; isOpen = false
        tw(arrow, eOut(0.15), { Rotation = 0 })
        tw(panel, eIn(0.18), { Size = UDim2.new(1, 0, 0, 0) })
        local p = panel; panel = nil
        task.delay(0.19, function()
            closing = false
            if p and p.Parent then p:Destroy() end
        end)
    end

    local function registerPanel()
        if self._panels then table.insert(self._panels, closePanel) end
    end

    local function openPanel()
        if panel or closing then return end
        isOpen = true
        registerPanel()
        tw(arrow, eOut(0.15), { Rotation = 180 })

        local IH = 34; local MAX = 5; local SH = 34
        local listH  = math.min(#values, MAX) * IH
        local totalH = SH + listH + 4

        panel = frm({
            Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, ROW_H),
            BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0,
            ClipsDescendants = true, ZIndex = 18, LayoutOrder = 2,
        }, sec); crn(panel, 10)
        frm({ Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = C.bgElevated,
            BackgroundTransparency = 0, ZIndex = 18 }, panel)

        local sw = frm({ Size = UDim2.new(1, -24, 0, 26), Position = UDim2.new(0, 12, 0, 5),
            BackgroundColor3 = C.fill, BackgroundTransparency = 0, ZIndex = 19 }, panel)
        crn(sw, 7); pad(sw, 0, 8, 0, 8)
        lbl({ Size = UDim2.new(0, 14, 1, 0), Text = "?", TextColor3 = C.l3,
            TextSize = 12, Font = F.bold, ZIndex = 20 }, sw)
        local sbox = inst("TextBox", {
            Size = UDim2.new(1, -18, 1, 0), Position = UDim2.new(0, 18, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            PlaceholderText = T("search_placeholder"), PlaceholderColor3 = C.l3,
            Text = "", TextColor3 = C.l1, TextSize = SZ.caption1, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 20, ClearTextOnFocus = false,
        }, sw)

        local lscroll = inst("ScrollingFrame", {
            Size = UDim2.new(1, -24, 0, listH), Position = UDim2.new(0, 12, 0, SH + 2),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = C.separator,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 19,
        }, panel)
        ll(lscroll, Enum.FillDirection.Vertical, 0)

        -- buildList re-evaluates isSel per item on each call — no stale closure.
        local function buildList(filter)
            for _, c in ipairs(lscroll:GetChildren()) do
                if c:IsA("Frame") then c:Destroy() end
            end
            local shown = 0
            for _, v in ipairs(values) do
                local vs = tostring(v)
                if filter == "" or vs:lower():find(filter:lower(), 1, true) then
                    shown = shown + 1
                    local isSel = multi and sel[v] or sel == v
                    local item = frm({
                        Size = UDim2.new(1, 0, 0, IH), LayoutOrder = shown,
                        BackgroundColor3 = isSel and C.blue:Lerp(C.fill, 0.7) or C.bgElevated,
                        BackgroundTransparency = 0, ZIndex = 20,
                    }, lscroll)
                    lbl({ Size = UDim2.new(1, -36, 1, 0), Position = UDim2.new(0, 12, 0, 0),
                        Text = vs, TextColor3 = isSel and C.l1 or C.l2,
                        TextSize = SZ.subhead, Font = isSel and F.medium or F.regular,
                        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, item)
                    if isSel then
                        lbl({ Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(1, -22, 0, 0),
                            Text = "v", TextColor3 = C.blue, TextSize = 12, Font = F.bold, ZIndex = 21 }, item)
                    end
                    local vc = v
                    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 22 }, item).MouseButton1Click:Connect(function()
                        if multi then sel[vc] = not sel[vc] else sel = vc end
                        vLbl.Text = dispText(); cb(sel); if onChange then onChange(sel) end
                        if not multi then closePanel() else buildList(sbox.Text) end
                    end)
                    -- isSel is local to this loop iteration, safe to close over.
                    local capturedSel = isSel
                    press(item,
                        function() return capturedSel and C.blue:Lerp(C.fill, 0.7) or C.bgElevated end,
                        "fillSecond", nil)
                    if shown > 1 then
                        frm({ Size = UDim2.new(1, -24, 0, 0.5), Position = UDim2.new(0, 12, 0, 0),
                            BackgroundColor3 = C.separator, BackgroundTransparency = 0.5, ZIndex = 21 }, item)
                    end
                end
            end
            lscroll.CanvasSize = UDim2.new(0, 0, 0, shown * IH)
            local newLH = math.min(shown, MAX) * IH
            lscroll.Size = UDim2.new(1, -24, 0, newLH)
            if panel then tw(panel, eOut(0.18), { Size = UDim2.new(1, 0, 0, SH + newLH + 4) }) end
        end

        buildList("")
        tw(panel, spr(0.35), { Size = UDim2.new(1, 0, 0, totalH) })
        sbox:GetPropertyChangedSignal("Text"):Connect(function() buildList(sbox.Text) end)
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 16 }, row).MouseButton1Click:Connect(function()
        if isOpen then closePanel() else openPanel() end
    end)

    local elem = { type = "dropdown", frame = sec, Value = sel }
    function elem:SetValue(v)
        if multi then sel = type(v) == "table" and v or { [v] = true } else sel = v end
        vLbl.Text = dispText(); self.Value = sel
    end
    function elem:SetValues(newList)
        values = newList; if panel then closePanel() end; vLbl.Text = dispText()
    end
    function elem:OnChanged(fn) onChange = fn end
    applyCommonMethods(elem)
    table.insert(self._elements, elem)
    if id then EcrinVeil.Options[id] = elem end
    return elem
end

-- Keybind
function Tab:AddKeybind(id, opts)
    opts = opts or {}
    local cont     = getContainer(self); local order = #self._elements + 1
    local mode     = opts.Mode or "Toggle"
    local cb       = opts.Callback or function() end
    local changeCb = opts.ChangedCallback or function() end
    local onChange = nil
    local listening = false; local state = false
    local curKey = opts.Default and Enum.KeyCode[opts.Default] or Enum.KeyCode.E

    local sec = secFrame(cont, order)
    local row = rowFrame(sec, 1); crn(row, 10); pad(row, 0, 14, 0, 14)
    rowLabels(row, opts.Title or "Keybind")

    local badge = frm({
        Size = UDim2.new(0, 50, 0, 24), Position = UDim2.new(1, -64, 0.5, -12),
        BackgroundColor3 = C.fill, BackgroundTransparency = 0, ZIndex = 15,
    }, row)
    crn(badge, 6); strk(badge, C.separator, 0.5, 0)

    local kLbl = lbl({
        Size = UDim2.new(1, 0, 1, 0), Text = curKey.Name, TextColor3 = C.l1,
        TextSize = SZ.caption1, Font = F.medium,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 16,
    }, badge)

    local dot = frm({
        Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(1, -16, 0.5, -4),
        BackgroundColor3 = C.l4, BackgroundTransparency = 0, ZIndex = 15,
    }, row)
    crn(dot, 4)

    local function setListening(v)
        listening = v
        if v then
            EcrinVeil._listeningKeybind = EcrinVeil._listeningKeybind + 1
            tw(badge, eOut(0.15), { BackgroundColor3 = C.blue:Lerp(C.fill, 0.6) }); kLbl.Text = "..."
        else
            EcrinVeil._listeningKeybind = math.max(0, EcrinVeil._listeningKeybind - 1)
            tw(badge, eOut(0.15), { BackgroundColor3 = C.fill }); kLbl.Text = curKey.Name
        end
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 17 }, row).MouseButton1Click:Connect(function()
        setListening(not listening)
    end)

    local conns = {}
    table.insert(conns, UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if listening then
            if i.KeyCode ~= Enum.KeyCode.Unknown then
                curKey = i.KeyCode; changeCb(curKey)
                if onChange then onChange(curKey) end; setListening(false)
            end
            return
        end
        if i.KeyCode == curKey then
            if mode == "Toggle" then
                state = not state
                tw(dot, eOut(0.15), { BackgroundColor3 = state and C.green or C.l4 }); cb(state)
            elseif mode == "Hold" then
                state = true; tw(dot, eOut(0.15), { BackgroundColor3 = C.green }); cb(true)
            end
        end
    end))
    table.insert(conns, UIS.InputEnded:Connect(function(i)
        if mode == "Hold" and i.KeyCode == curKey then
            state = false; tw(dot, eOut(0.15), { BackgroundColor3 = C.l4 }); cb(false)
        end
    end))

    local elem = { type = "keybind", frame = sec, Value = curKey }
    function elem:GetState() return state end
    function elem:SetValue(kn, nm)
        if kn then
            -- kn should be the key name string (e.g. "E"), not the full EnumItem string.
            local resolved = Enum.KeyCode[kn]
            if resolved then
                curKey = resolved; kLbl.Text = curKey.Name
            else
                warn("[EcrinVeil] Keybind SetValue: invalid key -> " .. tostring(kn))
            end
        end
        if nm then mode = nm end; self.Value = curKey
    end
    function elem:OnChanged(fn) onChange = fn end
    function elem:OnClick(fn) cb = fn end
    function elem:SetVisible(v2) if sec then sec.Visible = v2 end end
    function elem:Destroy()
        for _, c in ipairs(conns) do c:Disconnect() end
        if sec then sec:Destroy(); sec = nil end
    end
    table.insert(self._elements, elem)
    if id then EcrinVeil.Options[id] = elem end
    return elem
end

-- ProgressBar
function Tab:AddProgressBar(opts)
    opts = opts or {}
    local cont  = getContainer(self); local order = #self._elements + 1
    local val   = opts.Default or 0
    local col   = opts.Color or C.blue

    local sec = secFrame(cont, order)
    local row = frm({
        Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.fill,
        BackgroundTransparency = 0, ZIndex = 14, LayoutOrder = 1,
    }, sec)
    crn(row, 10); pad(row, 10, 14, 10, 14)

    local tL = lbl({
        Size = UDim2.new(0.7, -4, 0, 20), Position = UDim2.new(0, 0, 0, 0),
        Text = resolveText(opts.Title or "Progress"), TextColor3 = C.l1,
        TextSize = SZ.subhead, Font = F.regular, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
    }, row)
    trackLabel(tL, opts.Title)

    local pLbl = lbl({
        Size = UDim2.new(0.3, -4, 0, 20), Position = UDim2.new(0.7, 4, 0, 0),
        Text = string.format("%d%%", math.floor(val * 100)),
        TextColor3 = col, TextSize = SZ.subhead, Font = F.medium,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 15,
    }, row)

    local trk = frm({
        Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = C.fillSecond, BackgroundTransparency = 0, ZIndex = 15,
    }, row); crn(trk, 3)
    registerThemeFrame(trk, "fillSecond")
    local bar = frm({
        Size = UDim2.new(math.clamp(val, 0, 1), 0, 1, 0),
        BackgroundColor3 = col, BackgroundTransparency = 0, ZIndex = 16,
    }, trk); crn(bar, 3)

    local elem = { type = "progress", frame = sec, Value = val }
    function elem:SetValue(v, anim)
        v = math.clamp(v, 0, 1); self.Value = v
        pLbl.Text = string.format("%d%%", math.floor(v * 100))
        if anim ~= false then tw(bar, eOut(0.25), { Size = UDim2.new(v, 0, 1, 0) })
        else bar.Size = UDim2.new(v, 0, 1, 0) end
    end
    function elem:SetColor(c) col = c; bar.BackgroundColor3 = c; pLbl.TextColor3 = c end
    applyCommonMethods(elem)
    table.insert(self._elements, elem); return elem
end

-- PlayerTable
-- Renders as a dropdown-style row. Clicking opens a panel with search + avatar list.
-- Local player is always included. Supports double-click detection.
function Tab:AddPlayerTable(opts)
    opts = opts or {}
    local cont     = getContainer(self); local order = #self._elements + 1
    local cb       = opts.OnSelect or function() end
    local selected = nil
    local MAX = opts.MaxVisible or 6; local IH = 46
    local panel = nil; local closing = false

    local sec = secFrame(cont, order)
    local row = rowFrame(sec, 1); crn(row, 10); pad(row, 0, 14, 0, 14)
    registerThemeFrame(row, "fill")

    local titleLbl = lbl({ Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0),
        Text = resolveText(opts.Title or "Select Player"), TextColor3 = C.l1,
        TextSize = SZ.subhead, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15 }, row)
    trackLabel(titleLbl, opts.Title)

    local vLbl = lbl({ Size = UDim2.new(0.4, -24, 1, 0), Position = UDim2.new(0.6, 0, 0, 0),
        Text = "—", TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Right, ClipsDescendants = true, ZIndex = 15 }, row)
    registerThemeFrame(vLbl, "l2")

    local arrow = lbl({ Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0),
        Text = "v", TextColor3 = C.l3, TextSize = 12, Font = F.bold, ZIndex = 15 }, row)

    local function closePanel()
        if not panel or closing then return end
        closing = true
        tw(arrow, eOut(0.15), { Rotation = 0 })
        tw(panel, eIn(0.18), { Size = UDim2.new(1, 0, 0, 0) })
        local p = panel; panel = nil
        task.delay(0.19, function()
            closing = false
            if p and p.Parent then p:Destroy() end
        end)
    end

    local function buildList(ls, sbox)
        local filter = sbox and sbox.Text or ""
        for _, c in ipairs(ls:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local n = p.Name
            if filter == "" or n:lower():find(filter:lower(), 1, true) then
                table.insert(list, p)
            end
        end
        table.sort(list, function(a, b)
            if a == plr then return true end
            if b == plr then return false end
            return a.Name < b.Name
        end)
        for i, p in ipairs(list) do
            local isSelf = p == plr
            local isSel  = selected == p.Name
            local item = frm({
                Size = UDim2.new(1, 0, 0, IH), LayoutOrder = i,
                BackgroundColor3 = isSel and C.blue:Lerp(C.bgElevated, 0.65) or C.bgElevated,
                BackgroundTransparency = 0, ZIndex = 20,
            }, ls)
            local AV = IH - 10
            local avatarBg = frm({ Size = UDim2.new(0, AV, 0, AV),
                Position = UDim2.new(0, 8, 0.5, -(AV/2)),
                BackgroundColor3 = C.fill, BackgroundTransparency = 0, ZIndex = 21 }, item)
            crn(avatarBg, AV / 2)
            local avatarImg = inst("ImageLabel", { Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1, Image = "", ZIndex = 22 }, avatarBg)
            crn(avatarImg, AV / 2)
            task.spawn(function()
                local ok, url = pcall(function()
                    return Players:GetUserThumbnailAsync(p.UserId,
                        Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                end)
                if ok and avatarImg and avatarImg.Parent then avatarImg.Image = url end
            end)
            local nameOffX = AV + 14
            local nameText = isSelf and (p.Name .. " (you)") or p.Name
            lbl({ Size = UDim2.new(1, -(nameOffX + 26), 1, 0), Position = UDim2.new(0, nameOffX, 0, 0),
                Text = nameText, TextColor3 = isSel and C.l1 or (isSelf and C.blue or C.l2),
                TextSize = SZ.subhead, Font = (isSel or isSelf) and F.medium or F.regular,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, item)
            if isSel then
                lbl({ Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(1, -22, 0, 0),
                    Text = "v", TextColor3 = C.blue, TextSize = 12, Font = F.bold, ZIndex = 21 }, item)
            end
            if i > 1 then
                frm({ Size = UDim2.new(1, -22, 0, 0.5), Position = UDim2.new(0, 11, 0, 0),
                    BackgroundColor3 = C.separator, BackgroundTransparency = 0.5, ZIndex = 21 }, item)
            end
            local pc = p.Name; local lt = 0
            btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 22 }, item).MouseButton1Click:Connect(function()
                local now = tick(); local isDouble = (now - lt) < 0.36; lt = now
                selected = pc; vLbl.Text = pc
                buildList(ls, sbox); cb(pc, isDouble)
            end)
            local capturedSel = isSel
            press(item, function() return capturedSel and C.blue:Lerp(C.bgElevated, 0.65) or C.bgElevated end, "fillSecond", nil)
        end
        ls.CanvasSize = UDim2.new(0, 0, 0, #list * IH)
        local visH = math.min(#list, MAX) * IH
        ls.Size = UDim2.new(1, -22, 0, visH)
        if panel then
            local SH = 36
            tw(panel, eOut(0.12), { Size = UDim2.new(1, 0, 0, SH + visH + 8) })
        end
    end

    local function openPanel()
        if panel or closing then return end
        tw(arrow, eOut(0.15), { Rotation = 180 })
        local SH = 36
        local initH = SH + math.min(#Players:GetPlayers(), MAX) * IH + 8
        panel = frm({ Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, ROW_H),
            BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0,
            ClipsDescendants = true, ZIndex = 18, LayoutOrder = 2 }, sec)
        crn(panel, 10); registerThemeFrame(panel, "bgElevated")

        -- Search bar inside panel
        local sw = frm({ Size = UDim2.new(1, -22, 0, SH - 6), Position = UDim2.new(0, 11, 0, 4),
            BackgroundColor3 = C.fill, BackgroundTransparency = 0, ZIndex = 19 }, panel)
        crn(sw, 7); pad(sw, 0, 8, 0, 8); registerThemeFrame(sw, "fill")
        lbl({ Size = UDim2.new(0, 14, 1, 0), Text = "?", TextColor3 = C.l3,
            TextSize = 12, Font = F.bold, ZIndex = 20 }, sw)
        local sbox = inst("TextBox", {
            Size = UDim2.new(1, -18, 1, 0), Position = UDim2.new(0, 18, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            PlaceholderText = T("player_search"), PlaceholderColor3 = C.l3,
            Text = "", TextColor3 = C.l1, TextSize = SZ.footnote, Font = F.regular,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 20, ClearTextOnFocus = false,
        }, sw)

        local ls = inst("ScrollingFrame", {
            Size = UDim2.new(1, -22, 0, 0), Position = UDim2.new(0, 11, 0, SH + 2),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = C.separator,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 19,
        }, panel)
        ll(ls, Enum.FillDirection.Vertical, 0)

        buildList(ls, sbox)
        sbox:GetPropertyChangedSignal("Text"):Connect(function() buildList(ls, sbox) end)
        tw(panel, spr(0.35), { Size = UDim2.new(1, 0, 0, initH) })

        -- Auto-refresh when players join/leave while panel is open
        local pa = Players.PlayerAdded:Connect(function()
            if panel then buildList(ls, sbox) end
        end)
        local pr = Players.PlayerRemoving:Connect(function()
            if panel then task.defer(function() buildList(ls, sbox) end) end
        end)
        task.delay(60, function() pa:Disconnect(); pr:Disconnect() end)
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 16 }, row).MouseButton1Click:Connect(function()
        if panel then closePanel() else openPanel() end
    end)

    local elem = { type = "playertable", frame = sec }
    function elem:GetSelected() return selected end
    function elem:Refresh() if panel then end end
    applyCommonMethods(elem)
    table.insert(self._elements, elem); return elem
end

-- Table
-- Rendered as a dropdown-style row. Panel opens below, contains optional search
-- bar + scrollable list with single or multi-select.
function Tab:AddTable(opts)
    opts = opts or {}
    local cont  = getContainer(self); local order = #self._elements + 1
    local items = opts.Items or {}
    local cb    = opts.OnSelect or function() end
    local multi = opts.Multi == true
    local selected = multi and {} or nil
    local MAX = opts.MaxVisible or 6; local IH = 38
    local panel = nil; local closing = false

    local sec = secFrame(cont, order)
    local row = rowFrame(sec, 1); crn(row, 10); pad(row, 0, 14, 0, 14)
    registerThemeFrame(row, "fill")

    local titleLbl = lbl({ Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0),
        Text = resolveText(opts.Title or "Select"), TextColor3 = C.l1,
        TextSize = SZ.subhead, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15 }, row)
    trackLabel(titleLbl, opts.Title)

    local function dispSel()
        if multi then
            local arr = {}
            for v, s in pairs(selected) do if s then table.insert(arr, v) end end
            return #arr == 0 and T("select_placeholder") or table.concat(arr, ", ")
        else
            return selected or T("select_placeholder")
        end
    end

    local vLbl = lbl({ Size = UDim2.new(0.4, -24, 1, 0), Position = UDim2.new(0.6, 0, 0, 0),
        Text = dispSel(), TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Right, ClipsDescendants = true, ZIndex = 15 }, row)
    registerThemeFrame(vLbl, "l2")

    local arrow = lbl({ Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0),
        Text = "v", TextColor3 = C.l3, TextSize = 12, Font = F.bold, ZIndex = 15 }, row)

    local currentSbox = nil

    local function closePanel()
        if not panel or closing then return end
        closing = true
        tw(arrow, eOut(0.15), { Rotation = 0 })
        tw(panel, eIn(0.18), { Size = UDim2.new(1, 0, 0, 0) })
        local p = panel; panel = nil; currentSbox = nil
        task.delay(0.19, function()
            closing = false
            if p and p.Parent then p:Destroy() end
        end)
    end

    local function buildList(ls, sbox)
        local filter = sbox and sbox.Text or ""
        for _, c in ipairs(ls:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        local shown = 0
        for _, item in ipairs(items) do
            local label = type(item) == "table" and (item.Label or item[1]) or tostring(item)
            if filter == "" or label:lower():find(filter:lower(), 1, true) then
                shown = shown + 1
                local isSel = multi and (selected[label] == true) or (selected == label)
                local row2 = frm({
                    Size = UDim2.new(1, 0, 0, IH), LayoutOrder = shown,
                    BackgroundColor3 = isSel and C.blue:Lerp(C.bgElevated, 0.65) or C.bgElevated,
                    BackgroundTransparency = 0, ZIndex = 20,
                }, ls)
                lbl({ Size = UDim2.new(1, -36, 1, 0), Position = UDim2.new(0, 12, 0, 0),
                    Text = label, TextColor3 = isSel and C.l1 or C.l2,
                    TextSize = SZ.subhead, Font = isSel and F.medium or F.regular,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, row2)
                if isSel then
                    lbl({ Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(1, -22, 0, 0),
                        Text = "v", TextColor3 = C.blue, TextSize = 12, Font = F.bold, ZIndex = 21 }, row2)
                end
                if shown > 1 then
                    frm({ Size = UDim2.new(1, -22, 0, 0.5), Position = UDim2.new(0, 11, 0, 0),
                        BackgroundColor3 = C.separator, BackgroundTransparency = 0.5, ZIndex = 21 }, row2)
                end
                local vc = label
                btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 22 }, row2).MouseButton1Click:Connect(function()
                    if multi then selected[vc] = not selected[vc] else selected = vc end
                    vLbl.Text = dispSel(); cb(selected)
                    if multi then buildList(ls, sbox) else closePanel() end
                end)
                local capturedSel = isSel
                press(row2, function() return capturedSel and C.blue:Lerp(C.bgElevated, 0.65) or C.bgElevated end, "fillSecond", nil)
            end
        end
        ls.CanvasSize = UDim2.new(0, 0, 0, shown * IH)
        local visH = math.min(shown, MAX) * IH
        ls.Size = UDim2.new(1, -22, 0, visH)
        if panel then
            local SH = opts.Searchable and 36 or 0
            tw(panel, eOut(0.12), { Size = UDim2.new(1, 0, 0, SH + visH + 8) })
        end
    end

    local function openPanel()
        if panel or closing then return end
        tw(arrow, eOut(0.15), { Rotation = 180 })
        local SH = opts.Searchable and 36 or 0
        local initH = SH + math.min(#items, MAX) * IH + 8
        panel = frm({ Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, ROW_H),
            BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0,
            ClipsDescendants = true, ZIndex = 18, LayoutOrder = 2 }, sec)
        crn(panel, 10); registerThemeFrame(panel, "bgElevated")

        local sbox = nil
        if opts.Searchable then
            local sw = frm({ Size = UDim2.new(1, -22, 0, SH - 6), Position = UDim2.new(0, 11, 0, 4),
                BackgroundColor3 = C.fill, BackgroundTransparency = 0, ZIndex = 19 }, panel)
            crn(sw, 7); pad(sw, 0, 8, 0, 8); registerThemeFrame(sw, "fill")
            lbl({ Size = UDim2.new(0, 14, 1, 0), Text = "?", TextColor3 = C.l3,
                TextSize = 12, Font = F.bold, ZIndex = 20 }, sw)
            sbox = inst("TextBox", {
                Size = UDim2.new(1, -18, 1, 0), Position = UDim2.new(0, 18, 0, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                PlaceholderText = T("search_placeholder"), PlaceholderColor3 = C.l3,
                Text = "", TextColor3 = C.l1, TextSize = SZ.footnote, Font = F.regular,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 20, ClearTextOnFocus = false,
            }, sw)
            currentSbox = sbox
        end

        local ls = inst("ScrollingFrame", {
            Size = UDim2.new(1, -22, 0, 0), Position = UDim2.new(0, 11, 0, (SH > 0 and SH + 2 or 4)),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = C.separator,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 19,
        }, panel)
        ll(ls, Enum.FillDirection.Vertical, 0)

        buildList(ls, sbox)
        if sbox then
            sbox:GetPropertyChangedSignal("Text"):Connect(function() buildList(ls, sbox) end)
        end
        tw(panel, spr(0.35), { Size = UDim2.new(1, 0, 0, initH) })
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 16 }, row).MouseButton1Click:Connect(function()
        if panel then closePanel() else openPanel() end
    end)

    local elem = { type = "table", frame = sec, Value = selected }
    function elem:GetSelected() return selected end
    function elem:SetItems(newItems)
        items = newItems
        if panel then closePanel() end
        vLbl.Text = dispSel(); self.Value = selected
    end
    applyCommonMethods(elem)
    table.insert(self._elements, elem); return elem
end

-- ColorPicker
-- Note: preset swatches snapshot C.* at panel open time. If the user changes the
-- theme while the panel is open the swatches won't repaint. Not worth adding a
-- live subscription for this edge case — just close and reopen the panel.
function Tab:AddColorpicker(id, opts)
    opts = opts or {}
    local cont     = getContainer(self); local order = #self._elements + 1
    local val      = opts.Default or Color3.fromRGB(255, 255, 255)
    local onChange = nil; local isOpen = false; local panel = nil; local closing = false

    local sec = secFrame(cont, order)
    local row = rowFrame(sec, 1, opts.Description ~= nil); crn(row, 10)
    pad(row, 0, 14, 0, 14)
    rowLabels(row, opts.Title or "Color", opts.Description)

    local prev = frm({
        Size = UDim2.new(0, 26, 0, 20), Position = UDim2.new(1, -40, 0.5, -10),
        BackgroundColor3 = val, BackgroundTransparency = 0, ZIndex = 15,
    }, row)
    crn(prev, 6); strk(prev, C.separator, 0.5, 0)

    local panelConns = {}

    local function closePanel()
        if not panel or closing then return end
        closing = true; isOpen = false
        for _, c in ipairs(panelConns) do pcall(function() c:Disconnect() end) end
        panelConns = {}
        local p = panel; panel = nil
        tw(p, eIn(0.18), { Size = UDim2.new(1, 0, 0, 0) })
        task.delay(0.2, function()
            closing = false
            if p and p.Parent then p:Destroy() end
        end)
    end

    local function registerPanel()
        if self._panels then table.insert(self._panels, closePanel) end
    end

    local function openPanel()
        if panel or closing then return end
        isOpen = true
        registerPanel()
        panel = frm({
            Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, ROW_H),
            BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0,
            ClipsDescendants = true, ZIndex = 18, LayoutOrder = 2,
        }, sec); crn(panel, 10)
        registerThemeFrame(panel, "bgElevated")

        local function colorToHex(c)
            return string.format("%02X%02X%02X",
                math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
        end
        local function hexToColor(h)
            h = h:gsub("#", "")
            if #h ~= 6 then return nil end
            local r = tonumber(h:sub(1, 2), 16)
            local g = tonumber(h:sub(3, 4), 16)
            local b = tonumber(h:sub(5, 6), 16)
            if not r or not g or not b then return nil end
            return Color3.fromRGB(r, g, b)
        end

        local bigPrev = frm({
            Size = UDim2.new(1, -24, 0, 32), Position = UDim2.new(0, 12, 0, 10),
            BackgroundColor3 = val, BackgroundTransparency = 0, ZIndex = 19,
        }, panel); crn(bigPrev, 8); strk(bigPrev, C.separator, 0.5, 0.3)

        local hexBox = inst("TextBox", {
            Size = UDim2.new(0, 80, 0, 26), Position = UDim2.new(1, -94, 0, 13),
            BackgroundColor3 = C.fill, BackgroundTransparency = 0,
            Text = "#" .. colorToHex(val), PlaceholderText = "#RRGGBB",
            TextColor3 = C.l1, PlaceholderColor3 = C.l3,
            TextSize = SZ.caption1, Font = F.medium,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 20, ClearTextOnFocus = false, BorderSizePixel = 0,
        }, panel); crn(hexBox, 6); strk(hexBox, C.separator, 0.5, 0.3)

        local channels = {
            { name="R", g=function() return math.floor(val.R*255) end,
              s=function(v) val=Color3.fromRGB(v, math.floor(val.G*255), math.floor(val.B*255)); return val end, c=C.red },
            { name="G", g=function() return math.floor(val.G*255) end,
              s=function(v) val=Color3.fromRGB(math.floor(val.R*255), v, math.floor(val.B*255)); return val end, c=C.green },
            { name="B", g=function() return math.floor(val.B*255) end,
              s=function(v) val=Color3.fromRGB(math.floor(val.R*255), math.floor(val.G*255), v); return val end, c=C.blue },
        }

        local presets = { C.red, C.green, C.blue, C.orange, C.purple, C.pink, C.teal, C.yellow, C.cyan, C.indigo }
        local PSWATCH = 18; local pY = 52
        for pi, pc in ipairs(presets) do
            local ps = frm({
                Size = UDim2.new(0, PSWATCH, 0, PSWATCH),
                Position = UDim2.new(0, 12 + (pi-1) * (PSWATCH + 4), 0, pY),
                BackgroundColor3 = pc, BackgroundTransparency = 0, ZIndex = 19,
            }, panel); crn(ps, PSWATCH / 2); strk(ps, C.separator, 0.5, 0.4)
            local pcc = pc
            btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 20 }, ps).MouseButton1Click:Connect(function()
                val = pcc; prev.BackgroundColor3 = val; bigPrev.BackgroundColor3 = val
                hexBox.Text = "#" .. colorToHex(val)
                if onChange then onChange(val) end
            end)
        end

        local sliderBaseY = pY + PSWATCH + 10
        local panelH = sliderBaseY + #channels * 46 + 8
        tw(panel, spr(0.35), { Size = UDim2.new(1, 0, 0, panelH) })

        local sliderRefs = {}
        local function syncSliders()
            for _, sr in ipairs(sliderRefs) do
                local pct = sr.ch.g() / 255
                sr.fill.Size     = UDim2.new(pct, 0, 1, 0)
                sr.thumb.Position = UDim2.new(pct, -7, 0.5, -7)
                sr.vLbl.Text     = tostring(sr.ch.g())
            end
        end

        for ci, ch in ipairs(channels) do
            local yP = sliderBaseY + (ci - 1) * 46
            lbl({ Size = UDim2.new(0, 12, 0, 14), Position = UDim2.new(0, 14, 0, yP + 4),
                Text = ch.name, TextColor3 = ch.c, TextSize = SZ.caption1, Font = F.bold, ZIndex = 19 }, panel)

            local trk2 = frm({ Size = UDim2.new(1, -58, 0, 4), Position = UDim2.new(0, 30, 0, yP + 12),
                BackgroundColor3 = C.fillSecond, BackgroundTransparency = 0, ZIndex = 19 }, panel)
            crn(trk2, 2); registerThemeFrame(trk2, "fillSecond")

            local pct0  = ch.g() / 255
            local fill2 = frm({ Size = UDim2.new(pct0, 0, 1, 0), BackgroundColor3 = ch.c,
                BackgroundTransparency = 0, ZIndex = 20 }, trk2); crn(fill2, 2)

            local TH2 = 14
            local thumb2 = frm({ Size = UDim2.new(0, TH2, 0, TH2),
                Position = UDim2.new(pct0, -TH2/2, 0.5, -TH2/2),
                BackgroundColor3 = C.l1, BackgroundTransparency = 0, ZIndex = 21 }, trk2)
            crn(thumb2, TH2 / 2); strk(thumb2, Color3.new(0,0,0), 0.5, 0.7)
            registerThemeFrame(thumb2, "l1")

            local vLbl2 = lbl({ Size = UDim2.new(0, 32, 0, 22), Position = UDim2.new(1, -46, 0, yP + 3),
                Text = tostring(ch.g()), TextColor3 = C.l2,
                TextSize = SZ.caption1, Font = F.medium,
                TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 19 }, panel)

            table.insert(sliderRefs, { fill = fill2, thumb = thumb2, vLbl = vLbl2, ch = ch })

            local localDrag = false
            table.insert(panelConns, thumb2.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then localDrag = true end
            end))
            table.insert(panelConns, trk2.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    local ta = trk2.AbsolutePosition; local trkW2 = trk2.AbsoluteSize.X
                    local p3 = math.clamp((inp.Position.X - ta.X) / trkW2, 0, 1)
                    local v3 = math.floor(p3 * 255)
                    val = ch.s(v3); prev.BackgroundColor3 = val; bigPrev.BackgroundColor3 = val
                    hexBox.Text = "#" .. colorToHex(val)
                    fill2.Size = UDim2.new(p3, 0, 1, 0); thumb2.Position = UDim2.new(p3, -TH2/2, 0.5, -TH2/2)
                    vLbl2.Text = tostring(v3)
                    if onChange then onChange(val) end
                end
            end))
            table.insert(panelConns, UIS.InputChanged:Connect(function(inp)
                if not localDrag or not panel then return end
                if inp.UserInputType == Enum.UserInputType.MouseMovement then
                    local ta = trk2.AbsolutePosition; local trkW2 = trk2.AbsoluteSize.X
                    local p3 = math.clamp((inp.Position.X - ta.X) / trkW2, 0, 1)
                    local v3 = math.floor(p3 * 255)
                    val = ch.s(v3); prev.BackgroundColor3 = val; bigPrev.BackgroundColor3 = val
                    hexBox.Text = "#" .. colorToHex(val)
                    fill2.Size = UDim2.new(p3, 0, 1, 0); thumb2.Position = UDim2.new(p3, -TH2/2, 0.5, -TH2/2)
                    vLbl2.Text = tostring(v3)
                    if onChange then onChange(val) end
                end
            end))
            table.insert(panelConns, UIS.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then localDrag = false end
            end))
        end

        table.insert(panelConns, hexBox.FocusLost:Connect(function()
            local parsed = hexToColor(hexBox.Text)
            if parsed then
                val = parsed; prev.BackgroundColor3 = val; bigPrev.BackgroundColor3 = val
                hexBox.Text = "#" .. colorToHex(val); syncSliders()
                if onChange then onChange(val) end
            else
                hexBox.Text = "#" .. colorToHex(val)
            end
        end))
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 16 }, row).MouseButton1Click:Connect(function()
        if isOpen then closePanel() else openPanel() end
    end)

    local elem = { type = "colorpicker", frame = sec, Value = val }
    function elem:SetValueRGB(c) val = c; prev.BackgroundColor3 = c; self.Value = c end
    function elem:SetValue(c) self:SetValueRGB(c) end
    function elem:OnChanged(fn) onChange = fn end
    applyCommonMethods(elem)
    table.insert(self._elements, elem)
    if id then EcrinVeil.Options[id] = elem end
    return elem
end

-- Accordion
-- Creates a collapsible section. Elements added via accordion:Add() are hidden
-- until the header row is clicked. The content frame uses AutomaticSize so any
-- element type works inside without needing a fixed height.
-- Usage:
--   local acc = tab:AddAccordion({ Title = "Advanced", DefaultOpen = false })
--   acc:Add(function(innerTab) innerTab:AddToggle(...) end)
function Tab:AddAccordion(opts)
    opts = opts or {}
    local cont  = getContainer(self)
    local order = #self._elements + 1
    local isOpen = opts.DefaultOpen == true

    local sec = secFrame(cont, order)
    -- sec needs a vertical layout so hdr and contentWrap stack instead of overlap.
    ll(sec, Enum.FillDirection.Vertical, 0)

    -- Header row (always visible, acts as the toggle button)
    local hdr = btn({
        Size = UDim2.new(1, 0, 0, ROW_H),
        BackgroundColor3 = C.fill, BackgroundTransparency = 0,
        Text = "", ZIndex = 14, LayoutOrder = 1,
    }, sec)
    crn(hdr, 10)
    registerThemeFrame(hdr, "fill")

    local titleLbl = lbl({
        Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 14, 0, 0),
        Text = resolveText(opts.Title or "Accordion"),
        TextColor3 = C.l1, TextSize = SZ.subhead, Font = F.semibold,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15,
    }, hdr)
    trackLabel(titleLbl, opts.Title)

    local chevron = lbl({
        Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(1, -28, 0.5, -9),
        Text = "v", TextColor3 = C.l3, TextSize = 12, Font = F.bold,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 15,
        BackgroundTransparency = 1,
    }, hdr)

    -- contentWrap clips the inner content while animating.
    -- We drive its height manually — no AutomaticSize — so closing it to 0
    -- actually collapses the space in the parent layout.
    local contentWrap = frm({
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 13, LayoutOrder = 2,
    }, sec)

    -- contentInner holds the actual elements. AutomaticSize is intentionally
    -- NOT set here; we read AbsoluteContentSize from the layout and apply it
    -- to contentWrap ourselves so the parent layout sees the correct height.
    local contentInner = frm({
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 13,
    }, contentWrap)
    pad(contentInner, 4, 0, 4, 0)
    local innerLayout = ll(contentInner, Enum.FillDirection.Vertical, 8)

    local innerTab = setmetatable({
        _win       = self._win,
        _elements  = {},
        _panels    = self._panels,
        _container = contentInner,
    }, Tab)

    local function getContentHeight()
        return innerLayout.AbsoluteContentSize.Y + 8
    end

    local function applyHeight(h)
        contentInner.Size = UDim2.new(1, 0, 0, h)
        contentWrap.Size  = UDim2.new(1, 0, 0, h)
    end

    local function setOpen(open, animate)
        isOpen = open
        local targetH = open and getContentHeight() or 0
        tw(chevron, eOut(0.2), { Rotation = open and 180 or 0 })
        if animate then
            -- Tween both wrappers together so there's no gap left behind.
            TS:Create(contentWrap,  eOut(0.22), { Size = UDim2.new(1, 0, 0, targetH) }):Play()
            TS:Create(contentInner, eOut(0.22), { Size = UDim2.new(1, 0, 0, targetH) }):Play()
        else
            applyHeight(targetH)
        end
    end

    -- When elements are added after initial build, resize if already open.
    innerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if isOpen then applyHeight(getContentHeight()) end
    end)

    press(hdr, "fill", "fillSecond", nil)
    hdr.MouseButton1Click:Connect(function() setOpen(not isOpen, true) end)

    setOpen(isOpen, false)

    local elem = {
        type   = "accordion",
        frame  = sec,
        _inner = innerTab,
        IsOpen = isOpen,
    }

    function elem:Add(buildFn) buildFn(self._inner) end
    function elem:Open()       setOpen(true,      true) end
    function elem:Close()      setOpen(false,     true) end
    function elem:Toggle()     setOpen(not isOpen, true) end

    applyCommonMethods(elem)
    table.insert(self._elements, elem)
    return elem
end

-- ThemePicker
-- Rendered as a dropdown row so it matches the rest of the settings UI.
-- No color swatches — name only, check mark on active row.
function Tab:AddThemePicker(opts)
    opts = opts or {}
    local cont    = getContainer(self); local order = #self._elements + 1
    local themes  = EcrinVeil:GetThemes()
    local DISPLAY = { dark="Dark", midnight="Midnight", slate="Slate", ocean="Ocean", ember="Ember" }
    local IH = 36; local MAX = #themes
    local panel   = nil; local closing = false

    local sec = secFrame(cont, order)
    local row = rowFrame(sec, 1); crn(row, 10); pad(row, 0, 14, 0, 14)
    registerThemeFrame(row, "fill")

    lbl({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0),
        Text = T("theme_label"), TextColor3 = C.l1, TextSize = SZ.subhead, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15 }, row)

    local function activeName()
        return DISPLAY[EcrinVeil._activeTheme] or EcrinVeil._activeTheme or "—"
    end

    local vLbl = lbl({ Size = UDim2.new(0.42, -24, 1, 0), Position = UDim2.new(0.58, 0, 0, 0),
        Text = activeName(), TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Right, ClipsDescendants = true, ZIndex = 15 }, row)
    registerThemeFrame(vLbl, "l2")

    local arrow = lbl({ Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0),
        Text = "v", TextColor3 = C.l3, TextSize = 12, Font = F.bold, ZIndex = 15 }, row)

    local function closePanel()
        if not panel or closing then return end
        closing = true
        tw(arrow, eOut(0.15), { Rotation = 0 })
        tw(panel, eIn(0.18), { Size = UDim2.new(1, 0, 0, 0) })
        local p = panel; panel = nil
        task.delay(0.19, function()
            closing = false
            if p and p.Parent then p:Destroy() end
        end)
    end

    local function openPanel()
        if panel or closing then return end
        tw(arrow, eOut(0.15), { Rotation = 180 })
        local totalH = IH * MAX + 8
        panel = frm({ Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, ROW_H),
            BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0,
            ClipsDescendants = true, ZIndex = 18, LayoutOrder = 2 }, sec)
        crn(panel, 10); registerThemeFrame(panel, "bgElevated")

        local lscroll = inst("ScrollingFrame", {
            Size = UDim2.new(1, -22, 0, totalH - 8), Position = UDim2.new(0, 11, 0, 4),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = C.separator,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 19,
        }, panel)
        ll(lscroll, Enum.FillDirection.Vertical, 0)
        lscroll.CanvasSize = UDim2.new(0, 0, 0, #themes * IH)

        for i, themeName in ipairs(themes) do
            local isAct = EcrinVeil._activeTheme == themeName
            local dispName = DISPLAY[themeName] or themeName
            local item = frm({
                Size = UDim2.new(1, 0, 0, IH), LayoutOrder = i,
                BackgroundColor3 = isAct and C.blue:Lerp(C.fill, 0.7) or C.bgElevated,
                BackgroundTransparency = 0, ZIndex = 20,
            }, lscroll)
            lbl({ Size = UDim2.new(1, -34, 1, 0), Position = UDim2.new(0, 12, 0, 0),
                Text = dispName, TextColor3 = isAct and C.l1 or C.l2,
                TextSize = SZ.subhead, Font = isAct and F.medium or F.regular,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, item)
            if isAct then
                lbl({ Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -20, 0, 0),
                    Text = "v", TextColor3 = C.blue, TextSize = 12, Font = F.bold, ZIndex = 21 }, item)
            end
            if i > 1 then
                frm({ Size = UDim2.new(1, -22, 0, 0.5), Position = UDim2.new(0, 11, 0, 0),
                    BackgroundColor3 = C.separator, BackgroundTransparency = 0.5, ZIndex = 21 }, item)
            end
            local tn = themeName
            btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 22 }, item).MouseButton1Click:Connect(function()
                EcrinVeil:SetTheme(tn)
                vLbl.Text = DISPLAY[tn] or tn
                closePanel()
            end)
            local capturedAct = isAct
            press(item, function() return capturedAct and C.blue:Lerp(C.fill, 0.7) or C.bgElevated end, "fillSecond", nil)
        end

        tw(panel, spr(0.35), { Size = UDim2.new(1, 0, 0, totalH) })
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 16 }, row).MouseButton1Click:Connect(function()
        if panel then closePanel() else openPanel() end
    end)

    local elem = { type = "themepicker", frame = sec }
    applyCommonMethods(elem)
    table.insert(self._elements, elem); return elem
end

-- SaveManager
local SM = {}; SM.__index = SM
EcrinVeil.SaveManager = SM

local _smLib = nil; local _smFolder = "EcrinVeil"; local _smIgnore = {}

function SM:SetLibrary(lib)       _smLib    = lib end
function SM:SetFolder(f)          _smFolder = f   end
function SM:SetIgnoreIndexes(t)   _smIgnore = t   end

function SM:Save(name)
    if not writefile then return false end
    local data = {}
    if _smLib and _smLib.Options then
        for id, elem in pairs(_smLib.Options) do
            if not _smIgnore[id] then
                local v = elem.Value
                if type(v) == "Color3" then
                    data[id] = { r = v.R, g = v.G, b = v.B }
                elseif type(v) == "EnumItem" then
                    -- Store just the key name so Load can do Enum.KeyCode[name].
                    data[id] = v.Name
                else
                    data[id] = v
                end
            end
        end
    end
    local ok = pcall(function()
        if not isfolder(_smFolder) then makefolder(_smFolder) end
        writefile(_smFolder .. "/" .. name .. ".json",
            game:GetService("HttpService"):JSONEncode(data))
    end)
    return ok
end

function SM:Load(name)
    if not readfile or not isfile then return false end
    local ok, raw = pcall(readfile, _smFolder .. "/" .. name .. ".json")
    if not ok or not raw or raw == "" then return false end
    local ok2, data = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
    if not ok2 or not data then return false end
    if _smLib and _smLib.Options then
        for id, v in pairs(data) do
            local e = _smLib.Options[id]
            if e and e.SetValue then
                if type(v) == "table" and v.r then
                    e:SetValue(Color3.new(v.r, v.g, v.b))
                elseif type(v) == "string" and e.type == "keybind" then
                    -- v is a key name like "E"; SetValue expects the name string.
                    e:SetValue(v)
                else
                    e:SetValue(v)
                end
            end
        end
    end
    return true
end

function SM:BuildConfigSection(tab)
    tab:AddSeparator({ Title = T("config_section") })
    tab:AddInput("_cfgName", { Title = T("config_name"), Default = "default", Placeholder = "config-name" })
    tab:AddButton({ Title = T("save_btn"), Icon = "download", Callback = function()
        local ne = _smLib and _smLib.Options and _smLib.Options["_cfgName"]
        local n  = ne and ne.Value or "default"
        local ok = self:Save(n)
        EcrinVeil:Notify({
            Title   = ok and T("saved") or T("error"),
            Content = ok and (n .. ".json") or T("no_writefile"),
            Kind    = ok and "success" or "error", Duration = 3,
        })
    end })
    tab:AddButton({ Title = T("load_btn"), Icon = "upload", Callback = function()
        local ne = _smLib and _smLib.Options and _smLib.Options["_cfgName"]
        local n  = ne and ne.Value or "default"
        local ok = self:Load(n)
        EcrinVeil:Notify({
            Title   = ok and T("loaded") or T("error"),
            Content = ok and (n .. ".json") or T("file_not_found"),
            Kind    = ok and "success" or "error", Duration = 3,
        })
    end })
end

-- Language dropdown
function Tab:AddLanguageDropdown(opts)
    opts = opts or {}

    local available = {}
    for lang in pairs(EcrinVeil._registeredLangs) do table.insert(available, lang) end
    table.sort(available)

    if #available == 0 then
        warn("[EcrinVeil] AddLanguageDropdown: no multi-language labels registered.")
    end

    local missingCounts = {}
    for _, ref in ipairs(EcrinVeil._labelRefs) do
        if type(ref.original) == "table" then
            for _, lang in ipairs(available) do
                if ref.original[lang] == nil then
                    missingCounts[lang] = (missingCounts[lang] or 0) + 1
                end
            end
        end
    end

    local LANG_NAMES = {
        en="English", tr="Turkce", es="Espanol", fr="Francais",
        de="Deutsch", pt="Portugues", ru="Русский", zh="Zhongwen",
        ar="Arabic", ja="Japanese",
    }

    local displayNames  = {}
    local incompleteSet = {}

    for _, lang in ipairs(available) do
        local name = LANG_NAMES[lang] or lang
        if missingCounts[lang] then
            local incName = name .. " " .. T("incomplete_lang")
            table.insert(displayNames, incName)
            incompleteSet[incName] = true
        else
            table.insert(displayNames, name)
        end
    end

    local function currentDisplay()
        local idx = table.find(available, EcrinVeil._lang)
        if not idx then return displayNames[1] or "?" end
        return displayNames[idx]
    end

    local cont  = getContainer(self); local order = #self._elements + 1
    local sec   = secFrame(cont, order)
    local row   = rowFrame(sec, 1); crn(row, 10); pad(row, 0, 14, 0, 14)

    lbl({ Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0),
        Text = T("language_label"), TextColor3 = C.l1, TextSize = SZ.subhead, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15 }, row)

    local vLbl3 = lbl({ Size = UDim2.new(0.42, -24, 1, 0), Position = UDim2.new(0.58, 0, 0, 0),
        Text = currentDisplay(), TextColor3 = C.l2, TextSize = SZ.caption1, Font = F.regular,
        TextXAlignment = Enum.TextXAlignment.Right, ClipsDescendants = true, ZIndex = 15 }, row)
    local arrow3 = lbl({ Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0),
        Text = "v", TextColor3 = C.l3, TextSize = 12, Font = F.bold, ZIndex = 15 }, row)

    local panel3 = nil; local closing3 = false

    local function closePanel3()
        if not panel3 or closing3 then return end
        closing3 = true
        tw(arrow3, eOut(0.15), { Rotation = 0 })
        tw(panel3, eIn(0.18), { Size = UDim2.new(1, 0, 0, 0) })
        local p = panel3; panel3 = nil
        task.delay(0.19, function()
            closing3 = false
            if p and p.Parent then p:Destroy() end
        end)
    end

    local function openPanel3()
        if panel3 or closing3 then return end
        tw(arrow3, eOut(0.15), { Rotation = 180 })

        local IH2 = 34; local MAX2 = 6
        local totalH2 = IH2 * math.min(#displayNames, MAX2) + 8

        panel3 = frm({ Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, ROW_H),
            BackgroundColor3 = C.bgElevated, BackgroundTransparency = 0,
            ClipsDescendants = true, ZIndex = 18, LayoutOrder = 2 }, sec); crn(panel3, 10)

        local lscroll3 = inst("ScrollingFrame", {
            Size = UDim2.new(1, -22, 0, totalH2), Position = UDim2.new(0, 11, 0, 4),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = C.separator,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 19,
        }, panel3)
        ll(lscroll3, Enum.FillDirection.Vertical, 0)

        for i3, dname in ipairs(displayNames) do
            local isInc = incompleteSet[dname]
            local isCur = (dname == currentDisplay())
            local item3 = frm({
                Size = UDim2.new(1, 0, 0, IH2), LayoutOrder = i3,
                BackgroundColor3 = isCur and C.blue:Lerp(C.fill, 0.7) or C.bgElevated,
                BackgroundTransparency = 0, ZIndex = 20,
            }, lscroll3)
            lbl({ Size = UDim2.new(1, -34, 1, 0), Position = UDim2.new(0, 12, 0, 0),
                Text = dname, TextColor3 = isInc and C.l3 or (isCur and C.l1 or C.l2),
                TextSize = SZ.subhead, Font = isCur and F.medium or F.regular,
                TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21 }, item3)
            if isCur then
                lbl({ Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -20, 0, 0),
                    Text = "v", TextColor3 = C.blue, TextSize = 12, Font = F.bold, ZIndex = 21 }, item3)
            end
            if i3 > 1 then
                frm({ Size = UDim2.new(1, -22, 0, 0.5), Position = UDim2.new(0, 11, 0, 0),
                    BackgroundColor3 = C.separator, BackgroundTransparency = 0.5, ZIndex = 21 }, item3)
            end
            if not isInc then
                btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 22 }, item3).MouseButton1Click:Connect(function()
                    local idx3 = table.find(displayNames, dname)
                    if not idx3 then return end
                    EcrinVeil:SetLanguage(available[idx3])
                    vLbl3.Text = dname; closePanel3()
                end)
                press(item3, "bgElevated", "fillSecond", nil)
            end
        end

        lscroll3.CanvasSize = UDim2.new(0, 0, 0, #displayNames * IH2)
        tw(panel3, spr(0.35), { Size = UDim2.new(1, 0, 0, totalH2 + 8) })
    end

    btn({ Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 16 }, row).MouseButton1Click:Connect(function()
        if panel3 then closePanel3() else openPanel3() end
    end)

    pcall(function() _smIgnore["_ev_lang"] = true end)

    local elem = { type = "langdropdown", frame = sec }
    applyCommonMethods(elem)
    table.insert(self._elements, elem)
    return elem
end

return EcrinVeil
