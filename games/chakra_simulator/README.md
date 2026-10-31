# Chakra Training Simulator - QA Automation & Controller Pro

## โครงสร้างสถาปัตยกรรม (Architecture)
โฟลเดอร์นี้รวบรวมระบบทดสอบและบอทอัตโนมัติสำหรับเกม **Chakra Training Simulator** 
แยกโฟลเดอร์ออกจากสคริปต์แมพอื่นใน `kuykuyza123` เพื่อให้ปรับปรุงและแก้ไขได้ง่าย

### ไฟล์ในโฟลเดอร์
- `main.lua`: สคริปต์หลักพร้อมหน้าต่าง UI แบบแยกแท็บ (Tabbed UI), ฟังก์ชันย่อหน้าต่าง (Minimize Pill), และระบบบันทึกประวัติการทำงาน (Audit Logger)

### คุณสมบัติหลัก
1. **Combat & Stages**: ลุยด่าน Stage 1 - 15 อัตโนมัติ, ระบบ Kiting รักษาระยะ 15 studs, ถอยกลับจุดเซฟเมื่อเลือดต่ำ
2. **Boss Raid (Kurama)**: ตีบอสคุรามะในระยะปลอดภัย (Safe Orbit 76 studs, Height Y=18) ไม่โดนดาเมจ 100%
3. **Training & Best Spot**: คำนวณจุดฝึกที่ดีที่สุดของแต่ละโลก (Shinobi Lands ถึง Cosmic Void) อิงตาม Rebirths
4. **Gear & Pets**: หลอมสัตว์เลี้ยง 4 ตัวอัตโนมัติ (Pet Fuser), สวมใส่ Aura, Eye, Pets ที่ดีที่สุด
5. **Progression**: ระบบ Rebirth, รับของขวัญประจำวัน, แลก Redeem Codes อัตโนมัติ
6. **Audit Logs & Stats**: บันทึกการทำงานแบบเรียลไทม์พร้อมตัวนับสถิติในหน้า GUI
