-- ==============================================================================
-- PROJECT: KUYKUY HUB Unified Farm & Utility Framework
-- GAME: [🐟] จับปลา! (PlaceId: 93898234979111)
-- VERSION: v3.2.0 [KUYKUY ULTIMATE EDITION - UPDATE 10 SUITE]
-- FEATURES: Auto Net (Perfect Tap & Reel Strategy) / Auto Collect Pads / Auto Equip Best /
--           Auto Rebirth (Up to 50) / Auto Claim Gifts & Free Clams / Auto Sell & Shuck Pearls /
--           Auto Deep Current (Full 12 Tiers) / Multi-Select Potions (Cash + Net) /
--           Multi-Select Upgrades (6 Categories) / Multi-Select Mini-Games (Gold 🥇) /
--           Auto Boss Trio (Megalodon 🦈 + The Bloop 🌊 + Kraken 🐙) /
--           Update 10: Traits Engine / Leviathan Pass / Black Market / Promo Codes
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
        HubName = "KUYKUY HUB",
        Version = "v3.2.0 [KUYKUY ULTIMATE EDITION - UPDATE 10 SUITE]",
        SaveFileName = "KUYKUY_Config_" .. tostring(game.PlaceId) .. ".json"
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
        PearlShop = "PearlShop",
        Current = "Current",
        CurrentPing = "CurrentPing",
        MiniGame = "MiniGame",
        MiniGamePing = "MiniGamePing"
    },
    Settings = {
        -- Auto Net
        AutoNet = true,
        ReelWhenFull = true,
        ReelStrategy = "รอจนเต็มหลอด 100% เท่านั้น (Wait Until 100% Full Only - แนะนำ)", -- โหมดการดึงแห
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
        AutoRejoinAfterHourGifts = false, -- รีเซิร์ฟเวอร์อัตโนมัติเมื่อรับของขวัญออนไลน์ครบ 1 ชม. (รีเซ็ตกล่องใหม่)
        HourGiftsRejoinDelay = 10,       -- หน่วงเวลาก่อนรีเซิร์ฟเวอร์ (วินาที)
        AutoClaimClam = true,           -- หอยมุกฟรี
        AutoClaimContracts = true,      -- เคลมเควสสัญญาจับปลา (Contracts)
        AutoClaimChallenges = true,     -- เคลมเควสท้าทาย (Challenges)
        AutoClaimRetention = true,      -- เคลมเควสประจำวัน & หมุนวงล้อฟรี (Daily & Spins)
        AutoClaimIndexPages = true,     -- เคลมรางวัลสะสมปลาครบหน้า (Index Page Rewards)
        AutoLikeBases = true,           -- กด Like เบสผู้เล่นอื่นรับโบนัส

        -- Mini-Games (เล่นมินิเกมทุกอันอัตโนมัติ)
        AutoMiniGames = true,           -- เล่นมินิเกมอัตโนมัติทุกชนิดเมื่อได้รับคำเชิญ
        MiniGameMode = "ชนะเหรียญทองทุกอัน (Always Gold Medal 🥇)", -- โหมดเล่นมินิเกม
        MiniGameSelectedGames = {       -- มัลติซีเล็คเลือกมินิเกมที่จะเล่น
            Reel = true,
            Jump = true,
            Lures = true
        },

        -- Deep Current (กระแสน้ำลึก)
        AutoCurrent = true,             -- เปิดใช้งานฟังชั่นเรียกลอยกระแสน้ำลึกอัตโนมัติ
        CurrentMode = "อัตโนมัติ: ดีที่สุดตามแต้มชาร์จ (Auto: Best Affordable Tier)", -- โหมดการเรียกสิ่งมีชีวิต

        -- Potions, Skills & Bait
        AutoBuyPotions = true,          -- ซื้อยาจากร้าน Potion Shop เมื่อมีของ
        AutoDrinkPotions = true,        -- เปิดโหมดดื่มยาอัตโนมัติ
        PotionDrinkMode = "ดื่มยาทุกชนิด (All Potions)", -- โหมดการดื่มยา
        PotionSelectedKinds = {         -- มัลติซีเล็คเลือกชนิดยา (เลือกพร้อมกันได้ทั้งเงินและตาข่าย)
            Cash = true,                -- 💵 ยาเพิ่มเงิน (Cash Boost)
            Net = true                  -- 🧪 ยาเพิ่มขนาดตาข่าย (Net Space)
        },
        PotionSelectedTiers = {         -- มัลติซีเล็คเลือกระดับน้ำยา (Tier 1-10)
            [1] = true,
            [2] = true,
            [3] = true,
            [4] = true,
            [5] = true,
            [6] = true,
            [7] = true,
            [8] = true,
            [9] = true,
            [10] = true,
        },
        AutoInvestSkills = true,        -- อัปเกรด Skill Tree อัตโนมัติเมื่อได้แต้มฟรี
        AutoEquipBait = true,           -- สวมใส่เหยื่อที่ดีที่สุด
        AutoBuyBait = true,             -- ซื้อเหยื่อที่ดีที่สุดอัตโนมัติเมื่อหมด (ครั้งละ 10 อัน)
        BaitBatchAmount = 10,           -- จำนวนเหยื่อที่ซื้อต่อครั้ง (10 ชิ้น)

        -- Boss Automation (Megalodon, The Bloop & Kraken - Update 10)
        AutoBossFight = true,           -- ตีบอส Megalodon, The Bloop & Kraken อัตโนมัติ
        BossTargetMode = "สู้บอสทุกตัว (Megalodon, Bloop, Kraken 🦈🌊🐙)", -- ตัวกรองเป้าหมายบอส
        AutoClaimBossLoot = true,       -- เคลมการ์ดของรางวัลบอสอัตโนมัติ

        -- Update 10: Season Pass & Promo Codes
        AutoClaimSeasonPass = true,     -- เคลมของรางวัล Leviathan Pass ฟรีทุกเทียร์อัตโนมัติ
        AutoRedeemCodes = true,         -- แลกโค้ดของขวัญอัตโนมัติ (2MVISITS, 1MVISITS, MONARCH, UPD1)

        -- Update 10: Traits System
        AutoRollTraits = false,         -- สุ่มหมุน Trait อัตโนมัติเมื่อมีสิทธิ์
        AutoEquipBestTrait = true,      -- สวมใส่ Trait ระดับสูงสุดที่มีอัตโนมัติ

        -- Update 10: The Black Market (Silas the Smuggler)
        AutoBuyBlackMarket = false,     -- ซื้อของในตลาดมืดอัตโนมัติเมื่อมีเงินพอ

        -- Auto Sell
        AutoSell = false,
        SellInterval = 20,
        SellRarityMode = "ขายปลาทั่วไปทั้งหมด (Sell All Fish)", -- ตัวกรองระดับปลาที่จะขาย
        KeepMutatedFish = true,         -- เก็บปลาผ่าเหล่า/กลายพันธุ์ (Keep Mutated Fish)
        AutoShuckPearls = false,        -- ผ่าหอยมุกอัตโนมัติก่อนขาย (Auto Shuck Fish Into Pearls)

        -- Auto Upgrades
        AutoUpgrade = true,
        UpgradeInterval = 3,
        UpgradeSelectedCategories = {   -- มัลติซีเล็คหมวดหมู่อัปเกรด
            Net = true,                 -- 🕸️ แห & ตาข่าย
            Boat = true,                -- ⛵ เรือ & อุปกรณ์เรือ
            Fisherman = true,           -- 🎣 คนตกปลาผู้ช่วย
            Spear = true,               -- 🔱 ปืนฉมวกตีบอส
            General = true,             -- ⚙️ ทั่วไป / เบส
            StarPerks = true            -- ★ Ascension Star Perks
        },
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

-- ==============================================================================
-- Persistent Configuration Manager (บันทึกและโหลดการตั้งค่าอัตโนมัติ)
-- ==============================================================================
local CONFIG_FILE_NAME = "KUYKUY_Fishing_Config_" .. tostring(game.PlaceId) .. ".json"

local function SaveConfiguration()
    pcall(function()
        if writefile then
            local data = HttpService:JSONEncode(Config.Settings)
            writefile(CONFIG_FILE_NAME, data)
        end
    end)
end

local function LoadConfiguration()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE_NAME) then
            local content = readfile(CONFIG_FILE_NAME)
            local loaded = HttpService:JSONDecode(content)
            if loaded and type(loaded) == "table" then
                for k, v in pairs(loaded) do
                    if Config.Settings[k] ~= nil then
                        Config.Settings[k] = v
                    end
                end
            end
        end
    end)
end

local function ResetConfiguration()
    pcall(function()
        if delfile and isfile and isfile(CONFIG_FILE_NAME) then
            delfile(CONFIG_FILE_NAME)
        end
    end)
end

-- โหลดการตั้งค่าที่บันทึกไว้ในเครื่องทันทีเมื่อเริ่มทำงาน (หากยังไม่มีไฟล์ จะสร้างและบันทึกค่าเริ่มต้นให้อัตโนมัติ)
pcall(function()
    if isfile and isfile(CONFIG_FILE_NAME) then
        LoadConfiguration()
    else
        SaveConfiguration()
    end
end)

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

-- Server Rejoin & Server Hop Engine (พร้อมระบบตรวจสอบความปลอดภัยก่อนย้ายเซิร์ฟเวอร์)
local TeleportService = game:GetService("TeleportService")

local function IsSafeToRejoin()
    -- ตรวจสอบว่ากำลังดึงแห หรือแหอยู่ในน้ำหรือไม่
    local myBase = GetMyBase()
    if myBase then
        local netState = myBase:GetAttribute("NetState")
        if netState and (netState == "Fishing" or netState == "Thrown" or netState == "Reeling") then
            return false, "กำลังดึงแห (" .. tostring(netState) .. ")"
        end
    end

    -- ตรวจสอบว่ามีอีเวนต์บอสกำลังดำเนินอยู่หรือไม่
    if Workspace:GetAttribute("MegActive") == true then
        return false, "บอส Megalodon กำลังต่อสู้"
    end
    if Workspace:GetAttribute("BloopActive") == true then
        return false, "บอส The Bloop กำลังต่อสู้"
    end
    if Workspace:GetAttribute("BossActive") == true then
        return false, "บอส Kraken กำลังต่อสู้"
    end

    return true, "ปลอดภัย"
end

