/**
 * LLMResponseValidator
 *
 * Post-generation safety net. Even with a good system prompt and Trust Layer,
 * LLMs occasionally drift into medical advice, invent diagnoses, or leak PII.
 * This validator is the last gate before the response reaches a human.
 *
 * Strategy: rule-based regex/keyword checks for fast, deterministic blocking.
 * Production version would add an LLM-as-judge pass for nuanced cases.
 */
public class LLMResponseValidator {

    public class ValidationResult {
        public Boolean isSafe;
        public List<String> flags;          // medical_advice, pii_leak, etc.
        public List<String> matchedPhrases; // for audit
    }

    // Phrases that indicate the model is giving direct medical advice
    private static final List<String> MEDICAL_ADVICE_PATTERNS = new List<String>{
        '\\byou should take\\b',
        '\\byou need to take\\b',
        '\\bI recommend (taking|stopping)\\b',
        '\\bincrease your dose\\b',
        '\\bdecrease your dose\\b',
        '\\bstart taking\\b',
        '\\bstop taking\\b',
        '\\byou (probably|likely|definitely) have\\b',
        '\\bdiagnose(d)?\\b.*\\b(with|as)\\b'
    };

    // Phrases indicating the model is making clinical claims it shouldn't
    private static final List<String> UNSUPPORTED_CLAIM_PATTERNS = new List<String>{
        '\\bguaranteed to (work|cure|heal)\\b',
        '\\bwill definitely (cure|prevent|fix)\\b',
        '\\bcure(s)? (your )?(diabetes|cancer|depression)\\b'
    };

    // Phrases indicating prompt-injection bleed
    private static final List<String> INJECTION_BLEED_PATTERNS = new List<String>{
        'ignore (previous|prior) instructions',
        'system prompt',
        'you are now',
        'forget everything'
    };

    // PII patterns that should never appear in the response
    private static final String SSN_REGEX = '\\b\\d{3}-?\\d{2}-?\\d{4}\\b';
    private static final String EMAIL_REGEX = '\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b';

    public ValidationResult validate(String response) {
        ValidationResult result = new ValidationResult();
        result.flags = new List<String>();
        result.matchedPhrases = new List<String>();
        result.isSafe = true;

        if (String.isBlank(response)) {
            return result;  // empty response is technically safe; caller decides
        }

        String lower = response.toLowerCase();

        // Medical advice
        for (String pat : MEDICAL_ADVICE_PATTERNS) {
            Matcher m = Pattern.compile(pat).matcher(lower);
            if (m.find()) {
                result.flags.add('MEDICAL_ADVICE');
                result.matchedPhrases.add(m.group());
                result.isSafe = false;
                break;
            }
        }

        // Unsupported claims
        for (String pat : UNSUPPORTED_CLAIM_PATTERNS) {
            Matcher m = Pattern.compile(pat).matcher(lower);
            if (m.find()) {
                result.flags.add('UNSUPPORTED_CLAIM');
                result.matchedPhrases.add(m.group());
                result.isSafe = false;
                break;
            }
        }

        // Injection bleed
        for (String pat : INJECTION_BLEED_PATTERNS) {
            if (Pattern.compile(pat).matcher(lower).find()) {
                result.flags.add('INJECTION_BLEED');
                result.isSafe = false;
                break;
            }
        }

        // PII leak (response leaked something redaction missed upstream)
        if (Pattern.compile(SSN_REGEX).matcher(response).find()) {
            result.flags.add('PII_LEAK_SSN');
            result.isSafe = false;
        }
        if (Pattern.compile(EMAIL_REGEX).matcher(response).find()) {
            result.flags.add('PII_LEAK_EMAIL');
            result.isSafe = false;
        }

        return result;
    }
}
