//+------------------------------------------------------------------+
//|                                                 TradingRobot.mq4 |
//|                                                        Robin Kim |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Robin Kim, Benji Weiss"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict



extern double Lots = 0.2;        //Lots
// volatility
extern int rsize = 21;           //volatility range


// BUYING FUNCTIONS
extern int takeprofit = 380;     //Buy Take Profit level
extern int stoploss = 70;        //Buy Stop Loss level
extern int rsisup = 17;          //Buy RSI Support 
// function 0 buying variables: MACD
extern int MACDx = 44;           //Buy 0 MACD range
extern int    FastEMA = 29;      //Buy 0 MACD Fast EMA
extern int    SlowEMA = 71;      //Buy 0 MACD Slow EMA
extern int    MACD_SMA = 47;     //Buy 0 MACD Signal EMA
extern int macdrsiperiod = 23;   //Buy 0 RSI Period
// funciton 1 buying variables: MA 
extern int MAx = 137;             //Buy 1 MA range
extern int period1 = 29;         //Buy 1 MA Fast Period
extern int period2 = 161;        //Buy 1 MA Slow Period
extern int movrsiperiod = 209;    //Buy 1 RSI Period
// function 2 buying variables: Ichimoku
extern int ichirsiperiod = 203;   //Buy 2 RSI Period
extern int SenAv = 44;           //Buy 2 Senkou Average Period


// SELLING FUNCTIONS
extern int sellStopLoss = 70;   //Sell Stop Loss level
extern int rsiPeriod = 72;       //Sell RSI Period
extern int fractalPeriod = 42;   //Sell Check Fractal range
// function 3 variables - RsiFractalMacd
extern int rsiSupport3 = 12;     //Sell 3 RSI Support
extern int rsiResistance3 = 74;  //Sell 3 RSI Resistance
extern int macdFast = 29;        //Sell 3 MACD Fast EMA
extern int macdSlow = 71;        //Sell 3 MACD Slow EMA
extern int macdSignal = 47;       //Sell 3 MACD Signal EMA
// function 4 variables - RsiFractalKinko
extern int rsiSupport4 = 48;     //Sell 4 RSI Support
extern int rsiResistance4 = 86;  //Sell 4 RSI Resistance
extern int tenkanPeriod = 100;    //Sell 4 Tenkan Sen
extern int kijunPeriod = 195;     //Sell 4 Kijun Sen
extern int senkouBPeriod = 22;   //Sell 4 Senkou B
// function 5 variables - RsiFractalCandle
extern int rsiSupport5 = 46;     //Sell 5 RSI Support Level
extern int rsiResistance5 = 56;  //Sell 5 RSI Resistance Level


// variables to calculate profit factors
static double BuyProfitRSIMACD;
static double BuyLossRSIMACD;
static double BuyProfitRSIICHIMOKU;
static double BuyLossRSIICHIMOKU;
static double BuyProfitRSIMA;
static double BuyLossRSIMA;

static double SellProfitRsiFractalMacd;
static double SellLossRsiFractalMacd;
static double SellProfitRsiFractalKinko;
static double SellLossRsiFractalKinko;
static double SellProfitRsiFractalCandle;
static double SellLossRsiFractalCandle;

// variables to store profit factors
static int numFunctions = 6;         //number of functions
static bool trades[6] = {FALSE, FALSE, FALSE, FALSE, FALSE, FALSE}; //pending trades

static double pf[6] = {3.0, 3.0, 3.0, 3.0, 3.0, 3.0 };  //array of profit factors
static double sortedpf[6];                               //sorted array of profit factors

static int orderCount = 0;    // keeps track of what order# we are up to in history


