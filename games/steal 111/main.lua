-- Kuykuy Hub | ขโมยแพ็คอนิเมะ (PlaceId 133151378618377)
-- โครงสร้าง: Core(State/Cleanup) -> Helpers(Plot/POI) -> Net -> Features(Treadmill, StealPacks) -> UI
-- ไม่ใช้ไวยากรณ์ type/strict เพื่อให้เข้ากับ executor ทุกตัว; error ทั้งหมดจะ warn ขึ้น console ด้วยคำนำหน้า [Kuy]

local function main()
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local ContextActionService = game:GetService("ContextActionService")
	local HttpService = game:GetService("HttpService")
	local TweenService = game:GetService("TweenService")
	local CoreGui = game:GetService("CoreGui")
	local vimOk, vimSvc = pcall(function() return game:GetService("VirtualInputManager") end)
	local VirtualInputManager = vimOk and vimSvc or nil
	local vuOk, vuSvc = pcall(function() return game:GetService("VirtualUser") end)
	local VirtualUser = vuOk and vuSvc or nil

	local LocalPlayer = Players.LocalPlayer
	local ENV = (getgenv and getgenv()) or _G

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
	Core.Flags.MaxSpeedMode = false   -- false = ความเร็วตัวละครจริง, true = ความเร็วสูงสุด 340 (เพดานเกม)
	Core.Flags.SideBypassMode = true  -- วิ่งบนทางลัดด้านข้างนอกกำแพงด่าน 1-12 เพื่อหลบบอส
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
	Core.Flags.AutoRebirth = false          -- เกิดใหม่อัตโนมัติเมื่อ Speed ถึงเกณฑ์
	Core.Flags.AutoClaim = false            -- เคลม Offline / Daily / Index อัตโนมัติ
	Core.Flags.AntiAfk = true               -- กันเตะ AFK 20 นาที
	Core.Flags.StealDelay = 1
	for i = 1, 12 do
		Core.Flags["Stage" .. i] = true
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
	local CONFIG_FILE = "kuykuy_steal111_config.json"

	local function getEnvVar(name)
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

	local function getFS()
		local w = getEnvVar("writefile") or (syn and syn.write_file) or (fluxus and fluxus.write_file) or writefile
		local r = getEnvVar("readfile") or (syn and syn.read_file) or (fluxus and fluxus.read_file) or readfile
		local i = getEnvVar("isfile") or (syn and syn.is_file) or (fluxus and fluxus.is_file) or isfile
		return w, r, i
	end

	local function serializeFallback(data)
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

	local function deserializeFallback(str)
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

	local function encodeConfig(data)
		local okJson, json = pcall(function()
			return HttpService:JSONEncode(data)
		end)
		if okJson and type(json) == "string" and #json > 2 then
			return json
		end
		return serializeFallback(data)
	end

	local function decodeConfig(str)
		if not str or type(str) ~= "string" or #str < 2 then return nil end
		local okJson, parsed = pcall(function()
			return HttpService:JSONDecode(str)
		end)
		if okJson and type(parsed) == "table" then
			return parsed
		end
		local fallbackData = deserializeFallback(str)
		if next(fallbackData) ~= nil then
			return fallbackData
		end
		return nil
	end

	local function safeWriteFile(path, content)
		local w = getFS()
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

	local function safeReadFile(path)
		local _, r, i = getFS()
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
		local encoded = encodeConfig(dataToSave)
		local diskOk, diskErr = safeWriteFile(CONFIG_FILE, encoded)
		if diskOk then
			return true, "disk"
		elseif ENV.__KUY_CONFIG_CACHE then
			return true, "session"
		end
		return false, diskErr or "save_failed"
	end

	function Config.Load()
		local okRead, content, source = safeReadFile(CONFIG_FILE)
		if not okRead or not content then
			return false, "not_found"
		end

		local parsed = decodeConfig(content)
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
	local Helpers = {}
	local plotCache = nil
	local plotSpawnPosCache = nil
	local PlotUtil, ServerData, PlayerData, SpeedConfig, PacksConfig, MutationConfig, RagdollMod, CoachConfig, CoachUtil, AurasConfig, RebirthUtil, DailyRewardsUtil, MutateConfig = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil

	local function safeRequire(getter)
		local ok, mod = pcall(function() return require(getter()) end)
		if ok and type(mod) == "table" then return mod end
		return nil
	end

	local function getPlotUtil()
		if not PlotUtil then
			PlotUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.PlotUtil end)
		end
		return PlotUtil
	end

	local function getServerData()
		if not ServerData then
			ServerData = safeRequire(function() return ReplicatedStorage.Shared.Modules.DataReceiver.ServerData end)
		end
		return ServerData
	end

	local function getPlayerData()
		if not PlayerData then
			PlayerData = safeRequire(function() return ReplicatedStorage.Shared.Modules.DataReceiver.PlayerData end)
		end
		return PlayerData
	end

	local function getSpeedConfig()
		if not SpeedConfig then
			SpeedConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.SpeedConfig end)
		end
		return SpeedConfig
	end

	local function getPacksConfig()
		if not PacksConfig then
			PacksConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.PacksConfig end)
		end
		return PacksConfig
	end

	local function getMutationConfig()
		if not MutationConfig then
			MutationConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.MutationConfig end)
		end
		return MutationConfig
	end

	local function getRagdollModule()
		if not RagdollMod then
			RagdollMod = safeRequire(function() return ReplicatedStorage.Shared.Modules.Ragdoll end)
		end
		return RagdollMod
	end

	local function getCoachConfig()
		if not CoachConfig then
			CoachConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.CoachConfig end)
		end
		return CoachConfig
	end

	local function getCoachUtil()
		if not CoachUtil then
			CoachUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.CoachUtil end)
		end
		return CoachUtil
	end

	local function getAurasConfig()
		if not AurasConfig then
			AurasConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.AurasConfig end)
		end
		return AurasConfig
	end

	local function getRebirthUtil()
		if not RebirthUtil then
			RebirthUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.RebirthUtil end)
		end
		return RebirthUtil
	end

	local function getDailyRewardsUtil()
		if not DailyRewardsUtil then
			DailyRewardsUtil = safeRequire(function() return ReplicatedStorage.Shared.Utilities.DailyRewardsUtil end)
		end
		return DailyRewardsUtil
	end

	local function getMutateConfig()
		if not MutateConfig then
			MutateConfig = safeRequire(function() return ReplicatedStorage.Shared.Configs.MutateConfig end)
		end
		return MutateConfig
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

	-- Plot ของผู้เล่น: ใช้ PlotUtil.GetPlotByUserId ของเกม (ไม่ Hardcode เลข Plot)
	function Helpers.GetPlot(force)
		if not force and plotCache and plotCache.Parent then
			return plotCache
		end
		plotCache = nil
		local util = getPlotUtil()
		if not util then return nil end
		local ok, entry = pcall(util.GetPlotByUserId, LocalPlayer.UserId)
		if not ok or type(entry) ~= "table" or entry.Name == nil then return nil end
		local plots = Workspace:FindFirstChild("Plots")
		local slot = plots and plots:FindFirstChild(tostring(entry.Name))
		plotCache = slot
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
			plotSpawnPosCache = pos
			return pos
		end
		if plotSpawnPosCache then
			return plotSpawnPosCache
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

	local mutatePadCache = nil
	function Helpers.GetMutateMachinePad()
		if mutatePadCache and mutatePadCache.Parent then
			return mutatePadCache
		end
		local m2 = Workspace:FindFirstChild("Machine2")
		local pad = m2 and m2:FindFirstChild("MutationMachine")
		if pad and pad:IsA("BasePart") then
			mutatePadCache = pad
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

	-- คำนวณความเร็วเคลื่อนที่ปลอดภัยจาก SpeedConfig.ToWalkSpeed ของตัวละคร (หรือเพดานสูงสุด 340)
	function Helpers.GetMoveSpeed()
		local sc = getSpeedConfig()
		local maxCap = (sc and sc.MaximumWalkSpeed) or 340
		if Core.Flags.MaxSpeedMode then
			return maxCap
		end
		local spdStat = nil
		local pd = getPlayerData()
		if pd and pd.Get then
			local ok, val = pcall(pd.Get, "Speed")
			if ok then spdStat = tonumber(val) end
		end
		if not spdStat then
			local ls = LocalPlayer:FindFirstChild("leaderstats")
			local sv = ls and ls:FindFirstChild("Speed")
			if sv then spdStat = tonumber(sv.Value) end
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

	-- พื้นทางเลี่ยงด้านข้าง (SideBypass): วิ่งระดับพื้นผิว (Y=67.6) นอกกำแพง AllRocks/Shell ของด่าน 1-12
	local SIDE_TOP_Y = 67.6
	local SIDE_THICKNESS = 16
	local SIDE_OFFSET_Z = 126
	local SIDE_WIDTH = 64
	local SIDE_TILES = { { 1190, 2750 }, { 2700, 4300 }, { 4250, 5850 }, { 5800, 6750 } }
	local sideFolder = nil
	local sideTiles = { north = {}, south = {} }
	local sideDisabledWalls = {}

	local function makeSideTile(name)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = false
		p.Transparency = 0.78
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(40, 140, 220)
		p.Parent = sideFolder
		return p
	end

	local function disableSideWallPart(part, safeMaxX, centerZ)
		if not part or not part:IsA("BasePart") or sideDisabledWalls[part] ~= nil then return end
		local ancModel = part:FindFirstAncestorOfClass("Model")
		if ancModel and ancModel:FindFirstChildOfClass("Humanoid") then return end

		local cf = part.CFrame
		local sx, sy, sz = part.Size.X * 0.5, part.Size.Y * 0.5, part.Size.Z * 0.5
		local rx, ry, rz = cf.RightVector, cf.UpVector, cf.LookVector
		local wx = math.abs(rx.X) * sx + math.abs(ry.X) * sy + math.abs(rz.X) * sz
		local wy = math.abs(rx.Y) * sx + math.abs(ry.Y) * sy + math.abs(rz.Y) * sz
		local wz = math.abs(rx.Z) * sx + math.abs(ry.Z) * sy + math.abs(rz.Z) * sz
		local pos = cf.Position
		if (pos.X - wx) < (safeMaxX - 4) or (pos.X + wx) <= (safeMaxX + 8) then return end
		if (pos.Y + wy) < 68.2 then return end

		local minZ, maxZ = pos.Z - wz, pos.Z + wz
		local inNorthWall = maxZ <= (centerZ - 55) and minZ >= (centerZ - 260)
		local inSouthWall = minZ >= (centerZ + 55) and maxZ <= (centerZ + 260)
		if not (inNorthWall or inSouthWall) then return end

		sideDisabledWalls[part] = { cc = part.CanCollide, tr = part.Transparency }
		if part.CanCollide then
			part.CanCollide = false
		end
		if part.Transparency < 0.55 then
			part.Transparency = 0.55
		end
	end

	local function refreshSideWalls(enable, focusX)
		if not enable then
			for part, orig in pairs(sideDisabledWalls) do
				if part and part.Parent then
					pcall(function()
						part.CanCollide = orig.cc
						part.Transparency = orig.tr
					end)
				end
			end
			sideDisabledWalls = {}
			return
		end

		local bounds = Helpers.GetSafeZoneBounds()
		local gameFolder = Workspace:FindFirstChild("Game")
		local excludes = {}
		if sideFolder then table.insert(excludes, sideFolder) end
		if LocalPlayer.Character then table.insert(excludes, LocalPlayer.Character) end
		local gamePlots = gameFolder and gameFolder:FindFirstChild("Plots")
		if gamePlots then table.insert(excludes, gamePlots) end
		local rootPlots = Workspace:FindFirstChild("Plots")
		if rootPlots then table.insert(excludes, rootPlots) end

		local ov = OverlapParams.new()
		ov.FilterType = Enum.RaycastFilterType.Exclude
		ov.FilterDescendantsInstances = excludes

		local fx = math.max(bounds.maxX + 550, (focusX or bounds.maxX) + 450)
		local boxes = {
			{ Vector3.new(bounds.maxX + 40, 88, bounds.center.Z), Vector3.new(140, 80, 520) },
			{ Vector3.new(fx, 88, bounds.center.Z - SIDE_OFFSET_Z), Vector3.new(1400, 80, 160) },
			{ Vector3.new(fx, 88, bounds.center.Z + SIDE_OFFSET_Z), Vector3.new(1400, 80, 160) },
		}
		for _, b in ipairs(boxes) do
			local ok, hits = pcall(Workspace.GetPartBoundsInBox, Workspace, CFrame.new(b[1]), b[2], ov)
			if ok and hits then
				for _, hit in ipairs(hits) do
					disableSideWallPart(hit, bounds.maxX, bounds.center.Z)
				end
			end
		end
	end

	local function syncSideLane(enable)
		if not enable then
			for _, list in pairs(sideTiles) do
				for _, t in ipairs(list) do
					if t and t.Parent then t.CanCollide = false end
				end
			end
			refreshSideWalls(false)
			return
		end

		if not sideFolder or not sideFolder.Parent then
			sideFolder = Instance.new("Folder")
			sideFolder.Name = "KuySideLane"
			sideFolder.Parent = Workspace
			sideTiles = { north = {}, south = {} }
			for idx = 1, #SIDE_TILES do
				sideTiles.north[idx] = makeSideTile("SideNorth" .. idx)
				sideTiles.south[idx] = makeSideTile("SideSouth" .. idx)
			end
		end

		local bounds = Helpers.GetSafeZoneBounds()
		local northZ = bounds.center.Z - SIDE_OFFSET_Z
		local southZ = bounds.center.Z + SIDE_OFFSET_Z
		local centerY = SIDE_TOP_Y - SIDE_THICKNESS * 0.5
		for idx, seg in ipairs(SIDE_TILES) do
			local len = seg[2] - seg[1]
			local cx = (seg[1] + seg[2]) * 0.5
			local nt = sideTiles.north[idx]
			if nt then
				nt.Size = Vector3.new(len, SIDE_THICKNESS, SIDE_WIDTH)
				nt.CFrame = CFrame.new(cx, centerY, northZ)
				nt.CanCollide = true
			end
			local st = sideTiles.south[idx]
			if st then
				st.Size = Vector3.new(len, SIDE_THICKNESS, SIDE_WIDTH)
				st.CFrame = CFrame.new(cx, centerY, southZ)
				st.CanCollide = true
			end
		end
		refreshSideWalls(true, bounds.maxX + 200)
	end

	Core:OnCleanup(function()
		refreshSideWalls(false)
		if sideFolder then
			pcall(function() sideFolder:Destroy() end)
			sideFolder = nil
		end
		sideTiles = { north = {}, south = {} }
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
		local arriveDist = (opts and opts.arriveDist) or (precise and 4 or 10)
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
		if Core.Flags.SideBypassMode then
			refreshSideWalls(true, hrp.Position.X)
		end
		local initYOk = precise and 10 or 22
		local initFlat = Vector3.new(targetPos.X - hrp.Position.X, 0, targetPos.Z - hrp.Position.Z).Magnitude
		if initFlat <= arriveDist and math.abs(targetPos.Y - hrp.Position.Y) <= initYOk then
			if precise then
				stopMotion(hum, hrp, true)
			end
			return true
		end

		local lastCheck = os.clock()
		local lastPos = hrp.Position
		local lastIssue = 0
		local lastDodgeJump = 0
		local borderStallStart = nil
		local timeout = os.clock() + math.max(90, initFlat / 12 + 30)

		while Core._alive and Helpers.IsAlive() and os.clock() < timeout do
			if shouldAbort and shouldAbort() then
				if precise then
					stopMotion(hum, hrp, false)
				end
				return true
			end
			char = LocalPlayer.Character
			hum = char and char:FindFirstChildOfClass("Humanoid")
			hrp = Helpers.GetRoot()
			if not (char and hum and hrp) then return false end

			local now = os.clock()
			if Core.Flags.SideBypassMode and now - floorRefreshAt >= 0.12 then
				floorRefreshAt = now
				refreshSideWalls(true, hrp.Position.X)
			end

			local cur = hrp.Position
			local flatDelta = Vector3.new(targetPos.X - cur.X, 0, targetPos.Z - cur.Z)
			local flatDist = flatDelta.Magnitude
			local fullDist = (targetPos - cur).Magnitude
			local yTol = precise and 10 or 22
			if flatDist <= arriveDist and math.abs(targetPos.Y - cur.Y) <= yTol then
				if precise then
					stopMotion(hum, hrp, true)
				end
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
				if precise then
					if flatDist <= 10 then
						desiredSpeed = math.clamp(flatDist * 2.5, 16, 26)
					elseif flatDist <= 90 then
						desiredSpeed = math.clamp(flatDist * 2.5, 22, topSpeed)
					end
				end
				hum.WalkSpeed = desiredSpeed

				if precise and flatDist <= 90 then
					local v = hrp.AssemblyLinearVelocity
					local hVel = Vector3.new(v.X, 0, v.Z)
					local maxAllowed = desiredSpeed * 1.05 + 2
					if hVel.Magnitude > maxAllowed then
						local clamped = hVel.Unit * desiredSpeed
						pcall(function()
							hrp.AssemblyLinearVelocity = Vector3.new(clamped.X, v.Y, clamped.Z)
						end)
					end
				end

				-- หลีกเลี่ยงบอสบนทางหลักระหว่างวิ่งกลับฐาน (เมื่อไม่ได้เปิดโหมดอ้อมขอบนอก)
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
			local issueInterval = (precise and flatDist <= 35) and 0.02 or 0.1
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
					return false
				end
			else
				borderStallStart = nil
			end

			RunService.Heartbeat:Wait()
		end
		stopMotion(hum, hrp, false)
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
		RebirthRequest = RP .. "Rebirth.Request",    -- RF: InvokeServer()
		OfflineClaim = RP .. "Offline.Claim",        -- RF: InvokeServer()
		DailyClaim = RP .. "Daily.Claim",            -- RF: InvokeServer()
		IndexClaimReward = RP .. "Index.ClaimReward", -- RF: InvokeServer(stage, name, kind)
		CoachesPurchase = RP .. "Coaches.Purchase",  -- RF: InvokeServer(coachId)
		CoachesEquip = RP .. "Coaches.Equip",        -- RF: InvokeServer(coachKey)
		AurasPurchase = RP .. "Auras.Purchase",      -- RF: InvokeServer(auraId)
		AurasEquip = RP .. "Auras.Equip",            -- RF: InvokeServer(auraId)
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
		local ok, res = false, nil
		task.spawn(function()
			ok, res = pcall(function()
				return r:InvokeServer(table.unpack(args, 1, args.n))
			end)
			done = true
		end)
		local t0 = os.clock()
		while not done and (os.clock() - t0) < 4 and Core._alive do
			task.wait(0.03)
		end
		if not done then
			return false, "TIMEOUT"
		end
		return ok, res
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
			if not Core.Flags.AutoTreadmill then return end
			local args = table.pack(...)
			if args.n == 0 then return end
			task.spawn(function()
				task.wait(0.24 + math.random() * 0.16)
				if Core._alive and Core.Flags.AutoTreadmill then
					if tryClickBoostPopup() or Net.Fire(boost, nil, table.unpack(args, 1, args.n)) then
						Stats.boosts = Stats.boosts + 1
					end
				end
			end)
		end)
	end)

	local lastEnter = 0
	local function enterTreadmill()
		if Core.Busy or LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil then return end
		if os.clock() - lastEnter < 2 or not Helpers.IsAlive() or Helpers.IsCarrying() then return end
		local tm = Helpers.GetPlotChild("Treadmil")
		if not tm then return end
		local target = tm:FindFirstChild("PurplePad") or tm:FindFirstChild("PlayerTreadmill")
		local pos = target and Helpers.GetPosition(target)
		if not pos then return end
		lastEnter = os.clock()
		Helpers.Teleport(CFrame.new(pos + Vector3.new(0, 4, 0)))
	end

	local function startEnterLoop()
		Core:Loop("enter", "AutoEnter", 1, function()
			if not Core.Busy and not Helpers.IsCarrying() then
				enterTreadmill()
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
		if a.mult ~= b.mult then return a.mult > b.mult end
		if a.odd ~= b.odd then return a.odd > b.odd end
		if a.weight ~= b.weight then return a.weight > b.weight end
		if a.enemyDist ~= b.enemyDist then return a.enemyDist > b.enemyDist end
		return a.dist < b.dist
	end

	local function findStealPrompt(stageFolder)
		if not stageFolder then return nil end
		local root = stageFolder:FindFirstChild("SpawnedPacks")
		if not root then return nil end
		local hrp = Helpers.GetRoot()
		local enemies = getStageEnemyPositions(stageFolder)
		local bestSafe, bestAny = nil, nil
		for _, model in ipairs(root:GetChildren()) do
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
					local cand = {
						prompt = p,
						mult = mult,
						odd = odd,
						weight = weight,
						enemyDist = minEnemyDist,
						dist = hrp and (pos - hrp.Position).Magnitude or 0,
					}
					if minEnemyDist >= 25 then
						if isBetterCandidate(cand, bestSafe) then bestSafe = cand end
					else
						if isBetterCandidate(cand, bestAny) then bestAny = cand end
					end
				end
			end
		end
		return (bestSafe and bestSafe.prompt) or (bestAny and bestAny.prompt) or nil
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
				hum.WalkSpeed = math.clamp(Helpers.GetMoveSpeed(), 22, 38)
				pcall(function() hum:MoveTo(targetPos) end)
			else
				pcall(function()
					hum:MoveTo(hrp.Position)
					hum:Move(Vector3.zero)
				end)
			end
			RunService.Heartbeat:Wait()
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
		local hold = prompt.HoldDuration
		if method == "fire" and fireproximityprompt then
			pcall(fireproximityprompt, prompt)
			local tEnd = os.clock() + 0.65
			while os.clock() < tEnd and Core._alive and Core.Flags.AutoSteal and prompt.Parent do
				if Helpers.IsCarrying() or diag.trig then break end
				RunService.Heartbeat:Wait()
			end
		else
			holdAndOrbit(prompt, hold + 0.3, stageFolder, diag)
			pcall(function() prompt:InputHoldEnd() end)
			pressPromptKey(prompt, false)
		end
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		return diag
	end

	local function waitUntil(cond, timeout)
		local deadline = os.clock() + timeout
		while os.clock() < deadline and Core._alive do
			if cond() then return true end
			task.wait(0.1)
		end
		return cond()
	end

	local function leaveTreadmill()
		if LocalPlayer:GetAttribute(TRAINING_ATTR) == nil then return end
		Net.Fire(Net.Paths.ExitRequest, 0.5)
		waitUntil(function() return LocalPlayer:GetAttribute(TRAINING_ATTR) == nil end, 2.5)
	end

	local function pickSideZ(refPos, stageFolder)
		local bounds = Helpers.GetSafeZoneBounds()
		local northZ = bounds.center.Z - SIDE_OFFSET_Z
		local southZ = bounds.center.Z + SIDE_OFFSET_Z
		local rz = refPos and refPos.Z or bounds.center.Z
		if refPos then
			local ePos = findNearestEnemyPos(refPos, math.huge, stageFolder)
			if ePos then
				return (ePos.Z >= rz) and northZ or southZ
			end
		end
		return (rz <= bounds.center.Z) and northZ or southZ
	end

	local function moveToCenterLane(abortFn)
		local hrp = Helpers.GetRoot()
		if not hrp then return end
		local bounds = Helpers.GetSafeZoneBounds()
		local laneX = math.clamp(hrp.Position.X, bounds.maxX - 48, bounds.maxX - 28)
		if Core.Flags.SideBypassMode then
			local targetZ = pickSideZ(hrp.Position)
			if hrp.Position.X <= bounds.maxX + 20 and math.abs(hrp.Position.Z - targetZ) > 5 then
				Helpers.MoveTo(Vector3.new(laneX, hrp.Position.Y, targetZ), abortFn, { precise = true, arriveDist = 3 })
			end
			return
		end
		if hrp.Position.X <= bounds.maxX + 20 then
			if math.abs(hrp.Position.Z - bounds.center.Z) > 4 then
				Helpers.MoveTo(Vector3.new(laneX, hrp.Position.Y, bounds.center.Z), abortFn, { precise = true, arriveDist = 3 })
			end
		elseif math.abs(hrp.Position.Z - bounds.center.Z) > 20 then
			Helpers.MoveTo(Vector3.new(hrp.Position.X, hrp.Position.Y, bounds.center.Z), abortFn, { precise = true, arriveDist = 4 })
		end
	end

	local function isSafelyDelivered(livePos, bounds)
		if Helpers.IsCarrying() then return false end
		local hrp = Helpers.GetRoot()
		if not hrp then return false end
		return hrp.Position.X <= bounds.maxX + 15 or (hrp.Position - livePos).Magnitude <= 45
	end

	local function deliver()
		local pos = Helpers.GetPlotSpawnPos()
		if not pos then return false, "ไม่พบจุดเกิดของฐาน" end
		local bounds = Helpers.GetSafeZoneBounds()
		local stopWhenDelivered = function()
			return not Core.Flags.AutoSteal or not Helpers.IsCarrying()
		end
		for _ = 1, 2 do
			local livePos = Helpers.GetPlotSpawnPos() or pos
			local hrp = Helpers.GetRoot()
			if hrp and hrp.Position.X > bounds.maxX - 15 then
				if Core.Flags.SideBypassMode and hrp.Position.X > bounds.maxX + 10 then
					local exitSideZ = pickSideZ(hrp.Position)
					if math.abs(hrp.Position.Z - exitSideZ) > 12 then
						Helpers.MoveTo(Vector3.new(hrp.Position.X, SIDE_TOP_Y + 3, exitSideZ), stopWhenDelivered, { precise = false })
						if not Helpers.IsCarrying() then
							if isSafelyDelivered(livePos, bounds) then return true end
							return false, "โดนตี/แพ็คหลุดกลางทาง"
						end
						if not Core.Flags.AutoSteal or not Helpers.IsAlive() then break end
					end
					Helpers.MoveTo(Vector3.new(bounds.maxX - 35, livePos.Y, exitSideZ), stopWhenDelivered, { precise = false })
				else
					local entryZ = math.abs(livePos.Z - bounds.center.Z) > 35 and bounds.center.Z or livePos.Z
					Helpers.MoveTo(Vector3.new(bounds.maxX - 35, livePos.Y, entryZ), stopWhenDelivered, { precise = false, evadeEnemies = true })
				end
				if not Helpers.IsCarrying() then
					if isSafelyDelivered(livePos, bounds) then return true end
					return false, "โดนตี/แพ็คหลุดกลางทาง"
				end
				if not Core.Flags.AutoSteal or not Helpers.IsAlive() then break end
			end
			Helpers.MoveTo(livePos + Vector3.new(0, 3, 0), stopWhenDelivered, { evadeEnemies = true })
			if not Helpers.IsCarrying() then
				if isSafelyDelivered(livePos, bounds) then return true end
				return false, "โดนตี/แพ็คหลุดกลางทาง"
			end
			Helpers.StreamAround(livePos, 3)
			if waitUntil(function() return not Helpers.IsCarrying() end, 2) then
				if isSafelyDelivered(livePos, bounds) then return true end
				return false, "โดนตี/แพ็คหลุดกลางทาง"
			end
		end
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
		local prompt = findStealPrompt(folder)
		if prompt then return prompt end

		local basePos = STAGE_CENTERS[i]
		if basePos then
			Helpers.StreamAround(basePos, 1.2)
		end
		folder = getStageFolder(i)
		prompt = findStealPrompt(folder)
		if prompt then return prompt end

		local sp = folder and folder:FindFirstChild("SpawnedPacks")
		if sp and #sp:GetChildren() > 0 then
			task.wait(0.2)
			prompt = findStealPrompt(folder)
			if prompt then return prompt end
		end

		return nil
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

		syncSideLane(Core.Flags.SideBypassMode)
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

			local standTarget
			if Core.Flags.SideBypassMode then
				local hrp0 = Helpers.GetRoot()
				local curSideZ = (hrp0 and hrp0.Position.Z <= bounds.center.Z)
					and (bounds.center.Z - SIDE_OFFSET_Z)
					or (bounds.center.Z + SIDE_OFFSET_Z)
				local waitSpot = Vector3.new(p0.X, SIDE_TOP_Y + 3, curSideZ)
				Helpers.MoveTo(waitSpot, function()
					return not Core.Flags.AutoSteal or not prompt.Parent
				end, { precise = false })
				if not Core.Flags.AutoSteal or not Helpers.IsAlive() or not prompt.Parent then break end

				-- รอจังหวะสั้นๆ นอกกำแพงหากบอสยืนเฝ้าติดแพ็ค ก่อนพุ่งเข้าขโมยจากด้านข้างนอก
				local waitEnd = os.clock() + 1.8
				while os.clock() < waitEnd and Core.Flags.AutoSteal and prompt.Parent do
					local _, eDist = findNearestEnemyPos(p0, 35, stageFolder)
					if not eDist or eDist >= 22 then break end
					task.wait(0.15)
				end

				local anchor0 = packAnchorPos(prompt) or p0
				local edgeDir = (curSideZ < anchor0.Z) and -1 or 1
				local wallSidePos = Vector3.new(anchor0.X, anchor0.Y, anchor0.Z + edgeDir * 2.8)
				local safePos = safeStandPos(anchor0, stageFolder, 2.8)
				local _, dWall = findNearestEnemyPos(wallSidePos, math.huge, stageFolder)
				local _, dSafe = findNearestEnemyPos(safePos, math.huge, stageFolder)
				standTarget = (dSafe > dWall + 3) and safePos or wallSidePos
			else
				standTarget = safeStandPos(packAnchorPos(prompt) or p0, stageFolder, 2.5)
			end

			-- เดินเข้าไปยืนด้านที่ห่างบอสที่สุดให้ชิดระยะ Prompt จริง (<= 3.5 studs)
			Helpers.MoveTo(standTarget, function()
				return not Core.Flags.AutoSteal or not prompt.Parent
			end, { precise = true, arriveDist = 2.0, evadeEnemies = not Core.Flags.SideBypassMode })
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
			local holdDiag = usePrompt(prompt, "hold", stageFolder)
			lastDiag = holdDiag
			local got = waitUntil(Helpers.IsCarrying, 0.7)
			if not got and Core.Flags.AutoSteal and Helpers.IsAlive() and prompt.Parent then
				local fireDiag = usePrompt(prompt, "fire", stageFolder) -- สำรอง
				got = waitUntil(Helpers.IsCarrying, 1.0)
				if not got then
					lastDiag = {
						began = holdDiag.began,
						trig = fireDiag.trig or holdDiag.trig,
						fireTrig = fireDiag.trig,
					}
				end
			end
			if got or Helpers.IsCarrying() then break end
		end
		if not Helpers.IsCarrying() then
			local b = lastDiag and tostring(lastDiag.began) or "?"
			local t = lastDiag and tostring(lastDiag.trig) or "?"
			return false, string.format("หยิบไม่สำเร็จ(b=%s,t=%s,d=%.0f)", b, t, lastDist)
		end

		return deliver()
	end

	local function returnToSafeRest()
		if not Helpers.IsAlive() or Helpers.IsCarrying() then return end
		local pos = Helpers.GetPlotSpawnPos()
		if not pos then return end
		local hrp = Helpers.GetRoot()
		if not hrp then return end
		local bounds = Helpers.GetSafeZoneBounds()
		local flatDistToBase = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if flatDistToBase > 20 or hrp.Position.X > (bounds.maxX - 15) then
			Helpers.MoveTo(pos + Vector3.new(0, 3, 0), function()
				return not Core._alive or not Core.Flags.AutoSteal
			end, { precise = true, arriveDist = 6 })
		end
		if Core.Flags.AutoEnter or Core.Flags.AutoTreadmill then
			enterTreadmill()
		end
	end

	local function stealCycle()
		local anyFound = false
		for i = 1, 12 do
			if not Core._alive or not Core.Flags.AutoSteal then break end
			if Core.Flags["Stage" .. i] and Helpers.IsAlive() then
				local prompt = checkStageHasPacks(i)
				if prompt then
					anyFound = true
					Core.Busy = true
					leaveTreadmill()
					local ok, res, why = pcall(stealFromStage, i, prompt)
					stopPin()
					Core.Busy = false
					if ok and res then
						Stats.stealOk = Stats.stealOk + 1
						logAction("ขโมย", "ด่าน " .. i .. ": สำเร็จ", true)
					else
						Stats.stealFail = Stats.stealFail + 1
						local reason = res
						if ok then reason = why or "ไม่ทราบสาเหตุ" end
						logAction("ขโมย", "ด่าน " .. i .. ": " .. tostring(reason), false)
						returnToSafeRest()
					end
					task.wait(Core.Flags.StealDelay)
				end
			end
		end

		if not anyFound and Helpers.IsAlive() and not Helpers.IsCarrying() then
			returnToSafeRest()
			task.wait(1.5)
		end
	end

	local function startStealLoop()
		Core:Loop("steal", "AutoSteal", 0.5, stealCycle)
	end

	Core:OnCleanup(stopPin)

	-----------------------------------------------------------------
	-- 5.5. FEATURE: COACHES & AURAS (Auto Buy / Auto Equip Best)
	-----------------------------------------------------------------
	local lastCoachBuy, lastCoachEquip = 0, 0
	local lastAuraBuy, lastAuraEquip = 0, 0

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
			if res.Success ~= nil then return res.Success == true, res.Reason end
			if res.Ok ~= nil then return res.Ok == true, res.Reason end
		end
		return res ~= false, nil
	end

	local function equipBestCoach()
		local cu = getCoachUtil()
		local cc = getCoachConfig()
		local coachData = getPlayerDataKey("Coaches")
		if not (cu and type(coachData) == "table" and type(coachData.Owned) == "table") then return end

		local bestKey, bestMult, bestOrder = nil, -1, -1
		for key in pairs(coachData.Owned) do
			if cu.GetCount(coachData, key) > 0 then
				local entry, mut = cu.Get(key)
				if entry then
					local mult = cu.GetEntryMultiplier(entry, mut)
					local ord = entry.Order or 0
					if mult > bestMult or (mult == bestMult and ord > bestOrder) then
						bestKey, bestMult, bestOrder = key, mult, ord
					end
				end
			end
		end
		if not bestKey then return end

		local attrName = (cc and cc.Attributes and cc.Attributes.Equipped) or "EquippedCoach"
		local curEquipped = coachData.Equipped
		local curAttr = LocalPlayer:GetAttribute(attrName)
		if curEquipped == bestKey or (curEquipped == nil and curAttr == bestKey) then return end

		local now = os.clock()
		local rateLimit = math.max((cc and cc.RateLimit) or 0.3, 1.0)
		if now - lastCoachEquip < rateLimit then return end
		lastCoachEquip = now

		local ok, res = Net.Invoke(Net.Paths.CoachesEquip, bestKey)
		local success, reason = isRemoteOk(res)
		if ok and success then
			logAction("โค้ช", "สวมใส่: " .. tostring(cu.GetDisplayName(bestKey)), true)
		elseif ok and reason then
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
		if now - lastCoachBuy < rateLimit then return end

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
					lastCoachBuy = now
					local ok, res = Net.Invoke(Net.Paths.CoachesPurchase, entry.Id)
					local success, reason = isRemoteOk(res)
					if ok and success then
						logAction("โค้ช", "ซื้อสำเร็จ: " .. tostring(entry.Name or entry.Id), true)
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
		if now - lastAuraEquip < 1.0 then return end
		lastAuraEquip = now

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
		if now - lastAuraBuy < 0.6 then return end

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
				lastAuraBuy = now
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

	local function startAutoBuyCoachLoop()
		Core:Loop("buyCoach", "AutoBuyCoach", 1, buyBestCoach)
	end

	local function startAutoEquipCoachLoop()
		Core:Loop("equipCoach", "AutoEquipCoach", 1.2, equipBestCoach)
	end

	local function startAutoBuyAuraLoop()
		Core:Loop("buyAura", "AutoBuyAura", 1, buyBestAura)
	end

	local function startAutoEquipAuraLoop()
		Core:Loop("equipAura", "AutoEquipAura", 1.2, equipBestAura)
	end

	-----------------------------------------------------------------
	-- 5.6. FEATURE: PACKS & ECONOMY (Open / EquipBest / Sell / Merge / Fuse)
	-----------------------------------------------------------------
	local itemSkipUntil = {}
	local permSkipItems = {}
	local lastEquipBest, lastSell, lastMerge, lastFuse = 0, 0, 0, 0

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
					local isPack = tool:GetAttribute("CardIsPack") == true or tool:GetAttribute("ItemCategory") == "Packs"
					local isUnit = tool:GetAttribute("CardIsPack") == false or tool:GetAttribute("ItemCategory") == "Units"
					local mut = normMutation(getToolMutation(tool))

					if mode == "merge" and isPack then
						local name = tool:GetAttribute("PackName") or tool.Name
						if type(name) == "string" and name ~= "" then
							seenIds[packId] = true
							table.insert(candidates, {
								Id = packId,
								Name = name,
								Mutation = mut,
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
					local isChar = (pc and pc.IsCharacter and pc.IsCharacter(item)) or item.Kind == "Character"
					local isPath = (pc and pc.IsPathPack and pc.IsPathPack(item))
					local mut = normMutation(item.Mutation)

					if mode == "merge" and not isChar and not isPath then
						local name = item.PackName or item.Name
						if type(name) == "string" and name ~= "" then
							seenIds[packId] = true
							table.insert(candidates, {
								Id = packId,
								Name = name,
								Mutation = mut,
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

		return candidates
	end

	local function autoOpenPacksStep()
		local now = os.clock()
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local placed = inv and inv.Packs and inv.Packs.Placed
		local pc = getPacksConfig()
		local sTime = Workspace:GetServerTimeNow()

		-- 1. ตรวจสอบแพ็กที่เพาะอยู่ในฐาน (Placed) ที่ครบกำหนดเวลา -> เรียก OpenOwned เพื่อฟักออกเป็นตัว
		if type(placed) == "table" then
			for _, rec in pairs(placed) do
				if not (Core._alive and Core.Flags.AutoOpenPacks) then return end
				if type(rec) == "table" and type(rec.Id) == "string" then
					local isChar = (pc and pc.IsCharacter and pc.IsCharacter(rec)) or rec.Kind == "Character"
					if not isChar and (rec.GrowthEndsAt == nil or rec.GrowthEndsAt <= sTime) then
						if (itemSkipUntil[rec.Id] or 0) <= now then
							local ok, res = Net.Invoke(Net.Paths.OpenOwned, rec.Id)
							local success, reason = isRemoteOk(res)
							if ok and success then
								Net.Fire(Net.Paths.PacksOpened, nil, rec.Id)
								local name = rec.PackName or "Pack"
								logAction("เปิดแพ็ก", "ฟักสำเร็จ: " .. tostring(name), true)
								task.wait(0.35)
								return
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

		-- 2. นำแพ็กที่ขโมยมาในกระเป๋า (CardIsPack == true) วางลงพื้นที่เพาะของฐาน (PlaceOwned)
		-- หากเปิด AutoMerge อยู่และยังมีแพ็คซ้ำในกระเป๋า ให้รอ AutoMerge รวมให้เสร็จก่อน
		if Core.Flags.AutoMerge then
			local mergeCandidates = getBackpackCandidates("merge")
			local counts = {}
			for _, c in ipairs(mergeCandidates) do
				local k = c.Name .. "|" .. c.Mutation
				counts[k] = (counts[k] or 0) + 1
				if counts[k] >= 2 then
					return
				end
			end
		end

		local plot = Helpers.GetPlot()
		local pu = getPlotUtil()
		local area = (pu and plot and pu.GetAnimeArea and pu.GetAnimeArea(plot.Name)) or nil
		local basePos = area and Helpers.GetPosition(area) or Helpers.GetPlotSpawnPos()
		if basePos then
			for _, tool in ipairs(getBagTools(false)) do
				if not (Core._alive and Core.Flags.AutoOpenPacks) then return end
				local packId = tool:GetAttribute("PackId")
				local isPack = tool:GetAttribute("CardIsPack") == true or tool:GetAttribute("ItemCategory") == "Packs"
				if isPack and type(packId) == "string" and packId ~= "" then
					if (itemSkipUntil["place:" .. packId] or 0) <= now then
						local rx = (math.random() - 0.5) * 22
						local rz = (math.random() - 0.5) * 16
						local placePos = Vector3.new(basePos.X + rx, basePos.Y + 1.2, basePos.Z + rz)
						local ok, res = Net.Invoke(Net.Paths.PlaceOwned, {
							PackId = packId,
							Position = placePos,
						})
						local success, reason = isRemoteOk(res)
						if ok and success then
							logAction("วางแพ็ก", "นำลงเพาะในฐาน: " .. tostring(tool.Name), true)
							itemSkipUntil["place:" .. packId] = now + 2
							task.wait(0.35)
							return
						else
							itemSkipUntil["place:" .. packId] = now + 5
							if ok and reason and reason ~= "OVERLAPS_PACK" then
								logAction("วางแพ็ก", "วางไม่สำเร็จ (" .. tostring(reason) .. ")", false)
							end
						end
					end
				end
			end
		end
	end

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

	local function autoMergeStep()
		if Core.Busy or Helpers.IsCarrying() then return end
		local now = os.clock()
		local mc = getMutateConfig()
		local rl = math.max((mc and mc.RateLimit) or 0.35, 0.35)
		if now - lastMerge < 1.0 then return end

		local candidates = getBackpackCandidates("merge")
		local groups = {}
		for _, c in ipairs(candidates) do
			local key = c.Name .. "|" .. c.Mutation
			groups[key] = groups[key] or { name = c.Name, list = {} }
			table.insert(groups[key].list, c)
		end

		local pairsToMerge = {}
		for _, g in pairs(groups) do
			local list = g.list
			local i = 1
			while i + 1 <= #list do
				table.insert(pairsToMerge, {
					itemA = list[i],
					itemB = list[i + 1],
					packName = g.name,
				})
				i = i + 2
			end
		end

		if #pairsToMerge == 0 then return end
		lastMerge = now

		local okVisit, mergedTotal = Helpers.VisitMutateMachine(function()
			local count = 0
			for _, pair in ipairs(pairsToMerge) do
				if not (Core._alive and Core.Flags.AutoMerge) then break end
				local idA = pair.itemA.Id
				local idB = pair.itemB.Id
				local pName = pair.packName

				-- ลองใช้ MergeAll ก่อนเผื่อเซิร์ฟเวอร์รองรับ
				local okAll, resAll = Net.Invoke(Net.Paths.MutateMergeAll, idA)
				local sAll, rAll = isRemoteOk(resAll)
				if okAll and sAll then
					count = count + 1
					task.wait(rl)
				else
					-- Fallback ใช้ MutateMerge รายคู่
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
							itemSkipUntil["merge:" .. idA] = os.clock() + 6
							itemSkipUntil["merge:" .. idB] = os.clock() + 6
							logAction("Merge", "รวม " .. tostring(pName) .. " พลาด: " .. tostring(failReason), false)
						end
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
					local mutResult = (type(resFuse) == "table" and resFuse.Character and resFuse.Character.Mutation) or "สำเร็จ"
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
		end
	end

	local function startAutoOpenPacksLoop()
		task.spawn(autoOpenPacksStep)
		Core:Loop("openPacks", "AutoOpenPacks", 0.6, autoOpenPacksStep)
	end

	local function startAutoEquipBestLoop()
		task.spawn(function() autoEquipBestStep(true) end)
		Core:Loop("equipBest", "AutoEquipBest", 3, autoEquipBestStep)
	end

	local function startAutoSellLoop()
		task.spawn(autoSellUnitsStep)
		Core:Loop("sellUnits", "AutoSellUnits", 0.8, autoSellUnitsStep)
	end

	local function startAutoMergeLoop()
		task.spawn(autoMergeStep)
		Core:Loop("mergePacks", "AutoMerge", 1.8, autoMergeStep)
	end

	local function startAutoFuseLoop()
		task.spawn(autoFuseStep)
		Core:Loop("fuseUnits", "AutoFuse", 1.8, autoFuseStep)
	end

	-----------------------------------------------------------------
	-- 5.7. FEATURE: UPGRADES, REBIRTH, CLAIMS & ANTI-AFK
	-----------------------------------------------------------------
	local nextTmUpgrade, nextBaseUpgrade, lastRebirthTry = 0, 0, 0
	local nextOfflineClaim, nextDailyClaim, nextIndexClaim = 0, 0, 0

	local function autoUpgradeTreadmillStep()
		local now = os.clock()
		if now < nextTmUpgrade then return end
		local ok, res = Net.Invoke(Net.Paths.TreadmillUpgrade, {})
		local success, reason = isRemoteOk(res)
		if ok and success then
			nextTmUpgrade = now + 0.8
			logAction("อัปเกรด", "อัปเกรดลู่วิ่งสำเร็จ", true)
		else
			nextTmUpgrade = now + 4
			if ok and reason and reason ~= "NOT_ENOUGH_CASH" then
				logAction("อัปเกรด", "ลู่วิ่ง: " .. tostring(reason), false)
			end
		end
	end

	local function autoUpgradeBaseStep()
		local now = os.clock()
		if now < nextBaseUpgrade then return end
		local ok, res = Net.Invoke(Net.Paths.BaseUpgradePurchase, {})
		local success, reason = isRemoteOk(res)
		if ok and success then
			nextBaseUpgrade = now + 0.8
			logAction("อัปเกรด", "อัปเกรดฐานสำเร็จ", true)
		else
			nextBaseUpgrade = now + 4
			if ok and reason and reason ~= "NOT_ENOUGH_CASH" then
				logAction("อัปเกรด", "ฐาน: " .. tostring(reason), false)
			end
		end
	end

	local function autoRebirthStep()
		local now = os.clock()
		if now - lastRebirthTry < 3 then return end
		local ru = getRebirthUtil()
		if not (ru and ru.GetCount and ru.GetRequirement) then return end

		local count = ru.GetCount(LocalPlayer)
		local spd = tonumber(getPlayerDataKey("Speed")) or 0
		local needed = ru.GetRequirement(count)
		if needed and spd >= needed then
			lastRebirthTry = now
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
		if now >= nextOfflineClaim then
			local pending = getPlayerDataKey("PendingEarnings")
			local lastOff = getPlayerDataKey("LastOfflineReward")
			local hasOffline = (type(pending) == "table" and ((tonumber(pending.Cash) or 0) > 0 or (tonumber(pending.Diamonds) or 0) > 0))
				or (type(lastOff) == "table" and (tonumber(lastOff.Cash) or 0) > 0)
			if hasOffline then
				nextOfflineClaim = now + 15
				local ok, res = Net.Invoke(Net.Paths.OfflineClaim)
				if ok and isRemoteOk(res) then
					logAction("เคลม", "เคลม Offline สำเร็จ", true)
				end
				return
			end
			nextOfflineClaim = now + 10
		end

		if now >= nextDailyClaim then
			local dru = getDailyRewardsUtil()
			local dailyData = getPlayerDataKey("DailyRewards")
			if dru and dru.GetState and type(dailyData) == "table" then
				local okSt, st = pcall(dru.GetState, dailyData, Workspace:GetServerTimeNow())
				if okSt and type(st) == "table" and st.CanClaim then
					nextDailyClaim = now + 20
					local ok, res = Net.Invoke(Net.Paths.DailyClaim)
					if ok and isRemoteOk(res) then
						logAction("เคลม", "เคลม Daily สำเร็จ", true)
					end
					return
				end
			end
			nextDailyClaim = now + 15
		end

		if now >= nextIndexClaim then
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
				nextIndexClaim = now + 25
				local okU, resU = Net.Invoke(Net.Paths.IndexClaimReward, nil, nil, "Units")
				local okL, resL = Net.Invoke(Net.Paths.IndexClaimReward, nil, nil, "Limited")
				if (okU and isRemoteOk(resU)) or (okL and isRemoteOk(resL)) then
					logAction("เคลม", "เคลม Index Rewards สำเร็จ", true)
				end
			else
				nextIndexClaim = now + 20
			end
		end
	end

	local function startAutoUpgradeTreadmillLoop()
		Core:Loop("upgTreadmill", "AutoUpgradeTreadmill", 0.5, autoUpgradeTreadmillStep)
	end

	local function startAutoUpgradeBaseLoop()
		Core:Loop("upgBase", "AutoUpgradeBase", 0.5, autoUpgradeBaseStep)
	end

	local function startAutoRebirthLoop()
		Core:Loop("autoRebirth", "AutoRebirth", 1.5, autoRebirthStep)
	end

	local function startAutoClaimLoop()
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

	-----------------------------------------------------------------
	-- 6. UI CREATION (KUYKUY HUB UI FRAMEWORK - DARK PURPLE BLUEPRINT)
	-----------------------------------------------------------------
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

	local function buildUI()
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
			if v then startEnterLoop() end
		end)

		CreateToggle(pFarm, "ขโมยแพ็คอัตโนมัติ (Auto Steal Packs)", Core.Flags.AutoSteal, function(v)
			Core.Flags.AutoSteal = v
			if v then startStealLoop() end
		end)

		CreateToggle(pFarm, "ความเร็วสูงสุด 340 (เพดานเกม)", Core.Flags.MaxSpeedMode, function(v)
			Core.Flags.MaxSpeedMode = v
		end)

		CreateToggle(pFarm, "โหมดอ้อมขอบนอก (หลบบอส / Side Bypass)", Core.Flags.SideBypassMode, function(v)
			Core.Flags.SideBypassMode = v
			syncSideLane(v)
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

		-- =====================================================================
		-- TAB 2: 📦 2. แพ็ก & ยูนิต (Packs & Units)
		-- =====================================================================
		AddTabButton("PackTab", "📦 2. แพ็ก & ยูนิต", false, 2)
		local pPack = CreateTabPage("PackTab")

		local PackStatusCard = CreateStatusCard(pPack, "แพ็ก & ยูนิต: กำลังสแกนข้อมูล...")

		CreateToggle(pPack, "เปิดแพ็กในกระเป๋าอัตโนมัติ (Auto Open)", Core.Flags.AutoOpenPacks, function(v)
			Core.Flags.AutoOpenPacks = v
			if v then startAutoOpenPacksLoop() end
		end)

		CreateToggle(pPack, "วางตัวดีสุดลงฐานอัตโนมัติ (EquipBest)", Core.Flags.AutoEquipBest, function(v)
			Core.Flags.AutoEquipBest = v
			if v then startAutoEquipBestLoop() end
		end)

		CreateToggle(pPack, "รวมแพ็กซ้ำ 2 ชิ้น (Auto Merge Packs)", Core.Flags.AutoMerge, function(v)
			Core.Flags.AutoMerge = v
			if v then startAutoMergeLoop() end
		end)

		CreateToggle(pPack, "กลายพันธุ์ยูนิต 3 ตัว (Auto Fuse Units)", Core.Flags.AutoFuse, function(v)
			Core.Flags.AutoFuse = v
			if v then startAutoFuseLoop() end
		end)

		CreateToggle(pPack, "ขายยูนิตอัตโนมัติ (Auto Sell Units)", Core.Flags.AutoSellUnits, function(v)
			Core.Flags.AutoSellUnits = v
			if v then startAutoSellLoop() end
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
		}
		local rarityOptions = { "Rare (3)", "Epic (4)", "Legendary (5)", "Mythical (6)", "Cosmic (7)", "Divine (8)" }
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
			if v then startAutoBuyCoachLoop() end
		end)

		CreateToggle(pUpg, "สวมใส่โค้ชตัวคูณสูงสุด (Equip Best Coach)", Core.Flags.AutoEquipCoach, function(v)
			Core.Flags.AutoEquipCoach = v
			if v then startAutoEquipCoachLoop() end
		end)

		CreateToggle(pUpg, "ซื้อออร่าที่ดีกว่าอัตโนมัติ (Auto Buy Aura)", Core.Flags.AutoBuyAura, function(v)
			Core.Flags.AutoBuyAura = v
			if v then startAutoBuyAuraLoop() end
		end)

		CreateToggle(pUpg, "สวมใส่ออร่าตัวคูณสูงสุด (Equip Best Aura)", Core.Flags.AutoEquipAura, function(v)
			Core.Flags.AutoEquipAura = v
			if v then startAutoEquipAuraLoop() end
		end)

		CreateToggle(pUpg, "อัปเกรดลู่วิ่งอัตโนมัติ (Upgrade Treadmill)", Core.Flags.AutoUpgradeTreadmill, function(v)
			Core.Flags.AutoUpgradeTreadmill = v
			if v then startAutoUpgradeTreadmillLoop() end
		end)

		CreateToggle(pUpg, "อัปเกรดฐานอัตโนมัติ (Upgrade Base)", Core.Flags.AutoUpgradeBase, function(v)
			Core.Flags.AutoUpgradeBase = v
			if v then startAutoUpgradeBaseLoop() end
		end)

		CreateToggle(pUpg, "เกิดใหม่อัตโนมัติเมื่อครบเกณฑ์ (Auto Rebirth)", Core.Flags.AutoRebirth, function(v)
			Core.Flags.AutoRebirth = v
			if v then startAutoRebirthLoop() end
		end)

		CreateToggle(pUpg, "เคลม Offline / Daily / Index อัตโนมัติ", Core.Flags.AutoClaim, function(v)
			Core.Flags.AutoClaim = v
			if v then startAutoClaimLoop() end
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
		if Core.Flags.AutoEnter then task.spawn(startEnterLoop) end
		if Core.Flags.AutoSteal then task.spawn(startStealLoop) end
		if Core.Flags.SideBypassMode then syncSideLane(true) end
		if Core.Flags.AutoOpenPacks then task.spawn(startAutoOpenPacksLoop) end
		if Core.Flags.AutoEquipBest then task.spawn(startAutoEquipBestLoop) end
		if Core.Flags.AutoMerge then task.spawn(startAutoMergeLoop) end
		if Core.Flags.AutoFuse then task.spawn(startAutoFuseLoop) end
		if Core.Flags.AutoSellUnits then task.spawn(startAutoSellLoop) end
		if Core.Flags.AutoBuyCoach then task.spawn(startAutoBuyCoachLoop) end
		if Core.Flags.AutoEquipCoach then task.spawn(startAutoEquipCoachLoop) end
		if Core.Flags.AutoBuyAura then task.spawn(startAutoBuyAuraLoop) end
		if Core.Flags.AutoEquipAura then task.spawn(startAutoEquipAuraLoop) end
		if Core.Flags.AutoUpgradeTreadmill then task.spawn(startAutoUpgradeTreadmillLoop) end
		if Core.Flags.AutoUpgradeBase then task.spawn(startAutoUpgradeBaseLoop) end
		if Core.Flags.AutoRebirth then task.spawn(startAutoRebirthLoop) end
		if Core.Flags.AutoClaim then task.spawn(startAutoClaimLoop) end

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