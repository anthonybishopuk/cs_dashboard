CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE IF NOT EXISTS "clients_raw"(
  id INT,
  company_name TEXT,
  team_id INT,
  is_test INT,
  region TEXT,
  snapshot_month TEXT,
  source_file TEXT,
  load_date TEXT,
  total_clicks INT,
  total_clicks_wo_api INT,
  non_jobs_clicks INT,
  view_candidates INT,
  active_coddlers INT,
  monthly_fee REAL,
  monthly_fee_currency TEXT,
  number_candidate_emails INT,
  number_contact_emails INT,
  salesperson TEXT,
  latest_contract_end_date TEXT,
  active_harvester_accounts INT,
  active_users INT,
  total_resumes INT,
  total_jobs INT,
  hires_in_past_year INT
);
CREATE VIEW clients_clean AS
SELECT
	company_name,
	team_id,
	is_test,
	region,
	snapshot_month,
	source_file,
	load_date,
	total_clicks,
	total_clicks_wo_api,
	non_jobs_clicks,
	view_candidates,
	active_coddlers,
	CAST(REPLACE(monthly_fee, ',', '') AS REAL) AS monthly_fee,
	monthly_fee_currency,
	number_candidate_emails,
	number_contact_emails,
	salesperson,
	substr(latest_contract_end_date, 7, 4) || '-' ||
	substr(latest_contract_end_date, 1, 2) || '-' ||
	substr(latest_contract_end_date, 4, 2) AS latest_contract_end_date,
	active_harvester_accounts,
	active_users,
	total_resumes,
	total_jobs,
	hires_in_past_year
FROM clients_raw
WHERE is_test IS NOT TRUE
/* clients_clean(company_name,team_id,is_test,region,snapshot_month,source_file,load_date,total_clicks,total_clicks_wo_api,non_jobs_clicks,view_candidates,active_coddlers,monthly_fee,monthly_fee_currency,number_candidate_emails,number_contact_emails,salesperson,latest_contract_end_date,active_harvester_accounts,active_users,total_resumes,total_jobs,hires_in_past_year) */;
CREATE VIEW latest_snapshot AS
SELECT *,
	CASE 
		WHEN active_users BETWEEN 1 and 9 THEN 'micro'
		WHEN active_users BETWEEN 10 and 49 THEN 'small'
		WHEN active_users BETWEEN 50 and 250 THEN 'medium'
		WHEN active_users >= 250 THEN 'large'
		ELSE 'unknown'
	END AS company_size
FROM clients_clean cc 
WHERE snapshot_month = (
	SELECT MAX(snapshot_month) FROM clients_clean
)
/* latest_snapshot(company_name,team_id,is_test,region,snapshot_month,source_file,load_date,total_clicks,total_clicks_wo_api,non_jobs_clicks,view_candidates,active_coddlers,monthly_fee,monthly_fee_currency,number_candidate_emails,number_contact_emails,salesperson,latest_contract_end_date,active_harvester_accounts,active_users,total_resumes,total_jobs,hires_in_past_year,company_size) */;
CREATE VIEW previous_snapshot AS
SELECT *
FROM clients_clean cc 
WHERE snapshot_month = (
	SELECT MAX(snapshot_month) 
	FROM clients_clean
	WHERE snapshot_month < (SELECT MAX(snapshot_month) FROM clients_clean
	)
)
/* previous_snapshot(company_name,team_id,is_test,region,snapshot_month,source_file,load_date,total_clicks,total_clicks_wo_api,non_jobs_clicks,view_candidates,active_coddlers,monthly_fee,monthly_fee_currency,number_candidate_emails,number_contact_emails,salesperson,latest_contract_end_date,active_harvester_accounts,active_users,total_resumes,total_jobs,hires_in_past_year) */;
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
    ON l.team_id = p.team_id
