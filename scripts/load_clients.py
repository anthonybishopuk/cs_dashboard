import pandas as pd
import sqlite3
from pathlib import Path
from datetime import date
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))

from config import DB_PATH, DATA_DIR

COLUMN_MAP = {
    "Company Name": "company_name",
    "Team ID": "team_id",
    "Total Clicks": "total_clicks",
    "Total Clicks without API": "total_clicks_wo_api",
    "Non-Jobs Clicks": "non_jobs_clicks",
    "View Candidate": "view_candidates",
    "Active Coddlers": "active_coddlers",
    "Montly Fee": "monthly_fee",
    "Number of Candidate Emails": "number_candidate_emails",
    "Number of Contact Emails": "number_contact_emails",
    "Salesperson": "salesperson",
    "Latest Contract End date": "latest_contract_end_date",
    "# of active harvester accounts": "active_harvester_accounts",
    "# of active users now": "active_users",
    "Total # of resumes": "total_resumes",
    "Total # of jobs": "total_jobs",
    "# of hires within the past year": "hires_in_past_year",
}

def infer_region(file_path: Path) -> str:
    return file_path.parent.name.upper()


def infer_month(file_path: Path) -> str:
    return f"{file_path.stem}-01"


def load_csv(file_path: Path, conn):
    snapshot_month = infer_month(file_path)
    region = infer_region(file_path)

    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT 1
        FROM clients_raw
        WHERE snapshot_month = ?
            AND region = ?
        LIMIT 1
        """,
        (snapshot_month, region)
    )
    
    if cursor.fetchone():
        print(f"Skipping {file_path.name} - snapshot {snapshot_month} already loaded")
        return

    df = pd.read_csv(file_path)

    df = df.rename(columns=COLUMN_MAP)

    df = df[list(COLUMN_MAP.values())]

    df["region"] = infer_region(file_path)
    df["snapshot_month"] = infer_month(file_path)
    df["source_file"] = f"{file_path.parent.name}/{file_path.name}"
    df["load_date"] = date.today().isoformat()
    df["is_test"] = None

    df.to_sql(
        "clients_raw",
        conn,
        if_exists="append",
        index=False
    )
    print(f"Loaded {len(df)} rows for {snapshot_month}")

def main():
    conn = sqlite3.connect(DB_PATH)

    for csv_file in DATA_DIR.rglob("*.csv"):
        print(f"Loading {csv_file}")
        load_csv(csv_file, conn)

    conn.close()
    print("Load complete.")


if __name__ == "__main__":
    main()
