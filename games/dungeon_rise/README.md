# ดันเจี้ยนลุกขึ้น (Dungeon Rise) - QA Automation & Controller Pro V2

## โครงสร้างสถาปัตยกรรม (Architecture)
โฟลเดอร์นี้รวบรวมระบบทดสอบและบอทอัตโนมัติสำหรับเกม **ดันเจี้ยนลุกขึ้น (Dungeon Rise / Solo Leveling)** โดยกลุ่มผู้สร้าง **CL GAMES!** (Universe ID: `7074860883`)

### ฟังก์ชันใหม่ใน V2 (อัปเดตล่าสุด)
1. **แก้ปัญหาโดนเตะ (Non-Kick Smooth Movement)**:
   - ยกเลิกการ Instant CFrame Teleport ที่เสี่ยงต่อการถูกตรวจจับและโดนเซิร์ฟเวอร์เตะ
   - เปลี่ยนมาใช้ `Humanoid:MoveTo` พร้อมการเว้นระยะโจมตีและ Safe Kiting 16 studs อย่างสมบูรณ์แบบ
2. **ระบบลงดันเจี้ยนไม่จำกัดรอบ (Unlimited Auto Re-run Dungeons)**:
   - รองรับกุญแจทุกประเภทในเกม (Key ทั่วไป, FairyKey, DSKey, Solo2Key, XWinterKey, SHKey, AoTKey ฯลฯ)
   - เมื่อดันเจี้ยนจบ จะทำการเริ่มรอบใหม่ทันทีจนกว่ากุญแจจะหมดหรือดันเจี้ยนจะหายไป
3. **ระบบลงหอคอยระบุชั้น & วนซ้ำ (Tower & Castle Specific Floor Loop)**:
   - รองรับ Infernal Castle, Infinite Castle, Infinite Labyrinth, Infinite Mode
   - สามารถระบุชั้นเป้าหมายที่ต้องการลงซ้ำได้ (เช่น ชั้น 950 หรือชั้นอื่นๆ) พร้อมปุ่มปรับ `[-25]` `[+25]`
   - ระบบเร่งความเร็วหอคอยอัตโนมัติ (Auto SpeedUp)
   - เมื่อจบหอคอยจะทำการลงซ้ำชั้นเดิมแบบไม่จำกัด
4. **กองทัพเงา & สกัดเงา (55 Shadow Army & Auto Arise)**:
   - สั่งกองทัพเงา 55 ตัวพุ่งโจมตีเป้าหมายอัตโนมัติ
   - สกัดเงา (EnemyCapture) ทันทีที่มอนสเตอร์ตาย
5. **Modern Dashboard UI & Audit Logger**:
   - หน้าต่างแยก 7 แท็บเมนู ย่อเป็น Floating Pill ได้
   - บันทึกประวัติ Action ย้อนหลังพร้อมตัวนับสถิติ
