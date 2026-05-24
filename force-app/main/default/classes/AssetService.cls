/**
 * @description    Service layer for Asset business logic. Following the
 *                 Enterprise Apex pattern, all DML and
 *                 business rules live here - the Trigger Handler only
 *                 routes context, and the Trigger itself only delegates.
 *
 *                 Responsibilities:
 *                  - Create "Kickoff Service Onboarding" Tasks when Assets
 *                    are inserted with Status = Installed.
 *                  - Handle the "Installed transition" case when Assets
 *                    move from another status to Installed on update.
 *                  - Guard against bulk DML limits (200+ records).
 *
 * @author         Harshal Ramdham
 */
public with sharing class AssetService {

    // Constants - keeping magic strings out of the logic body so that
    // picklist or label changes are a single-line edit.
    @TestVisible
    private static final String STATUS_INSTALLED   = 'Installed';
    @TestVisible
    private static final String TASK_SUBJECT       = 'Kickoff Service Onboarding';
    @TestVisible
    private static final String TASK_PRIORITY      = 'High';
    @TestVisible
    private static final String TASK_STATUS_OPEN   = 'Not Started';
    @TestVisible
    private static final Integer DEFAULT_DUE_DAYS  = 7;

    /**
     * @description Public API called by the AssetTriggerHandler when Assets
     *              are inserted. Filters out Assets that are not "Installed"
     *              and creates kickoff Tasks for the remainder.
     *
     * @param newAssets The Trigger.new list from afterInsert context.
     */
    public static void handleAfterInsert(List<Asset> newAssets) {
        if (newAssets == null || newAssets.isEmpty()) {
            return;
        }

        List<Asset> installedAssets = filterByStatus(newAssets, STATUS_INSTALLED);
        if (installedAssets.isEmpty()) {
            return;
        }

        createKickoffTasks(installedAssets);
    }

    /**
     * @description Handles the afterUpdate case: only fires when an Asset
     *              transitions INTO 'Installed' status (i.e. was something
     *              else before). Prevents duplicate Tasks on field edits.
     *
     * @param newAssets Trigger.new
     * @param oldMap    Trigger.oldMap
     */
    public static void handleAfterUpdate(List<Asset> newAssets, Map<Id, Asset> oldMap) {
        if (newAssets == null || newAssets.isEmpty() || oldMap == null) {
            return;
        }

        List<Asset> transitionedAssets = new List<Asset>();
        for (Asset a : newAssets) {
            Asset oldAsset = oldMap.get(a.Id);
            if (oldAsset == null) continue;
            // Transition: was NOT installed, now IS installed
            if (a.Status == STATUS_INSTALLED && oldAsset.Status != STATUS_INSTALLED) {
                transitionedAssets.add(a);
            }
        }

        if (!transitionedAssets.isEmpty()) {
            createKickoffTasks(transitionedAssets);
        }
    }

    // ------------------------------------------------------------------
    // Private helpers
    // ------------------------------------------------------------------

    /**
     * @description Filters a list of Assets to those matching a given status.
     */
    private static List<Asset> filterByStatus(List<Asset> assets, String targetStatus) {
        List<Asset> filtered = new List<Asset>();
        for (Asset a : assets) {
            if (a.Status == targetStatus) {
                filtered.add(a);
            }
        }
        return filtered;
    }

    /**
     * @description Bulkified Task creation. Builds all Tasks in memory, then
     *              issues a single DML statement - safe for 200+ assets per
     *              transaction. Uses a Map<Id, Id> for AccountId -> OwnerId
     *              lookup so we do exactly ONE SOQL query regardless of size.
     */
    private static void createKickoffTasks(List<Asset> installedAssets) {

        // Step 1: Collect unique AccountIds from the Assets so we can
        // resolve their Owners in a single bulkified query.
        Set<Id> accountIds = new Set<Id>();
        for (Asset a : installedAssets) {
            if (a.AccountId != null) {
                accountIds.add(a.AccountId);
            }
        }

        if (accountIds.isEmpty()) {
            // No account context means no owner to assign - log & exit.
            System.debug(LoggingLevel.WARN,
                'AssetService: ' + installedAssets.size() + ' installed assets have no AccountId; no tasks created.');
            return;
        }

        // Step 2: One query to get Account -> Owner mapping.
        Map<Id, Id> accountIdToOwnerId = new Map<Id, Id>();
        for (Account acc : [
            SELECT Id, OwnerId
            FROM Account
            WHERE Id IN :accountIds
            WITH SECURITY_ENFORCED
        ]) {
            accountIdToOwnerId.put(acc.Id, acc.OwnerId);
        }

        // Step 3: Build Tasks in memory.
        List<Task> tasksToInsert = new List<Task>();
        Date dueDate = Date.today().addDays(DEFAULT_DUE_DAYS);

        for (Asset a : installedAssets) {
            Id ownerId = accountIdToOwnerId.get(a.AccountId);
            if (ownerId == null) {
                continue; // Account had no owner (unusual but defensive)
            }
            tasksToInsert.add(new Task(
                Subject     = TASK_SUBJECT,
                Priority    = TASK_PRIORITY,
                Status      = TASK_STATUS_OPEN,
                OwnerId     = ownerId,
                WhatId      = a.AccountId,    // related-to Account
                ActivityDate= dueDate,
                Description = 'Auto-generated by AssetService when Asset "'
                              + a.Name + '" was set to Installed. '
                              + 'Please coordinate service onboarding with the customer.'
            ));
        }

        // Step 4: Single DML. Using Database.insert with allOrNone=false so
        // a single bad record does not roll back the whole batch in
        // unusual production data scenarios. Errors are surfaced via
        // SaveResult inspection (logged here; could be sent to a Custom
        // Log Object in a real prod implementation - see recommendations).
        if (!tasksToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(tasksToInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug(LoggingLevel.ERROR,
                        'AssetService: Failed to create Task for AssetId '
                        + installedAssets[i].Id + '. Errors: '
                        + results[i].getErrors());
                }
            }
        }
    }
}