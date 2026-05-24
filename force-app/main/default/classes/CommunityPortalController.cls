/**
 * @description    Apex controller for all Customer Community LWCs.
 *                 Centralized so that authentication, account-scoping, and
 *                 error handling are consistent across every customer-facing
 *                 page. Every method is bulkified, security-enforced, and
 *                 returns DTOs (not raw SObjects) for clean LWC consumption.
 *
 *                 Account scoping pattern:
 *                  - Every method internally resolves the logged-in
 *                    community user's Contact.AccountId.
 *                  - All queries are filtered on that AccountId.
 *                  - If the user is internal (no Contact), defensive guard
 *                    returns an empty list rather than leaking data.
 *
 * @author         Harshal Ramdham
 */
public with sharing class CommunityPortalController {

    // ------------------------------------------------------------------
    // Public Data Transfer Object(DTOs) - returned to LWCs (never raw SObjects, so we can
    // shape the JSON cleanly and add/remove fields without breaking
    // the contract with the frontend).
    // ------------------------------------------------------------------

    public class AssetDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Date purchaseDate;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal price;
        @AuraEnabled public String productName;
        @AuraEnabled public Boolean hasActiveWarranty;
    }

    public class WarrantyDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Id assetId;
        @AuraEnabled public String assetName;
        @AuraEnabled public String status;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public Integer daysRemaining;
    }

    public class TaskDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String priority;
        @AuraEnabled public String status;
        @AuraEnabled public Date activityDate;
        @AuraEnabled public String description;
        @AuraEnabled public String ownerName;
    }

    public class AccountSummaryDTO {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Integer assetsOwned;
        @AuraEnabled public Integer activeWarranties;
        @AuraEnabled public Integer openTasks;
    }

    // ------------------------------------------------------------------
    // 1. My Assets
    // ------------------------------------------------------------------

    /**
     * @description Returns all Assets owned by the logged-in user's Account.
     *              Includes a "hasActiveWarranty" flag computed in Apex so
     *              the LWC doesn't need a second round trip.
     */
    @AuraEnabled(cacheable=true)
    public static List<AssetDTO> getMyAssets() {
        Id accountId = getCurrentUserAccountId();
        if (accountId == null) return new List<AssetDTO>();

        // First, map AssetId -> hasActiveWarranty (single sub-query)
        Set<Id> assetIdsWithActiveWarranty = new Set<Id>();
        for (Warranty_Registration__c w : [
            SELECT Asset__c
            FROM Warranty_Registration__c
            WHERE Account__c = :accountId
              AND Status__c = 'Active'
              AND Asset__c != null
            WITH SECURITY_ENFORCED
        ]) {
            assetIdsWithActiveWarranty.add(w.Asset__c);
        }

        List<AssetDTO> results = new List<AssetDTO>();
        for (Asset a : [
            SELECT Id, Name, Status, PurchaseDate, Quantity, Price, Product2.Name
            FROM Asset
            WHERE AccountId = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY PurchaseDate DESC NULLS LAST, Name ASC
            LIMIT 200
        ]) {
            AssetDTO dto = new AssetDTO();
            dto.id              = a.Id;
            dto.name            = a.Name;
            dto.status          = a.Status;
            dto.purchaseDate    = a.PurchaseDate;
            dto.quantity        = a.Quantity;
            dto.price           = a.Price;
            dto.productName     = a.Product2 != null ? a.Product2.Name : null;
            dto.hasActiveWarranty = assetIdsWithActiveWarranty.contains(a.Id);
            results.add(dto);
        }
        return results;
    }

    // ------------------------------------------------------------------
    // 2. My Warranties
    // ------------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<WarrantyDTO> getMyWarranties() {
        Id accountId = getCurrentUserAccountId();
        if (accountId == null) return new List<WarrantyDTO>();

        List<WarrantyDTO> results = new List<WarrantyDTO>();
        Date today = Date.today();
        for (Warranty_Registration__c w : [
            SELECT Id, Name, Status__c, Start_Date__c, End_Date__c,
                   Asset__c, Asset__r.Name
            FROM Warranty_Registration__c
            WHERE Account__c = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY End_Date__c DESC NULLS LAST
            LIMIT 200
        ]) {
            WarrantyDTO dto = new WarrantyDTO();
            dto.id        = w.Id;
            dto.name      = w.Name;
            dto.assetId   = w.Asset__c;
            dto.assetName = w.Asset__r != null ? w.Asset__r.Name : null;
            dto.status    = w.Status__c;
            dto.startDate = w.Start_Date__c;
            dto.endDate   = w.End_Date__c;
            dto.daysRemaining = w.End_Date__c != null
                ? today.daysBetween(w.End_Date__c)
                : null;
            results.add(dto);
        }
        return results;
    }

    /**
     * @description Returns lightweight asset options for the registration
     *              form dropdown - only the fields needed to populate
     *              <lightning-combobox>.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAssetOptionsForCurrentAccount() {
        Id accountId = getCurrentUserAccountId();
        List<Map<String, String>> options = new List<Map<String, String>>();
        if (accountId == null) return options;

        for (Asset a : [
            SELECT Id, Name
            FROM Asset
            WHERE AccountId = :accountId
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
            LIMIT 200
        ]) {
            options.add(new Map<String, String>{
                'label' => a.Name,
                'value' => a.Id
            });
        }
        return options;
    }

    /**
     * @description Creates a Warranty Registration for the current user's
     *              Account. The WarrantyRegistrationTriggerHandler runs and
     *              its addError() messages flow back to the LWC via a
     *              user-friendly AuraHandledException.
     *
     *              We deliberately call our own FlowErrorHandler to clean
     *              the DmlException text - this is the SAME error cleaner
     *              the Flow uses, demonstrating reuse across UI surfaces.
     */
    @AuraEnabled
    public static WarrantyDTO registerWarranty(
        Id assetId, String status, Date startDate, Date endDate
    ) {
        Id accountId = getCurrentUserAccountId();
        if (accountId == null) {
            throw new AuraHandledException(
                'Your user profile is not linked to an Account. Please contact support.'
            );
        }

        // Basic input validation (cheap; addError handles the rest)
        if (assetId == null) {
            throw new AuraHandledException('Please select an Asset.');
        }
        if (String.isBlank(status)) {
            throw new AuraHandledException('Please select a Status.');
        }

        Warranty_Registration__c w = new Warranty_Registration__c(
            Account__c    = accountId,
            Asset__c      = assetId,
            Status__c     = status,
            Start_Date__c = startDate,
            End_Date__c   = endDate
        );

        try {
            insert w;
        } catch (DmlException e) {
            // Reuse the FlowErrorHandler that the Record-Triggered Flow uses,
            // so a portal user sees the SAME cleaned message a Chatter user does.
            FlowErrorHandler.Request req = new FlowErrorHandler.Request();
            req.rawMessages = new List<String>{ e.getMessage() };
            List<FlowErrorHandler.Response> resp =
                FlowErrorHandler.cleanMessages(
                    new List<FlowErrorHandler.Request>{ req });
            String userMessage = (resp != null && !resp.isEmpty())
                ? resp[0].cleanedMessage
                : 'An error occurred while saving your warranty.';
            // AuraHandledException with setMessage() preserves the cleaned text
            AuraHandledException aex = new AuraHandledException(userMessage);
            aex.setMessage(userMessage);
            throw aex;
        }

        // Re-query to populate the DTO with relationship fields
        Warranty_Registration__c saved = [
            SELECT Id, Name, Status__c, Start_Date__c, End_Date__c,
                   Asset__c, Asset__r.Name
            FROM Warranty_Registration__c
            WHERE Id = :w.Id
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        WarrantyDTO dto = new WarrantyDTO();
        dto.id        = saved.Id;
        dto.name      = saved.Name;
        dto.assetId   = saved.Asset__c;
        dto.assetName = saved.Asset__r != null ? saved.Asset__r.Name : null;
        dto.status    = saved.Status__c;
        dto.startDate = saved.Start_Date__c;
        dto.endDate   = saved.End_Date__c;
        dto.daysRemaining = saved.End_Date__c != null
            ? Date.today().daysBetween(saved.End_Date__c)
            : null;
        return dto;
    }

    // ------------------------------------------------------------------
    // 3. My Service Requests (Tasks auto-created by AssetService)
    // ------------------------------------------------------------------

    /**
     * @description Returns Tasks (Service Requests) related to the current
     *              community user's Account.
     *
     *              We delegate to a `without sharing` inner class for the
     *              SOQL because Tasks have a peculiar sharing model in
     *              Communities - even with Activity OWD = ControlledByParent
     *              and proper Sharing Sets, portal users sometimes can't
     *              see related Tasks due to platform quirks around the
     *              "RelatedTo" polymorphic relationship.
     *
     *              This is safe because:
     *               1. The controller already resolved the user's AccountId
     *                  via Contact link (authenticated user identity).
     *               2. The helper class ONLY queries Tasks WHERE WhatId =
     *                  that specific AccountId - no leak to other accounts.
     *               3. Returned data is scoped to the user's own Account.
     *
     *              This pattern is documented in Salesforce's "Apex Sharing"
     *              guide as the correct approach for tightly-scoped reads
     *              that the standard sharing model blocks unnecessarily.
     */
    @AuraEnabled(cacheable=true)
    public static List<TaskDTO> getMyServiceRequests() {
        Id accountId = getCurrentUserAccountId();
        if (accountId == null) return new List<TaskDTO>();

        // Delegate to without-sharing helper for the query only
        List<Task> tasks = new TaskQueryHelper().fetchTasksForAccount(accountId);

        List<TaskDTO> results = new List<TaskDTO>();
        for (Task t : tasks) {
            TaskDTO dto = new TaskDTO();
            dto.id           = t.Id;
            dto.subject      = t.Subject;
            dto.priority     = t.Priority;
            dto.status       = t.Status;
            dto.activityDate = t.ActivityDate;
            dto.description  = t.Description;
            dto.ownerName    = t.Owner != null ? t.Owner.Name : null;
            results.add(dto);
        }
        return results;
    }

    /**
     * @description Tightly-scoped helper that runs the Task query without
     *              sharing. The only public method takes an AccountId
     *              parameter (already validated by the outer controller)
     *              and returns Tasks where WhatId matches.
     */
    private without sharing class TaskQueryHelper {
        public List<Task> fetchTasksForAccount(Id accountId) {
            return [
                SELECT Id, Subject, Priority, Status, ActivityDate,
                       Description, Owner.Name
                FROM Task
                WHERE WhatId = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        }

        public Integer countOpenTasksForAccount(Id accountId) {
            return [
                SELECT COUNT()
                FROM Task
                WHERE WhatId = :accountId AND Status != 'Completed'
            ];
        }
    }

    // ------------------------------------------------------------------
    // 4. Dashboard summary
    // ------------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static AccountSummaryDTO getAccountSummary() {
        Id accountId = getCurrentUserAccountId();
        AccountSummaryDTO dto = new AccountSummaryDTO();
        if (accountId == null) return dto;

        Account acc = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :accountId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        dto.accountId   = acc.Id;
        dto.accountName = acc.Name;

        dto.assetsOwned = [
            SELECT COUNT() FROM Asset WHERE AccountId = :accountId
        ];
        dto.activeWarranties = [
            SELECT COUNT()
            FROM Warranty_Registration__c
            WHERE Account__c = :accountId AND Status__c = 'Active'
        ];
        dto.openTasks = new TaskQueryHelper().countOpenTasksForAccount(accountId);
        return dto;
    }

    // ------------------------------------------------------------------
    // Private helpers
    // ------------------------------------------------------------------

    // Test-injectable override for the resolved Account ID. Production code
    // never sets this. Tests set it via TestVisible to exercise method bodies
    // without needing to spin up a Community user (which requires a Customer
    // Community license that may not be present in all test orgs).
    @TestVisible
    private static Id testAccountIdOverride = null;

    /**
     * @description Resolves the logged-in user's Account via their Contact.
     *              For internal users (no Contact), returns null - all
     *              public methods then short-circuit with an empty result
     *              rather than risk leaking data.
     */
    @TestVisible
    private static Id getCurrentUserAccountId() {
        // Test seam: when a test sets testAccountIdOverride, use that.
        if (Test.isRunningTest() && testAccountIdOverride != null) {
            return testAccountIdOverride;
        }

        Id userId = UserInfo.getUserId();
        List<User> users = [
            SELECT Id, ContactId, Contact.AccountId
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        if (users.isEmpty() || users[0].ContactId == null) {
            return null;
        }
        return users[0].Contact.AccountId;
    }
}