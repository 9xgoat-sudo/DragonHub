--!nonstrict
--// DRAGON HUB 3.1 - PHANTOM EDITION (OPTIMIZED)
--// Auto-launch ready. Best defaults applied. Silent Aim & Anti-AFK added.
--// Design upgraded to "Phantom" theme (Deep Matte + Neon Violet/Cyan).
local H = {
    TESTING_MODE = false, -- Set to true to bypass key system for testing
}

-- Explicit initialization
H.S = {}
H.St = {}
H.G = {}
H.K = {}

-- GUI HELPER
function H.I(name, class, parent, props)
    local inst = Instance.new(class, parent)
    if props then
        for k, v in pairs(props) do
            inst[k] = v
        end
    end
    H.G[name] = inst
    return inst
end

-- KEY SYSTEM MODULE
H.K.WORKINK_LINK = "https://work.ink/2Rim/key-system"
H.K.VERIFY_URL = "https://work.ink/_api/v2/token/isValid/"
H.K.CACHE_FILE = "DragonHub_KeyCache.json"
H.K.DEFAULT_TTL_SECONDS = 5 * 60 * 60

function H.K.nowMs()
    local ok, ms = pcall(function() return DateTime.now().UnixTimestampMillis end)
    if ok and type(ms) == "number" then return ms end
    return os.time() * 1000
end

function H.K.readCache()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return nil end
    local ok, raw = pcall(function()
        if not isfile(H.K.CACHE_FILE) then return nil end
        return readfile(H.K.CACHE_FILE)
    end)
    if not ok or type(raw) ~= "string" or raw == "" then return nil end
    local http = H.HttpService or game:GetService("HttpService")
    local decodedOk, data = pcall(function() return http:JSONDecode(raw) end)
    if decodedOk and type(data) == "table" then return data end
    return nil
end

function H.K.clearCache()
    if type(delfile) == "function" and type(isfile) == "function" then
        pcall(function()
            if isfile(H.K.CACHE_FILE) then delfile(H.K.CACHE_FILE) end
        end)
        return true
    end
    return false
end

function H.K.saveCache(token, expiresAtMs)
    if type(writefile) ~= "function" then return false end
    local payload = { token = token, expiresAt = expiresAtMs, savedAt = H.K.nowMs() }
    local http = H.HttpService or game:GetService("HttpService")
    return pcall(function() writefile(H.K.CACHE_FILE, http:JSONEncode(payload)) end)
end

function H.K.isCachedValid()
    local cached = H.K.readCache()
    local expiresAt = cached and tonumber(cached.expiresAt)
    return expiresAt ~= nil and expiresAt > H.K.nowMs()
end

function H.K.getCacheStatus()
    local cached = H.K.readCache()
    if not cached then return "KEY CACHE • NONE" end
    local expiresAt = tonumber(cached.expiresAt)
    local now = H.K.nowMs()
    if expiresAt and expiresAt > now then
        local remaining = math.max(0, math.floor((expiresAt - now) / 1000))
        return string.format("KEY CACHE • %dh %02dm LEFT", math.floor(remaining / 3600), math.floor((remaining % 3600) / 60))
    end
    return "KEY CACHE • EXPIRED"
end

function H.K.copyLink()
    local copied = false
    if setclipboard then pcall(setclipboard, H.K.WORKINK_LINK); copied = true end
    if toclipboard then pcall(toclipboard, H.K.WORKINK_LINK); copied = true end
    return copied
end

function H.K.httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and body ~= "" then return true, body end
    local env = (getfenv and getfenv()) or {}
    local req = env.request or env.http_request
    if not req then pcall(function() if syn and syn.request then req = syn.request end end) end
    if type(req) == "function" then
        local ok2, resp = pcall(req, { Url = url, Method = "GET", Headers = { ["Accept"] = "application/json" } })
        if ok2 and type(resp) == "table" then
            local code = tonumber(resp.StatusCode or resp.Status or 0) or 0
            local responseBody = resp.Body or resp.body
            if code == 0 or (code >= 200 and code < 300) then return true, responseBody or "" end
        end
    end
    return false, nil
end

function H.K.truthy(value)
    return value == true or value == 1 or value == "1" or tostring(value) == "true"
end

function H.K.extractValidity(data)
    if type(data) ~= "table" then return false, nil end
    local info = {}
    if type(data.info) == "table" then info = data.info elseif type(data.data) == "table" then info = data.data end
    local valid = H.K.truthy(data.valid) or H.K.truthy(data.isValid) or H.K.truthy(data.success) or data.status == "valid" or data.result == "valid" or H.K.truthy(info.valid)
    if not valid then return false, nil end
    local expiresAt = tonumber(data.expiresAt or info.expiresAt or data.expiresAfter or info.expiresAfter)
    local expiresIn = tonumber(data.expiresIn or info.expiresIn or data.ttl or info.ttl)
    if expiresIn and not expiresAt then expiresAt = H.K.nowMs() + (expiresIn * 1000) end
    if expiresAt and expiresAt < 1000000000000 then expiresAt = expiresAt * 1000 end
    return true, expiresAt
end

function H.K.verifyToken(rawToken, saveIfValid)
    local token = tostring(rawToken or ""):gsub("%s+", "")
    if token == "" then return false, "Enter a key first." end
    local http = H.HttpService or game:GetService("HttpService")
    local ok, response = H.K.httpGet(H.K.VERIFY_URL .. http:UrlEncode(token))
    if not ok then return false, "HTTP request failed." end
    local decoded, data = pcall(function() return http:JSONDecode(response) end)
    if not decoded or type(data) ~= "table" then return false, "Invalid server response." end
    local isValid, expiresAt = H.K.extractValidity(data)
    if not isValid then return false, "Invalid or expired key." end
    if not expiresAt or expiresAt <= H.K.nowMs() then expiresAt = H.K.nowMs() + (H.K.DEFAULT_TTL_SECONDS * 1000) end
    local saved = false
    if saveIfValid then saved = H.K.saveCache(token, expiresAt) end
    local remaining = math.max(0, math.floor((expiresAt - H.K.nowMs()) / 1000))
    local message = string.format("VALID • %dh %02dm remaining%s", math.floor(remaining / 3600), math.floor((remaining % 3600) / 60), saved and "" or " • SESSION ONLY")
    return true, message, expiresAt
end

-- SERVICES
function H.InitServices()
    H.Players = game:GetService("Players")
    H.RunService = game:GetService("RunService")
    H.UserInputService = game:GetService("UserInputService")
    H.TweenService = game:GetService("TweenService")
    H.GuiService = game:GetService("GuiService")
    H.HttpService = game:GetService("HttpService")
    H.StarterGui = game:GetService("StarterGui")
    local okStats, stats = pcall(function() return game:GetService("Stats") end)
    H.Stats = okStats and stats or nil
    local okVIM, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    H.VirtualInputManager = okVIM and vim or nil
    H.LocalPlayer = H.Players.LocalPlayer
    if H.LocalPlayer then H.PlayerGui = H.LocalPlayer:WaitForChild("PlayerGui") end
    H.Camera = workspace.CurrentCamera
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() H.Camera = workspace.CurrentCamera end)
    H.IsTouchDevice = H.UserInputService.TouchEnabled and not H.UserInputService.KeyboardEnabled
end

