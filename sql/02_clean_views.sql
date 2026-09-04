-- Standardisation and casting
DROP VIEW IF EXISTS clients_clean;
-- clients_clean source

CREATE VIEW clients_clean AS
SELECT
	COALESCE(cno.override_name, cr.company_name) AS	company_name,
	cr.team_id,
	cr.is_test,
	cr.region,
	cr.snapshot_month,
	cr.source_file,
	cr.load_date,
	cr.total_clicks,
	cr.total_clicks_wo_api,
	cr.non_jobs_clicks,
	cr.view_candidates,
	cr.active_coddlers,
	CAST(REPLACE(cr.monthly_fee, ',', '') AS REAL) AS monthly_fee,
	cr.monthly_fee_currency,
	cr.number_candidate_emails,
	cr.number_contact_emails,
	cr.salesperson,
	substr(cr.latest_contract_end_date, 7, 4) || '-' ||
	substr(cr.latest_contract_end_date, 1, 2) || '-' ||
	substr(cr.latest_contract_end_date, 4, 2) AS latest_contract_end_date,
	cr.active_harvester_accounts,
	cr.active_users,
	cr.total_resumes,
	cr.total_jobs,
	cr.hires_in_past_year
FROM clients_raw cr
LEFT JOIN company_name_overrides cno 
	ON cr.team_id = cno.team_id
WHERE is_test IS NOT TRUE
AND LOWER (cr.company_name) NOT LIKE '%test%'
AND LOWER (cr.company_name) NOT LIKE '%demo%'
AND LOWER (cr.company_name) NOT LIKE '%integration%'
AND LOWER (cr.company_name) NOT LIKE '%sandbox%'
AND LOWER (cr.company_name) NOT LIKE '%maria%'
AND LOWER (cr.company_name) NOT LIKE '%roula%'
AND LOWER (cr.company_name) NOT LIKE 'sassinova'
AND LOWER (cr.company_name) NOT LIKE '%beth%'
AND LOWER (cr.company_name) NOT LIKE '%angie%'
AND LOWER (cr.company_name) NOT LIKE '%charles%'
AND LOWER (cr.company_name) NOT LIKE '%database%'
AND LOWER (cr.company_name) NOT LIKE '%email%'
AND LOWER (cr.company_name) NOT LIKE '%harvest%'
AND LOWER (cr.company_name) NOT LIKE '%jana%'
AND LOWER (cr.company_name) NOT LIKE '%jobdiva%'
AND LOWER (cr.company_name) NOT LIKE '%qa%'
AND LOWER (cr.company_name) NOT LIKE '%divavms%'
AND cr.team_id NOT IN(
	SELECT team_id FROM excluded_accounts ea
	WHERE exclude_from_date IS NULL
)
AND NOT EXISTS (
	SELECT 1 FROM excluded_accounts ea
	WHERE ea.team_id = cr.team_id
	AND ea.exclude_from_date IS NOT NULL AND cr.snapshot_month >= ea.exclude_from_date
);