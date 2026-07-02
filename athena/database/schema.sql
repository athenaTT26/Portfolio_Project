PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS experiments (
    experiment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_name TEXT NOT NULL,
    ea_version TEXT NOT NULL,
    athena_version TEXT NOT NULL,
    broker TEXT,
    account_currency TEXT,
    symbol TEXT,
    timeframe TEXT,
    start_date TEXT,
    end_date TEXT,
    test_model TEXT,
    initial_deposit REAL,
    leverage TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS trades (
    trade_id INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id INTEGER,
    ea_version TEXT NOT NULL,
    symbol TEXT NOT NULL,
    direction TEXT NOT NULL CHECK(direction IN ('LONG','SHORT')),
    entry_time TEXT,
    exit_time TEXT,
    entry_price REAL,
    exit_price REAL,
    stop_loss REAL,
    take_profit REAL,
    lots REAL,
    risk_percent REAL,
    profit REAL,
    r_multiple REAL,
    mae REAL,
    mfe REAL,
    regime TEXT,
    volatility_state TEXT,
    session_name TEXT,
    htf_score REAL,
    liquidity_score REAL,
    fvg_score REAL,
    displacement_score REAL,
    volume_score REAL,
    volatility_score REAL,
    session_score REAL,
    total_score REAL,
    result TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(experiment_id) REFERENCES experiments(experiment_id)
);

CREATE TABLE IF NOT EXISTS candidates (
    candidate_id INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id INTEGER,
    ea_version TEXT NOT NULL,
    symbol TEXT NOT NULL,
    direction TEXT NOT NULL CHECK(direction IN ('LONG','SHORT')),
    candidate_time TEXT NOT NULL,
    accepted INTEGER NOT NULL CHECK(accepted IN (0,1)),
    rejection_reason TEXT,
    regime TEXT,
    volatility_state TEXT,
    session_name TEXT,
    spread_points REAL,
    atr_value REAL,
    htf_score REAL,
    liquidity_score REAL,
    fvg_score REAL,
    displacement_score REAL,
    volume_score REAL,
    volatility_score REAL,
    session_score REAL,
    total_score REAL,
    market_quality_score REAL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(experiment_id) REFERENCES experiments(experiment_id)
);

CREATE TABLE IF NOT EXISTS parameters (
    parameter_id INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id INTEGER,
    parameter_set_name TEXT NOT NULL,
    parameter_name TEXT NOT NULL,
    parameter_value TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(experiment_id) REFERENCES experiments(experiment_id)
);

CREATE TABLE IF NOT EXISTS portfolio_snapshots (
    snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id INTEGER,
    snapshot_time TEXT NOT NULL,
    equity REAL,
    balance REAL,
    open_risk_percent REAL,
    daily_drawdown_percent REAL,
    portfolio_heat_percent REAL,
    open_positions INTEGER,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(experiment_id) REFERENCES experiments(experiment_id)
);

CREATE TABLE IF NOT EXISTS models (
    model_id INTEGER PRIMARY KEY AUTOINCREMENT,
    model_name TEXT NOT NULL,
    model_type TEXT NOT NULL,
    model_version TEXT NOT NULL,
    symbol TEXT,
    training_start TEXT,
    training_end TEXT,
    validation_score REAL,
    active INTEGER NOT NULL DEFAULT 0 CHECK(active IN (0,1)),
    file_path TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reports (
    report_id INTEGER PRIMARY KEY AUTOINCREMENT,
    experiment_id INTEGER,
    report_name TEXT NOT NULL,
    report_type TEXT NOT NULL,
    file_path TEXT,
    summary TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(experiment_id) REFERENCES experiments(experiment_id)
);

CREATE INDEX IF NOT EXISTS idx_trades_symbol_time ON trades(symbol, entry_time);
CREATE INDEX IF NOT EXISTS idx_trades_experiment ON trades(experiment_id);
CREATE INDEX IF NOT EXISTS idx_candidates_symbol_time ON candidates(symbol, candidate_time);
CREATE INDEX IF NOT EXISTS idx_candidates_score ON candidates(total_score);
CREATE INDEX IF NOT EXISTS idx_experiments_version ON experiments(ea_version, athena_version);