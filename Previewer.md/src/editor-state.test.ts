import test from 'node:test';
import assert from 'node:assert/strict';

import {
  hasUnsavedChanges,
  shouldConfirmBeforeReplacingFile,
} from './editor-state';

test('hasUnsavedChanges reports dirty state only when content changed', () => {
  assert.equal(hasUnsavedChanges('alpha', 'alpha'), false);
  assert.equal(hasUnsavedChanges('alpha', 'beta'), true);
});

test('shouldConfirmBeforeReplacingFile only prompts when switching away with unsaved changes', () => {
  assert.equal(
    shouldConfirmBeforeReplacingFile('/tmp/a.md', '/tmp/b.md', true),
    true,
  );
  assert.equal(
    shouldConfirmBeforeReplacingFile('/tmp/a.md', '/tmp/a.md', true),
    false,
  );
  assert.equal(
    shouldConfirmBeforeReplacingFile('/tmp/a.md', '/tmp/b.md', false),
    false,
  );
  assert.equal(
    shouldConfirmBeforeReplacingFile(null, '/tmp/b.md', true),
    false,
  );
});
