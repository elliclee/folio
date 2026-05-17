import test from 'node:test';
import assert from 'node:assert/strict';

import {
  clearRecentWorkspaceFolders,
  createWorkspaceFolder,
  getRecentWorkspaceFolders,
  loadWorkspaceFolders,
  pinWorkspaceFolder,
  rememberRecentWorkspaceFolder,
  removeWorkspaceFolder,
  saveWorkspaceFolders,
  unpinWorkspaceFolder,
  type WorkspaceFolderState,
} from './workspace-folders';

class MemoryStorage implements Pick<Storage, 'getItem' | 'setItem'> {
  private entries = new Map<string, string>();

  getItem(key: string) {
    return this.entries.get(key) ?? null;
  }

  setItem(key: string, value: string) {
    this.entries.set(key, value);
  }
}

test('rememberRecentWorkspaceFolder moves a folder to the top and limits history', () => {
  let state: WorkspaceFolderState = {
    pinned: [],
    recent: [
      createWorkspaceFolder('/tmp/one'),
      createWorkspaceFolder('/tmp/two'),
      createWorkspaceFolder('/tmp/three'),
      createWorkspaceFolder('/tmp/four'),
      createWorkspaceFolder('/tmp/five'),
      createWorkspaceFolder('/tmp/six'),
    ],
  };

  state = rememberRecentWorkspaceFolder(state, '/tmp/three');

  assert.deepEqual(
    state.recent.map((folder) => folder.path),
    ['/tmp/three', '/tmp/one', '/tmp/two', '/tmp/four', '/tmp/five'],
  );
});

test('pinWorkspaceFolder adds a pinned folder once and removes it from visible recents', () => {
  const state = pinWorkspaceFolder(
    {
      pinned: [createWorkspaceFolder('/tmp/docs')],
      recent: [
        createWorkspaceFolder('/tmp/docs'),
        createWorkspaceFolder('/tmp/notes'),
      ],
    },
    '/tmp/docs',
  );

  assert.deepEqual(state.pinned.map((folder) => folder.path), ['/tmp/docs']);
  assert.deepEqual(getRecentWorkspaceFolders(state).map((folder) => folder.path), ['/tmp/notes']);
});

test('unpinWorkspaceFolder keeps the folder available in recent history', () => {
  const state = unpinWorkspaceFolder(
    {
      pinned: [createWorkspaceFolder('/tmp/docs')],
      recent: [],
    },
    '/tmp/docs',
  );

  assert.deepEqual(state.pinned, []);
  assert.deepEqual(state.recent.map((folder) => folder.path), ['/tmp/docs']);
});

test('removeWorkspaceFolder deletes a path from pinned and recent lists', () => {
  const state = removeWorkspaceFolder(
    {
      pinned: [createWorkspaceFolder('/tmp/docs')],
      recent: [
        createWorkspaceFolder('/tmp/docs'),
        createWorkspaceFolder('/tmp/notes'),
      ],
    },
    '/tmp/docs',
  );

  assert.deepEqual(state.pinned, []);
  assert.deepEqual(state.recent.map((folder) => folder.path), ['/tmp/notes']);
});

test('clearRecentWorkspaceFolders removes recent folders and keeps pinned folders', () => {
  const pinned = [createWorkspaceFolder('/tmp/docs')];
  const state = clearRecentWorkspaceFolders({
    pinned,
    recent: [
      createWorkspaceFolder('/tmp/docs'),
      createWorkspaceFolder('/tmp/notes'),
    ],
  });

  assert.deepEqual(state, {
    pinned,
    recent: [],
  });
});

test('workspace folders persist through storage and ignore malformed data', () => {
  const storage = new MemoryStorage();
  const state: WorkspaceFolderState = {
    pinned: [createWorkspaceFolder('/Users/ellic/Notes')],
    recent: [createWorkspaceFolder('/Users/ellic/Repos/app')],
  };

  saveWorkspaceFolders(storage, state);

  assert.deepEqual(loadWorkspaceFolders(storage), state);

  storage.setItem('previewermd.workspaceFolders.v1', '{"pinned":[{"path":7}]}');

  assert.deepEqual(loadWorkspaceFolders(storage), { pinned: [], recent: [] });
});

test('workspace folder persistence tolerates unavailable browser storage', () => {
  const state = { pinned: [createWorkspaceFolder('/tmp/docs')], recent: [] };

  assert.deepEqual(loadWorkspaceFolders(undefined), { pinned: [], recent: [] });
  assert.doesNotThrow(() => saveWorkspaceFolders(undefined, state));
});