-- KEY GATE
function H.RunKeyGate()
    if H.TESTING_MODE then return true end
    if H.K.isCachedValid() then return true end
    if not H.PlayerGui then return false end
    local oldGate = H.PlayerGui:FindFirstChild("DragonKeySystem")
    if oldGate then oldGate:Destroy() end
    H.I("KeyGate", "ScreenGui", H.PlayerGui, { Name = "DragonKeySystem", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100000, ZIndexBehavior = Enum.ZIndexBehavior.Global })
    H.I("KeyOverlay", "Frame", H.G.KeyGate, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 5, 10), BackgroundTransparency = 0.02, BorderSizePixel = 0, Active = true, ZIndex = 1 })
    H.I("KeyScale", "UIScale", H.G.KeyGate, { Scale = 1 })
    local function updateScale()
        local cam = workspace.CurrentCamera
        local viewport = cam and cam.ViewportSize or Vector2.new(900, 600)
        if H.UserInputService.TouchEnabled or viewport.X < 700 then H.G.KeyScale.Scale = math.clamp(math.min(viewport.X / 480, viewport.Y / 410), 0.68, 1) else H.G.KeyScale.Scale = 1 end
    end
    updateScale()
    H.I("KeyMain", "Frame", H.G.KeyOverlay, { Size = UDim2.fromOffset(440, 330), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(15, 13, 23), BorderSizePixel = 0, ZIndex = 5 })
    H.I("KeyMainCorner", "UICorner", H.G.KeyMain, { CornerRadius = UDim.new(0, 16) })
    H.I("KeyMainStroke", "UIStroke", H.G.KeyMain, { Color = Color3.fromRGB(146, 84, 255), Thickness = 1.6, Transparency = 0.16 })
    H.I("KeyTopGlow", "Frame", H.G.KeyMain, { Size = UDim2.new(1, -40, 0, 3), Position = UDim2.fromOffset(20, 14), BackgroundColor3 = Color3.fromRGB(168, 85, 247), BorderSizePixel = 0, BackgroundTransparency = 0.15, ZIndex = 6 })
    H.I("KeyTitle", "TextLabel", H.G.KeyMain, { Size = UDim2.new(1, -40, 0, 42), Position = UDim2.fromOffset(20, 26), BackgroundTransparency = 1, Text = "DRAGON HUB 3.1", TextColor3 = Color3.fromRGB(226, 205, 255), TextSize = 26, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
    H.I("KeySubtitle", "TextLabel", H.G.KeyMain, { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 64), BackgroundTransparency = 1, Text = "PRIVATE TEST BUILD • 5-HOUR KEY SYSTEM", TextColor3 = Color3.fromRGB(146, 140, 165), TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
    H.I("KeyGet", "TextButton", H.G.KeyMain, { Size = UDim2.new(1, -40, 0, 48), Position = UDim2.fromOffset(20, 102), BackgroundColor3 = Color3.fromRGB(112, 54, 216), BorderSizePixel = 0, Text = "GET KEY", TextColor3 = Color3.new(1, 1, 1), TextSize = 15, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 6 })
    H.I("KeyGetCorner", "UICorner", H.G.KeyGet, { CornerRadius = UDim.new(0, 10) })
    H.I("KeyBox", "TextBox", H.G.KeyMain, { Size = UDim2.new(1, -40, 0, 48), Position = UDim2.fromOffset(20, 162), BackgroundColor3 = Color3.fromRGB(9, 8, 14), BorderSizePixel = 0, PlaceholderText = "Enter your Work.ink key...", PlaceholderColor3 = Color3.fromRGB(102, 96, 118), Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Font = Enum.Font.Gotham, ClearTextOnFocus = false, ZIndex = 6 })
    H.I("KeyBoxCorner", "UICorner", H.G.KeyBox, { CornerRadius = UDim.new(0, 10) })
    H.I("KeyVerify", "TextButton", H.G.KeyMain, { Size = UDim2.new(1, -40, 0, 44), Position = UDim2.fromOffset(20, 222), BackgroundColor3 = Color3.fromRGB(42, 38, 56), BorderSizePixel = 0, Text = "VERIFY KEY", TextColor3 = Color3.fromRGB(225, 220, 238), TextSize = 14, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 6 })
    H.I("KeyVerifyCorner", "UICorner", H.G.KeyVerify, { CornerRadius = UDim.new(0, 10) })
    H.I("KeyStatus", "TextLabel", H.G.KeyMain, { Size = UDim2.new(1, -40, 0, 28), Position = UDim2.fromOffset(20, 276), BackgroundTransparency = 1, Text = H.K.getCacheStatus(), TextColor3 = Color3.fromRGB(146, 140, 165), TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 6 })
    local verified = false
    local verifying = false
    local function notify(text) pcall(function() H.StarterGui:SetCore("SendNotification", { Title = "Dragon Hub", Text = text, Duration = 3 }) end) end
    local function openWorkInk()
        local copied = H.K.copyLink()
        H.G.KeyStatus.Text = copied and "Status: Link copied!" or ("Status: " .. H.K.WORKINK_LINK)
        H.G.KeyStatus.TextColor3 = Color3.fromRGB(110, 255, 160)
        notify("Work.ink link copied!")
    end
    local function verifyKey(rawToken)
        if verifying or verified then return end
        verifying = true
        H.G.KeyVerify.Text = "VERIFYING..."
        H.G.KeyStatus.Text = "Status: Verifying..."
        H.G.KeyStatus.TextColor3 = Color3.fromRGB(255, 214, 110)
        task.spawn(function()
            local ok, message = H.K.verifyToken(rawToken, true)
            if ok then
                verified = true
                H.G.KeyStatus.Text = "Status: " .. message
                H.G.KeyStatus.TextColor3 = Color3.fromRGB(110, 255, 160)
                task.delay(0.55, function() if H.G.KeyGate and H.G.KeyGate.Parent then H.G.KeyGate:Destroy() end end)
            else
                H.G.KeyStatus.Text = "Status: " .. message
                H.G.KeyStatus.TextColor3 = Color3.fromRGB(255, 105, 105)
                H.G.KeyVerify.Text = "VERIFY KEY"
            end
            verifying = false
        end)
    end
    H.G.KeyGet.Activated:Connect(openWorkInk)
    H.G.KeyVerify.Activated:Connect(function() verifyKey(H.G.KeyBox.Text) end)
    H.G.KeyBox.FocusLost:Connect(function(enterPressed) if enterPressed then verifyKey(H.G.KeyBox.Text) end end)
    local camConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.defer(updateScale) end)
    while H.G.KeyGate.Parent and not verified do task.wait(0.05) end
    if camConnection then camConnection:Disconnect() end
    return verified
end

-- CLEANUP
function H.Cleanup()
    pcall(function() H.RunService:UnbindFromRenderStep("DragonAimbotStep") end)
    for _, name in ipairs({ "DragonHubUI", "DragonMobileUI", "DragonFOVGui", "DragonWatermark", "DragonTargetHUD", "DragonNotifications", "DragonESPVisuals", "DragonKeySystem" }) do
        local old = H.PlayerGui and H.PlayerGui:FindFirstChild(name)
        if old then old:Destroy() end
    end
    local oldEspFolder = workspace:FindFirstChild("DragonESPFolder")
    if oldEspFolder then oldEspFolder:Destroy() end
end

-- SETTINGS / THEME (PHANTOM EDITION)
function H.InitSettings()
    H.S = {
        Version = "3.1",
        Aimbot = false,
        SilentAim = false, -- NEW: Doesn't move camera, just locks target for Triggerbot/ESP
        Triggerbot = false,
        ESPEnabled = true,
        Players = true,
        NPCs = true,
        Boxes = true,
        CornerBoxes = true,
        BoxFill = false,
        PlayerInfo = true,
        HeadDot = true,
        Tracers = false,
        OffscreenArrows = true,
        ChestESP = true,
        Rainbow = false,
        VisibleOnly = true, -- BEST DEFAULT: Avoids wallbangs
        Prediction = true,
        TargetSticky = true,
        HideUser = false,
        ShowFOV = true,
        TargetHUD = true, 
        Watermark = true,
        Crosshair = false,
        NotificationsEnabled = true,
        ShowKeybindHints = true,
        MobileToggleVisible = true,
        MobileAimButton = H.IsTouchDevice,
        PerformanceProfile = H.IsTouchDevice and "Low" or "Balanced",
        AimFOV = 140, -- BEST DEFAULT
        AimSmoothness = 8, -- BEST DEFAULT
        AimResponsiveness = 140, -- BEST DEFAULT
        AimMaxAngle = 25,
        MaxDistance = 1200,
        MaxESPObjects = 32,
        ChestMaxDistance = 1800,
        ChestFillTransparency = 85,
        ChestFilter = "All",
        AimbotKey = Enum.KeyCode.E,
        ESPKey = Enum.KeyCode.V,
        MenuKey = Enum.KeyCode.RightShift,
        TriggerKey = Enum.KeyCode.T,
        AimPart = "Auto",
        TargetPriority = "Crosshair",
        AimDeadzone = 0,
        PredictionFactor = 0.012,
        MaxPredictionCap = 2.5,
        PingCompensation = true, -- BEST DEFAULT
        UseLineOfSightForSticky = true,
        TargetGraceFOV = 1.45,
        TargetSwitchCooldown = 0.12,
        TargetScanInterval = 0.12,
        PerformanceMode = true,
        AdaptivePerformance = true,
        ESPUpdateInterval = 0.020,
        ESPPerformanceInterval = 0.040,
        ESPLowFPSStep = 0.055,
        UIStatusUpdateInterval = 0.50,
        DynamicFOVColor = true,
        FOVColor = Color3.fromRGB(168, 85, 247),
        FOVLockedColor = Color3.fromRGB(236, 72, 153),
        BoxThickness = 1.2,
        BoxFillTransparency = 0.94,
        Names = true,
        Health = true,
        HealthText = true,
        Distance = true,
        TargetHighlight = true,
        Color = Color3.fromRGB(168, 85, 247),
        SaveConfigName = "DragonHub_3.1_Config.json",
        UnlockMouseWithUI = true,
        AntiAFK = false, -- NEW
    }
    H.Palette = {
        Background = Color3.fromRGB(12, 12, 16), -- Deep Matte
        Header = Color3.fromRGB(18, 18, 24),
        Container = Color3.fromRGB(22, 22, 30),
        Card = Color3.fromRGB(28, 28, 38),
        CardAlt = Color3.fromRGB(32, 32, 44),
        Accent = Color3.fromRGB(139, 92, 246), -- Phantom Violet
        AccentGlow = Color3.fromRGB(167, 139, 250),
        AccentDark = Color3.fromRGB(76, 29, 149),
        SecondaryAccent = Color3.fromRGB(34, 211, 238), -- Cyan
        Success = Color3.fromRGB(52, 211, 153),
        Warning = Color3.fromRGB(251, 191, 36),
        Error = Color3.fromRGB(248, 113, 113),
        TextLight = Color3.fromRGB(244, 244, 245),
        TextMuted = Color3.fromRGB(161, 161, 170),
        TextDim = Color3.fromRGB(113, 113, 122),
        Divider = Color3.fromRGB(45, 45, 58),
    }
    H.Fonts = { Header = Enum.Font.GothamBold, Body = Enum.Font.Gotham, Code = Enum.Font.Code }
end

function H.ApplyPerformanceProfile(profile)
    H.S.PerformanceProfile = profile
    if profile == "Low" then
        H.S.PerformanceMode = true; H.S.AdaptivePerformance = true; H.S.ESPUpdateInterval = 0.035; H.S.ESPPerformanceInterval = 0.075; H.S.ESPLowFPSStep = 0.100; H.S.TargetScanInterval = 0.18; H.S.UIStatusUpdateInterval = 0.75; H.S.MaxESPObjects = math.min(H.S.MaxESPObjects, 20)
    elseif profile == "High" then
        H.S.PerformanceMode = false; H.S.AdaptivePerformance = true; H.S.ESPUpdateInterval = 0.015; H.S.ESPPerformanceInterval = 0.025; H.S.ESPLowFPSStep = 0.045; H.S.TargetScanInterval = 0.08; H.S.UIStatusUpdateInterval = 0.35
    else
        H.S.PerformanceMode = true; H.S.AdaptivePerformance = true; H.S.ESPUpdateInterval = 0.020; H.S.ESPPerformanceInterval = 0.040; H.S.ESPLowFPSStep = 0.055; H.S.TargetScanInterval = 0.12; H.S.UIStatusUpdateInterval = 0.50
    end
    if H.IsTouchDevice and profile ~= "Low" then H.S.AdaptivePerformance = true; H.S.MaxESPObjects = math.min(H.S.MaxESPObjects, 28) end
end

function H.ApplyBestDefaults()
    -- Already set in InitSettings, but this ensures they stick if config loads over them
    H.S.AimPart = "Auto"
    H.S.TargetPriority = "Crosshair"
    H.S.PredictionFactor = 0.012
    H.S.MaxPredictionCap = 2.5
    H.S.PingCompensation = true
    H.S.UseLineOfSightForSticky = true
    H.S.TargetGraceFOV = 1.45
    H.S.TargetSwitchCooldown = 0.12
    H.S.AimDeadzone = 0
    H.S.TargetHighlight = true
    H.S.AimFOV = 140
    H.S.AimSmoothness = 8
    H.S.AimResponsiveness = 140
    H.ApplyPerformanceProfile(H.S.PerformanceProfile or (H.IsTouchDevice and "Low" or "Balanced"))
end

-- STATE
function H.InitState()
    H.St = {
        Objects = {}, CachedTargets = {}, VisibilityCache = {}, LastTargetScan = 0, LastTriggerTime = 0, LastESPStep = 0, LastOverlayStep = 0, LastTargetHUDStep = 0,
        menuVisible = false, previousCameraMode = nil, previousMouseBehavior = nil, previousMouseIconEnabled = nil, lastTargetSwitch = 0,
        CurrentTargetModel = nil, LockedTargetModel = nil, ChestObjects = {}, ConfigMemory = nil, listeningForKey = nil,
        MobileAimActive = false, HiddenUserObjects = {}, hideUserLoop = nil, fpsCounter = 0, lastTime = tick(), currentFPS = 60,
        Dragging = false, DragInput = nil, DragStart = nil, StartPos = nil, WindowW = 680, WindowH = 470, NotifOrder = 0, AntiAFKLoop = nil,
    }
    H.UIRefreshers = {}
    H.KeybindRefreshers = {}
    H.Tabs = {}
    H.TabButtons = {}
    H.SharedRaycastParams = RaycastParams.new()
    H.SharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
end

-- BASE GUIS
function H.InitBaseGuis()
    H.I("ESPFolder", "Folder", workspace, { Name = "DragonESPFolder" })
    H.I("FOVGui", "ScreenGui", H.PlayerGui, { Name = "DragonFOVGui", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 25 })
    H.I("FOVCircle", "Frame", H.G.FOVGui, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 10 })
    H.I("FOVCorner", "UICorner", H.G.FOVCircle, { CornerRadius = UDim.new(1, 0) })
    H.I("FOVStroke", "UIStroke", H.G.FOVCircle, { Color = H.S.FOVColor, Thickness = 1.2, Transparency = 0.12 })
    H.I("Crosshair", "Frame", H.G.FOVGui, { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 12 })
    H.I("CrosshairH", "Frame", H.G.Crosshair, { Size = UDim2.fromOffset(14, 1), Position = UDim2.fromOffset(-7, 0), BorderSizePixel = 0, BackgroundColor3 = H.Palette.Accent })
    H.I("CrosshairV", "Frame", H.G.Crosshair, { Size = UDim2.fromOffset(1, 14), Position = UDim2.fromOffset(0, -7), BorderSizePixel = 0, BackgroundColor3 = H.Palette.Accent })
    H.I("WatermarkGui", "ScreenGui", H.PlayerGui, { Name = "DragonWatermark", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 22 })
    H.I("WatermarkFrame", "Frame", H.G.WatermarkGui, { Size = UDim2.fromOffset(235, 26), Position = UDim2.new(1, -245, 0, 10), BackgroundColor3 = H.Palette.Header, BorderSizePixel = 0, BackgroundTransparency = 0.08 })
    H.I("WatermarkCorner", "UICorner", H.G.WatermarkFrame, { CornerRadius = UDim.new(0, 8) })
    H.I("WatermarkStroke", "UIStroke", H.G.WatermarkFrame, { Color = H.Palette.AccentDark, Thickness = 1, Transparency = 0.2 })
    H.I("WatermarkIndicator", "Frame", H.G.WatermarkFrame, { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = H.Palette.Accent, BorderSizePixel = 0 })
    H.I("WatermarkIndicatorCorner", "UICorner", H.G.WatermarkIndicator, { CornerRadius = UDim.new(1, 0) })
    H.I("WatermarkText", "TextLabel", H.G.WatermarkFrame, { Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(24, 0), BackgroundTransparency = 1, Font = H.Fonts.Code, TextSize = 10, TextColor3 = H.Palette.TextLight, TextXAlignment = Enum.TextXAlignment.Left, Text = "DRAGON HUB 3.1" })
    H.I("TargetHUDGui", "ScreenGui", H.PlayerGui, { Name = "DragonTargetHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 24 })
    H.I("TargetFrame", "Frame", H.G.TargetHUDGui, { Size = UDim2.fromOffset(190, 54), Position = UDim2.new(0.5, -95, 0.82, 0), BackgroundColor3 = H.Palette.Header, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false })
    H.I("TargetCorner", "UICorner", H.G.TargetFrame, { CornerRadius = UDim.new(0, 10) })
    H.I("TargetStroke", "UIStroke", H.G.TargetFrame, { Color = H.Palette.Accent, Thickness = 1.1, Transparency = 0.18 })
    H.I("TargetName", "TextLabel", H.G.TargetFrame, { Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -20, 0, 15), Font = H.Fonts.Header, TextSize = 11, TextColor3 = H.Palette.TextLight, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Text = "TARGET" })
    H.I("TargetSub", "TextLabel", H.G.TargetFrame, { Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 13), Font = H.Fonts.Code, TextSize = 9, TextColor3 = H.Palette.TextMuted, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Text = "DIST: 0m | HP: 100%" })
    H.I("TargetHealthBack", "Frame", H.G.TargetFrame, { Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 6), BackgroundColor3 = Color3.fromRGB(17, 13, 27), BorderSizePixel = 0 })
    H.I("TargetHealthBackCorner", "UICorner", H.G.TargetHealthBack, { CornerRadius = UDim.new(1, 0) })
    H.I("TargetHealthBar", "Frame", H.G.TargetHealthBack, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = H.Palette.Accent, BorderSizePixel = 0 })
    H.I("TargetHealthBarCorner", "UICorner", H.G.TargetHealthBar, { CornerRadius = UDim.new(1, 0) })
    H.I("NotificationGui", "ScreenGui", H.PlayerGui, { Name = "DragonNotifications", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 120 })
    H.I("NotificationContainer", "Frame", H.G.NotificationGui, { Size = UDim2.fromOffset(248, 220), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), BackgroundTransparency = 1 })
    H.I("NotifLayout", "UIListLayout", H.G.NotificationContainer, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom })
end

-- NOTIFICATIONS
function H.InitNotify()
    function H.Notify(title, desc, state, duration)
        duration = duration or 1.9
        if title == "CONFIG" and H.G.ConfigStatus and H.G.ConfigStatus.Parent then
            H.G.ConfigStatus.Text = "CONFIG • " .. string.upper(tostring(desc))
            H.G.ConfigStatus.TextColor3 = state and H.Palette.Success or H.Palette.Error
            task.delay(duration or 2, function() if H.G.ConfigStatus and H.G.ConfigStatus.Parent then H.G.ConfigStatus.Text = "CONFIG • READY"; H.G.ConfigStatus.TextColor3 = H.Palette.TextDim end end)
        end
        if not H.S.NotificationsEnabled and title ~= "CONFIG" then return end
        H.St.NotifOrder += 1
        local notif = Instance.new("Frame", H.G.NotificationContainer)
        notif.Size = UDim2.fromOffset(220, 42); notif.BackgroundColor3 = H.Palette.Header; notif.BorderSizePixel = 0; notif.BackgroundTransparency = 1; notif.LayoutOrder = H.St.NotifOrder
        local notifCorner = Instance.new("UICorner", notif); notifCorner.CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", notif); stroke.Color = (state == true and H.Palette.Accent) or (state == false and H.Palette.Error) or H.Palette.SecondaryAccent; stroke.Thickness = 1; stroke.Transparency = 1
        local titleLabel = Instance.new("TextLabel", notif); titleLabel.Position = UDim2.fromOffset(10, 5); titleLabel.Size = UDim2.new(1, -20, 0, 13); titleLabel.Text = "[3.1] " .. string.upper(tostring(title)); titleLabel.Font = H.Fonts.Header; titleLabel.TextSize = 9; titleLabel.TextColor3 = H.Palette.Accent; titleLabel.TextXAlignment = Enum.TextXAlignment.Left; titleLabel.BackgroundTransparency = 1; titleLabel.TextTransparency = 1
        local descLabel = Instance.new("TextLabel", notif); descLabel.Position = UDim2.fromOffset(10, 20); descLabel.Size = UDim2.new(1, -20, 0, 14); descLabel.Text = desc; descLabel.Font = H.Fonts.Body; descLabel.TextSize = 10; descLabel.TextColor3 = H.Palette.TextLight; descLabel.TextXAlignment = Enum.TextXAlignment.Left; descLabel.BackgroundTransparency = 1; descLabel.TextTransparency = 1; descLabel.TextWrapped = true
        H.TweenService:Create(notif, TweenInfo.new(0.14), {BackgroundTransparency = 0.06}):Play(); H.TweenService:Create(stroke, TweenInfo.new(0.14), {Transparency = 0}):Play(); H.TweenService:Create(titleLabel, TweenInfo.new(0.14), {TextTransparency = 0}):Play(); H.TweenService:Create(descLabel, TweenInfo.new(0.14), {TextTransparency = 0}):Play()
        task.delay(duration, function()
            local fadeOut = H.TweenService:Create(notif, TweenInfo.new(0.14), {BackgroundTransparency = 1})
            H.TweenService:Create(stroke, TweenInfo.new(0.14), {Transparency = 1}):Play(); H.TweenService:Create(titleLabel, TweenInfo.new(0.14), {TextTransparency = 1}):Play(); H.TweenService:Create(descLabel, TweenInfo.new(0.14), {TextTransparency = 1}):Play()
            fadeOut:Play(); fadeOut.Completed:Connect(function() notif:Destroy() end)
        end)
    end
