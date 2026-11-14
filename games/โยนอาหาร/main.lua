-- =====================================================================
-- KUYKUY HUB | โยนอาหารให้สัตว์ (PlaceId: 120219252362013)
-- โครงสร้าง: Core(State/Cleanup) -> Config(Auto Save/Load) -> Net -> Helpers -> Features -> UI
-- มาตรฐาน: Kuykuy Hub Universal Architecture (7 Core Pillars)
-- เวอร์ชัน: v2.4 (Throw Freeze Fix + Flight Timing & Reveal + Train Recovery + Anti-Spam Guard)
-- =====================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")

local vuOk, vuSvc = pcall(function() return game:GetService("VirtualUser") end)
local VirtualUser = vuOk and vuSvc or nil

local LocalPlayer = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

-- ล้างอินสแตนซ์เก่าถ้าเคยรันอยู่
if ENV.__KUY and type(ENV.__KUY.Destroy) == "function" then
    pcall(function() ENV.__KUY:Destroy() end)
end

-- =====================================================================
-- 1. CORE STATE & LIFECYCLE MANAGER
-- =====================================================================
local Core = {
    Flags = {},
    Busy = false,
    _conns = {},
    _loops = {},
    _cleanups = {},
    _alive = true,
    _gui = nil,
    _updateLogUI = nil,
}

ENV.__KUY = Core

-- รายชื่อ Flags เริ่มต้น (Default Values)
Core.Flags.AutoThrow        = false   -- โยนอาหารอัตโนมัติ (วาร์ปไปเส้นโยน + ป้องกันค้าง + คะแนนเต็ม 100%)
Core.Flags.PerfectThrow     = true    -- บังคับคะแนนเต็ม 100% (Meter Accuracy = 1.0)
Core.Flags.AutoSuperThrow   = false   -- ใช้งาน Super Throw เมื่อมีสิทธิ์
Core.Flags.AutoTrain        = false   -- ฝึกพลังอัตโนมัติ (วาร์ปไปแท่นฝึก + ระบบแก้ค้าง)
Core.Flags.AutoTapBonus     = true    -- กดคูณ 2 อัตโนมัติทันทีที่มีรอบโบนัสขณะฝึกซ้อม
Core.Flags.AutoStandUpgrade = false   -- อัปเกรดแท่นฝึกอัตโนมัติ (พร้อมระบบกันแจ้งเตือนเงินไม่พอ)
Core.Flags.AutoBuyFood      = true    -- ซื้ออาหารอัตโนมัติเมื่อเงินพอ
Core.Flags.AutoEquipFood    = true    -- สวมใส่อาหารที่ดีที่สุดอัตโนมัติ
Core.Flags.AutoEquipBest    = false   -- สวมใส่สัตว์ที่ดีที่สุดในแปลงอัตโนมัติ
Core.Flags.AutoUpgradeFence = false   -- ขยายรั้วเพิ่มความจุสัตว์ (พร้อมระบบกันแจ้งเตือนเงินไม่พอ)
Core.Flags.AutoSellAll      = false   -- ขายสัตว์ทั้งหมดที่ไม่ได้ติดตั้ง
Core.Flags.AutoClaimOffline = true    -- รับเงินออฟไลน์สะสมอัตโนมัติ
Core.Flags.AutoClaimFreeShop= true    -- รับของขวัญฟรีจาก Exclusive Shop
Core.Flags.AutoRingRush     = false   -- เล่นมินิเกม Ring Rush อัตโนมัติ
Core.Flags.AntiAfk          = true    -- กันเตะ AFK 20 นาที

-- =====================================================================
-- 2. CONFIG PERSISTENCE ENGINE (ระบบจดจำและบันทึกการตั้งค่าอัตโนมัติ)
-- =====================================================================
local Config = {
    FILE = "Kuykuy_FeedAnimals_Config.json"
}

function Config._getEnvVar(name)
    if type(getgenv) == "function" then
        local g = getgenv()
        if g and g[name] ~= nil then return g[name] end
    end
    if _G and _G[name] ~= nil then return _G[name] end
    local envOk, env = pcall(getfenv, 0)
    if envOk and env and env[name] ~= nil then return env[name] end
    local renvOk, renv = pcall(function() return getrenv and getrenv() end)
    if renvOk and renv and renv[name] ~= nil then return renv[name] end
    return nil
end

function Config._getFS()
    local w = Config._getEnvVar("writefile") or (syn and syn.write_file) or (fluxus and fluxus.write_file) or writefile
    local r = Config._getEnvVar("readfile") or (syn and syn.read_file) or (fluxus and fluxus.read_file) or readfile
    local i = Config._getEnvVar("isfile") or (syn and syn.is_file) or (fluxus and fluxus.is_file) or isfile
    return w, r, i
end

function Config._encode(data)
    local okJson, json = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if okJson and type(json) == "string" and #json > 2 then
        return json
    end
    local parts = {}
    for k, v in pairs(data) do
        table.insert(parts, string.format("%s=%s", tostring(k), tostring(v)))
    end
    return table.concat(parts, ";")
end

function Config._decode(str)
    if not str or type(str) ~= "string" or #str < 2 then return nil end
    local okJson, parsed = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    if okJson and type(parsed) == "table" then
        return parsed
    end
    local data = {}
    for pair in string.gmatch(str, "[^;]+") do
        local k, v = string.match(pair, "^([^=]+)=(.+)$")
        if k and v then
            if v == "true" then data[k] = true
            elseif v == "false" then data[k] = false
            elseif tonumber(v) then data[k] = tonumber(v)
            else data[k] = v end
        end
    end
    return data
end

function Config._safeWriteFile(path, content)
    local w = Config._getFS()
    local diskOk = false
    if type(w) == "function" then
        local ok = pcall(w, path, content)
        if ok then diskOk = true end
    end
    ENV.__KUY_CONFIG_CACHE = content
    return diskOk
end

function Config._safeReadFile(path)
    local _, r, i = Config._getFS()
    if type(i) == "function" and type(r) == "function" then
        local existsOk, exists = pcall(i, path)
        if existsOk and exists then
            local readOk, data = pcall(r, path)
            if readOk and type(data) == "string" and #data > 2 then
                return true, data, "disk"
            end
        end
    end
    if type(r) == "function" then
        local readOk, data = pcall(r, path)
        if readOk and type(data) == "string" and #data > 2 then
            return true, data, "disk"
        end
    end
    if ENV.__KUY_CONFIG_CACHE and type(ENV.__KUY_CONFIG_CACHE) == "string" and #ENV.__KUY_CONFIG_CACHE > 2 then
        return true, ENV.__KUY_CONFIG_CACHE, "session"
    end
    return false, nil, "none"
