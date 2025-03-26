# OMOP Cohort Creation and Deidentification Guide

The following scripts are to be run on a site’s full OMOP dataset in order to prepare the relevant data for sharing with the Rediscover registry team. Each script should be run on the same server as the OMOP data but can be customized to run on the preferred Database and Schema.

## Instructions
Replace the database name and schema in each of these scripts with your own, then run the cohort creation and deidentification scripts in the following sequence:

0. Concept table (Filename: 00_REDISCOVER_create_concept_table.sql)
  
1. Cohort Creation (Filename: 01_REDISCOVER_SEPSIS_cohort.sql)

2. Generate REDISCOVER Tables (Filename: 02_REDISCOVER_All_Tables.sql)

3. Deidentify Rare Conditions (Filename: 03_REDISCOVER_replace_rare_conditions_with_parents.sql)

4. Generate OMOP Tables (Filename: 04_DE_ID_CDM_Table_ddl.sql)

5. Remove Identifiers (Filename: 05_DE_ID_script.sql)

6. Run Data Quality Checks (Filename: 06_DE_ID_Quality_Checks.sql)

7. Profile Scripts
   -  Profile Conditions (Filename: 07_A_condition_profile.sql)
   -  Profile Measurements (Filename: 07_B_measurement_profile.sql)
   -  Profile Drug Exposure (Filename: 07_C_drug_exposure_profile.sql)
   -  Profile Unmapped Drugs (Filename: 07_D_review_unmapped_drugs.sql)
   -  Profile Devices (Filename: 07_E_device_profile.sql)

## OMOP Cohort Creation and Deidentification Process

### 1. Cohort Creation Script

**Filename**: 01_REDISCOVER_SEPSIS_cohort.sql

**Purpose**: This script creates a cohort of patients for the Rediscover registry. The patient list is saved in the cohort table, along with other useful data elements.

**Description**: This SQL script creates a cohort of sepsis patients based on specific criteria. The script performs several steps to identify and filter the patients before finally creating the cohort table. The script sets the context to use a specific database, but the actual name of the database is meant to be provided by the user.

**Dependencies**: Concept Table (Step 0)

### 2. REDISCOVER Tables Script

**Filename**: 02_REDISCOVER_All_Tables.sql

**Purpose**: This script takes your OMOP dataset and generates a copy of key tables that have been filtered down to only include people and records related to the registry.

**Description**: Creates REDISCOVER_ID tables from the generated REDISCOVER_ID cohort.

**Dependencies**:
- 01_REDISCOVER_SEPSIS_cohort.sql

**Steps**:

1.  Load Person table
2.  Load Measurements table
3.  Load Drug Exposure table
4.  Load Death table
5.  Load Observation data
6.  Load Procedure Occurrence Table
7.  Load Condition Occurrence Table
8.  Load Visit Occurrence table
9.  Load Device Exposure table

### 3. Replace Rare Conditions Script

**Filename**: 03_REDISCOVER_replace_rare_conditions_with_parents.sql

**Purpose**: Replace conditions occurring 10 or less times in the dataset with parent concepts that have at least 10 counts

**Description**: This script is run after scripts 01 and 02

**Dependencies**:
- 01_REDISCOVER_SEPSIS_cohort.sql
- 02_REDISCOVER_All_Tables.sql

**Steps**:

1.  Create Condition roll up: concepts are mapped to their corresponding ancestor concept(s)
2.  Create table that counts the ancestor concepts for each original concept
3.  Create table that counts the original concepts
4.  Filter to only include conditions that have more than 10 counts
5.  Get just the most specific condition in the ancestor-descendent hierarchy

### 4. Deidentified Data DDL Script

**Filename**: 04_DE_ID_CDM_Table_ddl.sql 

**Purpose**: Generate the necessary tables for the de-identified version of the Rediscover Cohort

**Description**: This script will create tables in the Results schema and preface the table names with 'deident.' However, the preface can be set to whatever value you desire.

**Dependencies**: None

**Steps**:

1.  Create the Person table
2.  Create the Death table
3.  Create the Visit Occurrence table
4.  Create the Procedure Occurrence table
4.  Create the Drug Exposure table
5.  Create the Device Exposure table
6.  Create the Condition Occurrence table
7.  Create the Measurement table
8.  Create the Observation table

### 5. Deidentification Script

**Filename**: 05_DE_ID_script.sql

**Purpose**: This script creates a copy of the Cohort and removes identifying characteristics to prepare the data for sharing.

**Description**: Run this script to generate a deidentified copy of your target data. The following actions are performed:
- Reassignment of Person IDs: Person IDs are regenerated sequentially from a sorted copy of the Person table. These new Person IDs are carried throughout the CDM to all tables that reference it.

- Date Shifting: Each person is assigned a random date shift value between -186 and +186 days. All dates for that person are then shifted shifted by that amount.
     
- Birthdays: After date shifting a person’s birthday, the day is then set to the first of the new birth month. If the person would be \> 89 years old then they are assigned a random birth year that would make them 90-99 years old.

