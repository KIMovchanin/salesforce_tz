import { api, LightningElement } from "lwc";
import { dispatchCloseEvent, dispatchItemEvent } from "c/componentEvents";
import {
  getItemDescription,
  getItemStockClass,
  getItemStockLabel,
  isItemOutOfStock
} from "c/itemPresentation";

export default class ItemDetailsModal extends LightningElement {
  @api item;

  get heading() {
    return this.item?.Name || "Item details";
  }

  get description() {
    return getItemDescription(this.item);
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

  handleClose(event) {
    dispatchCloseEvent(this, event);
  }

  handleAdd() {
    dispatchItemEvent(this, "additem", this.item);
  }
}
