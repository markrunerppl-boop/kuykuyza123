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
local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 30)

-- 🛑 KILL SWITCH FOR PREVIOUS RUNNING WORKER THREADS
if getgenv then
    if getgenv()._AnimeMineWorkerActive then
        getgenv()._AnimeMineWorkerActive = false
        task.wait(0.3)
    end
    getgenv()._AnimeMineWorkerActive = true
end
local scriptSessionId = tostring(math.random()) .. "_" .. tostring(os.clock())
if getgenv then
    getgenv()._AnimeMineSessionId = scriptSessionId
end

-- 🛡️ ปิดกั้นสคริปต์ IdleRejoin ของตัวเกมเพื่อป้องกัน Roblox Error 769 100%
local function NeutralizeIdleRejoin()
    pcall(function()
        local pscripts = LocalPlayer:FindFirstChild("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts", 5)
        if pscripts then
            local essentials = pscripts:FindFirstChild("Essentials") or pscripts:WaitForChild("Essentials", 3)
            if essentials then
                local idleScript = essentials:FindFirstChild("IdleRejoin")
                if idleScript then
                    idleScript.Disabled = true
                    idleScript:Destroy()
                end
            end
        end
    end)
end
NeutralizeIdleRejoin()

-- 🛡️ ระบบเฝ้าระวังหน้าจอโหลด คืนค่ามุมกล้อง และป้องกัน Error 769 ตลอดการทำงาน
task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            -- 1. เคลียร์ IdleRejoin อย่างต่อเนื่อง ป้องกันเกมเกิดใหม่แล้วโหลดสคริปต์ซ้ำ
            NeutralizeIdleRejoin()

            -- 2. ตรวจจับและกดปุ่มข้าม LoadingScreen / Popup เริ่มเกมอัตโนมัติ
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                local ls = pg:FindFirstChild("LoadingScreen")
                if ls and ls.Enabled then
                    local cb = ls:FindFirstChild("ContinueButton", true) or ls:FindFirstChild("PlayButton", true)
                    if cb and getconnections then
                        for _, conn in ipairs(getconnections(cb.MouseButton1Down)) do conn:Fire() end
                        for _, conn in ipairs(getconnections(cb.MouseButton1Click)) do conn:Fire() end
                    end
                    local vu = game:GetService("VirtualUser")
                    if vu then
                        vu:Button1Down(Vector2.new(200, 200))
                        task.wait(0.05)
                        vu:Button1Up(Vector2.new(200, 200))
                    end
                end
            end

            -- 3. กู้คืนมุมกล้องหากค้างลอยบนฟ้า (Scriptable) ให้กลับมาโฟกัสที่ตัวละครเสมอ
            local cam = workspace.CurrentCamera
            local char = LocalPlayer and LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if cam and hum then
                if cam.CameraType == Enum.CameraType.Scriptable then
                    cam.CameraType = Enum.CameraType.Custom
                    cam.CameraSubject = hum
                elseif cam.CameraSubject ~= hum and not (cam.CameraSubject and cam.CameraSubject:IsDescendantOf(char)) then
                    cam.CameraSubject = hum
                end
            end
        end)
    end
end)

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

-- 🛡️ ประกาศตัวแปร Config ล่วงหน้า (Forward Declaration) เพื่อให้ฟังก์ชัน Helper ทั้งหมดเข้าถึงได้
local Config = nil

-- สร้างตารางแมปชื่อตัวละคร -> โซน เพื่อค้นหาโซนได้อย่างแม่นยำ 100% โดยไม่ต้องพึ่งพาโมดูลภายนอก
local function GetCharacterZone(charName)
    if not charName or not (MineConfig and MineConfig.Zones) then return nil end
    for zk, z in pairs(MineConfig.Zones) do
        local zoneNum = tonumber(zk:match("%d+")) or 1
        if z and z.CharacterPool then
            for _, entry in ipairs(z.CharacterPool) do
                if entry.Name == charName then
                    return zoneNum
                end
            end
        end
    end
    return nil
end

-- คัดเลือกคีย์ขวานเก่าทั้งหมดเพื่อนำไปขาย (ยกเว้นขวานที่ดีที่สุดไว้เท่านั้น)
local function GetOldPickaxeKeys(mg)
    if not (mg and mg.Pickaxes and MineConfig and MineConfig.Pickaxes) then return {}, nil end

    -- 1. หาขวานที่ดีที่สุดที่ผู้เล่นมีอยู่ในกระเป๋า (Highest Multiplier)
    local bestMult = -1
    local bestOwnedPick = nil

    for pName, count in pairs(mg.Pickaxes) do
        local countNum = tonumber(count) or 0
        if countNum > 0 then
            local pDef = nil
            for _, p in ipairs(MineConfig.Pickaxes) do
                if p.Name == pName then
                    pDef = p
                    break
                end
            end
            local mult = pDef and (tonumber(pDef.Multiplier) or 1) or 0
            if mult > bestMult then
                bestMult = mult
                bestOwnedPick = pName
            end
        end
    end

    -- นับจำนวนขวานที่สวมใส่อยู่บนแท่นคนงานทั้งหมด
    local assignedCount = {}
    for _, h in pairs(mg.Holders or {}) do
        if h and h.Pickaxe then
            assignedCount[h.Pickaxe] = (assignedCount[h.Pickaxe] or 0) + 1
        end
    end

    -- 2. ขวานอื่นๆ ทั้งหมดที่ด้อยกว่าขวานที่ดีที่สุด และไม่ได้สวมใส่อยู่บนแท่น (Spare > 0)
    local oldPickKeys = {}
    for pName, count in pairs(mg.Pickaxes) do
        local countNum = tonumber(count) or 0
        local inUse = assignedCount[pName] or 0
        local spare = math.max(0, countNum - inUse)
        if countNum > 0 and pName ~= bestOwnedPick and spare > 0 then
            local pDef = nil
            for _, p in ipairs(MineConfig.Pickaxes) do
                if p.Name == pName then
                    pDef = p
                    break
                end
            end
            if pDef and not (MineConfig.IsPickaxeFree and MineConfig.IsPickaxeFree(pDef)) then
                table.insert(oldPickKeys, pName)
            end
        end
    end

    return oldPickKeys, bestOwnedPick
end

-- 🎯 ฟังก์ชันรวมศูนย์การคัดเลือกไอเทมที่จะขายทั้งหมด (แร่, ขวานเก่า, ตัวละครตามระดับ & โซนเก่า)
-- สแกนตรงจาก mg.Ores, mg.Pickaxes, mg.Characters 100% ปลอดภัย ไม่พึ่งพาโมดูลภายนอกที่อาจ Error
local function GetUnifiedSellKeys(mg)
    local sellKeys = {}
    local addedKeySet = {}
    if not (mg and Config and Config.SellOptions) then return sellKeys end

    -- 1. แร่ในกระเป๋า (Ores)
    if Config.SellOptions["Ores"] and mg.Ores then
        for k in pairs(mg.Ores) do
            if not addedKeySet[k] then
                table.insert(sellKeys, k)
                addedKeySet[k] = true
            end
        end
    end

    -- 2. ขวานเก่าทั้งหมด (ยกเว้นขวานที่ดีที่สุดที่สวมใส่/เก็บไว้)
    if Config.SellOptions["OldPickaxes"] then
        local oldPicks, bestPick = GetOldPickaxeKeys(mg)
        for _, k in ipairs(oldPicks) do
            if not addedKeySet[k] then
                table.insert(sellKeys, k)
                addedKeySet[k] = true
            end
        end
    end

    -- 3. ตัวละครในกระเป๋า (สแกนตรงจาก mg.Characters โดยตัวที่ทำงานบนแท่น Holders เซิร์ฟเวอร์จะคุ้มครองให้อยู่แล้ว 100%)
    local curZone = mg.CurrentZone or 1

    if type(mg.Characters) == "table" then
        for charKey, count in pairs(mg.Characters) do
            local countNum = tonumber(count) or 0
            if countNum > 0 then
                local baseName = charKey:match("^([^|]+)") or charKey
                local shouldSellChar = false
                local itemData = Items and Items.GetItemData and Items.GetItemData(baseName)
                local rName = nil
                if itemData and itemData.Rarity then
                    if type(itemData.Rarity) == "table" then
                        rName = itemData.Rarity.Rarity
                    else
                        rName = tostring(itemData.Rarity)
                    end
                end

                -- เช็คตามระดับความหายากที่เลือก (Common, Uncommon, Rare, Epic, Legendary, Mythical, Exotic)
                if rName and Config.SellOptions and Config.SellOptions[rName] then
                    shouldSellChar = true
                end

                -- เช็คกรณีเลือกขายตัวละครโซนเก่า
                if not shouldSellChar and Config.SellOptions and Config.SellOptions["OldZoneChars"] then
                    local z = GetCharacterZone(baseName)
                    if z and z < curZone then
                        shouldSellChar = true
                    end
                end

                -- 🛡️ ป้องกันตัวละคร Limited, Secret, Event, Exclusive 100% ไม่ให้โดนขายเด็ดขาด แม้จะเปิดขายโซนเก่า!
                local isProtectedRarity = (rName == "Limited" or rName == "Secret" or rName == "Event" or rName == "Exclusive")
                if isProtectedRarity then
                    shouldSellChar = false
                end

                if shouldSellChar then
                    local canSell = not MineConfig or not MineConfig.CanSellCharacter or MineConfig.CanSellCharacter(itemData or { ItemName = baseName })
                    if canSell and not addedKeySet[charKey] then
                        table.insert(sellKeys, charKey)
                        addedKeySet[charKey] = true
                    end
                end
            end
        end
    end

    return sellKeys
end

-- ═══════════════════════════════════════════════
-- 🎯 2. CONFIG STATE & CENTRALIZED STRING CONSTANTS
-- ═══════════════════════════════════════════════
local CONFIG_FILE = "AnimeMine_Config.json"

