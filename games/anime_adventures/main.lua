--!strict
--[[
    ============================================================================
    [PREMIUM ROBLOX QA AUTOMATION & NPC CONTROLLER - ANIME ADVENTURES PRO V2]
    Target Game: [☀️อัพเดท 21🏖️] การผจญภัยอนิเมะ (Anime Adventures)
    Place ID: 8304191830 | Creator: Gomu
    Repository: markrunerppl-boop/kuykuyza123
    Loader: loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/script.lua"))()

    Implemented Features:
    [✓] 1. Dynamic Banner Summon: สุ่มกาชาแบบเลือกแบนเนอร์ได้ (EventClover, Summer2026, Legacy, Special, etc.)
    [✓] 2. Auto Claim All Rewards: รับรางวัลทุกอย่างอัตโนมัติเมื่อพร้อม (Daily, BattlePass, Level, Missions, Clear)
    [✓] 3. Auto Equip Best Units: สวมใส่ตัวที่ดีที่สุดอัตโนมัติเมื่อได้ตัวใหม่หรือสั่งการ
    [✓] 4. Auto Stage & Matchmaking Loop: เข้าห้อง Story / Infinite อัตโนมัติ, กดเริ่ม, สคิปเวฟ, และวนลูป Replay
    [✓] 5. Auto Place Units at Enemy Gate: วางยูนิตหน้าประตูทางออกมอนสเตอร์อัตโนมัติในเกม
    [✓] 6. Auto Upgrade Placed Units: ตรวจจับยูนิตที่วางแล้วและอัปเกรดอัตโนมัติเมื่อเงินในเกมพร้อม
    [✓] 7. Strict Readiness Check: ตรวจสอบความพร้อม, คูลดาวน์, และทรัพยากรก่อนเริ่มทุกคำสั่ง
    [✓] 8. Tabbed Interactive UI with Draggable Frame & Real-Time Console Logging
    ============================================================================
--]]

-- Clean previous UI instance if exists
local targetParent = nil
if pcall(function() return gethui() end) and gethui() then
    targetParent = gethui()
elseif pcall(function() return game:GetService("CoreGui") end) then
    targetParent = game:GetService("CoreGui")
else
    targetParent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local existing = targetParent:FindFirstChild("QAAutomationHub")
if existing then existing:Destroy() end

-- ==============================================================================
-- SERVICES & CONSTANTS
-- ==============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==============================================================================
-- 1. CENTRALIZED STRING CONSTANTS & CONFIGURATION
-- ==============================================================================
local Config = {
    Events = {
        -- Summon & Shop
        SummonRemote             = "buy_from_banner",
        
        -- Inventory & Team
        EquipBestRemote          = "equip_best",
        EquipUnitRemote          = "equip_unit",
        UnequipAllRemote         = "unequip_all",
        
        -- Rewards & Claims
        ClaimDailyRemote         = "claim_daily_reward",
        ClaimBattlePassRemote    = "claim_battlepass_rewards",
        ClaimLevelRewardRemote   = "claim_player_level_rewards",
        ClaimDailyMissionRemote  = "request_claim_dailymission",
        ClaimFirstClearRemote    = "claim_first_clear_rewards",
        ClaimSummerBoardRemote   = "claim_summer2_map_board_lines",
        
        -- In-Game Match & Stages
        JoinLobbyRemote          = "request_join_lobby",
        StartGameRemote          = "request_start_game",
        VoteWaveSkipRemote       = "vote_wave_skip",
        VoteStartRemote          = "vote_start",
        GameFinishedVoteRemote   = "set_game_finished_vote",
        TeleportBackRemote       = "teleport_back_to_lobby",
        
        -- In-Game Unit Actions
        SpawnUnitRemote          = "spawn_unit",
        UpgradeUnitRemote        = "upgrade_unit_ingame",
        SellUnitRemote           = "sell_unit_ingame",
    },

    UI = {
        MainHUD          = "BannerUI",
        SummonGUI        = "SummonGUI",
        SpawnUnitsGUI    = "spawn_units",
        UnitUpgradeGUI   = "UnitUpgrade2",
    },

    Automation = {
        -- Feature 1: Summon
        AutoSummon         = false,
        SelectedBanner     = "Summer2026",
        SummonMode         = "gems10",   -- "gems" (1x) or "gems10" (10x)
        MinGemsToKeep      = 100,

        -- Feature 2: Claim Rewards
        AutoClaimRewards   = true,
        ClaimInterval      = 30.0,

        -- Feature 3: Equip Best
        AutoEquipBest      = true,
        EquipInterval      = 20.0,

        -- Feature 4: Stage & Loop
        AutoPlayStage      = false,
        StageMode          = "Story",    -- "Story" or "Infinite"
        AutoReplayLoop     = true,
        AutoWaveSkip       = true,

        -- Feature 5 & 6: In-Game Combat
        AutoPlaceUnits     = true,
        AutoUpgradeUnits   = true,
        MaxUnitsToPlace    = 6,
        PlaceDistance      = 14.0,       -- ระยะห่างจากจุดเกิดมอนสเตอร์
    },

    CircuitBreaker = {
        MaxConsecutiveErrors = 3,
        CooldownTime         = 10.0,
    },

    Simulation = {
        MinActionDelay       = 0.35,
        MaxActionDelay       = 0.65,
    }
}

