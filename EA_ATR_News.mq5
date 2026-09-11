//+------------------------------------------------------------------+
//|                                                 EA_ATR_News.mq5   |
//|            News Straddle Breakout EA (Buy Stop / Sell Stop)       |
//|                                                                  |
//|  แนวคิด:                                                          |
//|   - เมื่อถึงเวลาข่าวที่กำหนด (เวลา server ของโบรกเกอร์ ไม่ต้องแปลง) |
//|     และแท่ง 15M ปิดพอดี EA จะวาง Buy Stop + Sell Stop คร่อมราคา    |
//|   - ระยะการวางออเดอร์ใช้ค่า ATR                                    |
//|   - เบรกฝั่งไหนออเดอร์ฝั่งนั้นจะถูกทริก โดย "ไม่ลบ" อีกฝั่งทิ้ง      |
//|   - SL = ATR x SL_Multiplier , TP = ระยะ SL x RR                  |
//|   - ขนาดลอตคำนวณจาก เงินเสี่ยงต่อไม้ / ระยะ SL                     |
//|   - Pending ที่ไม่ถูกทริก หมดอายุตามนาทีที่ตั้ง                     |
//+------------------------------------------------------------------+
#property copyright "EA_ATR_News"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//====================== INPUTS ======================================
input group "=== เวลาข่าว (เวลา Server ของโบรกเกอร์) ==="
input int      InpNewsHour        = 19;      // ชั่วโมงข่าว (server time, 0-23)
input int      InpNewsMinute      = 30;      // นาทีข่าว (server time, 0-59)
input bool     InpTradeSunday     = false;   // เทรดวันอาทิตย์
input bool     InpTradeMonday     = true;    // เทรดวันจันทร์
input bool     InpTradeTuesday    = true;    // เทรดวันอังคาร
input bool     InpTradeWednesday  = true;    // เทรดวันพุธ
input bool     InpTradeThursday   = true;    // เทรดวันพฤหัสบดี
input bool     InpTradeFriday     = true;    // เทรดวันศุกร์
input bool     InpTradeSaturday   = false;   // เทรดวันเสาร์

input group "=== Timeframe & ATR ==="
input ENUM_TIMEFRAMES InpEntryTF  = PERIOD_M15; // Timeframe ของแท่งที่ใช้ (ค่าเริ่ม 15M)
input int      InpATRPeriod       = 14;      // ATR Period
input double   InpEntryMultiplier = 1.0;     // ตัวคูณ ATR สำหรับระยะวางออเดอร์ (entry offset)
input double   InpSLMultiplier    = 1.0;     // ตัวคูณ ATR สำหรับระยะ SL
input double   InpRR              = 2.0;     // Risk:Reward (TP = ระยะSL x RR)

input group "=== การจัดการเงิน / ออเดอร์ ==="
input double   InpRiskMoney       = 10.0;    // เงินเสี่ยงต่อไม้ (สกุลบัญชี) -> lot = RiskMoney / ระยะSL
input double   InpMinLot          = 0.01;    // ลอตขั้นต่ำที่ยอมให้เปิด
input double   InpMaxLot          = 5.0;     // ลอตสูงสุดที่ยอมให้เปิด
input int      InpExpireMinutes   = 60;      // นาทีที่ pending จะหมดอายุ (0 = ไม่หมดอายุ)
input int      InpMaxSpreadPoints = 0;       // สเปรดสูงสุดที่ยอมวาง (points, 0 = ปิดการเช็ก)
input long     InpMagicNumber     = 20250911;// Magic Number
input string   InpComment         = "ATR_News";

