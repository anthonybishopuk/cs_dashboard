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
            active_coddlers,
            total_resumes,
            resumes_added,
            hires_in_past_year
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
        WHERE overall_health_score <= 60
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)


def load_clients_to_review():
    query = """
        SELECT
            arna.company_name,
            arna.team_id,
            arna.region,
            arna.salesperson,
            arna.overall_health_score,
            arna.health_band,
            arna.health_narrative,
            arna.risk_flag,
            arna.contract_status,
            arna.days_to_contract_end,
            arna.user_trend,
            arna.engagement_delta,
            arna.company_size,
            arna.monthly_fee,
            arna.recommended_action,
            pca.child_team_id,
            CASE 
                WHEN pca.child_team_id IS NOT NULL 
                    THEN 1 
                ELSE 0 
            END AS is_child_account,
            pca.parent_company_name
        FROM at_risk_next_actions arna
        LEFT JOIN parent_child_accounts pca
            ON arna.team_id = pca.child_team_id
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
    

def load_churn_data():
    query = """
        SELECT
            cc.team_id,
            cc.company_name,
            cc.region,
            ls.company_size,
            cc.salesperson,
            cc.snapshot_month
        FROM clients_clean cc
        LEFT JOIN latest_snapshot ls
            ON cc.team_id = ls.team_id
            AND cc.snapshot_month = ls.snapshot_month
        WHERE cc.snapshot_month >= '2025-06-01'
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)
    

def load_portfolio_summary():
    query = """
        SELECT
            COUNT(DISTINCT ls.team_id) AS total_clients,
            SUM(ls.monthly_fee) AS total_mrr,
            ROUND(AVG(ohs.overall_health_score), 1) AS avg_health_score
        FROM latest_snapshot ls
        LEFT JOIN overall_health_score ohs
            ON ls.team_id = ohs.team_id
            AND ls.snapshot_month = ohs.snapshot_month
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)

  
def load_scatter_data():
    query = """
        SELECT
            *
        FROM consolidated_fee_per_user
        WHERE fee_per_user IS NOT NULL
        AND account_team_id NOT IN (
            SELECT team_id FROM company_overview
            WHERE client_stage = 'Onboarding'
        )
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)


def load_mrr_history():
    query = """
        SELECT
            *
        FROM consolidated_mrr_history
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)
    

def load_list_onboarding_clients():
    query = """
        SELECT
            *
        FROM onboarding_clients
        WHERE snapshot_month = (
            SELECT MAX(snapshot_month)
            FROM clients_clean   
        )
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)


def load_parent_ids():
    query = """
        SELECT DISTINCT parent_team_id FROM parent_child_accounts
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn)['parent_team_id'].tolist()
    

def load_child_accounts(parent_team_id):
    query = """
        SELECT
            pca.child_team_id AS team_id,
            pca.child_company_name AS company_name,
            ls.active_users,
            ls.total_clicks_wo_api,
            ls.monthly_fee,
            ohs.overall_health_score,
            ohs.health_band
        FROM parent_child_accounts pca
        LEFT JOIN latest_snapshot ls
            ON pca.child_team_id = ls.team_id
        LEFT JOIN overall_health_score ohs
            ON pca.child_team_id = ohs.team_id
            AND ls.snapshot_month = ohs.snapshot_month
        WHERE pca.parent_team_id = ?
        ORDER BY ohs.overall_health_score ASC
    """
    with get_connection() as conn:
        return pd.read_sql(query, conn, params=(parent_team_id,))