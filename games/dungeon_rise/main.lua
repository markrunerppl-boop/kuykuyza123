--[[
    ================================================================================
    [PREMIUM ROBLOX QA AUTOMATION & NPC CONTROLLER - DUNGEON RISE PRO EDITION]
    Target Game: ดันเจี้ยนลุกขึ้น (Dungeon Rise / Solo Leveling) - CL GAMES!
    Universe ID: 7074860883 | Supported Places: All Worlds (World 1, 2, 3...)
    Repository: markrunerppl-boop/kuykuyza123
    Loader: loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/script.lua"))()
    ================================================================================
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- Parent GUI resolution
local parentGui = nil
pcall(function()
    if typeof(gethui) == "function" then
        parentGui = gethui()
    elseif game:GetService("CoreGui") then
        parentGui = game:GetService("CoreGui")
    end
end)
if not parentGui then parentGui = PlayerGui end

-- ============================================================================
-- 0. STRUCTURED LOGGING & AUDIT LOGGER (ระบบบันทึกประวัติการทำงาน)
-- ============================================================================
local AuditLogger = {
    History = {},
    MaxRecords = 50,
    Stats = {
        StartTime = os.time(),
        EnemiesDefeated = 0,
        ShadowsArised = 0,
        AttacksFired = 0,
        QuestsClaimed = 0,
        GiftsClaimed = 0,
        DungeonsJoined = 0
    },
    OnLogged = nil -- UI Hook
}

function AuditLogger.Record(category, action, detail)
    local timestamp = os.date("%H:%M:%S")
    local entry = {
        Time = timestamp,
        Category = category,
        Action = action,
        Detail = detail or ""
    }
    table.insert(AuditLogger.History, 1, entry)
    if #AuditLogger.History > AuditLogger.MaxRecords then
        table.remove(AuditLogger.History)
    end

    print(string.format("[%s] [%s] %s: %s", timestamp, string.upper(category), action, tostring(detail)))
    if AuditLogger.OnLogged then
        pcall(AuditLogger.OnLogged, entry)
    end
end

-- ============================================================================
-- 1. CENTRALIZED STRING CONSTANTS & CONFIGURATION
-- ============================================================================
local Config = {
    Tag = "DungeonRiseQA_Pro",
    ConfigFile = "DungeonRise_Config_V1.json",

    Bridges = {
        General = "GENERAL_EVENT",
        Enemy = "ENEMY_EVENT",
        Pet = "PET_EVENT",
        Dungeon = "DUNGEON_EVENT",
        Warn = "WARN_EVENT",
        Cutscene = "CUTSCENE_EVENT"
    },

    Events = {
        PunchAttack = "PunchAttack",
        PunchAttackAoE = "PunchAttackAoE",
        EnemyCapture = "EnemyCapture",
        EnemyDestroy = "EnemyDestroy",
        EquipBest = "EquipBest",
        UnequipAll = "UnequipAll",
        ClaimQuest = "ClaimQuest",
        ClaimGift = "ClaimGift",
        WorldTeleport = "WorldTeleport",
        InfiniteModeAction = "InfiniteModeAction",
        CastleAction = "CastleAction",
        DungeonAction = "DungeonAction"
    },

    Automation = {
        AutoAttack = true,        -- โจมตีมอนสเตอร์ด้วยอาวุธ M1
        AutoShadowArmy = true,    -- สั่งกองทัพเงาโจมตี (Auto Send Pets)
        AutoArise = true,         -- สกัดเงาอัตโนมัติ (Arise EnemyCapture)
        AutoTargetMove = false,   -- วิ่ง/วาปเข้าหามอนสเตอร์ที่ใกล้ที่สุด
        AutoEquipBestPets = true, -- สวมใส่เงาที่ดีที่สุด (Equip Best)
        AutoClaimQuests = true,   -- รับเควสต์ประจำวัน/สัปดาห์
        AutoClaimGifts = true,    -- รับของขวัญฟรีตามเวลา
        AutoInfinite = false,     -- ลงโหมด Infinite อัตโนมัติ
        AntiAFK = true
    },

    Delays = {
        FastLoop = 0.08,
        SlowLoop = 3.0,
        TargetSearchRadius = 300,
        KitingDistance = 8,
        HumanJitterMin = 0.05,
        HumanJitterMax = 0.12
    }
}

-- ============================================================================
-- 2. SAFE MODULE LOADING & BRIDGENET2 RESOLUTION
-- ============================================================================
local function SafeRequire(parent, pathTable, moduleName)
    local ok, res = pcall(function()
        if not parent then return nil end
        local curr = parent
        for _, segment in ipairs(pathTable) do
            curr = curr:FindFirstChild(segment)
            if not curr then return nil end
        end
        local mod = curr:FindFirstChild(moduleName)
        if not mod or not mod:IsA("ModuleScript") then return nil end
        return require(mod)
    end)
    return (ok and res) or nil
end

local SharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
local BridgeNet2 = SafeRequire(ReplicatedStorage, {}, "BridgeNet2")
local WeaponsModule = SafeRequire(SharedModules, {}, "WeaponsModule")
local PetsController = SafeRequire(SharedModules, {"Pets"}, "PetsController")
local ButtonsModule = SafeRequire(SharedModules, {}, "ButtonsModule")
local ExtraFunctions = SafeRequire(SharedModules, {}, "ExtraFunctions")
local DamageFunctions = SafeRequire(SharedModules, {}, "DamageFunctions")
local PetsService = SafeRequire(SharedModules, {}, "PetsService")

-- Resolve Bridges Safely
local Bridges = {}
if BridgeNet2 and typeof(BridgeNet2.ReferenceBridge) == "function" then
    for key, bridgeName in pairs(Config.Bridges) do
        local ok, bridge = pcall(function() return BridgeNet2.ReferenceBridge(bridgeName) end)
        if ok and bridge then
            Bridges[key] = bridge
        end
    end
end

-- Circuit Breaker Registry
local CircuitBreaker = {
    Threshold = 3,
    Cooldown = 15,
    Registry = {}
}

function CircuitBreaker.RecordSuccess(taskKey)
    if CircuitBreaker.Registry[taskKey] then
        CircuitBreaker.Registry[taskKey].Errors = 0
        CircuitBreaker.Registry[taskKey].Tripped = false
    end
end

function CircuitBreaker.RecordFailure(taskKey, errorMsg)
    if not CircuitBreaker.Registry[taskKey] then
        CircuitBreaker.Registry[taskKey] = { Errors = 0, Tripped = false, LastTripTime = 0 }
    end
    local rec = CircuitBreaker.Registry[taskKey]
    rec.Errors = rec.Errors + 1
    if rec.Errors >= CircuitBreaker.Threshold then
        rec.Tripped = true
        rec.LastTripTime = tick()
        AuditLogger.Record("CircuitBreaker", "Tripped", string.format("Task '%s' พัก 15 วิ เนื่องจากล้มเหลวติดกัน", taskKey))
    end
end

function CircuitBreaker.IsAvailable(taskKey)
    local rec = CircuitBreaker.Registry[taskKey]
    if not rec or not rec.Tripped then return true end
    if tick() - rec.LastTripTime >= CircuitBreaker.Cooldown then
        rec.Tripped = false
        rec.Errors = 0
        return true
    end
    return false
end

-- ============================================================================
-- 3. STATE MANAGEMENT (FSM) & HELPERS
-- ============================================================================
local BotFSM = {
    States = {
        IDLE = "IDLE",
        COMBAT = "COMBAT",
        ARISE_CAPTURE = "ARISE_CAPTURE",
        DUNGEON = "DUNGEON",
        UPGRADING = "UPGRADING"
    },
    Current = "IDLE"
}

function BotFSM.SetState(newState, reason)
    if BotFSM.Current ~= newState then
        BotFSM.Current = newState
    end
end

local State = {
    Running = true,
    TargetEnemy = nil,
    StatusText = "บอทพร้อมทำงาน",
    Connections = {}
}

-- Cleanup of previous running instance
if _G.DungeonRiseCleanup then
    pcall(_G.DungeonRiseCleanup)
end

local function HumanWait(minSec, maxSec)
    local minT = minSec or Config.Delays.HumanJitterMin
    local maxT = maxSec or Config.Delays.HumanJitterMax
    task.wait(minT + math.random() * (maxT - minT))
end

local function SafeGetCharacter()
    local char = LocalPlayer.Character
    if not char or not char.Parent then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local function SafeFind(parent, childName, recursive)
    if not parent then return nil end
    local ok, res = pcall(function() return parent:FindFirstChild(childName, recursive or false) end)
    return (ok and res) or nil
end

-- ============================================================================
-- 4. CONFIG PERSISTENCE (JSON Save/Load)
-- ============================================================================
local function SaveConfig()
    pcall(function()
        if writefile then
            local payload = { Automation = Config.Automation }
            writefile(Config.ConfigFile, HttpService:JSONEncode(payload))
            AuditLogger.Record("Config", "Saved", "บันทึกการตั้งค่าลง " .. Config.ConfigFile)
        end
    end)
end

local function LoadConfig()
    pcall(function()
        if isfile and readfile and isfile(Config.ConfigFile) then
            local raw = readfile(Config.ConfigFile)
            local data = HttpService:JSONDecode(raw)
            if type(data) == "table" and type(data.Automation) == "table" then
                for k, v in pairs(data.Automation) do
                    if Config.Automation[k] ~= nil then Config.Automation[k] = v end
                end
                AuditLogger.Record("Config", "Loaded", "โหลดการตั้งค่าสำเร็จ")
            end
        end
    end)
end
LoadConfig()

-- ============================================================================
-- 5. GAME TARGETING & COMBAT ACTIONS
-- ============================================================================
local function GetServerEnemiesFolder()
    local main = Workspace:FindFirstChild("__Main")
    local enemies = main and main:FindFirstChild("__Enemies")
    return enemies and enemies:FindFirstChild("Server")
end

local function GetClientEnemiesFolder()
    local main = Workspace:FindFirstChild("__Main")
    local enemies = main and main:FindFirstChild("__Enemies")
    return enemies and enemies:FindFirstChild("Client")
end

local function FindNearestEnemy()
    local _, root = SafeGetCharacter()
    if not root then return nil, math.huge end
    local folder = GetServerEnemiesFolder()
    if not folder then return nil, math.huge end

    local nearest, minDist = nil, Config.Delays.TargetSearchRadius
    for _, e in ipairs(folder:GetChildren()) do
        if e:GetAttribute("Dead") ~= true and e:GetAttribute("Shield") ~= true then
            local dist = (e.Position - root.Position).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = e
            end
        end
    end
    return nearest, minDist
end

local function ExecuteAttack(target)
    if not target then return end
    local enemyBridge = Bridges.Enemy

    -- 1. Direct Punch Attack via BridgeNet2
    if enemyBridge then
        pcall(function()
            enemyBridge:Fire({
                Event = Config.Events.PunchAttack,
                Enemy = target.Name
            })
            AuditLogger.Stats.AttacksFired = AuditLogger.Stats.AttacksFired + 1
        end)
    end

    -- 2. WeaponsModule Click trigger
    if WeaponsModule and typeof(WeaponsModule.Click) == "function" then
        pcall(function()
            WeaponsModule.Click({ KeyCode = Enum.KeyCode.ButtonX }, false, nil, true)
        end)
    end
end

local function ExecuteShadowArmy(target)
    if not target then return end
    if PetsController and typeof(PetsController.AutoEnemy) == "function" then
        pcall(function()
            PetsController.AutoEnemy(target)
        end)
    end
end

local function ExecuteAriseCapture()
    local clientFolder = GetClientEnemiesFolder()
    local enemyBridge = Bridges.Enemy
    if not clientFolder or not enemyBridge then return end

    local _, root = SafeGetCharacter()
    for _, enemyModel in ipairs(clientFolder:GetChildren()) do
        -- Dead enemy waiting for Arise Extraction
        local hasArise = enemyModel:GetAttribute("Arise") ~= nil or enemyModel:FindFirstChild("Arise") ~= nil
        local isDead = enemyModel:GetAttribute("Dead") == true
        if hasArise or isDead then
            pcall(function()
                enemyBridge:Fire({
                    Event = Config.Events.EnemyCapture,
                    Enemy = enemyModel
                })
                AuditLogger.Stats.ShadowsArised = AuditLogger.Stats.ShadowsArised + 1
                AuditLogger.Record("ShadowArmy", "Arise!", "สกัดเงาสำเร็จ: " .. enemyModel.Name)
            end)
            HumanWait(0.1, 0.2)
        end
    end
end

local function ExecuteEquipBest()
    if ButtonsModule and typeof(ButtonsModule.PetsButtons) == "function" then
        pcall(function()
            ButtonsModule.PetsButtons("None", { Action = "PetAction", Type = "EquipBest" })
            AuditLogger.Record("Shadows", "EquipBest", "ติดตั้งเงาที่ดีที่สุดเรียบร้อย")
        end)
    elseif Bridges.Pet then
        pcall(function()
            Bridges.Pet:Fire({ Event = Config.Events.EquipBest })
        end)
    end
end

local function ExecuteClaimQuests()
    local generalBridge = Bridges.General
    if not generalBridge then return end

    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local questsFolder = ls and ls:FindFirstChild("Quests")
    if questsFolder then
        for _, qType in ipairs(questsFolder:GetChildren()) do
            for _, qItem in ipairs(qType:GetChildren()) do
                if qItem:GetAttribute("Completed") == true then
                    pcall(function()
                        generalBridge:Fire({
                            Event = Config.Events.ClaimQuest,
                            Id = qItem.Name,
                            Type = qType.Name
                        })
                        AuditLogger.Stats.QuestsClaimed = AuditLogger.Stats.QuestsClaimed + 1
                        AuditLogger.Record("Quests", "Claimed", "รับรางวัลเควสต์ " .. qItem.Name)
                    end)
                    HumanWait(0.15, 0.3)
                end
            end
        end
    end
end

local function ExecuteClaimGifts()
    local generalBridge = Bridges.General
    if not generalBridge then return end

    for giftId = 1, 12 do
        pcall(function()
            generalBridge:Fire({
                Event = Config.Events.ClaimGift,
                Id = giftId
            })
        end)
    end
end

-- ============================================================================
-- 6. WORKER ENGINE (Isolated Execution Loops with Circuit Breakers)
-- ============================================================================

-- Fast Combat Worker Thread
task.spawn(function()
    while State.Running do
        local _, root, hum = SafeGetCharacter()

        if root and hum and hum.Health > 0 then
            local target, dist = FindNearestEnemy()
            State.TargetEnemy = target

            if target then
                BotFSM.SetState(BotFSM.States.COMBAT, "Fighting Target")
                State.StatusText = string.format("โจมตีเป้าหมาย: %s (ระยะ %.1fm)", target.Name, dist)

                -- 1. Auto Attack with Weapon
                if Config.Automation.AutoAttack and CircuitBreaker.IsAvailable("Attack") then
                    local ok, err = pcall(function() ExecuteAttack(target) end)
                    if ok then CircuitBreaker.RecordSuccess("Attack") else CircuitBreaker.RecordFailure("Attack", err) end
                end

                -- 2. Auto Send Shadow Army
                if Config.Automation.AutoShadowArmy and CircuitBreaker.IsAvailable("ShadowArmy") then
                    local ok, err = pcall(function() ExecuteShadowArmy(target) end)
                    if ok then CircuitBreaker.RecordSuccess("ShadowArmy") else CircuitBreaker.RecordFailure("ShadowArmy", err) end
                end

                -- 3. Auto Target Movement / Kiting
                if Config.Automation.AutoTargetMove and dist > Config.Delays.KitingDistance then
                    pcall(function()
                        local targetPos = target.Position
                        local dir = (root.Position - targetPos).Unit
                        local standPos = targetPos + (dir * Config.Delays.KitingDistance)
                        root.CFrame = CFrame.new(standPos, targetPos)
                        root.AssemblyLinearVelocity = Vector3.zero
                    end)
                end
            else
                BotFSM.SetState(BotFSM.States.IDLE, "No Target Found")
                State.StatusText = "ค้นหาเป้าหมายมอนสเตอร์รอบตัว..."
            end

            -- 4. Auto Arise Extraction
            if Config.Automation.AutoArise and CircuitBreaker.IsAvailable("Arise") then
                local ok, err = pcall(ExecuteAriseCapture)
                if ok then CircuitBreaker.RecordSuccess("Arise") else CircuitBreaker.RecordFailure("Arise", err) end
            end
        end

        task.wait(Config.Delays.FastLoop)
    end
end)

-- Slow Progression Worker Thread
task.spawn(function()
    while State.Running do
        pcall(function()
            -- Equip Best Shadows
            if Config.Automation.AutoEquipBestPets and CircuitBreaker.IsAvailable("EquipBest") then
                ExecuteEquipBest()
            end

            -- Claim Completed Quests
            if Config.Automation.AutoClaimQuests and CircuitBreaker.IsAvailable("ClaimQuests") then
                ExecuteClaimQuests()
            end

            -- Claim Free Gifts
            if Config.Automation.AutoClaimGifts and CircuitBreaker.IsAvailable("ClaimGifts") then
                ExecuteClaimGifts()
            end
        end)

        task.wait(Config.Delays.SlowLoop)
    end
end)

-- Anti-AFK Handler
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if Config.Automation.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
            AuditLogger.Record("System", "Anti-AFK", "ป้องกันการหลุดจากการอยู่นิ่ง")
        end)
    end
end)

