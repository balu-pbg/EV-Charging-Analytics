"""
EV Charging Analytics - Demand Analysis
Uses NumPy/Pandas to identify peak demand, station pressure,
capacity risk and simple next-day demand estimates.
"""

from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

DATA_DIR = Path("../data")
OUTPUT_DIR = Path("../outputs")
CHART_DIR = OUTPUT_DIR / "charts"
CHART_DIR.mkdir(parents=True, exist_ok=True)


def load_data():
    file = OUTPUT_DIR / "cleaned_charging_sessions.csv"

    if file.exists():
        df = pd.read_csv(file, parse_dates=["start_time", "end_time"])
    else:
        df = pd.read_csv(DATA_DIR / "charging_sessions.csv",
                         parse_dates=["start_time", "end_time"])

    return df[df["session_status"] == "Completed"].copy()


def demand_statistics(df):
    hourly = (
        df.groupby("hour")["session_id"]
        .count()
        .reindex(range(24), fill_value=0)
    )

    values = hourly.to_numpy()

    stats = {
        "mean_hourly_sessions": np.mean(values),
        "median_hourly_sessions": np.median(values),
        "std_hourly_sessions": np.std(values),
        "p90_hourly_sessions": np.percentile(values, 90),
        "max_hourly_sessions": np.max(values),
        "peak_hour": int(np.argmax(values)),
    }

    return hourly, stats


def station_pressure(df):
    station = (
        df.groupby("station_id")
        .agg(
            sessions=("session_id", "count"),
            avg_waiting=("waiting_time_minutes", "mean"),
            energy_kwh=("energy_kwh", "sum"),
            revenue=("charging_cost", "sum")
        )
        .reset_index()
    )

    station["sessions_per_day"] = (
        station["sessions"] /
        df["start_time"].dt.date.nunique()
    )

    # A simple operational pressure score.
    # Higher demand + longer waiting = greater pressure.
    station["demand_score"] = (
        station["sessions_per_day"] /
        station["sessions_per_day"].max()
    )

    station["wait_score"] = (
        station["avg_waiting"] /
        station["avg_waiting"].max()
    )

    station["pressure_score"] = (
        0.60 * station["demand_score"] +
        0.40 * station["wait_score"]
    ).round(3)

    station["capacity_action"] = np.select(
        [
            station["pressure_score"] >= 0.75,
            station["pressure_score"] >= 0.50
        ],
        [
            "HIGH PRIORITY - REVIEW CAPACITY",
            "MONITOR"
        ],
        default="NORMAL"
    )

    return station.sort_values("pressure_score", ascending=False)


def simple_next_day_forecast(df):
    # Baseline forecast: average demand for each weekday/hour
    temp = df.copy()
    temp["date"] = temp["start_time"].dt.date
    temp["weekday_num"] = temp["start_time"].dt.dayofweek

    daily_hourly = (
        temp.groupby(["weekday_num", "hour"])
        .size()
        .reset_index(name="sessions")
    )

    forecast = (
        daily_hourly.groupby("hour")["sessions"]
        .mean()
        .round(1)
        .reset_index(name="expected_sessions")
    )

    return forecast


def create_demand_chart(hourly):
    plt.figure(figsize=(10, 5))
    plt.plot(hourly.index, hourly.values, marker="o")
    plt.title("Hourly EV Charging Demand")
    plt.xlabel("Hour")
    plt.ylabel("Sessions")
    plt.xticks(range(24))
    plt.tight_layout()
    plt.savefig(CHART_DIR / "demand_analysis_hourly.png", dpi=150)
    plt.close()


def main():
    df = load_data()

    hourly, stats = demand_statistics(df)
    station = station_pressure(df)
    forecast = simple_next_day_forecast(df)

    hourly_df = hourly.rename("sessions").reset_index()
    hourly_df.to_csv(OUTPUT_DIR / "demand_by_hour.csv", index=False)
    station.to_csv(OUTPUT_DIR / "station_pressure_analysis.csv", index=False)
    forecast.to_csv(OUTPUT_DIR / "hourly_demand_forecast_baseline.csv", index=False)

    pd.DataFrame([stats]).to_csv(
        OUTPUT_DIR / "demand_statistics.csv", index=False
    )

    create_demand_chart(hourly)

    print("Demand analysis completed.")
    print("\nDemand statistics:")
    for key, value in stats.items():
        print(f"{key}: {value}")

    print("\nStations requiring attention:")
    print(
        station[
            ["station_id", "sessions_per_day", "avg_waiting",
             "pressure_score", "capacity_action"]
        ].head(10).to_string(index=False)
    )


if __name__ == "__main__":
    main()
