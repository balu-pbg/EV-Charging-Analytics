-- EV Charging Analytics: Advanced SQL Business Queries
-- MySQL 8.0+
USE ev_charging_analytics;

-- 01. Station performance scorecard
SELECT
    s.station_id,
    s.station_name,
    s.city,
    s.number_of_chargers,
    COUNT(cs.session_id) AS sessions,
    ROUND(SUM(cs.energy_kwh),2) AS energy_kwh,
    ROUND(SUM(cs.charging_cost),2) AS revenue,
    ROUND(AVG(cs.waiting_time_minutes),2) AS avg_waiting
FROM stations s
LEFT JOIN charging_sessions cs
    ON s.station_id = cs.station_id
   AND cs.session_status = 'Completed'
GROUP BY s.station_id, s.station_name, s.city, s.number_of_chargers
ORDER BY revenue DESC;

-- 02. Revenue ranking of stations
WITH station_revenue AS (
    SELECT station_id,
           SUM(charging_cost) AS revenue
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY station_id
)
SELECT station_id,
       ROUND(revenue,2) AS revenue,
       DENSE_RANK() OVER (ORDER BY revenue DESC) AS revenue_rank
FROM station_revenue;

-- 03. Top 3 stations by revenue
WITH ranked AS (
    SELECT
        station_id,
        SUM(charging_cost) AS revenue,
        DENSE_RANK() OVER (ORDER BY SUM(charging_cost) DESC) AS rnk
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY station_id
)
SELECT station_id, ROUND(revenue,2) AS revenue
FROM ranked
WHERE rnk <= 3
ORDER BY revenue DESC;

-- 04. Monthly revenue growth
WITH monthly AS (
    SELECT month,
           SUM(charging_cost) AS revenue
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY month
)
SELECT month,
       ROUND(revenue,2) AS revenue,
       ROUND(
           (revenue - LAG(revenue) OVER (ORDER BY month))
           / NULLIF(LAG(revenue) OVER (ORDER BY month),0) * 100, 2
       ) AS revenue_growth_pct
FROM monthly
ORDER BY month;

-- 05. Monthly energy growth
WITH monthly AS (
    SELECT month, SUM(energy_kwh) AS energy
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY month
)
SELECT month,
       ROUND(energy,2) AS energy_kwh,
       ROUND(
           (energy - LAG(energy) OVER (ORDER BY month))
           / NULLIF(LAG(energy) OVER (ORDER BY month),0) * 100, 2
       ) AS energy_growth_pct
FROM monthly
ORDER BY month;

-- 06. Peak hour by station
WITH hourly AS (
    SELECT station_id, hour, COUNT(*) AS sessions
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY station_id, hour
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY station_id
               ORDER BY sessions DESC, hour
           ) AS rn
    FROM hourly
)
SELECT station_id, hour AS peak_hour, sessions
FROM ranked
WHERE rn = 1
ORDER BY station_id;

-- 07. Peak demand period
SELECT
    CASE
        WHEN hour BETWEEN 6 AND 11 THEN 'Morning'
        WHEN hour BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN hour BETWEEN 17 AND 21 THEN 'Evening'
        ELSE 'Night'
    END AS demand_period,
    COUNT(*) AS sessions,
    ROUND(SUM(energy_kwh),2) AS energy_kwh,
    ROUND(SUM(charging_cost),2) AS revenue
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY demand_period
ORDER BY sessions DESC;

-- 08. Stations with high utilization proxy
-- Utilization proxy = completed sessions / available chargers
SELECT
    s.station_id,
    s.station_name,
    s.number_of_chargers,
    COUNT(cs.session_id) AS sessions,
    ROUND(COUNT(cs.session_id) / s.number_of_chargers, 2)
        AS sessions_per_charger
FROM stations s
JOIN charging_sessions cs
    ON s.station_id = cs.station_id
WHERE cs.session_status = 'Completed'
GROUP BY s.station_id, s.station_name, s.number_of_chargers
ORDER BY sessions_per_charger DESC;

-- 09. Stations with both high demand and high waiting time
SELECT
    s.station_id,
    s.station_name,
    COUNT(cs.session_id) AS sessions,
    ROUND(AVG(cs.waiting_time_minutes),2) AS avg_waiting
