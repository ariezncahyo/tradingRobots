//+------------------------------------------------------------------+
//|                                            Kangaroo_Daily_V2.mq4 |
//|                              Copyright 2016, Francinaldo Portela |
//|                                   http://www.twitter.com/naldorp |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, Francinaldo Portela"
#property link      "http://www.twitter.com/naldorp"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Strategy Definition                                               
//+------------------------------------------------------------------+
/*
NAME: Kangaroo Tail
SELL RULES:
   1. weak high should represent more than 60% of total size of candle
   2. the body should be within the previous candle
   3. the kangaroo tail candle should be larger that the previous one
   4. no price action above 10% of the high in the candle. Eg. No price action above (High - 10%)
   
BUY RULES:
   1. The close of first candle should be higher than second one.(Close1 >= Close2)
   2. The body should be larger than 3 of 5 candles.
   3. It must have a higher high.Eg. (Low1 >= Low2)
   4. Weak high should represent 30% percent of candle AT MAXIMUM.
   5. The previous 5 candles should not close under the first candle open.
   6. The first candle should be bullish.
   7. The second candle should be bearish.
   
STOP/TRAILING/RISK/TIMEFRAME:
# Stop Loss: At low/high of the first candle;
# Risk: 1/1
# Timeframe: Daily/4H
*/

//+------------------------------------------------------------------+
//| Setup                                               
//+------------------------------------------------------------------+
extern string  Header1="----------Trading Rules Variables-----------";
extern int     ExpirationDateInHours=72;
extern double  ProfitFactor=1;
extern int     Interval=50;
extern double  CandleMinimalSize=500;
extern double  SpaceToLeftMinimalDistance=0.25;
extern double  CandleWeakMinimal = 60;


extern string  Header2="----------Position Sizing Settings-----------";
extern string  Lot_explanation="If IsSizingOn = true, Lots variable will be ignored";
extern double  Lots=0;
extern bool    IsSizingOn=True;
extern double  Risk=5; // Risk per trade (in percentage)

extern string  Header3="----------TP & SL Settings-----------";

extern bool    UseFixedStopLoss=False; // If this is false and IsSizingOn = True, sizing algo will not be able to calculate correct lot size. 
extern double  FixedStopLoss=0; // Hard Stop in Pips. Will be overridden if vol-based SL is true 
extern bool    IsVolatilityStopOn=False;
extern double  VolBasedSLMultiplier=6; // Stop Loss Amount in units of Volatility

extern bool    UseFixedTakeProfit=False;
extern double  FixedTakeProfit=0; // Hard Take Profit in Pips. Will be overridden if vol-based TP is true 
extern bool    IsVolatilityTakeProfitOn=False;
extern double  VolBasedTPMultiplier=6; // Take Profit Amount in units of Volatility

extern string  Header5="----------Breakeven Stops Settings-----------";
extern bool    UseBreakevenStops=False;
extern double  BreakevenBuffer=0; // In pips

extern string  Header7="----------Trailing Stops Settings-----------";
extern bool    UseTrailingStops=False;
extern double  TrailingStopDistance=0; // In pips
extern double  TrailingStopBuffer=0; // In pips

extern string  Header12="----------Max Orders-----------";
extern int     MaxPositionsAllowed=1;

extern string  Header13="----------Set Max Loss Limit-----------";
extern bool    IsLossLimitActivated=True;
extern double  LossLimitPercent=50;

extern string  Header15="----------EA General Settings-----------";
extern int     MagicNumber=12345;
extern int     Slippage=3; // In Pips
extern bool    IsECNbroker = false; // Is your broker an ECN
extern bool    OnJournaling = true; // Add EA updates in the Journal Tab

string  InternalHeader1="----------Errors Handling Settings-----------";
int     RetryInterval=100; // Pause Time before next retry (in milliseconds)
int     MaxRetriesPerTick=10;

string  InternalHeader2="----------Service Variables-----------";

double Stop,Take;
double P,YenPairAdjustFactor;

//+------------------------------------------------------------------+
//| BUY/SELL PRICE/TP/SL VAR DECLARATION                                              
//+------------------------------------------------------------------+
double _BuyPrice;
double _BuyTakeProfit;
double _BuyStopLoss;

double _SellPrice;
double _SellTakeProfit;
double _SellStopLoss;

datetime _ExpirationDate;

//+------------------------------------------------------------------+
//| CANDLE CHARACTERISTICS VAR DECLARATION                                             
//+------------------------------------------------------------------+
double _Candle_WeakLow;
double _Candle_WeakHigh;
double _Candle_BodySize;
double _Candle_TotalSize;//Total size in points
double _Candle_TotalSizePrice;//total size in price

double _Bars_Open[15] = {};
double _Bars_Close[15] = {};
double _Bars_High[15] = {};
double _Bars_Low[15] = {};

//+------------------------------------------------------------------+
//| STRATEGY CONDITIONS VARIABLES                                            
//+------------------------------------------------------------------+
bool _Condition_isWeakAcceptable;
bool _Condition_isCloseWithinPreviousCandle;
bool _Condition_isCandleLargerThanPrevious;
bool _Condition_isCandleBigEnough;
bool _Condition_hasSpaceToTheLeft;

/*
bool _Condition_hasHigherHighAndLowerLow;
bool _Condition_isFirstCandleBearish;
bool _Condition_isFirstCandleBullish;
bool _Condition_isSecondCandleBearish;
bool _Condition_isSecondCandleBullish;
*/
 
      
int OrderNumber;

//| End of Setup                                          
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert Initialization                                    
//+------------------------------------------------------------------+
int init()
  {
   P=GetP(); // To account for 5 digit brokers. Used to convert pips to decimal place
   YenPairAdjustFactor=GetYenAdjustFactor(); // Adjust for YenPair

   start();
   return(0);
  }
