--[[
    ================================================================================
    [PREMIUM ROBLOX QA AUTOMATION & NPC CONTROLLER - DUNGEON RISE PRO V2]
    Target Game: ดันเจี้ยนลุกขึ้น (Dungeon Rise / Solo Leveling) - CL GAMES!
    Universe ID: 7074860883 | Supported Places: All Worlds (World 1, 2, 3...)
    Repository: markrunerppl-boop/kuykuyza123
    Loader: loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/script.lua"))()

    Features Implemented:
    [✓] Non-Kick Humanized Smooth Approach (Humanoid:MoveTo - No teleport kicks)
    [✓] Unlimited Infinite Dungeon Looping (Continuous Auto Re-run until keys depleted)
    [✓] Full Catalog of All Dungeons & Keys in Game (Normal Key, Fairy, DS, Solo2, etc.)
    [✓] Unlimited Tower & Castle Automation (Infernal Castle, Infinite Castle, Labyrinth, etc.)
    [✓] Specific Floor / Wave Targeting & Endless Replay on Finish
    [✓] 55 Shadow Army Automated Command & Auto Arise Extraction
    [✓] Modern Tabbed Dashboard UI with Minimize Pill & Live Audit Logging
    ================================================================================
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

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
        DungeonsCleared = 0,
        TowerFloorsCleared = 0,
        ShadowsArised = 0,
        AttacksFired = 0,
        QuestsClaimed = 0,
        GiftsClaimed = 0
    },
    OnLogged = nil
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
    Tag = "DungeonRiseQA_Pro_V2",
    ConfigFile = "DungeonRise_Config_V2.json",

    Bridges = {
        General = "GENERAL_EVENT",
        Enemy = "ENEMY_EVENT",
        Pet = "PET_EVENT",
        Dungeon = "DUNGEON_EVENT"
    },

    Events = {
        PunchAttack = "PunchAttack",
        PunchAttackAoE = "PunchAttackAoE",
        EnemyCapture = "EnemyCapture",
        EnemyDestroy = "EnemyDestroy",
        EquipBest = "EquipBest",
        ClaimQuest = "ClaimQuest",
        ClaimGift = "ClaimGift",
        DungeonAction = "DungeonAction",
        DungeonKeyAction = "DungeonKeyAction",
        CastleAction = "CastleAction",
        InfiniteCastleAction = "InfiniteCastleAction",
        InfiniteLabyrinthAction = "InfiniteLabyrinthAction",
        InfiniteModeAction = "InfiniteModeAction"
    },

    Automation = {
        AutoAttack = true,              -- โจมตีด้วยอาวุธ M1
        AutoShadowArmy = true,          -- สั่งกองทัพเงา 55 ตัวโจมตี
        AutoArise = true,               -- สกัดเงาอัตโนมัติ (Arise)
        SmoothApproach = true,          -- เคลื่อนที่เข้าหาเป้าหมายแบบสมูท (ไม่โดนเตะ)
        AutoEquipBestPets = true,       -- สวมใส่เงาที่ดีที่สุด

        -- Dungeon Automation
        AutoDungeon = false,            -- ออโต้ลงดันเจี้ยน
        SelectedKey = "Key",            -- กุญแจที่เลือก (เช่น "Key", "FairyKey", "Solo2Key", "DSKey")
        LoopDungeonUntilGone = true,    -- ลงซ้ำเรื่อยๆ จนกว่ากุญแจจะหมด

        -- Tower / Castle Automation
        AutoTower = false,              -- ออโต้ลงหอคอย
        TowerMode = "Castle",           -- "Castle" (Infernal), "InfiniteCastle", "InfiniteLabyrinth", "InfiniteMode"
        TargetFloor = 950,              -- ชั้นที่ต้องการระบุลงซ้ำ
        RepeatTargetFloor = true,       -- ลงซ้ำชั้นเดิมเรื่อยๆ
        AutoSpeedUp = true,             -- เร่งความเร็วหอคอยอัตโนมัติ

        -- Quests & Misc
        AutoClaimQuests = true,
        AutoClaimGifts = true,
        AntiAFK = true
    },

    Delays = {
        FastLoop = 0.08,
        SlowLoop = 2.5,
        CombatRange = 16.0,             -- รักษาระยะ 16 studs เพื่อหลบและโจมตี
        MaxApproachDistance = 350
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

local Bridges = {}
if BridgeNet2 and typeof(BridgeNet2.ReferenceBridge) == "function" then
    for key, bridgeName in pairs(Config.Bridges) do
        local ok, bridge = pcall(function() return BridgeNet2.ReferenceBridge(bridgeName) end)
        if ok and bridge then Bridges[key] = bridge end
    end
end

-- Circuit Breaker Registry
local CircuitBreaker = {
    Threshold = 3,
    Cooldown = 12,
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
        AuditLogger.Record("CircuitBreaker", "Tripped", string.format("Task '%s' พัก 12 วิ เพื่อความปลอดภัย", taskKey))
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
-- 3. STATE & HELPERS
-- ============================================================================
local State = {
    Running = true,
    TargetEnemy = nil,
    InDungeonInstance = false,
    InTowerInstance = false,
    LastDungeonAttempt = 0,
    LastTowerAttempt = 0,
    StatusText = "บอทพร้อมทำงาน"
}

if _G.DungeonRiseCleanup then pcall(_G.DungeonRiseCleanup) end

local function SafeGetCharacter()
    local char = LocalPlayer.Character
    if not char or not char.Parent then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

local function GetKeyCount(keyName)
    local items = LocalPlayer.leaderstats:FindFirstChild("Inventory") and LocalPlayer.leaderstats.Inventory:FindFirstChild("Items")
    if not items then return 0 end
    local item = items:FindFirstChild(keyName)
    return (item and item:GetAttribute("Amount")) or (item and 1) or 0
end

-- ============================================================================
-- 4. CONFIG PERSISTENCE
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
-- 5. COMBAT & NON-KICK SMOOTH MOVEMENT ENGINE
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

    local nearest, minDist = nil, Config.Delays.MaxApproachDistance
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

-- Fix: Use Humanoid:MoveTo for 100% legitimate server-validated movement (No Kicking!)
local function SmoothApproachTarget(targetPosition, stopDistance)
    local _, root, hum = SafeGetCharacter()
    if not root or not hum then return end

    local dist = (targetPosition - root.Position).Magnitude
    if dist <= stopDistance then
        hum:MoveTo(root.Position)
        return
    end

    -- Legitimate character movement with server physics
    hum:MoveTo(targetPosition)
end

local function ExecuteAttack(target)
    if not target then return end

    -- 1. Direct Punch Attack via BridgeNet2
    if Bridges.Enemy then
        pcall(function()
            Bridges.Enemy:Fire({
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

    for _, enemyModel in ipairs(clientFolder:GetChildren()) do
        local hasArise = enemyModel:GetAttribute("Arise") ~= nil or enemyModel:FindFirstChild("Arise") ~= nil
        local isDead = enemyModel:GetAttribute("Dead") == true
        if hasArise or isDead then
            pcall(function()
                enemyBridge:Fire({
                    Event = Config.Events.EnemyCapture,
                    Enemy = enemyModel
                })
                AuditLogger.Stats.ShadowsArised = AuditLogger.Stats.ShadowsArised + 1
                AuditLogger.Record("Shadows", "Arise", "สกัดเงา: " .. enemyModel.Name)
            end)
            task.wait(0.1)
        end
    end
end

-- ============================================================================
-- 6. DUNGEON & TOWER UNLIMITED AUTOMATION ENGINE
-- ============================================================================

-- Function: Start or Re-enter Selected Dungeon
local function TriggerDungeonEnter()
    local generalBridge = Bridges.General
    if not generalBridge then return false end

    local selected = Config.Automation.SelectedKey
    local count = GetKeyCount(selected)

    if count <= 0 and selected ~= "World" then
        State.StatusText = string.format("กุญแจ %s หมดแล้ว!", selected)
        return false
    end

    AuditLogger.Record("Dungeon", "Entering", string.format("เริ่มลงดันเจี้ยน: %s (คงเหลือ %d)", selected, count))

    if selected == "World" then
        generalBridge:Fire({ Event = Config.Events.DungeonAction, Action = "Create" })
        task.wait(0.4)
        generalBridge:Fire({ Event = Config.Events.DungeonAction, Action = "Start" })
    else
        generalBridge:Fire({ Event = Config.Events.DungeonKeyAction, Action = "SelectKey", Key = selected })
        task.wait(0.4)
        generalBridge:Fire({ Event = Config.Events.DungeonKeyAction, Action = "Start" })
    end
    return true
end

-- Function: Start or Re-enter Tower / Castle at Specific Floor
local function TriggerTowerEnter()
    local generalBridge = Bridges.General
    if not generalBridge then return false end

    local mode = Config.Automation.TowerMode
    local floor = tonumber(Config.Automation.TargetFloor) or 1

    AuditLogger.Record("Tower", "Entering", string.format("เข้าหอคอย: %s (ชั้น %d)", mode, floor))

    if mode == "Castle" then
        generalBridge:Fire({
            Event = Config.Events.CastleAction,
            Action = "Join",
            Check = true,
            Floor = floor
        })
    elseif mode == "InfiniteCastle" then
        generalBridge:Fire({ Event = Config.Events.InfiniteCastleAction, Action = "Create" })
        task.wait(0.4)
        generalBridge:Fire({ Event = Config.Events.InfiniteCastleAction, Action = "Start" })
    elseif mode == "InfiniteLabyrinth" then
        generalBridge:Fire({ Event = Config.Events.InfiniteLabyrinthAction, Action = "Create" })
        task.wait(0.4)
        generalBridge:Fire({ Event = Config.Events.InfiniteLabyrinthAction, Action = "Start" })
    elseif mode == "InfiniteMode" then
        generalBridge:Fire({ Event = Config.Events.InfiniteModeAction, Action = "Create" })
        task.wait(0.4)
        generalBridge:Fire({ Event = Config.Events.InfiniteModeAction, Action = "Start" })
    end
    return true
end

-- ============================================================================
-- 7. WORKER THREADS (Isolated with Circuit Breakers)
-- ============================================================================

-- Fast Combat & Smooth Approach Loop
task.spawn(function()
    while State.Running do
        local _, root, hum = SafeGetCharacter()

        if root and hum and hum.Health > 0 then
            local target, dist = FindNearestEnemy()
            State.TargetEnemy = target

            if target then
                -- 1. Smooth Approach without getting kicked
                if Config.Automation.SmoothApproach then
                    SmoothApproachTarget(target.Position, Config.Delays.CombatRange)
                end

                -- 2. Attack with Weapon
                if Config.Automation.AutoAttack and CircuitBreaker.IsAvailable("Attack") then
                    local ok, err = pcall(function() ExecuteAttack(target) end)
                    if ok then CircuitBreaker.RecordSuccess("Attack") else CircuitBreaker.RecordFailure("Attack", err) end
                end

                -- 3. Command 55 Shadows
                if Config.Automation.AutoShadowArmy and CircuitBreaker.IsAvailable("ShadowArmy") then
                    local ok, err = pcall(function() ExecuteShadowArmy(target) end)
                    if ok then CircuitBreaker.RecordSuccess("ShadowArmy") else CircuitBreaker.RecordFailure("ShadowArmy", err) end
                end

                State.StatusText = string.format("สู้มอนสเตอร์: %s (ระยะ %.1fm)", target.Name, dist)
            else
                State.StatusText = "ค้นหามอนสเตอร์รอบตัว..."
            end

            -- 4. Arise Extraction
            if Config.Automation.AutoArise and CircuitBreaker.IsAvailable("Arise") then
                pcall(ExecuteAriseCapture)
            end
        end

        task.wait(Config.Delays.FastLoop)
    end
end)

-- Dungeon & Tower Continuous Loop Handler
task.spawn(function()
    while State.Running do
        -- Check In-Dungeon State
        local inDg = LocalPlayer:GetAttribute("InDungeon") == true or LocalPlayer:GetAttribute("InDungeonKey") == true
        local inTower = ReplicatedStorage:GetAttribute("IsCastle") == true or ReplicatedStorage:GetAttribute("InInfiniteC") == true or ReplicatedStorage:GetAttribute("InInfinite") == true

        -- SpeedUp Tower if active
        if inTower and Config.Automation.AutoSpeedUp and Bridges.General then
            pcall(function()
                Bridges.General:Fire({ Event = Config.Events.CastleAction, Action = "SpeedUp" })
                Bridges.General:Fire({ Event = Config.Events.InfiniteCastleAction, Action = "SpeedUp" })
            end)
        end

        -- Continuous Dungeon Looping: If not in dungeon, trigger next run until keys gone
        if Config.Automation.AutoDungeon and not inDg and not inTower then
            if tick() - State.LastDungeonAttempt >= 4.0 then
                State.LastDungeonAttempt = tick()
                local ok = TriggerDungeonEnter()
                if not ok and Config.Automation.LoopDungeonUntilGone then
                    Config.Automation.AutoDungeon = false
                    AuditLogger.Record("Dungeon", "Finished", "กุญแจหมดหรือดันเจี้ยนสิ้นสุดการทำงาน")
                end
            end
        end

        -- Continuous Tower Looping: If not in tower, trigger next run at specific floor
        if Config.Automation.AutoTower and not inTower and not inDg then
            if tick() - State.LastTowerAttempt >= 5.0 then
                State.LastTowerAttempt = tick()
                TriggerTowerEnter()
            end
        end

        task.wait(1.5)
    end
end)

-- Slow Utility Loop (Equip Best, Quests, Gifts)
task.spawn(function()
    while State.Running do
        pcall(function()
            -- Equip Best Shadows
            if Config.Automation.AutoEquipBestPets and CircuitBreaker.IsAvailable("EquipBest") then
                if ButtonsModule and typeof(ButtonsModule.PetsButtons) == "function" then
                    ButtonsModule.PetsButtons("None", { Action = "PetAction", Type = "EquipBest" })
                end
            end

            -- Claim Completed Quests
            if Config.Automation.AutoClaimQuests and Bridges.General then
                local ls = LocalPlayer:FindFirstChild("leaderstats")
                local questsFolder = ls and ls:FindFirstChild("Quests")
                if questsFolder then
                    for _, qType in ipairs(questsFolder:GetChildren()) do
                        for _, qItem in ipairs(qType:GetChildren()) do
                            if qItem:GetAttribute("Completed") == true then
                                Bridges.General:Fire({
                                    Event = Config.Events.ClaimQuest,
                                    Id = qItem.Name,
                                    Type = qType.Name
                                })
                                AuditLogger.Stats.QuestsClaimed = AuditLogger.Stats.QuestsClaimed + 1
                                AuditLogger.Record("Quests", "Claimed", "รับรางวัลเควสต์ " .. qItem.Name)
                            end
                        end
                    end
                end
            end

            -- Claim Free Gifts
            if Config.Automation.AutoClaimGifts and Bridges.General then
                for i = 1, 12 do
                    Bridges.General:Fire({ Event = Config.Events.ClaimGift, Id = i })
                end
            end
        end)

        task.wait(Config.Delays.SlowLoop)
    end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if Config.Automation.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end
end)

-- ============================================================================
-- 8. MODERN TABBED USER INTERFACE & MINIMIZE PILL
-- ============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DungeonRiseQAGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = parentGui

-- Floating Quick-Access Pill
local FloatingPill = Instance.new("TextButton")
FloatingPill.Name = "FloatingPill"
FloatingPill.Size = UDim2.new(0, 180, 0, 36)
FloatingPill.Position = UDim2.new(0.5, -90, 0, 15)
FloatingPill.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
FloatingPill.BorderSizePixel = 0
FloatingPill.Text = "⚡ Dungeon Rise (เปิด)"
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
MainFrame.Size = UDim2.new(0, 530, 0, 380)
MainFrame.Position = UDim2.new(0.5, -265, 0.25, -190)
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
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 10)
TopCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "⚡ DUNGEON RISE QA CONTROLLER (PRO V2)"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Size = UDim2.new(0, 320, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = TopBar

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
Sidebar.Name = "Sidebar"
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
PagesContainer.Name = "PagesContainer"
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
    page.CanvasSize = UDim2.new(0, 0, 0, 650)
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
    p.PaddingLeft = UDim.new(0, 8)
    p.Parent = btn

    TabButtons[pageName] = btn
    btn.MouseButton1Click:Connect(function() SwitchTab(pageName) end)
end

-- Pages
local CombatPage = CreatePage("Combat")
local DungeonPage = CreatePage("Dungeon")
local TowerPage = CreatePage("Tower")
local ShadowsPage = CreatePage("Shadows")
local QuestsPage = CreatePage("Quests")
local LogsPage = CreatePage("Logs")
local SettingsPage = CreatePage("Settings")

-- Tabs
AddTab("การต่อสู้", "⚔️", "Combat")
AddTab("ดันเจี้ยน", "🏰", "Dungeon")
AddTab("หอคอย", "🗼", "Tower")
AddTab("กองทัพเงา", "👥", "Shadows")
AddTab("เควสต์", "🎁", "Quests")
AddTab("ประวัติ", "📊", "Logs")
AddTab("ตั้งค่า", "⚙️", "Settings")

-- UI Helpers
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

local function AddSectionTo(page, txt, col)
    local l = Instance.new("TextLabel")
    l.Text = txt
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextColor3 = col or Color3.fromRGB(255, 170, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, -6, 0, 20)
    l.BackgroundTransparency = 1
    l.Parent = page
end

-- ============================================================================
-- 9. POPULATE TAB PAGES
-- ============================================================================

-- [TAB 1: COMBAT - NON-KICK FIX]
AddSectionTo(CombatPage, "⚔️ ระบบการต่อสู้ (ไม่หลุด/ไม่โดนเตะ)", Color3.fromRGB(0, 220, 255))
AddToggleTo(CombatPage, "โจมตีอัตโนมัติด้วยอาวุธ M1 (Auto Attack)", Config.Automation.AutoAttack, function(v) Config.Automation.AutoAttack = v end)
AddToggleTo(CombatPage, "ส่งกองทัพเงา 55 ตัวโจมตี (Auto Send Shadows)", Config.Automation.AutoShadowArmy, function(v) Config.Automation.AutoShadowArmy = v end)
AddToggleTo(CombatPage, "เคลื่อนที่เข้าหาแบบสมูท (Smooth Walk - แก้โดนเตะ)", Config.Automation.SmoothApproach, function(v) Config.Automation.SmoothApproach = v end)
AddButtonTo(CombatPage, "🗡️ โจมตีเป้าหมายทันที (Manual Hit)", Color3.fromRGB(40, 130, 80), function()
    local target = FindNearestEnemy()
    if target then ExecuteAttack(target) end
end)

-- [TAB 2: DUNGEON AUTOMATION]
AddSectionTo(DungeonPage, "🏰 ลงดันเจี้ยนต่อเนื่อง (ไม่จำกัดรอบ)", Color3.fromRGB(255, 120, 50))
AddToggleTo(DungeonPage, "ลงดันเจี้ยนอัตโนมัติ (Auto Run Dungeon)", Config.Automation.AutoDungeon, function(v) Config.Automation.AutoDungeon = v end)
AddToggleTo(DungeonPage, "ลงซ้ำจนกว่ากุญแจจะหมด (Loop Until Keys Depleted)", Config.Automation.LoopDungeonUntilGone, function(v) Config.Automation.LoopDungeonUntilGone = v end)

AddSectionTo(DungeonPage, "🔑 เลือกกุญแจ / ดันเจี้ยนเป้าหมาย:", Color3.fromRGB(255, 215, 0))
local KeyOptions = {
    {Id = "Key", Label = "Key (กุญแจทั่วไป 2400+ อัน)"},
    {Id = "FairyKey", Label = "FairyKey (660+ อัน)"},
    {Id = "DSKey", Label = "DSKey (250+ อัน)"},
    {Id = "Solo2Key", Label = "Solo2Key (190+ อัน)"},
    {Id = "XWinterKey", Label = "XWinterKey (120+ อัน)"},
    {Id = "SHKey", Label = "SHKey (47 อัน)"},
    {Id = "AoTKey", Label = "AoTKey (35 อัน)"},
    {Id = "NanatsuKey", Label = "NanatsuKey (18 อัน)"},
    {Id = "EminanceKey", Label = "EminanceKey (11 อัน)"},
    {Id = "OpmKey", Label = "OpmKey (10 อัน)"},
    {Id = "BeachKeyIgris", Label = "BeachKeyIgris (8 อัน)"},
    {Id = "SlimeKey", Label = "SlimeKey (5 อัน)"},
    {Id = "ZeroKey", Label = "ZeroKey (3 อัน)"},
    {Id = "World", Label = "World Dungeon (ดันเจี้ยนโลก)"}
}

for _, opt in ipairs(KeyOptions) do
    AddButtonTo(DungeonPage, "📌 เลือก: " .. opt.Label, Color3.fromRGB(32, 38, 54), function()
        Config.Automation.SelectedKey = opt.Id
        SaveConfig()
        AuditLogger.Record("Dungeon", "KeySelected", "เลือกกุญแจ: " .. opt.Id)
    end)
end

AddButtonTo(DungeonPage, "🚀 เริ่มลงดันเจี้ยนเดี๋ยวนี้ (Start Now)", Color3.fromRGB(40, 140, 90), function()
    TriggerDungeonEnter()
end)

-- [TAB 3: TOWER & CASTLE AUTOMATION]
AddSectionTo(TowerPage, "🗼 ระบบลงหอคอย & หอคอยอเวจี", Color3.fromRGB(180, 100, 255))
AddToggleTo(TowerPage, "ลงหอคอยอัตโนมัติ (Auto Run Tower/Castle)", Config.Automation.AutoTower, function(v) Config.Automation.AutoTower = v end)
AddToggleTo(TowerPage, "จบแล้วลงซ้ำชั้นเดิมเรื่อยๆ (Repeat Specified Floor)", Config.Automation.RepeatTargetFloor, function(v) Config.Automation.RepeatTargetFloor = v end)
AddToggleTo(TowerPage, "เร่งความเร็วหอคอย (Auto SpeedUp)", Config.Automation.AutoSpeedUp, function(v) Config.Automation.AutoSpeedUp = v end)

-- Floor Target Adjuster
local FloorBox = Instance.new("Frame")
FloorBox.Size = UDim2.new(1, -6, 0, 36)
FloorBox.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
FloorBox.BorderSizePixel = 0
FloorBox.Parent = TowerPage

local FloorCorner = Instance.new("UICorner")
FloorCorner.CornerRadius = UDim.new(0, 6)
FloorCorner.Parent = FloorBox

local FloorLabel = Instance.new("TextLabel")
FloorLabel.Size = UDim2.new(1, -120, 1, 0)
FloorLabel.Position = UDim2.new(0, 10, 0, 0)
FloorLabel.BackgroundTransparency = 1
FloorLabel.Font = Enum.Font.GothamBold
FloorLabel.TextSize = 11
FloorLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
FloorLabel.TextXAlignment = Enum.TextXAlignment.Left
FloorLabel.Text = "ชั้นเป้าหมาย: " .. tostring(Config.Automation.TargetFloor)
FloorLabel.Parent = FloorBox

local MinusBtn = Instance.new("TextButton")
MinusBtn.Size = UDim2.new(0, 30, 0, 26)
MinusBtn.Position = UDim2.new(1, -85, 0, 5)
MinusBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 75)
MinusBtn.Text = "-25"
MinusBtn.Font = Enum.Font.GothamBold
MinusBtn.TextSize = 10
MinusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinusBtn.BorderSizePixel = 0
MinusBtn.Parent = FloorBox

local PlusBtn = Instance.new("TextButton")
PlusBtn.Size = UDim2.new(0, 30, 0, 26)
PlusBtn.Position = UDim2.new(1, -45, 0, 5)
PlusBtn.BackgroundColor3 = Color3.fromRGB(45, 52, 75)
PlusBtn.Text = "+25"
PlusBtn.Font = Enum.Font.GothamBold
PlusBtn.TextSize = 10
PlusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PlusBtn.BorderSizePixel = 0
PlusBtn.Parent = FloorBox

MinusBtn.MouseButton1Click:Connect(function()
    Config.Automation.TargetFloor = math.max(1, Config.Automation.TargetFloor - 25)
    FloorLabel.Text = "ชั้นเป้าหมาย: " .. tostring(Config.Automation.TargetFloor)
    SaveConfig()
end)

PlusBtn.MouseButton1Click:Connect(function()
    Config.Automation.TargetFloor = Config.Automation.TargetFloor + 25
    FloorLabel.Text = "ชั้นเป้าหมาย: " .. tostring(Config.Automation.TargetFloor)
    SaveConfig()
end)

AddButtonTo(TowerPage, "🏆 ตั้งเป็นชั้นสูงสุด (Max Floor: 950)", Color3.fromRGB(40, 120, 180), function()
    Config.Automation.TargetFloor = 950
    FloorLabel.Text = "ชั้นเป้าหมาย: 950"
    SaveConfig()
end)

AddSectionTo(TowerPage, "โหมดหอคอย:", Color3.fromRGB(255, 200, 50))
local TowerModes = {
    {Id = "Castle", Name = "Infernal Castle (หอคอยอเวจี)"},
    {Id = "InfiniteCastle", Name = "Infinite Castle (หอคอยไร้สิ้นสุด)"},
    {Id = "InfiniteLabyrinth", Name = "Infinite Labyrinth (เขาวงกต)"},
    {Id = "InfiniteMode", Name = "Infinite Mode (โหมดเวฟ)"}
}
for _, tm in ipairs(TowerModes) do
    AddButtonTo(TowerPage, "เลือก: " .. tm.Name, Color3.fromRGB(28, 33, 48), function()
        Config.Automation.TowerMode = tm.Id
        SaveConfig()
        AuditLogger.Record("Tower", "ModeSelected", "เลือกโหมด: " .. tm.Id)
    end)
end

AddButtonTo(TowerPage, "🚀 เข้าหอคอยชั้นที่เลือกเดี๋ยวนี้", Color3.fromRGB(150, 40, 150), function()
    TriggerTowerEnter()
end)

-- [TAB 4: SHADOWS]
AddSectionTo(ShadowsPage, "👥 ควบคุมกองทัพเงา & สกัดเงา", Color3.fromRGB(0, 200, 255))
AddToggleTo(ShadowsPage, "สกัดเงาอัตโนมัติ (Auto Arise)", Config.Automation.AutoArise, function(v) Config.Automation.AutoArise = v end)
AddToggleTo(ShadowsPage, "สวมใส่เงาที่ดีที่สุด (Auto Equip Best Shadows)", Config.Automation.AutoEquipBestPets, function(v) Config.Automation.AutoEquipBestPets = v end)
AddButtonTo(ShadowsPage, "👑 ติดตั้งเงาที่ดีที่สุดทันที", Color3.fromRGB(35, 120, 180), function()
    if ButtonsModule and ButtonsModule.PetsButtons then
        ButtonsModule.PetsButtons("None", { Action = "PetAction", Type = "EquipBest" })
        AuditLogger.Record("Shadows", "EquipBest", "ติดตั้งเงาที่ดีที่สุดเรียบร้อย")
    end
end)

-- [TAB 5: QUESTS]
AddSectionTo(QuestsPage, "🎁 รางวัล & ของขวัญฟรี", Color3.fromRGB(255, 215, 0))
AddToggleTo(QuestsPage, "รับรางวัลเควสต์อัตโนมัติ (Auto Claim Quests)", Config.Automation.AutoClaimQuests, function(v) Config.Automation.AutoClaimQuests = v end)
AddToggleTo(QuestsPage, "รับของขวัญฟรีตามเวลา (Auto Claim Gifts)", Config.Automation.AutoClaimGifts, function(v) Config.Automation.AutoClaimGifts = v end)

-- [TAB 6: LOGS & STATS]
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
            local selected = Config.Automation.SelectedKey
            local count = GetKeyCount(selected)
            StatsLabel.Text = string.format("📊 โจมตี: %d | สกัดเงา: %d | กุญแจ [%s]: %d อัน\n🏰 ดันเจี้ยน: %s | หอคอยชั้น: %d | สถานะ: %s",
                AuditLogger.Stats.AttacksFired, AuditLogger.Stats.ShadowsArised, selected, count,
                Config.Automation.AutoDungeon and "เปิดวนซ้ำ" or "ปิด",
                Config.Automation.TargetFloor, State.StatusText)
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

AuditLogger.OnLogged = function() RefreshLogUI() end

AddButtonTo(LogsPage, "🗑️ ล้างประวัติการบันทึก (Clear Logs)", Color3.fromRGB(60, 35, 40), function()
    table.clear(AuditLogger.History)
    RefreshLogUI()
end)

-- [TAB 7: SETTINGS]
AddToggleTo(SettingsPage, "ป้องกันการหลุดจากการอยู่นิ่ง (Anti-AFK)", Config.Automation.AntiAFK, function(v) Config.Automation.AntiAFK = v end)
AddButtonTo(SettingsPage, "💾 บันทึกการตั้งค่าเดี๋ยวนี้ (Save Config)", Color3.fromRGB(40, 120, 180), function() SaveConfig() end)
AddButtonTo(SettingsPage, "🔄 โหลดการตั้งค่าจากไฟล์ (Reload Config)", Color3.fromRGB(50, 60, 90), function() LoadConfig() end)
AddButtonTo(SettingsPage, "⚠️ รีเซ็ตกลับเป็นค่าเริ่มต้น (Reset Defaults)", Color3.fromRGB(120, 40, 40), function()
    Config.Automation.AutoAttack = true
    Config.Automation.AutoShadowArmy = true
    Config.Automation.AutoArise = true
    Config.Automation.SmoothApproach = true
    Config.Automation.AutoDungeon = false
    Config.Automation.AutoTower = false
    Config.Automation.TargetFloor = 950
    SaveConfig()
    AuditLogger.Record("Settings", "Reset", "รีเซ็ตการตั้งค่าเป็นค่าเริ่มต้น")
end)

SwitchTab("Combat")

-- ============================================================================
-- 10. CLEANUP & SHUTDOWN HANDLER
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

AuditLogger.Record("Loader", "Ready", "Dungeon Rise Pro V2 พร้อมทำงานเรียบร้อย!")
