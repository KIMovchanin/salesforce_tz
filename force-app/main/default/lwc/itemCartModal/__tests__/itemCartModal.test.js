import { createElement } from "lwc";
import ItemCartModal from "c/itemCartModal";

const CART_ITEMS = [
  {
    itemId: "a01000000000001AAA",
    name: "Desk Lamp",
    imageUrl: "https://images.unsplash.com/lamp",
    photographerName: "Jane Photographer",
    photographerUrl:
      "https://unsplash.com/@jane?utm_source=item_purchase_tool&utm_medium=referral",
    price: 25,
    quantity: 2,
    availableQuantity: 3,
    lineTotal: 50
  }
];

describe("c-item-cart-modal", () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it("emits quantity updates, removals, and checkout", () => {
    const element = createElement("c-item-cart-modal", {
      is: ItemCartModal
    });
    element.items = CART_ITEMS;
    element.accountAvailable = true;
    const updateHandler = jest.fn();
    const removeHandler = jest.fn();
    const checkoutHandler = jest.fn();
    element.addEventListener("updatequantity", updateHandler);
    element.addEventListener("removeitem", removeHandler);
    element.addEventListener("checkout", checkoutHandler);
    document.body.appendChild(element);

    const quantityInput = element.shadowRoot.querySelector("lightning-input");
    quantityInput.value = "3";
    quantityInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "3" } })
    );
    element.shadowRoot.querySelector("lightning-button-icon").click();
    const checkoutButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Checkout");
    checkoutButton.click();
    const image = element.shadowRoot.querySelector("c-item-image");

    expect(updateHandler.mock.calls[0][0].detail).toEqual({
      itemId: CART_ITEMS[0].itemId,
      quantity: 3
    });
    expect(removeHandler.mock.calls[0][0].detail.itemId).toBe(
      CART_ITEMS[0].itemId
    );
    expect(checkoutHandler).toHaveBeenCalledTimes(1);
    expect(image.photographerName).toBe(CART_ITEMS[0].photographerName);
    expect(image.photographerUrl).toBe(CART_ITEMS[0].photographerUrl);
  });

  it("blocks checkout for a stale quantity", () => {
    const element = createElement("c-item-cart-modal", {
      is: ItemCartModal
    });
    element.items = [{ ...CART_ITEMS[0], quantity: 4, availableQuantity: 3 }];
    element.accountAvailable = true;
    document.body.appendChild(element);

    const checkoutButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Checkout");

    expect(checkoutButton.disabled).toBe(true);
    expect(element.shadowRoot.querySelector("[role='alert']")).not.toBeNull();
  });

  it("restores the committed quantity after invalid input", () => {
    const element = createElement("c-item-cart-modal", {
      is: ItemCartModal
    });
    element.items = CART_ITEMS;
    element.accountAvailable = true;
    const updateHandler = jest.fn();
    element.addEventListener("updatequantity", updateHandler);
    document.body.appendChild(element);

    const quantityInput = element.shadowRoot.querySelector("lightning-input");
    jest.spyOn(quantityInput, "reportValidity").mockImplementation();
    quantityInput.value = "0";
    quantityInput.dispatchEvent(
      new CustomEvent("change", { detail: { value: "0" } })
    );

    expect(quantityInput.value).toBe(2);
    expect(quantityInput.reportValidity).toHaveBeenCalledTimes(1);
    expect(updateHandler.mock.calls[0][0].detail.quantity).toBe(0);
  });

  it("renders an empty state and disables checkout without lines", () => {
    const element = createElement("c-item-cart-modal", {
      is: ItemCartModal
    });
    element.accountAvailable = true;
    document.body.appendChild(element);

    const checkoutButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Checkout");

    expect(element.shadowRoot.querySelector(".empty-state")).not.toBeNull();
    expect(checkoutButton.disabled).toBe(true);
  });
});
