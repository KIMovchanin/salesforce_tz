public with sharing class InventoryNotificationEmailAction {
  @TestVisible
  private static String templateDeveloperName = 'Out_of_Stock_Alert';

  @InvocableMethod(label='Send Out of Stock Email')
  public static List<Result> send(List<Request> requests) {
    List<Result> results = new List<Result>();
    if (requests == null || requests.isEmpty()) {
      return results;
    }

    Id templateId = findTemplateId();
    List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
    List<Integer> messageResultIndexes = new List<Integer>();
    for (Request request : requests) {
      PreparedEmail preparedEmail = prepareOne(request, templateId);
      results.add(preparedEmail.result);
      if (preparedEmail.message != null) {
        messages.add(preparedEmail.message);
        messageResultIndexes.add(results.size() - 1);
      }
    }
    sendPrepared(messages, messageResultIndexes, results);
    return results;
  }

  private static PreparedEmail prepareOne(Request request, Id templateId) {
    PreparedEmail preparedEmail = new PreparedEmail();
    preparedEmail.result = new Result();
    if (
      request == null ||
      request.itemId == null ||
      String.isBlank(request.recipientEmail)
    ) {
      preparedEmail.result.sent = false;
      preparedEmail.result.message = 'Recipient email or item is missing.';
      return preparedEmail;
    }
    if (templateId == null) {
      preparedEmail.result.sent = false;
      preparedEmail.result.message = 'Out of stock email template is unavailable.';
      return preparedEmail;
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
      preparedEmail.message = message;
    } catch (Exception caughtError) {
      preparedEmail.result.sent = false;
      preparedEmail.result.message = 'The inventory email could not be sent.';
    }
    return preparedEmail;
  }

  private static void sendPrepared(
    List<Messaging.SingleEmailMessage> messages,
    List<Integer> messageResultIndexes,
    List<Result> results
  ) {
    if (messages.isEmpty()) {
      return;
    }

    try {
      List<Messaging.SendEmailResult> sendResults = Messaging.sendEmail(
        messages,
        false
      );
      for (Integer index = 0; index < messages.size(); index++) {
        Result result = results[messageResultIndexes[index]];
        result.sent = sendResults[index].isSuccess();
        result.message = result.sent
          ? null
          : 'Salesforce rejected the inventory email.';
      }
    } catch (Exception caughtError) {
      for (Integer resultIndex : messageResultIndexes) {
        results[resultIndex].sent = false;
        results[resultIndex].message = 'The inventory email could not be sent.';
      }
    }
  }

  private static Id findTemplateId() {
    List<EmailTemplate> templates = [
      SELECT Id
      FROM EmailTemplate
      WHERE DeveloperName = :templateDeveloperName
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
    } catch (Exception caughtError) {
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

  private class PreparedEmail {
    Messaging.SingleEmailMessage message;
    Result result;
  }
}
