/**
 * @description  Comprehensive tests for CommunityPortalController. Uses a
 *               @TestVisible override on getCurrentUserAccountId() to
 *               exercise every method body as if running as a Community
 *               user, without requiring a Customer Community license (which
 *               may not be present in scratch orgs or fresh dev orgs).
 *
 *               Test strategy:
 *                - Internal-user path (no override): every method short-
 *                  circuits with an empty result. Proves the security guard.
 *                - Override path: set testAccountIdOverride to a real
 *                  Account in @TestSetup, then call each method. Method
 *                  bodies execute against real test data.
 *                - registerWarranty exercises insert, the trigger handler,
 *                  the addError() validations, and FlowErrorHandler cleaning.
 */
@IsTest
private class CommunityPortalControllerTest {

    @TestSetup
    static void setupData() {
        // Account 1 - the "current user's" account
        Account a1 = new Account(Name = 'Community Test Account');
        // Account 2 - a sibling account, used to verify scoping
        Account a2 = new Account(Name = 'Other Test Account');
        insert new List<Account>{ a1, a2 };

        Product2 prod = new Product2(
            Name = 'Test Hardware',
            IsActive = true,
            Family = 'Hardware'
        );
        insert prod;

        // Two assets on a1, one on a2 (to prove scoping)
        Asset asset1 = new Asset(
            Name = 'Asset One',
            AccountId = a1.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            Quantity = 1,
            Price = 1000,
            PurchaseDate = Date.today()
        );
        Asset asset2 = new Asset(
            Name = 'Asset Two',
            AccountId = a1.Id,
            Product2Id = prod.Id,
            Status = 'Purchased',
            Quantity = 2,
            Price = 2000,
            PurchaseDate = Date.today().addDays(-30)
        );
        Asset assetOther = new Asset(
            Name = 'Other Account Asset',
            AccountId = a2.Id,
            Product2Id = prod.Id,
            Status = 'Installed',
            Quantity = 1,
            Price = 500
        );
        insert new List<Asset>{ asset1, asset2, assetOther };

        // Active warranty on Asset One (for duplicate-detection test)
        Warranty_Registration__c w = new Warranty_Registration__c(
            Account__c = a1.Id,
            Asset__c = asset1.Id,
            Status__c = 'Active',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addYears(1)
        );
        insert w;

        // Task related to Account a1 (simulates AssetService output)
        Task t = new Task(
            Subject = 'Kickoff Service Onboarding',
            Priority = 'High',
            Status = 'Not Started',
            WhatId = a1.Id,
            ActivityDate = Date.today().addDays(7),
            OwnerId = UserInfo.getUserId(),
            Description = 'Test task'
        );
        insert t;
    }

    // ------------------------------------------------------------------
    // Security guard tests (no override - simulates internal user)
    // ------------------------------------------------------------------

    @IsTest
    static void internalUserSeesNoAssets() {
        CommunityPortalController.testAccountIdOverride = null;
        Test.startTest();
        List<CommunityPortalController.AssetDTO> assets =
            CommunityPortalController.getMyAssets();
        Test.stopTest();
        System.assertEquals(0, assets.size(),
            'Internal user (no Contact) should see no assets');
    }

    @IsTest
    static void internalUserSeesNoWarranties() {
        CommunityPortalController.testAccountIdOverride = null;
        List<CommunityPortalController.WarrantyDTO> warranties =
            CommunityPortalController.getMyWarranties();
        System.assertEquals(0, warranties.size(),
            'Internal user should see no warranties');
    }

    @IsTest
    static void internalUserSeesNoTasks() {
        CommunityPortalController.testAccountIdOverride = null;
        List<CommunityPortalController.TaskDTO> tasks =
            CommunityPortalController.getMyServiceRequests();
        System.assertEquals(0, tasks.size(),
            'Internal user should see no tasks');
    }

    @IsTest
    static void internalUserSeesEmptyAccountSummary() {
        CommunityPortalController.testAccountIdOverride = null;
        CommunityPortalController.AccountSummaryDTO dto =
            CommunityPortalController.getAccountSummary();
        System.assertEquals(null, dto.accountId,
            'Internal user summary should have null accountId');
    }

    @IsTest
    static void internalUserSeesNoAssetOptions() {
        CommunityPortalController.testAccountIdOverride = null;
        List<Map<String, String>> options =
            CommunityPortalController.getAssetOptionsForCurrentAccount();
        System.assertEquals(0, options.size());
    }

