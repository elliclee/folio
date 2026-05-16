export type ResolveTerminalCwdOptions = {
  currentFolderPath: string | null;
  activeFilePath: string | null;
  initialFolderPath: string | null;
  fallbackPath: string;
};

function getParentPath(path: string) {
  const normalized = path.replace(/[/\\]+$/, '');
  const separatorIndex = Math.max(normalized.lastIndexOf('/'), normalized.lastIndexOf('\\'));

  if (separatorIndex <= 0) {
    return normalized;
  }

  return normalized.slice(0, separatorIndex);
}

export function resolveTerminalCwd({
  currentFolderPath,
  activeFilePath,
  initialFolderPath,
  fallbackPath,
}: ResolveTerminalCwdOptions) {
  return currentFolderPath
    ?? (activeFilePath ? getParentPath(activeFilePath) : null)
    ?? initialFolderPath
    ?? fallbackPath;
}
