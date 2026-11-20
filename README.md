I used MySQL to clean and standardize a global tech layoffs dataset so it is ready for exploratory analysis and dashboarding. The raw file contained duplicate entries, inconsistent category labels, text formatting issues, and missing values that needed to be resolved before running any aggregations.

What I Did

- Created Staging Tables: Copied the raw layoffs table into staging tables (layoffs_staging and layoffs_staging2) so the original data stayed untouched throughout the cleanup.
- Removed Exact Duplicates: Since the dataset had no unique ID column, I used a ROW_NUMBER() window function partitioned across all columns to identify and delete 5 duplicate company records.
- Standardized Text and Typos: Trimmed hidden spaces across text fields, fixed UTF-8 character encoding glitches in city names (such as Florianópolis), corrected a spelling typo in Fredericton, merged Crypto variations into a single label, and removed trailing periods from United States.
- Converted Data Types: Standardized text dates (MM/DD/YYYY) into proper DATE format and converted percentage_laid_off from text into a DECIMAL column so calculations work accurately.
- Populated Missing Industries: Used a self-join matching companies to their own records to fill in missing industry values for companies like Airbnb, Carvana, and Juul.
- Removed Unusable Rows: Deleted rows where both total_laid_off and percentage_laid_off were null, as those records lacked any layoff metrics for analysis, then dropped the row_num helper column.

Tools Used
- MySQL 8.0 / MySQL Workbench

Files Included
- layoffs.csv - The original raw dataset.
- layoffs_data_cleaning.sql - The full SQL script with comments for each step.
- layoffs_cleaned.csv - The final cleaned dataset ready for analysis.

