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
local CoreGui = game:GetService("CoreGui")
local vimOk, vimSvc = pcall(function() return game:GetService("VirtualInputManager") end)
local VirtualInputManager = vimOk and vimSvc or nil
local vuOk, vuSvc = pcall(function() return game:GetService("VirtualUser") end)
local VirtualUser = vuOk and vuSvc or nil

local LocalPlayer = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

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
		_conns = {},
		_loops = {},
		_cleanups = {},
		_alive = true,
	}
	local Loops = {}

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

	-- ลูปผูกกับ flag: flag เป็น false หรือ Destroy -> หยุดเอง
	function Core:Loop(name, flag, interval, fn)
		self:StopLoop(name)
		self._loops[name] = task.spawn(function()
			while self._alive and self.Flags[flag] do
				local ok, err = pcall(fn)
				if not ok then
					warn("[Kuy] loop '" .. name .. "': " .. tostring(err))
				end
				task.wait(interval)
			end
			self._loops[name] = nil
		end)
	end

	function Core:Destroy()
		if Config and Config.Save then
			pcall(Config.Save)
		end
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
	Core.Flags.AntiAfk = true               -- กันเตะ AFK 20 นาที
	Core.Flags.StealDelay = 1
	Core.Flags.OutrunOnly = true           -- ขโมยเฉพาะด่านที่ความเร็วเราวิ่งหนีบอสทัน
	Core.Flags.TargetFastestOnly = true    -- ขโมยเฉพาะด่านเดียวที่บอสเร็วที่สุดที่เราวิ่งทัน
	Core.Flags.MaxStageStealPacks = 4      -- โควต้าขโมยการ์ดที่ดีที่สุดรอบละ 4 ใบในด่านเดียว
	Core.Flags.OutrunMargin = 1.0          -- อัตราส่วนความเร็วเราเทียบกับบอส (>= 1.0 คือวิ่งทัน)
	for i = 1, 12 do
		Core.Flags["Stage" .. i] = true
	end
	local STEAL_RARITY_KEYS = {
		"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical",
		"Cosmic", "Divine", "Omniversal", "Eternal", "Primordial",
		"Exclusive", "Godlike", "Secret"
	}
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

		local count = 0
		for k, v in pairs(parsed) do
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

	function Helpers.Teleport(cf)
		local char = LocalPlayer.Character
		local hrp = Helpers.GetRoot()
		if not (char and hrp) then return false end
		return pcall(function()
			char:PivotTo(cf)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
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
		local m2 = Workspace:FindFirstChild("Machine2")
		local pad = m2 and m2:FindFirstChild("MutationMachine")
		if pad and pad:IsA("BasePart") then
			Helpers.mutatePadCache = pad
			return pad
		end
		return nil
	end

	function Helpers.IsAtMutateMachine()
		local pad = Helpers.GetMutateMachinePad()
		local hrp = Helpers.GetRoot()
		if not (pad and hrp) then return false end
		local d = hrp.Position - pad.Position
		return Vector3.new(d.X, 0, d.Z).Magnitude <= 10 and math.abs(d.Y) <= 8
	end

	function Helpers.VisitMutateMachine(actionFn)
		if not Helpers.IsAlive() or Helpers.IsCarrying() or Core.Busy then
			return false, "BUSY_OR_DEAD"
		end
		local pad = Helpers.GetMutateMachinePad()
		if not pad then
			return false, "PAD_NOT_FOUND"
		end
		local hrp = Helpers.GetRoot()
		if not hrp then return false, "NO_HRP" end

		Core.Busy = true
		local wasAtMachine = Helpers.IsAtMutateMachine()
		local origCF = hrp.CFrame
		local padCF = CFrame.new(pad.Position + Vector3.new(0, 3, 0))

		if not wasAtMachine then
			Helpers.Teleport(padCF)
			task.wait(0.22)
		end

		local ok, res, extra = pcall(actionFn)

		if not wasAtMachine and Helpers.IsAlive() and not Helpers.IsCarrying() then
			Helpers.Teleport(origCF)
		end
		Core.Busy = false

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
		local pd = getPlayerData()
		if pd and pd.Get then
			local ok, val = pcall(pd.Get, "Speed")
			if ok and val ~= nil then
				spdStat = tonumber(val) or Helpers.ParseSuffixNumber(val)
			end
		end
		if not spdStat then
			local ls = LocalPlayer:FindFirstChild("leaderstats")
			local sv = ls and ls:FindFirstChild("Speed")
			if sv then
				spdStat = tonumber(sv.Value) or Helpers.ParseSuffixNumber(sv.Value)
			end
		end
		if sc and sc.ToWalkSpeed and spdStat then
			local ok, ws = pcall(sc.ToWalkSpeed, spdStat, false)
			if ok and type(ws) == "number" then
				return math.clamp(ws * 0.98, sc.MinimumWalkSpeed or 16, maxCap)
			end
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		return math.max((hum and hum.WalkSpeed) or 16, 16)
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
				local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
				local forward = look.Magnitude > 0.05 and look.Unit or Vector3.new(-1, 0, 0)
				local p = hrp.Position
				hrp.CFrame = CFrame.lookAt(p, p + forward)
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
				hum.WalkSpeed = Helpers.GetMoveSpeed()
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
		Core:Connect(RunService.Heartbeat, function()
			if not Core.Flags.AntiRagdollMode then return end
			local char = LocalPlayer.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end
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

	-- เคลื่อนที่ด้วย Humanoid:MoveTo จริง พร้อมโหมดเบรกแม่นยำ (precise) และหลบบอสไล่หลัง (evadeEnemies)
	function Helpers.MoveTo(targetPos, shouldAbort, opts)
		local precise = not (opts and opts.precise == false)
		local evadeEnemies = opts and opts.evadeEnemies == true
		local safeBounds = Helpers.GetSafeZoneBounds()
		local arriveDist = (opts and opts.arriveDist) or (precise and 3 or 8)
		local floorRefreshAt = 0

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
				if Vector3.new(v.X, 0, v.Z).Magnitude > 8 then
					RunService.Heartbeat:Wait()
					zeroOnce()
				end
			end
		end

		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = Helpers.GetRoot()
		if not (char and hum and hrp) then return false end
		local initYOk = precise and 10 or 22
		local initFlat = Vector3.new(targetPos.X - hrp.Position.X, 0, targetPos.Z - hrp.Position.Z).Magnitude
		if initFlat <= arriveDist and math.abs(targetPos.Y - hrp.Position.Y) <= initYOk then
			if precise then
				stopMotion(hum, hrp, true)
			end
			pcall(function()
				if hum then hum.WalkSpeed = Helpers.GetMoveSpeed() end
			end)
			return true
		end

		local lastCheck = os.clock()
		local lastPos = hrp.Position
		local lastIssue = 0
		local lastDodgeJump = 0
		local borderStallStart = nil
		local timeout = os.clock() + math.max(90, initFlat / 12 + 30)

		while Core._alive and Helpers.IsAlive() and os.clock() < timeout do
			local now = os.clock()
			if shouldAbort and shouldAbort() then
				if precise then
					stopMotion(hum, hrp, false)
				end
				pcall(function()
					if hum then hum.WalkSpeed = Helpers.GetMoveSpeed() end
				end)
				return true
			end
			char = LocalPlayer.Character
			hum = char and char:FindFirstChildOfClass("Humanoid")
			hrp = Helpers.GetRoot()
			if not (char and hum and hrp) then return false end

			local cur = hrp.Position
			local flatDelta = Vector3.new(targetPos.X - cur.X, 0, targetPos.Z - cur.Z)
			local flatDist = flatDelta.Magnitude
			local fullDist = (targetPos - cur).Magnitude
			local yTol = precise and 10 or 22
			if flatDist <= arriveDist and math.abs(targetPos.Y - cur.Y) <= yTol then
				if precise then
					stopMotion(hum, hrp, true)
				end
				pcall(function()
					if hum then hum.WalkSpeed = Helpers.GetMoveSpeed() end
				end)
				return true
			end

			local moveTarget = targetPos
			if Core.Flags.AntiRagdollMode and (char:GetAttribute("Ragdolled") == true or hum.PlatformStand) then
				Helpers.RecoverFromHit(char)
			end
			local locked = char:GetAttribute("TrapImmobilized") == true or (not Core.Flags.AntiRagdollMode and char:GetAttribute("Ragdolled") == true)
			if not locked then
				local topSpeed = Helpers.GetMoveSpeed()
				local desiredSpeed = topSpeed
				-- ชะลอความเร็วเล็กน้อยเฉพาะระยะประชิดตัว 5.5 studs สุดท้ายในโหมด precise เพื่อให้หยุดตรงจุด
				-- ระยะทางไกลวิ่งด้วย topSpeed เต็ม 100% ตลอดเส้นทาง ไม่กดสปีดลงล่วงหน้า
				if precise and flatDist <= 5.5 then
					desiredSpeed = math.clamp(flatDist * 12, 45, topSpeed)
				end
				hum.WalkSpeed = desiredSpeed

				-- หลีกเลี่ยงบอสบนทางหลักระหว่างวิ่งในด่าน
				if evadeEnemies and safeBounds and cur.X > safeBounds.maxX and cur.Y > 64 and flatDist > 40 then
					local ePos, eDist = findNearestEnemyPos(cur, 65)
					if ePos then
						local side = (ePos.Z >= cur.Z) and -1 or 1
						local dodgeZ = math.clamp(safeBounds.center.Z + side * 34, safeBounds.center.Z - 42, safeBounds.center.Z + 42)
						local stepX = math.max(targetPos.X, cur.X - 110)
						moveTarget = Vector3.new(stepX, targetPos.Y, dodgeZ)
						if eDist <= 42 and now - lastDodgeJump >= 0.65 then
							lastDodgeJump = now
							pcall(function() hum.Jump = true end)
						end
					end
				end
			end

			if not locked then
				if hum.Sit then hum.Sit = false end
				if hum.PlatformStand then hum.PlatformStand = false end
			end
			local issueInterval = 0.1
			local moveFlat = Vector3.new(moveTarget.X - cur.X, 0, moveTarget.Z - cur.Z)
			local moveFlatDist = moveFlat.Magnitude
			local flatDir = moveFlatDist > 0.05 and moveFlat.Unit or Vector3.zero
			local stepTarget = (moveFlatDist > 100 and flatDir ~= Vector3.zero)
				and Vector3.new(cur.X + flatDir.X * 100, moveTarget.Y, cur.Z + flatDir.Z * 100)
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
				if not locked and moved < 2 and fullDist > 6 then
					pcall(function()
						if flatDir ~= Vector3.zero then hum:Move(flatDir, false) end
						hum.Jump = true
					end)
				end
			end

			-- หากกำลังพยายามเดินออกจาก SafeZone เข้าสู่ด่าน แต่ติดสิ่งกีดขวาง/ประตูปิดหน้าด่านเกิน 2.5 วินาที ให้ยกเลิกทันที
			if safeBounds and targetPos.X > (safeBounds.maxX + 10) and cur.X <= (safeBounds.maxX + 4) then
				if not borderStallStart then
					borderStallStart = now
				elseif now - borderStallStart >= 2.5 then
					stopMotion(hum, hrp, true)
					pcall(function()
						if hum then hum.WalkSpeed = Helpers.GetMoveSpeed() end
					end)
					return false
				end
			else
				borderStallStart = nil
			end

			RunService.Heartbeat:Wait()
		end
		stopMotion(hum, hrp, false)
		pcall(function()
			if hum then hum.WalkSpeed = Helpers.GetMoveSpeed() end
		end)
		return false
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

	-- กำลังแบกแพ็คอยู่หรือไม่ (ยืนยันจาก ServerData.Get("Stealing")[UserId])
	function Helpers.IsCarrying()
		local sd = getServerData()
		if not sd then return false end
		local ok, t = pcall(sd.Get, "Stealing")
		return ok and type(t) == "table" and t[tostring(LocalPlayer.UserId)] ~= nil
	end

	-----------------------------------------------------------------
	-- 3. NETWORK WRAPPER
	-----------------------------------------------------------------
	local Net = { _last = {} }
	local RP = "ReplicatedStorage.Remotes."
	Net.Paths = {
		Boost = RP .. "Treadmill.Boost",             -- RE: FireServer(token:string)
		ExitRequest = RP .. "Treadmill.ExitRequest", -- RE: FireServer()
		PlaceOwned = RP .. "Packs.PlaceOwned",       -- RF: InvokeServer({PackId, Position})
		OpenOwned = RP .. "Packs.OpenOwned",         -- RF: InvokeServer(packGuid)
		PacksOpened = RP .. "Packs.Opened",          -- RE: FireServer(packGuid)
		PacksEquipBest = RP .. "Packs.EquipBest",    -- RF: InvokeServer({})
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
	local TRAINING_ATTR = "TrainingOnTreadmill"
	local COMBO_ATTR = "TreadmillCombo"

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
			if not (Core.Flags.AutoTreadmill or Core.Flags.AutoSteal) then return end
			local args = table.pack(...)
			if args.n == 0 then return end
			task.spawn(function()
				task.wait(0.24 + math.random() * 0.16)
				if Core._alive and (Core.Flags.AutoTreadmill or Core.Flags.AutoSteal) and LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then
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
			or r:find("AREA") ~= nil
			or r:find("PLOT") ~= nil
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
		-- วาร์ปลงบนแท่นยืนของลู่วิ่งตรงจุด Box หรือ Seat/Primary
		local targetCf
		if seat and seat:IsA("BasePart") then
			targetCf = CFrame.new(seat.Position + Vector3.new(0, 2.5, 0))
		elseif prim and prim:IsA("BasePart") then
			targetCf = prim.CFrame * CFrame.new(0, 1.2, 0)
		elseif box and box:IsA("BasePart") then
			targetCf = CFrame.new(box.Position + Vector3.new(0, 1.5, 0))
		else
			targetCf = CFrame.new(pos + Vector3.new(0, 1.2, 0))
		end

		Helpers.Teleport(targetCf)

		-- ก้าวเท้าเล็กน้อยเพื่อให้เซิร์ฟเวอร์ตรวจจับ Touched บนสายพาน
		local hum = Helpers.GetHumanoid()
		if hum and pos then
			pcall(function()
				hum:MoveTo(pos)
			end)
		end

		-- รอการยืนยันสถานะ TrainingOnTreadmill จากเซิร์ฟเวอร์
		waitUntil(function()
			return LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil or not Core._alive
		end, 1.2)
	end

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
	-- 5. FEATURE: STEAL PACKS (12 ด่าน)
	-- แพ็คอยู่ที่ Workspace.Game.Packs.Stage<N>.SpawnedPacks.<ชื่อ> มี ProximityPrompt ชื่อ "StealPrompt"
	-- ลำดับ: (ออกจากลู่วิ่ง) -> วาร์ปไปที่แพ็ค (ตรึงตำแหน่ง) -> กด StealPrompt -> ตรวจว่าแบก -> วาร์ปกลับฐาน -> ตรวจว่าส่งสำเร็จ
	-----------------------------------------------------------------
	-- พิกัดกลางด่าน 1-12 (ใช้สำหรับ RequestStreamAroundAsync/วาร์ป เมื่อ Area ยังไม่ stream เข้ามา)
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
	}

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

	local function getModelRarity(model)
		if not model then return "Common", 1 end
		local r = model:GetAttribute("Rarity")
			or model:GetAttribute("ItemRarity")
			or model:GetAttribute("PackRarity")
		local sr = tonumber(model:GetAttribute("SortRarity"))

		if not r or r == "" then
			local packName = model:GetAttribute("PackName") or model:GetAttribute("ItemName") or model.Name
			local cc = getCharacterConfig()
			local charCfg = cc and cc.Get and cc.Get(packName)
			if charCfg then
				r = charCfg.Rarity or charCfg.ItemRarity or charCfg.Tier
			end
			if not r or r == "" then
				local pc = getPacksConfig()
				local cfg = pc and pc.Get and pc.Get(packName)
				if cfg then
					r = cfg.Rarity or cfg.ItemRarity or cfg.Tier
					sr = sr or tonumber(cfg.SortRarity)
				end
			end
		end

		local pc = getPacksConfig()
		local ranks = (pc and pc.RarityRank) or {
			Common = 1,
			Uncommon = 2,
			Rare = 3,
			Epic = 4,
			Legendary = 5,
			Mythical = 6,
			Cosmic = 7,
			Divine = 8,
			Omniversal = 9,
			Eternal = 10,
			Primordial = 11,
			Exclusive = 12,
			Godlike = 13,
			Secret = 14,
		}

		local rank = sr or (r and ranks[r]) or 1
		local rName = r or "Common"

		if type(rName) == "string" then
			rName = rName:sub(1,1):upper() .. rName:sub(2):lower()
		end

		return rName, rank
	end

	local function isPackRarityAllowed(model)
		if not model then return false end
		local rName, rank = getModelRarity(model)

		-- 1. ตรวจสอบจากชื่อ Rarity โดยตรง
		local flagKey = "Rarity_" .. tostring(rName)
		if Core.Flags[flagKey] == true then
			return true
		end

		-- 2. Fallback ตรวจสอบจากลำดับ Rank
		local rankNames = {
			[1] = "Common",
			[2] = "Uncommon",
			[3] = "Rare",
			[4] = "Epic",
			[5] = "Legendary",
			[6] = "Mythical",
			[7] = "Cosmic",
			[8] = "Divine",
			[9] = "Omniversal",
			[10] = "Eternal",
			[11] = "Primordial",
			[12] = "Exclusive",
			[13] = "Godlike",
			[14] = "Secret",
		}
		local fallbackName = rankNames[rank]
		if fallbackName and Core.Flags["Rarity_" .. fallbackName] == true then
			return true
		end

		-- 3. ตรวจสอบว่าผู้ใช้เปิดเกรดใดไว้บ้างหรือไม่ หากปิดทุกเกรดให้ยอมรับทั้งหมด (Safety Fallback)
		local anyRarityActive = false
		for _, k in ipairs(STEAL_RARITY_KEYS) do
			if Core.Flags["Rarity_" .. k] == true then
				anyRarityActive = true
				break
			end
		end
		if not anyRarityActive then
			return true
		end

		return false
	end

	local function getPackScore(model)
		local pc = getPacksConfig()
		local mc = getMutationConfig()
		local packName = (model and (model:GetAttribute("PackName") or model.Name)) or ""
		local cfg = pc and pc.Get and pc.Get(packName)
		local luck = (cfg and pc.GetDisplayLuck and pc.GetDisplayLuck(cfg)) or 1
		local mut = model and model:GetAttribute("Mutation")
		local mutMult = (mut and mc and mc.Mutations and mc.Mutations[mut] and mc.Mutations[mut].CashMult) or 1
		local totalMult = luck * mutMult
		local odd = (cfg and tonumber(cfg.NumericalOdd)) or 0
		local weight = model and tonumber(model:GetAttribute("Weight")) or nil
		if not weight and model then
			local scOk, sc = pcall(function() return model:GetScale() end)
			local auth = tonumber(model:GetAttribute("AuthoredModelScale")) or 1
			local rel = (scOk and type(sc) == "number" and auth > 0) and (sc / auth) or 1
			weight = (pc and pc.ScaleToWeight and pc.ScaleToWeight(rel)) or rel
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

	local function findStealPrompt(stageFolder)
		if not stageFolder then return nil end
		local root = stageFolder:FindFirstChild("SpawnedPacks")
		if not root then return nil end
		local hrp = Helpers.GetRoot()
		local enemies = getStageEnemyPositions(stageFolder)
		local best = nil
		for _, model in ipairs(root:GetChildren()) do
			if isPackRarityAllowed(model) then
				local p = model:FindFirstChild("StealPrompt", true)
				if p and p:IsA("ProximityPrompt") and p.Enabled then
					local pos = promptPos(p)
					if pos then
						local minEnemyDist = math.huge
						for _, ePos in ipairs(enemies) do
							local ed = (pos - ePos).Magnitude
							if ed < minEnemyDist then minEnemyDist = ed end
						end
						local mult, odd, weight = getPackScore(model)
						local _, rank = getModelRarity(model)
						local cand = {
							prompt = p,
							model = model,
							rank = rank or 1,
							mult = mult or 1,
							odd = odd or 0,
							weight = weight or 0,
							enemyDist = minEnemyDist,
							dist = hrp and (pos - hrp.Position).Magnitude or 0,
						}
						if isBetterCandidate(cand, best) then
							best = cand
						end
					end
				end
			end
		end
		return best and best.prompt or nil
	end

	-- กดค้างตาม HoldDuration จริงภายในระยะปลอดภัยรอบแพ็ค (ไม่วิ่งเหวี่ยงหรือกระโดดหลุดระยะ Prompt)
	-- method "hold" = InputHoldBegin/End + KeyCode, method "fire" = fireproximityprompt
	-- คืนตาราง diag บอกว่าเหตุการณ์ของ prompt เกิดขึ้นครบหรือไม่ (ใช้ดูว่าพลาดที่ขั้นไหน)
	local function holdAndOrbit(prompt, duration, stageFolder, diag)
		local anchor0 = packAnchorPos(prompt) or promptPos(prompt)
		local maxDist = math.max(5, prompt.MaxActivationDistance or 10)
		local safeRadius = 2.8

		-- รอจน Prompt พร้อมใช้งานและตัวละครอยู่ในระยะเปิดใช้งานจริงก่อนเริ่มกดค้าง
		local readyDeadline = os.clock() + 0.35
		while os.clock() < readyDeadline and Core._alive and Core.Flags.AutoSteal and prompt.Parent do
			local hrp = Helpers.GetRoot()
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local pPos = promptPos(prompt) or anchor0
			local aPos = packAnchorPos(prompt) or pPos
			if hrp and pPos and aPos then
				local dPrompt = (hrp.Position - pPos).Magnitude
				local dAnchor = (hrp.Position - aPos).Magnitude
				if dPrompt <= maxDist - 2.5 and dAnchor <= maxDist - 2.5 and prompt.Enabled and ProximityPromptService.Enabled then
					break
				elseif hum and dAnchor > 3.2 then
					hum.WalkSpeed = 32
					pcall(function() hum:MoveTo(Vector3.new(aPos.X, hrp.Position.Y, aPos.Z)) end)
				end
			end
			RunService.Heartbeat:Wait()
		end

		local function triggerHoldStart()
			pcall(function() prompt:InputHoldBegin() end)
			pressPromptKey(prompt, true)
		end

		local t0 = os.clock()
		local deadline = t0 + duration
		local maxDeadline = t0 + duration + 1.0
		local lastRetryAt = t0
		triggerHoldStart()

		while os.clock() < deadline and Core._alive and Core.Flags.AutoSteal and prompt.Parent do
			if diag.trig or Helpers.IsCarrying() then break end
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = Helpers.GetRoot()
			local pPos = promptPos(prompt)
			local aPos = packAnchorPos(prompt) or pPos
			if not (char and hum and hrp and aPos) then break end
			if Core.Flags.AntiRagdollMode and (char:GetAttribute("Ragdolled") == true or hum.PlatformStand) then
				Helpers.RecoverFromHit(char)
			end
			local locked = char:GetAttribute("TrapImmobilized") == true or (not Core.Flags.AntiRagdollMode and char:GetAttribute("Ragdolled") == true)
			if locked then break end

			local now = os.clock()
			local dAnchor = Vector3.new(hrp.Position.X - aPos.X, 0, hrp.Position.Z - aPos.Z).Magnitude
			local dPrompt = pPos and (hrp.Position - pPos).Magnitude or dAnchor

			-- หาก InputHold ยังไม่เริ่มหรือถูกยกเลิกกลางคัน ให้เข้าใกล้และกดค้างใหม่อัตโนมัติ
			if not diag.began and now - t0 >= 0.55 and fireproximityprompt then
				break
			end
			if (not diag.began or diag.ended) and now - lastRetryAt >= 0.16 then
				lastRetryAt = now
				if diag.ended then
					diag.ended = false
					deadline = math.min(maxDeadline, now + duration)
				end
				if dAnchor <= maxDist - 1.5 and dPrompt <= maxDist - 1.5 then
					triggerHoldStart()
				end
			end

			-- ยืนชิดด้านที่ห่างบอสภายในรัศมี 2.8 studs ด้วยความเร็วคุมระยะ (ห้ามกระโดดหรือวิ่งเหวี่ยงไกลเกิน)
			local ePos = findNearestEnemyPos(hrp.Position, 55, stageFolder)
			if ePos or dAnchor > 3.6 or dPrompt > maxDist - 2.5 then
				local targetPos
				if ePos and dAnchor <= 4.5 then
					local away = Vector3.new(aPos.X - ePos.X, 0, aPos.Z - ePos.Z)
					local dir = away.Magnitude > 0.1 and away.Unit or Vector3.new(-1, 0, 0)
					targetPos = Vector3.new(aPos.X + dir.X * safeRadius, hrp.Position.Y, aPos.Z + dir.Z * safeRadius)
				else
					local toPlayer = Vector3.new(hrp.Position.X - aPos.X, 0, hrp.Position.Z - aPos.Z)
					local dir = toPlayer.Magnitude > 0.1 and toPlayer.Unit or Vector3.new(-1, 0, 0)
					targetPos = Vector3.new(aPos.X + dir.X * 2.4, hrp.Position.Y, aPos.Z + dir.Z * 2.4)
				end
				local curSpd = Helpers.GetMoveSpeed()
				hum.WalkSpeed = math.clamp(curSpd, math.min(16, curSpd), 38)
				pcall(function() hum:MoveTo(targetPos) end)
			else
				pcall(function()
					hum:MoveTo(hrp.Position)
					hum:Move(Vector3.zero)
				end)
			end
			RunService.Heartbeat:Wait()
		end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function() hum.WalkSpeed = Helpers.GetMoveSpeed() end)
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

		-- หาก executor รองรับ fireproximityprompt และไม่ได้ระบุ hold_only ให้ยิงตรงทันที
		if fireproximityprompt and method ~= "hold_only" then
			pcall(fireproximityprompt, prompt)
			local tEnd = os.clock() + 0.5
			while os.clock() < tEnd and Core._alive and Core.Flags.AutoSteal and prompt.Parent do
				if Helpers.IsCarrying() or diag.trig then break end
				RunService.Heartbeat:Wait()
			end
			if Helpers.IsCarrying() or diag.trig then
				for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then
					pcall(function() hum.WalkSpeed = Helpers.GetMoveSpeed() end)
				end
				return diag
			end
		end

		local hold = prompt.HoldDuration or 0.5
		holdAndOrbit(prompt, hold + 0.3, stageFolder, diag)
		pcall(function() prompt:InputHoldEnd() end)
		pressPromptKey(prompt, false)

		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function() hum.WalkSpeed = Helpers.GetMoveSpeed() end)
		end
		return diag
	end

	local function leaveTreadmill()
		if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil then return end
		Net.Fire(Net.Paths.ExitRequest, 0.5)

		-- ปลด Anchored และดีดตัวละครก้าวออกจากแท่นสายพานทันที เพื่อให้หลุดจากระยะ Touched
		local hrp = Helpers.GetRoot()
		local hum = Helpers.GetHumanoid()
		if hrp then
			pcall(function()
				hrp.Anchored = false
				-- ขยับตัวละครไปข้างหน้า 10 studs ออกจากเครื่องวิ่งไปยังพื้นที่โล่งของฐาน
				hrp.CFrame = hrp.CFrame * CFrame.new(0, 2, 10)
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
		end
		if hum then
			pcall(function()
				hum.Jump = true
			end)
		end

		waitUntil(function() return LocalPlayer:GetAttribute(TRAINING_ATTR) == nil end, 2.0)
		local cNow = LocalPlayer.Character
		local hNow = cNow and cNow:FindFirstChildOfClass("Humanoid")
		if hNow then
			pcall(function() hNow.WalkSpeed = Helpers.GetMoveSpeed() end)
		end
	end

	local function moveToCenterLane(abortFn)
		local hrp = Helpers.GetRoot()
		if not hrp then return end
		local bounds = Helpers.GetSafeZoneBounds()
		local laneX = math.clamp(hrp.Position.X, bounds.maxX - 48, bounds.maxX - 28)
		if hrp.Position.X <= bounds.maxX + 20 then
			if math.abs(hrp.Position.Z - bounds.center.Z) > 4 then
				Helpers.MoveTo(Vector3.new(laneX, hrp.Position.Y, bounds.center.Z), abortFn, { precise = false, arriveDist = 5 })
			end
		elseif math.abs(hrp.Position.Z - bounds.center.Z) > 20 then
			Helpers.MoveTo(Vector3.new(hrp.Position.X, hrp.Position.Y, bounds.center.Z), abortFn, { precise = false, arriveDist = 5 })
		end
	end

	local function findDroppedPackPrompt(maxRadius)
		local hrp = Helpers.GetRoot()
		if not hrp then return nil end
		local radius = maxRadius or 80
		local bestPrompt = nil
		local bestDist = radius

		-- 1. ตรวจสอบจาก CollectionService Tag 'SpawnedPack'
		local okTagged, taggedPacks = pcall(function()
			return CollectionService:GetTagged("SpawnedPack")
		end)
		if okTagged and type(taggedPacks) == "table" then
			for _, packModel in ipairs(taggedPacks) do
				if packModel and packModel.Parent then
					local prompt = packModel:FindFirstChild("StealPrompt", true)
					if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
						local pPos = promptPos(prompt) or packAnchorPos(prompt)
						if pPos then
							local d = (hrp.Position - pPos).Magnitude
							if d <= bestDist then
								bestDist = d
								bestPrompt = prompt
							end
						end
					end
				end
			end
		end
		if bestPrompt then return bestPrompt end

		-- 2. ค้นหาใน Workspace.Game.Packs
		local game_ = Workspace:FindFirstChild("Game")
		local packsFolder = game_ and game_:FindFirstChild("Packs")
		if packsFolder then
			for _, stage in ipairs(packsFolder:GetChildren()) do
				local sp = stage:FindFirstChild("SpawnedPacks")
				local container = sp or stage
				for _, model in ipairs(container:GetChildren()) do
					local prompt = model:FindFirstChild("StealPrompt", true)
					if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
						local pPos = promptPos(prompt) or packAnchorPos(prompt)
						if pPos then
							local d = (hrp.Position - pPos).Magnitude
							if d <= bestDist then
								bestDist = d
								bestPrompt = prompt
							end
						end
					end
				end
			end
		end
		return bestPrompt
	end

	local function recoverDroppedPack(stageFolder)
		local char = LocalPlayer.Character
		if char and Core.Flags.AntiRagdollMode then
			Helpers.RecoverFromHit(char)
		end
		task.wait(0.15)

		-- ค้นหาแพ็คที่เพิ่งหลุดตกพื้นในระยะใกล้
		local prompt = findDroppedPackPrompt(75)
		if not prompt then
			task.wait(0.25)
			prompt = findDroppedPackPrompt(90)
		end

		if not prompt then
			return false, "แพ็คหลุดกลางทางและหาไม่พบ"
		end

		logAction("ขโมย", "แพ็คหลุด! กำลังเดินกลับไปเก็บ...", true)

		local pPos = promptPos(prompt) or packAnchorPos(prompt)
		if pPos then
			Helpers.MoveTo(pPos, function()
				return not Core.Flags.AutoSteal or not prompt.Parent or Helpers.IsCarrying()
			end, { precise = true, arriveDist = 2.5, evadeEnemies = true })
		end

		if not Core.Flags.AutoSteal or not Helpers.IsAlive() then
			return false, "ยกเลิก/ตัวละครตายขณะเก็บแพ็คที่ตก"
		end

		if not prompt.Parent or not prompt.Enabled then
			return false, "แพ็คที่ตกถูกเก็บไปแล้วหรือหายไป"
		end

		local hrp = Helpers.GetRoot()
		local pNow = promptPos(prompt) or packAnchorPos(prompt)
		if hrp and pNow and (hrp.Position - pNow).Magnitude > 4.5 then
			Helpers.Teleport(CFrame.new(pNow + Vector3.new(0, 1.5, 0)))
			task.wait(0.05)
		end

		local holdDiag = usePrompt(prompt, "auto", stageFolder)
		local got = waitUntil(Helpers.IsCarrying, 0.6)
		if not got and prompt.Parent and Core.Flags.AutoSteal and Helpers.IsAlive() then
			usePrompt(prompt, "hold_only", stageFolder)
			got = waitUntil(Helpers.IsCarrying, 0.8)
		end

		if got or Helpers.IsCarrying() then
			logAction("ขโมย", "เก็บแพ็คที่ตกคืนสำเร็จ! กำลังนำส่งต่อ...", true)
			return true
		end

		return false, "เก็บแพ็คที่ตกไม่สำเร็จ"
	end

	local function deliver(stageFolder)
		local origChar = LocalPlayer.Character
		local pos = Helpers.GetPlotSpawnPos()
		if not pos then return false, "ไม่พบจุดเกิดของฐาน" end
		local bounds = Helpers.GetSafeZoneBounds()

		local curHum = origChar and origChar:FindFirstChildOfClass("Humanoid")
		if curHum then
			pcall(function() curHum.WalkSpeed = Helpers.GetMoveSpeed() end)
		end

		local function isSafelyDelivered(livePos)
			if Helpers.IsCarrying() then return false end
			local char = LocalPlayer.Character
			-- หากตัวละครเปลี่ยน instance หรือตาย/เลือดหมด = เกิดใหม่จากการโดนตีตาย ไม่ใช่การส่งสำเร็จ
			if not char or char ~= origChar or not Helpers.IsAlive() then return false end
			local hrp = Helpers.GetRoot()
			if not hrp then return false end

			-- 1) ถึงพื้นที่ฐานตัวเอง (ระยะห่างจากจุดเกิดฐาน <= 35 studs)
			if livePos and (hrp.Position - livePos).Magnitude <= 35 then return true end
			if pos and (hrp.Position - pos).Magnitude <= 35 then return true end

			-- 2) หรือตัวละครอยู่ใน SafeZone หรือข้ามฝั่ง SafeZone เข้ามาแล้ว
			if Helpers.IsInSafeZone(char) then return true end
			if hrp.Position.X <= (bounds.maxX + 5) then return true end

			return false
		end

		local stopWhenDelivered = function()
			if not Core.Flags.AutoSteal then return true end
			if Helpers.IsCarrying() then
				return false
			end
			return true
		end

		local function checkDeliveryOrRecover(livePos)
			if isSafelyDelivered(livePos) then
				return true, "DELIVERED"
			end
			if not Core.Flags.AutoSteal or not Helpers.IsAlive() or LocalPlayer.Character ~= origChar then
				return false, "ยกเลิก/ตัวละครตายขณะเดินกลับ"
			end
			local recovered, err = recoverDroppedPack(stageFolder)
			if recovered and Helpers.IsCarrying() then
				return false, "RECOVERED"
			end
			return false, err or "โดนตี/แพ็คหลุดกลางทาง"
		end

		for pass = 1, 3 do
			local livePos = Helpers.GetPlotSpawnPos() or pos
			local hrp = Helpers.GetRoot()
			local atBase = hrp and livePos and (hrp.Position - livePos).Magnitude <= 35

			-- เฉพาะเมื่อตัวละครยังอยู่นอกฐาน (X > bounds.maxX - 15) และยังไม่ถึงฐาน จึงจะเดินผ่านประตูทางเข้า SafeZone
			if not atBase and hrp and hrp.Position.X > bounds.maxX - 15 then
				local entryZ = math.abs(livePos.Z - bounds.center.Z) > 35 and bounds.center.Z or livePos.Z
				Helpers.MoveTo(Vector3.new(bounds.maxX - 35, livePos.Y, entryZ), stopWhenDelivered, { precise = false, arriveDist = 8, evadeEnemies = true })
				if not Helpers.IsCarrying() then
					local okDeliv, state = checkDeliveryOrRecover(livePos)
					if okDeliv then return true end
					if state ~= "RECOVERED" then return false, state end
				end
				if not Core.Flags.AutoSteal or not Helpers.IsAlive() or LocalPlayer.Character ~= origChar then break end
			end

			Helpers.MoveTo(livePos + Vector3.new(0, 3, 0), stopWhenDelivered, { precise = false, arriveDist = 6, evadeEnemies = true })
			if not Helpers.IsCarrying() then
				local okDeliv, state = checkDeliveryOrRecover(livePos)
				if okDeliv then return true end
				if state ~= "RECOVERED" then return false, state end
			end

			Helpers.StreamAround(livePos, 3)
			if waitUntil(function()
				return not Helpers.IsCarrying()
			end, 3.0) then
				if isSafelyDelivered(livePos) then return true end
				local okDeliv, state = checkDeliveryOrRecover(livePos)
				if okDeliv then return true end
				if state ~= "RECOVERED" then return false, state end
			end
		end

		if isSafelyDelivered(pos) then return true end
		return false, "ส่งแพ็คที่ฐานไม่สำเร็จ"
	end

	-- ตรึงตำแหน่งตัวละครไว้ที่ cf (หรือฟังก์ชันคืนตำแหน่ง) ระหว่างกดค้าง กันโดนเกมดัน/ดึงออกนอกระยะ prompt
	-- ใช้ pinGen เป็นโทเคน: เรียก stopPin() หรือ pinTo ใหม่ -> ลูปเก่าหยุดทันที
	local pinGen = 0
	local function stopPin()
		pinGen = pinGen + 1
	end
	local function pinTo(target)
		pinGen = pinGen + 1
		local mine = pinGen
		task.spawn(function()
			while pinGen == mine and Core._alive do
				local cf = type(target) == "function" and target() or target
				if cf and Helpers.IsAlive() then Helpers.Teleport(cf) end
				task.wait(0.1)
			end
		end)
	end

	local function getStageFolder(i)
		local game_ = Workspace:FindFirstChild("Game")
		local packs = game_ and game_:FindFirstChild("Packs")
		return packs and packs:FindFirstChild("Stage" .. i)
	end

	local function checkStageHasPacks(i)
		local folder = getStageFolder(i)
		local basePos = STAGE_CENTERS[i]

		-- 1. ตรวจสอบโฟลเดอร์ของด่าน ถ้ายังไม่โหลด (StreamingEnabled) ให้เรียก StreamAround อย่างทั่วถึง
		if not folder or not folder:FindFirstChild("SpawnedPacks") or #folder.SpawnedPacks:GetChildren() == 0 then
			if basePos then
				Helpers.StreamAround(basePos, 2.0)
			end
			folder = getStageFolder(i)
		end

		-- 2. ค้นหาแพ็คในด่าน
		local prompt = findStealPrompt(folder)
		if prompt then return prompt, nil end

		-- 3. ตรวจหาแพ็คที่หลุดตกค้างในด่าน (เช่น โดนตีตกแต่ยังไม่ถูกเก็บ)
		if basePos then
			local bestDropped = nil
			local okTagged, taggedPacks = pcall(function()
				return CollectionService:GetTagged("SpawnedPack")
			end)
			if okTagged and type(taggedPacks) == "table" then
				local bestScore = -1
				for _, packModel in ipairs(taggedPacks) do
					if packModel and packModel.Parent and isPackRarityAllowed(packModel) then
						local p = packModel:FindFirstChild("StealPrompt", true)
						if p and p:IsA("ProximityPrompt") and p.Enabled then
							local pPos = promptPos(p) or packAnchorPos(p)
							if pPos and (pPos - basePos).Magnitude <= 120 then
								local mult, odd, weight = getPackScore(packModel)
								local _, rank = getModelRarity(packModel)
								local score = (rank or 1) * 10000 + (mult or 1) * 100 + (weight or 0)
								if score > bestScore then
									bestScore = score
									bestDropped = p
								end
							end
						end
					end
				end
			end
			if bestDropped then return bestDropped, nil end
		end

		-- 4. หากไม่พบแพ็คที่ตรงตามเกรด ให้รวบรวมข้อมูลเกรดที่พบในด่านเพื่อแจ้งเตือน
		local diagReason = "ยังไม่มีแพ็คเกิดในด่าน"
		local root = folder and folder:FindFirstChild("SpawnedPacks")
		if root then
			local count = 0
			local rarityCounts = {}
			for _, model in ipairs(root:GetChildren()) do
				local p = model:FindFirstChild("StealPrompt", true)
				if p and p:IsA("ProximityPrompt") and p.Enabled then
					count = count + 1
					local rName = getModelRarity(model)
					rarityCounts[rName] = (rarityCounts[rName] or 0) + 1
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
		return p0 + dir * (radius or 4)
	end

	local function stealFromStage(i, knownPrompt)
		local prompt = knownPrompt or checkStageHasPacks(i)
		if not prompt then return false, "ไม่มีแพ็คให้ขโมย/ด่านปิด" end

		Helpers.GetPlotSpawnPos() -- แคชพิกัดฐานก่อนออกจากฐาน (กัน Plot stream out)
		moveToCenterLane(function()
			return not Core.Flags.AutoSteal or not prompt.Parent
		end)
		if not Core.Flags.AutoSteal or not Helpers.IsAlive() then return false, "ยกเลิก/ตัวละครตาย" end

		if not prompt.Parent then
			prompt = findStealPrompt(getStageFolder(i))
			if not prompt then return false, "แพ็คถูกหยิบไปแล้ว/ด่านปิด" end
		end

		local pos = promptPos(prompt)
		if not pos then return false, "ไม่มีพิกัดแพ็ค" end

		local stageFolder = getStageFolder(i)
		local lastDiag = nil
		local lastDist = -1
		local bounds = Helpers.GetSafeZoneBounds()
		for _ = 1, 3 do
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
			if not Core.Flags.AutoSteal or not Helpers.IsAlive() or not prompt.Parent then break end
			local p0 = promptPos(prompt)
			if not p0 then break end
			stageFolder = getStageFolder(i)

			local standTarget = safeStandPos(packAnchorPos(prompt) or p0, stageFolder, 2.5)

			-- เดินเข้าไปยืนด้านที่ห่างบอสที่สุดให้ชิดระยะ Prompt จริง (<= 3.5 studs)
			Helpers.MoveTo(standTarget, function()
				return not Core.Flags.AutoSteal or not prompt.Parent
			end, { precise = true, arriveDist = 2.0, evadeEnemies = true })
			if not Core.Flags.AutoSteal or not Helpers.IsAlive() or not prompt.Parent then break end
			local hrp = Helpers.GetRoot()
			local pNow = packAnchorPos(prompt) or promptPos(prompt)
			if hrp and pNow then
				lastDist = (hrp.Position - pNow).Magnitude
				if lastDist > 4.8 then
					local flat = Vector3.new(hrp.Position.X - pNow.X, 0, hrp.Position.Z - pNow.Z)
					local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(-1, 0, 0)
					Helpers.Teleport(CFrame.new(Vector3.new(pNow.X + dir.X * 2.5, math.max(hrp.Position.Y, 69), pNow.Z + dir.Z * 2.5)))
					lastDist = (hrp.Position - pNow).Magnitude
				end
			end
			task.wait(0.05)
			local promptDiag = usePrompt(prompt, "auto", stageFolder)
			lastDiag = promptDiag
			local got = waitUntil(Helpers.IsCarrying, 0.6)
			if not got and Core.Flags.AutoSteal and Helpers.IsAlive() and prompt.Parent then
				local fallDiag = usePrompt(prompt, "hold_only", stageFolder) -- สำรอง
				got = waitUntil(Helpers.IsCarrying, 0.8)
				if not got then
					lastDiag = {
						began = promptDiag.began or fallDiag.began,
						trig = promptDiag.trig or fallDiag.trig,
						fireTrig = promptDiag.trig,
					}
				else
					lastDiag = fallDiag
				end
			end
			if got or Helpers.IsCarrying() then break end
		end
		if not Helpers.IsCarrying() then
			local b = lastDiag and tostring(lastDiag.began) or "?"
			local t = lastDiag and tostring(lastDiag.trig) or "?"
			return false, string.format("หยิบไม่สำเร็จ(b=%s,t=%s,d=%.0f)", b, t, lastDist)
		end

		return deliver(stageFolder)
	end

	local function returnToSafeRest(allowTreadmill)
		if not Helpers.IsAlive() or Helpers.IsCarrying() then return end
		-- หากอยู่บนลู่วิ่งอยู่แล้ว ให้คงสถานะวิ่ง ไม่ต้องเดินหรือขยับตัว
		if LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then return end

		local canEnter = allowTreadmill and (Core.Flags.AutoSteal or Core.Flags.AutoEnter or Core.Flags.AutoTreadmill)

		-- หากต้องการขึ้นลู่วิ่ง ให้ลองขึ้นทันที
		if canEnter then
			enterTreadmill()
			if LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then return end
		end

		local pos = Helpers.GetPlotSpawnPos()
		if not pos then return end
		local hrp = Helpers.GetRoot()
		if not hrp then return end
		local bounds = Helpers.GetSafeZoneBounds()
		local flatDistToBase = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if flatDistToBase > 20 or hrp.Position.X > (bounds.maxX - 15) then
			Helpers.MoveTo(pos + Vector3.new(0, 3, 0), function()
				return not Core._alive or not Core.Flags.AutoSteal
			end, { precise = false, arriveDist = 8 })
		end
		if canEnter then
			enterTreadmill()
		end
	end

	runBaseMaintenance = function()
		if not Core._alive then return end
		-- Priority 1: ฟัก/เก็บแพ็คที่พร้อมเปิด เพื่อเคลียร์แท่นและเปิดพื้นที่ว่างบนฐาน
		if Core.Flags.AutoOpenPacks and openReadyPlacedPacks then
			pcall(openReadyPlacedPacks)
		end

		local count = (getPacksToPlace and #getPacksToPlace()) or 0

		-- Priority 2: หากมีแพ็คที่รวมได้ (ต้องมีในกระเป๋าอย่างน้อย 2 ใบ) ให้รวมให้เรียบร้อยก่อนนำไปวาง
		if count >= 2 and (Core.Flags.AutoMerge or Core.Flags.AutoPlacePacks) and autoMergeStep then
			pcall(autoMergeStep)
		end

		-- Priority 3: นำแพ็คในกระเป๋าไปวางลงฐาน (เฉพาะเมื่อผู้ใช้เปิด AutoPlacePacks และฐานยังไม่เต็ม)
		if Core.Flags.AutoPlacePacks and placePacksInBase then
			if count > 0 and not isBaseFull() then
				local okPlace, resWhy = placePacksInBase()
				if isFullReason(resWhy) then
					baseFullUntil = os.clock() + 60
				end
			end
		end
	end

	local StealState = {
		bossSpeedCache = {},
		lastOrderSig = "",
		stageStealCount = 0,
		currentTargetStage = nil,
		waitingForNightReset = false,
		lastResetNightCycle = 0,
		lastQuotaLogTime = 0,
	}

	local function getStageBossSpeed(i)
		if StealState.bossSpeedCache[i] then return StealState.bossSpeedCache[i] end

		local sc = getStageConfig()
		local spdCfg = getSpeedConfig()
		local stageKey = "Stage" .. i
		local stageData = sc and sc.Stages and sc.Stages[stageKey]
		if stageData then
			-- ด่าน 1 มีระบุ WalkSpeed ชัดเจนใน Enemy (16)
			local enemyWalkSpeed = stageData.Enemy and stageData.Enemy.WalkSpeed
			if enemyWalkSpeed and enemyWalkSpeed > 0 then
				StealState.bossSpeedCache[i] = enemyWalkSpeed
				return enemyWalkSpeed
			end
			-- ด่านอื่นๆ คำนวณความเร็ววิ่งจริงจาก RecommendedSpeed ผ่าน SpeedConfig.ToWalkSpeed
			local rec = tonumber(stageData.RecommendedSpeed)
			if rec and spdCfg and spdCfg.ToWalkSpeed then
				local ok, ws = pcall(spdCfg.ToWalkSpeed, rec, false)
				if ok and type(ws) == "number" and ws > 0 then
					StealState.bossSpeedCache[i] = ws
					return ws
				end
			end
		end

		-- Fallback ความเร็วมาตรฐานอ้างอิงจาก RecommendedSpeed ของ StageConfig จริง
		local fallbackSpeeds = {
			[1] = 16, [2] = 36, [3] = 64, [4] = 85,
			[5] = 101, [6] = 117, [7] = 135, [8] = 157,
			[9] = 207, [10] = 215, [11] = 226, [12] = 241
		}
		local spd = fallbackSpeeds[i] or (16 + i * 18)
		StealState.bossSpeedCache[i] = spd
		return spd
	end

	local function buildStageOrder()
		local mySpeed = Helpers.GetMoveSpeed()
		local margin = Core.Flags.OutrunMargin or 1.0

		local candidates = {}
		for i = 1, 12 do
			if Core.Flags["Stage" .. i] then
				local bSpd = getStageBossSpeed(i)
				-- ด่านที่ 1 เป็นด่านสอนเริ่มต้น (Tutorial) อยู่ชิด SafeZone เสมอ ตัวละครความเร็วเริ่มต้น (16) สามารถขโมยได้ปลอดภัย
				local canOutrun = (not Core.Flags.OutrunOnly) or (i == 1) or (mySpeed >= (bSpd * margin))
				if canOutrun then
					table.insert(candidates, {
						stage = i,
						bossSpeed = bSpd,
						canOutrun = canOutrun
					})
				end
			end
		end

		-- หากความเร็วตัวละครยังต่ำกว่าบอสทุกด่านที่เลือก
		if #candidates == 0 then
			local lowestSelected = nil
			for i = 1, 12 do
				if Core.Flags["Stage" .. i] then
					lowestSelected = i
					break
				end
			end
			if lowestSelected then
				local minSpd = getStageBossSpeed(lowestSelected) or 16
				local sig = string.format("TRAIN(M=%.0f,Req=%.0f)", mySpeed, minSpd)
				if sig ~= StealState.lastOrderSig then
					StealState.lastOrderSig = sig
					logAction("ฝึกซ้อม", string.format("ความเร็วเรา (%.0f) ยังต่ำกว่าด่าน %d (ต้องการ %.0f) กำลังวิ่งลู่วิ่งเพื่อปั๊ม Speed...", mySpeed, lowestSelected, minSpd), true)
				end
			else
				local sig = "NO_STAGE_SELECTED"
				if sig ~= StealState.lastOrderSig then
					StealState.lastOrderSig = sig
					logAction("ด่านเป้าหมาย", "ยังไม่ได้เลือกด่านที่ต้องการขโมยในเมนู (กรุณาติ๊กเลือกอย่างน้อย 1 ด่าน)", false)
				end
			end
			return {}
		end

		-- เรียงลำดับหาด่านเดียวที่บอสเร็วที่สุดที่เราวิ่งทัน (bossSpeed สูงสุด)
		table.sort(candidates, function(a, b)
			if a.bossSpeed ~= b.bossSpeed then
				return a.bossSpeed > b.bossSpeed
			end
			return a.stage > b.stage
		end)

		local best = candidates[1]
		local sig = string.format("S%d(B=%.0f,M=%.0f)", best.stage, best.bossSpeed, mySpeed)
		if sig ~= StealState.lastOrderSig then
			StealState.lastOrderSig = sig
			local info = (best.stage == 1 and mySpeed < best.bossSpeed)
				and string.format("เลือกด่าน 1 (ด่านเริ่มต้น/เควสต์สอนเล่น | เราเร็ว %.0f)", mySpeed)
				or string.format("เลือกด่าน %d (บอสเร็วที่สุดที่วิ่งทัน %.0f | เราเร็ว %.0f)", best.stage, best.bossSpeed, mySpeed)
			logAction("ด่านเป้าหมาย", info, true)
		end

		return { best.stage }
	end

	-----------------------------------------------------------------
	-- NIGHT & PACK RESET HELPERS
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

	local function getTimeUntilNight()
		local nf = getNightFolder()
		if not nf then return 0 end
		if nf:GetAttribute("NightActive") == true then return 0 end
		local endsAt = tonumber(nf:GetAttribute("NightPhaseEndsAt")) or 0
		local now = workspace:GetServerTimeNow()
		return math.max(0, math.ceil(endsAt - now))
	end

	local function stealCycle()
		-- 1. ตรวจสอบด่านเป้าหมายเพียงด่านเดียวที่บอสเร็วที่สุดที่เราวิ่งทัน
		local targetStages = buildStageOrder()
		if #targetStages == 0 then
			if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil and Helpers.IsAlive() and not Helpers.IsCarrying() then
				returnToSafeRest(true)
			end
			task.wait(1.0)
			return
		end

		local i = targetStages[1]
		local maxPacks = Core.Flags.MaxStageStealPacks or 4
		local currentPending = (getPacksToPlace and #getPacksToPlace()) or 0

		-- หากสลับด่านเป้าหมาย ให้รีเซ็ตตัวนับรอบ
		if StealState.currentTargetStage ~= i then
			StealState.currentTargetStage = i
			StealState.stageStealCount = 0
			StealState.waitingForNightReset = false
		end

		local isNight = isNightActive()
		local currentPhaseEndsAt = getNightPhaseEndsAt()

		-- ตรวจจับการรีเซ็ตแพ็คการ์ดทุกด่านเมื่อเข้าสู่ช่วงเวลากลางคืน (Night Active)
		if isNight and StealState.lastResetNightCycle ~= currentPhaseEndsAt then
			StealState.lastResetNightCycle = currentPhaseEndsAt
			if StealState.waitingForNightReset or StealState.stageStealCount > 0 then
				StealState.waitingForNightReset = false
				StealState.stageStealCount = 0
				logAction("ขโมย", string.format("🌙 ด่าน %d: กลางคืนมาถึงแล้ว! แพ็คการ์ดทุกด่านรีเซ็ตใหม่ทั้งหมด -> เริ่มรอบขโมยการ์ด 4 ใบใหม่", i), true)
			end
		end

		-- ตรวจสอบโควต้าการขโมย:
		-- หากเปิดระบบจำกัดโควต้า (MaxStageStealPacks < 999) และขโมยในรอบนี้ครบจำนวนแล้ว (stageStealCount >= maxPacks) หรือรอเวลากลางคืน
		local quotaActive = (Core.Flags.MaxStageStealPacks ~= nil and Core.Flags.MaxStageStealPacks < 999)
		local quotaReached = quotaActive and (StealState.waitingForNightReset or (StealState.stageStealCount >= maxPacks))

		if quotaReached then
			-- หากถึงเวลากลางคืนแล้ว ให้ปลดสถานะรอเริ่มรอบใหม่
			if isNight then
				StealState.waitingForNightReset = false
				StealState.stageStealCount = 0
			else
				local now = os.clock()
				if now - StealState.lastQuotaLogTime > 15 then
					StealState.lastQuotaLogTime = now
					local secUntilNight = getTimeUntilNight()
					local timeStr = isNight and "กำลังอยู่ในช่วงกลางคืน (แพ็ครีเซ็ตแล้ว)"
						or (secUntilNight > 60 and string.format("เหลืออีก %d นาที %02d วิ", math.floor(secUntilNight / 60), secUntilNight % 60)
							or string.format("เหลืออีก %d วิ", secUntilNight))

					local reason = string.format("ขโมยครบโควต้า %d/%d ใบแล้ว -> พักบนลู่วิ่ง รอแพ็คการ์ดรีเซ็ตตอนกลางคืน (%s)", StealState.stageStealCount, maxPacks, timeStr)
					logAction("ขโมย", reason .. " -> พักบนลู่วิ่งฝึกซ้อม", false)
				end

				if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil and Helpers.IsAlive() and not Helpers.IsCarrying() then
					returnToSafeRest(true)
				end

				if runBaseMaintenance then
					pcall(runBaseMaintenance)
				end

				task.wait(1.0)
				return
			end
		end

		if not Core.Flags["Stage" .. i] or not Helpers.IsAlive() then
			return
		end

		local prompt, diagReason = checkStageHasPacks(i)
		if not prompt then
			-- ลอง Stream ซ้ำอีกครั้งก่อนตัดสินใจพัก
			local basePos = STAGE_CENTERS[i]
			if basePos then
				Helpers.StreamAround(basePos, 1.5)
				prompt, diagReason = checkStageHasPacks(i)
			end
		end

		if not prompt then
			-- ในด่านยังไม่มีแพ็คตามเกรดที่เลือกเกิดใหม่ ให้กลับขึ้นลู่วิ่งรอ
			local now = os.clock()
			if now - StealState.lastQuotaLogTime > 15 then
				StealState.lastQuotaLogTime = now
				local reason = diagReason or "ยังไม่มีแพ็คเกิดในด่าน"
				logAction("ขโมย", string.format("ด่าน %d: %s -> พักบนลู่วิ่งรอเกรดที่เลือกเกิดใหม่", i, reason), false)
			end
			if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil and Helpers.IsAlive() and not Helpers.IsCarrying() then
				returnToSafeRest(true)
			end
			task.wait(1.5)
			return
		end

		Core.Busy = true
		leaveTreadmill()
		local packModel = prompt.Parent
		while packModel and packModel ~= Workspace and not packModel:IsA("Model") do
			packModel = packModel.Parent
		end
		local rName = packModel and getModelRarity(packModel) or "Pack"
		local pName = packModel and (packModel:GetAttribute("PackName") or packModel.Name) or ""
		local ok, res, why = pcall(stealFromStage, i, prompt)
		stopPin()
		Core.Busy = false

		if ok and res then
			StealState.stageStealCount = StealState.stageStealCount + 1
			Stats.stealOk = Stats.stealOk + 1
			local info = (pName ~= "" and pName ~= rName)
				and string.format("ด่าน %d [%s - %s]: สำเร็จ (ใบที่ %d/%d)", i, tostring(rName), tostring(pName), StealState.stageStealCount, maxPacks)
				or string.format("ด่าน %d [%s]: สำเร็จ (ใบที่ %d/%d)", i, tostring(rName), StealState.stageStealCount, maxPacks)
			logAction("ขโมย", info, true)

			-- จัดการนำแพ็คไปรวม/วางที่ฐาน
			if (Core.Flags.AutoPlacePacks or Core.Flags.AutoOpenPacks) and runBaseMaintenance then
				local waitSyncEnd = os.clock() + 2.0
				while os.clock() < waitSyncEnd and Core._alive and Core.Flags.AutoSteal do
					local count = (getPacksToPlace and #getPacksToPlace()) or 0
					if count > 0 then break end
					task.wait(0.15)
				end
				runBaseMaintenance()
			end

			-- หากขโมยในรอบนี้ครบโควต้าแล้ว ให้กลับฐานขึ้นลู่วิ่งและรอการรีเซ็ตตอนกลางคืน
			if quotaActive and StealState.stageStealCount >= maxPacks then
				StealState.waitingForNightReset = true
				local secUntilNight = getTimeUntilNight()
				local timeStr = secUntilNight > 60
					and string.format("%d นาที %02d วิ", math.floor(secUntilNight / 60), secUntilNight % 60)
					or string.format("%d วิ", secUntilNight)
				logAction("ขโมย", string.format("ขโมยการ์ดที่ดีที่สุดครบ %d/%d ใบในด่าน %d แล้ว -> กลับฐานขึ้นลู่วิ่งรอแพ็คการ์ดรีเซ็ตทุกด่านตอนกลางคืน (เหลืออีก %s)", StealState.stageStealCount, maxPacks, i, timeStr), true)
				if runBaseMaintenance then pcall(runBaseMaintenance) end
				returnToSafeRest(true)
			end
		else
			Stats.stealFail = Stats.stealFail + 1
			local reason = res
			if ok then reason = why or "ไม่ทราบสาเหตุ" end
			logAction("ขโมย", "ด่าน " .. i .. ": " .. tostring(reason), false)
			-- รอให้ตัวละครฟื้นตัว/เกิดใหม่สมบูรณ์ก่อนเริ่มรอบถัดไป
			task.wait(1.2)
			waitUntil(function()
				local char = LocalPlayer.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				return char and hum and hum.Health > 0
			end, 3.0)
		end

		task.wait(Core.Flags.StealDelay)
	end

	function Loops.Steal()
		Core:Loop("steal", "AutoSteal", 0.5, stealCycle)
	end

	Core:OnCleanup(stopPin)

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

	local function getBackpackCandidates(mode) -- mode: "merge" or "fuse"
		local now = os.clock()
		local favMap = getPlayerDataKey("Favorited")
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local packsData = inv and inv.Packs or {}
		local pc = getPacksConfig()
		local maxMerges = (pc and pc.MaxMergesPerPack) or 2
		local seenIds = {}
		local candidates = {}

		local function isFav(id, tool)
			if type(favMap) == "table" and favMap[id] == true then return true end
			if tool and isToolFavorited and isToolFavorited(tool, id, favMap) then return true end
			return false
		end

		local function normMutation(mut)
			if mut == nil or mut == "" or mut == "None" or mut == false then
				return "Normal"
			end
			return tostring(mut)
		end

		-- 1. สแกนจาก Tools ใน Backpack / Character
		for _, tool in ipairs(getBagTools(false)) do
			local packId = tool:GetAttribute("PackId")
			if type(packId) == "string" and packId ~= "" and not seenIds[packId] then
				local isSkip = (itemSkipUntil[mode .. ":" .. packId] or 0) > now or permSkipItems[mode .. ":" .. packId]
				if not isSkip and not isFav(packId, tool) then
					local isUnit = tool:GetAttribute("CardIsPack") == false or tool:GetAttribute("ItemCategory") == "Units" or tool:GetAttribute("CharacterName") ~= nil
					local isPack = not isUnit and (tool:GetAttribute("CardIsPack") == true or tool:GetAttribute("ItemCategory") == "Packs")
					local mut = normMutation(getToolMutation(tool))

					if mode == "merge" and isPack then
						local name = tool:GetAttribute("PackName") or tool.Name
						local mergeCount = tonumber(tool:GetAttribute("MergeCount")) or 0
						if type(name) == "string" and name ~= "" and mergeCount < maxMerges then
							seenIds[packId] = true
							table.insert(candidates, {
								Id = packId,
								Name = name,
								Mutation = mut,
								MergeCount = mergeCount,
								Raw = tool,
							})
						end
					elseif mode == "fuse" and isUnit then
						local name = tool:GetAttribute("CharacterName") or tool.Name
						if type(name) == "string" and name ~= "" then
							seenIds[packId] = true
							table.insert(candidates, {
								Id = packId,
								Name = name,
								Mutation = mut,
								Raw = tool,
							})
						end
					end
				end
			end
		end

		-- 2. สแกนจาก Inventory.Packs.Backpack (PlayerData) เผื่อ Tool ยังไม่โหลด
		local bpList = (type(packsData.Backpack) == "table" and packsData.Backpack) or {}
		for _, item in pairs(bpList) do
			if type(item) == "table" and type(item.Id) == "string" and not seenIds[item.Id] then
				local packId = item.Id
				local isSkip = (itemSkipUntil[mode .. ":" .. packId] or 0) > now or permSkipItems[mode .. ":" .. packId]
				if not isSkip and not isFav(packId, nil) and item.OpeningCommittedAt == nil then
					local isChar = (pc and pc.IsCharacter and pc.IsCharacter(item)) or item.Kind == "Character" or item.CharacterName ~= nil or item.ItemCategory == "Units"
					local isPath = (pc and pc.IsPathPack and pc.IsPathPack(item))
					local mut = normMutation(item.Mutation)

					if mode == "merge" and not isChar and not isPath then
						local name = item.PackName or item.Name
						local mergeCount = (pc and pc.GetMergeCount and pc.GetMergeCount(item)) or tonumber(item.MergeCount) or 0
						if type(name) == "string" and name ~= "" and mergeCount < maxMerges then
							seenIds[packId] = true
							table.insert(candidates, {
								Id = packId,
								Name = name,
								Mutation = mut,
								MergeCount = mergeCount,
								Raw = item,
							})
						end
					elseif mode == "fuse" and isChar then
						local name = item.CharacterName or item.PackName or item.Name
						if type(name) == "string" and name ~= "" then
							seenIds[packId] = true
							table.insert(candidates, {
								Id = packId,
								Name = name,
								Mutation = mut,
								Raw = item,
							})
						end
					end
				end
			end
		end

		-- 3. สแกนจาก Inventory.Packs.Placed (เฉพาะ mode == "fuse" สำหรับยูนิตที่กำลังใช้งานอยู่)
		-- หมายเหตุ: สำหรับ mode == "merge" แพ็คที่วางบนแท่นฟักฐานไม่สามารถรวมที่ MutateMachine ได้ จึงไม่ดึงมาเพื่อป้องกันเซิร์ฟเวอร์ปฏิเสธ
		if mode == "fuse" then
			local placedList = (type(packsData.Placed) == "table" and packsData.Placed) or {}
			for _, item in pairs(placedList) do
				if type(item) == "table" and type(item.Id) == "string" and not seenIds[item.Id] then
					local packId = item.Id
					local isSkip = (itemSkipUntil[mode .. ":" .. packId] or 0) > now or permSkipItems[mode .. ":" .. packId]
					if not isSkip and not isFav(packId, nil) and item.OpeningCommittedAt == nil then
						local isChar = (pc and pc.IsCharacter and pc.IsCharacter(item)) or item.Kind == "Character" or item.CharacterName ~= nil or item.ItemCategory == "Units"
						local mut = normMutation(item.Mutation)
						if isChar then
							local name = item.CharacterName or item.PackName or item.Name
							if type(name) == "string" and name ~= "" then
								seenIds[packId] = true
								table.insert(candidates, {
									Id = packId,
									Name = name,
									Mutation = mut,
									Raw = item,
								})
							end
						end
					end
				end
			end
		end

		-- 4. สแกนจาก Coaches (PlayerData.Coaches) สำหรับ mode == "fuse"
		if mode == "fuse" then
			local cu = getCoachUtil()
			local coachData = getPlayerDataKey("Coaches")
			if cu and cu.GetItems and type(coachData) == "table" then
				local coachItems = cu.GetItems(coachData)
				for _, item in ipairs(coachItems) do
					local cId = item.Id
					local isSkip = (itemSkipUntil[mode .. ":" .. cId] or 0) > now or permSkipItems[mode .. ":" .. cId]
					local canMut = cu.CanMutate and cu.CanMutate(item.CoachId)
					if not isSkip and canMut and not seenIds[cId] then
						local cEntry = cu.Get and cu.Get(item.CoachId)
						local name = (cEntry and cEntry.Name) or item.CoachId
						local mut = normMutation(item.Mutation)
						seenIds[cId] = true
						table.insert(candidates, {
							Id = cId,
							Name = name,
							Mutation = mut,
							Kind = "Coach",
							Raw = item,
						})
					end
				end
			end
		end

		return candidates
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
			local ranks = (pc and pc.RarityRank) or {}
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

	autoMergeStep = function()
		if Core.Busy or Helpers.IsCarrying() then return end
		local now = os.clock()
		local mc = getMutateConfig()
		local rl = math.max((mc and mc.RateLimit) or 0.35, 0.35)
		if now - lastMerge < 3.0 then return end

		-- 1. ตรวจสอบจำนวนแพ็คจริงในตัวก่อน: ต้องมีแพ็คในกระเป๋าอย่างน้อย 2 ชิ้นจึงจะเริ่มตรวจสอบคู่
		local pendingPacks = (getPacksToPlace and getPacksToPlace()) or {}
		if #pendingPacks < 2 then return end

		local candidates = getBackpackCandidates("merge")
		local groups = {}
		for _, c in ipairs(candidates) do
			local key = c.Name .. "|" .. c.Mutation
			groups[key] = groups[key] or { name = c.Name, mut = c.Mutation, list = {} }
			table.insert(groups[key].list, c)
		end

		-- คัดกรองเฉพาะกลุ่มที่มีแพ็คพร้อมรวมตั้งแต่ 2 ชิ้นขึ้นไปเท่านั้น (Readiness Pre-check)
		local eligibleGroups = {}
		local totalPairs = 0
		for _, g in pairs(groups) do
			if #g.list >= 2 then
				table.insert(eligibleGroups, g)
				totalPairs = totalPairs + math.floor(#g.list / 2)
			end
		end

		-- หากไม่มีแพ็คที่พร้อมรวมเป็นคู่ในกระเป๋าเลย ให้หยุดทันที (ไม่เดิน ไม่วาร์ป และไม่ยิงรีโมท)
		if totalPairs == 0 then return end

		-- ตรวจสอบสถานะตัวละคร: ต้องมีชีวิต ไม่ติดล้ม (Ragdolled) และไม่กำลังถือของ
		local char = LocalPlayer.Character
		if not Helpers.IsAlive() or Helpers.IsCarrying() or (char and char:GetAttribute("Ragdolled") == true) then
			return
		end

		lastMerge = now

		local okVisit, mergedTotal = Helpers.VisitMutateMachine(function()
			local count = 0
			for _, g in ipairs(eligibleGroups) do
				if not (Core._alive and Core.Flags.AutoMerge) then break end
				local list = g.list
				local pName = g.name
				local firstId = list[1] and list[1].Id

				-- 1. ลองใช้ MergeAll ก่อน (ยิงคำสั่งเดียวเพื่อรวมทั้งกลุ่มในกระเป๋า)
				local okAll, resAll = Net.Invoke(Net.Paths.MutateMergeAll, firstId)
				local sAll, rAll = isRemoteOk(resAll)
				if okAll and sAll then
					local pairsInGroup = math.floor(#list / 2)
					count = count + math.max(pairsInGroup, 1)
					task.wait(rl)
				else
					-- 2. Fallback รวมทีละคู่ หากเซิร์ฟเวอร์ไม่รองรับ MergeAll
					local i = 1
					while i + 1 <= #list do
						if not (Core._alive and Core.Flags.AutoMerge) then break end
						local idA = list[i].Id
						local idB = list[i + 1].Id

						local okPair, resPair = Net.Invoke(Net.Paths.MutateMerge, { idA, idB })
						local sPair, rPair = isRemoteOk(resPair)
						if okPair and sPair then
							count = count + 1
							task.wait(rl)
						else
							local failReason = rPair or rAll or "REJECTED"
							if failReason == "MERGE_LIMIT" then
								permSkipItems["merge:" .. idA] = true
								permSkipItems["merge:" .. idB] = true
								logAction("Merge", pName .. " ถึงลิมิตรวมซ้ำแล้ว (Max)", false)
							else
								itemSkipUntil["merge:" .. idA] = os.clock() + 30
								itemSkipUntil["merge:" .. idB] = os.clock() + 30
								logAction("Merge", "รวม " .. tostring(pName) .. " พลาด: " .. tostring(failReason), false)
							end
							break -- หากคู่นี้รวมไม่ได้ ให้ข้ามกลุ่มนี้ไปก่อน
						end
						i = i + 2
					end
				end
			end
			return count
		end)

		if okVisit and type(mergedTotal) == "number" and mergedTotal > 0 then
			logAction("Merge", string.format("รวมแพ็คสำเร็จ %d คู่ (หมดตัว)", mergedTotal), true)
		end
	end

	local function autoFuseStep()
		if Core.Busy or Helpers.IsCarrying() then return end
		local now = os.clock()
		local mc = getMutateConfig()
		local rl = math.max((mc and mc.RateLimit) or 0.38, 0.38)
		if now - lastFuse < 1.0 then return end

		local candidates = getBackpackCandidates("fuse")
		local groups = {}
		for _, c in ipairs(candidates) do
			local key = c.Name .. "|" .. c.Mutation
			groups[key] = groups[key] or { name = c.Name, mut = c.Mutation, list = {} }
			table.insert(groups[key].list, c)
		end

		local triosToFuse = {}
		for _, g in pairs(groups) do
			local list = g.list
			local i = 1
			while i + 2 <= #list do
				table.insert(triosToFuse, {
					itemA = list[i],
					itemB = list[i + 1],
					itemC = list[i + 2],
					charName = g.name,
					mut = g.mut,
				})
				i = i + 3
			end
		end

		if #triosToFuse == 0 then return end
		lastFuse = now

		local okVisit, fusedTotal = Helpers.VisitMutateMachine(function()
			local count = 0
			for _, trio in ipairs(triosToFuse) do
				if not (Core._alive and Core.Flags.AutoFuse) then break end
				local idA = trio.itemA.Id
				local idB = trio.itemB.Id
				local idC = trio.itemC.Id
				local cName = trio.charName

				local okFuse, resFuse = Net.Invoke(Net.Paths.MutateFuse, { idA, idB, idC })
				local sFuse, rFuse = isRemoteOk(resFuse)
				if okFuse and sFuse then
					count = count + 1
					local mutResult = (type(resFuse) == "table" and ((resFuse.Coach and resFuse.Coach.Mutation) or (resFuse.Character and resFuse.Character.Mutation))) or "สำเร็จ"
					logAction("Fuse", string.format("กลายพันธุ์ %s สำเร็จ! (%s)", tostring(cName), tostring(mutResult)), true)
					task.wait(rl)
				else
					local failReason = rFuse or "REJECTED"
					if failReason == "MAX_MUTATION" then
						permSkipItems["fuse:" .. idA] = true
						permSkipItems["fuse:" .. idB] = true
						permSkipItems["fuse:" .. idC] = true
						logAction("Fuse", cName .. " ถึงระดับกลายพันธุ์สูงสุดแล้ว", false)
					else
						itemSkipUntil["fuse:" .. idA] = os.clock() + 6
						itemSkipUntil["fuse:" .. idB] = os.clock() + 6
						itemSkipUntil["fuse:" .. idC] = os.clock() + 6
						logAction("Fuse", "กลายพันธุ์ " .. tostring(cName) .. " พลาด: " .. tostring(failReason), false)
					end
				end
			end
			return count
		end)

		if okVisit and type(fusedTotal) == "number" and fusedTotal > 0 then
			logAction("Fuse", string.format("กลายพันธุ์สำเร็จทั้งหมด %d ชุด (หมดตัว)", fusedTotal), true)
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
	end

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

			-- หากมีแพ็คในกระเป๋าตั้งแต่ 2 ชิ้นขึ้นไป ให้รวมแบบ Multi-Pass จนกว่าจะหมดคู่ก่อนนำไปวางที่ฐาน
			if #packs >= 2 and (Core.Flags.AutoMerge or Core.Flags.AutoPlacePacks) and autoMergeStep then
				local maxPasses = 4
				while maxPasses > 0 and Core._alive do
					maxPasses = maxPasses - 1
					local currentPacks = getPacksToPlace()
					if #currentPacks < 2 then break end

					local mergeCandidates = getBackpackCandidates and getBackpackCandidates("merge") or {}
					local counts = {}
					local hasPairs = false
					for _, c in ipairs(mergeCandidates) do
						local k = c.Name .. "|" .. c.Mutation
						counts[k] = (counts[k] or 0) + 1
						if counts[k] >= 2 then
							hasPairs = true
							break
						end
					end
					if not hasPairs then break end
					local okMerge = pcall(autoMergeStep)
					if not okMerge then break end
					task.wait(0.35)
				end
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

			-- ตรวจสอบตำแหน่งตัวละคร: หากอยู่นอกเขตฐานไกลเกิน 55 studs จึงจะเดินกลับเข้ามาที่ฐาน
			-- หากยืนอยู่บนฐานของตนเองอยู่แล้ว (รวมถึงบนลู่วิ่ง) ไม่ต้องเดิน MoveTo ไปกลาง AnimeArea ซ้ำซ้อน
			local hrp = Helpers.GetRoot()
			local isTraining = LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil
			if not isTraining and hrp and basePos and (hrp.Position - basePos).Magnitude > 55 then
				Helpers.MoveTo(basePos + Vector3.new(0, 2.5, 0), function()
					return not Core._alive or not Core.Flags.AutoPlacePacks
				end, { precise = false, arriveDist = 10 })
			end

			local placementUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.PlacementUtil end)
			local halfX, halfZ = 16, 12
			if area and area:IsA("BasePart") then
				halfX = math.max((area.Size.X - 4) / 2, 8)
				halfZ = math.max((area.Size.Z - 4) / 2, 8)
			end

			local noSpace = false
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local loopPass = 0

			while Core._alive and Core.Flags.AutoPlacePacks and not noSpace do
				loopPass = loopPass + 1
				if loopPass > 30 then break end

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
							task.wait(0.15)
						end
						pcall(function()
							Net.Fire(Net.Paths.ToolsRequestEquip, nil, {
								Equipped = true,
								Tool = packTool
							})
						end)
						task.wait(0.1)
					end

					-- คำนวณระดับความสูงพื้นแปลงเพาะ (AnimeArea.Position.Y + 0.3 studs ตาม PlacementLiftStuds)
					local surfaceY = (area and area:IsA("BasePart") and (area.Position.Y + 0.3)) or (basePos.Y + 0.3)

					-- พยายามวางหลายๆ จุด ถ้าชน OVERLAPS_PACK ให้สุ่มพิกัดใหม่ (ลองสูงสุด 15 จุด)
					for attempt = 1, 15 do
						local placePos = nil
						if placementUtil and placementUtil.RandomPointInArea and area then
							local okPt, pt = pcall(placementUtil.RandomPointInArea, area)
							if okPt and typeof(pt) == "Vector3" then
								placePos = Vector3.new(pt.X, surfaceY, pt.Z)
							end
						end
						if not placePos then
							local rx = (math.random() - 0.5) * 2 * halfX
							local rz = (math.random() - 0.5) * 2 * halfZ
							if area and area:IsA("BasePart") then
								local worldPt = area.CFrame:PointToWorldSpace(Vector3.new(rx, 0, rz))
								placePos = Vector3.new(worldPt.X, surfaceY, worldPt.Z)
							else
								placePos = Vector3.new(basePos.X + rx, surfaceY, basePos.Z + rz)
							end
						end

						local ok, res = Net.Invoke(Net.Paths.PlaceOwned, {
							PackId = packId,
							Position = placePos,
						})
						local success, reason = isRemoteOk(res)
						if ok and success then
							placedThis = true
							placedAnyInPass = true
							logAction("วางแพ็ก", "นำลงเพาะในฐาน: " .. tostring(packName), true)
							itemSkipUntil["place:" .. packId] = nil
							if hum then pcall(function() hum:UnequipTools() end) end
							task.wait(0.25)
							break
						else
							lastReason = reason or "FAILED"
							if reason == "NOT_OWNED" or reason == "ALREADY_PLACED" then
								placedThis = true
								placedAnyInPass = true
								if hum then pcall(function() hum:UnequipTools() end) end
								break
							elseif reason == "NOT_EQUIPPED" then
								-- เซิร์ฟเวอร์แจ้งว่ายังไม่ได้ถือ Tool ให้ลอง Equip ซ้ำ
								if hum and packTool then
									pcall(function() hum:EquipTool(packTool) end)
									task.wait(0.2)
								end
							elseif isFullReason(reason) then
								noSpace = true
								break
							end
							task.wait(0.05)
						end
					end

					if not placedThis then
						if isFullReason(lastReason) or noSpace then
							noSpace = true
							baseFullUntil = os.clock() + 60
							itemSkipUntil["place:" .. packId] = os.clock() + 60
							logAction("วางแพ็ก", "ฐานไม่มีที่ว่างสำหรับวาง " .. tostring(packName) .. " (" .. tostring(lastReason) .. ")", false)
							break
						elseif lastReason == "OVERLAPS_PACK" then
							itemSkipUntil["place:" .. packId] = os.clock() + 4
							logAction("วางแพ็ก", "พิกัดวางชนแพ็คอื่น: " .. tostring(packName) .. " (จะลองใหม่)", false)
						else
							itemSkipUntil["place:" .. packId] = os.clock() + 3
							logAction("วางแพ็ก", "วางไม่สำเร็จ: " .. tostring(packName) .. " (" .. tostring(lastReason) .. ")", false)
						end
					end
				end

				if noSpace or not placedAnyInPass then
					break
				end
				task.wait(0.15)
			end

			-- ปลดการถือ Tool เมื่อวางเสร็จสิ้นทั้งหมด
			if hum then pcall(function() hum:UnequipTools() end) end

			if noSpace then
				baseFullUntil = os.clock() + 60
				logAction("วางแพ็ก", "ไม่มีที่วางในฐานแล้ว -> รอแพ็คฟักเพื่อเปิดพื้นที่", false)
				return false, "NO_SPACE"
			end

			return true
		end)

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
		Core:Loop("placePacks", "AutoPlacePacks", 1.5, function()
			if not Core.Busy and not Helpers.IsCarrying() then
				if not isBaseFull() and getPacksToPlace and #getPacksToPlace() > 0 then
					if placePacksInBase then placePacksInBase() end
				end
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

	function Loops.Merge()
		task.spawn(autoMergeStep)
		Core:Loop("mergePacks", "AutoMerge", 4.0, autoMergeStep)
	end

	function Loops.Fuse()
		task.spawn(autoFuseStep)
		Core:Loop("fuseUnits", "AutoFuse", 1.8, autoFuseStep)
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
				nextIndexClaim = now + 20
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

		-- ล้าง UI เก่าถ้ามีอยู่
		local oldUI = (CoreGui and CoreGui:FindFirstChild("KUYKUY_ScreenGui"))
			or (LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("KUYKUY_ScreenGui"))
			or (CoreGui and CoreGui:FindFirstChild("KuykuyHub"))
			or (LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("KuykuyHub"))
		if oldUI then pcall(function() oldUI:Destroy() end) end

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

			local state = initialValue
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
				logAction("สวิตช์", (state and "เปิด: " or "ปิด: ") .. title, state)
				if callback then callback(state) end
				if Config and Config.Save then Config.Save() end
			end

			toggleTrack.MouseButton1Click:Connect(onToggle)
			pcall(function()
				if toggleTrack.Activated then toggleTrack.Activated:Connect(onToggle) end
			end)
		end

		local function CreateButton(parent, text, bgColor, callback)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, 0, 0, 34)
			btn.BackgroundColor3 = bgColor or UIColors.Card
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

			for i, opt in ipairs(options) do
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
			if v then Loops.Steal() end
		end)

		CreateToggle(pFarm, "ขโมยเฉพาะด่านบอสเร็วสุดที่วิ่งทัน (Target Fastest Boss Only)", Core.Flags.TargetFastestOnly, function(v)
			Core.Flags.TargetFastestOnly = v
			StealState.lastOrderSig = ""
		end)

		CreateToggle(pFarm, "จำกัดรอบละ 4 ใบที่ดีที่สุด (Quota 4 Best Packs/Round)", Core.Flags.MaxStageStealPacks == 4, function(v)
			Core.Flags.MaxStageStealPacks = v and 4 or 999
		end)

		CreateToggle(pFarm, "ขโมยเฉพาะด่านที่วิ่งหนีบอสทัน (Outrun Boss Only)", Core.Flags.OutrunOnly, function(v)
			Core.Flags.OutrunOnly = v
			StealState.lastOrderSig = ""
		end)

		CreateToggle(pFarm, "ลบอนิเมชชั่นโดนตี/ไม่ล้ม (Anti-Ragdoll)", Core.Flags.AntiRagdollMode, function(v)
			Core.Flags.AntiRagdollMode = v
			if v then Helpers.RecoverFromHit(LocalPlayer.Character) end
		end)

		-- Stage Multi-Select Dropdown
		local stageOptions = {}
		for i = 1, 12 do
			table.insert(stageOptions, {
				value = "Stage" .. i,
				label = string.format("ด่านที่ %d (Stage %d)", i, i),
				short = tostring(i),
			})
		end
		CreateMultiSelectDropdown(pFarm, "ด่านที่ต้องการขโมย (Stages)", stageOptions, Core.Flags, function()
			-- Core.Flags updated in-place by selectedMap
		end)

		-- Pack Rarities Multi-Select Dropdown
		local rarityOptions = {
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
			{ value = "Rarity_Secret",     label = "Secret (ระดับพิเศษ)",    short = "Sec" },
		}
		CreateMultiSelectDropdown(pFarm, "เกรดของแพ็คที่ต้องการขโมย (All Grades)", rarityOptions, Core.Flags, function()
			-- Core.Flags updated in-place by selectedMap
		end)

		-- =====================================================================
		-- TAB 2: 📦 2. แพ็ก & ยูนิต (Packs & Units)
		-- =====================================================================
		AddTabButton("PackTab", "📦 2. แพ็ก & ยูนิต", false, 2)
		local pPack = CreateTabPage("PackTab")

		local PackStatusCard = CreateStatusCard(pPack, "แพ็ก & ยูนิต: กำลังสแกนข้อมูล...")

		CreateToggle(pPack, "เปิดแพ็กในกระเป๋าอัตโนมัติ (Auto Open)", Core.Flags.AutoOpenPacks, function(v)
			Core.Flags.AutoOpenPacks = v
			if v then Loops.OpenPacks() end
		end)

		CreateToggle(pPack, "วางแพ็คในฐานอัตโนมัติ (Auto Place Packs)", Core.Flags.AutoPlacePacks, function(v)
			Core.Flags.AutoPlacePacks = v
			if v then Loops.PlacePacks() end
		end)

		CreateToggle(pPack, "วางตัวดีสุดลงฐานอัตโนมัติ (EquipBest)", Core.Flags.AutoEquipBest, function(v)
			Core.Flags.AutoEquipBest = v
			if v then Loops.EquipBest() end
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

		local RARITY_NAMES = {
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
		}
		local rarityOptions = {
			"Rare (3)", "Epic (4)", "Legendary (5)", "Mythical (6)",
			"Cosmic (7)", "Divine (8)", "Omniversal (9)", "Eternal (10)",
			"Primordial (11)", "Exclusive (12)", "Godlike (13)"
		}
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

		Core.Flags.UI = true
		Core:Loop("autoSaveConfig", "UI", 30, function()
			if Config and Config.Save then
				pcall(Config.Save)
			end
		end)

		Core:Loop("status", "UI", 0.5, function()
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
	print("[Kuy] โหลดสำเร็จ | Plot:", Helpers.GetPlot() and Helpers.GetPlot().Name or "ยังไม่พบ")
end

local ok, err = pcall(main)
if not ok then
	warn("[Kuy] FATAL: " .. tostring(err))
end