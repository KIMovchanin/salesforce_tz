import { api, LightningElement, wire } from "lwc";
import { getFieldValue, getRecord } from "lightning/uiRecordApi";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import ACCOUNT_NAME from "@salesforce/schema/Account.Name";
import ACCOUNT_NUMBER from "@salesforce/schema/Account.AccountNumber";
import ACCOUNT_INDUSTRY from "@salesforce/schema/Account.Industry";
import searchItems from "@salesforce/apex/PurchaseToolController.searchItems";
import getFilterOptions from "@salesforce/apex/PurchaseToolController.getFilterOptions";
import isCurrentUserManager from "@salesforce/apex/PurchaseToolController.isCurrentUserManager";
import createItem from "@salesforce/apex/PurchaseToolController.createItem";
import checkout from "@salesforce/apex/PurchaseToolController.checkout";

const ACCOUNT_FIELDS = [ACCOUNT_NAME];
const ACCOUNT_OPTIONAL_FIELDS = [ACCOUNT_NUMBER, ACCOUNT_INDUSTRY];

export default class ItemPurchaseTool extends NavigationMixin(
  LightningElement
) {
  accountId;
  account;
  accountLoadError;
  items = [];
  cart = [];
  typeValues = [];
  familyValues = [];
  selectedType = "";
  selectedFamily = "";
  searchTerm = "";
  isManager = false;
  isLoadingItems = false;
  isInitializing = true;
  isCheckingOut = false;
  isCreating = false;
  isDetailsOpen = false;
  isCartOpen = false;
  isCreateOpen = false;
  selectedItem;
  catalogError;
  createError;
  pageAccountId;
  requestSequence = 0;
  privateRecordId;

  @api
  get recordId() {
    return this.privateRecordId;
  }

  set recordId(value) {
    this.privateRecordId = value;
    if (!this.pageAccountId) {
      this.accountId = value;
    }
  }

  @wire(CurrentPageReference)
  capturePageReference(pageReference) {
    const stateAccountId = pageReference?.state?.c__accountId;
    if (stateAccountId) {
      this.pageAccountId = stateAccountId;
      this.accountId = stateAccountId;
    }
  }

  @wire(getRecord, {
    recordId: "$accountId",
    fields: ACCOUNT_FIELDS,
    optionalFields: ACCOUNT_OPTIONAL_FIELDS
  })
  loadAccount({ data, error }) {
    if (data) {
      this.account = data;
      this.accountLoadError = undefined;
    } else if (error) {
      this.account = undefined;
      this.accountLoadError = this.getErrorMessage(error);
    }
  }

  connectedCallback() {
    this.initialize();
  }

  async initialize() {
    this.isInitializing = true;
    await Promise.all([
      this.loadItems(),
      this.loadFilterOptions(),
      this.loadManagerStatus()
    ]);
    this.isInitializing = false;
  }

  async loadItems() {
    const requestId = ++this.requestSequence;
    this.isLoadingItems = true;
    this.catalogError = undefined;

    try {
      const result = await searchItems({
        family: this.selectedFamily || null,
        type: this.selectedType || null,
        searchTerm: this.searchTerm.trim() || null
      });
      if (requestId !== this.requestSequence) {
        return;
      }
      this.items = result || [];
      this.reconcileCart();
    } catch (error) {
      if (requestId !== this.requestSequence) {
        return;
      }
      this.catalogError = this.getErrorMessage(error);
      this.showToast("Catalog unavailable", this.catalogError, "error");
    } finally {
      if (requestId === this.requestSequence) {
        this.isLoadingItems = false;
      }
    }
  }

  async loadFilterOptions() {
    try {
      const result = await getFilterOptions();
      this.typeValues = result?.types || [];
      this.familyValues = result?.families || [];
    } catch (error) {
      this.showToast(
        "Filters unavailable",
        this.getErrorMessage(error),
        "error"
      );
    }
  }

  async loadManagerStatus() {
    try {
      this.isManager = await isCurrentUserManager();
    } catch {
      this.isManager = false;
    }
  }

  get accountName() {
    return getFieldValue(this.account, ACCOUNT_NAME) || "Not provided";
  }

  get accountNumber() {
    return getFieldValue(this.account, ACCOUNT_NUMBER) || "Not provided";
  }

  get accountIndustry() {
    return getFieldValue(this.account, ACCOUNT_INDUSTRY) || "Not provided";
  }

  get hasAccountContext() {
    return Boolean(this.accountId);
  }

  get accountContextMissing() {
    return !this.hasAccountContext && !this.accountLoadError;
  }

  get itemCount() {
    return this.items.length;
  }

  get itemCountLabel() {
    return `${this.itemCount} ${this.itemCount === 1 ? "item" : "items"}`;
  }

  get hasItems() {
    return this.itemCount > 0;
  }

  get cartCount() {
    return this.cart.reduce((total, line) => total + line.quantity, 0);
  }

  get cartLabel() {
    return `Cart (${this.cartCount})`;
  }

  get typeOptions() {
    return [
      { label: "All types", value: "" },
      ...this.typeValues.map((value) => ({ label: value, value }))
    ];
  }

  get familyOptions() {
    return [
      { label: "All families", value: "" },
      ...this.familyValues.map((value) => ({
        label: value.replaceAll("_", " "),
        value
      }))
    ];
  }

  get createTypeOptions() {
    return this.typeValues.map((value) => ({ label: value, value }));
  }

  get createFamilyOptions() {
    return this.familyValues.map((value) => ({
      label: value.replaceAll("_", " "),
      value
    }));
  }

  get cartItems() {
    return this.cart.map((line) => {
      const price = Number(line.item.Price__c || 0);
      return {
        itemId: line.item.Id,
        name: line.item.Name,
        imageUrl: line.item.Image__c,
        price,
        quantity: line.quantity,
        availableQuantity: Number(line.item.AvailableQuantity__c || 0),
        lineTotal: price * line.quantity
      };
    });
  }

  handleSearchInput(event) {
    this.searchTerm = event.target.value || "";
    this.loadItems();
  }

  handleTypeChange(event) {
    this.selectedType = event.detail.value;
    this.loadItems();
  }

  handleFamilyChange(event) {
    this.selectedFamily = event.detail.value;
    this.loadItems();
  }

  handleShowDetails(event) {
    this.selectedItem = event.detail.item;
    this.isDetailsOpen = true;
  }

  closeDetails() {
    this.isDetailsOpen = false;
    this.selectedItem = undefined;
  }

  handleAddItem(event) {
    this.addToCart(event.detail.item);
  }

  handleDetailsAdd(event) {
    if (this.addToCart(event.detail.item)) {
      this.closeDetails();
    }
  }

  addToCart(item) {
    const availableQuantity = Number(item?.AvailableQuantity__c || 0);
    if (!item || availableQuantity <= 0) {
      this.showToast("Item unavailable", "This item is out of stock.", "error");
      return false;
    }

    const existingLine = this.cart.find((line) => line.item.Id === item.Id);
    const nextQuantity = (existingLine?.quantity || 0) + 1;
    if (nextQuantity > availableQuantity) {
      this.showToast(
        "Stock limit reached",
        `Only ${availableQuantity} units are available.`,
        "warning"
      );
      return false;
    }

    this.cart = existingLine
      ? this.cart.map((line) => {
          if (line.item.Id === item.Id) {
            return { item, quantity: nextQuantity };
          }
          return line;
        })
      : [...this.cart, { item, quantity: 1 }];
    this.showToast("Added to cart", `${item.Name} was added.`, "success");
    return true;
  }

  openCart() {
    this.isCartOpen = true;
  }

  closeCart() {
    if (!this.isCheckingOut) {
      this.isCartOpen = false;
    }
  }

  handleQuantityUpdate(event) {
    const { itemId, quantity } = event.detail;
    const line = this.cart.find((entry) => entry.item.Id === itemId);
    const availableQuantity = Number(line?.item.AvailableQuantity__c || 0);

    if (
      !line ||
      !Number.isInteger(quantity) ||
      quantity < 1 ||
      quantity > availableQuantity
    ) {
      this.showToast(
        "Invalid quantity",
        `Enter a whole number from 1 to ${availableQuantity}.`,
        "warning"
      );
      return;
    }

    this.cart = this.cart.map((entry) => {
      if (entry.item.Id === itemId) {
        return { ...entry, quantity };
      }
      return entry;
    });
  }

  handleRemoveItem(event) {
    this.cart = this.cart.filter(
      (line) => line.item.Id !== event.detail.itemId
    );
  }

  openCreate() {
    this.createError = undefined;
    this.isCreateOpen = true;
  }

  closeCreate() {
    if (!this.isCreating) {
      this.isCreateOpen = false;
      this.createError = undefined;
    }
  }

  async handleCreateItem(event) {
    this.isCreating = true;
    this.createError = undefined;

    try {
      const item = await createItem(event.detail);
      this.isCreateOpen = false;
      this.showToast(
        "Item created",
        `${item.Name} is now in the catalog.`,
        "success"
      );
      await this.loadItems();
    } catch (error) {
      this.createError = this.getErrorMessage(error);
      this.showToast("Item not created", this.createError, "error");
    } finally {
      this.isCreating = false;
    }
  }

  async handleCheckout() {
    if (!this.hasAccountContext || this.cart.length === 0) {
      return;
    }

    this.isCheckingOut = true;
    try {
      const purchaseId = await checkout({
        accountId: this.accountId,
        cartLines: this.cart.map((line) => ({
          itemId: line.item.Id,
          quantity: line.quantity
        }))
      });
      this.cart = [];
      this.isCartOpen = false;
      this.showToast(
        "Purchase created",
        "Checkout completed successfully.",
        "success"
      );
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: purchaseId,
          objectApiName: "Purchase__c",
          actionName: "view"
        }
      });
    } catch (error) {
      this.showToast("Checkout failed", this.getErrorMessage(error), "error");
      await this.loadItems();
    } finally {
      this.isCheckingOut = false;
    }
  }

  reconcileCart() {
    if (this.cart.length === 0) {
      return;
    }
    const itemsById = new Map(this.items.map((item) => [item.Id, item]));
    this.cart = this.cart.map((line) => ({
      item: itemsById.get(line.item.Id) || line.item,
      quantity: line.quantity
    }));
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  getErrorMessage(error) {
    if (Array.isArray(error?.body)) {
      return error.body.map((entry) => entry.message).join(", ");
    }
    return error?.body?.message || error?.message || "Unexpected error";
  }
}
