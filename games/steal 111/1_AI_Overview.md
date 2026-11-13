# 1_AI_Overview.md - ภาพรวมระบบเกมและ Remote (ขโมยแพ็คการ์ดอนิเมะ)

- **PlaceId:** `133151378618377`
- **สคริปต์หลักที่ใช้งาน:** `main_4.lua`
- **เป้าหมาย:** บอทอัตโนมัติสำหรับฟาร์มลู่วิ่ง, ขโมยแพ็ค, เปิดแพ็ค, ขายยูนิต, ผสม/หลอมยูนิต, อัปเกรดฐาน และซื้อเทรนเนอร์/ออร่า

---

## 1. ข้อมูลโครงสร้างแมพและ Object สำคัญ (POIs & Attributes)
- **ระบบ Plot ของผู้เล่น:**
  - ฐานผู้เล่นอยู่ที่ `Workspace.Plots[X]` (หาด้วย `Plot.Sign` หรือตรวจสอบการเป็นเจ้าของ)
  - แท่นเพาะพันธุ์/วางแพ็คบนฐาน: `Plot.PlotModel.PlacedPacks` (ชื่อแพ็ค, PackId/UUID, Rarity, GrowthEndsAt)
  - ลู่วิ่งบนฐาน: `Plot.Treadmil` (ขึ้นวิ่งเพื่อปั๊มความเร็ว/สปีด)
  - บริเวณวางตัวละครสร้างเงิน: `Plot.PlotModel.AnimeArea`
- **ตัวอย่าง Attributes บนตัว LocalPlayer:**
  - `TreadmillLevel`, `Rebirths`, `IndexSpeedBoost`, `TrapCount`, `HatchLuckLevel`, `EquippedCoach`
- **ตัวอย่าง Pack ในกระเป๋า (Backpack Tools):**
  - Attribute สำคัญ: `PackId` (UUID เช่น `b6cba1ea-...`), `ItemName`, `ItemRarity`, `SortCash`, `CardIncome`
- **การขโมยแพ็ค:**
  - แพ็คบนด่าน: `Workspace.Game.Packs` (แยกตาม Stage เช่น Stage1 ถึง Stage12)

---

## 2. รายชื่อ Remote สำคัญที่คัดกรองแล้ว (Filtered Remotes)

### หมวดแพ็คและยูนิต (Packs & Units)
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Packs.PlaceOwned` — วางแพ็คจากกระเป๋าลงบนแท่นเพาะในฐาน `(packId, plotCFrame/position)`
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Packs.OpenOwned` — สั่งเปิดแพ็คที่โตเต็มวัยแล้วบนแท่น `(packId)`
- `[RemoteEvent]` `ReplicatedStorage.Remotes.Packs.Opened` — ยืนยันการเปิดแพ็คสำเร็จ
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Packs.EquipBest` — สวมใส่ยูนิตที่เก่งที่สุดลงฐานอัตโนมัติ
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Packs.CarryAction` — การอุ้มหรือหยิบแพ็ค
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Packs.UnequipAll` — ถอดยูนิตทั้งหมดออกจากฐาน

### หมวดผสมและหลอมยูนิต (Mutate / Merge / Fuse)
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Mutate.Merge` — รวมแพ็ค/การ์ดซ้ำ 2 ชิ้น `(id1, id2)`
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Mutate.Fuse` — หลอมยูนิต 3 ตัวเพื่อกลายพันธุ์ `({id1, id2, id3})`
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Mutate.MergeAll` — รวมการ์ดซ้ำทั้งหมด

### หมวดเศรษฐกิจและการขาย (Economy & Shop)
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Economy.SellItems` — ขายยูนิตเป็นชุด `(tableOfIds)` *(หมายเหตุ: ต้องมี Timeout Guard 4 วินาที)*
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Economy.SellInventory` — ขายยูนิตทั้งหมดในกระเป๋า
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Economy.SellHeld` — ขายยูนิตที่ถืออยู่ในมือ

### หมวดลู่วิ่งและอัปเกรด (Treadmill & Upgrades)
- `[RemoteFunction]` `ReplicatedStorage.Remotes.Treadmill.Upgrade` — อัปเกรดเลเวลลู่วิ่ง
- `[RemoteEvent]` `ReplicatedStorage.Remotes.Treadmill.Boost` — บูสต์สปีดการวิ่ง
- `[RemoteEvent]` `ReplicatedStorage.Remotes.Treadmill.ExitRequest` — ออกจากลู่วิ่ง
- `[RemoteFunction]` `ReplicatedStorage.Remotes.BaseUpgrade.Purchase` — ซื้อการอัปเกรดฐาน

---

## 3. กฎและข้อควรระวังสำคัญทางเทคนิค
1. **Timeout Guard บน `InvokeServer`:** Remote ฟังก์ชันบางตัวเช่น `Economy.SellItems` หรือ `Mutate.Merge` หากส่ง ID ไม่ถูกต้อง Server อาจค้างไม่คืนค่า ต้องใช้ wrapper ที่มี `task.cancel` หลัง 4 วินาทีเสมอ
2. **การเปิดแพ็คที่ขโมยมา:** แพ็คที่เพิ่งขโมยมาจะอยู่ในกระเป๋า (`Backpack`) **ไม่สามารถเรียก `OpenOwned` ได้โดยตรง** (จะติด `NOT_OWNED`) ต้องเรียก `PlaceOwned` ไปวางบนแท่นเพาะในฐานก่อน และรอจน `GrowthEndsAt <= ServerTimeNow` จึงจะเรียก `OpenOwned` ได้
