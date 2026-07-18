import { api, LightningElement } from "lwc";

export default class ItemCartModal extends LightningElement {
  @api items = [];
  @api busy = false;
  @api accountAvailable = false;

  get hasItems() {
    return this.items.length > 0;
  }

  get itemCount() {
    return this.items.reduce((total, line) => total + line.quantity, 0);
  }

  get grandTotal() {
    return this.items.reduce((total, line) => total + line.lineTotal, 0);
  }

  get hasInventoryConflict() {
    return this.items.some(
      (line) => line.quantity < 1 || line.quantity > line.availableQuantity
    );
  }

  get accountUnavailable() {
    return !this.accountAvailable;
  }

  get checkoutDisabled() {
    return (
      this.busy ||
      !this.hasItems ||
      !this.accountAvailable ||
      this.hasInventoryConflict
    );
  }

  get heading() {
    return `Cart (${this.itemCount})`;
  }

  handleClose(event) {
    event?.stopPropagation();
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleQuantityChange(event) {
    const quantity = Number(event.detail?.value ?? event.target.value);
    const currentLine = this.items.find(
      (line) => line.itemId === event.target.dataset.itemId
    );
    if (
      currentLine &&
      (!Number.isInteger(quantity) ||
        quantity < 1 ||
        quantity > currentLine.availableQuantity)
    ) {
      event.target.value = currentLine.quantity;
      event.target.reportValidity();
    }
    this.dispatchEvent(
      new CustomEvent("updatequantity", {
        detail: {
          itemId: event.target.dataset.itemId,
          quantity
        }
      })
    );
  }

  handleRemove(event) {
    this.dispatchEvent(
      new CustomEvent("removeitem", {
        detail: { itemId: event.currentTarget.dataset.itemId }
      })
    );
  }

  handleCheckout() {
    this.dispatchEvent(new CustomEvent("checkout"));
  }
}
