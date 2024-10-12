//+------------------------------------------------------------------+
//|                                                 Ldn_SprTrend.mq5 |
//|                            Copyright 2024, Chaitanya Palghadmal. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Chaitanya Palghadmal."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade trade;
int Spr_Trend;
int m15index;
int m5index;
int m1index;
double points5 = 0.00005;
double trendbuffer[];
double OBhigh, OBlow;
MqlRates bars15[];
MqlRates bars5[];
MqlRates bars1[];
MqlDateTime dt = {};
double risk = 0.015;

bool NewBar()
{
    static datetime previous_time = 0;
    datetime current_time = iTime(Symbol(),Period(),0);
    
    if (previous_time !=  current_time) // is 0
    {
        previous_time = current_time;
        return true;
    }

    return false;
}

void OBbull(ENUM_TIMEFRAMES TF, MqlRates& bars[], int a)
{
   //Finds bullish OB
   
   //Check if prev. candle close < prev.candle open
   //or prev. candle low < prev. prev. candle low
   //Mark OB levels if condition is satisfied
   //else iterate to previous candle
   
   //Code
   int i = a+1;
   for(i; i<=ArraySize(bars)+1; i++){
      if(bars[i].close <= bars[i].open || bars[i].low <= bars[i+1].low){
         insideBar(TF, bars, i);
         
         break;
      } else {
         continue;
      }
   }
}

void OBbear(ENUM_TIMEFRAMES TF, MqlRates& bars[], int a)
{
   //Finds bearish OB
   
   //Check if prev.candle close > prev. candle open
   //of prev. candle high > prev. prev. candle high
   //Mark OB levels if condition is satisfied
   //else iterate to previous candle
   
   //Code
   int i = a+1;
   for(i; i<=ArraySize(bars)+1; i++){
      if(bars[i].close >= bars[i].open || bars[i].high >= bars[i+1].high){
         insideBar(TF, bars, i);
         
         break;
      } else {
         continue;
      }
   }
}

int forewardScanBull(MqlRates& bars[], int a)
{
   //For finding bullish OB level breaks
   for(a; a>=1; a--){
      if(bars[a].close > OBhigh){
         return(a);
         break;
      } else {
         continue;
      }
   }
   
   return(1);
}

int forewardScanBear(MqlRates& bars[], int a)
{
   //For finding bearish OB level breaks
   for(a; a>=1; a--){
      if(bars[a].close < OBlow){
         return(a);
         break;
      } else {
         continue;
      }
   }
   
   return(1);
}

void insideBar(ENUM_TIMEFRAMES TF, MqlRates& bars[], int a)
{
   //Check inside bars
   
   //If next candle high < current candle high
   //and next candle low > current candle low
   //iterate to next candle and check again
   //else update OB levels
   
   //Code
   for(a; a>=1; a--) {
      if(bars[a].high >= bars[a-1].high && bars[a].low <= bars[a-1].low) {
         continue;
      } else {
         OBhigh = bars[a].high;
         OBlow = bars[a].low;
         break;
      }
   }
   
   if(TF == PERIOD_M15){
      m15index = a;
   } else if(TF == PERIOD_M5){
      m5index = a;
   } else {
      m1index = a;
   }

}

double Roundup(double price, double upto)
{
   return MathCeil(price/upto)*upto;
}

double Rounddown(double price, double downto)
{
   return MathFloor(price/downto)*downto;
}

bool checkdt(){
   int hourmin = (dt.hour*100)+dt.min;
   //((hourmin >= 0930 && hourmin <= 1130) || (hourmin >= 1430 && hourmin <= 1730))
   if(dt.day <= 16 && ( (hourmin >= 1230 && hourmin <= 1315) || (hourmin >= 1515 && hourmin <= 1545) )){
      return(true);
   } else {
      return(false);
   }
}

bool checkorder(){
   if(OrdersTotal() == 0 && PositionsTotal() == 0) {
      return(true);
   } else {
      return(false);
   }
}

double calcsl(){
   double sl = 0;
   double slpts = OBhigh-OBlow;
   if(trendbuffer[0] == -1.0){
      if(slpts<0.00015){
         sl = OBhigh - 0.00030;
      }else {
         sl = OBhigh - slpts - 0.00015;
      }
   } else if(trendbuffer[0] == 1.0){
      if(slpts<0.00015){
         sl = OBlow + 0.00030;
      }else {
         sl = OBlow + slpts + 0.00015;
      }
   }
   
   return(sl);
}

double hedgesl(){
   return NormalizeDouble((AccountInfoDouble(ACCOUNT_BALANCE)*risk/calcvol())*_Point, 5);
}

double hedgetp(){
   return hedgesl()*10;
}

