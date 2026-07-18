@IsTest
private class PurchaseCheckoutServiceTest {
  @TestSetup
  static void createCheckoutData() {
    User checkoutUser = PurchaseTestFactory.createUser(false, 'Checkout User');
    PurchaseTestFactory.assignPermissionSets(
      checkoutUser.Id,
      new Set<String>{ 'Item_Purchase_User' }
    );
    System.runAs(checkoutUser) {
      PurchaseTestFactory.createAccount('Checkout');
      Database.insert(
        new List<Item__c>{
          PurchaseTestFactory.itemRecord(
            'Checkout Cable',
            'Cable used in checkout tests',
            'Accessory',
            'Electronics',
            19.95,
            20
          ),
          PurchaseTestFactory.itemRecord(
            'Checkout Desk',
            'Desk used in checkout tests',
            'Equipment',
            'Furniture',
            275.5,
            10
          )
        },
        AccessLevel.SYSTEM_MODE
      );
    }
  }

  @IsTest
  static void createsOnePurchaseWithMergedLinesAndServerPrices() {
    User checkoutUser = authorizedCheckoutUser();
    Account account = checkoutAccount();
    Item__c cable = checkoutItem('Checkout Cable');
    Item__c desk = checkoutItem('Checkout Desk');
    List<CartLineInput> cart = new List<CartLineInput>{
      PurchaseTestFactory.cartLine(cable.Id, 2),
      PurchaseTestFactory.cartLine(cable.Id, 3),
      PurchaseTestFactory.cartLine(desk.Id, 1)
    };

    Id purchaseId;
    System.runAs(checkoutUser) {
      Test.startTest();
      purchaseId = PurchaseToolController.checkout(account.Id, cart);
      Test.stopTest();
    }

    Purchase__c purchase = [
      SELECT Id, OwnerId, ClientId__c, TotalItems__c, GrandTotal__c
      FROM Purchase__c
      WHERE Id = :purchaseId
      WITH SYSTEM_MODE
    ];
    Map<Id, PurchaseLine__c> linesByItem = new Map<Id, PurchaseLine__c>();
    for (PurchaseLine__c line : [
      SELECT ItemId__c, Amount__c, UnitCost__c, LineTotal__c
      FROM PurchaseLine__c
      WHERE PurchaseId__c = :purchaseId
      WITH SYSTEM_MODE
    ]) {
      linesByItem.put(line.ItemId__c, line);
    }

    System.Assert.areEqual(account.Id, purchase.ClientId__c);
    System.Assert.areEqual(checkoutUser.Id, purchase.OwnerId);
    System.Assert.areEqual(Decimal.valueOf('6'), purchase.TotalItems__c);
    System.Assert.areEqual(Decimal.valueOf('375.25'), purchase.GrandTotal__c);
    System.Assert.areEqual(2, linesByItem.size());
    System.Assert.areEqual(
      Decimal.valueOf('5'),
      linesByItem.get(cable.Id).Amount__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('19.95'),
      linesByItem.get(cable.Id).UnitCost__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('99.75'),
      linesByItem.get(cable.Id).LineTotal__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('1'),
      linesByItem.get(desk.Id).Amount__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('275.50'),
      linesByItem.get(desk.Id).UnitCost__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('275.50'),
      linesByItem.get(desk.Id).LineTotal__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('15'),
      [
        SELECT AvailableQuantity__c
        FROM Item__c
        WHERE Id = :cable.Id
        WITH SYSTEM_MODE
      ]
      .AvailableQuantity__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('9'),
      [
        SELECT AvailableQuantity__c
        FROM Item__c
        WHERE Id = :desk.Id
        WITH SYSTEM_MODE
      ]
      .AvailableQuantity__c
    );
  }

  @IsTest
  static void rejectsMissingCartLinesAndReferences() {
    User checkoutUser = authorizedCheckoutUser();
    Account account = checkoutAccount();

    System.runAs(checkoutUser) {
      assertCheckoutFailure(
        account.Id,
        null,
        'Add at least one item to the cart.'
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>(),
        'Add at least one item to the cart.'
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{ null },
        'Every cart line must reference an item.'
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{ PurchaseTestFactory.cartLine(null, 1) },
        'Every cart line must reference an item.'
      );
    }
  }