-- ==============================================================================
-- 2. CREATE SCREEN GUI (MODERN TABBED DASHBOARD)
-- ==============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "QAAutomationHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 580, 0, 480)
MainFrame.Position = UDim2.new(0.5, -290, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(17, 19, 25)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 58, 80)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Top Bar (Draggable)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 10)
TopBarCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(1, -90, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ QA Automation & Controller Pro | Anime Adventures"
TitleLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(44, 48, 62)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(220, 225, 235)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.AutoButtonColor = true
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Dragging Behavior
do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Status Bar
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Size = UDim2.new(1, -24, 0, 32)
StatusBar.Position = UDim2.new(0, 12, 0, 48)
StatusBar.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
StatusBar.BorderSizePixel = 0
StatusBar.Parent = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusBar

local StatePill = Instance.new("TextLabel")
StatePill.Name = "StatePill"
StatePill.Size = UDim2.new(0, 115, 0, 22)
StatePill.Position = UDim2.new(0, 5, 0, 5)
StatePill.BackgroundColor3 = Color3.fromRGB(35, 120, 65)
StatePill.Text = "● STATE: IDLE"
StatePill.TextColor3 = Color3.fromRGB(255, 255, 255)
StatePill.Font = Enum.Font.GothamBold
StatePill.TextSize = 10
StatePill.Parent = StatusBar

local StateCorner = Instance.new("UICorner")
StateCorner.CornerRadius = UDim.new(0, 4)
StateCorner.Parent = StatePill

local BreakerLabel = Instance.new("TextLabel")
BreakerLabel.Name = "BreakerLabel"
BreakerLabel.Size = UDim2.new(0, 140, 1, 0)
BreakerLabel.Position = UDim2.new(0, 128, 0, 0)
BreakerLabel.BackgroundTransparency = 1
BreakerLabel.Text = "Circuit: 0/3 (Normal)"
BreakerLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
BreakerLabel.Font = Enum.Font.GothamMedium
BreakerLabel.TextSize = 11
BreakerLabel.TextXAlignment = Enum.TextXAlignment.Left
BreakerLabel.Parent = StatusBar

local CurrencyLabel = Instance.new("TextLabel")
CurrencyLabel.Name = "CurrencyLabel"
CurrencyLabel.Size = UDim2.new(0, 220, 1, 0)
CurrencyLabel.Position = UDim2.new(1, -225, 0, 0)
CurrencyLabel.BackgroundTransparency = 1
CurrencyLabel.Text = "Gems: -- | Gold: --"
CurrencyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
CurrencyLabel.Font = Enum.Font.GothamMedium
CurrencyLabel.TextSize = 11
CurrencyLabel.TextXAlignment = Enum.TextXAlignment.Right
CurrencyLabel.Parent = StatusBar

-- Tab Buttons Bar
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -24, 0, 32)
TabBar.Position = UDim2.new(0, 12, 0, 86)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 6)
TabLayout.Parent = TabBar

local PagesContainer = Instance.new("Frame")
PagesContainer.Name = "PagesContainer"
PagesContainer.Size = UDim2.new(1, -24, 0, 195)
PagesContainer.Position = UDim2.new(0, 12, 0, 124)
PagesContainer.BackgroundColor3 = Color3.fromRGB(20, 23, 31)
PagesContainer.BorderSizePixel = 0
PagesContainer.Parent = MainFrame

local PagesCorner = Instance.new("UICorner")
PagesCorner.CornerRadius = UDim.new(0, 6)
PagesCorner.Parent = PagesContainer

local TabPages = {}
local TabButtons = {}

local function CreateTab(name: string, titleText: string)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = name .. "TabBtn"
    tabBtn.Size = UDim2.new(0, 105, 1, 0)
    tabBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
    tabBtn.Text = titleText
    tabBtn.TextColor3 = Color3.fromRGB(180, 185, 205)
    tabBtn.Font = Enum.Font.GothamMedium
    tabBtn.TextSize = 11
    tabBtn.Parent = TabBar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = tabBtn

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Color3.fromRGB(60, 65, 85)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = PagesContainer

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Padding = UDim.new(0, 8)
    pageLayout.Parent = page

    local pagePadding = Instance.new("UIPadding")
    pagePadding.PaddingTop = UDim.new(0, 8)
    pagePadding.PaddingBottom = UDim.new(0, 8)
    pagePadding.PaddingLeft = UDim.new(0, 10)
    pagePadding.PaddingRight = UDim.new(0, 10)
    pagePadding.Parent = page

    TabPages[name] = page
    TabButtons[name] = tabBtn

    tabBtn.MouseButton1Click:Connect(function()
        for k, p in pairs(TabPages) do
            p.Visible = (k == name)
            if TabButtons[k] then
                if k == name then
                    TabButtons[k].BackgroundColor3 = Color3.fromRGB(45, 75, 140)
                    TabButtons[k].TextColor3 = Color3.fromRGB(255, 255, 255)
                else
                    TabButtons[k].BackgroundColor3 = Color3.fromRGB(30, 34, 46)
                    TabButtons[k].TextColor3 = Color3.fromRGB(180, 185, 205)
                end
            end
        end
    end)

    return page
end

local StagesPage = CreateTab("Stages", "⚔️ ฟาร์ม & ด่าน")
local CombatPage = CreateTab("Combat", "🛡️ วาง & อัปเกรด")
local SummonPage = CreateTab("Summon", "🎲 สุ่มตัวละคร")
local RewardPage = CreateTab("Reward", "🎁 รับรางวัล")
local LogsPage   = CreateTab("Logs", "📊 ประวัติ Log")

-- Default to first tab
TabButtons["Stages"].BackgroundColor3 = Color3.fromRGB(45, 75, 140)
TabButtons["Stages"].TextColor3 = Color3.fromRGB(255, 255, 255)
TabPages["Stages"].Visible = true

