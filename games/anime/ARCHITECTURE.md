# ARCHITECTURE.md - ดัชนีโครงสร้างและแผนผังสคริปต์ (Anime Mine)

ไฟล์สคริปต์หลัก: `games/anime/anime_mine.lua`

---

## 1. ผังโครงสร้างโค้ดตามช่วงบรรทัด (Line Map)

```
[Lines 1 - 220]    : Bootloader, Watchdog, IdleRejoin Nullifier, Toast Purger
[Lines 221 - 250]  : Safe Require Modules & Safe Data Accessors (SafeGetData, SafeSendEvent)
[Lines 251 - 445]  : Helper Functions (FormatNumber, Damage Calculator, Character Zone Scanner, Sell Key Builder)
[Lines 446 - 670]  : Centralized Config State (Config, SaveConfig, LoadConfig)
[Lines 675 - 1480] : 🤝 TRADE SUITE V7.1 PRO (TradeState, Session Handlers, Watchdog Engine, Trade UI)
[Lines 1481 - 2600]: UI Construction (Modern Kuykuy Hub Framework, Tabs, Layout, Status Badges)
[Lines 2601 - 3570]: UI Event Bindings & Action Triggers (Buttons, Toggles, Dropdowns, Sliders)
[Lines 3571 - 4385]: 🚀 MASTER WORKER PIPELINE (Isolated Task 1 - Task 12 ในขณะ AFK)
[Lines 4386 - End] : Anti-AFK & Final Initialization
```

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

---

## 3. รายการ Task ใน Master Worker Loop (AFK Pipeline)
- **Task 1:** เก็บหีบบนแปลง (`MineTakeChest`)
- **Task 2:** ขายไอเทมรวม (`MineSellItems`)
- **Task 3:** อัปเกรดผังสกิลโซนและแกนหลัก (`AutoUpgradeTree`, `AutoUpgradeCore`)
- **Task 4:** ซื้อขวานที่ดีที่สุด (`AutoBuyBestPickaxe`)
- **Task 5:** อัปเกรดสเตตัสคนงานเรียงตาม Base DMG (`AutoUpgradeAllChars`)
- **Task 6:** สุ่มกลายพันธุ์คนงาน (`AutoMutation`)
- **Task 7:** ทอยลูกเต๋า Enchant & Halloween (`AutoRollDice`)
- **Task 8:** สุ่มตัวละครจากม้วนอัญเชิญ (`AutoSummonScrolls`)
- **Task 9:** รับรางวัลในดัชนี Index (`AutoClaimIndex`)
- **Task 10:** รับรางวัลบอร์ดอีเวนต์ (`AutoClaimEvents`)
- **Task 11:** เปิดกล่อง Colossus & Petalfall Crate (`OpenColossusCrate`)
- **Task 11.5:** เลื่อนระดับบอสโกโลซัสอัตโนมัติ (`AutoNextColossusTier`)
- **Task 12:** วาร์ปขุดหินในแปลง, ซื้อโซนใหม่, และจัดชุดคนงานที่ดีที่สุด (`MineEquipBest`)
