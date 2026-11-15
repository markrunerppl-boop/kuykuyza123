# KUYKUY HUB — UNIVERSAL MASTER PROMPT & ENGINEERING SPECIFICATION (v3.0)
> **คู่มือคำสั่งแม่แบบและข้อกำหนดทางวิศวกรรมสากล สำหรับสั่งงาน AI Agent (Antigravity, Claude, ChatGPT) เพื่อสร้างสคริปต์ Roblox Game Automation Hub ระดับ S-Tier ให้ประสบความสำเร็จสูงสุดใน One-Shot (คำสั่งเดียวจบ) และสามารถนำไปปรับใช้ได้กับทุกแมพบน Roblox**

---

## สารบัญ (Table of Contents)
1. [ส่วนที่ 1: คำสั่งแม่แบบพร้อมใช้งาน (Copy-Paste Ready Master Prompt)](#ส่วนที่-1-คำสั่งแม่แบบพร้อมใช้งาน-copy-paste-ready-master-prompt)
2. [ส่วนที่ 2: 10 เสาหลักทางวิศวกรรมที่การันตีความสำเร็จ (10 Core Pillars)](#ส่วนที่-2-10-เสาหลักทางวิศวกรรมที่การันตีความสำเร็จ-10-core-pillars)
3. [ส่วนที่ 3: ตารางการปรับใช้ตามประเภทของเกม (Genre Adaptation Matrix)](#ส่วนที่-3-ตารางการปรับใช้ตามประเภทของเกม-genre-adaptation-matrix)
4. [ส่วนที่ 4: โค้ดแม่แบบมาตรฐานวิศวกรรม S-Tier (Luau Reference Boilerplate v3.0)](#ส่วนที่-4-โค้ดแม่แบบมาตรฐานวิศวกรรม-s-tier-luau-reference-boilerplate-v30)
5. [ส่วนที่ 5: แบบตรวจสอบก่อนส่งงาน (Pre-Flight QA Checklist)](#ส่วนที่-5-แบบตรวจสอบก่อนส่งงาน-pre-flight-qa-checklist)

---

## ส่วนที่ 1: คำสั่งแม่แบบพร้อมใช้งาน (Copy-Paste Ready Master Prompt)
> **วิธีใช้:** คัดลอกข้อความในกล่องด้านล่างนี้ทั้งหมด นำไปกรอกข้อมูลในช่อง `[...]` ตามข้อมูลจริงของแมพที่ต้องการทำ แล้วส่งให้ AI Agent เริ่มต้นทำงานได้ทันที:

```markdown
คุณคือ Senior Luau Systems Engineer และ Roblox Reverse-Engineering Specialist ระดับโลก ที่เชี่ยวชาญการสร้างสคริปต์ Game Automation Hub คุณภาพสูงตามมาตรฐาน "Kuykuy Hub Universal Architecture"

เป้าหมายสูงสุด: จงเขียนสคริปต์ Luau ไฟล์เดียวจบ (Single-File Production Script) สำหรับเกม [ระบุชื่อเกม / PlaceId] โดยต้องมีความเสถียรสูงสุด ไร้บั๊ก 100% ไม่กระตุก ไม่หลุดการทำงาน บันทึกการตั้งค่าข้ามเซสชันได้ และปฏิบัติตาม "10 เสาหลักวิศวกรรม Kuykuy Hub" อย่างเคร่งครัด

### 1. ข้อมูลระบบและบริบทของเกม (Game Context):
- PlaceId: [ใส่ PlaceId เช่น 133151378618377]
- ประเภทเกม (Genre): [เลือก: Steal/Runner, Training Simulator, Tycoon, Anime RPG, Clicker/Tapping, Fishing/Gathering]
- ระบบหลักที่ต้องสร้าง Automation:
  1. [เช่น ฟาร์มสปีด / วิ่งลู่ / ต่อยมอนสเตอร์ / กดคลิก]
  2. [เช่น เดินไปขโมยไอเทมที่ดีที่สุดในด่าน / ฟาร์มเหรียญ]
  3. [เช่น นำไอเทมกลับมาเพาะ/วางที่ฐาน / รวมไอเทมซ้ำ / หลอมตัวละคร]
  4. [เช่น อัปเกรดฐาน / อัปเกรดสเตตัส / ซื้อโค้ช / ซื้อออร่า / เกิดใหม่ Rebirth]
  5. [เช่น เคลมรางวัลความสำเร็จ / รับของรางวัลรายวัน / เปิดหีบ / กันเตะ Anti-AFK]
- รายชื่อ Remotes / Net Paths สำคัญ:
  * RemoteFunction: [เช่น ReplicatedStorage.Remotes.Packs.PlaceOwned, Packs.Merge, Mutate.Merge]
  * RemoteEvent: [เช่น ReplicatedStorage.Remotes.Packs.Opened, Treadmill.Boost]
- รายชื่อ Config Modules / Data Scripts / POIs:
  * [เช่น ReplicatedStorage.Shared.Configs.StageConfig, PlayerData, Plots]

### 2. มาตรฐานสถาปัตยกรรม 10 เสาหลักที่ต้องปฏิบัติตาม (10 Core Pillars):
1. **Network & Timeout Guard (S-Tier Net):**
   - ทุกคำสั่ง `InvokeServer` ต้องครอบด้วย `task.spawn` + `pcall` และมี **Timeout Guard (3-4 วินาที)** เสมอ หากเซิร์ฟเวอร์ไม่ตอบกลับต้องคืนค่า `false, "TIMEOUT"` ห้ามปล่อยให้เธรดค้างถาวรเด็ดขาด
   - ทุกคำสั่ง `FireServer` ต้องมีระบบ Debounce Cooldown ในตัว
2. **Anti-Spam Pre-check Guard:**
   - ก่อนยิงคำสั่งซื้อหรืออัปเกรด ต้องตรวจสอบเงินสดจริง (`Cash >= NextPrice`) หากเงินไม่พอห้ามยิง Remote ป้องกันเซิร์ฟเวอร์ส่ง Toast เตือนเงินไม่พอเด้งรัวๆ
   - ก่อนยิงคำสั่งรวม/หลอม ต้องตรวจสอบจำนวนของจริงในกระเป๋า (`Count >= 2`) หากไม่มีคู่ห้ามยิง Remote และห้ามวาร์ปตัวละคร
3. **Roblox Streaming & Distance Guard:**
   - ห้ามตัดสินว่าด่านว่างหรือไม่มีของ หากวัตถุอยู่ห่างเกิน 500-1,000 studs ให้เรียก `LocalPlayer:RequestStreamAroundAsync(targetPos, 2.0)` ก่อนตรวจสอบเสมอ เพื่อแก้ปัญหา `StreamingEnabled` ซ่อนโมเดล
4. **Movement & State Isolation:**
   - ห้ามมีหลายลูปแย่งคำสั่ง `MoveTo` สลับไปมา (เช่น ลูปบนลู่วิ่ง vs ลูปวางของ)
   - หากตัวละครยืนอยู่ในบริเวณฐานตนเองอยู่แล้ว (`<= 55 studs`) หรือกำลังวิ่งบนลู่วิ่ง ห้ามสั่ง `MoveTo` ซ้ำซ้อน ให้ยิงคำสั่ง Remote วางของได้ทันที
   - ใช้แฟลก `Core.Busy = true` เพื่อล็อกเธรดการเคลื่อนที่หลักไม่ให้งานย่อยเข้ามาแทรกแซง
5. **Combat, Death & Item Recovery:**
   - การตรวจจับการส่งของสำเร็จ ต้องเช็คว่าตัวละครเป็นตัวเดิมที่หยิบของมาจริง (`LocalPlayer.Character == origChar and Helpers.IsAlive()`) เพื่อป้องกันการตายเกิดใหม่ที่ฐานถูกเข้าใจผิดว่าส่งสำเร็จ
   - หากถูกโจมตีของตกพื้น ต้องมีระบบสแกนหาของที่ตก (`CollectionService:GetTagged` หรือของตกในด่าน) กลับมาส่งให้สำเร็จ
6. **Environmental & Server Cycle Synchronization:**
   - ห้ามใช้ตัวจับเวลาหลับ (Sleep Timer) แบบสุ่ม หากเกมมีระบบรอบจริง (เช่น กลางวัน/กลางคืน, คูลดาวน์เวฟ, บอสรีเซ็ต) ต้องผูกรอบโควต้ากับ Attribute จริงของเซิร์ฟเวอร์ เช่น `Workspace.Night:GetAttribute("NightActive")`
7. **Safe Lifecycle & Action Logs:**
   - บันทึกการทำงานทุกขั้นตอนลง Circular Buffer (`Stats.logs` ขนาด 80 รายการ) เพื่อแสดงผล Real-time บน UI
   - มีปุ่มปิดสคริปต์ฉุกเฉิน (`Core:Destroy()`) ปลดการเชื่อมต่อและคืนสถานะตัวละครสะอาด 100%
8. **Config & Toggle State Persistence:**
   - ระบบจดจำการตั้งค่าอัตโนมัติ: บันทึกสถานะเปิด-ปิดของทุก Toggle, Dropdown, Slider ลงไฟล์ด้วย `writefile` / `readfile` (หรือ fallback cache)
   - Auto-Save ทุกครั้งที่ผู้ใช้คลิกสลับปุ่มใน UI และ Auto-Load คืนค่าสถานะทันทีเมื่อโหลดสคริปต์ใหม่
9. **Luau Register Budget Management:**
   - ตัวแปลระดับสูงสุดในฟังก์ชัน `main()` ต้องไม่เกิน 110 ตัวแปร เพื่อป้องกันข้อผิดพลาดรุนแรง `Luau: local register limit exceeded (200)`
   - ให้จัดกลุ่มฟังก์ชันและตัวแปรเข้าเป็น Namespace Tables เช่น `Core`, `Helpers`, `Net`, `Stats`, `Config`, `Loops`
10. **Universal Inventory & Multi-Remote Fallback:**
    - ค้นหาไอเทมครอบคลุมทั้งจาก Tool ในกระเป๋าและในมือ (`getBagTools(true)`) และข้อมูลใน `PlayerData.Inventory` (รองรับทั้ง Array และ Dictionary ที่ใช้ UUID เป็น Key)
    - หากเกมมี Remote สำหรับงานเดียวกันหลายตัว (เช่น `Packs.Merge` vs `Mutate.Merge`) ต้องมีระบบ Fallback รองรับอัตโนมัติ

จงเขียนโค้ดภาษา Luau ตัวเต็มที่สมบูรณ์แบบ ไวยากรณ์ถูกต้อง ไร้ข้อผิดพลาด พร้อมนำไปรันได้ทันที
```

---

## ส่วนที่ 2: 10 เสาหลักทางวิศวกรรมที่การันตีความสำเร็จ (10 Core Pillars)

### เสาหลักที่ 1: เครือข่ายและระบบป้องกันเธรดค้าง (Network & Timeout Guard)
- **ปัญหา:** การเรียก `RemoteFunction:InvokeServer()` หากส่ง Arguments ผิดประเภท, เซิร์ฟเวอร์ดีเลย์, หรือติดแอนตี้ชีต เธรดของ Lua จะค้างที่บรรทัดนั้นตลอดกาล ทำให้บอทหยุดทำงานเงียบๆ
- **มาตรฐาน:** แยกการ Invoke ไปทำงานใน Coroutine ผ่าน `task.spawn` พร้อมลูปตรวจสอบเวลาหมด (Timeout 3.5 วินาที) หากเกินกำหนดให้คืนค่า `false, "TIMEOUT"` และปลดล็อกเธรดทันที

### เสาหลักที่ 2: การตรวจสอบเงื่อนไขก่อนยิงคำสั่ง (Anti-Spam Pre-check Guard)
- **ปัญหา:** การยิง Remote ซื้อของหรืออัปเกรดรัวๆ ทุกเฟรม ทำให้เกิด Network Congestion และหน้าจอเต็มไปด้วย Toast สีแดงแจ้งเตือน "เงินไม่พอ" หรือ "ของไม่ถูกต้อง"
- **มาตรฐาน:** ตรวจสอบข้อมูลจาก `PlayerData`, `leaderstats` หรือ Attribute จริงก่อนเสมอ ถ้า `Cash < Price` หรือไม่มีไอเทมคู่ซ้ำ ให้พักลูปนั้นไว้ 3-5 วินาที

### เสาหลักที่ 3: ระบบรับมือการซ่อนวัตถุระยะไกล (Streaming & Distance Guard)
- **ปัญหา:** เกมสมัยใหม่เปิด `Workspace.StreamingEnabled = true` ทำให้โมเดล, มอนสเตอร์, หรือแพ็คการ์ดที่อยู่ห่างเกิน 500 studs ถูก Unload ออกจากหน่วยความจำ สคริปต์จะมองเห็นเป็น `nil`
- **มาตรฐาน:** กำหนดพิกัดศูนย์กลางของโซนไว้ล่วงหน้า และเรียก `LocalPlayer:RequestStreamAroundAsync(pos, timeout)` บังคับให้โหลดวัตถุก่อนเริ่มตรวจสอบ

### เสาหลักที่ 4: การแยกสถานะและป้องกันการแย่งควบคุมการเดิน (Movement State Isolation)
- **ปัญหา:** ลูปอัตโนมัติต่างๆ (เช่น วิ่งเก็บของ, เดินกลับฐาน, วิ่งลู่) ต่างคนต่างสั่ง `Humanoid:MoveTo` พร้อมกัน ตัวละครจะกระตุกและชะงักอยู่กับที่
- **มาตรฐาน:**
  1. หากตัวละครอยู่ในรัศมีฐานของตนเองอยู่แล้ว (`<= 55 studs`) หรืออยู่บนลู่วิ่ง ห้ามสั่ง `MoveTo` ซ้ำซ้อน ให้ยิง Remote ทำงานได้ทันที
  2. ใช้สถานะ `Core.Busy = true` บล็อกไม่ให้งานพื้นหลังแย่งควบคุมการเคลื่อนที่ขณะที่งานสำคัญกำลังดำเนินอยู่

### เสาหลักที่ 5: การจัดการการต่อสู้ การกระเด็น และการตาย (Combat, Knockback & Recovery)
- **ปัญหา:** เมื่อถูกตีจน Ragdoll หรือตายแล้วเกิดใหม่ที่ฐาน สคริปต์ที่เช็คแค่ "ไม่ถือของแล้ว และตัวอยู่บนฐาน" จะเข้าใจผิดว่าส่งของสำเร็จ ทั้งที่ของตกหรือตายระหว่างทาง
- **มาตรฐาน:**
  1. บันทึก Instance ตัวละครก่อนออกเดินทาง (`origChar = LocalPlayer.Character`) หากตัวละครตายหรือเปลี่ยน Instance ต้องรายงานล้มเหลวทันที
  2. สแกนหาไอเทมที่ตกพื้นในบริเวณใกล้เคียงเพื่อเก็บขึ้นมาวิ่งส่งต่อ

### เสาหลักที่ 6: การซิงก์รอบเวลากับเซิร์ฟเวอร์จริง (Server Cycle Synchronization)
- **ปัญหา:** การใช้ `task.wait(45)` เพื่อรอของรีเซ็ต มักคลาดเคลื่อนจากเวลาจริงของเซิร์ฟเวอร์
- **มาตรฐาน:** ผูกเงื่อนไขกับ Attribute จริงของเซิร์ฟเวอร์ เช่น `Workspace.Night:GetAttribute("NightActive")`, `ServerTimeNow` หรือเวลาสิ้นสุดรอบ `PhaseEndsAt`

### เสาหลักที่ 7: วงจรชีวิต ปลอดภัยต่อหน่วยความจำ และแท็บบันทึก Real-Time (Safe Lifecycle & Action Logs)
- **ปัญหา:** บอทรันข้ามคืนแล้วหน่วยความจำบวม (Memory Leak) จาก Event Connection ที่ค้างอยู่ หรือผู้ใช้ไม่รู้สถานะว่าบอทติดปัญหาอะไร
- **มาตรฐาน:** ใช้ `Core:Loop` และ `Core:Connect` สำหรับจัดการ Clean-up 100% พร้อมบันทึกประวัติการทำงานลง Circular Buffer (`Stats.logs` 80 รายการ) แสดงผลบนหน้าต่าง UI

### เสาหลักที่ 8: ระบบจดจำการตั้งค่าและสถานะเปิด-ปิดอัตโนมัติ (Config & Toggle State Persistence)
- **ปัญหา:** เมื่อปิดเกม, Rejoin, หรือรันสคริปต์ใหม่ ผู้ใช้ต้องมานั่งกดเปิด Toggle และเลือกค่า Dropdown เดิมใหม่ทั้งหมด
- **มาตรฐาน:**
  1. รองรับระบบไฟล์ Executor หลายค่าย (`writefile`, `readfile`, `isfolder`, `makefolder`) โดยสร้างโฟลเดอร์แยกตาม PlaceId เช่น `kuykuy_hub/configs/<PlaceId>.json`
  2. มีฟังก์ชัน Safe JSON Encode/Decode พร้อมระบบ Fallback Key-Value Parser หาก `HttpService` ไม่รองรับ
  3. บันทึกอัตโนมัติ (Auto-Save) ทุกครั้งที่มีการสลับ Toggle หรือเปลี่ยนค่า
  4. โหลดค่าอัตโนมัติ (Auto-Load) เมื่อเปิดสคริปต์ และซิงก์สถานะของ UI Knobs/Animations ให้ตรงกับค่าที่บันทึกไว้

### เสาหลักที่ 9: การควบคุมงบประมาณตัวแปร Luau (Register Budget Management)
- **ปัญหา:** ตัวคอมไพเลอร์ Luau มีข้อจำกัดทางสถาปัตยกรรมระดับฮาร์ดแวร์ **ห้ามมีตัวแปร Local เกิน 200 ตัวในสโคปเดียว** หากเขียนตัวแปร `local` เรียงกันเกิน 200 ตัวในฟังก์ชัน `main()` สคริปต์จะระเบิดทันที (`local register limit exceeded`)
- **มาตรฐาน:** ควบคุมจำนวน Local Variables ในฟังก์ชัน `main()` ให้อยู่ต่ำกว่า 100 ตัวแปร โดยการรวมตัวแปรและฟังก์ชันเข้าเป็นตาราง Namespace:
  - `Core`: จัดการ Lifecycle, Flags, Event Connections
  - `Helpers`: ฟังก์ชันช่วยคำนวณ พิกัด และตรวจสอบสถานะตัวละคร
  - `Net`: Wrapper ยิง Remote พร้อม Timeout Guard
  - `Stats`: บันทึกสถิติและ Action Logs
  - `Config`: ตัวจัดการ Save/Load ข้ามเซสชัน
  - `Loops`: ฟังก์ชันลูปการทำงานหลัก

### เสาหลักที่ 10: การจัดการไอเทมและคลังเก็บของแบบครอบคลุม (Universal Inventory & Multi-Remote Fallback)
- **ปัญหา:** เกมแต่ละแมพเก็บไอเทมต่างกัน บางเกมเก็บเป็น Tool ใน Backpack, บางเกมเก็บใน PlayerData เป็น Dictionary ที่ใช้ UUID เป็น Key, บางเกมใช้ Remote แยกกันระหว่างโหมดธรรมดากับโหมดกลายพันธุ์
- **มาตรฐาน:**
  1. สแกนทั้งจาก Tool ในกระเป๋าและในมือ (`getBagTools(true)`) และข้อมูลใน `PlayerData.Inventory`
  2. รองรับชื่อไอเทมจากหลาย Attribute: `ItemName`, `PackName`, `CardName`, `tool.Name`
  3. รองรับการดึง UUID จากทั้ง `item.Id`, `item.PackId`, `item.UUID` และ Key ของ Dictionary (`for k, item in pairs(container) do`)
  4. ทำระบบ Multi-Remote Strategy: หาก Remote หลักถูกปฏิเสธ ให้สลับไปเรียก Remote สำรองโดยอัตโนมัติ

---

## ส่วนที่ 3: ตารางการปรับใช้ตามประเภทของเกม (Genre Adaptation Matrix)

| หมวดหมู่เกม (Genre) | สัญญาณและลักษณะเด่นของแมพ | จุดสำคัญที่ต้องระบุใน Master Prompt | ฟังก์ชันเฉพาะทางที่ต้องมีในโค้ด | ปัญหาที่ต้องระวังเป็นพิเศษ |
| :--- | :--- | :--- | :--- | :--- |
| **1. Steal & Runner** *(เช่น ขโมยแพ็ค, Steal a Brainrot)* | มีด่านเป็นชั้นๆ (Stages), มีบอสวิ่งไล่, มีระบบอุ้มของกลับฐาน | - พิกัดแต่ละด่าน (`STAGE_CENTERS`)<br>- ความเร็วบอสแต่ละด่าน<br>- รอบเวลาบอสรีเซ็ต / กลางคืน | - ฟังก์ชันคัดเลือกของที่คุ้มค่าที่สุด (`getPackScore`)<br>- ตรวจสอบส่งของที่ฐาน (`isSafelyDelivered`)<br>- กู้ของที่ตกพื้น (`recoverDroppedPack`) | - การตายแล้วบอทนึกว่าส่งสำเร็จ<br>- โมเดลของในด่านไกลๆ หายเพราะ StreamingEnabled |
| **2. Training Simulator** *(เช่น Speed Sim, Muscle Legends)* | มีลู่วิ่ง, ดัมเบล, โซนฝึกซ้อมที่ต้องกดรัวๆ, ระบบ Rebirth | - Remote ฝึกซ้อม / ปั๊มค่าสเตตัส<br>- จุดเกิด SafeZone / แท่น Rebirth<br>- ค่าพลังขั้นต่ำสำหรับปลดล็อคโซนถัดไป | - ลูปเข้าเครื่องฝึกซ้อมอัตโนมัติ (`AutoEnter`)<br>- ระบบกดคูณโบนัส/ทำคอมโบ (`BoostPopup`)<br>- ระบบเกิดใหม่อัตโนมัติเมื่อค่าถึงเกณฑ์ (`AutoRebirth`) | - เซิร์ฟเวอร์เตะเพราะส่งคำสั่งฝึกถี่เกินไป (Rate Limit)<br>- โดนผู้เล่นอื่นโจมตีระหว่างฝึกซ้อม |
| **3. Tycoon & Base Builder** *(เช่น Anime Tycoon, Theme Park)* | มีฐานของตนเอง (Plots), มีแผ่นเหยียบซื้อของ (Buttons), มีตู้เก็บเงิน | - Path ของปุ่มซื้อและแผ่นเหยียบ (`Buttons`)<br>- Remote สะสมเงิน/ดึงเงินจากตู้ (`CollectCash`)<br>- รายการปุ่มและราคาเรียงลำดับ | - ค้นหาแผ่นซื้อที่ถูกที่สุดที่เงินพอซื้อ<br>- วาร์ป/เดินไปเหยียบปุ่มตามลำดับราคา<br>- ดึงเงินจากตู้เก็บเงินอัตโนมัติเมื่อถึงเกณฑ์ | - ปุ่มเกิดใหม่ซ้อนทับกัน<br>- เงินไม่พอแต่พยายามเดินไปเหยียบปุ่มราคาแพง |
| **4. Anime RPG & Tower Defense** *(เช่น Anime Defenders, All Star)* | มีการวางยูนิตบนแปลง, การรวม/หลอมยูนิต, คลื่นมอนสเตอร์ | - Remote วางยูนิต / ผสมยูนิต (`Merge`/`Fuse`)<br>- Remote ขายยูนิตส่วนเกิน (`SellItems`)<br>- Remote สวมใส่ตัวที่ดีที่สุด (`EquipBest`) | - ลูปฟักไข่/เปิดแพ็คที่พร้อมเปิดอัตโนมัติ<br>- ลูปตรวจจับยูนิตซ้ำเพื่อรวมร่าง (`AutoMerge`)<br>- ลูปขายตัวระดับต่ำกว่าที่กำหนดอัตโนมัติ | - วางยูนิตในจุดที่ทับซ้อนกัน (Overlap)<br>- สับสนระหว่างการรวมแพ็ค (Packs) กับการหลอมตัวละคร (Units) |
| **5. Clicker & Tapping Games** *(เช่น Clicker Simulator, Tap Tap)* | มีระบบคลิกปั๊มแต้ม, สัตว์เลี้ยงช่วยคูณ (Pets), ฟักไข่สุ่มตัว | - Remote คลิกปั๊มแต้ม (`Click`/`Tap`)<br>- Remote ฟักไข่สุ่มสัตว์เลี้ยง (`HatchEgg`)<br>- Remote สวมใส่สัตว์เลี้ยงดีที่สุด (`EquipBestPets`) | - ลูปคลิกด้วยความเร็วสูงสุดที่เซิร์ฟเวอร์ไม่ดีเลย์<br>- ระบบเลือกฟักไข่เฉพาะตู้ที่กำหนด<br>- ระบบลบสัตว์เลี้ยงระดับต่ำอัตโนมัติ (Auto-Delete) | - กระเป๋าสัตว์เลี้ยงเต็มจนฟักไข่ต่อไม่ได้<br>- เซิร์ฟเวอร์แบนเพราะคลิกเร็วเกินความเป็นมนุษย์ |
| **6. Fishing & Gathering** *(เช่น Fisch, Mining Simulator)* | มีจุดตกปลา/ขุดแร่, มินิเกมกดตามจังหวะ, ค่าน้ำหนักกระเป๋า | - Remote เหวี่ยงเบ็ด / ดึงปลา (`Cast`/`Reel`)<br>- Remote ขายของทั้งหมดในกระเป๋า (`SellAll`)<br>- พิกัดจุดตกปลาแต่ละบ่อและร้านค้า | - บอทแก้เกมจังหวะดึงปลาอัตโนมัติ (Auto-Shake / Reel)<br>- ตรวจสอบน้ำหนักกระเป๋าเต็มแล้ววาร์ปไปขาย<br>- ซื้อเหยื่อและเบ็ดระดับสูงขึ้นอัตโนมัติ | - มินิเกมมีระบบสุ่มจังหวะกันบอท<br>- เบ็ดตกปลาหลุดมือหรือตัวละครจมน้ำตาย |

---

## ส่วนที่ 4: โค้ดแม่แบบมาตรฐานวิศวกรรม S-Tier (Luau Reference Boilerplate v3.0)

```lua
-- =====================================================================
-- KUYKUY HUB UNIVERSAL CORE BOILERPLATE (v3.0 Production Standard)
-- สถาปัตยกรรมแม่แบบมาตรฐานวิศวกรรมสำหรับ Roblox Game Automation ทุกแมพ
-- =====================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId

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
    if self._loops[name] then pcall(task.cancel, self._loops[name]) end
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

-- 3. CONFIG & TOGGLE STATE PERSISTENCE (เสาหลักที่ 8)
local Config = {
    Folder = "kuykuy_hub",
    File = string.format("kuykuy_hub/config_%s.json", tostring(PlaceId)),
    Cache = {},
}

function Config.Save()
    local data = {}
    for k, v in pairs(Core.Flags) do data[k] = v end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false end
    if writefile then
        pcall(function()
            if isfolder and makefolder and not isfolder(Config.Folder) then makefolder(Config.Folder) end
            writefile(Config.File, encoded)
        end)
    end
    Config.Cache = data
    return true
end

function Config.Load()
    if not (readfile and isfile and isfile(Config.File)) then return false end
    local ok, content = pcall(readfile, Config.File)
    if not ok or not content or content == "" then return false end
    local okDecode, decoded = pcall(function() return HttpService:JSONDecode(content) end)
    if okDecode and type(decoded) == "table" then
        for k, v in pairs(decoded) do Core.Flags[k] = v end
        Config.Cache = decoded
        return true
    end
    return false
end

-- 4. NETWORK WRAPPER (TIMEOUT GUARD + MULTI-REMOTE FALLBACK)
local Net = { _last = {}, Paths = {} }

function Net.Fire(remote, cooldown, ...)
    if not Core._alive or not remote then return false end
    local key = typeof(remote) == "string" and remote or remote:GetFullName()
    local now = os.clock()
    if cooldown and (now - (Net._last[key] or 0)) < cooldown then return false end
    Net._last[key] = now
    local args = table.pack(...)
    return (pcall(function()
        local inst = typeof(remote) == "string" and Core.Helpers.ResolvePath(remote) or remote
        if inst and inst:IsA("RemoteEvent") then inst:FireServer(table.unpack(args, 1, args.n)) end
    end))
end

function Net.Invoke(remote, ...)
    if not Core._alive or not remote then return false, "DEAD_OR_NIL" end
    local inst = typeof(remote) == "string" and Core.Helpers.ResolvePath(remote) or remote
    if not inst or not inst:IsA("RemoteFunction") then return false, "INVALID_REMOTE" end

    local args = table.pack(...)
    local done = false
    local results = {}
    task.spawn(function()
        results = table.pack(pcall(function()
            return inst:InvokeServer(table.unpack(args, 1, args.n))
        end))
        done = true
    end)

    local t0 = os.clock()
    while not done and (os.clock() - t0) < 3.5 and Core._alive do
        task.wait(0.03)
    end

    if not done then return false, "TIMEOUT" end
    if not results[1] then return false, results[2] end
    return true, table.unpack(results, 2, results.n)
end

-- 5. HELPERS & STREAMING GUARD
local Helpers = {}
Core.Helpers = Helpers

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

ก่อนจะส่งงานหรือถือว่าสคริปต์แมพใดๆ เสร็จสมบูรณ์ ต้องผ่านเกณฑ์ประเมิน 10 ข้อนี้:
1. [ ] **Syntax Verification:** ผ่านการตรวจสอบด้วย `luaparse` (Luau AST Parser) ไม่มี Syntax Error
2. [ ] **Register Budget Safety:** จำนวน Local Variables ในฟังก์ชัน `main()` อยู่ในเกณฑ์ต่ำกว่า 110 ตัวแปร (ห้ามเกิน 200)
3. [ ] **Timeout Guard Active:** ไม่มีคำสั่ง `InvokeServer` ใดที่ถูกเรียกแบบลอยๆ โดยไม่มี Timeout ครอบ
4. [ ] **Anti-Spam Pre-check:** มีการตรวจเช็คเงินสดและจำนวนของจริงก่อนยิงคำสั่งซื้อ/อัปเกรด/รวมของ
5. [ ] **Streaming Safety:** มีการเรียก `RequestStreamAroundAsync` ก่อนเข้าถึงวัตถุที่อยู่ไกล
6. [ ] **No Movement Fighting:** ลูปงานแต่ละตัวไม่แย่งการเดิน `MoveTo` ไปคนละทิศทาง
7. [ ] **Safe Zone Verification:** การตรวจการส่งของหรือเคลมของตรวจสอบจากพิกัดจริงและสถานะตัวละครเดิม ไม่หลงกลการตายเกิดใหม่
8. [ ] **Config Persistence Functional:** ทดสอบสลับ Toggle แล้วค่าบันทึกลงไฟล์ และโหลดค่าเดิมกลับมาได้ถูกต้อง
9. [ ] **Universal Inventory Scan:** สแกนหาไอเทมครอบคลุมทั้งจาก Tool ในกระเป๋า/ในมือ และข้อมูลใน `PlayerData`
10. [ ] **Memory Cleanliness:** ทดสอบปิดสคริปต์ด้วย `Core:Destroy()` แล้ว เธรดและ UI หายหมดจด ไม่ค้างในหน่วยความจำ