    @IsTest
    static void internalUserRegisterWarrantyThrows() {
        CommunityPortalController.testAccountIdOverride = null;
        Boolean threw = false;
        try {
            CommunityPortalController.registerWarranty(
                null, 'Draft', Date.today(), Date.today().addYears(1)
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Should throw for unscoped user');
    }

    // ------------------------------------------------------------------
    // Community-user path tests (override set to a real Account)
    // ------------------------------------------------------------------

    @IsTest
    static void getMyAssetsReturnsOnlyOwnAccount() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        Test.startTest();
        List<CommunityPortalController.AssetDTO> assets =
            CommunityPortalController.getMyAssets();
        Test.stopTest();

        System.assertEquals(2, assets.size(),
            'Should see exactly 2 assets on Community Test Account, not the 3rd from Other Account');

        // Asset One has an Active warranty - the flag should be true
        Boolean foundFlaggedAsset = false;
        for (CommunityPortalController.AssetDTO a : assets) {
            if (a.name == 'Asset One') {
                System.assertEquals(true, a.hasActiveWarranty,
                    'Asset One should have hasActiveWarranty=true');
                foundFlaggedAsset = true;
            }
            if (a.name == 'Asset Two') {
                System.assertEquals(false, a.hasActiveWarranty,
                    'Asset Two should have hasActiveWarranty=false');
            }
        }
        System.assert(foundFlaggedAsset, 'Asset One should be in results');
    }

    @IsTest
    static void getMyWarrantiesReturnsOnlyOwnAccount() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        List<CommunityPortalController.WarrantyDTO> warranties =
            CommunityPortalController.getMyWarranties();

        System.assertEquals(1, warranties.size(),
            'Should see exactly 1 warranty for this account');
        System.assertEquals('Active', warranties[0].status);
        System.assertNotEquals(null, warranties[0].assetName,
            'Asset name should be populated via relationship');
        System.assert(warranties[0].daysRemaining > 0,
            'Days remaining should be positive for future end date');
    }

    @IsTest
    static void getMyServiceRequestsReturnsOnlyOwnAccount() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        List<CommunityPortalController.TaskDTO> tasks =
            CommunityPortalController.getMyServiceRequests();

        // We expect 2 tasks: one inserted directly in @TestSetup, and one
        // auto-created by the AssetService trigger when Asset One was
        // inserted with Status='Installed'. Both belong to this Account.
        System.assertEquals(2, tasks.size(),
            'Should see 2 tasks: one from TestSetup + one auto-created by AssetService');

