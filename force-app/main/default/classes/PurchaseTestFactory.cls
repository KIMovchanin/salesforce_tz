@IsTest
public class PurchaseTestFactory {
  public static Account createAccount(String label) {
    Account account = new Account(Name = 'Test Account ' + label);
    Database.insert(account, AccessLevel.SYSTEM_MODE);
    return account;
  }

  public static Item__c itemRecord(
    String name,
    String description,
    String type,
    String family,
    Decimal price,
    Decimal availableQuantity
  ) {
    return new Item__c(
      Name = name,
      Description__c = description,
      Type__c = type,
      Family__c = family,
      Price__c = price,
      AvailableQuantity__c = availableQuantity
    );
  }

  public static Item__c createItem(
    String name,
    String description,
    String type,
    String family,
    Decimal price,
    Decimal availableQuantity
  ) {
    Item__c item = itemRecord(
      name,
      description,
      type,
      family,
      price,
      availableQuantity
    );
    Database.insert(item, AccessLevel.SYSTEM_MODE);
    return item;
  }

  public static Purchase__c createPurchase(Account account, String label) {
    Purchase__c purchase = new Purchase__c(
      Name = 'Test Purchase ' + label,
      ClientId__c = account.Id
    );
    Database.insert(purchase, AccessLevel.SYSTEM_MODE);
    return purchase;
  }

  public static PurchaseLine__c lineRecord(
    Purchase__c purchase,
    Item__c item,
    Decimal amount,
    Decimal unitCost
  ) {
    return new PurchaseLine__c(
      PurchaseId__c = purchase.Id,
      ItemId__c = item.Id,
      Amount__c = amount,
      UnitCost__c = unitCost
    );
  }

  public static CartLineInput cartLine(Id itemId, Decimal quantity) {
    CartLineInput line = new CartLineInput();
    line.itemId = itemId;
    line.quantity = quantity;
    return line;
  }

  public static User createUser(Boolean isManager, String label) {
    String unique = (String.valueOf(Datetime.now().getTime()) +
      String.valueOf(Crypto.getRandomInteger()))
      .replace('-', 'n');
    User user = new User(
      Alias = isManager ? 'mgrtest' : 'usrtest',
      Email = 'user.' + unique + '@example.com',
      EmailEncodingKey = 'UTF-8',
      IsManager__c = isManager,
      LanguageLocaleKey = 'en_US',
      LastName = 'Purchase Tool ' + label,
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'user.' + unique + '@example.com'
    );
    Database.insert(user, AccessLevel.SYSTEM_MODE);
    return user;
  }

  public static void assignPermissionSets(
    Id userId,
    Set<String> permissionSetNames
  ) {
    if (permissionSetNames == null || permissionSetNames.isEmpty()) {
      return;
    }

    List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
    for (PermissionSet permission : [
      SELECT Id
      FROM PermissionSet
      WHERE Name IN :permissionSetNames
      WITH SYSTEM_MODE
    ]) {
      assignments.add(
        new PermissionSetAssignment(
          AssigneeId = userId,
          PermissionSetId = permission.Id
        )
      );
    }

    System.Assert.areEqual(
      permissionSetNames.size(),
      assignments.size(),
      'Every requested permission set must exist.'
    );
    Database.insert(assignments, AccessLevel.SYSTEM_MODE);
  }

  public static String repeat(String value, Integer count) {
    List<String> values = new List<String>();
    for (Integer index = 0; index < count; index++) {
      values.add(value);
    }
    return String.join(values, '');
  }
}