end

function Config.Save()
    local dataToSave = {}
    for k, v in pairs(Core.Flags) do
        local tv = type(v)
        if tv == "boolean" or tv == "number" or tv == "string" then
            dataToSave[k] = v
        end
    end
    local encoded = Config._encode(dataToSave)
    Config._safeWriteFile(Config.FILE, encoded)
    return true
end

function Config.Load()
    local okRead, content, source = Config._safeReadFile(Config.FILE)
    if not okRead or not content then
        return false, "not_found"
    end
    local loaded = Config._decode(content)
    if type(loaded) == "table" then
        for k, v in pairs(loaded) do
            if Core.Flags[k] ~= nil then
                Core.Flags[k] = v
            end
        end
        return true, source
    end
    return false, "invalid_data"
end

-- โหลดการตั้งค่าเดิมที่เคยบันทึกไว้ในเครื่องทันที
local loadedFromDisk, loadSource = Config.Load()

function Core:Connect(signal, fn)
    if not signal then return nil end
    local ok, c = pcall(function() return signal:Connect(fn) end)
    if ok and c then
        table.insert(self._conns, c)
        return c
    end
    return nil
end

function Core:OnCleanup(fn)
    table.insert(self._cleanups, fn)
end

function Core:StopLoop(name)
    local th = self._loops[name]
    self._loops[name] = nil
    if th and th ~= coroutine.running() then
        pcall(task.cancel, th)
    end
end

function Core:Loop(name, flag, interval, fn)
    self:StopLoop(name)
    self._loops[name] = task.spawn(function()
        while self._alive and self.Flags[flag] do
            local ok, err = pcall(fn)
            if not ok then
                warn(string.format("[Kuy] Loop '%s' error: %s", name, tostring(err)))
            end
            task.wait(interval)
        end
        self._loops[name] = nil
    end)
end

-- =====================================================================
-- 3. CIRCULAR BUFFER LOGGING (80 รายการ)
-- =====================================================================
local Stats = { logs = {} }

local function logAction(category, msg, isSuccess)
    local entry = {
        time = os.date("%H:%M:%S"),
        cat = category or "ทั่วไป",
        msg = tostring(msg),
        ok = (isSuccess == nil) and true or isSuccess
    }
    table.insert(Stats.logs, 1, entry)
    if #Stats.logs > 80 then
        table.remove(Stats.logs)
    end
    if Core._updateLogUI then
        pcall(Core._updateLogUI)
    end
end

-- =====================================================================
-- 4. S-TIER NETWORK WRAPPER (TIMEOUT GUARD 3.5s + COOLDOWN)
-- =====================================================================
local Net = { _last = {} }

function Net.Fire(remote, cooldown, ...)
    if not Core._alive or not remote then return false end
    local key = remote:GetFullName()
    local now = os.clock()
    if cooldown and (now - (Net._last[key] or 0)) < cooldown then
        return false
    end
    Net._last[key] = now
    local args = table.pack(...)
    return (pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end))
end

function Net.Invoke(remote, ...)
    if not Core._alive or not remote then return false, "DEAD_OR_NIL" end
    local args = table.pack(...)
    local done = false
    local results = {}

    task.spawn(function()
        results = table.pack(pcall(function()
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end))
        done = true
    end)

    local t0 = os.clock()
    while not done and (os.clock() - t0) < 3.5 and Core._alive do
        task.wait(0.03)
    end

    if not done then
        return false, "TIMEOUT"
    end
    if not results[1] then
        return false, results[2]
    end
    return true, table.unpack(results, 2, results.n)
end

-- =====================================================================
-- 5. CACHE CLIENT CONTROLLERS & CONFIGS
-- =====================================================================
local DataController
local ClientState, Movement, CameraRig, ScreenFX

pcall(function()
    local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 5)
    local clientFolder = playerScripts and playerScripts:WaitForChild("Client", 5)
    local controllers = clientFolder and clientFolder:WaitForChild("Controllers", 5)
    if controllers then
        pcall(function() DataController = require(controllers:WaitForChild("DataController", 3)) end)
        pcall(function() ClientState = require(controllers:WaitForChild("ClientState", 3)) end)
        pcall(function() Movement = require(controllers:WaitForChild("Movement", 3)) end)
        pcall(function() CameraRig = require(controllers:WaitForChild("CameraRig", 3)) end)
        pcall(function() ScreenFX = require(controllers:WaitForChild("ScreenFX", 3)) end)
    end
end)

