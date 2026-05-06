-- Health scoring views
-- Combines penalty signals into an overall score, band, and narrative per client per month.
-- Dependency order: penalty views (07) must exist before running this file.


DROP VIEW IF EXISTS overall_health_score;
CREATE VIEW overall_health_score AS
WITH base_metrics AS (
	SELECT
		cc.team_id,
		cc.company_name,
		cc.snapshot_month,
		-- Sum all penalty sources; floor at 0
		CASE
			WHEN 100 - (
				COALESCE(ump.user_penalty, 0) +
				COALESCE(usdp.sharp_decline_penalty, 0) +
				COALESCE(epm.engagement_penalty, 0) +
				COALESCE(jppm.jobs_posted_penalty, 0)
			) < 0 THEN 0
			ELSE 100 - (
				COALESCE(ump.user_penalty, 0) +
				COALESCE(usdp.sharp_decline_penalty, 0) +
				COALESCE(epm.engagement_penalty, 0) +
				COALESCE(jppm.jobs_posted_penalty, 0)
			)
		END AS overall_health_score,
		epm.engagement_penalty,
		ump.user_penalty,
		usdp.sharp_decline_penalty,
		pem.fee_per_user
	FROM clients_clean cc
	LEFT JOIN engagement_penalty_monthly epm
		ON cc.team_id = epm.team_id
		AND cc.snapshot_month = epm.snapshot_month
	LEFT JOIN user_monthly_penalty ump
		ON cc.team_id = ump.team_id
		AND cc.snapshot_month = ump.snapshot_month
	LEFT JOIN user_sharp_decline_penalty usdp
		ON cc.team_id = usdp.team_id
		AND cc.snapshot_month = usdp.snapshot_month
	LEFT JOIN pricing_exposure_monthly pem
		ON cc.team_id = pem.team_id
		AND cc.snapshot_month = pem.snapshot_month
	LEFT JOIN jobs_posted_penalty_monthly jppm
		ON cc.team_id = jppm.team_id
		AND cc.snapshot_month = jppm.snapshot_month
	ORDER BY cc.snapshot_month DESC, overall_health_score ASC
)
SELECT
	*,
	CASE
		WHEN overall_health_score >= 80 THEN 'Healthy'
		WHEN overall_health_score >= 60 THEN 'Watch'
		WHEN overall_health_score >= 40 THEN 'At Risk'
		ELSE 'Critical'
	END AS health_band
FROM base_metrics;


DROP VIEW IF EXISTS health_penalties;
CREATE VIEW health_penalties AS
-- Simplified two-signal version (engagement + user).
-- Retained as a lighter alternative to overall_health_score.
-- Used by health_score_monthly.
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
	END AS user_penalty
FROM latest_snapshot ls
LEFT JOIN engagement_trend et
	ON ls.team_id = et.team_id
	AND ls.snapshot_month = et.snapshot_month
LEFT JOIN user_trend_monthly ut
	ON ls.team_id = ut.team_id
	AND ls.snapshot_month = ut.snapshot_month;


DROP VIEW IF EXISTS health_score_monthly;
CREATE VIEW health_score_monthly AS
-- Simpler two-signal health score, derived from health_penalties.
-- overall_health_score uses the fuller penalty model.
SELECT
	team_id,
	company_name,
	snapshot_month,
	MAX(0, ROUND(100 - engagement_penalty - user_penalty)) AS health_score
FROM health_penalties;


DROP VIEW IF EXISTS health_narrative_monthly;
CREATE VIEW health_narrative_monthly AS
-- Generates a plain-English summary of what is driving a client's score.
-- Each penalty source contributes a sentence; they are concatenated into health_narrative.
WITH base AS (
	SELECT
		cc.team_id,
		cc.company_name,
		cc.snapshot_month,
		epm.decline_streak_length,
		epm.engagement_penalty,
		ump.user_penalty,
		usdp.sharp_decline_penalty,
		jppm.jobs_posted_penalty,
		pem.fee_per_user,
		pem.has_pricing_data
	FROM clients_clean cc
	LEFT JOIN engagement_penalty_monthly epm
		ON cc.team_id = epm.team_id
		AND cc.snapshot_month = epm.snapshot_month
	LEFT JOIN user_monthly_penalty ump
		ON cc.team_id = ump.team_id
		AND cc.snapshot_month = ump.snapshot_month
	LEFT JOIN user_sharp_decline_penalty usdp
		ON cc.team_id = usdp.team_id
		AND cc.snapshot_month = usdp.snapshot_month
	LEFT JOIN jobs_posted_penalty_monthly jppm
		ON cc.team_id = jppm.team_id
		AND cc.snapshot_month = jppm.snapshot_month
	LEFT JOIN pricing_exposure_monthly pem
		ON cc.team_id = pem.team_id
		AND cc.snapshot_month = pem.snapshot_month
),
narratives AS (
	SELECT
		*,
		CASE
			WHEN decline_streak_length >= 4
				THEN 'Engagement has declined for several consecutive months. '
			WHEN decline_streak_length BETWEEN 2 AND 3
				THEN 'Engagement is trending down compared to previous months. '
			ELSE ''
		END AS engagement_narrative,
		CASE
			WHEN user_penalty > 0
				THEN 'Active user numbers have reduced over recent periods. '
			ELSE ''
		END AS user_narrative,
		CASE
			WHEN sharp_decline_penalty > 0
				THEN 'A significant drop in active users was recorded recently. '
			ELSE ''
		END AS sharp_decline_narrative,
		CASE
			WHEN jobs_posted_penalty > 0
				THEN 'Job posting activity has decreased compared to earlier months. '
			ELSE ''
		END AS jobs_narrative,
		CASE
			WHEN has_pricing_data = 1
			 AND fee_per_user IS NOT NULL
			 AND fee_per_user > 100
				THEN 'Cost per user is relatively high for the current licence base. '
			WHEN has_pricing_data = 1
			 AND fee_per_user IS NOT NULL
			 AND fee_per_user < 30
				THEN 'Account appears cost-efficient given current usage. '
			ELSE ''
		END AS pricing_narrative
	FROM base
)
SELECT
	team_id,
	company_name,
	snapshot_month,
	TRIM(
		COALESCE(engagement_narrative, '') ||
		COALESCE(user_narrative, '') ||
		COALESCE(sharp_decline_narrative, '') ||
		COALESCE(jobs_narrative, '') ||
		COALESCE(pricing_narrative, '')
	) AS health_narrative
FROM narratives;


DROP VIEW IF EXISTS health_score_monthly_enriched;
CREATE VIEW health_score_monthly_enriched AS
-- Convenience view combining overall_health_score with the narrative.
-- This is what the Client Focus page queries.
SELECT
	ohs.team_id,
	ohs.company_name,
	ohs.snapshot_month,
	ohs.overall_health_score,
	ohs.health_band,
	hnm.health_narrative
FROM overall_health_score ohs
LEFT JOIN health_narrative_monthly hnm
	ON ohs.team_id = hnm.team_id
	AND ohs.snapshot_month = hnm.snapshot_month
ORDER BY ohs.snapshot_month DESC;
