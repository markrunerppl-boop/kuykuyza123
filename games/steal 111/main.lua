-- Kuykuy Hub | ขโมยแพ็คอนิเมะ (PlaceId 133151378618377)
-- โครงสร้าง: Core(State/Cleanup) -> Helpers(Plot/POI) -> Net -> Features(Treadmill, StealPacks) -> UI
-- ไม่ใช้ไวยากรณ์ type/strict เพื่อให้เข้ากับ executor ทุกตัว; error ทั้งหมดจะ warn ขึ้น console ด้วยคำนำหน้า [Kuy]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local cgOk, cgSvc = pcall(function() return game:GetService("CoreGui") end)
local CoreGui = cgOk and cgSvc or nil
local vimOk, vimSvc = pcall(function() return game:GetService("VirtualInputManager") end)
local VirtualInputManager = vimOk and vimSvc or nil
local vuOk, vuSvc = pcall(function() return game:GetService("VirtualUser") end)
local VirtualUser = vuOk and vuSvc or nil

local LocalPlayer = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

local TELEPORT_LOADER = [[
task.spawn(function()
	task.wait(1.5)
	local v = tostring(tick())
	local ok, src = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/script.lua?v=" .. v)
	if ok and type(src) == "string" and #src > 100 then
		loadstring(src)()
		return
	end
	local okDirect, srcDirect = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/games/steal%20111/main.lua?v=" .. v)
	if okDirect and type(srcDirect) == "string" and #srcDirect > 100 then
		loadstring(srcDirect)()
		return
	end
	if getgenv and getgenv().__KUY_RAW_SOURCE then
		loadstring(getgenv().__KUY_RAW_SOURCE)()
	end
end)
]]

local function queueScriptOnTeleport(scriptSource)
	local qot = (syn and syn.queue_on_teleport)
		or (fluxus and fluxus.queue_on_teleport)
		or queue_on_teleport
		or (getgenv and getgenv().queue_on_teleport)
	if ENV.__KUY_TELEPORT_QUEUED == true then return end
	if type(qot) == "function" then
		ENV.__KUY_TELEPORT_QUEUED = true
		pcall(qot, scriptSource or TELEPORT_LOADER)
	end
end

pcall(function()
	LocalPlayer.OnTeleport:Connect(function()
		queueScriptOnTeleport(TELEPORT_LOADER)
	end)
end)

local TRAINING_ATTR = "TrainingOnTreadmill"
local COMBO_ATTR = "TreadmillCombo"
local RP = "ReplicatedStorage.Remotes."

-- Fallback ฉุกเฉินกรณี require(PacksConfig/Types) ล้มเหลวเท่านั้น (ปกติอ่านสดจากเกมจริง 100%)
local STEAL_RARITY_KEYS = {
	"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical",
	"Cosmic", "Divine", "Omniversal", "Eternal", "Primordial",
	"Exclusive", "Godlike", "Absolute", "Mystery", "Immortal"
}

local STAGE_CENTERS = {
	[1] = Vector3.new(1257, 68, -365),
	[2] = Vector3.new(1373, 68, -366),
	[3] = Vector3.new(1555, 68, -366),
	[4] = Vector3.new(1777, 68, -366),
	[5] = Vector3.new(2055, 68, -366),
	[6] = Vector3.new(2432, 68, -366),
	[7] = Vector3.new(2961, 68, -366),
	[8] = Vector3.new(3589, 68, -366),
	[9] = Vector3.new(4178, 68, -366),
	[10] = Vector3.new(4820, 68, -366),
	[11] = Vector3.new(5490, 68, -365),
	[12] = Vector3.new(6135, 68, -364),
	[13] = Vector3.new(6875, 68, -364),
}

local function main()

	-----------------------------------------------------------------
	-- 1. CORE: State & Cleanup (รันซ้ำ = ล้างของเก่าอัตโนมัติ)
	-----------------------------------------------------------------
	if ENV.__KUY and type(ENV.__KUY.Destroy) == "function" then
		pcall(function() ENV.__KUY:Destroy() end)
	end

	local Config = {}

	local Core = {
		Flags = {},
		Busy = false,
		_busyOwner = nil,
		_conns = {},
		_loops = {},
		_cleanups = {},
		_alive = true,
	}
	local Loops = {}

	function Core:AcquireBusy(owner, force)
		if self.Busy and self._busyOwner and self._busyOwner ~= owner and not force then
			return false
		end
		self.Busy = true
		self._busyOwner = owner or "unknown"
		return true
	end

	function Core:ReleaseBusy(owner)
		if not owner or self._busyOwner == owner then
			self.Busy = false
			self._busyOwner = nil
		end
	end

	function Core:IsBusyByOther(owner)
		return self.Busy and self._busyOwner ~= nil and self._busyOwner ~= owner
	end

	function Core:Connect(signal, fn)
		local c = signal:Connect(fn)
		table.insert(self._conns, c)
		return c
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

	function Core:IsLoopRunning(name)
		local th = self._loops[name]
		if not th then return false end
		if typeof(th) == "thread" then
			return coroutine.status(th) ~= "dead"
		end
		return true
	end

	-- ลูปผูกกับ flag: flag เป็น false หรือ Destroy -> หยุดเอง
	function Core:Loop(name, flag, interval, fn)
		self:StopLoop(name)
		local myThread = task.spawn(function()
			local cur = coroutine.running()
			while self._alive and self.Flags[flag] do
				local ok, err = pcall(fn)
				if not ok then
					warn("[Kuy] loop '" .. name .. "': " .. tostring(err))
				end
				if not (self._alive and self.Flags[flag]) then break end
				task.wait(interval)
			end
			if self._loops[name] == cur then
				self._loops[name] = nil
			end
		end)
		if typeof(myThread) == "thread" and coroutine.status(myThread) ~= "dead" then
			self._loops[name] = myThread
		end
	end

	function Core:Destroy()
		if Config and Config.Save then
			pcall(Config.Save)
		end
		self._alive = false
		self.Busy = false
		self._busyOwner = nil
		for name in pairs(self._loops) do
			self:StopLoop(name)
		end
		for _, c in ipairs(self._conns) do
			pcall(function() c:Disconnect() end)
		end
		for _, fn in ipairs(self._cleanups) do
			pcall(fn)
		end
		self._conns = {}
		self._cleanups = {}
		if ENV.__KUY == self then
			ENV.__KUY = nil
		end
	end

	ENV.__KUY = Core

	Core.Flags.AutoTreadmill = false -- กดคูณอัตโนมัติ (ทำคอมโบ)
	Core.Flags.AutoEnter = false     -- เดินเข้าลู่วิ่งอัตโนมัติ
	Core.Flags.AutoSteal = false     -- ขโมยแพ็คตามด่านที่เลือก
	Core.Flags.AutoPlacePacks = false -- วางแพ็คในฐานอัตโนมัติเมื่อพร้อม (แยกเปิดอิสระ)
	Core.Flags.AntiRagdollMode = true -- ลบอนิเมชชั่นโดนตี/ไม่ล้ม เพื่อวิ่งกลับฐานต่อเนื่อง
	Core.Flags.AutoBuyCoach = false   -- ซื้อโค้ชที่แรงกว่าใน Stock อัตโนมัติ
	Core.Flags.AutoEquipCoach = false -- สวมใส่โค้ชที่ตัวคูณสูงสุดอัตโนมัติ
	Core.Flags.AutoBuyAura = false    -- ซื้อออร่าที่แรงกว่าที่มีอัตโนมัติ
	Core.Flags.AutoEquipAura = false  -- สวมใส่ออร่าที่ตัวคูณสูงสุดอัตโนมัติ
	Core.Flags.AutoOpenPacks = false  -- เปิดแพ็กในกระเป๋าอัตโนมัติ
	Core.Flags.AutoEquipBest = false  -- วางตัวละครดีสุดลงฐานอัตโนมัติ
	Core.Flags.AutoSellUnits = false  -- ขายยูนิตต่ำกว่าระดับที่ตั้งไว้
	Core.Flags.SellBelowRarity = 6    -- 3=Rare, 4=Epic, 5=Legendary, 6=Mythical, 7=Cosmic, 8=Divine
	Core.Flags.KeepMutated = true     -- เก็บตัวที่มี Mutation ไว้ไม่ขาย
	Core.Flags.AutoMerge = false      -- รวมแพ็กซ้ำ 2 ชิ้นอัตโนมัติ
	Core.Flags.AutoFuse = false       -- กลายพันธุ์ยูนิตซ้ำ 3 ตัวอัตโนมัติ
	Core.Flags.AutoUpgradeTreadmill = false -- อัปเกรดลู่วิ่งอัตโนมัติ
	Core.Flags.AutoUpgradeBase = false      -- อัปเกรดฐานอัตโนมัติ
	Core.Flags.AutoUpgradeLuck = false      -- อัปเกรดโชคในบ้านอัตโนมัติ (Upgrade Luck Machine)
	Core.Flags.AutoRebirth = false          -- เกิดใหม่อัตโนมัติเมื่อ Speed ถึงเกณฑ์
	Core.Flags.AutoClaim = false            -- เคลม Offline / Daily / Index อัตโนมัติ
	Core.Flags.AutoEnterDungeon = false     -- ลงดันเจี้ยนอัตโนมัติเมื่อประตูเปิด
	Core.Flags.AutoDungeonUlt = true        -- เปิดท่าไม้ตายออโต้ในดันเจี้ยน
	Core.Flags.AutoDungeonAttack = true     -- ตีออโต้ในดันเจี้ยน
	Core.Flags.AutoDungeonExit = true       -- ออกดันเจี้ยนอัตโนมัติเมื่อจบเกม
	Core.Flags.AutoDungeonSkipIntro = true  -- ข้ามคัตซีนเปิดตัวอัตโนมัติ
Core.Flags.DungeonTargetFloor = 500     -- ชั้นที่ต้องการรีสตาร์ทดันเจี้ยน (ตัวเลขอะไรก็ได้ >= 1)
Core.Flags.DungeonFloorLoop = true    -- โหมดรีสตาร์ทดันเจี้ยน 2 ครั้งเมื่อถึงชั้นที่ระบุ (ไม่ออกดันเจี้ยน)
	Core.Flags.AntiAfk = true               -- กันเตะ AFK 20 นาที
	Core.Flags.StealDelay = 1
	Core.Flags.OutrunMargin = 1.0          -- อัตราส่วนความเร็วเราเทียบกับบอส (>= 1.0 คือวิ่งทัน; ล็อกเก็บเฉพาะ 1 ด่านเร็วที่สุดที่วิ่งทันเสมอ)
	local initMaxStage = 13
	pcall(function()
		local game_ = Workspace:FindFirstChild("Game")
		local packs = game_ and game_:FindFirstChild("Packs")
		if packs then
			for _, ch in ipairs(packs:GetChildren()) do
				local num = tonumber(string.match(ch.Name, "%d+"))
				if num and num > initMaxStage then initMaxStage = num end
			end
		end
	end)
	for i = 1, initMaxStage do
		Core.Flags["Stage" .. i] = true
	end
	for _, r in ipairs(STEAL_RARITY_KEYS) do
		Core.Flags["Rarity_" .. r] = true
	end

	local Stats = { boosts = 0, stealOk = 0, stealFail = 0, last = "-", evt = "-", logs = {} }

	local function logAction(category, msg, isSuccess)
		local timeStr = os.date("%H:%M:%S")
		local entry = { time = timeStr, cat = category, msg = tostring(msg), ok = isSuccess }
		table.insert(Stats.logs, 1, entry)
		if #Stats.logs > 80 then
			table.remove(Stats.logs)
		end
		Stats.last = string.format("[%s] %s", category, tostring(msg))
		if Core and Core._updateLogUI then
			pcall(Core._updateLogUI)
		end
	end

	-----------------------------------------------------------------
	-- 1.1. CONFIG MANAGER (ระบบจดจำฟังก์ชันและการตั้งค่าอัตโนมัติ)
	-----------------------------------------------------------------
	Config.FILE = "kuykuy_steal111_config.json"

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

	function Config._serializeFallback(data)
		local lines = { "--KUY_CFG_V1--" }
		for k, v in pairs(data) do
			local tv = type(v)
			if tv == "boolean" then
				table.insert(lines, string.format("%s=b:%s", tostring(k), v and "1" or "0"))
			elseif tv == "number" then
				table.insert(lines, string.format("%s=n:%s", tostring(k), tostring(v)))
			elseif tv == "string" then
				table.insert(lines, string.format("%s=s:%s", tostring(k), v))
			end
		end
		return table.concat(lines, "\n")
	end

	function Config._deserializeFallback(str)
		local data = {}
		for line in string.gmatch(str, "[^\r\n]+") do
			local k, t, val = string.match(line, "^([^=]+)=([bns]):(.+)$")
			if k and t and val then
				if t == "b" then
					data[k] = (val == "1" or val == "true")
				elseif t == "n" then
					local num = tonumber(val)
					if num then data[k] = num end
				elseif t == "s" then
					data[k] = val
				end
			end
		end
		return data
	end

	function Config._encode(data)
		local okJson, json = pcall(function()
			return HttpService:JSONEncode(data)
		end)
		if okJson and type(json) == "string" and #json > 2 then
			return json
		end
		return Config._serializeFallback(data)
	end

	function Config._decode(str)
		if not str or type(str) ~= "string" or #str < 2 then return nil end
		local okJson, parsed = pcall(function()
			return HttpService:JSONDecode(str)
		end)
		if okJson and type(parsed) == "table" then
			return parsed
		end
		local fallbackData = Config._deserializeFallback(str)
		if next(fallbackData) ~= nil then
			return fallbackData
		end
		return nil
	end

	function Config._safeWriteFile(path, content)
		local w = Config._getFS()
		local diskOk, diskErr = false, "no_writefile"
		if type(w) == "function" then
			local ok, err = pcall(w, path, content)
			if ok then
				diskOk = true
			else
				diskErr = tostring(err)
			end
		end
		ENV.__KUY_CONFIG_CACHE = content
		return diskOk, diskErr
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
			if k ~= "UI" then
				local tv = type(v)
				if tv == "boolean" or tv == "number" or tv == "string" then
					dataToSave[k] = v
				end
			end
		end
		local encoded = Config._encode(dataToSave)
		local diskOk, diskErr = Config._safeWriteFile(Config.FILE, encoded)
		if diskOk then
			return true, "disk"
		elseif ENV.__KUY_CONFIG_CACHE then
			return true, "session"
		end
		return false, diskErr or "save_failed"
	end

	function Config.Load()
		local okRead, content, source = Config._safeReadFile(Config.FILE)
		if not okRead or not content then
			return false, "not_found"
		end

		local parsed = Config._decode(content)
		if not parsed or type(parsed) ~= "table" then
			return false, "decode_failed"
		end

		local removedKeys = {
			OutrunOnly = true,
			TargetFastestOnly = true,
			MaxStageStealPacks = true,
		}
		local count = 0
		for k, v in pairs(parsed) do
			if not removedKeys[k] then
				if Core.Flags[k] ~= nil and type(Core.Flags[k]) == type(v) then
					Core.Flags[k] = v
					count = count + 1
				elseif string.sub(k, 1, 5) == "Stage" and type(v) == "boolean" then
					Core.Flags[k] = v
					count = count + 1
				elseif Core.Flags[k] == nil then
					local tv = type(v)
					if tv == "boolean" or tv == "number" or tv == "string" then
						Core.Flags[k] = v
						count = count + 1
					end
				end
			end
		end
		return true, source, count
	end

	local loadedOk, loadSrc, loadCount = Config.Load()
	if loadedOk then
		logAction("ตั้งค่า", string.format("โหลดฟังก์ชันที่บันทึกไว้สำเร็จ (%s, %d ค่า)", loadSrc == "disk" and "จากไฟล์" or "จากแคช", loadCount or 0), true)
	else
		logAction("ตั้งค่า", "ใช้ค่าเริ่มต้น (ยังไม่มีไฟล์บันทึก)", true)
	end

	pcall(function()
		game:BindToClose(function()
			if Config and Config.Save then
				pcall(Config.Save)
			end
		end)
	end)

	-----------------------------------------------------------------
	-- 2. HELPERS: Plot / POI / Teleport
	-----------------------------------------------------------------
	local Helpers = {
		plotCache = nil,
		plotSpawnPosCache = nil,
		mutatePadCache = nil,
	}
	local M = {} -- Module & Config caches

	local function safeRequire(getter)
		local ok, mod = pcall(function() return require(getter()) end)
		if ok and type(mod) == "table" then return mod end
		return nil
	end

	local function getSafeZoneUtil()
		if not M.SafeZoneUtil then
			M.SafeZoneUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.SafeZoneUtil end)
		end
		return M.SafeZoneUtil
	end

	local function getPlotUtil()
		if not M.PlotUtil then
			M.PlotUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.PlotUtil end)
		end
		return M.PlotUtil
	end

	local function getServerData()
		if not M.ServerData then
			M.ServerData = safeRequire(function() return ReplicatedStorage.Shared.Modules.DataReceiver.ServerData end)
		end
		return M.ServerData
	end

	local function getPlayerData()
		if not M.PlayerData then
			M.PlayerData = safeRequire(function() return ReplicatedStorage.Shared.Modules.DataReceiver.PlayerData end)
		end
		return M.PlayerData
	end

	local function getSpeedConfig()
		if not M.SpeedConfig then
			M.SpeedConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.SpeedConfig end)
		end
		return M.SpeedConfig
	end

	local function getPacksConfig()
		if not M.PacksConfig then
			M.PacksConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.PacksConfig end)
		end
		return M.PacksConfig
	end

	local function getCharacterConfig()
		if not M.CharacterConfig then
			M.CharacterConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.CharacterConfig end)
		end
		return M.CharacterConfig
	end

	local function getMutationConfig()
		if not M.MutationConfig then
			M.MutationConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.MutationConfig end)
		end
		return M.MutationConfig
	end

	local function getRagdollModule()
		if not M.RagdollMod then
			M.RagdollMod = safeRequire(function() return ReplicatedStorage.Shared.Modules.Ragdoll end)
		end
		return M.RagdollMod
	end

	local function getCoachConfig()
		if not M.CoachConfig then
			M.CoachConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.CoachConfig end)
		end
		return M.CoachConfig
	end

	local function getCoachUtil()
		if not M.CoachUtil then
			M.CoachUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.CoachUtil end)
		end
		return M.CoachUtil
	end

	local function getAurasConfig()
		if not M.AurasConfig then
			M.AurasConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.AurasConfig end)
		end
		return M.AurasConfig
	end

	local function getRebirthUtil()
		if not M.RebirthUtil then
			M.RebirthUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.RebirthUtil end)
		end
		return M.RebirthUtil
	end

	local function getDailyRewardsUtil()
		if not M.DailyRewardsUtil then
			M.DailyRewardsUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.DailyRewardsUtil end)
		end
		return M.DailyRewardsUtil
	end

	local function getMutateConfig()
		if not M.MutateConfig then
			M.MutateConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.MutateConfig end)
		end
		return M.MutateConfig
	end

	local function getStageConfig()
		if not M.StageConfig then
			M.StageConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.StageConfig end)
		end
		return M.StageConfig
	end

	local function getTreadmillConfig()
		if not M.TreadmillConfig then
			M.TreadmillConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.TreadmillConfig end)
		end
		return M.TreadmillConfig
	end

	local function getBaseUpgradeConfig()
		if not M.BaseUpgradeConfig then
			M.BaseUpgradeConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.BaseUpgradeConfig end)
		end
		return M.BaseUpgradeConfig
	end

	local function getLuckMachineConfig()
		if not M.LuckMachineConfig then
			M.LuckMachineConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.LuckMachineConfig end)
		end
		return M.LuckMachineConfig
	end

	local function getIndexConfig()
		if not M.IndexConfig then
			M.IndexConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.IndexConfig end)
		end
		return M.IndexConfig
	end

	function Helpers.GetTowerConfig()
		if not M.TowerConfig then
			M.TowerConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.TowerConfig end)
		end
		return M.TowerConfig
	end

	function Helpers.GetDungeonUtil()
		if not M.DungeonUtil then
			M.DungeonUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.DungeonUtil end)
		end
		return M.DungeonUtil
	end

	function Helpers.GetTypesModule()
		if not M.Types then
			M.Types = safeRequire(function() return ReplicatedStorage.Shared.Data.Constants.Types end)
		end
		return M.Types
	end

	Helpers.GameCatalog = {
		discoveredRarities = {}, -- [canonicalRarity] = rank
		areaCenters = {},        -- [stageNum] = Vector3 (จาก Part Area จริงในแมพ)
		areaBounds = {},         -- [stageNum] = { center = Vector3, size = Vector3 }
		uiSyncCallbacks = {},
		uiSyncPending = false,
	}

	function Helpers.RegisterCatalogUISync(fn)
		if type(fn) == "function" then
			table.insert(Helpers.GameCatalog.uiSyncCallbacks, fn)
		end
	end

	function Helpers.TriggerCatalogUISync()
		if Helpers.GameCatalog.uiSyncPending or not Core._alive then return end
		Helpers.GameCatalog.uiSyncPending = true
		task.delay(0.25, function()
			Helpers.GameCatalog.uiSyncPending = false
			if not Core._alive then return end
			for _, fn in ipairs(Helpers.GameCatalog.uiSyncCallbacks) do
				pcall(fn)
			end
		end)
	end

	function Helpers.GetPacksRoot()
		local sc = getStageConfig()
		local worldName = (sc and sc.WorldFolderName) or "Game"
		local packsName = (sc and sc.PacksFolderName) or "Packs"
		local game_ = Workspace:FindFirstChild(worldName) or Workspace:FindFirstChild("Game")
		return game_ and (game_:FindFirstChild(packsName) or game_:FindFirstChild("Packs"))
	end

	function Helpers.GetStageFolder(i)
		local packs = Helpers.GetPacksRoot()
		return packs and packs:FindFirstChild("Stage" .. tostring(i))
	end

	function Helpers.IsAreaRockModel(model)
		if not model then return false end
		local pc = getPacksConfig()
		local rockName = (pc and pc.AreaRock and pc.AreaRock.RuntimeName) or "PackAreaRock"
		return model.Name == rockName
	end

	-- คืนรายชื่อด่านจริงทั้งหมดจาก StageConfig.GetRuntimeStageNames() + โฟลเดอร์จริงใน Workspace.Game.Packs (รองรับแมพเพิ่มด่านอัตโนมัติ)
	function Helpers.GetRuntimeStages()
		local sc = getStageConfig()
		local byNum = {}
		local function addStage(num, key)
			if not num or num < 1 then return end
			local stageKey = key or ("Stage" .. tostring(num))
			local cfg = nil
			if sc then
				if type(sc.Get) == "function" then
					local okG, resG = pcall(sc.Get, stageKey)
					if okG and type(resG) == "table" then cfg = resG end
				elseif type(sc.Stages) == "table" then
					cfg = sc.Stages[stageKey]
				end
			end
			if not byNum[num] then
				byNum[num] = {
					num = num,
					key = stageKey,
					text = (cfg and cfg.Text) or ("Stage " .. tostring(num)),
					emoji = (cfg and cfg.Emoji) or "",
					rarity = cfg and cfg.Rarity or nil,
					recommendedSpeed = cfg and tonumber(cfg.RecommendedSpeed) or nil,
				}
			end
			if Core.Flags["Stage" .. tostring(num)] == nil then
				Core.Flags["Stage" .. tostring(num)] = true
			end
		end

		if sc and type(sc.GetRuntimeStageNames) == "function" then
			local okN, names = pcall(sc.GetRuntimeStageNames)
			if okN and type(names) == "table" then
				for _, stName in ipairs(names) do
					local num = tonumber(string.match(tostring(stName), "^Stage(%d+)$")) or tonumber(string.match(tostring(stName), "(%d+)$"))
					if num then addStage(num, tostring(stName)) end
				end
			end
		elseif sc and type(sc.Stages) == "table" then
			for stName, cfg in pairs(sc.Stages) do
				if type(cfg) == "table" and cfg.RuntimeEnabled == true then
					local num = tonumber(string.match(tostring(stName), "^Stage(%d+)$")) or tonumber(string.match(tostring(stName), "(%d+)$"))
					if num then addStage(num, tostring(stName)) end
				end
			end
		end

		-- ผสานกับโฟลเดอร์ด่านจริงใน Workspace.Game.Packs (กรณีแมพเพิ่มด่านสดระหว่างเล่น)
		local packs = Helpers.GetPacksRoot()
		if packs then
			for _, child in ipairs(packs:GetChildren()) do
				local num = tonumber(string.match(child.Name, "^Stage(%d+)$"))
				if num then addStage(num, child.Name) end
			end
		end

		local list = {}
		for _, entry in pairs(byNum) do
			table.insert(list, entry)
		end
		if #list == 0 then
			for i = 1, 13 do
				addStage(i, "Stage" .. i)
				table.insert(list, byNum[i])
			end
		end
		table.sort(list, function(a, b) return a.num < b.num end)
		return list
	end

	function Helpers.GetMaxStage()
		local stages = Helpers.GetRuntimeStages()
		return (#stages > 0 and stages[#stages].num) or 13
	end

	function Helpers.GetStageAreaBounds(stageNum)
		if not stageNum then return nil end
		local folder = Helpers.GetStageFolder(stageNum)
		local sc = getStageConfig()
		local areaName = (sc and sc.AreaPartName) or "Area"
		local area = folder and folder:FindFirstChild(areaName)
		if area and area:IsA("BasePart") then
			local b = { center = area.Position, size = area.Size }
			Helpers.GameCatalog.areaBounds[stageNum] = b
			Helpers.GameCatalog.areaCenters[stageNum] = Vector3.new(area.Position.X, area.Position.Y, area.Position.Z)
			return b
		end
		return Helpers.GameCatalog.areaBounds[stageNum]
	end

	function Helpers.GetStageCenter(stageNum)
		if not stageNum then return nil end
		-- 1. อ่านจาก Part "Area" จริงของด่านก่อนเสมอ (แม่นยำ 100% แม้แมพย้ายหรือเพิ่มด่านใหม่)
		local areaBounds = Helpers.GetStageAreaBounds(stageNum)
		if areaBounds and areaBounds.center then
			return areaBounds.center
		end
		if Helpers.GameCatalog.areaCenters[stageNum] then
			return Helpers.GameCatalog.areaCenters[stageNum]
		end

		-- 2. ค่าเฉลี่ยพิกัดแพ็คจริงใน SpawnedPacks (ข้าม PackAreaRock)
		local folder = Helpers.GetStageFolder(stageNum)
		if folder then
			local sc = getStageConfig()
			local spName = (sc and sc.SpawnedPacksFolderName) or "SpawnedPacks"
			local sp = folder:FindFirstChild(spName)
			if sp then
				local sum, cnt = Vector3.zero, 0
				for _, m in ipairs(sp:GetChildren()) do
					if m:IsA("Model") and not Helpers.IsAreaRockModel(m) then
						local p = Helpers.GetPosition and Helpers.GetPosition(m) or nil
						if p then
							sum = sum + p
							cnt = cnt + 1
						end
					end
				end
				if cnt > 0 then
					local avg = sum / cnt
					return Vector3.new(avg.X, 68, -365)
				end
			end
		end

		-- 3. Fallback ตารางพิกัดเดิม (สำหรับด่านที่ยังไม่ stream เข้ามา)
		if STAGE_CENTERS[stageNum] then
			return STAGE_CENTERS[stageNum]
		end

		-- 4. ตำแหน่ง Enemy ปัจจุบัน (ชั่วคราว ไม่แคชทับ Area จริง)
		if folder then
			local enemy = folder:FindFirstChild("Enemy")
			if enemy and enemy:IsA("Model") then
				local p = Helpers.GetPosition and Helpers.GetPosition(enemy) or nil
				if p then
					return Vector3.new(p.X, 68, -365)
				end
			end
		end

		-- 5. ประมาณการต่อจากด่านสูงสุดที่ทราบพิกัด (สำหรับด่านใหม่ที่ยังไม่ stream)
		local highestKnown, lastCenter = 0, nil
		for k, v in pairs(Helpers.GameCatalog.areaCenters) do
			if type(k) == "number" and k > highestKnown then
				highestKnown, lastCenter = k, v
			end
		end
		for k, v in pairs(STAGE_CENTERS) do
			if type(k) == "number" and k > highestKnown then
				highestKnown, lastCenter = k, v
			end
		end
		if not lastCenter then
			highestKnown, lastCenter = 13, Vector3.new(6875, 68, -364)
		end
		return Vector3.new(lastCenter.X + (stageNum - highestKnown) * 720, lastCenter.Y, lastCenter.Z)
	end

	-- แปลงชื่อ Rarity ให้อยู่ในรูปมาตรฐานเดียวกับเกม (เช่น "Mystery" -> "???", ตรงตัวตาม PacksConfig.RarityRank / Types.Rarity)
	function Helpers.CanonicalRarityKey(raw)
		if raw == nil then return nil end
		local s = tostring(raw):gsub("^%s+", ""):gsub("%s+$", "")
		if s == "" then return nil end
		local ls = string.lower(s)
		if s == "???" or ls == "mystery" then
			return "???"
		end
		local pc = getPacksConfig()
		if pc and type(pc.RarityRank) == "table" then
			if pc.RarityRank[s] ~= nil then return s end
			for k in pairs(pc.RarityRank) do
				if type(k) == "string" and string.lower(k) == ls then
					return k
				end
			end
		end
		local typesMod = Helpers.GetTypesModule()
		if typesMod and type(typesMod.Rarity) == "table" then
			for enumKey, val in pairs(typesMod.Rarity) do
				if type(val) == "string" and (string.lower(val) == ls or string.lower(tostring(enumKey)) == ls) then
					return val
				end
			end
		end
		return s:sub(1, 1):upper() .. s:sub(2):lower()
	end

	-- แปลงชื่อ Rarity เป็นคีย์ Flag ใน Core.Flags (คง "Rarity_Mystery" สำหรับ "???" เพื่อไม่ให้ Config เก่าพัง)
	function Helpers.RarityToFlagKey(raw)
		local canon = Helpers.CanonicalRarityKey(raw)
		if not canon then return nil end
		if canon == "???" then
			return "Rarity_Mystery"
		end
		return "Rarity_" .. canon
	end

	function Helpers.RegisterDiscoveredRarity(raw, suggestedRank)
		local canon = Helpers.CanonicalRarityKey(raw)
		if not canon then return nil end
		local ranks = Helpers.GetAllRarityRanks()
		if ranks[canon] ~= nil then
			local fk = Helpers.RarityToFlagKey(canon)
			if fk and Core.Flags[fk] == nil then
				Core.Flags[fk] = true
			end
			return canon, ranks[canon]
		end
		local maxR = 0
		for _, v in pairs(ranks) do
			if type(v) == "number" and v > maxR then maxR = v end
		end
		local assignedRank = (type(suggestedRank) == "number" and suggestedRank > 0) and suggestedRank or (maxR + 1)
		Helpers.GameCatalog.discoveredRarities[canon] = assignedRank
		local fk = Helpers.RarityToFlagKey(canon)
		if fk and Core.Flags[fk] == nil then
			Core.Flags[fk] = true
		end
		Helpers.TriggerCatalogUISync()
		return canon, assignedRank
	end

	-- ดึงอันดับระดับความหายากทั้งหมดจากเกมจริง 100% (PacksConfig.RarityRank + Types.Rarity + Live Discovered)
	function Helpers.GetAllRarityRanks()
		local ranks = {}
		local hasLive = false
		local maxRank = 0

		local pc = getPacksConfig()
		if pc and type(pc.RarityRank) == "table" then
			for k, v in pairs(pc.RarityRank) do
				if type(k) == "string" and type(v) == "number" then
					ranks[k] = v
					hasLive = true
					if v > maxRank then maxRank = v end
				end
			end
		end

		local typesMod = Helpers.GetTypesModule()
		if typesMod and type(typesMod.Rarity) == "table" then
			local extra = {}
			for _, val in pairs(typesMod.Rarity) do
				if type(val) == "string" and ranks[val] == nil then
					table.insert(extra, val)
				end
			end
			table.sort(extra)
			for _, val in ipairs(extra) do
				maxRank = maxRank + 1
				ranks[val] = maxRank
				hasLive = true
			end
		end

		if not hasLive then
			ranks = {
				Common = 1, Uncommon = 2, Rare = 3, Epic = 4,
				Legendary = 5, Mythical = 6, Cosmic = 7, Divine = 8,
				Omniversal = 9, Eternal = 10, Primordial = 11, Exclusive = 12,
				Godlike = 13, Absolute = 14, ["???"] = 15, Immortal = 16,
			}
			maxRank = 16
		end

		-- ผสานระดับใหม่ที่ตรวจพบสดจากแมพขณะเล่น
		for k, v in pairs(Helpers.GameCatalog.discoveredRarities) do
			if type(k) == "string" and ranks[k] == nil then
				ranks[k] = (type(v) == "number" and v > 0) and v or (maxRank + 1)
				if ranks[k] > maxRank then maxRank = ranks[k] end
			end
		end

		-- Alias สำหรับการค้นหาคำว่า "Mystery" ให้ชี้ไปที่อันดับเดียวกับ "???" ของเกม
		if ranks["???"] and ranks.Mystery == nil then
			ranks.Mystery = ranks["???"]
		end

		return ranks
	end

	-- คืนรายการระดับความหายากเรียงจากระดับ 1 -> สูงสุดตามเกมจริง (ไม่มีระดับปลอม/ซ้ำซ้อน)
	function Helpers.GetOrderedRarities()
		local ranks = Helpers.GetAllRarityRanks()
		local pc = getPacksConfig()
		local emojis = pc and pc.RollNotification and pc.RollNotification.RarityEmojis or nil
		local byFlag = {}
		local list = {}

		for rawName, rNum in pairs(ranks) do
			if type(rawName) == "string" and type(rNum) == "number" and rawName ~= "Mystery" then
				local flagKey = Helpers.RarityToFlagKey(rawName)
				if flagKey and not byFlag[flagKey] then
					byFlag[flagKey] = true
					if Core.Flags[flagKey] == nil then
						Core.Flags[flagKey] = true
					end
					local displayName = (rawName == "???") and "??? / Mystery" or rawName
					local emoji = emojis and emojis[rawName]
					local prefix = (type(emoji) == "string" and emoji ~= "") and (emoji .. " ") or ""
					table.insert(list, {
						key = rawName,
						displayName = displayName,
						value = flagKey,
						label = string.format("%s%s (ระดับ %d)", prefix, displayName, rNum),
						short = (rawName == "???") and "???" or rawName:sub(1, 4),
						rank = rNum,
					})
				end
			end
		end

		table.sort(list, function(a, b)
			if a.rank ~= b.rank then return a.rank < b.rank end
			return tostring(a.key) < tostring(b.key)
		end)
		return list
	end

	function Helpers.GetRankNames()
		local ordered = Helpers.GetOrderedRarities()
		local rankToName = {}
		for _, item in ipairs(ordered) do
			if not rankToName[item.rank] then
				rankToName[item.rank] = (item.key == "???") and "Mystery" or item.key
			end
		end
		return rankToName
	end

	function Helpers.GetRarityDropdownOptions()
		return Helpers.GetOrderedRarities()
	end

	function Helpers.GetSellRarityOptions()
		local ordered = Helpers.GetOrderedRarities()
		local RARITY_NAMES = {}
		local rarityOptions = {}
		for _, item in ipairs(ordered) do
			if item.rank >= 3 then
				local name = (item.key == "???") and "??? / Mystery" or item.key
				local optText = string.format("%s (%d)", name, item.rank)
				RARITY_NAMES[item.rank] = optText
				table.insert(rarityOptions, optText)
			end
		end
		return RARITY_NAMES, rarityOptions
	end

	-- ซิงก์ Flag ด่านและระดับทั้งหมดจากเกมจริงทันทีหลัง Config.Load() (คงค่าเดิมที่ผู้ใช้เคยบันทึกไว้)
	pcall(function()
		Helpers.GetRuntimeStages()
		Helpers.GetOrderedRarities()
	end)

	function Helpers.IsDungeonPlace()
		return game.PlaceId == 135412798316370 or Workspace:FindFirstChild("DungeonRoom") ~= nil or Workspace:FindFirstChild("DungeonFighters") ~= nil
	end

	function Helpers.GetDungeonPad()
		local dp = Workspace:FindFirstChild("dungeon portal")
		if dp then
			local pad = dp:FindFirstChild("DungeonPad")
			if pad then
				return pad:FindFirstChild("Ring") or pad
			end
		end
		return nil
	end

	function Helpers.IsDungeonPortalOpen()
		local attr = ReplicatedStorage:GetAttribute("DungeonPortalOpenUntil")
		if type(attr) == "number" then
			local now = workspace:GetServerTimeNow()
			if attr > now then return true end
		end
		local du = Helpers.GetDungeonUtil()
		if du and type(du.GetPortal) == "function" then
			local ok, isOpen = pcall(du.GetPortal, workspace:GetServerTimeNow())
			if ok and isOpen == true then
				return true
			end
		end
		return false
	end

	function Helpers.GetPlayerSpeedStat()
		local pd = getPlayerData()
		if pd and type(pd.Get) == "function" then
			local ok, spd = pcall(pd.Get, "Speed")
			if ok and tonumber(spd) then return tonumber(spd) end
		end
		local ls = LocalPlayer:FindFirstChild("leaderstats")
		if ls then
			local sp = ls:FindFirstChild("Speed")
			if sp and type(sp.Value) == "number" then return sp.Value end
		end
		local attrSpd = LocalPlayer:GetAttribute("Speed")
		if type(attrSpd) == "number" then return attrSpd end
		return 0
	end

	function Helpers.CanEnterDungeon()
		if not Helpers.IsDungeonPortalOpen() then
			return false, "ประตูดันเจี้ยนยังไม่เปิด"
		end
		local speed = Helpers.GetPlayerSpeedStat()
		if speed < 50000000000 then
			return false, string.format("ต้องการความเร็ว 50B+ (ปัจจุบัน %.2e)", speed)
		end
		return true, "พร้อมลงดันเจี้ยน"
	end

	function Helpers.GetBestDungeonTeam()
		local pd = getPlayerData()
		local inv = pd and type(pd.Get) == "function" and pd.Get("Inventory")
		local packs = (type(inv) == "table") and inv.Packs or nil
		if not packs then return {} end

		local pc = getPacksConfig()
		local cc = safeRequire(function() return ReplicatedStorage.Shared.Configs.CharacterConfig end)
		local tu = safeRequire(function() return ReplicatedStorage.Shared.Utilities.TowerUtil end)
		local tc = Helpers.GetTowerConfig()
		local rarityRank = (Helpers.GetAllRarityRanks and Helpers.GetAllRarityRanks()) or (pc and pc.RarityRank) or {}
		local minRank = rarityRank.Cosmic or 7

		local candidates = {}
		local allChars = {}

		for _, bucketName in ipairs({"Backpack", "Placed"}) do
			local bucket = packs[bucketName]
			if type(bucket) == "table" then
				for id, v in pairs(bucket) do
					if type(v) == "table" and (pc == nil or (pc.IsCharacter and pc.IsCharacter(v))) and v.OpeningCommittedAt == nil and type(v.CharacterName) == "string" then
						local cdata = cc and cc.Get and cc.Get(v.CharacterName)
						local stage = cdata and tostring(cdata.Stage) or ""
						if cdata and stage ~= "Dungeons" and stage ~= "DungeonPack" then
							local unitId = v.Id or (type(id) == "string" and id)
							if unitId then
								local dmg = 0
								if tu and type(tu.GetStats) == "function" then
									local sOk, sRes = pcall(tu.GetStats, v)
									if sOk and type(sRes) == "table" and type(sRes.Damage) == "number" then
										dmg = sRes.Damage
									end
								end
								if dmg == 0 then
									dmg = tonumber(cdata.NumericalOdd) or 1
								end

								local itemRecord = {
									Id = unitId,
									Damage = dmg,
									Rarity = v.Rarity or cdata.Rarity,
									Name = v.CharacterName
								}

								local rRank = rarityRank[itemRecord.Rarity]
								if rRank and rRank >= minRank then
									table.insert(candidates, itemRecord)
								end
								table.insert(allChars, itemRecord)
							end
						end
					end
				end
			end
		end

		local pool = (#candidates > 0) and candidates or allChars
		table.sort(pool, function(a, b)
			return a.Damage > b.Damage
		end)

		local teamSize = (tc and tc.TeamSize) or 4
		local team = {}
		local chosenMap = {}
		for i = 1, math.min(teamSize, #pool) do
			local uid = pool[i].Id
			if uid and not chosenMap[uid] then
				chosenMap[uid] = true
				table.insert(team, uid)
			end
		end
		return team
	end

	function Helpers.FindVisibleGuiButton(root, keyword)
		if not root then return nil end
		local kw = string.lower(keyword)
		local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local function isVis(obj)
			local p = obj
			while p and p ~= pgui and not p:IsA("ScreenGui") do
				if p:IsA("GuiObject") and not p.Visible then return false end
				p = p.Parent
			end
			return not (p and p:IsA("ScreenGui") and not p.Enabled)
		end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("GuiButton") and isVis(d) then
				local nm = string.lower(d.Name)
				local tx = d:IsA("TextButton") and string.lower(d.Text or "") or ""
				if nm:find(kw, 1, true) or tx:find(kw, 1, true) then return d end
				for _, c in ipairs(d:GetDescendants()) do
					if c:IsA("TextLabel") and string.lower(c.Text or ""):find(kw, 1, true) then
						return d
					end
				end
			end
		end
		return nil
	end

	function Helpers.EquipBestDungeonTeam()
		local bestTeam = Helpers.GetBestDungeonTeam()
		if #bestTeam == 0 then
			logAction("ดันเจี้ยน", "ไม่พบตัวละครที่สามารถลงดันเจี้ยนได้ (ต้องการ Cosmic+)", false)
			return false, "NO_UNITS"
		end

		local okSet = false
		local setMsg = ""
		if Net and Net.Paths and Net.Paths.DungeonPartySetTeam then
			local ok, res = Net.Invoke(Net.Paths.DungeonPartySetTeam, bestTeam)
			if ok and (res == nil or (type(res) == "table" and res.Success)) then
				okSet = true
				logAction("ดันเจี้ยน", string.format("ใส่ตัวดีสุดลงดันเจี้ยนสำเร็จ (%d ตัว)", #bestTeam), true)
			else
				setMsg = (type(res) == "table" and (res.Message or res.Reason)) or "SetTeam ไม่สำเร็จ"
			end
		end

		-- กดปุ่ม EquipBest และรัวปุ่ม Continue บนหน้า Your Team จนกว่าหน้าต่างจะปิด (แก้บั๊ก UGPhone)
		pcall(function()
			local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if not pgui then return end
			for _, uiName in ipairs({ "DungeonUi", "TowerUi" }) do
				local ui = pgui:FindFirstChild(uiName)
				if ui then
					local eb = Helpers.FindVisibleGuiButton(ui, "equip")
					if eb then
						Helpers.ForceClickGuiButton(eb)
						task.wait(0.25)
					end
					for _ = 1, 15 do
						local cont = Helpers.FindVisibleGuiButton(ui, "continue")
						if not cont then break end
						Helpers.ForceClickGuiButton(cont)
						task.wait(0.18)
					end
				end
			end
		end)

		if okSet then
			return true, "EQUIPPED"
		else
			if setMsg ~= "" then
				logAction("ดันเจี้ยน", "จัดทีมลงดันเจี้ยน: " .. tostring(setMsg), false)
			end
			return false, setMsg
		end
	end

	Helpers._enteringDungeon = false
	function Helpers.ForceClickGuiButton(btn)
		if not (btn and btn:IsA("GuiButton")) then return false end
		local nm0 = string.lower(btn.Name)
		if nm0 == "stopview" or nm0 == "close" or nm0 == "exit" or nm0 == "leave" then return false end
		if getconnections then
			for _, sn in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "TouchTap" }) do
				pcall(function()
					for _, cn in ipairs(getconnections(btn[sn])) do
						if type(cn.Function) == "function" then pcall(cn.Function) end
						pcall(function() cn:Fire() end)
					end
				end)
			end
		end
		if firesignal then
			pcall(firesignal, btn.Activated)
			pcall(firesignal, btn.MouseButton1Click)
			pcall(firesignal, btn.MouseButton1Down)
			pcall(firesignal, btn.MouseButton1Up)
			pcall(function() firesignal(btn.TouchTap) end)
		end
		pcall(function()
			if btn.AbsoluteSize.X > 0 then
				local vim = game:GetService("VirtualInputManager")
				local sg = btn:FindFirstAncestorWhichIsA("ScreenGui")
				local inset = (sg and sg.IgnoreGuiInset) and Vector2.zero or game:GetService("GuiService"):GetGuiInset()
				local cx = btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2 + inset.X
				local cy = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2 + inset.Y
				vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
				task.wait(0.03)
				vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
			end
		end)
		return true
	end

	function Helpers.ResolveDungeonKey(picked)
		local foundDouble, foundAny
		local function scan(t, depth)
			if type(t) ~= "table" or depth > 3 or foundDouble then return end
			for k, v in pairs(t) do
				if type(k) == "string" then
					local l = string.lower(k)
					if l:find("double d") then foundDouble = k return end
					if not foundAny and (l == "dungeon" or l == "dugeon" or l:find("dungeon") or l:find("dugeon")) then foundAny = k end
				end
				if type(v) == "table" then scan(v, depth + 1) end
				if foundDouble then return end
			end
		end
		for _, g in ipairs({ "GetTowerConfig", "GetDungeonUtil" }) do
			local fn = Helpers[g]
			if type(fn) == "function" then
				local ok, t = pcall(fn)
				if ok then scan(t, 0) end
			end
		end
		return foundDouble or picked or foundAny or "Double Dugeons"
	end

	function Helpers.IsOnDungeonTreadmill()
		if LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then return true end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Sit and hum.SeatPart then return true end
		local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pg then
			local st = pg:FindFirstChild("StopTrainingGui")
			if st and st:IsA("ScreenGui") and st.Enabled then
				for _, d in ipairs(st:GetDescendants()) do
					if d:IsA("GuiObject") and d.Visible then return true end
				end
			end
			local tj = pg:FindFirstChild("TreadmillJuice")
			if tj and tj:IsA("ScreenGui") and tj.Enabled then
				for _, d in ipairs(tj:GetDescendants()) do
					if d:IsA("GuiObject") and d.Visible then return true end
				end
			end
		end
		return false
	end

	function Helpers.SummonDungeonTreadmill(hrp)
		if not hrp or Helpers.IsOnDungeonTreadmill() then return end
		local look = hrp.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.01 then flatLook = flatLook.Unit else flatLook = Vector3.new(0, 0, -1) end
		local pos = { Look = flatLook, Position = hrp.Position }

		-- 1) คลิกปุ่มเรียกลู่วิ่งใน DungeonHud / TowerUi / TowerHud ก่อน (เพื่อให้ Client Controller ส่งพิกัดพื้นจริงและเสกโมเดล)
		local clickedUi = false
		pcall(function()
			local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if not pg then return end
			for _, rn in ipairs({ "DungeonHud", "TowerUi", "TowerHud" }) do
				local root = pg:FindFirstChild(rn)
				if root then
					for _, d in ipairs(root:GetDescendants()) do
						if d:IsA("GuiButton") and d.Visible then
							local nm = string.lower(d.Name)
							local tx = d:IsA("TextButton") and string.lower(d.Text or "") or ""
							if (nm:find("treadmil") or tx:find("treadmil")) and not (nm:find("exit") or nm:find("stop") or nm:find("close")) then
								Helpers.ForceClickGuiButton(d)
								clickedUi = true
								break
							end
						end
					end
				end
				if clickedUi then break end
			end
		end)

		if clickedUi then
			task.wait(0.25)
			if Helpers.IsOnDungeonTreadmill() then return end
		end

		-- 2) ContextActionService (เผื่อแมพผูกปุ่มลัดเรียกลู่วิ่ง)
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			for an, info in pairs(game:GetService("ContextActionService"):GetAllBoundActionInfo()) do
				local l = string.lower(tostring(an))
				if l:find("treadmill") or l:find("treadmil") then
					for _, it in ipairs(info.inputTypes or {}) do
						if typeof(it) == "EnumItem" and it.EnumType == Enum.KeyCode then
							vim:SendKeyEvent(true, it, false, game)
							task.wait(0.05)
							vim:SendKeyEvent(false, it, false, game)
						end
					end
				end
			end
		end)

		-- 3) ยิง Remote ReplicatedStorage.Remotes.Towers.Treadmill โดยตรงเพียง 1 ครั้งต่อรอบ (ห้ามยิงซ้ำซ้อนเพื่อไม่ให้ Toggle ปิด)
		pcall(function()
			local rem = ReplicatedStorage:FindFirstChild("Remotes")
			local tw = rem and rem:FindFirstChild("Towers")
			local tm = tw and (tw:FindFirstChild("Treadmill") or tw:FindFirstChild("Treadmil"))
			if tm and tm:IsA("RemoteEvent") then
				tm:FireServer(pos)
			elseif Net and Net.Paths and Net.Paths.TowersTreadmill then
				Net.Fire(Net.Paths.TowersTreadmill, 2.0, pos)
			end
		end)
	end

	function Helpers.EnterDungeon()
		local can, reason = Helpers.CanEnterDungeon()
		if not can then
			return false, reason
		end

		if Helpers._enteringDungeon then
			return false, "กำลังดำเนินการเข้าดันเจี้ยนอยู่แล้ว"
		end
		if os.clock() - (Helpers._lastDungeonAttempt or -100) < 8 then
			return false, "คูลดาวน์ 8 วินาที"
		end
		Helpers._lastDungeonAttempt = os.clock()
		Helpers._enteringDungeon = true

		local success, retMsg = pcall(function()
			-- 1. ออกจากลู่วิ่งทันที และรอให้ Attribute เคลียร์
			if LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then
				if Helpers.LeaveTreadmill then
					pcall(Helpers.LeaveTreadmill)
				else
					if Net and Net.Paths and Net.Paths.ExitRequest then
						Net.Fire(Net.Paths.ExitRequest, 0.5)
					end
				end
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hrp then
					hrp.Anchored = false
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
				if hum then hum.Jump = true end

				local tWait = os.clock()
				while os.clock() - tWait < 2.0 and LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil do
					task.wait(0.1)
				end
			end

			-- 2. วาร์ปตัวละครไปยังแท่นดันเจี้ยน (DungeonPad / Ring)
			local ring = Helpers.GetDungeonPad()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if ring and hrp and ring:IsA("BasePart") then
				for attempt = 1, 3 do
					pcall(function()
						hrp.Anchored = false
						hrp.AssemblyLinearVelocity = Vector3.zero
						hrp.CFrame = ring.CFrame + Vector3.new(0, 3, 0)
					end)
					task.wait(0.3)
					if (hrp.Position - ring.Position).Magnitude <= 15 then
						break
					end
				end
			end

			task.wait(0.4)

			-- 3. สั่งแสดง UI Dungeons ผ่าน Controller และกด Play บน Template
			pcall(function()
				local ctrl = safeRequire(function() return ReplicatedStorage.UI.Controller end)
				if ctrl and type(ctrl.Show) == "function" then
					ctrl.Show("Dungeons")
				end
			end)

			local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local dui = pgui and pgui:FindFirstChild("DungeonUi")
			local holder = dui and dui:FindFirstChild("Holder")
			local waitCard = os.clock()
			while os.clock() - waitCard < 2 do
				dui = pgui and pgui:FindFirstChild("DungeonUi")
				holder = dui and dui:FindFirstChild("Holder")
				local ts0 = holder and holder:FindFirstChild("TowerSelection")
				local sf0 = ts0 and ts0:FindFirstChild("ScrollingFrame")
				local ready = false
				if ts0 and ts0:IsA("GuiObject") and ts0.Visible and sf0 then
					for _, c in ipairs(sf0:GetChildren()) do
						if c:IsA("GuiObject") and c.Visible and c.Name ~= "Template" then ready = true break end
					end
				end
				if ready then break end
				task.wait(0.1)
			end
			local ts = holder and holder:FindFirstChild("TowerSelection")
			local sf = ts and ts:FindFirstChild("ScrollingFrame")
			-- เลือกการ์ด "Double Dugeons" (วนทุก Template ตามชื่อ TowerName) ถ้าไม่เจอใช้ Template แรก
			local tmpl
			Helpers._dgPickedName = nil
			if sf then
				for _, c in ipairs(sf:GetChildren()) do
					local tn = c:FindFirstChild("TowerName", true)
					local txt = string.lower((tn and tn:IsA("TextLabel") and tn.Text) or "")
					local attrName = c:GetAttribute("TowerName") or c:GetAttribute("Name") or c:GetAttribute("Tower")
					if txt == "" then txt = string.lower(tostring(attrName or c.Name)) end
					if txt:find("double") and (not c:IsA("GuiObject") or c.Visible) then
						tmpl = c
						Helpers._dgPickedName = (tn and tn:IsA("TextLabel") and tn.Text ~= "" and tn.Text) or (type(attrName) == "string" and attrName) or nil
						break
					end
				end
				tmpl = tmpl or sf:FindFirstChild("Template")
			end
			local playBtn = tmpl and tmpl:FindFirstChild("Play")
			local function clickBtn(b)
				if not (b and b:IsA("GuiButton")) then return end
				if Helpers.ClickButton then pcall(Helpers.ClickButton, b) end
				Helpers.ForceClickGuiButton(b)
				if firesignal then
					pcall(firesignal, b.Activated)
					pcall(firesignal, b.MouseButton1Click)
					pcall(firesignal, b.MouseButton1Down)
					pcall(firesignal, b.MouseButton1Up)
				end
				if getconnections then
					pcall(function()
						for _, cn in ipairs(getconnections(b.Activated)) do pcall(cn.Fire, cn) end
						for _, cn in ipairs(getconnections(b.MouseButton1Click)) do pcall(cn.Fire, cn) end
					end)
				end
			end
			local function isSafeBtn(b)
				local nm = string.lower(b.Name)
				if nm == "stopview" or nm == "close" or nm == "back" or nm == "cancel" then return false end
				if b:IsA("TextButton") and string.lower(b.Text or ""):match("^%s*x%s*$") then return false end
				for _, c in ipairs(b:GetChildren()) do
					if c:IsA("TextLabel") and string.lower(c.Text or ""):match("^%s*x%s*$") then return false end
				end
				if nm == "play" or nm == "view" or nm == "select" then return true end
				if b:IsA("TextButton") then
					local bt = string.lower(b.Text or "")
					if bt:match("^%s*view%s*$") or bt:match("^%s*play%s*$") or bt:match("^%s*select%s*$") then return true end
				end
				for _, c in ipairs(b:GetChildren()) do
					if c:IsA("TextLabel") then
						local t = string.lower(c.Text or "")
						if t:match("^%s*view%s*$") or t:match("^%s*play%s*$") then return true end
					end
				end
				return false
			end
			local function teamOpen()
				local pg2 = LocalPlayer:FindFirstChildOfClass("PlayerGui")
				local d2 = pg2 and pg2:FindFirstChild("DungeonUi")
				local h2 = d2 and d2:FindFirstChild("Holder")
				for _, nm in ipairs({ "PartyFrame", "TeamFrame" }) do
					local f = h2 and h2:FindFirstChild(nm)
					if f and f:IsA("GuiObject") and f.Visible then return true end
				end
				local tu = pg2 and pg2:FindFirstChild("TowerUi")
				local tsel = tu and tu:FindFirstChild("TeamSelection")
				if tsel and tsel:IsA("GuiObject") and tsel.Visible then return true end
				return false
			end
			local function selectCard()
				if not tmpl or teamOpen() then return end
				for _, b in ipairs(tmpl:GetDescendants()) do
					if b:IsA("GuiButton") and isSafeBtn(b) then clickBtn(b) end
				end
			end
			selectCard()
			task.wait(0.3)

			-- 3.1 หาและกดปุ่ม "View" (ค้นหาตามชื่อ/ข้อความ) เพื่อไปหน้า Party/Team ต่อ
			local function findViewButton(root)
				if not root then return nil end
				for _, d in ipairs(root:GetDescendants()) do
					if d:IsA("GuiButton") and d:IsDescendantOf(pgui) then
						local vis = true
						local p = d
						while p and p ~= pgui do
							if p:IsA("GuiObject") and not p.Visible then vis = false break end
							p = p.Parent
						end
						if vis then
							local nm = string.lower(d.Name)
							local tx = d:IsA("TextButton") and string.lower(d.Text or "") or ""
							if nm == "stopview" or nm == "close" then
								-- ห้ามกด
							elseif nm == "view" or nm == "play" or tx:match("^%s*view%s*$") then return d end
							for _, c in ipairs(d:GetChildren()) do
								if c:IsA("TextLabel") and string.lower(c.Text or ""):match("^%s*view%s*$") then return d end
							end
						end
					end
				end
				return nil
			end
			local viewT0 = os.clock()
			while os.clock() - viewT0 < 4 and not teamOpen() do
				dui = pgui and pgui:FindFirstChild("DungeonUi")
				local vb = findViewButton(dui)
				if vb then
					Helpers.ForceClickGuiButton(vb)
					logAction("ดันเจี้ยน", "กดปุ่ม View แล้ว", true)
					task.wait(0.5)
					break
				end
				-- บางครั้ง Play ยังไม่ถูกกด ลองกดซ้ำจนกว่าจะเจอ View
				selectCard()
				task.wait(0.3)
			end
			holder = dui and dui:FindFirstChild("Holder")

			-- ดึงชื่อดันเจี้ยนจริงจากการ์ดที่เลือก (Attribute/Text) ถ้าไม่ได้ใช้ fallback
			local dungeonTargetName = Helpers.ResolveDungeonKey(Helpers._dgPickedName)

			-- 4. เปิดปาร์ตี้ด้วยชื่อจริง (fallback สะกดอื่น)
			if Net and Net.Paths and Net.Paths.DungeonPartyOpen and not teamOpen() then
				local ok, res = Net.Invoke(Net.Paths.DungeonPartyOpen, dungeonTargetName)
				if not ok or (type(res) == "table" and res.Success == false) then
					Net.Invoke(Net.Paths.DungeonPartyOpen, (dungeonTargetName == "Double Dungeons") and "Double Dugeons" or "Double Dungeons")
				end
			end

			task.wait(0.4)

			-- 5. สวมใส่ตัวที่ดีที่สุดลงดันเจี้ยน (ทั้ง SetTeam Remote และปุ่มบน TeamFrame)
			Helpers.EquipBestDungeonTeam()

			task.wait(0.4)

			-- 6. กดปุ่ม Start ใน PartyFrame (UI Fallback)
			local partyFrame = holder and (holder:FindFirstChild("PartyFrame") or dui:FindFirstChild("PartyFrame", true))
			if partyFrame and partyFrame.Visible then
				local startBtn = partyFrame:FindFirstChild("Start")
				if not (startBtn and startBtn:IsA("GuiButton")) then
					startBtn = nil
					for _, b in ipairs(partyFrame:GetDescendants()) do
						if b:IsA("GuiButton") and b.Visible then
							local bt = b:IsA("TextButton") and string.lower(b.Text or "") or ""
							local bn = string.lower(b.Name)
							if bn == "start" or bn == "startsolo" or bt:find("start") then startBtn = b break end
							for _, c in ipairs(b:GetChildren()) do
								if c:IsA("TextLabel") and string.lower(c.Text or ""):find("start") then startBtn = b break end
							end
							if startBtn then break end
						end
					end
				end
				if startBtn and startBtn:IsA("GuiButton") then
					Helpers.ForceClickGuiButton(startBtn)
					task.wait(0.3)
				end
			end

			-- 7. สั่งเริ่มเทเลพอร์ตเข้าดันเจี้ยนผ่าน Remote
			if Net and Net.Paths and Net.Paths.DungeonPartyStart then
				queueScriptOnTeleport(TELEPORT_LOADER)
				local ok, res = Net.Invoke(Net.Paths.DungeonPartyStart)
				if ok and (res == nil or (type(res) == "table" and res.Success)) then
					logAction("ดันเจี้ยน", "เริ่มเทเลพอร์ตเข้าสู่ Dungeon สำเร็จ", true)
					return "กำลังเทเลพอร์ต"
				else
					local msg = (type(res) == "table" and (res.Message or res.Reason)) or "ไม่สามารถเริ่มดันเจี้ยนได้"
					logAction("ดันเจี้ยน", "เริ่มดันเจี้ยนไม่สำเร็จ: " .. tostring(msg), false)
					error(tostring(msg))
				end
			end

			return "ส่งคำขอเข้าดันเจี้ยนแล้ว"
		end)

		Helpers._enteringDungeon = false
		Core:ReleaseBusy("dungeon")
		if not success then
			return false, tostring(retMsg)
		end
		return true, tostring(retMsg)
	end

	function Helpers.IsUnitUltReady(slot)
		if not slot then return false end

		-- 1. ต้องไม่ล้ม/ไม่ตาย (Down)
		local down = slot:FindFirstChild("Down")
		if down and down:IsA("GuiObject") and down.Visible then
			return false
		end

		local ultBtn = slot:FindFirstChild("Ult")
		if not ultBtn or not ultBtn:IsA("GuiButton") or not ultBtn.Visible then
			return false
		end

		-- 2. ตรวจจับ Key Label (ตัวเกมตั้ง Visible = true เมื่อชาร์จเต็ม 100% เท่านั้น)
		local key = slot:FindFirstChild("Key")
		if key and key:IsA("GuiObject") and key.Visible then
			return true
		end

		-- 3. ตรวจสอบ UIStroke ขอบสีทอง (Ready = Color3.fromRGB(255, 205, 60), Not Ready = ดำ)
		local stroke = ultBtn:FindFirstChild("UIStroke")
		if stroke and stroke:IsA("UIStroke") then
			local col = stroke.Color
			if col.R > 0.7 and col.G > 0.6 and col.B < 0.4 then
				return true
			end
		end

		-- 4. ตรวจสอบระดับการชาร์จใน BadgeClip (Scale >= 0.98)
		local badge = ultBtn:FindFirstChild("Badge")
		local clip = badge and badge:FindFirstChild("BadgeClip", true)
		if clip and clip:IsA("GuiObject") and clip.Size.Y.Scale >= 0.98 then
			return true
		end

		-- 5. ตรวจสอบประกายสายฟ้า UltBolts
		local bolts = slot:FindFirstChild("UltBolts") or ultBtn:FindFirstChild("UltBolts")
		if bolts and #bolts:GetChildren() > 0 then
			return true
		end

		return false
	end

	Helpers._lastUltTrigger = {}
	function Helpers.TriggerDungeonUltimates()
		if not Helpers.IsDungeonPlace() then return end

		local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local hud = pgui and pgui:FindFirstChild("DungeonHud")
		local unitBar = hud and hud:FindFirstChild("Bottom") and hud.Bottom:FindFirstChild("UnitBar")
		if not unitBar then return end

		local now = os.clock()
		for i = 1, 4 do
			local slot = unitBar:FindFirstChild("Slot" .. i)
			-- ตรวจสอบอย่างเข้มงวด: สกิลต้องพร้อมใช้ 100% จริงๆ เท่านั้นจึงจะยิงคำสั่ง
			if Helpers.IsUnitUltReady(slot) then
				if (now - (Helpers._lastUltTrigger[i] or 0)) >= 1.0 then
					Helpers._lastUltTrigger[i] = now
					local ultBtn = slot:FindFirstChild("Ult")
					local triggered = false

					-- 1. กดผ่าน firesignal บนปุ่ม Ult
					if firesignal and ultBtn then
						pcall(firesignal, ultBtn.Activated)
						pcall(firesignal, ultBtn.MouseButton1Click)
						triggered = true
					end

					-- 2. กดผ่าน VirtualInputManager ตาม KeyCode 1-4
					if not triggered and VirtualInputManager then
						local keyMap = { [1] = Enum.KeyCode.One, [2] = Enum.KeyCode.Two, [3] = Enum.KeyCode.Three, [4] = Enum.KeyCode.Four }
						local key = keyMap[i]
						if key then
							pcall(function()
								VirtualInputManager:SendKeyEvent(true, key, false, game)
								task.wait(0.04)
								VirtualInputManager:SendKeyEvent(false, key, false, game)
							end)
							triggered = true
						end
					end

					-- 3. สั่งผ่านโมดูลเกม DungeonUlt.Press(i)
					local duOk, duMod = pcall(function()
						return require(LocalPlayer.PlayerScripts.Client.Controllers.DungeonHud.DungeonUlt)
					end)
					if duOk and duMod and type(duMod.Press) == "function" then
						pcall(duMod.Press, i)
					end
				end
			end
		end
	end

	function Helpers.GetCurrentDungeonFloor()
		-- อ่านชั้น/เวฟปัจจุบันจาก DungeonHud.TopBar.Banner.wAVE ("Wave X • Y LEFT")
		local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local function parseFloor(txt)
			txt = tostring(txt or "")
			txt = txt:gsub("<[^>]->", ""):gsub(",", "")
			return txt:match("[Ww][Aa][Vv][Ee]%s*:?%s*(%d+)") or txt:match("[Ff][Ll][Oo][Oo][Rr]%s*:?%s*(%d+)")
				or txt:match("[Ss][Tt][Aa][Gg][Ee]%s*:?%s*(%d+)") or txt:match("[Ll][Ee][Vv][Ee][Ll]%s*:?%s*(%d+)")
				or txt:match("ชั้น%s*:?%s*(%d+)") or txt:match("เวฟ%s*:?%s*(%d+)")
		end
		local hud = pgui and pgui:FindFirstChild("DungeonHud")
		local topBar = hud and hud:FindFirstChild("TopBar")
		local banner = topBar and topBar:FindFirstChild("Banner")
		if banner then
			local waveLbl = banner:FindFirstChild("wAVE") or banner:FindFirstChild("Wave")
			if waveLbl and waveLbl:IsA("TextLabel") then
				local wTxt = tostring(waveLbl.Text or "")
				if string.lower(wTxt):find("lobby", 1, true) then
					return 0
				end
				local wn = tonumber(parseFloor(wTxt) or wTxt:match("(%d+)"))
				if wn and wn > 0 then return wn end
			end
			local floorLbl = banner:FindFirstChild("Floor")
			if floorLbl and floorLbl:IsA("TextLabel") then
				local fn = tonumber(parseFloor(floorLbl.Text))
				if fn and fn > 0 then return fn end
			end
		end
		local best = 0
		for _, rootName in ipairs({ "DungeonHud", "TowerUi", "DungeonUi", "TowerHud" }) do
			local root = pgui and pgui:FindFirstChild(rootName)
			if root then
				for _, d in ipairs(root:GetDescendants()) do
					if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible then
						local n = tonumber(parseFloor(d.Text))
						if n and n > best then best = n end
					end
				end
				if best > 0 then break end
			end
		end
		if best > 0 then return best end
		local wv = LocalPlayer:GetAttribute("Wave") or LocalPlayer:GetAttribute("Floor") or workspace:GetAttribute("Wave") or workspace:GetAttribute("Floor")
		return tonumber(wv) or 0
	end

	function Helpers.CheckDungeonResultAndExit()
		if not Helpers.IsDungeonPlace() then return end
		local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local hud = pgui and pgui:FindFirstChild("DungeonHud")
		if not hud then return end

		local defeat = hud:FindFirstChild("Defeat")
		local isDefeat = defeat and defeat:IsA("GuiObject") and defeat.Visible

		if isDefeat then
			logAction("ดันเจี้ยน", "ดันเจี้ยนจบลงแล้ว -> ออกจากห้องกลับสู่ Hub", true)
			if Net and Net.Paths and Net.Paths.TowersExit then
				Net.Fire(Net.Paths.TowersExit, 1.0)
			end
		end
	end

	function Helpers.AutoDungeonStep()
		-- กรณีอยู่ในแมพดันเจี้ยนแล้ว (PlaceId 135412798316370)
		if Helpers.IsDungeonPlace() then
			-- 1. สั่งข้ามคัตซีนเปิดตัว และกด Start ทันทีหากติดหน้า Lobby หลัง Restart
			if Core.Flags.AutoDungeonSkipIntro ~= false and Net and Net.Paths and Net.Paths.TowersIntroDone then
				Net.Fire(Net.Paths.TowersIntroDone, 1.5)
			end
			pcall(function()
				local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
				local hud = pg and pg:FindFirstChild("DungeonHud")
				local lobby = hud and hud:FindFirstChild("Lobby")
				local banner = hud and hud:FindFirstChild("TopBar") and hud.TopBar:FindFirstChild("Banner")
				local wLbl = banner and (banner:FindFirstChild("wAVE") or banner:FindFirstChild("Wave"))
				local inLobby = (lobby and lobby:IsA("GuiObject") and lobby.Visible)
					or (wLbl and wLbl:IsA("TextLabel") and string.lower(wLbl.Text or ""):find("lobby", 1, true) ~= nil)
				if inLobby and Net and Net.Paths and Net.Paths.TowersStartNow then
					Net.Fire(Net.Paths.TowersStartNow, 1.0)
				end
			end)

			-- 2. สั่งเปิดโหมด Auto Attack ต่อสู้ต่อเนื่อง
			if Core.Flags.AutoDungeonAttack ~= false and Net and Net.Paths and Net.Paths.TowersSetAuto then
				Net.Fire(Net.Paths.TowersSetAuto, 2.0, true)
			end

			-- 3. ตรวจจับและใช้ท่าไม้ตายออโต้ (Auto Ultimate)
			if Core.Flags.AutoDungeonUlt ~= false then
				Helpers.TriggerDungeonUltimates()
			end

			-- 3.5 ขึ้นลู่วิ่งในแมพดันเจี้ยนทันที (แบบ Dynamic ไม่สแปม Toggle ซ้อน)
			if not Helpers.IsOnDungeonTreadmill() and os.clock() - (Helpers._lastDgTreadmill or -100) > 4.0 then
				Helpers._lastDgTreadmill = os.clock()
				pcall(function()
					local plotsFolder = Workspace:FindFirstChild("Plots")
					local function findDungeonTreadmill()
						local best, bestScore
						for _, d in ipairs(Workspace:GetDescendants()) do
							local n = string.lower(d.Name)
							if n:find("treadmil") and not (plotsFolder and d:IsDescendantOf(plotsFolder)) then
								local part = d:IsA("BasePart") and d or nil
								if d:IsA("Model") or d:IsA("Folder") then
									part = d:FindFirstChild("Seat", true) or d:FindFirstChild("Primary", true) or d:FindFirstChild("TreadmilBox", true) or d:FindFirstChildWhichIsA("BasePart", true)
								end
								if part and part:IsA("BasePart") then
									local sc = (part.Name == "Seat" and 4) or (part.Name == "Primary" and 3) or (part.Name == "TreadmilBox" and 2) or 1
									if not bestScore or sc > bestScore then best, bestScore = part, sc end
								end
							end
						end
						return best
					end

					local best = findDungeonTreadmill()
					local hrp0 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

					-- หากยังไม่มีโมเดลลู่วิ่งใน Workspace ให้สั่งเสกออกมาเพียงครั้งเดียวแล้วรอให้โมเดลเกิด
					if not best and hrp0 then
						Helpers.SummonDungeonTreadmill(hrp0)
						local tWait = os.clock()
						while os.clock() - tWait < 1.5 and not Helpers.IsOnDungeonTreadmill() do
							best = findDungeonTreadmill()
							if best then break end
							task.wait(0.15)
						end
					end

					-- หากยังไม่ติดสถานะขึ้นลู่วิ่ง และพบโมเดลลู่วิ่ง (หรือเพิ่งเสกออกมา)
					if not Helpers.IsOnDungeonTreadmill() then
						local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
						if best and hrp then
							hrp.Anchored = false
							hrp.CFrame = best.CFrame + Vector3.new(0, 2.5, 0)
							local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
							if hum then hum:MoveTo(best.Position) end
							task.wait(0.25)

							local root = best.Parent or best
							local parts = { best }
							if root and root ~= Workspace then
								for _, p in ipairs(root:GetDescendants()) do
									if p:IsA("BasePart") and #parts < 12 then table.insert(parts, p) end
								end
							end
							if firetouchinterest then
								for _, p in ipairs(parts) do
									pcall(firetouchinterest, hrp, p, 0)
									pcall(firetouchinterest, hrp, p, 1)
								end
							end
							if fireproximityprompt then
								for _, pp in ipairs(root:GetDescendants()) do
									if pp:IsA("ProximityPrompt") then pcall(fireproximityprompt, pp) end
								end
							end
							if hum and best:IsA("Seat") then pcall(function() best:Sit(hum) end) end
							logAction("ดันเจี้ยน", "ขึ้นลู่วิ่งในดันเจี้ยน: " .. best:GetFullName(), true)
						elseif hrp and not best then
							logAction("ดันเจี้ยน", "ส่งคำสั่งเรียกลู่วิ่งในดันเจี้ยน (Towers.Treadmill)", true)
						end
					end
				end)
			end

			-- 4. ตรวจจับจบเกม (Victory / Defeat) เพื่อกดออก
			if Core.Flags.AutoDungeonExit ~= false then
				Helpers.CheckDungeonResultAndExit()
			end

			-- 5. ถึงชั้น/เวฟที่ระบุ → กดปุ่ม TopbarPlus "DungeonRestart" (RESTART DUGEON) 2 ครั้ง + ยิง Towers.Restart (ไม่ออกดันเจี้ยน)
			local targetFloor = tonumber(Core.Flags.DungeonTargetFloor)
			if targetFloor and targetFloor >= 1 then
				local curFloor = Helpers.GetCurrentDungeonFloor()
				if curFloor > (Helpers._dungeonMaxFloor or 0) then Helpers._dungeonMaxFloor = curFloor end
				if curFloor > 0 and curFloor >= targetFloor and not Helpers._forceExiting then
					Helpers._forceExiting = true
					logAction("ดันเจี้ยน", "ถึงเวฟ " .. curFloor .. " (เป้าหมาย " .. targetFloor .. ") → กด RESTART DUGEON 2 ครั้ง", true)
					task.spawn(function()
						local function findRestartClickRegion()
							local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
							if not pg then return nil end
							-- 1) ค้นหาจาก TopbarPlus: PlayerGui...DungeonRestart.Widget.ClickRegion
							local dr = pg:FindFirstChild("DungeonRestart", true)
							if dr then
								local cr = dr:FindFirstChild("ClickRegion", true) or dr:FindFirstChildWhichIsA("GuiButton", true)
								if cr then return cr end
							end
							-- 2) Fallback: ค้นหา IconLabel ที่มีข้อความ "RESTART DUGEON" แล้วหา ClickRegion ในคอนเทนเนอร์เดียวกัน
							for _, d in ipairs(pg:GetDescendants()) do
								if d:IsA("TextLabel") and not d:FindFirstAncestor("KUYKUY_ScreenGui") then
									local tx = string.lower(d.Text or "")
									if tx:find("restart", 1, true) then
										local p = d.Parent
										for _ = 1, 4 do
											if not p or p == pg then break end
											local cr = p:FindFirstChild("ClickRegion", true) or p:FindFirstChildWhichIsA("GuiButton", true)
											if cr and not string.lower(cr.Name):find("exit", 1, true) and not string.lower(cr.Name):find("leave", 1, true) then
												return cr
											end
											p = p.Parent
										end
									end
								end
							end
							return nil
						end

						local function fireButtonOnce(btn)
							if not (btn and btn:IsA("GuiButton")) then return false end
							local fired = false
							if firesignal then
								pcall(firesignal, btn.Activated)
								pcall(firesignal, btn.MouseButton1Click)
								fired = true
							end
							if getconnections then
								for _, sn in ipairs({ "Activated", "MouseButton1Click" }) do
									pcall(function()
										for _, cn in ipairs(getconnections(btn[sn])) do
											if type(cn.Function) == "function" then
												pcall(cn.Function)
												fired = true
											elseif cn.Fire then
												pcall(cn.Fire, cn)
												fired = true
											end
										end
									end)
								end
							end
							if not fired and VirtualInputManager and btn.AbsoluteSize.X > 0 then
								pcall(function()
									local sg = btn:FindFirstAncestorWhichIsA("ScreenGui")
									local inset = (sg and sg.IgnoreGuiInset) and Vector2.zero or game:GetService("GuiService"):GetGuiInset()
									local cx = btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2 + inset.X
									local cy = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2 + inset.Y
									VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
									task.wait(0.04)
									VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
								end)
							end
							return true
						end

						local t0 = os.clock()
						while Helpers.IsDungeonPlace() and Helpers.GetCurrentDungeonFloor() >= targetFloor and os.clock() - t0 < 12 do
							local cr = findRestartClickRegion()
							if cr then
								-- กดครั้งที่ 1 (เปลี่ยนปุ่มเป็น "SURE?")
								fireButtonOnce(cr)
								task.wait(0.25)
								-- กดครั้งที่ 2 (ยืนยัน "RESTART DUGEON" ภายใน 3 วินาที)
								fireButtonOnce(cr)
								task.wait(0.35)
							end
							-- Fallback ยิง Remote ReplicatedStorage.Remotes.Towers.Restart โดยตรงหากเวฟยังไม่รีเซ็ต
							if Helpers.GetCurrentDungeonFloor() >= targetFloor then
								pcall(function()
									local rem = ReplicatedStorage:FindFirstChild("Remotes")
									local tw = rem and rem:FindFirstChild("Towers")
									local rst = tw and tw:FindFirstChild("Restart")
									if rst and rst:IsA("RemoteEvent") then
										rst:FireServer()
									elseif Net and Net.Paths and Net.Paths.TowersRestart then
										Net.Fire(Net.Paths.TowersRestart, 0)
									end
								end)
							end
							task.wait(0.8)
						end
						-- หากหลังรีสตาร์ทติดหน้า Lobby ให้สั่ง StartNow ทันที
						if Net and Net.Paths and Net.Paths.TowersStartNow then
							pcall(Net.Fire, Net.Paths.TowersStartNow, 0)
						end
						Helpers._dungeonMaxFloor = 0
						Helpers._lastDgTreadmill = 0
						Helpers._forceExiting = false
					end)
				end
			end
			return
		end

		-- กรณีอยู่ในแมพหลัก (Hub)
		if not Core.Flags.AutoEnterDungeon then return end
		if Helpers._enteringDungeon then return end
		if Helpers.IsCarrying and Helpers.IsCarrying() then return end
		if os.clock() - (Helpers._lastDungeonAttempt or -100) < 8 then return end
		local can, reason = Helpers.CanEnterDungeon()
		if not can then
			return
		end

		if Helpers.StopMove then Helpers.StopMove() end
		Core:AcquireBusy("dungeon", true)

		logAction("ดันเจี้ยน", "ประตูดันเจี้ยนเปิดอยู่ และ Speed ถึง 50B -> กำลังเข้าดันเจี้ยน...", true)
		Helpers.EnterDungeon()
	end

	function Helpers.GetSafeZoneBounds()
		local game_ = Workspace:FindFirstChild("Game")
		local sz = game_ and game_:FindFirstChild("SafeZone")
		if sz then
			local pos, size
			if sz:IsA("BasePart") then
				pos, size = sz.Position, sz.Size
			elseif sz:IsA("Model") then
				local cf, s = sz:GetBoundingBox()
				pos, size = cf.Position, s
			elseif sz:IsA("Folder") then
				local minX, maxX, minY, maxY, minZ, maxZ
				for _, desc in ipairs(sz:GetDescendants()) do
					if desc:IsA("BasePart") then
						local p, s = desc.Position, desc.Size * 0.5
						local x1, x2 = p.X - s.X, p.X + s.X
						local y1, y2 = p.Y - s.Y, p.Y + s.Y
						local z1, z2 = p.Z - s.Z, p.Z + s.Z
						minX = minX and math.min(minX, x1) or x1
						maxX = maxX and math.max(maxX, x2) or x2
						minY = minY and math.min(minY, y1) or y1
						maxY = maxY and math.max(maxY, y2) or y2
						minZ = minZ and math.min(minZ, z1) or z1
						maxZ = maxZ and math.max(maxZ, z2) or z2
					end
				end
				if minX and maxX then
					pos = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
					size = Vector3.new(maxX - minX, maxY - minY, maxZ - minZ)
				end
			end
			if pos and size then
				return {
					center = pos,
					minX = pos.X - size.X * 0.5,
					maxX = pos.X + size.X * 0.5,
				}
			end
		end
		return {
			center = Vector3.new(1075.8, 68, -364.5),
			minX = 948.2,
			maxX = 1203.3,
		}
	end

	function Helpers.IsInSafeZone(char)
		local c = char or LocalPlayer.Character
		local szu = getSafeZoneUtil()
		if szu and szu.ContainsCharacter and c then
			local ok, inside = pcall(szu.ContainsCharacter, c)
			if ok and inside ~= nil then return inside end
		end
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end
		local bounds = Helpers.GetSafeZoneBounds()
		return hrp.Position.X <= (bounds.maxX - 6) and hrp.Position.X >= (bounds.minX + 6)
	end

	-- Plot ของผู้เล่น: ใช้ PlotUtil.GetPlotByUserId ของเกม (ไม่ Hardcode เลข Plot)
	function Helpers.GetPlot(force)
		if not force and Helpers.plotCache and Helpers.plotCache.Parent then
			return Helpers.plotCache
		end
		Helpers.plotCache = nil
		local util = getPlotUtil()
		if not util then return nil end
		local ok, entry = pcall(util.GetPlotByUserId, LocalPlayer.UserId)
		if not ok or type(entry) ~= "table" or entry.Name == nil then return nil end
		local plots = Workspace:FindFirstChild("Plots")
		local slot = plots and plots:FindFirstChild(tostring(entry.Name))
		Helpers.plotCache = slot
		return slot
	end

	function Helpers.GetPlotChild(relPath)
		local node = Helpers.GetPlot()
		for _, seg in ipairs(string.split(relPath, ".")) do
			if not node then return nil end
			node = node:FindFirstChild(seg)
		end
		return node
	end

	function Helpers.GetPlotSpawn()
		local util = getPlotUtil()
		local plot = Helpers.GetPlot()
		if util and plot then
			local ok, part = pcall(util.GetSpawn, plot.Name)
			if ok and part then return part end
		end
		return Helpers.GetPlotChild("PlotModel")
	end

	function Helpers.GetPlotSpawnPos()
		local spawnInst = Helpers.GetPlotSpawn()
		local pos = spawnInst and Helpers.GetPosition(spawnInst)
		if pos then
			Helpers.plotSpawnPosCache = pos
			return pos
		end
		if Helpers.plotSpawnPosCache then
			return Helpers.plotSpawnPosCache
		end
		local game_ = Workspace:FindFirstChild("Game")
		local sz = game_ and game_:FindFirstChild("SafeZone")
		return sz and Helpers.GetPosition(sz) or nil
	end

	function Helpers.StreamAround(pos, timeout)
		if not pos or not Workspace.StreamingEnabled then return end
		pcall(function()
			LocalPlayer:RequestStreamAroundAsync(pos, timeout or 4)
		end)
	end

	function Helpers.ResolvePath(path)
		local node = game
		for i, seg in ipairs(string.split(path, ".")) do
			if not (i == 1 and (seg == "Workspace" or seg == "game")) then
				node = node:FindFirstChild(seg)
				if not node then return nil end
			end
		end
		return node
	end

	function Helpers.GetPosition(inst)
		if typeof(inst) == "string" then inst = Helpers.ResolvePath(inst) end
		if not inst then return nil end
		if inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
			inst = inst.Parent
			if not inst then return nil end
		end
		if inst:IsA("Attachment") then return inst.WorldPosition end
		if inst:IsA("BasePart") then return inst.Position end
		if inst:IsA("Model") then return inst:GetPivot().Position end
		return nil
	end

	function Helpers.GetRoot()
		local char = LocalPlayer.Character
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	function Helpers.GetHumanoid()
		local char = LocalPlayer.Character
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	function Helpers.IsAlive()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		return hum ~= nil and hum.Health > 0 and Helpers.GetRoot() ~= nil
	end

	Helpers._moveToken = 0
	function Helpers.StopMove()
		Helpers._moveToken = (Helpers._moveToken or 0) + 1
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = Helpers.GetRoot()
		pcall(function()
			if hum and hrp then hum:MoveTo(hrp.Position) end
			if hum then hum:Move(Vector3.zero) end
			if hrp then
				local v = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
			end
		end)
	end

	local function waitUntil(cond, timeout)
		local deadline = os.clock() + timeout
		while os.clock() < deadline and Core._alive do
			if cond() then return true end
			task.wait(0.1)
		end
		return cond()
	end

	function Helpers.GetMutateMachinePad()
		if Helpers.mutatePadCache and Helpers.mutatePadCache.Parent then
			return Helpers.mutatePadCache
		end
		Helpers.mutatePadCache = nil

		-- อ่านตำแหน่งแท่นแบบไดนามิกจาก MutateConfig.Machine.Pad (รองรับการอัปเดตแมพอัตโนมัติ)
		local mc = getMutateConfig()
		local padPath = mc and mc.Machine and mc.Machine.Pad
		local pad = nil
		if type(padPath) == "table" and #padPath > 0 then
			local cur = Workspace
			for _, seg in ipairs(padPath) do
				cur = cur and cur:FindFirstChild(seg)
			end
			pad = cur
		end

		if not pad then
			pad = Workspace:FindFirstChild("MutationMachine", true)
				or Workspace:FindFirstChild("MergeMachine", true)
				or (Workspace:FindFirstChild("Machine2", true) and Workspace:FindFirstChild("Machine2", true):FindFirstChild("MutationMachine", true))
		end

		if pad then
			if pad:IsA("BasePart") then
				Helpers.mutatePadCache = pad
				return pad
			elseif pad:IsA("Model") then
				local p = pad.PrimaryPart or pad:FindFirstChildWhichIsA("BasePart")
				if p then
					Helpers.mutatePadCache = p
					return p
				end
			end
		end
		return nil
	end

	function Helpers.IsAtMutateMachine()
		local pad = Helpers.GetMutateMachinePad()
		local hrp = Helpers.GetRoot()
		if not (pad and hrp) then return false end
		local mc = getMutateConfig()
		local radius = (mc and mc.Machine and tonumber(mc.Machine.Radius)) or 10
		local height = (mc and mc.Machine and tonumber(mc.Machine.Height)) or 12
		local d = hrp.Position - pad.Position
		return Vector3.new(d.X, 0, d.Z).Magnitude <= radius and d.Y >= -2 and d.Y <= height
	end

	function Helpers.VisitMutateMachine(actionFn, ignoreBusy)
		if Helpers.IsDungeonPlace and Helpers.IsDungeonPlace() then
			return false, "IN_DUNGEON"
		end
		if not Helpers.IsAlive() or Helpers.IsCarrying() then
			return false, "BUSY_OR_DEAD"
		end
		if not ignoreBusy and (Core.Flags.AutoSteal or Core:IsBusyByOther("mutate")) then
			return false, "BUSY_OR_STEALING"
		end
		local pad = Helpers.GetMutateMachinePad()
		if not pad then
			return false, "PAD_NOT_FOUND"
		end
		local hrp = Helpers.GetRoot()
		if not hrp then return false, "NO_HRP" end

		local mc = getMutateConfig()
		local maxH = (mc and mc.Machine and tonumber(mc.Machine.Height)) or 12
		local checkSec = (mc and mc.Machine and tonumber(mc.Machine.CheckSeconds)) or 0.2
		local padY = pad.Position.Y + math.clamp((pad.Size.Y * 0.5) + 3.0, 1.5, math.max(maxH - 1.5, 2.0))

		local acquiredHere = false
		if not ignoreBusy then
			if not Core:AcquireBusy("mutate") then
				return false, "BUSY_OR_DEAD"
			end
			acquiredHere = true
		end
		local wasAtMachine = Helpers.IsAtMutateMachine()
		local padPos = Vector3.new(pad.Position.X, padY, pad.Position.Z)

		local wasTraining = LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil
		if not wasAtMachine then
			if wasTraining and Helpers.LeaveTreadmill then
				pcall(Helpers.LeaveTreadmill)
				task.wait(0.15)
			end
			Helpers.MoveTo(padPos, function()
				return not Core._alive or Helpers.IsCarrying() or Helpers.IsAtMutateMachine()
			end, { precise = true, arriveDist = 4, evadeEnemies = false })
			task.wait(math.max(checkSec, 0.2) + 0.15)
		end

		local ok, res, extra = pcall(actionFn)

		if not wasAtMachine and wasTraining and Core.Flags.AutoEnter and not Core.Flags.AutoSteal and Helpers.EnterTreadmill and Helpers.IsAlive() and not Helpers.IsCarrying() then
			task.spawn(function()
				task.wait(0.3)
				if not Core.Busy and not Core.Flags.AutoSteal then
					pcall(Helpers.EnterTreadmill)
				end
			end)
		end

		if acquiredHere then
			Core:ReleaseBusy("mutate")
		end

		if not ok then
			return false, tostring(res)
		end
		return true, res, extra
	end

	Helpers.SUFFIX_MAP = {
		k = 1e3, m = 1e6, b = 1e9, t = 1e12,
		qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24,
		oc = 1e27, no = 1e30, dc = 1e33,
	}
	function Helpers.ParseSuffixNumber(str)
		if type(str) == "number" then return str end
		if type(str) ~= "string" then return nil end
		local clean = str:gsub(",", ""):gsub("%s+", "")
		local num = tonumber(clean)
		if num then return num end
		local nPart, sPart = clean:match("^([%d%.]+)%s*([%a]+)$")
		if nPart and sPart then
			local n = tonumber(nPart)
			local mul = Helpers.SUFFIX_MAP[sPart:lower()]
			if n and mul then
				return n * mul
			end
		end
		return nil
	end

	-- คำนวณความเร็วเคลื่อนที่ปลอดภัยจาก SpeedConfig.ToWalkSpeed ของตัวละคร (ไม่เกินเพดานเกม)
	function Helpers.GetMoveSpeed()
		local sc = getSpeedConfig()
		local maxCap = (sc and sc.MaximumWalkSpeed) or 340
		local spdStat = nil
		local function takeHigher(val)
			local n = tonumber(val) or Helpers.ParseSuffixNumber(val)
			if n and (spdStat == nil or n > spdStat) then
				spdStat = n
			end
		end
		local pd = getPlayerData()
		if pd and pd.Get then
			local ok, val = pcall(pd.Get, "Speed")
			if ok and val ~= nil then takeHigher(val) end
		end
		local ls = LocalPlayer:FindFirstChild("leaderstats")
		local sv = ls and ls:FindFirstChild("Speed")
		if sv then takeHigher(sv.Value) end
		local attrSpd = LocalPlayer:GetAttribute("Speed")
		if attrSpd ~= nil then takeHigher(attrSpd) end
		local isSlowMode = false
		if pd and pd.Get and sc and sc.SlowModeDataName then
			local okSm, smVal = pcall(pd.Get, sc.SlowModeDataName)
			if okSm and smVal == true then isSlowMode = true end
		end
		if sc and sc.ToWalkSpeed and spdStat then
			local ok, ws = pcall(sc.ToWalkSpeed, spdStat, isSlowMode)
			if ok and type(ws) == "number" then
				return math.clamp(ws * 0.98, sc.MinimumWalkSpeed or 16, maxCap)
			end
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		return math.max((hum and hum.WalkSpeed) or 16, 16)
	end

	-- คำนวณความเร็วเป้าหมายตามจริงรวมตัวคูณแพ็คหนัก (Heavy) ให้ตรงกับ SpeedController ของเกม 100%
	function Helpers.GetTargetWalkSpeed()
		local baseWs = Helpers.GetMoveSpeed()
		local carryEntry = Helpers.GetCarryingEntry and Helpers.GetCarryingEntry() or nil
		if type(carryEntry) == "table" and carryEntry.Heavy == true then
			if M.AdminAbuseConfig == nil then
				M.AdminAbuseConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.AdminAbuseConfig end) or false
			end
			local aac = M.AdminAbuseConfig
			if type(aac) == "table" and type(aac.GetCarrySpeedMultiplier) == "function" then
				local okM, mult = pcall(aac.GetCarrySpeedMultiplier, carryEntry.Weight)
				if okM and type(mult) == "number" and mult < 1 then
					local minCarry = (aac.Rocket and aac.Rocket.CarrySpeed and aac.Rocket.CarrySpeed.MinimumWalkSpeed) or 16
					return math.max(baseWs * mult, minCarry)
				end
			end
		end
		return baseWs
	end

	-- ลบอนิเมชชั่นล้ม/โดนตี (Ragdoll) ทันทีเมื่อถูกบอสตี เพื่อไม่ให้เสียจังหวะวิ่งกลับฐาน
	function Helpers.RecoverFromHit(char)
		if not Core.Flags.AntiRagdollMode then return end
		char = char or LocalPlayer.Character
		if not char or not char.Parent then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not (hum and hrp) or hum.Health <= 0 then return end

		local ragMod = getRagdollModule()
		local wasRag = char:GetAttribute("Ragdolled") == true
		local badState = hum.PlatformStand or hum.Sit
		if not badState then
			local st = hum:GetState()
			badState = (st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown)
		end

		if wasRag and ragMod and type(ragMod.UnRagdoll) == "function" then
			pcall(ragMod.UnRagdoll, char)
		end

		if wasRag or badState then
			for _, desc in ipairs(char:GetDescendants()) do
				if desc.Name == "RagdollSocket" or desc.Name == "RagdollAttachment" or desc.Name == "ColliderPart" then
					pcall(function() desc:Destroy() end)
				elseif desc:IsA("Motor6D") or desc:IsA("AnimationConstraint") then
					if not desc.Enabled then
						pcall(function() desc.Enabled = true end)
					end
				end
			end
			pcall(function()
				hrp.Anchored = false
				hrp.Massless = false
				hrp.CanCollide = true
				hrp.AssemblyAngularVelocity = Vector3.zero
				local lv = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(0, math.clamp(lv.Y, -35, 10), 0)
				if not (Helpers.IsCarrying and Helpers.IsCarrying()) then
					local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
					local forward = look.Magnitude > 0.05 and look.Unit or Vector3.new(-1, 0, 0)
					local p = hrp.Position
					hrp.CFrame = CFrame.lookAt(p, p + forward)
				end
			end)
		end

		pcall(function()
			hum.RequiresNeck = true
			hum.AutoRotate = true
			hum.PlatformStand = false
			hum.Sit = false
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			local st = hum:GetState()
			if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end
			if hum.WalkSpeed <= 0 then
				hum.WalkSpeed = 16
			end
			if char:GetAttribute("Ragdolled") ~= nil then
				char:SetAttribute("Ragdolled", nil)
			end
			if char:GetAttribute("RagdollUntil") ~= nil then
				char:SetAttribute("RagdollUntil", nil)
			end
			ContextActionService:UnbindAction("RagdollNoLook")
		end)
	end

	do
		local ragMod = getRagdollModule()
		if ragMod and type(ragMod.Ragdoll) == "function" then
			local origRagdoll = ragMod.Ragdoll
			ragMod.Ragdoll = function(targetChar, impulse, duration, ...)
				if Core._alive and Core.Flags.AntiRagdollMode and targetChar == LocalPlayer.Character then
					task.defer(Helpers.RecoverFromHit, targetChar)
					return
				end
				return origRagdoll(targetChar, impulse, duration, ...)
			end
			Core:OnCleanup(function()
				ragMod.Ragdoll = origRagdoll
			end)
		end

		local charConns = {}
		local function clearCharConns()
			for _, c in ipairs(charConns) do
				pcall(function() c:Disconnect() end)
			end
			charConns = {}
		end
		Core:OnCleanup(clearCharConns)

		local function bindAntiRagdollChar(char)
			clearCharConns()
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
			if not hum or not Core._alive then return end

			if Core.Flags.AntiRagdollMode then
				Helpers.RecoverFromHit(char)
			end

			table.insert(charConns, char:GetAttributeChangedSignal("Ragdolled"):Connect(function()
				if Core.Flags.AntiRagdollMode and char:GetAttribute("Ragdolled") == true then
					Helpers.RecoverFromHit(char)
				end
			end))
			table.insert(charConns, char.DescendantAdded:Connect(function(desc)
				if not Core.Flags.AntiRagdollMode then return end
				if desc.Name == "RagdollSocket" or desc.Name == "RagdollAttachment" or desc.Name == "ColliderPart" then
					pcall(function() desc:Destroy() end)
					task.defer(Helpers.RecoverFromHit, char)
				elseif (desc:IsA("Motor6D") or desc:IsA("AnimationConstraint")) and not desc.Enabled then
					pcall(function() desc.Enabled = true end)
				end
			end))
			table.insert(charConns, hum:GetPropertyChangedSignal("PlatformStand"):Connect(function()
				if Core.Flags.AntiRagdollMode and hum.PlatformStand then
					Helpers.RecoverFromHit(char)
				end
			end))
			table.insert(charConns, hum.StateChanged:Connect(function(_, newState)
				if not Core.Flags.AntiRagdollMode then return end
				if newState == Enum.HumanoidStateType.Physics or newState == Enum.HumanoidStateType.Ragdoll or newState == Enum.HumanoidStateType.FallingDown then
					Helpers.RecoverFromHit(char)
				end
			end))
		end

		if LocalPlayer.Character then
			task.spawn(bindAntiRagdollChar, LocalPlayer.Character)
		end
		Core:Connect(LocalPlayer.CharacterAdded, bindAntiRagdollChar)
		local cachedSafeWs, nextWsSample = 16, 0
		Core:Connect(RunService.Heartbeat, function()
			local char = LocalPlayer.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end

			-- ป้องกัน SpeedController ของเกมรีเซ็ต WalkSpeed ลงเป็น 16 ระหว่าง MoveTo / หยุด / ออกตัว
			if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil
				and char:GetAttribute("TrapImmobilized") ~= true
				and char:GetAttribute("Ragdolled") ~= true then
				if Core.Flags.AutoSteal or Core.Busy or hum.MoveDirection.Magnitude > 0.05 then
					local now = os.clock()
					if now >= nextWsSample then
						nextWsSample = now + 0.2
						cachedSafeWs = Helpers.GetTargetWalkSpeed and Helpers.GetTargetWalkSpeed() or 16
					end
					if math.abs(hum.WalkSpeed - cachedSafeWs) > 1 or hum.WalkSpeed <= 0 then
						hum.WalkSpeed = cachedSafeWs
					end
				end
			end

			if not Core.Flags.AntiRagdollMode then return end
			if char:GetAttribute("Ragdolled") == true or hum.PlatformStand or hum.Sit then
				Helpers.RecoverFromHit(char)
			else
				local st = hum:GetState()
				if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
					Helpers.RecoverFromHit(char)
				end
			end
		end)
	end

	-- ทำความสะอาด KuySideLane เก่าที่อาจหลงเหลือจากการรันเวอร์ชันก่อนหน้า
	Core:OnCleanup(function()
		local oldFolder = Workspace:FindFirstChild("KuySideLane")
		if oldFolder then
			pcall(function() oldFolder:Destroy() end)
		end
	end)

	local function findNearestEnemyPos(pos, maxDist, scopeFolder)
		local root = scopeFolder or (Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Packs"))
		if not root then return nil, math.huge end
		local bestPos, bestDist = nil, maxDist or math.huge
		local stages = scopeFolder and { scopeFolder } or root:GetChildren()
		for _, st in ipairs(stages) do
			for _, ch in ipairs(st:GetChildren()) do
				if ch.Name == "Enemy" and ch:IsA("Model") then
					local ep = Helpers.GetPosition(ch)
					if ep then
						local d = (ep - pos).Magnitude
						if d < bestDist then
							bestPos, bestDist = ep, d
						end
					end
				end
			end
		end
		return bestPos, bestDist
	end

	-- เคลื่อนที่ต่อเนื่องหลาย Waypoint ด้วย Humanoid:MoveTo (โทเคนกันคำสั่งซ้อน + กัน Overshoot ที่ WalkSpeed สูง + Side Hysteresis หลบบอส)
	function Helpers.MoveAlongPath(waypoints, shouldAbort, opts)
		if type(waypoints) ~= "table" or #waypoints == 0 then return false end
		Helpers._moveToken = (Helpers._moveToken or 0) + 1
		local myToken = Helpers._moveToken
		local precise = not (opts and opts.precise == false)
		local strictArrive = opts and opts.strictArrive == true
		local evadeEnemies = opts and opts.evadeEnemies == true
		local safeBounds = Helpers.GetSafeZoneBounds()
		local defaultArrive = (opts and opts.arriveDist) or (precise and 3 or 8)
		local maxArriveCap = (opts and opts.maxArriveDist) or math.max(defaultArrive, 5.5)

		local function getWp(idx)
			local w = waypoints[idx]
			if typeof(w) == "Vector3" then
				return w, defaultArrive
			elseif type(w) == "table" and typeof(w.pos) == "Vector3" then
				return w.pos, w.arriveDist or defaultArrive
			end
			return nil, defaultArrive
		end

		local function stopMotion(h, r, settle)
			local function zeroOnce()
				pcall(function()
					if h and r then
						h:MoveTo(r.Position)
					end
					if h then
						h:Move(Vector3.zero)
					end
					if r then
						local v = r.AssemblyLinearVelocity
						r.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
						r.AssemblyAngularVelocity = Vector3.zero
					end
				end)
			end
			zeroOnce()
			if settle and r then
				local v = r.AssemblyLinearVelocity
				if Vector3.new(v.X, 0, v.Z).Magnitude > 10 then
					RunService.Heartbeat:Wait()
					zeroOnce()
				end
			end
		end

		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = Helpers.GetRoot()
		if not (char and hum and hrp) then return false end

		local totalDist = 0
		local prevP = hrp.Position
		for k = 1, #waypoints do
			local wp = getWp(k)
			if wp then
				totalDist = totalDist + Vector3.new(wp.X - prevP.X, 0, wp.Z - prevP.Z).Magnitude
				prevP = wp
			end
		end

		local wpIdx = 1
		local prevFlatDelta = nil
		local dodgeSide = nil
		local dodgeSideUntil = 0
		local lastCheck = os.clock()
		local lastPos = hrp.Position
		local lastIssue = 0
		local borderStallStart = nil
		local borderMaxX = nil
		local timeout = os.clock() + math.max(90, totalDist / 12 + 30)

		while Core._alive and Helpers.IsAlive() and Helpers._moveToken == myToken and os.clock() < timeout do
			local now = os.clock()
			if shouldAbort and shouldAbort() then
				if precise and not (opts and opts.noStopOnAbort) then
					stopMotion(hum, hrp, false)
				end
				return true
			end

			char = LocalPlayer.Character
			hum = char and char:FindFirstChildOfClass("Humanoid")
			hrp = Helpers.GetRoot()
			if not (char and hum and hrp) then return false end

			local targetPos, wpArrive = getWp(wpIdx)
			if not targetPos then return true end
			local isFinal = (wpIdx == #waypoints)
			local cur = hrp.Position
			local ws = math.max(hum.WalkSpeed or 16, 16)
			local flatDelta = Vector3.new(targetPos.X - cur.X, 0, targetPos.Z - cur.Z)
			local flatDist = flatDelta.Magnitude
			local yTol = (isFinal and precise) and 12 or 24

			if not isFinal then
				-- เปลี่ยน Waypoint ถัดไปแบบลื่นไหลต่อเนื่อง ไม่เบรก/ไม่ล้างความเร็วกลางทาง
				local cornerDist = math.clamp(math.max(wpArrive, ws / 22), 7, 16)
				if flatDist <= cornerDist and math.abs(targetPos.Y - cur.Y) <= yTol then
					wpIdx = wpIdx + 1
					prevFlatDelta = nil
					lastIssue = 0
					continue
				end
			else
				local effArrive
				if precise then
					effArrive = strictArrive and wpArrive or math.clamp(math.max(wpArrive, ws / 48), wpArrive, maxArriveCap)
				else
					effArrive = math.max(wpArrive, math.min(ws / 26, 14))
				end
				local crossed = precise and prevFlatDelta ~= nil and prevFlatDelta:Dot(flatDelta) <= 0 and flatDist <= (effArrive + 3.0)
				if (flatDist <= effArrive or crossed) and math.abs(targetPos.Y - cur.Y) <= yTol then
					if precise then
						stopMotion(hum, hrp, true)
					end
					return true
				end
			end
			prevFlatDelta = flatDelta

			local moveTarget = targetPos
			if Core.Flags.AntiRagdollMode and (char:GetAttribute("Ragdolled") == true or hum.PlatformStand) then
				Helpers.RecoverFromHit(char)
			end
			local locked = char:GetAttribute("TrapImmobilized") == true or (not Core.Flags.AntiRagdollMode and char:GetAttribute("Ragdolled") == true)
			if not locked then
				local targetWs = Helpers.GetTargetWalkSpeed and Helpers.GetTargetWalkSpeed() or Helpers.GetMoveSpeed()
				if math.abs(hum.WalkSpeed - targetWs) > 1 or hum.WalkSpeed <= 0 then
					hum.WalkSpeed = targetWs
				end
				ws = math.max(hum.WalkSpeed or 16, 16)
				if hum.Sit then hum.Sit = false end
				if hum.PlatformStand then hum.PlatformStand = false end

				-- หลีกเลี่ยงบอสบนทางหลักด้วย Side Hysteresis (ล็อกฝั่งหลบอย่างน้อย 0.85s กันส่ายซิกแซก และไม่กระโดดพร่ำเพรื่อ)
				if evadeEnemies and safeBounds and cur.X > safeBounds.maxX and cur.Y > 64 and flatDist > 35 then
					local ePos, eDist = findNearestEnemyPos(cur, 60)
					if ePos and eDist <= 60 then
						if not dodgeSide or now >= dodgeSideUntil then
							dodgeSide = (ePos.Z >= cur.Z) and -1 or 1
							dodgeSideUntil = now + 0.85
						end
						local dodgeZ = math.clamp(safeBounds.center.Z + dodgeSide * 34, safeBounds.center.Z - 42, safeBounds.center.Z + 42)
						local stepX
						if targetPos.X < cur.X then
							stepX = math.max(targetPos.X, cur.X - math.max(90, ws * 0.55))
						else
							stepX = math.min(targetPos.X, cur.X + math.max(90, ws * 0.55))
						end
						moveTarget = Vector3.new(stepX, targetPos.Y, dodgeZ)
					elseif now >= dodgeSideUntil then
						dodgeSide = nil
					end
				end
			end

			local issueInterval = (isFinal and flatDist <= 28) and 0.05 or 0.1
			local moveFlat = Vector3.new(moveTarget.X - cur.X, 0, moveTarget.Z - cur.Z)
			local moveFlatDist = moveFlat.Magnitude
			local flatDir = moveFlatDist > 0.05 and moveFlat.Unit or Vector3.zero
			local stepLen = math.max(100, ws * 0.7)
			local stepTarget = (moveFlatDist > stepLen and flatDir ~= Vector3.zero)
				and Vector3.new(cur.X + flatDir.X * stepLen, moveTarget.Y, cur.Z + flatDir.Z * stepLen)
				or moveTarget
			if now - lastIssue >= issueInterval or (not locked and flatDist > 6 and hum.MoveDirection.Magnitude < 0.05) then
				lastIssue = now
				pcall(function() hum:MoveTo(stepTarget) end)
			end

			-- หากติดสิ่งกีดขวาง (แทบไม่ขยับเกิน 0.5 วินาที) ให้เร่งเดินต่อ/กระโดดข้าม
			if now - lastCheck >= 0.5 then
				local moved = (cur - lastPos).Magnitude
				lastCheck = now
				lastPos = cur
				if not locked and moved < 2 and flatDist > 6 then
					pcall(function()
						if flatDir ~= Vector3.zero then hum:Move(flatDir, false) end
						hum.Jump = true
					end)
				end
			end

			-- หากกำลังพยายามเดินออกจาก SafeZone เข้าสู่ด่าน แต่ติดสิ่งกีดขวาง/ประตูปิดหน้าด่าน (ค่า X ไม่คืบหน้าเกิน 2.5 วินาที) ให้ยกเลิกทันที
			local finalTarget = getWp(#waypoints) or targetPos
			if safeBounds and finalTarget.X > (safeBounds.maxX + 10) and cur.X >= (safeBounds.maxX - 18) and cur.X <= (safeBounds.maxX + 4) then
				if not borderStallStart then
					borderStallStart = now
					borderMaxX = cur.X
				elseif cur.X > (borderMaxX + 1.5) then
					borderMaxX = cur.X
					borderStallStart = now
				elseif now - borderStallStart >= 2.5 then
					stopMotion(hum, hrp, true)
					return false
				end
			else
				borderStallStart = nil
				borderMaxX = nil
			end

			RunService.Heartbeat:Wait()
		end
		if precise then
			stopMotion(hum, hrp, false)
		end
		return false
	end

	function Helpers.MoveTo(targetPos, shouldAbort, opts)
		if typeof(targetPos) ~= "Vector3" then return false end
		return Helpers.MoveAlongPath({ targetPos }, shouldAbort, opts)
	end

	-- ปลดล็อคฟิสิกส์กระดานอันดับ (Leaderboard) ให้ตัวละครเดินทะลุได้ 100% ไม่ชน/ไม่ติดค้าง
	local function disableLeaderboardCollisions()
		pcall(function()
			local lb = Workspace:FindFirstChild("Leaderboards")
			if not lb then return end
			for _, desc in ipairs(lb:GetDescendants()) do
				if desc:IsA("BasePart") and desc.CanCollide then
					desc.CanCollide = false
				end
			end
		end)
	end
	disableLeaderboardCollisions()
	Core:Connect(Workspace.ChildAdded, function(ch)
		if ch.Name == "Leaderboards" then
			task.wait(0.5)
			disableLeaderboardCollisions()
		end
	end)

	-- ข้อมูลแพ็คที่กำลังแบกอยู่แบบ Real-Time (ซิงก์ทันทีผ่าน ServerData.Subscribe("Stealing") + fallback ServerData.Get)
	Helpers.CarryState = {
		bound = false,
		hasLive = false,
		entry = nil,
		changedAt = 0,
		listeners = {},
	}

	function Helpers.OnCarryChanged(fn)
		if type(fn) == "function" then
			table.insert(Helpers.CarryState.listeners, fn)
		end
	end

	function Helpers.BindCarryListener()
		if Helpers.CarryState.bound then return end
		local sd = getServerData()
		if not sd then return end
		Helpers.CarryState.bound = true
		local uidStr = tostring(LocalPlayer.UserId)

		local function applyStealingTable(tbl)
			local newEntry = (type(tbl) == "table") and tbl[uidStr] or nil
			local prevEntry = Helpers.CarryState.entry
			Helpers.CarryState.hasLive = true
			Helpers.CarryState.entry = newEntry
			if (prevEntry ~= nil) ~= (newEntry ~= nil) then
				Helpers.CarryState.changedAt = os.clock()
				for _, fn in ipairs(Helpers.CarryState.listeners) do
					pcall(fn, newEntry ~= nil, newEntry)
				end
			end
		end

		if type(sd.Get) == "function" then
			local okG, curTbl = pcall(sd.Get, "Stealing")
			if okG then applyStealingTable(curTbl) end
		end
		if type(sd.Subscribe) == "function" then
			local okS, sub = pcall(sd.Subscribe, "Stealing", applyStealingTable)
			if okS and sub then
				Core:OnCleanup(function()
					if type(sub) == "function" then
						pcall(sub)
					elseif type(sub) == "table" and type(sub.Disconnect) == "function" then
						pcall(sub.Disconnect)
					elseif typeof(sub) == "RBXScriptConnection" then
						pcall(function() sub:Disconnect() end)
					end
				end)
			end
		end
	end
	pcall(Helpers.BindCarryListener)

	function Helpers.GetCarryingEntry()
		if not Helpers.CarryState.bound then
			pcall(Helpers.BindCarryListener)
		end
		if Helpers.CarryState.hasLive then
			return Helpers.CarryState.entry
		end
		local sd = getServerData()
		if not sd or type(sd.Get) ~= "function" then return nil end
		local ok, t = pcall(sd.Get, "Stealing")
		if ok and type(t) == "table" then
			return t[tostring(LocalPlayer.UserId)]
		end
		return nil
	end

	function Helpers.IsCarrying()
		return Helpers.GetCarryingEntry() ~= nil
	end

	-- ยืนยันกับเซิร์ฟเวอร์ว่าแพ็คถูกหยิบขึ้นมาถือจริง (ใช้สถานะ Real-Time ไม่หน่วง 0.12s ซ้ำซ้อน)
	function Helpers.ConfirmCarrying(timeout, settleSec)
		if Helpers.IsCarrying() then
			if settleSec and settleSec > 0 then
				task.wait(settleSec)
				return Helpers.IsCarrying()
			end
			return true
		end
		local deadline = os.clock() + (timeout or 0.6)
		while os.clock() < deadline and Core._alive do
			if Helpers.IsCarrying() then
				if settleSec and settleSec > 0 then
					task.wait(settleSec)
					return Helpers.IsCarrying()
				end
				return true
			end
			RunService.Heartbeat:Wait()
		end
		return Helpers.IsCarrying()
	end

	-----------------------------------------------------------------
	-- 3. NETWORK WRAPPER
	-----------------------------------------------------------------
	local Net = { _last = {} }
	Net.Paths = {
		Boost = RP .. "Treadmill.Boost",             -- RE: FireServer(token:string)
		ExitRequest = RP .. "Treadmill.ExitRequest", -- RE: FireServer()
		PlaceOwned = RP .. "Packs.PlaceOwned",       -- RF: InvokeServer({PackId, Position})
		OpenOwned = RP .. "Packs.OpenOwned",         -- RF: InvokeServer(packGuid)
		PacksOpened = RP .. "Packs.Opened",          -- RE: FireServer(packGuid)
		PacksEquipBest = RP .. "Packs.EquipBest",    -- RF: InvokeServer({})
		PacksMerge = RP .. "Packs.Merge",            -- RF: InvokeServer({id1, id2})
		EconomySellItems = RP .. "Economy.SellItems", -- RF: InvokeServer({packGuid})
		MutateMergeAll = RP .. "Mutate.MergeAll",     -- RF: InvokeServer(packId)
		MutateMerge = RP .. "Mutate.Merge",          -- RF: InvokeServer({id1, id2})
		MutateFuse = RP .. "Mutate.Fuse",            -- RF: InvokeServer({id1, id2, id3})
		TreadmillUpgrade = RP .. "Treadmill.Upgrade", -- RF: InvokeServer({})
		BaseUpgradePurchase = RP .. "BaseUpgrade.Purchase", -- RF: InvokeServer({})
		LuckMachineUpgrade = RP .. "LuckMachine.Upgrade", -- RF: InvokeServer(mode) ("Max" / "One")
		RebirthRequest = RP .. "Rebirth.Request",    -- RF: InvokeServer()
		OfflineClaim = RP .. "Offline.Claim",        -- RF: InvokeServer()
		DailyClaim = RP .. "Daily.Claim",            -- RF: InvokeServer()
		IndexClaimReward = RP .. "Index.ClaimReward", -- RF: InvokeServer(stage, name, kind)
		CoachesPurchase = RP .. "Coaches.Purchase",  -- RF: InvokeServer(coachId)
		CoachesEquip = RP .. "Coaches.Equip",        -- RF: InvokeServer(coachKey)
		AurasPurchase = RP .. "Auras.Purchase",      -- RF: InvokeServer(auraId)
		AurasEquip = RP .. "Auras.Equip",            -- RF: InvokeServer(auraId)
		ToolsRequestEquip = RP .. "Tools.RequestEquip", -- RE: FireServer({Equipped, Tool})
		DungeonPartyOpen = RP .. "DungeonParty.Open",   -- RF: InvokeServer("Dugeon")
		DungeonPartySetTeam = RP .. "DungeonParty.SetTeam", -- RF: InvokeServer(teamArray)
		DungeonPartyStart = RP .. "DungeonParty.Start", -- RF: InvokeServer()
		TowersSetAuto = RP .. "Towers.SetAuto",         -- RE: FireServer(true/false)
		TowersStart = RP .. "Towers.Start",             -- RF: InvokeServer(...)
		TowersTreadmill = RP .. "Towers.Treadmill",   -- RE: FireServer({Look=Vector3, Position=Vector3})
		DungeonPartyLeave = RP .. "DungeonParty.Leave", -- RE: FireServer()
		TowersExit = RP .. "Towers.Exit",               -- RE: FireServer()
		TowersRestart = RP .. "Towers.Restart",         -- RE: FireServer()
		TowersStartNow = RP .. "Towers.StartNow",       -- RE: FireServer()
		TowersIntroDone = RP .. "Towers.IntroDone",     -- RE: FireServer()
		TowersUlt = RP .. "Towers.Ult",                 -- RE: FireServer(unitId)
		TowersReplay = RP .. "Towers.Replay",           -- RE: FireServer()
	}

	function Net.Get(remote)
		local inst = remote
		if typeof(remote) == "string" then inst = Helpers.ResolvePath(remote) end
		if inst and (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent")) then
			return inst
		end
		return nil
	end

	function Net.Fire(remote, cooldown, ...)
		if not Core._alive then return false end
		local r = Net.Get(remote)
		if not r then return false end
		local key = r:GetFullName()
		local now = os.clock()
		if cooldown and (now - (Net._last[key] or 0)) < cooldown then return false end
		Net._last[key] = now
		local args = table.pack(...)
		return (pcall(function()
			r:FireServer(table.unpack(args, 1, args.n))
		end))
	end

	function Net.Invoke(remote, ...)
		if not Core._alive then return false, nil end
		local r = Net.Get(remote)
		if not r or not r:IsA("RemoteFunction") then return false, nil end
		local args = table.pack(...)
		local done = false
		local results = {}
		task.spawn(function()
			results = table.pack(pcall(function()
				return r:InvokeServer(table.unpack(args, 1, args.n))
			end))
			done = true
		end)
		local t0 = os.clock()
		while not done and (os.clock() - t0) < 4 and Core._alive do
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

	-----------------------------------------------------------------
	-- 4. FEATURE: TREADMILL (กดคูณ + คอมโบ)
	-- เซิร์ฟเวอร์ส่ง token มาที่ Treadmill.Boost -> ไคลเอนต์ยิงกลับด้วยอาร์กิวเมนต์เดิมทั้งหมด
	-- ปุ่มคูณโชว์ 2 วินาที; ถ้ากดทันทุกครั้งคอมโบจะต่อเนื่อง (x2 -> x3 -> x4 -> x5)
	-----------------------------------------------------------------
	local function tryClickBoostPopup()
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local tap = pg and pg:FindFirstChild("TAPTreadmillBoost", true)
		local sg = tap and tap:FindFirstAncestorWhichIsA("ScreenGui")
		if not tap or not sg or not sg.Enabled then return false end
		local det = tap:FindFirstChild("Detector")
		local ring = tap:FindFirstChild("TimerRing")
		if not det or not ring or not ring.Visible then return false end

		local clicked = false
		if firesignal then
			clicked = pcall(firesignal, det.Activated)
		elseif getconnections then
			clicked = pcall(function()
				for _, conn in ipairs(getconnections(det.Activated)) do
					conn:Fire()
				end
			end)
		end
		return clicked and not ring.Visible
	end

	task.spawn(function()
		local ok, folder = pcall(function()
			local r = ReplicatedStorage:WaitForChild("Remotes", 15)
			return r and r:WaitForChild("Treadmill", 15)
		end)
		local boost = ok and folder and folder:WaitForChild("Boost", 15)
		if not boost or not Core._alive then
			warn("[Kuy] ไม่พบ Remote Treadmill.Boost")
			return
		end
		-- ดักทุก RemoteEvent ในโฟลเดอร์ Treadmill เพื่อแสดงใน UI (ใช้ดูว่าเซิร์ฟเวอร์ส่งอะไรมา)
		for _, ch in ipairs(folder:GetChildren()) do
			if ch:IsA("RemoteEvent") or ch:IsA("UnreliableRemoteEvent") then
				Core:Connect(ch.OnClientEvent, function(...)
					Stats.evt = ch.Name .. "(" .. typeof((...)) .. ")"
				end)
			end
		end
		-- หน่วงให้พ้นช่วงแอนิเมชันเปิดปุ่ม (0.2s) แล้วกดปุ่ม Boost จริงก่อน หากไม่ได้ค่อยยิง Remote ตรง
		Core:Connect(boost.OnClientEvent, function(...)
			local inDg = Helpers.IsDungeonPlace and Helpers.IsDungeonPlace()
			if not (Core.Flags.AutoTreadmill or Core.Flags.AutoSteal or Core.Flags.AutoEnterDungeon or inDg) then return end
			local args = table.pack(...)
			if args.n == 0 then return end
			task.spawn(function()
				task.wait(0.24 + math.random() * 0.16)
				if Core._alive and (Core.Flags.AutoTreadmill or Core.Flags.AutoSteal or Core.Flags.AutoEnterDungeon or inDg) and LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then
					if tryClickBoostPopup() or Net.Fire(boost, nil, table.unpack(args, 1, args.n)) then
						Stats.boosts = Stats.boosts + 1
					end
				end
			end)
		end)
	end)

	local getPacksToPlace = nil
	local openReadyPlacedPacks = nil
	local placePacksInBase = nil
	local autoMergeStep = nil
	local runBaseMaintenance = nil
	local baseFullUntil = 0
	local function isFullReason(reason)
		if not reason then return false end
		local r = string.upper(tostring(reason))
		return r:find("FULL") ~= nil
			or r:find("LIMIT") ~= nil
			or r:find("MAX") ~= nil
			or r:find("SPACE") ~= nil
			or r:find("เต็ม") ~= nil
			or r:find("CAPACITY") ~= nil
	end
	local function isBaseFull()
		return os.clock() < baseFullUntil
	end

	local function getActivePlacedPacksCount()
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local placed = inv and inv.Packs and inv.Packs.Placed
		local pc = getPacksConfig()
		local count = 0
		if type(placed) == "table" then
			for _, rec in pairs(placed) do
				if type(rec) == "table" and type(rec.Id) == "string" then
					local isChar = (pc and pc.IsCharacter and pc.IsCharacter(rec)) or rec.Kind == "Character" or rec.CharacterName ~= nil
					if not isChar then
						count = count + 1
					end
				end
			end
		end
		return count
	end

	local lastEnter = 0
	local function enterTreadmill()
		if Helpers.IsDungeonPlace() or Helpers._enteringDungeon then return end
		if Core.Busy or LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then return end
		if os.clock() - lastEnter < 1.5 or not Helpers.IsAlive() or Helpers.IsCarrying() then return end

		-- ตรวจสอบว่าลู่วิ่งปลดล็อคแล้วหรือยัง (ไอดีใหม่ที่ยังไม่ผ่านเควสต์สอนเล่น TreadmillLevel จะเป็น "Level0")
		local pd = getPlayerData()
		if pd and pd.Get then
			local ok, lvl = pcall(pd.Get, "TreadmillLevel")
			if ok and lvl == "Level0" then return end
		end

		local tm = Helpers.GetPlotChild("Treadmil")
		if not tm then return end

		local pt = tm:FindFirstChild("PlayerTreadmill")
		local seat = pt and pt:FindFirstChild("Seat")
		local prim = pt and pt:FindFirstChild("Primary")
		local box = tm:FindFirstChild("TreadmilBox")
		local pp = tm:FindFirstChild("PurplePad")
		local ppPart = pp and (pp:FindFirstChildWhichIsA("BasePart", true) or (pp:IsA("BasePart") and pp))
		local targetPart = (pt and (seat or prim)) or box or ppPart or tm:FindFirstChildWhichIsA("BasePart", true)
		local pos = targetPart and Helpers.GetPosition(targetPart)
		if not pos then return end

		lastEnter = os.clock()
		-- เดินเข้าสู่แท่นลู่วิ่งด้วย MoveTo (ไม่เทเลพอร์ต เพื่อป้องกันระบบ MovementGrace ดีดตัวกลับ)
		local targetPos = (seat and seat:IsA("BasePart") and seat.Position)
			or (prim and prim:IsA("BasePart") and prim.Position)
			or (box and box:IsA("BasePart") and box.Position)
			or pos
		Helpers.MoveTo(targetPos, function()
			return not Core._alive or Core.Busy or Helpers.IsCarrying() or LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil
		end, { precise = true, arriveDist = 2.5, evadeEnemies = false })

		if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil then
			local hum = Helpers.GetHumanoid()
			if hum and targetPos then
				pcall(function() hum:MoveTo(targetPos) end)
			end
			-- รอการยืนยันสถานะ TrainingOnTreadmill จากเซิร์ฟเวอร์
			waitUntil(function()
				return LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil or not Core._alive
			end, 1.2)
		end
	end
	Helpers.EnterTreadmill = enterTreadmill

	function Loops.Enter()
		Core:Loop("enter", "AutoEnter", 1, function()
			-- ถ้าเปิดระบบ AutoSteal ให้ระบบขโมยเป็นผู้ควบคุมการขึ้น-ลงลู่วิ่งทั้งหมดเพียงผู้เดียว เพื่อไม่ให้แย่งสิทธิ์กัน
			if Core.Flags.AutoSteal then return end
			if not Core.Busy and not Helpers.IsCarrying() then
				if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil then
					enterTreadmill()
				end
			end
		end)
	end

	-----------------------------------------------------------------
	-- 5. FEATURE: STEAL PACKS (ล็อกด่านบอสเร็วสุดที่วิ่งทันเพียง 1 ด่าน)
	-- แพ็คอยู่ที่ Workspace.Game.Packs.Stage<N>.SpawnedPacks.<ชื่อ> มี ProximityPrompt ชื่อ "StealPrompt"
	-- ลำดับ: (ออกจากลู่วิ่ง) -> วิ่งเข้ากลางแมพ -> วิ่งตามเลนกลางไปหน้าด่าน -> สแกนหยิบแพ็คดีที่สุดจนสำเร็จ -> วิ่งกลับเขตปลอดภัย (ไม่วาร์ป)
	-----------------------------------------------------------------
	-- พิกัดกลางด่าน 1-12 (ใช้สำหรับ RequestStreamAroundAsync/วาร์ป เมื่อ Area ยังไม่ stream เข้ามา)
	local function promptPos(prompt)
		return Helpers.GetPosition(prompt)
	end

	-- ตำแหน่งจริงของแพ็คฝั่งเซิร์ฟเวอร์ (ไม่หลงตาม Sphere/Attachment ของ CustomPrompt บนไคลเอนต์)
	local function packAnchorPos(prompt)
		if not prompt then return nil end
		local cur = prompt.Parent
		while cur and cur ~= Workspace do
			if cur:IsA("Model") and cur.Name ~= "Sphere" then
				local anchor = cur:FindFirstChild("StealPromptAnchor", true)
				local aPos = anchor and Helpers.GetPosition(anchor)
				if aPos then return aPos end
				return cur:GetPivot().Position
			end
			cur = cur.Parent
		end
		return promptPos(prompt)
	end

	local function pressPromptKey(prompt, isDown)
		if not VirtualInputManager then return end
		local key = Enum.KeyCode.E
		pcall(function()
			if prompt and prompt.KeyboardKeyCode ~= Enum.KeyCode.Unknown then
				key = prompt.KeyboardKeyCode
			end
		end)
		pcall(function()
			VirtualInputManager:SendKeyEvent(isDown, key, false, game)
		end)
	end

	local function getStageEnemyPositions(stageFolder)
		local list = {}
		if not stageFolder then return list end
		for _, ch in ipairs(stageFolder:GetChildren()) do
			if ch.Name == "Enemy" and ch:IsA("Model") then
				local p = Helpers.GetPosition(ch)
				if p then table.insert(list, p) end
			end
		end
		return list
	end

	local StealState = {
		bossSpeedCache = {},
		lastOrderSig = "",
		lastLockedStage = nil,
		stageStealCounts = {},
		currentTargetStage = nil,
		lastResetNightCycle = 0,
		lastNightActive = nil,
		lastNoPackLogTime = 0,
		lastPreMaintenanceTime = 0,
		lastStreamAt = {},
		holdBusy = false,
		phaseResetPending = false,
		phaseResetReason = nil,
		wakeSeq = 0,
		watchersBound = false,
		boundStageFolders = {},
		nightBoundFolder = nil,
	}

	StealState.SignalWake = function()
		StealState.wakeSeq = (StealState.wakeSeq or 0) + 1
	end

	StealState.waitInterruptible = function(sec)
		local startSeq = StealState.wakeSeq
		local deadline = os.clock() + (sec or 1.0)
		while os.clock() < deadline and Core._alive and Core.Flags.AutoSteal do
			if StealState.wakeSeq ~= startSeq then
				return true
			end
			task.wait(0.1)
		end
		return StealState.wakeSeq ~= startSeq
	end

	local function getModelRarity(model)
		if not model or Helpers.IsAreaRockModel(model) then return nil, 0 end
		local r = nil
		local sr = tonumber(model:GetAttribute("SortRarity"))

		-- 1. ลำดับความสำคัญตรงตามเกมจริง: ค่า DetailRarity บน StealPrompt ที่เซิร์ฟเวอร์แสดงให้ผู้เล่นเห็น
		local prompt = model:FindFirstChild("StealPrompt", true)
		if not (prompt and prompt:IsA("ProximityPrompt")) then
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("ProximityPrompt") and string.lower(desc.Name or "") ~= "openprompt" then
					prompt = desc
					break
				end
			end
		end
		if prompt then
			r = prompt:GetAttribute("DetailRarity") or prompt:GetAttribute("ObjectRarity")
				or prompt:GetAttribute("Rarity") or prompt:GetAttribute("ItemRarity")
		end

		-- 2. ค่าจาก CharacterConfig / PacksConfig.GetRecordRarity (ตรงกับเกมจริง แก้ปัญหา Attribute เก่าบน Model เช่น Mob/Lelouch/Goku Black)
		local packName = model:GetAttribute("PackName") or model:GetAttribute("ItemName") or model:GetAttribute("CardName") or model.Name
		local pc = getPacksConfig()
		if not r or r == "" then
			local cc = getCharacterConfig()
			if cc and type(cc.Get) == "function" then
				local okC, resC = pcall(cc.Get, packName)
				if okC and type(resC) == "table" then
					r = resC.Rarity or resC.ItemRarity or resC.Grade or resC.Tier
				end
			end
		end
		if (not r or r == "") and pc then
			if type(pc.GetRecordRarity) == "function" then
				local okR, resR = pcall(pc.GetRecordRarity, { PackName = packName })
				if okR and type(resR) == "string" and resR ~= "" then
					r = resR
				end
			end
			if (not r or r == "") and type(pc.Get) == "function" then
				local okP, resP = pcall(pc.Get, packName)
				if okP and type(resP) == "table" then
					r = resP.Rarity or resP.ItemRarity or resP.Grade or resP.Tier
					sr = sr or tonumber(resP.SortRarity)
				end
			end
		end

		-- 3. Fallback สุดท้าย: อ่าน Attribute บนตัว Model
		if not r or r == "" then
			r = model:GetAttribute("Rarity")
				or model:GetAttribute("ItemRarity")
				or model:GetAttribute("PackRarity")
				or model:GetAttribute("Grade")
				or model:GetAttribute("PackGrade")
				or model:GetAttribute("Tier")
		end

		if not r or r == "" then
			return nil, 0
		end

		local rName = Helpers.CanonicalRarityKey(r)
		if not rName then return nil, 0 end
		local ranks = Helpers.GetAllRarityRanks()
		local rank = ranks[rName] or sr
		if not rank then
			-- ตรวจพบระดับใหม่แบบเรียลไทม์จากแมพ -> ลงทะเบียนและซิงก์ UI ทันที
			rName, rank = Helpers.RegisterDiscoveredRarity(rName, sr)
		end

		return rName, rank or 1
	end

	function Helpers.AreAllRaritiesAllowed()
		local ordered = Helpers.GetOrderedRarities()
		if #ordered == 0 then return false end
		for _, item in ipairs(ordered) do
			if Core.Flags[item.value] == false then
				return false
			end
		end
		return true
	end

	local function isPackRarityAllowed(model)
		if not model or Helpers.IsAreaRockModel(model) then return false end
		local rName, rank = getModelRarity(model)
		if not rName then
			-- หากผู้เล่นติ๊กเลือกทุกเกรดไว้ทั้งหมด แต่แพ็คอ่านเกรดไม่ได้ ให้อนุญาตขโมยแทนการข้ามทิ้ง
			return Helpers.AreAllRaritiesAllowed()
		end

		-- 1. ตรวจสอบจาก Flag มาตรฐานของระดับจริงในเกม (เช่น "???" -> "Rarity_Mystery", "Immortal" -> "Rarity_Immortal")
		local flagKey = Helpers.RarityToFlagKey(rName)
		if flagKey and Core.Flags[flagKey] ~= nil then
			return Core.Flags[flagKey] == true
		end

		-- 2. ค้นหาแบบไม่สนตัวพิมพ์เล็ก-ใหญ่
		local lowerName = string.lower(tostring(rName))
		for k, v in pairs(Core.Flags) do
			if type(k) == "string" and string.sub(k, 1, 7) == "Rarity_" and string.lower(string.sub(k, 8)) == lowerName then
				return v == true
			end
		end

		-- 3. Auto-detect real-time: หากเป็นระดับใหม่ที่ยังไม่เคยมีใน Flag ให้ลงทะเบียน + เปิดอนุญาตเป็นค่าเริ่มต้น + ซิงก์ UI ทันที
		if flagKey and rank and rank >= 1 then
			Helpers.RegisterDiscoveredRarity(rName, rank)
			Core.Flags[flagKey] = true
			return true
		end

		-- 4. Fallback ตรวจสอบจากลำดับ Rank จริงในเกม
		local rankNames = Helpers.GetRankNames()
		local fallbackName = rankNames[rank]
		if fallbackName then
			local fbKey = Helpers.RarityToFlagKey(fallbackName)
			if fbKey and Core.Flags[fbKey] == true then
				return true
			end
		end

		return false
	end

	local function getPackScore(model)
		local pc = getPacksConfig()
		local mc = getMutationConfig()
		local packName = (model and (model:GetAttribute("PackName") or model.Name)) or ""
		local cfg = nil
		if pc and type(pc.Get) == "function" then
			local okCfg, resCfg = pcall(pc.Get, packName)
			if okCfg and type(resCfg) == "table" then cfg = resCfg end
		end
		local luck = 1
		if cfg and pc and type(pc.GetDisplayLuck) == "function" then
			local okL, resL = pcall(pc.GetDisplayLuck, cfg)
			if okL and type(resL) == "number" then luck = resL end
		end
		local mut = model and (model:GetAttribute("Mutation") or model:GetAttribute("ItemMutation"))
		if (not mut or mut == "") and model then
			local pr = model:FindFirstChild("StealPrompt", true) or model:FindFirstChildWhichIsA("ProximityPrompt", true)
			if pr then
				mut = pr:GetAttribute("DetailMutation") or pr:GetAttribute("ObjectMutation") or pr:GetAttribute("Mutation")
			end
		end
		local mutMult = (mut and mc and mc.Mutations and mc.Mutations[mut] and mc.Mutations[mut].CashMult) or 1
		local totalMult = luck * mutMult
		local odd = (cfg and tonumber(cfg.NumericalOdd)) or 0
		local weight = model and tonumber(model:GetAttribute("Weight")) or nil
		if not weight and model then
			local scOk, sc = pcall(function() return model:GetScale() end)
			local auth = tonumber(model:GetAttribute("AuthoredModelScale")) or 1
			local rel = (scOk and type(sc) == "number" and auth > 0) and (sc / auth) or 1
			if pc and type(pc.ScaleToWeight) == "function" then
				local okW, resW = pcall(pc.ScaleToWeight, rel)
				weight = (okW and tonumber(resW)) or rel
			else
				weight = rel
			end
		end
		return totalMult, odd, weight or 0
	end

	local function isBetterCandidate(a, b)
		if not b then return true end
		local aRank, bRank = a.rank or 0, b.rank or 0
		if aRank ~= bRank then return aRank > bRank end

		local aMult, bMult = a.mult or 1, b.mult or 1
		if aMult ~= bMult then return aMult > bMult end

		local aOdd, bOdd = a.odd or 0, b.odd or 0
		if aOdd ~= bOdd then return aOdd > bOdd end

		local aWeight, bWeight = a.weight or 0, b.weight or 0
		if aWeight ~= bWeight then return aWeight > bWeight end

		-- ถ้าคุณภาพเท่ากันทุกด้าน ให้เลือกอันที่อยู่ห่างศัตรูมากกว่า
		local aEnemyDist, bEnemyDist = a.enemyDist or 0, b.enemyDist or 0
		if aEnemyDist ~= bEnemyDist then return aEnemyDist > bEnemyDist end

		-- และสุดท้ายเลือกอันที่ใกล้ตัวละครมากกว่า
		local aDist, bDist = a.dist or 0, b.dist or 0
		return aDist < bDist
	end

	Helpers.StealRetry = { now = false, streak = 0 }

	function Helpers.IsHeldByCharacter(inst)
		local cur = inst
		while cur and cur ~= Workspace do
			if cur:IsA("Backpack") then return true end
			if cur:IsA("Model") and Players:GetPlayerFromCharacter(cur) then return true end
			cur = cur.Parent
		end
		return false
	end

	-- แพ็คยังหยิบได้ไหม (ยังอยู่, prompt เปิด, ไม่ได้อยู่ในมือผู้เล่นคนอื่น)
	function Helpers.IsPromptAvailable(prompt)
		if not prompt or not prompt.Parent or not prompt:IsA("ProximityPrompt") then return false end
		if not prompt.Enabled then return false end
		return not Helpers.IsHeldByCharacter(prompt.Parent)
	end

	-- เป้าหมายหลุดมือ (ถูกคนอื่นหยิบ/หาย) โดยที่เรายังไม่ได้แบก
	function Helpers.PromptLost(prompt)
		return (not Helpers.IsCarrying()) and (not Helpers.IsPromptAvailable(prompt))
	end

	function Helpers.FindPackStealPrompt(model)
		if not model or not model.Parent or Helpers.IsAreaRockModel(model) then return nil end
		local direct = model:FindFirstChild("StealPrompt", true)
		if Helpers.IsPromptAvailable(direct) then return direct end
		local fallback = nil
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("ProximityPrompt") and Helpers.IsPromptAvailable(desc) then
				local nm = string.lower(desc.Name or "")
				local act = string.lower(desc.ActionText or "")
				if nm ~= "openprompt" and not nm:find("like", 1, true) and not nm:find("sell", 1, true) and not nm:find("upgrade", 1, true) then
					if nm:find("steal", 1, true) or act:find("steal", 1, true)
						or nm:find("grab", 1, true) or act:find("grab", 1, true)
						or nm:find("carry", 1, true) or act:find("carry", 1, true)
						or nm:find("collect", 1, true) or act:find("collect", 1, true)
						or nm:find("pick", 1, true) or act:find("pick", 1, true) then
						return desc
					end
					if not fallback then fallback = desc end
				end
			end
		end
		return fallback
	end

	function Helpers.BuildPackCandidate(model, hrp, enemies, anyGrade)
		if not model or not model.Parent or Helpers.IsAreaRockModel(model) then return nil end
		local p = Helpers.FindPackStealPrompt(model)
		if not Helpers.IsPromptAvailable(p) then return nil end
		if not anyGrade and not isPackRarityAllowed(model) then return nil end
		local pos = promptPos(p)
		if not pos then return nil end
		local minEnemyDist = math.huge
		if enemies then
			for _, ePos in ipairs(enemies) do
				local ed = (pos - ePos).Magnitude
				if ed < minEnemyDist then minEnemyDist = ed end
			end
		end
		local mult, odd, weight = getPackScore(model)
		local _, rank = getModelRarity(model)
		return {
			prompt = p, model = model, rank = rank or 1, mult = mult or 1,
			odd = odd or 0, weight = weight or 0, enemyDist = minEnemyDist,
			dist = hrp and (pos - hrp.Position).Magnitude or 0,
		}
	end

	local function findStealPrompt(stageFolder, stageNum, skipModels)
		stageNum = stageNum or (stageFolder and tonumber(string.match(stageFolder.Name, "%d+")))
		if not stageFolder and not stageNum then return nil end
		local hrp = Helpers.GetRoot()
		local enemies = getStageEnemyPositions(stageFolder)
		local best, seen = nil, {}
		local function consider(model)
			if not model or seen[model] or (skipModels and skipModels[model]) or Helpers.IsAreaRockModel(model) then return end
			seen[model] = true
			local cand = Helpers.BuildPackCandidate(model, hrp, enemies)
			if cand and isBetterCandidate(cand, best) then best = cand end
		end
		local sc = getStageConfig()
		local spName = (sc and sc.SpawnedPacksFolderName) or "SpawnedPacks"
		local root = stageFolder and stageFolder:FindFirstChild(spName)
		if root then
			for _, m in ipairs(root:GetChildren()) do consider(m) end
		end
		-- แพ็คที่หลุดตกค้างในด่าน (Tag SpawnedPack) ให้แข่งคะแนนกับแพ็คปกติ
		local center = stageNum and Helpers.GetStageCenter(stageNum)
		if center then
			local pc = getPacksConfig()
			local packTag = (pc and pc.SpawnedPackTag) or "SpawnedPack"
			local areaBounds = stageNum and Helpers.GetStageAreaBounds(stageNum)
			local searchRadius = (areaBounds and areaBounds.size and math.max(areaBounds.size.X * 0.6, 120)) or 140
			local okT, tagged = pcall(CollectionService.GetTagged, CollectionService, packTag)
			if okT and type(tagged) == "table" then
				for _, m in ipairs(tagged) do
					if m.Parent and not seen[m] and not Helpers.IsAreaRockModel(m) then
						local p = Helpers.FindPackStealPrompt(m)
						local pos = p and promptPos(p)
						if pos and (pos - center).Magnitude <= searchRadius then consider(m) end
					end
				end
			end
		end
		if best then return best.prompt, best end
		return nil
	end

	-- ยืนนิ่งและกดค้างตาม HoldDuration จริง (แยกช่องทาง InputHoldBegin / Key E ไม่กดซ้อน และออกตัวทันทีในเฟรมที่ Stealing=true)
	local function holdStationary(prompt, duration, diag)
		local anchor0 = packAnchorPos(prompt) or promptPos(prompt)
		local maxDist = (prompt and prompt.MaxActivationDistance) or 10
		local activeMethod = "hold" -- "hold" | "key"

		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = Helpers.GetRoot()

		local function zeroHorizontal(h, r)
			pcall(function()
				if h and r then h:MoveTo(r.Position) end
				if h then h:Move(Vector3.zero) end
				if r then
					local lv = r.AssemblyLinearVelocity
					r.AssemblyLinearVelocity = Vector3.new(0, lv.Y, 0)
					r.AssemblyAngularVelocity = Vector3.zero
				end
			end)
		end

		-- เบรกความเร็วแนวราบจนนิ่ง (สูงสุด 0.08s แทนการหน่วง 0.12s ตายตัว)
		zeroHorizontal(hum, hrp)
		local settleEnd = os.clock() + 0.08
		while os.clock() < settleEnd and Core._alive and Core.Flags.AutoSteal do
			if Helpers.IsCarrying() then return end
			hrp = Helpers.GetRoot()
			if not hrp then return end
			local lv = hrp.AssemblyLinearVelocity
			if Vector3.new(lv.X, 0, lv.Z).Magnitude <= 14 then break end
			zeroHorizontal(hum, hrp)
			RunService.Heartbeat:Wait()
		end

		if not (Core._alive and Core.Flags.AutoSteal and Helpers.IsPromptAvailable(prompt)) or Helpers.IsCarrying() then
			return
		end

		local t0 = os.clock()
		local deadline = t0 + duration
		local maxDeadline = t0 + duration + 1.6
		local lastRetryAt = t0
		pcall(function() prompt:InputHoldBegin() end)

		while os.clock() < deadline and Core._alive and Core.Flags.AutoSteal and Helpers.IsPromptAvailable(prompt) do
			-- ออกตัววิ่งกลับทันทีในเฟรมที่เซิร์ฟเวอร์อัปเดตสถานะ Stealing=true (0ms dead delay)
			if Helpers.IsCarrying() then break end
			if diag.trig then
				local waitCarryEnd = os.clock() + 0.55
				while os.clock() < waitCarryEnd and Core._alive and Core.Flags.AutoSteal do
					if Helpers.IsCarrying() then break end
					RunService.Heartbeat:Wait()
				end
				break
			end
			local curChar = LocalPlayer.Character
			local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
			local curHrp = Helpers.GetRoot()
			if not (curChar and curHum and curHrp) then break end

			-- หากโดนดีดหรือหลุดออกนอกระยะ MaxActivationDistance ให้ยกเลิกการกดค้างทันทีเพื่อเดินเข้าประชิดใหม่
			local prPos = promptPos(prompt)
			local anPos = packAnchorPos(prompt) or anchor0
			local prDist = prPos and (curHrp.Position - prPos).Magnitude or math.huge
			local anDist = anPos and (curHrp.Position - anPos).Magnitude or math.huge
			local effDist = math.min(prDist, anDist)
			if effDist < math.huge and effDist > (maxDist + 1.5) then
				break
			end

			if Core.Flags.AntiRagdollMode and (curChar:GetAttribute("Ragdolled") == true or curHum.PlatformStand) then
				Helpers.RecoverFromHit(curChar)
			end
			local locked = curChar:GetAttribute("TrapImmobilized") == true or (not Core.Flags.AntiRagdollMode and curChar:GetAttribute("Ragdolled") == true)
			if locked then break end

			-- ยืนนิ่งสนิท (ล้างเฉพาะความเร็วแนวราบ X/Z ไม่ล้างแรงโน้มถ่วงแกน Y)
			pcall(function()
				curHum:Move(Vector3.zero)
				local lv = curHrp.AssemblyLinearVelocity
				curHrp.AssemblyLinearVelocity = Vector3.new(0, lv.Y, 0)
			end)

			local now = os.clock()
			if diag.ended and now - lastRetryAt >= 0.3 then
				-- Hold หลุดกลางคัน -> ปล่อยให้สะอาดแล้วเริ่ม InputHoldBegin ใหม่ (ไม่กดซ้อน)
				lastRetryAt = now
				diag.ended = false
				if activeMethod == "key" then
					pressPromptKey(prompt, false)
				else
					pcall(function() prompt:InputHoldEnd() end)
				end
				RunService.Heartbeat:Wait()
				activeMethod = "hold"
				deadline = math.min(maxDeadline, os.clock() + duration)
				pcall(function() prompt:InputHoldBegin() end)
			elseif (not diag.began) and activeMethod == "hold" and now - lastRetryAt >= 0.35 then
				-- หาก InputHoldBegin ไม่ตอบสนอง -> ยกเลิก InputHoldEnd ก่อนแล้วค่อยสลับไปใช้คีย์ E เพียงช่องทางเดียว
				lastRetryAt = now
				pcall(function() prompt:InputHoldEnd() end)
				RunService.Heartbeat:Wait()
				activeMethod = "key"
				deadline = math.min(maxDeadline, os.clock() + duration)
				pressPromptKey(prompt, true)
			elseif (not diag.began) and activeMethod == "key" and fireproximityprompt and now - lastRetryAt >= 0.45 then
				-- หากทั้ง InputHoldBegin และคีย์ E ไม่ตอบสนอง -> ลองใช้ fireproximityprompt เป็นทางเลือกสำรอง
				lastRetryAt = now
				pressPromptKey(prompt, false)
				RunService.Heartbeat:Wait()
				activeMethod = "fire"
				deadline = math.min(maxDeadline, os.clock() + duration)
				pcall(fireproximityprompt, prompt)
			end

			RunService.Heartbeat:Wait()
		end

		if activeMethod == "key" then
			pressPromptKey(prompt, false)
		else
			pcall(function() prompt:InputHoldEnd() end)
		end
	end

	local function usePrompt(prompt, method, stageFolder)
		local diag = { began = false, ended = false, trig = false }
		local conns = {}
		pcall(function()
			table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function() diag.began = true end))
			table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function() diag.ended = true end))
			table.insert(conns, prompt.Triggered:Connect(function() diag.trig = true end))
		end)

		-- ใช้ fireproximityprompt เฉพาะกรณี HoldDuration <= 0 เท่านั้น
		-- แพ็คในเกมนี้มี HoldDuration = 1.5s ทุกใบ: ห้ามยิง instant trigger เพราะเซิร์ฟเวอร์ปฏิเสธการกด 0 วินาที
		local hold = prompt.HoldDuration or 1.5
		local useInstant = fireproximityprompt and method ~= "hold_only" and hold <= 0
		if useInstant then
			pcall(fireproximityprompt, prompt, 0, true)
			pcall(fireproximityprompt, prompt)
			local tEnd = os.clock() + 0.35
			while os.clock() < tEnd and Core._alive and Core.Flags.AutoSteal and prompt.Parent do
				if Helpers.IsCarrying() then break end
				RunService.Heartbeat:Wait()
			end
			if Helpers.IsCarrying() then
				for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
				return diag
			end
			diag.trig = false
		end

		holdStationary(prompt, hold + 0.85, diag)

		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		return diag
	end

	local function leaveTreadmill()
		if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil then return end
		Net.Fire(Net.Paths.ExitRequest, 0.5)

		-- ปลด Anchored และกระโดด/ก้าวออกจากสายพานโดยไม่เขียน hrp.CFrame และไม่เขียนทับ WalkSpeed
		local hrp = Helpers.GetRoot()
		local hum = Helpers.GetHumanoid()
		if hrp then
			pcall(function()
				hrp.Anchored = false
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
		end
		if hum then
			pcall(function()
				hum.Jump = true
				local spawnPos = Helpers.GetPlotSpawnPos()
				if spawnPos then hum:MoveTo(spawnPos) end
			end)
		end

		waitUntil(function() return LocalPlayer:GetAttribute(TRAINING_ATTR) == nil end, 2.0)
	end
	Helpers.LeaveTreadmill = leaveTreadmill

	local function moveToCenterLane(abortFn, targetStageCenter, targetStageNum)
		local hrp = Helpers.GetRoot()
		if not hrp then return false end
		local bounds = Helpers.GetSafeZoneBounds()
		local centerZ = (bounds and bounds.center and bounds.center.Z) or -364.5
		local maxX = (bounds and bounds.maxX) or 1203.3
		-- เลนทางเดินโล่งใน SafeZone (X ≈ 1161 พ้นป้าย Plot/Treadmill และพ้นร้าน/เครื่อง Machine2)
		local walkwayX = maxX - 42
		-- จุดกลางแมพหน้าทางออก SafeZone (ผ่านประตูกึ่งกลางออกมาเลนกลางเรียบร้อยแล้ว ไม่ติดกำแพงข้าง)
		local gateOutX = maxX + 12

		local path = {}
		if hrp.Position.X < (maxX + 4) then
			if hrp.Position.X < (walkwayX - 6) and math.abs(hrp.Position.Z - centerZ) > 16 then
				table.insert(path, { pos = Vector3.new(walkwayX, hrp.Position.Y, hrp.Position.Z), arriveDist = 8 })
			end
			if math.abs(hrp.Position.Z - centerZ) > 8 or hrp.Position.X < (walkwayX - 8) then
				table.insert(path, { pos = Vector3.new(walkwayX, hrp.Position.Y, centerZ), arriveDist = 8 })
			end
			table.insert(path, { pos = Vector3.new(gateOutX, hrp.Position.Y, centerZ), arriveDist = 8 })
			if targetStageCenter and (targetStageNum or 1) > 1 and gateOutX < (targetStageCenter.X - 50) then
				table.insert(path, { pos = Vector3.new(targetStageCenter.X - 45, targetStageCenter.Y, centerZ), arriveDist = 10 })
			end
			Helpers.MoveAlongPath(path, abortFn, { precise = false, arriveDist = 8, evadeEnemies = false, noStopOnAbort = true })
			if (abortFn and abortFn()) or not Helpers.IsAlive() then return false end
			hrp = Helpers.GetRoot()
			return hrp ~= nil and hrp.Position.X >= (maxX - 2)
		else
			if math.abs(hrp.Position.Z - centerZ) > 12 then
				table.insert(path, { pos = Vector3.new(hrp.Position.X, hrp.Position.Y, centerZ), arriveDist = 8 })
			end
			if targetStageCenter and (targetStageNum or 1) > 1 and hrp.Position.X < (targetStageCenter.X - 50) then
				table.insert(path, { pos = Vector3.new(targetStageCenter.X - 45, targetStageCenter.Y, centerZ), arriveDist = 10 })
			end
			if #path > 0 then
				Helpers.MoveAlongPath(path, abortFn, { precise = false, arriveDist = 8, evadeEnemies = false, noStopOnAbort = true })
				if (abortFn and abortFn()) or not Helpers.IsAlive() then return false end
			end
			return true
		end
	end

	local function findDroppedPackPrompt(maxRadius, skip, anyGrade, stageFolder)
		local hrp = Helpers.GetRoot()
		if not hrp then return nil end
		local radius = maxRadius or 80
		local packsFolder = Helpers.GetPacksRoot()
		local sc = getStageConfig()
		local spName = (sc and sc.SpawnedPacksFolderName) or "SpawnedPacks"
		local pc = getPacksConfig()
		local packTag = (pc and pc.SpawnedPackTag) or "SpawnedPack"
		local best, seen = nil, {}
		local function belongsToOtherStage(model)
			if not (stageFolder and packsFolder and model) then return false end
			if model:IsDescendantOf(stageFolder) then return false end
			return model:IsDescendantOf(packsFolder)
		end
		local function consider(model)
			if not model or seen[model] or (skip and skip[model]) or Helpers.IsAreaRockModel(model) then return end
			if belongsToOtherStage(model) then return end
			seen[model] = true
			local cand = Helpers.BuildPackCandidate(model, hrp, nil, anyGrade)
			if cand and cand.dist <= radius and isBetterCandidate(cand, best) then best = cand end
		end
		local okT, tagged = pcall(CollectionService.GetTagged, CollectionService, packTag)
		if okT and type(tagged) == "table" then
			for _, m in ipairs(tagged) do consider(m) end
		end
		if stageFolder then
			local container = stageFolder:FindFirstChild(spName) or stageFolder
			for _, m in ipairs(container:GetChildren()) do consider(m) end
		elseif packsFolder then
			for _, stage in ipairs(packsFolder:GetChildren()) do
				local container = stage:FindFirstChild(spName) or stage
				for _, m in ipairs(container:GetChildren()) do consider(m) end
			end
		end
		if best then return best.prompt, best end
		return nil
	end

	local function recoverDroppedPack(stageFolder)
		local char = LocalPlayer.Character
		if char and Core.Flags.AntiRagdollMode then
			Helpers.RecoverFromHit(char)
		end
		task.wait(0.1)

		local skip, tries = {}, 0
		local giveUpAt = os.clock() + 10
		while Core._alive and Core.Flags.AutoSteal and Helpers.IsAlive() and tries < 3 and os.clock() < giveUpAt do
			local prompt, cand
			local scanEnd = os.clock() + 1.2
			repeat
				prompt, cand = findDroppedPackPrompt(90, skip, false, stageFolder)
				if not prompt then prompt, cand = findDroppedPackPrompt(45, skip, true, stageFolder) end
				if prompt then break end
				task.wait(0.1)
			until os.clock() >= scanEnd
			if not prompt then break end

			tries = tries + 1
			skip[cand.model] = true
			logAction("ขโมย", "แพ็คหลุด! กำลังไปเก็บใบที่ดีที่สุดที่เหลืออยู่...", true)

			local maxDist = (prompt and prompt.MaxActivationDistance) or 10
			local pPos = packAnchorPos(prompt) or promptPos(prompt)
			if pPos then
				Helpers.MoveTo(pPos, function()
					return not Core.Flags.AutoSteal or Helpers.PromptLost(prompt) or Helpers.IsCarrying()
				end, { precise = true, arriveDist = 3.2, maxArriveDist = math.min(maxDist - 2.0, 5.5), evadeEnemies = true, noStopOnAbort = true })
			end
			if not Core.Flags.AutoSteal or not Helpers.IsAlive() then break end

			if Helpers.IsPromptAvailable(prompt) and not Helpers.IsCarrying() then
				local hrp = Helpers.GetRoot()
				local pNow = packAnchorPos(prompt) or promptPos(prompt)
				if hrp and pNow and (hrp.Position - pNow).Magnitude > (maxDist - 1.5) then
					Helpers.MoveTo(pNow, function()
						return not Core.Flags.AutoSteal or Helpers.PromptLost(prompt) or Helpers.IsCarrying()
					end, { precise = true, arriveDist = 3.0, maxArriveDist = math.min(maxDist - 2.2, 5.2), evadeEnemies = false, noStopOnAbort = true })
				end
				usePrompt(prompt, "auto", stageFolder)
				local got = Helpers.ConfirmCarrying(0.45, 0)
				if not got and Helpers.IsPromptAvailable(prompt) and Core.Flags.AutoSteal and Helpers.IsAlive() then
					local hrp2 = Helpers.GetRoot()
					local pNow2 = packAnchorPos(prompt) or promptPos(prompt)
					if hrp2 and pNow2 and (hrp2.Position - pNow2).Magnitude > (maxDist - 1.5) then
						Helpers.MoveTo(pNow2, function()
							return not Core.Flags.AutoSteal or Helpers.PromptLost(prompt) or Helpers.IsCarrying()
						end, { precise = true, arriveDist = 3.0, maxArriveDist = math.min(maxDist - 2.2, 5.2), evadeEnemies = false, noStopOnAbort = true })
					end
					usePrompt(prompt, "hold_only", stageFolder)
					got = Helpers.ConfirmCarrying(0.55, 0)
				end
			end
			if Helpers.IsCarrying() then
				logAction("ขโมย", "เก็บแพ็คที่ตกคืนสำเร็จ! กำลังนำส่งต่อ...", true)
				return true
			end
		end

		if Helpers.IsCarrying() then return true end
		return false, "แพ็คที่ตกถูกคนอื่นหยิบ/หาไม่พบ -> ไปขโมยใบถัดไปในด่านที่ตั้งค่า"
	end

	local function deliver(stageFolder)
		-- ยืนยันทันทีจาก Real-Time CarryState (ไม่หน่วง 0.12s ซ้ำเพื่อให้วิ่งหนีบอสได้ในเฟรมเดียว)
		if not Helpers.IsCarrying() and not Helpers.ConfirmCarrying(0.35, 0) then
			return false, "ยังไม่ได้ถือแพ็ค (ยกเลิกการเดินกลับเขตปลอดภัย)"
		end
		local origChar = LocalPlayer.Character
		local pos = Helpers.GetPlotSpawnPos()
		if not pos then return false, "ไม่พบจุดเกิดของฐาน" end
		local bounds = Helpers.GetSafeZoneBounds()

		local function isSafelyDelivered(livePos)
			if Helpers.IsCarrying() then return false end
			local char = LocalPlayer.Character
			if not char or char ~= origChar or not Helpers.IsAlive() then return false end
			local hrp = Helpers.GetRoot()
			if not hrp then return false end

			if Helpers.IsInSafeZone(char) then return true end
			if hrp.Position.X <= (bounds.maxX + 5) then return true end
			if livePos and (hrp.Position - livePos).Magnitude <= 35 then return true end
			if pos and (hrp.Position - pos).Magnitude <= 35 then return true end

			return false
		end

		local stopWhenDelivered = function()
			if not Core.Flags.AutoSteal then return true end
			return not Helpers.IsCarrying()
		end

		local function checkDeliveryOrRecover(livePos)
			if isSafelyDelivered(livePos) then
				return true, "DELIVERED"
			end
			if not Core.Flags.AutoSteal or not Helpers.IsAlive() or LocalPlayer.Character ~= origChar then
				Helpers.StealRetry.now = Core.Flags.AutoSteal == true
				return false, "ยกเลิก/ตัวละครตายขณะเดินกลับ"
			end
			local recovered, err = recoverDroppedPack(stageFolder)
			if recovered and Helpers.IsCarrying() then
				return false, "RECOVERED"
			end
			Helpers.StealRetry.now = true
			return false, err or "โดนตี/แพ็คหลุดกลางทาง"
		end

		for pass = 1, 5 do
			local livePos = Helpers.GetPlotSpawnPos() or pos
			local hrp = Helpers.GetRoot()
			if not hrp or not Helpers.IsAlive() or LocalPlayer.Character ~= origChar then break end

			local centerZ = (bounds and bounds.center and bounds.center.Z) or -364.5
			local gateInX = bounds.maxX - 18
			local walkwayX = bounds.maxX - 42
			local returnPath = {}

			-- วิ่งตรงรวดเดียวเข้ากลางประตู SafeZone (ไม่วิ่งเฉียงถอยเข้าหาบอส และไม่หยุดระหว่าง Waypoint)
			if hrp.Position.X > (bounds.maxX - 15) then
				table.insert(returnPath, { pos = Vector3.new(gateInX, livePos.Y, centerZ), arriveDist = 10 })
				table.insert(returnPath, { pos = Vector3.new(walkwayX, livePos.Y, centerZ), arriveDist = 10 })
			end
			table.insert(returnPath, { pos = livePos + Vector3.new(0, 3, 0), arriveDist = 8 })

			Helpers.MoveAlongPath(returnPath, stopWhenDelivered, { precise = false, arriveDist = 8, evadeEnemies = true, noStopOnAbort = true })
			if not Helpers.IsCarrying() then
				local okDeliv, state = checkDeliveryOrRecover(livePos)
				if okDeliv then return true end
				if state ~= "RECOVERED" then return false, state end
				continue
			end

			Helpers.StreamAround(livePos, 2.0)
			if waitUntil(function()
				return not Helpers.IsCarrying()
			end, 2.0) then
				if isSafelyDelivered(livePos) then return true end
				local okDeliv, state = checkDeliveryOrRecover(livePos)
				if okDeliv then return true end
				if state ~= "RECOVERED" then return false, state end
			end
		end

		if isSafelyDelivered(pos) then return true end
		return false, "ส่งแพ็คที่ฐานไม่สำเร็จ"
	end

	local function getStageFolder(i)
		return Helpers.GetStageFolder(i)
	end

	local function checkStageHasPacks(i, noStream)
		local folder = getStageFolder(i)
		local basePos = Helpers.GetStageCenter(i)
		local prompt, cand = findStealPrompt(folder, i)

		-- จำกัด StreamAround สูงสุด 1 ครั้งต่อ 3 วินาทีต่อด่าน (ตัดปัญหาเรียกซ้ำ 4 รอบจนหน่วง 6-8 วินาที)
		if not prompt and not noStream and basePos then
			local now = os.clock()
			local lastAt = StealState.lastStreamAt[i] or 0
			if (now - lastAt) >= 3.0 then
				StealState.lastStreamAt[i] = now
				Helpers.StreamAround(basePos, 1.5)
				task.wait(0.15)
				folder = getStageFolder(i)
				prompt, cand = findStealPrompt(folder, i)
			end
		end
		if prompt then return prompt, nil, cand end

		local diagReason = "ยังไม่มีแพ็คเกิดในด่าน"
		local sc = getStageConfig()
		local spName = (sc and sc.SpawnedPacksFolderName) or "SpawnedPacks"
		local root = folder and folder:FindFirstChild(spName)
		if root then
			local count, rarityCounts = 0, {}
			for _, model in ipairs(root:GetChildren()) do
				if not Helpers.IsAreaRockModel(model) then
					local p = Helpers.FindPackStealPrompt(model)
					if Helpers.IsPromptAvailable(p) then
						count = count + 1
						local rName = getModelRarity(model) or "ไม่ทราบเกรด"
						rarityCounts[rName] = (rarityCounts[rName] or 0) + 1
					end
				end
			end
			if count > 0 then
				local parts = {}
				for r, c in pairs(rarityCounts) do
					table.insert(parts, string.format("%dx %s", c, r))
				end
				diagReason = string.format("พบแพ็ค %d ใบแต่เกรดไม่ตรงเมนู (%s)", count, table.concat(parts, ", "))
			end
		end
		return nil, diagReason
	end

	local function safeStandPos(p0, stageFolder, radius)
		local nearest = findNearestEnemyPos(p0, math.huge, stageFolder)
		local dir = Vector3.new(-1, 0, 0)
		if nearest then
			local flat = Vector3.new(p0.X - nearest.X, 0, p0.Z - nearest.Z)
			if flat.Magnitude > 0.1 then
				dir = flat.Unit
			end
		end
		return p0 + dir * (radius or 3.5)
	end

	local function stealFromStage(i, knownPrompt)
		local initPrompt = knownPrompt or checkStageHasPacks(i)
		if not initPrompt then return false, "ไม่มีแพ็คให้ขโมย/ด่านปิด" end

		Helpers.GetPlotSpawnPos() -- แคชพิกัดฐานก่อนออกจากฐาน (กัน Plot stream out)

		-- ขั้นที่ 1+2 รวมเป็นเส้นทางต่อเนื่องเส้นเดียว: ออกจาก SafeZone ผ่านประตูกลาง -> วิ่งตรงตามเลนกลางสู่หน้าด่านเป้าหมาย (ไม่ชะงักกลางทาง)
		local stageCenter = Helpers.GetStageCenter(i)
		local reachedStage = moveToCenterLane(function()
			return not Core.Flags.AutoSteal or Helpers.IsCarrying()
		end, stageCenter, i)
		if not Core.Flags.AutoSteal or not Helpers.IsAlive() then return false, "ยกเลิก/ตัวละครตาย" end
		if Helpers.IsCarrying() then
			local okD, whyD = deliver(getStageFolder(i))
			return okD, whyD, nil
		end
		if not reachedStage then
			Helpers.StealRetry.now = true
			return false, "ยังวิ่งไม่ถึงกลางแมพ"
		end

		-- ขั้นที่ 3: สแกนหยิบแพ็คที่ดีที่สุด ณ เวลานั้นในด่านเป้าหมาย (หยุดครั้งเดียวด้วย Adaptive Stop ไม่วิ่งเลยสั่นไปมา)
		local skipModels, failCounts = {}, {}
		local pickedModel, lastDiag, lastDist = nil, nil, -1
		local pickupDeadline = os.clock() + 35
		local attempts = 0

		while Core._alive and Core.Flags.AutoSteal and Helpers.IsAlive() and os.clock() < pickupDeadline and attempts < 10 do
			if Helpers.IsCarrying() then
				break
			end

			local char = LocalPlayer.Character
			if char then
				if Core.Flags.AntiRagdollMode then
					Helpers.RecoverFromHit(char)
				end
				waitUntil(function()
					local ragLocked = not Core.Flags.AntiRagdollMode and char:GetAttribute("Ragdolled") == true
					return not ragLocked and not char:GetAttribute("TrapImmobilized")
				end, 3)
			end
			if not Core.Flags.AutoSteal or not Helpers.IsAlive() then
				return false, "ยกเลิก/ตัวละครตาย"
			end
			if Helpers.IsCarrying() then
				break
			end

			-- สแกนหาแพ็คที่ดีที่สุด ณ เวลานั้นในด่านเป้าหมายเสมอ (Rank > Mult > Odd > Weight)
			local stageFolder = getStageFolder(i)
			local prompt, cand = findStealPrompt(stageFolder, i, skipModels)
			if not prompt then
				stageCenter = Helpers.GetStageCenter(i)
				if stageCenter and (os.clock() - (StealState.lastStreamAt[i] or 0)) >= 2.5 then
					StealState.lastStreamAt[i] = os.clock()
					Helpers.StreamAround(stageCenter, 1.5)
					task.wait(0.15)
					stageFolder = getStageFolder(i)
					prompt, cand = findStealPrompt(stageFolder, i, skipModels)
				end
				if not prompt then
					return false, "ไม่มีแพ็คตามเกรดที่เหลือในด่าน"
				end
			end

			attempts = attempts + 1
			local targetModel = cand and cand.model
			local p0 = promptPos(prompt)
			local a0 = (p0 and packAnchorPos(prompt)) or p0
			if not a0 then
				if targetModel then skipModels[targetModel] = true end
			else
				local maxDist = (prompt and prompt.MaxActivationDistance) or 10
				local safeRadius = math.clamp(maxDist - 6.0, 2.5, 4.0)
				local maxStopDist = math.clamp(maxDist - 2.2, 3.5, 5.8)

				-- วิ่งเข้าตำแหน่งยืนที่เหมาะสมและหยุดครั้งเดียวด้วย Adaptive Stop (กัน Overshoot ที่ความเร็ว 200-340)
				local standTarget = safeStandPos(a0, stageFolder, safeRadius)
				Helpers.MoveTo(standTarget, function()
					return not Core.Flags.AutoSteal or Helpers.PromptLost(prompt) or Helpers.IsCarrying()
				end, { precise = true, arriveDist = 3.2, maxArriveDist = maxStopDist, evadeEnemies = false, noStopOnAbort = true })

				if not Core.Flags.AutoSteal or not Helpers.IsAlive() then
					return false, "ยกเลิก/ตัวละครตาย"
				end
				if Helpers.IsCarrying() then
					pickedModel = targetModel
					break
				end

				if Helpers.IsPromptAvailable(prompt) then
					local hrp = Helpers.GetRoot()
					local prNow = promptPos(prompt)
					local anNow = packAnchorPos(prompt)
					local pNow = prNow or anNow
					if hrp and pNow then
						local prDist = prNow and (hrp.Position - prNow).Magnitude or math.huge
						local anDist = anNow and (hrp.Position - anNow).Magnitude or math.huge
						lastDist = math.min(prDist, anDist)
						-- ขยับเข้าใกล้เพิ่มเฉพาะเมื่ออยู่นอกระยะปลอดภัยของ Prompt จริงๆ (ไม่แกว่งเข้าออกหากอยู่ในระยะแล้ว)
						if lastDist > (maxDist - 1.5) then
							local retryStand = safeStandPos(pNow, stageFolder, math.min(safeRadius, 3.0))
							Helpers.MoveTo(retryStand, function()
								return not Core.Flags.AutoSteal or Helpers.PromptLost(prompt) or Helpers.IsCarrying()
							end, { precise = true, arriveDist = 3.0, maxArriveDist = math.min(maxStopDist, 4.8), evadeEnemies = false, noStopOnAbort = true })
							if not Core.Flags.AutoSteal or not Helpers.IsAlive() then
								return false, "ยกเลิก/ตัวละครตาย"
							end
							if Helpers.IsCarrying() then
								pickedModel = targetModel
								break
							end
							hrp = Helpers.GetRoot()
							prNow = promptPos(prompt)
							anNow = packAnchorPos(prompt)
							if hrp then
								local d1 = prNow and (hrp.Position - prNow).Magnitude or math.huge
								local d2 = anNow and (hrp.Position - anNow).Magnitude or math.huge
								local bestD = math.min(d1, d2)
								if bestD < math.huge then lastDist = bestD end
							end
						end

						if Core.Flags.AutoSteal and Helpers.IsAlive() and Helpers.IsPromptAvailable(prompt) and lastDist <= (maxDist + 1.5) then
							local prevFails = (targetModel and failCounts[targetModel]) or 0
							local mode = prevFails == 0 and "auto" or "hold_only"
							lastDiag = usePrompt(prompt, mode, stageFolder)
							if Helpers.IsCarrying() or Helpers.ConfirmCarrying(0.45, 0) then
								pickedModel = targetModel
								break
							end
							if targetModel and Helpers.IsPromptAvailable(prompt) then
								failCounts[targetModel] = prevFails + 1
								if failCounts[targetModel] >= 3 then
									skipModels[targetModel] = true
								end
							end
						end
					end
				end
			end
		end

		-- ขั้นที่ 4: ยืนยันสถานะถือแพ็คจริงจาก ServerData("Stealing") แล้วออกตัววิ่งกลับทันที
		if not Helpers.IsCarrying() then
			local b = lastDiag and tostring(lastDiag.began) or "?"
			local t = lastDiag and tostring(lastDiag.trig) or "?"
			return false, string.format("หยิบไม่สำเร็จ(b=%s,t=%s,d=%.0f)", b, t, lastDist)
		end

		local okDeliver, whyDeliver = deliver(getStageFolder(i))
		return okDeliver, whyDeliver, pickedModel
	end

	local function returnToSafeRest(allowTreadmill)
		if Helpers._enteringDungeon then return end
		if not Helpers.IsAlive() or Helpers.IsCarrying() then return end
		if LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then return end
		if Core:IsBusyByOther("steal") then return end

		local canEnter = allowTreadmill and (Core.Flags.AutoEnter == true)
		local pos = Helpers.GetPlotSpawnPos()
		local hrp = Helpers.GetRoot()
		local bounds = Helpers.GetSafeZoneBounds()
		if not pos or not hrp then return end

		local acquiredHere = false
		if not StealState.holdBusy then
			if not Core:AcquireBusy("steal") then return end
			StealState.holdBusy = true
			acquiredHere = true
		end

		pcall(function()
			local centerZ = (bounds and bounds.center and bounds.center.Z) or -364.5
			local walkwayX = (bounds and bounds.maxX or 1203.3) - 42
			local outsideSafe = hrp.Position.X > (bounds.maxX - 10)
			local path = {}

			if outsideSafe then
				table.insert(path, { pos = Vector3.new(walkwayX, hrp.Position.Y, centerZ), arriveDist = 8 })
			end

			if canEnter then
				local flatDistToBase = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
				if outsideSafe or flatDistToBase > 20 then
					if math.abs(hrp.Position.Z - pos.Z) > 16 or outsideSafe then
						table.insert(path, { pos = Vector3.new(walkwayX, hrp.Position.Y, pos.Z), arriveDist = 8 })
					end
					table.insert(path, { pos = pos + Vector3.new(0, 3, 0), arriveDist = 8 })
				end
			end

			if #path > 0 then
				Helpers.MoveAlongPath(path, function()
					return not Core._alive or (not Core.Flags.AutoSteal and not Core.Flags.AutoEnter) or Helpers.IsCarrying()
				end, { precise = false, arriveDist = 8, noStopOnAbort = true })
			end

			if canEnter then
				local hrpAfter = Helpers.GetRoot()
				local nearBase = hrpAfter and ((Vector3.new(hrpAfter.Position.X, 0, hrpAfter.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude <= 32 and hrpAfter.Position.X <= (bounds.maxX - 10))
				if nearBase then
					-- ปลดล็อกชั่วคราวเพื่อให้ enterTreadmill ไม่ติดเช็ก Core.Busy ของตัวเอง
					if acquiredHere then
						StealState.holdBusy = false
						Core:ReleaseBusy("steal")
						acquiredHere = false
					end
					enterTreadmill()
				end
			end
		end)

		if acquiredHere then
			StealState.holdBusy = false
			Core:ReleaseBusy("steal")
		end
	end

	runBaseMaintenance = function()
		if not Core._alive then return end
		-- Priority 1: ฟัก/เก็บแพ็คที่พร้อมเปิด เพื่อเคลียร์แท่นและเปิดพื้นที่ว่างบนฐาน
		if Core.Flags.AutoOpenPacks and openReadyPlacedPacks then
			pcall(openReadyPlacedPacks)
		end

		-- Priority 2: รวมแพ็คซ้ำทั้งหมดอัตโนมัติ (สแกนทั้งในกระเป๋าและบนฐาน)
		if (Core.Flags.AutoMerge or Core.Flags.AutoPlacePacks) and autoMergeStep then
			pcall(function() autoMergeStep(true) end)
		end

		-- Priority 3: นำแพ็คในกระเป๋าไปวางลงฐาน (เฉพาะเมื่อผู้ใช้เปิด AutoPlacePacks และฐานยังไม่เต็ม)
		if Core.Flags.AutoPlacePacks and placePacksInBase then
			local remaining = (getPacksToPlace and #getPacksToPlace()) or 0
			if remaining > 0 and not isBaseFull() then
				local okPlace, resWhy = placePacksInBase()
				if isFullReason(resWhy) then
					baseFullUntil = os.clock() + 60
				end
			end
		end

		-- Priority 4: กลายพันธุ์ยูนิต/โค้ชซ้ำ 3 ตัวอัตโนมัติ (เมื่ออยู่ฐาน)
		if Core.Flags.AutoFuse and Helpers.AutoFuseStep then
			pcall(function() Helpers.AutoFuseStep(true) end)
		end
	end

	-- แจ้งเตือนรีเซ็ตรอบอย่างปลอดภัย (ห้ามปลด Core.Busy กลางอากาศขณะกำลังวิ่งอยู่ในด่าน)
	StealState.resetCycle = function(reason, fromEvent)
		if fromEvent and StealState.holdBusy then
			StealState.phaseResetPending = true
			StealState.phaseResetReason = reason
			StealState.SignalWake()
			return
		end
		table.clear(StealState.stageStealCounts)
		StealState.lastNoPackLogTime = 0
		StealState.phaseResetPending = false
		StealState.phaseResetReason = nil
		if reason then
			logAction("ขโมย", tostring(reason), true)
		end
		StealState.SignalWake()
	end

	-- อ่านความเร็ววิ่งจริงของบอสจาก StageConfig.GetEnemyWalkSpeed(stageKey) โดยตรง (อัปเดตตามแมพ 100%)
	local function getStageBossSpeed(i)
		local sc = getStageConfig()
		local stageKey = "Stage" .. tostring(i)

		if sc and type(sc.GetEnemyWalkSpeed) == "function" then
			local okWs, ws = pcall(sc.GetEnemyWalkSpeed, stageKey)
			if okWs and type(ws) == "number" and ws > 0 then
				StealState.bossSpeedCache[i] = ws
				return ws
			end
		end

		if StealState.bossSpeedCache[i] then
			return StealState.bossSpeedCache[i]
		end

		local spdCfg = getSpeedConfig()
		local stageData = sc and sc.Stages and sc.Stages[stageKey]
		if stageData then
			local enemyWalkSpeed = stageData.Enemy and stageData.Enemy.WalkSpeed
			if enemyWalkSpeed and enemyWalkSpeed > 0 then
				StealState.bossSpeedCache[i] = enemyWalkSpeed
				return enemyWalkSpeed
			end
			local rec = tonumber(stageData.RecommendedSpeed)
			if rec and spdCfg and spdCfg.ToWalkSpeed then
				local ok, ws = pcall(spdCfg.ToWalkSpeed, rec, false)
				if ok and type(ws) == "number" and ws > 0 then
					local ratio = (sc.EnemyDifficulty and tonumber(sc.EnemyDifficulty.SpeedRatio)) or 1
					StealState.bossSpeedCache[i] = ws * ratio
					return ws * ratio
				end
			end
		end

		local fallbackSpeeds = {
			[1] = 16, [2] = 36.27, [3] = 64.25, [4] = 84.97,
			[5] = 101.55, [6] = 117.1, [7] = 134.72, [8] = 157.51,
			[9] = 207.25, [10] = 214, [11] = 226.25, [12] = 241.25,
			[13] = 252.64
		}
		return fallbackSpeeds[i] or (16 + i * 18)
	end

	local function getSelectedCandidateStages()
		local mySpeed = Helpers.GetMoveSpeed()
		local margin = Core.Flags.OutrunMargin or 1.0

		local bestCandidate = nil
		local runtimeStages = Helpers.GetRuntimeStages()
		for _, st in ipairs(runtimeStages) do
			local i = st.num
			if Core.Flags["Stage" .. tostring(i)] then
				local bSpd = getStageBossSpeed(i)
				-- บังคับล็อกเฉพาะ 1 ด่านที่ความเร็วเราวิ่งหนีบอสทันและบอสเร็วที่สุด (ตัวเลือก A)
				local canOutrun = (i == 1) or (mySpeed >= (bSpd * margin))
				if canOutrun then
					if (not bestCandidate)
						or (bSpd > bestCandidate.bossSpeed)
						or (bSpd == bestCandidate.bossSpeed and i > bestCandidate.stage) then
						bestCandidate = {
							stage = i,
							bossSpeed = bSpd,
							canOutrun = true,
							meta = st,
						}
					end
				end
			end
		end

		if bestCandidate then
			return { bestCandidate }
		end
		return {}
	end

	-----------------------------------------------------------------
	-- REAL-TIME MAP, NIGHT, PACK & SPEED WATCHERS (ผ่าน Core:Connect ปิด Leak 100%)
	-----------------------------------------------------------------
	local function getNightFolder()
		return Workspace:FindFirstChild("Night")
	end

	local function isNightActive()
		local nf = getNightFolder()
		return nf and nf:GetAttribute("NightActive") == true
	end

	local function getNightPhaseEndsAt()
		local nf = getNightFolder()
		return nf and tonumber(nf:GetAttribute("NightPhaseEndsAt")) or 0
	end

	StealState.bindNightFolder = function(nf)
		if not nf or StealState.nightBoundFolder == nf then return end
		StealState.nightBoundFolder = nf
		pcall(function()
			Core:Connect(nf:GetAttributeChangedSignal("NightActive"), function()
				local active = nf:GetAttribute("NightActive") == true
				StealState.lastNightActive = active
				local info = active
					and "🌙 เซิร์ฟเวอร์เข้าสู่เวลากลางคืน (Night Active)! แพ็คการ์ดทุกด่านรีเซ็ตใหม่ -> เริ่มรอบขโมยใหม่"
					or "☀️ เข้าสู่รอบกลางวันใหม่ -> แพ็คการ์ดรีเซ็ตพร้อมเริ่มขโมยชุดใหม่ทันที"
				StealState.resetCycle(info, true)
			end)
			Core:Connect(nf:GetAttributeChangedSignal("NightPhaseEndsAt"), function()
				local endsAt = tonumber(nf:GetAttribute("NightPhaseEndsAt")) or 0
				if endsAt > 0 and endsAt ~= StealState.lastResetNightCycle then
					StealState.lastResetNightCycle = endsAt
					StealState.resetCycle("🔄 ตรวจพบการเปลี่ยนรอบเวลาเซิร์ฟเวอร์ (Phase Reset) -> พร้อมเริ่มรอบขโมยใหม่", true)
				end
			end)
		end)
	end

	StealState.bindStageFolder = function(stageFolder)
		if not stageFolder or StealState.boundStageFolders[stageFolder] then return end
		local stageNum = tonumber(string.match(stageFolder.Name, "^Stage(%d+)$"))
		if not stageNum then return end
		StealState.boundStageFolders[stageFolder] = true

		local sc = getStageConfig()
		local spName = (sc and sc.SpawnedPacksFolderName) or "SpawnedPacks"
		local areaName = (sc and sc.AreaPartName) or "Area"

		local function onPackAdded(child)
			if not child or Helpers.IsAreaRockModel(child) then return end
			task.defer(function()
				if Core._alive and child.Parent then
					pcall(getModelRarity, child) -- ตรวจจับเกรดใหม่แบบเรียลไทม์อัตโนมัติ
					if StealState.lastLockedStage == nil or StealState.lastLockedStage == stageNum then
						StealState.SignalWake()
					end
				end
			end)
		end

		local function bindSpawnedFolder(sp)
			if not sp then return end
			Core:Connect(sp.ChildAdded, onPackAdded)
		end

		local sp = stageFolder:FindFirstChild(spName)
		if sp then bindSpawnedFolder(sp) end

		Core:Connect(stageFolder.ChildAdded, function(ch)
			if ch.Name == spName then
				bindSpawnedFolder(ch)
				StealState.SignalWake()
			elseif ch.Name == areaName and ch:IsA("BasePart") then
				Helpers.GetStageAreaBounds(stageNum)
			end
		end)
	end

	StealState.bindRealtimeWatchers = function()
		if StealState.watchersBound then return end
		StealState.watchersBound = true

		-- 1. Night / Day Reset Listener
		StealState.bindNightFolder(getNightFolder())
		Core:Connect(Workspace.ChildAdded, function(child)
			if child.Name == "Night" then
				task.defer(StealState.bindNightFolder, child)
			end
		end)

		-- 2. Stage & Pack Spawn Listeners (ตรวจพบด่านใหม่/แพ็คเกิดใหม่/ระดับใหม่แบบเรียลไทม์)
		local function bindPacksRoot(packsRoot)
			if not packsRoot then return end
			for _, st in ipairs(packsRoot:GetChildren()) do
				StealState.bindStageFolder(st)
			end
			Core:Connect(packsRoot.ChildAdded, function(child)
				StealState.bindStageFolder(child)
				local num = tonumber(string.match(child.Name, "^Stage(%d+)$"))
				if num then
					StealState.bossSpeedCache[num] = nil
					Helpers.GameCatalog.areaCenters[num] = nil
					Helpers.GameCatalog.areaBounds[num] = nil
				end
				Helpers.GetRuntimeStages()
				Helpers.TriggerCatalogUISync()
				StealState.SignalWake()
			end)
			Core:Connect(packsRoot.ChildRemoved, function(child)
				StealState.boundStageFolders[child] = nil
				Helpers.TriggerCatalogUISync()
			end)
		end

		local packsRoot = Helpers.GetPacksRoot()
		if packsRoot then
			bindPacksRoot(packsRoot)
		else
			local gameFolder = Workspace:FindFirstChild("Game")
			if gameFolder then
				Core:Connect(gameFolder.ChildAdded, function(ch)
					if ch.Name == "Packs" then bindPacksRoot(ch) end
				end)
			end
		end

		-- 3. CollectionService SpawnedPack Listener (ดักจับแพ็คเกิดใหม่หรือตกหล่นพร้อมตรวจ Rarity ใหม่ทันที)
		local pc = getPacksConfig()
		local packTag = (pc and pc.SpawnedPackTag) or "SpawnedPack"
		pcall(function()
			Core:Connect(CollectionService:GetInstanceAddedSignal(packTag), function(inst)
				if inst and not Helpers.IsAreaRockModel(inst) then
					task.defer(function()
						if Core._alive and inst.Parent then
							pcall(getModelRarity, inst)
							StealState.SignalWake()
						end
					end)
				end
			end)
		end)

		-- 4. Speed Subscriber (ปลดล็อกด่านสูงกว่าหรือสลับด่านทันทีเมื่อ Speed เปลี่ยนแบบเรียลไทม์)
		local pd = getPlayerData()
		if pd and type(pd.Subscribe) == "function" then
			local okSpd, subSpd = pcall(pd.Subscribe, "Speed", function()
				StealState.SignalWake()
			end)
			if okSpd and subSpd then
				Core:OnCleanup(function()
					if type(subSpd) == "function" then
						pcall(subSpd)
					elseif type(subSpd) == "table" and type(subSpd.Disconnect) == "function" then
						pcall(subSpd.Disconnect)
					elseif typeof(subSpd) == "RBXScriptConnection" then
						pcall(function() subSpd:Disconnect() end)
					end
				end)
			end
		end

		-- 5. Carry Subscriber -> ปลุกลูปเมื่อส่งแพ็คสำเร็จ
		Helpers.OnCarryChanged(function(carrying)
			if not carrying then
				StealState.SignalWake()
			end
		end)
	end

	StealState.bindRealtimeWatchers()

	StealState.cycleInner = function()
		-- 0. ตรวจจับและเคลียร์รอบรีเซ็ตกลางวัน/กลางคืนที่จุดปลอดภัยบนสุดของลูปเท่านั้น
		if StealState.phaseResetPending then
			StealState.resetCycle(StealState.phaseResetReason, false)
		end
		local isNight = isNightActive()
		local currentPhaseEndsAt = getNightPhaseEndsAt()
		local phaseChanged = (currentPhaseEndsAt > 0 and StealState.lastResetNightCycle > 0 and currentPhaseEndsAt ~= StealState.lastResetNightCycle)
		local nightToggled = (StealState.lastNightActive ~= nil and StealState.lastNightActive ~= isNight)

		if StealState.lastResetNightCycle == 0 and currentPhaseEndsAt > 0 then
			StealState.lastResetNightCycle = currentPhaseEndsAt
		end

		if phaseChanged or nightToggled then
			StealState.lastNightActive = isNight
			StealState.lastResetNightCycle = currentPhaseEndsAt
			local info = isNight
				and "🌙 เซิร์ฟเวอร์เข้าสู่เวลากลางคืน (Night Active)! แพ็คการ์ดทุกด่านรีเซ็ตใหม่ -> เริ่มรอบขโมยใหม่"
				or "☀️ เข้าสู่รอบกลางวันใหม่ -> แพ็คการ์ดรีเซ็ตพร้อมเริ่มขโมยชุดใหม่ทันที"
			StealState.resetCycle(info, false)
		end

		-- หากมีลูปอื่น (เช่น Dungeon) ถือสิทธิ์ Busy อยู่ ให้รออย่างปลอดภัยไม่แย่ง MoveTo ซ้อน
		if Core:IsBusyByOther("steal") then
			StealState.waitInterruptible(0.25)
			return
		end

		-- 1. ค้นหาด่านเดียวที่บอสเร็วที่สุดและตัวละครวิ่งหนีบอสทัน (ล็อกแค่ 1 ด่านเสมอ — ตัวเลือก A)
		local candidateStages = getSelectedCandidateStages()
		if #candidateStages == 0 then
			local mySpeed = Helpers.GetMoveSpeed()
			local lowestSelected = nil
			for _, st in ipairs(Helpers.GetRuntimeStages()) do
				if Core.Flags["Stage" .. tostring(st.num)] then
					lowestSelected = st.num
					break
				end
			end
			if lowestSelected then
				local minSpd = getStageBossSpeed(lowestSelected) or 16
				local sig = string.format("TRAIN(M=%.0f,Req=%.0f)", mySpeed, minSpd)
				if sig ~= StealState.lastOrderSig then
					StealState.lastOrderSig = sig
					logAction("ฝึกซ้อม", string.format("ความเร็วเรา (%.0f) ยังต่ำกว่าด่าน %d (ต้องการ %.0f) -> เข้าลู่วิ่งปั๊ม Speed", mySpeed, lowestSelected, minSpd), true)
				end
			else
				local sig = "NO_STAGE_SELECTED"
				if sig ~= StealState.lastOrderSig then
					StealState.lastOrderSig = sig
					logAction("ด่านเป้าหมาย", "ยังไม่ได้เลือกด่านที่ต้องการขโมยในเมนู (กรุณาติ๊กเลือกอย่างน้อย 1 ด่าน)", false)
				end
			end

			if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil and Helpers.IsAlive() and not Helpers.IsCarrying() then
				returnToSafeRest(true)
			end
			StealState.waitInterruptible(1.2)
			return
		end

		-- 2. สแกนหาแพ็คที่ดีที่สุดตามเกรดจริงในเกม เฉพาะในด่านเป้าหมายเดียวที่วิ่งหนีบอสทันและเร็วที่สุด
		local lockedCand = candidateStages[1]
		local sNum = lockedCand.stage
		if StealState.lastLockedStage ~= sNum then
			StealState.lastLockedStage = sNum
			local stLabel = (lockedCand.meta and lockedCand.meta.text) and (" (" .. lockedCand.meta.text .. ")") or ""
			logAction("ด่านเป้าหมาย", string.format("ล็อกเก็บเฉพาะด่าน %d%s (ความเร็วเรา %.0f / บอส %.0f)", sNum, stLabel, Helpers.GetMoveSpeed(), lockedCand.bossSpeed or 0), true)
		end

		local promptFound, lastDiag = checkStageHasPacks(sNum, false)
		local targetStage, targetPrompt = nil, nil
		if promptFound then
			targetStage, targetPrompt = sNum, promptFound
		end

		-- 3. หากไม่มีแพ็คตามเกรดที่เลือกเกิดในด่านเป้าหมาย -> พักบนลู่วิ่งและรอปลุกทันทีแบบ Real-Time เมื่อแพ็คเกิด
		if not targetStage or not targetPrompt then
			local now = os.clock()
			if now - (StealState.lastNoPackLogTime or 0) > 15 then
				StealState.lastNoPackLogTime = now
				local reason = lastDiag or "ไม่มีแพ็คตามเกรดที่เลือกเกิดในด่านเป้าหมาย"
				logAction("ขโมย", string.format("ด่าน %d: %s -> พักบนลู่วิ่ง รอแพ็คเกิดใหม่ (Real-Time)", sNum, reason), false)
			end

			if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil and Helpers.IsAlive() and not Helpers.IsCarrying() then
				returnToSafeRest(true)
			end
			if runBaseMaintenance and Core:AcquireBusy("steal") then
				StealState.holdBusy = true
				pcall(runBaseMaintenance)
				StealState.holdBusy = false
				Core:ReleaseBusy("steal")
			end
			StealState.waitInterruptible(1.5)
			return
		end

		local i = targetStage
		StealState.currentTargetStage = i

		if not Core.Flags["Stage" .. tostring(i)] or not Helpers.IsAlive() then
			return
		end

		-- ถือ Exclusive Busy Lock ("steal") ครอบทั้ง Pre-Maintenance -> LeaveTreadmill -> Steal -> Post-Maintenance (กันคำสั่งอื่นแทรก 100%)
		if not Core:AcquireBusy("steal") then
			StealState.waitInterruptible(0.2)
			return
		end
		StealState.holdBusy = true

		-- จัดการงานฐาน (รวมแพ็คซ้ำ + วางแพ็คลงแปลงเพาะ) ให้เรียบร้อยก่อนออกจากฐานไปขโมย (Throttled 10s)
		if not Helpers.IsCarrying() and runBaseMaintenance then
			local hrp = Helpers.GetRoot()
			local bPos = Helpers.GetPlotSpawnPos()
			if hrp and bPos and (hrp.Position - bPos).Magnitude <= 50 then
				local now = os.clock()
				if (now - (StealState.lastPreMaintenanceTime or 0)) >= 10 then
					local hasPacks = (getPacksToPlace and #getPacksToPlace() > 0)
					local hasMerges = (Core.Flags.AutoMerge and Helpers.HasReadyMerges and Helpers.HasReadyMerges()) or false
					local hasFuses = (Core.Flags.AutoFuse and Helpers.HasReadyFuses and Helpers.HasReadyFuses()) or false
					if hasPacks or hasMerges or hasFuses then
						StealState.lastPreMaintenanceTime = now
						pcall(runBaseMaintenance)
					end
				end
			end
		end

		local prompt = targetPrompt
		if not Helpers.IsPromptAvailable(prompt) then
			prompt = checkStageHasPacks(i, true)
		end
		if not prompt then
			StealState.holdBusy = false
			Core:ReleaseBusy("steal")
			if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil and Helpers.IsAlive() and not Helpers.IsCarrying() then
				returnToSafeRest(true)
			end
			StealState.waitInterruptible(0.8)
			return
		end

		leaveTreadmill()
		local curHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if curHum then pcall(function() curHum:UnequipTools() end) end
		local fallbackModel = prompt.Parent
		while fallbackModel and fallbackModel ~= Workspace and not fallbackModel:IsA("Model") do
			fallbackModel = fallbackModel.Parent
		end
		local ok, res, why, pickedModel = pcall(stealFromStage, i, prompt)

		if ok and res then
			StealState.stageStealCounts[i] = (StealState.stageStealCounts[i] or 0) + 1
			Stats.stealOk = Stats.stealOk + 1
			Helpers.StealRetry.streak = 0
			local finalModel = pickedModel or fallbackModel
			local rName = finalModel and getModelRarity(finalModel) or "Pack"
			local pName = finalModel and (finalModel:GetAttribute("PackName") or finalModel.Name) or ""
			local cntTxt = tostring(StealState.stageStealCounts[i])
			local info = (pName ~= "" and pName ~= rName)
				and string.format("ด่าน %d [%s - %s]: สำเร็จ (ใบที่ %s)", i, tostring(rName), tostring(pName), cntTxt)
				or string.format("ด่าน %d [%s]: สำเร็จ (ใบที่ %s)", i, tostring(rName), cntTxt)
			logAction("ขโมย", info, true)

			-- จัดการงานฐานตามคิวภายใต้ Lock "steal" (ไม่ปล่อยให้ลูป Merge/Fuse แทรกกลางทาง)
			if (Core.Flags.AutoPlacePacks or Core.Flags.AutoOpenPacks or Core.Flags.AutoMerge or Core.Flags.AutoFuse) and runBaseMaintenance then
				if Core.Flags.AutoPlacePacks then
					local waitSyncEnd = os.clock() + 1.5
					while os.clock() < waitSyncEnd and Core._alive and Core.Flags.AutoSteal do
						local count = (getPacksToPlace and #getPacksToPlace()) or 0
						if count > 0 then break end
						task.wait(0.1)
					end
				end
				pcall(runBaseMaintenance)
			end
		else
			Stats.stealFail = Stats.stealFail + 1
			local reason = res
			if ok then reason = why or "ไม่ทราบสาเหตุ" end
			logAction("ขโมย", "ด่าน " .. i .. ": " .. tostring(reason), false)

			local retry = Helpers.StealRetry
			local stageEmpty = ok and reason == "ไม่มีแพ็คตามเกรดที่เหลือในด่าน"
			local lostTarget = ok and not stageEmpty and Core.Flags.AutoSteal and Helpers.PromptLost(prompt)
			if not stageEmpty and (retry.now or lostTarget) and Core.Flags.AutoSteal and retry.streak < 6 then
				retry.now = false
				retry.streak = retry.streak + 1
				logAction("ขโมย", "แพ็คหลุด/ถูกคนอื่นหยิบ/โดนตี -> หาแพ็คที่ดีที่สุดถัดไปในด่านที่ตั้งค่าทันที", true)
				waitUntil(function()
					local c = LocalPlayer.Character
					local h = c and c:FindFirstChildOfClass("Humanoid")
					return c and h and h.Health > 0
				end, 3.0)
				StealState.holdBusy = false
				Core:ReleaseBusy("steal")
				task.wait(0.08)
				return
			end
			retry.now = false
			retry.streak = 0

			task.wait(0.5)
			waitUntil(function()
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				return char and hum and hum.Health > 0
			end, 3.0)
		end

		StealState.holdBusy = false
		Core:ReleaseBusy("steal")
		if (Core.Flags.StealDelay or 0) > 0 then
			StealState.waitInterruptible(Core.Flags.StealDelay)
		end
	end

	local function stealCycle()
		if Helpers.IsDungeonPlace() or Helpers._enteringDungeon then return end
		if StealState.holdBusy then
			StealState.holdBusy = false
			Core:ReleaseBusy("steal")
		end
		local ok, err = pcall(StealState.cycleInner)
		if StealState.holdBusy then
			StealState.holdBusy = false
			Core:ReleaseBusy("steal")
		end
		if not ok then
			logAction("ขโมย", "รอบขโมยพัง: " .. tostring(err) .. " -> ปลดล็อกแล้วกลับลู่วิ่ง", false)
			pcall(function()
				if Core._alive and Core.Flags.AutoSteal and Helpers.IsAlive()
					and not Helpers.IsCarrying() and LocalPlayer:GetAttribute(TRAINING_ATTR) == nil then
					returnToSafeRest(true)
				end
			end)
			task.wait(0.8)
		end
	end

	function Loops.Steal()
		if StealState.holdBusy then
			StealState.holdBusy = false
			Core:ReleaseBusy("steal")
		end
		StealState.lastOrderSig = ""
		StealState.lastLockedStage = nil
		StealState.lastNoPackLogTime = 0
		StealState.bindRealtimeWatchers()
		Core:Loop("steal", "AutoSteal", 0.15, stealCycle)
	end

	Core:OnCleanup(Helpers.StopMove)

	-----------------------------------------------------------------
	-- 5.5. FEATURE: COACHES & AURAS (Auto Buy / Auto Equip Best)
	-----------------------------------------------------------------
	local CoachState = {
		lastCoachBuy = 0,
		lastCoachEquip = 0,
		lastEquippedCoachKey = "",
		coachEquipDebounceUntil = 0,
		lastAuraBuy = 0,
		lastAuraEquip = 0,
	}

	local function getPlayerDataKey(key)
		local pd = getPlayerData()
		if not (pd and pd.Get) then return nil end
		local ok, val = pcall(pd.Get, key)
		if ok then return val end
		return nil
	end

	local function getPlayerCash()
		local cash = tonumber(getPlayerDataKey("Cash"))
		if cash then return cash end
		local ls = LocalPlayer:FindFirstChild("leaderstats")
		local cv = ls and ls:FindFirstChild("Cash")
		return (cv and tonumber(cv.Value)) or 0
	end

	local function isRemoteOk(res)
		if type(res) == "table" then
			local reason = res.Reason or res.reason or res.Message or res.message or res.Error or res.error or res.why or res.Why
			if res.Success ~= nil then return res.Success == true, reason end
			if res.Ok ~= nil then return res.Ok == true, reason end
			if res.success ~= nil then return res.success == true, reason end
			return true, nil
		end
		return res == true, nil
	end

	local function equipBestCoach()
		local cu = getCoachUtil()
		local cc = getCoachConfig()
		local mc = getMutationConfig()
		local coachData = getPlayerDataKey("Coaches")
		if not (cu and type(coachData) == "table" and type(coachData.Owned) == "table") then return end

		local mutOrderMap = {}
		if mc and mc.Order then
			for idx, mName in ipairs(mc.Order) do
				mutOrderMap[mName] = idx
			end
		end

		local bestKey, bestMult, bestOrder, bestMutRank = nil, -1, -1, -1
		for key in pairs(coachData.Owned) do
			if cu.GetCount(coachData, key) > 0 then
				local entry, mut = cu.Get(key)
				if entry then
					local mult = cu.GetEntryMultiplier(entry, mut)
					local ord = entry.Order or 0
					local mutRank = mut and mutOrderMap[mut] or 0

					local isBetter = false
					if mult > bestMult then
						isBetter = true
					elseif mult == bestMult then
						if ord > bestOrder then
							isBetter = true
						elseif ord == bestOrder then
							if mutRank > bestMutRank then
								isBetter = true
							elseif mutRank == bestMutRank and (bestKey == nil or key > bestKey) then
								isBetter = true
							end
						end
					end

					if isBetter then
						bestKey, bestMult, bestOrder, bestMutRank = key, mult, ord, mutRank
					end
				end
			end
		end
		if not bestKey then return end

		local attrName = (cc and cc.Attributes and cc.Attributes.Equipped) or "EquippedCoach"
		local curEquipped = coachData.Equipped
		local curAttr = LocalPlayer:GetAttribute(attrName)

		-- หากโค้ชที่ดีที่สุดสวมใส่อยู่แล้ว (ทั้งใน PlayerData หรือใน Character Attribute) ให้บันทึกและจบการทำงานทันที
		if curEquipped == bestKey or curAttr == bestKey then
			CoachState.lastEquippedCoachKey = bestKey
			return
		end

		local now = os.clock()
		-- หากเพิ่งยิงคำสั่งสวมใส่ bestKey นี้ไปแล้ว และอยู่ในช่วง Debounce (5 วินาที) ไม่ยิงซ้ำระหว่างรอเซิร์ฟเวอร์ตอบสนอง
		if CoachState.lastEquippedCoachKey == bestKey and now < CoachState.coachEquipDebounceUntil then
			return
		end

		local rateLimit = math.max((cc and cc.RateLimit) or 0.3, 1.5)
		if now - CoachState.lastCoachEquip < rateLimit then return end
		CoachState.lastCoachEquip = now
		CoachState.coachEquipDebounceUntil = now + 5.0
		CoachState.lastEquippedCoachKey = bestKey

		local ok, res = Net.Invoke(Net.Paths.CoachesEquip, bestKey)
		local success, reason = isRemoteOk(res)
		if ok and success then
			logAction("โค้ช", "สวมใส่: " .. tostring(cu.GetDisplayName(bestKey)), true)
		elseif ok and reason then
			-- หากล้มเหลว ให้เคลียร์ debounce เพื่อให้สามารถลองใหม่ได้เมื่อพร้อม
			CoachState.lastEquippedCoachKey = ""
			CoachState.coachEquipDebounceUntil = 0
			logAction("โค้ช", "ใส่พลาด: " .. tostring(reason), false)
		end
	end

	local function buyBestCoach()
		local cu = getCoachUtil()
		local cc = getCoachConfig()
		local coachData = getPlayerDataKey("Coaches")
		if not (cu and type(coachData) == "table") then return end

		local now = os.clock()
		local rateLimit = math.max((cc and cc.RateLimit) or 0.3, 0.4)
		if now - CoachState.lastCoachBuy < rateLimit then return end

		local all = cu.GetAll()
		if type(all) ~= "table" then return end

		table.sort(all, function(a, b)
			local ba, bb = tonumber(a.Boost) or 0, tonumber(b.Boost) or 0
			if ba == bb then
				return (tonumber(a.Price) or 0) > (tonumber(b.Price) or 0)
			end
			return ba > bb
		end)

		local cash = getPlayerCash()
		local window = cu.GetWindow(Workspace:GetServerTimeNow())
		for _, entry in ipairs(all) do
			if not entry.Featured and type(entry.Price) == "number" and entry.Price > 0 and cash >= entry.Price then
				if cu.GetRemaining(coachData, entry, window) > 0 then
					CoachState.lastCoachBuy = now
					local ok, res = Net.Invoke(Net.Paths.CoachesPurchase, entry.Id)
					local success, reason = isRemoteOk(res)
					if ok and success then
						logAction("โค้ช", "ซื้อสำเร็จ: " .. tostring(entry.Name or entry.Id), true)
						-- เซิร์ฟเวอร์มีระบบ AutoEquipOnPurchase = true ซึ่งอาจสลับใส่โค้ชที่เพิ่งซื้ออัตโนมัติ
						-- ให้เรียก equipBestCoach เพื่อสวมใส่โค้ชที่ดีที่สุดกลับมาทันที
						task.spawn(function()
							task.wait(0.2)
							CoachState.lastEquippedCoachKey = ""
							equipBestCoach()
						end)
					elseif ok and reason then
						logAction("โค้ช", "ซื้อพลาด: " .. tostring(reason), false)
					end
					return
				end
			end
		end
	end

	local function equipBestAura()
		local ac = getAurasConfig()
		local auraData = getPlayerDataKey("Auras")
		if not (ac and type(ac.Ordered) == "table" and type(auraData) == "table" and type(auraData.Owned) == "table") then return end

		local bestId, bestName, bestMult, bestOrder = nil, nil, -1, -1
		for _, aura in ipairs(ac.Ordered) do
			if auraData.Owned[aura.Id] then
				local mult = tonumber(aura.SpeedMultiplier) or 0
				local ord = tonumber(aura.Order) or 0
				if mult > bestMult or (mult == bestMult and ord > bestOrder) then
					bestId, bestName, bestMult, bestOrder = aura.Id, aura.DisplayName or aura.Id, mult, ord
				end
			end
		end
		if not bestId or auraData.Equipped == bestId then return end

		local now = os.clock()
		if now - CoachState.lastAuraEquip < 1.0 then return end
		CoachState.lastAuraEquip = now

		local ok, res = Net.Invoke(Net.Paths.AurasEquip, bestId)
		local success, reason = isRemoteOk(res)
		if ok and success then
			logAction("ออร่า", "สวมใส่: " .. tostring(bestName), true)
		elseif ok and reason then
			logAction("ออร่า", "ใส่พลาด: " .. tostring(reason), false)
		end
	end

	local function buyBestAura()
		local ac = getAurasConfig()
		local auraData = getPlayerDataKey("Auras")
		if not (ac and type(ac.Ordered) == "table" and type(auraData) == "table") then return end

		local now = os.clock()
		if now - CoachState.lastAuraBuy < 0.6 then return end

		local owned = type(auraData.Owned) == "table" and auraData.Owned or {}
		local candidates = {}
		for _, aura in ipairs(ac.Ordered) do
			if not owned[aura.Id] then
				table.insert(candidates, aura)
			end
		end
		if #candidates == 0 then return end

		table.sort(candidates, function(a, b)
			local ma, mb = tonumber(a.SpeedMultiplier) or 0, tonumber(b.SpeedMultiplier) or 0
			if ma == mb then
				return (tonumber(a.Order) or 0) > (tonumber(b.Order) or 0)
			end
			return ma > mb
		end)

		local cash = getPlayerCash()
		for _, aura in ipairs(candidates) do
			local price = tonumber(aura.CashPrice)
			if price and price > 0 and cash >= price then
				CoachState.lastAuraBuy = now
				local ok, res = Net.Invoke(Net.Paths.AurasPurchase, aura.Id)
				local success, reason = isRemoteOk(res)
				if ok and success then
					logAction("ออร่า", "ซื้อสำเร็จ: " .. tostring(aura.DisplayName or aura.Id), true)
				elseif ok and reason then
					logAction("ออร่า", "ซื้อพลาด: " .. tostring(reason), false)
				end
				return
			end
		end
	end

	function Loops.BuyCoach()
		Core:Loop("buyCoach", "AutoBuyCoach", 1, buyBestCoach)
	end

	function Loops.EquipCoach()
		task.spawn(equipBestCoach)
		Core:Loop("equipCoach", "AutoEquipCoach", 4.0, equipBestCoach)

		-- เชื่อมต่อ Event เมื่อข้อมูลโค้ชมีการเปลี่ยนแปลง เพื่อให้สวมใส่ทันทีเมื่อพร้อม
		local pd = getPlayerData()
		if pd and pd.Subscribe then
			pcall(function()
				pd.Subscribe("Coaches", function()
					if Core._alive and Core.Flags.AutoEquipCoach then
						equipBestCoach()
					end
				end)
			end)
		end
	end

	function Loops.BuyAura()
		Core:Loop("buyAura", "AutoBuyAura", 1, buyBestAura)
	end

	function Loops.EquipAura()
		Core:Loop("equipAura", "AutoEquipAura", 1.2, equipBestAura)
	end

	-----------------------------------------------------------------
	-- 5.6. FEATURE: PACKS & ECONOMY (Open / EquipBest / Sell / Merge / Fuse)
	-----------------------------------------------------------------
	local itemSkipUntil = {}
	local permSkipItems = {}
	local lastEquipBest, lastSell, lastMerge, lastFuse, lastIdleMaintenance = 0, 0, 0, 0, 0

	local function getBagTools(includeCharacter)
		local list = {}
		local bp = LocalPlayer:FindFirstChild("Backpack")
		if bp then
			for _, ch in ipairs(bp:GetChildren()) do
				if ch:IsA("Tool") then table.insert(list, ch) end
			end
		end
		if includeCharacter and LocalPlayer.Character then
			for _, ch in ipairs(LocalPlayer.Character:GetChildren()) do
				if ch:IsA("Tool") then table.insert(list, ch) end
			end
		end
		return list
	end

	local function isToolFavorited(tool, packId, favMap)
		if tool and tool:GetAttribute("Favorited") == true then return true end
		return type(favMap) == "table" and favMap[packId] == true
	end

	local function getToolMutation(tool)
		local m = tool:GetAttribute("Mutation") or tool:GetAttribute("CardMutation")
		if type(m) == "string" and m ~= "" then return m end
		return nil
	end

	Helpers.MutateState = {
		mergeRunning = false,
		fuseRunning = false,
		lastInvokeAt = 0,
		requiresPad = nil,
		realtimeBound = false,
		mergeScheduled = false,
		fuseScheduled = false,
	}

	function Helpers.ResolveMutateRemote(actionKey, fallbackPath)
		local mc = getMutateConfig()
		local ns = (mc and mc.Remote and mc.Remote.Namespace) or "Mutate"
		local rName = (mc and mc.Remote and mc.Remote[actionKey]) or actionKey
		local dynPath = RP .. tostring(ns) .. "." .. tostring(rName)
		local r = Net.Get(dynPath)
		if r then return r end
		return fallbackPath and Net.Get(fallbackPath) or nil
	end

	function Helpers.GetMutateRateLimit()
		local mc = getMutateConfig()
		local base = (mc and tonumber(mc.RateLimit)) or 1.0
		return math.max(base, 0.35) + 0.12
	end

	function Helpers.WaitMutateRateLimit()
		local rl = Helpers.GetMutateRateLimit()
		local waitSec = rl - (os.clock() - (Helpers.MutateState.lastInvokeAt or 0))
		if waitSec > 0 then
			task.wait(waitSec)
		end
		Helpers.MutateState.lastInvokeAt = os.clock()
		return rl
	end

	local function getBackpackCandidates(mode) -- mode: "merge" or "fuse"
		local now = os.clock()
		local favMap = getPlayerDataKey("Favorited")
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local packsData = type(inv) == "table" and type(inv.Packs) == "table" and inv.Packs or nil
		local hasPdInventory = packsData ~= nil
		local pc = getPacksConfig()
		local mc = getMutateConfig()
		local chc = getCharacterConfig()
		local upgradesMap = (mc and type(mc.Upgrades) == "table" and mc.Upgrades) or nil
		local maxMerges = (pc and tonumber(pc.MaxMergesPerPack)) or math.huge
		local seenIds = {}
		local knownPdIds = {}
		local candidates = {}

		local function isFav(id, tool, rec)
			if type(favMap) == "table" and favMap[id] == true then return true end
			if type(rec) == "table" and (rec.Favorited == true or rec.Locked == true) then return true end
			if tool and isToolFavorited and isToolFavorited(tool, id, favMap) then return true end
			return false
		end

		local function canUpgradeMutation(rawMut)
			if rawMut == nil or rawMut == "" then return true end
			if upgradesMap then
				return upgradesMap[rawMut] ~= nil
			end
			return rawMut ~= "Mystic"
		end

		-- 1. แหล่งข้อมูลหลัก (Authoritative): PlayerData.Inventory.Packs (ตรงกับ MutateMachine ของแมพ 100%)
		if packsData then
			for _, containerName in ipairs({ "Backpack", "Placed" }) do
				local list = (type(packsData[containerName]) == "table" and packsData[containerName]) or {}
				for k, item in pairs(list) do
					local packId = (type(item) == "table" and (item.Id or item.PackId or item.UUID)) or (type(k) == "string" and #k >= 20 and k) or nil
					if type(packId) == "string" and packId ~= "" and type(item) == "table" then
						knownPdIds[packId] = true
						if not seenIds[packId] then
							local isSkip = (itemSkipUntil[mode .. ":" .. packId] or 0) > now or permSkipItems[mode .. ":" .. packId]
							if not isSkip and not isFav(packId, nil, item) and item.OpeningCommittedAt == nil then
								local isChar
								if pc and pc.IsCharacter then
									isChar = pc.IsCharacter(item)
								else
									isChar = item.Kind == "Character" or (type(item.CharacterName) == "string" and item.CharacterName ~= "") or item.ItemCategory == "Units"
								end
								local rawMut = (type(item.Mutation) == "string" and item.Mutation ~= "") and item.Mutation or nil
								local weight = (pc and pc.ClampWeight and pc.ClampWeight(item.Weight, item.Size)) or tonumber(item.Weight) or 0

								if mode == "merge" and not isChar then
									local isPath = (pc and pc.IsPathPack and pc.IsPathPack(item)) or false
									local packName = item.PackName
									local hasCfg = (not pc or not pc.Get or (type(packName) == "string" and pc.Get(packName) ~= nil))
									local mergeCount = (pc and pc.GetMergeCount and pc.GetMergeCount(item)) or tonumber(item.MergeCount) or 0
									if not isPath and type(packName) == "string" and packName ~= "" and hasCfg and mergeCount < maxMerges then
										seenIds[packId] = true
										local dispName = (pc and pc.GetDisplayName and pc.GetDisplayName(item)) or packName
										table.insert(candidates, {
											Id = packId,
											GroupKey = packName .. "|" .. tostring(rawMut or ""),
											Name = packName,
											DisplayName = dispName,
											Mutation = rawMut,
											MergeCount = mergeCount,
											Weight = weight,
											InBase = (containerName == "Placed"),
											Raw = item,
										})
									end
								elseif mode == "fuse" and isChar then
									local charName = item.CharacterName
									local hasCharCfg = (not chc or not chc.Get or (type(charName) == "string" and chc.Get(charName) ~= nil))
									if type(charName) == "string" and charName ~= "" and hasCharCfg and canUpgradeMutation(rawMut) then
										seenIds[packId] = true
										local dispName = (chc and chc.GetDisplayName and chc.GetDisplayName(charName)) or charName
										table.insert(candidates, {
											Id = packId,
											GroupKey = charName .. (rawMut and ("|" .. rawMut) or ""),
											Name = charName,
											DisplayName = dispName,
											Mutation = rawMut,
											Weight = weight,
											Kind = "Character",
											InBase = (containerName == "Placed"),
											Raw = item,
										})
									end
								end
							end
						end
					end
				end
			end
		end

		-- 2. สแกนโค้ชแบบไดนามิกจาก CoachConfig.DataKey สำหรับ mode == "fuse" (ตรงกับ MutateMachine ของแมพ)
		if mode == "fuse" then
			local cu = getCoachUtil()
			local cc = getCoachConfig()
			local coachKey = (cc and cc.DataKey) or "Coaches"
			local coachData = getPlayerDataKey(coachKey)
			if cu and cu.GetItems and type(coachData) == "table" then
				local coachItems = cu.GetItems(coachData)
				for _, item in ipairs(coachItems) do
					local cId = item.Id
					if type(cId) == "string" and cId ~= "" and not seenIds[cId] then
						local isSkip = (itemSkipUntil[mode .. ":" .. cId] or 0) > now or permSkipItems[mode .. ":" .. cId]
						local canMut = cu.CanMutate and cu.CanMutate(item.CoachId)
						if not isSkip and canMut then
							local dispName = (cu.GetDisplayName and cu.GetDisplayName(item.CoachId))
								or (cu.Get and cu.Get(item.CoachId) and cu.Get(item.CoachId).Name)
								or tostring(item.CoachId)
							seenIds[cId] = true
							table.insert(candidates, {
								Id = cId,
								GroupKey = "Coach:" .. tostring(item.CoachId),
								Name = tostring(item.CoachId),
								DisplayName = dispName,
								Mutation = item.Mutation,
								Weight = 0,
								Kind = "Coach",
								CoachId = item.CoachId,
								InBase = false,
								Raw = item,
							})
						end
					end
				end
			end
		end

		-- 3. Fallback สแกนจาก Tools ใน Backpack / Character เฉพาะกรณีข้อมูลไม่อยู่ใน PlayerData
		for _, tool in ipairs(getBagTools(true)) do
			local packId = tool:GetAttribute("PackId")
			if type(packId) == "string" and packId ~= "" and not knownPdIds[packId] and not seenIds[packId] then
				local isSkip = (itemSkipUntil[mode .. ":" .. packId] or 0) > now or permSkipItems[mode .. ":" .. packId]
				if not isSkip and not isFav(packId, tool, nil) then
					local itemCat = tool:GetAttribute("ItemCategory")
					local cardIsPack = tool:GetAttribute("CardIsPack")
					local charName = tool:GetAttribute("CharacterName")
					local isUnit = (itemCat == "Units") or (cardIsPack == false) or (type(charName) == "string" and charName ~= "")
					local isPack = not isUnit and (cardIsPack == true or itemCat == "Packs" or itemCat == "Pack")
					local rawMut = tool:GetAttribute("Mutation")
					if type(rawMut) ~= "string" or rawMut == "" then rawMut = nil end
					local weight = tonumber(tool:GetAttribute("SortWeight")) or 0

					if mode == "merge" and isPack and not hasPdInventory then
						local name = tool:GetAttribute("PackName") or tool:GetAttribute("ItemName") or tool.Name
						local mergeCount = tonumber(tool:GetAttribute("MergeCount")) or 0
						if type(name) == "string" and name ~= "" and mergeCount < maxMerges then
							seenIds[packId] = true
							table.insert(candidates, {
								Id = packId,
								GroupKey = name .. "|" .. tostring(rawMut or ""),
								Name = name,
								DisplayName = name,
								Mutation = rawMut,
								MergeCount = mergeCount,
								Weight = weight,
								InBase = false,
								Raw = tool,
							})
						end
					elseif mode == "fuse" and isUnit then
						local name = (type(charName) == "string" and charName ~= "" and charName) or tool.Name
						if type(name) == "string" and name ~= "" and canUpgradeMutation(rawMut) then
							seenIds[packId] = true
							table.insert(candidates, {
								Id = packId,
								GroupKey = name .. (rawMut and ("|" .. rawMut) or ""),
								Name = name,
								DisplayName = name,
								Mutation = rawMut,
								Weight = weight,
								Kind = "Character",
								InBase = false,
								Raw = tool,
							})
						end
					end
				end
			end
		end

		return candidates
	end
	Helpers.GetMutateCandidates = getBackpackCandidates

	function Helpers.GetMutateGroups(mode)
		local mc = getMutateConfig()
		local minCount
		if mode == "merge" then
			minCount = (mc and mc.Merge and type(mc.Merge.Slots) == "table" and math.max(#mc.Merge.Slots, 2)) or 2
		else
			minCount = math.max((mc and tonumber(mc.Slots)) or 3, 2)
		end

		local candidates = getBackpackCandidates(mode)
		local groupMap = {}
		for _, c in ipairs(candidates) do
			local key = c.GroupKey or (tostring(c.Name or "") .. "|" .. tostring(c.Mutation or ""))
			local g = groupMap[key]
			if not g then
				g = {
					key = key,
					name = c.Name or "",
					displayName = c.DisplayName or c.Name or "",
					mut = c.Mutation,
					kind = c.Kind,
					list = {},
				}
				groupMap[key] = g
			end
			table.insert(g.list, c)
		end

		local eligible = {}
		for _, g in pairs(groupMap) do
			if #g.list >= minCount then
				table.sort(g.list, function(a, b)
					local wa, wb = tonumber(a.Weight) or 0, tonumber(b.Weight) or 0
					if wa ~= wb then return wa > wb end
					return (a.InBase and 1 or 0) > (b.InBase and 1 or 0)
				end)
				table.insert(eligible, g)
			end
		end

		table.sort(eligible, function(a, b)
			local wa = (a.list[1] and tonumber(a.list[1].Weight)) or 0
			local wb = (b.list[1] and tonumber(b.list[1].Weight)) or 0
			if wa ~= wb then return wa > wb end
			return #a.list > #b.list
		end)

		return eligible, minCount
	end

	function Helpers.HasReadyMerges()
		local groups = Helpers.GetMutateGroups("merge")
		return #groups > 0
	end

	function Helpers.HasReadyFuses()
		local groups = Helpers.GetMutateGroups("fuse")
		return #groups > 0
	end

	-- (ระบบ openReadyPlacedPacks และ placePacksInBase ถูกย้ายไปอยู่หลัง autoFuseStep เพื่อให้เรียกใช้ autoMergeStep ได้อย่างสมบูรณ์)

	local function autoEquipBestStep(manual)
		local pc = getPacksConfig()
		local cd = (pc and pc.Placement and pc.Placement.EquipBestCooldownSeconds) or 2
		local now = os.clock()
		if not manual and (now - lastEquipBest < math.max(cd, 2)) then return end
		lastEquipBest = now

		local ok, res = Net.Invoke(Net.Paths.PacksEquipBest, {})
		local success, reason = isRemoteOk(res)
		if ok and success and type(res) == "table" then
			local equipped = tonumber(res.Equipped) or 0
			local changed = tonumber(res.Changed) or 0
			if res.Reason == "NO_CHANGES" then
				if manual then
					logAction("EquipBest", "ใส่ตัวดีสุดครบอยู่แล้ว (" .. tostring(equipped) .. " ตัว)", true)
				end
			elseif changed > 0 then
				logAction("EquipBest", "เปลี่ยนใส่ตัวดีสุดใหม่ " .. tostring(changed) .. " ตัว (รวม " .. tostring(equipped) .. ")", true)
			else
				logAction("EquipBest", "สวมใส่ตัวดีสุดสำเร็จ (" .. tostring(equipped) .. " ตัว)", true)
			end
		elseif ok and reason then
			logAction("EquipBest", "ไม่สำเร็จ: " .. tostring(reason), false)
		end
	end

	local function autoSellUnitsStep()
		local now = os.clock()
		if now - lastSell < 0.6 then return end

		local favMap = getPlayerDataKey("Favorited")
		local threshold = Core.Flags.SellBelowRarity or 6
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local bpRecords = inv and inv.Packs and inv.Packs.Backpack or {}

		local toSell = {}
		local namesToSell = {}
		local seen = {}

		-- สแกนจาก Tools ใน Backpack
		for _, tool in ipairs(getBagTools(false)) do
			local packId = tool:GetAttribute("PackId")
			if tool:GetAttribute("CardIsPack") == false
				and tool:GetAttribute("ItemCategory") == "Units"
				and type(packId) == "string" and packId ~= ""
				and (itemSkipUntil[packId] or 0) <= now
				and not isToolFavorited(tool, packId, favMap)
				and not seen[packId]
			then
				local mut = getToolMutation(tool)
				if not (Core.Flags.KeepMutated and mut ~= nil) then
					local sr = tonumber(tool:GetAttribute("SortRarity")) or 0
					if sr > 0 and sr < threshold then
						seen[packId] = true
						table.insert(toSell, packId)
						table.insert(namesToSell, tool.Name)
						if #toSell >= 15 then break end
					end
				end
			end
		end

		-- สแกนจาก Inventory.Packs.Backpack เผื่อ Tool ยังไม่โหลด
		if #toSell == 0 and type(bpRecords) == "table" then
			local pc = getPacksConfig()
			local ranks = (Helpers.GetAllRarityRanks and Helpers.GetAllRarityRanks()) or (pc and pc.RarityRank) or {
				Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5,
				Mythical = 6, Cosmic = 7, Divine = 8, Omniversal = 9, Eternal = 10,
				Primordial = 11, Exclusive = 12, Godlike = 13, Absolute = 14,
				Secret = 15, Mystery = 15, ["???"] = 15,
			}
			for _, rec in ipairs(bpRecords) do
				if type(rec) == "table" and type(rec.Id) == "string" and not seen[rec.Id] then
					local packId = rec.Id
					local isChar = (pc and pc.IsCharacter and pc.IsCharacter(rec)) or rec.Kind == "Character"
					if isChar and (itemSkipUntil[packId] or 0) <= now and not (type(favMap) == "table" and favMap[packId] == true) then
						local hasMut = rec.Mutation and rec.Mutation ~= ""
						if not (Core.Flags.KeepMutated and hasMut) then
							local rName = rec.Rarity or "Common"
							local rRank = ranks[rName] or 1
							if rRank < threshold then
								seen[packId] = true
								table.insert(toSell, packId)
								table.insert(namesToSell, rec.CharacterName or rec.PackName or "Unit")
								if #toSell >= 15 then break end
							end
						end
					end
				end
			end
		end

		if #toSell > 0 then
			lastSell = now
			local ok, res = Net.Invoke(Net.Paths.EconomySellItems, toSell)
			local success, reason = isRemoteOk(res)
			if ok and success then
				local count = #toSell
				local sample = namesToSell[1] or "ยูนิต"
				if count == 1 then
					logAction("ขายยูนิต", "ขาย " .. sample .. " สำเร็จ", true)
				else
					logAction("ขายยูนิต", string.format("ขาย %d ชิ้น (%s...) สำเร็จ", count, sample), true)
				end
			else
				for _, id in ipairs(toSell) do
					itemSkipUntil[id] = now + 12
				end
				if ok and reason then
					logAction("ขายยูนิต", "ขายพลาด: " .. tostring(reason), false)
				end
			end
		end
	end

	function Helpers.MutateState.NormReason(reason)
		return string.upper(tostring(reason or "")):gsub("[^A-Z0-9]", "")
	end

	function Helpers.MutateState.IsRateLimit(nr)
		return nr:find("RATELIMIT") ~= nil or nr:find("SLOWDOWN") ~= nil or nr:find("COOLDOWN") ~= nil
	end

	function Helpers.MutateState.IsMachineProximity(nr)
		return nr:find("USEMACHINE") ~= nil
			or nr:find("MACHINE") ~= nil
			or nr:find("PAD") ~= nil
			or nr:find("NEAR") ~= nil
			or nr:find("TOOFAR") ~= nil
			or nr:find("RANGE") ~= nil
			or nr:find("DIST") ~= nil
	end

	function Helpers.MutateState.IsGenericReject(nr)
		return nr == "" or nr == "FAILED" or nr == "REJECTED" or nr == "NIL"
	end

	autoMergeStep = function(forceMulti)
		if not Core._alive then return 0 end
		if Helpers.MutateState.mergeRunning then return 0 end
		if (not forceMulti and Core.Busy) or Helpers.IsCarrying() then return 0 end

		local char = LocalPlayer.Character
		if not Helpers.IsAlive() or (char and char:GetAttribute("Ragdolled") == true) then
			return 0
		end

		local preGroups = Helpers.GetMutateGroups("merge")
		if #preGroups == 0 then return 0 end

		Helpers.MutateState.mergeRunning = true
		local totalMergedOverall = 0

		local okAllRun, errAllRun = pcall(function()
			local pc = getPacksConfig()
			local mergeAllRemote = Helpers.ResolveMutateRemote("MergeAll", Net.Paths.MutateMergeAll)
			local mergeRemote = Helpers.ResolveMutateRemote("Merge", Net.Paths.MutateMerge)
			local rateRetries = 0

			local function runMergePasses(onPad)
				local mergedHere = 0
				local passCount = 0

				while Core._alive and (Core.Flags.AutoMerge or Core.Flags.AutoPlacePacks or forceMulti) and passCount < 15 do
					if Helpers.IsCarrying() or not Helpers.IsAlive() then break end
					passCount = passCount + 1

					local eligibleGroups, minCount = Helpers.GetMutateGroups("merge")
					if #eligibleGroups == 0 then
						return mergedHere, "DONE"
					end

					lastMerge = os.clock()
					local passMerged = 0
					local retryPass = false

					for _, g in ipairs(eligibleGroups) do
						if not Core._alive then break end
						local list = g.list
						local pName = g.displayName or g.name
						local firstItem = list[1]
						local groupHandled = false

						-- นับจำนวนที่อยู่ใน Backpack (Mutate.MergeAll รวมเฉพาะ Backpack + ตัวแรกที่เลือกตาม MutateMachine)
						local bpCount = 0
						local hasMergeableBp = false
						for idx = 1, #list do
							if not list[idx].InBase then
								bpCount = bpCount + 1
								if idx > 1 then
									if pc and pc.CanMerge and type(firstItem.Raw) == "table" and type(list[idx].Raw) == "table" then
										if pc.CanMerge(firstItem.Raw, list[idx].Raw) then
											hasMergeableBp = true
										end
									else
										hasMergeableBp = true
									end
								end
							end
						end
						local mergeAllEligible = bpCount + ((firstItem and firstItem.InBase) and 1 or 0)

						-- 1. ใช้ Mutate.MergeAll เมื่อมีแพ็คใน Backpack ที่รวมกับตัวแรกได้ (ลดจำนวน RPC เหลือครั้งเดียวต่อกลุ่ม)
						if firstItem and mergeAllRemote and mergeAllEligible >= minCount and hasMergeableBp then
							local rl = Helpers.WaitMutateRateLimit()
							local okAll, resAll = Net.Invoke(mergeAllRemote, firstItem.Id)
							local sAll, rAll = isRemoteOk(resAll)
							if okAll and sAll then
								local mCnt = (type(resAll) == "table" and tonumber(resAll.Count)) or mergeAllEligible
								mergedHere = mergedHere + math.max(mCnt - 1, 1)
								passMerged = passMerged + 1
								for _, item in ipairs(list) do
									itemSkipUntil["merge:" .. item.Id] = nil
								end
								logAction("Merge", string.format("รวมกลุ่ม %s สำเร็จ (%d ชิ้น)", tostring(pName), mCnt), true)
								groupHandled = true
								break -- สแกน PlayerData ใหม่ทันทีหลังรวมสำเร็จ
							else
								local failAll = (not okAll and resAll) or rAll
								local nr = Helpers.MutateState.NormReason(failAll)
								if Helpers.MutateState.IsRateLimit(nr) then
									rateRetries = rateRetries + 1
									if rateRetries <= 3 then
										task.wait(rl)
										retryPass = true
									end
									groupHandled = true
									break
								elseif nr == "TIMEOUT" then
									itemSkipUntil["merge:" .. firstItem.Id] = os.clock() + 5
									logAction("Merge", "รวมกลุ่ม " .. tostring(pName) .. " หมดเวลา (TIMEOUT)", false)
									groupHandled = true
								elseif not onPad and (Helpers.MutateState.IsMachineProximity(nr) or Helpers.MutateState.IsGenericReject(nr)) then
									return mergedHere, "NEED_MACHINE"
								elseif nr:find("MERGELIMIT") or nr:find("PATHPACK") then
									for _, item in ipairs(list) do
										permSkipItems["merge:" .. item.Id] = true
									end
									logAction("Merge", tostring(pName) .. " ข้ามกลุ่ม (" .. tostring(failAll) .. ")", false)
									groupHandled = true
								elseif nr:find("NOTHINGTOMERGE") then
									-- ให้ fallback ไปรวมแบบคู่ด้านล่าง (กรณีมีแพ็คใน Placed)
								else
									itemSkipUntil["merge:" .. firstItem.Id] = os.clock() + 5
									logAction("Merge", "รวมกลุ่ม " .. tostring(pName) .. " พลาด: " .. tostring(failAll or "REJECTED"), false)
									groupHandled = true
								end
							end
						end

						-- 2. รวมทีละชุดด้วย Mutate.Merge ({ id1, id2, ... }) ตามจำนวนสล็อตจริงของแมพ
						if not groupHandled and #list >= minCount then
							local picked = { firstItem }
							for idx = 2, #list do
								if #picked >= minCount then break end
								local cand = list[idx]
								local validPair = true
								if pc and pc.CanMerge and type(firstItem.Raw) == "table" and type(cand.Raw) == "table" then
									local canOk = pc.CanMerge(firstItem.Raw, cand.Raw)
									if not canOk then validPair = false end
								end
								if validPair then
									table.insert(picked, cand)
								end
							end

							if #picked >= minCount then
								local payloadIds = {}
								for _, item in ipairs(picked) do
									table.insert(payloadIds, item.Id)
								end

								local rl = Helpers.WaitMutateRateLimit()
								local okPair, resPair = false, nil
								local sPair, rPair = false, nil

								if mergeRemote then
									okPair, resPair = Net.Invoke(mergeRemote, payloadIds)
									sPair, rPair = isRemoteOk(resPair)
								elseif Net.Paths.PacksMerge and #payloadIds >= 2 then
									okPair, resPair = Net.Invoke(Net.Paths.PacksMerge, {
										SourcePackId = payloadIds[1],
										TargetPackId = payloadIds[2],
									})
									sPair, rPair = isRemoteOk(resPair)
								end

								if okPair and sPair then
									mergedHere = mergedHere + 1
									passMerged = passMerged + 1
									for _, id in ipairs(payloadIds) do
										itemSkipUntil["merge:" .. id] = nil
									end
									logAction("Merge", string.format("รวม %s สำเร็จ (+1 คู่)", tostring(pName)), true)
									break -- สแกน PlayerData ใหม่ทันทีเพื่อให้แพ็คที่รวมแล้วต่อยอดรวมซ้ำได้
								else
									local failPair = (not okPair and resPair) or rPair
									local nr = Helpers.MutateState.NormReason(failPair)
									if Helpers.MutateState.IsRateLimit(nr) then
										rateRetries = rateRetries + 1
										if rateRetries <= 3 then
											task.wait(rl)
											retryPass = true
										end
										break
									elseif nr == "TIMEOUT" then
										for _, id in ipairs(payloadIds) do
											itemSkipUntil["merge:" .. id] = os.clock() + 5
										end
										logAction("Merge", "รวม " .. tostring(pName) .. " หมดเวลา (TIMEOUT)", false)
									elseif not onPad and (Helpers.MutateState.IsMachineProximity(nr) or Helpers.MutateState.IsGenericReject(nr)) then
										return mergedHere, "NEED_MACHINE"
									elseif nr:find("MERGELIMIT") or nr:find("PATHPACK") then
										for _, id in ipairs(payloadIds) do
											permSkipItems["merge:" .. id] = true
										end
										logAction("Merge", tostring(pName) .. " ข้าม (" .. tostring(failPair) .. ")", false)
									else
										for _, id in ipairs(payloadIds) do
											itemSkipUntil["merge:" .. id] = os.clock() + 6
										end
										logAction("Merge", "รวม " .. tostring(pName) .. " พลาด: " .. tostring(failPair or "REJECTED"), false)
									end
								end
							end
						end
					end

					if passMerged == 0 and not retryPass then
						break
					end
					task.wait(0.25)
				end

				return mergedHere, "DONE"
			end

			local atMachine = Helpers.IsAtMutateMachine and Helpers.IsAtMutateMachine() or false
			if Helpers.MutateState.requiresPad == true and not atMachine and Helpers.VisitMutateMachine then
				local okVisit, visitCount = Helpers.VisitMutateMachine(function()
					local c = runMergePasses(true)
					return c or 0
				end, forceMulti == true)
				if okVisit and type(visitCount) == "number" then
					totalMergedOverall = totalMergedOverall + visitCount
				end
			else
				local directCount, directStatus = runMergePasses(atMachine)
				totalMergedOverall = totalMergedOverall + (directCount or 0)
				if directStatus == "NEED_MACHINE" and not atMachine and Helpers.VisitMutateMachine then
					local okVisit, visitCount = Helpers.VisitMutateMachine(function()
						local c = runMergePasses(true)
						return c or 0
					end, forceMulti == true)
					if okVisit and type(visitCount) == "number" then
						totalMergedOverall = totalMergedOverall + visitCount
						if visitCount > 0 then
							Helpers.MutateState.requiresPad = true
						end
					end
				end
			end
		end)

		Helpers.MutateState.mergeRunning = false
		if not okAllRun then
			warn("[Kuy] autoMergeStep: " .. tostring(errAllRun))
		end

		if totalMergedOverall > 0 then
			logAction("Merge", string.format("รวมแพ็คซ้ำทั้งหมดสำเร็จ %d ครั้ง", totalMergedOverall), true)
		end
		return totalMergedOverall
	end

	local function autoFuseStep(ignoreBusy)
		if not Core._alive then return 0 end
		if Helpers.MutateState.fuseRunning then return 0 end
		if (not ignoreBusy and Core.Busy) or Helpers.IsCarrying() then return 0 end

		local char = LocalPlayer.Character
		if not Helpers.IsAlive() or (char and char:GetAttribute("Ragdolled") == true) then
			return 0
		end

		local preGroups = Helpers.GetMutateGroups("fuse")
		if #preGroups == 0 then return 0 end

		Helpers.MutateState.fuseRunning = true
		local totalFusedOverall = 0

		local okAllRun, errAllRun = pcall(function()
			local fuseRemote = Helpers.ResolveMutateRemote("Fuse", Net.Paths.MutateFuse)
			if not fuseRemote then return end
			local rateRetries = 0

			local function runFusePasses(onPad)
				local fusedHere = 0
				local passCount = 0

				-- ลูป Multi-Pass สแกนสดทุกครั้ง: รองรับการต่อยอด Mutation หลายขั้น (Normal->Gold->Emerald...) และอัปเดต Coach ID แบบเรียลไทม์
				while Core._alive and (Core.Flags.AutoFuse or ignoreBusy) and passCount < 25 do
					if Helpers.IsCarrying() or not Helpers.IsAlive() then break end
					passCount = passCount + 1

					local eligibleGroups, minCount = Helpers.GetMutateGroups("fuse")
					if #eligibleGroups == 0 then
						return fusedHere, "DONE"
					end

					lastFuse = os.clock()
					local passFused = 0
					local retryPass = false

					for _, g in ipairs(eligibleGroups) do
						if not (Core._alive and (Core.Flags.AutoFuse or ignoreBusy)) then break end
						if #g.list >= minCount then
							local payloadIds = {}
							for idx = 1, minCount do
								table.insert(payloadIds, g.list[idx].Id)
							end
							local cName = g.displayName or g.name
							local isCoachGroup = (g.kind == "Coach")

							local rl = Helpers.WaitMutateRateLimit()
							local okFuse, resFuse = Net.Invoke(fuseRemote, payloadIds)
							local sFuse, rFuse = isRemoteOk(resFuse)

							if okFuse and sFuse then
								fusedHere = fusedHere + 1
								passFused = passFused + 1
								for _, id in ipairs(payloadIds) do
									itemSkipUntil["fuse:" .. id] = nil
								end
								local mutResult = (type(resFuse) == "table" and ((resFuse.Coach and resFuse.Coach.Mutation) or (resFuse.Character and resFuse.Character.Mutation))) or "สำเร็จ"
								logAction("Fuse", string.format("กลายพันธุ์ %s สำเร็จ! (%s)", tostring(cName), tostring(mutResult)), true)
								break -- สแกน PlayerData ใหม่ทันทีเพื่อให้ผลกลายพันธุ์ต่อยอดขั้นถัดไปและ Coach ID สดเสมอ
							else
								local failFuse = (not okFuse and resFuse) or rFuse
								local nr = Helpers.MutateState.NormReason(failFuse)
								if Helpers.MutateState.IsRateLimit(nr) then
									rateRetries = rateRetries + 1
									if rateRetries <= 3 then
										task.wait(rl)
										retryPass = true
									end
									break
								elseif nr == "TIMEOUT" then
									for _, id in ipairs(payloadIds) do
										itemSkipUntil["fuse:" .. id] = os.clock() + 5
									end
									logAction("Fuse", "กลายพันธุ์ " .. tostring(cName) .. " หมดเวลา (TIMEOUT)", false)
								elseif not onPad and (Helpers.MutateState.IsMachineProximity(nr) or Helpers.MutateState.IsGenericReject(nr)) then
									return fusedHere, "NEED_MACHINE"
								elseif nr:find("MAXMUTATION") or nr:find("ALREADYMAX") or nr:find("ALREADYMUTATED") then
									for _, id in ipairs(payloadIds) do
										if isCoachGroup then
											itemSkipUntil["fuse:" .. id] = os.clock() + 15
										else
											permSkipItems["fuse:" .. id] = true
										end
									end
									logAction("Fuse", tostring(cName) .. " ถึงระดับกลายพันธุ์สูงสุดแล้ว", false)
								else
									for _, id in ipairs(payloadIds) do
										itemSkipUntil["fuse:" .. id] = os.clock() + 6
									end
									logAction("Fuse", "กลายพันธุ์ " .. tostring(cName) .. " พลาด: " .. tostring(failFuse or "REJECTED"), false)
								end
							end
						end
					end

					if passFused == 0 and not retryPass then
						break
					end
					task.wait(0.25)
				end

				return fusedHere, "DONE"
			end

			local atMachine = Helpers.IsAtMutateMachine and Helpers.IsAtMutateMachine() or false
			if Helpers.MutateState.requiresPad == true and not atMachine and Helpers.VisitMutateMachine then
				local okVisit, visitCount = Helpers.VisitMutateMachine(function()
					local c = runFusePasses(true)
					return c or 0
				end, ignoreBusy == true)
				if okVisit and type(visitCount) == "number" then
					totalFusedOverall = totalFusedOverall + visitCount
				end
			else
				local directCount, directStatus = runFusePasses(atMachine)
				totalFusedOverall = totalFusedOverall + (directCount or 0)
				if directStatus == "NEED_MACHINE" and not atMachine and Helpers.VisitMutateMachine then
					local okVisit, visitCount = Helpers.VisitMutateMachine(function()
						local c = runFusePasses(true)
						return c or 0
					end, ignoreBusy == true)
					if okVisit and type(visitCount) == "number" then
						totalFusedOverall = totalFusedOverall + visitCount
						if visitCount > 0 then
							Helpers.MutateState.requiresPad = true
						end
					end
				end
			end
		end)

		Helpers.MutateState.fuseRunning = false
		if not okAllRun then
			warn("[Kuy] autoFuseStep: " .. tostring(errAllRun))
		end

		if totalFusedOverall > 0 then
			logAction("Fuse", string.format("กลายพันธุ์สำเร็จทั้งหมด %d ชุด", totalFusedOverall), true)
			if autoEquipBestStep then
				task.spawn(function()
					task.wait(0.5)
					autoEquipBestStep(false)
				end)
			end
			if equipBestCoach then
				task.spawn(function()
					task.wait(0.5)
					equipBestCoach()
				end)
			end
		end
		return totalFusedOverall
	end
	Helpers.AutoFuseStep = autoFuseStep

	openReadyPlacedPacks = function()
		local now = os.clock()
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local placed = inv and inv.Packs and inv.Packs.Placed
		local pc = getPacksConfig()
		local sTime = Workspace:GetServerTimeNow()

		if type(placed) == "table" then
			for _, rec in pairs(placed) do
				if not Core._alive then return end
				if type(rec) == "table" and type(rec.Id) == "string" then
					local isChar = (pc and pc.IsCharacter and pc.IsCharacter(rec)) or rec.Kind == "Character" or rec.CharacterName ~= nil or rec.ItemCategory == "Units"
					local isGrowingPack = type(rec.GrowthEndsAt) == "number" and rec.GrowthEndsAt > 0
					if not isChar and isGrowingPack and rec.GrowthEndsAt <= sTime then
						if (itemSkipUntil[rec.Id] or 0) <= now then
							local ok, res = Net.Invoke(Net.Paths.OpenOwned, rec.Id)
							local success, reason = isRemoteOk(res)
							if ok and success then
								Net.Fire(Net.Paths.PacksOpened, nil, rec.Id)
								local name = rec.PackName or "Pack"
								logAction("เปิดแพ็ก", "ฟักสำเร็จ: " .. tostring(name), true)
								baseFullUntil = 0
								if autoEquipBestStep then
									task.spawn(function()
										task.wait(0.3)
										autoEquipBestStep(false)
									end)
								end
								task.wait(0.2)
							else
								itemSkipUntil[rec.Id] = now + 4
								if ok and reason and reason ~= "NOT_READY" then
									logAction("เปิดแพ็ก", "ยังไม่พร้อม (" .. tostring(reason) .. ")", false)
								end
							end
						end
					end
				end
			end
		end
	end

	getPacksToPlace = function()
		local now = os.clock()
		local packs = {}
		local seen = {}
		local pc = getPacksConfig()

		-- 1. Tools ใน Character / Backpack
		for _, tool in ipairs(getBagTools(true)) do
			local packId = tool:GetAttribute("PackId")
			local itemCat = tool:GetAttribute("ItemCategory")
			local cardIsPack = tool:GetAttribute("CardIsPack")
			local charName = tool:GetAttribute("CharacterName")

			-- กรองยูนิตตัวละครออก: หากเป็น Units หรือ CardIsPack เป็น false หรือมี CharacterName ห้ามนำมาวางเด็ดขาด
			local isUnit = (itemCat == "Units") or (cardIsPack == false) or (charName ~= nil)
			local isPack = not isUnit and (cardIsPack == true or itemCat == "Packs" or (type(packId) == "string" and packId ~= ""))

			if isPack and type(packId) == "string" and packId ~= "" and not seen[packId] then
				if (itemSkipUntil["place:" .. packId] or 0) <= now then
					seen[packId] = true
					local name = tool:GetAttribute("PackName") or tool.Name
					table.insert(packs, {
						Id = packId,
						Name = name,
						Tool = tool,
					})
				end
			end
		end

		-- 2. PlayerData Inventory Backpack (กรณี Tool ยังไม่แสดงใน Workspace)
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local bpRecords = inv and inv.Packs and inv.Packs.Backpack
		if type(bpRecords) == "table" then
			for _, rec in pairs(bpRecords) do
				if type(rec) == "table" and type(rec.Id) == "string" and not seen[rec.Id] then
					local isChar = (pc and pc.IsCharacter and pc.IsCharacter(rec)) or rec.Kind == "Character" or rec.CharacterName ~= nil
					local isPath = (pc and pc.IsPathPack and pc.IsPathPack(rec))
					if not isChar and not isPath and rec.OpeningCommittedAt == nil then
						if (itemSkipUntil["place:" .. rec.Id] or 0) <= now then
							seen[rec.Id] = true
							table.insert(packs, {
								Id = rec.Id,
								Name = rec.PackName or rec.Name or "Pack",
							})
						end
					end
				end
			end
		end

		return packs
	end

	local isPlacingPacks = false
	placePacksInBase = function()
		if not Core._alive then return false end
		if not Core.Flags.AutoPlacePacks then return false end
		if isBaseFull() then return false, "BASE_FULL" end
		if isPlacingPacks then return false end
		isPlacingPacks = true
		local prevBusy = Core.Busy
		Core.Busy = true

		local okRun, ret = pcall(function()
			-- รอให้แพ็กที่เพิ่งได้รับซิงก์เข้ากระเป๋าสักครู่
			task.wait(0.15)

			-- 1. ตรวจสอบจำนวนแพ็คจริงในกระเป๋าก่อน หากไม่มีแพ็คให้จบฟังก์ชันทันที (ไม่เดิน ไม่รวม ไม่วาง)
			local packs = getPacksToPlace()
			if #packs == 0 then
				return true
			end

			-- ถ้าเปิด AutoOpenPacks ให้ฟักแพ็กที่โตเต็มวัยก่อนเพื่อเคลียร์พื้นที่ว่าง
			if Core.Flags.AutoOpenPacks then
				openReadyPlacedPacks()
			end

			-- หากมีแพ็คในกระเป๋าตั้งแต่ 2 ชิ้นขึ้นไป ให้รวมแพ็คซ้ำทั้งหมดให้เรียบร้อยก่อนนำไปวางที่ฐาน
			if #packs >= 2 and (Core.Flags.AutoMerge or Core.Flags.AutoPlacePacks) and autoMergeStep then
				pcall(function() autoMergeStep(true) end)
				packs = getPacksToPlace()
				if #packs == 0 then
					return true
				end
			end

			local plot = Helpers.GetPlot()
			local pu = getPlotUtil()
			local area = (pu and plot and pu.GetAnimeArea and pu.GetAnimeArea(plot.Name))
				or (plot and plot:FindFirstChild("PlotModel") and plot.PlotModel:FindFirstChild("AnimeArea"))
			local basePos = area and Helpers.GetPosition(area) or Helpers.GetPlotSpawnPos()
			if not basePos then
				return false, "ไม่พบพื้นที่ฐาน"
			end

			local placementUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.PlacementUtil end)
			local char = LocalPlayer.Character
			local hrp = Helpers.GetRoot()
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local wasTraining = LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil

			-- เดินเข้าสู่พื้นที่ AnimeArea ด้วย MoveTo (ไม่เทเลพอร์ต กัน MovementGrace และไม่ชนกับลูปขโมย)
			if area and area:IsA("BasePart") and hrp then
				local areaCenter = area.Position + Vector3.new(0, 3.5, 0)
				if (hrp.Position - area.Position).Magnitude > (area.Size.X * 0.45) then
					if wasTraining and Helpers.LeaveTreadmill then
						pcall(Helpers.LeaveTreadmill)
						task.wait(0.1)
					end
					Helpers.MoveTo(areaCenter, function()
						return not Core._alive or not Core.Flags.AutoPlacePacks or Helpers.IsCarrying()
					end, { precise = true, arriveDist = 6, evadeEnemies = false })
					task.wait(0.15)
				end
			end

			local halfX, halfZ = 16, 12
			if area and area:IsA("BasePart") then
				halfX = math.max((area.Size.X - 4) / 2, 8)
				halfZ = math.max((area.Size.Z - 4) / 2, 8)
			end

			local noSpace = false
			local loopPass = 0

			while Core._alive and Core.Flags.AutoPlacePacks and not noSpace do
				loopPass = loopPass + 1
				if loopPass > 15 then break end

				local currentPacks = getPacksToPlace()
				if #currentPacks == 0 then
					break
				end

				-- ถ้าเปิด AutoOpenPacks ให้ฟักแพ็กที่โตเต็มวัยระหว่างลูปเพื่อเคลียร์พื้นที่ว่าง
				if Core.Flags.AutoOpenPacks and openReadyPlacedPacks then
					pcall(openReadyPlacedPacks)
				end

				local placedAnyInPass = false

				for _, pack in ipairs(currentPacks) do
					if not Core._alive or not (Core.Flags.AutoSteal or Core.Flags.AutoPlacePacks) or noSpace then break end
					local packId = pack.Id
					local packName = pack.Name or "Pack"
					local placedThis = false
					local lastReason = nil

					-- ค้นหา Tool ของแพ็กชิ้นนี้
					char = LocalPlayer.Character
					hum = char and char:FindFirstChildOfClass("Humanoid")
					local bp = LocalPlayer:FindFirstChild("Backpack")
					local packTool = pack.Tool
					if not (packTool and packTool.Parent) then
						packTool = (char and char:FindFirstChild(packName)) or (bp and bp:FindFirstChild(packName))
					end
					if not (packTool and packTool:GetAttribute("PackId") == packId) then
						if bp then
							for _, t in ipairs(bp:GetChildren()) do
								if t:IsA("Tool") and t:GetAttribute("PackId") == packId then
									packTool = t
									break
								end
							end
						end
						if not packTool and char then
							for _, t in ipairs(char:GetChildren()) do
								if t:IsA("Tool") and t:GetAttribute("PackId") == packId then
									packTool = t
									break
								end
							end
						end
					end

					-- สวมใส่ Tool เข้าร่างกายตัวละคร (เซิร์ฟเวอร์บังคับว่าต้องถือ Tool ก่อนวาง)
					if hum and packTool then
						if packTool.Parent ~= char then
							pcall(function() hum:EquipTool(packTool) end)
							local tEquipDeadline = os.clock() + 0.3
							while os.clock() < tEquipDeadline and packTool.Parent ~= char do
								RunService.Heartbeat:Wait()
							end
						end
						pcall(function()
							Net.Fire(Net.Paths.ToolsRequestEquip, nil, {
								Equipped = true,
								Tool = packTool
							})
						end)
						task.wait(0.06)
					end

					-- คำนวณระดับความสูงพื้นแปลงเพาะ (AnimeArea.Position.Y + ครึ่งความหนา + 0.3 studs ตาม PlacementLiftStuds)
					local surfaceY = (area and area:IsA("BasePart") and (area.Position.Y + (area.Size.Y * 0.5) + 0.3)) or (basePos.Y + 0.3)

					-- สร้างรายการพิกัดแบบตารางกริด (Jittered Grid) ทั่วแปลงเพาะ เพื่อตัดปัญหาชนแพ็คเดิม (OVERLAPS_PACK)
					local gridCandidates = {}
					local step = 3.2
					for gx = -halfX + 2, halfX - 2, step do
						for gz = -halfZ + 2, halfZ - 2, step do
							local jx = gx + (math.random() - 0.5) * 1.2
							local jz = gz + (math.random() - 0.5) * 1.2
							table.insert(gridCandidates, Vector2.new(jx, jz))
						end
					end
					-- สับเปลี่ยนลำดับเพื่อกระจายแพ็คทั่วแปลง
					for k = #gridCandidates, 2, -1 do
						local j = math.random(k)
						gridCandidates[k], gridCandidates[j] = gridCandidates[j], gridCandidates[k]
					end

					-- พยายามวางตามจุดในตารางกริด (ลองสูงสุด 6 จุดเพื่อความเร็ว)
					for attempt = 1, math.min(6, #gridCandidates) do
						local pt2d = gridCandidates[attempt]
						local placePos
						if area and area:IsA("BasePart") then
							local worldPt = area.CFrame:PointToWorldSpace(Vector3.new(pt2d.X, 0, pt2d.Y))
							placePos = Vector3.new(worldPt.X, surfaceY, worldPt.Z)
						else
							placePos = Vector3.new(basePos.X + pt2d.X, surfaceY, basePos.Z + pt2d.Y)
						end

						local ok, res = Net.Invoke(Net.Paths.PlaceOwned, {
							PackId = packId,
							Position = placePos,
						})
						local success, reason = isRemoteOk(res)
						if ok and success then
							placedThis = true
							placedAnyInPass = true
							logAction("วางแพ็ก", "นำลงเพาะในแปลง: " .. tostring(packName), true)
							itemSkipUntil["place:" .. packId] = nil
							task.wait(0.12)
							break
						else
							lastReason = reason or "FAILED"
							if reason == "NOT_OWNED" or reason == "ALREADY_PLACED" then
								placedThis = true
								placedAnyInPass = true
								break
							elseif reason == "NOT_EQUIPPED" then
								if hum and packTool then
									pcall(function() hum:EquipTool(packTool) end)
									task.wait(0.12)
								end
							elseif isFullReason(reason) then
								noSpace = true
								break
							end
							task.wait(0.04)
						end
					end

					if not placedThis then
						if isFullReason(lastReason) or noSpace then
							noSpace = true
							baseFullUntil = os.clock() + 10
							itemSkipUntil["place:" .. packId] = os.clock() + 10
							logAction("วางแพ็ก", "ฐานไม่มีที่ว่างสำหรับวาง " .. tostring(packName) .. " (" .. tostring(lastReason) .. ")", false)
							break
						elseif lastReason == "OVERLAPS_PACK" then
							itemSkipUntil["place:" .. packId] = os.clock() + 15
							logAction("วางแพ็ก", "พิกัดวางชนแพ็คอื่น: " .. tostring(packName) .. " (จะลองใหม่ภายหลัง)", false)
						else
							itemSkipUntil["place:" .. packId] = os.clock() + 15
							logAction("วางแพ็ก", "วางไม่สำเร็จ: " .. tostring(packName) .. " (" .. tostring(lastReason) .. ")", false)
						end
					end
				end

				if noSpace or not placedAnyInPass then
					break
				end
				task.wait(0.15)
			end

			-- ปลดการถือ Tool เมื่อวางเสร็จสิ้นทั้งหมด (ไม่วาปกลับ origCF)
			char = LocalPlayer.Character
			hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then pcall(function() hum:UnequipTools() end) end

			if wasTraining and Core.Flags.AutoEnter and not Core.Flags.AutoSteal and enterTreadmill and Helpers.IsAlive() and not Helpers.IsCarrying() then
				task.spawn(function()
					task.wait(0.3)
					if not Core.Busy and not Core.Flags.AutoSteal then
						pcall(enterTreadmill)
					end
				end)
			end

			if noSpace then
				baseFullUntil = os.clock() + 10
				logAction("วางแพ็ก", "ไม่มีที่วางในฐานแล้ว -> รอแพ็คฟักเพื่อเปิดพื้นที่", false)
				return false, "NO_SPACE"
			end

			return true
		end)

		if not prevBusy then
			Core.Busy = false
		end
		isPlacingPacks = false
		return okRun and ret
	end

	local function autoOpenPacksStep()
		if not Core._alive then return end
		-- ฟัก/เปิดแพ็กที่พร้อมเปิดบนฐานตลอดเวลา (รีโมททำงานได้จากทุกจุด ไม่กระทบการเดินหรือขโมย)
		if openReadyPlacedPacks then
			pcall(openReadyPlacedPacks)
		end
		-- หากไม่ได้เปิด AutoSteal หรือไม่ได้กำลังแบกแพ็ค ให้จัดการนำแพ็คในกระเป๋าไปวางบนฐานด้วย (Throttled ทุก 3.0s ไม่ให้เช็คบ่อยเกินไป)
		local now = os.clock()
		if not Core.Flags.AutoSteal and not Helpers.IsCarrying() and not Core.Busy and (now - lastIdleMaintenance >= 3.0) then
			lastIdleMaintenance = now
			if runBaseMaintenance then
				pcall(runBaseMaintenance)
			end
		end
	end

	function Loops.PlacePacks()
		isPlacingPacks = false
		Core:Loop("placePacks", "AutoPlacePacks", 1.5, function()
			-- ห้ามรันซ้อนขณะ AutoSteal เปิดอยู่หรือ Core.Busy ถูกล็อก (เมื่อเปิด AutoSteal ระบบ runBaseMaintenance จะสั่งวางให้ตามคิว)
			if Core.Busy or Helpers.IsCarrying() or Core.Flags.AutoSteal then return end
			if not isBaseFull() and getPacksToPlace and #getPacksToPlace() > 0 then
				if placePacksInBase then placePacksInBase() end
			end
		end)
	end

	function Loops.OpenPacks()
		task.spawn(autoOpenPacksStep)
		Core:Loop("openPacks", "AutoOpenPacks", 0.6, autoOpenPacksStep)
	end

	function Loops.EquipBest()
		task.spawn(function() autoEquipBestStep(true) end)
		Core:Loop("equipBest", "AutoEquipBest", 3, autoEquipBestStep)
	end

	function Loops.Sell()
		task.spawn(autoSellUnitsStep)
		Core:Loop("sellUnits", "AutoSellUnits", 0.8, autoSellUnitsStep)
	end

	function Helpers.ScheduleRealtimeMutate(wantMerge, wantFuse)
		if not Core._alive then return end
		if wantMerge and Core.Flags.AutoMerge and not Helpers.MutateState.mergeScheduled then
			Helpers.MutateState.mergeScheduled = true
			task.delay(0.25, function()
				Helpers.MutateState.mergeScheduled = false
				if not (Core._alive and Core.Flags.AutoMerge) then return end
				if Helpers.IsCarrying() or Core.Busy then return end
				if autoMergeStep then
					pcall(autoMergeStep, false)
				end
			end)
		end
		if wantFuse and Core.Flags.AutoFuse and not Helpers.MutateState.fuseScheduled then
			Helpers.MutateState.fuseScheduled = true
			task.delay(0.3, function()
				Helpers.MutateState.fuseScheduled = false
				if not (Core._alive and Core.Flags.AutoFuse) then return end
				if Helpers.IsCarrying() or Core.Busy then return end
				if autoFuseStep then
					pcall(autoFuseStep, false)
				end
			end)
		end
	end

	function Helpers.EnsureMutateRealtime()
		if Helpers.MutateState.realtimeBound then return end
		Helpers.MutateState.realtimeBound = true

		-- 1. ดักการเปลี่ยนแปลง Inventory และ Coaches แบบเรียลไทม์ผ่าน PlayerData.Subscribe (ตรงกับ MutateMachine)
		local pd = getPlayerData()
		if pd and pd.Subscribe then
			local cc = getCoachConfig()
			local coachKey = (cc and cc.DataKey) or "Coaches"

			local okInv, subInv = pcall(pd.Subscribe, "Inventory", function()
				Helpers.ScheduleRealtimeMutate(true, true)
			end)
			if okInv and type(subInv) == "table" and type(subInv.Disconnect) == "function" then
				table.insert(Core._cleanups, function() pcall(subInv.Disconnect) end)
			end

			local okCoach, subCoach = pcall(pd.Subscribe, coachKey, function()
				Helpers.ScheduleRealtimeMutate(false, true)
			end)
			if okCoach and type(subCoach) == "table" and type(subCoach.Disconnect) == "function" then
				table.insert(Core._cleanups, function() pcall(subCoach.Disconnect) end)
			end
		end

		-- 2. ดัก Tool ใหม่ใน Backpack แบบเรียลไทม์ (รองรับการรีสปอนของ Backpack)
		local function bindBackpack(bp)
			if not bp then return end
			Core:Connect(bp.ChildAdded, function(ch)
				if ch:IsA("Tool") and ch:GetAttribute("PackId") ~= nil then
					Helpers.ScheduleRealtimeMutate(true, true)
				end
			end)
		end
		bindBackpack(LocalPlayer:FindFirstChild("Backpack"))
		Core:Connect(LocalPlayer.ChildAdded, function(ch)
			if ch:IsA("Backpack") then
				bindBackpack(ch)
			end
		end)

		-- 3. ล้างแคชแท่น MutateMachine อัตโนมัติหากแมพมีการโหลด/ย้ายเครื่องใหม่
		local function checkPadRefresh(ch)
			local mc = getMutateConfig()
			local rootName = (mc and mc.Machine and type(mc.Machine.Pad) == "table" and mc.Machine.Pad[1]) or "Machine2"
			if ch.Name == rootName or ch.Name == "MutationMachine" or ch.Name == "MergeMachine" then
				Helpers.mutatePadCache = nil
			end
		end
		Core:Connect(Workspace.ChildAdded, checkPadRefresh)
		Core:Connect(Workspace.ChildRemoved, checkPadRefresh)
	end

	function Loops.Merge()
		Helpers.EnsureMutateRealtime()
		task.spawn(function()
			if Core._alive and Core.Flags.AutoMerge and not Helpers.IsCarrying() and not Core.Busy and autoMergeStep then
				pcall(autoMergeStep, false)
			end
		end)
		Core:Loop("mergePacks", "AutoMerge", 2.0, function()
			if Helpers.IsCarrying() then return end
			if not Core.Busy and autoMergeStep then
				autoMergeStep(false)
			end
		end)
	end

	function Loops.Fuse()
		Helpers.EnsureMutateRealtime()
		task.spawn(function()
			if Core._alive and Core.Flags.AutoFuse and not Helpers.IsCarrying() and not Core.Busy and autoFuseStep then
				pcall(autoFuseStep, false)
			end
		end)
		Core:Loop("fuseUnits", "AutoFuse", 1.8, function()
			if Helpers.IsCarrying() then return end
			if not Core.Busy and autoFuseStep then
				autoFuseStep(false)
			end
		end)
	end

	-----------------------------------------------------------------
	-- 5.7. FEATURE: UPGRADES, REBIRTH, CLAIMS & ANTI-AFK
	-----------------------------------------------------------------
	local UpgState = {
		nextTmUpgrade = 0,
		nextBaseUpgrade = 0,
		lastRebirthTry = 0,
		nextOfflineClaim = 0,
		nextDailyClaim = 0,
		nextIndexClaim = 0,
		nextLuckUpgrade = 0,
	}

	local function autoUpgradeTreadmillStep()
		local now = os.clock()
		if now < UpgState.nextTmUpgrade then return end

		local tc = getTreadmillConfig()
		local pd = getPlayerData()
		local curLvl = pd and pd.Get and pd.Get(tc and tc.Upgrade and tc.Upgrade.DataName or "TreadmillLevel")
		local normLvl = tc and tc.NormalizeLevelName and tc.NormalizeLevelName(curLvl)
		local nextPrice = tc and tc.GetPriceForNextLevel and tc.GetPriceForNextLevel(normLvl)

		if nextPrice == nil then
			-- เลเวลตันแล้ว หยุดตรวจเป็นเวลานาน
			UpgState.nextTmUpgrade = now + 60
			return
		end

		local cash = getPlayerCash()
		if cash < nextPrice then
			-- เงินยังไม่พอ ไม่ยิงคำสั่ง ป้องกันเซิร์ฟเวอร์ส่ง Toast Notification แจ้งเตือนเงินไม่พอรัวๆ
			UpgState.nextTmUpgrade = now + 4
			return
		end

		local ok, res = Net.Invoke(Net.Paths.TreadmillUpgrade, {})
		local success, reason = isRemoteOk(res)
		if ok and success then
			UpgState.nextTmUpgrade = now + 1.0
			logAction("อัปเกรด", "อัปเกรดลู่วิ่งสำเร็จ (Level: " .. tostring(res and res.LevelName or "Next") .. ")", true)
		else
			UpgState.nextTmUpgrade = now + 5
			if ok and reason and reason ~= "NOT_ENOUGH_CASH" then
				logAction("อัปเกรด", "ลู่วิ่ง: " .. tostring(reason), false)
			end
		end
	end

	local function autoUpgradeBaseStep()
		local now = os.clock()
		if now < UpgState.nextBaseUpgrade then return end

		local bc = getBaseUpgradeConfig()
		local pd = getPlayerData()
		local curLvl = pd and pd.Get and pd.Get("BaseUpgradeLevel")
		local normLvl = bc and bc.NormalizeLevel and bc.NormalizeLevel(curLvl)
		local nextPrice = bc and bc.GetPriceForNextLevel and bc.GetPriceForNextLevel(normLvl)

		if nextPrice == nil then
			-- เลเวลตันแล้ว หยุดตรวจเป็นเวลานาน
			UpgState.nextBaseUpgrade = now + 60
			return
		end

		local cash = getPlayerCash()
		if cash < nextPrice then
			-- เงินยังไม่พอ ไม่ยิงคำสั่ง ป้องกันเซิร์ฟเวอร์ส่ง Toast Notification แจ้งเตือนเงินไม่พอรัวๆ
			UpgState.nextBaseUpgrade = now + 4
			return
		end

		local ok, res = Net.Invoke(Net.Paths.BaseUpgradePurchase, {})
		local success, reason = isRemoteOk(res)
		if ok and success then
			UpgState.nextBaseUpgrade = now + 1.0
			logAction("อัปเกรด", "อัปเกรดฐานสำเร็จ (Level: " .. tostring(res and res.Level or "Next") .. ")", true)
		else
			UpgState.nextBaseUpgrade = now + 5
			if ok and reason and reason ~= "NOT_ENOUGH_CASH" then
				logAction("อัปเกรด", "ฐาน: " .. tostring(reason), false)
			end
		end
	end

	local function autoUpgradeLuckStep()
		local now = os.clock()
		if now < UpgState.nextLuckUpgrade then return end

		local lmc = getLuckMachineConfig()
		local curLvl = tonumber(LocalPlayer:GetAttribute("HatchLuckLevel")) or 0
		local nextPrice = lmc and lmc.GetPrice and lmc.GetPrice(curLvl)

		if nextPrice == nil then
			-- เลเวลตันแล้ว หยุดตรวจเป็นเวลานาน
			UpgState.nextLuckUpgrade = now + 60
			return
		end

		local cash = getPlayerCash()
		if cash < nextPrice then
			-- เงินยังไม่พอ ไม่ยิงคำสั่ง ป้องกันเซิร์ฟเวอร์ส่ง Toast Notification แจ้งเตือนเงินไม่พอรัวๆ
			UpgState.nextLuckUpgrade = now + 4
			return
		end

		local ok, res = Net.Invoke(Net.Paths.LuckMachineUpgrade, "Max")
		local success, reason = isRemoteOk(res)
		if ok and success then
			UpgState.nextLuckUpgrade = now + 1.0
			local newLvl = tonumber(LocalPlayer:GetAttribute("HatchLuckLevel")) or (curLvl + 1)
			logAction("อัปเกรด", "อัปเกรดเครื่องโชคสำเร็จ (Level: " .. tostring(newLvl) .. ")", true)
		else
			UpgState.nextLuckUpgrade = now + 5
			if ok and reason and reason ~= "NOT_ENOUGH_CASH" then
				logAction("อัปเกรด", "เครื่องโชค: " .. tostring(reason), false)
			end
		end
	end

	local function autoRebirthStep()
		local now = os.clock()
		if now - UpgState.lastRebirthTry < 3 then return end
		local ru = getRebirthUtil()
		if not (ru and ru.GetCount and ru.GetRequirement) then return end

		local count = ru.GetCount(LocalPlayer)
		local spd = tonumber(getPlayerDataKey("Speed")) or 0
		local needed = ru.GetRequirement(count)
		if needed and spd >= needed then
			UpgState.lastRebirthTry = now
			local ok, res = Net.Invoke(Net.Paths.RebirthRequest)
			local success, reason = isRemoteOk(res)
			if ok and success then
				logAction("Rebirth", "เกิดใหม่สำเร็จ (#" .. tostring((count or 0) + 1) .. ")", true)
			elseif ok and reason then
				logAction("Rebirth", "Rebirth พลาด: " .. tostring(reason), false)
			end
		end
	end

	local function autoClaimStep()
		local now = os.clock()
		if now >= UpgState.nextOfflineClaim then
			local pending = getPlayerDataKey("PendingEarnings")
			local lastOff = getPlayerDataKey("LastOfflineReward")
			local hasOffline = (type(pending) == "table" and ((tonumber(pending.Cash) or 0) > 0 or (tonumber(pending.Diamonds) or 0) > 0))
				or (type(lastOff) == "table" and (tonumber(lastOff.Cash) or 0) > 0)
			if hasOffline then
				UpgState.nextOfflineClaim = now + 15
				local ok, res = Net.Invoke(Net.Paths.OfflineClaim)
				if ok and isRemoteOk(res) then
					logAction("เคลม", "เคลม Offline สำเร็จ", true)
				end
				return
			end
			UpgState.nextOfflineClaim = now + 10
		end

		if now >= UpgState.nextDailyClaim then
			local dru = getDailyRewardsUtil()
			local dailyData = getPlayerDataKey("DailyRewards")
			if dru and dru.GetState and type(dailyData) == "table" then
				local okSt, st = pcall(dru.GetState, dailyData, Workspace:GetServerTimeNow())
				if okSt and type(st) == "table" and st.CanClaim then
					UpgState.nextDailyClaim = now + 20
					local ok, res = Net.Invoke(Net.Paths.DailyClaim)
					if ok and isRemoteOk(res) then
						logAction("เคลม", "เคลม Daily สำเร็จ", true)
					end
					return
				end
			end
			UpgState.nextDailyClaim = now + 15
		end

		if now >= UpgState.nextIndexClaim then
			local idx = getPlayerDataKey("Index")
			local hasUnclaimed = false
			if type(idx) == "table" and type(idx.Unlocked) == "table" then
				local claimed = type(idx.Claimed) == "table" and idx.Claimed or {}
				for k in pairs(idx.Unlocked) do
					if not claimed[k] then
						hasUnclaimed = true
						break
					end
				end
			end
			if hasUnclaimed then
				UpgState.nextIndexClaim = now + 25
				local mutationKeys = { "", "Gold", "Emerald", "Diamond", "Cursed", "Transcendent", "Glitched" }
				local seenMut = {}
				for _, mk in ipairs(mutationKeys) do seenMut[mk] = true end
				pcall(function()
					local mc = getMutateConfig()
					if type(mc) == "table" then
						for _, tbl in pairs({ mc.Mutations, mc.Order, mc.Config, mc }) do
							if type(tbl) == "table" then
								for k, v in pairs(tbl) do
									local mName = (type(v) == "string" and v) or (type(k) == "string" and type(v) == "table" and (v.Name or k)) or nil
									if type(mName) == "string" and #mName > 1 and not seenMut[mName] and mName ~= "Mutations" and mName ~= "Order" then
										seenMut[mName] = true
										table.insert(mutationKeys, mName)
									end
								end
							end
						end
					end
				end)
				local totalClaimed = 0

				-- 1. เคลมแบบรวมทั้งหมด (Batch ClaimAll)
				for _, mKey in ipairs(mutationKeys) do
					local mutArg = (mKey ~= "" and mKey) or nil
					local ok, success, reason, count = Net.Invoke(Net.Paths.IndexClaimReward, nil, nil, mutArg)
					if ok and (success == true or isRemoteOk(success)) then
						local num = tonumber(count) or 1
						totalClaimed = totalClaimed + num
					end
					task.wait(0.1)
				end

				-- 2. เคลมรายตัวที่เหลือตกค้างผ่าน IndexConfig.IsClaimable (Precision Fallback)
				local ic = getIndexConfig()
				idx = getPlayerDataKey("Index") or idx
				if ic and ic.GetStages and ic.IsClaimable and type(idx) == "table" then
					local stages = ic.GetStages()
					for _, st in ipairs(stages) do
						for _, entry in ipairs(st.Characters or {}) do
							for _, mKey in ipairs(mutationKeys) do
								local mutArg = (mKey ~= "" and mKey) or nil
								if ic.IsClaimable(idx, entry, mutArg) then
									local ok, success = Net.Invoke(Net.Paths.IndexClaimReward, entry.StageName, entry.Name, mutArg)
									if ok and (success == true or isRemoteOk(success)) then
										totalClaimed = totalClaimed + 1
										idx = getPlayerDataKey("Index") or idx
									end
									task.wait(0.08)
								end
							end
						end
					end
				end

				if totalClaimed > 0 then
					logAction("เคลม", string.format("เคลม Index Rewards สำเร็จ (+%d รายการ)", totalClaimed), true)
				end
			else
				UpgState.nextIndexClaim = now + 20
			end
		end
	end

	function Loops.UpgradeTreadmill()
		Core:Loop("upgTreadmill", "AutoUpgradeTreadmill", 0.5, autoUpgradeTreadmillStep)
	end

	function Loops.UpgradeBase()
		Core:Loop("upgBase", "AutoUpgradeBase", 0.5, autoUpgradeBaseStep)
	end

	function Loops.UpgradeLuck()
		Core:Loop("upgLuck", "AutoUpgradeLuck", 0.5, autoUpgradeLuckStep)
	end

	function Loops.Rebirth()
		Core:Loop("autoRebirth", "AutoRebirth", 1.5, autoRebirthStep)
	end

	function Loops.Claim()
		Core:Loop("autoClaim", "AutoClaim", 2, autoClaimStep)
	end

	function Loops.Dungeon()
		Core:StopLoop("autoDungeon")
		Core._loops["autoDungeon"] = task.spawn(function()
			while Core._alive and (Helpers.IsDungeonPlace() or Core.Flags.AutoEnterDungeon or Core.Flags.DungeonFloorLoop) do
				local ok, err = pcall(Helpers.AutoDungeonStep)
				if not ok then
					warn("[Kuy] loop 'autoDungeon': " .. tostring(err))
				end
				task.wait(Helpers.IsDungeonPlace() and 1.2 or 2.5)
			end
			Core._loops["autoDungeon"] = nil
		end)
	end

	Core:Connect(LocalPlayer.Idled, function()
		if Core._alive and Core.Flags.AntiAfk and VirtualUser then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end)

	-- ดักจับการแจ้งเตือนจากเซิร์ฟเวอร์ (เช่น "พื้นที่ของคุณเต็มแล้ว") เพื่อตั้ง baseFullUntil ทันที
	pcall(function()
		local notifRemote = Helpers.ResolvePath("ReplicatedStorage.Remotes.Notification.Notification")
		if notifRemote and notifRemote:IsA("RemoteEvent") then
			Core:Connect(notifRemote.OnClientEvent, function(...)
				local args = table.pack(...)
				for i = 1, args.n do
					local val = args[i]
					local txt = ""
					if typeof(val) == "string" then
						txt = val
					elseif typeof(val) == "table" then
						txt = tostring(val.Text or val.Message or val.Title or val.Reason or "")
					end
					if isFullReason(txt) then
						baseFullUntil = os.clock() + 60
						logAction("ฐาน", "ตรวจพบแจ้งเตือน: " .. txt .. " (ฐานเต็ม - พักบนลู่วิ่งรอแพ็คฟัก)", false)
						break
					end
				end
			end)
		end
	end)

	pcall(function()
		local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if pgui then
			Core:Connect(pgui.DescendantAdded, function(desc)
				if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and isFullReason(desc.Text) then
					baseFullUntil = os.clock() + 60
				end
			end)
		end
	end)

	-----------------------------------------------------------------
	-- 6. UI CREATION (KUYKUY HUB UI FRAMEWORK - DARK PURPLE BLUEPRINT)
	-----------------------------------------------------------------
	local function buildUI()
		Core.Flags.UI = true
		local UIColors = {
			Background    = Color3.fromRGB(18, 15, 26),
			Sidebar       = Color3.fromRGB(13, 11, 20),
			Content       = Color3.fromRGB(24, 20, 36),
			Card          = Color3.fromRGB(32, 27, 48),
			CardHover     = Color3.fromRGB(42, 36, 62),
			Accent        = Color3.fromRGB(155, 89, 230), -- #9B59E6
			AccentLight   = Color3.fromRGB(180, 120, 255), -- #B478FF
			TextPrimary   = Color3.fromRGB(245, 240, 255), -- #F5F0FF
			TextSecondary = Color3.fromRGB(160, 150, 180), -- #A096B4
			Border        = Color3.fromRGB(48, 40, 70),   -- #302846
			Success       = Color3.fromRGB(46, 204, 113),  -- #2ECC71
			Danger        = Color3.fromRGB(231, 76, 60),   -- #E74C3C
			Warning       = Color3.fromRGB(241, 196, 15),  -- #F1C40F
			Gold          = Color3.fromRGB(255, 205, 70),  -- #FFCD46
			Cyan          = Color3.fromRGB(0, 210, 255),   -- #00D2FF
		}

		-- ล้าง UI เก่าถ้ามีอยู่ (ครอบ pcall ป้องกัน Executor ที่จำกัดสิทธิ์ CoreGui)
		local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		local hui = nil
		if gethui then
			local okH, resH = pcall(gethui)
			if okH then hui = resH end
		end
		local uiRoots = {}
		if hui then table.insert(uiRoots, hui) end
		if CoreGui then table.insert(uiRoots, CoreGui) end
		if pgui then table.insert(uiRoots, pgui) end
		for _, root in ipairs(uiRoots) do
			if root then
				for _, uiName in ipairs({ "KUYKUY_ScreenGui", "KuykuyHub" }) do
					pcall(function()
						local old = root:FindFirstChild(uiName)
						if old then old:Destroy() end
					end)
				end
			end
		end

		local ScreenGui = Instance.new("ScreenGui")
		ScreenGui.Name = "KUYKUY_ScreenGui"
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
		Core:OnCleanup(function() pcall(function() ScreenGui:Destroy() end) end)

		-- Floating Action Button (ปุ่มลอยการ์ตูนควาย 52x52 px)
		local FloatButton = Instance.new("TextButton")
		FloatButton.Name = "KUYKUY_FloatButton"
		FloatButton.Size = UDim2.new(0, 52, 0, 52)
		FloatButton.Position = UDim2.new(0, 25, 0.35, 0)
		FloatButton.BackgroundColor3 = UIColors.Card
		FloatButton.Text = "🐃"
		FloatButton.TextSize = 28
		FloatButton.AutoButtonColor = false
		FloatButton.Parent = ScreenGui

		local FloatCorner = Instance.new("UICorner")
		FloatCorner.CornerRadius = UDim.new(1, 0)
		FloatCorner.Parent = FloatButton

		local FloatStroke = Instance.new("UIStroke")
		FloatStroke.Color = UIColors.Gold
		FloatStroke.Thickness = 2.2
		FloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		FloatStroke.Parent = FloatButton

		local BuffaloIcon = Instance.new("ImageLabel")
		BuffaloIcon.Name = "BuffaloIcon"
		BuffaloIcon.Size = UDim2.new(1, -6, 1, -6)
		BuffaloIcon.Position = UDim2.new(0, 3, 0, 3)
		BuffaloIcon.BackgroundTransparency = 1
		BuffaloIcon.Image = "rbxassetid://15264624467"
		BuffaloIcon.ScaleType = Enum.ScaleType.Fit
		BuffaloIcon.ZIndex = FloatButton.ZIndex + 1
		BuffaloIcon.Parent = FloatButton

		task.delay(1.5, function()
			if BuffaloIcon and BuffaloIcon.IsLoaded then
				FloatButton.Text = ""
			end
		end)

		-- MainFrame (570 x 430 px)
		local MainFrame = Instance.new("Frame")
		MainFrame.Name = "MainFrame"
		MainFrame.Size = UDim2.new(0, 570, 0, 430)
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
		MainStroke.Color = UIColors.Border
		MainStroke.Thickness = 1.2
		MainStroke.Parent = MainFrame

		-- Header (42 px)
		local Header = Instance.new("Frame")
		Header.Name = "Header"
		Header.Size = UDim2.new(1, 0, 0, 42)
		Header.BackgroundColor3 = UIColors.Sidebar
		Header.BorderSizePixel = 0
		Header.Parent = MainFrame

		local TitleLabel = Instance.new("TextLabel")
		TitleLabel.Size = UDim2.new(0, 450, 1, 0)
		TitleLabel.Position = UDim2.new(0, 16, 0, 0)
		TitleLabel.BackgroundTransparency = 1
		TitleLabel.Font = Enum.Font.GothamBold
		TitleLabel.TextSize = 14
		TitleLabel.TextColor3 = UIColors.TextPrimary
		TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		TitleLabel.RichText = true
		TitleLabel.Text = "KUYKUY HUB <font color=\"#B478FF\">ขโมยแพ็คอนิเมะ v3.2.0</font>"
		TitleLabel.Parent = Header

		local CloseBtn = Instance.new("TextButton")
		CloseBtn.Size = UDim2.new(0, 28, 0, 28)
		CloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
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
		Sidebar.Size = UDim2.new(0, 145, 1, -42)
		Sidebar.Position = UDim2.new(0, 0, 0, 42)
		Sidebar.BackgroundColor3 = UIColors.Sidebar
		Sidebar.BorderSizePixel = 0
		Sidebar.ScrollBarThickness = 2
		Sidebar.ScrollBarImageColor3 = UIColors.Border
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
		ContentFrame.BackgroundColor3 = UIColors.Content
		ContentFrame.BorderSizePixel = 0
		ContentFrame.Parent = MainFrame

		-- Status Bar (24 px)
		local StatusBar = Instance.new("Frame")
		StatusBar.Name = "StatusBar"
		StatusBar.Size = UDim2.new(1, -145, 0, 24)
		StatusBar.Position = UDim2.new(0, 145, 1, -24)
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
		StatusText.Text = "STATUS: ACTIVE | สคริปต์พร้อมทำงาน"
		StatusText.Parent = StatusBar

		-- Draggable System (Touch & Mouse Compatible)
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

		-- Window Toggle & Minimize Animation
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
			btn.TextColor3 = isDefault and UIColors.TextPrimary or UIColors.TextSecondary
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
					b.TextColor3 = active and UIColors.TextPrimary or UIColors.TextSecondary
				end
				if tabId == "LogsTab" and Core._updateLogUI then
					pcall(Core._updateLogUI)
				end
			end)

			TabButtons[tabId] = btn
			return btn
		end

		-- UI Component Constructors
		local function CreateToggle(parent, title, initialValue, callback)
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 40)
			card.BackgroundColor3 = UIColors.Card
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
			label.TextColor3 = UIColors.TextPrimary
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = title
			label.Parent = card

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
			knob.BackgroundColor3 = UIColors.TextPrimary
			knob.Parent = toggleTrack

			local knobCorner = Instance.new("UICorner")
			knobCorner.CornerRadius = UDim.new(1, 0)
			knobCorner.Parent = knob

			local state = (initialValue == true)
			local lastClick = 0
			local function onToggle()
				local now = tick()
				if now - lastClick < 0.25 then return end
				lastClick = now
				state = not state
				local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
				local targetColor = state and UIColors.Accent or UIColors.Sidebar
				TweenService:Create(knob, TweenInfo.new(0.2), { Position = targetPos }):Play()
				TweenService:Create(toggleTrack, TweenInfo.new(0.2), { BackgroundColor3 = targetColor }):Play()
				pcall(logAction, "สวิตช์", (state and "เปิด: " or "ปิด: ") .. title, state)
				if callback then
					local cbOk, cbErr = pcall(callback, state)
					if not cbOk then
						warn("[Kuy] toggle '" .. tostring(title) .. "': " .. tostring(cbErr))
					end
				end
				if Config and Config.Save then pcall(Config.Save) end
			end

			toggleTrack.MouseButton1Click:Connect(onToggle)
			pcall(function()
				if toggleTrack.Activated then toggleTrack.Activated:Connect(onToggle) end
			end)
		end

		local function CreateButton(parent, text, bgColor, callback)
			if type(bgColor) == "function" and callback == nil then
				callback = bgColor
				bgColor = UIColors.Card
			elseif bgColor == nil or typeof(bgColor) ~= "Color3" then
				bgColor = UIColors.Card
			end

			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 34)
			btn.BackgroundColor3 = bgColor
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 12
			btn.TextColor3 = UIColors.TextPrimary
			btn.Text = text
			btn.Parent = parent

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = btn

			local lastClick = 0
			local function onClick()
				local now = tick()
				if now - lastClick < 0.25 then return end
				lastClick = now
				if callback then callback() end
			end

			btn.MouseButton1Click:Connect(onClick)
			pcall(function()
				if btn.Activated then btn.Activated:Connect(onClick) end
			end)
			return btn
		end

		local function CreateStatusCard(parent, titleText)
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 36)
			card.BackgroundColor3 = UIColors.Sidebar
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
			label.TextColor3 = UIColors.TextPrimary
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
			card.BackgroundColor3 = UIColors.Card
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
			titleLabel.TextColor3 = UIColors.TextPrimary
			titleLabel.TextXAlignment = Enum.TextXAlignment.Left
			titleLabel.Text = title
			titleLabel.Parent = header

			local selectBtn = Instance.new("TextButton")
			selectBtn.Size = UDim2.new(0.52, -12, 0, 28)
			selectBtn.Position = UDim2.new(0.48, 0, 0.5, -14)
			selectBtn.BackgroundColor3 = UIColors.Sidebar
			selectBtn.Font = Enum.Font.GothamMedium
			selectBtn.TextSize = 11
			selectBtn.TextColor3 = UIColors.AccentLight
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
				optBtn.BackgroundColor3 = (opt == currentSelected) and UIColors.Accent or UIColors.Sidebar
				optBtn.Font = Enum.Font.GothamMedium
				optBtn.TextSize = 11
				optBtn.TextColor3 = UIColors.TextPrimary
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
							child.BackgroundColor3 = (child.Text == currentSelected) and UIColors.Accent or UIColors.Sidebar
						end
					end
					if callback then callback(opt) end
					if Config and Config.Save then Config.Save() end
				end)
			end

			return card
		end

		local function CreateMultiSelectDropdown(parent, title, options, selectedMap, callback)
			local isExpanded = false
			selectedMap = selectedMap or {}

			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 42)
			card.BackgroundColor3 = UIColors.Card
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
			titleLabel.TextColor3 = UIColors.TextPrimary
			titleLabel.TextXAlignment = Enum.TextXAlignment.Left
			titleLabel.Text = title
			titleLabel.Parent = header

			local selectBtn = Instance.new("TextButton")
			selectBtn.Size = UDim2.new(0.52, -12, 0, 28)
			selectBtn.Position = UDim2.new(0.48, 0, 0.5, -14)
			selectBtn.BackgroundColor3 = UIColors.Sidebar
			selectBtn.Font = Enum.Font.GothamMedium
			selectBtn.TextSize = 11
			selectBtn.TextColor3 = UIColors.AccentLight
			selectBtn.Parent = header

			local selectCorner = Instance.new("UICorner")
			selectCorner.CornerRadius = UDim.new(0, 4)
			selectCorner.Parent = selectBtn

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
					item.btn.BackgroundColor3 = isChecked and Color3.fromRGB(48, 38, 72) or UIColors.Sidebar
					item.btn.TextColor3 = isChecked and UIColors.TextPrimary or UIColors.TextSecondary
					item.btn.Text = (isChecked and " [✓]  " or " [  ]  ") .. item.label
				end
			end

			local function CreateQuickBtn(text, color, onClick)
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(0.31, 0, 1, 0)
				btn.BackgroundColor3 = color
				btn.Font = Enum.Font.GothamBold
				btn.TextSize = 10
				btn.TextColor3 = UIColors.TextPrimary
				btn.Text = text
				btn.Parent = quickBar

				local btnCorner = Instance.new("UICorner")
				btnCorner.CornerRadius = UDim.new(0, 4)
				btnCorner.Parent = btn

				btn.MouseButton1Click:Connect(function()
					onClick()
					RefreshUI()
					if callback then callback(selectedMap) end
					if Config and Config.Save then Config.Save() end
				end)
				return btn
			end

			CreateQuickBtn("✓ ทั้งหมด", UIColors.Accent, function()
				for _, opt in ipairs(options) do
					selectedMap[opt.value] = true
				end
			end)

			CreateQuickBtn("✕ ล้างหมด", UIColors.Danger, function()
				for _, opt in ipairs(options) do
					selectedMap[opt.value] = false
				end
			end)

			CreateQuickBtn("⇄ สลับค่า", UIColors.Warning, function()
				for _, opt in ipairs(options) do
					selectedMap[opt.value] = not (selectedMap[opt.value] == true)
				end
			end)

			local knownValues = {}
			local totalContentHeight = 26 + 4 + (#options * 30) + 12

			local function addOptionItem(i, opt)
				knownValues[opt.value] = true
				local optBtn = Instance.new("TextButton")
				optBtn.Name = "Opt_" .. string.format("%02d", i)
				optBtn.LayoutOrder = i
				optBtn.Size = UDim2.new(1, 0, 0, 26)
				optBtn.BackgroundColor3 = (selectedMap[opt.value] == true) and Color3.fromRGB(48, 38, 72) or UIColors.Sidebar
				optBtn.Font = Enum.Font.GothamMedium
				optBtn.TextSize = 11
				optBtn.TextColor3 = (selectedMap[opt.value] == true) and UIColors.TextPrimary or UIColors.TextSecondary
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
					if callback then callback(selectedMap) end
					if Config and Config.Save then Config.Save() end
				end)

				table.insert(optionButtons, { btn = optBtn, value = opt.value, label = opt.label })
			end

			for i, opt in ipairs(options) do
				addOptionItem(i, opt)
			end

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

			local function SyncOptions(newOptions)
				if type(newOptions) ~= "table" then return end
				local added = false
				for _, opt in ipairs(newOptions) do
					if opt and opt.value and not knownValues[opt.value] then
						table.insert(options, opt)
						addOptionItem(#options, opt)
						added = true
					end
				end
				if added then
					totalContentHeight = 26 + 4 + (#options * 30) + 12
					if isExpanded then
						card.Size = UDim2.new(1, 0, 0, 48 + totalContentHeight)
					end
					RefreshUI()
				end
			end

			selectBtn.MouseButton1Click:Connect(function()
				ToggleExpand()
			end)

			RefreshUI()
			return card, SyncOptions
		end

		-- =====================================================================
		-- TAB 1: 🏃 1. ฟาร์ม & ขโมย (Farm & Steal)
		-- =====================================================================
		AddTabButton("FarmTab", "🏃 1. ฟาร์ม & ขโมย", true, 1)
		local pFarm = CreateTabPage("FarmTab")
		pFarm.Visible = true

		local TreadmillStatusCard = CreateStatusCard(pFarm, "ลู่วิ่ง: กำลังโหลดสถานะ...")

		CreateToggle(pFarm, "กดคูณอัตโนมัติ (ทำคอมโบลู่วิ่ง)", Core.Flags.AutoTreadmill, function(v)
			Core.Flags.AutoTreadmill = v
			if v then
				task.spawn(function()
					if tryClickBoostPopup() then
						Stats.boosts = Stats.boosts + 1
						logAction("ลู่วิ่ง", "กดคูณสำเร็จ", true)
					end
				end)
			end
		end)

		CreateToggle(pFarm, "เดินเข้าลู่วิ่งอัตโนมัติ (Auto Treadmill)", Core.Flags.AutoEnter, function(v)
			Core.Flags.AutoEnter = v
			if v then Loops.Enter() end
		end)

		CreateToggle(pFarm, "ขโมยแพ็คอัตโนมัติ (Auto Steal Packs)", Core.Flags.AutoSteal, function(v)
			Core.Flags.AutoSteal = v
			if v then
				Loops.Steal()
			else
				Core:StopLoop("steal")
				Helpers.StopMove()
				if StealState.holdBusy then
					StealState.holdBusy = false
					Core:ReleaseBusy("steal")
				end
			end
		end)

		CreateToggle(pFarm, "ลบอนิเมชชั่นโดนตี/ไม่ล้ม (Anti-Ragdoll)", Core.Flags.AntiRagdollMode, function(v)
			Core.Flags.AntiRagdollMode = v
			if v then Helpers.RecoverFromHit(LocalPlayer.Character) end
		end)

		CreateToggle(pFarm, "ลงดันเจี้ยนอัตโนมัติเมื่อเปิด (Auto Enter Dungeon)", Core.Flags.AutoEnterDungeon, function(v)
			Core.Flags.AutoEnterDungeon = v
			if v then Loops.Dungeon() end
		end)

		CreateToggle(pFarm, "เปิดท่าไม้ตายออโต้ในดันเจี้ยน (Auto Dungeon Ultimate)", Core.Flags.AutoDungeonUlt, function(v)
			Core.Flags.AutoDungeonUlt = v
		end)

		CreateToggle(pFarm, "ออกดันเจี้ยนอัตโนมัติเมื่อจบเกม (Auto Exit Dungeon)", Core.Flags.AutoDungeonExit, function(v)
			Core.Flags.AutoDungeonExit = v
		end)

		-- โหมดรีสตาร์ทดันเจี้ยน 2 ครั้งตามชั้นที่ระบุ (Toggle + ช่องกรอกชั้น + ชั้นสูงสุดเรียลไทม์)
		CreateToggle(pFarm, "รีสตาร์ทดันเจี้ยนเมื่อถึงชั้นที่ระบุ (Restart Floor Loop)", Core.Flags.DungeonFloorLoop, function(v)
			Core.Flags.DungeonFloorLoop = v
			if v then Loops.Dungeon() end
			pcall(function() if Config and Config.Save then Config.Save() end end)
		end)

		do
			local floorFrame = Instance.new("Frame")
			floorFrame.BackgroundTransparency = 1
			floorFrame.Size = UDim2.new(1, 0, 0, 52)
			floorFrame.Parent = pFarm

			local lblFloor = Instance.new("TextLabel")
			lblFloor.BackgroundTransparency = 1
			lblFloor.Size = UDim2.new(1, -8, 0, 18)
			lblFloor.Position = UDim2.new(0, 4, 0, 0)
			lblFloor.TextColor3 = Color3.fromRGB(220, 220, 220)
			lblFloor.TextSize = 13
			lblFloor.Font = Enum.Font.GothamMedium
			lblFloor.TextXAlignment = Enum.TextXAlignment.Left
			lblFloor.Text = "🏁 ชั้นปัจจุบัน: 0 | สูงสุด: 0"
			lblFloor.Parent = floorFrame

			local box = Instance.new("TextBox")
			box.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
			box.TextColor3 = Color3.fromRGB(255, 255, 255)
			box.PlaceholderText = "ชั้น/เวฟที่ต้องการรีสตาร์ท (ใส่เลขเท่าไหร่ก็ได้)"
			box.ClearTextOnFocus = false
			box.Font = Enum.Font.GothamMedium
			box.TextSize = 13
			box.Size = UDim2.new(1, -8, 0, 26)
			box.Position = UDim2.new(0, 4, 0, 22)
			box.Text = tostring(Core.Flags.DungeonTargetFloor or 500)
			box.Parent = floorFrame
			Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

			box.FocusLost:Connect(function()
				local n = tonumber(box.Text)
				if n then
					n = math.max(1, math.floor(n))
					Core.Flags.DungeonTargetFloor = n
					box.Text = tostring(n)
					pcall(function()
						if Config and Config.Save then Config.Save() end
					end)
				else
					box.Text = tostring(Core.Flags.DungeonTargetFloor or 500)
				end
			end)

			Core:Loop("dungeonFloorLabel", "UI", 0.5, function()
				if not Helpers.IsDungeonPlace() then
					lblFloor.Text = string.format("🏁 ชั้นสูงสุดรอบล่าสุด: %d", Helpers._dungeonMaxFloor or 0)
					return
				end
				local cur = Helpers.GetCurrentDungeonFloor()
				if cur > (Helpers._dungeonMaxFloor or 0) then Helpers._dungeonMaxFloor = cur end
				lblFloor.Text = string.format("🏁 ชั้นปัจจุบัน: %d | สูงสุดตอนนี้: %d", cur, Helpers._dungeonMaxFloor or 0)
			end)
		end

		CreateButton(pFarm, "⚔️ จัดทีมตัวดีสุดลงดันเจี้ยน (Equip Best Team)", UIColors.Card, function()
			Helpers.EquipBestDungeonTeam()
		end)

		CreateButton(pFarm, "🚪 ลงดันเจี้ยนทันที (Force Enter Dungeon)", UIColors.Accent, function()
			task.spawn(function()
				local ok, msg = Helpers.EnterDungeon()
				if not ok then
					logAction("ดันเจี้ยน", "ไม่สามารถเข้าดันเจี้ยนได้: " .. tostring(msg), false)
				end
			end)
		end)

		-- Stage Multi-Select Dropdown
		local function buildStageOptions()
			local list = {}
			local maxSt = (Helpers.GetMaxStage and Helpers.GetMaxStage()) or 13
			for i = 1, maxSt do
				table.insert(list, {
					value = "Stage" .. i,
					label = string.format("ด่านที่ %d (Stage %d)", i, i),
					short = tostring(i),
				})
			end
			return list
		end
		local stageOptions = buildStageOptions()
		local _, syncStageDropdown = CreateMultiSelectDropdown(pFarm, "ด่านที่ต้องการขโมย (Stages)", stageOptions, Core.Flags, function()
			StealState.lastOrderSig = ""
			StealState.lastLockedStage = nil
			StealState.lastNoPackLogTime = 0
			if Core.Flags.AutoSteal and not Core:IsLoopRunning("steal") then Loops.Steal() end
		end)

		-- Pack Rarities Multi-Select Dropdown
		local rarityOptions = (Helpers.GetRarityDropdownOptions and Helpers.GetRarityDropdownOptions()) or {
			{ value = "Rarity_Common",     label = "Common (ระดับ 1)",       short = "Com" },
			{ value = "Rarity_Uncommon",   label = "Uncommon (ระดับ 2)",     short = "Unc" },
			{ value = "Rarity_Rare",       label = "Rare (ระดับ 3)",         short = "Rare" },
			{ value = "Rarity_Epic",       label = "Epic (ระดับ 4)",         short = "Epic" },
			{ value = "Rarity_Legendary",  label = "Legendary (ระดับ 5)",    short = "Leg" },
			{ value = "Rarity_Mythical",   label = "Mythical (ระดับ 6)",     short = "Myth" },
			{ value = "Rarity_Cosmic",     label = "Cosmic (ระดับ 7)",       short = "Cos" },
			{ value = "Rarity_Divine",     label = "Divine (ระดับ 8)",       short = "Div" },
			{ value = "Rarity_Omniversal", label = "Omniversal (ระดับ 9)",   short = "Omni" },
			{ value = "Rarity_Eternal",    label = "Eternal (ระดับ 10)",     short = "Eter" },
			{ value = "Rarity_Primordial", label = "Primordial (ระดับ 11)",  short = "Prim" },
			{ value = "Rarity_Exclusive",  label = "Exclusive (ระดับ 12)",   short = "Excl" },
			{ value = "Rarity_Godlike",    label = "Godlike (ระดับ 13)",     short = "God" },
			{ value = "Rarity_Absolute",   label = "Absolute (ระดับ 14)",    short = "Abs" },
			{ value = "Rarity_Mystery",    label = "??? / Mystery (ระดับ 15)", short = "Mys" },
			{ value = "Rarity_Secret",     label = "Secret (ระดับพิเศษ)",    short = "Sec" },
		}
		local _, syncRarityDropdown = CreateMultiSelectDropdown(pFarm, "เกรดของแพ็คที่ต้องการขโมย (All Grades)", rarityOptions, Core.Flags, function()
			StealState.lastOrderSig = ""
			StealState.lastNoPackLogTime = 0
			if Core.Flags.AutoSteal and not Core:IsLoopRunning("steal") then Loops.Steal() end
		end)

		Core:Loop("dynamicUISync", "UI", 5.0, function()
			if syncStageDropdown then
				pcall(function() syncStageDropdown(buildStageOptions()) end)
			end
			if syncRarityDropdown and Helpers.GetRarityDropdownOptions then
				pcall(function() syncRarityDropdown(Helpers.GetRarityDropdownOptions()) end)
			end
		end)

		-- =====================================================================
		-- TAB 2: 📦 2. แพ็ก & ยูนิต (Packs & Units)
		-- =====================================================================
		AddTabButton("PackTab", "📦 2. แพ็ก & ยูนิต", false, 2)
		local pPack = CreateTabPage("PackTab")

		local PackStatusCard = CreateStatusCard(pPack, "แพ็ก & ยูนิต: กำลังสแกนข้อมูล...")

		CreateToggle(pPack, "เปิดแพ็กในกระเป๋าอัตโนมัติ (Auto Open)", Core.Flags.AutoOpenPacks, function(v)
			Core.Flags.AutoOpenPacks = v
			if v then Loops.OpenPacks() else Core:StopLoop("openPacks") end
		end)

		CreateToggle(pPack, "วางแพ็คในฐานอัตโนมัติ (Auto Place Packs)", Core.Flags.AutoPlacePacks, function(v)
			Core.Flags.AutoPlacePacks = v
			if v then
				Loops.PlacePacks()
			else
				Core:StopLoop("placePacks")
				isPlacingPacks = false
			end
		end)

		CreateToggle(pPack, "วางตัวดีสุดลงฐานอัตโนมัติ (EquipBest)", Core.Flags.AutoEquipBest, function(v)
			Core.Flags.AutoEquipBest = v
			if v then Loops.EquipBest() end
		end)

		CreateButton(pPack, "⭐ ใส่ตัวดีสุดลงฐานทันที (Equip Best Now)", UIColors.Accent, function()
			if autoEquipBestStep then
				autoEquipBestStep(true)
			end
		end)

		CreateToggle(pPack, "รวมแพ็กซ้ำ 2 ชิ้น (Auto Merge Packs)", Core.Flags.AutoMerge, function(v)
			Core.Flags.AutoMerge = v
			if v then Loops.Merge() end
		end)

		CreateToggle(pPack, "กลายพันธุ์ยูนิต 3 ตัว (Auto Fuse Units)", Core.Flags.AutoFuse, function(v)
			Core.Flags.AutoFuse = v
			if v then Loops.Fuse() end
		end)

		CreateToggle(pPack, "ขายยูนิตอัตโนมัติ (Auto Sell Units)", Core.Flags.AutoSellUnits, function(v)
			Core.Flags.AutoSellUnits = v
			if v then Loops.Sell() end
		end)

		CreateToggle(pPack, "เก็บตัวกลายพันธุ์ (Keep Mutated - ไม่ขาย)", Core.Flags.KeepMutated, function(v)
			Core.Flags.KeepMutated = v
		end)

		local RARITY_NAMES, rarityOptions = nil, nil
		if Helpers.GetSellRarityOptions then
			RARITY_NAMES, rarityOptions = Helpers.GetSellRarityOptions()
		end
		if not RARITY_NAMES then
			RARITY_NAMES = {
				[3] = "Rare (3)",
				[4] = "Epic (4)",
				[5] = "Legendary (5)",
				[6] = "Mythical (6)",
				[7] = "Cosmic (7)",
				[8] = "Divine (8)",
				[9] = "Omniversal (9)",
				[10] = "Eternal (10)",
				[11] = "Primordial (11)",
				[12] = "Exclusive (12)",
				[13] = "Godlike (13)",
				[14] = "Absolute (14)",
				[15] = "Mystery (15)",
			}
			rarityOptions = {
				"Rare (3)", "Epic (4)", "Legendary (5)", "Mythical (6)",
				"Cosmic (7)", "Divine (8)", "Omniversal (9)", "Eternal (10)",
				"Primordial (11)", "Exclusive (12)", "Godlike (13)", "Absolute (14)", "Mystery (15)"
			}
		end
		local curRarityVal = Core.Flags.SellBelowRarity or 6
		local curRarityText = RARITY_NAMES[curRarityVal] or "Mythical (6)"

		CreateDropdown(pPack, "ขายต่ำกว่าระดับ:", rarityOptions, curRarityText, function(selected)
			for val, name in pairs(RARITY_NAMES) do
				if name == selected then
					Core.Flags.SellBelowRarity = val
					logAction("ตั้งค่า", "ตั้งเกณฑ์ขายต่ำกว่า " .. tostring(selected))
					break
				end
			end
		end)

		-- =====================================================================
		-- TAB 3: ⚡ 3. อัปเกรด & เกิดใหม่ (Upgrades & Rebirth)
		-- =====================================================================
		AddTabButton("UpgTab", "⚡ 3. อัปเกรด", false, 3)
		local pUpg = CreateTabPage("UpgTab")

		CreateStatusCard(pUpg, "⚡ ระบบอัปเกรดโค้ช, ออร่า, ลู่วิ่ง, ฐาน และเกิดใหม่อัตโนมัติ")

		CreateToggle(pUpg, "ซื้อโค้ชที่ดีกว่าอัตโนมัติ (Auto Buy Coach)", Core.Flags.AutoBuyCoach, function(v)
			Core.Flags.AutoBuyCoach = v
			if v then Loops.BuyCoach() end
		end)

		CreateToggle(pUpg, "สวมใส่โค้ชตัวคูณสูงสุด (Equip Best Coach)", Core.Flags.AutoEquipCoach, function(v)
			Core.Flags.AutoEquipCoach = v
			if v then Loops.EquipCoach() end
		end)

		CreateToggle(pUpg, "ซื้อออร่าที่ดีกว่าอัตโนมัติ (Auto Buy Aura)", Core.Flags.AutoBuyAura, function(v)
			Core.Flags.AutoBuyAura = v
			if v then Loops.BuyAura() end
		end)

		CreateToggle(pUpg, "สวมใส่ออร่าตัวคูณสูงสุด (Equip Best Aura)", Core.Flags.AutoEquipAura, function(v)
			Core.Flags.AutoEquipAura = v
			if v then Loops.EquipAura() end
		end)

		CreateToggle(pUpg, "อัปเกรดลู่วิ่งอัตโนมัติ (Upgrade Treadmill)", Core.Flags.AutoUpgradeTreadmill, function(v)
			Core.Flags.AutoUpgradeTreadmill = v
			if v then Loops.UpgradeTreadmill() end
		end)

		CreateToggle(pUpg, "อัปเกรดฐานอัตโนมัติ (Upgrade Base)", Core.Flags.AutoUpgradeBase, function(v)
			Core.Flags.AutoUpgradeBase = v
			if v then Loops.UpgradeBase() end
		end)

		CreateToggle(pUpg, "อัปเกรดโชคในบ้านอัตโนมัติ (Upgrade Luck Machine)", Core.Flags.AutoUpgradeLuck, function(v)
			Core.Flags.AutoUpgradeLuck = v
			if v then Loops.UpgradeLuck() end
		end)

		CreateToggle(pUpg, "เกิดใหม่อัตโนมัติเมื่อครบเกณฑ์ (Auto Rebirth)", Core.Flags.AutoRebirth, function(v)
			Core.Flags.AutoRebirth = v
			if v then Loops.Rebirth() end
		end)

		CreateToggle(pUpg, "เคลม Offline / Daily / Index อัตโนมัติ", Core.Flags.AutoClaim, function(v)
			Core.Flags.AutoClaim = v
			if v then Loops.Claim() end
		end)

		CreateToggle(pUpg, "ระบบกันเตะ AFK (Anti-AFK 20 นาที)", Core.Flags.AntiAfk, function(v)
			Core.Flags.AntiAfk = v
		end)

		-- =====================================================================
		-- TAB 4: 📜 4. ประวัติ & ตั้งค่า (Logs & Config)
		-- =====================================================================
		AddTabButton("LogsTab", "📜 4. ประวัติ & ตั้งค่า", false, 4)
		local pLog = CreateTabPage("LogsTab")

		CreateButton(pLog, "💾 บันทึกค่าการใช้งาน (Save Config Now)", UIColors.Accent, function()
			if Config and Config.Save then
				local ok, src = Config.Save()
				if ok then
					logAction("ตั้งค่า", "บันทึกฟังก์ชันสำเร็จ (" .. (src == "disk" and "ลงไฟล์" or "ลงแคช") .. ")", true)
				else
					logAction("ตั้งค่า", "บันทึกไม่สำเร็จ: " .. tostring(src), false)
				end
			end
		end)

		CreateButton(pLog, "🗑️ ล้างประวัติการทำงาน (Clear Logs)", UIColors.Card, function()
			table.clear(Stats.logs)
			if Core._updateLogUI then pcall(Core._updateLogUI) end
		end)

		CreateButton(pLog, "🛑 ปิดสคริปต์ (Kill Switch / Unload)", UIColors.Danger, function()
			Core:Destroy()
		end)

		local logScroll = Instance.new("ScrollingFrame")
		logScroll.Name = "LogsScroll"
		logScroll.Size = UDim2.new(1, 0, 0, 240)
		logScroll.BackgroundColor3 = UIColors.Sidebar
		logScroll.BorderSizePixel = 0
		logScroll.ScrollBarThickness = 3
		logScroll.ScrollBarImageColor3 = UIColors.Border
		logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		logScroll.Parent = pLog

		local lsc = Instance.new("UICorner"); lsc.CornerRadius = UDim.new(0, 6); lsc.Parent = logScroll
		local lsp = Instance.new("UIPadding"); lsp.PaddingTop = UDim.new(0, 6); lsp.PaddingBottom = UDim.new(0, 6); lsp.PaddingLeft = UDim.new(0, 8); lsp.PaddingRight = UDim.new(0, 8); lsp.Parent = logScroll
		local lsl = Instance.new("UIListLayout"); lsl.SortOrder = Enum.SortOrder.LayoutOrder; lsl.Padding = UDim.new(0, 3); lsl.Parent = logScroll

		local function renderLogs()
			for _, ch in ipairs(logScroll:GetChildren()) do
				if ch:IsA("TextLabel") then ch:Destroy() end
			end
			if #Stats.logs == 0 then
				local empty = Instance.new("TextLabel")
				empty.Size = UDim2.new(1, 0, 0, 24)
				empty.BackgroundTransparency = 1
				empty.Font = Enum.Font.Gotham
				empty.TextSize = 11
				empty.TextColor3 = UIColors.TextSecondary
				empty.Text = "(ยังไม่มีบันทึกการทำงาน)"
				empty.Parent = logScroll
				return
			end
			for idx, item in ipairs(Stats.logs) do
				local row = Instance.new("TextLabel")
				row.Size = UDim2.new(1, 0, 0, 0)
				row.AutomaticSize = Enum.AutomaticSize.Y
				row.BackgroundTransparency = 1
				row.Font = Enum.Font.Gotham
				row.TextSize = 11
				row.TextWrapped = true
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.LayoutOrder = idx
				local color = UIColors.TextPrimary
				if item.ok == true then
					color = UIColors.Success
				elseif item.ok == false then
					color = UIColors.Danger
				end
				row.TextColor3 = color
				row.Text = string.format("[%s] [%s] %s", item.time, item.cat, item.msg)
				row.Parent = logScroll
			end
		end

		Core._updateLogUI = function()
			if pLog.Visible then
				renderLogs()
			end
		end

		-- Startup Loop Initialization
		if Core.Flags.AutoEnter then task.spawn(Loops.Enter) end
		if Core.Flags.AutoSteal then task.spawn(Loops.Steal) end
		if Core.Flags.AutoPlacePacks then task.spawn(Loops.PlacePacks) end
		if Core.Flags.AutoOpenPacks then task.spawn(Loops.OpenPacks) end
		if Core.Flags.AutoEquipBest then task.spawn(Loops.EquipBest) end
		if Core.Flags.AutoMerge then task.spawn(Loops.Merge) end
		if Core.Flags.AutoFuse then task.spawn(Loops.Fuse) end
		if Core.Flags.AutoSellUnits then task.spawn(Loops.Sell) end
		if Core.Flags.AutoBuyCoach then task.spawn(Loops.BuyCoach) end
		if Core.Flags.AutoEquipCoach then task.spawn(Loops.EquipCoach) end
		if Core.Flags.AutoBuyAura then task.spawn(Loops.BuyAura) end
		if Core.Flags.AutoEquipAura then task.spawn(Loops.EquipAura) end
		if Core.Flags.AutoUpgradeTreadmill then task.spawn(Loops.UpgradeTreadmill) end
		if Core.Flags.AutoUpgradeBase then task.spawn(Loops.UpgradeBase) end
		if Core.Flags.AutoUpgradeLuck then task.spawn(Loops.UpgradeLuck) end
		if Core.Flags.AutoRebirth then task.spawn(Loops.Rebirth) end
		if Core.Flags.AutoClaim then task.spawn(Loops.Claim) end
		if Helpers.IsDungeonPlace() or Core.Flags.AutoEnterDungeon then
			task.spawn(Loops.Dungeon)
		end

		Core:Loop("autoSaveConfig", "UI", 30, function()
			if Config and Config.Save then
				pcall(Config.Save)
			end
		end)

		Core:Loop("status", "UI", 0.5, function()
			-- Loop Watchdog: หากสวิตช์เปิดค้างไว้ใน UI แต่เธรดลูปหยุดไป ให้ปลุกทำงานอัตโนมัติ
			if Core.Flags.AutoSteal and not Core:IsLoopRunning("steal") then
				Loops.Steal()
			end
			if Core.Flags.AutoPlacePacks and not Core:IsLoopRunning("placePacks") then
				Loops.PlacePacks()
			end
			if Core.Flags.AutoOpenPacks and not Core:IsLoopRunning("openPacks") then
				Loops.OpenPacks()
			end
			if Helpers.IsDungeonPlace() then
				local stText = "[⚔️ DUNGEON ACTIVE] กำลังต่อสู้อัตโนมัติในดันเจี้ยน"
				StatusText.Text = "STATUS: " .. stText
				if TreadmillStatusCard then
					TreadmillStatusCard.Text = stText
				end
				if PackStatusCard then
					PackStatusCard.Text = stText
				end
				return
			end
			local combo = LocalPlayer:GetAttribute(COMBO_ATTR) or 0
			local training = LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil
			local spd = math.floor(Helpers.GetMoveSpeed() + 0.5)
			local stText = string.format(
				"ลู่วิ่ง: %s | คูณ %d | คอมโบ %s | วิ่ง %d | ขโมย: สำเร็จ %d / พลาด %d",
				training and "กำลังวิ่ง" or "ไม่ได้วิ่ง", Stats.boosts, tostring(combo), spd,
				Stats.stealOk, Stats.stealFail
			)
			StatusText.Text = "STATUS: " .. stText
			if TreadmillStatusCard then
				TreadmillStatusCard.Text = stText
			end
			if PackStatusCard then
				PackStatusCard.Text = string.format("ขโมยแพ็ค: สำเร็จ %d | พลาด %d | ล่าสุด: %s", Stats.stealOk, Stats.stealFail, tostring(Stats.last or "-"))
			end
		end)
	end

	buildUI()
	Core.Helpers = Helpers
	Core.Net = Net
	print("[Kuy] โหลดสำเร็จ (v2.3 FastSteal) | Plot:", Helpers.GetPlot() and Helpers.GetPlot().Name or "ยังไม่พบ")
end

local ok, err = pcall(main)
if not ok then
	warn("[Kuy] FATAL: " .. tostring(err))
end