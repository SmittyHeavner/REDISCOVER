/*
Filename:
05_DE_ID_script.sql

Purpose:
This script creates a copy of the Cohort and removes identifying characteristics
to prepare the data for sharing with the REDISCOVER-ICU registry.


Description:
Run this file to generate a deidentified copy of your target data. Insert your data
into the OMOP tables, and de-identify person_id, and date fields using date.shift.
If a person is 90 years of age or older, assign a random age between 90-99 years.

Dependencies:
01_REDISCOVER_Cohort.sql
02_REDISCOVER_All_Tables.sql
03_REDISCOVER_replace_rare_conditions_with_parents.sql
04_DE_ID_CDM_Table_ddl.sql
*/


/******* VARIABLES *******/
--SOURCE_SCHEMA: Results
--TARGET_SCHEMA: [Results]
DECLARE @START_DATE DATE = CAST('2016-01-01' AS DATE)
DECLARE @END_DATE DATE = CAST('2029-12-31' AS DATE)


/******* GENERATE MAP TABLES *******/

--Tables are dropped and created in a separate script.
--Please run that script first.

USE YOUR_DATABASE;


/******* GENERATE MAP TABLES *******/
INSERT INTO [Results].[source_id_person]
SELECT
    p.person_id AS sourceKey,
    ROW_NUMBER() OVER (ORDER BY p.gender_concept_id DESC, p.person_id DESC) AS id,
    (FLOOR(RAND(CAST(NEWID() AS VARBINARY)) * 367)) - 183 AS date_shift,
    CAST((DATEPART(YEAR, GETDATE()) - 90 - (FLOOR(RAND(CAST(NEWID() AS VARBINARY)) * 10))) AS INT) AS over_89_birth_year --If a person is > 89, then assign them a random age between 90 - 99
FROM [Results].[REDISCOVER_Person] AS p;

INSERT INTO [Results].[source_id_visit]
SELECT
    p.visit_occurrence_id AS sourceKey,
    ROW_NUMBER() OVER (ORDER BY p.visit_occurrence_id) AS new_id
FROM [Results].[REDISCOVER_Visit_Occurrence] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id
LEFT JOIN [Results].[source_id_visit] AS v ON v.sourceKey = p.visit_occurrence_id --Ask Ben about this self join?
WHERE v.new_id IS NULL AND (
    DATEADD(DAY, s.date_shift, p.visit_start_date) >= @START_DATE
    AND DATEADD(DAY, s.date_shift, p.visit_end_date) <= @END_DATE
) ORDER BY p.person_id, p.visit_start_date;

/******* PERSON *******/
INSERT INTO [Results].[deident_REDISCOVER_Person]
SELECT
    s.id AS person_id,
    p.gender_concept_id,
    CASE
        WHEN DATEDIFF(DAY, p.birth_datetime, GETDATE()) / 365.25 > 89 THEN s.over_89_birth_year
        ELSE DATEPART(YEAR, DATEADD(DAY, s.date_shift, p.birth_datetime))
    END AS year_of_birth,
    DATEPART(MONTH, DATEADD(DAY, s.date_shift, p.birth_datetime)) AS month_of_birth,
    1 AS day_of_birth,
    DATEFROMPARTS(
        CASE WHEN DATEDIFF(DAY, p.birth_datetime, GETDATE()) / 365.25 > 89 THEN s.over_89_birth_year ELSE DATEPART(YEAR, DATEADD(DAY, s.date_shift, p.birth_datetime)) END,
        DATEPART(MONTH, DATEADD(DAY, s.date_shift, p.birth_datetime)),
        1
    ) AS birth_datetime,
    p.race_concept_id,
    p.ethnicity_concept_id,
    1 AS location_id,
    1 AS provider_id,
    1 AS care_site_id,
    0 AS person_source_value,
    0 AS gender_source_value,
    0 AS gender_source_concept_id,
    0 AS race_source_value,
    0 AS race_source_concept_id,
    0 AS ethnicity_source_value,
    0 AS ethnicity_source_concept_id
FROM [Results].[REDISCOVER_Person] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id;

/******* VISIT *******/
INSERT INTO [Results].[deident_REDISCOVER_Visit_Occurrence]
SELECT
    v.new_id AS visit_occurrence_id,
    s.id AS person_id,
    p.visit_concept_id,
    DATEADD(DAY, s.date_shift, p.visit_start_date) AS visit_start_date,
    DATEADD(DAY, s.date_shift, p.visit_start_datetime) AS visit_start_datetime,
    DATEADD(DAY, s.date_shift, p.visit_end_date) AS visit_end_date,
    DATEADD(DAY, s.date_shift, p.visit_end_datetime) AS visit_end_datetime,
    p.visit_type_concept_id,
    1 AS provider_id,
    1 AS care_site_id,
    NULL AS visit_source_value,
    p.visit_source_concept_id,
    p.admitted_from_concept_id,
    NULL AS admitted_from_source_value,
    p.discharged_to_concept_id,
    NULL AS discharged_to_source_value,
    p.preceding_visit_occurrence_id
