//+------------------------------------------------------------------+
//|  SMC_Portfolio_Engine_V6_3_0.mq5                                          |
//|  SMC MultiAsset NewsGuard V4 — FX, Metals, Indices, BTC            |
//|  Confluence Scoring + Asian Compression + MT5 Calendar NewsGuard + Shock Filters          |
//|  Server UTC+2 (Blueberry Markets)                                |
//|  Version 6.30 — ATHENA Framework Integration Smoke Test — fixes: H4 handle leak, HistorySelect scope,      |
//|           min-lot risk guard (XAGUSD/small-balance oversize)    |
//|                 day-start balance baseline, vol gate path,        |
//|                 index MinSLPrice                                  |
//+------------------------------------------------------------------+
#property copyright "Gray"
#property version   "6.30"
#property strict

#include <RegimeGate.mqh>
#include <LiquidityMap.mqh>
#include <VolGate.mqh>
#include <BetterVolume_Reader.mqh>
#include <EventBus.mqh>
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== Risk ==="
input double InpRiskPct         = 0.5;
input double InpReducedRiskPct  = 0.25;   // Risk used after drawdown brake
input double InpRewardRatio     = 2.5;
input int    InpMaxTrades       = 2;
input double InpMinRR           = 1.5;
input int    InpMaxTradesPerDay = 3;
input double InpMaxDailyLossPct = 3.0;
input double InpReduceRiskDDPct = 3.0;
input double InpStopTradingDDPct= 6.0;
input int    InpCooldownBarsAfterLoss = 2;
input double InpMinLotRiskMult  = 2.0;    // Block trade if min-lot cost > N x target risk%

input group "=== Volatility Gate ==="
input bool   InpVgEnabled       = true;   // Enable volatility filter
input double InpVgConfThreshold = 0.65;   // Min confidence to trust vol state
// EXPANDING  = best conditions, all gates as normal
// NORMAL     = acceptable, BOS confirmation enforced
// CONTRACTING= suppressed, no entries

input group "=== Regime Gate ==="
input bool   InpRgEnabled       = false; // When true: pre-entry gate blocks unknown/mismatched regimes
input bool   InpRgUseGlobalVar  = true;
input bool   InpRgUseCsv        = false; // true = read Common\Files\regimes.csv instead of GlobalVariable/JSON
input string InpRgJsonFile      = "regime.json";
input bool   InpRgLongsInBull   = true;
input bool   InpRgShortsInBear  = true;
input bool   InpRgRangeEntries  = false;
input bool   InpRgCloseOnFlip   = false;

input group "=== Liquidity Map ==="
input int    InpLmSwingBars     = 10;
input int    InpLmSweepBars     = 6;
input bool   InpLmRequireClose  = true;
// Note: EqualLevelPips and SL buffer are auto-set per symbol below
// Override with 0 to use auto values, or set manually
input double InpLmEqualPipsOverride  = 0.0;  // 0 = auto per symbol
input double InpSlBufferPipsOverride = 0.0;  // 0 = auto per symbol

input group "=== Structure H4 ==="
input int    InpStructSwing     = 10;
input int    InpStructLookback  = 50;

input group "=== Entry / Confluence Scoring ==="
input ENUM_TIMEFRAMES InpEntryTF      = PERIOD_M30;
input bool   InpUseConfluenceScoring = true;
input int    InpMinScoreToEnter = 7;
input int    InpScoreH4Bias     = 2;
input int    InpScorePDZone     = 1;
input int    InpScoreSweep      = 2;
input int    InpScoreFVG        = 1;
input int    InpScoreBOS        = 1;
input int    InpScoreEngulf     = 1;
input int    InpScoreAsianCompression = 2;
input int    InpScoreSessionLiquidity = 2;
input int    InpScoreBetterVolume = 2;       // Volume participation / climax confirmation score
input bool   InpHardRequireH4Bias = true;
input bool   InpHardRequireSweep  = false;
input bool   InpHardRequireFVG    = false;
input bool   InpHardRequireBOS    = false;
input bool   InpPaRequireEngulf = false;

input group "=== Directional Intelligence v6.1 ==="
input bool   InpUseDirectionalIntelligence = true;  // Adds D1/H4 slow trend gate before entry
input bool   InpTrendOnlyMode = true;               // true = only trade with H4 plus D1/H4 slow alignment
input bool   InpBlockShortsInMajorBullTrend = true; // blocks shorts when D1 and H4 slow trend are bullish
input bool   InpBlockLongsInMajorBearTrend  = true; // blocks longs when D1 and H4 slow trend are bearish
input int    InpH4SlowEmaPeriod = 200;              // slow H4 institutional trend filter
input int    InpD1EmaPeriod     = 50;               // daily macro bias filter
input double InpMajorTrendSlopeAtrPct = 0.03;       // EMA slope threshold as fraction of ATR
input int    InpScoreDirectionalAlignment = 3;      // additional confluence score for D1/H4 slow alignment
input bool   InpPrintDirectionalDiagnostics = true; // structured logs for directional blocks


input group "=== Adaptive Confluence Intelligence v6.2 ==="
input bool   InpUseAdaptiveConfluence = true;       // Weighted 0-100 decision engine instead of legacy small integer score
input int    InpAciMinScoreTrending   = 75;         // Minimum score in aligned trend
input int    InpAciMinScoreStrongTrend= 70;         // Minimum score when D1 and H4 slow align with trade
input int    InpAciMinScoreRange      = 90;         // Minimum score when higher TF is neutral/ranging
input int    InpAciMinScoreNormalVol  = 80;         // Minimum score when VolGate=NORMAL
input bool   InpAciSoftBOSInNormalVol = true;       // v6.2: NORMAL vol requires score uplift rather than hard BOS block
input bool   InpAciLogCandidates      = true;       // Writes candidate decisions to Common\Files\SMC_PE_V6_2_candidates.csv
input string InpAciCandidateLogFile   = "SMC_PE_V6_2_candidates.csv";
input int    InpAciWeightHTF          = 25;
input int    InpAciWeightLiquidity    = 20;
input int    InpAciWeightDisplacement = 15;
input int    InpAciWeightFVG          = 15;
input int    InpAciWeightBetterVolume = 10;
input int    InpAciWeightVolatility   = 10;
input int    InpAciWeightSession      = 5;

input group "=== Better Volume Confirmation ==="
input bool   InpUseBetterVolume = true;       // Uses Better_Volume indicator via BetterVolume_Reader.mqh
input bool   InpHardRequireBetterVolume = false; // false recommended; use as score only
input int    InpBVMAPeriod = 100;
input int    InpBVLookback = 20;
input ENUM_APPLIED_VOLUME InpBVVolumeType = VOLUME_TICK;
input int    InpBVSignalLookbackBars = 3;
input double InpBVMinVolumeMARatio = 1.15; // Current closed-bar volume must exceed MA by this ratio for surge score
input bool   InpBVPenalizeWeakVolume = true;
input int    InpBVWeakPenalty = 1;

input group "=== Session (UTC+2) ==="
input bool   InpUseSession      = true;
input int    InpSessionStart    = 9;
input int    InpSessionEnd      = 20;
input bool   InpUseAsianCompression = true;
input int    InpAsianStartHour  = 0;
input int    InpAsianEndHour    = 7;
input double InpAsianMaxAtrMult = 0.85;
input bool   InpUseSessionLiquidity = true;
input int    InpLondonOpenHour  = 9;
input int    InpNYOpenHour      = 15;
input int    InpSessionSweepLookbackBars = 8;

input group "=== Spread / Execution Hygiene ==="
input bool   InpUseSpreadFilter = true;
input int    InpMaxSpreadPoints = 0;     // 0 = auto per symbol profile
input double InpMaxSpreadAtrPct = 0.0;   // 0 = auto per symbol profile
input bool   InpUseStopLevelCheck = true;
input int    InpSlippagePoints  = 30;

input group "=== Manual News / Rollover Blackout UTC+2 ==="
input bool   InpUseManualBlackout = true;
input int    InpBlackout1StartHour = 21;
input int    InpBlackout1StartMin  = 55;
input int    InpBlackout1EndHour   = 22;
input int    InpBlackout1EndMin    = 10;
input int    InpBlackout2StartHour = -1;
input int    InpBlackout2StartMin  = 0;
input int    InpBlackout2EndHour   = -1;
input int    InpBlackout2EndMin    = 0;

input group "=== MT5 Calendar NewsGuard ==="
input bool   InpUseMT5CalendarNews = true;       // Native MT5 economic calendar filter
input bool   InpNewsBlockHighImpact = true;
input bool   InpNewsBlockMediumImpact = false;
input int    InpNewsMinutesBefore = 30;
input int    InpNewsMinutesAfter  = 45;
input int    InpNewsLookaheadHours = 24;
input string InpNewsCurrenciesOverride = "";     // Blank = auto per symbol; examples: "USD" or "USD,EUR"
input string InpNewsKeywordFilter = "CPI,NFP,FOMC,Fed,Powell,PCE,Payroll,Unemployment,Interest Rate,ISM,PMI,GDP,Retail Sales";
input bool   InpNewsKeywordOnly = false;          // false = all high-impact USD/EUR events; true = keywords only
input bool   InpCloseBeforeHighImpactNews = false;
input int    InpCloseBeforeNewsMinutes = 10;

input group "=== Volatility Shock Guard ==="
input bool   InpUseShockGuard = true;
input double InpShockRangeAtrMult = 2.20;         // Closed entry-TF candle range vs ATR
input double InpShockSpreadAtrPct = 0.20;         // Spread vs ATR hard shock level
input int    InpShockCooldownBars = 3;

input group "=== Stop Loss ==="
input bool   InpSlBeyondSwept   = true;
input double InpSlAtrMult       = 1.5;

input group "=== Trade Management ==="
input bool   InpUseBE           = true;
input bool   InpUsePartial      = false;
input double InpPartialRatio    = 0.5;

input group "=== Display ==="
input bool   InpShowDash        = true;
input bool   InpShowPools       = true;
input bool   InpShowFVGs        = true;
input bool   InpDebugGates      = true;   // Print which gate blocks each entry attempt

input group "=== Portfolio Engine v6.0 Stability ==="
input bool   InpRequireTradableSymbol = true;     // Fail closed if chart symbol cannot be traded
input bool   InpUsePortfolioHeatGuard = true;     // Max aggregate engine risk across open positions
input double InpMaxPortfolioRiskPct   = 3.0;      // Total open SL risk cap for this EA magic family
input int    InpPortfolioMagicPrefix  = 260527;   // Magic family prefix used across portfolio charts
input bool   InpShowV6Diagnostics     = true;     // Extra dashboard rows: gate reason, heat, file diagnostics