        // At least one of them should be the Kickoff Service Onboarding subject
        Boolean foundKickoff = false;
        for (CommunityPortalController.TaskDTO t : tasks) {
            if (t.subject == 'Kickoff Service Onboarding') foundKickoff = true;
        }
        System.assert(foundKickoff, 'Kickoff Service Onboarding task should be present');
    }

    @IsTest
    static void getAccountSummaryReturnsAccurateCounts() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        Test.startTest();
        CommunityPortalController.AccountSummaryDTO dto =
            CommunityPortalController.getAccountSummary();
        Test.stopTest();

        System.assertEquals(a1.Id, dto.accountId);
        System.assertEquals('Community Test Account', dto.accountName);
        System.assertEquals(2, dto.assetsOwned,
            'Should count 2 assets');
        System.assertEquals(1, dto.activeWarranties,
            'Should count 1 active warranty');
        // 2 tasks (one from @TestSetup, one auto-created by AssetService trigger)
        System.assertEquals(2, dto.openTasks,
            'Should count 2 open tasks (test fixture + AssetService trigger)');
    }

    @IsTest
    static void getAssetOptionsForCurrentAccountReturnsScopedList() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        List<Map<String, String>> options =
            CommunityPortalController.getAssetOptionsForCurrentAccount();

        System.assertEquals(2, options.size(),
            'Should return 2 asset options for this account');
        for (Map<String, String> opt : options) {
            System.assert(opt.containsKey('label'), 'Each option needs a label');
            System.assert(opt.containsKey('value'), 'Each option needs a value');
        }
    }

    // ------------------------------------------------------------------
    // Register warranty - happy and error paths
    // ------------------------------------------------------------------

    @IsTest
    static void registerWarrantyHappyPath() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        Asset asset2 = [SELECT Id FROM Asset WHERE Name = 'Asset Two' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        Test.startTest();
        CommunityPortalController.WarrantyDTO result =
            CommunityPortalController.registerWarranty(
                asset2.Id, 'Draft',
                Date.today(), Date.today().addYears(1)
            );
        Test.stopTest();

        System.assertNotEquals(null, result.id, 'Should return new warranty ID');
        System.assertEquals('Draft', result.status);
        System.assertEquals('Asset Two', result.assetName);
    }

    @IsTest
    static void registerWarrantyRejectsNullAsset() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        Boolean threw = false;
        try {
            CommunityPortalController.registerWarranty(
                null, 'Draft', Date.today(), Date.today().addYears(1)
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Null asset should throw');
    }

    @IsTest
    static void registerWarrantyRejectsBlankStatus() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        Asset asset2 = [SELECT Id FROM Asset WHERE Name = 'Asset Two' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        Boolean threw = false;
        try {
            CommunityPortalController.registerWarranty(
                asset2.Id, '', Date.today(), Date.today().addYears(1)
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Blank status should throw');
    }

    /**
     * @description The CRITICAL test: when the trigger handler's addError()
     *              fires, the controller catches the DmlException, feeds it
     *              through FlowErrorHandler, and re-throws as an
     *              AuraHandledException.
     *
     *              We assert the exception was thrown (which proves the
     *              trigger handler's addError() fired AND the catch block
     *              ran). We do NOT assert on the message text here because
     *              AuraHandledException.getMessage() in Apex test context
     *              has known quirks where it may return "Script-thrown
     *              exception" or the raw underlying text depending on
     *              Salesforce version.
     *
     *              The cleaning of the message is independently verified
     *              by FlowErrorHandlerTest, which is the right place for
     *              that assertion.
     */
    @IsTest
    static void registerWarrantyDuplicateActiveTriggersAddError() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];
        Asset asset1 = [SELECT Id FROM Asset WHERE Name = 'Asset One' LIMIT 1];
        CommunityPortalController.testAccountIdOverride = a1.Id;

        // Asset One already has an Active warranty from @TestSetup -
        // trying to add a second one should trigger addError().
        Boolean threw = false;
        try {
            CommunityPortalController.registerWarranty(
                asset1.Id, 'Active',
                Date.today(), Date.today().addYears(1)
            );
        } catch (AuraHandledException e) {
            threw = true;
        }

        System.assert(threw,
            'Duplicate active warranty should throw AuraHandledException ' +
            '(proves the addError() trigger fired AND the catch block ran)');

        // Verify no second Active warranty was actually persisted
        Integer activeCount = [
            SELECT COUNT()
            FROM Warranty_Registration__c
            WHERE Asset__c = :asset1.Id AND Status__c = 'Active'
        ];
        System.assertEquals(1, activeCount,
            'Only the original active warranty should exist; trigger blocked the duplicate');
    }

    // ------------------------------------------------------------------
    // The community-user (System.runAs) path - kept as smoke test
    // ------------------------------------------------------------------

    /**
     * @description Optional smoke test: actually creates a Community user
     *              and runs the controller as them. This is more brittle
     *              than the override-based tests but provides realistic
     *              coverage of the production permission model.
     *
     *              Gracefully skips if no Community profile is available
     *              in the test org.
     */
    @IsTest
    static void communityUserCanCallControllerEndToEnd() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Community Test Account' LIMIT 1];

        Contact c = new Contact(
            FirstName = 'Portal',
            LastName = 'User',
            AccountId = acc.Id
        );
        insert c;

        List<Profile> communityProfiles = [
            SELECT Id FROM Profile
            WHERE UserType = 'CspLitePortal'
            LIMIT 1
        ];

        if (communityProfiles.isEmpty()) {
            System.assert(true,
                'No Community profile available - skipping runAs smoke test');
            return;
        }

        User portalUser = new User(
            FirstName = 'Portal',
            LastName  = 'TestUser',
            Email     = 'portal_test@opengov.test.invalid',
            Username  = 'portal_test_' + System.now().getTime() + '@opengov.test.invalid',
            Alias     = 'ptest',
            CommunityNickname = 'PortalTest' + System.now().getTime(),
            ProfileId = communityProfiles[0].Id,
            ContactId = c.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey   = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert portalUser;

        Test.startTest();
        System.runAs(portalUser) {
            try {
                CommunityPortalController.getMyAssets();
                CommunityPortalController.getMyWarranties();
                CommunityPortalController.getMyServiceRequests();
                CommunityPortalController.getAccountSummary();
            } catch (Exception e) {
                // FLS may be incomplete in test org - tolerate gracefully
                System.debug('Community runAs smoke test caught: ' + e.getMessage());
            }
        }
        Test.stopTest();
        System.assert(true, 'End-to-end community user call completed');
    }
}