-- ============================================================================
-- 7. TABBED MODERN USER INTERFACE & MINIMIZE CONTROLLER
-- ============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DungeonRiseQAGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = parentGui

-- Floating Quick-Access Pill (เมื่อย่อหน้าต่าง)
local FloatingPill = Instance.new("TextButton")
FloatingPill.Name = "FloatingPill"
FloatingPill.Size = UDim2.new(0, 180, 0, 36)
FloatingPill.Position = UDim2.new(0.5, -90, 0, 15)
FloatingPill.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
FloatingPill.BorderSizePixel = 0
FloatingPill.Text = "⚡ Dungeon Rise QA (เปิด)"
FloatingPill.Font = Enum.Font.GothamBold
FloatingPill.TextSize = 12
FloatingPill.TextColor3 = Color3.fromRGB(0, 230, 255)
FloatingPill.Visible = false
FloatingPill.Active = true
FloatingPill.Draggable = true
FloatingPill.Parent = ScreenGui

local PillCorner = Instance.new("UICorner")
PillCorner.CornerRadius = UDim.new(1, 0)
PillCorner.Parent = FloatingPill

local PillStroke = Instance.new("UIStroke")
PillStroke.Thickness = 1.5
PillStroke.Color = Color3.fromRGB(0, 170, 255)
PillStroke.Parent = FloatingPill

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 370)
MainFrame.Position = UDim2.new(0.5, -260, 0.25, -185)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(45, 52, 75)
MainStroke.Parent = MainFrame

