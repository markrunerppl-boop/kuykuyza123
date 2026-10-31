--[[
    ================================================================================
    [PREMIUM ROBLOX QA AUTOMATION & NPC CONTROLLER - CHAKRA QA ENTERPRISE V12]
    Target Game: Chakra Training Simulator (Anime / Naruto)
    Architecture: Ground Level Zone-Trigger Compliant | Tabbed UI | Audit Logging
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
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- Parent GUI Resolution
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
        StagesCleared = 0,
        BossAttacks = 0,
        RebirthsCount = 0,
        PetsFused = 0,
        RewardsClaimed = 0,
        CodesRedeemed = 0
    },
    OnLogged = nil -- UI Callback
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
-- 1. CENTRALIZED CONSTANTS & CONFIGURATION
-- ============================================================================
local Config = {
    Tag = "ChakraQA_Pro",
    ConfigFile = "ChakraQA_Config_V12.json",

    Remotes = {
        Train = "Train",
        Cast = "Cast",
        Rebirth = "Rebirth",
        ClaimQuest = "ClaimQuest",
        ClaimReward = "ClaimReward",
        ClaimDaily = "ClaimDaily",
        ClaimGroup = "ClaimGroup",
        PetAction = "PetAction",
        EquipAura = "EquipAura",
        UnlockEye = "UnlockEye",
        Equip = "Equip",
        Pad = "Pad",
        Teleport = "Teleport",
        Fuse = "Fuse",
        RedeemCode = "RedeemCode",
        Boss = "Boss",
        BossShop = "BossShop",
        Revive = "Revive",
        ArcadeStart = "ArcadeStart"
    },

    Attributes = {
        World = "World",
        Downed = "Downed",
        InStages = "InStages",
        RunStage = "RunStage",
        RunCleared = "RunCleared",
        BossPhase = "BossPhase",
        BossHp = "BossHp",
        Rebirths = "Rebirths",
        TrainMult = "TrainMult"
    },

    Events = {
        Attack = "attack",
        SkillE = "E",
        SkillR = "R",
        ReviveDeny = "no",
        EquipBest = "equipBest",
        FuseAction = "fuse",
        BossJoin = "join",
        BossLeave = "leave"
    },

    Automation = {
        AutoTrain = true,
        AutoBestTrain = true,
        AutoAttack = true,
        AutoSkillE = true,
        AutoSkillR = true,
        AutoStages = true,
        AutoRetreat = true,
        AutoPops = true,
        AutoRebirth = true,
        AutoEquipBestAura = true,
        AutoEquipBestEye = true,
        AutoEquipBestPets = true,
        AutoClaimAll = true,
        AutoRedeemCodes = true,
        AutoFusePets = true,
        AutoBoss = true
    },

    Delays = {
        FastLoop = 0.05,
        SlowLoop = 2.5,
        SkillECooldown = 3.5,
        SkillRCooldown = 6.0,
        HumanJitterMin = 0.06,
        HumanJitterMax = 0.14
    },

    Stages = {
        TargetWorld = 5,
        PadType = "purple",            -- "purple" = 3x, "gold" = standard
        MaxCombatTime = 8.0,
        HealthRetreatThreshold = 0.45,
        PadDwellTime = 0.8,
        FloorY = 3.5
    }
}

local WorldsInfo = {
    [1] = { name = "Shinobi Lands", color = Color3.fromRGB(69, 200, 255), originX = 0 },
    [2] = { name = "Celestial Realm", color = Color3.fromRGB(180, 92, 255), originX = 3000 },
    [3] = { name = "Blood Moon", color = Color3.fromRGB(255, 46, 77), originX = 6000 },
    [4] = { name = "Frozen Abyss", color = Color3.fromRGB(63, 184, 255), originX = 9000 },
    [5] = { name = "Cosmic Void", color = Color3.fromRGB(155, 92, 255), originX = 12000 }
}

-- ============================================================================
-- 2. SAFE MODULE LOADING & CIRCUIT BREAKER (NON-BLOCKING)
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

local Input = SafeRequire(LocalPlayer, {"PlayerScripts", "Client"}, "Input")
local Enemies = SafeRequire(LocalPlayer, {"PlayerScripts", "Client"}, "Enemies")
local StateMod = SafeRequire(LocalPlayer, {"PlayerScripts", "Client"}, "State")
local World = SafeRequire(ReplicatedStorage, {"Shared", "Config"}, "World")
local Plots = SafeRequire(ReplicatedStorage, {"Shared", "Config"}, "Plots")
local FuseLogic = SafeRequire(ReplicatedStorage, {"Shared", "Logic"}, "Fuse")
local CodesConfig = SafeRequire(ReplicatedStorage, {"Shared", "Config"}, "Codes")
local EyesConfig = SafeRequire(ReplicatedStorage, {"Shared", "Config"}, "Eyes")
local AurasConfig = SafeRequire(ReplicatedStorage, {"Shared", "Config"}, "Auras")
local BossLogic = SafeRequire(ReplicatedStorage, {"Shared", "Logic"}, "Boss")

local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local Remotes = {}
for alias, name in pairs(Config.Remotes) do
    Remotes[alias] = RemotesFolder and RemotesFolder:FindFirstChild(name)
end

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
        AuditLogger.Record("CircuitBreaker", "Tripped", string.format("Task '%s' ล้มเหลวติดกันเกิน 3 ครั้ง พักการทำงาน 15 วิ", taskKey))
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
-- 3. STATE, CHARACTER & RATE LIMITING HELPERS
-- ============================================================================
local State = {
    Running = true,
    CurrentStage = 1,
    LastStage = 0,
    StageStartTime = tick(),
    IsRetreating = false,
    StatusText = "ระบบกำลังเริ่มต้น...",
    Connections = {}
}

local function HumanWait(minSec, maxSec)
    local minT = minSec or Config.Delays.HumanJitterMin
    local maxT = maxSec or Config.Delays.HumanJitterMax
    task.wait(minT + math.random() * (maxT - minT))
end

local function SafeFind(parent, childName, recursive)
    if not parent then return nil end
    local ok, res = pcall(function()
        return parent:FindFirstChild(childName, recursive or false)
    end)
    return (ok and res) or nil
end

local function SafeGetCharacter()
    local char = LocalPlayer.Character
    if not char or not char.Parent then return nil, nil, nil end
    return char, char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
end

-- ============================================================================
-- 4. CONFIG PERSISTENCE
-- ============================================================================
local function SaveConfig()
    pcall(function()
        if writefile then
            local payload = { Automation = Config.Automation, Stages = Config.Stages }
            writefile(Config.ConfigFile, HttpService:JSONEncode(payload))
            AuditLogger.Record("Config", "Saved", "บันทึกการตั้งค่าลงไฟล์ " .. Config.ConfigFile)
        end
    end)
end

local function LoadConfig()
    pcall(function()
        if isfile and readfile and isfile(Config.ConfigFile) then
            local raw = readfile(Config.ConfigFile)
            local data = HttpService:JSONDecode(raw)
            if type(data) == "table" then
                if type(data.Automation) == "table" then
                    for k, v in pairs(data.Automation) do Config.Automation[k] = v end
                end
                if type(data.Stages) == "table" then
                    for k, v in pairs(data.Stages) do Config.Stages[k] = v end
                end
                AuditLogger.Record("Config", "Loaded", "โหลดการตั้งค่าเดิมเรียบร้อย")
            end
        end
    end)
end
LoadConfig()

-- ============================================================================
-- 5. WORLD & COMBAT LOGIC
-- ============================================================================
local function GetCurrentWorld()
    if Config.Stages.TargetWorld and Config.Stages.TargetWorld >= 1 and Config.Stages.TargetWorld <= 5 then
        return Config.Stages.TargetWorld
    end
    local _, root = SafeGetCharacter()
    if root and World and typeof(World.worldAt) == "function" then
        local w = World.worldAt(root.Position)
        if w and w >= 1 and w <= 5 then return w end
    end
    local attrW = LocalPlayer:GetAttribute(Config.Attributes.World)
    return (attrW and attrW >= 1 and attrW <= 5) and attrW or 5
end

local function GetWorldOrigin(worldId)
    local w = worldId or GetCurrentWorld()
    local entry = WorldsInfo[w]
    return Vector3.new(entry and entry.originX or 0, 0, 0)
end

local function GetAimPos(targetPos)
    if targetPos then return targetPos end
    local _, root = SafeGetCharacter()
    local cam = Workspace.CurrentCamera
    if cam and root then
        return root.Position + cam.CFrame.LookVector * 25
    elseif root then
        return root.Position + Vector3.new(0, 0, 15)
    end
    return Vector3.zero
end

local function ExecuteAttack(target)
    local aimPos = target and target.pos or GetAimPos()
    local targetId = target and target.id or nil
    if Input and typeof(Input.press) == "function" then
        pcall(function() Input.press(Config.Events.Attack) end)
    end
    if Remotes.Cast then
        pcall(function() Remotes.Cast:FireServer(Config.Events.Attack, aimPos, targetId) end)
    end
end

local function ExecuteSkill(slot, target)
    local aimPos = target and target.pos or GetAimPos()
    local targetId = target and target.id or nil
    if Input and typeof(Input.press) == "function" then
        pcall(function() Input.press(slot) end)
    end
    if Remotes.Cast then
        pcall(function() Remotes.Cast:FireServer(slot, aimPos, targetId) end)
    end
end

local function TeleportToBestTrainingSpot()
    local _, root = SafeGetCharacter()
    if not root or not Plots or not World or not World.TRAINING then return false end

    -- ถ้าตัวยังอยู่ในอารีน่าบอส ให้ส่งคำขอออกจากห้องบอสก่อน
    local bossCentre = Vector3.new(-3000, 0, 300)
    local inBossDist = (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(bossCentre.X, bossCentre.Z)).Magnitude
    if inBossDist <= 150 and Remotes.Boss then
        pcall(function() Remotes.Boss:FireServer(Config.Events.BossLeave) end)
    end

    local w = GetCurrentWorld()
    local spots = (typeof(Plots.forWorld) == "function") and Plots.forWorld(w) or nil
    if not spots then return false end

    local rebirths = (StateMod and StateMod.number and StateMod.number("Rebirths")) or LocalPlayer:GetAttribute("Rebirths") or 0
    local bestSpot, bestIdx = nil, 1
    for idx, spot in ipairs(spots) do
        local passOk = true
        if spot.pass then
            passOk = LocalPlayer:GetAttribute("Pass_" .. spot.pass) == true
        end
        if passOk and rebirths >= (spot.rebirths or 0) then
            if not bestSpot or (spot.mult or 0) > (bestSpot.mult or 0) then
                bestSpot = spot
                bestIdx = idx
            end
        end
    end

    if bestSpot and World.TRAINING[bestIdx] then
        local rawOffset = World.TRAINING[bestIdx]
        local offVec = Vector3.zero
        if typeof(rawOffset) == "Vector3" then
            offVec = rawOffset
        elseif type(rawOffset) == "string" then
            local parts = string.split(rawOffset, ",")
            offVec = Vector3.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0)
        end
        local originX = GetWorldOrigin(w).X
        local spotPos = Vector3.new(originX + offVec.X, 4.5, offVec.Z)

        if (root.Position - spotPos).Magnitude > 6 then
            root.CFrame = CFrame.new(spotPos)
            root.AssemblyLinearVelocity = Vector3.zero
        end

        if Input and Input.autoClick then 
            pcall(Input.autoClick) 
        elseif Remotes.Train then 
            pcall(function() Remotes.Train:FireServer() end) 
        end
        local multVal = (bestSpot.mult or 1)
        State.StatusText = string.format("🧘 ซ้อมจักระรอบอส: %s (คูณ %.1e x)", bestSpot.name, multVal)
        return true
    end
    return false
