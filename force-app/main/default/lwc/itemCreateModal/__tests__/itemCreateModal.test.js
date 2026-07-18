import { createElement } from "lwc";
import ItemCreateModal from "c/itemCreateModal";

const VALUES = {
  name: "Desk Lamp",
  description: "Adjustable LED lamp",
  type: "Product",
  family: "Electronics",
  price: "25.50",
  availableQuantity: "4"
};

describe("c-item-create-modal", () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it("normalizes valid form values and requests item creation", () => {
    const element = createElement("c-item-create-modal", {
      is: ItemCreateModal
    });
    element.typeOptions = [{ label: "Product", value: "Product" }];
    element.familyOptions = [{ label: "Electronics", value: "Electronics" }];
    const saveHandler = jest.fn();
    element.addEventListener("saveitem", saveHandler);
    document.body.appendChild(element);

    const fields = element.shadowRoot.querySelectorAll(
      "lightning-input, lightning-textarea, lightning-combobox"
    );
    fields.forEach((field) => {
      const value = VALUES[field.name];
      field.value = value;
      jest.spyOn(field, "checkValidity").mockReturnValue(true);
      jest.spyOn(field, "reportValidity").mockImplementation();
      field.dispatchEvent(new CustomEvent("change", { detail: { value } }));
    });

    const saveButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Create item");
    saveButton.click();

    expect(saveHandler.mock.calls[0][0].detail).toEqual({
      name: "Desk Lamp",
      description: "Adjustable LED lamp",
      type: "Product",
      family: "Electronics",
      price: 25.5,
      availableQuantity: 4
    });
  });

  it("does not submit when a field is invalid", () => {
    const element = createElement("c-item-create-modal", {
      is: ItemCreateModal
    });
    const saveHandler = jest.fn();
    element.addEventListener("saveitem", saveHandler);
    document.body.appendChild(element);

    const fields = element.shadowRoot.querySelectorAll(
      "lightning-input, lightning-textarea, lightning-combobox"
    );
    fields.forEach((field, index) => {
      jest.spyOn(field, "checkValidity").mockReturnValue(index !== 0);
      jest.spyOn(field, "reportValidity").mockImplementation();
    });
    const saveButton = [
      ...element.shadowRoot.querySelectorAll("lightning-button")
    ].find((button) => button.label === "Create item");
    saveButton.click();

    expect(saveHandler).not.toHaveBeenCalled();
  });
});