Config = {
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
    AutoSell = true, -- ระบบขายอัตโนมัติรวม (ขายแร่, ขวานเก่า และตัวละครตามที่เลือกในดรอปดาวน์)
    SellOptions = {
        ["Ores"] = true,          -- แร่ในกระเป๋า
        ["OldPickaxes"] = true,   -- ขวานเก่าทั้งหมด (เก็บเฉพาะขวานที่ดีที่สุด)
        ["Common"] = true,        -- ตัวละคร Common
        ["Uncommon"] = true,      -- ตัวละคร Uncommon
        ["Rare"] = true,          -- ตัวละคร Rare
        ["Epic"] = false,         -- ตัวละคร Epic
        ["Legendary"] = false,    -- ตัวละคร Legendary
        ["Mythical"] = false,     -- ตัวละคร Mythical
        ["Exotic"] = false,       -- ตัวละคร Exotic
        ["OldZoneChars"] = true,  -- ตัวละครโซนเก่า
    },
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
        ["M8"] = true,
        ["M9"] = true,
        ["M10"] = true,
        ["M11"] = true,
        ["M12"] = true
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
                SellOptions = Config.SellOptions,
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
                        if k == "SellOptions" and type(v) == "table" then
                            for optKey, optVal in pairs(v) do
                                Config.SellOptions[optKey] = optVal
                            end
                        elseif k == "MutationSlots" and type(v) == "table" then
                            for sKey, sVal in pairs(v) do
                                Config.MutationSlots[sKey] = sVal
                            end
                        elseif k == "TargetMutations" and type(v) == "table" then
                            for mKey, mVal in pairs(v) do
                                Config.TargetMutations[mKey] = mVal
                            end
                        else
                            Config[k] = v
                        end
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

-- ═══════════════════════════════════════════════
-- 🤝 TRADE CORE DATA HELPERS & LOGIC
-- ═══════════════════════════════════════════════
-- 🤝 7. ADVANCED TRADE & SELECTIVE TRANSFER SUITE (V7.1 PRO)
-- ═══════════════════════════════════════════════
local TradeState = nil
local TradeMainFrame = nil

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
        PreReadyDelay    = 1.5,     -- หน่วงเวลาก่อนส่ง MineTradeReady (วินาที)
        ConfirmWaitTime  = 4.5,     -- เวลารอนับถอยหลังของเกมก่อนกดยืนยัน Confirm (วินาที)
        RequestTimeout   = 35.0,    -- เวลารอผู้รับกดยอมรับคำขอเทรด (วินาที) ปรับเพิ่มสำหรับ UGPhone / Mobile
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
    
    -- ตรวจสอบว่าไอเทมสามารถแสดงในระบบเทรดได้ (เปิดให้แสดงไอเทมทุกชนิดในคลังเพื่อให้ผู้ใช้เลือกส่งได้เอง 100%)
    local function CanTradeItem(itemKey)
        if not itemKey or type(itemKey) ~= "string" or #itemKey == 0 then return false end
        if itemKey == "Day" or itemKey == "Count" then return false end
        return true
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

        -- 8. แร่ (Ores)
        if type(mg.Ores) == "table" then
            for oreName, count in pairs(mg.Ores) do
                local num = tonumber(count) or 0
                if num > 0 and CanTradeItem(oreName) then
                    table.insert(list, {
                        Key = oreName,
                        Name = oreName,
                        Count = num,
                        Total = num,
                        Kind = "Ore",
                        Category = "Other",
                        Emoji = "🪨",
                        MaxCap = TradeTimingConfig.MaxStackCap
                    })
                end
            end
        end

        -- 9. ไอเทมทั่วไปอื่นๆ ในกระเป๋า (Items / Misc)
        if type(mg.Items) == "table" then
            for itName, count in pairs(mg.Items) do
                local num = tonumber(count) or 0
                if num > 0 and CanTradeItem(itName) then
                    table.insert(list, {
                        Key = itName,
                        Name = itName,
                        Count = num,
                        Total = num,
                        Kind = "Misc",
                        Category = "Other",
                        Emoji = "📦",
                        MaxCap = TradeTimingConfig.MaxStackCap
                    })
                end
            end
        end
    
        table.sort(list, function(a, b) return a.Name < b.Name end)
        return list
    end
    
    -- ========================================================================

-- ═══════════════════════════════════════════════
-- ⚙️ DUNGEON & ACTION HELPER FUNCTIONS
-- ═══════════════════════════════════════════════
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

-- Helper สำหรับเปิด Colossus Crates (Petalfall Crate, Tidewreck Crate ฯลฯ)
local function TriggerOpenPetalfallCrate()
    local d2 = SafeGetData2()
    local mg = d2 and d2.MineGame
    local cc = mg and mg.ColossusCrates
    if not cc then
        UpdateStatus("ℹ️ ไม่มี Colossus Crate ในคลัง")
        return
    end

    local openedAny = false
    for crateName, countVal in pairs(cc) do
        local count = tonumber(countVal) or 0
        if count > 0 then
            openedAny = true
            local openAmount = math.clamp(count, 1, 50)
            UpdateStatus(string.format("📦 เปิด %s (%d/%d กล่อง)...", tostring(crateName), openAmount, count))
            SafeSendEvent(Config.Events.OpenColossusCrate, crateName, openAmount)
            HumanWait(0.4, 0.6)
            UpdateStatus(string.format("✅ เปิด %s %d กล่องสำเร็จ!", tostring(crateName), openAmount))
        end
    end
    if not openedAny then
        UpdateStatus("ℹ️ ไม่มี Colossus Crate ในคลัง")
    elseif Config.AutoEquipBest then
        TriggerEquipBest()
    end
end

-- Helper สำหรับส่งคำสั่งสวมใส่ตัวละครที่ดีที่สุดไปยัง Server
local function TriggerEquipBest()
    UpdateStatus("👥 สวมใส่ตัวที่ดีที่สุด...")
    SafeSendEvent(Config.Events.EquipBest)
    HumanWait(0.2, 0.3)
end

-- Helper สำหรับอัปเกรดผังสกิลทั้งหมดที่มีในโซนที่ปลดล็อกทันที
local function TriggerUpgradeAllSkillTrees()
    local d = SafeGetData()
    local d2 = SafeGetData2()
    local mg = d2 and d2.MineGame
    if not (mg and MineConfig and MineConfig.GetSkillNodes) then return end

    local myMoney = tonumber(d.Money) or 0
    local totalBought = 0

    local zonesToCheck = {}
    local curZone = mg.CurrentZone or 1
    table.insert(zonesToCheck, "Z" .. curZone)
    for z = 14, 1, -1 do
        local zk = "Z" .. z
        if zk ~= ("Z" .. curZone) and (mg.UnlockedZones and mg.UnlockedZones[zk]) then
            table.insert(zonesToCheck, zk)
        end
    end

    for _, zKey in ipairs(zonesToCheck) do
        local zSkills = (mg.Skills and mg.Skills[zKey]) or {}
        local nodes = MineConfig.GetSkillNodes(zKey)
        if nodes then
            for _, node in ipairs(nodes) do
                local isOpen = MineConfig.IsSkillNodeOpen and MineConfig.IsSkillNodeOpen(zSkills, node)
                local isMaxed = MineConfig.IsSkillNodeMaxed and MineConfig.IsSkillNodeMaxed(zSkills, node)
                local curLvl = zSkills[node.Family] or 0
                local cost = MineConfig.GetSkillCost and MineConfig.GetSkillCost(zKey, curLvl, node.Family)

                myMoney = tonumber(SafeGetData().Money) or 0
                if isOpen and not isMaxed and cost and myMoney >= cost then
                    SafeSendEvent(Config.Events.SkillTreeSection, zKey)
                    UpdateStatus("🌳 อัปต้นไม้: " .. (node.Name or node.Id or "Node"))
                    SafeSendEvent(Config.Events.BuySkill, zKey, node.Family, node.Id)
                    zSkills[node.Family] = curLvl + 1
                    totalBought = totalBought + 1
                    HumanWait(0.08, 0.12)
                end
            end
        end
    end

    if totalBought > 0 then
        UpdateStatus(string.format("✅ อัปเกรดผังสกิลสำเร็จรวม %d โหนด!", totalBought))
    else
        UpdateStatus("ℹ️ ไม่มีสกิลที่พร้อมอัปเกรด (เงินไม่พอหรืออัปเต็มแล้ว)")
    end
end

-- Helper สำหรับอัปเกรดสถิติคนงานทั้งหมดให้ตันทันที
local function TriggerUpgradeAllMinersMax()
    local d2 = SafeGetData2()
    local mg = d2 and d2.MineGame
    local holders = mg and mg.Holders
    if not (holders and Items and MineConfig) then return end

    local count = 0
    for slotKey, h in pairs(holders) do
        if h and h.CharName then
            local item = Items.GetItemData(h.CharName)
            if item then
                -- 1. Damage (อัปจนถึง 200)
                local curLvl = h.CharLevel or 1
                if curLvl < 200 then
                    local curMoney = tonumber(SafeGetData().Money) or 0
                    local cost = MineConfig.GetCharacterUpgradeCost and MineConfig.GetCharacterUpgradeCost(curLvl, item)
                    if cost and curMoney >= cost then
                        UpdateStatus(string.format("⚔️ อัป Max DMG %s...", slotKey))
                        SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "Damage", true)
                        count = count + 1
                        HumanWait(0.08, 0.12)
                    end
                end

                -- 2. Speed (อัปจนถึง 17)
                local curSpd = h.CharSpeedLevel or 1
                local maxSpd = MineConfig.CharSpeedMaxLevel or 17
                if curSpd < maxSpd then
                    local curMoney = tonumber(SafeGetData().Money) or 0
                    local cost = MineConfig.GetCharacterSpeedUpgradeCost and MineConfig.GetCharacterSpeedUpgradeCost(curSpd, item)
                    if cost and curMoney >= cost then
                        UpdateStatus(string.format("⚡ อัป Max Speed %s...", slotKey))
                        SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "Speed", true)
                        count = count + 1
                        HumanWait(0.08, 0.12)
                    end
                end

                -- 3. MineSpeed (อัปจนถึง 16)
                local curMineSpd = h.CharMineSpeedLevel or 1
                local maxMineSpd = MineConfig.CharMineSpeedMaxLevel or 16
                if curMineSpd < maxMineSpd then
                    local curMoney = tonumber(SafeGetData().Money) or 0
                    local cost = MineConfig.GetCharacterMineSpeedUpgradeCost and MineConfig.GetCharacterMineSpeedUpgradeCost(curMineSpd, item)
                    if cost and curMoney >= cost then
                        UpdateStatus(string.format("⛏️ อัป Max MineSpeed %s...", slotKey))
                        SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "MineSpeed", true)
                        count = count + 1
                        HumanWait(0.08, 0.12)
                    end
                end
            end
        end
    end
    if count > 0 then
        UpdateStatus("✅ สั่งอัปเกรดสถิติคนงานให้ตันเรียบร้อย!")
    else
        UpdateStatus("ℹ️ สถิติคนงานตันทั้งหมดแล้ว หรือเงินไม่พอ")
    end
end

-- ═══════════════════════════════════════════════
-- 📋 สร้างเมนูจัดหมวดหมู่ UI ใหม่ (6 หมวดหมู่ ใช้งานง่าย & สะดวก)
-- ═══════════════════════════════════════════════

-- 🎨 UNIFIED HUB UI (KUYKUY ANIME MINE V17)
-- ═══════════════════════════════════════════════
-- 🧹 ทำความสะอาด UI เวอร์ชันเก่าทั้งใน CoreGui และ PlayerGui
local TargetParent = PlayerGui
pcall(function()
    local cg = game:GetService("CoreGui")
    local test = Instance.new("Folder")
    test.Parent = cg
    test:Destroy()
    TargetParent = cg
end)

local function CleanOldGuis(parentObj)
    if not parentObj then return end
    pcall(function()
        for _, oldName in ipairs({
            "AnimeMineAutoFarmV1", "AnimeMineAutoFarmV2", "AnimeMineAutoFarmV3", "AnimeMineAutoFarmV4",
            "AnimeMineAutoFarmV5", "AnimeMineAutoFarmV6", "AnimeMineAutoFarmV7", "AnimeMineAutoFarmV8",
            "AnimeMineAutoFarmV9", "AnimeMineAutoFarmV10", "AnimeMineAutoFarmV11", "AnimeMineAutoFarmV12",
            "AnimeMineAutoFarmV13", "AnimeMineAutoFarmV14", "AnimeMineAutoFarmV15", "AnimeMineAutoFarmV16",
            "MineTradeSelectiveUI", "AnimeMineHubUnified"
        }) do
            local oldGui = parentObj:FindFirstChild(oldName)
            if oldGui then oldGui:Destroy() end
        end
    end)
end

CleanOldGuis(PlayerGui)
pcall(function() CleanOldGuis(game:GetService("CoreGui")) end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AnimeMineHubUnified"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = TargetParent

local Theme = {
    Background = Color3.fromRGB(18, 18, 26),
    Header = Color3.fromRGB(26, 22, 38),
    Sidebar = Color3.fromRGB(22, 20, 32),
    SidebarBtn = Color3.fromRGB(28, 26, 40),
    SidebarBtnActive = Color3.fromRGB(115, 65, 210),
    ContentBG = Color3.fromRGB(15, 15, 22),
    Card = Color3.fromRGB(25, 25, 38),
    CardHover = Color3.fromRGB(32, 32, 48),
    InputBG = Color3.fromRGB(14, 14, 20),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(155, 155, 180),
    ToggleOn = Color3.fromRGB(46, 204, 113),
    ToggleOff = Color3.fromRGB(231, 76, 60),
    Accent = Color3.fromRGB(145, 80, 240),
    AccentHover = Color3.fromRGB(165, 100, 255),
    Border = Color3.fromRGB(65, 45, 105),
    BadgeBG = Color3.fromRGB(36, 30, 56),
    SpecialBtn = Color3.fromRGB(230, 126, 34),
    RedBtn = Color3.fromRGB(190, 45, 45),
    GreenBtn = Color3.fromRGB(45, 160, 90),
    ChipActive = Color3.fromRGB(142, 68, 173),
    ChipInactive = Color3.fromRGB(36, 36, 52),
    ChipLocked = Color3.fromRGB(39, 174, 96),
}

-- -------------------------------------------------------------
-- [1] MAIN FRAME & FLOATING TOGGLE
-- -------------------------------------------------------------
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 420)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -210)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ZIndex = 100
MainFrame.Parent = ScreenGui

