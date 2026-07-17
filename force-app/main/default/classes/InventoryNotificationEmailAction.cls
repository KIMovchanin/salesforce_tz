public with sharing class InventoryNotificationEmailAction {
  private static final String TEMPLATE_DEVELOPER_NAME = 'Out_of_Stock_Alert';

  @InvocableMethod(label='Send Out of Stock Email')
  public static List<Result> send(List<Request> requests) {
    List<Result> results = new List<Result>();
    Id templateId = findTemplateId();
    for (Request request : requests) {
      results.add(sendOne(request, templateId));
    }
    return results;
  }

  private static Result sendOne(Request request, Id templateId) {
    Result result = new Result();
    if (
      request == null ||
      request.itemId == null ||
      String.isBlank(request.recipientEmail)
    ) {
      result.sent = false;
      result.message = 'Recipient email or item is missing.';
      return result;
    }
    if (templateId == null) {
      result.sent = false;
      result.message = 'Out of stock email template is unavailable.';
      return result;
    }

    try {
      Id renderingUserId = parseUserId(request.recipientUserId);
      Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(
        templateId,
        renderingUserId,
        request.itemId
      );
      Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
      message.setToAddresses(new List<String>{ request.recipientEmail.trim() });
      message.setSubject(rendered.getSubject());
      message.setPlainTextBody(rendered.getPlainTextBody());
      message.setHtmlBody(rendered.getHtmlBody());
      message.setSaveAsActivity(false);
      message.setUseSignature(false);
      Messaging.SendEmailResult sendResult = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ message }
      )[0];
      result.sent = sendResult.isSuccess();
      result.message = result.sent
        ? null
        : 'Salesforce rejected the inventory email.';
    } catch (Exception exception) {
      result.sent = false;
      result.message = 'The inventory email could not be sent.';
    }
    return result;
  }

  private static Id findTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE DeveloperName = :TEMPLATE_DEVELOPER_NAME
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return templates.isEmpty() ? null : templates[0].Id;
  }

  private static Id parseUserId(String userId) {
    if (String.isBlank(userId)) {
      return UserInfo.getUserId();
    }
    try {
      Id parsedId = (Id) userId.trim();
      return parsedId.getSObjectType() == User.SObjectType
        ? parsedId
        : UserInfo.getUserId();
    } catch (Exception exception) {
      return UserInfo.getUserId();
    }
  }

  public class Request {
    @InvocableVariable(required=true)
    public Id itemId;

    @InvocableVariable
    public String recipientUserId;

    @InvocableVariable(required=true)
    public String recipientEmail;
  }

  public class Result {
    @InvocableVariable
    public Boolean sent;

    @InvocableVariable
    public String message;
  }
}