static int rx = 1;      // queue counter
                        // if an order gets sent, rx will increment by 1
                        // not allowing ontick to execute the expert adisor
                        // until it is set to 1 again

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static int timec = 0;            //timec keeps track
   static bool minutetick = true;   //minutetick lets us know when it's been a minute
   
   if(timec == 59){timec = 0;}      //resets timec to 0 once an hour has passed
   
   if(Minute() == timec)      //if current minute == minute counter
   {
      minutetick = true;
      
      if(minutetick == true)
      {   
            minutetick = false;
            timec++;                //increment minute counter.  when minute() changes to the next minute, it will equal timec
            
            if(rx==1) 
            {      
               CheckBuyRSIMACD();            //function 0
               CheckBuyRSIMA();              //function 1
               CheckBuyRSIICHIMOKU();        //function 2
               CheckSellRsiFractalMacd();    //function 3
               CheckSellRsiFractalKinko();   //function 4
               CheckSellRsiFractalCandle();  //function 5
      
               Execute();
            }//if rx == 1
            
            else
            {
               rx++;
               if(rx == 7){rx = 1;}    // allows ontick to execute the expert advisor after 6 minutes
            }//else (if rx != 1)
      }//if minute tick is == to true
      
      CloseSells();                 //check to close sells at each minutetick
      CalculateProfitFactor();      //i moved it down here so it calculates every minute
                                    //it will only calculate if there is a new closed order in history
   }// if Minute() == timec
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Profit Factor Comparison                                         |
//+------------------------------------------------------------------+
void Execute()
{
   int cnt = 0;      //number of pending trades
   
   //count how many trades are pending
   for(int i=0; i<numFunctions; i++)
   {
      if(trades[i])
      {
         cnt++;
      }//end if(trades[i])
   }//end for(int i=0; i<3; i++)
   
   
   if(cnt>0)         //if there are trades
   {
      //population of sortedarray
      for(int i = 0; i<numFunctions; i++)
      {
         sortedpf[i] = pf[i];
      }//end for(int i = 0; i<3; i++)
      
      
      // sort sortedpf (insertion sort from highest to lowest)
      for(int i=1; i<numFunctions; i++)                 //go through each element
      {
         double x = sortedpf[i];             //let x = current value
         int j = i-1;                        //set j to current index-1
         while(j>=0 && sortedpf[j]<x)        //while j is greater than 0 and value at index j is greater than x
         {
            sortedpf[j+1] = sortedpf[j];     //move the value at index j to index j+1
            j = j-1;                         //decrement j, to check the previous value in the array
         }//end while(j>=0 && sortedpf[j]<x)
         sortedpf[j+1] = x;                  //put x into the newly opened spot
      }//end for(int i=1; i<3; i++)


/**************************  Test *************
         for(int i = 0; i<numFunctions; i++)
         {
            Print("sortedpf[",i,"] ",sortedpf[i]);
         }//end for(int i = 0; i<3; i++)
*************************  END TEST **********/
   
         
      bool tradeSent = FALSE;             //keep track of if a trade has been sent
      int i = 0;                          //counter for the while loop to follow
      
      // go down sortedpf from highest to lowest pf's.  if trade for that pf is true, send order
      while(tradeSent==FALSE && i<numFunctions)      //while trade hasn't been sent yet and i is less than numFunctions length
      {
         if(sortedpf[i]==pf[0] && trades[0])       //if current pf in sortedpf = function 0's pf && there is a pending order for function 0
         {
            BuyRSIMACD();              //send order for function 0
            tradeSent = TRUE;          //set tradeSent to True, to end the while loop
            rx++;                      //increment wait timer (rx)
         }//end if(sortedpf[i]==pf[0] && trades[0]))
         else if(sortedpf[i]==pf[1] && trades[1])  //if current pf in sortedpf = function 1's pf && there is a pending order for function 1
         {
            BuyRSIICHIMOKU();          //send order for function 1
            tradeSent = TRUE;          //set tradeSent to True, to end the while loop
            rx++;                      //increment wait timer (rx)
         }//end else if(sortedpf[i]==pf[1] && trades[1])
         else if(sortedpf[i]==pf[2] && trades[2])  //if current pf in sortedpf = function 2's pf && there is a pending order for function 2
         {
            BuyRSIMA();                //send order for function 2
            tradeSent = TRUE;          //set tradeSent to True, to end the while loop
            rx++;                      //increment wait timer (rx)
         }//end else if(sortedpf[i]==pf[2] && trades[2])
         
         else if(sortedpf[i]==pf[3] && trades[3])  //if current pf in sortedpf = function 3's pf && there is a pending order for function 3
         {
            SellRsiFractalMacd();      //send order for function 3
            tradeSent = TRUE;          //set tradeSent to True, to end the while loop
            rx++;                      //increment wait timer (rx)
         }//end if(sortedpf[i]==pf[3] && trades[3]))
         else if(sortedpf[i]==pf[4] && trades[4])  //if current pf in sortedpf = function 4's pf && there is a pending order for function 4
         {
            SellRsiFractalKinko();     //send order for function 4
            tradeSent = TRUE;          //set tradeSent to True, to end the while loop
            rx++;                      //increment wait timer (rx)
         }//end if(sortedpf[i]==pf[4] && trades[4]))
         else if(sortedpf[i]==pf[5] && trades[5])  //if current pf in sortedpf = function 5's pf && there is a pending order for function 5
         {
            SellRsiFractalCandle();    //send order for function 5
            tradeSent = TRUE;          //set tradeSent to True, to end the while loop
            rx++;                      //increment wait timer (rx)
         }//end if(sortedpf[i]==pf[5] && trades[5]))
         
         else
         {
            tradeSent = FALSE;
         }
         i++;     //increment the counter
      }//end while(tradeSent==FALSE && i<6)
  
      //reset pending trades
      for(i=0;i<numFunctions;i++)
      {
         trades[i] = FALSE;
      }//end for(i=0;i<6;i++)
   }//end if(cnt>0)
}//end ProfitFactor()
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
/********************************************************************/
/*               Buying RSI MACD                                    */
/*                function 0                                        */
/********************************************************************/
//+------------------------------------------------------------------+


