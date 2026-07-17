public class CartLineInput {
  @AuraEnabled
  public Id itemId { get; set; }

  @AuraEnabled
  public Decimal quantity { get; set; }
}