-- Top Bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 10)
TopCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "⚡ DUNGEON RISE QA CONTROLLER (PRO)"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Size = UDim2.new(0, 280, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = TopBar

-- Minimize Button [-]
local MinBtn = Instance.new("TextButton")
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -62, 0, 6)
MinBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 56)
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TopBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent = MinBtn

-- Close Button [✕]
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = Color3.fromRGB(220, 150, 150)
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0, 6)
CloseBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 35)
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseBtn

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatingPill.Visible = true
end)

FloatingPill.MouseButton1Click:Connect(function()
    FloatingPill.Visible = false
    MainFrame.Visible = true
end)

-- Sidebar Navigation
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -38)
Sidebar.Position = UDim2.new(0, 0, 0, 38)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 21, 30)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 4)
SideLayout.Parent = Sidebar

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop = UDim.new(0, 8)
SidePad.PaddingLeft = UDim.new(0, 8)
SidePad.PaddingRight = UDim.new(0, 8)
SidePad.Parent = Sidebar

-- Pages Container
local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -135, 1, -44)
PagesContainer.Position = UDim2.new(0, 133, 0, 40)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame

local Pages = {}
local TabButtons = {}

local function CreatePage(pageName)
    local page = Instance.new("ScrollingFrame")
    page.Name = pageName .. "Page"
    page.Size = UDim2.new(1, -6, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(60, 68, 95)
    page.CanvasSize = UDim2.new(0, 0, 0, 600)
    page.Visible = false
    page.Parent = PagesContainer

    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = page

    Pages[pageName] = page
    return page
end

local function SwitchTab(tabName)
    for name, page in pairs(Pages) do
        page.Visible = (name == tabName)
    end
    for name, btn in pairs(TabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = Color3.fromRGB(0, 140, 230)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
            btn.TextColor3 = Color3.fromRGB(160, 170, 190)
        end
    end
end

local function AddTab(name, icon, pageName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(160, 170, 190)
    btn.Text = icon .. " " .. name
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = Sidebar

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 10)
    p.Parent = btn

    TabButtons[pageName] = btn
    btn.MouseButton1Click:Connect(function() SwitchTab(pageName) end)
end

-- Create Pages
local CombatPage = CreatePage("Combat")
local ShadowsPage = CreatePage("Shadows")
local QuestsPage = CreatePage("Quests")
local LogsPage = CreatePage("Logs")
local SettingsPage = CreatePage("Settings")

-- Register Tabs
AddTab("การต่อสู้", "⚔️", "Combat")
AddTab("กองทัพเงา", "👥", "Shadows")
AddTab("เควสต์ & ของขวัญ", "🎁", "Quests")
AddTab("บันทึกการทำงาน", "📊", "Logs")
AddTab("ตั้งค่าระบบ", "⚙️", "Settings")

local function AddToggleTo(page, text, initVal, onChange)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -6, 0, 32)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local active = initVal
    local function Refresh()
        if active then
            btn.BackgroundColor3 = Color3.fromRGB(35, 135, 75)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Text = "🟢 " .. text .. " : [เปิด]"
        else
            btn.BackgroundColor3 = Color3.fromRGB(28, 32, 46)
            btn.TextColor3 = Color3.fromRGB(150, 160, 180)
            btn.Text = "⚪ " .. text .. " : [ปิด]"
        end
    end
    Refresh()

    btn.MouseButton1Click:Connect(function()
        active = not active
        Refresh()
        onChange(active)
        SaveConfig()
        AuditLogger.Record("Settings", "Toggle", text .. " -> " .. (active and "เปิด" or "ปิด"))
    end)
end

local function AddButtonTo(page, text, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -6, 0, 30)
    btn.BackgroundColor3 = color or Color3.fromRGB(38, 44, 62)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Parent = page

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(onClick)
end

-- [COMBAT TAB]
AddToggleTo(CombatPage, "โจมตีอัตโนมัติด้วยอาวุธ (Auto Weapon Attack)", Config.Automation.AutoAttack, function(v) Config.Automation.AutoAttack = v end)
AddToggleTo(CombatPage, "ส่งกองทัพเงาโจมตี (Auto Send Shadows)", Config.Automation.AutoShadowArmy, function(v) Config.Automation.AutoShadowArmy = v end)
AddToggleTo(CombatPage, "เคลื่อนที่เข้าหาเป้าหมาย (Auto Target Move)", Config.Automation.AutoTargetMove, function(v) Config.Automation.AutoTargetMove = v end)
AddButtonTo(CombatPage, "🗡️ โจมตีเป้าหมายทันที (Manual Hit)", Color3.fromRGB(40, 130, 80), function()
    local target = FindNearestEnemy()
    if target then ExecuteAttack(target) end
end)

-- [SHADOWS TAB]
AddToggleTo(ShadowsPage, "สกัดเงาอัตโนมัติเมื่อมอนตาย (Auto Arise)", Config.Automation.AutoArise, function(v) Config.Automation.AutoArise = v end)
AddToggleTo(ShadowsPage, "สวมใส่เงาที่ดีที่สุด (Auto Equip Best Shadows)", Config.Automation.AutoEquipBestPets, function(v) Config.Automation.AutoEquipBestPets = v end)
AddButtonTo(ShadowsPage, "👑 ติดตั้งเงาที่ดีที่สุดทันที (Equip Best Now)", Color3.fromRGB(35, 120, 180), function()
    ExecuteEquipBest()
end)

-- [QUESTS TAB]
AddToggleTo(QuestsPage, "รับรางวัลเควสต์อัตโนมัติ (Auto Claim Quests)", Config.Automation.AutoClaimQuests, function(v) Config.Automation.AutoClaimQuests = v end)
AddToggleTo(QuestsPage, "รับของขวัญเล่นเกมฟรี (Auto Claim Gifts)", Config.Automation.AutoClaimGifts, function(v) Config.Automation.AutoClaimGifts = v end)
AddButtonTo(QuestsPage, "🎁 กดรับของขวัญทั้งหมดทันที", Color3.fromRGB(150, 90, 30), function()
    ExecuteClaimGifts()
    ExecuteClaimQuests()
end)

-- [LOGS TAB & REAL-TIME STATS]
local StatsBox = Instance.new("Frame")
StatsBox.Size = UDim2.new(1, -6, 0, 52)
StatsBox.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
StatsBox.BorderSizePixel = 0
StatsBox.Parent = LogsPage

local StatsBoxCorner = Instance.new("UICorner")
StatsBoxCorner.CornerRadius = UDim.new(0, 6)
StatsBoxCorner.Parent = StatsBox

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Size = UDim2.new(1, -12, 1, 0)
StatsLabel.Position = UDim2.new(0, 8, 0, 0)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Font = Enum.Font.GothamMedium
StatsLabel.TextSize = 10
StatsLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.Text = "📊 สถิติรอบนี้: กำลังประมวลผล..."
StatsLabel.Parent = StatsBox

task.spawn(function()
    while State.Running do
        pcall(function()
            StatsLabel.Text = string.format("📊 โจมตี: %d ครั้ง | สกัดเงา: %d ตัว | เควสต์: %d รายการ | ของขวัญ: %d ชิ้น\n⏱️ เวลาทำงาน: %d วิ | สถานะ: %s",
                AuditLogger.Stats.AttacksFired, AuditLogger.Stats.ShadowsArised, AuditLogger.Stats.QuestsClaimed, AuditLogger.Stats.GiftsClaimed,
                os.time() - AuditLogger.Stats.StartTime, State.StatusText)
        end)
        task.wait(0.5)
    end
end)

local LogContainer = Instance.new("ScrollingFrame")
LogContainer.Size = UDim2.new(1, -6, 0, 230)
LogContainer.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
LogContainer.BorderSizePixel = 0
LogContainer.ScrollBarThickness = 2
LogContainer.CanvasSize = UDim2.new(0, 0, 0, 1000)
LogContainer.Parent = LogsPage

local LogLayout = Instance.new("UIListLayout")
LogLayout.Padding = UDim.new(0, 3)
LogLayout.Parent = LogContainer

local function RefreshLogUI()
    for _, item in ipairs(LogContainer:GetChildren()) do
        if item:IsA("TextLabel") then item:Destroy() end
    end
    for _, entry in ipairs(AuditLogger.History) do
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -8, 0, 18)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.Gotham
        l.TextSize = 9
        l.TextColor3 = Color3.fromRGB(180, 195, 215)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = string.format("[%s] [%s] %s: %s", entry.Time, entry.Category, entry.Action, entry.Detail)
        l.Parent = LogContainer
    end