void CheckBuyRSIMACD()
{ 
   double macd1 = iMACD(NULL, 0, FastEMA, SlowEMA, MACD_SMA, PRICE_CLOSE, 0, 1);
   double macd1signal = iMACD(NULL, 0, FastEMA, SlowEMA, MACD_SMA, PRICE_CLOSE, 1, 1);
   
   double macdx = iMACD(NULL, 0, FastEMA, SlowEMA, MACD_SMA, PRICE_CLOSE, 0, MACDx);
   double macdxsignal = iMACD(NULL, 0, FastEMA, SlowEMA, MACD_SMA, PRICE_CLOSE, 1, MACDx);
   
   double rsi = iRSI(NULL, 0, macdrsiperiod, PRICE_CLOSE, 1);


   double slope = (macd1-macdx);

   if(rsi<rsisup)
   {
     if(slope<0 && macd1<0 )
     {
         trades[0] = TRUE;
     }
   }//if macd crossover occurs downards, buy signal
             
 }//CHECKMACD
 
  void BuyRSIMACD()
 { 
      
      int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, 10, Bid-stoploss*Point, Bid+takeprofit*Point, "Macd");
      if(ticket < 0 )
      {
         Alert("error sending order Macd: ", GetLastError());            
      }
      else
      {
         if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         {     
            Print("BUY Order Opened: ",OrderComment()); 
         }
      }
      
 }
 
//+-----------------------------------------------------------------+/
/********************************************************************/
/*               Buying RSI ICHIMOKU                                */
/*                function 1                                        */
/********************************************************************/
//+------------------------------------------------------------------/      

 
void CheckBuyRSIICHIMOKU()
 {
   
   double SenkouA = iIchimoku(NULL,0,9,26,SenAv,MODE_SENKOUSPANA,1);
   double SenkouB = iIchimoku(NULL,0,9,26,SenAv,MODE_SENKOUSPANB,1);
   double rsi = iRSI(NULL, 0, ichirsiperiod, PRICE_CLOSE, 1);
   
   
   if(SenkouA<SenkouB && Open[1]<SenkouA)
   {  
     if(rsi<rsisup)
     {
         trades[1] = TRUE;
     }//rsi<35
   }//senkoua<senkouB
 
 }//CHECK ICHIMOKU
 
void BuyRSIICHIMOKU()
 {
     int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, 10, Bid-stoploss*Point, Bid+takeprofit*Point, "Ichimoku");
     if(ticket < 0 )
     {
        Alert("error sending order Ichimoku: ", GetLastError());            
     }   
     else
      {
         if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         {     
            Print("BUY Order Opened: ",OrderComment()); 
         }
      }
      
 }
  
