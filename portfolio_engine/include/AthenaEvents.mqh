//+------------------------------------------------------------------+
//| AthenaEvents.mqh                                                 |
//| ATHENA Quant Platform - Shared Event Structures                   |
//| Version: v1.0.0-alpha                                            |
//+------------------------------------------------------------------+
#ifndef __ATHENA_EVENTS_MQH__
#define __ATHENA_EVENTS_MQH__

struct AthenaCandidateEvent
{
   string   symbol;
   string   direction;
   datetime candidate_time;
   bool     accepted;
   string   rejection_reason;

   string   regime;
   string   volatility_state;
   string   session_name;

   double   spread_points;
   double   atr_value;

   double   htf_score;
   double   liquidity_score;
   double   fvg_score;
   double   displacement_score;
   double   volume_score;
   double   volatility_score;
   double   session_score;
   double   total_score;
   double   market_quality_score;
};

struct AthenaTradeEvent
{
   string   symbol;
   string   direction;

   datetime entry_time;
   datetime exit_time;

   double   entry_price;
   double   exit_price;
   double   stop_loss;
   double   take_profit;
   double   lots;
   double   risk_percent;

   double   profit;
   double   r_multiple;
   double   mae;
   double   mfe;

   string   regime;
   string   volatility_state;
   string   session_name;

   double   htf_score;
   double   liquidity_score;
   double   fvg_score;
   double   displacement_score;
   double   volume_score;
   double   volatility_score;
   double   session_score;
   double   total_score;

   string   result;
};

struct AthenaPortfolioSnapshotEvent
{
   datetime snapshot_time;

   double equity;
   double balance;
   double open_risk_percent;
   double daily_drawdown_percent;
   double portfolio_heat_percent;

   int    open_positions;
   string notes;
};

struct AthenaExperimentEvent
{
   string experiment_name;
   string athena_version;
   string broker;
   string account_currency;
   string symbol;
   string timeframe;
   string start_date;
   string end_date;
   string test_model;
   double initial_deposit;
   string leverage;
   string notes;
};

#endif