-- UI Component Helpers
local function AddToggle(parent: Instance, labelText: string, defaultVal: boolean, onToggle: (boolean) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(25, 29, 40)
    row.BorderSizePixel = 0
    row.Parent = parent

    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0, 6)
    rCorner.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(230, 235, 245)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 52, 0, 22)
    btn.Position = UDim2.new(1, -60, 0, 6)
    btn.BackgroundColor3 = defaultVal and Color3.fromRGB(0, 160, 90) or Color3.fromRGB(60, 65, 80)
    btn.Text = defaultVal and "เปิด" or "ปิด"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 4)
    bCorner.Parent = btn

    local state = defaultVal
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 160, 90) or Color3.fromRGB(60, 65, 80)
        btn.Text = state and "เปิด" or "ปิด"
        pcall(onToggle, state)
    end)
    return row
end

local function AddButton(parent: Instance, labelText: string, color: Color3, onClick: () -> ())
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = color
    btn.Text = labelText
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = parent

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        task.spawn(onClick)
    end)
    return btn
end

-- Bottom Live Console Frame (Visible always)
local BottomLogFrame = Instance.new("Frame")
BottomLogFrame.Name = "BottomLogFrame"
BottomLogFrame.Size = UDim2.new(1, -24, 0, 140)
BottomLogFrame.Position = UDim2.new(0, 12, 0, 326)
BottomLogFrame.BackgroundColor3 = Color3.fromRGB(13, 15, 20)
BottomLogFrame.BorderSizePixel = 0
BottomLogFrame.Parent = MainFrame

local BottomLogCorner = Instance.new("UICorner")
BottomLogCorner.CornerRadius = UDim.new(0, 6)
BottomLogCorner.Parent = BottomLogFrame

local BottomLogStroke = Instance.new("UIStroke")
BottomLogStroke.Color = Color3.fromRGB(35, 40, 55)
BottomLogStroke.Thickness = 1
BottomLogStroke.Parent = BottomLogFrame

local ConsoleHeader = Instance.new("TextLabel")
ConsoleHeader.Name = "ConsoleHeader"
ConsoleHeader.Size = UDim2.new(1, -12, 0, 20)
ConsoleHeader.Position = UDim2.new(0, 8, 0, 2)
ConsoleHeader.BackgroundTransparency = 1
ConsoleHeader.Text = "LIVE CONSOLE LOG (AUDIT & FSM TRACE):"
ConsoleHeader.TextColor3 = Color3.fromRGB(135, 140, 160)
ConsoleHeader.Font = Enum.Font.GothamBold
ConsoleHeader.TextSize = 9
ConsoleHeader.TextXAlignment = Enum.TextXAlignment.Left
ConsoleHeader.Parent = BottomLogFrame

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Name = "LogScroll"
LogScroll.Size = UDim2.new(1, -16, 0, 110)
LogScroll.Position = UDim2.new(0, 8, 0, 24)
LogScroll.BackgroundTransparency = 1
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 4
LogScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 65, 85)
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScroll.Parent = BottomLogFrame

local LogLayout = Instance.new("UIListLayout")
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Padding = UDim.new(0, 2)
LogLayout.Parent = LogScroll

-- ==============================================================================
-- 3. STRUCTURED LOGGER
-- ==============================================================================
local Logger = {}
do
    local logCounter = 0

    function Logger:Log(subsystem: string, level: "INFO" | "WARN" | "ERROR", msg: string)
        logCounter += 1
        local dt = DateTime.now():ToLocalTime()
        local timeStr = string.format("%02d:%02d:%02d", dt.Hour, dt.Minute, dt.Second)
        local formatted = string.format("[%s] [%s] [%s] %s", timeStr, subsystem, level, msg)

        if level == "ERROR" then
            warn(formatted)
        elseif level == "WARN" then
            warn(formatted)
        else
            print(formatted)
        end

        task.spawn(function()
            local line = Instance.new("TextLabel")
            line.Name = "Entry_" .. logCounter
            line.Size = UDim2.new(1, 0, 0, 16)
            line.BackgroundTransparency = 1
            line.Font = Enum.Font.Code
            line.TextSize = 10
            line.TextXAlignment = Enum.TextXAlignment.Left
            line.LayoutOrder = logCounter
            line.TextWrapped = true

            if level == "ERROR" then
                line.TextColor3 = Color3.fromRGB(255, 90, 90)
            elseif level == "WARN" then
                line.TextColor3 = Color3.fromRGB(255, 205, 75)
            else
                line.TextColor3 = Color3.fromRGB(150, 225, 175)
            end

            line.Text = formatted
            line.Parent = LogScroll
            
            task.wait()
            LogScroll.CanvasPosition = Vector2.new(0, 999999)
        end)
    end
end

-- ==============================================================================
-- 4. SAFE MODULE LOADING (Requirement 1)
-- ==============================================================================
local ExternalData = nil
do
    local function TryLoad()
        local src = ReplicatedStorage:FindFirstChild("src")
        local module = src and src:FindFirstChild("GameData")
        if not module or not module:IsA("ModuleScript") then
            return nil, "GameData ModuleScript not found in ReplicatedStorage.src"
        end
        return require(module)
    end

    local success, result = pcall(TryLoad)
    if success and result then
        ExternalData = result
        Logger:Log("ModuleLoader", "INFO", "External GameData loaded successfully.")
    else
        Logger:Log("ModuleLoader", "WARN", "Safe Fallback: Using default mock configuration.")
        ExternalData = {
            DefaultBanner = "Summer2026",
            MaxSlots = 6
        }
    end