//+------------------------------------------------------------------+
/********************************************************************/
/*               Buying Moving average RSI                          */
/*                function 2                                        */
/********************************************************************/
//+------------------------------------------------------------------+
void CheckBuyRSIMA()
{        
   double ma1 = iMA(Symbol(), Period(), period1, 0, 0, 0, 1);
   double ma2 = iMA(Symbol(), Period(), period2, 0, 0, 0, 1);
   double pastma1 = iMA(Symbol(), Period(), period1, 0, 0, 0, MAx);
   double pastma2 = iMA(Symbol(), Period(), period2, 0, 0, 0, MAx);
   double rsi = iRSI(NULL, 0, movrsiperiod, PRICE_CLOSE, 1);

   double mov2slope = (ma2-pastma2);
 
   if( mov2slope<0 && ma1<ma2 )   
   {
      if(rsi<rsisup)
      {
         trades[2] = TRUE;
      }//if price is falling and the short ema is higher than the long ema, sell
      
   }//ifrsi<sup
}//Check Movav


void BuyRSIMA()
{
      int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, 10, Bid-stoploss*Point, Bid+takeprofit*Point, "Movav");
      if(ticket < 0 )
      {
         Alert("error sending order movav: ", GetLastError());            
      }
      else
      {
         if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         {     
            Print("BUY Order Opened: ",OrderComment()); 
         }
      }
      
}  
 


//+------------------------------------------------------------------+
//| Rsi, Fractals, Macd                                              |
//| function 3                                                       |
//+------------------------------------------------------------------+
void CheckSellRsiFractalMacd()
{
   int total = OrdersTotal();    //total number of orders
   int i;      //counter for loops
   //+------------------------------------------------------------------+
   //| Set up Indicators                                                |
   //+------------------------------------------------------------------+
   double rsi = iRSI(NULL,0,rsiPeriod,PRICE_CLOSE,0);      //current RSI value
   double macd = iMACD(NULL,0,macdFast,macdSlow,macdSignal,PRICE_CLOSE,MODE_MAIN,0);      //current MACD value
   double signal = iMACD(NULL,0,macdFast,macdSlow,macdSignal,PRICE_CLOSE,MODE_SIGNAL,0);  //current MACD signal value
   double fractalUp = 0;      //value of nearest up fractal
   int fractalUpIndex = 0;    //index of nearest up fractal
   
   // Check for Up Fractal
   for(i=3; i<=fractalPeriod; i++)
   {
      fractalUp = iFractals(NULL,0,MODE_UPPER,i);     //close at shift i if there is a fractal. NULL if there is no fractal at shift i
      if(fractalUp != NULL)      //if fractalUp has a value
      {
         fractalUpIndex = i;     //set the fractalUpIndex to i
         break;      //break out of the for loop
      }//end if(fractalUp != NULL)
   }//end for(i=3; i<=fractalPeriod1; i++)
   
   //+------------------------------------------------------------------+
   //| Open Selling Order                                               |
   //+------------------------------------------------------------------+  
   if(rsi>rsiResistance3 && macd<signal && signal>0 && fractalUpIndex>=3)
   {                     
      trades[3] = TRUE;
   }//end if(rsi>rsiResistance3 && macd<signal && signal>0 && fractalUpIndex>=3)
}//end CheckRsiFractalMacd()

void SellRsiFractalMacd()
{
    int ticket = OrderSend(Symbol(),OP_SELL,Lots,Bid,10,Ask+sellStopLoss*Point,0,"SellRsiFractalMacd",0,Red);
    if(ticket>0)
    {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      {
         Print("SELL Order Opened: ",OrderComment());
      }//end if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
    }//end if(ticket>0)
    if(ticket<0)
    {
      Print(OrderComment()," SELL Order error: ",GetLastError());
    }//end if(ticket<0)
}//end SellRsiFractalMacd()
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Rsi, Fractals, Ichimoku                                          |
//| function 4                                                       |
//+------------------------------------------------------------------+
void CheckSellRsiFractalKinko()
{
   int total = OrdersTotal();           
   int i;
   int fractalUpIndex = 0;
   double tenkan[5] = {0,0,0,0,0};
   bool tenkanTrendDown = FALSE;
   
   //+------------------------------------------------------------------+
   //| Set up Indicators                                                |
   //+------------------------------------------------------------------+
   double rsi = iRSI(NULL,0,rsiPeriod,PRICE_CLOSE,0);
   double kijun = iIchimoku(NULL,0,tenkanPeriod,kijunPeriod,senkouBPeriod,MODE_KIJUNSEN,0);
   double senkouA = iIchimoku(NULL,0,tenkanPeriod,kijunPeriod,senkouBPeriod,MODE_SENKOUSPANA,0);
   double senkouB = iIchimoku(NULL,0,tenkanPeriod,kijunPeriod,senkouBPeriod,MODE_SENKOUSPANB,0);
   double fractalUp = 0;
   
   // Check Up Fractal
   for(i=3; i<=fractalPeriod; i++)
   {
      fractalUp = iFractals(NULL,0,MODE_UPPER,i);
      if(fractalUp != NULL)
      {
         fractalUpIndex = i;
         break;
      }
   }
   
   // Check Tenkan Trend
   for(i=0; i<=4; i++)
   {
      tenkan[i] = iIchimoku(NULL,0,tenkanPeriod,kijunPeriod,senkouBPeriod,MODE_TENKANSEN,i);
   }
   if(tenkan[0]<=tenkan[1] && tenkan[1]<=tenkan[2] && tenkan[2]<=tenkan[3] && tenkan[3]<=tenkan[4])
   {
      tenkanTrendDown = TRUE;
   }
   
   
   //+------------------------------------------------------------------+
   //| Open Selling Order                                               |
   //+------------------------------------------------------------------+  
   if(rsi>rsiResistance4 && fractalUpIndex>=3 && Close[1]<kijun && Close[1]>senkouA && Close[1]>senkouB && tenkanTrendDown)
   {
      trades[4] = TRUE;
   }
}

