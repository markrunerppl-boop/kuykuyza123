# ⚡ Anime Adventures - QA Automation & Controller

สคริปต์ทดสอบระบบอัตโนมัติ (Automated QA Tester) และ NPC Controller สำหรับเกม **[☀️อัพเดท 21🏖️] การผจญภัยอนิเมะ (Anime Adventures)** (Place ID: `8304191830`)

---

## 🚀 วิธีการรัน (Loadstring)

คัดลอกคำสั่งด้านล่างไปวางใน Script Executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/markrunerppl-boop/kuykuyza123/main/games/anime_adventures/main.lua"))()
```

---

## 🛡️ จุดเด่นและสถาปัตยกรรมระบบ (Architecture)

1. **Safe Module Loading:**
   * ครอบการ `require()` โมดูลภายนอกด้วย `pcall`
   * มี Fallback Mock Configuration หากไม่พบ Module เพื่อป้องกันข้อผิดพลาดที่ทำให้ระบบหยุดทำงาน

2. **Centralized String Constants (`Config.Events` / `Config.UI`):**
   * รวมชื่อ Remote ทั้งหมด เช่น `buy_from_banner`, `equip_unit`, `unequip_all`, `equip_best`
   * ช่วยให้ดูแลและอัปเดตง่ายเมื่อเกมเปลี่ยนชื่อ Remote

3. **Null-Safety สำหรับ UI & Objects:**
   * ใช้ฟังก์ชันกลาง `SafeUtils.SafeFind` ค้นหา Instance และตรวจสอบ `nil` ทุกครั้ง
   * หาก Object หรือ UI โดนเปลี่ยนชื่อ จะแจ้งเตือนระดับ Warning โดยไม่ทำให้ระบบหลักพัง

4. **Isolating Worker Tasks (Main Loop):**
   * แยก Task ในลูป Worker ด้วย `pcall` อิสระ
   * หากมี Task ใดเกิดข้อผิดพลาด ลูปหลักและ Task อื่นๆ ยังคงทำงานต่อไปได้ตามปกติ

5. **Circuit Breaker System:**
   * ตรวจนับความผิดพลาด หากเกิด Error ติดต่อกันเกิน 3 ครั้ง ระบบจะตัดวงจร (Trip) พักชั่วคราว เพื่อป้องกันการสแปมคำสั่งไปยังเซิร์ฟเวอร์

6. **Interactive Modern UI & Live Audit Log:**
   * หน้าต่าง UI แบบ Draggable ลากย้ายตำแหน่งได้
   * แสดงแท็บสถานะ FSM (`STATE: IDLE / TESTING / MOVING / BROKEN`)
   * กล่องแสดง Log แบบเรียลไทม์บนหน้าจอ แยกประเภทสีตามความสำคัญ
