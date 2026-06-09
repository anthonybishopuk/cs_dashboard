import streamlit as st
import plotly.express as px
import pandas as pd
from utils.db import load_list_onboarding_clients, load_monthly_usage
from utils.data_prep import prepare_time_series

st.set_page_config(layout="wide")
st.title("Onboarding Tracker")

df = load_list_onboarding_clients()

early_df = df[df['onboarding_age_band'] == 'Month 0–1']
mid_df = df[df['onboarding_age_band'] == 'Month 1–3']
late_df = df[df['onboarding_age_band'] == 'Month 3–6']

early_col, mid_col, late_col = st.columns(3)

with early_col:
    st.metric(label='Early Stage (1 month)', value=len(early_df))

with mid_col:
    st.metric(label='Mid Stage (1-3 Months)', value=len(mid_df))

with late_col:
    st.metric(label='Late Stage (3-6 Months)', value=len(late_df))

st.divider()

display_cols = [
    'team_id',
    'company_name',
    'salesperson',
    'region',
    'months_since_start',
    'onboarding_age_band',
    'monthly_fee',
    'active_users',
    'total_clicks_wo_api',
    'hires_in_past_year',
    'total_resumes'
]

onboard_df = df[display_cols].sort_values('months_since_start')
onboard_df['First Hire Achieved'] = onboard_df['hires_in_past_year'].apply(lambda x: '✅' if x > 0 else '❌')
onboard_df = onboard_df.rename(columns={
    'company_name': 'Company',
    'salesperson': 'Account Manager',
    'region': 'Region',
    'months_since_start': 'Months In',
    'onboarding_age_band': 'Stage',
    'monthly_fee': 'Monthly Fee',
    'active_users': 'Users',
    'total_clicks_wo_api': 'Clicks',
    'hires_in_past_year': 'Hires',
    'total_resumes': 'Resumes'
})

with st.expander("🔎 Filters"):
    stage_filter = st.multiselect(
        'Stage',
        options=sorted(onboard_df['Stage'].unique()),
        default=sorted(onboard_df['Stage'].unique())
    )

    salesperson_filter = st.multiselect(
        'Account Manager',
        options=sorted(onboard_df['Account Manager'].unique()),
        default=sorted(onboard_df['Account Manager'].unique())
    )

    region_filter = st.multiselect(
        'Region',
        options=sorted(onboard_df['Region'].unique()),
        default=sorted(onboard_df['Region'].unique())
    )

filtered_df = onboard_df[
    (onboard_df["Stage"].isin(stage_filter)) &
    (onboard_df["Account Manager"].isin(salesperson_filter)) &
    (onboard_df["Region"].isin(region_filter))
]

st.divider()

