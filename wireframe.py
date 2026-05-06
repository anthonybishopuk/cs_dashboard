import streamlit as st
import sqlite3
import pandas as pd
import altair as alt
from config import DB_PATH
from utils.db import load_companies, load_monthly_usage, load_risk_flag, load_health_scores, load_at_risk_clients

st.set_page_config(
    page_title="Client Health Overview",
    layout="wide"
)

at_risk_df = load_at_risk_clients()
all_clients_df = load_companies()
growth_opportunity_percentage = round((len(all_clients_df[all_clients_df["health_score"] > 70]) / (len(all_clients_df["health_score"])) * 100), 1)
month_getter = load_monthly_usage(1)
latest_month = month_getter["snapshot_month"].max()

if at_risk_df.empty:
    st.warning("No at-risk clients found.")

st.title("📊 Client Health Overview")
st.caption(f"Last updated: {latest_month}")

st.divider()

col1, col2, col3 = st.columns(3)

col1.metric(
    "🔴 At Risk (Health below 30)",
    len(at_risk_df)
)

col2.metric(
    "🔵 Onboarding Clients",
    len(all_clients_df[all_clients_df["client_stage"] == "Onboarding"])
)


col3.metric(
    "🟢 Growth Opportunity Clients (Health over 70)",
    f"{growth_opportunity_percentage}%"
)

st.divider()

st.subheader("Clients Requiring Attention")

st.dataframe(
    at_risk_df.sort_values(
        by=["health_score", "company_size"],
        ascending=[True, True]
        ),
    width="stretch"
)


with st.expander("🔎 Filters"):
    size_filter = st.multiselect(
        "Company size",
        options=sorted(at_risk_df["company_size"].unique()),
        default=sorted(at_risk_df["company_size"].unique())
    )

filtered_at_risk_df = at_risk_df[at_risk_df["company_size"].isin(size_filter)]

st.dataframe(filtered_at_risk_df, width="stretch")

st.divider()

# CLIENT DETAIL VIEW

st.subheader("📈 Client Detail View")

selected_company = st.selectbox(
    "Select a company",
    all_clients_df["company_name"].sort_values()
)

selected_team_id = all_clients_df.loc[
    all_clients_df["company_name"] == selected_company,
    "team_id"
].iloc[0]

usage_df = load_monthly_usage(selected_team_id)
if usage_df.empty:
    st.info("No usage data available for this client.")
    st.stop()

col1, col2 = st.columns(2)

with col1:
    st.line_chart(
        usage_df.set_index("snapshot_month")[
            ["total_clicks_wo_api"]
        ]
    )

with col2:
    st.line_chart(
        usage_df.set_index("snapshot_month")[
            ["jobs_posted"]
        ]
    )

col3, col4 = st.columns(2)

with col3:
    st.line_chart(
        usage_df.set_index("snapshot_month")[
            ["active_users"]
        ]
    )

with col4:
    st.line_chart(
        usage_df.set_index("snapshot_month")[
            ["active_coddlers"]
        ]
    )

with st.expander("🗒️ Raw monthly data"):
    st.dataframe(usage_df, width="stretch")