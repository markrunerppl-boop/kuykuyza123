# MASTER PROMPT: KUYKUY HUB — ขโมยแพ็คอนิเมะ (STEAL ANIME PACKS)
> **แม่แบบคำสั่งพร้อมใช้งานทันที (Ready-to-Use Master Prompt) สำหรับสร้างหรือสร้างซ้ำสคริปต์ Kuykuy Hub ของเกม ขโมยแพ็คอนิเมะ (PlaceId 133151378618377 และ Dungeon 135412798316370)**
> *สามารถคัดลอกข้อความในกรอบด้านล่างนี้ทั้งหมด แล้วส่งให้ AI Agent (Antigravity, Claude, ChatGPT) เพื่อสร้างสคริปต์ `main.lua` ตัวเต็มได้ใน One-Shot 100%*

---

```markdown
คุณคือ Senior Luau Systems Engineer และ Roblox Reverse-Engineering Specialist ระดับโลก ที่เชี่ยวชาญการสร้างสคริปต์ Game Automation Hub คุณภาพสูงตามมาตรฐาน "Kuykuy Hub Universal Architecture"

เป้าหมายสูงสุด: จงเขียนสคริปต์ Luau ไฟล์เดียวจบ (Single-File Production Script) สำหรับเกม "ขโมยแพ็คอนิเมะ" (Steal Anime Packs) รองรับทั้ง Main Game และ Dungeon โดยต้องมีความเสถียรสูงสุด ไร้บั๊ก 100% ไม่หลุดการทำงาน บันทึกการตั้งค่าข้ามเซสชันได้ และปฏิบัติตาม "12 เสาหลักวิศวกรรม Kuykuy Hub" อย่างเคร่งครัด

### 1. ข้อมูลระบบและบริบทของเกม (Game Context):
- Main PlaceId: 133151378618377 (แมพหลัก ขโมยแพ็คอนิเมะ)
- Dungeon PlaceId: 135412798316370 (แมพ Double Dungeon)
- ประเภทของเกม (Genre): Steal & Carry / Runner + Training Simulator + Anime Dungeon RPG
- สกุลเงินและค่าสถานะหลัก (Currencies & Stats):
  * Cash (เงินสดในเกม), Gems (เพชร), Speed (ความเร็ววิ่ง), Rebirths (การเกิดใหม่)
- จุดเกิดและฐานผู้เล่น (Plot / Base Structure):
  * โฟลเดอร์ฐาน: Workspace.Plots (สแกนหาฐานของผู้เล่น LocalPlayer อัตโนมัติ)
  * แท่นวางเพาะแพ็ค: Plot.PlotModel.PlacedPacks (สล็อต 1 ถึง 12+)
  * ลู่วิ่งบนฐาน: Plot.Treadmil (วิ่งปั๊ม Speed)
  * ประตูวาร์ปดันเจี้ยน: Workspace["dungeon portal"].DungeonPad

### 2. รายการ Remotes & Endpoints สำคัญ (Reverse-Engineered 100%):
- RemoteFunctions (InvokeServer) [ต้องมี Timeout Guard 3.5s เสมอ]:
  * ReplicatedStorage.Remotes.Packs.PlaceOwned: InvokeServer(packId: string, slotIndex: number) -- วางแพ็กลงแท่น
  * ReplicatedStorage.Remotes.Packs.OpenPlaced: InvokeServer(packId: string) -- เปิดแพ็คที่โตเต็มวัยบนแท่น
  * ReplicatedStorage.Remotes.Packs.OpenBackpack: InvokeServer(packId: string, amount: number) -- เปิดแพ็คในกระเป๋า
  * ReplicatedStorage.Remotes.Packs.Merge: InvokeServer(id1: string, id2: string) -- รวมแพ็คซ้ำ 2 ชิ้น
  * ReplicatedStorage.Remotes.Packs.SellPacks: InvokeServer(packIdsTable: table) -- ขายยูนิตขยะเป็นชุด
  * ReplicatedStorage.Remotes.Packs.EquipBest: InvokeServer() -- สวมใส่แพ็ค/ตัวละครที่ดีที่สุดลงฐาน
  * ReplicatedStorage.Remotes.Mutate.Merge: InvokeServer(id1: string, id2: string, id3: string) -- กลายพันธุ์ยูนิต 3 ตัว
  * ReplicatedStorage.Remotes.Coaches.Purchase: InvokeServer(coachId: string) -- ซื้อโค้ช
  * ReplicatedStorage.Remotes.Coaches.Equip: InvokeServer(coachKey: string) -- สวมใส่โค้ช
  * ReplicatedStorage.Remotes.Auras.Purchase: InvokeServer(auraId: string) -- ซื้อออร่า
  * ReplicatedStorage.Remotes.Auras.Equip: InvokeServer(auraKey: string) -- สวมใส่ออร่า
  * ReplicatedStorage.Remotes.Upgrades.TreadmillUpgrade: InvokeServer() -- อัปเกรดลู่วิ่ง
  * ReplicatedStorage.Remotes.Upgrades.BaseUpgrade: InvokeServer() -- อัปเกรดฐาน
  * ReplicatedStorage.Remotes.LuckMachine.Upgrade: InvokeServer() -- อัปเกรดเครื่องเพิ่มโชค
  * ReplicatedStorage.Remotes.Rebirth.Rebirth: InvokeServer() -- เกิดใหม่ Rebirth
  * ReplicatedStorage.Remotes.Daily.Claim: InvokeServer() -- เคลมรางวัลประจำวัน
  * ReplicatedStorage.Remotes.Index.ClaimReward: InvokeServer(stage: string, name: string, kind: string) -- เคลม Index
  * ReplicatedStorage.Remotes.ClaimOfflineGems: InvokeServer() -- เคลมเพชร Offline
  * ReplicatedStorage.Remotes.Dungeons.Enter: InvokeServer() -- เข้าร่วมดันเจี้ยน
  * ReplicatedStorage.Remotes.Dungeons.Exit: InvokeServer() -- ออกจากดันเจี้ยน
  * ReplicatedStorage.Remotes.Dungeons.TriggerUltimate: InvokeServer(slotIndex: number) -- ปล่อยท่าไม้ตายยูนิต
  * ReplicatedStorage.Remotes.Dungeons.Attack: InvokeServer(targetId: string) -- สั่งยูนิตโจมตี
  * ReplicatedStorage.Remotes.DungeonPartySetTeam: InvokeServer(teamTable: table) -- จัดทีมตัวละครลงดันเจี้ยน
- RemoteEvents (FireServer):
  * ReplicatedStorage.Remotes.Treadmill.Boost: FireServer() -- กดคอมโบเร่งความเร็วบนลู่วิ่ง
  * ReplicatedStorage.Remotes.Treadmill.SetTraining: FireServer(isTraining: boolean) -- แจ้งสถานะวิ่ง

### 3. รายการ Config Modules & POIs:
- Config Modules (ReplicatedStorage.Shared.Configs):
  * StageConfig, PacksConfig, CharacterConfig, MutationConfig, SpeedConfig, TreadmillConfig, BaseUpgradeConfig, LuckMachineConfig, IndexConfig, CoachesConfig, AurasConfig, RebirthConfig, TowerConfig
- Utilities:
  * ReplicatedStorage.Shared.Utilities.DungeonUtil
  * ReplicatedStorage.Shared.Modules.DataReceiver.PlayerData
- POIs ใน Workspace:
  * ด่านขโมย: Workspace.Game.Packs (Stage1 ถึง StageN มีโฟลเดอร์ย่อย SpawnedPacks และ Enemy)
  * เครื่องหลอม: Workspace.MutationMachine หรือ Workspace.MergeMachine
  * วงจรกลางคืน: Workspace.Night (มี Attributes: NightActive: boolean, NightPhaseEndsAt: number)

### 4. รายละเอียดฟังก์ชันระบบที่ต้องสร้าง (Features Specification):

1. **ระบบขโมยแพ็คอัจฉริยะ (Smart Steal & Dynamic Stages):**
   - **Dynamic Stages Detection:** ใช้ `Helpers.GetMaxStage()` ตรวจหาด่านสูงสุดจริงจากแมพ (`Workspace.Game.Packs`) และ `StageConfig.Stages` ห้ามล็อกตัวเลขไว้แค่ 13 ด่าน
   - **Dynamic Stage Centers & Corridor Pathing:** มีฟังก์ชัน `Helpers.GetStageCenter(stageNum)` หาพิกัดจาก Enemy/แพ็คจริง หรือ Extrapolate ตามแกนวิ่งเลนกลาง (`Z = -365`, `Y = 68`) หากเป็นด่านที่อยู่ไกล ให้วิ่งเกาะเลนกลาง (Corridor) ไปจนถึงหน้าด่านก่อนเลี้ยวเข้าหาแพ็ค
   - **Outrun Margin:** คำนวณความเร็วตัวละครเทียบกับบอส `mySpeed >= bossSpeed * OutrunMargin` (กรองเฉพาะด่านที่วิ่งหนีทัน) และมีโหมด "Target Fastest Boss Only"
   - **Steal Execution:** เข้าประชิดตัวแพ็คระยะ <= 2.5 studs กด ProximityPrompt "StealPrompt" นำกลับส่งที่ฐาน และมีระบบกวาดเก็บแพ็คที่ตกพื้นด้วย Tag "SpawnedPack"
   - **Anti-Ragdoll:** ลบสถานะล้ม/โดนตี (`Helpers.RecoverFromHit`) เพื่อให้ลุกวิ่งต่อได้ทันที

2. **ระบบเกรดแพ็คแบบ Real-time (Dynamic Rarities & Auto Sell):**
   - **Dynamic Rarities:** ดึงเกรดทั้งหมดจาก `PacksConfig.RarityRank` มาสร้างตัวเลือกบน UI อัตโนมัติ และมีระบบ Auto-Allow หากพบแพ็คเกรดใหม่ที่เกมเพิ่งอัปเดตเข้ามา
   - **Auto Sell Units:** สแกนยูนิตขยะที่มี Rank ต่ำกว่าเกณฑ์ที่ตั้งไว้ใน UI (เช่น ต่ำกว่า Mythical 6) ขายทิ้งเป็นชุดผ่าน Remote `SellPacks` พร้อมระบบล็อกตัวกลายพันธุ์ (Keep Mutated) และยูนิต Favorite

3. **ระบบจัดการฐานอัตโนมัติ (Base Maintenance):**
   - **Auto Open Placed:** ตรวจจับแพ็คบนแท่นที่โตเต็มวัย (`GrowthEndsAt <= now`) แล้วกดยิงเปิดทันที
   - **Auto Place Packs:** หยิบแพ็คที่มีค่าตัวคูณสูงสุดในกระเป๋ามาวางลงสล็อตแท่นว่างที่ฐาน
   - **Auto Merge Packs:** รวมแพ็คซ้ำระดับเดียวกัน 2 ชิ้น
   - **Auto Fuse Units:** หลอมยูนิตซ้ำระดับเดียวกัน 3 ตัวที่เครื่องหลอม
   - **Auto Equip Best:** สวมใส่ยูนิตที่ดีที่สุดลงฐาน

4. **ระบบฝึกซ้อมและเศรษฐกิจ (Training & Upgrades):**
   - **Auto Treadmill:** เดินเข้าลู่วิ่งเมื่อไม่ได้ขโมยของ พร้อมกดคอมโบ `Treadmill.Boost` ปั๊ม Speed อัตโนมัติ
   - **Auto Upgrades:** อัปเกรดลู่วิ่ง, ฐาน, และเครื่องโชค (ต้องตรวจสอบค่าเงินสดก่อนยิง Remote ป้องกัน Error Toast)
   - **Auto Coach & Aura:** ซื้อและสวมใส่โค้ช/ออร่าที่มีตัวคูณสูงสุดใน Stock
   - **Auto Rebirth:** เกิดใหม่อัตโนมัติเมื่อค่า Speed ถึงเกณฑ์ที่กำหนด
   - **Auto Claim:** เคลม Offline Gems, รางวัลประจำวัน Daily, และ Index Rewards อัตโนมัติ

5. **ระบบดันเจี้ยน (Double Dungeon Subsystem):**
   - **Auto Enter Dungeon:** เมื่อประตูวาร์ปเปิด (`Workspace["dungeon portal"]`) ให้จัดทีมยูนิตที่ดีที่สุด (`Helpers.GetBestDungeonTeam` และยิง `DungeonPartySetTeam`) เดินไปแตะ DungeonPad แล้วยิง `Dungeons.Enter`
   - **Strict Ultimate Readiness Check:** ในแมพดันเจี้ยน (`PlaceId 135412798316370`) ก่อนยิงคำสั่ง `Dungeons.TriggerUltimate` ต้องตรวจสอบ UI อย่างเข้มงวดว่าท่าไม้ตายพร้อมใช้ 100% จริงๆ เท่านั้น (กรอบสีทองสว่างขึ้น, หลอดคูลดาวน์เต็ม 1.0, ปุ่ม Key แสดงผล)
   - **Auto Attack & Exit:** สั่งยูนิตตีมอนสเตอร์ และออกจากห้องอัตโนมัติเมื่อจบเกม

6. **Kuykuy Dark Neon UI & Config Persistence:**
   - GUI ธีมมืดม่วงนีออน 5 แท็บ: 1. ฟาร์ม & ขโมย | 2. แพ็ก & ยูนิต | 3. อัปเกรด | 4. ดันเจี้ยน | 5. ตั้งค่า & บันทึก
   - Dropdown แบบ Multi-Select เลือกด่านและเกรดที่ต้องการขโมย
   - บันทึกประวัติการทำงานลง Circular Buffer (`Stats.logs` 80 รายการ) แสดงผล Real-time
   - บันทึกสถานะทุกสวิตช์ลงไฟล์ `kuykuy_steal111_config.json` อัตโนมัติ (ข้ามเซสชันได้)

7. **ข้อจำกัดวิศวกรรม (Engineering Constraints):**
   - ตัวแปร Local ระดับบนสุดในฟังก์ชัน `main()` ต้องไม่เกิน 110 ตัวแปร (Register Budget Guard) โดยต้องจัดกลุ่มเข้า Namespace Tables (`Core`, `Helpers`, `Net`, `Stats`, `Config`, `Loops`)
   - ทุก `InvokeServer` ต้องครอบ Timeout Guard 3.5 วินาที
   - มีฟังก์ชัน `Core:Destroy()` สำหรับล้างสถานะสะอาดเมื่อรันซ้ำ

จงเขียนโค้ดภาษา Luau ตัวเต็มที่สมบูรณ์แบบ ไวยากรณ์ถูกต้อง 100% พร้อมรันได้ทันที
```