end

-- UTILITIES
function H.GetCharacterRoot(model) if not model then return nil end return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("Head") end
function H.GetHumanoid(model) if not model then return nil end return model:FindFirstChildOfClass("Humanoid") end
function H.IsAlive(model) if not model or not model.Parent then return false end local hum = H.GetHumanoid(model) if hum then return hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead end return H.GetCharacterRoot(model) ~= nil end
function H.IsNPC(model) if not model or not model:IsA("Model") then return false end if model == H.LocalPlayer.Character then return false end if H.Players:GetPlayerFromCharacter(model) then return false end local hum = H.GetHumanoid(model) local root = H.GetCharacterRoot(model) return hum ~= nil and root ~= nil and hum.Health > 0 end
function H.MatchesUserName(text) if type(text) ~= "string" or text == "" then return false end local lower = string.lower(text) local nameLower = string.lower(H.LocalPlayer.Name) if string.find(lower, nameLower, 1, true) then return true end local displayLower = string.lower(H.LocalPlayer.DisplayName) if displayLower ~= "" and displayLower ~= nameLower and string.find(lower, displayLower, 1, true) then return true end return false end
function H.HideElement(obj) if H.St.HiddenUserObjects[obj] == nil then H.St.HiddenUserObjects[obj] = obj.Visible end obj.Visible = false local parent = obj.Parent if parent and (parent:IsA("Frame") or parent:IsA("TextButton")) then local size = parent.AbsoluteSize if size.X > 0 and size.X < 520 and size.Y > 0 and size.Y < 320 then if H.St.HiddenUserObjects[parent] == nil then H.St.HiddenUserObjects[parent] = parent.Visible end parent.Visible = false end end end
function H.HideUserElements() if not H.PlayerGui then return end for _, gui in ipairs(H.PlayerGui:GetChildren()) do if gui:IsA("ScreenGui") and gui.Name ~= "DragonHubUI" and gui.Name ~= "DragonMobileUI" and gui.Name ~= "DragonKeySystem" and gui.Name ~= "DragonFOVGui" and gui.Name ~= "DragonWatermark" and gui.Name ~= "DragonTargetHUD" and gui.Name ~= "DragonNotifications" and gui.Name ~= "DragonESPVisuals" then for _, obj in ipairs(gui:GetDescendants()) do if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and H.MatchesUserName(obj.Text) then H.HideElement(obj) end end end end end
function H.RestoreHiddenUserElements() for obj, vis in pairs(H.St.HiddenUserObjects) do if obj and obj.Parent then obj.Visible = vis end end table.clear(H.St.HiddenUserObjects) end
function H.SetHideUser(enabled) H.S.HideUser = enabled if enabled then H.HideUserElements() if not H.St.hideUserLoop then H.St.hideUserLoop = task.spawn(function() while H.S.HideUser do H.HideUserElements() task.wait(0.45) end H.St.hideUserLoop = nil end) end else H.RestoreHiddenUserElements() end end
function H.GetColor() if H.S.Rainbow then return Color3.fromHSV((os.clock() % 4) / 4, 0.85, 1) end return H.S.Color end
function H.SetRaycastFilter(extra) local filter = {} if H.LocalPlayer and H.LocalPlayer.Character then table.insert(filter, H.LocalPlayer.Character) end if H.G.ESPFolder then table.insert(filter, H.G.ESPFolder) end if H.Camera then table.insert(filter, H.Camera) end if extra then table.insert(filter, extra) end H.SharedRaycastParams.FilterDescendantsInstances = filter end
function H.IsPartVisible(part, model) if not part or not H.Camera then return false end H.SetRaycastFilter(model) local origin = H.Camera.CFrame.Position return workspace:Raycast(origin, part.Position - origin, H.SharedRaycastParams) == nil end
function H.IsPartVisibleCached(part, model) if not part or not model then return false end local now = os.clock() local entry = H.St.VisibilityCache[model] if entry and now - entry.t < 0.12 then return entry.v end local visible = H.IsPartVisible(part, model) H.St.VisibilityCache[model] = { t = now, v = visible } return visible end
function H.GetBestTargetPart(model) if not model then return nil end local head = model:FindFirstChild("Head") local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") if H.S.AimPart == "Torso" then return torso or head or H.GetCharacterRoot(model) end if H.S.AimPart == "Head" then return head or torso or H.GetCharacterRoot(model) end local root = H.GetCharacterRoot(model) if H.Camera and root then local dist = (H.Camera.CFrame.Position - root.Position).Magnitude if dist > 450 and torso then return torso end end return head or torso or root end
function H.GetFastScreenBounds(model) if not model or not model.Parent or not H.Camera then return nil end local root = H.GetCharacterRoot(model) local head = model:FindFirstChild("Head") or root if not root or not head then return nil end local headPos = H.Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.18, 0)) local rootPos = H.Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.6, 0)) if headPos.Z <= 0 or rootPos.Z <= 0 then return nil end local topY = math.min(headPos.Y, rootPos.Y) local bottomY = math.max(headPos.Y, rootPos.Y) local height = math.max(10, bottomY - topY) local width = math.max(7, height * 0.52) local centerX = (headPos.X + rootPos.X) * 0.5 return Vector2.new(centerX - width * 0.5, topY), Vector2.new(centerX + width * 0.5, bottomY) end
function H.GetMouseViewportPosition() local mousePos = H.UserInputService:GetMouseLocation() local inset = H.GuiService:GetGuiInset() return Vector2.new(mousePos.X, mousePos.Y - inset.Y) end
function H.GetAimViewportPosition() if not H.Camera then return Vector2.new(0, 0) end if H.IsTouchDevice or H.UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default or not H.UserInputService.MouseIconEnabled then local viewport = H.Camera.ViewportSize return Vector2.new(viewport.X * 0.5, viewport.Y * 0.5) end return H.GetMouseViewportPosition() end
function H.GetPredictedPosition(targetPart, targetModel) local pos = targetPart.Position if not H.S.Prediction then return pos end local root = targetModel and H.GetCharacterRoot(targetModel) or targetPart local rawVelocity = root.AssemblyLinearVelocity if rawVelocity.Magnitude < 1 then return pos end local leadTime = H.S.PredictionFactor if H.S.PingCompensation and H.Stats then pcall(function() local ping = H.Stats.Network.ServerStatsItem["Data Ping"]:GetValue() leadTime = leadTime + ((ping / 1000) * 0.2) end) end local offset = rawVelocity * leadTime if offset.Magnitude > H.S.MaxPredictionCap then offset = offset.Unit * H.S.MaxPredictionCap end return pos + offset end
function H.AddNPCTargets(container, list, added, depth, hardLimit) if depth > 2 or #list >= hardLimit then return end for _, child in ipairs(container:GetChildren()) do if #list >= hardLimit then break end if child:IsA("Model") and not added[child] and H.IsNPC(child) then added[child] = true table.insert(list, { Model = child, Player = nil }) elseif child:IsA("Folder") then H.AddNPCTargets(child, list, added, depth + 1, hardLimit) end end end
function H.GetTargetsList() local currentTime = os.clock() if currentTime - H.St.LastTargetScan < H.S.TargetScanInterval and #H.St.CachedTargets > 0 then return H.St.CachedTargets end H.St.LastTargetScan = currentTime local list = {} local added = {} if H.S.Players then for _, player in ipairs(H.Players:GetPlayers()) do if player ~= H.LocalPlayer and player.Character and H.IsAlive(player.Character) and not added[player.Character] then added[player.Character] = true table.insert(list, { Model = player.Character, Player = player }) end end end if H.S.NPCs then H.AddNPCTargets(workspace, list, added, 0, 128) end local cap = math.max(1, math.floor(H.S.MaxESPObjects or 32)) if #list > cap then local camPos = H.Camera and H.Camera.CFrame.Position or Vector3.new(0, 0, 0) table.sort(list, function(a, b) local ra = H.GetCharacterRoot(a.Model) local rb = H.GetCharacterRoot(b.Model) if not ra then return false end if not rb then return true end return (ra.Position - camPos).Magnitude < (rb.Position - camPos).Magnitude end) local trimmed = {} for i = 1, math.min(cap, #list) do trimmed[i] = list[i] end list = trimmed end H.St.CachedTargets = list return list end
function H.GetCameraAimError(targetPosition) if not H.Camera then return math.huge end local direction = targetPosition - H.Camera.CFrame.Position if direction.Magnitude <= 0.001 then return math.huge end direction = direction.Unit local dot = math.clamp(H.Camera.CFrame.LookVector:Dot(direction), -1, 1) return math.deg(math.acos(dot)) end
function H.InvalidateTargetCache() H.St.CachedTargets = {} H.St.LastTargetScan = 0 H.St.LockedTargetModel = nil H.St.CurrentTargetModel = nil H.St.VisibilityCache = {} end
function H.GetClosestTarget()
    if not H.Camera then return nil, nil end
    local aimPos = H.GetAimViewportPosition()
    local camPos = H.Camera.CFrame.Position
    if H.S.TargetSticky and H.St.LockedTargetModel and H.IsAlive(H.St.LockedTargetModel) then
        local targetPart = H.GetBestTargetPart(H.St.LockedTargetModel)
        if targetPart then
            local distFromCam = (camPos - targetPart.Position).Magnitude
            local predictedPos = H.GetPredictedPosition(targetPart, H.St.LockedTargetModel)
            local screenPos = H.Camera:WorldToViewportPoint(predictedPos)
            if distFromCam <= H.S.MaxDistance and screenPos.Z > 0 then
                local distToAim = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
                local visible = H.IsPartVisibleCached(targetPart, H.St.LockedTargetModel)
                local needsVisible = H.S.VisibleOnly or H.S.UseLineOfSightForSticky
                if distToAim <= (H.S.AimFOV * H.S.TargetGraceFOV) and ((not needsVisible) or visible) then
                    return targetPart, H.St.LockedTargetModel
                end
            end
        end
    end
    local closestPart = nil
    local closestModel = nil
    local bestMetric = math.huge
    for _, target in ipairs(H.GetTargetsList()) do
        local model = target.Model
        if H.IsAlive(model) then
            local targetPart = H.GetBestTargetPart(model)
            if targetPart then
                local distFromCam = (camPos - targetPart.Position).Magnitude
                if distFromCam <= H.S.MaxDistance then
                    local predictedPos = H.GetPredictedPosition(targetPart, model)
                    local screenPos = H.Camera:WorldToViewportPoint(predictedPos)
                    if screenPos.Z > 0 then
                        local distToAim = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
                        if distToAim <= H.S.AimFOV then
                            if not (H.S.AimDeadzone > 0 and distToAim < H.S.AimDeadzone) then
                                local angularError = H.GetCameraAimError(predictedPos)
                                if angularError <= H.S.AimMaxAngle then
                                    if not H.S.VisibleOnly or H.IsPartVisibleCached(targetPart, model) then
                                        local metric
                                        if H.S.TargetPriority == "Distance" then metric = distFromCam + angularError * 7 else metric = distToAim + angularError * 10 + distFromCam * 0.004 end
                                        if metric < bestMetric then bestMetric = metric; closestPart = targetPart; closestModel = model end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if closestModel then
        local canSwitch = (os.clock() - H.St.lastTargetSwitch) >= H.S.TargetSwitchCooldown
        local currentAlive = H.St.LockedTargetModel and H.IsAlive(H.St.LockedTargetModel)
        if canSwitch or not currentAlive then H.St.LockedTargetModel = closestModel; H.St.lastTargetSwitch = os.clock() else closestModel = H.St.LockedTargetModel; closestPart = H.GetBestTargetPart(closestModel) end
    else H.St.LockedTargetModel = nil end
    return closestPart, closestModel
end

