import test from 'node:test';
import assert from 'node:assert/strict';

import {
  createWorkspaceWindowLabel,
  createWorkspaceWindowUrl,
  getInitialFolderPathFromSearch,
  getInitialThemeFromSearch,
} from './workspace-window';

test('createWorkspaceWindowUrl encodes folder and theme for a new workspace window', () => {
  const url = createWorkspaceWindowUrl(
    {
      origin: 'tauri://localhost',
      pathname: '/index.html',
    },
    '/Users/ellic/Documents/Project Notes',
    'claude-dark',
  );

  assert.equal(
    url,
    'tauri://localhost/index.html?folder=%2FUsers%2Fellic%2FDocuments%2FProject+Notes&theme=claude-dark',
  );
});

test('search helpers recover initial folder path and theme from workspace urls', () => {
  const search = '?folder=%2Ftmp%2FDocs%2FREADME.md&theme=lovable';

  assert.equal(getInitialFolderPathFromSearch(search), '/tmp/Docs/README.md');
  assert.equal(getInitialThemeFromSearch(search), 'lovable');
});

test('search helpers return null when workspace params are absent', () => {
  assert.equal(getInitialFolderPathFromSearch(''), null);
  assert.equal(getInitialThemeFromSearch('?printMode=1'), null);
});

test('createWorkspaceWindowLabel keeps the workspace prefix for capability matching', () => {
  assert.match(createWorkspaceWindowLabel(), /^workspace-/);
});
