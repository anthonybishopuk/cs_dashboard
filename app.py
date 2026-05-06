import streamlit as st
import sqlite3
import pandas as pd
import altair as alt
from config import DB_PATH
from utils.db import load_companies, load_monthly_usage, load_risk_flag, load_health_scores, load_at_risk_clients, load_latest_health_summary
from utils.data_prep import prepare_time_series

st.set_page_config(
    page_title="Client Health Overview",
    layout="wide"
)

at_risk_df = load_at_risk_clients()
all_clients_df = load_companies()
growth_opportunity_percentage = round((len(all_clients_df[all_clients_df["overall_health_score"] > 70]) / (len(all_clients_df["overall_health_score"])) * 100), 1)
month_getter = load_monthly_usage(1)
latest_month = month_getter["snapshot_month"].max()

if at_risk_df.empty:
    st.warning("No at-risk clients found.")

st.title("📊 Client Health Overview")
st.caption(f"Last updated: {latest_month}")

st.divider()

col1, col2, col3 = st.columns(3)

col1.metric(
    "🔴 Critical (Health below 40)",
    len(at_risk_df)
)

col2.metric(
    "🔵 Onboarding Clients (Under 6 months old)",
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
        by=["overall_health_score", "company_size"],
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

    salesperson_filter = st.multiselect(
        "Salesperson",
        options=sorted(at_risk_df["salesperson"].dropna().unique()),
        default=sorted(at_risk_df["salesperson"].dropna().unique())
    )
    
filtered_at_risk_df = at_risk_df[
    (at_risk_df["company_size"].isin(size_filter)) &
    (at_risk_df["salesperson"].isin(salesperson_filter))
]

st.dataframe(filtered_at_risk_df, width="stretch")

st.divider()

# CLIENT DETAIL VIEW

st.subheader("📈 Client Detail View")

selected_company = st.selectbox(
    "Select a company",
    all_clients_df["company_name"].sort_values()
)

selected_team_id = int(all_clients_df.loc[
    all_clients_df["company_name"] == selected_company,
    "team_id"
].iloc[0])

health_summary_df = load_latest_health_summary(selected_team_id)

if not health_summary_df.empty:
    health_score = health_summary_df["overall_health_score"].iloc[0]
    health_band = health_summary_df["health_band"].iloc[0]
    narrative = health_summary_df["health_narrative"].iloc[0]

    st.markdown("🩺 Health Summary")
    st.metric("Overall Health Score", health_score)
    st.caption(f"Current Health Band: {health_band}")
    st.info(narrative)

usage_df = load_monthly_usage(selected_team_id)

st.write("Raw usage rows:", len(usage_df))

usage_df = prepare_time_series(usage_df)

st.write("After prep rows:", len(usage_df))
st.write("Selected Team ID:", selected_team_id)

if usage_df.empty:
    st.info("No usage data available for this client.")
    st.stop()

col1, col2 = st.columns(2)

with col1:
    st.line_chart(
        usage_df[["total_clicks_wo_api"]], y_label="Clicks"
    )

with col2:
    st.line_chart(
        usage_df[["jobs_posted"]], y_label="Jobs Posted"
    )

col3, col4 = st.columns(2)

with col3:
    st.line_chart(
        usage_df[["active_users"]], y_label="Users"
    )

with col4:
    st.line_chart(
        usage_df[["active_coddlers"]], y_label="Coddlers"
    )

# ALL DATA FOR SELECTED CLIENT

with st.expander("🗒️ Raw monthly data"):
    st.dataframe(usage_df, width="stretch")