-- CONFIG
H.AllowedConfigKeys = { Aimbot = true, SilentAim = true, Triggerbot = true, ESPEnabled = true, Players = true, NPCs = true, Boxes = true, CornerBoxes = true, BoxFill = true, PlayerInfo = true, HeadDot = true, Tracers = true, OffscreenArrows = true, ChestESP = true, Rainbow = true, VisibleOnly = true, Prediction = true, TargetSticky = true, HideUser = true, ShowFOV = true, TargetHUD = true, Watermark = true, Crosshair = true, NotificationsEnabled = true, ShowKeybindHints = true, MobileToggleVisible = true, MobileAimButton = true, PerformanceProfile = true, AimFOV = true, AimSmoothness = true, AimResponsiveness = true, AimMaxAngle = true, MaxDistance = true, MaxESPObjects = true, ChestMaxDistance = true, ChestFillTransparency = true, ChestFilter = true, AimPart = true, TargetPriority = true, AntiAFK = true }
function H.GetConfigSnapshot() return { ConfigVersion = 12, Aimbot = H.S.Aimbot, SilentAim = H.S.SilentAim, Triggerbot = H.S.Triggerbot, ESPEnabled = H.S.ESPEnabled, Players = H.S.Players, NPCs = H.S.NPCs, Boxes = H.S.Boxes, CornerBoxes = H.S.CornerBoxes, BoxFill = H.S.BoxFill, PlayerInfo = H.S.PlayerInfo, HeadDot = H.S.HeadDot, Tracers = H.S.Tracers, OffscreenArrows = H.S.OffscreenArrows, ChestESP = H.S.ChestESP, Rainbow = H.S.Rainbow, VisibleOnly = H.S.VisibleOnly, Prediction = H.S.Prediction, TargetSticky = H.S.TargetSticky, HideUser = H.S.HideUser, ShowFOV = H.S.ShowFOV, TargetHUD = H.S.TargetHUD, Watermark = H.S.Watermark, Crosshair = H.S.Crosshair, NotificationsEnabled = H.S.NotificationsEnabled, ShowKeybindHints = H.S.ShowKeybindHints, MobileToggleVisible = H.S.MobileToggleVisible, MobileAimButton = H.S.MobileAimButton, PerformanceProfile = H.S.PerformanceProfile, AimFOV = H.S.AimFOV, AimSmoothness = H.S.AimSmoothness, AimResponsiveness = H.S.AimResponsiveness, AimMaxAngle = H.S.AimMaxAngle, MaxDistance = H.S.MaxDistance, MaxESPObjects = H.S.MaxESPObjects, ChestMaxDistance = H.S.ChestMaxDistance, ChestFillTransparency = H.S.ChestFillTransparency, ChestFilter = H.S.ChestFilter, AimPart = H.S.AimPart, TargetPriority = H.S.TargetPriority, AimbotKey = H.S.AimbotKey.Name, ESPKey = H.S.ESPKey.Name, MenuKey = H.S.MenuKey.Name, TriggerKey = H.S.TriggerKey.Name, AntiAFK = H.S.AntiAFK } end
function H.DecodeKeyCode(value) if type(value) ~= "string" then return nil end value = tostring(value):gsub("%s+", "") local ok, key = pcall(function() return Enum.KeyCode[value] end) return (ok and key and key ~= Enum.KeyCode.Unknown) and key or nil end
function H.SyncPlayerInfo() H.S.Names = H.S.PlayerInfo; H.S.Health = H.S.PlayerInfo; H.S.HealthText = H.S.PlayerInfo; H.S.Distance = H.S.PlayerInfo end
function H.ApplyConfigSnapshot(data) if type(data) ~= "table" then return false end for key, value in pairs(data) do if H.AllowedConfigKeys[key] and H.S[key] ~= nil and type(value) == type(H.S[key]) then H.S[key] = value end end H.S.AimbotKey = H.DecodeKeyCode(data.AimbotKey) or H.S.AimbotKey; H.S.ESPKey = H.DecodeKeyCode(data.ESPKey) or H.S.ESPKey; H.S.MenuKey = H.DecodeKeyCode(data.MenuKey) or H.S.MenuKey; H.S.TriggerKey = H.DecodeKeyCode(data.TriggerKey) or H.S.TriggerKey; H.SyncPlayerInfo(); H.ApplyPerformanceProfile(H.S.PerformanceProfile); H.InvalidateTargetCache() for key, refresh in pairs(H.UIRefreshers) do pcall(refresh, H.S[key]) end for key, refresh in pairs(H.KeybindRefreshers) do pcall(refresh, H.S[key]) end if H.UpdateFooter then H.UpdateFooter() end return true end
function H.SaveConfig() local data = H.GetConfigSnapshot() H.St.ConfigMemory = data local http = H.HttpService or game:GetService("HttpService") if type(writefile) ~= "function" then H.Notify("CONFIG", "Session backup saved", true) return end local ok = pcall(function() writefile(H.S.SaveConfigName, http:JSONEncode(data)) end) H.Notify("CONFIG", ok and "Configuration saved" or "Save failed • session backup kept", ok) end
function H.LoadConfig() local data local http = H.HttpService or game:GetService("HttpService") if type(readfile) == "function" and type(isfile) == "function" then local ok, raw = pcall(function() if isfile(H.S.SaveConfigName) then return readfile(H.S.SaveConfigName) end end) if ok and type(raw) == "string" and raw ~= "" then local decodedOk, decoded = pcall(function() return http:JSONDecode(raw) end) if decodedOk and type(decoded) == "table" then data = decoded end end end data = data or H.St.ConfigMemory if H.ApplyConfigSnapshot(data) then H.Notify("CONFIG", "Configuration loaded", true) return true end H.Notify("CONFIG", "No saved configuration found", false) return false end
function H.ResetConfig() if type(H.DefaultSettings) ~= "table" then H.Notify("CONFIG", "Reset unavailable", false) return end for k, v in pairs(H.DefaultSettings) do if H.S[k] ~= nil and type(v) == type(H.S[k]) then H.S[k] = v end end H.SyncPlayerInfo(); H.ApplyPerformanceProfile(H.S.PerformanceProfile); H.InvalidateTargetCache() for key, refresh in pairs(H.UIRefreshers) do pcall(refresh, H.S[key]) end for key, refresh in pairs(H.KeybindRefreshers) do pcall(refresh, H.S[key]) end if H.UpdateFooter then H.UpdateFooter() end H.Notify("CONFIG", "Configuration reset", true) end

-- ANTI-AFK
function H.InitAntiAFK()
    if H.St.AntiAFKLoop then return end
    H.St.AntiAFKLoop = task.spawn(function()
        while H.S.AntiAFK do
            pcall(function()
                if H.VirtualInputManager and H.LocalPlayer and H.LocalPlayer.Character and H.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local vu = game:GetService("VirtualUser")
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new(0,0))
                end
            end)
            task.wait(60)
        end
        H.St.AntiAFKLoop = nil
    end)
end

-- AIMBOT / TRIGGERBOT
function H.InitAimbot()
    H.RunService:BindToRenderStep("DragonAimbotStep", Enum.RenderPriority.Camera.Value + 10, function(delta)
        if not H.Camera then H.Camera = workspace.CurrentCamera end
        if not H.Camera then return end
        
        if H.S.Aimbot or H.St.MobileAimActive then
            local targetPart, targetModel = H.GetClosestTarget()
            H.St.CurrentTargetModel = targetModel
            if targetPart and targetModel and not H.St.menuVisible then
                local predictedPos = H.GetPredictedPosition(targetPart, targetModel)
                local currentCF = H.Camera.CFrame
                local toTarget = predictedPos - currentCF.Position
                if toTarget.Magnitude > 0.001 then
                    local targetCF = CFrame.lookAt(currentCF.Position, predictedPos)
                    local smoothValue = math.clamp(H.S.AimSmoothness, 1, 50)
                    local response = math.clamp((60 / smoothValue) * (H.S.AimResponsiveness / 100), 0.5, 45)
                    local lerpAlpha = 1 - math.exp(-delta * response)
                    lerpAlpha = math.clamp(lerpAlpha, 0.015, 0.72)
                    
                    -- SILENT AIM LOGIC: Don't move camera if SilentAim is ON
                    if not H.S.SilentAim then
                        H.Camera.CFrame = currentCF:Lerp(targetCF, lerpAlpha)
                    end
                end
            end
        else
            H.St.CurrentTargetModel = nil
            H.St.LockedTargetModel = nil
        end
        
        if H.S.Triggerbot and H.VirtualInputManager and not H.St.menuVisible and (os.clock() - H.St.LastTriggerTime) >= 0.05 then
            local mousePos = H.GetAimViewportPosition()
            local unitRay = H.Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
            H.SetRaycastFilter(nil)
            local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * H.S.MaxDistance, H.SharedRaycastParams)
            if result and result.Instance then
                local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
                if hitModel and H.IsAlive(hitModel) then
                    H.St.LastTriggerTime = os.clock()
                    pcall(function() H.VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 0) end)
                    task.delay(0.012, function() pcall(function() H.VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 0) end) end)
                end
            end
        end
    end)
end

-- CHEST ESP
H.CHEST_RARITIES = { "Legendary", "Epic", "Rare", "Uncommon", "Common" }
H.CHEST_COLORS = { Common = Color3.fromRGB(178, 182, 190), Uncommon = Color3.fromRGB(76, 210, 126), Rare = Color3.fromRGB(74, 147, 255), Epic = Color3.fromRGB(183, 92, 255), Legendary = Color3.fromRGB(255, 175, 58) }
function H.ClassifyChest(instance) if not instance then return nil end local name = string.lower(instance.Name) local rarity = nil for _, key in ipairs({"Rarity", "ChestRarity", "Tier"}) do local ok, value = pcall(function() return instance:GetAttribute(key) end) if ok and value ~= nil then rarity = tostring(value) break end end local text = string.lower(tostring(rarity or name)) if not string.find(text, "chest", 1, true) and not rarity then return nil end for _, r in ipairs(H.CHEST_RARITIES) do if string.find(text, string.lower(r), 1, true) then return r end end return "Common" end
function H.GetChestPart(instance) if instance:IsA("BasePart") then return instance end if instance:IsA("Model") then return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true) end return nil end
function H.RemoveChestESP(instance) local data = H.St.ChestObjects[instance] if data then if data.Highlight then data.Highlight:Destroy() end H.St.ChestObjects[instance] = nil end end
function H.ClearAllChestESP() local list = {} for instance in pairs(H.St.ChestObjects) do table.insert(list, instance) end for _, instance in ipairs(list) do H.RemoveChestESP(instance) end end
function H.CreateChestESP(instance, rarity) if not H.S.ChestESP then return end if H.St.ChestObjects[instance] then return end if H.S.ChestFilter ~= "All" and rarity ~= H.S.ChestFilter then return end local part = H.GetChestPart(instance) if not part then return end if H.Camera and H.S.ChestMaxDistance > 0 then if (part.Position - H.Camera.CFrame.Position).Magnitude > H.S.ChestMaxDistance then return end end local color = H.CHEST_COLORS[rarity] or H.CHEST_COLORS.Common local ok = pcall(function() local highlight = Instance.new("Highlight") highlight.Name = "DragonChestESP" highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop highlight.FillColor = color highlight.FillTransparency = math.clamp(H.S.ChestFillTransparency / 100, 0, 1) highlight.OutlineColor = color highlight.OutlineTransparency = 0.08 highlight.Adornee = instance:IsA("Model") and instance or part highlight.Parent = H.G.ESPFolder H.St.ChestObjects[instance] = { Highlight = highlight, Part = part, Rarity = rarity } end) if not ok then warn("[Dragon Hub] Failed to create chest highlight.") end end
function H.ScanChestsOnce() if not H.S.ChestESP then return end local ok, descendants = pcall(function() return workspace:GetDescendants() end) if not ok or type(descendants) ~= "table" then return end for _, instance in ipairs(descendants) do if instance:IsA("Model") then local classifyOk, rarity = pcall(H.ClassifyChest, instance) if classifyOk and rarity then H.CreateChestESP(instance, rarity) end end end end
function H.RefreshChestESP() H.ClearAllChestESP() if H.S.ChestESP then task.defer(H.ScanChestsOnce) end end
function H.InitChestESP() workspace.DescendantAdded:Connect(function(instance) if not H.S.ChestESP then return end if instance:IsA("Model") or instance:IsA("BasePart") then task.defer(function() local rarity = H.ClassifyChest(instance) if rarity then H.CreateChestESP(instance, rarity) end end) end end) workspace.DescendantRemoving:Connect(function(instance) pcall(H.RemoveChestESP, instance) end) task.defer(H.ScanChestsOnce) end

