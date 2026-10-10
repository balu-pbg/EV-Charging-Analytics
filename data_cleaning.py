"""
EV Charging Analytics - Data Cleaning
Reads the raw CSV files, validates relationships and values,
creates analytical features, and saves a cleaned session dataset.
"""

from pathlib import Path
import pandas as pd
import numpy as np

DATA_DIR = Path("../data")
OUTPUT_DIR = Path("../outputs")
OUTPUT_DIR.mkdir(exist_ok=True)


def load_data():
    stations = pd.read_csv(DATA_DIR / "stations.csv")
    chargers = pd.read_csv(DATA_DIR / "chargers.csv")
    customers = pd.read_csv(DATA_DIR / "customers.csv")
    sessions = pd.read_csv(DATA_DIR / "charging_sessions.csv")

    sessions["start_time"] = pd.to_datetime(sessions["start_time"], errors="coerce")
    sessions["end_time"] = pd.to_datetime(sessions["end_time"], errors="coerce")

    return stations, chargers, customers, sessions


def clean_sessions(stations, chargers, customers, sessions):
    df = sessions.copy()

    # Remove exact duplicate rows
    df = df.drop_duplicates()

    # Remove duplicate session IDs, keeping the first occurrence
    df = df.drop_duplicates(subset="session_id", keep="first")

    # Numeric columns
    numeric_cols = [
        "duration_minutes", "energy_kwh", "charging_cost",
        "waiting_time_minutes"
    ]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    # Correct duration from timestamps
    calculated_duration = (
        (df["end_time"] - df["start_time"]).dt.total_seconds() / 60
    )
    df["duration_minutes_calculated"] = calculated_duration.round()

    # Fill duration only when the source duration is missing/invalid
    invalid_duration = (
        df["duration_minutes"].isna() |
        (df["duration_minutes"] <= 0)
    )
    df.loc[invalid_duration, "duration_minutes"] = (
        df.loc[invalid_duration, "duration_minutes_calculated"]
    )

    # Remove impossible records
    df = df[
        (df["start_time"].notna()) &
        (df["end_time"].notna()) &
        (df["end_time"] >= df["start_time"]) &
        (df["duration_minutes"] > 0) &
        (df["energy_kwh"] > 0) &
        (df["charging_cost"] >= 0) &
        (df["waiting_time_minutes"] >= 0)
    ].copy()

    # Referential integrity checks
    valid_stations = set(stations["station_id"])
    valid_chargers = set(chargers["charger_id"])
    valid_customers = set(customers["customer_id"])

    df = df[
        df["station_id"].isin(valid_stations) &
        df["charger_id"].isin(valid_chargers) &
        df["customer_id"].isin(valid_customers)
    ].copy()

    # Feature engineering
    df["date"] = df["start_time"].dt.date
    df["hour"] = df["start_time"].dt.hour
    df["day_of_week"] = df["start_time"].dt.day_name()
    df["day_of_week_num"] = df["start_time"].dt.dayofweek
    df["day_type"] = np.where(df["day_of_week_num"] >= 5, "Weekend", "Weekday")
    df["month"] = df["start_time"].dt.to_period("M").astype(str)
    df["quarter"] = df["start_time"].dt.to_period("Q").astype(str)

    df["revenue_per_kwh"] = np.where(
        df["energy_kwh"] > 0,
        df["charging_cost"] / df["energy_kwh"],
        np.nan
    )

    df["energy_per_minute"] = np.where(
        df["duration_minutes"] > 0,
        df["energy_kwh"] / df["duration_minutes"],
        np.nan
    )

    df["peak_period"] = np.select(
        [
            df["hour"].between(7, 10),
            df["hour"].between(11, 16),
            df["hour"].between(17, 21)
        ],
        ["Morning Peak", "Afternoon", "Evening Peak"],
        default="Night"
    )

    df["high_wait_flag"] = np.where(
        df["waiting_time_minutes"] >= 15, 1, 0
    )

    df["high_value_flag"] = np.where(
        df["charging_cost"] >= df["charging_cost"].quantile(0.90), 1, 0
    )

    return df


def main():
    stations, chargers, customers, sessions = load_data()
    cleaned = clean_sessions(stations, chargers, customers, sessions)

    cleaned.to_csv(OUTPUT_DIR / "cleaned_charging_sessions.csv", index=False)

    quality = pd.DataFrame({
        "metric": [
            "Raw rows",
            "Cleaned rows",
            "Removed rows",
            "Missing start timestamps",
            "Missing end timestamps",
            "Duplicate session IDs",
        ],
        "value": [
            len(sessions),
            len(cleaned),
            len(sessions) - len(cleaned),
            sessions["start_time"].isna().sum(),
            sessions["end_time"].isna().sum(),
            sessions["session_id"].duplicated().sum(),
        ],
    })

    quality.to_csv(OUTPUT_DIR / "data_quality_report.csv", index=False)

    print("Data cleaning completed.")
    print(f"Raw rows: {len(sessions):,}")
    print(f"Cleaned rows: {len(cleaned):,}")
    print(f"Output: {OUTPUT_DIR / 'cleaned_charging_sessions.csv'}")


if __name__ == "__main__":
    main()
