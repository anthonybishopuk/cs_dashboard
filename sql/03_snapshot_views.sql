DROP VIEW IF EXISTS latest_snapshot;
DROP VIEW IF EXISTS previous_snapshot;

-- latest_snapshot source

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
);

-- previous snapshot source

CREATE VIEW previous_snapshot AS
SELECT *
FROM clients_clean cc 
WHERE snapshot_month = (
	SELECT MAX(snapshot_month) 
	FROM clients_clean
	WHERE snapshot_month < (SELECT MAX(snapshot_month) FROM clients_clean
	)
);