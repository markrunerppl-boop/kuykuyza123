-- ==============================================================================
-- PROJECT: Unified Auto Farm & Utility Hub Framework
-- GAME: [🐟] จับปลา! (PlaceId: 93898234979111)
-- VERSION: v3.0.0 [ULTIMATE EDITION]
-- FEATURES: Auto Net (Perfect Tap) / Auto Collect Pads / Auto Equip Best /
--           Auto Rebirth / Auto Claim Gifts & Free Clams / Auto Sell
-- ==============================================================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local SharedEnv = (getgenv and getgenv()) or _G

-- Kill previous session cleanly
local CurrentSessionId = HttpService:GenerateGUID(false)
SharedEnv._ScriptWorkerActive = true
SharedEnv._CurrentHubSessionId = CurrentSessionId

local function IsSessionValid()
    return SharedEnv._ScriptWorkerActive == true and SharedEnv._CurrentHubSessionId == CurrentSessionId
end

-- ==============================================================================
-- Dual-Layer Anti-AFK Engine (Roblox Platform 20m + Custom In-Game 300s + Auto-Dismiss)
-- ==============================================================================
local function DismissGameAFKScreen()
    pcall(function()
        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if PlayerGui then
            local afkScreen = PlayerGui:FindFirstChild("AFKModeScreen")
            if afkScreen then
                local afkBack = afkScreen:FindFirstChild("AFKBack", true)
                if afkBack and typeof(firesignal) == "function" then
                    pcall(function() firesignal(afkBack.MouseButton1Click) end)
                    pcall(function() firesignal(afkBack.Activated) end)
                end
                afkScreen.Enabled = false
            end
        end

        if LocalPlayer:GetAttribute("AFKScreen") then
            LocalPlayer:SetAttribute("AFKScreen", nil)
        end

        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
    end)
end

local function InitializeAntiAFK()
    -- Layer 1: Roblox Platform 20-Minute Idle Kick Protection
    LocalPlayer.Idled:Connect(function()
        if not IsSessionValid() then return end
        if Config and Config.Settings and Config.Settings.AntiAFK == false then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
        end)
    end)

    -- Layer 2: Realtime Attribute Listener for Game's AFKScreen
    LocalPlayer:GetAttributeChangedSignal("AFKScreen"):Connect(function()
        if not IsSessionValid() then return end
        if Config and Config.Settings and Config.Settings.AutoDismissAFKScreen == false then return end
        if LocalPlayer:GetAttribute("AFKScreen") == true then
            task.wait(0.1)
            DismissGameAFKScreen()
        end
    end)

    -- Layer 3: Heartbeat Anti-AFK Worker (Prevents game's 300s timer & auto-dismisses screen)
    task.spawn(function()
        local lastMicroInput = os.clock()
        while IsSessionValid() do
            if not Config or not Config.Settings or Config.Settings.AntiAFK ~= false then
                -- Send harmless micro-input every 25 seconds to continuously reset game's 300s idle timer
                if os.clock() - lastMicroInput >= 25 then
                    lastMicroInput = os.clock()
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
                        task.wait(0.02)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
                    end)
                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new(0, 0))
                    end)
                end

                -- Auto-dismiss screen & restore 3D rendering if AFK screen is triggered
                if not Config or not Config.Settings or Config.Settings.AutoDismissAFKScreen ~= false then
                    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
                    local afkScreen = PlayerGui and PlayerGui:FindFirstChild("AFKModeScreen")
                    if (afkScreen and afkScreen.Enabled) or LocalPlayer:GetAttribute("AFKScreen") == true then
                        DismissGameAFKScreen()
                    end
                end

                -- Manage visibility of in-game AFK button if user opted to hide it
                if Config and Config.Settings and Config.Settings.HideAFKBar ~= nil then
                    pcall(function()
                        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
                        local afkUI = PlayerGui and PlayerGui:FindFirstChild("AFKModeUI")
                        if afkUI then
                            local afkBar = afkUI:FindFirstChild("AFKBar")
                            local stackToggle = afkUI:FindFirstChild("StackToggle")
                            if Config.Settings.HideAFKBar then
                                if afkBar and afkBar.Visible then afkBar.Visible = false end
                                if stackToggle and stackToggle.Visible then stackToggle.Visible = false end
                            end
                        end
                    end)
                end
            end
            task.wait(2)
        end
    end)
end
task.spawn(InitializeAntiAFK)

-- Safe Task Isolation Runner
local function SpawnWorker(taskName, workerFunc)
    task.spawn(function()
        while IsSessionValid() do
            local success, err = pcall(workerFunc)
            if not success and err then
                warn(string.format("[Worker Error: %s] %s", taskName, tostring(err)))
            end
            task.wait(0.25 + (math.random(5, 20) / 100))
        end
    end)
end

-- ==============================================================================
-- 2. CENTRAL CONFIGURATION & GAME MODULES
-- ==============================================================================
local FishingShared = nil
pcall(function()
    FishingShared = require(ReplicatedStorage:WaitForChild("FishingShared", 5))
end)

local Config = {
    Meta = {
        HubName = "NEXUS HUB",
        Version = "v3.0.0 [จับปลา! Ultimate]",
        SaveFileName = "NexusHub_Config_" .. tostring(game.PlaceId) .. ".json"
    },
    Colors = {
        Background = Color3.fromRGB(18, 15, 26),
        Sidebar = Color3.fromRGB(13, 11, 20),
        Content = Color3.fromRGB(24, 20, 36),
        Card = Color3.fromRGB(32, 27, 48),
        CardHover = Color3.fromRGB(42, 36, 62),
        Accent = Color3.fromRGB(155, 89, 230),
        AccentLight = Color3.fromRGB(180, 120, 255),
        TextPrimary = Color3.fromRGB(245, 240, 255),
        TextSecondary = Color3.fromRGB(160, 150, 180),
        Border = Color3.fromRGB(48, 40, 70),
        Success = Color3.fromRGB(46, 204, 113),
        Danger = Color3.fromRGB(231, 76, 60),
        Warning = Color3.fromRGB(241, 196, 15),
        Gold = Color3.fromRGB(255, 205, 70),
        Cyan = Color3.fromRGB(0, 210, 255)
    },
    Events = {
        SellFish = "SellFish",
        BestSetup = "BestSetup",
        CollectPad = "CollectPadReq",
        CatchReady = "CatchReady",
        ThrowNet = "ThrowNet",
        ReelIn = "ReelIn",
        PerfectTap = "PerfectTap",
        RebirthRequest = "RebirthRequest",
        GetData = "GetData",
        Rewards = "Rewards",
        PearlShop = "PearlShop"
    },
    Settings = {
        -- Auto Net
        AutoNet = true,
        ReelWhenFull = true,
        AutoPerfectTap = true,

        -- Auto Base Pads
        AutoCollectPads = true,
        CollectInterval = 10,

        -- Auto Equip Best
        AutoEquipBest = true,
        EquipBestInterval = 10,

        -- Auto Rebirth
        AutoRebirth = true,

        -- Mega Quest & Reward Auto Claims
        AutoClaimRewards = true,        -- ของขวัญเล่นเกม & รางวัลประจำวัน
        AutoClaimClam = true,           -- หอยมุกฟรี
        AutoClaimContracts = true,      -- เคลมเควสสัญญาจับปลา (Contracts)
        AutoClaimChallenges = true,     -- เคลมเควสท้าทาย (Challenges)
        AutoClaimRetention = true,      -- เคลมเควสประจำวัน & หมุนวงล้อฟรี (Daily & Spins)
        AutoClaimIndexPages = true,     -- เคลมรางวัลสะสมปลาครบหน้า (Index Page Rewards)
        AutoLikeBases = true,           -- กด Like เบสผู้เล่นอื่นรับโบนัส

        -- Potions, Skills & Bait
        AutoBuyPotions = true,          -- ซื้อยาจากร้าน Potion Shop เมื่อมีของ
        AutoDrinkPotions = true,        -- เปิดโหมดดื่มยาอัตโนมัติ
        PotionDrinkMode = "ดื่มยาทุกชนิด (All Potions)", -- โหมดการดื่มยา
        AutoInvestSkills = true,        -- อัปเกรด Skill Tree อัตโนมัติเมื่อได้แต้มฟรี
        AutoEquipBait = true,           -- สวมใส่เหยื่อที่ดีที่สุด
        AutoBuyBait = true,             -- ซื้อเหยื่อที่ดีที่สุดอัตโนมัติเมื่อหมด (ครั้งละ 10 อัน)
        BaitBatchAmount = 10,           -- จำนวนเหยื่อที่ซื้อต่อครั้ง (10 ชิ้น)

        -- Boss Automation (Megalodon & Kraken)
        AutoBossFight = true,           -- ตีบอส Megalodon & Kraken อัตโนมัติ
        AutoClaimBossLoot = true,       -- เคลมการ์ดของรางวัลบอสอัตโนมัติ

        -- Auto Sell
        AutoSell = false,
        SellInterval = 20,

        -- Auto Upgrades
        AutoUpgrade = true,
        UpgradeInterval = 3,
        UpgradeBoat = true,         -- อัปเกรดเรือ (Hull + อุปกรณ์เรือ)
        UpgradeNet = true,          -- อัปเกรดตาข่าย (ซื้อเทียร์ใหม่)
        UpgradeFisherman = true,    -- อัปเกรดชาวประมง (เบ็ด, ถัง, สปีด, เหยื่อ)
        UpgradeSpear = true,        -- อัปเกรดปืนฉมวก (หัวฉมวก, ยิงหลายนัด, รีโหลด)
        UpgradeGeneral = true,      -- อัปเกรดทั่วไป/เบส (Weave, Titan, Colossus, Fleet, etc.)

        -- Anti-AFK & System
        AntiAFK = true,                 -- ป้องกันการตัดการเชื่อมต่อจาก AFK (Roblox 20 min + In-Game 300s)
        AutoDismissAFKScreen = true,    -- ปิดหน้าจอ AFK Mode Screen และกู้คืน 3D Rendering อัตโนมัติ
        HideAFKBar = false              -- ซ่อนปุ่ม 💤 AFK MODE ของตัวเกมที่มุมขวาล่าง
    }
}

local UIReferences = {
    StatusBarText = nil,
    RebirthProgressLabel = nil,
    NetStateLabel = nil
}

