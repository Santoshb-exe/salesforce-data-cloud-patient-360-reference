-- ============================================================================
-- CALCULATED INSIGHTS — Salesforce Data Cloud
-- ============================================================================
-- These are written as ANSI SQL for the Data Cloud Calculated Insights editor.
-- DMO names use the placeholder format: ssot__<EntityName>__dlm
-- Adjust to match your actual DMO API names after mapping in your org.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- INSIGHT 1: Provider Load Balancing Score
-- ----------------------------------------------------------------------------
-- Purpose: Rank providers by a composite score so segmentation can route
--          patients to providers who are high-quality AND have capacity.
--
-- Inputs:  Provider performance DMO (RVU, utilization, satisfaction, no-show)
-- Output:  One row per provider per month with composite score
-- ----------------------------------------------------------------------------
SELECT
    pp.provider_id__c AS provider_id,
    pp.measurement_month__c AS measurement_month,
    pp.rvu_score__c AS rvu_score,
    pp.capacity_utilization_pct__c AS capacity_utilization_pct,
    pp.open_appointment_slots__c AS open_slots,

    -- Composite score: weighted blend.
    -- Higher = better candidate to receive more outreach-driven appointments.
    (
        (pp.rvu_score__c * 0.35)
        + ((100 - pp.capacity_utilization_pct__c) * 0.25)
        + (pp.open_appointment_slots__c * 0.20)
        + (pp.patient_satisfaction_score__c * 0.15)
        - (pp.no_show_rate__c * 100 * 0.05)
    ) AS provider_load_score

FROM
    ssot__ProviderPerformance__dlm pp
WHERE
    pp.measurement_month__c >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '90' DAY)
;


-- ----------------------------------------------------------------------------
-- INSIGHT 2: Patient Engagement Score
-- ----------------------------------------------------------------------------
-- Purpose: Predict outreach responsiveness so segmentation can prioritize
--          patients who are likely to open/click/convert.
--
-- Inputs:  Engagement events DMO (sent/open/click/convert), 180-day window
-- Output:  One row per unified individual with score 0-100
-- ----------------------------------------------------------------------------
SELECT
    ee.unified_individual_id__c AS unified_individual_id,

    -- Recency component (0-40): more recent engagement = higher
    CASE
        WHEN MAX(ee.event_timestamp__c) >= CURRENT_DATE - INTERVAL '30' DAY  THEN 40
        WHEN MAX(ee.event_timestamp__c) >= CURRENT_DATE - INTERVAL '60' DAY  THEN 30
        WHEN MAX(ee.event_timestamp__c) >= CURRENT_DATE - INTERVAL '90' DAY  THEN 20
        WHEN MAX(ee.event_timestamp__c) >= CURRENT_DATE - INTERVAL '180' DAY THEN 10
        ELSE 0
    END
    -- Open ratio (0-25)
    + LEAST(25, COUNT_IF(ee.opened_flag__c = TRUE) * 5)
    -- Click ratio (0-25)
    + LEAST(25, COUNT_IF(ee.clicked_flag__c = TRUE) * 8)
    -- Conversion bonus (0-10)
    + LEAST(10, COUNT_IF(ee.converted_flag__c = TRUE) * 10)
    AS patient_engagement_score,

    MAX(ee.event_timestamp__c) AS last_engagement_at,
    COUNT(*) AS total_events_180d

FROM
    ssot__EngagementEvent__dlm ee
WHERE
    ee.event_timestamp__c >= CURRENT_DATE - INTERVAL '180' DAY
GROUP BY
    ee.unified_individual_id__c
;


-- ----------------------------------------------------------------------------
-- INSIGHT 3: Segment Health Metric
-- ----------------------------------------------------------------------------
-- Purpose: Track segment population over time so business owners get
--          observability into whether outreach pipelines are growing/shrinking.
--
-- Inputs:  Unified Individual, Clinical Reference, Consent
-- Output:  One row per clinical_category per day with eligible patient count
-- ----------------------------------------------------------------------------
SELECT
    cr.friendly_category__c AS clinical_category,
    CURRENT_DATE AS measurement_date,

    COUNT(DISTINCT ui.unified_individual_id__c)
        AS total_patients_in_category,

    COUNT(DISTINCT CASE WHEN cs.email_opt_in__c = TRUE
                        THEN ui.unified_individual_id__c END)
        AS eligible_for_email_outreach,

    COUNT(DISTINCT CASE WHEN cs.sms_opt_in__c = TRUE
                        THEN ui.unified_individual_id__c END)
        AS eligible_for_sms_outreach,

    -- Patients with a recent encounter in this category
    COUNT(DISTINCT CASE
        WHEN enc.encounter_date__c >= CURRENT_DATE - INTERVAL '90' DAY
        THEN ui.unified_individual_id__c END)
        AS active_in_90d

FROM
    ssot__UnifiedIndividual__dlm ui
    JOIN ssot__Encounter__dlm enc
        ON enc.unified_individual_id__c = ui.unified_individual_id__c
    JOIN ssot__ClinicalReference__dlm cr
        ON cr.raw_code__c = enc.diagnosis_code__c
    LEFT JOIN ssot__Consent__dlm cs
        ON cs.unified_individual_id__c = ui.unified_individual_id__c
GROUP BY
    cr.friendly_category__c
;


-- ============================================================================
-- BONUS: PEDIATRIC GUARANTOR ROUTING TRANSFORMATION
-- ============================================================================
-- This is conceptually a transformation/streaming insight, not a CI per se.
-- Apply during ingestion or as a derived attribute on Unified Individual.
--
-- Logic: If patient is under 18, the outreach_email is the guardian email;
--        otherwise it's the patient's own.
-- ============================================================================
SELECT
    ui.unified_individual_id__c,
    DATEDIFF('year', ui.date_of_birth__c, CURRENT_DATE) AS age,

    CASE
        WHEN DATEDIFF('year', ui.date_of_birth__c, CURRENT_DATE) < 18
             AND ui.guardian_email__c IS NOT NULL
            THEN ui.guardian_email__c
        ELSE ui.email__c
    END AS outreach_email,

    CASE
        WHEN DATEDIFF('year', ui.date_of_birth__c, CURRENT_DATE) < 18
            THEN TRUE ELSE FALSE
    END AS is_pediatric_routing

FROM
    ssot__UnifiedIndividual__dlm ui
;
