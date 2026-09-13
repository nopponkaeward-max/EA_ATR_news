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

//====================== ENUMS =======================================
enum ENUM_ENTRY_MODE
  {
   ENTRY_NEWS     = 0,  // 1. News Time
   ENTRY_RSI      = 1,  // 2. RSI OB/OS
   ENTRY_NEWS_RSI = 2   // 3. News + RSI
  };
enum ENUM_RSI_TRIG
  {
   RSI_ON_CROSS      = 0, // ตัดเข้าโซน (กันวางซ้ำ)
   RSI_ON_EXIT       = 1, // กลับมาตัดออกจากโซนครั้งแรก (reversal)
   RSI_WHILE_IN_ZONE = 2  // ทุกแท่งที่อยู่ในโซน
  };
enum ENUM_RSI_DIR
  {
   RSI_BOTH     = 0, // Both (straddle)
   RSI_A_OBSELL = 1, // A: OB->Sell / OS->Buy
   RSI_B_OBBUY  = 2  // B: OB->Buy / OS->Sell
  };

//====================== INPUTS ======================================
input group "=== Entry Mode ==="
input ENUM_ENTRY_MODE InpEntryMode = ENTRY_NEWS; // โหมดเข้าออเดอร์

input group "=== RSI (ใช้กับ Entry Mode 2/3) ==="
input int             InpRSIPeriod = 14;            // RSI Period
input ENUM_TIMEFRAMES InpRSITF     = PERIOD_CURRENT;// RSI Timeframe (CURRENT = TF เดียวกับ ATR/กราฟ)
input double          InpRSIOB     = 70.0;          // Overbought
input double          InpRSIOS     = 30.0;          // Oversold
input ENUM_RSI_TRIG   InpRSITrig   = RSI_ON_CROSS;  // ทริกตอนตัดเข้าโซน หรือ ทุกแท่งในโซน
input ENUM_RSI_DIR    InpRSIDir    = RSI_BOTH;      // ทิศทางเมื่อเจอ OB/OS

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
input double   InpSLMultiplier    = 1.0;     // ตัวคูณ ATR สำหรับระยะ SL (ใช้เมื่อ SL Distance = 0)
input double   InpRR              = 2.0;     // Risk:Reward (TP = ระยะSL x RR, ใช้เมื่อ TP Distance = 0)

input group "=== Fixed TP/SL Distance (หน่วย=ราคา 1=1.0; 0 = ใช้ ATR) ==="
input double   InpSLDistFix       = 0.0;     // SL Distance (0 = ใช้ SL x ATR) — เช่น XAUUSD 1 = ระยะ 1.0
input double   InpTPDistFix       = 0.0;     // TP Distance (0 = ใช้ ระยะSL x RR)

input group "=== การจัดการเงิน / ออเดอร์ ==="
input double   InpRiskMoney       = 10.0;    // เงินเสี่ยงต่อไม้ (สกุลบัญชี) -> lot = RiskMoney / ระยะSL
input double   InpMinLot          = 0.01;    // ลอตขั้นต่ำที่ยอมให้เปิด
input double   InpMaxLot          = 5.0;     // ลอตสูงสุดที่ยอมให้เปิด
input int      InpExpireMinutes   = 60;      // นาทีที่ pending จะหมดอายุ (0 = ไม่หมดอายุ)
input int      InpMaxSpreadPoints = 0;       // สเปรดสูงสุดที่ยอมวาง (points, 0 = ปิดการเช็ก)
input bool     InpOneTradeAtATime = false;   // เปิดได้ครั้งละ 1 ชุด (มี position/pending ค้าง ห้ามวางใหม่)
input bool     InpOCO             = false;   // OCO: ฝั่งหนึ่งถูกเปิด -> ยกเลิก pending อีกฝั่ง
input long     InpMagicNumber     = 20250911;// Magic Number
input string   InpComment         = "ATR_News";

input group "=== Re-Entry (เมื่อโดน SL แล้วราคากลับมาจุดเปิดเดิม) ==="
input bool     InpReentryOn         = false; // เปิดใช้ Re-Entry
input int      InpReentryMax        = 1;     // จำนวน re-entry สูงสุด (1 = ถึง Order-2)
input int      InpReentryExpireMin  = 0;     // นาทีหมดอายุของ pending re-entry (0 = ไม่หมดอายุ)

