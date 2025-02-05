# REDISCOVER ICU Registry

REDISCOVER-ICU (Repurposing Drugs in Intensive Care Units through Real-world Data Analysis) is a clinical registry leveraging OMOP and EHR automation. 

The Society of Critical Care Medicine (SCCM) Discovery and the Critical Path Institute (C-Path) share a common goal of promoting wide availability of high-quality data for observational research in diseases and conditions of high unmet clinical need. Together with clinical and academic collaborators, SCCM and C-Path seek to establish a disease agnostic repository for real-world data for drug repurposing research in critical care. While targeting minimal data enrichment, C-Path and SCCM will collaborate with five institutions to embed and optimize extract, transform, and load (ETL) processes for quarterly refreshes of critical care data. Specific data targets would include RNA/DNA probes, medication administration record (MAR) dose, and oxygenation devices for sepsis, acute kidney injury (AKI), Acute respiratory distress syndrome (ARDS), COVID-19, and meningitis. Project would refine methods for dose extraction and develop open source code and guidelines to share through SCCM and OHDSI. By fostering collaboration and establishing a data repository, this initiative aims to fortify the foundational data infrastructure vital for advancing translational science, facilitating the exploration of real-world data (RWD), and harnessing real-world evidence (RWE) for innovative solutions in critical care.

This Github repository is the REDISCOVER-ICU documentation for participating sites. It is meant to be the central authority of the definition of the registry, e.g. what concepts to include, how to generate the cohort, who is included, etc.

The Cohort is comprised of the anonymized person_id, birthdate, and visit_start_date for hospitalizations with associated sepsis (concept_id 132797) or central line infection diagnoses (concept_id 43021283) from the OMOP CDM. Multiple hospitalizations can be captured for each unique patient. 

--------------------------------------------------------------------------------------------------

## Explanation of the Curation Script Files: 

**00 - Create Concept Table**
- Creates "rediscover_concepts" for all values captured by REDISCOVER-ICU
- Additional concepts can be requested by contacting @SmittyHeavner

**01 - Create Cohort** (this section has not yet been updated from CURE ID)
- Identifies all patients with a positive lab result measurement, patient_id and first positive lab result
- Identifies all patients with a "strong" or "weak" COVID diagnosis based on condition codes
- Combines the "strong" and "weak" results into a "comb" table
- Creates an intermediary table "inpat_intermed" for all patients with a positive lab result, who were flagged as inpatient treatment
- Joins the positive lab result, "inpat_intermed" and "comb" tables to get the criteria of the Cohort (sans edge cases)

In summary, the Cohort contains patients who were hospitalized with COVID, and experienced symptoms that suggest COVID played a significant role in their hospitalization. These patients tested positive for COVID, started in-patient care 7 days before through 21 days after a positive test, and experienced COVID-symptoms around 2 weeks before or after their in-patient period. If the patient was hospitalized more than once, we prioritize the earliest occurrence. 

**02 - Load All Tables**
- From the Cohort created in 01, create tables for Person, Measurement, Drug Exposure, Death, Observation, Procedure, Condition, Visit Occurrence and Device Exposure
- This is limited to a hardcoded list of measurements that is relevant to the topic of COVID inpatient stay. Any measurements not on the list are not exposed. 

**03 - Replace Rare Conditions**
- Uses the Conditions table from 02.
- Find and replace conditions occurring 10 or less times with parent concepts that have at least 10 counts

**04 - Create Deidentification CDM Tables**
- Defines the DDL for generating the empty OMOP CDM tables to hold your deidentified data.
- The tables are blank and will be loaded with data in 04.

**05 - Perform Deidentification**
- Table by table, loads the data from 02 script, parses and deidentifies it.
- The results are inserted into the OMOP CDM tables from 03.

**06 - Perform Quality Checks**
- Read the count, min, and max for various columns and tables.
- Comments say what results are expected, if the script succeeded (more documentation is needed here)

**07 - Utilize Profile Scripts**
- Five different scripts to create different profiles from the Cohort created in previous steps.
- Condition, Measurement, Drug Exposure, Unmapped Drugs, Device


