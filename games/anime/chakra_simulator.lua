--[[
    ========================================================================
    [PREMIUM ROBLOX QA AUTOMATION & NPC CONTROLLER - STAGES & COMBAT PRO]
    Target Game: Chakra Training Simulator (Anime / Naruto)
    Architecture: Ground Level Zone-Trigger Compliant | Stage Filtering | Smooth Fast Loop
    Version: 9.3.0 (Anti-Stage-1-Stuck & Safe Progression Edition)
    ========================================================================
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 0. CLEANUP PREVIOUS INSTANCE
if _G.ChakraQACleanup then
    pcall(_G.ChakraQACleanup)
end

local existing = PlayerGui:FindFirstChild("ChakraQAGui")
if existing then existing:Destroy() end

-- 1. CLIENT MODULES BINDING
local Input = nil
pcall(function() Input = require(LocalPlayer.PlayerScripts.Client.Input) end)

local Enemies = nil
pcall(function() Enemies = require(LocalPlayer.PlayerScripts.Client.Enemies) end)

local StateMod = nil
pcall(function() StateMod = require(LocalPlayer.PlayerScripts.Client.State) end)

local World = nil
pcall(function() World = require(ReplicatedStorage.Shared.Config.World) end)

local StagesConfig = nil
pcall(function() StagesConfig = require(ReplicatedStorage.Shared.Config.Stages) end)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TrainRemote = Remotes:WaitForChild("Train")
local CastRemote = Remotes:WaitForChild("Cast")
local RebirthFunc = Remotes:WaitForChild("Rebirth")
local ClaimQuestFunc = Remotes:WaitForChild("ClaimQuest")
local ClaimRewardFunc = Remotes:WaitForChild("ClaimReward")
local ClaimDailyFunc = Remotes:WaitForChild("ClaimDaily")
local ClaimGroupFunc = Remotes:WaitForChild("ClaimGroup")
local PetActionFunc = Remotes:WaitForChild("PetAction")
local EquipAuraFunc = Remotes:WaitForChild("EquipAura")
local UnlockEyeRemote = Remotes:WaitForChild("UnlockEye")
local EquipRemote = Remotes:WaitForChild("Equip")
local PadRemote = Remotes:WaitForChild("Pad")

-- 2. CONFIGURATION
local Config = {
    Tag = "ChakraQA",
    Automation = {
        AutoTrain = true,          -- ฝึกจักระ
        AutoAttack = true,         -- โจมตีฟันดาบ/หมัด (มีแอนิเมชันเต็มรูปแบบ)
        AutoSkillE = true,         -- สกิล E
        AutoSkillR = true,         -- สกิล R (Kamui)
        AutoStages = true,         -- ระบบลงด่านสเตจอัตโนมัติ (Stage 1-15)
        AutoRetreat = true,        -- ถอยไปเก็บถ้วยด่านก่อนหน้าเมื่อสู้ไม่ไหว
        AutoPops = true,           -- กดคูณจักระรูปไฟ
        AutoRebirth = true,        -- เกิดใหม่อัตโนมัติ
        AutoEquipBestAura = true,  -- ใส่ออร่าที่ดีที่สุด
        AutoEquipBestEye = true,   -- ใส่ดวงตาที่ดีที่สุด
        AutoEquipBestPets = true,  -- ใส่สัตว์เลี้ยงที่ดีที่สุด
        AutoClaimAll = true,       -- เคลมของขวัญและเควสต์
    },
    Delays = {
        FastLoop = 0.04,
        SlowLoop = 2.5,
        SkillECooldown = 3.5,
        SkillRCooldown = 6.0,
    },
    Stages = {
        MaxCombatTime = 8,             -- สู้มอนสเตอร์เกิน 8 วินาที ถือว่าสู้ไม่ไหว (ถอยทันที)
        HealthRetreatThreshold = 0.35, -- เลือดต่ำกว่า 35% ให้ถอยทันที
        MinRetreatStage = 8,           -- ด่าน 1-7 มอนสเตอร์อ่อน เลือดจะฟื้นฟูเองอัตโนมัติ ห้ามถอยเด็ดขาด ป้องกันการติดลูปด่านแรก
        PadDwellTime = 0.8,            -- ยืนบนแท่นทอง 0.8 วินาทีให้เห็นการเก็บถ้วยชัดเจน
        FloorY = 3.5,                  -- ระดับความสูงมาตรฐานที่ระบบทริกเกอร์ของเกมจับได้ 100%
    }
}

local State = {
    Running = true,
    CurrentStage = 1,
    LastStage = 0,
    StageStartTime = tick(),
    IsRetreating = false,
    StartingStageOne = false,
    StatusText = "พร้อมทำงาน",
}

-- 3. ATTACK & SKILL ENGINE
local function GetAimPos(targetPos)
    if targetPos then return targetPos end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
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

    if Input and Input.press then
        pcall(function() Input.press("attack") end)
    end

    pcall(function()
        CastRemote:FireServer("attack", aimPos, targetId)
    end)
end

local function ExecuteSkill(slot, target)
    local aimPos = target and target.pos or GetAimPos()
    local targetId = target and target.id or nil

    if Input and Input.press then
        pcall(function() Input.press(slot) end)
    end

    pcall(function()
        CastRemote:FireServer(slot, aimPos, targetId)
    end)
end

-- 4. SMART STAGE RUNNER WITH STAGE-SPECIFIC TARGETING
local function GetStageCenterZ(stageNum)
    if World and World.stageStart and World.stageEnd then
        local s = World.stageStart(stageNum)
        local e = World.stageEnd(stageNum)
        return (s + e) / 2
    end
    return -75 - (stageNum - 1) * 90
end

local function GetEnemiesForStage(targetStage)
    local rawList = Enemies and Enemies.list() or {}
    local stageEnemies = {}

    for _, e in ipairs(rawList) do
        if e.pos then
            local eStage = (World and World.stageAt) and World.stageAt(e.pos.Z)
            if eStage == targetStage then
                table.insert(stageEnemies, e)
            end
        end
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and #stageEnemies > 1 then
        table.sort(stageEnemies, function(a, b)
            return (root.Position - a.pos).Magnitude < (root.Position - b.pos).Magnitude
        end)
    end

    return stageEnemies
end

local function StartStageOneProperly()
    if State.StartingStageOne or State.IsRetreating then return end
    State.StartingStageOne = true

    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        State.StatusText = "🚀 กำลังก้าวเข้าสู่ Stage 1..."
        -- ก้าวผ่านประตูที่ความสูงระดับพื้น Y = 3.5 เพื่อให้เซิร์ฟเวอร์ทริกเกอร์ InStages แน่นอน
        root.CFrame = CFrame.new(0, Config.Stages.FloorY, -20)
        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.12)
        root.CFrame = CFrame.new(0, Config.Stages.FloorY, -40)
        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.15)

        -- เดินเข้าสู่ตำแหน่งกลางด่าน Stage 1
        root.CFrame = CFrame.new(0, Config.Stages.FloorY, -75)
        root.AssemblyLinearVelocity = Vector3.zero
        State.CurrentStage = 1
        State.LastStage = 1
        State.StageStartTime = tick()
    end)

    task.wait(0.3)
    State.StartingStageOne = false
