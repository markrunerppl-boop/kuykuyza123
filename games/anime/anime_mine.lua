--[[
    ⛏️ เหมืองอนิเมะของฉัน - Auto Farm Suite V15 (All-in-One Trade & Auto Farm Edition)
    ========================================================================
    🔥 อัปเดตใหม่ล่าสุด V15:
    ✅ 1. รวมระบบแลกเปลี่ยนไอเทม & อัญมณี (Trade & Selective Transfer Suite V7.1 Pro) เข้ากับ AutoFarm 100%:
          - เพิ่มหมวดที่ 7: 🤝 ระบบแลกเปลี่ยน & โอนไอเทม (Trade Suite) ในหน้าต่างหลัก
          - มีปุ่ม [🤝 เปิด Trade UI] สำหรับเปิด/ปิดหน้าต่างควบคุมการเทรดแบบละเอียด
    ✅ 2. ระบบความปลอดภัย Auto-Pause ขณะเทรด (Prevent Trade Interruption):
          - เมื่อมีเซสชันการเทรดเปิดอยู่ หรือกำลังส่งของ ระบบ AutoFarm จะหยุดทำงานชั่วคราวอัตโนมัติ
          - ป้องกันการวาร์ปขุดหิน, การขายของ หรือการเปลี่ยนขวานคนขุดไปรบกวนกระบวนการเทรด
          - เมื่อการเทรดเสร็จสิ้น ระบบ AutoFarm จะกลับมาขุดและทำงานต่อทันที 100%
    ✅ 3. ฟังก์ชันเทรดไอเทมและอัญมณีแบบครบวงจร:
          - สแกนคลังไอเทมทุกหมวดหมู่ (คนขุด, ขวาน, 💎 อัญมณี, น้ำยา, หินเอนแชนต์ ฯลฯ)
          - เลือกระบุจำนวนหรือกด Max (จำกัดเพดานความปลอดภัย 999 ชิ้น/ช่อง, อัญมณีสูงสุด 1,000,000 Gems)
          - ระบบ Rate Limiting & Two-Phase Synchronized Confirmation Engine ยืนยันสำเร็จแน่นอน
          - Real-time Watchdog Engine สำหรับฝั่งรับ กดยินยอมทันทีที่ฝั่งส่งพร้อม
    ✅ 4. ซิงค์สคริปต์ไปยัง GitHub Repo อัตโนมัติ:
          loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/script.lua"))()
    ========================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.2)
    LocalPlayer = Players.LocalPlayer
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)

-- ═══════════════════════════════════════════════
-- 🛡️ 1. SAFE MODULE LOADING (SafeRequire with pcall)
-- ═══════════════════════════════════════════════
local function SafeRequire(parent, moduleName)
    local ok, result = pcall(function()
        if not parent then
            error("Parent container is nil")
        end
        local target = parent:WaitForChild(moduleName, 5)
        if not target then
            error(string.format("Module '%s' not found under %s", moduleName, parent:GetFullName()))
        end
        return require(target)
    end)
    if not ok then
        warn(string.format("⚠️ [SafeRequire Warning] โหลดโมดูล '%s' ไม่สำเร็จ: %s", tostring(moduleName), tostring(result)))
        return nil
    end
    return result
end

local modulesFolder = ReplicatedStorage:WaitForChild("Modules", 15)
if not modulesFolder then
    warn("⚠️ [SafeRequire Warning] ไม่พบโฟลเดอร์ 'Modules' ใน ReplicatedStorage!")
end

local GameState = SafeRequire(modulesFolder, "GameState")
local MineConfig = SafeRequire(modulesFolder, "MineConfig")
local MineInventory = SafeRequire(modulesFolder, "MineInventory")
local MineStock = SafeRequire(modulesFolder, "MineStock")
local Items = SafeRequire(modulesFolder, "Items")
local MineEnchantCatalog = SafeRequire(modulesFolder, "MineEnchantCatalog")
local MineSummonCatalog = SafeRequire(modulesFolder, "MineSummonCatalog")
local MineIndexRewardsConfig = SafeRequire(modulesFolder, "MineIndexRewardsConfig")
local MineEventsConfig = SafeRequire(modulesFolder, "MineEventsConfig")
local MineTrialConfig = SafeRequire(modulesFolder, "MineTrialConfig")
local MineCrateConfig = SafeRequire(modulesFolder, "MineCrateConfig")

-- 🔧 ซ่อมแซมและเชื่อมโยงแคชโมดูล Items เข้ากับ MineConfig เพื่อแก้ปัญหา TradeStack คืนค่า nil
if Items and MineConfig and type(MineConfig) == "table" and not MineConfig.TradeItems then
    pcall(function()
        MineConfig.TradeItems = Items
    end)
end

-- ═══════════════════════════════════════════════
-- 🛡️ SAFE STATE ACCESSORS & SAFE EVENT DISPATCHER
-- ═══════════════════════════════════════════════
local function SafeGetData()
    if GameState and GameState.GetData then
        local ok, data = pcall(function() return GameState:GetData() end)
        if ok and data then return data end
    end
    return {}
end

local function SafeGetData2()
    if GameState and GameState.GetData2 then
        local ok, data = pcall(function() return GameState.GetData2() end)
        if ok and data then return data end
    end
    return {}
end

local function SafeSendEvent(eventName, ...)
    if not eventName then
        warn("⚠️ [SafeSendEvent Warning] eventName เป็นค่า nil ข้ามการส่ง Event")
        return false
    end
    if not (GameState and GameState.SendEvent) then
        warn(string.format("⚠️ [SafeSendEvent Warning] GameState.SendEvent ไม่พร้อมใช้งานสำหรับ Event '%s'", tostring(eventName)))
        return false
    end
    local ok, err = pcall(GameState.SendEvent, eventName, ...)
    if not ok then
        warn(string.format("⚠️ [SafeSendEvent Error] เกิดข้อผิดพลาดขณะส่ง Event '%s': %s", tostring(eventName), tostring(err)))
        return false
    end
    return true
end

-- ═══════════════════════════════════════════════
-- 🛡️ RATE LIMITER & HUMAN DELAY & HELPERS
-- ═══════════════════════════════════════════════
local function HumanWait(minSec, maxSec)
    minSec = minSec or 0.08
    maxSec = maxSec or 0.16
    task.wait(minSec + math.random() * (maxSec - minSec))
end

local function FormatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e27 then
        return string.format("%.2fOc", n / 1e27)
    elseif n >= 1e24 then
        return string.format("%.2fSp", n / 1e24)
    elseif n >= 1e21 then
        return string.format("%.2fSx", n / 1e21)
    elseif n >= 1e18 then
        return string.format("%.2fQi", n / 1e18)
    elseif n >= 1e15 then
        return string.format("%.2fQa", n / 1e15)
    elseif n >= 1e12 then
        return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.2fK", n / 1e3)
    else
        return tostring(math.floor(n))
    end
end

-- คำนวณค่าพลังโจมตีพื้นฐานเลเวล 1 ของตัวละคร
local function GetCharBaseDamage(charName)
    if not (Items and Items.GetItemData) then return 0 end
    local okItem, item = pcall(Items.GetItemData, charName)
    if not okItem or not item then return 0 end
    if MineConfig and MineConfig.GetCharacterDamage then
        local ok, dmg = pcall(MineConfig.GetCharacterDamage, item, 1, "Normal")
        if ok and dmg then return dmg end
    end
    if item.MineTier and MineConfig and MineConfig.TierDamage and MineConfig.TierDamage[item.MineTier] then
        return MineConfig.TierDamage[item.MineTier]
    end
    return 0
end

-- คัดเลือกคีย์ตัวละครเฉพาะในโซนเก่า (ไม่รวมโซนปัจจุบัน และไม่รวมตัวที่สวมใส่)
local function GetOldZoneCharacterKeys(mg)
    if not (MineInventory and MineInventory.Collect) then return {} end
    local okCollect, allItems = pcall(MineInventory.Collect, mg)
    if not okCollect or not allItems then return {} end
    local curZone = mg and mg.CurrentZone or 1
    local equippedNames = {}
    for _, h in pairs(mg and mg.Holders or {}) do
        if h and h.CharName then
            equippedNames[h.CharName] = true
        end
    end

    local keys = {}
    for _, it in ipairs(allItems or {}) do
        if it.Kind == "Character" then
            local zone = it.Zone or (MineInventory.DropZoneOf and MineInventory.DropZoneOf(it))
            local name = it.Name or (it.Item and it.Item.ItemName) or it.Key
            -- เฉพาะตัวละครจากโซนเก่า และต้องไม่สวมใส่อยู่บนแท่น
            if zone and zone < curZone and not equippedNames[name] then
                if MineConfig and MineConfig.CanSellCharacter and MineConfig.CanSellCharacter(it.Item or it) then
                    table.insert(keys, it.Key)
                end
            end
        end
    end
    return keys
end

-- ═══════════════════════════════════════════════
-- 🎯 2. CONFIG STATE & CENTRALIZED STRING CONSTANTS
-- ═══════════════════════════════════════════════
local CONFIG_FILE = "AnimeMine_Config.json"

local Config = {
    -- 📡 CENTRALIZED STRING CONSTANTS: รวบรวม Event ทั้งหมดไว้ใน Table ที่เดียว
    Events = {
        TakeChest = "MineTakeChest",
        SellItems = "MineSellItems",
        SkillTreeSection = "MineSkillTreeSection",
        BuySkill = "MineBuySkill",
        BuyPickaxe = "MineBuyPickaxe",
        EquipPickaxe = "MineEquipPickaxe",
        UpgradeCharacter = "MineUpgradeCharacter",
        RollMutation = "MineRollMutation",
        RollEnchant = "MineRollEnchant",
        Summon = "MineSummon",
        SelectZone = "MineSelectZone",
        EquipBest = "MineEquipBest",

        -- Infinity Trial & Colossus Crate Events
        TrialStart = (MineTrialConfig and MineTrialConfig.Events and MineTrialConfig.Events.Start) or "MineTrialStart",
        TrialClaim = (MineTrialConfig and MineTrialConfig.Events and MineTrialConfig.Events.Claim) or "MineTrialClaim",
        TrialCancel = (MineTrialConfig and MineTrialConfig.Events and MineTrialConfig.Events.Cancel) or "MineTrialCancel",
        OpenColossusCrate = "MineOpenColossusCrate",

        -- Dynamic / Module-based Event Constants (พร้อม Fallback)
        IndexClaim = (MineIndexRewardsConfig and MineIndexRewardsConfig.Events and MineIndexRewardsConfig.Events.Claim) or "MineIndexRewardsClaim",
        EventsOpen = (MineEventsConfig and MineEventsConfig.Events and MineEventsConfig.Events.Open) or "MineEventsOpen",
        EventsClaim = (MineEventsConfig and MineEventsConfig.Events and MineEventsConfig.Events.Claim) or "MineEventsClaim",
        EventsState = (MineEventsConfig and MineEventsConfig.Events and MineEventsConfig.Events.State) or "MineEventsState",
    },
    AutoMine = true,
    AutoChest = true,
    AutoSell = true,
    AutoSellOldChars = true, -- ขายตัวละครโซนเก่าอัตโนมัติ
    AutoBuyBestPickaxe = true,
    AutoBuyZone = true,
    AutoUpgradeTree = true,
    AutoUpgradeCore = true,
    AutoEquipBest = true,
    AutoUpgradeAllChars = true,
    AutoMutation = false,
    AutoRollDice = false,       -- สุ่มลูกเต๋าเวทมนต์อัตโนมัติ
    AutoSummonScrolls = false,  -- สุ่มม้วนอัญเชิญอัตโนมัติ
    AutoClaimIndex = true,      -- รับรางวัลในดัชนี (Index) อัตโนมัติ
    AutoClaimEvents = true,     -- รับรางวัลบอร์ดอีเว้น (Events) อัตโนมัติ
    AutoInfinityTrial = false,  -- ลงทดสอบอินฟินิตี้ & รับรางวัลอัตโนมัติ
    AutoOpenPetalfallCrate = false, -- เปิด Petalfall Crate อัตโนมัติเมื่อมีในคลัง

    MutationSlots = {
        ["M1"] = true,
        ["M2"] = true,
        ["M3"] = true,
        ["M4"] = true,
        ["M5"] = true,
        ["M6"] = true,
        ["M7"] = true,
        ["M8"] = true
    },

    TargetLevelDamage = 200,
    TargetLevelSpeed = 17,
    TargetLevelMineSpeed = 16,

    TargetMutations = {
        ["Rainbow"] = true,
        ["Inferno"] = true,
        ["Unreal"] = true,
        ["Paradox"] = true,
        ["Nightmare"] = true,
        ["Frozen"] = true,
        ["Unleashed"] = true
    },
    AntiAFK = true
}

local AllMutations = {
    "Rainbow",
    "Inferno",
    "Unreal",
    "Paradox",
    "Nightmare",
    "Frozen",
    "Unleashed",
    "Platinum",
    "Diamond",
    "Bronze"
}

-- ตัวแปรเก็บสถานะอีเว้นล่าสุด
local latestEventsPayload = nil
local lastEventRequestTime = 0
pcall(function()
    if GameState and GameState.ListenToEvent and Config.Events and Config.Events.EventsState then
        GameState.ListenToEvent(Config.Events.EventsState, function(data)
            if type(data) == "table" then
                latestEventsPayload = data
            end
        end)
    end
end)

local function SaveConfig()
    pcall(function()
        if writefile then
            local dataToSave = {
                AutoMine = Config.AutoMine,
                AutoChest = Config.AutoChest,
                AutoSell = Config.AutoSell,
                AutoSellOldChars = Config.AutoSellOldChars,
                AutoBuyBestPickaxe = Config.AutoBuyBestPickaxe,
                AutoBuyZone = Config.AutoBuyZone,
                AutoUpgradeTree = Config.AutoUpgradeTree,
                AutoUpgradeCore = Config.AutoUpgradeCore,
                AutoEquipBest = Config.AutoEquipBest,
                AutoUpgradeAllChars = Config.AutoUpgradeAllChars,
                AutoMutation = Config.AutoMutation,
                AutoRollDice = Config.AutoRollDice,
                AutoSummonScrolls = Config.AutoSummonScrolls,
                AutoClaimIndex = Config.AutoClaimIndex,
                AutoClaimEvents = Config.AutoClaimEvents,
                AutoInfinityTrial = Config.AutoInfinityTrial,
                AutoOpenPetalfallCrate = Config.AutoOpenPetalfallCrate,
                MutationSlots = Config.MutationSlots,
                TargetLevelDamage = Config.TargetLevelDamage,
                TargetLevelSpeed = Config.TargetLevelSpeed,
                TargetLevelMineSpeed = Config.TargetLevelMineSpeed,
                TargetMutations = Config.TargetMutations,
                AntiAFK = Config.AntiAFK
            }
            writefile(CONFIG_FILE, HttpService:JSONEncode(dataToSave))
        end
    end)
end

local function LoadConfig()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if Config[k] ~= nil and k ~= "Events" then
                        Config[k] = v
                    end
                end
            end
        end
    end)
end

LoadConfig()
SaveConfig()

-- ═══════════════════════════════════════════════
-- 📍 3. NULL-SAFE HELPERS: ค้นหา Plot & จุดวาร์ป
-- ═══════════════════════════════════════════════
local function GetMyPlot()
    local mw = workspace:FindFirstChild("MineWorld")
    if not mw then
        warn("⚠️ [Null-Safety] ไม่พบ 'MineWorld' ใน workspace")
        return nil
    end
    local plots = mw:FindFirstChild("Plots")
    if not plots then
        warn("⚠️ [Null-Safety] ไม่พบ 'Plots' ใน MineWorld")
        return nil
    end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:GetAttribute("OwnerUserId") or plot:GetAttribute("Owner")
        if owner == LocalPlayer.UserId or owner == tostring(LocalPlayer.UserId) then
            return plot
        end
    end
    return nil
end

local function GetPlotReturnCFrame(plot)
    if not plot then return nil end
    local plotSpawn = plot:FindFirstChild("PlotSpawn")
    if plotSpawn and plotSpawn:IsA("BasePart") then
        return plotSpawn.CFrame + Vector3.new(0, 3, 0)
    end
    local ok, pivot = pcall(function() return plot:GetPivot() end)
    if ok and pivot then
        return pivot + Vector3.new(0, 4, 0)
    end
    return nil
end

-- ═══════════════════════════════════════════════
-- 🎨 UI SYSTEM
-- ═══════════════════════════════════════════════
for _, oldName in ipairs({"AnimeMineAutoFarmV5", "AnimeMineAutoFarmV6", "AnimeMineAutoFarmV7", "AnimeMineAutoFarmV8", "AnimeMineAutoFarmV9", "AnimeMineAutoFarmV10", "AnimeMineAutoFarmV11", "AnimeMineAutoFarmV12", "AnimeMineAutoFarmV13", "AnimeMineAutoFarmV14", "AnimeMineAutoFarmV15", "MineTradeSelectiveUI"}) do
    local oldGui = PlayerGui:FindFirstChild(oldName)
    if oldGui then oldGui:Destroy() end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimeMineAutoFarmV15"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

local Theme = {
    Background = Color3.fromRGB(18, 18, 28),
    Header = Color3.fromRGB(34, 24, 56),
    Category = Color3.fromRGB(28, 26, 44),
    Button = Color3.fromRGB(24, 24, 38),
    InputBG = Color3.fromRGB(15, 15, 24),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(160, 160, 185),
    ToggleOn = Color3.fromRGB(46, 204, 113),
    ToggleOff = Color3.fromRGB(231, 76, 60),
    Accent = Color3.fromRGB(165, 94, 234),
    Border = Color3.fromRGB(70, 48, 110),
    ChipActive = Color3.fromRGB(142, 68, 173),
    ChipInactive = Color3.fromRGB(36, 36, 52),
    ChipLocked = Color3.fromRGB(39, 174, 96),
    BadgeBG = Color3.fromRGB(38, 32, 60),
    SpecialBtn = Color3.fromRGB(230, 126, 34)
}

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 370, 0, 620)
MainFrame.Position = UDim2.new(0, 20, 0.5, -310)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MainFrame

local Stroke = Instance.new("UIStroke")
Stroke.Thickness = 2
Stroke.Color = Theme.Border
Stroke.Parent = MainFrame

-- Header
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 50)
Header.BackgroundColor3 = Theme.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 12)
HeaderFix.Position = UDim2.new(0, 0, 1, -12)
HeaderFix.BackgroundColor3 = Theme.Header
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 175, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⛏️ Auto Farm Suite V14"
Title.TextColor3 = Theme.Text
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local StatusBadge = Instance.new("TextLabel")
StatusBadge.Name = "StatusBadge"
StatusBadge.Size = UDim2.new(0, 130, 0, 26)
StatusBadge.Position = UDim2.new(1, -170, 0.5, -13)
StatusBadge.BackgroundColor3 = Theme.BadgeBG
StatusBadge.Text = "⏸️ เริ่มต้นทำงาน..."
StatusBadge.TextColor3 = Theme.Accent
StatusBadge.TextSize = 11
StatusBadge.Font = Enum.Font.GothamMedium
StatusBadge.Parent = Header

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(0, 6)
BadgeCorner.Parent = StatusBadge

local function UpdateStatus(text)
    StatusBadge.Text = text
end

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -34, 0.5, -14)
MinBtn.BackgroundColor3 = Theme.Accent
MinBtn.Text = "—"
MinBtn.TextColor3 = Theme.Text
MinBtn.TextSize = 15
MinBtn.Font = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

