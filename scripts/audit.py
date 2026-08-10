import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

import pandas as pd
from utils.db import load_pricing_audit

df = load_pricing_audit()

overpaying = df[df['fee_per_user'] > 150].copy()
underpaying = df[
    ((df['company_size'] == 'micro') & (df['fee_per_user'] < 70)) |
    ((df['company_size'] == 'small') & (df['fee_per_user'] < 50)) |
    ((df['company_size'] == 'medium') & (df['fee_per_user'] < 40)) |
    ((df['company_size'] == 'large') & (df['fee_per_user'] < 25)) |
    ((df['company_size'] == 'enterprise') & (df['fee_per_user'] < 10))
].copy()

with pd.ExcelWriter('data/pricing_audit.xlsx', engine='openpyxl') as writer:
    underpaying.to_excel(writer, sheet_name='Underpaying', index=False)
    overpaying.to_excel(writer, sheet_name='Overpaying', index=False)