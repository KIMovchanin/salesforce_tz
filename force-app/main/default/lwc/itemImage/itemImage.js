import { api, LightningElement } from "lwc";

const UNSPLASH_URL =
  "https://unsplash.com/?utm_source=item_purchase_tool&utm_medium=referral";

export default class ItemImage extends LightningElement {
  @api imageUrl;
  @api alternativeText;
  @api loading;
  @api photographerName;
  @api photographerUrl;

  unsplashUrl = UNSPLASH_URL;

  get hasImage() {
    return Boolean(
      this.imageUrl &&
      (!this.isUnsplashImage || this.hasPhotographerAttribution)
    );
  }

  get isUnsplashImage() {
    return this.imageUrl?.startsWith("https://images.unsplash.com/");
  }

  get photographerLink() {
    return this.photographerUrl?.startsWith("https://unsplash.com/")
      ? this.photographerUrl
      : undefined;
  }

  get hasPhotographerAttribution() {
    return Boolean(this.photographerName && this.photographerLink);
  }
}
