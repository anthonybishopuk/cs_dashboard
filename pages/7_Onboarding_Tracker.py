import streamlit as st
import plotly.express as px
import pandas as pd
from utils.db import load_list_onboarding_clients

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

st.dataframe(onboard_df, hide_index=True, width='stretch')