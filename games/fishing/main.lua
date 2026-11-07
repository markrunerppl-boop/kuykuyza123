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

local LocalPlayer = Players.LocalPlayer
local SharedEnv = (getgenv and getgenv()) or _G

-- Kill previous session cleanly
local CurrentSessionId = HttpService:GenerateGUID(false)
SharedEnv._ScriptWorkerActive = true
SharedEnv._CurrentHubSessionId = CurrentSessionId

local function IsSessionValid()
    return SharedEnv._ScriptWorkerActive == true and SharedEnv._CurrentHubSessionId == CurrentSessionId
end

-- Anti-AFK Engine
local function InitializeAntiAFK()
    LocalPlayer.Idled:Connect(function()
        if not IsSessionValid() then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
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

        -- Auto Claim
        AutoClaimRewards = true,
        AutoClaimClam = true,

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
        UpgradeGeneral = true       -- อัปเกรดทั่วไป/เบส (Weave, Titan, Colossus, Fleet, etc.)
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

-- Task 4: Auto Rebirth Worker (เกิดใหม่อัตโนมัติ)
SpawnWorker("AutoRebirthWorker", function()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local getDataRemote = remotes and remotes:FindFirstChild(Config.Events.GetData)
    local rebirthRemote = remotes and remotes:FindFirstChild(Config.Events.RebirthRequest)

    if getDataRemote and rebirthRemote and FishingShared then
        local data = nil
        pcall(function() data = getDataRemote:InvokeServer() end)

        if data then
            local nextRebirth = (data.Rebirths or 0) + 1
            local need = FishingShared.RebirthNeed and FishingShared.RebirthNeed(data, nextRebirth)
            local canRebirth = false
            pcall(function() canRebirth = FishingShared.CanRebirth(data) end)

            if UIReferences.RebirthProgressLabel and need then
                if canRebirth then
                    UIReferences.RebirthProgressLabel.Text = string.format("REBIRTH %d: READY TO REBIRTH!", nextRebirth)
                    UIReferences.RebirthProgressLabel.TextColor3 = Config.Colors.Success
                else
                    UIReferences.RebirthProgressLabel.Text = string.format("Rebirth %d Need: %s Cash, %d Fish", nextRebirth, FishingShared.Money(need.Cash), need.Caught)
                    UIReferences.RebirthProgressLabel.TextColor3 = Config.Colors.Gold
                end
            end

            if Config.Settings.AutoRebirth and canRebirth then
                rebirthRemote:FireServer()
                UpdateStatus(string.format("STATUS: REBIRTH %d EXECUTED!", nextRebirth))
                task.wait(4.0)
            end
        end
    end

    task.wait(5.0)
end)

-- Task 5: Auto Claim Rewards & Free Pearls (รับของขวัญและหอยมุกฟรีอัตโนมัติ)
SpawnWorker("AutoClaimWorker", function()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")

    -- 1. Free Pearl Clam
    if Config.Settings.AutoClaimClam and LocalPlayer:GetAttribute("PearlFreeClam") == true then
        local pearlRemote = remotes and remotes:FindFirstChild(Config.Events.PearlShop)
        if pearlRemote then
            pcall(function()
                local res = pearlRemote:InvokeServer("freeClam")
                if res and res.ok then
                    UpdateStatus("STATUS: CLAIMED FREE PEARL CLAM!")
                end
            end)
        end
    end

    -- 2. Playtime Gifts & Daily Rewards
    if Config.Settings.AutoClaimRewards then
        local rewardsRemote = remotes and remotes:FindFirstChild(Config.Events.Rewards)
        if rewardsRemote then
            pcall(function()
                local state = rewardsRemote:InvokeServer("state")
                if state and state.gifts then
                    for i, gift in ipairs(state.gifts) do
                        if gift.ready and not gift.claimed then
                            rewardsRemote:InvokeServer("claimGift", i)
                            UpdateStatus(string.format("STATUS: CLAIMED GIFT #%d (%s)!", i, gift.text or "Reward"))
                            task.wait(0.5)
                        end
                    end
                end
                if state and state.daily and state.daily.claimable then
                    rewardsRemote:InvokeServer("claimDaily")
                    UpdateStatus("STATUS: CLAIMED DAILY REWARD!")
                end
            end)
        end
    end

    task.wait(15.0 + math.random(1, 5))
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

    -- 1. Upgrade Net (ตาข่าย)
    if Config.Settings.UpgradeNet and remotes:FindFirstChild("BuyItem") then
        local nextTier = (data.NetTier or 1) + 1
        local netCfg = FishingShared.Nets and FishingShared.Nets[nextTier]
        if netCfg and (netCfg.Cost or (1/0)) <= currentCash then
            local rOk = (FishingShared.NetRebirthOk == nil) or FishingShared.NetRebirthOk(data, nextTier)
            if rOk then
                pcall(function()
                    remotes.BuyItem:FireServer("Net", nextTier, true)
                end)
                currentCash = currentCash - netCfg.Cost
                upgradedCount = upgradedCount + 1
                UpdateStatus(string.format("STATUS: UPGRADED NET TIER %d (%s)!", nextTier, netCfg.Name or ""))
                task.wait(0.2)
            end
        end
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

    local function AddTabButton(tabId, tabName, isDefault)
        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. tabId
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = isDefault and Config.Colors.Accent or Config.Colors.Card
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        btn.TextColor3 = isDefault and Config.Colors.TextPrimary or Config.Colors.TextSecondary
        btn.Text = tabName
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

    -- ==========================================================================
    -- TAB 1: ระบบโยนแห & ฟาร์มหลัก (Net & Main Farm)
    -- ==========================================================================
    AddTabButton("NetFarm", "โยนแห & ฟาร์ม", true)
    local pNetFarm = CreateTabPage("NetFarm")
    pNetFarm.Visible = true

    UIReferences.NetStateLabel = CreateStatusCard(pNetFarm, "Net: Scanning...")

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
    -- TAB 2: แท่นวาง & เงินในฐาน (Base & Cash Pads)
    -- ==========================================================================
    AddTabButton("BasePads", "แท่นวาง & เงิน", false)
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
    -- TAB 3: รางวัล & ไข่มุก (Rewards & Pearls)
    -- ==========================================================================
    AddTabButton("RewardsTab", "รางวัล & มุก", false)
    local pRewards = CreateTabPage("RewardsTab")

    CreateToggle(pRewards, "รับของขวัญออนไลน์อัตโนมัติ (Auto Claim Gifts)", Config.Settings.AutoClaimRewards, function(v)
        Config.Settings.AutoClaimRewards = v
    end)

    CreateToggle(pRewards, "รับหอยมุกฟรีอัตโนมัติ (Auto Free Pearl Clam)", Config.Settings.AutoClaimClam, function(v)
        Config.Settings.AutoClaimClam = v
    end)

    CreateButton(pRewards, "🎁 กดรับรางวัลและหอยมุกทั้งหมดทันที", Config.Colors.Cyan, function()
        task.spawn(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local claimedCount = 0

            -- Free Clam
            local pearlRemote = remotes and remotes:FindFirstChild(Config.Events.PearlShop)
            if pearlRemote then
                pcall(function()
                    local res = pearlRemote:InvokeServer("freeClam")
                    if res and res.ok then claimedCount = claimedCount + 1 end
                end)
            end

            -- Gifts
            local rewardsRemote = remotes and remotes:FindFirstChild(Config.Events.Rewards)
            if rewardsRemote then
                pcall(function()
                    local state = rewardsRemote:InvokeServer("state")
                    if state and state.gifts then
                        for i, g in ipairs(state.gifts) do
                            if g.ready and not g.claimed then
                                rewardsRemote:InvokeServer("claimGift", i)
                                claimedCount = claimedCount + 1
                                task.wait(0.3)
                            end
                        end
                    end
                    if state and state.daily and state.daily.claimable then
                        rewardsRemote:InvokeServer("claimDaily")
                        claimedCount = claimedCount + 1
                    end
                end)
            end

            UpdateStatus("STATUS: CLAIMED ALL AVAILABLE GIFTS & PEARLS!")
        end)
    end)

    -- ==========================================================================
    -- TAB 4: เกิดใหม่ & วิวัฒนาการ (Rebirth)
    -- ==========================================================================
    AddTabButton("RebirthTab", "เกิดใหม่", false)
    local pRebirth = CreateTabPage("RebirthTab")

    UIReferences.RebirthProgressLabel = CreateStatusCard(pRebirth, "Rebirth Requirement: Calculating...")

    CreateToggle(pRebirth, "เกิดใหม่อัตโนมัติเมื่อครบเกณฑ์ (Auto Rebirth)", Config.Settings.AutoRebirth, function(v)
        Config.Settings.AutoRebirth = v
    end)

    CreateButton(pRebirth, "🔄 กดเกิดใหม่ทันที (Rebirth Now)", Config.Colors.Gold, function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild(Config.Events.RebirthRequest) then
            remotes[Config.Events.RebirthRequest]:FireServer()
            UpdateStatus("STATUS: REBIRTH REQUEST SENT!")
        end
    end)

    -- ==========================================================================
    -- TAB 5: ขายปลา/ร้านค้า (Market & Sell)
    -- ==========================================================================
    AddTabButton("SellTab", "ขายปลา", false)
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
    -- TAB 6: ระบบอัปเกรดอัตโนมัติ (Auto Upgrades)
    -- ==========================================================================
    AddTabButton("UpgradeTab", "⚡ อัปเกรด", false)
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
    -- TAB 7: ตั้งค่าระบบ (Settings & System)
    -- ==========================================================================
    AddTabButton("SettingsTab", "ตั้งค่าระบบ", false)
    local pSettings = CreateTabPage("SettingsTab")

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