input group "=== ATHENA Research Platform ==="
input bool   EnableAthena = true;          // Enable ATHENA event/logging framework
input bool   AthenaDebug  = false;         // Print ATHENA logger diagnostics

//+------------------------------------------------------------------+
//| Per-symbol configuration (auto-set in OnInit)                  |
//+------------------------------------------------------------------+
double g_EqualLevelPips  = 15.0;  // Liquidity zone tolerance
double g_SlBufferPips    = 10.0;  // SL buffer beyond swept level
bool   g_IsIndex         = false; // true for DJ30/NAS100 (no pip scaling)
bool   g_IsCrypto        = false;
int    g_ProfileMaxSpreadPoints = 250;
double g_ProfileMaxSpreadAtrPct = 0.12;
int    g_ProfileMinScoreToEnter = 7;
int    g_MagicNumber     = 26052741;

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
CTrade        Trade;
CPositionInfo PosInfo;
CAthenaEventBus AthenaBus;
datetime      g_LastEntryBar = 0;
datetime      g_LastLossCloseTime = 0;
string        g_SymbolLabel  = "";
int           g_DayKey = -1;
double        g_DayStartEquity = 0.0;
int           g_TradesToday = 0;
double        g_LastScoreLong = 0;
double        g_LastScoreShort = 0;
string        g_LastReasonLong = "";
string        g_LastReasonShort = "";
datetime      g_LastNewsCheck = 0;
bool          g_NewsBlockActive = false;
datetime      g_NextNewsTime = 0;
string        g_NextNewsName = "";
string        g_NextNewsCurrency = "";
datetime      g_LastShockTime = 0;
string        g_LastShockReason = "";
CBetterVolumeReader g_BV;
bool          g_BVReady = false;
string        g_LastBVLong = "--";
string        g_LastBVShort = "--";
double        g_LastBVRatio = 0.0;
int           g_H4BiasHandle = INVALID_HANDLE; // Persistent H4 50-EMA handle — created once in OnInit
int           g_H4SlowBiasHandle = INVALID_HANDLE; // v6.1 H4 slow EMA handle
int           g_D1BiasHandle = INVALID_HANDLE;     // v6.1 D1 EMA handle
string        g_LastDirectionalDiag = "--";
string        g_V6_State = "INIT";
string        g_V6_BlockReason = "--";
string        g_V6_LastGate = "--";
double        g_V6_PortfolioHeatPct = 0.0;
bool          g_V6_SymbolTradeOK = false;
int           g_LastAciScoreLong = 0;
int           g_LastAciScoreShort = 0;
int           g_LastAciThresholdLong = 0;
int           g_LastAciThresholdShort = 0;
string        g_LastAciGradeLong = "--";
string        g_LastAciGradeShort = "--";

//+------------------------------------------------------------------+
//| Symbol profile — called in OnInit                              |
//+------------------------------------------------------------------+
void SetProfile(string label,
                int magic,
                double equalPips,
                double slBufferPips,
                bool isIndex,
                bool isCrypto,
                int maxSpreadPoints,
                double maxSpreadAtrPct,
                int minScore,
                string regimeName)
{
   g_SymbolLabel = label;
   g_MagicNumber = magic;
   g_EqualLevelPips = equalPips;
   g_SlBufferPips = slBufferPips;
   g_IsIndex = isIndex;
   g_IsCrypto = isCrypto;
   g_ProfileMaxSpreadPoints = maxSpreadPoints;
   g_ProfileMaxSpreadAtrPct = maxSpreadAtrPct;
   g_ProfileMinScoreToEnter = minScore;
   RG_GlobalVarName = regimeName;
}

bool SymHas(string token)
{
   string s = _Symbol;
   StringToUpper(s);
   string t = token;
   StringToUpper(t);
   return (StringFind(s, t) >= 0);
}


//+------------------------------------------------------------------+
//| v6.0 diagnostics / portfolio safety helpers                      |
//+------------------------------------------------------------------+
string V6_YesNo(bool v){ return v ? "YES" : "NO"; }
string V6_PassFail(bool v){ return v ? "PASS" : "FAIL"; }

void V6_SetState(string state, string reason="--", string gate="--")
{
   g_V6_State       = state;
   g_V6_BlockReason = reason;
   g_V6_LastGate    = gate;
}

bool V6_MagicInFamily(long magic)
{
   string m = IntegerToString((int)magic);
   string p = IntegerToString(InpPortfolioMagicPrefix);
   return (StringFind(m, p) == 0);
}

bool V6_SymbolTradeAllowed(string &reason)
{
   if(!InpRequireTradableSymbol) return true;
   ResetLastError();
   if(!SymbolSelect(_Symbol, true))
   {
      reason = StringFormat("SymbolSelect failed err=%d", GetLastError());
      return false;
   }
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED)
   {
      reason = "symbol trade mode disabled";
      return false;
   }
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
   {
      reason = StringFormat("bad quote ask=%.5f bid=%.5f", ask, bid);
      return false;
   }
   return true;
}

// Estimate current open SL risk for all positions in this EA magic family.
double V6_EstimatePortfolioHeatPct()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal <= 0.0) return 0.0;

   double riskMoney = 0.0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      long magic = (long)PosInfo.Magic();
      if(!V6_MagicInFamily(magic)) continue;

      string sym = PosInfo.Symbol();
      double sl  = PosInfo.StopLoss();
      double op  = PosInfo.PriceOpen();
      double vol = PosInfo.Volume();
      if(sl <= 0.0 || op <= 0.0 || vol <= 0.0) continue;

      double tickVal = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tickSz  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tickVal <= 0.0 || tickSz <= 0.0) continue;

      double dist = MathAbs(op - sl);
      riskMoney += (dist / tickSz) * tickVal * vol;
   }
   return (riskMoney / bal) * 100.0;
}

