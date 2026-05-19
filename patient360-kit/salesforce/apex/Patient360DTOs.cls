/**
 * DTOs returned by Patient360DataProvider.
 * Kept as inner classes for portability; split into separate files if needed.
 */
public class Patient360DTOs {

    public class UnifiedPatientSummary {
        @AuraEnabled public String unifiedIndividualId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Integer age;
        @AuraEnabled public String ageBand;       // '0-17', '18-39', '40-64', '65+'
        @AuraEnabled public Boolean isPediatric;
        @AuraEnabled public String preferredEmail;   // Guardian email if pediatric
        @AuraEnabled public String preferredPhone;
        @AuraEnabled public List<String> clinicalCategories;
        @AuraEnabled public List<String> sourceBrands;  // brands this patient was matched across
        @AuraEnabled public Date lastEncounterDate;
        @AuraEnabled public Integer matchConfidence;    // 0-100
    }

    public class CalculatedInsight {
        @AuraEnabled public String name;
        @AuraEnabled public Decimal value;
        @AuraEnabled public String description;
        @AuraEnabled public Datetime lastComputed;
    }

    public class ConsentStatus {
        @AuraEnabled public Boolean emailOptIn;
        @AuraEnabled public Boolean smsOptIn;
        @AuraEnabled public Boolean phoneOptIn;
        @AuraEnabled public Boolean marketingOptIn;
        @AuraEnabled public Datetime lastUpdated;
    }

    public class ProviderRecommendation {
        @AuraEnabled public String providerId;
        @AuraEnabled public String providerName;
        @AuraEnabled public String specialty;
        @AuraEnabled public Decimal loadBalancingScore;
        @AuraEnabled public Integer openSlots;
        @AuraEnabled public String reasonCode;
    }
}
