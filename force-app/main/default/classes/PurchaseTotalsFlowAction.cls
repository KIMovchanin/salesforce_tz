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

    List<AggregateResult> totals;
    if (excludedLineIds.isEmpty()) {
      totals = [
        SELECT
          PurchaseId__c purchaseId,
          SUM(Amount__c) itemTotal,
          SUM(LineTotal__c) grandTotal
        FROM PurchaseLine__c
        WHERE PurchaseId__c IN :purchaseIds
        WITH SYSTEM_MODE
        GROUP BY PurchaseId__c
      ];
    } else {
      totals = [
        SELECT
          PurchaseId__c purchaseId,
          SUM(Amount__c) itemTotal,
          SUM(LineTotal__c) grandTotal
        FROM PurchaseLine__c
        WHERE PurchaseId__c IN :purchaseIds AND Id NOT IN :excludedLineIds
        WITH SYSTEM_MODE
        GROUP BY PurchaseId__c
      ];
    }
    for (AggregateResult total : totals) {
      Id purchaseId = (Id) total.get('purchaseId');
      itemTotals.put(purchaseId, (Decimal) total.get('itemTotal'));
      grandTotals.put(purchaseId, (Decimal) total.get('grandTotal'));
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
