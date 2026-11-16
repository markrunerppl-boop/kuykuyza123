# ARCHITECTURE.md - ขโมยแพ็คอนิเมะ & ดันเจี้ยน
**หน้าที่:** อธิบายภาพรวมโปรเจกต์และบริบทเกมเพื่อให้ AI เข้าใจกลไกการทำงาน (รวมข้อมูลจาก Main World & Dungeon)
- **PlaceId หลัก (ขโมยแพ็คอนิเมะ):** `133151378618377`
- **PlaceId ดันเจี้ยน (Dungeon):** `135412798316370`

## 1. จุด Entry Point
- `main.lua`: ลูปควบคุมการทำงาน

## 2. บริบทข้อมูลเจาะลึก (Deep Extracted Context) *สำคัญมาก*
- **วิเคราะห์แหล่งเก็บข้อมูลเจ้าของ Plot (Plot Owner):**
  - **บนตัว Plot:**
    - Plot 2: `FreeGiftClaimedAt=0`
  - **บนป้าย Sign:**
    - ป้าย Sign Plot 1 (`Workspace.Plots.1.Sign`): `(ไม่มี Attribute/Value)` (ข้อความบนป้าย: `@UNOWNED`)
    - ป้าย Sign Plot 2 (`Workspace.Plots.2.Sign`): `(ไม่มี Attribute/Value)` (ข้อความบนป้าย: `⭐ RAREST PULL`)
  - **บนตัว LocalPlayer:**
    - `CashPotionMultiplier=2, UpdateCinematic=Skip, LuckPotionMultiplier=2, FriendsInServer=0, CashPotionX2_15Owned=true, IntroCinematic=Skip, SpeedPotionX2_10Owned=true, LuckPotionX2_10Owned=true, EquippedCoach=Buddha:Gold, PhoneRevives=0, RengokuSwordCount=1, CashPotionX2_10Count=14, IndexSpeedBoost=10.13, RichestInServer=true, MutationPotionMultiplier=2, RengokuSwordOwned=true, HatchLuckLevel=25236, TreadmillLevel=Level12, GojoBlindfoldOwned=true, CashPotionX2_15Count=2, LuckPotionX2_15Count=1, TouchInput=false, SpeedPotionX2_10Count=4, CashPotionX2_10Owned=true, LuckPotionX2_10Count=4, Rebirths=12, TradeUnlocked=true, LuckPotionX2_15Owned=true, Title=SideCharacter, SpeedPotionMultiplier=2, TrapCount=3, GojoBlindfoldCount=1`

- **ตัวอย่าง Pack Tool ของจริง:**
  - `Players.markergg7.Backpack.Overlord` -> ข้อมูล: `(ItemName=Cursed Overlord, MutationTint=0.55098, 0.5, 0.580392, CardIsPack=false, SortWeight=110, CharacterName=Overlord, CardWeight=(110Kg), Mutation=Cursed, HeldCharacterLifecycleBound=true, CharacterIdleAnimationId=90476069912128, CardPrice=$412,2T, ItemWeightText=110 KG, CardMutationColors=0 0.101961 0 0.160784 0 1 0.705882 0.298039 1 0 , SortCash=412211236098016, ItemCategory=Units, HeldOverhead=true, ItemMetricText=$27,4T/s, ItemRarity=Eternal, CardRarity=Eternal, CardMutation=Cursed, CardIncome=$27,4T/s, CardIcon=rbxassetid://88695246391874, PackId=e827e6c6-d9ae-4cdb-8565-f0a51bade692, SortRarity=10)`

- **ตัวอย่าง Treadmill (ลู่วิ่ง):**
  - Plot 1: `Workspace.Plots.1.Treadmil` -> ข้อมูล: `((ไม่มี Attribute/Value))`
  - Plot 2: `Workspace.Plots.2.Treadmil` -> ข้อมูล: `((ไม่มี Attribute/Value))`
  - *หมายเหตุ: ถ้าหา UUID ไม่เจอใน Attribute อาจซ่อนอยู่ใน Child/Model ของมัน หรือเซิร์ฟเวอร์ส่งมาให้ตอนขึ้นลู่วิ่ง*

- **ตัวอย่างแพ็คบน Plot (PlacedPacks):**
  - ตัวอย่างที่ 1: `Workspace.Plots.2.PlotModel.PlacedPacks.Thorfann` -> ข้อมูล: `(Pack=Pack4, Rarity=Divine, Weight=553, HiddenBySetting=true, PackId=c01057cb-fd97-475f-94e8-f1337500570e)`
  - ตัวอย่างที่ 2: `Workspace.Plots.2.PlotModel.PlacedPacks.In Chae` -> ข้อมูล: `(Pack=Pack4, Rarity=Mythical, Weight=298, Mutation=Gold, HiddenBySetting=true, PackId=a5cb6312-2efe-4416-ad3d-02be2bf015e4)`

