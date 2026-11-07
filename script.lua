--[[
    ========================================================================
    [KUYKUY HUB - UNIVERSAL MODULAR LOADER]
    Repository: markrunerppl-boop/kuykuyza123
    Architecture: PlaceId & GameId Routing | Safe Execution | Category Organization
    Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/script.lua"))()
    ========================================================================
--]]

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
-- ========================================================================
local SupportedGames = {

    -- --------------------------------------------------------------------
    -- ⚔️ 1. การผจญภัยอนิเมะ (Anime Adventures)
    -- --------------------------------------------------------------------
    [8304191830] = {
        Name = "การผจญภัยอนิเมะ (Anime Adventures)",
        Category = "Tower Defense / QA",
        Path = "anime_adventures/main.lua"
    },

    -- --------------------------------------------------------------------
    -- ⛏️ 2. เหมืองอนิเมะของฉัน (My Anime Mine)
    -- --------------------------------------------------------------------
    [79389059854988] = {
        Name = "เหมืองอนิเมะของฉัน (Anime Mine)",
        Category = "Anime",
        Path = "anime/anime_mine.lua"
    },

    -- --------------------------------------------------------------------
    -- 🥊 3. Chakra Training Simulator
    -- --------------------------------------------------------------------
    [97617452700163] = {
        Name = "Chakra Training Simulator",
        Category = "Anime",
        Path = "chakra_simulator/main.lua"
    },

    -- --------------------------------------------------------------------
    -- 🏰 4. ดันเจี้ยนลุกขึ้น (Dungeon Rise / Solo Leveling)
    -- --------------------------------------------------------------------
    [128336380114944] = {
        Name = "ดันเจี้ยนลุกขึ้น (Dungeon Rise)",
        Category = "Anime / Action",
        Path = "dungeon_rise/main.lua"
    },

    -- --------------------------------------------------------------------
    -- 🍉 5. Blox Fruits
    -- --------------------------------------------------------------------
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
    -- 🏋️ 6. หมวด SIMULATOR
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
    -- 🐟 7. จับปลา! (Catch Fish)
    -- --------------------------------------------------------------------
    [93898234979111] = {
        Name = "[🐟] จับปลา! (Catch Fish)",
        Category = "Fishing / Simulator",
        Path = "fishing/main.lua"
    },
}

-- ฐานข้อมูลสำรองตาม GameId (Universe ID) เผื่อกรณีแมพมีห้องย่อย/ดันเจี้ยน/วาป
local SupportedUniverses = {
    [3183403065] = {
        Name = "การผจญภัยอนิเมะ (Anime Adventures)",
        Category = "Tower Defense / QA",
        Path = "anime_adventures/main.lua"
    },
    [10740316645] = {
        Name = "เหมืองอนิเมะของฉัน (Anime Mine)",
        Category = "Anime",
        Path = "anime/anime_mine.lua"
    },
    [7074860883] = {
        Name = "ดันเจี้ยนลุกขึ้น (Dungeon Rise)",
        Category = "Anime / Action",
        Path = "dungeon_rise/main.lua"
    },
    [10771053183] = {
        Name = "[🐟] จับปลา! (Catch Fish)",
        Category = "Fishing / Simulator",
        Path = "fishing/main.lua"
    }
}

