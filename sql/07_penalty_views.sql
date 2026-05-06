-- Penalty scoring views
-- Each view calculates penalty points for a specific signal.
-- Penalties are later combined in overall_health_score (08_health_views.sql).


DROP VIEW IF EXISTS engagement_penalty_monthly;
CREATE VIEW engagement_penalty_monthly AS
-- Monthly engagement metrics per client
WITH base_metrics AS (
	SELECT
		team_id,
		company_name,
		snapshot_month,
		total_clicks_wo_api,
		active_users,
		ROUND(
			total_clicks_wo_api * 1.0 / NULLIF(active_users, 0),
			2
		) AS clicks_per_user
	FROM clients_clean
),
-- Month-on-month engagement comparison
engagement_trends AS (
	SELECT
		*,
		LAG(clicks_per_user) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS prev_clicks_per_user,
		ROUND(
			(clicks_per_user
			 - LAG(clicks_per_user) OVER (
				PARTITION BY team_id
				ORDER BY snapshot_month
			 )
			)
			/ NULLIF(
				LAG(clicks_per_user) OVER (
					PARTITION BY team_id
					ORDER BY snapshot_month
				), 0
			),
			4
		) AS clicks_per_user_pct_change
	FROM base_metrics
),
-- Flag declining months
engagement_flags AS (
	SELECT
		*,
		CASE
			WHEN clicks_per_user_pct_change < 0 THEN 1
			ELSE 0
		END AS is_engagement_declining
	FROM engagement_trends
),
-- Create reset group when decline streak breaks
engagement_resets AS (
	SELECT
		*,
		SUM(
			CASE
				WHEN is_engagement_declining = 0 THEN 1
				ELSE 0
			END
		) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS reset_group
	FROM engagement_flags
),
-- Count streak lengths
engagement_streaks AS (
	SELECT
		team_id,
		snapshot_month,
		is_engagement_declining,
		reset_group,
		COUNT(*) OVER (
			PARTITION BY team_id, reset_group
		) AS decline_streak_length
	FROM engagement_resets
	WHERE is_engagement_declining = 1
),
engagement_penalties AS (
	SELECT
		team_id,
		snapshot_month,
		decline_streak_length,
		CASE
			WHEN decline_streak_length = 1 THEN 0
			WHEN decline_streak_length = 2 THEN 10
			WHEN decline_streak_length = 3 THEN 20
			WHEN decline_streak_length >= 4 THEN 40
		END AS engagement_penalty
	FROM engagement_streaks
)
SELECT
	team_id,
	snapshot_month,
	decline_streak_length,
	engagement_penalty
FROM engagement_penalties
ORDER BY team_id, snapshot_month;


DROP VIEW IF EXISTS user_monthly_penalty;
CREATE VIEW user_monthly_penalty AS
-- User base metrics
WITH base_metrics AS (
	SELECT
		team_id,
		company_name,
		snapshot_month,
		active_users
	FROM clients_clean
),
-- Month-on-month user trend
user_trends AS (
	SELECT
		*,
		LAG(active_users) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS prev_active_users,
		(active_users - LAG(active_users) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		)) * 1.0
		/ NULLIF(
			LAG(active_users) OVER (
				PARTITION BY team_id
				ORDER BY snapshot_month
			), 0
		) AS user_pct_change
	FROM base_metrics
),
-- Flag declining months
user_decline_flags AS (
	SELECT
		*,
		CASE
			WHEN user_pct_change < 0 THEN 1
			ELSE 0
		END AS are_users_declining
	FROM user_trends
),
-- Reset group when decline streak breaks
user_resets AS (
	SELECT
		*,
		SUM(
			CASE
				WHEN are_users_declining = 0 THEN 1
				ELSE 0
			END
		) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS reset_group
	FROM user_decline_flags
),
-- Streak lengths (declining months only)
user_decline_streaks AS (
	SELECT
		*,
		COUNT(*) OVER (
			PARTITION BY team_id, reset_group
		) AS decline_streak_length
	FROM user_resets
	WHERE are_users_declining = 1
),
-- Convert streaks to penalty points
user_penalties AS (
	SELECT
		*,
		CASE
			WHEN decline_streak_length = 1 THEN 0
			WHEN decline_streak_length = 2 THEN 5
			WHEN decline_streak_length = 3 THEN 10
			WHEN decline_streak_length >= 4 THEN 20
		END AS user_penalty
	FROM user_decline_streaks
)
SELECT *
FROM user_penalties
ORDER BY team_id, snapshot_month;


