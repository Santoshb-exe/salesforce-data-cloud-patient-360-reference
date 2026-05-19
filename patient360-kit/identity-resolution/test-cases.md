# Identity Resolution Test Cases

These test cases pair with the synthetic data produced by `data-generator/generate_all.py`.
They validate that match rules behave correctly across deterministic, fuzzy, and anti-match scenarios.

## How to Use

After loading patient CSVs into Data Cloud and configuring Identity Resolution rulesets, run each scenario:

1. Query the Unified Individual for the patient(s) involved
2. Verify the `match_confidence` and `unified_individual_id` are as expected
3. Document the result in `weekly-build-journal/week-3-identity-resolution.md`

## Rule Order (apply in this priority)

| Priority | Rule | Match On |
|---|---|---|
| 1 | Deterministic High | `ssn_last4 + dob + last_name` |
| 2 | Email Strong | `email_lower + dob` |
| 3 | Phone Strong | `phone_e164 + dob + last_name` |
| 4 | Fuzzy Name + Address | `fuzzy(first_name) + fuzzy(last_name) + dob + postal_code` |

---

## Positive Match Scenarios (should be stitched into ONE Unified Individual)

### TC-IR-001: Exact match across three brands
**Setup:** A `cross_brand_duplicate` patient with identical SSN, DOB, name.
**Expected:** Single Unified Individual with `source_brands = [MEDFIRST, CAREPLUS, HEALTHBRIDGE]`, match_confidence ≥ 90.
**Query:** Find patients where last_name appears in all three brand files with same DOB and ssn_last4.

### TC-IR-002: Name typo (fuzzy)
**Setup:** Same person, last_name differs by one character (e.g., Smith vs Smyth) at different brands.
**Expected:** Stitched via Rule 4 (fuzzy). match_confidence in 70-85 range.
**Validation:** Both source records reference the same Unified Individual.

### TC-IR-003: Changed phone, same email
**Setup:** Same person across brands; phone differs, email stable.
**Expected:** Stitched via Rule 2 (email + DOB).

### TC-IR-004: Missing email but valid phone
**Setup:** Email present at one brand, missing at another; phone matches.
**Expected:** Stitched via Rule 3 (phone + DOB + last_name).

---

## Anti-Match Scenarios (should NOT be stitched)

### TC-IR-005: ID collision (different people, same source_patient_id)
**Setup:** Source patient ID 23507 exists in all three brands but refers to three different people (Michael Murphy / Shelley Ray / Sarah Lopez in the generated data).
**Expected:** THREE separate Unified Individuals. Source primary key must NOT be used as the match key. Global key strategy (`MEDFIRST-23507`, `CAREPLUS-23507`, etc.) prevents collision.
**Critical:** If this collapses into one Unified Individual, identity resolution is misconfigured.

### TC-IR-006: Twins (same DOB + same address, different first names)
**Setup:** Two records with same DOB, same address, same last_name, different first names.
**Expected:** TWO separate Unified Individuals.
**Risk:** Rule 4 (fuzzy first + last + dob + postal) could over-collapse. Test that first_name distance is enforced.

### TC-IR-007: Family-shared email
**Setup:** Multiple family members at same brand share an email address.
**Expected:** Separate Unified Individuals per person (different DOBs distinguish).
**Risk:** Rule 2 (email + DOB) protects because DOB differs.

### TC-IR-008: Phone reused across patients
**Setup:** Same phone number, different DOB, different name.
**Expected:** Separate Unified Individuals.

---

## Pediatric Guarantor Routing Tests

### TC-PR-001: Under-18 patient
**Setup:** Patient DOB 14 years ago, guardian_email populated.
**Expected:** `outreach_email = guardian_email` (NOT patient's email).
**Verify:** The Calculated Insight / transformation correctly applies the age check.

### TC-PR-002: 17-year-old (boundary case)
**Setup:** Patient DOB exactly 17 years 11 months ago.
**Expected:** `outreach_email = guardian_email`. Still under 18.

### TC-PR-003: Aging out
**Setup:** Modify a record so the patient just turned 18.
**Expected:** `outreach_email = patient_email`. Transformation must respect current_date dynamically.

### TC-PR-004: Adult with old guardian record
**Setup:** Adult patient whose record still has stale guardian fields populated.
**Expected:** `outreach_email = patient_email` (age check overrides guardian field presence).

---

## Reconciliation Rule Tests

After identity resolution stitches records, the Unified Individual fields must be reconciled across sources. Validate the following reconciliation outcomes:

| Field | Rule | Test |
|---|---|---|
| `last_name` | Most recently updated | Brand with latest `updated_at` wins |
| `dob` | Highest-trust source (define priority: MEDFIRST > HEALTHBRIDGE > CAREPLUS) | Verify priority order applies |
| `email` (adult) | Most recent verified | Latest non-null email wins |
| `email` (pediatric) | Guardian routing first, then latest | Guardian wins when age < 18 |
| `phone` | Most recent verified | Latest non-null phone wins |
| `consent` | Most restrictive | If any brand has opt-out, unified consent = opt-out |
| `clinical_categories` | Union (preserve all) | All categories from all brands appear |

---

## Documentation Template (per test case)

```markdown
### TC-XX-NNN: <name>
- **Setup:** <how to find / construct the test data>
- **Expected:** <what should happen>
- **Actual:** <what did happen — fill in after run>
- **Result:** PASS / FAIL / NEEDS-INVESTIGATION
- **Screenshot:** [link to docs/screenshots/...]
- **Notes:** <anything notable about the run>
```
