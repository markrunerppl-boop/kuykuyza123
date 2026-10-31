# ดันเจี้ยนลุกขึ้น (Dungeon Rise) - QA Automation & Controller Pro

## โครงสร้างสถาปัตยกรรม (Architecture)
โฟลเดอร์นี้รวบรวมระบบทดสอบและบอทอัตโนมัติสำหรับเกม **ดันเจี้ยนลุกขึ้น (Dungeon Rise / Solo Leveling)** โดยกลุ่มผู้สร้าง **CL GAMES!**
Universe ID: `7074860883`

### ไฟล์ในโฟลเดอร์
- `main.lua`: สคริปต์หลักที่เชื่อมต่อกับระบบ BridgeNet2 ของเกมโดยตรง (`GENERAL_EVENT`, `ENEMY_EVENT`, `PET_EVENT`, `DUNGEON_EVENT`)

### ฟังก์ชันที่รองรับตามระบบจริงของเกม
1. **Auto Weapon Attack (M1)**: โจมตีด้วยอาวุธผ่าน `WeaponsModule.Click` และ BridgeNet2 `ENEMY_EVENT` (`PunchAttack`)
2. **Auto Shadow Army (กองทัพเงา)**: สั่งกองทัพเงา/สัตว์เลี้ยงโจมตีมอนสเตอร์รอบตัวอัตโนมัติผ่าน `PetsController.AutoEnemy`
3. **Auto Arise (สกัดเงา)**: เมื่อมอนสเตอร์ตายและเข้าสู่สถานะ Arise ระบบจะส่งสัญญาณ `EnemyCapture` เพื่อสกัดเงาเข้าสู่กองทัพทันที
4. **Auto Target & Movement**: ค้นหามอนสเตอร์ที่ใกล้ที่สุดใน `workspace.__Main.__Enemies.Server`
5. **Auto Equip Best Shadows**: สวมใส่เงาที่มีสเตตัสสูงสุดอัตโนมัติผ่าน `PET_EVENT` (`EquipBest`)
6. **Auto Claim Quests & Gifts**: รับรางวัลเควสต์และของขวัญเล่นเกมฟรีอัตโนมัติ
7. **Tabbed Modern UI & Minimize**: หน้าต่างแยก 5 หมวดหมู่ สลับแท็บง่าย และกดย่อเป็น Floating Pill ได้
8. **Audit Logs & Stats**: ระบบบันทึกประวัติการทำงานแบบเรียลไทม์พร้อมตัวนับสถิติ
