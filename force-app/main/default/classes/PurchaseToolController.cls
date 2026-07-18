public with sharing class PurchaseToolController {
  @AuraEnabled(cacheable=true)
  public static List<Item__c> searchItems(
    String family,
    String type,
    String searchTerm
  ) {
    try {
      return ItemCatalogService.search(family, type, searchTerm);
    } catch (PurchaseToolException caughtError) {
      throw handled(caughtError.getMessage());
    } catch (Exception caughtError) {
      throw handled(
        'Items could not be loaded. Check your permissions and try again.'
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, List<String>> getFilterOptions() {
    try {
      return ItemCatalogService.getFilterOptions();
    } catch (PurchaseToolException caughtError) {
      throw handled(caughtError.getMessage());
    } catch (Exception caughtError) {
      throw handled('Item filters could not be loaded.');
    }
  }

  @AuraEnabled(cacheable=true)
  public static Boolean isCurrentUserManager() {
    try {
      return PurchaseToolAuthorization.isCurrentUserManager();
    } catch (Exception caughtError) {
      return false;
    }
  }

  @AuraEnabled
  public static Item__c createItem(
    String name,
    String description,
    String type,
    String family,
    Decimal price,
    Decimal availableQuantity
  ) {
    try {
      return ItemCreationService.create(
        name,
        description,
        type,
        family,
        price,
        availableQuantity
      );
    } catch (PurchaseToolException caughtError) {
      throw handled(caughtError.getMessage());
    } catch (Exception caughtError) {
      throw handled('The item could not be created. No records were changed.');
    }
  }

  @AuraEnabled
  public static Id checkout(Id accountId, List<CartLineInput> cartLines) {
    try {
      return PurchaseCheckoutService.checkout(accountId, cartLines);
    } catch (PurchaseToolException caughtError) {
      throw handled(caughtError.getMessage());
    }
  }

  private static AuraHandledException handled(String message) {
    AuraHandledException handledError = new AuraHandledException(message);
    handledError.setMessage(message);
    return handledError;
  }
}
