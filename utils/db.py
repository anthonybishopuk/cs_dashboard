# DB connection + query helpers

import sqlite3
import pandas as pd
from config import DB_PATH


def load_df(query: str, params=None) -> pd.DataFrame:
    with sqlite3.connect(DB_PATH) as conn:
        return pd.read_sql_query(query, conn, params=params)
    

def get_connection():
    return sqlite3.connect(DB_PATH)


def load_companies():
    query = """
        SELECT DISTINCT
            team_id,
            company_name,
            company_size,
            region,
            monthly_fee,
            client_stage,
            overall_health_score,
            salesperson
        FROM company_overview
        ORDER BY company_name
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)


def load_monthly_usage(team_id):
    usage_query = """
        SELECT
            snapshot_month,
            total_clicks_wo_api,
            active_users,
            jobs_posted,
            active_coddlers
        FROM monthly_usage
        WHERE team_id = ?
        ORDER BY snapshot_month
    """
    health_query = """
        SELECT
            snapshot_month,
            overall_health_score
        FROM health_score_monthly_enriched
        WHERE team_id = ?
        ORDER BY snapshot_month
    """
    with get_connection() as conn:
        usage_df = pd.read_sql(usage_query, conn, params=(team_id,))
        health_df = pd.read_sql(health_query, conn, params=(team_id,))

    return usage_df.merge(health_df, on="snapshot_month", how="left")


def load_risk_flag(team_id):
    query = """
        SELECT
            risk_flag,
            contract_status,
            days_to_contract_end,
            latest_contract_end_date
        FROM at_risk_watchlist
        WHERE team_id = ?
        LIMIT 1
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn, params=(team_id,))


def load_at_risk_clients():
    query = """
        SELECT
            company_name,
            overall_health_score,
            health_narrative,
            company_size,
            monthly_fee,
            salesperson
        FROM at_risk_next_actions
        WHERE overall_health_score <= 40
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)


def load_clients_to_review():
    query = """
        SELECT
            company_name,
            team_id,
            region,
            salesperson,
            overall_health_score,
            health_band,
            health_narrative,
            risk_flag,
            contract_status,
            days_to_contract_end
            user_trend,
            engagement_delta,
            company_size,
            monthly_fee,
            recommended_action
        FROM at_risk_next_actions
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)


def load_health_scores(team_id):
    query = """
        SELECT 
            snapshot_month,
            health_score
        FROM health_score_monthly
        WHERE team_id is = ?
        ORDER BY snapshot_month
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn, params=[team_id])
    

def load_latest_health_summary(team_id):
    query = """
        SELECT
            snapshot_month,
            overall_health_score,
            health_band,
            health_narrative
        FROM health_score_monthly_enriched
        WHERE team_id = ?
        ORDER BY snapshot_month DESC
        LIMIT 1
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn, params=(team_id,))
    

def load_onboarding_clients(team_id):
    query = """
        SELECT
            snapshot_month,
            onboarding_age_band
        FROM onboarding_clients
        WHERE team_id = ?
        ORDER BY snapshot_month DESC
        LIMIT 1
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn, params=(team_id,))