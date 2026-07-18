import { api, LightningElement } from "lwc";

export default class ItemDetailsModal extends LightningElement {
  @api item;

  get heading() {
    return this.item?.Name || "Item details";
  }

  get hasImage() {
    return Boolean(this.item?.Image__c);
  }

  get description() {
    return this.item?.Description__c || "No description available";
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

  handleClose(event) {
    event?.stopPropagation();
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleAdd() {
    this.dispatchEvent(
      new CustomEvent("additem", {
        detail: { item: this.item }
      })
    );
  }
}