end

local function RetreatAndClaimTrophies(retreatStage)
    if State.IsRetreating then return end
    State.IsRetreating = true

    pcall(function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if hum and hum.Health <= 0 then
            StartStageOneProperly()
            return
        end

        if root and retreatStage and retreatStage >= 1 then
            State.StatusText = string.format("🏆 กำลังเหยียบแท่นทองด่านที่ผ่าน (Stage %d)...", retreatStage)
            local padPos = nil
            if World and World.padPosition then
                pcall(function() padPos = World.padPosition(retreatStage, "gold") end)
            end
            if not padPos then
                padPos = Vector3.new(20, 0.6, -111 - (retreatStage - 1) * 90)
            end

            -- วาร์ปไปยืนบนกึ่งกลางแท่นรับถ้วย PadGold ที่ระดับพื้น
            root.CFrame = CFrame.new(padPos + Vector3.new(0, 1.2, 0))
            root.AssemblyLinearVelocity = Vector3.zero
            
            -- ยิงคำสั่งเก็บถ้วยเข้าเซิร์ฟเวอร์
            pcall(function()
                PadRemote:FireServer(retreatStage, "gold")
            end)
            
            -- ยืนอยู่บนแท่นให้เห็นการรับถ้วยรางวัลชัดเจน
            task.wait(Config.Stages.PadDwellTime)
        end
    end)

    State.IsRetreating = false
    task.wait(0.08)
    StartStageOneProperly()
end