-- เชื่อมโยง TradeMainFrame เดิมให้ชี้มาที่ MainFrame เพื่อความเข้ากันได้
TradeMainFrame = MainFrame

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.6
MainStroke.Color = Theme.Border
MainStroke.Parent = MainFrame

-- Floating Icon Button (ปุ่มกลมลอยพับเก็บ-เปิดหน้าจอได้สะดวกรวดเร็วบนมือถือ/UGPhone/PC)
local FloatingIconBtn = Instance.new("TextButton")
FloatingIconBtn.Name = "FloatingIconBtn"
FloatingIconBtn.Size = UDim2.new(0, 42, 0, 42)
FloatingIconBtn.Position = UDim2.new(0, 18, 0.5, -21)
FloatingIconBtn.BackgroundColor3 = Theme.Accent
FloatingIconBtn.Text = "⛏️"
FloatingIconBtn.TextSize = 20
FloatingIconBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatingIconBtn.Font = Enum.Font.GothamBold
FloatingIconBtn.Active = true
FloatingIconBtn.Draggable = true
FloatingIconBtn.ZIndex = 1000
FloatingIconBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatingIconBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Thickness = 1.5
FloatStroke.Color = Color3.fromRGB(200, 160, 255)
FloatStroke.Parent = FloatingIconBtn

FloatingIconBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- -------------------------------------------------------------
-- [2] HEADER
-- -------------------------------------------------------------
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Theme.Header
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 10)
HeaderFix.Position = UDim2.new(0, 0, 1, -10)
HeaderFix.BackgroundColor3 = Theme.Header
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 240, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⛏️ KUYKUY HUB | Anime Mine V17"
Title.TextColor3 = Theme.Text
Title.TextSize = 13.5
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local StatusBadge = Instance.new("TextLabel")
StatusBadge.Name = "StatusBadge"
StatusBadge.Size = UDim2.new(0, 180, 0, 24)
StatusBadge.Position = UDim2.new(1, -260, 0.5, -12)
StatusBadge.BackgroundColor3 = Theme.BadgeBG
StatusBadge.Text = "🟢 ระบบพร้อมทำงาน"
StatusBadge.TextColor3 = Theme.ToggleOn
StatusBadge.TextSize = 10.5
StatusBadge.Font = Enum.Font.GothamMedium
StatusBadge.Parent = Header

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(0, 6)
BadgeCorner.Parent = StatusBadge

local function UpdateStatus(text)
    if StatusBadge then
        StatusBadge.Text = text
    end
end

local isMinimized = false
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -64, 0.5, -13)
MinBtn.BackgroundColor3 = Color3.fromRGB(48, 48, 65)
MinBtn.Text = "—"
MinBtn.TextColor3 = Theme.Text
MinBtn.TextSize = 14
MinBtn.Font = Enum.Font.GothamBold
MinBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MinBtn.Text = isMinimized and "+" or "—"
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
        Size = isMinimized and UDim2.new(0, 560, 0, 44) or UDim2.new(0, 560, 0, 420)
    }):Play()
end)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Theme.RedBtn
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Theme.Text
CloseBtn.TextSize = 12
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- -------------------------------------------------------------
-- [3] SIDEBAR & TAB PAGES SETUP
-- -------------------------------------------------------------
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 136, 1, -54)
Sidebar.Position = UDim2.new(0, 8, 0, 48)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 8)
SidebarCorner.Parent = Sidebar

local SidebarLayout = Instance.new("UIListLayout")
SidebarLayout.Padding = UDim.new(0, 5)
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
SidebarLayout.Parent = Sidebar

local SidebarPad = Instance.new("UIPadding")
SidebarPad.PaddingTop = UDim.new(0, 8)
SidebarPad.PaddingLeft = UDim.new(0, 6)
SidebarPad.PaddingRight = UDim.new(0, 6)
SidebarPad.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -158, 1, -54)
ContentArea.Position = UDim2.new(0, 150, 0, 48)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local TabButtons = {}
local TabPages = {}
local CurrentActiveTab = "Farming"

local function CreateTabPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = "Tab_" .. name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = false
    page.Parent = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingRight = UDim.new(0, 6)
    pad.PaddingTop = UDim.new(0, 2)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = page

    TabPages[name] = page
    return page
end

local function SwitchTab(tabName)
    CurrentActiveTab = tabName
    for name, page in pairs(TabPages) do
        page.Visible = (name == tabName)
    end
    for name, data in pairs(TabButtons) do
        local isActive = (name == tabName)
        data.Btn.BackgroundColor3 = isActive and Theme.SidebarBtnActive or Theme.SidebarBtn
        data.Btn.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Theme.SubText
        data.Indicator.Visible = isActive
    end
end

local function CreateTabNavButton(tabKey, tabLabel, icon, order)
    local btn = Instance.new("TextButton")
    btn.Name = "Nav_" .. tabKey
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Theme.SidebarBtn
    btn.Text = "   " .. icon .. " " .. tabLabel
    btn.TextColor3 = Theme.SubText
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.LayoutOrder = order
    btn.Parent = Sidebar

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0, 18)
    indicator.Position = UDim2.new(0, 3, 0.5, -9)
    indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.Parent = btn

    local indCorner = Instance.new("UICorner")
    indCorner.CornerRadius = UDim.new(1, 0)
    indCorner.Parent = indicator

    TabButtons[tabKey] = { Btn = btn, Indicator = indicator }

    btn.MouseButton1Click:Connect(function()
        SwitchTab(tabKey)
    end)
end

-- สร้างเมนูนำทางใน Sidebar 5 หมวดหมู่
CreateTabNavButton("Farming", "ฟาร์ม & ขาย", "⛏️", 1)
CreateTabNavButton("Workers", "คนงาน & สกิล", "👥", 2)
CreateTabNavButton("Dungeon", "ดันเจี้ยน & กาชา", "⚔️", 3)
CreateTabNavButton("Trade", "ระบบเทรด", "🤝", 4)
CreateTabNavButton("Settings", "ตั้งค่าระบบ", "⚙️", 5)

local TabFarming = CreateTabPage("Farming")
local TabWorkers = CreateTabPage("Workers")
local TabDungeon = CreateTabPage("Dungeon")
local TabTrade = CreateTabPage("Trade")
local TabSettings = CreateTabPage("Settings")

local StartTradeBtn = nil
local CancelTradeBtn = nil
local TradeSwitchBadge = nil
local TradeCloseBtn = nil
local TradeMainToggleBtn = nil
local ItemCountLabel = nil
local ItemScrollBox = nil
local StatusBar = nil

-- -------------------------------------------------------------
-- [4] UI BUILDER HELPERS
-- -------------------------------------------------------------
local ToggleControls = {}

local function AddSectionHeader(title, parentTab, order)
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundColor3 = Theme.BadgeBG
    header.BorderSizePixel = 0
    header.LayoutOrder = order or 0
    header.Parent = parentTab

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = header

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = Theme.Accent
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = header
    return header
end

local function AddToggle(key, name, desc, parentTab, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 42)
    Frame.BackgroundColor3 = Theme.Card
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order or 0
    Frame.Parent = parentTab

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = Frame

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -65, 0, 18)
    tLbl.Position = UDim2.new(0, 10, 0, 4)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = name
    tLbl.TextColor3 = Theme.Text
    tLbl.TextSize = 11.5
    tLbl.Font = Enum.Font.GothamSemibold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = Frame

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -65, 0, 14)
    dLbl.Position = UDim2.new(0, 10, 0, 22)
    dLbl.BackgroundTransparency = 1
    dLbl.Text = desc
    dLbl.TextColor3 = Theme.SubText
    dLbl.TextSize = 9.5
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.Parent = Frame

    local Switch = Instance.new("Frame")
    Switch.Size = UDim2.new(0, 36, 0, 18)
    Switch.Position = UDim2.new(1, -44, 0.5, -9)
    Switch.BackgroundColor3 = Config[key] and Theme.ToggleOn or Theme.ToggleOff
    Switch.BorderSizePixel = 0
    Switch.Parent = Frame

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(1, 0)
    sCorner.Parent = Switch

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.Position = Config[key] and UDim2.new(0, 19, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
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
            Position = val and UDim2.new(0, 19, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
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

local function AddActionButton(name, desc, btnText, btnColor, callback, parentTab, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 42)
    Frame.BackgroundColor3 = Theme.Card
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order or 0
    Frame.Parent = parentTab

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = Frame

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -115, 0, 18)
    tLbl.Position = UDim2.new(0, 10, 0, 4)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = name
    tLbl.TextColor3 = Theme.Text
    tLbl.TextSize = 11.5
    tLbl.Font = Enum.Font.GothamSemibold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = Frame

    local dLbl = Instance.new("TextLabel")
    dLbl.Size = UDim2.new(1, -115, 0, 14)
    dLbl.Position = UDim2.new(0, 10, 0, 22)
    dLbl.BackgroundTransparency = 1
    dLbl.Text = desc
    dLbl.TextColor3 = Theme.SubText
    dLbl.TextSize = 9.5
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.Parent = Frame

    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0, 95, 0, 26)
    Btn.Position = UDim2.new(1, -102, 0.5, -13)
    Btn.BackgroundColor3 = btnColor or Theme.SpecialBtn
    Btn.Text = btnText
    Btn.TextColor3 = Theme.Text
    Btn.TextSize = 11
    Btn.Font = Enum.Font.GothamBold
    Btn.BorderSizePixel = 0
    Btn.Parent = Frame

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = Btn

    Btn.MouseButton1Click:Connect(callback)
    return Frame
end

local function AddLevelCapCustomInput(title, configKey, minVal, maxVal, step, parentTab, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 42)
    Frame.BackgroundColor3 = Theme.Card
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order or 0
    Frame.Parent = parentTab

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = Frame

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(0, 180, 1, 0)
    tLbl.Position = UDim2.new(0, 10, 0, 0)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = title
    tLbl.TextColor3 = Theme.Text
    tLbl.TextSize = 11
    tLbl.Font = Enum.Font.GothamSemibold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = Frame

    local currentVal = tonumber(Config[configKey]) or maxVal

    local ControlsContainer = Instance.new("Frame")
    ControlsContainer.Size = UDim2.new(0, 160, 0, 26)
    ControlsContainer.Position = UDim2.new(1, -168, 0.5, -13)
    ControlsContainer.BackgroundTransparency = 1
    ControlsContainer.Parent = Frame

    local MinusBtn = Instance.new("TextButton")
    MinusBtn.Size = UDim2.new(0, 24, 1, 0)
    MinusBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    MinusBtn.Text = "-"
    MinusBtn.TextColor3 = Theme.Text
    MinusBtn.TextSize = 13
    MinusBtn.Font = Enum.Font.GothamBold
    MinusBtn.Parent = ControlsContainer

    local mCorner = Instance.new("UICorner")
    mCorner.CornerRadius = UDim.new(0, 4)
    mCorner.Parent = MinusBtn

    local ValBox = Instance.new("TextBox")
    ValBox.Size = UDim2.new(0, 50, 1, 0)
    ValBox.Position = UDim2.new(0, 28, 0, 0)
    ValBox.BackgroundColor3 = Theme.InputBG
    ValBox.Text = tostring(currentVal)
    ValBox.TextColor3 = Color3.fromRGB(240, 200, 90)
    ValBox.Font = Enum.Font.GothamBold
    ValBox.TextSize = 11
    ValBox.ClearTextOnFocus = false
    ValBox.Parent = ControlsContainer

    local vCorner = Instance.new("UICorner")
    vCorner.CornerRadius = UDim.new(0, 4)
    vCorner.Parent = ValBox

    local PlusBtn = Instance.new("TextButton")
    PlusBtn.Size = UDim2.new(0, 24, 1, 0)
    PlusBtn.Position = UDim2.new(0, 82, 0, 0)
    PlusBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    PlusBtn.Text = "+"
    PlusBtn.TextColor3 = Theme.Text
    PlusBtn.TextSize = 13
    PlusBtn.Font = Enum.Font.GothamBold
    PlusBtn.Parent = ControlsContainer

    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 4)
    pCorner.Parent = PlusBtn

    local MaxBtn = Instance.new("TextButton")
    MaxBtn.Size = UDim2.new(0, 45, 1, 0)
    MaxBtn.Position = UDim2.new(0, 110, 0, 0)
    MaxBtn.BackgroundColor3 = Theme.Accent
    MaxBtn.Text = "ตัน"
    MaxBtn.TextColor3 = Theme.Text
    MaxBtn.TextSize = 10.5
    MaxBtn.Font = Enum.Font.GothamBold
    MaxBtn.Parent = ControlsContainer

    local maxCorner = Instance.new("UICorner")
    maxCorner.CornerRadius = UDim.new(0, 4)
    maxCorner.Parent = MaxBtn

    local function ApplyValue(v)
        local clamped = math.clamp(math.floor(v), minVal, maxVal)
        currentVal = clamped
        Config[configKey] = clamped
        ValBox.Text = tostring(clamped)
        SaveConfig()
    end

    MinusBtn.MouseButton1Click:Connect(function() ApplyValue(currentVal - step) end)
    PlusBtn.MouseButton1Click:Connect(function() ApplyValue(currentVal + step) end)
    MaxBtn.MouseButton1Click:Connect(function() ApplyValue(maxVal) end)

    ValBox.FocusLost:Connect(function()
        local num = tonumber(ValBox.Text)
        if num then ApplyValue(num) else ValBox.Text = tostring(currentVal) end
    end)
    return Frame
