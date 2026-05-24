/**
 * @description    Trigger Handler for the Asset object. Extends the base
 *                 TriggerHandler abstract class and delegates ALL business
 *                 logic to the AssetService.
 *
 *                 Why this pattern?
 *                  - The trigger file itself stays a 3-line dispatcher.
 *                  - This handler stays focused on context routing only.
 *                  - The Service class is the only place that performs DML
 *                    or queries, making it reusable from REST APIs, Flows,
 *                    batch jobs, etc.
 *
 * @author         Harshal Ramdham
 */
public with sharing class AssetTriggerHandler extends TriggerHandler {

    protected override void afterInsert() {
        // Cast Trigger.new to typed list so we get compile-time safety
        AssetService.handleAfterInsert((List<Asset>) Trigger.new);
    }

    protected override void afterUpdate() {
        AssetService.handleAfterUpdate((List<Asset>) Trigger.new,(Map<Id, Asset>) Trigger.oldMap);
    }
}