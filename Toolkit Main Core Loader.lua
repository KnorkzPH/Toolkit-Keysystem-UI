local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Env = (getgenv and getgenv()) or _G

local Toolkit = {
    Version = "3.4",
    NotifName = "ToolkitKeysystem_Notifs",
    -- editable anytime: Toolkit.Notifications.Max / .Duration
    Notifications = { Max = 4, Duration = 4 },
}

-- Colors only. Sizes / layout are fixed on purpose.
local DefaultTheme = {
    Bg = Color3.fromRGB(9, 9, 16),
    Bg2 = Color3.fromRGB(18, 14, 34),
    Card = Color3.fromRGB(19, 18, 32),
    Stroke = Color3.fromRGB(42, 40, 66),
    Text = Color3.fromRGB(242, 240, 255),
    Muted = Color3.fromRGB(138, 135, 170),
    Violet = Color3.fromRGB(139, 92, 255),
    Cyan = Color3.fromRGB(34, 211, 238),
    Pink = Color3.fromRGB(255, 77, 166),
    Teal = Color3.fromRGB(20, 184, 166),
    Blue = Color3.fromRGB(59, 130, 246),
    Green = Color3.fromRGB(74, 222, 128),
    Red = Color3.fromRGB(248, 113, 113),
    Amber = Color3.fromRGB(251, 191, 36),
}

local Theme = {}
for Key, Value in pairs(DefaultTheme) do
    Theme[Key] = Value
end
Toolkit.Theme = Theme -- mutated in place, never replaced

function Toolkit:SetTheme(Overrides)
    if type(Overrides) == "table" then
        for Key, Value in pairs(Overrides) do
            if DefaultTheme[Key] ~= nil and typeof(Value) == "Color3" then
                Theme[Key] = Value
            end
        end
    end
    return self
end

function Toolkit:ResetTheme()
    for Key, Value in pairs(DefaultTheme) do
        Theme[Key] = Value
    end
    return self
end

-- Every option of Launcher, with its default
Toolkit.Defaults = {
    Name = "ToolkitKeysystem",

    -- Header
    Title = "TOOLKIT",
    TitleHighlights = true,     -- true = TitleAccent is colored, false = shown as plain text
    TitleAccent = "KEYSYSTEM",  -- any text after Title. "" to disable
    TitleAccentColor = nil,     -- Color3 or "#RRGGBB" (default: Theme.Cyan)
    Tagline = "Access Beyond Ordinary",
    Version = "v2.6",
    Logo = "K",

    -- Premium / Freemium launcher
    Premium = false,            -- true = PREMIUM, false = FREEMIUM
    EnforceTier = true,         -- key tier must match the launcher (else "Wrong service")
    Marker = {
        Show = true,
        PremiumText = "PREMIUM",
        FreemiumText = "FREEMIUM",
        PremiumColor = nil,     -- default: Theme.Amber
        FreemiumColor = nil,    -- default: Theme.Blue
    },

    -- true  = notify config mistakes (wrong Junkie Service / Identifier / Provider,
    --         missing Junkie config, SDK failed to load)
    -- false = no toast, no error status for those.
    -- (user errors like "Invalid key" / "Key expired" / "Wrong service" always show)
    NotifyErrors = true,

    -- Description card
    Card = {
        Chip = "COMMUNITY",
        Title = "Toolkit Freemium",
        Subtitle = "Free access  •  Key required",
        Description = "Get a free key in a few quick steps, paste it below and press VERIFY. "
            .. "Your key is saved on this device so you won't need to repeat the steps every time.",
    },

    -- Bottom link (copies Discord to clipboard). Empty Discord hides the link.
    -- The link is also hidden when Premium = true.
    PremiumText = "Want instant access, no key steps?",
    PremiumAction = "Get Premium",
    Discord = "",

    -- Mercenary-style key flow
    GetKeyLink = "",    -- fixed key link. "" = ask Junkie (Junkie.get_key_link)
    AutoVerify = true,  -- check a saved key automatically (rejected saved key is deleted)
    LoadScript = true,  -- after a valid key: Junkie.load_script(key). Ignored if DefaultScript is set
    WaitForKey = true,  -- Launcher() blocks until a valid key was accepted
    KickOnBan = true,   -- kick the player when Junkie reports HWID_BANNED

    ToggleKey = Enum.KeyCode.RightShift,

    KeyFile = nil,      -- default: <Name>_Key.txt

    -- Optional script link loaded after a valid key (works in any game).
    -- nil = only verify the key.
    -- (a bare token still works too, and so does the old DefaultScriptId)
    DefaultScript = nil,

    Timing = {
        CheckDelay = 1.4,
        ValidDelay = 1.6,
        FailDelay = 0.9,
    },

    -- Junkie service (REQUIRED)
    -- Only Service is required. Identifier defaults to "" and Provider to "Mixed".
    Junkie = {
        Service = nil,
        Identifier = "",
        Provider = "Mixed",
        SDKUrl = "https://jnkie.com/sdk/library.lua",
    },

    -- Colors only, same keys as Toolkit.Theme
    Theme = nil,

    -- Optional callbacks
    OnVerified = nil, -- function(Key, IsPremium)
    OnClose = nil,    -- function()
}

local function Merge(Base, Over)
    local Out = {}
    for K, V in pairs(Base) do
        Out[K] = (type(V) == "table") and Merge(V, {}) or V
    end
    for K, V in pairs(Over or {}) do
        if type(V) == "table" and type(Out[K]) == "table" then
            Out[K] = Merge(Out[K], V)
        else
            Out[K] = V
        end
    end
    return Out
end

local function ResolveScript(Value)
    local Text = tostring(Value or ""):match("^%s*(.-)%s*$")
    if Text == "" then
        return nil, nil
    end
    for Part in Text:gmatch("%w+") do
        if #Part >= 32 and Part:match("^%x+$") then
            return Part, Text
        end
    end
    if Text:match("^https?://") then
        return nil, Text
    end
    return nil, nil
end

local White = Color3.new(1, 1, 1)
local GLOW_IMAGE = "rbxassetid://6014261993"
local GLOW_SLICE = Rect.new(49, 49, 450, 450)
local BASE_W, BASE_H = 440, 406

-- message kinds shared by the status bar and the toasts (read live from Theme)
local function KindPreset(Kind)
    local Presets = {
        info = { Theme.Cyan, "i" },
        loading = { Theme.Cyan, "…" },
        success = { Theme.Green, "✓" },
        warn = { Theme.Amber, "!" },
        error = { Theme.Red, "×" },
    }
    local P = Presets[Kind or "info"] or Presets.info
    return { Color = P[1], Icon = P[2] }
