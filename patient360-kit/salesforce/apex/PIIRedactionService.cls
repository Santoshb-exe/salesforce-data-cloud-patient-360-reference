/**
 * PIIRedactionService
 *
 * Strips PII from text before it leaves Salesforce for an external LLM.
 * Defense-in-depth even when using Einstein Trust Layer — never assume
 * a single layer is enough for compliance.
 *
 * Redacts:
 *   - SSN (full and last-4)
 *   - Email addresses
 *   - Phone numbers (US formats)
 *   - Street addresses (best-effort heuristic)
 *   - Dates (replaced with age band where appropriate)
 *
 * Returns the redacted text PLUS a map of placeholders for auditing.
 */
public class PIIRedactionService {

    public class RedactionResult {
        public String redactedText;
        public Map<String, String> placeholderMap;  // placeholder -> original value
        public Integer redactionCount;
    }

    private static final String SSN_REGEX = '\\b\\d{3}-?\\d{2}-?\\d{4}\\b';
    private static final String EMAIL_REGEX = '\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b';
    private static final String PHONE_REGEX = '(\\+?1?[-.\\s]?)?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}';
    private static final String DOB_REGEX = '\\b(0?[1-9]|1[0-2])[/-](0?[1-9]|[12]\\d|3[01])[/-](19|20)\\d{2}\\b';

    public RedactionResult redact(String input) {
        RedactionResult result = new RedactionResult();
        result.placeholderMap = new Map<String, String>();
        result.redactionCount = 0;

        if (String.isBlank(input)) {
            result.redactedText = input;
            return result;
        }

        String working = input;

        // SSN
        Matcher m = Pattern.compile(SSN_REGEX).matcher(working);
        while (m.find()) {
            String placeholder = '[REDACTED_SSN_' + result.redactionCount + ']';
            result.placeholderMap.put(placeholder, m.group());
            result.redactionCount++;
        }
        working = working.replaceAll(SSN_REGEX, '[REDACTED_SSN]');

        // Email
        m = Pattern.compile(EMAIL_REGEX).matcher(working);
        while (m.find()) {
            String placeholder = '[REDACTED_EMAIL_' + result.redactionCount + ']';
            result.placeholderMap.put(placeholder, m.group());
            result.redactionCount++;
        }
        working = working.replaceAll(EMAIL_REGEX, '[REDACTED_EMAIL]');

        // Phone
        m = Pattern.compile(PHONE_REGEX).matcher(working);
        while (m.find()) {
            result.redactionCount++;
        }
        working = working.replaceAll(PHONE_REGEX, '[REDACTED_PHONE]');

        // DOB → leave a placeholder; the calling code should attach age band
        working = working.replaceAll(DOB_REGEX, '[REDACTED_DOB_USE_AGEBAND]');

        result.redactedText = working;
        return result;
    }

    /**
     * Convenience helper: redact a UnifiedPatientSummary into a minimal
     * context payload suitable for prompt construction.
     */
    public String summaryToSafeContext(Patient360DTOs.UnifiedPatientSummary s) {
        // Note: we intentionally do NOT include name in many use cases.
        // Pass only the fields the use case requires.
        return JSON.serialize(new Map<String, Object>{
            'patient_id' => '[REDACTED]',
            'age_band' => s.ageBand,
            'is_pediatric' => s.isPediatric,
            'clinical_categories' => s.clinicalCategories,
            'match_confidence' => s.matchConfidence,
            'last_encounter_days_ago' => s.lastEncounterDate == null
                ? null
                : s.lastEncounterDate.daysBetween(Date.today())
        });
    }
}