end

AuditLogger.OnLogged = function()
    RefreshLogUI()
end

AddButtonTo(LogsPage, "🗑️ ล้างประวัติการบันทึก (Clear Logs)", Color3.fromRGB(60, 35, 40), function()
    table.clear(AuditLogger.History)
    RefreshLogUI()
end)

-- [SETTINGS TAB]
AddToggleTo(SettingsPage, "ป้องกันการหลุดจากการอยู่นิ่ง (Anti-AFK)", Config.Automation.AntiAFK, function(v) Config.Automation.AntiAFK = v end)
AddButtonTo(SettingsPage, "💾 บันทึกการตั้งค่าเดี๋ยวนี้ (Save Config)", Color3.fromRGB(40, 120, 180), function() SaveConfig() end)
AddButtonTo(SettingsPage, "🔄 โหลดการตั้งค่าจากไฟล์ (Reload Config)", Color3.fromRGB(50, 60, 90), function() LoadConfig() end)
AddButtonTo(SettingsPage, "⚠️ รีเซ็ตกลับเป็นค่าเริ่มต้น (Reset Defaults)", Color3.fromRGB(120, 40, 40), function()
    for k, _ in pairs(Config.Automation) do Config.Automation[k] = true end
    SaveConfig()
    AuditLogger.Record("Settings", "Reset", "รีเซ็ตการตั้งค่าเป็นค่าเริ่มต้น")
end)

SwitchTab("Combat")

-- ============================================================================
-- 8. CLEANUP & SHUTDOWN HANDLER
-- ============================================================================
local function Cleanup()
    State.Running = false
    AuditLogger.Record("System", "Shutdown", "ทำความสะอาด GUI และยุติกระบวนการ")
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() FloatingPill:Destroy() end)
    _G.DungeonRiseCleanup = nil
end

_G.DungeonRiseCleanup = Cleanup
CloseBtn.MouseButton1Click:Connect(Cleanup)

AuditLogger.Record("Loader", "Ready", "Dungeon Rise QA Automation พร้อมทำงานเรียบร้อย!")
