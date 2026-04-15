-- =============================================================================
-- INSIGHT 1: BILLING ANOMALY DETECTION
-- Flags patients whose billing amount is more than 2 standard deviations
-- above the average for their medical condition and admission type.
-- Useful for identifying potential overbilling or high-complexity cases.
-- =============================================================================
WITH condition_stats AS (
    SELECT
        "Medical Condition",
        "Admission Type",
        AVG("Billing Amount")    AS avg_billing,
        STDDEV("Billing Amount") AS stddev_billing
    FROM healthcare_data
    GROUP BY "Medical Condition", "Admission Type"
)
SELECT
    h."Name",
    h."Age",
    h."Medical Condition",
    h."Admission Type",
    h."Insurance Provider",
    ROUND(h."Billing Amount"::NUMERIC, 2)           AS billing_amount,
    ROUND(cs.avg_billing::NUMERIC, 2)               AS condition_avg,
    ROUND(cs.stddev_billing::NUMERIC, 2)            AS condition_stddev,
    ROUND(
        ((h."Billing Amount" - cs.avg_billing) / NULLIF(cs.stddev_billing, 0))::NUMERIC, 2
    )                                               AS z_score,
    'BILLING ANOMALY'                               AS flag
FROM healthcare_data h
JOIN condition_stats cs
    ON h."Medical Condition" = cs."Medical Condition"
    AND h."Admission Type"   = cs."Admission Type"
WHERE
    (h."Billing Amount" - cs.avg_billing) / NULLIF(cs.stddev_billing, 0) > 2
ORDER BY z_score DESC;


-- =============================================================================
-- INSIGHT 2: PATIENT RISK SEGMENTATION (RFM-STYLE)
-- Segments patients into risk tiers based on:
--   - Age band (elder patients = higher risk)
--   - Length of stay (proxy for condition severity)
--   - Test result (Abnormal = high concern)
--   - Admission type (Emergency = most urgent)
-- Creates a composite risk score and assigns a tier label.
-- =============================================================================
WITH patient_scores AS (
    SELECT
        "Name",
        "Age",
        "Medical Condition",
        "Test Results",
        "Admission Type",
        "Insurance Provider",
        ROUND("Billing Amount"::NUMERIC, 2) AS billing_amount,
        ("Discharge Date" - "Date of Admission") AS length_of_stay,

        -- Age risk score (0-3)
        CASE
            WHEN "Age" >= 75 THEN 3
            WHEN "Age" >= 55 THEN 2
            WHEN "Age" >= 35 THEN 1
            ELSE 0
        END AS age_score,

        -- Length of stay risk score (0-3)
        CASE
            WHEN ("Discharge Date" - "Date of Admission") > 25 THEN 3
            WHEN ("Discharge Date" - "Date of Admission") > 15 THEN 2
            WHEN ("Discharge Date" - "Date of Admission") > 7  THEN 1
            ELSE 0
        END AS los_score,

        -- Test result risk score (0-2)
        CASE
            WHEN "Test Results" = 'Abnormal'   THEN 2
            WHEN "Test Results" = 'Inconclusive' THEN 1
            ELSE 0
        END AS test_score,

        -- Admission type risk score (0-2)
        CASE
            WHEN "Admission Type" = 'Emergency' THEN 2
            WHEN "Admission Type" = 'Urgent'    THEN 1
            ELSE 0
        END AS admission_score

    FROM healthcare_data
),
scored AS (
    SELECT
        *,
        (age_score + los_score + test_score + admission_score) AS total_risk_score
    FROM patient_scores
)
SELECT
    "Name",
    "Age",
    "Medical Condition",
    "Admission Type",
    "Test Results",
    length_of_stay,
    billing_amount,
    total_risk_score,
    CASE
        WHEN total_risk_score >= 8  THEN 'CRITICAL'
        WHEN total_risk_score >= 5  THEN 'HIGH RISK'
        WHEN total_risk_score >= 3  THEN 'MODERATE'
        ELSE 'LOW RISK'
    END AS risk_tier
FROM scored
ORDER BY total_risk_score DESC, billing_amount DESC;


