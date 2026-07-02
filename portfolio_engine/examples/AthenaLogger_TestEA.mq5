//+------------------------------------------------------------------+
//| AthenaLogger_TestEA.mq5                                          |
//| Minimal test EA for ATHENA Logger                                |
//+------------------------------------------------------------------+
#property strict
#property version "1.000"

#include "../include/AthenaLogger.mqh"

input bool InpAthenaEnabled = true;
input bool InpAthenaDebug   = true;

CAthenaLogger Athena;

int OnInit()
{
   Athena.Init("AthenaLogger_TestEA_v1.0.0-alpha", "ATHENA_TEST", InpAthenaEnabled, InpAthenaDebug);

   Athena.LogExperiment(
      "Athena Logger Smoke Test",
      "ATHENA_v1.0.0-alpha",
      "Local MT5",
      AccountInfoString(ACCOUNT_CURRENCY),
      _Symbol,
      EnumToString(_Period),
      "N/A",
      "N/A",
      "Visual/Manual",
      AccountInfoDouble(ACCOUNT_BALANCE),
      "N/A",
      "Initial AthenaLogger test."
   );

   Athena.LogCandidate(
      _Symbol,
      "LONG",
      TimeCurrent(),
      true,
      "",
      "BULL",
      "EXPANDING",
      "London",
      20,
      4.57,
      25,
      18,
      12,
      14,
      8,
      10,
      5,
      92,
      87
   );

   Athena.LogPortfolioSnapshot(
      TimeCurrent(),
      AccountInfoDouble(ACCOUNT_EQUITY),
      AccountInfoDouble(ACCOUNT_BALANCE),
      0.0,
      0.0,
      0.0,
      PositionsTotal(),
      "Logger smoke test snapshot."
   );

   Print("ATHENA Logger smoke test complete. Check Common\\Files for ATHENA_TEST_*.csv");
   return INIT_SUCCEEDED;
}

void OnTick()
{
}
