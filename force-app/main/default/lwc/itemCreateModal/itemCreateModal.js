import { api, LightningElement } from "lwc";

export default class ItemCreateModal extends LightningElement {
  @api typeOptions = [];
  @api familyOptions = [];
  @api saving = false;
  @api errorMessage;

  draft = {};

  get saveDisabled() {
    return this.saving;
  }

  handleFieldChange(event) {
    this.draft = {
      ...this.draft,
      [event.target.name]: event.detail?.value ?? event.target.value
    };
  }

  handleClose(event) {
    event?.stopPropagation();
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleSave() {
    const fields = [
      ...this.template.querySelectorAll(
        "lightning-input, lightning-textarea, lightning-combobox"
      )
    ];
    const isValid = fields.reduce((valid, field) => {
      field.reportValidity();
      return field.checkValidity() && valid;
    }, true);

    if (!isValid) {
      return;
    }

    this.dispatchEvent(
      new CustomEvent("saveitem", {
        detail: {
          name: this.draft.name?.trim(),
          description: this.draft.description?.trim() || null,
          type: this.draft.type,
          family: this.draft.family,
          price: Number(this.draft.price),
          availableQuantity: Number(this.draft.availableQuantity)
        }
      })
    );
  }
}