-- =============================================================================
-- INSIGHT 3: DOCTOR PERFORMANCE SCORECARD
-- Ranks doctors by volume, average billing, patient outcomes (test results),
-- and average length of stay. Highlights potential efficiency outliers.
-- =============================================================================
SELECT
    "Doctor",
    COUNT(*)                                                    AS total_patients,
    ROUND(AVG("Billing Amount")::NUMERIC, 2)                   AS avg_billing_per_patient,
    ROUND(SUM("Billing Amount")::NUMERIC, 2)                   AS total_revenue_generated,
    ROUND(AVG("Discharge Date" - "Date of Admission")::NUMERIC, 1) AS avg_length_of_stay_days,
    COUNT(*) FILTER (WHERE "Test Results" = 'Normal')           AS normal_results,
    COUNT(*) FILTER (WHERE "Test Results" = 'Abnormal')         AS abnormal_results,
    COUNT(*) FILTER (WHERE "Test Results" = 'Inconclusive')     AS inconclusive_results,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE "Test Results" = 'Abnormal') / COUNT(*), 1
    )                                                           AS abnormal_rate_pct,
    COUNT(*) FILTER (WHERE "Admission Type" = 'Emergency')      AS emergency_cases,
    RANK() OVER (ORDER BY COUNT(*) DESC)                        AS volume_rank,
    RANK() OVER (ORDER BY AVG("Billing Amount") DESC)           AS billing_rank
FROM healthcare_data
GROUP BY "Doctor"
ORDER BY total_patients DESC;


-- =============================================================================
-- INSIGHT 4: INSURANCE PROVIDER PROFITABILITY & COVERAGE ANALYSIS
-- Breaks down each insurer's patient mix by condition, admission type,
-- and avg billing — useful for understanding payer distribution.
-- =============================================================================
SELECT
    "Insurance Provider",
    "Medical Condition",
    COUNT(*)                                        AS patient_count,
    ROUND(AVG("Billing Amount")::NUMERIC, 2)        AS avg_billing,
    ROUND(MIN("Billing Amount")::NUMERIC, 2)        AS min_billing,
    ROUND(MAX("Billing Amount")::NUMERIC, 2)        AS max_billing,
    ROUND(SUM("Billing Amount")::NUMERIC, 2)        AS total_billed,
    COUNT(*) FILTER (WHERE "Admission Type" = 'Emergency')  AS emergency_count,
    COUNT(*) FILTER (WHERE "Admission Type" = 'Elective')   AS elective_count,
    COUNT(*) FILTER (WHERE "Admission Type" = 'Urgent')     AS urgent_count
FROM healthcare_data
GROUP BY "Insurance Provider", "Medical Condition"
ORDER BY "Insurance Provider", total_billed DESC;


-- =============================================================================
-- INSIGHT 5: MONTH-OVER-MONTH ADMISSION TREND & SEASONAL PATTERNS
-- Tracks monthly admission volume and billing totals across years.
-- Identifies seasonal spikes (e.g. winter respiratory conditions).
-- =============================================================================
SELECT
    EXTRACT(YEAR  FROM "Date of Admission")::INT    AS admission_year,
    EXTRACT(MONTH FROM "Date of Admission")::INT    AS admission_month,
    TO_CHAR("Date of Admission", 'Mon')             AS month_name,
    COUNT(*)                                        AS total_admissions,
    ROUND(SUM("Billing Amount")::NUMERIC, 2)        AS total_billing,
    ROUND(AVG("Billing Amount")::NUMERIC, 2)        AS avg_billing,
    COUNT(*) FILTER (WHERE "Admission Type" = 'Emergency') AS emergency_admissions,
    -- Month-over-month growth in admissions (using LAG window function)
    LAG(COUNT(*)) OVER (
        ORDER BY
            EXTRACT(YEAR FROM "Date of Admission"),
            EXTRACT(MONTH FROM "Date of Admission")
    )                                               AS prev_month_admissions,
    ROUND(
        100.0 * (COUNT(*) - LAG(COUNT(*)) OVER (
            ORDER BY
                EXTRACT(YEAR FROM "Date of Admission"),
                EXTRACT(MONTH FROM "Date of Admission")
        )) / NULLIF(LAG(COUNT(*)) OVER (
            ORDER BY
                EXTRACT(YEAR FROM "Date of Admission"),
                EXTRACT(MONTH FROM "Date of Admission")
        ), 0), 1
    )                                               AS mom_growth_pct
