
-- ============================================================
-- PROJECT: E-Commerce Inventory Health & Reorder Optimization
-- FILE: inventory_analysis.sql
-- TOOLS: MySQL
--
-- PURPOSE:
-- Analyze inventory levels, identify potential stockout risks,
-- evaluate reorder requirements, compare warehouse inventory,
-- and rank SKU-warehouse combinations using SQL.
--
-- DATASET:
-- final_inventory_recommendations (1)
--
-- KEY BUSINESS QUESTIONS:
-- 1. How many SKU-warehouse combinations are available?
-- 2. Which combinations have potential stockout risk?
-- 3. Which warehouses hold the most inventory?
-- 4. Which products may need replenishment?
-- 5. Which combinations have the lowest projected inventory?
-- 6. How does projected inventory vary across warehouses?
-- ============================================================


-- ============================================================
-- SECTION 1: DATABASE SETUP AND DATA EXPLORATION
-- ============================================================

-- Create the project database if it does not already exist.
CREATE DATABASE IF NOT EXISTS inventory_project;

-- Select the database for subsequent operations.
USE inventory_project;

-- Display the tables available in the project database.
SHOW TABLES FROM inventory_project;

-- Preview the first 10 records to inspect the dataset.
SELECT *
FROM `final_inventory_recommendations (1)`
LIMIT 10;

-- Count the total number of SKU-warehouse combinations.
SELECT COUNT(*) AS total_records
FROM `final_inventory_recommendations (1)`;

-- Inspect the table structure, including column names and data types.
DESCRIBE `final_inventory_recommendations (1)`;


-- ============================================================
-- SECTION 2: IDENTIFY POTENTIAL STOCKOUT RISKS
-- ============================================================

-- Retrieve all records classified as potential stockout risks.
SELECT *
FROM `final_inventory_recommendations (1)`
WHERE Lead_Time_Risk = 'Potential Stockout Risk';

-- Display the key inventory and supplier details for at-risk records.
SELECT
    SKU_ID,
    Warehouse_ID,
    Inventory_Level,
    Supplier_Lead_Time_Days,
    Lead_Time_Demand,
    Projected_Inventory_At_Delivery,
    Lead_Time_Risk
FROM `final_inventory_recommendations (1)`
WHERE Lead_Time_Risk = 'Potential Stockout Risk';


-- ============================================================
-- SECTION 3: WAREHOUSE INVENTORY ANALYSIS
-- ============================================================

-- Calculate total inventory held by each warehouse.
-- Sort warehouses from highest to lowest total inventory.
SELECT
    Warehouse_ID,
    SUM(Inventory_Level) AS Total_Inventory
FROM `final_inventory_recommendations (1)`
GROUP BY Warehouse_ID
ORDER BY Total_Inventory DESC;

-- Compare total SKU combinations and at-risk combinations
-- across warehouses.
SELECT
    Warehouse_ID,
    COUNT(*) AS Total_SKU_Combinations,
    SUM(
        CASE
            WHEN Lead_Time_Risk = 'Potential Stockout Risk'
            THEN 1
            ELSE 0
        END
    ) AS At_Risk_Combinations
FROM `final_inventory_recommendations (1)`
GROUP BY Warehouse_ID
ORDER BY At_Risk_Combinations DESC;

-- Calculate projected stockout counts and the lowest projected
-- inventory for each warehouse.
SELECT
    Warehouse_ID,
    COUNT(*) AS Total_SKUs,
    SUM(
        CASE
            WHEN Projected_Inventory_At_Delivery < 0
            THEN 1
            ELSE 0
        END
    ) AS Projected_Stockout_Count,
    ROUND(
        MIN(Projected_Inventory_At_Delivery), 2
    ) AS Lowest_Projected_Inventory
FROM `final_inventory_recommendations (1)`
GROUP BY Warehouse_ID
ORDER BY Projected_Stockout_Count DESC;

-- Calculate each warehouse's share of total projected inventory.
-- The percentage helps compare projected inventory distribution.
SELECT
    Warehouse_ID,
    ROUND(
        SUM(Projected_Inventory_At_Delivery), 2
    ) AS Total_Projected_Inventory,
    ROUND(
        100.0 * SUM(Projected_Inventory_At_Delivery)
        / (
            SELECT SUM(Projected_Inventory_At_Delivery)
            FROM `final_inventory_recommendations (1)`
        ),
        2
    ) AS Inventory_Share_Percent
FROM `final_inventory_recommendations (1)`
GROUP BY Warehouse_ID
ORDER BY Inventory_Share_Percent DESC;

-- Summarize total projected inventory and the number of
-- SKU-warehouse combinations in the dataset.
SELECT
    ROUND(
        SUM(Projected_Inventory_At_Delivery), 2
    ) AS Total_Projected_Inventory,
    COUNT(*) AS Total_SKU_Warehouse_Combinations
FROM `final_inventory_recommendations (1)`;


-- ============================================================
-- SECTION 4: REORDER POINT AND REPLENISHMENT ANALYSIS
-- ============================================================

-- Identify products whose current inventory is below the reorder
-- point and calculate the difference.
-- Note: Units_Below_Reorder will be negative for these records.
SELECT
    SKU_ID,
    Warehouse_ID,
    Inventory_Level,
    Reorder_Point,
    Inventory_Level - Reorder_Point AS Units_Below_Reorder
FROM `final_inventory_recommendations (1)`
WHERE Inventory_Level < Reorder_Point
ORDER BY Units_Below_Reorder ASC;

-- Count SKU-warehouse combinations below their reorder points
-- and calculate the total replenishment shortfall.
SELECT
    COUNT(*) AS SKUs_Below_Reorder,
    SUM(Reorder_Point - Inventory_Level) AS Total_Reorder_Shortfall
