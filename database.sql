-- EV Charging Station Demand Analytics
-- MySQL 8.0+
-- Database setup + table definitions + CSV import commands

CREATE DATABASE IF NOT EXISTS ev_charging_analytics;
USE ev_charging_analytics;

DROP TABLE IF EXISTS charging_sessions;
DROP TABLE IF EXISTS chargers;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS stations;

CREATE TABLE stations (
    station_id VARCHAR(10) PRIMARY KEY,
    station_name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    station_type VARCHAR(30) NOT NULL,
    number_of_chargers INT NOT NULL,
    operating_hours VARCHAR(30)
);

CREATE TABLE chargers (
    charger_id VARCHAR(20) PRIMARY KEY,
    station_id VARCHAR(10) NOT NULL,
    charger_type VARCHAR(30) NOT NULL,
    power_kw DECIMAL(8,2) NOT NULL,
    initial_status VARCHAR(30),
    CONSTRAINT fk_charger_station
        FOREIGN KEY (station_id) REFERENCES stations(station_id)
);

CREATE TABLE customers (
    customer_id VARCHAR(12) PRIMARY KEY,
    customer_type VARCHAR(30) NOT NULL,
    vehicle_type VARCHAR(40) NOT NULL,
    home_city VARCHAR(50) NOT NULL
);

CREATE TABLE charging_sessions (
    session_id VARCHAR(15) PRIMARY KEY,
    station_id VARCHAR(10) NOT NULL,
    charger_id VARCHAR(20) NOT NULL,
    customer_id VARCHAR(12) NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    duration_minutes INT NOT NULL,
    energy_kwh DECIMAL(10,2) NOT NULL,
    charging_cost DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(30),
    waiting_time_minutes INT DEFAULT 0,
    session_status VARCHAR(30),
    day_of_week VARCHAR(15),
    is_weekend BOOLEAN,
    hour INT,
    month CHAR(7),
    CONSTRAINT fk_session_station
        FOREIGN KEY (station_id) REFERENCES stations(station_id),
    CONSTRAINT fk_session_charger
        FOREIGN KEY (charger_id) REFERENCES chargers(charger_id),
    CONSTRAINT fk_session_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Update these paths to the location of your CSV files.
-- In MySQL Workbench, LOAD DATA LOCAL INFILE may require:
-- SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'stations.csv'
INTO TABLE stations
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'chargers.csv'
INTO TABLE chargers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'charging_sessions.csv'
INTO TABLE charging_sessions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

CREATE INDEX idx_sessions_station ON charging_sessions(station_id);
CREATE INDEX idx_sessions_charger ON charging_sessions(charger_id);
CREATE INDEX idx_sessions_customer ON charging_sessions(customer_id);
CREATE INDEX idx_sessions_start_time ON charging_sessions(start_time);
CREATE INDEX idx_sessions_status ON charging_sessions(session_status);

-- Verification
SELECT 'stations' AS table_name, COUNT(*) AS row_count FROM stations
UNION ALL
SELECT 'chargers', COUNT(*) FROM chargers
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'charging_sessions', COUNT(*) FROM charging_sessions;
