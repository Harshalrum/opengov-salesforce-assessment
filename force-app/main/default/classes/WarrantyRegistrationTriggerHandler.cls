/**
 * @description    Trigger Handler for Warranty_Registration__c. Demonstrates
 *                 the use of addError() to catch validation cases that a
 *                 declarative Validation Rule cannot easily express.
 *
 *                 Complex validations enforced here:
 *                  1. An Account cannot have more than ONE Active warranty
 *                     for the same Asset at the same time. (Cross-record
 *                     check - impossible with a standard validation rule.)
 *                  2. The Asset on the warranty must belong to the same
 *                     Account as the warranty itself. (Cross-object check.)
 *
 * @author         OpenGov Candidate Submission
 */
public with sharing class WarrantyRegistrationTriggerHandler extends TriggerHandler {

    private static final String STATUS_ACTIVE = 'Active';

    protected override void beforeInsert() {
        validateWarranties((List<Warranty_Registration__c>) Trigger.new, null);
    }

    protected override void beforeUpdate() {
        validateWarranties(
            (List<Warranty_Registration__c>) Trigger.new,
            (Map<Id, Warranty_Registration__c>) Trigger.oldMap
        );
    }

    /**
     * @description Runs both complex validations in a bulkified fashion.
     *              addError() is called per offending record so the user
     *              gets a clean, field-level error in the UI.
     */
    private static void validateWarranties(
        List<Warranty_Registration__c> newRecs,
        Map<Id, Warranty_Registration__c> oldMap
    ) {
        // -------------------------------------------------------------
        // Gather context in bulk
        // -------------------------------------------------------------
        Set<Id> assetIds   = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> recordIds  = new Set<Id>();

        for (Warranty_Registration__c w : newRecs) {
            if (w.Asset__c   != null) assetIds.add(w.Asset__c);
            if (w.Account__c != null) accountIds.add(w.Account__c);
            if (w.Id         != null) recordIds.add(w.Id); // for update context
        }

        // -------------------------------------------------------------
        // VALIDATION 1: Asset must belong to the same Account
        // -------------------------------------------------------------
        Map<Id, Id> assetIdToAccountId = new Map<Id, Id>();
        if (!assetIds.isEmpty()) {
            for (Asset a : [
                SELECT Id, AccountId
                FROM Asset
                WHERE Id IN :assetIds
                WITH SECURITY_ENFORCED
            ]) {
                assetIdToAccountId.put(a.Id, a.AccountId);
            }
        }

        // -------------------------------------------------------------
        // VALIDATION 2: Build map of existing Active warranties per Asset
        // (excluding the records currently being updated, to avoid self-collision)
        // -------------------------------------------------------------
        Map<Id, Id> assetIdToExistingActiveWarrantyId = new Map<Id, Id>();
        if (!assetIds.isEmpty()) {
            for (Warranty_Registration__c existing : [
                SELECT Id, Asset__c
                FROM Warranty_Registration__c
                WHERE Asset__c IN :assetIds
                  AND Status__c = :STATUS_ACTIVE
                  AND Id NOT IN :recordIds
                WITH SECURITY_ENFORCED
            ]) {
                assetIdToExistingActiveWarrantyId.put(existing.Asset__c, existing.Id);
            }
        }

        // Also track duplicates within the SAME Trigger.new batch
        // (e.g. someone bulk-loads two Active warranties for one asset)
        Map<Id, Warranty_Registration__c> sameBatchActivePerAsset =
            new Map<Id, Warranty_Registration__c>();

        // -------------------------------------------------------------
        // Apply validations
        // -------------------------------------------------------------
        for (Warranty_Registration__c w : newRecs) {

            // 1) Asset/Account mismatch
            if (w.Asset__c != null && w.Account__c != null) {
                Id assetAccountId = assetIdToAccountId.get(w.Asset__c);
                if (assetAccountId != null && assetAccountId != w.Account__c) {
                    w.Asset__c.addError(
                        'The selected Asset belongs to a different Account. ' +
                        'Please choose an Asset that belongs to ' +
                        'the same Account as this Warranty Registration.'
                    );
                }
            }

            // 2) Duplicate Active warranty for same Asset
            if (w.Status__c == STATUS_ACTIVE && w.Asset__c != null) {

                // Conflict with already-saved record
                if (assetIdToExistingActiveWarrantyId.containsKey(w.Asset__c)) {
                    w.Asset__c.addError(
                        'This Asset already has an Active Warranty Registration. ' +
                        'Please deactivate the existing record before creating a new one.'
                    );
                }
                // Conflict within the same DML batch
                else if (sameBatchActivePerAsset.containsKey(w.Asset__c)) {
                    w.Asset__c.addError(
                        'Two records in this batch attempt to set an Active ' +
                        'Warranty on the same Asset. Only one Active warranty ' +
                        'per Asset is allowed.'
                    );
                } else {
                    sameBatchActivePerAsset.put(w.Asset__c, w);
                }
            }
        }
    }
}