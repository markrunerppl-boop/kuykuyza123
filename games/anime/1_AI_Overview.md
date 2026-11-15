# 1_AI_Overview.md - ภาพรวมระบบเกม Anime Mine (Kuykuy Hub)

- **Game:** Anime Mine (เหมืองอนิเมะของฉัน)
- **PlaceId:** `79389059854988`
- **Main Script File:** `games/anime/anime_mine.lua` (~4,400 lines)
- **Main Loader:** `script.lua`

---

## 1. โครงสร้างการเข้าถึงข้อมูลตัวเกม (State & Data Access)
ตัวเกมใช้ ReplicatedStorage Modules ในการจัดการข้อมูลส่วนกลาง:
- `GameState.GetData()` : ข้อมูลฝั่ง Client ทั่วไป (`Money`, `Gems`, `Rebirths`)
- `GameState.GetData2()` : ข้อมูลเกมหลัก (`MineGame`)
  - `mg.CurrentZone` : หมายเลขโซนปัจจุบัน (1-14)
  - `mg.UnlockedZones` : ตารางโซนที่ปลดล็อกแล้ว เช่น `["Z14"] = true`
  - `mg.Holders` : คนงานบนแท่นขุดในแปลง (`h.CharName`, `h.Pickaxe`, `h.Level`)
  - `mg.Characters` : ตัวละครทั้งหมดในกระเป๋า (`[charName] = count`)
  - `mg.Pickaxes` : ขวานทั้งหมดในคลัง (`[pickName] = count`)
  - `mg.ColossusCrates` : กล่องบอสโกโลซัสทั้งหมด (`Tidewreck Crate` / กล่องซากเรือจากกระแสน้ำ, `Petalfall Crate` ฯลฯ)
  - `mg.Crates` : กล่องทั่วไปในคลัง
  - `mg.BigNodes[curZoneKey]` : บอสโกโลซัส (`Level`, `Drop`, `ActiveTime`, `Ore`)
  - `mg.Skills[curZoneKey]` : ผังสกิลประจำโซน (`NodeLevel`, `CharSpeed`, `CharDamage`)
  - `mg.Gems` : อัญมณี
  - `mg.Trade` : สถานะการเทรดสด

---

## 2. รายชื่อ Remote Events ที่เซิร์ฟเวอร์รับ (GameState.SendEvent)
การส่งคำสั่งในเกมนี้ใช้ `GameState.SendEvent(eventName, ...)`:

### หมวดระบบเทรด (Trade Suite V7.1 Pro)
- `MineTradeRequest` `(targetUserId)` : ส่งคำขอเทรดไปยังผู้เล่นเป้าหมาย
- `MineTradeRespond` `(acceptBoolean, requestId)` : ตอบรับ (true) หรือปฏิเสธ (false) คำขอเทรด
- `MineTradeSetItem` `(itemKey, amount, sessionId, editRevision)` : วางไอเทมลงในช่องเทรด
- `MineTradeReady` `(readyBoolean, sessionId, revision)` : กดยืนยันความพร้อมฝั่งตนเอง (Ready / ติ๊กถูก)
- `MineTradeConfirm` `(sessionId, revision)` : กดยืนยันการแลกเปลี่ยนขั้นสุดท้าย (Confirm Deal)
- `MineTradeCancel` `()` : ยกเลิกเซสชันการเทรด

### หมวดขุดหิน & จัดการแปลง (Mining & Plots)
- `MineTakeChest` `()` : เก็บหีบสมบัติบนแปลง
- `MineSellItems` `(sellKeysTable)` : ขายไอเทม/ตัวละครแบบระบุ Key
- `MineBigNodeToggle` `(targetTierLevel)` : สลับระดับบอสโกโลซัส (Colossus Tier)
- `MineEquipBest` `()` : คำสั่งเซิร์ฟเวอร์จัดคนงานที่เก่งที่สุดและขวานที่ดีที่สุดลงแปลงอัตโนมัติ

### หมวดอัปเกรด & ซื้อของ (Upgrades & Shop)
- `MineBuyPickaxe` `(pickaxeIndex)` : ซื้อขวานที่ดีที่สุด (เช็ก `MineStock.GetRemaining > 0` ก่อนเสมอ)
- `MineSelectZone` `(zoneKey)` : ซื้อและปลดล็อกโซนใหม่
- `MineBuySkill` `(zoneKey, family, nodeId)` : อัปเกรดผังสกิลประจำโซน
- `MineUpgradeCharacter` `(slotKey, statType, isBatch)` : อัปเกรดสเตตัสคนงาน (Damage/Speed/MineSpeed)
- `MineRollMutation` `(slotKey)` : สุ่มกลายพันธุ์คนงาน
- `MineRollEnchant` `(rollCount, bannerType)` : ทอยลูกเต๋า Enchant / Halloween

### หมวดดันเจี้ยน & กาชา (Dungeons & Gacha)
- `MineTrialStart` `()` : เริ่มลง Infinity Trial
- `MineTrialClaim` `(tierIndex)` : รับรางวัล Infinity Trial
- `MineOpenColossusCrate` `(crateName, amount)` : เปิดกล่องบอสโกโลซัส
- `MineSummon` `(amount)` : สุ่มตัวละครจากม้วนอัญเชิญ
- `MineIndexRewardsClaim` `(catKey, tierKey, rIdx)` : เคลมรางวัลในดัชนี (Index)

---

## 3. กฎทางเทคนิคและข้อควรระวังสำคัญ (Technical Constraints)
1. **ห้ามยิง `MineEquipPickaxe` รายช่อง:** ให้ใช้ `MineEquipBest` เพียงอย่างเดียว เพื่อป้องกันการแย่งขวานที่ถืออยู่แล้ว (`already in someone's hands`)
2. **ขวาน Blacklist:** ห้ามซื้อ `Dragonrise Pickaxe` และ `Krakenmaw Pickaxe` เพราะยังไม่เปิดขาย
3. **การเปลี่ยนโกโลซัส:** ต้องใช้ `MineConfig.GetBigNodeRunLevel` เทียบกับ `MineConfig.GetBigNodeLevel` และสั่งงานผ่าน Client GC (`pickColossus`) เพื่อความเสถียรบนมือถือ Delta
4. **ความปลอดภัยขณะเทรด:** เมื่อ `TradeState.IsTradeActive == true` ทุกเธรดใน AutoFarm จะหยุดทำงานชั่วคราวอัตโนมัติ เพื่อป้องกันการวาร์ปหรือการขายไอเทมขัดจังหวะการเทรด