//====================== GLOBALS =====================================
CTrade   trade;
int      atrHandle = INVALID_HANDLE;
int      rsiHandle = INVALID_HANDLE;
datetime g_lastCycleBarTime = 0;   // เวลาแท่งล่าสุดที่ประมวลผลแล้ว (ประมวลผล 1 ครั้งต่อแท่ง)

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

   rsiHandle = iRSI(_Symbol, InpRSITF, InpRSIPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
     {
      Print("สร้าง RSI handle ไม่สำเร็จ");
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFillingBySymbol(_Symbol);

   PrintFormat("EA_ATR_News เริ่มทำงาน | Mode=%s | ข่าว %02d:%02d (server) | TF=%s | ATR=%d | RSI=%d(%.0f/%.0f)",
               EnumToString(InpEntryMode), InpNewsHour, InpNewsMinute, EnumToString(InpEntryTF),
               InpATRPeriod, InpRSIPeriod, InpRSIOB, InpRSIOS);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(atrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(atrHandle);
      atrHandle = INVALID_HANDLE;
     }
   if(rsiHandle != INVALID_HANDLE)
     {
      IndicatorRelease(rsiHandle);
      rsiHandle = INVALID_HANDLE;
     }
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
//| นับ position ของ EA นี้ (ตาม magic + symbol)                       |
//+------------------------------------------------------------------+
int CountPositions()
  {
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         c++;
     }
   return c;
  }

//+------------------------------------------------------------------+
//| นับ pending order ของ EA นี้                                      |
//+------------------------------------------------------------------+
int CountPendingOrders()
  {
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         c++;
     }
   return c;
  }