FROM healthcare_data
GROUP BY
    EXTRACT(YEAR FROM "Date of Admission"),
    EXTRACT(MONTH FROM "Date of Admission"),
    TO_CHAR("Date of Admission", 'Mon')
ORDER BY admission_year, admission_month;


-- =============================================================================
-- INSIGHT 6: MEDICAL CONDITION COMORBIDITY PROXY
-- Identifies patients admitted multiple times and groups by conditions seen,
-- acting as a proxy for comorbidity patterns across re-admissions.
-- =============================================================================
WITH patient_history AS (
    SELECT
        "Name",
        COUNT(*)                                            AS total_admissions,
        STRING_AGG(DISTINCT "Medical Condition", ', '
            ORDER BY "Medical Condition")                   AS conditions_seen,
        STRING_AGG(DISTINCT "Medication", ', '
            ORDER BY "Medication")                          AS medications_prescribed,
        MIN("Date of Admission")                            AS first_admission,
        MAX("Date of Admission")                            AS last_admission,
        MAX("Date of Admission") - MIN("Date of Admission") AS days_as_patient,
        ROUND(SUM("Billing Amount")::NUMERIC, 2)           AS lifetime_billing
    FROM healthcare_data
    GROUP BY "Name"
    HAVING COUNT(*) > 1
)
SELECT
    "Name",
    total_admissions,
    conditions_seen,
    medications_prescribed,
    first_admission,
    last_admission,
    days_as_patient,
    lifetime_billing,
    ROUND(lifetime_billing / total_admissions, 2)  AS avg_billing_per_visit
FROM patient_history
ORDER BY total_admissions DESC, lifetime_billing DESC;


-- =============================================================================
-- INSIGHT 7: HOSPITAL EFFICIENCY BENCHMARKING
-- Compares hospitals on length of stay, billing efficiency (billing per day),
-- and outcome quality (abnormal test rate). Uses NTILE to rank hospitals
-- into performance quartiles.
-- =============================================================================
WITH hospital_metrics AS (
    SELECT
        "Hospital",
        COUNT(*)                                                    AS total_patients,
        ROUND(AVG("Discharge Date" - "Date of Admission")::NUMERIC, 2)
                                                                    AS avg_los_days,
        ROUND(AVG("Billing Amount")::NUMERIC, 2)                   AS avg_billing,
        ROUND(
            AVG("Billing Amount") /
            NULLIF(AVG("Discharge Date" - "Date of Admission"), 0)
        , 2)                                                        AS billing_per_day,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE "Test Results" = 'Abnormal')
            / COUNT(*), 1
        )                                                           AS abnormal_rate_pct,
        COUNT(DISTINCT "Doctor")                                    AS num_doctors
    FROM healthcare_data
    GROUP BY "Hospital"
)
SELECT
    "Hospital",
    total_patients,
    avg_los_days,
    avg_billing,
    billing_per_day,
    abnormal_rate_pct,
    num_doctors,
    NTILE(4) OVER (ORDER BY avg_los_days ASC)           AS los_efficiency_quartile,  -- 1 = most efficient
    NTILE(4) OVER (ORDER BY abnormal_rate_pct ASC)      AS outcome_quality_quartile  -- 1 = best outcomes
FROM hospital_metrics
ORDER BY total_patients DESC;


-- =============================================================================
-- INSIGHT 8: MEDICATION EFFECTIVENESS PROXY BY TEST OUTCOME
-- Examines which medications are associated with better test outcomes
-- (Normal vs Abnormal) across conditions. Useful for surface-level
-- treatment pattern analysis.
-- =============================================================================
SELECT
    "Medication",
    "Medical Condition",
    COUNT(*)                                                    AS total_prescriptions,
    COUNT(*) FILTER (WHERE "Test Results" = 'Normal')           AS normal_outcomes,
    COUNT(*) FILTER (WHERE "Test Results" = 'Abnormal')         AS abnormal_outcomes,
    COUNT(*) FILTER (WHERE "Test Results" = 'Inconclusive')     AS inconclusive_outcomes,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE "Test Results" = 'Normal')
        / COUNT(*), 1
    )                                                           AS normal_rate_pct,
    ROUND(AVG("Billing Amount")::NUMERIC, 2)                    AS avg_billing,
    ROUND(AVG("Discharge Date" - "Date of Admission")::NUMERIC, 1) AS avg_los_days