end

local function New(Class, Props, Parent)
    local Object = Instance.new(Class)
    for Key, Value in pairs(Props or {}) do
        Object[Key] = Value
    end
    Object.Parent = Parent
    return Object
end

local function Tween(Object, Time, Props, Style, Direction)
    local T = TweenService:Create(
        Object,
        TweenInfo.new(Time, Style or Enum.EasingStyle.Quart, Direction or Enum.EasingDirection.Out),
        Props
    )
    T:Play()
    return T
end

local function Corner(Parent, Radius)
    return New("UICorner", { CornerRadius = UDim.new(0, Radius or 10) }, Parent)
end

local function Stroke(Parent, Color, Thickness, Transparency)
    return New("UIStroke", {
        Color = Color or Theme.Stroke,
        Thickness = Thickness or 1,
        Transparency = Transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, Parent)
end

local function Gradient(Parent, A, B, Rotation)
    return New("UIGradient", { Color = ColorSequence.new(A, B), Rotation = Rotation or 0 }, Parent)
end

local function Pad(Parent, L, T, R, B)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, L),
        PaddingTop = UDim.new(0, T),
        PaddingRight = UDim.new(0, R),
        PaddingBottom = UDim.new(0, B),
    }, Parent)
end

local function Glow(Parent, Color, Extra, Transparency, ZIndex)
    return New("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, Extra, 1, Extra),
        Image = GLOW_IMAGE,
        ImageColor3 = Color,
        ImageTransparency = Transparency,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = GLOW_SLICE,
        ZIndex = ZIndex or 1,
    }, Parent)
end

local function Pulse(Object, Prop, A, B, Time)
    Object[Prop] = A
    TweenService:Create(
        Object,
        TweenInfo.new(Time or 1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { [Prop] = B }
    ):Play()
end

local function Trim(Text)
    return (tostring(Text or ""):match("^%s*(.-)%s*$"))
end

local function Escape(Text)
    return (tostring(Text or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Accepts a Color3 or a "#RRGGBB" / "RRGGBB" string. Returns a hex string (no #).
local function ToHexColor(Value, Fallback)
    if typeof(Value) == "Color3" then
        return Value:ToHex()
    end
    if type(Value) == "string" then
        local Hex = (Value:gsub("^%s*#?", ""):gsub("%s*$", ""))
        if Hex:match("^%x%x%x%x%x%x$") then
            return Hex:lower()
        end
    end
    return Fallback:ToHex()
end

-- Accepts a Color3 or a "#RRGGBB" string. Returns a Color3.
local function ToColor3(Value, Fallback)
    if typeof(Value) == "Color3" then
        return Value
    end
    if type(Value) == "string" then
        local Hex = (Value:gsub("^%s*#?", ""):gsub("%s*$", ""))
        if Hex:match("^%x%x%x%x%x%x$") then
            return Color3.fromRGB(
                tonumber(Hex:sub(1, 2), 16),
                tonumber(Hex:sub(3, 4), 16),
                tonumber(Hex:sub(5, 6), 16)
            )
        end
    end
    return Fallback
end

local function CopyText(Text)
    local Fn = setclipboard or toclipboard or (syn and syn.write_clipboard)
    return Fn ~= nil and (pcall(Fn, Text))
end

local function ReadFile(Path)
    local Ok, Data = pcall(function()
        if isfile and readfile and isfile(Path) then
            return readfile(Path)
        end
        return ""
    end)
    return (Ok and type(Data) == "string") and Data or ""
end

local function WriteFile(Path, Data)
    pcall(function()
        if writefile then
            writefile(Path, Data)
        end
    end)
end

local function DeleteFile(Path)
    pcall(function()
        if delfile and isfile and isfile(Path) then
            delfile(Path)
        end
    end)
end

-- game:HttpGet first, then the executor request functions as a fallback
local function SafeHttpGet(Url)
    local Ok, Res = pcall(function()
        return game:HttpGet(Url)
    end)
    if Ok and type(Res) == "string" and #Res > 100 then
        return Res
    end

    local Req = (syn and syn.request) or (http and http.request) or http_request
        or (fluxus and fluxus.request) or request
    if Req then
        local Ok2, R = pcall(function()
            return Req({ Url = Url, Method = "GET" })
        end)
        if Ok2 and R then
            if type(R) == "string" and #R > 100 then
                return R
            end
            if type(R) == "table" and type(R.Body) == "string" and #R.Body > 100 then
                return R.Body
            end
        end
    end

    if Ok and type(Res) == "string" then
        return Res
    end
    return nil
end

local function Label(Parent, Props)
    Props.BackgroundTransparency = Props.BackgroundTransparency or 1
    Props.ZIndex = Props.ZIndex or 5
    Props.Font = Props.Font or Enum.Font.Gotham
    Props.TextColor3 = Props.TextColor3 or Theme.Text
    Props.TextXAlignment = Props.TextXAlignment or Enum.TextXAlignment.Left
    return New("TextLabel", Props, Parent)
end

local function GradButton(Parent, Text, Size, Position, ColA, ColB)
    local Holder = New("Frame", {
        Size = Size,
        Position = Position,
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, Parent)
    Corner(Holder, 10)
    local G = Gradient(Holder, ColA, ColB, 20)
    local S = Stroke(Holder, White, 1, 0.85)

    local Button = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = Text,
        TextColor3 = White,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        ZIndex = 6,
    }, Holder)

    Button.MouseEnter:Connect(function()
        Tween(S, 0.18, { Transparency = 0.3 })
        Tween(G, 0.45, { Rotation = 200 })
    end)
    Button.MouseLeave:Connect(function()
        Tween(S, 0.18, { Transparency = 0.85 })
        Tween(G, 0.45, { Rotation = 20 })
    end)
    return Button
end

local function IconButton(Parent, Text, Position, HoverColor)
    local B = New("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = Position,
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = Text,
        TextColor3 = Theme.Muted,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        ZIndex = 6,
    }, Parent)
    Corner(B, 8)
    Stroke(B, Theme.Stroke, 1)
    B.MouseEnter:Connect(function()
        Tween(B, 0.15, { BackgroundColor3 = HoverColor, TextColor3 = Theme.Text })
    end)
    B.MouseLeave:Connect(function()
        Tween(B, 0.15, { BackgroundColor3 = Theme.Card, TextColor3 = Theme.Muted })
    end)
    return B
end

-- gui mount
local function GetContainers()
    local List = { CoreGui }
    local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if PlayerGui then
        table.insert(List, PlayerGui)
    end
    if gethui then
        local Ok, H = pcall(gethui)
        if Ok and H then
            table.insert(List, H)
        end
    end
    return List
end

local function RemoveGui(Name)
    for _, Container in ipairs(GetContainers()) do
        pcall(function()
            local Old = Container:FindFirstChild(Name)
            if Old then
                Old:Destroy()
            end
        end)
    end
end

local function NewScreenGui(Name, DisplayOrder)
    local Gui = New("ScreenGui", {
        Name = Name,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = DisplayOrder,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    local Ok = pcall(function()
        Gui.Parent = gethui and gethui() or CoreGui
    end)
    if not Ok or not Gui.Parent then
        Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    return Gui
end

----------------------------------------------------------------------
-- [3] NOTIFICATIONS
--
--   Toolkit:Notify(Title, Text, Kind, Opts)
--     Kind : "info" | "loading" | "success" | "warn" | "error"   (default "info")
--     Opts : Duration, Tag, Fill, Color, Icon
--       Tag  - a new toast with the same Tag replaces the old one instantly
--       Fill - bar FILLS over Duration and the toast stays until Dismiss()
--   Returns a handle: { Dismiss = function(Instant) }
--
--   The toast GUI is separate from the key GUI, so it keeps working
--   after the key GUI closes (and works without Launcher at all).
----------------------------------------------------------------------
local TOAST = {
    Height = 68,
    Radius = 20,
    Gap = 10,
    Margin = 16,
}

local Notif = { Gui = nil, Holder = nil, Width = 300, Toasts = {}, Counter = 0 }
local NoToast = { Dismiss = function() end }

local function EnsureNotif()
    if Notif.Gui and Notif.Gui.Parent and Notif.Holder and Notif.Holder.Parent then
        return true
    end

    RemoveGui(Toolkit.NotifName)

    local Camera = workspace.CurrentCamera
    local V = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
    Notif.Width = math.clamp(V.X - TOAST.Margin * 2, 230, 300)
    Notif.Toasts = {}

    Notif.Gui = NewScreenGui(Toolkit.NotifName, 1000000)
    Notif.Holder = New("Frame", {
        Name = "Holder",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -TOAST.Margin, 1, -TOAST.Margin),
        Size = UDim2.new(0, Notif.Width, 1, -TOAST.Margin * 2),
        BackgroundTransparency = 1,
    }, Notif.Gui)

    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, TOAST.Gap),
    }, Notif.Holder)

    return true
