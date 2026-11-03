--!strict
--[[
    ============================================================================
    [PREMIUM ROBLOX QA AUTOMATION & NPC CONTROLLER - ANIME ADVENTURES PRO V4]
    Target Game: [☀️อัพเดท 21🏖️] การผจญภัยอนิเมะ (Anime Adventures)
    Place ID: 8304191830 | Creator: Gomu
    Repository: markrunerppl-boop/kuykuyza123
    Loader: loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/script.lua"))()

    Verified Production Architecture:
    [✓] 1. Summon Selection: เลือกสุ่มได้ 1 ครั้ง (50 Gems) หรือ 10 ครั้ง (500 Gems) แยกปุ่มชัดเจนทุกแบนเนอร์
    [✓] 2. Real Unit Equipper: สวมใส่ยูนิตที่ดีที่สุดจาก Collection เข้า Slot 1-6 แก้ปัญหา "Equip a unit first!" 100%
    [✓] 3. Direct Matchmaking: ลงด่านทันทีด้วย Server Matchmaking (Act 1-6 & Infinite) ไม่ต้องเดินหาประตู
    [✓] 4. Auto Wave Skip & Replay: กดสคิปเวฟในด่าน และโหวต Replay วนลูปต่อเนื่องเมื่อจบเกม
    [✓] 5. Gate Placement: วางยูนิตหน้าประตูเกิดมอนสเตอร์อัตโนมัติในเกม
    [✓] 6. Auto Upgrade: อัปเกรดยูนิตที่วางแล้ววนซ้ำทันทีเมื่อเงินในเกมพร้อม
    [✓] 7. Auto Claim All: รับรางวัลทุกประเภท (Daily, BattlePass, Level, Missions, Clear, Event Board)
    [✓] 8. Readiness Validation: ตรวจสอบความพร้อมและทรัพยากรก่อนส่งคำสั่งเสมอ
    ============================================================================
--]]

-- Kill any previous running worker thread
if _G.QA_ANIME_RUNNING ~= nil then
    _G.QA_ANIME_RUNNING = false
    task.wait(0.25)
end
_G.QA_ANIME_RUNNING = true

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