FROM [Results].[REDISCOVER_Visit_Occurrence] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id
LEFT JOIN [Results].[source_id_visit] AS v ON v.sourceKey = p.visit_occurrence_id
WHERE (DATEADD(DAY, s.date_shift, visit_start_date) >= @START_DATE AND DATEADD(DAY, s.date_shift, visit_end_date) <= @END_DATE);

/******* CONDITION OCCURENCE *******/
INSERT INTO [Results].[deident_REDISCOVER_Condition_Occurrence]
SELECT
    p.condition_occurrence_id,
    s.id AS person_id,
    p.condition_concept_id,
    DATEADD(DAY, s.date_shift, p.condition_start_date) AS condition_start_date,
    DATEADD(DAY, s.date_shift, p.condition_start_datetime) AS condition_start_datetime,
    DATEADD(DAY, s.date_shift, p.condition_end_date) AS condition_end_date,
    DATEADD(DAY, s.date_shift, p.condition_end_datetime) AS condition_end_datetime,
    p.condition_type_concept_id,
    p.stop_reason,
    1 AS provider_id,
    v.new_id AS visit_occurrence_id,
    p.visit_detail_id,
    p.condition_source_value,
    p.condition_source_concept_id,
    p.condition_status_source_value,
    p.condition_status_concept_id
FROM [Results].[REDISCOVER_Condition_Occurrence_Rare_Removed] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id
LEFT JOIN [Results].[source_id_visit] AS v ON v.sourceKey = p.visit_occurrence_id
WHERE (
    DATEADD(DAY, s.date_shift, condition_start_date) < @END_DATE
    AND DATEADD(DAY, s.date_shift, COALESCE(condition_end_date, condition_start_date)) > @START_DATE
);

/******* PROCEDURE OCCURENCE *******/
INSERT INTO [Results].[deident_REDISCOVER_Procedure_Occurrence]
SELECT
    p.procedure_occurrence_id,
    s.id AS person_id,
    p.procedure_concept_id,
    DATEADD(DAY, s.date_shift, p.procedure_date) AS procedure_date,
    DATEADD(DAY, s.date_shift, p.procedure_date) AS procedure_datetime,
    p.procedure_type_concept_id,
    p.modifier_concept_id,
    p.quantity,
    1 AS provider_id,
    v.new_id AS visit_occurrence_id,
    p.visit_detail_id,
    p.procedure_source_value,
    p.procedure_source_concept_id,
    p.modifier_source_value
FROM [Results].[REDISCOVER_Procedure_Occurrence] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id
LEFT JOIN [Results].[source_id_visit] AS v ON v.sourceKey = p.visit_occurrence_id
WHERE (
    DATEADD(DAY, s.date_shift, procedure_date) < @END_DATE
    AND DATEADD(DAY, s.date_shift, procedure_date) > @START_DATE
);

/******* DRUG EXPOSURE *******/
INSERT INTO [Results].[deident_REDISCOVER_Drug_Exposure]
SELECT
    p.drug_exposure_id,
    s.id AS person_id,
    p.drug_concept_id,
    DATEADD(DAY, s.date_shift, p.drug_exposure_start_date) AS drug_exposure_start_date,
    DATEADD(DAY, s.date_shift, p.drug_exposure_start_date) AS drug_exposure_start_datetime,
    DATEADD(DAY, s.date_shift, p.drug_exposure_end_date) AS drug_exposure_end_date,
    DATEADD(DAY, s.date_shift, p.drug_exposure_end_date) AS drug_exposure_end_datetime,
    DATEADD(DAY, s.date_shift, p.verbatim_end_date) AS verbatim_end_date,
    p.drug_type_concept_id,
    p.stop_reason,
    p.refills,
    p.quantity,
    p.days_supply,
    p.sig,
    p.route_concept_id,
    p.lot_number,
    1 AS provider_id,
    v.new_id AS visit_occurrence_id,
    p.visit_detail_id,
    p.drug_source_value,
    p.drug_source_concept_id,
    p.route_source_value,
    p.dose_unit_source_value
