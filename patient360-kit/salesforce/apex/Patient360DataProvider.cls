/**
 * Patient360DataProvider
 *
 * Interface abstraction over Data Cloud / Patient 360 data.
 * Lets the rest of the codebase work without knowing whether the data
 * comes from real Data Cloud APIs, a mock, or a future change.
 *
 * Implementations:
 *   - MockPatient360DataProvider  (returns canned data, used in dev/test)
 *   - DataCloudPatient360DataProvider  (real Data Cloud API calls)
 */
public interface Patient360DataProvider {

    /**
     * Get the unified patient profile assembled by identity resolution.
     * @param unifiedIndividualId Data Cloud Unified Individual Id
     * @return UnifiedPatientSummary DTO
     */
    UnifiedPatientSummary getUnifiedProfile(String unifiedIndividualId);

    /**
     * Get calculated insights bound to this patient
     * (engagement score, care gap score, etc).
     */
    List<CalculatedInsight> getCalculatedInsights(String unifiedIndividualId);

    /**
     * Segments this patient currently qualifies for.
     */
    List<String> getSegmentMemberships(String unifiedIndividualId);

    /**
     * Consent posture for this patient (email, sms, phone).
     */
    ConsentStatus getConsentStatus(String unifiedIndividualId);

    /**
     * Provider recommendation derived from load-balancing insight.
     */
    ProviderRecommendation getRecommendedProvider(String unifiedIndividualId);
}
