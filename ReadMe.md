# FIFA Data Cleaning.


## Introduction

Data cleaning is one of the most critical stages of dat analysis and visualization. Without this step insights genrated from the data are likely to be inaccurate and with errors. The dataset for cleaning in this exercise is the FIFA data available [here](https://www.kaggle.com/datasets/yagunnersya/fifa-21-messy-raw-dataset-for-cleaning-exploring) scraped from Sofia.com. This dataset contains messy FIFA21 data about player ratings, club contracts, loans and stats.
In the process of cleaning this data the following are the objectives I had in mind to make this data ready for analysis:-
- Identifying and removing duplicate rows of data
- Identifying wrong data type columns 
- Identifying outliers

## Overview of the data

The data is provided in csv format which can easily be opened in excel or google sheets for an overview of how the data looks like, the columns within the dataset and by just a glance you can identify the data types of each of the column. The first step of cleaning the data was by importing the csv into SQL server database management system into a table that I named FifaData and then writting scripts to clean each of the columns data. By just looking at the columns, Team_contract, Value, Wages,Release clause and many other columns require transformation into a clean state. In this repository you will find the dataset before cleaning and the after cleaning. 

## Data Cleaning

 ### Removing Duplicates

 The fisrt step in the cleaning process is identifying and removing duplicates from the dataset. I found out that the row
 
  is duplicated and therefore using SQL Common Table Expressions(CTE) i removed the duplicate row by executing the following query. Having over 70 columns in the dataset, I used just a few columns i.e ID, LongName, Name, Nationality, Positions, DuplicateCount to identify the duplicates. In this case i made the assumption that there are no two players with the same name, coming from the same country and playing the same position. 
  The query in the CTE returns a count of 1 for non repeating rows and a value greater than one for repeating rows. 

```sql
  WITH CTE (ID, LongName, Name, Nationality, Positions, DuplicateCount)
AS (SELECT
  ID,
  LongName,
  Name,
  Nationality,
  Positions,
  ROW_NUMBER() OVER (PARTITION BY ID, LongName, Name, Nationality, Positions
  ORDER BY id) AS DuplicateCount
FROM FifaData)
DELETE FROM CTE
WHERE DuplicateCount > 1

```

You can check for duplicates after executing the above query with the following query.

```sql
SELECT COUNT(ID), COUNT(DISTINCT ID) from FifaData
```
The query should result should be equal for both *COUNT(ID)* and *COUNT(DISTINCT ID)* otherwise duplicates still exists.

 ### Player Height

After removing duplicates, its time to check the data in each column and then identity the columns that need cleaning. The first column was the height column whose data is in foot and inches. In order to perform aggregations on this column or any mathematical calculations then this column has to be transformed into a decimal or integer data type. This means converting the foot and inches to either centimeters or meters. In this case is used the query below to convert the height into Centimeters.
Notice that a series of SQL functions are used to achieve the goal. These include **REPLACE** that is used to replace values in a string with another value, **LEFT** which is a function that returns all characters from the left of the string to a given position and the **CAST** which converts the result into INT data type before perfoming the conversion. 

```sql
UPDATE FifaData
SET Height = (CAST(LEFT(Height, 1) AS int) * 30.48) + (CAST(REPLACE(REPLACE(Height, RIGHT(Height, 1), '')
, LEFT(Height, 1) + '''', '') AS int) * 2.54)

```

 ### Player Weight

 The next column to clean is the Weight of the players. Looking carefully at the data the weight is in lbs with a trailing 'lbs' at the end of each value. By replacing the 'lbs' text on the values the weight column is cleaned. You may however opt to convert the pounds into kgs by multiplying the result by 0.454

 ```sql
 UPDATE FifaData
SET Weight = REPLACE(Weight, 'lbs', '')

```


 ### Wage, Value and Release Clause
The wage,value and release clause data is all in a similar format and the same criteria can be applied while cleaning the data. To begin with, we do away with the Pound symbol at the start of each values, then check for the leters **M** and **K** and remove them as well using the **REPLACE** function. Now, we are left with a decimal value that we then multiply with either 1000 or 1000000 for **K** and **M** values respectively. In the event that these columns are missing the two letters, then we just keep the original value 

```sql


UPDATE FifaData
SET Value = (
CASE
  WHEN RIGHT(Value, 1) = 'M' THEN CAST(REPLACE(REPLACE(Value, '�', ''), RIGHT(Value, 1), '') AS decimal) * 1000000
  WHEN RIGHT(Value, 1) = 'K' THEN CAST(REPLACE(REPLACE(Value, '�', ''), RIGHT(Value, 1), '') AS decimal) * 1000
  WHEN RIGHT(Value, 1) = '0' THEN 0
  ELSE (REPLACE(Value, '�', '')
END)


UPDATE FifaData
SET wage = (CASE
  WHEN RIGHT(wage, 1) = 'M' THEN CAST(REPLACE(REPLACE(wage, '�', ''), RIGHT(wage, 1), '') AS decimal) * 1000000
  WHEN RIGHT(wage, 1) = 'K' THEN CAST(REPLACE(REPLACE(wage, '�', ''), RIGHT(wage, 1), '') AS decimal) * 1000
  WHEN RIGHT(wage, 1) = '0' THEN 0
  ELSE (REPLACE(wage, '�', '')
END)


UPDATE FifaData
SET Release_Clause = (CASE
  WHEN RIGHT(Release_Clause, 1) = 'M' THEN CAST(REPLACE(REPLACE(Release_Clause, '�', ''), RIGHT(Release_Clause, 1), '') AS decimal) * 1000000
  WHEN RIGHT(Release_Clause, 1) = 'K' THEN CAST(REPLACE(REPLACE(Release_Clause, '�', ''), RIGHT(Release_Clause, 1), '') AS decimal) * 1000
  WHEN RIGHT(Release_Clause, 1) = '0' THEN 0
  ELSE (REPLACE(Release_Clause, '�', '')
END)

```


 ### W_F, SM and IR

 These columns are expected to contain intefer values only but seem to be having some special character at the end of the value. To clean the values, I used the **PATINDEX** function together with the **LEFT** function to get the integer value.

 **PATINDEX** function in SQL returns the position of a pattern or value in a string. If the value or pattern is not found then it returns 0. In this case we are supposed to get the integer value from the string and therefore I pass the regex **[^0-9]** for integer numbers. 

```sql
 UPDATE FifaData
SET W_F = LEFT(W_F, PATINDEX('%[^0-9]%', W_F) - 1),
    SM = LEFT(SM, PATINDEX('%[^0-9]%', SM) - 1),
    IR = LEFT(IR, PATINDEX('%[^0-9]%', IR) - 1)

```

 ### Team Contract

 This was one of the most challenging column especially extracting the start and end years from the string. Fisrt I discovered that there columns that have on loan and free transfer and others that have the start and end of contact period. To obtain the contract years, I had to the process into 3 steps i.e begin with columns that have contract years followed by Free and then on Loan. 

 I used a combination of **PATINDEX**, **SUBSTRING** and **REPLACE** to separate the team from the start and end Year. Before the update, I added some extra columns to the dataset for the new columns extracted from the Team_contract.

 ```sql
ALTER TABLE FifaData ADD Team varchar(50)
ALTER TABLE FifaData ADD StartYear int
ALTER TABLE FifaData ADD EndYear int
ALTER TABLE FifaData ADD LoanDate varchar(20)
ALTER TABLE FifaData ADD TranserFee varchar(20) 

 ```

 
```sql
UPDATE FifaData
SET Team = REPLACE(REPLACE(REPLACE(Team_Contract, SUBSTRING(Team_Contract, PATINDEX('%[~]%', Team_Contract) - 5, 5), ''), SUBSTRING(Team_Contract, PATINDEX('%[~]%', Team_Contract) + 1, 5), ''), '~', ''),
    StartYear = SUBSTRING(Team_Contract, PATINDEX('%[~]%', Team_Contract) - 5, 5),
    EndYear = SUBSTRING(Team_Contract, PATINDEX('%[~]%', Team_Contract) + 1, 5)
FROM FifaData
WHERE Team_Contract NOT LIKE '%Free%'
AND Team_Contract NOT LIKE '%Loan%'

```
 
 ### Column Data types
 After cleaning the columns that I had identified as dirty, then next step was to validate the data types of each of the columns. Most of the columns contain numerical data and can easily be verified whether each column contains an Integer as expected. 
 In SQL **ISNUMERIC** function returns 0 if a value is not an integer. Therefore, using this function for the columns that re numeric I could identify that the hits column contained values with a trailing **K** at the end of some values.  The below script was helpful in cleaning the column into an integer data type.

 Within the process of cleaning this column, I cam across an issue, where the values had a trailing **Line Feed** that could not allow me perform the multiplications. This was bit frastrauating as the **Line Feed** is not a normal space that can easily be removed by **TRIM, RTRIM or LTRIM** 
 *At some point I was doubting whether the TRIM function really works😅😅😅😅😅😅*

However, stackoverflow came in handy and I was able to figure out that  **CHAR(10)** is a **Line Feed** and replacing that with an empty space worked like charm!

 ````sql
UPDATE FifaData
SET Hits = CAST(REPLACE(REPLACE(Hits, 'K', ''), CHAR(10), '') AS decimal) * 1000
WHERE ISNUMERIC(Hits) = 0

-- clean line feed from all other columns 
UPDATE FifaData
SET Hits = CAST(REPLACE( Hits, CHAR(10), '') AS decimal) 
WHERE ISNUMERIC(Hits) = 1
 ````

Finaly, I ran the script for a few other columns removing the line feed from the columns

```sql
UPDATE FifaData
SET IR = CAST(REPLACE( IR, CHAR(10), '') AS INT) 
,PAC = CAST(REPLACE( PAC, CHAR(10), '') AS INT)
,SHO = CAST(REPLACE( SHO, CHAR(10), '') AS INT)
,PAS = CAST(REPLACE( PAS, CHAR(10), '') AS INT)
,DRI = CAST(REPLACE( DRI, CHAR(10), '') AS INT)
,DEF = CAST(REPLACE( DEF, CHAR(10), '') AS INT)
,PHY = CAST(REPLACE( PHY, CHAR(10), '') AS INT)

```

Lastly,  I converted the integer columns into INt by running the query below

````sql
ALTER TABLE FifaData ALTER COLUMN IR INT
ALTER TABLE FifaData ALTER COLUMN PAC INT
ALTER TABLE FifaData ALTER COLUMN SHO INT
ALTER TABLE FifaData ALTER COLUMN PAS INT
ALTER TABLE FifaData ALTER COLUMN DRI INT
ALTER TABLE FifaData ALTER COLUMN DEF INT
ALTER TABLE FifaData ALTER COLUMN PHY INT

ALTER TABLE FifaData ALTER COLUMN SM INT

....

````

 ### Identifying outliers

In SQL to identify outliers, you can use **ORDER BY** clause to check whether there are values that are much higher or lower than the expected values. Order by will also help identify varying data types in a single column. Having little knowledge on the columns of the dataset, I just performed outlier detection on Age, Weight and Height which are columns that I have a clear understanding of the expected value range.
For the rest of the columns nothing much I could do. 

This task is tideous with SQL as you would have to go through each column checking for outliers. I believe beyond SQL there are better tools that can easily perform outlier checks across all the dataset columns without having to specify which column. 

 ## Conclusion

Data cleaning is a vital process in data analysis as that helps transform data into a format that can be analyzed to draw meaningful insights from data. Its always important to ensure that there no duplicates in your data, columns values that have the different data types unless otherwise stated and there no outliers in your data set.
Cleaning this data was abit challenging for some columns but despite all that i sailed through using  SQL that provides a wide range of functions helpful in cleaning the data. 


