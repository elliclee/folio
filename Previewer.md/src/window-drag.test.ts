import test from 'node:test';
import assert from 'node:assert/strict';

import { shouldStartWindowDrag, shouldToggleWindowMaximize } from './window-drag';

test('starts dragging on plain header targets with primary click', () => {
  const target = {
    closest: () => null,
  } as unknown as EventTarget & { closest: (selector: string) => null };

  assert.equal(shouldStartWindowDrag(target, 0, 1), true);
});

test('does not start dragging from no-drag controls', () => {
  const button = {
    closest: (selector: string) =>
      selector === '[data-no-drag="true"]' ? ({}) as Element : null,
  } as unknown as EventTarget & { closest: (selector: string) => Element | null };

  assert.equal(shouldStartWindowDrag(button, 0, 1), false);
});

test('does not start dragging for non-primary clicks or double clicks', () => {
  const target = {
    closest: () => null,
  } as unknown as EventTarget & { closest: (selector: string) => null };

  assert.equal(shouldStartWindowDrag(target, 1, 1), false);
  assert.equal(shouldStartWindowDrag(target, 0, 2), false);
});

test('toggles window maximize on double click in plain drag regions', () => {
  const target = {
    closest: () => null,
  } as unknown as EventTarget & { closest: (selector: string) => null };

  assert.equal(shouldToggleWindowMaximize(target, 0, 2), true);
});

test('does not toggle maximize from no-drag controls', () => {
  const button = {
    closest: (selector: string) =>
      selector === '[data-no-drag="true"]' ? ({}) as Element : null,
  } as unknown as EventTarget & { closest: (selector: string) => Element | null };

  assert.equal(shouldToggleWindowMaximize(button, 0, 2), false);
});

test('does not toggle maximize for single clicks or non-primary buttons', () => {
  const target = {
    closest: () => null,
  } as unknown as EventTarget & { closest: (selector: string) => null };

  assert.equal(shouldToggleWindowMaximize(target, 0, 1), false);
  assert.equal(shouldToggleWindowMaximize(target, 1, 2), false);
});