//+------------------------------------------------------------------+
//| ลบ pending order ทั้งหมดของ EA นี้ (ใช้กับ OCO)                    |
//+------------------------------------------------------------------+
void DeleteAllPendings()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         trade.OrderDelete(tk);
     }
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   // --- OCO: ถ้ามี position เปิดแล้ว -> ยกเลิก pending ที่เหลือ (อีกฝั่ง) ---
   if(InpOCO && CountPositions() > 0 && CountPendingOrders() > 0)
      DeleteAllPendings();

   // เวลาเปิดของแท่งปัจจุบัน (index 0) บน TF ที่กำหนด
   datetime curBarOpen = iTime(_Symbol, InpEntryTF, 0);
   if(curBarOpen == 0)
      return;

   // ประมวลผล 1 ครั้งต่อ "แท่งใหม่" (แท่งก่อนหน้า index 1 เพิ่งปิด)
   if(curBarOpen == g_lastCycleBarTime)
      return;
   g_lastCycleBarTime = curBarOpen; // ทำเครื่องหมายว่าประมวลผลแท่งนี้แล้ว

   // เวลาเปิดแท่งปัจจุบัน = เวลาปิดของแท่งที่เพิ่งจบ
   MqlDateTime bt;
   TimeToStruct(curBarOpen, bt);

   if(!IsTradingDay(bt))
      return;

   // --- One trade at a time: มี position หรือ pending ค้างอยู่ -> ไม่เริ่มชุดใหม่ ---
   if(InpOneTradeAtATime && (CountPositions() > 0 || CountPendingOrders() > 0))
      return;

   bool useNews = (InpEntryMode == ENTRY_NEWS || InpEntryMode == ENTRY_NEWS_RSI);
   bool useRSI  = (InpEntryMode == ENTRY_RSI  || InpEntryMode == ENTRY_NEWS_RSI);

   bool allowBuy  = false;
   bool allowSell = false;
   string trigTxt = "";

   // --- News trigger ---
   if(useNews && bt.hour == InpNewsHour && bt.min == InpNewsMinute)
     {
      allowBuy  = true;
      allowSell = true;
      trigTxt   = "News";
     }

   // --- RSI trigger ---
   if(useRSI)
     {
      double rCur, rPrev;
      if(GetRSI(rCur, rPrev))
        {
         bool inOB    = rCur >= InpRSIOB;
         bool inOS    = rCur <= InpRSIOS;
         bool crossOB = inOB && rPrev <  InpRSIOB;      // ตัดขึ้นเข้าโซน OB
         bool crossOS = inOS && rPrev >  InpRSIOS;      // ตัดลงเข้าโซน OS
         bool exitOB  = (rCur < InpRSIOB) && (rPrev >= InpRSIOB); // ตัดลงทะลุ OB กลับมา
         bool exitOS  = (rCur > InpRSIOS) && (rPrev <= InpRSIOS); // ตัดขึ้นทะลุ OS กลับมา
         bool sigOB   = (InpRSITrig == RSI_WHILE_IN_ZONE) ? inOB : (InpRSITrig == RSI_ON_EXIT) ? exitOB : crossOB;
         bool sigOS   = (InpRSITrig == RSI_WHILE_IN_ZONE) ? inOS : (InpRSITrig == RSI_ON_EXIT) ? exitOS : crossOS;

         if(sigOB || sigOS)
           {
            if(InpRSIDir == RSI_BOTH)
              {
               allowBuy  = true;
               allowSell = true;
              }
            else if(InpRSIDir == RSI_A_OBSELL)
              {
               if(sigOB) allowSell = true;
               if(sigOS) allowBuy  = true;
              }
            else // RSI_B_OBBUY
              {
               if(sigOB) allowBuy  = true;
               if(sigOS) allowSell = true;
              }
            trigTxt = (StringLen(trigTxt) > 0 ? trigTxt + "+" : "") + "RSI " + DoubleToString(rCur, 1);
           }
        }
     }

   if(allowBuy || allowSell)
      PlaceStraddle(allowBuy, allowSell, trigTxt);
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
//| อ่านค่า RSI ของแท่งที่ปิด (index 1) และแท่งก่อนหน้า (index 2)       |
//+------------------------------------------------------------------+
bool GetRSI(double &cur, double &prev)
  {
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(rsiHandle, 0, 1, 2, buf) < 2)
      return false;
   cur  = buf[0]; // แท่งที่เพิ่งปิด (index 1)
   prev = buf[1]; // แท่งก่อนหน้า (index 2)
   return true;
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
void PlaceStraddle(bool allowBuy, bool allowSell, string trigTxt)
  {
   if(!allowBuy && !allowSell)
      return;

   // จุดเข้า (entry) ใช้ ATR เสมอ; SL/TP ถ้ากรอก Distance > 0 จะใช้ระยะคงที่แทน ATR
   double atr = GetATR();
   if(atr <= 0.0)
     {
      Print("ATR ไม่พร้อม ข้ามรอบนี้");
      return;
     }
   double entryDist = atr * InpEntryMultiplier;
   double slDist    = InpSLDistFix > 0.0 ? InpSLDistFix : atr * InpSLMultiplier;
   double tpDist    = InpTPDistFix > 0.0 ? InpTPDistFix : slDist * InpRR;
   if(slDist <= 0.0)
      return;

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

   // ราคาอ้างอิง = ราคาปิดแท่งที่เพิ่งปิด (index 1)
   double anchor = iClose(_Symbol, InpEntryTF, 1);
   if(anchor <= 0.0)
      return;

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

   string cmt = (StringLen(trigTxt) > 0 ? InpComment + " " + trigTxt : InpComment) + " Order-1";

   // วาง Buy Stop (เฉพาะฝั่งที่อนุญาต)
   if(allowBuy)
     {
      if(!trade.BuyStop(lot, buyPrice, _Symbol, buySL, buyTP, typeTime, expiration, cmt))
         PrintFormat("วาง Buy Stop ไม่สำเร็จ err=%d", trade.ResultRetcode());
      else
         PrintFormat("[%s] Buy Stop @%.*f SL=%.*f TP=%.*f lot=%.2f", trigTxt, digits, buyPrice, digits, buySL, digits, buyTP, lot);
     }

   // วาง Sell Stop (เฉพาะฝั่งที่อนุญาต)
   if(allowSell)
     {
      if(!trade.SellStop(lot, sellPrice, _Symbol, sellSL, sellTP, typeTime, expiration, cmt))
         PrintFormat("วาง Sell Stop ไม่สำเร็จ err=%d", trade.ResultRetcode());
      else
         PrintFormat("[%s] Sell Stop @%.*f SL=%.*f TP=%.*f lot=%.2f", trigTxt, digits, sellPrice, digits, sellSL, digits, sellTP, lot);
     }
  }