-- Scroll Container
local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Content"
Scroll.Size = UDim2.new(1, -16, 1, -60)
Scroll.Position = UDim2.new(0, 8, 0, 54)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Theme.Accent
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.Parent = MainFrame

local Layout = Instance.new("UIListLayout")
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Padding = UDim.new(0, 6)
Layout.Parent = Scroll

-- ═══════════════════════════════════════════════
-- 🛠️ UI BUILDERS
-- ═══════════════════════════════════════════════
local ToggleControls = {}

local function AddCategory(title, order)
    local Cat = Instance.new("Frame")
    Cat.Size = UDim2.new(1, 0, 0, 26)
    Cat.BackgroundColor3 = Theme.Category
    Cat.BorderSizePixel = 0
    Cat.LayoutOrder = order
    Cat.Parent = Scroll

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 6)
    cCorner.Parent = Cat

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Theme.Accent
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Cat
end

local function AddToggle(key, name, desc, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 46)
    Frame.BackgroundColor3 = Theme.Button
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order
    Frame.Parent = Scroll

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 8)
    fCorner.Parent = Frame

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -65, 0, 18)
    tLbl.Position = UDim2.new(0, 12, 0, 6)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = name
    tLbl.TextColor3 = Theme.Text
    tLbl.TextSize = 12
    tLbl.Font = Enum.Font.GothamSemibold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = Frame

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -65, 0, 14)
    dLbl.Position = UDim2.new(0, 12, 0, 24)
    dLbl.BackgroundTransparency = 1
    dLbl.Text = desc
    dLbl.TextColor3 = Theme.SubText
    dLbl.TextSize = 10
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.Parent = Frame

    local Switch = Instance.new("Frame")
    Switch.Size = UDim2.new(0, 40, 0, 20)
    Switch.Position = UDim2.new(1, -48, 0.5, -10)
    Switch.BackgroundColor3 = Config[key] and Theme.ToggleOn or Theme.ToggleOff
    Switch.BorderSizePixel = 0
    Switch.Parent = Frame

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(1, 0)
    sCorner.Parent = Switch

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = Config[key] and UDim2.new(0, 21, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    Knob.Parent = Switch

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = Knob

    local function UpdateVisual(val)
        TweenService:Create(Switch, TweenInfo.new(0.2), {
            BackgroundColor3 = val and Theme.ToggleOn or Theme.ToggleOff
        }):Play()

        TweenService:Create(Knob, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
            Position = val and UDim2.new(0, 21, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
    end

    ToggleControls[key] = {
        Set = function(val)
            Config[key] = val
            UpdateVisual(val)
            SaveConfig()
        end
    }

    local Click = Instance.new("TextButton")
    Click.Size = UDim2.new(1, 0, 1, 0)
    Click.BackgroundTransparency = 1
    Click.Text = ""
    Click.Parent = Frame

    Click.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        UpdateVisual(Config[key])
        SaveConfig()
    end)
    return Frame
end

local function AddActionButton(name, desc, btnText, btnColor, callback, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 44)
    Frame.BackgroundColor3 = Theme.Button
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order
    Frame.Parent = Scroll

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 8)
    fCorner.Parent = Frame

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -125, 0, 18)
    tLbl.Position = UDim2.new(0, 12, 0, 5)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = name
    tLbl.TextColor3 = Theme.Text
    tLbl.TextSize = 11
    tLbl.Font = Enum.Font.GothamSemibold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = Frame

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -125, 0, 14)
    dLbl.Position = UDim2.new(0, 12, 0, 23)
    dLbl.BackgroundTransparency = 1
    dLbl.Text = desc
    dLbl.TextColor3 = Theme.SubText
    dLbl.TextSize = 10
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.Parent = Frame

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 105, 0, 26)
    Btn.Position = UDim2.new(1, -117, 0.5, -13)
    Btn.BackgroundColor3 = btnColor or Theme.BadgeBG
    Btn.Text = btnText
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.TextSize = 10
    Btn.Font = Enum.Font.GothamBold
    Btn.BorderSizePixel = 0
    Btn.Parent = Frame

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = Btn

    Btn.MouseButton1Click:Connect(callback)
    return Frame
end

local function AddLevelCapCustomInput(title, configKey, minVal, maxVal, step, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 42)
    Frame.BackgroundColor3 = Theme.Button
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order
    Frame.Parent = Scroll

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 8)
    fCorner.Parent = Frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 155, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Frame

    local Actions = Instance.new("Frame")
    Actions.Size = UDim2.new(0, 175, 0, 28)
    Actions.Position = UDim2.new(1, -183, 0.5, -14)
    Actions.BackgroundTransparency = 1
    Actions.Parent = Frame

    local aLayout = Instance.new("UIListLayout")
    aLayout.FillDirection = Enum.FillDirection.Horizontal
    aLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    aLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    aLayout.Padding = UDim.new(0, 4)
    aLayout.Parent = Actions

    local InputBox = Instance.new("TextBox")
    InputBox.Size = UDim2.new(0, 52, 0, 26)
    InputBox.BackgroundColor3 = Theme.InputBG
    InputBox.Text = tostring(Config[configKey])
    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    InputBox.TextSize = 12
    InputBox.Font = Enum.Font.GothamBold
    InputBox.ClearTextOnFocus = false
    InputBox.BorderSizePixel = 0
    InputBox.LayoutOrder = 2
    InputBox.Parent = Actions

    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(0, 6)
    iCorner.Parent = InputBox

    local iStroke = Instance.new("UIStroke")
    iStroke.Color = Theme.Border
    iStroke.Thickness = 1
    iStroke.Parent = InputBox

    local function ApplyValue(val)
        val = tonumber(val) or Config[configKey]
        val = math.clamp(math.floor(val), minVal, maxVal)
        Config[configKey] = val
        InputBox.Text = tostring(val)
        SaveConfig()
    end

    InputBox.FocusLost:Connect(function()
        ApplyValue(InputBox.Text)
    end)

    local DecBtn = Instance.new("TextButton")
    DecBtn.Size = UDim2.new(0, 26, 0, 26)
    DecBtn.BackgroundColor3 = Theme.BadgeBG
    DecBtn.Text = "—"
    DecBtn.TextColor3 = Theme.Accent
    DecBtn.TextSize = 11
    DecBtn.Font = Enum.Font.GothamBold
    DecBtn.BorderSizePixel = 0
    DecBtn.LayoutOrder = 1
    DecBtn.Parent = Actions

    local dCorner = Instance.new("UICorner")
    dCorner.CornerRadius = UDim.new(0, 6)
    dCorner.Parent = DecBtn

    DecBtn.MouseButton1Click:Connect(function()
        ApplyValue(Config[configKey] - step)
    end)

    local IncBtn = Instance.new("TextButton")
    IncBtn.Size = UDim2.new(0, 26, 0, 26)
    IncBtn.BackgroundColor3 = Theme.BadgeBG
    IncBtn.Text = "+"
    IncBtn.TextColor3 = Theme.Accent
    IncBtn.TextSize = 12
    IncBtn.Font = Enum.Font.GothamBold
    IncBtn.BorderSizePixel = 0
    IncBtn.LayoutOrder = 3
    IncBtn.Parent = Actions

    local inCorner = Instance.new("UICorner")
    inCorner.CornerRadius = UDim.new(0, 6)
    inCorner.Parent = IncBtn

    IncBtn.MouseButton1Click:Connect(function()
        ApplyValue(Config[configKey] + step)
    end)

    local MaxBtn = Instance.new("TextButton")
    MaxBtn.Size = UDim2.new(0, 42, 0, 26)
    MaxBtn.BackgroundColor3 = Theme.ChipActive
    MaxBtn.Text = "ตัน"
    MaxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MaxBtn.TextSize = 10
    MaxBtn.Font = Enum.Font.GothamBold
    MaxBtn.BorderSizePixel = 0
    MaxBtn.LayoutOrder = 4
    MaxBtn.Parent = Actions

    local mCorner = Instance.new("UICorner")
    mCorner.CornerRadius = UDim.new(0, 6)
    mCorner.Parent = MaxBtn

    MaxBtn.MouseButton1Click:Connect(function()
        ApplyValue(maxVal)
    end)
end

-- ตัวเลือก Slot สุ่มบัพ (จัดลำดับตาม Base DMG Lv.1 + ล็อคอัตโนมัติ)
local function AddMultiSlotSelector(order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 105)
    Frame.BackgroundColor3 = Theme.Button
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order
    Frame.Parent = Scroll

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 8)
    fCorner.Parent = Frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 210, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = "📌 แท่นสุ่มบัพ (เรียงตาม Base DMG Lv.1):"
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Frame

    local QuickActions = Instance.new("Frame")
    QuickActions.Size = UDim2.new(0, 130, 0, 20)
    QuickActions.Position = UDim2.new(1, -140, 0, 6)
    QuickActions.BackgroundTransparency = 1
    QuickActions.Parent = Frame

    local qLayout = Instance.new("UIListLayout")
    qLayout.FillDirection = Enum.FillDirection.Horizontal
    qLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    qLayout.Padding = UDim.new(0, 4)
    qLayout.Parent = QuickActions

    local SelectAllBtn = Instance.new("TextButton")
    SelectAllBtn.Size = UDim2.new(0, 62, 1, 0)
    SelectAllBtn.BackgroundColor3 = Theme.BadgeBG
    SelectAllBtn.Text = "เลือกทั้งหมด"
    SelectAllBtn.TextColor3 = Theme.Accent
    SelectAllBtn.TextSize = 9
    SelectAllBtn.Font = Enum.Font.GothamMedium
    SelectAllBtn.BorderSizePixel = 0
    SelectAllBtn.Parent = QuickActions

    local saCorner = Instance.new("UICorner")
    saCorner.CornerRadius = UDim.new(0, 4)
    saCorner.Parent = SelectAllBtn

    local ClearAllBtn = Instance.new("TextButton")
    ClearAllBtn.Size = UDim2.new(0, 44, 1, 0)
    ClearAllBtn.BackgroundColor3 = Theme.BadgeBG
    ClearAllBtn.Text = "ล้าง"
    ClearAllBtn.TextColor3 = Theme.SubText
    ClearAllBtn.TextSize = 9
    ClearAllBtn.Font = Enum.Font.GothamMedium
    ClearAllBtn.BorderSizePixel = 0
    ClearAllBtn.Parent = QuickActions

    local caCorner = Instance.new("UICorner")
    caCorner.CornerRadius = UDim.new(0, 4)
    caCorner.Parent = ClearAllBtn

    local SlotContainer = Instance.new("Frame")
    SlotContainer.Size = UDim2.new(1, -24, 0, 28)
    SlotContainer.Position = UDim2.new(0, 12, 0, 30)
    SlotContainer.BackgroundTransparency = 1
    SlotContainer.Parent = Frame

    local sLayout = Instance.new("UIListLayout")
    sLayout.FillDirection = Enum.FillDirection.Horizontal
    sLayout.Padding = UDim.new(0, 4)
    sLayout.Parent = SlotContainer

    local StatusSubLabel = Instance.new("TextLabel")
    StatusSubLabel.Size = UDim2.new(1, -24, 0, 36)
    StatusSubLabel.Position = UDim2.new(0, 12, 0, 62)
    StatusSubLabel.BackgroundTransparency = 1
    StatusSubLabel.Text = "สถานะ: กำลังตรวจสอบ..."
    StatusSubLabel.TextColor3 = Theme.SubText
    StatusSubLabel.TextSize = 10
    StatusSubLabel.Font = Enum.Font.Gotham
    StatusSubLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusSubLabel.TextYAlignment = Enum.TextYAlignment.Top
    StatusSubLabel.TextWrapped = true
    StatusSubLabel.Parent = Frame

    local slotButtons = {}
    local availableSlots = { "M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8" }

    local function RefreshVisuals()
        local d2 = GameState.GetData2()
        local mg = d2 and d2.MineGame
        local lockedCount = 0
        local totalSelected = 0

        for _, sName in ipairs(availableSlots) do
            local btn = slotButtons[sName]
            local isSelected = Config.MutationSlots[sName] == true
            local h = mg and mg.Holders and mg.Holders[sName]
            local curVariant = h and h.CharVariant or "Normal"
            local isTargetHit = Config.TargetMutations[curVariant] == true

            if isSelected then
                totalSelected = totalSelected + 1
                if isTargetHit then
                    lockedCount = lockedCount + 1
                    btn.BackgroundColor3 = Theme.ChipLocked
                    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    btn.Text = "🔒" .. sName
                else
                    btn.BackgroundColor3 = Theme.ChipActive
                    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    btn.Text = "✓" .. sName
                end
            else
                btn.BackgroundColor3 = Theme.ChipInactive
                btn.TextColor3 = Theme.SubText
                btn.Text = "+" .. sName
            end
        end

        StatusSubLabel.Text = string.format("เลือกทั้งหมด: %d แท่น | ล็อคแล้ว: %d | รอดำเนินการ: %d (เปิดค้างได้ สุ่มตัว Base DMG สูงสุดก่อน)", totalSelected, lockedCount, math.max(0, totalSelected - lockedCount))
    end

    for _, sName in ipairs(availableSlots) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 37, 1, 0)
        btn.BackgroundColor3 = Theme.ChipInactive
        btn.Text = sName
        btn.TextColor3 = Theme.SubText
        btn.TextSize = 10
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = SlotContainer

        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 5)
        bCorner.Parent = btn

        slotButtons[sName] = btn

        btn.MouseButton1Click:Connect(function()
            if Config.MutationSlots[sName] then
                Config.MutationSlots[sName] = nil
            else
                Config.MutationSlots[sName] = true
            end
            SaveConfig()
            RefreshVisuals()
        end)
    end

    SelectAllBtn.MouseButton1Click:Connect(function()
        for _, sName in ipairs(availableSlots) do
            Config.MutationSlots[sName] = true
        end
        SaveConfig()
        RefreshVisuals()
    end)

    ClearAllBtn.MouseButton1Click:Connect(function()
        Config.MutationSlots = {}
        SaveConfig()
        RefreshVisuals()
    end)

    task.spawn(function()
        while Frame and Frame.Parent do
            RefreshVisuals()
            task.wait(1.5)
        end
    end)
end

local function AddMultiMutationSelector(order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 140)
    Frame.BackgroundColor3 = Theme.Button
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order
    Frame.Parent = Scroll

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 8)
    fCorner.Parent = Frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 0, 20)
    lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = "🎯 เลือกบัพการกลายพันธุ์เป้าหมาย (เลือกกี่บัพก็ได้):"
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = Frame

    local ChipContainer = Instance.new("Frame")
    ChipContainer.Size = UDim2.new(1, -24, 0, 105)
    ChipContainer.Position = UDim2.new(0, 12, 0, 28)
    ChipContainer.BackgroundTransparency = 1
    ChipContainer.Parent = Frame

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 100, 0, 28)
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.Parent = ChipContainer

    for _, mutName in ipairs(AllMutations) do
        local chip = Instance.new("TextButton")
        local isSelected = Config.TargetMutations[mutName] == true
        chip.BackgroundColor3 = isSelected and Theme.ChipActive or Theme.ChipInactive
        chip.Text = (isSelected and "✓ " or "+ ") .. mutName
        chip.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Theme.SubText
        chip.TextSize = 10
        chip.Font = Enum.Font.GothamMedium
        chip.BorderSizePixel = 0
        chip.Parent = ChipContainer

        local chCorner = Instance.new("UICorner")
        chCorner.CornerRadius = UDim.new(0, 6)
        chCorner.Parent = chip

        chip.MouseButton1Click:Connect(function()
            if Config.TargetMutations[mutName] then
                Config.TargetMutations[mutName] = nil
                chip.BackgroundColor3 = Theme.ChipInactive
                chip.TextColor3 = Theme.SubText
                chip.Text = "+ " .. mutName
            else
                Config.TargetMutations[mutName] = true
                chip.BackgroundColor3 = Theme.ChipActive
                chip.TextColor3 = Color3.fromRGB(255, 255, 255)
                chip.Text = "✓ " .. mutName
            end
            SaveConfig()
        end)
    end
end

-- ═══════════════════════════════════════════════
-- 🛠️ ACTION HELPERS (TRIALS, CRATES, EQUIP BEST)
-- ═══════════════════════════════════════════════

-- Helper สำหรับตรวจสอบสถานะรางวัลของ Infinity Trial (ตรวจนับจำนวนเทียร์ที่เคลมแล้วและนับถอยหลังรีเซ็ต)
local function GetTrialRewardStatus(trialData)
    if not (MineTrialConfig and trialData) then
        return { allClaimed = false, claimedCount = 0, totalTiers = 12, claimable = {}, claimableCount = 0, resetCountdown = "00:00:00", secondsLeft = 0 }
    end
    local totalTiers = (MineTrialConfig.TierCount and MineTrialConfig.TierCount(trialData)) or 12
    local claimedCount = 0
    for i = 1, totalTiers do
        if MineTrialConfig.IsClaimed and MineTrialConfig.IsClaimed(trialData, i) then
            claimedCount = claimedCount + 1
        end
    end
    local claimable = (MineTrialConfig.ClaimableTiers and MineTrialConfig.ClaimableTiers(trialData)) or {}
    local allClaimed = (claimedCount >= totalTiers)
    local secondsLeft = (MineTrialConfig.SecondsToNextDay and MineTrialConfig.SecondsToNextDay()) or 0
    local resetCountdown = (MineTrialConfig.FormatCountdown and MineTrialConfig.FormatCountdown(secondsLeft)) or string.format("%ds", secondsLeft)

    return {
        allClaimed = allClaimed,
        claimedCount = claimedCount,
        totalTiers = totalTiers,
        claimable = claimable,
        claimableCount = #claimable,
        hasAvailableRewards = not allClaimed,
        resetCountdown = resetCountdown,
        secondsLeft = secondsLeft
    }
end

-- Helper สำหรับลงทดสอบอินฟินิตี้ (Infinity Trial)
local function TriggerInfinityTrial(force)
    local d2 = SafeGetData2()
    local mg = d2 and d2.MineGame
    if not (mg and MineTrialConfig) then
        UpdateStatus("⚠️ ไม่พบข้อมูลโหมด Infinity Trial")
        return
    end
    if MineTrialConfig.Unlocked and not MineTrialConfig.Unlocked(mg) then
        UpdateStatus("🔒 ยังไม่ปลดล็อกโหมด Infinity Trial")
        return
    end
    local trialData = (mg.Trial and type(mg.Trial) == "table" and mg.Trial) or {}
    local status = GetTrialRewardStatus(trialData)

    -- หากเคลมรางวัลครบทุกเทียร์แล้ว และไม่ได้สั่งบังคับลง
    if not force and status.allClaimed then
        UpdateStatus(string.format("⏳ รางวัลครบแล้ว (รอรีเซ็ต %s)", status.resetCountdown))
        return
    end

    local attempt = trialData.Attempt
    local now = os.time()
    local isRunning = type(attempt) == "table" and (tonumber(attempt.EndsAt) or 0) > now
    if isRunning then
        UpdateStatus("ℹ️ กำลังทดสอบ Infinity Trial อยู่ในขณะนี้")
    else
        UpdateStatus("⚔️ เริ่มลงทดสอบอินฟินิตี้ (Infinity Trial)...")
        SafeSendEvent(Config.Events.TrialStart)
        HumanWait(0.4, 0.6)
        UpdateStatus("✅ เริ่มลงทดสอบ Infinity Trial สำเร็จ!")
    end
end