DROP VIEW IF EXISTS user_sharp_decline_penalty;
CREATE VIEW user_sharp_decline_penalty AS
-- Flags a sharp single-month user drop (>=20%) as an additional penalty,
-- independent of the streak-based user_monthly_penalty.
WITH base_metrics AS (
	SELECT
		team_id,
		company_name,
		snapshot_month,
		active_users
	FROM clients_clean
),
user_trends AS (
	SELECT
		*,
		LAG(active_users) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS prev_active_users,
		(active_users - LAG(active_users) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		)) * 1.0
		/ NULLIF(
			LAG(active_users) OVER (
				PARTITION BY team_id
				ORDER BY snapshot_month
			), 0
		) AS user_pct_change
	FROM base_metrics
),
sharp_decline_window AS (
	SELECT
		*,
		MIN(user_pct_change) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
			ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
		) AS worst_3m_pct_change
	FROM user_trends
),
user_sharp_decline AS (
	SELECT
		*,
		CASE
			WHEN worst_3m_pct_change <= -0.20 THEN 1
			ELSE 0
		END AS is_user_sharp_decline,
		CASE
			WHEN worst_3m_pct_change <= -0.20 THEN 10
			ELSE 0
		END AS sharp_decline_penalty
	FROM sharp_decline_window
)
SELECT *
FROM user_sharp_decline
ORDER BY team_id, snapshot_month;


DROP VIEW IF EXISTS jobs_posted_penalty_monthly;
CREATE VIEW jobs_posted_penalty_monthly AS
WITH base_metrics AS (
	SELECT
		team_id,
		company_name,
		snapshot_month,
		jobs_posted
	FROM monthly_usage
),
jobs_trends AS (
	SELECT
		*,
		LAG(jobs_posted) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS prev_jobs_posted,
		(jobs_posted - LAG(jobs_posted) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		)) * 1.0
		/ NULLIF(
			LAG(jobs_posted) OVER (
				PARTITION BY team_id
				ORDER BY snapshot_month
			), 0
		) AS jobs_pct_change
	FROM base_metrics
),
jobs_flags AS (
	SELECT
		*,
		CASE
			WHEN jobs_pct_change < 0 THEN 1
			ELSE 0
		END AS is_jobs_declining
	FROM jobs_trends
),
jobs_resets AS (
	SELECT
		*,
		SUM(
			CASE
				WHEN is_jobs_declining = 0 THEN 1
				ELSE 0
			END
		) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		) AS reset_group
	FROM jobs_flags
),
jobs_streaks AS (
	SELECT
		team_id,
		snapshot_month,
		reset_group,
		COUNT(*) OVER (
			PARTITION BY team_id, reset_group
		) AS decline_streak_length
	FROM jobs_resets
	WHERE is_jobs_declining = 1
),
jobs_penalties AS (
	SELECT
		team_id,
		snapshot_month,
		decline_streak_length,
		CASE
			WHEN decline_streak_length = 1 THEN 0
			WHEN decline_streak_length = 2 THEN 5
			WHEN decline_streak_length = 3 THEN 15
			WHEN decline_streak_length = 4 THEN 30
			WHEN decline_streak_length >= 5 THEN 45
		END AS jobs_posted_penalty
	FROM jobs_streaks
)
SELECT *
FROM jobs_penalties
ORDER BY team_id, snapshot_month;


DROP VIEW IF EXISTS pricing_exposure_monthly;
CREATE VIEW pricing_exposure_monthly AS
-- Joins current monthly_fee and active_users from latest_snapshot
-- against all historical months to give a consistent per-user cost signal.
WITH base_metrics AS (
	SELECT
		cc.team_id,
		cc.company_name,
		cc.snapshot_month,
		ls.monthly_fee,
		ls.active_users,
		ls.company_size
	FROM clients_clean cc
	LEFT JOIN latest_snapshot ls
		ON cc.team_id = ls.team_id
)
SELECT
	*,
	CASE
		WHEN monthly_fee IS NULL THEN NULL
		WHEN active_users IS NULL OR active_users = 0 THEN NULL
		ELSE ROUND(monthly_fee * 1.0 / active_users, 2)
	END AS fee_per_user,
	CASE
		WHEN monthly_fee IS NULL OR monthly_fee = 0 THEN 0
		ELSE 1
	END AS has_pricing_data
FROM base_metrics
ORDER BY team_id, snapshot_month;
