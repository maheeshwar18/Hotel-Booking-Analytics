
-- Q1: Monthly Booking Summary

CREATE OR REFRESH MATERIALIZED VIEW gold_monthly_bookings AS

SELECT
    DATE_TRUNC('MONTH', check_in_date) AS stay_month,

    COUNT(*) AS bookings,

    SUM(
        CASE
            WHEN booking_status = 'Cancelled' THEN 1
            ELSE 0
        END
    ) AS cancelled_bookings,

    SUM(
        CASE
            WHEN booking_status = 'Completed' THEN nights
            ELSE 0
        END
    ) AS room_nights,

    SUM(
        CASE
            WHEN booking_status = 'Completed'
            THEN total_amount - COALESCE(discount_amount, 0)
            ELSE 0
        END
    ) AS net_revenue

FROM silver_bookings_clean

GROUP BY DATE_TRUNC('MONTH', check_in_date);


-- Q2: Hotel Performance Summary

CREATE OR REFRESH MATERIALIZED VIEW gold_hotel_summary AS

SELECT
    region,
    city,
    hotel_name,

    COUNT(*) AS bookings,

    SUM(
        CASE
            WHEN booking_status = 'Completed' THEN nights
            ELSE 0
        END
    ) AS room_nights,

    SUM(
        CASE
            WHEN booking_status = 'Completed'
            THEN total_amount - COALESCE(discount_amount, 0)
            ELSE 0
        END
    ) AS net_revenue,

    CASE
        WHEN SUM(
            CASE WHEN booking_status = 'Completed'
            THEN nights ELSE 0 END
        ) = 0 THEN 0

        ELSE
            SUM(
                CASE
                    WHEN booking_status = 'Completed'
                    THEN total_amount - COALESCE(discount_amount, 0)
                    ELSE 0
                END
            )
            /
            SUM(
                CASE
                    WHEN booking_status = 'Completed' THEN nights
                    ELSE 0
                END
            )
    END AS avg_daily_rate

FROM silver_bookings_clean

GROUP BY region, city, hotel_name;


-- Q3: Room Type Performance Summary

CREATE OR REFRESH MATERIALIZED VIEW gold_room_type_summary AS

SELECT
    room_type,

    COUNT(*) AS bookings,

    SUM(
        CASE
            WHEN booking_status = 'Completed' THEN nights
            ELSE 0
        END
    ) AS room_nights,

    SUM(
        CASE
            WHEN booking_status = 'Completed'
            THEN total_amount - COALESCE(discount_amount, 0)
            ELSE 0
        END
    ) AS net_revenue,

    AVG(guest_rating) AS avg_rating

FROM silver_bookings_clean

GROUP BY room_type;


-- Q4: Booking Channel Summary

CREATE OR REFRESH MATERIALIZED VIEW gold_channel_summary AS

SELECT
    booking_channel,

    COUNT(*) AS bookings,

    SUM(
        CASE
            WHEN booking_status = 'Cancelled' THEN 1
            ELSE 0
        END
    ) AS cancelled_bookings,

    ROUND(
        SUM(
            CASE
                WHEN booking_status = 'Cancelled' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate_pct,

    SUM(
        CASE
            WHEN booking_status = 'Completed'
            THEN total_amount - COALESCE(discount_amount, 0)
            ELSE 0
        END
    ) AS net_revenue

FROM silver_bookings_clean

GROUP BY booking_channel;


-- Q5: Data Quality and Reconciliation

CREATE OR REFRESH MATERIALIZED VIEW gold_data_quality AS

WITH raw_checks AS (

    SELECT
        COUNT(*) AS bronze_rows,

        COUNT(*) - COUNT(DISTINCT booking_id)
            AS duplicate_rows,

        SUM(
            CASE
                WHEN TRY_CAST(NULLIF(TRIM(check_in_date), '') AS DATE) IS NULL
                  OR TRY_CAST(NULLIF(TRIM(check_out_date), '') AS DATE) IS NULL
                  OR TRY_CAST(NULLIF(TRIM(check_out_date), '') AS DATE)
                     <= TRY_CAST(NULLIF(TRIM(check_in_date), '') AS DATE)
                THEN 1 ELSE 0
            END
        ) AS invalid_date_rows,

        SUM(
            CASE
                WHEN city IS NULL OR TRIM(city) = ''
                THEN 1 ELSE 0
            END
        ) AS missing_city_rows,

        SUM(
            CASE
                WHEN booking_channel IS NULL
                  OR TRIM(booking_channel) = ''
                THEN 1 ELSE 0
            END
        ) AS missing_channel_rows,

        SUM(
            CASE
                WHEN guest_id IS NULL OR TRIM(guest_id) = ''
                THEN 1 ELSE 0
            END
        ) AS missing_guest_id_rows,

        SUM(
            CASE
                WHEN nights IS NULL OR TRIM(nights) = ''
                THEN 1 ELSE 0
            END
        ) AS missing_nights_rows,

        SUM(
            CASE
                WHEN total_amount IS NULL OR TRIM(total_amount) = ''
                THEN 1 ELSE 0
            END
        ) AS missing_amount_rows,

        SUM(
            CASE
                WHEN TRY_CAST(room_rate AS DECIMAL(12,2)) < 0
                THEN 1 ELSE 0
            END
        ) AS negative_rate_rows

    FROM bronze_hotel_bookings
),

clean_checks AS (
    SELECT COUNT(*) AS clean_rows
    FROM silver_bookings_clean
),

rejected_checks AS (
    SELECT COUNT(*) AS rejected_rows
    FROM silver_bookings_rejected
)

SELECT
    r.*,
    c.clean_rows,
    x.rejected_rows,

    r.duplicate_rows + c.clean_rows + x.rejected_rows
        AS accounted_rows,

    CASE
        WHEN r.bronze_rows =
             c.clean_rows + x.rejected_rows + r.duplicate_rows
        THEN 'Yes'
        ELSE 'No'
    END AS reconciliation_passed

FROM raw_checks r
CROSS JOIN clean_checks c
CROSS JOIN rejected_checks x;


-- Q6: Monthly bookings
SELECT *
FROM hospitality_catalog.default.gold_monthly_bookings
ORDER BY stay_month;


-- Q7: Hotel performance
SELECT *
FROM hospitality_catalog.default.gold_hotel_summary
ORDER BY net_revenue DESC;


-- Q8: Room type performance
SELECT *
FROM hospitality_catalog.default.gold_room_type_summary
ORDER BY net_revenue DESC;


-- Q9: Booking channel performance
SELECT *
FROM hospitality_catalog.default.gold_channel_summary
ORDER BY cancellation_rate_pct DESC;


-- Q10: Data quality
SELECT *
FROM hospitality_catalog.bookings.gold_data_quality;

