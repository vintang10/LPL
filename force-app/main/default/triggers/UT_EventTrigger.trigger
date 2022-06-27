trigger UT_EventTrigger on Event (after update, after insert) {

    if (Trigger.isUpdate)
        UT_EventTriggerHandler.afterUpdate(Trigger.New);

    if (Trigger.isInsert)
        UT_EventTriggerHandler.afterInsert(Trigger.New);

}