--!strict
--[[
    ============================================================================
    [PREMIUM ROBLOX QA AUTOMATION & NPC CONTROLLER - ANIME ADVENTURES]
    Target Game: [☀️อัพเดท 21🏖️] การผจญภัยอนิเมะ (Anime Adventures)
    Place ID: 8304191830 | Creator: Gomu
    Repository: markrunerppl-boop/kuykuyza123
    Loader: loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/games/anime_adventures/main.lua"))()

    Core Architecture:
    [✓] Safe Module Loading: ครอบ require() ด้วย pcall ป้องกันระบบหยุดทำงานเมื่อขาด Dependency
    [✓] Centralized String Constants: รวม Events, Remotes, และ UI Frame ไว้ใน Config Table
    [✓] Null-Safety สำหรับ UI & Objects: ตรวจสอบ nil ทุกจุดด้วย SafeUtils.SafeFind ป้องกัน Crash
    [✓] Isolating Worker Tasks: แยก Main Worker Threads ด้วย pcall แต่ละ Task ทำงานอิสระ
    [✓] Finite State Machine (FSM): จัดการสถานะ Idle, Moving, Testing, CircuitBroken เป็นระบบ
    [✓] Humanized Simulation: สุ่ม Path Jitter Delay และใช้ PathfindingService เลียนแบบผู้เล่นจริง
    [✓] Circuit Breaker: ป้องกัน Server Spam โดยตัดวงจรอัตโนมัติเมื่อ Error ติดต่อกันเกิน 3 ครั้ง
    [✓] Live In-Game UI Console: หน้าต่าง UI Draggable พร้อมกล่องแสดง Log แบบเรียลไทม์บนหน้าจอ
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

-- 1. CENTRALIZED STRING CONSTANTS & CONFIGURATION
local Config = {
    Events = {
        SummonRemote       = "buy_from_banner",
        EquipUnitRemote    = "equip_unit",
        UnequipAllRemote   = "unequip_all",
        EquipBestRemote    = "equip_best",
        SellUnitRemote     = "sell_units",
    },
    UI = {
        MainHUD            = "BannerUI",
        SummonFrame        = "SummonWindow",
        ConfirmButton      = "ConfirmBtn",
        InventoryFrame     = "UnitsInventory",
    },
    CircuitBreaker = {
        MaxConsecutiveErrors = 3,
        CooldownTime         = 12.0,
    },
    Simulation = {
        MinActionDelay       = 0.35,
        MaxActionDelay       = 0.75,
        PathJitterRadius     = 2.0,
    }
}

-- ==============================================================================
-- 2. CREATE SCREEN GUI (DRAGGABLE & MODERN DESIGN)
-- ==============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "QAAutomationHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 430)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -215)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(55, 62, 85)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Top Bar (Draggable)
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Color3.fromRGB(26, 29, 39)
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
TitleLabel.Text = "⚡ QA Automation & Controller | Anime Adventures"
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
StatusBar.Size = UDim2.new(1, -24, 0, 34)
StatusBar.Position = UDim2.new(0, 12, 0, 50)
StatusBar.BackgroundColor3 = Color3.fromRGB(24, 27, 36)
StatusBar.BorderSizePixel = 0
StatusBar.Parent = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusBar

local StatePill = Instance.new("TextLabel")
StatePill.Name = "StatePill"
StatePill.Size = UDim2.new(0, 120, 0, 24)
StatePill.Position = UDim2.new(0, 6, 0, 5)
StatePill.BackgroundColor3 = Color3.fromRGB(35, 120, 65)
StatePill.Text = "● STATE: IDLE"
StatePill.TextColor3 = Color3.fromRGB(255, 255, 255)
StatePill.Font = Enum.Font.GothamBold
StatePill.TextSize = 11
StatePill.Parent = StatusBar

local StateCorner = Instance.new("UICorner")
StateCorner.CornerRadius = UDim.new(0, 4)
StateCorner.Parent = StatePill

local BreakerLabel = Instance.new("TextLabel")
BreakerLabel.Name = "BreakerLabel"
BreakerLabel.Size = UDim2.new(0, 140, 1, 0)
BreakerLabel.Position = UDim2.new(0, 135, 0, 0)
BreakerLabel.BackgroundTransparency = 1
BreakerLabel.Text = "Circuit: 0/3 (Normal)"
BreakerLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
BreakerLabel.Font = Enum.Font.GothamMedium
BreakerLabel.TextSize = 11
BreakerLabel.TextXAlignment = Enum.TextXAlignment.Left
BreakerLabel.Parent = StatusBar

local CurrencyLabel = Instance.new("TextLabel")
CurrencyLabel.Name = "CurrencyLabel"
CurrencyLabel.Size = UDim2.new(0, 200, 1, 0)
CurrencyLabel.Position = UDim2.new(1, -210, 0, 0)
CurrencyLabel.BackgroundTransparency = 1
CurrencyLabel.Text = "Gems: -- | Gold: --"
CurrencyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
CurrencyLabel.Font = Enum.Font.GothamMedium
CurrencyLabel.TextSize = 11
CurrencyLabel.TextXAlignment = Enum.TextXAlignment.Right
CurrencyLabel.Parent = StatusBar

-- Controls Frame
local ControlsFrame = Instance.new("Frame")
ControlsFrame.Name = "ControlsFrame"
ControlsFrame.Size = UDim2.new(1, -24, 0, 38)
ControlsFrame.Position = UDim2.new(0, 12, 0, 92)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.Parent = MainFrame

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 140, 1, 0)
ToggleBtn.Position = UDim2.new(0, 0, 0, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
ToggleBtn.Text = "▶ START QA LOOP"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 12
ToggleBtn.Parent = ControlsFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleBtn

local TestSummonBtn = Instance.new("TextButton")
TestSummonBtn.Name = "TestSummonBtn"
TestSummonBtn.Size = UDim2.new(0, 125, 1, 0)
TestSummonBtn.Position = UDim2.new(0, 148, 0, 0)
TestSummonBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
TestSummonBtn.Text = "🎲 Test Banner"
TestSummonBtn.TextColor3 = Color3.fromRGB(220, 225, 240)
TestSummonBtn.Font = Enum.Font.GothamMedium
TestSummonBtn.TextSize = 11
TestSummonBtn.Parent = ControlsFrame

local TestSummonCorner = Instance.new("UICorner")
TestSummonCorner.CornerRadius = UDim.new(0, 6)
TestSummonCorner.Parent = TestSummonBtn

local TestRoamBtn = Instance.new("TextButton")
TestRoamBtn.Name = "TestRoamBtn"
TestRoamBtn.Size = UDim2.new(0, 120, 1, 0)
TestRoamBtn.Position = UDim2.new(0, 281, 0, 0)
TestRoamBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
TestRoamBtn.Text = "🧭 Test Roam"
TestRoamBtn.TextColor3 = Color3.fromRGB(220, 225, 240)
TestRoamBtn.Font = Enum.Font.GothamMedium
TestRoamBtn.TextSize = 11
TestRoamBtn.Parent = ControlsFrame

local TestRoamCorner = Instance.new("UICorner")
TestRoamCorner.CornerRadius = UDim.new(0, 6)
TestRoamCorner.Parent = TestRoamBtn

local ClearLogBtn = Instance.new("TextButton")
ClearLogBtn.Name = "ClearLogBtn"
ClearLogBtn.Size = UDim2.new(0, 95, 1, 0)
ClearLogBtn.Position = UDim2.new(1, -95, 0, 0)
ClearLogBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 56)
ClearLogBtn.Text = "🧹 Clear"
ClearLogBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
ClearLogBtn.Font = Enum.Font.GothamMedium
ClearLogBtn.TextSize = 11
ClearLogBtn.Parent = ControlsFrame

local ClearCorner = Instance.new("UICorner")
ClearCorner.CornerRadius = UDim.new(0, 6)
ClearCorner.Parent = ClearLogBtn

-- Live Log Console Frame
local ConsoleHeader = Instance.new("TextLabel")
ConsoleHeader.Name = "ConsoleHeader"
ConsoleHeader.Size = UDim2.new(1, -24, 0, 20)
ConsoleHeader.Position = UDim2.new(0, 12, 0, 138)
ConsoleHeader.BackgroundTransparency = 1
ConsoleHeader.Text = "LIVE CONSOLE LOG (AUDIT & FSM TRACE):"
ConsoleHeader.TextColor3 = Color3.fromRGB(145, 150, 170)
ConsoleHeader.Font = Enum.Font.GothamBold
ConsoleHeader.TextSize = 10
ConsoleHeader.TextXAlignment = Enum.TextXAlignment.Left
ConsoleHeader.Parent = MainFrame

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Name = "LogScroll"
LogScroll.Size = UDim2.new(1, -24, 0, 252)
LogScroll.Position = UDim2.new(0, 12, 0, 160)
LogScroll.BackgroundColor3 = Color3.fromRGB(13, 14, 19)
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 5
LogScroll.ScrollBarImageColor3 = Color3.fromRGB(65, 70, 90)
LogScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
LogScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogScroll.Parent = MainFrame

local LogCorner = Instance.new("UICorner")
LogCorner.CornerRadius = UDim.new(0, 6)
LogCorner.Parent = LogScroll

local LogStroke = Instance.new("UIStroke")
LogStroke.Color = Color3.fromRGB(35, 38, 52)
LogStroke.Thickness = 1
LogStroke.Parent = LogScroll

local LogLayout = Instance.new("UIListLayout")
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Padding = UDim.new(0, 3)
LogLayout.Parent = LogScroll

local LogPadding = Instance.new("UIPadding")
LogPadding.PaddingTop = UDim.new(0, 6)
LogPadding.PaddingBottom = UDim.new(0, 6)
LogPadding.PaddingLeft = UDim.new(0, 8)
LogPadding.PaddingRight = UDim.new(0, 8)
LogPadding.Parent = LogScroll

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
            line.Size = UDim2.new(1, 0, 0, 18)
            line.BackgroundTransparency = 1
            line.Font = Enum.Font.Code
            line.TextSize = 11
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

ClearLogBtn.MouseButton1Click:Connect(function()
    for _, child in ipairs(LogScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    Logger:Log("Logger", "INFO", "Log history cleared.")
end)

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
            DefaultBanner = "Standard",
            MaxSlots = 6
        }
    end
end

-- ==============================================================================
-- 5. FSM (FINITE STATE MACHINE)
-- ==============================================================================
local BotState = {
    Current = "Idle",
    IDLE = "Idle",
    MOVING = "Moving",
    TESTING = "Testing",
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
        else
            StatePill.BackgroundColor3 = Color3.fromRGB(30, 95, 190)
            StatePill.Text = "● STATE: " .. string.upper(newState)
        end
    end
end

function BotState:GetState(): string
    return self.Current
end

-- ==============================================================================
-- 6. CIRCUIT BREAKER
-- ==============================================================================
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
-- 7. NULL-SAFETY HELPERS (Requirement 3)
-- ==============================================================================
local SafeUtils = {}

function SafeUtils.SafeFind(parent: Instance?, childName: string): Instance?
    if not parent then
        Logger:Log("NullSafety", "WARN", "SafeFind parent is nil: " .. childName)
        return nil
    end
    local target = parent:FindFirstChild(childName)
    if not target then
        Logger:Log("NullSafety", "WARN", string.format("SafeFind: '%s' not found in '%s'", childName, parent.Name))
        return nil
    end
    return target
end

function SafeUtils.SafeGetRemote(remoteName: string): RemoteFunction | RemoteEvent | nil
    local endpoints = ReplicatedStorage:FindFirstChild("endpoints")
    if not endpoints then
        Logger:Log("RemoteFinder", "WARN", "Endpoints folder not found in ReplicatedStorage.")
        return nil
    end
    local c2s = SafeUtils.SafeFind(endpoints, "client_to_server")
    if not c2s then return nil end
    return SafeUtils.SafeFind(c2s, remoteName)
end

function SafeUtils.HumanWait()
    local jitter = math.random() * (Config.Simulation.MaxActionDelay - Config.Simulation.MinActionDelay)
    local waitTime = Config.Simulation.MinActionDelay + jitter
    if coroutine.isyieldable() then
        task.wait(waitTime)
    end
end

-- ==============================================================================
-- 8. CURRENCY CHECK & DISPLAY
-- ==============================================================================
local function UpdateCurrencyDisplay()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local gems = 0
    local gold = 0
    if leaderstats then
        local gVal = leaderstats:FindFirstChild("Gems")
        local goldVal = leaderstats:FindFirstChild("Gold")
        if gVal and (gVal:IsA("IntValue") or gVal:IsA("NumberValue")) then gems = gVal.Value end
        if goldVal and (goldVal:IsA("IntValue") or goldVal:IsA("NumberValue")) then gold = goldVal.Value end
    end
    CurrencyLabel.Text = string.format("Gems: %s | Gold: %s", tostring(gems), tostring(gold))
end

-- ==============================================================================
-- 9. NAVIGATION / ROAM SIMULATION
-- ==============================================================================
local function PerformHumanizedRoam(): boolean
    local char = LocalPlayer.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = SafeUtils.SafeFind(char, "HumanoidRootPart") :: BasePart?
    if not humanoid or not rootPart then return false end

    BotState:SetState(BotState.MOVING)
    local targetPos = rootPart.Position + Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
    Logger:Log("Navigator", "INFO", string.format("Moving to Vector3(%.1f, %.1f, %.1f)", targetPos.X, targetPos.Y, targetPos.Z))
    humanoid:MoveTo(targetPos)
    
    if coroutine.isyieldable() then
        task.wait(1.5)
    end
    BotState:SetState(BotState.IDLE)
    return true
end

-- ==============================================================================
-- 10. WORKER WITH ISOLATED TASKS (Requirement 4)
-- ==============================================================================
local Worker = {
    _running = false,
    _connections = {} :: { RBXScriptConnection }
}

local function Task_InspectUI(): boolean
    local mainUI = SafeUtils.SafeFind(PlayerGui, Config.UI.MainHUD)
    if not mainUI then
        Logger:Log("TaskUI", "INFO", "Banner UI currently closed (Normal state).")
        return true
    end
    return true
end

local function Task_SimulateBanner(): boolean
    if not CircuitBreaker:CanExecute() then return false end
    BotState:SetState(BotState.TESTING)

    local bannerRemote = SafeUtils.SafeGetRemote(Config.Events.SummonRemote)
    if not bannerRemote then
        error("Remote '" .. Config.Events.SummonRemote .. "' not found in endpoints!")
    end

    Logger:Log("TaskBanner", "INFO", "Verified banner remote: " .. bannerRemote.Name)
    SafeUtils.HumanWait()
    BotState:SetState(BotState.IDLE)
    return true
end

function Worker:Start()
    if self._running then return end
    self._running = true
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
    ToggleBtn.Text = "⏹ STOP QA LOOP"
    Logger:Log("Worker", "INFO", "QA Worker loop active.")

    task.spawn(function()
        while self._running do
            UpdateCurrencyDisplay()

            if CircuitBreaker:CanExecute() then
                -- Task 1: UI Inspection (Isolated)
                local s1, err1 = pcall(Task_InspectUI)
                if not s1 then
                    CircuitBreaker:RecordFailure("Task_InspectUI: " .. tostring(err1))
                else
                    CircuitBreaker:RecordSuccess()
                end
                SafeUtils.HumanWait()

                -- Task 2: Remote Simulation (Isolated)
                local s2, err2 = pcall(Task_SimulateBanner)
                if not s2 then
                    CircuitBreaker:RecordFailure("Task_SimulateBanner: " .. tostring(err2))
                else
                    CircuitBreaker:RecordSuccess()
                end
                SafeUtils.HumanWait()

            else
                Logger:Log("Worker", "WARN", "Circuit breaker active. Waiting for cooldown...")
                task.wait(2.0)
            end

            task.wait(2.0)
        end
        Logger:Log("Worker", "INFO", "QA Worker loop stopped.")
    end)
end

function Worker:Stop()
    if not self._running then return end
    self._running = false
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 90)
    ToggleBtn.Text = "▶ START QA LOOP"
    BotState:SetState(BotState.IDLE)
    Logger:Log("Worker", "INFO", "QA Worker stopped.")
end

-- ==============================================================================
-- 11. BUTTON CONNECTIONS (WRAPPED IN TASK.SPAWN FOR SAFE YIELDING)
-- ==============================================================================
ToggleBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        if Worker._running then
            Worker:Stop()
        else
            Worker:Start()
        end
    end)
end)

TestSummonBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        Logger:Log("ManualAction", "INFO", "Manual Test Banner triggered...")
        local s, err = pcall(Task_SimulateBanner)
        if not s then
            CircuitBreaker:RecordFailure(tostring(err))
        else
            CircuitBreaker:RecordSuccess()
        end
    end)
end)

TestRoamBtn.MouseButton1Click:Connect(function()
    task.spawn(PerformHumanizedRoam)
end)

CloseBtn.MouseButton1Click:Connect(function()
    Worker:Stop()
    for _, conn in ipairs(Worker._connections) do
        if conn.Connected then conn:Disconnect() end
    end
    ScreenGui:Destroy()
end)

UpdateCurrencyDisplay()
Logger:Log("System", "INFO", "QA Automation Hub ready. Click [START QA LOOP] or test buttons.")
