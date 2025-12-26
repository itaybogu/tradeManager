//+------------------------------------------------------------------+
//|                                                 tradeManager.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Created by Itay"
#property link      "https://github.com/itaybogu/tradeManager"

//+------------------------------------------------------------------+
//| TradeManager.mqh                                                 |
//+------------------------------------------------------------------+


class tradeManager
{
private:
    string symbol;
    ulong  magic;
    bool flipPositions;

public:
    // Constructor: set symbol and magic number at creation
    tradeManager(string symbol, ulong magic)
    {
        this.symbol = symbol;
        this.magic  = magic;
        this.flipPositions = false;
    }
    
public:
   // set flip positions
   void setFlipPositions(bool flipPositions)
   {
      this.flipPositions = flipPositions;
   }

private:
    // Calculate money at risk per 1 lot
    double MoneyRiskPerLot(double entryPrice, double stopPrice, bool isBuy)
    {
       double profit;
       ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
       if(!OrderCalcProfit(type, this.symbol, 1.0, entryPrice, stopPrice, profit))
       {
           Print("OrderCalcProfit failed for ", this.symbol, " error=", GetLastError());
           return 0;
       }
   
       return MathAbs(profit); // $ risk per 1 lot
    }
    
    
private:
   bool sendTradeRequest(double stopLossPrice,double takeProfit,double volume, bool isLong)                      
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   
      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);
   
      // --- base request
      request.action       = TRADE_ACTION_DEAL;
      request.symbol       = symbol;
      request.volume       = volume;
      request.deviation    = 50;
      request.magic        = magic;
      request.type_filling = ORDER_FILLING_IOC;
   
      // --- direction (handle flip once)
      bool finalLong = flipPositions ? !isLong : isLong;
   
      request.type  = finalLong ? ORDER_TYPE_BUY  : ORDER_TYPE_SELL;
      request.price = finalLong ? ask              : bid;
      request.sl    = flipPositions ? takeProfit    : stopLossPrice;
      request.tp    = flipPositions ? stopLossPrice  : takeProfit;
   
      request.comment = finalLong ? "Long" : "Short";
      if(flipPositions)
         request.comment += " (flipped)";

   
      // --- send
      if(!OrderSend(request, result))
      {
         Print("OrderSend failed, retcode: ", result.retcode);
         return false;
      }
   
      if(result.retcode != TRADE_RETCODE_DONE)
      {
         Print("Trade rejected, retcode: ", result.retcode);
         return false;
      }
   
      PrintFormat(
         "Position opened %.2f lots at %.5f | SL=%.5f | TP=%.5f",
         volume,
         result.price,
         request.sl,
         request.tp
      );
   
      return true;
   }


public:
       // Open long
    bool OpenLong(double stopLossPrice, double riskAmount, double rr = 2.0)
    {
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
        if(stopLossPrice >= ask)
        {
            Print("Invalid stop loss: must be below current price for a long.");
            return false;
        }
      
        //--- calculate $ risk per lot using MT5
        double riskPerLot = MoneyRiskPerLot(ask, stopLossPrice, true);
        if(riskPerLot <= 0)
        {
            Print("Failed to calculate risk per lot.");
            return false;
        }
      
        //--- calculate volume (lots)
        double volume = riskAmount / riskPerLot;
      
        //--- normalize volume
        double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
        volume = MathFloor(volume / lotStep) * lotStep;
        volume = MathMax(minLot, MathMin(volume, maxLot));
        
      //--- calculate take profit
        double stopDistance = ask - stopLossPrice;
        double takeProfit   = ask + stopDistance * rr;
      
        double sl = NormalizeDouble(stopLossPrice, _Digits);
        double tp = NormalizeDouble(takeProfit, _Digits);
          
        return sendTradeRequest(sl, tp, volume, true);
        
      }
 
 public:      // Open short
    bool OpenShort(double stopLossPrice, double riskAmount, double rr = 2.0)
    {
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      
        if(stopLossPrice <= bid)
        {
            Print("Invalid stop loss: must be above current price for a short.");
            return false;
        }
      
        //--- calculate $ risk per lot using MT5
        double riskPerLot = MoneyRiskPerLot(bid, stopLossPrice, false);
        if(riskPerLot <= 0)
        {
            Print("Failed to calculate risk per lot.");
            return false;
        }
      
        //--- calculate volume (lots)
        double volume = riskAmount / riskPerLot;
      
        //--- normalize volume
        double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
        volume = MathFloor(volume / lotStep) * lotStep;
        volume = MathMax(minLot, MathMin(volume, maxLot));
      
        //--- calculate take profit
        double stopDistance = stopLossPrice - bid;
        double takeProfit   = bid - stopDistance * rr;
      
        double sl = NormalizeDouble(stopLossPrice, _Digits);
        double tp = NormalizeDouble(takeProfit, _Digits);
          
        return sendTradeRequest(sl, tp, volume, false);
      
        
    }
    
    
public:      
   // Open short with take profit
    bool OpenShortWithTakeProfit(double stopLossPrice, double riskAmount, double takeProfit)
    {
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      
        if(stopLossPrice <= bid)
        {
            Print("Invalid stop loss: must be above current price for a short.");
            return false;
        }
      
        //--- calculate $ risk per lot using MT5
        double riskPerLot = MoneyRiskPerLot(bid, stopLossPrice, false);
        if(riskPerLot <= 0)
        {
            Print("Failed to calculate risk per lot.");
            return false;
        }
      
        //--- calculate volume (lots)
        double volume = riskAmount / riskPerLot;
      
        //--- normalize volume
        double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
        volume = MathFloor(volume / lotStep) * lotStep;
        volume = MathMax(minLot, MathMin(volume, maxLot));
      
        //--- calculate take profit
        double stopDistance = stopLossPrice - bid;
      
        double sl = NormalizeDouble(stopLossPrice, _Digits);
        double tp = NormalizeDouble(takeProfit, _Digits);
          
        return sendTradeRequest(sl, tp, volume, false);
      
    }
    
           // Open long
    bool OpenLongWithTakeProfit(double stopLossPrice, double riskAmount, double takeProfit)
    {
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
        if(stopLossPrice >= ask)
        {
            Print("Invalid stop loss: must be below current price for a long.");
            return false;
        }
      
        //--- calculate $ risk per lot using MT5
        double riskPerLot = MoneyRiskPerLot(ask, stopLossPrice, true);
        if(riskPerLot <= 0)
        {
            Print("Failed to calculate risk per lot.");
            return false;
        }
      
        //--- calculate volume (lots)
        double volume = riskAmount / riskPerLot;
      
        //--- normalize volume
        double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
        volume = MathFloor(volume / lotStep) * lotStep;
        volume = MathMax(minLot, MathMin(volume, maxLot));
        
      //--- calculate take profit
        double stopDistance = ask - stopLossPrice;
      
        double sl = NormalizeDouble(stopLossPrice, _Digits);
        double tp = NormalizeDouble(takeProfit, _Digits);
          
        return sendTradeRequest(sl, tp, volume, true);
        
      }
    
};
