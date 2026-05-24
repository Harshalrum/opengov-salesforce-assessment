/**
 * @description    Abstract base class implementing the Trigger Handler pattern.
 *                 All concrete trigger handlers extend this class and override
 *                 the specific context methods they need.
 *
 *                 Benefits:
 *                  - Separates trigger logic from the Apex trigger file itself
 *                    (the trigger becomes a 3-line dispatcher).
 *                  - Provides re-entrancy / recursion control via a static flag.
 *                  - Standardized hook points (beforeInsert, afterUpdate, etc.).
 *                  - Easy to disable in tests or for specific bulk loads.
 *
 * @author         Harshal Ramdham
 * @date           2026
 */
public virtual class TriggerHandler {

    // Static flag used to prevent recursive trigger execution within the
    // same transaction. Service classes can call bypass()/clearBypass()
    // to disable specific handlers during bulk DML.
    private static Set<String> bypassedHandlers = new Set<String>();

    /**
     * @description Main entry point called from the Apex trigger.
     *              Routes execution to the correct context method.
     */
    public void run() {
        if (isBypassed()) {
            return;
        }

        if (Trigger.isBefore) {
            if (Trigger.isInsert)  beforeInsert();
            if (Trigger.isUpdate)  beforeUpdate();
            if (Trigger.isDelete)  beforeDelete();
        } else if (Trigger.isAfter) {
            if (Trigger.isInsert)  afterInsert();
            if (Trigger.isUpdate)  afterUpdate();
            if (Trigger.isDelete)  afterDelete();
            if (Trigger.isUndelete) afterUndelete();
        }
    }

    // ----- Hook methods. Subclasses override only what they need. -----
    protected virtual void beforeInsert()  {}
    protected virtual void beforeUpdate()  {}
    protected virtual void beforeDelete()  {}
    protected virtual void afterInsert()   {}
    protected virtual void afterUpdate()   {}
    protected virtual void afterDelete()   {}
    protected virtual void afterUndelete() {}

    // ----- Bypass controls (useful for data migrations / nested DML) -----
    public static void bypass(String handlerName)  { bypassedHandlers.add(handlerName); }
    public static void clearBypass(String handlerName) { bypassedHandlers.remove(handlerName); }
    public static void clearAllBypasses() { bypassedHandlers.clear(); }

    private Boolean isBypassed() {
        return bypassedHandlers.contains(getHandlerName());
    }

    private String getHandlerName() {
        return String.valueOf(this).split(':').get(0);
    }
}