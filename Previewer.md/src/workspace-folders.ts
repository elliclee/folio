export type WorkspaceFolder = {
  name: string;
  path: string;
};

export type WorkspaceFolderState = {
  pinned: WorkspaceFolder[];
  recent: WorkspaceFolder[];
};

export const WORKSPACE_FOLDERS_STORAGE_KEY = 'previewermd.workspaceFolders.v1';
const MAX_RECENT_WORKSPACE_FOLDERS = 5;

type WorkspaceFolderStorage = Pick<Storage, 'getItem' | 'setItem'> | null | undefined;

function getFolderName(path: string) {
  const normalizedPath = path.replace(/[\\/]+$/, '');
  const segments = normalizedPath.split(/[\\/]/);
  return segments.at(-1) || normalizedPath || path;
}

function dedupeFolders(folders: WorkspaceFolder[]) {
  const seen = new Set<string>();
  const deduped: WorkspaceFolder[] = [];

  for (const folder of folders) {
    if (seen.has(folder.path)) {
      continue;
    }

    seen.add(folder.path);
    deduped.push(folder);
  }

  return deduped;
}

function isWorkspaceFolder(value: unknown): value is WorkspaceFolder {
  return (
    typeof value === 'object'
    && value !== null
    && typeof (value as WorkspaceFolder).name === 'string'
    && typeof (value as WorkspaceFolder).path === 'string'
  );
}

function normalizeWorkspaceFolderState(value: unknown): WorkspaceFolderState {
  if (typeof value !== 'object' || value === null) {
    return { pinned: [], recent: [] };
  }

  const candidate = value as Partial<WorkspaceFolderState>;
  const pinned = Array.isArray(candidate.pinned)
    ? dedupeFolders(candidate.pinned.filter(isWorkspaceFolder))
    : [];
  const recent = Array.isArray(candidate.recent)
    ? dedupeFolders(candidate.recent.filter(isWorkspaceFolder)).slice(0, MAX_RECENT_WORKSPACE_FOLDERS)
    : [];

  return { pinned, recent };
}

export function createWorkspaceFolder(path: string): WorkspaceFolder {
  return {
    name: getFolderName(path),
    path,
  };
}

export function rememberRecentWorkspaceFolder(
  state: WorkspaceFolderState,
  folderPath: string,
): WorkspaceFolderState {
  const folder = createWorkspaceFolder(folderPath);
  const recent = [
    folder,
    ...state.recent.filter((item) => item.path !== folder.path),
  ].slice(0, MAX_RECENT_WORKSPACE_FOLDERS);

  return {
    pinned: dedupeFolders(state.pinned),
    recent,
  };
}

export function pinWorkspaceFolder(
  state: WorkspaceFolderState,
  folderPath: string,
): WorkspaceFolderState {
  const folder = createWorkspaceFolder(folderPath);

  return {
    pinned: dedupeFolders([
      ...state.pinned,
      folder,
    ]),
    recent: dedupeFolders(state.recent),
  };
}

export function unpinWorkspaceFolder(
  state: WorkspaceFolderState,
  folderPath: string,
): WorkspaceFolderState {
  return rememberRecentWorkspaceFolder(
    {
      pinned: state.pinned.filter((folder) => folder.path !== folderPath),
      recent: state.recent,
    },
    folderPath,
  );
}

export function removeWorkspaceFolder(
  state: WorkspaceFolderState,
  folderPath: string,
): WorkspaceFolderState {
  return {
    pinned: state.pinned.filter((folder) => folder.path !== folderPath),
    recent: state.recent.filter((folder) => folder.path !== folderPath),
  };
}

export function clearRecentWorkspaceFolders(state: WorkspaceFolderState): WorkspaceFolderState {
  return {
    pinned: state.pinned,
    recent: [],
  };
}

export function getRecentWorkspaceFolders(state: WorkspaceFolderState) {
  const pinnedPaths = new Set(state.pinned.map((folder) => folder.path));
  return state.recent.filter((folder) => !pinnedPaths.has(folder.path));
}

export function loadWorkspaceFolders(storage: WorkspaceFolderStorage): WorkspaceFolderState {
  if (!storage) {
    return { pinned: [], recent: [] };
  }

  const rawValue = storage.getItem(WORKSPACE_FOLDERS_STORAGE_KEY);
  if (!rawValue) {
    return { pinned: [], recent: [] };
  }

  try {
    return normalizeWorkspaceFolderState(JSON.parse(rawValue));
  } catch {
    return { pinned: [], recent: [] };
  }
}

export function saveWorkspaceFolders(
  storage: WorkspaceFolderStorage,
  state: WorkspaceFolderState,
) {
  if (!storage) {
    return;
  }

  storage.setItem(
    WORKSPACE_FOLDERS_STORAGE_KEY,
    JSON.stringify(normalizeWorkspaceFolderState(state)),
  );
}