bool V6_PortfolioHeatOK(string &reason)
{
   g_V6_PortfolioHeatPct = V6_EstimatePortfolioHeatPct();
   if(!InpUsePortfolioHeatGuard) return true;
   if(InpMaxPortfolioRiskPct <= 0.0) return true;
   if(g_V6_PortfolioHeatPct >= InpMaxPortfolioRiskPct)
   {
      reason = StringFormat("portfolio heat %.2f%% >= max %.2f%%", g_V6_PortfolioHeatPct, InpMaxPortfolioRiskPct);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Symbol profile — called in OnInit                               |
//| Magic-number family V4: 2605274x / 2605275x                      |
//+------------------------------------------------------------------+
void ConfigureSymbolProfile()
{
   string sym = _Symbol;

   // --- Metals
   if(SymHas("XAUUSD") || SymHas("GOLD"))
      SetProfile("XAUUSD", 26052741, 15.0, 10.0, false, false, 250, 0.12, 7, "XAUUSD_Regime");
   else if(SymHas("XAGUSD") || SymHas("SILVER"))
      SetProfile("XAGUSD", 26052742, 8.0, 5.0, false, false, 180, 0.14, 7, "XAGUSD_Regime");

   // --- Major FX
   else if(SymHas("EURUSD"))
      SetProfile("EURUSD", 26052743, 5.0, 3.0, false, false, 45, 0.08, 7, "EURUSD_Regime");
   else if(SymHas("GBPUSD"))
      SetProfile("GBPUSD", 26052744, 6.0, 4.0, false, false, 55, 0.09, 7, "GBPUSD_Regime");
   else if(SymHas("USDJPY"))
      SetProfile("USDJPY", 26052745, 6.0, 4.0, false, false, 55, 0.09, 7, "USDJPY_Regime");
   else if(SymHas("GBPJPY"))
      SetProfile("GBPJPY", 26052746, 8.0, 6.0, false, false, 75, 0.10, 8, "GBPJPY_Regime");
   else if(SymHas("EURJPY"))
      SetProfile("EURJPY", 26052747, 7.0, 5.0, false, false, 65, 0.10, 7, "EURJPY_Regime");
   else if(SymHas("AUDUSD"))
      SetProfile("AUDUSD", 26052748, 5.0, 3.0, false, false, 50, 0.09, 7, "AUDUSD_Regime");
   else if(SymHas("USDCAD"))
      SetProfile("USDCAD", 26052749, 6.0, 4.0, false, false, 60, 0.10, 7, "USDCAD_Regime");

   // --- US equity indices / CFDs.  Broker names vary, so match common aliases.
   else if(SymHas("NAS100") || SymHas("US100") || SymHas("USTEC") || SymHas("NASDAQ"))
      SetProfile("NAS100", 26052751, 35.0, 25.0, true, false, 350, 0.10, 8, "NAS100_Regime");
   else if(SymHas("US500") || SymHas("SP500") || SymHas("SPX500") || SymHas("S&P"))
      SetProfile("US500", 26052752, 18.0, 12.0, true, false, 180, 0.10, 8, "US500_Regime");
   else if(SymHas("DJ30") || SymHas("US30") || SymHas("DOW") || SymHas("WS30"))
      SetProfile("DJ30", 26052753, 45.0, 30.0, true, false, 450, 0.10, 8, "DJ30_Regime");
   else if(SymHas("GER40") || SymHas("DE40") || SymHas("DAX"))
      SetProfile("GER40", 26052754, 30.0, 20.0, true, false, 300, 0.10, 8, "GER40_Regime");
   else if(SymHas("UK100") || SymHas("FTSE"))
      SetProfile("UK100", 26052755, 20.0, 14.0, true, false, 220, 0.11, 8, "UK100_Regime");

   // --- Crypto CFDs
   else if(SymHas("BTCUSD") || SymHas("BITCOIN"))
      SetProfile("BTCUSD", 26052756, 120.0, 80.0, false, true, 2500, 0.16, 8, "BTCUSD_Regime");
   else if(SymHas("ETHUSD") || SymHas("ETHEREUM"))
      SetProfile("ETHUSD", 26052757, 35.0, 25.0, false, true, 800, 0.16, 8, "ETHUSD_Regime");

   // --- Generic fallback
   else
   {
      SetProfile(sym, 26052759, 10.0, 8.0, false, false, 250, 0.12, 8, sym + "_Regime");
      PrintFormat("SMC_MultiAsset_NewsGuard_V4: Unknown symbol '%s' — using generic profile. Add a dedicated profile before live use.", sym);
   }

   // Manual overrides take priority
   if(InpLmEqualPipsOverride  > 0) g_EqualLevelPips = InpLmEqualPipsOverride;
   if(InpSlBufferPipsOverride > 0) g_SlBufferPips   = InpSlBufferPipsOverride;
}

//+------------------------------------------------------------------+
//| Price distance — handles both forex/gold (pip-based)           |
//| and indices (point-based, no pip scaling)                      |
//+------------------------------------------------------------------+
double PriceDist(double a, double b)
{
   return MathAbs(a - b);
}

// Convert pips to price (forex/metals only — indices skip this)
double PipsToSLBuffer()
{
   if(g_IsIndex) return g_SlBufferPips * _Point * 10.0; // treat as "index points"
   return g_SlBufferPips * _Point * 10.0;
}

// Minimum SL distance sanity check (in price units)
double MinSLPrice()
{
   // Indices: use 500 points minimum — 50 is negligible for DJ30 (0.5 price units)
   // and would pass virtually any SL through, defeating the sanity check entirely.
   // Forex/metals/crypto: 50 points is appropriate.
   if(g_IsIndex) return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 500;
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;
}


//+------------------------------------------------------------------+
//| Date / risk / execution helper functions                         |
//+------------------------------------------------------------------+
int MakeDayKey(datetime when)
{
   MqlDateTime t; TimeToStruct(when, t);
   return t.year*10000 + t.mon*100 + t.day;
}

int MinutesOfDay(datetime when)
{
   MqlDateTime t; TimeToStruct(when, t);
   return t.hour*60 + t.min;
}

bool TimeWindowActive(int sh, int sm, int eh, int em)
{
   if(sh < 0 || eh < 0) return false;
   int now = MinutesOfDay(TimeCurrent());
   int a = sh*60 + sm;
   int b = eh*60 + em;
   if(a == b) return false;
   if(a < b) return (now >= a && now <= b);
   return (now >= a || now <= b);
}

bool InManualBlackout()
{
   if(!InpUseManualBlackout) return false;
   if(TimeWindowActive(InpBlackout1StartHour, InpBlackout1StartMin, InpBlackout1EndHour, InpBlackout1EndMin)) return true;
   if(TimeWindowActive(InpBlackout2StartHour, InpBlackout2StartMin, InpBlackout2EndHour, InpBlackout2EndMin)) return true;
   return false;
}

string TrimString(string text)
{
   StringTrimLeft(text);
   StringTrimRight(text);
   return text;
}

string AutoNewsCurrencies()
{
   if(StringLen(TrimString(InpNewsCurrenciesOverride)) > 0) return InpNewsCurrenciesOverride;

   // Metals and crypto are priced primarily against USD macro/liquidity.
   if(SymHas("XAUUSD") || SymHas("GOLD") || SymHas("XAGUSD") || SymHas("SILVER")) return "USD";
   if(SymHas("BTCUSD") || SymHas("ETHUSD") || SymHas("CRYPTO")) return "USD";

   // FX majors / crosses.
   if(SymHas("EURUSD")) return "EUR,USD";
   if(SymHas("GBPUSD")) return "GBP,USD";
   if(SymHas("USDJPY")) return "USD,JPY";
   if(SymHas("GBPJPY")) return "GBP,JPY";
   if(SymHas("EURJPY")) return "EUR,JPY";
   if(SymHas("AUDUSD")) return "AUD,USD";
   if(SymHas("USDCAD")) return "USD,CAD";
   if(SymHas("NZDUSD")) return "NZD,USD";
   if(SymHas("USDCHF")) return "USD,CHF";

   // Equity indices.
   if(SymHas("NAS100") || SymHas("US100") || SymHas("USTEC") || SymHas("NASDAQ") ||
      SymHas("US500") || SymHas("SP500") || SymHas("SPX500") || SymHas("DJ30") ||
      SymHas("US30") || SymHas("DOW") || SymHas("WS30")) return "USD";
   if(SymHas("GER40") || SymHas("DE40") || SymHas("DAX")) return "EUR,USD";
   if(SymHas("UK100") || SymHas("FTSE")) return "GBP,USD";

   return "USD";
}

bool TextContainsKeyword(string text, string csv)
{
   string lower = text;
   StringToLower(lower);
   string keys[];
   int n = StringSplit(csv, ',', keys);
   if(n <= 0) return false;
   for(int i=0; i<n; i++)
   {
      string k = TrimString(keys[i]);
      StringToLower(k);
      if(StringLen(k) > 0 && StringFind(lower, k) >= 0) return true;
   }
   return false;
}

bool ImpactAllowed(const MqlCalendarEvent &event)
{
   int imp = (int)event.importance;
   // MT5 enum normally maps low=1, moderate=2, high=3.
   if(InpNewsBlockHighImpact && imp >= 3) return true;
   if(InpNewsBlockMediumImpact && imp >= 2) return true;
   return false;
}

bool CalendarEventQualifies(const MqlCalendarEvent &event)
{
   if(!ImpactAllowed(event)) return false;
   if(InpNewsKeywordOnly && !TextContainsKeyword(event.name, InpNewsKeywordFilter)) return false;
   if(!InpNewsKeywordOnly && StringLen(TrimString(InpNewsKeywordFilter)) > 0)
   {
      // Always allow high-impact events, and allow medium-impact events only if keyword matched unless explicitly broad medium filtering is wanted.
      int imp = (int)event.importance;
      if(imp >= 3) return true;
      if(InpNewsBlockMediumImpact) return TextContainsKeyword(event.name, InpNewsKeywordFilter);
   }
   return true;
}

void UpdateCalendarNewsState()
{
   if(!InpUseMT5CalendarNews)
   {
      g_NewsBlockActive = false;
      g_NextNewsTime = 0;
      g_NextNewsName = "";
      g_NextNewsCurrency = "";
      return;
   }

   datetime now = TimeCurrent();
   if(g_LastNewsCheck > 0 && now - g_LastNewsCheck < 60) return;
   g_LastNewsCheck = now;

   g_NewsBlockActive = false;
   g_NextNewsTime = 0;
   g_NextNewsName = "";
   g_NextNewsCurrency = "";

   datetime from = now - InpNewsMinutesAfter * 60;
   datetime to   = now + MathMax(1, InpNewsLookaheadHours) * 3600;
   string currs[];
   int cnum = StringSplit(AutoNewsCurrencies(), ',', currs);

   for(int c=0; c<cnum; c++)
   {
      string cur = TrimString(currs[c]);
      if(StringLen(cur) < 3) continue;

      MqlCalendarValue values[];
      ResetLastError();
      int total = CalendarValueHistory(values, from, to, "", cur);
      if(total <= 0) continue;

      for(int i=0; i<total; i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev)) continue;
         if(!CalendarEventQualifies(ev)) continue;

         datetime et = values[i].time;
         if(et <= 0) continue;

         if(et >= now && (g_NextNewsTime == 0 || et < g_NextNewsTime))
         {
            g_NextNewsTime = et;
            g_NextNewsName = ev.name;
            g_NextNewsCurrency = cur;
         }

         if(now >= et - InpNewsMinutesBefore * 60 && now <= et + InpNewsMinutesAfter * 60)
         {
            g_NewsBlockActive = true;
            g_NextNewsTime = et;
            g_NextNewsName = ev.name;
            g_NextNewsCurrency = cur;
            return;
         }
      }
   }
}

string NewsStatusText()
{
   UpdateCalendarNewsState();
   if(!InpUseMT5CalendarNews) return "Calendar OFF";
   if(g_NewsBlockActive) return StringFormat("BLOCK %s %s", g_NextNewsCurrency, g_NextNewsName);
   if(g_NextNewsTime > 0)
   {
      int mins = (int)MathMax(0, (g_NextNewsTime - TimeCurrent()) / 60);
      return StringFormat("Next %s in %dm: %s", g_NextNewsCurrency, mins, g_NextNewsName);
   }
   return "No event found";
}

bool CalendarNewsBlocked(string &reason)
{
   UpdateCalendarNewsState();
   if(!g_NewsBlockActive) return false;
   reason = StringFormat("MT5 calendar blackout: %s %s", g_NextNewsCurrency, g_NextNewsName);
   return true;
}

bool ShockGuardBlocked(string &reason)
{
   if(!InpUseShockGuard) return false;
   double atr = LM_GetATR(_Symbol, InpEntryTF, 14);
   if(atr <= 0.0) return false;

   double prevRange = iHigh(_Symbol, InpEntryTF, 1) - iLow(_Symbol, InpEntryTF, 1);
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime prevBarTime = iTime(_Symbol, InpEntryTF, 1);

   if(prevRange > atr * InpShockRangeAtrMult)
   {
      g_LastShockTime = prevBarTime;
      g_LastShockReason = StringFormat("range shock %.2fx ATR", prevRange / atr);
   }
   if(spread > atr * InpShockSpreadAtrPct)
   {
      g_LastShockTime = TimeCurrent();
      g_LastShockReason = StringFormat("spread shock %.2f%% ATR", spread / atr * 100.0);
   }

   if(g_LastShockTime > 0)
   {
      int shift = iBarShift(_Symbol, InpEntryTF, g_LastShockTime, false);
      if(shift >= 0 && shift <= InpShockCooldownBars)
      {
         reason = StringFormat("volatility shock guard active: %s, bars since=%d", g_LastShockReason, shift);
         return true;
      }
   }
   return false;
}

void ClosePositionsBeforeNews()
{
   if(!InpUseMT5CalendarNews || !InpCloseBeforeHighImpactNews) return;
   UpdateCalendarNewsState();
   if(g_NextNewsTime <= 0) return;
   int mins = (int)((g_NextNewsTime - TimeCurrent()) / 60);
   if(mins < 0 || mins > InpCloseBeforeNewsMinutes) return;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!PosInfo.SelectByIndex(i)) continue;
      if(PosInfo.Symbol()!=_Symbol) continue;
      if(PosInfo.Magic()!=(ulong)g_MagicNumber) continue;
      PrintFormat("NEWS EXIT [%s] Closing before %s %s in %d min", g_SymbolLabel, g_NextNewsCurrency, g_NextNewsName, mins);
      Trade.PositionClose(PosInfo.Ticket());
   }
}

void UpdateDailyStats()
{
   int k = MakeDayKey(TimeCurrent());
   if(k != g_DayKey)
   {
      g_DayKey = k;
      // Use balance (not equity) so open floating positions at midnight don't
      // distort the daily drawdown baseline — equity can spike/dip on rollover.
      g_DayStartEquity = AccountInfoDouble(ACCOUNT_BALANCE);
      g_TradesToday = 0;
   }
}

double CurrentDailyDDPct()
{
   if(g_DayStartEquity <= 0.0) return 0.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   return MathMax(0.0, (g_DayStartEquity - eq) / g_DayStartEquity * 100.0);
}

bool DailyRiskBlocked(string &reason)
{
   UpdateDailyStats();
   double dd = CurrentDailyDDPct();
   if(InpMaxTradesPerDay > 0 && g_TradesToday >= InpMaxTradesPerDay)
   {
      reason = StringFormat("daily trade limit reached %d/%d", g_TradesToday, InpMaxTradesPerDay);
      return true;
   }
   if(InpMaxDailyLossPct > 0.0 && dd >= InpMaxDailyLossPct)
   {
      reason = StringFormat("daily loss brake active %.2f%% >= %.2f%%", dd, InpMaxDailyLossPct);
      return true;
   }
   if(InpStopTradingDDPct > 0.0 && dd >= InpStopTradingDDPct)
   {
      reason = StringFormat("hard DD stop active %.2f%% >= %.2f%%", dd, InpStopTradingDDPct);
      return true;
   }
   return false;
}