local function RejoinOrServerHop()
    UpdateStatus("STATUS: ตรวจสอบความปลอดภัยก่อนรีเซิร์ฟเวอร์...")

    -- ตรวจสอบความปลอดภัย: หากยังดึงแหไม่เสร็จ หรือมีบอสค้างอยู่ ให้ดึงแหขึ้นและรอให้เสร็จก่อน
    local safe, reason = IsSafeToRejoin()
    if not safe then
        UpdateStatus("STATUS: ป้องกันของหาย! รอดึงแห/จบบอสก่อนย้าย (" .. reason .. ")")

        -- สั่งดึงแหกลับทันทีเพื่อเตรียมความพร้อม
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(Config.Events.ReelIn) then
            pcall(function()
                remotes[Config.Events.ReelIn]:FireServer()
            end)
        end

        local waited = 0
        while not safe and waited < 60 do
            task.wait(2)
            waited = waited + 2
            safe, reason = IsSafeToRejoin()
            UpdateStatus("STATUS: รอดึงแห/จบบอสให้เรียบร้อยก่อนย้าย... (" .. reason .. ")")
        end
    end

    UpdateStatus("STATUS: ทุกอย่างเสร็จสิ้น ปลอดภัย 100% กำลังรีเซิร์ฟเวอร์...")

    local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if queueTeleport then
        pcall(function()
            queueTeleport([[
                task.wait(3.5)
                loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/games/fishing/main.lua"))()
            ]])
        end)
    end

    task.wait(1.0)

    local hopped = false
    pcall(function()
        local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(game.PlaceId))
        local raw = game:HttpGet(url)
        local data = HttpService:JSONDecode(raw)
        if data and data.data then
            local candidates = {}
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 12) and (s.playing or 0) > 0 then
                    table.insert(candidates, s.id)
                end
            end
            if #candidates > 0 then
                local targetId = candidates[math.random(1, #candidates)]
                hopped = true
                TeleportService:TeleportToPlaceInstance(game.PlaceId, targetId, LocalPlayer)
            end
        end
    end)

    if not hopped then
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
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
local lastNetThrowTime = 0
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
        local pct = math.clamp((netCount / math.max(1, netCap)) * 100, 0, 100)

        if UIReferences.NetStateLabel then
            UIReferences.NetStateLabel.Text = string.format("Net: %s (%d/%d | %.1f%%)", netState, netCount, netCap, pct)
        end

        if netState == "Idle" then
            EnsureOnDock()
            ProcessBaitCycle(remotes)
            throwRemote:FireServer()
            lastNetThrowTime = serverTime
            UpdateStatus("STATUS: NET THROWN! [FISHING STARTED]")
            task.wait(1.0)
        elseif netState == "Fishing" then
            local shouldReel = false
            local strat = Config.Settings.ReelStrategy or "รอจนเต็มหลอด 100% เท่านั้น (Wait Until 100% Full Only - แนะนำ)"
            if strat:find("Instant Fast") then
                shouldReel = true
            elseif strat:find("Fixed 5s") or strat:find("Fixed 3s") then
                shouldReel = (serverTime >= lastNetThrowTime + 5.0) or (netCount >= netCap)
            elseif strat:find("หมดเวลาถอยหลัง") or strat:find("Timeout") then
                -- เต็มความจุ หรือเมื่อหมดเวลาถอยหลัง
                if netCount >= netCap then
                    shouldReel = true
                elseif netReelAt > 0 and serverTime >= netReelAt then
                    shouldReel = true
                end
            else
                -- รอจนเต็มหลอด 100% เท่านั้น (ค่าเริ่มต้น แนะนำ): ดึงเมื่อ netCount >= netCap เท่านั้น ไม่สนตัวนับเวลาถอยหลัง netReelAt
                if netCount >= netCap then
                    shouldReel = true
                end
            end

            if shouldReel then
                -- Perfect Tap
                if Config.Settings.AutoPerfectTap and perfectRemote then
                    perfectRemote:FireServer(serverTime)
                end

                reelRemote:FireServer()
                UpdateStatus(string.format("STATUS: REELED IN %d/%d (%.1f%%) FISH! (PERFECT CATCH)", netCount, netCap, pct))
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
                    local allGiftsClaimed = true
                    for i, gift in ipairs(state.gifts) do
                        if gift.ready and not gift.claimed then
                            rewardsRemote:InvokeServer("claimGift", i)
                            claimedCount = claimedCount + 1
                            UpdateStatus(string.format("STATUS: CLAIMED GIFT #%d (%s)!", i, gift.text or "Reward"))
                            task.wait(0.3)
                        end
                        if not gift.claimed then
                            allGiftsClaimed = false
                        end
                    end

                    -- ตรวจสอบและคลิกปุ่มเปิดของขวัญบนหน้าจอ (ปุ่มไอคอนกล่องของขวัญ "เปิด!" ในแถบ Boosts) โดยตรง
                    pcall(function()
                        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                        local freeGift = playerGui and playerGui:FindFirstChild("BoostsUI") and playerGui.BoostsUI:FindFirstChild("Row") and playerGui.BoostsUI.Row:FindFirstChild("FreeGift")
                        if freeGift and freeGift.Visible then
                            local hitBtn = freeGift:FindFirstChild("Hit")
                            if hitBtn then
                                if firesignal then
                                    firesignal(hitBtn.MouseButton1Click)
                                elseif getconnections then
                                    for _, conn in ipairs(getconnections(hitBtn.MouseButton1Click)) do
                                        conn:Fire()
                                    end
                                end
                            end
                        end
                    end)

                    -- Auto Rejoin after 1-Hour gifts are all claimed to reset gift boxes
                    if Config.Settings.AutoRejoinAfterHourGifts and allGiftsClaimed and (state.played or 0) >= 60 then
                        if not SharedEnv._HourRejoinTriggered then
                            SharedEnv._HourRejoinTriggered = true
                            task.spawn(function()
                                local delayTime = Config.Settings.HourGiftsRejoinDelay or 10
                                UpdateStatus(string.format("STATUS: ALL 1-HOUR GIFTS CLAIMED! REJOINING TO RESET GIFTS IN %d SECONDS...", delayTime))
                                task.wait(delayTime)
                                RejoinOrServerHop()
                            end)
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

    -- 8. Leviathan Pass (Season Pass - Free Tiers)
    if Config.Settings.AutoClaimSeasonPass and remotes:FindFirstChild("SeasonPass") then
        pcall(function()
            local spState = remotes.SeasonPass:InvokeServer("state")
            if spState and spState.tier then
                local maxTier = spState.tier
                local freeClaimed = spState.free or {}
                for t = 1, maxTier do
                    if not freeClaimed[tostring(t)] then
                        local res = remotes.SeasonPass:InvokeServer("claim", { gold = false, tier = t })
                        if res and (res.ok or res.reward or res.claimed or not res.err) then
                            claimedCount = claimedCount + 1
                            UpdateStatus(string.format("STATUS: CLAIMED LEVIATHAN PASS TIER %d!", t))
                            task.wait(0.2)
                        end
                    end
                end
            end
        end)
    end

    -- 9. Auto Redeem Active Promo Codes (2MVISITS, 1MVISITS, MONARCH, UPD1)
    if Config.Settings.AutoRedeemCodes and remotes:FindFirstChild("Rewards") and not SharedEnv._CodesRedeemedThisSession then
        SharedEnv._CodesRedeemedThisSession = true
        task.spawn(function()
            local promoCodes = { "2MVISITS", "1MVISITS", "MONARCH", "UPD1" }
            for _, code in ipairs(promoCodes) do
                pcall(function()
                    local res = remotes.Rewards:InvokeServer("redeem", code)
                    if res and (res.ok or res.claimed) then
                        claimedCount = claimedCount + 1
                        UpdateStatus(string.format("STATUS: REDEEMED PROMO CODE [%s]!", code))
                    end
                end)
                task.wait(0.4)
            end
        end)
    end

    -- 10. Traits Auto Equip Best & Auto Roll
    if remotes:FindFirstChild("Traits") then
        pcall(function()
            local trState = remotes.Traits:InvokeServer("state")
            if trState then
                -- Auto roll traits if user enabled and has free rolls
                if Config.Settings.AutoRollTraits and (trState.rolls or 0) > 0 then
                    local rollAmt = (trState.rolls >= 10) and 10 or 1
                    local rollRes = remotes.Traits:InvokeServer("roll", rollAmt)
                    if rollRes and rollRes.ok then
                        UpdateStatus(string.format("STATUS: ROLLED %d TRAITS!", rollAmt))
                        task.wait(0.3)
                        trState = remotes.Traits:InvokeServer("state")
                    end
                end

                -- Auto equip highest trait
                if Config.Settings.AutoEquipBestTrait and trState and trState.best and trState.trait ~= trState.best then
                    local equipRes = remotes.Traits:InvokeServer("equip", trState.best)
                    if equipRes and equipRes.ok then
                        UpdateStatus(string.format("STATUS: EQUIPPED BEST TRAIT (TIER %d)!", trState.best))
                    end
                end
            end
        end)
    end

    return claimedCount
end

SpawnWorker("AutoClaimWorker", function()
    RunMegaClaimCycle()
    task.wait(15.0 + math.random(1, 5))
end)

-- ==============================================================================
-- Task: Deep Current Automation (ระบบเรียกลอยกระแสน้ำลึกอัตโนมัติ)
-- ==============================================================================
local CurrentStateCache = nil

local function RunCurrentCycle()
    if not Config.Settings.AutoCurrent then return end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes or not FishingShared or not FishingShared.Current then return end

    local currentRemote = remotes:FindFirstChild("Current")
    if not currentRemote then return end

    local ok, state = pcall(function()
        return currentRemote:InvokeServer("state")
    end)
    if not ok or type(state) ~= "table" then return end
    CurrentStateCache = state

    -- If a creature is already riding the current, wait for it to be caught by the net
    if state.active ~= nil then
        return
    end

    local currentPts = state.pts or 0
    if currentPts < 3 then
        return
    end

    local currentNet = FishingShared.Nets[state.net or 1]
    local maxRarity = currentNet and (currentNet.MaxRarity or 3) or 3
    local netCap = state.cap or (currentNet and currentNet.Capacity) or 999999

    local targets = FishingShared.Current.Targets
    if not targets or #targets == 0 then return end

    local chosenTarget = nil
    local mode = Config.Settings.CurrentMode or "อัตโนมัติ: ดีที่สุดตามแต้มชาร์จ (Auto: Best Affordable Tier)"

    if mode:find("ดีที่สุด") or mode:find("Best Affordable") then
        -- Find highest tier creature that we have enough points and net requirement for
        for i = #targets, 1, -1 do
            local t = targets[i]
            local canCatch = maxRarity >= t.r
            local hasPoints = currentPts >= t.cost
            local hasSpace = not netCap or (FishingShared.FishCost(t.r) <= netCap)

            if canCatch and hasPoints and hasSpace then
                chosenTarget = t
                break
            end
        end
    elseif mode:find("รอแต้ม") or mode:find("Highest Unlocked") or mode:find("Highest Net Tier") then
        -- Find the highest tier creature our net can catch, and only call when points reach its cost
        local highestUnlocked = nil
        for i = #targets, 1, -1 do
            local t = targets[i]
            if maxRarity >= t.r then
                highestUnlocked = t
                break
            end
        end
        if highestUnlocked and currentPts >= highestUnlocked.cost then
            local hasSpace = not netCap or (FishingShared.FishCost(highestUnlocked.r) <= netCap)
            if hasSpace then
                chosenTarget = highestUnlocked
            end
        end
    else
        -- Match specific tier by name or cost from dropdown
        for _, t in ipairs(targets) do
            local rInfo = FishingShared.Rarities[t.r]
            local rName = (rInfo and rInfo.Name) or ""
            if (rName ~= "" and mode:find(rName)) or mode:find(tostring(t.cost) .. " ⚡") or mode:find("%(" .. tostring(t.cost) .. " ") then
                local canCatch = maxRarity >= t.r
                local hasPoints = currentPts >= t.cost
                local hasSpace = not netCap or (FishingShared.FishCost(t.r) <= netCap)
                if canCatch and hasPoints and hasSpace then
                    chosenTarget = t
                end
                break
            end
        end
    end

    if chosenTarget then
        local rInfo = FishingShared.Rarities[chosenTarget.r]
        local rName = rInfo and rInfo.Name or tostring(chosenTarget.r)
        local callOk, callRes = pcall(function()
            return currentRemote:InvokeServer("call", chosenTarget.r)
        end)
        if callOk and type(callRes) == "table" and callRes.ok then
            CurrentStateCache = callRes.state or CurrentStateCache
            local creatureName = callRes.state and callRes.state.active and callRes.state.active.s or rName
            UpdateStatus(string.format("STATUS: 🌊 SUMMONED BEST DEEP CURRENT: %s (Tier %d, Cost %d)!", tostring(creatureName), chosenTarget.r, chosenTarget.cost))
        end
    end
end

-- Realtime Listener for Deep Current State Updates
local function InitializeCurrentPing()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local currentPing = remotes and remotes:FindFirstChild("CurrentPing")
    if currentPing then
        currentPing.OnClientEvent:Connect(function(state)
            if not IsSessionValid() then return end
            if type(state) == "table" then
                CurrentStateCache = state
                if Config.Settings.AutoCurrent and state.active == nil and (state.pts or 0) >= 3 then
                    task.spawn(RunCurrentCycle)
                end
            end
        end)
    end
end
task.spawn(InitializeCurrentPing)

SpawnWorker("DeepCurrentWorker", function()
    if Config.Settings.AutoCurrent then
        RunCurrentCycle()
    end
    task.wait(6.0 + math.random(1, 3))
end)

-- ==============================================================================
-- ==============================================================================
-- Auto Mini-Games Engine (Perfect Reel, Fish Frenzy, Bait Memory -> Always Gold 🥇)
-- ==============================================================================

-- 1. Dual Hook RemoteFunction.InvokeServer (both hookfunction and hookmetamethod to guarantee Gold Medal)
if not SharedEnv._MiniGameHooked then
    SharedEnv._MiniGameHooked = true
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local mgRemote = remotes and remotes:FindFirstChild(Config.Events.MiniGame)
        if mgRemote then
            local function ModifyFinishArgs(self, args)
                if (self == mgRemote or (self and self.Name == "MiniGame")) and args and args[1] == "finish" then
                    local currentScore = args[3]
                    local isCancel = args[4]
                    if Config.Settings.AutoMiniGames and not isCancel then
                        -- Compute Gold Medal target score (based on ReplicatedStorage.MiniGames thresholds)
                        -- Reel: 560 threshold -> 620
                        -- Jump: 430 threshold -> 480
                        -- Lures: 8 threshold -> 11
                        local goldScore = 620
                        if type(currentScore) == "number" then
                            if currentScore <= 20 then
                                goldScore = 11 -- Lures
                            elseif currentScore <= 500 then
                                goldScore = 480 -- Jump
                            else
                                goldScore = 620 -- Reel
                            end
                        end
                        args[3] = goldScore
                        UpdateStatus(string.format("STATUS: 🥇 INJECTED GOLD MEDAL SCORE (%d) FOR MINIGAME!", goldScore))
                    end
                end
                return args
            end

            -- Hook 1: Direct method hook on RemoteFunction prototype (for pcall(MiniGame.InvokeServer, MiniGame, ...))
            if typeof(hookfunction) == "function" then
                local oldInvoke
                local protoInvoke = Instance.new("RemoteFunction").InvokeServer
                oldInvoke = hookfunction(protoInvoke, function(self, ...)
                    local args = { ... }
                    args = ModifyFinishArgs(self, args)
                    return oldInvoke(self, unpack(args))
                end)
            end

            -- Hook 2: Metamethod hook (for MiniGame:InvokeServer(...))
            if typeof(hookmetamethod) == "function" then
                local rawNamecall
                rawNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                    local method = getnamecallmethod()
                    if method == "InvokeServer" and (self == mgRemote or (self and self.Name == "MiniGame")) then
                        local args = { ... }
                        args = ModifyFinishArgs(self, args)
                        return rawNamecall(self, unpack(args))
                    end
                    return rawNamecall(self, ...)
                end)
            end
        end
    end)
