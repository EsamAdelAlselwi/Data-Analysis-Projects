

-- Create a new table with the same structure as the original table to avoid direct modification of the source.
create table housing_data2
like housing_data;


-- Copy all records from the original table to the new table to start the cleaning process.
insert housing_data2 (select * from housing_data);



-- Change the column data type to DATE to ensure the correctness of calculations and temporal sorting.
alter table housing_data2
modify column SaleDate date;


-- Convert existing values to standard date format.
UPDATE housing_data2
SET  SaleDate= CONVERT(SaleDate, DATE);



-- Review records missing property addresses for verification before processing.
select * from housing_data2
where PropertyAddress is null or PropertyAddress = ' '
order by ParcelID;


-- Standardize missing data representation by making empty spaces NULL.

update housing_data
set PropertyAddress = null
where PropertyAddress = ' ';

-- Self-join logic: Search for addresses for the same ParcelID in other records.
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, COALESCE(a.PropertyAddress, b.PropertyAddress)
FROM housing_data2 a
JOIN housing_data2 b
ON a.ParcelID = b.ParcelID
AND a.UniqueID != b.UniqueID
WHERE a.PropertyAddress IS NULL;

-- Use a temporary table to store retrieved addresses for updating the main table.
DROP TEMPORARY TABLE IF EXISTS UpdatePropertyAddress;
CREATE TEMPORARY TABLE UpdatePropertyAddress(
a_ParcelID VARCHAR(50), 
a_PropertyAddress VARCHAR(100), 
b_ParceID VARCHAR(50), 
b_Property_Address VARCHAR(100)
);

INSERT INTO UpdatePropertyAddress
(SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress
FROM housing_data2 a
JOIN housing_data2 b
ON a.ParcelID = b.ParcelID
AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL);


-- Update missing addresses based on data retrieved from the temporary table.
UPDATE housing_data2
INNER JOIN UpdatePropertyAddress
ON housing_data2.ParcelID = UpdatePropertyAddress.a_ParcelID
SET housing_data2.PropertyAddress = UpdatePropertyAddress.b_Property_Address;


-- Alternative and direct method to populate missing addresses using direct JOIN.
update housing_data2 t1
JOIN housing_data2 t2
ON t1.ParcelID = t2.ParcelID
AND t1.UniqueID != t2.UniqueID
set t1.PropertyAddress = t2.PropertyAddress
WHERE  t1.PropertyAddress IS NULL and t2.PropertyAddress is not null;


/* ===== Split Property Address into Separate Columns (Address, City) ===== */
-- Test the splitting process using text functions before applying permanent changes.
select PropertyAddress,substring(PropertyAddress,1,locate(',',PropertyAddress)-1) as addres
,substring(PropertyAddress,locate(',',PropertyAddress)+1,PropertyAddress) as city
from housing_data2;

-- Add new columns to store address and city separately for easier filtering.
alter table housing_data2
add column `Adderess` nvarchar(200) after PropertyAddress;

alter table housing_data2
add column `City` nvarchar(200) after Adderess;

-- Extract and distribute data to new columns based on comma location.
update housing_data2
set Adderess = substring(PropertyAddress,1,locate(',',PropertyAddress)-1),
 City = substring(PropertyAddress,locate(',',PropertyAddress)+1,PropertyAddress);



/* ===== Split Owner Address (Address, City, State) ===== */
-- Use SUBSTRING_INDEX to split the composite address into three parts.
select OwnerAddress,substring_index(OwnerAddress,',',1)as Address,
substring_index(substring_index(OwnerAddress,',',2),',',-1) as City,
substring_index(OwnerAddress,',',-1)as Stat
from housing_data2;

-- Create three new columns for owner data.
alter table housing_data2 
add column Owner_Address nvarchar(200),
add column Owner_City nvarchar(200),
add column Owner_State nvarchar(200);

-- Execute the update process to populate detailed owner data.
update housing_data2
set Owner_Address = substring_index(OwnerAddress,',',1),
Owner_City =substring_index(substring_index(OwnerAddress,',',2),',',-1),
Owner_State = substring_index(OwnerAddress,',',-1);

/* ===== Standardize 'SoldAsVacant' Field Values ===== */
-- Convert 'No' to 'N' to standardize data format and facilitate statistical analysis.
update housing_data2
set SoldAsVacant = 'N'
where SoldAsVacant = 'No';

-- Convert 'Yes' to 'Y' for the same standardization purpose.
update housing_data2
set SoldAsVacant = 'Y'
where SoldAsVacant = 'Yes';

-- Reorder new columns to be next to the original column (for organizational purposes).
alter table housing_data2
modify column Owner_Address nvarchar(200) after OwnerAddress ,
modify column Owner_City nvarchar(200) after Owner_Address,
modify column Owner_State nvarchar(200) after Owner_City;

/* ===== Identify and Remove Duplicate Records ===== */


DELETE from housing_data2
WHERE UniqueID NOT IN (
    SELECT UniqueID FROM (
        SELECT UniqueID,
        ROW_NUMBER() OVER (
            PARTITION BY ParcelID,
                        Adderess,
                        SalePrice,
                        SaleDate,
                        LegalReference
            ORDER BY UniqueID
        ) AS row_num
        FROM housing_data2
    ) subquery
    WHERE row_num = 1
);

/* ===== Block Explanation: Final Cleaning and Deletion of Unnecessary Columns ===== */
-- Delete original columns that have been split or are no longer needed to save space.
ALTER TABLE housing_data2
DROP COLUMN OwnerAddress, 
DROP COLUMN PropertyAddress,
DROP COLUMN row_num;