  @IsTest
  static void rejectsInvalidQuantities() {
    User checkoutUser = authorizedCheckoutUser();
    Account account = checkoutAccount();
    Id itemId = checkoutItem('Checkout Cable').Id;
    String expectedMessage = 'Every cart quantity must be a positive whole number.';

    System.runAs(checkoutUser) {
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{ PurchaseTestFactory.cartLine(itemId, null) },
        expectedMessage
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{ PurchaseTestFactory.cartLine(itemId, 0) },
        expectedMessage
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{ PurchaseTestFactory.cartLine(itemId, -1) },
        expectedMessage
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{ PurchaseTestFactory.cartLine(itemId, 1.5) },
        expectedMessage
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{
          PurchaseTestFactory.cartLine(
            itemId,
            Decimal.valueOf('1000000000000000000')
          )
        },
        expectedMessage
      );
    }
  }

  @IsTest
  static void rejectsCartLimitsAndUnavailableRecords() {
    User checkoutUser = authorizedCheckoutUser();
    Account account = checkoutAccount();
    Item__c item = checkoutItem('Checkout Cable');
    List<CartLineInput> oversizedCart = new List<CartLineInput>();
    for (Integer index = 0; index < 101; index++) {
      oversizedCart.add(PurchaseTestFactory.cartLine(item.Id, 1));
    }
    Decimal maximumQuantity = Decimal.valueOf('999999999999999999');

    Item__c removedItem = PurchaseTestFactory.createItem(
      'Removed Item',
      null,
      'Product',
      'Other',
      10,
      3
    );
    Database.delete(removedItem, AccessLevel.SYSTEM_MODE);

    Account removedAccount = PurchaseTestFactory.createAccount('Removed');
    Database.delete(removedAccount, AccessLevel.SYSTEM_MODE);

    System.runAs(checkoutUser) {
      assertCheckoutFailure(
        account.Id,
        oversizedCart,
        'A cart cannot contain more than 100 lines.'
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{
          PurchaseTestFactory.cartLine(item.Id, maximumQuantity),
          PurchaseTestFactory.cartLine(item.Id, 1)
        },
        'Cart quantity is too large.'
      );
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{
          PurchaseTestFactory.cartLine(removedItem.Id, 1)
        },
        'One or more cart items are unavailable.'
      );
      assertCheckoutFailure(
        removedAccount.Id,
        new List<CartLineInput>{ PurchaseTestFactory.cartLine(item.Id, 1) },
        'The Account is unavailable or you do not have access to it.'
      );
    }
  }

  @IsTest
  static void rejectsMissingAccountThroughTheController() {
    User checkoutUser = authorizedCheckoutUser();
    Item__c item = checkoutItem('Checkout Cable');

    System.runAs(checkoutUser) {
      Test.startTest();
      try {
        PurchaseToolController.checkout(
          null,
          new List<CartLineInput>{ PurchaseTestFactory.cartLine(item.Id, 1) }
        );
        System.Assert.fail('Expected an AuraHandledException.');
      } catch (AuraHandledException caughtError) {
        System.Assert.areEqual(
          'Open the purchase tool from an Account record.',
          caughtError.getMessage()
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void rejectsInsufficientStockWithoutChangingAnyRecords() {
    User checkoutUser = authorizedCheckoutUser();
    Account account = checkoutAccount();
    Item__c cable = checkoutItem('Checkout Cable');
    Item__c desk = checkoutItem('Checkout Desk');

    System.runAs(checkoutUser) {
      Test.startTest();
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{
          PurchaseTestFactory.cartLine(cable.Id, 2),
          PurchaseTestFactory.cartLine(desk.Id, 11)
        },
        'Not enough stock is available for Checkout Desk.'
      );
      Test.stopTest();
    }

    Set<Id> itemIds = new Set<Id>{ cable.Id, desk.Id };
    Map<Id, Item__c> unchangedItems = new Map<Id, Item__c>(
      [
        SELECT Id, AvailableQuantity__c
        FROM Item__c
        WHERE Id IN :itemIds
        WITH SYSTEM_MODE
      ]
    );
    System.Assert.areEqual(
      Decimal.valueOf('20'),
      unchangedItems.get(cable.Id).AvailableQuantity__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('10'),
      unchangedItems.get(desk.Id).AvailableQuantity__c
    );
    System.Assert.areEqual(
      0,
      [SELECT COUNT() FROM Purchase__c WITH SYSTEM_MODE]
    );
    System.Assert.areEqual(
      0,
      [SELECT COUNT() FROM PurchaseLine__c WITH SYSTEM_MODE]
    );
  }

  @IsTest
  static void rollsBackThePurchaseWhenDownstreamTotalsOverflow() {
    User checkoutUser = authorizedCheckoutUser();
    Account account = checkoutAccount();
    Item__c item = PurchaseTestFactory.createItem(
      'Overflow Item',
      null,
      'Product',
      'Other',
      Decimal.valueOf('9999999999999999.99'),
      Decimal.valueOf('999999999999999999')
    );

    System.runAs(checkoutUser) {
      Test.startTest();
      assertCheckoutFailure(
        account.Id,
        new List<CartLineInput>{
          PurchaseTestFactory.cartLine(
            item.Id,
            Decimal.valueOf('999999999999999999')
          )
        },
        'Checkout could not be completed. No records were changed.'
      );
      Test.stopTest();
    }

    System.Assert.areEqual(
      Decimal.valueOf('999999999999999999'),
      [
        SELECT AvailableQuantity__c
        FROM Item__c
        WHERE Id = :item.Id
        WITH SYSTEM_MODE
      ]
      .AvailableQuantity__c
    );
    System.Assert.areEqual(
      0,
      [SELECT COUNT() FROM Purchase__c WITH SYSTEM_MODE]
    );
    System.Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM PurchaseLine__c
        WHERE ItemId__c = :item.Id
        WITH SYSTEM_MODE
      ]
    );
  }

  private static Account checkoutAccount() {
    return [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account Checkout'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static Item__c checkoutItem(String name) {
    return [
      SELECT Id, Price__c, AvailableQuantity__c
      FROM Item__c
      WHERE Name = :name
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static User authorizedCheckoutUser() {
    return [
      SELECT Id
      FROM User
      WHERE LastName = 'Purchase Tool Checkout User'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static void assertCheckoutFailure(
    Id accountId,
    List<CartLineInput> cartLines,
    String expectedMessage
  ) {
    try {
      PurchaseCheckoutService.checkout(accountId, cartLines);
      System.Assert.fail('Expected a PurchaseToolException.');
    } catch (PurchaseToolException caughtError) {
      System.Assert.areEqual(expectedMessage, caughtError.getMessage());
    }
  }
}