local FoodsConfig, FenceConfig, StandsConfig
pcall(function() FoodsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FoodsConfig")) end)
pcall(function() FenceConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FenceConfig")) end)
pcall(function() StandsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("StandsConfig")) end)

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
local remotes = {}

local function getRemote(name, className)
    if not RemotesFolder then return nil end
    local r = RemotesFolder:FindFirstChild(name)
    if r and (not className or r:IsA(className)) then
        return r
    end
    return nil
end

remotes.Training_Start      = getRemote("Training_Start", "RemoteFunction")
remotes.Training_Stop       = getRemote("Training_Stop", "RemoteFunction")
remotes.Training_TapBonus   = getRemote("Training_TapBonus", "RemoteFunction")
remotes.Training_Bonus      = getRemote("Training_Bonus", "RemoteEvent")

remotes.Throw_Start         = getRemote("Throw_Start", "RemoteFunction")
remotes.Throw_Resolve       = getRemote("Throw_Resolve", "RemoteFunction")
remotes.Throw_Revealed      = getRemote("Throw_Revealed", "RemoteEvent")
remotes.Throw_Complete      = getRemote("Throw_Complete", "RemoteFunction")
remotes.Throw_Cancel        = getRemote("Throw_Cancel", "RemoteFunction")
remotes.Throw_UseSuper      = getRemote("Throw_UseSuper", "RemoteFunction")
remotes.Player_SetThrowPower= getRemote("Player_SetThrowPower", "RemoteFunction")

remotes.Shop_Buy            = getRemote("Shop_Buy", "RemoteFunction")
remotes.Shop_Equip          = getRemote("Shop_Equip", "RemoteFunction")
remotes.Plot_EquipBest      = getRemote("Plot_EquipBest", "RemoteFunction")
remotes.Plot_UpgradeFence   = getRemote("Plot_UpgradeFence", "RemoteFunction")
remotes.Plot_SellAll        = getRemote("Plot_SellAll", "RemoteFunction")
remotes.Stand_Upgrade       = getRemote("Stand_Upgrade", "RemoteFunction")

remotes.Offline_Claim       = getRemote("Offline_Claim", "RemoteFunction")
remotes.Shop_ClaimFree      = getRemote("Shop_ClaimFree", "RemoteFunction")
remotes.IndexRewards_Claim  = getRemote("IndexRewards_Claim", "RemoteFunction")
remotes.RingRush_Begin      = getRemote("RingRush_Begin", "RemoteFunction")
remotes.RingRush_End        = getRemote("RingRush_End", "RemoteFunction")

-- =====================================================================
-- 6. HELPERS, WATCHDOG & POSITION SAFEGUARDS
-- =====================================================================
local Helpers = {}

function Helpers.GetRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Helpers.IsAlive()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil
end

-- ระบบฟื้นฟูตัวละครและแก้ค้างฉุกเฉิน (Unstick / Watchdog Recovery)
function Helpers.RecoverCharacter()
    local hrp = Helpers.GetRoot()
    if hrp and hrp.Anchored and not Core.Busy then
        hrp.Anchored = false
    end
    if Movement and Movement.Unlock then
        pcall(Movement.Unlock)
    end
    if CameraRig and CameraRig.Release then
        pcall(CameraRig.Release)
    end
    if ScreenFX and ScreenFX.Reset then
        pcall(ScreenFX.Reset)
    end
    if ClientState and ClientState.Busy then
        local busyStr = tostring(ClientState.Busy)
        if busyStr == "Throw" or busyStr == "KuykuyThrow" or busyStr == "KuykuyTrain" then
            ClientState.Busy = nil
        end
    end
end

function Helpers.TeleportTo(targetPos)
    local hrp = Helpers.GetRoot()
    if hrp and targetPos then
        if typeof(targetPos) == "CFrame" then
            hrp.CFrame = targetPos
        elseif typeof(targetPos) == "Vector3" then
            hrp.CFrame = CFrame.new(targetPos)
        end
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
end

function Helpers.GetPlotIndex()
    local attr = LocalPlayer:GetAttribute("PlotIndex")
    if attr then return attr end
    return 1
end

-- ดึงเงินสดจริงจาก DataController (หรือ leaderstats)
function Helpers.GetMoney()
    if DataController and DataController.Get then
        local ok, m = pcall(function() return DataController:Get("Money") end)
        if ok and type(m) == "number" then return m end
    end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local cash = leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Cash")
        if cash and type(cash.Value) == "number" then return cash.Value end
    end
    return 0
end

-- ค้นหาแท่นฝึกพลัง (TrainingSpot) ของผู้เล่น
function Helpers.GetTrainingSpot()
    local lpp = Workspace:FindFirstChild("LocalPlotProps")
    local ta = lpp and lpp:FindFirstChild("TrainingArea")
    local spot = ta and ta:FindFirstChild("TrainingSpot")
    if spot and spot:IsA("BasePart") then
        return spot
    end
    local plotIndex = Helpers.GetPlotIndex()
    local plots = Workspace:FindFirstChild("Plots")
    local myPlot = plots and plots:FindFirstChild(tostring(plotIndex))
    if myPlot then
        local s = myPlot:FindFirstChild("TrainingSpot", true)
        if s and s:IsA("BasePart") then return s end
    end
    return nil
end

-- ค้นหาเส้นโยนอาหาร (StarterArea.CrossLine)
function Helpers.GetLaunchCFrame()
    local starterArea = Workspace:FindFirstChild("StarterArea")
    if starterArea then
        local crossLine = starterArea:FindFirstChild("CrossLine")
        if crossLine and crossLine:IsA("BasePart") then
            return crossLine.CFrame + Vector3.new(0, 3.5, 0)
        end
        return CFrame.new(starterArea.Position.X, starterArea.Position.Y + starterArea.Size.Y / 2 + 3.5, starterArea.Position.Z)
    end
    return nil
end

function Core:Destroy()
    pcall(Config.Save)
    Helpers.RecoverCharacter()
    self._alive = false
    for name in pairs(self._loops) do
        self:StopLoop(name)
    end
    for _, c in ipairs(self._conns) do
        pcall(function() c:Disconnect() end)
    end
    for _, fn in ipairs(self._cleanups) do
        pcall(fn)
    end
    if self._gui then
        pcall(function() self._gui:Destroy() end)
    end
    self._conns = {}
    self._cleanups = {}
    if ENV.__KUY == self then
        ENV.__KUY = nil
    end
end

-- =====================================================================
-- 7. FEATURE LOGIC & AUTOMATION LOOPS
-- =====================================================================

-- [ฟังก์ชันพิเศษ 1]: ดักจับสัญญาณกดคูณ 2 อัตโนมัติขณะฝึกซ้อม (Real-time Tap Bonus)
if remotes.Training_Bonus then
    Core:Connect(remotes.Training_Bonus.OnClientEvent, function(bonusId, expireTime)
        if not Core._alive or not (Core.Flags.AutoTapBonus or Core.Flags.AutoTrain) then
            return
        end
        if not bonusId or not remotes.Training_TapBonus then
            return
        end
        task.spawn(function()
            local ok, res = Net.Invoke(remotes.Training_TapBonus, bonusId)
            if ok and res and res.Ok then
                logAction("โบนัสคูณ 2", "กดคูณ 2 สำเร็จ! (Bonus ID: " .. tostring(bonusId) .. ")", true)
            else
                local reason = (res and res.Reason) or tostring(res)
                logAction("โบนัสคูณ 2", "กดคูณ 2 ไม่ผ่าน: " .. tostring(reason), false)
            end
        end)
    end)
end

Core:OnCleanup(function()
    if remotes.Training_Stop then
        pcall(function() Net.Invoke(remotes.Training_Stop) end)
    end
    Helpers.RecoverCharacter()
end)

-- [ฟังก์ชันหลัก 1]: ลูปฝึกซ้อม (Auto Train Power ปลอดภัย ไร้สถานะค้าง)
local function runTrainCycle()
    if Core.Busy then return end
    if not Helpers.IsAlive() then return end
    if not remotes.Training_Start then return end

    -- ล้างสถานะตกค้างหากมี
    Helpers.RecoverCharacter()

    -- ตรวจสอบแท่นฝึกเริ่มต้น หากยังไม่มี Stand ให้สั่งซื้อเริ่มต้นก่อน
    local curStand = 0
    if DataController and DataController.Get then
        pcall(function() curStand = DataController:Get("Stand") or 0 end)
    end
    if curStand < 1 and remotes.Stand_Upgrade then
        Net.Invoke(remotes.Stand_Upgrade)
        task.wait(0.3)
    end

    -- ตรวจสอบตำแหน่ง: ต้องยืนที่ TrainingSpot จึงจะเริ่มฝึกได้
    local spot = Helpers.GetTrainingSpot()
    local hrp = Helpers.GetRoot()
    if spot and hrp then
        local flatDist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(spot.Position.X, 0, spot.Position.Z)).Magnitude
        if flatDist > 8 then
            Helpers.TeleportTo(spot.Position + Vector3.new(0, 3, 0))
            task.wait(0.3)
        end
    end

    -- ตรวจสอบสถานะจริงของเซิร์ฟเวอร์
    local isTraining = (LocalPlayer:GetAttribute("Training") == true)
    if not isTraining then
        local ok, res = Net.Invoke(remotes.Training_Start)
        if ok and res and res.Ok then
            logAction("ฝึกพลัง", "เริ่มการฝึกซ้อมบนแท่นฝึกสำเร็จ", true)
        else
            local reason = (res and res.Reason) or tostring(res)
            logAction("ฝึกพลัง", "เริ่มฝึกไม่ได้: " .. tostring(reason), false)
        end
    end
