-- Client tenure and start date views

DROP VIEW IF EXISTS start_date;
CREATE VIEW start_date AS
SELECT
	team_id,
	MIN(snapshot_month) AS first_seen_month
FROM clients_clean
GROUP BY team_id;


DROP VIEW IF EXISTS client_tenure;
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
	ON ls.team_id = sd.team_id;
