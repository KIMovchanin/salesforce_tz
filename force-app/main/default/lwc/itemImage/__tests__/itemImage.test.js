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
    element.photographerName = "Jane Photographer";
    element.photographerUrl =
      "https://unsplash.com/@jane?utm_source=item_purchase_tool&utm_medium=referral";
    document.body.appendChild(element);

    const image = element.shadowRoot.querySelector("img");
    const links = element.shadowRoot.querySelectorAll("a");

    expect(image.src).toBe("https://images.unsplash.com/item");
    expect(image.alt).toBe("Desk Lamp");
    expect(image.getAttribute("loading")).toBe("lazy");
    expect(links).toHaveLength(2);
    expect(links[0].textContent).toBe("Jane Photographer");
    expect(links[0].getAttribute("href")).toBe(element.photographerUrl);
    expect(links[1].textContent).toBe("Unsplash");
    expect(links[1].getAttribute("href")).toBe(
      "https://unsplash.com/?utm_source=item_purchase_tool&utm_medium=referral"
    );
    links.forEach((link) => {
      expect(link.getAttribute("target")).toBe("_blank");
      expect(link.getAttribute("rel")).toBe("noopener noreferrer");
    });
    expect(element.shadowRoot.querySelector(".placeholder")).toBeNull();
  });

  it("hides an Unsplash image without trusted photographer attribution", () => {
    const element = createElement("c-item-image", { is: ItemImage });
    element.imageUrl = "https://images.unsplash.com/item";
    element.photographerName = "Unsupported";
    element.photographerUrl = "https://example.com/profile";
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("img")).toBeNull();
    expect(element.shadowRoot.querySelector(".attribution")).toBeNull();
    expect(element.shadowRoot.querySelector(".placeholder")).not.toBeNull();
  });

  it("does not attribute a non-Unsplash image to Unsplash", () => {
    const element = createElement("c-item-image", { is: ItemImage });
    element.imageUrl = "https://example.com/item.jpg";
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("img")).not.toBeNull();
    expect(element.shadowRoot.querySelector(".attribution")).toBeNull();
  });

  it("renders a placeholder without an image URL", () => {
    const element = createElement("c-item-image", { is: ItemImage });
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector("img")).toBeNull();
    expect(element.shadowRoot.querySelector(".placeholder")).not.toBeNull();
  });
});
