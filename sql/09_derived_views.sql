-- Derived and composite views
-- These sit at the top of the dependency chain and pull from multiple upstream views.
-- Run last, after all preceding SQL files.


DROP VIEW IF EXISTS company_overview;
CREATE VIEW company_overview AS
-- Single summary row per client based on latest snapshot.
-- Used as the base for the main client list and onboarding_clients.
SELECT
	ls.team_id,
	ls.company_name,
	ls.company_size,
	ls.region,
	ls.monthly_fee,
	ls.salesperson,
	ct.months_since_start,
	CASE
		WHEN ct.months_since_start < 6 THEN 'Onboarding'
		ELSE 'Established'
	END AS client_stage,
	ohs.overall_health_score
FROM latest_snapshot ls
LEFT JOIN client_tenure ct
	ON ls.team_id = ct.team_id
LEFT JOIN health_score_monthly hsm
	ON ls.team_id = hsm.team_id
	AND ls.snapshot_month = hsm.snapshot_month
LEFT JOIN overall_health_score ohs
	ON ls.team_id = ohs.team_id
	AND ls.snapshot_month = ohs.snapshot_month;


DROP VIEW IF EXISTS at_risk_next_actions;
CREATE VIEW at_risk_next_actions AS
-- Combines health score, risk flags, contract status, and engagement
-- to produce a recommended action per client.
-- Excludes clients still in onboarding (<3 months) and nulls.
SELECT
	ls.company_name,
	ls.team_id,
    ls.region,
	ls.salesperson,
	ohs.overall_health_score,
    ohs.health_band,
	hnm.health_narrative,
	arw.risk_flag,
	arw.contract_status,
	arw.days_to_contract_end,
	arw.user_trend,
	et.engagement_delta,
	ls.company_size,
    ls.monthly_fee,
	CASE
		WHEN ohs.overall_health_score < 40
			THEN 'Urgent outreach – disengaging'
		WHEN arw.contract_status = 'Expired'
			THEN 'Commercial check-in'
		WHEN arw.contract_status LIKE 'Renegotiate%'
			THEN 'Renewal conversation'
		WHEN arw.user_trend = 'Declining'
			THEN 'Adoption review'
		WHEN ls.company_size IN ('medium', 'large')
		 AND ohs.overall_health_score BETWEEN 50 AND 65
			THEN 'Proactive value review'
		ELSE 'Monitor'
	END AS recommended_action
FROM latest_snapshot ls
LEFT JOIN overall_health_score ohs
	ON ls.team_id = ohs.team_id
	AND ls.snapshot_month = ohs.snapshot_month
LEFT JOIN at_risk_watchlist arw
	ON ls.team_id = arw.team_id
LEFT JOIN engagement_trend et
	ON ls.team_id = et.team_id
	AND ls.snapshot_month = et.snapshot_month
LEFT JOIN client_tenure ct
	ON ls.team_id = ct.team_id
LEFT JOIN health_narrative_monthly hnm
	ON ls.team_id = hnm.team_id
	AND ls.snapshot_month = hnm.snapshot_month
WHERE ohs.overall_health_score IS NOT NULL
	AND ct.months_since_start >= 3
ORDER BY ohs.overall_health_score ASC, arw.company_size;


DROP VIEW IF EXISTS onboarding_clients;
CREATE VIEW onboarding_clients AS
-- All historical monthly rows for clients currently flagged as Onboarding
-- in company_overview. Used to track early-stage engagement over time.
SELECT
	cc.team_id,
	cc.company_name,
	co.salesperson,
	co.client_stage,
	co.months_since_start,
	CASE
		WHEN co.months_since_start < 1 THEN 'Month 0–1'
		WHEN co.months_since_start < 3 THEN 'Month 1–3'
		WHEN co.months_since_start < 6 THEN 'Month 3–6'
		ELSE '6+ Months'
	END AS onboarding_age_band,
	cc.region,
	cc.snapshot_month,
	cc.total_clicks_wo_api,
	cc.active_coddlers,
	cc.monthly_fee,
	CASE
		WHEN cc.monthly_fee > 80 THEN 1
		ELSE 0
	END AS has_paid_users,
	cc.active_users,
	cc.total_resumes,
	cc.total_jobs,
	cc.hires_in_past_year
