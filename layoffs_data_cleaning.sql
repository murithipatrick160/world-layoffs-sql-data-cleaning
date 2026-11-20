-- 1. Create a staging table to protect the raw data
CREATE TABLE layoffs_staging LIKE layoffs;

INSERT INTO layoffs_staging 
SELECT * FROM layoffs;

-- Check for exact duplicates across all columns
WITH duplicate_cte AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY company, location, industry, total_laid_off, 
                            percentage_laid_off, `date`, stage, country, funds_raised
           ) AS row_num
    FROM layoffs_staging
)
SELECT * 
FROM duplicate_cte 
WHERE row_num > 1;

-- Create a second staging table with a row_num column so we can delete duplicates
CREATE TABLE layoffs_staging2 (
  company TEXT,
  location TEXT,
  industry TEXT,
  total_laid_off INT DEFAULT NULL,
  percentage_laid_off TEXT,
  `date` TEXT,
  stage TEXT,
  country TEXT,
  funds_raised INT DEFAULT NULL,
  row_num INT
);

INSERT INTO layoffs_staging2
SELECT *,
       ROW_NUMBER() OVER(
           PARTITION BY company, location, industry, total_laid_off, 
                        percentage_laid_off, `date`, stage, country, funds_raised
       ) AS row_num
FROM layoffs_staging;

-- Remove the 5 duplicate rows and drop the first staging table
SET SQL_SAFE_UPDATES = 0;

DELETE FROM layoffs_staging2 
WHERE row_num > 1;

DROP TABLE IF EXISTS layoffs_staging;


-- 2. Standardize text, fix typos, and repair character encoding

-- Trim extra leading and trailing spaces
UPDATE layoffs_staging2
SET 
    company = TRIM(company),
    location = TRIM(location),
    industry = TRIM(industry),
    stage = TRIM(stage),
    country = TRIM(country);

-- Fix broken UTF-8 characters (such as Florianópolis)
UPDATE layoffs_staging2
SET 
    company = CONVERT(BINARY CONVERT(company USING latin1) USING utf8mb4),
    location = CONVERT(BINARY CONVERT(location USING latin1) USING utf8mb4),
    country = CONVERT(BINARY CONVERT(country USING latin1) USING utf8mb4)
WHERE 
    company LIKE '%Ã%' 
    OR location LIKE '%Ã%' 
    OR country LIKE '%Ã%';

-- Fix spelling typo in location
UPDATE layoffs_staging2
SET location = 'Fredericton'
WHERE location = 'Ferdericton';

-- Merge all Crypto variations into one consistent label
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Remove trailing period from United States
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';


-- 3. Convert the date column from text to DATE format

UPDATE layoffs_staging2
SET `date` = NULL
WHERE `date` = 'NULL' OR `date` = '';

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y')
WHERE `date` IS NOT NULL;

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;


-- 4. Populate missing industry values using a self-join

UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '' OR industry = 'NULL';

UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;


-- 5. Convert percentage column, remove unusable rows, and drop helper column

UPDATE layoffs_staging2
SET percentage_laid_off = NULL
WHERE percentage_laid_off = 'NULL' OR percentage_laid_off = '';

-- Delete rows missing both layoff metrics
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Drop the row_num column used for deduplication
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- Final review of the cleaned table
SELECT * FROM layoffs_staging2;

