# KUYKUY HUB — MASTER PROMPT & ENGINEERING SPECIFICATION
> **คู่มือคำสั่งแม่แบบ (Master Prompt) สำหรับสั่งงาน AI Agent เพื่อสร้างสคริปต์ Roblox Automation Hub คุณภาพสูง เสถียรสูงสุด แบบ One-Shot**

---

## ส่วนที่ 1: แม่แบบคำสั่งพร้อมใช้งาน (Copy-Paste Ready Prompt)
> คัดลอกข้อความในกล่องด้านล่างนี้ไปวางสั่ง AI Agent (เช่น Antigravity, Claude, ChatGPT) พร้อมกรอกข้อมูลเกมเป้าหมาย

```markdown
คุณคือ Senior Luau Systems Engineer ที่เชี่ยวชาญการสร้างสคริปต์ Game Automation Hub สำหรับ Roblox โดยใช้มาตรฐาน Kuykuy Hub Framework

เป้าหมาย: จงเขียนสคริปต์ Luau สมบูรณ์แบบไฟล์เดียว (Single-File Complete Script) สำหรับเกม [ระบุชื่อเกม / PlaceId] โดยต้องมีความเสถียรสูงสุด ไม่มีบั๊ก ไม่กระตุก และปฏิบัติตามมาตรฐานวิศวกรรมของ Kuykuy Hub 6 เลเยอร์อย่างเคร่งครัด

### ข้อมูลระบบเกมเป้าหมาย (Game Context):
- PlaceId: [ใส่ PlaceId]
- ระบบหลักในเกม: [ระบุ เช่น ฟาร์มความเร็ว, ขโมยไอเทม, เปิดแพ็ค, หลอมตัวละคร, อัปเกรดฐาน]
- Remotes / Net Paths ที่สำคัญ:
  * [ระบุ RemoteEvent / RemoteFunction เช่น ReplicatedStorage.Remotes.Packs.OpenOwned]
- Config Modules ที่เกี่ยวข้อง:
  * [ระบุ ModuleScript เช่น ReplicatedStorage.Shared.Configs.StageConfig]

### กฎสถาปัตยกรรม Kuykuy Hub 6 เลเยอร์ (Architecture Layers):
1. **Layer 1 - Core Lifecycle & Loop Manager:**
   - ใช้ `Core:Loop(id, flagName, interval, fn)` และ `Core:Connect(signal, fn)` มีระบบเคลียร์ Connection และ Thread เมื่อ Unload (`Core:Destroy()`) ป้องกัน Memory Leak และ Thread ซ้อนทับ 100%
   - ทุก Loop ใช้ `task.spawn` และ `task.wait()` ห้ามใช้ `wait()` เก่า
2. **Layer 2 - Engine & Movement Helpers:**
   - ฟังก์ชันช่วยระดับระบบ: `ResolvePath` (แปลงสตริงเป็น Instance อัตโนมัติ), `GetRoot`, `GetHumanoid`, `MoveTo` (มี precise และ timeout), `Teleport`, `RecoverFromHit` (Anti-Ragdoll)
3. **Layer 3 - Network Wrapper (S-Tier Net Standard):**
   - `Net.Fire(remote, cooldown, ...)`: มี Cooldown Debounce ในตัว
   - `Net.Invoke(remote, ...)`: ต้องครอบ `task.spawn` + `pcall` พร้อม **Timeout Guard 3-4 วินาที** ป้องกัน Thread ค้างถาวรหากเซิร์ฟเวอร์ไม่ตอบกลับ และต้องรองรับ **Multiple Return Values** (`true, table.unpack(results, 2, results.n)`)
4. **Layer 4 - Config Persistence (Save/Load):**
   - บันทึกการตั้งค่าลงไฟล์ `[gamename]_config.json` โดยใช้ `HttpService:JSONEncode` พร้อมระบบสำรอง `serializeFallback` (Key-Value) เผื่อ Executor ไม่มี JSON Parser
5. **Layer 5 - Independent Gameplay Loops (Decoupled Loops):**
   - แยก Loop แต่ละระบบเป็นอิสระ (เช่น Loop ขโมย, Loop ฟักแพ็ค, Loop สวมใส่ตัวดีสุด, Loop อัปเกรด, Loop รวม/หลอม, Loop เคลมรางวัล, Loop กันเตะ AFK)
6. **Layer 6 - Modern Dark Theme UI Framework:**
   - หน้าต่าง Modern Dark GUI พร้อม Sidebar แท็บ, ปุ่ม Toggle, Dropdown, Status Bar และแท็บบันทึกประวัติ Real-Time (Circular Buffer 80 รายการ)

### กฎเหล็กป้องกันข้อผิดพลาดและความเสถียร (Zero-Tolerance Failure Rules):
1. **Pre-check Price Guard (ป้องกัน Notification Spam):**
   - ก่อนยิง Remote ซื้อหรืออัปเกรดใดๆ ต้องคำนวณและเปรียบเทียบเงินสดของผู้เล่นกับราคาใน Config ทางการก่อนเสมอ (`Cash >= NextPrice`) หากเงินไม่พอห้ามยิง Remote เด็ดขาด เพื่อป้องกัน Toast Notification แจ้งเตือนเงินไม่พอเด้งรัวๆ
2. **Array Nil Hole Guard (ป้องกัน Loop หยุดทำงาน):**
   - ห้ามสร้าง Array ที่มีค่า `nil` ตัวแรก เช่น `{ nil, "Gold", ... }` แล้ววนลูปด้วย `ipairs` เพราะใน Luau `ipairs` จะหยุดทำงานทันทีตั้งแต่รอบที่ 0 ให้ใช้ค่าว่าง `""` แทน แล้วแปลงเป็น `nil` ในจังหวะส่ง Remote
3. **Official Module Introspection (ห้ามเชื่อ Client Rigs):**
   - การคำนวณสปีดบอสหรือเงื่อนไขด่าน ต้องอ่านจาก Module Config ทางการของเกม (เช่น `StageConfig`, `SpeedConfig`) ห้ามอ่าน Property จาก Rig ที่ยังไม่ถูกโหลดหรือมีค่า Placeholder (`WalkSpeed = 10`)
4. **Dual-Layer Actioning (แม่นยำ 100%):**
   - สำหรับระบบเคลมรางวัลหรือซื้อของ ให้ใช้ 2 ชั้น: ชั้นที่ 1 ลองส่งคำสั่งแบบรวม (Batch) หากยังมีรายการตกค้าง ให้ใช้ชั้นที่ 2 สแกนผ่าน Config แล้วยิงเจาะจงรายตัว (Precision Fallback)
5. **Placed & Equipped Items Scanning:**
   - สำหรับระบบรวมของ (Merge) หรือหลอมตัวละคร (Fuse) ต้องสแกนทั้งในกระเป๋า (`Backpack`) และบนฐาน (`Placed` / ยูนิตที่กำลังทำงาน) เพื่อให้ผู้เล่นไม่ต้องเก็บของเข้ากระเป๋าก่อน
   - หลังการหลอมยูนิตสำเร็จ ต้องหน่วงเวลา 0.5s แล้วทริกเกอร์ `EquipBest` อัตโนมัติทันที เพื่อเติมช่องว่างที่ว่างลง

จงสร้างโค้ดที่สมบูรณ์ ไวยากรณ์ถูกต้อง 100% พร้อมใช้งานทันที
```

