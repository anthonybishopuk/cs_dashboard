import pandas as pd

def prepare_time_series(df, date_col="snapshot_month"):
    df = df.copy()
    df[date_col] = pd.to_datetime(df[date_col])
    df = df.sort_values(date_col)
    df = df.set_index(date_col)
    return df


def calculate_churn_summary(churn_df):
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
    return churn_summary


def prepare_churn_chart_data(churn_summary):
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
    return churn_melted