//+------------------------------------------------------------------+
//|                                                 tradeManager.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//| TradeManager.mqh                                                 |
//+------------------------------------------------------------------+


class tradeManager
{
private:
    string m_symbol;
    ulong  m_magic;
    bool flipPositions;

public:
    // Constructor: set symbol and magic number at creation
    tradeManager(string symbol, ulong magic)
    {
        this.m_symbol = symbol;
        this.m_magic  = magic;
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
        double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);

        double stopDistance = isBuy ? entryPrice - stopPrice : stopPrice - entryPrice;
        double ticks = stopDistance / tickSize;
        double moneyPerLot = ticks * tickValue;

        if(moneyPerLot <= 0)
        {
            Print("Invalid moneyPerLot calculation for symbol ", m_symbol);
            return 0;
        }

        return moneyPerLot;
    }

    // Send trade request
    bool SendOrder(ENUM_ORDER_TYPE type, double volume, double price, double sl, double tp, string comment)
    {
        MqlTradeRequest request;
        MqlTradeResult  result;
        ZeroMemory(request);
        ZeroMemory(result);

        request.action       = TRADE_ACTION_DEAL;
        request.symbol       = m_symbol;
        request.volume       = volume;
        request.type         = type;
        request.price        = price;
        request.sl           = sl;
        request.tp           = tp;
        request.deviation    = 50;
        request.magic        = m_magic;
        request.comment      = comment;
        request.type_filling = ORDER_FILLING_IOC;
        
        

        if(!OrderSend(request, result))
        {
            Print("OrderSend failed: ", result.retcode);
            return false;
        }

        if(result.retcode == TRADE_RETCODE_DONE)
        {
            PrintFormat("%s opened %.2f lots at %.5f | SL=%.5f | TP=%.5f",
                        (type==ORDER_TYPE_BUY ? "Long" : "Short"),
                        volume, price, sl, tp);
            return true;
        }

        PrintFormat("Order failed, retcode=%d", result.retcode);
        return false;
    }

public:
    // Open long
    bool OpenLong(double stopLossPrice, double riskAmount, double rr=2.0, double takeProfitLevel=0)
    {
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        

        if(stopLossPrice >= ask)
        {
            Print("Invalid stop loss: must be below current price for a long.");
            return false;
        }

        double riskPerLot = MoneyRiskPerLot(ask, stopLossPrice, true);
        if(riskPerLot <= 0) return false;

        double volume = riskAmount / riskPerLot;

        double minLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
        double maxLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);

        volume = MathFloor(volume / lotStep) * lotStep;
        if(volume < minLot) return false;
        volume = MathMin(volume, maxLot);

        double takeProfit = (takeProfitLevel != 0) ? takeProfitLevel : ask + (ask - stopLossPrice) * rr;
        
        
        if(this.flipPositions)
        {
            return SendOrder(ORDER_TYPE_SELL, volume, bid,
                NormalizeDouble(takeProfit,_Digits),
                NormalizeDouble(stopLossPrice,_Digits),
                "Short (flipped) RR=" + DoubleToString((1/rr),1) + " dynamic risk");
        }
    
        

        return SendOrder(ORDER_TYPE_BUY, volume, ask,
                         NormalizeDouble(stopLossPrice,_Digits),
                         NormalizeDouble(takeProfit,_Digits),
                         "Long RR=" + DoubleToString(rr,1) + " dynamic risk");
    }

    // Open short
    bool OpenShort(double stopLossPrice, double riskAmount, double rr=2.0, double takeProfitLevel=0)
    {
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

        if(stopLossPrice <= bid)
        {
            Print("Invalid stop loss: must be above current price for a short.");
            return false;
        }

        double riskPerLot = MoneyRiskPerLot(bid, stopLossPrice, false);
        if(riskPerLot <= 0) return false;

        double volume = riskAmount / riskPerLot;

        double minLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
        double maxLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);

        volume = MathFloor(volume / lotStep) * lotStep;
        if(volume < minLot) return false;
        volume = MathMin(volume, maxLot);

        double takeProfit = (takeProfitLevel != 0) ? takeProfitLevel : bid - (stopLossPrice - bid) * rr;

                
        if(this.flipPositions)
        {
            return SendOrder(ORDER_TYPE_BUY, volume, ask,
                NormalizeDouble(stopLossPrice,_Digits),
                NormalizeDouble(takeProfit,_Digits),
                "Long (flipped) RR=" + DoubleToString((1/rr),1) + " dynamic risk");
        }
        
        return SendOrder(ORDER_TYPE_SELL, volume, bid,
                         NormalizeDouble(stopLossPrice,_Digits),
                         NormalizeDouble(takeProfit,_Digits),
                         "Short RR=" + DoubleToString(rr,1) + " dynamic risk");
    }
};