double calctp(){
   double tp = 0;
   double tppts;
   double slpts;
   if(trendbuffer[0] == -1.0){
      slpts = OBhigh - calcsl();
      tppts = slpts*7.5;
      tp = OBhigh + tppts;
   }else if(trendbuffer[0] == 1.0){
      slpts = calcsl() - OBlow;
      tppts = slpts*7.5;
      tp = OBlow - tppts;
   }
   return(tp);
}

double calcvol(){
   double slpts = 0;
   double vol = 0;
   if(trendbuffer[0] == -1.0){
      slpts = OBhigh - calcsl();
   } else if(trendbuffer[0] == 1.0){
      slpts = calcsl() - OBlow;
   }
   
   vol = AccountInfoDouble(ACCOUNT_BALANCE)*risk/(slpts*100000);
   return(vol);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   Spr_Trend = iCustom("EURUSD", PERIOD_M15, "Market\\supertrend");
   CopyRates(_Symbol, PERIOD_M15, 0, 25, bars15);
   CopyRates(_Symbol, PERIOD_M5, 0, 75, bars5);
   CopyRates(_Symbol, PERIOD_M1, 0, 375, bars1);
   ArraySetAsSeries(bars15, true);
   ArraySetAsSeries(bars5, true);
   ArraySetAsSeries(bars1, true);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(NewBar()) {
      CopyBuffer(Spr_Trend, 8, 0, 3, trendbuffer);
      
      if(trendbuffer[1] != trendbuffer[0]) {
         m15index = 1;
         //Insert OB code and order execution
         CopyRates(_Symbol, PERIOD_M15, 0, 25, bars15);
         CopyRates(_Symbol, PERIOD_M5, 0, 75, bars5);
         CopyRates(_Symbol, PERIOD_M1, 0, 375, bars1);
         
         if(trendbuffer[0] == -1.0){
            OBbull(PERIOD_M15, bars15, m15index);
            m5index = forewardScanBull(bars5, m15index * 3);
            OBbull(PERIOD_M5, bars5, m5index);
            m1index = forewardScanBull(bars1, m5index * 5);
            OBbull(PERIOD_M1, bars1, m1index);
         }else {
            OBbear(PERIOD_M15, bars15, m15index);
            m5index = forewardScanBear(bars5, m15index * 3);
            OBbear(PERIOD_M5, bars5, m5index);
            m1index = forewardScanBear(bars1, m5index * 5);
            OBbear(PERIOD_M1, bars1, m1index);
            
            if(bars1[m1index].close >= bars1[m1index].open){
               OBlow = bars1[m1index].open;
            } else {
               OBlow = bars1[m1index].close;
            }
         }
            
         //Print("M15 index: ", m15index, " M5 index: ", m5index, " M1 index: ", m1index);
         
         OBhigh = Roundup(OBhigh, points5);
         OBlow = Rounddown(OBlow, points5);
         
         TimeCurrent(dt);
         MqlDateTime expirystruct = dt;
         expirystruct.day = dt.day+1;
         expirystruct.hour = 11;
         expirystruct.min = 30;
         expirystruct.sec = 0;
         
         datetime expiry = StructToTime(expirystruct);
         
         if(trendbuffer[0] == -1.0 && checkdt() && checkorder() ) {
            //trade.BuyLimit(NormalizeDouble(calcvol(), 2), OBhigh, _Symbol, calcsl(), calctp(), ORDER_TIME_SPECIFIED, expiry, NULL);
            
            //Error handling
            if(!trade.BuyLimit(NormalizeDouble(calcvol(), 2), OBhigh, _Symbol, calcsl()-_Point, calctp(), ORDER_TIME_DAY, 0, NULL)){
               trade.BuyStop(NormalizeDouble(calcvol(), 2), OBhigh, _Symbol, calcsl()-_Point, calctp(), ORDER_TIME_DAY, 0, NULL);
            }
            trade.SellStop(NormalizeDouble(calcvol(), 2), calcsl(), _Symbol, calcsl()+hedgesl(), calcsl()-hedgetp(), ORDER_TIME_DAY, 0, NULL);

         } else if(trendbuffer[0] == 1.0 && checkdt() && checkorder() ) {
            //trade.SellLimit(NormalizeDouble(calcvol(), 2), OBlow, _Symbol, calcsl(), calctp(), ORDER_TIME_SPECIFIED, expiry, NULL);
            
            //Error handling
            if(!trade.SellLimit(NormalizeDouble(calcvol(), 2), OBlow, _Symbol, calcsl()+_Point, calctp(), ORDER_TIME_DAY, 0, NULL)){
               trade.SellStop(NormalizeDouble(calcvol(), 2), OBlow, _Symbol, calcsl()+_Point, calctp(), ORDER_TIME_DAY, 0, NULL);
            }
            trade.BuyStop(NormalizeDouble(calcvol(), 2), calcsl(), _Symbol, calcsl()-hedgesl(), calcsl()+hedgetp(), ORDER_TIME_DAY, 0, NULL);

         }
      }
   }
  }
//+------------------------------------------------------------------+