/* growth_summary(team_id,company_name,users_current,users_previous,users_change,clicks_current,clicks_previous,clicks_change,fee_current,fee_previous,fee_change,jobs_current,jobs_previous,jobs_change,user_trend) */;
CREATE VIEW start_date AS
SELECT
	team_id,
	MIN(snapshot_month) AS first_seen_month
FROM  clients_clean cc
GROUP BY cc.team_id
/* start_date(team_id,first_seen_month) */;
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
FROM latest_snapshot
/* contract_status(team_id,company_name,latest_contract_end_date,days_to_contract_end,contract_status) */;
CREATE VIEW client_tenure AS
SELECT
	ls.team_id,
	ls.company_name,
	sd.first_seen_month,
	CAST(
		(JULIANDAY(ls.snapshot_month) - JULIANDAY(sd.first_seen_month)) / 30 AS INTEGER
	) AS months_since_start
FROM latest_snapshot ls
JOIN start_date sd
	ON ls.team_id = sd.team_id
/* client_tenure(team_id,company_name,first_seen_month,months_since_start) */;
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
	ON ls.team_id = ct.team_id
/* at_risk_watchlist(team_id,company_name,region,company_size,active_users,total_clicks_wo_api,monthly_fee,fee_per_user,latest_contract_end_date,days_to_contract_end,contract_status,user_trend,months_since_start,client_stage,risk_flag) */;
CREATE VIEW monthly_usage AS
SELECT
    snapshot_month,
    region,
    team_id,
    company_name,
    total_clicks_wo_api,
	active_users,
	active_coddlers,
	monthly_fee,
    COALESCE(
        total_jobs
          - LAG(total_jobs) OVER (
                PARTITION BY team_id
                ORDER BY snapshot_month
            ),
        0
    ) AS jobs_posted
FROM clients_clean
/* monthly_usage(snapshot_month,region,team_id,company_name,total_clicks_wo_api,active_users,active_coddlers,monthly_fee,jobs_posted) */;
CREATE VIEW clicks_per_user_trend AS
WITH base AS(
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
		)
		)
		/ NULLIF(
			LAG(clicks_per_user) OVER (
				PARTITION BY team_id
				ORDER BY snapshot_month
			),
			0
		) * 100,
		2
	) AS clicks_per_user_pct_change
