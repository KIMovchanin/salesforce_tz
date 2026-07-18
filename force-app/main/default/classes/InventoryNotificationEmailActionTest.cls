@IsTest
private class InventoryNotificationEmailActionTest {
  @TestSetup
  static void createEmailData() {
    PurchaseTestFactory.createAccount('Email');
    PurchaseTestFactory.createItem(
      'Email Test Item',
      'Item used to render inventory email tests',
      'Product',
      'Electronics',
      25,
      5
    );
  }

  @IsTest
  static void rejectsIncompleteRequestsWithoutSendingEmail() {
    Item__c item = emailItem();
    InventoryNotificationEmailAction.Request blankRequest = emailRequest(
      null,
      null,
      null
    );
    InventoryNotificationEmailAction.Request blankEmailRequest = emailRequest(
      item.Id,
      null,
      ' '
    );
    InventoryNotificationEmailAction.Request missingItemRequest = emailRequest(
      null,
      null,
      'inventory@example.com'
    );

    Test.startTest();
    List<InventoryNotificationEmailAction.Result> results = InventoryNotificationEmailAction.send(
      new List<InventoryNotificationEmailAction.Request>{
        null,
        blankRequest,
        blankEmailRequest,
        missingItemRequest
      }
    );
    Integer emailInvocations = Limits.getEmailInvocations();
    Test.stopTest();

    System.Assert.areEqual(4, results.size());
    for (InventoryNotificationEmailAction.Result result : results) {
      System.Assert.isFalse(result.sent);
      System.Assert.areEqual(
        'Recipient email or item is missing.',
        result.message
      );
    }
    System.Assert.areEqual(0, emailInvocations);
  }

  @IsTest
  static void reportsUnavailableTemplateForAValidRequest() {
    InventoryNotificationEmailAction.Request request = emailRequest(
      emailItem().Id,
      null,
      'inventory@example.com'
    );

    Test.startTest();
    InventoryNotificationEmailAction.Result result = InventoryNotificationEmailAction.send(
      new List<InventoryNotificationEmailAction.Request>{ request }
    )[0];
    Test.stopTest();

    System.Assert.isFalse(result.sent);
    System.Assert.areEqual(
      'Out of stock email template is unavailable.',
      result.message
    );
  }

  @IsTest
  static void rendersAndSendsForEverySupportedRecipientIdForm() {
    createTestTemplate();
    Item__c item = emailItem();
    Account account = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account Email'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    List<InventoryNotificationEmailAction.Request> requests = new List<InventoryNotificationEmailAction.Request>{
      emailRequest(item.Id, null, 'first@example.com'),
      emailRequest(item.Id, 'not-an-id', 'second@example.com'),
      emailRequest(item.Id, String.valueOf(account.Id), 'third@example.com'),
      emailRequest(
        item.Id,
        String.valueOf(UserInfo.getUserId()),
        'fourth@example.com'
      )
    };

    Test.startTest();
    List<InventoryNotificationEmailAction.Result> results = InventoryNotificationEmailAction.send(
      requests
    );
    Integer emailInvocations = Limits.getEmailInvocations();
    Test.stopTest();

    System.Assert.areEqual(4, results.size());
    for (InventoryNotificationEmailAction.Result result : results) {
      System.Assert.isTrue(result.sent);
      System.Assert.isNull(result.message);
    }
    System.Assert.areEqual(1, emailInvocations);
  }

  @IsTest
  static void outOfStockFlowSendsEmailOnTheZeroQuantityTransition() {
    createTestTemplate();
    Database.insert(
      new Inventory_Notification_Settings__c(
        SetupOwnerId = UserInfo.getOrganizationId(),
        Recipient_Email__c = 'inventory@example.com'
      ),
      AccessLevel.SYSTEM_MODE
    );
    Item__c item = emailItem();
    item.AvailableQuantity__c = 0;
    User currentUser = [
      SELECT Id
      FROM User
      WHERE Id = :UserInfo.getUserId()
      WITH SYSTEM_MODE
    ];

    Test.startTest();
    System.runAs(currentUser) {
      Database.update(item, AccessLevel.SYSTEM_MODE);
    }
    Integer emailInvocations = Limits.getEmailInvocations();
    Test.stopTest();

    System.Assert.areEqual(1, emailInvocations);
    System.Assert.areEqual(
      Decimal.valueOf('0'),
      [
        SELECT AvailableQuantity__c
        FROM Item__c
        WHERE Id = :item.Id
        WITH SYSTEM_MODE
      ]
      .AvailableQuantity__c
    );
  }

  @IsTest
  static void invalidBellRecipientFallsBackToEmailWithoutBlockingStock() {
    createTestTemplate();
    Database.insert(
      new Inventory_Notification_Settings__c(
        SetupOwnerId = UserInfo.getOrganizationId(),
        Recipient_User__c = 'INVALIDUSERID00000',
        Recipient_Email__c = 'inventory@example.com'
      ),
      AccessLevel.SYSTEM_MODE
    );
    Item__c item = emailItem();
    item.AvailableQuantity__c = 0;

    Test.startTest();
    Database.update(item, AccessLevel.SYSTEM_MODE);
    Integer emailInvocations = Limits.getEmailInvocations();
    Test.stopTest();

    System.Assert.areEqual(1, emailInvocations);
    System.Assert.areEqual(
      Decimal.valueOf('0'),
      [
        SELECT AvailableQuantity__c
        FROM Item__c
        WHERE Id = :item.Id
        WITH SYSTEM_MODE
      ]
      .AvailableQuantity__c
    );
  }

  private static Item__c emailItem() {
    return [
      SELECT Id
      FROM Item__c
      WHERE Name = 'Email Test Item'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static InventoryNotificationEmailAction.Request emailRequest(
    Id itemId,
    String recipientUserId,
    String recipientEmail
  ) {
    InventoryNotificationEmailAction.Request request = new InventoryNotificationEmailAction.Request();
    request.itemId = itemId;
    request.recipientUserId = recipientUserId;
    request.recipientEmail = recipientEmail;
    return request;
  }

  private static void createTestTemplate() {
    EmailTemplate template = new EmailTemplate(
      Body = 'An inventory item is out of stock.',
      DeveloperName = 'Out_of_Stock_Alert',
      Encoding = 'UTF-8',
      FolderId = UserInfo.getUserId(),
      IsActive = true,
      Name = 'Out of Stock Alert Test',
      Subject = 'Out of Stock Alert',
      TemplateType = 'text'
    );
    Database.insert(template, AccessLevel.SYSTEM_MODE);
  }
}