end

local function AddUnifiedSellDropdown(parentTab, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 44)
    Frame.BackgroundColor3 = Theme.Card
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order or 0
    Frame.ClipsDescendants = true
    Frame.Parent = parentTab

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = Frame

    local TopBar = Instance.new("TextButton")
    TopBar.Size = UDim2.new(1, 0, 0, 44)
    TopBar.BackgroundTransparency = 1
    TopBar.Text = ""
    TopBar.Parent = Frame

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -40, 0, 18)
    tLbl.Position = UDim2.new(0, 10, 0, 5)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = "💎 เลือกระดับที่จะขาย (Unified Sell Options)"
    tLbl.TextColor3 = Theme.Text
    tLbl.TextSize = 11.5
    tLbl.Font = Enum.Font.GothamSemibold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = TopBar

    local SummaryLbl = Instance.new("TextLabel")
    SummaryLbl.Size = UDim2.new(1, -40, 0, 14)
    SummaryLbl.Position = UDim2.new(0, 10, 0, 24)
    SummaryLbl.BackgroundTransparency = 1
    SummaryLbl.Text = "กำลังโหลดการตั้งค่า..."
    SummaryLbl.TextColor3 = Color3.fromRGB(180, 140, 255)
    SummaryLbl.TextSize = 9.5
    SummaryLbl.Font = Enum.Font.Gotham
    SummaryLbl.TextXAlignment = Enum.TextXAlignment.Left
    SummaryLbl.Parent = TopBar

    local ArrowLbl = Instance.new("TextLabel")
    ArrowLbl.Size = UDim2.new(0, 30, 0, 30)
    ArrowLbl.Position = UDim2.new(1, -34, 0, 7)
    ArrowLbl.BackgroundTransparency = 1
    ArrowLbl.Text = "▼"
    ArrowLbl.TextColor3 = Theme.SubText
    ArrowLbl.TextSize = 10
    ArrowLbl.Font = Enum.Font.GothamBold
    ArrowLbl.Parent = TopBar

    local ChipContainer = Instance.new("Frame")
    ChipContainer.Size = UDim2.new(1, -20, 0, 120)
    ChipContainer.Position = UDim2.new(0, 10, 0, 48)
    ChipContainer.BackgroundTransparency = 1
    ChipContainer.Parent = Frame

    local chipLayout = Instance.new("UIGridLayout")
    chipLayout.CellSize = UDim2.new(0, 85, 0, 24)
    chipLayout.CellPadding = UDim2.new(0, 4, 0, 4)
    chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
    chipLayout.Parent = ChipContainer

    local chipDefinitions = {
        { Key = "Ores", Name = "🪨 แร่ทั้งหมด", Locked = false },
        { Key = "OldPickaxes", Name = "⛏️ ขวานเก่า", Locked = false },
        { Key = "Common", Name = "Common", Locked = false },
        { Key = "Uncommon", Name = "Uncommon", Locked = false },
        { Key = "Rare", Name = "Rare", Locked = false },
        { Key = "Epic", Name = "Epic", Locked = false },
        { Key = "Legendary", Name = "Legendary", Locked = false },
        { Key = "Mythical", Name = "Mythical", Locked = false },
        { Key = "Exotic", Name = "Exotic", Locked = false },
        { Key = "OldZoneChars", Name = "👥 ตัวโซนเก่า", Locked = false },
    }

    local chipButtons = {}

    local function UpdateSummary()
        local activeList = {}
        for _, def in ipairs(chipDefinitions) do
            if Config.SellOptions and Config.SellOptions[def.Key] then
                table.insert(activeList, def.Name)
            end
        end
        if #activeList == 0 then
            SummaryLbl.Text = "ยังไม่ได้เลือกรายการขายใดๆ"
            SummaryLbl.TextColor3 = Theme.SubText
        else
            SummaryLbl.Text = table.concat(activeList, ", ")
            SummaryLbl.TextColor3 = Color3.fromRGB(180, 140, 255)
        end
    end

    for idx, def in ipairs(chipDefinitions) do
        local chip = Instance.new("TextButton")
        chip.Size = UDim2.new(0, 85, 0, 24)
        chip.Font = Enum.Font.GothamBold
        chip.TextSize = 9.5
        chip.LayoutOrder = idx
        chip.Parent = ChipContainer

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 4)
        cCorner.Parent = chip

        local isSel = Config.SellOptions and Config.SellOptions[def.Key]
        chip.BackgroundColor3 = isSel and Theme.ChipActive or Theme.ChipInactive
        chip.TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or Theme.SubText
        chip.Text = (isSel and "✓ " or "") .. def.Name

        chip.MouseButton1Click:Connect(function()
            if not Config.SellOptions then Config.SellOptions = {} end
            Config.SellOptions[def.Key] = not Config.SellOptions[def.Key]
            local newSel = Config.SellOptions[def.Key]
            chip.BackgroundColor3 = newSel and Theme.ChipActive or Theme.ChipInactive
            chip.TextColor3 = newSel and Color3.fromRGB(255, 255, 255) or Theme.SubText
            chip.Text = (newSel and "✓ " or "") .. def.Name
            UpdateSummary()
            SaveConfig()
        end)
        chipButtons[def.Key] = chip
    end

    UpdateSummary()

    local isExpanded = false
    TopBar.MouseButton1Click:Connect(function()
        isExpanded = not isExpanded
        ArrowLbl.Text = isExpanded and "▲" or "▼"
        TweenService:Create(Frame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            Size = isExpanded and UDim2.new(1, 0, 0, 175) or UDim2.new(1, 0, 0, 44)
        }):Play()
    end)
    return Frame
end

local function AddMultiSlotSelector(parentTab, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 84)
    Frame.BackgroundColor3 = Theme.Card
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order or 0
    Frame.Parent = parentTab

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = Frame

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -20, 0, 16)
    tLbl.Position = UDim2.new(0, 10, 0, 6)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = "🎯 เลือก Slot แท่นขุดที่ต้องการสุ่มบัพ (ติ๊กได้หลายช่อง S1-S12):"
    tLbl.TextColor3 = Theme.Text
    tLbl.TextSize = 10.5
    tLbl.Font = Enum.Font.GothamSemibold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = Frame

    local SlotContainer = Instance.new("Frame")
    SlotContainer.Size = UDim2.new(1, -20, 0, 52)
    SlotContainer.Position = UDim2.new(0, 10, 0, 26)
    SlotContainer.BackgroundTransparency = 1
    SlotContainer.Parent = Frame

    local sGrid = Instance.new("UIGridLayout")
    sGrid.CellSize = UDim2.new(0.155, 0, 0, 23)
    sGrid.CellPadding = UDim2.new(0.014, 0, 0, 4)
    sGrid.Parent = SlotContainer

    for s = 1, 12 do
        local slotKey = "M" .. s
        local sBtn = Instance.new("TextButton")
        sBtn.Font = Enum.Font.GothamBold
        sBtn.TextSize = 10
        sBtn.Parent = SlotContainer

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = sBtn

        local isChecked = Config.MutationSlots and (Config.MutationSlots[slotKey] == true or Config.MutationSlots[s] == true)
        sBtn.BackgroundColor3 = isChecked and Theme.ChipActive or Theme.ChipInactive
        sBtn.TextColor3 = isChecked and Color3.fromRGB(255, 255, 255) or Theme.SubText
        sBtn.Text = (isChecked and "✓ " or "") .. "S" .. s

        sBtn.MouseButton1Click:Connect(function()
            if not Config.MutationSlots then Config.MutationSlots = {} end
            local cur = not (Config.MutationSlots[slotKey] == true or Config.MutationSlots[s] == true)
            Config.MutationSlots[slotKey] = cur
            Config.MutationSlots[s] = cur
            sBtn.BackgroundColor3 = cur and Theme.ChipActive or Theme.ChipInactive
            sBtn.TextColor3 = cur and Color3.fromRGB(255, 255, 255) or Theme.SubText
            sBtn.Text = (cur and "✓ " or "") .. "S" .. s
            SaveConfig()
        end)
    end
    return Frame
end

local function AddMultiMutationSelector(parentTab, order)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 172)
    Frame.BackgroundColor3 = Theme.Card
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = order or 0
    Frame.Parent = parentTab

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = Frame

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -20, 0, 16)
    tLbl.Position = UDim2.new(0, 10, 0, 6)
    tLbl.BackgroundTransparency = 1
    tLbl.Text = "✨ เลือกบัพที่ยอมรับและหยุดสุ่มเมื่อได้ (ติ๊กได้หลายบัพ):"
    tLbl.TextColor3 = Theme.Text
    tLbl.TextSize = 10.5
    tLbl.Font = Enum.Font.GothamSemibold
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = Frame

    local MutContainer = Instance.new("Frame")
    MutContainer.Size = UDim2.new(1, -20, 0, 138)
    MutContainer.Position = UDim2.new(0, 10, 0, 26)
    MutContainer.BackgroundTransparency = 1
    MutContainer.Parent = Frame

    local gLayout = Instance.new("UIGridLayout")
    gLayout.CellSize = UDim2.new(0.485, 0, 0, 24)
    gLayout.CellPadding = UDim2.new(0.03, 0, 0, 4)
    gLayout.Parent = MutContainer

    local mutations = {
        { key = "Bronze", label = "บรอนซ์ (1.37X)" },
        { key = "Diamond", label = "เพชร (2.12X)" },
        { key = "Platinum", label = "แพลตตินัม (3.23X)" },
        { key = "Rainbow", label = "สายรุ้ง (4.72X)" },
        { key = "Frozen", label = "แช่แข็ง (11.41X)" },
        { key = "Inferno", label = "นรก (22.56X)" },
        { key = "Nightmare", label = "ฝันร้าย (40X)" },
        { key = "Unreal", label = "ไม่จริง (80X)" },
        { key = "Unleashed", label = "ปลดปล่อย (120X)" },
        { key = "Paradox", label = "พาราด็อกซ์ (160X)" }
    }

    for _, mData in ipairs(mutations) do
        local mKey = mData.key
        local mLabel = mData.label
        local mBtn = Instance.new("TextButton")
        mBtn.Font = Enum.Font.GothamBold
        mBtn.TextSize = 9.5
        mBtn.Parent = MutContainer

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = mBtn

        local isChecked = (Config.TargetMutations and Config.TargetMutations[mKey] == true) or (Config.Mutations and Config.Mutations[mKey] == true)
        mBtn.BackgroundColor3 = isChecked and Theme.ChipActive or Theme.ChipInactive
        mBtn.TextColor3 = isChecked and Color3.fromRGB(255, 255, 255) or Theme.SubText
        mBtn.Text = (isChecked and "✓ " or "") .. mLabel

        mBtn.MouseButton1Click:Connect(function()
            if not Config.TargetMutations then Config.TargetMutations = {} end
            if not Config.Mutations then Config.Mutations = {} end
            local cur = not ((Config.TargetMutations and Config.TargetMutations[mKey] == true) or (Config.Mutations and Config.Mutations[mKey] == true))
            Config.TargetMutations[mKey] = cur
            Config.Mutations[mKey] = cur
            mBtn.BackgroundColor3 = cur and Theme.ChipActive or Theme.ChipInactive
            mBtn.TextColor3 = cur and Color3.fromRGB(255, 255, 255) or Theme.SubText
            mBtn.Text = (cur and "✓ " or "") .. mLabel
            SaveConfig()
        end)
    end
    return Frame
