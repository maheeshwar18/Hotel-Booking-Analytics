# Hotel Booking Analytics – Architecture

The project follows the Medallion Architecture to transform raw hotel booking data into business-ready insights.


          HOTEL BOOKING DATA
                  |
                  v
          BRONZE LAYER
          Raw Data Ingestion
                  |
                  v
          SILVER LAYER
       Data Cleaning & Validation
                  |
                  v
           GOLD LAYER
        Business Aggregations
                  |
          +-------+-------+
          |       |       |
          v       v       v
        Genie   SQL     AI/BI
                Queries Dashboard
                  |
                  v
          BUSINESS INSIGHTS


## Architecture Components

- **Bronze:** Stores ingested raw booking records.
- **Silver:** Handles cleaning, duplicates, rejected records and validation.
- **Gold:** Stores analytical tables for reporting.
- **Genie:** Enables natural-language data exploration.
- **AI/BI Dashboard:** Presents booking, revenue, hotel performance and data quality insights.
