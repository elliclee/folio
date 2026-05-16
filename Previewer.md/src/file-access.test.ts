import test from 'node:test';
import assert from 'node:assert/strict';

import { readMarkdownFileWithFallback, writeMarkdownFileWithFallback } from './file-access';

test('readMarkdownFileWithFallback returns plugin-fs content when direct read succeeds', async () => {
  const directReads: string[] = [];
  const fallbackReads: string[] = [];

  const content = await readMarkdownFileWithFallback(
    '/tmp/doc.md',
    async (path) => {
      directReads.push(path);
      return '# direct';
    },
    async (path) => {
      fallbackReads.push(path);
      return '# fallback';
    },
  );

  assert.equal(content, '# direct');
  assert.deepEqual(directReads, ['/tmp/doc.md']);
  assert.deepEqual(fallbackReads, []);
});

test('readMarkdownFileWithFallback falls back to native command when direct read fails', async () => {
  const directReads: string[] = [];
  const fallbackReads: string[] = [];

  const content = await readMarkdownFileWithFallback(
    '/tmp/doc.md',
    async (path) => {
      directReads.push(path);
      throw new Error('plugin fs read failed');
    },
    async (path) => {
      fallbackReads.push(path);
      return '# fallback';
    },
  );

  assert.equal(content, '# fallback');
  assert.deepEqual(directReads, ['/tmp/doc.md']);
  assert.deepEqual(fallbackReads, ['/tmp/doc.md']);
});

test('writeMarkdownFileWithFallback writes directly when plugin-fs succeeds', async () => {
  const directWrites: Array<{ path: string; contents: string }> = [];
  const fallbackWrites: Array<{ path: string; contents: string }> = [];

  await writeMarkdownFileWithFallback(
    '/tmp/doc.md',
    '# direct',
    async (path, contents) => {
      directWrites.push({ path, contents });
    },
    async (path, contents) => {
      fallbackWrites.push({ path, contents });
    },
  );

  assert.deepEqual(directWrites, [{ path: '/tmp/doc.md', contents: '# direct' }]);
  assert.deepEqual(fallbackWrites, []);
});

test('writeMarkdownFileWithFallback falls back to native command when direct write fails', async () => {
  const directWrites: Array<{ path: string; contents: string }> = [];
  const fallbackWrites: Array<{ path: string; contents: string }> = [];

  await writeMarkdownFileWithFallback(
    '/tmp/doc.md',
    '# fallback',
    async (path, contents) => {
      directWrites.push({ path, contents });
      throw new Error('plugin fs write failed');
    },
    async (path, contents) => {
      fallbackWrites.push({ path, contents });
    },
  );

  assert.deepEqual(directWrites, [{ path: '/tmp/doc.md', contents: '# fallback' }]);
  assert.deepEqual(fallbackWrites, [{ path: '/tmp/doc.md', contents: '# fallback' }]);
});