if not filtered_df.empty:
    st.subheader("📈 Client Detail View")

    selected_company = st.selectbox(
        "Select a company",
        filtered_df["Company"].sort_values()
    )

    selected_team_id = int(filtered_df.loc[
        filtered_df["Company"] == selected_company,
        "team_id"
        ].iloc[0])

    selected_client = filtered_df[
        filtered_df["Company"] == selected_company
        ].iloc[0]

    progress_df = load_monthly_usage(selected_team_id)
    progress_df = prepare_time_series(progress_df)
    progress_df['clicks_per_user'] = (
        progress_df['total_clicks_wo_api'] / progress_df['active_users'].replace(0, pd.NA)
    ).round(2)
    
    st.divider()

    st.header(selected_company)

    client_col1, client_col2, client_col3 = st.columns(3)

    with client_col1:
        st.html(f"<strong>Onboarding Stage</strong>: {selected_client['Stage']}")
        st.html(f"<strong>Months In</strong>: {selected_client['Months In']}")
        st.html(f"<strong>Users</strong>: {selected_client['Users']}")

    with client_col2:
        st.html(f"<strong>Resumes</strong>: {selected_client['Resumes']}")
        st.html(f"<strong>Hired</strong>: {selected_client['First Hire Achieved']}")
        st.html(f"<strong>Hires</strong>: {selected_client['Hires']}")
        

    with client_col3:
        fee = selected_client["Monthly Fee"]
        fee_unit = "£" if selected_client["Region"] == "UK" else "$"
        fee_display = "Unknown" if pd.isna(fee) else f"{fee_unit}{int(fee):,}"
        st.html(f"<strong>Monthly fee</strong>: {fee_display}")
        st.html(f"<strong>Account Manager</strong>: {selected_client['Account Manager']}")
        st.html(f"<strong>Region</strong>: {selected_client['Region']}")


    
    onboard_col1, onboard_col2, onboard_col3 = st.columns(3)
    onboard_col4, onboard_col5, onboard_col6 = st.columns(3)

    with onboard_col1:
        fig = px.bar(
            progress_df.reset_index(),
            x="snapshot_month",
            y="total_clicks_wo_api",
            title="User Clicks",
            labels={
                "snapshot_month": "Month",
                "total_clicks_wo_api": "Clicks"
            }
        )
        fig.update_xaxes(dtick="M1", tickformat="%b %Y")
        fig.update_yaxes(rangemode="tozero")
        fig.update_layout(bargap=0.1)
        st.plotly_chart(fig, width="stretch") 

    with onboard_col2:
        fig = px.bar(
            progress_df.reset_index(),
            x="snapshot_month",
            y="clicks_per_user",
            title="Clicks per user",
            labels={
                "snapshot_month": "Month",
                "clicks_per_user": "Clicks per user"
            }
        )
        fig.update_xaxes(dtick="M1", tickformat="%b %Y")
        fig.update_yaxes(rangemode="tozero")
        fig.update_layout(bargap=0.1)
        st.plotly_chart(fig, width="stretch")

    with onboard_col3:
        fig = px.bar(
            progress_df.reset_index(),
            x="snapshot_month",
            y="resumes_added",
            title="Resumes Added",
            labels={
                "snapshot_month": "Month",
                "resumes_added": "Resumes Added"
            }
        )
        fig.update_xaxes(dtick="M1", tickformat="%b %Y")
        fig.update_yaxes(rangemode="tozero")
        fig.update_layout(bargap=0.1)
        st.plotly_chart(fig, width="stretch")
    
    with onboard_col4:
        fig = px.bar(
            progress_df.reset_index().iloc[1:],
            x="snapshot_month",
            y="jobs_posted",
            title="Jobs Posted",
            labels={
                "snapshot_month": "Month",
                "jobs_posted": "Jobs"
            }
        )
        fig.update_xaxes(dtick="M1", tickformat="%b %Y")
        fig.update_yaxes(rangemode="tozero")
        fig.update_layout(bargap=0.1)
        st.plotly_chart(fig, width="stretch")

    with onboard_col5:
        fig = px.bar(
            progress_df.reset_index(),
            x="snapshot_month",
            y="active_users",
            title="Users",
            labels={
                "snapshot_month": "Month",
                "active_users": "Users"
            }
        )
        fig.update_xaxes(dtick="M1", tickformat="%b %Y")
        fig.update_yaxes(rangemode="tozero")
        fig.update_layout(bargap=0.1)
        st.plotly_chart(fig, width="stretch")

    with onboard_col6:
        fig = px.bar(
            progress_df.reset_index(),
            x="snapshot_month",
            y="hires_in_past_year",
            title="Hires (in past year)",
            labels={
                "snapshot_month": "Month",
                "hires_in_past_year": "Hires in past year"
            }
        )
        fig.update_xaxes(dtick="M1", tickformat="%b %Y")
        fig.update_yaxes(rangemode="tozero")
        fig.update_layout(bargap=0.1)
        st.plotly_chart(fig, width="stretch")

else:
    st.info("No clients match the current filters.")

st.dataframe(filtered_df, hide_index=True, width='stretch')