FROM [Results].[REDISCOVER_Drug_Exposure] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id
LEFT JOIN [Results].[source_id_visit] AS v ON v.sourceKey = p.visit_occurrence_id
WHERE (
    DATEADD(DAY, s.date_shift, drug_exposure_start_date) < @END_DATE
    AND DATEADD(DAY, s.date_shift, drug_exposure_end_date) > @START_DATE
);

/******* OBSERVATION *******/
INSERT INTO [Results].[deident_REDISCOVER_Observation]
SELECT
    p.observation_id,
    s.id AS person_id,
    p.observation_concept_id,
    DATEADD(DAY, s.date_shift, p.observation_date) AS observation_date,
    DATEADD(DAY, s.date_shift, p.observation_date) AS observation_datetime,
    p.observation_type_concept_id,
    p.value_as_number,
    p.value_as_string,
    p.value_as_concept_id,
    p.qualifier_concept_id,
    p.unit_concept_id,
    1 AS provider_id,
    v.new_id AS visit_occurrence_id,
    p.visit_detail_id,
    p.observation_source_value,
    p.observation_source_concept_id,
    p.unit_source_value,
    p.qualifier_source_value
FROM [Results].[REDISCOVER_Observation] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id
LEFT JOIN [Results].[source_id_visit] AS v ON v.sourceKey = p.visit_occurrence_id
WHERE (
    DATEADD(DAY, s.date_shift, observation_date) < @END_DATE
    AND DATEADD(DAY, s.date_shift, observation_date) > @START_DATE
);

/******* DEATH *******/
INSERT INTO [Results].[deident_REDISCOVER_Death]
SELECT
    s.id AS person_id,
    DATEADD(DAY, s.date_shift, p.death_date) AS death_date,
    DATEADD(DAY, s.date_shift, p.death_date) AS death_datetime,
    p.death_type_concept_id,
    p.cause_concept_id,
    p.cause_source_value,
    p.cause_source_concept_id
FROM [Results].[REDISCOVER_Death] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id;

/******* DEVICE EXPOSURE *******/
INSERT INTO [Results].[deident_REDISCOVER_Device_Exposure]
SELECT
    p.device_exposure_id,
    s.id AS person_id,
    p.device_concept_id,
    DATEADD(DAY, s.date_shift, p.device_exposure_start_date) AS device_exposure_start_date,
    DATEADD(DAY, s.date_shift, p.device_exposure_start_date) AS device_exposure_start_datetime,
    DATEADD(DAY, s.date_shift, p.device_exposure_end_date) AS device_exposure_end_date,
    DATEADD(DAY, s.date_shift, p.device_exposure_end_date) AS device_exposure_end_datetime,
    p.device_type_concept_id,
    p.unique_device_id,
    p.quantity,
    1 AS provider_id,
    v.new_id AS visit_occurrence_id,
    p.visit_detail_id,
    p.device_source_value,
    p.device_source_concept_id
FROM [Results].[REDISCOVER_Device_Exposure] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id
LEFT JOIN [Results].[source_id_visit] AS v ON v.sourceKey = p.visit_occurrence_id
WHERE (
    DATEADD(DAY, s.date_shift, device_exposure_start_date) < @END_DATE
    AND DATEADD(DAY, s.date_shift, COALESCE(device_exposure_end_date, device_exposure_start_date)) > @START_DATE
);

/******* MEASUREMENT *******/
INSERT INTO [Results].[deident_REDISCOVER_Measurement]
SELECT
    p.measurement_id,
    s.id AS person_id,
    p.measurement_concept_id,
    DATEADD(DAY, s.date_shift, p.measurement_date) AS measurement_date,
    DATEADD(DAY, s.date_shift, p.measurement_date) AS measurement_datetime,
    p.measurement_time,
    p.measurement_type_concept_id,
    p.operator_concept_id,
    p.value_as_number,
    p.value_as_concept_id,
    p.unit_concept_id,
    p.range_low,
    p.range_high,
    1 AS provider_id,
    v.new_id AS visit_occurrence_id,
    p.visit_detail_id,
    p.measurement_source_value,
    p.measurement_source_concept_id,
    p.unit_source_value,
    p.value_source_value
FROM [Results].[REDISCOVER_Measurement] AS p
INNER JOIN [Results].[source_id_person] AS s ON s.sourceKey = p.person_id
LEFT JOIN [Results].[source_id_visit] AS v ON v.sourceKey = p.visit_occurrence_id
WHERE (
    DATEADD(DAY, s.date_shift, measurement_date) < @END_DATE
    AND DATEADD(DAY, s.date_shift, measurement_date) > @START_DATE
);