double CurrentRiskPct()
{
   double dd = CurrentDailyDDPct();
   if(InpReduceRiskDDPct > 0.0 && dd >= InpReduceRiskDDPct) return InpReducedRiskPct;
   return InpRiskPct;
}

bool SpreadOK(string &reason)
{
   if(!InpUseSpreadFilter) return true;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPrice = ask - bid;
   double spreadPoints = spreadPrice / _Point;
   int maxSpreadPts = (InpMaxSpreadPoints > 0 ? InpMaxSpreadPoints : g_ProfileMaxSpreadPoints);
   double maxSpreadAtr = (InpMaxSpreadAtrPct > 0.0 ? InpMaxSpreadAtrPct : g_ProfileMaxSpreadAtrPct);
   if(maxSpreadPts > 0 && spreadPoints > maxSpreadPts)
   {
      reason = StringFormat("spread %.0f pts > profile max %d", spreadPoints, maxSpreadPts);
      return false;
   }
   double atr = LM_GetATR(_Symbol, InpEntryTF, 14);
   if(atr > 0.0 && maxSpreadAtr > 0.0 && spreadPrice > atr * maxSpreadAtr)
   {
      reason = StringFormat("spread %.5f > %.2f x ATR %.5f", spreadPrice, maxSpreadAtr, atr);
      return false;
   }
   return true;
}

bool StopLevelOK(int direction, double entry, double sl, double tp, string &reason)
{
   if(!InpUseStopLevelCheck) return true;
   long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist = (double)MathMax(stops, freeze) * _Point;
   if(minDist <= 0.0) return true;
   if(MathAbs(entry - sl) < minDist)
   {
      reason = StringFormat("SL inside broker stop/freeze level %.5f < %.5f", MathAbs(entry-sl), minDist);
      return false;
   }
   if(MathAbs(entry - tp) < minDist)
   {
      reason = StringFormat("TP inside broker stop/freeze level %.5f < %.5f", MathAbs(entry-tp), minDist);
      return false;
   }
   if(direction == 1 && (sl >= entry || tp <= entry)) { reason = "invalid long SL/TP side"; return false; }
   if(direction ==-1 && (sl <= entry || tp >= entry)) { reason = "invalid short SL/TP side"; return false; }
   return true;
}

bool GetTimedRange(datetime dayTime, int startHour, int endHour, double &hi, double &lo)
{
   hi = 0.0; lo = DBL_MAX;
   int key = MakeDayKey(dayTime);
   int bars = MathMin(300, Bars(_Symbol, InpEntryTF));
   for(int i=0; i<bars; i++)
   {
      datetime bt = iTime(_Symbol, InpEntryTF, i);
      if(MakeDayKey(bt) != key) continue;
      MqlDateTime t; TimeToStruct(bt, t);
      bool inWindow = false;
      if(startHour < endHour) inWindow = (t.hour >= startHour && t.hour < endHour);
      else if(startHour > endHour) inWindow = (t.hour >= startHour || t.hour < endHour);
      if(!inWindow) continue;
      hi = MathMax(hi, iHigh(_Symbol, InpEntryTF, i));
      lo = MathMin(lo, iLow(_Symbol, InpEntryTF, i));
   }
   return (hi > 0.0 && lo < DBL_MAX && hi > lo);
}

bool AsianCompressionOK()
{
   if(!InpUseAsianCompression) return false;
   double hi, lo;
   if(!GetTimedRange(TimeCurrent(), InpAsianStartHour, InpAsianEndHour, hi, lo)) return false;
   double atr = LM_GetATR(_Symbol, PERIOD_H1, 14);
   if(atr <= 0.0) return false;
   return ((hi - lo) <= atr * InpAsianMaxAtrMult);
}

bool RecentLevelSweep(double level, int direction, int barsBack)
{
   if(level <= 0.0) return false;
   int bars = MathMin(barsBack, Bars(_Symbol, InpEntryTF)-2);
   for(int i=1; i<=bars; i++)
   {
      double h = iHigh(_Symbol, InpEntryTF, i);
      double l = iLow(_Symbol, InpEntryTF, i);
      double c = iClose(_Symbol, InpEntryTF, i);
      if(direction == 1 && l < level && c > level) return true;
      if(direction ==-1 && h > level && c < level) return true;
   }
   return false;
}

bool GetPreviousDayHL(double &hi, double &lo)
{
   hi = iHigh(_Symbol, PERIOD_D1, 1);
   lo = iLow(_Symbol, PERIOD_D1, 1);
   return (hi > 0.0 && lo > 0.0 && hi > lo);
}

bool GetPreviousWeekHL(double &hi, double &lo)
{
   hi = iHigh(_Symbol, PERIOD_W1, 1);
   lo = iLow(_Symbol, PERIOD_W1, 1);
   return (hi > 0.0 && lo > 0.0 && hi > lo);
}

bool SessionLiquidityConfluence(int direction)
{
   if(!InpUseSessionLiquidity) return false;
   double hi, lo;
   if(GetPreviousDayHL(hi, lo))
   {
      if(direction == 1 && RecentLevelSweep(lo, direction, InpSessionSweepLookbackBars)) return true;
      if(direction ==-1 && RecentLevelSweep(hi, direction, InpSessionSweepLookbackBars)) return true;
   }
   if(GetPreviousWeekHL(hi, lo))
   {
      if(direction == 1 && RecentLevelSweep(lo, direction, InpSessionSweepLookbackBars)) return true;
      if(direction ==-1 && RecentLevelSweep(hi, direction, InpSessionSweepLookbackBars)) return true;
   }
   if(GetTimedRange(TimeCurrent(), InpAsianStartHour, InpAsianEndHour, hi, lo))
   {
      if(direction == 1 && RecentLevelSweep(lo, direction, InpSessionSweepLookbackBars)) return true;
      if(direction ==-1 && RecentLevelSweep(hi, direction, InpSessionSweepLookbackBars)) return true;
   }
   return false;
}

