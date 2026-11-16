# ARCHITECTURE.md - ขโมยแพ็คอนิเมะ
**หน้าที่:** อธิบายภาพรวมโปรเจกต์และบริบทเกมเพื่อให้ AI เข้าใจกลไกการทำฟาร์ม

## 1. จุด Entry Point
- `main.lua`: ลูปควบคุมการทำงานหลัก

## 2. บริบทข้อมูลเจาะลึก (Deep Extracted Context)สำหรับการฟาร์ม
- **ตัวอย่าง Plot:** `Workspace.Plots.3` -> Attributes: `(FreeGiftClaimedAt=0)`
  - *วิธีเช็คเจ้าของ:* ตรวจสอบจากข้อความป้าย Sign (`Sign` / `OwnerSign`) หรือ Attribute ภายใน Plot
- **โครงสร้าง Pack / Items:** Backpack และ PlacedPacks มี Attribute เช่น `PackId` (UUID), `ItemCategory`, `SortRarity`, `Weight`
- **จุดเกิดแพ็คบนแมพ:** `Workspace.Game.Packs` และผ่าน `StealPrompt` ตามพิกัด Plot ของผู้เล่น

## 3. คำแนะนำสำหรับ AI
  - ใช้ Path จากไฟล์ JSON เสมอ ห้ามฮาร์ดโค้ดชื่อผู้เล่น
  - ครอบ `pcall` ทุกคำสั่ง Remote และใช้ `fireproximityprompt` ตามค่า `HoldDuration` ที่ดึงมา