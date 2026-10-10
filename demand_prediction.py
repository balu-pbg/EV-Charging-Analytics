import pandas as pd
import numpy as np

from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

# Load charging session data
df = pd.read_csv("data/charging_sessions.csv")
chargers = pd.read_csv("data/chargers.csv")

station_capacity = (
    chargers.groupby("station_id")
    .size()
    .reset_index(name="charger_count")
)
print("Dataset shape:", df.shape)
print(df.head())

# Check date/time columns
print("\nColumn names:")
print(df.columns.tolist())

print("\nData types:")
print(df.dtypes)

# Create hourly charging demand
df["start_time"] = pd.to_datetime(df["start_time"])

df["date"] = df["start_time"].dt.date
df["hour"] = df["start_time"].dt.hour

completed = df[df["session_status"] == "Completed"].copy()

completed["start_time"] = pd.to_datetime(completed["start_time"])

hourly_demand = (
    completed
    .set_index("start_time")
    .groupby("station_id")
    .resample("h")
    .size()
    .reset_index(name="session_count")
)

hourly_demand["date"] = hourly_demand["start_time"].dt.date
hourly_demand["hour"] = hourly_demand["start_time"].dt.hour

hourly_demand = hourly_demand.sort_values(
    ["station_id", "date", "hour"]
).reset_index(drop=True)

hourly_demand["previous_hour_demand"] = (
    hourly_demand.groupby("station_id")["session_count"].shift(1)
)

hourly_demand["previous_day_demand"] = (
    hourly_demand.groupby("station_id")["session_count"].shift(24)
)

hourly_demand = hourly_demand.dropna().reset_index(drop=True)
hourly_demand = hourly_demand.merge(
    station_capacity,
    on="station_id",
    how="left"
)

print("\nHourly demand:")
print(hourly_demand.head())

print("\nHourly demand shape:", hourly_demand.shape)

# Create prediction features
hourly_demand["station_code"] = (
    hourly_demand["station_id"].astype("category").cat.codes
)
hourly_demand["date"] = pd.to_datetime(hourly_demand["date"])

hourly_demand["day_of_week"] = hourly_demand["date"].dt.dayofweek
hourly_demand["day_of_month"] = hourly_demand["date"].dt.day
hourly_demand["month"] = hourly_demand["date"].dt.month
hourly_demand["is_weekend"] = (
    hourly_demand["day_of_week"] >= 5
).astype(int)

print("\nPrediction features:")
print(hourly_demand.head())

# Select features and target
features = [
    "station_code",
    "charger_count",
    "hour",
    "day_of_week",
    "day_of_month",
    "month",
    "is_weekend",
    "previous_hour_demand",
    "previous_day_demand"
]
X = hourly_demand[features]
y = hourly_demand["session_count"]

print("\nFeatures:")
print(X.head())

print("\nTarget:")
print(y.head())

# Split data into training and testing sets
split_index = int(len(X) * 0.8)

X_train = X.iloc[:split_index]
X_test = X.iloc[split_index:]

y_train = y.iloc[:split_index]
y_test = y.iloc[split_index:]
print("\nTraining samples:", len(X_train))
print("Testing samples:", len(X_test))

# Create Random Forest model
model = RandomForestRegressor(
    n_estimators=300,
    max_depth=10,
    min_samples_leaf=2,
    random_state=42
)

# Train the model
model.fit(X_train, y_train)

print("\nModel training completed successfully!")

# Make predictions
y_pred = model.predict(X_test)

print("\nActual vs Predicted:")
comparison = pd.DataFrame({
    "Actual Sessions": y_test.values,
    "Predicted Sessions": np.round(y_pred, 0)
})

print(comparison.head(10))

# Evaluate model performance
mae = mean_absolute_error(y_test, y_pred)
rmse = np.sqrt(mean_squared_error(y_test, y_pred))
r2 = r2_score(y_test, y_pred)

print("\nModel Performance")
print("------------------")
print("MAE :", round(mae, 2))
print("RMSE:", round(rmse, 2))
print("R²  :", round(r2, 2))

# Create prediction results
prediction_results = X_test.copy()

prediction_results["actual_sessions"] = y_test.values
prediction_results["predicted_sessions"] = np.round(y_pred, 0)

# Save prediction results
prediction_results.to_csv(
    "data/demand_predictions.csv",
    index=False
)

print("\nPrediction results saved successfully!")
print(prediction_results.head(10))

# Feature importance
feature_importance = pd.DataFrame({
    "Feature": features,
    "Importance": model.feature_importances_
})

feature_importance = feature_importance.sort_values(
    by="Importance",
    ascending=False
)

print("\nFeature Importance:")
print(feature_importance)

import matplotlib.pyplot as plt

# Plot actual vs predicted demand
plt.figure(figsize=(10, 5))

plt.plot(
    y_test.values[:50],
    label="Actual Sessions",
    marker="o"
)

plt.plot(
    y_pred[:50],
    label="Predicted Sessions",
    marker="x"
)

plt.title("Actual vs Predicted EV Charging Demand")
plt.xlabel("Test Sample")
plt.ylabel("Number of Sessions")
plt.legend()
plt.tight_layout()

import os

os.makedirs("visualizations/charts", exist_ok=True)
plt.savefig("visualizations/charts/actual_vs_predicted_demand.png")

plt.show()

# Add demand level to predictions
prediction_results["demand_level"] = pd.cut(
    prediction_results["predicted_sessions"],
    bins=[-1, 10, 20, 30, float("inf")],
    labels=["Low", "Normal", "High", "Critical"]
)

print("\nPredicted Demand Classification:")
print(
    prediction_results[
        ["hour", "predicted_sessions", "demand_level"]
    ].head(10)
)

# Save updated predictions
prediction_results.to_csv(
    "../data/demand_predictions.csv",
    index=False
)