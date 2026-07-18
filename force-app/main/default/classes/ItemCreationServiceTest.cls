@IsTest
private class ItemCreationServiceTest {
  private class SequenceMock implements HttpCalloutMock {
    private List<Integer> statusCodes;
    private List<String> bodies;
    private Integer index = 0;

    SequenceMock(List<Integer> statusCodes, List<String> bodies) {
      this.statusCodes = statusCodes;
      this.bodies = bodies;
    }

    public HttpResponse respond(HttpRequest request) {
      System.Assert.isTrue(index < statusCodes.size());
      System.Assert.areEqual('GET', request.getMethod());
      System.Assert.isTrue(
        request.getEndpoint()
          .startsWith('callout:Unsplash_API/search/photos?query=')
      );
      System.Assert.isTrue(request.getEndpoint().endsWith('&per_page=1'));
      HttpResponse response = new HttpResponse();
      response.setStatusCode(statusCodes[index]);
      response.setBody(bodies[index]);
      index++;
      return response;
    }
  }

  private class UnexpectedCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      System.Assert.fail('A denied request must not perform a callout.');
      return null;
    }
  }

  @TestSetup
  static void createAuthorizationUsers() {
    User manager = PurchaseTestFactory.createUser(true, 'Manager');
    User standardUser = PurchaseTestFactory.createUser(false, 'Standard User');
    Map<String, PermissionSet> permissionsByName = new Map<String, PermissionSet>();
    for (PermissionSet permission : [
      SELECT Id, Name
      FROM PermissionSet
      WHERE Name IN ('Item_Purchase_User', 'Item_Purchase_Manager')
    ]) {
      permissionsByName.put(permission.Name, permission);
    }
    insert new List<PermissionSetAssignment>{
      new PermissionSetAssignment(
        AssigneeId = manager.Id,
        PermissionSetId = permissionsByName.get('Item_Purchase_User').Id
      ),
      new PermissionSetAssignment(
        AssigneeId = manager.Id,
        PermissionSetId = permissionsByName.get('Item_Purchase_Manager').Id
      ),
      new PermissionSetAssignment(
        AssigneeId = standardUser.Id,
        PermissionSetId = permissionsByName.get('Item_Purchase_User').Id
      )
    };
  }

  @IsTest
  static void managerCreatesTrimmedItemWithUnsplashImage() {
    User manager = userByLastName('Purchase Tool Manager');
    Test.setMock(
      HttpCalloutMock.class,
      new SequenceMock(
        new List<Integer>{ 200 },
        new List<String>{
          '{"results":[{"urls":{"small":"https://images.unsplash.com/photo-test"}}]}'
        }
      )
    );
    Item__c createdItem;

    System.runAs(manager) {
      System.Assert.isTrue(PurchaseToolAuthorization.isCurrentUserManager());
      System.Assert.isTrue(PurchaseToolController.isCurrentUserManager());
      Test.startTest();
      createdItem = PurchaseToolController.createItem(
        '  Desk Lamp  ',
        '  Adjustable light  ',
        'Product',
        'Electronics',
        89.99,
        12
      );
      Test.stopTest();
    }

    createdItem = [
      SELECT
        Name,
        Description__c,
        Type__c,
        Family__c,
        Image__c,
        Price__c,
        AvailableQuantity__c
      FROM Item__c
      WHERE Id = :createdItem.Id
    ];
    System.Assert.areEqual('Desk Lamp', createdItem.Name);
    System.Assert.areEqual('Adjustable light', createdItem.Description__c);
    System.Assert.areEqual('Product', createdItem.Type__c);
    System.Assert.areEqual('Electronics', createdItem.Family__c);
    System.Assert.areEqual(
      'https://images.unsplash.com/photo-test',
      createdItem.Image__c
    );
    System.Assert.areEqual(Decimal.valueOf('89.99'), createdItem.Price__c);
    System.Assert.areEqual(
      Decimal.valueOf('12'),
      createdItem.AvailableQuantity__c
    );
  }

  @IsTest
  static void nonManagerCannotCreateItems() {
    User standardUser = userByLastName('Purchase Tool Standard User');
    Test.setMock(HttpCalloutMock.class, new UnexpectedCalloutMock());

    System.runAs(standardUser) {
      System.Assert.isFalse(PurchaseToolAuthorization.isCurrentUserManager());
      System.Assert.isFalse(PurchaseToolController.isCurrentUserManager());
      Test.startTest();
      try {
        PurchaseToolController.createItem(
          'Denied Item',
          null,
          'Product',
          'Electronics',
          10,
          1
        );
        System.Assert.fail('Expected an AuraHandledException.');
      } catch (AuraHandledException caughtError) {
        System.Assert.areEqual(
          'Only inventory managers can create items.',
          caughtError.getMessage()
        );
      }
      Test.stopTest();
    }

    System.Assert.areEqual(0, [SELECT COUNT() FROM Item__c]);
  }

  @IsTest
  static void validatesEveryManagerInputBeforeCallingUnsplash() {
    User manager = userByLastName('Purchase Tool Manager');
    Test.setMock(HttpCalloutMock.class, new UnexpectedCalloutMock());

    System.runAs(manager) {
      assertCreateFailure(
        ' ',
        null,
        'Product',
        'Electronics',
        1,
        1,
        'Item name is required and cannot exceed 80 characters.'
      );
      assertCreateFailure(
        PurchaseTestFactory.repeat('n', 81),
        null,
        'Product',
        'Electronics',
        1,
        1,
        'Item name is required and cannot exceed 80 characters.'
      );
      assertCreateFailure(
        'Item',
        PurchaseTestFactory.repeat('d', 256),
        'Product',
        'Electronics',
        1,
        1,
        'Description cannot exceed 255 characters.'
      );
      assertCreateFailure(
        'Item',
        null,
        'Unknown',
        'Electronics',
        1,
        1,
        'Select a valid item type.'
      );
      assertCreateFailure(
        'Item',
        null,
        'Product',
        'Unknown',
        1,
        1,
        'Select a valid item family.'
      );
      assertCreateFailure(
        'Item',
        null,
        'Product',
        'Electronics',
        null,
        1,
        'Price must be zero or greater.'
      );
      assertCreateFailure(
        'Item',
        null,
        'Product',
        'Electronics',
        -0.01,
        1,
        'Price must be zero or greater.'
      );
      assertCreateFailure(
        'Item',
        null,
        'Product',
        'Electronics',
        1,
        null,
        'Available quantity must be a whole number that is zero or greater.'
      );
      assertCreateFailure(
        'Item',
        null,
        'Product',
        'Electronics',
        1,
        -1,
        'Available quantity must be a whole number that is zero or greater.'
      );
      assertCreateFailure(
        'Item',
        null,
        'Product',
        'Electronics',
        1,
        1.5,
        'Available quantity must be a whole number that is zero or greater.'
      );
    }
  }

  @IsTest
  static void mapsUnsplashErrorResponsesToStableMessages() {
    Test.setMock(
      HttpCalloutMock.class,
      new SequenceMock(
        new List<Integer>{ 429, 503, 200, 200, 200, 200, 200 },
        new List<String>{
          '{}',
          '{}',
          'not-json',
          '{}',
          '{"results":[]}',
          '{"results":[{}]}',
          '{"results":[{"urls":{"small":"https://example.com/image.jpg"}}]}'
        }
      )
    );

    Test.startTest();
    assertUnsplashFailure(
      'Rate Limited',
      'Unsplash request limit has been reached. Try again later.'
    );
    assertUnsplashFailure(
      'Server Error',
      'Unsplash could not provide an image for this item.'
    );
    assertUnsplashFailure(
      'Invalid JSON',
      'Unsplash returned an invalid response.'
    );
    assertUnsplashFailure(
      'Missing Results',
      'Unsplash did not find an image for this item.'
    );
    assertUnsplashFailure(
      'Empty Results',
      'Unsplash did not find an image for this item.'
    );
    assertUnsplashFailure(
      'Missing URL',
      'Unsplash returned an unsupported image URL.'
    );
    assertUnsplashFailure(
      'Unsupported Host',
      'Unsplash returned an unsupported image URL.'
    );
    Test.stopTest();
  }

  private static User userByLastName(String lastName) {
    return [
      SELECT Id, IsManager__c
      FROM User
      WHERE LastName = :lastName
      LIMIT 1
    ];
  }

  private static void assertCreateFailure(
    String name,
    String description,
    String type,
    String family,
    Decimal price,
    Decimal availableQuantity,
    String expectedMessage
  ) {
    try {
      ItemCreationService.create(
        name,
        description,
        type,
        family,
        price,
        availableQuantity
      );
      System.Assert.fail('Expected a PurchaseToolException.');
    } catch (PurchaseToolException caughtError) {
      System.Assert.areEqual(expectedMessage, caughtError.getMessage());
    }
  }

  private static void assertUnsplashFailure(
    String itemName,
    String expectedMessage
  ) {
    try {
      UnsplashClient.findImageUrl(itemName);
      System.Assert.fail('Expected a PurchaseToolException.');
    } catch (PurchaseToolException caughtError) {
      System.Assert.areEqual(expectedMessage, caughtError.getMessage());
    }
  }
}
