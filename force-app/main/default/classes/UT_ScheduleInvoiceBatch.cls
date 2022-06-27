public class UT_ScheduleInvoiceBatch implements Schedulable {

	public void execute(SchedulableContext sc)
    {
        UT_BatchTrainingInvoice sendInvoiceBatch = new UT_BatchTrainingInvoice();
        Database.executeBatch(sendInvoiceBatch);
    }

}