//+------------------------------------------------------------------+
//| End of Expert Initialization                            
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert Deinitialization                                  
//+------------------------------------------------------------------+
int deinit()
  {
//----

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| End of Expert Deinitialization                          
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert start                                             
//+------------------------------------------------------------------+
int start()
  {

//----------Variables to be Refreshed-----------

OrderNumber=0; // OrderNumber used in Entry Rules

//load the last 15 bars into the array
for(int i=0; i< 15; i++){
      _Bars_Open[i] = NormalizeDouble(iOpen(Symbol(), Period(), i+1), Digits);
      _Bars_Close[i] = NormalizeDouble(iClose(Symbol(), Period(), i+1), Digits);
      _Bars_High[i] = NormalizeDouble(iHigh(Symbol(), Period(), i+1), Digits);
      _Bars_Low[i] = NormalizeDouble(iLow(Symbol(), Period(), i+1), Digits);
}

//+------------------------------------------------------------------+
//| Define Candle Characteristics                                          
//+------------------------------------------------------------------+
_Candle_TotalSizePrice = _Bars_High[0] - _Bars_Low[0];
_Candle_TotalSize = NormalizeDouble(_Candle_TotalSizePrice/Point,Digits);
_Candle_BodySize = GetCandleBodySize(_Bars_Open[0],_Bars_Close[0]);
_Candle_WeakLow = GetCandleWeakLow();
_Candle_WeakHigh = GetCandleWeakHigh();


//----------Entry Rules (Market and Pending) -----------

if(!IsLossLimitBreached(IsLossLimitActivated,LossLimitPercent,OnJournaling,0)){
   if(!IsMaxPositionsReached(MaxPositionsAllowed,MagicNumber,OnJournaling)){
      _ExpirationDate=TimeCurrent()+ExpirationDateInHours*60*60;
      double _level = 0;
      if(IsBuySignal()){
         _BuyPrice=NormalizeDouble(_Bars_High[0]+Interval*Point,Digits); //define a price of order placing with intervals
         _BuyStopLoss = NormalizeDouble(_Bars_Low[0]-Interval*Point,Digits); //define a stop loss with interval
         _BuyTakeProfit=NormalizeDouble(_BuyPrice + ((_BuyPrice - _BuyStopLoss)*ProfitFactor),Digits);
         
         _level = NormalizeDouble((_BuyPrice - _BuyStopLoss) / (P*Point),Digits);
         _BuyStopLoss = _level * ProfitFactor;
         _BuyTakeProfit = _level * ProfitFactor;
          
         OrderNumber=OpenPositionPending(OP_BUYSTOP,_BuyPrice,_ExpirationDate,GetLot(IsSizingOn,Lots,Risk,YenPairAdjustFactor,_BuyStopLoss,P),_BuyStopLoss,_BuyTakeProfit,MagicNumber,Slippage,OnJournaling,P,IsECNbroker,MaxRetriesPerTick,RetryInterval);
      }
      else if(IsSellSignal()){
         _SellPrice=NormalizeDouble(_Bars_Low[0]-Interval*Point,Digits);
         _SellStopLoss = NormalizeDouble(_Bars_High[0]+Interval*Point,Digits);
         _SellTakeProfit=NormalizeDouble((_SellPrice -((_SellStopLoss - _SellPrice) * ProfitFactor)),Digits);

         _level = NormalizeDouble((_SellStopLoss - _SellPrice) /(P*Point),Digits);
         _SellStopLoss = _level * ProfitFactor;
         _SellTakeProfit = _level * ProfitFactor;
         
         OrderNumber=OpenPositionPending(OP_SELLSTOP,_SellPrice,_ExpirationDate,GetLot(IsSizingOn,Lots,Risk,YenPairAdjustFactor,_SellStopLoss,P),_SellStopLoss,_SellTakeProfit,MagicNumber,Slippage,OnJournaling,P,IsECNbroker,MaxRetriesPerTick,RetryInterval);
      }
   }
}
   
return(0);
}
//+------------------------------------------------------------------+
//| End of expert start function                                     |
//+------------------------------------------------------------------+

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//|                     FUNCTIONS LIBRARY                                   
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

/*

Content:
1) EntrySignal
2) ExitSignal
3) GetLot
4) CheckLot
5) CountPosOrders
6) IsMaxPositionsReached
7) OpenPositionMarket
8) OpenPositionPending
9) CloseOrderPosition
10) GetP
11) GetYenAdjustFactor
12) VolBasedStopLoss
13) VolBasedTakeProfit
14) Crossed1 / Crossed2
15) IsLossLimitBreached
16) IsVolLimitBreached
17) SetStopLossHidden
18) TriggerStopLossHidden
19) SetTakeProfitHidden
20) TriggerTakeProfitHidden
21) BreakevenStopAll
22) UpdateHiddenBEList
23) SetAndTriggerBEHidden
24) TrailingStopAll
25) UpdateHiddenTrailingList
26) SetAndTriggerHiddenTrailing
27) UpdateVolTrailingList
28) SetVolTrailingStop
29) ReviewVolTrailingStop
30) UpdateHiddenVolTrailingList
31) SetHiddenVolTrailing
32) TriggerAndReviewHiddenVolTrailing
33) HandleTradingEnvironment
34) GetErrorDescription

*/
bool IsBuySignal(){
  if(_Candle_WeakLow >= CandleWeakMinimal){
     //# BUY RULE 01 : weak high should represent more than CandleWeakMinimal% of total size of candle
      _Condition_isWeakAcceptable = _Candle_WeakLow >= CandleWeakMinimal;
      
      //# BUY RULE 02 : the body should be within the previous candle
      _Condition_isCloseWithinPreviousCandle = (_Bars_Close[0] >= _Bars_Low[1] && _Bars_Close[0] <= _Bars_High[1]) //closing inside previous bar
                                               && (_Bars_Open[0] >= _Bars_Low[1] && _Bars_Open[0] <= _Bars_High[1]); //Opening inside previous bar
      
      //# BUY RULE 03 : _Condition_isCandleLargerThanPrevious
      _Condition_isCandleLargerThanPrevious = _Candle_TotalSize >= GetCandleEntireSize(_Bars_High[1],_Bars_Low[1]);
      
      //# BUY RULE 04 : space to left
      double maximumAllowedPrice = _Bars_Low[0] + (SpaceToLeftMinimalDistance * _Candle_TotalSizePrice);
      
      _Condition_hasSpaceToTheLeft = true;
      for(int j=1; j<5; j++){
         if(_Bars_Open[j] < maximumAllowedPrice || _Bars_Close[j] < maximumAllowedPrice || _Bars_High[j] < maximumAllowedPrice || _Bars_Low[j] < maximumAllowedPrice){
            _Condition_hasSpaceToTheLeft = false;
            break;
         }
      }
      
       if(_Condition_hasSpaceToTheLeft){
         maximumAllowedPrice = _Bars_High[0] - (0.15 * _Candle_TotalSizePrice);
         for(int k=5; k<8; k++){
            if(_Bars_Open[k] < maximumAllowedPrice || _Bars_Close[k] < maximumAllowedPrice || _Bars_High[k] < maximumAllowedPrice || _Bars_Low[k] < maximumAllowedPrice){
               _Condition_hasSpaceToTheLeft = false;
               break;
            }
         }
      }
      
      _Condition_isCandleBigEnough = _Candle_TotalSize >= CandleMinimalSize;
      
       /*
      Print("_Candle_WeakLow:"+_Candle_WeakLow);
      Print("maximumAllowedPrice: "+maximumAllowedPrice);
      Print("_Condition_isWeakAcceptable:"+_Condition_isWeakAcceptable);
      Print("_Condition_isCloseWithinPreviousCandle:"+_Condition_isCloseWithinPreviousCandle);
      Print("_Condition_isCandleLargerThanPrevious:"+_Condition_isCandleLargerThanPrevious);
      Print("_Condition_hasSpaceToTheLeft:"+_Condition_hasSpaceToTheLeft);
      Print("_Condition_isCandleBigEnough:"+_Condition_isCandleBigEnough);
      
      */
      return _Condition_isWeakAcceptable &&
             _Condition_isCloseWithinPreviousCandle &&
             _Condition_isCandleLargerThanPrevious &&
             _Condition_hasSpaceToTheLeft &&
             _Condition_isCandleBigEnough;
    }
    else{
      return false;
    }
}

bool IsSellSignal(){
   if(_Candle_WeakHigh >= CandleWeakMinimal){
      //# SELL RULE 01 : weak high should represent more than 60% of total size of candle
      _Condition_isWeakAcceptable = _Candle_WeakHigh >= CandleWeakMinimal;
      
      //# SELL RULE 02 : the body should be within the previous candle
      _Condition_isCloseWithinPreviousCandle = (_Bars_Close[0] >= _Bars_Low[1] && _Bars_Close[0] <= _Bars_High[1]) //closing inside previous bar
                                               || (_Bars_Open[0] >= _Bars_Low[1] && _Bars_Open[0] <= _Bars_High[1]); //Opening inside previous bar
      
      //# SELL RULE 03 : _Condition_isCandleLargerThanPrevious
      _Condition_isCandleLargerThanPrevious = _Candle_TotalSize >= GetCandleEntireSize(_Bars_High[1],_Bars_Low[1]);
      
      //# SELL RULE 04 : space to left
      double maximumAllowedPrice = _Bars_High[0] - (SpaceToLeftMinimalDistance * _Candle_TotalSizePrice);
      
      _Condition_hasSpaceToTheLeft = true;
      for(int j=1; j<5; j++){
         if(_Bars_Open[j] > maximumAllowedPrice || _Bars_Close[j] > maximumAllowedPrice || _Bars_High[j] > maximumAllowedPrice){
            _Condition_hasSpaceToTheLeft = false;
            break;
         }
      }
      
      if(_Condition_hasSpaceToTheLeft){
         maximumAllowedPrice = _Bars_High[0] - (0.15 * _Candle_TotalSizePrice);
         for(int k=5; k<8; k++){
            if(_Bars_Open[k] > maximumAllowedPrice || _Bars_Close[k] > maximumAllowedPrice || _Bars_High[k] > maximumAllowedPrice){
               _Condition_hasSpaceToTheLeft = false;
               break;
            }
         }
      }
      
        /*
      //Print("_Candle_WeakLow:"+);
      Print("maximumAllowedPrice: "+maximumAllowedPrice);
      Print("_Condition_isWeakAcceptable:"+_Condition_isWeakAcceptable);
      Print("_Condition_isCloseWithinPreviousCandle:"+_Condition_isCloseWithinPreviousCandle);
      Print("_Condition_isCandleLargerThanPrevious:"+_Condition_isCandleLargerThanPrevious);
      Print("_Condition_hasSpaceToTheLeft:"+_Condition_hasSpaceToTheLeft);
      Print("_Condition_isCandleBigEnough:"+_Condition_isCandleBigEnough);
      
      */
      
      _Condition_isCandleBigEnough = _Candle_TotalSize >= CandleMinimalSize;
    
      return _Condition_isWeakAcceptable &&
             _Condition_isCloseWithinPreviousCandle &&
             _Condition_isCandleLargerThanPrevious &&
             _Condition_hasSpaceToTheLeft &&
             _Condition_isCandleBigEnough;
   }
   else{
      return false;
   }
}

double GetCandleWeakHigh(){
   if(IsBearishCandle(_Bars_Open[0],_Bars_Close[0])){
      return NormalizeDouble(((_Bars_High[0] - _Bars_Open[0]) * 100)/(_Candle_TotalSizePrice <= 0 ? 1: _Candle_TotalSizePrice),Digits);
   }
   else{
       return NormalizeDouble(((_Bars_High[0] - _Bars_Close[0]) * 100)/(_Candle_TotalSizePrice <= 0 ? 1: _Candle_TotalSizePrice),Digits);
   }
}

double GetCandleWeakLow(){
   if(IsBullishCandle(_Bars_Open[0],_Bars_Close[0])){
      return NormalizeDouble(((_Bars_Open[0] - _Bars_Low[0]) * 100)/(_Candle_TotalSizePrice <= 0 ? 1: _Candle_TotalSizePrice),Digits);
   }
   else{
       return NormalizeDouble(((_Bars_Close[0] - _Bars_Low[0]) * 100)/(_Candle_TotalSizePrice <= 0 ? 1: _Candle_TotalSizePrice),Digits);
   }
}

//+------------------------------------------------------------------+
//| Position Sizing Algo               
//+------------------------------------------------------------------+
// Type: Customisable 
// Modify this function to suit your trading robot

// This is our sizing algorithm

double GetLot(bool IsSizingOnTrigger,double FixedLots,double RiskPerTrade,int YenAdjustment,double STOP,int K) 
  {

   double output;

   if(IsSizingOnTrigger==true) 
     {
      output=RiskPerTrade*0.01*AccountBalance()/(MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_TICKVALUE)*STOP*K*Point); // Sizing Algo based on account size
      output=output*YenAdjustment; // Adjust for Yen Pairs
        } else {
      output=FixedLots;
     }
   output=NormalizeDouble(output,2); // Round to 2 decimal place
   return(output);
  }