-- ESP ENGINE
function H.CreateLine(parent) local line = Instance.new("Frame") line.AnchorPoint = Vector2.new(0.5, 0.5) line.BorderSizePixel = 0 line.BackgroundColor3 = H.S.Color line.Visible = false line.Parent = parent return line end
function H.SetLine(line, from, to, thickness, color) local delta = to - from line.Size = UDim2.fromOffset(delta.Magnitude, thickness) line.Position = UDim2.fromOffset((from.X + to.X) * 0.5, (from.Y + to.Y) * 0.5) line.Rotation = math.deg(math.atan2(delta.Y, delta.X)) line.BackgroundColor3 = color line.Visible = true end
function H.RemoveESP(model) local data = H.St.Objects[model] if not data then return end if data.DestroyConnection then pcall(function() data.DestroyConnection:Disconnect() end) end if data.Gui then data.Gui:Destroy() end if data.Highlight then data.Highlight:Destroy() end H.St.Objects[model] = nil H.St.VisibilityCache[model] = nil end
function H.CreateESP(model, player) if H.St.Objects[model] then H.RemoveESP(model) end if not H.IsAlive(model) then return end local gui = Instance.new("Frame", H.G.ESPGui) gui.Name = "ESP_" .. model.Name gui.Size = UDim2.fromScale(1, 1) gui.BackgroundTransparency = 1 gui.BorderSizePixel = 0 local box = Instance.new("Frame", gui) box.BackgroundTransparency = 1 box.BorderSizePixel = 0 box.Visible = false local boxStroke = Instance.new("UIStroke", box) boxStroke.Thickness = H.S.BoxThickness boxStroke.Color = H.S.Color local boxFill = Instance.new("Frame", gui) boxFill.BackgroundColor3 = H.S.Color boxFill.BackgroundTransparency = H.S.BoxFillTransparency boxFill.BorderSizePixel = 0 boxFill.Visible = false boxFill.ZIndex = 0 local corners = {} for i = 1, 8 do local line = H.CreateLine(gui) line.Visible = false table.insert(corners, line) end local tracer = H.CreateLine(gui) tracer.Visible = false local headDot = Instance.new("Frame", gui) headDot.Size = UDim2.fromOffset(4, 4) headDot.AnchorPoint = Vector2.new(0.5, 0.5) headDot.BackgroundColor3 = H.S.Color headDot.BorderSizePixel = 0 headDot.Visible = false local headDotCorner = Instance.new("UICorner", headDot) headDotCorner.CornerRadius = UDim.new(1, 0) local name = Instance.new("TextLabel", gui) name.BackgroundTransparency = 1 name.Font = H.Fonts.Code name.TextSize = 8 name.TextColor3 = H.Palette.Accent name.TextStrokeTransparency = 0.55 name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) name.Visible = false name.Text = "" local distanceText = Instance.new("TextLabel", gui) distanceText.BackgroundTransparency = 1 distanceText.Font = H.Fonts.Code distanceText.TextSize = 8 distanceText.TextColor3 = H.Palette.TextLight distanceText.TextStrokeTransparency = 0.55 distanceText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) distanceText.Visible = false distanceText.Text = "" local healthBack = Instance.new("Frame", gui) healthBack.BackgroundColor3 = Color3.fromRGB(10, 6, 18) healthBack.BorderSizePixel = 0 healthBack.Visible = false local healthBar = Instance.new("Frame", healthBack) healthBar.BorderSizePixel = 0 healthBar.BackgroundColor3 = H.Palette.Accent local healthVal = Instance.new("TextLabel", gui) healthVal.BackgroundTransparency = 1 healthVal.Font = H.Fonts.Code healthVal.TextSize = 8 healthVal.TextColor3 = H.Palette.TextLight healthVal.TextStrokeTransparency = 0.35 healthVal.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) healthVal.Visible = false healthVal.Text = "" local arrow = Instance.new("Frame", gui) arrow.Size = UDim2.fromOffset(8, 8) arrow.AnchorPoint = Vector2.new(0.5, 0.5) arrow.BackgroundColor3 = H.S.Color arrow.BorderSizePixel = 0 arrow.Visible = false local arrowCorner = Instance.new("UICorner", arrow) arrowCorner.CornerRadius = UDim.new(0, 2) local highlight = Instance.new("Highlight") highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop highlight.FillTransparency = 0.82 highlight.OutlineTransparency = 0.18 highlight.Enabled = false highlight.Adornee = model highlight.Parent = H.G.ESPFolder local destroyConnection pcall(function() destroyConnection = model.Destroying:Connect(function() H.RemoveESP(model) end) end) local cachedName = player and player.Name or (model.Name .. " [BOT]") local cachedNameText = string.upper(cachedName) local cachedNameWidth = math.clamp((#cachedNameText * 4.4) + 6, 24, 190) H.St.Objects[model] = { Model = model, Player = player, Gui = gui, Box = box, BoxStroke = boxStroke, BoxFill = boxFill, Corners = corners, Tracer = tracer, HeadDot = headDot, Name = name, DistanceText = distanceText, HealthBack = healthBack, HealthBar = healthBar, HealthVal = healthVal, Arrow = arrow, Highlight = highlight, DestroyConnection = destroyConnection, CachedName = cachedName, NameWidth = cachedNameWidth, CachedDistanceLabel = nil } end
function H.HideESP(data) if not data then return end data.Box.Visible = false data.BoxFill.Visible = false data.HeadDot.Visible = false data.Name.Visible = false data.DistanceText.Visible = false data.HealthBack.Visible = false data.HealthVal.Visible = false data.Arrow.Visible = false data.Tracer.Visible = false data.Highlight.Enabled = false if data.Corners then for _, c in ipairs(data.Corners) do c.Visible = false end end end
function H.InitESP()
    H.I("ESPGui", "ScreenGui", H.PlayerGui, { Name = "DragonESPVisuals", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 20 })
    H.RunService.RenderStepped:Connect(function()
        H.St.fpsCounter += 1
        if tick() - H.St.lastTime >= 1 then H.St.currentFPS = H.St.fpsCounter; H.St.fpsCounter = 0; H.St.lastTime = tick() end
        if not H.Camera then H.Camera = workspace.CurrentCamera end
        if not H.Camera then return end
        local themeColor = H.GetColor()
        if (tick() - H.St.LastOverlayStep) >= H.S.UIStatusUpdateInterval then
            H.St.LastOverlayStep = tick()
            if H.S.Watermark then
                local ping = 0
                if H.Stats then pcall(function() ping = math.floor(H.Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end) end
                H.G.WatermarkText.Text = string.format("DRAGON HUB 3.1 | %d FPS | %d ms", H.St.currentFPS, ping)
                H.G.WatermarkFrame.Visible = true
            else H.G.WatermarkFrame.Visible = false end
        end
        if H.S.Crosshair and not H.St.menuVisible then
            local vp = H.Camera.ViewportSize
            H.G.Crosshair.Position = UDim2.fromOffset(vp.X * 0.5, vp.Y * 0.5)
            H.G.CrosshairH.BackgroundColor3 = themeColor; H.G.CrosshairV.BackgroundColor3 = themeColor; H.G.Crosshair.Visible = true
        else H.G.Crosshair.Visible = false end
        if (tick() - H.St.LastTargetHUDStep) >= 0.08 then
            H.St.LastTargetHUDStep = tick()
            if H.S.TargetHUD and H.St.CurrentTargetModel and H.IsAlive(H.St.CurrentTargetModel) then
                local hum = H.GetHumanoid(H.St.CurrentTargetModel)
                local root = H.GetCharacterRoot(H.St.CurrentTargetModel)
                if hum and root then
                    local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    local dist = (H.Camera.CFrame.Position - root.Position).Magnitude
                    local player = H.Players:GetPlayerFromCharacter(H.St.CurrentTargetModel)
                    local pName = player and player.Name or H.St.CurrentTargetModel.Name
                    H.G.TargetName.Text = string.upper(pName)
                    H.G.TargetSub.Text = string.format("DIST: %dm | HP: %d%%", math.floor(dist), math.floor(hpPct * 100))
                    H.G.TargetHealthBar.Size = UDim2.new(hpPct, 0, 1, 0)
                    H.G.TargetHealthBar.BackgroundColor3 = Color3.fromRGB(168 * (1 - hpPct), 220 * hpPct, 255 * hpPct)
                    H.G.TargetFrame.Visible = true
                else H.G.TargetFrame.Visible = false end
            else H.G.TargetFrame.Visible = false end
        end
        if H.St.menuVisible and H.S.UnlockMouseWithUI then
            if H.UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then H.UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
            if not H.UserInputService.MouseIconEnabled then H.UserInputService.MouseIconEnabled = true end
        end
        if H.S.ShowFOV and (H.S.Aimbot or H.St.MobileAimActive) then
            H.G.FOVCircle.Size = UDim2.fromOffset(H.S.AimFOV * 2, H.S.AimFOV * 2)
            local aimPos = H.GetAimViewportPosition()
            H.G.FOVCircle.Position = UDim2.fromOffset(aimPos.X, aimPos.Y)
            H.G.FOVCircle.Visible = true
            H.G.FOVStroke.Color = (H.S.DynamicFOVColor and H.St.CurrentTargetModel) and H.S.FOVLockedColor or H.S.FOVColor
        else H.G.FOVCircle.Visible = false end
        local now = os.clock()
        local minTimeStep = H.S.PerformanceMode and H.S.ESPPerformanceInterval or H.S.ESPUpdateInterval
        if H.S.AdaptivePerformance then if H.St.currentFPS < 30 then minTimeStep = H.S.ESPLowFPSStep elseif H.St.currentFPS < 45 then minTimeStep = math.max(minTimeStep, 0.028) end end
        if (now - H.St.LastESPStep) < minTimeStep then return end
        H.St.LastESPStep = now
        if not H.S.ESPEnabled then for _, data in pairs(H.St.Objects) do H.HideESP(data) end return end
        local currentTargets = H.GetTargetsList()
        for _, target in ipairs(currentTargets) do if not H.St.Objects[target.Model] then H.CreateESP(target.Model, target.Player) end end
        for model in pairs(H.St.Objects) do if not model or not model.Parent then H.RemoveESP(model) end end
        local vpSize = H.Camera.ViewportSize
        local vpCenter = Vector2.new(vpSize.X * 0.5, vpSize.Y * 0.5)
        local camCF = H.Camera.CFrame
        local camPos = camCF.Position
        local camLook = camCF.LookVector
        local maxDistSq = H.S.MaxDistance * H.S.MaxDistance
        for model, data in pairs(H.St.Objects) do
            local categoryEnabled = (data.Player and H.S.Players) or ((not data.Player) and H.S.NPCs)
            if not model or not model.Parent or not H.IsAlive(model) or not categoryEnabled then H.HideESP(data) if not H.IsAlive(model) then H.RemoveESP(model) end continue end
            local root = H.GetCharacterRoot(model)
            if not root then H.HideESP(data) continue end
            local rootPos = root.Position
            local dirToRoot = rootPos - camPos
            local distSq = dirToRoot.X * dirToRoot.X + dirToRoot.Y * dirToRoot.Y + dirToRoot.Z * dirToRoot.Z
            if distSq > maxDistSq then H.HideESP(data) continue end
            local isBehind = camLook:Dot(dirToRoot) <= 0
            if isBehind then
                H.HideESP(data)
                if H.S.OffscreenArrows then
                    local proj = camCF:VectorToObjectSpace(dirToRoot)
                    local angle = math.atan2(-proj.Y, proj.X)
                    local radius = math.min(vpSize.X, vpSize.Y) * 0.38
                    local arrowPos = vpCenter + Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
                    data.Arrow.Position = UDim2.fromOffset(arrowPos.X, arrowPos.Y)
                    data.Arrow.Rotation = math.deg(angle) + 90
                    data.Arrow.BackgroundColor3 = themeColor
                    data.Arrow.Visible = true
                end
                continue
            else data.Arrow.Visible = false end
            local boundsMin, boundsMax = H.GetFastScreenBounds(model)
            if not boundsMin or not boundsMax then H.HideESP(data) continue end
            local distance = math.sqrt(distSq)
            local boxPos = boundsMin
            local boxWidth = math.max(8, boundsMax.X - boundsMin.X)
            local boxHeight = math.max(12, boundsMax.Y - boundsMin.Y)
            data.BoxStroke.Thickness = H.S.BoxThickness
            if H.S.Boxes then data.Box.Position = UDim2.fromOffset(boxPos.X, boxPos.Y); data.Box.Size = UDim2.fromOffset(boxWidth, boxHeight); data.BoxStroke.Color = themeColor; data.Box.Visible = true else data.Box.Visible = false end
            data.BoxFill.Position = UDim2.fromOffset(boxPos.X, boxPos.Y); data.BoxFill.Size = UDim2.fromOffset(boxWidth, boxHeight); data.BoxFill.BackgroundColor3 = themeColor; data.BoxFill.BackgroundTransparency = H.S.BoxFillTransparency; data.BoxFill.Visible = H.S.Boxes and H.S.BoxFill
            for _, line in ipairs(data.Corners) do line.Visible = false end
            if H.S.Boxes and H.S.CornerBoxes then
                local c = math.min(12, math.min(boxWidth, boxHeight) * 0.28)
                local x1, y1 = boxPos.X, boxPos.Y
                local x2, y2 = boxPos.X + boxWidth, boxPos.Y + boxHeight
                local segments = { {Vector2.new(x1, y1), Vector2.new(x1 + c, y1)}, {Vector2.new(x1, y1), Vector2.new(x1, y1 + c)}, {Vector2.new(x2, y1), Vector2.new(x2 - c, y1)}, {Vector2.new(x2, y1), Vector2.new(x2, y1 + c)}, {Vector2.new(x1, y2), Vector2.new(x1 + c, y2)}, {Vector2.new(x1, y2), Vector2.new(x1, y2 - c)}, {Vector2.new(x2, y2), Vector2.new(x2 - c, y2)}, {Vector2.new(x2, y2), Vector2.new(x2, y2 - c)} }
                for i, seg in ipairs(segments) do H.SetLine(data.Corners[i], seg[1], seg[2], H.S.BoxThickness, themeColor) end
                data.Box.Visible = false
            end
            if H.S.Tracers then local rootScreen = H.Camera:WorldToViewportPoint(rootPos) if rootScreen.Z > 0 then H.SetLine(data.Tracer, Vector2.new(vpSize.X * 0.5, vpSize.Y), Vector2.new(rootScreen.X, rootScreen.Y), 1, themeColor) else data.Tracer.Visible = false end else data.Tracer.Visible = false end
            local headPart = model:FindFirstChild("Head")
            if H.S.HeadDot and headPart then local headPos = H.Camera:WorldToViewportPoint(headPart.Position) if headPos.Z > 0 then data.HeadDot.Position = UDim2.fromOffset(headPos.X, headPos.Y); data.HeadDot.BackgroundColor3 = themeColor; data.HeadDot.Visible = true else data.HeadDot.Visible = false end else data.HeadDot.Visible = false end
            if H.S.Names then data.Name.Text = string.upper(data.CachedName); local nameW = math.clamp((data.NameWidth or 40) + 6, 24, math.min(190, math.max(48, boxWidth + 26))); local nameX = math.clamp(boxPos.X + (boxWidth - nameW) * 0.5, 2, vpSize.X - nameW - 2); local nameY = math.max(2, boxPos.Y - 17); data.Name.Position = UDim2.fromOffset(nameX + 2, nameY + 1); data.Name.Size = UDim2.fromOffset(nameW - 4, 11); data.Name.TextXAlignment = Enum.TextXAlignment.Center; data.Name.Visible = true else data.Name.Visible = false end
            local humanoid = H.GetHumanoid(model)
            if humanoid then
                local hpPct = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                if H.S.Health then data.HealthBack.Position = UDim2.fromOffset(boxPos.X - 5, boxPos.Y); data.HealthBack.Size = UDim2.fromOffset(2, boxHeight); data.HealthBack.Visible = true; data.HealthBar.AnchorPoint = Vector2.new(0, 1); data.HealthBar.Position = UDim2.new(0, 0, 1, 0); data.HealthBar.Size = UDim2.new(1, 0, hpPct, 0); data.HealthBar.BackgroundColor3 = Color3.fromRGB(168 * (1 - hpPct), 220 * hpPct, 255 * hpPct) else data.HealthBack.Visible = false end
                if H.S.HealthText then data.HealthVal.Text = string.format("%d%%", math.floor(hpPct * 100)); data.HealthVal.Position = UDim2.fromOffset(boxPos.X - 34, boxPos.Y + (boxHeight * (1 - hpPct)) - 6); data.HealthVal.Size = UDim2.fromOffset(26, 12); data.HealthVal.Visible = true else data.HealthVal.Visible = false end
            else data.HealthBack.Visible = false; data.HealthVal.Visible = false end
            if H.S.Distance then local distanceLabel = string.format("%dm", math.floor(distance)) if data.CachedDistanceLabel ~= distanceLabel then data.CachedDistanceLabel = distanceLabel; data.DistanceText.Text = distanceLabel end local distW = math.max(24, (#distanceLabel * 4.4) + 8) local distX = math.clamp(boxPos.X + (boxWidth - distW) * 0.5, 2, vpSize.X - distW - 2) data.DistanceText.Position = UDim2.fromOffset(distX + 2, boxPos.Y + boxHeight + 2) data.DistanceText.Size = UDim2.fromOffset(distW - 4, 10) data.DistanceText.TextXAlignment = Enum.TextXAlignment.Center data.DistanceText.Visible = true else data.DistanceText.Visible = false end
            if H.S.TargetHighlight and H.St.CurrentTargetModel == model then data.Highlight.FillColor = H.Palette.SecondaryAccent; data.Highlight.OutlineColor = H.Palette.AccentGlow; data.Highlight.FillTransparency = 0.92; data.Highlight.OutlineTransparency = 0.05; data.Highlight.Enabled = true else data.Highlight.Enabled = false end
        end
    end)
end

-- UI HELPERS
function H.TweenBackgroundColor(obj, color) if obj then H.TweenService:Create(obj, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = color }):Play() end end
function H.TweenPosition(obj, pos) if obj then H.TweenService:Create(obj, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos }):Play() end end
function H.UpdateUIScale() if not H.G.UIScale then return end local viewportWidth = (H.Camera and H.Camera.ViewportSize.X) or 1280 local viewportHeight = (H.Camera and H.Camera.ViewportSize.Y) or 720 local scaleW = viewportWidth / (H.St.WindowW + 40) local scaleH = viewportHeight / (H.St.WindowH + 60) local target = math.min(scaleW, scaleH, 1) if H.IsTouchDevice then target = math.min(target, 0.76) end H.G.UIScale.Scale = math.clamp(target, 0.48, 1) end
function H.ReleaseMouseForUI() if not H.St.previousCameraMode then H.St.previousCameraMode = H.LocalPlayer.CameraMode end if H.St.previousMouseBehavior == nil then H.St.previousMouseBehavior = H.UserInputService.MouseBehavior end if H.St.previousMouseIconEnabled == nil then H.St.previousMouseIconEnabled = H.UserInputService.MouseIconEnabled end pcall(function() H.LocalPlayer.CameraMode = Enum.CameraMode.Classic end) H.UserInputService.MouseBehavior = Enum.MouseBehavior.Default H.UserInputService.MouseIconEnabled = true end
function H.RestoreMouseAfterUI() pcall(function() if H.St.previousCameraMode then H.LocalPlayer.CameraMode = H.St.previousCameraMode end end) if H.St.previousMouseBehavior ~= nil then H.UserInputService.MouseBehavior = H.St.previousMouseBehavior end if H.St.previousMouseIconEnabled ~= nil then H.UserInputService.MouseIconEnabled = H.St.previousMouseIconEnabled end H.St.previousCameraMode = nil H.St.previousMouseBehavior = nil H.St.previousMouseIconEnabled = nil end
function H.SetMenuVisible(visible) if not H.G.Main then return end H.St.menuVisible = visible H.G.Main.Visible = visible if visible then H.G.Main.Position = UDim2.new(0.5, -(H.St.WindowW / 2), 0.5, -((H.St.WindowH / 2) - 6)) H.TweenService:Create(H.G.Main, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -(H.St.WindowW / 2), 0.5, -(H.St.WindowH / 2))}):Play() end if H.G.MobileToggleBtn then H.G.MobileToggleBtn.Visible = H.S.MobileToggleVisible and H.IsTouchDevice and not visible end if H.G.MobileCloseBtn then H.G.MobileCloseBtn.Visible = H.IsTouchDevice and visible end if H.G.MobileAimBtn then H.G.MobileAimBtn.Visible = H.S.MobileAimButton and H.IsTouchDevice end if visible then H.ReleaseMouseForUI() else H.RestoreMouseAfterUI() end end
function H.UpdateStatus() if not H.G.StatusPill then return end if H.St.menuVisible then H.G.StatusPill.Text = "MENU OPEN"; H.G.StatusPill.TextColor3 = H.Palette.AccentGlow else H.G.StatusPill.Text = H.S.Aimbot and "AIM ON" or "READY"; H.G.StatusPill.TextColor3 = H.S.Aimbot and H.Palette.SecondaryAccent or H.Palette.AccentGlow end end
function H.UpdateKeyPill(valid) if not H.G.KeyPill then return end if valid then H.G.KeyPill.Text = "KEY OK"; H.G.KeyPill.TextColor3 = H.Palette.Success else H.G.KeyPill.Text = H.TESTING_MODE and "TEST MODE" or "NO KEY"; H.G.KeyPill.TextColor3 = H.Palette.TextMuted end end
function H.UpdateFooter() if not H.G.Footer then return end H.G.Footer.Text = string.format("%s Aim • %s ESP • %s Trigger • %s Menu", H.S.AimbotKey.Name, H.S.ESPKey.Name, H.S.TriggerKey.Name, H.S.MenuKey.Name) end
function H.SelectTab(name) for tabName, page in pairs(H.Tabs) do local selected = (tabName == name) page.Visible = selected local btnData = H.TabButtons[tabName] if btnData then btnData.Btn.BackgroundColor3 = selected and H.Palette.Card or H.Palette.Container; btnData.Btn.TextColor3 = selected and H.Palette.AccentGlow or H.Palette.TextMuted; btnData.Stroke.Enabled = selected end end end
function H.CreateTab(name, order) local tabBtn = Instance.new("TextButton", H.G.TabBar) tabBtn.LayoutOrder = order tabBtn.Size = UDim2.new(0.31, 0, 1, 0) tabBtn.BackgroundColor3 = H.Palette.Container tabBtn.Text = name tabBtn.Font = H.Fonts.Header tabBtn.TextSize = 10 tabBtn.TextColor3 = H.Palette.TextMuted tabBtn.BorderSizePixel = 0 tabBtn.AutoButtonColor = false tabBtn.ZIndex = 4 local tabBtnCorner = Instance.new("UICorner", tabBtn) tabBtnCorner.CornerRadius = UDim.new(0, 10) local tabStroke = Instance.new("UIStroke", tabBtn) tabStroke.Color = H.Palette.AccentDark tabStroke.Thickness = 1 tabStroke.Enabled = false local page = Instance.new("ScrollingFrame", H.G.ContentArea) page.Size = UDim2.new(1, 0, 1, 0) page.BackgroundTransparency = 1 page.Visible = false page.ScrollBarThickness = 3 page.ScrollBarImageColor3 = H.Palette.Accent page.BorderSizePixel = 0 page.ZIndex = 2 local pageLayout = Instance.new("UIListLayout", page) pageLayout.Padding = UDim.new(0, 8) pageLayout.SortOrder = Enum.SortOrder.LayoutOrder local pagePad = Instance.new("UIPadding", page) pagePad.PaddingTop = UDim.new(0, 4) pagePad.PaddingLeft = UDim.new(0, 2) pagePad.PaddingRight = UDim.new(0, 2) pagePad.PaddingBottom = UDim.new(0, 8) pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() page.CanvasSize = UDim2.fromOffset(0, pageLayout.AbsoluteContentSize.Y + 16) end) H.Tabs[name] = page H.TabButtons[name] = { Btn = tabBtn, Stroke = tabStroke } tabBtn.Activated:Connect(function() H.SelectTab(name) end) return page end
function H.CreateCard(parent, title, desc) local card = Instance.new("Frame", parent) card.Size = UDim2.new(1, 0, 0, 0) card.AutomaticSize = Enum.AutomaticSize.Y card.BackgroundColor3 = H.Palette.CardAlt card.BorderSizePixel = 0 card.ZIndex = 3 local cardCorner = Instance.new("UICorner", card) cardCorner.CornerRadius = UDim.new(0, 12) local cardStroke = Instance.new("UIStroke", card) cardStroke.Color = H.Palette.Divider cardStroke.Thickness = 1 cardStroke.Transparency = 0.12 local layout = Instance.new("UIListLayout", card) layout.Padding = UDim.new(0, 7) layout.SortOrder = Enum.SortOrder.LayoutOrder local pad = Instance.new("UIPadding", card) pad.PaddingTop = UDim.new(0, 10) pad.PaddingLeft = UDim.new(0, 12) pad.PaddingRight = UDim.new(0, 12) pad.PaddingBottom = UDim.new(0, 10) local label = Instance.new("TextLabel", card) label.Size = UDim2.new(1, 0, 0, 14) label.Text = string.upper(title) label.Font = H.Fonts.Header label.TextSize = 10 label.TextColor3 = H.Palette.AccentGlow label.TextXAlignment = Enum.TextXAlignment.Left label.BackgroundTransparency = 1 label.ZIndex = 4 if desc and desc ~= "" then local descLabel = Instance.new("TextLabel", card) descLabel.Size = UDim2.new(1, 0, 0, 14) descLabel.Text = desc descLabel.Font = H.Fonts.Code descLabel.TextSize = 8 descLabel.TextColor3 = H.Palette.TextMuted descLabel.TextXAlignment = Enum.TextXAlignment.Left descLabel.BackgroundTransparency = 1 descLabel.ZIndex = 4 end return card end
function H.AddInfo(parent, text, height) local label = Instance.new("TextLabel", parent) label.Size = UDim2.new(1, 0, 0, height or 18) label.BackgroundTransparency = 1 label.Text = text label.Font = H.Fonts.Code label.TextSize = 8 label.TextColor3 = H.Palette.TextMuted label.TextXAlignment = Enum.TextXAlignment.Left label.TextWrapped = true label.ZIndex = 4 return label end
function H.AddToggle(parent, text, settingKey, callback) local row = Instance.new("Frame", parent) row.Size = UDim2.new(1, 0, 0, 32) row.BackgroundColor3 = H.Palette.Container row.BackgroundTransparency = 0.22 row.BorderSizePixel = 0 row.ZIndex = 4 local rowCorner = Instance.new("UICorner", row) rowCorner.CornerRadius = UDim.new(0, 9) local label = Instance.new("TextLabel", row) label.Size = UDim2.new(1, -66, 1, 0) label.Position = UDim2.fromOffset(10, 0) label.Text = text label.Font = H.Fonts.Body label.TextSize = 10 label.TextColor3 = H.Palette.TextLight label.TextXAlignment = Enum.TextXAlignment.Left label.BackgroundTransparency = 1 label.ZIndex = 5 local btn = Instance.new("TextButton", row) btn.Size = UDim2.fromOffset(44, 21) btn.Position = UDim2.new(1, -54, 0, 5) btn.BackgroundColor3 = H.S[settingKey] and H.Palette.Accent or H.Palette.Container btn.Text = "" btn.BorderSizePixel = 0 btn.AutoButtonColor = false btn.ZIndex = 6 local btnCorner = Instance.new("UICorner", btn) btnCorner.CornerRadius = UDim.new(1, 0) local knob = Instance.new("Frame", btn) knob.Size = UDim2.fromOffset(15, 15) knob.Position = H.S[settingKey] and UDim2.fromOffset(25, 3) or UDim2.fromOffset(4, 3) knob.BackgroundColor3 = H.Palette.TextLight knob.BorderSizePixel = 0 knob.ZIndex = 7 local knobCorner = Instance.new("UICorner", knob) knobCorner.CornerRadius = UDim.new(1, 0) local function refresh(value, animate) local enabled = value == true H.S[settingKey] = enabled if animate then H.TweenBackgroundColor(btn, enabled and H.Palette.Accent or H.Palette.Container); H.TweenPosition(knob, enabled and UDim2.fromOffset(25, 3) or UDim2.fromOffset(4, 3)) else btn.BackgroundColor3 = enabled and H.Palette.Accent or H.Palette.Container; knob.Position = enabled and UDim2.fromOffset(25, 3) or UDim2.fromOffset(4, 3) end if callback then pcall(callback, enabled) end end H.UIRefreshers[settingKey] = function(value) refresh(value, false) end btn.Activated:Connect(function() refresh(not H.S[settingKey], true) end) end
function H.AddSlider(parent, text, min, max, settingKey, callback) local row = Instance.new("Frame", parent) row.Size = UDim2.new(1, 0, 0, 40) row.BackgroundColor3 = H.Palette.Container row.BackgroundTransparency = 0.22 row.BorderSizePixel = 0 row.ZIndex = 4 local rowCorner = Instance.new("UICorner", row) rowCorner.CornerRadius = UDim.new(0, 9) local label = Instance.new("TextLabel", row) label.Size = UDim2.new(1, -72, 0, 15) label.Position = UDim2.fromOffset(10, 3) label.Text = text label.Font = H.Fonts.Body label.TextSize = 10 label.TextColor3 = H.Palette.TextLight label.TextXAlignment = Enum.TextXAlignment.Left label.BackgroundTransparency = 1 label.ZIndex = 5 local valLabel = Instance.new("TextLabel", row) valLabel.Size = UDim2.fromOffset(60, 15) valLabel.Position = UDim2.new(1, -70, 0, 3) valLabel.Text = tostring(H.S[settingKey]) valLabel.Font = H.Fonts.Code valLabel.TextSize = 9 valLabel.TextColor3 = H.Palette.AccentGlow valLabel.TextXAlignment = Enum.TextXAlignment.Right valLabel.BackgroundTransparency = 1 valLabel.ZIndex = 5 local track = Instance.new("TextButton", row) track.Size = UDim2.new(1, -20, 0, 7) track.Position = UDim2.fromOffset(10, 25) track.BackgroundColor3 = Color3.fromRGB(31, 26, 43) track.BorderSizePixel = 0 track.Text = "" track.AutoButtonColor = false track.ZIndex = 5 local trackCorner = Instance.new("UICorner", track) trackCorner.CornerRadius = UDim.new(1, 0) local initValue = tonumber(H.S[settingKey]) or min local initPct = math.clamp((initValue - min) / (max - min), 0, 1) local fill = Instance.new("Frame", track) fill.Size = UDim2.new(initPct, 0, 1, 0) fill.BackgroundColor3 = H.Palette.AccentGlow fill.BorderSizePixel = 0 fill.ZIndex = 6 local fillCorner = Instance.new("UICorner", fill) fillCorner.CornerRadius = UDim.new(1, 0) local knob = Instance.new("Frame", track) knob.Size = UDim2.fromOffset(11, 11) knob.AnchorPoint = Vector2.new(0.5, 0.5) knob.Position = UDim2.new(initPct, 0, 0.5, 0) knob.BackgroundColor3 = H.Palette.TextLight knob.BorderSizePixel = 0 knob.ZIndex = 7 local knobCorner = Instance.new("UICorner", knob) knobCorner.CornerRadius = UDim.new(1, 0) local sliding = false local function update(input) local sizeX = track.AbsoluteSize.X if sizeX <= 0 then return end local pct = math.clamp((input.Position.X - track.AbsolutePosition.X) / sizeX, 0, 1) local val = math.floor(min + (max - min) * pct + 0.5) H.S[settingKey] = val valLabel.Text = tostring(val) fill.Size = UDim2.new(pct, 0, 1, 0) knob.Position = UDim2.new(pct, 0, 0.5, 0) if callback then pcall(callback, val) end end H.UIRefreshers[settingKey] = function(value) local safe = tonumber(value) or min safe = math.clamp(safe, min, max) H.S[settingKey] = safe local pct = math.clamp((safe - min) / (max - min), 0, 1) valLabel.Text = tostring(safe) fill.Size = UDim2.new(pct, 0, 1, 0) knob.Position = UDim2.new(pct, 0, 0.5, 0) if callback then pcall(callback, safe) end end track.Activated:Connect(function(input) if input and input.Position then update(input) else local mouse = H.UserInputService:GetMouseLocation() update({Position = mouse}) end end) track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = true update(input) end end) H.UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = false end end) H.UserInputService.InputChanged:Connect(function(input) if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end end) end
function H.AddCycle(parent, text, settingKey, options, callback) local row = Instance.new("Frame", parent) row.Size = UDim2.new(1, 0, 0, 32) row.BackgroundColor3 = H.Palette.Container row.BackgroundTransparency = 0.22 row.BorderSizePixel = 0 row.ZIndex = 4 local rowCorner = Instance.new("UICorner", row) rowCorner.CornerRadius = UDim.new(0, 9) local label = Instance.new("TextLabel", row) label.Size = UDim2.new(1, -145, 1, 0) label.Position = UDim2.fromOffset(10, 0) label.Text = text label.Font = H.Fonts.Body label.TextSize = 10 label.TextColor3 = H.Palette.TextLight label.TextXAlignment = Enum.TextXAlignment.Left label.BackgroundTransparency = 1 label.ZIndex = 5 local btn = Instance.new("TextButton", row) btn.Size = UDim2.fromOffset(125, 22) btn.Position = UDim2.new(1, -135, 0, 5) btn.BackgroundColor3 = H.Palette.Card btn.Text = tostring(H.S[settingKey]) btn.Font = H.Fonts.Code btn.TextSize = 9 btn.TextColor3 = H.Palette.AccentGlow btn.BorderSizePixel = 0 btn.AutoButtonColor = false btn.ZIndex = 5 local btnCorner = Instance.new("UICorner", btn) btnCorner.CornerRadius = UDim.new(0, 8) local btnStroke = Instance.new("UIStroke", btn) btnStroke.Color = H.Palette.Divider btnStroke.Thickness = 1 local index = 1 for i, option in ipairs(options) do if option == H.S[settingKey] then index = i end end btn.Text = tostring(options[index]) local function refresh(value) if typeof(value) == "number" then index = math.clamp(math.floor(value), 1, #options) else local found = false for i, option in ipairs(options) do if option == value then index = i found = true break end end if not found then index = 1 end end H.S[settingKey] = options[index] btn.Text = tostring(options[index]) if callback then pcall(callback, options[index]) end end H.UIRefreshers[settingKey] = refresh btn.Activated:Connect(function() index = (index % #options) + 1 refresh(index) end) end
function H.AddButton(parent, text, callback) local btn = Instance.new("TextButton", parent) btn.Size = UDim2.new(1, 0, 0, 34) btn.BackgroundColor3 = H.Palette.Container btn.Text = text btn.Font = H.Fonts.Header btn.TextSize = 10 btn.TextColor3 = H.Palette.AccentGlow btn.BorderSizePixel = 0 btn.AutoButtonColor = false btn.ZIndex = 5 local btnCorner = Instance.new("UICorner", btn) btnCorner.CornerRadius = UDim.new(0, 9) local stroke = Instance.new("UIStroke", btn) stroke.Color = H.Palette.Divider stroke.Thickness = 1 btn.MouseEnter:Connect(function() H.TweenBackgroundColor(btn, H.Palette.Card) end) btn.MouseLeave:Connect(function() H.TweenBackgroundColor(btn, H.Palette.Container) end) btn.Activated:Connect(function() if callback then pcall(callback) end end) return btn end
function H.AddTextBox(parent, label, placeholder, defaultText) local row = Instance.new("Frame", parent) row.Size = UDim2.new(1, 0, 0, 34) row.BackgroundColor3 = H.Palette.Container row.BackgroundTransparency = 0.22 row.BorderSizePixel = 0 row.ZIndex = 4 local rowCorner = Instance.new("UICorner", row) rowCorner.CornerRadius = UDim.new(0, 9) local labelUi = Instance.new("TextLabel", row) labelUi.Size = UDim2.new(0.35, -10, 1, 0) labelUi.Position = UDim2.fromOffset(10, 0) labelUi.Text = label labelUi.Font = H.Fonts.Body labelUi.TextSize = 10 labelUi.TextColor3 = H.Palette.TextLight labelUi.TextXAlignment = Enum.TextXAlignment.Left labelUi.BackgroundTransparency = 1 labelUi.ZIndex = 5 local box = Instance.new("TextBox", row) box.Size = UDim2.new(0.62, -8, 0, 24) box.Position = UDim2.new(0.36, 8, 0, 5) box.BackgroundColor3 = H.Palette.Card box.BorderSizePixel = 0 box.PlaceholderText = placeholder box.PlaceholderColor3 = H.Palette.TextDim box.Text = defaultText or "" box.TextColor3 = H.Palette.TextLight box.TextSize = 10 box.Font = H.Fonts.Code box.ClearTextOnFocus = false box.ZIndex = 5 local boxCorner = Instance.new("UICorner", box) boxCorner.CornerRadius = UDim.new(0, 8) return box end
function H.AddKeybind(parent, text, defaultKeySetting, callback) local row = Instance.new("Frame", parent) row.Size = UDim2.new(1, 0, 0, 32) row.BackgroundColor3 = H.Palette.Container row.BackgroundTransparency = 0.22 row.BorderSizePixel = 0 row.ZIndex = 4 local rowCorner = Instance.new("UICorner", row) rowCorner.CornerRadius = UDim.new(0, 9) local label = Instance.new("TextLabel", row) label.Size = UDim2.new(1, -118, 1, 0) label.Position = UDim2.fromOffset(10, 0) label.Text = text label.Font = H.Fonts.Body label.TextSize = 10 label.TextColor3 = H.Palette.TextLight label.TextXAlignment = Enum.TextXAlignment.Left label.BackgroundTransparency = 1 label.ZIndex = 5 local btn = Instance.new("TextButton", row) btn.Size = UDim2.fromOffset(98, 22) btn.Position = UDim2.new(1, -108, 0, 5) btn.BackgroundColor3 = H.Palette.Card btn.Text = H.S[defaultKeySetting].Name btn.Font = H.Fonts.Code btn.TextSize = 9 btn.TextColor3 = H.Palette.AccentGlow btn.BorderSizePixel = 0 btn.AutoButtonColor = false btn.ZIndex = 5 local btnCorner = Instance.new("UICorner", btn) btnCorner.CornerRadius = UDim.new(0, 8) local stroke = Instance.new("UIStroke", btn) stroke.Color = H.Palette.Divider stroke.Thickness = 1 local function refreshKey(value) btn.Text = (typeof(value) == "EnumItem" and value.Name) or tostring(value or "?") btn.TextColor3 = H.Palette.AccentGlow end H.KeybindRefreshers[defaultKeySetting] = refreshKey btn.Activated:Connect(function() btn.Text = "PRESS KEY" btn.TextColor3 = H.Palette.SecondaryAccent H.St.listeningForKey = { Setting = defaultKeySetting, Button = btn, Callback = callback, Refresh = refreshKey } end) end

-- BUILD MAIN UI
function H.BuildUI()
    H.I("UI", "ScreenGui", H.PlayerGui, { Name = "DragonHubUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Global })
    H.I("Main", "Frame", H.G.UI, { Name = "Main", Size = UDim2.fromOffset(H.St.WindowW, H.St.WindowH), Position = UDim2.new(0.5, -(H.St.WindowW / 2), 0.5, -(H.St.WindowH / 2)), BackgroundColor3 = H.Palette.Background, BorderSizePixel = 0, Visible = false, Active = true, ClipsDescendants = true, ZIndex = 1 })
    H.I("MainCorner", "UICorner", H.G.Main, { CornerRadius = UDim.new(0, 16) })
    H.I("MainStroke", "UIStroke", H.G.Main, { Color = H.Palette.Divider, Thickness = 1.2, Transparency = 0.14 })
    H.I("MainGradient", "UIGradient", H.G.Main, { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 24)), ColorSequenceKeypoint.new(0.55, Color3.fromRGB(24, 24, 32)), ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 24, 42)) }), Rotation = 90 })
    H.I("UIScale", "UIScale", H.G.Main, { Scale = 1 })
    H.UpdateUIScale()
    if H.Camera then H.Camera:GetPropertyChangedSignal("ViewportSize"):Connect(H.UpdateUIScale) end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() H.Camera = workspace.CurrentCamera; H.UpdateUIScale() end)
    H.I("Header", "Frame", H.G.Main, { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = H.Palette.Header, BorderSizePixel = 0, ZIndex = 4 })
    H.I("HeaderCorner", "UICorner", H.G.Header, { CornerRadius = UDim.new(0, 16) })
    H.I("HeaderGradient", "UIGradient", H.G.Header, { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 28, 64)), ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 26)) }), Rotation = 0 })
    H.I("HeaderAccent", "Frame", H.G.Header, { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = H.Palette.Accent, BorderSizePixel = 0, ZIndex = 5 })
    H.I("BrandIcon", "Frame", H.G.Header, { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(12, 11), BackgroundColor3 = H.Palette.Card, BorderSizePixel = 0, ZIndex = 5 })
    H.I("BrandIconCorner", "UICorner", H.G.BrandIcon, { CornerRadius = UDim.new(0, 11) })
    H.I("BrandStroke", "UIStroke", H.G.BrandIcon, { Color = H.Palette.AccentDark, Thickness = 1 })
    H.I("BrandText", "TextLabel", H.G.BrandIcon, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "DR", Font = H.Fonts.Header, TextSize = 14, TextColor3 = H.Palette.AccentGlow, ZIndex = 6 })
    H.I("Title", "TextLabel", H.G.Header, { Position = UDim2.fromOffset(58, 8), Size = UDim2.fromOffset(220, 24), Text = "DRAGON HUB 3.1", Font = H.Fonts.Header, TextSize = 16, TextColor3 = H.Palette.TextLight, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, ZIndex = 5 })
    H.I("Subtitle", "TextLabel", H.G.Header, { Position = UDim2.fromOffset(59, 30), Size = UDim2.fromOffset(230, 16), Text = "V3.1 PHANTOM EDITION", Font = H.Fonts.Code, TextSize = 8, TextColor3 = H.Palette.TextMuted, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, ZIndex = 5 })
    H.I("KeyPill", "TextLabel", H.G.Header, { Size = UDim2.fromOffset(78, 20), Position = UDim2.new(1, -198, 0, 14), BackgroundColor3 = H.Palette.Container, Text = "KEY TEST", Font = H.Fonts.Code, TextSize = 8, TextColor3 = H.Palette.Success, BorderSizePixel = 0, ZIndex = 5 })
    H.I("KeyPillCorner", "UICorner", H.G.KeyPill, { CornerRadius = UDim.new(0, 7) })
    H.I("StatusPill", "TextLabel", H.G.Header, { Size = UDim2.fromOffset(90, 20), Position = UDim2.new(1, -114, 0, 14), BackgroundColor3 = H.Palette.Container, Text = "READY", Font = H.Fonts.Code, TextSize = 8, TextColor3 = H.Palette.AccentGlow, BorderSizePixel = 0, ZIndex = 5 })
    H.I("StatusPillCorner", "UICorner", H.G.StatusPill, { CornerRadius = UDim.new(0, 7) })
    H.I("CloseButton", "TextButton", H.G.Header, { Size = H.IsTouchDevice and UDim2.fromOffset(40, 40) or UDim2.fromOffset(34, 34), Position = H.IsTouchDevice and UDim2.new(1, -48, 0, 8) or UDim2.new(1, -44, 0, 11), BackgroundColor3 = Color3.fromRGB(48, 29, 40), Text = "X", Font = H.Fonts.Header, TextSize = 16, TextColor3 = Color3.fromRGB(255, 214, 222), BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 6 })
    H.I("CloseButtonCorner", "UICorner", H.G.CloseButton, { CornerRadius = UDim.new(0, 10) })
    H.I("CloseStroke", "UIStroke", H.G.CloseButton, { Color = Color3.fromRGB(114, 52, 78), Thickness = 1 })
    H.G.CloseButton.Activated:Connect(function() H.SetMenuVisible(false); H.UpdateStatus(); H.Notify("INTERFACE", "Menu Hidden", false) end)
    H.G.Header.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then H.St.Dragging = true; H.St.DragStart = input.Position; H.St.StartPos = H.G.Main.Position input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then H.St.Dragging = false end end) end end)
    H.G.Header.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then H.St.DragInput = input end end)
    H.UserInputService.InputChanged:Connect(function(input) if input == H.St.DragInput and H.St.Dragging then local delta = input.Position - H.St.DragStart H.G.Main.Position = UDim2.new(H.St.StartPos.X.Scale, H.St.StartPos.X.Offset + delta.X, H.St.StartPos.Y.Scale, H.St.StartPos.Y.Offset + delta.Y) end end)
    H.I("TabBar", "Frame", H.G.Main, { Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 68), BackgroundTransparency = 1, ZIndex = 3 })
    H.I("TabLayout", "UIListLayout", H.G.TabBar, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    H.I("ContentArea", "Frame", H.G.Main, { Position = UDim2.fromOffset(12, 112), Size = UDim2.new(1, -24, 1, -142), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2 })
    H.I("Footer", "TextLabel", H.G.Main, { Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 1, -26), BackgroundTransparency = 1, Text = "E Aim • V ESP • T Trigger • RightShift Menu", Font = H.Fonts.Code, TextSize = 9, TextColor3 = H.Palette.TextMuted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Visible = H.S.ShowKeybindHints })
    H.UpdateFooter()
