# ARCHITECTURE.md - โยนอาหารให้สัตว์
**หน้าที่:** อธิบายภาพรวมโปรเจกต์และบริบทเกมเพื่อให้ AI เข้าใจกลไกการทำงาน

## 1. จุด Entry Point
- `main.lua`: ลูปควบคุมการทำงาน

## 2. บริบทข้อมูลเจาะลึก (Deep Extracted Context) *สำคัญมาก*
- **วิเคราะห์แหล่งเก็บข้อมูลเจ้าของ Plot (Plot Owner):**
  - บนตัว Plot (`5`): `OwnerUserId=0, PlotIndex=5`
  - บนตัว LocalPlayer: `__UG=true, PlotIndex=2, BestIncome=30000000, Pass_DoubleCash=false, TrailXpMultiplier=1, Pass_DoubleXp=false, Training=false, Dreamland=true, CashMultiplier=1, IncomeRate=37396596, TrailCashMultiplier=1, DataLoaded=true, XpMultiplier=1, __UG_FIRST_SESSION=false, __UG_NEW=true`
- **ตัวอย่าง Pack Tool ของจริง:** `Players.SUN_S636.Backpack.Snake` -> ข้อมูล: `(Weight=2.5, Income=11250, AnimalName=Snake, SizeMult=1, Mutation=Gold, AnimalId=a9, Rarity=Uncommon)`
- ไม่พบ Treadmill (ลู่วิ่ง) ใน Plot
- ไม่พบแพ็คที่วางอยู่บน Plot
- ไม่พบแพ็คที่เกิดบน Map/Stage (Game.Packs)
- **คำแนะนำสำหรับ AI:**
  - ให้ใช้ชื่อ Attribute หรือ ValueBase จากตัวอย่างของจริงด้านบนในการดึงข้อมูล UUID/ID ต่างๆ
  - หาก Args ของ Remote ต้องการพิกัด ให้แปลงเป็น `Vector3.new(x, y, z)`
  - หาก Args ต้องการ Object ตัวตนจริงๆ ให้หาจาก Path ห้ามส่งเป็น String

## 3. Module หลัก
- พบ Scripts ทั้งหมด: `662` ไฟล์