end

function Toolkit:Notify(Title, Text, Kind, Opts)
    if not EnsureNotif() then
        return NoToast
    end

    Opts = Opts or {}
    local Preset = KindPreset(Kind)
    local Color = Opts.Color or Preset.Color
    local Icon = Opts.Icon or Preset.Icon
    local Fill = Opts.Fill == true
    local Duration = Opts.Duration or Toolkit.Notifications.Duration
    local Max = Toolkit.Notifications.Max
    local OffX = Notif.Width + 40
    local Toasts = Notif.Toasts
    local NotifHolder = Notif.Holder

    if Opts.Tag then
        for _, T in ipairs({ table.unpack(Toasts) }) do
            if T.Tag == Opts.Tag then
                T.Dismiss(true)
            end
        end
    end
    while #Toasts >= Max do
        Toasts[1].Dismiss(true)
    end

    Notif.Counter = Notif.Counter + 1

    local Wrap = New("Frame", {
        Name = "Toast",
        Size = UDim2.new(1, 0, 0, TOAST.Height),
        BackgroundTransparency = 1,
        LayoutOrder = -Notif.Counter,
    }, NotifHolder)
    local Slider = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(OffX, 0),
        BackgroundTransparency = 1,
    }, Wrap)

    Glow(Slider, Color, 46, 0.84, 1)

    local Card = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, Slider)
    Corner(Card, TOAST.Radius)
    Gradient(Card, Theme.Bg2, Theme.Bg, 135)
    local CardStroke = Stroke(Card, White, 1.5, 0.2)
    Gradient(CardStroke, Color, Theme.Stroke, 45)

    local Badge = New("Frame", {
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.fromOffset(36, 36),
        BackgroundColor3 = Color,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, Card)
    Corner(Badge, 18)
    Stroke(Badge, Color, 1.2, 0.55)
    local BadgePop = New("UIScale", { Scale = 0 }, Badge)
    Label(Badge, {
        Size = UDim2.fromScale(1, 1),
        Text = Icon,
        TextColor3 = Color,
        TextSize = 17,
        Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })

    Label(Card, {
        Position = UDim2.fromOffset(62, 10),
        Size = UDim2.new(1, -76, 0, 16),
        Text = Title,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    })
    Label(Card, {
        Position = UDim2.fromOffset(62, 27),
        Size = UDim2.new(1, -76, 0, 26),
        Text = Text,
        TextColor3 = Theme.Muted,
        TextSize = 11,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 3,
    })

    local Track = New("Frame", {
        Position = UDim2.new(0, 18, 1, -12),
        Size = UDim2.new(1, -36, 0, 4),
        BackgroundColor3 = Color,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, Card)
    Corner(Track, 2)
    local Bar = New("Frame", {
        Size = Fill and UDim2.fromScale(0, 1) or UDim2.fromScale(1, 1),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, Track)
    Corner(Bar, 2)
    Gradient(Bar, Color, Color:Lerp(White, 0.45), 0)

    local Handle = { Tag = Opts.Tag, Gone = false }
    table.insert(Toasts, Handle)

    function Handle.Dismiss(Instant)
        if Handle.Gone then return end
        Handle.Gone = true

        local Index = table.find(Toasts, Handle)
        if Index then
            table.remove(Toasts, Index)
        end

        if Instant == true then
            pcall(function() Wrap:Destroy() end)
            return
        end

        Tween(Slider, 0.25, { Position = UDim2.fromOffset(OffX, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        task.delay(0.25, function()
            if Wrap.Parent then
                Tween(Wrap, 0.18, { Size = UDim2.new(1, 0, 0, 0) })
            end
            task.delay(0.2, function()
                pcall(function() Wrap:Destroy() end)
            end)
        end)
    end

    local Click = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 8,
    }, Card)
    Click.MouseButton1Click:Connect(function() Handle.Dismiss() end)
    Click.MouseEnter:Connect(function() Tween(CardStroke, 0.15, { Transparency = 0 }) end)
    Click.MouseLeave:Connect(function() Tween(CardStroke, 0.15, { Transparency = 0.2 }) end)

    Tween(Slider, 0.45, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
    task.delay(0.15, function()
        if not Handle.Gone then
            Tween(BadgePop, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
        end
    end)

    if Fill then
        Tween(Bar, Duration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
        task.delay(Duration + 15, Handle.Dismiss)
    else
        Tween(Bar, Duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
        task.delay(Duration, Handle.Dismiss)
    end

    return Handle
end

----------------------------------------------------------------------
-- [4] LAUNCHER
--   Toolkit:Launcher(Options) -> { Destroy, Show, Hide, SetStatus, Wait, IsVerified }
----------------------------------------------------------------------
function Toolkit:Launcher(Options)
    local Config = Merge(Toolkit.Defaults, Options)
    Config.KeyFile = Config.KeyFile or (Config.Name .. "_Key.txt")

    -- apply color overrides + notification overrides
    Toolkit:SetTheme(Config.Theme)
    if type(Options) == "table" and type(Options.Notifications) == "table" then
        for K, V in pairs(Options.Notifications) do
            Toolkit.Notifications[K] = V
        end
    end

    -- only one launcher at a time
    if Toolkit._Active then
        pcall(Toolkit._Active.Destroy, true)
    end
    RemoveGui(Config.Name)

    local Handle = {}

    -- Premium / Freemium launcher
    local IsPremium = Config.Premium == true
    local EnforceTier = Config.EnforceTier ~= false

    -- start the Junkie SDK download right away
    local SDKLib, SDKDone = nil, false
    task.spawn(function()
        local Ok, Lib = pcall(function()
            local Source = SafeHttpGet(Config.Junkie.SDKUrl)
            if type(Source) ~= "string" then
                error("empty response")
            end
            return loadstring(Source)()
        end)
        if Ok and Lib then
            SDKLib = Lib
        else
            warn("[Toolkit] Junkie SDK failed to load: " .. tostring(Lib))
        end
        SDKDone = true
    end)

    local ScreenGui = NewScreenGui(Config.Name, 999999)

    local Destroyed, Busy, Hidden = false, false, false
    local Verified = false
    Env.TOOLKIT_KEY_VERIFIED = false
    local Connections = {}
    local Junkie = nil

    local function Connect(Signal, Fn)
        local C = Signal:Connect(Fn)
        table.insert(Connections, C)
        return C
    end

    ------------------------------------------------------------------
    -- window
    ------------------------------------------------------------------
    local function ComputeScale()
        local Camera = workspace.CurrentCamera
        local V = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
        return math.clamp(math.min((V.X - 24) / BASE_W, (V.Y - 24) / BASE_H), 0.5, 1.1)
    end

    local TargetScale = ComputeScale()

    local Root = New("Frame", {
        Name = "Root",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(BASE_W, BASE_H),
        BackgroundTransparency = 1,
    }, ScreenGui)
    local RootScale = New("UIScale", { Scale = TargetScale * 0.85 }, Root)

    Glow(Root, Theme.Teal, 70, 0.6, 1)

    local Main = New("Frame", {
        Name = "Main",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    }, Root)
    Corner(Main, 16)
    Gradient(Main, Theme.Bg2, Theme.Bg, 135)

    local BorderStroke = Stroke(Main, White, 1.5, 0.1)
    local BorderGrad = New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Teal),
            ColorSequenceKeypoint.new(0.33, Theme.Cyan),
            ColorSequenceKeypoint.new(0.66, Theme.Violet),
            ColorSequenceKeypoint.new(1, Theme.Teal),
        }),
    }, BorderStroke)

    local function Orb(Color, X, Y, Size)
        local O = Glow(Main, Color, 0, 0.72, 1)
        O.Position = UDim2.fromScale(X, Y)
        O.Size = UDim2.fromOffset(Size, Size)
        return O
    end
    local Orb1 = Orb(Theme.Teal, 0.12, 0.1, 340)
    local Orb2 = Orb(Theme.Violet, 0.95, 0.95, 320)

    ------------------------------------------------------------------
    -- top bar
    ------------------------------------------------------------------
    local TopBar = New("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, 66),
        BackgroundTransparency = 1,
        ZIndex = 5,
    }, Main)

    local Logo = New("Frame", {
        Size = UDim2.fromOffset(40, 40),
        Position = UDim2.fromOffset(16, 13),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, TopBar)
    Corner(Logo, 12)
    local LogoGrad = Gradient(Logo, Theme.Teal, Theme.Blue, 45)
    Stroke(Logo, White, 1, 0.75)
    Label(Logo, {
        Size = UDim2.fromScale(1, 1),
        Text = Config.Logo,
        TextColor3 = White,
        TextSize = 22,
        Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- Title + accent
    --   TitleHighlights = true  -> accent text is colored (TitleAccentColor, default Theme.Cyan)
    --   TitleHighlights = false -> accent text is shown as plain text
    --   TitleAccent = ""        -> no accent at all
    local TitleText = Escape(Config.Title)
    if Trim(Config.TitleAccent) ~= "" then
        if Config.TitleHighlights == true then
            TitleText = TitleText .. ' <font color="#'
                .. ToHexColor(Config.TitleAccentColor, Theme.Cyan) .. '">'
                .. Escape(Config.TitleAccent) .. "</font>"
        else
            TitleText = TitleText .. " " .. Escape(Config.TitleAccent)
        end
    end
    Label(TopBar, {
        Position = UDim2.fromOffset(66, 12),
        Size = UDim2.new(1, -170, 0, 24),
        RichText = true,
        Text = TitleText,
        TextSize = 18,
        Font = Enum.Font.GothamBlack,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local TaglineText = Config.Tagline
    if Trim(Config.Version) ~= "" then
        TaglineText = TaglineText .. "  •  " .. Config.Version
    end
    Label(TopBar, {
        Position = UDim2.fromOffset(66, 37),
        Size = UDim2.new(1, -170, 0, 14),
        Text = TaglineText,
        TextColor3 = Theme.Muted,
        TextSize = 10,
        Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local CloseButton = IconButton(TopBar, "×", UDim2.new(1, -44, 0, 19), Theme.Red)
    local MinButton = IconButton(TopBar, "–", UDim2.new(1, -78, 0, 19), Theme.Teal)

    local Divider = New("Frame", {
        Position = UDim2.fromOffset(16, 65),
        Size = UDim2.new(1, -32, 0, 1),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, Main)
    New("UIGradient", {
        Color = ColorSequence.new(Theme.Teal, Theme.Cyan),
        Transparency = NumberSequence.new(0.2, 1),
    }, Divider)

    ------------------------------------------------------------------
    -- status bar
    ------------------------------------------------------------------
    local StatusBar = New("Frame", {
        Position = UDim2.fromOffset(16, 78),
        Size = UDim2.new(1, -32, 0, 48),
        BackgroundColor3 = Theme.Card:Lerp(Theme.Green, 0.16),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, Main)
    Corner(StatusBar, 12)
    local StatusStroke = Stroke(StatusBar, Theme.Green, 1.5, 0)

    local StatusDot = New("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new(0, 14, 0.5, -7),
        BackgroundColor3 = Theme.Green,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, StatusBar)
    Corner(StatusDot, 7)
    Pulse(StatusDot, "BackgroundTransparency", 0, 0.5, 0.8)

    local StatusLabel = Label(StatusBar, {
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -50, 1, 0),
        Text = "Ready  •  Get a key or paste yours",
        TextColor3 = White,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextWrapped = true,
        ZIndex = 6,
    })

    local StatusTweens = {}
    local function SetStatus(Text, Color)
        if Destroyed then return end
        Color = Color or Theme.Green
        StatusLabel.Text = Text

        for _, T in ipairs(StatusTweens) do
            T:Cancel()
        end
        StatusStroke.Color = Color
        StatusStroke.Thickness = 3.5
        StatusTweens = {
            Tween(StatusDot, 0.2, { BackgroundColor3 = Color }),
            Tween(StatusBar, 0.25, { BackgroundColor3 = Theme.Card:Lerp(Color, 0.16) }),
            Tween(StatusStroke, 0.6, { Thickness = 1.5 }),
        }
    end

    local function Report(Kind, StatusText, Title, Text, Opts)
        local Color = (Opts and Opts.Color) or KindPreset(Kind).Color
        SetStatus(StatusText, Color)
        Toolkit:Notify(Title, Text, Kind, Opts)
    end

    -- Config / developer mistakes (wrong Junkie Service, missing config, SDK failed...).
    --   NotifyErrors = true  -> status + toast, like Report
    --   NotifyErrors = false -> silent: no toast, no error status
    local function Problem(Kind, StatusText, Title, Text, Opts)
        if Config.NotifyErrors == true then
            Report(Kind, StatusText, Title, Text, Opts)
        else
            SetStatus("Ready  •  Paste your key and press VERIFY", Theme.Cyan)
        end
    end

    ------------------------------------------------------------------
    -- description card
    ------------------------------------------------------------------
    local Info = New("Frame", {
        Position = UDim2.fromOffset(16, 138),
        Size = UDim2.new(1, -32, 0, 104),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, Main)
    Corner(Info, 14)
    Gradient(Stroke(Info, White, 1.2, 0.1), Theme.Teal, Theme.Blue, 45)

    local Chip = Label(Info, {
        Position = UDim2.fromOffset(14, 12),
        Size = UDim2.fromOffset(0, 18),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 0.82,
        BackgroundColor3 = Theme.Teal,
        Text = Config.Card.Chip,
        TextColor3 = Theme.Teal:Lerp(White, 0.35),
        TextSize = 9,
        Font = Enum.Font.GothamBold,
    })
    Corner(Chip, 6)
    Pad(Chip, 8, 0, 8, 0)

    -- Premium / Freemium marker (top right of the card)
    if Config.Marker.Show ~= false then
        local MarkerColor = IsPremium
            and ToColor3(Config.Marker.PremiumColor, Theme.Amber)
            or ToColor3(Config.Marker.FreemiumColor, Theme.Blue)
        local MarkerText = IsPremium and Config.Marker.PremiumText or Config.Marker.FreemiumText

        local MarkerPill = Label(Info, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 0, 12),
            Size = UDim2.fromOffset(0, 18),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 0.82,
            BackgroundColor3 = MarkerColor,
            Text = tostring(MarkerText),
            TextColor3 = MarkerColor:Lerp(White, 0.35),
            TextSize = 9,
            Font = Enum.Font.GothamBold,
        })
        Corner(MarkerPill, 6)
        Pad(MarkerPill, 8, 0, 8, 0)
        Stroke(MarkerPill, MarkerColor, 1, 0.6)
    end

    local InfoTitle = Label(Info, {
        Position = UDim2.fromOffset(14, 34),
        Size = UDim2.new(1, -28, 0, 22),
        Text = Config.Card.Title,
        TextColor3 = White,
        TextSize = 18,
        Font = Enum.Font.GothamBlack,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    Gradient(InfoTitle, Theme.Teal:Lerp(White, 0.25), Theme.Blue:Lerp(White, 0.25), 0)

    Label(Info, {
        Position = UDim2.fromOffset(14, 56),
        Size = UDim2.new(1, -28, 0, 14),
        Text = Config.Card.Subtitle,
        TextColor3 = Theme.Cyan,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    Label(Info, {
        Position = UDim2.fromOffset(14, 72),
        Size = UDim2.new(1, -28, 0, 28),
        Text = Config.Card.Description,
        TextColor3 = Theme.Muted,
        TextSize = 10,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })

    ------------------------------------------------------------------
    -- key row + buttons
    ------------------------------------------------------------------
    Label(Main, {
        Position = UDim2.fromOffset(18, 254),
        Size = UDim2.fromOffset(200, 14),
        Text = "YOUR KEY",
        TextColor3 = Theme.Muted,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
    })

    local KeyBox = New("TextBox", {
        Position = UDim2.fromOffset(16, 272),
        Size = UDim2.new(1, -32, 0, 40),
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "Paste your key here...",
        PlaceholderColor3 = Theme.Muted,
        TextColor3 = Theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
    }, Main)
    Corner(KeyBox, 10)
    Pad(KeyBox, 12, 0, 12, 0)
    local KeyStroke = Stroke(KeyBox, Theme.Stroke, 1.2)

    local GetKeyButton = GradButton(
        Main, "GET KEY",
        UDim2.fromOffset(198, 40), UDim2.fromOffset(16, 324),
        Theme.Teal, Theme.Blue
    )
    local VerifyButton = GradButton(
        Main, "VERIFY KEY",
        UDim2.fromOffset(198, 40), UDim2.fromOffset(226, 324),
        Theme.Violet, Theme.Pink
    )

    local PremiumLink = New("TextButton", {
        Position = UDim2.fromOffset(16, 372),
        Size = UDim2.new(1, -32, 0, 18),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        RichText = true,
        Text = Escape(Config.PremiumText) .. '  <font color="#' .. Theme.Pink:ToHex() .. '"><b>'
            .. Escape(Config.PremiumAction) .. "</b></font>",
        TextColor3 = Theme.Muted,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        Visible = (Trim(Config.Discord) ~= "") and not IsPremium,
        ZIndex = 5,
    }, Main)

    ------------------------------------------------------------------
    -- minimized bubble
    ------------------------------------------------------------------
    local Bubble = New("Frame", {
        Size = UDim2.fromOffset(48, 48),
        Position = UDim2.new(1, -64, 0.5, -24),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        Visible = false,
    }, ScreenGui)
    Corner(Bubble, 24)
    Gradient(Bubble, Theme.Teal, Theme.Blue, 45)
    Stroke(Bubble, White, 1.5, 0.6)
    local BubbleButton = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = Config.Logo,
        TextColor3 = White,
        TextSize = 20,
        Font = Enum.Font.GothamBlack,
    }, Bubble)

    local function SetHidden(Value)
        if Destroyed then return end
        Hidden = Value
        Root.Visible = not Value
        Bubble.Visible = Value
    end

    ------------------------------------------------------------------
    -- close / destroy (toasts live in their own gui and survive this)
    ------------------------------------------------------------------
    local function DestroyUI(Instant)
        if Destroyed then return end
        Destroyed, Busy = true, true

        for _, C in ipairs(Connections) do
            C:Disconnect()
        end
        if Toolkit._Active == Handle then
            Toolkit._Active = nil
        end

        if Instant == true then
            ScreenGui:Destroy()
            return
        end

        Tween(RootScale, 0.25, { Scale = 0.8 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        task.delay(0.28, function()
            ScreenGui:Destroy()
        end)
    end

    ------------------------------------------------------------------
    -- error classification
    --   Dev = true  -> config mistake, only shown when NotifyErrors = true
    --   Dev = false -> user mistake, always shown
    ------------------------------------------------------------------
    local Rejections = {
        invalid = {
            Kind = "error",
            Title = "Invalid key",
            Text = "That key isn't valid. Check it and try again.",
            Status = "Invalid key  •  Check it and try again",
        },
        expired = {
            Kind = "warn",
            Title = "Key expired",
            Text = "This key has expired. Press GET KEY for a new one.",
            Status = "Key expired  •  Press GET KEY for a new one",
        },
        hwid = {
            Kind = "error",
            Title = "Key locked",
            Text = "HWID limit reached for this key.",
            Status = "HWID limit reached for this key",
        },
        mismatch = {
            Kind = "error",
            Title = "Wrong service",
            Text = "This key is for a different service.",
            Status = "Key is for a different service",
        },
        banned = {
            Kind = "error",
            Title = "Hardware banned",
            Text = "This device is banned from the service.",
            Status = "Hardware banned",
        },
        rate = {
            Kind = "warn",
            Title = "Slow down",
            Text = "Too many attempts. Wait a bit then try again.",
            Status = "Too many attempts  •  Wait a bit then try again",
        },
        service = {
            Kind = "error",
            Title = "Invalid Junkie service",
            Text = "Service, Identifier or Provider is wrong. Check your Launcher config.",
            Status = "Invalid Junkie service  •  Check Service, Identifier and Provider",
            Dev = true,
        },

        -- tier mismatch (user mistake, always shown)
        premium_in_freemium = {
            Kind = "error",
            Title = "Wrong service",
            Text = "This is a Premium key. It can't be redeemed in the Freemium version.",
            Status = "Wrong service  •  This is a Premium key, use the Premium version",
        },
        freemium_in_premium = {
            Kind = "error",
            Title = "Wrong service",
            Text = "This is a Freemium key. It can't be redeemed in the Premium version.",
            Status = "Wrong service  •  This is a Freemium key, use the Freemium version",
        },
    }

    local function ClassifyError(Err)
        local E = string.upper(tostring(Err or ""))
        if E:find("BANNED") then return "banned" end            -- HWID_BANNED
        if E:find("EXPIRED") then return "expired" end          -- KEY_EXPIRED
        if E:find("SERVICE_MISMATCH") then return "mismatch" end -- key of another service (user mistake)
        if E:find("HWID") then return "hwid" end                -- HWID_MISMATCH
        if E:find("RATE_LIMIT") then return "rate" end          -- RATE_LIMITTED
        if E:find("SERVICE") or E:find("IDENTIFIER") or E:find("PROVIDER") then
            return "service"                                    -- wrong Junkie config (dev mistake)
        end
        return "invalid"
    end

    ------------------------------------------------------------------
    -- key link (prefetched so GET KEY is instant)
    ------------------------------------------------------------------
    local SavedKey = Trim(ReadFile(Config.KeyFile))

    local LINK_TTL = 240
    local LinkCache = { Link = nil, Err = nil, At = 0, Fetching = false }
    local GetBusy = false

    local function LinkFresh()
        return LinkCache.Link ~= nil and (os.clock() - LinkCache.At) < LINK_TTL
    end

    local function FetchLink()
        if LinkFresh() then
            return LinkCache.Link, nil
        end
        if LinkCache.Fetching then
            while LinkCache.Fetching do
                task.wait()
            end
            return LinkCache.Link, LinkCache.Err
        end

        LinkCache.Fetching = true
        local Ok, Link, Err = pcall(Junkie.get_key_link)
        if not Ok then
            Ok, Link, Err = pcall(Junkie.get_key_link)
        end

        if Ok and type(Link) == "string" and Link ~= "" then
            LinkCache.Link, LinkCache.Err, LinkCache.At = Link, nil, os.clock()
        else
            LinkCache.Link = nil
            LinkCache.Err = Ok and (Err or "ERROR") or "REQUEST_FAILED"
        end
        LinkCache.Fetching = false
        return LinkCache.Link, LinkCache.Err
    end

    local function DeliverLink(Link, Err)
        if Destroyed then return end
        local Opts = { Tag = "link" }

        if Link then
            if CopyText(Link) then
                Report("success", "Key link copied!  •  Paste it in your browser",
                    "Key link copied", "Paste it in your browser to get your key.", Opts)
            else
                KeyBox.Text = Link
                Report("warn", "Clipboard unavailable  •  Link placed in the box, copy it manually",
                    "Clipboard unavailable", "The link was placed in the key box. Copy it manually.", Opts)
            end
        elseif Err == "RATE_LIMITTED" then
            Report("warn", "Too many requests  •  Wait a bit then try again",
                "Too many requests", "Wait a bit then try again.", Opts)
        elseif Err == "REQUEST_FAILED" then
            Report("error", "Could not request a key link. Try again.",
                "Request failed", "Could not request a key link. Try again.", Opts)
        elseif ClassifyError(Err) == "service" then
            local R = Rejections.service
            Problem(R.Kind, R.Status, R.Title, R.Text, Opts)
        else
            warn("[Toolkit] get_key_link: " .. tostring(Err))
            Report("warn", "Link not ready  •  Please wait ~5 minutes then try again",
                "Link not ready", "Please wait about 5 minutes then press GET KEY again.", Opts)
        end
    end

    local function GetKey()
        if Busy or GetBusy or Destroyed then return end

        -- fixed link from the config (Mercenary's GetKeyLink)
        if type(Config.GetKeyLink) == "string" and Config.GetKeyLink ~= "" then
            DeliverLink(Config.GetKeyLink, nil)
            return
        end

        if not Junkie then
            SetStatus("Junkie SDK isn't ready yet. Try again in a moment.", Theme.Amber)
            return
        end

        if LinkFresh() then
            DeliverLink(LinkCache.Link, nil)
            return
        end

        GetBusy = true
        SetStatus("Requesting your key link...", Theme.Cyan)
        task.spawn(function()
            local Link, Err = FetchLink()
            GetBusy = false
            DeliverLink(Link, Err)
        end)
    end

    ------------------------------------------------------------------
    -- verify
    ------------------------------------------------------------------
    local function Verify(IsAuto)
        if Busy or Destroyed then return end

        local Timing = Config.Timing
        local Key = Trim(KeyBox.Text)

        if Key == "" then
            Report("warn", "Enter your key first, or press GET KEY.",
                "Missing key", "Paste your key first, or press GET KEY.", { Tag = "verify" })
            return
        end
        if not Junkie then
            SetStatus("Junkie SDK isn't ready yet. Try again in a moment.", Theme.Amber)
            return
        end

        Busy = true
        local Started = os.clock()
        SetStatus("Checking your key...", Theme.Cyan)
        local Checking = Toolkit:Notify("Checking key", "Contacting the key server...", "loading", {
            Fill = true, Duration = Timing.CheckDelay, Tag = "verify",
        })

        task.spawn(function()
            local Ok, Result = pcall(Junkie.check_key, Key)

            local Remaining = Timing.CheckDelay - (os.clock() - Started)
            if Remaining > 0 then
                task.wait(Remaining)
            end
            if Destroyed then return end
            Checking.Dismiss(true)

            local function Fail(Kind, StatusText, Title, Text, IsDev)
                local Opts = { Tag = "verify", Duration = 5 }
                if IsDev then
                    Problem(Kind, StatusText, Title, Text, Opts)
                else
                    Report(Kind, StatusText, Title, Text, Opts)
                end
                task.wait(Timing.FailDelay)
                if not Destroyed then
                    Busy = false
                end
            end

            if not Ok or type(Result) ~= "table" then
                return Fail("error", "Could not check the key. Try again.",
                    "Check failed", "Couldn't reach the key server. Try again.")
            end

            if not Result.valid then
                local Class = ClassifyError(Result.error or Result.message)

                -- Junkie banned this device
                if Class == "banned" then
                    if Config.KickOnBan == true then
                        pcall(function()
                            LocalPlayer:Kick("Hardware banned")
                        end)
                    end
                    local R = Rejections.banned
                    return Fail(R.Kind, R.Status, R.Title, R.Text, false)
                end

                -- a saved key that Junkie rejects is deleted so it isn't tried again
                if Key == SavedKey and (Class == "invalid" or Class == "expired"
                    or Class == "hwid" or Class == "mismatch") then
                    DeleteFile(Config.KeyFile)
                    SavedKey = ""
                end

                local R = Rejections[Class]
                return Fail(R.Kind, R.Status, R.Title, R.Text, R.Dev == true)
            end

            -- valid key: detect its tier (Junkie check_key -> is_premium)
            local KeyIsPremium = Result.is_premium == true

            if EnforceTier then
                if KeyIsPremium and not IsPremium then
                    local R = Rejections.premium_in_freemium
                    return Fail(R.Kind, R.Status, R.Title, R.Text, false)
                end
                if (not KeyIsPremium) and IsPremium then
                    local R = Rejections.freemium_in_premium
                    return Fail(R.Kind, R.Status, R.Title, R.Text, false)
                end
            end

            -- accepted (the key is only saved / exposed after the tier check passes)
            WriteFile(Config.KeyFile, Key)
            Env.SCRIPT_KEY = Key
            Env.TOOLKIT_KEY_VERIFIED = true
            Env.TOOLKIT_KEY_PREMIUM = KeyIsPremium
            Verified = true
            if type(Config.OnVerified) == "function" then
                task.spawn(Config.OnVerified, Key, KeyIsPremium)
            end

            local TierName = KeyIsPremium and "Premium" or "Freemium"
            Report("success", TierName .. " key valid  •  Access granted",
                TierName .. " key valid", "Access granted.", { Tag = "verify" })

            task.wait(Timing.ValidDelay)
            if Destroyed then return end
            DestroyUI()

            -- optional: load a script after a valid key (works in any game)
            local Source = Config.DefaultScript or Config.DefaultScriptId
            if Source then
                Toolkit:Notify("Please wait", "May take longer to load depending on jnkie servers.", "info", {
                    Duration = 8, Tag = "load",
                })
                task.wait()

                local Token, Link = ResolveScript(Source)
                local RunOk, RunErr = false, "invalid script link"

                if Token then
                    Junkie.script_id = Token
                    RunOk, RunErr = pcall(Junkie.load_script, Key)
                elseif Link then
                    RunOk, RunErr = pcall(function()
                        local Fn, CompileErr = loadstring(game:HttpGet(Link))
                        if not Fn then
                            error(CompileErr)
                        end
                        Fn()
                    end)
                end

                if not RunOk then
                    warn("[Toolkit] load_script failed: " .. tostring(RunErr))
                    Toolkit:Notify("Load failed", "Could not load the script. Try again.", "error", {
                        Duration = 6, Tag = "load",
                    })
                end
            elseif Config.LoadScript ~= false then
                -- Mercenary flow: Junkie.load_script(key) loads the script protected on the service
                local RunOk, RunErr = pcall(Junkie.load_script, Key)
                if not RunOk then
                    warn("[Toolkit] load_script failed: " .. tostring(RunErr))
                end
            end
        end)
    end

    ------------------------------------------------------------------
    -- wiring
    ------------------------------------------------------------------
    GetKeyButton.MouseButton1Click:Connect(GetKey)
    VerifyButton.MouseButton1Click:Connect(function()
        Verify()
    end)

    KeyBox.Focused:Connect(function()
        Tween(KeyStroke, 0.15, { Color = Theme.Teal })
    end)
    KeyBox.FocusLost:Connect(function(EnterPressed)
        Tween(KeyStroke, 0.15, { Color = Theme.Stroke })
        if EnterPressed then
            Verify()
        end
    end)

    PremiumLink.MouseButton1Click:Connect(function()
        if Destroyed then return end
        if CopyText(Config.Discord) then
            Report("success", "Discord invite copied  •  Premium is sold there",
                "Discord invite copied", "Premium is sold there.", { Tag = "discord", Color = Theme.Pink })
        else
            Report("error", "Unable to copy the Discord invite.",
                "Copy failed", "Unable to copy the Discord invite.", { Tag = "discord" })
        end
    end)

    -- Close: red X toast (same style as the green check on success)
    CloseButton.MouseButton1Click:Connect(function()
        if Destroyed then return end
        DestroyUI()
        Toolkit:Notify("Closed", "Key system closed. See you next time.", "error", {
            Duration = 3.5, Tag = "close",
        })
        if type(Config.OnClose) == "function" then
            task.spawn(Config.OnClose)
        end
    end)
    MinButton.MouseButton1Click:Connect(function() SetHidden(true) end)
    BubbleButton.MouseButton1Click:Connect(function() SetHidden(false) end)

    Connect(UserInputService.InputBegan, function(Input, Processed)
        if Processed or Destroyed then return end
        if Input.KeyCode == Config.ToggleKey then
            SetHidden(not Hidden)
        end
    end)

    -- drag
    local Dragging, DragStart, StartPosition, DragInput = false, nil, nil, nil

    local function IsPointer(Input)
        return Input.UserInputType == Enum.UserInputType.MouseButton1
            or Input.UserInputType == Enum.UserInputType.Touch
    end

    TopBar.InputBegan:Connect(function(Input)
        if not IsPointer(Input) then return end
        Dragging = true
        DragStart = Input.Position
        StartPosition = Root.Position
        Input.Changed:Connect(function()
            if Input.UserInputState == Enum.UserInputState.End then
                Dragging = false
            end
        end)
    end)

    TopBar.InputChanged:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement
            or Input.UserInputType == Enum.UserInputType.Touch then
            DragInput = Input
        end
    end)

    Connect(UserInputService.InputChanged, function(Input)
        if Input == DragInput and Dragging then
            local Delta = (Input.Position - DragStart) / RootScale.Scale
            Root.Position = UDim2.new(
                StartPosition.X.Scale, StartPosition.X.Offset + Delta.X,
                StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y
            )
        end
    end)

    -- ambient animation (paused while minimized)
    local Elapsed = 0
    Connect(RunService.Heartbeat, function(Dt)
        if Hidden then return end
        Elapsed = Elapsed + Dt
        BorderGrad.Rotation = (Elapsed * 45) % 360
        LogoGrad.Rotation = (Elapsed * 60) % 360
        Orb1.Position = UDim2.fromScale(0.12 + math.sin(Elapsed * 0.5) * 0.07, 0.1 + math.cos(Elapsed * 0.4) * 0.06)
        Orb2.Position = UDim2.fromScale(0.95 + math.cos(Elapsed * 0.45) * 0.07, 0.95 + math.sin(Elapsed * 0.35) * 0.06)
    end)

    ------------------------------------------------------------------
    -- startup (no auto verify: the user always presses VERIFY KEY)
    ------------------------------------------------------------------
    Tween(RootScale, 0.4, { Scale = TargetScale }, Enum.EasingStyle.Back)

    SetStatus("Connecting to key service...", Theme.Cyan)

    if SavedKey ~= "" then
        KeyBox.Text = SavedKey
    end

    task.spawn(function()
        while not SDKDone and not Destroyed do
            task.wait()
        end
        if Destroyed then return end

        if not SDKLib then
            Problem("error", "Key service unreachable  •  Check your connection",
                "SDK failed", "Could not load the Junkie SDK. Check your connection.", { Duration = 6, Tag = "sdk" })
            return
        end

        local J = Config.Junkie
        if not J.Service then
            Problem("error", "Junkie config missing  •  Set Junkie.Service",
                "Config missing", "Set Junkie.Service in Launcher.", { Duration = 8, Tag = "sdk" })
            return
        end

        Junkie = SDKLib
        Junkie.service = J.Service
        Junkie.identifier = J.Identifier or ""
        Junkie.provider = J.Provider or "Mixed"

        if SavedKey ~= "" then
            if Config.AutoVerify ~= false then
                SetStatus("Saved key found  •  Verifying...", Theme.Cyan)
                task.wait(0.8)
                if not Destroyed then
                    Verify(true)
                end
            else
                SetStatus("Saved key found  •  Press VERIFY KEY", Theme.Cyan)
            end
        else
            SetStatus("Ready  •  Get a key or paste yours", Theme.Green)
            -- prefetch the key link so GET KEY is instant
            task.spawn(FetchLink)
        end
    end)

    -- blocks until a valid key was accepted. If the window is closed without a
    -- valid key it never returns, so the code after Launcher never runs.
    local function WaitForKey()
        while not Verified do
            if Destroyed then
                while true do
                    task.wait(1)
                end
            end
            task.wait(0.1)
        end
    end

    Handle.Destroy = DestroyUI
    Handle.Show = function() SetHidden(false) end
    Handle.Hide = function() SetHidden(true) end
    Handle.SetStatus = SetStatus
    Handle.Wait = WaitForKey
    Handle.IsVerified = function() return Verified end
    Toolkit._Active = Handle

    if Config.WaitForKey == true then
        WaitForKey()
    end

    return Handle
end

-- usable from other scripts after the key GUI is gone: getgenv().Toolkit:Notify(...)
Env.Toolkit = Toolkit

return Toolkit
