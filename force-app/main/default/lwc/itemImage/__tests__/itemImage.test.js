import { createElement } from "lwc";
import ItemImage from "c/itemImage";

describe("c-item-image", () => {
  afterEach(() => {
    document.body.replaceChildren();
  });

  it("renders a configured image", () => {
    const element = createElement("c-item-image", { is: ItemImage });
    element.imageUrl = "https://images.unsplash.com/item";
    element.alternativeText = "Desk Lamp";
    element.loading = "lazy";
    document.body.appendChild(element);

    const image = element.shadowRoot.querySelector("img");

    expect(image.src).toBe("https://images.unsplash.com/item");
    expect(image.alt).toBe("Desk Lamp");
    expect(image.getAttribute("loading")).toBe("lazy");
    expect(element.shadowRoot.querySelector(".placeholder")).toBeNull();
  });

  it("renders a placeholder without an image URL", () => {
    const element = createElement("c-item-image", { is: ItemImage });
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("img")).toBeNull();
    expect(element.shadowRoot.querySelector(".placeholder")).not.toBeNull();
  });
});