---

## ส่วนที่ 2: มาตรฐานโครงสร้างโค้ด Luau (Code Skeleton Reference)

ด้านล่างนี้คือตัวอย่าง Implementation มาตรฐานของระบบสำคัญที่ต้องมีในสคริปต์ Kuykuy Hub ทุกตัว:

### 1. Network Wrapper พร้อม Timeout Guard & Multiple Return Values
```lua
local Net = { _last = {} }
local RP = "ReplicatedStorage.Remotes."

Net.Paths = {
    -- กำหนด Path ของ Remotes ทั้งหมดไว้ที่จุดเดียว
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
```

---

### 2. Guard ตรวจสอบเงินสดและเลเวลตันก่อนอัปเกรด (Zero-Spam Pattern)
```lua
local nextUpgradeTime = 0

local function autoUpgradeStep()
    local now = os.clock()
    if now < nextUpgradeTime then return end

    local cfg = getUpgradeConfig()
    local curLvl = getPlayerLevel()
    local nextPrice = cfg and cfg.GetPrice and cfg.GetPrice(curLvl)

    -- เลเวลตันแล้ว หยุดตรวจสอบเป็นเวลานานเพื่อประหยัดทรัพยากร
    if nextPrice == nil then
        nextUpgradeTime = now + 60
        return
    end

    local cash = getPlayerCash()
    -- หากเงินสดไม่พอ ห้ามยิง Remote ป้องกันเซิร์ฟเวอร์ส่ง Toast Notification แจ้งเตือนเงินไม่พอรัวๆ
    if cash < nextPrice then
        nextUpgradeTime = now + 4
        return
    end

    local ok, success, reason = Net.Invoke(Net.Paths.UpgradeRemote, {})
    if ok and success then
        nextUpgradeTime = now + 1.0
        logAction("อัปเกรด", "อัปเกรดสำเร็จ", true)
    else
        nextUpgradeTime = now + 5
        if ok and reason and reason ~= "NOT_ENOUGH_CASH" then
            logAction("อัปเกรด", "พลาด: " .. tostring(reason), false)
        end
    end
end
```

