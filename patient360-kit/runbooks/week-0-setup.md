# Week 0 — Setup (Days 1–3)

**Goal:** Provision accounts, tools, and the project skeleton. Document your access reality. Pick Track A / B / C.

You're done with Week 0 when:
- GitHub repo exists with this folder structure
- Salesforce CLI works locally
- Data Cloud trial requested (waiting is fine; don't block on it)
- `docs/access-notes.md` exists with your current access state
- ADR-001 is committed
- You can describe the project in 60 seconds out loud

Time budget: **3-6 hours total across 3 days**. This is the cheapest week. Don't overthink it.

---

## Day 1 — Repo + Story (90 min)

### Step 1: Create GitHub repo
```
Repo name: salesforce-data-cloud-patient-360-reference
Visibility: Public (this is the point — recruiter signal)
License: MIT
.gitignore: from template "Python" + manually add: .sfdx/, .vscode/settings.json, *.env, *.key
```

### Step 2: Clone locally and copy this kit
```bash
git clone https://github.com/<your-username>/salesforce-data-cloud-patient-360-reference.git
cd salesforce-data-cloud-patient-360-reference
# Copy the contents of patient360-kit/ into the repo root
```

### Step 3: First README.md
Replace the auto-generated README with:

```markdown
# Salesforce Data Cloud — Patient 360 Reference Implementation

A public, defensible reference implementation of a Salesforce Data Cloud +
Agentforce + LLM-grounded healthcare Patient 360, built end-to-end with
synthetic multi-brand data.

## What this is

An independent, hands-on reference build that demonstrates:
- Multi-source healthcare data ingestion with source-key collision handling
- DLO → DMO mapping for a Patient 360 model
- Identity resolution across three fictional brands
- Calculated Insights (provider load balancing, engagement scoring)
- Segmentation and activation patterns
- Agentforce custom actions grounded in Data Cloud
- External LLM integration with PII redaction, response validation, and evals

## What this is NOT

- Not production code
- Not a real patient system
- Not a copy of any employer's implementation
- All data is synthetic. No PHI. No client information.

## Status

In active build. See [`docs/weekly-build-journal/`](docs/weekly-build-journal/) for progress.

## Quick start

```bash
cd data-generator
pip install -r requirements.txt
python generate_all.py
# CSVs land in ../data/
```

## Architecture

See [`docs/architecture/`](docs/architecture/) and [`diagrams/`](diagrams/).
```

Commit:
```bash
git add .
git commit -m "init patient 360 reference implementation"
git push
```

### Step 4: 60-second pitch — write it down
In `docs/pitch.md` write a 6-sentence elevator pitch of the project. Re-read it before every recruiter call. Example:

> I'm building a public Salesforce Data Cloud Patient 360 reference implementation with synthetic multi-brand healthcare data. It demonstrates ingestion with source-key collision handling, identity resolution, Calculated Insights for provider load balancing, and segmentation with consent enforcement. I've layered Agentforce on top using custom Apex actions, and added an external LLM gateway with PII redaction, response validation, and a 30-scenario eval harness. The data is synthetic — no real patient data, no client data. My existing healthcare Salesforce experience informs the architectural choices, but this implementation is built independently in my own org.

---

## Day 2 — Access Reality Check (90 min)

### Step 1: Request Salesforce Data Cloud trial
Go to: https://www.salesforce.com/form/data-cloud/data-cloud-trial-org/

Submit the form. Trial provisioning is uneven — could be instant, could be days, could need a Salesforce contact's help. **Don't block on it.** Continue with the rest of the plan in parallel.

### Step 2: Backup option — Salesforce Developer Edition
While you wait, sign up for a regular Dev Edition org. Some Data Cloud features are limited but core platform work (Apex, LWC, custom objects, Named Credentials) is fully available.

https://developer.salesforce.com/signup

### Step 3: Marketing Cloud Engagement (SFMC) trial — optional but high-leverage
If you want to wire up activation properly, request an SFMC trial. Often paired with Data Cloud requests.

### Step 4: External LLM account
Choose ONE (don't do both):
- **Azure OpenAI** (preferred — matches enterprise JDs better, harder to set up): https://azure.microsoft.com/en-us/products/ai-services/openai-service
- **OpenAI direct** (easier — $5 credit gets you very far): https://platform.openai.com/signup

Budget cap: **set spending limit to $10/month**. Project will not exceed this. Don't burn money.

### Step 5: Local tools
```bash
# Salesforce CLI
npm install -g @salesforce/cli
sf --version

# VS Code extensions: Salesforce Extension Pack, Apex PMD, Prettier

# Python 3.11+
python3 --version
pip install --upgrade pip
```

### Step 6: Document access state
Create `docs/access-notes.md`:

```markdown
# Access Notes — Updated <DATE>

## Salesforce
- Dev Edition org: <username> (provisioned <date>)
- Data Cloud trial: REQUESTED / PROVISIONED / WAITING / DENIED
- Marketing Cloud trial: REQUESTED / PROVISIONED / WAITING / NOT-PURSUED

## External LLM
- Provider: Azure OpenAI / OpenAI
- API key issued: yes/no
- Spending cap: $10/month

## Track decision
- **Track A** (full Data Cloud) — TBD
- **Track B** (limited trial) — TBD
- **Track C** (mock-first) — current default until Data Cloud lands
```

Commit:
```bash
git add docs/access-notes.md
git commit -m "add access notes and project tooling setup"
git push
```

---

## Day 3 — First Architecture + ADR-001 (90 min)

### Step 1: Problem statement
Create `docs/architecture/problem-statement.md` (use this as a starter):

```markdown
# Problem Statement

A fictional US healthcare group has acquired three brands:
- **MedFirst** — primary care network in the Northeast
- **CarePlus** — multi-specialty group in the Midwest
- **HealthBridge** — community clinics in the Southeast

Each brand operates its own EHR, scheduling system, and marketing stack.
After acquisition, the parent organization needs:

1. A unified Patient 360 view across all three brands
2. HIPAA-compliant marketing and care coordination outreach
3. Provider load balancing across the combined network
4. AI-assisted internal workflows (summarization, recommendation drafting)

**Source-system challenges:**
- Patient ID `12345` exists at all three brands — referring to three
  different people
- Some patients exist at multiple brands (cross-brand duplicates)
- Pediatric patients require guardian routing for outreach
- Marketers should not write SQL against ICD-10 directly
- Consent posture varies across patients and channels

**Scope of this reference implementation:**
End-to-end on Salesforce Data Cloud + Agentforce + external LLM, with
synthetic data and no real PHI.
```

### Step 2: ADR-001 — Synthetic Data Only
Create `docs/decisions/ADR-001-synthetic-data-only.md`:

```markdown
# ADR-001: Synthetic Data Only

## Status
Accepted

## Context
This is a public reference implementation. It will live on GitHub and
demonstrate architectural patterns to recruiters and interviewers. Any
real patient data — even seemingly innocuous fields — creates compliance
risk and confidentiality risk.

## Decision
All data in this repository is synthetic, generated by a Python script
using `Faker`. No real PHI, no client data, no production schemas, no
screenshots from any employer's environment.

## Alternatives Considered
- Use anonymized employer data — REJECTED. Anonymization is fragile and
  legally insufficient given HIPAA Safe Harbor requirements.
- Use public healthcare datasets — REJECTED. Adds licensing complexity
  for marginal realism gain.

## Consequences
- Positive: Zero compliance risk. Fully shareable. Reproducible.
- Negative: Some edge cases must be manually engineered into the
  generator rather than emerging naturally.

## Interview Talking Point
"I deliberately built this on synthetic data so the architectural
discussion stays clean. Nothing in the repo is bound by any employer's
confidentiality agreements."
```

### Step 3: First architecture diagram (Mermaid)
Create `diagrams/c4-context.md`:

```markdown
# C4 Context — Patient 360 Reference Implementation

\`\`\`mermaid
graph TB
    subgraph "Source Brands"
        MF[MedFirst EHR]
        CP[CarePlus EHR]
        HB[HealthBridge EHR]
    end

    subgraph "External Systems"
        SFMC[Marketing Cloud]
        LLM[External LLM<br/>Azure OpenAI]
    end

    subgraph "Salesforce Platform"
        DC[Data Cloud<br/>Patient 360]
        CRM[Sales/Service Cloud]
        AF[Agentforce Agent]
    end

    User[Care Coordinator<br/>Internal User]

    MF --> DC
    CP --> DC
    HB --> DC
    DC --> CRM
    DC --> SFMC
    CRM --> AF
    AF --> LLM
    User --> AF
    User --> CRM
\`\`\`
```

### Step 4: Commit Week 0
```bash
git add docs/ diagrams/
git commit -m "week-0: problem statement, ADR-001 synthetic data, C4 context diagram"
git push
```

---

## Week 0 Definition of Done — Checklist

- [ ] Repo exists and is public
- [ ] README explains the project
- [ ] Folder structure committed
- [ ] `docs/access-notes.md` reflects current access state
- [ ] Data Cloud trial requested
- [ ] LLM account created with $10 spending cap
- [ ] `docs/architecture/problem-statement.md` committed
- [ ] `docs/decisions/ADR-001-synthetic-data-only.md` committed
- [ ] `diagrams/c4-context.md` committed
- [ ] You can pitch the project in 60 seconds without notes

If all boxes ticked → start Week 1.