end

-- -------------------------------------------------------------
-- [5] POPULATE TAB 1: ฟาร์ม & ขาย (FARMING & SELL)
-- -------------------------------------------------------------
AddSectionHeader("📦 ระบบฟาร์มหลัก (Main Farming)", TabFarming, 1)
AddToggle("AutoMine", "Auto Mine (ขุดหินในแปลง)", "ค้นหาและขุดหินในแปลง รวมถึงหินทดสอบอินฟินิตี้ก่อนเสมอ", TabFarming, 2)
AddToggle("AutoChest", "Auto Take Chest (ดูดแร่จากหีบ)", "ดูดแร่จากหีบเข้ากระเป๋าอัตโนมัติเมื่อหินแตก", TabFarming, 3)
AddToggle("AutoBuyZone", "Auto Unlock New Zone (ปลดล็อคโซนใหม่)", "ซื้อและปลดล็อกโซนใหม่ที่ ZoneBoard เมื่อวิจัยครบ", TabFarming, 4)
AddToggle("AutoBuyBestPickaxe", "Auto Buy Best Pickaxe (ซื้อขวานดีสุดที่ปลดล็อค)", "ซื้อแค่อันสุดท้ายที่ดีที่สุดที่ปลดล็อคเมื่อพร้อมเท่านั้น", TabFarming, 5)

AddSectionHeader("💰 ระบบขายรวมอัจฉริยะ (Unified Auto-Sell)", TabFarming, 6)
AddToggle("AutoSell", "Auto Sell (ระบบขายอัตโนมัติรวม)", "วาร์ปไปขายแร่, ขวานเก่า และตัวละครตามที่เลือกในดรอปดาวน์", TabFarming, 7)
AddUnifiedSellDropdown(TabFarming, 8)
AddActionButton("💰 วาร์ปไปขายทันที (ตามที่เลือก)", "วาร์ปไปร้านขายแร่ ขายทุกอย่างที่ติ๊กเลือกไว้ในดรอปดาวน์ทันที", "ขายทันที", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(function()
            local d2 = SafeGetData2()
            local mg = d2 and d2.MineGame
            local sellKeys = GetUnifiedSellKeys(mg)
            if #sellKeys == 0 then
                UpdateStatus("ℹ️ ไม่มีไอเทมตามที่เลือกให้ขาย")
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
                UpdateStatus(string.format("💰 ขายไอเทมที่เลือก (%d รายการ)...", #sellKeys))
                char:PivotTo(sellStand:GetPivot() + Vector3.new(0, 3, 5))
                HumanWait(0.35, 0.5)

                -- ส่งคำสั่งขายแบบ Batch ปลอดภัย (ครั้งละ 50 คีย์)
                for i = 1, #sellKeys, 50 do
                    local batch = {}
                    for j = i, math.min(i + 49, #sellKeys) do
                        table.insert(batch, sellKeys[j])
                    end
                    SafeSendEvent(Config.Events.SellItems, batch)
                    HumanWait(0.25, 0.35)
                end

                if returnPlot then
                    char:PivotTo(returnPlot)
                    HumanWait(0.2, 0.3)
                end
                UpdateStatus(string.format("✅ ขายสำเร็จ %d รายการ!", #sellKeys))
            end
        end)
        if not ok then
            warn(string.format("⚠️ [Action Error: UnifiedSellNow] %s", tostring(err)))
        end
    end)
end, TabFarming, 9)

-- -------------------------------------------------------------
-- [6] POPULATE TAB 2: คนงาน & สกิล (WORKERS & SKILLS)
-- -------------------------------------------------------------
AddSectionHeader("🌳 ผังสกิล & อัปเกรด (Skill Tree & Core)", TabWorkers, 1)
AddToggle("AutoUpgradeTree", "Auto Zone Skill Tree (อัปเกรดผังสกิล)", "อัปเกรดผังสกิลของทุกโซนที่ปลดล็อกตามลำดับโหนด (Batch Upgrades)", TabWorkers, 2)
AddToggle("AutoUpgradeCore", "Auto Core Upgrades (แกนหลัก)", "อัปเกรด Tap Level และ Miner Slots ในแกนหลัก", TabWorkers, 3)
AddActionButton("⚡ อัปเกรดผังสกิลทั้งหมดทันที", "ส่งคำสั่งซื้อผังสกิลทุกโหนดที่เงินพอในทุกโซนที่ปลดล็อกทันที", "อัปผังสกิลทันที", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerUpgradeAllSkillTrees)
        if not ok then warn(string.format("⚠️ [Action Error: UpgradeAllSkillTrees] %s", tostring(err))) end
    end)
end, TabWorkers, 4)

AddSectionHeader("👥 คนงาน & สถิติตัวละคร (Miners & Stats)", TabWorkers, 5)
AddToggle("AutoEquipBest", "Auto Equip Best (ใส่ตัวดีที่สุด)", "ใส่ตัวละครที่ดีที่สุดลงแท่นขุด (เว้นช่วง 20 วิ ไม่ส่งซ้ำ)", TabWorkers, 6)
AddActionButton("⚡ ใส่ตัวที่ดีที่สุดทันที", "ส่งคำสั่งสวมใส่ตัวละครที่ดีที่สุดลงแท่นขุดทันที", "สวมใส่ทันที", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerEquipBest)
        if ok then
            UpdateStatus("✅ สวมใส่ตัวที่ดีที่สุดสำเร็จ!")
        else
            warn(string.format("⚠️ [Action Error: EquipBest] %s", tostring(err)))
        end
    end)
end, TabWorkers, 7)
AddToggle("AutoUpgradeAllChars", "Auto Upgrade Characters (อัปสถิติ)", "อัปเกรดสถิติตัวละคร โดยให้ความสำคัญจากตัวที่เก่งสุดก่อน", TabWorkers, 8)
AddLevelCapCustomInput("⚔️ เป้าหมาย Damage (1-200 / ตัน):", "TargetLevelDamage", 1, 200, 5, TabWorkers, 9)
AddLevelCapCustomInput("⚡ เป้าหมาย Speed (1-17 / ตัน):", "TargetLevelSpeed", 1, 17, 1, TabWorkers, 10)
AddLevelCapCustomInput("⛏️ เป้าหมาย MineSpeed (1-16 / ตัน):", "TargetLevelMineSpeed", 1, 16, 1, TabWorkers, 11)
AddActionButton("⚡ อัปเกรดคนงานให้ตันทันที", "อัปเกรดสถิติคนงานทุกตัวให้ตันทันที (DMG 200, Speed 17, MineSpeed 16)", "อัปสถิติตันทันที", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerUpgradeAllMinersMax)
        if not ok then warn(string.format("⚠️ [Action Error: UpgradeAllMinersMax] %s", tostring(err))) end
    end)
end, TabWorkers, 12)

AddSectionHeader("🧬 การกลายพันธุ์ (Mutations)", TabWorkers, 13)
AddToggle("AutoMutation", "Auto Mutation Roll (เปิดค้างได้)", "สุ่มบัพตัวละครที่เลือกทีละตัว และสแตนด์บายเมื่อได้ครบ", TabWorkers, 14)
AddMultiSlotSelector(TabWorkers, 15)
AddMultiMutationSelector(TabWorkers, 16)

-- -------------------------------------------------------------
-- [7] POPULATE TAB 3: ดันเจี้ยน & กาชา (DUNGEON & GACHA)
-- -------------------------------------------------------------
AddSectionHeader("⚔️ ดันเจี้ยน & กล่องรางวัล (Trials & Crates)", TabDungeon, 1)
AddToggle("AutoInfinityTrial", "Auto Infinity Trial (ทดสอบอินฟินิตี้)", "ลงทดสอบและเคลมรับรางวัลอินฟินิตี้อัตโนมัติเมื่อพร้อม", TabDungeon, 2)
AddActionButton("⚡ ลง Infinity Trial ทันที", "สั่งเริ่มการทดสอบอินฟินิตี้รอบใหม่ทันที", "ลง Trial", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerInfinityTrial)
        if not ok then warn(string.format("⚠️ [Action Error: InfinityTrial] %s", tostring(err))) end
    end)
end, TabDungeon, 3)
AddActionButton("⚡ รับรางวัล Trial ทันที", "ตรวจสอบและกดรับรางวัล Infinity Trial ที่ผ่านเกณฑ์ทันที", "รับรางวัล", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerClaimTrial)
        if not ok then warn(string.format("⚠️ [Action Error: ClaimTrial] %s", tostring(err))) end
    end)
end, TabDungeon, 4)
AddToggle("AutoOpenPetalfallCrate", "Auto Open Colossus Crates", "เปิดกล่องบอส Colossus ทั้งหมด เช่น Petalfall & Tidewreck Crate อัตโนมัติ", TabDungeon, 5)
AddActionButton("⚡ เปิด Colossus Crates ทันที", "สั่งเปิดกล่องบอส Colossus ในคลังทั้งหมดทันที (Petalfall & Tidewreck)", "เปิดกล่อง", Theme.SpecialBtn, function()
    task.spawn(function()
        local ok, err = pcall(TriggerOpenPetalfallCrate)
        if not ok then warn(string.format("⚠️ [Action Error: OpenPetalfallCrate] %s", tostring(err))) end
    end)
end, TabDungeon, 6)

AddSectionHeader("🎲 กาชา & รับรางวัล (Gacha & Claims)", TabDungeon, 7)
AddToggle("AutoRollDice", "Auto Roll Dice (ทอยลูกเต๋า Enchant)", "ทอยลูกเต๋า Enchant & Halloween อัตโนมัติ (หยุดเมื่อหมด)", TabDungeon, 8)
AddToggle("AutoSummonScrolls", "Auto Summon Scrolls (สุ่มม้วนอัญเชิญ)", "เปิดม้วนอัญเชิญตัวละครอัตโนมัติ (หยุดเมื่อม้วนหมด)", TabDungeon, 9)
AddToggle("AutoClaimIndex", "Auto Claim Index (รับรางวัล Index)", "รับรางวัลในดัชนีทั้งหมดที่ปลดล็อกอัตโนมัติ", TabDungeon, 10)
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
end, TabDungeon, 11)
AddToggle("AutoClaimEvents", "Auto Claim Events (รับรางวัลอีเว้น)", "รับรางวัล Milestone บนบอร์ดอีเว้นอัตโนมัติ", TabDungeon, 12)
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
end, TabDungeon, 13)

-- -------------------------------------------------------------
-- [8] POPULATE TAB 4: ระบบเทรด (TRADE SUITE)
-- -------------------------------------------------------------
StatusBar = Instance.new("TextLabel")
StatusBar.Size = UDim2.new(1, 0, 0, 26)
StatusBar.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
StatusBar.Text = "💡 สถานะ: พร้อมทำงาน เลือกบทบาทบัญชีเพื่อเริ่มต้น"
StatusBar.TextColor3 = Color3.fromRGB(150, 220, 160)
StatusBar.Font = Enum.Font.GothamMedium
StatusBar.TextSize = 10.5
StatusBar.LayoutOrder = 1
StatusBar.Parent = TabTrade

local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 6)
sbCorner.Parent = StatusBar

-- Role Selection Frame
AddSectionHeader("👤 1. เลือกบทบาทของบัญชีนี้", TabTrade, 2)
local RoleFrame = Instance.new("Frame")
RoleFrame.Size = UDim2.new(1, 0, 0, 32)
RoleFrame.BackgroundTransparency = 1
RoleFrame.LayoutOrder = 3
RoleFrame.Parent = TabTrade

