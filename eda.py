"""
EV Charging Analytics - Exploratory Data Analysis
Creates business-level summaries and Matplotlib charts.
"""

from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

DATA_DIR = Path("../data")
OUTPUT_DIR = Path("../outputs")
CHART_DIR = OUTPUT_DIR / "charts"
CHART_DIR.mkdir(parents=True, exist_ok=True)


def load_clean_data():
    cleaned_file = OUTPUT_DIR / "cleaned_charging_sessions.csv"

    if cleaned_file.exists():
        df = pd.read_csv(cleaned_file, parse_dates=["start_time", "end_time"])
    else:
        df = pd.read_csv(DATA_DIR / "charging_sessions.csv",
                         parse_dates=["start_time", "end_time"])

    return df[df["session_status"] == "Completed"].copy()


def create_summaries(df):
    station = (
        df.groupby("station_id")
        .agg(
            sessions=("session_id", "count"),
            energy_kwh=("energy_kwh", "sum"),
            revenue=("charging_cost", "sum"),
            avg_duration=("duration_minutes", "mean"),
            avg_waiting=("waiting_time_minutes", "mean")
        )
        .reset_index()
        .sort_values("revenue", ascending=False)
    )

    hourly = (
        df.groupby("hour")
        .agg(
            sessions=("session_id", "count"),
            energy_kwh=("energy_kwh", "sum"),
            revenue=("charging_cost", "sum")
        )
        .reset_index()
    )

    monthly = (
        df.groupby("month")
        .agg(
            sessions=("session_id", "count"),
            energy_kwh=("energy_kwh", "sum"),
            revenue=("charging_cost", "sum")
        )
        .reset_index()
    )

    charger = (
        df.groupby("charger_id")
        .agg(
            sessions=("session_id", "count"),
            energy_kwh=("energy_kwh", "sum"),
            revenue=("charging_cost", "sum"),
            avg_duration=("duration_minutes", "mean")
        )
        .reset_index()
    )

    return station, hourly, monthly, charger


def save_summary_tables(station, hourly, monthly, charger):
    station.to_csv(OUTPUT_DIR / "station_summary.csv", index=False)
    hourly.to_csv(OUTPUT_DIR / "hourly_summary.csv", index=False)
    monthly.to_csv(OUTPUT_DIR / "monthly_summary.csv", index=False)
    charger.to_csv(OUTPUT_DIR / "charger_summary.csv", index=False)


def make_charts(station, hourly, monthly):
    # 1. Hourly demand
    plt.figure(figsize=(10, 5))
    plt.plot(hourly["hour"], hourly["sessions"], marker="o")
    plt.title("EV Charging Demand by Hour")
    plt.xlabel("Hour of Day")
    plt.ylabel("Charging Sessions")
    plt.xticks(range(24))
    plt.tight_layout()
    plt.savefig(CHART_DIR / "hourly_demand.png", dpi=150)
    plt.close()

    # 2. Monthly revenue
    plt.figure(figsize=(10, 5))
    plt.plot(monthly["month"], monthly["revenue"], marker="o")
    plt.title("Monthly Charging Revenue")
    plt.xlabel("Month")
    plt.ylabel("Revenue")
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(CHART_DIR / "monthly_revenue.png", dpi=150)
    plt.close()

    # 3. Station revenue
    top = station.head(10).sort_values("revenue")
    plt.figure(figsize=(10, 6))
    plt.barh(top["station_id"], top["revenue"])
    plt.title("Top Stations by Revenue")
    plt.xlabel("Revenue")
    plt.ylabel("Station")
    plt.tight_layout()
    plt.savefig(CHART_DIR / "station_revenue.png", dpi=150)
    plt.close()

    # 4. Waiting time distribution
    plt.figure(figsize=(10, 5))
    plt.hist(
        station["avg_waiting"],
        bins=10
    )
    plt.title("Distribution of Average Station Waiting Time")
    plt.xlabel("Average Waiting Time (minutes)")
    plt.ylabel("Number of Stations")
    plt.tight_layout()
    plt.savefig(CHART_DIR / "waiting_time_distribution.png", dpi=150)
    plt.close()


def main():
    df = load_clean_data()
    station, hourly, monthly, charger = create_summaries(df)

    save_summary_tables(station, hourly, monthly, charger)
    make_charts(station, hourly, monthly)

    print("EDA completed.")
    print("\nTop 5 stations by revenue:")
    print(station.head(5).to_string(index=False))
    print("\nPeak demand hours:")
    print(hourly.sort_values("sessions", ascending=False).head(5).to_string(index=False))


if __name__ == "__main__":
    main()