end

-- [ฟังก์ชันหลัก 2]: ลูปโยนอาหารคะแนนเต็ม 100% (ป้องกันการค้างด้วย ClientState Isolation + Throw_Revealed)
local function runThrowCycle()
    if Core.Busy then return end
    if not Helpers.IsAlive() then return end
    if not remotes.Throw_Start or not remotes.Throw_Resolve or not remotes.Throw_Complete then
        return
    end

    -- ปลดล็อคและฟื้นฟูตัวละครก่อนเริ่ม
    Helpers.RecoverCharacter()

    -- หยุดฝึกซ้อมก่อนโยนอาหาร
    if LocalPlayer:GetAttribute("Training") and remotes.Training_Stop then
        Net.Invoke(remotes.Training_Stop)
        task.wait(0.4)
    end

    Core.Busy = true
    if ClientState then
        ClientState.Busy = "KuykuyThrow" -- บล็อก pollLine ของตัวเกมไม่ให้แย่งเปิด UI/ล็อคกล้อง
    end

    -- เคลื่อนย้ายตัวละครไปยังเส้นปล่อยอาหาร StarterArea
    local launchCF = Helpers.GetLaunchCFrame()
    local hrp = Helpers.GetRoot()
    if launchCF and hrp then
        local flatDist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(launchCF.Position.X, 0, launchCF.Position.Z)).Magnitude
        if flatDist > 10 then
            Helpers.TeleportTo(launchCF)
            task.wait(0.25)
        end
    end

    local okStart, startRes = Net.Invoke(remotes.Throw_Start)
    if okStart and startRes and startRes.Ok then
        if Core.Flags.AutoSuperThrow and remotes.Throw_UseSuper then
            pcall(function() Net.Invoke(remotes.Throw_UseSuper) end)
        end

        task.wait(0.15)

        -- ส่งผลความแม่นยำคะแนนเต็ม 100% (Meter Accuracy = 1.0)
        local accuracy = Core.Flags.PerfectThrow and 1.0 or 0.85
        local okResolve, resolveRes = Net.Invoke(remotes.Throw_Resolve, accuracy)

        if okResolve and resolveRes and resolveRes.Ok then
            -- รอเวลาจำลองการบินของอาหารและส่งสัญญาณ Throw_Revealed (ป้องกันเซิร์ฟเวอร์ตีกลับว่า "ลูกยังไม่ตก")
            task.wait(1.8)
            if remotes.Throw_Revealed then
                pcall(function() remotes.Throw_Revealed:FireServer() end)
            end
            task.wait(0.3)

            -- ยืนยันจบการโยนและรับรางวัล
            local okComp, compRes = Net.Invoke(remotes.Throw_Complete)
            local animalName = (compRes and compRes.AnimalName) or (resolveRes and resolveRes.ModelName) or "สัตว์ใหม่"
            logAction("โยนอาหาร", string.format("โยนคะแนนเต็ม 100%% สำเร็จ! ได้รับ: %s", tostring(animalName)), true)
        else
            local reason = (resolveRes and resolveRes.Reason) or tostring(resolveRes)
            logAction("โยนอาหาร", "Resolve ไม่สำเร็จ: " .. tostring(reason), false)
            if remotes.Throw_Cancel then pcall(function() Net.Invoke(remotes.Throw_Cancel) end) end
        end
    else
        local reason = (startRes and startRes.Reason) or tostring(startRes)
        logAction("โยนอาหาร", "เริ่มโยนไม่สำเร็จ: " .. tostring(reason), false)
    end

    Core.Busy = false
    Helpers.RecoverCharacter()
    task.wait(1.2)
end

-- [ฟังก์ชันหลัก 3]: ระบบอัปเกรดแท่นฝึก (พร้อม Anti-Spam Pre-check Guard ป้องกันแจ้งเตือนเงินไม่พอ)
local function runStandUpgrade()
    if not remotes.Stand_Upgrade then return end
    local curMoney = Helpers.GetMoney()
    local curStand = 0
    if DataController and DataController.Get then
        pcall(function() curStand = DataController:Get("Stand") or 0 end)
    end

    if StandsConfig and StandsConfig.Get then
        local nextStand = StandsConfig.Get(curStand + 1)
        if not nextStand then return end -- เลเวลสูงสุดแล้ว
        if curMoney < nextStand.Price then
            -- เงินไม่พอ! ข้ามทันที ไม่ยิง Remote เด็ดขาด (ป้องกันแจ้งเตือนเงินไม่พอเด้ง)
            return
        end
    end

    local ok, res = Net.Invoke(remotes.Stand_Upgrade)
    if ok and res and res.Ok then
        logAction("แท่นฝึก", "อัปเกรดแท่นฝึกสำเร็จ!", true)
    end
end