- **ตัวอย่างแพ็คบน Stage/Map (Game.Packs):**
  - `Workspace.Game.Packs.Stage1` -> ข้อมูล: `((ไม่มี Attribute/Value))` | Prompt: `OpenPrompt` (HoldDuration: 0.00s)

- **บริบทเฉพาะแมพดันเจี้ยน (Dungeon Context - PlaceId 135412798316370):**
  - ไม่พบ Plot ใน Workspace
  - ไม่พบ Pack ในกระเป๋าหรือตัวละคร
  - ไม่พบ Treadmill (ลู่วิ่ง) ใน Plot
  - ไม่พบแพ็คที่วางอยู่บน Plot
  - ไม่พบแพ็คที่เกิดบน Map/Stage (Game.Packs)

- **คำแนะนำสำหรับ AI:**
  - ให้ใช้ชื่อ Attribute หรือ ValueBase จากตัวอย่างของจริงด้านบนในการดึงข้อมูล UUID/ID ต่างๆ
  - หาก ProximityPrompt มีค่า `HoldDuration > 0` ให้ใช้ `fireproximityprompt(prompt)` หรือจำลองการกดค้างตามเวลาจริง
  - หาก Args ของ Remote ต้องการพิกัด ให้แปลงเป็น `Vector3.new(x, y, z)`
  - หาก Args ต้องการ Object ตัวตนจริงๆ ให้หาจาก Path ห้ามส่งเป็น String

## 3. ModuleScripts ใน ReplicatedStorage (ใช้ตรวจสอบ Config/Rarity/Items)
- พบ Scripts ทั้งหมด: สูงสุด `1162` ไฟล์ (รวมตัวอย่าง ModuleScript สำคัญ):
  - `ReplicatedStorage.TODO`
  - `ReplicatedStorage.Doomscroll`
  - `ReplicatedStorage.Doomscroll.Signal`
  - `ReplicatedStorage.Doomscroll.ripple`
  - `ReplicatedStorage.Doomscroll.ripple.config`
  - `ReplicatedStorage.Doomscroll.ripple.createMotion`
  - `ReplicatedStorage.Doomscroll.ripple.createMotion.spec`
  - `ReplicatedStorage.Doomscroll.ripple.types`
  - `ReplicatedStorage.Doomscroll.ripple.solvers.immediate`
  - `ReplicatedStorage.Doomscroll.ripple.solvers.immediate.spec`
  - `ReplicatedStorage.Doomscroll.ripple.solvers.linear`
  - `ReplicatedStorage.Doomscroll.ripple.solvers.linear.spec`
  - `ReplicatedStorage.Doomscroll.ripple.solvers.spring`
  - `ReplicatedStorage.Doomscroll.ripple.solvers.spring.spec`
  - `ReplicatedStorage.Doomscroll.ripple.solvers.tween`
  - `ReplicatedStorage.Doomscroll.ripple.solvers.tween.spec`
  - `ReplicatedStorage.Doomscroll.ripple.utils.assign`
  - `ReplicatedStorage.Doomscroll.ripple.utils.intermediate`
  - `ReplicatedStorage.Doomscroll.ripple.utils.merge`
  - `ReplicatedStorage.Doomscroll.ripple.utils.snapshot`
  - `ReplicatedStorage.Doomscroll.ripple.utils.spy`
  - `ReplicatedStorage.Doomscroll.HookButton`
  - `ReplicatedStorage.Doomscroll.Config`
  - `ReplicatedStorage.Doomscroll.Catalog`
  - `ReplicatedStorage.Doomscroll.Feed`
  - `ReplicatedStorage.Doomscroll.Scroller`
  - `ReplicatedStorage.Doomscroll.Remotes`
  - `ReplicatedStorage.Doomscroll.Interface`
  - `ReplicatedStorage.Doomscroll.Session`
  - `ReplicatedStorage.Doomscroll.Packages.janitor`
  - `ReplicatedStorage.Doomscroll.Packages.net`
  - `ReplicatedStorage.Doomscroll.Packages.profilestore`
  - `ReplicatedStorage.Doomscroll.Packages.promise`
  - `ReplicatedStorage.Doomscroll.Packages.signal`
  - `ReplicatedStorage.Doomscroll.Packages.Component`
  - `ReplicatedStorage.Doomscroll.Packages._Index.evaera_promise@4.0.0.promise`
