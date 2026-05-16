type ShortcutEvent = {
  key: string;
  metaKey: boolean;
  ctrlKey: boolean;
  altKey: boolean;
};

function isCommandShortcut(event: ShortcutEvent, key: string) {
  return (
    !event.altKey &&
    (event.metaKey || event.ctrlKey) &&
    event.key.toLowerCase() === key
  );
}

export function isSaveShortcut(event: ShortcutEvent) {
  return isCommandShortcut(event, 's');
}

export function isFindShortcut(event: ShortcutEvent) {
  return isCommandShortcut(event, 'f');
}

export function isEscapeKey(event: ShortcutEvent) {
  return !event.metaKey && !event.ctrlKey && !event.altKey && event.key === 'Escape';
}
