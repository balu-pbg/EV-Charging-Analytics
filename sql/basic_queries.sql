-- EV Charging Analytics: Basic SQL Business Queries
USE ev_charging_analytics;

-- 01. View all stations
SELECT * FROM stations;

-- 02. View completed charging sessions
SELECT *
FROM charging_sessions
WHERE session_status = 'Completed';

-- 03. Total charging sessions
SELECT COUNT(*) AS total_sessions
FROM charging_sessions;

-- 04. Total energy consumed
SELECT ROUND(SUM(energy_kwh), 2) AS total_energy_kwh
FROM charging_sessions
WHERE session_status = 'Completed';

-- 05. Total revenue
SELECT ROUND(SUM(charging_cost), 2) AS total_revenue
FROM charging_sessions
WHERE session_status = 'Completed';

-- 06. Average charging duration
SELECT ROUND(AVG(duration_minutes), 2) AS avg_duration_minutes
FROM charging_sessions
WHERE session_status = 'Completed';

-- 07. Average waiting time
SELECT ROUND(AVG(waiting_time_minutes), 2) AS avg_waiting_minutes
FROM charging_sessions
WHERE session_status = 'Completed';

-- 08. Sessions by payment method
SELECT payment_method, COUNT(*) AS sessions
FROM charging_sessions
GROUP BY payment_method
ORDER BY sessions DESC;

-- 09. Sessions by vehicle type
SELECT c.vehicle_type, COUNT(*) AS sessions
FROM charging_sessions cs
JOIN customers c ON cs.customer_id = c.customer_id
GROUP BY c.vehicle_type
ORDER BY sessions DESC;

-- 10. Revenue by station
SELECT station_id,
       ROUND(SUM(charging_cost),2) AS revenue
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY station_id
ORDER BY revenue DESC;

-- 11. Energy by station
SELECT station_id,
       ROUND(SUM(energy_kwh),2) AS energy_kwh
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY station_id
ORDER BY energy_kwh DESC;

-- 12. Number of sessions by station
SELECT station_id, COUNT(*) AS sessions
FROM charging_sessions
GROUP BY station_id
ORDER BY sessions DESC;

-- 13. Busiest charging hours
SELECT hour, COUNT(*) AS sessions
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY hour
ORDER BY sessions DESC;

-- 14. Revenue by month
SELECT month,
       ROUND(SUM(charging_cost),2) AS revenue
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY month
ORDER BY month;

-- 15. Energy by month
SELECT month,
       ROUND(SUM(energy_kwh),2) AS energy_kwh
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY month
ORDER BY month;

-- 16. Weekday vs weekend demand
SELECT
    CASE WHEN is_weekend = 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(*) AS sessions
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY is_weekend;

-- 17. Charger type performance
SELECT ch.charger_type,
       COUNT(cs.session_id) AS sessions,
       ROUND(SUM(cs.energy_kwh),2) AS energy_kwh,
       ROUND(SUM(cs.charging_cost),2) AS revenue
FROM chargers ch
LEFT JOIN charging_sessions cs ON ch.charger_id = cs.charger_id
WHERE cs.session_status = 'Completed'
GROUP BY ch.charger_type;

-- 18. Average revenue per session
SELECT ROUND(AVG(charging_cost),2) AS avg_revenue_per_session
FROM charging_sessions
WHERE session_status = 'Completed';

-- 19. Highest individual charging bill
SELECT session_id, station_id, charging_cost
FROM charging_sessions
ORDER BY charging_cost DESC
LIMIT 10;

-- 20. Longest charging sessions
SELECT session_id, station_id, duration_minutes
FROM charging_sessions
ORDER BY duration_minutes DESC
LIMIT 10;

-- 21. Sessions with high waiting time
SELECT session_id, station_id, waiting_time_minutes
FROM charging_sessions
WHERE waiting_time_minutes >= 15
ORDER BY waiting_time_minutes DESC;

-- 22. Customers with the most charging sessions
SELECT customer_id, COUNT(*) AS sessions
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY customer_id
ORDER BY sessions DESC
LIMIT 20;

-- 23. Customer type revenue
SELECT c.customer_type,
       COUNT(cs.session_id) AS sessions,
       ROUND(SUM(cs.charging_cost),2) AS revenue
FROM customers c
JOIN charging_sessions cs ON c.customer_id = cs.customer_id
WHERE cs.session_status = 'Completed'
GROUP BY c.customer_type
ORDER BY revenue DESC;

-- 24. Station details with demand
SELECT s.station_id, s.station_name, s.city,
       s.station_type, s.number_of_chargers,
       COUNT(cs.session_id) AS sessions
FROM stations s
LEFT JOIN charging_sessions cs ON s.station_id = cs.station_id
GROUP BY s.station_id, s.station_name, s.city,
         s.station_type, s.number_of_chargers
ORDER BY sessions DESC;

-- 25. Cancelled sessions
SELECT COUNT(*) AS cancelled_sessions
FROM charging_sessions
WHERE session_status = 'Cancelled';
