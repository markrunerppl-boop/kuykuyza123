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
	local RunService = game:GetService("RunService")
	local Lighting = game:GetService("Lighting")
	local StatsService = game:GetService("Stats")

	local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
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
		if self._onDestroy then pcall(self._onDestroy) end
		for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
		for _, th in pairs(self._loops) do pcall(task.cancel, th) end
		table.clear(self._conns)
		table.clear(self._loops)
		if self._gui then pcall(function() self._gui:Destroy() end) end
	end

	-- =================================================================
	-- 2. STATS / LOGS (Circular Buffer)
	-- =================================================================
	local Stats = {
		logs = {},
		bought = 0,
		spent = 0,
		opened = 0,
		shopBought = 0,
		storyRuns = 0,
		dungeonRuns = 0,
		raidRuns = 0,
		bossRuns = 0,
		pvpRuns = 0,
		ascended = 0,
		soldUnits = 0,
		startedAt = os.time(),
		startCash = nil,
	}
	local function logAction(cat, msg, ok)
		local text = tostring(msg)
		if ok == true then
			if cat == "OPEN" then
				Stats.opened += 1
			elseif cat == "SHOP" and text:find("ซื้อ", 1, true) then
				Stats.shopBought += 1
			elseif cat == "STORY" and (text:find("เริ่มด่าน", 1, true) or text:find("เล่นซ้ำ", 1, true)) then
				Stats.storyRuns += 1
			elseif cat == "DUNGEON" and text:find("เริ่มลงดันเจียน", 1, true) then
				Stats.dungeonRuns += 1
			elseif cat == "RAID" and (text:find("กดเริ่ม", 1, true) or text:find("กด Play", 1, true) or text:find("READY", 1, true)) then
				Stats.raidRuns += 1
			elseif cat == "BOSS" and (text:find("กดเริ่ม", 1, true) or text:find("กด Play", 1, true) or text:find("READY", 1, true) or text:find("สู้บอสซ้ำ", 1, true)) then
				Stats.bossRuns += 1
			elseif cat == "PVP" and (text:find("เข้าคิว", 1, true) or text:find("เล่น PvP ซ้ำ", 1, true)) then
				Stats.pvpRuns += 1
			elseif cat == "ASCEND" then
				Stats.ascended += 1
			end
		end
		table.insert(Stats.logs, 1, { time = os.date("%H:%M:%S"), cat = cat, msg = text, ok = ok })
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
			AutoBuyFreeChest = true,
			MinPrice = 0,
			Tiers = { Normal = true },
			ChestRarities = {},
			TeleportToBelt = true,
			ReturnAfterBuy = true,
			AutoPlaceChest = true,
			AutoOpenChest = false,
			AutoReplay = false,
			AutoNextStage = false,
			AutoStory = false,
			StoryWorld = "World_1",
			StoryAct = 1,
			StoryDifficulty = "Easy",
			AutoUpgradeSkill = false,
			AutoDungeon = false,
			DungeonId = "ShrineGrounds",
			DungeonStartFloor = 1,
			DungeonEndFloor = 10,
			AutoTravelRaid = false,
			AutoRaid = false,
			RaidDifficulty = "Easy",
			RaidPartySize = 4,
			RaidFriendsOnly = false,
			RaidStartNow = true,
			AutoRaidReplay = true,
			AutoRaidReturn = false,
			RaidEndWave = 0,
			AutoBuyRaidShop = false,
			RaidShopTarget = "All",
			AutoTravelPvp = false,
			AutoPvp = false,
			AutoPvpReplay = true,
			AutoBuyPvpShop = false,
			AutoTravelBoss = false,
			AutoBoss = false,
			BossDifficulty = "Easy",
			BossPartySize = 4,
			BossFriendsOnly = false,
			BossStartNow = true,
			AutoBossReplay = true,
			AutoBossReturn = false,
			AutoBuyBossShop = false,
			BossShopTarget = "All",
			AutoBuyShop = false,
			ShopBuyAll = false,
			ShopFilterKind = "All",
			ShopMinRarity = "All",
			ShopTargets = {},
			AutoAscendUnit = false,
			AutoSellUnits = false,
			SellUnitMaxRarity = "Epic",
			AutoClaimBattlePass = false,
			AutoClaimWeekly = false,
			AntiAfk = true,
			FpsBoost = false,
			FpsBoost3DOff = true,
			FpsBoostCap = "0",
			UIWidth = 340,
			UIHeight = 450,
			UIExpanded = false,
			ActiveTab = "Chest",
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

	-- ReplicatedStorage.Events.AnimeIdle.<name> (cached, recursive fallback on map restructure)
	Net._cache = {}
	function Net.Remote(name: string)
		local c = Net._cache[name]
		if c and c.Parent then return c end
		local ev = ReplicatedStorage:FindFirstChild("Events")
		local ai = ev and ev:FindFirstChild("AnimeIdle")
		local r = ai and ai:FindFirstChild(name)
		if not r and ev then r = ev:FindFirstChild(name, true) end
		if not r then r = ReplicatedStorage:FindFirstChild(name, true) end
		Net._cache[name] = r
		return r
	end

	-- =================================================================
	-- 5. HELPERS
	-- =================================================================
	local Helpers = {
		_plot = nil,
		_mods = {},
		_modInsts = {},
		_chestTemplates = {},
		DungeonList = {},
		StoryWorlds = {},
		StoryActsByWorld = {},
		StoryDifficulties = {},
		_storySig = "",
		TierList = { "Normal" },
		ChestRarityList = {},
		RaidDifficulties = {},
		RaidShopItems = {},
		RaidQueueState = nil,
		BossDifficulties = {},
		BossShopItems = {},
		BossToday = nil,
		RarityOrder = {},
		AscensionPaths = {},
		Inventory = nil,
		PvpShopItems = {},
		PvpMeta = { hasQueue = false, hasShop = false, hasConfig = false },
		ShopOffers = {},
		ShopRotation = -1,
		ShopOptions = {},
		ShopKinds = { { id = "All", name = "ทั้งหมด (All)" } },
		_shopSig = "",
		SkillTree = {},
		_skillSynced = false,
	}

	function Helpers.RequireModule(key: string, ...: string)
		local inst = Helpers._modInsts[key]
		if inst and inst.Parent and Helpers._mods[key] ~= nil then
			return Helpers._mods[key]
		end
		Helpers._mods[key] = nil
		Helpers._modInsts[key] = nil
		local cur: Instance? = ReplicatedStorage
		for i = 1, select("#", ...) do
			if not cur then break end
			local part = select(i, ...)
			cur = cur:FindFirstChild(part) or cur:WaitForChild(part, 1.5)
		end
		if cur and cur:IsA("ModuleScript") then
			local ok, mod = pcall(require, cur)
			if ok and type(mod) == "table" then
				Helpers._modInsts[key] = cur
				Helpers._mods[key] = mod
				return mod
			end
		end
		return nil
	end

	function Helpers.InvalidateModules()
		table.clear(Helpers._mods)
		table.clear(Helpers._modInsts)
		table.clear(Helpers._chestTemplates)
	end

	function Helpers.RefreshDungeons(): boolean
		local list, seen = {}, {}
		local cfg = Helpers.RequireModule("DungeonConfig", "Modules", "Gameplay", "DungeonConfig")
		if cfg and type(cfg.Dungeons) == "table" then
			for _, d in ipairs(cfg.Dungeons) do
				if type(d) == "table" and d.Id then
					local id = tostring(d.Id)
					if not seen[id] then
						seen[id] = true
						table.insert(list, { id = id, name = tostring(d.Name or d.Id) })
					end
				end
			end
		end
		local arenas = Workspace:FindFirstChild("Arenas")
		if arenas then
			for _, a in ipairs(arenas:GetChildren()) do
				local da = a:GetAttribute("DungeonArena")
				if type(da) == "string" and da ~= "" and not seen[da] then
					seen[da] = true
					table.insert(list, { id = da, name = da })
				end
			end
		end
		if #list == 0 then
			list = { { id = "ShrineGrounds", name = "Shrine Grounds" } }
		end
		local changed = #list ~= #Helpers.DungeonList
		if not changed then
			for i, v in ipairs(list) do
				if not Helpers.DungeonList[i] or Helpers.DungeonList[i].id ~= v.id or Helpers.DungeonList[i].name ~= v.name then
					changed = true
					break
				end
			end
		end
		Helpers.DungeonList = list
		return changed
	end

	function Helpers.GetDungeons()
		if #Helpers.DungeonList == 0 then Helpers.RefreshDungeons() end
		return Helpers.DungeonList
	end

	function Helpers.GetStoryConfig()
		return Helpers.RequireModule("StoryConfig", "Modules", "Gameplay", "StoryConfig")
	end

	function Helpers.RefreshStory(): boolean
		local cfg = Helpers.GetStoryConfig()
		local worlds, seenW, actsByWorld = {}, {}, {}
		local sigParts = {}

		if cfg and type(cfg.Worlds) == "table" then
			for i, w in ipairs(cfg.Worlds) do
				if type(w) == "table" and w.Id then
					local id = tostring(w.Id)
					if not seenW[id] then
						seenW[id] = true
						local order = tonumber(w.Order) or i
						local wName = tostring(w.Name or id)
						local acts = {}
						if type(w.Levels) == "table" then
							for li, lv in ipairs(w.Levels) do
								local lvName = (type(lv) == "table" and lv.Name) and tostring(lv.Name) or ("Act " .. tostring(li))
								table.insert(acts, {
									id = tostring(li),
									num = li,
									name = string.format("Act %d: %s", li, lvName),
								})
								table.insert(sigParts, string.format("%s:%d:%s", id, li, lvName))
							end
						end
						if #acts == 0 then
							for li = 1, 8 do
								table.insert(acts, { id = tostring(li), num = li, name = "Act " .. tostring(li) })
							end
						end
						actsByWorld[id] = acts
						table.insert(worlds, {
							id = id,
							order = order,
							name = string.format("W%d: %s", order, wName),
						})
						table.insert(sigParts, string.format("W:%s:%d:%s", id, order, wName))
					end
				end
			end
		end

		local storyFolder = Workspace:FindFirstChild("Story_Mode")
		if storyFolder then
			local extra = {}
			for _, ch in ipairs(storyFolder:GetChildren()) do
				local wid = ch:GetAttribute("World")
				local id = (type(wid) == "string" and wid ~= "") and wid or (ch.Name:match("^World_%d+$") and ch.Name or nil)
				if id and not seenW[id] then
					seenW[id] = true
					local num = tonumber(id:match("(%d+)$")) or (#worlds + 1)
					table.insert(extra, { inst = ch, id = id, order = num })
				end
			end
			table.sort(extra, function(a, b) return a.order < b.order end)
			for _, item in ipairs(extra) do
				local acts, seenA = {}, {}
				for _, child in ipairs(item.inst:GetChildren()) do
					local lv = tonumber(child:GetAttribute("Level")) or tonumber(child.Name:match("^Level_(%d+)$"))
					if lv and not seenA[lv] then
						seenA[lv] = true
						local tag = (child:GetAttribute("Boss") == true or child.Name == "Boss_Pad") and " (Boss)" or ""
						table.insert(acts, { id = tostring(lv), num = lv, name = string.format("Act %d%s", lv, tag) })
					end
				end
				table.sort(acts, function(a, b) return a.num < b.num end)
				if #acts == 0 then
					for li = 1, 8 do
						table.insert(acts, { id = tostring(li), num = li, name = "Act " .. tostring(li) })
					end
				end
				actsByWorld[item.id] = acts
				table.insert(worlds, {
					id = item.id,
					order = item.order,
					name = string.format("W%d: %s", item.order, item.id),
				})
				table.insert(sigParts, string.format("WS:%s:%d:%d", item.id, item.order, #acts))
			end
		end

		if #worlds == 0 then
			for wi = 1, 7 do
				local id = "World_" .. tostring(wi)
				local acts = {}
				for li = 1, 8 do
					table.insert(acts, { id = tostring(li), num = li, name = "Act " .. tostring(li) })
				end
				actsByWorld[id] = acts
				table.insert(worlds, { id = id, order = wi, name = "World " .. tostring(wi) })
			end
		end

		local diffs, seenD = {}, {}
		if cfg and type(cfg.Difficulties) == "table" then
			for _, d in ipairs(cfg.Difficulties) do
				if type(d) == "table" and d.Id then
					local did = tostring(d.Id)
					if not seenD[did] then
						seenD[did] = true
						local dName = tostring(d.Name or did)
						table.insert(diffs, { id = did, name = dName })
						table.insert(sigParts, "D:" .. did .. ":" .. dName)
					end
				end
			end
		end
		if #diffs == 0 then
			diffs = {
				{ id = "Easy", name = "EASY" },
				{ id = "Hard", name = "HARD" },
				{ id = "Impossible", name = "IMPOSSIBLE" },
			}
		end

		local sig = table.concat(sigParts, "|")
		local changed = (sig ~= Helpers._storySig) or (#worlds ~= #Helpers.StoryWorlds) or (#diffs ~= #Helpers.StoryDifficulties)
		Helpers.StoryWorlds = worlds
		Helpers.StoryActsByWorld = actsByWorld
		Helpers.StoryDifficulties = diffs
		Helpers._storySig = sig
		return changed
	end

	function Helpers.GetStoryWorlds()
		if #Helpers.StoryWorlds == 0 then Helpers.RefreshStory() end
		return Helpers.StoryWorlds
	end

	function Helpers.GetStoryActs(worldId: string?)
		if #Helpers.StoryWorlds == 0 then Helpers.RefreshStory() end
		local wid = tostring(worldId or Core.Flags.StoryWorld or "World_1")
		local acts = Helpers.StoryActsByWorld[wid]
		if not acts or #acts == 0 then
			local first = Helpers.StoryWorlds[1]
			acts = first and Helpers.StoryActsByWorld[first.id] or { { id = "1", num = 1, name = "Act 1" } }
		end
		return acts
	end

	function Helpers.GetStoryDifficulties()
		if #Helpers.StoryDifficulties == 0 then Helpers.RefreshStory() end
		return Helpers.StoryDifficulties
	end

	function Helpers.ResolveStoryTarget(worldId: string, actNum: number, diffId: string)
		local storyCfg = Helpers.GetStoryConfig()
		local inv = Helpers.Inventory
		local cleared = (type(inv) == "table" and type(inv.story) == "table" and type(inv.story.cleared) == "table") and inv.story.cleared or nil
		if not (storyCfg and type(storyCfg.CanPlay) == "function" and cleared) then
			return { world = worldId, level = actNum, difficulty = diffId, autoUnlock = false }
		end

		local okPlay, canPlay, reason = pcall(storyCfg.CanPlay, cleared, worldId, actNum, diffId)
		if not okPlay or canPlay ~= false then
			return { world = worldId, level = actNum, difficulty = diffId, autoUnlock = false }
		end

		-- 1) Impossible locked -> clear this act on Hard first
		if diffId == "Impossible" then
			local okH, canHard = pcall(storyCfg.CanPlay, cleared, worldId, actNum, "Hard")
			if okH and canHard == true then
				return {
					world = worldId,
					level = actNum,
					difficulty = "Hard",
					autoUnlock = true,
					reason = string.format("ลง %s Act %d (Hard) เพื่อปลดล็อก Impossible", worldId, actNum),
				}
			end
		end

		-- 2) Act locked in unlocked world -> clear earliest uncleared act in this world on Easy
		local okWU, worldUnlocked = pcall(storyCfg.WorldUnlocked, cleared, worldId)
		if okWU and worldUnlocked == true then
			for k = 1, actNum do
				local okCl, isCl = pcall(storyCfg.IsCleared, cleared, worldId, k)
				if okCl and not isCl then
					local okE, canEasy = pcall(storyCfg.CanPlay, cleared, worldId, k, "Easy")
					if okE and canEasy == true then
						return {
							world = worldId,
							level = k,
							difficulty = "Easy",
							autoUnlock = true,
							reason = string.format("ปลดล็อก %s Act %d (Easy) ก่อน", worldId, k),
						}
					end
				end
			end
		end

		-- 3) World locked -> clear earliest uncleared act in highest unlocked prerequisite world
		if type(storyCfg.Worlds) == "table" then
			for _, w in ipairs(storyCfg.Worlds) do
				if type(w) == "table" and w.Id then
					local okU, u = pcall(storyCfg.WorldUnlocked, cleared, w.Id)
					if okU and u == true and type(w.Levels) == "table" then
						for k = 1, #w.Levels do
							local okCl, isCl = pcall(storyCfg.IsCleared, cleared, w.Id, k)
							if okCl and not isCl then
								local okE, canEasy = pcall(storyCfg.CanPlay, cleared, w.Id, k, "Easy")
								if okE and canEasy == true then
									return {
										world = tostring(w.Id),
										level = k,
										difficulty = "Easy",
										autoUnlock = true,
										reason = string.format("ปลดล็อก %s Act %d (Easy) เพื่อเปิด %s", tostring(w.Id), k, worldId),
									}
								end
							end
						end
					end
				end
			end
		end

		return { world = worldId, level = actNum, difficulty = diffId, autoUnlock = false, lockedReason = tostring(reason or "Locked") }
	end

	function Helpers.GetConfig()
		return Helpers.RequireModule("AnimeIdleConfig", "Modules", "Gameplay", "AnimeIdleConfig")
	end

	function Helpers.GetUpgradeDefs()
		return Helpers.RequireModule("UpgradeDefinitions", "Modules", "UI", "UpgradeTreeController", "UpgradeDefinitions")
	end

	function Helpers.GetRaidConfig()
		return Helpers.RequireModule("RaidConfig", "Modules", "Gameplay", "RaidConfig")
	end

	function Helpers.GetBossConfig()
		return Helpers.RequireModule("BossConfig", "Modules", "Gameplay", "BossConfig")
	end

	function Helpers.GetAscensionConfig()
		return Helpers.RequireModule("AscensionConfig", "Modules", "Gameplay", "AscensionConfig")
	end

	function Helpers.GetBattlePassConfig()
		return Helpers.RequireModule("BattlePassConfig", "Modules", "Gameplay", "BattlePassConfig")
	end

	function Helpers.IsBossPlace(): boolean
		local cfg = Helpers.GetBossConfig()
		local bossPlaceId = (cfg and (tonumber(cfg.PlaceId) or tonumber(cfg.BossPlaceId))) or 91808906335958
		if PlaceId == bossPlaceId then return true end
		local rCfg = Helpers.GetRaidConfig()
		local raidPlaceId = (rCfg and tonumber(rCfg.RaidPlaceId)) or 72834116419513
		if PlaceId == raidPlaceId then return false end
		return LocalPlayer:GetAttribute("BattleKind") == "Boss"
	end

	function Helpers.IsRaidPlace(): boolean
		local cfg = Helpers.GetRaidConfig()
		local raidPlaceId = (cfg and tonumber(cfg.RaidPlaceId)) or 72834116419513
		if PlaceId == raidPlaceId then return true end
		if Helpers.IsBossPlace() then return false end
		return LocalPlayer:GetAttribute("BattleKind") == "Raid"
	end

	function Helpers.GetProfileConfig()
		return Helpers.RequireModule("ProfileConfig", "Modules", "Gameplay", "ProfileConfig")
	end

	function Helpers.GetItemConfig()
		return Helpers.RequireModule("ItemConfig", "Modules", "Gameplay", "ItemConfig")
	end

	function Helpers.GetShopConfig()
		return Helpers.RequireModule("ShopConfig", "Modules", "Gameplay", "ShopConfig")
	end

	function Helpers.GetShopOfferName(offer): string
		if type(offer) ~= "table" then return "?" end
		local ref = tostring(offer.ref or offer.id or "?")
		if offer.kind == "Unit" then return ref end
		local itemCfg = Helpers.GetItemConfig()
		if itemCfg and type(itemCfg.Get) == "function" then
			local ok, def = pcall(itemCfg.Get, ref)
			if ok and type(def) == "table" and def.Name then
				return tostring(def.Name)
			end
		end
		return ref
	end

	function Helpers.GetShopRemaining(offer, rot: number?): number
		if type(offer) ~= "table" then return 0 end
		local stock = tonumber(offer.stock) or 0
		if stock <= 0 then return 0 end
		local inv = Helpers.Inventory
		local shopData = type(inv) == "table" and inv.shop or nil
		local curRot = rot or Helpers.ShopRotation
		local used = 0
		if type(shopData) == "table" and shopData.Rotation == curRot and type(shopData.Used) == "table" then
			used = tonumber(shopData.Used[offer.id]) or 0
		end
		return math.max(0, stock - used)
	end

	function Helpers.RefreshShop(): boolean
		local shopCfg = Helpers.GetShopConfig()
		local rot = -1
		local offers = {}
		if shopCfg and type(shopCfg.Rotation) == "function" and type(shopCfg.Offers) == "function" then
			local okT, now = pcall(function() return Workspace:GetServerTimeNow() end)
			local t = (okT and type(now) == "number") and now or os.time()
			local okR, r = pcall(shopCfg.Rotation, t)
			if okR and type(r) == "number" then
				rot = r
				local okO, list = pcall(shopCfg.Offers, rot)
				if okO and type(list) == "table" then
					offers = list
				end
			end
		end
		if #offers == 0 then
			local qRemote = Net.Remote("ShopQuery")
			if qRemote and qRemote:IsA("RemoteFunction") then
				local okQ, resQ = Net.Invoke(qRemote)
				if okQ and type(resQ) == "table" then
					if type(resQ.offers) == "table" then offers = resQ.offers
					elseif type(resQ.Offers) == "table" then offers = resQ.Offers
					elseif #resQ > 0 then offers = resQ end
					if type(resQ.rotation) == "number" then rot = resQ.rotation
					elseif type(resQ.Rotation) == "number" then rot = resQ.Rotation end
				end
			end
		end

		local kindLabels = { Unit = "ยูนิต (Unit)", Equip = "อุปกรณ์ (Equip)", Material = "ไอเทม (Material)" }
		local kinds, seenK = { { id = "All", name = "ทุกหมวด (All)" } }, { All = true }
		for _, baseK in ipairs({ "Unit", "Equip", "Material" }) do
			seenK[baseK] = true
			table.insert(kinds, { id = baseK, name = kindLabels[baseK] or baseK })
		end

		local opts, sigParts = {}, { tostring(rot) }
		for _, offer in ipairs(offers) do
			if type(offer) == "table" and offer.id then
				local kind = tostring(offer.kind or "Item")
				if not seenK[kind] then
					seenK[kind] = true
					table.insert(kinds, { id = kind, name = kindLabels[kind] or kind })
				end
				local ref = tostring(offer.ref or offer.id)
				local name = Helpers.GetShopOfferName(offer)
				local rem = Helpers.GetShopRemaining(offer, rot)
				local stock = tonumber(offer.stock) or 0
				local price = tonumber(offer.price) or 0
				local rarity = tostring(offer.rarity or "Common")
				table.insert(opts, {
					id = tostring(offer.id),
					ref = ref,
					name = name,
					kind = kind,
					rarity = rarity,
					price = price,
					stock = stock,
					remaining = rem,
					amount = tonumber(offer.amount) or 1,
					inRotation = true,
				})
				table.insert(sigParts, string.format("%s:%s:%s:%d:%d", tostring(offer.id), ref, rarity, price, rem))
			end
		end

		local sig = table.concat(sigParts, "|")
		local kindsChanged = (#kinds ~= #Helpers.ShopKinds)
		if not kindsChanged then
			for i, v in ipairs(kinds) do
				local cur = Helpers.ShopKinds[i]
				if not cur or cur.id ~= v.id or cur.name ~= v.name then
					kindsChanged = true
					break
				end
			end
		end
		local changed = (sig ~= Helpers._shopSig) or (rot ~= Helpers.ShopRotation) or kindsChanged
		Helpers.ShopOffers = offers
		Helpers.ShopRotation = rot
		Helpers.ShopOptions = opts
		Helpers.ShopKinds = kinds
		Helpers._shopSig = sig
		return changed
	end

	function Helpers.GetShopKindOptions()
		if #Helpers.ShopKinds <= 1 then Helpers.RefreshShop() end
		return Helpers.ShopKinds
	end

	function Helpers.GetShopRarityOptions()
		if #Helpers.RarityOrder == 0 then Helpers.RefreshRaritiesAndAscension() end
		local list, seen = { { id = "All", name = "ทุกระดับ (All)" } }, { All = true }
		for _, r in ipairs(Helpers.RarityOrder) do
			if not seen[r] then
				seen[r] = true
				table.insert(list, { id = r, name = r .. "+" })
			end
		end
		for _, offer in ipairs(Helpers.ShopOffers) do
			local r = type(offer) == "table" and offer.rarity
			if type(r) == "string" and r ~= "" and not seen[r] then
				seen[r] = true
				table.insert(list, { id = r, name = r .. "+" })
			end
		end
		return list
	end

	function Helpers.GetUnitSellRarityOptions()
		if #Helpers.RarityOrder == 0 then Helpers.RefreshRaritiesAndAscension() end
		local list, seen = {}, {}
		for _, r in ipairs(Helpers.RarityOrder) do
			if type(r) == "string" and r ~= "" and not seen[r] then
				seen[r] = true
				table.insert(list, { id = r, name = r .. " ลงมา" })
			end
		end
		if #list == 0 then
			for _, r in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }) do
				table.insert(list, { id = r, name = r .. " ลงมา" })
			end
		end
		return list
	end

	function Helpers.GetUnitRarity(unit): string
		if type(unit) ~= "table" then return "Common" end
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local unitsFolder = assets and assets:FindFirstChild("Units")
		local unitModel = unitsFolder and unit.name and unitsFolder:FindFirstChild(tostring(unit.name))
		local attrRarity = unitModel and unitModel:GetAttribute("Rarity")
		if type(attrRarity) == "string" and attrRarity ~= "" then
			return attrRarity
		end
		if type(unit.rarity) == "string" and unit.rarity ~= "" then
			return unit.rarity
		end
		return "Common"
	end

	function Helpers.GetPvpConfig()
		local mods = ReplicatedStorage:FindFirstChild("Modules")
		local gp = mods and mods:FindFirstChild("Gameplay")
		if gp then
			for _, m in ipairs(gp:GetChildren()) do
				if m:IsA("ModuleScript") then
					local lower = m.Name:lower()
					if lower:find("pvp", 1, true) then
						return Helpers.RequireModule(m.Name, "Modules", "Gameplay", m.Name)
					end
				end
			end
		end
		return nil
	end

	local function listEqual(a, b)
		if #a ~= #b then return false end
		for i, v in ipairs(a) do
			if not b[i] or b[i].id ~= v.id or b[i].name ~= v.name then return false end
		end
		return true
	end

	function Helpers.RefreshRaids(): boolean
		local cfg = Helpers.GetRaidConfig()
		local diffs, seenD = {}, {}
		if cfg and type(cfg.Difficulties) == "table" then
			for _, d in ipairs(cfg.Difficulties) do
				if type(d) == "table" and d.Id and not seenD[d.Id] then
					seenD[d.Id] = true
					table.insert(diffs, { id = tostring(d.Id), name = tostring(d.Name or d.Id), minWorld = tonumber(d.MinWorld) or 1 })
				end
			end
		end
		if #diffs == 0 then
			diffs = {
				{ id = "Easy", name = "EASY", minWorld = 2 },
				{ id = "Hard", name = "HARD", minWorld = 4 },
				{ id = "Impossible", name = "IMPOSSIBLE", minWorld = 6 },
			}
		end

		local shopOpts, seenS = { { id = "All", name = "ทั้งหมด (All)" } }, { All = true }
		if cfg and type(cfg.Merchant) == "table" then
			for _, item in ipairs(cfg.Merchant) do
				if type(item) == "table" and item.id and not seenS[item.id] then
					seenS[item.id] = true
					table.insert(shopOpts, {
						id = tostring(item.id),
						name = string.format("%s (%s)", tostring(item.ref or item.id), Helpers.Format(tonumber(item.price) or 0)),
						price = tonumber(item.price) or 0,
					})
				end
			end
		end

		local changed = not listEqual(diffs, Helpers.RaidDifficulties) or not listEqual(shopOpts, Helpers.RaidShopItems)
		Helpers.RaidDifficulties = diffs
		Helpers.RaidShopItems = shopOpts
		return changed
	end

	function Helpers.GetRaidDifficulties()
		if #Helpers.RaidDifficulties == 0 then Helpers.RefreshRaids() end
		return Helpers.RaidDifficulties
	end

	function Helpers.GetRaidShopOptions()
		if #Helpers.RaidShopItems == 0 then Helpers.RefreshRaids() end
		return Helpers.RaidShopItems
	end

	function Helpers.RefreshBoss(): boolean
		local cfg = Helpers.GetBossConfig()
		local diffs, seenD = {}, {}
		if cfg and type(cfg.Difficulties) == "table" then
			for _, d in ipairs(cfg.Difficulties) do
				if type(d) == "table" and d.Id and not seenD[d.Id] then
					seenD[d.Id] = true
					table.insert(diffs, {
						id = tostring(d.Id),
						name = string.format("%s (%s)", tostring(d.Name or d.Id), tostring(d.Expect or "")),
					})
				end
			end
		end
		if #diffs == 0 then
			diffs = {
				{ id = "Easy", name = "EASY (1M+ Power)" },
				{ id = "Hard", name = "HARD (3M+ Power)" },
				{ id = "Impossible", name = "IMPOSSIBLE (6M+ Power)" },
			}
		end

		local shopOpts, seenS = { { id = "All", name = "ทั้งหมด (All)" } }, { All = true }
		if cfg and type(cfg.Merchant) == "table" then
			for _, item in ipairs(cfg.Merchant) do
				if type(item) == "table" and item.id and not seenS[item.id] then
					seenS[item.id] = true
					table.insert(shopOpts, {
						id = tostring(item.id),
						name = string.format("%s (¥%s)", tostring(item.ref or item.id), Helpers.Format(tonumber(item.price) or 0)),
						price = tonumber(item.price) or 0,
					})
				end
			end
		end

		local todayName = nil
		if cfg and type(cfg.Today) == "function" then
			local okT, today = pcall(cfg.Today)
			if okT and type(today) == "table" then
				todayName = tostring(today.Name or today.Id or "")
			end
		end

		local changed = (Helpers.BossToday ~= todayName) or (not listEqual(diffs, Helpers.BossDifficulties)) or (not listEqual(shopOpts, Helpers.BossShopItems))
		Helpers.BossToday = todayName
		Helpers.BossDifficulties = diffs
		Helpers.BossShopItems = shopOpts
		return changed
	end

	function Helpers.GetBossDifficulties()
		if #Helpers.BossDifficulties == 0 then Helpers.RefreshBoss() end
		return Helpers.BossDifficulties
	end

	function Helpers.GetBossShopOptions()
		if #Helpers.BossShopItems == 0 then Helpers.RefreshBoss() end
		return Helpers.BossShopItems
	end

	function Helpers.RefreshRaritiesAndAscension(): boolean
		local rarities = {}
		local cfg = Helpers.GetConfig()
		if cfg and type(cfg.RarityOrder) == "table" then
			for _, r in ipairs(cfg.RarityOrder) do
				if type(r) == "string" then table.insert(rarities, r) end
			end
		end
		local paths = {}
		local asc = Helpers.GetAscensionConfig()
		if asc and type(asc.Paths) == "table" then
			for _, p in ipairs(asc.Paths) do
				if type(p) == "table" and p.From and p.To then
					table.insert(paths, { id = tostring(p.From), name = tostring(p.To) })
				end
			end
		end
		local changed = (#rarities ~= #Helpers.RarityOrder) or (not listEqual(paths, Helpers.AscensionPaths))
		if not changed then
			for i, v in ipairs(rarities) do
				if Helpers.RarityOrder[i] ~= v then changed = true; break end
			end
		end
		Helpers.RarityOrder = rarities
		Helpers.AscensionPaths = paths
		return changed
	end

	function Helpers.FindItemCount(inv, itemId: string): number
		if type(inv) ~= "table" or type(itemId) ~= "string" then return 0 end
		local total = 0
		for _, bucketName in ipairs({ "materials", "items" }) do
			local bucket = inv[bucketName]
			if type(bucket) == "table" then
				local direct = bucket[itemId]
				if type(direct) == "number" then
					total += direct
				elseif type(direct) == "table" then
					total += tonumber(direct.count or direct.amount or direct.qty) or 1
				end
				for k, entry in pairs(bucket) do
					if k ~= itemId and type(entry) == "table" then
						local eid = entry.id or entry.Id or entry.item or entry.name or entry.Name
						if tostring(eid) == itemId then
							total += tonumber(entry.count or entry.amount or entry.qty) or 1
						end
					end
				end
			end
		end
		return total
	end

	function Helpers.RefreshPvp(): boolean
		local items, seen = {}, {}
		local itemCfg = Helpers.GetItemConfig()
		if itemCfg and type(itemCfg.Items) == "table" then
			for _, it in ipairs(itemCfg.Items) do
				if type(it) == "table" and it.Source == "PvpShop" and it.Id and not seen[it.Id] then
					seen[it.Id] = true
					table.insert(items, { id = tostring(it.Id), name = tostring(it.Name or it.Id) })
				end
			end
		end
		local pvpCfg = Helpers.GetPvpConfig()
		local hasQueue = Net.Remote("PvpQueue") ~= nil or Net.Remote("PvpMatch") ~= nil or Net.Remote("PvpRequest") ~= nil
		local hasShop = Net.Remote("PvpShop") ~= nil or Net.Remote("PvpMerchant") ~= nil
		local hasConfig = pvpCfg ~= nil
		local metaChanged = (Helpers.PvpMeta.hasQueue ~= hasQueue) or (Helpers.PvpMeta.hasShop ~= hasShop) or (Helpers.PvpMeta.hasConfig ~= hasConfig)
		local changed = metaChanged or not listEqual(items, Helpers.PvpShopItems)
		Helpers.PvpShopItems = items
		Helpers.PvpMeta = { hasQueue = hasQueue, hasShop = hasShop, hasConfig = hasConfig }
		return changed
	end

	function Helpers.TriggerAreaPrompt(areaName: string, promptName: string?): boolean
		if not Helpers.IsAlive() then return false end
		local root = Helpers.GetRoot()
		local lobby = Workspace:FindFirstChild("Lobby")
		local areas = lobby and lobby:FindFirstChild("Areas")
		local area = areas and areas:FindFirstChild(areaName)
		if not (root and area) then return false end
		local prompt = promptName and area:FindFirstChild(promptName, true) or area:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not (prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled) then return false end
		local targetPos = (prompt.Parent and prompt.Parent:IsA("BasePart")) and prompt.Parent.Position or area:GetPivot().Position
		if (root.Position - targetPos).Magnitude > (prompt.MaxActivationDistance or 12) - 2 then
			root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
			task.wait(0.15)
		end
		if fireproximityprompt then
			local ok = pcall(fireproximityprompt, prompt)
			return ok
		end
		return false
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
		local attr = tonumber(chest:GetAttribute("Price"))
		if attr ~= nil then return attr end
		local cfg = Helpers.GetConfig()
		local tier = tonumber(chest:GetAttribute("Tier"))
		if cfg and tier and type(cfg.ChestPrice) == "function" then
			local mut = chest:GetAttribute("Mutation")
			local ok, p = pcall(cfg.ChestPrice, tier, (type(mut) == "string" and mut ~= "") and mut or nil)
			if ok and tonumber(p) then return tonumber(p) end
		end
		return 0
	end

	-- BeltAnchor (Part + BUY prompt) pairs with chest model by XZ position
	-- Note: for mutated chests (Silver/Gold/Diamond/...), the game sets prompt's Rarity attribute to the Mutation name
	function Helpers.FindAnchor(folder, chest)
		local pivot = chest:GetPivot().Position
		local rarity = chest:GetAttribute("Rarity")
		local mutation = chest:GetAttribute("Mutation")
		local hasMut = type(mutation) == "string" and mutation ~= ""
		local best, bestD = nil, 6
		for _, a in ipairs(folder:GetChildren()) do
			if a:IsA("BasePart") then
				local pr = a:FindFirstChildOfClass("ProximityPrompt")
				if pr and pr.Enabled then
					local prTag = pr:GetAttribute("Rarity")
					local tagOk = (prTag == nil)
						or (hasMut and prTag == mutation)
						or (rarity ~= nil and prTag == rarity)
						or (rarity == nil and not hasMut)
					if tagOk then
						local d = Vector3.new(a.Position.X - pivot.X, 0, a.Position.Z - pivot.Z).Magnitude
						if d < bestD then best, bestD = pr, d end
					end
				end
			end
		end
		return best
	end

	-- dynamic tier list (Normal + AnimeIdleConfig.MutationOrder + any Mutation seen on map/assets)
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
				for _, folderName in ipairs({ "ActiveChests", "PlacedChests" }) do
					local ac = p:FindFirstChild(folderName)
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
		end
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local chests = assets and assets:FindFirstChild("Chests")
		if chests then
			for _, c in ipairs(chests:GetChildren()) do
				local t = Helpers.ChestTier(c)
				if not seen[t] then seen[t] = true; table.insert(list, t) end
			end
		end
		local changed = #list ~= #Helpers.TierList
		if not changed then
			for i, v in ipairs(list) do if Helpers.TierList[i] ~= v then changed = true break end end
		end
		Helpers.TierList = list
		return changed
	end

	-- chest rarity key (Common/Uncommon/Rare/.../Bloodmoon/future rarities)
	function Helpers.ChestRarity(chest): string?
		if not chest then return nil end
		local r = chest:GetAttribute("Rarity") or chest:GetAttribute("ChestRarity")
		if type(r) == "string" and r ~= "" then return r end
		local tierNum = tonumber(chest:GetAttribute("Tier"))
		if tierNum then
			local cfg = Helpers.GetConfig()
			if cfg then
				if type(cfg.Chests) == "table" then
					local entry = cfg.Chests[tierNum]
					if type(entry) == "table" then
						local cr = entry.Rarity or entry.rarity or entry.Name
						if type(cr) == "string" and cr ~= "" then
							return (cr:gsub("%s*[Cc]hest$", ""))
						end
					end
				end
				if type(cfg.RarityOrder) == "table" and type(cfg.RarityOrder[tierNum]) == "string" and cfg.RarityOrder[tierNum] ~= "" then
					return cfg.RarityOrder[tierNum]
				end
			end
		end
		local cname = chest:GetAttribute("ChestName")
		if type(cname) == "string" and cname ~= "" then
			local stripped = cname:gsub("%s*[Cc]hest$", "")
			if stripped ~= "" then return stripped end
		end
		return nil
	end

	-- dynamic chest rarity list (AnimeIdleConfig + Assets.Chests + live map ActiveChests/PlacedChests Models)
	function Helpers.RefreshChestRarities(): boolean
		local list, seen = {}, {}
		local mutationSet = {}
		local cfg = Helpers.GetConfig()
		if cfg then
			if type(cfg.MutationOrder) == "table" then
				for _, m in ipairs(cfg.MutationOrder) do
					if type(m) == "string" and m ~= "" then mutationSet[m] = true end
				end
			end
			if type(cfg.Mutations) == "table" then
				for m in pairs(cfg.Mutations) do
					if type(m) == "string" and m ~= "" then mutationSet[m] = true end
				end
			end
		end
		for _, t in ipairs(Helpers.TierList) do
			if type(t) == "string" and t ~= "" and t ~= "Normal" then
				mutationSet[t] = true
			end
		end
		if type(Core.Flags.ChestRarities) == "table" then
			for m in pairs(mutationSet) do
				if Core.Flags.ChestRarities[m] ~= nil then
					Core.Flags.ChestRarities[m] = nil
				end
			end
		end

		local function addRarity(val)
			if type(val) ~= "string" then return end
			local clean = val:match("^%s*(.-)%s*$")
			if clean == "" then return end
			clean = clean:gsub("%s*[Cc]hest$", "")
			if clean ~= "" and not mutationSet[clean] and not seen[clean] then
				seen[clean] = true
				table.insert(list, clean)
			end
		end

		if cfg then
			if type(cfg.RarityOrder) == "table" then
				for _, r in ipairs(cfg.RarityOrder) do addRarity(r) end
			end
			if type(cfg.Chests) == "table" then
				for _, c in ipairs(cfg.Chests) do
					if type(c) == "table" then addRarity(c.Rarity or c.rarity or c.Name) end
				end
				for _, c in pairs(cfg.Chests) do
					if type(c) == "table" then addRarity(c.Rarity or c.rarity or c.Name) end
				end
			end
		end

		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local chests = assets and assets:FindFirstChild("Chests")
		if chests then
			local templates = {}
			for _, c in ipairs(chests:GetChildren()) do
				table.insert(templates, { inst = c, tier = tonumber(c:GetAttribute("Tier")) or math.huge })
			end
			table.sort(templates, function(a, b) return a.tier < b.tier end)
			for _, item in ipairs(templates) do
				addRarity(Helpers.ChestRarity(item.inst))
			end
		end

		local lobby = Workspace:FindFirstChild("Lobby")
		local plots = lobby and lobby:FindFirstChild("Plots")
		if plots then
			for _, p in ipairs(plots:GetChildren()) do
				for _, folderName in ipairs({ "ActiveChests", "PlacedChests" }) do
					local ac = p:FindFirstChild(folderName)
					if ac then
						for _, c in ipairs(ac:GetChildren()) do
							if c:IsA("Model") then
								addRarity(Helpers.ChestRarity(c))
							end
						end
					end
				end
			end
		end

		local changed = #list ~= #Helpers.ChestRarityList
		if not changed then
			for i, v in ipairs(list) do
				if Helpers.ChestRarityList[i] ~= v then changed = true; break end
			end
		end
		Helpers.ChestRarityList = list
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

	function Helpers.GetChestTemplate(tier: number)
		local cached = Helpers._chestTemplates[tier]
		if cached and cached.Parent then return cached end
		table.clear(Helpers._chestTemplates)
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local chests = assets and assets:FindFirstChild("Chests")
		if chests then
			for _, c in ipairs(chests:GetChildren()) do
				local t = c:GetAttribute("Tier")
				if type(t) == "number" then Helpers._chestTemplates[t] = c end
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
	local Loops = { attempts = setmetatable({}, { __mode = "k" }), backoffUntil = 0, lastBuyAt = 0, lastReplayAt = 0, lastNextAt = 0, lastStoryAt = 0, lastStoryWarnAt = 0, _lastStory = nil, lastDungeonAt = 0, lastRaidAt = 0, lastRaidQuitAt = 0, raidBattleStartedAt = 0, raidTargetWaveAt = 0, raidWaveArmed = false, raidQuitTriggered = false, lastRaidShopAt = 0, raidSetupBusy = false, raidQueueState = nil, raidQueueStateAt = 0, raidStartSentAt = 0, raidEndScreenAt = 0, raidRevealAt = 0, raidReplayMine = false, raidReplayState = nil, raidReplaySentAt = 0, raidReplayTries = 0, lastBossAt = 0, lastBossShopAt = 0, bossSetupBusy = false, bossQueueState = nil, bossQueueStateAt = 0, bossStartSentAt = 0, bossEndScreenAt = 0, bossRevealAt = 0, bossReplayMine = false, bossReplayState = nil, bossReplaySentAt = 0, bossReplayTries = 0, lastAscendAt = 0, lastSellAt = 0, lastBpAt = 0, lastBpResetAt = 0, bpBusy = false, lastWeeklyAt = 0, lastPvpAt = 0, lastPvpShopAt = 0, lastShopAt = 0, lastTravelAt = 0 }

	function Loops.SelectTargets()
		local plot = Helpers.GetPlot()
		local folder = plot and plot:FindFirstChild("ActiveChests")
		if not folder then return nil, nil end
		local minPrice = tonumber(Core.Flags.MinPrice) or 0
		local tiers = Core.Flags.Tiers or {}
		local rarities = type(Core.Flags.ChestRarities) == "table" and Core.Flags.ChestRarities or {}
		local hasRarityFilter = false
		for _, v in pairs(rarities) do
			if v == true then hasRarityFilter = true; break end
		end
		local cash = Helpers.GetCash()
		local buyFree = Core.Flags.AutoBuyFreeChest == true
		local list = {}
		for _, chest in ipairs(folder:GetChildren()) do
			if chest:IsA("Model") and (Loops.attempts[chest] or 0) < 3 then
				local price = Helpers.ChestPrice(chest)
				local tier = Helpers.ChestTier(chest)
				local rarity = Helpers.ChestRarity(chest)
				local isFree = price == 0 and buyFree
				local rarityOk = (not hasRarityFilter) or (rarity ~= nil and rarities[rarity] == true)
				if isFree or (tiers[tier] == true and rarityOk and price >= minPrice and price <= cash) then
					table.insert(list, { chest = chest, price = price, tier = tier, rarity = rarity })
				end
			end
		end
		table.sort(list, function(a, b)
			if (a.price == 0) ~= (b.price == 0) then return a.price == 0 end
			return a.price > b.price
		end)
		return list, folder
	end

	function Loops.BuyChest(entry, folder): boolean
		local chest = entry.chest
		local price = tonumber(entry.price) or 0
		if price > 0 and Helpers.GetCash() < price then return false end

		local inv = Helpers.Inventory
		if type(inv) ~= "table" then
			local now = os.clock()
			if now - (Loops._lastInvReq or 0) >= 2 then
				Loops._lastInvReq = now
				local req = Net.Remote("RequestInventory")
				if req and req:IsA("RemoteEvent") then pcall(function() req:FireServer() end) end
			end
			return false
		end

		local chestLimit = tonumber(inv.chestLimit)
		local chestCount = tonumber(inv.chestCount)
		if chestLimit and chestCount and chestCount >= chestLimit then return false end

		local tierNum = tonumber(chest:GetAttribute("Tier"))
		local plot = Helpers.GetPlot()
		if plot then
			if chestLimit then
				local placedFolder = plot:FindFirstChild("PlacedChests")
				if placedFolder then
					local placedCount = 0
					for _, ch in ipairs(placedFolder:GetChildren()) do
						if ch:IsA("Model") and not ch:GetAttribute("Opening") then
							placedCount += 1
						end
					end
					if placedCount >= chestLimit then return false end
				end
			end
			if tierNum then
				local lx, lz = Helpers.FindFreeSpot(plot, tierNum)
				if not (lx and lz) then return false end
			end
		end

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
		local mutAttr = chest:GetAttribute("Mutation")
		local mutArg = (type(mutAttr) == "string" and mutAttr ~= "") and mutAttr or nil
		local priceLabel = entry.price == 0 and "FREE" or ("¥" .. Helpers.Format(entry.price))
		local label = string.format("%s %s (%s)", entry.tier ~= "Normal" and entry.tier or "", tostring(chest:GetAttribute("ChestName") or chest.Name), priceLabel)

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
			if type(Helpers.Inventory) == "table" and tonumber(Helpers.Inventory.chestCount) then
				Helpers.Inventory.chestCount = tonumber(Helpers.Inventory.chestCount) + 1
			end
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
		if Helpers.IsRaidPlace() or Helpers.IsBossPlace() then return false end
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
		if Core.Busy or Helpers.IsRaidPlace() or Helpers.IsBossPlace() then return end
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
		local bk = LocalPlayer:GetAttribute("BattleKind")
		if (Core.Flags.AutoStory and bk == "Story") or (Core.Flags.AutoDungeon and bk == "Dungeon") or ((Core.Flags.AutoRaid or Core.Flags.AutoRaidReplay or Core.Flags.AutoRaidReturn) and (bk == "Raid" or Helpers.IsRaidPlace())) or ((Core.Flags.AutoBoss or Core.Flags.AutoBossReplay or Core.Flags.AutoBossReturn) and (bk == "Boss" or Helpers.IsBossPlace())) or ((Core.Flags.AutoPvp or Core.Flags.AutoPvpReplay) and (bk == "Pvp" or LocalPlayer:GetAttribute("PvpSide") ~= nil)) then return end
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
		local bk = LocalPlayer:GetAttribute("BattleKind")
		if (Core.Flags.AutoDungeon and bk == "Dungeon") or ((Core.Flags.AutoRaid or Core.Flags.AutoRaidReplay or Core.Flags.AutoRaidReturn) and (bk == "Raid" or Helpers.IsRaidPlace())) or ((Core.Flags.AutoBoss or Core.Flags.AutoBossReplay or Core.Flags.AutoBossReturn) and (bk == "Boss" or Helpers.IsBossPlace())) or ((Core.Flags.AutoPvp or Core.Flags.AutoPvpReplay) and (bk == "Pvp" or LocalPlayer:GetAttribute("PvpSide") ~= nil)) then return end
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

	function Loops.AutoStoryTick()
		if os.clock() - Loops.lastStoryAt < 2 then return end
		if Helpers.IsRaidPlace() or Helpers.IsBossPlace() then return end
		local battleReq = Net.Remote("BattleRequest")
		if not battleReq then return end

		if Helpers.Inventory == nil then
			local reqInv = Net.Remote("RequestInventory")
			if reqInv and reqInv:IsA("RemoteEvent") then
				pcall(function() reqInv:FireServer() end)
			end
		end

		local worldId = tostring(Core.Flags.StoryWorld or "World_1")
		local acts = Helpers.GetStoryActs(worldId)
		local actNum = math.max(1, math.floor(tonumber(Core.Flags.StoryAct) or 1))
		if #acts > 0 and actNum > #acts then
			actNum = #acts
		end
		local diffId = tostring(Core.Flags.StoryDifficulty or "Easy")

		local target = Helpers.ResolveStoryTarget(worldId, actNum, diffId)

		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local endScreen = results and results:FindFirstChild("EndScreen")
		if endScreen and endScreen:IsA("GuiObject") and endScreen.Visible then
			if Core.Flags.AutoNextStage then
				local left = endScreen:FindFirstChild("Left")
				local buttons = left and left:FindFirstChild("Buttons")
				local nextBtn = buttons and buttons:FindFirstChild("Next")
				if nextBtn and nextBtn:IsA("GuiObject") and nextBtn.Visible then return end
			end
			Loops.lastStoryAt = os.clock()
			local sameStage = LocalPlayer:GetAttribute("BattleKind") == "Story"
				and type(Loops._lastStory) == "table"
				and not Loops._lastStory.autoUnlock
				and not target.autoUnlock
				and Loops._lastStory.world == target.world
				and Loops._lastStory.level == target.level
				and Loops._lastStory.difficulty == target.difficulty
			if sameStage then
				local ok, res, err = Net.Invoke(battleReq, "Replay")
				if ok and res ~= false then
					logAction("STORY", string.format("เล่นซ้ำ %s Act %d (%s)", target.world, target.level, target.difficulty), true)
					Loops.GoHome("STORY")
				else
					logAction("STORY", "เล่นซ้ำด่านเนื้อเรื่องไม่สำเร็จ: " .. tostring(err or res), false)
				end
			else
				local ok, res, err = Net.Invoke(battleReq, "Quit")
				if ok and res ~= false then
					logAction("STORY", "ออกจากหน้าสรุปผลเพื่อเข้าด่านเป้าหมายถัดไป", true)
				else
					logAction("STORY", "ออกจากหน้าสรุปผลไม่สำเร็จ: " .. tostring(err or res), false)
				end
			end
			return
		end

		if LocalPlayer:GetAttribute("InBattle") == true then return end

		if target.lockedReason then
			if os.clock() - Loops.lastStoryWarnAt >= 10 then
				Loops.lastStoryWarnAt = os.clock()
				logAction("STORY", string.format("ยังไม่ปลดล็อก %s Act %d (%s): %s", worldId, actNum, diffId, target.lockedReason), false)
			end
			return
		end

		Loops.lastStoryAt = os.clock()
		local payload = { world = target.world, level = target.level, difficulty = target.difficulty }
		local ok, res, err = Net.Invoke(battleReq, "StartStory", payload)
		if (not ok or res == false) and target.difficulty == "Impossible" and tostring(err or res):lower():find("hard", 1, true) then
			payload.difficulty = "Hard"
			target.autoUnlock = true
			target.reason = string.format("ลง %s Act %d (Hard) เพื่อปลดล็อก Impossible", target.world, target.level)
			ok, res, err = Net.Invoke(battleReq, "StartStory", payload)
		end

		if ok and res ~= false then
			Loops._lastStory = { world = payload.world, level = payload.level, difficulty = payload.difficulty, autoUnlock = target.autoUnlock }
			if target.autoUnlock and target.reason then
				logAction("STORY", target.reason, true)
			else
				logAction("STORY", string.format("เริ่มด่าน %s Act %d (%s)", payload.world, payload.level, payload.difficulty), true)
			end
			Loops.GoHome("STORY")
		else
			logAction("STORY", string.format("เข้าด่าน %s Act %d (%s) ไม่สำเร็จ: %s", payload.world, payload.level, payload.difficulty, tostring(err or res)), false)
		end
	end

	function Loops.StartAutoStory()
		if Core.Flags.AutoStory then
			Core:Loop("AutoStory", "AutoStory", 0.8, Loops.AutoStoryTick)
		end
	end

	function Loops.AutoDungeonTick()
		if os.clock() - Loops.lastDungeonAt < 2 then return end
		if Helpers.IsRaidPlace() or Helpers.IsBossPlace() then return end
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

	function Loops.AutoTravelRaidTick()
		if os.clock() - Loops.lastTravelAt < 5 then return end
		local cfg = Helpers.GetRaidConfig()
		local raidPlaceId = (cfg and tonumber(cfg.RaidPlaceId)) or 72834116419513
		if PlaceId == raidPlaceId then return end
		if LocalPlayer:GetAttribute("RaidLocked") == true or LocalPlayer:GetAttribute("InBattle") == true then return end
		Loops.lastTravelAt = os.clock()
		if Helpers.TriggerAreaPrompt("Raids", "RaidTravelPrompt") then
			logAction("RAID", "วาร์ปเข้าโซน Raid อัตโนมัติ", true)
		end
	end

	function Loops.StartAutoTravelRaid()
		if Core.Flags.AutoTravelRaid then
			Core:Loop("AutoTravelRaid", "AutoTravelRaid", 1.5, Loops.AutoTravelRaidTick)
		end
	end

	function Loops.ApplyRaidSetup(state)
		if Loops.raidSetupBusy then return end
		local raidQueue = Net.Remote("RaidQueue")
		if not (raidQueue and raidQueue:IsA("RemoteEvent") and type(state) == "table" and state.leader) then return end
		if LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("InBattle") == true then return end
		Loops.raidSetupBusy = true
		local function stillBuilding()
			if not (Core._alive and Core.Flags.AutoRaid and Helpers.IsRaidPlace()) then return false end
			if LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("InBattle") == true then return false end
			local cur = Helpers.RaidQueueState
			return type(cur) == "table" and cur.leader and cur.state == "building"
		end
		pcall(function()
			local diff = tostring(Core.Flags.RaidDifficulty or "Easy")
			local size = math.clamp(math.floor(tonumber(Core.Flags.RaidPartySize) or 4), 1, 4)
			local friends = Core.Flags.RaidFriendsOnly == true
			task.wait(0.1)
			if not stillBuilding() then return end
			local cur = Helpers.RaidQueueState or state
			if cur.difficulty ~= diff then
				pcall(function() raidQueue:FireServer("Difficulty", diff) end)
				task.wait(0.1)
				if not stillBuilding() then return end
			end
			cur = Helpers.RaidQueueState or cur
			if tonumber(cur.size) ~= size then
				pcall(function() raidQueue:FireServer("Size", size) end)
				task.wait(0.1)
				if not stillBuilding() then return end
			end
			cur = Helpers.RaidQueueState or cur
			if (cur.friendsOnly == true) ~= friends then
				pcall(function() raidQueue:FireServer("Friends") end)
				task.wait(0.1)
				if not stillBuilding() then return end
			end
			task.wait(0.1)
			if not stillBuilding() then return end
			Loops.lastRaidAt = os.clock()
			pcall(function() raidQueue:FireServer("Play") end)
			logAction("RAID", string.format("ตั้งค่าคิว Raid (%s | %d คน) และกด Play", diff, size), true)
		end)
		Loops.raidSetupBusy = false
	end

	function Loops.ResetRaidReplayState()
		Loops.raidEndScreenAt = 0
		Loops.raidRevealAt = 0
		Loops.raidReplayMine = false
		Loops.raidReplayState = nil
		Loops.raidReplaySentAt = 0
		Loops.raidReplayTries = 0
	end

	function Loops.FindEmptyRaidPad(queues: Instance, myPos: Vector3?)
		local bestFree, bestFreeScore = nil, -math.huge
		local bestFallback, bestFallbackDist = nil, -1
		local otherPositions = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local ch = plr.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					table.insert(otherPositions, hrp.Position)
				end
			end
		end
		for _, pad in ipairs(queues:GetChildren()) do
			local blocked = pad:GetAttribute("Blocked") == true
			local leaderId = tonumber(pad:GetAttribute("LeaderId")) or 0
			local isOtherLeader = leaderId ~= 0 and leaderId ~= LocalPlayer.UserId
			local count = tonumber(pad:GetAttribute("Count") or pad:GetAttribute("Players") or pad:GetAttribute("Members")) or 0
			local stateAttr = tostring(pad:GetAttribute("State") or ""):lower()
			local busyState = stateAttr ~= "" and stateAttr ~= "idle" and stateAttr ~= "open" and stateAttr ~= "empty"
			if not blocked and not isOtherLeader and (count == 0 or leaderId == LocalPlayer.UserId) and (not busyState or leaderId == LocalPlayer.UserId) then
				local hitbox = pad:FindFirstChild("Hitbox") or pad:FindFirstChildWhichIsA("BasePart")
				if hitbox and hitbox:IsA("BasePart") then
					local uiOccupied = false
					if leaderId ~= LocalPlayer.UserId then
						for _, d in ipairs(pad:GetDescendants()) do
							if d:IsA("TextLabel") then
								local n = tonumber(tostring(d.Text or ""):match("^(%d+)%s*/%s*%d+"))
								if n and n > 0 then
									uiOccupied = true
									break
								end
							end
						end
					end
					if not uiOccupied then
						local pos = hitbox.Position
						local minOtherDist = math.huge
						for _, opos in ipairs(otherPositions) do
							local d = (opos - pos).Magnitude
							if d < minOtherDist then minOtherDist = d end
						end
						local radius = math.max(hitbox.Size.X, hitbox.Size.Z) * 0.65 + 10
						if minOtherDist > radius then
							local myDist = myPos and (myPos - pos).Magnitude or 0
							local score = -myDist
							if score > bestFreeScore then
								bestFreeScore = score
								bestFree = { pad = pad, hitbox = hitbox }
							end
						elseif minOtherDist > bestFallbackDist then
							bestFallbackDist = minOtherDist
							bestFallback = { pad = pad, hitbox = hitbox }
						end
					end
				end
			end
		end
		return bestFree or bestFallback
	end

	function Loops.TryRaidEndWave(): boolean
		if not Helpers.IsRaidPlace() then return false end
		local endWave = math.floor(tonumber(Core.Flags.RaidEndWave) or 0)
		if endWave <= 0 then return false end
		if LocalPlayer:GetAttribute("InBattle") ~= true then
			Loops.raidBattleStartedAt = 0
			Loops.raidTargetWaveAt = 0
			Loops.raidWaveArmed = false
			Loops.raidQuitTriggered = false
			return false
		end
		if LocalPlayer:GetAttribute("BattleKind") ~= "Raid" and LocalPlayer:GetAttribute("InRaid") ~= true then return false end
		local now = os.clock()
		if Loops.raidBattleStartedAt == 0 then
			Loops.raidBattleStartedAt = now
			Loops.raidTargetWaveAt = 0
			Loops.raidWaveArmed = false
			Loops.raidQuitTriggered = false
		end
		local floor = tonumber(LocalPlayer:GetAttribute("BattleFloor")) or 0
		-- กัน BattleFloor ค้างจากรอบก่อน: ต้องเห็นเวฟรีเซ็ตต่ำกว่า endWave ก่อนจึงจะอนุญาตให้ออก
		if endWave > 1 then
			if floor > 0 and floor < endWave then
				Loops.raidWaveArmed = true
			end
			if not Loops.raidWaveArmed then return false end
		else
			if floor == 1 and (now - Loops.raidBattleStartedAt >= 2.0) then
				Loops.raidWaveArmed = true
			end
			if not Loops.raidWaveArmed then return false end
		end
		if floor < endWave then
			Loops.raidTargetWaveAt = 0
			return false
		end
		if now - Loops.raidBattleStartedAt < 1.2 then return false end
		-- รอ 0.45s ให้ packet เริ่มเวฟมาถึง client เสร็จก่อนกด Quit ป้องกัน UI WAVE/QUIT เด้งค้างทับ Lobby
		if Loops.raidTargetWaveAt == 0 then
			Loops.raidTargetWaveAt = now
			return true
		end
		if now - Loops.raidTargetWaveAt < 0.45 then return true end
		if Loops.raidQuitTriggered and (now - (Loops.lastRaidQuitAt or 0) < 2.5) then return true end
		if now - (Loops.lastRaidQuitAt or 0) < 1.5 then return true end

		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local battleGui = pg and pg:FindFirstChild("Battle")
		local playFrame = battleGui and battleGui:FindFirstChild("Play")
		if playFrame and playFrame:IsA("GuiObject") and not playFrame.Visible then return false end

		Loops.lastRaidQuitAt = now
		Loops.raidQuitTriggered = true
		local buttons = playFrame and playFrame:FindFirstChild("Buttons")
		local quitBtn = buttons and buttons:FindFirstChild("Quit")
		local usedUi = false
		if quitBtn and quitBtn:IsA("GuiButton") and firesignal then
			usedUi = pcall(firesignal, quitBtn.Activated)
			logAction("RAID", string.format("ถึงเวฟ %d -> ออกเข้าใหม่ (Quit UI)", floor), true)
		end
		if not usedUi then
			local battleReq = Net.Remote("BattleRequest")
			if battleReq then
				local ok, res = Net.Invoke(battleReq, "Quit")
				if ok and res ~= false then
					logAction("RAID", string.format("ถึงเวฟ %d -> ออกเข้าใหม่ (Quit)", floor), true)
				end
			end
		end
		task.delay(0.5, function()
			if not Core._alive then return end
			if LocalPlayer:GetAttribute("InBattle") ~= true and LocalPlayer:GetAttribute("InRaid") ~= true then
				local pgi = LocalPlayer:FindFirstChild("PlayerGui")
				local bg = pgi and pgi:FindFirstChild("Battle")
				local pf = bg and bg:FindFirstChild("Play")
				if pf and pf:IsA("GuiObject") and pf.Visible then
					pcall(function() pf.Visible = false end)
				end
			end
		end)
		return true
	end

	function Loops.TryRaidReplay(fromEvent: boolean?): boolean
		if not (Core.Flags.AutoRaidReplay and Helpers.IsRaidPlace()) then return false end
		local now = os.clock()
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local reveal = results and results:FindFirstChild("Reveal")
		local endScreen = results and results:FindFirstChild("EndScreen")
		local endVisible = endScreen and endScreen:IsA("GuiObject") and endScreen.Visible

		if reveal and reveal:IsA("GuiObject") and reveal.Visible and not endVisible then
			if Loops.raidRevealAt == 0 then
				Loops.raidRevealAt = now
			end
			if now - Loops.raidRevealAt >= 0.15 then
				if firesignal and reveal:IsA("GuiButton") then
					pcall(firesignal, reveal.Activated)
				end
				if now - Loops.raidRevealAt >= 0.3 and reveal.Visible then
					pcall(function() reveal.Visible = false end)
				end
			end
			return true
		else
			Loops.raidRevealAt = 0
		end

		if not endVisible then
			Loops.ResetRaidReplayState()
			return false
		end

		-- กด READY แล้ว (เซิร์ฟยืนยัน mine) -> ห้ามกดซ้ำ (กดซ้ำ = ยกเลิก Ready)
		if Loops.raidReplayMine then return true end

		local replayBtn = nil
		local left = endScreen:FindFirstChild("Left")
		local buttons = left and left:FindFirstChild("Buttons")
		local btn = buttons and buttons:FindFirstChild("Replay")
		if btn and btn:IsA("GuiButton") and btn.Visible then
			replayBtn = btn
			local title = btn:FindFirstChild("Title")
			if title and title:IsA("TextLabel") then
				-- ยืนยัน READY จากข้อความปุ่มเฉพาะหลังส่งคำสั่งในรอบนี้แล้ว ป้องกันข้อความค้างจากรอบก่อน
				local txt = tostring(title.Text or ""):upper()
				if Loops.raidReplaySentAt > 0 and txt:sub(1, 5) == "READY" then
					Loops.raidReplayMine = true
					return true
				end
			end
		end

		if Loops.raidEndScreenAt == 0 then
			Loops.raidEndScreenAt = now
		end
		-- ส่งไปแล้ว รอยืนยัน 0.7s ก่อนลองใหม่ (เฉพาะกรณีเซิร์ฟยังไม่ตอบ mine=true)
		if Loops.raidReplaySentAt > 0 and (now - Loops.raidReplaySentAt < 0.7) then return true end
		local tries = tonumber(Loops.raidReplayTries) or 0
		if tries >= 12 then return true end

		local raidQueue = Net.Remote("RaidQueue")
		if raidQueue and raidQueue:IsA("RemoteEvent") then
			Loops.raidReplayTries = tries + 1
			Loops.raidReplaySentAt = now
			Loops.lastRaidAt = now
			if Loops.raidReplayState == nil then
				pcall(function() raidQueue:FireServer("ResultsOpen") end)
			end
			pcall(function() raidQueue:FireServer("Again") end)
			logAction("RAID", string.format("กด READY เล่น Raid ซ้ำทันที (Again) #%d", tries + 1), true)
			return true
		elseif replayBtn and firesignal then
			Loops.raidReplayTries = tries + 1
			Loops.raidReplaySentAt = now
			Loops.lastRaidAt = now
			pcall(firesignal, replayBtn.Activated)
			logAction("RAID", string.format("กดปุ่ม READY เล่น Raid ซ้ำทันที (UI) #%d", tries + 1), true)
			return true
		end
		return false
	end

	function Loops.TryRaidReturn(): boolean
		if not (Core.Flags.AutoRaidReturn and Helpers.IsRaidPlace()) then return false end
		if Core.Flags.AutoRaidReplay then return false end
		local now = os.clock()
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local reveal = results and results:FindFirstChild("Reveal")
		local endScreen = results and results:FindFirstChild("EndScreen")
		local endVisible = endScreen and endScreen:IsA("GuiObject") and endScreen.Visible
		if reveal and reveal:IsA("GuiObject") and reveal.Visible and not endVisible then
			if Loops.raidRevealAt == 0 then
				Loops.raidRevealAt = now
				return true
			end
			if now - Loops.raidRevealAt >= 0.4 then
				if firesignal and reveal:IsA("GuiButton") then
					pcall(firesignal, reveal.Activated)
				end
				if now - Loops.raidRevealAt >= 0.8 and reveal.Visible then
					pcall(function() reveal.Visible = false end)
				end
			end
			return true
		else
			Loops.raidRevealAt = 0
		end
		if not endVisible then
			Loops.raidEndScreenAt = 0
			return false
		end
		if Loops.raidEndScreenAt == 0 then
			Loops.raidEndScreenAt = now
			return true
		end
		if now - Loops.raidEndScreenAt < 0.35 or now - Loops.lastRaidAt < 1.5 then return true end
		local raidQueue = Net.Remote("RaidQueue")
		if raidQueue and raidQueue:IsA("RemoteEvent") then
			Loops.lastRaidAt = now
			pcall(function() raidQueue:FireServer("Return") end)
			logAction("RAID", "ออกจาก Raid กลับล็อบบี้ (Return)", true)
			return true
		end
		return false
	end

	function Loops.TryRaidStartNow(): boolean
		if not (Core.Flags.RaidStartNow and Helpers.IsRaidPlace()) then return false end
		if LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("InBattle") == true then return false end
		local qState = Helpers.RaidQueueState
		if not (type(qState) == "table" and qState.leader and qState.state == "queued") then return false end
		local now = os.clock()
		if now - Loops.raidQueueStateAt < 0.2 then return true end
		-- ยิง StartNow แค่ 1 ครั้งต่อ 1 รอบคิว เพื่อไม่ให้ยิงซ้ำจนขึ้นแจ้งเตือน
		if Loops.raidStartSentAt >= Loops.raidQueueStateAt then return true end
		local raidQueue = Net.Remote("RaidQueue")
		if raidQueue and raidQueue:IsA("RemoteEvent") then
			Loops.lastRaidAt = now
			Loops.raidStartSentAt = now
			pcall(function() raidQueue:FireServer("StartNow") end)
			logAction("RAID", "กดเริ่ม Raid ทันที (StartNow)", true)
			return true
		end
		return false
	end

	function Loops.AutoRaidTick()
		if not Helpers.IsRaidPlace() then return end
		if Loops.raidSetupBusy then return end
		local now = os.clock()
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local reveal = results and results:FindFirstChild("Reveal")
		local endScreen = results and results:FindFirstChild("EndScreen")
		local endVisible = endScreen and endScreen:IsA("GuiObject") and endScreen.Visible
		local revealVisible = reveal and reveal:IsA("GuiObject") and reveal.Visible
		if endVisible or revealVisible then
			Loops.raidBattleStartedAt = 0
			Loops.raidWaveArmed = false
			Loops.raidQuitTriggered = false
			if Core.Flags.AutoRaidReplay then
				Loops.TryRaidReplay(false)
				return
			end
			if Core.Flags.AutoRaidReturn then
				Loops.TryRaidReturn()
			end
			return
		else
			Loops.ResetRaidReplayState()
		end

		local battleGui = pg and pg:FindFirstChild("Battle")
		local playFrame = battleGui and battleGui:FindFirstChild("Play")
		if LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("InBattle") == true then
			Helpers.RaidQueueState = nil
			Loops.raidQueueState = nil
			Loops.raidStartSentAt = 0
			Loops.ResetRaidReplayState()
			Loops.TryRaidEndWave()
			return
		end

		if playFrame and playFrame:IsA("GuiObject") and playFrame.Visible then
			pcall(function() playFrame.Visible = false end)
		end

		Loops.raidBattleStartedAt = 0
		Loops.raidTargetWaveAt = 0
		Loops.raidWaveArmed = false
		Loops.raidQuitTriggered = false

		local qState = Helpers.RaidQueueState
		if type(qState) == "table" then
			if qState.leader then
				if qState.state == "building" then
					if now - Loops.raidQueueStateAt < 0.1 then return end
					Loops.ApplyRaidSetup(qState)
					return
				elseif qState.state == "queued" then
					Loops.TryRaidStartNow()
					return
				end
			end
			return
		end

		if now - (Loops.lastRaidQuitAt or 0) < 1.2 then return end
		if now - Loops.lastRaidAt < 1.2 then return end

		local lobby = Workspace:FindFirstChild("Lobby")
		local queues = lobby and lobby:FindFirstChild("Queues")
		if not (queues and Helpers.IsAlive()) then return end
		local root = Helpers.GetRoot()
		if not root then return end
		local picked = Loops.FindEmptyRaidPad(queues, root.Position)
		if picked and picked.hitbox then
			-- ถ้ายืนอยู่ในแท่นคิวแล้ว รอเซิร์ฟตอบ building ก่อน ไม่วาร์ปซ้ำ
			if (root.Position - picked.hitbox.Position).Magnitude <= 8 and (now - Loops.lastRaidAt < 2.5) then
				return
			end
			Loops.lastRaidAt = now
			root.CFrame = picked.hitbox.CFrame + Vector3.new(0, 3, 0)
			logAction("RAID", "เข้าประตู Raid ว่าง: " .. picked.pad.Name, true)
			return
		end
	end

	function Loops.StartAutoRaid()
		if Core.Flags.AutoRaid then
			Core:Loop("AutoRaid", "AutoRaid", 0.35, Loops.AutoRaidTick)
		end
	end

	function Loops.AutoRaidReplayTick()
		Loops.TryRaidReplay(false)
	end

	function Loops.StartAutoRaidReplay()
		if Core.Flags.AutoRaidReplay then
			Loops.ResetRaidReplayState()
			Core:Loop("AutoRaidReplay", "AutoRaidReplay", 0.3, Loops.AutoRaidReplayTick)
		end
	end

	function Loops.AutoRaidReturnTick()
		Loops.TryRaidReturn()
	end

	function Loops.StartAutoRaidReturn()
		if Core.Flags.AutoRaidReturn then
			Core:Loop("AutoRaidReturn", "AutoRaidReturn", 0.5, Loops.AutoRaidReturnTick)
		end
	end

	function Loops.RaidStartNowTick()
		Loops.TryRaidStartNow()
	end

	function Loops.StartRaidStartNow()
		if Core.Flags.RaidStartNow then
			Core:Loop("RaidStartNow", "RaidStartNow", 0.4, Loops.RaidStartNowTick)
		end
	end

	function Loops.AutoBuyRaidShopTick()
		if Helpers.IsBossPlace() then return end
		if os.clock() - Loops.lastRaidShopAt < 3 then return end
		local raidShop = Net.Remote("RaidShop")
		if not (raidShop and raidShop:IsA("RemoteFunction")) then return end
		local coins = tonumber(LocalPlayer:GetAttribute("RaidCoins")) or 0
		if coins <= 0 then return end
		Loops.lastRaidShopAt = os.clock()
		local okC, okRes, catalog = Net.Invoke(raidShop, "Catalog")
		local items = (okC and okRes and type(catalog) == "table") and (type(catalog.offers) == "table" and catalog.offers or catalog) or nil
		if not items then
			local cfg = Helpers.GetRaidConfig()
			items = cfg and cfg.Merchant
		end
		if type(items) ~= "table" then return end
		local target = tostring(Core.Flags.RaidShopTarget or "All")
		for _, item in ipairs(items) do
			if type(item) == "table" and item.id then
				local matchTarget = (target == "All") or (tostring(item.id) == target)
				local price = tonumber(item.price) or math.huge
				local stock = item.stock or item.remaining
				local inStock = (stock == nil) or (tonumber(stock) or 0) > 0
				if matchTarget and inStock and coins >= price then
					local okB, resB, errB = Net.Invoke(raidShop, "Buy", item.id, 1)
					if okB and resB ~= false then
						coins -= price
						logAction("RAIDSHOP", string.format("ซื้อ %s (-%s Tokens)", tostring(item.ref or item.id), Helpers.Format(price)), true)
					elseif errB then
						logAction("RAIDSHOP", "ซื้อไม่สำเร็จ: " .. tostring(errB), false)
					end
				end
			end
		end
	end

	function Loops.StartAutoBuyRaidShop()
		if Core.Flags.AutoBuyRaidShop then
			Core:Loop("AutoBuyRaidShop", "AutoBuyRaidShop", 1.5, Loops.AutoBuyRaidShopTick)
		end
	end

	function Loops.AutoTravelBossTick()
		if os.clock() - Loops.lastTravelAt < 5 then return end
		if Helpers.IsBossPlace() then return end
		if LocalPlayer:GetAttribute("BossLocked") == true or LocalPlayer:GetAttribute("InBattle") == true then return end
		local lobby = Workspace:FindFirstChild("Lobby")
		local areas = lobby and lobby:FindFirstChild("Areas")
		if not areas then return end
		for _, areaName in ipairs({ "Boss", "Bosses", "BossBattles", "Boss Battles" }) do
			if areas:FindFirstChild(areaName) then
				Loops.lastTravelAt = os.clock()
				if Helpers.TriggerAreaPrompt(areaName, "BossTravelPrompt") or Helpers.TriggerAreaPrompt(areaName, "RaidTravelPrompt") or Helpers.TriggerAreaPrompt(areaName, nil) then
					logAction("BOSS", "วาร์ปเข้าโซน Boss Battles อัตโนมัติ", true)
				end
				return
			end
		end
	end

	function Loops.StartAutoTravelBoss()
		if Core.Flags.AutoTravelBoss then
			Core:Loop("AutoTravelBoss", "AutoTravelBoss", 1.5, Loops.AutoTravelBossTick)
		end
	end

	function Loops.ApplyBossSetup(state)
		if Loops.bossSetupBusy then return end
		local raidQueue = Net.Remote("RaidQueue")
		if not (raidQueue and raidQueue:IsA("RemoteEvent") and type(state) == "table" and state.leader) then return end
		if LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("InBattle") == true then return end
		Loops.bossSetupBusy = true
		local function stillBuilding()
			if not (Core._alive and Core.Flags.AutoBoss and Helpers.IsBossPlace()) then return false end
			if LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("InBattle") == true then return false end
			local cur = Helpers.RaidQueueState
			return type(cur) == "table" and cur.leader and cur.state == "building"
		end
		pcall(function()
			local diff = tostring(Core.Flags.BossDifficulty or "Easy")
			local size = math.clamp(math.floor(tonumber(Core.Flags.BossPartySize) or 4), 1, 4)
			local friends = Core.Flags.BossFriendsOnly == true
			task.wait(0.6)
			if not stillBuilding() then return end
			local cur = Helpers.RaidQueueState or state
			if cur.difficulty ~= diff then
				pcall(function() raidQueue:FireServer("Difficulty", diff) end)
				task.wait(0.35)
				if not stillBuilding() then return end
			end
			cur = Helpers.RaidQueueState or cur
			if tonumber(cur.size) ~= size then
				pcall(function() raidQueue:FireServer("Size", size) end)
				task.wait(0.35)
				if not stillBuilding() then return end
			end
			cur = Helpers.RaidQueueState or cur
			if (cur.friendsOnly == true) ~= friends then
				pcall(function() raidQueue:FireServer("Friends") end)
				task.wait(0.35)
				if not stillBuilding() then return end
			end
			task.wait(0.5)
			if not stillBuilding() then return end
			Loops.lastBossAt = os.clock()
			pcall(function() raidQueue:FireServer("Play") end)
			logAction("BOSS", string.format("ตั้งค่าคิว Boss (%s | %d คน) และกด Play", diff, size), true)
		end)
		Loops.bossSetupBusy = false
	end

	function Loops.ResetBossReplayState()
		Loops.bossEndScreenAt = 0
		Loops.bossRevealAt = 0
		Loops.bossReplayMine = false
		Loops.bossReplayState = nil
		Loops.bossReplaySentAt = 0
		Loops.bossReplayTries = 0
	end

	function Loops.TryBossReplay(fromEvent: boolean?): boolean
		if not (Core.Flags.AutoBossReplay and Helpers.IsBossPlace()) then return false end
		local now = os.clock()
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local reveal = results and results:FindFirstChild("Reveal")
		local endScreen = results and results:FindFirstChild("EndScreen")
		local endVisible = endScreen and endScreen:IsA("GuiObject") and endScreen.Visible

		if reveal and reveal:IsA("GuiObject") and reveal.Visible and not endVisible then
			if Loops.bossRevealAt == 0 then
				Loops.bossRevealAt = now
			end
			if now - Loops.bossRevealAt >= 0.15 then
				if firesignal and reveal:IsA("GuiButton") then
					pcall(firesignal, reveal.Activated)
				end
				if now - Loops.bossRevealAt >= 0.3 and reveal.Visible then
					pcall(function() reveal.Visible = false end)
				end
			end
			return true
		else
			Loops.bossRevealAt = 0
		end

		if not endVisible then
			Loops.ResetBossReplayState()
			return false
		end

		-- กด READY แล้ว (เซิร์ฟยืนยัน mine) -> ห้ามกดซ้ำ
		if Loops.bossReplayMine then return true end

		local replayBtn = nil
		local left = endScreen:FindFirstChild("Left")
		local buttons = left and left:FindFirstChild("Buttons")
		local btn = buttons and buttons:FindFirstChild("Replay")
		if btn and btn:IsA("GuiButton") and btn.Visible then
			replayBtn = btn
			local title = btn:FindFirstChild("Title")
			if title and title:IsA("TextLabel") then
				-- ยืนยัน READY จากข้อความปุ่มเฉพาะหลังส่งคำสั่งในรอบนี้แล้ว ป้องกันข้อความค้างจากรอบก่อน
				local txt = tostring(title.Text or ""):upper()
				if Loops.bossReplaySentAt > 0 and txt:sub(1, 5) == "READY" then
					Loops.bossReplayMine = true
					return true
				end
			end
		end

		if Loops.bossEndScreenAt == 0 then
			Loops.bossEndScreenAt = now
		end
		if Loops.bossReplaySentAt > 0 and (now - Loops.bossReplaySentAt < 0.7) then return true end
		local tries = tonumber(Loops.bossReplayTries) or 0
		if tries >= 12 then return true end

		local raidQueue = Net.Remote("RaidQueue") or Net.Remote("BossQueue")
		if raidQueue and raidQueue:IsA("RemoteEvent") then
			Loops.bossReplayTries = tries + 1
			Loops.bossReplaySentAt = now
			Loops.lastBossAt = now
			if Loops.bossReplayState == nil then
				pcall(function() raidQueue:FireServer("ResultsOpen") end)
			end
			pcall(function() raidQueue:FireServer("Again") end)
			logAction("BOSS", string.format("กด READY สู้บอสซ้ำทันที (Again) #%d", tries + 1), true)
			return true
		elseif replayBtn and firesignal then
			Loops.bossReplayTries = tries + 1
			Loops.bossReplaySentAt = now
			Loops.lastBossAt = now
			pcall(firesignal, replayBtn.Activated)
			logAction("BOSS", string.format("กดปุ่ม READY สู้บอสซ้ำทันที (UI) #%d", tries + 1), true)
			return true
		else
			local battleReq = Net.Remote("BattleRequest")
			if battleReq then
				Loops.bossReplayTries = tries + 1
				Loops.bossReplaySentAt = now
				Loops.lastBossAt = now
				local ok, res = Net.Invoke(battleReq, "Replay")
				logAction("BOSS", ok and res ~= false and "ส่งคำสั่งสู้บอสซ้ำ (BattleRequest)" or "ส่งคำสั่งสู้บอสซ้ำไม่สำเร็จ", ok and res ~= false)
				return true
			end
		end
		return false
	end

	function Loops.AutoBossTick()
		if not Helpers.IsBossPlace() then return end
		if Loops.bossSetupBusy then return end
		local now = os.clock()
		local raidQueue = Net.Remote("RaidQueue") or Net.Remote("BossQueue")
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local reveal = results and results:FindFirstChild("Reveal")
		local endScreen = results and results:FindFirstChild("EndScreen")
		local endVisible = endScreen and endScreen:IsA("GuiObject") and endScreen.Visible
		local revealVisible = reveal and reveal:IsA("GuiObject") and reveal.Visible
		if endVisible or revealVisible then
			if Core.Flags.AutoBossReplay then
				Loops.TryBossReplay(false)
				return
			end
			if endVisible then
				if Loops.bossEndScreenAt == 0 then
					Loops.bossEndScreenAt = now
					return
				end
				if now - Loops.bossEndScreenAt < 1.8 or now - Loops.lastBossAt < 3.5 then return end
				if Core.Flags.AutoBossReturn and raidQueue and raidQueue:IsA("RemoteEvent") then
					Loops.lastBossAt = now
					pcall(function() raidQueue:FireServer("Return") end)
					logAction("BOSS", "ออกจากบอสกลับล็อบบี้ (Return)", true)
				end
			end
			return
		else
			Loops.ResetBossReplayState()
		end

		if LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("InBattle") == true then
			Helpers.RaidQueueState = nil
			Loops.bossQueueState = nil
			Loops.bossStartSentAt = 0
			Loops.ResetBossReplayState()
			return
		end
		if now - Loops.lastBossAt < 3.5 then return end

		local qState = Helpers.RaidQueueState
		if type(qState) == "table" then
			if qState.leader then
				if qState.state == "building" then
					if now - Loops.bossQueueStateAt < 1.0 then return end
					Loops.lastBossAt = now
					Loops.ApplyBossSetup(qState)
					return
				elseif qState.state == "queued" then
					if Core.Flags.BossStartNow and raidQueue and raidQueue:IsA("RemoteEvent") then
						if now - Loops.bossQueueStateAt < 1.8 then return end
						if Loops.bossStartSentAt < Loops.bossQueueStateAt or (now - Loops.bossStartSentAt >= 5) then
							Loops.lastBossAt = now
							Loops.bossStartSentAt = now
							pcall(function() raidQueue:FireServer("StartNow") end)
							logAction("BOSS", "กดเริ่มสู้บอสทันที (StartNow)", true)
						end
					end
					return
				end
			end
			return
		end

		local lobby = Workspace:FindFirstChild("Lobby")
		local queues = lobby and lobby:FindFirstChild("Queues")
		if not (queues and Helpers.IsAlive()) then return end
		local root = Helpers.GetRoot()
		if not root then return end
		for _, pad in ipairs(queues:GetChildren()) do
			local blocked = pad:GetAttribute("Blocked") == true
			local leaderId = pad:GetAttribute("LeaderId")
			if not blocked or leaderId == LocalPlayer.UserId then
				local hitbox = pad:FindFirstChild("Hitbox") or pad:FindFirstChildWhichIsA("BasePart")
				if hitbox and hitbox:IsA("BasePart") then
					Loops.lastBossAt = now
					root.CFrame = hitbox.CFrame + Vector3.new(0, 3, 0)
					logAction("BOSS", "เข้าแท่นคิว Boss: " .. pad.Name, true)
					return
				end
			end
		end
	end

	function Loops.StartAutoBoss()
		if Core.Flags.AutoBoss then
			Core:Loop("AutoBoss", "AutoBoss", 1.0, Loops.AutoBossTick)
		end
	end

	function Loops.AutoBossReplayTick()
		Loops.TryBossReplay(false)
	end

	function Loops.StartAutoBossReplay()
		if Core.Flags.AutoBossReplay then
			Loops.ResetBossReplayState()
			Core:Loop("AutoBossReplay", "AutoBossReplay", 0.3, Loops.AutoBossReplayTick)
		end
	end

	function Loops.AutoBuyBossShopTick()
		if not Helpers.IsBossPlace() then return end
		if os.clock() - Loops.lastBossShopAt < 3 then return end
		local raidShop = Net.Remote("RaidShop")
		if not (raidShop and raidShop:IsA("RemoteFunction")) then return end
		local cash = Helpers.GetCash()
		if cash <= 0 then return end
		Loops.lastBossShopAt = os.clock()
		local okC, okRes, catalog = Net.Invoke(raidShop, "Catalog")
		local items = (okC and okRes and type(catalog) == "table") and (type(catalog.offers) == "table" and catalog.offers or catalog) or nil
		if not items then
			local cfg = Helpers.GetBossConfig()
			items = cfg and cfg.Merchant
		end
		if type(items) ~= "table" then return end
		local target = tostring(Core.Flags.BossShopTarget or "All")
		for _, item in ipairs(items) do
			if type(item) == "table" and item.id then
				local matchTarget = (target == "All") or (tostring(item.id) == target)
				local price = tonumber(item.price) or math.huge
				local stock = item.stock or item.remaining
				local inStock = (stock == nil) or (tonumber(stock) or 0) > 0
				if matchTarget and inStock and cash >= price then
					local okB, resB, errB = Net.Invoke(raidShop, "Buy", item.id, 1)
					if okB and resB ~= false then
						cash -= price
						logAction("BOSSSHOP", string.format("ซื้อ %s (-¥%s)", tostring(item.ref or item.id), Helpers.Format(price)), true)
					elseif errB then
						logAction("BOSSSHOP", "ซื้อไม่สำเร็จ: " .. tostring(errB), false)
					end
				end
			end
		end
	end

	function Loops.StartAutoBuyBossShop()
		if Core.Flags.AutoBuyBossShop then
			Core:Loop("AutoBuyBossShop", "AutoBuyBossShop", 1.5, Loops.AutoBuyBossShopTick)
		end
	end

	function Loops.AutoAscendTick()
		if os.clock() - Loops.lastAscendAt < 4 then return end
		local inv = Helpers.Inventory
		if type(inv) ~= "table" or type(inv.units) ~= "table" then
			Loops.RequestSkillSync()
			return
		end
		local ascCfg = Helpers.GetAscensionConfig()
		local ascendRemote = Net.Remote("AscendUnit")
		if not (ascCfg and type(ascCfg.Paths) == "table" and ascendRemote and ascendRemote:IsA("RemoteFunction")) then return end

		local pathByFrom = {}
		for _, p in ipairs(ascCfg.Paths) do
			if type(p) == "table" and p.From and p.To then
				pathByFrom[tostring(p.From)] = p
			end
		end
		local reqStars = tonumber(ascCfg.RequiredStars) or 5
		local baseMats = type(ascCfg.Materials) == "table" and ascCfg.Materials or {}
		local cash = Helpers.GetCash()

		for _, unit in pairs(inv.units) do
			if type(unit) == "table" and unit.id and unit.name then
				local path = pathByFrom[tostring(unit.name)]
				if path and (tonumber(unit.stars) or 0) >= reqStars then
					local needCoins = tonumber(path.Coins) or 0
					local okCost = cash >= needCoins
					if okCost and path.Item then
						local have = Helpers.FindItemCount(inv, tostring(path.Item))
						if have < (tonumber(path.Count) or 1) then okCost = false end
					end
					if okCost then
						for _, m in ipairs(baseMats) do
							if type(m) == "table" and m.Id then
								if Helpers.FindItemCount(inv, tostring(m.Id)) < (tonumber(m.Count) or 1) then
									okCost = false
									break
								end
							end
						end
					end
					if okCost then
						Loops.lastAscendAt = os.clock()
						local okA, resA, errA = Net.Invoke(ascendRemote, unit.id)
						if okA and resA ~= false then
							logAction("ASCEND", string.format("Ascend สำเร็จ: %s -> %s", tostring(unit.name), tostring(path.To)), true)
							Loops.RequestSkillSync()
						else
							logAction("ASCEND", string.format("Ascend %s ไม่สำเร็จ: %s", tostring(unit.name), tostring(errA or resA)), false)
						end
						return
					end
				end
			end
		end
	end

	function Loops.StartAutoAscend()
		if Core.Flags.AutoAscendUnit then
			if type(Helpers.Inventory) ~= "table" then Loops.RequestSkillSync() end
			Core:Loop("AutoAscendUnit", "AutoAscendUnit", 2.0, Loops.AutoAscendTick)
		end
	end

	function Loops.SellTrashUnits(maxRarity: string?, silentIfEmpty: boolean?)
		local inv = Helpers.Inventory
		if type(inv) ~= "table" or type(inv.units) ~= "table" then
			Loops.RequestSkillSync()
			if not silentIfEmpty then
				logAction("SELL", "กำลังซิงค์ข้อมูลคลังตัวละคร ลองใหม่อีกครั้ง", false)
			end
			return 0, 0
		end
		if #Helpers.RarityOrder == 0 then Helpers.RefreshRaritiesAndAscension() end
		local rarityRank = {}
		for i, r in ipairs(Helpers.RarityOrder) do
			rarityRank[r] = i
		end
		local targetRarity = tostring(maxRarity or Core.Flags.SellUnitMaxRarity or "Epic")
		local maxRank = rarityRank[targetRarity]
		if not maxRank then
			if not silentIfEmpty then
				logAction("SELL", "ไม่พบระดับความหายาก: " .. targetRarity, false)
			end
			return 0, 0
		end

		local teamIds = {}
		if type(inv.team) == "table" then
			for _, t in pairs(inv.team) do
				if type(t) == "table" and t.id then
					teamIds[t.id] = true
				end
			end
		end

		local batch = {}
		for _, unit in pairs(inv.units) do
			if type(unit) == "table" and unit.id and unit.name then
				if unit.locked ~= true and unit.placed ~= true and not teamIds[unit.id] then
					local rarity = Helpers.GetUnitRarity(unit)
					local rank = rarityRank[rarity]
					if rank and rank <= maxRank then
						table.insert(batch, { kind = "Unit", id = unit.id, count = 1 })
					end
				end
			end
		end

		if #batch == 0 then
			if not silentIfEmpty then
				logAction("SELL", string.format("ไม่พบตัวละครระดับ %s ลงมาที่ขายได้", targetRarity), true)
			end
			return 0, 0
		end

		local sellItemsRemote = Net.Remote("SellItems")
		local sellItemRemote = Net.Remote("SellItem")
		local totalSold, totalCoins = 0, 0

		if sellItemsRemote and sellItemsRemote:IsA("RemoteFunction") then
			for i = 1, #batch, 300 do
				if not Core._alive then break end
				if i > 1 then task.wait(0.2) end
				local chunk = table.move(batch, i, math.min(i + 299, #batch), 1, {})
				local okS, resS = Net.Invoke(sellItemsRemote, chunk)
				if okS and type(resS) == "table" then
					totalSold += tonumber(resS.sold) or #chunk
					totalCoins += tonumber(resS.coins) or 0
				elseif not okS then
					logAction("SELL", "ขายตัวละครล้มเหลว: " .. tostring(resS), false)
					break
				end
			end
		elseif sellItemRemote and sellItemRemote:IsA("RemoteFunction") then
			for _, entry in ipairs(batch) do
				if not Core._alive then break end
				local okS, resS = Net.Invoke(sellItemRemote, entry.kind, entry.id, entry.count)
				if okS and type(resS) == "number" then
					totalSold += 1
					totalCoins += resS
				end
			end
		else
			logAction("SELL", "ไม่พบ Remote สำหรับขายตัวละคร (SellItems/SellItem)", false)
			return 0, 0
		end

		if totalSold > 0 then
			Stats.soldUnits += totalSold
			logAction("SELL", string.format("ขายตัวละครระดับ %s ลงมาสำเร็จ %d ตัว (+%s coins)", targetRarity, totalSold, Helpers.Format(math.floor(totalCoins + 0.5))), true)
			Loops.RequestSkillSync()
		elseif not silentIfEmpty then
			logAction("SELL", string.format("ไม่สามารถขายตัวละครระดับ %s ลงมาได้", targetRarity), false)
		end
		return totalSold, totalCoins
	end

	function Loops.AutoSellUnitsTick()
		if os.clock() - Loops.lastSellAt < 4 then return end
		Loops.lastSellAt = os.clock()
		Loops.SellTrashUnits(Core.Flags.SellUnitMaxRarity, true)
	end

	function Loops.StartAutoSellUnits()
		if Core.Flags.AutoSellUnits then
			if type(Helpers.Inventory) ~= "table" then Loops.RequestSkillSync() end
			Core:Loop("AutoSellUnits", "AutoSellUnits", 2.0, Loops.AutoSellUnitsTick)
		end
	end

	function Loops.AutoClaimBattlePassTick()
		if Loops.bpBusy then return end
		if os.clock() - Loops.lastBpAt < 5 then return end
		local bp = Net.Remote("BattlePass")
		if not (bp and bp:IsA("RemoteFunction")) then return end

		local bpCfg = Helpers.GetBattlePassConfig()
		local maxLevel = tonumber(bpCfg and bpCfg.MaxLevel) or 50
		local claimable = tonumber(LocalPlayer:GetAttribute("BattlePassClaimable")) or 0
		local bpLevel = tonumber(LocalPlayer:GetAttribute("BattlePassLevel")) or 0
		local needClaim = claimable > 0
		local canCheckReset = bpLevel >= maxLevel and (os.clock() - Loops.lastBpResetAt >= 10)
		if not needClaim and not canCheckReset then return end

		Loops.bpBusy = true
		Loops.lastBpAt = os.clock()

		local okRun, runErr = pcall(function()
			if needClaim then
				local ok, res, err = Net.Invoke(bp, "ClaimAll")
				if ok and res == true then
					logAction("PASS", string.format("รับรางวัล Battle Pass ทั้งหมดสำเร็จ (%d รายการ)", claimable), true)
					if canCheckReset then task.wait(0.35) end
				else
					logAction("PASS", "รับรางวัล Battle Pass ไม่สำเร็จ: " .. tostring(err or res), false)
					return
				end
			end

			if canCheckReset then
				-- เช็กสถานะจริงจาก Server ก่อนยิงคำสั่ง Reset
				local okS, stOk, stData = Net.Invoke(bp, "State")
				if not (okS and stOk == true and type(stData) == "table") then return end

				local srvLevel = tonumber(stData.level) or 0
				if srvLevel < maxLevel then return end

				local endsAt = tonumber(stData.endsAt) or tonumber(bpCfg and bpCfg.Ends) or 0
				if endsAt > 0 and endsAt <= os.time() then return end

				local srvClaimable = tonumber(stData.claimable) or 0
				if srvClaimable > 0 then
					local okC, resC, errC = Net.Invoke(bp, "ClaimAll")
					if okC and resC == true then
						logAction("PASS", string.format("รับรางวัล Battle Pass ก่อนรีเซ็ตสำเร็จ (%d รายการ)", srvClaimable), true)
						task.wait(0.35)
					else
						logAction("PASS", "รับรางวัลก่อนรีเซ็ตไม่สำเร็จ (ยกเลิกการรีเซ็ต): " .. tostring(errC or resC), false)
						return
					end
				end

				Loops.lastBpResetAt = os.clock()
				local okR, resR, errR = Net.Invoke(bp, "Reset")
				if okR and resR == true then
					logAction("PASS", string.format("รีเซ็ต Battle Pass สำเร็จ (Lv.%d -> Lv.0)", srvLevel), true)
				else
					logAction("PASS", "รีเซ็ต Battle Pass ไม่สำเร็จ: " .. tostring(errR or resR), false)
				end
			end
		end)

		Loops.bpBusy = false
		if not okRun then
			logAction("PASS", "Battle Pass error: " .. tostring(runErr), false)
		end
	end

	function Loops.StartAutoClaimBattlePass()
		if Core.Flags.AutoClaimBattlePass then
			Core:Loop("AutoClaimBattlePass", "AutoClaimBattlePass", 3.0, Loops.AutoClaimBattlePassTick)
		end
	end

	function Loops.AutoClaimWeeklyTick()
		if os.clock() - Loops.lastWeeklyAt < 15 then return end
		local weekly = Net.Remote("WeeklyRewards")
		if not (weekly and weekly:IsA("RemoteFunction")) then return end
		Loops.lastWeeklyAt = os.clock()
		local okS, resS, state = Net.Invoke(weekly, "State")
		if not (okS and resS and type(state) == "table") then return end
		local list = type(state.claimable) == "table" and state.claimable or (type(state.pending) == "table" and state.pending or state)
		for _, entry in ipairs(list) do
			if type(entry) == "table" and entry.board and entry.week and entry.claimed ~= true then
				local okC, resC = Net.Invoke(weekly, "Claim", entry.board, entry.week)
				if okC and resC ~= false then
					logAction("WEEKLY", string.format("รับรางวัลประจำสัปดาห์สำเร็จ (%s)", tostring(entry.board)), true)
				end
				task.wait(0.2)
			end
		end
	end

	function Loops.StartAutoClaimWeekly()
		if Core.Flags.AutoClaimWeekly then
			Core:Loop("AutoClaimWeekly", "AutoClaimWeekly", 15.0, Loops.AutoClaimWeeklyTick)
		end
	end

	function Loops.AutoTravelPvpTick()
		if os.clock() - Loops.lastTravelAt < 5 then return end
		if LocalPlayer:GetAttribute("PvpLocked") == true or LocalPlayer:GetAttribute("InBattle") == true then return end
		local lobby = Workspace:FindFirstChild("Lobby")
		local areas = lobby and lobby:FindFirstChild("Areas")
		if not (areas and areas:FindFirstChild("PVP")) then return end
		Loops.lastTravelAt = os.clock()
		if Helpers.TriggerAreaPrompt("PVP", "PvpTravelPrompt") then
			logAction("PVP", "วาร์ปเข้าโซน PvP อัตโนมัติ", true)
		end
	end

	function Loops.StartAutoTravelPvp()
		if Core.Flags.AutoTravelPvp then
			Core:Loop("AutoTravelPvp", "AutoTravelPvp", 1.5, Loops.AutoTravelPvpTick)
		end
	end

	function Loops.AutoPvpTick()
		if os.clock() - Loops.lastPvpAt < 2 then return end
		local isPvp = LocalPlayer:GetAttribute("BattleKind") == "Pvp" or LocalPlayer:GetAttribute("PvpSide") ~= nil
		local pg = LocalPlayer:FindFirstChild("PlayerGui")
		local results = pg and pg:FindFirstChild("Results")
		local endScreen = results and results:FindFirstChild("EndScreen")
		if endScreen and endScreen:IsA("GuiObject") and endScreen.Visible and isPvp then
			Loops.lastPvpAt = os.clock()
			local pvpQueue = Net.Remote("PvpQueue") or Net.Remote("PvpMatch")
			if Core.Flags.AutoPvpReplay then
				if pvpQueue and pvpQueue:IsA("RemoteEvent") then
					pcall(function() pvpQueue:FireServer("Again") end)
					logAction("PVP", "ส่งคำสั่งเล่น PvP ซ้ำ (Again)", true)
				else
					local battleReq = Net.Remote("BattleRequest")
					if battleReq then Net.Invoke(battleReq, "Replay") end
					logAction("PVP", "ส่งคำสั่งเล่น PvP ซ้ำ (Replay)", true)
				end
			else
				if pvpQueue and pvpQueue:IsA("RemoteEvent") then
					pcall(function() pvpQueue:FireServer("Return") end)
				else
					local battleReq = Net.Remote("BattleRequest")
					if battleReq then Net.Invoke(battleReq, "Quit") end
				end
				logAction("PVP", "ออกจากแมตช์ PvP", true)
			end
			return
		end

		if LocalPlayer:GetAttribute("PvpLocked") == true or LocalPlayer:GetAttribute("InBattle") == true then return end
		local pvpRemote = Net.Remote("PvpQueue") or Net.Remote("PvpMatch") or Net.Remote("PvpRequest")
		if pvpRemote then
			Loops.lastPvpAt = os.clock()
			if pvpRemote:IsA("RemoteEvent") then
				pcall(function() pvpRemote:FireServer("Queue") end)
				pcall(function() pvpRemote:FireServer("Play") end)
				logAction("PVP", "ส่งคำสั่งเข้าคิว PvP อัตโนมัติ", true)
			elseif pvpRemote:IsA("RemoteFunction") then
				local ok, res = Net.Invoke(pvpRemote, "Queue")
				if ok and res ~= false then logAction("PVP", "เข้าคิว PvP สำเร็จ", true) end
			end
			return
		end

		local lobby = Workspace:FindFirstChild("Lobby")
		local pvpQueues = lobby and (lobby:FindFirstChild("PvpQueues") or lobby:FindFirstChild("PVPQueues"))
		if pvpQueues and Helpers.IsAlive() then
			local root = Helpers.GetRoot()
			if not root then return end
			for _, pad in ipairs(pvpQueues:GetChildren()) do
				if pad:GetAttribute("Blocked") ~= true or pad:GetAttribute("LeaderId") == LocalPlayer.UserId then
					local hitbox = pad:FindFirstChild("Hitbox") or pad:FindFirstChildWhichIsA("BasePart")
					if hitbox and hitbox:IsA("BasePart") then
						Loops.lastPvpAt = os.clock()
						root.CFrame = hitbox.CFrame + Vector3.new(0, 3, 0)
						logAction("PVP", "เข้าแท่นคิว PvP: " .. pad.Name, true)
						return
					end
				end
			end
		end
	end

	function Loops.StartAutoPvp()
		if Core.Flags.AutoPvp then
			Core:Loop("AutoPvp", "AutoPvp", 1.0, Loops.AutoPvpTick)
		end
	end

	function Loops.AutoBuyPvpShopTick()
		if os.clock() - Loops.lastPvpShopAt < 3 then return end
		local pvpShop = Net.Remote("PvpShop") or Net.Remote("PvpMerchant")
		if not (pvpShop and pvpShop:IsA("RemoteFunction")) then return end
		Loops.lastPvpShopAt = os.clock()
		local okC, okRes, catalog = Net.Invoke(pvpShop, "Catalog")
		if not (okC and okRes and type(catalog) == "table") then return end
		local coins = tonumber(LocalPlayer:GetAttribute("PvpCoins") or LocalPlayer:GetAttribute("PvpTokens")) or 0
		for _, item in ipairs(catalog) do
			if type(item) == "table" and item.id then
				local price = tonumber(item.price) or math.huge
				local stock = item.stock or item.remaining
				if (stock == nil or (tonumber(stock) or 0) > 0) and coins >= price then
					local okB, resB = Net.Invoke(pvpShop, "Buy", item.id, 1)
					if okB and resB ~= false then
						coins -= price
						logAction("PVPSHOP", string.format("ซื้อ %s (-%s)", tostring(item.ref or item.id), Helpers.Format(price)), true)
					end
				end
			end
		end
	end

	function Loops.StartAutoBuyPvpShop()
		if Core.Flags.AutoBuyPvpShop then
			Core:Loop("AutoBuyPvpShop", "AutoBuyPvpShop", 1.5, Loops.AutoBuyPvpShopTick)
		end
	end

	function Loops.AutoBuyShopTick()
		if os.clock() - Loops.lastShopAt < 1.2 then return end
		local shopBuy = Net.Remote("ShopBuy")
		if not (shopBuy and shopBuy:IsA("RemoteFunction")) then return end
		if Helpers.Inventory == nil then
			local req = Net.Remote("RequestInventory")
			if req and req:IsA("RemoteEvent") then pcall(function() req:FireServer() end) end
		end
		if Helpers.RefreshShop() and Core._rebuildShopUI then
			pcall(Core._rebuildShopUI)
		end
		if #Helpers.ShopOffers == 0 then return end
		local cash = Helpers.GetCash()
		if cash <= 0 then return end
		Loops.lastShopAt = os.clock()

		local rarityRank = {}
		for i, r in ipairs(Helpers.RarityOrder) do rarityRank[r] = i end
		local minRarity = tostring(Core.Flags.ShopMinRarity or "All")
		local minRank = (minRarity ~= "All") and (rarityRank[minRarity] or 0) or 0
		local filterKind = tostring(Core.Flags.ShopFilterKind or "All")
		local buyAll = Core.Flags.ShopBuyAll == true
		local targets = type(Core.Flags.ShopTargets) == "table" and Core.Flags.ShopTargets or {}
		local boughtAny = false

		for _, offer in ipairs(Helpers.ShopOffers) do
			if not Core._alive or not Core.Flags.AutoBuyShop then break end
			if type(offer) == "table" and offer.id then
				local rem = Helpers.GetShopRemaining(offer, Helpers.ShopRotation)
				local price = tonumber(offer.price) or math.huge
				local kind = tostring(offer.kind or "")
				local ref = tostring(offer.ref or offer.id)
				local rarity = tostring(offer.rarity or "Common")
				local okKind = (filterKind == "All") or (kind == filterKind)
				local okRarity = (minRank == 0) or ((rarityRank[rarity] or 0) >= minRank)
				local okTarget = buyAll or (targets[ref] == true)
				if rem > 0 and price > 0 and cash >= price and okKind and okRarity and okTarget then
					local qty = math.min(rem, math.floor(cash / price))
					if qty >= 1 then
						local okB, resB, errB = Net.Invoke(shopBuy, offer.id, qty)
						if okB and resB == true then
							local spent = price * qty
							cash -= spent
							Stats.spent += spent
							boughtAny = true
							if type(Helpers.Inventory) == "table" then
								if type(Helpers.Inventory.shop) ~= "table" or Helpers.Inventory.shop.Rotation ~= Helpers.ShopRotation then
									Helpers.Inventory.shop = { Rotation = Helpers.ShopRotation, Used = {} }
								end
								Helpers.Inventory.shop.Used = Helpers.Inventory.shop.Used or {}
								Helpers.Inventory.shop.Used[offer.id] = (tonumber(Helpers.Inventory.shop.Used[offer.id]) or 0) + qty
							end
							local totalAmt = qty * (tonumber(offer.amount) or 1)
							logAction("SHOP", string.format("ซื้อ %dx %s (-¥%s)", totalAmt, Helpers.GetShopOfferName(offer), Helpers.Format(spent)), true)
							task.wait(0.15)
						elseif errB then
							logAction("SHOP", "ซื้อไม่สำเร็จ (" .. Helpers.GetShopOfferName(offer) .. "): " .. tostring(errB), false)
							Loops.lastShopAt = os.clock() + 1.5
							break
						end
					end
				end
			end
		end

		if boughtAny and Helpers.RefreshShop() and Core._rebuildShopUI then
			pcall(Core._rebuildShopUI)
		end
	end

	function Loops.StartAutoBuyShop()
		if Core.Flags.AutoBuyShop then
			Core:Loop("AutoBuyShop", "AutoBuyShop", 1.5, Loops.AutoBuyShopTick)
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

	function Loops.InitAntiAfk()
		if Loops._antiAfkInit then return end
		Loops._antiAfkInit = true
		Core:Connect(LocalPlayer.Idled, function()
			if not Core.Flags.AntiAfk then return end
			local ok = pcall(function()
				local vu = game:GetService("VirtualUser")
				vu:CaptureController()
				vu:ClickButton2(Vector2.new(0, 0))
			end)
			if ok then
				local now = os.clock()
				if now - (Loops._lastAntiAfkLogAt or 0) >= 300 then
					Loops._lastAntiAfkLogAt = now
					logAction("SYS", "Anti-AFK ทำงาน (รีเซ็ตเวลา Idle)", true)
				end
			end
		end)
	end

	function Loops.AutoBuyTick()
		if Core.Busy or os.clock() < Loops.backoffUntil or Helpers.IsRaidPlace() or Helpers.IsBossPlace() then return end
		if not Helpers.IsAlive() then return end
		local list, folder = Loops.SelectTargets()
		if not list or #list == 0 then return end
		Core.Busy = true
		for _, entry in ipairs(list) do
			if not (Core._alive and Core.Flags.AutoBuyChest) or os.clock() < Loops.backoffUntil then break end
			local ok, bought = pcall(Loops.BuyChest, entry, folder)
			if not ok then
				logAction("ERR", bought, false)
			elseif bought then
				break
			end
		end
		Core.Busy = false
	end

	function Loops.StartAutoBuy()
		if Core.Flags.AutoBuyChest then
			Core:Loop("AutoBuyChest", "AutoBuyChest", 0.25, Loops.AutoBuyTick)
		end
	end

	function Loops.AutoBuyFreeTick()
		if Core.Flags.AutoBuyChest then return end
		if Core.Busy or os.clock() < Loops.backoffUntil or Helpers.IsRaidPlace() or Helpers.IsBossPlace() then return end
		if not Helpers.IsAlive() then return end
		local plot = Helpers.GetPlot()
		local folder = plot and plot:FindFirstChild("ActiveChests")
		if not folder then return end
		for _, chest in ipairs(folder:GetChildren()) do
			if chest:IsA("Model") and (Loops.attempts[chest] or 0) < 3 and Helpers.ChestPrice(chest) == 0 then
				Core.Busy = true
				local ok, err = pcall(Loops.BuyChest, { chest = chest, price = 0, tier = Helpers.ChestTier(chest) }, folder)
				Core.Busy = false
				if not ok then logAction("ERR", err, false) end
				break
			end
		end
	end

	function Loops.StartAutoBuyFree()
		if Core.Flags.AutoBuyFreeChest then
			Core:Loop("AutoBuyFreeChest", "AutoBuyFreeChest", 0.35, Loops.AutoBuyFreeTick)
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
				if type(data) == "table" then
					Helpers.Inventory = data
					if type(data.skillTree) == "table" then
						Helpers.SkillTree = data.skillTree
						Helpers._skillSynced = true
					end
					task.defer(function()
						if Core._alive and Helpers.RefreshShop() and Core._rebuildShopUI then
							pcall(Core._rebuildShopUI)
						end
					end)
				end
			end)
		end
		local function bindShopChanged(sc)
			if not (sc and sc:IsA("RemoteEvent")) then return end
			Core:Connect(sc.OnClientEvent, function()
				task.defer(function()
					if not Core._alive then return end
					if Helpers.RefreshShop() and Core._rebuildShopUI then
						pcall(Core._rebuildShopUI)
					end
					if Core.Flags.AutoBuyShop then
						Loops.AutoBuyShopTick()
					end
				end)
			end)
		end
		bindShopChanged(ev:FindFirstChild("ShopChanged"))
		local function bindRaidQueue(rq)
			if not (rq and rq:IsA("RemoteEvent")) then return end
			Core:Connect(rq.OnClientEvent, function(payload)
				if type(payload) ~= "table" then return end
				local isBoss = Helpers.IsBossPlace()
				if payload.state == "building" or payload.state == "queued" then
					if LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("InBattle") == true then return end
					if isBoss then
						if Loops.bossQueueState ~= payload.state then
							Loops.bossQueueState = payload.state
							Loops.bossQueueStateAt = os.clock()
							if payload.state == "building" then
								Loops.bossStartSentAt = 0
							end
						end
						Helpers.RaidQueueState = payload
					else
						if Loops.raidQueueState ~= payload.state then
							Loops.raidQueueState = payload.state
							Loops.raidQueueStateAt = os.clock()
							if payload.state == "building" then
								Loops.raidStartSentAt = 0
							end
						end
						Helpers.RaidQueueState = payload
						if payload.leader then
							if payload.state == "building" and Core.Flags.AutoRaid and not Loops.raidSetupBusy then
								task.defer(function()
									if Core._alive and Core.Flags.AutoRaid and Helpers.IsRaidPlace() and not Loops.raidSetupBusy then
										Loops.ApplyRaidSetup(payload)
									end
								end)
							elseif payload.state == "queued" and Core.Flags.RaidStartNow then
								task.delay(0.12, function()
									if Core._alive and Core.Flags.RaidStartNow and Helpers.IsRaidPlace() then
										Loops.TryRaidStartNow()
									end
								end)
							end
						end
					end
				elseif payload.state == "replay" then
					local nowEv = os.clock()
					if isBoss then
						local firstState = Loops.bossReplayState == nil
						Loops.bossReplayState = payload
						Loops.bossReplayMine = payload.mine == true
						if Core.Flags.AutoBossReplay and not Loops.bossReplayMine then
							if firstState or (Loops.bossReplaySentAt > 0 and nowEv - Loops.bossReplaySentAt >= 0.25) then
								Loops.bossReplaySentAt = 0
							end
							task.defer(function()
								if not (Core._alive and Core.Flags.AutoBossReplay and Helpers.IsBossPlace()) then return end
								Loops.TryBossReplay(true)
							end)
						end
					else
						local firstState = Loops.raidReplayState == nil
						Loops.raidReplayState = payload
						Loops.raidReplayMine = payload.mine == true
						if Core.Flags.AutoRaidReplay and not Loops.raidReplayMine then
							if firstState or (Loops.raidReplaySentAt > 0 and nowEv - Loops.raidReplaySentAt >= 0.25) then
								Loops.raidReplaySentAt = 0
							end
							task.defer(function()
								if not (Core._alive and Core.Flags.AutoRaidReplay and Helpers.IsRaidPlace()) then return end
								Loops.TryRaidReplay(true)
							end)
						end
					end
				elseif payload.state == "replayGo" or payload.state == "idle" or payload.state == "left" or payload.state == "started" or payload.state == "fighting" or payload.state == "closed" or payload.state == "cancelled" then
					Helpers.RaidQueueState = nil
					if isBoss then
						Loops.bossQueueState = nil
						Loops.bossStartSentAt = 0
						Loops.ResetBossReplayState()
					else
						Loops.raidQueueState = nil
						Loops.raidStartSentAt = 0
						Loops.ResetRaidReplayState()
					end
				end
			end)
		end
		local function bindResultsUI(res)
			if not res then return end
			task.spawn(function()
				local es = res:FindFirstChild("EndScreen") or res:WaitForChild("EndScreen", 10)
				if Core._alive and es and es:IsA("GuiObject") then
					local function onEndVisible()
						if es.Visible then
							if Core.Flags.AutoBossReplay and Helpers.IsBossPlace() then
								Loops.bossEndScreenAt = 0
								Loops.bossReplayMine = false
								Loops.bossReplaySentAt = 0
								Loops.bossReplayTries = 0
								task.defer(Loops.TryBossReplay, true)
							elseif Core.Flags.AutoRaidReplay and Helpers.IsRaidPlace() then
								Loops.raidEndScreenAt = 0
								Loops.raidReplayMine = false
								Loops.raidReplaySentAt = 0
								Loops.raidReplayTries = 0
								task.defer(Loops.TryRaidReplay, true)
							end
						else
							if Helpers.IsBossPlace() then
								Loops.ResetBossReplayState()
							elseif Helpers.IsRaidPlace() then
								Loops.ResetRaidReplayState()
							end
						end
					end
					Core:Connect(es:GetPropertyChangedSignal("Visible"), onEndVisible)
					if es.Visible then onEndVisible() end
				end
			end)
			task.spawn(function()
				local rev = res:FindFirstChild("Reveal") or res:WaitForChild("Reveal", 10)
				if Core._alive and rev and rev:IsA("GuiObject") then
					Core:Connect(rev:GetPropertyChangedSignal("Visible"), function()
						if rev.Visible then
							if Core.Flags.AutoBossReplay and Helpers.IsBossPlace() then
								task.defer(Loops.TryBossReplay, false)
							elseif Core.Flags.AutoRaidReplay and Helpers.IsRaidPlace() then
								task.defer(Loops.TryRaidReplay, false)
							end
						end
					end)
				end
			end)
		end
		local pgNow = LocalPlayer:FindFirstChild("PlayerGui")
		if pgNow then
			bindResultsUI(pgNow:FindFirstChild("Results"))
			Core:Connect(pgNow.ChildAdded, function(ch)
				if ch.Name == "Results" then
					task.defer(bindResultsUI, ch)
				end
			end)
		end
		Core:Connect(LocalPlayer:GetAttributeChangedSignal("InBattle"), function()
			if LocalPlayer:GetAttribute("InBattle") == true then
				Loops.raidBattleStartedAt = os.clock()
				Loops.raidTargetWaveAt = 0
				Loops.raidWaveArmed = false
				Loops.raidQuitTriggered = false
			else
				Loops.raidBattleStartedAt = 0
				Loops.raidTargetWaveAt = 0
				Loops.raidWaveArmed = false
				Loops.raidQuitTriggered = false
			end
		end)
		Core:Connect(LocalPlayer:GetAttributeChangedSignal("BattleFloor"), function()
			if Helpers.IsRaidPlace() and (tonumber(Core.Flags.RaidEndWave) or 0) > 0 then
				task.defer(Loops.TryRaidEndWave)
			end
		end)
		local function bindBossEvent(be)
			if not (be and be:IsA("RemoteEvent")) then return end
			Core:Connect(be.OnClientEvent, function(payload)
				if type(payload) == "table" and payload.t == "boss" then
					Helpers.RaidQueueState = nil
					Loops.bossQueueState = nil
					Loops.bossStartSentAt = 0
					Loops.ResetBossReplayState()
					if payload.phase then
						logAction("BOSS", "Boss Phase " .. tostring(payload.phase), true)
					end
				end
			end)
		end
		bindRaidQueue(ev:FindFirstChild("RaidQueue"))
		bindBossEvent(ev:FindFirstChild("BossEvent"))
		Core:Connect(ev.ChildAdded, function(ch)
			table.clear(Net._cache)
			if ch.Name == "RaidQueue" then bindRaidQueue(ch) end
			if ch.Name == "BossEvent" then bindBossEvent(ch) end
			if ch.Name == "ShopChanged" then bindShopChanged(ch) end
			local lower = ch.Name:lower()
			if lower:find("pvp", 1, true) or lower:find("raid", 1, true) or lower:find("boss", 1, true) or lower:find("shop", 1, true) then
				Helpers.RefreshRaids()
				Helpers.RefreshBoss()
				Helpers.RefreshPvp()
				if Helpers.RefreshShop() and Core._rebuildShopUI then pcall(Core._rebuildShopUI) end
			end
		end)
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
	-- 6.5 ULTIMATE FPS BOOST + FARMING STATS OVERLAY
	-- =================================================================
	local FpsBoost = {
		active = false,
		render3DOff = false,
		fps = 0,
		savedProps = setmetatable({}, { __mode = "k" }),
		savedLighting = nil,
		savedTerrain = nil,
		savedQuality = nil,
		_descConn = nil,
		_fpsConn = nil,
		_uiThread = nil,
		_scanThread = nil,
		_capApplied = false,
		_gui = nil,
		_fullFrame = nil,
		_miniFrame = nil,
		_refs = {},
	}

	function FpsBoost.GetCapOptions()
		return {
			{ id = "0", name = "ไม่จำกัด (Max)" },
			{ id = "30", name = "30 FPS" },
			{ id = "60", name = "60 FPS" },
			{ id = "15", name = "15 FPS (ประหยัดสุด)" },
		}
	end

	local function saveProp(inst: Instance, prop: string)
		local bucket = FpsBoost.savedProps[inst]
		if not bucket then
			bucket = {}
			FpsBoost.savedProps[inst] = bucket
		end
		if bucket[prop] == nil then
			local ok, val = pcall(function() return (inst :: any)[prop] end)
			if ok then bucket[prop] = val end
		end
	end

	function FpsBoost.OptimizeInstance(inst: Instance)
		if not FpsBoost.active or not inst or not inst.Parent then return end
		if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
			or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles")
			or inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
			saveProp(inst, "Enabled")
			pcall(function() (inst :: any).Enabled = false end)
		elseif inst:IsA("Explosion") then
			saveProp(inst, "Visible")
			pcall(function() (inst :: any).Visible = false end)
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			saveProp(inst, "Transparency")
			pcall(function() (inst :: any).Transparency = 1 end)
		elseif inst:IsA("BasePart") then
			saveProp(inst, "Material")
			saveProp(inst, "CastShadow")
			saveProp(inst, "Reflectance")
			pcall(function()
				inst.Material = Enum.Material.SmoothPlastic
				inst.CastShadow = false
				inst.Reflectance = 0
			end)
		elseif inst:IsA("PostEffect") or inst:IsA("Clouds") then
			saveProp(inst, "Enabled")
			pcall(function() (inst :: any).Enabled = false end)
		elseif inst:IsA("Atmosphere") then
			saveProp(inst, "Density")
			pcall(function() (inst :: any).Density = 0 end)
		end
	end

	function FpsBoost.ApplyEnvironment()
		if not FpsBoost.savedLighting then
			local lSave = {}
			for _, prop in ipairs({ "GlobalShadows", "FogEnd", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }) do
				local ok, val = pcall(function() return (Lighting :: any)[prop] end)
				if ok then lSave[prop] = val end
			end
			FpsBoost.savedLighting = lSave
		end
		pcall(function()
			Lighting.GlobalShadows = false
			Lighting.FogEnd = 9e9
			Lighting.EnvironmentDiffuseScale = 0
			Lighting.EnvironmentSpecularScale = 0
		end)
		for _, ch in ipairs(Lighting:GetChildren()) do
			FpsBoost.OptimizeInstance(ch)
		end

		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			if not FpsBoost.savedTerrain then
				local tSave = {}
				for _, prop in ipairs({ "WaterWaveSize", "WaterWaveSpeed", "WaterReflectance", "WaterTransparency" }) do
					local ok, val = pcall(function() return (terrain :: any)[prop] end)
					if ok then tSave[prop] = val end
				end
				FpsBoost.savedTerrain = tSave
			end
			pcall(function()
				terrain.WaterWaveSize = 0
				terrain.WaterWaveSpeed = 0
				terrain.WaterReflectance = 0
				terrain.WaterTransparency = 0
			end)
		end

		pcall(function()
			local rs = settings().Rendering
			if FpsBoost.savedQuality == nil then
				FpsBoost.savedQuality = rs.QualityLevel
			end
			rs.QualityLevel = Enum.QualityLevel.Level01
		end)
	end

	function FpsBoost.ApplyFpsCap()
		local capFn = (ENV and ENV.setfpscap) or setfpscap
		if type(capFn) == "function" then
			local cap = tonumber(Core.Flags.FpsBoostCap) or 0
			pcall(capFn, cap)
			FpsBoost._capApplied = true
		end
	end

	local function formatDuration(sec: number): string
		sec = math.max(0, math.floor(sec))
		local h = sec // 3600
		local m = (sec % 3600) // 60
		local s = sec % 60
		return string.format("%02d:%02d:%02d", h, m, s)
	end

	function FpsBoost.GetFarmingSummary()
		local inBattle = LocalPlayer:GetAttribute("InBattle") == true
		local battleKind = tostring(LocalPlayer:GetAttribute("BattleKind") or "")
		local battleFloor = tonumber(LocalPlayer:GetAttribute("BattleFloor")) or 0
		local inRaid = LocalPlayer:GetAttribute("InRaid") == true
		local pvpSide = LocalPlayer:GetAttribute("PvpSide")

		local activity = "💤 สแตนด์บาย (ยังไม่ได้เปิดโหมดฟาร์ม)"
		if battleKind == "Story" or (Core.Flags.AutoStory and not Helpers.IsBossPlace() and not Helpers.IsRaidPlace()) then
			local ls = type(Loops._lastStory) == "table" and Loops._lastStory or nil
			local world = ls and ls.world or tostring(Core.Flags.StoryWorld or "World_1")
			local act = ls and ls.level or (tonumber(Core.Flags.StoryAct) or 1)
			local diff = ls and ls.difficulty or tostring(Core.Flags.StoryDifficulty or "Easy")
			local stateTxt = inBattle and "กำลังต่อสู้" or "รอเข้าด่าน"
			activity = string.format("🗺️ ฟาร์มเนื้อเรื่อง: %s Act %d (%s) [%s]", tostring(world), tonumber(act) or 1, tostring(diff), stateTxt)
		elseif battleKind == "Dungeon" or Core.Flags.AutoDungeon then
			local dId = tostring(Core.Flags.DungeonId or "ShrineGrounds")
			local endF = tonumber(Core.Flags.DungeonEndFloor) or 10
			local flTxt = battleFloor > 0 and string.format("ชั้น %d/%d", battleFloor, endF) or (inBattle and "กำลังลุย" or "รอเข้าด่าน")
			activity = string.format("🏰 ฟาร์มดันเจียน: %s (%s)", dId, flTxt)
		elseif battleKind == "Raid" or inRaid or Helpers.IsRaidPlace() or Core.Flags.AutoRaid then
			local rDiff = tostring(Core.Flags.RaidDifficulty or "Easy")
			local waveTxt = battleFloor > 0 and ("Wave " .. tostring(battleFloor)) or (inBattle and "กำลังสู้" or "หน้าคิว Raid")
			activity = string.format("🔥 ฟาร์ม Raid: %s (%s)", rDiff, waveTxt)
		elseif battleKind == "Boss" or Helpers.IsBossPlace() or Core.Flags.AutoBoss then
			local bName = tostring(Helpers.BossToday or "Daily Boss")
			local bDiff = tostring(Core.Flags.BossDifficulty or "Easy")
			local st = inBattle and "กำลังสู้บอส" or "หน้าคิว Boss"
			activity = string.format("👹 ฟาร์ม Boss: %s (%s | %s)", bName, bDiff, st)
		elseif battleKind == "Pvp" or pvpSide ~= nil or Core.Flags.AutoPvp then
			local sideTxt = pvpSide and ("Side " .. tostring(pvpSide)) or (inBattle and "กำลังสู้" or "รอคิว")
			activity = string.format("⚔️ ฟาร์ม PvP (%s)", sideTxt)
		elseif Core.Flags.AutoBuyChest or Core.Flags.AutoOpenChest or Core.Flags.AutoBuyShop or Core.Flags.AutoBuyFreeChest then
			local parts = {}
			if Core.Flags.AutoBuyChest then table.insert(parts, "ซื้อกล่อง") end
			if Core.Flags.AutoBuyFreeChest then table.insert(parts, "กล่องฟรี") end
			if Core.Flags.AutoOpenChest then table.insert(parts, "เปิดกล่อง") end
			if Core.Flags.AutoBuyShop then table.insert(parts, "ซื้อร้านค้า") end
			activity = "📦 ฟาร์มล็อบบี้: " .. table.concat(parts, " + ")
		end

		local activeList = {}
		local labels = {
			{ "AutoBuyChest", "ซื้อกล่อง" },
			{ "AutoBuyFreeChest", "กล่องฟรี" },
			{ "AutoOpenChest", "เปิดกล่อง" },
			{ "AutoBuyShop", "ร้านค้า" },
			{ "AutoStory", "เนื้อเรื่อง" },
			{ "AutoDungeon", "ดันเจียน" },
			{ "AutoRaid", "Raid" },
			{ "AutoBoss", "Boss" },
			{ "AutoPvp", "PvP" },
			{ "AutoAscendUnit", "Ascend" },
			{ "AutoSellUnits", "ขายยูนิต" },
			{ "AutoUpgradeSkill", "อัพสกิล" },
			{ "AutoClaimBattlePass", "รับ BP" },
			{ "AutoClaimWeekly", "รับ Weekly" },
		}
		for _, pair in ipairs(labels) do
			if Core.Flags[pair[1]] == true then
				table.insert(activeList, pair[2])
			end
		end

		local ping = 0
		pcall(function()
			ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
		end)

		local cash = Helpers.GetCash()
		local baseCash = Stats.startCash or cash
		local deltaCash = cash - baseCash
		local deltaPrefix = deltaCash >= 0 and "+" or "-"

		local logLines = {}
		for i = 1, math.min(#Stats.logs, 5) do
			local e = Stats.logs[i]
			local col = e.ok and "#7CFC8A" or "#FF7070"
			local clean = e.msg:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
			table.insert(logLines, string.format('<font color="%s">[%s] %s</font> %s', col, e.time, e.cat, clean))
		end

		return {
			activity = activity,
			activeModules = #activeList > 0 and table.concat(activeList, " • ") or "ไม่มีระบบอัตโนมัติที่เปิดอยู่",
			fps = math.max(0, math.floor(FpsBoost.fps + 0.5)),
			ping = ping,
			uptime = formatDuration(os.time() - (Stats.startedAt or os.time())),
			cashText = string.format("¥%s (%s¥%s)", Helpers.Format(cash), deltaPrefix, Helpers.Format(math.abs(deltaCash))),
			chestText = string.format("ซื้อ %d (¥%s) | เปิด %d | ร้าน %d", Stats.bought, Helpers.Format(Stats.spent), Stats.opened, Stats.shopBought),
			runsText = string.format("Story %d | Dgn %d | Raid %d | Boss %d | PvP %d", Stats.storyRuns, Stats.dungeonRuns, Stats.raidRuns, Stats.bossRuns, Stats.pvpRuns),
			currencyText = string.format("Raid: %s | PvP: %s | BP Lv.%d | Ascend: %d",
				Helpers.Format(tonumber(LocalPlayer:GetAttribute("RaidCoins")) or 0),
				Helpers.Format(tonumber(LocalPlayer:GetAttribute("PvpTokens")) or tonumber(LocalPlayer:GetAttribute("PvpCoins")) or 0),
				tonumber(LocalPlayer:GetAttribute("BattlePassLevel")) or 0,
				Stats.ascended),
			logsRich = #logLines > 0 and table.concat(logLines, "\n") or '<font color="#9696A5">ยังไม่มีประวัติการทำงาน</font>',
		}
	end

	function FpsBoost.EnsureOverlay()
		if FpsBoost._gui and FpsBoost._gui.Parent then return end
		local parentGui
		pcall(function() parentGui = gethui and gethui() end)
		if not parentGui then pcall(function() parentGui = game:GetService("CoreGui") end) end
		if not parentGui then parentGui = LocalPlayer:WaitForChild("PlayerGui") end

		local og = Instance.new("ScreenGui")
		og.Name = "KuykuyHub_FpsBoostOverlay"
		og.IgnoreGuiInset = true
		og.ResetOnSpawn = false
		og.DisplayOrder = 900
		og.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		og.Enabled = false
		local okP = pcall(function() og.Parent = parentGui end)
		if not okP then og.Parent = LocalPlayer:WaitForChild("PlayerGui") end
		FpsBoost._gui = og

		local function mk(cls, props, parent)
			local o = Instance.new(cls)
			for k, v in pairs(props) do (o :: any)[k] = v end
			o.Parent = parent
			return o
		end
		local function corner(o, r)
			mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
		end

		local C_DARK, C_CARD, C_PANEL, C_ACC, C_TXT, C_SUB =
			Color3.fromRGB(12, 13, 18), Color3.fromRGB(22, 23, 30), Color3.fromRGB(32, 34, 44),
			Color3.fromRGB(255, 140, 60), Color3.fromRGB(238, 240, 245), Color3.fromRGB(155, 160, 175)

		-- Full-Screen Dark Dashboard (3D OFF mode)
		local full = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C_DARK, BorderSizePixel = 0, Visible = false }, og)
		FpsBoost._fullFrame = full

		local card = mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.92, 0, 0.88, 0),
			BackgroundColor3 = C_CARD,
			BorderSizePixel = 0,
		}, full)
		corner(card, 10)
		mk("UISizeConstraint", { MaxSize = Vector2.new(580, 440), MinSize = Vector2.new(300, 280) }, card)
		mk("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, card)
		mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, card)

		local hdr = mk("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, card)
		mk("TextLabel", { Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1, Text = "⚡ KUYKUY HUB | FPS BOOST", TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, hdr)
		local fullPerf = mk("TextLabel", { Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromScale(0.55, 0), BackgroundTransparency = 1, Text = "FPS: -- | Ping: --ms", TextColor3 = Color3.fromRGB(124, 252, 138), Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right }, hdr)

		local actBox = mk("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, card)
		corner(actBox, 8)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, actBox)
		mk("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "🎯 สถานะการฟาร์มปัจจุบัน (Current Activity)", TextColor3 = C_SUB, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left }, actBox)
		local fullActivity = mk("TextLabel", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 18), BackgroundTransparency = 1, Text = "...", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, actBox)

		local modBox = mk("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, card)
		corner(modBox, 8)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, modBox)
		local fullMods = mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", TextColor3 = C_TXT, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, modBox)

		local statBox = mk("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, card)
		corner(statBox, 8)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, statBox)
		local fullStats = mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", TextColor3 = C_TXT, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, statBox)

		local logBox = mk("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 114), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, card)
		corner(logBox, 8)
		mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, logBox)
		local fullLogs = mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", RichText = true, TextColor3 = C_TXT, Font = Enum.Font.Code, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, logBox)

		local btnRow = mk("Frame", { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 }, card)
		mk("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 1, 0), CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder }, btnRow)
		local btnToggle3D = mk("TextButton", { LayoutOrder = 1, BackgroundColor3 = Color3.fromRGB(55, 85, 130), Text = "👁️ เปิดภาพ 3D (โหมดย่อ)", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 12 }, btnRow)
		corner(btnToggle3D, 6)
		local btnStopBoost = mk("TextButton", { LayoutOrder = 2, BackgroundColor3 = Color3.fromRGB(160, 52, 52), Text = "⏹️ ปิด FPS Boost", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 12 }, btnRow)
		corner(btnStopBoost, 6)

		-- Compact Floating Mini-HUD (Low-Poly 3D ON mode)
		local mini = mk("Frame", {
			Position = UDim2.new(1, -310, 0, 14),
			Size = UDim2.fromOffset(296, 152),
			BackgroundColor3 = C_CARD,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Visible = false,
		}, og)
		corner(mini, 8)
		mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, mini)
		mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, mini)

		local miniPerf = mk("TextLabel", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "⚡ FPS: -- | Ping: --ms", TextColor3 = Color3.fromRGB(124, 252, 138), Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }, mini)
		local miniAct = mk("TextLabel", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "...", TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, mini)
		local miniStats = mk("TextLabel", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Text = "", TextColor3 = C_TXT, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, mini)

		local miniBtns = mk("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 }, mini)
		mk("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 1, 0), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder }, miniBtns)
		local btnMini3DOff = mk("TextButton", { LayoutOrder = 1, BackgroundColor3 = C_PANEL, Text = "🌑 ปิด 3D (จอดำ)", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 11 }, miniBtns)
		corner(btnMini3DOff, 5)
		local btnMiniStop = mk("TextButton", { LayoutOrder = 2, BackgroundColor3 = Color3.fromRGB(160, 52, 52), Text = "⏹️ ปิด Boost", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 11 }, miniBtns)
		corner(btnMiniStop, 5)

		btnToggle3D.MouseButton1Click:Connect(function()
			Config.Set("FpsBoost3DOff", false)
			FpsBoost.Set3DRenderOff(false)
			if Core._syncToggle then Core._syncToggle("FpsBoost3DOff") end
		end)
		btnMini3DOff.MouseButton1Click:Connect(function()
			Config.Set("FpsBoost3DOff", true)
			FpsBoost.Set3DRenderOff(true)
			if Core._syncToggle then Core._syncToggle("FpsBoost3DOff") end
		end)
		local function stopAll()
			Config.Set("FpsBoost", false)
			FpsBoost.Disable()
			if Core._syncToggle then Core._syncToggle("FpsBoost") end
		end
		btnStopBoost.MouseButton1Click:Connect(stopAll)
		btnMiniStop.MouseButton1Click:Connect(stopAll)

		FpsBoost._refs = {
			fullPerf = fullPerf,
			fullActivity = fullActivity,
			fullMods = fullMods,
			fullStats = fullStats,
			fullLogs = fullLogs,
			miniPerf = miniPerf,
			miniAct = miniAct,
			miniStats = miniStats,
		}
	end

	function FpsBoost.UpdateOverlay()
		if not FpsBoost.active or not FpsBoost._gui then return end
		local s = FpsBoost.GetFarmingSummary()
		local r = FpsBoost._refs
		if r.fullPerf then
			r.fullPerf.Text = string.format("FPS: %d | Ping: %dms | %s | 3D: OFF", s.fps, s.ping, s.uptime)
			r.fullActivity.Text = s.activity
			r.fullMods.Text = "⚙️ ระบบที่เปิดอยู่: " .. s.activeModules
			r.fullStats.Text = string.format("💰 เงิน: %s\n📦 กล่อง/ร้าน: %s\n⚔️ รอบที่ลง: %s\n🏅 แต้ม: %s", s.cashText, s.chestText, s.runsText, s.currencyText)
			r.fullLogs.Text = s.logsRich
		end
		if r.miniPerf then
			r.miniPerf.Text = string.format("⚡ FPS: %d | Ping: %dms | %s", s.fps, s.ping, s.uptime)
			r.miniAct.Text = s.activity
			r.miniStats.Text = string.format("💰 %s\n📦 %s\n⚔️ %s", s.cashText, s.chestText, s.runsText)
		end
	end

	function FpsBoost.Set3DRenderOff(off: boolean)
		FpsBoost.render3DOff = off == true
		pcall(function()
			RunService:Set3dRenderingEnabled(not FpsBoost.render3DOff)
		end)
		if FpsBoost._fullFrame and FpsBoost._miniFrame then
			FpsBoost._fullFrame.Visible = FpsBoost.active and FpsBoost.render3DOff
			FpsBoost._miniFrame.Visible = FpsBoost.active and (not FpsBoost.render3DOff)
		end
		FpsBoost.UpdateOverlay()
	end

	function FpsBoost.Enable()
		if FpsBoost.active then return end
		FpsBoost.active = true
		if Stats.startCash == nil then Stats.startCash = Helpers.GetCash() end

		FpsBoost.ApplyEnvironment()
		FpsBoost.ApplyFpsCap()

		if FpsBoost._scanThread then pcall(task.cancel, FpsBoost._scanThread) end
		FpsBoost._scanThread = task.spawn(function()
			local all = Workspace:GetDescendants()
			for i, inst in ipairs(all) do
				if not (Core._alive and FpsBoost.active) then break end
				FpsBoost.OptimizeInstance(inst)
				if i % 250 == 0 then task.wait() end
			end
			FpsBoost._scanThread = nil
		end)

		if FpsBoost._descConn then pcall(function() FpsBoost._descConn:Disconnect() end) end
		FpsBoost._descConn = Workspace.DescendantAdded:Connect(function(desc)
			if not FpsBoost.active then return end
			task.defer(FpsBoost.OptimizeInstance, desc)
		end)

		if FpsBoost._fpsConn then pcall(function() FpsBoost._fpsConn:Disconnect() end) end
		FpsBoost._fpsConn = RunService.RenderStepped:Connect(function(dt)
			if dt > 0 then
				local instFps = 1 / dt
				FpsBoost.fps = (FpsBoost.fps == 0) and instFps or (FpsBoost.fps * 0.85 + instFps * 0.15)
			end
		end)

		FpsBoost.EnsureOverlay()
		if FpsBoost._gui then FpsBoost._gui.Enabled = true end
		FpsBoost.Set3DRenderOff(Core.Flags.FpsBoost3DOff == true)

		if FpsBoost._uiThread then pcall(task.cancel, FpsBoost._uiThread) end
		FpsBoost._uiThread = task.spawn(function()
			while Core._alive and FpsBoost.active do
				pcall(FpsBoost.UpdateOverlay)
				task.wait(0.5)
			end
			FpsBoost._uiThread = nil
		end)

		logAction("FPS", "เปิด Ultimate FPS Boost สำเร็จ" .. (FpsBoost.render3DOff and " (3D OFF)" or " (Low-Poly)"), true)
	end

	function FpsBoost.Disable()
		pcall(function() RunService:Set3dRenderingEnabled(true) end)
		if not FpsBoost.active and not FpsBoost._gui then return end
		local wasActive = FpsBoost.active
		FpsBoost.active = false
		FpsBoost.render3DOff = false

		if FpsBoost._descConn then pcall(function() FpsBoost._descConn:Disconnect() end) FpsBoost._descConn = nil end
		if FpsBoost._fpsConn then pcall(function() FpsBoost._fpsConn:Disconnect() end) FpsBoost._fpsConn = nil end
		if FpsBoost._scanThread then pcall(task.cancel, FpsBoost._scanThread) FpsBoost._scanThread = nil end
		if FpsBoost._uiThread then pcall(task.cancel, FpsBoost._uiThread) FpsBoost._uiThread = nil end

		if FpsBoost.savedLighting then
			for prop, val in pairs(FpsBoost.savedLighting) do
				pcall(function() (Lighting :: any)[prop] = val end)
			end
			FpsBoost.savedLighting = nil
		end
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain and FpsBoost.savedTerrain then
			for prop, val in pairs(FpsBoost.savedTerrain) do
				pcall(function() (terrain :: any)[prop] = val end)
			end
			FpsBoost.savedTerrain = nil
		end
		if FpsBoost.savedQuality ~= nil then
			pcall(function() settings().Rendering.QualityLevel = FpsBoost.savedQuality end)
			FpsBoost.savedQuality = nil
		end
		for inst, props in pairs(FpsBoost.savedProps) do
			if inst and inst.Parent then
				for prop, val in pairs(props) do
					pcall(function() (inst :: any)[prop] = val end)
				end
			end
		end
		table.clear(FpsBoost.savedProps)

		if FpsBoost._capApplied then
			local capFn = (ENV and ENV.setfpscap) or setfpscap
			if type(capFn) == "function" then pcall(capFn, 60) end
			FpsBoost._capApplied = false
		end

		if FpsBoost._gui then
			FpsBoost._gui.Enabled = false
			if FpsBoost._fullFrame then FpsBoost._fullFrame.Visible = false end
			if FpsBoost._miniFrame then FpsBoost._miniFrame.Visible = false end
		end

		if wasActive and Core._alive then
			logAction("FPS", "ปิด Ultimate FPS Boost และคืนค่ากราฟิกแล้ว", true)
		end
	end

	Core._onDestroy = function()
		FpsBoost.Disable()
		if FpsBoost._gui then
			pcall(function() FpsBoost._gui:Destroy() end)
			FpsBoost._gui = nil
		end
	end

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
		gui.DisplayOrder = 1000
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		local okP = pcall(function() gui.Parent = parentGui end)
		if not okP then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
		Core._gui = gui
		UI._toggleRenderers = {}
		function UI.SyncToggle(key)
			if UI._toggleRenderers[key] then UI._toggleRenderers[key]() end
		end
		Core._syncToggle = UI.SyncToggle

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

		local curW, curH = 340, 450
		local minimized, expanded = false, false

		local main = mk("Frame", { Size = UDim2.fromOffset(curW, curH), Position = UDim2.new(0, 40, 0.5, -225), BackgroundColor3 = C_BG, BorderSizePixel = 0, Active = true, ClipsDescendants = true }, gui)
		corner(main, 8)
		local top = mk("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, main)
		corner(top, 8)
		mk("TextLabel", { Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "KUYKUY HUB | Anime Fight", TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, top)
		local btnSize = mk("TextButton", { Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -86, 0, 4), BackgroundColor3 = C_BG, Text = "□", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 13 }, top)
		corner(btnSize, 4)
		local btnMin = mk("TextButton", { Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -58, 0, 4), BackgroundColor3 = C_BG, Text = "-", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 14 }, top)
		corner(btnMin, 4)
		local btnClose = mk("TextButton", { Size = UDim2.fromOffset(26, 22), Position = UDim2.new(1, -30, 0, 4), BackgroundColor3 = Color3.fromRGB(170, 50, 50), Text = "X", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 12 }, top)
		corner(btnClose, 4)

		local contentWrap = mk("Frame", { Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 30), BackgroundTransparency = 1, BorderSizePixel = 0 }, main)
		local tabBar = mk("Frame", { Size = UDim2.new(1, -12, 0, 54), Position = UDim2.fromOffset(6, 4), BackgroundTransparency = 1, BorderSizePixel = 0 }, contentWrap)
		mk("UIGridLayout", { CellSize = UDim2.new(1 / 3, -3, 0, 25), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)

		local pageContainer = mk("Frame", { Size = UDim2.new(1, -12, 1, -120), Position = UDim2.fromOffset(6, 62), BackgroundTransparency = 1, BorderSizePixel = 0 }, contentWrap)
		local statusBar = mk("Frame", { Size = UDim2.new(1, -18, 0, 48), Position = UDim2.new(0, 6, 1, -54), BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, contentWrap)
		corner(statusBar, 6)
		local resizeGrip = mk("TextButton", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -14, 1, -14), BackgroundTransparency = 1, Text = "◢", TextColor3 = C_SUB, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false }, contentWrap)

		local function applyWindowSize(saveIt)
			curW = math.clamp(math.floor(curW), 280, 720)
			curH = math.clamp(math.floor(curH), 260, 700)
			contentWrap.Visible = not minimized
			main.Size = minimized and UDim2.fromOffset(curW, 30) or UDim2.fromOffset(curW, curH)
			btnMin.Text = minimized and "+" or "-"
			btnSize.Text = expanded and "❐" or "□"
			if saveIt then
				Core.Flags.UIWidth = curW
				Core.Flags.UIHeight = curH
				Core.Flags.UIExpanded = expanded
				Config.Save()
			end
		end

		function UI.ApplySavedSize()
			expanded = Core.Flags.UIExpanded == true
			curW = tonumber(Core.Flags.UIWidth) or (expanded and 480 or 340)
			curH = tonumber(Core.Flags.UIHeight) or (expanded and 560 or 450)
			applyWindowSize(false)
		end

		-- drag & resize
		do
			local dragging, dStart, pStart
			local resizing, rStart, sW, sH
			Core:Connect(top.InputBegan, function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					dragging, dStart, pStart = true, i.Position, main.Position
				end
			end)
			Core:Connect(resizeGrip.InputBegan, function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					resizing, rStart, sW, sH = true, i.Position, curW, curH
				end
			end)
			Core:Connect(UserInputService.InputChanged, function(i)
				if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
					if dragging then
						local d = i.Position - dStart
						main.Position = UDim2.new(pStart.X.Scale, pStart.X.Offset + d.X, pStart.Y.Scale, pStart.Y.Offset + d.Y)
					elseif resizing and not minimized then
						local d = i.Position - rStart
						curW = math.clamp(sW + d.X, 280, 720)
						curH = math.clamp(sH + d.Y, 260, 700)
						expanded = (curW >= 440 or curH >= 520)
						main.Size = UDim2.fromOffset(curW, curH)
						btnSize.Text = expanded and "❐" or "□"
					end
				end
			end)
			Core:Connect(UserInputService.InputEnded, function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					dragging = false
					if resizing then
						resizing = false
						applyWindowSize(true)
					end
				end
			end)
		end

		Core:Connect(btnSize.MouseButton1Click, function()
			expanded = not expanded
			minimized = false
			curW = expanded and 480 or 340
			curH = expanded and 560 or 450
			applyWindowSize(true)
		end)
		Core:Connect(btnMin.MouseButton1Click, function()
			minimized = not minimized
			applyWindowSize(false)
		end)
		Core:Connect(btnClose.MouseButton1Click, function() Core:Destroy() end)

		local tabs, tabOrder, activeTabId = {}, 0, nil
		local body = pageContainer
		local order = 0
		local function nextOrder() order += 1 return order end

		function UI.SetTab(id)
			if not tabs[id] then return end
			activeTabId = id
			for k, t in pairs(tabs) do
				local on = (k == id)
				t.page.Visible = on
				t.btn.BackgroundColor3 = on and Color3.fromRGB(90, 55, 25) or C_PANEL
				t.btn.TextColor3 = on and C_ACC or C_SUB
			end
			body = tabs[id].page
		end

		function UI.CreateTab(id, label)
			tabOrder += 1
			local btn = mk("TextButton", { LayoutOrder = tabOrder, BackgroundColor3 = C_PANEL, Text = label, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C_SUB, TextTruncate = Enum.TextTruncate.AtEnd }, tabBar)
			corner(btn, 6)
			local page = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false }, pageContainer)
			mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
			mk("UIPadding", { PaddingRight = UDim.new(0, 4) }, page)
			tabs[id] = { btn = btn, page = page }
			Core:Connect(btn.MouseButton1Click, function()
				UI.SetTab(id)
				Config.Set("ActiveTab", id)
			end)
			body = page
			if not activeTabId then UI.SetTab(id) end
			return page
		end

		function UI.Section(text)
			mk("TextLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = text, TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, body)
		end

		function UI.Button(text, onClick)
			local b = mk("TextButton", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C_PANEL, Text = text, TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = true }, body)
			corner(b, 6)
			Core:Connect(b.MouseButton1Click, function() if onClick then onClick() end end)
			return b
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
			UI._toggleRenderers[key] = render
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
			local btns = {}
			local function renderAll()
				local cur = tostring(Core.Flags.DungeonId or "ShrineGrounds")
				for _, entry in ipairs(btns) do
					local on = (entry.id == cur)
					entry.btn.Text = (on and "● " or "○ ") .. entry.name
					entry.btn.BackgroundColor3 = on and Color3.fromRGB(90, 55, 25) or C_BG
				end
			end
			local function rebuild()
				table.clear(btns)
				for _, ch in ipairs(holder:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
				local dungeons = Helpers.GetDungeons()
				for i, d in ipairs(dungeons) do
					local b = mk("TextButton", { LayoutOrder = i, BackgroundColor3 = C_BG, Text = d.name, AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C_TXT, TextTruncate = Enum.TextTruncate.AtEnd }, holder)
					corner(b, 4)
					table.insert(btns, { id = d.id, name = d.name, btn = b })
					b.MouseButton1Click:Connect(function()
						Config.Set("DungeonId", d.id)
						logAction("CFG", "เลือกระดับดันเจียน: " .. d.name, true)
						renderAll()
					end)
				end
				renderAll()
			end
			UI.RebuildDungeons = rebuild
			rebuild()
		end

		function UI.OptionSelect(key, defaultVal, getOptionsFn, logPrefix, setterName, onSelect)
			local holder = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, body)
			corner(holder, 6)
			mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, holder)
			mk("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 26), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
			local btns = {}
			local function renderAll()
				local cur = tostring(Core.Flags[key] or defaultVal)
				for _, entry in ipairs(btns) do
					local on = (entry.id == cur)
					entry.btn.Text = (on and "● " or "○ ") .. entry.name
					entry.btn.BackgroundColor3 = on and Color3.fromRGB(90, 55, 25) or C_BG
				end
			end
			local function rebuild()
				table.clear(btns)
				for _, ch in ipairs(holder:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
				for i, opt in ipairs(getOptionsFn()) do
					local b = mk("TextButton", { LayoutOrder = i, BackgroundColor3 = C_BG, Text = opt.name, AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C_TXT, TextTruncate = Enum.TextTruncate.AtEnd }, holder)
					corner(b, 4)
					table.insert(btns, { id = opt.id, name = opt.name, btn = b })
					b.MouseButton1Click:Connect(function()
						Config.Set(key, opt.id)
						logAction("CFG", logPrefix .. opt.name, true)
						renderAll()
						if onSelect then onSelect(opt.id) end
					end)
				end
				renderAll()
			end
			UI[setterName] = rebuild
			rebuild()
		end

		function UI.SingleDropdown(titlePrefix, key, defaultVal, getOptionsFn, logPrefix, setterName, onSelect, isNumber)
			local wrap = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 }, body)
			mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, wrap)

			local headerBtn = mk("TextButton", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C_PANEL, Text = "", AutoButtonColor = false }, wrap)
			corner(headerBtn, 6)
			local headerLbl = mk("TextLabel", { Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, headerBtn)
			local arrowLbl = mk("TextLabel", { Size = UDim2.fromOffset(22, 30), Position = UDim2.new(1, -24, 0, 0), BackgroundTransparency = 1, Text = "▼", TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 11 }, headerBtn)

			local dropPanel = mk("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C_PANEL, BorderSizePixel = 0, Visible = false }, wrap)
			corner(dropPanel, 6)
			mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, dropPanel)
			mk("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 26), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, dropPanel)

			local isOpen = false
			local btns = {}

			local function renderAll()
				local cur = tostring(Core.Flags[key] ~= nil and Core.Flags[key] or defaultVal)
				local disp = cur
				for _, entry in ipairs(btns) do
					local on = (entry.id == cur)
					if on then disp = entry.name end
					entry.btn.Text = (on and "● " or "○ ") .. entry.name
					entry.btn.BackgroundColor3 = on and Color3.fromRGB(90, 55, 25) or C_BG
				end
				headerLbl.Text = titlePrefix .. disp
				arrowLbl.Text = isOpen and "▲" or "▼"
				dropPanel.Visible = isOpen
			end

			Core:Connect(headerBtn.MouseButton1Click, function()
				isOpen = not isOpen
				renderAll()
			end)

			local function rebuild()
				table.clear(btns)
				for _, ch in ipairs(dropPanel:GetChildren()) do
					if ch:IsA("TextButton") then ch:Destroy() end
				end
				local opts = getOptionsFn()
				local curStr = tostring(Core.Flags[key] ~= nil and Core.Flags[key] or defaultVal)
				local found = false
				for i, opt in ipairs(opts) do
					local oid = tostring(opt.id)
					if oid == curStr then found = true end
					local b = mk("TextButton", { LayoutOrder = i, BackgroundColor3 = C_BG, Text = opt.name, AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C_TXT, TextTruncate = Enum.TextTruncate.AtEnd }, dropPanel)
					corner(b, 4)
					table.insert(btns, { id = oid, name = opt.name, btn = b })
					b.MouseButton1Click:Connect(function()
						local val = isNumber and (tonumber(oid) or defaultVal) or oid
						Config.Set(key, val)
						isOpen = false
						logAction("CFG", logPrefix .. opt.name, true)
						renderAll()
						if onSelect then onSelect(val) end
					end)
				end
				if not found and #opts > 0 then
					local fallbackId = tostring(opts[1].id)
					local val = isNumber and (tonumber(fallbackId) or defaultVal) or fallbackId
					Core.Flags[key] = val
				end
				renderAll()
			end

			UI[setterName] = rebuild
			rebuild()
		end

		-- dynamic multi-select (rebuilt when map/config tiers change)
		function UI.TierMultiSelect()
			local holder = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, body)
			corner(holder, 6)
			mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, holder)
			mk("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 26), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
			local function rebuild()
				local cfg = Helpers.GetConfig()
				for _, ch in ipairs(holder:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
				for i, tier in ipairs(Helpers.TierList) do
					local mul = ""
					if cfg and type(cfg.Mutations) == "table" and type(cfg.Mutations[tier]) == "table" and cfg.Mutations[tier].PriceMultiplier then
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

		-- collapsible multi-select dropdown for chest rarities (auto-updated in real time)
		function UI.ChestRarityDropdown()
			local wrap = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0 }, body)
			mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, wrap)

			local headerBtn = mk("TextButton", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C_PANEL, Text = "", AutoButtonColor = false }, wrap)
			corner(headerBtn, 6)
			local headerLbl = mk("TextLabel", { Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "", TextColor3 = C_TXT, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, headerBtn)
			local arrowLbl = mk("TextLabel", { Size = UDim2.fromOffset(22, 30), Position = UDim2.new(1, -24, 0, 0), BackgroundTransparency = 1, Text = "▼", TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 11 }, headerBtn)

			local dropPanel = mk("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C_PANEL, BorderSizePixel = 0, Visible = false }, wrap)
			corner(dropPanel, 6)
			mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, dropPanel)
			mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, dropPanel)

			local actionsRow = mk("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 }, dropPanel)
			mk("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 1, 0), CellPadding = UDim2.fromOffset(6, 0), SortOrder = Enum.SortOrder.LayoutOrder }, actionsRow)
			local btnClear = mk("TextButton", { LayoutOrder = 1, BackgroundColor3 = C_BG, Text = "ทั้งหมด (ไม่กรอง)", TextColor3 = C_SUB, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false }, actionsRow)
			corner(btnClear, 4)
			local btnSelectAll = mk("TextButton", { LayoutOrder = 2, BackgroundColor3 = C_BG, Text = "เลือกทุกระดับ", TextColor3 = C_ACC, Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false }, actionsRow)
			corner(btnSelectAll, 4)

			local gridHolder = mk("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, dropPanel)
			mk("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 26), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, gridHolder)

			local isOpen = false
			local renderMap = {}

			local function updateHeader()
				if type(Core.Flags.ChestRarities) ~= "table" then Core.Flags.ChestRarities = {} end
				local selected = {}
				local seenSel = {}
				for _, r in ipairs(Helpers.ChestRarityList) do
					if Core.Flags.ChestRarities[r] == true then
						seenSel[r] = true
						table.insert(selected, r)
					end
				end
				for r, on in pairs(Core.Flags.ChestRarities) do
					if on == true and not seenSel[r] then
						table.insert(selected, tostring(r))
					end
				end
				if #selected == 0 then
					headerLbl.Text = "ระดับกล่อง (Rarity): ทั้งหมด (All)"
				else
					headerLbl.Text = string.format("ระดับกล่อง (%d): %s", #selected, table.concat(selected, ", "))
				end
				arrowLbl.Text = isOpen and "▲" or "▼"
				dropPanel.Visible = isOpen
			end

			Core:Connect(headerBtn.MouseButton1Click, function()
				isOpen = not isOpen
				updateHeader()
			end)

			Core:Connect(btnClear.MouseButton1Click, function()
				Core.Flags.ChestRarities = {}
				Config.Save()
				for _, fn in pairs(renderMap) do fn() end
				updateHeader()
				logAction("CFG", "ระดับกล่อง (Rarity): ทั้งหมด (All)", true)
			end)

			Core:Connect(btnSelectAll.MouseButton1Click, function()
				if type(Core.Flags.ChestRarities) ~= "table" then Core.Flags.ChestRarities = {} end
				for _, r in ipairs(Helpers.ChestRarityList) do
					Core.Flags.ChestRarities[r] = true
				end
				Config.Save()
				for _, fn in pairs(renderMap) do fn() end
				updateHeader()
				logAction("CFG", string.format("เลือกกล่องทุกระดับ (%d ระดับ)", #Helpers.ChestRarityList), true)
			end)

			local function rebuild()
				table.clear(renderMap)
				for _, ch in ipairs(gridHolder:GetChildren()) do
					if ch:IsA("TextButton") then ch:Destroy() end
				end
				if type(Core.Flags.ChestRarities) ~= "table" then Core.Flags.ChestRarities = {} end
				local seen = {}
				local idx = 0
				local function addBtn(rarityName, extraTag)
					idx += 1
					seen[rarityName] = true
					local b = mk("TextButton", { LayoutOrder = idx, BackgroundColor3 = C_BG, Text = "", AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C_TXT, TextTruncate = Enum.TextTruncate.AtEnd }, gridHolder)
					corner(b, 4)
					local function render()
						local on = Core.Flags.ChestRarities[rarityName] == true
						b.Text = (on and "☑ " or "☐ ") .. rarityName .. (extraTag or "")
						b.BackgroundColor3 = on and Color3.fromRGB(90, 55, 25) or C_BG
					end
					renderMap[rarityName] = render
					render()
					b.MouseButton1Click:Connect(function()
						local nextVal = not (Core.Flags.ChestRarities[rarityName] == true)
						Core.Flags.ChestRarities[rarityName] = nextVal and true or nil
						Config.Save()
						render()
						updateHeader()
					end)
				end
				for _, r in ipairs(Helpers.ChestRarityList) do
					addBtn(r, nil)
				end
				for r, on in pairs(Core.Flags.ChestRarities) do
					if on == true and not seen[r] then
						addBtn(tostring(r), " (บันทึกไว้)")
					end
				end
				updateHeader()
			end

			UI.RebuildChestRarities = rebuild
			rebuild()
		end

		function UI.ShopMultiSelect()
			local header = mk("TextLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "สินค้าในร้านปัจจุบัน (อัปเดตเรียลไทม์)", TextColor3 = C_SUB, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, body)
			local holder = mk("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C_PANEL, BorderSizePixel = 0 }, body)
			corner(holder, 6)
			mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, holder)
			mk("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 28), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
			local function updateHeader()
				local shopCfg = Helpers.GetShopConfig()
				local secLeft = nil
				if shopCfg and type(shopCfg.SecondsLeft) == "function" then
					local okT, now = pcall(function() return Workspace:GetServerTimeNow() end)
					local okS, s = pcall(shopCfg.SecondsLeft, (okT and type(now) == "number") and now or os.time())
					if okS and type(s) == "number" then secLeft = math.max(0, math.floor(s)) end
				end
				if secLeft then
					header.Text = string.format("สินค้าในร้าน (%d รายการ | Restock %d:%02d)", #Helpers.ShopOptions, secLeft // 60, secLeft % 60)
				else
					header.Text = string.format("สินค้าในร้าน (%d รายการ)", #Helpers.ShopOptions)
				end
			end
			local function rebuild()
				updateHeader()
				for _, ch in ipairs(holder:GetChildren()) do if ch:IsA("TextButton") then ch:Destroy() end end
				if type(Core.Flags.ShopTargets) ~= "table" then Core.Flags.ShopTargets = {} end
				local seenRef = {}
				local idx = 0
				for _, opt in ipairs(Helpers.ShopOptions) do
					idx += 1
					seenRef[opt.ref] = true
					local refKey = opt.ref
					local stockTxt = opt.remaining <= 0 and "หมด" or (tostring(opt.remaining) .. "/" .. tostring(opt.stock))
					local label = string.format("%s ¥%s [%s]", opt.name, Helpers.Format(opt.price), stockTxt)
					local b = mk("TextButton", { LayoutOrder = idx, BackgroundColor3 = C_BG, Text = "", AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = opt.remaining <= 0 and C_SUB or C_TXT, TextTruncate = Enum.TextTruncate.AtEnd }, holder)
					corner(b, 4)
					local function render()
						local on = Core.Flags.ShopTargets[refKey] == true
						b.Text = (on and "☑ " or "☐ ") .. label
						b.BackgroundColor3 = on and Color3.fromRGB(90, 55, 25) or C_BG
					end
					render()
					b.MouseButton1Click:Connect(function()
						Core.Flags.ShopTargets[refKey] = not (Core.Flags.ShopTargets[refKey] == true)
						if not Core.Flags.ShopTargets[refKey] then Core.Flags.ShopTargets[refKey] = nil end
						Config.Save()
						render()
					end)
				end
				for refKey, isOn in pairs(Core.Flags.ShopTargets) do
					if isOn == true and not seenRef[refKey] then
						idx += 1
						local rk = tostring(refKey)
						local disp = Helpers.GetShopOfferName({ kind = "Material", ref = rk })
						local b = mk("TextButton", { LayoutOrder = idx, BackgroundColor3 = Color3.fromRGB(90, 55, 25), Text = "☑ " .. disp .. " (รอรอบ)", AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C_SUB, TextTruncate = Enum.TextTruncate.AtEnd }, holder)
						corner(b, 4)
						b.MouseButton1Click:Connect(function()
							Core.Flags.ShopTargets[rk] = nil
							Config.Save()
							rebuild()
						end)
					end
				end
			end
			UI.RebuildShopItems = rebuild
			UI.UpdateShopHeader = updateHeader
			Core._rebuildShopUI = rebuild
			rebuild()
		end

		function UI.StatusLabel()
			return mk("TextLabel", { Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1, Text = "", TextColor3 = C_SUB, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, statusBar)
		end

		function UI.LogBox()
			local box = mk("ScrollingFrame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 260), BackgroundColor3 = C_PANEL, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
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
	UI.ApplySavedSize()
	if type(Core.Flags.Tiers) ~= "table" then Core.Flags.Tiers = { Normal = true } end
	if type(Core.Flags.ChestRarities) ~= "table" then Core.Flags.ChestRarities = {} end
	if type(Core.Flags.ShopTargets) ~= "table" then Core.Flags.ShopTargets = {} end
	Helpers.RefreshTiers()
	Helpers.RefreshChestRarities()
	Helpers.RefreshStory()
	Helpers.RefreshDungeons()
	Helpers.RefreshRaids()
	Helpers.RefreshBoss()
	Helpers.RefreshRaritiesAndAscension()
	Helpers.RefreshPvp()
	Helpers.RefreshShop()

	UI.CreateTab("Chest", "📦 กล่อง/ร้าน")
	UI.Section("📦 Auto Buy Chest (สายพานฐานตัวเอง)")
	UI.Toggle("เปิด Auto ซื้อกล่อง", "AutoBuyChest", function(on)
		logAction("CFG", "Auto Buy Chest: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBuy() end
	end)
	UI.Toggle("รับกล่องฟรีช่วงอีเว้นอัตโนมัติ (Free Chest)", "AutoBuyFreeChest", function(on)
		logAction("CFG", "Auto Buy Free Chest: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBuyFree() end
	end)
	UI.AmountInput("ราคาขั้นต่ำ (¥)", "MinPrice")
	UI.Section("ระดับกล่องที่จะซื้อ (ดรอปดาวเลือกได้หลายระดับ)")
	UI.ChestRarityDropdown()
	UI.Section("ประเภทกล่อง / Mutation (เลือกได้หลายอัน)")
	UI.TierMultiSelect()
	UI.Toggle("วาร์ปไปสายพานเมื่ออยู่ไกล", "TeleportToBelt")
	UI.Toggle("วาร์ปกลับจุดเดิมหลังซื้อ", "ReturnAfterBuy")
	UI.Toggle("วางกล่องที่ฐานอัตโนมัติหลังซื้อ", "AutoPlaceChest")
	UI.Toggle("เปิดกล่องอัตโนมัติเมื่อพร้อม", "AutoOpenChest", function(on)
		logAction("CFG", "Auto Open Chest: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoOpen() end
	end)
	UI.Section("🛒 Auto Buy Shop (ร้านค้าหลัก - อัปเดตเรียลไทม์)")
	UI.Toggle("เปิด Auto ซื้อของร้านค้า (Shop)", "AutoBuyShop", function(on)
		logAction("CFG", "Auto Buy Shop: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBuyShop() end
	end)
	UI.Toggle("ซื้อทั้งหมดที่เงินพอ (ไม่สนรายการที่ติ๊ก)", "ShopBuyAll")
	UI.OptionSelect("ShopFilterKind", "All", Helpers.GetShopKindOptions, "หมวดร้านค้า: ", "RebuildShopKinds")
	UI.OptionSelect("ShopMinRarity", "All", Helpers.GetShopRarityOptions, "ระดับขั้นต่ำร้านค้า: ", "RebuildShopRarities")
	UI.ShopMultiSelect()
	UI.Button("🔄 รีเฟรชรายการร้านค้า", function()
		Helpers.InvalidateModules()
		Helpers.RefreshShop()
		if UI.RebuildShopKinds then UI.RebuildShopKinds() end
		if UI.RebuildShopRarities then UI.RebuildShopRarities() end
		if UI.RebuildShopItems then UI.RebuildShopItems() end
		logAction("SHOP", string.format("รีเฟรชร้านค้าแล้ว (%d รายการ)", #Helpers.ShopOptions), true)
	end)

	UI.CreateTab("Story", "🗺️ เนื้อเรื่อง")
	UI.Section("🗺️ Auto Story (ลงด่านโลก 1-7+ อัตโนมัติ)")
	UI.Toggle("เปิด Auto ลงด่านเนื้อเรื่อง (Auto Story)", "AutoStory", function(on)
		logAction("CFG", "Auto Story: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoStory() end
	end)
	UI.SingleDropdown("🌍 โลก (World): ", "StoryWorld", "World_1", Helpers.GetStoryWorlds, "เลือกโลก: ", "RebuildStoryWorlds", function()
		if UI.RebuildStoryActs then UI.RebuildStoryActs() end
	end, false)
	UI.SingleDropdown("📍 ด่าน (Act): ", "StoryAct", 1, function()
		return Helpers.GetStoryActs(Core.Flags.StoryWorld)
	end, "เลือกด่าน: ", "RebuildStoryActs", nil, true)
	UI.Section("🔥 ระดับความยาก (Difficulty)")
	UI.OptionSelect("StoryDifficulty", "Easy", Helpers.GetStoryDifficulties, "ระดับความยากเนื้อเรื่อง: ", "RebuildStoryDiffs")
	UI.Section("⚔️ ควบคุมหลังจบด่าน (Auto Replay / Next)")
	UI.Toggle("เล่นด่านซ้ำอัตโนมัติ (Auto Replay)", "AutoReplay", function(on)
		logAction("CFG", "Auto Replay: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoReplay() end
	end)
	UI.Toggle("เล่นด่านถัดไปอัตโนมัติ (Auto Next Stage)", "AutoNextStage", function(on)
		logAction("CFG", "Auto Next Stage: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoNextStage() end
	end)
	UI.Button("🔄 รีเฟรชรายชื่อโลก/ด่าน (Story)", function()
		Helpers.InvalidateModules()
		Helpers.RefreshStory()
		if UI.RebuildStoryWorlds then UI.RebuildStoryWorlds() end
		if UI.RebuildStoryActs then UI.RebuildStoryActs() end
		if UI.RebuildStoryDiffs then UI.RebuildStoryDiffs() end
		logAction("STORY", string.format("รีเฟรชข้อมูลเนื้อเรื่องแล้ว (%d โลก | %d ระดับ)", #Helpers.StoryWorlds, #Helpers.StoryDifficulties), true)
	end)

	UI.CreateTab("Battle", "🏰 ดันเจียน")
	UI.Section("🏰 Auto Dungeon (ลงดันเจียนวนลูป)")
	UI.Toggle("เปิด Auto ลงดันเจียนวนลูป", "AutoDungeon", function(on)
		logAction("CFG", "Auto Dungeon: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoDungeon() end
	end)
	UI.NumberInput("ชั้นเริ่มต้น (Start Floor)", "DungeonStartFloor", 1)
	UI.NumberInput("จบชั้นที่ (ออกเมื่อพ้นชั้นนี้)", "DungeonEndFloor", 1)
	UI.DungeonSelect()

	UI.CreateTab("Raid", "🔥 Boss/Raid")
	UI.Section("👹 Auto Boss Battles (ต่อสู้บอสอัตโนมัติ)")
	UI.Toggle("วาร์ปเข้าโซน Boss อัตโนมัติ (จากล็อบบี้หลัก)", "AutoTravelBoss", function(on)
		logAction("CFG", "Auto Travel Boss: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoTravelBoss() end
	end)
	UI.Toggle("เปิด Auto สู้บอส (เข้าคิว + กด Play)", "AutoBoss", function(on)
		logAction("CFG", "Auto Boss: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBoss() end
	end)
	UI.OptionSelect("BossDifficulty", "Easy", Helpers.GetBossDifficulties, "ระดับบอส: ", "RebuildBossDiffs")
	UI.NumberInput("จำนวนคนในปาร์ตี้บอส (1-4)", "BossPartySize", 1)
	UI.Toggle("เฉพาะเพื่อน (Boss Friends Only)", "BossFriendsOnly")
	UI.Toggle("กดเริ่มบอสทันทีเมื่ออยู่หน้าคิว (StartNow)", "BossStartNow")
	UI.Toggle("สู้บอสซ้ำอัตโนมัติ (Play Again)", "AutoBossReplay", function(on)
		logAction("CFG", "Auto Boss Replay: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBossReplay() end
	end)
	UI.Toggle("กลับล็อบบี้หลังจบบอส (ถ้าไม่ Replay)", "AutoBossReturn")
	UI.Toggle("ซื้อของร้าน Boss Merchant อัตโนมัติ (ใช้เงิน ¥)", "AutoBuyBossShop", function(on)
		logAction("CFG", "Auto Buy Boss Shop: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBuyBossShop() end
	end)
	UI.OptionSelect("BossShopTarget", "All", Helpers.GetBossShopOptions, "ไอเทม Boss Shop: ", "RebuildBossShop")
	UI.Section("🔥 Auto Raid (ลงเรดอัตโนมัติ)")
	UI.Toggle("วาร์ปเข้าโซน Raid อัตโนมัติ (เมื่อปลดล็อก)", "AutoTravelRaid", function(on)
		logAction("CFG", "Auto Travel Raid: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoTravelRaid() end
	end)
	UI.Toggle("เปิด Auto ลง Raid (เข้าคิว + กด Play)", "AutoRaid", function(on)
		logAction("CFG", "Auto Raid: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoRaid() end
	end)
	UI.OptionSelect("RaidDifficulty", "Easy", Helpers.GetRaidDifficulties, "ระดับ Raid: ", "RebuildRaidDiffs")
	UI.NumberInput("จำนวนคนในปาร์ตี้ (1-4)", "RaidPartySize", 1)
	UI.Toggle("เฉพาะเพื่อน (Friends Only)", "RaidFriendsOnly")
	UI.Toggle("กดเริ่มทันทีเมื่ออยู่หน้าคิว (StartNow)", "RaidStartNow", function(on)
		logAction("CFG", "Raid Start Now: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartRaidStartNow() end
	end)
	UI.Toggle("เล่น Raid ซ้ำอัตโนมัติ (Play Again)", "AutoRaidReplay", function(on)
		logAction("CFG", "Auto Raid Replay: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoRaidReplay() end
	end)
	UI.Toggle("กลับล็อบบี้หลังจบ (ถ้าไม่ Replay)", "AutoRaidReturn", function(on)
		logAction("CFG", "Auto Raid Return: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoRaidReturn() end
	end)
	UI.NumberInput("ออกเข้าใหม่เมื่อถึงเวฟ (0 = ไม่จำกัด)", "RaidEndWave", 0)
	UI.Toggle("ซื้อของร้าน Raid Merchant อัตโนมัติ", "AutoBuyRaidShop", function(on)
		logAction("CFG", "Auto Buy Raid Shop: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBuyRaidShop() end
	end)
	UI.OptionSelect("RaidShopTarget", "All", Helpers.GetRaidShopOptions, "ไอเทม Raid Shop: ", "RebuildRaidShop")

	UI.CreateTab("PvP", "⚡ PvP/อื่นๆ")
	UI.Section("🚀 Ultimate FPS Boost (บูส FPS + โชว์สถิติฟาร์ม)")
	UI.Toggle("กันหลุด AFK อัตโนมัติ (Anti-AFK 20 นาที)", "AntiAfk", function(on)
		logAction("CFG", "Anti-AFK: " .. (on and "ON" or "OFF"), on)
	end)
	UI.Toggle("เปิด Ultimate FPS Boost + โชว์สถิติ", "FpsBoost", function(on)
		if on then FpsBoost.Enable() else FpsBoost.Disable() end
	end)
	UI.Toggle("ปิดการเรนเดอร์ 3D (จอดำประหยัดเครื่องสุดยอด)", "FpsBoost3DOff", function(on)
		logAction("CFG", "FPS Boost 3D Off: " .. (on and "ON" or "OFF"), on)
		if FpsBoost.active then FpsBoost.Set3DRenderOff(on) end
	end)
	UI.OptionSelect("FpsBoostCap", "0", FpsBoost.GetCapOptions, "จำกัด FPS: ", "RebuildFpsCap", function()
		if FpsBoost.active then FpsBoost.ApplyFpsCap() end
	end)
	UI.Section("✨ ตัวละครระดับใหม่ (Ascension / Godly)")
	UI.Toggle("อัปขั้นตัวละคร Ascend อัตโนมัติ (5★ + วัตถุดิบครบ)", "AutoAscendUnit", function(on)
		logAction("CFG", "Auto Ascend Unit: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoAscend() end
	end)
	UI.Section("🗑️ ขายตัวละครอัตโนมัติ (Sell Units)")
	UI.OptionSelect("SellUnitMaxRarity", "Epic", Helpers.GetUnitSellRarityOptions, "ขายระดับ: ", "RebuildSellUnitRarities")
	UI.Toggle("ขายตัวละครขยะอัตโนมัติ (ข้ามล็อก/ในทีม)", "AutoSellUnits", function(on)
		logAction("CFG", "Auto Sell Units: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoSellUnits() end
	end)
	UI.Button("🗑️ ขายตัวละครตามระดับที่เลือกทันที", function()
		task.spawn(function()
			Loops.SellTrashUnits(Core.Flags.SellUnitMaxRarity, false)
		end)
	end)
	UI.Section("🎁 รางวัลอัปเดต (Battle Pass / Weekly)")
	UI.Toggle("รับรางวัล + รีเซ็ต Battle Pass อัตโนมัติ (ClaimAll / Reset)", "AutoClaimBattlePass", function(on)
		logAction("CFG", "Auto Claim Battle Pass: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoClaimBattlePass() end
	end)
	UI.Toggle("รับรางวัลอันดับประจำสัปดาห์ (Weekly Rewards)", "AutoClaimWeekly", function(on)
		logAction("CFG", "Auto Claim Weekly: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoClaimWeekly() end
	end)
	UI.Section("⚔️ Auto PvP (ลง PvP อัตโนมัติ - Real-Time)")
	UI.Toggle("วาร์ปเข้าโซน PvP อัตโนมัติ (เมื่อปลดล็อก)", "AutoTravelPvp", function(on)
		logAction("CFG", "Auto Travel PvP: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoTravelPvp() end
	end)
	UI.Toggle("เปิด Auto ลง PvP (คิว + ต่อสู้)", "AutoPvp", function(on)
		logAction("CFG", "Auto PvP: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoPvp() end
	end)
	UI.Toggle("เล่น PvP ซ้ำอัตโนมัติ (Replay)", "AutoPvpReplay")
	UI.Toggle("ซื้อของร้าน PvP Shop อัตโนมัติ", "AutoBuyPvpShop", function(on)
		logAction("CFG", "Auto Buy PvP Shop: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoBuyPvpShop() end
	end)
	UI.Section("🌟 Skill Tree")
	UI.Toggle("อัปเกรดทักษะอัตโนมัติ (เมื่อตังค์พร้อม)", "AutoUpgradeSkill", function(on)
		logAction("CFG", "Auto Upgrade Skill: " .. (on and "ON" or "OFF"), on)
		if on then Loops.StartAutoUpgradeSkill() end
	end)

	UI.CreateTab("Logs", "📜 Logs")
	UI.Section("📜 ประวัติการทำงาน (Logs)")
	UI.Button("🗑️ ล้าง Logs", function()
		table.clear(Stats.logs)
		if Core._updateLogUI then pcall(Core._updateLogUI) end
	end)
	UI.LogBox()

	UI.SetTab(Core.Flags.ActiveTab or "Chest")
	local status = UI.StatusLabel()

	-- real-time: map / config / assets auto-update watchers
	local function syncMapData(reason: string?)
		if not Core._alive then return end
		if Helpers.RefreshTiers() and UI.RebuildTiers then
			UI.RebuildTiers()
			logAction("MAP", reason or "อัปเดตรายการระดับกล่องตามแมพ", true)
		end
		if Helpers.RefreshChestRarities() and UI.RebuildChestRarities then
			UI.RebuildChestRarities()
			logAction("MAP", reason or "อัปเดตรายการระดับกล่อง (Rarity) ตามแมพ", true)
		end
		if Helpers.RefreshStory() then
			if UI.RebuildStoryWorlds then UI.RebuildStoryWorlds() end
			if UI.RebuildStoryActs then UI.RebuildStoryActs() end
			if UI.RebuildStoryDiffs then UI.RebuildStoryDiffs() end
			logAction("MAP", reason or string.format("อัปเดตด่านเนื้อเรื่องตามแมพ (%d โลก | %d ระดับ)", #Helpers.StoryWorlds, #Helpers.StoryDifficulties), true)
		end
		if Helpers.RefreshDungeons() and UI.RebuildDungeons then
			UI.RebuildDungeons()
			logAction("MAP", reason or "อัปเดตรายชื่อดันเจียนตามแมพ", true)
		end
		if Helpers.RefreshRaids() then
			if UI.RebuildRaidDiffs then UI.RebuildRaidDiffs() end
			if UI.RebuildRaidShop then UI.RebuildRaidShop() end
			logAction("MAP", reason or "อัปเดตข้อมูล Raid (ความยาก/ร้านค้า) ตามแมพ", true)
		end
		if Helpers.RefreshBoss() then
			if UI.RebuildBossDiffs then UI.RebuildBossDiffs() end
			if UI.RebuildBossShop then UI.RebuildBossShop() end
			logAction("MAP", reason or ("อัปเดตข้อมูล Boss: " .. tostring(Helpers.BossToday or "-")), true)
		end
		if Helpers.RefreshRaritiesAndAscension() then
			if UI.RebuildShopRarities then UI.RebuildShopRarities() end
			if UI.RebuildSellUnitRarities then UI.RebuildSellUnitRarities() end
			logAction("MAP", reason or string.format("อัปเดตระดับยูนิต (%d ระดับ) / Ascend (%d สาย)", #Helpers.RarityOrder, #Helpers.AscensionPaths), true)
		end
		if Helpers.RefreshPvp() then
			logAction("MAP", reason or "อัปเดตข้อมูล PvP ตามแมพ", true)
		end
		if Helpers.RefreshShop() then
			if UI.RebuildShopKinds then UI.RebuildShopKinds() end
			if UI.RebuildShopRarities then UI.RebuildShopRarities() end
			if UI.RebuildShopItems then UI.RebuildShopItems() end
			logAction("SHOP", reason or string.format("อัปเดตรายการร้านค้าเรียลไทม์ (%d รายการ)", #Helpers.ShopOptions), true)
		elseif UI.UpdateShopHeader then
			pcall(UI.UpdateShopHeader)
		end
	end

	local function hookPlotsFolder()
		local function hookPlot(p)
			local ac = p:WaitForChild("ActiveChests", 10)
			if not (ac and Core._alive) then return end
			Core:Connect(ac.ChildAdded, function(c)
				task.defer(function()
					if not Core._alive then return end
					if c:IsA("Model") then
						local t = Helpers.ChestTier(c)
						if not table.find(Helpers.TierList, t) then
							syncMapData("พบระดับ Mutation กล่องใหม่: " .. t)
						end
						local r = Helpers.ChestRarity(c)
						if r and not table.find(Helpers.ChestRarityList, r) then
							syncMapData("พบระดับกล่อง (Rarity) ใหม่: " .. r)
						end
					end
				end)
			end)
		end
		local function bindPlots(plots)
			for _, p in ipairs(plots:GetChildren()) do task.spawn(hookPlot, p) end
			Core:Connect(plots.ChildAdded, function(p) task.spawn(hookPlot, p) end)
		end
		local function bindLobby(lobby)
			local plots = lobby:FindFirstChild("Plots")
			if plots then bindPlots(plots) end
			Core:Connect(lobby.ChildAdded, function(ch)
				if ch.Name == "Plots" then bindPlots(ch) end
			end)
		end
		local lobby = Workspace:FindFirstChild("Lobby")
		if lobby then bindLobby(lobby) end
		Core:Connect(Workspace.ChildAdded, function(ch)
			if ch.Name == "Lobby" then bindLobby(ch) end
		end)
	end
	task.spawn(hookPlotsFolder)

	task.spawn(function()
		local mods = ReplicatedStorage:FindFirstChild("Modules") or ReplicatedStorage:WaitForChild("Modules", 5)
		if mods and Core._alive then
			local function onModChange(desc)
				if desc:IsA("ModuleScript") then
					Helpers.InvalidateModules()
					task.defer(syncMapData, "ตรวจพบอัปเดตโมดูลแมพ: " .. desc.Name)
				end
			end
			Core:Connect(mods.DescendantAdded, onModChange)
			Core:Connect(mods.DescendantRemoving, onModChange)
		end
		local assets = ReplicatedStorage:FindFirstChild("Assets") or ReplicatedStorage:WaitForChild("Assets", 5)
		local chests = assets and (assets:FindFirstChild("Chests") or assets:WaitForChild("Chests", 5))
		if chests and Core._alive then
			Core:Connect(chests.ChildAdded, function()
				table.clear(Helpers._chestTemplates)
				task.defer(syncMapData, "พบกล่องใหม่ใน Assets")
			end)
		end
		local units = assets and (assets:FindFirstChild("Units") or assets:WaitForChild("Units", 5))
		if units and Core._alive then
			local function onUnitChange()
				Helpers.InvalidateModules()
				task.defer(syncMapData, "ตรวจพบอัปเดตยูนิตใน Assets")
			end
			Core:Connect(units.ChildAdded, onUnitChange)
			Core:Connect(units.ChildRemoved, onUnitChange)
		end
		local function bindStoryMode(sm)
			if not (sm and Core._alive) then return end
			local function onStoryChange(ch)
				Helpers.InvalidateModules()
				task.defer(syncMapData, "ตรวจพบอัปเดตโลกเนื้อเรื่อง: " .. ch.Name)
			end
			Core:Connect(sm.ChildAdded, onStoryChange)
			Core:Connect(sm.ChildRemoved, onStoryChange)
		end
		local storyMode = Workspace:FindFirstChild("Story_Mode")
		if storyMode then bindStoryMode(storyMode) end
		Core:Connect(Workspace.ChildAdded, function(ch)
			if ch.Name == "Story_Mode" then bindStoryMode(ch) end
		end)
	end)

	Core:Connect(LocalPlayer:GetAttributeChangedSignal("PlotId"), function() Helpers._plot = nil end)
	Core:Connect(LocalPlayer:GetAttributeChangedSignal("RaidLocked"), function()
		if LocalPlayer:GetAttribute("RaidLocked") ~= true then
			logAction("RAID", "ปลดล็อกโซน Raid แล้ว", true)
			if Core.Flags.AutoTravelRaid then Loops.StartAutoTravelRaid() end
		end
	end)
	Core:Connect(LocalPlayer:GetAttributeChangedSignal("PvpLocked"), function()
		if LocalPlayer:GetAttribute("PvpLocked") ~= true then
			logAction("PVP", "ปลดล็อกโซน PvP แล้ว", true)
			if Core.Flags.AutoTravelPvp then Loops.StartAutoTravelPvp() end
		end
	end)
	Core:Connect(LocalPlayer:GetAttributeChangedSignal("BattlePassClaimable"), function()
		if Core.Flags.AutoClaimBattlePass and (tonumber(LocalPlayer:GetAttribute("BattlePassClaimable")) or 0) > 0 then
			task.defer(Loops.AutoClaimBattlePassTick)
		end
	end)
	Core:Connect(LocalPlayer:GetAttributeChangedSignal("BattlePassLevel"), function()
		if Core.Flags.AutoClaimBattlePass then
			local bpCfg = Helpers.GetBattlePassConfig()
			local maxLevel = tonumber(bpCfg and bpCfg.MaxLevel) or 50
			if (tonumber(LocalPlayer:GetAttribute("BattlePassLevel")) or 0) >= maxLevel then
				task.defer(Loops.AutoClaimBattlePassTick)
			end
		end
	end)

	task.spawn(function()
		while Core._alive do
			syncMapData()
			local plot = Helpers.GetPlot()
			pcall(function()
				local modeLine
				if Helpers.IsBossPlace() then
					local bossState = (LocalPlayer:GetAttribute("InBattle") == true and "Fighting") or (Helpers.RaidQueueState and Helpers.RaidQueueState.state or "Lobby")
					modeLine = string.format("Boss: %s (%s) | BP Lv.%d", tostring(Helpers.BossToday or "-"), bossState, tonumber(LocalPlayer:GetAttribute("BattlePassLevel")) or 0)
				else
					local raidTokens = tonumber(LocalPlayer:GetAttribute("RaidCoins")) or 0
					local raidState = (LocalPlayer:GetAttribute("BattleKind") == "Raid" and ("Wave " .. tostring(LocalPlayer:GetAttribute("BattleFloor") or 0))) or (LocalPlayer:GetAttribute("RaidLocked") == true and "Locked" or "Ready")
					local pvpState = (LocalPlayer:GetAttribute("PvpSide") and ("Side " .. tostring(LocalPlayer:GetAttribute("PvpSide")))) or (LocalPlayer:GetAttribute("PvpLocked") == true and "Locked" or "Ready")
					modeLine = string.format("Raid: %s (%s Tokens) | PvP: %s", raidState, Helpers.Format(raidTokens), pvpState)
				end
				status.Size = UDim2.new(1, 0, 0, 48)
				status.Text = string.format("  Plot: %s | เงิน: ¥%s | ขั้นต่ำ: ¥%s\n  ซื้อ: %d กล่อง | ใช้: ¥%s\n  %s",
					plot and plot.Name or "-", Helpers.Format(Helpers.GetCash()), Helpers.Format(tonumber(Core.Flags.MinPrice) or 0),
					Stats.bought, Helpers.Format(Stats.spent), modeLine)
			end)
			task.wait(1)
		end
	end)

	Loops.StartAutoBuy()
	Loops.StartAutoBuyFree()
	Loops.StartAutoBuyShop()
	Loops.StartAutoOpen()
	Loops.StartAutoStory()
	Loops.StartAutoReplay()
	Loops.StartAutoNextStage()
	Loops.StartAutoDungeon()
	Loops.StartAutoTravelRaid()
	Loops.StartAutoRaid()
	Loops.StartRaidStartNow()
	Loops.StartAutoRaidReplay()
	Loops.StartAutoRaidReturn()
	Loops.StartAutoBuyRaidShop()
	Loops.StartAutoTravelBoss()
	Loops.StartAutoBoss()
	Loops.StartAutoBossReplay()
	Loops.StartAutoBuyBossShop()
	Loops.StartAutoAscend()
	Loops.StartAutoSellUnits()
	Loops.StartAutoClaimBattlePass()
	Loops.StartAutoClaimWeekly()
	Loops.StartAutoTravelPvp()
	Loops.StartAutoPvp()
	Loops.StartAutoBuyPvpShop()
	Loops.StartAutoUpgradeSkill()
	Loops.InitAntiAfk()
	if Core.Flags.FpsBoost then FpsBoost.Enable() end
	logAction("SYS", "โหลดสคริปต์สำเร็จ | Config: " .. Config.File, true)
end

local ok, err = pcall(main)
if not ok then
	warn("[KUYKUY HUB] Boot error: " .. tostring(err))
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "KUYKUY HUB | Boot Error",
			Text = tostring(err),
			Duration = 8,
		})
	end)
end
