import { api, LightningElement } from "lwc";

export default class ItemTile extends LightningElement {
  @api item;

  get itemName() {
    return this.item?.Name || "Item";
  }

  get description() {
    return this.item?.Description__c || "No description available";
  }

  get imageUrl() {
    return this.item?.Image__c;
  }

  get hasImage() {
    return Boolean(this.imageUrl);
  }

  get isOutOfStock() {
    return Number(this.item?.AvailableQuantity__c || 0) <= 0;
  }

  get stockLabel() {
    return this.isOutOfStock
      ? "Out of stock"
      : `${this.item.AvailableQuantity__c} available`;
  }

  get stockClass() {
    return this.isOutOfStock ? "stock stock_empty" : "stock stock_available";
  }

  handleDetails() {
    this.dispatchEvent(
      new CustomEvent("showdetails", {
        detail: { item: this.item }
      })
    );
  }

  handleAdd() {
    this.dispatchEvent(
      new CustomEvent("additem", {
        detail: { item: this.item }
      })
    );
  }
}