local function ProcessStageRunner()
    if State.IsRetreating then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end

    local inStages = LocalPlayer:GetAttribute("InStages")
    local runStage = LocalPlayer:GetAttribute("RunStage") or 0
    local runCleared = LocalPlayer:GetAttribute("RunCleared") or 0
    local hpPercent = hum.Health / math.max(hum.MaxHealth, 1)

    -- ถ้าไม่ได้อยู่ในด่าน หรืออยู่นอก Stage ให้เริ่ม Stage 1 ที่ระดับพื้น
    if not inStages or runStage == 0 then
        StartStageOneProperly()
        return
    end

    State.CurrentStage = runStage

    -- ตรวจสอบการเปลี่ยนด่าน เพื่อรีเซ็ตตัวจับเวลาต่อสู้
    if State.CurrentStage ~= State.LastStage then
        State.LastStage = State.CurrentStage
        State.StageStartTime = tick()
    end

    local timeInCombat = tick() - State.StageStartTime
    local isDowned = LocalPlayer:GetAttribute("Downed") == true

    -- ตรวจสอบเงื่อนไข "สู้ไม่ไหว" (เฉพาะด่านสูง >= MinRetreatStage เท่านั้น เพื่อป้องกันการถอยในด่าน 1-7 ที่มอนสเตอร์อ่อน)
    -- ป้องกันปัญหาตัวละครวนลูปติดอยู่ที่ด่านแรกๆ เวลาเลือดยังไม่เต็มจากรอบที่แล้ว
    local minStage = Config.Stages.MinRetreatStage or 8
    if Config.Automation.AutoRetreat and runStage >= minStage and runCleared >= 1 then
        local healthCrit = (hpPercent <= Config.Stages.HealthRetreatThreshold) or isDowned
        local timeCrit = (timeInCombat >= Config.Stages.MaxCombatTime)

        if healthCrit or timeCrit then
            local retreatTarget = runCleared
            RetreatAndClaimTrophies(retreatTarget)
            return
        end
    end

    -- ดึงเฉพาะมอนสเตอร์ของด่านปัจจุบันเท่านั้น
    local enemyList = GetEnemiesForStage(runStage)
    local enemyCount = #enemyList

    if enemyCount > 0 then
        local nearest = enemyList[1]

        -- ประชิดมอนสเตอร์ที่ระดับพื้น Y = 3.5 ในระยะ 5 studs
        local combatPos = nearest.pos + Vector3.new(0, 0.5, 5)
        if (root.Position - combatPos).Magnitude > 8 then
            root.CFrame = CFrame.new(combatPos)
            root.AssemblyLinearVelocity = Vector3.zero
        end

        State.StatusText = string.format("⚔️ Stage %d | มอนในด่าน %d ตัว | เวลา: %.1fs | HP: %d%%", 
            runStage, enemyCount, timeInCombat, math.floor(hpPercent * 100))

        ExecuteAttack(nearest)
        ExecuteSkill("E", nearest)
        ExecuteSkill("R", nearest)
    else
        -- ถ้าในด่านปัจจุบันไม่มีมอนสเตอร์แล้ว
        if timeInCombat > 0.3 then
            State.StatusText = string.format("🎉 เคลียร์ Stage %d สำเร็จ!", runStage)
            
            -- ถ้าเคลียร์ถึงด่าน 15 (ด่านสุดท้าย) ให้เก็บถ้วยด่าน 15 แล้วเริ่มใหม่
            if runStage >= 15 then
                RetreatAndClaimTrophies(15)
                return
            end

            -- พุ่งข้ามเข้าสู่กึ่งกลางด่านถัดไปที่ระดับพื้น
            local nextStage = runStage + 1
            root.CFrame = CFrame.new(0, Config.Stages.FloorY, GetStageCenterZ(nextStage))
            root.AssemblyLinearVelocity = Vector3.zero
            State.LastStage = nextStage
            State.StageStartTime = tick()
        else
            -- มอนสเตอร์กำลังสปอว์น ให้ยืนประจำที่กึ่งกลางด่านรอ
            root.CFrame = CFrame.new(0, Config.Stages.FloorY, GetStageCenterZ(runStage))
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

