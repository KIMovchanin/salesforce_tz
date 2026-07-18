import { createElement } from "lwc";
import ItemDetailsModal from "c/itemDetailsModal";

const ITEM = {
  Id: "a01000000000001AAA",
  Name: "Desk Lamp",
  Description__c: "Adjustable LED lamp",
  Type__c: "Product",
  Family__c: "Electronics",
  Price__c: 25,
  AvailableQuantity__c: 3
};

describe("c-item-details-modal", () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it("shows details and emits the selected item", () => {
    const element = createElement("c-item-details-modal", {
      is: ItemDetailsModal
    });
    element.item = ITEM;
    const addHandler = jest.fn();
    element.addEventListener("additem", addHandler);
    document.body.appendChild(element);

    const addButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Add to cart");
    addButton.click();

    expect(element.shadowRoot.querySelector(".description").textContent).toBe(
      ITEM.Description__c
    );
    expect(addHandler.mock.calls[0][0].detail.item).toEqual(ITEM);
  });

  it("disables adding when inventory is empty", () => {
    const element = createElement("c-item-details-modal", {
      is: ItemDetailsModal
    });
    element.item = { ...ITEM, AvailableQuantity__c: 0 };
    document.body.appendChild(element);

    const addButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Add to cart");

    expect(addButton.disabled).toBe(true);
  });
});