local function UpdateStatus(text)
    if UIReferences.StatusBarText then
        UIReferences.StatusBarText.Text = text
    end
end

-- Helpers
local function GetPlayerRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function GetMyBase()
    local bases = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Bases")
    if not bases then return nil end
    for _, b in ipairs(bases:GetChildren()) do
        if b:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return b
        end
    end
    return nil
end

local function EnsureOnDock()
    local root = GetPlayerRoot()
    local myBase = GetMyBase()
    if root and myBase and FishingShared then
        local onDock = FishingShared.OnOwnDock(myBase, root.Position)
        if not onDock and myBase:FindFirstChild("Dock") then
            root.CFrame = myBase.Dock.CFrame + Vector3.new(0, 3, 0)
            task.wait(0.2)
        end
    end
end

-- Bait Manager (Auto Buy Best Bait x10 when empty & Auto Equip Best)
local function ProcessBaitCycle(remotes)
    if not Config.Settings.AutoEquipBait and not Config.Settings.AutoBuyBait then return end
    remotes = remotes or ReplicatedStorage:FindFirstChild("Remotes")
    local tackleRemote = remotes and remotes:FindFirstChild("Tackle")
    if not tackleRemote then return end

    pcall(function()
        local state = tackleRemote:InvokeServer("state")
        if not state or not state.baits then return end

        local playerRebirths = state.rebirths or 0
        local playerCash = state.cash or 0
        local prices = state.prices or {}
        local currentEquipped = state.bait
        local batchSize = Config.Settings.BaitBatchAmount or 10

        -- 1. Identify the best unlocked bait for the player
        local targetBaitId = nil
        local targetBaitName = nil

        if FishingShared and FishingShared.Baits then
            for i = #FishingShared.Baits, 1, -1 do
                local b = FishingShared.Baits[i]
                if playerRebirths >= (b.Rebirth or 0) then
                    local price = prices[b.Id] or 0
                    if (state.baits[b.Id] or 0) > 0 or playerCash >= price then
                        targetBaitId = b.Id
                        targetBaitName = b.Name or b.Id
                        break
                    end
                end
            end
        end

        if not targetBaitId then
            targetBaitId = "Crumbs"
            targetBaitName = "Bread Crumbs"
        end

        -- 2. If best bait is out (count <= 0), buy 10 at a time
        local currentCount = tonumber(state.baits[targetBaitId]) or 0
        if Config.Settings.AutoBuyBait and currentCount <= 0 then
            local buyRes = tackleRemote:InvokeServer("buyBait", targetBaitId, batchSize)
            if buyRes and buyRes.ok then
                UpdateStatus(string.format("STATUS: BOUGHT %d BEST BAIT [%s]!", batchSize, targetBaitName))
                currentCount = batchSize
                task.wait(0.2)
            end
        end

        -- 3. Equip the best bait if not currently equipped and we have stock
        if Config.Settings.AutoEquipBait and currentCount > 0 and currentEquipped ~= targetBaitId then
            local equipRes = tackleRemote:InvokeServer("equipBait", targetBaitId)
            if equipRes and equipRes.ok then
                UpdateStatus(string.format("STATUS: EQUIPPED BEST BAIT [%s]! (%d REMAINING)", targetBaitName, currentCount))
            end
        end
    end)
end

-- ==============================================================================
-- 3. ADVANCED LOGIC WORKERS
-- ==============================================================================

-- Task 1: Auto Net Loop (โยนแห ดึงแห พร้อมกด Perfect Tap)
SpawnWorker("AutoNetWorker", function()
    if not Config.Settings.AutoNet then
        task.wait(1.0)
        return
    end

    local myBase = GetMyBase()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local throwRemote = remotes and remotes:FindFirstChild(Config.Events.ThrowNet)
    local reelRemote = remotes and remotes:FindFirstChild(Config.Events.ReelIn)
    local perfectRemote = remotes and remotes:FindFirstChild(Config.Events.PerfectTap)

    if myBase and throwRemote and reelRemote then
        local netState = myBase:GetAttribute("NetState") or "Idle"
        local netCount = myBase:GetAttribute("NetCount") or 0
        local netCap = myBase:GetAttribute("NetCap") or 1
        local netReelAt = myBase:GetAttribute("NetReelAt") or 0
        local serverTime = Workspace:GetServerTimeNow()

        if UIReferences.NetStateLabel then
            UIReferences.NetStateLabel.Text = string.format("Net: %s (%d/%d)", netState, netCount, netCap)
        end

        if netState == "Idle" then
            EnsureOnDock()
            ProcessBaitCycle(remotes)
            throwRemote:FireServer()
            UpdateStatus("STATUS: NET THROWN! [FISHING STARTED]")
            task.wait(1.0)
        elseif netState == "Fishing" then
            local shouldReel = false
            if Config.Settings.ReelWhenFull and netCount >= netCap then
                shouldReel = true
            elseif netReelAt > 0 and serverTime >= netReelAt then
                shouldReel = true
            end

            if shouldReel then
                -- Perfect Tap
                if Config.Settings.AutoPerfectTap and perfectRemote then
                    perfectRemote:FireServer(serverTime)
                end

                reelRemote:FireServer()
                UpdateStatus(string.format("STATUS: REELED IN %d FISH! (PERFECT CATCH)", netCount))
                task.wait(2.5)

                if Config.Settings.AutoEquipBest then
                    local bestRemote = remotes:FindFirstChild(Config.Events.BestSetup)
                    if bestRemote then bestRemote:FireServer() end
                end
            end
        elseif netState == "Reeling" then
            if Config.Settings.AutoPerfectTap and perfectRemote then
                perfectRemote:FireServer(serverTime)
            end
            task.wait(1.2)
        end
    end

    task.wait(1.0)
end)

