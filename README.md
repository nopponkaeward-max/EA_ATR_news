# ATR News Straddle — MT5 EA + TradingView Indicator

กลยุทธ์ **ดักเบรกข่าว (News Straddle Breakout)** ใช้ค่า **ATR** กำหนดระยะ มี 2 ไฟล์:

| ไฟล์ | แพลตฟอร์ม | ใช้ทำอะไร |
|---|---|---|
| `EA_ATR_News.mq5` | MetaTrader 5 | เทรดจริง/อัตโนมัติ (วางออเดอร์จริง) |
| `ATR_News_Straddle.pine` | TradingView (Pine v6) | จำลอง/ดูสถิติ + **ตาราง stat** (Main / By-Day / Daily / Monthly / Settings) |

---

## Distance Mode (วิธีคิดระยะ Entry/SL/TP) — มีทั้ง EA และ Pine

| Mode | ระยะ Entry / SL / TP |
|---|---|
| **ATR × Multiplier** (เดิม) | Entry = ATR×mult, SL = ATR×mult, TP = SL×RR |
| **Fixed Distance** | ระบุเป็น **หน่วยราคาคงที่** — `1 = ราคาเปลี่ยน 1.0` (เช่น XAUUSD 4000→3999 = ระยะ 1) |

- Fixed Distance: กรอก `Entry Distance`, `SL Distance`, `TP Distance` ตรงๆ (เช่น SL=1, TP=2 → RR 1:2)
- สถิติ (Net R / By-Order) คำนวณ R จากระยะ TP/SL จริง จึงถูกต้องทุกโหมด
- Re-Entry ใช้ระยะเดียวกับออเดอร์เดิมเสมอ

---

## Entry Mode (ทริกเกอร์การเข้า) — มีทั้งใน EA และ Pine

เลือกได้ว่าจะให้ "วางออเดอร์ ATR straddle" ตอนไหน:

| Mode | ทริกเมื่อ |
|---|---|
| **1. News Time** | แท่งปิด ณ เวลาข่าวที่ตั้ง (เดิม) |
| **2. RSI OB/OS** | ดู RSI ที่ราคาปิดแท่ง ถ้าเข้าโซน Overbought/Oversold |
| **3. News + RSI** | ทริกด้วยอย่างใดอย่างหนึ่ง |

**RSI settings:** `Period`, `TF`, `Overbought` (70), `Oversold` (30)
- **Trigger**:
  - `On Cross Into Zone` — ทริกตอน RSI **ตัดเข้า** โซน OB/OS (กันวางซ้ำ)
  - `On Exit Zone (reversal)` — ทริกตอน RSI **กลับมาตัดออก** จากโซนครั้งแรก (สัญญาณกลับตัว: OS เด้งขึ้นทะลุ 30 / OB ย่อลงทะลุ 70)
  - `While In Zone` — ทุกแท่งที่ RSI ยังอยู่ในโซน
- **Direction**:
  - `Both (straddle)` — วางทั้ง 2 ฝั่ง (ค่าเริ่ม เหมือนโหมดข่าว)
  - `A: OB→Sell / OS→Buy` — สวนทาง (mean reversion)
  - `B: OB→Buy / OS→Sell` — ตามโมเมนตัม

> เมื่อทริก ไม่ว่าโหมดไหน → ใช้กลไกวางออเดอร์ **เหมือนเดิม** (ระยะ ATR, SL/TP ตาม RR, ลอตจากเงินเสี่ยง, pending หมดอายุ)

### Order Management (มีทั้ง EA และ Pine)
| Input | ผล |
|---|---|
| **One Trade At A Time** (`InpOneTradeAtATime`) | ถ้ายังมี position หรือ pending ค้างอยู่ → **ห้ามเริ่มชุดใหม่** (ข้ามรอบสัญญาณนั้น) |
| **OCO** (`InpOCO` / `ocoCancel`) | เมื่อฝั่งหนึ่งถูกทริก (เปิดเป็นออเดอร์) → **ยกเลิก pending อีกฝั่งทันที** |

> - เปิด OCO = ได้พฤติกรรม "เบรกฝั่งไหนเอาฝั่งนั้น แล้วตัดอีกฝั่งทิ้ง" (ตรงข้ามค่าเริ่มที่ปล่อยค้างทั้งคู่)
> - เปิด One Trade = คุมให้มีชุดเทรดเดียว ณ เวลาหนึ่ง ไม่ซ้อนหลายชุด
> - EA: นับจาก order/position จริง (ตาม Magic) — Pine: นับจากสถานะจำลอง