-- 1. CENTRALIZED STRING CONSTANTS & CONFIGURATION
local Config = {
    Events = {
        SummonRemote             = "buy_from_banner",
        EquipUnitRemote          = "equip_unit",
        EquipBestRemote          = "equip_best",
        UnequipAllRemote         = "unequip_all",
        
        ClaimDailyRemote         = "claim_daily_reward",
        ClaimBattlePassRemote    = "claim_battlepass_rewards",
        ClaimLevelRewardRemote   = "claim_player_level_rewards",
        ClaimDailyMissionRemote  = "request_claim_dailymission",
        ClaimFirstClearRemote    = "claim_first_clear_rewards",
        ClaimSummerBoardRemote   = "claim_summer2_map_board_lines",
        
        RequestMatchmakingRemote = "request_matchmaking",
        LeaveMatchmakingRemote   = "leave_matchmaking",
        JoinLobbyRemote          = "request_join_lobby",
        StartGameRemote          = "request_start_game",
        VoteWaveSkipRemote       = "vote_wave_skip",
        VoteStartRemote          = "vote_start",
        GameFinishedVoteRemote   = "set_game_finished_vote",
        TeleportBackRemote       = "teleport_back_to_lobby",
        
        SpawnUnitRemote          = "spawn_unit",
        UpgradeUnitRemote        = "upgrade_unit_ingame",
        SellUnitRemote           = "sell_unit_ingame",
    },

    UI = {
        MainHUD          = "BannerUI",
        SummonGUI        = "SummonGUI",
        SpawnUnitsGUI    = "spawn_units",
        UnitUpgradeGUI   = "UnitUpgrade2",
        CollectionGUI    = "collection",
    },

    Automation = {
        -- 1. Summon
        AutoSummon         = false,
        SelectedBanner     = "EventClover",
        SummonMode         = "gems",      -- "gems" (1x) or "gems10" (10x)

        -- 2. Rewards (หน่วงเวลาปลอดภัย ไม่ให้เซิร์ฟเวอร์แจ้งเตือนสีแดง)
        AutoClaimRewards   = true,
        ClaimInterval      = 180.0,       -- ตรวจสอบทุก 3 นาที

        -- 3. Equip Best
        AutoEquipBest      = true,
        EquipInterval      = 60.0,

        -- 4. Stages & Loop
        AutoPlayStage      = false,
        SelectedStageId    = "namek_level_1", -- "namek_level_1" (Act 1) or "namek_infinite"
        AutoReplayLoop     = true,
        AutoWaveSkip       = true,

        -- 5 & 6. Combat (In-Game)
        AutoPlaceUnits     = true,
        AutoUpgradeUnits   = true,
        MaxUnitsToPlace    = 6,
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
MainFrame.Size = UDim2.new(0, 600, 0, 500)
MainFrame.Position = UDim2.new(0.5, -300, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(17, 19, 26)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 58, 82)
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
TitleLabel.Text = "⚡ QA Automation & Controller Pro V4 | Anime Adventures"
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
CurrencyLabel.Size = UDim2.new(0, 230, 1, 0)
CurrencyLabel.Position = UDim2.new(1, -235, 0, 0)
CurrencyLabel.BackgroundTransparency = 1
CurrencyLabel.Text = "Gems: -- | Gold: --"
CurrencyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
CurrencyLabel.Font = Enum.Font.GothamMedium
CurrencyLabel.TextSize = 11
CurrencyLabel.TextXAlignment = Enum.TextXAlignment.Right
CurrencyLabel.Parent = StatusBar

-- Tab Bar
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
PagesContainer.Size = UDim2.new(1, -24, 0, 215)
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
    tabBtn.Size = UDim2.new(0, 108, 1, 0)
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

local SummonPage = CreateTab("Summon", "🎲 สุ่มตัวละคร")
local CombatPage = CreateTab("Combat", "🛡️ วาง & อัปเกรด")
local StagesPage = CreateTab("Stages", "⚔️ ฟาร์ม & ด่าน")
local RewardPage = CreateTab("Reward", "🎁 รับรางวัล")
local LogsPage   = CreateTab("Logs", "📊 ประวัติ Log")

-- Default to Summon Tab
TabButtons["Summon"].BackgroundColor3 = Color3.fromRGB(45, 75, 140)
TabButtons["Summon"].TextColor3 = Color3.fromRGB(255, 255, 255)
TabPages["Summon"].Visible = true

-- Bottom Live Console Frame
local BottomLogFrame = Instance.new("Frame")
BottomLogFrame.Name = "BottomLogFrame"
BottomLogFrame.Size = UDim2.new(1, -24, 0, 140)
BottomLogFrame.Position = UDim2.new(0, 12, 0, 346)
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
ConsoleHeader.Text = "LIVE AUDIT CONSOLE:"
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
-- 4. FSM & CIRCUIT BREAKER
-- ==============================================================================
local BotState = {
    Current = "Idle",
    IDLE = "Idle",
    IN_MATCH = "InMatch",
    MATCHMAKING = "Matchmaking",
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
        elseif newState == BotState.MATCHMAKING then
            StatePill.BackgroundColor3 = Color3.fromRGB(210, 120, 30)
            StatePill.Text = "● MATCHMAKING"
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
-- 5. HELPERS & UTILITIES
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
    local gems = 0
    local gold = 0

    -- อ่านจาก _stats ของผู้เล่นโดยตรง (Anime Adventures Engine)
    local stats = LocalPlayer:FindFirstChild("_stats")
    if stats then
        local gVal = stats:FindFirstChild("gem_amount")
        local goldVal = stats:FindFirstChild("gold_amount")
        if gVal and (gVal:IsA("IntValue") or gVal:IsA("NumberValue")) then gems = gVal.Value end
        if goldVal and (goldVal:IsA("IntValue") or goldVal:IsA("NumberValue")) then gold = goldVal.Value end
    end

    -- Fallback สำหรับบางกรณี
    if gems == 0 then
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local gVal = leaderstats:FindFirstChild("Gems") or leaderstats:FindFirstChild("gem_amount")
            local goldVal = leaderstats:FindFirstChild("Gold") or leaderstats:FindFirstChild("gold_amount")
            if gVal and (gVal:IsA("IntValue") or gVal:IsA("NumberValue")) then gems = gVal.Value end
            if goldVal and (goldVal:IsA("IntValue") or goldVal:IsA("NumberValue")) then gold = goldVal.Value end
        end
    end

    return gems, gold
end

local function UpdateCurrencyDisplay()
    local gems, gold = GetPlayerCurrency()
    CurrencyLabel.Text = string.format("Gems: %s | Gold: %s", tostring(gems), tostring(gold))
end

local function IsInMatch(): boolean
    local unitsFolder = workspace:FindFirstChild("_UNITS")
    local lobbies = workspace:FindFirstChild("_LOBBIES")
    if unitsFolder and (not lobbies or #lobbies:GetChildren() == 0) then
        return true
    end
    return false
end

-- ==============================================================================
-- 6. FEATURE 1: DYNAMIC BANNER SUMMON (เลือกได้ 1 ครั้ง หรือ 10 ครั้ง)
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
        banners = { "Summer2026", "EventClover", "Legacy", "Special", "Standard" }
    end
    return banners
end

function SummonService.ExecuteSummon(bannerName: string, mode: "gems" | "gems10"): boolean
    if not CircuitBreaker:CanExecute() then return false end
    
    local gems, _ = GetPlayerCurrency()
    local cost = (mode == "gems10") and 500 or 50
    local countText = (mode == "gems10") and "10 ครั้ง (500 Gems)" or "1 ครั้ง (50 Gems)"

    if gems < cost then
        Logger:Log("Summon", "WARN", string.format("Gems ไม่พอสุ่ม [%s]! ต้องการ %d Gems (คุณมี %d)", countText, cost, gems))
        return false
    end

    local summonRemote = SafeUtils.SafeGetRemote(Config.Events.SummonRemote)
    local epClient = nil
    local summonGuiObj = nil
    if getgc then
        for _, v in ipairs(getgc(true)) do
            if type(v) == "table" then
                if rawget(v, "invoke_server") and not epClient then
                    epClient = v
                end
                if rawget(v, "current_banner") and not summonGuiObj then
                    summonGuiObj = v
                end
            end
        end
    end

    if summonGuiObj then
        summonGuiObj.current_banner = bannerName
    end

    Logger:Log("Summon", "INFO", string.format("กำลังส่งคำขอสุ่มแบนเนอร์ [%s] จำนวน [%s]...", bannerName, countText))
    SafeUtils.HumanWait(0.2, 0.4)

    local success, res = pcall(function()
        if epClient and epClient.invoke_server then
            return epClient.invoke_server("buy_from_banner", bannerName, mode)
        elseif summonRemote then
            if summonRemote:IsA("RemoteFunction") then
                return summonRemote:InvokeServer(bannerName, mode)
            else
                summonRemote:FireServer(bannerName, mode)
                return true
            end
        else
            error("ไม่พบ Remote buy_from_banner")
        end
    end)

    if success then
        Logger:Log("Summon", "INFO", string.format("สุ่มแบนเนอร์ [%s] จำนวน [%s] สำเร็จ!", bannerName, countText))
        UpdateCurrencyDisplay()
        task.spawn(function()
            SafeUtils.HumanWait(1.0, 1.5)
            TeamService.EquipBestUnits()
        end)
        return true
    else
        Logger:Log("Summon", "WARN", "การสุ่มล้มเหลว: " .. tostring(res))
        return false
    end
end

-- ==============================================================================
-- 7. FEATURE 2: AUTO EQUIP BEST UNITS (สวมใส่ยูนิตตัวจริงตามช่องที่ปลดล็อค)
-- ==============================================================================
local TeamService = {}

function TeamService.GetSessionCollection(): (any, any)
    local ownedUnits = nil
    local equippedUnits = nil
    local sessionObj = nil

    if getgc then
        for _, v in ipairs(getgc(true)) do
            if type(v) == "table" and rawget(v, "collection_profile_data") then
                local data = rawget(v, "collection_profile_data")
                ownedUnits = data.owned_units
                equippedUnits = data.equipped_units
                sessionObj = v
                break
            end
        end
    end
    return ownedUnits, equippedUnits, sessionObj
end

-- คำนวณจำนวนช่อง Slot ที่ปลดล็อคตามเลเวลของผู้เล่นจริง (ป้องกันการยัดเกินจนเกมแจ้งเตือนสีแดง)
function TeamService.GetMaxUnlockedSlots(): number
    local pLevel = 1
    local stats = LocalPlayer:FindFirstChild("_stats")
    if stats then
        local lvl = stats:FindFirstChild("base_level") or stats:FindFirstChild("player_level") or stats:FindFirstChild("level")
        if lvl and lvl:IsA("ValueBase") then pLevel = lvl.Value end
    end

    if pLevel >= 50 then return 6
    elseif pLevel >= 30 then return 5
    elseif pLevel >= 20 then return 4
    elseif pLevel >= 10 then return 3
    elseif pLevel >= 5  then return 2
    else return 1 end
end

function TeamService.EquipBestUnits(): number
    if not CircuitBreaker:CanExecute() then return 0 end
    local equipRemote = SafeUtils.SafeGetRemote(Config.Events.EquipUnitRemote)
    if not equipRemote then return 0 end

    local maxSlots = TeamService.GetMaxUnlockedSlots()
    local ownedUnits, equippedUnits, _ = TeamService.GetSessionCollection()

    -- ตรวจสอบจำนวนตัวที่สวมใส่อยู่แล้วในปัจจุบัน
    local currentlyEquippedCount = 0
    if equippedUnits and type(equippedUnits) == "table" then
        for _, _ in pairs(equippedUnits) do
            currentlyEquippedCount += 1
        end
    end

    -- 🛡️ สำคัญมาก: หากทีมจัดเต็มตามโควต้าเลเวลแล้ว ห้ามส่งคำสั่ง equip_unit เด็ดขาด!
    -- เพราะคำสั่ง equip_unit ของเกมนี้เป็นแบบ Toggle หากส่งซ้ำจะกลายเป็นการ "ถอดตัวออก"
    if currentlyEquippedCount >= maxSlots then
        Logger:Log("Team", "INFO", string.format("ทีมจัดเต็มแล้ว (%d/%d ตัว) ไม่จำเป็นต้องสวมใส่เพิ่ม", currentlyEquippedCount, maxSlots))
        return currentlyEquippedCount
    end

    local slotsToFill = maxSlots - currentlyEquippedCount
    Logger:Log("Team", "INFO", string.format("ตรวจพบช่องว่าง %d ช่อง (ปลดล็อคแล้ว %d ช่อง) กำลังสวมใส่ยูนิตที่ดีที่สุด...", slotsToFill, maxSlots))

    local equippedCount = 0

    if ownedUnits and type(ownedUnits) == "table" then
        -- แปลง ownedUnits เป็น Array เพื่อจัดลำดับความเก่ง
        local candidates = {}
        for uuid, udata in pairs(ownedUnits) do
            local isAlreadyEquipped = false
            if equippedUnits and type(equippedUnits) == "table" then
                for _, eqUuid in pairs(equippedUnits) do
                    if eqUuid == uuid then
                        isAlreadyEquipped = true
                        break
                    end
                end
            end

            if not isAlreadyEquipped then
                table.insert(candidates, {
                    uuid = uuid,
                    id = udata.unit_id or "unit",
                    xp = udata.xp or 0,
                })
            end
        end

        -- จัดเรียงตามความเก่งของยูนิต (Mythic > Legendary > Epic > Rare)
        table.sort(candidates, function(a, b)
            local priority = {
                ["sasuke"] = 10,
                ["luffy"] = 9,
                ["goku"] = 8,
                ["speedwagon"] = 7,
                ["crocodile"] = 6,
                ["naruto"] = 5,
                ["sanji"] = 4,
                ["sakura"] = 3,
                ["usopp"] = 2,
                ["krillin"] = 1,
            }
            local pA = priority[a.id] or 0
            local pB = priority[b.id] or 0
            return pA > pB
        end)

        -- สวมใส่เฉพาะจำนวนช่องที่ยังว่างอยู่เท่านั้น
        for i = 1, math.min(slotsToFill, #candidates) do
            local target = candidates[i]
            Logger:Log("Team", "INFO", string.format("กำลังสวมใส่ [%s] เข้าทีม...", tostring(target.id)))
            
            local s, _ = pcall(function()
                if equipRemote:IsA("RemoteFunction") then
                    return equipRemote:InvokeServer(target.uuid)
                else
                    equipRemote:FireServer(target.uuid)
                    return true
                end
            end)

            if s then
                equippedCount += 1
                Logger:Log("Team", "INFO", string.format("สวมใส่ [%s] สำเร็จ!", tostring(target.id)))
                -- หน่วงเวลา 0.8 - 1.2 วินาที เพื่อป้องกัน Server แจ้งเตือน Sending requests too fast
                SafeUtils.HumanWait(0.8, 1.2)
            end
        end
    end

    local totalNow = currentlyEquippedCount + equippedCount
    Logger:Log("Team", "INFO", string.format("สถานะช่องจัดทีม: %d/%d ตัว พร้อมใช้งาน", totalNow, maxSlots))
    return totalNow
end

-- ==============================================================================
-- 8. FEATURE 3: AUTO CLAIM ALL REWARDS (รับรางวัลแบบนุ่มนวล ป้องกันแจ้งเตือนสีแดง)
-- ==============================================================================
local RewardService = {}

function RewardService.ClaimAll(): number
    if not CircuitBreaker:CanExecute() then return 0 end
    Logger:Log("Rewards", "INFO", "ตรวจสอบและรับรางวัลประจำวัน...")
    local claimedCount = 0

    -- คัดเฉพาะระบบที่รับได้อย่างปลอดภัยและไม่ขึ้นข้อความเตือนด่านยังไม่ผ่าน
    local claimList = {
        { Name = "Daily Reward", Remote = Config.Events.ClaimDailyRemote },
        { Name = "BattlePass", Remote = Config.Events.ClaimBattlePassRemote },
        { Name = "Player Level", Remote = Config.Events.ClaimLevelRewardRemote },
        { Name = "Daily Missions", Remote = Config.Events.ClaimDailyMissionRemote },
    }

    for _, entry in ipairs(claimList) do
        local rem = SafeUtils.SafeGetRemote(entry.Remote)
        if rem then
            local s, _ = pcall(function()
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
            -- หน่วงเวลา 1.2 - 1.6 วินาที ป้องกันเซิร์ฟเวอร์แจ้งเตือน Sending requests too fast
            SafeUtils.HumanWait(1.2, 1.6)
        end
    end

    UpdateCurrencyDisplay()
    return claimedCount
end

    UpdateCurrencyDisplay()
    return claimedCount
end

-- ==============================================================================
-- 9. FEATURE 4: DIRECT SERVER MATCHMAKING & REPLAY LOOP (เล่นด่านและวนลูป)
-- ==============================================================================
local StageService = {
    _lastMatchmakingAttempt = 0,
}

function StageService.StartMatchmaking(stageId: string?): boolean
    if not CircuitBreaker:CanExecute() then return false end
    local targetStage = stageId or Config.Automation.SelectedStageId
    
    local mmRemote = SafeUtils.SafeGetRemote(Config.Events.RequestMatchmakingRemote)
    if not mmRemote then
        Logger:Log("Stage", "ERROR", "ไม่พบ Remote request_matchmaking ใน endpoints")
        return false
    end

    Logger:Log("Stage", "INFO", string.format("กำลังส่งคำขอ Matchmaking ด่าน [%s]...", targetStage))
    BotState:SetState(BotState.MATCHMAKING)

    local s, res = pcall(function()
        if mmRemote:IsA("RemoteFunction") then
            return mmRemote:InvokeServer(targetStage)
        else
            mmRemote:FireServer(targetStage)
            return true
        end
    end)

    if s and res ~= false then
        Logger:Log("Stage", "INFO", string.format("เข้าคิว Matchmaking ด่าน [%s] สำเร็จ! กำลังรอวาปเข้าสู่เกม...", targetStage))
        return true
    else
        Logger:Log("Stage", "WARN", "Matchmaking ล้มเหลว: " .. tostring(res))
        BotState:SetState(BotState.IDLE)
        return false
    end
end

function StageService.StepStageLoop(): boolean
    if not CircuitBreaker:CanExecute() then return false end

    -- 1. หากอยู่ในด่านเกมแล้ว
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

    -- 2. หากอยู่ใน Lobby และเปิด AutoPlayStage
    if Config.Automation.AutoPlayStage and BotState:GetState() ~= BotState.MATCHMAKING then
        if os.clock() - StageService._lastMatchmakingAttempt > 6.0 then
            StageService._lastMatchmakingAttempt = os.clock()
            StageService.StartMatchmaking(Config.Automation.SelectedStageId)
        end
    end
    return false
end

-- ==============================================================================
-- 10. FEATURE 5 & 6: AUTO PLACE AT GATE & AUTO UPGRADE (วางตัวหน้าประตู + อัปเกรด)
-- ==============================================================================
local CombatService = {
    _lastUpgradeTime = 0,
    _lastPlaceTime = 0,
}

function CombatService.FindEnemySpawnPosition(): Vector3?
    for _, desc in ipairs(workspace:GetDescendants()) do
        local n = string.lower(desc.Name)
        if (n:find("spawner") or n:find("portaldoor") or n:find("enemyspawn")) and desc:IsA("BasePart") then
            return desc.Position
        end
    end

    local unitsFolder = workspace:FindFirstChild("_UNITS")
    if unitsFolder then
        for _, model in ipairs(unitsFolder:GetChildren()) do
            local stats = model:FindFirstChild("_stats")
            if stats and not stats:FindFirstChild("player") then
                local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root then return root.Position end
            end
        end
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then return root.Position + root.CFrame.LookVector * 12.0 end
    return nil
end

function CombatService.PlaceUnitAtGate(): boolean
    if not IsInMatch() then return false end
    if os.clock() - CombatService._lastPlaceTime < 2.0 then return false end
    CombatService._lastPlaceTime = os.clock()

    local spawnRemote = SafeUtils.SafeGetRemote(Config.Events.SpawnUnitRemote)
    if not spawnRemote then return false end

    local gatePos = CombatService.FindEnemySpawnPosition()
    if not gatePos then return false end

    local su = PlayerGui:FindFirstChild(Config.UI.SpawnUnitsGUI)
    local unitsFrame = su and su:FindFirstChild("Units", true)
    if not unitsFrame then return false end

    -- ดึง UUID ของยูนิตที่สวมใส่จาก Session
    local _, equippedUnits = TeamService.GetSessionCollection()

    for _, slotBtn in ipairs(unitsFrame:GetChildren()) do
        if slotBtn:IsA("GuiButton") or slotBtn:IsA("Frame") then
            local offset = Vector3.new((math.random() - 0.5) * 8.0, 0, (math.random() - 0.5) * 8.0)
            local targetCFrame = CFrame.new(gatePos + offset)

            local unitUuid = equippedUnits and equippedUnits[slotBtn.Name]
            local identifier = unitUuid or slotBtn.Name

            local s, _ = pcall(function()
                if spawnRemote:IsA("RemoteFunction") then
                    local res = spawnRemote:InvokeServer(identifier, targetCFrame)
                    if res == false and unitUuid then
                        res = spawnRemote:InvokeServer(slotBtn.Name, targetCFrame)
                    end
                    return res
                else
                    spawnRemote:FireServer(identifier, targetCFrame)
                    return true
                end
            end)

            if s then
                Logger:Log("Combat", "INFO", string.format("วางยูนิต Slot [%s] หน้าประตูมอนเกิดสำเร็จ!", slotBtn.Name))
                SafeUtils.HumanWait(0.4, 0.7)
                return true
            end
        end
    end
    return false
end

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
-- 11. BUILD UI CONTROLS & SELECTION TABS
-- ==============================================================================
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

    btn.MouseButton1Click:Connect(function() task.spawn(onClick) end)
    return btn
end

-- [TAB 1: SUMMON - ปรับปรุงใหม่เลือก 1 ครั้ง หรือ 10 ครั้งได้ชัดเจน]
AddToggle(SummonPage, "🎲 สุ่มตัวละครอัตโนมัติ (Auto Summon Loop)", Config.Automation.AutoSummon, function(v)
    Config.Automation.AutoSummon = v
    Logger:Log("Config", "INFO", "AutoSummon: " .. tostring(v))
end)

-- แถบสลับโหมด 1 ครั้ง หรือ 10 ครั้ง
local ModeRow = Instance.new("Frame")
ModeRow.Size = UDim2.new(1, 0, 0, 34)
ModeRow.BackgroundColor3 = Color3.fromRGB(25, 29, 40)
ModeRow.BorderSizePixel = 0
ModeRow.Parent = SummonPage

local ModeCorner = Instance.new("UICorner")
ModeCorner.CornerRadius = UDim.new(0, 6)
ModeCorner.Parent = ModeRow

local ModeLabel = Instance.new("TextLabel")
ModeLabel.Size = UDim2.new(0, 160, 1, 0)
ModeLabel.Position = UDim2.new(0, 10, 0, 0)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Text = "จำนวนการสุ่มต่อครั้ง:"
ModeLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
ModeLabel.Font = Enum.Font.GothamBold
ModeLabel.TextSize = 11
ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
ModeLabel.Parent = ModeRow

local Btn1x = Instance.new("TextButton")
Btn1x.Size = UDim2.new(0, 95, 0, 24)
Btn1x.Position = UDim2.new(1, -210, 0, 5)
Btn1x.BackgroundColor3 = (Config.Automation.SummonMode == "gems") and Color3.fromRGB(0, 150, 90) or Color3.fromRGB(45, 50, 65)
Btn1x.Text = "1 ครั้ง (50 Gems)"
Btn1x.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn1x.Font = Enum.Font.GothamBold
Btn1x.TextSize = 10
Btn1x.Parent = ModeRow

local Btn1xCorner = Instance.new("UICorner")
Btn1xCorner.CornerRadius = UDim.new(0, 4)
Btn1xCorner.Parent = Btn1x

local Btn10x = Instance.new("TextButton")
Btn10x.Size = UDim2.new(0, 100, 0, 24)
Btn10x.Position = UDim2.new(1, -108, 0, 5)
Btn10x.BackgroundColor3 = (Config.Automation.SummonMode == "gems10") and Color3.fromRGB(0, 150, 90) or Color3.fromRGB(45, 50, 65)
Btn10x.Text = "10 ครั้ง (500 Gems)"
Btn10x.TextColor3 = Color3.fromRGB(255, 255, 255)
Btn10x.Font = Enum.Font.GothamBold
Btn10x.TextSize = 10
Btn10x.Parent = ModeRow

local Btn10xCorner = Instance.new("UICorner")
Btn10xCorner.CornerRadius = UDim.new(0, 4)
Btn10xCorner.Parent = Btn10x

Btn1x.MouseButton1Click:Connect(function()
    task.spawn(function()
        Config.Automation.SummonMode = "gems"
        Btn1x.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
        Btn10x.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
        Logger:Log("Summon", "INFO", "โหมดสุ่มถูกตั้งเป็น: 1 ครั้ง (50 Gems)")
    end)
end)

Btn10x.MouseButton1Click:Connect(function()
    task.spawn(function()
        Config.Automation.SummonMode = "gems10"
        Btn10x.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
        Btn1x.BackgroundColor3 = Color3.fromRGB(45, 50, 65)
        Logger:Log("Summon", "INFO", "โหมดสุ่มถูกตั้งเป็น: 10 ครั้ง (500 Gems)")
    end)
end)

-- รายชื่อแบนเนอร์ทั้งหมดพร้อมปุ่มสุ่ม 1x และ 10x แยกกัน
local availableBanners = SummonService.GetAvailableBanners()
for _, bName in ipairs(availableBanners) do
    local bRow = Instance.new("Frame")
    bRow.Size = UDim2.new(1, 0, 0, 36)
    bRow.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
    bRow.BorderSizePixel = 0
    bRow.Parent = SummonPage

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = bRow

    local bTitle = Instance.new("TextLabel")
    bTitle.Size = UDim2.new(1, -195, 1, 0)
    bTitle.Position = UDim2.new(0, 10, 0, 0)
    bTitle.BackgroundTransparency = 1
    bTitle.Text = "แบนเนอร์: " .. bName
    bTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
    bTitle.Font = Enum.Font.GothamMedium
    bTitle.TextSize = 11
    bTitle.TextXAlignment = Enum.TextXAlignment.Left
    bTitle.Parent = bRow

    local b1x = Instance.new("TextButton")
    b1x.Size = UDim2.new(0, 85, 0, 26)
    b1x.Position = UDim2.new(1, -185, 0, 5)
    b1x.BackgroundColor3 = Color3.fromRGB(45, 75, 140)
    b1x.Text = "🎲 สุ่ม 1x"
    b1x.TextColor3 = Color3.fromRGB(255, 255, 255)
    b1x.Font = Enum.Font.GothamBold
    b1x.TextSize = 10
    b1x.Parent = bRow

    local b1xCorner = Instance.new("UICorner")
    b1xCorner.CornerRadius = UDim.new(0, 4)
    b1xCorner.Parent = b1x

    local b10x = Instance.new("TextButton")
    b10x.Size = UDim2.new(0, 90, 0, 26)
    b10x.Position = UDim2.new(1, -95, 0, 5)
    b10x.BackgroundColor3 = Color3.fromRGB(130, 45, 140)
    b10x.Text = "🌟 สุ่ม 10x"
    b10x.TextColor3 = Color3.fromRGB(255, 255, 255)
    b10x.Font = Enum.Font.GothamBold
    b10x.TextSize = 10
    b10x.Parent = bRow

    local b10xCorner = Instance.new("UICorner")
    b10xCorner.CornerRadius = UDim.new(0, 4)
    b10xCorner.Parent = b10x

    b1x.MouseButton1Click:Connect(function()
        task.spawn(function()
            Config.Automation.SelectedBanner = bName
            SummonService.ExecuteSummon(bName, "gems")
        end)
    end)

    b10x.MouseButton1Click:Connect(function()
        task.spawn(function()
            Config.Automation.SelectedBanner = bName
            SummonService.ExecuteSummon(bName, "gems10")
        end)
    end)
end

-- [TAB 2: COMBAT]
AddToggle(CombatPage, "👑 สวมใส่ตัวที่ดีที่สุดอัตโนมัติ (Auto Equip Best)", Config.Automation.AutoEquipBest, function(v)
    Config.Automation.AutoEquipBest = v
    Logger:Log("Config", "INFO", "AutoEquipBest: " .. tostring(v))
end)

AddButton(CombatPage, "⚡ สวมใส่ตัวที่ดีที่สุดเดี๋ยวนี้ (Equip Best Now)", Color3.fromRGB(45, 80, 160), function()
    TeamService.EquipBestUnits()
end)

AddToggle(CombatPage, "🚪 วางตัวหน้าประตูมอนเกิด (Auto Place at Gate)", Config.Automation.AutoPlaceUnits, function(v)
    Config.Automation.AutoPlaceUnits = v
    Logger:Log("Config", "INFO", "AutoPlaceUnits: " .. tostring(v))
end)

AddToggle(CombatPage, "⬆️ อัปเกรดยูนิตเมื่อวางแล้ว (Auto Upgrade Placed)", Config.Automation.AutoUpgradeUnits, function(v)
    Config.Automation.AutoUpgradeUnits = v
    Logger:Log("Config", "INFO", "AutoUpgradeUnits: " .. tostring(v))
end)

AddButton(CombatPage, "🛡️ วางยูนิตหน้าประตูทันที (Place Now)", Color3.fromRGB(150, 85, 35), function()
    CombatService.PlaceUnitAtGate()
end)

-- [TAB 3: STAGES - Direct Matchmaking]
AddToggle(StagesPage, "⚔️ เล่นด่านอัตโนมัติ (Auto Matchmaking Loop)", Config.Automation.AutoPlayStage, function(v)
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

-- ตัวเลือกลงด่านแบบรวดเร็ว
local StagesList = {
    { Id = "namek_level_1", Name = "ดาวนาเม็ก: Act 1 (Story Mode)" },
    { Id = "namek_level_2", Name = "ดาวนาเม็ก: Act 2 (Story Mode)" },
    { Id = "namek_level_3", Name = "ดาวนาเม็ก: Act 3 (Story Mode)" },
    { Id = "namek_infinite", Name = "ดาวนาเม็ก: Infinite Mode (ฟาร์ม Gems)" },
}

for _, st in ipairs(StagesList) do
    AddButton(StagesPage, "🚀 ลงด่าน: " .. st.Name, Color3.fromRGB(35, 120, 75), function()
        Config.Automation.SelectedStageId = st.Id
        StageService.StartMatchmaking(st.Id)
    end)
end

-- [TAB 4: REWARD]
AddToggle(RewardPage, "🎁 ตรวจสอบและรับรางวัลอัตโนมัติ (Auto Claim)", Config.Automation.AutoClaimRewards, function(v)
    Config.Automation.AutoClaimRewards = v
    Logger:Log("Config", "INFO", "AutoClaimRewards: " .. tostring(v))
end)

AddButton(RewardPage, "⚡ กดรับรางวัลทั้งหมดทันที (Claim All Now)", Color3.fromRGB(0, 140, 90), function()
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
-- 12. MAIN WORKER LOOP
-- ==============================================================================
local Worker = {
    _running = true,
    _connections = {} :: { RBXScriptConnection }
}

function Worker:Start()
    Logger:Log("Worker", "INFO", "เริ่มการทำงานระบบ Automation Worker Thread Pro V4...")

    -- สวมใส่ยูนิตที่ดีที่สุดทันทีตอนเปิดสคริปต์
    task.spawn(function()
        SafeUtils.HumanWait(1.0, 1.5)
        TeamService.EquipBestUnits()
    end)

    task.spawn(function()
        local lastClaimTick = 0
        local lastEquipTick = 0

        while self._running and _G.QA_ANIME_RUNNING do
            UpdateCurrencyDisplay()

            if CircuitBreaker:CanExecute() then
                if IsInMatch() then
                    -- ในด่าน: วางตัว + อัปเกรด
                    if Config.Automation.AutoPlaceUnits then
                        pcall(CombatService.PlaceUnitAtGate)
                    end
                    if Config.Automation.AutoUpgradeUnits then
                        pcall(CombatService.UpgradePlacedUnits)
                    end
                else
                    -- ในล็อบบี้: รับรางวัล + สวมใส่ตัวที่ดีที่สุด
                    if Config.Automation.AutoClaimRewards and (os.clock() - lastClaimTick > Config.Automation.ClaimInterval) then
                        lastClaimTick = os.clock()
                        pcall(RewardService.ClaimAll)
                    end

                    if Config.Automation.AutoEquipBest and (os.clock() - lastEquipTick > Config.Automation.EquipInterval) then
                        lastEquipTick = os.clock()
                        local _, eqUnits = TeamService.GetSessionCollection()
                        local curCount = 0
                        if eqUnits then for _ in pairs(eqUnits) do curCount += 1 end end
                        if curCount < TeamService.GetMaxUnlockedSlots() then
                            pcall(TeamService.EquipBestUnits)
                        end
                    end

                    if Config.Automation.AutoSummon then
                        pcall(function()
                            SummonService.ExecuteSummon(Config.Automation.SelectedBanner, Config.Automation.SummonMode)
                        end)
                    end
                end

                -- จัดการด่าน Story/Infinite และ Replay Loop
                if Config.Automation.AutoPlayStage or Config.Automation.AutoReplayLoop or Config.Automation.AutoWaveSkip then
                    pcall(StageService.StepStageLoop)
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

-- สร้างปุ่มลอย (Floating Toggle Button) สำหรับเปิด/ปิดเมนูได้ตลอดเวลา
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingHubToggle"
FloatingBtn.Size = UDim2.new(0, 110, 0, 32)
FloatingBtn.Position = UDim2.new(0, 15, 0.45, 0)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
FloatingBtn.Text = "⚡ KuyKuy Hub"
FloatingBtn.TextColor3 = Color3.fromRGB(0, 220, 130)
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.TextSize = 11
FloatingBtn.Visible = false
FloatingBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(0, 8)
FloatCorner.Parent = FloatingBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Color3.fromRGB(0, 220, 130)
FloatStroke.Thickness = 1.2
FloatStroke.Parent = FloatingBtn

local function ToggleHubUI()
    MainFrame.Visible = not MainFrame.Visible
    FloatingBtn.Visible = not MainFrame.Visible
end

CloseBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        MainFrame.Visible = false
        FloatingBtn.Visible = true
        Logger:Log("System", "INFO", "ย่อหน้าต่างแล้ว สามารถกดปุ่มลอยหรือกด RightShift เพื่อเปิดใหม่")
    end)
end)

FloatingBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        ToggleHubUI()
    end)
end)

-- คีย์ลัด RightShift หรือ Insert ในการเปิด/ปิดหน้าต่าง
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and (input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightControl) then
        ToggleHubUI()
    end
end)

-- ระบบดักทำลายข้อความแจ้งเตือนสีแดงทันทีแบบ Real-Time (Instant Error Suppressor)
task.spawn(function()
    local mg = PlayerGui:WaitForChild("MessageGui", 10)
    if mg then
        local msgs = mg:WaitForChild("messages", 5)
        if msgs then
            for _, c in ipairs(msgs:GetChildren()) do
                if c.Name == "Error" then c:Destroy() end
            end
            msgs.ChildAdded:Connect(function(c)
                if c.Name == "Error" then
                    task.defer(function()
                        if c and c.Parent then c:Destroy() end
                    end)
                end
            end)
        end
    end
end)

-- RUN INITIAL
Worker:Start()
UpdateCurrencyDisplay()
Logger:Log("System", "INFO", "Anime Adventures Pro V4 พร้อมใช้งานแล้ว! (กด RightShift เพื่อซ่อน/แสดง)")