-- ========================================================================
-- 🚀 LOADER ENGINE (ดาวน์โหลดและสั่งรันแบบปลอดภัยสูงสุด)
-- ========================================================================
task.spawn(function()
    -- 1. รอเกมโหลดเสร็จสมบูรณ์ + ป้องกันการแย่ง CPU เธรดตอนโหลด
    if not game:IsLoaded() then
        pcall(function() game.Loaded:Wait() end)
    end
    task.wait(1.5) -- หน่วงเวลาสั้นๆ เพื่อให้ ReplicatedFirst และ Data Init เริ่มต้นอย่างปลอดภัย

    -- 🛡️ ระบบเฝ้าระวังและกระตุ้นการเข้าเกมอัตโนมัติ (Auto-Click Start & Restore Camera)
    task.spawn(function()
        local watchStart = os.clock()
        while (os.clock() - watchStart < 25) do
            task.wait(0.5)
            pcall(function()
                local lp = game:GetService("Players").LocalPlayer
                local pGui = lp and lp:FindFirstChild("PlayerGui")
                local ls = pGui and pGui:FindFirstChild("LoadingScreen")

                -- หากตัวเกมมีปุ่ม ContinueButton หรือหน้าจอโหลดค้าง ให้ส่งสัญญาณคลิกเริ่มเกม
                if ls and ls.Enabled then
                    local cb = ls:FindFirstChild("ContinueButton", true)
                    if cb and getconnections then
                        for _, conn in ipairs(getconnections(cb.MouseButton1Down)) do
                            conn:Fire()
                        end
                        for _, conn in ipairs(getconnections(cb.MouseButton1Click)) do
                            conn:Fire()
                        end
                    end
                    -- ส่งสัญญาณคลิกจำลองเพื่อกระตุ้น UserInputService.InputBegan ในตัวโหลดของเกม
                    local vu = game:GetService("VirtualUser")
                    if vu then
                        vu:Button1Down(Vector2.new(200, 200))
                        task.wait(0.05)
                        vu:Button1Up(Vector2.new(200, 200))
                    end
                end

                -- หากกล้องยังค้างอยู่ในโหมดชมวิว (Scriptable) ให้คืนค่ากล้องกลับมาที่ตัวละคร
                local cam = workspace.CurrentCamera
                local char = lp and lp.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if cam and cam.CameraType == Enum.CameraType.Scriptable and hum then
                    local mineGui = pGui and pGui:FindFirstChild("MineGui")
                    if mineGui and mineGui.Enabled then
                        cam.CameraType = Enum.CameraType.Custom
                        cam.CameraSubject = hum
                    end
                end
            end)
        end
    end)

    -- 2. รอ PlaceId และ GameId ให้พร้อมใช้งาน
    local startWait = os.clock()
    while (not game.PlaceId or game.PlaceId == 0) and (os.clock() - startWait < 8) do
        task.wait(0.5)
    end

    local placeId = tonumber(game.PlaceId) or 0
    local gameId = tonumber(game.GameId) or 0

    -- ค้นหาข้อมูลแมพ (ทั้งแบบ Number และ String หรือ Universe)
    local gameInfo = SupportedGames[placeId] 
        or SupportedGames[tostring(placeId)] 
        or SupportedUniverses[gameId] 
        or SupportedUniverses[tostring(gameId)]

    -- Heuristic Fallback: หากไม่พบด้วย ID ให้ตรวจจับจาก Object ภายในแมพ
    if not gameInfo then
        local rep = game:GetService("ReplicatedStorage")
        local modules = rep:FindFirstChild("Modules")
        if workspace:FindFirstChild("MineWorld") or (modules and modules:FindFirstChild("MineConfig")) then
            gameInfo = SupportedGames[79389059854988]
        elseif (rep:FindFirstChild("Remotes") and rep.Remotes:FindFirstChild("ThrowNet")) or workspace:FindFirstChild("FishingDocks") then
            gameInfo = SupportedGames[93898234979111]
        end
    end

    if not gameInfo then
        Log("Unsupported Map", string.format("แมพนี้ยังไม่รองรับในระบบ\nPlaceId: %s | GameId: %s", tostring(placeId), tostring(gameId)), 6)
        warn("[KuyKuy Hub] Unknown Game -> PlaceId:", placeId, "GameId:", gameId)
        return
    end

    Log("KuyKuy Hub", string.format("ตรวจพบ: %s [%s]", gameInfo.Name, gameInfo.Category), 3)

    -- 3. ฟังก์ชันดาวน์โหลดโค้ดสคริปต์ (Dual-Method Fetch with Cache-Buster)
    local function FetchScript(path)
        local fullUrl = BaseUrl .. path
        local saltUrl = fullUrl .. "?v=" .. tostring(os.time()) .. "&salt=" .. tostring(math.random(100000, 999999))

        -- ลองโหลดด้วย Salt URL ป้องกันแคช
        local okSalt, srcSalt = pcall(function()
            return game:HttpGet(saltUrl)
        end)
        if okSalt and type(srcSalt) == "string" and #srcSalt > 100 then
            return srcSalt
        end

        -- Fallback ลองโหลดด้วย Clean URL ตรง
        local okClean, srcClean = pcall(function()
            return game:HttpGet(fullUrl)
        end)
        if okClean and type(srcClean) == "string" and #srcClean > 100 then
            return srcClean
        end

        -- Fallback ผ่าน request / http_request
        local req = (syn and syn.request) or request or http_request or (http and http.request)
        if req then
            local res = nil
            pcall(function()
                res = req({ Url = fullUrl, Method = "GET" })
            end)
            if res and res.Body and #res.Body > 100 then
                return res.Body
            end
        end

        return nil
    end

    local scriptSource = FetchScript(gameInfo.Path)
    if not scriptSource then
        Log("Fetch Failed", "ไม่สามารถดาวน์โหลดไฟล์จาก GitHub ได้! ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต", 6)
        warn("[KuyKuy Hub Fetch Failed]:", BaseUrl .. gameInfo.Path)
        return
    end

    -- ตัด UTF-8 BOM ออกหากมี
    if scriptSource:sub(1, 3) == "\239\187\191" then
        scriptSource = scriptSource:sub(4)
    end

    -- 4. คอมไพล์และรันสคริปต์
    local fn, compileErr = loadstring(scriptSource, "=" .. gameInfo.Path)
    if not fn then
        Log("Compile Error", "คอมไพล์สคริปต์ไม่ผ่าน: " .. tostring(compileErr), 10)
        warn("[KuyKuy Hub Compile Error]:\n", compileErr)
        return
    end

    local runOk, runErr = xpcall(fn, function(err)
        return tostring(err) .. "\n" .. debug.traceback()
    end)

    if not runOk then
        Log("Runtime Error", "เกิดข้อผิดพลาดในการรันสคริปต์:\n" .. tostring(runErr), 10)
        warn("[KuyKuy Hub Runtime Error]:\n", runErr)
    else
        Log("KuyKuy Hub", "✅ รันสคริปต์ " .. gameInfo.Name .. " สำเร็จ!", 4)
    end
end)
