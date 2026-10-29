--[[
    ⛏️ เหมืองอนิเมะของฉัน - Auto Farm Suite V11 (All-in-One Safe Pipeline)
    ========================================================================
    ✅ 1. อัพระดับ Damage สถิติให้ตันแบบระบุตัวเลขได้:
          - กำหนดเลเวลเป้าหมายได้อิสระ (1-200) หรือกดปุ่ม [ตัน] เพื่อตั้งค่าเลเวล 200 ทันที
          - ป้องกันการอัปเกินค่า MaxLevel และตรวจเช็คเงินสดทุกครั้งก่อนยิงคำสั่ง
    ✅ 2. เพิ่มฟังก์ชันสุ่มลูกเต๋าเวทมนต์ (Auto Roll Enchanted Dice):
          - ตรวจสอบการปลดล็อกแท่น Enchant และจำนวนลูกเต๋า (DiceCount > 0) ก่อนยิงคำสั่ง
          - รองรับทั้ง EnchantDice ปกติ และ HalloweenDice อัตโนมัติ (สแตนด์บาย 0% Spam เมื่อหมด)
    ✅ 3. เพิ่มฟังก์ชันสุ่มม้วนอัญเชิญ (Auto Roll Summon Scrolls):
          - ตรวจสอบการปลดล็อกศาลเจ้า Summon และจำนวนม้วนอัญเชิญ (ScrollCount > 0) ก่อนยิงคำสั่ง
          - สุ่มครั้งละสูงสุด 10 ม้วนตามจำนวนที่มีจริง (สแตนด์บาย 0% Spam เมื่อหมด)
    ✅ 4. Pre-flight Checks เคร่งครัดทุกฟังก์ชัน 100%:
          - ตรวจสอบยอดเงินคงเหลือและสต็อกจริงแบบ Real-time ก่อนยิงทุก Remote Event
          - หมดปัญหาข้อความเตือน "เงินไม่พอ" หรือยิงคำสั่งซ้ำซ้อน
    ✅ 5. ทุกฟังก์ชันสามารถเปิดพร้อมกันได้ 100% เรียงตามลำดับ Priority 1 -> 9:
          1. เก็บของ -> 2. ขายของ (แร่ + โซนเก่า) -> 3. ต้นไม้ & แกนหลัก -> 4. ซื้อขวาน
          5. สถิติตัวละคร (จัดตาม Base DMG) -> 6. สุ่มการกลายพันธุ์ (เปิดค้างได้)
          7. สุ่มลูกเต๋าเวทมนต์ -> 8. สุ่มม้วนอัญเชิญ -> 9. อื่นๆ (ตีหิน, ซื้อโซน, สวมใส่, Anti-AFK)
    ✅ 6. Auto-Save & Auto-Load ลง AnimeMine_Config.json
    ✅ 7. ซิงค์สคริปต์ไปยัง GitHub Repo อัตโนมัติ:
          loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/script.lua"))()
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GameState = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameState"))
local MineConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MineConfig"))
local MineInventory = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MineInventory"))
local MineStock = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MineStock"))
local Items = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Items"))
local MineEnchantCatalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MineEnchantCatalog"))
local MineSummonCatalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MineSummonCatalog"))

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
    local item = Items.GetItemData(charName)
    if not item then return 0 end
    if MineConfig.GetCharacterDamage then
        local ok, dmg = pcall(MineConfig.GetCharacterDamage, item, 1, "Normal")
        if ok and dmg then return dmg end
    end
    if item.MineTier and MineConfig.TierDamage and MineConfig.TierDamage[item.MineTier] then
        return MineConfig.TierDamage[item.MineTier]
    end
    return 0
end

-- คัดเลือกคีย์ตัวละครเฉพาะในโซนเก่า (ไม่รวมโซนปัจจุบัน และไม่รวมตัวที่สวมใส่)
local function GetOldZoneCharacterKeys(mg)
    if not (MineInventory and MineInventory.Collect) then return {} end
    local allItems = MineInventory.Collect(mg)
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
                if MineConfig.CanSellCharacter and MineConfig.CanSellCharacter(it.Item or it) then
                    table.insert(keys, it.Key)
                end
            end
        end
    end
    return keys
end

-- ═══════════════════════════════════════════════
-- 🎯 CONFIG STATE & AUTO-SAVE SYSTEM
-- ═══════════════════════════════════════════════
local CONFIG_FILE = "AnimeMine_Config.json"

local Config = {
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
                    if Config[k] ~= nil then
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
-- 📍 HELPER: ค้นหา Plot ประจำตัวผู้เล่น
-- ═══════════════════════════════════════════════
local function GetMyPlot()
    local mw = workspace:FindFirstChild("MineWorld")
    if not mw then return nil end
    local plots = mw:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in plots:GetChildren() do
        local owner = plot:GetAttribute("OwnerUserId") or plot:GetAttribute("Owner")
        if owner == LocalPlayer.UserId or owner == tostring(LocalPlayer.UserId) then
            return plot
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════
-- 🎨 UI SYSTEM
-- ═══════════════════════════════════════════════
for _, oldName in ipairs({"AnimeMineAutoFarmV5", "AnimeMineAutoFarmV6", "AnimeMineAutoFarmV7", "AnimeMineAutoFarmV8", "AnimeMineAutoFarmV9", "AnimeMineAutoFarmV10", "AnimeMineAutoFarmV11"}) do
    local oldGui = PlayerGui:FindFirstChild(oldName)
    if oldGui then oldGui:Destroy() end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimeMineAutoFarmV11"
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
Title.Text = "⛏️ Auto Farm Suite V11"
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
-- 📋 สร้างเมนูจัดหมวดหมู่ตามลำดับ PRIORITY 1 -> 7
-- ═══════════════════════════════════════════════
AddCategory("📦 1. เก็บของ & 💰 2. ขายของ", 1)
AddToggle("AutoChest", "1. Auto Take Chest (เก็บของ)", "ดูดแร่จากหีบเข้ากระเป๋าเมื่อหินแตก", 2)
AddToggle("AutoSell", "2. Auto Sell Ores (ขายแร่)", "เมื่อมีแร่ วาร์ปไปขายที่ SellStand รับเงินสด", 3)
AddToggle("AutoSellOldChars", "3. Auto Sell Old Zone Chars", "ขายตัวละครโซนเก่าทิ้งอัตโนมัติ (เก็บตัวละครโซนปัจจุบันไว้ 100%)", 4)
AddActionButton("⚡ ขายตัวละครโซนเก่าทันที", "วาร์ปไปขายตัวละครในคลังจากโซนเก่าทั้งหมดรอบเดียว", "ขายทันที", Theme.SpecialBtn, function()
    task.spawn(function()
        local d2 = GameState.GetData2()
        local mg = d2 and d2.MineGame
        local oldKeys = GetOldZoneCharacterKeys(mg)
        if #oldKeys == 0 then
            UpdateStatus("ℹ️ ไม่มีตัวละครโซนเก่าให้ขาย")
            return
        end
        local char = LocalPlayer.Character
        local sellStand = workspace:FindFirstChild("SellStand")
        local myPlot = GetMyPlot()
        local returnPlot = (myPlot and myPlot:FindFirstChild("PlotSpawn") and (myPlot.PlotSpawn.CFrame + Vector3.new(0, 3, 0))) or (myPlot and (myPlot:GetPivot() + Vector3.new(0, 4, 0)))
        if char and sellStand then
            UpdateStatus(string.format("💰 ขายตัวละครโซนเก่า (%d ชุด)...", #oldKeys))
            char:PivotTo(sellStand:GetPivot() + Vector3.new(0, 3, 5))
            HumanWait(0.35, 0.5)
            GameState.SendEvent("MineSellItems", oldKeys)
            HumanWait(0.35, 0.5)
            if returnPlot then
                char:PivotTo(returnPlot)
                HumanWait(0.2, 0.3)
            end
            UpdateStatus(string.format("✅ ขายตัวละครโซนเก่า %d ชุดสำเร็จ!", #oldKeys))
        end
    end)
end, 5)

AddCategory("🌳 3. อัปเกรดต้นไม้ & แกนหลัก", 10)
AddToggle("AutoUpgradeTree", "Auto Zone Skill Tree (ต้นใหม่)", "อัปเกรดผังสกิลของโซนปัจจุบันตามลำดับโหนด (Batch Upgrades)", 11)
AddToggle("AutoUpgradeCore", "Auto Core Upgrades (แกนหลัก)", "อัปเกรด Tap Level และ Miner Slots ในแกนหลัก", 12)

AddCategory("🪓 4. ซื้อขวานร้านค้า", 20)
AddToggle("AutoBuyBestPickaxe", "Auto Buy Best Pickaxe", "ซื้อขวานขั้นที่แพงและดีที่สุดเมื่อพร้อม (ไม่จำกัดจำนวน)", 21)

AddCategory("👥 5. อัปเกรดสถิติ (เรียงตาม Base DMG Lv.1)", 30)
AddToggle("AutoUpgradeAllChars", "Auto Upgrade Characters", "อัปเกรดสถิติตัวละคร โดยให้ความสำคัญจากตัวที่เก่งสุดก่อน", 31)
AddLevelCapCustomInput("⚔️ เป้าหมาย Damage (1-200 / ตัน):", "TargetLevelDamage", 1, 200, 5, 32)
AddLevelCapCustomInput("⚡ เป้าหมาย Speed (1-17 / ตัน):", "TargetLevelSpeed", 1, 17, 1, 33)
AddLevelCapCustomInput("⛏️ เป้าหมาย MineSpeed (1-16 / ตัน):", "TargetLevelMineSpeed", 1, 16, 1, 34)

AddCategory("🧬 6. สุ่มการกลายพันธุ์ (เปิดค้างได้ + ล็อคอัตโนมัติ)", 40)
AddToggle("AutoMutation", "Auto Mutation Roll (เปิดค้างได้)", "สุ่มบัพตัวละครที่เลือกทีละตัว และสแตนด์บายเมื่อได้ครบ (ไม่ปิดสวิตช์)", 41)
AddMultiSlotSelector(42)
AddMultiMutationSelector(43)

AddCategory("🎲 7. ลูกเต๋าเวทมนต์ & ม้วนอัญเชิญ", 50)
AddToggle("AutoRollDice", "Auto Roll Dice (ทอยลูกเต๋า Enchant)", "ทอยลูกเต๋า Enchant & Halloween อัตโนมัติ (หยุดเมื่อลูกเต๋าหมด)", 51)
AddToggle("AutoSummonScrolls", "Auto Summon Scrolls (สุ่มม้วนอัญเชิญ)", "เปิดม้วนอัญเชิญตัวละครอัตโนมัติ (หยุดเมื่อม้วนหมด)", 52)

AddCategory("⛏️ 8. อื่นๆ (ตีหิน, โซนใหม่, สวมใส่, Anti-AFK)", 60)
AddToggle("AutoMine", "Auto Mine (ตีหินในแปลง)", "ค้นหาและตีหินในแปลงของตัวเองอย่างเป็นระเบียบ", 61)
AddToggle("AutoBuyZone", "Auto Unlock New Zone", "ซื้อและปลดล็อกโซนใหม่ที่ ZoneBoard เมื่อวิจัยครบ", 62)
AddToggle("AutoEquipBest", "Auto Equip Best", "ใส่ตัวละครที่ดีที่สุดลงแท่นขุด (เว้นช่วงไม่ส่งซ้ำ)", 63)
AddToggle("AntiAFK", "Anti-AFK Protection", "ป้องกันระบบตัดการเชื่อมต่อเมื่อ AFK", 64)

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
-- 🚀 MASTER WORKER PIPELINE (ลำดับ 1 -> 7 ตามคำสั่งผู้ใช้)
-- ═══════════════════════════════════════════════
local lastEquipTime = 0

task.spawn(function()
    while true do
        local myPlot = GetMyPlot()
        local d = GameState:GetData()
        local d2 = GameState.GetData2()
        local mg = d2 and d2.MineGame
        local myMoney = d and tonumber(d.Money) or 0
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        -- -------------------------------------------------------------
        -- ลำดับที่ 1: เก็บของ (Auto Take Chest)
        -- -------------------------------------------------------------
        if Config.AutoChest then
            d2 = GameState.GetData2()
            mg = d2 and d2.MineGame
            local chest = mg and mg.Chest
            if chest and next(chest) ~= nil then
                UpdateStatus("📦 ดูดแร่จากหีบ...")
                GameState.SendEvent("MineTakeChest")
                HumanWait(0.2, 0.35)
            end
        end

        -- -------------------------------------------------------------
        -- ลำดับที่ 2: ขายของ (Auto Sell ที่ร้านค้า SellStand)
        -- ขายแร่ในกระเป๋า + ขายตัวละครในโซนเก่าทิ้ง (เก็บตัวละครโซนปัจจุบันไว้ทั้งหมด 100%)
        -- -------------------------------------------------------------
        d2 = GameState.GetData2()
        mg = d2 and d2.MineGame
        local ores = mg and mg.Ores
        local hasOres = ores and next(ores) ~= nil
        local oldCharKeys = Config.AutoSellOldChars and GetOldZoneCharacterKeys(mg) or {}
        local hasOldChars = #oldCharKeys > 0
        local shouldSell = hasOres or hasOldChars
        local didTravel = false
        local returnPlotCFrame = (myPlot and myPlot:FindFirstChild("PlotSpawn") and (myPlot.PlotSpawn.CFrame + Vector3.new(0, 3, 0))) or (myPlot and (myPlot:GetPivot() + Vector3.new(0, 4, 0)))

        if (Config.AutoSell or Config.AutoSellOldChars) and shouldSell and char then
            local sellStand = workspace:FindFirstChild("SellStand")
            if sellStand then
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
                    GameState.SendEvent("MineSellItems", sellKeys)
                    HumanWait(0.35, 0.5)
                end

                d = GameState:GetData()
                myMoney = d and tonumber(d.Money) or 0
            end
        end

        -- -------------------------------------------------------------
        -- ลำดับที่ 3: อัปเกรดต้นไม้ (Zone Skill Tree & Core Upgrades)
        -- -------------------------------------------------------------
        d = GameState:GetData()
        d2 = GameState.GetData2()
        mg = d2 and d2.MineGame
        myMoney = d and tonumber(d.Money) or 0

        -- 3.1 สกิลต้นไม้ประจำโซน (Batch Upgrade สูงสุด 5 โหนดต่อรอบ)
        if Config.AutoUpgradeTree and mg then
            local curZone = mg.CurrentZone or 1
            local zoneKey = "Z" .. tostring(curZone)
            local zSkills = (mg.Skills and mg.Skills[zoneKey]) or {}

            local nodes = MineConfig.GetSkillNodes and MineConfig.GetSkillNodes(zoneKey)
            if nodes then
                local upgradedCount = 0
                for _, node in ipairs(nodes) do
                    local isOpen = MineConfig.IsSkillNodeOpen(zSkills, node)
                    local isMaxed = MineConfig.IsSkillNodeMaxed(zSkills, node)
                    local curLvl = zSkills[node.Family] or 0
                    local cost = MineConfig.GetSkillCost and MineConfig.GetSkillCost(zoneKey, curLvl, node.Family)

                    local curMoney = tonumber(GameState:GetData().Money) or 0
                    if isOpen and not isMaxed and cost and curMoney >= cost then
                        GameState.SendEvent("MineSkillTreeSection", zoneKey)
                        UpdateStatus("🌳 อัปต้นไม้: " .. (node.Name or node.Id))
                        GameState.SendEvent("MineBuySkill", zoneKey, node.Family, node.Id)
                        upgradedCount = upgradedCount + 1
                        HumanWait(0.12, 0.18)
                        if upgradedCount >= 5 then break end
                    end
                end
            end
        end

        -- 3.2 สกิลแกนหลัก
        if Config.AutoUpgradeCore and mg then
            for _, cNode in ipairs(MineConfig.CoreNodes or {}) do
                local isOpen = MineConfig.IsCoreNodeOpen and MineConfig.IsCoreNodeOpen(mg, cNode)
                local isMaxed = MineConfig.IsCoreNodeMaxed and MineConfig.IsCoreNodeMaxed(mg, cNode)
                if isOpen and not isMaxed then
                    local upDef = MineConfig.CoreUpgradeById and MineConfig.CoreUpgradeById[cNode.Family]
                    if upDef and upDef.Cost and upDef.Event then
                        local cost = upDef.Cost(mg[upDef.Field])
                        local curMoney = tonumber(GameState:GetData().Money) or 0
                        if cost and curMoney >= cost then
                            UpdateStatus("⚙️ อัปแกนหลัก: " .. (cNode.Name or cNode.Id))
                            GameState.SendEvent(upDef.Event)
                            HumanWait(0.2, 0.35)
                            break
                        end
                    end
                end
            end
        end

        -- -------------------------------------------------------------
        -- ลำดับที่ 4: ซื้อขวานที่ดีที่สุดและออโต้สวมใส่ (Auto Buy & Equip Best Pickaxes)
        -- ซื้อขวานที่ดีที่สุดเมื่อพร้อมโดยไม่จำกัดจำนวน
        -- -------------------------------------------------------------
        if Config.AutoBuyBestPickaxe and mg then
            d = GameState:GetData()
            d2 = GameState.GetData2()
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
                        local stock = MineStock.GetRemaining and MineStock.GetRemaining(d2, pick.Name) or 0

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
                    local curMoney = tonumber(GameState:GetData().Money) or 0
                    local cost = tonumber(bestPick.Cost) or (1 / 0)
                    local stock = MineStock.GetRemaining and MineStock.GetRemaining(d2, bestPick.Name) or 0
                    local ownedCount = tonumber(mg.Pickaxes and mg.Pickaxes[bestPick.Name]) or 0

                    if curMoney >= cost and stock > 0 then
                        UpdateStatus(string.format("🪓 ซื้อขวาน: %s (มีแล้ว %d ชิ้น)", bestPick.Name, ownedCount))
                        GameState.SendEvent("MineBuyPickaxe", bestPickIdx)
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
                d2 = GameState.GetData2()
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
                            GameState.SendEvent("MineEquipPickaxe", h.slot, target.name)
                            HumanWait(0.08, 0.12)
                        end
                    end
                end
            end
        end

        -- หากมีการวาร์ปออกไป ให้วาร์ปกลับแปลง
        if didTravel and char and returnPlotCFrame then
            char:PivotTo(returnPlotCFrame)
            HumanWait(0.25, 0.4)
            UpdateStatus("🏠 กลับถึงแปลงขุด")
        end

        -- รีเฟรชข้อมูลเงินและตัวละครล่าสุด
        d = GameState:GetData()
        d2 = GameState.GetData2()
        mg = d2 and d2.MineGame
        myMoney = d and tonumber(d.Money) or 0

        -- -------------------------------------------------------------
        -- ลำดับที่ 5: อัปเกรดสถิติ (จัดลำดับจากค่าพลังโจมตีพื้นฐาน Lv.1 มากที่สุดเสมอ)
        -- -------------------------------------------------------------
        if Config.AutoUpgradeAllChars and mg and mg.Holders then
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

            -- เรียงลำดับจากค่าพลังโจมตีพื้นฐานเวล 1 ที่มากที่สุดเสมอ
            table.sort(sortedHolders, function(a, b) return a.baseDmg > b.baseDmg end)

            for _, charInfo in ipairs(sortedHolders) do
                local slotKey = charInfo.slot
                local h = charInfo.holder
                local item = Items.GetItemData(h.CharName)
                if item then
                    -- 1. Damage Upgrade Check
                    local curLvl = h.CharLevel or 1
                    local targetLvl = math.min(Config.TargetLevelDamage, MineConfig.CharMaxLevel or 200)
                    if curLvl < targetLvl then
                        local cost = MineConfig.GetCharacterUpgradeCost(curLvl, item)
                        local curMoney = tonumber(GameState:GetData().Money) or 0
                        if cost and curMoney >= cost then
                            UpdateStatus(string.format("⚔️ อัป DMG %s [%s]", slotKey, FormatNumber(charInfo.baseDmg)))
                            GameState.SendEvent("MineUpgradeCharacter", slotKey, "Damage")
                            HumanWait(0.08, 0.15)
                        end
                    end

                    -- 2. Speed Upgrade Check
                    local curSpd = h.CharSpeedLevel or 1
                    local targetSpd = math.min(Config.TargetLevelSpeed, MineConfig.CharSpeedMaxLevel or 17)
                    if curSpd < targetSpd then
                        local cost = MineConfig.GetCharacterSpeedUpgradeCost(curSpd, item)
                        local curMoney = tonumber(GameState:GetData().Money) or 0
                        if cost and curMoney >= cost then
                            UpdateStatus("⚡ อัป Speed " .. slotKey)
                            GameState.SendEvent("MineUpgradeCharacter", slotKey, "Speed")
                            HumanWait(0.08, 0.15)
                        end
                    end

                    -- 3. MineSpeed Upgrade Check
                    local curMineSpd = h.CharMineSpeedLevel or 1
                    local targetMineSpd = math.min(Config.TargetLevelMineSpeed, MineConfig.CharMineSpeedMaxLevel or 16)
                    if curMineSpd < targetMineSpd then
                        local cost = MineConfig.GetCharacterMineSpeedUpgradeCost(curMineSpd, item)
                        local curMoney = tonumber(GameState:GetData().Money) or 0
                        if cost and curMoney >= cost then
                            UpdateStatus("⛏️ อัป MineSpeed " .. slotKey)
                            GameState.SendEvent("MineUpgradeCharacter", slotKey, "MineSpeed")
                            HumanWait(0.08, 0.15)
                        end
                    end
                end
            end
        end

        -- -------------------------------------------------------------
        -- ลำดับที่ 6: สุ่มการกลายพันธุ์ (จัดลำดับจากค่าพลังโจมตีพื้นฐาน Lv.1 มากที่สุดเสมอ)
        -- เปิดค้างไว้ได้ตลอดเวลา ทำงานเมื่อพร้อม ถ้าได้บัพที่เลือกแล้วจะหยุดยิงคำสั่ง (สแตนด์บาย ไม่ปิดสวิตช์)
        -- -------------------------------------------------------------
        if Config.AutoMutation and mg and mg.Holders then
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

            -- เรียงลำดับจากค่าพลังโจมตีพื้นฐานเวล 1 ที่มากที่สุดเสมอ
            table.sort(pendingSlots, function(a, b) return a.baseDmg > b.baseDmg end)

            if totalSelected == 0 then
                -- ยังไม่ได้เลือกแท่นใดๆ
            elseif #pendingSlots == 0 then
                -- ทุกตัวที่เลือกได้บัพเป้าหมายครบหมดแล้ว! หยุดยิงคำสั่ง สแตนด์บายรอ (ไม่ปิดสวิตช์!)
                UpdateStatus(string.format("🎉 ได้บัพครบแล้ว (%d/%d) [สแตนด์บาย]", lockedCount, totalSelected))
            else
                -- หยิบตัวที่มีพลังโจมตีพื้นฐานเลเวล 1 สูงสุดก่อน
                local currentTarget = pendingSlots[1]
                local item = Items.GetItemData(currentTarget.name)
                -- ใช้ mg (d2.MineGame ที่มีตาราง .Skills) เพื่อคำนวณ MutationDensityCostMult ให้ตรงกับ Server จริง 100%
                local mutCost = item and MineConfig.GetMutationRollCost(item, mg)
                local curMoney = tonumber(GameState:GetData().Money) or 0

                if mutCost and curMoney >= mutCost then
                    -- ตรวจสอบเงินสดล่าสุดก่อนยิงคำสั่งสุ่มทุกครั้ง ป้องกัน Server แจ้งเตือนเงินไม่พอ 100%
                    for r = 1, 3 do
                        curMoney = tonumber(GameState:GetData().Money) or 0
                        if not Config.AutoMutation or curMoney < mutCost then break end

                        UpdateStatus(string.format("🧬 สุ่ม %s [Base: %s]", currentTarget.slot, FormatNumber(currentTarget.baseDmg)))
                        GameState.SendEvent("MineRollMutation", currentTarget.slot)
                        HumanWait(0.22, 0.3)

                        local postD2 = GameState.GetData2()
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

        -- -------------------------------------------------------------
        -- ลำดับที่ 7: สุ่มลูกเต๋าเวทมนต์ (Auto Roll Enchanted & Halloween Dice)
        -- ตรวจสอบเงื่อนไขอย่างเคร่งครัด: ต้องปลดล็อกแท่น และมีลูกเต๋า > 0 ก่อนยิงคำสั่ง
        -- -------------------------------------------------------------
        if Config.AutoRollDice and mg then
            local isEnchantUnlocked = MineEnchantCatalog and MineEnchantCatalog.Unlocked and MineEnchantCatalog.Unlocked(mg)
            if isEnchantUnlocked then
                local hwDice = (mg and mg.HalloweenDice) or 0
                local normalDice = (MineConfig.GetEnchantDiceCount and MineConfig.GetEnchantDiceCount(mg)) or (mg and mg.EnchantDice) or 0

                if hwDice > 0 then
                    local rollCount = math.clamp(hwDice, 1, 5)
                    UpdateStatus(string.format("🎲 ทอยลูกเต๋า Halloween (%d ลูก)...", rollCount))
                    GameState.SendEvent("MineRollEnchant", rollCount, "Halloween")
                    HumanWait(0.3, 0.45)
                elseif normalDice > 0 then
                    local rollCount = math.clamp(normalDice, 1, 5)
                    UpdateStatus(string.format("🎲 ทอยลูกเต๋า Enchant (%d ลูก)...", rollCount))
                    GameState.SendEvent("MineRollEnchant", rollCount, nil)
                    HumanWait(0.3, 0.45)
                end
            end
        end

        -- -------------------------------------------------------------
        -- ลำดับที่ 8: สุ่มม้วนอัญเชิญ (Auto Roll Summon Scrolls)
        -- ตรวจสอบเงื่อนไขอย่างเคร่งครัด: ต้องปลดล็อกศาลเจ้า และมีม้วน > 0 ก่อนยิงคำสั่ง
        -- -------------------------------------------------------------
        if Config.AutoSummonScrolls and mg then
            local isSummonUnlocked = MineSummonCatalog and MineSummonCatalog.Unlocked and MineSummonCatalog.Unlocked(mg)
            if isSummonUnlocked then
                local scrollCount = (MineConfig.GetSummonScrollCount and MineConfig.GetSummonScrollCount(mg)) or (mg and mg.SummonScrolls) or 0
                if scrollCount > 0 then
                    local rollCount = math.clamp(scrollCount, 1, 10)
                    UpdateStatus(string.format("📜 สุ่มม้วนอัญเชิญ (%d ม้วน)...", rollCount))
                    GameState.SendEvent("MineSummon", rollCount)
                    HumanWait(0.3, 0.45)
                end
            end
        end

        -- -------------------------------------------------------------
        -- ลำดับที่ 9: อื่นๆ (ตีหิน, ซื้อโซน, สวมใส่ตัวดีที่สุด)
        -- -------------------------------------------------------------
        -- 7.1 ตีหินในแปลง
        if Config.AutoMine and myPlot and myPlot:FindFirstChild("Nodes") then
            for hit = 1, 10 do
                if not Config.AutoMine then break end

                local targetNode = nil
                for _, node in ipairs(myPlot.Nodes:GetChildren()) do
                    local hp = node:GetAttribute("NodeHP")
                    if hp and hp > 0 then
                        targetNode = node
                        break
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

        -- 7.2 ซื้อโซนใหม่ที่ ZoneBoard
        if Config.AutoBuyZone and myPlot then
            local zb = myPlot:FindFirstChild("ZoneBoard")
            local gui = zb and zb:FindFirstChild("ZoneBoardGui")
            local list = gui and gui:FindFirstChild("Root") and gui.Root:FindFirstChild("List")

            if list then
                for _, item in ipairs(list:GetChildren()) do
                    if item:IsA("GuiObject") then
                        local lbl = item:FindFirstChild("Label", true)
                        local zn = item:FindFirstChild("ZoneName", true)
                        if lbl and lbl.Text:find("%$") then
                            local btn = item:FindFirstChildWhichIsA("GuiButton", true)
                            if btn then
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

            -- ตรวจสอบปลดล็อกโซนโดยตรงเมื่อวิจัยครบ 100% และเงินพอ
            local nextZoneIdx = (mg and mg.CurrentZone or 1) + 1
            local nextZoneKey = "Z" .. nextZoneIdx
            local nextZoneDef = MineConfig.Zones and MineConfig.Zones[nextZoneKey]
            if nextZoneDef then
                local unlockCost = tonumber(nextZoneDef.UnlockCost) or 0
                local gate = MineConfig.ZoneResearchGateFor and MineConfig.ZoneResearchGateFor(nextZoneKey)
                local isResearchDone = gate and MineConfig.IsZoneResearchComplete and MineConfig.IsZoneResearchComplete(mg.Skills or {}, gate)
                local curMoney = tonumber(GameState:GetData().Money) or 0
                if isResearchDone and unlockCost > 0 and curMoney >= unlockCost then
                    UpdateStatus("🗺️ ปลดล็อกโซน: " .. (nextZoneDef.DisplayName or nextZoneKey))
                    GameState.SendEvent("MineSelectZone", nextZoneKey)
                    HumanWait(0.4, 0.6)
                end
            end
        end

        -- 7.3 สวมใส่ตัวละครที่ดีที่สุด (เว้นช่วง 60 วิ ไม่ส่งซ้ำ)
        if Config.AutoEquipBest and os.clock() - lastEquipTime > 60 then
            lastEquipTime = os.clock()
            GameState.SendEvent("MineEquipBest")
            HumanWait(0.2, 0.3)
        end

        task.wait(0.2)
    end
end)

-- ═══════════════════════════════════════════════
-- 🛡️ ANTI-AFK
-- ═══════════════════════════════════════════════
LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

print("✅ [AnimeMineAutoFarmV11] โหลดสำเร็จ - All-in-One Safe Pipeline พร้อมทำงาน!")