-- Helper สำหรับรับรางวัล Infinity Trial
local function TriggerClaimTrial()
    local d2 = SafeGetData2()
    local mg = d2 and d2.MineGame
    if not (mg and MineTrialConfig) then return end
    local trialData = (mg.Trial and type(mg.Trial) == "table" and mg.Trial) or {}
    local claimable = MineTrialConfig.ClaimableTiers and MineTrialConfig.ClaimableTiers(trialData)
    if claimable and #claimable > 0 then
        local count = 0
        for _, tierIdx in ipairs(claimable) do
            UpdateStatus(string.format("🏆 รับรางวัล Infinity Trial T%d...", tierIdx))
            SafeSendEvent(Config.Events.TrialClaim, tierIdx)
            count = count + 1
            HumanWait(0.35, 0.5)
        end
        UpdateStatus(string.format("✅ รับรางวัล Infinity Trial %d รายการสำเร็จ!", count))
    else
        UpdateStatus("ℹ️ ไม่มีรางวัล Infinity Trial ที่ค้างรับ")
    end
end

-- Helper สำหรับเปิด Petalfall Crate
local function TriggerOpenPetalfallCrate()
    local d2 = SafeGetData2()
    local mg = d2 and d2.MineGame
    local cc = mg and mg.ColossusCrates
    local count = cc and (tonumber(cc["Petalfall Crate"]) or 0) or 0
    if count <= 0 then
        UpdateStatus("ℹ️ ไม่มี Petalfall Crate ในคลัง")
        return
    end
    local openAmount = math.clamp(count, 1, 50)
    UpdateStatus(string.format("🌸 เปิด Petalfall Crate (%d/%d กล่อง)...", openAmount, count))
    SafeSendEvent(Config.Events.OpenColossusCrate, "Petalfall Crate", openAmount)
    HumanWait(0.4, 0.6)
    UpdateStatus(string.format("✅ เปิด Petalfall Crate %d กล่องสำเร็จ!", openAmount))
end

-- Helper สำหรับกดปุ่มสวมใส่ที่ดีที่สุดทั้ง UI และ Server
local function TriggerEquipBest()
    UpdateStatus("👥 สวมใส่ตัวที่ดีที่สุด...")
    local mineGui = PlayerGui:FindFirstChild("MineGui")
    if not mineGui then
        warn("⚠️ [Null-Safety] ไม่พบ 'MineGui' ใน PlayerGui ข้ามการกดปุ่ม UI")
    else
        local invFrame = mineGui:FindFirstChild("InventoryFrame")
        if not invFrame then
            warn("⚠️ [Null-Safety] ไม่พบ 'InventoryFrame' ใน MineGui")
        else
            local eqBtn = invFrame:FindFirstChild("EquipBestButton", true)
            if eqBtn then
                if getconnections then
                    local conns = getconnections(eqBtn.MouseButton1Click)
                    if conns and conns[1] then
                        conns[1]:Fire()
                    end
                end
            else
                warn("⚠️ [Null-Safety] ไม่พบ 'EquipBestButton' ใน InventoryFrame")
            end
        end
    end
    SafeSendEvent(Config.Events.EquipBest)
    HumanWait(0.25, 0.35)
end

-- ═══════════════════════════════════════════════
-- 📋 สร้างเมนูจัดหมวดหมู่ UI ใหม่ (6 หมวดหมู่ ใช้งานง่าย & สะดวก)
-- ═══════════════════════════════════════════════

-- หมวดที่ 1: ระบบฟาร์ม & ร้านค้า
AddCategory("📦 1. ระบบฟาร์ม & ร้านค้า (Farming & Sell)", 1)
AddToggle("AutoMine", "Auto Mine (ขุดหินในแปลง)", "ค้นหาและขุดหินในแปลง รวมถึงหินทดสอบอินฟินิตี้ก่อนเสมอ", 2)
AddToggle("AutoChest", "Auto Take Chest (ดูดแร่จากหีบ)", "ดูดแร่จากหีบเข้ากระเป๋าอัตโนมัติเมื่อหินแตก", 3)
AddToggle("AutoSell", "Auto Sell Ores (ขายแร่ที่ร้าน)", "เมื่อมีแร่ในกระเป๋า วาร์ปไปขายที่ร้าน SellStand ทันที", 4)
AddToggle("AutoSellOldChars", "Auto Sell Old Zone Chars", "ขายตัวละครโซนเก่าทิ้งอัตโนมัติ (เก็บตัวละครโซนปัจจุบันไว้ 100%)", 5)
AddActionButton("⚡ ขายตัวละครโซนเก่าทันที", "วาร์ปไปขายตัวละครในคลังจากโซนเก่าทั้งหมดรอบเดียว", "ขายทันที", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(function()
            local d2 = SafeGetData2()
            local mg = d2 and d2.MineGame
            local oldKeys = GetOldZoneCharacterKeys(mg)
            if #oldKeys == 0 then
                UpdateStatus("ℹ️ ไม่มีตัวละครโซนเก่าให้ขาย")
                return
            end
            local char = LocalPlayer.Character
            local sellStand = workspace:FindFirstChild("SellStand")
            if not sellStand then
                warn("⚠️ [Null-Safety] ไม่พบ 'SellStand' ใน workspace")
                UpdateStatus("⚠️ ไม่พบร้านค้า SellStand")
                return
            end
            local myPlot = GetMyPlot()
            local returnPlot = GetPlotReturnCFrame(myPlot)
            if char and sellStand then
                UpdateStatus(string.format("💰 ขายตัวละครโซนเก่า (%d ชุด)...", #oldKeys))
                char:PivotTo(sellStand:GetPivot() + Vector3.new(0, 3, 5))
                HumanWait(0.35, 0.5)
                SafeSendEvent(Config.Events.SellItems, oldKeys)
                HumanWait(0.35, 0.5)
                if returnPlot then
                    char:PivotTo(returnPlot)
                    HumanWait(0.2, 0.3)
                end
                UpdateStatus(string.format("✅ ขายตัวละครโซนเก่า %d ชุดสำเร็จ!", #oldKeys))
            end
        end)
        if not ok then
            warn(string.format("⚠️ [Action Error: SellOldChars] %s", tostring(err)))
        end
    end)
end, 6)
AddToggle("AutoBuyZone", "Auto Unlock New Zone", "ซื้อและปลดล็อกโซนใหม่ที่ ZoneBoard เมื่อวิจัยครบ", 7)

-- หมวดที่ 2: ดันเจี้ยน & กล่องรางวัล
AddCategory("⚔️ 2. ดันเจี้ยน & กล่องรางวัล (Trials & Crates)", 10)
AddToggle("AutoInfinityTrial", "Auto Infinity Trial (ทดสอบอินฟินิตี้)", "ลงทดสอบและเคลมรับรางวัลอินฟินิตี้อัตโนมัติเมื่อพร้อม", 11)
AddActionButton("⚡ ลง Infinity Trial ทันที", "สั่งเริ่มการทดสอบอินฟินิตี้ (Infinity Trial) รอบใหม่ทันที", "ลง Trial", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerInfinityTrial)
        if not ok then warn(string.format("⚠️ [Action Error: InfinityTrial] %s", tostring(err))) end
    end)
end, 12)
AddActionButton("⚡ รับรางวัล Trial ทันที", "ตรวจสอบและกดรับรางวัล Infinity Trial ที่ผ่านเกณฑ์ทั้งหมดทันที", "รับรางวัล", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerClaimTrial)
        if not ok then warn(string.format("⚠️ [Action Error: ClaimTrial] %s", tostring(err))) end
    end)
end, 13)
AddToggle("AutoOpenPetalfallCrate", "Auto Open Petalfall Crate", "เปิดกล่อง Petalfall Crate ในคลังอัตโนมัติเมื่อมีกล่อง", 14)
AddActionButton("⚡ เปิด Petalfall Crate ทันที", "สั่งเปิดกล่อง Petalfall Crate ในคลังที่มีอยู่ทั้งหมดทันที", "เปิดกล่อง", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerOpenPetalfallCrate)
        if not ok then warn(string.format("⚠️ [Action Error: OpenPetalfallCrate] %s", tostring(err))) end
    end)
end, 15)

-- หมวดที่ 3: อัปเกรด & ขวานคนงาน
AddCategory("🌳 3. อัปเกรด & ขวานคนงาน (Upgrades & Gear)", 20)
AddToggle("AutoUpgradeTree", "Auto Zone Skill Tree (ต้นใหม่)", "อัปเกรดผังสกิลของโซนปัจจุบันตามลำดับโหนด (Batch Upgrades)", 21)
AddToggle("AutoUpgradeCore", "Auto Core Upgrades (แกนหลัก)", "อัปเกรด Tap Level และ Miner Slots ในแกนหลัก", 22)
AddToggle("AutoBuyBestPickaxe", "Auto Buy Best Pickaxe", "ซื้อขวานขั้นที่แพงและดีที่สุดเมื่อพร้อม (ไม่จำกัดจำนวน)", 23)
AddToggle("AutoEquipBest", "Auto Equip Best (ใส่ตัวดีที่สุด)", "ใส่ตัวละครที่ดีที่สุดลงแท่นขุด (เว้นช่วง 20 วิ ไม่ส่งซ้ำ)", 24)
AddActionButton("⚡ ใส่ตัวที่ดีที่สุดทันที", "ส่งคำสั่งสวมใส่ตัวละครที่ดีที่สุดลงแท่นขุดทันที", "สวมใส่ทันที", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerEquipBest)
        if ok then
            UpdateStatus("✅ สวมใส่ตัวที่ดีที่สุดสำเร็จ!")
        else
            warn(string.format("⚠️ [Action Error: EquipBest] %s", tostring(err)))
        end
    end)
end, 25)

-- หมวดที่ 4: สถิติตัวละคร & กลายพันธุ์
AddCategory("👥 4. สถิติตัวละคร & กลายพันธุ์ (Stats & Mutations)", 30)
AddToggle("AutoUpgradeAllChars", "Auto Upgrade Characters", "อัปเกรดสถิติตัวละคร โดยให้ความสำคัญจากตัวที่เก่งสุดก่อน", 31)
AddLevelCapCustomInput("⚔️ เป้าหมาย Damage (1-200 / ตัน):", "TargetLevelDamage", 1, 200, 5, 32)
AddLevelCapCustomInput("⚡ เป้าหมาย Speed (1-17 / ตัน):", "TargetLevelSpeed", 1, 17, 1, 33)
AddLevelCapCustomInput("⛏️ เป้าหมาย MineSpeed (1-16 / ตัน):", "TargetLevelMineSpeed", 1, 16, 1, 34)
AddToggle("AutoMutation", "Auto Mutation Roll (เปิดค้างได้)", "สุ่มบัพตัวละครที่เลือกทีละตัว และสแตนด์บายเมื่อได้ครบ (ไม่ปิดสวิตช์)", 35)
AddMultiSlotSelector(36)
AddMultiMutationSelector(37)

-- หมวดที่ 5: กาชา & รับรางวัล
AddCategory("🎲 5. กาชา & รับรางวัล (Gacha & Claims)", 40)
AddToggle("AutoRollDice", "Auto Roll Dice (ทอยลูกเต๋า Enchant)", "ทอยลูกเต๋า Enchant & Halloween อัตโนมัติ (หยุดเมื่อลูกเต๋าหมด)", 41)
AddToggle("AutoSummonScrolls", "Auto Summon Scrolls (สุ่มม้วนอัญเชิญ)", "เปิดม้วนอัญเชิญตัวละครอัตโนมัติ (หยุดเมื่อม้วนหมด)", 42)
AddToggle("AutoClaimIndex", "Auto Claim Index (รับรางวัล Index)", "รับรางวัลในดัชนีทั้งหมดที่ปลดล็อกอัตโนมัติ", 43)
AddActionButton("⚡ รับรางวัล Index ทันที", "ตรวจสอบและกดรับรางวัล Index ที่ปลดล็อกทั้งหมดทันที", "รับ Index", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(function()
            local d2 = SafeGetData2()
            local mg = d2 and d2.MineGame
            if not (mg and MineIndexRewardsConfig and MineIndexRewardsConfig.Enabled) then return end
            local heldNames = MineIndexRewardsConfig.HeldNames(mg)
            local claimedAny = 0
            for _, catKey in ipairs(MineIndexRewardsConfig.Keys()) do
                local state = MineIndexRewardsConfig.State(mg, catKey, heldNames)
                for _, tier in ipairs(state.Track or {}) do
                    if tier.Reached and not tier.Claimed then
                        for rIdx, rDef in ipairs(tier.Rewards or {}) do
                            local rIds = MineIndexRewardsConfig.RewardIds({rDef})
                            local rId = rIds and rIds[1]
                            local isClaimed = tier.ClaimedRewards and (tier.ClaimedRewards[rId] or 0) > 0
                            if not isClaimed then
                                UpdateStatus(string.format("📖 รับรางวัล Index: %s", catKey))
                                SafeSendEvent(Config.Events.IndexClaim, catKey, tier.Key, rIdx)
                                claimedAny = claimedAny + 1
                                HumanWait(0.3, 0.45)
                            end
                        end
                    end
                end
            end
            if claimedAny > 0 then
                UpdateStatus(string.format("✅ รับรางวัล Index %d รายการสำเร็จ!", claimedAny))
            else
                UpdateStatus("ℹ️ ไม่มีรางวัล Index ที่ค้างรับ")
            end
        end)
        if not ok then
            warn(string.format("⚠️ [Action Error: ClaimIndex] %s", tostring(err)))
        end
    end)
end, 44)
AddToggle("AutoClaimEvents", "Auto Claim Events (รับรางวัลอีเว้น)", "รับรางวัล Milestone บนบอร์ดอีเว้นอัตโนมัติ", 45)
AddActionButton("⚡ รับรางวัล Event ทันที", "ตรวจสอบและกดรับรางวัลบอร์ด Event ที่ปลดล็อกทั้งหมดทันที", "รับ Event", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(function()
            UpdateStatus("🏆 ตรวจสอบรางวัล Event...")
            SafeSendEvent(Config.Events.EventsOpen)
            HumanWait(0.4, 0.6)
            if latestEventsPayload and latestEventsPayload.Events then
                local claimedCount = 0
                for _, ev in ipairs(latestEventsPayload.Events or {}) do
                    local pts = tonumber(ev.Points) or 0
                    for tIdx, targetPts in ipairs(ev.Thresholds or {}) do
                        if pts >= targetPts and not (ev.Claimed and ev.Claimed[tIdx]) then
                            local tiers = ev.Days and ev.Key and MineEventsConfig and MineEventsConfig.Catalog and MineEventsConfig.Catalog[ev.Key] and MineEventsConfig.Tiers and MineEventsConfig.Tiers(ev.Days, MineEventsConfig.Catalog[ev.Key])
                            local tDef = tiers and tiers[tIdx]
                            local rList = tDef and tDef.Rewards or {}
                            local shownList = MineEventsConfig and MineEventsConfig.Shown and MineEventsConfig.Shown(rList) or rList
                            for rIdx, rItem in ipairs(shownList) do
                                local actualIdx = table.find(rList, rItem) or rIdx
                                local gotMask = type(ev.Got) == "table" and (tonumber(ev.Got[tIdx]) or 0) or 0
                                if not (gotMask > 0 and bit32.btest(gotMask, 2 ^ (actualIdx - 1))) then
                                    SafeSendEvent(Config.Events.EventsClaim, ev.Id, tIdx, actualIdx)
                                    claimedCount = claimedCount + 1
                                    HumanWait(0.35, 0.5)
                                end
                            end
                        end
                    end
                end
                if claimedCount > 0 then
                    UpdateStatus(string.format("✅ รับรางวัล Event %d รายการสำเร็จ!", claimedCount))
                else
                    UpdateStatus("ℹ️ ไม่มีรางวัล Event ที่ค้างรับ")
                end
            else
                UpdateStatus("ℹ️ กำลังรอข้อมูลบอร์ด Event...")
            end
        end)
        if not ok then
            warn(string.format("⚠️ [Action Error: ClaimEvent] %s", tostring(err)))
        end
    end)
end, 46)

-- หมวดที่ 6: ระบบเสริม
AddCategory("🛡️ 6. ระบบเสริม (System)", 50)
AddToggle("AntiAFK", "Anti-AFK Protection", "ป้องกันระบบตัดการเชื่อมต่อเมื่อ AFK", 51)

-- หมวดที่ 7: ระบบแลกเปลี่ยน & โอนไอเทม (Trade Suite)
AddCategory("🤝 7. ระบบแลกเปลี่ยน & โอนไอเทม (Trade Suite)", 60)
AddActionButton("Trade Suite UI", "เปิด/ปิดหน้าต่างเมนูเทรดไอเทมและอัญมณีแบบแยกจอ", "🤝 เปิด Trade UI", Color3.fromRGB(130, 70, 220), function()
    if TradeMainFrame then
        TradeMainFrame.Visible = not TradeMainFrame.Visible
    end
end, 61)

local TradeMainToggleBtn
local TradeMainToggleFrame = AddActionButton("สวิตช์ระบบเทรด (Trade Switch)", "กดเปิดเพื่อเริ่มส่งของ หรือกดปิดเพื่อหยุดการเทรด", "🚀 ปิด (OFF)", Color3.fromRGB(50, 50, 70), function()
    if _G.ToggleTrade then
        _G.ToggleTrade()
    end
end, 62)
if TradeMainToggleFrame then
    TradeMainToggleBtn = TradeMainToggleFrame:FindFirstChildWhichIsA("TextButton", true)
end

-- ═══════════════════════════════════════════════
-- 🖱️ DRAGGING & MINIMIZE & HOTKEY
-- ═══════════════════════════════════════════════
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MinBtn.Text = isMinimized and "+" or "—"
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
        Size = isMinimized and UDim2.new(0, 370, 0, 50) or UDim2.new(0, 370, 0, 620)
    }):Play()
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.F9 then
        MainFrame.Visible = not MainFrame.Visible
    end
end)


-- ═══════════════════════════════════════════════
-- 🤝 7. ADVANCED TRADE & SELECTIVE TRANSFER SUITE (V7.1 PRO)
-- ═══════════════════════════════════════════════
local TradeState = nil
local TradeMainFrame = nil

