import { api, LightningElement } from "lwc";
import { dispatchItemEvent } from "c/componentEvents";
import {
  getItemDescription,
  getItemStockClass,
  getItemStockLabel,
  isItemOutOfStock
} from "c/itemPresentation";

export default class ItemTile extends LightningElement {
  @api item;

  get itemName() {
    return this.item?.Name || "Item";
  }

  get description() {
    return getItemDescription(this.item);
  }

  get imageUrl() {
    return this.item?.Image__c;
  }

  get isOutOfStock() {
    return isItemOutOfStock(this.item);
  }

  get stockLabel() {
    return getItemStockLabel(this.item);
  }

  get stockClass() {
    return getItemStockClass(this.item);
  }

  handleDetails() {
    this.dispatchEvent(
      new CustomEvent("showdetails", {
        detail: { item: this.item }
      })
    );
  }

  handleAdd() {
    dispatchItemEvent(this, "additem", this.item);
  }
}