end

-- BUILD MOBILE
function H.BuildMobile()
    H.I("MobileGui", "ScreenGui", H.PlayerGui, { Name = "DragonMobileUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 110, ZIndexBehavior = Enum.ZIndexBehavior.Global })
    H.I("MobileToggleBtn", "TextButton", H.G.MobileGui, { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0, 16, 0.42, 0), BackgroundColor3 = H.Palette.Header, Text = "DR", TextSize = 18, Font = H.Fonts.Header, TextColor3 = H.Palette.AccentGlow, BorderSizePixel = 0, AutoButtonColor = false, Visible = H.S.MobileToggleVisible and H.IsTouchDevice, ZIndex = 20 })
    H.I("MobileToggleCorner", "UICorner", H.G.MobileToggleBtn, { CornerRadius = UDim.new(1, 0) })
    H.I("MobileToggleStroke", "UIStroke", H.G.MobileToggleBtn, { Color = H.Palette.Accent, Thickness = 1.6 })
    H.G.MobileToggleBtn.Activated:Connect(function() if not H.St.menuVisible then H.SetMenuVisible(true); H.UpdateStatus(); H.Notify("INTERFACE", "Menu Opened", true) end end)
    H.I("MobileCloseBtn", "TextButton", H.G.MobileGui, { Name = "MobileClose", Size = UDim2.fromOffset(62, 42), Position = UDim2.new(1, -76, 1, -60), AnchorPoint = Vector2.new(0, 0), BackgroundColor3 = H.Palette.Header, Text = "CLOSE", TextSize = 10, Font = H.Fonts.Header, TextColor3 = H.Palette.TextLight, BorderSizePixel = 0, AutoButtonColor = false, Visible = false, ZIndex = 25 })
    H.I("MobileCloseCorner", "UICorner", H.G.MobileCloseBtn, { CornerRadius = UDim.new(0, 11) })
    H.I("MobileCloseStroke", "UIStroke", H.G.MobileCloseBtn, { Color = H.Palette.Accent, Thickness = 1 })
    H.G.MobileCloseBtn.Activated:Connect(function() H.SetMenuVisible(false); H.UpdateStatus() end)
    H.I("MobileAimBtn", "TextButton", H.G.MobileGui, { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.84, -32, 0.72, 0), BackgroundColor3 = H.Palette.Header, Text = "AIM", Font = H.Fonts.Header, TextSize = 12, TextColor3 = H.Palette.AccentGlow, BorderSizePixel = 0, Visible = H.S.MobileAimButton and H.IsTouchDevice, AutoButtonColor = false, ZIndex = 20 })
    H.I("MobileAimCorner", "UICorner", H.G.MobileAimBtn, { CornerRadius = UDim.new(1, 0) })
    H.I("MobileAimStroke", "UIStroke", H.G.MobileAimBtn, { Color = H.Palette.Accent, Thickness = 1.6 })
    H.G.MobileAimBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then H.St.MobileAimActive = true; H.G.MobileAimStroke.Color = H.Palette.SecondaryAccent end end)
    H.G.MobileAimBtn.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then H.St.MobileAimActive = false; H.G.MobileAimStroke.Color = H.Palette.Accent end end)
