export function shouldStartWindowDrag(
  target: EventTarget | null,
  button: number,
  detail: number,
) {
  if (button !== 0 || detail > 1 || !isClosestCapable(target)) {
    return false;
  }

  return !target.closest('[data-no-drag="true"]');
}

export function shouldToggleWindowMaximize(
  target: EventTarget | null,
  button: number,
  detail: number,
) {
  if (button !== 0 || detail !== 2 || !isClosestCapable(target)) {
    return false;
  }

  return !target.closest('[data-no-drag="true"]');
}

function isClosestCapable(
  target: EventTarget | null,
): target is EventTarget & { closest: (selector: string) => Element | null } {
  return (
    typeof target === 'object' &&
    target !== null &&
    'closest' in target &&
    typeof target.closest === 'function'
  );
}
