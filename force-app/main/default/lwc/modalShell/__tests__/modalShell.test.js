import { createElement } from "lwc";
import ModalShell from "c/modalShell";

describe("c-modal-shell", () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it("renders its heading and closes from the close button", () => {
    const element = createElement("c-modal-shell", { is: ModalShell });
    element.heading = "Cart";
    const closeHandler = jest.fn();
    element.addEventListener("close", closeHandler);
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("h2").textContent.trim()).toBe(
      "Cart"
    );
    element.shadowRoot.querySelector("lightning-button-icon").click();

    expect(closeHandler).toHaveBeenCalledTimes(1);
  });

  it("closes when Escape is pressed", () => {
    const element = createElement("c-modal-shell", { is: ModalShell });
    const closeHandler = jest.fn();
    element.addEventListener("close", closeHandler);
    document.body.appendChild(element);

    element.shadowRoot
      .querySelector("section")
      .dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));

    expect(closeHandler).toHaveBeenCalledTimes(1);
  });
});
