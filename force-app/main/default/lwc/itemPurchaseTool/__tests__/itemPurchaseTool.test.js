import { createElement } from "lwc";
import * as uiRecordApi from "lightning/uiRecordApi";
import * as navigation from "lightning/navigation";
import ItemPurchaseTool from "c/itemPurchaseTool";
import searchItems from "@salesforce/apex/PurchaseToolController.searchItems";
import getFilterOptions from "@salesforce/apex/PurchaseToolController.getFilterOptions";
import isCurrentUserManager from "@salesforce/apex/PurchaseToolController.isCurrentUserManager";
import createItem from "@salesforce/apex/PurchaseToolController.createItem";
import checkout from "@salesforce/apex/PurchaseToolController.checkout";

jest.mock("lightning/navigation", () => {
  const actual = jest.requireActual("lightning/navigation");
  const navigate = jest.fn();
  const Navigate = Symbol("Navigate");
  const NavigationMixin = (Base) =>
    class extends Base {
      [Navigate](pageReference) {
        navigate(pageReference);
      }
    };
  NavigationMixin.Navigate = Navigate;
  return {
    ...actual,
    NavigationMixin,
    mockNavigate: navigate
  };
});

jest.mock(
  "@salesforce/apex/PurchaseToolController.searchItems",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/PurchaseToolController.getFilterOptions",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/PurchaseToolController.isCurrentUserManager",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/PurchaseToolController.createItem",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/PurchaseToolController.checkout",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const ACCOUNT_ID = "001000000000001AAA";
const PURCHASE_ID = "a02000000000001AAA";
const CATALOG = [
  {
    Id: "a01000000000001AAA",
    Name: "Desk Lamp",
    Description__c: "Adjustable LED lamp",
    Type__c: "Product",
    Family__c: "Electronics",
    Image__c: "https://images.unsplash.com/lamp",
    Unsplash_Photographer__c: "Jane Photographer",
    Unsplash_Profile_URL__c:
      "https://unsplash.com/@jane?utm_source=item_purchase_tool&utm_medium=referral",
    Price__c: 25,
    AvailableQuantity__c: 3
  },
  {
    Id: "a01000000000002AAA",
    Name: "Office Chair",
    Description__c: "Ergonomic chair",
    Type__c: "Product",
    Family__c: "Furniture",
    Price__c: 150,
    AvailableQuantity__c: 2
  }
];

const ACCOUNT = {
  fields: {
    Name: { value: "Acme" },
    AccountNumber: { value: "AC-42" },
    Industry: { value: "Technology" }
  }
};

const flushPromises = async () => {
  await Promise.resolve();
  await Promise.resolve();
};

describe("c-item-purchase-tool", () => {
  beforeEach(() => {
    searchItems.mockResolvedValue(CATALOG);
    getFilterOptions.mockResolvedValue({
      types: ["Product", "Accessory"],
      families: ["Electronics", "Furniture"]
    });
    isCurrentUserManager.mockResolvedValue(true);
    createItem.mockResolvedValue(CATALOG[0]);
    checkout.mockResolvedValue(PURCHASE_ID);
  });

  afterEach(() => {
    document.body.replaceChildren();
    jest.clearAllMocks();
    jest.useRealTimers();
  });

  it("loads the account context, catalog, filters, and manager action", async () => {
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    document.body.appendChild(element);
    navigation.CurrentPageReference.emit({
      state: { c__accountId: ACCOUNT_ID }
    });
    uiRecordApi.getRecord.emit(ACCOUNT);
    await flushPromises();

    const accountValues = [
      ...element.shadowRoot.querySelectorAll(".account-details dd")
    ].map((node) => node.textContent.trim());

    expect(searchItems).toHaveBeenCalledWith({
      family: null,
      type: null,
      searchTerm: null
    });
    expect(accountValues).toEqual(["Acme", "AC-42", "Technology"]);
    expect(element.shadowRoot.querySelectorAll("c-item-tile")).toHaveLength(2);
    expect(
      element.shadowRoot.querySelector(".count-badge").textContent
    ).toContain("2 items");
    expect(
      [...element.shadowRoot.querySelectorAll("lightning-button")].some(
        (button) => button.label === "Create item"
      )
    ).toBe(true);
  });

  it("keeps cart lines when catalog filters hide the selected item", async () => {
    searchItems
      .mockResolvedValueOnce(CATALOG)
      .mockResolvedValueOnce([CATALOG[1]]);
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot
      .querySelector("c-item-tile")
      .dispatchEvent(
        new CustomEvent("additem", { detail: { item: CATALOG[0] } })
      );
    const typeFilter = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.name === "typeFilter");
    typeFilter.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Product" } })
    );
    await flushPromises();
    expect(searchItems).toHaveBeenLastCalledWith({
      family: null,
      type: "Product",
      searchTerm: null
    });
    const cartButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label.startsWith("Cart"));
    cartButton.click();
    await Promise.resolve();

    const cartModal = element.shadowRoot.querySelector("c-item-cart-modal");
    expect(cartModal.items).toHaveLength(1);
    expect(cartModal.items[0].itemId).toBe(CATALOG[0].Id);
    expect(cartModal.items[0].photographerName).toBe(
      CATALOG[0].Unsplash_Photographer__c
    );
    expect(cartModal.items[0].photographerUrl).toBe(
      CATALOG[0].Unsplash_Profile_URL__c
    );
  });

  it("opens item details and adds the selected item from the modal", async () => {
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot
      .querySelector("c-item-tile")
      .dispatchEvent(
        new CustomEvent("showdetails", { detail: { item: CATALOG[0] } })
      );
    await Promise.resolve();

    const detailsModal = element.shadowRoot.querySelector(
      "c-item-details-modal"
    );
    expect(detailsModal.item).toEqual(CATALOG[0]);

    detailsModal.dispatchEvent(
      new CustomEvent("additem", { detail: { item: CATALOG[0] } })
    );
    await Promise.resolve();

    expect(element.shadowRoot.querySelector("c-item-details-modal")).toBeNull();
    const cartButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label.startsWith("Cart"));
    expect(cartButton.label).toBe("Cart (1)");
  });

  it("applies cart quantity updates and removals to parent state", async () => {
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    document.body.appendChild(element);
    await flushPromises();

    const tiles = element.shadowRoot.querySelectorAll("c-item-tile");
    tiles[0].dispatchEvent(
      new CustomEvent("additem", { detail: { item: CATALOG[0] } })
    );
    tiles[1].dispatchEvent(
      new CustomEvent("additem", { detail: { item: CATALOG[1] } })
    );
    const cartButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label.startsWith("Cart"));
    cartButton.click();
    await Promise.resolve();

    element.shadowRoot.querySelector("c-item-cart-modal").dispatchEvent(
      new CustomEvent("updatequantity", {
        detail: { itemId: CATALOG[0].Id, quantity: 3 }
      })
    );
    await Promise.resolve();

    let cartModal = element.shadowRoot.querySelector("c-item-cart-modal");
    expect(cartModal.items).toEqual([
      expect.objectContaining({ itemId: CATALOG[0].Id, quantity: 3 }),
      expect.objectContaining({ itemId: CATALOG[1].Id, quantity: 1 })
    ]);
    expect(cartButton.label).toBe("Cart (4)");

    cartModal.dispatchEvent(
      new CustomEvent("removeitem", {
        detail: { itemId: CATALOG[1].Id }
      })
    );
    await Promise.resolve();

    cartModal = element.shadowRoot.querySelector("c-item-cart-modal");
    expect(cartModal.items).toEqual([
      expect.objectContaining({ itemId: CATALOG[0].Id, quantity: 3 })
    ]);
    expect(cartButton.label).toBe("Cart (3)");
  });

  it("searches text and combines it with family filters", async () => {
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    document.body.appendChild(element);
    await flushPromises();

    const searchInput = [
      ...element.shadowRoot.querySelectorAll("lightning-input")
    ].find((input) => input.type === "search");
    searchInput.value = "lamp";
    searchInput.dispatchEvent(new CustomEvent("change"));
    await flushPromises();
    expect(searchItems).toHaveBeenLastCalledWith({
      family: null,
      type: null,
      searchTerm: "lamp"
    });

    const familyFilter = [
      ...element.shadowRoot.querySelectorAll("lightning-combobox")
    ].find((combobox) => combobox.name === "familyFilter");
    familyFilter.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Electronics" } })
    );
    await flushPromises();
    expect(searchItems).toHaveBeenLastCalledWith({
      family: "Electronics",
      type: null,
      searchTerm: "lamp"
    });
  });

  it("hides manager creation controls for a regular user", async () => {
    isCurrentUserManager.mockResolvedValue(false);
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(
      [...element.shadowRoot.querySelectorAll("lightning-button")].some(
        (button) => button.label === "Create item"
      )
    ).toBe(false);
  });

  it("rejects an out-of-stock item even if an add event is forced", async () => {
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot.querySelector("c-item-tile").dispatchEvent(
      new CustomEvent("additem", {
        detail: {
          item: { ...CATALOG[0], AvailableQuantity__c: 0 }
        }
      })
    );

    const cartButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label.startsWith("Cart"));
    expect(cartButton.label).toBe("Cart (0)");
    expect(toastHandler.mock.calls[0][0].detail.variant).toBe("error");
  });

  it("checks out the cart and navigates to the Purchase record", async () => {
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    document.body.appendChild(element);
    navigation.CurrentPageReference.emit({
      state: { c__accountId: ACCOUNT_ID }
    });
    await flushPromises();

    element.shadowRoot
      .querySelector("c-item-tile")
      .dispatchEvent(
        new CustomEvent("additem", { detail: { item: CATALOG[0] } })
      );
    const cartButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label.startsWith("Cart"));
    cartButton.click();
    await Promise.resolve();
    element.shadowRoot
      .querySelector("c-item-cart-modal")
      .dispatchEvent(new CustomEvent("checkout"));
    await flushPromises();

    expect(checkout).toHaveBeenCalledWith({
      accountId: ACCOUNT_ID,
      cartLines: [{ itemId: CATALOG[0].Id, quantity: 1 }]
    });
    expect(navigation.mockNavigate).toHaveBeenCalledWith({
      type: "standard__recordPage",
      attributes: {
        recordId: PURCHASE_ID,
        objectApiName: "Purchase__c",
        actionName: "view"
      }
    });
    expect(element.shadowRoot.querySelector("c-item-cart-modal")).toBeNull();
  });

  it("delegates manager item creation to Apex and refreshes the catalog", async () => {
    const element = createElement("c-item-purchase-tool", {
      is: ItemPurchaseTool
    });
    document.body.appendChild(element);
    await flushPromises();

    const createButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Create item");
    createButton.click();
    await Promise.resolve();
    const payload = {
      name: "Desk Lamp",
      description: "Adjustable LED lamp",
      type: "Product",
      family: "Electronics",
      price: 25,
      availableQuantity: 3
    };
    element.shadowRoot
      .querySelector("c-item-create-modal")
      .dispatchEvent(new CustomEvent("saveitem", { detail: payload }));
    await flushPromises();

    expect(createItem).toHaveBeenCalledWith(payload);
    expect(searchItems).toHaveBeenCalledTimes(2);
    expect(element.shadowRoot.querySelector("c-item-create-modal")).toBeNull();
  });
});
