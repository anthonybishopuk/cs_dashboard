import streamlit as st
from utils.db import load_companies
from config import DB_PATH

st.set_page_config(
    page_title="JobDiva CS Dashboard",
    layout="wide"
)

st.title("📊 JobDiva Customer Success Dashboard")
st.markdown("Use the sidebar to navigate between pages.")

st.divider()

col1, col2, col3 = st.columns(3)

with col1:
    st.page_link("pages/1_Portfolio_Overview.py", label="Portfolio Overview", icon="📈")

with col2:
    st.page_link("pages/2_Onboarding_Tracker.py", label="Onboarding Tracker", icon="🌱")

with col3:
    st.page_link("pages/3_Client_Review.py", label="Client Review", icon="🔍")