//+------------------------------------------------------------------+
//| End of Position Sizing Algo               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CHECK LOT
//+------------------------------------------------------------------+
double CheckLot(double Lot,bool Journaling)
  {
// This function checks if our Lots to be trade satisfies any broker limitations

   double LotToOpen=0;
   LotToOpen=NormalizeDouble(Lot,2);
   LotToOpen=MathFloor(LotToOpen/MarketInfo(Symbol(),MODE_LOTSTEP))*MarketInfo(Symbol(),MODE_LOTSTEP);

   if(LotToOpen<MarketInfo(Symbol(),MODE_MINLOT))LotToOpen=MarketInfo(Symbol(),MODE_MINLOT);
   if(LotToOpen>MarketInfo(Symbol(),MODE_MAXLOT))LotToOpen=MarketInfo(Symbol(),MODE_MAXLOT);
   LotToOpen=NormalizeDouble(LotToOpen,2);

   if(Journaling && LotToOpen!=Lot)Print("EA Journaling: Trading Lot has been changed by CheckLot function. Requested lot: "+Lot+". Lot to open: "+LotToOpen);

   return(LotToOpen);
  }
//+------------------------------------------------------------------+
//| End of CHECK LOT
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| COUNT POSITIONS 
//+------------------------------------------------------------------+
int CountPosOrders(int Magic,int TYPE)
  {
// This function counts number of positions/orders of OrderType TYPE

   int Orders=0;
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
         Orders++;
     }
   return(Orders);

  }
