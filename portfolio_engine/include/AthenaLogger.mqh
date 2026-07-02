//+------------------------------------------------------------------+
//| AthenaLogger.mqh                                                 |
//| ATHENA Quant Platform - MT5 CSV Logging Bridge                    |
//| Version: v1.0.0-alpha                                            |
//+------------------------------------------------------------------+
#ifndef __ATHENA_LOGGER_MQH__
#define __ATHENA_LOGGER_MQH__

class CAthenaLogger
{
private:
   string m_prefix;
   string m_ea_version;
   bool   m_enabled;
   bool   m_debug;

   string BoolToText(const bool value)
   {
      return value ? "1" : "0";
   }

   string Clean(const string value)
   {
      string v = value;
      StringReplace(v, ",", ";");
      StringReplace(v, "\r", " ");
      StringReplace(v, "\n", " ");
      return v;
   }

   bool EnsureHeader(const string file_name, const string header)
   {
      if(!m_enabled)
         return false;

      bool exists = FileIsExist(file_name, FILE_COMMON);
      int handle = FileOpen(file_name, FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI);

      if(handle == INVALID_HANDLE)
      {
         if(m_debug)
            Print("ATHENA LOGGER ERROR: could not open ", file_name, " err=", GetLastError());
         return false;
      }

      if(!exists || FileSize(handle) == 0)
      {
         FileWriteString(handle, header + "\r\n");
      }

      FileClose(handle);
      return true;
   }

   bool AppendLine(const string file_name, const string line)
   {
      if(!m_enabled)
         return false;

      int handle = FileOpen(file_name, FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI);
      if(handle == INVALID_HANDLE)
      {
         if(m_debug)
            Print("ATHENA LOGGER ERROR: could not append ", file_name, " err=", GetLastError());
         return false;
      }

      FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, line + "\r\n");
      FileClose(handle);
      return true;
   }

