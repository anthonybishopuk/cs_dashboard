import streamlit as st
import plotly.express as px
import pandas as pd
from utils.db import load_clients_to_review, load_monthly_usage
from utils.data_prep import prepare_time_series

st.set_page_config(layout="wide")
st.title("Clients to Review")

df = load_clients_to_review()

critical_clients = df[df["health_band"] == "Critical"]
at_risk_clients = df[df["health_band"] == "At Risk"]
watch_clients = df[df["health_band"] == "Watch"]
healthy_clients = df[df["health_band"] == "Healthy"]

global_col1, global_col2, global_col3, global_col4 = st.columns(4)

with global_col1:
    st.metric(label="Critical", value=len(critical_clients))

with global_col2:
    st.metric(label="At Risk", value=len(at_risk_clients))

with global_col3:
    st.metric(label="Watch", value=len(watch_clients))

with global_col4:
    st.metric(label="Healthy", value=len(healthy_clients))


with st.expander("🔎 Filters"):
    health_filter = st.multiselect(
        "Health Band",
        options=sorted(df["health_band"].unique()),
        default=sorted(df["health_band"].unique())
    )
    
    size_filter = st.multiselect(
        "Company Size",
        options=sorted(df["company_size"].unique()),
        default=sorted(df["company_size"].unique())
    )

    salesperson_filter = st.multiselect(
        "Salesperson",
        options=sorted(df["salesperson"].dropna().unique()),
        default=sorted(df["salesperson"].dropna().unique())
    )

    region_filter = st.multiselect(
        "Region",
        options=sorted(df["region"].unique()),
        default=sorted(df["region"].unique())
    )

filtered_df = df[
    (df["health_band"].isin(health_filter)) &
    (df["company_size"].isin(size_filter)) &
    (df["salesperson"].isin(salesperson_filter)) &
    (df["region"].isin(region_filter))
]

filtered_critical_clients = filtered_df[filtered_df["health_band"] == "Critical"]
filtered_at_risk_clients = filtered_df[filtered_df["health_band"] == "At Risk"]
filtered_watch_clients = filtered_df[filtered_df["health_band"] == "Watch"]
filtered_healthy_clients = filtered_df[filtered_df["health_band"] == "Healthy"]

filtered_col1, filtered_col2, filtered_col3, filtered_col4 = st.columns(4)

with filtered_col1:
    st.metric(label="Critical", value=len(filtered_critical_clients))

with filtered_col2:
    st.metric(label="At Risk", value=len(filtered_at_risk_clients))

with filtered_col3:
    st.metric(label="Watch", value=len(filtered_watch_clients))

with filtered_col4:
    st.metric(label="Healthy", value=len(filtered_healthy_clients))


if not filtered_df.empty:
    st.subheader("📈 Client Detail View")

    selected_company = st.selectbox(
        "Select a company",
        filtered_df["company_name"].sort_values()
    )

    selected_team_id = int(filtered_df.loc[
        filtered_df["company_name"] == selected_company,
        "team_id"
        ].iloc[0])

    selected_client = filtered_df[
        filtered_df["company_name"] == selected_company
        ].iloc[0]

    usage_df = load_monthly_usage(selected_team_id)
    usage_df = prepare_time_series(usage_df)
    
    st.divider()

    st.header(selected_company)
    st.info(selected_client["health_narrative"])

    client_col1, client_col2 = st.columns(2)

    with client_col1:
        fee = selected_client["monthly_fee"]
        fee_unit = "£" if selected_client["region"] == "UK" else "$"
        fee_display = "Unknown" if pd.isna(fee) else f"{fee_unit}{int(fee):,}"
        st.markdown(f"Monthly fee: {fee_display}")
        st.markdown(f"Users: {usage_df['active_users'].iloc[-1]}")
        st.markdown(f"Risk: {selected_client["risk_flag"]}")
        st.markdown(f"Health Score: {selected_client["overall_health_score"]}")

    with client_col2:
        st.markdown(f"Account Manager: {selected_client["salesperson"]}")
        st.markdown(f"Region: {selected_client["region"]}")
        days_left = selected_client["days_to_contract_end"]
        days_display = "Unknown. Please check" if pd.isna(days_left) else int(days_left)
        st.markdown(f"Contract Days left: {days_display}")
        st.markdown(f"Company Size: {selected_client["company_size"].capitalize()}")

    
    chart_col1, chart_col2 = st.columns(2)

    with chart_col1:
        fig = px.line(
            usage_df.reset_index(),
            x="snapshot_month",
            y="total_clicks_wo_api",
            title="User Clicks",
            labels={
                "snapshot_month": "Month",
                "total_clicks_wo_api": "Clicks"
            }
        )
        st.plotly_chart(fig, width="stretch")

    with chart_col2:
        fig = px.line(
            usage_df.reset_index(),
            x="snapshot_month",
            y="jobs_posted",
            title="Jobs Posted",
            labels={
                "snapshot_month": "Month",
                "jobs_posted": "Jobs"
            }
        )
        st.plotly_chart(fig, width="stretch")


    chart_col3, chart_col4 = st.columns(2)

    with chart_col3:
        fig = px.line(
            usage_df.reset_index(),
            x="snapshot_month",
            y="active_users",
            title="Users",
            labels={
                "snapshot_month": "Month",
                "active_users": "Users"
            }
        )
        st.plotly_chart(fig, width="stretch")

    with chart_col4:
        fig = px.line(
            usage_df.reset_index(),
            x="snapshot_month",
            y="overall_health_score",
            title="Health Score",
            labels={
                "snapshot_month": "Month",
                "overall_health_score": "Health Score"
            }
        )
        st.plotly_chart(fig, width="stretch") 


else:
    st.info("No clients match the current filters.")