end

-- ==============================================================================
-- 5. FSM (FINITE STATE MACHINE) & CIRCUIT BREAKER
-- ==============================================================================
local BotState = {
    Current = "Idle",
    IDLE = "Idle",
    MOVING = "Moving",
    TESTING = "Testing",
    IN_MATCH = "InMatch",
    CIRCUIT_BROKEN = "CircuitBroken",
}

function BotState:SetState(newState: string)
    if self.Current ~= newState then
        self.Current = newState
        Logger:Log("StateMgr", "INFO", "State transition: " .. newState)
        
        if newState == BotState.IDLE then
            StatePill.BackgroundColor3 = Color3.fromRGB(35, 120, 65)
            StatePill.Text = "● STATE: IDLE"
        elseif newState == BotState.CIRCUIT_BROKEN then
            StatePill.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
            StatePill.Text = "● STATE: BROKEN"
        elseif newState == BotState.IN_MATCH then
            StatePill.BackgroundColor3 = Color3.fromRGB(130, 40, 160)
            StatePill.Text = "● STATE: IN MATCH"
        else
            StatePill.BackgroundColor3 = Color3.fromRGB(30, 95, 190)
            StatePill.Text = "● STATE: " .. string.upper(newState)
        end
    end
end

function BotState:GetState(): string
    return self.Current
end

local CircuitBreaker = {
    consecutiveErrors = 0,
    lastBreakTime = 0,
}

function CircuitBreaker:RecordSuccess()
    if self.consecutiveErrors > 0 then
        Logger:Log("CircuitBreaker", "INFO", "Recovered from errors. Resetting strike count.")
    end
    self.consecutiveErrors = 0
    BreakerLabel.Text = "Circuit: 0/3 (Normal)"
    BreakerLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
end

function CircuitBreaker:RecordFailure(err: string)
    self.consecutiveErrors += 1
    BreakerLabel.Text = string.format("Circuit: %d/3 (Alert)", self.consecutiveErrors)
    BreakerLabel.TextColor3 = Color3.fromRGB(255, 140, 70)
    Logger:Log("CircuitBreaker", "WARN", string.format("Task failure (%d/%d): %s", 
        self.consecutiveErrors, Config.CircuitBreaker.MaxConsecutiveErrors, tostring(err)))
    
    if self.consecutiveErrors >= Config.CircuitBreaker.MaxConsecutiveErrors then
        self:Trip()
    end
end

function CircuitBreaker:Trip()
    BreakerLabel.Text = "Circuit: TRIPPED (Halted)"
    BreakerLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
    Logger:Log("CircuitBreaker", "ERROR", "Trip limit reached! Pausing workers.")
    BotState:SetState(BotState.CIRCUIT_BROKEN)
    self.lastBreakTime = os.clock()
end

function CircuitBreaker:CanExecute(): boolean
    if BotState:GetState() == BotState.CIRCUIT_BROKEN then
        if os.clock() - self.lastBreakTime >= Config.CircuitBreaker.CooldownTime then
            Logger:Log("CircuitBreaker", "INFO", "Circuit breaker cooldown finished. Resuming.")
            self.consecutiveErrors = 0
            BotState:SetState(BotState.IDLE)
            BreakerLabel.Text = "Circuit: 0/3 (Normal)"
            BreakerLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
            return true
        end
        return false
    end
    return true
end

-- ==============================================================================
-- 6. NULL-SAFETY HELPERS (Requirement 3)
-- ==============================================================================
local SafeUtils = {}

function SafeUtils.SafeFind(parent: Instance?, childName: string): Instance?
    if not parent then return nil end
    return parent:FindFirstChild(childName)
end

function SafeUtils.SafeGetRemote(remoteName: string): RemoteFunction | RemoteEvent | nil
    local endpoints = ReplicatedStorage:FindFirstChild("endpoints")
    if not endpoints then return nil end
    local c2s = SafeUtils.SafeFind(endpoints, "client_to_server")
    if not c2s then return nil end
    return SafeUtils.SafeFind(c2s, remoteName)
end

function SafeUtils.HumanWait(minD: number?, maxD: number?)
    local minDelay = minD or Config.Simulation.MinActionDelay
    local maxDelay = maxD or Config.Simulation.MaxActionDelay
    local jitter = math.random() * (maxDelay - minDelay)
    local waitTime = minDelay + jitter
    if coroutine.isyieldable() then
        task.wait(waitTime)
    end
end

local function GetPlayerCurrency(): (number, number)
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local gems = 0
    local gold = 0
    if leaderstats then
        local gVal = leaderstats:FindFirstChild("Gems")
        local goldVal = leaderstats:FindFirstChild("Gold")
        if gVal and (gVal:IsA("IntValue") or gVal:IsA("NumberValue")) then gems = gVal.Value end
        if goldVal and (goldVal:IsA("IntValue") or goldVal:IsA("NumberValue")) then gold = goldVal.Value end
    end
    return gems, gold
end

local function UpdateCurrencyDisplay()
    local gems, gold = GetPlayerCurrency()
    CurrencyLabel.Text = string.format("Gems: %s | Gold: %s", tostring(gems), tostring(gold))
end