end

-- ============================================================================
-- 6. WORKER ENGINE (Tasks with Circuit Breakers & Logging)
-- ============================================================================
task.spawn(function()
    local lastSkillE, lastSkillR = 0, 0

    while State.Running do
        local _, root, hum = SafeGetCharacter()
        local isDowned = LocalPlayer:GetAttribute(Config.Attributes.Downed) == true

        if hum and (hum.Health <= 0 or isDowned) then
            State.StatusText = "ฟื้นฟูสภาพตัวละคร (Respawning)..."
            if Remotes.Revive then
                pcall(function() Remotes.Revive:FireServer(Config.Events.ReviveDeny) end)
            end
            task.wait(0.5)
        else
            -- Task: Boss Fight
            local bossPhase = Workspace:GetAttribute(Config.Attributes.BossPhase)
            local bossHp = Workspace:GetAttribute(Config.Attributes.BossHp) or 0

            if Config.Automation.AutoBoss and (bossPhase == "fight" or bossPhase == "coming") and CircuitBreaker.IsAvailable("Boss") then
                local ok, err = pcall(function()
                    local bossCentre = Vector3.new(-3000, 0, 300)
                    if not root then return end
                    local dist = (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(bossCentre.X, bossCentre.Z)).Magnitude

                    if dist > 140 then
                        State.StatusText = "เดินทางเข้าห้องบอสคุรามะ..."
                        if Remotes.Boss then Remotes.Boss:FireServer(Config.Events.BossJoin) end
                        local bp = SafeFind(Workspace, "BossPortals")
                        local portal = bp and (SafeFind(bp, "Portal5") or bp:FindFirstChildWhichIsA("Model"))
                        local prompt = portal and SafeFind(portal, "JoinPrompt", true)
                        if prompt and prompt.Enabled and typeof(fireproximityprompt) == "function" then
                            fireproximityprompt(prompt)
                        end
                        task.wait(0.5)
                    else
                        local orbitAngle = (tick() * 0.5) % (math.pi * 2)
                        local safeRadius = 74.0
                        local safeCombatPos = bossCentre + Vector3.new(math.cos(orbitAngle) * safeRadius, 16, math.sin(orbitAngle) * safeRadius)
                        local bossLookPos = bossCentre + Vector3.new(0, 14, 0)
                        root.CFrame = CFrame.new(safeCombatPos, bossLookPos)
                        root.AssemblyLinearVelocity = Vector3.zero

                        local aimPos = (BossLogic and BossLogic.aimPoint and BossLogic.aimPoint(root.Position.X, root.Position.Z)) or bossLookPos
                        local bossTarget = { boss = true, id = 2000000000, pos = aimPos }
                        ExecuteAttack(bossTarget)
                        ExecuteSkill(Config.Events.SkillE, bossTarget)
                        ExecuteSkill(Config.Events.SkillR, bossTarget)
                        AuditLogger.Stats.BossAttacks = AuditLogger.Stats.BossAttacks + 1
                        State.StatusText = string.format("🦊⚔️ ตีบอสคุรามะ (หลบ 74st / โจมตี 100%%) HP: %.1f%%", bossHp * 100)
                    end
                end)
                if ok then CircuitBreaker.RecordSuccess("Boss") else CircuitBreaker.RecordFailure("Boss", err) end

            -- Task: Best Training (ระหว่างรอบอสเกิด หรือช่วงบอสจบ ให้ซ้อมจุดที่ดีที่สุด)
            elseif Config.Automation.AutoBestTrain and CircuitBreaker.IsAvailable("BestTrain") then
                local bossCentre = Vector3.new(-3000, 0, 300)
                local dist = root and (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(bossCentre.X, bossCentre.Z)).Magnitude or 999
                if dist <= 140 and Remotes.Boss then
                    pcall(function() Remotes.Boss:FireServer(Config.Events.BossLeave) end)
                    task.wait(0.3)
                end
                local ok, err = pcall(TeleportToBestTrainingSpot)
                if ok then CircuitBreaker.RecordSuccess("BestTrain") else CircuitBreaker.RecordFailure("BestTrain", err) end

            -- Task: Stages Runner
            elseif Config.Automation.AutoStages and CircuitBreaker.IsAvailable("Stages") and root and hum then
                local ok, err = pcall(function()
                    local inStages = LocalPlayer:GetAttribute(Config.Attributes.InStages)
                    local runStage = LocalPlayer:GetAttribute(Config.Attributes.RunStage) or 0
                    local runCleared = LocalPlayer:GetAttribute(Config.Attributes.RunCleared) or 0
                    local curWorld = GetCurrentWorld()
                    local originX = GetWorldOrigin(curWorld).X

                    if not inStages or runStage == 0 then
                        root.CFrame = CFrame.new(originX, Config.Stages.FloorY, -75)
                        root.AssemblyLinearVelocity = Vector3.zero
                        State.CurrentStage = 1
                        State.StageStartTime = tick()
                        task.wait(0.3)
                    else
                        local hpPercent = hum.Health / math.max(hum.MaxHealth, 1)
                        local timeInCombat = tick() - State.StageStartTime

                        if Config.Automation.AutoRetreat and runStage > 1 and runCleared >= 1 and (hpPercent <= Config.Stages.HealthRetreatThreshold or timeInCombat >= Config.Stages.MaxCombatTime) then
                            local padOffsetX = (Config.Stages.PadType == "purple") and -20 or 20
                            root.CFrame = CFrame.new(originX + padOffsetX, 1.8, -111 - (runCleared - 1) * 90)
                            root.AssemblyLinearVelocity = Vector3.zero
                            if Remotes.Pad then Remotes.Pad:FireServer(runCleared, Config.Stages.PadType) end
                            AuditLogger.Record("Combat", "Smart Retreat", string.format("ถอยมารับถ้วยรางวัล Stage %d", runCleared))
                            task.wait(Config.Stages.PadDwellTime)
                        else
                            local rawList = (Enemies and Enemies.list and Enemies.list()) or {}
                            local currentTarget = nil
                            for _, e in ipairs(rawList) do
                                if e.pos and (World and World.stageAt and World.stageAt(e.pos.Z) == runStage) then
                                    currentTarget = e; break
                                end
                            end

                            if currentTarget then
                                local toPlayer = (root.Position - currentTarget.pos)
                                local dir = (toPlayer.Magnitude > 0.1) and toPlayer.Unit or Vector3.new(0, 0, 1)
                                root.CFrame = CFrame.new(currentTarget.pos + dir * 15 + Vector3.new(0, 4, 0), currentTarget.pos)
                                root.AssemblyLinearVelocity = Vector3.zero

                                ExecuteAttack(currentTarget)
                                ExecuteSkill(Config.Events.SkillE, currentTarget)
                                ExecuteSkill(Config.Events.SkillR, currentTarget)
                                State.StatusText = string.format("สู้ด่าน Stage %d (Kiting 15st) | เลือด: %d%%", runStage, math.floor(hpPercent * 100))
                            else
                                if runStage >= 15 then
                                    if Remotes.Pad then Remotes.Pad:FireServer(15, Config.Stages.PadType) end
                                    AuditLogger.Stats.StagesCleared = AuditLogger.Stats.StagesCleared + 1
                                    AuditLogger.Record("Combat", "Stage Cleared", "เคลียร์ด่านสูงสุด Stage 15 สำเร็จ!")
                                    task.wait(1.0)
                                else
                                    local nextZ = -75 - (runStage) * 90
                                    root.CFrame = CFrame.new(originX, Config.Stages.FloorY, nextZ)
                                    root.AssemblyLinearVelocity = Vector3.zero
                                    State.StageStartTime = tick()
                                end
                            end
                        end
                    end
                end)
                if ok then CircuitBreaker.RecordSuccess("Stages") else CircuitBreaker.RecordFailure("Stages", err) end

            -- Task: Basic Manual Train / Attack
            else
                if Config.Automation.AutoTrain and Remotes.Train then
                    pcall(function()
                        if Input and Input.autoClick then Input.autoClick() else Remotes.Train:FireServer() end
                    end)
                end
                if Config.Automation.AutoAttack then ExecuteAttack(nil) end
                if Config.Automation.AutoSkillE and (tick() - lastSkillE >= Config.Delays.SkillECooldown) then
                    ExecuteSkill(Config.Events.SkillE, nil)
                    lastSkillE = tick()
                end
                if Config.Automation.AutoSkillR and (tick() - lastSkillR >= Config.Delays.SkillRCooldown) then
                    ExecuteSkill(Config.Events.SkillR, nil)
                    lastSkillR = tick()
                end
            end

            -- Task: Auto Pops
            if Config.Automation.AutoPops then
                pcall(function()
                    local mainGui = SafeFind(PlayerGui, "Main")
                    local hud = SafeFind(mainGui, "HUD")
                    local pops = SafeFind(hud, "Pops")
                    if pops then
                        for _, holder in ipairs(pops:GetChildren()) do
                            if holder:IsA("GuiObject") and not SafeFind(holder, "Price", true) then
                                local btn = holder:FindFirstChildWhichIsA("GuiButton", true)
                                if btn and btn.Visible and typeof(firesignal) == "function" then
                                    firesignal(btn.Activated)
                                end
                            end
                        end
                    end
                end)
            end
        end

        task.wait(Config.Delays.FastLoop)
    end
end)

