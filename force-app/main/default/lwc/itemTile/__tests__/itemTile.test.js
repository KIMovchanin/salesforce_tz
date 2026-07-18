import { createElement } from "lwc";
import ItemTile from "c/itemTile";

const ITEM = {
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
};

describe("c-item-tile", () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it("renders item data and emits selection events", () => {
    const element = createElement("c-item-tile", { is: ItemTile });
    element.item = ITEM;
    const detailsHandler = jest.fn();
    const addHandler = jest.fn();
    element.addEventListener("showdetails", detailsHandler);
    element.addEventListener("additem", addHandler);
    document.body.appendChild(element);

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    buttons[0].click();
    buttons[1].click();

    expect(element.shadowRoot.querySelector("h3").textContent.trim()).toBe(
      "Desk Lamp"
    );
    const image = element.shadowRoot.querySelector("c-item-image");
    expect(image.photographerName).toBe(ITEM.Unsplash_Photographer__c);
    expect(image.photographerUrl).toBe(ITEM.Unsplash_Profile_URL__c);
    expect(detailsHandler.mock.calls[0][0].detail.item).toEqual(ITEM);
    expect(addHandler.mock.calls[0][0].detail.item).toEqual(ITEM);
  });

  it("prevents adding an out-of-stock item", () => {
    const element = createElement("c-item-tile", { is: ItemTile });
    element.item = { ...ITEM, AvailableQuantity__c: 0 };
    document.body.appendChild(element);

    const addButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Add");

    expect(addButton.disabled).toBe(true);
    expect(element.shadowRoot.querySelector(".stock").textContent).toContain(
      "Out of stock"
    );
  });
});
