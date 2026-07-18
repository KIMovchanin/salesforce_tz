import { api, LightningElement } from "lwc";

export default class ItemImage extends LightningElement {
  @api imageUrl;
  @api alternativeText;
  @api loading;

  get hasImage() {
    return Boolean(this.imageUrl);
  }
}
