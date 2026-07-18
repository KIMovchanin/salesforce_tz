export function getItemDescription(item) {
  return item?.Description__c || "No description available";
}

export function isItemOutOfStock(item) {
  return Number(item?.AvailableQuantity__c || 0) <= 0;
}

export function getItemStockLabel(item) {
  return isItemOutOfStock(item)
    ? "Out of stock"
    : `${item.AvailableQuantity__c} available`;
}

export function getItemStockClass(item) {
  return isItemOutOfStock(item)
    ? "stock slds-text-color_error"
    : "stock slds-text-color_success";
}
