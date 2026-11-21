--!nonstrict
-- =====================================================================
-- KUYKUY HUB - Anime Fight (Anime Idle) | PlaceId 110387159727292
-- Feature 1: Auto Buy Chest (Min Price + Multi-Select Mutation Tiers)
-- =====================================================================

local function main()
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	local UserInputService = game:GetService("UserInputService")

	local LocalPlayer = Players.LocalPlayer
	local PlaceId = game.PlaceId
	local ENV = (getgenv and getgenv()) or _G

	-- kill previous instance
	if ENV.__KUYKUY_ANIMEFIGHT and ENV.__KUYKUY_ANIMEFIGHT.Destroy then
		pcall(ENV.__KUYKUY_ANIMEFIGHT.Destroy, ENV.__KUYKUY_ANIMEFIGHT)
	end

	-- =================================================================
	-- 1. CORE
	-- =================================================================
	local Core = { Flags = {}, Busy = false, _conns = {}, _loops = {}, _alive = true }
	ENV.__KUYKUY_ANIMEFIGHT = Core

	function Core:Connect(signal, fn)
		local c = signal:Connect(fn)
		table.insert(self._conns, c)
		return c
	end

	function Core:Loop(name, flag, interval, fn)
		if self._loops[name] then pcall(task.cancel, self._loops[name]) end
		self._loops[name] = task.spawn(function()
			while self._alive and self.Flags[flag] do
				local ok, err = pcall(fn)
				if not ok then warn(string.format("[%s Loop Error]: %s", name, tostring(err))) end
				task.wait(interval)
			end
			self._loops[name] = nil
		end)
	end

	function Core:Destroy()
		self._alive = false
		for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
		for _, th in pairs(self._loops) do pcall(task.cancel, th) end
		table.clear(self._conns)
		table.clear(self._loops)
		if self._gui then pcall(function() self._gui:Destroy() end) end
	end

	-- =================================================================
	-- 2. STATS / LOGS (Circular Buffer)
	-- =================================================================
	local Stats = { logs = {}, bought = 0, spent = 0 }
	local function logAction(cat, msg, ok)
		table.insert(Stats.logs, 1, { time = os.date("%H:%M:%S"), cat = cat, msg = tostring(msg), ok = ok })
		if #Stats.logs > 80 then table.remove(Stats.logs) end
		if Core._updateLogUI then pcall(Core._updateLogUI) end
	end
	Stats.log = logAction

	-- =================================================================
	-- 3. CONFIG PERSISTENCE
	-- =================================================================
	local Config = {
		Folder = "kuykuy_hub",
		File = string.format("kuykuy_hub/animefight_%s.json", tostring(PlaceId)),
		Defaults = {
			AutoBuyChest = false,
			MinPrice = 0,
			Tiers = { Normal = true },
			TeleportToBelt = true,
			ReturnAfterBuy = true,
			AutoPlaceChest = true,
			AutoOpenChest = false,
			AutoReplay = false,
			AutoNextStage = false,
			AutoUpgradeSkill = false,
			AutoDungeon = false,
			DungeonId = "ShrineGrounds",
			DungeonStartFloor = 1,
			DungeonEndFloor = 10,
		},
	}

	function Config.Save()
		local ok, encoded = pcall(function() return HttpService:JSONEncode(Core.Flags) end)
		if not ok then return false end
		ENV.__KUYKUY_ANIMEFIGHT_CACHE = encoded
		if writefile then
			pcall(function()
				if isfolder and makefolder and not isfolder(Config.Folder) then makefolder(Config.Folder) end
				writefile(Config.File, encoded)
			end)
		end
		return true
	end

	function Config.Load()
		for k, v in pairs(Config.Defaults) do
			if type(v) == "table" then
				local t = {}
				for kk, vv in pairs(v) do t[kk] = vv end
				Core.Flags[k] = t
			else
				Core.Flags[k] = v
			end
		end
		local content
		if readfile and isfile then
			local okF, exists = pcall(isfile, Config.File)
			if okF and exists then
				local okR, data = pcall(readfile, Config.File)
				if okR then content = data end
			end
		end
		content = content or ENV.__KUYKUY_ANIMEFIGHT_CACHE
		if type(content) ~= "string" or content == "" then return false end
		local okD, decoded = pcall(function() return HttpService:JSONDecode(content) end)
		if not okD or type(decoded) ~= "table" then return false end
		for k, v in pairs(decoded) do
			if Config.Defaults[k] ~= nil and type(v) == type(Config.Defaults[k]) then
				Core.Flags[k] = v
			end
		end
		return true
	end

	function Config.Set(key, value)
		Core.Flags[key] = value
		Config.Save()
	end

	-- =================================================================
	-- 4. NET (Timeout Guard - reserved for future Remote calls)
	-- =================================================================
	local Net = {}
	function Net.Invoke(inst, ...)
		if not Core._alive or not inst or not inst:IsA("RemoteFunction") then return false, "INVALID_REMOTE" end
		local args = table.pack(...)
		local done, results = false, nil
		task.spawn(function()
			results = table.pack(pcall(function() return inst:InvokeServer(table.unpack(args, 1, args.n)) end))
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 3.5 and Core._alive do task.wait(0.03) end
		if not done then return false, "TIMEOUT" end
		if not results[1] then return false, results[2] end
		return true, table.unpack(results, 2, results.n)
	end

	-- ReplicatedStorage.Events.AnimeIdle.<name> (cached)
	Net._cache = {}
	function Net.Remote(name: string)
		local c = Net._cache[name]
		if c and c.Parent then return c end
		local ev = ReplicatedStorage:FindFirstChild("Events")
		ev = ev and ev:FindFirstChild("AnimeIdle")
		local r = ev and ev:FindFirstChild(name)
		Net._cache[name] = r
		return r
	end

	-- =================================================================
	-- 5. HELPERS
	-- =================================================================
	local Helpers = { _plot = nil, _cfg = nil, _upgradeDefs = nil, _dungeonCfg = nil, SkillTree = {}, _skillSynced = false }

	function Helpers.GetDungeons()
		if not Helpers._dungeonCfg then
			local ok, mod = pcall(function()
				return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Gameplay"):WaitForChild("DungeonConfig"))
			end)
			if ok and type(mod) == "table" then Helpers._dungeonCfg = mod end
		end
		local list = {}
		if Helpers._dungeonCfg and type(Helpers._dungeonCfg.Dungeons) == "table" then
			for _, d in ipairs(Helpers._dungeonCfg.Dungeons) do
				if d.Id then
					table.insert(list, { id = tostring(d.Id), name = tostring(d.Name or d.Id) })
				end
			end
		end
		if #list == 0 then
			list = {
				{ id = "ShrineGrounds", name = "Shrine Grounds" },
				{ id = "JadePalace", name = "Jade Palace" },
				{ id = "RaijinStorm", name = "Raijin Storm" },
				{ id = "DivineSanctum", name = "Divine Sanctum" },
				{ id = "OniDemonFortress", name = "Oni Demon Fortress" },
				{ id = "BloodMoonCitadel", name = "Blood Moon Citadel" },
				{ id = "AstralWorld", name = "Astral Awakening" },
			}
		end
		return list
	end

	function Helpers.GetConfig()
		if Helpers._cfg then return Helpers._cfg end
		local ok, mod = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Gameplay"):WaitForChild("AnimeIdleConfig"))
		end)
		if ok and type(mod) == "table" then Helpers._cfg = mod end
		return Helpers._cfg
	end

	function Helpers.GetUpgradeDefs()
		if Helpers._upgradeDefs then return Helpers._upgradeDefs end
		local ok, mod = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("UpgradeTreeController"):WaitForChild("UpgradeDefinitions"))
		end)
		if ok and type(mod) == "table" then Helpers._upgradeDefs = mod end
		return Helpers._upgradeDefs
	end

	function Helpers.GetRoot()
		local c = LocalPlayer.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end

	function Helpers.IsAlive()
		local c = LocalPlayer.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		return h ~= nil and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil
	end

	function Helpers.GetCash(): number
		return tonumber(LocalPlayer:GetAttribute("Cash")) or 0
	end

	-- auto find & cache LocalPlayer plot (no hardcode)
	function Helpers.GetPlot()
		local cached = Helpers._plot
		if cached and cached.Parent and cached:GetAttribute("OwnerUserId") == LocalPlayer.UserId then return cached end
		Helpers._plot = nil
		local lobby = Workspace:FindFirstChild("Lobby")
		local plots = lobby and lobby:FindFirstChild("Plots")
		if not plots then return nil end
		local pid = LocalPlayer:GetAttribute("PlotId")
		local byId = pid and plots:FindFirstChild(tostring(pid))
		if byId and byId:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			Helpers._plot = byId
			return byId
		end
		for _, p in ipairs(plots:GetChildren()) do
			if p:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
				Helpers._plot = p
				return p
			end
		end
		return nil
	end

	-- "1.5M" / "250k" / "1,000" -> number
	function Helpers.ParseAmount(text: string): number?
		if type(text) ~= "string" then return nil end
		local s = text:gsub("[,%s¥]", ""):upper()
		local num, suf = s:match("^([%d%.]+)([KMBTQ]?)$")
		local n = tonumber(num)
		if not n then return nil end
		local mult = ({ K = 1e3, M = 1e6, B = 1e9, T = 1e12, Q = 1e15 })[suf] or 1
		return math.floor(n * mult + 0.5)
	end

	function Helpers.Format(n: number): string
		local cfg = Helpers.GetConfig()
		if cfg and type(cfg.FormatShort) == "function" then
			local ok, s = pcall(cfg.FormatShort, n)
			if ok and s then return tostring(s) end
		end
		return tostring(n)
	end

	-- tier key of a chest: "Normal" or mutation name (Silver/Gold/Diamond/...)
	function Helpers.ChestTier(chest): string
		local m = chest:GetAttribute("Mutation")
		if type(m) == "string" and m ~= "" then return m end
		return "Normal"
	end

	function Helpers.ChestPrice(chest): number
		local attr = tonumber(chest:GetAttribute("Price")) or 0
		local cfg = Helpers.GetConfig()
		local tier = tonumber(chest:GetAttribute("Tier"))
		if cfg and tier and type(cfg.ChestPrice) == "function" then
			local mut = chest:GetAttribute("Mutation")
			local ok, p = pcall(cfg.ChestPrice, tier, (type(mut) == "string" and mut ~= "") and mut or nil)
			if ok and tonumber(p) then return math.max(attr, tonumber(p)) end
		end
		return attr
	end

	-- BeltAnchor (Part + BUY prompt) pairs with chest model by XZ position
	function Helpers.FindAnchor(folder, chest)
		local pivot = chest:GetPivot().Position
		local rarity = chest:GetAttribute("Rarity")
		local best, bestD = nil, 6
		for _, a in ipairs(folder:GetChildren()) do
			if a:IsA("BasePart") then
				local pr = a:FindFirstChildOfClass("ProximityPrompt")
				if pr and pr.Enabled and (rarity == nil or pr:GetAttribute("Rarity") == nil or pr:GetAttribute("Rarity") == rarity) then
					local d = Vector3.new(a.Position.X - pivot.X, 0, a.Position.Z - pivot.Z).Magnitude
					if d < bestD then best, bestD = pr, d end
				end
			end
		end
		return best
	end

	-- dynamic tier list (Normal + AnimeIdleConfig.MutationOrder + any Mutation seen on map)
	Helpers.TierList = { "Normal" }
	function Helpers.RefreshTiers(): boolean
		local list, seen = { "Normal" }, { Normal = true }
		local cfg = Helpers.GetConfig()
		if cfg and type(cfg.MutationOrder) == "table" then
			for _, m in ipairs(cfg.MutationOrder) do
				if type(m) == "string" and not seen[m] then seen[m] = true; table.insert(list, m) end
			end
		end
		if cfg and type(cfg.Mutations) == "table" then
			for m in pairs(cfg.Mutations) do
				if type(m) == "string" and not seen[m] then seen[m] = true; table.insert(list, m) end
			end
		end
		local lobby = Workspace:FindFirstChild("Lobby")
		local plots = lobby and lobby:FindFirstChild("Plots")
		if plots then
			for _, p in ipairs(plots:GetChildren()) do
				local ac = p:FindFirstChild("ActiveChests")
				if ac then
					for _, c in ipairs(ac:GetChildren()) do
						if c:IsA("Model") then
							local t = Helpers.ChestTier(c)
							if not seen[t] then seen[t] = true; table.insert(list, t) end
						end
					end
				end
			end
		end
		local changed = #list ~= #Helpers.TierList
		if not changed then
			for i, v in ipairs(list) do if Helpers.TierList[i] ~= v then changed = true break end end
		end
		Helpers.TierList = list
		return changed
	end

	function Helpers.TriggerPrompt(prompt): boolean
		if fireproximityprompt then
			local ok = pcall(fireproximityprompt, prompt)
			if ok then return true end
		end
		local ok = pcall(function()
			prompt:InputHoldBegin()
			task.wait((prompt.HoldDuration or 0) + 0.05)
			prompt:InputHoldEnd()
		end)
		return ok
	end

	Helpers._chestTemplates = nil
	function Helpers.GetChestTemplate(tier: number)
		if not Helpers._chestTemplates then
			Helpers._chestTemplates = {}
			local assets = ReplicatedStorage:FindFirstChild("Assets")
			local chests = assets and assets:FindFirstChild("Chests")
			if chests then
				for _, c in ipairs(chests:GetChildren()) do
					local t = c:GetAttribute("Tier")
					if type(t) == "number" then Helpers._chestTemplates[t] = c end
				end
			end
		end
		return Helpers._chestTemplates[tier]
	end

	function Helpers.FindFreeSpot(plot, tier: number)
		local build = plot and plot:FindFirstChild("Build")
		local cfg = Helpers.GetConfig()
		local tmpl = Helpers.GetChestTemplate(tier)
		if not (build and cfg and tmpl) then return nil, nil end

		local hx, hz = cfg.Footprint(tmpl, 0)
		local maxX, maxZLim = cfg.BuildLimits(build, hx, hz)
		local maxZ = cfg.BuildMaxZ(hz, maxZLim)

		local placed = {}
		local folder = plot:FindFirstChild("PlacedChests")
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				local lx, lz, ptier = child:GetAttribute("LX"), child:GetAttribute("LZ"), child:GetAttribute("Tier")
				if lx and lz and ptier and not child:GetAttribute("Opening") then
					local pt = Helpers.GetChestTemplate(ptier)
					if pt then
						local phx, phz = cfg.Footprint(pt, child:GetAttribute("Rot"))
						table.insert(placed, { x = lx, z = lz, hx = phx, hz = phz })
					end
				end
			end
		end

		local stepX = math.max(1.5, hx * 2 + 0.4)
		local stepZ = math.max(1.5, hz * 2 + 0.4)
		local x = -maxX
		while x <= maxX + 0.001 do
			local z = -maxZLim
			while z <= maxZ + 0.001 do
				if cfg.FitsBuild(build, x, z, hx, hz) then
					local overlap = false
					for _, v in ipairs(placed) do
						if cfg.Overlaps(x, z, hx, hz, v.x, v.z, v.hx, v.hz) then
							overlap = true
							break
						end
					end
					if not overlap then return x, z end
				end
				z += stepZ
			end
			x += stepX
		end
		return nil, nil
	end

	-- =================================================================
	-- 6. LOOPS
	-- =================================================================
	local Loops = { attempts = setmetatable({}, { __mode = "k" }), backoffUntil = 0, lastBuyAt = 0, lastReplayAt = 0, lastNextAt = 0, lastDungeonAt = 0 }

	function Loops.SelectTargets()
		local plot = Helpers.GetPlot()
		local folder = plot and plot:FindFirstChild("ActiveChests")
		if not folder then return nil, nil end
		local minPrice = tonumber(Core.Flags.MinPrice) or 0
		local tiers = Core.Flags.Tiers or {}
		local cash = Helpers.GetCash()
		local list = {}
		for _, chest in ipairs(folder:GetChildren()) do
			if chest:IsA("Model") and (Loops.attempts[chest] or 0) < 3 then
				local price = Helpers.ChestPrice(chest)
				local tier = Helpers.ChestTier(chest)
				if tiers[tier] == true and price >= minPrice and price <= cash then
					table.insert(list, { chest = chest, price = price, tier = tier })
				end
			end
		end
		table.sort(list, function(a, b) return a.price > b.price end)
		return list, folder
	end

	function Loops.BuyChest(entry, folder): boolean
		local chest = entry.chest
		local prompt = Helpers.FindAnchor(folder, chest)
		if not prompt then return false end
		local anchor = prompt.Parent
		local hrp = Helpers.GetRoot()
		if not (hrp and Helpers.IsAlive() and anchor and anchor:IsA("BasePart")) then return false end

		Loops.attempts[chest] = (Loops.attempts[chest] or 0) + 1
		local origin = hrp.CFrame
		local moved = false
		local reach = math.max(4, (prompt.MaxActivationDistance or 12) - 2)
		local function snapToAnchor()
			if not (hrp and hrp.Parent and anchor and anchor:IsA("BasePart")) then return false end
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(anchor.Position + Vector3.new(0, 2, 0))
			moved = true
			return true
		end

		if (hrp.Position - anchor.Position).Magnitude > reach then
			if not Core.Flags.TeleportToBelt then return false end
			snapToAnchor()
			task.wait(0.22)
		end

		local cashBefore = Helpers.GetCash()
		local tierNum = tonumber(chest:GetAttribute("Tier"))
		local mutAttr = chest:GetAttribute("Mutation")
		local mutArg = (type(mutAttr) == "string" and mutAttr ~= "") and mutAttr or nil
		local label = string.format("%s %s (¥%s)", entry.tier ~= "Normal" and entry.tier or "", tostring(chest:GetAttribute("ChestName") or chest.Name), Helpers.Format(entry.price))

		local t0, ok, fired = os.clock(), false, false
		local lastFire = 0
		while os.clock() - t0 < 1.8 and Core._alive and Helpers.IsAlive() do
			if not chest.Parent or Helpers.GetCash() < cashBefore then
				ok = true
				break
			end
			if os.clock() < Loops.backoffUntil then break end

			if not (anchor and anchor.Parent and prompt and prompt.Parent and prompt.Enabled) then
				prompt = Helpers.FindAnchor(folder, chest)
				anchor = prompt and prompt.Parent or nil
			end
			if prompt and anchor and anchor:IsA("BasePart") then
				hrp = Helpers.GetRoot()
				if not hrp then break end
				if (hrp.Position - anchor.Position).Magnitude > math.max(3, reach * 0.65) then
					if not Core.Flags.TeleportToBelt then break end
					snapToAnchor()
					task.wait(0.15)
					if not chest.Parent or Helpers.GetCash() < cashBefore then
						ok = true
						break
					end
				end
				if os.clock() - lastFire >= 0.28 then
					if Helpers.TriggerPrompt(prompt) then fired = true end
					lastFire = os.clock()
					Loops.lastBuyAt = lastFire
				end
			end
			task.wait(0.05)
		end

		if moved and Core.Flags.ReturnAfterBuy then
			local r = Helpers.GetRoot()
			if r then
				r.AssemblyLinearVelocity = Vector3.zero
				r.AssemblyAngularVelocity = Vector3.zero
				r.CFrame = origin
			end
		end

		if ok then
			Stats.bought += 1
			Stats.spent += math.max(0, cashBefore - Helpers.GetCash())
			logAction("BUY", "ซื้อสำเร็จ: " .. label, true)
			if Core.Flags.AutoPlaceChest and tierNum then
				task.wait(0.15)
				Loops.PlaceChest(tierNum, mutArg)
			end
		else
			logAction("BUY", (fired and "ไม่สำเร็จ: " or "Trigger ล้มเหลว: ") .. label, false)
		end
		return ok
	end

	function Loops.PlaceChest(tier: number, mutation: string?): boolean
		local plot = Helpers.GetPlot()
		local remote = Net.Remote("PlaceChest")
		if not (plot and remote) then return false end
		local lx, lz = Helpers.FindFreeSpot(plot, tier)
		if not (lx and lz) then
			logAction("PLACE", "พื้นที่ฐานเต็ม ไม่สามารถวางกล่องได้", false)
			return false
		end
		for attempt = 1, 2 do
			local ok, res, err = Net.Invoke(remote, tier, lx, lz, mutation, 0)
			if ok and res then
				logAction("PLACE", string.format("วางกล่องที่ฐานสำเร็จ (Tier %d)", tier), true)
				return true
			end
			if attempt == 1 then task.wait(0.25) else
				logAction("PLACE", "วางกล่องไม่สำเร็จ: " .. tostring(err or res), false)
			end
		end
		return false
	end

	function Loops.AutoOpenTick()
		if Core.Busy then return end
		if not Helpers.IsAlive() then return end
		local plot = Helpers.GetPlot()
		local placed = plot and plot:FindFirstChild("PlacedChests")
		if not placed then return end
		local now = Workspace:GetServerTimeNow()
		local target, prompt
		for _, chest in ipairs(placed:GetChildren()) do
			if chest:IsA("Model") and not chest:GetAttribute("Opening") then
				local readyAt = tonumber(chest:GetAttribute("ReadyAt"))
				if readyAt and readyAt <= now then
					local p = chest:FindFirstChild("OpenPrompt", true)
					if p and p:IsA("ProximityPrompt") and p.Enabled then
						target, prompt = chest, p
						break
					end
				end
			end
		end
		if not (target and prompt) then return end

		local hrp = Helpers.GetRoot()
		local part = prompt.Parent
		local pos = (part and part:IsA("BasePart")) and part.Position or target:GetPivot().Position
		if not hrp then return end

		Core.Busy = true
		local origin = hrp.CFrame
		local moved = false
		local reach = (prompt.MaxActivationDistance or 12) - 2
		if (hrp.Position - pos).Magnitude > reach then
			hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
			moved = true
			task.wait(0.12)
		end

		local fired = Helpers.TriggerPrompt(prompt)
		local t0, opened = os.clock(), false
		while os.clock() - t0 < 1.5 and Core._alive do
			if not target.Parent or target:GetAttribute("Opening") or not prompt.Enabled then
				opened = true
				break
			end
			task.wait(0.05)
		end

		if moved and Core.Flags.ReturnAfterBuy then
			local r = Helpers.GetRoot()
			if r then r.CFrame = origin end
		end
		Core.Busy = false

		if opened then
			logAction("OPEN", "เปิดกล่องสำเร็จ: " .. target.Name, true)
		elseif fired then
			logAction("OPEN", "รอเปิดกล่อง: " .. target.Name, false)
		end
	end

	function Loops.StartAutoOpen()
		if Core.Flags.AutoOpenChest then
			Core:Loop("AutoOpenChest", "AutoOpenChest", 0.5, Loops.AutoOpenTick)
		end
	end

	function Loops.GoHome(tag: string)
		local goHome = Net.Remote("GoHome")
		if not (goHome and goHome:IsA("RemoteEvent")) then return end
		task.delay(1, function()
			if not Core._alive then return end
			local ok = pcall(function()
				goHome:FireServer()
			end)
			if ok then
				logAction(tag, "กลับมายืนที่บ้าน (GoHome) สำเร็จ", true)
			end
		end)
	end

	function Loops.AutoReplayTick()
		if Core.Flags.AutoDungeon and LocalPlayer:GetAttribute("BattleKind") == "Dungeon" then return end
		if os.clock() - Loops.lastReplayAt < 3 then return end
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local endScreen = results and results:FindFirstChild("EndScreen")
		if not (endScreen and endScreen:IsA("GuiObject") and endScreen.Visible) then return end

		if Core.Flags.AutoNextStage then
			local left = endScreen:FindFirstChild("Left")
			local buttons = left and left:FindFirstChild("Buttons")
			local nextBtn = buttons and buttons:FindFirstChild("Next")
			if nextBtn and nextBtn:IsA("GuiObject") and nextBtn.Visible then return end
		end

		local remote = Net.Remote("BattleRequest")
		if not remote then return end
		Loops.lastReplayAt = os.clock()
		local ok, res, err = Net.Invoke(remote, "Replay")
		if ok and res ~= false then
			logAction("REPLAY", "ส่งคำสั่งเล่นซ้ำ (Replay) สำเร็จ", true)
			Loops.GoHome("REPLAY")
		else
			logAction("REPLAY", "เล่นซ้ำไม่สำเร็จ: " .. tostring(err or res), false)
		end
	end

	function Loops.StartAutoReplay()
		if Core.Flags.AutoReplay then
			Core:Loop("AutoReplay", "AutoReplay", 0.8, Loops.AutoReplayTick)
		end
	end

	function Loops.AutoNextStageTick()
		if Core.Flags.AutoDungeon and LocalPlayer:GetAttribute("BattleKind") == "Dungeon" then return end
		if os.clock() - Loops.lastNextAt < 3 then return end
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local endScreen = results and results:FindFirstChild("EndScreen")
		if not (endScreen and endScreen:IsA("GuiObject") and endScreen.Visible) then return end

		local left = endScreen:FindFirstChild("Left")
		local buttons = left and left:FindFirstChild("Buttons")
		local nextBtn = buttons and buttons:FindFirstChild("Next")
		if not (nextBtn and nextBtn:IsA("GuiObject") and nextBtn.Visible) then return end

		local remote = Net.Remote("BattleRequest")
		if not remote then return end
		Loops.lastNextAt = os.clock()
		local ok, res, err = Net.Invoke(remote, "NextAct")
		if ok and res ~= false then
			logAction("NEXT", "ส่งคำสั่งเล่นด่านถัดไป (NextAct) สำเร็จ", true)
			Loops.GoHome("NEXT")
		else
			logAction("NEXT", "ไปด่านถัดไปไม่สำเร็จ: " .. tostring(err or res), false)
		end
	end

	function Loops.StartAutoNextStage()
		if Core.Flags.AutoNextStage then
			Core:Loop("AutoNextStage", "AutoNextStage", 0.8, Loops.AutoNextStageTick)
		end
	end

	function Loops.AutoDungeonTick()
		if os.clock() - Loops.lastDungeonAt < 2 then return end
		local battleReq = Net.Remote("BattleRequest")
		if not battleReq then return end

		local dungeonId = tostring(Core.Flags.DungeonId or "ShrineGrounds")
		local startFloor = math.max(1, math.floor(tonumber(Core.Flags.DungeonStartFloor) or 1))
		local endFloor = math.max(startFloor, math.floor(tonumber(Core.Flags.DungeonEndFloor) or 10))

		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local endScreen = results and results:FindFirstChild("EndScreen")
		if endScreen and endScreen:IsA("GuiObject") and endScreen.Visible then
			Loops.lastDungeonAt = os.clock()
			local ok, res, err = Net.Invoke(battleReq, "Quit")
			if ok and res ~= false then
				logAction("DUNGEON", "จบการต่อสู้ -> ออกจากหน้าสรุปผลเพื่อเริ่มใหม่", true)
			else
				logAction("DUNGEON", "ออกจากหน้าสรุปผลไม่สำเร็จ: " .. tostring(err or res), false)
			end
			return
		end

		if LocalPlayer:GetAttribute("InBattle") == true then
			if LocalPlayer:GetAttribute("BattleKind") == "Dungeon" then
				local floor = tonumber(LocalPlayer:GetAttribute("BattleFloor")) or 0
				if floor > endFloor then
					Loops.lastDungeonAt = os.clock()
					local ok, res, err = Net.Invoke(battleReq, "Quit")
					if ok and res ~= false then
						logAction("DUNGEON", string.format("จบชั้น %d แล้ว -> ออกจากดันเจียน (%s)", endFloor, dungeonId), true)
					else
						logAction("DUNGEON", "ออกจากดันเจียนไม่สำเร็จ: " .. tostring(err or res), false)
					end
				end
			end
			return
		end

		Loops.lastDungeonAt = os.clock()
		local ok, res, err = Net.Invoke(battleReq, "Start", dungeonId, startFloor)
		if ok and res ~= false then
			logAction("DUNGEON", string.format("เริ่มลงดันเจียน %s (ชั้น %d -> %d)", dungeonId, startFloor, endFloor), true)
			Loops.GoHome("DUNGEON")
		else
			logAction("DUNGEON", "เข้าดันเจียนไม่สำเร็จ: " .. tostring(err or res), false)
		end
	end

	function Loops.StartAutoDungeon()
		if Core.Flags.AutoDungeon then
			Core:Loop("AutoDungeon", "AutoDungeon", 0.8, Loops.AutoDungeonTick)
		end
	end

	function Loops.RequestSkillSync()
		local now = os.clock()
		if now - (Loops.lastSkillSyncAt or 0) < 4 then return end
		Loops.lastSkillSyncAt = now
		local req = Net.Remote("RequestInventory")
		if req and req:IsA("RemoteEvent") then
			pcall(function() req:FireServer() end)
		end
	end

	function Loops.AutoUpgradeSkillTick()
		if os.clock() < (Loops.skillBackoffUntil or 0) then return end
		if not Helpers._skillSynced then
			Loops.RequestSkillSync()
			return
		end
		local defs = Helpers.GetUpgradeDefs()
		if not (defs and type(defs.Order) == "table" and type(defs.Get) == "function" and type(defs.ArePrerequisitesMet) == "function") then return end
		local remote = Net.Remote("PurchaseSkillNode")
		if not remote then return end

		local cash = Helpers.GetCash()
		local bestNode, bestPrice = nil, math.huge
		for _, id in ipairs(defs.Order) do
			if Helpers.SkillTree[id] ~= true then
				local node = defs.Get(id)
				if node and defs.ArePrerequisitesMet(Helpers.SkillTree, node) then
					local price = tonumber(node.Price) or 0
					if price <= cash and price < bestPrice then
						bestNode, bestPrice = node, price
					end
				end
			end
		end
		if not bestNode then return end

		local ok, res, err = Net.Invoke(remote, bestNode.Id)
		if ok and res == true then
			Helpers.SkillTree[bestNode.Id] = true
			logAction("SKILL", string.format("อัปเกรด %s (-¥%s)", tostring(bestNode.DisplayName or bestNode.Id), Helpers.Format(bestPrice)), true)
		else
			Loops.skillBackoffUntil = os.clock() + 3
			logAction("SKILL", string.format("อัปเกรด %s ไม่สำเร็จ: %s", tostring(bestNode.DisplayName or bestNode.Id), tostring(err or res)), false)
		end
	end

	function Loops.StartAutoUpgradeSkill()
		if Core.Flags.AutoUpgradeSkill then
			if not Helpers._skillSynced then Loops.RequestSkillSync() end
			Core:Loop("AutoUpgradeSkill", "AutoUpgradeSkill", 0.6, Loops.AutoUpgradeSkillTick)
		end
	end

	function Loops.AutoBuyTick()
		if Core.Busy or os.clock() < Loops.backoffUntil then return end
		if not Helpers.IsAlive() then return end
		local list, folder = Loops.SelectTargets()
		if not list or #list == 0 then return end
		Core.Busy = true
		local ok, err = pcall(Loops.BuyChest, list[1], folder)
		Core.Busy = false
		if not ok then logAction("ERR", err, false) end
	end

	function Loops.StartAutoBuy()
		if Core.Flags.AutoBuyChest then
			Core:Loop("AutoBuyChest", "AutoBuyChest", 0.25, Loops.AutoBuyTick)
		end
	end

	-- Notify & InventoryChanged listeners
	task.spawn(function()
		local ev = ReplicatedStorage:WaitForChild("Events", 10)
		ev = ev and ev:WaitForChild("AnimeIdle", 10)
		if not (ev and Core._alive) then return end
		local invChanged = ev:FindFirstChild("InventoryChanged")
		if invChanged and invChanged:IsA("RemoteEvent") then
			Core:Connect(invChanged.OnClientEvent, function(data)
				if type(data) == "table" and type(data.skillTree) == "table" then
					Helpers.SkillTree = data.skillTree
					Helpers._skillSynced = true
				end
			end)
		end
		local notify = ev:WaitForChild("Notify", 10)
		if not (notify and notify:IsA("RemoteEvent") and Core._alive) then return end
		Core:Connect(notify.OnClientEvent, function(msg, kind)
			if os.clock() - Loops.lastBuyAt > 2.5 then return end
			msg = tostring(msg)
			if kind ~= "Success" then
				Loops.backoffUntil = os.clock() + 5
				logAction("GAME", msg .. " (พัก 5s)", false)
			end
		end)
	end)

	-- =================================================================
	-- 7. UI
	-- =================================================================
	local UI = {}
	do
		local parentGui
		pcall(function() parentGui = gethui and gethui() end)
		if not parentGui then pcall(function() parentGui = game:GetService("CoreGui") end) end
		if not parentGui then parentGui = LocalPlayer:WaitForChild("PlayerGui") end

		local gui = Instance.new("ScreenGui")
		gui.Name = "KuykuyHub_AnimeFight"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local okP = pcall(function() gui.Parent = parentGui end)
		if not okP then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
		Core._gui = gui

		local C_BG, C_PANEL, C_ACC, C_TXT, C_SUB = Color3.fromRGB(22, 22, 28), Color3.fromRGB(34, 34, 44), Color3.fromRGB(255, 140, 60), Color3.fromRGB(235, 235, 240), Color3.fromRGB(150, 150, 165)

		local function corner(o, r)
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = o
		end
		local function mk(cls, props, parent)
			local o = Instance.new(cls)
			for k, v in pairs(props) do o[k] = v end
			o.Parent = parent
			return o
		end
		UI.mk, UI.corner = mk, corner

		local main = mk("Frame", { Size = UDim2.fromOffset(300, 430), Position = UDim2.new(0, 40, 0.5, -215), BackgroundColor3 = C_BG, BorderSizePixel = 0, Active = true }, gui)
		corner(main, 8)
		local top = mk("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, main)
		corner(top, 8)
		mk("TextLabel", { Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "KUYKUY HUB | Anime Fight", TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left }, top)
		local btnMin = mk("TextButton", { Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -58, 0, 4), BackgroundColor3 = C_BG, Text = "-", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 14 }, top)
		corner(btnMin, 4)
		local btnClose = mk("TextButton", { Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -30, 0, 4), BackgroundColor3 = Color3.fromRGB(170, 50, 50), Text = "X", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 12 }, top)
		corner(btnClose, 4)

		local body = mk("ScrollingFrame", { Size = UDim2.new(1, -12, 1, -38), Position = UDim2.fromOffset(6, 34), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, main)
		mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)

		-- drag
		do
			local dragging, dStart, pStart
			Core:Connect(top.InputBegan, function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					dragging, dStart, pStart = true, i.Position, main.Position
				end
			end)
			Core:Connect(UserInputService.InputChanged, function(i)
				if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
					local d = i.Position - dStart
					main.Position = UDim2.new(pStart.X.Scale, pStart.X.Offset + d.X, pStart.Y.Scale, pStart.Y.Offset + d.Y)
				end
			end)
			Core:Connect(UserInputService.InputEnded, function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
			end)
		end

		local minimized = false
		Core:Connect(btnMin.MouseButton1Click, function()
			minimized = not minimized
			body.Visible = not minimized
			main.Size = minimized and UDim2.fromOffset(300, 30) or UDim2.fromOffset(300, 430)
		end)
		Core:Connect(btnClose.MouseButton1Click, function() Core:Destroy() end)

		local order = 0
		local function nextOrder() order += 1 return order end

		function UI.Section(text)
			mk("TextLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = text, TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left }, body)
		end

		-- toggle row (synced with Core.Flags + saved)
		function UI.Toggle(text, key, onChange)
			local row = mk("TextButton", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C_PANEL, Text = "", AutoButtonColor = false }, body)
			corner(row, 6)
			mk("TextLabel", { Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = text, TextColor3 = C_TXT, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }, row)
			local track = mk("Frame", { Size = UDim2.fromOffset(36, 18), Position = UDim2.new(1, -46, 0.5, -9), BackgroundColor3 = C_BG, BorderSizePixel = 0 }, row)
			corner(track, 9)
			local knob = mk("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = C_SUB, BorderSizePixel = 0 }, track)
			corner(knob, 7)
			local function render()
				local on = Core.Flags[key] == true
				knob.Position = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)
				knob.BackgroundColor3 = on and C_ACC or C_SUB
			end
			render()
			Core:Connect(row.MouseButton1Click, function()
				Config.Set(key, not (Core.Flags[key] == true))
				render()
				if onChange then onChange(Core.Flags[key]) end
			end)
		end

		-- numeric input (supports K/M/B suffix)
		function UI.AmountInput(text, key)
			local row = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, body)
			corner(row, 6)
			mk("TextLabel", { Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = text, TextColor3 = C_TXT, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }, row)
			local box = mk("TextBox", { Size = UDim2.new(0.5, -14, 0, 22), Position = UDim2.new(0.5, 4, 0.5, -11), BackgroundColor3 = C_BG, Text = tostring(Core.Flags[key] or 0), PlaceholderText = "เช่น 500, 2.5K, 1M", TextColor3 = C_TXT, Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false }, row)
			corner(box, 4)
			Core:Connect(box.FocusLost, function()
				local n = Helpers.ParseAmount(box.Text)
				if n then
					Config.Set(key, n)
					logAction("CFG", "ราคาขั้นต่ำ = ¥" .. Helpers.Format(n), true)
				end
				box.Text = tostring(Core.Flags[key] or 0)
			end)
		end

		function UI.NumberInput(text, key, minVal)
			local floorMin = minVal or 1
			local row = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, body)
			corner(row, 6)
			mk("TextLabel", { Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = text, TextColor3 = C_TXT, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }, row)
			local box = mk("TextBox", { Size = UDim2.new(0.4, -14, 0, 22), Position = UDim2.new(0.6, 4, 0.5, -11), BackgroundColor3 = C_BG, Text = tostring(Core.Flags[key] or floorMin), PlaceholderText = "ตัวเลขชั้น", TextColor3 = C_TXT, Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false }, row)
			corner(box, 4)
			Core:Connect(box.FocusLost, function()
				local n = tonumber(box.Text)
				if n then
					n = math.max(floorMin, math.floor(n))
					Config.Set(key, n)
					logAction("CFG", text .. " = " .. tostring(n), true)
				end
				box.Text = tostring(Core.Flags[key] or floorMin)
			end)
		end

		function UI.DungeonSelect()
			local holder = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, body)
			corner(holder, 6)
			mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, holder)
			mk("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 26), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
			local dungeons = Helpers.GetDungeons()
			local btns = {}
			local function renderAll()
				local cur = tostring(Core.Flags.DungeonId or "ShrineGrounds")
				for _, entry in ipairs(btns) do
					local on = (entry.id == cur)
					entry.btn.Text = (on and "● " or "○ ") .. entry.name
					entry.btn.BackgroundColor3 = on and Color3.fromRGB(90, 55, 25) or C_BG
				end
			end
			for i, d in ipairs(dungeons) do
				local b = mk("TextButton", { LayoutOrder = i, BackgroundColor3 = C_BG, Text = d.name, AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C_TXT, TextTruncate = Enum.TextTruncate.AtEnd }, holder)
				corner(b, 4)
				table.insert(btns, { id = d.id, name = d.name, btn = b })
				Core:Connect(b.MouseButton1Click, function()
					Config.Set("DungeonId", d.id)
					logAction("CFG", "เลือกระดับดันเจียน: " .. d.name, true)
					renderAll()
				end)
			end
			renderAll()
		end

		-- dynamic multi-select (rebuilt when map/config tiers change)
		function UI.TierMultiSelect()
			local holder = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, body)
			corner(holder, 6)
			mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, holder)
			mk("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 26), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
			local cfg = Helpers.GetConfig()
			local function rebuild()
				for _, ch in ipairs(holder:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
				for i, tier in ipairs(Helpers.TierList) do
					local mul = ""
					if cfg and type(cfg.Mutations) == "table" and cfg.Mutations[tier] and cfg.Mutations[tier].PriceMultiplier then
						mul = " x" .. tostring(cfg.Mutations[tier].PriceMultiplier)
					end
					local b = mk("TextButton", { LayoutOrder = i, BackgroundColor3 = C_BG, Text = "", AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C_TXT }, holder)
					corner(b, 4)
					local function render()
						local on = Core.Flags.Tiers[tier] == true
						b.Text = (on and "☑ " or "☐ ") .. (tier == "Normal" and "ธรรมดา" or tier) .. mul
						b.BackgroundColor3 = on and Color3.fromRGB(90, 55, 25) or C_BG
					end
					render()
					b.MouseButton1Click:Connect(function()
						Core.Flags.Tiers[tier] = not (Core.Flags.Tiers[tier] == true)
						Config.Save()
						render()
					end)
				end
			end
			UI.RebuildTiers = rebuild
			rebuild()
		end

		function UI.StatusLabel()
			return mk("TextLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C_PANEL, Text = "", TextColor3 = C_SUB, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, body)
		end

		function UI.LogBox()
			local box = mk("ScrollingFrame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 130), BackgroundColor3 = C_PANEL, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
			corner(box, 6)
			local lbl = mk("TextLabel", { Size = UDim2.new(1, -8, 0, 0), Position = UDim2.fromOffset(4, 2), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "", RichText = true, TextColor3 = C_TXT, Font = Enum.Font.Code, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, box)
			Core._updateLogUI = function()
				local lines = {}
				for i = 1, math.min(#Stats.logs, 40) do
					local e = Stats.logs[i]
					local col = e.ok and "#7CFC8A" or "#FF7070"
					local msg = e.msg:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
					table.insert(lines, string.format('<font color="%s">[%s] %s</font> %s', col, e.time, e.cat, msg))
				end
				lbl.Text = table.concat(lines, "\n")
			end
		end
	end

	-- =================================================================
	-- 8. BOOT
	-- =================================================================
	Config.Load()
	if type(Core.Flags.Tiers) ~= "table" then Core.Flags.Tiers = { Normal = true } end
	Helpers.RefreshTiers()

	UI.Section("📦 Auto Buy Chest (สายพานฐานตัวเอง)")
	UI.Toggle("เปิด Auto ซื้อกล่อง", "AutoBuyChest", function(on)
		logAction("CFG", "Auto Buy Chest: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBuy() end
	end)
	UI.AmountInput("ราคาขั้นต่ำ (¥)", "MinPrice")
	UI.Section("ระดับกล่อง (เลือกได้หลายอัน)")
	UI.TierMultiSelect()
	UI.Toggle("วาร์ปไปสายพานเมื่ออยู่ไกล", "TeleportToBelt")
	UI.Toggle("วาร์ปกลับจุดเดิมหลังซื้อ", "ReturnAfterBuy")
	UI.Toggle("วางกล่องที่ฐานอัตโนมัติหลังซื้อ", "AutoPlaceChest")
	UI.Toggle("เปิดกล่องอัตโนมัติเมื่อพร้อม", "AutoOpenChest", function(on)
		logAction("CFG", "Auto Open Chest: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoOpen() end
	end)
	UI.Section("⚔️ Auto Battle")
	UI.Toggle("เล่นด่านซ้ำอัตโนมัติ (Auto Replay)", "AutoReplay", function(on)
		logAction("CFG", "Auto Replay: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoReplay() end
	end)
	UI.Toggle("เล่นด่านถัดไปอัตโนมัติ (Auto Next Stage)", "AutoNextStage", function(on)
		logAction("CFG", "Auto Next Stage: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoNextStage() end
	end)
	UI.Section("🏰 Auto Dungeon (ลงดันเจียนวนลูป)")
	UI.Toggle("เปิด Auto ลงดันเจียนวนลูป", "AutoDungeon", function(on)
		logAction("CFG", "Auto Dungeon: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoDungeon() end
	end)
	UI.NumberInput("ชั้นเริ่มต้น (Start Floor)", "DungeonStartFloor", 1)
	UI.NumberInput("จบชั้นที่ (ออกเมื่อพ้นชั้นนี้)", "DungeonEndFloor", 1)
	UI.DungeonSelect()
	UI.Section("🌟 Skill Tree")
	UI.Toggle("อัปเกรดทักษะอัตโนมัติ (เมื่อตังค์พร้อม)", "AutoUpgradeSkill", function(on)
		logAction("CFG", "Auto Upgrade Skill: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoUpgradeSkill() end
	end)
	local status = UI.StatusLabel()
	UI.Section("📜 Logs")
	UI.LogBox()

	-- real-time: tiers watcher (map ChildAdded + periodic config re-check)
	local function hookPlotsFolder()
		local lobby = Workspace:FindFirstChild("Lobby")
		local plots = lobby and lobby:FindFirstChild("Plots")
		if not plots then return end
		local function hookPlot(p)
			local ac = p:WaitForChild("ActiveChests", 10)
			if not (ac and Core._alive) then return end
			Core:Connect(ac.ChildAdded, function(c)
				if not c:IsA("Model") then return end
				task.defer(function()
					local t = Helpers.ChestTier(c)
					if not table.find(Helpers.TierList, t) and Helpers.RefreshTiers() and UI.RebuildTiers then
						UI.RebuildTiers()
						logAction("MAP", "พบระดับกล่องใหม่: " .. t, true)
					end
				end)
			end)
		end
		for _, p in ipairs(plots:GetChildren()) do task.spawn(hookPlot, p) end
		Core:Connect(plots.ChildAdded, function(p) task.spawn(hookPlot, p) end)
	end
	task.spawn(hookPlotsFolder)

	Core:Connect(LocalPlayer:GetAttributeChangedSignal("PlotId"), function() Helpers._plot = nil end)

	task.spawn(function()
		while Core._alive do
			if Helpers.RefreshTiers() and UI.RebuildTiers then UI.RebuildTiers() end
			local plot = Helpers.GetPlot()
			pcall(function()
				status.Text = string.format("  Plot: %s | เงิน: ¥%s | ขั้นต่ำ: ¥%s\n  ซื้อแล้ว: %d กล่อง | ใช้ไป: ¥%s",
					plot and plot.Name or "-", Helpers.Format(Helpers.GetCash()), Helpers.Format(tonumber(Core.Flags.MinPrice) or 0),
					Stats.bought, Helpers.Format(Stats.spent))
			end)
			task.wait(1)
		end
	end)

	Loops.StartAutoBuy()
	Loops.StartAutoOpen()
	Loops.StartAutoReplay()
	Loops.StartAutoNextStage()
	Loops.StartAutoDungeon()
	Loops.StartAutoUpgradeSkill()
	logAction("SYS", "โหลดสคริปต์สำเร็จ | Config: " .. Config.File, true)
end

local ok, err = pcall(main)
if not ok then warn("[KUYKUY HUB] Boot error: " .. tostring(err)) end