FROM base
ORDER BY company_name, snapshot_month
/* clicks_per_user_trend(company_name,team_id,snapshot_month,clicks_per_user,prev_clicks_per_user,clicks_per_user_delta,clicks_per_user_pct_change) */;
CREATE VIEW engagement_trend AS
WITH base AS (
	SELECT
	team_id,
	company_name,
	snapshot_month,
	ROUND(
		cc.total_clicks_wo_api * 1.0 / NULLIF(active_users, 0),
		2
	) AS clicks_per_user
	FROM clients_clean cc
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
FROM rolling
/* engagement_trend(team_id,company_name,snapshot_month,clicks_per_user,clicks_per_user_3m_avg,engagement_delta) */;
CREATE VIEW user_trend_monthly AS
WITH base AS(
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
		/NULLIF(prev_active_users, 0),
		3
	) AS users_pct_change
FROM base
/* user_trend_monthly(team_id,snapshot_month,active_users,prev_active_users,users_delta,users_pct_change) */;
CREATE VIEW user_sharp_decline_penalty AS
-- User base metrics - pull in all necessary columns
WITH base_metrics AS (
	SELECT 
		team_id,
		company_name,
		snapshot_month,
		active_users
	FROM clients_clean
),
-- User trends - calculate month on month trend (via LAG)
user_trends AS (
	SELECT *,
	LAG(active_users) OVER (
		PARTITION BY team_id
		ORDER BY snapshot_month
	) AS prev_active_users,
	(active_users - LAG(active_users) OVER (
		PARTITION BY team_id
		ORDER BY snapshot_month
		)
	) * 1.0
	/NULLIF(
		LAG(active_users) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		),
		0
	) AS user_pct_change
	FROM base_metrics
),
sharp_decline_window AS(
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
SELECT
	*
FROM user_sharp_decline
ORDER BY team_id, snapshot_month
/* user_sharp_decline_penalty(team_id,company_name,snapshot_month,active_users,prev_active_users,user_pct_change,worst_3m_pct_change,is_user_sharp_decline,sharp_decline_penalty) */;
CREATE VIEW user_monthly_penalty AS
-- User base metrics - pull in all necessary columns
WITH base_metrics AS (
	SELECT 
		team_id,
		company_name,
		snapshot_month,
		active_users
	FROM clients_clean
),
-- User trends - calculate month on month trend (via LAG)
user_trends AS (
	SELECT *,
	LAG(active_users) OVER (
		PARTITION BY team_id
		ORDER BY snapshot_month
	) AS prev_active_users,
	(active_users - LAG(active_users) OVER (
		PARTITION BY team_id
		ORDER BY snapshot_month
		)
	) * 1.0
	/NULLIF(
		LAG(active_users) OVER (
			PARTITION BY team_id
			ORDER BY snapshot_month
		),
		0
	) AS user_pct_change
	FROM base_metrics
),
-- User decline flags - turn percentages into signals
user_decline_flags AS (
	SELECT 
		*,
		CASE
			WHEN user_pct_change < 0 THEN 1
			ELSE 0
		END AS are_users_declining
	FROM user_trends	
),
-- User resets - identify when decline streaks reset
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
-- User streaks - measure how long decline has lasted
user_decline_streaks AS (
	SELECT 
		*,
		COUNT(*) OVER (
			PARTITION BY team_id, reset_group
		) AS decline_streak_length
	FROM user_resets
	WHERE are_users_declining = 1
),
-- User penalties - convert streaks and severity into penalty points
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
SELECT
	*
FROM user_penalties
ORDER BY team_id, snapshot_month
/* user_monthly_penalty(team_id,company_name,snapshot_month,active_users,prev_active_users,user_pct_change,are_users_declining,reset_group,decline_streak_length,user_penalty) */;
CREATE VIEW pricing_exposure_monthly AS
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
ORDER BY team_id, snapshot_month
/* pricing_exposure_monthly(team_id,company_name,snapshot_month,monthly_fee,active_users,company_size,fee_per_user,has_pricing_data) */;
CREATE VIEW user_mom_severity AS
SELECT
    ls.team_id,
    ls.company_name,
    ls.snapshot_month,
    /* engagement penalty */
    CASE
        WHEN et.engagement_delta >= -0.05 THEN 0
        ELSE MIN(
            50,
            ABS(et.engagement_delta) * 100 * 1.2
        )
    END AS engagement_penalty,
    /* user penalty */
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
    AND ls.snapshot_month = ut.snapshot_month
/* user_mom_severity(team_id,company_name,snapshot_month,engagement_penalty,user_mom_decline) */;
CREATE VIEW engagement_penalty_monthly AS
-- Monthly engagement metrics per client
WITH base_metrics AS(
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
	FROM clients_clean cc
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
-- Count the streak lengths
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
ORDER BY team_id, snapshot_month
/* engagement_penalty_monthly(team_id,snapshot_month,decline_streak_length,engagement_penalty) */;
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
jobs_posted_penalty_monthly AS (
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
SELECT
	*
FROM jobs_posted_penalty_monthly
ORDER BY
	team_id, snapshot_month
/* jobs_posted_penalty_monthly(team_id,snapshot_month,decline_streak_length,jobs_posted_penalty) */;
CREATE VIEW overall_health_score AS
WITH base_metrics AS (
SELECT
	cc.team_id,
	cc.company_name,
	cc.snapshot_month,
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
FROM base_metrics
/* overall_health_score(team_id,company_name,snapshot_month,overall_health_score,engagement_penalty,user_penalty,sharp_decline_penalty,fee_per_user,health_band) */;
CREATE VIEW health_penalties AS
SELECT
    ls.team_id,
    ls.company_name,
    ls.snapshot_month,
    /* engagement penalty */
    CASE
        WHEN et.engagement_delta >= -0.05 THEN 0
        ELSE MIN(
            50,
            ABS(et.engagement_delta) * 100 * 1.2
        )
    END AS engagement_penalty,
    /* user penalty */
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
    AND ls.snapshot_month = ut.snapshot_month
/* health_penalties(team_id,company_name,snapshot_month,engagement_penalty,user_penalty) */;
CREATE VIEW health_score_monthly AS
SELECT
    team_id,
    company_name,
    snapshot_month,
    MAX(
        0,
        ROUND(100 - engagement_penalty - user_penalty)
    ) AS health_score
FROM health_penalties
/* health_score_monthly(team_id,company_name,snapshot_month,health_score) */;
CREATE VIEW health_narrative_monthly AS
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
        -- Engagement narrative
        CASE
            WHEN decline_streak_length >= 4
                THEN 'Engagement has declined for several consecutive months. '
            WHEN decline_streak_length BETWEEN 2 AND 3
                THEN 'Engagement is trending down compared to previous months. '
            ELSE ''
        END AS engagement_narrative,
        -- User licence narrative
        CASE
            WHEN user_penalty > 0
                THEN 'Active user numbers have reduced over recent periods. '
            ELSE ''
        END AS user_narrative,
        -- Sharp user drop narrative
        CASE
            WHEN sharp_decline_penalty > 0
                THEN 'A significant drop in active users was recorded recently. '
            ELSE ''
        END AS sharp_decline_narrative,
        -- Jobs activity narrative
        CASE
            WHEN jobs_posted_penalty > 0
                THEN 'Job posting activity has decreased compared to earlier months. '
            ELSE ''
        END AS jobs_narrative,
        -- Pricing exposure narrative
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
FROM narratives
/* health_narrative_monthly(team_id,company_name,snapshot_month,health_narrative) */;
CREATE VIEW at_risk_next_actions AS
SELECT
    ls.company_name,
    ls.team_id,
    ls.salesperson,
    ohs.overall_health_score,
    hnm.health_narrative,
    arw.risk_flag,
    arw.contract_status,
    arw.days_to_contract_end,
    arw.user_trend,
    et.engagement_delta,
    ls.company_size,
    CASE
        WHEN ohs.overall_health_score < 40
            THEN 'Urgent outreach – disengaging'
        WHEN arw.contract_status = 'Expired'
            THEN 'Commercial check-in'
        WHEN arw.contract_status LIKE 'Renegotiate%'
            THEN 'Renewal conversation'
        WHEN arw.user_trend = 'Declining'
            THEN 'Adoption review'
        WHEN ls.company_size IN ('medium','large')
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
ORDER BY ohs.overall_health_score ASC, arw.company_size
/* at_risk_next_actions(company_name,team_id,salesperson,overall_health_score,health_narrative,risk_flag,contract_status,days_to_contract_end,user_trend,engagement_delta,company_size,recommended_action) */;
CREATE VIEW health_score_monthly_enriched AS
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
ORDER BY ohs.snapshot_month DESC
/* health_score_monthly_enriched(team_id,company_name,snapshot_month,overall_health_score,health_band,health_narrative) */;
CREATE VIEW onboarding_clients AS
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
WHERE co.client_stage = "Onboarding"
/* onboarding_clients(team_id,company_name,salesperson,client_stage,months_since_start,onboarding_age_band,region,snapshot_month,total_clicks_wo_api,active_coddlers,monthly_fee,has_paid_users,active_users,total_resumes,total_jobs,hires_in_past_year) */;
CREATE VIEW company_overview AS
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
	AND ls.snapshot_month = ohs.snapshot_month
/* company_overview(team_id,company_name,company_size,region,monthly_fee,salesperson,months_since_start,client_stage,overall_health_score) */;