end

-- POPULATE TABS
function H.PopulateCombat(combatTab)
    local aimCard = H.CreateCard(combatTab, "Aim Assist", "Main combat options")
    H.AddToggle(aimCard, "Aimbot", "Aimbot", function() H.UpdateStatus() end)
    H.AddToggle(aimCard, "Silent Aim", "SilentAim")
    H.AddToggle(aimCard, "Triggerbot", "Triggerbot")
    H.AddToggle(aimCard, "Visible Only", "VisibleOnly")
    H.AddSlider(aimCard, "FOV", 30, 300, "AimFOV")
    H.AddSlider(aimCard, "Smoothness", 1, 40, "AimSmoothness")
    H.AddSlider(aimCard, "Max Distance", 100, 3000, "MaxDistance")
    local precisionCard = H.CreateCard(combatTab, "Precision", "Improved automatic aim behavior")
    H.AddToggle(precisionCard, "Prediction", "Prediction")
    H.AddToggle(precisionCard, "Sticky Target", "TargetSticky")
    H.AddSlider(precisionCard, "Responsiveness %", 50, 300, "AimResponsiveness")
    H.AddSlider(precisionCard, "Max Angle", 5, 60, "AimMaxAngle")
    H.AddCycle(precisionCard, "Aim Part", "AimPart", { "Auto", "Head", "Torso" }, function() H.InvalidateTargetCache() end)
    H.AddCycle(precisionCard, "Target Priority", "TargetPriority", { "Crosshair", "Distance" }, function() H.InvalidateTargetCache() end)
