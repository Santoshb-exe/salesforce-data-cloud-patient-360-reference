/**
 * MockPatient360DataProvider
 *
 * Returns canned data for development and test runs.
 * Use this when:
 *   - Data Cloud trial hasn't been provisioned yet
 *   - You're running unit tests
 *   - You're demoing without live data
 *
 * Swap to DataCloudPatient360DataProvider for real integration.
 */
public class MockPatient360DataProvider implements Patient360DataProvider {

    public Patient360DTOs.UnifiedPatientSummary getUnifiedProfile(String unifiedIndividualId) {
        Patient360DTOs.UnifiedPatientSummary s = new Patient360DTOs.UnifiedPatientSummary();
        s.unifiedIndividualId = unifiedIndividualId;
        s.firstName = 'Jane';
        s.lastName = 'Doe';
        s.age = 42;
        s.ageBand = '40-64';
        s.isPediatric = false;
        s.preferredEmail = 'jane.doe@example.test';
        s.preferredPhone = '+1-555-0100';
        s.clinicalCategories = new List<String>{'Diabetes', 'Cardiac'};
        s.sourceBrands = new List<String>{'MEDFIRST', 'CAREPLUS'};
        s.lastEncounterDate = Date.today().addDays(-45);
        s.matchConfidence = 95;
        return s;
    }

    public List<Patient360DTOs.CalculatedInsight> getCalculatedInsights(String unifiedIndividualId) {
        List<Patient360DTOs.CalculatedInsight> out = new List<Patient360DTOs.CalculatedInsight>();

        Patient360DTOs.CalculatedInsight engagement = new Patient360DTOs.CalculatedInsight();
        engagement.name = 'PatientEngagementScore';
        engagement.value = 73.5;
        engagement.description = 'Likelihood-to-respond score based on recent opens, clicks, conversions';
        engagement.lastComputed = Datetime.now().addHours(-3);
        out.add(engagement);

        Patient360DTOs.CalculatedInsight careGap = new Patient360DTOs.CalculatedInsight();
        careGap.name = 'CareGapScore';
        careGap.value = 0.62;
        careGap.description = 'Overdue Annual Wellness + last HbA1c > 6 months';
        careGap.lastComputed = Datetime.now().addHours(-3);
        out.add(careGap);

        return out;
    }

    public List<String> getSegmentMemberships(String unifiedIndividualId) {
        return new List<String>{
            'Diabetic Patients — Quarterly Outreach',
            'Annual Wellness Due',
            'High Engagement Re-Targeting'
        };
    }

    public Patient360DTOs.ConsentStatus getConsentStatus(String unifiedIndividualId) {
        Patient360DTOs.ConsentStatus c = new Patient360DTOs.ConsentStatus();
        c.emailOptIn = true;
        c.smsOptIn = false;
        c.phoneOptIn = true;
        c.marketingOptIn = true;
        c.lastUpdated = Datetime.now().addDays(-30);
        return c;
    }

    public Patient360DTOs.ProviderRecommendation getRecommendedProvider(String unifiedIndividualId) {
        Patient360DTOs.ProviderRecommendation p = new Patient360DTOs.ProviderRecommendation();
        p.providerId = 'PRV-1042';
        p.providerName = 'Dr. Alex Morgan';
        p.specialty = 'Endocrinology';
        p.loadBalancingScore = 4.21;
        p.openSlots = 14;
        p.reasonCode = 'HIGH_RVU_AVAILABLE_CAPACITY';
        return p;
    }
}
