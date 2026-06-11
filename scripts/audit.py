import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

import pandas as pd
from utils.db import load_pricing_audit

df = load_pricing_audit()

overpaying = df[df['fee_per_user'] > 150].copy()
underpaying = df[
    ((df['company_size'].isin(['micro', 'small'])) & (df['fee_per_user'] < 60)) |
    ((df['company_size'].isin(['medium', 'large'])) & (df['fee_per_user'] < 40))
].copy()

with pd.ExcelWriter('data/pricing_audit.xlsx', engine='openpyxl') as writer:
    overpaying.to_excel(writer, sheet_name='Overpaying', index=False)
    underpaying.to_excel(writer, sheet_name='Underpaying', index=False)
