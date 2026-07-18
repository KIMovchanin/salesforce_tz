import { api, LightningElement } from "lwc";

export default class ModalShell extends LightningElement {
  @api heading;
  @api size = "medium";

  hasFocused = false;

  get sectionClass() {
    const supportedSizes = ["small", "medium", "large"];
    const sizeClass = supportedSizes.includes(this.size)
      ? ` slds-modal_${this.size}`
      : "";
    return `slds-modal slds-fade-in-open${sizeClass}`;
  }

  renderedCallback() {
    if (this.hasFocused) {
      return;
    }
    this.template.querySelector("section")?.focus();
    this.hasFocused = true;
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleKeyDown(event) {
    if (event.key === "Escape") {
      this.handleClose();
    }
  }
}