bool CooldownOK(string &reason)
{
   if(InpCooldownBarsAfterLoss <= 0 || g_LastLossCloseTime <= 0) return true;
   datetime curBar = iTime(_Symbol, InpEntryTF, 0);
   int shift = iBarShift(_Symbol, InpEntryTF, g_LastLossCloseTime, false);
   if(shift >= 0 && shift <= InpCooldownBarsAfterLoss)
   {
      reason = StringFormat("cooldown after loss active, bars since loss=%d", shift);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Lot calculation using price-distance SL                        |
//+------------------------------------------------------------------+
double CalcLots(double slPrice)
{
   if(slPrice <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double bal     = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk    = bal * CurrentRiskPct() / 100.0;
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double ptVal   = tickVal / tickSz;
   if(ptVal <= 0)  return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   // slPrice is in price units; convert to ticks
   double slTicks = slPrice / tickSz;
   double lots    = risk / (slTicks * tickVal);
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   lots = MathFloor(lots / step) * step;

   // --- Minimum-lot risk guard ---
   // On instruments with large contract sizes relative to account balance
   // (e.g. XAGUSD 5000oz, XAUUSD at small balance), the mathematically
   // correct lot falls below SYMBOL_VOLUME_MIN.  Without this guard the
   // EA silently snaps to minLot and trades at a multiple of the intended
   // risk -- 4-8% effective exposure when the input says 0.5%.
   // If the minimum lot costs more than InpMinLotRiskMult x target risk,
   // block the trade entirely and log the reason.
   if(InpMinLotRiskMult > 0.0)
   {
      double minLotRiskPct = (slTicks * tickVal * minLot) / bal * 100.0;
      double threshold     = CurrentRiskPct() * InpMinLotRiskMult;
      if(minLotRiskPct > threshold)
      {
         PrintFormat("RISK BLOCK [%s]: min lot %.2f costs %.2f%% equity (target %.2f%% x mult %.1f = %.2f%%) -- trade skipped",
                     g_SymbolLabel, minLot, minLotRiskPct, CurrentRiskPct(), InpMinLotRiskMult, threshold);
         return 0.0; // caller receives 0 -> trade execution path rejects
      }
   }

   return MathMax(minLot, MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), lots));
}

//+------------------------------------------------------------------+
//| Session filter                                                  |
//+------------------------------------------------------------------+
bool InSession()
{
   if(!InpUseSession) return true;
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   return (t.hour >= InpSessionStart && t.hour < InpSessionEnd);
}

//+------------------------------------------------------------------+
//| Open trade count for this symbol + magic                       |
//+------------------------------------------------------------------+
int OpenTradeCount()
{
   int n = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
      if(PosInfo.SelectByIndex(i) && PosInfo.Symbol()==_Symbol && PosInfo.Magic()==(ulong)g_MagicNumber)
         n++;
   return n;
}

//+------------------------------------------------------------------+
//| H4 Structural Bias                                             |
//| Primary:   50 EMA slope on H4 (fast, works in strong trends)  |
//| Secondary: HH/HL or LH/LL swing structure confirmation        |
//| Returns 1=bull, -1=bear, 0=neutral                            |
//+------------------------------------------------------------------+
int GetH4Bias()
{
   // --- Primary: 50 EMA slope
   // Uses g_H4BiasHandle created once in OnInit — no per-tick handle allocation.
   if(g_H4BiasHandle != INVALID_HANDLE)
   {
      double ema[];
      if(CopyBuffer(g_H4BiasHandle, 0, 0, 3, ema) == 3)
      {
         // EMA sloping up = bull, down = bear
         // Use 3-bar slope to avoid noise
         double slope = ema[0] - ema[2];
         double atr   = LM_GetATR(_Symbol, PERIOD_H4, 14);
         double threshold = atr * 0.05; // Must slope by at least 5% of ATR to count

         if(slope >  threshold) return  1;
         if(slope < -threshold) return -1;
         return 0;
      }
   }

   // --- Fallback: swing structure HH/HL or LH/LL
   int bars = InpStructLookback;
   double sh1=0,sh2=0,sl1=0,sl2=0;
   int shc=0,slc=0;
   for(int i=InpStructSwing; i<bars-InpStructSwing && (shc<2||slc<2); i++)
   {
      bool swH=true,swL=true;
      for(int j=1; j<=InpStructSwing; j++)
      {
         if(iHigh(_Symbol,PERIOD_H4,i-j)>=iHigh(_Symbol,PERIOD_H4,i)||
            iHigh(_Symbol,PERIOD_H4,i+j)>=iHigh(_Symbol,PERIOD_H4,i)) swH=false;
         if(iLow(_Symbol,PERIOD_H4,i-j) <=iLow(_Symbol,PERIOD_H4,i)||
            iLow(_Symbol,PERIOD_H4,i+j) <=iLow(_Symbol,PERIOD_H4,i))  swL=false;
      }
      if(swH&&shc<2){ if(shc==0)sh1=iHigh(_Symbol,PERIOD_H4,i);else sh2=iHigh(_Symbol,PERIOD_H4,i);shc++; }
      if(swL&&slc<2){ if(slc==0)sl1=iLow(_Symbol,PERIOD_H4,i); else sl2=iLow(_Symbol,PERIOD_H4,i); slc++; }
   }
   if(shc<2||slc<2) return 0;
   if(sh1>sh2&&sl1>sl2) return  1;
   if(sh1<sh2&&sl1<sl2) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| v6.1 EMA bias helper                                            |
//| Returns 1=bull, -1=bear, 0=neutral/unknown                      |
//+------------------------------------------------------------------+
int BiasFromEmaHandle(int handle, ENUM_TIMEFRAMES tf)
{
   if(handle == INVALID_HANDLE) return 0;

   double ema[];
   ArraySetAsSeries(ema, true);
   if(CopyBuffer(handle, 0, 0, 4, ema) < 4) return 0;

   double atr = LM_GetATR(_Symbol, tf, 14);
   double threshold = atr * InpMajorTrendSlopeAtrPct;
   double slope = ema[0] - ema[3];
   double close1 = iClose(_Symbol, tf, 1);

   if(close1 > ema[1] && slope >  threshold) return  1;
   if(close1 < ema[1] && slope < -threshold) return -1;
   return 0;
}

int GetH4SlowBias()
{
   return BiasFromEmaHandle(g_H4SlowBiasHandle, PERIOD_H4);
}

int GetD1Bias()
{
   return BiasFromEmaHandle(g_D1BiasHandle, PERIOD_D1);
}

string BiasText(int b)
{
   if(b > 0) return "Bull";
   if(b < 0) return "Bear";
   return "Neutral";
}

bool DirectionalAlignmentOK(int direction)
{
   int h4 = GetH4Bias();
   int h4s = GetH4SlowBias();
   int d1 = GetD1Bias();
   return (h4 == direction && (h4s == direction || d1 == direction));
}

bool DirectionalPermissionOK(int direction, string &reason)
{
   reason = "";
   if(!InpUseDirectionalIntelligence)
   {
      g_LastDirectionalDiag = "OFF";
      return true;
   }

   int h4  = GetH4Bias();
   int h4s = GetH4SlowBias();
   int d1  = GetD1Bias();
   string dir = direction == 1 ? "LONG" : "SHORT";
   g_LastDirectionalDiag = StringFormat("Dir=%s H4=%s H4Slow=%s D1=%s", dir, BiasText(h4), BiasText(h4s), BiasText(d1));

   // Strong major-trend protection: this specifically stops repeated shorts into a dominant gold uptrend.
   if(direction == -1 && InpBlockShortsInMajorBullTrend && h4s == 1 && d1 == 1)
   {
      reason = StringFormat("Directional block SHORT: major trend bullish | %s", g_LastDirectionalDiag);
      return false;
   }
   if(direction == 1 && InpBlockLongsInMajorBearTrend && h4s == -1 && d1 == -1)
   {
      reason = StringFormat("Directional block LONG: major trend bearish | %s", g_LastDirectionalDiag);
      return false;
   }

   // Trend-only mode requires immediate H4 direction plus at least one higher alignment filter.
   if(InpTrendOnlyMode && !DirectionalAlignmentOK(direction))
   {
      reason = StringFormat("Directional trend-only block | %s", g_LastDirectionalDiag);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Premium / Discount zone                                        |
//| Uses recent 20-bar H4 range so strong trends don't permanently |
//| block entries. In a trend the range shifts with price.         |
//+------------------------------------------------------------------+
bool InPDZone(int direction)
{
   // Use a shorter recent window — 20 H4 bars = ~3 days
   // This means the equilibrium tracks the recent swing, not the full trend
   int lookback = 20;
   double hi=0, lo=DBL_MAX;
   for(int i=0; i<lookback; i++)
   {
      hi = MathMax(hi, iHigh(_Symbol, PERIOD_H4, i));
      lo = MathMin(lo, iLow(_Symbol,  PERIOD_H4, i));
   }
   double eq  = (hi + lo) * 0.5;
   double mid = (SymbolInfoDouble(_Symbol,SYMBOL_ASK) + SymbolInfoDouble(_Symbol,SYMBOL_BID)) * 0.5;
   double rng = hi - lo;

   // In a very strong trend the range can be small — give 60/40 split
   // rather than strict 50/50 to avoid blocking trend-continuation entries
   if(direction ==  1) return (mid < lo + rng * 0.6); // Lower 60% = discount
   if(direction == -1) return (mid > lo + rng * 0.4); // Upper 60% = premium
   return false;
}

//+------------------------------------------------------------------+
//| Minor BOS on entry TF                                          |
//+------------------------------------------------------------------+
bool MinorBOS(int direction)
{
   double close=iClose(_Symbol,InpEntryTF,1);
   if(direction==1)
   {
      double swH=0;
      for(int i=2;i<=10;i++) swH=MathMax(swH,iHigh(_Symbol,InpEntryTF,i));
      return (close>swH);
   }
   if(direction==-1)
   {
      double swL=DBL_MAX;
      for(int i=2;i<=10;i++) swL=MathMin(swL,iLow(_Symbol,InpEntryTF,i));
      return (close<swL);
   }
   return false;
}

//+------------------------------------------------------------------+
//| Engulfing candle                                               |
//+------------------------------------------------------------------+
bool IsEngulfing(int direction)
{
   double o1=iOpen(_Symbol,InpEntryTF,1),c1=iClose(_Symbol,InpEntryTF,1);
   double o2=iOpen(_Symbol,InpEntryTF,2),c2=iClose(_Symbol,InpEntryTF,2);
   if(direction== 1) return (c1>o1&&c2<o2&&c1>o2&&o1<c2);
   if(direction==-1) return (c1<o1&&c2>o2&&c1<o2&&o1>c2);
   return false;
}


//+------------------------------------------------------------------+
//| Better Volume participation / climax scoring                     |
//+------------------------------------------------------------------+
bool BetterVolumeReady()
{
   return (InpUseBetterVolume && g_BVReady);
}

string BetterVolumeStatusText()
{
   if(!InpUseBetterVolume) return "OFF";
   if(!g_BVReady) return "NOT READY / indicator missing";
   ENUM_BV_SIGNAL sig = g_BV.GetSignal(1);
   double v  = g_BV.GetVolume(1);
   double ma = g_BV.GetVolumeMA(1);
   double r  = (ma > 0.0 ? v / ma : 0.0);
   return StringFormat("%s r=%.2f", CBetterVolumeReader::SignalName(sig), r);
}

bool BetterVolumeConfluence(int direction, int &scoreAdd, string &detail)
{
   scoreAdd = 0;
   detail = "";

   if(!InpUseBetterVolume)
   {
      detail = "BV off";
      return true;
   }

   if(!g_BVReady)
   {
      detail = "BV not ready";
      return false;
   }

   ENUM_BV_SIGNAL sig = g_BV.GetSignal(1);
   double v  = g_BV.GetVolume(1);
   double ma = g_BV.GetVolumeMA(1);
   double ratio = (ma > 0.0 ? v / ma : 0.0);
   g_LastBVRatio = ratio;

   bool climaxWithDirection = false;
   bool recentClimax = false;
   bool churn = g_BV.IsChurn(1);
   bool surge = (ratio >= InpBVMinVolumeMARatio);
   bool weak  = g_BV.IsWeak(1);

   if(direction == 1)
   {
      // For longs, useful participation is sell climax / climax churn after sell-side raid,
      // or strong volume on bullish displacement/BOS.
      climaxWithDirection = (sig == BV_SELL_CLIMAX || sig == BV_CLIMAX_CHURN);
      recentClimax = g_BV.SignalWithin(BV_SELL_CLIMAX, InpBVSignalLookbackBars) ||
                     g_BV.SignalWithin(BV_CLIMAX_CHURN, InpBVSignalLookbackBars);
   }
   else
   {
      // For shorts, useful participation is buy climax / climax churn after buy-side raid,
      // or strong volume on bearish displacement/BOS.
      climaxWithDirection = (sig == BV_BUY_CLIMAX || sig == BV_CLIMAX_CHURN);
      recentClimax = g_BV.SignalWithin(BV_BUY_CLIMAX, InpBVSignalLookbackBars) ||
                     g_BV.SignalWithin(BV_CLIMAX_CHURN, InpBVSignalLookbackBars);
   }

   if(climaxWithDirection)
   {
      scoreAdd += InpScoreBetterVolume;
      detail += "+BVClimax ";
   }
   else if(recentClimax)
   {
      scoreAdd += MathMax(1, InpScoreBetterVolume - 1);
      detail += "+BVRecentClimax ";
   }

   if(surge)
   {
      scoreAdd += 1;
      detail += "+BVSurge ";
   }

   if(churn)
   {
      scoreAdd += 1;
      detail += "+BVChurn ";
   }

   if(InpBVPenalizeWeakVolume && weak)
   {
      scoreAdd -= InpBVWeakPenalty;
      detail += "-BVWeak ";
   }

   if(scoreAdd < 0) scoreAdd = 0;
   if(detail == "") detail = StringFormat("BV neutral %s r=%.2f", CBetterVolumeReader::SignalName(sig), ratio);
   else detail += StringFormat("(%s r=%.2f) ", CBetterVolumeReader::SignalName(sig), ratio);

   if(direction == 1) g_LastBVLong = detail;
   else               g_LastBVShort = detail;

   return (scoreAdd > 0 || !InpHardRequireBetterVolume);
}

//+------------------------------------------------------------------+
//| Stop loss                                                      |
//+------------------------------------------------------------------+
double CalcSL(int direction)
{
   double atr = LM_GetATR(_Symbol,InpEntryTF,14);
   if(InpSlBeyondSwept && g_LM_SweepActive && g_LM_LastSweep.confirmed)
   {
      double buf = PipsToSLBuffer();
      if(direction== 1) return g_LM_LastSweep.sweptLevel - buf;
      if(direction==-1) return g_LM_LastSweep.sweptLevel + buf;
   }
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(direction== 1) return bid - atr*InpSlAtrMult;
   if(direction==-1) return ask + atr*InpSlAtrMult;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Take profit                                                    |
//+------------------------------------------------------------------+
double CalcTP(int direction, double entry, double sl)
{
   double slDist = PriceDist(entry,sl);
   double pool   = (direction==1) ? LM_NearestBuySidePool(_Symbol) : LM_NearestSellSidePool(_Symbol);
   if(pool>0 && PriceDist(pool,entry)/slDist >= InpMinRR) return pool;
   if(direction== 1) return entry + slDist*InpRewardRatio;
   if(direction==-1) return entry - slDist*InpRewardRatio;
   return 0.0;
}


string ACI_Grade(int score)
{
   if(score >= 95) return "A+";
   if(score >= 90) return "A";
   if(score >= 85) return "B+";
   if(score >= 80) return "B";
   if(score >= 75) return "C";
   return "REJECT";
}

bool ACI_StrongTrendAligned(int direction)
{
   return (GetH4SlowBias() == direction && GetD1Bias() == direction);
}

bool ACI_RangeLike()
{
   return (GetH4SlowBias() == 0 && GetD1Bias() == 0);
}

int ACI_AdaptiveThreshold(int direction)
{
   int threshold = InpAciMinScoreTrending;
   if(ACI_StrongTrendAligned(direction)) threshold = InpAciMinScoreStrongTrend;
   else if(ACI_RangeLike())              threshold = InpAciMinScoreRange;

   if(VolGate_IsNormal()) threshold = MathMax(threshold, InpAciMinScoreNormalVol);
   return threshold;
}

int ACI_WeightedScore(int direction,
                      bool h4OK,
                      bool sweepOK,
                      bool fvgOK,
                      bool bosOK,
                      bool asianOK,
                      bool sessionLiqOK,
                      int bvScore,
                      string &detail)
{
   int score = 0;
   detail = "";

   if(h4OK && DirectionalAlignmentOK(direction))
   {
      score += InpAciWeightHTF;
      detail += StringFormat("HTF=%d/%d ", InpAciWeightHTF, InpAciWeightHTF);
   }
   else if(h4OK || DirectionalAlignmentOK(direction))
   {
      int pts = (int)MathRound(InpAciWeightHTF * 0.60);
      score += pts;
      detail += StringFormat("HTF=%d/%d ", pts, InpAciWeightHTF);
   }
   else detail += StringFormat("HTF=0/%d ", InpAciWeightHTF);

   if(sweepOK)
   {
      score += InpAciWeightLiquidity;
      detail += StringFormat("Liq=%d/%d ", InpAciWeightLiquidity, InpAciWeightLiquidity);
   }
   else detail += StringFormat("Liq=0/%d ", InpAciWeightLiquidity);

   if(bosOK)
   {
      score += InpAciWeightDisplacement;
      detail += StringFormat("Disp=%d/%d ", InpAciWeightDisplacement, InpAciWeightDisplacement);
   }
   else detail += StringFormat("Disp=0/%d ", InpAciWeightDisplacement);

   if(fvgOK)
   {
      score += InpAciWeightFVG;
      detail += StringFormat("FVG=%d/%d ", InpAciWeightFVG, InpAciWeightFVG);
   }
   else detail += StringFormat("FVG=0/%d ", InpAciWeightFVG);

   int bvPts = 0;
   if(InpScoreBetterVolume > 0)
      bvPts = (int)MathRound((double)MathMin(bvScore, InpScoreBetterVolume + 2) / (double)(InpScoreBetterVolume + 2) * InpAciWeightBetterVolume);
   if(bvPts > InpAciWeightBetterVolume) bvPts = InpAciWeightBetterVolume;
   score += bvPts;
   detail += StringFormat("BV=%d/%d ", bvPts, InpAciWeightBetterVolume);

   int volPts = 0;
   if(VolGate_IsExpanding()) volPts = InpAciWeightVolatility;
   else if(VolGate_IsNormal()) volPts = (int)MathRound(InpAciWeightVolatility * 0.60);
   score += volPts;
   detail += StringFormat("Vol=%d/%d ", volPts, InpAciWeightVolatility);

   int sessionPts = 0;
   if(sessionLiqOK) sessionPts += (int)MathRound(InpAciWeightSession * 0.70);
   if(asianOK)      sessionPts += (InpAciWeightSession - sessionPts);
   if(sessionPts > InpAciWeightSession) sessionPts = InpAciWeightSession;
   score += sessionPts;
   detail += StringFormat("Session=%d/%d ", sessionPts, InpAciWeightSession);

   if(score > 100) score = 100;
   if(score < 0) score = 0;
   return score;
}

void ACI_LogCandidate(string dir,
                      int legacyScore,
                      int aciScore,
                      int threshold,
                      string grade,
                      string decision,
                      string detail)
{
   if(!InpAciLogCandidates) return;

   int flags = FILE_COMMON|FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI;
   int h = FileOpen(InpAciCandidateLogFile, flags, ',');
   if(h == INVALID_HANDLE) return;

   bool empty = (FileSize(h) == 0);
   FileSeek(h, 0, SEEK_END);
   if(empty)
      FileWrite(h, "time", "symbol", "profile", "direction", "legacy_score", "aci_score", "threshold", "grade", "decision", "vol", "h4", "h4slow", "d1", "detail");

   FileWrite(h,
             TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
             _Symbol,
             g_SymbolLabel,
             dir,
             legacyScore,
             aciScore,
             threshold,
             grade,
             decision,
             VolGate_Label(),
             BiasText(GetH4Bias()),
             BiasText(GetH4SlowBias()),
             BiasText(GetD1Bias()),
             detail);
   FileClose(h);
}

int EffectiveMinScoreToEnter()
{
   return (InpMinScoreToEnter > 0 ? InpMinScoreToEnter : g_ProfileMinScoreToEnter);
}

//+------------------------------------------------------------------+
//| Entry attempt — V3 confluence scoring + news/shock hard safety gates         |
//+------------------------------------------------------------------+
void TryEntry(int direction)
{
   datetime curBar = iTime(_Symbol, InpEntryTF, 0);
   if(curBar == g_LastEntryBar) return;

   string dir  = direction == 1 ? "LONG" : "SHORT";
   static datetime lastDebugBarL = 0;
   static datetime lastDebugBarS = 0;
   bool dbg = InpDebugGates;
   if(dbg)
   {
      if(direction== 1 && curBar == lastDebugBarL) dbg = false;
      if(direction==-1 && curBar == lastDebugBarS) dbg = false;
      if(direction== 1) lastDebugBarL = curBar;
      if(direction==-1) lastDebugBarS = curBar;
   }

   string reason = "";
   if(DailyRiskBlocked(reason))
   {
      V6_SetState("BLOCKED", reason, "DAILY_RISK");
      if(dbg) PrintFormat("SAFETY BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }
   if(InManualBlackout())
   {
      V6_SetState("BLOCKED", "manual news/rollover blackout", "BLACKOUT");
      if(dbg) PrintFormat("SAFETY BLOCK [%s %s] manual news/rollover blackout", g_SymbolLabel, dir);
      return;
   }
   if(CalendarNewsBlocked(reason))
   {
      V6_SetState("BLOCKED", reason, "NEWS");
      if(dbg) PrintFormat("SAFETY BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }
   if(ShockGuardBlocked(reason))
   {
      V6_SetState("BLOCKED", reason, "SHOCK");
      if(dbg) PrintFormat("SAFETY BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }
   if(!CooldownOK(reason))
   {
      V6_SetState("BLOCKED", reason, "COOLDOWN");
      if(dbg) PrintFormat("SAFETY BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }
   if(!SpreadOK(reason))
   {
      V6_SetState("BLOCKED", reason, "SPREAD");
      if(dbg) PrintFormat("SAFETY BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }
   if(!VolGate_Allow())
   {
      reason = StringFormat("Vol=%s (%.0f%%) CONTRACTING/UNKNOWN", VolGate_Label(), g_VG_Confidence*100);
      V6_SetState("BLOCKED", reason, "VOLATILITY");
      if(dbg) PrintFormat("SAFETY BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }
   if(InpRgEnabled)
   {
      bool rgOK = (direction==1 ? RegimeGate_AllowLong() : RegimeGate_AllowShort());
      if(!rgOK)
      {
         reason = StringFormat("RegimeGate blocks %s: %s", dir, RegimeGate_Diagnostics());
         V6_SetState("BLOCKED", reason, "REGIME");
         if(dbg) PrintFormat("SAFETY BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
         return;
      }
   }
   if(!V6_PortfolioHeatOK(reason))
   {
      V6_SetState("BLOCKED", reason, "PORTFOLIO_HEAT");
      if(dbg) PrintFormat("SAFETY BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }
   if(!DirectionalPermissionOK(direction, reason))
   {
      V6_SetState("BLOCKED", reason, "DIRECTIONAL_INTELLIGENCE");
      if(dbg || InpPrintDirectionalDiagnostics) PrintFormat("DIRECTIONAL BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }

   int score = 0;
   string detail = "";

   int bias = GetH4Bias();
   bool h4OK = (bias == direction);
   if(h4OK) { score += InpScoreH4Bias; detail += "+H4 "; }
   else if(InpHardRequireH4Bias)
   {
      if(dbg) PrintFormat("HARD BLOCK [%s %s] H4Bias=%s — direction mismatch",
                          g_SymbolLabel, dir, bias==1?"Bull":bias==-1?"Bear":"Neutral");
      return;
   }
   if(DirectionalAlignmentOK(direction)) { score += InpScoreDirectionalAlignment; detail += "+DirAlign "; }

   bool pdOK = InPDZone(direction);
   if(pdOK) { score += InpScorePDZone; detail += "+PD "; }

   bool sweepSide = (direction==1) ? false : true;
   bool sweepOK = LM_RecentSweepExists(sweepSide, InpLmSweepBars);
   if(sweepOK) { score += InpScoreSweep; detail += "+Sweep "; }
   else if(InpHardRequireSweep)
   {
      if(dbg) PrintFormat("HARD BLOCK [%s %s] No recent %s sweep in last %d bars",
                          g_SymbolLabel, dir, sweepSide?"buy-side":"sell-side", InpLmSweepBars);
      return;
   }

   double fvgL=0, fvgH=0;
   bool fvgOK = LM_FVGNearPrice(_Symbol,(direction==1),fvgL,fvgH);
   if(fvgOK) { score += InpScoreFVG; detail += "+FVG "; }
   else if(InpHardRequireFVG)
   {
      if(dbg) PrintFormat("HARD BLOCK [%s %s] No %s FVG near price (FVGs tracked=%d)",
                          g_SymbolLabel, dir, direction==1?"bullish":"bearish", ArraySize(g_LM_FVGs));
      return;
   }

   bool bosOK = MinorBOS(direction);
   if(bosOK) { score += InpScoreBOS; detail += "+BOS "; }
   else if(InpHardRequireBOS || (VolGate_IsNormal() && !(InpUseAdaptiveConfluence && InpAciSoftBOSInNormalVol)))
   {
      if(dbg) PrintFormat("HARD BLOCK [%s %s] No minor BOS on %s (Vol=%s)",
                          g_SymbolLabel, dir, EnumToString(InpEntryTF), VolGate_Label());
      return;
   }

   bool engulfOK = IsEngulfing(direction);
   if(engulfOK) { score += InpScoreEngulf; detail += "+Engulf "; }
   else if(InpPaRequireEngulf)
   {
      if(dbg) PrintFormat("HARD BLOCK [%s %s] No engulfing candle", g_SymbolLabel, dir);
      return;
   }

   bool asianOK = AsianCompressionOK();
   if(asianOK) { score += InpScoreAsianCompression; detail += "+AsianCompression "; }

   bool sessionLiqOK = SessionLiquidityConfluence(direction);
   if(sessionLiqOK) { score += InpScoreSessionLiquidity; detail += "+SessionLiq "; }

   int bvScore = 0;
   string bvDetail = "";
   bool bvOK = BetterVolumeConfluence(direction, bvScore, bvDetail);
   if(bvScore > 0) { score += bvScore; detail += bvDetail; }
   else if(InpHardRequireBetterVolume && !bvOK)
   {
      if(dbg) PrintFormat("HARD BLOCK [%s %s] BetterVolume — %s", g_SymbolLabel, dir, bvDetail);
      return;
   }

   if(direction == 1) { g_LastScoreLong = score; g_LastReasonLong = detail; }
   else               { g_LastScoreShort = score; g_LastReasonShort = detail; }

   int aciScore = 0;
   int aciThreshold = 0;
   string aciDetail = "";
   string aciGrade = "--";

   if(InpUseAdaptiveConfluence)
   {
      aciScore = ACI_WeightedScore(direction, h4OK, sweepOK, fvgOK, bosOK, asianOK, sessionLiqOK, bvScore, aciDetail);
      aciThreshold = ACI_AdaptiveThreshold(direction);
      aciGrade = ACI_Grade(aciScore);

      if(direction == 1) { g_LastAciScoreLong = aciScore; g_LastAciThresholdLong = aciThreshold; g_LastAciGradeLong = aciGrade; }
      else               { g_LastAciScoreShort = aciScore; g_LastAciThresholdShort = aciThreshold; g_LastAciGradeShort = aciGrade; }

      if(aciScore < aciThreshold)
      {
         reason = StringFormat("ACI=%d/%d %s | legacy=%d | %s", aciScore, aciThreshold, aciGrade, score, aciDetail);
         V6_SetState("BLOCKED", reason, "ACI_SCORE");
         ACI_LogCandidate(dir, score, aciScore, aciThreshold, aciGrade, "REJECT", aciDetail);
         if(dbg || InpPrintDirectionalDiagnostics) PrintFormat("ACI BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
         return;
      }
   }
   else if(InpUseConfluenceScoring && score < EffectiveMinScoreToEnter())
   {
      reason = StringFormat("Score=%d/%d | %s", score, EffectiveMinScoreToEnter(), detail);
      V6_SetState("BLOCKED", reason, "SCORE");
      if(dbg) PrintFormat("SCORE BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }

   double entry = (direction==1) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                 : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl    = CalcSL(direction);
   double tp    = CalcTP(direction, entry, sl);

   if(sl==0.0 || tp==0.0)
   {
      if(dbg) PrintFormat("EXEC BLOCK [%s %s] SL=%.5f or TP=%.5f invalid", g_SymbolLabel, dir, sl, tp);
      return;
   }

   double slDist = PriceDist(entry, sl);
   double tpDist = PriceDist(entry, tp);

   if(slDist < MinSLPrice())
   {
      if(dbg) PrintFormat("EXEC BLOCK [%s %s] SL too small: %.5f < min %.5f", g_SymbolLabel, dir, slDist, MinSLPrice());
      return;
   }
   if(tpDist/slDist < InpMinRR)
   {
      if(dbg) PrintFormat("EXEC BLOCK [%s %s] RR=%.2f < min %.2f", g_SymbolLabel, dir, tpDist/slDist, InpMinRR);
      return;
   }
   if(!StopLevelOK(direction, entry, sl, tp, reason))
   {
      if(dbg) PrintFormat("EXEC BLOCK [%s %s] %s", g_SymbolLabel, dir, reason);
      return;
   }

   double lots = CalcLots(slDist);
   if(lots <= 0)
   {
      if(dbg) PrintFormat("EXEC BLOCK [%s %s] Lot calc returned 0", g_SymbolLabel, dir);
      return;
   }

   if(dbg) PrintFormat("ENTRY APPROVED [%s %s] Legacy=%d/%d ACI=%d/%d %s | %s — attempting order",
                       g_SymbolLabel, dir, score, EffectiveMinScoreToEnter(), aciScore, aciThreshold, aciGrade, (InpUseAdaptiveConfluence ? aciDetail : detail));

   ResetLastError();
   bool ok = false;
   if(direction== 1) ok = Trade.Buy(lots,  _Symbol, entry, sl, tp, "SMC_PE_V6_"+g_SymbolLabel+"_L");
   if(direction==-1) ok = Trade.Sell(lots, _Symbol, entry, sl, tp, "SMC_PE_V6_"+g_SymbolLabel+"_S");

   if(ok)
   {
      V6_SetState("TRADE OPENED", StringFormat("%s score=%d ACI=%d/%d %s lots=%.2f", dir, score, aciScore, aciThreshold, aciGrade, lots), "EXECUTION");
      if(InpUseAdaptiveConfluence) ACI_LogCandidate(dir, score, aciScore, aciThreshold, aciGrade, "ENTER", aciDetail);
      g_LastEntryBar = curBar;
      g_TradesToday++;
      PrintFormat("TRADE OPENED [%s] | %s | Legacy=%d | ACI=%d/%d %s | Risk=%.2f%% | Entry=%.5f SL=%.5f TP=%.5f Lots=%.2f RR=%.1f Vol=%s",
                  g_SymbolLabel, dir, score, aciScore, aciThreshold, aciGrade, CurrentRiskPct(), entry, sl, tp, lots, tpDist/slDist, VolGate_Label());
   }
   else
   {
      V6_SetState("ORDER FAILED", Trade.ResultComment(), "EXECUTION");
      PrintFormat("ORDER FAILED [%s %s] — retcode=%d error=%d comment=%s",
                  g_SymbolLabel, dir, Trade.ResultRetcode(), GetLastError(), Trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Trade management                                               |
//+------------------------------------------------------------------+
void ManageTrades()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!PosInfo.SelectByIndex(i))           continue;
      if(PosInfo.Symbol()!=_Symbol)           continue;
      if(PosInfo.Magic()!=(ulong)g_MagicNumber) continue;

      double open=PosInfo.PriceOpen();
      double sl  =PosInfo.StopLoss();
      double tp  =PosInfo.TakeProfit();
      double cur =PosInfo.PriceCurrent();
      ulong  tkt =PosInfo.Ticket();
      int    dir =(PosInfo.PositionType()==POSITION_TYPE_BUY)?1:-1;
      double slD =MathAbs(open-sl);

      if(InpRgCloseOnFlip)
      {
         if(dir== 1&&RegimeGate_FlippedAgainstLong())  {Trade.PositionClose(tkt);continue;}
         if(dir==-1&&RegimeGate_FlippedAgainstShort()) {Trade.PositionClose(tkt);continue;}
      }

      if(InpUseBE&&slD>0)
      {
         double r1=(dir==1)?open+slD:open-slD;
         bool at1R=(dir==1)?cur>=r1:cur<=r1;
         bool beNotDone=(dir==1)?sl<open:sl>open;
         if(at1R&&beNotDone)
            Trade.PositionModify(tkt,(dir==1)?open+_Point:open-_Point,tp);
      }

      if(InpUsePartial&&slD>0)
      {
         double r1=(dir==1)?open+slD:open-slD;
         bool at1R=(dir==1)?cur>=r1:cur<=r1;
         if(at1R)
         {
            double step  =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
            double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
            double closeV=MathFloor(PosInfo.Volume()*InpPartialRatio/step)*step;
            if(closeV>=minLot&&PosInfo.Volume()-closeV>=minLot)
               Trade.PositionClosePartial(tkt,closeV);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Dashboard                                                      |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   if(!InpShowDash) return;
   string lines[40];
   int n = 0;
   string sprReason="", symReason="", heatReason="";
   bool sprOK  = SpreadOK(sprReason);
   bool symOK  = V6_SymbolTradeAllowed(symReason);
   bool heatOK = V6_PortfolioHeatOK(heatReason);
   int bias = GetH4Bias();

   lines[n++]=StringFormat("SMC Portfolio Engine v6.2 [%s] Magic=%d",g_SymbolLabel,g_MagicNumber);
   lines[n++]=StringFormat("State   : %s | Gate=%s", g_V6_State, g_V6_LastGate);
   lines[n++]=StringFormat("Reason  : %s", g_V6_BlockReason);
   lines[n++]=StringFormat("Symbol  : %s | Profile=%s | Tradable=%s", _Symbol, g_SymbolLabel, V6_PassFail(symOK));
   lines[n++]=StringFormat("Vol     : %s (%.0f%%) Allow=%s",VolGate_Label(),g_VG_Confidence*100,V6_YesNo(VolGate_Allow()));
   lines[n++]=StringFormat("Regime  : %s Enabled=%s", RegimeGate_Label(), V6_YesNo(InpRgEnabled));
   lines[n++]=StringFormat("H4 Bias : %s",bias==1?"Bull":bias==-1?"Bear":"Neutral");
   if(InpUseDirectionalIntelligence)
      lines[n++]=StringFormat("Trend   : H4S=%s D1=%s", BiasText(GetH4SlowBias()), BiasText(GetD1Bias()));
   lines[n++]=StringFormat("Score   : Legacy L %.0f/S %.0f Min=%d",g_LastScoreLong,g_LastScoreShort,EffectiveMinScoreToEnter());
   if(InpUseAdaptiveConfluence)
      lines[n++]=StringFormat("ACI     : L %d/%d %s | S %d/%d %s", g_LastAciScoreLong,g_LastAciThresholdLong,g_LastAciGradeLong,g_LastAciScoreShort,g_LastAciThresholdShort,g_LastAciGradeShort);
   lines[n++]=StringFormat("Risk    : %.2f%%  DailyDD: %.2f%%",CurrentRiskPct(),CurrentDailyDDPct());
   lines[n++]=StringFormat("Heat    : %.2f%% / %.2f%% %s",g_V6_PortfolioHeatPct,InpMaxPortfolioRiskPct,V6_PassFail(heatOK));
   lines[n++]=StringFormat("Trades  : open %d/%d  today %d/%d",OpenTradeCount(),InpMaxTrades,g_TradesToday,InpMaxTradesPerDay);
   lines[n++]=StringFormat("Spread  : %.0f pts %s",(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point,V6_PassFail(sprOK));
   lines[n++]=StringFormat("Session : %s | News: %s",V6_PassFail(InSession()),NewsStatusText());
   lines[n++]=StringFormat("BV      : %s",BetterVolumeStatusText());
   lines[n++]=StringFormat("Pools   : %d  FVGs: %d Sweep:%s",ArraySize(g_LM_Pools),ArraySize(g_LM_FVGs),g_LM_SweepActive?"ACTIVE":"--");
   if(InpShowV6Diagnostics)
   {
      lines[n++]=StringFormat("VolFile : %s via %s", g_VG_LastMatchedSym, g_VG_MatchedVia);
      lines[n++]=StringFormat("RegDiag : %s", RegimeGate_Diagnostics());
      lines[n++]=StringFormat("Shock   : %s",(g_LastShockTime>0?g_LastShockReason:"--"));
      lines[n++]=StringFormat("EqPips  : %.1f  SLBuf: %.1f",g_EqualLevelPips,g_SlBufferPips);
   }

   for(int i=0;i<n;i++)
   {
      string obj="SMC_D_"+(string)i;
      if(ObjectFind(0,obj)<0) ObjectCreate(0,obj,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,obj,OBJPROP_CORNER,   CORNER_LEFT_UPPER);
      ObjectSetInteger(0,obj,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,obj,OBJPROP_YDISTANCE,15+i*18);
      color rowColor = clrWhite;
      if(i==1) rowColor = (g_V6_State=="TRADE OPENED" ? clrLime : (g_V6_State=="BLOCKED" || g_V6_State=="INIT BLOCK" ? clrOrangeRed : clrWhite));
      if(i==4)
      {
         if(VolGate_IsExpanding())   rowColor = clrLime;
         else if(VolGate_IsNormal()) rowColor = clrYellow;
         else                        rowColor = clrOrangeRed;
      }
      if(i==5 && InpRgEnabled) rowColor = (RegimeGate_Get()==REGIME_UNKNOWN ? clrOrangeRed : clrDeepSkyBlue);
      if(i==9) rowColor = heatOK ? clrLime : clrOrangeRed;
      if(i==13) rowColor = g_BVReady ? clrDeepSkyBlue : clrOrangeRed;
      ObjectSetInteger(0,obj,OBJPROP_COLOR,    rowColor);
      ObjectSetInteger(0,obj,OBJPROP_FONTSIZE, 9);
      ObjectSetString (0,obj,OBJPROP_TEXT,     lines[i]);
   }
   for(int j=n;j<25;j++) ObjectDelete(0,"SMC_D_"+(string)j);

   if(InpShowPools)
   {
      ObjectsDeleteAll(0,"LM_P_");
      for(int p=0;p<ArraySize(g_LM_Pools);p++)
      {
         string obj="LM_P_"+(string)p;
         ObjectCreate(0,obj,OBJ_HLINE,0,0,g_LM_Pools[p].price);
         color c=g_LM_Pools[p].swept?clrGray:g_LM_Pools[p].buySide?clrDeepSkyBlue:clrOrangeRed;
         ObjectSetInteger(0,obj,OBJPROP_COLOR,c);
         ObjectSetInteger(0,obj,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,obj,OBJPROP_WIDTH,1);
      }
   }

   if(InpShowFVGs)
   {
      ObjectsDeleteAll(0,"LM_F_");
      for(int f=0;f<ArraySize(g_LM_FVGs);f++)
      {
         if(g_LM_FVGs[f].mitigated) continue;
         string obj="LM_F_"+(string)f;
         ObjectCreate(0,obj,OBJ_RECTANGLE,0,
                      g_LM_FVGs[f].time,g_LM_FVGs[f].high,
                      TimeCurrent(),g_LM_FVGs[f].low);
         ObjectSetInteger(0,obj,OBJPROP_COLOR,g_LM_FVGs[f].bullish?C'0,60,0':C'60,0,0');
         ObjectSetInteger(0,obj,OBJPROP_BACK, true);
         ObjectSetInteger(0,obj,OBJPROP_FILL, true);
      }
   }
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Lifecycle                                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   ConfigureSymbolProfile();

   // ATHENA v6.3.0 framework smoke-test integration.
   // This initialises the event bus/logger only; no strategy logic is changed.
   AthenaBus.Init("SMC_Portfolio_Engine_v6.3.0", EnableAthena, AthenaDebug, "ATHENA");
   string v6Reason = "";
   g_V6_SymbolTradeOK = V6_SymbolTradeAllowed(v6Reason);
   if(!g_V6_SymbolTradeOK)
   {
      V6_SetState("INIT BLOCK", v6Reason, "SYMBOL");
      PrintFormat("V6 SYMBOL BLOCK [%s]: %s", _Symbol, v6Reason);
      if(InpRequireTradableSymbol) return INIT_FAILED;
   }
   Trade.SetExpertMagicNumber(g_MagicNumber);
   Trade.SetDeviationInPoints(InpSlippagePoints);
   UpdateDailyStats();

   RG_Enabled = InpRgEnabled;
   RG_UseGlobalVar      = InpRgUseGlobalVar;
   RG_UseCsv            = InpRgUseCsv;
   RG_JsonFile          = InpRgJsonFile;
   RG_AllowLongsInBull  = InpRgLongsInBull;
   RG_AllowShortsInBear = InpRgShortsInBear;
   RG_AllowRangeEntries = InpRgRangeEntries;
   RG_CloseOnRegimeFlip = InpRgCloseOnFlip;

   LM_SwingLookback  = InpLmSwingBars;
   LM_EqualLevelPips = g_EqualLevelPips;
   LM_SweepMaxBars   = InpLmSweepBars;
   LM_RequireClose   = InpLmRequireClose;

   LiquidityMap_Init();

   // Better Volume reader; non-fatal if indicator is not installed.
   g_BVReady = false;
   if(InpUseBetterVolume)
   {
      g_BVReady = g_BV.Init(_Symbol, InpEntryTF, InpBVMAPeriod, InpBVLookback, InpBVVolumeType);
      if(!g_BVReady)
         Print("BetterVolume disabled/not ready: install Better_Volume.mq5 in MQL5\\Indicators or set InpUseBetterVolume=false.");
   }

   // Bias EMA handles — created once here to avoid per-tick handle leaks
   g_H4BiasHandle = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(g_H4BiasHandle == INVALID_HANDLE)
      Print("WARNING: H4 50-EMA handle creation failed — H4 bias will use swing-structure fallback only.");

   g_H4SlowBiasHandle = iMA(_Symbol, PERIOD_H4, InpH4SlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_H4SlowBiasHandle == INVALID_HANDLE)
      Print("WARNING: H4 slow EMA handle creation failed — directional intelligence will be less restrictive.");

   g_D1BiasHandle = iMA(_Symbol, PERIOD_D1, InpD1EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_D1BiasHandle == INVALID_HANDLE)
      Print("WARNING: D1 EMA handle creation failed — directional intelligence will be less restrictive.");

   // Vol gate
   VG_Enabled       = InpVgEnabled;
   VG_ConfThreshold = InpVgConfThreshold;
   VG_SetPath(TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\volatility.csv");

   PrintFormat("SMC_Portfolio_Engine_v6.3.0 | Symbol=%s | Magic=%d | EqPips=%.1f | SLBuf=%.1f | VolGate=%s",
               g_SymbolLabel, g_MagicNumber, g_EqualLevelPips, g_SlBufferPips,
               VG_Enabled ? "ON" : "OFF");
   PrintFormat("Profile: label=%s | index=%s | crypto=%s | spreadMaxPts=%d | spreadAtrPct=%.2f | minScore=%d", g_SymbolLabel, g_IsIndex?"YES":"NO", g_IsCrypto?"YES":"NO", g_ProfileMaxSpreadPoints, g_ProfileMaxSpreadAtrPct, EffectiveMinScoreToEnter());
   PrintFormat("NewsGuard currencies: %s | Before=%d min After=%d min | Calendar=%s", AutoNewsCurrencies(), InpNewsMinutesBefore, InpNewsMinutesAfter, InpUseMT5CalendarNews ? "ON" : "OFF");
   PrintFormat("BetterVolume: %s | TF=%s | MA=%d | Lookback=%d | HardRequire=%s", g_BVReady?"READY":"NOT READY", EnumToString(InpEntryTF), InpBVMAPeriod, InpBVLookback, InpHardRequireBetterVolume?"YES":"NO");
   PrintFormat("VolGate path: %s", VG_CsvPath);
   PrintFormat("Terminal Common path: %s", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,"SMC_D_");
   ObjectsDeleteAll(0,"LM_P_");
   ObjectsDeleteAll(0,"LM_F_");
   g_BV.Release();
   if(g_H4BiasHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_H4BiasHandle);
      g_H4BiasHandle = INVALID_HANDLE;
   }
   if(g_H4SlowBiasHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_H4SlowBiasHandle);
      g_H4SlowBiasHandle = INVALID_HANDLE;
   }
   if(g_D1BiasHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_D1BiasHandle);
      g_D1BiasHandle = INVALID_HANDLE;
   }
}


void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal = trans.deal;
   if(deal == 0) return;
   // Load a 2-hour history window so the deal is guaranteed to be in scope
   // before calling HistoryDealSelect — without this it silently fails and
   // g_LastLossCloseTime never gets set, disabling the cooldown gate.
   if(!HistorySelect(TimeCurrent() - 7200, TimeCurrent())) return;
   if(!HistoryDealSelect(deal)) return;
   string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
   long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
   long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(sym != _Symbol || magic != g_MagicNumber || entry != DEAL_ENTRY_OUT) return;
   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT) +
                   HistoryDealGetDouble(deal, DEAL_SWAP) +
                   HistoryDealGetDouble(deal, DEAL_COMMISSION);
   if(profit < 0.0)
      g_LastLossCloseTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
}

void OnTick()
{
   UpdateDailyStats();
   VolGate_Update(_Symbol);
   RegimeGate_Update(_Symbol);
   LiquidityMap_Update(_Symbol);
   g_V6_PortfolioHeatPct = V6_EstimatePortfolioHeatPct();
   UpdateCalendarNewsState();
   ClosePositionsBeforeNews();

   if(!InSession())
   {
      V6_SetState("BLOCKED", "outside configured trading session", "SESSION");
      ManageTrades();
      DrawDashboard();
      return;
   }

   if(OpenTradeCount()<InpMaxTrades)
   {
      V6_SetState("SCANNING", "waiting for valid confluence", "SCAN");
      // v6.0 preserves the v5 confluence/news-guard engine inside TryEntry().
      TryEntry(1);
      TryEntry(-1);
   }

   if(OpenTradeCount()>=InpMaxTrades) V6_SetState("BLOCKED", "max open trades reached", "OPEN_TRADES");
   ManageTrades();
   DrawDashboard();
}