local SenderBtn = Instance.new("TextButton")
SenderBtn.Size = UDim2.new(0.485, 0, 1, 0)
SenderBtn.BackgroundColor3 = Color3.fromRGB(110, 65, 200)
SenderBtn.Text = "📤 โหมดผู้ส่ง (Sender)"
SenderBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SenderBtn.Font = Enum.Font.GothamBold
SenderBtn.TextSize = 11
SenderBtn.Parent = RoleFrame

local sndCorner = Instance.new("UICorner")
sndCorner.CornerRadius = UDim.new(0, 6)
sndCorner.Parent = SenderBtn

local ReceiverBtn = Instance.new("TextButton")
ReceiverBtn.Size = UDim2.new(0.485, 0, 1, 0)
ReceiverBtn.Position = UDim2.new(0.515, 0, 0, 0)
ReceiverBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
ReceiverBtn.Text = "📥 โหมดผู้รับ (Receiver)"
ReceiverBtn.TextColor3 = Color3.fromRGB(190, 190, 205)
ReceiverBtn.Font = Enum.Font.GothamBold
ReceiverBtn.TextSize = 11
ReceiverBtn.Parent = RoleFrame

local rcvCorner = Instance.new("UICorner")
rcvCorner.CornerRadius = UDim.new(0, 6)
rcvCorner.Parent = ReceiverBtn

-- Target Receiver Selection Frame (สำหรับ Sender)
local TargetHeader = AddSectionHeader("🎯 2. เลือกผู้รับเป้าหมาย (Receiver)", TabTrade, 4)

local PlayerSelectFrame = Instance.new("Frame")
PlayerSelectFrame.Size = UDim2.new(1, 0, 0, 32)
PlayerSelectFrame.BackgroundTransparency = 1
PlayerSelectFrame.LayoutOrder = 5
PlayerSelectFrame.Parent = TabTrade

local CurrentPlayerLabel = Instance.new("TextLabel")
CurrentPlayerLabel.Size = UDim2.new(0.72, 0, 1, 0)
CurrentPlayerLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
CurrentPlayerLabel.Text = "กำลังค้นหาผู้เล่นในห้อง..."
CurrentPlayerLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
CurrentPlayerLabel.Font = Enum.Font.GothamBold
CurrentPlayerLabel.TextSize = 11
CurrentPlayerLabel.Parent = PlayerSelectFrame

local cplCorner = Instance.new("UICorner")
cplCorner.CornerRadius = UDim.new(0, 6)
cplCorner.Parent = CurrentPlayerLabel

local CyclePlayerBtn = Instance.new("TextButton")
CyclePlayerBtn.Size = UDim2.new(0.26, 0, 1, 0)
CyclePlayerBtn.Position = UDim2.new(0.74, 0, 0, 0)
CyclePlayerBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 85)
CyclePlayerBtn.Text = "🔄 สลับผู้เล่น"
CyclePlayerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CyclePlayerBtn.Font = Enum.Font.GothamBold
CyclePlayerBtn.TextSize = 10.5
CyclePlayerBtn.Parent = PlayerSelectFrame

local cycCorner = Instance.new("UICorner")
cycCorner.CornerRadius = UDim.new(0, 6)
cycCorner.Parent = CyclePlayerBtn

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
ReceiverAutoFrame.LayoutOrder = 6
ReceiverAutoFrame.Visible = false
ReceiverAutoFrame.Parent = TabTrade

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

SenderBtn.MouseButton1Click:Connect(function() SetRole("Sender") end)
ReceiverBtn.MouseButton1Click:Connect(function() SetRole("Receiver") end)
SetRole(TradeState.Mode, true)

-- Item Selection Area
AddSectionHeader("🎒 3. เลือกไอเทมที่จะส่ง (สูงสุด 8 กองต่อรอบ)", TabTrade, 7)

local FilterFrame = Instance.new("Frame")
FilterFrame.Size = UDim2.new(1, 0, 0, 26)
FilterFrame.BackgroundTransparency = 1
FilterFrame.LayoutOrder = 8
FilterFrame.Parent = TabTrade

local FilterLayout = Instance.new("UIListLayout")
FilterLayout.FillDirection = Enum.FillDirection.Horizontal
FilterLayout.Padding = UDim.new(0, 3)
FilterLayout.Parent = FilterFrame

ItemCountLabel = Instance.new("TextLabel")
ItemCountLabel.Size = UDim2.new(1, 0, 0, 18)
ItemCountLabel.BackgroundTransparency = 1
ItemCountLabel.Text = "เลือกแล้ว: 0 / 8 กอง"
ItemCountLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
ItemCountLabel.Font = Enum.Font.GothamMedium
ItemCountLabel.TextSize = 10.5
ItemCountLabel.TextXAlignment = Enum.TextXAlignment.Left
ItemCountLabel.LayoutOrder = 9
ItemCountLabel.Parent = TabTrade

ItemScrollBox = Instance.new("ScrollingFrame")
ItemScrollBox.Size = UDim2.new(1, 0, 0, 150)
ItemScrollBox.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
ItemScrollBox.ScrollBarThickness = 3
ItemScrollBox.ScrollBarImageColor3 = Theme.Accent
ItemScrollBox.LayoutOrder = 10
ItemScrollBox.Parent = TabTrade

local isbCorner = Instance.new("UICorner")
isbCorner.CornerRadius = UDim.new(0, 6)
isbCorner.Parent = ItemScrollBox

local ItemListLayout = Instance.new("UIListLayout")
ItemListLayout.Padding = UDim.new(0, 4)
ItemListLayout.Parent = ItemScrollBox

local function CountSelected()
    local c = 0
    for _ in pairs(TradeState.SelectedItems) do c = c + 1 end
    return c
end

local RenderInventoryList

local function CreateCategoryTabBtn(name, cat)
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