-- 5. AUTO POPS MULTIPLIER
local function ProcessAutoPops()
    local main = PlayerGui:FindFirstChild("Main")
    local hud = main and main:FindFirstChild("HUD")
    local pops = hud and hud:FindFirstChild("Pops")
    if not pops then return end

    for _, holder in ipairs(pops:GetChildren()) do
        if holder:IsA("GuiObject") and not holder:FindFirstChild("Price", true) then
            local btn = holder:FindFirstChildOfClass("GuiButton", true)
                or holder:FindFirstChildOfClass("ImageButton", true)
                or holder:FindFirstChildOfClass("TextButton", true)
            if btn and btn.Visible then
                if firesignal then pcall(function() firesignal(btn.Activated) end) end
                if getconnections then
                    pcall(function()
                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                    end)
                end
                pcall(function()
                    local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
                    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                    task.wait(0.01)
                    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
                end)
            end
        end
    end
end

-- 6. PERIODIC AUTOMATIONS (EQUIP BEST AURA, EYE, PETS, REBIRTH)
local function DoRebirth()
    pcall(function() RebirthFunc:InvokeServer() end)
end

-- ฟังก์ชันใส่ออร่าที่ดีที่สุด
local function DoEquipBestAura()
    local aurasMod = ReplicatedStorage.Shared.Config:FindFirstChild("Auras")
    if not aurasMod or not StateMod then return end
    local okA, Auras = pcall(require, aurasMod)
    if not okA or not Auras then return end

    local totalWins = StateMod.number("TotalWins") or 0
    local owned = StateMod.ownedAuras and StateMod.ownedAuras() or {}
    local currentAura = StateMod.string("Aura")

    local function HasAuraUnlocked(a)
        if not Auras.isOut(a) then return false end
        if a.pass and LocalPlayer:GetAttribute("Pass_" .. a.pass) == true then return true end
        if a.skip and LocalPlayer:GetAttribute("Pass_" .. a.skip) == true then return true end
        if a.exclusive then return owned[a.id] == true end
        return totalWins >= (a.trophies or 0)
    end

    local bestAura = nil
    for _, a in ipairs(Auras.list or {}) do
        if HasAuraUnlocked(a) then
            if not bestAura or (a.mult or 1) > (bestAura.mult or 1) then
                bestAura = a
            end
        end
    end

    if bestAura and bestAura.id ~= currentAura then
        pcall(function() EquipAuraFunc:InvokeServer(bestAura.id) end)
    end
end

local function DoEquipBestEye()
    local eyesMod = ReplicatedStorage.Shared.Config:FindFirstChild("Eyes")
    if not eyesMod or not StateMod then return end
    local okE, Eyes = pcall(require, eyesMod)
    if not okE or not Eyes then return end

    local totalWins = StateMod.number("TotalWins") or 0
    local myEyes = StateMod.eyes and StateMod.eyes() or {}
    local currentEye = StateMod.string("Eye")
    local currentWorld = StateMod.number("World", 1) or 1

    local bestEye = nil
    for _, eye in ipairs(Eyes.list or {}) do
        local isUnlocked = myEyes[eye.id] ~= nil
        local worldOk = (eye.world or 1) <= currentWorld
        local canUnlock = worldOk and (totalWins >= (eye.wins or 0)) and not eye.pass and not eye.boss and not eye.exclusive

        if isUnlocked or canUnlock then
            bestEye = eye
        end
    end

    if bestEye and bestEye.id ~= currentEye then
        if myEyes[bestEye.id] == nil then
            pcall(function() UnlockEyeRemote:FireServer(bestEye.id) end)
            task.wait(0.15)
        end
        pcall(function() EquipRemote:FireServer(bestEye.id) end)
    end
end

local function DoEquipBestPets()
    pcall(function() PetActionFunc:InvokeServer("equipBest") end)
end

local function DoClaimAll()
    pcall(function() ClaimDailyFunc:InvokeServer() end)
    pcall(function() ClaimGroupFunc:InvokeServer() end)
    for i = 1, 12 do pcall(function() ClaimRewardFunc:InvokeServer(i) end) end

    if StateMod and StateMod.quests then
        for _, kind in ipairs({"daily", "weekly"}) do
            for _, q in ipairs(StateMod.quests(kind) or {}) do
                if q.done and not q.claimed and q.slot then
                    pcall(function() ClaimQuestFunc:InvokeServer(kind, q.slot) end)
                end
            end
        end
    end
end

