-- Risk flagging and contract status views

DROP VIEW IF EXISTS contract_status;
CREATE VIEW contract_status AS
SELECT
	team_id,
	company_name,
	latest_contract_end_date,
	CAST(julianday(latest_contract_end_date) - julianday('now') AS INTEGER) AS days_to_contract_end,
	CASE
		WHEN julianday(latest_contract_end_date) - julianday('now') < 0
			THEN 'Expired'
		WHEN julianday(latest_contract_end_date) - julianday('now') <= 30
			THEN 'Renegotiate (0-30 days)'
		WHEN julianday(latest_contract_end_date) <= julianday('now', '+90 days')
			THEN 'Renewal window (31-90 days)'
		ELSE 'Active'
	END AS contract_status
FROM latest_snapshot;


DROP VIEW IF EXISTS at_risk_watchlist;
CREATE VIEW at_risk_watchlist AS
SELECT
	ls.team_id,
	ls.company_name,
	ls.region,
	ls.company_size,
	ls.active_users,
	ls.total_clicks_wo_api,
	ls.monthly_fee,
	ROUND(ls.monthly_fee * 1.0 / NULLIF(ls.active_users, 0), 2) AS fee_per_user,
	cs.latest_contract_end_date,
	cs.days_to_contract_end,
	cs.contract_status,
	gs.user_trend,
	ct.months_since_start,
	CASE
		WHEN ct.months_since_start < 3
			THEN 'Onboarding'
		ELSE 'Established'
	END AS client_stage,
	CASE
		WHEN ct.months_since_start < 3 THEN 'Monitor'
		WHEN cs.days_to_contract_end < 0 THEN 'High'
		WHEN cs.days_to_contract_end <= 30 THEN 'High'
		WHEN cs.days_to_contract_end <= 90 AND gs.user_trend = 'Declining' THEN 'High'
		WHEN cs.days_to_contract_end <= 90 THEN 'Medium'
		ELSE 'Low'
	END AS risk_flag
FROM latest_snapshot ls
LEFT JOIN contract_status cs
	ON ls.team_id = cs.team_id
LEFT JOIN growth_summary gs
	ON ls.team_id = gs.team_id
LEFT JOIN client_tenure ct
	ON ls.team_id = ct.team_id;