FROM healthcare_data
GROUP BY "Medication", "Medical Condition"
ORDER BY "Medical Condition", normal_rate_pct DESC;


-- =============================================================================
-- INSIGHT 9: AGE-GENDER HEALTH MATRIX
-- Cross-tabulates age bands with gender to reveal demographic health patterns:
-- which conditions are most prevalent, avg billing, and test abnormality rates.
-- =============================================================================
SELECT
    CASE
        WHEN "Age" BETWEEN 0  AND 17 THEN '0-17 (Pediatric)'
        WHEN "Age" BETWEEN 18 AND 34 THEN '18-34 (Young Adult)'
        WHEN "Age" BETWEEN 35 AND 54 THEN '35-54 (Middle Aged)'
        WHEN "Age" BETWEEN 55 AND 74 THEN '55-74 (Senior)'
        ELSE '75+ (Elderly)'
    END                                                         AS age_band,
    "Gender",
    "Medical Condition",
    COUNT(*)                                                    AS patient_count,
    ROUND(AVG("Billing Amount")::NUMERIC, 2)                   AS avg_billing,
    ROUND(AVG("Discharge Date" - "Date of Admission")::NUMERIC, 1) AS avg_los_days,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE "Test Results" = 'Abnormal')
        / COUNT(*), 1
    )                                                           AS abnormal_rate_pct,
    -- What proportion of this demographic's total admissions does this condition represent?
    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (
            PARTITION BY
                CASE
                    WHEN "Age" BETWEEN 0  AND 17 THEN '0-17'
                    WHEN "Age" BETWEEN 18 AND 34 THEN '18-34'
                    WHEN "Age" BETWEEN 35 AND 54 THEN '35-54'
                    WHEN "Age" BETWEEN 55 AND 74 THEN '55-74'
                    ELSE '75+'
                END,
                "Gender"
        ), 1
    )                                                           AS pct_of_demographic
FROM healthcare_data
GROUP BY age_band, "Gender", "Medical Condition",
    CASE
        WHEN "Age" BETWEEN 0  AND 17 THEN '0-17'
        WHEN "Age" BETWEEN 18 AND 34 THEN '18-34'
        WHEN "Age" BETWEEN 35 AND 54 THEN '35-54'
        WHEN "Age" BETWEEN 55 AND 74 THEN '55-74'
        ELSE '75+'
    END
ORDER BY age_band, "Gender", patient_count DESC;


-- =============================================================================
-- INSIGHT 10: BLOOD TYPE & CONDITION RISK CORRELATION
-- Explores whether certain blood types are disproportionately associated
-- with specific conditions or worse test outcomes (educational analysis).
-- Uses a chi-square-style proportion comparison.
-- =============================================================================
WITH overall_condition_rate AS (
    SELECT
        "Medical Condition",
        COUNT(*) AS total_condition_patients
    FROM healthcare_data
    GROUP BY "Medical Condition"
),
blood_condition AS (
    SELECT
        h."Blood Type",
        h."Medical Condition",
        COUNT(*)                                    AS observed_count,
        ROUND(
            100.0 * COUNT(*) /
            SUM(COUNT(*)) OVER (PARTITION BY h."Blood Type"), 1
        )                                           AS pct_within_blood_type,
        ROUND(AVG(h."Billing Amount")::NUMERIC, 2) AS avg_billing,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE h."Test Results" = 'Abnormal')
            / COUNT(*), 1
        )                                           AS abnormal_rate_pct
    FROM healthcare_data h
    GROUP BY h."Blood Type", h."Medical Condition"
)
SELECT
    bc."Blood Type",
    bc."Medical Condition",
    bc.observed_count,
    bc.pct_within_blood_type,
    bc.avg_billing,
    bc.abnormal_rate_pct,
    -- Flag blood types with unusually high condition concentration
    CASE
        WHEN bc.pct_within_blood_type > 20 THEN 'HIGH CONCENTRATION'
        WHEN bc.pct_within_blood_type > 15 THEN 'MODERATE'
        ELSE 'NORMAL'
    END AS concentration_flag
FROM blood_condition bc
ORDER BY bc."Blood Type", bc.pct_within_blood_type DESC;