- Date Truncation: A user-defined Start and End date are used to exclude any date shifted data that falls outside of the target date range (e.g. procedures, conditions occurrences, etc.). Does not include Birthdates.

- Removal of Other Identifiers: Other potentially identifying datapoints are removed from the dataset such as location_id, provider_id, and care_site_id

**Dependencies**:
- 01_REDISCOVER_SEPSIS_cohort.sql
- 02_REDISCOVER_All_Tables.sql
- 03_REDISCOVER_replace_rare_conditions_with_parents.sql
- 04_DE_ID_CDM_Table_ddl.sql

**Steps**:

1.  Use find and replace to set source and target DB and Schema names
2.  Load the OMOP Person table, and de-identify
3.  Load the OMOP Visit Occurrence table, and de-identify
4.  Load the OMOP Condition Occurrence table, and de-identify
5.  Load the OMOP Procedure Occurrence table, and de-identify
6.  Load the OMOP Drug Exposure table, and de-identify
7.  Load the OMOP Observation table, and de-identify
8.  Load the OMOP Death table, and de-identify
9.  Load the OMOP Device Exposure table, and de-identify
10. Load the OMOP Measurement table, and de-identify

### 6. Quality Checks Script (optional)

**Filename**: 06_DE_ID_Quality_Checks.sql

**Purpose**: This script checks basic metrics for each table in the deidentified dataset to ensure the previous scripts were successful.

**Description**: This script runs a number of summary level quality checks for each table to audit basic data counts and date ranges.

**Dependencies**:
- 01_REDISCOVER_SEPSIS_cohort.sql
- 02_REDISCOVER_All_Tables.sql
- 03_REDISCOVER_replace_rare_conditions_with_parents.sql
- 04_DE_ID_CDM_Table_ddl.sql
- 05_DE_ID_script.sql

**Steps**:

1.  Count distinct person_ids and find the maximum and minimum birthdates in the OMOP Person table.
2.  Count distinct person_ids in the OMOP Death table.
3.  Count distinct person_ids, count number of records per observation_concept_id, and find the maximum and minimum observation dates for all records in the OMOP Observation table.
4.  Count distinct person_ids, count number of records per procedure_concept_id, and find the maximum and minimum procedure dates for all records in the OMOP Procedure Occurrence table.
5.  Count distinct person_ids, count number of records per condition_concept_id, and find the maximum and minimum condition dates for all records in the OMOP Condition Occurrence table.
6.  Count distinct person_ids, count number of records per measurement_concept_id, and find the maximum and minimum measurement dates for all records in the OMOP Measurement table.
7.  Count distinct person_ids, count number of records per device_concept_id, and find the maximum and minimum device exposure dates for all records in the OMOP Device Exposure table.
8.  Count distinct person_ids, count number of records per drug_concept_id, and find the maximum and minimum drug exposure dates for all records in the OMOP Drug Exposure table.

### 7. Cohort Profile Scripts

**Dependencies**: These scripts require the populated deidentified OMOP tables generated from the sequence of running scripts 1-5:

- 01_REDISCOVER_SEPSIS_cohort.sql
- 02_REDISCOVER_All_Tables.sql
- 03_REDISCOVER_replace_rare_conditions_with_parents.sql
- 04_DE_ID_CDM_Table_ddl.sql
- 05_DE_ID_script.sql

    ##### 07-A – Condition Profile

    **Filename**: 07_A_condition_profile.sql

    **Purpose**: Generate a profile of condition prevalence in the final cohort.

    **Description**: Condition counts are calculated per patient and are aggregated by parent concepts for each condition concept present in the final OMOP Condition Occurrence table.
    
    ##### 07-B – Measurement Profile

    **Filename**: 07_B_measurement_profile.sql

    **Purpose**: Generate a profile of measurement prevalence in the final cohort.

    **Description**: Measurement counts are calculated per patient and are aggregated by parent concepts for each measurement concept present in the final OMOP Measurement table.

    ##### 07-C – Drug Exposure Profile

    **Filename**: 07_C_drug_exposure_profile.sql

    **Purpose**: Generate a profile of drug prevalence in the final cohort.

    **Description**: Drug counts are calculated per patient and are aggregated by ingredient for each drug concept present in the final OMOP Drug Exposure table.

    ##### 07-D – Unmapped Drugs Profile

    **Filename**: 07_D_review_unmapped_drugs.sql

    **Purpose**: Generate a profile of drugs that are not mapped to drug_concept_ids in the final cohort.

    **Description**: This file filters drugs that were unsuccessfully mapped to a drug_concept_id when running the 02_REDISCOVER_All_Tables.sql script. Drug source values for which the drug_concept_id is “0” and have at least 20 instances in the final cohort are aggregated for manual review.
    \*\* Drug source values can contain PHI. Please review the output for PHI before sharing.

    ##### 07-E – Device Profile

    **Filename**: 07_E_device_profile.sql

    **Purpose**: Generate a profile of device prevalence in the final cohort.

    **Description**: Device counts are calculated per patient and are aggregated by parent concepts for each device concept present in the final OMOP Device Exposure table.
