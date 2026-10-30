--[[
    ========================================================================
    [PREMIUM ROBLOX QA AUTOMATION & NPC CONTROLLER - STAGES & COMBAT PRO]
    Target Game: Chakra Training Simulator (Anime / Naruto)
    Architecture: Ground Level Zone-Trigger Compliant | Stage Filtering | Smooth Fast Loop
    Version: 9.8.0 (Update 2 & 3 Support: World 5, Kurama Boss, Pet Fuser & Code Automation)
    ========================================================================
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local parentGui = nil
pcall(function()
    if gethui then
        parentGui = gethui()
    elseif game:GetService("CoreGui") then
        parentGui = game:GetService("CoreGui")
    end
end)
if not parentGui then
    parentGui = PlayerGui
end

-- 0. CLEANUP PREVIOUS INSTANCE
if _G.ChakraQACleanup then
    pcall(_G.ChakraQACleanup)
end

local existing = parentGui:FindFirstChild("ChakraQAGui") or PlayerGui:FindFirstChild("ChakraQAGui")
if existing then pcall(function() existing:Destroy() end) end

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

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5) or ReplicatedStorage:FindFirstChild("Remotes")
local TrainRemote = Remotes and (Remotes:FindFirstChild("Train") or Remotes:WaitForChild("Train", 3))
local CastRemote = Remotes and (Remotes:FindFirstChild("Cast") or Remotes:WaitForChild("Cast", 3))
local RebirthFunc = Remotes and (Remotes:FindFirstChild("Rebirth") or Remotes:WaitForChild("Rebirth", 3))
local ClaimQuestFunc = Remotes and (Remotes:FindFirstChild("ClaimQuest") or Remotes:WaitForChild("ClaimQuest", 3))
local ClaimRewardFunc = Remotes and (Remotes:FindFirstChild("ClaimReward") or Remotes:WaitForChild("ClaimReward", 3))
local ClaimDailyFunc = Remotes and (Remotes:FindFirstChild("ClaimDaily") or Remotes:WaitForChild("ClaimDaily", 3))
local ClaimGroupFunc = Remotes and (Remotes:FindFirstChild("ClaimGroup") or Remotes:WaitForChild("ClaimGroup", 3))
local PetActionFunc = Remotes and (Remotes:FindFirstChild("PetAction") or Remotes:WaitForChild("PetAction", 3))
local EquipAuraFunc = Remotes and (Remotes:FindFirstChild("EquipAura") or Remotes:WaitForChild("EquipAura", 3))
local UnlockEyeRemote = Remotes and (Remotes:FindFirstChild("UnlockEye") or Remotes:WaitForChild("UnlockEye", 3))
local EquipRemote = Remotes and (Remotes:FindFirstChild("Equip") or Remotes:WaitForChild("Equip", 3))
local PadRemote = Remotes and (Remotes:FindFirstChild("Pad") or Remotes:WaitForChild("Pad", 3))
local TeleportRemote = Remotes and (Remotes:FindFirstChild("Teleport") or Remotes:WaitForChild("Teleport", 3))
local FuseFunc = Remotes and (Remotes:FindFirstChild("Fuse") or Remotes:WaitForChild("Fuse", 3))
local RedeemCodeFunc = Remotes and (Remotes:FindFirstChild("RedeemCode") or Remotes:WaitForChild("RedeemCode", 3))
local BossRemote = Remotes and (Remotes:FindFirstChild("Boss") or Remotes:WaitForChild("Boss", 3))
local BossShopFunc = Remotes and (Remotes:FindFirstChild("BossShop") or Remotes:WaitForChild("BossShop", 3))

local WorldsInfo = {
    [1] = {name = "Shinobi Lands", color = Color3.fromRGB(69, 200, 255), desc = "โลก 1: ดินแดนนินจา"},
    [2] = {name = "Celestial Realm", color = Color3.fromRGB(180, 92, 255), desc = "โลก 2: แดนสวรรค์"},
    [3] = {name = "Blood Moon", color = Color3.fromRGB(255, 46, 77), desc = "โลก 3: พระจันทร์เลือด"},
    [4] = {name = "Frozen Abyss", color = Color3.fromRGB(63, 184, 255), desc = "โลก 4: แดนเยือกแข็ง"},
    [5] = {name = "Cosmic Void", color = Color3.fromRGB(155, 92, 255), desc = "โลก 5: มิติคอสมิก"},
}

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
        AutoRedeemCodes = true,    -- แลกโค้ดอัตโนมัติ (Update Codes)
        AutoFusePets = true,       -- รวมสัตว์เลี้ยง 4 ตัวเป็นระดับสูง (Update 3 Fusing)
        AutoBoss = false,          -- ร่วมตีบอสคุรามะอัตโนมัติ (Update 2 Boss)
    },
    Delays = {
        FastLoop = 0.04,
        SlowLoop = 2.5,
        SkillECooldown = 3.5,
        SkillRCooldown = 6.0,
    },
    Stages = {
        TargetWorld = nil,             -- โลกเป้าหมาย (ถ้าไม่ระบุ จะฟาร์มโลกที่ตัวละครยืนอยู่ปัจจุบันตลอดไป)
        AutoDetectWorld = true,        -- ซิงค์พิกัดตามโลกที่ตัวละครยืนอยู่อัตโนมัติ
        PadType = "purple",            -- ประเภทแท่น ("purple" = แท่นคูณ 3, "gold" = แท่นทองปกติ)
        MaxCombatTime = 8,             -- สู้มอนสเตอร์เกิน 8 วินาที ถือว่าสู้ไม่ไหว (ถอยทันที)
        HealthRetreatThreshold = 0.45, -- เลือดต่ำกว่า 45% ให้ถอยไปเก็บถ้วยทันที ป้องกันโดนบอสตีตาย
        PadDwellTime = 0.8,            -- ยืนบนแท่น 0.8 วินาทีให้เห็นการเก็บถ้วยชัดเจน
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

-- 4. SMART STAGE RUNNER WITH MULTI-WORLD 1-4 SUPPORT
local function GetCurrentWorld()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and World and World.worldAt then
        local w = World.worldAt(root.Position)
        if w and w >= 1 and w <= 5 then return w end
    end
    local attrW = LocalPlayer:GetAttribute("World")
    if attrW and attrW >= 1 and attrW <= 5 then return attrW end
    if StateMod and StateMod.number then
        local stW = StateMod.number("World")
        if stW and stW >= 1 and stW <= 5 then return stW end
    end
    return 1
end

local function GetWorldOrigin(worldId)
    local w = worldId or GetCurrentWorld()
    if World and World.origin then
        local ok, orig = pcall(function() return World.origin(w) end)
        if ok and orig then return orig end
    end
    local origins = {0, 3000, 6000, 9000, 12000}
    local x = origins[w] or 0
    return Vector3.new(x, 0, 0)
end

local function TeleportToWorld(targetWorldId)
    if not targetWorldId or targetWorldId < 1 or targetWorldId > 5 then return false end
    local curWorld = GetCurrentWorld()
    if curWorld == targetWorldId then return true end

    local info = WorldsInfo[targetWorldId]
    local name = info and info.name or ("World " .. targetWorldId)
    State.StatusText = string.format("🌀 กำลังเปลี่ยนไปโลก %d (%s)...", targetWorldId, name)

    if TeleportRemote then
        pcall(function() TeleportRemote:FireServer(targetWorldId) end)
        task.wait(1.5)
    end

    local afterWorld = GetCurrentWorld()
    if afterWorld == targetWorldId then
        return true
    else
        State.StatusText = string.format("⚠️ ไม่สามารถไปโลก %d ได้ (ยังล็อคอยู่/ต้องผ่านด่าน 15 โลกก่อนหน้า)", targetWorldId)
        return false
    end
end

local function GetStageCenterZ(stageNum)
    if World and World.stageStart and World.stageEnd then
        local s = World.stageStart(stageNum)
        local e = World.stageEnd(stageNum)
        return (s + e) / 2
    end
    return -75 - (stageNum - 1) * 90
end

local function GetStageCenter(stageNum, worldId)
    local curWorld = worldId or GetCurrentWorld()
    local originX = GetWorldOrigin(curWorld).X
    local z = GetStageCenterZ(stageNum)
    return Vector3.new(originX, Config.Stages.FloorY, z)
end

local function GetEnemiesForStage(targetStage)
    local rawList = Enemies and Enemies.list() or {}
    local stageEnemies = {}
    local curWorld = GetCurrentWorld()

    for _, e in ipairs(rawList) do
        if e.pos then
            local eStage = (World and World.stageAt) and World.stageAt(e.pos.Z)
            local eWorld = (World and World.worldAt) and World.worldAt(e.pos) or curWorld
            if eStage == targetStage and eWorld == curWorld then
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

        -- อยู่โลกไหน ให้ลงด่านโลกนั้นเสมอ ไม่มีการสลับกลับโลกเก่าเด็ดขาด
        local curWorld = GetCurrentWorld()
        local originX = GetWorldOrigin(curWorld).X
        local wName = WorldsInfo[curWorld] and WorldsInfo[curWorld].name or ("World " .. curWorld)

        State.StatusText = string.format("🚀 ก้าวเข้าสู่ Stage 1 (โลก %d: %s)...", curWorld, wName)
        -- ก้าวผ่านประตูที่ความสูงระดับพื้น Y = 3.5 ของโลกนั้นๆ
        root.CFrame = CFrame.new(originX, Config.Stages.FloorY, -20)
        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.12)
        root.CFrame = CFrame.new(originX, Config.Stages.FloorY, -40)
        root.AssemblyLinearVelocity = Vector3.zero
        task.wait(0.15)

        -- เดินเข้าสู่ตำแหน่งกลางด่าน Stage 1
        root.CFrame = CFrame.new(originX, Config.Stages.FloorY, -75)
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
        local curWorld = GetCurrentWorld()
        local originX = GetWorldOrigin(curWorld).X

        if hum and hum.Health <= 0 then
            StartStageOneProperly()
            return
        end

        if root and retreatStage and retreatStage >= 1 then
            local padType = Config.Stages.PadType or "purple"
            local isPurple = padType == "purple"
            local padName = isPurple and "แท่นม่วง x3 (คูณ 3)" or "แท่นทอง"
            State.StatusText = string.format("🏆 เหยียบ%s ด่านที่ผ่าน (โลก %d | Stage %d)...", padName, curWorld, retreatStage)

            local padPos = nil
            if World and World.padPosition then
                pcall(function()
                    local localPad = World.padPosition(retreatStage, padType)
                    if localPad then
                        padPos = Vector3.new(originX + localPad.X, localPad.Y, localPad.Z)
                    end
                end)
            end
            if not padPos then
                local padOffsetX = isPurple and -20 or 20
                padPos = Vector3.new(originX + padOffsetX, 0.6, -111 - (retreatStage - 1) * 90)
            end

            -- วาร์ปไปยืนบนกึ่งกลางแท่นรับถ้วย (PadPurple หรือ PadGold) ที่ระดับพื้น
            root.CFrame = CFrame.new(padPos + Vector3.new(0, 1.2, 0))
            root.AssemblyLinearVelocity = Vector3.zero
            
            -- ยิงคำสั่งเก็บถ้วยเข้าเซิร์ฟเวอร์
            pcall(function()
                PadRemote:FireServer(retreatStage, padType)
            end)
            task.wait(0.15)
            pcall(function()
                PadRemote:FireServer(retreatStage, padType)
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

    -- ตรวจสอบเงื่อนไข "สู้ไม่ไหว / ใกล้ตาย" (ทำงานทุกด่านที่ผ่านด่าน 1 มาแล้ว และมีแท่นทองด่านก่อนหน้าให้เก็บถ้วย)
    if Config.Automation.AutoRetreat and runStage > 1 and runCleared >= 1 then
        -- 1. วิกฤตฉุกเฉิน: เลือดต่ำกว่า 20% หรือโดน Downed ให้ถอยไปเก็บถ้วยทันทีแบบไม่มีเงื่อนไข
        local isEmergency = (hpPercent <= 0.20) or isDowned
        -- 2. สู้ไม่ไหว: เลือดลดต่ำกว่า 45% หลังจากเข้าสู้ไปแล้วเกิน 0.8 วินาที
        local isLowHpInCombat = (hpPercent <= Config.Stages.HealthRetreatThreshold) and (timeInCombat >= 0.8)
        -- 3. ตีนานเกินไป: ตีมอนเกินเวลาที่กำหนด (8 วิ) ถือว่าสู้ไม่ทัน
        local isTimeCrit = (timeInCombat >= Config.Stages.MaxCombatTime)

        if isEmergency or isLowHpInCombat or isTimeCrit then
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

            -- พุ่งข้ามเข้าสู่กึ่งกลางด่านถัดไปที่ระดับพื้นของโลกปัจจุบัน
            local curWorld = GetCurrentWorld()
            local nextStage = runStage + 1
            root.CFrame = CFrame.new(GetStageCenter(nextStage, curWorld))
            root.AssemblyLinearVelocity = Vector3.zero
            State.LastStage = nextStage
            State.StageStartTime = tick()
        else
            -- มอนสเตอร์กำลังสปอว์น ให้ยืนประจำที่กึ่งกลางด่านรอ
            local curWorld = GetCurrentWorld()
            root.CFrame = CFrame.new(GetStageCenter(runStage, curWorld))
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

    local bestEye = nil
    for _, eye in ipairs(Eyes.list or {}) do
        local isUnlocked = myEyes[eye.id] ~= nil
        local canUnlock = (totalWins >= (eye.wins or 0)) and not eye.pass and not eye.boss and not eye.exclusive

        if isUnlocked or canUnlock then
            if not bestEye or (eye.mult or 0) > (bestEye.mult or 0) then
                bestEye = eye
            end
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

-- แลกโค้ดทั้งหมดอัตโนมัติ (Update 1 & Update 2 Codes)
local lastCodeRedeemTick = 0
local function DoRedeemAllCodes()
    local codesMod = ReplicatedStorage.Shared.Config:FindFirstChild("Codes")
    if not codesMod or not RedeemCodeFunc then return end
    local okC, Codes = pcall(require, codesMod)
    if not okC or not Codes or not Codes.list then return end

    for _, c in ipairs(Codes.list) do
        pcall(function()
            RedeemCodeFunc:InvokeServer(c.code)
        end)
        task.wait(1.2)
    end
end

-- หลอมรวมสัตว์เลี้ยง 4 ตัวเป็นระดับสูงอัตโนมัติ (Update 3 Pet Fusing: Void, Rainbow, Corrupted)
local function DoAutoFusePets()
    local fuseLogicMod = ReplicatedStorage.Shared.Logic:FindFirstChild("Fuse")
    if not fuseLogicMod or not FuseFunc or not StateMod then return end
    local okF, FuseLogic = pcall(require, fuseLogicMod)
    if not okF or not FuseLogic then return end

    local pets = StateMod.pets and StateMod.pets() or {}
    local petTiers = StateMod.petTiers and StateMod.petTiers() or {}
    local groups = FuseLogic.groups and FuseLogic.groups(pets, petTiers) or {}

    for _, group in ipairs(groups) do
        if #group >= 4 then
            local uids = {group[1], group[2], group[3], group[4]}
            pcall(function()
                FuseFunc:InvokeServer("fuse", uids)
            end)
            task.wait(0.4)
        end
    end
end

-- ระบบต่อสู้กับบอสคุรามะ (Kurama Boss Event Update 2)
local function ProcessBossCombat()
    local phase = Workspace:GetAttribute("BossPhase")
    local hp = Workspace:GetAttribute("BossHp") or 0
    local inFight = (phase == "fight" and hp > 0)
    local bossCentre = Vector3.new(-3000, 0, 300)

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local dist = (Vector2.new(root.Position.X, root.Position.Z) - Vector2.new(bossCentre.X, bossCentre.Z)).Magnitude

    if inFight then
        if dist > 150 then
            -- ยังไม่ได้เข้าอารีน่าบอส: ทำการวาร์ปเข้าร่วม
            State.StatusText = "🦊 กำลังเข้าร่วมศึกตีบอสคุรามะ (Kurama Boss)..."
            if BossRemote then
                pcall(function() BossRemote:FireServer("join") end)
            end
            local bp = Workspace:FindFirstChild("BossPortals")
            local portal = bp and bp:FindFirstChildWhichIsA("Model") or (bp and bp:FindFirstChild("Portal5"))
            local prompt = portal and portal:FindFirstChild("JoinPrompt", true)
            if prompt and prompt.Enabled and fireproximityprompt then
                pcall(function() fireproximityprompt(prompt) end)
            end
            task.wait(0.5)
        else
            -- อยู่ในอารีน่าบอสแล้ว: โจมตีและปล่อยสกิลใส่บอส
            State.StatusText = string.format("🦊⚔️ กำลังรุมตีบอสคุรามะ! HP: %.1f%%", hp * 100)
            local aimPos = bossCentre + Vector3.new(0, 15, 0)
            local bossTarget = {
                boss = true,
                id = "kyubi",
                pos = aimPos
            }
            ExecuteAttack(bossTarget)
            ExecuteSkill("E", bossTarget)
            ExecuteSkill("R", bossTarget)
        end
    else
        -- บอสจบลงหรือยังไม่เริ่ม ถ้าตัวยังอยู่ในอารีน่า ให้กลับออกมา
        if dist <= 150 then
            State.StatusText = "🚪 บอสจบแล้ว กำลังออกจากอารีน่าบอส..."
            if BossRemote then
                pcall(function() BossRemote:FireServer("leave") end)
            end
            task.wait(0.5)
        end
    end
end

-- 7. THREAD WORKERS
-- Fast Worker Loop
task.spawn(function()
    local lastSkillE = 0
    local lastSkillR = 0

    while State.Running do
        local bossPhase = Workspace:GetAttribute("BossPhase")
        if Config.Automation.AutoBoss and bossPhase == "fight" then
            pcall(ProcessBossCombat)
        elseif Config.Automation.AutoStages then
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
        if Config.Automation.AutoFusePets then
            pcall(DoAutoFusePets)
        end
        if Config.Automation.AutoRedeemCodes and (tick() - lastCodeRedeemTick >= 60) then
            lastCodeRedeemTick = tick()
            task.spawn(DoRedeemAllCodes)
        end

        task.wait(Config.Delays.SlowLoop)
    end
end)

-- 8. MODERN USER INTERFACE
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChakraQAGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = parentGui

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
TitleLabel.Text = "⚡ Chakra QA Hub (Update 2 & 3 Support v9.8.0)"
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
Content.CanvasSize = UDim2.new(0, 0, 0, 1350)
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
AddSection("🌍 1. AUTO STAGES (เลือกระดับโลก 1-5 & ฟาร์มอัตโนมัติ)", Color3.fromRGB(255, 75, 75))
AddToggle("ลงด่านสเตจฟาร์มมอนอัตโนมัติ (Auto Stages)", Config.Automation.AutoStages, function(v) 
    Config.Automation.AutoStages = v 
end)
AddToggle("ถอยเก็บถ้วยด่านก่อนหน้าเมื่อสู้ไม่ไหว (Smart Retreat)", Config.Automation.AutoRetreat, function(v) 
    Config.Automation.AutoRetreat = v 
end)
AddToggle("ยืนแท่นคูณ 3 อัตโนมัติ (Pad x3 Multiplier)", Config.Stages.PadType == "purple", function(v)
    Config.Stages.PadType = v and "purple" or "gold"
end)

-- โชว์สถานะโลกและปุ่มเลือกระดับโลก 1 - 5
local WorldStatusLabel = Instance.new("TextLabel")
WorldStatusLabel.Size = UDim2.new(1, 0, 0, 22)
WorldStatusLabel.BackgroundTransparency = 1
WorldStatusLabel.Font = Enum.Font.GothamBold
WorldStatusLabel.TextSize = 11
WorldStatusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
WorldStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
local initialWorld = GetCurrentWorld()
WorldStatusLabel.Text = string.format("🌐 โลกปัจจุบัน: %d (%s)", initialWorld, WorldsInfo[initialWorld] and WorldsInfo[initialWorld].name or "World " .. initialWorld)
WorldStatusLabel.Parent = Content

task.spawn(function()
    while State.Running do
        pcall(function()
            local cw = GetCurrentWorld()
            local tw = Config.Stages.TargetWorld or cw
            local wName = WorldsInfo[cw] and WorldsInfo[cw].name or ("World " .. cw)
            WorldStatusLabel.Text = string.format("🌐 โลกปัจจุบัน: %d (%s) | เป้าหมาย: %d", cw, wName, tw)
        end)
        task.wait(0.5)
    end
end)

-- ปุ่มเลือกโลกทั้ง 5 โลก (Shinobi Lands, Celestial Realm, Blood Moon, Frozen Abyss, Cosmic Void)
for wId = 1, 5 do
    local info = WorldsInfo[wId]
    local btnName = string.format("🗺️ เลือกระดับโลก %d: %s", wId, info.name)
    AddButton(btnName, info.color, function()
        Config.Stages.TargetWorld = wId
        State.StatusText = string.format("🌀 กำลังสลับไปโลก %d (%s)...", wId, info.name)
        TeleportToWorld(wId)
        task.wait(0.5)
        StartStageOneProperly()
    end)
end

AddButton("🏆 ถอยไปเก็บถ้วยด่านก่อนหน้าทันที (Retreat & Claim)", Color3.fromRGB(160, 100, 30), function()
    local runCleared = LocalPlayer:GetAttribute("RunCleared") or 0
    RetreatAndClaimTrophies(runCleared)
end)
AddButton("🚀 เริ่มด่าน Stage 1 ของโลกนี้ทันที", Color3.fromRGB(140, 35, 35), function()
    StartStageOneProperly()
end)
AddButton("🏠 วาร์ปกลับจุดศูนย์กลาง (Hub Spawn ของโลกนี้)", Color3.fromRGB(60, 60, 80), function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local originX = GetWorldOrigin().X
    if root then root.CFrame = CFrame.new(originX, 4, 46) end
end)

-- KURAMA BOSS SECTION
AddSection("🦊 2. KURAMA BOSS EVENT (บอสคุรามะ - อัพเดทใหม่!)", Color3.fromRGB(255, 125, 40))
local BossStatusLabel = Instance.new("TextLabel")
BossStatusLabel.Size = UDim2.new(1, 0, 0, 22)
BossStatusLabel.BackgroundTransparency = 1
BossStatusLabel.Font = Enum.Font.GothamMedium
BossStatusLabel.TextSize = 10
BossStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
BossStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
BossStatusLabel.Text = "🦊 กำลังเช็คสถานะบอสคุรามะ..."
BossStatusLabel.Parent = Content

task.spawn(function()
    while State.Running do
        pcall(function()
            local phase = Workspace:GetAttribute("BossPhase") or "wait"
            local hp = Workspace:GetAttribute("BossHp") or 0
            local coins = LocalPlayer:GetAttribute("KuramaCoins") or 0
            local phaseText = (phase == "fight" and string.format("กำลังสู้! (HP: %.0f%%)", hp * 100))
                or (phase == "coming" and "กำลังเกิด...")
                or (phase == "over" and "จบศึกแล้ว")
                or "รอรอบถัดไป"
            BossStatusLabel.Text = string.format("🦊 บอส: %s | เหรียญคุรามะ: %d 🪙", phaseText, coins)
        end)
        task.wait(0.5)
    end
end)

AddToggle("ร่วมตีบอสคุรามะอัตโนมัติ (Auto Kurama Boss)", Config.Automation.AutoBoss, function(v)
    Config.Automation.AutoBoss = v
end)
AddButton("🦊 วาร์ปเข้าร่วมสู้บอสทันที (Join Boss)", Color3.fromRGB(180, 60, 20), function()
    if BossRemote then pcall(function() BossRemote:FireServer("join") end) end
end)
AddButton("🚪 ออกจากห้องบอส (Leave Boss Arena)", Color3.fromRGB(60, 60, 80), function()
    if BossRemote then pcall(function() BossRemote:FireServer("leave") end) end
end)
AddButton("🛍️ ซื้อของ Boss Shop (Fox Fire / Grand Prize)", Color3.fromRGB(150, 90, 20), function()
    local shopItems = {"fox_fire", "chakra_cloak", "kanjogan", "tailed_cloak", "fuma_mangekyo", "bijuu_mode", "kurenai_mangekyo", "grand_prize"}
    for _, item in ipairs(shopItems) do
        if BossShopFunc then
            pcall(function() BossShopFunc:InvokeServer("buy", item) end)
        end
    end
end)

AddSection("⚡ 3. ATTACK & COMBAT (โจมตีและพลัง)", Color3.fromRGB(255, 170, 0))
AddToggle("Auto Attack (M1 โจมตี/แอนิเมชันเต็ม)", Config.Automation.AutoAttack, function(v) Config.Automation.AutoAttack = v end)
AddToggle("Auto Skill E (สกิลปล่อยพลัง)", Config.Automation.AutoSkillE, function(v) Config.Automation.AutoSkillE = v end)
AddToggle("Auto Skill R (คามุย Kamui)", Config.Automation.AutoSkillR, function(v) Config.Automation.AutoSkillR = v end)
AddToggle("Auto Train (ฝึกจักระรวดเร็ว)", Config.Automation.AutoTrain, function(v) Config.Automation.AutoTrain = v end)

AddSection("🌀 4. PROGRESSION & REBIRTH", Color3.fromRGB(255, 100, 255))
AddToggle("เกิดใหม่อัตโนมัติ (Auto Rebirth)", Config.Automation.AutoRebirth, function(v) Config.Automation.AutoRebirth = v end)
AddButton("🌀 สั่งเกิดใหม่ทันที (Rebirth Now)", Color3.fromRGB(150, 40, 150), function() pcall(DoRebirth) end)

AddSection("💫 5. BEST GEAR & PET FUSER (ออร่า, ดวงตา & รวมสัตว์เลี้ยง)", Color3.fromRGB(120, 220, 255))
AddToggle("ใส่ออร่าที่ดีที่สุด ออโต้ (Best Aura)", Config.Automation.AutoEquipBestAura, function(v) Config.Automation.AutoEquipBestAura = v end)
AddButton("✨ ใส่ออร่าที่ดีที่สุดทันที (Equip Best Aura)", Color3.fromRGB(40, 120, 180), function() pcall(DoEquipBestAura) end)
AddToggle("ใส่ดวงตาที่ดีที่สุด ออโต้ (Best Eye)", Config.Automation.AutoEquipBestEye, function(v) Config.Automation.AutoEquipBestEye = v end)
AddToggle("ใส่สัตว์เลี้ยงที่ดีที่สุด ออโต้ (Best Pets)", Config.Automation.AutoEquipBestPets, function(v) Config.Automation.AutoEquipBestPets = v end)
AddToggle("หลอมรวมสัตว์เลี้ยง 4 ตัวออโต้ (Auto Fuse Pets)", Config.Automation.AutoFusePets, function(v) Config.Automation.AutoFusePets = v end)
AddButton("🧬 หลอมรวมสัตว์เลี้ยงทันที (Fuse Pets Now)", Color3.fromRGB(40, 140, 90), function() pcall(DoAutoFusePets) end)

AddSection("🔥 6. MULTIPLIER, CODES & REWARDS", Color3.fromRGB(255, 215, 0))
AddToggle("กดคูณจักระออโต้ (Pops Multipliers)", Config.Automation.AutoPops, function(v) Config.Automation.AutoPops = v end)
AddToggle("รับภารกิจ & รางวัลเวลารอ ออโต้", Config.Automation.AutoClaimAll, function(v) Config.Automation.AutoClaimAll = v end)
AddToggle("แลกโค้ดทั้งหมดอัตโนมัติ (Auto Redeem Codes)", Config.Automation.AutoRedeemCodes, function(v) Config.Automation.AutoRedeemCodes = v end)
AddButton("🎁 แลกโค้ดทั้งหมดทันที (7 โค้ดฟรี: AWAKEN, UPDATE2, KURUMA...)", Color3.fromRGB(180, 110, 30), function() 
    task.spawn(DoRedeemAllCodes) 
end)

_G.ChakraQACleanup = function()
    State.Running = false
    pcall(function() ScreenGui:Destroy() end)
end