//+------------------------------------------------------------------+
//| End of COUNT POSITIONS
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| MAX ORDERS                                              
//+------------------------------------------------------------------+
bool IsMaxPositionsReached(int MaxPositions,int Magic,bool Journaling)
  {
// This function checks the number of positions we are holding against the maximum allowed 

   int result=False;
   if(CountPosOrders(Magic,OP_BUY)+CountPosOrders(Magic,OP_SELL) + CountPosOrders(Magic,OP_SELLLIMIT) + CountPosOrders(Magic,OP_BUYLIMIT) + CountPosOrders(Magic,OP_BUYSTOP) + CountPosOrders(Magic,OP_SELLSTOP)>MaxPositions) 
     {
      result=True;
      if(Journaling)Print("Max Orders Exceeded");
        } else if(CountPosOrders(Magic,OP_BUY)+CountPosOrders(Magic,OP_SELL) + CountPosOrders(Magic,OP_SELLLIMIT) + CountPosOrders(Magic,OP_BUYLIMIT) + CountPosOrders(Magic,OP_BUYSTOP) + CountPosOrders(Magic,OP_SELLSTOP)==MaxPositions) {
      result=True;
     }

   return(result);

/* Definitions: Position vs Orders
   
   Position describes an opened trade
   Order is a pending trade
   
   How to use in a sentence: Jim has 5 buy limit orders pending 10 minutes ago. The market just crashed. The orders were executed and he has 5 losing positions now lol.

*/
  }
//+------------------------------------------------------------------+
//| End of MAX ORDERS                                                
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| OPEN FROM MARKET
//+------------------------------------------------------------------+
int OpenPositionMarket(int TYPE,double LOT,double SL,double TP,int Magic,int Slip,bool Journaling,int K,bool ECN,int Max_Retries_Per_Tick,int Retry_Interval)
  {
// This function submits new orders

   int tries=0;
   string symbol=Symbol();
   int cmd=TYPE;
   double volume=CheckLot(LOT,Journaling);
   if(MarketInfo(symbol,MODE_MARGINREQUIRED)*volume>AccountFreeMargin())
     {
      Print("Can not open a trade. Not enough free margin to open "+volume+" on "+symbol);
      return(-1);
     }
   int slippage=Slip*K; // Slippage is in points. 1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
   string comment=" "+TYPE+"(#"+Magic+")";
   int magic=Magic;
   datetime expiration=0;
   color arrow_color=0;if(TYPE==OP_BUY)arrow_color=Blue;if(TYPE==OP_SELL)arrow_color=Green;
   double stoploss=0;
   double takeprofit=0;
   double initTP = TP;
   double initSL = SL;
   int Ticket=-1;
   double price=0;
   if(!ECN)
     {
      while(tries<Max_Retries_Per_Tick) // Edits stops and take profits before the market order is placed
        {
         RefreshRates();
         if(TYPE==OP_BUY)price=Ask;if(TYPE==OP_SELL)price=Bid;

         // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
         if(TYPE==OP_BUY && SL!=0)
           {
            stoploss=NormalizeDouble(Ask-SL*K*Point,Digits);
            if(Bid-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
              {
               stoploss=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+MarketInfo(Symbol(),MODE_STOPLEVEL)/K+" pips");
              }
           }
         if(TYPE==OP_SELL && SL!=0)
           {
            stoploss=NormalizeDouble(Bid+SL*K*Point,Digits);
            if(stoploss-Ask<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
              {
               stoploss=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+MarketInfo(Symbol(),MODE_STOPLEVEL)/K+" pips");
              }
           }
         if(TYPE==OP_BUY && TP!=0)
           {
            takeprofit=NormalizeDouble(Ask+TP*K*Point,Digits);
            if(takeprofit-Bid<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
              {
               takeprofit=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+MarketInfo(Symbol(),MODE_STOPLEVEL)/K+" pips");
              }
           }
         if(TYPE==OP_SELL && TP!=0)
           {
            takeprofit=NormalizeDouble(Bid-TP*K*Point,Digits);
            if(Ask-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
              {
               takeprofit=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+MarketInfo(Symbol(),MODE_STOPLEVEL)/K+" pips");
              }
           }
         if(Journaling)Print("EA Journaling: Trying to place a market order...");
         HandleTradingEnvironment(Journaling,Retry_Interval);
         Ticket=OrderSend(symbol,cmd,volume,price,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);
         if(Ticket>0)break;
         tries++;
        }
     }
   if(ECN) // Edits stops and take profits after the market order is placed
     {
      HandleTradingEnvironment(Journaling,Retry_Interval);
      if(TYPE==OP_BUY)price=Ask;if(TYPE==OP_SELL)price=Bid;
      if(Journaling)Print("EA Journaling: Trying to place a market order...");
      Ticket=OrderSend(symbol,cmd,volume,price,slippage,0,0,comment,magic,expiration,arrow_color);
      if(Ticket>0)
         if(Ticket>0 && OrderSelect(Ticket,SELECT_BY_TICKET)==true && (SL!=0 || TP!=0))
           {
            // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
            if(TYPE==OP_BUY && SL!=0)
              {
               stoploss=NormalizeDouble(OrderOpenPrice()-SL*K*Point,Digits);
               if(Bid-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
                 {
                  stoploss=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
                  if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+(OrderOpenPrice()-stoploss)/(K*Point)+" pips");
                 }
              }
            if(TYPE==OP_SELL && SL!=0)
              {
               stoploss=NormalizeDouble(OrderOpenPrice()+SL*K*Point,Digits);
               if(stoploss-Ask<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
                 {
                  stoploss=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
                  if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+(stoploss-OrderOpenPrice())/(K*Point)+" pips");
                 }
              }
            if(TYPE==OP_BUY && TP!=0)
              {
               takeprofit=NormalizeDouble(OrderOpenPrice()+TP*K*Point,Digits);
               if(takeprofit-Bid<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
                 {
                  takeprofit=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
                  if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+(takeprofit-OrderOpenPrice())/(K*Point)+" pips");
                 }
              }
            if(TYPE==OP_SELL && TP!=0)
              {
               takeprofit=NormalizeDouble(OrderOpenPrice()-TP*K*Point,Digits);
               if(Ask-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
                 {
                  takeprofit=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
                  if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+(OrderOpenPrice()-takeprofit)/(K*Point)+" pips");
                 }
              }
            bool ModifyOpen=false;
            while(!ModifyOpen)
              {
               HandleTradingEnvironment(Journaling,Retry_Interval);
               ModifyOpen=OrderModify(Ticket,OrderOpenPrice(),stoploss,takeprofit,expiration,arrow_color);
               if(Journaling && !ModifyOpen)Print("EA Journaling: Take Profit and Stop Loss not set. Error Description: "+GetErrorDescription(GetLastError()));
              }
           }
     }
   if(Journaling && Ticket<0)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
   if(Journaling && Ticket>0)
     {
      Print("EA Journaling: Order successfully placed. Ticket: "+Ticket);
     }
   return(Ticket);
  }
