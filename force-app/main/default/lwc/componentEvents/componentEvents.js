export function dispatchCloseEvent(component, event) {
  event?.stopPropagation();
  component.dispatchEvent(new CustomEvent("close"));
}

export function dispatchItemEvent(component, eventName, item) {
  component.dispatchEvent(
    new CustomEvent(eventName, {
      detail: { item }
    })
  );
}
