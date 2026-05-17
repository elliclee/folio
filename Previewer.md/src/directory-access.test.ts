import test from 'node:test';
import assert from 'node:assert/strict';

import { readDirectoryWithFallback } from './directory-access';
import type { DirectoryEntryLike } from './markdown-files';

test('readDirectoryWithFallback returns plugin-fs entries when direct read succeeds', async () => {
  const directEntries: DirectoryEntryLike[] = [
    { name: 'README.md', path: '/tmp/docs/README.md', isFile: true },
  ];

  const entries = await readDirectoryWithFallback(
    '/tmp/docs',
    async () => directEntries,
    async () => {
      throw new Error('should not use fallback');
    },
  );

  assert.deepEqual(entries, directEntries);
});

test('readDirectoryWithFallback uses native directory read when plugin-fs rejects saved paths', async () => {
  const fallbackEntries: DirectoryEntryLike[] = [
    { name: 'notes', path: '/tmp/docs/notes', isDirectory: true },
  ];

  const entries = await readDirectoryWithFallback(
    '/tmp/docs',
    async () => {
      throw new Error('forbidden path');
    },
    async (path) => {
      assert.equal(path, '/tmp/docs');
      return fallbackEntries;
    },
  );

  assert.deepEqual(entries, fallbackEntries);
});