FROM `final_inventory_recommendations (1)`
WHERE Inventory_Level < Reorder_Point;


-- ============================================================
-- SECTION 5: LOWEST PROJECTED INVENTORY AND PRIORITIZATION
-- ============================================================

-- Display the 10 combinations with the lowest projected inventory.
-- These records are useful for prioritizing inventory reviews.
SELECT
    SKU_ID,
    Warehouse_ID,
    Inventory_Level,
    Lead_Time_Demand,
    Projected_Inventory_At_Delivery,
    Lead_Time_Risk,
    Recommended_Action
FROM `final_inventory_recommendations (1)`
ORDER BY Projected_Inventory_At_Delivery ASC
LIMIT 10;

-- Identify combinations whose projected inventory is below
-- the overall dataset average.
SELECT
    SKU_ID,
    Warehouse_ID,
    Projected_Inventory_At_Delivery
FROM `final_inventory_recommendations (1)`
WHERE Projected_Inventory_At_Delivery < (
    SELECT AVG(Projected_Inventory_At_Delivery)
    FROM `final_inventory_recommendations (1)`
)
ORDER BY Projected_Inventory_At_Delivery ASC;

-- Find the highest projected inventory in each warehouse.
SELECT
    Warehouse_ID,
    MAX(Projected_Inventory_At_Delivery) AS Highest_Projected_Inventory
FROM `final_inventory_recommendations (1)`
GROUP BY Warehouse_ID
ORDER BY Highest_Projected_Inventory DESC;


-- ============================================================
-- SECTION 6: INVENTORY RANKING USING WINDOW FUNCTIONS
-- ============================================================

-- Rank all SKU-warehouse combinations by projected inventory.
-- Rank 1 represents the lowest projected inventory.
SELECT
    SKU_ID,
    Warehouse_ID,
    Projected_Inventory_At_Delivery,
    RANK() OVER (
        ORDER BY Projected_Inventory_At_Delivery ASC
    ) AS Inventory_Rank
FROM `final_inventory_recommendations (1)`
ORDER BY Inventory_Rank
LIMIT 10;

-- Rank combinations separately within each warehouse.
-- This identifies the lowest projected inventory positions
-- within individual warehouse operations.
SELECT
    SKU_ID,
    Warehouse_ID,
    Projected_Inventory_At_Delivery,
    RANK() OVER (
        PARTITION BY Warehouse_ID
        ORDER BY Projected_Inventory_At_Delivery ASC
    ) AS Warehouse_Rank
FROM `final_inventory_recommendations (1)`
ORDER BY Warehouse_ID, Warehouse_Rank;

-- Use a derived table to identify the two lowest-ranked
-- projected inventory positions in each warehouse.
-- Ties may result in more than two rows per warehouse.
SELECT
    SKU_ID,
    Warehouse_ID,
    Projected_Inventory_At_Delivery,
    Warehouse_Rank
FROM (
    SELECT
        SKU_ID,
        Warehouse_ID,
        Projected_Inventory_At_Delivery,
        RANK() OVER (
            PARTITION BY Warehouse_ID
            ORDER BY Projected_Inventory_At_Delivery ASC
        ) AS Warehouse_Rank
    FROM `final_inventory_recommendations (1)`
) AS ranked_inventory
WHERE Warehouse_Rank <= 2
ORDER BY Warehouse_ID, Warehouse_Rank;


-- ============================================================
-- SECTION 7: INVENTORY COMPARISON USING LAG()
-- ============================================================

-- Use LAG() to retrieve the previous row's projected inventory
-- within each warehouse when ordered by projected inventory.
SELECT
    SKU_ID,
    Warehouse_ID,
    Projected_Inventory_At_Delivery,
    LAG(Projected_Inventory_At_Delivery) OVER (
        PARTITION BY Warehouse_ID
        ORDER BY Projected_Inventory_At_Delivery ASC
    ) AS Previous_Projected_Inventory
FROM `final_inventory_recommendations (1)`
ORDER BY Warehouse_ID, Projected_Inventory_At_Delivery ASC;

-- Calculate the difference between the current row's projected
-- inventory and the preceding row's projected inventory
-- within the same warehouse.
SELECT
    SKU_ID,
    Warehouse_ID,
    Projected_Inventory_At_Delivery,
    LAG(Projected_Inventory_At_Delivery) OVER (
        PARTITION BY Warehouse_ID
        ORDER BY Projected_Inventory_At_Delivery ASC
    ) AS Previous_Inventory,
    ROUND(
        Projected_Inventory_At_Delivery
        - LAG(Projected_Inventory_At_Delivery) OVER (
            PARTITION BY Warehouse_ID
            ORDER BY Projected_Inventory_At_Delivery ASC
        ),
        2
    ) AS Inventory_Difference
FROM `final_inventory_recommendations (1)`
ORDER BY Warehouse_ID, Projected_Inventory_At_Delivery ASC;


-- ============================================================
-- SECTION 8: BUSINESS-LEVEL INVENTORY SUMMARY
-- ============================================================

-- Provide a final high-level summary of the total projected
-- inventory and the number of SKU-warehouse combinations.
SELECT
    ROUND(
        SUM(Projected_Inventory_At_Delivery), 2
    ) AS Total_Projected_Inventory,
    COUNT(*) AS Total_SKU_Warehouse_Combinations
FROM `final_inventory_recommendations (1)`;


-- ============================================================
-- END OF INVENTORY ANALYSIS
--
-- BUSINESS USE:
-- The analysis supports inventory monitoring, warehouse
-- comparisons, replenishment prioritization, and the review
-- of potential stockout risks.
--
-- IMPORTANT:
-- This script queries an existing imported table. It does not
-- create or populate the recommendation table itself.
-- ============================================================
