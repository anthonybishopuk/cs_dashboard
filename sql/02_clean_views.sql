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
FROM clients_raw
WHERE is_test IS NOT TRUE;