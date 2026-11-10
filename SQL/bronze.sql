
-- Hotel Booking Analytics
-- Q1: Bronze Layer - Raw Data Ingestion

CREATE OR REPLACE TABLE hospitality_catalog.bookings.bronze_hotel_bookings
AS
SELECT
    *,
    _metadata.file_name AS source_file,
    CURRENT_TIMESTAMP() AS loaded_at
FROM READ_FILES(
    '/Volumes/hospitality_catalog/default/bookings_volume',
    format => 'csv',
    header => true
);

-- Q2: Validate Bronze Records

SELECT COUNT(*) AS bronze_records
FROM hospitality_catalog.bookings.bronze_hotel_bookings;

-- Q3: Preview Bronze Data

SELECT *
FROM hospitality_catalog.bookings.bronze_hotel_bookings
LIMIT 10;
