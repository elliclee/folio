import test from 'node:test';
import assert from 'node:assert/strict';

import {
  createStandaloneMarkdownFile,
  filterSupportedOpenPaths,
  findTreeFileByPath,
} from './opened-files';
import type { MarkdownTreeNode } from './markdown-files';

test('filterSupportedOpenPaths keeps only md and markdown files', () => {
  assert.deepEqual(
    filterSupportedOpenPaths([
      '/tmp/guide.md',
      '/tmp/spec.markdown',
      '/tmp/notes.txt',
      '/tmp/image.png',
    ]),
    ['/tmp/guide.md', '/tmp/spec.markdown'],
  );
});

test('findTreeFileByPath locates nested markdown leaves', () => {
  const tree: MarkdownTreeNode[] = [
    {
      type: 'directory',
      name: 'docs',
      path: '/tmp/docs',
      children: [
        {
          type: 'directory',
          name: 'guides',
          path: '/tmp/docs/guides',
          children: [
            {
              type: 'file',
              name: 'intro.md',
              path: '/tmp/docs/guides/intro.md',
            },
          ],
        },
      ],
    },
  ];

  assert.deepEqual(
    findTreeFileByPath(tree, '/tmp/docs/guides/intro.md'),
    {
      type: 'file',
      name: 'intro.md',
      path: '/tmp/docs/guides/intro.md',
    },
  );
});

test('createStandaloneMarkdownFile derives the leaf name from a path', () => {
  assert.deepEqual(
    createStandaloneMarkdownFile('/tmp/docs/guides/intro.md'),
    {
      type: 'file',
      name: 'intro.md',
      path: '/tmp/docs/guides/intro.md',
    },
  );
});
