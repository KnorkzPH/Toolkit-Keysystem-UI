----------------------------------------------------------------------
-- [1] LIBRARY
----------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local Env = (getgenv and getgenv()) or _G

local Toolkit = {
    Version = "3.5",
    NotifName = "ToolkitKeysystem_Notifs",
    -- editable anytime (or through Notifications = { ... } in Toolkit:Launcher):
    --   Max          : how many toasts can show at once
    --   Duration     : default seconds a toast stays
    --   CornerRadius : corner of the toast. A number below 1 is a UICorner SCALE (0 = fully square,
    --                  0.5 = pill), a number of 1 or more is PIXELS, or pass a UDim.
    --                  Default 0.12 = squared. Use 0.35 for a rounder look.
    --   Width        : toast width in pixels (shrinks on small screens)
    --   TitleSize / TextSize : text sizes (bigger = easier to read)
    --   TitleColor / TextColor : Color3 (default pure white)
    Notifications = {
        Max = 4,
        Duration = 4,
        CornerRadius = 0.12,
        Width = 340,
        TitleSize = 18,
        TextSize = 15,
        TitleColor = nil,
        TextColor = nil,
    },
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
    Premium = false,            -- true = PREMIUM, false = FREEMIUM, "both" = accepts either key
    EnforceTier = true,         -- key tier must match the launcher (else "Wrong service")
    Marker = {
        Show = true,
        PremiumText = "PREMIUM",
        FreemiumText = "FREEMIUM",
        PremiumColor = nil,     -- default: Theme.Amber
        FreemiumColor = nil,    -- default: Theme.Blue
        BothText = "FREEMIUM + PREMIUM", -- shown when Premium = "both"
        BothColor = nil,        -- default: Theme.Violet
    },

    -- true  = notify config mistakes (wrong Junkie Service / Identifier / Provider,
    --         missing Junkie config, missing / invalid script link, SDK failed to load)
    -- false = no toast, no error status for those.
    -- (user errors like "Invalid key" / "Key expired" / "Wrong service" always show)
    NotifyErrors = true,

    -- Description card
    Card = {
        Chip = "Public",
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
    -- (AUTO VERIFY is now a toggle button in the GUI. It starts OFF and the user turns it ON.)
    LoadScript = true,  -- true = a missing script (no matching Games entry) is reported as a config error. false = only verify the key
                        -- when no script is configured. Ignored when a Games entry matches
    WaitForKey = true,  -- Launcher() blocks until a valid key was accepted
    KickOnBan = true,   -- kick the player when Junkie reports HWID_BANNED

    -- Notification shown right after a successful verification, while the script loads.
    -- Set WaitNotice = false to turn it off.
    WaitNotice = {
        Enabled = true,
        Title = "Wait",
        Description = "Please wait while Jnkie loads the script. It may take a while depending on Jnkie servers.",
        Duration = 8,
    },

    ToggleKey = Enum.KeyCode.RightShift,

    KeyFile = nil,      -- default: <Name>_Key.txt
    SettingsFile = nil, -- default: <Name>_Settings.txt (stores the AUTO VERIFY toggle)

    Timing = {
        CheckDelay = 1.4,
        ValidDelay = 1.6,
        FailDelay = 0.9,
    },

    -- Junkie service (REQUIRED)
    -- Only Service is required. Identifier defaults to "" and Provider to none (nil).
    -- Every field below is a string, or { Premium = "...", Freemium = "..." } so the
    -- Premium and Freemium versions each get their own Junkie values:
    --   Service / Identifier / Provider : picked by the launcher (Premium = true / false)
    Junkie = {
        Service = nil,
        Identifier = "",
        Provider = "", -- empty = none, no provider is set on the SDK
        SDKUrl = "https://jnkie.com/sdk/library.lua",
    },

    -- Per-game scripts, each with its own Premium / Freemium link (or id).
    -- If an entry matches the current PlaceId its links are loaded after the key is verified.
    -- No match = nothing breaks: the key still works, there is just no script to load.
    --   Games = { { Name = "...", PlaceId = 123, Premium = "<link>", Freemium = "<link>" }, ... }
    Games = nil,
    -- Or keep the list online so you can add games without touching the loader.
    -- The link must return the same table:  return { { Name = ..., PlaceId = ..., ... }, ... }
    GamesUrl = nil,

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

----------------------------------------------------------------------
-- [2] HELPERS
----------------------------------------------------------------------
local UUID_PATTERN = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

-- Returns Tokens (script ids), Link (http url or nil), Invalid (text given, but neither a valid url nor an id).
-- A public download url carries its script id in the path:
--   https://api.jnkie.com/api/v1/luascripts/public/<ID>/download
local function ResolveScript(Value)
    local Text = tostring(Value or ""):match("^%s*(.-)%s*$")
    Text = Text:gsub("^[\"'`]+", ""):gsub("[\"'`]+$", "")
    Text = Text:match("^%s*(.-)%s*$")
    if Text == "" then
        return {}, nil, false
    end

    local Tokens, Seen = {}, {}
    local function Add(T)
        if not Seen[T] then
            Seen[T] = true
            table.insert(Tokens, T)
        end
    end

    if Text:match("^https?://") then
        if not Text:match("^https?://[^%s/]+%S*$") then
            return {}, nil, true
        end

        local PathId = Text:match("/luascripts/public/([%w_%-]+)/download")
        if PathId then
            Add(PathId)
        end
        if #Tokens == 0 then
            for Part in Text:gmatch(UUID_PATTERN) do
                Add(Part)
            end
        end
        return Tokens, Text, false
    end

    for Part in Text:gmatch(UUID_PATTERN) do
        Add(Part)
    end
    for Part in Text:gmatch("%w+") do
        if #Part >= 32 and Part:match("^%x+$") then
            Add(Part)
        end
    end

    return Tokens, nil, #Tokens == 0
end

local function PickByTier(Value, KeyIsPremium)
    if type(Value) == "table" then
        local Chosen
        if KeyIsPremium then
            Chosen = Value.Premium
        else
            Chosen = Value.Freemium
        end
        return Chosen or Value.Default
    end
    return Value
end

-- "" counts as not set
local function NonEmpty(Value, Default)
    if Value == nil or Value == "" then
        return Default
    end
    return Value
end

-- Maps a Junkie error string to a rejection class (shared by Launcher and CheckKey)
--   banned | expired | mismatch | hwid | rate | service | invalid
local function ClassifyJunkieError(Err)
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

-- Finds the entry of a Games list that belongs to the current game.
--   Games = {
--       { Name = "My Game", PlaceId = 123, Premium = "<link or id>", Freemium = "<link or id>" },
--       { Name = "Other",   PlaceIds = { 1, 2 }, GameId = 456, Premium = "...", Freemium = "..." },
--   }
-- An entry matches by PlaceId, PlaceIds (list) or GameId (universe).
local function ResolveGame(Games)
    if type(Games) ~= "table" then
        return nil
    end
    for _, Entry in ipairs(Games) do
        if type(Entry) == "table" then
            if Entry.PlaceId ~= nil and tostring(Entry.PlaceId) == tostring(game.PlaceId) then
                return Entry
            end
            if Entry.GameId ~= nil and tostring(Entry.GameId) == tostring(game.GameId) then
                return Entry
            end
            if type(Entry.PlaceIds) == "table" then
                for _, Id in ipairs(Entry.PlaceIds) do
                    if tostring(Id) == tostring(game.PlaceId) then
                        return Entry
                    end
                end
            end
        end
    end
    return nil
end

function Toolkit:ResolveGame(Games)
    return ResolveGame(Games)
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

-- Service / Identifier / Provider values: numbers become text, spaces are trimmed,
-- and anything empty or of the wrong type (nil, table, boolean) falls back to Default
local function CleanText(Value, Default)
    if Value == nil or type(Value) == "table" or type(Value) == "boolean" then
        return Default
    end
    local Text = Trim(Value)
    if Text == "" then
        return Default
    end
    return Text
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

local StatusNames = {
    [400] = "bad request",
    [401] = "unauthorized",
    [403] = "forbidden",
    [404] = "not found",
    [429] = "rate limited",
    [500] = "server error",
    [502] = "bad gateway",
    [503] = "service unavailable",
}

local function DescribeStatus(Code)
    local Name = StatusNames[Code]
    return "HTTP " .. tostring(Code) .. (Name and (" (" .. Name .. ")") or "")
end

-- error pages come back as HTML, they must never reach loadstring
local function IsHtml(Body)
    local Head = (Body:sub(1, 400):gsub("^\239\187\191", ""):gsub("^%s+", "")):lower()
    return Head:find("^<!doctype") ~= nil
        or Head:find("^<html") ~= nil
        or Head:find("^<head") ~= nil
        or Head:find("^<body") ~= nil
end

local HTML_ERROR = "server returned an HTML page instead of a script"

local function GetRequestFunction()
    return (syn and syn.request) or (http and http.request) or http_request
        or (fluxus and fluxus.request) or request
end

-- GET a url. Returns Body, or nil + error text + HTTP status code (when known).
-- The executor request function is used first (it exposes the status code),
-- game:HttpGet is the fallback. Non-2xx answers and HTML pages are rejected.
local function SafeHttpGet(Url)
    Url = Trim(Url)
    if not Url:match("^https?://[^%s/]+%S*$") then
        return nil, "invalid URL"
    end

    local Req = GetRequestFunction()
    if Req then
        local Ok, R = pcall(function()
            return Req({ Url = Url, Method = "GET" })
        end)
        if Ok and type(R) == "table" then
            local Code = tonumber(R.StatusCode) or tonumber(R.Status)
            if Code and (Code < 200 or Code >= 300) then
                return nil, DescribeStatus(Code), Code
            end
            if type(R.Body) == "string" and R.Body ~= "" then
                if IsHtml(R.Body) then
                    return nil, HTML_ERROR, Code
                end
                return R.Body, nil, Code
            end
            if Code then
                return nil, "empty response", Code
            end
        end
    end

    local Ok, Res = pcall(function()
        return game:HttpGet(Url)
    end)
    if not Ok then
        local Code = tonumber(tostring(Res):match("HTTP%s*(%d%d%d)"))
        if Code then
            return nil, DescribeStatus(Code), Code
        end
        return nil, tostring(Res)
    end
    if type(Res) ~= "string" or Res == "" then
        return nil, "empty response"
    end
    if IsHtml(Res) then
        return nil, HTML_ERROR
    end
    return Res
end

-- Loads a games list from a link, so you can add games without touching the loader.
-- The link must return a Lua table:  return { { Name = ..., PlaceId = ..., Premium = ..., Freemium = ... }, ... }
local function FetchGames(Url)
    local Ok, Result = pcall(function()
        local Source, Err = SafeHttpGet(Url)
        if type(Source) ~= "string" then
            error(Err or "empty response", 0)
        end
        local Compiled, CompileErr = loadstring(Source)
        if not Compiled then
            error(CompileErr)
        end
        return Compiled()
    end)
    if Ok and type(Result) == "table" then
        return Result
    end
    warn("[Toolkit] GamesUrl failed to load: " .. tostring(Result))
    return nil
end

-- Which script a verified key loads.
--   Id   : Junkie script id (the token, or read from a public download link)
--   Link : the download link, only when the script is a link, used when the SDK can't load the script
--   Given: a script (link or id) is configured
--   Invalid: it is configured but is neither a valid link nor a valid id
local function ResolveLoadSource(Script, KeyIsPremium)
    local Value = PickByTier(Script, KeyIsPremium)

    local Tokens, Link, Invalid = ResolveScript(Value)
    return {
        Id = Tokens[1],
        Link = Link,
        Given = Trim(Value) ~= "",
        Invalid = Invalid,
        Text = Trim(Value),
    }
end

local function SDKLoadResult(Ok, A, B)
    if not Ok then
        return false, tostring(A)
    end
    if A == false then
        return false, tostring(B or "load_script returned false")
    end
    if A == nil and B ~= nil then
        return false, tostring(B)
    end
    if type(A) == "table" and (A.success == false or A.error ~= nil) then
        return false, tostring(A.error or A.message or "load_script failed")
    end
    return true
end

-- Downloads a script and runs it once. Returns true | false, Reason, Detail
-- Reason: "http" (download failed) | "compile" (not Lua) | "runtime" (script errored)
local function DownloadAndRun(Url, Key)
    local Body, Err, Code = SafeHttpGet(Url)
    if not Body and (Code == 401 or Code == 403) and not Url:find("[?&]key=") then
        local Sep = Url:find("?", 1, true) and "&" or "?"
        Body, Err = SafeHttpGet(Url .. Sep .. "key=" .. HttpService:UrlEncode(Key))
    end
    if not Body then
        return false, "http", Err
    end

    local CompileOk, Compiled, CompileErr = pcall(loadstring, Body)
    if not CompileOk then
        return false, "compile", tostring(Compiled)
    end
    if not Compiled then
        return false, "compile", tostring(CompileErr)
    end

    local RunOk, RunErr = pcall(Compiled)
    if not RunOk then
        return false, "runtime", tostring(RunErr)
    end
    return true
end

-- Loads the protected script for a verified key. Shared by Launcher and CheckKey.
--   1. Junkie SDK with the resolved script id (script_id is set before load_script, restored on failure).
--      load_script() takes no arguments and reads getgenv().SCRIPT_KEY, which is set before this runs
--   2. direct download of the link, only if the SDK did not load it
-- Returns true | false, Reason, Detail, SDKError
-- Reason: "bad_url" | "no_source" | "sdk" | "http" | "compile" | "runtime"
local function LoadProtected(Lib, Key, Source)
    if Source.Invalid then
        return false, "bad_url", Source.Text
    end
    if not Source.Id and not Source.Link then
        return false, "no_source"
    end

    local SDKErr
    if Source.Id then
        local Previous = Lib.script_id
        Lib.script_id = Source.Id

        local Ok, A, B = pcall(Lib.load_script)
        local Good, Err = SDKLoadResult(Ok, A, B)
        if Good then
            return true
        end

        Lib.script_id = Previous
        if not Source.Link then
            return false, "sdk", Err
        end
        SDKErr = Err
    end

    local Good, Reason, Detail = DownloadAndRun(Source.Link, Key)
    if Good then
        return true
    end
    return false, Reason, Detail, SDKErr
end

local LoadReasons = {
    no_source = "no script configured. Add a Games entry for this game",
    bad_url = "the configured script is not a valid script id or link",
    sdk = "Junkie load_script failed",
    http = "script download failed",
    compile = "downloaded file is not valid Lua",
    runtime = "script errored while running",
}

-- long text for the console / Result.LoadError
local function LoadFailureLog(Reason, Detail, SDKErr)
    local Text = LoadReasons[Reason] or tostring(Reason)
    if Detail ~= nil and Detail ~= "" then
        Text = Text .. ": " .. tostring(Detail)
    end
    if Reason == "http" and tostring(Detail):find("HTTP 404", 1, true) then
        Text = Text .. ". Check the link and script id, and that the script is published as public in the Junkie dashboard"
    end
    if SDKErr ~= nil and Reason ~= "sdk" then
        Text = Text .. " (Junkie SDK: " .. tostring(SDKErr) .. ")"
    end
    return Text
end

-- short text for the toast
local function LoadToastText(Reason, Detail)
    Detail = tostring(Detail or "")
    if Reason == "no_source" then
        return "No script set. Add a Games entry."
    elseif Reason == "bad_url" then
        return "The script is not a valid script id or link."
    elseif Reason == "http" then
        if Detail:find("HTTP 404", 1, true) then
            return "Script not found (HTTP 404). Check the link / script id."
        end
        return "Download failed: " .. Detail:sub(1, 45)
    elseif Reason == "compile" then
        return "The downloaded file is not a valid Lua script."
    elseif Reason == "runtime" then
        return "The script errored while running. Check the console."
    end
    return "Junkie could not load the script: " .. Detail:sub(1, 40)
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
    MinHeight = 84,
    Gap = 12,
    Margin = 16,
}

-- Notifications.CornerRadius -> UDim (number < 1 = scale, number >= 1 = pixels, or a UDim)
local function ToastRadius()
    local R = Toolkit.Notifications.CornerRadius
    if typeof(R) == "UDim" then
        return R
    end
    R = tonumber(R) or 0.12
    if R < 1 then
        return UDim.new(math.max(R, 0), 0)
    end
    return UDim.new(0, R)
end

local Notif = { Gui = nil, Holder = nil, Width = 300, Toasts = {}, Counter = 0 }
local NoToast = { Dismiss = function() end }

local function EnsureNotif()
    if Notif.Gui and Notif.Gui.Parent and Notif.Holder and Notif.Holder.Parent then
        return true
    end

    RemoveGui(Toolkit.NotifName)

    local Camera = workspace.CurrentCamera
    local V = Camera and Camera.ViewportSize or Vector2.new(1280, 720)
    Notif.Width = math.clamp(V.X - TOAST.Margin * 2, 240, tonumber(Toolkit.Notifications.Width) or 340)
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

    -- bigger, higher-contrast text; the toast grows to fit the description
    local Cfg = Toolkit.Notifications
    local TitleSize = tonumber(Cfg.TitleSize) or 18
    local TextSize = tonumber(Cfg.TextSize) or 15
    local TextLeft = 74
    local TextWidth = Notif.Width - TextLeft - 16
    local TitleColor = Cfg.TitleColor or Theme.Text
    local BodyColor = Cfg.TextColor or Theme.Text
    local TextHeight = TextSize + 4
    local Measured, MeasureText = pcall(function()
        return TextService:GetTextSize(tostring(Text), TextSize, Enum.Font.GothamMedium, Vector2.new(TextWidth, 10000))
    end)
    if Measured and typeof(MeasureText) == "Vector2" then
        TextHeight = math.ceil(MeasureText.Y) + 2
    else
        local Lines = math.max(1, math.ceil(#tostring(Text) * TextSize * 0.55 / TextWidth))
        TextHeight = Lines * (TextSize + 3)
    end
    local ToastHeight = math.max(TOAST.MinHeight, 14 + (TitleSize + 6) + 4 + TextHeight + 14 + 8 + 10)

    local Wrap = New("Frame", {
        Name = "Toast",
        Size = UDim2.new(1, 0, 0, ToastHeight),
        BackgroundTransparency = 1,
        LayoutOrder = -Notif.Counter,
    }, NotifHolder)
    local Slider = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(OffX, 0),
        BackgroundTransparency = 1,
    }, Wrap)

    Glow(Slider, Color, 46, 0.6, 1)

    local Card = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, Slider)
    local Radius = ToastRadius()
    New("UICorner", { CornerRadius = Radius }, Card)
    Gradient(Card, Theme.Bg, Theme.Bg, 135)
    local CardStroke = Stroke(Card, Color, 2.5, 0)

    local Badge = New("Frame", {
        Position = UDim2.fromOffset(14, 14),
        Size = UDim2.fromOffset(46, 46),
        BackgroundColor3 = Color,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, Card)
    New("UICorner", { CornerRadius = Radius }, Badge)
    Stroke(Badge, Color, 2, 0)
    local BadgePop = New("UIScale", { Scale = 0 }, Badge)
    Label(Badge, {
        Size = UDim2.fromScale(1, 1),
        Text = Icon,
        TextColor3 = Color,
        TextSize = 28,
        Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })

    Label(Card, {
        Position = UDim2.fromOffset(TextLeft, 12),
        Size = UDim2.new(1, -(TextLeft + 14), 0, TitleSize + 6),
        Text = Title,
        TextColor3 = TitleColor,
        TextSize = TitleSize,
        Font = Enum.Font.GothamBlack,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3,
    })
    Label(Card, {
        Position = UDim2.fromOffset(TextLeft, 12 + TitleSize + 10),
        Size = UDim2.new(1, -(TextLeft + 14), 0, TextHeight),
        Text = Text,
        TextColor3 = BodyColor,
        TextSize = TextSize,
        Font = Enum.Font.GothamMedium,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 3,
    })

    local Track = New("Frame", {
        Position = UDim2.new(0, 14, 1, -18),
        Size = UDim2.new(1, -28, 0, 8),
        BackgroundColor3 = Color,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, Card)
    New("UICorner", { CornerRadius = Radius }, Track)
    local Bar = New("Frame", {
        Size = Fill and UDim2.fromScale(0, 1) or UDim2.fromScale(1, 1),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, Track)
    New("UICorner", { CornerRadius = Radius }, Bar)
    Gradient(Bar, Color, Color:Lerp(White, 0.3), 0)

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
    Click.MouseEnter:Connect(function() Tween(CardStroke, 0.15, { Transparency = 0.25 }) end)
    Click.MouseLeave:Connect(function() Tween(CardStroke, 0.15, { Transparency = 0 }) end)

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

    -- Merc-style options also work (aliases of the Toolkit options):
    --   Service / Identifier / Provider  -> Junkie.*
    --   OnSuccess -> OnVerified
    --   Storage.FileName -> KeyFile       Links.Discord / Links.GetKey -> Discord / GetKeyLink
    --   Appearance.Title / Subtitle -> Title / Tagline
    for _, K in ipairs({ "Service", "Identifier", "Provider" }) do
        if Config[K] ~= nil then
            Config.Junkie[K] = Config[K]
        end
    end
    if type(Config.OnSuccess) == "function" and Config.OnVerified == nil then
        Config.OnVerified = Config.OnSuccess
    end
    if type(Config.Storage) == "table" and Config.Storage.FileName and Config.KeyFile == nil then
        Config.KeyFile = tostring(Config.Storage.FileName)
    end
    if type(Config.Links) == "table" then
        if Config.Links.Discord and (Config.Discord == nil or Config.Discord == "") then
            Config.Discord = Config.Links.Discord
        end
        if Config.Links.GetKey and (Config.GetKeyLink == nil or Config.GetKeyLink == "") then
            Config.GetKeyLink = Config.Links.GetKey
        end
    end
    if type(Config.Appearance) == "table" then
        if Config.Appearance.Title then Config.Title = Config.Appearance.Title end
        if Config.Appearance.Subtitle then Config.Tagline = Config.Appearance.Subtitle end
    end

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

    -- Games list (optional): if an entry matches this PlaceId, its Premium / Freemium links
    -- are loaded after the key is verified. No match = nothing changes, the key
    -- flow still runs, so an unlisted game is never blocked.
    local GamesDone = false
    task.spawn(function()
        local Games = Config.Games
        if type(Games) ~= "table" and type(Config.GamesUrl) == "string" and Config.GamesUrl ~= "" then
            Games = FetchGames(Config.GamesUrl)
        end
        local Entry = ResolveGame(Games)
        if Entry then
            Config.GameScript = { Premium = Entry.Premium, Freemium = Entry.Freemium }
            Env.TOOLKIT_GAME = Entry.Name
        end
        GamesDone = true
    end)

    -- Premium / Freemium launcher
    local AnyTier = Config.Premium == "both" or Config.Premium == "auto"
    local IsPremium = Config.Premium == true
    local EnforceTier = Config.EnforceTier ~= false and not AnyTier

    -- start the Junkie SDK download right away
    local SDKLib, SDKDone = nil, false
    task.spawn(function()
        local Ok, Lib = pcall(function()
            local Source, Err = SafeHttpGet(Config.Junkie.SDKUrl)
            if type(Source) ~= "string" then
                error(Err or "empty response", 0)
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

    -- why the Junkie SDK can't be used (set at startup), shown when the user presses a button anyway
    local StartupError = nil
    local function NotReady()
        if StartupError and Config.NotifyErrors == true then
            SetStatus(StartupError, Theme.Red)
        else
            SetStatus("Junkie SDK isn't ready yet. Try again in a moment.", Theme.Amber)
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
        local MarkerColor = AnyTier and ToColor3(Config.Marker.BothColor, Theme.Violet)
            or IsPremium
            and ToColor3(Config.Marker.PremiumColor, Theme.Amber)
            or ToColor3(Config.Marker.FreemiumColor, Theme.Blue)
        local MarkerText = AnyTier and Config.Marker.BothText
            or (IsPremium and Config.Marker.PremiumText or Config.Marker.FreemiumText)

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

    -- AUTO VERIFY toggle (right side of the YOUR KEY row).
    -- Always OFF at first. It only turns ON when the user enables it, and that
    -- choice is then saved on the device.
    local SettingsFile = Config.SettingsFile or (Config.Name .. "_Settings.txt")
    local AutoOn = false
    do
        local Saved = ReadFile(SettingsFile):lower()
        local Value = Saved:match("autoverify%s*=%s*(%a+)")
        if Value == "on" then
            AutoOn = true
        elseif Value == "off" then
            AutoOn = false
        end
    end

    local AutoToggle = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 250),
        Size = UDim2.fromOffset(120, 20),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 6,
    }, Main)

    Label(AutoToggle, {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(1, -40, 1, 0),
        Text = "AUTO VERIFY",
        TextColor3 = Theme.Muted,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 7,
    })

    local AutoTrack = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(32, 16),
        BackgroundColor3 = AutoOn and Theme.Teal or Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, AutoToggle)
    Corner(AutoTrack, 8)
    local AutoStroke = Stroke(AutoTrack, AutoOn and Theme.Teal or Theme.Stroke, 1.2)

    local AutoKnob = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = AutoOn and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = White,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, AutoTrack)
    Corner(AutoKnob, 6)

    local function PaintAuto(Animate)
        local Time = Animate and 0.2 or 0
        Tween(AutoTrack, Time, { BackgroundColor3 = AutoOn and Theme.Teal or Theme.Card })
        Tween(AutoStroke, Time, { Color = AutoOn and Theme.Teal or Theme.Stroke })
        Tween(AutoKnob, Time, {
            Position = AutoOn and UDim2.new(1, -14, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
        })
    end

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

    local ClassifyError = ClassifyJunkieError

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
            NotReady()
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
            NotReady()
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

            -- load the script after a valid key (works in any game)
            -- the "Wait" toast (Config.WaitNotice) is shown right after the key is verified, before the load starts
            local function NotifyWait()
                local Notice = Config.WaitNotice
                if Notice == false or (type(Notice) == "table" and Notice.Enabled == false) then
                    return
                end
                if type(Notice) ~= "table" then
                    Notice = {}
                end
                Toolkit:Notify(
                    tostring(Notice.Title or "Wait"),
                    tostring(Notice.Description or "Please wait while Jnkie loads the script. It may take a while depending on Jnkie servers."),
                    "info",
                    { Duration = tonumber(Notice.Duration) or 8, Tag = "load" }
                )
            end

            local WaitedAt = os.clock()
            while not GamesDone and os.clock() - WaitedAt < 10 do
                task.wait()
            end

            local Source = ResolveLoadSource(Config.GameScript, KeyIsPremium)
            if Source.Given or Config.LoadScript ~= false then
                NotifyWait()
                local Loaded, Reason, Detail, SDKErr = LoadProtected(Junkie, Key, Source)
                if not Loaded then
                    warn("[Toolkit] load failed: " .. LoadFailureLog(Reason, Detail, SDKErr))
                    local Text = LoadToastText(Reason, Detail)
                    if Reason == "no_source" or Reason == "bad_url" then
                        Problem("error", Text, Reason == "bad_url" and "Invalid script link" or "Script not set", Text, {
                            Duration = 8, Tag = "load",
                        })
                    else
                        Toolkit:Notify("Load failed", Text, "error", {
                            Duration = 6, Tag = "load",
                        })
                    end
                end
            end
        end)
    end

    ------------------------------------------------------------------
    -- wiring
    ------------------------------------------------------------------
    AutoToggle.MouseButton1Click:Connect(function()
        if Destroyed then return end
        AutoOn = not AutoOn
        WriteFile(SettingsFile, "autoverify=" .. (AutoOn and "on" or "off"))
        PaintAuto(true)
        Toolkit:Notify(
            "Auto verify " .. (AutoOn and "ON" or "OFF"),
            AutoOn and "A saved key will be checked automatically." or "You will press VERIFY KEY yourself.",
            AutoOn and "success" or "info",
            { Tag = "autoverify", Duration = 2.5 }
        )
    end)

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
            StartupError = "Junkie SDK failed to load  •  Check your connection and SDKUrl"
            Problem("error", "Key service unreachable  •  Check your connection",
                "SDK failed", "Could not load the Junkie SDK. Check your connection.", { Duration = 6, Tag = "sdk" })
            return
        end

        local J = Config.Junkie
        -- Service / Identifier / Provider can be { Premium = "...", Freemium = "..." }
        -- (picked by this launcher's Premium = true / false)
        local Service = CleanText(PickByTier(J.Service, IsPremium), nil)
        if not Service then
            StartupError = "Junkie config missing  •  Set Junkie.Service"
            Problem("error", "Junkie config missing  •  Set Junkie.Service",
                "Config missing", "Set Junkie.Service in Launcher.", { Duration = 8, Tag = "sdk" })
            return
        end

        Junkie = SDKLib
        Junkie.service = Service
        Junkie.identifier = CleanText(PickByTier(J.Identifier, IsPremium), "")
        Junkie.provider = CleanText(PickByTier(J.Provider, IsPremium), nil)

        -- the script id is resolved from the matched Games entry and set before any SDK call.
        -- it is resolved again after the key is verified, because the key's tier can pick another script
        local StartSource = ResolveLoadSource(Config.GameScript, IsPremium)
        if StartSource.Id then
            Junkie.script_id = StartSource.Id
        end

        if SavedKey ~= "" then
            if AutoOn then
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

----------------------------------------------------------------------
-- [5] JUNKIE FUNCTIONS (no GUI)
--
--   Toolkit:CheckKey(Key, Options) -> Result
--     Headless Junkie check with premium / freemium support.
--     Options : { Premium = false | true | "both", EnforceTier = true,
--                 Junkie = { Service, Identifier, Provider, SDKUrl },
--                 LoadScript = true, SDK = <already loaded Junkie lib> }
--     Result  : {
--         Valid     = boolean   -- true only when the key is valid AND its tier is accepted
--         IsPremium = boolean   -- tier of the key (Junkie check_key -> is_premium)
--         Tier      = "Premium" | "Freemium" | nil
--         Reason    = nil when Valid, otherwise one of:
--                     "missing" | "config" | "sdk" | "request" | "invalid" | "expired"
--                     "hwid" | "mismatch" | "banned" | "rate" | "service"
--                     "premium_in_freemium" | "freemium_in_premium"
--         Error     = raw Junkie error / message (if any)
--         Raw       = raw table returned by Junkie.check_key
--         Load      = function() -> ok, err, reason   (only when Valid) loads the script for the key's tier
--                     reason: "bad_url" | "no_source" | "sdk" | "http" | "compile" | "runtime"
--                     calling it again after it succeeded does nothing
--     }
--
--   Toolkit:VerifyAndLoad(Key, Options) -> Result
--     check key -> valid -> tier check -> load script. Same Options as CheckKey.
--     Result gets extra fields: Loaded (boolean), LoadError and LoadReason.
--
--       local R = Toolkit:VerifyAndLoad(Key, {
--           Premium = "both",                      -- true | false | "both"
--           Service = "My Service", Identifier = "12345", Provider = "Mixed",
--           Games = Games,
--       })
--       if not R.Valid then warn(R.Reason) end
--       if R.Valid and not R.Loaded then warn(R.LoadError) end
--
--       -- one entry per game, each with its own Premium / Freemium link (matched by PlaceId)
--       local Games = {
--           { Name = "Karinderya", PlaceId = 116497287371701,
--             Premium = "https://api.jnkie.com/api/v1/luascripts/public/<id>/download",
--             Freemium = "https://api.jnkie.com/api/v1/luascripts/public/<id>/download" },
--       }
--       Toolkit:VerifyAndLoad(Key, { Premium = "both", Service = "...", Games = Games })
--       -- Result.Game = the matched entry (nil when the game isn't listed; it still works,
--       -- there is just no script to load).
--       -- The same Games = Games option works in Toolkit:Launcher.
--       -- To edit the list without touching the loader: GamesUrl = "https://.../games.lua"
--
--       -- separate Junkie services per version also works (Premium = true / false only):
--       --   Service = { Premium = "My Premium", Freemium = "My Freemium" }
--       --   Identifier / Provider can be split the same way.
----------------------------------------------------------------------
function Toolkit:CheckKey(Key, Options)
    local Config = Merge({
        Premium = Toolkit.Defaults.Premium,
        EnforceTier = Toolkit.Defaults.EnforceTier,
        LoadScript = Toolkit.Defaults.LoadScript,
        Junkie = Toolkit.Defaults.Junkie,
    }, Options)

    local Result = { Valid = false, IsPremium = false, Tier = nil, Reason = nil, Error = nil, Raw = nil }

    Key = Trim(Key)
    if Key == "" then
        Result.Reason = "missing"
        return Result
    end

    local J = Config.Junkie

    -- top-level Service / Identifier / Provider win over Junkie.*
    for _, K in ipairs({ "Service", "Identifier", "Provider" }) do
        if Config[K] ~= nil then
            J[K] = Config[K]
        end
    end

    -- Games list (optional): a matching entry provides the script to load. No match is fine:
    -- the key is still checked, there is just no script to load.
    local GameScript
    local Games = Config.Games
    if type(Games) ~= "table" and type(Config.GamesUrl) == "string" and Config.GamesUrl ~= "" then
        Games = FetchGames(Config.GamesUrl)
    end
    local GameEntry = ResolveGame(Games)
    if GameEntry then
        Result.Game = GameEntry
        GameScript = { Premium = GameEntry.Premium, Freemium = GameEntry.Freemium }
    end

    -- every one of them can be { Premium = "...", Freemium = "..." }.
    -- Service / Identifier / Provider are picked by Options.Premium (true / false),
    -- the Games script is picked by the tier of the key that was just verified.
    local LauncherPremium = Config.Premium == true
    local Service = CleanText(PickByTier(J.Service, LauncherPremium), nil)
    local Identifier = CleanText(PickByTier(J.Identifier, LauncherPremium), "")
    local Provider = CleanText(PickByTier(J.Provider, LauncherPremium), nil)

    if not Service then
        Result.Reason = "config"
        Result.Error = "Junkie.Service is missing"
        return Result
    end

    local Lib = Config.SDK
    if not Lib then
        local Ok, Loaded = pcall(function()
            local Source, Err = SafeHttpGet(J.SDKUrl)
            if type(Source) ~= "string" then
                error(Err or "empty response", 0)
            end
            return loadstring(Source)()
        end)
        if not Ok or not Loaded then
            Result.Reason = "sdk"
            Result.Error = tostring(Loaded)
            return Result
        end
        Lib = Loaded
    end

    Lib.service = Service
    Lib.identifier = Identifier
    Lib.provider = Provider

    -- the script id is resolved from the matched Games entry and set before any SDK call
    local StartSource = ResolveLoadSource(GameScript, LauncherPremium)
    if StartSource.Id then
        Lib.script_id = StartSource.Id
    end

    local Ok, Res = pcall(Lib.check_key, Key)
    if not Ok or type(Res) ~= "table" then
        Result.Reason = "request"
        Result.Error = Ok and "bad response" or tostring(Res)
        return Result
    end
    Result.Raw = Res

    if not Res.valid then
        Result.Error = Res.error or Res.message
        Result.Reason = ClassifyJunkieError(Result.Error)
        return Result
    end

    -- valid key: detect its tier (Junkie check_key -> is_premium)
    local KeyIsPremium = Res.is_premium == true
    Result.IsPremium = KeyIsPremium
    Result.Tier = KeyIsPremium and "Premium" or "Freemium"

    local AnyTier = Config.Premium == "both" or Config.Premium == "auto"
    local WantPremium = Config.Premium == true
    if Config.EnforceTier ~= false and not AnyTier then
        if KeyIsPremium and not WantPremium then
            Result.Reason = "premium_in_freemium"
            return Result
        end
        if (not KeyIsPremium) and WantPremium then
            Result.Reason = "freemium_in_premium"
            return Result
        end
    end

    Result.Valid = true

    -- loads the script that belongs to this key's tier (same logic as the Launcher)
    local Loaded, Running = false, false
    Result.Load = function()
        if Loaded then
            return true
        end
        if Running then
            return false, "a load is already in progress", "busy"
        end

        Running = true
        Env.SCRIPT_KEY = Key
        Env.TOOLKIT_KEY_PREMIUM = KeyIsPremium
        local Source = ResolveLoadSource(GameScript, KeyIsPremium)
        local Good, Reason, Detail, SDKErr = LoadProtected(Lib, Key, Source)
        Running = false

        if Good then
            Loaded = true
            return true
        end
        return false, LoadFailureLog(Reason, Detail, SDKErr), Reason
    end

    return Result
end

function Toolkit:VerifyAndLoad(Key, Options)
    local Result = Toolkit:CheckKey(Key, Options)
    if not Result.Valid then
        return Result
    end

    local Ok, Loaded, Err, Reason = pcall(Result.Load)
    Result.Loaded = Ok and Loaded == true
    if not Result.Loaded then
        Result.LoadError = Ok and Err or tostring(Loaded)
        Result.LoadReason = Ok and Reason or "runtime"
        warn("[Toolkit] load failed: " .. tostring(Result.LoadError))
    end
    return Result
end

-- usable from other scripts after the key GUI is gone: getgenv().Toolkit:Notify(...)
Env.Toolkit = Toolkit

return Toolkit