-- [ฟังก์ชันหลัก 4]: ระบบอัปเกรดขยายรั้ว (พร้อม Anti-Spam Pre-check Guard และการเข้าใกล้ป้าย)
local function runFenceUpgrade()
    if not remotes.Plot_UpgradeFence then return end
    local curMoney = Helpers.GetMoney()
    local curFence = 0
    if DataController and DataController.Get then
        pcall(function() curFence = DataController:Get("FenceLevel") or 0 end)
    end

    if FenceConfig and FenceConfig.Upgrades then
        local nextUpgrade = FenceConfig.Upgrades[curFence + 1]
        if not nextUpgrade then return end -- เลเวลสูงสุดแล้ว
        if curMoney < nextUpgrade.Price then
            -- เงินไม่พอ! ไม่ยิง Remote
            return
        end
    end

    -- เงินพอแล้ว เดินทางไปที่ป้ายอัปเกรดรั้วของแปลงตนเอง
    local plotIndex = Helpers.GetPlotIndex()
    local plots = Workspace:FindFirstChild("Plots")
    local myPlot = plots and plots:FindFirstChild(tostring(plotIndex))
    if myPlot and FenceConfig and FenceConfig.SignOffset then
        local signPos = myPlot.Position + FenceConfig.SignOffset
        Helpers.TeleportTo(signPos + Vector3.new(0, 3, 0))
        task.wait(0.25)
    end

    local ok, res = Net.Invoke(remotes.Plot_UpgradeFence)
    if ok and res and res.Ok then
        logAction("แปลงสัตว์", "อัปเกรดขยายรั้วสำเร็จ!", true)
    end
end

-- [ฟังก์ชันหลัก 5]: ระบบซื้ออาหารและใส่อาหารที่ดีที่สุดอัตโนมัติ (Auto Buy & Equip Best Food)
local function runFoodManagement()
    local curMoney = Helpers.GetMoney()

    -- 1. ซื้ออาหารอัตโนมัติ (เรียงจากระดับสูงสุดที่เงินพอซื้อ)
    if Core.Flags.AutoBuyFood and remotes.Shop_Buy and FoodsConfig and FoodsConfig.All then
        local allFoods = FoodsConfig.All
        for i = #allFoods, 1, -1 do
            local food = allFoods[i]
            local isOwned = false
            if i == 1 then
                isOwned = true
            elseif DataController and DataController.GetPath then
                isOwned = (DataController:GetPath("OwnedFoods." .. i) == true)
            end

            if not isOwned and food.Price and curMoney >= food.Price then
                local ok, res = Net.Invoke(remotes.Shop_Buy, i)
                if ok and res and res.Ok then
                    logAction("อาหาร", string.format("ซื้ออาหารสำเร็จ: ชิ้นที่ %d", i), true)
                    task.wait(0.3)
                    break
                end
            end
        end
    end

    -- 2. สวมใส่อาหารที่ดีที่สุดอัตโนมัติ
    if Core.Flags.AutoEquipFood and remotes.Shop_Equip and FoodsConfig and FoodsConfig.All then
        local allFoods = FoodsConfig.All
        local bestOwnedIndex = 1
        for i = #allFoods, 1, -1 do
            local isOwned = false
            if i == 1 then
                isOwned = true
            elseif DataController and DataController.GetPath then
                isOwned = (DataController:GetPath("OwnedFoods." .. i) == true)
            end
            if isOwned then
                bestOwnedIndex = i
                break
            end
        end

        local currentEquipped = 1
        if DataController and DataController.Get then
            currentEquipped = DataController:Get("EquippedFood") or 1
        end

        if currentEquipped ~= bestOwnedIndex then
            local ok, res = Net.Invoke(remotes.Shop_Equip, bestOwnedIndex)
            if ok and res and res.Ok then
                logAction("อาหาร", string.format("สวมใส่อาหารที่ดีที่สุดสำเร็จ: ชิ้นที่ %d", bestOwnedIndex), true)
            end
        end
    end
end

-- ลูปจัดการแปลงและสัตว์ (Auto Plot Management)
local function runPlotManagement()
    if Core.Flags.AutoEquipBest and remotes.Plot_EquipBest then
        local ok, res = Net.Invoke(remotes.Plot_EquipBest)
        if ok and res and res.Ok then
            logAction("แปลงสัตว์", "สวมใส่สัตว์ที่ทำเงินสูงสุดสำเร็จ", true)
        end
    end

    if Core.Flags.AutoUpgradeFence then
        runFenceUpgrade()
    end

    if Core.Flags.AutoSellAll and remotes.Plot_SellAll then
        if remotes.Plot_EquipBest then
            pcall(function() Net.Invoke(remotes.Plot_EquipBest) end)
            task.wait(0.2)
        end
        local ok, res = Net.Invoke(remotes.Plot_SellAll)
        if ok and res and res.Ok then
            logAction("แปลงสัตว์", "ขายสัตว์ที่ไม่ได้สวมใส่ทั้งหมดสำเร็จ", true)
        end
    end
end

-- ลูปเคลมของรางวัลอัตโนมัติ (Auto Claim Offline, Free Shop)
local function runClaimRewards()
    if Core.Flags.AutoClaimOffline and remotes.Offline_Claim then
        local ok, res = Net.Invoke(remotes.Offline_Claim)
        if ok and res and res.Ok then
            logAction("ของรางวัล", "เคลมเงินออฟไลน์สะสมสำเร็จ", true)
        end
    end

    if Core.Flags.AutoClaimFreeShop and remotes.Shop_ClaimFree then
        local ok, res = Net.Invoke(remotes.Shop_ClaimFree)
        if ok and res and res.Ok then
            logAction("ของรางวัล", "เคลมของขวัญฟรีร้านค้าสำเร็จ", true)
        end
    end

    if Core.Flags.AutoRingRush and remotes.RingRush_Begin then
        local ok, res = Net.Invoke(remotes.RingRush_Begin)
        if ok and res and res.Ok then
            task.wait(0.5)
            if remotes.RingRush_End then
                pcall(function() Net.Invoke(remotes.RingRush_End, true) end)
            end
            logAction("มินิเกม", "เคลม Ring Rush สำเร็จ", true)
        end
    end
end

-- ลูปต่อต้านการถูกเตะ AFK (Anti-AFK 20 นาที)
Core:Connect(LocalPlayer.Idled, function()
    if Core._alive and Core.Flags.AntiAfk then
        if VirtualUser then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            logAction("ความปลอดภัย", "ป้องกันการหลุด AFK สำเร็จ", true)
        end
    end
end)

-- ลูปเฝ้าระวังตัวละครแก้ค้างอัตโนมัติ (Watchdog Heartbeat)
Core:Connect(RunService.Heartbeat, function()
    if not Core._alive then return end
    if not Core.Busy then
        local hrp = Helpers.GetRoot()
        if hrp and hrp.Anchored then
            hrp.Anchored = false
        end
    end
end)

