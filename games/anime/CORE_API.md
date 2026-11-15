# CORE_API.md - โครงสร้าง API และฟังก์ชันหลัก (Anime Mine / Kuykuy Hub)

เอกสารนี้รวบรวมเฉพาะ Core API, Helper Functions และ Data Schema สำหรับ AI Agent เพื่อใช้อ้างอิงโดยไม่ต้องโหลดสคริปต์เต็ม 5,000 บรรทัด (ช่วยประหยัด Token 95%+)

---

## 1. 🛡️ Safe State & Event Accessors (ฟังก์ชันเรียกใช้ข้อมูลและส่งคำสั่ง)

```lua
-- ดึงข้อมูล Client Data ทั่วไป (Money, Gems, Rebirths)
local function SafeGetData()
    if GameState and GameState.GetData then
        local ok, data = pcall(function() return GameState:GetData() end)
        if ok and data then return data end
    end
    return {}
end

-- ดึงข้อมูลหลักตัวเกม (MineGame State)
local function SafeGetData2()
    if GameState and GameState.GetData2 then
        local ok, data = pcall(function() return GameState.GetData2() end)
        if ok and data then return data end
    end
    return {}
end

-- ส่งคำสั่ง Remote Event เข้าเซิร์ฟเวอร์อย่างปลอดภัยผ่าน GameState
local function SafeSendEvent(eventName, ...)
    if not eventName then return false end
    if not (GameState and GameState.SendEvent) then return false end
    local ok, err = pcall(GameState.SendEvent, eventName, ...)
    return ok
end

-- หน่วงเวลาแบบสุ่มเพื่อความปลอดภัยและไม่ให้เซิร์ฟเวอร์ดีด (Human Delay)
local function HumanWait(minSec, maxSec)
    minSec = minSec or 0.08
    maxSec = maxSec or 0.16
    task.wait(minSec + math.random() * (maxSec - minSec))
end

-- อัปเดตข้อความสถานะบน Badge มุมขวาบนของ GUI
local function UpdateStatus(text)
    -- อัปเดตตัวแปร StatusLabel.Text และบันทึกลง Console
end
```

---

## 2. 📦 Data Schema ใน `mg` (`SafeGetData2().MineGame`)

| คีย์ใน `mg` | ชนิดข้อมูล | คำอธิบาย / ตัวอย่างข้อมูล |
| :--- | :--- | :--- |
| `mg.CurrentZone` | `number` / `string` | หมายเลขโซนปัจจุบัน (1-14) |
| `mg.UnlockedZones` | `table` | ตารางโซนที่ปลดแล้ว เช่น `["Z1"]=true, ["Z14"]=true` |
| `mg.Holders` | `table` | คนงานบนแท่นขุด `h.CharName`, `h.Pickaxe`, `h.Level` |
| `mg.Characters` | `table` | ตัวละครในกระเป๋า `[charName] = count` |
| `mg.Pickaxes` | `table` | ขวานทั้งหมดในคลัง `[pickName] = count` |
| `mg.ColossusCrates` | `table` | กล่องบอสโกโลซัส (`Tidewreck Crate`, `Petalfall Crate` ฯลฯ) |
| `mg.Crates` | `table` | กล่องสุ่มทั่วไปในคลัง |
| `mg.Items` / `mg.Inventory` | `table` | ไอเทมทั่วไปและกล่องที่จัดเป็นไอเทม |
| `mg.EnchantItems` | `table` | หินบัฟ (`Glacial`, `Quaking`, `Blazing` ฯลฯ) |
| `mg.Potions` | `table` | น้ำยาบัฟ (`Mutation Luck Potion I`, `II` ฯลฯ) |
| `mg.GearItems` | `table` | อุปกรณ์สวมใส่ |
| `mg.Ores` | `table` | แร่ที่ขุดได้ในแปลง |
| `mg.BigNodes[zoneKey]` | `table` | บอสประจำโซน (`Level`, `Drop`, `ActiveTime`) |
| `mg.Skills[zoneKey]` | `table` | ผังสกิลประจำโซน (`NodeLevel`, `CharSpeed`, `CharDamage`) |
| `mg.Gems` | `number` | จำนวนอัญมณี |
| `mg.Trial` | `table` | สถานะ Infinity Trial (`Attempt`, `EndsAt`, `Tier`) |

> [!IMPORTANT]
> ในระบบไอเทม ให้ใช้ฟังก์ชันช่วยอ่านจำนวนเสมอ เพราะตัวเกมอาจเก็บเป็นตัวเลขตรงๆ `tonumber(v)` หรือเก็บเป็นออบเจกต์ `v.Count`, `v.Amount`, `v.Value`

---

## 3. 📡 Remote Event Names (`Config.Events`)

```lua
Config.Events = {
    -- ฟาร์มและขุด
    TakeChest = "MineTakeChest",
    SellItems = "MineSellItems",
    EquipBest = "MineEquipBest",
    BigNodeToggle = "MineBigNodeToggle",
    SelectZone = "MineSelectZone",
    BuyPickaxe = "MineBuyPickaxe",
    BuySkill = "MineBuySkill",
    UpgradeCharacter = "MineUpgradeCharacter",
    RollMutation = "MineRollMutation",
    RollEnchant = "MineRollEnchant",
    Summon = "MineSummon",
    
    -- ดันเจี้ยนและกล่อง
    TrialStart = "MineTrialStart",
    TrialClaim = "MineTrialClaim",
    TrialCancel = "MineTrialCancel",
    OpenColossusCrate = "MineOpenColossusCrate",
    IndexClaim = "MineIndexRewardsClaim",
    EventsClaim = "MineEventsClaim",

    -- เทรด
    TradeRequest = "MineTradeRequest",
    TradeRespond = "MineTradeRespond",
    TradeSetItem = "MineTradeSetItem",
    TradeReady = "MineTradeReady",
    TradeConfirm = "MineTradeConfirm",
    TradeCancel = "MineTradeCancel"
}
```

---

## 4. 🚀 ผัง Worker Tasks (Master AFK Loop)

- **[TASK 1]** `MineTakeChest()` : เก็บหีบสมบัติบนแปลง
- **[TASK 2]** `MineSellItems()` : ขายแร่, ขวานเก่า, คนงาน
- **[TASK 3]** `AutoUpgradeTree` : อัปสกิลโซน + ซื้อโซนวิจัย
- **[TASK 4]** `AutoBuyBestPickaxe` : ซื้อขวานปลดล็อกที่ดีที่สุดอันเดียว
- **[TASK 5]** `AutoUpgradeAllChars` : อัปเกรดคนงานตาม Base DMG
- **[TASK 6]** `AutoMutation` : สุ่มกลายพันธุ์คนงานที่พร้อมก่อน + Auto Lock
- **[TASK 7]** `AutoRollDice` : ทอยเต๋าบัฟ Enchant / Halloween
- **[TASK 8]** `AutoSummonScrolls` : สุ่มม้วนตัวละคร
- **[TASK 9]** `AutoClaimIndex` : เคลมรางวัล Index & Event Board
- **[TASK 10]** `AutoInfinityTrial` : ตรวจสอบและลงทดสอบ Infinity Trial
- **[TASK 11]** `TriggerOpenPetalfallCrate()` : เปิดกล่อง Colossus Crates ทั้งหมด
- **[TASK 11.5]** `AutoNextColossusTier` : เลื่อนระดับบอสโกโลซัสอัตโนมัติ
- **[TASK 12]** `AutoMine` / `AutoBuyZone` / `TriggerEquipBest()` : ตีหิน, ซื้อโซน, สวมใส่คนงานดีที่สุด