//====================== GLOBALS =====================================
CTrade   trade;
int      atrHandle = INVALID_HANDLE;
datetime g_lastCycleBarTime = 0;   // เวลาแท่งของรอบที่วางไปแล้ว (กันวางซ้ำในรอบเดียว)

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   atrHandle = iATR(_Symbol, InpEntryTF, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
     {
      Print("สร้าง ATR handle ไม่สำเร็จ");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFillingBySymbol(_Symbol);

   PrintFormat("EA_ATR_News เริ่มทำงาน | ข่าวเวลา %02d:%02d (server) | TF=%s | ATR=%d",
               InpNewsHour, InpNewsMinute, EnumToString(InpEntryTF), InpATRPeriod);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(atrHandle != INVALID_HANDLE)
      Iuu_ReleaseHandle();
  }

void Iuu_ReleaseHandle()
  {
   IndicatorRelease(atrHandle);
   atrHandle = INVALID_HANDLE;
  }

//+------------------------------------------------------------------+
//| ตรวจว่าวันนี้อนุญาตให้เทรดหรือไม่                                  |
//+------------------------------------------------------------------+
bool IsTradingDay(const MqlDateTime &dt)
  {
   switch(dt.day_of_week)
     {
      case 0: return InpTradeSunday;
      case 1: return InpTradeMonday;
      case 2: return InpTradeTuesday;
      case 3: return InpTradeWednesday;
      case 4: return InpTradeThursday;
      case 5: return InpTradeFriday;
      case 6: return InpTradeSaturday;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   // เวลาเปิดของแท่งปัจจุบัน (index 0) บน TF ที่กำหนด
   datetime curBarOpen = iTime(_Symbol, InpEntryTF, 0);
   if(curBarOpen == 0)
      return;

   // ตรวจ "แท่งใหม่": ถ้าแท่งปัจจุบันเพิ่งเปิด แปลว่าแท่งก่อนหน้า (index 1) เพิ่งปิด
   if(curBarOpen == g_lastCycleBarTime)
      return; // รอบนี้จัดการไปแล้ว

   // เวลาเปิดแท่งปัจจุบัน = เวลาปิดของแท่งข่าว
   // ข่าว 19:30 -> แท่ง 19:15-19:30 ปิดตอน 19:30 -> แท่งใหม่เปิดที่ 19:30
   MqlDateTime bt;
   TimeToStruct(curBarOpen, bt);

   if(bt.hour != InpNewsHour || bt.min != InpNewsMinute)
      return; // ยังไม่ถึงเวลาข่าว

   if(!IsTradingDay(bt))
     {
      g_lastCycleBarTime = curBarOpen; // ทำเครื่องหมายว่าผ่านรอบนี้แล้ว
      return;
     }

   // ถึงเวลาข่าว + แท่ง 15M ปิดพอดี -> วางออเดอร์
   PlaceStraddle(curBarOpen);
   g_lastCycleBarTime = curBarOpen; // กันวางซ้ำในรอบเดียวกัน
  }

//+------------------------------------------------------------------+
//| อ่านค่า ATR ของแท่งที่ปิดแล้ว (index 1)                            |
//+------------------------------------------------------------------+
double GetATR()
  {
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(atrHandle, 0, 1, 1, buf) < 1)
      return 0.0;
   return buf[0];
  }

//+------------------------------------------------------------------+
//| คำนวณลอตจาก เงินเสี่ยงต่อไม้ / ระยะ SL (เป็นราคา)                  |
//+------------------------------------------------------------------+
double CalcLot(double slDistancePrice)
  {
   if(slDistancePrice <= 0.0)
      return 0.0;

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;

   // ขาดทุนต่อ 1.0 lot เมื่อราคาวิ่งเท่าระยะ SL
   double lossPerLot = (slDistancePrice / tickSize) * tickValue;
   if(lossPerLot <= 0.0)
      return 0.0;

   double lot = InpRiskMoney / lossPerLot;

   // ปรับให้ตรง lot step และขอบเขตของโบรก + ขอบเขตที่ผู้ใช้ตั้ง
   double stepLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double brokerMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double brokerMax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(stepLot > 0.0)
      lot = MathFloor(lot / stepLot) * stepLot;

   double lowLimit  = MathMax(brokerMin, InpMinLot);
   double highLimit = MathMin(brokerMax, InpMaxLot);

   if(lot < lowLimit)  lot = lowLimit;
   if(lot > highLimit) lot = highLimit;

   return NormalizeDouble(lot, 2);
  }

//+------------------------------------------------------------------+
//| วาง Buy Stop + Sell Stop คร่อมราคาปิดแท่งข่าว                      |
//+------------------------------------------------------------------+
void PlaceStraddle(datetime cycleBar)
  {
   double atr = GetATR();
   if(atr <= 0.0)
     {
      Print("ATR ไม่พร้อม ข้ามรอบนี้");
      return;
     }

   // เช็กสเปรด (ถ้าเปิดใช้งาน)
   if(InpMaxSpreadPoints > 0)
     {
      long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > InpMaxSpreadPoints)
        {
         PrintFormat("สเปรด %d เกิน %d ข้ามรอบนี้", spread, InpMaxSpreadPoints);
         return;
        }
     }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // ราคาอ้างอิง = ราคาปิดแท่งข่าว (แท่งที่เพิ่งปิด = index 1)
   double anchor = iClose(_Symbol, InpEntryTF, 1);
   if(anchor <= 0.0)
      return;

   double entryDist = atr * InpEntryMultiplier; // ระยะจาก anchor ไปจุดวางออเดอร์
   double slDist    = atr * InpSLMultiplier;    // ระยะ SL
   double tpDist    = slDist * InpRR;           // ระยะ TP

   // ---------- Buy Stop ----------
   double buyPrice = NormalizeDouble(anchor + entryDist, digits);
   double buySL    = NormalizeDouble(buyPrice - slDist, digits);
   double buyTP    = NormalizeDouble(buyPrice + tpDist, digits);

   // ---------- Sell Stop ----------
   double sellPrice = NormalizeDouble(anchor - entryDist, digits);
   double sellSL    = NormalizeDouble(sellPrice + slDist, digits);
   double sellTP    = NormalizeDouble(sellPrice - tpDist, digits);

   // ตรวจ stops level ขั้นต่ำของโบรก (ระยะ pending จากราคาตลาดปัจจุบัน)
   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist    = stopsLevel * point;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Buy Stop ต้องอยู่สูงกว่า Ask อย่างน้อย stops level
   if(buyPrice - ask < minDist)
      buyPrice = NormalizeDouble(ask + minDist + point, digits);
   // Sell Stop ต้องอยู่ต่ำกว่า Bid อย่างน้อย stops level
   if(bid - sellPrice < minDist)
      sellPrice = NormalizeDouble(bid - minDist - point, digits);

   // ปรับ SL/TP ตามราคา entry ที่อาจถูกเลื่อน
   buySL  = NormalizeDouble(buyPrice - slDist, digits);
   buyTP  = NormalizeDouble(buyPrice + tpDist, digits);
   sellSL = NormalizeDouble(sellPrice + slDist, digits);
   sellTP = NormalizeDouble(sellPrice - tpDist, digits);

   // ลอต (คิดจากระยะ SL)
   double lot = CalcLot(slDist);
   if(lot <= 0.0)
     {
      Print("คำนวณลอตไม่ได้ ข้ามรอบนี้");
      return;
     }

   // เวลาและประเภทหมดอายุของ pending
   ENUM_ORDER_TYPE_TIME typeTime = ORDER_TIME_GTC;
   datetime expiration = 0;
   if(InpExpireMinutes > 0)
     {
      typeTime   = ORDER_TIME_SPECIFIED;
      expiration = TimeCurrent() + (datetime)InpExpireMinutes * 60;
     }

   string cmt = InpComment;

   // วาง Buy Stop
   if(!trade.BuyStop(lot, buyPrice, _Symbol, buySL, buyTP, typeTime, expiration, cmt))
      PrintFormat("วาง Buy Stop ไม่สำเร็จ err=%d", trade.ResultRetcode());
   else
      PrintFormat("Buy Stop @%.*f SL=%.*f TP=%.*f lot=%.2f", digits, buyPrice, digits, buySL, digits, buyTP, lot);

   // วาง Sell Stop
   if(!trade.SellStop(lot, sellPrice, _Symbol, sellSL, sellTP, typeTime, expiration, cmt))
      PrintFormat("วาง Sell Stop ไม่สำเร็จ err=%d", trade.ResultRetcode());
   else
      PrintFormat("Sell Stop @%.*f SL=%.*f TP=%.*f lot=%.2f", digits, sellPrice, digits, sellSL, digits, sellTP, lot);
  }
//+------------------------------------------------------------------+
