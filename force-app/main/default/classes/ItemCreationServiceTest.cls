@IsTest
private class ItemCreationServiceTest {
  private class SequenceMock implements HttpCalloutMock {
    private List<String> endpoints;
    private List<Integer> statusCodes;
    private List<String> bodies;
    private Integer index = 0;

    SequenceMock(
      List<String> endpoints,
      List<Integer> statusCodes,
      List<String> bodies
    ) {
      this.endpoints = endpoints;
      this.statusCodes = statusCodes;
      this.bodies = bodies;
    }

    public HttpResponse respond(HttpRequest request) {
      System.Assert.isTrue(index < statusCodes.size());
      System.Assert.areEqual('GET', request.getMethod());
      System.Assert.areEqual('v1', request.getHeader('Accept-Version'));
      System.Assert.areEqual(endpoints[index], request.getEndpoint());
      HttpResponse response = new HttpResponse();
      response.setStatusCode(statusCodes[index]);
      response.setBody(bodies[index]);
      index++;
      return response;
    }

    void assertComplete() {
      System.Assert.areEqual(statusCodes.size(), index);
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
    PurchaseTestFactory.assignPermissionSets(
      manager.Id,
      new Set<String>{ 'Item_Purchase_User', 'Item_Purchase_Manager' }
    );
    PurchaseTestFactory.assignPermissionSets(
      standardUser.Id,
      new Set<String>{ 'Item_Purchase_User' }
    );
  }

