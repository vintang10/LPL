public class UT_BatchTrainingInvoice implements Database.Batchable<sObject>, Database.Stateful {

    public Integer emailsSent = 0;
    public List<Id> globalContactIds = new List<Id>();

	public Database.QueryLocator start(Database.BatchableContext bc)
    {
        String query = 'SELECT Id, UT_Attendee__c, UT_Start_Date_Time__c FROM UT_Simple_Invoice__c WHERE UT_Start_Date_Time__c > TODAY';
        return Database.getQueryLocator(query);
    }
 
    public void execute(Database.BatchableContext bc, List<UT_Simple_Invoice__c> invoiceList)
    {
        // get date 2 days from today
        List<Id> eventsInTwoDays = new List<Id>();
        DateTime twoDaysDateTime = DateTime.now() + 2;
        Date twoDaysFromNowDate = Date.newinstance(
            twoDaysDateTime.year(),
            twoDaysDateTime.month(),
            twoDaysDateTime.day()
        );

        List<UT_Simple_Invoice__c> invoicesToEmail = new List<UT_Simple_Invoice__c>();

        for(UT_Simple_Invoice__c futureEvent : invoiceList)
        {
            Date furtureEventDate = Date.newinstance(
                futureEvent.UT_Start_Date_Time__c.year(),
                futureEvent.UT_Start_Date_Time__c.month(),
                futureEvent.UT_Start_Date_Time__c.day()
            );
            if (furtureEventDate.isSameDay(twoDaysFromNowDate)) {
                invoicesToEmail.add(futureEvent);
            }         
        }
        
        EmailTemplate template = [SELECT Id, Subject, Body FROM EmailTemplate WHERE DeveloperName = 'UT_Invoice_for_Training_Class'];
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (UT_Simple_Invoice__c invoice : invoicesToEmail) {
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(invoice.UT_Attendee__c);
            mail.setTemplateId(template.Id);
            mail.setWhatId(invoice.Id); // for merge fields of email template
            globalContactIds.add(invoice.UT_Attendee__c);
            
            PageReference pdf = Page.UT_AttachmentPDF;
            pdf.getParameters().put('id', invoice.Id); // for merge fields of invoice attachment
            pdf.setRedirect(true);
            
            Blob b = pdf.getContent();
            
            // create email attachment
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName('Training Invoice.pdf');
            efa.setBody(b);
            
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] {efa});
            
            emails.add(mail);
            emailsSent++;
        }

        Messaging.sendEmail(emails);
    } // end of execute batch

    public void finish(Database.BatchableContext bc)
    {
        System.debug('Emails sent: ' + emailsSent);
        System.debug('contacts receving mail: ' + globalContactIds);
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        System.debug('Job details: ' + job);
    }

}