-- ผูกลูปเข้ากับ Core:Loop ตามการตั้งค่าที่โหลดมา
if Core.Flags.AutoThrow then Core:Loop("Loop_Throw", "AutoThrow", 1.8, runThrowCycle) end
if Core.Flags.AutoTrain then Core:Loop("Loop_Train", "AutoTrain", 2.2, runTrainCycle) end
if Core.Flags.AutoStandUpgrade then Core:Loop("Loop_Stand", "AutoStandUpgrade", 5.0, runStandUpgrade) end
if Core.Flags.AutoBuyFood then Core:Loop("Loop_Food", "AutoBuyFood", 4.0, runFoodManagement) end
if Core.Flags.AutoEquipBest then Core:Loop("Loop_Plot", "AutoEquipBest", 15.0, runPlotManagement) end
if Core.Flags.AutoClaimOffline then Core:Loop("Loop_Claims", "AutoClaimOffline", 30.0, runClaimRewards) end

-- =====================================================================
-- 8. KUYKUY DARK UI & REAL-TIME LOG VIEWER
-- =====================================================================
local UIColors = {
    Background = Color3.fromRGB(16, 16, 22),
    Sidebar    = Color3.fromRGB(22, 22, 30),
    Card       = Color3.fromRGB(28, 28, 40),
    CardBorder = Color3.fromRGB(44, 44, 62),
    Accent     = Color3.fromRGB(56, 217, 169),
    AccentOrange= Color3.fromRGB(255, 146, 43),
    Gold       = Color3.fromRGB(255, 212, 59),
    TextPrimary= Color3.fromRGB(245, 245, 250),
    TextSecondary= Color3.fromRGB(160, 160, 180),
    Success    = Color3.fromRGB(81, 207, 102),
    Danger     = Color3.fromRGB(255, 107, 107),
}

-- ล้าง UI เก่าถ้ามีอยู่
local oldUI = (CoreGui and CoreGui:FindFirstChild("KUYKUY_FeedAnimals_Gui"))
    or (LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("KUYKUY_FeedAnimals_Gui"))
if oldUI then pcall(function() oldUI:Destroy() end) end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KUYKUY_FeedAnimals_Gui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parented = false
if gethui then
    parented = pcall(function() ScreenGui.Parent = gethui() end)
end
if not parented and CoreGui then
    parented = pcall(function() ScreenGui.Parent = CoreGui end)
end
if not parented or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

Core._gui = ScreenGui
Core:OnCleanup(function() pcall(function() ScreenGui:Destroy() end) end)

-- Floating Action Button (ปุ่มลอย 52x52 px ลายการ์ตูนควาย)
local FloatButton = Instance.new("TextButton")
FloatButton.Name = "KUYKUY_FloatButton"
FloatButton.Size = UDim2.new(0, 52, 0, 52)
FloatButton.Position = UDim2.new(0, 25, 0.4, 0)
FloatButton.BackgroundColor3 = UIColors.Card
FloatButton.Text = "🐃"
FloatButton.TextSize = 28
FloatButton.AutoButtonColor = false
FloatButton.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatButton

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = UIColors.Accent
FloatStroke.Thickness = 2.0
FloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
FloatStroke.Parent = FloatButton

-- MainFrame (580 x 440 px)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 580, 0, 440)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = UIColors.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = UIColors.CardBorder
MainStroke.Thickness = 1.2
MainStroke.Parent = MainFrame

-- Header (44 px)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = UIColors.Sidebar
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 460, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextColor3 = UIColors.TextPrimary
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.RichText = true
TitleLabel.Text = "KUYKUY HUB <font color=\"#38D9A9\">โยนอาหารให้สัตว์</font> <font color=\"#FF922B\">v2.4</font>"
TitleLabel.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -14)
CloseBtn.BackgroundColor3 = UIColors.Card
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "—"
CloseBtn.TextColor3 = UIColors.TextSecondary
CloseBtn.TextSize = 14
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Sidebar (145 px)
local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 145, 1, -44)
Sidebar.Position = UDim2.new(0, 0, 0, 44)
Sidebar.BackgroundColor3 = UIColors.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 2
Sidebar.ScrollBarImageColor3 = UIColors.CardBorder
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

-- Content Frame
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -145, 1, -70)
ContentFrame.Position = UDim2.new(0, 145, 0, 44)
ContentFrame.BackgroundColor3 = UIColors.Background
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

-- Status Bar (26 px)
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Size = UDim2.new(1, -145, 0, 26)
StatusBar.Position = UDim2.new(0, 145, 1, -26)
StatusBar.BackgroundColor3 = UIColors.Sidebar
StatusBar.BorderSizePixel = 0
StatusBar.Parent = MainFrame

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -20, 1, 0)
StatusText.Position = UDim2.new(0, 10, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Font = Enum.Font.RobotoMono
StatusText.TextSize = 11
StatusText.TextColor3 = UIColors.TextSecondary
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Text = "สถานะ: ACTIVE | Watchdog ป้องกันค้างพร้อมทำงาน"
StatusText.Parent = StatusBar

-- Draggable Logic
local function MakeDraggable(dragHandle, targetFrame)
    local dragging, dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
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
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

MakeDraggable(Header, MainFrame)
MakeDraggable(FloatButton, FloatButton)

-- Toggle UI Window
local isWindowOpen = true
local function ToggleWindow()
    isWindowOpen = not isWindowOpen
    if isWindowOpen then
        MainFrame.Visible = true
        TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0, 580, 0, 440)
        }):Play()
    else
        local tw = TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0, 580, 0, 0)
        })
        tw:Play()
        tw.Completed:Connect(function()
            if not isWindowOpen then MainFrame.Visible = false end
        end)
    end
end

FloatButton.MouseButton1Click:Connect(ToggleWindow)
CloseBtn.MouseButton1Click:Connect(ToggleWindow)

-- Tab Controller
local TabPages = {}
local TabButtons = {}

local function CreateTabPage(pageId)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "TabContent_" .. pageId
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = UIColors.Accent
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
    btn.BackgroundColor3 = isDefault and UIColors.Accent or UIColors.Card
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.TextColor3 = isDefault and Color3.fromRGB(16, 16, 22) or UIColors.TextSecondary
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
            b.BackgroundColor3 = active and UIColors.Accent or UIColors.Card
            b.TextColor3 = active and Color3.fromRGB(16, 16, 22) or UIColors.TextSecondary
        end
        if tabId == "LogsTab" and Core._updateLogUI then
            pcall(Core._updateLogUI)
        end
    end)

    TabButtons[tabId] = btn
    return btn
end

