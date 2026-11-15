# ARCHITECTURE.md - ดัชนีโครงสร้างและแผนผังสคริปต์ (Anime Mine)

ไฟล์สคริปต์หลัก: `games/anime/anime_mine.lua` (ความยาวประมาณ 5,230 บรรทัด)

---

## 1. 🔍 สารบัญค้นหาฟังก์ชันและตำแหน่งบรรทัด (Quick Search Index)

> **💡 คำแนะนำ:** หากต้องการค้นหาในโปรแกรมแก้ไขโค้ด ให้กด `Ctrl + F` แล้วพิมพ์คำในช่อง **"คำค้นหา (Ctrl+F)"** จะพบฟังก์ชันทันที

| ระบบ / ฟังก์ชันการทำงาน | ชื่อฟังก์ชันในโค้ด | อยู่บรรทัดที่ | คำค้นหา (Ctrl+F) |
| :--- | :--- | :--- | :--- |
| **🛡️ Safe Event & State Accessors** | `SafeSendEvent` / `SafeGetData` | ~210 - 245 | `local function SafeSendEvent` |
| **💰 ระบบขายของรวม (Auto Sell)** | `GetUnifiedSellKeys` | ~370 - 450 | `local function GetUnifiedSellKeys` |
| **⚙️ ค่าคอนฟิกเริ่มต้นของสคริปต์** | `Config = { ... }` | ~460 - 550 | `Config = {` |
| **🎒 ระบบสแกนคลังไอเทมเพื่อเทรด** | `FetchOwnedInventory` | ~828 - 1220 | `local function FetchOwnedInventory` |
| **📦 ระบบเปิดกล่องบอส Colossus** | `TriggerOpenPetalfallCrate` | ~1343 - 1580 | `local function TriggerOpenPetalfallCrate` |
| **🎨 โครงสร้างหน้าต่าง UI (Kuykuy Hub)** | UI Construction & Tabs | ~1585 - 2800 | `Kuykuy Hub Framework` |
| **🔘 การผูกปุ่มและ Event บนหน้า UI** | UI Bindings & Action Buttons | ~2801 - 3680 | `AddToggle("AutoMine"` |
| **🤝 ระบบส่งของเทรดอัตโนมัติ** | `RunTransferWorker` | ~4053 - 4350 | `local function RunTransferWorker` |
| **[TASK 1] เก็บหีบบนแปลง** | Auto Take Chest Loop | ~4506 | `[TASK 1]` |
| **[TASK 2] ขายของอัตโนมัติในลูป** | Unified Auto Sell Loop | ~4525 | `[TASK 2]` |
| **[TASK 3] อัปเกรดผังสกิลโซน** | Zone Skill Tree & Core | ~4569 | `[TASK 3]` |
| **[TASK 4] ซื้อขวานที่ดีที่สุด** | Auto Buy Best Pickaxe | ~4642 | `[TASK 4]` |
| **[TASK 5] อัปเกรดสเตตัสคนงาน** | Auto Upgrade Stats (Base DMG) | ~4715 | `[TASK 5]` |
| **[TASK 6] สุ่มกลายพันธุ์คนงาน** | Auto Mutation & Auto-Lock | ~4785 | `[TASK 6]` |
| **[TASK 7] ทอยลูกเต๋าบัฟ** | Auto Roll Dice (Enchant/HW) | ~4888 | `[TASK 7]` |
| **[TASK 8] สุ่มม้วนตัวละคร** | Auto Summon Scrolls | ~4916 | `[TASK 8]` |
| **[TASK 9] รับรางวัล Index & Events** | Auto Claim Index & Events | ~4940 | `[TASK 9]` |
| **[TASK 10] ลง Infinity Trial** | Auto Infinity Trial | ~5017 | `[TASK 10]` |
| **[TASK 11] เปิดกล่อง Colossus ในลูป** | Auto Open Colossus Crates | ~5066 | `[TASK 11]` |
| **[TASK 11.5] เลื่อนระดับโกโลซัส** | Auto Next Colossus Tier | ~5080 | `[TASK 11.5]` |
| **[TASK 12] ขุดหินในแปลง / ซื้อโซน** | Auto Mine & Unlock Zones | ~5112 | `[TASK 12]` |

---

## 2. โครงสร้างตัวแปรหลัก (State Specifications)

### `TradeState` (ระบบเทรดและส่งของ)
```lua
TradeState = {
    IsTradeActive = false,       -- true เมื่ออยู่ในเซสชันเทรด (AutoFarm จะ Pause ทันที)
    Mode = "Sender",             -- "Sender" (ผู้ส่ง) หรือ "Receiver" (ผู้รับ)
    TargetReceiver = nil,        -- Player Instance ของผู้รับ
    SavedReceiverName = "",      -- ชื่อผู้รับที่บันทึกไว้ใน Config
    CurrentCategory = "All",     -- หมวดหมู่ไอเทมที่เลือกดู
    SelectedItems = {},          -- รายการไอเทมที่เลือกจะส่ง [itemKey] = { Key = ..., Amount = ... }
    SendAllAlways = true,        -- ส่งไอเทมที่เลือกทั้งหมดทุกครั้ง (Max Always)
    AutoLoopUntilEmpty = true,   -- วนส่งซ้ำอัตโนมัติจนกว่าของที่เลือกจะหมดตัว
    AutoAccept = true,           -- กดยอมรับคำขอเทรดอัตโนมัติ (ฝั่งรับ)
    AutoReady = true,            -- กดยืนยันความพร้อมอัตโนมัติ (Ready)
    AutoConfirm = true,          -- กดยืนยันดีลแลกเปลี่ยนอัตโนมัติ (Confirm)
    CurrentSession = nil,        -- ข้อมูลเซสชันเทรดปัจจุบัน
    EditRevision = 0,            -- เลข Revision การปรับเปลี่ยนของในช่อง
}
```

### `Config` (ระบบฟาร์มหลัก)
```lua
Config = {
    AutoMine = true,
    AutoTakeChest = true,
    AutoUnlockNewZone = true,
    AutoBuyBestPickaxe = true,
    AutoSell = true,
    AutoBuyZone = true,
    AutoUpgradeTree = true,
    AutoUpgradeCore = true,
    AutoEquipBest = true,
    AutoUpgradeAllChars = true,
    AutoMutation = false,
    AutoRollDice = false,
    AutoSummonScrolls = false,
    AutoClaimIndex = true,
    AutoClaimEvents = true,
    AutoInfinityTrial = false,
    AutoOpenPetalfallCrate = false,
    AutoNextColossusTier = true,
}
```