-- Slow Progression Thread
task.spawn(function()
    local lastCodeTick = 0

    while State.Running do
        pcall(function()
            -- Auto Rebirth
            if Config.Automation.AutoRebirth and Remotes.Rebirth then
                local res = Remotes.Rebirth:InvokeServer()
                if res then
                    AuditLogger.Stats.RebirthsCount = AuditLogger.Stats.RebirthsCount + 1
                    AuditLogger.Record("Progression", "Rebirth", "ทำการจุติ (Rebirth) สำเร็จ")
                end
            end

            -- Auto Equip Best Pets
            if Config.Automation.AutoEquipBestPets and Remotes.PetAction then
                Remotes.PetAction:InvokeServer(Config.Events.EquipBest)
            end

            -- Auto Fuse Pets
            if Config.Automation.AutoFusePets and FuseLogic and Remotes.Fuse and StateMod then
                local pets = (StateMod.pets and StateMod.pets()) or {}
                local petTiers = (StateMod.petTiers and StateMod.petTiers()) or {}
                local groups = (FuseLogic.groups and FuseLogic.groups(pets, petTiers)) or {}
                for _, g in ipairs(groups) do
                    local uids = g.uids or g
                    if #uids >= 4 then
                        Remotes.Fuse:InvokeServer(Config.Events.FuseAction, {tostring(uids[1]), tostring(uids[2]), tostring(uids[3]), tostring(uids[4])})
                        AuditLogger.Stats.PetsFused = AuditLogger.Stats.PetsFused + 1
                        AuditLogger.Record("Pets", "Pet Fused", "รวมสัตว์เลี้ยง 4 ตัวระดับสูงสำเร็จ")
                        HumanWait(0.2, 0.4)
                        break
                    end
                end
            end

            -- Daily, Group & Playtime Claims
            if Config.Automation.AutoClaimAll then
                if Remotes.ClaimDaily then Remotes.ClaimDaily:InvokeServer() end
                if Remotes.ClaimGroup then Remotes.ClaimGroup:InvokeServer() end
                if Remotes.ClaimReward then
                    for i = 1, 12 do Remotes.ClaimReward:InvokeServer(i) end
                end
            end

            -- Auto Redeem Codes
            if Config.Automation.AutoRedeemCodes and Remotes.RedeemCode and CodesConfig and (tick() - lastCodeTick >= 60) then
                lastCodeTick = tick()
                if CodesConfig.list then
                    for _, c in ipairs(CodesConfig.list) do
                        Remotes.RedeemCode:InvokeServer(c.code)
                        AuditLogger.Stats.CodesRedeemed = AuditLogger.Stats.CodesRedeemed + 1
                        HumanWait(0.4, 0.8)
                    end
                end
            end
        end)
        task.wait(Config.Delays.SlowLoop)
    end
end)

