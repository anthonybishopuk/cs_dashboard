-- Base tables
-- clients_raw is the single source table. All other objects are views.
-- Data is loaded via CSV import (see data/ folder, excluded from git).

CREATE TABLE IF NOT EXISTS clients_raw (
    id                        INT,
    company_name              TEXT,
    team_id                   INT,
    is_test                   INT,            -- 1 = test account, excluded from all views
    region                    TEXT,
    snapshot_month            TEXT,           -- format: YYYY-MM-DD (monthly grain)
    source_file               TEXT,           -- name of the CSV this row was loaded from
    load_date                 TEXT,
    total_clicks              INT,
    total_clicks_wo_api       INT,            -- clicks excluding API activity (preferred engagement metric)
    non_jobs_clicks           INT,
    view_candidates           INT,
    active_coddlers           INT,            -- active recruiters/users on the CoddlerSphere product
    monthly_fee               REAL,           -- stored with commas in source; cast to REAL in clients_clean
    monthly_fee_currency      TEXT,
    number_candidate_emails   INT,
    number_contact_emails     INT,
    salesperson               TEXT,
    latest_contract_end_date  TEXT,           -- source format: DD/MM/YYYY; converted to ISO in clients_clean
    active_harvester_accounts INT,
    active_users              INT,
    total_resumes             INT,
    total_jobs                INT,
    hires_in_past_year        INT
);
