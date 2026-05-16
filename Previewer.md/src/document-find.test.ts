import test from 'node:test';
import assert from 'node:assert/strict';

import {
  findMarkdownMatches,
  getNextFindMatchIndex,
} from './document-find';

test('findMarkdownMatches returns case-insensitive markdown ranges', () => {
  assert.deepEqual(findMarkdownMatches('Alpha beta alpha', 'ALPHA'), [
    { start: 0, end: 5 },
    { start: 11, end: 16 },
  ]);
});

test('findMarkdownMatches ignores empty queries', () => {
  assert.deepEqual(findMarkdownMatches('Alpha', ''), []);
  assert.deepEqual(findMarkdownMatches('Alpha', '   '), []);
});

test('getNextFindMatchIndex wraps through available matches', () => {
  assert.equal(getNextFindMatchIndex(-1, 3, 1), 0);
  assert.equal(getNextFindMatchIndex(2, 3, 1), 0);
  assert.equal(getNextFindMatchIndex(0, 3, -1), 2);
  assert.equal(getNextFindMatchIndex(0, 0, 1), -1);
});