//+------------------------------------------------------------------+
//| End of OPEN FROM MARKET   
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| OPEN PENDING ORDERS
//+------------------------------------------------------------------+
int OpenPositionPending(int TYPE,double OpenPrice,datetime expiration,double LOT,double SL,double TP,int Magic,int Slip,bool Journaling,int K,bool ECN,int Max_Retries_Per_Tick,int Retry_Interval)
  {
// This function submits new pending orders
   OpenPrice= NormalizeDouble(OpenPrice,Digits);
   int tries=0;
   string symbol=Symbol();
   int cmd=TYPE;
   double volume=CheckLot(LOT,Journaling);
   if(MarketInfo(symbol,MODE_MARGINREQUIRED)*volume>AccountFreeMargin())
     {
      Print("Can not open a trade. Not enough free margin to open "+volume+" on "+symbol);
      return(-1);
     }
   int slippage=Slip*K; // Slippage is in points. 1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
   string comment=" "+TYPE+"(#"+Magic+")";
   int magic=Magic;
   color arrow_color=0;if(TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP)arrow_color=Blue;if(TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP)arrow_color=Green;
   double stoploss=0;
   double takeprofit=0;
   double initTP = TP;
   double initSL = SL;
   int Ticket=-1;
   double price=0;

   while(tries<Max_Retries_Per_Tick) // Edits stops and take profits before the market order is placed
     {
      RefreshRates();

      // We are able to send in TP and SL when we open our orders even if we are using ECN brokers

      // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
      if((TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP) && SL!=0)
        {
         stoploss=NormalizeDouble(OpenPrice-SL*K*Point,Digits);
         if(OpenPrice-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
           {
            stoploss=NormalizeDouble(OpenPrice-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
            if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+(OpenPrice-stoploss)/(K*Point)+" pips");
           }
        }
      if((TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP) && TP!=0)
        {
         takeprofit=NormalizeDouble(OpenPrice+TP*K*Point,Digits);
         if(takeprofit-OpenPrice<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
           {
            takeprofit=NormalizeDouble(OpenPrice+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
            if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+(takeprofit-OpenPrice)/(K*Point)+" pips");
           }
        }
      if((TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP) && SL!=0)
        {
         stoploss=NormalizeDouble(OpenPrice+SL*K*Point,Digits);
         if(stoploss-OpenPrice<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
           {
            stoploss=NormalizeDouble(OpenPrice+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
            if(Journaling)Print("EA Journaling: Stop Loss changed from "+initSL+" to "+(OpenPrice-stoploss)/(K*Point)+" pips");
           }
        }
      if((TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP) && TP!=0)
        {
         takeprofit=NormalizeDouble(OpenPrice-TP*K*Point,Digits);
         if(OpenPrice-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) 
           {
            takeprofit=NormalizeDouble(OpenPrice-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
            if(Journaling)Print("EA Journaling: Take Profit changed from "+initTP+" to "+(OrderOpenPrice()-stoploss)/(K*Point)+" pips");
           }
        }
      if(Journaling)Print("EA Journaling: Trying to place a pending order...");
      HandleTradingEnvironment(Journaling,Retry_Interval);

      //Note: We did not modify Open Price if it breaches the Stop Level Limitations as Open Prices are sensitive and important. It is unsafe to change it automatically.
      Ticket=OrderSend(symbol,cmd,volume,OpenPrice,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);
      if(Ticket>0)break;
      tries++;
     }

   if(Journaling && Ticket<0)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
   if(Journaling && Ticket>0)
     {
      Print("EA Journaling: Order successfully placed. Ticket: "+Ticket);
     }
   return(Ticket);
  }
//+------------------------------------------------------------------+
//| End of OPEN PENDING ORDERS 
//+------------------------------------------------------------------+ 
//+------------------------------------------------------------------+
//| CLOSE/DELETE ORDERS AND POSITIONS
//+------------------------------------------------------------------+
bool CloseOrderPosition(int TYPE,bool Journaling,int Magic,int Slip,int K,int Retry_Interval)
  {
// This function closes all positions of type TYPE or Deletes pending orders of type TYPE
   int ordersPos=OrdersTotal();

   for(int i=ordersPos-1; i>=0; i--)
     {
      // Note: Once pending orders become positions, OP_BUYLIMIT AND OP_BUYSTOP becomes OP_BUY, OP_SELLLIMIT and OP_SELLSTOP becomes OP_SELL
      if(TYPE==OP_BUY || TYPE==OP_SELL)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
           {
            bool Closing=false;
            double Price=0;
            color arrow_color=0;if(TYPE==OP_BUY)arrow_color=Blue;if(TYPE==OP_SELL)arrow_color=Green;
            if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,RetryInterval);
            if(TYPE==OP_BUY)Price=Bid; if(TYPE==OP_SELL)Price=Ask;
            Closing=OrderClose(OrderTicket(),OrderLots(),Price,Slip*K,arrow_color);
            if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Closing)Print("EA Journaling: Position successfully closed.");
           }
        }
      else
        {
         bool Delete=false;
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
           {
            if(Journaling)Print("EA Journaling: Trying to delete order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,RetryInterval);
            Delete=OrderDelete(OrderTicket(),CLR_NONE);
            if(Journaling && !Delete)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Delete)Print("EA Journaling: Order successfully deleted.");
           }
        }
     }
   if(CountPosOrders(Magic, TYPE)==0)return(true); else return(false);
  }
//+------------------------------------------------------------------+
//| End of CLOSE/DELETE ORDERS AND POSITIONS 
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check for 4/5 Digits Broker              
//+------------------------------------------------------------------+ 
int GetP() 
  {
// This function returns P, which is used for converting pips to decimals/points

   int output;
   if(Digits==5 || Digits==3) output=10;else output=1;
   return(output);

/* Some definitions: Pips vs Point

1 pip = 0.0001 on a 4 digit broker and 0.00010 on a 5 digit broker
1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
  
*/

  }
//+------------------------------------------------------------------+
//| End of Check for 4/5 Digits Broker               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Yen Adjustment Factor             
//+------------------------------------------------------------------+ 
int GetYenAdjustFactor() 
  {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function returns a constant factor, which is used for position sizing for Yen pairs

   int output= 1;
   if(Digits == 3|| Digits == 2) output = 100;
   return(output);
  }
//+------------------------------------------------------------------+
//| End of Yen Adjustment Factor             
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Volatility-Based Stop Loss                                             
//+------------------------------------------------------------------+
double VolBasedStopLoss(bool isVolatilitySwitchOn,double fixedStop,double VolATR,double volMultiplier,int K)
  { // K represents our P multiplier to adjust for broker digits
// This function calculates stop loss amount based on volatility

   double StopL;
   if(!isVolatilitySwitchOn)
     {
      StopL=fixedStop; // If Volatility Stop Loss not activated. Stop Loss = Fixed Pips Stop Loss
        } else {
      StopL=volMultiplier*VolATR/(K*Point); // Stop Loss in Pips
     }
   return(StopL);
  }
//+------------------------------------------------------------------+
//| End of Volatility-Based Stop Loss                  
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Volatility-Based Take Profit                                     
//+------------------------------------------------------------------+

double VolBasedTakeProfit(bool isVolatilitySwitchOn,double fixedTP,double VolATR,double volMultiplier,int K)
  { // K represents our P multiplier to adjust for broker digits
// This function calculates take profit amount based on volatility

   double TakeP;
   if(!isVolatilitySwitchOn)
     {
      TakeP=fixedTP; // If Volatility Take Profit not activated. Take Profit = Fixed Pips Take Profit
        } else {
      TakeP=volMultiplier*VolATR/(K*Point); // Take Profit in Pips
     }
   return(TakeP);
  }
//+------------------------------------------------------------------+
//| End of Volatility-Based Take Profit                 
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Cross1                                                             
//+------------------------------------------------------------------+
// This function determines if a cross happened between 2 lines/data set

/* 

If Output is 0: No cross happened
If Output is 1: Line 1 crossed Line 2 from Bottom
If Output is 2: Line 1 crossed Line 2 from top 

*/

int Crossed1(double line1,double line2)
  {

   static int CurrentDirection1=0;
   static int LastDirection1=0;
   static bool FirstTime1=true;

//----
   if(line1>line2)
      CurrentDirection1=1;  // line1 above line2
   if(line1<line2)
      CurrentDirection1=2;  // line1 below line2
//----
   if(FirstTime1==true) // Need to check if this is the first time the function is run
     {
      FirstTime1=false; // Change variable to false
      LastDirection1=CurrentDirection1; // Set new direction
      return (0);
     }

   if(CurrentDirection1!=LastDirection1 && FirstTime1==false) // If not the first time and there is a direction change
     {
      LastDirection1=CurrentDirection1; // Set new direction
      return(CurrentDirection1); // 1 for up, 2 for down
     }
   else
     {
      return(0);  // No direction change
     }
  }
//+------------------------------------------------------------------+
// End of Cross                                                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Cross2                                                             
//+------------------------------------------------------------------+

// This function determines if a cross happened between 2 lines/data set

/* 

If Output is 0: No cross happened
If Output is 1: Line 1 crossed Line 2 from Bottom
If Output is 2: Line 1 crossed Line 2 from top 

*/

int Crossed2(double line1,double line2)
  {

   static int CurrentDirection1=0;
   static int LastDirection1=0;
   static bool FirstTime1=true;

//----
   if(line1>line2)
      CurrentDirection1=1;  // line1 above line2
   if(line1<line2)
      CurrentDirection1=2;  // line1 below line2
//----
   if(FirstTime1==true) // Need to check if this is the first time the function is run
     {
      FirstTime1=false; // Change variable to false
      LastDirection1=CurrentDirection1; // Set new direction
      return (0);
     }

   if(CurrentDirection1!=LastDirection1 && FirstTime1==false) // If not the first time and there is a direction change
     {
      LastDirection1=CurrentDirection1; // Set new direction
      return(CurrentDirection1); // 1 for up, 2 for down
     }
   else
     {
      return(0);  // No direction change
     }
  }
//+------------------------------------------------------------------+
// End of Cross                                                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Cross3                                                          
//+------------------------------------------------------------------+

// This function determines if a cross happened between 2 lines/data set

/* 

If Output is 0: No cross happened
If Output is 1: Line 1 crossed Line 2 from Bottom
If Output is 2: Line 1 crossed Line 2 from top 

*/

int Crossed3(double line1,double line2)
  {

   static int CurrentDirection1=0;
   static int LastDirection1=0;
   static bool FirstTime1=true;

//----
   if(line1>line2)
      CurrentDirection1=1;  // line1 above line2
   if(line1<line2)
      CurrentDirection1=2;  // line1 below line2
//----
   if(FirstTime1==true) // Need to check if this is the first time the function is run
     {
      FirstTime1=false; // Change variable to false
      LastDirection1=CurrentDirection1; // Set new direction
      return (0);
     }

   if(CurrentDirection1!=LastDirection1 && FirstTime1==false) // If not the first time and there is a direction change
     {
      LastDirection1=CurrentDirection1; // Set new direction
      return(CurrentDirection1); // 1 for up, 2 for down
     }
   else
     {
      return(0);  // No direction change
     }
  }
//+------------------------------------------------------------------+
// End of Cross                                                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Is Loss Limit Breached                                       
//+------------------------------------------------------------------+
bool IsLossLimitBreached(bool LossLimitActivated,double LossLimitPercentage,bool Journaling,int EntrySignalTrigger)
  {
// This function determines if our maximum loss threshold is breached

   static bool firstTick=False;
   static double initialCapital=0;
   double profitAndLoss=0;
   double profitAndLossPrint=0;
   bool output=False;

   if(LossLimitActivated==False) return(output);

   if(firstTick==False)
     {
      initialCapital=AccountEquity();
      firstTick=True;
     }

   profitAndLoss=(AccountEquity()/initialCapital)-1;

   if(profitAndLoss<-LossLimitPercentage/100)
     {
      output=True;
      profitAndLossPrint=NormalizeDouble(profitAndLoss,4)*100;
      if(Journaling)if(EntrySignalTrigger!=0) Print("Entry trade triggered but not executed. Loss threshold breached. Current Loss: "+profitAndLossPrint+"%");
     }

   return(output);
  }
//+------------------------------------------------------------------+
//| End of Is Loss Limit Breached                                     
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Is Volatility Limit Breached                                       
//+------------------------------------------------------------------+
bool IsVolLimitBreached(bool VolLimitActivated,double VolMulti,int ATR_Timeframe, int ATR_per)
  {
// This function determines if our maximum volatility threshold is breached

// 2 steps to this function: 
// 1) It checks the price movement between current time and the closing price of the last completed 1min bar (shift 1 of 1min timeframe).
// 2) Return True if this price movement > VolLimitMulti * VolATR

   bool output = False;
   if(VolLimitActivated==False) return(output);
   
   double priceMovement = MathAbs(Bid-iClose(NULL,PERIOD_M1,1)); // Not much difference if we use bid or ask prices here. We can also use iOpen at shift 0 here, it will be similar to using iClose at shift 1.
   double VolATR = iATR(NULL, ATR_Timeframe, ATR_per, 1);
   
   if(priceMovement > VolMulti*VolATR) output = True;

   return(output);
  }
//+------------------------------------------------------------------+
//| End of Is Volatility Limit Breached                                         
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Breakeven Stop
//+------------------------------------------------------------------+
void BreakevenStopAll(bool Journaling,int Retry_Interval,double Breakeven_Buffer,int Magic,int K)
  {
// This function sets breakeven stops for all positions

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      bool Modify=false;
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic)
        {
         RefreshRates();
         if(OrderType()==OP_BUY && (Bid-OrderOpenPrice())>(Breakeven_Buffer*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, breakeven stop updated.");
           }
         if(OrderType()==OP_SELL && (OrderOpenPrice()-Ask)>(Breakeven_Buffer*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, breakeven stop updated.");
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| End of Breakeven Stop
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trailing Stop
//+------------------------------------------------------------------+

void TrailingStopAll(bool Journaling,double TrailingStopDist,double TrailingStopBuff,int Retry_Interval,int Magic,int K)
  {
// This function sets trailing stops for all positions

   for(int i=OrdersTotal()-1; i>=0; i--) // Looping through all orders
     {
      bool Modify=false;
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic)
        {
         RefreshRates();
         if(OrderType()==OP_BUY && (Bid-OrderStopLoss()>(TrailingStopDist+TrailingStopBuff)*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Bid-TrailingStopDist*K*Point,OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, trailing stop changed.");
           }
         if(OrderType()==OP_SELL && ((OrderStopLoss()-Ask>((TrailingStopDist+TrailingStopBuff)*K*Point)) || (OrderStopLoss()==0)))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling,Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Ask+TrailingStopDist*K*Point,OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, trailing stop changed.");
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| End Trailing Stop
//+------------------------------------------------------------------+

bool IsBearishCandle(double open, double close)
{
   return open > close;
}

bool IsBullishCandle(double open, double close)
{
   return close > open;
}

double GetCandleBodySize(double open, double close){
   double   _point   = MarketInfo(Symbol(), MODE_POINT);
   double size = NormalizeDouble((open - close) / _point,Digits);
   
   if(size<0){
      size = size * -1;
   }
   return size;
}

double GetCandleEntireSize(double high, double low){
   double   _point   = MarketInfo(Symbol(), MODE_POINT);
   double size = NormalizeDouble((high - low) / _point,Digits);
   
   if(size<0){
      size = size * -1;
   }
   return size;
}


//+------------------------------------------------------------------+
//| HANDLE TRADING ENVIRONMENT                                       
//+------------------------------------------------------------------+
void HandleTradingEnvironment(bool Journaling,int Retry_Interval)
  {
// This function checks for errors

   if(IsTradeAllowed()==true)return;
   if(!IsConnected())
     {
      if(Journaling)Print("EA Journaling: Terminal is not connected to server...");
      return;
     }
   if(!IsTradeAllowed() && Journaling)Print("EA Journaling: Trade is not alowed for some reason...");
   if(IsConnected() && !IsTradeAllowed())
     {
      while(IsTradeContextBusy()==true)
        {
         if(Journaling)Print("EA Journaling: Trading context is busy... Will wait a bit...");
         Sleep(Retry_Interval);
        }
     }
   RefreshRates();
  }
//+------------------------------------------------------------------+
//| End of HANDLE TRADING ENVIRONMENT                                
//+------------------------------------------------------------------+  
//+------------------------------------------------------------------+
//| ERROR DESCRIPTION                                                
//+------------------------------------------------------------------+
string GetErrorDescription(int error)
  {
// This function returns the exact error

   string ErrorDescription="";
//---
   switch(error)
     {
      case 0:     ErrorDescription = "No Error. Everything should be good.";                                    break;
      case 1:     ErrorDescription = "No error returned, but the result is unknown";                            break;
      case 2:     ErrorDescription = "Common error";                                                            break;
      case 3:     ErrorDescription = "Invalid trade parameters";                                                break;
      case 4:     ErrorDescription = "Trade server is busy";                                                    break;
      case 5:     ErrorDescription = "Old version of the client terminal";                                      break;
      case 6:     ErrorDescription = "No connection with trade server";                                         break;
      case 7:     ErrorDescription = "Not enough rights";                                                       break;
      case 8:     ErrorDescription = "Too frequent requests";                                                   break;
      case 9:     ErrorDescription = "Malfunctional trade operation";                                           break;
      case 64:    ErrorDescription = "Account disabled";                                                        break;
      case 65:    ErrorDescription = "Invalid account";                                                         break;
      case 128:   ErrorDescription = "Trade timeout";                                                           break;
      case 129:   ErrorDescription = "Invalid price";                                                           break;
      case 130:   ErrorDescription = "Invalid stops";                                                           break;
      case 131:   ErrorDescription = "Invalid trade volume";                                                    break;
      case 132:   ErrorDescription = "Market is closed";                                                        break;
      case 133:   ErrorDescription = "Trade is disabled";                                                       break;
      case 134:   ErrorDescription = "Not enough money";                                                        break;
      case 135:   ErrorDescription = "Price changed";                                                           break;
      case 136:   ErrorDescription = "Off quotes";                                                              break;
      case 137:   ErrorDescription = "Broker is busy";                                                          break;
      case 138:   ErrorDescription = "Requote";                                                                 break;
      case 139:   ErrorDescription = "Order is locked";                                                         break;
      case 140:   ErrorDescription = "Long positions only allowed";                                             break;
      case 141:   ErrorDescription = "Too many requests";                                                       break;
      case 145:   ErrorDescription = "Modification denied because order too close to market";                   break;
      case 146:   ErrorDescription = "Trade context is busy";                                                   break;
      case 147:   ErrorDescription = "Expirations are denied by broker";                                        break;
      case 148:   ErrorDescription = "Too many open and pending orders (more than allowed)";                    break;
      case 4000:  ErrorDescription = "No error";                                                                break;
      case 4001:  ErrorDescription = "Wrong function pointer";                                                  break;
      case 4002:  ErrorDescription = "Array index is out of range";                                             break;
      case 4003:  ErrorDescription = "No memory for function call stack";                                       break;
      case 4004:  ErrorDescription = "Recursive stack overflow";                                                break;
      case 4005:  ErrorDescription = "Not enough stack for parameter";                                          break;
      case 4006:  ErrorDescription = "No memory for parameter string";                                          break;
      case 4007:  ErrorDescription = "No memory for temp string";                                               break;
      case 4008:  ErrorDescription = "Not initialized string";                                                  break;
      case 4009:  ErrorDescription = "Not initialized string in array";                                         break;
      case 4010:  ErrorDescription = "No memory for array string";                                              break;
      case 4011:  ErrorDescription = "Too long string";                                                         break;
      case 4012:  ErrorDescription = "Remainder from zero divide";                                              break;
      case 4013:  ErrorDescription = "Zero divide";                                                             break;
      case 4014:  ErrorDescription = "Unknown command";                                                         break;
      case 4015:  ErrorDescription = "Wrong jump (never generated error)";                                      break;
      case 4016:  ErrorDescription = "Not initialized array";                                                   break;
      case 4017:  ErrorDescription = "DLL calls are not allowed";                                               break;
      case 4018:  ErrorDescription = "Cannot load library";                                                     break;
      case 4019:  ErrorDescription = "Cannot call function";                                                    break;
      case 4020:  ErrorDescription = "Expert function calls are not allowed";                                   break;
      case 4021:  ErrorDescription = "Not enough memory for temp string returned from function";                break;
      case 4022:  ErrorDescription = "System is busy (never generated error)";                                  break;
      case 4050:  ErrorDescription = "Invalid function parameters count";                                       break;
      case 4051:  ErrorDescription = "Invalid function parameter value";                                        break;
      case 4052:  ErrorDescription = "String function internal error";                                          break;
      case 4053:  ErrorDescription = "Some array error";                                                        break;
      case 4054:  ErrorDescription = "Incorrect series array using";                                            break;
      case 4055:  ErrorDescription = "Custom indicator error";                                                  break;
      case 4056:  ErrorDescription = "Arrays are incompatible";                                                 break;
      case 4057:  ErrorDescription = "Global variables processing error";                                       break;
      case 4058:  ErrorDescription = "Global variable not found";                                               break;
      case 4059:  ErrorDescription = "Function is not allowed in testing mode";                                 break;
      case 4060:  ErrorDescription = "Function is not confirmed";                                               break;
      case 4061:  ErrorDescription = "Send mail error";                                                         break;
      case 4062:  ErrorDescription = "String parameter expected";                                               break;
      case 4063:  ErrorDescription = "Integer parameter expected";                                              break;
      case 4064:  ErrorDescription = "Double parameter expected";                                               break;
      case 4065:  ErrorDescription = "Array as parameter expected";                                             break;
      case 4066:  ErrorDescription = "Requested history data in updating state";                                break;
      case 4067:  ErrorDescription = "Some error in trading function";                                          break;
      case 4099:  ErrorDescription = "End of file";                                                             break;
      case 4100:  ErrorDescription = "Some file error";                                                         break;
      case 4101:  ErrorDescription = "Wrong file name";                                                         break;
      case 4102:  ErrorDescription = "Too many opened files";                                                   break;
      case 4103:  ErrorDescription = "Cannot open file";                                                        break;
      case 4104:  ErrorDescription = "Incompatible access to a file";                                           break;
      case 4105:  ErrorDescription = "No order selected";                                                       break;
      case 4106:  ErrorDescription = "Unknown symbol";                                                          break;
      case 4107:  ErrorDescription = "Invalid price";                                                           break;
      case 4108:  ErrorDescription = "Invalid ticket";                                                          break;
      case 4109:  ErrorDescription = "EA is not allowed to trade is not allowed. ";                             break;
      case 4110:  ErrorDescription = "Longs are not allowed. Check the expert properties";                      break;
      case 4111:  ErrorDescription = "Shorts are not allowed. Check the expert properties";                     break;
      case 4200:  ErrorDescription = "Object exists already";                                                   break;
      case 4201:  ErrorDescription = "Unknown object property";                                                 break;
      case 4202:  ErrorDescription = "Object does not exist";                                                   break;
      case 4203:  ErrorDescription = "Unknown object type";                                                     break;
      case 4204:  ErrorDescription = "No object name";                                                          break;
      case 4205:  ErrorDescription = "Object coordinates error";                                                break;
      case 4206:  ErrorDescription = "No specified subwindow";                                                  break;
      case 4207:  ErrorDescription = "Some error in object function";                                           break;
      default:    ErrorDescription = "No error or error is unknown";
     }
   return(ErrorDescription);
  }
//+------------------------------------------------------------------+
//| End of ERROR DESCRIPTION                                         
//+------------------------------------------------------------------+