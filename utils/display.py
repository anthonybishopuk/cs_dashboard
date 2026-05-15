def colour_health_band(row):
    colours = {
        "Critical": "background-color: #f8d7da",
        "At Risk": "background-color: #ffe5b4",
        "Watch": "background-color: #fff3cd",
        "Healthy": "background-color: #d4edda"
    }
    colour = colours.get(row["health_band"], "")
    return [colour] * len(row)