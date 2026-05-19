# Weeks 1–4 — Build the Data Cloud Implementation

Each week ends with a commit, a journal entry, and a visible artifact.

---

## Week 1 — Synthetic Data + Ingestion Foundation

**Goal:** Generate realistic data and design ingestion. By end of week, you should have 1,930 patient records and a documented ingestion plan.

### Day 1-2 — Data generation
```bash
cd data-generator
pip install -r requirements.txt
python generate_all.py
```

Verify in `data/`:
- 3 brand patient CSVs (~640 records each)
- providers, encounters, engagement_events, clinical_reference, provider_performance, consent_preferences

**Sanity check** — confirm collisions and pediatric records exist:
```bash
python -c "
import csv
from collections import defaultdict
pids = defaultdict(list)
for b in ['medfirst','careplus','healthbridge']:
    for r in csv.DictReader(open(f'../data/{b}_patients.csv')):
        pids[r['source_patient_id']].append(b)
print('IDs colliding across brands:', sum(1 for v in pids.values() if len(v)>1))
"
# Should show ~50 collisions
```

### Day 3 — Clinical reference review
Open `data/clinical_reference.csv`. Confirm ICD-10 → friendly_category mapping is sensible. **Add 5 more rows** specific to your interests (e.g., behavioral health codes, oncology screening). This is where you customize.

### Day 4 — ID collision analysis writeup
Create `docs/weekly-build-journal/week-1-id-collision-analysis.md`:
- How many collisions in the data
- Why source_patient_id alone is unsafe
- The global key formula: `<BRAND>-<SOURCE_PATIENT_ID>`
- Where this transformation will live (preference: in Data Cloud ingestion via formula field; fallback: Python precompute or Apex transformation)

Commit ADR-002:
```markdown
# ADR-002: Global Source Key Strategy

## Decision
Concatenate `source_brand + '-' + source_patient_id` during ingestion to produce a globally unique key. Implement preferentially as a Data Cloud transformation; fall back to Python precompute if access is limited.
```

### Day 5 — Ingestion design
Create `docs/architecture/ingestion-design.md`:
- Native connectors (CRM, SFMC) — where applicable
- S3 / Cloud Storage Source connector — for batch CSVs
- Ingestion API — for near-real-time engagement events
- Data Stream schedule design (12-hour for engagement, daily for clinical)

### Day 6 — Data dictionary
Create `docs/architecture/data-dictionary.md` — one table per CSV with field, type, description, source, sensitivity.

### Day 7 — Journal + commit
Week 1 journal in `docs/weekly-build-journal/week-1.md`. Commit, push.

**Definition of done:** You can regenerate all data from code, explain every edge case, and articulate the global key strategy.

---

## Week 2 — DLO → DMO Modeling

**Goal:** Map raw source CSVs into a harmonized Patient 360 data model.

### Day 1 — Document target DLOs
In `docs/architecture/dlo-dmo-mapping.md`, list the DLOs you'll create (one per CSV):
- `Patient_Source__dlm`
- `Provider_Source__dlm`
- `Encounter_Source__dlm`
- `EngagementEvent_Source__dlm`
- `Consent_Source__dlm`
- `ClinicalReference_Source__dlm`
- `ProviderPerformance_Source__dlm`

### Day 2 — Standard DMO mapping
For patient data, map to:
- `Individual` — name, DOB, demographics
- `Contact Point Email` — email
- `Contact Point Phone` — phone
- `Contact Point Address` — address

### Day 3 — Engagement DMO
Map engagement events to the standard `Engagement` DMO. Field mapping table:

| Source field | DMO field | Transformation |
|---|---|---|
| event_id | EngagementId | passthrough |
| source_patient_id | IndividualId | global key applied |
| event_type | EngagementType | enum normalize |
| event_timestamp | EngagementDateTime | timezone-normalize to UTC |

### Day 4 — Custom DMOs
Design two custom DMOs:
1. `ClinicalReference__dlm` — abstracts ICD-10/CPT into friendly categories
2. `ProviderPerformance__dlm` — supports the load balancing CI

### Day 5 — Mapping spreadsheet
Build the full mapping in `docs/architecture/mapping-spreadsheet.md` (markdown table). Columns: Source File, Source Field, DLO Field, DMO Field, Transformation, Required, Notes.

### Day 6 — Build in Data Cloud (if access)
If Track A: actually create the DLOs and DMOs in Data Cloud. Screenshot every mapping screen. Capture metadata exports.
If Track B/C: document the design fully so anyone can reproduce it.

