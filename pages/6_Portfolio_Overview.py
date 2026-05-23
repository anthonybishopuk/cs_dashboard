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

churn_df = load_churn_data()
last_seen = churn_df.groupby('team_id')['snapshot_month'].max().reset_index()
last_seen.columns = ['team_id', 'last_seen_month']

latest_month = churn_df['snapshot_month'].max()
churned = last_seen[last_seen['last_seen_month'] < latest_month]
churned = churned.merge(
    churn_df[['team_id', 'region']].drop_duplicates(),
    on='team_id'
)

churn_by_month = churned.groupby(
    ['last_seen_month', 'region']
)['team_id'].count().reset_index()
churn_by_month.columns = ['snapshot_month', 'region', 'clients_churned']

active_by_month = churn_df.groupby(
    ['snapshot_month', 'region']
)['team_id'].nunique().reset_index()
active_by_month.columns = ['snapshot_month', 'region', 'clients_active']

churn_summary = active_by_month.merge(
    churn_by_month,
    on=['snapshot_month', 'region'],
    how='left'
).fillna(0)

churn_summary['churn_rate'] = (
    churn_summary['clients_churned'] / churn_summary['clients_active'] * 100
).round(2)

churn_fig = px.line(
    churn_summary,
    x='snapshot_month',
    y='churn_rate',
    color='region',
    title='Monthly Churn Rate by Region',
    labels={
        'snapshot_month': 'Month',
        'churn_rate': 'Churn Rate (%)',
        'region': 'Region'
    }
)
churn_fig.add_hline(
    y=5,
    line_dash='dash',
    line_color='red',
    annotation_text='5% threshold'
)
churn_fig.update_yaxes(rangemode="tozero")
st.plotly_chart(churn_fig, width="stretch")

st.divider()

first_seen = churn_df.groupby('team_id')['snapshot_month'].min().reset_index()
first_seen.columns = ['team_id', 'first_seen_month']

first_month = churn_df['snapshot_month'].min()
new_clients = first_seen[first_seen['first_seen_month'] > first_month]
new_clients = new_clients.merge(
    churn_df[['team_id', 'region']].drop_duplicates(),
    on='team_id'
)

new_by_month = new_clients.groupby(
    ['first_seen_month', 'region']
)['team_id'].count().reset_index()
new_by_month.columns = ['snapshot_month', 'region', 'clients_new']

churn_summary = churn_summary.merge(
    new_by_month,
    on=['snapshot_month', 'region'],
    how='left'
).fillna(0)


churn_melted = churn_summary.melt(
    id_vars=['snapshot_month', 'region'],
    value_vars=['clients_churned', 'clients_new'],
    var_name='metric',
    value_name='clients'
)

churn_melted['metric'] = churn_melted['metric'].replace({
    'clients_churned': 'Clients Leaving',
    'clients_new': 'New Clients'
})

us_df = churn_melted[churn_melted['region'] == 'US']
uk_df = churn_melted[churn_melted['region'] == 'UK']

us_churn_col1, uk_churn_col2 = st.columns(2)

with us_churn_col1:
    new_churn_fig = px.bar(
    us_df,
    x='snapshot_month',
    y='clients',
    color='metric',
    barmode='group',
    color_discrete_map={
        'New Clients': '#2ecc71',
        'Clients Leaving': '#e74c3c'
    },
    title='US Market - New vs Churned Clients by Month',
    labels={
        "clients": "Clients",
        "snapshot_month": "Month",
        "metric": "Metric"
    }
    )
    st.plotly_chart(new_churn_fig, width='stretch')

with uk_churn_col2:
    new_churn_fig = px.bar(
    uk_df,
    x='snapshot_month',
    y='clients',
    color='metric',
    barmode='group',
    color_discrete_map={
        'New Clients': '#2ecc71',
        'Clients Leaving': '#e74c3c'
    },
    title='UK Market - New vs Churned Clients by Month',
    labels={
        "clients": "Clients",
        "snapshot_month": "Month",
        "metric": "Metric"
    }
    )
    st.plotly_chart(new_churn_fig, width='stretch')

