# Patient 360 Reference Implementation Kit

An executable starter kit for building a public Salesforce Data Cloud + Agentforce + LLM-grounded healthcare Patient 360 reference implementation.

**This kit is a starting point, not the finished project.** It gives you the code skeletons, data generator, runbooks, and evaluation framework so you can focus on building rather than figuring out the "how" each time.

---

## What's in here

```
patient360-kit/
├── README.md                          ← you are here
├── runbooks/
│   ├── week-0-setup.md               ← start here Monday morning
│   ├── weeks-1-to-4-data-cloud-build.md
│   └── weeks-5-to-8-agentforce-llm-evals.md
├── data-generator/
│   ├── generate_all.py               ← Python — generates all synthetic CSVs
│   ├── config.yaml                   ← knobs: brand sizes, edge case counts, seed
│   └── requirements.txt
├── data/                              ← PRE-GENERATED synthetic CSVs (1,930 patients)
│   ├── medfirst_patients.csv
│   ├── careplus_patients.csv
│   ├── healthbridge_patients.csv
│   ├── providers.csv
│   ├── encounters.csv
│   ├── engagement_events.csv
│   ├── clinical_reference.csv
│   ├── provider_performance.csv
│   └── consent_preferences.csv
├── salesforce/
│   └── apex/                          ← skeleton Apex classes
│       ├── Patient360DataProvider.cls
│       ├── Patient360DTOs.cls
│       ├── MockPatient360DataProvider.cls
│       ├── PIIRedactionService.cls
│       ├── LLMGateway.cls
│       └── LLMResponseValidator.cls
├── sql/
│   └── calculated_insights.sql        ← 3 CIs + pediatric routing transformation
├── eval-scenarios/
│   └── scenarios.csv                  ← 30 AI eval scenarios
└── identity-resolution/
    └── test-cases.md                  ← 12 identity resolution test cases
```

---

## Quick start (Day 1)

1. Read `runbooks/week-0-setup.md`.
2. Create your public GitHub repo named `salesforce-data-cloud-patient-360-reference`.
3. Copy this kit's contents into the repo root.
4. Run the data generator to confirm it works on your machine:
   ```bash
   cd data-generator
   pip install -r requirements.txt
   python generate_all.py
   ```
5. Inspect a generated CSV and confirm you see realistic synthetic data.
6. Commit + push. You're done with Day 1.

That's it. Don't try to do more than this on Day 1.

---

## What's pre-generated vs what you build

| Component | Status |
|---|---|
| Synthetic data generator | ✅ done, runs out of the box |
| Sample CSVs (1,930 patients, 4,786 encounters, 15K events) | ✅ included |
| Apex skeleton classes | ✅ included, drop into your org |
| Calculated Insight SQL | ✅ included, adapt DMO names to your org |
| Identity resolution test cases | ✅ documented, you execute them |
| AI eval scenarios | ✅ 30 included, you can add more |
| Week-by-week runbooks | ✅ included |
| Your Data Cloud DLO/DMO mappings | ⚠️ you build in your org |
| Your Identity Resolution rulesets | ⚠️ you configure in Data Cloud |
| Your Agentforce agent | ⚠️ you build in Agent Builder |
| Your Medium posts | ⚠️ you write |
| Your demo video | ⚠️ you record |
| Your GitHub repo + README | ⚠️ you own and maintain |

---

## Principles

These came from the original plan and they govern every decision in this kit:

1. **Honest positioning.** You're building this in your own org with synthetic data. Don't claim production ownership of anything you haven't built. Resume bullet: *"Built independently in a personal org using synthetic data, informed by professional healthcare Salesforce experience."*

2. **Synthetic data only.** No real PHI. No client schemas. No employer screenshots.

3. **Architecture depth over visual glamour.** A clean README and a working eval harness beats a pretty UI.

4. **Public artifact mindset.** Every week leaves behind something committed — code, docs, decisions, screenshots, or notes.

5. **Three tracks, one outcome.** Whether you get full Data Cloud access (A), a limited trial (B), or no access yet (C), you can complete this project. The mock provider keeps you unblocked.

---

## Data characteristics (already generated)

The pre-generated dataset includes deliberate edge cases:

- **50 source ID collisions** — same `source_patient_id` exists in all three brands referring to different people (forces global key strategy)
- **80 cross-brand duplicates** — same person appears in 2-3 brands with name typos, changed phones, changed emails (forces identity resolution to work)
- **269 pediatric patients** (≈15%) with guardian email populated (tests guardian routing logic)
- **Twins** at the same address with the same DOB but different first names (anti-match test)
- **Family-shared emails** across multiple patients (anti-match test)
- **Reused phones** across different patients (anti-match test)

You can regenerate with different seeds or counts via `data-generator/config.yaml`.

---

## Tracks based on access

**Track A** — full Data Cloud trial provisioned. Build everything in the platform. Best learning outcome.

**Track B** — short Data Cloud trial window. Use trial for screenshots and proof; document the rest. Still a strong artifact.

**Track C** — no Data Cloud access yet. Use `MockPatient360DataProvider`, document the design fully, build everything else (Apex services, LLM integration, evals). When access arrives, plug in `DataCloudPatient360DataProvider`.

**Don't block the project on perfect access.** Track C is honest and complete enough to land interviews. Add the Data Cloud pieces as access becomes available.

---

## What to commit, what to never commit

✅ Commit:
- Code, docs, diagrams, synthetic CSVs
- Architecture Decision Records
- Screenshots of your own Dev/trial org
- Weekly build journal entries

❌ Never commit:
- API keys (use Named Credentials in Salesforce; .env locally)
- Any real patient data
- Any data or schema from any employer
- Screenshots from employer systems
- Confidential client names

The `.gitignore` should include: `.sfdx/`, `.env`, `*.key`, `*.pem`, `secrets/`.

---

## Positioning after completion

Use this language in interviews and on LinkedIn:

> "I built a public Salesforce Data Cloud Patient 360 reference implementation end-to-end using synthetic multi-brand healthcare data. It covers ingestion with source-key collision handling, identity resolution, Calculated Insights for provider load balancing and engagement scoring, segmentation with consent enforcement, and an Agentforce + external LLM layer with PII redaction, response validation, and a 30-scenario eval harness. My professional healthcare Salesforce experience informed the architectural choices; this implementation was built independently in my own org."

That's honest, defensible, and demonstrates the exact skills the JDs are asking for.

---

## Daily working rhythm

- **Busy day (60 min):** 20 build, 20 document, 20 commit
- **Normal day (2 hr):** 60 build, 30 test/screenshot, 30 doc
- **Weekend block (3-4 hr):** deep build + write-up

**Commit something every build day.** Small commits beat heroic weekend disappearances.

Good luck. Start with `runbooks/week-0-setup.md`.