-- Component Builders: Toggle Card (เชื่อมกับ Flag และ Auto Save)
local function CreateToggle(parent, flagKey, title, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 42)
    card.BackgroundColor3 = UIColors.Card
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = UIColors.CardBorder
    stroke.Thickness = 1
    stroke.Parent = card

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = UIColors.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = title
    label.Parent = card

    local initialValue = (Core.Flags[flagKey] == true)
    local toggleTrack = Instance.new("TextButton")
    toggleTrack.Size = UDim2.new(0, 44, 0, 22)
    toggleTrack.Position = UDim2.new(1, -54, 0.5, -11)
    toggleTrack.BackgroundColor3 = initialValue and UIColors.Accent or UIColors.Sidebar
    toggleTrack.Text = ""
    toggleTrack.Parent = card

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = toggleTrack

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initialValue and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = toggleTrack

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local state = initialValue
    local lastClick = 0
    local function onToggle()
        local now = os.clock()
        if now - lastClick < 0.25 then return end
        lastClick = now
        state = not state
        Core.Flags[flagKey] = state
        local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetColor = state and UIColors.Accent or UIColors.Sidebar
        TweenService:Create(knob, TweenInfo.new(0.2), { Position = targetPos }):Play()
        TweenService:Create(toggleTrack, TweenInfo.new(0.2), { BackgroundColor3 = targetColor }):Play()
        logAction("การตั้งค่า", (state and "เปิด: " or "ปิด: ") .. title, state)
        if callback then callback(state) end
        pcall(Config.Save)
    end

    toggleTrack.MouseButton1Click:Connect(onToggle)
end

