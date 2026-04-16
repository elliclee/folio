export function hasUnsavedChanges(markdown: string, savedMarkdown: string): boolean {
  return markdown !== savedMarkdown;
}

export function shouldConfirmBeforeReplacingFile(
  currentPath: string | null,
  nextPath: string,
  isDirty: boolean,
): boolean {
  return Boolean(currentPath && currentPath !== nextPath && isDirty);
}
