import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';

const appPath = join(process.cwd(), 'src', 'App.tsx');

test('embedded terminal runtime is not part of the app shell', () => {
  const source = readFileSync(appPath, 'utf8');

  assert.doesNotMatch(source, /from ['"]@xterm\/xterm['"]/);
  assert.doesNotMatch(source, /from ['"]@xterm\/addon-fit['"]/);
  assert.doesNotMatch(source, /@xterm\/xterm\/css\/xterm\.css/);
  assert.doesNotMatch(source, /import\(['"]\.\/terminal-runtime['"]\)/);
});

test('syntax highlighting is deferred out of the main app shell', () => {
  const source = readFileSync(appPath, 'utf8');

  assert.doesNotMatch(source, /from ['"]rehype-highlight['"]/);
  assert.match(source, /import\(['"]rehype-highlight['"]\)/);
});