FROM stations s
JOIN charging_sessions cs ON s.station_id = cs.station_id
WHERE cs.session_status = 'Completed'
GROUP BY s.station_id, s.station_name
HAVING COUNT(cs.session_id) > (
    SELECT AVG(session_count)
    FROM (
        SELECT COUNT(*) AS session_count
        FROM charging_sessions
        WHERE session_status = 'Completed'
        GROUP BY station_id
    ) x
)
AND AVG(cs.waiting_time_minutes) > (
    SELECT AVG(waiting_time_minutes)
    FROM charging_sessions
    WHERE session_status = 'Completed'
)
ORDER BY avg_waiting DESC;

-- 10. Charger performance
SELECT
    ch.charger_id,
    ch.station_id,
    ch.charger_type,
    ch.power_kw,
    COUNT(cs.session_id) AS sessions,
    ROUND(SUM(cs.energy_kwh),2) AS energy_kwh,
    ROUND(SUM(cs.charging_cost),2) AS revenue,
    ROUND(AVG(cs.duration_minutes),2) AS avg_duration
FROM chargers ch
LEFT JOIN charging_sessions cs ON ch.charger_id = cs.charger_id
WHERE cs.session_status = 'Completed'
GROUP BY ch.charger_id, ch.station_id, ch.charger_type, ch.power_kw
ORDER BY revenue DESC;

-- 11. Top 10 customers by revenue
SELECT
    c.customer_id,
    c.customer_type,
    c.vehicle_type,
    COUNT(cs.session_id) AS sessions,
    ROUND(SUM(cs.charging_cost),2) AS revenue
FROM customers c
JOIN charging_sessions cs ON c.customer_id = cs.customer_id
WHERE cs.session_status = 'Completed'
GROUP BY c.customer_id, c.customer_type, c.vehicle_type
ORDER BY revenue DESC
LIMIT 10;

-- 12. Customer lifetime-style value
SELECT
    c.customer_type,
    COUNT(DISTINCT c.customer_id) AS customers,
    ROUND(SUM(cs.charging_cost),2) AS revenue,
    ROUND(SUM(cs.charging_cost) / COUNT(DISTINCT c.customer_id),2)
        AS revenue_per_customer
FROM customers c
JOIN charging_sessions cs ON c.customer_id = cs.customer_id
WHERE cs.session_status = 'Completed'
GROUP BY c.customer_type
ORDER BY revenue_per_customer DESC;

-- 13. Station revenue contribution percentage
WITH station_rev AS (
    SELECT station_id, SUM(charging_cost) AS revenue
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY station_id
),
total_rev AS (
    SELECT SUM(revenue) AS total_revenue
    FROM station_rev
)
SELECT
    sr.station_id,
    ROUND(sr.revenue,2) AS revenue,
    ROUND(sr.revenue / tr.total_revenue * 100,2) AS revenue_share_pct
FROM station_rev sr
CROSS JOIN total_rev tr
ORDER BY revenue_share_pct DESC;

-- 14. Daily demand trend
SELECT
    DATE(start_time) AS charge_date,
    COUNT(*) AS sessions,
    ROUND(SUM(energy_kwh),2) AS energy_kwh,
    ROUND(SUM(charging_cost),2) AS revenue
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY DATE(start_time)
ORDER BY charge_date;

-- 15. Running monthly revenue
WITH monthly AS (
    SELECT month, SUM(charging_cost) AS revenue
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY month
)
SELECT
    month,
    ROUND(revenue,2) AS monthly_revenue,
    ROUND(
        SUM(revenue) OVER (
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),2
    ) AS cumulative_revenue
FROM monthly
ORDER BY month;

-- 16. Weekday demand ranking
WITH day_stats AS (
    SELECT
        day_of_week,
        COUNT(*) AS sessions,
        SUM(charging_cost) AS revenue
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY day_of_week
)
SELECT *,
       DENSE_RANK() OVER (ORDER BY sessions DESC) AS demand_rank
FROM day_stats
ORDER BY demand_rank;

-- 17. High-value charging sessions
SELECT
    session_id,
    station_id,
    energy_kwh,
    charging_cost,
    duration_minutes,
    waiting_time_minutes
FROM charging_sessions
WHERE session_status = 'Completed'
  AND charging_cost >= (
      SELECT AVG(charging_cost) + 2 * STDDEV(charging_cost)
      FROM charging_sessions
      WHERE session_status = 'Completed'
  )
ORDER BY charging_cost DESC;

