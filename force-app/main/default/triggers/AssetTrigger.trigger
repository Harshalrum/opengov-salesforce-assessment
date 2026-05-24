/**
 * @description  Single dispatcher trigger on Asset. All logic lives in
 *               AssetTriggerHandler / AssetService. This file should
 *               never grow - one trigger per object is the rule.
 */
trigger AssetTrigger on Asset (
    before insert, before update, before delete,
    after insert,  after update,  after delete, after undelete
) {
    new AssetTriggerHandler().run();
}