  @IsTest
  static void managerCreatesAttributedItemAndTracksSelection() {
    User manager = userByLastName('Purchase Tool Manager');
    SequenceMock callouts = new SequenceMock(
      new List<String>{
        searchEndpoint('Desk Lamp'),
        'callout:Unsplash_API/photos/photo-test/download?ixid=download-context&context=search%20result'
      },
      new List<Integer>{ 200, 200 },
      new List<String>{
        validPhotoBody(),
        '{"url":"https://images.unsplash.com/photo-test"}'
      }
    );
    Test.setMock(HttpCalloutMock.class, callouts);
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

    callouts.assertComplete();
    createdItem = [
      SELECT
        Name,
        Description__c,
        Type__c,
        Family__c,
        Image__c,
        Unsplash_Photographer__c,
        Unsplash_Profile_URL__c,
        Price__c,
        AvailableQuantity__c
      FROM Item__c
      WHERE Id = :createdItem.Id
      WITH SYSTEM_MODE
    ];
    System.Assert.areEqual('Desk Lamp', createdItem.Name);
    System.Assert.areEqual('Adjustable light', createdItem.Description__c);
    System.Assert.areEqual('Product', createdItem.Type__c);
    System.Assert.areEqual('Electronics', createdItem.Family__c);
    System.Assert.areEqual(
      'https://images.unsplash.com/photo-test?ixid=application',
      createdItem.Image__c
    );
    System.Assert.areEqual(
      'Jane Photographer',
      createdItem.Unsplash_Photographer__c
    );
    System.Assert.areEqual(
      'https://unsplash.com/@jane-photographer?utm_source=item_purchase_tool&utm_medium=referral',
      createdItem.Unsplash_Profile_URL__c
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

    System.Assert.areEqual(0, [SELECT COUNT() FROM Item__c WITH SYSTEM_MODE]);
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
  static void mapsSearchErrorsToStableMessages() {
    List<String> itemNames = new List<String>{
      'Rate Limited',
      'Server Error',
      'Invalid JSON',
      'Invalid Shape',
      'Missing Results',
      'Empty Results',
      'Missing URL',
      'Unsupported Host',
      'Missing Photographer',
      'Unsupported Profile',
      'Unsupported Download'
    };
    List<String> endpoints = new List<String>();
    for (String itemName : itemNames) {
      endpoints.add(searchEndpoint(itemName));
    }
    SequenceMock callouts = new SequenceMock(
      endpoints,
      new List<Integer>{
        429,
        503,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200,
        200
      },
      new List<String>{
        '{}',
        '{}',
        'not-json',
        '[]',
        '{}',
        '{"results":[]}',
        '{"results":[{}]}',
        '{"results":[{"urls":{"small":"https://example.com/image.jpg"}}]}',
        '{"results":[{"urls":{"small":"https://images.unsplash.com/photo"}}]}',
        '{"results":[{"urls":{"small":"https://images.unsplash.com/photo"},"user":{"name":"Jane","links":{"html":"https://example.com/jane"}}}]}',
        '{"results":[{"urls":{"small":"https://images.unsplash.com/photo"},"links":{"download_location":"https://api.unsplash.com/photos/photo/download?ixid=safe#fragment"},"user":{"name":"Jane","links":{"html":"https://unsplash.com/@jane"}}}]}'
      }
    );
    Test.setMock(HttpCalloutMock.class, callouts);

    Test.startTest();
    assertUnsplashFailure(
      itemNames[0],
      'Unsplash request limit has been reached. Try again later.'
    );
    assertUnsplashFailure(
      itemNames[1],
      'Unsplash could not provide an image for this item.'
    );
    assertUnsplashFailure(
      itemNames[2],
      'Unsplash returned an invalid response.'
    );
    assertUnsplashFailure(
      itemNames[3],
      'Unsplash returned an invalid response.'
    );
    assertUnsplashFailure(
      itemNames[4],
      'Unsplash did not find an image for this item.'
    );
    assertUnsplashFailure(
      itemNames[5],
      'Unsplash did not find an image for this item.'
    );
    assertUnsplashFailure(
      itemNames[6],
      'Unsplash returned an unsupported image URL.'
    );
    assertUnsplashFailure(
      itemNames[7],
      'Unsplash returned an unsupported image URL.'
    );
    assertUnsplashFailure(
      itemNames[8],
      'Unsplash returned incomplete photographer attribution.'
    );
    assertUnsplashFailure(
      itemNames[9],
      'Unsplash returned an unsupported photographer URL.'
    );
    assertUnsplashFailure(
      itemNames[10],
      'Unsplash returned an unsupported download endpoint.'
    );
    Test.stopTest();
    callouts.assertComplete();
  }

  @IsTest
  static void downloadTrackingFailurePreventsItemCreation() {
    User manager = userByLastName('Purchase Tool Manager');
    SequenceMock callouts = new SequenceMock(
      new List<String>{
        searchEndpoint('Track Failure'),
        'callout:Unsplash_API/photos/photo-test/download?ixid=download-context&context=search%20result'
      },
      new List<Integer>{ 200, 503 },
      new List<String>{ validPhotoBody(), '{}' }
    );
    Test.setMock(HttpCalloutMock.class, callouts);

    System.runAs(manager) {
      Test.startTest();
      assertCreateFailure(
        'Track Failure',
        null,
        'Product',
        'Electronics',
        10,
        1,
        'Unsplash could not register the selected image.'
      );
      Test.stopTest();
    }

    callouts.assertComplete();
    System.Assert.areEqual(0, [SELECT COUNT() FROM Item__c WITH SYSTEM_MODE]);
  }

  private static User userByLastName(String lastName) {
    return [
      SELECT Id, IsManager__c
      FROM User
      WHERE LastName = :lastName
      WITH SYSTEM_MODE
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
      UnsplashClient.findPhoto(itemName);
      System.Assert.fail('Expected a PurchaseToolException.');
    } catch (PurchaseToolException caughtError) {
      System.Assert.areEqual(expectedMessage, caughtError.getMessage());
    }
  }

  private static String searchEndpoint(String itemName) {
    return 'callout:Unsplash_API/search/photos?query=' +
      EncodingUtil.urlEncode(itemName, 'UTF-8') +
      '&per_page=1';
  }

  private static String validPhotoBody() {
    return '{"results":[{"urls":{"small":"https://images.unsplash.com/photo-test?ixid=application"},"links":{"download_location":"https://api.unsplash.com/photos/photo-test/download?ixid=download-context&context=search%20result"},"user":{"name":"Jane Photographer","links":{"html":"https://unsplash.com/@jane-photographer"}}}]}';
  }
}