-- Component Builders: Action Button
local function CreateButton(parent, text, bgColor, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = bgColor or UIColors.Card
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = UIColors.TextPrimary
    btn.Text = text
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
    return btn
end

-- Component Builders: Section Title
local function CreateSection(parent, title)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextColor3 = UIColors.Accent
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = "— " .. title
    lbl.Parent = parent
end

-- =====================================================================
-- BUILD TAB CONTENTS
-- =====================================================================

-- 1. แท็บฟาร์มหลัก (Farm Tab)
local FarmPage = CreateTabPage("FarmTab")
FarmPage.Visible = true
AddTabButton("FarmTab", "🎮 ฟาร์มหลัก", true, 1)

CreateSection(FarmPage, "ระบบโยนอาหาร (Food Throwing)")
CreateToggle(FarmPage, "AutoThrow", "โยนอาหารอัตโนมัติ (Auto Throw)", function(val)
    if val then
        Core:Loop("Loop_Throw", "AutoThrow", 1.8, runThrowCycle)
    else
        Core:StopLoop("Loop_Throw")
        Helpers.RecoverCharacter()
    end
end)

CreateToggle(FarmPage, "PerfectThrow", "บังคับคะแนนเต็ม 100% (Perfect Meter)", function(val)
end)

CreateToggle(FarmPage, "AutoSuperThrow", "เปิดใช้ Super Throw อัตโนมัติ", function(val)
end)

CreateSection(FarmPage, "ระบบฝึกซ้อมพลัง (Power Training)")
CreateToggle(FarmPage, "AutoTrain", "ฝึกพลังอัตโนมัติ (Auto Train)", function(val)
    if val then
        Core:Loop("Loop_Train", "AutoTrain", 2.2, runTrainCycle)
    else
        Core:StopLoop("Loop_Train")
        if remotes.Training_Stop then pcall(function() Net.Invoke(remotes.Training_Stop) end) end
        Helpers.RecoverCharacter()
    end
end)

CreateToggle(FarmPage, "AutoTapBonus", "กดคูณ 2 อัตโนมัติขณะฝึกซ้อม (2x Tap Bonus)", function(val)
end)

CreateToggle(FarmPage, "AutoStandUpgrade", "อัปเกรดแท่นฝึกอัตโนมัติ (Auto Stand Upgrade)", function(val)
    if val then
        Core:Loop("Loop_Stand", "AutoStandUpgrade", 5.0, runStandUpgrade)
    else
        Core:StopLoop("Loop_Stand")
    end
end)

-- 2. แท็บอาหารและร้านค้า (Food Tab)
local FoodPage = CreateTabPage("FoodTab")
AddTabButton("FoodTab", "🍖 อาหาร/ร้านค้า", false, 2)

CreateSection(FoodPage, "ระบบจัดการอาหาร (Foods Management)")
CreateToggle(FoodPage, "AutoBuyFood", "ซื้ออาหารที่ดีที่สุดอัตโนมัติ (Auto Buy Food)", function(val)
    if val then
        Core:Loop("Loop_Food", "AutoBuyFood", 4.0, runFoodManagement)
    else
        Core:StopLoop("Loop_Food")
    end
end)

CreateToggle(FoodPage, "AutoEquipFood", "ใส่อาหารที่ดีที่สุดอัตโนมัติ (Auto Equip Food)", function(val)
end)

CreateButton(FoodPage, "⚡ ซื้อและใส่อาหารที่ดีที่สุดทันที (Buy & Equip Best Now)", UIColors.Card, function()
    runFoodManagement()
end)

-- 3. แท็บจัดการแปลง (Plot Tab)
local PlotPage = CreateTabPage("PlotTab")
AddTabButton("PlotTab", "🏡 จัดการแปลง", false, 3)

CreateSection(PlotPage, "ระบบจัดการสัตว์และรั้ว (Animals & Plot)")
CreateToggle(PlotPage, "AutoEquipBest", "สวมใส่สัตว์ที่ดีที่สุดอัตโนมัติ (Equip Best)", function(val)
    if val then
        Core:Loop("Loop_Plot", "AutoEquipBest", 15.0, runPlotManagement)
    else
        Core:StopLoop("Loop_Plot")
    end
end)

CreateToggle(PlotPage, "AutoUpgradeFence", "ขยายรั้วความจุสัตว์อัตโนมัติ (Upgrade Fence)", function(val)
end)

CreateToggle(PlotPage, "AutoSellAll", "ขายสัตว์ที่ไม่ได้สวมใส่ทั้งหมด (Auto Sell All)", function(val)
end)

CreateButton(PlotPage, "⚡ สวมใส่สัตว์ดีที่สุดทันที (Equip Best Now)", UIColors.Card, function()
    if remotes.Plot_EquipBest then
        local ok, res = Net.Invoke(remotes.Plot_EquipBest)
        if ok and res and res.Ok then
            logAction("แปลงสัตว์", "สวมใส่สัตว์ที่ดีที่สุดทันทีสำเร็จ", true)
        end
    end
end)

CreateButton(PlotPage, "💰 ขายสัตว์ที่ไม่ได้ใส่ทันที (Sell All Now)", UIColors.Card, function()
    if remotes.Plot_SellAll then
        local ok, res = Net.Invoke(remotes.Plot_SellAll)
        if ok and res and res.Ok then
            logAction("แปลงสัตว์", "ขายสัตว์ที่ไม่ได้สวมใส่ทันทีสำเร็จ", true)
        end
    end
end)

-- 4. แท็บของรางวัล (Rewards Tab)
local RewardsPage = CreateTabPage("RewardsTab")
AddTabButton("RewardsTab", "🎁 ของรางวัล", false, 4)

CreateSection(RewardsPage, "ระบบเคลมรางวัลอัตโนมัติ (Auto Claim)")
CreateToggle(RewardsPage, "AutoClaimOffline", "เคลมเงินออฟไลน์สะสม (Offline Earnings)", function(val)
    if val then
        Core:Loop("Loop_Claims", "AutoClaimOffline", 30.0, runClaimRewards)
    else
        Core:StopLoop("Loop_Claims")
    end
end)

CreateToggle(RewardsPage, "AutoClaimFreeShop", "เคลมของขวัญฟรีร้านค้า (Free Shop Gift)", function(val)
end)

CreateToggle(RewardsPage, "AutoRingRush", "เล่นมินิเกม Ring Rush อัตโนมัติ", function(val)
end)

CreateButton(RewardsPage, "🎉 เคลมรางวัลทั้งหมดทันที (Claim All Now)", UIColors.Card, function()
    runClaimRewards()
end)

-- 5. แท็บบันทึกสถานะ Real-time Logs (Logs Tab)
local LogsPage = CreateTabPage("LogsTab")
AddTabButton("LogsTab", "📋 บันทึกสด", false, 5)

local LogContainer = Instance.new("Frame")
LogContainer.Size = UDim2.new(1, 0, 0, 0)
LogContainer.AutomaticSize = Enum.AutomaticSize.Y
LogContainer.BackgroundTransparency = 1
LogContainer.Parent = LogsPage

local LogList = Instance.new("UIListLayout")
LogList.Padding = UDim.new(0, 4)
LogList.SortOrder = Enum.SortOrder.LayoutOrder
LogList.Parent = LogContainer

local function renderLogs()
    for _, ch in ipairs(LogContainer:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end

    for idx, entry in ipairs(Stats.logs) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundColor3 = (idx % 2 == 0) and UIColors.Card or UIColors.Sidebar
        row.BorderSizePixel = 0
        row.LayoutOrder = idx
        row.Parent = LogContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = row

        local timeLbl = Instance.new("TextLabel")
        timeLbl.Size = UDim2.new(0, 65, 1, 0)
        timeLbl.Position = UDim2.new(0, 6, 0, 0)
        timeLbl.BackgroundTransparency = 1
        timeLbl.Font = Enum.Font.RobotoMono
        timeLbl.TextSize = 10
        timeLbl.TextColor3 = UIColors.TextSecondary
        timeLbl.TextXAlignment = Enum.TextXAlignment.Left
        timeLbl.Text = string.format("[%s]", entry.time)
        timeLbl.Parent = row

        local catLbl = Instance.new("TextLabel")
        catLbl.Size = UDim2.new(0, 75, 1, 0)
        catLbl.Position = UDim2.new(0, 75, 0, 0)
        catLbl.BackgroundTransparency = 1
        catLbl.Font = Enum.Font.GothamBold
        catLbl.TextSize = 10
        catLbl.TextColor3 = entry.ok and UIColors.Accent or UIColors.Danger
        catLbl.TextXAlignment = Enum.TextXAlignment.Left
        catLbl.Text = entry.cat
        catLbl.Parent = row

        local msgLbl = Instance.new("TextLabel")
        msgLbl.Size = UDim2.new(1, -160, 1, 0)
        msgLbl.Position = UDim2.new(0, 155, 0, 0)
        msgLbl.BackgroundTransparency = 1
        msgLbl.Font = Enum.Font.GothamMedium
        msgLbl.TextSize = 11
        msgLbl.TextColor3 = UIColors.TextPrimary
        msgLbl.TextXAlignment = Enum.TextXAlignment.Left
        msgLbl.TextTruncate = Enum.TextTruncate.AtEnd
        msgLbl.Text = entry.msg
        msgLbl.Parent = row
    end
end

Core._updateLogUI = function()
    if LogsPage.Visible then
        renderLogs()
    end
end

-- 6. แท็บตั้งค่าและปิดสคริปต์ (Settings Tab)
local SettingsPage = CreateTabPage("SettingsTab")
AddTabButton("SettingsTab", "⚙️ ตั้งค่า", false, 6)

CreateSection(SettingsPage, "ความปลอดภัยและระบบ (Safety & System)")
CreateToggle(SettingsPage, "AntiAfk", "กันเตะออกจากเกม (Anti-AFK 20 นาที)", function(val)
end)

CreateButton(SettingsPage, "🛡️ ปลดล็อคตัวละครฉุกเฉิน (Fix Stuck Character)", UIColors.Card, function()
    Helpers.RecoverCharacter()
    logAction("ความปลอดภัย", "ปลดล็อคตัวละครและคืนค่ากล้องสำเร็จ", true)
end)

CreateSection(SettingsPage, "ระบบจดจำการตั้งค่า (Config Management)")
CreateButton(SettingsPage, "💾 บันทึกการตั้งค่าตอนนี้ (Save Config)", UIColors.Card, function()
    local ok = Config.Save()
    if ok then
        logAction("การตั้งค่า", "บันทึกการตั้งค่าลงเครื่องสำเร็จ (" .. Config.FILE .. ")", true)
    end
end)

CreateButton(SettingsPage, "🔄 โหลดการตั้งค่าเดิม (Reload Config)", UIColors.Card, function()
    local ok, src = Config.Load()
    if ok then
        logAction("การตั้งค่า", "โหลดการตั้งค่าสำเร็จ (" .. tostring(src) .. ")", true)
    end
end)

CreateButton(SettingsPage, "🗑️ ล้างประวัติบันทึกสด (Clear Logs)", UIColors.Card, function()
    Stats.logs = {}
    renderLogs()
end)

CreateButton(SettingsPage, "⛔ ปิดสคริปต์ฉุกเฉิน (Unload / Destroy Kuykuy Hub)", UIColors.Danger, function()
    logAction("ระบบ", "ปิดการทำงานสคริปต์ Kuykuy Hub เรียบร้อยแล้ว", true)
    task.wait(0.2)
    Core:Destroy()
end)

-- เริ่มต้นระบบ
logAction("ระบบ", string.format("Kuykuy Hub v2.4 โหลดสำเร็จ (การตั้งค่า: %s)", loadedFromDisk and "โหลดการตั้งค่าเดิมแล้ว" or "ค่าเริ่มต้น"), true)

print("[Kuykuy Hub] โยนอาหารให้สัตว์ v2.4 โหลดสำเร็จ 100%")
