import streamlit as st
import plotly.express as px
import pandas as pd
from utils.db import load_portfolio_summary, load_churn_data

st.set_page_config(layout="wide")
st.title("Portfolio Overview")

df = load_portfolio_summary()

total_clients = df['total_clients'].iloc[0]
clients_display = f'{total_clients:,.0f}'
total_mrr = df['total_mrr'].iloc[0]
mrr_display = f'${total_mrr:,.0f}'
avg_health_score = df['avg_health_score'].iloc[0]

global_col1, global_col2, global_col3 = st.columns(3)

with global_col1:
    st.metric(label="Total Clients", value=clients_display)

with global_col2:
    st.metric(label="Total Monthly Recurring Revenue", value=mrr_display)

with global_col3:
    st.metric(label="Average Health Score", value=avg_health_score)