void SellRsiFractalKinko()
{
    int ticket = OrderSend(Symbol(),OP_SELL,Lots,Bid,10,Ask+sellStopLoss*Point,0,"SellRsiFractalKinko",0,Red);
    if(ticket>0)
    {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      {
         Print("SELL Order Opened: ",OrderComment());
      }
    }
    if(ticket<0)
    {
      Print(OrderComment()," SELL Order error: ",GetLastError());
    }
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Rsi, Fractals, Candle Pattern                                    |
//| function 5                                                       |
//+------------------------------------------------------------------+
void CheckSellRsiFractalCandle()
{
   int total = OrdersTotal();           
   int i;
   int fractalUpIndex = 0;
   bool candleDown = FALSE;
   
   //+------------------------------------------------------------------+
   //| Set up Indicators                                                |
   //+------------------------------------------------------------------+
   double rsi = iRSI(NULL,0,rsiPeriod,PRICE_CLOSE,0);
   double fractalUp = 0;
   
   // Check Up Fractal
   for(i=3; i<=fractalPeriod; i++)
   {
      fractalUp = iFractals(NULL,0,MODE_UPPER,i);
      if(fractalUp != NULL)
      {
         fractalUpIndex = i;
         break;
      }
   }
   
   if(Close[1]<=Low[4])
   {
      candleDown = TRUE;
   }
   
   i = 4;
   while(candleDown==TRUE && i>1)
   {
      if(Open[i]>Close[i] || High[i]>High[i-1])
      {
         candleDown = FALSE;
      }
      i--;
   }
   
   //+------------------------------------------------------------------+
   //| Set Selling Flag                                                 |
   //+------------------------------------------------------------------+  
   if(rsi>rsiResistance5 && fractalUpIndex>=3 && candleDown==TRUE)
   {
      trades[5] = TRUE;
   }
}

void SellRsiFractalCandle()
{
    int ticket = OrderSend(Symbol(),OP_SELL,Lots,Bid,10,Ask+sellStopLoss*Point,0,"SellRsiFractalCandle",0,Red);
    if(ticket>0)
    {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      {
         Print("SELL Order Opened: ",OrderComment());
      }
    }
    if(ticket<0)
    {
      Print(OrderComment()," SELL Order error: ",GetLastError());
    }
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Close Sell Orders                                                |
//+------------------------------------------------------------------+
void CloseSells()
{
   int total = OrdersTotal();   
   string comment;        
   int cnt,i;
   
   //+------------------------------------------------------------------+
   //| Set up Indicators                                                |
   //+------------------------------------------------------------------+
   double rsi = iRSI(NULL,0,rsiPeriod,PRICE_CLOSE,0);
   int fractalDownIndex = 0;
   double fractalDown = 0;

   double macd = iMACD(NULL,0,macdFast,macdSlow,macdSignal,PRICE_CLOSE,MODE_MAIN,0);
   double signal = iMACD(NULL,0,macdFast,macdSlow,macdSignal,PRICE_CLOSE,MODE_SIGNAL,0);

   double tenkan[5] = {0,0,0,0,0};
   bool tenkanTrendUp = FALSE;

   bool candleUp = FALSE;
   
   // Check for Down Fractal
   for(i=3; i<=fractalPeriod; i++)
   {
      fractalDown = iFractals(NULL,0,MODE_LOWER,i);
      if(fractalDown != NULL)
      {
         fractalDownIndex = i;
         break;
      }
   }
   
   // Check for Tenkan Uptrend
   for(i=0; i<=4; i++)
   {
      tenkan[i] = iIchimoku(NULL,0,tenkanPeriod,kijunPeriod,senkouBPeriod,MODE_TENKANSEN,i);
   }
   if(tenkan[0]>=tenkan[1] && tenkan[1]>=tenkan[2] && tenkan[2]>=tenkan[3] && tenkan[3]>=tenkan[4])
   {
      tenkanTrendUp = TRUE;
   }
   
   if(Close[1]>=High[4])
   {
      candleUp = TRUE;
   }
   
   // Check for reversal to uptrend in Candlestick pattern
   i = 4;
   while(candleUp==TRUE && i>1)
   {
      if(Open[i]<Close[i] || Low[i]<Low[i-1])
      {
         candleUp = FALSE;
      }
      i--;
   }

   
   total = OrdersTotal();
   for(cnt=0;cnt<total;cnt++)
   {
      if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
      {
         continue;
      }
      
      comment = OrderComment();
      
      if(OrderType()==OP_SELL && OrderSymbol()==Symbol())
      {
         //+------------------------------------------------------------------+
         //| Close Function 3 (RsiFractalMacd)                                |
         //+------------------------------------------------------------------+
         if(StringCompare(comment,"SellRsiFractalMacd",FALSE)==0)
         {
            if(rsi<rsiSupport3 && macd>signal && signal<0 && fractalDownIndex>=3)
            {
               if(OrderClose(OrderTicket(),OrderLots(),Ask,5,Green))       
               {
                  Print("SELL Order Closed: ",comment);
               }
               else
               {
                  Print(comment," SELL OrderClose error ",GetLastError());
               }
            }
         }
         
         //+------------------------------------------------------------------+
         //| Close Function 4 (RsiFractalKinko)                               |
         //+------------------------------------------------------------------+
         else if(StringCompare(comment,"SellRsiFractalKinko",FALSE)==0)
         {
            if(rsi<rsiSupport4 && fractalDownIndex>=3 && tenkanTrendUp)
            {
               if(OrderClose(OrderTicket(),OrderLots(),Ask,5,Green))
               {
                  Print("SELL Order Closed: ",comment);
               }
               else
               {
                  Print(comment," SELL OrderClose error ",GetLastError());
               }
            }
         }
         
         //+------------------------------------------------------------------+
         //| Close Function 5 (RsiFractalCandle)                              |
         //+------------------------------------------------------------------+
         else if(StringCompare(comment,"SellRsiFractalCandle",FALSE)==0)
         {
            if(rsi<rsiSupport5 && fractalDownIndex>=3 && candleUp==TRUE)
            {
               if(OrderClose(OrderTicket(),OrderLots(),Ask,5,Green))
               {
                  Print("SELL Order Closed: ",comment);
               }
               else
               {
                  Print(comment," SELL OrderClose error ",GetLastError());
               }
            }
         }  
      }
   }    
}
//+------------------------------------------------------------------+




//int orderCount = 0;  - this is added at the top with the other global variables

void CalculateProfitFactor()
{
   int total = OrdersHistoryTotal();
   
   if(total>orderCount)
   {
      for(int i=orderCount; i<total; i++)
      {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
         {
            orderCount++;
            string comment = OrderComment();
            double profit = OrderProfit();
     
            if(StringCompare(StringSubstr(comment,0,4),"Macd",FALSE)==0)
            {
               Print("*** CLOSED TRADE *** Order#: ",i+1,";  ",comment,";  Profit: ",profit);     //check to see profit or loss is correct
               if(profit < 0)
               {
                  BuyLossRSIMACD += (profit/-1);
               }
               else
               {
                  BuyProfitRSIMACD += profit;
               }
               
               if(BuyLossRSIMACD != 0)
               {
                  pf[0] = BuyProfitRSIMACD/BuyLossRSIMACD;
               }
               
               Print("%%% PROFIT FACTOR %%% ",comment,";  Profit Factor: ", pf[0]);        //check to see if profit factor is being calculated
            }
            //if the selected order is caused by the MACD function, find its profit factor and update the static variable for buymacd
            
            if(StringCompare(StringSubstr(comment,0,8),"Ichimoku",FALSE)==0)
            {
               Print("*** CLOSED TRADE *** Order#: ",i+1,";  ",comment,";  Profit: ",profit);     //check to see profit or loss is correct
               if(profit < 0)
               {
                  BuyLossRSIICHIMOKU += (profit/-1);
               }
               else
               {
                  BuyProfitRSIICHIMOKU += profit;
               }
               
               if(BuyLossRSIICHIMOKU != 0)
               {
                  pf[1] = BuyProfitRSIICHIMOKU/BuyLossRSIICHIMOKU;
               }
               
               Print("%%% PROFIT FACTOR %%% ",comment,";  Profit Factor: ", pf[1]);        //check to see if profit factor is being calculated
            }
            //if the selected order is caused by the Ichimoku function, find its profit factor and update the static variable for buyichimoku      
            
            if(StringCompare(StringSubstr(comment,0,5),"Movav",FALSE)==0)
            {
               Print("*** CLOSED TRADE *** Order#: ",i+1,";  ",comment,";  Profit: ",profit);     //check to see profit or loss is correct
               if(profit < 0)
               {
                  BuyLossRSIMA += (profit/-1);
               }
               else
               {
                  BuyProfitRSIMA += profit;
               }
               
               if(BuyLossRSIMA != 0)
               {
                  pf[2] = BuyProfitRSIMA/BuyLossRSIMA;
               }
               
               Print("%%% PROFIT FACTOR %%% ",comment,";  Profit Factor: ", pf[2]);        //check to see if profit factor is being calculated
            }
            //if the selected order is caused by the Movav function, find its profit factor and update the static variable for buymovav    
            
              
            if(StringCompare(StringSubstr(comment,0,18),"SellRsiFractalMacd",FALSE)==0)
            {
               Print("*** CLOSED TRADE *** Order#: ",i+1,";  ",comment,";  Profit: ",profit);     //check to see profit or loss is correct
               if(profit < 0)
               {
                  SellLossRsiFractalMacd += (profit/-1);
               }
               else
               {
                  SellProfitRsiFractalMacd += profit;
               }
               
               if(SellLossRsiFractalMacd != 0)
               {
                  pf[3] = SellProfitRsiFractalMacd/SellLossRsiFractalMacd;
               }
               
               Print("%%% PROFIT FACTOR %%% ",comment,";  Profit Factor: ", pf[3]);        //check to see if profit factor is being calculated
            }
            
            if(StringCompare(StringSubstr(comment,0,19),"SellRsiFractalKinko",FALSE)==0)
            {
               Print("*** CLOSED TRADE *** Order#: ",i+1,";  ",comment,";  Profit: ",profit);     //check to see profit or loss is correct
               if(profit < 0)
               {
                  SellLossRsiFractalKinko += (profit/-1);
               }
               else
               {
                  SellProfitRsiFractalKinko += profit;
               }
               
               if(SellLossRsiFractalKinko != 0)
               {
                  pf[4] = SellProfitRsiFractalKinko/SellLossRsiFractalKinko;
               }
               
               Print("%%% PROFIT FACTOR %%% ",comment,";  Profit Factor: ", pf[4]);        //check to see if profit factor is being calculated
            }
            
            if(StringCompare(StringSubstr(comment,0,20),"SellRsiFractalCandle",FALSE)==0)
            {
               Print("*** CLOSED TRADE *** Order#: ",i+1,";  ",comment,";  Profit: ",profit);     //check to see profit or loss is correct
               if(profit < 0)
               {
                  SellLossRsiFractalCandle += (profit/-1);
               }
               else
               {
                  SellProfitRsiFractalCandle += profit;
               }
               
               if(SellLossRsiFractalCandle != 0 )
               {
                  pf[5] = SellProfitRsiFractalCandle/SellLossRsiFractalCandle;
               }
               
               Print("%%% PROFIT FACTOR %%% ",comment,";  Profit Factor: ", pf[5]);        //check to see if profit factor is being calculated
            }
         
         }//if the order was selected succesfully .. OrderSelect == true
         
         else
         {
            Alert(GetLastError());
         }
      }//sift through orders total
   }//if there are orders in history
}// Going to change profit factors