CreateCategoryTabBtn("ทั้งหมด", "All")
CreateCategoryTabBtn("👤 คนขุด", "Miners")
CreateCategoryTabBtn("⛏️ ขวาน", "Pickaxes")
CreateCategoryTabBtn("💎 อัญมณี", "Gems")
CreateCategoryTabBtn("🧪 อื่นๆ", "Other")

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

    ItemScrollBox.CanvasSize = UDim2.new(0, 0, 0, #items * 32 + 8)

    for _, it in ipairs(items) do
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
        row.Size = UDim2.new(1, -6, 0, 28)
        row.Position = UDim2.new(0, 3, 0, 0)
        row.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
        row.Parent = ItemScrollBox

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 4)
        rCorner.Parent = row

        local checkBtn = Instance.new("TextButton")
        checkBtn.Size = UDim2.new(0, 18, 0, 18)
        checkBtn.Position = UDim2.new(0, 6, 0.5, -9)
        checkBtn.BackgroundColor3 = TradeState.SelectedItems[it.Key] and Color3.fromRGB(45, 170, 95) or Color3.fromRGB(50, 50, 65)
        checkBtn.Text = TradeState.SelectedItems[it.Key] and "✓" or ""
        checkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        checkBtn.Font = Enum.Font.GothamBold
        checkBtn.TextSize = 10
        checkBtn.Parent = row

        local ckCorner = Instance.new("UICorner")
        ckCorner.CornerRadius = UDim.new(0, 4)
        ckCorner.Parent = checkBtn

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -145, 1, 0)
        nameLbl.Position = UDim2.new(0, 28, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = string.format("%s %s (มี %d)", it.Emoji or "📦", it.Name, it.Count)
        nameLbl.TextColor3 = Color3.fromRGB(235, 235, 240)
        nameLbl.Font = Enum.Font.GothamMedium
        nameLbl.TextSize = 10
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = row

        local amtBox = Instance.new("TextBox")
        amtBox.Size = UDim2.new(0, 50, 0, 18)
        amtBox.Position = UDim2.new(1, -95, 0.5, -9)
        amtBox.BackgroundColor3 = Color3.fromRGB(36, 36, 50)
        amtBox.TextColor3 = Color3.fromRGB(240, 200, 90)
        amtBox.Font = Enum.Font.GothamBold
        amtBox.TextSize = 9.5
        amtBox.Text = tostring((TradeState.SelectedItems[it.Key] and TradeState.SelectedItems[it.Key].Amount) or (maxAllowed > 0 and 1 or 0))
        amtBox.ClearTextOnFocus = false
        amtBox.Parent = row

        local aCorner = Instance.new("UICorner")
        aCorner.CornerRadius = UDim.new(0, 4)
        aCorner.Parent = amtBox

        local function SyncAmount()
            local num = tonumber(amtBox.Text)
            if num then
                local clamped = math.clamp(math.floor(num), 1, math.max(1, maxAllowed))
                if TradeState.SelectedItems[it.Key] then
                    TradeState.SelectedItems[it.Key].Amount = clamped
                end
                amtBox.Text = tostring(clamped)
                SavedTradeItems[it.Key] = clamped
                SaveTradeConfig()
            else
                amtBox.Text = tostring((TradeState.SelectedItems[it.Key] and TradeState.SelectedItems[it.Key].Amount) or 1)
            end
        end

        amtBox.FocusLost:Connect(SyncAmount)

        local maxBtn = Instance.new("TextButton")
        maxBtn.Size = UDim2.new(0, 36, 0, 18)
        maxBtn.Position = UDim2.new(1, -40, 0.5, -9)
        maxBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        maxBtn.Text = "สูงสุด"
        maxBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
        maxBtn.Font = Enum.Font.GothamBold
        maxBtn.TextSize = 8.5
        maxBtn.Parent = row

        local mxCorner = Instance.new("UICorner")
        mxCorner.CornerRadius = UDim.new(0, 4)
        mxCorner.Parent = maxBtn

        maxBtn.MouseButton1Click:Connect(function()
            amtBox.Text = tostring(maxAllowed)
            SyncAmount()
            if not TradeState.SelectedItems[it.Key] and CountSelected() < 8 and it.Count > 0 then
                TradeState.SelectedItems[it.Key] = {
                    Key = it.Key,
                    Name = it.Name,
                    Amount = maxAllowed,
                    MaxCount = maxAllowed,
                    MaxCap = it.MaxCap or TradeTimingConfig.MaxStackCap
                }
                SavedTradeItems[it.Key] = maxAllowed
                SaveTradeConfig()
                checkBtn.BackgroundColor3 = Color3.fromRGB(45, 170, 95)
                checkBtn.Text = "✓"
                local curCount = CountSelected()
                ItemCountLabel.Text = string.format("เลือกแล้ว: %d / 8 กอง", curCount)
                ItemCountLabel.TextColor3 = curCount > 0 and Color3.fromRGB(120, 230, 160) or Color3.fromRGB(160, 160, 180)
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
RefreshInvBtn.LayoutOrder = 11
RefreshInvBtn.Parent = TabTrade

local refCorner = Instance.new("UICorner")
refCorner.CornerRadius = UDim.new(0, 6)
refCorner.Parent = RefreshInvBtn

RefreshInvBtn.MouseButton1Click:Connect(function()
    RenderInventoryList()
    TradeNotify("รีเฟรชคลัง", "อัปเดตรายการไอเทมในกระเป๋าเรียบร้อย")
end)

-- Trade Options & Controls
AddSectionHeader("⚡ 4. คำสั่งเปิด-ปิดการเทรด (Trade Controls)", TabTrade, 12)

local SendAllToggleFrame = Instance.new("Frame")
SendAllToggleFrame.Size = UDim2.new(1, 0, 0, 58)
SendAllToggleFrame.BackgroundTransparency = 1
SendAllToggleFrame.LayoutOrder = 13
SendAllToggleFrame.Parent = TabTrade

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

StartTradeBtn = Instance.new("TextButton")
StartTradeBtn.Size = UDim2.new(1, 0, 0, 34)
StartTradeBtn.BackgroundColor3 = Color3.fromRGB(110, 65, 200)
StartTradeBtn.Text = "🚀 เปิด/เริ่มส่งไอเทมที่เลือก (Start Transfer)"
StartTradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StartTradeBtn.Font = Enum.Font.GothamBold
StartTradeBtn.TextSize = 11.5
StartTradeBtn.LayoutOrder = 14
StartTradeBtn.Parent = TabTrade

local stCorner = Instance.new("UICorner")
stCorner.CornerRadius = UDim.new(0, 6)
stCorner.Parent = StartTradeBtn

CancelTradeBtn = Instance.new("TextButton")
CancelTradeBtn.Size = UDim2.new(1, 0, 0, 28)
CancelTradeBtn.BackgroundColor3 = Theme.RedBtn
CancelTradeBtn.Text = "❌ ยกเลิกการเทรดทันที (Cancel Trade)"
CancelTradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CancelTradeBtn.Font = Enum.Font.GothamBold
CancelTradeBtn.TextSize = 10.5
CancelTradeBtn.LayoutOrder = 15
CancelTradeBtn.Parent = TabTrade

local ctCorner = Instance.new("UICorner")
ctCorner.CornerRadius = UDim.new(0, 6)
ctCorner.Parent = CancelTradeBtn

local SaveConfigBtn = Instance.new("TextButton")
SaveConfigBtn.Size = UDim2.new(1, 0, 0, 26)
SaveConfigBtn.BackgroundColor3 = Color3.fromRGB(38, 55, 80)
SaveConfigBtn.Text = "💾 บันทึกการตั้งค่าเทรด (Save Trade Config)"
SaveConfigBtn.TextColor3 = Color3.fromRGB(200, 230, 255)
SaveConfigBtn.Font = Enum.Font.GothamSemibold
SaveConfigBtn.TextSize = 10.5
SaveConfigBtn.LayoutOrder = 16
SaveConfigBtn.Parent = TabTrade

local scCorner = Instance.new("UICorner")
scCorner.CornerRadius = UDim.new(0, 6)
scCorner.Parent = SaveConfigBtn

SaveConfigBtn.MouseButton1Click:Connect(function()
    SaveTradeConfig(true)
end)

-- -------------------------------------------------------------
-- [9] POPULATE TAB 5: ตั้งค่าระบบ & สถานะ (SETTINGS & STATUS)
-- -------------------------------------------------------------
AddSectionHeader("🛡️ ระบบความปลอดภัย & AFK (Security & AFK)", TabSettings, 1)
AddToggle("AntiAFK", "Anti-AFK Protection (ป้องกันหลุดเมื่อ AFK)", "ป้องกัน Roblox ตัดการเชื่อมต่อเมื่อปล่อยหน้าจอนานเกิน 20 นาที", TabSettings, 2)

AddSectionHeader("📊 ข้อมูลผู้เล่นปัจจุบัน (Current Status)", TabSettings, 3)

local InfoCard = Instance.new("Frame")
InfoCard.Size = UDim2.new(1, 0, 0, 75)
InfoCard.BackgroundColor3 = Theme.Card
InfoCard.BorderSizePixel = 0
InfoCard.LayoutOrder = 4
InfoCard.Parent = TabSettings

local icCorner = Instance.new("UICorner")
icCorner.CornerRadius = UDim.new(0, 6)
icCorner.Parent = InfoCard

local InfoLbl = Instance.new("TextLabel")
InfoLbl.Size = UDim2.new(1, -20, 1, -10)
InfoLbl.Position = UDim2.new(0, 10, 0, 5)
InfoLbl.BackgroundTransparency = 1
InfoLbl.TextColor3 = Theme.Text
InfoLbl.Font = Enum.Font.GothamMedium
InfoLbl.TextSize = 10.5
InfoLbl.TextXAlignment = Enum.TextXAlignment.Left
InfoLbl.TextYAlignment = Enum.TextYAlignment.Top
InfoLbl.Text = string.format("👤 ผู้เล่น: %s\\n📍 โซนปัจจุบัน: Zone %s\\n💎 สถานะสคริปต์: V17 Unified Edition (พร้อมใช้งาน 100%%)", LocalPlayer.Name, tostring(LocalPlayer:GetAttribute("Zone") or "1"))
InfoLbl.Parent = InfoCard

task.spawn(function()
    while true do
        task.wait(3.0)
        pcall(function()
            local d2 = SafeGetData2()
            local mg = d2 and d2.MineGame
            local curZone = mg and mg.CurrentZone or 1
            local gems = mg and mg.Gems or 0
            InfoLbl.Text = string.format("👤 ผู้เล่น: %s\\n📍 โซนปัจจุบัน: Zone %s | 💎 Gems: %s\\n⚡ สถานะสคริปต์: V17 Unified Edition (ทำงานปกติ 100%%)", LocalPlayer.Name, tostring(curZone), tostring(gems))
        end)
    end
end)

AddSectionHeader("⚙️ การจัดการการตั้งค่า (Config Management)", TabSettings, 5)
AddActionButton("💾 บันทึกการตั้งค่าทั้งหมดทันที", "บันทึกการตั้งค่าระบบฟาร์มและระบบเทรดลงไฟล์คอนฟิกทันที", "บันทึกข้อมูล", Theme.Accent, function()
    SaveConfig()
    SaveTradeConfig(true)
    UpdateStatus("💾 บันทึกการตั้งค่าทั้งหมดเรียบร้อยแล้ว!")
end, TabSettings, 6)

-- เปิดแท็บเริ่มต้น
SwitchTab("Farming")

-- Hotkey F9 สำหรับสลับเปิด-ปิด UI
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.F9 then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- ═══════════════════════════════════════════════
-- 🔄 BACKGROUND AUTOMATION & WATCHDOG ENGINE
-- ═══════════════════════════════════════════════
-- ฟังก์ชันช่วยคลิกปุ่มบนหน้าต่างเทรดจริงของเกม
    local function ClickTradeButtonUI()
        pcall(function()
            local mineGui = PlayerGui:FindFirstChild("MineGui")
            local tradeFrame = mineGui and mineGui:FindFirstChild("TradeFrame")
            if tradeFrame then
                for _, desc in ipairs(tradeFrame:GetDescendants()) do
                    if (desc.Name == "ReadyButton" or desc.Name == "ConfirmButton") and desc:IsA("GuiButton") then
                        pcall(function()
                            if getconnections then
                                for _, conn in ipairs(getconnections(desc.Activated)) do conn:Fire() end
                                for _, conn in ipairs(getconnections(desc.MouseButton1Click)) do conn:Fire() end
                            end
                        end)
                        pcall(function()
                            if firesignal then
                                firesignal(desc.Activated)
                                firesignal(desc.MouseButton1Click)
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
                            for _, conn in ipairs(getconnections(acceptBtn.Activated)) do conn:Fire() end
                            for _, conn in ipairs(getconnections(acceptBtn.MouseButton1Click)) do conn:Fire() end
                        end
                    end)
                    pcall(function()
                        if firesignal then
                            firesignal(acceptBtn.Activated)
                            firesignal(acceptBtn.MouseButton1Click)
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

    if TradeSwitchBadge then TradeSwitchBadge.MouseButton1Click:Connect(function() ToggleTrade() end) end
    
    if StartTradeBtn then StartTradeBtn.MouseButton1Click:Connect(function() ToggleTrade() end) end
    
    if CancelTradeBtn then CancelTradeBtn.MouseButton1Click:Connect(function() ToggleTrade(false) end) end
    
    if TradeCloseBtn then TradeCloseBtn.MouseButton1Click:Connect(function() ToggleTrade(false) TradeMainFrame.Visible = false end) end
    
    _G.ToggleTrade = ToggleTrade
    _G.IsTradeActive = function() return TradeState.IsTradeActive end
    
    TradeNotify("Trade Suite V7.1 Pro", "หน้าต่างควบคุมการเทรด V7.1 Pro พร้อมใช้งานแล้ว!", 3)

-- ═══════════════════════════════════════════════
-- 🚀 4. MASTER WORKER PIPELINE (ISOLATED TASKS WITH PCALL)
-- ═══════════════════════════════════════════════
local lastEquipTime = 0

task.spawn(function()
    while true do
        -- 🛑 หยุดการทำงานของเธรดเก่าทันที หากมีการรันสคริปต์ตัวใหม่ หรือ UI ถูกทำลาย
        if getgenv and (getgenv()._AnimeMineWorkerActive == false or getgenv()._AnimeMineSessionId ~= scriptSessionId) then
            break
        end
        if ScreenGui and not ScreenGui.Parent then
            break
        end

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
        -- [TASK 2] ขายของอัตโนมัติ (Unified Auto Sell)
        -- วาร์ปไปขายแร่, ขวานเก่า และตัวละครตามประเภทและความหายากที่เลือกไว้ในดรอปดาวน์
        -- -------------------------------------------------------------
        local ok2, err2 = pcall(function()
            if not Config.AutoSell then return end

            d2 = SafeGetData2()
            mg = d2 and d2.MineGame
            local sellKeys = GetUnifiedSellKeys(mg)

            if #sellKeys > 0 and char then
                local sellStand = workspace:FindFirstChild("SellStand")
                if not sellStand then
                    warn("⚠️ [Null-Safety] ไม่พบ 'SellStand' ใน workspace ข้ามขั้นตอนการขาย")
                else
                    local returnPlotCFrame = GetPlotReturnCFrame(myPlot)
                    UpdateStatus(string.format("💰 วาร์ปไปขายของ (%d รายการ)...", #sellKeys))

                    char:PivotTo(sellStand:GetPivot() + Vector3.new(0, 3, 5))
                    HumanWait(0.35, 0.5)

                    -- ส่งคำสั่งขายแบบแบ่งชุด (Batching ครั้งละ 50 คีย์ ป้องกัน Packet ขาดหาย)
                    for i = 1, #sellKeys, 50 do
                        local batch = {}
                        for j = i, math.min(i + 49, #sellKeys) do
                            table.insert(batch, sellKeys[j])
                        end
                        SafeSendEvent(Config.Events.SellItems, batch)
                        HumanWait(0.25, 0.35)
                    end

                    if returnPlotCFrame then
                        char:PivotTo(returnPlotCFrame)
                        HumanWait(0.2, 0.3)
                    end
                    UpdateStatus(string.format("✅ ขายสำเร็จ %d รายการ!", #sellKeys))
                end
            end
        end)
        if not ok2 then
            warn(string.format("⚠️ [Worker Task 2 Error - UnifiedAutoSell] %s", tostring(err2)))
        end

        -- -------------------------------------------------------------
        -- [TASK 3] อัปเกรดต้นไม้ (Zone Skill Tree & Core Upgrades)
        -- -------------------------------------------------------------
        local ok3, err3 = pcall(function()
            d = SafeGetData()
            d2 = SafeGetData2()
            mg = d2 and d2.MineGame
            myMoney = d and tonumber(d.Money) or 0

            -- 3.1 สกิลต้นไม้ประจำโซน (วนตรวจเช็คทุกโซนที่ปลดล็อกแล้ว)
            if Config.AutoUpgradeTree and mg and MineConfig then
                local zonesToCheck = {}
                local curZone = mg.CurrentZone or 1
                table.insert(zonesToCheck, "Z" .. curZone)
                for z = 14, 1, -1 do
                    local zk = "Z" .. z
                    if zk ~= ("Z" .. curZone) and (mg.UnlockedZones and mg.UnlockedZones[zk]) then
                        table.insert(zonesToCheck, zk)
                    end
                end

                local upgradedCount = 0
                for _, zoneKey in ipairs(zonesToCheck) do
                    local zSkills = (mg.Skills and mg.Skills[zoneKey]) or {}
                    local nodes = MineConfig.GetSkillNodes and MineConfig.GetSkillNodes(zoneKey)
                    if nodes then
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
                                zSkills[node.Family] = curLvl + 1
                                upgradedCount = upgradedCount + 1
                                HumanWait(0.08, 0.12)
                                if upgradedCount >= 10 then break end
                            end
                        end
                    end
                    if upgradedCount >= 10 then break end
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

                -- 4.1 ค้นหาขวาน "อันสุดท้ายที่ดีที่สุดที่ปลดล็อค" เพียงอันเดียวเท่านั้น
                if MineConfig.Pickaxes then
                    local targetBestPick = nil
                    local targetBestIdx = nil
                    local bestUnlockedMult = -1

                    for idx, pick in ipairs(MineConfig.Pickaxes) do
                        if not (MineConfig.IsPickaxeFree and MineConfig.IsPickaxeFree(pick)) and not pick.RobuxOnly and not pick.RobuxCost then
                            -- ตรวจสอบว่าขวานนี้เปิดวางจำหน่ายจริงในร้านค้า (ตัด Dragonrise Pickaxe และ Krakenmaw Pickaxe ออกเด็ดขาด 100%)
                            local pickNameLower = string.lower(pick.Name or "")
                            local isShopBlacklisted = (pick.Name == "Dragonrise Pickaxe") or (pick.Name == "Krakenmaw Pickaxe")
                                or (string.find(pickNameLower, "dragonrise") ~= nil)
                                or (string.find(pickNameLower, "krakenmaw") ~= nil)
                            local isForSale = not isShopBlacklisted and (type(pick.Stock) == "table")
                            local isZoneUnlocked = not pick.ZoneReq or (mg.UnlockedZones and mg.UnlockedZones[pick.ZoneReq])
                            local mult = tonumber(pick.Multiplier) or 1
                            if isForSale and isZoneUnlocked then
                                -- ยึดอันสุดท้ายที่มีตัวคูณสูงสุด (อันสุดท้ายที่ดีที่สุดที่เปิดขายจริงเสมอ)
                                if mult >= bestUnlockedMult then
                                    bestUnlockedMult = mult
                                    targetBestPick = pick
                                    targetBestIdx = idx
                                end
                            end
                        end
                    end

                    -- ซื้อแค่อันสุดท้ายที่ดีที่สุดที่ปลดล็อคเท่านั้น ให้ซื้อทุกครั้งเมื่อพร้อม (เงินพอ + มีสต็อก)
                    if targetBestPick and targetBestIdx then
                        local maxNeed = (MineConfig and tonumber(MineConfig.TotalMinerSlots)) or 12
                        local cost = tonumber(targetBestPick.Cost) or (1 / 0)

                        -- ซื้อทุกครั้งเมื่อพร้อม วนซื้อต่อเนื่องจนกว่าเงินจะไม่พอ สต็อกหมด หรือครบตามจำนวนแท่นคนงานทั้งหมด
                        for buyAttempt = 1, maxNeed do
                            local curD = SafeGetData()
                            local curD2 = SafeGetData2()
                            local curMg = curD2 and curD2.MineGame
                            local curMoney = tonumber(curD.Money) or 0
                            local ownedCount = tonumber(curMg and curMg.Pickaxes and curMg.Pickaxes[targetBestPick.Name]) or 0

                            local remStock = MineStock and MineStock.GetRemaining and MineStock.GetRemaining(curD2, targetBestPick.Name)
                            local hasStock = (remStock == nil) or (remStock > 0)

                            if curMoney >= cost and hasStock and ownedCount < maxNeed then
                                UpdateStatus(string.format("🪓 ซื้อขวานดีสุดอันสุดท้าย: %s (%d/%d ชิ้น) [ราคา: %s]", 
                                    targetBestPick.Name, ownedCount + 1, maxNeed, FormatNumber(cost)))
                                SafeSendEvent(Config.Events.BuyPickaxe, targetBestIdx)
                                HumanWait(0.25, 0.35)
                            else
                                break
                            end
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
                                SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "Damage", true)
                                HumanWait(0.08, 0.12)
                            end
                        end

                        -- 2. Speed Upgrade Check
                        local curSpd = h.CharSpeedLevel or 1
                        local targetSpd = math.min(tonumber(Config.TargetLevelSpeed) or 17, MineConfig.CharSpeedMaxLevel or 17)
                        if curSpd < targetSpd then
                            local cost = MineConfig.GetCharacterSpeedUpgradeCost and MineConfig.GetCharacterSpeedUpgradeCost(curSpd, item)
                            local curMoney = tonumber(SafeGetData().Money) or 0
                            if cost and curMoney >= cost then
                                UpdateStatus("⚡ อัป Speed " .. slotKey)
                                SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "Speed", true)
                                HumanWait(0.08, 0.12)
                            end
                        end

                        -- 3. MineSpeed Upgrade Check
                        local curMineSpd = h.CharMineSpeedLevel or 1
                        local targetMineSpd = math.min(tonumber(Config.TargetLevelMineSpeed) or 16, MineConfig.CharMineSpeedMaxLevel or 16)
                        if curMineSpd < targetMineSpd then
                            local cost = MineConfig.GetCharacterMineSpeedUpgradeCost and MineConfig.GetCharacterMineSpeedUpgradeCost(curMineSpd, item)
                            local curMoney = tonumber(SafeGetData().Money) or 0
                            if cost and curMoney >= cost then
                                UpdateStatus("⛏️ อัป MineSpeed " .. slotKey)
                                SafeSendEvent(Config.Events.UpgradeCharacter, slotKey, "MineSpeed", true)
                                HumanWait(0.08, 0.12)
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
        -- [TASK 6] สุ่มการกลายพันธุ์ (Auto Mutation - Ready First & Auto-Lock Engine)
        -- -------------------------------------------------------------
        local ok6, err6 = pcall(function()
            if Config.AutoMutation and mg and mg.Holders and Items and MineConfig then
                local curMoney = tonumber(SafeGetData().Money) or 0
                local readySlots = {}    -- ตัวที่ยังไม่ได้บัพเป้าหมาย และเงินพอสุ่มทันที (พร้อมที่สุด)
                local waitingSlots = {}  -- ตัวที่ยังไม่ได้บัพเป้าหมาย แต่เงินยังไม่พอ
                local lockedCount = 0
                local totalSelected = 0
                local processedSlots = {}

                for slotKey, isSelected in pairs(Config.MutationSlots) do
                    if isSelected then
                        local realKey = tostring(slotKey)
                        if not string.find(realKey, "^M") then
                            local num = tonumber(string.match(realKey, "%d+"))
                            if num then realKey = "M" .. num end
                        end

                        if not processedSlots[realKey] then
                            processedSlots[realKey] = true
                            local h = mg.Holders[realKey]
                            if h and h.CharName then
                                totalSelected = totalSelected + 1
                                local curVariant = h.CharVariant or "Normal"
                                -- 🔒 ตรวจสอบว่าได้บัพตรงตามที่เลือกไว้หรือไม่
                                local isTargetMatched = (Config.TargetMutations and Config.TargetMutations[curVariant] == true) or (Config.Mutations and Config.Mutations[curVariant] == true)
                                if isTargetMatched then
                                    -- ล็อคตัวนี้ทันที ไม่นำไปสุ่มอีกเด็ดขาด
                                    lockedCount = lockedCount + 1
                                else
                                    -- ยังไม่ได้บัพเป้าหมาย ให้คำนวณค่าสุ่ม
                                    local item = Items.GetItemData(h.CharName)
                                    local mutCost = item and MineConfig.GetMutationRollCost and MineConfig.GetMutationRollCost(item, mg) or 0
                                    local baseDmg = GetCharBaseDamage(h.CharName)

                                    local slotData = {
                                        slot = realKey,
                                        name = h.CharName,
                                        variant = curVariant,
                                        baseDmg = baseDmg,
                                        cost = mutCost
                                    }

                                    if mutCost > 0 and curMoney >= mutCost then
                                        table.insert(readySlots, slotData)
                                    else
                                        table.insert(waitingSlots, slotData)
                                    end
                                end
                            end
                        end
                    end
                end

                if totalSelected == 0 then
                    -- ยังไม่ได้เลือกแท่นใดๆ
                elseif lockedCount >= totalSelected then
                    UpdateStatus(string.format("🎉 ได้บัพตรงตามที่เลือกครบแล้ว (%d/%d) [🔒 ล็อคทั้งหมด]", lockedCount, totalSelected))
                    if RefreshMutationVisuals then pcall(RefreshMutationVisuals) end
                elseif #readySlots > 0 then
                    -- 🎯 สุ่มตัวที่พร้อมก่อนเสมอ! (เรียงตัวที่ Base DMG สูงสุดในกลุ่มตัวที่เงินพอ)
                    table.sort(readySlots, function(a, b) return a.baseDmg > b.baseDmg end)
                    local currentTarget = readySlots[1]
                    local mutCost = currentTarget.cost

                    for r = 1, 3 do
                        curMoney = tonumber(SafeGetData().Money) or 0
                        if not Config.AutoMutation or curMoney < mutCost then break end

                        UpdateStatus(string.format("🧬 สุ่ม %s (%s) [ค่าสุ่ม: %s]", currentTarget.slot, currentTarget.name, FormatNumber(mutCost)))
                        SafeSendEvent(Config.Events.RollMutation, currentTarget.slot)
                        HumanWait(0.22, 0.3)

                        -- ตรวจสอบผลลัพธ์ทันทีหลังสุ่ม
                        local postD2 = SafeGetData2()
                        local postH = postD2 and postD2.MineGame and postD2.MineGame.Holders and postD2.MineGame.Holders[currentTarget.slot]
                        local newVariant = postH and (postH.CharVariant or "Normal")

                        -- 🔒 ล็อคทันทีเมื่อบัพตรงตามที่เลือก
                        local isNewMatched = (Config.TargetMutations and Config.TargetMutations[newVariant] == true) or (Config.Mutations and Config.Mutations[newVariant] == true)
                        if newVariant and isNewMatched then
                            UpdateStatus(string.format("🔒 ล็อค %s ได้ '%s' แล้ว! (ตรงตามที่เลือก)", currentTarget.slot, newVariant))
                            SaveConfig()
                            if RefreshMutationVisuals then pcall(RefreshMutationVisuals) end
                            HumanWait(0.3, 0.5)
                            break
                        end
                    end
                elseif #waitingSlots > 0 then
                    -- มีตัวที่ยังไม่ได้บัพ แต่เงินยังไม่พอ ให้หาตัวที่ขาดเงินน้อยที่สุดมาบอกสถานะ
                    table.sort(waitingSlots, function(a, b) return (a.cost - curMoney) < (b.cost - curMoney) end)
                    local nearest = waitingSlots[1]
                    local needMore = math.max(0, nearest.cost - curMoney)
                    UpdateStatus(string.format("⏳ รอเงินสุ่มบัพ %s (ขาดอีก %s)", nearest.slot, FormatNumber(needMore)))
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
                        local rollCount = math.clamp(hwDice, 1, 10)
                        UpdateStatus(string.format("🎲 ทอยลูกเต๋า Halloween (%d ลูก)...", rollCount))
                        SafeSendEvent(Config.Events.RollEnchant, rollCount, "Halloween")
                        HumanWait(0.3, 0.45)
                    elseif normalDice > 0 then
                        local rollCount = math.clamp(normalDice, 1, 10)
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
                        if Config.AutoEquipBest then
                            TriggerEquipBest()
                        end
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
        -- [TASK 11] เปิด Colossus Crates (Petalfall & Tidewreck Crate ฯลฯ อัตโนมัติ)
        -- -------------------------------------------------------------
        local ok11, err11 = pcall(function()
            if Config.AutoOpenPetalfallCrate and mg and mg.ColossusCrates then
                for crateName, countVal in pairs(mg.ColossusCrates) do
                    local count = tonumber(countVal) or 0
                    if count > 0 then
                        local openAmount = math.clamp(count, 1, 50)
                        UpdateStatus(string.format("📦 เปิด %s (%d/%d กล่อง)...", tostring(crateName), openAmount, count))
                        SafeSendEvent(Config.Events.OpenColossusCrate, crateName, openAmount)
                        HumanWait(0.4, 0.6)
                        if Config.AutoEquipBest then
                            TriggerEquipBest()
                        end
                        d2 = SafeGetData2()
                        mg = d2 and d2.MineGame
                    end
                end
            end
        end)
        if not ok11 then
            warn(string.format("⚠️ [Worker Task 11 Error - ColossusCrate] %s", tostring(err11)))
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

            -- 12.3 สวมใส่ตัวละครที่ดีที่สุด (ตรวจสอบทุก 8 วินาที)
            if Config.AutoEquipBest and os.clock() - lastEquipTime > 8 then
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