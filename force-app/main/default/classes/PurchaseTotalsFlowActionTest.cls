@IsTest
private class PurchaseTotalsFlowActionTest {
  @TestSetup
  static void createPurchaseLines() {
    Account account = PurchaseTestFactory.createAccount('Totals');
    List<Item__c> items = new List<Item__c>{
      PurchaseTestFactory.itemRecord(
        'Totals Item One',
        null,
        'Product',
        'Electronics',
        10,
        50
      ),
      PurchaseTestFactory.itemRecord(
        'Totals Item Two',
        null,
        'Accessory',
        'Electronics',
        25,
        50
      )
    };
    Database.insert(items, AccessLevel.SYSTEM_MODE);
    Purchase__c firstPurchase = PurchaseTestFactory.createPurchase(
      account,
      'Totals One'
    );
    Purchase__c secondPurchase = PurchaseTestFactory.createPurchase(
      account,
      'Totals Two'
    );
    Database.insert(
      new List<PurchaseLine__c>{
        PurchaseTestFactory.lineRecord(firstPurchase, items[0], 2, 10),
        PurchaseTestFactory.lineRecord(firstPurchase, items[1], 3, 25),
        PurchaseTestFactory.lineRecord(secondPurchase, items[0], 4, 7.5)
      },
      AccessLevel.SYSTEM_MODE
    );
  }

  @IsTest
  static void recalculatesMultiplePurchasesAndExcludesDeletedLines() {
    Purchase__c firstPurchase = purchaseByName('Test Purchase Totals One');
    Purchase__c secondPurchase = purchaseByName('Test Purchase Totals Two');
    PurchaseLine__c excludedLine = [
      SELECT Id
      FROM PurchaseLine__c
      WHERE PurchaseId__c = :firstPurchase.Id AND Amount__c = 3
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Database.update(
      new List<Purchase__c>{
        new Purchase__c(
          Id = firstPurchase.Id,
          TotalItems__c = 999,
          GrandTotal__c = 999
        ),
        new Purchase__c(
          Id = secondPurchase.Id,
          TotalItems__c = 999,
          GrandTotal__c = 999
        )
      },
      AccessLevel.SYSTEM_MODE
    );
    PurchaseTotalsFlowAction.Request firstRequest = totalsRequest(
      firstPurchase.Id,
      excludedLine.Id
    );
    PurchaseTotalsFlowAction.Request secondRequest = totalsRequest(
      secondPurchase.Id,
      null
    );
    PurchaseTotalsFlowAction.Request emptyRequest = totalsRequest(null, null);

    Test.startTest();
    PurchaseTotalsFlowAction.recalculate(
      new List<PurchaseTotalsFlowAction.Request>{
        firstRequest,
        secondRequest,
        emptyRequest
      }
    );
    Test.stopTest();

    Set<Id> purchaseIds = new Set<Id>{ firstPurchase.Id, secondPurchase.Id };
    Map<Id, Purchase__c> refreshedPurchases = new Map<Id, Purchase__c>(
      [
        SELECT Id, TotalItems__c, GrandTotal__c
        FROM Purchase__c
        WHERE Id IN :purchaseIds
        WITH SYSTEM_MODE
      ]
    );
    System.Assert.areEqual(
      Decimal.valueOf('2'),
      refreshedPurchases.get(firstPurchase.Id).TotalItems__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('20'),
      refreshedPurchases.get(firstPurchase.Id).GrandTotal__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('4'),
      refreshedPurchases.get(secondPurchase.Id).TotalItems__c
    );
    System.Assert.areEqual(
      Decimal.valueOf('30'),
      refreshedPurchases.get(secondPurchase.Id).GrandTotal__c
    );
  }

  @IsTest
  static void resetsPurchasesWithoutLinesToZero() {
    Account account = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Account Totals'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Purchase__c purchase = PurchaseTestFactory.createPurchase(
      account,
      'Without Lines'
    );
    purchase.TotalItems__c = 7;
    purchase.GrandTotal__c = 77;
    Database.update(purchase, AccessLevel.SYSTEM_MODE);

    Test.startTest();
    PurchaseTotalsFlowAction.recalculate(
      new List<PurchaseTotalsFlowAction.Request>{
        totalsRequest(purchase.Id, null)
      }
    );
    Test.stopTest();

    purchase = [
      SELECT TotalItems__c, GrandTotal__c
      FROM Purchase__c
      WHERE Id = :purchase.Id
      WITH SYSTEM_MODE
    ];
    System.Assert.areEqual(Decimal.valueOf('0'), purchase.TotalItems__c);
    System.Assert.areEqual(Decimal.valueOf('0'), purchase.GrandTotal__c);
  }

  @IsTest
  static void beforeDeleteFlowExcludesTheDeletedLineFromTotals() {
    Purchase__c purchase = purchaseByName('Test Purchase Totals One');
    PurchaseLine__c lineToDelete = [
      SELECT Id
      FROM PurchaseLine__c
      WHERE PurchaseId__c = :purchase.Id AND Amount__c = 3
      WITH SYSTEM_MODE
      LIMIT 1
    ];

    Test.startTest();
    Database.delete(lineToDelete, AccessLevel.SYSTEM_MODE);
    Test.stopTest();

    purchase = [
      SELECT TotalItems__c, GrandTotal__c
      FROM Purchase__c
      WHERE Id = :purchase.Id
      WITH SYSTEM_MODE
    ];
    System.Assert.areEqual(Decimal.valueOf('2'), purchase.TotalItems__c);
    System.Assert.areEqual(Decimal.valueOf('20'), purchase.GrandTotal__c);
    System.Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM PurchaseLine__c
        WHERE PurchaseId__c = :purchase.Id
        WITH SYSTEM_MODE
      ]
    );
  }

  @IsTest
  static void leavesTotalsUntouchedWhenNoPurchaseIsRequested() {
    Purchase__c purchase = purchaseByName('Test Purchase Totals One');
    purchase.TotalItems__c = 12;
    purchase.GrandTotal__c = 120;
    Database.update(purchase, AccessLevel.SYSTEM_MODE);

    Test.startTest();
    PurchaseTotalsFlowAction.recalculate(
      new List<PurchaseTotalsFlowAction.Request>()
    );
    PurchaseTotalsFlowAction.recalculate(
      new List<PurchaseTotalsFlowAction.Request>{ totalsRequest(null, null) }
    );
    Test.stopTest();

    purchase = [
      SELECT TotalItems__c, GrandTotal__c
      FROM Purchase__c
      WHERE Id = :purchase.Id
      WITH SYSTEM_MODE
    ];
    System.Assert.areEqual(Decimal.valueOf('12'), purchase.TotalItems__c);
    System.Assert.areEqual(Decimal.valueOf('120'), purchase.GrandTotal__c);
  }

  private static Purchase__c purchaseByName(String name) {
    return [
      SELECT Id, TotalItems__c, GrandTotal__c
      FROM Purchase__c
      WHERE Name = :name
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static PurchaseTotalsFlowAction.Request totalsRequest(
    Id purchaseId,
    Id excludedLineId
  ) {
    PurchaseTotalsFlowAction.Request request = new PurchaseTotalsFlowAction.Request();
    request.purchaseId = purchaseId;
    request.excludedLineId = excludedLineId;
    return request;
  }
}
