import streamlit as st
import plotly.express as px
import pandas as pd
from utils.db import load_portfolio_summary, load_churn_data, load_scatter_data, load_mrr_history
from utils.data_prep import calculate_churn_summary, prepare_churn_chart_data, calculate_nrr_grr

st.set_page_config(layout="wide")
st.title("Portfolio Overview")

df = load_portfolio_summary()

total_clients = df['total_clients'].iloc[0]
clients_display = f'{total_clients:,.0f}'
total_mrr = df['total_mrr'].iloc[0]
mrr_display = f'${total_mrr:,.0f}'
avg_health_score = df['avg_health_score'].iloc[0]


# FIRST SECTION - OVERALL STATS
global_col1, global_col2, global_col3 = st.columns(3)

with global_col1:
    st.metric(label="Total Clients", value=clients_display)

with global_col2:
    st.metric(label="Total Monthly Recurring Revenue", value=mrr_display)

with global_col3:
    st.metric(label="Average Health Score", value=avg_health_score)


# CHURN GRAPHS
churn_df = load_churn_data()
churn_summary = calculate_churn_summary(churn_df)

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

# US AND UK - NEW & LEAVING CLIENTS
churn_melted = prepare_churn_chart_data(churn_summary)
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

st.divider()

scatter_df = load_scatter_data()
small_df = scatter_df[scatter_df['company_size'].isin(['micro', 'small'])]
large_df = scatter_df[scatter_df['company_size'].isin(['medium', 'large'])]

scatter_col1, scatter_col2 = st.columns(2)

with scatter_col1:
    scatter_fig = px.scatter(
        small_df,
        x='total_users',
        y='fee_per_user',
        color='region',
        hover_name='company_name',
        color_discrete_map={
            'UK': 'red',
            'US': 'blue'
        },
        title='Micro & Small compannies - Fee per User',
        labels={
            'total_users': 'Active Users',
            'fee_per_user': 'Fee per User',
            'region': 'Region'
        }
    )
    scatter_fig.update_yaxes(rangemode="tozero")
    st.plotly_chart(scatter_fig, width='stretch')


with scatter_col2:
    scatter_fig = px.scatter(
        large_df,
        x='total_users',
        y='fee_per_user',
        color='region',
        hover_name='company_name',
        color_discrete_map={
            'UK': 'red',
            'US': 'blue'
        },
        title='Medium & Large companies - Fee per User',
        labels={
            'total_users': 'Active Users',
            'fee_per_user': 'Fee per User',
            'region': 'Region'
        }
    )
    scatter_fig.update_yaxes(rangemode="tozero")
    st.plotly_chart(scatter_fig, width='stretch')

st.dataframe(scatter_df)

st.divider()

# NRR_GRR GRAPHS

mrr_history = load_mrr_history()
nrr_grr_summary = calculate_nrr_grr(mrr_history)
nrr_grr_plot = nrr_grr_summary.reset_index()
nrr_grr_plot.rename(columns={
    'index': 'snapshot_month'
}, inplace=True)

grr_fig = px.line(
    nrr_grr_plot,
    x='snapshot_month',
    y='grr_result',
    title='Monthly GRR',
    labels={
        'snapshot_month': 'Month',
        'grr_result': 'GRR (%)'
    }
)
grr_fig.data[0].name = 'GRR'
grr_fig.data[0].showlegend = True
grr_fig.add_scatter(
    x=nrr_grr_plot['snapshot_month'],
    y=nrr_grr_plot['nrr_result'],
    mode='lines',
    name='NRR'
)

grr_fig.update_yaxes(rangemode="tozero")
st.plotly_chart(grr_fig, width="stretch")

st.divider()