-- Task 2: Auto Collect Base Pads (กวาดเงิน 13 แท่นวาง)
SpawnWorker("AutoCollectPadsWorker", function()
    if not Config.Settings.AutoCollectPads then
        task.wait(2.0)
        return
    end

    local root = GetPlayerRoot()
    local myBase = GetMyBase()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local collectRemote = remotes and remotes:FindFirstChild(Config.Events.CollectPad)

    if root and myBase and collectRemote then
        local pedestals = myBase:FindFirstChild("Pedestals")
        if pedestals then
            local pendingPads = {}
            for _, ped in ipairs(pedestals:GetChildren()) do
                local slot = ped:GetAttribute("Slot")
                local col = ped:FindFirstChild("Collect")
                local pad = col and col:FindFirstChild("Pad")
                local info = col and col:FindFirstChild("LabelAnchor") and col.LabelAnchor:FindFirstChild("CollectInfo")
                local amtText = info and info:FindFirstChild("Amount") and info.Amount.Text or ""

                if pad and slot and amtText ~= "" and amtText ~= "$0" then
                    table.insert(pendingPads, { slot = slot, pad = pad })
                end
            end

            if #pendingPads > 0 then
                local originalCF = root.CFrame
                for _, item in ipairs(pendingPads) do
                    if not IsSessionValid() or not Config.Settings.AutoCollectPads then break end
                    root.CFrame = item.pad.CFrame + Vector3.new(0, 2, 0)
                    task.wait(0.08)
                    collectRemote:FireServer(item.slot)
                end
                task.wait(0.05)
                root.CFrame = originalCF
                UpdateStatus(string.format("STATUS: COLLECTED CASH FROM %d PADS!", #pendingPads))
            end
        end
    end

    task.wait(Config.Settings.CollectInterval + math.random(1, 3))
end)

-- Task 3: Auto Equip Best Fish (ใส่ตัวดีสุดลงแท่นวาง)
SpawnWorker("AutoEquipBestWorker", function()
    if not Config.Settings.AutoEquipBest then
        task.wait(3.0)
        return
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local bestRemote = remotes and remotes:FindFirstChild(Config.Events.BestSetup)
    if bestRemote then
        bestRemote:FireServer()
    end

    task.wait(Config.Settings.EquipBestInterval + math.random(1, 3))
end)

-- ==============================================================================
-- PRIORITY 1 & 2 WORKERS & HELPERS
-- 1. เกิดใหม่ทันทีเมื่อครบเกณฑ์ (Auto Rebirth)
-- 2. ซื้อแหและใส่แหที่ดีที่สุดเสมอ (Buy & Equip Best Net)
-- ==============================================================================

local function UpgradeBestNet(remotes, data)
    remotes = remotes or ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes or not remotes:FindFirstChild("BuyItem") or not FishingShared or not FishingShared.Nets then
        return 0
    end

    if not data then
        local getData = remotes:FindFirstChild(Config.Events.GetData)
        local ok, res = pcall(function() return getData and getData:InvokeServer() end)
        if ok and type(res) == "table" then
            data = res
        else
            return 0
        end
    end

    local currentCash = data.Cash or 0
    local curTier = data.NetTier or 1
    local upgradedCount = 0

    for nextTier = curTier + 1, #FishingShared.Nets do
        local netCfg = FishingShared.Nets[nextTier]
        if not netCfg then break end
        local cost = netCfg.Cost or (1/0)
        local rOk = (FishingShared.NetRebirthOk == nil) or FishingShared.NetRebirthOk(data, nextTier)

        if rOk and currentCash >= cost then
            local success = pcall(function()
                remotes.BuyItem:FireServer("Net", nextTier, true)
            end)
            if success then
                currentCash = currentCash - cost
                data.Cash = currentCash
                data.NetTier = nextTier
                curTier = nextTier
                upgradedCount = upgradedCount + 1
                UpdateStatus(string.format("PRIORITY 2: UPGRADED & EQUIPPED NET TIER %d (%s)!", nextTier, netCfg.Name or ""))
                task.wait(0.2)
            else
                break
            end
        else
            break
        end
    end

    return upgradedCount
end

-- Task 4: Priority 1 & 2 Worker (Rebirth First, Then Best Net)
SpawnWorker("PriorityRebirthAndNetWorker", function()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes or not FishingShared then
        task.wait(2.0)
        return
    end

    local getDataRemote = remotes:FindFirstChild(Config.Events.GetData)
    local rebirthRemote = remotes:FindFirstChild(Config.Events.RebirthRequest)
    if not getDataRemote or not rebirthRemote then
        task.wait(2.0)
        return
    end

    local ok, data = pcall(function() return getDataRemote:InvokeServer() end)
    if not ok or type(data) ~= "table" then
        task.wait(2.0)
        return
    end

    local nextRebirth = (data.Rebirths or 0) + 1
    local need = FishingShared.RebirthNeed and FishingShared.RebirthNeed(data, nextRebirth)
    local canRebirth = false
    pcall(function() canRebirth = FishingShared.CanRebirth(data) end)

    if UIReferences.RebirthProgressLabel and need then
        if canRebirth then
            UIReferences.RebirthProgressLabel.Text = string.format("REBIRTH %d: พร้อมเกิดใหม่ทันที! (READY)", nextRebirth)
            UIReferences.RebirthProgressLabel.TextColor3 = Config.Colors.Success
        else
            UIReferences.RebirthProgressLabel.Text = string.format("Rebirth %d ต้องการ: %s เงิน | %d ปลา", nextRebirth, FishingShared.Money(need.Cash), need.Caught)
            UIReferences.RebirthProgressLabel.TextColor3 = Config.Colors.Gold
        end
    end

    -- PRIORITY 1: AUTO REBIRTH
    if Config.Settings.AutoRebirth and canRebirth then
        UpdateStatus(string.format("PRIORITY 1: PERFORMING REBIRTH %d NOW!", nextRebirth))
        rebirthRemote:FireServer()
        task.wait(2.5)

        -- ทันทีหลัง Rebirth: กวาดเงินฐาน -> ซื้อแหที่ดีที่สุด -> ใส่ปลาดีที่สุด
        pcall(function()
            local root = GetPlayerRoot()
            local myBase = GetMyBase()
            local collectRemote = remotes:FindFirstChild(Config.Events.CollectPad)
            if root and myBase and collectRemote then
                local pedestals = myBase:FindFirstChild("Pedestals")
                if pedestals then
                    local originalCF = root.CFrame
                    for _, ped in ipairs(pedestals:GetChildren()) do
                        local slot = ped:GetAttribute("Slot")
                        local col = ped:FindFirstChild("Collect")
                        local pad = col and col:FindFirstChild("Pad")
                        if pad and slot then
                            root.CFrame = pad.CFrame + Vector3.new(0, 2, 0)
                            task.wait(0.06)
                            collectRemote:FireServer(slot)
                        end
                    end
                    task.wait(0.05)
                    root.CFrame = originalCF
                end
            end
        end)

        -- PRIORITY 2: BUY & EQUIP BEST NET IMMEDIATELY
        UpgradeBestNet(remotes)

        -- PRIORITY 3: EQUIP BEST FISH IMMEDIATELY
        if remotes:FindFirstChild(Config.Events.BestSetup) then
            remotes[Config.Events.BestSetup]:FireServer()
        end

        task.wait(2.0)
        return
    end

    -- PRIORITY 2: BUY & EQUIP BEST NET ALWAYS (หากมีเงินพอซื้อเทียร์ใหม่)
    if Config.Settings.UpgradeNet then
        UpgradeBestNet(remotes, data)
    end

    task.wait(2.5)
end)

-- Rebirth Event Listener: เมื่อเกิดใหม่สำเร็จจากทางใดก็ตาม รีบซื้อและใส่แหที่ดีที่สุดทันที
task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    local rebirthDone = remotes and remotes:WaitForChild("RebirthDone", 5)
    if rebirthDone then
        rebirthDone.OnClientEvent:Connect(function(newRebirthLvl)
            if not IsSessionValid() then return end
            UpdateStatus(string.format("REBIRTH %s CONFIRMED! AUTO BUYING BEST NET...", tostring(newRebirthLvl)))
            task.wait(1.0)
            UpgradeBestNet(remotes)
            if remotes:FindFirstChild(Config.Events.BestSetup) then
                remotes[Config.Events.BestSetup]:FireServer()
            end
        end)
    end
end)

-- Task 5: Mega Auto Claim System (รับรางวัลภารกิจ & ของขวัญทุกหมวดหมู่อัตโนมัติ)
local function RunMegaClaimCycle()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return 0 end
    local claimedCount = 0

    -- 1. Free Pearl Clam
    if Config.Settings.AutoClaimClam then
        local pearlRemote = remotes:FindFirstChild(Config.Events.PearlShop)
        if pearlRemote then
            pcall(function()
                local res = pearlRemote:InvokeServer("freeClam")
                if res and res.ok then
                    claimedCount = claimedCount + 1
                    UpdateStatus("STATUS: CLAIMED FREE PEARL CLAM!")
                end
            end)
        end
    end

    -- 2. Playtime Gifts & Daily Rewards
    if Config.Settings.AutoClaimRewards then
        local rewardsRemote = remotes:FindFirstChild(Config.Events.Rewards)
        if rewardsRemote then
            pcall(function()
                local state = rewardsRemote:InvokeServer("state")
                if state and state.gifts then
                    for i, gift in ipairs(state.gifts) do
                        if gift.ready and not gift.claimed then
                            rewardsRemote:InvokeServer("claimGift", i)
                            claimedCount = claimedCount + 1
                            UpdateStatus(string.format("STATUS: CLAIMED GIFT #%d (%s)!", i, gift.text or "Reward"))
                            task.wait(0.3)
                        end
                    end
                end
                if state and state.daily and state.daily.claimable then
                    rewardsRemote:InvokeServer("claimDaily")
                    claimedCount = claimedCount + 1
                    UpdateStatus("STATUS: CLAIMED DAILY REWARD!")
                end
            end)
        end
    end

    -- 3. Contracts / Quests (เควสสัญญาจับปลา)
    if Config.Settings.AutoClaimContracts then
        local contractsRemote = remotes:FindFirstChild("Contracts")
        if contractsRemote then
            pcall(function()
                local state = contractsRemote:InvokeServer("state")
                if state and state.list then
                    for i, c in ipairs(state.list) do
                        if (c.done == true or (c.goal and c.p and c.p >= c.goal)) and c.k ~= "wait" then
                            local res = contractsRemote:InvokeServer("claim", i)
                            if res and res.ok then
                                claimedCount = claimedCount + 1
                                UpdateStatus(string.format("STATUS: CLAIMED CONTRACT #%d (%s)!", i, tostring(res.reward or "Reward")))
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end)
        end
    end

    -- 4. Daily Retention Missions & Free Lucky Spins (ภารกิจรายวัน & วงล้อหมุนฟรี)
    if Config.Settings.AutoClaimRetention then
        local retRemote = remotes:FindFirstChild("Retention")
        if retRemote then
            pcall(function()
                local state = retRemote:InvokeServer("state")
                -- Claim Daily
                if state and state.daily and not state.daily.claimed then
                    local dRes = retRemote:InvokeServer("claimDaily")
                    if dRes then claimedCount = claimedCount + 1 end
                end
                -- Lucky Spins
                if state and state.spin and (state.spin.spins or 0) > 0 then
                    for s = 1, state.spin.spins do
                        local sRes = retRemote:InvokeServer("spin")
                        if sRes and sRes.ok then
                            claimedCount = claimedCount + 1
                            UpdateStatus(string.format("STATUS: LUCKY SPIN #%d WON: %s!", s, tostring(sRes.text or "Reward")))
                            task.wait(0.25)
                        end
                    end
                end
            end)
        end
    end

    -- 5. Challenge Pass Quests (เควสท้าทายประจำซีซั่น)
    if Config.Settings.AutoClaimChallenges then
        local chalRemote = remotes:FindFirstChild("Challenge")
        if chalRemote then
            pcall(function()
                local state = chalRemote:InvokeServer("state")
                if state and state.tiers then
                    for i, t in ipairs(state.tiers) do
                        if t.done and not t.claimed then
                            local cRes = chalRemote:InvokeServer("claim", i)
                            if cRes then
                                claimedCount = claimedCount + 1
                                UpdateStatus(string.format("STATUS: CLAIMED CHALLENGE TIER #%d!", i))
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end)
        end
    end

    -- 6. Index Page Milestones (รางวัลสะสมปลาครบหน้า)
    if Config.Settings.AutoClaimIndexPages then
        local rewardsRemote = remotes:FindFirstChild("Rewards")
        if rewardsRemote then
            pcall(function()
                local res = rewardsRemote:InvokeServer("pageRewards")
                if res and res.done and res.claims then
                    for _, pNum in ipairs(res.done) do
                        if not res.claims[tostring(pNum)] then
                            local pRes = rewardsRemote:InvokeServer("claimPage", pNum)
                            if pRes and pRes.ok then
                                claimedCount = claimedCount + 1
                                UpdateStatus(string.format("STATUS: CLAIMED INDEX PAGE #%d REWARD!", pNum))
                                task.wait(0.3)
                            end
                        end
                    end
                end
            end)
        end
    end

    -- 7. Auto Like Bases (กด Like เบสผู้เล่นอื่นรับโบนัส)
    if Config.Settings.AutoLikeBases then
        local likeRemote = remotes:FindFirstChild("LikeBase")
        if likeRemote then
            pcall(function()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        likeRemote:InvokeServer("like", p.UserId)
                        task.wait(0.1)
                    end
                end
            end)
        end
    end

    return claimedCount
end

SpawnWorker("AutoClaimWorker", function()
    RunMegaClaimCycle()
    task.wait(15.0 + math.random(1, 5))
end)

-- Task 8: Potions, Skill Tree & Best Bait Worker
local function RunPotionsAndSkillsCycle()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end

    -- 1. Auto Potions (ซื้อยา & ดื่มยา)
    if Config.Settings.AutoDrinkPotions and remotes:FindFirstChild("Potions") then
        local potionRemote = remotes.Potions
        local mode = Config.Settings.PotionDrinkMode or "ดื่มยาทุกชนิด (All Potions)"
        if mode == "ดื่มยาทุกชนิด (All Potions)" then
            pcall(function()
                local res = potionRemote:InvokeServer("useAll")
                if res and res.ok and res.drank and res.drank > 0 then
                    UpdateStatus(string.format("STATUS: DRANK %d POTIONS FROM COOLER!", res.drank))
                end
            end)
        elseif mode ~= "ปิดการดื่มยา (Disabled)" then
            pcall(function()
                local inv = nil
                local pState = potionRemote:InvokeServer("state")
                if pState and pState.inv then
                    inv = pState.inv
                else
                    local getData = remotes:FindFirstChild(Config.Events.GetData)
                    local data = getData and getData:InvokeServer()
                    if data and data.PotionInv then
                        inv = data.PotionInv
                    end
                end

                if inv then
                    for key, count in pairs(inv) do
                        if (tonumber(count) or 0) > 0 then
                            local kind, tier = key:match("^(%a+)_(%d+)$")
                            local shouldDrink = false
                            if mode == "เฉพาะยาเงิน (Cash Boost)" and kind == "Cash" then
                                shouldDrink = true
                            elseif mode == "เฉพาะยาตาข่าย (Net Space)" and kind == "Net" then
                                shouldDrink = true
                            elseif mode == "เฉพาะเทียร์สูงสุด (Tier 5+)" and (tonumber(tier) or 0) >= 5 then
                                shouldDrink = true
                            end

                            if shouldDrink then
                                potionRemote:InvokeServer("use", key)
                                UpdateStatus(string.format("STATUS: DRANK POTION [%s]!", key))
                                task.wait(0.15)
                            end
                        end
                    end
                end
            end)
        end
    end

    if Config.Settings.AutoBuyPotions then
        local potionRemote = remotes:FindFirstChild("Potions")
        if potionRemote then
            pcall(function()
                local state = potionRemote:InvokeServer("state")
                if state and state.stock and state.cash then
                    for i, p in ipairs(state.stock) do
                        if not p.bought and p.price and state.cash >= p.price then
                            local buyRes = potionRemote:InvokeServer("buy", i)
                            if buyRes and buyRes.ok then
                                state.cash = state.cash - p.price
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end)
        end
    end

    -- 2. Auto Skill Tree Invest
    if Config.Settings.AutoInvestSkills then
        local skillRemote = remotes:FindFirstChild("SkillTree")
        local SkillTreeModule = nil
        pcall(function() SkillTreeModule = require(ReplicatedStorage:FindFirstChild("SkillTree")) end)

        if skillRemote and SkillTreeModule then
            pcall(function()
                local state = skillRemote:InvokeServer("state")
                if state and (state.free or 0) > 0 and SkillTreeModule.Nodes then
                    for _, node in ipairs(SkillTreeModule.Nodes) do
                        local cur = tonumber(state.skills[node.Id]) or 0
                        local max = node.Max or 5
                        local cost = node.Cost or 1
                        local unlocked = SkillTreeModule.unlocked and SkillTreeModule.unlocked(state.skills, node.Id)
                        while cur < max and unlocked and (state.free or 0) >= cost do
                            local res = skillRemote:InvokeServer("buy", node.Id)
                            if res and res.ok then
                                state = res.state
                                cur = cur + 1
                                UpdateStatus(string.format("STATUS: LEARNED SKILL [%s] LVL %d!", node.Name or node.Id, cur))
                                task.wait(0.2)
                            else
                                break
                            end
                        end
                    end
                end
            end)
        end
    end

    -- 3. Auto Best Bait Equip & Buy (ซื้อเหยื่อที่ดีที่สุดครั้งละ 10 เมื่อหมด & ใส่เหยื่อดีสุด)
    ProcessBaitCycle(remotes)
end

SpawnWorker("PotionsAndSkillsWorker", function()
    RunPotionsAndSkillsCycle()
    task.wait(15.0 + math.random(1, 4))
end)

-- Task 9: Auto Boss Fighter (Megalodon & Kraken Auto Fight & Loot)
SpawnWorker("AutoBossWorker", function()
    if not Config.Settings.AutoBossFight then
        task.wait(3.0)
        return
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        task.wait(3.0)
        return
    end

    local megEvent = remotes:FindFirstChild("MegEvent")
    local bossEvent = remotes:FindFirstChild("BossEvent")

    -- 1. Check Megalodon Event
    if megEvent and workspace:GetAttribute("MegActive") == true then
        UpdateStatus("STATUS: MEGALODON DETECTED! ENTERING FIGHT...")
        pcall(function()
            -- Join the fight
            megEvent:FireServer("enter")
            task.wait(0.5)

            -- Fight loop while Megalodon is active
            local fightStart = os.clock()
            while workspace:GetAttribute("MegActive") == true and (os.clock() - fightStart < 190) and IsSessionValid() do
                -- Calculate Megalodon aim position
                local targetPos = nil
                local megFolder = workspace:FindFirstChild("MegalodonLocal")
                if megFolder and megFolder:FindFirstChild("Root") then
                    targetPos = megFolder.Root.Position
                elseif FishingShared and FishingShared.MegPos then
                    targetPos = FishingShared.MegPos(workspace:GetServerTimeNow())
                end

                if targetPos then
                    megEvent:FireServer("fire", targetPos)
                    UpdateStatus("STATUS: ATTACKING MEGALODON WITH SPEAR TURRET!")
                end

                task.wait(1.1)
            end

            -- Battle ended: claim victory rewards
            task.wait(1.0)
            megEvent:FireServer("closed")
            UpdateStatus("STATUS: MEGALODON DEFEATED! CLAIMED VICTORY LOOT!")
        end)
    end

    -- 2. Kraken Boss / General Boss Event
    if bossEvent and Config.Settings.AutoClaimBossLoot then
        -- Auto close/claim Kraken loot card if open
        pcall(function()
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local bossUI = pGui and (pGui:FindFirstChild("BossUI") or pGui:FindFirstChild("LootUI"))
            if bossUI and bossUI.Enabled then
                bossEvent:FireServer("closed")
                UpdateStatus("STATUS: CLAIMED KRAKEN BOSS LOOT CARD!")
            end
        end)
    end

    task.wait(3.0)
end)

-- Task 6: Auto Sell Worker
SpawnWorker("AutoSellWorker", function()
    if not Config.Settings.AutoSell then
        task.wait(2.0)
        return
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local sellRemote = remotes and remotes:FindFirstChild(Config.Events.SellFish)
    if sellRemote then
        sellRemote:FireServer()
    end

    task.wait(Config.Settings.SellInterval)
end)

-- Task 7: Universal Auto Upgrade Runner
local function RunUpgradeCycle()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes or not FishingShared then return 0 end

    local getData = remotes:FindFirstChild(Config.Events.GetData)
    if not getData then return 0 end

    local ok, data = pcall(function() return getData:InvokeServer() end)
    if not ok or type(data) ~= "table" then return 0 end

    local currentCash = data.Cash or 0
    local upgradedCount = 0

    -- 1. Upgrade Net (ตาข่าย - อันดับความสำคัญสูงสุดในหมวดอัปเกรด ซื้อและใส่แหที่ดีที่สุดทันที)
    if Config.Settings.UpgradeNet then
        local netUpgrades = UpgradeBestNet(remotes, data)
        upgradedCount = upgradedCount + netUpgrades
        currentCash = data.Cash or currentCash
    end

    -- 2. Upgrade Boat (เรือ)
    if Config.Settings.UpgradeBoat and remotes:FindFirstChild("BoatAction") then
        -- Hull (ตัวเรือ)
        local curHull = (data.Boat and data.Boat.Hull) or 0
        local nextHull = curHull + 1
        local hullCfg = FishingShared.Boat and FishingShared.Boat.Hulls and FishingShared.Boat.Hulls[nextHull]
        if hullCfg and (data.Rebirths or 0) >= (hullCfg.Rebirth or 0) and currentCash >= (hullCfg.Cost or (1/0)) then
            local okBuy = nil
            pcall(function()
                okBuy = remotes.BoatAction:InvokeServer("buy", "Hull")
            end)
            if okBuy and okBuy.ok then
                currentCash = currentCash - hullCfg.Cost
                upgradedCount = upgradedCount + 1
                UpdateStatus(string.format("STATUS: UPGRADED BOAT HULL LVL %d!", nextHull))
                task.wait(0.2)
            end
        end

        -- Parts (อุปกรณ์เรือ: Trawl, Engine, Sonar, Cold, Figure)
        if FishingShared.Boat and FishingShared.Boat.Upgrades then
            for _, u in ipairs(FishingShared.Boat.Upgrades) do
                local cur = (data.Boat or {})[u.Id] or 0
                local max = u.Max or 35
                if cur < max then
                    local cost = FishingShared.BoatCost and FishingShared.BoatCost(u.Id, cur) or (1/0)
                    local extraOk = (FishingShared.ExtraOk == nil) or FishingShared.ExtraOk(data, u, cur + 1)
                    if currentCash >= cost and extraOk then
                        local okBuy = nil
                        pcall(function()
                            okBuy = remotes.BoatAction:InvokeServer("buy", u.Id)
                        end)
                        if okBuy and okBuy.ok then
                            currentCash = currentCash - cost
                            upgradedCount = upgradedCount + 1
                            UpdateStatus(string.format("STATUS: UPGRADED BOAT [%s] LVL %d!", u.Name or u.Id, cur + 1))
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end

    -- 3. Upgrade Fishermen (ชาวประมง: Rod, Line, Speed, Range, Tackle, Shiny, Bait)
    if Config.Settings.UpgradeFisherman and remotes:FindFirstChild("HelperAction") and FishingShared.Helper and FishingShared.Helper.Upgrades then
        for _, u in ipairs(FishingShared.Helper.Upgrades) do
            local cur = (data.Helper or {})[u.Id] or 0
            local max = u.Max or 35
            if cur < max then
                local cost = FishingShared.HelperCost and FishingShared.HelperCost(u.Id, cur) or (1/0)
                local okLvl = (FishingShared.HelperLevelOk == nil) or FishingShared.HelperLevelOk(data, u, cur + 1)
                if currentCash >= cost and okLvl then
                    local okBuy = nil
                    pcall(function()
                        okBuy = remotes.HelperAction:InvokeServer("buy", u.Id)
                    end)
                    if okBuy and okBuy.ok then
                        currentCash = currentCash - cost
                        upgradedCount = upgradedCount + 1
                        UpdateStatus(string.format("STATUS: UPGRADED FISHERMAN [%s] LVL %d!", u.Name or u.Id, cur + 1))
                        task.wait(0.2)
                    end
                end
            end
        end
    end

    -- 4. Upgrade Spear Gun (ปืนฉมวก: Tip, Multi, Reload, Range, Barb, Barrel, Scope)
    if Config.Settings.UpgradeSpear and remotes:FindFirstChild("SpearAction") and FishingShared.Spear and FishingShared.Spear.Upgrades then
        for _, u in ipairs(FishingShared.Spear.Upgrades) do
            local cur = (data.Spear or {})[u.Id] or 0
            local max = u.Max or 35
            if cur < max then
                local cost = FishingShared.SpearCost and FishingShared.SpearCost(u.Id, cur) or (1/0)
                local okLvl = (FishingShared.HelperLevelOk == nil) or FishingShared.HelperLevelOk(data, u, cur + 1)
                if currentCash >= cost and okLvl then
                    local okBuy = nil
                    pcall(function()
                        okBuy = remotes.SpearAction:InvokeServer("buy", u.Id)
                    end)
                    if okBuy and okBuy.ok then
                        currentCash = currentCash - cost
                        upgradedCount = upgradedCount + 1
                        UpdateStatus(string.format("STATUS: UPGRADED SPEAR GUN [%s] LVL %d!", u.Name or u.Id, cur + 1))
                        task.wait(0.2)
                    end
                end
            end
        end
    end

    -- 5. Upgrade General & Base (อัปเกรดทั่วไป/เบส)
    if Config.Settings.UpgradeGeneral and remotes:FindFirstChild("BuyItem") and FishingShared.Upgrades then
        for _, u in ipairs(FishingShared.Upgrades) do
            if not u.Hidden then
                local cur = (data.Upgrades or {})[u.Id] or 0
                local max = u.Max or 35
                if cur < max then
                    local cost = FishingShared.UpgradeCost and FishingShared.UpgradeCost(u.Id, cur) or (1/0)
                    local okLvl = (FishingShared.UpgradeLevelOk == nil) or FishingShared.UpgradeLevelOk(data, u, cur + 1)
                    if currentCash >= cost and okLvl then
                        pcall(function()
                            remotes.BuyItem:FireServer("Upgrade", u.Id)
                        end)
                        currentCash = currentCash - cost
                        upgradedCount = upgradedCount + 1
                        UpdateStatus(string.format("STATUS: UPGRADED [%s] LVL %d!", u.Name or u.Id, cur + 1))
                        task.wait(0.2)
                    end
                end
            end
        end
    end

    return upgradedCount
end

SpawnWorker("AutoUpgradeWorker", function()
    if not Config.Settings.AutoUpgrade then
        task.wait(2.0)
        return
    end

    RunUpgradeCycle()
    task.wait(Config.Settings.UpgradeInterval + math.random(1, 2))
end)

-- ==============================================================================
-- 4. UI CREATION (MODERN DARK PURPLE UNIFIED HUB)
-- ==============================================================================
local function BuildUI()
    local oldUI = CoreGui:FindFirstChild("NexusHub_ScreenGui") or (LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("NexusHub_ScreenGui"))
    if oldUI then oldUI:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "NexusHub_ScreenGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local parentSuccess = pcall(function() ScreenGui.Parent = CoreGui end)
    if not parentSuccess or not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Floating Action Button
    local FloatButton = Instance.new("TextButton")
    FloatButton.Name = "NexusFloatButton"
    FloatButton.Size = UDim2.new(0, 48, 0, 48)
    FloatButton.Position = UDim2.new(0, 25, 0.35, 0)
    FloatButton.BackgroundColor3 = Config.Colors.Card
    FloatButton.Text = "🔮"
    FloatButton.TextSize = 22
    FloatButton.AutoButtonColor = false
    FloatButton.Parent = ScreenGui

    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatButton

    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Config.Colors.Accent
    FloatStroke.Thickness = 1.8
    FloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    FloatStroke.Parent = FloatButton

    -- Main Container (570 x 430 px)
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 570, 0, 430)
    MainFrame.Position = UDim2.new(0.5, -285, 0.5, -215)
    MainFrame.BackgroundColor3 = Config.Colors.Background
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Config.Colors.Border
    MainStroke.Thickness = 1.2
    MainStroke.Parent = MainFrame

    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 42)
    Header.BackgroundColor3 = Config.Colors.Sidebar
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 340, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 14
    TitleLabel.TextColor3 = Config.Colors.TextPrimary
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Text = Config.Meta.HubName .. " <font color=\"#B478FF\">" .. Config.Meta.Version .. "</font>"
    TitleLabel.RichText = true
    TitleLabel.Parent = Header

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
    CloseBtn.BackgroundColor3 = Config.Colors.Card
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "—"
    CloseBtn.TextColor3 = Config.Colors.TextSecondary
    CloseBtn.TextSize = 14
    CloseBtn.Parent = Header

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    -- Sidebar (145px)
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 145, 1, -42)
    Sidebar.Position = UDim2.new(0, 0, 0, 42)
    Sidebar.BackgroundColor3 = Config.Colors.Sidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 2
    Sidebar.ScrollBarImageColor3 = Config.Colors.Border
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Sidebar.Parent = MainFrame

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.Padding = UDim.new(0, 6)
    SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarList.Parent = Sidebar

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.PaddingTop = UDim.new(0, 10)
    SidebarPadding.PaddingLeft = UDim.new(0, 8)
    SidebarPadding.PaddingRight = UDim.new(0, 8)
    SidebarPadding.Parent = Sidebar

    -- Content Area
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, -145, 1, -66)
    ContentFrame.Position = UDim2.new(0, 145, 0, 42)
    ContentFrame.BackgroundColor3 = Config.Colors.Content
    ContentFrame.BorderSizePixel = 0
    ContentFrame.Parent = MainFrame

    -- Status Bar
    local StatusBar = Instance.new("Frame")
    StatusBar.Name = "StatusBar"
    StatusBar.Size = UDim2.new(1, -145, 0, 24)
    StatusBar.Position = UDim2.new(0, 145, 1, -24)
    StatusBar.BackgroundColor3 = Config.Colors.Sidebar
    StatusBar.BorderSizePixel = 0
    StatusBar.Parent = MainFrame

    local StatusText = Instance.new("TextLabel")
    StatusText.Size = UDim2.new(1, -20, 1, 0)
    StatusText.Position = UDim2.new(0, 10, 0, 0)
    StatusText.BackgroundTransparency = 1
    StatusText.Font = Enum.Font.RobotoMono
    StatusText.TextSize = 11
    StatusText.TextColor3 = Config.Colors.TextSecondary
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.Text = "STATUS: ACTIVE | ALL AUTOMATION RUNNING"
    StatusText.Parent = StatusBar
    UIReferences.StatusBarText = StatusText

    -- Tab System
    local TabPages = {}
    local TabButtons = {}

    local function CreateTabPage(pageId)
        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "TabContent_" .. pageId
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = Config.Colors.Accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Visible = false
        scroll.Parent = ContentFrame

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 8)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = scroll

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 12)
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 12)
        pad.PaddingBottom = UDim.new(0, 12)
        pad.Parent = scroll

        TabPages[pageId] = scroll
        return scroll
    end

    local function AddTabButton(tabId, tabName, isDefault, layoutOrder)
        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. tabId
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = isDefault and Config.Colors.Accent or Config.Colors.Card
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        btn.TextColor3 = isDefault and Config.Colors.TextPrimary or Config.Colors.TextSecondary
        btn.Text = tabName
        if layoutOrder then btn.LayoutOrder = layoutOrder end
        btn.Parent = Sidebar

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            for id, page in pairs(TabPages) do page.Visible = (id == tabId) end
            for id, b in pairs(TabButtons) do
                local active = (id == tabId)
                b.BackgroundColor3 = active and Config.Colors.Accent or Config.Colors.Card
                b.TextColor3 = active and Config.Colors.TextPrimary or Config.Colors.TextSecondary
            end
        end)

        TabButtons[tabId] = btn
    end

    local function CreateToggle(parent, title, initialValue, callback)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 40)
        card.BackgroundColor3 = Config.Colors.Card
        card.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = card

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -70, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 12
        label.TextColor3 = Config.Colors.TextPrimary
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = title
        label.Parent = card

        local toggleTrack = Instance.new("TextButton")
        toggleTrack.Size = UDim2.new(0, 44, 0, 22)
        toggleTrack.Position = UDim2.new(1, -54, 0.5, -11)
        toggleTrack.BackgroundColor3 = initialValue and Config.Colors.Accent or Config.Colors.Sidebar
        toggleTrack.Text = ""
        toggleTrack.Parent = card

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = toggleTrack

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = initialValue and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        knob.BackgroundColor3 = Config.Colors.TextPrimary
        knob.Parent = toggleTrack

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        local state = initialValue
        toggleTrack.MouseButton1Click:Connect(function()
            state = not state
            local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            local targetColor = state and Config.Colors.Accent or Config.Colors.Sidebar
            TweenService:Create(knob, TweenInfo.new(0.2), { Position = targetPos }):Play()
            TweenService:Create(toggleTrack, TweenInfo.new(0.2), { BackgroundColor3 = targetColor }):Play()
            callback(state)
        end)
    end

    local function CreateButton(parent, text, bgColor, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.BackgroundColor3 = bgColor or Config.Colors.Card
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.TextColor3 = Config.Colors.TextPrimary
        btn.Text = text
        btn.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn

        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    local function CreateStatusCard(parent, titleText)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 36)
        card.BackgroundColor3 = Config.Colors.Sidebar
        card.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = card

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.RobotoMono
        label.TextSize = 11
        label.TextColor3 = Config.Colors.TextPrimary
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = titleText
        label.Parent = card

        return label
    end

    local function CreateDropdown(parent, title, options, defaultOption, callback)
        local isExpanded = false
        local currentSelected = defaultOption or options[1]

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 42)
        card.BackgroundColor3 = Config.Colors.Card
        card.ClipsDescendants = true
        card.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = card

        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 42)
        header.BackgroundTransparency = 1
        header.Parent = card

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(0.48, -10, 1, 0)
        titleLabel.Position = UDim2.new(0, 12, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamMedium
        titleLabel.TextSize = 12
        titleLabel.TextColor3 = Config.Colors.TextPrimary
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Text = title
        titleLabel.Parent = header

        local selectBtn = Instance.new("TextButton")
        selectBtn.Size = UDim2.new(0.52, -12, 0, 28)
        selectBtn.Position = UDim2.new(0.48, 0, 0.5, -14)
        selectBtn.BackgroundColor3 = Config.Colors.Sidebar
        selectBtn.Font = Enum.Font.GothamMedium
        selectBtn.TextSize = 11
        selectBtn.TextColor3 = Config.Colors.AccentLight
        selectBtn.Text = tostring(currentSelected) .. " ▼"
        selectBtn.Parent = header

        local selectCorner = Instance.new("UICorner")
        selectCorner.CornerRadius = UDim.new(0, 4)
        selectCorner.Parent = selectBtn

        local optionsList = Instance.new("Frame")
        optionsList.Size = UDim2.new(1, -24, 0, #options * 30 + 4)
        optionsList.Position = UDim2.new(0, 12, 0, 44)
        optionsList.BackgroundTransparency = 1
        optionsList.Visible = false
        optionsList.Parent = card

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 4)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = optionsList

        local function ToggleExpand(state)
            isExpanded = (state ~= nil) and state or (not isExpanded)
            optionsList.Visible = isExpanded
            selectBtn.Text = tostring(currentSelected) .. (isExpanded and " ▲" or " ▼")
            if isExpanded then
                card.Size = UDim2.new(1, 0, 0, 46 + #options * 32)
            else
                card.Size = UDim2.new(1, 0, 0, 42)
            end
        end

        selectBtn.MouseButton1Click:Connect(function()
            ToggleExpand()
        end)

        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Name = "Opt_" .. tostring(i)
            optBtn.Size = UDim2.new(1, 0, 0, 28)
            optBtn.BackgroundColor3 = (opt == currentSelected) and Config.Colors.Accent or Config.Colors.Sidebar
            optBtn.Font = Enum.Font.GothamMedium
            optBtn.TextSize = 11
            optBtn.TextColor3 = Config.Colors.TextPrimary
            optBtn.Text = opt
            optBtn.Parent = optionsList

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 4)
            optCorner.Parent = optBtn

            optBtn.MouseButton1Click:Connect(function()
                currentSelected = opt
                selectBtn.Text = tostring(currentSelected) .. " ▼"
                ToggleExpand(false)
                for _, child in ipairs(optionsList:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.BackgroundColor3 = (child.Text == currentSelected) and Config.Colors.Accent or Config.Colors.Sidebar
                    end
                end
                if callback then
                    callback(opt)
                end
            end)
        end

        return card
    end

    -- ==========================================================================
    -- TAB 1: 🔄 1. เกิดใหม่ & วิวัฒนาการ (Rebirth - Priority 1)
    -- ==========================================================================
    AddTabButton("RebirthTab", "🔄 1. เกิดใหม่", true, 1)
    local pRebirth = CreateTabPage("RebirthTab")
    pRebirth.Visible = true

    UIReferences.RebirthProgressLabel = CreateStatusCard(pRebirth, "Rebirth Requirement: กำลังคำนวณเงื่อนไข...")

    CreateToggle(pRebirth, "เกิดใหม่อัตโนมัติเมื่อครบเกณฑ์ (Priority 1: Auto Rebirth)", Config.Settings.AutoRebirth, function(v)
        Config.Settings.AutoRebirth = v
    end)

    CreateButton(pRebirth, "🔄 กดเกิดใหม่ทันที (Rebirth Now)", Config.Colors.Gold, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(Config.Events.RebirthRequest) then
            remotes[Config.Events.RebirthRequest]:FireServer()
            UpdateStatus("STATUS: REBIRTH REQUEST SENT!")
        end
    end)

    CreateStatusCard(pRebirth, "⚡ ลำดับสำคัญ 1: เกิดใหม่ทันทีเมื่อครบเกณฑ์ เพื่อรับตัวคูณเงินถาวร\n(เมื่อเกิดใหม่แล้ว ระบบจะซื้อและใส่แหที่ดีที่สุดต่อทันที)")

    -- ==========================================================================
    -- TAB 2: 🕸️ 2. แห & โยนแหตกปลา (Net & Fishing - Priority 2)
    -- ==========================================================================
    AddTabButton("NetFarm", "🕸️ 2. แห & โยนแห", false, 2)
    local pNetFarm = CreateTabPage("NetFarm")

    UIReferences.NetStateLabel = CreateStatusCard(pNetFarm, "Net: Scanning...")

    CreateToggle(pNetFarm, "ซื้อและใส่แหที่ดีที่สุดอัตโนมัติ (Priority 2: Auto Best Net)", Config.Settings.UpgradeNet, function(v)
        Config.Settings.UpgradeNet = v
    end)

    CreateButton(pNetFarm, "⭐ ซื้อและสวมใส่แหที่ดีที่สุดทันที (Buy & Equip Best Net Now)", Config.Colors.Gold, function()
        UpdateStatus("STATUS: UPGRADING TO HIGHEST AFFORDABLE NET...")
        task.spawn(function()
            local count = UpgradeBestNet()
            UpdateStatus(string.format("STATUS: EQUIPPED BEST NET! (%d TIERS UPGRADED)", count))
        end)
    end)

    CreateToggle(pNetFarm, "โยนแห & ดึงแหอัตโนมัติ (Auto Net Loop)", Config.Settings.AutoNet, function(v)
        Config.Settings.AutoNet = v
    end)

    CreateToggle(pNetFarm, "ดึงแหทันทีเมื่อเต็มความจุ (Reel When Full)", Config.Settings.ReelWhenFull, function(v)
        Config.Settings.ReelWhenFull = v
    end)

    CreateToggle(pNetFarm, "กด Perfect Tap อัตโนมัติ (เพิ่มโชค)", Config.Settings.AutoPerfectTap, function(v)
        Config.Settings.AutoPerfectTap = v
    end)

    local rowNet = Instance.new("Frame")
    rowNet.Size = UDim2.new(1, 0, 0, 34)
    rowNet.BackgroundTransparency = 1
    rowNet.Parent = pNetFarm

    local btnThrowNow = Instance.new("TextButton")
    btnThrowNow.Size = UDim2.new(0.48, 0, 1, 0)
    btnThrowNow.BackgroundColor3 = Config.Colors.Accent
    btnThrowNow.Font = Enum.Font.GothamBold
    btnThrowNow.TextSize = 11
    btnThrowNow.TextColor3 = Config.Colors.TextPrimary
    btnThrowNow.Text = "⚡ โยนแหทันที (Throw Net)"
    btnThrowNow.Parent = rowNet
    local btn1Corner = Instance.new("UICorner")
    btn1Corner.CornerRadius = UDim.new(0, 6)
    btn1Corner.Parent = btnThrowNow

    btnThrowNow.MouseButton1Click:Connect(function()
        EnsureOnDock()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(Config.Events.ThrowNet) then
            remotes[Config.Events.ThrowNet]:FireServer()
            UpdateStatus("STATUS: MANUAL THROW NET EXECUTED!")
        end
    end)

    local btnReelNow = Instance.new("TextButton")
    btnReelNow.Size = UDim2.new(0.48, 0, 1, 0)
    btnReelNow.Position = UDim2.new(0.52, 0, 0, 0)
    btnReelNow.BackgroundColor3 = Config.Colors.Success
    btnReelNow.Font = Enum.Font.GothamBold
    btnReelNow.TextSize = 11
    btnReelNow.TextColor3 = Config.Colors.TextPrimary
    btnReelNow.Text = "⚡ ดึงแหขึ้นทันที (Reel In)"
    btnReelNow.Parent = rowNet
    local btn2Corner = Instance.new("UICorner")
    btn2Corner.CornerRadius = UDim.new(0, 6)
    btn2Corner.Parent = btnReelNow

    btnReelNow.MouseButton1Click:Connect(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(Config.Events.ReelIn) then
            remotes[Config.Events.ReelIn]:FireServer()
            UpdateStatus("STATUS: MANUAL REEL IN EXECUTED!")
        end
    end)

    -- ==========================================================================
    -- TAB 3: แท่นวาง & เงินในฐาน (Base & Cash Pads)
    -- ==========================================================================
    AddTabButton("BasePads", "💰 3. แท่นวาง & เงิน", false, 3)
    local pBasePads = CreateTabPage("BasePads")

    CreateToggle(pBasePads, "กวาดเงินแท่นวางอัตโนมัติ (Auto Collect Pads)", Config.Settings.AutoCollectPads, function(v)
        Config.Settings.AutoCollectPads = v
    end)

    CreateButton(pBasePads, "⚡ กวาดเงินแท่นวางทั้งหมดทันที ($16T+/s)", Config.Colors.Success, function()
        task.spawn(function()
            local root = GetPlayerRoot()
            local myBase = GetMyBase()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local collectRemote = remotes and remotes:FindFirstChild(Config.Events.CollectPad)

            if root and myBase and collectRemote then
                local pedestals = myBase:FindFirstChild("Pedestals")
                if pedestals then
                    local originalCF = root.CFrame
                    local count = 0
                    for _, ped in ipairs(pedestals:GetChildren()) do
                        local slot = ped:GetAttribute("Slot")
                        local col = ped:FindFirstChild("Collect")
                        local pad = col and col:FindFirstChild("Pad")
                        local info = col and col:FindFirstChild("LabelAnchor") and col.LabelAnchor:FindFirstChild("CollectInfo")
                        local amtText = info and info:FindFirstChild("Amount") and info.Amount.Text or ""

                        if pad and slot and amtText ~= "" and amtText ~= "$0" then
                            root.CFrame = pad.CFrame + Vector3.new(0, 2, 0)
                            task.wait(0.08)
                            collectRemote:FireServer(slot)
                            count = count + 1
                        end
                    end
                    task.wait(0.05)
                    root.CFrame = originalCF
                    UpdateStatus("STATUS: MANUALLY COLLECTED " .. count .. " PADS!")
                end
            end
        end)
    end)

    CreateToggle(pBasePads, "สวมใส่ปลาที่ดีที่สุดอัตโนมัติ (Auto Equip Best)", Config.Settings.AutoEquipBest, function(v)
        Config.Settings.AutoEquipBest = v
    end)

    CreateButton(pBasePads, "⭐ สวมใส่ตัวที่ดีที่สุดทันที (Equip Best Now)", Config.Colors.Accent, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(Config.Events.BestSetup) then
            remotes[Config.Events.BestSetup]:FireServer()
            UpdateStatus("STATUS: BEST FISH EQUIPPED ON ALL PEDESTALS!")
        end
    end)

    -- ==========================================================================
    -- TAB 7: ภารกิจ & รางวัลทั้งหมด (Mega Quests & Rewards)
    -- ==========================================================================
    AddTabButton("RewardsTab", "🎁 7. ภารกิจ & ของขวัญ", false, 7)
    local pRewards = CreateTabPage("RewardsTab")

    local QuestStatusCard = CreateStatusCard(pRewards, "ระบบภารกิจ: สแกนเควสและของขวัญทุกระบบอัตโนมัติ...")

    CreateToggle(pRewards, "เคลมเควสสัญญาจับปลา (Auto Claim Contracts)", Config.Settings.AutoClaimContracts, function(v)
        Config.Settings.AutoClaimContracts = v
    end)

    CreateToggle(pRewards, "รับของขวัญออนไลน์ & ล็อกอิน (Playtime Gifts & Daily)", Config.Settings.AutoClaimRewards, function(v)
        Config.Settings.AutoClaimRewards = v
    end)

    CreateToggle(pRewards, "เควสประจำวัน & หมุนวงล้อฟรี (Daily Quests & Lucky Spins)", Config.Settings.AutoClaimRetention, function(v)
        Config.Settings.AutoClaimRetention = v
    end)

    CreateToggle(pRewards, "เควสท้าทายประจำซีซั่น (Challenge Pass Quests)", Config.Settings.AutoClaimChallenges, function(v)
        Config.Settings.AutoClaimChallenges = v
    end)

    CreateToggle(pRewards, "รางวัลสะสมปลาครบหน้า (Index Milestone Rewards)", Config.Settings.AutoClaimIndexPages, function(v)
        Config.Settings.AutoClaimIndexPages = v
    end)

    CreateToggle(pRewards, "รับหอยมุกฟรีอัตโนมัติ (Auto Free Pearl Clam)", Config.Settings.AutoClaimClam, function(v)
        Config.Settings.AutoClaimClam = v
    end)

    CreateToggle(pRewards, "กด Like เบสผู้เล่นอื่นรับบัฟ (Auto Like Other Bases)", Config.Settings.AutoLikeBases, function(v)
        Config.Settings.AutoLikeBases = v
    end)

    CreateButton(pRewards, "🎁 กดรับรางวัลและเควสทุกหมวดหมู่ทันที (Claim ALL Now)", Config.Colors.Gold, function()
        UpdateStatus("STATUS: RUNNING MEGA CLAIM CYCLE FOR ALL QUESTS & REWARDS...")
        task.spawn(function()
            local count = RunMegaClaimCycle()
            UpdateStatus(string.format("STATUS: CLAIMED %d REWARDS & SPINS SUCCESSFULLY!", count))
            if QuestStatusCard then
                QuestStatusCard.Text = string.format("เคลมรางวัลและหมุนวงล้อสำเร็จล่าสุด: %d รายการ!", count)
            end
        end)
    end)

    -- ==========================================================================
    -- TAB 8: ขายปลา/ร้านค้า (Market & Sell)
    -- ==========================================================================
    AddTabButton("SellTab", "🏷️ 8. ขายปลา", false, 8)
    local pSell = CreateTabPage("SellTab")

    CreateToggle(pSell, "ขายปลาอัตโนมัติ (Auto Sell Fish)", Config.Settings.AutoSell, function(v)
        Config.Settings.AutoSell = v
    end)

    CreateButton(pSell, "💰 กดขายปลาทั้งหมดทันที (Sell All Fish)", Config.Colors.Card, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(Config.Events.SellFish) then
            remotes[Config.Events.SellFish]:FireServer()
            UpdateStatus("STATUS: MANUAL SELL FISH EXECUTED!")
        end
    end)

    -- ==========================================================================
    -- TAB 4: ระบบอัปเกรดอัตโนมัติ (Auto Upgrades)
    -- ==========================================================================
    AddTabButton("UpgradeTab", "⚡ 4. อัปเกรดอื่นๆ", false, 4)
    local pUpgrade = CreateTabPage("UpgradeTab")

    local UpgradeStatusCard = CreateStatusCard(pUpgrade, "ระบบอัปเกรด: กำลังตรวจสอบไอเทมที่สามารถอัปเกรดได้...")

    CreateToggle(pUpgrade, "⚡ เปิดระบบ Auto Upgrade ทั้งหมด (Master Switch)", Config.Settings.AutoUpgrade, function(v)
        Config.Settings.AutoUpgrade = v
        UpdateStatus("STATUS: AUTO UPGRADE " .. (v and "ENABLED" or "DISABLED"))
    end)

    CreateToggle(pUpgrade, "🚤 อัปเกรดเรือ (Boat: Hull & Equipment)", Config.Settings.UpgradeBoat, function(v)
        Config.Settings.UpgradeBoat = v
    end)

    CreateToggle(pUpgrade, "🕸️ อัปเกรดตาข่าย (Net: Auto Tier Up)", Config.Settings.UpgradeNet, function(v)
        Config.Settings.UpgradeNet = v
    end)

    CreateToggle(pUpgrade, "🎣 อัปเกรดชาวประมง (Fisherman: Rod, Tackle, Bait)", Config.Settings.UpgradeFisherman, function(v)
        Config.Settings.UpgradeFisherman = v
    end)

    CreateToggle(pUpgrade, "🔱 อัปเกรดปืนฉมวก (Harpoon: Tips, Multi, Reload)", Config.Settings.UpgradeSpear, function(v)
        Config.Settings.UpgradeSpear = v
    end)

    CreateToggle(pUpgrade, "⚙️ อัปเกรดทั่วไป/เบส (General: Weave, Titan, Colossus)", Config.Settings.UpgradeGeneral, function(v)
        Config.Settings.UpgradeGeneral = v
    end)

    CreateButton(pUpgrade, "⚡ รันอัปเกรดทุกอย่างที่ซื้อได้ทันที (Upgrade All Now)", Config.Colors.Gold, function()
        UpdateStatus("STATUS: RUNNING INSTANT UPGRADE CYCLE...")
        task.spawn(function()
            local count = RunUpgradeCycle()
            UpdateStatus(string.format("STATUS: UPGRADE COMPLETED! (%d ITEMS UPGRADED)", count))
            if UpgradeStatusCard then
                UpgradeStatusCard.Text = string.format("อัปเกรดสำเร็จล่าสุด: %d รายการ | เงินคงเหลืออัปเดตแล้ว", count)
            end
        end)
    end)

    -- ==========================================================================
    -- TAB 6: ยา & สกิลทรี (Potions & Skill Tree)
    -- ==========================================================================
    AddTabButton("PotionsTab", "🧪 6. ยา & สกิล", false, 6)
    local pPotions = CreateTabPage("PotionsTab")

    local PotionsStatusCard = CreateStatusCard(pPotions, "ระบบยาและสกิล: กำลังตรวจสอบร้านค้าและแต้มสกิล...")

    CreateToggle(pPotions, "ซื้อยาบัฟทุกชนิดเมื่อร้านรีเฟรช (Auto Buy Potions)", Config.Settings.AutoBuyPotions, function(v)
        Config.Settings.AutoBuyPotions = v
    end)

    CreateToggle(pPotions, "เปิดระบบดื่มยาบัฟอัตโนมัติ (Auto Drink Potions)", Config.Settings.AutoDrinkPotions, function(v)
        Config.Settings.AutoDrinkPotions = v
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("Potions") then
            remotes.Potions:InvokeServer("auto", v)
        end
    end)

    local potionOptions = {
        "ดื่มยาทุกชนิด (All Potions)",
        "เฉพาะยาเงิน (Cash Boost)",
        "เฉพาะยาตาข่าย (Net Space)",
        "เฉพาะเทียร์สูงสุด (Tier 5+)",
        "ปิดการดื่มยา (Disabled)"
    }
    CreateDropdown(pPotions, "โหมดการดื่มยา (Drink Mode)", potionOptions, Config.Settings.PotionDrinkMode, function(selected)
        Config.Settings.PotionDrinkMode = selected
        UpdateStatus("STATUS: POTION MODE SET TO: " .. selected)
        if PotionsStatusCard then
            PotionsStatusCard.Text = "โหมดดื่มยาปัจจุบัน: " .. selected
        end
    end)

    CreateButton(pPotions, "⚡ ดื่มยาทุกขวดในคูลเลอร์ทันที (Drink All Potions Now)", Config.Colors.Success, function()
        UpdateStatus("STATUS: CONSUMING ALL STORED POTIONS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("Potions") then
                local res = remotes.Potions:InvokeServer("useAll")
                local count = (res and res.drank) or 0
                UpdateStatus(string.format("STATUS: SUCCESSFULLY DRANK %d POTIONS!", count))
                if PotionsStatusCard then
                    PotionsStatusCard.Text = string.format("ดื่มยาสำเร็จทันที: %d ขวด! (บัฟทำงานแล้ว)", count)
                end
            end
        end)
    end)

    CreateToggle(pPotions, "อัปเกรด Skill Tree อัตโนมัติเมื่อได้แต้มฟรี (Auto Invest Skills)", Config.Settings.AutoInvestSkills, function(v)
        Config.Settings.AutoInvestSkills = v
    end)

    CreateToggle(pPotions, "สวมใส่เหยื่อที่ดีที่สุดเสมอ (Auto Equip Best Bait)", Config.Settings.AutoEquipBait, function(v)
        Config.Settings.AutoEquipBait = v
    end)

    CreateToggle(pPotions, "ซื้อเหยื่อที่ดีที่สุดอัตโนมัติเมื่อหมด x10 (Auto Buy Best Bait x10)", Config.Settings.AutoBuyBait, function(v)
        Config.Settings.AutoBuyBait = v
    end)

    CreateButton(pPotions, "🪱 ซื้อเหยื่อที่ดีที่สุด 10 ชิ้นทันที (Buy 10x Best Bait Now)", Config.Colors.Gold, function()
        UpdateStatus("STATUS: BUYING 10x BEST BAIT...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local tackleRemote = remotes and remotes:FindFirstChild("Tackle")
            if tackleRemote and FishingShared and FishingShared.Baits then
                local state = tackleRemote:InvokeServer("state")
                if state then
                    local playerRebirths = state.rebirths or 0
                    local targetBait = nil
                    for i = #FishingShared.Baits, 1, -1 do
                        local b = FishingShared.Baits[i]
                        if playerRebirths >= (b.Rebirth or 0) then
                            targetBait = b
                            break
                        end
                    end
                    if targetBait then
                        local res = tackleRemote:InvokeServer("buyBait", targetBait.Id, 10)
                        if res and res.ok then
                            tackleRemote:InvokeServer("equipBait", targetBait.Id)
                            UpdateStatus(string.format("STATUS: BOUGHT 10x %s & EQUIPPED!", targetBait.Name or targetBait.Id))
                            if PotionsStatusCard then
                                PotionsStatusCard.Text = string.format("ซื้อเหยื่อ %s สำเร็จ 10 ชิ้น!", targetBait.Name or targetBait.Id)
                            end
                        else
                            UpdateStatus("STATUS: FAILED TO BUY BAIT (INSUFFICIENT FUNDS)")
                        end
                    end
                end
            end
        end)
    end)

    CreateButton(pPotions, "🧪 ซื้อยาทุกชนิดในร้านตอนนี้ทันที (Buy All Stock Potions)", Config.Colors.Cyan, function()
        UpdateStatus("STATUS: BUYING ALL STOCKED POTIONS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("Potions") then
                local state = remotes.Potions:InvokeServer("state")
                local count = 0
                if state and state.stock and state.cash then
                    for i, p in ipairs(state.stock) do
                        if not p.bought and p.price and state.cash >= p.price then
                            local b = remotes.Potions:InvokeServer("buy", i)
                            if b and b.ok then
                                count = count + 1
                                state.cash = state.cash - p.price
                            end
                        end
                    end
                end
                UpdateStatus(string.format("STATUS: BOUGHT %d POTIONS FROM SHOP!", count))
                if PotionsStatusCard then
                    PotionsStatusCard.Text = string.format("ซื้อยาสำเร็จล่าสุด: %d ขวด!", count)
                end
            end
        end)
    end)

    CreateButton(pPotions, "🌳 อัปเกรดแต้มสกิลฟรีที่มีทั้งหมดทันที (Invest All Skill Points)", Config.Colors.Gold, function()
        UpdateStatus("STATUS: INVESTING ALL FREE SKILL POINTS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local SkillTreeModule = nil
            pcall(function() SkillTreeModule = require(ReplicatedStorage:FindFirstChild("SkillTree")) end)
            if remotes and remotes:FindFirstChild("SkillTree") and SkillTreeModule then
                local state = remotes.SkillTree:InvokeServer("state")
                local count = 0
                if state and (state.free or 0) > 0 and SkillTreeModule.Nodes then
                    for _, node in ipairs(SkillTreeModule.Nodes) do
                        local cur = tonumber(state.skills[node.Id]) or 0
                        local max = node.Max or 5
                        local cost = node.Cost or 1
                        local unlocked = SkillTreeModule.unlocked and SkillTreeModule.unlocked(state.skills, node.Id)
                        while cur < max and unlocked and (state.free or 0) >= cost do
                            local res = remotes.SkillTree:InvokeServer("buy", node.Id)
                            if res and res.ok then
                                count = count + 1
                                state = res.state
                                cur = cur + 1
                                task.wait(0.2)
                            else
                                break
                            end
                        end
                    end
                end
                UpdateStatus(string.format("STATUS: INVESTED %d SKILL POINTS!", count))
                if PotionsStatusCard then
                    PotionsStatusCard.Text = string.format("อัปเกรดสกิลสำเร็จล่าสุด: %d แต้ม!", count)
                end
            end
        end)
    end)

    -- ==========================================================================
    -- TAB 5: ระบบล่าบอส (Boss Fights: Megalodon & Kraken)
    -- ==========================================================================
    AddTabButton("BossTab", "🦈 5. ล่าบอส", false, 5)
    local pBoss = CreateTabPage("BossTab")

    local BossStatusCard = CreateStatusCard(pBoss, "ระบบบอส: กำลังสแกนสถานะ Megalodon & Kraken...")

    -- Live status update for BossStatusCard
    task.spawn(function()
        while IsSessionValid() do
            if BossStatusCard and BossStatusCard.Parent then
                local isMeg = workspace:GetAttribute("MegActive") == true
                local isKraken = workspace:GetAttribute("BossActive") == true
                local megText = isMeg and "🔴 MEG ACTIVE!" or "Meg: รอเวลา"
                local krakenText = isKraken and "🔴 KRAKEN ACTIVE!" or "Kraken: รอเวลา"
                BossStatusCard.Text = string.format("สถานะบอส | %s | %s", megText, krakenText)
            end
            task.wait(2.5)
        end
    end)

    CreateToggle(pBoss, "🦈 ตีบอสอัตโนมัติ (Auto Fight Megalodon & Kraken)", Config.Settings.AutoBossFight, function(v)
        Config.Settings.AutoBossFight = v
        UpdateStatus("STATUS: AUTO BOSS FIGHT " .. (v and "ENABLED" or "DISABLED"))
    end)

    CreateToggle(pBoss, "🎁 เคลมการ์ดของรางวัลบอสอัตโนมัติ (Auto Claim Boss Loot)", Config.Settings.AutoClaimBossLoot, function(v)
        Config.Settings.AutoClaimBossLoot = v
        UpdateStatus("STATUS: AUTO CLAIM BOSS LOOT " .. (v and "ENABLED" or "DISABLED"))
    end)

    CreateButton(pBoss, "🦈 เข้าสู่โหมดป้อมปืนตี Megalodon ทันที (Enter Turret)", Config.Colors.Accent, function()
        UpdateStatus("STATUS: ENTERING MEGALODON TURRET MODE...")
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("MegEvent") then
            remotes.MegEvent:FireServer("enter")
        end
    end)

    CreateButton(pBoss, "🎯 เล็งยิงฉมวกใส่ Megalodon ทันที (Fire Turret Spear)", Config.Colors.Cyan, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("MegEvent") then
            local targetPos = nil
            local megFolder = workspace:FindFirstChild("MegalodonLocal")
            if megFolder and megFolder:FindFirstChild("Root") then
                targetPos = megFolder.Root.Position
            elseif FishingShared and FishingShared.MegPos then
                targetPos = FishingShared.MegPos(workspace:GetServerTimeNow())
            end
            if targetPos then
                remotes.MegEvent:FireServer("fire", targetPos)
                UpdateStatus("STATUS: MANUAL SHOT FIRED AT MEGALODON!")
            else
                UpdateStatus("STATUS: MEGALODON TARGET NOT FOUND")
            end
        end
    end)

    CreateButton(pBoss, "🎁 รับของรางวัลบอส Megalodon ทันที (Claim Megalodon Loot)", Config.Colors.Gold, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("MegEvent") then
            remotes.MegEvent:FireServer("closed")
            UpdateStatus("STATUS: CLAIMED MEGALODON REWARDS!")
        end
    end)

    CreateButton(pBoss, "🐙 รับของรางวัลบอส Kraken ทันที (Claim Kraken Loot)", Config.Colors.Success, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("BossEvent") then
            remotes.BossEvent:FireServer("closed")
            UpdateStatus("STATUS: CLAIMED KRAKEN REWARDS!")
        end
    end)

    -- ==========================================================================
    -- TAB 9: ตั้งค่าระบบ (Settings & System)
    -- ==========================================================================
    AddTabButton("SettingsTab", "⚙️ 9. ตั้งค่าระบบ", false, 9)
    local pSettings = CreateTabPage("SettingsTab")

    CreateToggle(pSettings, "🛡️ ป้องกันหลุด AFK ขั้นสูง (Dual-Layer Anti-AFK)", Config.Settings.AntiAFK, function(val)
        Config.Settings.AntiAFK = val
    end)

    CreateToggle(pSettings, "🚫 ปิดหน้าจอ AFK Mode อัตโนมัติ (Auto Dismiss AFK Screen)", Config.Settings.AutoDismissAFKScreen, function(val)
        Config.Settings.AutoDismissAFKScreen = val
        if val then
            DismissGameAFKScreen()
        end
    end)

    CreateToggle(pSettings, "👁️ ซ่อนปุ่ม AFK ของเกมที่ขวาล่าง (Hide In-Game AFK Bar)", Config.Settings.HideAFKBar, function(val)
        Config.Settings.HideAFKBar = val
        pcall(function()
            local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
            local afkUI = PlayerGui and PlayerGui:FindFirstChild("AFKModeUI")
            if afkUI then
                local afkBar = afkUI:FindFirstChild("AFKBar")
                local stackToggle = afkUI:FindFirstChild("StackToggle")
                if afkBar then afkBar.Visible = not val end
                if stackToggle then stackToggle.Visible = not val end
            end
        end)
    end)

    CreateButton(pSettings, "⚡ บังคับปลด AFK ทันที (Force Exit AFK Now)", Config.Colors.Warning, function()
        DismissGameAFKScreen()
        UpdateStatus("ปลดสถานะ AFK และกู้คืน 3D Render เรียบร้อย!")
    end)

    CreateButton(pSettings, "EMERGENCY KILL SWITCH (หยุดการทำงานทั้งหมด)", Config.Colors.Danger, function()
        SharedEnv._ScriptWorkerActive = false
        ScreenGui:Destroy()
    end)

    -- Draggable Logic
    local function MakeDraggable(dragHandle, targetFrame)
        local dragging = false
        local dragInput, dragStart, startPos

        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = targetFrame.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        dragHandle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                targetFrame.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    MakeDraggable(Header, MainFrame)
    MakeDraggable(FloatButton, FloatButton)

    local isWindowOpen = true
    local function ToggleWindow()
        isWindowOpen = not isWindowOpen
        if isWindowOpen then
            MainFrame.Visible = true
            TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
                Size = UDim2.new(0, 570, 0, 430)
            }):Play()
        else
            local tw = TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
                Size = UDim2.new(0, 570, 0, 0)
            })
            tw:Play()
            tw.Completed:Connect(function()
                if not isWindowOpen then MainFrame.Visible = false end
            end)
        end
    end

    FloatButton.MouseButton1Click:Connect(ToggleWindow)
    CloseBtn.MouseButton1Click:Connect(ToggleWindow)
end

pcall(function()
    BuildUI()
end)
