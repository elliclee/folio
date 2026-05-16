import test from 'node:test';
import assert from 'node:assert/strict';

import {
  isEscapeKey,
  isFindShortcut,
  isSaveShortcut,
} from './native-shortcuts';

test('find shortcut follows platform command modifiers', () => {
  assert.equal(isFindShortcut({ key: 'f', metaKey: true, ctrlKey: false, altKey: false }), true);
  assert.equal(isFindShortcut({ key: 'F', metaKey: false, ctrlKey: true, altKey: false }), true);
  assert.equal(isFindShortcut({ key: 'f', metaKey: false, ctrlKey: false, altKey: false }), false);
  assert.equal(isFindShortcut({ key: 'f', metaKey: true, ctrlKey: false, altKey: true }), false);
});

test('save shortcut remains independent from find shortcut', () => {
  assert.equal(isSaveShortcut({ key: 's', metaKey: true, ctrlKey: false, altKey: false }), true);
  assert.equal(isSaveShortcut({ key: 'f', metaKey: true, ctrlKey: false, altKey: false }), false);
});

test('escape key is matched without modifiers', () => {
  assert.equal(isEscapeKey({ key: 'Escape', metaKey: false, ctrlKey: false, altKey: false }), true);
  assert.equal(isEscapeKey({ key: 'Escape', metaKey: true, ctrlKey: false, altKey: false }), false);
});
