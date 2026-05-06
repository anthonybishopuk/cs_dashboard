DROP VIEW IF EXISTS growth_summary;

-- client_growth_summary source

CREATE VIEW growth_summary AS
SELECT
	l.team_id,
	l.company_name,
    l.active_users AS users_current,
    p.active_users AS users_previous,
    l.active_users - p.active_users AS users_change,
    l.total_clicks AS clicks_current,
    p.total_clicks AS clicks_previous,
    l.total_clicks - p.total_clicks AS clicks_change,
    l.monthly_fee AS fee_current,
    p.monthly_fee AS fee_previous,
    l.monthly_fee - p.monthly_fee AS fee_change,
    l.total_jobs AS jobs_current,
    p.total_jobs AS jobs_previous,
    l.total_jobs - p.total_jobs AS jobs_change,
CASE
	WHEN p.active_users IS NULL THEN 'new'
	WHEN l.active_users - p.active_users > 0 THEN 'growing'
	WHEN l.active_users - p.active_users < 0 THEN 'shrinking'
	ELSE 'flat'
END AS user_trend
FROM latest_snapshot l
LEFT JOIN previous_snapshot p
    ON l.team_id = p.team_id;