### Day 7 — Commit, ADR-003 (DLO/DMO mapping approach), journal entry.

**Definition of done:** You can explain DLO vs DMO without hand-waving and show your mapping table.

---

## Week 3 — Identity Resolution

**Goal:** Stitch fragmented patient identities across brands. Test that anti-match cases stay separate.

### Day 1 — Design document
Create `docs/architecture/identity-resolution-design.md` covering:
- 4 match rule groups (deterministic → fuzzy, see [identity-resolution/test-cases.md](../identity-resolution/test-cases.md))
- Reconciliation rules per field
- Confidence levels
- False positive / false negative risk analysis

### Day 2 — Deterministic match tests
Use the test cases TC-IR-001 through TC-IR-004 from `identity-resolution/test-cases.md`. Run each one (or document expected behavior if no DC access).

### Day 3 — Fuzzy match tests
TC-IR-002 (name typos). Document tuning decisions.

### Day 4 — Anti-match tests
**Critical:** TC-IR-005 (ID collision). Three different people with the same source ID across three brands MUST end up as THREE separate Unified Individuals. If they collapse into one, your global key strategy isn't being applied.

TC-IR-006 (twins), TC-IR-007 (family-shared email), TC-IR-008 (reused phone).

### Day 5 — Pediatric guarantor routing
Implement the age-based outreach routing. Preferred: Data Cloud streaming insight or transformation. Fallback: Apex / Python precompute.

Test TC-PR-001 through TC-PR-004.

### Day 6 — Run + screenshot (if access)
Capture the Identity Resolution ruleset, a Unified Individual showing multi-source stitch, and the reconciliation result.

### Day 7 — **First Medium post draft**
`medium-posts/post-2-identity-resolution-healthcare.md`. Title: *"Identity Resolution Patterns for Multi-Brand Healthcare Data."* Use your test cases as the structural backbone. ~1500 words.

Commit ADR-004 (identity rules) and ADR-005 (pediatric routing).

**Definition of done:** You can explain why identity resolution is not "just dedupe" and show the test cases passing (or documented expected results).

---

## Week 4 — Calculated Insights + Segments + Activation

**Goal:** Turn unified data into business actions.

### Day 1-3 — Build the three Calculated Insights
Use `sql/calculated_insights.sql` as your starting point. Adapt the DMO names to match what you created in Week 2.

1. **Provider Load Balancing Score** — Day 1
2. **Patient Engagement Score** — Day 2
3. **Segment Health Metric** — Day 3

Document each in `docs/architecture/calculated-insights.md`: purpose, inputs, formula, refresh schedule.

### Day 4 — Build segments
Create 5 segments in Segment Canvas (or document with full criteria):
1. **Pediatric Annual Wellness Due** — exercises guardian routing
2. **Diabetic Patients — Quarterly Outreach** — exercises clinical reference
3. **Under-Utilized Provider Promotion** — exercises load balancing CI
4. **High Engagement Re-Targeting** — exercises engagement CI
5. **Consent-Safe Outreach** — exercises consent filter

### Day 5 — Activation
**Preferred:** Configure SFMC as activation target. Publish one segment on 12-hour cadence.
**Fallback:** Build a webhook receiver locally (FastAPI on port 8000, ngrok tunnel), point a Data Action at it, prove the payload arrives.
**Tertiary fallback:** Document the activation payload schema and how the target would consume it.

### Day 6 — Custom CRM object for activation landing
Create custom object `Patient_Outreach_Recommendation__c` in your Salesforce org with fields per the plan. This is what activation writes to.

### Day 7 — **Second Medium post draft**
`medium-posts/post-1-data-cloud-patient-360.md`. Title: *"Building a Salesforce Data Cloud Patient 360 Reference Implementation."* This is the marquee post — make it strong.

Commit ADR-006 (CI design) and ADR-007 (segmentation/activation strategy).

**Definition of done:** You can show the chain raw data → CI → segment → activation target end to end.

---

## End of Month 1 Milestone

By end of Week 4, you should have:
- ~1,930 synthetic patients, 4,786 encounters, 15,085 engagement events
- DLO → DMO mapping documented (and built if access)
- Identity resolution rules + 12 test cases + pediatric routing
- 3 Calculated Insights with SQL
- 5 Segments
- 1 Activation target (real or mocked)
- 2 Medium post drafts
- 7 ADRs committed
- 4 weekly journal entries

**Schedule the Data Cloud Consultant cert exam for the start of Month 2.** The build IS the prep.
