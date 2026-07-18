@IsTest
private class ItemCatalogServiceTest {
  @TestSetup
  static void createCatalog() {
    insert new List<Item__c>{
      PurchaseTestFactory.itemRecord(
        'Alpha Laptop',
        'Portable workstation',
        'Product',
        'Electronics',
        1200,
        8
      ),
      PurchaseTestFactory.itemRecord(
        'Beta Cable',
        'Braided connector',
        'Accessory',
        'Electronics',
        19.95,
        30
      ),
      PurchaseTestFactory.itemRecord(
        'Gamma Desk',
        'Standing workspace',
        'Equipment',
        'Furniture',
        450,
        5
      ),
      PurchaseTestFactory.itemRecord(
        'Delta Paper',
        'Copy paper package',
        'Supply',
        'Office_Supplies',
        7.5,
        100
      )
    };
  }

  @IsTest
  static void searchesAndCombinesAllFilters() {
    Test.startTest();
    List<Item__c> allItems = ItemCatalogService.search(null, ' ', null);
    List<Item__c> familyItems = ItemCatalogService.search(
      ' Electronics ',
      null,
      null
    );
    List<Item__c> typeItems = ItemCatalogService.search(
      null,
      'Accessory',
      null
    );
    List<Item__c> nameMatches = ItemCatalogService.search(
      null,
      null,
      ' gamma '
    );
    List<Item__c> descriptionMatches = ItemCatalogService.search(
      null,
      null,
      'workstation'
    );
    List<Item__c> combinedMatches = PurchaseToolController.searchItems(
      'Electronics',
      'Accessory',
      'connector'
    );
    Test.stopTest();

    System.Assert.areEqual(4, allItems.size());
    System.Assert.areEqual('Alpha Laptop', allItems[0].Name);
    System.Assert.areEqual(2, familyItems.size());
    System.Assert.areEqual(1, typeItems.size());
    System.Assert.areEqual('Beta Cable', typeItems[0].Name);
    System.Assert.areEqual(1, nameMatches.size());
    System.Assert.areEqual('Gamma Desk', nameMatches[0].Name);
    System.Assert.areEqual(1, descriptionMatches.size());
    System.Assert.areEqual('Alpha Laptop', descriptionMatches[0].Name);
    System.Assert.areEqual(1, combinedMatches.size());
    System.Assert.areEqual('Beta Cable', combinedMatches[0].Name);
  }

  @IsTest
  static void returnsActiveFilterOptions() {
    Test.startTest();
    Map<String, List<String>> options = PurchaseToolController.getFilterOptions();
    Test.stopTest();

    System.Assert.areEqual(
      new Set<String>{ 'Product', 'Accessory', 'Supply', 'Equipment' },
      new Set<String>(options.get('types'))
    );
    System.Assert.areEqual(
      new Set<String>{ 'Electronics', 'Furniture', 'Office_Supplies', 'Other' },
      new Set<String>(options.get('families'))
    );
  }

  @IsTest
  static void rejectsSearchTextOverTheLimit() {
    String searchText = PurchaseTestFactory.repeat('x', 101);

    Test.startTest();
    try {
      PurchaseToolController.searchItems(null, null, searchText);
      System.Assert.fail('Expected an AuraHandledException.');
    } catch (AuraHandledException exception) {
      System.Assert.areEqual(
        'Search text cannot exceed 100 characters.',
        exception.getMessage()
      );
    }
    Test.stopTest();
  }
}