---

### 3. ระบบเคลมรางวัลแบบ Dual-Layer (Batch + Precision Fallback)
```lua
local function autoClaimStep()
    local now = os.clock()
    if now < nextClaimTime then return end

    local data = getPlayerDataKey("Index")
    if not hasUnclaimedRewards(data) then
        nextClaimTime = now + 20
        return
    end

    nextClaimTime = now + 25
    -- ใช้ String ว่างแทน nil เพื่อป้องกัน ipairs จบการทำงานตั้งแต่รอบแรก
    local categories = { "", "Gold", "Emerald", "Diamond", "Cursed", "Transcendent", "Glitched" }
    local totalClaimed = 0

    -- วิธีที่ 1: ยิงแบบรวมทั้งหมด (Batch Claim)
    for _, cat in ipairs(categories) do
        local arg = (cat ~= "" and cat) or nil
        local ok, success, _, count = Net.Invoke(Net.Paths.ClaimAllRemote, nil, nil, arg)
        if ok and success then
            totalClaimed = totalClaimed + (tonumber(count) or 1)
        end
        task.wait(0.1)
    end

    -- วิธีที่ 2: เคลมรายตัวที่เหลือตกค้าง (Precision Fallback)
    local cfg = getIndexConfig()
    if cfg and cfg.IsClaimable and type(data) == "table" then
        for _, entry in ipairs(getAllEntries()) do
            for _, cat in ipairs(categories) do
                local arg = (cat ~= "" and cat) or nil
                if cfg.IsClaimable(data, entry, arg) then
                    local ok, success = Net.Invoke(Net.Paths.ClaimRemote, entry.Stage, entry.Name, arg)
                    if ok and success then
                        totalClaimed = totalClaimed + 1
                    end
                    task.wait(0.08)
                end
            end
        end
    end

    if totalClaimed > 0 then
        logAction("เคลม", string.format("เคลมสำเร็จ (+%d รายการ)", totalClaimed), true)
    end
end
```

---

### 4. Circular Buffer Real-Time Logging Engine
```lua
local Stats = { boosts = 0, success = 0, fail = 0, last = "-", logs = {} }

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
```

---

## ส่วนที่ 3: สรุป Checklist สำหรับส่งงาน (Quality Assurance Checklist)
ก่อนนำสคริปต์ไปรันจริง ให้ตรวจสอบ 5 ข้อนี้เสมอ:
- [ ] **Syntax:** ผ่านการตรวจสอบด้วย Luau AST Parser (`luaparse`) ไม่มี Syntax Error
- [ ] **Timeout Guard:** มี Timeout 3-4 วินาทีครอบทุกการเรียก `InvokeServer`
- [ ] **Notification Guard:** มีการเช็คเงินก่อนยิงคำสั่งซื้อ/อัปเกรด ป้องกันแจ้งเตือนเงินไม่พอเด้งรัวๆ
- [ ] **Nil-Safe Arrays:** ไม่มีการใช้ `ipairs` กับตารางที่สมาชิกแรกเป็น `nil`
- [ ] **Unload Safety:** มีปุ่ม Kill Switch (`Core:Destroy()`) ปิดการทำงานและล้างเธรด/UI ทุกอย่างได้อย่างสะอาด 100%
