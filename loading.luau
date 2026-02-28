local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local Lighting = game:GetService('Lighting')
local CoreGui = gethui and gethui() or game:GetService('CoreGui')
local LocalPlayer = Players.LocalPlayer
local title = 'ecrinveil'
local labels = {}
local spacing = 48
local particles = {}
local blur = Instance.new('BlurEffect')

blur.Size = 0
blur.Parent = Lighting

TweenService:Create(blur, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = 35}):Play()

local gui = Instance.new('ScreenGui')

gui.Name = 'ecrin colbabaa'
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local root = Instance.new('Frame')

root.Size = UDim2.new(1, 0, 1, 0)
root.BackgroundTransparency = 1
root.Parent = gui

local background = Instance.new('Frame')

background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(35, 10, 30)
background.BackgroundTransparency = 1
background.ZIndex = 0
background.Parent = root

TweenService:Create(background, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {BackgroundTransparency = 0.18}):Play()

local particleSymbols = {
    '\u{2661}',
    '\u{2726}',
    '\u{2da}',
    '\u{b7}',
    '\u{273f}',
    '\u{2740}',
}
local spawnLoop = true

task.spawn(function()
    while spawnLoop do
        local lbl = Instance.new('TextLabel')

        lbl.Text = particleSymbols[math.random(1, #particleSymbols)]
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = math.random(12, 22)
        lbl.TextColor3 = ({
            Color3.fromRGB(255, 182, 215),
            Color3.fromRGB(200, 162, 255),
            Color3.fromRGB(255, 210, 230),
        })[math.random(1, 3)]
        lbl.TextTransparency = 0.2
        lbl.BackgroundTransparency = 1
        lbl.AnchorPoint = Vector2.new(0.5, 0.5)
        lbl.Position = UDim2.new(math.random(3, 97) / 100, 0, 1.05, 0)
        lbl.ZIndex = 2
        lbl.Parent = root

        local duration = math.random(30, 55) / 10

        TweenService:Create(lbl, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
            Position = UDim2.new(lbl.Position.X.Scale + math.random(-6, 6) / 100, 0, -0.06, 0),
            TextTransparency = 1,
            Rotation = math.random(-20, 20),
        }):Play()
        table.insert(particles, lbl)
        task.delay(duration, function()
            if lbl and lbl.Parent then
                lbl:Destroy()
            end
        end)
        task.wait(math.random(10, 25) / 100)
    end
end)

local image = Instance.new('ImageLabel')

image.AnchorPoint = Vector2.new(0.5, 0.5)
image.Position = UDim2.new(0.5, 0, 0.4, 0)
image.Size = UDim2.new(0, 0, 0, 0)
image.BackgroundTransparency = 1
image.Image = 'rbxassetid://75498856718303'
image.ImageTransparency = 1
image.ImageColor3 = Color3.fromRGB(255, 200, 225)
image.ScaleType = Enum.ScaleType.Fit
image.Parent = gui

TweenService:Create(image, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 200, 0, 200),
    ImageTransparency = 0,
}):Play()

local function FadeOut()
    spawnLoop = false

    TweenService:Create(image, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {
        ImageTransparency = 1,
        Size = UDim2.new(0, 180, 0, 180),
    }):Play()

    for _, lbl in ipairs(labels)do
        TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
            TextSize = 22,
        }):Play()
    end
    for _, p in ipairs(particles)do
        if p and p.Parent then
            TweenService:Create(p, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
        end
    end

    TweenService:Create(background, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
    TweenService:Create(blur, TweenInfo.new(0.2), {Size = 0}):Play()
    task.wait(0.25)
    gui:Destroy()
    blur:Destroy()
end

for i = 1, #title do
    local char = title:sub(i, i)
    local lbl = Instance.new('TextLabel')

    lbl.Text = char
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextTransparency = 1
    lbl.TextStrokeTransparency = 1
    lbl.TextSize = 44
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.Position = UDim2.new(0.5, (i - (#title / 2 + 0.5)) * spacing, 0.65, 0)
    lbl.BackgroundTransparency = 1
    lbl.Parent = root

    local grad = Instance.new('UIGradient')

    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 200)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(210, 170, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 240)),
    })
    grad.Rotation = -45
    grad.Parent = lbl

    TweenService:Create(lbl, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextTransparency = 0,
        TextStrokeTransparency = 0.4,
        TextSize = 68,
    }):Play()
    TweenService:Create(lbl, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextSize = 54}):Play()
    table.insert(labels, lbl)
    task.wait(0.09)
end

task.wait()
FadeOut()
