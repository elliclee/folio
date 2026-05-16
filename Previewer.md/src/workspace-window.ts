type WorkspaceLocation = Pick<Location, 'origin' | 'pathname'>;

const WORKSPACE_SEARCH_PARAM = 'folder';
const WORKSPACE_THEME_SEARCH_PARAM = 'theme';

export function createWorkspaceWindowUrl(
  location: WorkspaceLocation,
  folderPath: string,
  theme?: string | null,
) {
  const url = new URL(location.pathname, location.origin);
  url.searchParams.set(WORKSPACE_SEARCH_PARAM, folderPath);

  if (theme) {
    url.searchParams.set(WORKSPACE_THEME_SEARCH_PARAM, theme);
  }

  return url.toString();
}

export function getInitialFolderPathFromSearch(search: string) {
  return new URLSearchParams(search).get(WORKSPACE_SEARCH_PARAM);
}

export function getInitialThemeFromSearch(search: string) {
  return new URLSearchParams(search).get(WORKSPACE_THEME_SEARCH_PARAM);
}

export function createWorkspaceWindowLabel() {
  return `workspace-${crypto.randomUUID()}`;
}
