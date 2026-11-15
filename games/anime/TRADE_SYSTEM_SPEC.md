# TRADE_SYSTEM_SPEC.md - ข้อมูลจำเพาะและคู่มือพัฒนาระบบเทรด (Anime Mine)

เอกสารนี้ใช้สำหรับส่งให้ AI (Claude / Sonnet / Antigravity) เพื่อแก้ไขหรือเพิ่มฟังก์ชันใน **ระบบเทรด (Trade Suite V7.1 Pro)** โดยไม่ต้องแนบสคริปต์ตัวเต็ม 4,400 บรรทัด

---

## 1. ตัวแปรและฟังก์ชันสำคัญในระบบเทรด

### `TradeState` (State Table)
```lua
TradeState = {
    IsTradeActive = false,
    Mode = "Sender",            -- "Sender" หรือ "Receiver"
    TargetReceiver = nil,       -- Instance ของผู้เล่นผู้รับ
    SavedReceiverName = "",     -- ชื่อผู้รับที่บันทึกไว้ใน Config
    CurrentCategory = "All",    -- "All", "Miners", "Pickaxes", "Gems", "Other"
    SelectedItems = {},         -- [itemKey] = { Key = itemKey, Amount = number }
    SendAllAlways = true,       -- ส่งไอเทมที่เลือกทั้งหมดทุกครั้ง (Max Always)
    AutoLoopUntilEmpty = true,  -- วนส่งซ้ำอัตโนมัติจนกว่าของที่เลือกจะหมดกระเป๋า
    AutoAccept = true,
    AutoReady = true,
    AutoConfirm = true,
    CurrentSession = nil,
    EditRevision = 0,
    
    -- [ฟังก์ชัน Auto Trade เมื่อของครบยอด]:
    AutoTradeThresholdEnabled = false, -- สวิตช์เปิด/ปิด ส่งเทรดอัตโนมัติเมื่อของครบยอด
    AutoTradeThresholdAmount = 50,     -- ยอดสะสมรวมของไอเทมที่เลือกที่ต้องถึงก่อนส่งเทรด
}
```

---

## 2. ลำดับขั้นตอนการทำงานของโหมดผู้ส่ง (Sender Execution Flow)

```
[1. ตรวจสอบเป้าหมาย] -> TargetReceiver ต้องอยู่ในเซิร์ฟเวอร์
[2. ตรวจสอบเงื่อนไขยอดสะสม] -> รวมจำนวนของในกระเป๋า (GetAvailableCountMap) ที่ตรงกับ SelectedItems
[3. ส่งคำขอเทรด]     -> SafeSendEvent("MineTradeRequest", TargetReceiver.UserId)
[4. รอเปิดเซสชัน]    -> รอสัญญาณ MineTradeSync จากเซิร์ฟเวอร์
[5. ใส่ไอเทมลงช่อง] -> วนส่ง SafeSendEvent("MineTradeSetItem", itemKey, sendAmount, sessionId, rev)
[6. กด Ready]        -> SafeSendEvent("MineTradeReady", true, sessionId, rev)
[7. กด Confirm]      -> SafeSendEvent("MineTradeConfirm", sessionId, rev)
[8. วนซ้ำ (Loop)]    -> หากเปิด AutoLoopUntilEmpty และยังมีของเหลือ จะเริ่มส่งรอบถัดไป
[9. คืนสู่โหมดฟาร์ม] -> เมื่อของถูกส่งหมด หรือปิดการเทรด ระบบฟาร์มหลักจะทำงานต่ออัตโนมัติ
```

---

## 3. Remote Events ที่เกี่ยวข้องกับระบบเทรดทั้งหมด
- `MineTradeRequest` `(targetUserId)` : ส่งคำขอเริ่มเทรด
- `MineTradeRespond` `(acceptBoolean, requestId)` : ยอมรับคำขอเทรด
- `MineTradeSetItem` `(itemKey, amount, sessionId, editRevision)` : วางของลงช่อง
- `MineTradeReady` `(readyBoolean, sessionId, revision)` : ยืนยันความพร้อม
- `MineTradeConfirm` `(sessionId, revision)` : ยืนยันการแลกเปลี่ยน
- `MineTradeCancel` `()` : ยกเลิกการเทรด

---

## 4. โค้ดของระบบ "ส่งเทรดอัตโนมัติเมื่อของครบยอด" (Auto Trade on Item Threshold)
1. **ใน `TradeState`:** เพิ่ม `AutoTradeThresholdEnabled = false` และ `AutoTradeThresholdAmount = 50`
2. **ใน `SaveTradeConfig` & `LoadTradeConfig`:** บันทึกและโหลดค่าทั้ง 2 ตัวนี้ลงไฟล์ `AnimeMine_TradeConfig.json`
3. **ใน UI Control (`SendAllToggleFrame`):** เพิ่ม Toggle สวิตช์ `Auto Trade on Threshold` และ TextBox กรอกยอดรวมขั้นต่ำ
4. **Sender Threshold Watchdog Loop:** 
   ```lua
   task.spawn(function()
       while true do
           task.wait(2.0)
           pcall(function()
               if TradeState.Mode == "Sender"
                   and TradeState.AutoTradeThresholdEnabled
                   and not TradeState.IsTradeActive
                   and (not TradeState.CurrentSession or TradeState.CurrentSession.Stage == "closed" or TradeState.CurrentSession.Stage == "saving") then

                   local targetPlayer = TradeState.TargetReceiver
                   if not targetPlayer and TradeState.SavedReceiverName and #TradeState.SavedReceiverName > 0 then
                       targetPlayer = Players:FindFirstChild(TradeState.SavedReceiverName)
                       if targetPlayer then TradeState.TargetReceiver = targetPlayer end
                   end

                   if targetPlayer and targetPlayer.Parent == Players then
                       local ownedMap = GetAvailableCountMap()
                       local totalMatchingCount = 0
                       local hasAnySelected = false
                       for key, _ in pairs(TradeState.SelectedItems or {}) do
                           hasAnySelected = true
                           totalMatchingCount = totalMatchingCount + (ownedMap[key] or 0)
                       end

                       local requiredThreshold = tonumber(TradeState.AutoTradeThresholdAmount) or 50
                       if hasAnySelected and totalMatchingCount >= requiredThreshold then
                           TradeNotify("ยอดสะสมครบตามเป้าหมาย!", string.format("พบไอเทมที่เลือกสะสมครบ %d/%d ชิ้น เริ่มระบบเทรดส่งให้ %s ทันที!", totalMatchingCount, requiredThreshold, targetPlayer.Name), 4)
                           ToggleTrade(true)
                       end
                   end
               end
           end)
       end
   end)
   ```
