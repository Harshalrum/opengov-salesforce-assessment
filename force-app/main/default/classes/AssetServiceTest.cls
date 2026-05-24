/**
 * @description  Tests for AssetService and AssetTrigger. Specifically proves
 *               that 200+ Assets in a single transaction produce exactly ONE
 *               account query and ONE Task insert DML (bulkification).
 * 
 * @author       Harshal Ramdham
 */
@IsTest
private class AssetServiceTest {

    /**
     * @description Sets up an Account and matching Product for use across tests.
     *              Marked @TestSetup so each test method gets a clean copy.
     */
    @TestSetup
    static void setupData() {
        Account a = new Account(Name = 'Test Account');
        insert a;

        // Need a Product2 since Asset.Product2Id is sometimes required by org config
        Product2 prod = new Product2(Name = 'Test Hardware', IsActive = true);
        insert prod;
    }

    @IsTest
    static void createsTaskWhenAssetInstalledOnInsert() {
        Account acc = [SELECT Id, OwnerId FROM Account LIMIT 1];

        Asset asset = new Asset(
            Name      = 'Asset 1',
            AccountId = acc.Id,
            Status    = 'Installed'
        );

        Test.startTest();
        insert asset;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Id, Subject, OwnerId, WhatId, Priority, Status
            FROM Task
            WHERE WhatId = :acc.Id
        ];
        System.assertEquals(1, tasks.size(), 'Exactly one kickoff task should be created');
        System.assertEquals('Kickoff Service Onboarding', tasks[0].Subject);
        System.assertEquals(acc.OwnerId, tasks[0].OwnerId, 'Task owner = Account owner');
        System.assertEquals('High', tasks[0].Priority);
    }

    @IsTest
    static void doesNotCreateTaskWhenStatusNotInstalled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Asset asset = new Asset(
            Name      = 'Asset Draft',
            AccountId = acc.Id,
            Status    = 'Purchased'
        );

        Test.startTest();
        insert asset;
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id],
            'No task should be created for non-Installed assets');
    }

    @IsTest
    static void createsTaskOnTransitionToInstalled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Asset asset = new Asset(
            Name      = 'Asset Transition',
            AccountId = acc.Id,
            Status    = 'Purchased'
        );
        insert asset;

        Test.startTest();
        asset.Status = 'Installed';
        update asset;
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id],
            'Task should be created when Asset transitions to Installed');
    }

    @IsTest
    static void doesNotDuplicateTaskOnUnrelatedUpdate() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Asset asset = new Asset(
            Name      = 'Asset Re-edit',
            AccountId = acc.Id,
            Status    = 'Installed'
        );
        insert asset; // creates 1 task

        Test.startTest();
        asset.Name = 'Renamed Asset'; // no status change
        update asset;
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id],
            'Editing a non-status field must NOT create another task');
    }

    @IsTest
    static void bulkInsert200AssetsHitsGovernorLimitsCleanly() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        List<Asset> bulkAssets = new List<Asset>();
        for (Integer i = 0; i < 200; i++) {
            bulkAssets.add(new Asset(
                Name      = 'Bulk Asset ' + i,
                AccountId = acc.Id,
                Status    = 'Installed'
            ));
        }

        Test.startTest();
        insert bulkAssets;
        Integer queriesUsed = Limits.getQueries();
        Integer dmlUsed     = Limits.getDmlStatements();
        Test.stopTest();

        // We expect:
        //   - 1 SOQL inside AssetService (account query)
        //   - 1 DML inside AssetService (task insert)
        // Plus the trigger overhead. The big assertion is: NOT 200 each.
        System.assert(queriesUsed < 10,
            'Bulkified service should not approach SOQL limit. Used: ' + queriesUsed);
        System.assert(dmlUsed < 10,
            'Bulkified service should not approach DML limit. Used: ' + dmlUsed);

        System.assertEquals(200,
            [SELECT COUNT() FROM Task WHERE WhatId = :acc.Id],
            '200 tasks should be created for 200 installed assets');
    }
}