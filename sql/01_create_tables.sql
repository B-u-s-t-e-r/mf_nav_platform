-- 1. Pipeline run audit
CREATE TABLE etl_run_audit (
    run_id              UUID PRIMARY KEY,
    dag_id              VARCHAR(100) NOT NULL,
    nav_start_date      DATE NOT NULL,
    nav_end_date        DATE NOT NULL,
    source_url          TEXT NOT NULL,
    raw_file_path       TEXT NOT NULL,
    raw_file_sha256     CHAR(64) NOT NULL,
    raw_file_size_bytes BIGINT,
    input_row_count     BIGINT,
    valid_row_count     BIGINT,
    rejected_row_count  BIGINT,
    status              VARCHAR(20) NOT NULL,
    error_message       TEXT,
    started_at          TIMESTAMPTZ NOT NULL,
    completed_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_run_audit_status ON etl_run_audit (status);

-- 2. Data-quality results
CREATE TABLE dq_result (
    dq_result_id       BIGSERIAL PRIMARY KEY,
    run_id             UUID NOT NULL REFERENCES etl_run_audit(run_id),
    rule_code          VARCHAR(50) NOT NULL,
    severity           VARCHAR(20) NOT NULL,
    status             VARCHAR(20) NOT NULL,
    affected_row_count BIGINT NOT NULL,
    message            TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (run_id, rule_code)
);

CREATE INDEX idx_dq_result_run ON dq_result (run_id);

-- 3. Rejected NAV rows
CREATE TABLE nav_reject (
    reject_id      BIGSERIAL PRIMARY KEY,
    run_id         UUID NOT NULL REFERENCES etl_run_audit(run_id),
    scheme_code    VARCHAR(50),
    scheme_name    TEXT,
    plan           VARCHAR(100),
    option_name    VARCHAR(100),
    nav_date       DATE,
    nav_value_raw  VARCHAR(100),
    reject_rule    VARCHAR(50) NOT NULL,
    reject_reason  TEXT NOT NULL,
    source_file    TEXT NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_nav_reject_run ON nav_reject (run_id);

-- 4. Curated daily NAV
CREATE TABLE fact_daily_nav (
    scheme_code       VARCHAR(50) NOT NULL,
    nav_date          DATE NOT NULL,
    scheme_name       TEXT NOT NULL,
    plan              VARCHAR(50) NOT NULL,
    option_name       VARCHAR(100) NOT NULL,
    nav_value         NUMERIC(18,6) NOT NULL,
    prev_nav_value    NUMERIC(18,6),
    daily_return_pct  NUMERIC(12,6),
    stale_flag        BOOLEAN NOT NULL DEFAULT FALSE,
    anomaly_flag      BOOLEAN NOT NULL DEFAULT FALSE,
    run_id            UUID NOT NULL REFERENCES etl_run_audit(run_id),
    source_file       TEXT NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (scheme_code, nav_date)
);

CREATE INDEX idx_fact_daily_nav_date   ON fact_daily_nav (nav_date);
CREATE INDEX idx_fact_daily_nav_scheme ON fact_daily_nav (scheme_code);

-- 5. Scheme reference dimension
CREATE TABLE dim_scheme (
    scheme_code       VARCHAR(50) PRIMARY KEY,
    scheme_name       TEXT NOT NULL,
    amc_name          VARCHAR(200),
    plan              VARCHAR(50) NOT NULL,
    option_name       VARCHAR(100) NOT NULL,
    record_valid_flag BOOLEAN NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (scheme_name, plan, option_name)
);