# KUYKUY HUB — UNIVERSAL MASTER PROMPT & ENGINEERING SPECIFICATION (v2.0)
> **คู่มือคำสั่งแม่แบบและข้อกำหนดทางวิศวกรรมสากล สำหรับสั่งงาน AI Agent (Antigravity, Claude, ChatGPT) เพื่อสร้างสคริปต์ Roblox Game Automation Hub ระดับ S-Tier ให้ประสบความสำเร็จสูงสุดใน One-Shot (คำสั่งเดียวจบ) และสามารถนำไปปรับใช้ได้กับทุกแมพ**

---

## สารบัญ (Table of Contents)
1. [ส่วนที่ 1: คำสั่งแม่แบบพร้อมใช้งาน (Copy-Paste Ready Master Prompt)](#ส่วนที่-1-คำสั่งแม่แบบพร้อมใช้งาน-copy-paste-ready-master-prompt)
2. [ส่วนที่ 2: 7 เสาหลักทางวิศวกรรมที่การันตีความสำเร็จ (7 Core Pillars)](#ส่วนที่-2-7-เสาหลักทางวิศวกรรมที่การันตีความสำเร็จ-7-core-pillars)
3. [ส่วนที่ 3: ตารางการปรับใช้ตามประเภทของเกม (Genre Adaptation Matrix)](#ส่วนที่-3-ตารางการปรับใช้ตามประเภทของเกม-genre-adaptation-matrix)
4. [ส่วนที่ 4: โค้ดแม่แบบมาตรฐานวิศวกรรม S-Tier (Luau Reference Boilerplate)](#ส่วนที่-4-โค้ดแม่แบบมาตรฐานวิศวกรรม-s-tier-luau-reference-boilerplate)
5. [ส่วนที่ 5: แบบตรวจสอบก่อนส่งงาน (Pre-Flight QA Checklist)](#ส่วนที่-5-แบบตรวจสอบก่อนส่งงาน-pre-flight-qa-checklist)

---

## ส่วนที่ 1: คำสั่งแม่แบบพร้อมใช้งาน (Copy-Paste Ready Master Prompt)
> คัดลอกข้อความในกล่องด้านล่างนี้ทั้งหมด นำไปกรอกข้อมูลในช่อง `[...]` แล้วส่งให้ AI Agent ทำงานได้ทันที:

```markdown
คุณคือ Senior Luau Systems Engineer และ Roblox Reverse-Engineering Specialist ระดับโลก ที่เชี่ยวชาญการสร้างสคริปต์ Game Automation Hub คุณภาพสูงตามมาตรฐาน "Kuykuy Hub Universal Architecture"

เป้าหมาย: จงเขียนสคริปต์ Luau ไฟล์เดียวจบ (Single-File Production Script) สำหรับเกม [ระบุชื่อเกม / PlaceId] โดยต้องมีความเสถียรสูงสุด ไร้บั๊ก 100% ไม่กระตุก ไม่หลุดการทำงาน และปฏิบัติตาม "7 เสาหลักวิศวกรรม Kuykuy Hub" อย่างเคร่งครัด

### 1. ข้อมูลระบบและบริบทของเกม (Game Context):
- PlaceId: [ใส่ PlaceId เช่น 133151378618377]
- ประเภทเกม (Genre): [เช่น Steal/Runner, Training Simulator, Tycoon, Anime RPG, Dungeon/Wave]
- ระบบหลักที่ต้องสร้าง Automation:
  1. [เช่น ฟาร์มสปีด / วิ่งลู่ / ต่อยมอนสเตอร์ / กดคลิก]
  2. [เช่น เดินไปขโมยไอเทมที่ดีที่สุดในด่าน / ฟาร์มเหรียญ]
  3. [เช่น นำไอเทมกลับมาเพาะ/วางที่ฐาน / รวมไอเทม / หลอมตัวละคร]
  4. [เช่น อัปเกรดฐาน / อัปเกรดสเตตัส / ซื้อโค้ช / ซื้อออร่า]
  5. [เช่น เคลมรางวัลความสำเร็จ / รับของรางวัลรายวัน / เปิดหีบ]
- รายชื่อ Remotes / Net Paths สำคัญ:
  * RemoteFunction: [เช่น ReplicatedStorage.Remotes.Packs.PlaceOwned]
  * RemoteEvent: [เช่น ReplicatedStorage.Remotes.Packs.Opened]
- รายชื่อ Config Modules / Data Scripts:
  * [เช่น ReplicatedStorage.Shared.Configs.StageConfig, PlayerData]

### 2. มาตรฐานสถาปัตยกรรม 7 เสาหลักที่ต้องปฏิบัติตาม (7 Core Pillars):
1. **Network & Timeout Guard (S-Tier Net):**
   - ทุกคำสั่ง `InvokeServer` ต้องครอบด้วย `task.spawn` + `pcall` และมี **Timeout Guard (3-4 วินาที)** เสมอ หากเซิร์ฟเวอร์ไม่ตอบกลับต้องคืนค่า `false, "TIMEOUT"` ห้ามปล่อยให้เธรดค้างถาวรเด็ดขาด
   - ทุกคำสั่ง `FireServer` ต้องมีระบบ Debounce Cooldown ในตัว
2. **Anti-Spam Pre-check Guard:**
   - ก่อนยิงคำสั่งซื้อหรืออัปเกรด ต้องตรวจสอบเงินสดจริง (`Cash >= NextPrice`) หากเงินไม่พอห้ามยิง Remote ป้องกันเซิร์ฟเวอร์ส่ง Toast เตือนเงินไม่พอเด้งรัวๆ
   - ก่อนยิงคำสั่งรวม/หลอม ต้องตรวจสอบจำนวนของจริงในกระเป๋า (`Count >= 2`) หากไม่มีคู่ห้ามยิง Remote และห้ามวาร์ปตัวละคร
3. **Roblox Streaming & Distance Guard:**
   - ห้ามตัดสินว่าด่านว่างหรือไม่มีของ หากวัตถุอยู่ห่างเกิน 800-1,000 studs ให้เรียก `LocalPlayer:RequestStreamAroundAsync(targetPos, 2.0)` ก่อนตรวจสอบเสมอ เพื่อแก้ปัญหา `StreamingEnabled` ซ่อนโมเดล
4. **Movement & State Isolation:**
   - ห้ามมีหลายลูปแย่งคำสั่ง `MoveTo` สลับไปมา (เช่น ลูปบนลู่วิ่ง vs ลูปวางของ)
   - หากตัวละครยืนอยู่ในบริเวณฐานตนเองอยู่แล้ว (`<= 55 studs`) หรือกำลังวิ่งบนลู่วิ่ง ห้ามสั่ง `MoveTo` ซ้ำซ้อน ให้ยิงคำสั่ง Remote วางของได้ทันที
5. **Combat, Death & Item Recovery:**
   - การตรวจจับการส่งของสำเร็จ ต้องเช็คว่าตัวละครเป็นตัวเดิมที่หยิบของมาจริง (`LocalPlayer.Character == origChar and Helpers.IsAlive()`) เพื่อป้องกันการตายเกิดใหม่ที่ฐานถูกเข้าใจผิดว่าส่งสำเร็จ
   - หากถูกโจมตีของตกพื้น ต้องมีระบบสแกนหาของที่ตก (`CollectionService:GetTagged("SpawnedPack")` หรือของตกในด่าน) กลับมาส่งให้สำเร็จ
6. **Environmental & Server Cycle Synchronization:**
   - ห้ามใช้ตัวจับเวลาหลับ (Sleep Timer) แบบสุ่ม หากเกมมีระบบรอบจริง (เช่น กลางวัน/กลางคืน, คูลดาวน์เวฟ, บอสรีเซ็ต) ต้องผูกรอบโควต้ากับ Attribute จริงของเซิร์ฟเวอร์ เช่น `Workspace.Night:GetAttribute("NightActive")`
7. **Safe Lifecycle, Circular Buffer Logs & Dark UI:**
   - บันทึกการทำงานทุกขั้นตอนลง Circular Buffer (`Stats.logs` ขนาด 80 รายการ) เพื่อแสดงผล Real-time บน UI
   - มีปุ่มปิดสคริปต์ฉุกเฉิน (`Core:Destroy()`) ปลดการเชื่อมต่อและคืนสถานะตัวละครสะอาด 100%

จงเขียนโค้ดภาษา Luau ตัวเต็มที่สมบูรณ์แบบ ไวยากรณ์ถูกต้อง ไร้ข้อผิดพลาด พร้อมนำไปรันได้ทันที
```

---

## ส่วนที่ 2: 7 เสาหลักทางวิศวกรรมที่การันตีความสำเร็จ (7 Core Pillars)

### เสาหลักที่ 1: เครือข่ายและระบบป้องกันเธรดค้าง (Network & Timeout Guard)
- **ปัญหาที่พบบ่อย:** การเรียก `RemoteFunction:InvokeServer()` หากส่ง Arguments ไม่ถูกต้อง หรือเซิร์ฟเวอร์เกิดอาการ Lag เธรดของ Lua จะค้างที่บรรทัดนั้นตลอดกาล ทำให้ทั้งสคริปต์หยุดทำงานเงียบๆ
- **ทางแก้มาตรฐาน:** แยกการ Invoke ไปทำงานใน Coroutine ผ่าน `task.spawn` พร้อมลูปตรวจสอบเวลาหมด (Timeout 3-4 วินาที) หากเกินเวลาให้สั่ง Cancel และคืนค่า Error ทันที

### เสาหลักที่ 2: การตรวจสอบเงื่อนไขก่อนยิงคำสั่ง (Anti-Spam Pre-check Guard)
- **ปัญหาที่พบบ่อย:** สคริปต์ทั่วไปมักยิงคำสั่งซื้อ/อัปเกรด/รวมของวนลูปทุก Frame ส่งผลให้หน้าจอเกมเต็มไปด้วยกรอบแจ้งเตือนสีแดง "Not Enough Money!" หรือ "Invalid Items!"
- **ทางแก้มาตรฐาน:** อ่านค่าเงินและระดับเลเวลปัจจุบันจาก `PlayerData` หรือ `leaderstats` มาเปรียบเทียบกับสูตรคำนวณใน Config ทางการก่อน หากเงินไม่พอ ให้หยุดพักลูปการตรวจสอบไว้ 3-5 วินาที

### เสาหลักที่ 3: ระบบรับมือการซ่อนวัตถุระยะไกล (Streaming & Distance Guard)
- **ปัญหาที่พบบ่อย:** ในแมพขนาดใหญ่ที่มี `Workspace.StreamingEnabled = true` วัตถุที่อยู่ห่างเกิน 500-1,000 studs จะถูกลบออกจากหน่วยความจำไคลเอนต์ สคริปต์ที่ค้นหาโมเดลจะมองเห็นเป็น `nil` และสรุปผิดพลาดว่า "ไม่มีของในด่าน"
- **ทางแก้มาตรฐาน:** แคชพิกัดคงที่ของแต่ละโซนไว้ล่วงหน้า (`STAGE_CENTERS`) และเรียกใช้ `LocalPlayer:RequestStreamAroundAsync(targetPos, timeout)` เพื่อบังคับให้เซิร์ฟเวอร์สตรีมข้อมูลโซนเป้าหมายลงมาก่อนเริ่มค้นหา

### เสาหลักที่ 4: การแยกสถานะและป้องกันการแย่งควบคุมการเดิน (Movement State Isolation)
- **ปัญหาที่พบบ่อย:** เมื่อเปิดใช้งานฟังก์ชันฟาร์มหลายตัวพร้อมกัน (เช่น ลูปวิ่งลู่ + ลูปวางของ + ลูปตีมอน) แต่ละลูปจะสั่ง `Humanoid:MoveTo` ไปยังคนละจุดพร้อมกัน ตัวละครจะกระตุกและเดินสลับไปมาอยู่ที่เดิม
- **ทางแก้มาตรฐาน:** 
  1. ใช้ระบบพิกัดสัมพัทธ์ หากตัวละครอยู่ในรัศมีฐานของตนเองอยู่แล้ว (`<= 55 studs`) ไม่ต้องสั่ง `MoveTo` ใดๆ เพิ่มเติม
  2. กำหนดสถานะ `Core.Busy = true` เมื่อมีงานลำดับสูง (เช่น กำลังวิ่งหนีบอสขโมยของ) เพื่อบล็อกลูปงานพื้นหลังไม่ให้แย่งการเดิน

### เสาหลักที่ 5: การจัดการการต่อสู้ การกระเด็น และการตาย (Combat, Knockback & Recovery)
- **ปัญหาที่พบบ่อย:** เมื่อถือไอเทมแล้วถูกศัตรูโจมตี ตัวละครมักจะล้ม (Ragdoll) หรือกระเด็น (Knockback) ของหลุดมือ และหากตายแล้วเกิดใหม่ที่ฐาน สคริปต์ที่เช็คแค่ "ไม่ถือของแล้ว และตัวอยู่บนฐาน" จะเข้าใจผิดว่าส่งของสำเร็จ
- **ทางแก้มาตรฐาน:**
  1. บันทึก Instance ตัวละครก่อนออกเดินทาง (`origChar = LocalPlayer.Character`) หากตัวละครตายหรือเปลี่ยน Instance จะต้องรายงานว่า "ล้มเหลว/ตายระหว่างทาง" ทันที
  2. เมื่อของหลุดมือ ต้องสแกนหาของที่ตกในรัศมีรอบด่านและทางเดิน เพื่อเก็บขึ้นมาวิ่งส่งต่อ

### เสาหลักที่ 6: การซิงก์รอบเวลากับเซิร์ฟเวอร์จริง (Server Cycle Synchronization)
- **ปัญหาที่พบบ่อย:** การใช้คำสั่ง `task.wait(45)` เพื่อรอของเกิดใหม่ มักหลุดจากรอบจริงของเกม เพราะเซิร์ฟเวอร์เกมมักมีรอบการเกิดเป็นระบบ เช่น เวลากลางวัน 5 นาที / กลางคืน 15 วินาที
- **ทางแก้มาตรฐาน:** ผูกเงื่อนไขการเริ่มรอบใหม่กับ Attribute ของเซิร์ฟเวอร์จริง เช่น `Workspace.Night:GetAttribute("NightActive")` หรือเวลาสิ้นสุดรอบ `NightPhaseEndsAt`

### เสาหลักที่ 7: วงจรชีวิต ปลอดภัยต่อหน่วยความจำ และแท็บบันทึก Real-Time
- **ปัญหาที่พบบ่อย:** สคริปต์ที่รันนานๆ มักเกิดอาการแรมบวม (Memory Leak) จาก Connection ที่ไม่ได้ Disconnect หรือไม่มีหน้าต่างบันทึกสถานะให้ผู้ใช้ดูว่าสคริปต์กำลังทำอะไรอยู่
- **ทางแก้มาตรฐาน:** ใช้ `Core:Loop` และ `Core:Connect` เก็บไว้ในตารางเพื่อล้างได้ 100% พร้อมบันทึกประวัติการทำงานลง Circular Buffer (`Stats.logs`) อัปเดตขึ้น UI แบบสดๆ

---

## ส่วนที่ 3: ตารางการปรับใช้ตามประเภทของเกม (Genre Adaptation Matrix)

| หมวดหมู่เกม (Genre) | จุดสำคัญที่ต้องระบุใน Prompt | ฟังก์ชันเฉพาะทางที่ต้องมีในโค้ด | ปัญหาที่ต้องระวังเป็นพิเศษ |
| :--- | :--- | :--- | :--- |
| **1. Steal & Runner** *(เช่น ขโมยแพ็คอนิเมะ, Steal a Brainrot)* | - พิกัดแต่ละด่าน (`STAGE_CENTERS`)<br>- ความเร็วบอสแต่ละด่าน<br>- รอบกลางวัน/กลางคืน | - ฟังก์ชันคัดเลือกของที่ดีที่สุด (`isBetterCandidate`)<br>- ตรวจสอบส่งของที่ฐาน (`isSafelyDelivered`)<br>- เก็บของที่ตกพื้น (`recoverDroppedPack`) | - การตายแล้วเข้าใจผิดว่าส่งสำเร็จ<br>- วัตถุในด่านไกลๆ หายเพราะ StreamingEnabled |
| **2. Training Simulator** *(เช่น Muscle Legends, Speed Sim)* | - Remotes ฝึกซ้อม/ปั๊มสเตตัส<br>- จุดเกิด SafeZone / Rebirth Portal | - ลูปเข้าเครื่องฝึกซ้อมอัตโนมัติ<br>- คำนวณความเร็ว/พลังเพื่อปลดล็อคเครื่องระดับถัดไป | - เซิร์ฟเวอร์เตะเพราะส่งคำสั่งฝึกถี่เกินไป (Rate Limit)<br>- โดนผู้เล่นอื่นโจมตีระหว่างฝึก |
| **3. Tycoon & Base Builder** *(เช่น Anime Tycoon, Theme Park)* | - Path ของปุ่มซื้อและแผ่นเหยียบ (`Buttons`)<br>- Remote สะสมเงิน/ดึงเงินจากตู้ | - ค้นหาแผ่นซื้อที่ถูกที่สุดที่เงินพอซื้อ<br>- วาร์ป/เดินไปเหยียบปุ่มตามลำดับราคา | - ปุ่มเกิดใหม่ซ้อนทับกัน<br>- เงินไม่พอแต่พยายามเดินไปเหยียบปุ่มราคาแพง |
| **4. Anime RPG & Wave Defense** *(เช่น Anime Defenders, All Star)* | - Remote วางยูนิต / อัปเกรดยูนิต<br>- คลื่นศัตรูและจุดเกิดมอนสเตอร์ | - สแกนจุดวางยูนิตที่ครอบคลุมเส้นทางเดิน<br>- อัปเกรดยูนิตตัวดาเมจหลักก่อน | - วางยูนิตในจุดที่ทับซ้อน (Overlap)<br>- เงินในเกมไม่พออัปเกรดระหว่างเวฟ |

---

## ส่วนที่ 4: โค้ดแม่แบบมาตรฐานวิศวกรรม S-Tier (Luau Reference Boilerplate)

```lua
-- =====================================================================
-- KUYKUY HUB UNIVERSAL CORE BOILERPLATE (Production Standard)
-- =====================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

-- 1. CORE LIFECYCLE MANAGER
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

function Core:Loop(name, flag, interval, fn)
    if self._loops[name] then
        pcall(task.cancel, self._loops[name])
    end
    self._loops[name] = task.spawn(function()
        while self._alive and self.Flags[flag] do
            local ok, err = pcall(fn)
            if not ok then warn(string.format("[%s Loop Error]: %s", name, tostring(err))) end
            task.wait(interval)
        end
    end)
end

function Core:Destroy()
    self._alive = false
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    for _, th in pairs(self._loops) do pcall(task.cancel, th) end
    for _, fn in ipairs(self._cleanups) do pcall(fn) end
    if self._gui then self._gui:Destroy() end
end

-- 2. CIRCULAR BUFFER LOGGING
local Stats = { logs = {} }
local function logAction(category, msg, isSuccess)
    local entry = { time = os.date("%H:%M:%S"), cat = category, msg = tostring(msg), ok = isSuccess }
    table.insert(Stats.logs, 1, entry)
    if #Stats.logs > 80 then table.remove(Stats.logs) end
    if Core._updateLogUI then pcall(Core._updateLogUI) end
end

-- 3. NETWORK WRAPPER (TIMEOUT GUARD + COOLDOWN)
local Net = { _last = {} }
function Net.Fire(remote, cooldown, ...)
    if not Core._alive or not remote then return false end
    local key = remote:GetFullName()
    local now = os.clock()
    if cooldown and (now - (Net._last[key] or 0)) < cooldown then return false end
    Net._last[key] = now
    local args = table.pack(...)
    return (pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end))
end

function Net.Invoke(remote, ...)
    if not Core._alive or not remote then return false, "DEAD_OR_NIL" end
    local args = table.pack(...)
    local done = false
    local results = {}
    task.spawn(function()
        results = table.pack(pcall(function()
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end))
        done = true
    end)
    local t0 = os.clock()
    while not done and (os.clock() - t0) < 4.0 and Core._alive do
        task.wait(0.03)
    end
    if not done then return false, "TIMEOUT" end
    if not results[1] then return false, results[2] end
    return true, table.unpack(results, 2, results.n)
end

-- 4. MOVEMENT & STREAMING HELPERS
local Helpers = {}
function Helpers.GetRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Helpers.IsAlive()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil
end

function Helpers.StreamAround(pos, timeout)
    if not pos or not Workspace.StreamingEnabled then return end
    pcall(function() LocalPlayer:RequestStreamAroundAsync(pos, timeout or 2.0) end)
end

function Helpers.MoveTo(targetPos, abortFn, opts)
    local hrp = Helpers.GetRoot()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end
    local arriveDist = (opts and opts.arriveDist) or 4
    local deadline = os.clock() + (opts and opts.timeout or 30)

    while Core._alive and Helpers.IsAlive() and os.clock() < deadline do
        if abortFn and abortFn() then break end
        if (hrp.Position - targetPos).Magnitude <= arriveDist then return true end
        hum:MoveTo(targetPos)
        task.wait(0.1)
    end
    return false
end
```

---

## ส่วนที่ 5: แบบตรวจสอบก่อนส่งงาน (Pre-Flight QA Checklist)

ก่อนจะถือว่าสคริปต์เสร็จสมบูรณ์ 100% ต้องผ่านเกณฑ์ 6 ข้อนี้:
1. [ ] **Syntax Verification:** ผ่านการตรวจสอบด้วย `luaparse` (Luau AST Parser) ไม่มี Syntax Error
2. [ ] **Timeout Guard Active:** ไม่มีคำสั่ง `InvokeServer` ใดที่ถูกเรียกแบบลอยๆ โดยไม่มี Timeout ครอบ
3. [ ] **No Movement Fighting:** ลูปงานแต่ละตัวไม่แย่งการเดิน `MoveTo` ไปคนละทิศทาง
4. [ ] **Safe Zone Verification:** การตรวจการส่งของหรือเคลมของตรวจสอบจากพิกัดจริงและสถานะตัวละครเดิม ไม่หลงกลการตายเกิดใหม่
5. [ ] **Streaming Safety:** มีการเรียก `RequestStreamAroundAsync` ก่อนเข้าถึงวัตถุที่อยู่ไกล
6. [ ] **Memory Cleanliness:** ทดสอบปิดสคริปต์ด้วย `Core:Destroy()` แล้ว เธรดและ UI หายหมดจด ไม่ค้างในหน่วยความจำ
