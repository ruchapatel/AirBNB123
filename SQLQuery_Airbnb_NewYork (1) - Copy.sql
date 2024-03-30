select * from DataAnalysis..['listings New York$']
order by id
	
--Data Cleaning 
SELECT 
    property_type,
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) AS Pricing 
FROM 
    DataAnalysis..['listings New York$']
-- WHERE property_type = 'Entire condominium (condo)'
WHERE 
    TRY_CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
ORDER BY 
    Pricing DESC

--Overall Data
SELECT  
    COUNT(*) AS 'Listings',
    SUM(accommodates) AS Accommodations,
    SUM(number_of_reviews) AS 'Reviews',
    ROUND(AVG(review_scores_rating), 2) AS 'Average Ratings',
    CONCAT('$', ROUND(AVG(Pricing), 2)) AS 'Average Pricing'
FROM 
    (
    SELECT 
        *,
        CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) AS Pricing 
    FROM 
        DataAnalysis..['listings New York$']
    ) t
WHERE 
    Pricing > 0

--Querying hosts and details who live in the same neighborhood as their listings
--Using self INNER JOINS
-------------------------------------------------------------------------------------------------------
SELECT DISTINCT
    a.host_id,
    a.HOST_NAME,
    a.host_neighbourhood
FROM 
    DataAnalysis..['listings New York$'] a
INNER JOIN 
    DataAnalysis..['listings New York$'] b
ON 
    a.host_neighbourhood = b.neighbourhood_cleansed 
    AND a.host_name = b.host_name
ORDER BY 
    a.host_neighbourhood,
    a.host_id;

SELECT
    a.host_neighbourhood,
    COUNT(DISTINCT a.host_id) AS Hosts_live_here
FROM 
    DataAnalysis..['listings New York$'] a
INNER JOIN 
    DataAnalysis..['listings New York$'] b
ON 
    a.host_neighbourhood = b.neighbourhood_cleansed 
    AND a.host_name = b.host_name
GROUP BY 
    a.host_neighbourhood
ORDER BY 
    a.host_neighbourhood;


--Further details
SELECT 
    t.host_name, 
    t.host_neighbourhood, 
    t.name, 
    t.neighborhood_overview, 
    t.Neighbourhood, 
    t.property_type, 
    t.room_type, 
    t.accommodates, 
    t.price, 
    t.review_scores_rating, 
    t.number_of_reviews
FROM 
    (
    SELECT DISTINCT
        a.host_id, 
        a.host_name, 
        a.host_neighbourhood, 
        a.name, 
        a.neighborhood_overview, 
        a.neighbourhood_group_cleansed AS Neighbourhood, 
        a.property_type, 
        a.room_type, 
        a.accommodates, 
        a.price, 
        a.review_scores_rating, 
        a.number_of_reviews
    FROM 
        DataAnalysis..['listings New York$'] a 
    INNER JOIN 
        DataAnalysis..['listings New York$'] b ON a.host_neighbourhood = b.neighbourhood_cleansed 
                                                AND a.host_name = b.host_name
    WHERE 
        a.neighbourhood IS NOT NULL 
        AND a.review_scores_rating IS NOT NULL
    ) t
ORDER BY 
    t.host_neighbourhood ASC, 
    (t.review_scores_rating * t.number_of_reviews) DESC;

--Further details of specific Neighbourhoods
--Using PROCEDURES
--Using Temporary Tables
--------------------------------------------
DROP PROCEDURE IF EXISTS dbo.HostInSameNeighbourhood;
GO

CREATE PROCEDURE dbo.HostInSameNeighbourhood
    @neighbourhood NVARCHAR(100)	--PARAMETER LOCATION
AS
BEGIN
    DROP TABLE IF EXISTS hostinfo;

    CREATE TABLE hostinfo (
        Host_Name VARCHAR(100),
        Host_Neighbourhood VARCHAR(100),
        Name VARCHAR(400),
        Neighbourhood_Overview VARCHAR(5000),
        Neighbourhood_Group VARCHAR(100),
        Property VARCHAR(100),
        Room VARCHAR(100),
        Accomodates INT,
        Price FLOAT,
        Score FLOAT,
        Reviews FLOAT
    );
END;


INSERT INTO hostinfo
SELECT 
    t.host_name, 
    t.host_neighbourhood, 
    t.name, 
    t.neighborhood_overview, 
    t.Neighbourhood, 
    t.property_type, 
    t.room_type, 
    t.accommodates, 
    t.price, 
    t.review_scores_rating, 
    t.number_of_reviews
FROM 
    (
    SELECT DISTINCT
        a.host_id, 
        a.host_name, 
        a.host_neighbourhood, 
        a.name, 
        a.neighborhood_overview, 
        a.neighbourhood_group_cleansed AS Neighbourhood, 
        a.property_type, 
        a.room_type, 
        a.accommodates, 
        CAST(REPLACE(SUBSTRING(a.price, 2, 10), ',', '') AS FLOAT) AS price, 
        a.review_scores_rating, 
        a.number_of_reviews
    FROM 
        DataAnalysis..['listings New York$'] a 
    INNER JOIN 
        DataAnalysis..['listings New York$'] b ON a.host_neighbourhood = b.neighbourhood_cleansed 
                                                AND a.host_name = b.host_name
    WHERE 
        a.neighbourhood IS NOT NULL 
        AND a.review_scores_rating IS NOT NULL
    ) t
WHERE 
    t.Neighbourhood = @neighbourhood	--PARAMETER LOCATION
    AND t.price > 0
    AND t.review_scores_rating > 0
    AND t.number_of_reviews > 10
ORDER BY 
    t.host_neighbourhood ASC, 
    (t.review_scores_rating * t.number_of_reviews) DESC;

-- View the contents of the hostinfo table before executing the stored procedures
SELECT * FROM hostinfo;
GO

-- Define the list of neighborhoods
DECLARE @neighborhoods TABLE (Neighborhood NVARCHAR(100));
INSERT INTO @neighborhoods (Neighborhood) VALUES 
    ('Bronx'),
    ('Brooklyn'),
    ('Manhattan'),
    ('Queens'),
    ('Staten Island');

-- Execute the stored procedures for each neighborhood
DECLARE @neighborhood NVARCHAR(100);
DECLARE neighborhood_cursor CURSOR FOR
    SELECT Neighborhood FROM @neighborhoods;

OPEN neighborhood_cursor;
FETCH NEXT FROM neighborhood_cursor INTO @neighborhood;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC HostInSameNeighbourhood @neighbourhood = @neighborhood;
    FETCH NEXT FROM neighborhood_cursor INTO @neighborhood;
END

CLOSE neighborhood_cursor;
DEALLOCATE neighborhood_cursor;


--For viewing the trend(rolling count) of listings by new hosts
--Using PARTITION BY
---------------------------------------------------------------
SELECT
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) AS Pricing,
    CAST(host_since AS DATE) AS HostDates,
    ROW_NUMBER() OVER(PARTITION BY CAST(host_since AS DATE) ORDER BY CAST(host_since AS DATE)) AS Counts
FROM 
    DataAnalysis..['listings New York$']
WHERE 
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
    AND CAST(host_since AS DATE) IS NOT NULL
    AND YEAR(CAST(host_since AS DATE)) > 2000
ORDER BY 
    HostDates;


--Quantitative details about units and prices
--Using COUNT, MIN, MAX, AVG
--Using TEMPORARY TABLES
----------------------------------------------------------
-- Drop the table if it exists
IF OBJECT_ID('Temp_table1', 'U') IS NOT NULL
    DROP TABLE Temp_table1;

-- Create the table
CREATE TABLE Temp_table1 (
    category VARCHAR(200),
    Units INT,
    MinPrice FLOAT,
    MaxPrice FLOAT,
    AvgPrice FLOAT
);

