CREATE DATABASE ENERGYDB;
USE ENERGYDB;

-- 1. country table
CREATE TABLE country (
    CID VARCHAR(10) PRIMARY KEY,
    Country VARCHAR(100) UNIQUE
);

SELECT * FROM COUNTRY;

-- 2. emission_3 table
CREATE TABLE emission_3 (
    country VARCHAR(100),
    energy_type VARCHAR(50),
    year INT,
    emission INT,
    per_capita_emission DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
);

SELECT * FROM EMISSION_3;

-- 3. population table
CREATE TABLE population (
    countries VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (countries) REFERENCES country(Country)
);

SELECT * FROM POPULATION;

-- 4. production table
CREATE TABLE production (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    production INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);


SELECT * FROM PRODUCTION;

-- 5. gdp_3 table
CREATE TABLE gdp_3 (
    Country VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (Country) REFERENCES country(Country)
);

SELECT * FROM GDP_3;

-- 6. consumption table
CREATE TABLE consumption (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    consumption INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);

SELECT * FROM CONSUMPTION;

-- Data Analysis Questions

-- 1.What is the total emission per country for the most recent year available?
SELECT country,year,
    SUM(emission) AS total_emission
FROM emission_3
WHERE year = (SELECT MAX(year) FROM emission_3)
GROUP BY country, year
ORDER BY total_emission DESC;


-- 2.What are the top 5 countries by GDP in the most recent year?
SELECT Country,year, Value AS GDP
FROM gdp_3
WHERE year = (SELECT MAX(year) FROM gdp_3)
ORDER BY Value DESC
LIMIT 5;

-- 3.Compare energy production and consumption by country and year. 
SELECT p.country,p.year,
    SUM(p.production) AS total_energy_production,
    SUM(c.consumption) AS total_energy_consumption
FROM production p
JOIN consumption c ON p.country = c.country
AND p.year = c.year
GROUP BY p.country, p.year
ORDER BY p.country, p.year;

-- 4.Which energy types contribute most to emissions across all countries?
SELECT energy_type, SUM(emission) AS total_emission
FROM emission_3
GROUP BY energy_type
ORDER BY total_emission DESC;

-- 5.How have global emissions changed year over year?
WITH yearly AS (
    SELECT year, SUM(emission) AS total_emissions
    FROM emission_3
    GROUP BY year)
SELECT year,total_emissions,
    ROUND(
        (total_emissions - LAG(total_emissions) OVER (ORDER BY year))
        / NULLIF(LAG(total_emissions) OVER (ORDER BY year), 0) * 100,2) AS yoy_growth_percent
FROM yearly
ORDER BY year;

-- 6.What is the trend in GDP for each country over the given years?
SELECT country,year,value AS gdp
FROM gdp_3
ORDER BY country, year;

-- 7.How has population growth affected total emissions in each country?
SELECT e.country,e.year,
    SUM(e.emission) AS total_emission,
    p.value AS population,
    (SUM(e.emission) / p.value) AS emission_per_capita
FROM emission_3 e
JOIN population p ON e.country = p.countries
AND e.year = p.year
GROUP BY e.country, e.year, p.value
ORDER BY e.country, e.year;


-- 8.Has energy consumption increased or decreased over the years for major economies?
SELECT c.country,c.year,SUM(c.consumption) AS total_consumption
FROM consumption c
JOIN (SELECT Country FROM gdp_3
    GROUP BY Country
    ORDER BY MAX(Value) DESC
    LIMIT 5) top_economies
ON c.country = top_economies.Country
GROUP BY c.country, c.year
ORDER BY c.country, c.year;

-- 9.What is the average yearly change in emissions per capita for each country?
SELECT e.country,
AVG((e.emission / p.Value)) AS avg_per_capita_emission
FROM emission_3 e
JOIN population p ON e.country = p.countries
AND e.year = p.year
GROUP BY e.country
ORDER BY avg_per_capita_emission DESC;


-- 10.What is the emission-to-GDP ratio for each country by year?
SELECT e.country,e.year,SUM(e.emission) AS total_emission,
    g.Value AS gdp,SUM(e.emission) / g.Value AS emission_to_gdp_ratio
FROM emission_3 e
JOIN gdp_3 g ON e.country = g.Country
   AND e.year = g.year
GROUP BY e.country, e.year, g.Value
ORDER BY e.country, e.year;

-- 11.What is the energy consumption per capita for each country over the last decade?
SELECT c.country, c.year,
	SUM(c.consumption) / p.Value AS consumption_per_capita