### Re-Entry (มีทั้ง EA และ Pine)
| Input | ผล |
|---|---|
| **Re-Entry on SL return** (`InpReentryOn` / `reentryOn`) | เมื่อออเดอร์โดน **SL** แล้วราคา **กลับมาที่จุดเปิดเดิม** → เปิดออเดอร์ถัดไป (Order-2…) ทิศทางเดิม จุดเดิม SL/TP เท่าเดิม |
| **Max Re-Entries** (`InpReentryMax` / `reentryMax`) | จำนวน re-entry สูงสุด (1 = ถึง Order-2) |
| **Re-Entry Expire** (`InpReentryExpireMin` / `reentryExpMin`) | นาทีหมดอายุ pending re-entry (0 = รอไม่จำกัด) |

- กลไก: re-entry เป็น **stop order ที่ราคา entry เดิม** → จะทริกเมื่อราคาวิ่งกลับมาแตะจุดเปิด
- **ป้าย**: ทุกออเดอร์ติดชื่อ `Order-1`, `Order-2`, … (EA = comment, Pine = label บนกราฟ)
- **สถิติแยกตามออเดอร์**: Pine เพิ่มตาราง **BY ORDER** (Order-1 / Order-2 / … : W-L / WR% / Net R)
  - EA: แยกผ่านชื่อ comment ของแต่ละออเดอร์ (ดูใน History/Report ของ MT5)

---

## EA_ATR_News (MT5)

Expert Advisor สำหรับ MetaTrader 5 แนว **ดักเบรกข่าว (News Straddle Breakout)** โดยใช้ค่า **ATR** กำหนดระยะ

## หลักการทำงาน
1. เมื่อถึง **เวลาข่าว** ที่ตั้งไว้ (ใช้ **เวลา server ของโบรกเกอร์ตรงๆ ไม่ต้องแปลง GMT**)
   และ **แท่ง 15M ปิดพอดี** EA จะใช้ราคาปิดแท่งนั้นเป็นจุดอ้างอิง (anchor)
   - ตัวอย่าง: ข่าว USD เวลา 19:30 → แท่ง 19:15–19:30 ปิดตอน 19:30 → วางออเดอร์ ณ ตอนนั้น
2. คำนวณ `ATR(period)` บน TF ที่เลือก แล้ววาง **คร่อมราคา**:
   - **Buy Stop** = anchor + (ATR × EntryMultiplier)
   - **Sell Stop** = anchor − (ATR × EntryMultiplier)
3. **SL / TP** ตาม RR ของระยะ ATR:
   - `SL = ATR × SL_Multiplier`
   - `TP = ระยะ SL × RR`
4. **เบรกฝั่งไหนเปิดฝั่งนั้น** — เมื่อราคาทริกฝั่งใดฝั่งหนึ่ง EA **ไม่ลบ** อีกฝั่งทิ้ง
   (ปล่อยค้างไว้ เผื่อราคาสวิงกลับไปเบรกอีกฝั่ง)
5. **ขนาดลอต** คำนวณจาก *เงินเสี่ยงต่อไม้ ÷ ระยะ SL*
   - `lot = RiskMoney / (ระยะSL ในหน่วยเงิน)` แล้วปรับตาม lot step / min / max
6. **Pending ที่ไม่ถูกทริก หมดอายุ** ตามนาทีที่ตั้ง (`InpExpireMinutes`)

## พารามิเตอร์ (Inputs)

### เวลาข่าว (เวลา Server)
| Input | ค่าเริ่ม | อธิบาย |
|---|---|---|
| `InpNewsHour` | 19 | ชั่วโมงข่าว (server time, 0–23) |
| `InpNewsMinute` | 30 | นาทีข่าว (server time, 0–59) |
| `InpTradeMonday..Friday` | true | เลือกวันที่อนุญาตให้เทรด (เสาร์/อาทิตย์ ปิดโดยค่าเริ่ม) |

> **การตั้งเวลา:** ให้ดูเวลาบนกราฟ/นาฬิกา server ของโบรกคุณ แล้วกรอกตามนั้น
> เช่น ข่าว 19:30 GMT+7 ถ้าโบรกเป็น GMT+3 นาฬิกา server จะเป็น 15:30 → กรอก 15 / 30

