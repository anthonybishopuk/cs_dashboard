import pandas as pd

def colour_health_band(row):
    colours = {
        "Critical": "background-color: #f8d7da",
        "At Risk": "background-color: #ffe5b4",
        "Watch": "background-color: #fff3cd",
        "Healthy": "background-color: #d4edda"
    }
    colour = colours.get(row["Health Band"], "")
    return [colour] * len(row)


def format_days(days):
    if pd.isna(days):
        return "Unknown. Please check"
    days = int(days)
    if days < 0:
        abs_days = abs(days)
        years = abs_days // 365
        months = (abs_days % 365) // 30
        if years > 0:
            return f"Expired {years}y {months}m ago"
        elif months > 0:
            return f"Expired {months} months ago"
        else:
            return f"Expired {abs_days} days ago"
    elif days == 0:
        return "Expires today"
    elif days <= 30:
        return f"{days} days (Urgent)"
    elif days <= 90:
        return f"{days} days (Renewal window)"
    else:
        years = days // 365
        months = (days % 365) // 30
        if years > 0:
            return f"{years}y {months}m remaining"
        else:
            return f"{days} days"