FROM consumption c
JOIN population p
ON c.country = p.countries AND c.year = p.year
WHERE c.year >= (SELECT MAX(year) - 10 FROM consumption)
GROUP BY c.country, c.year, p.Value;

-- 12.How does energy production per capita vary across countries?
SELECT p.country,p.year,
    (SUM(p.production) / pop.value) AS production_per_capita
FROM production p
JOIN population pop ON p.country = pop.countries
   AND p.year = pop.year
GROUP BY p.country, p.year, pop.value
ORDER BY production_per_capita DESC;


-- 13.Which countries have the highest energy consumption relative to GDP?
SELECT c.country,
SUM(c.consumption) AS total_energy_consumption,
SUM(g.value) AS total_gdp,
(SUM(c.consumption) / SUM(g.value)) AS consumption_to_gdp_ratio
FROM consumption c
JOIN gdp_3 g ON c.country = g.country AND c.year = g.year
GROUP BY c.country
ORDER BY consumption_to_gdp_ratio DESC;


-- 14.What is the correlation between GDP growth and energy production growth?
SELECT g.year,
(g.total_gdp - prev.total_gdp) / NULLIF(prev.total_gdp, 0) AS gdp_growth_pct
FROM (SELECT year, 
     SUM(value) AS total_gdp FROM gdp_3
     GROUP BY year) g
JOIN (SELECT year, 
      SUM(value) AS total_gdp FROM gdp_3
      GROUP BY year) prev 
      ON g.year = prev.year + 1
ORDER BY g.year;


-- 15.What are the top 10 countries by population and how do their emissions compare?
-- Step 1: Find the most recent year of population data
WITH latest_pop AS (
    SELECT countries AS country,year,
        Value AS population
    FROM population
    WHERE year = (SELECT MAX(year) FROM population)
),

-- Step 2: Total emissions for the same year
latest_emissions AS (
    SELECT country,
        SUM(emission) AS total_emissions
    FROM emission_3
    WHERE year = (SELECT MAX(year) FROM emission_3)
    GROUP BY country
)

-- Step 3: Join and pick top 10 by population
SELECT p.country,p.population,e.total_emissions,
    ROUND(e.total_emissions / NULLIF(p.population, 0), 6) AS emission_per_capita
FROM latest_pop p
LEFT JOIN latest_emissions e
    ON p.country = e.country
ORDER BY p.population DESC
LIMIT 10;

-- 16.Which countries have improved (reduced) their per capita emissions the most over the last decade?
-- Step 1: Calculate per-capita emissions for the last decade
WITH last_decade AS (
    SELECT e.country,e.year,
        SUM(e.emission) AS emission,p.Value AS population,
        (SUM(e.emission) / NULLIF(p.Value, 0)) AS per_capita_emission
    FROM emission_3 e
    JOIN population p ON e.country = p.countries AND e.year = p.year
    WHERE e.year >= (SELECT MAX(year) - 10 FROM emission_3)
    GROUP BY e.country, e.year, p.Value),
-- Step 2: Find earliest and latest year per country in the last decade
start_end AS (
    SELECT country,
        MIN(year) AS start_year,
        MAX(year) AS end_year
    FROM last_decade
    GROUP BY country)
-- Step 3: Compute reduction in per-capita emissions
SELECT se.country,
    s.per_capita_emission AS start_per_capita,
    e.per_capita_emission AS end_per_capita,
    (s.per_capita_emission - e.per_capita_emission) AS reduction_in_per_capita
FROM start_end se
JOIN last_decade s ON se.country = s.country
    AND se.start_year = s.year
JOIN last_decade e ON se.country = e.country
    AND se.end_year = e.year
WHERE (s.per_capita_emission - e.per_capita_emission) > 0
ORDER BY reduction_in_per_capita DESC;


-- 17.What is the global share (%) of emissions by country?
SELECT 
    country, 
    SUM(emission) AS total_emission,
    (SUM(emission) * 100.0 / (SELECT SUM(emission) FROM emission_3)) AS global_share_percent
FROM emission_3
GROUP BY country
ORDER BY global_share_percent DESC;


-- 18.What is the global average GDP, emission, and population by year?
SELECT g.year,
    AVG(g.Value) AS avg_gdp,
    AVG(e.total_emission) AS avg_emission,
    AVG(p.Value) AS avg_population
FROM gdp_3 g
JOIN (
    SELECT country, year, SUM(emission) AS total_emission
    FROM emission_3
    GROUP BY country, year
) e ON g.Country = e.country AND g.year = e.year
JOIN population p ON g.Country = p.countries
    AND g.year = p.year
GROUP BY g.year
ORDER BY g.year;
