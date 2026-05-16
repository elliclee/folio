import test from 'node:test';
import assert from 'node:assert/strict';

import {
  resolveTerminalCwd,
} from './terminal-session';

test('resolveTerminalCwd prefers the currently opened folder', () => {
  assert.equal(
    resolveTerminalCwd({
      currentFolderPath: '/Users/ellic/docs',
      activeFilePath: '/tmp/notes/readme.md',
      initialFolderPath: '/tmp/bootstrap',
      fallbackPath: '/Users/ellic',
    }),
    '/Users/ellic/docs',
  );
});

test('resolveTerminalCwd falls back to the active file directory', () => {
  assert.equal(
    resolveTerminalCwd({
      currentFolderPath: null,
      activeFilePath: '/Users/ellic/docs/readme.md',
      initialFolderPath: null,
      fallbackPath: '/Users/ellic',
    }),
    '/Users/ellic/docs',
  );
});

test('resolveTerminalCwd uses initial folder before fallback', () => {
  assert.equal(
    resolveTerminalCwd({
      currentFolderPath: null,
      activeFilePath: null,
      initialFolderPath: '/Users/ellic/bootstrap',
      fallbackPath: '/Users/ellic',
    }),
    '/Users/ellic/bootstrap',
  );
});

test('resolveTerminalCwd returns fallback when no workspace context exists', () => {
  assert.equal(
    resolveTerminalCwd({
      currentFolderPath: null,
      activeFilePath: null,
      initialFolderPath: null,
      fallbackPath: '/Users/ellic',
    }),
    '/Users/ellic',
  );
});

test('resolveTerminalCwd keeps the terminal target focused on folders only', () => {
  assert.equal(
    resolveTerminalCwd({
      currentFolderPath: null,
      activeFilePath: 'C:\\Users\\ellic\\docs\\readme.md',
      initialFolderPath: null,
      fallbackPath: 'C:\\Users\\ellic',
    }),
    'C:\\Users\\ellic\\docs',
  );
});