//+------------------------------------------------------------------+
//| อ่านเลข generation จากคอมเมนต์ (เช่น "... Order-2" -> 2)           |
//+------------------------------------------------------------------+
int ParseGen(string comment)
  {
   int p = StringFind(comment, "Order-");
   if(p < 0)
      return 1;
   string tail = StringSubstr(comment, p + 6);
   int g = (int)StringToInteger(tail);
   return g < 1 ? 1 : g;
  }

//+------------------------------------------------------------------+
//| Re-Entry: เมื่อ position โดน SL -> ตั้ง pending Order ถัดไป        |
//| ที่ "จุดเปิดเดิม" ทิศทางเดิม (รอราค้ากลับมาที่ entry)              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(!InpReentryOn)
      return;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong dealTk = trans.deal;
   if(dealTk == 0 || !HistoryDealSelect(dealTk))
      return;
   if(HistoryDealGetInteger(dealTk, DEAL_MAGIC)  != InpMagicNumber) return;
   if(HistoryDealGetString(dealTk, DEAL_SYMBOL)  != _Symbol)        return;
   if(HistoryDealGetInteger(dealTk, DEAL_ENTRY)  != DEAL_ENTRY_OUT) return; // เฉพาะตอนปิด
   if(HistoryDealGetInteger(dealTk, DEAL_REASON) != DEAL_REASON_SL) return; // เฉพาะโดน SL
   if(HistoryDealGetDouble(dealTk, DEAL_PROFIT)  >= 0.0)            return;

   long   posId    = HistoryDealGetInteger(dealTk, DEAL_POSITION_ID);
   double slPrice  = HistoryDealGetDouble(dealTk, DEAL_PRICE);      // ราคาปิด ~ SL
   long   dealType = HistoryDealGetInteger(dealTk, DEAL_TYPE);
   bool   wasBuy   = (dealType == DEAL_TYPE_SELL);                  // ปิด BUY ด้วย SELL

   // หา entry price + generation จาก deal เปิด (IN) ของ position นี้
   double entry = 0.0;
   int    gen   = 1;
   if(HistorySelectByPosition(posId))
     {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong dk = HistoryDealGetTicket(i);
         if(dk == 0) continue;
         if(HistoryDealGetInteger(dk, DEAL_ENTRY) == DEAL_ENTRY_IN)
           {
            entry = HistoryDealGetDouble(dk, DEAL_PRICE);
            gen   = ParseGen(HistoryDealGetString(dk, DEAL_COMMENT));
            break;
           }
        }
     }
   if(entry <= 0.0)     return;
   if(gen > InpReentryMax) return; // เกินจำนวน re-entry ที่กำหนด

   double slDist = MathAbs(entry - slPrice);
   if(slDist <= 0.0)    return;
   double tpDist = InpTPDistFix > 0.0 ? InpTPDistFix : slDist * InpRR;

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double lvl    = NormalizeDouble(entry, digits);
   double sl     = wasBuy ? NormalizeDouble(lvl - slDist, digits) : NormalizeDouble(lvl + slDist, digits);
   double tp     = wasBuy ? NormalizeDouble(lvl + tpDist, digits) : NormalizeDouble(lvl - tpDist, digits);

   double lot = CalcLot(slDist);
   if(lot <= 0.0)       return;

   ENUM_ORDER_TYPE_TIME typeTime = ORDER_TIME_GTC;
   datetime expiration = 0;
   if(InpReentryExpireMin > 0)
     {
      typeTime   = ORDER_TIME_SPECIFIED;
      expiration = TimeCurrent() + (datetime)InpReentryExpireMin * 60;
     }

   int    newGen = gen + 1;
   string cmt    = InpComment + " Order-" + IntegerToString(newGen);

   bool ok = wasBuy ? trade.BuyStop(lot, lvl, _Symbol, sl, tp, typeTime, expiration, cmt)
                    : trade.SellStop(lot, lvl, _Symbol, sl, tp, typeTime, expiration, cmt);
   if(ok)
      PrintFormat("Re-Entry -> Order-%d %s @%.*f SL=%.*f TP=%.*f lot=%.2f",
                  newGen, wasBuy ? "BUY" : "SELL", digits, lvl, digits, sl, digits, tp, lot);
   else
      PrintFormat("Re-Entry Order-%d วางไม่สำเร็จ err=%d", newGen, trade.ResultRetcode());
  }
//+------------------------------------------------------------------+
