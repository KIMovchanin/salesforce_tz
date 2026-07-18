import {
  getItemDescription,
  getItemStockClass,
  getItemStockLabel,
  isItemOutOfStock
} from "c/itemPresentation";

describe("c-item-presentation", () => {
  it("builds the available item presentation", () => {
    const item = {
      Description__c: "Adjustable LED lamp",
      AvailableQuantity__c: 3
    };

    expect(getItemDescription(item)).toBe("Adjustable LED lamp");
    expect(isItemOutOfStock(item)).toBe(false);
    expect(getItemStockLabel(item)).toBe("3 available");
    expect(getItemStockClass(item)).toBe("stock slds-text-color_success");
  });

  it("builds the missing and out-of-stock presentation", () => {
    expect(getItemDescription()).toBe("No description available");
    expect(isItemOutOfStock()).toBe(true);
    expect(getItemStockLabel()).toBe("Out of stock");
    expect(getItemStockClass()).toBe("stock slds-text-color_error");
  });
});
