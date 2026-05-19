# Weeks 5–8 — Agentforce + LLM + Evals + Public Launch

Month 2 is the differentiator phase. The base built in Month 1 is real value;
this layer is what separates you from every other Salesforce Data Cloud
practitioner.

---

## Week 5 — Data Cloud APIs + Patient 360 UI Shell

**Goal:** A thin app layer that queries Patient 360 data and displays it. Lets the rest of the build (Agentforce, LLM) consume data without re-implementing access patterns.

### Day 1 — Apex abstraction layer
Drop these into your org from `salesforce/apex/`:
- `Patient360DataProvider.cls` (interface)
- `Patient360DTOs.cls` (return types)
- `MockPatient360DataProvider.cls` (canned data for dev)

Use `Patient360DataProvider provider = new MockPatient360DataProvider();` everywhere downstream. Swap to real implementation when Data Cloud is wired up.

### Day 2 — Mock provider works end-to-end
Verify in anonymous Apex:
```apex
Patient360DataProvider p = new MockPatient360DataProvider();
Patient360DTOs.UnifiedPatientSummary s = p.getUnifiedProfile('test-id');
System.debug(JSON.serializePretty(s));
```

### Day 3 — Real Data Cloud provider (if Track A)
Create `DataCloudPatient360DataProvider.cls` that calls Data Cloud's Query API via Named Credential. Implement `getUnifiedProfile` first as a smoke test.

### Day 4 — LWC `patient360Summary`
A simple Lightning Web Component that takes a `unifiedIndividualId`, calls the provider via `@AuraEnabled` Apex, and renders:
- Patient summary card
- Clinical categories as badges
- Engagement score gauge
- Segment memberships as list
- Consent indicators

### Day 5 — Flow + Quick Action
Add a Quick Action on the Contact record page that launches a Flow showing the LWC.

### Day 6 — Test classes
Write Apex tests for the provider, the mock, and the DTO serialization. Aim for 90% coverage on this layer — it's the foundation.

### Day 7 — Journal + commit.

---

## Week 6 — Agentforce Foundation

**Goal:** Build an internal Patient Outreach Agent that uses controlled actions and grounds in Patient 360 data.

### Day 1 — Agent design doc
`agentforce/agent-design.md`:
- **Purpose:** internal care coordinator outreach assistant (NOT patient-facing)
- **Users:** internal care coordinators only
- **Allowed actions:** retrieve patient summary, retrieve consent, draft outreach, request provider recommendation
- **Restricted:** no diagnosis, no medical advice, no PII exposure, no medication recommendations
- **Grounding sources:** unified profile, segments, calculated insights, consent
- **Escalation:** any clinical question → "refer to provider", any ambiguity → "manual review"

### Day 2 — Prompt templates
Create in Prompt Builder (or document as files):
- `patient_summary_prompt.md` — generates 2-sentence patient summary
- `outreach_draft_prompt.md` — drafts a compliant outreach message
- `care_gap_explanation_prompt.md` — explains why patient is in segment X

Each template MUST include:
- System instruction: "You are an internal healthcare outreach assistant"
- Constraints: no medical advice, cite data sources, refuse if confidence low
- Grounding placeholder: `{{ patient_360_context }}`

### Day 3 — Custom Agent Actions
Wire Apex Invocable Methods as Agent Actions:
1. `GetPatientSummaryAction` → calls `Patient360DataProvider.getUnifiedProfile`
2. `GetConsentStatusAction` → calls `getConsentStatus`
3. `GetProviderRecommendationAction` → calls `getRecommendedProvider`
4. `GenerateOutreachDraftAction` → calls LLM via `LLMGateway`
5. `LogOutreachRecommendationAction` → writes to `Patient_Outreach_Recommendation__c`

Each Action is an `@InvocableMethod` with explicit input/output classes.

### Day 4 — Agent assembly
In Agent Builder:
- Create Topics for outreach scenarios
- Bind the 5 actions to topics
- Add the system prompt
- Configure escalation rules

### Day 5 — Test scenarios
Run through 5 scenarios manually:
1. Normal adult diabetic patient
2. Pediatric patient (verify guardian routing in draft)
3. Opted-out patient (verify refusal)
4. Patient with missing data (verify acknowledgment)
5. Ambiguous identity (low match confidence)

### Day 6 — Screenshots + Trust Layer review
Capture every interaction. Verify Einstein Trust Layer is masking PII in test transcripts.

### Day 7 — Journal + ADR-008 (agent action boundaries).

---

## Week 7 — External LLM + Guardrails

**Goal:** Build the AI integration layer with redaction, validation, and safe fallback.

### Day 1 — Named Credential
Set up `LLM_API` Named Credential pointing to your Azure OpenAI or OpenAI endpoint. Auth via header injection. **Test connectivity** before writing any code.

### Day 2 — Drop in the Apex classes
From `salesforce/apex/`:
- `PIIRedactionService.cls`
- `LLMGateway.cls`
- `LLMResponseValidator.cls`

