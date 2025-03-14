/*
Filename:
07_B_measurement_profile.sql

Purpose:
Generate a profile of measurement prevalence in the final cohort

Description:
Measurement counts are calculated per patient and are aggregated by parent concepts
for each measurement concept present in the final OMOP Measurement table.

Dependencies:

*/

-- Create table which includes the measurement concepts included in the cohort and their names

DROP TABLE IF EXISTS #measurement_parent_concepts_of_interest;
SELECT
    CONCEPT_ANCESTOR.descendant_concept_id AS concept_id,
    CONCEPT_ANCESTOR.ancestor_concept_id,
    [Results].[REDISCOVER_concepts].concept_name
INTO #measurement_parent_concepts_of_interest
FROM [Results].[REDISCOVER_concepts]
INNER JOIN CONCEPT_ANCESTOR
    ON CONCEPT_ANCESTOR.ancestor_concept_id = [Results].[REDISCOVER_concepts].concept_id
WHERE
    [Results].[REDISCOVER_concepts].domain = 'Measurement'
    AND (
        [Results].[REDISCOVER_concepts].include_descendants = 'TRUE'
        OR CONCEPT_ANCESTOR.ancestor_concept_id = CONCEPT_ANCESTOR.descendant_concept_id
    )
ORDER BY [Results].[REDISCOVER_concepts].concept_name

--The measurement_count_temp table counts the number of times that each concept is present for each patient in the cohort.
--It is rolled up into ancestor concepts grouped as above
--If no records for the patient of that concept are present, a record of 0 will be present 
DROP TABLE IF EXISTS #measurement_count_temp;
SELECT
    p.person_id,
    mpci.ancestor_concept_id AS concept_id,
    mpci.concept_name,
    COUNT(CASE WHEN m.measurement_concept_id IS NOT NULL THEN 1 END) AS concept_count
INTO #measurement_count_temp
FROM
    #measurement_parent_concepts_of_interest AS mpci
CROSS JOIN
    [Results].[deident_REDISCOVER_person] AS p
LEFT JOIN
    [Results].[deident_REDISCOVER_measurement] AS m
    ON
        mpci.concept_id = m.measurement_concept_id
        AND m.person_id = p.person_id
GROUP BY
    p.person_id,
    mpci.ancestor_concept_id,
    mpci.concept_name

--This orders patients by how frequently the record occurs and does so for each individual concept
DROP TABLE IF EXISTS #measurment_concept_count_rank;
SELECT
    concept_name,
    concept_id,
    concept_count,
    ROW_NUMBER() OVER (PARTITION BY concept_id ORDER BY concept_count) AS rownumber
INTO #measurment_concept_count_rank
FROM #measurement_count_temp;

-- This summary table aims to show how many measurement records are present per patient. 
-- Because the clinical course for patients varies considerably, some patients have very few records; others have many.
-- The summary table has a row for each ancestor concept included in the measurement table
-- For each measurement, each patient in the cohort is ranked according to how many records of the measurement are present during the defined visit
-- The columns show how many measurement records are present per patient per measurement concept for the 25th percentile, median, 75th percentile, and 95th percentile of patients
WITH p25 AS (
    SELECT
        concept_id,
        concept_count AS percentile_25
    FROM #measurment_concept_count_rank
    WHERE rownumber = FLOOR(0.25 * (
        SELECT COUNT(person_id)
        FROM [Results].[deident_REDISCOVER_person]
    ))
),

p50 AS (
    SELECT
        concept_id,
        concept_count AS median
    FROM #measurment_concept_count_rank
    WHERE rownumber = FLOOR(0.50 * (
        SELECT COUNT(person_id)
        FROM [Results].[deident_REDISCOVER_person]
    ))
),

p75 AS (
    SELECT
        concept_id,
        concept_count AS percentile_75
    FROM #measurment_concept_count_rank
    WHERE rownumber = FLOOR(0.75 * (
        SELECT COUNT(person_id)
        FROM [Results].[deident_REDISCOVER_person]
    ))
),

p95 AS (
    SELECT
        concept_id,
        concept_count AS percentile_95
    FROM #measurment_concept_count_rank
    WHERE rownumber = FLOOR(0.95 * (
        SELECT COUNT(person_id)
        FROM [Results].[deident_REDISCOVER_person]
    ))
)

SELECT
    x1.concept_name,
    x1.concept_id,
    p25.percentile_25,
    p50.median,
    p75.percentile_75,
    p95.percentile_95,
    CASE
        WHEN p50.median = 0
            THEN
                'For half of patients, there were no records of this measurement. 5% of patients had '
                + CAST(p95.percentile_95 AS VARCHAR(10))
                + ' or more records.'
        ELSE
            'For half of patients, there were at least '
            + CAST(p50.median AS VARCHAR(10))
            + ' records. Most patients (25th-75th percentile) had '
            + CAST(p25.percentile_25 AS VARCHAR(10)) + '-'
            + CAST(p75.percentile_75 AS VARCHAR(10))
            + ' records. 5% of patients had '
            + CAST(p95.percentile_95 AS VARCHAR(10))
            + ' or more records.'
    END AS interpretation
FROM (
    SELECT DISTINCT
        ancestor_concept_id AS concept_id,
        concept_name
    FROM #measurement_parent_concepts_of_interest
) AS x1
FULL JOIN p25
    ON x1.concept_id = p25.concept_id
FULL JOIN p50
    ON x1.concept_id = p50.concept_id
FULL JOIN p75
    ON x1.concept_id = p75.concept_id
FULL JOIN p95
    ON x1.concept_id = p95.concept_id
ORDER BY p50.median DESC, p75.percentile_75 DESC, p95.percentile_95 DESC;
