-- Standardisation and casting
DROP VIEW IF EXISTS clients_clean;
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
FROM clients_raw cr
WHERE is_test IS NOT TRUE
AND LOWER (cr.company_name) NOT LIKE '%test%'
AND LOWER (cr.company_name) NOT LIKE '%demo%'
AND LOWER (cr.company_name) NOT LIKE '%integration%'
AND LOWER (cr.company_name) NOT LIKE '%sandbox%'
AND LOWER (cr.company_name) NOT LIKE '%maria%'
AND LOWER (cr.company_name) NOT LIKE '%roula%'
AND LOWER (cr.company_name) NOT LIKE '%beth%'
AND LOWER (cr.company_name) NOT LIKE '%angie%'
AND LOWER (cr.company_name) NOT LIKE '%charles%'
AND LOWER (cr.company_name) NOT LIKE '%database%'
AND LOWER (cr.company_name) NOT LIKE '%email%'
AND LOWER (cr.company_name) NOT LIKE '%harvest%'
AND LOWER (cr.company_name) NOT LIKE '%jana%'
AND LOWER (cr.company_name) NOT LIKE '%jobdiva%'
AND LOWER (cr.company_name) NOT LIKE '%qa%'
AND cr.team_id NOT IN(
	SELECT team_id FROM excluded_accounts ea
);