Write smoke tests for each.

### Day 3 — `Patient360LLMService.cls`
The orchestration wrapper that:
1. Pulls minimum necessary context via `Patient360DataProvider`
2. Builds the prompt
3. Calls `LLMGateway`
4. Returns safe response

Pattern:
```apex
public class Patient360LLMService {
    public String summarizePatient(String unifiedIndividualId) {
        Patient360DataProvider provider = new MockPatient360DataProvider(); // swap later
        Patient360DTOs.UnifiedPatientSummary s = provider.getUnifiedProfile(unifiedIndividualId);

        LLMGateway.LLMRequest req = new LLMGateway.LLMRequest();
        req.systemPrompt = 'You are an internal healthcare outreach assistant. ' +
                           'Respond in 2 sentences. Never invent clinical facts. ' +
                           'Cite only the provided context.';
        req.userPrompt = 'Summarize this patient\'s outreach readiness.';
        req.patientContext = s;
        req.scenarioId = 'EVAL-001';

        LLMGateway.LLMResponse resp = new LLMGateway().invoke(req);
        return resp.success ? resp.content : '[Unable to generate summary: ' + resp.failureReason + ']';
    }
}
```

### Day 4 — `PromptInjectionDetector.cls`
Pre-callout layer that flags obvious injection attempts in user input. Patterns to detect:
- "ignore previous instructions"
- "you are now"
- "system prompt"
- Encoded variants (base64, leetspeak)

Block if confidence > threshold; pass with warning otherwise.

### Day 5 — End-to-end test
Run a complete flow:
1. User clicks "Generate Outreach Draft" on a Contact record
2. LWC → Flow → Agent Action → `Patient360LLMService` → `LLMGateway` → external LLM → validation → response back to user
3. Verify audit log entry exists

### Day 6 — Trust boundary diagram
`diagrams/trust-boundary.md` showing where redaction happens, where validation happens, what data crosses which boundary. Mermaid is fine.

### Day 7 — ADR-009 (external LLM trust boundary), journal.

---

## Week 8 — Evals + Packaging + Public Launch

**Goal:** Ship it.

### Day 1 — Eval scenarios
Already in `eval-scenarios/scenarios.csv` (30 scenarios). Review, customize, add 5 more specific to scenarios you care about.

### Day 2 — `AI_Eval_Result__c` custom object
Create the custom object with all fields per the plan. Each eval run inserts one record.

### Day 3 — `AIEvalRunner.cls`
A scheduled Apex job that:
1. Loads scenarios from a Custom Metadata Type or CSV-loaded custom object
2. For each scenario, invokes `Patient360LLMService` with the prompt
3. Auto-scores against the expected behavior (regex/keyword match — keep simple)
4. Logs pass/fail to `AI_Eval_Result__c`

### Day 4 — Run the eval suite
Execute. Review results. Document which scenarios pass, which fail, which need work. **Failing evals at this stage are GOOD** — they prove the harness works and give you content for the post.

### Day 5 — README polish
Final README sections:
- Problem statement
- Architecture (diagrams)
- Features list
- Setup
- Data model summary
- Screenshots
- Demo video link
- Limitations (be honest)
- Lessons learned

### Day 6 — Demo video (3-5 min Loom)
Script:
1. "This is a Patient 360 reference implementation."
2. Show source data → ID collision problem
3. Show DLO → DMO mapping
4. Show identity resolution + pediatric routing
5. Show CIs + segments
6. Show Agentforce agent in action
7. Show LLM guardrail / eval results
8. Close with limitations

### Day 7 — Publish
- Push final commit
- Publish Medium Post 1 (Data Cloud Patient 360 Implementation)
- Publish Medium Post 3 (Agentforce + Data Cloud + LLM Guardrails)
- LinkedIn post linking to GitHub + Medium + demo
- Update resume with the "Currently Building" → "Built" bullet
- Update LinkedIn headline to mention Data Cloud + Agentforce

**ADR-010** committed (evals and guardrails).

---

## End of Month 2 Milestone — Definition of Done

- [ ] Public GitHub repo with clean README
- [ ] All 3 Medium posts published
- [ ] Demo video (Loom) linked from README
- [ ] 30+ eval scenarios with results logged
- [ ] LLM integration with redaction + validation working end-to-end
- [ ] Agentforce agent grounded in Patient 360 data
- [ ] LWC patient summary component
- [ ] All 10 ADRs committed
- [ ] LinkedIn updated with new positioning
- [ ] Resume updated with completed-project bullet
- [ ] Both certs (Data Cloud Consultant + Agentforce Specialist) scheduled or done

When this is done, your story is no longer "9-year Salesforce architect studying Data Cloud." It's "Architect who built an end-to-end Patient 360 reference implementation with Agentforce and governed AI integration." That's a story recruiters at Salesforce, healthcare GCCs, and AI-augmented enterprise platforms all want to hear.
