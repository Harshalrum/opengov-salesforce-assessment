/**
 * @description  Tests for WarrantyRegistrationTriggerHandler. Verifies the
 *               addError() complex validations fire as expected and that
 *               valid records save cleanly.
 * 
 * @author         Harshal Ramdham
 */
@IsTest
private class WarrantyRegistrationTriggerTest {

    @TestSetup
    static void setupData() {
        Account a1 = new Account(Name = 'Account A');
        Account a2 = new Account(Name = 'Account B');
        insert new List<Account>{ a1, a2 };

        // Asset belongs to Account A
        Asset assetA = new Asset(Name = 'Asset A', AccountId = a1.Id, Status = 'Purchased');
        insert assetA;
    }

    @IsTest
    static void allowsValidWarranty() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Account A' LIMIT 1];
        Asset assetA = [SELECT Id FROM Asset WHERE Name = 'Asset A' LIMIT 1];

        Warranty_Registration__c w = new Warranty_Registration__c(
            Account__c   = a1.Id,
            Asset__c     = assetA.Id,
            Status__c    = 'Draft',
            Start_Date__c= Date.today(),
            End_Date__c  = Date.today().addYears(1)
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(w, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Valid warranty should save without error');
    }

    @IsTest
    static void rejectsAssetFromDifferentAccount() {
        Account a2 = [SELECT Id FROM Account WHERE Name = 'Account B' LIMIT 1];
        Asset assetA = [SELECT Id FROM Asset WHERE Name = 'Asset A' LIMIT 1];

        // Account B tries to register a warranty on Asset A (which belongs to Account A)
        Warranty_Registration__c w = new Warranty_Registration__c(
            Account__c   = a2.Id,
            Asset__c     = assetA.Id,
            Status__c    = 'Draft',
            Start_Date__c= Date.today(),
            End_Date__c  = Date.today().addYears(1)
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(w, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Cross-account warranty must fail');
        System.assert(
            sr.getErrors()[0].getMessage().contains('different Account'),
            'Error message should mention different Account: ' + sr.getErrors()[0].getMessage()
        );
    }

    @IsTest
    static void rejectsDuplicateActiveWarranty() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Account A' LIMIT 1];
        Asset assetA = [SELECT Id FROM Asset WHERE Name = 'Asset A' LIMIT 1];

        // First active warranty - OK
        Warranty_Registration__c w1 = new Warranty_Registration__c(
            Account__c   = a1.Id,
            Asset__c     = assetA.Id,
            Status__c    = 'Active',
            Start_Date__c= Date.today(),
            End_Date__c  = Date.today().addYears(1)
        );
        insert w1;

        // Second active warranty on same asset - SHOULD FAIL
        Warranty_Registration__c w2 = new Warranty_Registration__c(
            Account__c   = a1.Id,
            Asset__c     = assetA.Id,
            Status__c    = 'Active',
            Start_Date__c= Date.today(),
            End_Date__c  = Date.today().addYears(2)
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(w2, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Duplicate active warranty must fail');
        System.assert(
            sr.getErrors()[0].getMessage().contains('Active Warranty Registration'),
            'Should mention existing Active warranty'
        );
    }

    @IsTest
    static void rejectsTwoActiveWarrantiesInSameBatch() {
        Account a1 = [SELECT Id FROM Account WHERE Name = 'Account A' LIMIT 1];
        Asset assetA = [SELECT Id FROM Asset WHERE Name = 'Asset A' LIMIT 1];

        Warranty_Registration__c w1 = new Warranty_Registration__c(
            Account__c = a1.Id, Asset__c = assetA.Id, Status__c = 'Active',
            Start_Date__c = Date.today(), End_Date__c = Date.today().addYears(1));
        Warranty_Registration__c w2 = new Warranty_Registration__c(
            Account__c = a1.Id, Asset__c = assetA.Id, Status__c = 'Active',
            Start_Date__c = Date.today(), End_Date__c = Date.today().addYears(2));

        Test.startTest();
        Database.SaveResult[] results =
            Database.insert(new List<Warranty_Registration__c>{ w1, w2 }, false);
        Test.stopTest();

        Boolean atLeastOneFailed = false;
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) atLeastOneFailed = true;
        }
        System.assert(atLeastOneFailed,
            'At least one warranty in the duplicate batch must fail');
    }
}