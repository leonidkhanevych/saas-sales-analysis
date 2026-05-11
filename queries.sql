-- ============================================================
-- SaaS Sales Reporting — Analysis Queries
-- ============================================================
-- These queries are written for PostgreSQL.
-- The analysis.py script runs equivalent logic via SQLite
-- (in-memory) so no database install is needed to run the project.
-- ============================================================


-- ── 1. Weekly revenue with WoW growth (CTE + window functions) ───────────────
WITH weekly_revenue AS (
    SELECT
        DATE_TRUNC('week', "Order Date")::DATE      AS week_start,
        ROUND(SUM("Sales")::NUMERIC, 2)             AS revenue,
        ROUND(SUM("Profit")::NUMERIC, 2)            AS profit,
        COUNT(DISTINCT "Order ID")                  AS orders,
        COUNT(DISTINCT "Customer")                  AS customers,
        ROUND(AVG("Discount")::NUMERIC, 3)          AS avg_discount
    FROM sales
    GROUP BY 1
),
with_growth AS (
    SELECT
        week_start,
        revenue,
        profit,
        orders,
        customers,
        avg_discount,
        ROUND(100.0 * profit / NULLIF(revenue, 0), 1)       AS margin_pct,
        LAG(revenue) OVER (ORDER BY week_start)             AS prev_week_revenue,
        ROUND(
            100.0 * (revenue - LAG(revenue) OVER (ORDER BY week_start))
                  / NULLIF(LAG(revenue) OVER (ORDER BY week_start), 0),
            1
        )                                                   AS wow_growth_pct,
        SUM(revenue) OVER (ORDER BY week_start
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                   AS cumulative_revenue
    FROM weekly_revenue
)
SELECT * FROM with_growth ORDER BY week_start;


-- ── 2. Revenue & profit by region (with rank) ─────────────────────────────────
WITH region_stats AS (
    SELECT
        "Region",
        ROUND(SUM("Sales")::NUMERIC, 2)            AS revenue,
        ROUND(SUM("Profit")::NUMERIC, 2)           AS profit,
        COUNT(DISTINCT "Order ID")                 AS orders,
        COUNT(DISTINCT "Customer")                 AS customers
    FROM sales
    GROUP BY "Region"
)
SELECT
    *,
    ROUND(100.0 * profit / NULLIF(revenue, 0), 1)   AS margin_pct,
    RANK() OVER (ORDER BY revenue DESC)              AS revenue_rank
FROM region_stats
ORDER BY revenue DESC;


-- ── 3. Product performance ────────────────────────────────────────────────────
SELECT
    "Product",
    ROUND(SUM("Sales")::NUMERIC, 2)                         AS revenue,
    ROUND(SUM("Profit")::NUMERIC, 2)                        AS profit,
    COUNT(DISTINCT "Order ID")                              AS orders,
    ROUND(AVG("Discount") * 100, 1)                         AS avg_discount_pct,
    ROUND(100.0 * SUM("Profit") / NULLIF(SUM("Sales"), 0), 1) AS margin_pct
FROM sales
GROUP BY "Product"
ORDER BY revenue DESC;


-- ── 4. Customer segment performance ──────────────────────────────────────────
SELECT
    "Segment",
    ROUND(SUM("Sales")::NUMERIC, 2)                             AS revenue,
    ROUND(SUM("Profit")::NUMERIC, 2)                            AS profit,
    COUNT(DISTINCT "Customer")                                  AS customers,
    COUNT(DISTINCT "Order ID")                                  AS orders,
    ROUND(SUM("Sales")::NUMERIC / COUNT(DISTINCT "Customer"), 2) AS revenue_per_customer,
    ROUND(100.0 * SUM("Profit") / NULLIF(SUM("Sales"), 0), 1)   AS margin_pct
FROM sales
GROUP BY "Segment"
ORDER BY revenue DESC;


-- ── 5. Discount impact on margin ──────────────────────────────────────────────
SELECT
    CASE
        WHEN "Discount" = 0         THEN '0% (no discount)'
        WHEN "Discount" <= 0.10     THEN '1–10%'
        WHEN "Discount" <= 0.20     THEN '11–20%'
        WHEN "Discount" <= 0.30     THEN '21–30%'
        ELSE '30%+'
    END                                                         AS discount_band,
    COUNT(*)                                                    AS orders,
    ROUND(SUM("Sales")::NUMERIC, 2)                             AS revenue,
    ROUND(AVG(100.0 * "Profit" / NULLIF("Sales", 0))::NUMERIC, 1) AS avg_margin_pct
FROM sales
GROUP BY 1
ORDER BY 2;


-- ── 6. Top 15 customers by revenue (window function) ─────────────────────────
SELECT
    "Customer",
    "Industry",
    "Segment",
    "Region",
    ROUND(SUM("Sales")::NUMERIC, 2)                             AS revenue,
    ROUND(SUM("Profit")::NUMERIC, 2)                            AS profit,
    COUNT(DISTINCT "Order ID")                                  AS orders,
    ROUND(100.0 * SUM("Profit") / NULLIF(SUM("Sales"), 0), 1)   AS margin_pct,
    RANK() OVER (ORDER BY SUM("Sales") DESC)                    AS rank
FROM sales
GROUP BY "Customer", "Industry", "Segment", "Region"
ORDER BY revenue DESC
LIMIT 15;
