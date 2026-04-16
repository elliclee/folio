import test from 'node:test';
import assert from 'node:assert/strict';

import { collectMarkdownFiles } from './markdown-files';

test('collectMarkdownFiles keeps only markdown-ish files, builds paths, and sorts them by name', async () => {
  const files = await collectMarkdownFiles('/tmp/notes', [
    { name: 'zeta.txt', isFile: true },
    { name: 'assets', isDirectory: true },
    { name: 'alpha.md', isFile: true },
    { name: 'README.MD', isFile: true },
    { name: 'todo.docx', isFile: true },
  ], async (...parts) => parts.join('/'));

  assert.deepEqual(files, [
    { name: 'alpha.md', path: '/tmp/notes/alpha.md' },
    { name: 'README.MD', path: '/tmp/notes/README.MD' },
    { name: 'zeta.txt', path: '/tmp/notes/zeta.txt' },
  ]);
});
