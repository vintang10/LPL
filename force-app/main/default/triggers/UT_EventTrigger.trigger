trigger UT_EventTrigger on Event (after update, after insert, after delete) {

    if (Trigger.isUpdate)
        UT_EventTriggerHandler.afterUpdate(Trigger.New, Trigger.Old);

    if (Trigger.isInsert)
        UT_EventTriggerHandler.afterInsert(Trigger.New);
    
    if (Trigger.isDelete)
        UT_EventTriggerHandler.afterDelete(Trigger.Old);

}