end

function H.PopulateVisuals(visualTab)
    local espCard = H.CreateCard(visualTab, "Player ESP", "Clean overlay with improved controls")
    H.AddToggle(espCard, "ESP Enabled", "ESPEnabled")
    H.AddToggle(espCard, "Players", "Players")
    H.AddToggle(espCard, "NPCs", "NPCs")
    H.AddToggle(espCard, "Boxes", "Boxes")
    H.AddToggle(espCard, "Corner Boxes", "CornerBoxes")
    H.AddToggle(espCard, "Box Fill", "BoxFill")
    H.AddToggle(espCard, "Player Info", "PlayerInfo", function(enabled) H.S.Names = enabled; H.S.Health = enabled; H.S.HealthText = enabled; H.S.Distance = enabled end)
    H.AddToggle(espCard, "Head Dot", "HeadDot")
    H.AddToggle(espCard, "Tracers", "Tracers")
    H.AddToggle(espCard, "Offscreen Arrows", "OffscreenArrows")
    H.AddToggle(espCard, "Rainbow Theme", "Rainbow")
    H.AddSlider(espCard, "Max ESP Objects", 4, 64, "MaxESPObjects")
    local chestCard = H.CreateCard(visualTab, "Chest ESP", "Loot highlights")
    H.AddToggle(chestCard, "Chest ESP", "ChestESP", function() H.RefreshChestESP() end)
    H.AddCycle(chestCard, "Chest Filter", "ChestFilter", { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" }, function() H.RefreshChestESP() end)
    H.AddSlider(chestCard, "Chest Max Distance", 200, 5000, "ChestMaxDistance")
    H.AddSlider(chestCard, "Chest Fill Transparency %", 0, 95, "ChestFillTransparency", function(value) for _, data in pairs(H.St.ChestObjects) do if data.Highlight then data.Highlight.FillTransparency = math.clamp(value / 100, 0, 1) end end end)
    H.AddButton(chestCard, "RESCAN CHESTS", function() H.RefreshChestESP(); H.Notify("VISUALS", "Chest ESP rescanned", true) end)
    local overlayCard = H.CreateCard(visualTab, "Overlay", "HUD and visual helpers")
    H.AddToggle(overlayCard, "FOV Ring", "ShowFOV")
    H.AddToggle(overlayCard, "Target HUD", "TargetHUD")
    H.AddToggle(overlayCard, "Watermark", "Watermark")
    H.AddToggle(overlayCard, "Crosshair", "Crosshair")
    H.AddToggle(overlayCard, "Notifications", "NotificationsEnabled")
    H.AddToggle(overlayCard, "Keybind Hints", "ShowKeybindHints", function(enabled) if H.G.Footer then H.G.Footer.Visible = enabled end end)
end

function H.PopulateSystem(systemTab)
    local stealthCard = H.CreateCard(systemTab, "Stealth", "Hides your name card and kill feed entries")
    H.AddToggle(stealthCard, "Hide User (UI)", "HideUser", function(enabled) H.SetHideUser(enabled) end)
    H.AddInfo(stealthCard, "Hides GUI elements that show your username. Client-side only.")
    local utilityCard = H.CreateCard(systemTab, "Utility", "Anti-AFK and misc")
    H.AddToggle(utilityCard, "Anti-AFK", "AntiAFK", function(enabled)
        if enabled then H.InitAntiAFK() else if H.St.AntiAFKLoop then task.cancel(H.St.AntiAFKLoop); H.St.AntiAFKLoop = nil end end
    end)
    local performanceCard = H.CreateCard(systemTab, "Performance", "Optimization profiles")
    H.AddCycle(performanceCard, "Profile", "PerformanceProfile", { "Low", "Balanced", "High" }, function(profile) H.ApplyPerformanceProfile(profile); H.InvalidateTargetCache(); H.Notify("PERFORMANCE", profile .. " profile applied", true) end)
    H.AddToggle(performanceCard, "Adaptive Performance", "AdaptivePerformance")
    H.AddInfo(performanceCard, "Low is recommended for mobile / weaker devices.")
    local mobileCard = H.CreateCard(systemTab, "Mobile", "Touch options")
    if H.IsTouchDevice then
        H.AddToggle(mobileCard, "Floating Button", "MobileToggleVisible", function(val) if H.G.MobileToggleBtn then H.G.MobileToggleBtn.Visible = val and not H.St.menuVisible end end)
        H.AddToggle(mobileCard, "Touch Aim Button", "MobileAimButton", function(val) if H.G.MobileAimBtn then H.G.MobileAimBtn.Visible = val end end)
    else H.AddInfo(mobileCard, "Mobile options are automatic on desktop.") end
    local configCard = H.CreateCard(systemTab, "Config", "Save and restore your setup")
    H.AddButton(configCard, "SAVE CONFIG", H.SaveConfig)
    H.AddButton(configCard, "LOAD CONFIG", H.LoadConfig)
    H.AddButton(configCard, "RESET CONFIG", H.ResetConfig)
    H.I("ConfigStatus", "TextLabel", configCard, { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "CONFIG • READY", Font = H.Fonts.Code, TextSize = 8, TextColor3 = H.Palette.TextDim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
    local keybindCard = H.CreateCard(systemTab, "Keybinds", "Default: E, V, T, RightShift")
    H.AddKeybind(keybindCard, "Aimbot Toggle", "AimbotKey", H.UpdateFooter)
    H.AddKeybind(keybindCard, "ESP Toggle", "ESPKey", H.UpdateFooter)
    H.AddKeybind(keybindCard, "Triggerbot Toggle", "TriggerKey", H.UpdateFooter)
    H.AddKeybind(keybindCard, "Menu Toggle", "MenuKey", H.UpdateFooter)
end

function H.PopulateKeySystem(systemTab)
    local keyCard = H.CreateCard(systemTab, "Key System", "Test Work.ink keys")
    local cacheLabel = H.AddInfo(keyCard, H.K.getCacheStatus())
    local keyStatus = H.AddInfo(keyCard, "Status: Waiting for input...")
    local keyBox = H.AddTextBox(keyCard, "Key", "Enter Work.ink key...", "")
    local verifyingMenuKey = false
    local function verifyFromBox()
        if verifyingMenuKey then return end
        verifyingMenuKey = true
        keyStatus.Text = "Status: Verifying..."
        keyStatus.TextColor3 = H.Palette.TextMuted
        task.spawn(function()
            local ok, message = H.K.verifyToken(keyBox.Text, true)
            keyStatus.Text = "Status: " .. message
            keyStatus.TextColor3 = ok and H.Palette.Success or Color3.fromRGB(239, 100, 110)
            cacheLabel.Text = H.K.getCacheStatus()
            H.UpdateKeyPill(ok or H.K.isCachedValid())
            H.Notify("KEY SYSTEM", message, ok)
            verifyingMenuKey = false
        end)
    end
    H.AddButton(keyCard, "GET KEY", function() local copied = H.K.copyLink() keyStatus.Text = copied and "Status: Work.ink link copied!" or ("Status: " .. H.K.WORKINK_LINK) keyStatus.TextColor3 = H.Palette.AccentGlow end)
    H.AddButton(keyCard, "VERIFY KEY", verifyFromBox)
    H.AddButton(keyCard, "CLEAR KEY CACHE", function() H.K.clearCache(); cacheLabel.Text = H.K.getCacheStatus(); keyStatus.Text = "Status: Key cache cleared."; keyStatus.TextColor3 = H.Palette.TextMuted; H.UpdateKeyPill(H.K.isCachedValid()); H.Notify("KEY SYSTEM", "Key cache cleared", true) end)
    keyBox.FocusLost:Connect(function(enterPressed) if enterPressed then verifyFromBox() end end)
end

function H.PopulateTabs()
    local combatTab = H.CreateTab("COMBAT", 1)
    local visualTab = H.CreateTab("VISUALS", 2)
    local systemTab = H.CreateTab("SYSTEM", 3)
    H.SelectTab("COMBAT")
    H.PopulateCombat(combatTab)
    H.PopulateVisuals(visualTab)
    H.PopulateKeySystem(systemTab)
    H.PopulateSystem(systemTab)
end

-- GLOBAL INPUT
function H.InitInput()
    local function setSetting(key, value) H.S[key] = value if H.UIRefreshers[key] then pcall(H.UIRefreshers[key], value) end end
    H.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if H.St.listeningForKey and input.UserInputType == Enum.UserInputType.Keyboard then
            if H.UserInputService:GetFocusedTextBox() then return end
            if input.KeyCode == Enum.KeyCode.Escape then if H.St.listeningForKey.Refresh then H.St.listeningForKey.Refresh(H.S[H.St.listeningForKey.Setting]) end H.Notify("KEYBIND", "Keybind cancelled", false) else local key = input.KeyCode if key ~= Enum.KeyCode.Unknown then H.S[H.St.listeningForKey.Setting] = key if H.St.listeningForKey.Refresh then H.St.listeningForKey.Refresh(key) elseif H.St.listeningForKey.Button then H.St.listeningForKey.Button.Text = key.Name end if H.St.listeningForKey.Callback then pcall(H.St.listeningForKey.Callback, key) end H.Notify("KEYBIND", H.St.listeningForKey.Setting .. " -> " .. key.Name, true); H.UpdateFooter() end end
            H.St.listeningForKey = nil
            return
        end
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == H.S.MenuKey then H.SetMenuVisible(not H.St.menuVisible); H.UpdateStatus(); H.Notify("INTERFACE", H.St.menuVisible and "Menu Opened" or "Menu Hidden", H.St.menuVisible)
            elseif input.KeyCode == Enum.KeyCode.Escape and H.St.menuVisible then H.SetMenuVisible(false); H.UpdateStatus(); H.Notify("INTERFACE", "Menu Hidden", false)
            elseif input.KeyCode == H.S.AimbotKey then setSetting("Aimbot", not H.S.Aimbot); H.UpdateStatus(); H.Notify("COMBAT", "Aimbot: " .. (H.S.Aimbot and "ENABLED" or "DISABLED"), H.S.Aimbot)
            elseif input.KeyCode == H.S.ESPKey then setSetting("ESPEnabled", not H.S.ESPEnabled); H.Notify("VISUALS", "ESP: " .. (H.S.ESPEnabled and "ENABLED" or "DISABLED"), H.S.ESPEnabled)
            elseif input.KeyCode == H.S.TriggerKey then setSetting("Triggerbot", not H.S.Triggerbot); H.Notify("COMBAT", "Triggerbot: " .. (H.S.Triggerbot and "ENABLED" or "DISABLED"), H.S.Triggerbot) end
        end
    end)
end

-- START
function H.Start()
    H.UpdateKeyPill(H.K.isCachedValid())
    H.UpdateFooter()
    H.UpdateStatus()
    H.SetMenuVisible(false)
    task.defer(function()
        H.LoadConfig()
        H.ApplyBestDefaults()
        H.UpdateStatus()
        H.UpdateFooter()
    end)
    H.Notify("DRAGON HUB 3.1", "Ready • Phantom build loaded", true, 3.0)
end

-- RUN
function H.Run()
    H.InitServices()
    if not H.LocalPlayer then return end
    if not H.RunKeyGate() then return end
    H.Cleanup()
    H.InitSettings()
    H.ApplyBestDefaults()
    H.DefaultSettings = {}
    for k, v in pairs(H.S) do H.DefaultSettings[k] = v end
    H.InitState()
    H.InitBaseGuis()
    H.InitNotify()
    H.InitAimbot()
    H.InitChestESP()
    H.InitESP()
    H.BuildUI()
    H.BuildMobile()
    H.PopulateTabs()
    H.InitInput()
    H.Start()
end
H.Run()