do
    TradeState = {
        IsTradeActive = false,
        Mode = "Sender",            -- "Sender" หรือ "Receiver"
        TargetReceiver = nil,
        SavedReceiverName = "",     -- ชื่อผู้รับที่บันทึกไว้
        CurrentCategory = "All",    -- "All", "Miners", "Pickaxes", "Gems", "Other"
        SelectedItems = {},
        SendAllAlways = true,       -- ⚡ ส่งไอเทมที่เลือกทั้งหมดทุกครั้ง (Auto-Max Always)
        AutoLoopUntilEmpty = true,  -- 🔁 ส่งวนซ้ำอัตโนมัติจนกว่าของที่เลือกจะหมดกระเป๋า
        AutoAccept = true,
        AutoReady = true,
        AutoConfirm = true,
        CurrentSession = nil,
        EditRevision = 0,
    }
    
    local TRADE_CONFIG_FILE = "AnimeMine_TradeConfig.json"
    local SavedTradeItems = {}

    local function SaveTradeConfig(notifyUser)
        pcall(function()
            if writefile then
                local itemsToSave = {}
                for k, v in pairs(TradeState.SelectedItems or {}) do
                    if type(v) == "table" and v.Key then
                        itemsToSave[v.Key] = tonumber(v.Amount) or 1
                    elseif type(v) == "number" then
                        itemsToSave[k] = v
                    end
                end
                local data = {
                    Mode = TradeState.Mode or "Sender",
                    TargetReceiverName = (TradeState.TargetReceiver and TradeState.TargetReceiver.Name) or TradeState.SavedReceiverName or "",
                    AutoAccept = TradeState.AutoAccept,
                    AutoReady = TradeState.AutoReady,
                    AutoConfirm = TradeState.AutoConfirm,
                    CurrentCategory = TradeState.CurrentCategory or "All",
                SendAllAlways = TradeState.SendAllAlways ~= false,
                AutoLoopUntilEmpty = TradeState.AutoLoopUntilEmpty ~= false,
                    SelectedItems = itemsToSave
                }
                writefile(TRADE_CONFIG_FILE, HttpService:JSONEncode(data))
                if notifyUser then
                    TradeNotify("บันทึกสำเร็จ", "บันทึกการตั้งค่าระบบเทรดและไอเทมเรียบร้อยแล้ว", 3)
                end
            end
        end)
    end

    local function LoadTradeConfig()
        pcall(function()
            if isfile and readfile and isfile(TRADE_CONFIG_FILE) then
                local raw = readfile(TRADE_CONFIG_FILE)
                local decoded = HttpService:JSONDecode(raw)
                if type(decoded) == "table" then
                    if decoded.Mode then TradeState.Mode = decoded.Mode end
                    if decoded.TargetReceiverName and #decoded.TargetReceiverName > 0 then
                        TradeState.SavedReceiverName = decoded.TargetReceiverName
                    end
                    if decoded.AutoAccept ~= nil then TradeState.AutoAccept = decoded.AutoAccept end
                    if decoded.AutoReady ~= nil then TradeState.AutoReady = decoded.AutoReady end
                    if decoded.AutoConfirm ~= nil then TradeState.AutoConfirm = decoded.AutoConfirm end
                    if decoded.CurrentCategory then TradeState.CurrentCategory = decoded.CurrentCategory end
                if decoded.SendAllAlways ~= nil then TradeState.SendAllAlways = decoded.SendAllAlways end
                if decoded.AutoLoopUntilEmpty ~= nil then TradeState.AutoLoopUntilEmpty = decoded.AutoLoopUntilEmpty end
                    if type(decoded.SelectedItems) == "table" then
                        SavedTradeItems = decoded.SelectedItems
                    end
                end
            end
        end)
    end

    LoadTradeConfig()
    
    local TradeTimingConfig = {
        ThrottleDelayMin = 0.55,    -- หน่วงเวลาระหว่างส่งไอเทมแต่ละชิ้น (วินาที)
        ThrottleDelayMax = 0.85,    -- หน่วงเวลาขั้นสูงแบบสุ่มเลียนแบบมนุษย์ (วินาที)
        PreReadyDelay    = 1.2,     -- หน่วงเวลาก่อนส่ง MineTradeReady (วินาที)
        ConfirmWaitTime  = 4.5,     -- เวลารอนับถอยหลังของเกมก่อนกดยืนยัน Confirm (วินาที)
        RequestTimeout   = 20.0,    -- เวลารอผู้รับกดยอมรับคำขอเทรด (วินาที)
        MaxStackCap      = 999,     -- เพดานขีดจำกัดสูงสุดต่อ 1 ช่องของเซิร์ฟเวอร์
        MaxGemsCap       = 1000000, -- เพดานอัญมณีสูงสุดต่อ 1 รอบการเทรด (1 ล้าน Gems)
    }
    
    local function TradeNotify(title, msg, duration)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "🤝 " .. title,
                Text = msg,
                Duration = duration or 3
            })
        end)
        print(string.format("[TradeSuite | %s] %s", title, msg))
    end
    
    local function SafeSendEvent(eventName, ...)
        local args = { ... }
        local success, err = pcall(function()
            if GameState and type(GameState.SendEvent) == "function" then
                GameState.SendEvent(eventName, unpack(args))
            else
                error("GameState.SendEvent is invalid")
            end
        end)
        if not success then
            warn(string.format("[TradeSuite] ส่ง Remote '%s' ไม่สำเร็จ: %s", eventName, tostring(err)))
            return false, err
        end
        return true
    end
    
    local function IsReceiverOnline()
        if not TradeState.TargetReceiver then return false end
        return TradeState.TargetReceiver:IsDescendantOf(Players)
    end
    
    -- ตรวจสอบว่าไอเทมสามารถเทรดได้จริงตามกฎของเกมหรือไม่ (Dual-Layer Safe Validator)
    local function CanTradeItem(itemKey)
        if not itemKey or type(itemKey) ~= "string" or #itemKey == 0 then return false end
        if itemKey == "Day" or itemKey == "Count" then return false end
        if itemKey == "Gems" then return true end
    
        -- 1. ตรวจสอบผ่าน MineConfig.TradeStack
        if MineConfig and type(MineConfig.TradeStack) == "function" then
            local stack = MineConfig.TradeStack(itemKey)
            if stack ~= nil then return true end
        end
    
        -- 2. Fallback ตรวจสอบผ่าน Items.GetItemData
        if Items and type(Items.GetItemData) == "function" then
            local cleanName = tostring(itemKey):match("^([^|]+)") or tostring(itemKey)
            local data = Items.GetItemData(cleanName) or Items.GetItemData(itemKey)
            if type(data) == "table" then return true end
        end
    
        return false
    end
    
    -- สแกนไอเทมจริงทั้งหมดในกระเป๋าอย่างละเอียด (รวมอัญมณี หินบัฟ น้ำยา ขวาน และตัวละคร)
    local function FetchOwnedInventory()
        local d2 = GameState.GetData2()
        local mg = d2 and d2.MineGame
        if not mg then return {} end
    
        -- นับจำนวนที่คนขุดสวมใส่ใช้งานอยู่ (Holders)
        local assignedChars = {}
        local assignedPicks = {}
        if type(mg.Holders) == "table" then
            for _, holder in pairs(mg.Holders) do
                if type(holder) == "table" then
                    if holder.Char then
                        assignedChars[holder.Char] = (assignedChars[holder.Char] or 0) + 1
                    end
                    if holder.Pickaxe then
                        assignedPicks[holder.Pickaxe] = (assignedPicks[holder.Pickaxe] or 0) + 1
                    end
                end
            end
        end
    
        local list = {}
    
        -- 1. ตัวละครคนขุด (Miners / Characters)
        if type(mg.Characters) == "table" then
            for charKey, count in pairs(mg.Characters) do
                local total = tonumber(count) or 0
                local inUse = assignedChars[charKey] or 0
                local spare = math.max(0, total - inUse)
                if spare > 0 then
                    local cleanName = tostring(charKey):match("^([^|]+)") or tostring(charKey)
                    if CanTradeItem(charKey) or CanTradeItem(cleanName) then
                        table.insert(list, {
                            Key = charKey,
                            Name = cleanName,
                            Count = spare,
                            Total = total,
                            Kind = "Miners",
                            Category = "Miners",
                            Emoji = "👤",
                            MaxCap = TradeTimingConfig.MaxStackCap
                        })
                    end
                end
            end
        end
    
        -- 2. ขวาน (Pickaxes)
        if type(mg.Pickaxes) == "table" then
            for pickName, count in pairs(mg.Pickaxes) do
                local total = tonumber(count) or 0
                local inUse = assignedPicks[pickName] or 0
                local spare = math.max(0, total - inUse)
                if spare > 0 and CanTradeItem(pickName) then
                    table.insert(list, {
                        Key = pickName,
                        Name = pickName,
                        Count = spare,
                        Total = total,
                        Kind = "Pickaxe",
                        Category = "Pickaxes",
                        Emoji = "⛏️",
                        MaxCap = TradeTimingConfig.MaxStackCap
                    })
                end
            end
        end
    
        -- 3. อัญมณี (💎 Gems Currency)
        local gemCount = 0
        if MineConfig and type(MineConfig.GetGemCount) == "function" then
            gemCount = MineConfig.GetGemCount(mg)
        else
            gemCount = tonumber(mg.Gems) or 0
        end
        if (gemCount > 0 or TradeState.CurrentCategory == "Gems") and CanTradeItem("Gems") then
            table.insert(list, {
                Key = "Gems",
                Name = "Gems (อัญมณี)",
                Count = gemCount,
                Total = gemCount,
                Kind = "Gem",
                Category = "Gems",
                Emoji = "💎",
                MaxCap = TradeTimingConfig.MaxGemsCap
            })
        end
    
        -- 4. ม้วนอัญเชิญ (Summon Scroll) & ลูกเต๋าเวทมนต์ (Enchanted Dice)
        local diceCount = 0
        if MineConfig and type(MineConfig.GetEnchantDiceCount) == "function" then
            diceCount = MineConfig.GetEnchantDiceCount(mg)
        else
            diceCount = tonumber(mg.EnchantDice) or 0
        end
        if diceCount > 0 and CanTradeItem("Enchanted Dice") then
            table.insert(list, {
                Key = "Enchanted Dice",
                Name = "Enchanted Dice",
                Count = diceCount,
                Total = diceCount,
                Kind = "Dice",
                Category = "Other",
                Emoji = "🎲",
                MaxCap = TradeTimingConfig.MaxStackCap
            })
        end
    
        local scrollCount = 0
        if MineConfig and type(MineConfig.GetSummonScrollCount) == "function" then
            scrollCount = MineConfig.GetSummonScrollCount(mg)
        else
            scrollCount = tonumber(mg.SummonScrolls) or 0
        end
        if scrollCount > 0 and CanTradeItem("Summon Scroll") then
            table.insert(list, {
                Key = "Summon Scroll",
                Name = "Summon Scroll",
                Count = scrollCount,
                Total = scrollCount,
                Kind = "Scroll",
                Category = "Other",
                Emoji = "📜",
                MaxCap = TradeTimingConfig.MaxStackCap
            })
        end
    
        -- 5. น้ำยาและเครื่องราง (Potions & Charms)
        if type(mg.Potions) == "table" then
            for potName, count in pairs(mg.Potions) do
                local num = tonumber(count) or 0
                if num > 0 and CanTradeItem(potName) then
                    table.insert(list, {
                        Key = potName,
                        Name = potName,
                        Count = num,
                        Total = num,
                        Kind = "Potion",
                        Category = "Other",
                        Emoji = "🧪",
                        MaxCap = TradeTimingConfig.MaxStackCap
                    })
                end
            end
        end
    
        -- 6. หินบัฟและไอเทมเสริมพลัง (EnchantItems: Glacial, Quaking, Blazing ฯลฯ)
        if type(mg.EnchantItems) == "table" then
            for enchName, count in pairs(mg.EnchantItems) do
                local num = tonumber(count) or 0
                if num > 0 and CanTradeItem(enchName) then
                    table.insert(list, {
                        Key = enchName,
                        Name = enchName,
                        Count = num,
                        Total = num,
                        Kind = "EnchantItem",
                        Category = "Other",
                        Emoji = "✨",
                        MaxCap = TradeTimingConfig.MaxStackCap
                    })
                end
            end
        end
    
        -- 7. อุปกรณ์สวมใส่และของอื่นๆ (GearItems / Staffs)
        if type(mg.GearItems) == "table" then
            for gearName, count in pairs(mg.GearItems) do
                local num = tonumber(count) or 0
                if num > 0 and CanTradeItem(gearName) then
                    table.insert(list, {
                        Key = gearName,
                        Name = gearName,
                        Count = num,
                        Total = num,
                        Kind = "Gear",
                        Category = "Other",
                        Emoji = "🛡️",
                        MaxCap = TradeTimingConfig.MaxStackCap
                    })
                end
            end
        end
    
        table.sort(list, function(a, b) return a.Name < b.Name end)
        return list
    end
    
    -- ========================================================================
    -- 🎨 GUI CREATION (V7.1 Pro UI)
    -- ========================================================================
    local GuiName = "MineTradeSelectiveUI"
    local oldGui = PlayerGui:FindFirstChild(GuiName)
    if oldGui then oldGui:Destroy() end
    
    local TradeScreenGui = Instance.new("ScreenGui")
    TradeScreenGui.Name = GuiName
    TradeScreenGui.ResetOnSpawn = false
    TradeScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    TradeScreenGui.Parent = PlayerGui
    
    TradeMainFrame = Instance.new("Frame")
    TradeMainFrame.Name = "TradeMainFrame"
    TradeMainFrame.Size = UDim2.new(0, 420, 0, 570)
    TradeMainFrame.Position = UDim2.new(0.04, 0, 0.14, 0)
    TradeMainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    TradeMainFrame.BorderSizePixel = 0
    TradeMainFrame.ClipsDescendants = true
    TradeMainFrame.Active = true
    TradeMainFrame.Draggable = true
    TradeMainFrame.Parent = TradeScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = TradeMainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(130, 80, 230)
    MainStroke.Thickness = 1.6
    MainStroke.Parent = TradeMainFrame
    
    -- TradeHeader
    local TradeHeader = Instance.new("Frame")
    TradeHeader.Size = UDim2.new(1, 0, 0, 42)
    TradeHeader.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    TradeHeader.BorderSizePixel = 0
    TradeHeader.Parent = TradeMainFrame
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 10)
    HeaderCorner.Parent = TradeHeader
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🤝 Trade & Selective Transfer V7.1 Pro"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 12.5
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TradeHeader
    
    local TradeMinBtn = Instance.new("TextButton")
    TradeMinBtn.Size = UDim2.new(0, 26, 0, 26)
    TradeMinBtn.Position = UDim2.new(1, -64, 0, 8)
    TradeMinBtn.BackgroundColor3 = Color3.fromRGB(48, 48, 65)
    TradeMinBtn.Text = "—"
    TradeMinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TradeMinBtn.Font = Enum.Font.GothamBold
    TradeMinBtn.TextSize = 13
    TradeMinBtn.Parent = TradeHeader

    local TradeMinCorner = Instance.new("UICorner")
    TradeMinCorner.CornerRadius = UDim.new(0, 6)
    TradeMinCorner.Parent = TradeMinBtn

    local isTradeMinimized = false
    TradeMinBtn.MouseButton1Click:Connect(function()
        isTradeMinimized = not isTradeMinimized
        TradeMinBtn.Text = isTradeMinimized and "+" or "—"
        TweenService:Create(TradeMainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
            Size = isTradeMinimized and UDim2.new(0, 420, 0, 42) or UDim2.new(0, 420, 0, 570)
        }):Play()
    end)

    local TradeCloseBtn = Instance.new("TextButton")
    TradeCloseBtn.Size = UDim2.new(0, 26, 0, 26)
    TradeCloseBtn.Position = UDim2.new(1, -34, 0, 8)
    TradeCloseBtn.BackgroundColor3 = Color3.fromRGB(190, 45, 45)
    TradeCloseBtn.Text = "✕"
    TradeCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TradeCloseBtn.Font = Enum.Font.GothamBold
    TradeCloseBtn.TextSize = 12
    TradeCloseBtn.Parent = TradeHeader
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = TradeCloseBtn
    
    -- Status Bar
    local StatusBar = Instance.new("TextLabel")
    StatusBar.Size = UDim2.new(1, -20, 0, 26)
    StatusBar.Position = UDim2.new(0, 10, 0, 48)
    StatusBar.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
    StatusBar.Text = "💡 สถานะ: พร้อมทำงาน เลือกบทบาทบัญชีเพื่อเริ่มต้น"
    StatusBar.TextColor3 = Color3.fromRGB(150, 220, 160)
    StatusBar.Font = Enum.Font.GothamMedium
    StatusBar.TextSize = 11
    StatusBar.Parent = TradeMainFrame
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(0, 6)
    StatusCorner.Parent = StatusBar
    
    -- Main Scroll Container
    local ScrollContainer = Instance.new("ScrollingFrame")
    ScrollContainer.Size = UDim2.new(1, -20, 1, -88)
    ScrollContainer.Position = UDim2.new(0, 10, 0, 80)
    ScrollContainer.BackgroundTransparency = 1
    ScrollContainer.BorderSizePixel = 0
    ScrollContainer.ScrollBarThickness = 4
    ScrollContainer.ScrollBarImageColor3 = Color3.fromRGB(130, 80, 230)
    ScrollContainer.CanvasSize = UDim2.new(0, 0, 0, 800)
    ScrollContainer.Parent = TradeMainFrame
    
    local ContainerLayout = Instance.new("UIListLayout")
    ContainerLayout.Padding = UDim.new(0, 8)
    ContainerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ContainerLayout.Parent = ScrollContainer
    
    local function CreateHeader(text, order)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(200, 170, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11.5
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order
        lbl.Parent = ScrollContainer
        return lbl
    end
    
    -- ========================================================================
    -- [1] ROLE SELECTION
    -- ========================================================================
    CreateHeader("👤 1. เลือกบทบาทของบัญชีนี้", 1)
    
    local RoleFrame = Instance.new("Frame")
    RoleFrame.Size = UDim2.new(1, 0, 0, 32)
    RoleFrame.BackgroundTransparency = 1
    RoleFrame.LayoutOrder = 2
    RoleFrame.Parent = ScrollContainer
    
    local SenderBtn = Instance.new("TextButton")
    SenderBtn.Size = UDim2.new(0.485, 0, 1, 0)
    SenderBtn.Position = UDim2.new(0, 0, 0, 0)
    SenderBtn.BackgroundColor3 = Color3.fromRGB(110, 65, 200)
    SenderBtn.Text = "📤 โหมดผู้ส่ง (Sender)"
    SenderBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SenderBtn.Font = Enum.Font.GothamBold
    SenderBtn.TextSize = 11
    SenderBtn.Parent = RoleFrame
    
    local SenderCorner = Instance.new("UICorner")
    SenderCorner.CornerRadius = UDim.new(0, 6)
    SenderCorner.Parent = SenderBtn
    
    local ReceiverBtn = Instance.new("TextButton")
    ReceiverBtn.Size = UDim2.new(0.485, 0, 1, 0)
    ReceiverBtn.Position = UDim2.new(0.515, 0, 0, 0)
    ReceiverBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    ReceiverBtn.Text = "📥 โหมดผู้รับ (Receiver)"
    ReceiverBtn.TextColor3 = Color3.fromRGB(190, 190, 205)
    ReceiverBtn.Font = Enum.Font.GothamBold
    ReceiverBtn.TextSize = 11
    ReceiverBtn.Parent = RoleFrame
    
    local ReceiverCorner = Instance.new("UICorner")
    ReceiverCorner.CornerRadius = UDim.new(0, 6)
    ReceiverCorner.Parent = ReceiverBtn
    
    -- ========================================================================
    -- [2] TARGET RECEIVER SELECTION (สำหรับ Sender)
    -- ========================================================================
    local TargetHeader = CreateHeader("🎯 2. เลือกผู้รับเป้าหมาย (Receiver)", 3)
    
    local PlayerSelectFrame = Instance.new("Frame")
    PlayerSelectFrame.Size = UDim2.new(1, 0, 0, 32)
    PlayerSelectFrame.BackgroundTransparency = 1
    PlayerSelectFrame.LayoutOrder = 4
    PlayerSelectFrame.Parent = ScrollContainer
    
    local CurrentPlayerLabel = Instance.new("TextLabel")
    CurrentPlayerLabel.Size = UDim2.new(0.72, 0, 1, 0)
    CurrentPlayerLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    CurrentPlayerLabel.Text = "กำลังค้นหาผู้เล่นในห้อง..."
    CurrentPlayerLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
    CurrentPlayerLabel.Font = Enum.Font.GothamBold
    CurrentPlayerLabel.TextSize = 11
    CurrentPlayerLabel.Parent = PlayerSelectFrame
    
    local CurPlayerCorner = Instance.new("UICorner")
    CurPlayerCorner.CornerRadius = UDim.new(0, 6)
    CurPlayerCorner.Parent = CurrentPlayerLabel
    
    local CyclePlayerBtn = Instance.new("TextButton")
    CyclePlayerBtn.Size = UDim2.new(0.25, 0, 1, 0)
    CyclePlayerBtn.Position = UDim2.new(0.75, 0, 0, 0)
    CyclePlayerBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 85)
    CyclePlayerBtn.Text = "🔄 สลับผู้เล่น"
    CyclePlayerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CyclePlayerBtn.Font = Enum.Font.GothamBold
    CyclePlayerBtn.TextSize = 10.5
    CyclePlayerBtn.Parent = PlayerSelectFrame
    
    local CycleCorner = Instance.new("UICorner")
    CycleCorner.CornerRadius = UDim.new(0, 6)
    CycleCorner.Parent = CyclePlayerBtn
    
    local function GetOtherPlayers()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(list, p)
            end
        end
        return list
    end
    
    local playerIndex = 1
    local function UpdateSelectedPlayer(preferSaved)
        local others = GetOtherPlayers()
        if #others == 0 then
            TradeState.TargetReceiver = nil
            CurrentPlayerLabel.Text = "⚠️ ไม่มีผู้เล่นอื่นในห้อง"
            CurrentPlayerLabel.TextColor3 = Color3.fromRGB(230, 90, 90)
            return
        end
        if preferSaved and TradeState.SavedReceiverName and #TradeState.SavedReceiverName > 0 then
            for idx, p in ipairs(others) do
                if p.Name == TradeState.SavedReceiverName then
                    playerIndex = idx
                    break
                end
            end
        end
        if playerIndex > #others then playerIndex = 1 end
        TradeState.TargetReceiver = others[playerIndex]
        TradeState.SavedReceiverName = TradeState.TargetReceiver and TradeState.TargetReceiver.Name or TradeState.SavedReceiverName
        CurrentPlayerLabel.Text = "👤 " .. TradeState.TargetReceiver.Name
        CurrentPlayerLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
    end
    
    UpdateSelectedPlayer(true)
    
    CyclePlayerBtn.MouseButton1Click:Connect(function()
        local others = GetOtherPlayers()
        if #others > 0 then
            playerIndex = (playerIndex % #others) + 1
            UpdateSelectedPlayer()
            TradeNotify("เปลี่ยนผู้รับ", "เป้าหมายปัจจุบัน: " .. (TradeState.TargetReceiver and TradeState.TargetReceiver.Name or "None"))
            SaveTradeConfig()
        end
    end)
    
    -- Receiver Options
    local ReceiverAutoFrame = Instance.new("Frame")
    ReceiverAutoFrame.Size = UDim2.new(1, 0, 0, 68)
    ReceiverAutoFrame.BackgroundTransparency = 1
    ReceiverAutoFrame.LayoutOrder = 5
    ReceiverAutoFrame.Visible = false
    ReceiverAutoFrame.Parent = ScrollContainer
    
    local ReceiverLayout = Instance.new("UIListLayout")
    ReceiverLayout.Padding = UDim.new(0, 6)
    ReceiverLayout.Parent = ReceiverAutoFrame
    
    local function CreateSmallToggle(parent, titleText, defaultVal, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
        btn.Text = "  " .. titleText
        btn.TextColor3 = Color3.fromRGB(220, 220, 230)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 10.5
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = parent
    
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
    
        local badge = Instance.new("TextLabel")
        badge.Size = UDim2.new(0, 42, 0, 20)
        badge.Position = UDim2.new(1, -48, 0.5, -10)
        badge.BackgroundColor3 = defaultVal and Color3.fromRGB(45, 160, 90) or Color3.fromRGB(65, 65, 80)
        badge.Text = defaultVal and "ON" or "OFF"
        badge.TextColor3 = Color3.fromRGB(255, 255, 255)
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 10
        badge.Parent = btn
    
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 4)
        bCorner.Parent = badge
    
        local val = defaultVal
        btn.MouseButton1Click:Connect(function()
            val = not val
            badge.Text = val and "ON" or "OFF"
            badge.BackgroundColor3 = val and Color3.fromRGB(45, 160, 90) or Color3.fromRGB(65, 65, 80)
            callback(val)
            SaveTradeConfig()
        end)
    end
    
    CreateSmallToggle(ReceiverAutoFrame, "⚡ Auto Accept ตอบรับคำขอเทรดทันที", true, function(v) TradeState.AutoAccept = v end)
    CreateSmallToggle(ReceiverAutoFrame, "⚡ Auto Ready & Confirm ยินยอมรับของอัตโนมัติ", true, function(v) TradeState.AutoReady = v TradeState.AutoConfirm = v end)
    
    local function SetRole(mode, skipSave)
        TradeState.Mode = mode or "Sender"
        if TradeState.Mode == "Sender" then
            SenderBtn.BackgroundColor3 = Color3.fromRGB(110, 65, 200)
            SenderBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            ReceiverBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
            ReceiverBtn.TextColor3 = Color3.fromRGB(190, 190, 205)
            PlayerSelectFrame.Visible = true
            TargetHeader.Visible = true
            ReceiverAutoFrame.Visible = false
            StatusBar.Text = "โหมดผู้ส่ง: เลือกผู้รับและติ๊กไอเทมที่จะส่ง"
        else
            ReceiverBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 90)
            ReceiverBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            SenderBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
            SenderBtn.TextColor3 = Color3.fromRGB(190, 190, 205)
            PlayerSelectFrame.Visible = false
            TargetHeader.Visible = false
            ReceiverAutoFrame.Visible = true
            StatusBar.Text = "โหมดผู้รับ: รอรับคำขอเทรดและยืนยันอัตโนมัติ"
        end
        if not skipSave then
            SaveTradeConfig()
        end
    end

    SenderBtn.MouseButton1Click:Connect(function()
        SetRole("Sender")
    end)
    
    ReceiverBtn.MouseButton1Click:Connect(function()
        SetRole("Receiver")
    end)

    SetRole(TradeState.Mode, true)
    
    -- ========================================================================
    -- [3] SELECTIVE ITEM TRANSFER (รวมอัญมณี 💎 Gems)
    -- ========================================================================
    CreateHeader("🎒 3. เลือกไอเทม/อัญมณีที่จะส่ง (สูงสุด 8 กองต่อรอบ)", 6)
    
    local FilterFrame = Instance.new("Frame")
    FilterFrame.Size = UDim2.new(1, 0, 0, 26)
    FilterFrame.BackgroundTransparency = 1
    FilterFrame.LayoutOrder = 7
    FilterFrame.Parent = ScrollContainer
    
    local FilterLayout = Instance.new("UIListLayout")
    FilterLayout.FillDirection = Enum.FillDirection.Horizontal
    FilterLayout.Padding = UDim.new(0, 3)
    FilterLayout.Parent = FilterFrame
    
    local ItemCountLabel = Instance.new("TextLabel")
    ItemCountLabel.Size = UDim2.new(1, 0, 0, 18)
    ItemCountLabel.BackgroundTransparency = 1
    ItemCountLabel.Text = "เลือกแล้ว: 0 / 8 กอง"
    ItemCountLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
    ItemCountLabel.Font = Enum.Font.GothamMedium
    ItemCountLabel.TextSize = 11
    ItemCountLabel.TextXAlignment = Enum.TextXAlignment.Left
    ItemCountLabel.LayoutOrder = 8
    ItemCountLabel.Parent = ScrollContainer
    
    local ItemScrollBox = Instance.new("ScrollingFrame")
    ItemScrollBox.Size = UDim2.new(1, 0, 0, 190)
    ItemScrollBox.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    ItemScrollBox.ScrollBarThickness = 3
    ItemScrollBox.ScrollBarImageColor3 = Color3.fromRGB(130, 80, 230)
    ItemScrollBox.LayoutOrder = 9
    ItemScrollBox.Parent = ScrollContainer
    
    local ItemScrollCorner = Instance.new("UICorner")
    ItemScrollCorner.CornerRadius = UDim.new(0, 8)
    ItemScrollCorner.Parent = ItemScrollBox
    
    local ItemListLayout = Instance.new("UIListLayout")
    ItemListLayout.Padding = UDim.new(0, 4)
    ItemListLayout.Parent = ItemScrollBox
    
    local function CountSelected()
        local c = 0
        for _ in pairs(TradeState.SelectedItems) do c = c + 1 end
        return c
    end
    
    local RenderInventoryList
    
    local function CreateTabBtn(name, cat)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.192, -2, 1, 0)
        btn.BackgroundColor3 = TradeState.CurrentCategory == cat and Color3.fromRGB(110, 65, 200) or Color3.fromRGB(36, 36, 48)
        btn.Text = name
        btn.TextColor3 = Color3.fromRGB(240, 240, 245)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9.5
        btn.Parent = FilterFrame
    
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = btn
    
        btn.MouseButton1Click:Connect(function()
            TradeState.CurrentCategory = cat
            SaveTradeConfig()
            for _, b in ipairs(FilterFrame:GetChildren()) do
                if b:IsA("TextButton") then
                    b.BackgroundColor3 = Color3.fromRGB(36, 36, 48)
                end
            end
            btn.BackgroundColor3 = Color3.fromRGB(110, 65, 200)
            RenderInventoryList()
        end)
    end
    
    CreateTabBtn("ทั้งหมด", "All")
    CreateTabBtn("👤 คนขุด", "Miners")
    CreateTabBtn("⛏️ ขวาน", "Pickaxes")
    CreateTabBtn("💎 อัญมณี", "Gems")
    CreateTabBtn("🧪 อื่นๆ", "Other")
    
    RenderInventoryList = function()
        for _, child in ipairs(ItemScrollBox:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
    
        local rawItems = FetchOwnedInventory()
        local items = {}
    
        for _, it in ipairs(rawItems) do
            if TradeState.CurrentCategory == "All" or it.Category == TradeState.CurrentCategory then
                table.insert(items, it)
            end
        end
    
        ItemScrollBox.CanvasSize = UDim2.new(0, 0, 0, #items * 34 + 10)
    
        for _, it in ipairs(items) do
            -- คืนค่าไอเทมและจำนวนที่เคยบันทึกไว้ใน Config อัตโนมัติ
            local maxAllowed = math.min(it.Count, it.MaxCap or TradeTimingConfig.MaxStackCap)
            if SavedTradeItems and SavedTradeItems[it.Key] and CountSelected() < 8 and it.Count > 0 and not TradeState.SelectedItems[it.Key] then
                local savedAmt = TradeState.SendAllAlways and maxAllowed or math.clamp(tonumber(SavedTradeItems[it.Key]) or 1, 1, math.max(1, maxAllowed))
                TradeState.SelectedItems[it.Key] = {
                    Key = it.Key,
                    Name = it.Name,
                    Amount = savedAmt,
                    MaxCount = maxAllowed,
                    MaxCap = it.MaxCap or TradeTimingConfig.MaxStackCap
                }
            end

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -6, 0, 30)
            row.Position = UDim2.new(0, 3, 0, 0)
            row.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
            row.Parent = ItemScrollBox
    
            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 6)
            rowCorner.Parent = row
    
            -- Checkbox
            local checkBtn = Instance.new("TextButton")
            checkBtn.Size = UDim2.new(0, 20, 0, 20)
            checkBtn.Position = UDim2.new(0, 6, 0.5, -10)
            checkBtn.BackgroundColor3 = TradeState.SelectedItems[it.Key] and Color3.fromRGB(45, 170, 95) or Color3.fromRGB(50, 50, 65)
            checkBtn.Text = TradeState.SelectedItems[it.Key] and "✓" or ""
            checkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            checkBtn.Font = Enum.Font.GothamBold
            checkBtn.TextSize = 11
            checkBtn.Parent = row
    
            local checkCorner = Instance.new("UICorner")
            checkCorner.CornerRadius = UDim.new(0, 4)
            checkCorner.Parent = checkBtn
    
            -- Item Title & Count
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -145, 1, 0)
            nameLbl.Position = UDim2.new(0, 32, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = string.format("%s %s (มี %d)", it.Emoji or "📦", it.Name, it.Count)
            nameLbl.TextColor3 = Color3.fromRGB(235, 235, 240)
            nameLbl.Font = Enum.Font.GothamMedium
            nameLbl.TextSize = 10.5
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = row
    
            -- Amount Box
            local maxAllowed = math.min(it.Count, it.MaxCap or TradeTimingConfig.MaxStackCap)
            local amtBox = Instance.new("TextBox")
            amtBox.Size = UDim2.new(0, 55, 0, 20)
            amtBox.Position = UDim2.new(1, -95, 0.5, -10)
            amtBox.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
            amtBox.TextColor3 = Color3.fromRGB(240, 200, 90)
            amtBox.Font = Enum.Font.GothamBold
            amtBox.TextSize = 10
            amtBox.Text = tostring((TradeState.SelectedItems[it.Key] and TradeState.SelectedItems[it.Key].Amount) or (maxAllowed > 0 and 1 or 0))
            amtBox.ClearTextOnFocus = false
            amtBox.Parent = row
    
            local amtCorner = Instance.new("UICorner")
            amtCorner.CornerRadius = UDim.new(0, 4)
            amtCorner.Parent = amtBox
    
            local function SyncAmount()
                local num = tonumber(amtBox.Text)
                if num then
                    local clamped = math.clamp(math.floor(num), 1, math.max(1, maxAllowed))
                    if TradeState.SelectedItems[it.Key] then
                        TradeState.SelectedItems[it.Key].Amount = clamped
                    end
                end
            end
    
            amtBox:GetPropertyChangedSignal("Text"):Connect(SyncAmount)
    
            amtBox.FocusLost:Connect(function()
                local num = tonumber(amtBox.Text) or 1
                num = math.clamp(math.floor(num), 1, math.max(1, maxAllowed))
                amtBox.Text = tostring(num)
                if TradeState.SelectedItems[it.Key] then
                    TradeState.SelectedItems[it.Key].Amount = num
                    SavedTradeItems[it.Key] = num
                    SaveTradeConfig()
                end
            end)
    
            -- Max Button
            local maxBtn = Instance.new("TextButton")
            maxBtn.Size = UDim2.new(0, 28, 0, 20)
            maxBtn.Position = UDim2.new(1, -34, 0.5, -10)
            maxBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            maxBtn.Text = "Max"
            maxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            maxBtn.Font = Enum.Font.GothamBold
            maxBtn.TextSize = 9
            maxBtn.Parent = row
    
            local maxCorner = Instance.new("UICorner")
            maxCorner.CornerRadius = UDim.new(0, 4)
            maxCorner.Parent = maxBtn
    
            maxBtn.MouseButton1Click:Connect(function()
                local maxVal = math.max(1, maxAllowed)
                amtBox.Text = tostring(maxVal)
                if TradeState.SelectedItems[it.Key] then
                    TradeState.SelectedItems[it.Key].Amount = maxVal
                    SavedTradeItems[it.Key] = maxVal
                    SaveTradeConfig()
                end
            end)
    
            checkBtn.MouseButton1Click:Connect(function()
                if TradeState.SelectedItems[it.Key] then
                    TradeState.SelectedItems[it.Key] = nil
                    SavedTradeItems[it.Key] = nil
                    SaveTradeConfig()
                    checkBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
                    checkBtn.Text = ""
                else
                    if it.Count <= 0 then
                        TradeNotify("ไม่มีไอเทม", "ไอเทมนี้มีจำนวนเป็น 0 ไม่สามารถเลือกได้ครับ", 2)
                        return
                    end
                    if CountSelected() >= 8 then
                        TradeNotify("ขีดจำกัดไอเทม", "สามารถเลือกส่งได้สูงสุด 8 กองต่อครั้งครับ", 3)
                        return
                    end
                    local sendNum = TradeState.SendAllAlways and maxAllowed or (tonumber(amtBox.Text) or maxAllowed)
                    sendNum = math.clamp(sendNum, 1, maxAllowed)
                    TradeState.SelectedItems[it.Key] = {
                        Key = it.Key,
                        Name = it.Name,
                        Amount = sendNum,
                        MaxCount = maxAllowed,
                        MaxCap = it.MaxCap or TradeTimingConfig.MaxStackCap
                    }
                    SavedTradeItems[it.Key] = sendNum
                    SaveTradeConfig()
                    checkBtn.BackgroundColor3 = Color3.fromRGB(45, 170, 95)
                    checkBtn.Text = "✓"
                end
                local curCount = CountSelected()
                ItemCountLabel.Text = string.format("เลือกแล้ว: %d / 8 กอง", curCount)
                ItemCountLabel.TextColor3 = curCount > 0 and Color3.fromRGB(120, 230, 160) or Color3.fromRGB(160, 160, 180)
            end)
        end
    end
    
    RenderInventoryList()
    
    local RefreshInvBtn = Instance.new("TextButton")
    RefreshInvBtn.Size = UDim2.new(1, 0, 0, 26)
    RefreshInvBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    RefreshInvBtn.Text = "🔄 รีเฟรชคลังไอเทม (Refresh Inventory)"
    RefreshInvBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
    RefreshInvBtn.Font = Enum.Font.GothamSemibold
    RefreshInvBtn.TextSize = 10.5
    RefreshInvBtn.LayoutOrder = 10
    RefreshInvBtn.Parent = ScrollContainer
    
    local RefCorner = Instance.new("UICorner")
    RefCorner.CornerRadius = UDim.new(0, 6)
    RefCorner.Parent = RefreshInvBtn
    
    RefreshInvBtn.MouseButton1Click:Connect(function()
        RenderInventoryList()
        TradeNotify("รีเฟรชคลัง", "อัปเดตรายการไอเทมในกระเป๋าเรียบร้อย")
    end)
    
    -- ========================================================================
    -- [4] ACTIONS & TRADE EXECUTION
    -- ========================================================================
    CreateHeader("⚡ 4. คำสั่งเปิด-ปิดการเทรด (Trade Controls)", 11)
    
    local TradeToggleFrame = Instance.new("Frame")
    TradeToggleFrame.Size = UDim2.new(1, 0, 0, 32)
    TradeToggleFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    TradeToggleFrame.LayoutOrder = 12
    TradeToggleFrame.Parent = ScrollContainer
    
    local ToggleFrameCorner = Instance.new("UICorner")
    ToggleFrameCorner.CornerRadius = UDim.new(0, 6)
    ToggleFrameCorner.Parent = TradeToggleFrame
    
    local ToggleLabel = Instance.new("TextLabel")
    ToggleLabel.Size = UDim2.new(1, -70, 1, 0)
    ToggleLabel.Position = UDim2.new(0, 10, 0, 0)
    ToggleLabel.BackgroundTransparency = 1
    ToggleLabel.Text = "🔄 สวิตช์เปิด-ปิดระบบเทรด (Toggle Trade)"
    ToggleLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
    ToggleLabel.Font = Enum.Font.GothamMedium
    ToggleLabel.TextSize = 11
    ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    ToggleLabel.Parent = TradeToggleFrame
    
    local TradeSwitchBadge = Instance.new("TextButton")
    TradeSwitchBadge.Size = UDim2.new(0, 52, 0, 22)
    TradeSwitchBadge.Position = UDim2.new(1, -58, 0.5, -11)
    TradeSwitchBadge.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
    TradeSwitchBadge.Text = "OFF"
    TradeSwitchBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
    TradeSwitchBadge.Font = Enum.Font.GothamBold
    TradeSwitchBadge.TextSize = 10.5
    TradeSwitchBadge.Parent = TradeToggleFrame
    
    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(0, 4)
    SwitchCorner.Parent = TradeSwitchBadge

    local SendAllToggleFrame = Instance.new("Frame")
    SendAllToggleFrame.Size = UDim2.new(1, 0, 0, 58)
    SendAllToggleFrame.BackgroundTransparency = 1
    SendAllToggleFrame.LayoutOrder = 13
    SendAllToggleFrame.Parent = ScrollContainer

    local SendAllLayout = Instance.new("UIListLayout")
    SendAllLayout.Padding = UDim.new(0, 4)
    SendAllLayout.Parent = SendAllToggleFrame

    CreateSmallToggle(SendAllToggleFrame, "⚡ ส่งของที่เลือกทั้งหมดทุกครั้ง (Send Max Always)", TradeState.SendAllAlways, function(v)
        TradeState.SendAllAlways = v
        SaveTradeConfig()
        RenderInventoryList()
    end)

    CreateSmallToggle(SendAllToggleFrame, "🔁 ส่งวนซ้ำจนกว่าของจะหมดกระเป๋า (Auto-Loop)", TradeState.AutoLoopUntilEmpty, function(v)
        TradeState.AutoLoopUntilEmpty = v
        SaveTradeConfig()
    end)

    local StartTradeBtn = Instance.new("TextButton")
    StartTradeBtn.Size = UDim2.new(1, 0, 0, 36)
    StartTradeBtn.BackgroundColor3 = Color3.fromRGB(110, 65, 200)
    StartTradeBtn.Text = "🚀 เปิด/เริ่มส่งไอเทมที่เลือก (Start Transfer)"
    StartTradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    StartTradeBtn.Font = Enum.Font.GothamBold
    StartTradeBtn.TextSize = 12
    StartTradeBtn.LayoutOrder = 14
    StartTradeBtn.Parent = ScrollContainer
    
    local StartCorner = Instance.new("UICorner")
    StartCorner.CornerRadius = UDim.new(0, 8)
    StartCorner.Parent = StartTradeBtn
    
    local CancelTradeBtn = Instance.new("TextButton")
    CancelTradeBtn.Size = UDim2.new(1, 0, 0, 28)
    CancelTradeBtn.BackgroundColor3 = Color3.fromRGB(160, 45, 45)
    CancelTradeBtn.Text = "❌ ยกเลิกการเทรดทันที (Cancel Trade)"
    CancelTradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CancelTradeBtn.Font = Enum.Font.GothamBold
    CancelTradeBtn.TextSize = 11
    CancelTradeBtn.LayoutOrder = 15
    CancelTradeBtn.Parent = ScrollContainer
    
    local CancelCorner = Instance.new("UICorner")
    CancelCorner.CornerRadius = UDim.new(0, 6)
    CancelCorner.Parent = CancelTradeBtn

    local SaveConfigBtn = Instance.new("TextButton")
    SaveConfigBtn.Size = UDim2.new(1, 0, 0, 26)
    SaveConfigBtn.BackgroundColor3 = Color3.fromRGB(38, 55, 80)
    SaveConfigBtn.Text = "💾 บันทึกการตั้งค่าเทรด (Save Trade Config)"
    SaveConfigBtn.TextColor3 = Color3.fromRGB(200, 230, 255)
    SaveConfigBtn.Font = Enum.Font.GothamSemibold
    SaveConfigBtn.TextSize = 10.5
    SaveConfigBtn.LayoutOrder = 16
    SaveConfigBtn.Parent = ScrollContainer
    
    local SaveCorner = Instance.new("UICorner")
    SaveCorner.CornerRadius = UDim.new(0, 6)
    SaveCorner.Parent = SaveConfigBtn

    SaveConfigBtn.MouseButton1Click:Connect(function()
        SaveTradeConfig(true)
    end)
    
    -- ========================================================================
    -- 🔄 BACKGROUND AUTOMATION & WATCHDOG ENGINE
    -- ========================================================================
    
    -- ฟังก์ชันช่วยคลิกปุ่มบนหน้าต่างเทรดจริงของเกม
    local function ClickTradeButtonUI()
        pcall(function()
            local mineGui = PlayerGui:FindFirstChild("MineGui")
            local tradeFrame = mineGui and mineGui:FindFirstChild("TradeFrame")
            if tradeFrame then
                for _, desc in ipairs(tradeFrame:GetDescendants()) do
                    if desc.Name == "ReadyButton" and desc:IsA("GuiButton") then
                        pcall(function()
                            if getconnections then
                                for _, conn in ipairs(getconnections(desc.Activated)) do
                                    conn:Fire()
                                end
                            end
                        end)
                        pcall(function()
                            if firesignal then
                                firesignal(desc.Activated)
                            end
                        end)
                    end
                end
            end
        end)
    end
    
    -- ฟังก์ชันช่วยคลิกปุ่มยอมรับคำขอเทรดที่เด้งขึ้นมาบนหน้าจอจริง
    local function CheckAndAutoAcceptUI()
        pcall(function()
            local mineGui = PlayerGui:FindFirstChild("MineGui")
            local reqFrame = mineGui and mineGui:FindFirstChild("TradeRequestFrame")
            if reqFrame and reqFrame.Visible then
                local acceptBtn = reqFrame:FindFirstChild("AcceptButton", true)
                if acceptBtn and acceptBtn:IsA("GuiButton") then
                    pcall(function()
                        if getconnections then
                            for _, conn in ipairs(getconnections(acceptBtn.Activated)) do
                                conn:Fire()
                            end
                        end
                    end)
                    pcall(function()
                        if firesignal then
                            firesignal(acceptBtn.Activated)
                        end
                    end)
                end
            end
        end)
    end
    
    local function AbortTransfer(reason)
        TradeState.IsTradeActive = false
        SafeSendEvent("MineTradeCancel")
        TradeState.CurrentSession = nil
        TradeState.EditRevision = 0
        UpdateTradeUIState(false)
        StatusBar.Text = "⚠️ " .. tostring(reason)
        StatusBar.TextColor3 = Color3.fromRGB(240, 100, 100)
        TradeNotify("Trade Aborted", reason, 4)
    end
    
    -- รับการซิงค์ข้อมูล Snapshot ของเซสชันเทรด
    pcall(function()
        GameState.ListenToEvent("MineTradeSync", function(snapshot)
            if type(snapshot) ~= "table" or type(snapshot.SessionId) ~= "number" then return end
            TradeState.CurrentSession = snapshot
        end)
    end)
    
    -- Auto Accept คำขอเทรดผ่าน Remote สำหรับ Receiver
    pcall(function()
        GameState.ListenToEvent("MineTradeShowRequest", function(senderName, senderId, requestId)
            if TradeState.Mode == "Receiver" and TradeState.AutoAccept and requestId then
                TradeNotify("Auto Accept", "ยอมรับคำขอเทรดจาก: " .. tostring(senderName))
                task.wait(0.2)
                SafeSendEvent("MineTradeRespond", true, requestId)
            end
        end)
    end)
    
    -- 🛡️ Receiver Watchdog Loop: ตรวจจับและยืนยันการเทรดแบบ Real-time ตลอดเวลา
    task.spawn(function()
        while true do
            task.wait(0.4)
            if TradeState.Mode == "Receiver" then
                -- 1. ตรวจจับและกดยอมรับหน้าต่าง Trade Request ที่เด้งมา
                if TradeState.AutoAccept then
                    CheckAndAutoAcceptUI()
                end
    
                -- 2. เมื่ออยู่ในเซสชันการเทรด
                if TradeState.CurrentSession and type(TradeState.CurrentSession.SessionId) == "number" then
                    local sess = TradeState.CurrentSession
                    local stage = sess.Stage or "negotiate"
    
                    if stage == "closed" or stage == "saving" then
                        StatusBar.Text = "✅ ได้รับของและการเทรดสำเร็จเรียบร้อย"
                        StatusBar.TextColor3 = Color3.fromRGB(120, 230, 160)
                    elseif stage == "negotiate" and TradeState.AutoReady then
                        -- ฝั่งรับจะกด Ready เมื่อฝั่งผู้ส่ง (ThemReady) วางของเสร็จและกด Ready แล้วเท่านั้น!
                        if sess.ThemReady and not sess.MeReady then
                            StatusBar.Text = "⚡ ฝั่งส่งวางของพร้อมแล้ว ฝั่งรับกด Ready ยินยอม..."
                            StatusBar.TextColor3 = Color3.fromRGB(240, 200, 90)
                            SafeSendEvent("MineTradeReady", true, sess.SessionId, sess.Revision)
                            ClickTradeButtonUI()
                        elseif not sess.ThemReady then
                            StatusBar.Text = "⏳ ฝั่งรับกำลังรอฝั่งผู้ส่งวางไอเทม..."
                            StatusBar.TextColor3 = Color3.fromRGB(160, 200, 240)
                        end
                    elseif stage == "confirm" and TradeState.AutoConfirm then
                        -- เมื่อเข้าสู่ช่วง Confirm และสถานะยังไม่เป็น MeConfirmed
                        if not sess.MeConfirmed then
                            StatusBar.Text = "⚡ ฝั่งรับส่งคำสั่ง Confirm ยินยอมรับของ..."
                            StatusBar.TextColor3 = Color3.fromRGB(120, 240, 160)
                            SafeSendEvent("MineTradeConfirm", sess.SessionId, sess.Revision)
                            ClickTradeButtonUI()
                        else
                            StatusBar.Text = "✅ ฝั่งรับยินยอมเรียบร้อย (Confirmed)"
                            StatusBar.TextColor3 = Color3.fromRGB(120, 230, 160)
                        end
                    end
                end
            end
        end
    end)
    
    -- Main Transfer Worker (สำหรับ Sender)
    local function GetAvailableCountMap()
        local list = FetchOwnedInventory()
        local map = {}
        for _, it in ipairs(list) do
            map[it.Key] = it.Count
        end
        return map
    end

        local function RunTransferWorker()
        if not TradeState.TargetReceiver then
            AbortTransfer("กรุณาเลือกผู้รับเป้าหมายก่อน")
            return
        end

        local roundCount = 0

        while TradeState.IsTradeActive do
            roundCount = roundCount + 1

            -- ตรวจสอบคลังไอเทมจริงล่าสุด ณ ปัจจุบัน
            local ownedMap = GetAvailableCountMap()
            local itemsToSendList = {}

            for key, item in pairs(TradeState.SelectedItems) do
                local currentAvailable = ownedMap[key] or 0
                if currentAvailable > 0 then
                    local cap = item.MaxCap or TradeTimingConfig.MaxStackCap
                    -- ⚡ ส่งไอเทมที่เลือกทั้งหมดทุกครั้ง: คำนวณจำนวนส่งเป็นจำนวนทั้งหมดที่มีจริงในคลัง (ไม่เกิน Cap)
                    local sendAmount = TradeState.SendAllAlways and math.min(currentAvailable, cap) or math.min(item.Amount, currentAvailable, cap)
                    if sendAmount > 0 then
                        table.insert(itemsToSendList, {
                            Key = key,
                            Name = item.Name,
                            Amount = sendAmount,
                            MaxCap = cap
                        })
                        if #itemsToSendList >= 8 then break end -- ขีดจำกัด 8 ช่องต่อรอบของเกม
                    end
                end
            end

            if #itemsToSendList == 0 then
                if roundCount > 1 then
                    TradeNotify("ส่งครบ 100%", "ส่งไอเทมที่เลือกทั้งหมดทุกชิ้นเรียบร้อยแล้ว (ของหมดกระเป๋า)!")
                    StatusBar.Text = "✅ ส่งไอเทมที่เลือกทั้งหมดทุกชิ้นเรียบร้อย (ของหมดกระเป๋า)"
                else
                    AbortTransfer("ไม่พบไอเทมที่เลือกในกระเป๋า หรือจำนวนเป็น 0")
                end
                StatusBar.TextColor3 = Color3.fromRGB(120, 230, 160)
                TradeState.IsTradeActive = false
                UpdateTradeUIState(false)
                RenderInventoryList()
                break
            end

            StatusBar.Text = string.format("⏳ [รอบที่ %d] กำลังส่งคำขอเทรดไปยัง: %s", roundCount, TradeState.TargetReceiver.Name)
            StatusBar.TextColor3 = Color3.fromRGB(240, 200, 90)
            TradeNotify("เริ่มส่งไอเทม", string.format("รอบที่ %d: ส่งของ %d รายการไปยัง %s", roundCount, #itemsToSendList, TradeState.TargetReceiver.Name))

            -- 1. ยิงคำขอเทรด
            SafeSendEvent("MineTradeRequest", TradeState.TargetReceiver.UserId)

            -- 2. รอตอบรับจนกว่า Session จะ Active
            local elapsed = 0
            while TradeState.IsTradeActive and (not TradeState.CurrentSession or TradeState.CurrentSession.Stage == "saving" or TradeState.CurrentSession.Stage == "closed") do
                if not IsReceiverOnline() then
                    AbortTransfer("ผู้รับเป้าหมายหลุดออกจากเซิร์ฟเวอร์")
                    return
                end
                task.wait(0.5)
                elapsed = elapsed + 0.5
                if elapsed >= TradeTimingConfig.RequestTimeout then
                    AbortTransfer("หมดเวลารอ (Timeout 20s) ผู้รับไม่ตอบรับคำขอ")
                    return
                end
            end

            if not TradeState.IsTradeActive or not TradeState.CurrentSession then return end

            local sess = TradeState.CurrentSession
            TradeState.EditRevision = 0

            -- 3. วนลูปส่งไอเทมทีละชิ้น (Network Rate Limiting + Safe Cap)
            for idx, item in ipairs(itemsToSendList) do
                if not TradeState.IsTradeActive then
                    AbortTransfer("ผู้ใช้กดยกเลิกการทำงาน")
                    return
                end

                if not IsReceiverOnline() then
                    AbortTransfer("ผู้รับหลุดออกจากเซิร์ฟเวอร์ขณะกำลังส่งไอเทม")
                    return
                end

                local cap = item.MaxCap or TradeTimingConfig.MaxStackCap
                local sendAmount = math.clamp(item.Amount, 1, cap)
                TradeState.EditRevision = math.max(TradeState.EditRevision, tonumber(TradeState.CurrentSession and TradeState.CurrentSession.LastEditId) or 0) + 1

                StatusBar.Text = string.format("ใส่ไอเทม [%d/%d]: %s x%d", idx, #itemsToSendList, item.Name, sendAmount)
                StatusBar.TextColor3 = Color3.fromRGB(240, 220, 100)

                SafeSendEvent("MineTradeSetItem", item.Key, sendAmount, sess.SessionId, TradeState.EditRevision)

                local jitter = math.random(TradeTimingConfig.ThrottleDelayMin * 100, TradeTimingConfig.ThrottleDelayMax * 100) / 100
                task.wait(jitter)
            end

            -- 4. ส่งไอเทมครบทุกชิ้นก่อน -> หน่วงเวลาให้เซิร์ฟเวอร์ซิงค์ข้อมูล
            StatusBar.Text = string.format("⏱️ ส่งไอเทมครบแล้ว หน่วงเวลา %.1f วินาทีก่อน Ready...", TradeTimingConfig.PreReadyDelay)
            StatusBar.TextColor3 = Color3.fromRGB(130, 200, 255)
            task.wait(TradeTimingConfig.PreReadyDelay)

            if not TradeState.IsTradeActive or not IsReceiverOnline() then
                AbortTransfer("ยกเลิกหรือผู้รับหลุดก่อนกด Ready")
                return
            end

            -- 5a. ส่งคำสั่ง MineTradeReady จนกว่า MeReady จะเป็น true
            local readyRetries = 0
            while TradeState.IsTradeActive and TradeState.CurrentSession and TradeState.CurrentSession.Stage == "negotiate" and not TradeState.CurrentSession.MeReady and readyRetries < 8 do
                local curRev = TradeState.CurrentSession.Revision or TradeState.EditRevision
                StatusBar.Text = string.format("⚡ กดยืนยัน Ready (Rev: %d)...", curRev)
                SafeSendEvent("MineTradeReady", true, TradeState.CurrentSession.SessionId, curRev)
                ClickTradeButtonUI()
                readyRetries = readyRetries + 1
                task.wait(0.6)
            end

            -- 5b. รอนจนกว่า Stage จะเปลี่ยนเป็น "confirm"
            StatusBar.Text = "⏳ ฝั่งผู้ส่งพร้อมแล้ว กำลังรอฝ่ายรับกดยินยอม Ready..."
            StatusBar.TextColor3 = Color3.fromRGB(240, 200, 90)
            local waitStageElapsed = 0
            while TradeState.IsTradeActive and TradeState.CurrentSession and TradeState.CurrentSession.Stage == "negotiate" do
                if not IsReceiverOnline() then
                    AbortTransfer("ผู้รับหลุดออกจากเซิร์ฟเวอร์ขณะรอ Ready")
                    return
                end
                if not TradeState.CurrentSession.MeReady then
                    SafeSendEvent("MineTradeReady", true, TradeState.CurrentSession.SessionId, TradeState.CurrentSession.Revision or TradeState.EditRevision)
                    ClickTradeButtonUI()
                end
                task.wait(0.5)
                waitStageElapsed = waitStageElapsed + 0.5
                if waitStageElapsed >= 25 then
                    AbortTransfer("หมดเวลารอ (Timeout 25s) ฝ่ายรับไม่ยอมกด Ready")
                    return
                end
            end

            if not TradeState.IsTradeActive or not TradeState.CurrentSession or TradeState.CurrentSession.Stage ~= "confirm" then
                if TradeState.CurrentSession and (TradeState.CurrentSession.Stage == "saving" or TradeState.CurrentSession.Stage == "closed") then
                    -- สำเร็จทันที
                else
                    AbortTransfer("การเทรดถูกยกเลิกหรือไม่สามารถเข้าสู่ช่วงยืนยันได้")
                    return
                end
            end

            -- 6. หน่วงเวลานับถอยหลัง Confirm Countdown
            local countdown = math.max(4.5, (tonumber(TradeState.CurrentSession and TradeState.CurrentSession.ConfirmAfter) or 4.0) + 0.5)
            for t = math.ceil(countdown), 1, -1 do
                if not TradeState.IsTradeActive or not IsReceiverOnline() then
                    AbortTransfer("ยกเลิกหรือผู้รับหลุดก่อนกด Confirm")
                    return
                end
                StatusBar.Text = string.format("⏳ รอนับถอยหลังยืนยันครั้งสุดท้าย (%d วิ)...", t)
                StatusBar.TextColor3 = Color3.fromRGB(255, 180, 80)
                task.wait(1.0)
            end

            if not TradeState.IsTradeActive or not IsReceiverOnline() then
                AbortTransfer("ยกเลิกหรือผู้รับหลุดก่อนกด Confirm")
                return
            end

            -- 7. วนส่ง MineTradeConfirm
            local confirmRetries = 0
            while TradeState.IsTradeActive and TradeState.CurrentSession and TradeState.CurrentSession.Stage == "confirm" and not TradeState.CurrentSession.MeConfirmed and confirmRetries < 15 do
                local curRev = TradeState.CurrentSession.Revision or TradeState.EditRevision
                StatusBar.Text = string.format("⚡ กดยืนยัน Confirm แลกเปลี่ยน (%d/15)...", confirmRetries + 1)
                StatusBar.TextColor3 = Color3.fromRGB(120, 240, 160)
                SafeSendEvent("MineTradeConfirm", TradeState.CurrentSession.SessionId, curRev)
                ClickTradeButtonUI()
                confirmRetries = confirmRetries + 1
                task.wait(0.6)
            end

            -- 8. รอรับผลลัพธ์การบันทึกข้อมูล
            local saveWait = 0
            while TradeState.IsTradeActive and TradeState.CurrentSession and TradeState.CurrentSession.Stage == "confirm" and saveWait < 8 do
                task.wait(0.5)
                saveWait = saveWait + 0.5
            end

            -- ตรวจสอบว่าต้องวนลูปส่งต่อจนกว่าของจะหมดหรือไม่
            if not TradeState.AutoLoopUntilEmpty then
                TradeNotify("สำเร็จ", "ส่งไอเทมรอบนี้ครบถ้วนเรียบร้อยแล้ว!")
                StatusBar.Text = "✅ การโอนย้ายไอเทมเสร็จสมบูรณ์"
                StatusBar.TextColor3 = Color3.fromRGB(120, 230, 160)
                TradeState.IsTradeActive = false
                UpdateTradeUIState(false)
                RenderInventoryList()
                break
            end

            -- ถ้าเปิด AutoLoopUntilEmpty: เช็คว่ายังมีของที่เลือกเหลือในคลังหรือไม่
            local nextOwnedMap = GetAvailableCountMap()
            local remainingItemsCount = 0
            for key, _ in pairs(TradeState.SelectedItems) do
                remainingItemsCount = remainingItemsCount + (nextOwnedMap[key] or 0)
            end

            if remainingItemsCount <= 0 then
                TradeNotify("ส่งครบ 100%", "ส่งไอเทมที่เลือกทั้งหมดทุกชิ้นเรียบร้อยแล้ว (ของหมดกระเป๋า)!")
                StatusBar.Text = "✅ ส่งไอเทมที่เลือกทั้งหมดเรียบร้อย (ของหมดกระเป๋า)"
                StatusBar.TextColor3 = Color3.fromRGB(120, 230, 160)
                TradeState.IsTradeActive = false
                UpdateTradeUIState(false)
                RenderInventoryList()
                break
            else
                StatusBar.Text = string.format("🔄 รอบที่ %d สำเร็จ! กำลังเตรียมส่งรอบถัดไปสำหรับของที่เหลือ (%d ชิ้น)...", roundCount, remainingItemsCount)
                StatusBar.TextColor3 = Color3.fromRGB(140, 200, 255)
                RenderInventoryList()
                task.wait(3.0)
            end
        end
    end
    
    local function UpdateTradeUIState(isActive)
        if TradeSwitchBadge then
            TradeSwitchBadge.Text = isActive and "ON" or "OFF"
            TradeSwitchBadge.BackgroundColor3 = isActive and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(65, 65, 80)
        end
        if StartTradeBtn then
            StartTradeBtn.BackgroundColor3 = isActive and Color3.fromRGB(190, 45, 45) or Color3.fromRGB(110, 65, 200)
            StartTradeBtn.Text = isActive and "⏹️ ปิด/หยุดการส่งไอเทม (STOP)" or "🚀 เปิด/เริ่มส่งไอเทมที่เลือก (Start Transfer)"
        end
        if TradeMainToggleBtn then
            TradeMainToggleBtn.Text = isActive and "⏹️ เปิด (ON)" or "🚀 ปิด (OFF)"
            TradeMainToggleBtn.BackgroundColor3 = isActive and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(50, 50, 70)
        end
    end

    local function ToggleTrade(state)
        if state == nil then
            TradeState.IsTradeActive = not TradeState.IsTradeActive
        else
            TradeState.IsTradeActive = state
        end

        UpdateTradeUIState(TradeState.IsTradeActive)

        if TradeState.IsTradeActive then
            if TradeState.Mode ~= "Sender" then
                TradeNotify("แจ้งเตือน", "กรุณาสลับเป็น 'โหมดผู้ส่ง (Sender)' เพื่อเริ่มส่งของ", 3)
                TradeState.IsTradeActive = false
                UpdateTradeUIState(false)
                return false
            end
            task.spawn(RunTransferWorker)
        else
            AbortTransfer("ผู้ใช้สั่งปิด/หยุดการทำงาน")
        end
        return TradeState.IsTradeActive
    end

    TradeSwitchBadge.MouseButton1Click:Connect(function()
        ToggleTrade()
    end)
    
    StartTradeBtn.MouseButton1Click:Connect(function()
        ToggleTrade()
    end)
    
    CancelTradeBtn.MouseButton1Click:Connect(function()
        ToggleTrade(false)
    end)
    
    TradeCloseBtn.MouseButton1Click:Connect(function()
        ToggleTrade(false)
        TradeMainFrame.Visible = false
    end)
    
    _G.ToggleTrade = ToggleTrade
    _G.IsTradeActive = function() return TradeState.IsTradeActive end
    
    TradeNotify("Trade Suite V7.1 Pro", "หน้าต่างควบคุมการเทรด V7.1 Pro พร้อมใช้งานแล้ว!", 3)
    
end

-- ═══════════════════════════════════════════════
-- 🚀 4. MASTER WORKER PIPELINE (ISOLATED TASKS WITH PCALL)
-- ═══════════════════════════════════════════════
local lastEquipTime = 0

task.spawn(function()
    while true do
        -- ⏸️ PAUSE WHILE TRADING: หากกำลังเทรดหรือเปิดเซสชันเทรดอยู่ ให้หยุดการทำงานฟาร์มชั่วคราว
        if TradeState and (TradeState.IsTradeActive or (TradeState.CurrentSession and TradeState.CurrentSession.Stage and TradeState.CurrentSession.Stage ~= "closed" and TradeState.CurrentSession.Stage ~= "saving")) then
            UpdateStatus("🤝 หยุดฟาร์มชั่วคราว (กำลังเทรดไอเทม)...")
            task.wait(1.0)
            continue
        end
        local myPlot = GetMyPlot()
        local d = SafeGetData()
        local d2 = SafeGetData2()
        local mg = d2 and d2.MineGame
        local myMoney = d and tonumber(d.Money) or 0
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        -- -------------------------------------------------------------
        -- [TASK 1] เก็บของ (Auto Take Chest)
        -- -------------------------------------------------------------
        local ok1, err1 = pcall(function()
            if Config.AutoChest then
                d2 = SafeGetData2()
                mg = d2 and d2.MineGame
                local chest = mg and mg.Chest
                if chest and next(chest) ~= nil then
                    UpdateStatus("📦 ดูดแร่จากหีบ...")
                    SafeSendEvent(Config.Events.TakeChest)
                    HumanWait(0.2, 0.35)
                end
            end
        end)
        if not ok1 then
            warn(string.format("⚠️ [Worker Task 1 Error - AutoChest] %s", tostring(err1)))
        end

        -- -------------------------------------------------------------
        -- [TASK 2] ขายของ (Auto Sell ที่ร้านค้า SellStand)
        -- ขายแร่ในกระเป๋า + ขายตัวละครในโซนเก่าทิ้ง (เก็บตัวละครโซนปัจจุบันไว้ 100%)
        -- -------------------------------------------------------------
        local ok2, err2 = pcall(function()
            d2 = SafeGetData2()
            mg = d2 and d2.MineGame
            local ores = mg and mg.Ores
            local hasOres = ores and next(ores) ~= nil
            local oldCharKeys = Config.AutoSellOldChars and GetOldZoneCharacterKeys(mg) or {}
            local hasOldChars = #oldCharKeys > 0
            local shouldSell = hasOres or hasOldChars
            local didTravel = false
            local returnPlotCFrame = GetPlotReturnCFrame(myPlot)

            if (Config.AutoSell or Config.AutoSellOldChars) and shouldSell and char then
                local sellStand = workspace:FindFirstChild("SellStand")
                if not sellStand then
                    warn("⚠️ [Null-Safety] ไม่พบ 'SellStand' ใน workspace ข้ามขั้นตอนการขาย")
                else
                    didTravel = true
                    local sellStatusText = "💰 วาร์ปไปร้านขายแร่"
                    if hasOldChars then
                        sellStatusText = sellStatusText .. string.format(" + ขายตัวละครโซนเก่า (%d ชุด)...", #oldCharKeys)
                    else
                        sellStatusText = sellStatusText .. "..."
                    end
                    UpdateStatus(sellStatusText)
                    char:PivotTo(sellStand:GetPivot() + Vector3.new(0, 3, 5))
                    HumanWait(0.35, 0.5)

                    local sellKeys = {}
                    if Config.AutoSell and hasOres then
                        for k in pairs(ores) do
                            table.insert(sellKeys, k)
                        end
                    end
                    if Config.AutoSellOldChars and hasOldChars then
                        for _, k in ipairs(oldCharKeys) do
                            table.insert(sellKeys, k)
                        end
                    end

                    if #sellKeys > 0 then
                        SafeSendEvent(Config.Events.SellItems, sellKeys)
                        HumanWait(0.35, 0.5)
                    end

                    d = SafeGetData()
                    myMoney = d and tonumber(d.Money) or 0
                end
            end

            -- หากมีการวาร์ปออกไป ให้วาร์ปกลับแปลง
            if didTravel and char and returnPlotCFrame then
                char:PivotTo(returnPlotCFrame)
                HumanWait(0.25, 0.4)
                UpdateStatus("🏠 กลับถึงแปลงขุด")
            end
        end)
        if not ok2 then
            warn(string.format("⚠️ [Worker Task 2 Error - AutoSell] %s", tostring(err2)))
        end

        -- -------------------------------------------------------------
        -- [TASK 3] อัปเกรดต้นไม้ (Zone Skill Tree & Core Upgrades)
        -- -------------------------------------------------------------
        local ok3, err3 = pcall(function()
            d = SafeGetData()
            d2 = SafeGetData2()
            mg = d2 and d2.MineGame
            myMoney = d and tonumber(d.Money) or 0

            -- 3.1 สกิลต้นไม้ประจำโซน (Batch Upgrade สูงสุด 5 โหนดต่อรอบ)
            if Config.AutoUpgradeTree and mg and MineConfig then
                local curZone = mg.CurrentZone or 1
                local zoneKey = "Z" .. tostring(curZone)
                local zSkills = (mg.Skills and mg.Skills[zoneKey]) or {}

                local nodes = MineConfig.GetSkillNodes and MineConfig.GetSkillNodes(zoneKey)
                if nodes then
                    local upgradedCount = 0
                    for _, node in ipairs(nodes) do
                        local isOpen = MineConfig.IsSkillNodeOpen and MineConfig.IsSkillNodeOpen(zSkills, node)
                        local isMaxed = MineConfig.IsSkillNodeMaxed and MineConfig.IsSkillNodeMaxed(zSkills, node)
                        local curLvl = zSkills[node.Family] or 0
                        local cost = MineConfig.GetSkillCost and MineConfig.GetSkillCost(zoneKey, curLvl, node.Family)

                        local curMoney = tonumber(SafeGetData().Money) or 0
                        if isOpen and not isMaxed and cost and curMoney >= cost then
                            SafeSendEvent(Config.Events.SkillTreeSection, zoneKey)
                            UpdateStatus("🌳 อัปต้นไม้: " .. (node.Name or node.Id or "Node"))
                            SafeSendEvent(Config.Events.BuySkill, zoneKey, node.Family, node.Id)
                            upgradedCount = upgradedCount + 1
                            HumanWait(0.12, 0.18)
                            if upgradedCount >= 5 then break end
                        end
                    end
                end
            end

            -- 3.2 สกิลแกนหลัก
            if Config.AutoUpgradeCore and mg and MineConfig then
                for _, cNode in ipairs(MineConfig.CoreNodes or {}) do
                    local isOpen = MineConfig.IsCoreNodeOpen and MineConfig.IsCoreNodeOpen(mg, cNode)
                    local isMaxed = MineConfig.IsCoreNodeMaxed and MineConfig.IsCoreNodeMaxed(mg, cNode)
                    if isOpen and not isMaxed then
                        local upDef = MineConfig.CoreUpgradeById and MineConfig.CoreUpgradeById[cNode.Family]
                        if upDef and upDef.Cost and upDef.Event then
                            local cost = upDef.Cost(mg[upDef.Field])
                            local curMoney = tonumber(SafeGetData().Money) or 0
                            if cost and curMoney >= cost then
                                UpdateStatus("⚙️ อัปแกนหลัก: " .. (cNode.Name or cNode.Id or "Core"))
                                SafeSendEvent(upDef.Event)
                                HumanWait(0.2, 0.35)
                                break
                            end
                        end
                    end
                end
            end
        end)
        if not ok3 then
            warn(string.format("⚠️ [Worker Task 3 Error - AutoUpgradeTree] %s", tostring(err3)))
        end

        -- -------------------------------------------------------------
        -- [TASK 4] ซื้อขวานที่ดีที่สุดและออโต้สวมใส่ (Auto Buy & Equip Pickaxe)
        -- -------------------------------------------------------------
        local ok4, err4 = pcall(function()
            if Config.AutoBuyBestPickaxe and mg and MineConfig then
                d = SafeGetData()
                d2 = SafeGetData2()
                mg = d2 and d2.MineGame
                myMoney = d and tonumber(d.Money) or 0

                -- 4.1 ค้นหาขวานที่ดีที่สุดในร้านค้าที่ปลดล็อกแล้ว มีสต็อก และมีเงินพอซื้อ
                if MineConfig.Pickaxes then
                    local bestPick = nil
                    local bestPickIdx = nil
                    local bestMult = -1

                    for idx, pick in ipairs(MineConfig.Pickaxes) do
                        if not (MineConfig.IsPickaxeFree and MineConfig.IsPickaxeFree(pick)) and not pick.RobuxOnly then
                            local cost = tonumber(pick.Cost) or (1 / 0)
                            local mult = tonumber(pick.Multiplier) or 1
                            local isZoneUnlocked = not pick.ZoneReq or (mg.UnlockedZones and mg.UnlockedZones[pick.ZoneReq])
                            local stock = MineStock and MineStock.GetRemaining and MineStock.GetRemaining(d2, pick.Name) or 0

                            if isZoneUnlocked and myMoney >= cost and stock > 0 then
                                if mult > bestMult then
                                    bestMult = mult
                                    bestPick = pick
                                    bestPickIdx = idx
                                end
                            end
                        end
                    end

                    -- ซื้อขวานที่ดีที่สุดทันทีเมื่อพร้อม (ไม่จำกัดจำนวน)
                    if bestPick and bestPickIdx then
                        local curMoney = tonumber(SafeGetData().Money) or 0
                        local cost = tonumber(bestPick.Cost) or (1 / 0)
                        local stock = MineStock and MineStock.GetRemaining and MineStock.GetRemaining(d2, bestPick.Name) or 0
                        local ownedCount = tonumber(mg.Pickaxes and mg.Pickaxes[bestPick.Name]) or 0

                        if curMoney >= cost and stock > 0 then
                            UpdateStatus(string.format("🪓 ซื้อขวาน: %s (มีแล้ว %d ชิ้น)", bestPick.Name, ownedCount))
                            SafeSendEvent(Config.Events.BuyPickaxe, bestPickIdx)
                            myMoney = myMoney - cost
                            HumanWait(0.2, 0.35)
                        end
                    end
                end

                -- 4.2 จัดสรรและสวมใส่ขวานที่ดีที่สุดให้คนงานทั้งหมดโดยอัตโนมัติ
                local sortedHolders = {}
                for slotKey, h in pairs(mg.Holders or {}) do
                    if h and h.CharName then
                        table.insert(sortedHolders, {
                            slot = slotKey,
                            charName = h.CharName,
                            baseDmg = GetCharBaseDamage(h.CharName),
                            currentPick = h.Pickaxe
                        })
                    end
                end
                table.sort(sortedHolders, function(a, b) return a.baseDmg > b.baseDmg end)

                if #sortedHolders > 0 and MineConfig.Pickaxes then
                    d2 = SafeGetData2()
                    mg = d2 and d2.MineGame

                    local availablePicks = {}
                    for pName, count in pairs(mg and mg.Pickaxes or {}) do
                        local countNum = tonumber(count) or 0
                        local pDef = nil
                        for _, p in ipairs(MineConfig.Pickaxes) do
                            if p.Name == pName then pDef = p break end
                        end
                        if pDef and countNum > 0 then
                            for i = 1, countNum do
                                table.insert(availablePicks, {
                                    name = pName,
                                    mult = tonumber(pDef.Multiplier) or 1
                                })
                            end
                        end
                    end
                    table.sort(availablePicks, function(a, b) return a.mult > b.mult end)

                    -- สวมใส่ให้คนงานตามลำดับความแรงของตัวละคร
                    for i, h in ipairs(sortedHolders) do
                        local target = availablePicks[i]
                        if target then
                            local cur = mg.Holders[h.slot] and mg.Holders[h.slot].Pickaxe
                            if cur ~= target.name then
                                SafeSendEvent(Config.Events.EquipPickaxe, h.slot, target.name)
                                HumanWait(0.08, 0.12)
                            end
                        end
                    end
                end
            end
        end)
        if not ok4 then
            warn(string.format("⚠️ [Worker Task 4 Error - AutoPickaxe] %s", tostring(err4)))
        end

        -- -------------------------------------------------------------
        -- [TASK 5] อัปเกรดสถิติ (จัดลำดับจาก Base DMG Lv.1 มากที่สุดเสมอ)
        -- -------------------------------------------------------------
        local ok5, err5 = pcall(function()
            if Config.AutoUpgradeAllChars and mg and mg.Holders and Items and MineConfig then
                local sortedHolders = {}
                for slotKey, h in pairs(mg.Holders) do
                    if h and h.CharName then
                        table.insert(sortedHolders, {
                            slot = slotKey,
                            holder = h,
                            name = h.CharName,
                            baseDmg = GetCharBaseDamage(h.CharName)
                        })
                    end
                end

                table.sort(sortedHolders, function(a, b) return a.baseDmg > b.baseDmg end)

                for _, charInfo in ipairs(sortedHolders) do
                    local slotKey = charInfo.slot
                    local h = charInfo.holder
                    local item = Items.GetItemData(h.CharName)
                    if item then
                        -- 1. Damage Upgrade Check (รองรับ 1-200)
                        local curLvl = h.CharLevel or 1
                        local targetLvl = math.clamp(tonumber(Config.TargetLevelDamage) or 200, 1, 200)
                        if curLvl < targetLvl then
                            local cost = MineConfig.GetCharacterUpgradeCost and MineConfig.GetCharacterUpgradeCost(curLvl, item)
                            local curMoney = tonumber(SafeGetData().Money) or 0
                            if cost and curMoney >= cost then
                                UpdateStatus(string.format("⚔️ อัป DMG %s [%s]", slotKey, FormatNumber(charInfo.baseDmg)))
                                SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "Damage")
                                HumanWait(0.08, 0.15)
                            end
                        end

                        -- 2. Speed Upgrade Check
                        local curSpd = h.CharSpeedLevel or 1
                        local targetSpd = math.min(Config.TargetLevelSpeed, MineConfig.CharSpeedMaxLevel or 17)
                        if curSpd < targetSpd then
                            local cost = MineConfig.GetCharacterSpeedUpgradeCost and MineConfig.GetCharacterSpeedUpgradeCost(curSpd, item)
                            local curMoney = tonumber(SafeGetData().Money) or 0
                            if cost and curMoney >= cost then
                                UpdateStatus("⚡ อัป Speed " .. slotKey)
                                SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "Speed")
                                HumanWait(0.08, 0.15)
                            end
                        end

                        -- 3. MineSpeed Upgrade Check
                        local curMineSpd = h.CharMineSpeedLevel or 1
                        local targetMineSpd = math.min(Config.TargetLevelMineSpeed, MineConfig.CharMineSpeedMaxLevel or 16)
                        if curMineSpd < targetMineSpd then
                            local cost = MineConfig.GetCharacterMineSpeedUpgradeCost and MineConfig.GetCharacterMineSpeedUpgradeCost(curMineSpd, item)
                            local curMoney = tonumber(SafeGetData().Money) or 0
                            if cost and curMoney >= cost then
                                UpdateStatus("⛏️ อัป MineSpeed " .. slotKey)
                                SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "MineSpeed")
                                HumanWait(0.08, 0.15)
                            end
                        end
                    end
                end
            end
        end)
        if not ok5 then
            warn(string.format("⚠️ [Worker Task 5 Error - AutoUpgradeStats] %s", tostring(err5)))
        end

        -- -------------------------------------------------------------
        -- [TASK 6] สุ่มการกลายพันธุ์ (Auto Mutation)
        -- -------------------------------------------------------------
        local ok6, err6 = pcall(function()
            if Config.AutoMutation and mg and mg.Holders and Items and MineConfig then
                local pendingSlots = {}
                local lockedCount = 0
                local totalSelected = 0

                for slotKey, isSelected in pairs(Config.MutationSlots) do
                    if isSelected then
                        local h = mg.Holders[slotKey]
                        if h and h.CharName then
                            totalSelected = totalSelected + 1
                            local curVariant = h.CharVariant or "Normal"
                            if Config.TargetMutations[curVariant] then
                                lockedCount = lockedCount + 1
                            else
                                table.insert(pendingSlots, {
                                    slot = slotKey,
                                    name = h.CharName,
                                    variant = curVariant,
                                    baseDmg = GetCharBaseDamage(h.CharName)
                                })
                            end
                        end
                    end
                end

                table.sort(pendingSlots, function(a, b) return a.baseDmg > b.baseDmg end)

                if totalSelected == 0 then
                    -- ยังไม่ได้เลือกแท่นใดๆ
                elseif #pendingSlots == 0 then
                    UpdateStatus(string.format("🎉 ได้บัพครบแล้ว (%d/%d) [สแตนด์บาย]", lockedCount, totalSelected))
                else
                    local currentTarget = pendingSlots[1]
                    local item = Items.GetItemData(currentTarget.name)
                    local mutCost = item and MineConfig.GetMutationRollCost and MineConfig.GetMutationRollCost(item, mg)
                    local curMoney = tonumber(SafeGetData().Money) or 0

                    if mutCost and curMoney >= mutCost then
                        for r = 1, 3 do
                            curMoney = tonumber(SafeGetData().Money) or 0
                            if not Config.AutoMutation or curMoney < mutCost then break end

                            UpdateStatus(string.format("🧬 สุ่ม %s [Base: %s]", currentTarget.slot, FormatNumber(currentTarget.baseDmg)))
                            SafeSendEvent(Config.Events.RollMutation, currentTarget.slot)
                            HumanWait(0.22, 0.3)

                            local postD2 = SafeGetData2()
                            local postH = postD2 and postD2.MineGame and postD2.MineGame.Holders and postD2.MineGame.Holders[currentTarget.slot]
                            local newVariant = postH and (postH.CharVariant or "Normal")
                            if newVariant and Config.TargetMutations[newVariant] then
                                UpdateStatus(string.format("🔒 ล็อค %s ได้ %s! สุ่มตัวถัดไป...", currentTarget.slot, newVariant))
                                SaveConfig()
                                HumanWait(0.3, 0.5)
                                break
                            end
                        end
                    else
                        local needMore = (mutCost and curMoney) and (mutCost - curMoney) or 0
                        if needMore > 0 then
                            UpdateStatus(string.format("⏳ รอเงินสุ่มบัพ (ขาดอีก %s)", FormatNumber(needMore)))
                        else
                            UpdateStatus("⏳ รอเงินเพื่อสุ่มบัพ...")
                        end
                    end
                end
            end
        end)
        if not ok6 then
            warn(string.format("⚠️ [Worker Task 6 Error - AutoMutation] %s", tostring(err6)))
        end

        -- -------------------------------------------------------------
        -- [TASK 7] สุ่มลูกเต๋าเวทมนต์ (Auto Roll Dice)
        -- -------------------------------------------------------------
        local ok7, err7 = pcall(function()
            if Config.AutoRollDice and mg then
                local isEnchantUnlocked = MineEnchantCatalog and MineEnchantCatalog.Unlocked and MineEnchantCatalog.Unlocked(mg)
                if isEnchantUnlocked then
                    local hwDice = (mg and mg.HalloweenDice) or 0
                    local normalDice = (MineConfig and MineConfig.GetEnchantDiceCount and MineConfig.GetEnchantDiceCount(mg)) or (mg and mg.EnchantDice) or 0

                    if hwDice > 0 then
                        local rollCount = math.clamp(hwDice, 1, 5)
                        UpdateStatus(string.format("🎲 ทอยลูกเต๋า Halloween (%d ลูก)...", rollCount))
                        SafeSendEvent(Config.Events.RollEnchant, rollCount, "Halloween")
                        HumanWait(0.3, 0.45)
                    elseif normalDice > 0 then
                        local rollCount = math.clamp(normalDice, 1, 5)
                        UpdateStatus(string.format("🎲 ทอยลูกเต๋า Enchant (%d ลูก)...", rollCount))
                        SafeSendEvent(Config.Events.RollEnchant, rollCount, nil)
                        HumanWait(0.3, 0.45)
                    end
                end
            end
        end)
        if not ok7 then
            warn(string.format("⚠️ [Worker Task 7 Error - AutoRollDice] %s", tostring(err7)))
        end

        -- -------------------------------------------------------------
        -- [TASK 8] สุ่มม้วนอัญเชิญ (Auto Summon Scrolls)
        -- -------------------------------------------------------------
        local ok8, err8 = pcall(function()
            if Config.AutoSummonScrolls and mg then
                local isSummonUnlocked = MineSummonCatalog and MineSummonCatalog.Unlocked and MineSummonCatalog.Unlocked(mg)
                if isSummonUnlocked then
                    local scrollCount = (MineConfig and MineConfig.GetSummonScrollCount and MineConfig.GetSummonScrollCount(mg)) or (mg and mg.SummonScrolls) or 0
                    if scrollCount > 0 then
                        local rollCount = math.clamp(scrollCount, 1, 10)
                        UpdateStatus(string.format("📜 สุ่มม้วนอัญเชิญ (%d ม้วน)...", rollCount))
                        SafeSendEvent(Config.Events.Summon, rollCount)
                        HumanWait(0.3, 0.45)
                    end
                end
            end
        end)
        if not ok8 then
            warn(string.format("⚠️ [Worker Task 8 Error - AutoSummon] %s", tostring(err8)))
        end

        -- -------------------------------------------------------------
        -- [TASK 9] รับรางวัลอัตโนมัติ (Index & Event Board)
        -- -------------------------------------------------------------
        local ok9, err9 = pcall(function()
            -- 9.1 รับรางวัลในดัชนี (MineIndexClaim)
            if Config.AutoClaimIndex and mg and MineIndexRewardsConfig and MineIndexRewardsConfig.Enabled then
                local heldNames = MineIndexRewardsConfig.HeldNames(mg)
                for _, catKey in ipairs(MineIndexRewardsConfig.Keys()) do
                    local state = MineIndexRewardsConfig.State(mg, catKey, heldNames)
                    for _, tier in ipairs(state.Track or {}) do
                        if tier.Reached and not tier.Claimed then
                            for rIdx, rDef in ipairs(tier.Rewards or {}) do
                                local rIds = MineIndexRewardsConfig.RewardIds({rDef})
                                local rId = rIds and rIds[1]
                                local isClaimed = tier.ClaimedRewards and (tier.ClaimedRewards[rId] or 0) > 0
                                if not isClaimed then
                                    UpdateStatus(string.format("📖 รับรางวัล Index: %s T%s#%d", catKey, tostring(tier.Index or tier.Key), rIdx))
                                    SafeSendEvent(Config.Events.IndexClaim, catKey, tier.Key, rIdx)
                                    HumanWait(0.35, 0.5)
                                end
                            end
                        end
                    end
                end
            end

            -- 9.2 รับรางวัลในบอร์ดอีเว้น (MineEventsClaim)
            if Config.AutoClaimEvents and MineEventsConfig then
                if not latestEventsPayload or os.clock() - lastEventRequestTime > 30 then
                    lastEventRequestTime = os.clock()
                    SafeSendEvent(Config.Events.EventsOpen)
                    HumanWait(0.35, 0.5)
                end

                if latestEventsPayload and latestEventsPayload.Events then
                    local function CheckAndClaimLadder(ladderObj)
                        if not ladderObj or not ladderObj.Thresholds then return end
                        local pts = tonumber(ladderObj.Points) or 0
                        local thresholds = ladderObj.Thresholds or {}
                        local claimed = ladderObj.Claimed or {}
                        local got = ladderObj.Got or {}

                        for tIdx, targetPts in ipairs(thresholds) do
                            if pts >= targetPts and not claimed[tIdx] then
                                local tiers = (ladderObj.IsPersonal and MineEventsConfig.PersonalTiers and MineEventsConfig.PersonalTiers() or (ladderObj.Days and ladderObj.Key and MineEventsConfig.Catalog and MineEventsConfig.Catalog[ladderObj.Key] and MineEventsConfig.Tiers and MineEventsConfig.Tiers(ladderObj.Days, MineEventsConfig.Catalog[ladderObj.Key])))
                                local tDef = tiers and tiers[tIdx]
                                local rList = tDef and tDef.Rewards or {}
                                local shownList = MineEventsConfig.Shown and MineEventsConfig.Shown(rList) or rList

                                for rIdx, rItem in ipairs(shownList) do
                                    local actualIdx = table.find(rList, rItem) or rIdx
                                    local gotMask = type(got) == "table" and (tonumber(got[tIdx]) or 0) or 0
                                    local isGot = (gotMask > 0 and bit32.btest(gotMask, 2 ^ (actualIdx - 1))) or claimed[tIdx] == true

                                    if not isGot then
                                        UpdateStatus(string.format("🏆 รับรางวัล Event: %s T%d#%d", tostring(ladderObj.Key or ladderObj.Id), tIdx, actualIdx))
                                        SafeSendEvent(Config.Events.EventsClaim, ladderObj.Id, tIdx, actualIdx)
                                        HumanWait(0.35, 0.5)
                                    end
                                end
                            end
                        end
                    end

                    for _, ev in ipairs(latestEventsPayload.Events or {}) do
                        CheckAndClaimLadder(ev)
                        if ev.Personal and MineEventsConfig.PersonalOn and MineEventsConfig.PersonalOn() then
                            CheckAndClaimLadder(ev.Personal)
                        end
                    end
                end
            end
        end)
        if not ok9 then
            warn(string.format("⚠️ [Worker Task 9 Error - AutoClaimRewards] %s", tostring(err9)))
        end

        -- -------------------------------------------------------------
        -- [TASK 10] ทดสอบอินฟินิตี้ (Infinity Trial: ตรวจสอบความพร้อม, รับรางวัล, เริ่มลงทดสอบ)
        -- ทำงานเฉพาะเมื่อรางวัลรีเซ็ตและมีรางวัลให้รับเท่านั้น (ไม่ลงซ้ำหากเคลมครบแล้วหรือติด Cooldown)
        -- -------------------------------------------------------------
        local ok10, err10 = pcall(function()
            if Config.AutoInfinityTrial and mg and MineTrialConfig then
                local isUnlocked = MineTrialConfig.Unlocked and MineTrialConfig.Unlocked(mg)
                if isUnlocked then
                    local trialData = (mg.Trial and type(mg.Trial) == "table" and mg.Trial) or {}

                    -- 10.1 ตรวจสอบและเคลมรางวัลที่ผ่านเกณฑ์ (Claimable Tiers)
                    local claimable = MineTrialConfig.ClaimableTiers and MineTrialConfig.ClaimableTiers(trialData)
                    if claimable and #claimable > 0 then
                        for _, tierIdx in ipairs(claimable) do
                            UpdateStatus(string.format("🏆 รับรางวัล Infinity Trial T%d...", tierIdx))
                            SafeSendEvent(Config.Events.TrialClaim, tierIdx)
                            HumanWait(0.35, 0.5)
                        end
                        -- รีเฟรชข้อมูลหลังรับรางวัล
                        d2 = SafeGetData2()
                        mg = d2 and d2.MineGame
                        trialData = (mg and mg.Trial and type(mg.Trial) == "table" and mg.Trial) or {}
                    end

                    -- 10.2 ตรวจสอบว่ารางวัลสำหรับวันนี้เคลมครบทุกเทียร์แล้วหรือไม่
                    local status = GetTrialRewardStatus(trialData)
                    if status.allClaimed then
                        -- รางวัลสำหรับวันนี้เคลมครบหมดแล้ว (อยู่ในช่วง Cooldown รอรีเซ็ตวันถัดไป)
                        -- ไม่ส่งคำสั่งลงทดสอบเด็ดขาดตามเงื่อนไขของผู้ใช้
                        return
                    end

                    -- 10.3 ตรวจสอบสถานะการทดสอบปัจจุบัน
                    local attempt = trialData.Attempt
                    local now = os.time()
                    local isRunning = type(attempt) == "table" and (tonumber(attempt.EndsAt) or 0) > now

                    if not isRunning then
                        UpdateStatus(string.format("⚔️ ลงทดสอบอินฟินิตี้ (รางวัลค้าง %d/%d)...", status.totalTiers - status.claimedCount, status.totalTiers))
                        SafeSendEvent(Config.Events.TrialStart)
                        HumanWait(0.4, 0.6)
                    end
                end
            end
        end)
        if not ok10 then
            warn(string.format("⚠️ [Worker Task 10 Error - InfinityTrial] %s", tostring(err10)))
        end

        -- -------------------------------------------------------------
        -- [TASK 11] เปิด Petalfall Crate (เปิดกล่องในคลังอัตโนมัติ)
        -- -------------------------------------------------------------
        local ok11, err11 = pcall(function()
            if Config.AutoOpenPetalfallCrate and mg then
                local cc = mg.ColossusCrates
                local count = cc and (tonumber(cc["Petalfall Crate"]) or 0) or 0
                if count > 0 then
                    local openAmount = math.clamp(count, 1, 50)
                    UpdateStatus(string.format("🌸 เปิด Petalfall Crate (%d/%d กล่อง)...", openAmount, count))
                    SafeSendEvent(Config.Events.OpenColossusCrate, "Petalfall Crate", openAmount)
                    HumanWait(0.4, 0.6)
                    d2 = SafeGetData2()
                    mg = d2 and d2.MineGame
                end
            end
        end)
        if not ok11 then
            warn(string.format("⚠️ [Worker Task 11 Error - PetalfallCrate] %s", tostring(err11)))
        end

        -- -------------------------------------------------------------
        -- [TASK 12] อื่นๆ (ตีหินในแปลงรวมหินอินฟินิตี้, ซื้อโซน, สวมใส่ตัวดีที่สุด)
        -- -------------------------------------------------------------
        local ok12, err12 = pcall(function()
            -- 12.1 ตีหินในแปลง (ให้ความสำคัญกับหิน Infinity Trial ก่อนหากมี)
            if Config.AutoMine and myPlot then
                local nodesFolder = myPlot:FindFirstChild("Nodes")
                if nodesFolder then
                    for hit = 1, 10 do
                        if not Config.AutoMine then break end

                        local targetNode = nil
                        -- ตรวจหาหิน Infinity Trial ก่อนเป็นอันดับแรก
                        for _, node in ipairs(nodesFolder:GetChildren()) do
                            if node:GetAttribute("MineTrial") == true or node:GetAttribute("RaidId") ~= nil or node.Name:find("Trial") or node.Name:find("Infinity") then
                                local hp = node:GetAttribute("NodeHP")
                                if hp and hp > 0 then
                                    targetNode = node
                                    break
                                end
                            end
                        end
                        -- หากไม่มีหิน Trial ให้ขุดหินแร่ตามปกติ
                        if not targetNode then
                            for _, node in ipairs(nodesFolder:GetChildren()) do
                                local hp = node:GetAttribute("NodeHP")
                                if hp and hp > 0 then
                                    targetNode = node
                                    break
                                end
                            end
                        end

                        if targetNode then
                            UpdateStatus("⛏️ ขุด " .. targetNode.Name)
                            local cd = targetNode:FindFirstChildWhichIsA("ClickDetector", true)
                            if cd and fireclickdetector then
                                fireclickdetector(cd)
                            end
                            HumanWait(0.06, 0.12)
                        else
                            break
                        end
                    end
                end
            end

            -- 12.2 ซื้อโซนใหม่ที่ ZoneBoard
            if Config.AutoBuyZone and myPlot then
                local zb = myPlot:FindFirstChild("ZoneBoard")
                if zb then
                    local gui = zb:FindFirstChild("ZoneBoardGui")
                    local root = gui and gui:FindFirstChild("Root")
                    local list = root and root:FindFirstChild("List")

                    if list then
                        for _, item in ipairs(list:GetChildren()) do
                            if item:IsA("GuiObject") then
                                local lbl = item:FindFirstChild("Label", true)
                                local zn = item:FindFirstChild("ZoneName", true)
                                if lbl and lbl.Text:find("%$") then
                                    local btn = item:FindFirstChildWhichIsA("GuiButton", true)
                                    if btn and getconnections then
                                        UpdateStatus("🗺️ ปลดล็อกโซน: " .. (zn and zn.Text or "Next"))
                                        for _, conn in getconnections(btn.MouseButton1Click) do
                                            conn:Fire()
                                        end
                                        HumanWait(0.4, 0.6)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                -- ตรวจสอบปลดล็อกโซนโดยตรงเมื่อวิจัยครบ 100% และเงินพอ
                if MineConfig then
                    local nextZoneIdx = (mg and mg.CurrentZone or 1) + 1
                    local nextZoneKey = "Z" .. nextZoneIdx
                    local nextZoneDef = MineConfig.Zones and MineConfig.Zones[nextZoneKey]
                    if nextZoneDef then
                        local unlockCost = tonumber(nextZoneDef.UnlockCost) or 0
                        local gate = MineConfig.ZoneResearchGateFor and MineConfig.ZoneResearchGateFor(nextZoneKey)
                        local isResearchDone = gate and MineConfig.IsZoneResearchComplete and MineConfig.IsZoneResearchComplete(mg.Skills or {}, gate)
                        local curMoney = tonumber(SafeGetData().Money) or 0
                        if isResearchDone and unlockCost > 0 and curMoney >= unlockCost then
                            UpdateStatus("🗺️ ปลดล็อกโซน: " .. (nextZoneDef.DisplayName or nextZoneKey))
                            SafeSendEvent(Config.Events.SelectZone, nextZoneKey)
                            HumanWait(0.4, 0.6)
                        end
                    end
                end
            end

            -- 12.3 สวมใส่ตัวละครที่ดีที่สุด (เว้นช่วง 20 วิ ไม่ส่งซ้ำ)
            if Config.AutoEquipBest and os.clock() - lastEquipTime > 20 then
                lastEquipTime = os.clock()
                TriggerEquipBest()
            end
        end)
        if not ok12 then
            warn(string.format("⚠️ [Worker Task 12 Error - AutoOther] %s", tostring(err12)))
        end

        task.wait(0.2)
    end
end)

-- ═══════════════════════════════════════════════
-- 🛡️ ANTI-AFK
-- ═══════════════════════════════════════════════
LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

print("✅ [AnimeMineAutoFarmV15] โหลดสำเร็จ - All-in-One Trade & Auto Farm Edition พร้อมทำงาน!")
