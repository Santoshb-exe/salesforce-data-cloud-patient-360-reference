/**
 * LLMGateway
 *
 * Single entry point for all external LLM calls.
 * Enforces the pipeline:
 *   1. Redact PII
 *   2. Build prompt
 *   3. Call external endpoint via Named Credential
 *   4. Validate response (medical advice, PII leak, hallucination)
 *   5. Audit log
 *   6. Return safe response
 *
 * Configure a Named Credential called 'LLM_API' pointing to your
 * Azure OpenAI / OpenAI / Anthropic endpoint. Auth via header injection.
 *
 * DO NOT hardcode API keys. DO NOT bypass validation. DO NOT log raw payloads
 * to debug logs in production.
 */
public class LLMGateway {

    public class LLMRequest {
        public String systemPrompt;
        public String userPrompt;
        public String unifiedIndividualId;
        public String scenarioId;        // for evals
        public Patient360DTOs.UnifiedPatientSummary patientContext; // optional
    }

    public class LLMResponse {
        public Boolean success;
        public String content;
        public String failureReason;     // null on success
        public Integer redactionCount;
        public List<String> validationFlags;  // medical_advice, pii_leak, etc.
        public Datetime timestamp;
    }

    private static final Integer CALLOUT_TIMEOUT_MS = 30000;
    private static final String NAMED_CREDENTIAL = 'callout:LLM_API';

    public LLMResponse invoke(LLMRequest req) {
        LLMResponse resp = new LLMResponse();
        resp.timestamp = Datetime.now();
        resp.validationFlags = new List<String>();

        // 1. Redact
        PIIRedactionService redactor = new PIIRedactionService();
        PIIRedactionService.RedactionResult redacted = redactor.redact(req.userPrompt);
        resp.redactionCount = redacted.redactionCount;

        // 2. Build the final prompt (system + redacted user + safe context)
        String safeContext = req.patientContext != null
            ? redactor.summaryToSafeContext(req.patientContext)
            : '';

        Map<String, Object> body = new Map<String, Object>{
            'messages' => new List<Map<String, String>>{
                new Map<String, String>{
                    'role' => 'system',
                    'content' => req.systemPrompt
                },
                new Map<String, String>{
                    'role' => 'user',
                    'content' => redacted.redactedText
                        + (String.isBlank(safeContext) ? '' : '\n\nContext: ' + safeContext)
                }
            },
            'temperature' => 0.2,
            'max_tokens' => 800
        };

        // 3. Callout
        HttpRequest http = new HttpRequest();
        http.setEndpoint(NAMED_CREDENTIAL + '/chat/completions');
        http.setMethod('POST');
        http.setHeader('Content-Type', 'application/json');
        http.setTimeout(CALLOUT_TIMEOUT_MS);
        http.setBody(JSON.serialize(body));

        HttpResponse httpResp;
        try {
            httpResp = new Http().send(http);
        } catch (Exception e) {
            resp.success = false;
            resp.failureReason = 'CALLOUT_FAILED: ' + e.getMessage();
            auditLog(req, resp);
            return resp;
        }

        if (httpResp.getStatusCode() < 200 || httpResp.getStatusCode() >= 300) {
            resp.success = false;
            resp.failureReason = 'HTTP_' + httpResp.getStatusCode();
            auditLog(req, resp);
            return resp;
        }

        // 4. Parse + validate
        String rawContent = parseContent(httpResp.getBody());
        LLMResponseValidator validator = new LLMResponseValidator();
        LLMResponseValidator.ValidationResult v = validator.validate(rawContent);
        resp.validationFlags = v.flags;

        if (!v.isSafe) {
            resp.success = false;
            resp.failureReason = 'VALIDATION_FAILED: ' + String.join(v.flags, ',');
            resp.content = '[Response blocked by output validator]';
        } else {
            resp.success = true;
            resp.content = rawContent;
        }

        // 5. Audit
        auditLog(req, resp);
        return resp;
    }

    private String parseContent(String responseBody) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> choices = (List<Object>) parsed.get('choices');
        if (choices == null || choices.isEmpty()) return '';
        Map<String, Object> first = (Map<String, Object>) choices[0];
        Map<String, Object> message = (Map<String, Object>) first.get('message');
        return (String) message.get('content');
    }

    private void auditLog(LLMRequest req, LLMResponse resp) {
        // In production: insert into AI_Audit_Log__c with PII-safe fields.
        // For now: System.debug at INFO level — never log raw prompts or responses.
        System.debug(LoggingLevel.INFO, JSON.serialize(new Map<String, Object>{
            'scenario' => req.scenarioId,
            'success' => resp.success,
            'redactions' => resp.redactionCount,
            'flags' => resp.validationFlags,
            'failure' => resp.failureReason,
            'ts' => resp.timestamp
        }));
    }
}