FROM company_overview co
LEFT JOIN clients_clean cc
	ON co.team_id = cc.team_id
WHERE co.client_stage = 'Onboarding';


DROP VIEW IF EXISTS clicks_per_user_trend;
CREATE VIEW clicks_per_user_trend AS
-- Month-on-month clicks per user with percentage change.
-- Useful for spotting engagement trajectory per client.
WITH base AS (
	SELECT
		company_name,
		team_id,
		snapshot_month,
		total_clicks_wo_api,
		active_users,
		ROUND(total_clicks_wo_api * 1.0 / NULLIF(active_users, 0), 2) AS clicks_per_user
	FROM clients_clean
)
SELECT
	company_name,
	team_id,
	snapshot_month,
	clicks_per_user,
	LAG(clicks_per_user) OVER (
		PARTITION BY team_id
		ORDER BY snapshot_month
	) AS prev_clicks_per_user,
	clicks_per_user
		- LAG(clicks_per_user) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS clicks_per_user_delta,
	ROUND(
		(clicks_per_user - LAG(clicks_per_user) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		))
		/ NULLIF(
			LAG(clicks_per_user) OVER (
				PARTITION BY team_id
				ORDER BY snapshot_month
			), 0
		) * 100,
		2
	) AS clicks_per_user_pct_change
FROM base
ORDER BY company_name, snapshot_month;


DROP VIEW IF EXISTS engagement_trend;
CREATE VIEW engagement_trend AS
-- 3-month rolling average of clicks per user, with a delta
-- showing whether engagement is improving or declining.
WITH base AS (
	SELECT
		team_id,
		company_name,
		snapshot_month,
		ROUND(
			total_clicks_wo_api * 1.0 / NULLIF(active_users, 0),
			2
		) AS clicks_per_user
	FROM clients_clean
),
rolling AS (
	SELECT
		team_id,
		company_name,
		snapshot_month,
		clicks_per_user,
		AVG(clicks_per_user) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
			ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
		) AS clicks_per_user_3m_avg
	FROM base
)
SELECT
	*,
	clicks_per_user_3m_avg
		- LAG(clicks_per_user_3m_avg) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS engagement_delta
FROM rolling;


DROP VIEW IF EXISTS user_trend_monthly;
CREATE VIEW user_trend_monthly AS
-- Month-on-month active user change with percentage.
WITH base AS (
	SELECT
		team_id,
		snapshot_month,
		active_users,
		active_users
			- LAG(active_users) OVER (
				PARTITION BY team_id
				ORDER BY snapshot_month
			) AS prev_active_users
	FROM clients_clean
)
SELECT
	*,
	active_users - prev_active_users AS users_delta,
	ROUND(
		(active_users - prev_active_users) * 1.0
		/ NULLIF(prev_active_users, 0),
		3
	) AS users_pct_change
FROM base;


DROP VIEW IF EXISTS user_mom_severity;
CREATE VIEW user_mom_severity AS
-- Earlier prototype combining engagement and user penalties
-- against the latest snapshot only (not historical).
-- Superseded by the monthly penalty views in 07_penalty_views.sql.
-- Retained for reference; not actively used by the app.
SELECT
	ls.team_id,
	ls.company_name,
	ls.snapshot_month,
	CASE
		WHEN et.engagement_delta >= -0.05 THEN 0
		ELSE MIN(50, ABS(et.engagement_delta) * 100 * 1.2)
	END AS engagement_penalty,
	CASE
		WHEN ut.users_pct_change <= -0.20 THEN 25
		WHEN ut.users_pct_change <= -0.10 THEN 15
		WHEN ut.users_pct_change <= -0.05 THEN 5
		ELSE 0
	END AS user_mom_decline
FROM latest_snapshot ls
LEFT JOIN engagement_trend et
	ON ls.team_id = et.team_id
	AND ls.snapshot_month = et.snapshot_month
LEFT JOIN user_trend_monthly ut
	ON ls.team_id = ut.team_id
	AND ls.snapshot_month = ut.snapshot_month;
