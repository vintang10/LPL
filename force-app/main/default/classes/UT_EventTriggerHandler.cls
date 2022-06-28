public class UT_EventTriggerHandler {

    public static void afterInsert(List<Event> newEvents)
    {
        // mapping preparation
        Set<Id> eventIdList = new Set<Id>();
        Map<Id, Event> eventMap = new Map<Id, Event>();

        for (Event event : newEvents) {
            eventIdList.add(event.Id);
            eventMap.put(event.Id, event);
        }

        Set<Id> contactIdList = new Set<Id>();

        Map<Id, Event> contactIdToEventMap = new Map<Id, Event>();
        for (EventRelation eventRelation : [SELECT Relation.Id, EventId FROM EventRelation WHERE EventId IN :eventIdList AND isInvitee = true]) {
            String relationId = String.valueOf(eventRelation.Relation.Id);
            if (relationId.startsWith('003')) {
                contactIdList.add(eventRelation.Relation.Id);
                contactIdToEventMap.put(eventRelation.Relation.Id, eventMap.get(eventRelation.EventId));
            }
        }

        /**********************************/
        /* creates invoices for attendees */
        /**********************************/
        if (contactIdList.size() > 0) createInvoices(contactIdList, contactIdToEventMap);
    }

    public static void afterUpdate(List<Event> updatedEvents, List<Event> oldEvents)
    {
        updateRelatedInvoiceRecords(updatedEvents, oldEvents);
        addRemoveInvoicesHandler(updatedEvents);
    }

    public static void afterDelete(List<Event> deletedEvents)
    {
        Set<Id> deletedEventIdList = new Set<Id>();

        for (Event deletedEvent : deletedEvents) {
            deletedEventIdList.add(deletedEvent.Id);
        }

        List<UT_Simple_Invoice__c> relatedInvoicesToDelete = [
          SELECT Id FROM UT_Simple_Invoice__c WHERE UT_Related_Event_Id__c IN :deletedEventIdList
        ];
        
        if (relatedInvoicesToDelete.size() > 0) delete relatedInvoicesToDelete;
    }

    /***************************************************************************/
    /* method handles removing their invoice if attendee is removed from event */
    /***************************************************************************/
    private static List<UT_Simple_Invoice__c> getInvoicesToDelete(Set<EventRelation> newContactList, Set<UT_Simple_Invoice__c> oldContactList)
    {
        Set<Id> newContactIdList = new Set<Id>();
        for (EventRelation eventRelation : newContactList) {
            newContactIdList.add(eventRelation.Relation.Id);
        }

        List<UT_Simple_Invoice__c> invoicesToDelete = new List<UT_Simple_Invoice__c>();

        for (UT_Simple_Invoice__c previousAttendee : oldContactList) {
            if (!newContactIdList.contains(previousAttendee.UT_Attendee__c)) {
				invoicesToDelete.add(previousAttendee);
            }
        }
        return invoicesToDelete;
    }

    /**************************************************************************/
    /* method helps with adding new invoice if new attendee is added to event */
	/**************************************************************************/
    private static Set<EventRelation> getAttendeesForNewInvoices(Set<EventRelation> newContactList, Set<UT_Simple_Invoice__c> oldContactList)
    {
        Set<Id> oldContactIdList = new Set<Id>();
        for (UT_Simple_Invoice__c invoiceWithOldContact : oldContactList) {
            oldContactIdList.add(invoiceWithOldContact.UT_Attendee__c);
        }

        Set<EventRelation> newAttendeeList = new Set<EventRelation>();

        for (EventRelation newAttendee : newContactList) {
            if (!oldContactIdList.contains(newAttendee.Relation.Id)) {
				newAttendeeList.add(newAttendee);
            }
        }
        return newAttendeeList;
    }

    private static void createInvoices(Set<Id> newContactIdList, Map<Id, Event> contactIdToEventMap)
    {
        List<Contact> contactList = [
            SELECT Id, Email, Name, MailingStreet, MailingCity, MailingState, MailingPostalCode FROM Contact WHERE Id IN :newContactIdList
        ];

		List<UT_Simple_Invoice__c> invoicesToCreate = new List<UT_Simple_Invoice__c>();
        for (Contact contact : contactList) {
            Event relatedEvent = contactIdToEventMap.get(contact.Id);
            invoicesToCreate.add(
                new UT_Simple_Invoice__c(
                    UT_Attendee__c = contact.Id,
                    UT_Training_Received__c = relatedEvent.Type,
                    UT_Training_Date_Formatted__c = relatedEvent.StartDateTime.format(),
                    UT_Total_Amount_Due__c = relatedEvent.UT_Training_Fee__c,
                    UT_Related_Event_Id__c = relatedEvent.Id,
                    UT_Start_Date_Time__c = relatedEvent.StartDateTime
                )
            );
        }
        insert invoicesToCreate;
    }

    private static void updateRelatedInvoiceRecords(List<Event> updatedEvents, List<Event> oldEvents)
    {
        /*********************************************************************************************/
        /* here we will update related invoices to reflect the new event time, in bulk consideration */
        /*********************************************************************************************/
        List<Id> updatedStartDateTimeIdList = new List<Id>();
        Map<Id, Event> eventIdMap = new Map<Id, Event>();

        for (Integer i = 0; i < updatedEvents.size(); i++) {
            if (updatedEvents[i].StartDateTime != oldEvents[i].StartDateTime) {
                updatedStartDateTimeIdList.add(updatedEvents[i].Id);
                eventIdMap.put(updatedEvents[i].Id, updatedEvents[i]);
            }
        }

        List<UT_Simple_Invoice__c> invoicesToUpdateList = new List<UT_Simple_Invoice__c>();
        Map<Id, Event> invoiceIdToEvent = new Map<Id, Event>();

        for (UT_Simple_Invoice__c invoice : [
            SELECT Id, UT_Related_Event_Id__c FROM UT_Simple_Invoice__c WHERE UT_Related_Event_Id__c IN :updatedStartDateTimeIdList
        ]) {
            invoiceIdToEvent.put(invoice.Id, eventIdMap.get(invoice.UT_Related_Event_Id__c));
            invoicesToUpdateList.add(invoice);
        }

        for (UT_Simple_Invoice__c inoviceToUpdate : invoicesToUpdateList) {
            Event updatedEvent = invoiceIdToEvent.get(inoviceToUpdate.Id);
            inoviceToUpdate.UT_Start_Date_Time__c = updatedEvent.startDateTime;
            inoviceToUpdate.UT_Training_Date_Formatted__c = updatedEvent.startDateTime.format();
        }

        if (invoicesToUpdateList.size() > 0) update invoicesToUpdateList;
    }

    private static void addRemoveInvoicesHandler(List<Event> updatedEvents)
    {
        // mapping preparation to handle invoice creation and deletion
        Set<Id> updatedEventIdList = new Set<Id>();
        Map<Id, Event> eventMap = new Map<Id, Event>();

        for (Event event : updatedEvents) {
            updatedEventIdList.add(event.Id);
            eventMap.put(event.Id, event);
        }

        Set<EventRelation> recentContactList = new Set<EventRelation>();
        Set<UT_Simple_Invoice__c> oldContactList = new Set<UT_Simple_Invoice__c>();

        Map<Id, Event> contactIdToEventMap = new Map<Id, Event>();

        for (EventRelation eventRelation : [SELECT Relation.Id, EventId FROM EventRelation WHERE EventId IN :updatedEventIdList AND isInvitee = true]) {
            String relationId = String.valueOf(eventRelation.Relation.Id);
            if (relationId.startsWith('003')) {
                recentContactList.add(eventRelation);
                contactIdToEventMap.put(eventRelation.Relation.Id, eventMap.get(eventRelation.EventId));
            }
        }

        for (UT_Simple_Invoice__c invoice : [SELECT Id, UT_Attendee__c FROM UT_Simple_Invoice__c WHERE UT_Related_Event_Id__c IN :updatedEventIdList]) {
            oldContactList.add(invoice);
        }

        List<UT_Simple_Invoice__c> invoicesToDelete = getInvoicesToDelete(recentContactList, oldContactList);
        Set<EventRelation> newAttendees = getAttendeesForNewInvoices(recentContactList, oldContactList);

        Set<Id> newAttendeeIdList = new Set<Id>();
        for (EventRelation eventRelation : newAttendees) {
            newAttendeeIdList.add(eventRelation.Relation.Id);
        }

        /*********************************************/
        /* updating event deletes & creates invoices */
        /*********************************************/
        if (invoicesToDelete.size() > 0) delete invoicesToDelete;
        if (newAttendeeIdList.size() > 0) createInvoices(newAttendeeIdList, contactIdToEventMap);
    }
}