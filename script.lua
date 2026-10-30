--[[
    ========================================================================
    [KUYKUY HUB - UNIVERSAL MODULAR LOADER]
    Repository: markrunerppl-boop/kuykuyza123
    Architecture: PlaceId Routing | Safe Execution | Category Organization
    ========================================================================
--]]

local PlaceId = game.PlaceId
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
-- วิธีเพิ่มแมพใหม่: ใส่ PlaceId, ชื่อเกม, หมวดหมู่ และ Path ไฟล์ตามตัวอย่าง
-- ========================================================================
local SupportedGames = {

    -- --------------------------------------------------------------------
    -- 🥊 1. หมวด ANIME GAMES (เกมอนิเมะ)
    -- --------------------------------------------------------------------
    [97617452700163] = {
        Name = "Chakra Training Simulator",
        Category = "Anime",
        Path = "anime/chakra_simulator.lua"
    },
    -- แมพอื่นๆ ในอนาคต
    -- [PlaceId] = {
    --     Name = "เหมืองอนิเมะของฉัน (Anime Mine)",
    --     Category = "Anime",
    --     Path = "anime/anime_mine.lua"
    -- },

    -- --------------------------------------------------------------------
    -- 🏋️ 2. หมวด SIMULATOR (เกมจำลอง/ฟาร์มพลัง)
    -- --------------------------------------------------------------------
    -- [PlaceId] = {
    --     Name = "ชื่อเกม Simulator",
    --     Category = "Simulator",
    --     Path = "simulator/example.lua"
    -- },

    -- --------------------------------------------------------------------
    -- 🌐 3. หมวด GENERAL / OTHER (เกมอื่นๆ)
    -- --------------------------------------------------------------------
}

-- ========================================================================
-- 🚀 LOADER ENGINE (ดาวน์โหลดและสั่งรัน)
-- ========================================================================
local gameInfo = SupportedGames[PlaceId]

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
            Log("KuyKuy Hub", "โหลดสคริปต์สำเร็จ! ขอให้สนุกกับการเล่น", 3)
        else
            Log("Runtime Error", "เกิดข้อผิดพลาดในการรันสคริปต์: " .. tostring(runError), 7)
            warn("[KuyKuy Hub Error]:", runError)
        end
    else
        Log("Fetch Failed", "ไม่สามารถดาวน์โหลดไฟล์จาก GitHub ได้! ตรวจสอบชื่อ Path: " .. gameInfo.Path, 6)
    end
else
    -- กรณีเข้าแมพที่ยังไม่ได้ใส่ในลิสต์
    Log("Unsupported Map", "แมพนี้ยังไม่รองรับในระบบ\nPlaceId: " .. tostring(PlaceId), 5)
    warn("[KuyKuy Hub] PlaceId not found:", PlaceId)
end
