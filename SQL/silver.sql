
-- Q1: Create a staging view with cleaned data types and text

CREATE OR REFRESH MATERIALIZED VIEW silver_bookings_staged AS

SELECT
    TRIM(booking_id) AS booking_id,
    NULLIF(TRIM(guest_id), '') AS guest_id,

    TRY_CAST(NULLIF(TRIM(booking_date), '') AS DATE)
        AS booking_date,

    TRY_CAST(NULLIF(TRIM(check_in_date), '') AS DATE)
        AS check_in_date,

    TRY_CAST(NULLIF(TRIM(check_out_date), '') AS DATE)
        AS check_out_date,

    TRY_CAST(NULLIF(TRIM(nights), '') AS INT) AS original_nights,

    INITCAP(TRIM(hotel_name)) AS hotel_name,

    COALESCE(
        INITCAP(NULLIF(TRIM(city), '')),
        'Unknown'
    ) AS city,

    INITCAP(TRIM(region)) AS region,
    INITCAP(TRIM(room_type)) AS room_type,

    COALESCE(
        INITCAP(NULLIF(TRIM(booking_channel), '')),
        'Unknown'
    ) AS booking_channel,

    TRY_CAST(NULLIF(TRIM(guests), '') AS INT) AS guests,

    TRY_CAST(NULLIF(TRIM(room_rate), '') AS DECIMAL(12,2))
        AS room_rate,

    TRY_CAST(NULLIF(TRIM(total_amount), '') AS DECIMAL(12,2))
        AS original_total_amount,

    TRY_CAST(NULLIF(TRIM(discount_amount), '') AS DECIMAL(12,2))
        AS discount_amount,

    INITCAP(TRIM(meal_plan)) AS meal_plan,
    INITCAP(TRIM(payment_method)) AS payment_method,
    INITCAP(TRIM(payment_status)) AS payment_status,
    INITCAP(TRIM(booking_status)) AS booking_status,

    TRY_CAST(NULLIF(TRIM(guest_rating), '') AS DOUBLE)
        AS guest_rating,

    source_file,
    loaded_at

FROM bronze_hotel_bookings;


-- Q2: Remove duplicate booking IDs

CREATE OR REFRESH MATERIALIZED VIEW silver_bookings_deduplicated AS

SELECT *
FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY booking_id
            ORDER BY loaded_at
        ) AS row_num
    FROM silver_bookings_staged
)
WHERE row_num = 1;


-- Q3: Create the rejected bookings table

CREATE OR REFRESH MATERIALIZED VIEW silver_bookings_rejected AS

SELECT *,
    CASE
        WHEN check_in_date IS NULL
          OR check_out_date IS NULL
          OR check_out_date <= check_in_date
            THEN 'Invalid stay dates'

        WHEN room_rate IS NULL OR room_rate < 0
            THEN 'Invalid room rate'

    END AS reject_reason

FROM silver_bookings_deduplicated

WHERE
    check_in_date IS NULL
    OR check_out_date IS NULL
    OR check_out_date <= check_in_date
    OR room_rate IS NULL
    OR room_rate < 0;


-- Q4: Create the clean Silver table

CREATE OR REFRESH MATERIALIZED VIEW silver_bookings_clean AS

SELECT
    booking_id,
    guest_id,
    booking_date,
    check_in_date,
    check_out_date,

    COALESCE(
        original_nights,
        DATEDIFF(check_out_date, check_in_date)
    ) AS nights,

    hotel_name,
    city,
    region,
    room_type,
    booking_channel,
    guests,
    room_rate,

    COALESCE(
        original_total_amount,
        COALESCE(
            original_nights,
            DATEDIFF(check_out_date, check_in_date)
        ) * room_rate
    ) AS total_amount,

    discount_amount,
    meal_plan,
    payment_method,
    payment_status,
    booking_status,
    guest_rating,
    source_file,
    loaded_at

FROM silver_bookings_deduplicated

WHERE
    check_in_date IS NOT NULL
    AND check_out_date IS NOT NULL
    AND check_out_date > check_in_date
    AND room_rate IS NOT NULL
    AND room_rate >= 0;


-- Q5: Count clean bookings
SELECT COUNT(*) AS clean_rows
FROM hospitality_catalog.bookings.silver_bookings_clean;


-- Q6: Count rejected bookings
SELECT COUNT(*) AS rejected_rows
FROM hospitality_catalog.bookings.silver_bookings_rejected;


-- Q7: Check duplicates removed
SELECT
    COUNT(*) AS bronze_rows,
    COUNT(DISTINCT booking_id) AS unique_bookings,
    COUNT(*) - COUNT(DISTINCT booking_id) AS duplicate_rows
FROM hospitality_catalog.bookings.bronze_hotel_bookings;


-- Q8: Check cancelled bookings
SELECT booking_status, COUNT(*) AS total_bookings
FROM hospitality_catalog.bookings.silver_bookings_clean
GROUP BY booking_status;