end

-- 2. MiniGame Invitation Listener
local function InitializeMiniGameListener()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local pingRemote = remotes and remotes:FindFirstChild(Config.Events.MiniGamePing)
    if not pingRemote then return end

    pingRemote.OnClientEvent:Connect(function(msg)
        if not IsSessionValid() then return end
        if type(msg) ~= "table" then return end
        if not Config.Settings.AutoMiniGames then return end

        if msg.kind == "invite" and msg.game then
            local gameId = msg.game
            local selectedGames = Config.Settings.MiniGameSelectedGames or { Reel = true, Jump = true, Lures = true }
            if selectedGames[gameId] ~= true then return end

            UpdateStatus(string.format("STATUS: 🎮 ได้รับคำเชิญมินิเกม [%s]! รอเปิดหน้าต่างแล้วกดเล่นอัตโนมัติ...", gameId))
            if UIReferences.MiniGameStatusCard then
                UIReferences.MiniGameStatusCard.Text = string.format("🎮 กำลังเล่นมินิเกม: [%s] (เหรียญทอง 🥇)", gameId)
            end
        end
    end)
end
task.spawn(InitializeMiniGameListener)

-- Helper: Check if a GuiObject is genuinely visible (every ancestor up to ScreenGui is Visible)
local function IsReallyVisible(guiObj)
    if not guiObj or not guiObj:IsA("GuiObject") then return false end
    local current = guiObj
    while current and current:IsA("GuiObject") do
        if not current.Visible then
            return false
        end
        current = current.Parent
    end
    return true
end

-- Helper: Thoroughly click a button via all signals
local function ClickButton(btn)
    if not btn then return end
    if firesignal then
        pcall(function() firesignal(btn.MouseButton1Down) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.Activated) end)
        pcall(function() firesignal(btn.MouseButton1Up) end)
    end
    if getconnections then
        for _, conn in ipairs(getconnections(btn.MouseButton1Down)) do
            pcall(function() conn:Fire() end)
        end
        for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
            pcall(function() conn:Fire() end)
        end
        for _, conn in ipairs(getconnections(btn.Activated)) do
            pcall(function() conn:Fire() end)
        end
    end
end

-- 3. Dedicated MiniGame UI Auto-Player Worker
SpawnWorker("MiniGameAutoWorker", function()
    if not Config.Settings.AutoMiniGames then
        task.wait(1.5)
        return
    end

    pcall(function()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        local mgUI = pgui and pgui:FindFirstChild("MiniGameUI")
        if not mgUI or not mgUI.Enabled then
            task.wait(0.2)
            return
        end

        -- Stage 1: Auto Accept Invite Screen ("▶ PLAY!")
        local playBtn = mgUI:FindFirstChild("PlayButton", true)
        if playBtn and playBtn:IsA("TextButton") and IsReallyVisible(playBtn) then
            UpdateStatus("STATUS: 🎮 ตรวจพบหน้าต่างเชิญมินิเกม! กำลังกดปุ่ม ▶ PLAY เริ่มเล่นอัตโนมัติ...")
            ClickButton(playBtn)
            task.wait(0.5)
            return
        end

        -- Stage 2: Auto Play Active Mini-Games
        -- 2A. Fish Frenzy (Jump) - Catch jumping fish at Spot1..Spot5 (avoid boots 👢)
        for s = 1, 5 do
            local spot = mgUI:FindFirstChild("Spot" .. s, true)
            if spot and spot:IsA("TextButton") and IsReallyVisible(spot) then
                for _, ch in ipairs(spot:GetChildren()) do
                    if ch:IsA("TextLabel") and ch.Visible then
                        local txt = ch.Text
                        if txt == "🐟" or txt == "🐠" or txt == "🐡" then
                            ClickButton(spot)
                            local keyMap = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
                            if keyMap[s] then
                                pcall(function()
                                    VirtualInputManager:SendKeyEvent(true, keyMap[s], false, game)
                                    task.wait(0.01)
                                    VirtualInputManager:SendKeyEvent(false, keyMap[s], false, game)
                                end)
                            end
                            break
                        end
                    end
                end
            end
        end

        -- 2B. Perfect Reel (Reel) - Tap ReelButton / Spacebar
        local reelBtn = mgUI:FindFirstChild("ReelButton", true)
        if reelBtn and reelBtn:IsA("TextButton") and IsReallyVisible(reelBtn) then
            ClickButton(reelBtn)
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.02)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
            local area = mgUI:FindFirstChild("Area", true)
            if area then
                for _, ch in ipairs(area:GetChildren()) do
                    if ch:IsA("TextButton") and ch.Visible then
                        ClickButton(ch)
                    end
                end
            end
        end

        -- 2C. Bait Memory (Lures) - Tap Bait buttons
        for b = 1, 4 do
            local baitBtn = mgUI:FindFirstChild("Bait" .. b, true)
            if baitBtn and baitBtn:IsA("TextButton") and IsReallyVisible(baitBtn) then
                ClickButton(baitBtn)
                local keyMap = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
                if keyMap[b] then
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(true, keyMap[b], false, game)
                        task.wait(0.01)
                        VirtualInputManager:SendKeyEvent(false, keyMap[b], false, game)
                    end)
                end
            end
        end

        -- Stage 3: Auto Collect Reward on Result screen ("Collect" / "เก็บ!")
        local collectBtn = mgUI:FindFirstChild("Collect", true)
        if collectBtn and collectBtn:IsA("TextButton") and IsReallyVisible(collectBtn) then
            UpdateStatus("STATUS: 🥇 มินิเกมจบแล้ว! กำลังกดรับรางวัลเหรียญทอง (COLLECT)...")
            task.wait(0.8)
            ClickButton(collectBtn)
            task.wait(0.5)
            return
        end
    end)

    task.wait(0.12)
end)

-- Task 8: Potions, Skill Tree & Best Bait Worker
local function RunPotionsAndSkillsCycle()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return end

    -- 1. Auto Potions (ซื้อยา & ดื่มยา)
    if Config.Settings.AutoDrinkPotions and remotes:FindFirstChild("Potions") then
        local potionRemote = remotes.Potions
        local selectedKinds = Config.Settings.PotionSelectedKinds or { Cash = true, Net = true }
        local selectedTiers = Config.Settings.PotionSelectedTiers or {}

        -- Check if all 10 tiers are selected and both Cash + Net kinds are selected
        local allTiersSelected = true
        for t = 1, 10 do
            if not selectedTiers[t] then
                allTiersSelected = false
                break
            end
        end
        local allKindsSelected = (selectedKinds.Cash == true and selectedKinds.Net == true)

        if allTiersSelected and allKindsSelected then
            pcall(function()
                local res = potionRemote:InvokeServer("useAll")
                if res and res.ok and res.drank and res.drank > 0 then
                    UpdateStatus(string.format("STATUS: DRANK %d POTIONS FROM COOLER!", res.drank))
                end
            end)
        elseif selectedKinds.Cash or selectedKinds.Net then
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
                            local kind, tierStr = key:match("^(%a+)_(%d+)$")
                            local tier = tonumber(tierStr) or 0
                            local kindAllowed = (selectedKinds[kind] == true)
                            local tierAllowed = (selectedTiers[tier] == true)

                            if kindAllowed and tierAllowed then
                                potionRemote:InvokeServer("use", key)
                                UpdateStatus(string.format("STATUS: DRANK POTION [%s] (Tier %d)!", key, tier))
                                task.wait(0.12)
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
                local selectedKinds = Config.Settings.PotionSelectedKinds or { Cash = true, Net = true }
                local selectedTiers = Config.Settings.PotionSelectedTiers or {}
                if state and state.stock and state.cash then
                    for i, p in ipairs(state.stock) do
                        local kindAllowed = (p.kind == nil or selectedKinds[p.kind] == true)
                        local tierAllowed = (p.tier == nil or selectedTiers[p.tier] == true)
                        if not p.bought and p.price and state.cash >= p.price and kindAllowed and tierAllowed then
                            local buyRes = potionRemote:InvokeServer("buy", i)
                            if buyRes and buyRes.ok then
                                state.cash = state.cash - p.price
                                task.wait(0.15)
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

-- Helper: Accurate Megalodon Aim Position Resolver
local function GetMegalodonAimPosition()
    -- 1. Scan workspace.MegalodonLocal for the Megalodon part/model
    local megFolder = workspace:FindFirstChild("MegalodonLocal")
    if megFolder then
        local meg = megFolder:FindFirstChild("Megalodon")
            or megFolder:FindFirstChildWhichIsA("BasePart")
            or megFolder:FindFirstChildWhichIsA("Model")
        if meg then
            if meg:IsA("BasePart") then
                return meg.Position
            elseif meg:IsA("Model") then
                return meg:GetPivot().Position
            end
        end
    end

    -- 2. Compute path position using FishingShared.MegPos and elapsed time from MegStart
    if FishingShared and FishingShared.MegPos then
        local megStart = workspace:GetAttribute("MegStart") or 0
        local elapsed = math.max(0, workspace:GetServerTimeNow() - megStart)
        local ok, pos = pcall(function()
            return FishingShared.MegPos(elapsed)
        end)
        if ok and typeof(pos) == "Vector3" then
            return pos
        end
    end

    -- 3. Fallback
    return Vector3.new(0, -6, 200)
end

-- Helper: Universal Megalodon Spear Attack Trigger (UI Click + Space Key + Virtual Mouse + Remote)
local function FireTurretSpearAtMegalodon(remotes)
    local targetPos = GetMegalodonAimPosition()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local turretUI = pGui and pGui:FindFirstChild("MegTurretUI")

    -- 1. Direct In-Game Client UI Trigger (If Turret UI is open)
    if turretUI then
        local fireBtn = turretUI:FindFirstChild("Fire", true)
        if fireBtn then
            if typeof(firesignal) == "function" then
                pcall(function() firesignal(fireBtn.MouseButton1Click) end)
                pcall(function() firesignal(fireBtn.Activated) end)
            end
        end
    end

    -- 2. Virtual Key Press (Space key directly triggers MegalodonClient fireNow)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)

    -- 3. Virtual Mouse Click with Aim Coordinate
    pcall(function()
        local camera = workspace.CurrentCamera
        local viewSize = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local screenPos = Vector2.new(viewSize.X / 2, viewSize.Y * 0.45)
        if camera and targetPos then
            local w2s, onScreen = camera:WorldToViewportPoint(targetPos)
            if onScreen then
                screenPos = Vector2.new(w2s.X, w2s.Y)
            end
        end
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
    end)

    -- 4. Direct Server Remote Call (Double-tap with exact target coordinates)
    if remotes and remotes:FindFirstChild("MegEvent") and targetPos then
        pcall(function()
            remotes.MegEvent:FireServer("fire", targetPos)
        end)
    end
end

-- Helper: Accurate The Bloop Aim Position Resolver
local function GetBloopAimPosition()
    -- 1. Scan workspace.BloopLocal for the Bloop part/model
    local bloopFolder = workspace:FindFirstChild("BloopLocal")
    if bloopFolder then
        local bloop = bloopFolder:FindFirstChild("Bloop")
            or bloopFolder:FindFirstChildWhichIsA("BasePart")
            or bloopFolder:FindFirstChildWhichIsA("Model")
        if bloop then
            if bloop:IsA("BasePart") then
                return bloop.Position
            elseif bloop:IsA("Model") then
                return bloop:GetPivot().Position
            end
        end
    end

    -- 2. Compute path position using FishingShared.BloopPos and elapsed time from BloopStart
    if FishingShared and FishingShared.BloopPos then
        local bloopStart = workspace:GetAttribute("BloopStart") or 0
        local elapsed = math.max(0, workspace:GetServerTimeNow() - bloopStart)
        local ok, pos = pcall(function()
            return FishingShared.BloopPos(elapsed)
        end)
        if ok and typeof(pos) == "Vector3" then
            return pos
        end
    end

    -- 3. Fallback
    return Vector3.new(0, -22, 0)
