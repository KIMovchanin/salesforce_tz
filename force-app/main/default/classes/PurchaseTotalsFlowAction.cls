public with sharing class PurchaseTotalsFlowAction {
  @InvocableMethod(label='Recalculate Purchase Totals')
  public static void recalculate(List<Request> requests) {
    Set<Id> purchaseIds = new Set<Id>();
    Set<Id> excludedLineIds = new Set<Id>();
    for (Request request : requests) {
      if (request.purchaseId != null) {
        purchaseIds.add(request.purchaseId);
      }
      if (request.excludedLineId != null) {
        excludedLineIds.add(request.excludedLineId);
      }
    }
    if (purchaseIds.isEmpty()) {
      return;
    }

    Map<Id, Decimal> itemTotals = new Map<Id, Decimal>();
    Map<Id, Decimal> grandTotals = new Map<Id, Decimal>();
    for (Id purchaseId : purchaseIds) {
      itemTotals.put(purchaseId, 0);
      grandTotals.put(purchaseId, 0);
    }

    for (PurchaseLine__c line : [
      SELECT Id, PurchaseId__c, Amount__c, UnitCost__c
      FROM PurchaseLine__c
      WHERE PurchaseId__c IN :purchaseIds
      WITH SYSTEM_MODE
    ]) {
      if (excludedLineIds.contains(line.Id)) {
        continue;
      }
      Decimal amount = line.Amount__c == null ? 0 : line.Amount__c;
      Decimal unitCost = line.UnitCost__c == null ? 0 : line.UnitCost__c;
      itemTotals.put(
        line.PurchaseId__c,
        itemTotals.get(line.PurchaseId__c) + amount
      );
      grandTotals.put(
        line.PurchaseId__c,
        grandTotals.get(line.PurchaseId__c) + amount * unitCost
      );
    }

    List<Purchase__c> purchases = new List<Purchase__c>();
    for (Id purchaseId : purchaseIds) {
      purchases.add(
        new Purchase__c(
          Id = purchaseId,
          TotalItems__c = itemTotals.get(purchaseId),
          GrandTotal__c = grandTotals.get(purchaseId)
        )
      );
    }
    Database.update(purchases, AccessLevel.SYSTEM_MODE);
  }

  public class Request {
    @InvocableVariable(required=true)
    public Id purchaseId;

    @InvocableVariable
    public Id excludedLineId;
  }
}