### Timeframe & ATR
| Input | ค่าเริ่ม | อธิบาย |
|---|---|---|
| `InpEntryTF` | PERIOD_M15 | TF ของแท่งที่ใช้ |
| `InpATRPeriod` | 14 | ATR period |
| `InpEntryMultiplier` | 1.0 | ตัวคูณ ATR สำหรับระยะวางออเดอร์ |
| `InpSLMultiplier` | 1.0 | ตัวคูณ ATR สำหรับระยะ SL |
| `InpRR` | 2.0 | Risk:Reward (TP = ระยะSL × RR) |

### การจัดการเงิน / ออเดอร์
| Input | ค่าเริ่ม | อธิบาย |
|---|---|---|
| `InpRiskMoney` | 10.0 | เงินเสี่ยงต่อไม้ (สกุลบัญชี) |
| `InpMinLot` | 0.01 | ลอตต่ำสุดที่ยอมเปิด |
| `InpMaxLot` | 5.0 | ลอตสูงสุดที่ยอมเปิด |
| `InpExpireMinutes` | 60 | นาทีที่ pending หมดอายุ (0 = ไม่หมดอายุ) |
| `InpMaxSpreadPoints` | 0 | สเปรดสูงสุดที่ยอมวาง (0 = ปิดเช็ก) |
| `InpMagicNumber` | 20250911 | Magic number |
| `InpComment` | ATR_News | คอมเมนต์ออเดอร์ |

## การติดตั้ง
1. ก็อป `EA_ATR_News.mq5` ไปไว้ที่ `MQL5/Experts/` ของ MT5
2. เปิด MetaEditor แล้ว **Compile** (F7)
3. ลาก EA ลงกราฟคู่เงินที่ต้องการ (แนะนำ TF 15M)
4. ตั้งค่า Inputs ตามตารางด้านบน และเปิด **Algo Trading**

## ข้อควรทราบ (EA)
- EA เช็ก stops level ขั้นต่ำของโบรก และเลื่อนราคา pending ให้อัตโนมัติถ้าจำเป็น
- ทดสอบใน **Strategy Tester / บัญชี Demo** ก่อนใช้จริงเสมอ
- ยังไม่ได้เปิดโหมด OCO (ลบอีกฝั่งเมื่อไม้แรกทริก) ตามที่ผู้ใช้ต้องการ

---

## ATR_News_Straddle (TradingView / Pine v6)

Indicator สำหรับ **จำลองและดูสถิติ** ของกลยุทธ์เดียวกันบน TradingView พร้อมตาราง stat สไตล์ Luxe

### วิธีใช้
1. เปิด TradingView → Pine Editor → วางโค้ดจาก `ATR_News_Straddle.pine`
2. **Add to chart** — แนะนำให้ใช้บน **Timeframe ที่ปิดตรงเวลาข่าว** (เช่น M15 สำหรับข่าว 19:30)
3. ตั้งค่า News Hour/Minute ให้ตรงกับ **เวลาของกราฟ** (ปรับ Timezone ในกลุ่ม Timezone ได้)

### ตรรกะ
- ถึงเวลาข่าว + แท่งปิด → วาง Buy Stop / Sell Stop คร่อมราคาปิด (`close ± ATR×EntryMult`)
- เบรกฝั่งไหนเข้าฝั่งนั้น แต่ละไม้อิสระ ไม่ลบอีกฝั่ง
- `SL = ATR×SL_Mult`, `TP = ระยะSL×RR`; pending หมดอายุตามนาทีที่ตั้ง
- ใช้ **Lower TF** ตัดสินว่า TP หรือ SL โดนก่อน เมื่อแท่งเดียวครอบทั้งคู่

### ตาราง Stat
- **Main** — Trades / Winrate / Net R / Max Streak (+วันที่) / Streak R·Pts / การตั้งค่า ATR·RR / Open·Pending
- **By-Day** — สรุปราย Sun–Sat (ไฮไลต์วันดีสุด)
- **Daily Log** — log รายวันของเดือนที่เลือก
- **Monthly** — สรุปรายเดือน (โหมด Last N Months)
- **Settings Summary** — สรุปพารามิเตอร์ทั้งหมด

> หมายเหตุ: เป็น indicator สำหรับ *วิเคราะห์/ดูสถิติ* ไม่ใช่ strategy ที่ส่งออเดอร์จริง
> ผลเป็นการจำลองบนแท่งเทียนในอดีต (historical) เพื่อประเมินกลยุทธ์
