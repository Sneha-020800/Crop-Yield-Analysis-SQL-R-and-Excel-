--- Create a new database for the project
CREATE DATABASE IF NOT EXISTS crop_yield_project;
USE crop_yield_project;

--- Create a table based on the CSV column names and data types
CREATE TABLE crop_project (
    id INT AUTO_INCREMENT PRIMARY KEY,
    Area VARCHAR(255) NOT NULL,
    Item VARCHAR(255) NOT NULL,
    Year INT NOT NULL,
    hg_ha_yield FLOAT NOT NULL,
    average_rain_fall_mm_per_year FLOAT NOT NULL,
    pesticides_tonnes FLOAT NOT NULL,
    avg_temp FLOAT NOT NULL
);
DESCRIBE crop_project;
SELECT * FROM crop_project;

SELECT COUNT(*) AS total_rows
FROM crop_project;

                              -- Data Cleaning
SELECT Area, Item, Year, cnt
FROM (
  SELECT Area, Item, Year, COUNT(*) AS cnt
  FROM crop_project
  GROUP BY Area, Item, Year
) AS t
WHERE cnt > 1
ORDER BY cnt DESC;
     
CREATE TABLE crop_project_clean AS
SELECT 
    Area,
    Item,
    Year,
    AVG(`hg/ha_yield`) AS avg_yield,
    AVG(average_rain_fall_mm_per_year) AS avg_rainfall,
    AVG(pesticides_tonnes) AS avg_pesticides,
    AVG(avg_temp) AS avg_temp
FROM crop_project
GROUP BY `Area`, `Item`, `Year`;

SELECT * FROM crop_project_clean;
      
-- 1. Maximum and Minimum Yield
SELECT MAX(avg_yield) AS max_yield,
MIN(avg_yield) AS min_yield 
FROM crop_project_clean;

-- 2. Yield Trend over Years
SELECT Year, AVG(avg_yield) AS yield_trend
FROM crop_project_clean
GROUP BY Year
ORDER BY Year;

-- INSIGHTS
-- In 1990, the yield was 61,877, and by 2013, it had risen to 83,380.
-- This is an increase of approximately 34.7% over 23 years.
-- Insight: The overall trend indicates improvement in productivity, possibly due to better agricultural practices,
-- improved seeds, fertilizers, irrigation, or technology adoption.

-- 3. Top 5 Crops with Highest Average Yield
SELECT Item, AVG(avg_yield) AS yield_by_crop
FROM crop_project_clean
GROUP BY Item
ORDER BY yield_by_crop DESC
LIMIT 5;

-- Insights are
-- (i) Potatoes are clearly the most productive crop in terms of yield per hectare, which could make them a strong 
-- (ii) Candidate for intensified cultivation if market and climate conditions allow.

-- 4. Correlation: Average Yield by Temperature Range
SELECT 
  CASE 
    WHEN avg_temp < 15 THEN 'Low Temp'
    WHEN avg_temp BETWEEN 15 AND 25 THEN 'Moderate Temp'
    ELSE 'High Temp'
  END AS temp_category,
  AVG(avg_yield) AS yield_by_temp
FROM crop_project_clean
GROUP BY temp_category;

-- Insights are
-- (i) Cooler regions (<15°C) are more productive for this crop dataset.
-- (ii) Crop performance is temperature-sensitive, with moderate temperatures surprisingly underperforming.
-- (iii) Temperature-based crop planning can help maximize yield by focusing on cooler regions for certain crops.


-- 5. Best Performing Crop in each Area
SELECT Area, Item, AVG(avg_yield) AS avg_yield
FROM crop_project_clean
GROUP BY Area, Item
HAVING avg_yield = (
    SELECT MAX(sub.avg_yield)
    FROM (
        SELECT Area AS a2, Item AS i2, AVG(avg_yield) AS avg_yield
        FROM crop_project_clean
        GROUP BY Area, Item
    ) sub
    WHERE sub.a2 = crop_project_clean.Area
);

-- Insights are:
-- (i) Potatoes are the most consistently high-yielding crop across multiple regions, especially in temperate zones.
-- (ii) Climate-specific crops perform best in tropical or arid zones.


-- 6. Years with Highest Pesticide use
SELECT Year, SUM(avg_pesticides) AS total_pesticides
FROM crop_project_clean
GROUP BY Year
ORDER BY total_pesticides DESC;

-- Insights are:
-- (i) In 1990, total pesticides used were ~6.07 million units, rising to ~11.65 million in 2012.
-- (ii) This is an almost doubling of pesticide usage over ~22 years.

-- 7. Yield efficiency = Yield per rainfall unit
SELECT Area, Item, Year,
       (avg_yield / NULLIF(avg_rainfall,0)) AS yield_efficiency
FROM crop_project_clean
ORDER BY yield_efficiency DESC
LIMIT 10;

-- Insights are:
-- (i) All top 10 entries are from Egypt, indicating that Egypt has the highest water efficiency for crop production 
--     among the dataset.
-- (ii) Sweet potatoes dominate the list, showing that they produce high yields with relatively low rainfall in 
--      Egypt.
-- (iii) Efficiency is highest in recent years (2013–2010), gradually decreasing as we move back to 2000.
--       This may reflect improvements in irrigation, crop management, or high-yield varieties over time.

-- 8. Yield per pesticide usage (eco-efficiency)
SELECT DISTINCT Area, Item, Year,
       (avg_yield / NULLIF(avg_pesticides,0)) AS eco_efficiency
FROM crop_project_clean
ORDER BY eco_efficiency DESC
LIMIT 10;

-- Insights are:
-- (i) Potatoes are globally efficient in converting pesticide input into yield, especially in Pakistan and 
--    Montenegro.
-- (ii) Yams in Mali also show strong efficiency, highlighting region-specific crop suitability.