-- 7. THREAD WORKERS
-- Fast Worker Loop
task.spawn(function()
    local lastSkillE = 0
    local lastSkillR = 0

    while State.Running do
        if Config.Automation.AutoStages then
            pcall(ProcessStageRunner)
        else
            if Config.Automation.AutoTrain then
                pcall(function()
                    if Input and Input.autoClick then
                        Input.autoClick()
                    else
                        TrainRemote:FireServer()
                    end
                end)
            end

            if Config.Automation.AutoAttack then
                ExecuteAttack(nil)
            end

            if Config.Automation.AutoSkillE and (tick() - lastSkillE >= Config.Delays.SkillECooldown) then
                ExecuteSkill("E", nil)
                lastSkillE = tick()
            end

            if Config.Automation.AutoSkillR and (tick() - lastSkillR >= Config.Delays.SkillRCooldown) then
                ExecuteSkill("R", nil)
                lastSkillR = tick()
            end
        end

        if Config.Automation.AutoPops then
            pcall(ProcessAutoPops)
        end

        task.wait(Config.Delays.FastLoop)
    end
end)

-- Slow Worker Loop
task.spawn(function()
    while State.Running do
        if Config.Automation.AutoRebirth then
            pcall(DoRebirth)
        end
        if Config.Automation.AutoEquipBestAura then
            pcall(DoEquipBestAura)
        end
        if Config.Automation.AutoEquipBestEye then
            pcall(DoEquipBestEye)
        end
        if Config.Automation.AutoEquipBestPets then
            pcall(DoEquipBestPets)
        end
        if Config.Automation.AutoClaimAll then
            pcall(DoClaimAll)
        end

        task.wait(Config.Delays.SlowLoop)
    end
end)

-- 8. MODERN USER INTERFACE
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChakraQAGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 330, 0, 480)
MainFrame.Position = UDim2.new(0.5, -165, 0.18, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.5
MainStroke.Color = Color3.fromRGB(50, 55, 78)
MainStroke.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3 = Color3.fromRGB(24, 27, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Text = "⚡ Chakra QA Hub (Stage & Combat Pro v9.2)"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Size = UDim2.new(1, -40, 1, 0)
TitleLabel.Position = UDim2.new(0, 12, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0, 7)
CloseBtn.BackgroundColor3 = Color3.fromRGB(42, 45, 60)
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    State.Running = false
    ScreenGui:Destroy()
end)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -46)
Content.Position = UDim2.new(0, 8, 0, 40)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(70, 75, 100)
Content.CanvasSize = UDim2.new(0, 0, 0, 820)
Content.Parent = MainFrame

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 5)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Content

-- LIVE STATUS BANNER
local StatusBox = Instance.new("Frame")
StatusBox.Size = UDim2.new(1, 0, 0, 36)
StatusBox.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
StatusBox.BorderSizePixel = 0
StatusBox.Parent = Content

local StatusBoxCorner = Instance.new("UICorner")
StatusBoxCorner.CornerRadius = UDim.new(0, 6)
StatusBoxCorner.Parent = StatusBox

local StatusBoxStroke = Instance.new("UIStroke")
StatusBoxStroke.Thickness = 1
StatusBoxStroke.Color = Color3.fromRGB(45, 52, 75)
StatusBoxStroke.Parent = StatusBox

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(1, -12, 1, 0)
StatusLabel.Position = UDim2.new(0, 6, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.TextSize = 10
StatusLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Text = "สถานะ: กำลังเริ่มต้น..."
StatusLabel.Parent = StatusBox

task.spawn(function()
    while State.Running do
        pcall(function()
            StatusLabel.Text = "📌 " .. State.StatusText
        end)
        task.wait(0.15)
    end
end)

local function AddSection(txt, col)
    local l = Instance.new("TextLabel")
    l.Text = txt
    l.Font = Enum.Font.GothamBold
    l.TextSize = 11
    l.TextColor3 = col or Color3.fromRGB(255, 170, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 0, 20)
    l.BackgroundTransparency = 1
    l.Parent = Content
end

local function AddToggle(text, initVal, onChange)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.Parent = Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local active = initVal
    local function Refresh()
        if active then
            btn.BackgroundColor3 = Color3.fromRGB(35, 135, 70)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Text = "🟢 " .. text .. " : [เปิด]"
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 33, 46)
            btn.TextColor3 = Color3.fromRGB(165, 170, 185)
            btn.Text = "⚪ " .. text .. " : [ปิด]"
        end
    end
    Refresh()

    btn.MouseButton1Click:Connect(function()
        active = not active
        Refresh()
        onChange(active)
    end)
