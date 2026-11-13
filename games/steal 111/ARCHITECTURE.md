# ARCHITECTURE.md - ขโมยแพ็คอนิเมะ
**หน้าที่:** อธิบายภาพรวมโปรเจกต์และบริบทเกมเพื่อให้ AI เข้าใจกลไกการทำงาน

## 1. จุด Entry Point
- `main.lua`: ลูปควบคุมการทำงาน

## 2. บริบทข้อมูลเจาะลึก (Deep Extracted Context) *สำคัญมาก*
- **วิเคราะห์แหล่งเก็บข้อมูลเจ้าของ Plot (Plot Owner):**
  - บนป้าย Sign (`Workspace.Plots.5.Sign`): `(ไม่มี Attribute/Value)` (ข้อความบนป้าย: `@UNOWNED`)
  - บนตัว LocalPlayer: `PackLuckBatchRemaining=2, IndexSpeedBoost=3.67, LuckPotionMultiplier=2, FriendsInServer=1, EnemyChased=false, TouchInput=false, IntroCinematic=Skip, UpdateCinematic=Skip, TreadmillLevel=Level10, SpeedPotionMultiplier=2, Rebirths=7, TradeUnlocked=true, MutationPotionMultiplier=2, Title=SideCharacter, EquippedCoach=Levi, PhoneRevives=0, TrapCount=3, HatchLuckLevel=7835`
- **ตัวอย่าง Pack Tool ของจริง:** `Players.markergg7.Backpack.Kanpechi` -> ข้อมูล: `(ItemName=Kanpechi, CardIsPack=false, SortWeight=606, CharacterName=Kanpechi, CardWeight=(606Kg), HeldCharacterLifecycleBound=true, CharacterIdleAnimationId=81002917748736, CardPrice=$477,6B, ItemWeightText=606 KG, SortCash=477631373514, ItemCategory=Units, HeldOverhead=true, ItemRarity=Cosmic, CardRarity=Cosmic, ItemMetricText=$31,8B/s, CardIncome=$31,8B/s, CardIcon=rbxassetid://76203146198216, PackId=b6cba1ea-6701-4208-a0c4-3684bdca9385, SortRarity=7)`
- **ตัวอย่าง Treadmill:** `Workspace.Plots.5.Treadmil` -> ข้อมูล: `((ไม่มี Attribute/Value))`
  - *หมายเหตุ: ถ้าหา UUID ไม่เจอใน Attribute อาจซ่อนอยู่ใน Child/Model ของมัน หรือเซิร์ฟเวอร์ส่งมาให้ตอนขึ้นลู่วิ่ง*
- **ตัวอย่างแพ็คบน Plot (PlacedPacks):** `Workspace.Plots.3.PlotModel.PlacedPacks.Beast Titan` -> ข้อมูล: `(Pack=Pack4, Rarity=Cosmic, Weight=3417, HiddenBySetting=true, PackId=c81a4e91-6982-4e10-9e69-9422947ee8ae)`
- **ตัวอย่างแพ็คบน Stage/Map (Game.Packs):** `Workspace.Game.Packs.Stage1` -> ข้อมูล: `((ไม่มี Attribute/Value))`
- **คำแนะนำสำหรับ AI:**
  - ให้ใช้ชื่อ Attribute หรือ ValueBase จากตัวอย่างของจริงด้านบนในการดึงข้อมูล UUID/ID ต่างๆ
  - หาก Args ของ Remote ต้องการพิกัด ให้แปลงเป็น `Vector3.new(x, y, z)`
  - หาก Args ต้องการ Object ตัวตนจริงๆ ให้หาจาก Path ห้ามส่งเป็น String

## 3. Module หลัก
- พบ Scripts ทั้งหมด: `513` ไฟล์