INSERT INTO Temp_table1 (category, Units, MinPrice, MaxPrice, AvgPrice)
SELECT 
    property_type, 
    COUNT(property_type),
    MIN(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    MAX(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    ROUND(AVG(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)), 2)
FROM 
    DataAnalysis..['listings New York$']
WHERE 
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
GROUP BY 
    property_type;

-- Select all data from Temp_table1
SELECT * FROM Temp_table1;

-- Select category, price range, and average price from Temp_table1
SELECT 
    category, 
    CONCAT(MinPrice, ' - ', MaxPrice) AS Range,
    AvgPrice 
FROM 
    Temp_table1;

-- Drop Temp_table2 if it exists
IF OBJECT_ID('Temp_table2', 'U') IS NOT NULL
    DROP TABLE Temp_table2;

-- Create Temp_table2 with the same structure as Temp_table1
CREATE TABLE Temp_table2 (
    category VARCHAR(200),
    Units INT,
    MinPrice FLOAT,
    MaxPrice FLOAT,
    AvgPrice FLOAT
);

INSERT INTO Temp_table2 (category, Units, MinPrice, MaxPrice, AvgPrice)
SELECT 
    room_type, 
    COUNT(room_type),
    MIN(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    MAX(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    ROUND(AVG(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)), 2)
FROM 
    DataAnalysis..['listings New York$']
WHERE 
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
GROUP BY 
    room_type; 

SELECT 
    category, 
    Units, 
    CONCAT(MinPrice, ' - ', MaxPrice) AS Range,
    AvgPrice 
FROM 
    Temp_table2;

-- Drop the table if it exists
IF OBJECT_ID('Temp_table3', 'U') IS NOT NULL
    DROP TABLE Temp_table3;

-- Create the table
CREATE TABLE Temp_table3 (
    category VARCHAR(200),
    Units INT,
    MinPrice FLOAT,
    MaxPrice FLOAT,
    AvgPrice FLOAT
);


INSERT INTO Temp_table3 (category, Units, MinPrice, MaxPrice, AvgPrice)
SELECT 
    neighbourhood_group_cleansed, 
    COUNT(neighbourhood_group_cleansed),
    MIN(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    MAX(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    ROUND(AVG(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)), 2)
FROM 
    DataAnalysis..['listings New York$']
WHERE 
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
GROUP BY 
    neighbourhood_group_cleansed;

SELECT 
    category, 
    Units, 
    CONCAT(MinPrice, ' - ', MaxPrice) AS Range,
    AvgPrice 
FROM 
    Temp_table3;

/*
category		Units	Range		AvgPrice
Bronx			1058	11 - 2000	105.85
Brooklyn		14507	10 - 9999	136.48
Manhattan		16592	10 - 10000	212.14
Queens			5178	10 - 10000	113.37
Staten Island	339		10 - 1200	117.45
*/

-- Drop the table if it exists
IF OBJECT_ID('Temp_table04', 'U') IS NOT NULL
    DROP TABLE Temp_table04;

-- Create the table
CREATE TABLE Temp_table04 (
    category VARCHAR(200),
    Units INT,
    MinPrice FLOAT,
    MaxPrice FLOAT,
    AvgPrice FLOAT
);

INSERT INTO Temp_table04 (category, Units, MinPrice, MaxPrice, AvgPrice)
SELECT 
    neighbourhood_cleansed, 
    COUNT(neighbourhood_cleansed),
    MIN(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    MAX(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    ROUND(AVG(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)), 2)
FROM 
    DataAnalysis..['listings New York$']
WHERE 
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
    AND review_scores_rating > 0
GROUP BY 
    neighbourhood_cleansed;
 
SELECT 
    category, 
    Units, 
    CONCAT(MinPrice, ' - ', MaxPrice) AS Range,
    AvgPrice 
FROM 
    Temp_table04
WHERE 
    category = 'Allerton';

--Querying ratings info
-----------------------

-- Drop the table if it exists
IF OBJECT_ID('Review_table1', 'U') IS NOT NULL
    DROP TABLE Review_table1;

-- Create the table
CREATE TABLE Review_table1 (
    Name VARCHAR(300),
    Neighbourhood_group VARCHAR(100),
    Neighbourhood VARCHAR(200),
    Property_type VARCHAR(100),
    Room_type VARCHAR(100),
    Price FLOAT, 
    Reviews INT,
    Score FLOAT,
    Score_Accuracy FLOAT,
    Cleanliness FLOAT,
    Checkin FLOAT,
    Communication FLOAT,
    Location FLOAT,
    Value FLOAT
);

INSERT INTO Review_table1 (
    Name,
    Neighbourhood_group,
    Neighbourhood,
    Property_type,
    Room_type,
    Price,
    Reviews,
    Score,
    Score_Accuracy,
    Cleanliness,
    Checkin,
    Communication,
    Location,
    Value
)
SELECT 
    name,
    neighbourhood_group_cleansed,
    neighbourhood_cleansed,
    property_type,
    room_type,
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT),
    number_of_reviews,
    review_scores_rating,
    review_scores_accuracy,
    review_scores_cleanliness,
    review_scores_checkin,
    review_scores_communication,
    review_scores_location,
    review_scores_value
FROM 
    DataAnalysis..['listings New York$'];

-- Retrieve data from Review_table1 where Score is not null and Price is greater than 0
SELECT *
FROM Review_table1
WHERE Score IS NOT NULL
AND Price > 0;
-- AND Reviews > 0; -- Uncomment this line if you want to filter by Reviews greater than 0

-- Categorize data by neighborhood and calculate the average score for each neighborhood
SELECT
    Neighbourhood,
    ROUND(AVG(Score), 2) AS AvgScore
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
GROUP BY
    Neighbourhood
ORDER BY
    Neighbourhood;


-- Calculate the average score for each property type
SELECT
    Property_type,
    ROUND(AVG(Score), 2) AS AvgScore
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
GROUP BY
    Property_type
ORDER BY
    Property_type;

-- Calculate the average score for each room type
SELECT
    Room_type,
    ROUND(AVG(Score), 2) AS AvgScore
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
GROUP BY
    Room_type
ORDER BY
    Room_type;

-- Calculate the modified average score for each room type
SELECT
    Room_type,
    ROUND((SUM(Score * Reviews) / SUM(Reviews)), 2) AS AvgModScore
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
GROUP BY
    Room_type
ORDER BY
    Room_type;


-- Property type wise: Checking range and average of ratings
SELECT
    Property_type,
    CONCAT(MIN(Score), ' - ', MAX(Score)) AS Range_of_ratings,
    AVG(Score) AS Average_ratings
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
    AND Reviews > 10 -- For reliable scores
GROUP BY
    Property_type;

-- Room type wise: Checking range and average of ratings
SELECT
    Room_type,
    CONCAT(MIN(Score), ' - ', MAX(Score)) AS Range_of_ratings,
    AVG(Score) AS Average_ratings
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
    AND Reviews > 10 -- For reliable scores
GROUP BY
    Room_type;

/*
Room_type			Range_of_ratings		Aerage_ratings
Hotel room			3.37 - 5				4.43
Shared room			3.79 - 5				4.68255555555556
Private room		2.36 - 5				4.72813807144178
Entire home/apt		3.5 - 5					4.76333653978286
*/

-- Neighbourhood wise: Checking range and average of ratings
SELECT
    Neighbourhood,
    CONCAT(MIN(Score), ' - ', MAX(Score)) AS Range_of_ratings,
    AVG(Score) AS Average_ratings
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
    AND Reviews > 10 -- For reliable scores
GROUP BY
    Neighbourhood;

-- Checking minimum score for each neighbourhood
SELECT TOP 1
    Neighbourhood,
    MIN(Score) AS Minimum
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
    AND Reviews > 10 -- For reliable scores
GROUP BY
    Neighbourhood
ORDER BY
    Minimum;



--Neighbourhood wise
-- Checking range and average of ratings for each neighborhood group
SELECT
    Neighbourhood_group,
    CONCAT(MIN(Score), ' - ', MAX(Score)) AS Range_of_ratings,
    AVG(Score) AS Average_ratings
FROM
    Review_table1
WHERE
    Score IS NOT NULL
    AND Price > 0
    AND Reviews > 10 -- For reliable scores
GROUP BY
    Neighbourhood_group;

/*
Neighbourhood	Range_of_ratings	Aerage_ratings
Brooklyn		3.87 - 5			4.76833826794965
Bronx			3.83 - 5			4.7424838012959
Manhattan		2.36 - 5			4.72136335209502
Staten Island	4.08 - 5			4.76916666666667
Queens			3.64 - 5			4.74065934065933
*/

------------
--ANALYSIS |
------------

--Do HIGH REVIEWS tend to be associated with MORE EXPENSIVE or LESS EXPENSIVE LISTINGS?
---------------------------------------------------------------------------------------

--Checking Correlation of price and ratings using Pearson's formula
-------------------------------------------------------------------
/*
Pearson's formula
r = [ n(SUM(xy)-SUM(x)SUM(y) ] / [ sqrt (nSUM(x^2)-(SUM(x)^2))(nSUM(y^2)-(SUM(y)^2)) ]

r=correlation coefficient
if r-->1 strong correlation
if r-->-1 poor correaltion

r=(n*Sxy-Sx*Sy)/sqrt((n*Sx2-power(Sx,2))*(n*Sy2-power(Sy,2)))
*/
-------------------------------------------------------------------

SELECT 
    n, 
    Sx, 
    Sy, 
    Sxy, 
    Sx2, 
    Sy2, 
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        COUNT(*) AS n, 
        SUM(price) AS Sx,
        SUM(Score) AS Sy,
        SUM(price * Score) AS Sxy,
        SUM(POWER(price, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table1
    WHERE 
        Score IS NOT NULL
        AND Price > 0
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0;
--to prevent divide by zero error
---------------------------------------------------------------------------------------
--Overall there was a WEAK POSITIVE CORRELATION between MORE EXPENSIVE & HIGH REVIEWS |
---------------------------------------------------------------------------------------

--Displaying correlation Neighbourhood wise
SELECT 
    Neighbourhood,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Neighbourhood,
        COUNT(*) AS n, 
        SUM(price) AS Sx,
        SUM(Score) AS Sy,
        SUM(price * Score) AS Sxy,
        SUM(POWER(price, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table1
    WHERE 
        Score IS NOT NULL
        AND Price > 0
    GROUP BY 
        Neighbourhood
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0;


--------------------------------------------------------------------------------------------------
--There was a WEAK POSITIVE CORRELATION between MORE EXPENSIVE & HIGH REVIEWS for Neighbourhoods |
--------------------------------------------------------------------------------------------------

--Displaying correlation Property type wise
SELECT 
    Property_type,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Property_type,
        COUNT(*) AS n, 
        SUM(price) AS Sx,
        SUM(Score) AS Sy,
        SUM(price * Score) AS Sxy,
        SUM(POWER(price, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table1
    WHERE 
        Score IS NOT NULL
        AND Price > 0
        AND Score > 0
    GROUP BY 
        Property_type
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0;

--Displaying correlation Room type type wise
SELECT 
    Room_type,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Room_type,
        COUNT(*) AS n, 
        SUM(price) AS Sx,
        SUM(Score) AS Sy,
        SUM(price * Score) AS Sxy,
        SUM(POWER(price, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table1
    WHERE 
        Score IS NOT NULL
        AND Price > 0
        AND Score > 0
        AND Reviews > 50 -- to see more reliable reviews
    GROUP BY 
        Room_type
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0; -- to prevent divide by zero error


-------------------------------------------------------------------------------------------------------------------------------
--Overall there was a WEAK POSITIVE CORRELATION between MORE EXPENSIVE & HIGH REVIEWS for Hotels, Shared rooms & Entire Homes |
--& there was a VERY WEAK NEGATIVE CORRELATION between MORE EXPENSIVE & HIGH REVIEWS for Private Rooms						  |
-------------------------------------------------------------------------------------------------------------------------------

--Displaying DETAILED correlation Room type type wise in Neighbourhoods
SELECT 
    Neighbourhood,
    Room_type,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R 
FROM (
    SELECT 
        Neighbourhood,
        Room_type,
        COUNT(*) AS n, 
        SUM(price) AS Sx,
        SUM(Score) AS Sy,
        SUM(price * Score) AS Sxy,
        SUM(POWER(price, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table1
    WHERE 
        Score IS NOT NULL
        AND Price > 0
    GROUP BY 
        Neighbourhood, Room_type
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0 -- to prevent divide by zero error
ORDER BY 
    Neighbourhood, Room_type;

/*
Neighbourhood	Room_type				Pearson's R
Bronx			Entire home/apt		 0.0730143761665861
Bronx			Private room		-0.0806435070687292
Bronx			Shared room			 0.598768036753285
Brooklyn		Entire home/apt		 0.0146351679548435
Brooklyn		Hotel room			 0.0427414184105248
Brooklyn		Private room		 0.000879055653266063
Brooklyn		Shared room			 0.0188612179936523
Manhattan		Entire home/apt		 0.0250052568046383
Manhattan		Hotel room			 0.0669069528323807
Manhattan		Private room		 0.0127105849369331
Manhattan		Shared room			 0.0163970320537131
Queens			Entire home/apt		-0.00795699866522247
Queens			Hotel room			 0.615288655291931
Queens			Private room		 0.0162201290587321
Queens			Shared room			-0.0102678623254058
Staten Island	Entire home/apt		-0.00258930852369308
Staten Island	Private room		 0.0700163898636942
Staten Island	Shared room			 0.999999999999992
*/


--Do HIGH REVIEWS tend to be associated with MORE BEDROOMS & BATHROOMS or LESS?
-------------------------------------------------------------------------------

--Extracting bathroom and bedroom count
--Using PATINDEX

-- Extracting and converting the number of bathrooms
SELECT 
    CAST(
        ISNULL(
            REPLACE(
                bathrooms_text,
                SUBSTRING(bathrooms_text, PATINDEX('%[a-z]%', bathrooms_text), LEN(bathrooms_text)),
                ''
            ),
            0
        ) AS FLOAT
    ) AS Bathrooms 
FROM 
    DataAnalysis..['listings New York$']
ORDER BY 
    id;

-- Extracting and converting the number of bedrooms
SELECT 
    CAST(
        ISNULL(bedrooms, 0) AS FLOAT
    ) AS Bedrooms 
FROM 
    DataAnalysis..['listings New York$']
ORDER BY 
    id;


--Querying bedrooms & bathrooms info
------------------------------------

-- Drop the table if it exists
DROP TABLE IF EXISTS Review_table2;

-- Create the new table
CREATE TABLE Review_table2 (
    Name VARCHAR(300),
    Neighbourhood VARCHAR(100),
    Property_type VARCHAR(100),
    Room_type VARCHAR(100),
    Price FLOAT, 
    Reviews INT,
    Score FLOAT,
    Score_Accuracy FLOAT,
    Cleanliness FLOAT,
    Checkin FLOAT,
    Communication FLOAT,
    Location FLOAT,
    Value FLOAT,
    Bedrooms FLOAT,
    Bathrooms FLOAT
);


insert into Review_table2
select name, 
neighbourhood_group_cleansed, 
property_type, room_type, 
cast(replace(substring(price,2,10),',','') as float),
number_of_reviews,
review_scores_rating,
review_scores_accuracy,
review_scores_cleanliness,
review_scores_checkin,
review_scores_communication,
review_scores_location,
review_scores_value,
cast(isnull(bedrooms,0) as float),
cast(
isnull(
replace(bathrooms_text,
(substring(bathrooms_text,PATINDEX('%[a-z]%',bathrooms_text),len(bathrooms_text))),
'')
,0) as float)
from DataAnalysis..['listings New York$']

--Validating the data
-- Retrieve all columns from Review_table2
SELECT * FROM Review_table2;

-- Retrieve specific columns from Review_table2 for certain listings
SELECT 
    name,
    Bedrooms,
    Bathrooms
FROM 
    Review_table2
WHERE 
    name IN ('BEST BET IN HARLEM', 'Lovely Room 1, Garden, Best Area, Legal rental', 'Midtown Pied-a-terre');

-- Retrieve name, bedrooms, and bathrooms_text from DataAnalysis..['listings New York$'] for certain listings
SELECT 
    name,
    bedrooms,
    bathrooms_text
FROM 
    DataAnalysis..['listings New York$']
WHERE 
    name IN ('BEST BET IN HARLEM', 'Lovely Room 1, Garden, Best Area, Legal rental', 'Midtown Pied-a-terre');


--Checking Correlation of bedrooms and ratings using Pearson's formula
----------------------------------------------------------------------

SELECT 
    n,
    Sx,
    Sy,
    Sxy,
    Sx2,
    Sy2,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        COUNT(*) AS n, 
        SUM(Bedrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bedrooms * Score) AS Sxy,
        SUM(POWER(Bedrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0; -- To prevent divide by zero error


--------------------------------------------------------------------------------------
--Overall there was a WEAK POSITIVE CORRELATION between MORE BEDROOMS & HIGH REVIEWS |
--------------------------------------------------------------------------------------

--Displaying correlation Neighbourhood wise
SELECT 
    Neighbourhood,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Neighbourhood,
        COUNT(*) AS n, 
        SUM(Bedrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bedrooms * Score) AS Sxy,
        SUM(POWER(Bedrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
    GROUP BY 
        Neighbourhood
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0; -- To prevent divide by zero error


----------------------------------------------------------------------------------------------------------------
--There was a WEAK POSITIVE CORRELATION between MORE BEDROOMS & HIGH REVIEWS for Brooklyn, Manhattan, & Queens |
--There was a WEAK NEGATIVE CORRELATION between MORE BEDROOMS & HIGH REVIEWS for Bronx & Staten Island		   |
----------------------------------------------------------------------------------------------------------------

--Displaying correlation Property type wise
SELECT 
    Property_type,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Property_type,
        COUNT(*) AS n, 
        SUM(Bedrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bedrooms * Score) AS Sxy,
        SUM(POWER(Bedrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
        AND Score > 0
    GROUP BY 
        Property_type
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0; -- To prevent divide by zero error


--Displaying correlation Room type type wise
SELECT 
    Room_type,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Room_type,
        COUNT(*) AS n, 
        SUM(Bedrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bedrooms * Score) AS Sxy,
        SUM(POWER(Bedrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
        AND Score > 0
    GROUP BY 
        Room_type
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0; -- To prevent divide by zero error

----------------------------------------------------------------------------------------------------------------
--There was a WEAK POSITIVE CORRELATION between MORE BEDROOMS & HIGH REVIEWS for Private Rooms				   |
--There was a WEAK NEGATIVE CORRELATION between MORE BEDROOMS & HIGH REVIEWS for Hotels & Entire Homes		   |
----------------------------------------------------------------------------------------------------------------


----Displaying correlation Room type type wise in Neighbourhoods for better insights
SELECT 
    Neighbourhood,
    Room_type,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Neighbourhood,
        Room_type,
        COUNT(*) AS n, 
        SUM(Bedrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bedrooms * Score) AS Sxy,
        SUM(POWER(Bedrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
    GROUP BY 
        Neighbourhood, Room_type
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0 -- To prevent divide by zero error
ORDER BY 
    Neighbourhood, Room_type;

/*
Neighbourhood	Room_type				Pearson's R
Bronx			Entire home/apt		-0.0401065219845552
Bronx			Private room		-0.0547417473532595
Brooklyn		Entire home/apt		-0.00632190668507133
Brooklyn		Hotel room			-0.192524380444772
Brooklyn		Private room		 0.0187287904572153
Manhattan		Entire home/apt		-0.00780423268295889
Manhattan		Hotel room			 0.000997277138749698
Manhattan		Private room		 0.0219087848092802
Queens			Entire home/apt		-0.0334220989052496
Queens			Private room		 0.0114437626131096
Staten Island	Entire home/apt		-0.0733728700814781
Staten Island	Private room		-0.0163007555423255
*/

--Checking Correlation of bathrooms and ratings using Pearson's formula
-----------------------------------------------------------------------
SELECT 
    n,
    Sx,
    Sy,
    Sxy,
    Sx2,
    Sy2,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        COUNT(*) AS n, 
        SUM(Bathrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bathrooms * Score) AS Sxy,
        SUM(POWER(Bathrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0; -- To prevent divide by zero error


--------------------------------------------------------------------------------------------
--Overall there was a VERY WEAK POSITIVE CORRELATION between MORE BATHROOMS & HIGH REVIEWS |
--------------------------------------------------------------------------------------------

--Displaying correlation Neighbourhood wise
SELECT 
    Neighbourhood,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Neighbourhood,
        COUNT(*) AS n, 
        SUM(Bathrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bathrooms * Score) AS Sxy,
        SUM(POWER(Bathrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
    GROUP BY 
        Neighbourhood
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0; -- To prevent divide by zero error


--------------------------------------------------------------------------------------------------------------
--There was a WEAK POSITIVE CORRELATION between MORE BATHROOMS & HIGH REVIEWS for Bronx, Manhattan, & Queens |
--There was a WEAK NEGATIVE CORRELATION between MORE BATHROOMS & HIGH REVIEWS for Brooklyn & Staten Island   |
--------------------------------------------------------------------------------------------------------------

--Displaying correlation Room type type wise
SELECT 
    Room_type,
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R
FROM (
    SELECT 
        Room_type,
        COUNT(*) AS n, 
        SUM(Bathrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bathrooms * Score) AS Sxy,
        SUM(POWER(Bathrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
        AND Score > 0
    GROUP BY 
        Room_type
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0; -- To prevent divide by zero error

----------------------------------------------------------------------------------------------------------
--There was a WEAK POSITIVE CORRELATION between MORE BATHROOMS & HIGH REVIEWS for Hotels & Entire Homes  |
--There was a WEAK NEGATIVE CORRELATION between MORE BATHROOMS & HIGH REVIEWS for Shared & Private Rooms |
----------------------------------------------------------------------------------------------------------

----Displaying correlation Room type type wise in Neighbourhoods for better insights
SELECT 
    Neighbourhood, 
    Room_type, 
    (n * Sxy - Sx * Sy) / SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) AS R 
FROM (
    SELECT 
        Neighbourhood,
        Room_type,
        COUNT(*) AS n, 
        SUM(Bedrooms) AS Sx,
        SUM(Score) AS Sy,
        SUM(Bedrooms * Score) AS Sxy,
        SUM(POWER(Bedrooms, 2)) AS Sx2,
        SUM(POWER(Score, 2)) AS Sy2
    FROM 
        Review_table2
    WHERE 
        Score IS NOT NULL
        AND Price > 0
    GROUP BY 
        Neighbourhood, Room_type
) AS t
WHERE 
    SQRT((n * Sx2 - POWER(Sx, 2)) * (n * Sy2 - POWER(Sy, 2))) > 0 -- To prevent divide by zero error
ORDER 


/*
Neighbourhood		Room_type			Pearson's R
Bronx			Entire home/apt		-0.0401065219845552
Bronx			Private room		-0.0547417473532595
Brooklyn		Entire home/apt		-0.00632190668507133
Brooklyn		Hotel room			-0.192524380444772
Brooklyn		Private room		 0.0187287904572153
Manhattan		Entire home/apt		-0.00780423268295889
Manhattan		Hotel room			 0.000997277138749698
Manhattan		Private room		 0.0219087848092802
Queens			Entire home/apt		-0.0334220989052496
Queens			Private room		 0.0114437626131096
Staten Island	Entire home/apt		-0.0733728700814781
Staten Island	Private room		-0.0163007555423255
*/

--Looking at super hosts and non super hosts
--Using CASE STATEMENTS
--------------------------------------------
SELECT 
    Superhost, 
    ROUND(AVG(CAST(REPLACE(SUBSTRING(rt2.price, 2, 10), ',', '') AS FLOAT)), 2) AS AvgPrice,
    CONCAT(MIN(rt2.price), ' - ', MAX(rt2.price)) AS PriceRange, 
    AVG(Score) AS AvgScore, 
    AVG(Score_Accuracy) AS AvgScoreAccuracy,
    AVG(Cleanliness) AS AvgCleanliness,
    AVG(Checkin) AS AvgCheckin,
    AVG(Communication) AS AvgCommunication,
    AVG(Location) AS AvgLocation,
    AVG(Value) AS AvgValue
FROM (
    SELECT 
        *,
        CASE
            WHEN host_is_superhost = 'f' THEN 0
            ELSE 1
        END AS Superhost
    FROM 
        DataAnalysis..['listings New York$']
) AS t
INNER JOIN Review_table2 AS rt2 ON t.name = rt2.Name
WHERE 
    rt2.Price > 0 
    AND Reviews > 10
    AND Score IS NOT NULL
GROUP BY 
    Superhost;

/*
Superhost	AvgPrice	Range		Score				ScoreAccuracy		Cleanliness			Checkin				Communication		Location			Value
0			163.49		10 - 10000	4.68101149176063	4.76159366869037	4.63780680832609	4.83250758889851	4.82775477016478	4.7380279705117		4.66666413703382
1			163.85		10 - 2943	4.83656661562021	4.86482542113321	4.81671822358346	4.90932618683		4.91292189892801	4.82120673813168	4.79342725880552
*/
------------------------------------------------------------------------------------------------
--Superhosts provide better services in all aspects	at a similar price on an average		   |
--Non Superhosts should improve CLEANLINESS if they want to make it competitive for Superhosts |
------------------------------------------------------------------------------------------------

--Room type wise
--Checking range and average of ratings based on Cleanliness
SELECT 
    Room_type, 
    CONCAT(MIN(Cleanliness), ' - ', MAX(Cleanliness)) AS Range_of_ratings, 
    AVG(Cleanliness) AS Average_ratings 
FROM 
    Review_table1 
WHERE 
    Score IS NOT NULL
    AND Price > 0
    AND Reviews > 10 --for reliable scores
GROUP BY 
    Room_type;

/*
Room_type		Range_of_ratings	Aerage_ratings
Hotel room		3.62 - 5			4.59337662337662
Shared room		3.16 - 5			4.62155555555556
Private room	2 - 5				4.67910790301683
Entire home/apt	2.95 - 5			4.7247643259585
*/

--Neighbourhood wise
--Checking range and average of ratings
SELECT 
    Neighbourhood, 
    CONCAT(MIN(Cleanliness), ' - ', MAX(Cleanliness)) AS Range_of_ratings, 
    AVG(Cleanliness) AS Average_ratings 
FROM 
    Review_table1 
WHERE 
    Score IS NOT NULL
    AND Price > 0
    AND Reviews > 10 --for reliable scores
GROUP BY 
    Neighbourhood;


/*
Neighbourhood	Range_of_ratings	Aerage_ratings
Brooklyn		3.07 - 5			4.71807735011101
Bronx			3.74 - 5			4.74401727861771
Manhattan		2 - 5				4.665559724828
Staten Island	3.76 - 5			4.77422222222222
Queens			3.41 - 5			4.73763975155279
*/


--Looking at Response rate & Acceptance rate
SELECT 
    Superhost,
    AVG(CAST(host_response_rate_num AS FLOAT)) AS Avg_Response_rate,
    AVG(CAST(host_acceptance_rate_num AS FLOAT)) AS Avg_Acc_rate
FROM
(
    SELECT 
        *,
        CASE
            WHEN host_is_superhost = 'f' THEN 0
            ELSE 1
        END AS Superhost,
        ISNULL(host_response_rate, 0) AS host_response_rate_num,
        ISNULL(host_acceptance_rate, 0) AS host_acceptance_rate_num
    FROM 
        DataAnalysis..['listings New York$']
) AS t
INNER JOIN 
    Review_table2 AS rt2 ON t.name = rt2.Name
WHERE 
    rt2.Price > 0 
    AND Reviews > 10
    AND Score IS NOT NULL
GROUP BY 
    Superhost;


/*
Superhost	Avg_Response_rate	Avg_Acc_rate
0			0.530730702515179	0.492172593235041
1			0.810154670750384	0.764425727411948
*/

-----------------------------------------------------------------------------------------------------------------------------
--Superhosts are more responsive towards potential clients on an average; Non Superhosts should improve their response time |
--Superhosts have a higher acceptance rate; Non Superhosts should accept more frequently									|
-----------------------------------------------------------------------------------------------------------------------------

--Looking at instant bookablity
SELECT 
    Superhost,
    SUM(ib) AS Instant_Bookable,
    COUNT(ib) AS Total,
    CONCAT(CAST((CAST(SUM(ib) AS FLOAT) * 100 / CAST(COUNT(ib) AS FLOAT)) AS DECIMAL(10, 2)), '%') AS AvgB
FROM
(
    SELECT 
        *,
        CASE
            WHEN host_is_superhost = 'f' THEN 0
            ELSE 1
        END AS Superhost,
        CASE
            WHEN instant_bookable = 'f' THEN 0
            ELSE 1
        END AS ib
    FROM 
        DataAnalysis..['listings New York$']
) AS t
INNER JOIN 
    Review_table2 AS rt2 ON t.name = rt2.Name
WHERE 
    rt2.Price > 0 
    AND Reviews > 10
    AND Score IS NOT NULL
GROUP BY 
    Superhost;


/*
Superhost	Instant_Bookable	Total	AvgB
0			2865				9224	31.06%
1			2688				6530	41.16%
*/
--------------------------------------------------
--Superhosts are more instantly bookable by ~10% |
--------------------------------------------------

--Location of Superhosts
SELECT 
    neighbourhood_group_cleansed AS Neighbourhood,
    COUNT(*) AS Totalhosts,
    SUM(Superhost) AS Superhosts,
    CONCAT(CAST((CAST(SUM(Superhost) AS FLOAT) * 100 / CAST(COUNT(*) AS FLOAT)) AS DECIMAL(10, 2)), '%') AS PercentSuperhosts
FROM 
(
    SELECT 
        *,
        CASE
            WHEN host_is_superhost = 'f' THEN 0
            ELSE 1
        END AS Superhost
    FROM 
        DataAnalysis..['listings New York$']
) AS t
INNER JOIN 
    Review_table2 AS rt2 ON t.name = rt2.Name
WHERE 
    rt2.Price > 0 
    AND Reviews > 10
    AND Score IS NOT NULL
GROUP BY 
    neighbourhood_group_cleansed
ORDER BY 
    neighbourhood_group_cleansed;

/*
Neighbourhood	Totalhosts	Superhosts	PercentSuperhosts
Bronx			518			225			43.44%
Brooklyn		5989		2368		39.54%
Manhattan		6727		2940		43.70%
Queens			2337		896			38.34%
Staten Island	183			101			55.19%
*/

--Room types owned by super hosts
SELECT 
    t.room_type AS RoomType, 
    COUNT(*) AS Totalhosts, 
    SUM(Superhost) AS Superhosts,
    CONCAT(CAST((CAST(SUM(Superhost) AS FLOAT) * 100 / CAST(COUNT(*) AS FLOAT)) AS DECIMAL(10, 2)), '%') AS PercentSuperhosts
FROM 
(
    SELECT 
        *,
        CASE
            WHEN host_is_superhost = 'f' THEN 0
            ELSE 1
        END AS Superhost
    FROM 
        DataAnalysis..['listings New York$']
) AS t
INNER JOIN 
    Review_table2 AS rt2 ON t.name = rt2.Name
WHERE 
    rt2.Price > 0 
    AND Reviews > 10
    AND Score IS NOT NULL
GROUP BY 
    t.room_type
ORDER BY 
    t.room_type;


/*
RoomType			Totalhosts	Superhosts	PercentSuperhosts
Entire home/apt		7940		3108		39.14%
Hotel room			88			3			3.41%
Private room		7518		3380		44.96%
Shared room			208			39			18.75%
*/

--------------------------------------------------------------------------------------------------
--Very few Superhosts own Hotel rooms; They are more interested in renting Private rooms		 |	
--Non Superhosts should try to move towards Private rooms or Entire homes for better results	 | 
--------------------------------------------------------------------------------------------------

--Checking availability
SELECT 
    Superhost, 
    AVG(availability_30) AS a30,
    AVG(availability_60) AS a60,
    AVG(availability_90) AS a90,
    AVG(availability_365) AS ay
FROM
(
    SELECT 
        *,
        CASE
            WHEN host_is_superhost = 'f' THEN 0
            ELSE 1
        END AS Superhost
    FROM 
        DataAnalysis..['listings New York$']
) AS t
INNER JOIN 
    Review_table2 AS rt2 ON t.name = rt2.Name
WHERE 
    rt2.Price > 0 
    AND Reviews > 10
    AND Score IS NOT NULL
    AND availability_30 > 0
GROUP BY 
    Superhost;


--Displaying the range, count of scores & percent of count of scores

      



--FOR VISUALIZATIONS PURPOSES
-----------------------------
-- Drop and create Vtable1
DROP TABLE IF EXISTS Vtable1;
CREATE TABLE Vtable1(
    category VARCHAR(200),
    Units INT,
    MinPrice FLOAT,
    MaxPrice FLOAT,
    AvgPrice FLOAT
);

-- Populate Vtable1
INSERT INTO Vtable1
SELECT 
    property_type, 
    COUNT(property_type),
    MIN(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    MAX(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)),
    ROUND(AVG(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)), 2)
FROM 
    DataAnalysis..['listings New York$']
WHERE 
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
GROUP BY 
    property_type;

-- Display Vtable1 contents
SELECT * FROM Vtable1;

-- Retrieve neighborhood statistics
WITH NeighborhoodStats AS (
    SELECT 
        neighbourhood_group_cleansed,
        neighbourhood_cleansed,
        AVG(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)) OVER (PARTITION BY neighbourhood_cleansed ORDER BY neighbourhood_group_cleansed) AS avgp, 
        AVG(review_scores_rating) OVER (PARTITION BY neighbourhood_cleansed ORDER BY neighbourhood_group_cleansed) AS scores,  
        SUM(number_of_reviews) OVER (PARTITION BY neighbourhood_cleansed ORDER BY neighbourhood_group_cleansed) AS rev
    FROM 
        DataAnalysis..['listings New York$']
    WHERE 
        CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
        AND review_scores_rating > 0
)

-- Display neighborhood statistics
SELECT 
    neighbourhood_group_cleansed,
    neighbourhood_cleansed,
    COUNT(*) AS Listings,
    ROUND(MIN(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)), 2) AS minp,
    ROUND(MAX(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)), 2) AS maxp,
    ROUND(AVG(CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT)), 2) AS avgp,
    ROUND(MIN(review_scores_rating), 2) AS minscores, 
    ROUND(MAX(review_scores_rating), 2) AS maxscores, 
    ROUND(AVG(review_scores_rating), 2) AS avgscores, 
    SUM(number_of_reviews) AS rev,
    SUM(accommodates) AS acc
FROM 
    DataAnalysis..['listings New York$']
WHERE 
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
    AND review_scores_rating > 0
    AND accommodates <> 0
GROUP BY 
    neighbourhood_group_cleansed, 
    neighbourhood_cleansed
ORDER BY 
    neighbourhood_group_cleansed, 
    neighbourhood_cleansed;



--Changing data as per locations file for Tableau
-------------------------------------------------
select 
neighbourhood_group_cleansed,
t.NeighbourhoodArea,
count(*) as Listings,
round(min(cast(replace(substring(price,2,10),',','') as float)),2) as minp,
round(max(cast(replace(substring(price,2,10),',','') as float)),2) as maxp,
round(avg(cast(replace(substring(price,2,10),',','') as float)),2) as avgp,
round(min(review_scores_rating),2)  as minscores, 
round(max(review_scores_rating),2)  as maxscores, 
round(avg(review_scores_rating),2)  as avgscores, 
sum(number_of_reviews) as rev,
sum(accommodates) as acc
from
(
select *,
case 
	when neighbourhood_cleansed='Baychester' then replace(neighbourhood_cleansed,'Baychester', 'Eastchester-Edenwald-Baychester')
	when neighbourhood_cleansed='Eastchester' then replace(neighbourhood_cleansed,'Eastchester', 'Eastchester-Edenwald-Baychester')
	when neighbourhood_cleansed='Edenwald' then replace(neighbourhood_cleansed,'Edenwald', 'Eastchester-Edenwald-Baychester')
	when neighbourhood_cleansed='Kingsbridge' then replace(neighbourhood_cleansed,'Kingsbridge', 'Kingsbridge-Marble Hill')
	when neighbourhood_cleansed='Mott Haven' then replace(neighbourhood_cleansed,'Mott Haven', 'Mott Haven-Port Morris')
	when neighbourhood_cleansed='Port Morris' then replace(neighbourhood_cleansed,'Port Morris', 'Mott Haven-Port Morris')
	when neighbourhood_cleansed='Mount Eden' then replace(neighbourhood_cleansed,'Mount Eden', 'Mount Eden-Claremont(West)')
	when neighbourhood_cleansed='Claremont Village' then replace(neighbourhood_cleansed,'Claremont Village', 'Mount Eden-Claremont(West)')
	when neighbourhood_cleansed='Bronxdale' then replace(neighbourhood_cleansed,'Bronxdale', 'Bronx Park')
	when neighbourhood_cleansed='Castle Hill' then replace(neighbourhood_cleansed,'Castle Hill', 'Castle Hill-Unionport')
	when neighbourhood_cleansed='Concourse' then replace(neighbourhood_cleansed,'Concourse', 'Concourse-Concourse Village')
	when neighbourhood_cleansed='Concourse Village' then replace(neighbourhood_cleansed,'Concourse Village', 'Concourse-Concourse Village')
	when neighbourhood_cleansed='Pelham Bay' then replace(neighbourhood_cleansed,'Pelham Bay', 'Pelham Bay-Country Club-City Island')
	when neighbourhood_cleansed='Country Club' then replace(neighbourhood_cleansed,'Country Club', 'Pelham Bay-Country Club-City Island')
	when neighbourhood_cleansed='City Island' then replace(neighbourhood_cleansed,'City Island', 'Pelham Bay-Country Club-City Island')
	when neighbourhood_cleansed='Van Nest' then replace(neighbourhood_cleansed,'Van Nest', 'Pelham Parkway-Van Nest')
	when neighbourhood_cleansed='Riverdale' then replace(neighbourhood_cleansed,'Riverdale', 'Riverdale-Spuyten Duyvil')
	when neighbourhood_cleansed='Spuyten Duyvil' then replace(neighbourhood_cleansed,'Spuyten Duyvil', 'Riverdale-Spuyten Duyvil')
	when neighbourhood_cleansed='Soundview' then replace(neighbourhood_cleansed,'Soundview', 'Soundview-Clason Point')
	when neighbourhood_cleansed='Clason Point' then replace(neighbourhood_cleansed,'Clason Point', 'Soundview-Clason Point')
	when neighbourhood_cleansed='Throgs Neck' then replace(neighbourhood_cleansed,'Throgs Neck', 'Throgs Neck-Schuylerville')
	when neighbourhood_cleansed='Schuylerville' then replace(neighbourhood_cleansed,'Schuylerville', 'Throgs Neck-Schuylerville')
	when neighbourhood_cleansed='University Heights' then replace(neighbourhood_cleansed,'University Heights', 'University Heights (South)-Morris Heights')
	when neighbourhood_cleansed='Morris Heights' then replace(neighbourhood_cleansed,'Morris Heights', 'University Heights (South)-Morris Heights')
	when neighbourhood_cleansed='Wakefield' then replace(neighbourhood_cleansed,'Wakefield', 'Wakefield-Woodlawn')
	when neighbourhood_cleansed='Woodlawn' then replace(neighbourhood_cleansed,'Woodlawn', 'Wakefield-Woodlawn')
	when neighbourhood_cleansed='Williamsbridge' then replace(neighbourhood_cleansed,'Williamsbridge', 'Williamsbridge-Olinville')
	when neighbourhood_cleansed='Olinville' then replace(neighbourhood_cleansed,'Olinville', 'Williamsbridge-Olinville')
	when neighbourhood_cleansed='Bedford-Stuyvesant' then replace(neighbourhood_cleansed,'Bedford-Stuyvesant', 'Bedford-Stuyvesant (East)')
	when neighbourhood_cleansed='Bushwick' then replace(neighbourhood_cleansed,'Bushwick', 'Bushwick (West)')
	when neighbourhood_cleansed='Carroll Gardens' then replace(neighbourhood_cleansed,'Carroll Gardens', 'Carroll Gardens-Cobble Hill-Gowanus-Red Hook')
	when neighbourhood_cleansed='Cobble Hill' then replace(neighbourhood_cleansed,'Cobble Hill', 'Carroll Gardens-Cobble Hill-Gowanus-Red Hook')
	when neighbourhood_cleansed='Gowanus' then replace(neighbourhood_cleansed,'Gowanus', 'Carroll Gardens-Cobble Hill-Gowanus-Red Hook')
	when neighbourhood_cleansed='Red Hook' then replace(neighbourhood_cleansed,'Red Hook', 'Carroll Gardens-Cobble Hill-Gowanus-Red Hook')
	when neighbourhood_cleansed='Coney Island' then replace(neighbourhood_cleansed,'Coney Island', 'Coney Island-Sea Gate')
	when neighbourhood_cleansed='Sea Gate' then replace(neighbourhood_cleansed,'Sea Gate', 'Coney Island-Sea Gate')
	when neighbourhood_cleansed='Crown Heights' then replace(neighbourhood_cleansed,'Crown Heights', 'Crown Heights (North)')
	when neighbourhood_cleansed='Downtown Brooklyn' then replace(neighbourhood_cleansed,'Downtown Brooklyn', 'Downtown Brooklyn-DUMBO-Boerum Hill')
	when neighbourhood_cleansed='DUMBO' then replace(neighbourhood_cleansed,'DUMBO', 'Downtown Brooklyn-DUMBO-Boerum Hill')
	when neighbourhood_cleansed='Boerum Hill' then replace(neighbourhood_cleansed,'Boerum Hill', 'Downtown Brooklyn-DUMBO-Boerum Hill')
	when neighbourhood_cleansed='East Flatbush' then replace(neighbourhood_cleansed,'East Flatbush', 'East Flatbush-Erasmus')
	when neighbourhood_cleansed='East New York' then replace(neighbourhood_cleansed,'East New York', 'East New York-City Line')
	when neighbourhood_cleansed='Gravesend' then replace(neighbourhood_cleansed,'Gravesend', 'Gravesend (South)')
	when neighbourhood_cleansed='Bergen Beach' then replace(neighbourhood_cleansed,'Bergen Beach', 'Marine Park-Mill Basin-Bergen Beach')
	when neighbourhood_cleansed='Mill Basin' then replace(neighbourhood_cleansed,'Mill Basin', 'Marine Park-Mill Basin-Bergen Beach')
	when neighbourhood_cleansed='Prospect Lefferts Gardens' then replace(neighbourhood_cleansed,'Prospect Lefferts Gardens', 'Prospect Lefferts Gardens-Wingate')
	when neighbourhood_cleansed='Sheepshead Bay' then replace(neighbourhood_cleansed,'Sheepshead Bay', 'Sheepshead Bay-Manhattan Beach-Gerritsen Beach')
	when neighbourhood_cleansed='Manhattan Beach' then replace(neighbourhood_cleansed,'Manhattan Beach', 'Sheepshead Bay-Manhattan Beach-Gerritsen Beach')	
	when neighbourhood_cleansed='Gerritsen Beach' then replace(neighbourhood_cleansed,'Gerritsen Beach', 'Sheepshead Bay-Manhattan Beach-Gerritsen Beach')	
	when neighbourhood_cleansed='Williamsburg' then replace(neighbourhood_cleansed,'Williamsburg', 'South Williamsburg')
	when neighbourhood_cleansed='Sunset Park' then replace(neighbourhood_cleansed,'Sunset Park', 'Sunset Park (Central)')
	when neighbourhood_cleansed='Windsor Terrace' then replace(neighbourhood_cleansed,'Windsor Terrace', 'Windsor Terrace-South Slope')
	when neighbourhood_cleansed='South Slope' then replace(neighbourhood_cleansed,'South Slope', 'Williamsbridge-Olinville')
	when neighbourhood_cleansed='Chelsea' then replace(neighbourhood_cleansed,'Chelsea', 'Chelsea-Hudson Yards')
	when neighbourhood_cleansed='Chinatown' then replace(neighbourhood_cleansed,'Chinatown', 'Chinatown-Two Bridges')
	when neighbourhood_cleansed='Two Bridges' then replace(neighbourhood_cleansed,'Two Bridges', 'Chinatown-Two Bridges')
	when neighbourhood_cleansed='East Harlem' then replace(neighbourhood_cleansed,'East Harlem', 'East Harlem (North)')
	when neighbourhood_cleansed='Financial District' then replace(neighbourhood_cleansed,'Financial District', 'Financial District-Battery Park City')
	when neighbourhood_cleansed='Battery Park City' then replace(neighbourhood_cleansed,'Battery Park City', 'Financial District-Battery Park City')
	when neighbourhood_cleansed='Harlem' then replace(neighbourhood_cleansed,'Harlem', 'Harlem (North)')
	when neighbourhood_cleansed='Flatiron District' then replace(neighbourhood_cleansed,'Flatiron District', 'Midtown South-Flatiron-Union Square')
	when neighbourhood_cleansed='Midtown' then replace(neighbourhood_cleansed,'Midtown', 'Midtown-Times Square')
	when neighbourhood_cleansed='Murray Hill' then replace(neighbourhood_cleansed,'Murray Hill', 'Murray Hill-Kips Bay')
	when neighbourhood_cleansed='Kips Bay' then replace(neighbourhood_cleansed,'Kips Bay', 'Murray Hill-Kips Bay')
	when neighbourhood_cleansed='SoHo' then replace(neighbourhood_cleansed,'SoHo', 'SoHo-Little Italy-Hudson Square')
	when neighbourhood_cleansed='Little Italy' then replace(neighbourhood_cleansed,'Little Italy', 'SoHo-Little Italy-Hudson Square')
	when neighbourhood_cleansed='Stuyvesant Town' then replace(neighbourhood_cleansed,'Stuyvesant Town', 'Stuyvesant Peter Cooper Village')
	when neighbourhood_cleansed='Tribeca' then replace(neighbourhood_cleansed,'Tribeca', 'Tribeca-Civic Center')
	when neighbourhood_cleansed='Civic Center' then replace(neighbourhood_cleansed,'Civic Center', 'Tribeca-Civic Center')
	when neighbourhood_cleansed='Upper East Side' then replace(neighbourhood_cleansed,'Upper East Side', 'Upper East Side-Lenox Hill-Roosevelt Island')
	when neighbourhood_cleansed='Roosevelt Island' then replace(neighbourhood_cleansed,'Roosevelt Island', 'Upper East Side-Lenox Hill-Roosevelt Island')
	when neighbourhood_cleansed='Upper West Side' then replace(neighbourhood_cleansed,'Upper West Side', 'Upper West Side (Central)')
	when neighbourhood_cleansed='Washington Heights' then replace(neighbourhood_cleansed,'Washington Heights', 'Washington Heights (South)')
	when neighbourhood_cleansed='Astoria' then replace(neighbourhood_cleansed,'Astoria', 'Astoria (North)-Ditmars-Steinway')
	when neighbourhood_cleansed='Ditmars Steinway' then replace(neighbourhood_cleansed,'Ditmars Steinway', 'Astoria (North)-Ditmars-Steinway')
	when neighbourhood_cleansed='Breezy Point' then replace(neighbourhood_cleansed,'Breezy Point', 'Breezy Point-Belle Harbor-Rockaway Park-Broad Channel')
	when neighbourhood_cleansed='Belle Harbor' then replace(neighbourhood_cleansed,'Belle Harbor', 'Breezy Point-Belle Harbor-Rockaway Park-Broad Channel')
	when neighbourhood_cleansed='Douglaston' then replace(neighbourhood_cleansed,'Douglaston', 'Douglaston-Little Neck')
	when neighbourhood_cleansed='Little Neck' then replace(neighbourhood_cleansed,'Little Neck', 'Douglaston-Little Neck')
	when neighbourhood_cleansed='Flushing' then replace(neighbourhood_cleansed,'Flushing', 'Flushing-Willets Point')
	when neighbourhood_cleansed='Fresh Meadows' then replace(neighbourhood_cleansed,'Fresh Meadows', 'Fresh Meadows-Utopia')
	when neighbourhood_cleansed='Howard Beach' then replace(neighbourhood_cleansed,'Howard Beach', 'Howard Beach-Lindenwood')
	when neighbourhood_cleansed='Jamaica Estates' then replace(neighbourhood_cleansed,'Jamaica Estates', 'Jamaica Estates-Holliswood')
	when neighbourhood_cleansed='Holliswood' then replace(neighbourhood_cleansed,'Holliswood', 'Jamaica Estates-Holliswood')
	when neighbourhood_cleansed='Jamaica Hills' then replace(neighbourhood_cleansed,'Jamaica Hills', 'Jamaica Hills-Briarwood')
	when neighbourhood_cleansed='Briarwood' then replace(neighbourhood_cleansed,'Briarwood', 'Jamaica Hills-Briarwood')
	when neighbourhood_cleansed='Long Island City' then replace(neighbourhood_cleansed,'Long Island City', 'Long Island City-Hunters Point')
	when neighbourhood_cleansed='Hollis' then replace(neighbourhood_cleansed,'Hollis', 'Oakland Gardens-Hollis Hills')
	when neighbourhood_cleansed='Rockaway Beach' then replace(neighbourhood_cleansed,'Rockaway Beach', 'Rockaway Beach-Arverne-Edgemere')
	when neighbourhood_cleansed='Arverne' then replace(neighbourhood_cleansed,'Arverne', 'Rockaway Beach-Arverne-Edgemere')
	when neighbourhood_cleansed='Edgemere' then replace(neighbourhood_cleansed,'Edgemere', 'Rockaway Beach-Arverne-Edgemere')
	when neighbourhood_cleansed='Springfield Gardens' then replace(neighbourhood_cleansed,'Springfield Gardens', 'Springfield Gardens (South)-Brookville')
	when neighbourhood_cleansed='Whitestone' then replace(neighbourhood_cleansed,'Whitestone', 'Whitestone-Beechhurst')
	when neighbourhood_cleansed='Huguenot' then replace(neighbourhood_cleansed,'Huguenot', 'Annadale-Huguenot-Prince''s Bay-Woodrow')
	when neighbourhood_cleansed='Prince''s Bay' then replace(neighbourhood_cleansed,'Prince''s Bay', 'Annadale-Huguenot-Prince''s Bay-Woodrow')
	when neighbourhood_cleansed='Woodrow' then replace(neighbourhood_cleansed,'Woodrow', 'Annadale-Huguenot-Prince''s Bay-Woodrow')
	when neighbourhood_cleansed='Arden Heights' then replace(neighbourhood_cleansed,'Arden Heights', 'Arden Heights-Rossville')
	when neighbourhood_cleansed='Rossville' then replace(neighbourhood_cleansed,'Rossville', 'Arden Heights-Rossville')
	when neighbourhood_cleansed='Arrochar' then replace(neighbourhood_cleansed,'Arrochar', 'Grasmere-Arrochar-South Beach-Dongan Hills')
	when neighbourhood_cleansed='Dongan Hills' then replace(neighbourhood_cleansed,'Dongan Hills', 'Grasmere-Arrochar-South Beach-Dongan Hills')
	when neighbourhood_cleansed='South Beach' then replace(neighbourhood_cleansed,'South Beach', 'Grasmere-Arrochar-South Beach-Dongan Hills')
	when neighbourhood_cleansed='Great Kills' then replace(neighbourhood_cleansed,'Great Kills', 'Great Kills-Eltingville')
	when neighbourhood_cleansed='Eltingville Kills' then replace(neighbourhood_cleansed,'Eltingville Kills', 'Great Kills-Eltingville')
	when neighbourhood_cleansed='Graniteville' then replace(neighbourhood_cleansed,'Graniteville', 'Mariner''s Harbor-Arlington-Graniteville')
	when neighbourhood_cleansed='Mariners Harbor' then replace(neighbourhood_cleansed,'Mariners Harbor', 'Mariner''s Harbor-Arlington-Graniteville')
	when neighbourhood_cleansed='New Dorp' then replace(neighbourhood_cleansed,'New Dorp', 'New Dorp-Midland Beach')
	when neighbourhood_cleansed='Midland Beach' then replace(neighbourhood_cleansed,'Midland Beach', 'New Dorp-Midland Beach')
	when neighbourhood_cleansed='New Springville' then replace(neighbourhood_cleansed,'New Springville', 'New Springville-Willowbrook-Bulls Head-Travis')
	when neighbourhood_cleansed='Bull''s Head' then replace(neighbourhood_cleansed,'Bull''s Head', 'New Springville-Willowbrook-Bulls Head-Travis')
	when neighbourhood_cleansed='Oakwood' then replace(neighbourhood_cleansed,'Oakwood', 'Oakwood-Richmondtown')
	when neighbourhood_cleansed='Richmondtown' then replace(neighbourhood_cleansed,'Oakwood', 'Oakwood-Richmondtown')
	when neighbourhood_cleansed='Rosebank' then replace(neighbourhood_cleansed,'Rosebank', 'Rosebank-Shore Acres-Park Hill')
	when neighbourhood_cleansed='Shore Acres' then replace(neighbourhood_cleansed,'Shore Acres', 'Rosebank-Shore Acres-Park Hill')
	when neighbourhood_cleansed='New Brighton' then replace(neighbourhood_cleansed,'New Brighton', 'St. George-New Brighton')
	when neighbourhood_cleansed='St. George' then replace(neighbourhood_cleansed,'St. George', 'St. George-New Brighton')
	when neighbourhood_cleansed='Todt Hill' then replace(neighbourhood_cleansed,'Todt Hill', 'Todt Hill-Emerson Hill-Lighthouse Hill-Manor Heights')
	when neighbourhood_cleansed='Emerson Hill' then replace(neighbourhood_cleansed,'Emerson Hill', 'Todt Hill-Emerson Hill-Lighthouse Hill-Manor Heights')
	when neighbourhood_cleansed='Lighthouse Hill' then replace(neighbourhood_cleansed,'Lighthouse Hill', 'Todt Hill-Emerson Hill-Lighthouse Hill-Manor Heights')
	when neighbourhood_cleansed='Tompkinsville' then replace(neighbourhood_cleansed,'Tompkinsville', 'Tompkinsville-Stapleton-Clifton-Fox Hills')
	when neighbourhood_cleansed='Stapleton' then replace(neighbourhood_cleansed,'Stapleton', 'Tompkinsville-Stapleton-Clifton-Fox Hills')
	when neighbourhood_cleansed='Clifton' then replace(neighbourhood_cleansed,'Clifton', 'Tompkinsville-Stapleton-Clifton-Fox Hills')
	when neighbourhood_cleansed='West Brighton' then replace(neighbourhood_cleansed,'West Brighton', 'West New Brighton-Silver Lake-Grymes Hill')
	when neighbourhood_cleansed='Silver Lake' then replace(neighbourhood_cleansed,'Silver Lake', 'West New Brighton-Silver Lake-Grymes Hill')
	when neighbourhood_cleansed='Grymes Hill' then replace(neighbourhood_cleansed,'Grymes Hill', 'West New Brighton-Silver Lake-Grymes Hill')
	when neighbourhood_cleansed='Westerleigh' then replace(neighbourhood_cleansed,'Westerleigh', 'Westerleigh-Castleton Corners')

	else neighbourhood_cleansed
end as NeighbourhoodArea
from DataAnalysis..['listings New York$']
where cast(replace(substring(price,2,10),',','') as float)>0
--and neighbourhood_cleansed='Allerton'
and review_scores_rating>0
and accommodates<>0
) t
group by neighbourhood_group_cleansed, t.NeighbourhoodArea
order by neighbourhood_group_cleansed, t.NeighbourhoodArea

--Details
-- Details for Neighbourhood groups
WITH CleanedListings AS (
    SELECT 
        *,
        CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) AS Pricing
    FROM 
        DataAnalysis..['listings New York$']
    WHERE 
        CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
        AND review_scores_rating > 0
)

SELECT  
    neighbourhood_group_cleansed,
    COUNT(*) AS Listings,
    SUM(accommodates) AS Accomodations,
    SUM(number_of_reviews) AS Reviews,
    ROUND(AVG(review_scores_rating), 2) AS Average_Ratings,
    CONCAT('$', ROUND(AVG(Pricing), 2)) AS Average_Pricing
FROM 
    CleanedListings
GROUP BY 
    neighbourhood_group_cleansed;



--Listings info
SELECT 
    host_id, 
    host_name,
    ISNULL(name, ' - ') AS name, 
    ISNULL(neighborhood_overview, ' - ') AS neighborhood_overview, 
    neighbourhood_cleansed, 
    neighbourhood_group_cleansed, 
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) AS Price, 
    property_type, 
    room_type,
    CASE 
        WHEN host_is_superhost = 't' THEN 'Superhost'
        WHEN host_is_superhost = 'f' THEN 'Not Superhost'
    END AS Superhost,
    review_scores_rating, 
    latitude, 
    longitude, 
    accommodates,
    CAST(
        ISNULL(
            REPLACE(
                bathrooms_text,
                (SUBSTRING(bathrooms_text, PATINDEX('%[a-z]%', bathrooms_text), LEN(bathrooms_text))),
                ''
            ),
            0
        ) AS FLOAT
    ) AS Bathrooms, 
    ISNULL(bedrooms, 0) AS bedrooms, 
    minimum_nights, 
    maximum_nights,
    review_scores_accuracy, 
    review_scores_checkin, 
    review_scores_cleanliness, 
    review_scores_communication, 
    review_scores_location, 
    review_scores_value, 
    number_of_reviews,
    listing_url
FROM 
    DataAnalysis..['listings New York$']
WHERE
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
    AND review_scores_rating > 0
    AND host_name IS NOT NULL
ORDER BY 
    Superhost;

SELECT 
    host_id, 
    COUNT(*) AS listings 
FROM 
    DataAnalysis..['listings New York$']
WHERE
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
    AND review_scores_rating > 0
GROUP BY 
    host_id
ORDER BY 
    COUNT(*) DESC;
SELECT 
    CAST(SUM(listings) AS DECIMAL(10, 3)) * 100 AS sumof4percent
FROM (
    SELECT 
        host_id, 
        COUNT(*) AS listings,
        NTILE(25) OVER (ORDER BY COUNT(*) DESC) AS quartile
    FROM 
        DataAnalysis..['listings New York$']
    WHERE
        CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
        AND review_scores_rating > 0
    GROUP BY 
        host_id
) AS t
WHERE
    quartile <= 1;

/
SELECT 
    SUM(Tlistings) AS sumof100percent
FROM (
    SELECT 
        TOP 100 PERCENT
        COUNT(*) AS Tlistings 
    FROM 
        DataAnalysis..['listings New York$']
    WHERE
        CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
        AND review_scores_rating > 0
    GROUP BY 
        host_id
    ORDER BY 
        COUNT(*) DESC
) AS t1;

-- Percentage of listings with count > 3
SELECT CAST(COUNT(*) AS DECIMAL(10,3)) / 20065 AS percent
FROM DataAnalysis..['listings New York$']
WHERE
    CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
    AND review_scores_rating > 0
GROUP BY
    host_id
HAVING
    COUNT(*) > 3
ORDER BY
    COUNT(*) DESC;

-- Calculated percentages
SELECT CAST(3110 AS DECIMAL(10,3)) / 20065 AS percent1;
SELECT CAST(1198 AS DECIMAL(10,3)) / 20065 AS percent2;
SELECT CAST(624 AS DECIMAL(10,3)) / 20065 AS percent3;


SELECT SUM(listings)
FROM
(
    SELECT COUNT(*) AS listings
    FROM DataAnalysis..['listings New York$']
    WHERE
        CAST(REPLACE(SUBSTRING(price, 2, 10), ',', '') AS FLOAT) > 0
        AND review_scores_rating > 0
    GROUP BY host_id
    HAVING COUNT(*) > 0
) t;
