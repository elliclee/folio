import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourceDir = dirname(fileURLToPath(import.meta.url));

function readSourceFile(fileName: string) {
  return readFileSync(join(sourceDir, fileName), 'utf8');
}

test('chrome controls do not force webpage pointer cursors', () => {
  const appSource = readSourceFile('App.tsx');

  assert.equal(appSource.includes('cursor-pointer'), false);
  assert.equal(appSource.includes('cursor-not-allowed'), false);
});

test('chrome disables accidental text selection while document content stays selectable', () => {
  const css = readSourceFile('index.css');

  assert.match(css, /\.app-shell\s+:is\(button, select, label, \[data-chrome-text\]\)/);
  assert.match(css, /user-select:\s*none;/);
  assert.match(css, /\.app-shell\s+:is\(textarea, \.markdown-content, \.markdown-content \*\)/);
  assert.match(css, /user-select:\s*text;/);
});

test('webkit touch callout is disabled outside document content', () => {
  const css = readSourceFile('index.css');

  assert.match(css, /-webkit-touch-callout:\s*none;/);
  assert.match(css, /\.markdown-content\s+a/);
  assert.match(css, /-webkit-touch-callout:\s*default;/);
});