-- ตรวจสอบว่าขณะนี้อยู่ในเกม (Match) หรืออยู่ใน Lobby
local function IsInMatch(): boolean
    -- ในห้องเกมจริงจะมี Folder _UNITS และไม่มี Story Lobby ประจำการ
    local unitsFolder = workspace:FindFirstChild("_UNITS")
    local lobbies = workspace:FindFirstChild("_LOBBIES")
    if unitsFolder and (not lobbies or #lobbies:GetChildren() == 0) then
        return true
    end
    return false
end

-- ==============================================================================
-- 7. FUNCTION 1: DYNAMIC BANNER SUMMON (เลือกแบนเนอร์ได้)
-- ==============================================================================
local SummonService = {}

function SummonService.GetAvailableBanners(): { string }
    local banners = {}
    local summonGUI = PlayerGui:FindFirstChild("SummonGUI")
    local bf = summonGUI and summonGUI:FindFirstChild("BannerFrames", true)
    if bf then
        for _, child in ipairs(bf:GetChildren()) do
            if child:IsA("GuiObject") and not child.Name:find("UI") then
                table.insert(banners, child.Name)
            end
        end
    end
    if #banners == 0 then
        -- Default Known Banners in Anime Adventures
        banners = { "Summer2026", "EventClover", "Legacy", "Special", "Standard" }
    end
    return banners
end

function SummonService.ExecuteSummon(bannerName: string, mode: "gems" | "gems10"): boolean
    if not CircuitBreaker:CanExecute() then return false end
    
    local gems, _ = GetPlayerCurrency()
    local cost = (mode == "gems10") and 500 or 50
    if gems < cost + Config.Automation.MinGemsToKeep then
        Logger:Log("Summon", "WARN", string.format("ยอด Gems ไม่พอสำหรับการสุ่ม (ต้องการ %d, คงเหลือ %d)", cost, gems))
        return false
    end

    local summonRemote = SafeUtils.SafeGetRemote(Config.Events.SummonRemote)
    if not summonRemote then
        Logger:Log("Summon", "ERROR", "ไม่พบ Remote buy_from_banner ใน endpoints")
        return false
    end

    Logger:Log("Summon", "INFO", string.format("กำลังสุ่มจากแบนเนอร์ [%s] โหมด [%s]...", bannerName, mode))
    SafeUtils.HumanWait()

    local success, res = pcall(function()
        if summonRemote:IsA("RemoteFunction") then
            return summonRemote:InvokeServer(bannerName, mode)
        else
            summonRemote:FireServer(bannerName, mode)
            return true
        end
    end)

    if success then
        Logger:Log("Summon", "INFO", string.format("สุ่มแบนเนอร์ [%s] สำเร็จ!", bannerName))
        UpdateCurrencyDisplay()
        return true
    else
        Logger:Log("Summon", "WARN", "การสุ่มล้มเหลว: " .. tostring(res))
        return false
    end
end

-- ==============================================================================
-- 8. FUNCTION 2: AUTO CLAIM ALL REWARDS (รับรางวัลทุกอย่างเมื่อพร้อม)
-- ==============================================================================
local RewardService = {}

function RewardService.ClaimAll(): number
    if not CircuitBreaker:CanExecute() then return 0 end
    Logger:Log("Rewards", "INFO", "ตรวจสอบและรับรางวัลทุกอย่างที่พร้อมใช้งาน...")
    local claimedCount = 0

    local claimList = {
        { Name = "Daily Reward", Remote = Config.Events.ClaimDailyRemote },
        { Name = "BattlePass", Remote = Config.Events.ClaimBattlePassRemote },
        { Name = "Player Level", Remote = Config.Events.ClaimLevelRewardRemote },
        { Name = "Daily Missions", Remote = Config.Events.ClaimDailyMissionRemote },
        { Name = "First Clear", Remote = Config.Events.ClaimFirstClearRemote },
        { Name = "Summer Board", Remote = Config.Events.ClaimSummerBoardRemote },
    }

    for _, entry in ipairs(claimList) do
        local rem = SafeUtils.SafeGetRemote(entry.Remote)
        if rem then
            local s, err = pcall(function()
                if rem:IsA("RemoteFunction") then
                    return rem:InvokeServer()
                else
                    rem:FireServer()
                    return true
                end
            end)
            if s then
                claimedCount += 1
                Logger:Log("Rewards", "INFO", string.format("กดรับ [%s] สำเร็จ", entry.Name))
            end
            SafeUtils.HumanWait(0.15, 0.3)
        end
    end

    UpdateCurrencyDisplay()
    return claimedCount
end

-- ==============================================================================
-- 9. FUNCTION 3: AUTO EQUIP BEST UNITS (สวมใส่ตัวที่ดีที่สุด)
-- ==============================================================================
local TeamService = {}

function TeamService.EquipBest(): boolean
    if not CircuitBreaker:CanExecute() then return false end
    local equipBestRemote = SafeUtils.SafeGetRemote(Config.Events.EquipBestRemote)
    if not equipBestRemote then
        Logger:Log("Team", "WARN", "ไม่พบ Remote equip_best ใน endpoints")
        return false
    end

    local s, err = pcall(function()
        if equipBestRemote:IsA("RemoteFunction") then
            return equipBestRemote:InvokeServer()
        else
            equipBestRemote:FireServer()
            return true
        end
    end)

    if s then
        Logger:Log("Team", "INFO", "สวมใส่ทีมยูนิตที่ดีที่สุดเรียบร้อย (Equip Best)")
        return true
    else
        Logger:Log("Team", "WARN", "ไม่สามารถสวมใส่ยูนิตได้: " .. tostring(err))
        return false
    end
end

-- ==============================================================================
-- 10. FUNCTION 4: AUTO PLAY STAGES & LOOP (เล่นด่านและเลือกลงวนลูปได้)
-- ==============================================================================
local StageService = {
    _lastJoinAttempt = 0,
}

function StageService.FindAvailableLobby(mode: string): Instance?
    local lobbies = workspace:FindFirstChild("_LOBBIES")
    if not lobbies then return nil end
    local folder = lobbies:FindFirstChild(mode) or lobbies:FindFirstChild("Story")
    if not folder then return nil end

    for _, lob in ipairs(folder:GetChildren()) do
        local active = lob:FindFirstChild("Active")
        local locked = lob:FindFirstChild("Locked")
        local owner = lob:FindFirstChild("Owner")
        local teleporting = lob:FindFirstChild("Teleporting")

        -- ห้องที่ยังไม่เริ่ม และยังไม่มีเจ้าของ หรือเป็นเจ้าของเอง
        local isOwnerEmpty = (owner and owner:IsA("ObjectValue") and owner.Value == nil)
        local isSelfOwner = (owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer)
        local isNotTeleporting = (teleporting and teleporting:IsA("BoolValue") and not teleporting.Value)

        if (isOwnerEmpty or isSelfOwner) and isNotTeleporting then
            return lob
        end
    end
    return nil
end

function StageService.StepLobbyLoop(): boolean
    if not CircuitBreaker:CanExecute() then return false end
    if os.clock() - StageService._lastJoinAttempt < 3.0 then return false end
    StageService._lastJoinAttempt = os.clock()

    -- 1. หากอยู่ในเกมแล้ว ให้จัดการ Vote Wave Skip หรือ Replay
    if IsInMatch() then
        BotState:SetState(BotState.IN_MATCH)

        -- Auto Wave Skip
        if Config.Automation.AutoWaveSkip then
            local skipRem = SafeUtils.SafeGetRemote(Config.Events.VoteWaveSkipRemote)
            if skipRem then
                pcall(function()
                    if skipRem:IsA("RemoteFunction") then skipRem:InvokeServer() else skipRem:FireServer() end
                end)
            end
        end

        -- Auto Vote Replay เมื่อเกมจบ
        if Config.Automation.AutoReplayLoop then
            local finishVote = SafeUtils.SafeGetRemote(Config.Events.GameFinishedVoteRemote)
            if finishVote then
                pcall(function()
                    if finishVote:IsA("RemoteFunction") then
                        finishVote:InvokeServer("replay")
                    else
                        finishVote:FireServer("replay")
                    end
                end)
            end
        end
        return true
    end

    -- 2. หากอยู่ใน Lobby และเปิด AutoPlayStage ให้หาห้องเข้า
    if Config.Automation.AutoPlayStage then
        local targetLobby = StageService.FindAvailableLobby(Config.Automation.StageMode)
        if targetLobby then
            Logger:Log("Stage", "INFO", string.format("ตรวจพบห้องว่าง [%s] กำลังส่งคำขอเข้าร่วม...", targetLobby.Name))
            
            local joinRem = SafeUtils.SafeGetRemote(Config.Events.JoinLobbyRemote)
            local startRem = SafeUtils.SafeGetRemote(Config.Events.StartGameRemote)

            if joinRem then
                local sJoin, _ = pcall(function()
                    if joinRem:IsA("RemoteFunction") then
                        return joinRem:InvokeServer(targetLobby.Name)
                    else
                        joinRem:FireServer(targetLobby.Name)
                        return true
                    end
                end)

                if sJoin then
                    Logger:Log("Stage", "INFO", "เข้าห้องสำเร็จ กำลังส่งคำสั่งเริ่มเกม...")
                    SafeUtils.HumanWait(0.8, 1.2)
                    if startRem then
                        pcall(function()
                            if startRem:IsA("RemoteFunction") then
                                startRem:InvokeServer(targetLobby.Name)
                            else
                                startRem:FireServer(targetLobby.Name)
                            end
                        end)
                        Logger:Log("Stage", "INFO", "เริ่มเกมเรียบร้อย กำลังรอวาปเข้าสู่ด่าน...")
                    end
                    return true
                end
            end
        else
            Logger:Log("Stage", "INFO", "กำลังสแกนหาห้องว่างใน Lobby...")
        end
    end
    return false
end

-- ==============================================================================
-- 11. FUNCTION 5 & 6: AUTO PLACE & UPGRADE UNITS (วางตัวหน้าประตู + อัปเกรด)
-- ==============================================================================
local CombatService = {
    _placedCount = 0,
    _lastUpgradeTime = 0,
    _lastPlaceTime = 0,
}

-- ค้นหาตำแหน่งหน้าประตูเกิดมอนสเตอร์
function CombatService.FindEnemySpawnPosition(): Vector3?
    -- 1. ค้นหาจาก Spawner Part หรือ Portal ในแมพ
    for _, desc in ipairs(workspace:GetDescendants()) do
        local n = string.lower(desc.Name)
        if (n:find("spawner") or n:find("portal") or n:find("enemyspawn") or n:find("spawn_point")) and desc:IsA("BasePart") then
            return desc.Position
        end
    end

    -- 2. ค้นหาจากมอนสเตอร์ตัวแรกที่เพิ่งเดินออกมา
    local unitsFolder = workspace:FindFirstChild("_UNITS")
    if unitsFolder then
        for _, model in ipairs(unitsFolder:GetChildren()) do
            local stats = model:FindFirstChild("_stats")
            -- มอนสเตอร์จะไม่มี _stats.player หรือมี _stats.is_enemy
            if stats and not stats:FindFirstChild("player") then
                local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root then
                    return root.Position
                end
            end
        end
    end

    -- 3. Fallback: วางข้างหน้าตัวละคร LocalPlayer เล็กน้อย
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        return root.Position + root.CFrame.LookVector * 12.0
    end
    return nil
end

-- วางยูนิตหน้าประตูเกิดมอนสเตอร์
function CombatService.PlaceUnitAtGate(): boolean
    if not IsInMatch() then return false end
    if os.clock() - CombatService._lastPlaceTime < 2.0 then return false end
    CombatService._lastPlaceTime = os.clock()

    local spawnRemote = SafeUtils.SafeGetRemote(Config.Events.SpawnUnitRemote)
    if not spawnRemote then return false end

    local gatePos = CombatService.FindEnemySpawnPosition()
    if not gatePos then return false end

    -- ค้นหาช่องยูนิตที่มีใน spawn_units GUI
    local su = PlayerGui:FindFirstChild(Config.UI.SpawnUnitsGUI)
    local unitsFrame = su and su:FindFirstChild("Units", true)
    if not unitsFrame then return false end

    for _, slotBtn in ipairs(unitsFrame:GetChildren()) do
        if slotBtn:IsA("GuiButton") or slotBtn:IsA("Frame") then
            -- สุ่มตำแหน่งกระจายรอบหน้าประตูไม่ให้ทับซ้อนกัน
            local offset = Vector3.new((math.random() - 0.5) * 8.0, 0, (math.random() - 0.5) * 8.0)
            local targetCFrame = CFrame.new(gatePos + offset)

            local s, res = pcall(function()
                if spawnRemote:IsA("RemoteFunction") then
                    return spawnRemote:InvokeServer(slotBtn.Name, targetCFrame)
                else
                    spawnRemote:FireServer(slotBtn.Name, targetCFrame)
                    return true
                end
            end)

            if s then
                CombatService._placedCount += 1
                Logger:Log("Combat", "INFO", string.format("วางยูนิต Slot [%s] หน้าประตูมอนสเตอร์สำเร็จ!", slotBtn.Name))
                SafeUtils.HumanWait(0.4, 0.7)
                return true
            end
        end
    end
    return false
end

-- อัปเกรดยูนิตที่วางแล้ว
function CombatService.UpgradePlacedUnits(): number
    if not IsInMatch() then return 0 end
    if os.clock() - CombatService._lastUpgradeTime < 1.5 then return 0 end
    CombatService._lastUpgradeTime = os.clock()

    local unitsFolder = workspace:FindFirstChild("_UNITS")
    if not unitsFolder then return 0 end

    local upgradeRemote = SafeUtils.SafeGetRemote(Config.Events.UpgradeUnitRemote)
    if not upgradeRemote then return 0 end

    local upgraded = 0
    for _, unitModel in ipairs(unitsFolder:GetChildren()) do
        local stats = unitModel:FindFirstChild("_stats")
        local playerVal = stats and stats:FindFirstChild("player")
        
        -- ตรวจสอบว่าเป็นยูนิตของผู้เล่นเราเอง
        local isMine = (playerVal and playerVal:IsA("ObjectValue") and playerVal.Value == LocalPlayer)
        if isMine or (not stats and unitModel:IsA("Model")) then
            local s, res = pcall(function()
                if upgradeRemote:IsA("RemoteFunction") then
                    return upgradeRemote:InvokeServer(unitModel)
                else
                    upgradeRemote:FireServer(unitModel)
                    return true
                end
            end)
            if s and res ~= false then
                upgraded += 1
                Logger:Log("Combat", "INFO", "อัปเกรดยูนิต " .. unitModel.Name .. " เรียบร้อย!")
            end
            SafeUtils.HumanWait(0.2, 0.4)
        end
    end
    return upgraded
end

-- ==============================================================================
-- 12. POPULATE TAB CONTROLS (UI INTERACTION)
-- ==============================================================================
-- [TAB 1: STAGES]
AddToggle(StagesPage, "⚔️ เล่นด่านอัตโนมัติ (Auto Join & Start)", Config.Automation.AutoPlayStage, function(v)
    Config.Automation.AutoPlayStage = v
    Logger:Log("Config", "INFO", "AutoPlayStage: " .. tostring(v))
end)

AddToggle(StagesPage, "🔄 ลงวนลูปอัตโนมัติ (Auto Replay Loop)", Config.Automation.AutoReplayLoop, function(v)
    Config.Automation.AutoReplayLoop = v
    Logger:Log("Config", "INFO", "AutoReplayLoop: " .. tostring(v))
end)

AddToggle(StagesPage, "⏩ สคิปเวฟอัตโนมัติ (Auto Wave Skip)", Config.Automation.AutoWaveSkip, function(v)
    Config.Automation.AutoWaveSkip = v
    Logger:Log("Config", "INFO", "AutoWaveSkip: " .. tostring(v))
end)

AddButton(StagesPage, "🚀 เข้าร่วมและเริ่มด่านเดี๋ยวนี้ (Join Now)", Color3.fromRGB(40, 140, 85), function()
    StageService.StepLobbyLoop()
end)

-- [TAB 2: COMBAT]
AddToggle(CombatPage, "🚪 วางตัวหน้าประตูมอนเกิด (Auto Place at Gate)", Config.Automation.AutoPlaceUnits, function(v)
    Config.Automation.AutoPlaceUnits = v
    Logger:Log("Config", "INFO", "AutoPlaceUnits: " .. tostring(v))
end)

AddToggle(CombatPage, "⬆️ อัปเกรดยูนิตเมื่อวางแล้ว (Auto Upgrade)", Config.Automation.AutoUpgradeUnits, function(v)
    Config.Automation.AutoUpgradeUnits = v
    Logger:Log("Config", "INFO", "AutoUpgradeUnits: " .. tostring(v))
end)

AddToggle(CombatPage, "👑 สวมใส่ตัวที่ดีที่สุดอัตโนมัติ (Auto Equip Best)", Config.Automation.AutoEquipBest, function(v)
    Config.Automation.AutoEquipBest = v
    Logger:Log("Config", "INFO", "AutoEquipBest: " .. tostring(v))
end)

AddButton(CombatPage, "⚡ สวมใส่ตัวที่ดีที่สุดเดี๋ยวนี้ (Equip Best Now)", Color3.fromRGB(50, 90, 170), function()
    TeamService.EquipBest()
end)

AddButton(CombatPage, "🛡️ วางยูนิตหน้าประตูทันที (Place Now)", Color3.fromRGB(160, 90, 40), function()
    CombatService.PlaceUnitAtGate()
end)

-- [TAB 3: SUMMON]
AddToggle(SummonPage, "🎲 สุ่มตัวละครอัตโนมัติ (Auto Summon Loop)", Config.Automation.AutoSummon, function(v)
    Config.Automation.AutoSummon = v
    Logger:Log("Config", "INFO", "AutoSummon: " .. tostring(v))
end)

-- แบนเนอร์ที่มีให้เลือก
local availableBanners = SummonService.GetAvailableBanners()
for _, bName in ipairs(availableBanners) do
    AddButton(SummonPage, "🎯 สุ่มแบนเนอร์: " .. bName .. " (10x)", Color3.fromRGB(38, 44, 62), function()
        Config.Automation.SelectedBanner = bName
        SummonService.ExecuteSummon(bName, "gems10")
    end)
end

-- [TAB 4: REWARD]
AddToggle(RewardPage, "🎁 ตรวจสอบและรับรางวัลอัตโนมัติ (Auto Claim)", Config.Automation.AutoClaimRewards, function(v)
    Config.Automation.AutoClaimRewards = v
    Logger:Log("Config", "INFO", "AutoClaimRewards: " .. tostring(v))
end)

AddButton(RewardPage, "⚡ กดรับรางวัลทั้งหมดทันที (Claim All Now)", Color3.fromRGB(0, 150, 95), function()
    RewardService.ClaimAll()
end)

-- [TAB 5: LOGS]
AddButton(LogsPage, "🧹 ล้างประวัติ Log Console (Clear)", Color3.fromRGB(50, 55, 75), function()
    for _, child in ipairs(LogScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    Logger:Log("Logger", "INFO", "ล้างประวัติ Log เรียบร้อย")
end)

-- ==============================================================================
-- 13. MAIN WORKER LOOP (ISOLATED WORKER TASKS)
-- ==============================================================================
local Worker = {
    _running = true,
    _connections = {} :: { RBXScriptConnection }
}

function Worker:Start()
    Logger:Log("Worker", "INFO", "เริ่มการทำงานระบบ Automation Worker Thread...")

    task.spawn(function()
        local lastClaimTick = 0
        local lastEquipTick = 0

        while self._running do
            UpdateCurrencyDisplay()

            if CircuitBreaker:CanExecute() then
                -- 1. Task: In-Game Combat (วางตัว + อัปเกรดตัวเมื่ออยู่ในด่าน)
                if IsInMatch() then
                    if Config.Automation.AutoPlaceUnits then
                        pcall(CombatService.PlaceUnitAtGate)
                    end
                    if Config.Automation.AutoUpgradeUnits then
                        pcall(CombatService.UpgradePlacedUnits)
                    end
                else
                    -- 2. Task: Auto Claim Rewards (รับรางวัลเมื่อถึงเวลา)
                    if Config.Automation.AutoClaimRewards and (os.clock() - lastClaimTick > Config.Automation.ClaimInterval) then
                        lastClaimTick = os.clock()
                        pcall(RewardService.ClaimAll)
                    end

                    -- 3. Task: Auto Equip Best (สวมใส่ตัวที่ดีที่สุด)
                    if Config.Automation.AutoEquipBest and (os.clock() - lastEquipTick > Config.Automation.EquipInterval) then
                        lastEquipTick = os.clock()
                        pcall(TeamService.EquipBest)
                    end

                    -- 4. Task: Auto Summon (เมื่อเปิดใช้งาน)
                    if Config.Automation.AutoSummon then
                        pcall(function()
                            SummonService.ExecuteSummon(Config.Automation.SelectedBanner, Config.Automation.SummonMode)
                        end)
                    end
                end

                -- 5. Task: Stage & Matchmaking Loop (จัดการด่านและลูป)
                if Config.Automation.AutoPlayStage or Config.Automation.AutoReplayLoop or Config.Automation.AutoWaveSkip then
                    pcall(StageService.StepLobbyLoop)
                end

                CircuitBreaker:RecordSuccess()
            else
                Logger:Log("Worker", "WARN", "Circuit Breaker ทำงาน พักระบบชั่วคราว...")
                task.wait(2.0)
            end

            task.wait(1.0)
        end
        Logger:Log("Worker", "INFO", "ระบบ Worker หยุดทำงานเรียบร้อย")
    end)
end

function Worker:Stop()
    self._running = false
    for _, conn in ipairs(self._connections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(self._connections)
    ScreenGui:Destroy()
end

CloseBtn.MouseButton1Click:Connect(function()
    Worker:Stop()
end)

-- START AUTOMATION
Worker:Start()
UpdateCurrencyDisplay()
Logger:Log("System", "INFO", "Anime Adventures QA Hub Pro พร้อมใช้งานแล้ว!")
