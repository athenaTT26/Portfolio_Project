//+------------------------------------------------------------------+
//| EventBus.mqh                                                     |
//| ATHENA Quant Platform - Event Bus                                |
//| Version: v1.0.0-alpha                                            |
//+------------------------------------------------------------------+
#ifndef __ATHENA_EVENT_BUS_MQH__
#define __ATHENA_EVENT_BUS_MQH__

#include "AthenaLogger.mqh"
#include "AthenaEvents.mqh"
#include "LoggerConfig.mqh"

class CAthenaEventBus
{
private:
   CAthenaLogger m_logger;
   bool          m_enabled;
   bool          m_debug;
   string        m_ea_version;
   string        m_prefix;

public:
   CAthenaEventBus()
   {
      m_enabled    = true;
      m_debug      = false;
      m_ea_version = "UNKNOWN";
      m_prefix     = ATHENA_DEFAULT_PREFIX;
   }

   void Init(const string ea_version,
             const bool enabled = true,
             const bool debug = false,
             const string prefix = ATHENA_DEFAULT_PREFIX)
   {
      m_ea_version = ea_version;
      m_enabled    = enabled;
      m_debug      = debug;
      m_prefix     = prefix;

      m_logger.Init(m_ea_version, m_prefix, m_enabled, m_debug);

      if(m_debug)
         Print("ATHENA EVENT BUS: initialised. Enabled=", m_enabled, " EA=", m_ea_version);
   }

   bool EmitCandidate(const AthenaCandidateEvent &event)
   {
      if(!m_enabled)
         return false;

      return m_logger.LogCandidate(
         event.symbol,
         event.direction,
         event.candidate_time,
         event.accepted,
         event.rejection_reason,
         event.regime,
         event.volatility_state,
         event.session_name,
         event.spread_points,
         event.atr_value,
         event.htf_score,
         event.liquidity_score,
         event.fvg_score,
         event.displacement_score,
         event.volume_score,
         event.volatility_score,
         event.session_score,
         event.total_score,
         event.market_quality_score
      );
   }

   bool EmitTrade(const AthenaTradeEvent &event)
   {
      if(!m_enabled)
         return false;

      return m_logger.LogTrade(
         event.symbol,
         event.direction,
         event.entry_time,
         event.exit_time,
         event.entry_price,
         event.exit_price,
         event.stop_loss,
         event.take_profit,
         event.lots,
         event.risk_percent,
         event.profit,
         event.r_multiple,
         event.mae,
         event.mfe,
         event.regime,
         event.volatility_state,
         event.session_name,
         event.htf_score,
         event.liquidity_score,
         event.fvg_score,
         event.displacement_score,
         event.volume_score,
         event.volatility_score,
         event.session_score,
         event.total_score,
         event.result
      );
   }

   bool EmitPortfolioSnapshot(const AthenaPortfolioSnapshotEvent &event)
   {
      if(!m_enabled)
         return false;

      return m_logger.LogPortfolioSnapshot(
         event.snapshot_time,
         event.equity,
         event.balance,
         event.open_risk_percent,
         event.daily_drawdown_percent,
         event.portfolio_heat_percent,
         event.open_positions,
         event.notes
      );
   }

   bool EmitExperiment(const AthenaExperimentEvent &event)
   {
      if(!m_enabled)
         return false;

      return m_logger.LogExperiment(
         event.experiment_name,
         event.athena_version,
         event.broker,
         event.account_currency,
         event.symbol,
         event.timeframe,
         event.start_date,
         event.end_date,
         event.test_model,
         event.initial_deposit,
         event.leverage,
         event.notes
      );
   }
};

#endif
