import streamlit as st
import sqlite3
import pandas as pd
from config import DB_PATH
from utils.db import load_companies, load_monthly_usage, load_risk_flag, load_health_scores, load_at_risk_clients, load_latest_health_summary, load_onboarding_clients
from utils.data_prep import prepare_time_series

st.set_page_config(
    page_title="Client Search",
    layout="wide"
)

all_clients_df = load_companies()

with st.expander("🔎 Filters"):
    size_filter = st.multiselect(
        "Company size",
        options=sorted(all_clients_df["company_size"].unique()),
        default=sorted(all_clients_df["company_size"].unique())
    )

    salesperson_filter = st.multiselect(
        "Salesperson",
        options=sorted(all_clients_df["salesperson"].dropna().unique()),
        default=sorted(all_clients_df["salesperson"].dropna().unique())
    )

    region_filter = st.multiselect(
        "Region",
        options=sorted(all_clients_df["region"].unique()),
        default=sorted(all_clients_df["region"].unique())
    )
    
filtered_all_clients_df = all_clients_df[
    (all_clients_df["company_size"].isin(size_filter)) &
    (all_clients_df["salesperson"].isin(salesperson_filter)) &
    (all_clients_df["region"].isin(region_filter))
]


st.subheader("📈 Client Detail View")

selected_company = st.selectbox(
    "Select a company",
    filtered_all_clients_df["company_name"].sort_values()
)

selected_team_id = int(filtered_all_clients_df.loc[
    filtered_all_clients_df["company_name"] == selected_company,
    "team_id"
].iloc[0])

selected_client = filtered_all_clients_df[
    filtered_all_clients_df["company_name"] == selected_company
    ].iloc[0]

usage_df = load_monthly_usage(selected_team_id)
usage_df = prepare_time_series(usage_df)

col1, col2 = st.columns(2)

with col1:
    st.header(selected_company)
    st.markdown(f"Monthly fee: {int(selected_client["monthly_fee"])}")
    st.markdown(f"Account Manager: {selected_client["salesperson"]}")
    st.markdown(f"Region: {selected_client["region"]}")
    st.markdown(f"Client Stage: {selected_client["client_stage"]}")

with col2:
    fee_per_user = round(selected_client["monthly_fee"] / usage_df["active_users"].iloc[-1], 2)
    st.markdown(f"Fee per user: {fee_per_user}")


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