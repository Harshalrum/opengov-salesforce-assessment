/**
 * @description Single dispatcher trigger on Warranty_Registration__c.
 *              All logic is in WarrantyRegistrationTriggerHandler.
 */
trigger WarrantyRegistrationTrigger on Warranty_Registration__c (
    before insert, before update, before delete,
    after insert,  after update,  after delete, after undelete
) {
    new WarrantyRegistrationTriggerHandler().run();
}