-- ============================================================================
-- 7. TABBED USER INTERFACE & MINIMIZE SYSTEM
-- ============================================================================
if _G.ChakraQACleanup then pcall(_G.ChakraQACleanup) end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChakraQAGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = parentGui

-- Floating Quick-Access Pill
local FloatingPill = Instance.new("TextButton")
FloatingPill.Name = "FloatingPill"
FloatingPill.Size = UDim2.new(0, 160, 0, 36)
FloatingPill.Position = UDim2.new(0.5, -80, 0, 15)
FloatingPill.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
FloatingPill.BorderSizePixel = 0
FloatingPill.Text = "⚡ Chakra QA (เปิด)"
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
PillStroke.Color = Color3.fromRGB(0, 180, 255)
PillStroke.Parent = FloatingPill

-- Main Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 360)
MainFrame.Position = UDim2.new(0.5, -260, 0.25, -180)
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
TitleLabel.Text = "⚡ CHAKRA QA CONTROLLER (ENTERPRISE)"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Size = UDim2.new(0, 280, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = TopBar

-- Minimize Button
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

-- Close Button
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
local TrainingPage = CreatePage("Training")
local PetsPage = CreatePage("Pets")
local RewardsPage = CreatePage("Rewards")
local LogsPage = CreatePage("Logs")
local SettingsPage = CreatePage("Settings")

-- Register Tabs
AddTab("การต่อสู้", "⚔️", "Combat")
AddTab("ฝึกจักระ", "🧘", "Training")
AddTab("สัตว์เลี้ยง", "🐾", "Pets")
AddTab("รางวัล", "🎁", "Rewards")
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
        AuditLogger.Record("Settings", "Toggle Changed", text .. " -> " .. (active and "เปิด" or "ปิด"))
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
AddToggleTo(CombatPage, "ลงด่านอัตโนมัติ (Auto Stages 1-15)", Config.Automation.AutoStages, function(v) Config.Automation.AutoStages = v end)
AddToggleTo(CombatPage, "ล่าบอสคุรามะ (Auto Boss & Safe Orbit)", Config.Automation.AutoBoss, function(v) Config.Automation.AutoBoss = v end)
AddToggleTo(CombatPage, "ถอยอัตโนมัติเมื่อเลือดต่ำ (Smart Retreat)", Config.Automation.AutoRetreat, function(v) Config.Automation.AutoRetreat = v end)
AddToggleTo(CombatPage, "โจมตีธรรมดา M1 (Auto Attack)", Config.Automation.AutoAttack, function(v) Config.Automation.AutoAttack = v end)
AddToggleTo(CombatPage, "สกิล E (Skill E)", Config.Automation.AutoSkillE, function(v) Config.Automation.AutoSkillE = v end)
AddToggleTo(CombatPage, "สกิล R คามุย (Skill R)", Config.Automation.AutoSkillR, function(v) Config.Automation.AutoSkillR = v end)

-- [TRAINING TAB]
AddToggleTo(TrainingPage, "ฟาร์มจุดที่ดีที่สุดอัตโนมัติ (Auto Best Train)", Config.Automation.AutoBestTrain, function(v) Config.Automation.AutoBestTrain = v end)
AddToggleTo(TrainingPage, "ฝึกวิชาพื้นฐาน (Auto Train)", Config.Automation.AutoTrain, function(v) Config.Automation.AutoTrain = v end)
AddToggleTo(TrainingPage, "กดรับคูณพลังงาน (Auto Pops)", Config.Automation.AutoPops, function(v) Config.Automation.AutoPops = v end)
AddButtonTo(TrainingPage, "🚀 วาปไปจุดฝึกที่ดีที่สุดทันที", Color3.fromRGB(30, 130, 80), function()
    TeleportToBestTrainingSpot()
    AuditLogger.Record("Training", "Manual Teleport", "วาปไปจุดฝึกที่ดีที่สุด")
end)

-- [PETS TAB]
AddToggleTo(PetsPage, "ผสมสัตว์เลี้ยง 4 ตัวอัตโนมัติ (Auto Fuse Pets)", Config.Automation.AutoFusePets, function(v) Config.Automation.AutoFusePets = v end)
AddToggleTo(PetsPage, "สวมใส่สัตว์เลี้ยงที่ดีที่สุด (Best Pets)", Config.Automation.AutoEquipBestPets, function(v) Config.Automation.AutoEquipBestPets = v end)
AddToggleTo(PetsPage, "สวมใส่ออร่าที่ดีที่สุด (Best Aura)", Config.Automation.AutoEquipBestAura, function(v) Config.Automation.AutoEquipBestAura = v end)
AddToggleTo(PetsPage, "สวมใส่เนตรที่ดีที่สุด (Best Eye)", Config.Automation.AutoEquipBestEye, function(v) Config.Automation.AutoEquipBestEye = v end)

-- [REWARDS TAB]
AddToggleTo(RewardsPage, "จุติอัตโนมัติ (Auto Rebirth)", Config.Automation.AutoRebirth, function(v) Config.Automation.AutoRebirth = v end)
AddToggleTo(RewardsPage, "รับของขวัญและเควสต์ทั้งหมด (Claim All)", Config.Automation.AutoClaimAll, function(v) Config.Automation.AutoClaimAll = v end)
AddToggleTo(RewardsPage, "แลกโค้ดทั้งหมดอัตโนมัติ (Redeem Codes)", Config.Automation.AutoRedeemCodes, function(v) Config.Automation.AutoRedeemCodes = v end)

-- [LOGS TAB & REAL-TIME STATS]
local StatsBox = Instance.new("Frame")
StatsBox.Size = UDim2.new(1, -6, 0, 50)
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
            StatsLabel.Text = string.format("📊 จุติ: %d ครั้ง | เคลียร์ด่าน: %d รอบ | ตีบอส: %d Hit | รวมสัตว์: %d ตัว\n⏱️ เวลาทำงาน: %d วินาที | สถานะ: %s",
                AuditLogger.Stats.RebirthsCount, AuditLogger.Stats.StagesCleared, AuditLogger.Stats.BossAttacks, AuditLogger.Stats.PetsFused,
                os.time() - AuditLogger.Stats.StartTime, State.StatusText)
        end)
        task.wait(0.5)
    end
end)

local LogContainer = Instance.new("ScrollingFrame")
LogContainer.Size = UDim2.new(1, -6, 0, 240)
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
    AuditLogger.Record("System", "Shutdown", "ทำความสะอาด GUI และยกเลิกการเชื่อมต่อ")
    pcall(function() ScreenGui:Destroy() end)
    pcall(function() FloatingPill:Destroy() end)
    _G.ChakraQACleanup = nil
end

_G.ChakraQACleanup = Cleanup
CloseBtn.MouseButton1Click:Connect(Cleanup)

AuditLogger.Record("Loader", "Ready", "Chakra QA Enterprise Hub V12 พร้อมทำงาน!")
