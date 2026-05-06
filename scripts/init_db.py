import sqlite3

conn = sqlite3.connect("data/client_success.db")
cursor = conn.cursor()

cursor.execute("""
CREATE TABLE IF NOT EXISTS clients_raw (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
               
            company_name TEXT,
            team_id INTEGER,
            
            is_test INTEGER,
            region TEXT,
            snapshot_month TEXT,
            source_file TEXT,
            load_date TEXT,
            
            total_clicks INTEGER,
            total_clicks_wo_api INTEGER,
            non_jobs_clicks INTEGER,
            view_candidates INTEGER,
            active_coddlers INTEGER,
               
            monthly_fee REAL,
            monthly_fee_currency TEXT,   

            number_candidate_emails INTEGER,
            number_contact_emails INTEGER,
               
            salesperson TEXT,
            latest_contract_end_date TEXT,
               
            active_harvester_accounts INTEGER,
            active_users INTEGER,
            total_resumes INTEGER,
            total_jobs INTEGER,
            hires_in_past_year INTEGER
            );
""")

conn.commit()
conn.close()