public:
   CAthenaLogger()
   {
      m_prefix     = "ATHENA";
      m_ea_version = "UNKNOWN";
      m_enabled    = true;
      m_debug      = false;
   }

   void Init(const string ea_version,
             const string file_prefix = "ATHENA",
             const bool enabled = true,
             const bool debug = false)
   {
      m_ea_version = ea_version;
      m_prefix     = file_prefix;
      m_enabled    = enabled;
      m_debug      = debug;

      if(!m_enabled)
         return;

      EnsureHeader(CandidatesFile(),
         "logged_at,ea_version,symbol,direction,candidate_time,accepted,rejection_reason,regime,volatility_state,session_name,spread_points,atr_value,htf_score,liquidity_score,fvg_score,displacement_score,volume_score,volatility_score,session_score,total_score,market_quality_score");

      EnsureHeader(TradesFile(),
         "logged_at,ea_version,symbol,direction,entry_time,exit_time,entry_price,exit_price,stop_loss,take_profit,lots,risk_percent,profit,r_multiple,mae,mfe,regime,volatility_state,session_name,htf_score,liquidity_score,fvg_score,displacement_score,volume_score,volatility_score,session_score,total_score,result");

      EnsureHeader(PortfolioFile(),
         "logged_at,ea_version,snapshot_time,equity,balance,open_risk_percent,daily_drawdown_percent,portfolio_heat_percent,open_positions,notes");

      EnsureHeader(ExperimentsFile(),
         "logged_at,experiment_name,ea_version,athena_version,broker,account_currency,symbol,timeframe,start_date,end_date,test_model,initial_deposit,leverage,notes");

      if(m_debug)
         Print("ATHENA LOGGER: initialised. Prefix=", m_prefix, " EA=", m_ea_version);
   }

   string CandidatesFile()  { return m_prefix + "_candidates.csv"; }
   string TradesFile()      { return m_prefix + "_trades.csv"; }
   string PortfolioFile()   { return m_prefix + "_portfolio_snapshots.csv"; }
   string ExperimentsFile() { return m_prefix + "_experiments.csv"; }

   bool LogCandidate(const string symbol,
                     const string direction,
                     const datetime candidate_time,
                     const bool accepted,
                     const string rejection_reason,
                     const string regime,
                     const string volatility_state,
                     const string session_name,
                     const double spread_points,
                     const double atr_value,
                     const double htf_score,
                     const double liquidity_score,
                     const double fvg_score,
                     const double displacement_score,
                     const double volume_score,
                     const double volatility_score,
                     const double session_score,
                     const double total_score,
                     const double market_quality_score)
   {
      string line =
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "," +
         Clean(m_ea_version) + "," +
         Clean(symbol) + "," +
         Clean(direction) + "," +
         TimeToString(candidate_time, TIME_DATE|TIME_SECONDS) + "," +
         BoolToText(accepted) + "," +
         Clean(rejection_reason) + "," +
         Clean(regime) + "," +
         Clean(volatility_state) + "," +
         Clean(session_name) + "," +
         DoubleToString(spread_points, 2) + "," +
         DoubleToString(atr_value, 5) + "," +
         DoubleToString(htf_score, 2) + "," +
         DoubleToString(liquidity_score, 2) + "," +
         DoubleToString(fvg_score, 2) + "," +
         DoubleToString(displacement_score, 2) + "," +
         DoubleToString(volume_score, 2) + "," +
         DoubleToString(volatility_score, 2) + "," +
         DoubleToString(session_score, 2) + "," +
         DoubleToString(total_score, 2) + "," +
         DoubleToString(market_quality_score, 2);

      return AppendLine(CandidatesFile(), line);
   }

   bool LogTrade(const string symbol,
                 const string direction,
                 const datetime entry_time,
                 const datetime exit_time,
                 const double entry_price,
                 const double exit_price,
                 const double stop_loss,
                 const double take_profit,
                 const double lots,
                 const double risk_percent,
                 const double profit,
                 const double r_multiple,
                 const double mae,
                 const double mfe,
                 const string regime,
                 const string volatility_state,
                 const string session_name,
                 const double htf_score,
                 const double liquidity_score,
                 const double fvg_score,
                 const double displacement_score,
                 const double volume_score,
                 const double volatility_score,
                 const double session_score,
                 const double total_score,
                 const string result)
   {
      string line =
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "," +
         Clean(m_ea_version) + "," +
         Clean(symbol) + "," +
         Clean(direction) + "," +
         TimeToString(entry_time, TIME_DATE|TIME_SECONDS) + "," +
         TimeToString(exit_time, TIME_DATE|TIME_SECONDS) + "," +
         DoubleToString(entry_price, _Digits) + "," +
         DoubleToString(exit_price, _Digits) + "," +
         DoubleToString(stop_loss, _Digits) + "," +
         DoubleToString(take_profit, _Digits) + "," +
         DoubleToString(lots, 2) + "," +
         DoubleToString(risk_percent, 2) + "," +
         DoubleToString(profit, 2) + "," +
         DoubleToString(r_multiple, 3) + "," +
         DoubleToString(mae, 3) + "," +
         DoubleToString(mfe, 3) + "," +
         Clean(regime) + "," +
         Clean(volatility_state) + "," +
         Clean(session_name) + "," +
         DoubleToString(htf_score, 2) + "," +
         DoubleToString(liquidity_score, 2) + "," +
         DoubleToString(fvg_score, 2) + "," +
         DoubleToString(displacement_score, 2) + "," +
         DoubleToString(volume_score, 2) + "," +
         DoubleToString(volatility_score, 2) + "," +
         DoubleToString(session_score, 2) + "," +
         DoubleToString(total_score, 2) + "," +
         Clean(result);

      return AppendLine(TradesFile(), line);
   }

   bool LogPortfolioSnapshot(const datetime snapshot_time,
                             const double equity,
                             const double balance,
                             const double open_risk_percent,
                             const double daily_drawdown_percent,
                             const double portfolio_heat_percent,
                             const int open_positions,
                             const string notes)
   {
      string line =
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "," +
         Clean(m_ea_version) + "," +
         TimeToString(snapshot_time, TIME_DATE|TIME_SECONDS) + "," +
         DoubleToString(equity, 2) + "," +
         DoubleToString(balance, 2) + "," +
         DoubleToString(open_risk_percent, 2) + "," +
         DoubleToString(daily_drawdown_percent, 2) + "," +
         DoubleToString(portfolio_heat_percent, 2) + "," +
         IntegerToString(open_positions) + "," +
         Clean(notes);

      return AppendLine(PortfolioFile(), line);
   }

   bool LogExperiment(const string experiment_name,
                      const string athena_version,
                      const string broker,
                      const string account_currency,
                      const string symbol,
                      const string timeframe,
                      const string start_date,
                      const string end_date,
                      const string test_model,
                      const double initial_deposit,
                      const string leverage,
                      const string notes)
   {
      string line =
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "," +
         Clean(experiment_name) + "," +
         Clean(m_ea_version) + "," +
         Clean(athena_version) + "," +
         Clean(broker) + "," +
         Clean(account_currency) + "," +
         Clean(symbol) + "," +
         Clean(timeframe) + "," +
         Clean(start_date) + "," +
         Clean(end_date) + "," +
         Clean(test_model) + "," +
         DoubleToString(initial_deposit, 2) + "," +
         Clean(leverage) + "," +
         Clean(notes);

      return AppendLine(ExperimentsFile(), line);
   }
};

#endif
