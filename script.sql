 
-- /****** Object:  Script   Script Date: 27/03/2023 4:39:35 PM ******/
 
-- -- =============================================
-- -- Author:		<JahsonK>
-- -- Create date: <27/03/2023>
-- -- Description:	<FIFA dirty data cleaning Script> 
-- -- =============================================

 
-- BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
SET NOCOUNT ON;

-- Insert the data into a temporary table 

SELECT  *  INTO #FifaData 
FROM Fifa21

GO


-- STEP 1: Find and remove duplicates from the dataset using Common Table Expressions(CTE).

-- Find the duplicate records by ID, LongName, Name, Nationality, Positions
-- Duplicated records will have a duplicate count greater than 1
-- Delete the duplicate records form the dataset.

WITH CTE (ID, LongName, Name, Nationality, Positions, DuplicateCount)
AS (SELECT
  ID,
  LongName,
  Name,
  Nationality,
  Positions,
  ROW_NUMBER() OVER (PARTITION BY ID, LongName, Name, Nationality, Positions
  ORDER BY id) AS DuplicateCount
FROM #FifaData)
DELETE FROM CTE
WHERE DuplicateCount > 1

--STEP 2: Players height 
-- The height of the players is recorded in foot and inches. Convert these to centimeters.
-- Begin by replacing the '' symbols with an empty space, then replace the foot value to be left with the inches
-- Multiply by 2.54 to convert them to CM
-- Get the first value on the left which is the height in foot, multiply by 30.48 to convert it to CM
-- Sum the two values to get the actual height in CM

UPDATE #FifaData
SET Height = (CAST(LEFT(Height, 1) AS int) * 30.48) + (CAST(REPLACE(REPLACE(Height, RIGHT(Height, 1), '')
, LEFT(Height, 1) + '''', '') AS int) * 2.54)


--STEP 3: Player Weight 
-- The player weight has a trailing lbs on the right that we should get rid of.
-- Removing the lbs you are left with the weight in pounds
-- You can opt to use Kilograms by multiplying the result with 0.454
UPDATE #FifaData
SET Weight = REPLACE(Weight, 'lbs', '')


-- STEP 4: Value, Wage and Release clause
-- These columns have a datatyoe nvarchar with a mixture of text symbols and numbers
-- To obtain the actual values we get rid of the pound sign and the trailing M - Million and K - thousand values
-- Multiply with 10^n where n is represents thousand or  million
--  

UPDATE #FifaData
SET Value = (
CASE
  WHEN RIGHT(Value, 1) = 'M' THEN CAST(REPLACE(REPLACE(Value, '€', ''), RIGHT(Value, 1), '') AS decimal) * 1000000
  WHEN RIGHT(Value, 1) = 'K' THEN CAST(REPLACE(REPLACE(Value, '€', ''), RIGHT(Value, 1), '') AS decimal) * 1000
  WHEN RIGHT(Value, 1) = '0' THEN 0
  ELSE REPLACE(Value, '€', '')
END)


UPDATE #FifaData
SET wage = (CASE
  WHEN RIGHT(wage, 1) = 'M' THEN CAST(REPLACE(REPLACE(wage, '€', ''), RIGHT(wage, 1), '') AS decimal) * 1000000
  WHEN RIGHT(wage, 1) = 'K' THEN CAST(REPLACE(REPLACE(wage, '€', ''), RIGHT(wage, 1), '') AS decimal) * 1000
  WHEN RIGHT(wage, 1) = '0' THEN 0
  ELSE REPLACE(wage, '€', '')
END)


UPDATE #FifaData
SET Release_Clause = (CASE
  WHEN RIGHT(Release_Clause, 1) = 'M' THEN CAST(REPLACE(REPLACE(Release_Clause, '€', ''), RIGHT(Release_Clause, 1), '') AS decimal) * 1000000
  WHEN RIGHT(Release_Clause, 1) = 'K' THEN CAST(REPLACE(REPLACE(Release_Clause, '€', ''), RIGHT(Release_Clause, 1), '') AS decimal) * 1000
  WHEN RIGHT(Release_Clause, 1) = '0' THEN 0
  ELSE REPLACE(Release_Clause, '€', '')
END)


--STEP 5: W_F, SM and IR columns 

-- Extract the integer value from these columns using patindex and the LEFT function that gives you the index 
--and values on the left for a given number of characters

UPDATE #FifaData
SET W_F = LEFT(W_F, PATINDEX('%[^0-9]%', W_F) - 1),
    SM = LEFT(SM, PATINDEX('%[^0-9]%', SM) - 1),
    IR = LEFT(IR, PATINDEX('%[^0-9]%', IR) - 1)


--STEP 6 Team_contract
 
 -- Split the years from the club and introduce new columns for each as start and end
   
-- Add rows generated from the data set

ALTER TABLE #FifaData ADD Team varchar(50)
ALTER TABLE #FifaData ADD StartYear int
ALTER TABLE #FifaData ADD EndYear int
ALTER TABLE #FifaData ADD LoanDate varchar(20)
ALTER TABLE #FifaData ADD TranserFee varchar(20) 

GO

-- Cleaning data in this column requires a combination of SQL functions
-- First we begin by team contrcats that are not Free and have no loan date.
-- These rows of data have similar patterns in the data 

UPDATE #FifaData
SET Team = REPLACE(REPLACE(REPLACE(Team_Contract, SUBSTRING(Team_Contract, PATINDEX('%[~]%', Team_Contract) - 5, 5), ''), SUBSTRING(Team_Contract, PATINDEX('%[~]%', Team_Contract) + 1, 5), ''), '~', ''),
    StartYear = SUBSTRING(Team_Contract, PATINDEX('%[~]%', Team_Contract) - 5, 5),
    EndYear = SUBSTRING(Team_Contract, PATINDEX('%[~]%', Team_Contract) + 1, 5)
FROM #FifaData
WHERE Team_Contract NOT LIKE '%Free%'
AND Team_Contract NOT LIKE '%Loan%'

-- Next are the rows that contain the  'Free' word

UPDATE #FifaData
SET Team = REPLACE(Team_Contract, 'Free', ''),
    TranserFee = 'Free'
FROM #FifaData
WHERE Team_Contract LIKE '%Free%'

-- Finaly players with Loans

UPDATE #FifaData
SET Team = REPLACE(REPLACE(Team_Contract, 'On Loan', ''),
    RIGHT(CAST(REPLACE(Team_Contract, 'On Loan', '') AS varchar(50)), 15),
    ''),
    LoanDate = RIGHT(CAST(REPLACE(Team_Contract, 'On Loan', '') AS varchar(50)), 15)
FROM #FifaData
WHERE Team_Contract LIKE '%Loan%'


-- STEP 7 Removing unnecessary columns and validating data types

ALTER TABLE #FifaData DROP COLUMN Team_Contract
ALTER TABLE #FifaData DROP COLUMN Loan_Date_End


-- Validating and cleaning columns

-- Hits column 

-- All the Hits values that are not Integers have a trailing K at the end of the value
-- Get rid of the value then update accordingly

-- CHAR(10) helps remove Line Feed from the resulting string
-- Cast the value as decimal then multiply with 1000

--SELECT
--  Hits,
--  ISNUMERIC(Hits),
--  LEN(Hits),
--  LEN(REPLACE( Hits, CHAR(10), '')),
--  CAST(REPLACE(REPLACE(Hits, 'K', ''), CHAR(10), '') AS decimal) * 1000
--FROM #FifaData
--WHERE ISNUMERIC(Hits) = 0

UPDATE #FifaData
SET Hits = CAST(REPLACE(REPLACE(Hits, 'K', ''), CHAR(10), '') AS decimal) * 1000
WHERE ISNUMERIC(Hits) = 0

-- clean line feed from all other columns 
UPDATE #FifaData
SET Hits = CAST(REPLACE( Hits, CHAR(10), '') AS decimal) 
WHERE ISNUMERIC(Hits) = 1

-- Convert the column to INT
ALTER TABLE #FifaData ALTER COLUMN Hits INT


-- Update other integer valued columns  
UPDATE #FifaData
SET IR = CAST(REPLACE( IR, CHAR(10), '') AS INT) 
,PAC = CAST(REPLACE( PAC, CHAR(10), '') AS INT)
,SHO = CAST(REPLACE( SHO, CHAR(10), '') AS INT)
,PAS = CAST(REPLACE( PAS, CHAR(10), '') AS INT)
,DRI = CAST(REPLACE( DRI, CHAR(10), '') AS INT)
,DEF = CAST(REPLACE( DEF, CHAR(10), '') AS INT)
,PHY = CAST(REPLACE( PHY, CHAR(10), '') AS INT)
 

ALTER TABLE #FifaData ALTER COLUMN IR INT
ALTER TABLE #FifaData ALTER COLUMN PAC INT
ALTER TABLE #FifaData ALTER COLUMN SHO INT
ALTER TABLE #FifaData ALTER COLUMN PAS INT
ALTER TABLE #FifaData ALTER COLUMN DRI INT
ALTER TABLE #FifaData ALTER COLUMN DEF INT
ALTER TABLE #FifaData ALTER COLUMN PHY INT

ALTER TABLE #FifaData ALTER COLUMN SM INT
ALTER TABLE #FifaData ALTER COLUMN W_F INT
ALTER TABLE #FifaData ALTER COLUMN Base_Stats INT
ALTER TABLE #FifaData ALTER COLUMN Total_Stats INT
ALTER TABLE #FifaData ALTER COLUMN GK_Reflexes INT
ALTER TABLE #FifaData ALTER COLUMN GK_Kicking INT
ALTER TABLE #FifaData ALTER COLUMN Gk_Handling INT


ALTER TABLE #FifaData ALTER COLUMN GK_Diving INT
ALTER TABLE #FifaData ALTER COLUMN GoalKeeping INT
ALTER TABLE #FifaData ALTER COLUMN Sliding_Tackle INT
ALTER TABLE #FifaData ALTER COLUMN Standing_Tackle INT
ALTER TABLE #FifaData ALTER COLUMN Marking INT
ALTER TABLE #FifaData ALTER COLUMN Defending INT
ALTER TABLE #FifaData ALTER COLUMN Composure INT


ALTER TABLE #FifaData ALTER COLUMN Penalties INT
ALTER TABLE #FifaData ALTER COLUMN Vision INT
ALTER TABLE #FifaData ALTER COLUMN Positioning INT
ALTER TABLE #FifaData ALTER COLUMN Interceptions INT
ALTER TABLE #FifaData ALTER COLUMN Aggression INT
ALTER TABLE #FifaData ALTER COLUMN Mentality INT
ALTER TABLE #FifaData ALTER COLUMN Long_Shots INT

ALTER TABLE #FifaData ALTER COLUMN Strength INT
ALTER TABLE #FifaData ALTER COLUMN Stamina INT
ALTER TABLE #FifaData ALTER COLUMN Jumping INT
ALTER TABLE #FifaData ALTER COLUMN Power INT
ALTER TABLE #FifaData ALTER COLUMN Balance INT
ALTER TABLE #FifaData ALTER COLUMN Reactions INT
ALTER TABLE #FifaData ALTER COLUMN Agility INT

ALTER TABLE #FifaData ALTER COLUMN Sprint_Speed INT
ALTER TABLE #FifaData ALTER COLUMN Acceleration INT
ALTER TABLE #FifaData ALTER COLUMN Movement INT
ALTER TABLE #FifaData ALTER COLUMN Ball_Control INT
ALTER TABLE #FifaData ALTER COLUMN Long_Passing INT
ALTER TABLE #FifaData ALTER COLUMN FK_Accuracy INT
ALTER TABLE #FifaData ALTER COLUMN Curve INT

ALTER TABLE #FifaData ALTER COLUMN Dribbling INT
ALTER TABLE #FifaData ALTER COLUMN Skill INT
ALTER TABLE #FifaData ALTER COLUMN Volleys INT
ALTER TABLE #FifaData ALTER COLUMN Short_Passing INT
ALTER TABLE #FifaData ALTER COLUMN Heading_Accuracy INT
ALTER TABLE #FifaData ALTER COLUMN Finishing INT
ALTER TABLE #FifaData ALTER COLUMN Crossing INT

ALTER TABLE #FifaData ALTER COLUMN Attacking INT
ALTER TABLE #FifaData ALTER COLUMN Growth INT
ALTER TABLE #FifaData ALTER COLUMN BOV INT
ALTER TABLE #FifaData ALTER COLUMN Weight INT
ALTER TABLE #FifaData ALTER COLUMN Height DECIMAL(10,2)
ALTER TABLE #FifaData ALTER COLUMN POT INT
ALTER TABLE #FifaData ALTER COLUMN OVA INT
ALTER TABLE #FifaData ALTER COLUMN Age INT


-- STEP 8 Detecting outliers

-- You can use ORDER BY to detect if there any outliers in the columns
-- For instance to check for outliers in weight, the following query can be used.

-- select Name,Weight from #FifaData order by Weight desc



-- Display the cleaned data

Select * from #FifaData  


-- END