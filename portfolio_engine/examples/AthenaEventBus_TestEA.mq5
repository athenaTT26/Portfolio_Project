//+------------------------------------------------------------------+
//| AthenaEventBus_TestEA.mq5                                        |
//| Minimal smoke test for ATHENA Event Bus                           |
//+------------------------------------------------------------------+
#property strict
#property version "1.000"

#include "../include/EventBus.mqh"

input bool InpAthenaEnabled = true;
input bool InpAthenaDebug   = true;

CAthenaEventBus AthenaBus;

int OnInit()
{
   AthenaBus.Init("AthenaEventBus_TestEA_v1.0.0-alpha", InpAthenaEnabled, InpAthenaDebug, "ATHENA_BUS_TEST");

   AthenaExperimentEvent experiment;
   experiment.experiment_name   = "Athena EventBus Smoke Test";
   experiment.athena_version    = ATHENA_VERSION;
   experiment.broker            = "Local MT5";
   experiment.account_currency  = AccountInfoString(ACCOUNT_CURRENCY);
   experiment.symbol            = _Symbol;
   experiment.timeframe         = EnumToString(_Period);
   experiment.start_date        = "N/A";
   experiment.end_date          = "N/A";
   experiment.test_model        = "Manual";
   experiment.initial_deposit   = AccountInfoDouble(ACCOUNT_BALANCE);
   experiment.leverage          = "N/A";
   experiment.notes             = "EventBus smoke test.";
   AthenaBus.EmitExperiment(experiment);

   AthenaCandidateEvent candidate;
   candidate.symbol               = _Symbol;
   candidate.direction            = "LONG";
   candidate.candidate_time       = TimeCurrent();
   candidate.accepted             = true;
   candidate.rejection_reason     = "";
   candidate.regime               = "BULL";
   candidate.volatility_state     = "EXPANDING";
   candidate.session_name         = "London";
   candidate.spread_points        = 20;
   candidate.atr_value            = 4.57;
   candidate.htf_score            = 25;
   candidate.liquidity_score      = 18;
   candidate.fvg_score            = 12;
   candidate.displacement_score   = 14;
   candidate.volume_score         = 8;
   candidate.volatility_score     = 10;
   candidate.session_score        = 5;
   candidate.total_score          = 92;
   candidate.market_quality_score = 87;
   AthenaBus.EmitCandidate(candidate);

   AthenaPortfolioSnapshotEvent snapshot;
   snapshot.snapshot_time             = TimeCurrent();
   snapshot.equity                    = AccountInfoDouble(ACCOUNT_EQUITY);
   snapshot.balance                   = AccountInfoDouble(ACCOUNT_BALANCE);
   snapshot.open_risk_percent         = 0.0;
   snapshot.daily_drawdown_percent    = 0.0;
   snapshot.portfolio_heat_percent    = 0.0;
   snapshot.open_positions            = PositionsTotal();
   snapshot.notes                     = "EventBus smoke test snapshot.";
   AthenaBus.EmitPortfolioSnapshot(snapshot);

   Print("ATHENA EventBus smoke test complete. Check Common\\Files for ATHENA_BUS_TEST_*.csv");
   return INIT_SUCCEEDED;
}

void OnTick()
{
}