-- 18. Cancel rate by station
SELECT
    station_id,
    COUNT(*) AS total_sessions,
    SUM(session_status = 'Cancelled') AS cancelled,
    ROUND(
        SUM(session_status = 'Cancelled') / COUNT(*) * 100, 2
    ) AS cancel_rate_pct
FROM charging_sessions
GROUP BY station_id
ORDER BY cancel_rate_pct DESC;

-- 19. Energy efficiency by charger type
SELECT
    ch.charger_type,
    ROUND(AVG(cs.energy_kwh / NULLIF(cs.duration_minutes,0)),3)
        AS avg_kwh_per_minute,
    ROUND(AVG(cs.energy_kwh),2) AS avg_energy_per_session
FROM chargers ch
JOIN charging_sessions cs ON ch.charger_id = cs.charger_id
WHERE cs.session_status = 'Completed'
GROUP BY ch.charger_type;

-- 20. Station capacity recommendation
WITH station_stats AS (
    SELECT
        s.station_id,
        s.station_name,
        s.number_of_chargers,
        COUNT(cs.session_id) AS sessions,
        AVG(cs.waiting_time_minutes) AS avg_wait
    FROM stations s
    JOIN charging_sessions cs ON s.station_id = cs.station_id
    WHERE cs.session_status = 'Completed'
    GROUP BY s.station_id, s.station_name, s.number_of_chargers
)
SELECT *,
    CASE
        WHEN avg_wait >= 15 AND sessions > 700
            THEN 'HIGH PRIORITY - REVIEW ADDING CAPACITY'
        WHEN avg_wait >= 10 OR sessions > 600
            THEN 'MEDIUM PRIORITY - MONITOR'
        ELSE 'NORMAL'
    END AS capacity_recommendation
FROM station_stats
ORDER BY avg_wait DESC;

-- 21. Find customers who use multiple stations
SELECT
    customer_id,
    COUNT(DISTINCT station_id) AS stations_used,
    COUNT(*) AS sessions
FROM charging_sessions
WHERE session_status = 'Completed'
GROUP BY customer_id
HAVING COUNT(DISTINCT station_id) >= 3
ORDER BY stations_used DESC, sessions DESC;

-- 22. Station demand by hour with ranking
WITH hourly AS (
    SELECT station_id, hour, COUNT(*) AS sessions
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY station_id, hour
)
SELECT
    station_id,
    hour,
    sessions,
    RANK() OVER (
        PARTITION BY station_id
        ORDER BY sessions DESC
    ) AS hour_rank
FROM hourly
ORDER BY station_id, hour_rank;

-- 23. Compare each station to the average station revenue
WITH station_rev AS (
    SELECT station_id, SUM(charging_cost) AS revenue
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY station_id
)
SELECT
    station_id,
    ROUND(revenue,2) AS revenue,
    ROUND((SELECT AVG(revenue) FROM station_rev),2) AS avg_station_revenue,
    CASE
        WHEN revenue >= (SELECT AVG(revenue) FROM station_rev)
            THEN 'Above Average'
        ELSE 'Below Average'
    END AS performance
FROM station_rev
ORDER BY revenue DESC;

-- 24. Monthly station revenue ranking
WITH monthly_station AS (
    SELECT month, station_id, SUM(charging_cost) AS revenue
    FROM charging_sessions
    WHERE session_status = 'Completed'
    GROUP BY month, station_id
)
SELECT
    month,
    station_id,
    ROUND(revenue,2) AS revenue,
    RANK() OVER (
        PARTITION BY month
        ORDER BY revenue DESC
    ) AS monthly_rank
FROM monthly_station
ORDER BY month, monthly_rank;

-- 25. Executive KPI query for Power BI
SELECT
    COUNT(*) AS total_sessions,
    ROUND(SUM(energy_kwh),2) AS total_energy_kwh,
    ROUND(SUM(charging_cost),2) AS total_revenue,
    ROUND(AVG(duration_minutes),2) AS avg_duration_minutes,
    ROUND(AVG(waiting_time_minutes),2) AS avg_waiting_minutes,
    ROUND(AVG(energy_kwh),2) AS avg_energy_per_session,
    ROUND(AVG(charging_cost),2) AS avg_revenue_per_session,
    COUNT(DISTINCT customer_id) AS active_customers,
    COUNT(DISTINCT station_id) AS active_stations
FROM charging_sessions
WHERE session_status = 'Completed';
