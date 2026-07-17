public with sharing class ItemCreationService {
  public static Item__c create(
    String name,
    String description,
    String type,
    String family,
    Decimal price,
    Decimal availableQuantity
  ) {
    if (!PurchaseToolAuthorization.isCurrentUserManager()) {
      throw new PurchaseToolException(
        'Only inventory managers can create items.'
      );
    }

    validate(name, description, type, family, price, availableQuantity);
    String imageUrl = UnsplashClient.findImageUrl(name.trim());
    Item__c item = new Item__c(
      Name = name.trim(),
      Description__c = String.isBlank(description) ? null : description.trim(),
      Type__c = type,
      Family__c = family,
      Image__c = imageUrl,
      Price__c = price,
      AvailableQuantity__c = availableQuantity
    );
    Database.insert(item, AccessLevel.USER_MODE);
    return item;
  }

  private static void validate(
    String name,
    String description,
    String type,
    String family,
    Decimal price,
    Decimal availableQuantity
  ) {
    if (String.isBlank(name) || name.trim().length() > 80) {
      throw new PurchaseToolException(
        'Item name is required and cannot exceed 80 characters.'
      );
    }
    if (description != null && description.trim().length() > 255) {
      throw new PurchaseToolException(
        'Description cannot exceed 255 characters.'
      );
    }
    if (!isActivePicklistValue(Item__c.Type__c.getDescribe(), type)) {
      throw new PurchaseToolException('Select a valid item type.');
    }
    if (!isActivePicklistValue(Item__c.Family__c.getDescribe(), family)) {
      throw new PurchaseToolException('Select a valid item family.');
    }
    if (price == null || price < 0) {
      throw new PurchaseToolException('Price must be zero or greater.');
    }
    if (
      availableQuantity == null ||
      availableQuantity < 0 ||
      availableQuantity != availableQuantity.setScale(0)
    ) {
      throw new PurchaseToolException(
        'Available quantity must be a whole number that is zero or greater.'
      );
    }
  }

  private static Boolean isActivePicklistValue(
    Schema.DescribeFieldResult fieldDescription,
    String value
  ) {
    if (String.isBlank(value)) {
      return false;
    }
    for (Schema.PicklistEntry entry : fieldDescription.getPicklistValues()) {
      if (entry.isActive() && entry.getValue() == value) {
        return true;
      }
    }
    return false;
  }
}
