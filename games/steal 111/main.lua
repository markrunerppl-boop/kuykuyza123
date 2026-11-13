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

		if not ok then
			return false, tostring(res)
		end
		return res, extra
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
		local mc = getMutateConfig()
		local rl = math.max((mc and mc.RateLimit) or 1, 1.8)
		local now = os.clock()
		if now - lastMerge < rl then return end

		local favMap = getPlayerDataKey("Favorited")
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local packsData = inv and inv.Packs or {}
		local pc = getPacksConfig()

		-- สแกนเฉพาะ Backpack (ไม่รวม Placed ที่กำลังเพาะพันธุ์) เพื่อความปลอดภัยและไม่ชนสถานะ BUSY
		local groups = {}
		local bpList = (type(packsData.Backpack) == "table" and packsData.Backpack) or {}
		for _, item in ipairs(bpList) do
			if type(item) == "table" and type(item.Id) == "string" and not permSkipItems["merge:" .. item.Id] then
				local isChar = (pc and pc.IsCharacter and pc.IsCharacter(item)) or item.Kind == "Character"
				local isPath = (pc and pc.IsPathPack and pc.IsPathPack(item))
				if not isChar and not isPath and item.OpeningCommittedAt == nil then
					local packName = item.PackName
					if type(packName) == "string" and packName ~= "" then
						local isFav = (type(favMap) == "table" and favMap[item.Id] == true)
						if not isFav and (itemSkipUntil["merge:" .. item.Id] or 0) <= now then
							local key = packName .. "|" .. tostring(item.Mutation or "")
							groups[key] = groups[key] or { name = packName, list = {} }
							table.insert(groups[key].list, item)
						end
					end
				end
			end
		end

		-- ตรวจหาคู่ที่มีอย่างน้อย 2 ชิ้น และผ่านเงื่อนไข CanMerge
		local targetItemA, targetItemB = nil, nil
		for _, g in pairs(groups) do
			if #g.list >= 2 then
				if pc and pc.CanMerge then
					for i = 1, #g.list do
						for j = i + 1, #g.list do
							local can, why = pc.CanMerge(g.list[i], g.list[j])
							if can then
								targetItemA = g.list[i]
								targetItemB = g.list[j]
								break
							elseif why == "MERGE_LIMIT" then
								permSkipItems["merge:" .. g.list[i].Id] = true
								permSkipItems["merge:" .. g.list[j].Id] = true
							end
						end
						if targetItemA then break end
					end
				else
					targetItemA = g.list[1]
					targetItemB = g.list[2]
				end
				if targetItemA then break end
			end
		end

		if not targetItemA or not targetItemB then return end

		lastMerge = now
		local pName = targetItemA.PackName or "Pack"

		local visitOk, invokeOk, res = Helpers.VisitMutateMachine(function()
			-- ลองใช้ MergeAll ก่อน (รวมทั้งหมดของประเภทนั้นใน 1 คำสั่ง)
			local okAll, resAll = Net.Invoke(Net.Paths.MutateMergeAll, targetItemA.Id)
			local sAll, rAll = isRemoteOk(resAll)
			if okAll and sAll then
				return true, resAll
			end
			-- Fallback: ใช้ Merge คู่ 2 ชิ้น
			local okPair, resPair = Net.Invoke(Net.Paths.MutateMerge, { targetItemA.Id, targetItemB.Id })
			return okPair, resPair
		end)

		local success, reason = isRemoteOk(res)
		if visitOk and invokeOk and success then
			logAction("Merge", "รวมแพ็ก " .. tostring(pName) .. " สำเร็จ!", true)
			task.wait(0.4)
		else
			local failReason = (not visitOk and tostring(invokeOk)) or reason or "ไม่ทราบสาเหตุ"
			if failReason == "MERGE_LIMIT" then
				permSkipItems["merge:" .. targetItemA.Id] = true
				permSkipItems["merge:" .. targetItemB.Id] = true
				logAction("Merge", pName .. " ถึงลิมิตรวมซ้ำแล้ว (Max)", false)
			else
				itemSkipUntil["merge:" .. targetItemA.Id] = now + 6
				itemSkipUntil["merge:" .. targetItemB.Id] = now + 6
				logAction("Merge", "Merge " .. tostring(pName) .. " พลาด: " .. tostring(failReason), false)
			end
		end
	end

	local function autoFuseStep()
		if Core.Busy or Helpers.IsCarrying() then return end
		local mc = getMutateConfig()
		local rl = math.max((mc and mc.RateLimit) or 1, 1.8)
		local now = os.clock()
		if now - lastFuse < rl then return end

		local favMap = getPlayerDataKey("Favorited")
		local pd = getPlayerData()
		local inv = pd and pd.Get and pd.Get("Inventory")
		local packsData = inv and inv.Packs or {}
		local pc = getPacksConfig()
		local upgTable = (mc and mc.Upgrades) or {}

		local groups = {}
		local function scanCharList(list)
			if type(list) ~= "table" then return end
			for _, item in pairs(list) do
				if type(item) == "table" and type(item.Id) == "string" and not permSkipItems["fuse:" .. item.Id] then
					local isChar = (pc and pc.IsCharacter and pc.IsCharacter(item)) or item.Kind == "Character"
					if isChar and item.OpeningCommittedAt == nil then
						local charName = item.CharacterName or item.PackName
						local mut = item.Mutation
						if type(charName) == "string" and charName ~= "" and (mut == nil or upgTable[mut] ~= nil) then
							local isFav = (type(favMap) == "table" and favMap[item.Id] == true)
							if not isFav and (itemSkipUntil["fuse:" .. item.Id] or 0) <= now then
								local key = charName .. "|" .. tostring(mut or "Normal")
								groups[key] = groups[key] or { name = charName, mut = mut, ids = {} }
								table.insert(groups[key].ids, item.Id)
							end
						end
					end
				end
			end
		end

		scanCharList(packsData.Backpack)
		scanCharList(packsData.Placed)

		-- ตรวจหาตัวละครที่ครบ 3 ตัว
		local targetGroup = nil
		for _, g in pairs(groups) do
			if #g.ids >= 3 then
				targetGroup = g
				break
			end
		end

		if not targetGroup then return end

		lastFuse = now
		local cName = targetGroup.name
		local id1, id2, id3 = targetGroup.ids[1], targetGroup.ids[2], targetGroup.ids[3]

		local visitOk, invokeOk, res = Helpers.VisitMutateMachine(function()
			return Net.Invoke(Net.Paths.MutateFuse, { id1, id2, id3 })
		end)

		local success, reason = isRemoteOk(res)
		if visitOk and invokeOk and success then
			local mutResult = (type(res) == "table" and res.Character and res.Character.Mutation) or "สำเร็จ"
			logAction("Fuse", string.format("กลายพันธุ์ %s สำเร็จ! (%s)", tostring(cName), tostring(mutResult)), true)
			task.wait(0.4)
		else
			local failReason = (not visitOk and tostring(invokeOk)) or reason or "ไม่ทราบสาเหตุ"
			if failReason == "MAX_MUTATION" then
				permSkipItems["fuse:" .. id1] = true
				logAction("Fuse", cName .. " ถึงระดับกลายพันธุ์สูงสุดแล้ว", false)
			else
				itemSkipUntil["fuse:" .. id1] = now + 6
				itemSkipUntil["fuse:" .. id2] = now + 6
				itemSkipUntil["fuse:" .. id3] = now + 6
				logAction("Fuse", "กลายพันธุ์ " .. tostring(cName) .. " พลาด: " .. tostring(failReason), false)
			end
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
	-- 6. UI (หน้าต่าง 4 Tab: ฟาร์ม / แพ็ก/ขาย / อัปเกรด / บันทึก)
	-----------------------------------------------------------------
	local COL_ON, COL_OFF = Color3.fromRGB(46, 160, 67), Color3.fromRGB(58, 58, 70)
	local COL_TAB = Color3.fromRGB(55, 110, 190)

	local function buildUI()
		local gui = Instance.new("ScreenGui")
		gui.Name = "KuykuyHub"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 999

		local parented = false
		if gethui then
			parented = pcall(function() gui.Parent = gethui() end)
		end
		if not parented then
			parented = pcall(function() gui.Parent = game:GetService("CoreGui") end)
		end
		if not parented or not gui.Parent then
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end
		Core:OnCleanup(function() gui:Destroy() end)

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(260, 490)
		frame.Position = UDim2.fromOffset(40, 100)
		frame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
		frame.BorderSizePixel = 0
		frame.Parent = gui
		local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 8); fc.Parent = frame

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 28)
		title.BackgroundColor3 = Color3.fromRGB(40, 40, 54)
		title.BorderSizePixel = 0
		title.Font = Enum.Font.GothamBold
		title.TextSize = 14
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Text = "Kuykuy Hub (ลากเพื่อย้าย)"
		title.Parent = frame
		local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 8); tc.Parent = title

		local dragging, dragStart, startPos = false, nil, nil
		title.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, dragStart, startPos = true, input.Position, frame.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then dragging = false end
				end)
			end
		end)
		Core:Connect(UserInputService.InputChanged, function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local d = input.Position - dragStart
				frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)

		local function makeButton(text, x, y, w, h, parent)
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(w, h)
			b.Position = UDim2.fromOffset(x, y)
			b.BackgroundColor3 = COL_OFF
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamMedium
			b.TextSize = 12
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = text
			b.Parent = parent or frame
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = b
			return b
		end

		local function addToggle(text, flag, x, y, w, h, onChange, onOff, parent)
			local b = makeButton(text, x, y, w, h, parent)
			local function paint()
				b.BackgroundColor3 = Core.Flags[flag] and COL_ON or COL_OFF
			end
			b.MouseButton1Click:Connect(function()
				Core.Flags[flag] = not Core.Flags[flag]
				paint()
				logAction("สวิตช์", (Core.Flags[flag] and "เปิด: " or "ปิด: ") .. text, Core.Flags[flag])
				if onChange and Core.Flags[flag] then onChange() end
				if onOff and not Core.Flags[flag] then onOff() end
			end)
			paint()
			return b
		end

		local function makePage()
			local p = Instance.new("Frame")
			p.Position = UDim2.fromOffset(0, 60)
			p.Size = UDim2.new(1, 0, 0, 314)
			p.BackgroundTransparency = 1
			p.Visible = false
			p.Parent = frame
			return p
		end

		local pageFarm = makePage()
		local pagePack = makePage()
		local pageUpg = makePage()
		local pageLog = makePage()
		local pages = { pageFarm, pagePack, pageUpg, pageLog }
		local tabBtns = {}

		local renderLogs = nil

		local function selectTab(idx)
			for i, p in ipairs(pages) do
				p.Visible = (i == idx)
				tabBtns[i].BackgroundColor3 = (i == idx) and COL_TAB or COL_OFF
			end
			if idx == 4 and renderLogs then
				renderLogs()
			end
		end

		local tabSpecs = {
			{ text = "ฟาร์ม", x = 8, w = 58 },
			{ text = "แพ็ก/ขาย", x = 70, w = 62 },
			{ text = "อัปเกรด", x = 136, w = 56 },
			{ text = "บันทึก", x = 196, w = 56 },
		}
		for i, spec in ipairs(tabSpecs) do
			local tb = makeButton(spec.text, spec.x, 32, spec.w, 24, frame)
			tb.MouseButton1Click:Connect(function() selectTab(i) end)
			tabBtns[i] = tb
		end

		-- Tab 1: ฟาร์ม
		addToggle("กดคูณอัตโนมัติ (คอมโบ)", "AutoTreadmill", 10, 0, 240, 28, function()
			task.spawn(function()
				if tryClickBoostPopup() then
					Stats.boosts = Stats.boosts + 1
					logAction("ลู่วิ่ง", "กดคูณสำเร็จ", true)
				end
			end)
		end, nil, pageFarm)
		addToggle("เข้าลู่วิ่งอัตโนมัติ", "AutoEnter", 10, 32, 240, 28, startEnterLoop, nil, pageFarm)
		addToggle("ขโมยแพ็คอัตโนมัติ", "AutoSteal", 10, 64, 240, 28, startStealLoop, nil, pageFarm)
		addToggle("ความเร็วสูงสุด 340 (เพดานเกม)", "MaxSpeedMode", 10, 96, 240, 26, nil, nil, pageFarm)
		addToggle("โหมดอ้อมขอบนอก (หลบบอส)", "SideBypassMode", 10, 126, 240, 26, function()
			syncSideLane(true)
		end, function()
			syncSideLane(false)
		end, pageFarm)
		addToggle("ลบอนิเมชชั่นตี/ไม่ล้ม", "AntiRagdollMode", 10, 156, 240, 26, function()
			Helpers.RecoverFromHit(LocalPlayer.Character)
		end, nil, pageFarm)

		local lbl = Instance.new("TextLabel")
		lbl.Position = UDim2.fromOffset(10, 188)
		lbl.Size = UDim2.fromOffset(240, 18)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 12
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
		lbl.Text = "ด่านที่ขโมย (กดเปิด/ปิด):"
		lbl.Parent = pageFarm

		for i = 1, 12 do
			local col = (i - 1) % 4
			local row = math.floor((i - 1) / 4)
			addToggle(tostring(i), "Stage" .. i, 10 + col * 61, 208 + row * 30, 56, 26, nil, nil, pageFarm)
		end

		-- Tab 2: แพ็ก/ขาย
		addToggle("เปิดแพ็กในกระเป๋า (Auto)", "AutoOpenPacks", 10, 0, 240, 28, startAutoOpenPacksLoop, nil, pagePack)
		addToggle("วางตัวดีสุดลงฐาน (EquipBest)", "AutoEquipBest", 10, 32, 240, 28, startAutoEquipBestLoop, nil, pagePack)
		addToggle("ขายยูนิตอัตโนมัติ (AutoSell)", "AutoSellUnits", 10, 64, 240, 28, startAutoSellLoop, nil, pagePack)

		local RARITY_NAMES = {
			[3] = "Rare (3)",
			[4] = "Epic (4)",
			[5] = "Legendary (5)",
			[6] = "Mythical (6)",
			[7] = "Cosmic (7)",
			[8] = "Divine (8)",
		}
		local rarityCycle = { 3, 4, 5, 6, 7, 8 }
		local rarityBtn = makeButton("", 10, 96, 240, 26, pagePack)
		rarityBtn.BackgroundColor3 = Color3.fromRGB(68, 68, 86)
		local function paintRarityBtn()
			local cur = Core.Flags.SellBelowRarity or 6
			rarityBtn.Text = "ขายต่ำกว่า: " .. (RARITY_NAMES[cur] or tostring(cur))
		end
		rarityBtn.MouseButton1Click:Connect(function()
			local cur = Core.Flags.SellBelowRarity or 6
			local idx = 1
			for i, v in ipairs(rarityCycle) do
				if v == cur then idx = i break end
			end
			Core.Flags.SellBelowRarity = rarityCycle[(idx % #rarityCycle) + 1]
			paintRarityBtn()
			logAction("ตั้งค่า", "ตั้งเกณฑ์ขายต่ำกว่า " .. tostring(RARITY_NAMES[Core.Flags.SellBelowRarity]))
		end)
		paintRarityBtn()

		addToggle("เก็บตัวกลายพันธุ์ (ไม่ขาย)", "KeepMutated", 10, 126, 240, 26, nil, nil, pagePack)
		addToggle("รวมแพ็กซ้ำ 2 ชิ้น (Merge)", "AutoMerge", 10, 158, 240, 28, startAutoMergeLoop, nil, pagePack)
		addToggle("กลายพันธุ์ยูนิต 3 ตัว (Fuse)", "AutoFuse", 10, 190, 240, 28, startAutoFuseLoop, nil, pagePack)

		-- Tab 3: อัปเกรด & เคลม
		addToggle("ซื้อโค้ช (Auto)", "AutoBuyCoach", 10, 0, 116, 28, startAutoBuyCoachLoop, nil, pageUpg)
		addToggle("ใส่โค้ชดีสุด", "AutoEquipCoach", 134, 0, 116, 28, startAutoEquipCoachLoop, nil, pageUpg)
		addToggle("ซื้อออร่า (Auto)", "AutoBuyAura", 10, 32, 116, 28, startAutoBuyAuraLoop, nil, pageUpg)
		addToggle("ใส่ออร่าดีสุด", "AutoEquipAura", 134, 32, 116, 28, startAutoEquipAuraLoop, nil, pageUpg)
		addToggle("อัปเกรดลู่วิ่ง (Auto)", "AutoUpgradeTreadmill", 10, 66, 240, 28, startAutoUpgradeTreadmillLoop, nil, pageUpg)
		addToggle("อัปเกรดฐาน (Auto)", "AutoUpgradeBase", 10, 98, 240, 28, startAutoUpgradeBaseLoop, nil, pageUpg)
		addToggle("เกิดใหม่อัตโนมัติ (Rebirth)", "AutoRebirth", 10, 130, 240, 28, startAutoRebirthLoop, nil, pageUpg)
		addToggle("เคลม Offline/Daily/Index", "AutoClaim", 10, 162, 240, 28, startAutoClaimLoop, nil, pageUpg)
		addToggle("กันเตะ AFK (Anti-AFK)", "AntiAfk", 10, 194, 240, 28, nil, nil, pageUpg)

		-- Tab 4: บันทึกการใช้งาน (Action Logs)
		local logHead = Instance.new("TextLabel")
		logHead.Position = UDim2.fromOffset(10, 0)
		logHead.Size = UDim2.fromOffset(150, 24)
		logHead.BackgroundTransparency = 1
		logHead.Font = Enum.Font.GothamBold
		logHead.TextSize = 12
		logHead.TextXAlignment = Enum.TextXAlignment.Left
		logHead.TextColor3 = Color3.fromRGB(220, 220, 230)
		logHead.Text = "ประวัติการทำงาน (Logs):"
		logHead.Parent = pageLog

		local clearLogBtn = makeButton("ล้างประวัติ", 168, 0, 82, 24, pageLog)
		clearLogBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
		clearLogBtn.MouseButton1Click:Connect(function()
			table.clear(Stats.logs)
			if renderLogs then renderLogs() end
		end)

		local logScroll = Instance.new("ScrollingFrame")
		logScroll.Position = UDim2.fromOffset(8, 28)
		logScroll.Size = UDim2.fromOffset(244, 282)
		logScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		logScroll.BorderSizePixel = 0
		logScroll.ScrollBarThickness = 4
		logScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 110)
		logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		logScroll.Parent = pageLog
		local lsc = Instance.new("UICorner"); lsc.CornerRadius = UDim.new(0, 6); lsc.Parent = logScroll
		local lsp = Instance.new("UIPadding"); lsp.PaddingTop = UDim.new(0, 4); lsp.PaddingBottom = UDim.new(0, 4); lsp.PaddingLeft = UDim.new(0, 6); lsp.PaddingRight = UDim.new(0, 6); lsp.Parent = logScroll
		local lsl = Instance.new("UIListLayout"); lsl.SortOrder = Enum.SortOrder.LayoutOrder; lsl.Padding = UDim.new(0, 3); lsl.Parent = logScroll

		renderLogs = function()
			for _, ch in ipairs(logScroll:GetChildren()) do
				if ch:IsA("TextLabel") then
					ch:Destroy()
				end
			end
			if #Stats.logs == 0 then
				local empty = Instance.new("TextLabel")
				empty.Size = UDim2.new(1, 0, 0, 24)
				empty.BackgroundTransparency = 1
				empty.Font = Enum.Font.Gotham
				empty.TextSize = 11
				empty.TextColor3 = Color3.fromRGB(130, 130, 145)
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
				local color = Color3.fromRGB(200, 225, 255)
				if item.ok == true then
					color = Color3.fromRGB(110, 240, 130)
				elseif item.ok == false then
					color = Color3.fromRGB(255, 115, 115)
				end
				row.TextColor3 = color
				row.Text = string.format("[%s] [%s] %s", item.time, item.cat, item.msg)
				row.Parent = logScroll
			end
		end

		Core._updateLogUI = function()
			if pageLog.Visible and renderLogs then
				renderLogs()
			end
		end

		selectTab(1)

		local status = Instance.new("TextLabel")
		status.Position = UDim2.fromOffset(10, 378)
		status.Size = UDim2.fromOffset(240, 68)
		status.BackgroundTransparency = 1
		status.Font = Enum.Font.Gotham
		status.TextSize = 11
		status.TextWrapped = true
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextYAlignment = Enum.TextYAlignment.Top
		status.TextColor3 = Color3.fromRGB(170, 220, 255)
		status.Text = ""
		status.Parent = frame

		local unload = makeButton("ปิดสคริปต์ (Unload)", 10, 456, 240, 24, frame)
		unload.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
		unload.MouseButton1Click:Connect(function() Core:Destroy() end)

		Core.Flags.UI = true
		Core:Loop("status", "UI", 0.5, function()
			local combo = LocalPlayer:GetAttribute(COMBO_ATTR) or 0
			local training = LocalPlayer:GetAttribute(TRAINING_ATTR) ~= nil
			local spd = math.floor(Helpers.GetMoveSpeed() + 0.5)
			status.Text = string.format(
				"ลู่วิ่ง: %s | คูณ %d | คอมโบ %s | วิ่ง %d\nขโมย: สำเร็จ %d / พลาด %d\nล่าสุด: %s",
				training and "กำลังวิ่ง" or "ไม่ได้วิ่ง", Stats.boosts, tostring(combo), spd,
				Stats.stealOk, Stats.stealFail, tostring(Stats.last or "-")
			)
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