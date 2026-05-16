import test from 'node:test';
import assert from 'node:assert/strict';

import {
  collectMarkdownTree,
  getExpandedDirectoryPaths,
  getFirstMarkdownFile,
  type DirectoryEntryLike,
  type MarkdownTreeNode,
} from './markdown-files';

const entriesByPath = new Map<string, DirectoryEntryLike[]>([
  ['/tmp/notes', [
    { name: 'guides', isDirectory: true },
    { name: 'assets', isDirectory: true },
    { name: 'zeta.txt', isFile: true },
    { name: 'README.MD', isFile: true },
  ]],
  ['/tmp/notes/guides', [
    { name: 'advanced', isDirectory: true },
    { name: 'alpha.md', isFile: true },
  ]],
  ['/tmp/notes/guides/advanced', [
    { name: 'beta.markdown', isFile: true },
    { name: 'notes.docx', isFile: true },
  ]],
  ['/tmp/notes/assets', [
    { name: 'logo.png', isFile: true },
  ]],
]);

const readDir = async (path: string) => entriesByPath.get(path) ?? [];
const joinPath = async (...parts: string[]) => parts.join('/');

test('collectMarkdownTree keeps nested directories only when they contain markdown descendants', async () => {
  const tree = await collectMarkdownTree('/tmp/notes', entriesByPath.get('/tmp/notes') ?? [], readDir, joinPath);

  assert.deepEqual(tree, [
    {
      type: 'directory',
      name: 'guides',
      path: '/tmp/notes/guides',
      children: [
        {
          type: 'directory',
          name: 'advanced',
          path: '/tmp/notes/guides/advanced',
          children: [
            { type: 'file', name: 'beta.markdown', path: '/tmp/notes/guides/advanced/beta.markdown' },
          ],
        },
        { type: 'file', name: 'alpha.md', path: '/tmp/notes/guides/alpha.md' },
      ],
    },
    { type: 'file', name: 'README.MD', path: '/tmp/notes/README.MD' },
    { type: 'file', name: 'zeta.txt', path: '/tmp/notes/zeta.txt' },
  ] satisfies MarkdownTreeNode[]);
});

test('collectMarkdownTree sorts directories and files by name within each level', async () => {
  const tree = await collectMarkdownTree('/tmp/notes', entriesByPath.get('/tmp/notes') ?? [], readDir, joinPath);

  assert.deepEqual(
    tree.map((node) => node.name),
    ['guides', 'README.MD', 'zeta.txt'],
  );

  assert.deepEqual(
    (tree[0] as Extract<MarkdownTreeNode, { type: 'directory' }>).children.map((node) => node.name),
    ['advanced', 'alpha.md'],
  );
});

test('collectMarkdownTree skips unreadable directories instead of failing the whole tree', async () => {
  const flakyReadDir = async (path: string) => {
    if (path === '/tmp/notes/guides/advanced') {
      throw new Error('permission denied');
    }

    return entriesByPath.get(path) ?? [];
  };

  const tree = await collectMarkdownTree(
    '/tmp/notes',
    entriesByPath.get('/tmp/notes') ?? [],
    flakyReadDir,
    joinPath,
  );

  assert.deepEqual(tree, [
    {
      type: 'directory',
      name: 'guides',
      path: '/tmp/notes/guides',
      children: [
        { type: 'file', name: 'alpha.md', path: '/tmp/notes/guides/alpha.md' },
      ],
    },
    { type: 'file', name: 'README.MD', path: '/tmp/notes/README.MD' },
    { type: 'file', name: 'zeta.txt', path: '/tmp/notes/zeta.txt' },
  ] satisfies MarkdownTreeNode[]);
});

test('collectMarkdownTree prefers entry paths when runtime provides them', async () => {
  const tree = await collectMarkdownTree(
    '/tmp/notes',
    [
      {
        name: 'linked.md',
        path: '/private/var/folders/runtime/linked.md',
        isFile: true,
      },
    ],
    readDir,
    joinPath,
  );

  assert.deepEqual(tree, [
    {
      type: 'file',
      name: 'linked.md',
      path: '/private/var/folders/runtime/linked.md',
    },
  ] satisfies MarkdownTreeNode[]);
});

test('getExpandedDirectoryPaths returns every directory path in the tree', () => {
  const tree: MarkdownTreeNode[] = [
    {
      type: 'directory',
      name: 'guides',
      path: '/tmp/notes/guides',
      children: [
        {
          type: 'directory',
          name: 'advanced',
          path: '/tmp/notes/guides/advanced',
          children: [{ type: 'file', name: 'beta.md', path: '/tmp/notes/guides/advanced/beta.md' }],
        },
      ],
    },
  ];

  assert.deepEqual(getExpandedDirectoryPaths(tree), [
    '/tmp/notes/guides',
    '/tmp/notes/guides/advanced',
  ]);
});

test('getFirstMarkdownFile returns the first leaf in tree order', () => {
  const tree: MarkdownTreeNode[] = [
    {
      type: 'directory',
      name: 'guides',
      path: '/tmp/notes/guides',
      children: [
        { type: 'file', name: 'alpha.md', path: '/tmp/notes/guides/alpha.md' },
      ],
    },
    { type: 'file', name: 'zeta.txt', path: '/tmp/notes/zeta.txt' },
  ];

  assert.deepEqual(getFirstMarkdownFile(tree), {
    type: 'file',
    name: 'alpha.md',
    path: '/tmp/notes/guides/alpha.md',
  });
});