end

local function AddButton(text, bgCol, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = bgCol or Color3.fromRGB(38, 44, 62)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Parent = Content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(onClick)
end

-- SECTIONS
AddSection("⚔️ 1. AUTO STAGES (ระบบลงด่านสเตจ & ไหลลื่นระดับพื้น)", Color3.fromRGB(255, 75, 75))
AddToggle("ลงด่านสเตจฟาร์มมอนอัตโนมัติ (Auto Stages)", Config.Automation.AutoStages, function(v) 
    Config.Automation.AutoStages = v 
end)
AddToggle("ถอยเก็บถ้วยด่านก่อนหน้าเมื่อสู้ไม่ไหว (Smart Retreat)", Config.Automation.AutoRetreat, function(v) 
    Config.Automation.AutoRetreat = v 
end)
AddButton("🏆 ถอยไปเก็บถ้วยด่านก่อนหน้าทันที (Retreat & Claim)", Color3.fromRGB(160, 100, 30), function()
    local runCleared = LocalPlayer:GetAttribute("RunCleared") or 0
    RetreatAndClaimTrophies(runCleared)
end)
AddButton("🚀 วาร์ปเข้าสู่ด่าน Stage 1 ทันที", Color3.fromRGB(140, 35, 35), function()
    StartStageOneProperly()
end)
AddButton("🏠 วาร์ปกลับจุดศูนย์กลาง (Hub Spawn)", Color3.fromRGB(60, 60, 80), function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = CFrame.new(0, 4, 46) end
end)

AddSection("⚡ 2. ATTACK & COMBAT (โจมตีและพลัง)", Color3.fromRGB(255, 170, 0))
AddToggle("Auto Attack (M1 โจมตี/แอนิเมชันเต็ม)", Config.Automation.AutoAttack, function(v) Config.Automation.AutoAttack = v end)
AddToggle("Auto Skill E (สกิลปล่อยพลัง)", Config.Automation.AutoSkillE, function(v) Config.Automation.AutoSkillE = v end)
AddToggle("Auto Skill R (คามุย Kamui)", Config.Automation.AutoSkillR, function(v) Config.Automation.AutoSkillR = v end)
AddToggle("Auto Train (ฝึกจักระรวดเร็ว)", Config.Automation.AutoTrain, function(v) Config.Automation.AutoTrain = v end)

AddSection("🌀 3. PROGRESSION & REBIRTH", Color3.fromRGB(255, 100, 255))
AddToggle("เกิดใหม่อัตโนมัติ (Auto Rebirth)", Config.Automation.AutoRebirth, function(v) Config.Automation.AutoRebirth = v end)
AddButton("🌀 สั่งเกิดใหม่ทันที (Rebirth Now)", Color3.fromRGB(150, 40, 150), function() pcall(DoRebirth) end)

AddSection("💫 4. BEST GEAR (ออร่า & ดวงตา & สัตว์เลี้ยง)", Color3.fromRGB(120, 220, 255))
AddToggle("ใส่ออร่าที่ดีที่สุด ออโต้ (Best Aura)", Config.Automation.AutoEquipBestAura, function(v) Config.Automation.AutoEquipBestAura = v end)
AddButton("✨ ใส่ออร่าที่ดีที่สุดทันที (Equip Best Aura)", Color3.fromRGB(40, 120, 180), function() pcall(DoEquipBestAura) end)
AddToggle("ใส่ดวงตาที่ดีที่สุด ออโต้ (Best Eye)", Config.Automation.AutoEquipBestEye, function(v) Config.Automation.AutoEquipBestEye = v end)
AddToggle("ใส่สัตว์เลี้ยงที่ดีที่สุด ออโต้ (Best Pets)", Config.Automation.AutoEquipBestPets, function(v) Config.Automation.AutoEquipBestPets = v end)

AddSection("🔥 5. MULTIPLIER & REWARDS", Color3.fromRGB(255, 215, 0))
AddToggle("กดคูณจักระออโต้ (Pops Multipliers)", Config.Automation.AutoPops, function(v) Config.Automation.AutoPops = v end)
AddToggle("รับภารกิจ & รางวัลเวลารอ ออโต้", Config.Automation.AutoClaimAll, function(v) Config.Automation.AutoClaimAll = v end)

_G.ChakraQACleanup = function()
    State.Running = false
    pcall(function() ScreenGui:Destroy() end)
end
