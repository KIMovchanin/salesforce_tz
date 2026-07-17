public with sharing class PurchaseCheckoutService {
  private static final Integer MAX_CART_LINES = 100;
  private static final Decimal MAX_QUANTITY = 999999999999999999L;

  public static Id checkout(Id accountId, List<CartLineInput> cartLines) {
    Savepoint savepoint = Database.setSavepoint();
    try {
      validateAccount(accountId);
      Map<Id, Decimal> quantitiesByItem = normalizeCart(cartLines);
      List<Item__c> items = lockItems(quantitiesByItem.keySet());
      validateStock(items, quantitiesByItem);

      Purchase__c purchase = new Purchase__c(
        Name = 'Purchase ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss'),
        ClientId__c = accountId,
        TotalItems__c = 0,
        GrandTotal__c = 0
      );
      Database.insert(purchase, AccessLevel.USER_MODE);

      List<PurchaseLine__c> lines = new List<PurchaseLine__c>();
      for (Item__c item : items) {
        Decimal quantity = quantitiesByItem.get(item.Id);
        lines.add(
          new PurchaseLine__c(
            PurchaseId__c = purchase.Id,
            ItemId__c = item.Id,
            Amount__c = quantity,
            UnitCost__c = item.Price__c
          )
        );
        item.AvailableQuantity__c -= quantity;
      }

      Database.insert(lines, AccessLevel.USER_MODE);
      Database.update(items, AccessLevel.SYSTEM_MODE);
      return purchase.Id;
    } catch (PurchaseToolException exception) {
      Database.rollback(savepoint);
      throw exception;
    } catch (Exception exception) {
      Database.rollback(savepoint);
      if (
        exception.getMessage() != null &&
        exception.getMessage().contains('UNABLE_TO_LOCK_ROW')
      ) {
        throw new PurchaseToolException(
          'Inventory is being updated. Try checkout again.'
        );
      }
      throw new PurchaseToolException(
        'Checkout could not be completed. No records were changed.'
      );
    }
  }

  private static void validateAccount(Id accountId) {
    if (accountId == null) {
      throw new PurchaseToolException(
        'Open the purchase tool from an Account record.'
      );
    }
    List<Account> accounts = [
      SELECT Id
      FROM Account
      WHERE Id = :accountId
      WITH USER_MODE
      LIMIT 1
    ];
    if (accounts.isEmpty()) {
      throw new PurchaseToolException(
        'The Account is unavailable or you do not have access to it.'
      );
    }
  }

  private static Map<Id, Decimal> normalizeCart(List<CartLineInput> cartLines) {
    if (cartLines == null || cartLines.isEmpty()) {
      throw new PurchaseToolException('Add at least one item to the cart.');
    }
    if (cartLines.size() > MAX_CART_LINES) {
      throw new PurchaseToolException(
        'A cart cannot contain more than 100 lines.'
      );
    }

    Map<Id, Decimal> quantitiesByItem = new Map<Id, Decimal>();
    for (CartLineInput line : cartLines) {
      if (line == null || line.itemId == null) {
        throw new PurchaseToolException(
          'Every cart line must reference an item.'
        );
      }
      if (
        line.quantity == null ||
        line.quantity <= 0 ||
        line.quantity > MAX_QUANTITY ||
        line.quantity != line.quantity.setScale(0)
      ) {
        throw new PurchaseToolException(
          'Every cart quantity must be a positive whole number.'
        );
      }
      Decimal existingQuantity = quantitiesByItem.get(line.itemId);
      Decimal totalQuantity =
        (existingQuantity == null ? 0 : existingQuantity) + line.quantity;
      if (totalQuantity > MAX_QUANTITY) {
        throw new PurchaseToolException('Cart quantity is too large.');
      }
      quantitiesByItem.put(line.itemId, totalQuantity);
    }
    return quantitiesByItem;
  }

  private static List<Item__c> lockItems(Set<Id> itemIds) {
    List<Item__c> items = [
      SELECT Id, Name, Price__c, AvailableQuantity__c
      FROM Item__c
      WHERE Id IN :itemIds
      WITH USER_MODE
      ORDER BY Id
      FOR UPDATE
    ];
    if (items.size() != itemIds.size()) {
      throw new PurchaseToolException(
        'One or more cart items are unavailable.'
      );
    }
    return items;
  }

  private static void validateStock(
    List<Item__c> items,
    Map<Id, Decimal> quantitiesByItem
  ) {
    for (Item__c item : items) {
      Decimal requestedQuantity = quantitiesByItem.get(item.Id);
      if (item.Price__c == null || item.Price__c < 0) {
        throw new PurchaseToolException(
          'The price for ' + item.Name + ' is unavailable.'
        );
      }
      if (
        item.AvailableQuantity__c == null ||
        item.AvailableQuantity__c < requestedQuantity
      ) {
        throw new PurchaseToolException(
          'Not enough stock is available for ' + item.Name + '.'
        );
      }
    }
  }
}