end

-- Helper: Universal Bloop Spear Attack Trigger (UI Click + Space Key + Virtual Mouse + Remote)
local function FireTurretSpearAtBloop(remotes)
    local targetPos = GetBloopAimPosition()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local turretUI = pGui and pGui:FindFirstChild("BloopTurretUI")

    -- 1. Direct In-Game Client UI Trigger (If Bloop Turret UI is open)
    if turretUI then
        local fireBtn = turretUI:FindFirstChild("Fire", true)
            or turretUI:FindFirstChild("Shoot", true)
            or turretUI:FindFirstChild("FireBtn", true)
        if fireBtn then
            if typeof(firesignal) == "function" then
                pcall(function() firesignal(fireBtn.MouseButton1Click) end)
                pcall(function() firesignal(fireBtn.Activated) end)
            end
        end
    end

    -- 2. Virtual Key Press (Space key directly triggers Bloop fireNow)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)

    -- 3. Virtual Mouse Click with Aim Coordinate
    pcall(function()
        local camera = workspace.CurrentCamera
        local viewSize = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local screenPos = Vector2.new(viewSize.X / 2, viewSize.Y * 0.45)
        if camera and targetPos then
            local w2s, onScreen = camera:WorldToViewportPoint(targetPos)
            if onScreen then
                screenPos = Vector2.new(w2s.X, w2s.Y)
            end
        end
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
    end)

    -- 4. Direct Server Remote Call
    if remotes and remotes:FindFirstChild("BloopEvent") and targetPos then
        pcall(function()
            remotes.BloopEvent:FireServer("fire", targetPos)
        end)
    end
end

-- Task 9: Auto Boss Fighter (Megalodon, The Bloop & Kraken Auto Fight & Loot)
SpawnWorker("AutoBossWorker", function()
    if not Config.Settings.AutoBossFight then
        task.wait(2.5)
        return
    end

    local bMode = Config.Settings.BossTargetMode or "สู้บอสทุกตัว (Megalodon, Bloop, Kraken 🦈🌊🐙)"
    if bMode == "ปิดการล่าบอส (Disabled)" then
        task.wait(2.5)
        return
    end

    local allowMeg = (bMode == "สู้บอสทุกตัว (Megalodon, Bloop, Kraken 🦈🌊🐙)" or bMode == "เฉพาะฉลามยักษ์ Megalodon 🦈")
    local allowBloop = (bMode == "สู้บอสทุกตัว (Megalodon, Bloop, Kraken 🦈🌊🐙)" or bMode == "เฉพาะสัตว์ประหลาด The Bloop 🌊")
    local allowKraken = (bMode == "สู้บอสทุกตัว (Megalodon, Bloop, Kraken 🦈🌊🐙)" or bMode == "เฉพาะปลาหมึกยักษ์ Kraken 🐙")

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then
        task.wait(2.5)
        return
    end

    local megEvent = remotes:FindFirstChild("MegEvent")
    local bloopEvent = remotes:FindFirstChild("BloopEvent")
    local bossEvent = remotes:FindFirstChild("BossEvent")

    -- 1. Check Megalodon Event
    if allowMeg and megEvent and workspace:GetAttribute("MegActive") == true then
        UpdateStatus("STATUS: MEGALODON DETECTED! ENTERING TURRET FIGHT...")

        -- Ensure player is mounted in the turret
        pcall(function()
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local turretUI = pGui and pGui:FindFirstChild("MegTurretUI")
            if not (turretUI and turretUI.Enabled) then
                megEvent:FireServer("enter")
                task.wait(0.4)
            end
        end)

        -- Combat loop while Megalodon is alive
        local fightStart = os.clock()
        while workspace:GetAttribute("MegActive") == true and (os.clock() - fightStart < 195) and IsSessionValid() do
            if not Config.Settings.AutoBossFight then break end

            -- Re-enter turret mode if dropped out
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local turretUI = pGui and pGui:FindFirstChild("MegTurretUI")
            if not (turretUI and turretUI.Enabled) then
                pcall(function() megEvent:FireServer("enter") end)
                task.wait(0.3)
            end

            -- Direct camera to face Megalodon for turret crosshair lock
            pcall(function()
                local targetPos = GetMegalodonAimPosition()
                local cam = workspace.CurrentCamera
                if cam and targetPos then
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
                end
            end)

            -- Fire through all channels (UI, Space, Mouse, Remote)
            FireTurretSpearAtMegalodon(remotes)
            UpdateStatus("STATUS: 🔥 FIRING SPEARS AT MEGALODON!")

            -- Poll at 0.5s interval to immediately fire once the 2.0s cooldown finishes
            task.wait(0.5)
        end

        -- Battle finished: claim victory rewards
        task.wait(1.5)
        pcall(function()
            megEvent:FireServer("closed")
        end)
        UpdateStatus("STATUS: MEGALODON DEFEATED! CLAIMED VICTORY LOOT!")
    end

    -- 2. Check The Bloop Event (Update 10)
    if allowBloop and bloopEvent and workspace:GetAttribute("BloopActive") == true then
        UpdateStatus("STATUS: 🌊 THE BLOOP DETECTED! ENTERING TURRET FIGHT...")

        -- Ensure player is mounted in the Bloop turret
        pcall(function()
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local turretUI = pGui and pGui:FindFirstChild("BloopTurretUI")
            if not (turretUI and turretUI.Enabled) then
                bloopEvent:FireServer("enter")
                task.wait(0.4)
            end
        end)

        -- Combat loop while The Bloop is active
        local bloopFightStart = os.clock()
        while workspace:GetAttribute("BloopActive") == true and (os.clock() - bloopFightStart < 250) and IsSessionValid() do
            if not Config.Settings.AutoBossFight then break end

            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local turretUI = pGui and pGui:FindFirstChild("BloopTurretUI")
            if not (turretUI and turretUI.Enabled) then
                pcall(function() bloopEvent:FireServer("enter") end)
                task.wait(0.3)
            end

            pcall(function()
                local targetPos = GetBloopAimPosition()
                local cam = workspace.CurrentCamera
                if cam and targetPos then
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
                end
            end)

            FireTurretSpearAtBloop(remotes)
            UpdateStatus("STATUS: 🔥 FIRING SPEARS AT THE BLOOP!")
            task.wait(0.5)
        end

        task.wait(1.5)
        pcall(function()
            bloopEvent:FireServer("closed")
        end)
        UpdateStatus("STATUS: THE BLOOP DEFEATED! CLAIMED VICTORY LOOT!")
    end

    -- 3. Kraken Boss / General Sea Boss Event
    if allowKraken and workspace:GetAttribute("BossActive") == true then
        UpdateStatus("STATUS: 🐙 KRAKEN ACTIVE! FIGHTING WITH NETS & WEAPONS...")
    end

    if allowKraken and bossEvent and Config.Settings.AutoClaimBossLoot then
        -- Auto close/claim Kraken loot card if open
        pcall(function()
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local bossUI = pGui and (pGui:FindFirstChild("BossUI") or pGui:FindFirstChild("LootUI") or pGui:FindFirstChild("BossDrops") or pGui:FindFirstChild("KrakenDrops"))
            if (bossUI and bossUI.Enabled) or workspace:GetAttribute("BossActive") == false then
                bossEvent:FireServer("closed")
            end
        end)
    end

    task.wait(1.5)
end)

-- Task: The Black Market Auto Buyer (Silas the Smuggler)
SpawnWorker("AutoBlackMarketWorker", function()
    if not Config.Settings.AutoBuyBlackMarket then
        task.wait(3.0)
        return
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local bmRemote = remotes and remotes:FindFirstChild("BlackMarket")
    if bmRemote then
        pcall(function()
            local state = bmRemote:InvokeServer("state")
            if state and state.items and state.cash then
                for _, item in ipairs(state.items) do
                    if not item.bought and item.price and state.cash >= item.price then
                        local res = bmRemote:InvokeServer("buy", item.id)
                        if res and (res.ok or res.bought) then
                            state.cash = state.cash - item.price
                            UpdateStatus(string.format("STATUS: BOUGHT BLACK MARKET ITEM [%s]!", item.name or item.id))
                            task.wait(0.3)
                        end
                    end
                end
            end
        end)
    end

    task.wait(15.0 + math.random(2, 5))
end)

