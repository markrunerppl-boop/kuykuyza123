--[[
    ========================================================================
    [KUYKUY HUB - UNIVERSAL MODULAR LOADER]
    Repository: markrunerppl-boop/kuykuyza123
    Architecture: PlaceId & GameId Routing | Safe Execution | Category Organization
    ========================================================================
--]]

local PlaceId = game.PlaceId
local GameId = game.GameId
local BaseUrl = "https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/games/"

-- ฟังก์ชันแจ้งเตือน (Roblox Notification + F9 Console)
local function Log(title, msg, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "⚡ " .. title,
            Text = msg,
            Duration = duration or 4
        })
    end)
    print(string.format("[%s] %s", title, msg))
end

-- ========================================================================
-- 📌 ฐานข้อมูลรายชื่อแมพ (GAME REGISTRY)
-- วิธีเพิ่มแมพใหม่: ใส่ PlaceId หรือ GameId, ชื่อเกม, หมวดหมู่ และ Path ไฟล์
-- ========================================================================
local SupportedGames = {

    -- --------------------------------------------------------------------
    -- 🥊 1. หมวด ANIME GAMES (เกมอนิเมะ)
    -- --------------------------------------------------------------------
    -- แมพ: Chakra Training Simulator
    [97617452700163] = {
        Name = "Chakra Training Simulator",
        Category = "Anime",
        Path = "chakra_simulator/main.lua"
    },

    -- แมพ: เหมืองอนิเมะของฉัน (My Anime Mine)
    [79389059854988] = {
        Name = "เหมืองอนิเมะของฉัน (Anime Mine)",
        Category = "Anime",
        Path = "anime/anime_mine.lua"
    },

    -- แมพ: ดันเจี้ยนลุกขึ้น (Dungeon Rise / QA Hub Test)
    [128336380114944] = {
        Name = "ดันเจี้ยนลุกขึ้น (QA Hub)",
        Category = "Anime",
        Path = "chakra_simulator/main.lua"
    },

    -- แมพ: Blox Fruits (ตัวอย่าง)
    [2753915549] = {
        Name = "Blox Fruits (Sea 1)",
        Category = "Anime",
        Path = "anime/blox_fruits.lua"
    },
    [4442272183] = {
        Name = "Blox Fruits (Sea 2)",
        Category = "Anime",
        Path = "anime/blox_fruits.lua"
    },
    [7449423635] = {
        Name = "Blox Fruits (Sea 3)",
        Category = "Anime",
        Path = "anime/blox_fruits.lua"
    },

    -- --------------------------------------------------------------------
    -- 🏋️ 2. หมวด SIMULATOR (เกมจำลอง/ฟาร์มพลัง)
    -- --------------------------------------------------------------------
    [13127800756] = {
        Name = "Arm Wrestle Simulator",
        Category = "Simulator",
        Path = "simulator/arm_wrestle.lua"
    },
    [8737899170] = {
        Name = "Pet Simulator 99",
        Category = "Simulator",
        Path = "simulator/pet_simulator.lua"
    },

    -- --------------------------------------------------------------------
    -- 🌐 3. หมวด GENERAL / OTHER (เกมอื่นๆ)
    -- --------------------------------------------------------------------
}

-- ฐานข้อมูลสำรองตาม GameId (Universe ID) เผื่อกรณีแมพมีห้องย่อย/วาป
local SupportedUniverses = {
    [10740316645] = {
        Name = "เหมืองอนิเมะของฉัน (Anime Mine)",
        Category = "Anime",
        Path = "anime/anime_mine.lua"
    },
    [7074860883] = {
        Name = "ดันเจี้ยนลุกขึ้น (QA Hub)",
        Category = "Anime",
        Path = "chakra_simulator/main.lua"
    }
}

-- ========================================================================
-- 🚀 LOADER ENGINE (ดาวน์โหลดและสั่งรัน)
-- ========================================================================
local gameInfo = SupportedGames[PlaceId] or SupportedUniverses[GameId]

if gameInfo then
    Log("KuyKuy Hub", string.format("ตรวจพบ: %s [%s]", gameInfo.Name, gameInfo.Category), 3)
    
    -- ป้องกัน GitHub Cache โดยการใส่ Timestamp เพื่อให้โค้ดอัปเดตสดใหม่ตลอดเวลา
    local fullUrl = BaseUrl .. gameInfo.Path .. "?nocache=" .. tostring(os.time())
    
    local fetchSuccess, scriptSource = pcall(function()
        return game:HttpGet(fullUrl)
    end)

    if fetchSuccess and scriptSource and #scriptSource > 20 then
        local runSuccess, runError = pcall(function()
            local fn = loadstring(scriptSource)
            if fn then fn() else error("Syntax error in script") end
        end)

        if runSuccess then
            Log("KuyKuy Hub", "โหลดสคริปต์ " .. gameInfo.Name .. " สำเร็จ!", 3)
        else
            Log("Runtime Error", "เกิดข้อผิดพลาดในการรันสคริปต์: " .. tostring(runError), 7)
            warn("[KuyKuy Hub Error]:", runError)
        end
    else
        Log("Fetch Failed", "ไม่สามารถดาวน์โหลดไฟล์จาก GitHub ได้! ตรวจสอบชื่อ Path: " .. gameInfo.Path, 6)
    end
else
    -- กรณีเข้าแมพที่ยังไม่ได้ใส่ในลิสต์
    Log("Unsupported Map", string.format("แมพนี้ยังไม่รองรับในระบบ\nPlaceId: %s | GameId: %s", tostring(PlaceId), tostring(GameId)), 5)
    warn("[KuyKuy Hub] Unknown Game -> PlaceId:", PlaceId, "GameId:", GameId)
end