-- Task 6: Auto Sell Worker
SpawnWorker("AutoSellWorker", function()
    if not Config.Settings.AutoSell then
        task.wait(2.0)
        return
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        if Config.Settings.AutoShuckPearls and remotes:FindFirstChild("CoolerAction") then
            pcall(function() remotes.CoolerAction:InvokeServer("shuck") end)
            task.wait(0.3)
        end
        local sellRemote = remotes:FindFirstChild(Config.Events.SellFish)
        if sellRemote then
            sellRemote:FireServer()
        end
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

    local upCats = Config.Settings.UpgradeSelectedCategories or {}
    local allowNet = (upCats.Net ~= false) and (Config.Settings.UpgradeNet ~= false)
    local allowBoat = (upCats.Boat ~= false) and (Config.Settings.UpgradeBoat ~= false)
    local allowFisherman = (upCats.Fisherman ~= false) and (Config.Settings.UpgradeFisherman ~= false)
    local allowSpear = (upCats.Spear ~= false) and (Config.Settings.UpgradeSpear ~= false)
    local allowGeneral = (upCats.General ~= false) and (Config.Settings.UpgradeGeneral ~= false)
    local allowStarPerks = (upCats.StarPerks == true)

    -- 1. Upgrade Net (ตาข่าย - อันดับความสำคัญสูงสุดในหมวดอัปเกรด ซื้อและใส่แหที่ดีที่สุดทันที)
    if allowNet then
        local netUpgrades = UpgradeBestNet(remotes, data)
        upgradedCount = upgradedCount + netUpgrades
        currentCash = data.Cash or currentCash
    end

    -- 2. Upgrade Boat (เรือ)
    if allowBoat and remotes:FindFirstChild("BoatAction") then
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
    if allowFisherman and remotes:FindFirstChild("HelperAction") and FishingShared.Helper and FishingShared.Helper.Upgrades then
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
    if allowSpear and remotes:FindFirstChild("SpearAction") and FishingShared.Spear and FishingShared.Spear.Upgrades then
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
    if allowGeneral and remotes:FindFirstChild("BuyItem") and FishingShared.Upgrades then
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

    -- 6. Upgrade Ascension Star Perks (สตาร์เพิร์กจุติ)
    if allowStarPerks and remotes:FindFirstChild("Ascension") and FishingShared.AscPerks then
        pcall(function()
            local ascRemote = remotes.Ascension
            local aState = ascRemote:InvokeServer("state")
            if aState and (aState.stars or 0) > 0 and aState.perks then
                for _, perk in ipairs(FishingShared.AscPerks) do
                    local curLvl = tonumber(aState.perks[perk.Id]) or 0
                    if curLvl < (perk.Max or 10) then
                        local cost = FishingShared.AscPerkCost and FishingShared.AscPerkCost(curLvl + 1) or 1
                        if (aState.stars or 0) >= cost then
                            local bRes = ascRemote:InvokeServer("buy", perk.Id)
                            if bRes and bRes.state then
                                aState = bRes.state
                                upgradedCount = upgradedCount + 1
                                UpdateStatus(string.format("STATUS: UPGRADED STAR PERK [%s] LVL %d!", perk.Name, curLvl + 1))
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end
        end)
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
-- 4. UI CREATION (KUYKUY HUB - MODERN DARK PURPLE UNIFIED HUB)
-- ==============================================================================
local function BuildUI()
    local oldUI = CoreGui:FindFirstChild("KUYKUY_ScreenGui") or CoreGui:FindFirstChild("NexusHub_ScreenGui") or (LocalPlayer:FindFirstChildOfClass("PlayerGui") and (LocalPlayer.PlayerGui:FindFirstChild("KUYKUY_ScreenGui") or LocalPlayer.PlayerGui:FindFirstChild("NexusHub_ScreenGui")))
    if oldUI then oldUI:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KUYKUY_ScreenGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local parentSuccess = pcall(function() ScreenGui.Parent = CoreGui end)
    if not parentSuccess or not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Floating Action Button (ตอนย่อหน้าต่าง ui เป็นรูปการ์ตูนควาย)
    local FloatButton = Instance.new("TextButton")
    FloatButton.Name = "KUYKUY_FloatButton"
    FloatButton.Size = UDim2.new(0, 52, 0, 52)
    FloatButton.Position = UDim2.new(0, 25, 0.35, 0)
    FloatButton.BackgroundColor3 = Config.Colors.Card
    FloatButton.Text = "🐃"
    FloatButton.TextSize = 28
    FloatButton.AutoButtonColor = false
    FloatButton.Parent = ScreenGui

    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatButton

    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Config.Colors.Gold
    FloatStroke.Thickness = 2.2
    FloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    FloatStroke.Parent = FloatButton

    -- Cartoon Buffalo Image Sticker inside
    local BuffaloIcon = Instance.new("ImageLabel")
    BuffaloIcon.Name = "BuffaloIcon"
    BuffaloIcon.Size = UDim2.new(1, -6, 1, -6)
    BuffaloIcon.Position = UDim2.new(0, 3, 0, 3)
    BuffaloIcon.BackgroundTransparency = 1
    BuffaloIcon.Image = "rbxassetid://15264624467"
    BuffaloIcon.ScaleType = Enum.ScaleType.Fit
    BuffaloIcon.ZIndex = FloatButton.ZIndex + 1
    BuffaloIcon.Parent = FloatButton

    -- If image fails to load or slow CDN, text "🐃" remains visible under it
    task.delay(1.5, function()
        if BuffaloIcon and BuffaloIcon.IsLoaded then
            FloatButton.Text = ""
        end
    end)

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
            SaveConfiguration()
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
                SaveConfiguration()
            end)
        end

        return card
    end

    local function CreateMultiSelectDropdown(parent, title, options, selectedMap, callback)
        local isExpanded = false
        selectedMap = selectedMap or {}

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
        titleLabel.Size = UDim2.new(0.48, -12, 1, 0)
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
        selectBtn.Parent = header

        local selectCorner = Instance.new("UICorner")
        selectCorner.CornerRadius = UDim.new(0, 4)
        selectCorner.Parent = selectBtn

        -- Options container
        local optionsContainer = Instance.new("Frame")
        optionsContainer.Position = UDim2.new(0, 12, 0, 44)
        optionsContainer.Size = UDim2.new(1, -24, 0, 0)
        optionsContainer.BackgroundTransparency = 1
        optionsContainer.Visible = false
        optionsContainer.Parent = card

        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding = UDim.new(0, 4)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = optionsContainer

        -- Quick actions bar
        local quickBar = Instance.new("Frame")
        quickBar.Name = "00_QuickBar"
        quickBar.LayoutOrder = 0
        quickBar.Size = UDim2.new(1, 0, 0, 26)
        quickBar.BackgroundTransparency = 1
        quickBar.Parent = optionsContainer

        local quickBarLayout = Instance.new("UIListLayout")
        quickBarLayout.FillDirection = Enum.FillDirection.Horizontal
        quickBarLayout.Padding = UDim.new(0, 6)
        quickBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
        quickBarLayout.Parent = quickBar

        local optionButtons = {}

        local function GetSummaryText()
            local total = #options
            local count = 0
            for _, opt in ipairs(options) do
                if selectedMap[opt.value] then
                    count = count + 1
                end
            end
            if count == total then
                return "เลือกทั้งหมด (" .. tostring(total) .. "/" .. tostring(total) .. ")"
            elseif count == 0 then
                return "ไม่ได้เลือก (0/" .. tostring(total) .. ")"
            elseif count <= 3 then
                local names = {}
                for _, opt in ipairs(options) do
                    if selectedMap[opt.value] then
                        table.insert(names, opt.short or tostring(opt.value))
                    end
                end
                return table.concat(names, ", ") .. " (" .. tostring(count) .. "/" .. tostring(total) .. ")"
            else
                return "เลือก " .. tostring(count) .. " รายการ (" .. tostring(count) .. "/" .. tostring(total) .. ")"
            end
        end

        local function RefreshUI()
            selectBtn.Text = GetSummaryText() .. (isExpanded and " ▲" or " ▼")
            for _, item in ipairs(optionButtons) do
                local isChecked = (selectedMap[item.value] == true)
                item.btn.BackgroundColor3 = isChecked and Color3.fromRGB(48, 38, 72) or Config.Colors.Sidebar
                item.btn.TextColor3 = isChecked and Config.Colors.TextPrimary or Config.Colors.TextSecondary
                item.btn.Text = (isChecked and " [✓]  " or " [  ]  ") .. item.label
            end
        end

        local function CreateQuickBtn(text, color, onClick)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.31, 0, 1, 0)
            btn.BackgroundColor3 = color
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 10
            btn.TextColor3 = Config.Colors.TextPrimary
            btn.Text = text
            btn.Parent = quickBar

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 4)
            btnCorner.Parent = btn

            btn.MouseButton1Click:Connect(function()
                onClick()
                RefreshUI()
                if callback then callback(selectedMap) end
                SaveConfiguration()
            end)
            return btn
        end

        CreateQuickBtn("✓ ทั้งหมด", Config.Colors.Accent, function()
            for _, opt in ipairs(options) do
                selectedMap[opt.value] = true
            end
        end)

        CreateQuickBtn("✕ ล้างหมด", Config.Colors.Danger, function()
            for _, opt in ipairs(options) do
                selectedMap[opt.value] = false
            end
        end)

        if #options > 4 and type(options[1].value) == "number" then
            CreateQuickBtn("⚡ ระดับ 5+", Config.Colors.Gold, function()
                for _, opt in ipairs(options) do
                    selectedMap[opt.value] = (type(opt.value) == "number" and opt.value >= 5)
                end
            end)
        else
            CreateQuickBtn("⇄ สลับค่า", Config.Colors.Warning, function()
                for _, opt in ipairs(options) do
                    selectedMap[opt.value] = not (selectedMap[opt.value] == true)
                end
            end)
        end

        for i, opt in ipairs(options) do
            local optBtn = Instance.new("TextButton")
            optBtn.Name = "Opt_" .. string.format("%02d", i)
            optBtn.LayoutOrder = i
            optBtn.Size = UDim2.new(1, 0, 0, 26)
            optBtn.BackgroundColor3 = (selectedMap[opt.value] == true) and Color3.fromRGB(48, 38, 72) or Config.Colors.Sidebar
            optBtn.Font = Enum.Font.GothamMedium
            optBtn.TextSize = 11
            optBtn.TextColor3 = (selectedMap[opt.value] == true) and Config.Colors.TextPrimary or Config.Colors.TextSecondary
            optBtn.TextXAlignment = Enum.TextXAlignment.Left
            optBtn.Text = ((selectedMap[opt.value] == true) and " [✓]  " or " [  ]  ") .. opt.label
            optBtn.Parent = optionsContainer

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 4)
            optCorner.Parent = optBtn

            local optPad = Instance.new("UIPadding")
            optPad.PaddingLeft = UDim.new(0, 8)
            optPad.Parent = optBtn

            optBtn.MouseButton1Click:Connect(function()
                selectedMap[opt.value] = not (selectedMap[opt.value] == true)
                RefreshUI()
                if callback then
                    callback(selectedMap)
                end
                SaveConfiguration()
            end)

            table.insert(optionButtons, { btn = optBtn, value = opt.value, label = opt.label })
        end

        local totalContentHeight = 26 + 4 + (#options * 30) + 12

        local function ToggleExpand(state)
            isExpanded = (state ~= nil) and state or (not isExpanded)
            optionsContainer.Visible = isExpanded
            RefreshUI()
            if isExpanded then
                card.Size = UDim2.new(1, 0, 0, 48 + totalContentHeight)
            else
                card.Size = UDim2.new(1, 0, 0, 42)
            end
        end

        selectBtn.MouseButton1Click:Connect(function()
            ToggleExpand()
        end)

        RefreshUI()
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

    CreateStatusCard(pRebirth, "⚡ ลำดับสำคัญ 1: เกิดใหม่ทันทีเมื่อครบเกณฑ์ เพื่อรับตัวคูณเงินถาวร (Update 10 ขยายเพดานสูงสุด Rebirth 50 และปลดล็อก Trait ทวีคูณ)\n(เมื่อเกิดใหม่แล้ว ระบบจะซื้อและใส่แหที่ดีที่สุดต่อทันที)")

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

    CreateToggle(pNetFarm, "รอจนเต็มความจุ 100% เสมอ (Wait For 100% Full Bar)", Config.Settings.ReelWhenFull, function(v)
        Config.Settings.ReelWhenFull = v
    end)

    local reelModes = {
        "รอจนเต็มหลอด 100% เท่านั้น (Wait Until 100% Full Only - แนะนำ)",
        "เต็มความจุ หรือเมื่อหมดเวลาถอยหลัง (Full or Timeout)",
        "ดึงตามเวลาคงที่ 5 วินาที (Fixed 5s Timer)",
        "ดึงทันทีแบบเร็วต่อเนื่อง (Instant Fast Cycle)"
    }
    CreateDropdown(pNetFarm, "โหมดการดึงแห (Reel Strategy)", reelModes, Config.Settings.ReelStrategy, function(selected)
        Config.Settings.ReelStrategy = selected
        Config.Settings.ReelWhenFull = (selected:find("100%") ~= nil or selected:find("เต็มความจุ") ~= nil or selected:find("Reel When Full") ~= nil)
        UpdateStatus("STATUS: REEL STRATEGY SET TO: " .. selected)
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
    local CurrentStatusCard = CreateStatusCard(pRewards, "🌊 กระแสน้ำลึก: กำลังตรวจสอบสถานะ...")

    -- Live update for CurrentStatusCard
    task.spawn(function()
        while IsSessionValid() do
            if CurrentStatusCard and CurrentStatusCard.Parent then
                local s = CurrentStateCache
                if s then
                    local pts = s.pts or 0
                    if s.active then
                        local cName = s.active.s or "Unknown"
                        local rName = FishingShared and FishingShared.Rarities[s.active.r] and FishingShared.Rarities[s.active.r].Name or tostring(s.active.r)
                        CurrentStatusCard.Text = string.format("🌊 กระแสน้ำลึก | ⚡ ชาร์จ: %d | 🔴 กำลังมา: %s (%s)", pts, cName, rName)
                    else
                        CurrentStatusCard.Text = string.format("🌊 กระแสน้ำลึก | ⚡ ชาร์จ: %d | 🟢 พร้อมเรียกตัวที่ดีที่สุด!", pts)
                    end
                end
            end
            task.wait(2.5)
        end
    end)

    CreateToggle(pRewards, "🌊 เรียกลอยกระแสน้ำลึกอัตโนมัติ (Auto Deep Current Summon)", Config.Settings.AutoCurrent, function(v)
        Config.Settings.AutoCurrent = v
        UpdateStatus("STATUS: AUTO DEEP CURRENT " .. (v and "ENABLED" or "DISABLED"))
        if v then
            task.spawn(RunCurrentCycle)
        end
    end)

    local currentModes = {
        "อัตโนมัติ: ดีที่สุดตามแต้มชาร์จ (Auto: Best Affordable Tier)",
        "อัตโนมัติ: รอแต้มตัวสูงสุดที่ตาข่ายจับได้ (Auto: Save for Highest Net Tier)",
        "เจาะจง: เซนิท Zenith (250 ⚡)",
        "เจาะจง: สูงสุด Supreme (200 ⚡)",
        "เจาะจง: เอมพิเรียน Empyrean (100 ⚡)",
        "เจาะจง: ศักดิ์สิทธิ์ Sacred (75 ⚡)",
        "เจาะจง: จักรวาล Cosmic (40 ⚡)",
        "เจาะจง: ต้องห้าม Forbidden (25 ⚡)",
        "เจาะจง: พระมหากษัตริย์ King (20 ⚡)",
        "เจาะจง: ประวัติศาสตร์ Historical (15 ⚡)",
        "เจาะจง: เดมิก๊อด Demigod (12 ⚡)",
        "เจาะจง: เอเพ็กซ์ Apex (6 ⚡)",
        "เจาะจง: ตำนาน Legendary (3 ⚡)"
    }
    CreateDropdown(pRewards, "เป้าหมายกระแสน้ำลึก (Deep Current Target)", currentModes, Config.Settings.CurrentMode, function(selected)
        Config.Settings.CurrentMode = selected
        UpdateStatus("STATUS: CURRENT MODE SET TO: " .. selected)
        if Config.Settings.AutoCurrent then
            task.spawn(RunCurrentCycle)
        end
    end)

    CreateButton(pRewards, "🌊 เรียกกระแสน้ำลึกตัวที่ดีที่สุดทันที (Call Best Current Now)", Config.Colors.Cyan, function()
        UpdateStatus("STATUS: CALLING BEST DEEP CURRENT CREATURE...")
        task.spawn(function()
            RunCurrentCycle()
        end)
    end)

    CreateToggle(pRewards, "เคลมเควสสัญญาจับปลา (Auto Claim Contracts)", Config.Settings.AutoClaimContracts, function(v)
        Config.Settings.AutoClaimContracts = v
    end)

    CreateToggle(pRewards, "รับของขวัญออนไลน์ & ล็อกอิน (Playtime Gifts & Daily)", Config.Settings.AutoClaimRewards, function(v)
        Config.Settings.AutoClaimRewards = v
    end)

    CreateToggle(pRewards, "🔄 รีเซิร์ฟเวอร์อัตโนมัติเมื่อรับกล่องครบ 1 ชม. (Auto Rejoin 1-Hr Gifts)", Config.Settings.AutoRejoinAfterHourGifts, function(v)
        Config.Settings.AutoRejoinAfterHourGifts = v
        UpdateStatus("STATUS: AUTO REJOIN AFTER 1-HOUR GIFTS " .. (v and "ENABLED" or "DISABLED"))
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

    local MiniGameStatusCard = CreateStatusCard(pRewards, "🎮 มินิเกม (Mini-Games): รอรับคำเชิญเพื่อเล่นอัตโนมัติ...")
    UIReferences.MiniGameStatusCard = MiniGameStatusCard

    CreateToggle(pRewards, "🎮 เล่นมินิเกมทุกอันอัตโนมัติ (Auto Play All Mini-Games 🥇)", Config.Settings.AutoMiniGames, function(v)
        Config.Settings.AutoMiniGames = v
        UpdateStatus("STATUS: AUTO MINI-GAMES " .. (v and "ENABLED" or "DISABLED"))
    end)

    local miniGameOptions = {
        { value = "Reel", short = "เบ็ด 🎣", label = "🎣 Perfect Reel (มินิเกมดึงเบ็ด)" },
        { value = "Jump", short = "กระโดด 🐟", label = "🐟 Fish Frenzy (มินิเกมปลากระโดด)" },
        { value = "Lures", short = "เหยื่อ 🪱", label = "🪱 Bait Memory (มินิเกมเหยื่อล่อ)" }
    }
    CreateMultiSelectDropdown(pRewards, "เลือกมินิเกมที่จะเล่น (Mini-Games Multi-Select)", miniGameOptions, Config.Settings.MiniGameSelectedGames, function(selectedMap)
        local count = 0
        for _, v in pairs(selectedMap) do
            if v then count = count + 1 end
        end
        UpdateStatus(string.format("STATUS: MINI-GAMES SELECTION UPDATED: %d GAMES", count))
        if MiniGameStatusCard then
            MiniGameStatusCard.Text = string.format("เลือกมินิเกมแล้ว: %d/3 เกม (เหรียญทอง 🥇)", count)
        end
    end)

    CreateButton(pRewards, "🎮 ตรวจสอบสถิติมินิเกม & เหรียญทอง (Check Mini-Game Stats)", Config.Colors.Cyan, function()
        UpdateStatus("STATUS: CHECKING MINI-GAME STATS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local getData = remotes and remotes:FindFirstChild(Config.Events.GetData)
            local data = getData and getData:InvokeServer()
            local mg = data and (data.MiniGame or data.MiniGames)
            if mg then
                local plays = mg.plays or 0
                local golds = mg.golds or 0
                local bestText = ""
                if mg.best then
                    local parts = {}
                    for g, s in pairs(mg.best) do table.insert(parts, string.format("%s: %d", tostring(g), tonumber(s) or 0)) end
                    bestText = table.concat(parts, " | ")
                end
                UpdateStatus(string.format("STATUS: MINI-GAMES: %d PLAYS | %d GOLDS 🥇 | BEST: %s", plays, golds, bestText))
                if MiniGameStatusCard then
                    MiniGameStatusCard.Text = string.format("🎮 สถิติ: เล่น %d ครั้ง | ทอง 🥇 %d ครั้ง | สถิติสูงสุด: %s", plays, golds, bestText)
                end
            end
        end)
    end)

    CreateToggle(pRewards, "📜 เคลมของรางวัล Leviathan Pass อัตโนมัติ (Auto Claim Season Pass)", Config.Settings.AutoClaimSeasonPass, function(v)
        Config.Settings.AutoClaimSeasonPass = v
        UpdateStatus("STATUS: AUTO CLAIM SEASON PASS " .. (v and "ENABLED" or "DISABLED"))
    end)

    CreateToggle(pRewards, "🎁 แลกโค้ดโปรโมชั่นใหม่อัตโนมัติ (Auto Redeem Promo Codes)", Config.Settings.AutoRedeemCodes, function(v)
        Config.Settings.AutoRedeemCodes = v
        UpdateStatus("STATUS: AUTO REDEEM CODES " .. (v and "ENABLED" or "DISABLED"))
    end)

    local passBtnRow = Instance.new("Frame")
    passBtnRow.Size = UDim2.new(1, 0, 0, 34)
    passBtnRow.BackgroundTransparency = 1
    passBtnRow.Parent = pRewards

    local btnClaimPass = Instance.new("TextButton")
    btnClaimPass.Size = UDim2.new(0.48, 0, 1, 0)
    btnClaimPass.BackgroundColor3 = Config.Colors.Accent
    btnClaimPass.Font = Enum.Font.GothamBold
    btnClaimPass.TextSize = 11
    btnClaimPass.TextColor3 = Config.Colors.TextPrimary
    btnClaimPass.Text = "📜 เคลม Leviathan Pass (All)"
    btnClaimPass.Parent = passBtnRow
    local bcpCorner = Instance.new("UICorner")
    bcpCorner.CornerRadius = UDim.new(0, 6)
    bcpCorner.Parent = btnClaimPass

    btnClaimPass.MouseButton1Click:Connect(function()
        UpdateStatus("STATUS: CLAIMING ALL UNCLAIMED SEASON PASS TIERS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local spRemote = remotes and remotes:FindFirstChild("SeasonPass")
            if spRemote then
                local spState = spRemote:InvokeServer("state")
                local count = 0
                if spState and spState.tier then
                    local maxTier = spState.tier
                    local freeClaimed = spState.free or {}
                    for t = 1, maxTier do
                        if not freeClaimed[tostring(t)] then
                            local res = spRemote:InvokeServer("claim", { gold = false, tier = t })
                            if res and (res.ok or res.reward or res.claimed or not res.err) then
                                count = count + 1
                                UpdateStatus(string.format("STATUS: CLAIMED PASS TIER %d!", t))
                                task.wait(0.2)
                            end
                        end
                    end
                end
                UpdateStatus(string.format("STATUS: CLAIMED %d PASS TIERS!", count))
                if QuestStatusCard then
                    QuestStatusCard.Text = string.format("เคลม Leviathan Pass สำเร็จ: %d เลเวล!", count)
                end
            end
        end)
    end)

    local btnRedeemCodes = Instance.new("TextButton")
    btnRedeemCodes.Size = UDim2.new(0.48, 0, 1, 0)
    btnRedeemCodes.Position = UDim2.new(0.52, 0, 0, 0)
    btnRedeemCodes.BackgroundColor3 = Config.Colors.Gold
    btnRedeemCodes.Font = Enum.Font.GothamBold
    btnRedeemCodes.TextSize = 11
    btnRedeemCodes.TextColor3 = Config.Colors.TextPrimary
    btnRedeemCodes.Text = "🎁 แลกโค้ดทั้งหมด (Redeem)"
    btnRedeemCodes.Parent = passBtnRow
    local brcCorner = Instance.new("UICorner")
    brcCorner.CornerRadius = UDim.new(0, 6)
    brcCorner.Parent = btnRedeemCodes

    btnRedeemCodes.MouseButton1Click:Connect(function()
        UpdateStatus("STATUS: REDEEMING ALL ACTIVE PROMO CODES...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local rewardsRemote = remotes and remotes:FindFirstChild("Rewards")
            if rewardsRemote then
                local promoCodes = { "2MVISITS", "1MVISITS", "MONARCH", "UPD1" }
                local count = 0
                for _, code in ipairs(promoCodes) do
                    local res = rewardsRemote:InvokeServer("redeem", code)
                    if res and (res.ok or res.claimed) then
                        count = count + 1
                    end
                    task.wait(0.4)
                end
                UpdateStatus(string.format("STATUS: PROMO CODES REDEEMED (%d SUCCEEDED)!", count))
                if QuestStatusCard then
                    QuestStatusCard.Text = string.format("แลกโค้ดของขวัญสำเร็จ: %d โค้ด (บัฟ/หีบ/ยาทำงานแล้ว)", count)
                end
            end
        end)
    end)

    CreateButton(pRewards, "🎁 กดรับรางวัลและเควสทุกหมวดหมู่ทันที (Claim ALL Now)", Config.Colors.Gold, function()
        UpdateStatus("STATUS: RUNNING MEGA CLAIM CYCLE FOR ALL QUESTS & REWARDS...")
        task.spawn(function()
            local count = RunMegaClaimCycle()
            UpdateStatus(string.format("STATUS: CLAIMED %d REWARDS & SPINS SUCCESSFULLY!", count))
            if QuestStatusCard then
                QuestStatusCard.Text = string.format("เคลมรางวัลและหมหมุนวงล้อสำเร็จล่าสุด: %d รายการ!", count)
            end
        end)
    end)

    CreateButton(pRewards, "🔄 รีเซิร์ฟเวอร์แบบปลอดภัย (Safe Server Hop: รอดึงแห & จบบอส)", Config.Colors.Warning, function()
        RejoinOrServerHop()
    end)

    -- ==========================================================================
    -- TAB 8: ขายปลา/ร้านค้า (Market & Sell)
    -- ==========================================================================
    AddTabButton("SellTab", "🏷️ 8. ขายปลา", false, 8)
    local pSell = CreateTabPage("SellTab")

    CreateToggle(pSell, "ขายปลาอัตโนมัติ (Auto Sell Fish)", Config.Settings.AutoSell, function(v)
        Config.Settings.AutoSell = v
        UpdateStatus("STATUS: AUTO SELL " .. (v and "ENABLED" or "DISABLED"))
    end)

    local sellFilterOptions = {
        "ขายปลาทั่วไปทั้งหมด (Sell All Fish)",
        "ขายเฉพาะ Common ถึง Rare (ระดับ 1-3)",
        "ขายเฉพาะ Common ถึง Epic (ระดับ 1-5)",
        "ขายเฉพาะ Common ถึง Legendary (ระดับ 1-6)",
        "ขายเฉพาะ Common ถึง Apex (ระดับ 1-7)",
        "ขายเฉพาะ Common ถึง Demigod (ระดับ 1-8)"
    }
    CreateDropdown(pSell, "ตัวกรองระดับปลาที่จะขาย (Sell Rarity Filter)", sellFilterOptions, Config.Settings.SellRarityMode, function(selected)
        Config.Settings.SellRarityMode = selected
        UpdateStatus("STATUS: SELL RARITY FILTER SET TO: " .. selected)
    end)

    CreateToggle(pSell, "✨ เก็บปลาผ่าเหล่า/กลายพันธุ์ (Keep Mutated Fish)", Config.Settings.KeepMutatedFish, function(v)
        Config.Settings.KeepMutatedFish = v
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("CoolerAction") then
            pcall(function()
                remotes.CoolerAction:InvokeServer("simpleSet", 0, { keepMut = v, shuck = Config.Settings.AutoShuckPearls })
            end)
        end
        UpdateStatus("STATUS: KEEP MUTATED FISH " .. (v and "ENABLED" or "DISABLED"))
    end)

    CreateToggle(pSell, "🦪 ผ่าหอยมุกอัตโนมัติ (Auto Shuck Fish Into Pearls)", Config.Settings.AutoShuckPearls, function(v)
        Config.Settings.AutoShuckPearls = v
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("CoolerAction") then
            pcall(function()
                remotes.CoolerAction:InvokeServer("simpleSet", 0, { keepMut = Config.Settings.KeepMutatedFish, shuck = v })
            end)
        end
        UpdateStatus("STATUS: AUTO SHUCK PEARLS " .. (v and "ENABLED" or "DISABLED"))
    end)

    local sellBtnRow = Instance.new("Frame")
    sellBtnRow.Size = UDim2.new(1, 0, 0, 34)
    sellBtnRow.BackgroundTransparency = 1
    sellBtnRow.Parent = pSell

    local btnSellNow = Instance.new("TextButton")
    btnSellNow.Size = UDim2.new(0.48, 0, 1, 0)
    btnSellNow.BackgroundColor3 = Config.Colors.Card
    btnSellNow.Font = Enum.Font.GothamBold
    btnSellNow.TextSize = 11
    btnSellNow.TextColor3 = Config.Colors.TextPrimary
    btnSellNow.Text = "💰 ขายปลาทันที (Sell Now)"
    btnSellNow.Parent = sellBtnRow
    local bsnCorner = Instance.new("UICorner")
    bsnCorner.CornerRadius = UDim.new(0, 6)
    bsnCorner.Parent = btnSellNow

    btnSellNow.MouseButton1Click:Connect(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(Config.Events.SellFish) then
            remotes[Config.Events.SellFish]:FireServer()
            UpdateStatus("STATUS: MANUAL SELL FISH EXECUTED!")
        end
    end)

    local btnShuckNow = Instance.new("TextButton")
    btnShuckNow.Size = UDim2.new(0.48, 0, 1, 0)
    btnShuckNow.Position = UDim2.new(0.52, 0, 0, 0)
    btnShuckNow.BackgroundColor3 = Config.Colors.Gold
    btnShuckNow.Font = Enum.Font.GothamBold
    btnShuckNow.TextSize = 11
    btnShuckNow.TextColor3 = Config.Colors.TextPrimary
    btnShuckNow.Text = "🦪 ผ่าหอยมุกทันที (Shuck Pearls)"
    btnShuckNow.Parent = sellBtnRow
    local bskCorner = Instance.new("UICorner")
    bskCorner.CornerRadius = UDim.new(0, 6)
    bskCorner.Parent = btnShuckNow

    btnShuckNow.MouseButton1Click:Connect(function()
        UpdateStatus("STATUS: SHUCKING FISH INTO PEARLS...")
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("CoolerAction") then
            local res = remotes.CoolerAction:InvokeServer("shuck")
            local pCount = (res and res.pearls) or 0
            UpdateStatus(string.format("STATUS: SHUCKED PEARLS! +%d PEARLS GAINED", pCount))
        end
    end)

    -- Update 10: The Black Market (ตลาดมืด Silas the Smuggler)
    local BlackMarketStatusCard = CreateStatusCard(pSell, "🛒 ตลาดมืด (Black Market Update 10): กำลังตรวจสินค้า...")
    task.spawn(function()
        while IsSessionValid() do
            if BlackMarketStatusCard and BlackMarketStatusCard.Parent then
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local bmRemote = remotes and remotes:FindFirstChild("BlackMarket")
                if bmRemote then
                    pcall(function()
                        local bmState = bmRemote:InvokeServer("state")
                        if bmState then
                            local left = bmState.nextIn or 0
                            local available = 0
                            local total = 0
                            if bmState.items then
                                total = #bmState.items
                                for _, it in ipairs(bmState.items) do
                                    if not it.bought then available = available + 1 end
                                end
                            end
                            local min = math.floor(left / 60)
                            local sec = left % 60
                            BlackMarketStatusCard.Text = string.format("🛒 ตลาดมืด: สินค้าพร้อมซื้อ %d/%d ชิ้น | รีเฟรชใน %d:%02d นาที", available, total, min, sec)
                        end
                    end)
                end
            end
            task.wait(4.0)
        end
    end)

    CreateToggle(pSell, "🛒 ซื้อของตลาดมืดอัตโนมัติ (Auto Buy Black Market Stock)", Config.Settings.AutoBuyBlackMarket, function(v)
        Config.Settings.AutoBuyBlackMarket = v
        UpdateStatus("STATUS: AUTO BUY BLACK MARKET " .. (v and "ENABLED" or "DISABLED"))
    end)

    CreateButton(pSell, "🛒 ซื้อของตลาดมืดที่มีทั้งหมดทันที (Buy Black Market Now)", Config.Colors.Gold, function()
        UpdateStatus("STATUS: BUYING BLACK MARKET ITEMS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local bmRemote = remotes and remotes:FindFirstChild("BlackMarket")
            if bmRemote then
                local bmState = bmRemote:InvokeServer("state")
                local count = 0
                if bmState and bmState.items and bmState.cash then
                    for _, item in ipairs(bmState.items) do
                        if not item.bought and item.price and bmState.cash >= item.price then
                            local res = bmRemote:InvokeServer("buy", item.id)
                            if res and (res.ok or res.bought) then
                                count = count + 1
                                bmState.cash = bmState.cash - item.price
                                UpdateStatus(string.format("STATUS: BOUGHT [%s] FROM BLACK MARKET!", item.name or item.id))
                                task.wait(0.3)
                            end
                        end
                    end
                end
                UpdateStatus(string.format("STATUS: BOUGHT %d BLACK MARKET ITEMS!", count))
                if BlackMarketStatusCard then
                    BlackMarketStatusCard.Text = string.format("ซื้อของตลาดมืดสำเร็จล่าสุด: %d ชิ้น!", count)
                end
            end
        end)
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

    local upgradeCatOptions = {
        { value = "Net", short = "แห/ตาข่าย 🕸️", label = "🕸️ แห & ตาข่าย (Priority 2: Best Net Tier Up)" },
        { value = "Boat", short = "เรือ ⛵", label = "⛵ เรือ & อุปกรณ์เรือ (Hull, Engine, Sonar, Cold, Trawl)" },
        { value = "Fisherman", short = "คนตกปลา 🎣", label = "🎣 คนตกปลาผู้ช่วย (Rod, Line, Speed, Range, Tackle, Bait)" },
        { value = "Spear", short = "ฉมวก 🔱", label = "🔱 ปืนฉมวกตีบอส (Spear Gun, Power, Reload, Piercing)" },
        { value = "General", short = "ทั่วไป ⚙️", label = "⚙️ อุปกรณ์ทั่วไป (Weave, Titan, Colossus, Fleet, etc.)" },
        { value = "StarPerks", short = "สตาร์เพิร์ก ★", label = "★ สตาร์เพิร์กจุติ (Ascension Star Perks Auto-Invest)" }
    }
    CreateMultiSelectDropdown(pUpgrade, "เลือกหมวดหมู่อัปเกรด (Upgrade Categories)", upgradeCatOptions, Config.Settings.UpgradeSelectedCategories, function(selectedMap)
        local count = 0
        for _, v in pairs(selectedMap) do
            if v then count = count + 1 end
        end
        UpdateStatus(string.format("STATUS: UPGRADE CATEGORIES UPDATED: %d SELECTED", count))
        if UpgradeStatusCard then
            UpgradeStatusCard.Text = string.format("หมวดหมู่อัปเกรดที่เลือก: %d/6 หมวด", count)
        end
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

    CreateToggle(pPotions, "ซื้อยาบัฟตามระดับที่เลือกเมื่อร้านรีเฟรช (Auto Buy Potions)", Config.Settings.AutoBuyPotions, function(v)
        Config.Settings.AutoBuyPotions = v
    end)

    CreateToggle(pPotions, "เปิดระบบดื่มยาบัฟอัตโนมัติ (Auto Drink Potions)", Config.Settings.AutoDrinkPotions, function(v)
        Config.Settings.AutoDrinkPotions = v
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("Potions") then
            remotes.Potions:InvokeServer("auto", v)
        end
    end)

    local potionKindOptions = {
        { value = "Cash", short = "เงิน 💵", label = "💵 ยาเพิ่มเงิน (Cash Boost Potion)" },
        { value = "Net", short = "ตาข่าย 🧪", label = "🧪 ยาเพิ่มขนาดตาข่าย (Net Space Potion)" }
    }
    CreateMultiSelectDropdown(pPotions, "เลือกชนิดยาที่ดื่ม & ซื้อ (Potion Types)", potionKindOptions, Config.Settings.PotionSelectedKinds, function(selectedKinds)
        local count = 0
        local kinds = {}
        if selectedKinds.Cash then count = count + 1 table.insert(kinds, "เงิน 💵") end
        if selectedKinds.Net then count = count + 1 table.insert(kinds, "ตาข่าย 🧪") end
        local txt = count == 2 and "ยาทุกชนิด (Cash + Net 💵🧪)" or (count == 1 and ("เฉพาะ" .. table.concat(kinds, ", ")) or "ไม่ได้เลือกชนิดยา")
        UpdateStatus("STATUS: POTION TYPES UPDATED: " .. txt)
        if PotionsStatusCard then
            PotionsStatusCard.Text = "ชนิดยาที่เลือก: " .. txt
        end
    end)

    local potionTierOptions = {
        { value = 1, short = "I", label = "Tier I (ระดับ 1 - เริ่มต้น)" },
        { value = 2, short = "II", label = "Tier II (ระดับ 2)" },
        { value = 3, short = "III", label = "Tier III (ระดับ 3)" },
        { value = 4, short = "IV", label = "Tier IV (ระดับ 4)" },
        { value = 5, short = "V", label = "Tier V (ระดับ 5 - ปานกลาง)" },
        { value = 6, short = "VI", label = "Tier VI (ระดับ 6)" },
        { value = 7, short = "VII", label = "Tier VII (ระดับ 7)" },
        { value = 8, short = "VIII", label = "Tier VIII (ระดับ 8)" },
        { value = 9, short = "IX", label = "Tier IX (ระดับ 9 - หายาก)" },
        { value = 10, short = "X", label = "Tier X (ระดับ 10 - เทพสุด)" }
    }
    CreateMultiSelectDropdown(pPotions, "เลือกระดับน้ำยา (Potion Tiers Multi-Select)", potionTierOptions, Config.Settings.PotionSelectedTiers, function(selectedMap)
        local count = 0
        for _, v in pairs(selectedMap) do
            if v then count = count + 1 end
        end
        UpdateStatus(string.format("STATUS: POTION TIERS UPDATED: %d TIERS SELECTED", count))
        if PotionsStatusCard then
            PotionsStatusCard.Text = string.format("เลือกระดับน้ำยาแล้ว: %d/10 ระดับ", count)
        end
    end)

    CreateButton(pPotions, "⚡ ดื่มยาตามชนิดและระดับที่เลือกทันที (Drink Selected Potions Now)", Config.Colors.Success, function()
        UpdateStatus("STATUS: CONSUMING SELECTED STORED POTIONS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("Potions") then
                local selectedKinds = Config.Settings.PotionSelectedKinds or { Cash = true, Net = true }
                local selectedTiers = Config.Settings.PotionSelectedTiers or {}
                local allTiersSelected = true
                for t = 1, 10 do
                    if not selectedTiers[t] then
                        allTiersSelected = false
                        break
                    end
                end
                local allKindsSelected = (selectedKinds.Cash == true and selectedKinds.Net == true)

                if allTiersSelected and allKindsSelected then
                    local res = remotes.Potions:InvokeServer("useAll")
                    local count = (res and res.drank) or 0
                    UpdateStatus(string.format("STATUS: SUCCESSFULLY DRANK %d POTIONS!", count))
                    if PotionsStatusCard then
                        PotionsStatusCard.Text = string.format("ดื่มยาทุกชนิดและทุกระดับสำเร็จทันที: %d ขวด! (บัฟทำงานแล้ว)", count)
                    end
                else
                    local pState = remotes.Potions:InvokeServer("state")
                    local inv = pState and pState.inv
                    if not inv then
                        local getData = remotes:FindFirstChild(Config.Events.GetData)
                        local data = getData and getData:InvokeServer()
                        inv = data and data.PotionInv
                    end
                    local count = 0
                    if inv then
                        for key, amt in pairs(inv) do
                            local c = tonumber(amt) or 0
                            if c > 0 then
                                local kind, tierStr = key:match("^(%a+)_(%d+)$")
                                local tier = tonumber(tierStr) or 0
                                if (selectedKinds[kind] == true) and (selectedTiers[tier] == true) then
                                    for _ = 1, c do
                                        local res = remotes.Potions:InvokeServer("use", key)
                                        if res and res.ok then
                                            count = count + 1
                                        end
                                        task.wait(0.05)
                                    end
                                end
                            end
                        end
                    end
                    UpdateStatus(string.format("STATUS: DRANK %d SELECTED POTIONS!", count))
                    if PotionsStatusCard then
                        PotionsStatusCard.Text = string.format("ดื่มยาตามที่เลือกสำเร็จทันที: %d ขวด!", count)
                    end
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

    CreateButton(pPotions, "🧪 ซื้อยาตามชนิดและระดับที่เลือกในร้านทันที (Buy Selected Stock Potions)", Config.Colors.Cyan, function()
        UpdateStatus("STATUS: BUYING SELECTED STOCKED POTIONS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes and remotes:FindFirstChild("Potions") then
                local state = remotes.Potions:InvokeServer("state")
                local count = 0
                local selectedKinds = Config.Settings.PotionSelectedKinds or { Cash = true, Net = true }
                local selectedTiers = Config.Settings.PotionSelectedTiers or {}
                if state and state.stock and state.cash then
                    for i, p in ipairs(state.stock) do
                        local kindAllowed = (p.kind == nil or selectedKinds[p.kind] == true)
                        local tierAllowed = (p.tier == nil or selectedTiers[p.tier] == true)
                        if not p.bought and p.price and state.cash >= p.price and kindAllowed and tierAllowed then
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
                    PotionsStatusCard.Text = string.format("ซื้อยาตามชนิดและระดับที่เลือกสำเร็จล่าสุด: %d ขวด!", count)
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

    -- Update 10: Traits System (คุณสมบัติพิเศษ)
    local TraitsStatusCard = CreateStatusCard(pPotions, "✨ คุณสมบัติพิเศษ (Traits Update 10): กำลังโหลดข้อมูล...")
    task.spawn(function()
        while IsSessionValid() do
            if TraitsStatusCard and TraitsStatusCard.Parent then
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local trRemote = remotes and remotes:FindFirstChild("Traits")
                if trRemote then
                    pcall(function()
                        local trState = trRemote:InvokeServer("state")
                        if trState then
                            local rolls = trState.rolls or 0
                            local curTrait = trState.trait or 0
                            local bestTrait = trState.best or 0
                            local TraitsModule = nil
                            pcall(function() TraitsModule = require(ReplicatedStorage:FindFirstChild("Traits")) end)
                            local mult = (TraitsModule and TraitsModule.Mult and TraitsModule.Mult(curTrait)) or 1
                            TraitsStatusCard.Text = string.format("✨ Trait ปัจจุบัน: Tier %d (x%.2f) | ดีที่สุด: Tier %d | สิทธิ์สุ่ม: %d ครั้ง", curTrait, mult, bestTrait, rolls)
                        end
                    end)
                end
            end
            task.wait(3.5)
        end
    end)

    CreateToggle(pPotions, "⭐ สวมใส่ Trait ระดับสูงสุดเสมอ (Auto Equip Best Trait)", Config.Settings.AutoEquipBestTrait, function(v)
        Config.Settings.AutoEquipBestTrait = v
        UpdateStatus("STATUS: AUTO EQUIP BEST TRAIT " .. (v and "ENABLED" or "DISABLED"))
    end)

    CreateToggle(pPotions, "🎲 สุ่มหมุน Trait อัตโนมัติเมื่อมีสิทธิ์ (Auto Roll Traits)", Config.Settings.AutoRollTraits, function(v)
        Config.Settings.AutoRollTraits = v
        UpdateStatus("STATUS: AUTO ROLL TRAITS " .. (v and "ENABLED" or "DISABLED"))
    end)

    local traitBtnRow = Instance.new("Frame")
    traitBtnRow.Size = UDim2.new(1, 0, 0, 34)
    traitBtnRow.BackgroundTransparency = 1
    traitBtnRow.Parent = pPotions

    local btnRollTrait = Instance.new("TextButton")
    btnRollTrait.Size = UDim2.new(0.48, 0, 1, 0)
    btnRollTrait.BackgroundColor3 = Config.Colors.Accent
    btnRollTrait.Font = Enum.Font.GothamBold
    btnRollTrait.TextSize = 11
    btnRollTrait.TextColor3 = Config.Colors.TextPrimary
    btnRollTrait.Text = "🎲 สุ่ม Trait ทันที (Roll)"
    btnRollTrait.Parent = traitBtnRow
    local brtCorner = Instance.new("UICorner")
    brtCorner.CornerRadius = UDim.new(0, 6)
    brtCorner.Parent = btnRollTrait

    btnRollTrait.MouseButton1Click:Connect(function()
        UpdateStatus("STATUS: ROLLING TRAITS...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local trRemote = remotes and remotes:FindFirstChild("Traits")
            if trRemote then
                local trState = trRemote:InvokeServer("state")
                if trState and (trState.rolls or 0) > 0 then
                    local rollAmt = (trState.rolls >= 10) and 10 or 1
                    local res = trRemote:InvokeServer("roll", rollAmt)
                    if res and res.ok then
                        UpdateStatus(string.format("STATUS: ROLLED %d TRAITS! NEW BEST: TIER %d", rollAmt, res.state and res.state.best or 0))
                        if Config.Settings.AutoEquipBestTrait and res.state and res.state.best then
                            trRemote:InvokeServer("equip", res.state.best)
                        end
                    end
                else
                    UpdateStatus("STATUS: NO TRAIT ROLLS AVAILABLE (NEED REBIRTH 7+ OR ROLLS)")
                end
            end
        end)
    end)

    local btnEquipTrait = Instance.new("TextButton")
    btnEquipTrait.Size = UDim2.new(0.48, 0, 1, 0)
    btnEquipTrait.Position = UDim2.new(0.52, 0, 0, 0)
    btnEquipTrait.BackgroundColor3 = Config.Colors.Gold
    btnEquipTrait.Font = Enum.Font.GothamBold
    btnEquipTrait.TextSize = 11
    btnEquipTrait.TextColor3 = Config.Colors.TextPrimary
    btnEquipTrait.Text = "⭐ ใส่ Trait สูงสุด (Equip)"
    btnEquipTrait.Parent = traitBtnRow
    local betCorner = Instance.new("UICorner")
    betCorner.CornerRadius = UDim.new(0, 6)
    betCorner.Parent = btnEquipTrait

    btnEquipTrait.MouseButton1Click:Connect(function()
        UpdateStatus("STATUS: EQUIPPING BEST TRAIT...")
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local trRemote = remotes and remotes:FindFirstChild("Traits")
            if trRemote then
                local trState = trRemote:InvokeServer("state")
                if trState and trState.best then
                    local res = trRemote:InvokeServer("equip", trState.best)
                    if res and res.ok then
                        UpdateStatus(string.format("STATUS: EQUIPPED BEST TRAIT TIER %d!", trState.best))
                    end
                end
            end
        end)
    end)

    -- ==========================================================================
    -- TAB 5: ระบบล่าบอส (Boss Fights: Megalodon, The Bloop & Kraken - Update 10)
    -- ==========================================================================
    AddTabButton("BossTab", "🦈 5. ล่าบอส", false, 5)
    local pBoss = CreateTabPage("BossTab")

    local BossStatusCard = CreateStatusCard(pBoss, "ระบบบอส: กำลังสแกนสถานะ Megalodon, The Bloop & Kraken...")

    -- Live status update for BossStatusCard
    task.spawn(function()
        while IsSessionValid() do
            if BossStatusCard and BossStatusCard.Parent then
                local isMeg = workspace:GetAttribute("MegActive") == true
                local isBloop = workspace:GetAttribute("BloopActive") == true
                local isKraken = workspace:GetAttribute("BossActive") == true
                local megText = isMeg and "🔴 MEG ACTIVE!" or "Meg: รอเวลา"
                local bloopText = isBloop and "🌊 BLOOP ACTIVE!" or "Bloop: รอเวลา"
                local krakenText = isKraken and "🔴 KRAKEN ACTIVE!" or "Kraken: รอเวลา"
                BossStatusCard.Text = string.format("สถานะบอส | %s | %s | %s", megText, bloopText, krakenText)
            end
            task.wait(2.5)
        end
    end)

    CreateToggle(pBoss, "🦈 ตีบอสอัตโนมัติ (Auto Fight Megalodon, The Bloop & Kraken)", Config.Settings.AutoBossFight, function(v)
        Config.Settings.AutoBossFight = v
        UpdateStatus("STATUS: AUTO BOSS FIGHT " .. (v and "ENABLED" or "DISABLED"))
    end)

    local bossModes = {
        "สู้บอสทุกตัว (Megalodon, Bloop, Kraken 🦈🌊🐙)",
        "เฉพาะฉลามยักษ์ Megalodon 🦈",
        "เฉพาะสัตว์ประหลาด The Bloop 🌊",
        "เฉพาะปลาหมึกยักษ์ Kraken 🐙",
        "ปิดการล่าบอส (Disabled)"
    }
    CreateDropdown(pBoss, "เลือกเป้าหมายบอส (Boss Target Filter)", bossModes, Config.Settings.BossTargetMode, function(selected)
        Config.Settings.BossTargetMode = selected
        UpdateStatus("STATUS: BOSS TARGET SET TO: " .. selected)
    end)

    CreateToggle(pBoss, "🎁 เคลมการ์ดของรางวัลบอสอัตโนมัติ (Auto Claim Boss Loot)", Config.Settings.AutoClaimBossLoot, function(v)
        Config.Settings.AutoClaimBossLoot = v
        UpdateStatus("STATUS: AUTO CLAIM BOSS LOOT " .. (v and "ENABLED" or "DISABLED"))
    end)

    CreateButton(pBoss, "🦈 เข้าสู่โหมดป้อมปืนตี Megalodon ทันที (Enter Meg Turret)", Config.Colors.Accent, function()
        UpdateStatus("STATUS: ENTERING MEGALODON TURRET MODE...")
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("MegEvent") then
            remotes.MegEvent:FireServer("enter")
        end
    end)

    CreateButton(pBoss, "🎯 เล็งยิงฉมวกใส่ Megalodon ทันที (Fire Meg Turret Spear)", Config.Colors.Cyan, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            pcall(function()
                local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                local turretUI = pGui and pGui:FindFirstChild("MegTurretUI")
                if not (turretUI and turretUI.Enabled) and remotes:FindFirstChild("MegEvent") then
                    remotes.MegEvent:FireServer("enter")
                    task.wait(0.3)
                end
            end)

            FireTurretSpearAtMegalodon(remotes)
            UpdateStatus("STATUS: MANUAL SPEAR SHOT TRIGGERED AT MEGALODON!")
        end
    end)

    CreateButton(pBoss, "🎁 รับของรางวัลบอส Megalodon ทันที (Claim Megalodon Loot)", Config.Colors.Gold, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("MegEvent") then
            remotes.MegEvent:FireServer("closed")
            UpdateStatus("STATUS: CLAIMED MEGALODON REWARDS!")
        end
    end)

    CreateButton(pBoss, "🌊 เข้าสู่โหมดป้อมปืนตี The Bloop ทันที (Enter Bloop Turret)", Config.Colors.Accent, function()
        UpdateStatus("STATUS: ENTERING THE BLOOP TURRET MODE...")
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("BloopEvent") then
            remotes.BloopEvent:FireServer("enter")
        end
    end)

    CreateButton(pBoss, "🎯 เล็งยิงฉมวกใส่ The Bloop ทันที (Fire Bloop Turret Spear)", Config.Colors.Cyan, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            pcall(function()
                local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                local turretUI = pGui and pGui:FindFirstChild("BloopTurretUI")
                if not (turretUI and turretUI.Enabled) and remotes:FindFirstChild("BloopEvent") then
                    remotes.BloopEvent:FireServer("enter")
                    task.wait(0.3)
                end
            end)

            FireTurretSpearAtBloop(remotes)
            UpdateStatus("STATUS: MANUAL SPEAR SHOT TRIGGERED AT THE BLOOP!")
        end
    end)

    CreateButton(pBoss, "🎁 รับของรางวัลบอส The Bloop ทันที (Claim Bloop Loot)", Config.Colors.Gold, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("BloopEvent") then
            remotes.BloopEvent:FireServer("closed")
            UpdateStatus("STATUS: CLAIMED THE BLOOP REWARDS!")
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

    -- Persistent Configuration Buttons
    CreateStatusCard(pSettings, "📁 ระบบบันทึกการตั้งค่า (Persistent Configuration File)")

    CreateButton(pSettings, "💾 บันทึกการตั้งค่าลงเครื่องทันที (Save Settings Now)", Config.Colors.Success, function()
        SaveConfiguration()
        UpdateStatus("STATUS: บันทึกการตั้งค่าลงไฟล์เรียบร้อย!")
    end)

    CreateButton(pSettings, "📂 โหลดการตั้งค่าจากไฟล์ (Reload Settings from File)", Config.Colors.Accent, function()
        LoadConfiguration()
        UpdateStatus("STATUS: โหลดการตั้งค่าจากไฟล์เรียบร้อย!")
    end)

    CreateButton(pSettings, "🔄 คืนค่าเริ่มต้นทั้งหมด (Reset Settings to Default)", Config.Colors.Warning, function()
        ResetConfiguration()
        UpdateStatus("STATUS: คืนค่าการตั้งค่าเริ่มต้นเรียบร้อย!")
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
